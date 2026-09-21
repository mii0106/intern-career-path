-- ============================================================
-- STEP｜キャリアステップシート  Supabase スキーマ  （3/4）
-- チェック・名前検索・管理者への昇格
-- ------------------------------------------------------------
-- Supabase の SQL Editor に貼り付けて RUN してください。
-- **1 から順に、1ファイルずつ** です。順番は入れ替えないでください。
-- 何度実行しても壊れないように書いてあります。
--
-- 元は1つのファイルでしたが、SQL Editor が長い入力を途中で切ってしまい
-- 「syntax error」で止まるため、貼れる大きさに分けてあります。
-- ============================================================

-- ============================================================
-- 5.5 チェックは本人が押した時点で達成
--     ------------------------------------------------------------
--     承認制はやめました。本人が画面でチェックを入れれば、その場で
--     達成として数えます。外すのも本人がそのままできます。
--     UL・メンターは管理画面から代わりに付ける／外すことができます。
--
--     approved_at / approved_by の列は、これまでのデータを消さないために
--     残していますが、いまはチェックと同時に埋まるだけの記録です。
-- ============================================================
alter table public.progress add column if not exists checked_by  uuid references public.members(id) on delete set null;
alter table public.progress add column if not exists approved_by uuid references public.members(id) on delete set null;
alter table public.progress add column if not exists approved_at timestamptz;

-- 承認待ちのまま残っているチェックは、すべて達成として扱う。
update public.progress set approved_at = checked_at where approved_at is null;

-- 本人からの書き込みは関数経由に限定する（他人の行に触れないようにするため）。
create or replace function public.set_my_check(p_item_id text, p_on boolean)
returns void language plpgsql security definer set search_path = public as $fn$
declare v_id uuid := public.current_member_id();
begin
  if v_id is null then raise exception 'not linked'; end if;
  if not public.is_active_member(v_id) then raise exception 'このアカウントは卒業・退職の扱いになっているため操作できません。心当たりがなければ育成・ULにご連絡ください'; end if;
  if p_on then
    insert into public.progress(member_id, item_id, checked_at, checked_by, approved_at, approved_by)
    values (v_id, p_item_id, now(), v_id, now(), v_id)
    on conflict (member_id, item_id)
      do update set approved_at = coalesce(progress.approved_at, excluded.approved_at);
  else
    delete from public.progress where member_id = v_id and item_id = p_item_id;
  end if;
end $fn$;

-- UL・メンターが代わりに付ける／外す。
--   p_state: 'off'（チェックを外す）／それ以外（チェックを付ける）
create or replace function public.set_check_for(p_member_id uuid, p_item_id text, p_state text)
returns void language plpgsql security definer set search_path = public as $fn$
declare v_me uuid := public.current_member_id();
begin
  if not public.is_manager() then raise exception 'この操作をする権限がありません'; end if;
  if p_state = 'off' then
    delete from public.progress where member_id = p_member_id and item_id = p_item_id;
  else
    insert into public.progress(member_id, item_id, checked_at, checked_by, approved_at, approved_by)
    values (p_member_id, p_item_id, now(), v_me, now(), v_me)
    on conflict (member_id, item_id) do update set approved_at = coalesce(progress.approved_at, excluded.approved_at);
  end if;
end $fn$;

-- 承認制をやめる前に残った「承認待ち」を、まとめて達成にそろえる関数。
-- ふだんは使いませんが、古いデータが混じったときの片付け用に残しています。
create or replace function public.approve_items(p_member_id uuid, p_item_ids text[])
returns int language plpgsql security definer set search_path = public as $fn$
declare v_n int;
begin
  if not public.is_manager() then raise exception 'この操作をする権限がありません'; end if;
  update public.progress
     set approved_at = checked_at
   where member_id = p_member_id and approved_at is null
     and (p_item_ids is null or item_id = any(p_item_ids));
  get diagnostics v_n = row_count;
  return v_n;
end $fn$;

-- 管理者がその人のチェックを全部消す（本人画面から消せないようにした代わり）。
create or replace function public.admin_clear_progress(p_member_id uuid)
returns int language plpgsql security definer set search_path = public as $fn$
declare v_n int; v_name text;
begin
  if not public.is_manager() then raise exception 'この操作をする権限がありません'; end if;
  delete from public.progress where member_id = p_member_id;
  get diagnostics v_n = row_count;
  select name into v_name from public.members where auth_id = auth.uid();
  insert into public.notes(member_id, kind, occurred_on, body, author_id, author_name, visibility)
  values (p_member_id, 'memo', current_date,
          'チェックを全件消去しました（' || v_n || '件）。管理画面からの操作です。',
          public.current_member_id(), v_name, 'admin');
  return v_n;
end $fn$;

grant execute on function public.set_my_check(text, boolean)              to authenticated;
grant execute on function public.set_check_for(uuid, text, text)          to authenticated;
grant execute on function public.approve_items(uuid, text[])              to authenticated;
grant execute on function public.admin_clear_progress(uuid)               to authenticated;

-- 本人の直接書き込みを止める（上の関数だけを通す）。読み取りはそのまま。
drop policy if exists progress_write  on public.progress;
drop policy if exists progress_update on public.progress;
drop policy if exists progress_delete on public.progress;
create policy progress_write on public.progress for insert to authenticated
  with check (public.is_manager());
create policy progress_update on public.progress for update to authenticated
  using (public.is_manager()) with check (public.is_manager());
create policy progress_delete on public.progress for delete to authenticated
  using (public.is_manager());

-- ============================================================
-- 5.6 ログイン画面の名前検索
--     名簿の一覧をログイン前に丸ごと見せず、2文字以上を入れた人にだけ
--     一致した数件を返す。
--     ※この節を実行したあと、名簿ビューの anon 権限を落とすかどうかは
--       SETUP.md「名簿を隠す」を参照（落とすと一覧表示は使えなくなります）。
-- ============================================================
create or replace function public.roster_search(p_q text, p_managers boolean default false)
returns table(id uuid, name text, unit text, ul text, slug text, role text, linked boolean)
language sql stable security definer set search_path = public as $fn$
  /* slug を出すのはパスワード設定済みの人だけ（member_roster と同じ理由）。
     未設定の人の行は「パスワードを決める ›」に進むだけなので id で足りる。 */
  select m.id, m.name, m.unit, m.ul,
         case when m.auth_id is not null then m.slug end,
         m.role, (m.auth_id is not null)
    from public.members m
   where m.active
     and length(coalesce(trim(p_q), '')) >= 2
     and (not p_managers or m.role in ('mentor','ul'))
     and (m.name ilike '%' || trim(p_q) || '%' or coalesce(m.unit,'') ilike '%' || trim(p_q) || '%')
   order by m.name
   limit 10
$fn$;
grant execute on function public.roster_search(text, boolean) to anon, authenticated;

-- 新規登録のときに Unit・UL・メンターを選択肢として出すためだけの一覧。
-- 個人名と紐付けない、値の集合だけを返す（表記ゆれを防ぐ目的にはそれで足りる。
-- 「だれのUL・メンターか」は出さない）。
create or replace function public.roster_units()
returns table(unit text)
language sql stable security definer set search_path = public as $fn$
  select distinct m.unit from public.members m
   where m.active and nullif(trim(m.unit),'') is not null
   order by 1
$fn$;
grant execute on function public.roster_units() to anon, authenticated;

create or replace function public.roster_uls()
returns table(ul text)
language sql stable security definer set search_path = public as $fn$
  select distinct m.ul from public.members m
   where m.active and nullif(trim(m.ul),'') is not null
   order by 1
$fn$;
grant execute on function public.roster_uls() to anon, authenticated;

create or replace function public.roster_mentors()
returns table(mentor text)
language sql stable security definer set search_path = public as $fn$
  select distinct m.mentor from public.members m
   where m.active and nullif(trim(m.mentor),'') is not null
   order by 1
$fn$;
grant execute on function public.roster_mentors() to anon, authenticated;

-- ============================================================
-- 5.7 管理者になるまでの流れを「申請 → 既存管理者の承認」に変える
--     管理者キーを知っている人が、育成／ULのどちらとして入るかを選んで
--     その場で権限を付ける。承認を待つ必要はない。
--     そのぶんキーの管理がすべてなので、メンバーには配らないこと。
--     総当り対策として、5回続けて間違えると15分ロックする。
-- ============================================================
-- 承認制をやめたので、この表はもう使っていない（過去の申請の記録が残っているだけ）。
-- 消したい場合は drop table public.manager_requests; を手で実行してください。
create table if not exists public.manager_requests (
  member_id   uuid primary key references public.members(id) on delete cascade,
  requested_at timestamptz not null default now(),
  status      text not null default 'pending',   -- pending / approved / rejected
  decided_by  uuid references public.members(id) on delete set null,
  decided_at  timestamptz
);
-- 育成として入りたいのか、ULとして入りたいのか。承認するとこの権限が付く。
alter table public.manager_requests add column if not exists want_role text not null default 'ul';
alter table public.manager_requests drop constraint if exists mreq_want_role_chk;
alter table public.manager_requests add constraint mreq_want_role_chk check (want_role in ('mentor','ul'));
alter table public.manager_requests enable row level security;
drop policy if exists mreq_read on public.manager_requests;
create policy mreq_read on public.manager_requests for select to authenticated
  using (member_id = public.current_member_id() or public.is_manager());

-- 管理者キーの連続失敗をロックする（総当り対策）。
alter table public.members add column if not exists admin_key_fails int not null default 0;
alter table public.members add column if not exists admin_key_locked_until timestamptz;

-- 引数が1つだった頃の版が残っていると、どちらを呼ぶか決められなくなる。
drop function if exists public.request_manager(text);
create or replace function public.request_manager(p_code text, p_role text default 'ul')
returns text language plpgsql security definer set search_path = public, extensions as $fn$
declare v_id uuid := public.current_member_id(); v_hash text; v_lock timestamptz;
        v_want text := case when p_role = 'mentor' then 'mentor' else 'ul' end;
begin
  if v_id is null then raise exception 'not linked'; end if;
  select admin_key_locked_until into v_lock from public.members where id = v_id;
  if v_lock is not null and v_lock > now() then
    raise exception '管理者キーの入力を続けて間違えたため、しばらく試せません（あと%分）',
      ceil(extract(epoch from (v_lock - now())) / 60);
  end if;

  select admin_passcode into v_hash from public.app_config where id = 1;
  if v_hash is null then raise exception '管理者キーがまだ設定されていません（SETUP.md 手順5）'; end if;

  if v_hash <> crypt(coalesce(p_code,''), v_hash) then
    update public.members
       set admin_key_fails = admin_key_fails + 1,
           admin_key_locked_until = case when admin_key_fails + 1 >= 5 then now() + interval '15 minutes' end
     where id = v_id;
    /* 【重要】ここで raise してはいけない（claim_member と同じ理由）。
       例外でトランザクションが巻き戻ると、失敗回数が戻ってしまい、
       「5回でロック」が一度も効かない。実際そうなっていた。
       間違いのときは 'bad-key' を返し、エラー文は呼び出し側が出す。 */
    return 'bad-key';
  end if;
  update public.members set admin_key_fails = 0, admin_key_locked_until = null where id = v_id;

  /* キーが合っていれば、その場で権限を付ける（承認待ちはない）。
     すでに育成／ULの人が選び直した場合も、選んだほうに切り替える。 */
  update public.members set role = v_want where id = v_id and role <> v_want;
  return 'approved';
end $fn$;

-- 承認制をやめたので、承認する関数は落とす。
drop function if exists public.decide_manager_request(uuid, boolean);

grant execute on function public.request_manager(text, text)           to authenticated;

-- 旧：引数の無い版。request_manager に一本化したので落とす。
drop function if exists public.claim_manager(text);
