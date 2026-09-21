-- ============================================================
-- STEP｜ログインまわりの動作確認
-- ------------------------------------------------------------
-- 「誰が誰になれるか」は目で追うだけでは間違えるので、
-- 主な筋道をここで実際に動かして確かめられるようにしてある。
--
-- 使い方（ローカルのPostgreSQLで）
--   1. 空のDBを用意する
--   2. supabase/test/_stub.sql を流す（Supabase の auth.* を真似る）
--   3. supabase/schema.sql を流す
--   4. このファイルを流す。PASS / FAIL が並ぶ
--
-- 本番のSupabaseに対しては流さないこと（名簿を消す）。
-- ============================================================
create or replace function pg_temp.t(label text, got text, want text) returns void language plpgsql as $$
begin
  raise notice '%  %', case when got is not distinct from want then 'PASS' else 'FAIL (got='||coalesce(got,'NULL')||' want='||coalesce(want,'NULL')||')' end, label;
end $$;
create or replace function pg_temp.fails(label text, sql text, want text) returns void language plpgsql as $$
begin
  execute sql;
  raise notice 'FAIL (通ってしまった)  %', label;
exception when others then
  raise notice '%  %', case when sqlerrm like '%'||want||'%' then 'PASS' else 'FAIL (断り文=>'||sqlerrm||'<)' end, label;
end $$;

-- ============================================================
-- 下ごしらえ
-- ============================================================

-- ===== パスコード未設定のうちは、誰も登録できないこと（fail-closed）=====
update public.app_config set team_passcode = null, admin_passcode = null where id = 1;
select pg_temp.t('未設定なら、どんなパスコードでも通さない',
  public.check_team_passcode('なんでもいい')::text, 'false');
select pg_temp.t('未設定であることが分かる', public.team_passcode_set()::text, 'false');
insert into auth.users(id) values ('00000000-0000-0000-0000-0000000000a9') on conflict do nothing;
select set_config('test.uid','00000000-0000-0000-0000-0000000000a9',false);
select set_config('test.jwt','{"email":"m-newcomer@example.com"}',false);
select pg_temp.fails('未設定のあいだは登録できない',
  $$select public.register_me('誰か',null,null,null,null,null,'なんでもいい')$$,
  'まだ設定されていません');

-- ===== 設定したあと =====
update public.app_config
   set team_passcode  = crypt('step-sns-7k95yza3eu', gen_salt('bf')),
       admin_passcode = crypt('adminkey',            gen_salt('bf')),
       updated_at = now()
 where id = 1;
select pg_temp.t('設定済みであることが分かる', public.team_passcode_set()::text, 'true');
select pg_temp.t('正しいパスコードは通る',  public.check_team_passcode('step-sns-7k95yza3eu')::text, 'true');
select pg_temp.t('違うパスコードは通らない', public.check_team_passcode('ちがう')::text, 'false');
select pg_temp.t('空のパスコードは通らない', public.check_team_passcode('')::text,      'false');
select pg_temp.t('NULLのパスコードは通らない', public.check_team_passcode(null)::text,  'false');
select pg_temp.fails('パスコードが違うと登録できない',
  $$select public.register_me('誰か',null,null,null,null,null,'ちがう')$$, 'パスコードが違います');
select pg_temp.t('正しいパスコードなら登録できる',
  (public.register_me('新人','unitA',null,null,null,null,'step-sns-7k95yza3eu') is not null)::text, 'true');
select pg_temp.t('登録した人は必ず member から始まる',
  (select role from public.members where auth_id='00000000-0000-0000-0000-0000000000a9'), 'member');
delete from public.members where auth_id='00000000-0000-0000-0000-0000000000a9';

-- ===== 名簿の登場人物 =====
insert into auth.users(id) values
  ('00000000-0000-0000-0000-0000000000a1'),('00000000-0000-0000-0000-0000000000a2'),
  ('00000000-0000-0000-0000-0000000000a3') on conflict do nothing;
delete from public.members;
insert into public.members(id,auth_id,name,slug,role,active) values
  ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-0000000000a1','UL花子','ul-hanako','ul',true),
  ('00000000-0000-0000-0000-0000000000b2','00000000-0000-0000-0000-0000000000a2','山田太郎','yamada-taro','member',true);

-- ULとしてリセット
select set_config('test.uid','00000000-0000-0000-0000-0000000000a1',false);
select set_config('test.code', public.admin_reset_login('00000000-0000-0000-0000-0000000000b2'), false);
select pg_temp.t('コードは8文字', length(current_setting('test.code'))::text, '8');
select pg_temp.t('紛らわしい文字(0/O/1/I/l)を含まない',
  (current_setting('test.code') ~ '^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$')::text,'true');
select pg_temp.t('平文はDBに残らない',
  (select (claim_code_hash <> current_setting('test.code'))::text
     from public.members where id='00000000-0000-0000-0000-0000000000b2'), 'true');
select pg_temp.t('リセットで紐付けが外れる',
  (select (auth_id is null)::text from public.members where id='00000000-0000-0000-0000-0000000000b2'),'true');
select pg_temp.t('slugが振り直される',
  (select (slug <> 'yamada-taro')::text from public.members where id='00000000-0000-0000-0000-0000000000b2'),'true');

-- 名簿の漏れ方
select pg_temp.t('未設定の人のslugは検索に出ない',
  (select coalesce(slug,'(なし)') from public.roster_search('山田') limit 1), '(なし)');
select pg_temp.t('未設定でも名前は出る（本人が選べるように）',
  (select name from public.roster_search('山田') limit 1), '山田太郎');
select pg_temp.t('設定済みの人のslugは出る（ログインに要る）',
  (select slug from public.roster_search('UL花') limit 1), 'ul-hanako');
select pg_temp.t('ビューでも同じ',
  (select coalesce(slug,'(なし)') from public.member_roster where name='山田太郎'), '(なし)');

-- ★ 本題：共通パスコードだけで他人の行を掴めないこと
select set_config('test.uid','00000000-0000-0000-0000-0000000000a3',false);
select set_config('test.jwt','{"email":"m-attacker@example.com"}',false);
select pg_temp.t('共通パスコードでは他人になりすませない',
  coalesce(public.claim_member('00000000-0000-0000-0000-0000000000b2','step-sns-7k95yza3eu')::text,'(拒否)'),'(拒否)');
select pg_temp.t('でたらめなコードでもなりすませない',
  coalesce(public.claim_member('00000000-0000-0000-0000-0000000000b2','ZZZZZZZZ')::text,'(拒否)'),'(拒否)');
select public.claim_member('00000000-0000-0000-0000-0000000000b2','ZZZZZZZZ');
select public.claim_member('00000000-0000-0000-0000-0000000000b2','ZZZZZZZZ');
select public.claim_member('00000000-0000-0000-0000-0000000000b2','ZZZZZZZZ');
select pg_temp.t('間違えた回数がちゃんと残る（巻き戻らない）',
  (select claim_code_fails::text from public.members where id='00000000-0000-0000-0000-0000000000b2'),'5');
select pg_temp.fails('5回間違えると、正しいコードでも使えなくなる',
  $$select public.claim_member('00000000-0000-0000-0000-0000000000b2', current_setting('test.code'))$$,
  '使えなくなりました');

-- 発行し直せば、本人はちゃんと入れる
select set_config('test.uid','00000000-0000-0000-0000-0000000000a1',false);
select set_config('test.code', public.admin_reset_login('00000000-0000-0000-0000-0000000000b2'), false);
select set_config('test.uid','00000000-0000-0000-0000-0000000000a2',false);
select set_config('test.jwt','{"email":"m-newid99@example.com"}',false);
select pg_temp.t('正しいコードなら紐付く',
  public.claim_member('00000000-0000-0000-0000-0000000000b2', current_setting('test.code'))::text,
  '00000000-0000-0000-0000-0000000000b2');
select pg_temp.t('slugが新しいログインに合う',
  (select slug from public.members where id='00000000-0000-0000-0000-0000000000b2'), 'm-newid99');
select pg_temp.t('使ったコードは消える',
  (select (claim_code_hash is null)::text from public.members where id='00000000-0000-0000-0000-0000000000b2'),'true');
select pg_temp.t('記録は消えていない（名前が残る）',
  (select name from public.members where id='00000000-0000-0000-0000-0000000000b2'), '山田太郎');

-- 期限切れ
select set_config('test.uid','00000000-0000-0000-0000-0000000000a1',false);
select set_config('test.code', public.admin_reset_login('00000000-0000-0000-0000-0000000000b2'), false);
update public.members set claim_code_expires = now() - interval '1 day'
 where id='00000000-0000-0000-0000-0000000000b2';
select set_config('test.uid','00000000-0000-0000-0000-0000000000a3',false);
select set_config('test.jwt','{"email":"m-late@example.com"}',false);
select pg_temp.fails('期限切れのコードは使えない',
  $$select public.claim_member('00000000-0000-0000-0000-0000000000b2', current_setting('test.code'))$$,
  '有効期限が切れています');

-- メンバーが自分を昇格できないこと
select set_config('test.uid','00000000-0000-0000-0000-0000000000a2',false);
select pg_temp.fails('メンバーは他人のログインをリセットできない',
  $$select public.admin_reset_login('00000000-0000-0000-0000-0000000000b1')$$,
  '権限がありません');
-- 管理者キー（claim_manager は request_manager に一本化済み）
update public.members set auth_id='00000000-0000-0000-0000-0000000000a2',
       admin_key_fails=0, admin_key_locked_until=null
 where id='00000000-0000-0000-0000-0000000000b2';
select set_config('test.uid','00000000-0000-0000-0000-0000000000a2',false);
select pg_temp.t('キーが違えば昇格できない', public.request_manager('ちがうキー'), 'bad-key');
select pg_temp.t('メンバーのままでいる',
  (select role from public.members where id='00000000-0000-0000-0000-0000000000b2'), 'member');

/* 間違えた回数が巻き戻らないこと。
   以前はここで例外を投げていたため、update ごと巻き戻って
   「5回でロック」が一度も効いていなかった。 */
select public.request_manager('ちがうキー');
select public.request_manager('ちがうキー');
select public.request_manager('ちがうキー');
select pg_temp.t('4回目まではロックしない',
  (select admin_key_fails||'/'||coalesce(admin_key_locked_until::text,'ロックなし')
     from public.members where id='00000000-0000-0000-0000-0000000000b2'), '4/ロックなし');
select public.request_manager('ちがうキー');
select pg_temp.t('5回でロックがかかる',
  (select admin_key_fails||'/'||(admin_key_locked_until is not null)::text
     from public.members where id='00000000-0000-0000-0000-0000000000b2'), '5/true');
select pg_temp.fails('ロック中は正しいキーでも試せない',
  $$select public.request_manager('adminkey')$$, 'しばらく試せません');

-- ロックを手で解いてから。
-- （同じ文の中で members を更新しながら request_manager を呼ぶと、
--   同一スナップショットのため関数側の update が効かない。文を分ける）
update public.members set admin_key_fails=0, admin_key_locked_until=null
 where id='00000000-0000-0000-0000-0000000000b2';
select pg_temp.t('正しいキーなら昇格できる',
  public.request_manager('adminkey','mentor'), 'approved');
select pg_temp.t('選んだ権限が付く',
  (select role from public.members where id='00000000-0000-0000-0000-0000000000b2'), 'mentor');
update public.members set role='member' where id='00000000-0000-0000-0000-0000000000b2';

-- リセット依頼
select pg_temp.t('依頼を出せる', (select public.request_login_reset('00000000-0000-0000-0000-0000000000b2'))::text, '');
select pg_temp.t('依頼が1件たつ',
  (select count(*)::text from public.login_requests where member_id='00000000-0000-0000-0000-0000000000b2'),'1');
select public.request_login_reset('00000000-0000-0000-0000-0000000000b2');
select public.request_login_reset('00000000-0000-0000-0000-0000000000b2');
select pg_temp.t('連打しても増えない（10分に1回）',
  (select times::text from public.login_requests where member_id='00000000-0000-0000-0000-0000000000b2'),'1');
select pg_temp.fails('いない人には依頼を出せない',
  $$select public.request_login_reset('00000000-0000-0000-0000-0000000000bf')$$, '見つかりません');
select set_config('test.uid','00000000-0000-0000-0000-0000000000a1',false);
select public.admin_reset_login('00000000-0000-0000-0000-0000000000b2');
select pg_temp.t('リセットすると依頼は片付く',
  (select count(*)::text from public.login_requests where member_id='00000000-0000-0000-0000-0000000000b2'),'0');
