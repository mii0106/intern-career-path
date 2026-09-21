-- ============================================================
-- STEP｜キャリアステップシート  Supabase スキーマ  （2/4）
-- 本人側からの書き込みと RLS
-- ------------------------------------------------------------
-- Supabase の SQL Editor に貼り付けて RUN してください。
-- **1 から順に、1ファイルずつ** です。順番は入れ替えないでください。
-- 何度実行しても壊れないように書いてあります。
--
-- 元は1つのファイルでしたが、SQL Editor が長い入力を途中で切ってしまい
-- 「syntax error」で止まるため、貼れる大きさに分けてあります。
-- ============================================================

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
-- ワンタイムのログインコードを入れる欄。
-- ULが発行し、本人に口頭やDMで渡す。ハッシュで持つので読み出せない。
alter table public.members add column if not exists claim_code_hash    text;
alter table public.members add column if not exists claim_code_expires timestamptz;
alter table public.members add column if not exists claim_code_fails   int not null default 0;

drop function if exists public.claim_member(uuid);
create or replace function public.claim_member(p_member_id uuid, p_code text)
returns uuid language plpgsql security definer set search_path = public, extensions as $fn$
declare v_slug text; v_id uuid; r record;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  v_slug := lower(split_part(coalesce(auth.jwt() ->> 'email',''), '@', 1));
  if v_slug = '' then raise exception 'ログイン情報を確認できません'; end if;

  -- すでに紐付いているなら、それを返す
  select id into v_id from public.members where auth_id = auth.uid();
  if v_id is not null then return v_id; end if;

  select id, claim_code_hash, claim_code_expires, claim_code_fails
    into r
    from public.members
   where id = p_member_id and auth_id is null and active
   for update;

  if r.id is null then
    raise exception 'この名前は使用できません（すでにパスワードが設定されています）';
  end if;
  if r.claim_code_hash is null then
    raise exception 'ログイン用コードが発行されていません。UL・育成に「STEPのログインコードを発行してほしい」と伝えてください';
  end if;
  if r.claim_code_expires is not null and r.claim_code_expires < now() then
    raise exception 'ログイン用コードの有効期限が切れています。UL・育成に発行し直してもらってください';
  end if;
  if r.claim_code_fails >= 5 then
    raise exception 'ログイン用コードを続けて間違えたため、このコードは使えなくなりました。発行し直してもらってください';
  end if;
  if r.claim_code_hash <> crypt(coalesce(p_code,''), r.claim_code_hash) then
    update public.members set claim_code_fails = claim_code_fails + 1 where id = r.id;
    /* 【重要】ここで raise してはいけない。
       例外を投げるとトランザクションが巻き戻り、いま足した失敗回数ごと
       無かったことになる（＝何回間違えてもロックがかからない）。
       間違いのときだけ NULL を返し、エラー文は呼び出し側（shared/store.js）が出す。 */
    return null;
  end if;

  /* ここまで来たら本人。いま作ったログインに slug を合わせる。
     以前は「認証メールのローカル部と slug が一致すること」を条件にしていたが、
     その slug は名前で検索すれば未ログインでも取れてしまうため、
     共通パスコード（全員が知っている）さえあれば他人の行を掴めた。
     コードで本人確認し、slug のほうを後から合わせる形にしている。 */
  update public.members
     set auth_id = auth.uid(),
         slug    = v_slug,
         claim_code_hash = null, claim_code_expires = null, claim_code_fails = 0
   where id = r.id
  returning id into v_id;

  insert into public.member_state(member_id) values (v_id) on conflict do nothing;
  return v_id;
end $fn$;

-- ログインのリセット（パスワードを忘れた人の救済）。
-- 管理者だけが呼べる。行そのもの（進捗・申し送り・点数）は一切消さず、
-- ログインとの紐付けだけを外し、slug を新しい値に振り直す。
-- このあと本人が名前を選ぶと「初回パスワード設定」に進み、
-- 共通パスコードと新しいパスワードを入れて claim_member で繋ぎ直す。
--
-- slug を振り直すのは、外したあとに古いログイン（元のパスワードを知っている人）が
-- そのまま繋ぎ直せてしまうのを防ぐため。
create or replace function public.admin_reset_login(p_member_id uuid)
returns text language plpgsql security definer set search_path = public, extensions as $fn$
declare v_slug text; v_code text;
begin
  if not public.is_manager() then raise exception 'この操作をする権限がありません'; end if;
  if p_member_id = public.current_member_id() then
    raise exception '自分のログインはリセットできません（他の管理者に依頼してください）';
  end if;

  /* 読み上げ・書き写しで間違えない文字だけを使う。
     0/O、1/I/l のような紛らわしい組み合わせは外してある。 */
  select string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789',
                           1 + floor(random()*32)::int, 1), '')
    into v_code from generate_series(1,8);

  v_slug := 'm-' || replace(gen_random_uuid()::text, '-', '');
  update public.members
     set auth_id = null,
         slug    = v_slug,
         claim_code_hash    = crypt(v_code, gen_salt('bf')),
         claim_code_expires = now() + interval '7 days',
         claim_code_fails   = 0
   where id = p_member_id;
  if not found then raise exception '対象が見つかりません'; end if;
  /* 本人からの依頼が出ていたら、ここで片付ける。
     （login_requests はこのファイルの後ろで作るので、まだ無くても落ちないようにする） */
  begin
    delete from public.login_requests where member_id = p_member_id;
  exception when undefined_table then null; end;

  /* 平文のコードを返すのはここ1回だけ。DBにはハッシュしか残らないので、
     控え忘れたら発行し直す（それでいい。使い回さないほうが安全）。 */
  return v_code;
end $fn$;

-- 自分で名簿に登録する。
-- 一括投入をしなくても、使い始めた人の情報が順に名簿へ積み上がっていく。
-- 作れるのは自分の行だけで、role は必ず member 固定。
-- 同じログインで2回呼んだ場合は、行を作り直さず内容を更新する。
create or replace function public.register_me(
  p_name text, p_unit text, p_ul text, p_mentor text,
  p_join_date date, p_certified_grade int, p_code text
) returns uuid language plpgsql security definer set search_path = public as $fn$
declare v_id uuid; v_slug text;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  perform public.assert_team_passcode(p_code);
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
end $fn$;

-- 管理者キーを入れて、自分を UL に昇格させる。
-- キーが未設定のあいだは昇格できない（誰でも全員分を見られてしまうため）。
create or replace function public.claim_manager(p_code text)
returns text language plpgsql security definer set search_path = public, extensions as $fn$
declare v_id uuid := public.current_member_id(); v_hash text;
begin
  if v_id is null then raise exception 'not linked'; end if;
  select admin_passcode into v_hash from public.app_config where id = 1;
  if v_hash is null then raise exception '管理者キーがまだ設定されていません（SETUP.md 手順5）'; end if;
  if v_hash <> crypt(coalesce(p_code,''), v_hash) then raise exception '管理者キーが違います'; end if;

  update public.members set role = 'ul' where id = v_id and role = 'member';
  return (select role from public.members where id = v_id);
end $fn$;

-- マイシートの自己申告項目だけを更新する。role や auth_id には触れない。
create or replace function public.update_my_profile(
  p_name text, p_join_date date, p_certified_grade int,
  p_unit text default null, p_ul text default null, p_mentor text default null
) returns void language plpgsql security definer set search_path = public as $fn$
declare v_id uuid := public.current_member_id();
begin
  if v_id is null then raise exception 'not linked'; end if;
  if not public.is_active_member(v_id) then raise exception 'このアカウントは卒業・退職の扱いになっているため操作できません。心当たりがなければ育成・ULにご連絡ください'; end if;
  update public.members
     set name            = coalesce(nullif(trim(p_name),''), name),
         join_date       = coalesce(p_join_date, join_date),
         certified_grade = coalesce(p_certified_grade, certified_grade),
         unit            = coalesce(nullif(trim(p_unit),''),   unit),
         ul              = coalesce(nullif(trim(p_ul),''),     ul),
         mentor          = coalesce(nullif(trim(p_mentor),''), mentor)
   where id = v_id;
end $fn$;

grant execute on function public.claim_member(uuid,text)                             to authenticated;
grant execute on function public.admin_reset_login(uuid)                             to authenticated;
grant execute on function public.register_me(text,text,text,text,date,int,text)      to authenticated;
grant execute on function public.claim_manager(text)                                 to authenticated;
grant execute on function public.update_my_profile(text,date,int,text,text,text)     to authenticated;
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
