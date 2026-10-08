-- ============================================================
-- STEP｜キャリアステップシート  Supabase スキーマ  （5/5）
-- 立場（インターン／社員／メンター）と期への移行
-- ------------------------------------------------------------
-- Supabase の SQL Editor に貼り付けて RUN してください。
-- **1 から順に、1ファイルずつ** です。順番は入れ替えないでください。
-- 何度実行しても壊れないように書いてあります。
--
-- このファイルは、これまでのデータを新しい形に寄せるためのものです。
-- 中で行う「立場の振り分け」は最初の1回だけ動き、2回目以降は何もしません
-- （あとから管理者ツールで直した立場を、貼り直しで上書きしないため）。
-- ============================================================

-- ============================================================
-- 9. 立場の振り分け（最初の1回だけ）
--    ------------------------------------------------------------
--    これまでは「グレード（成長の軸）」と「UL／育成（立場）」を
--    1つの role に入れていた。そのため、社員のULにグレードの概念が無いのに
--    G1として表示されていた。
--
--    role を「インターン（member）／社員（staff）／メンター（mentor）」の3つにし、
--    ULはユニットの側（term_units）から決めるように変える。
--
--    以前「UL」だった人は、インターンなのか社員なのかがデータから分からない。
--    そこで、チェックか認定グレードが1つでもある人はインターン、
--    どちらも無い人は社員として**仮に**決め、role_confirmed = false にしておく。
--    管理者ツールの「設定 → 立場の確認」に並ぶので、1人ずつ確かめてもらう。
--    メンターだった人も、念のため確認の一覧に出す。
--
--    確かめるまでは legacy_ul = true のあいだ、管理者ツールをこれまでどおり使える。
--    インターンに振り分けられたULが、移行した瞬間に入れなくなるのを防ぐため。
-- ============================================================
alter table public.app_config add column if not exists roles_migrated_at timestamptz;

do $mig$
begin
  if (select roles_migrated_at from public.app_config where id = 1) is null then
    update public.members m
       set role = case
                    when m.certified_grade is not null
                      or exists (select 1 from public.progress p where p.member_id = m.id)
                    then 'member' else 'staff' end,
           legacy_ul = true,
           role_confirmed = false
     where m.role = 'ul';

    update public.members set role_confirmed = false where role = 'mentor';

    update public.app_config set roles_migrated_at = now() where id = 1;
  end if;
end $mig$;

-- ============================================================
-- 10. いまの編成を「1期目」として期に載せる
--    ------------------------------------------------------------
--    期（terms）をまだ1つも確定していない環境では、いまの名簿をそのまま
--    「いまの期」として登録する。期の名前はあとから管理者ツールで変えられる。
--    すでに「いまの期」がある環境では、新しい期は作らない。
--
--    グレード・目標・チェック・申し送りはどれも本人（members）に紐づいているので、
--    期を作っても、あとで編成を替えても消えない。
-- ============================================================
insert into public.terms(name, starts_on, status, note)
select '1期目（移行時の編成）', current_date, 'active',
       '移行のときに、その時点の名簿から自動で作った期です。名前と期間は管理者ツールで直せます。'
 where not exists (select 1 from public.terms where status = 'active')
on conflict (name) do nothing;

/* いまの期の割当が無いインターンは、名簿の所属・UL・メンターをそのまま割当にする。
   すでにある割当は上書きしない。 */
insert into public.assignments(term_id, member_id, unit, ul, mentor)
select t.id, m.id, m.unit, m.ul, m.mentor
  from public.members m
 cross join (select id from public.terms where status = 'active'
              order by starts_on desc limit 1) t
 where m.active and m.role = 'member'
on conflict (term_id, member_id) do nothing;

/* いまの期のユニットごとに、ULを1人決めて term_units に入れる。
   そのユニットの人のUL欄でいちばん多い名前を、名簿の氏名（空白を無視して比べる）と突き合わせる。
   見つからない名前（まだ登録していない人・表記ゆれ）は空のままにしておき、
   管理者ツールの「期・ユニット編成 → ユニットとUL」で選んでもらう。
   すでに入っているユニットは上書きしない。 */
insert into public.term_units(term_id, unit, ul_member_id)
select x.term_id, x.unit,
       (select m.id from public.members m
         where m.active
           and regexp_replace(m.name, '[[:space:]　]', '', 'g')
             = regexp_replace(x.ul,   '[[:space:]　]', '', 'g')
         order by (m.role <> 'member') desc, m.created_at
         limit 1)
  from (
    select a.term_id, a.unit,
           (select trim(b.ul) from public.assignments b
             where b.term_id = a.term_id and trim(b.unit) = a.unit
               and nullif(trim(b.ul), '') is not null
             group by trim(b.ul) order by count(*) desc, trim(b.ul) limit 1) as ul
      from (select distinct term_id, trim(unit) as unit
              from public.assignments
             where term_id = (select id from public.terms where status = 'active'
                               order by starts_on desc limit 1)
               and nullif(trim(unit), '') is not null) a
  ) x
on conflict (term_id, unit) do nothing;
