-- ============================================================
-- STEP｜キャリアステップシート  Supabase スキーマ
-- ------------------------------------------------------------
-- Supabase の SQL Editor に貼り付けて RUN すれば、そのまま動きます。
-- 何度実行しても壊れないように書いてあります。
--
-- 設計のポイント
--   ・アクセス制御は RLS（行レベルセキュリティ）で宣言的に書く
--       本人  … 自分の行だけ読める／書ける
--       UL/管理者 … 全員分読める／書ける
--   ・本人に見せたくない申し送りは visibility='admin' にすれば
--     本人のブラウザからは物理的に取得できない
--   ・ロール昇格や他人のULコメント書き換えを防ぐため、
--     本人側からの書き込みだけは関数（RPC）経由に絞っている
--   ・ログインのパスワードは1人1つ（Supabase Auth が持つ）。
--     共通パスコードは「登録していい人かどうか」を確かめるためのもので、
--     ログインのパスワードではない。ここを分けておかないと、
--     共通パスコードを知っている人が名簿からULの名前を選ぶだけで
--     管理者になれてしまう
-- ============================================================

-- ============================================================
-- 1. テーブル
-- ============================================================

-- 名簿。ログインの単位。
create table if not exists public.members (
  id              uuid primary key default gen_random_uuid(),
  auth_id         uuid unique,                       -- auth.users.id との紐付け
  name            text not null,                     -- 表示名（例：山田 太郎）
  slug            text not null unique,              -- ログイン用の内部ID（例：yamada-taro）
  unit            text,                              -- 所属Unit
  mentor          text,                              -- メンター名
  ul              text,                               -- UL名
  join_date       date,                              -- 入社日
  certified_grade int,                                -- 社内で認定されている現グレード
  promotion_target date,                              -- 昇格予定時期（手で上書きしたい場合）
  role            text not null default 'member',
  active          boolean not null default true,
  created_at      timestamptz not null default now()
);
do $$ begin
  alter table public.members add constraint members_role_chk
    check (role in ('member','ul','admin'));
exception when duplicate_object then null; end $$;

-- チェックが入った項目。1行＝1項目。
create table if not exists public.progress (
  member_id  uuid not null references public.members(id) on delete cascade,
  item_id    text not null,                          -- shared/steps.js が組み立てる項目ID（例：g2.4-1）
  checked_at timestamptz not null default now(),
  primary key (member_id, item_id)
);
create index if not exists progress_member_idx on public.progress(member_id);

-- 相棒の名前・目標・五箇条・アタリマエ・個別設定などの自由入力。
create table if not exists public.member_state (
  member_id  uuid primary key references public.members(id) on delete cascade,
  buddy      text default '',
  goals      jsonb not null default '{"basic":"","skill":""}'::jsonb,
  creed      jsonb not null default '[]'::jsonb,
  atarimae   jsonb not null default '{}'::jsonb,
  custom     jsonb not null default '{}'::jsonb,
  seen       jsonb not null default '[]'::jsonb,      -- 進化演出をすでに見たグレード
  sound      boolean not null default true,
  updated_at timestamptz not null default now()
);

-- 申し送り／メモ／面談記録。昇格面談のメモもここに入れる。
create table if not exists public.notes (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid not null references public.members(id) on delete cascade,
  kind        text not null default 'memo',
  occurred_on date not null default current_date,     -- 「いつ」の話か
  grade       int,                                     -- 昇格面談ならどのグレードの面談か
  title       text,
  body        text not null,                           -- 何があって、どうだったか
  next_action text,                                    -- 次にどうする
  author_id   uuid references public.members(id) on delete set null,
  author_name text,                                    -- 面談担当者・記入者
  visibility  text not null default 'shared',          -- shared: 本人も見える / admin: 管理者のみ
  pinned      boolean not null default false,
  created_at  timestamptz not null default now()
);
do $$ begin
  alter table public.notes add constraint notes_kind_chk
    check (kind in ('memo','handover','interview','promotion','escalation','praise'));
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.notes add constraint notes_visibility_chk
    check (visibility in ('shared','admin'));
exception when duplicate_object then null; end $$;
create index if not exists notes_member_idx on public.notes(member_id, occurred_on desc);

-- ラーニングボックス等のテスト結果。
-- (member_id, quiz_name, taken_on) を一意にしているので、
-- 同じCSVを何度取り込んでも重複しない。
create table if not exists public.quiz_scores (
  id          uuid primary key default gen_random_uuid(),
  member_id   uuid not null references public.members(id) on delete cascade,
  quiz_name   text not null,
  score       numeric,
  max_score   numeric,
  passed      boolean,
  taken_on    date,
  source      text default 'manual',                  -- manual / csv / learningbox
  external_id text,
  created_at  timestamptz not null default now(),
  unique (member_id, quiz_name, taken_on)
);
create index if not exists quiz_member_idx on public.quiz_scores(member_id);

-- 隔週YWT・月次振り返り。
create table if not exists public.reviews (
  id            uuid primary key default gen_random_uuid(),
  member_id     uuid not null references public.members(id) on delete cascade,
  kind          text not null,                        -- ywt / monthly
  period        text not null,                        -- ywt: '2026-08-A'（前半）/'2026-08-B'（後半）, monthly: '2026-08'
  y             text,                                  -- やったこと
  w             text,                                  -- わかったこと
  t             text,                                  -- つぎにやること
  looking_back  text,                                  -- 月次の振り返り
  next_goal     text,                                  -- 次月目標
  ul_comment    text,
  ul_comment_by text,
  submitted_at  timestamptz,
  updated_at    timestamptz not null default now(),
  unique (member_id, kind, period)
);
do $$ begin
  alter table public.reviews add constraint reviews_kind_chk check (kind in ('ywt','monthly'));
exception when duplicate_object then null; end $$;
create index if not exists reviews_member_idx on public.reviews(member_id);

-- ============================================================
-- 2. 補助関数
--    RLSポリシーの中から members を参照すると再帰してしまうため、
--    security definer にして RLS を通さずに引く。
-- ============================================================
create or replace function public.current_member_id()
returns uuid language sql stable security definer set search_path = public as $$
  select id from public.members where auth_id = auth.uid() limit 1
$$;

create or replace function public.is_manager()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.members
    where auth_id = auth.uid() and role in ('ul','admin') and active
  )
$$;

-- ============================================================
-- 3. ログイン画面に出す名簿
--    ログイン前（anon）でも名前を選べるようにするための最小限のビュー。
--    出るのは 表示名・Unit・UL・内部ID・権限・パスワード設定済みかどうか
--    だけで、入社日や進捗は出ない。
--    Unit と UL は、新しく登録する人の選択肢としても使う
--    （すでに誰かが登録した表記がそのまま選べるので、表記が揃う）。
--
--    role   … 管理者画面のログイン一覧で UL だけを出すために使う。
--    linked … パスワードを設定済みか。false の行は「初回パスワード設定」に進む
--             （新規登録の直後と、ULがログインをリセットした直後だけ false）。
--
--    ※名前の一覧はURLを知っていれば見えます。それも隠したい場合は
--      SETUP.md の「名簿も隠したい場合」を参照。
-- ============================================================
drop view if exists public.member_roster;
create view public.member_roster with (security_invoker = false) as
  select id, name, unit, ul, slug, role, (auth_id is not null) as linked
    from public.members where active order by unit nulls last, name;
grant select on public.member_roster to anon, authenticated;

-- ============================================================
-- 3.5 パスコードの保管
--     部署共通パスコード（登録するときに入れるもの）と、
--     管理者キー（ULが自分を管理者に昇格させるときに入れるもの）を
--     ハッシュにして持つ。クライアントからは一切読めない。
--     設定のしかたは SETUP.md 手順5を参照。
-- ============================================================
-- Supabase では pgcrypto が extensions スキーマに入っていることが多い。
-- そのため crypt() を使う関数の search_path には extensions も入れてある。
-- まだ入っていない環境ではここで public に作られるが、どちらでも動く。
create extension if not exists pgcrypto;

create table if not exists public.app_config (
  id             int primary key default 1,
  team_passcode  text,          -- bcryptハッシュ。新規登録のときの共通パスコード
  admin_passcode text,          -- bcryptハッシュ。管理者になるための管理者キー
  updated_at     timestamptz not null default now()
);
do $$ begin
  alter table public.app_config add constraint app_config_single check (id = 1);
exception when duplicate_object then null; end $$;
insert into public.app_config(id) values (1) on conflict (id) do nothing;

-- ポリシーを1つも作らないので、クライアント（anon/authenticated）からは読めない。
-- 下の security definer 関数の中からだけ参照される。
alter table public.app_config enable row level security;

-- パスコードの設定は、あえて関数にせず SQL Editor から直接 update します。
-- PostgreSQL は作成した関数の実行権限を既定で PUBLIC に与えるため、
-- 「設定用の関数」を置くとメンバーからも呼べてしまい、
-- パスコードと管理者キーを書き換えられる隙になります。
-- 設定するSQLは SETUP.md 手順5に書いてあります（下と同じ内容）。
--
--   update public.app_config
--      set team_passcode  = crypt('チーム共通のパスコード', gen_salt('bf')),
--          admin_passcode = crypt('管理者キー',             gen_salt('bf')),
--          updated_at = now()
--    where id = 1;
--
-- 万一この先で設定用の関数を足すときは、必ず
--   revoke all on function <名前>(...) from public;
-- まで書いてください（anon / authenticated からのrevokeだけでは足りません）。
-- 古い版で関数を作ってしまっていた場合は、ここで確実に落とす。
drop function if exists public.set_passcodes(text, text);

-- 共通パスコードが合っているかだけを返す。未設定のあいだは true（誰でも登録できる）。
create or replace function public.check_team_passcode(p_code text)
returns boolean language sql stable security definer set search_path = public, extensions as $$
  select coalesce(team_passcode = crypt(coalesce(p_code,''), team_passcode), true)
    from public.app_config where id = 1
$$;
grant execute on function public.check_team_passcode(text) to anon, authenticated;

-- パスコードが設定済みかどうか（管理者画面で注意を出すため）。中身は返さない。
create or replace function public.config_status()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
           'team',  (select team_passcode  is not null from public.app_config where id=1),
           'admin', (select admin_passcode is not null from public.app_config where id=1))
  where public.is_manager()
$$;
grant execute on function public.config_status() to authenticated;

-- ============================================================
-- 4. 本人側からの書き込み（ロール昇格などを防ぐため関数に限定）
-- ============================================================

-- 名簿の行と、いま作ったログインを紐付ける。
--
-- 使うのは「ULがログインをリセットした人が、新しいパスワードを設定するとき」だけ。
-- 通常の新規登録は register_me が行の作成と紐付けを同時にやる。
--
-- 掴めるのは
--   ・まだ誰とも紐付いていない行（auth_id が空）で、かつ
--   ・認証したメールのローカル部と slug が一致する行
-- だけ。加えて共通パスコードの一致を必須にしているので、
-- URLと名簿を見ただけの人が他人の行を掴むことはできない。
drop function if exists public.claim_member(uuid);
create or replace function public.claim_member(p_member_id uuid, p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_slug text; v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not coalesce(public.check_team_passcode(p_code), true) then raise exception 'パスコードが違います'; end if;
  v_slug := lower(split_part(coalesce(auth.jwt() ->> 'email',''), '@', 1));

  -- すでに紐付いているなら、それを返す
  select id into v_id from public.members where auth_id = auth.uid();
  if v_id is not null then return v_id; end if;

  update public.members
     set auth_id = auth.uid()
   where id = p_member_id and auth_id is null and lower(slug) = v_slug and active
  returning id into v_id;

  if v_id is null then raise exception 'この名前は使用できません（すでにパスワード設定済み、または名前とログイン情報が一致しません）'; end if;

  insert into public.member_state(member_id) values (v_id) on conflict do nothing;
  return v_id;
end $$;

-- ログインのリセット（パスワードを忘れた人の救済）。
-- 管理者だけが呼べる。行そのもの（進捗・申し送り・点数）は一切消さず、
-- ログインとの紐付けだけを外し、slug を新しい値に振り直す。
-- このあと本人が名前を選ぶと「初回パスワード設定」に進み、
-- 共通パスコードと新しいパスワードを入れて claim_member で繋ぎ直す。
--
-- slug を振り直すのは、外したあとに古いログイン（元のパスワードを知っている人）が
-- そのまま繋ぎ直せてしまうのを防ぐため。
create or replace function public.admin_reset_login(p_member_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_slug text;
begin
  if not public.is_manager() then raise exception 'この操作をする権限がありません'; end if;
  if p_member_id = public.current_member_id() then
    raise exception '自分のログインはリセットできません（他の管理者に依頼してください）';
  end if;

  v_slug := 'm-' || replace(gen_random_uuid()::text, '-', '');
  update public.members set auth_id = null, slug = v_slug where id = p_member_id;
  if not found then raise exception '対象が見つかりません'; end if;
  return v_slug;
end $$;

-- 自分で名簿に登録する。
-- 一括投入をしなくても、使い始めた人の情報が順に名簿へ積み上がっていく。
-- 作れるのは自分の行だけで、role は必ず member 固定。
-- 同じログインで2回呼んだ場合は、行を作り直さず内容を更新する。
create or replace function public.register_me(
  p_name text, p_unit text, p_ul text, p_mentor text,
  p_join_date date, p_certified_grade int, p_code text
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_slug text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if not coalesce(public.check_team_passcode(p_code), true) then raise exception 'パスコードが違います'; end if;
  if nullif(trim(p_name),'') is null then raise exception '氏名を入力してください'; end if;

  v_slug := lower(split_part(coalesce(auth.jwt() ->> 'email',''), '@', 1));
  if v_slug = '' then raise exception 'ログイン情報を確認できません'; end if;

  select id into v_id from public.members where auth_id = auth.uid();
  if v_id is not null then
    /* すでに登録済み。押し間違いや再送信でも増えないように更新だけする */
    update public.members
       set name            = trim(p_name),
           unit            = nullif(trim(p_unit),''),
           ul              = nullif(trim(p_ul),''),
           mentor          = nullif(trim(p_mentor),''),
           join_date       = coalesce(p_join_date, join_date),
           certified_grade = coalesce(p_certified_grade, certified_grade)
     where id = v_id;
    return v_id;
  end if;

  insert into public.members(name, slug, unit, ul, mentor, join_date, certified_grade, role, auth_id, active)
  values (trim(p_name), v_slug, nullif(trim(p_unit),''), nullif(trim(p_ul),''),
          nullif(trim(p_mentor),''), p_join_date, p_certified_grade, 'member', auth.uid(), true)
  returning id into v_id;

  insert into public.member_state(member_id) values (v_id) on conflict do nothing;
  return v_id;
end $$;

-- 管理者キーを入れて、自分を UL に昇格させる。
-- キーが未設定のあいだは昇格できない（誰でも全員分を見られてしまうため）。
create or replace function public.claim_manager(p_code text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare v_id uuid := public.current_member_id(); v_hash text;
begin
  if v_id is null then raise exception 'not linked'; end if;
  select admin_passcode into v_hash from public.app_config where id = 1;
  if v_hash is null then raise exception '管理者キーがまだ設定されていません（SETUP.md 手順5）'; end if;
  if v_hash <> crypt(coalesce(p_code,''), v_hash) then raise exception '管理者キーが違います'; end if;

  update public.members set role = 'ul' where id = v_id and role = 'member';
  return (select role from public.members where id = v_id);
end $$;

-- マイシートの自己申告項目だけを更新する。role や auth_id には触れない。
create or replace function public.update_my_profile(
  p_name text, p_join_date date, p_certified_grade int,
  p_unit text default null, p_ul text default null, p_mentor text default null
) returns void language plpgsql security definer set search_path = public as $$
declare v_id uuid := public.current_member_id();
begin
  if v_id is null then raise exception 'not linked'; end if;
  update public.members
     set name            = coalesce(nullif(trim(p_name),''), name),
         join_date       = coalesce(p_join_date, join_date),
         certified_grade = coalesce(p_certified_grade, certified_grade),
         unit            = coalesce(nullif(trim(p_unit),''),   unit),
         ul              = coalesce(nullif(trim(p_ul),''),     ul),
         mentor          = coalesce(nullif(trim(p_mentor),''), mentor)
   where id = v_id;
end $$;

-- 本人が自分のYWT・月次振り返りを提出する。ULコメントは触れない。
create or replace function public.submit_review(
  p_kind text, p_period text,
  p_y text, p_w text, p_t text, p_looking_back text, p_next_goal text
) returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid := public.current_member_id(); v_row uuid;
begin
  if v_id is null then raise exception 'not linked'; end if;
  if p_kind not in ('ywt','monthly') then raise exception 'bad kind'; end if;

  insert into public.reviews as r (member_id, kind, period, y, w, t, looking_back, next_goal, submitted_at, updated_at)
  values (v_id, p_kind, p_period, p_y, p_w, p_t, p_looking_back, p_next_goal, now(), now())
  on conflict (member_id, kind, period) do update
    set y = excluded.y, w = excluded.w, t = excluded.t,
        looking_back = excluded.looking_back, next_goal = excluded.next_goal,
        submitted_at = coalesce(r.submitted_at, now()), updated_at = now()
  returning id into v_row;
  return v_row;
end $$;

-- UL/管理者が振り返りにコメントを返す。
create or replace function public.set_ul_comment(p_review_id uuid, p_comment text)
returns void language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if not public.is_manager() then raise exception 'not a manager'; end if;
  select name into v_name from public.members where auth_id = auth.uid();
  update public.reviews set ul_comment = p_comment, ul_comment_by = v_name, updated_at = now()
   where id = p_review_id;
end $$;

grant execute on function public.claim_member(uuid,text)                             to authenticated;
grant execute on function public.admin_reset_login(uuid)                             to authenticated;
grant execute on function public.register_me(text,text,text,text,date,int,text)      to authenticated;
grant execute on function public.claim_manager(text)                                 to authenticated;
grant execute on function public.update_my_profile(text,date,int,text,text,text)     to authenticated;
grant execute on function public.submit_review(text, text, text, text, text, text, text) to authenticated;
grant execute on function public.set_ul_comment(uuid, text)                          to authenticated;
/* 古い版から貼り直したときに、引数が違う旧関数が残らないように落とす */
drop function if exists public.update_my_profile(text, date, int);

-- ============================================================
-- 5. RLS
-- ============================================================
alter table public.members      enable row level security;
alter table public.progress     enable row level security;
alter table public.member_state enable row level security;
alter table public.notes        enable row level security;
alter table public.quiz_scores  enable row level security;
alter table public.reviews      enable row level security;

-- members：自分の行と、管理者なら全員。書き込みは管理者のみ（本人は上の関数経由）。
drop policy if exists members_read   on public.members;
drop policy if exists members_write  on public.members;
drop policy if exists members_update on public.members;
drop policy if exists members_delete on public.members;
create policy members_read on public.members for select to authenticated
  using (auth_id = auth.uid() or public.is_manager());
create policy members_write on public.members for insert to authenticated
  with check (public.is_manager());
create policy members_update on public.members for update to authenticated
  using (public.is_manager()) with check (public.is_manager());
create policy members_delete on public.members for delete to authenticated
  using (public.is_manager());

-- progress：本人と管理者。
drop policy if exists progress_read   on public.progress;
drop policy if exists progress_write  on public.progress;
drop policy if exists progress_update on public.progress;
drop policy if exists progress_delete on public.progress;
create policy progress_read on public.progress for select to authenticated
  using (member_id = public.current_member_id() or public.is_manager());
create policy progress_write on public.progress for insert to authenticated
  with check (member_id = public.current_member_id() or public.is_manager());
create policy progress_update on public.progress for update to authenticated
  using (member_id = public.current_member_id() or public.is_manager())
  with check (member_id = public.current_member_id() or public.is_manager());
create policy progress_delete on public.progress for delete to authenticated
  using (member_id = public.current_member_id() or public.is_manager());

-- member_state：本人と管理者。
drop policy if exists state_read   on public.member_state;
drop policy if exists state_write  on public.member_state;
drop policy if exists state_update on public.member_state;
create policy state_read on public.member_state for select to authenticated
  using (member_id = public.current_member_id() or public.is_manager());
create policy state_write on public.member_state for insert to authenticated
  with check (member_id = public.current_member_id() or public.is_manager());
create policy state_update on public.member_state for update to authenticated
  using (member_id = public.current_member_id() or public.is_manager())
  with check (member_id = public.current_member_id() or public.is_manager());

-- notes：管理者は全部。本人は「本人にも見せる」と指定されたものだけ。
-- 書けるのは管理者だけ。
drop policy if exists notes_read   on public.notes;
drop policy if exists notes_write  on public.notes;
drop policy if exists notes_update on public.notes;
drop policy if exists notes_delete on public.notes;
create policy notes_read on public.notes for select to authenticated
  using (public.is_manager()
         or (member_id = public.current_member_id() and visibility = 'shared'));
create policy notes_write on public.notes for insert to authenticated
  with check (public.is_manager());
create policy notes_update on public.notes for update to authenticated
  using (public.is_manager()) with check (public.is_manager());
create policy notes_delete on public.notes for delete to authenticated
  using (public.is_manager());

-- quiz_scores：本人は自分の点数、管理者は全員。登録は管理者。
drop policy if exists quiz_read   on public.quiz_scores;
drop policy if exists quiz_write  on public.quiz_scores;
drop policy if exists quiz_update on public.quiz_scores;
drop policy if exists quiz_delete on public.quiz_scores;
create policy quiz_read on public.quiz_scores for select to authenticated
  using (member_id = public.current_member_id() or public.is_manager());
create policy quiz_write on public.quiz_scores for insert to authenticated
  with check (public.is_manager());
create policy quiz_update on public.quiz_scores for update to authenticated
  using (public.is_manager()) with check (public.is_manager());
create policy quiz_delete on public.quiz_scores for delete to authenticated
  using (public.is_manager());

-- reviews：本人は自分の分を読める（書き込みは submit_review 経由）。管理者は全部。
drop policy if exists reviews_read   on public.reviews;
drop policy if exists reviews_write  on public.reviews;
drop policy if exists reviews_update on public.reviews;
drop policy if exists reviews_delete on public.reviews;
create policy reviews_read on public.reviews for select to authenticated
  using (member_id = public.current_member_id() or public.is_manager());
create policy reviews_write on public.reviews for insert to authenticated
  with check (public.is_manager());
create policy reviews_update on public.reviews for update to authenticated
  using (public.is_manager()) with check (public.is_manager());
create policy reviews_delete on public.reviews for delete to authenticated
  using (public.is_manager());

-- ============================================================
-- 6. 名簿について
--    投入作業は不要です。各メンバーが自分で登録すると members に行が増えていき、
--    そのまま管理者画面の一覧に反映されます。
--    このファイルはサンプルデータを1件も作りません。
--    管理者画面に出るのは、実際に本人画面から登録した人だけです。
--
--    先に名簿を用意しておきたい場合（未登録者を把握したいときなど）は、
--    下のように行だけ作っておけます。auth_id が空の行は「まだパスワード未設定」
--    として扱われ、その名前を選んだ人が共通パスコードと新しいパスワードを
--    入れて紐付きます。slug は他と重複しない任意の文字列にしてください。
-- ============================================================
-- insert into public.members (name, slug, unit, ul, mentor, join_date, certified_grade, role) values
--   ('山田 太郎', 'yamada-taro', 'Unit A', '佐藤 花子', '鈴木 一郎', '2026-04-01', 2, 'member')
-- on conflict (slug) do nothing;
