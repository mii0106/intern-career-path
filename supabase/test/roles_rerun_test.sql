-- roles_test.sql のあとに supabase/parts/05 をもう一度流してから実行する
create or replace function pg_temp.t(label text, got text, want text) returns void language plpgsql as $fn$
begin
  raise notice '%  %', case when got is not distinct from want then 'PASS' else 'FAIL (got='||coalesce(got,'NULL')||' want='||coalesce(want,'NULL')||')' end, label;
end $fn$;
select pg_temp.t('2回目は振り分けをやり直さない',
  (select role from public.members where id = '00000000-0000-0000-0000-00000000c003'), 'ul');
select pg_temp.t('2回目は期を増やさない',
  (select count(*) from public.terms)::text, '2');
