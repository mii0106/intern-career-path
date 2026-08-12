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

  /* ログインに使う内部的なメールアドレスのドメイン。
     氏名ではなく m-xxxxxx のようなランダムな内部IDと組み合わせて使うだけで、
     実際にメールを送ることはありません（Supabase側でメール確認をオフにします）。

     ここは「実在するTLDのドメイン」でなければなりません。
     step-app.local のような架空のTLDは Supabase Auth が
       Email address "m-xxxxxx@step-app.local" is invalid
     として弾きます（.local / .test / .internal などは実在しないTLDのため）。

     そのため自社ドメインを使っています。このドメイン宛にメールが飛ぶことは
     ありませんが、気になる場合は自社で持っている別のドメインに変えてください。

     ※すでに登録した人がいる状態でここを変えると、その人のログインは
       繋がらなくなります（管理画面の「ログインをリセットする」で復旧できます）。 */
  AUTH_EMAIL_DOMAIN: 'sho-san.co.jp',

  /* 何日チェックが動いていなければ「停滞」として管理者画面で拾うか */
  STALE_DAYS: 14,

  /* 標準期間を何ヶ月超えたら「遅れ」として警告色にするか */
  DELAY_ALERT_MONTHS: 1
};
