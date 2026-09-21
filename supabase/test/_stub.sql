-- ============================================================
-- 動作確認用の足場
-- ------------------------------------------------------------
-- Supabase が用意している auth.uid() / auth.jwt() を、
-- ローカルのPostgreSQLで真似るためだけのもの。
-- 本番のSupabaseには流さないこと。
-- ============================================================
create schema if not exists extensions;
create schema if not exists auth;
create table if not exists auth.users(id uuid primary key);

-- 「いま誰としてログインしているか」を set_config で差し替えられるようにする
create or replace function auth.uid() returns uuid language sql stable as $fn$
  select nullif(current_setting('test.uid', true), '')::uuid
$fn$;
create or replace function auth.jwt() returns jsonb language sql stable as $fn$
  select coalesce(nullif(current_setting('test.jwt', true), '')::jsonb, '{}'::jsonb)
$fn$;

do $fn$ begin create role anon;          exception when duplicate_object then null; end $fn$;
do $fn$ begin create role authenticated; exception when duplicate_object then null; end $fn$;

-- ------------------------------------------------------------
-- まとめて流すとき（ローカルのPostgreSQLで）
--
--   createdb steptest
--   psql -d steptest -f supabase/test/_stub.sql
--   psql -d steptest -f supabase/schema.sql
--   psql -d steptest -f supabase/test/login_test.sql
--
-- 最後の1本で PASS / FAIL が並びます。FAIL が1つでもあれば、
-- ログインまわりの筋道がどこかで崩れています。
-- ------------------------------------------------------------
