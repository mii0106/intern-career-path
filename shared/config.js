/* ============================================================
   STEP — 接続設定
   ------------------------------------------------------------
   ここに Supabase の情報を入れるとチーム全員でデータを共有する
   「共有モード」になります。空のままだと、いままでどおり
   自分の端末だけに保存する「ローカルモード」で動きます。

   入れる値は Supabase の
     Project Settings → API Keys / Data API
   にある2つです。
     ・Project URL                → SUPABASE_URL
     ・publishable（旧 anon public）のキー → SUPABASE_ANON_KEY

   SUPABASE_URL は末尾に /rest/v1/ を付けないでください。
   SDKが自分で /rest/v1/ や /auth/v1/ を足すので、付けると
   /rest/v1/rest/v1/... になって全部404になります。

   publishable キーはブラウザから見える前提の公開キーです。
   実際のアクセス制御は Supabase 側の RLS（supabase/schema.sql）で
   かけているので、ここに貼って問題ありません。
   secret（旧 service_role）のキーは絶対に貼らないでください。
   ============================================================ */
window.STEP_CONFIG = {
  SUPABASE_URL: 'https://obunqfhalsqnzhdhacvr.supabase.co',
  SUPABASE_ANON_KEY: 'sb_publishable_NPEAWWLvL4IPcEKPtgwgWg_6hLcrgvt',

  /* ログインの内部IDに使う、全員共通の固定ドメイン。
     ここは「本人のメールアドレス」ではありません。
     メンバーが自分のメールアドレスを入力する画面は1つもなく、
     インターン生が使っているメールの種類（Gmail・大学・キャリア等）は
     登録にもログインにも一切関係しません。

       田中さん → m-6x1oi8dcgp@intern-career-path.vercel.app
       佐藤さん → m-k2p9wq3lzx@intern-career-path.vercel.app

     @ の前はランダムな内部IDで、氏名とも本人のアドレスとも無関係です。

     このアプリはメールを1通も送りません（送りうるのは登録時の signUp だけで、
     Supabase側で Confirm email をオフにすれば送信は発生しません。
     パスワード再設定もマジックリンクも使っていません）。

     そのうえで、万一 Confirm email が誤ってオンに戻された場合でも
     誰の受信箱にも届かないよう、メールを受け取る仕組みを持たない
     このアプリ自身のドメインを使っています。
     自社ドメインを使うと、その場合に社内へ配信が試みられてしまいます。

     ※架空のTLD（.local / .test / .internal など）は Supabase Auth が
       「Email address ... is invalid」として弾くので使えません。
     ※すでに登録した人がいる状態でここを変えると、その人のログインは
       繋がらなくなります（管理画面の「ログインをリセットする」で復旧できます）。 */
  AUTH_EMAIL_DOMAIN: 'intern-career-path.vercel.app',

  /* 何日チェックが動いていなければ「停滞」として管理者画面で拾うか */
  STALE_DAYS: 14,

  /* 標準期間を何ヶ月超えたら「遅れ」として警告色にするか */
  DELAY_ALERT_MONTHS: 1
};
