-- ============================================================
-- STEP｜キャリアステップシート  Supabase スキーマ  （4/4）
-- しきい値・期とユニット編成・ログインリセットの依頼
-- ------------------------------------------------------------
-- Supabase の SQL Editor に貼り付けて RUN してください。
-- **1 から順に、1ファイルずつ** です。順番は入れ替えないでください。
-- 何度実行しても壊れないように書いてあります。
--
-- 元は1つのファイルでしたが、SQL Editor が長い入力を途中で切ってしまい
-- 「syntax error」で止まるため、貼れる大きさに分けてあります。
-- ============================================================

-- ============================================================
-- 5.8 アラートのしきい値を画面から変えられるようにする
--     「何日でチェックが止まっていたら停滞とみなすか」などを
--     コードではなく管理画面から設定する。
-- ============================================================
alter table public.app_config add column if not exists settings jsonb not null default '{}'::jsonb;

create or replace function public.get_app_settings()
returns jsonb language sql stable security definer set search_path = public as $fn$
  select settings from public.app_config where id = 1 and public.is_manager()
$fn$;

create or replace function public.set_app_settings(p_settings jsonb)
returns jsonb language plpgsql security definer set search_path = public as $fn$
begin
  if not public.is_manager() then raise exception 'この操作をする権限がありません'; end if;
  update public.app_config set settings = coalesce(p_settings, '{}'::jsonb), updated_at = now() where id = 1;
  return (select settings from public.app_config where id = 1);
end $fn$;

-- 関数の実行権限は既定で PUBLIC に付くので、明示的に落としてから配り直す。
revoke all on function public.get_app_settings()      from public;
revoke all on function public.set_app_settings(jsonb) from public;
grant execute on function public.get_app_settings()      to authenticated;
grant execute on function public.set_app_settings(jsonb) to authenticated;

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
--   ('山田 太郎', 'yamada-taro', 'unitA', '佐藤 花子', '鈴木 一郎', '2026-04-01', 2, 'member')
-- on conflict (slug) do nothing;

-- ============================================================
-- 7. 期（半期）とユニット編成
--    ------------------------------------------------------------
--    members.unit / ul / mentor は1つのカラムしか無いため、
--    半期ごとの編成替えで上書きすると前期の所属とULが消えてしまう。
--    引き継ぎのときに「この子は前期どのユニットで誰の下だったか」を
--    出せないのはそのため。
--
--    そこで「期」と「期ごとの割当」を別に持つ。
--      terms       … 2026上期 のような期。開始日・終了日・状態
--      assignments … 期 × メンバー = 1行。その期の所属・担当・稼働
--
--    members.unit / ul / mentor は残す。これらは「いまの割当のキャッシュ」で、
--    期を確定（apply_term）したときに assignments から書き戻される。
--    既存の画面・RLS・ログイン画面の名簿はこれまでどおり members を見る。
-- ============================================================

create table if not exists public.terms (
  id         uuid primary key default gen_random_uuid(),
  name       text not null unique,                 -- 例：2026上期
  starts_on  date not null,
  ends_on    date,
  status     text not null default 'draft',        -- draft:編成中 / active:いまの期 / closed:終了
  note       text,
  created_at timestamptz not null default now()
);
alter table public.terms drop constraint if exists terms_status_chk;
alter table public.terms add constraint terms_status_chk
  check (status in ('draft','active','closed'));
create index if not exists terms_start_idx on public.terms(starts_on desc);

create table if not exists public.assignments (
  id           uuid primary key default gen_random_uuid(),
  term_id      uuid not null references public.terms(id)   on delete cascade,
  member_id    uuid not null references public.members(id) on delete cascade,
  unit         text,
  ul           text,
  mentor       text,
  weekly_hours numeric,                              -- 週の稼働時間（その期の見込み）
  acc_std      int,                                  -- スタンダード運用の社数
  acc_adv      int,                                  -- アドバンス運用の社数
  note         text,
  /* 引き継ぎシート。前のULが埋める定型項目を入れる。
     { strength, weakness, comm, landmine, next, filled_by, filled_at } */
  handover     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (term_id, member_id)
);
create index if not exists assignments_term_idx   on public.assignments(term_id);
create index if not exists assignments_member_idx on public.assignments(member_id);

alter table public.terms       enable row level security;
alter table public.assignments enable row level security;

-- 期そのものは全員が読めてよい（本人画面に「来期の所属」を出すため）。書けるのは管理者だけ。
drop policy if exists terms_read   on public.terms;
drop policy if exists terms_write  on public.terms;
drop policy if exists terms_update on public.terms;
drop policy if exists terms_delete on public.terms;
create policy terms_read on public.terms for select to authenticated using (true);
create policy terms_write on public.terms for insert to authenticated
  with check (public.is_manager());
create policy terms_update on public.terms for update to authenticated
  using (public.is_manager()) with check (public.is_manager());
create policy terms_delete on public.terms for delete to authenticated
  using (public.is_manager());

-- 割当は、本人は自分の行だけ。管理者は全員ぶん。
-- 引き継ぎシート（handover）には本人に見せたくない内容も入るため、
-- 本人向けには下の my_assignments ビューで列を絞って返す。
drop policy if exists asg_read   on public.assignments;
drop policy if exists asg_write  on public.assignments;
drop policy if exists asg_update on public.assignments;
drop policy if exists asg_delete on public.assignments;
create policy asg_read on public.assignments for select to authenticated
  using (public.is_manager());
create policy asg_write on public.assignments for insert to authenticated
  with check (public.is_manager());
create policy asg_update on public.assignments for update to authenticated
  using (public.is_manager()) with check (public.is_manager());
create policy asg_delete on public.assignments for delete to authenticated
  using (public.is_manager());

/* 本人が見てよい範囲だけの割当。handover は含めない。
   security_invoker = false なので、このビュー越しなら本人でも読める。 */
drop view if exists public.my_assignments;
create view public.my_assignments with (security_invoker = false) as
  select a.id, a.term_id, a.member_id, a.unit, a.ul, a.mentor,
         t.name as term_name, t.starts_on, t.ends_on, t.status
    from public.assignments a
    join public.terms t on t.id = a.term_id
   where a.member_id = public.current_member_id();
grant select on public.my_assignments to authenticated;

/* 期を確定する。
   その期の割当を members に書き戻し（＝いまの所属になる）、
   その期を active に、ほかの active を closed にする。
   1人ずつ更新すると途中で失敗したときに名簿が半端な状態で残るので、
   まとめて1つのトランザクションで行う。 */
create or replace function public.apply_term(p_term uuid)
returns int language plpgsql security definer set search_path = public as $fn$
declare v_n int;
begin
  if not public.is_manager() then raise exception 'この操作をする権限がありません'; end if;
  if not exists (select 1 from public.terms where id = p_term) then
    raise exception 'その期は見つかりません';
  end if;

  update public.members m
     set unit   = a.unit,
         ul     = a.ul,
         mentor = a.mentor
    from public.assignments a
   where a.term_id = p_term and a.member_id = m.id and m.active;
  get diagnostics v_n = row_count;

  update public.terms set status = 'closed' where status = 'active' and id <> p_term;
  update public.terms set status = 'active' where id = p_term;
  return v_n;
end $fn$;
revoke all on function public.apply_term(uuid) from public;
grant execute on function public.apply_term(uuid) to authenticated;

-- ============================================================
-- 8. ログインリセットの依頼
--    ------------------------------------------------------------
--    パスワードを忘れた人は、これまで「UL・育成を捕まえる」以外に
--    手段がなかった。夜や休日に詰まると翌営業日まで止まる。
--
--    ログイン画面から自分で依頼を出せるようにして、管理者画面の
--    「今日のアクション」に出す。ULは気づいた時点で1クリックで
--    リセットし、出てきたログイン用コードを本人に渡す。
--
--    未ログインの人が呼ぶので、書けるのは「誰が困っているか」だけ。
--    自由入力は受け取らない（連絡手段として悪用されないように）。
--    1人1行（主キー）＋10分に1回までなので、量も増えない。
-- ============================================================
create table if not exists public.login_requests (
  member_id    uuid primary key references public.members(id) on delete cascade,
  requested_at timestamptz not null default now(),
  times        int not null default 1        -- 何回頼んだか（急ぎ具合の目安）
);
alter table public.login_requests enable row level security;

-- 管理者だけが読める／消せる。書き込みは下の関数からだけ。
drop policy if exists loginreq_read   on public.login_requests;
drop policy if exists loginreq_delete on public.login_requests;
create policy loginreq_read on public.login_requests for select to authenticated
  using (public.is_manager());
create policy loginreq_delete on public.login_requests for delete to authenticated
  using (public.is_manager());

create or replace function public.request_login_reset(p_member_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
declare v_last timestamptz;
begin
  if not exists (select 1 from public.members where id = p_member_id and active) then
    raise exception '対象が見つかりません';
  end if;

  select requested_at into v_last from public.login_requests where member_id = p_member_id;
  if v_last is not null and v_last > now() - interval '10 minutes' then
    /* 連打しても増やさない。すでに届いているので、これは成功扱いでいい */
    return;
  end if;

  insert into public.login_requests(member_id) values (p_member_id)
  on conflict (member_id) do update
    set requested_at = now(), times = public.login_requests.times + 1;
end $fn$;
grant execute on function public.request_login_reset(uuid) to anon, authenticated;

-- リセットしたら依頼は片付ける（admin_reset_login の中から呼ばれる）。
create or replace function public.clear_login_request(p_member_id uuid)
returns void language plpgsql security definer set search_path = public as $fn$
begin
  if not public.is_manager() then raise exception 'この操作をする権限がありません'; end if;
  delete from public.login_requests where member_id = p_member_id;
end $fn$;
grant execute on function public.clear_login_request(uuid) to authenticated;
