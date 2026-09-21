-- ============================================================
-- STEP｜キャリアステップシート  Supabase スキーマ  （1/4）
-- テーブル・補助関数・名簿・パスコードの保管
-- ------------------------------------------------------------
-- Supabase の SQL Editor に貼り付けて RUN してください。
-- **1 から順に、1ファイルずつ** です。順番は入れ替えないでください。
-- 何度実行しても壊れないように書いてあります。
--
-- 元は1つのファイルでしたが、SQL Editor が長い入力を途中で切ってしまい
-- 「syntax error」で止まるため、貼れる大きさに分けてあります。
-- ============================================================

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

/* 制約は「いったん落としてから付け直す」。
   以前は do ... exception when duplicate_object ... のブロックで包んでいたが、
   2つ問題があった。
     ・許す値を増やしたとき、すでにある古い制約がそのまま残る
       （duplicate_object で黙って飛ばすため。新しい値の保存が弾かれる）
     ・SQLエディタによっては、引用の対応を取り違えて
       「syntax error at or near "check"」で止まる
   drop if exists → add なら、何度流しても同じ結果になり、
   引用も使わないので、どの画面に貼っても通る。 */

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
/* 権限は3つ。
     member … インターン本人。自分の分だけ見える
     mentor … 育成。管理者ツールで全員を見られる
     ul     … ユニットリーダー。管理者ツールで全員を見られる
   mentor と ul にできることの差はない（表示上の役割の違い）。
   'admin' は旧「管理者」。中身は mentor と同じなので、下で mentor に寄せる。 */
alter table public.members drop constraint if exists members_role_chk;
update public.members set role = 'mentor' where role = 'admin';
alter table public.members add constraint members_role_chk
  check (role in ('member','mentor','ul'));

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
alter table public.notes drop constraint if exists notes_kind_chk;
alter table public.notes add constraint notes_kind_chk
  check (kind in ('memo','handover','interview','promotion','escalation','praise'));
alter table public.notes drop constraint if exists notes_visibility_chk;
alter table public.notes add constraint notes_visibility_chk
  check (visibility in ('shared','admin'));
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

-- ============================================================
-- 2. 補助関数
--    RLSポリシーの中から members を参照すると再帰してしまうため、
--    security definer にして RLS を通さずに引く。
-- ============================================================
create or replace function public.current_member_id()
returns uuid language sql stable security definer set search_path = public as $fn$
  select id from public.members where auth_id = auth.uid() limit 1
$fn$;

create or replace function public.is_manager()
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (
    select 1 from public.members
    where auth_id = auth.uid() and role in ('mentor','ul') and active
  )
$fn$;

/* 卒業・退職（members.active = false）した本人からの書き込みを止めるためのガード。
   記録（チェック・申し送り・テスト）はそのまま残すが、
   本人がその後もチェックを付け外ししたり、プロフィールを書き換えたりはできなくする。
   読み取り（本人が自分の記録を見ること）はここでは制限しない。 */
create or replace function public.is_active_member(p_id uuid)
returns boolean language sql stable security definer set search_path = public as $fn$
  select coalesce((select active from public.members where id = p_id), false)
$fn$;

-- ============================================================
-- 3. ログイン画面に出す名簿
--    ログイン前（anon）でも名前を選べるようにするための最小限のビュー。
--    出るのは 表示名・Unit・UL・メンター・内部ID・権限・パスワード設定済みかどうか
--    だけで、入社日や進捗は出ない。
--    Unit・UL・メンターは、新しく登録する人の選択肢としても使う
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
  /* slug（＝ログインID）は、すでにパスワードを設定した人のぶんだけ出す。
     未設定の行の slug を出すと、共通パスコードを知っている人が
     名前で検索して他人の行を先に掴めてしまうため。
     未設定の人の slug はどのみち誰も使わない（claim_member が
     ログインのほうに slug を合わせる）。 */
  select id, name, unit, ul, mentor,
         case when auth_id is not null then slug end as slug,
         role, (auth_id is not null) as linked
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
alter table public.app_config drop constraint if exists app_config_single;
alter table public.app_config add constraint app_config_single check (id = 1);
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

-- 共通パスコードが合っているかだけを返す。
--
-- 【重要】ここは必ず「合っていなければ false」で返すこと（fail-closed）。
-- 以前は未設定のあいだ true を返していたが、それだと
--   ・app_config の行が消えた
--   ・スキーマを貼り直した直後
--   ・移行の途中
-- といった状況で、誰でも登録し放題の状態に黙って戻ってしまう。
-- 認証の既定は常に「拒否」でなければならない。
--
-- 未設定のときは false になるので誰も登録できないが、SETUP.md は
-- 手順5（パスコードを決める）→ 手順7（URLを配る）の順なので、
-- 通常の手順どおりなら詰まらない。万一未設定のまま配ってしまった場合は
-- 下の register_me / claim_member が「まだ設定されていません」と
-- 理由の分かるエラーを出す。
create or replace function public.check_team_passcode(p_code text)
returns boolean language sql stable security definer set search_path = public, extensions as $fn$
  select coalesce(team_passcode = crypt(coalesce(p_code,''), team_passcode), false)
    from public.app_config where id = 1
$fn$;
grant execute on function public.check_team_passcode(text) to anon, authenticated;

-- 共通パスコードが「設定されているか」だけを返す（中身は返さない）。
-- 登録画面が「違います」と「まだ設定されていません」を出し分けるために使う。
-- どちらの状態かはエラーメッセージからどのみち分かるので、これ自体は何も漏らさない。
create or replace function public.team_passcode_set()
returns boolean language sql stable security definer set search_path = public as $fn$
  select exists (select 1 from public.app_config where id = 1 and team_passcode is not null)
$fn$;
grant execute on function public.team_passcode_set() to anon, authenticated;

-- 共通パスコードを検証して、通らなければ理由の分かるエラーで止める。
-- 「未設定」と「間違い」を分けるのは、配る側と入れる側で直す場所が違うため。
create or replace function public.assert_team_passcode(p_code text)
returns void language plpgsql stable security definer set search_path = public, extensions as $fn$
begin
  if not exists (select 1 from public.app_config where id = 1 and team_passcode is not null) then
    raise exception '共通パスコードがまだ設定されていません。ULに連絡してください（SETUP.md 手順5）';
  end if;
  if not public.check_team_passcode(p_code) then
    raise exception 'パスコードが違います';
  end if;
end $fn$;

-- パスコードが設定済みかどうか（管理者画面で注意を出すため）。中身は返さない。
create or replace function public.config_status()
returns jsonb language sql stable security definer set search_path = public as $fn$
  select jsonb_build_object(
           'team',  (select team_passcode  is not null from public.app_config where id=1),
           'admin', (select admin_passcode is not null from public.app_config where id=1))
  where public.is_manager()
$fn$;
grant execute on function public.config_status() to authenticated;
