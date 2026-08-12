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
--    出るのは 表示名・Unit・内部ID だけで、入社日や進捗は出ない。
--    ※名前の一覧はURLを知っていれば見えます。それも隠したい場合は
--      SETUP.md の「名簿も隠したい場合」を参照。
-- ============================================================
drop view if exists public.member_roster;
create view public.member_roster with (security_invoker = false) as
  select id, name, unit, slug from public.members where active order by unit nulls last, name;
grant select on public.member_roster to anon, authenticated;

-- ============================================================
-- 4. 本人側からの書き込み（ロール昇格などを防ぐため関数に限定）
-- ============================================================

-- 名前を選んでパスコードでログインした直後に、名簿の行と自分のログインを紐付ける。
-- 認証したメールのローカル部と slug が一致する行しか掴めない。
create or replace function public.claim_member(p_member_id uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_slug text; v_id uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_slug := lower(split_part(coalesce(auth.jwt() ->> 'email',''), '@', 1));

  -- すでに紐付いているなら、それを返す
  select id into v_id from public.members where auth_id = auth.uid();
  if v_id is not null then return v_id; end if;

  update public.members
     set auth_id = auth.uid()
   where id = p_member_id and auth_id is null and lower(slug) = v_slug and active
  returning id into v_id;

  if v_id is null then raise exception 'この名前は使用できません（すでに登録済み、または名前とログイン情報が一致しません）'; end if;

  insert into public.member_state(member_id) values (v_id) on conflict do nothing;
  return v_id;
end $$;

-- マイシートの自己申告項目だけを更新する。role や auth_id には触れない。
create or replace function public.update_my_profile(p_name text, p_join_date date, p_certified_grade int)
returns void language plpgsql security definer set search_path = public as $$
declare v_id uuid := public.current_member_id();
begin
  if v_id is null then raise exception 'not linked'; end if;
  update public.members
     set name            = coalesce(nullif(trim(p_name),''), name),
         join_date       = coalesce(p_join_date, join_date),
         certified_grade = coalesce(p_certified_grade, certified_grade)
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

grant execute on function public.claim_member(uuid)                                  to authenticated;
grant execute on function public.update_my_profile(text, date, int)                  to authenticated;
grant execute on function public.submit_review(text, text, text, text, text, text, text) to authenticated;
grant execute on function public.set_ul_comment(uuid, text)                          to authenticated;

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
-- 6. 名簿の投入例
--    slug は半角英数とハイフンのみ。ログイン用の内部IDになるので
--    一度決めたら変えないでください。
--    role は member / ul / admin の3つ。
-- ============================================================
-- insert into public.members (name, slug, unit, ul, mentor, join_date, certified_grade, role) values
--   ('山田 太郎', 'yamada-taro', 'Unit A', '佐藤 花子', '鈴木 一郎', '2026-04-01', 2, 'member'),
--   ('佐藤 花子', 'sato-hanako', 'Unit A', null,        null,        '2025-04-01', 7, 'ul')
-- on conflict (slug) do nothing;
