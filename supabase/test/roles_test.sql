-- ============================================================
-- STEP｜立場（インターン／社員／メンター）とユニットULの動作確認
-- ------------------------------------------------------------
-- 使い方（ローカルのPostgreSQLで）
--   1. 空のDBに supabase/test/_stub.sql を流す
--   2. 移行前の古いスキーマ（git の以前の supabase/parts/ 1〜4）を流し、
--      supabase/test/roles_olddata.sql で古い形のデータを入れる
--   3. 新しい supabase/parts/ を 1 から 5 まで流す
--   4. このファイルを流す。PASS / FAIL が並ぶ
--
-- 本番のSupabaseに対しては流さないこと。
-- ============================================================
create or replace function pg_temp.t(label text, got text, want text) returns void language plpgsql as $fn$
begin
  raise notice '%  %', case when got is not distinct from want then 'PASS' else 'FAIL (got='||coalesce(got,'NULL')||' want='||coalesce(want,'NULL')||')' end, label;
end $fn$;
create or replace function pg_temp.role_of(p text) returns text language sql as $fn$
  select role from public.members where id = p::uuid
$fn$;

-- ===== 立場の振り分け =====
select pg_temp.t('チェックも認定グレードも無い旧ULは社員に仮決め',
  pg_temp.role_of('00000000-0000-0000-0000-00000000c001'), 'staff');
select pg_temp.t('認定グレードがある旧ULはインターンに仮決め',
  pg_temp.role_of('00000000-0000-0000-0000-00000000c002'), 'member');
select pg_temp.t('チェックがある旧ULもインターンに仮決め',
  pg_temp.role_of('00000000-0000-0000-0000-00000000c006'), 'member');
select pg_temp.t('メンターはメンターのまま',
  pg_temp.role_of('00000000-0000-0000-0000-00000000c003'), 'mentor');
select pg_temp.t('インターンはインターンのまま',
  pg_temp.role_of('00000000-0000-0000-0000-00000000c004'), 'member');
select pg_temp.t('仮決めした人は確認待ちになる',
  (select count(*) from public.members where not role_confirmed)::text, '4');
select pg_temp.t('ULという立場は残らない',
  (select count(*) from public.members where role = 'ul')::text, '0');

-- ===== 期・割当・ユニットUL =====
select pg_temp.t('いまの期が1つできる',
  (select count(*) from public.terms where status = 'active')::text, '1');
select pg_temp.t('インターンの割当がいまの期に入る',
  (select count(*) from public.assignments)::text, '4');
select pg_temp.t('ユニットのULが、空白違いの名前でも名簿と結び付く',
  (select ul_member_id::text from public.term_units where unit = 'unitA'),
  '00000000-0000-0000-0000-00000000c001');
select pg_temp.t('インターンのULもユニットに結び付く',
  (select ul_member_id::text from public.term_units where unit = 'unitB'),
  '00000000-0000-0000-0000-00000000c002');

-- ===== 管理者ツールを使えるか =====
select pg_temp.t('社員は使える',
  public.is_manager_member('00000000-0000-0000-0000-00000000c001')::text, 'true');
select pg_temp.t('ULのインターン（二重身分）は使える',
  public.is_manager_member('00000000-0000-0000-0000-00000000c002')::text, 'true');
select pg_temp.t('ULでないインターンは使えない',
  public.is_manager_member('00000000-0000-0000-0000-00000000c004')::text, 'false');
select pg_temp.t('元ULでユニットが分からない人も、確認までは使える',
  public.is_manager_member('00000000-0000-0000-0000-00000000c006')::text, 'true');

-- 確認して「インターン」と決めると、ULでないかぎり使えなくなる
update public.members set role_confirmed = true, legacy_ul = false
 where id = '00000000-0000-0000-0000-00000000c006';
select pg_temp.t('確認後、ULでないインターンは使えない',
  public.is_manager_member('00000000-0000-0000-0000-00000000c006')::text, 'false');

-- ULの交代はユニットのUL欄を差し替えるだけ
update public.term_units set ul_member_id = '00000000-0000-0000-0000-00000000c004' where unit = 'unitB';
update public.members set legacy_ul = false where id = '00000000-0000-0000-0000-00000000c002';
select pg_temp.t('新しくULにしたインターンが使えるようになる',
  public.is_manager_member('00000000-0000-0000-0000-00000000c004')::text, 'true');
select pg_temp.t('ULから外れたインターンは使えなくなる',
  public.is_manager_member('00000000-0000-0000-0000-00000000c002')::text, 'false');
select pg_temp.t('ULから外れても本人の立場はインターンのまま',
  pg_temp.role_of('00000000-0000-0000-0000-00000000c002'), 'member');

-- 編成中の期のULも、引き継ぎの準備のために使える
insert into public.terms(id, name, starts_on, status)
  values ('00000000-0000-0000-0000-0000000000f1', '次の期', current_date + 30, 'draft');
insert into public.term_units(term_id, unit, ul_member_id)
  values ('00000000-0000-0000-0000-0000000000f1', 'unitC', '00000000-0000-0000-0000-00000000c006');
select pg_temp.t('編成中の期のULも使える',
  public.is_manager_member('00000000-0000-0000-0000-00000000c006')::text, 'true');

-- 期を確定すると、ULの名前がユニットの側から名簿に書き戻される
insert into public.assignments(term_id, member_id, unit, ul)
  values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-00000000c005', 'unitC', '古い名前');
insert into auth.users(id) values ('00000000-0000-0000-0000-0000000000d1') on conflict do nothing;
update public.members set auth_id = '00000000-0000-0000-0000-0000000000d1'
 where id = '00000000-0000-0000-0000-00000000c001';
select set_config('test.uid','00000000-0000-0000-0000-0000000000d1',false);
select public.apply_term('00000000-0000-0000-0000-0000000000f1');
select pg_temp.t('確定でULの名前がユニットから入る',
  (select ul from public.members where id = '00000000-0000-0000-0000-00000000c005'), 'チェックだけ ULさん');
select pg_temp.t('確定で前の期は終了になり、その期のULは外れる',
  public.is_manager_member('00000000-0000-0000-0000-00000000c004')::text, 'false');

-- ===== 貼り直しても立場の振り分けはやり直さない =====
update public.members set role = 'ul' where id = '00000000-0000-0000-0000-00000000c003';
-- （ここから先は、このあとに supabase/parts/05 をもう一度流してから
--   supabase/test/roles_rerun_test.sql で確かめる）
