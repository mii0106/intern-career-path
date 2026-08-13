/* ============================================================
   STEP — キャリアステップ定義（インターン側・管理者側で共有）
   Notionのキャリアステップシートをそのまま格納
   ============================================================ */
const TIERS = {
  starter:{name:'スターター', c:'--violet', soft:'--violet-soft', hex:'#5B3DF5'},
  player:{name:'プレイヤー', c:'--mint', soft:'--mint-soft', hex:'#17B98A'},
  pro:{name:'プロフェッショナル', c:'--sky', soft:'--sky-soft', hex:'#2E8FE0'},
  leader:{name:'リーダー', c:'--amber', soft:'--amber-soft', hex:'#F59E17'},
  exec:{name:'エグゼクティブ', c:'--coral', soft:'--coral-soft', hex:'#F2536A'}
};

const GRADES = [
{n:1,tier:'starter',period:'1ヶ月',
 vision:['インプットの完了','スタンダードアカウント運用ができる'],
 sections:[
  {title:'スタンス｜アリエナイ基準を厳守して行動している',items:[
    '2ヶ月連続フォロワー増加100以下になっていない（他人が手伝った場合も対象）',
    '投稿ミス・漏れ（準備・ストーリー）が3ヶ月以内に3回未満',
    '遅刻月2回が2ヶ月以上発生していない',
    '改善策を自分から出せる・対応できる',
    'その他スタンス面（クライアント様へご迷惑をかける行為等）が発生していない']},
  {title:'コミュニケーション｜聞く力',items:[
    '上司の指示を理解し実行に移せる',
    '不明点をそのままにせず、周囲に確認して解消できる',
    '業務上の報告・連絡・相談を適切なタイミングでできる']},
  {title:'タスク管理｜ToDo管理',items:[
    '日々のタスクを認識できている',
    '日次・月次のスケジュールを立てられる',
    '日報（attendance）で次回予定の記載、管理ができる']},
  {title:'業務スキル｜知見（インプット）',items:[
    'スキルアップリスト「アカウント運用開始」のシートまで完了',
    'ラーニングボックススターター編読了',
    'Notionで不明点を自己解決できる']},
  {title:'業務スキル｜運用（基本運用）',items:[
    '基本的な投稿作成・ストーリーズ投稿ができる',
    'Instagramのアルゴリズムに適した画像選定ができる（高数値投稿の画像傾向を分析し、再現できる）',
    'Social drive / AIproで適切な分析ができる（数値確認ができる／見方を理解しているレベル）',
    'レポートの記載ができる',
    'スタンダードアカウントの運用が、質を担保した状態で可能である',
    '【Canva基礎】青空加工・ぼかし加工ができる／画像リールの作成ができる']}
 ]},

{n:2,tier:'starter',period:'2ヶ月',
 vision:['2社のスタンダード運用が滞りなくできる'],
 sections:[
  {title:'スタンス｜社内から信頼されて、アカウントを任せられる状態（池田塾10ヶ条）',items:[
    'レスは最短【意思表示も合わせてする】',
    'タスクの優先度を精査する',
    '自分の前後の仕事に思いをはせる',
    '相手の立場を慮る',
    'ボールの持ち主を常に確認する',
    '意図・目的を理解する',
    'まずは一歩踏み出す',
    '出来ない理由ではなく、出来る方法を考える',
    '周囲からの期待を自覚する',
    '周りに興味をもつ',
    '自分事化ができている（自分が最終責任者）']},
  {title:'コミュニケーション｜相互コミュニケーション',items:[
    'ユニットメンバー同士でコミュニケーションが取れる',
    'ユニット定例で適切な共有ができる',
    '指揮系統を理解したうえでの報連相']},
  {title:'タスク管理｜納期厳守（投稿作成）',items:['納期遅延・タスク履行漏れを起こさない']},
  {title:'業務スキル｜知見（定着・実行）',items:[
    'マニュアルに沿った運用ができる',
    'インプットしたノウハウを確実に実行できる']},
  {title:'業務スキル｜運用（プレイヤー基準のクリア）',items:[
    'フォロワー200／月（フォロー制限時にも適切な対応ができる）',
    '2アカウント以上の運用',
    '商圏理解およびペルソナに基づいた運用ができている（ペルソナ分析実施済み）',
    'メンバー予約投稿のWチェックができる（トリプルチェック必要）',
    {t:'クライアントに提出できるレベルのレポートが一人で作成できる',sub:['数値の変化に対して自分なりの考察が書けている']}]},
  {title:'AI活用｜AI基礎知識のインプット',ai:true,groups:[
    {label:'なりたい姿',items:[
      'AIを知って触れる',
      'チャットにてAI使用ができる',
      '質問をする前にAIに聞き、会話コストを減らせる',
      '日常的にAIに触れる習慣がついている']},
    {label:'スキル感｜定量・定性',items:[
      'AIを用いてプロンプトの作成ができる（前提の定義／どの立場で分析するのか等）',
      'AIツールの使い分けについての理解がある（Gemini、ChatGPT、Claudeの違いを認識）',
      {t:'ノートブックLMにてAI基礎クイズを解く（9/10以上正解で達成）',link:'https://notebooklm.google.com/notebook/e188464f-8003-4b1f-889b-f6f2a103728e?authuser=2'}]}
  ]}
 ]},

{n:3,tier:'player',period:'3ヶ月',
 vision:['リーダーのチェックを受けながら、アドバンス運用の全工程（投稿・ストーリー・ハイライト・イベントスケジュール管理等）を実行できる'],
 sections:[
  {title:'コミュニケーション｜メンバー交流',items:[
    '他Unitのメンバーやリーダーとコミュニケーションが取れる',
    '他Unitのメンバーやリーダー含めて、情報共有ができる']},
  {title:'タスク管理｜質・スピード',items:['タスク消化の質を担保しながら、スピード感高く業務遂行ができる']},
  {title:'業務スキル｜知見（アウトプット）',items:[
    'マニュアルに対して鵜呑みでなく自分なりの解釈のアウトプットができる',
    '既存のマニュアルなどに対して、改善提案ができる']},
  {title:'業務スキル｜運用（アドバンス運用の対応）',items:[
    'アドバンス投稿に必要な画像加工（背景修正・電線除去・家具の追加等）を、Canvaやnanobananaを活用して行える',
    'リールのサムネイルを一人で作成できる',
    'ハイライトの運用ができる',
    'スタンダードの新規会社を受け入れることができる',
    '自身の運用しているアカウントを新人メンバーに引き継ぎ対応できる',
    '新人に渡した後でも、成果を継続できる引き継ぎができる',
    {t:'デザイン',sub:['UnitDデザインレクチャー会_0515 インプット済み','上記の内容を理解したうえで、実際にAIを用いてデザイン作成ができる']}]}
 ]},

{n:4,tier:'player',period:'4ヶ月',
 note:'⚠️ プロフェ昇格面談前に、改めて担当アカウントの理解度を高めましょう！面談時に内容を確認します。すでに担当アカウントについてまとまった資料（戦略メモ・運用設計など）がある人は、それを使ってもOKです。',
 vision:['担当アカウントの課題を究明したうえで、打ち手を考え実行に移すことができる','フロントとの円滑なコミュニケーションから必要な情報を集めることができる'],
 sections:[
  {title:'スタンス',items:[
    'リーダーフォローの下、クライアントがアドバンス運用を任せてよかったと思えるような運用ができる',
    '担当業務の状況をチームに共有できている',
    'メンバーが困っているときに声をかけられる状態にある',
    'クレドを意識し、体現できている']},
  {title:'コミュニケーション｜フロント・外部連携（基礎）',items:['フロントとコミュニケーションが取れる']},
  {title:'タスク管理｜完全自走（PDCAを自分で回せる）',items:[
    'タスクの実行を自走できる',
    '自ら考え、能動的に課題解決できる']},
  {title:'組織運営',items:[
    'ユニット定例で自分の担当状況を報告できる',
    '困っているメンバーを見つけたとき、リーダーに報告または直接声をかけられる']},
  {title:'業務スキル｜知見（ナレッジ創出・発信）',items:[
    '自発的に新しい情報を取りにいくことができる',
    '自ら検証などを行うことができる',
    'ナレッジ賞にノミネートされるレベルのナレッジの創出・発信ができる']},
  {title:'業務スキル｜運用（運用成果創出）',items:[
    '【主指標】フォロワー200以上／月を2ヶ月連続で達成、かつCV獲得1件以上',
    '【副指標】担当アカウントの課題となる指標（リーチ、ENG、リンククリック、プロフアクセス等）の改善（任意記録）']},
  {title:'AI活用｜アウトプットメイン（施策の壁打ち、運用で使う）',ai:true,groups:[
    {label:'なりたい姿',items:[
      'AIで精度の高い成果物を生成し業務で成果につなげることができる',
      'AIユースケースインプット、実践画像生成・プロンプト作成ができる',
      'Claude Codeの概要と危険性を理解することができる状態になる',
      {t:'バイブコーディングの基礎がわかる（クイズ9/10以上正解で達成）',link:'https://notebooklm.google.com/notebook/6d195191-fcb5-4711-af7b-71f427fd0588'}]},
    {label:'業務スキル｜定量・定性',items:[
      'アドバンス定例でAIと壁打ちした施策を提案し、根拠を説明できる',
      '業務内でのAI使用をしている（★投稿の画像生成 ★キャプション作成）']}
  ]}
 ]},

{n:5,tier:'pro',period:'5ヶ月',
 vision:['アカウント戦略を描き成果創出まで自立自走で可能','自分の担当アカウントで継続的に結果を出せる'],
 sections:[
  {title:'スタンス',items:['集めた情報から戦略を自ら描き、自分の担当アカウントで成果を出すことにこだわれる']},
  {title:'コミュニケーション｜フロント・外部連携（応用）',items:[
    'フロントからクライアントのニーズを自ら引き出した上で、適切な運用改善ができる',
    '自ら戦略を言語化し、伝えることができる']},
  {title:'タスク管理｜自分のタスク',items:[
    '期限を守る・約束を守る',
    '細かいところまで気を配り、丁寧な仕事をする',
    '周囲の期待を超えるアウトプットを意識する']},
  {title:'組織運営｜メンバー協働',items:[
    'メンバーへ納期の声かけができる',
    'タスク漏れの指摘やサポートができる',
    '他の人のボールを把握できる',
    'リーダー不在時などのサポート対応ができる',
    'メンバーの運用会社の動き理解、ミス発生時の把握']},
  {title:'業務スキル｜知見（レクチャー）',items:[
    '習得した知識・知見をメンバーにアウトプットできる（ユニット定例、ナレッジ）',
    'インスタのアルゴリズムや運用方法を新人にアウトプットできる']},
  {title:'業務スキル｜知見（インプット）',items:['最新のトレンドや業界の動向をリサーチし、業務に活かす']},
  {title:'業務スキル｜運用（アドバンス運用の対応）',items:[
    'アドバンスアカウント2社ともCVが出せる',
    'アドバンスアカウントのチェック（投稿、レポート、ストーリー等）ができる',
    '他のunit活動のために業務効率化できる状態',
    '新規のアドバンスアカウントを受け入れることができる（戦略設計ができる）']}
 ]},

{n:6,tier:'pro',period:'6ヶ月',
 vision:['自身の担当アカウントで成果を継続的に出せるうえで、困っているメンバーを助けることができる'],
 sections:[
  {title:'スタンス',items:[
    '運用アカウントに対し、集めた情報から貢献（主にCV出し）する為の戦略を自ら描くことができる',
    'ユニットがよりよい方向に向かう為の施策を自ら考え、行動できる']},
  {title:'コミュニケーション｜フロント・外部連携（応用）',items:[
    'フロントからクライアントのニーズを自ら引き出した上で、適切な運用改善ができる',
    '自ら戦略を言語化し、伝えることができる']},
  {title:'タスク管理｜アカウント運用でのタスク意識',items:['周囲の期待を超えるアウトプットを意識する']},
  {title:'タスク管理｜ユニットでのタスク意識',items:[
    '納期の声かけができる',
    'タスク履行漏れの指摘やサポートができる',
    '他の人のボールを把握できる',
    '自分のボールを少しでも進められる']},
  {title:'組織運営｜メンバー協働（育成応用）',items:[
    '個人ではなく「組織の成果」を最優先に考える',
    'チームの成長を促す行動を取る（知識の共有、仕組み化など）']},
  {title:'業務スキル｜知見（レクチャー）',items:[
    '習得した知識・知見をメンバーにアウトプットできる（ユニット定例、ナレッジ）',
    'インスタのアルゴリズムや運用方法を新人にアウトプットできる']},
  {title:'業務スキル｜運用（圧倒的な成果へのこだわり）',items:[
    '「頑張った」ではなく、「価値を提供できたか？」を意識する',
    '「早くて質が高い」仕事を目指す（どちらか一方ではなく、両方）']},
  {title:'業務スキル｜運用（他のメンバーの成果創出フォロー）',items:[
    'アドバンス定例において、担当アカウントの状況を過不足なく説明できる',
    'ユニットメンバーの運用面での補助ができる']},
  {title:'AI活用',ai:true,groups:[
    {label:'なりたい姿',items:[
      'AIで新しい価値を生み出す＋unit内に広め始める',
      '最新AI情報を自分でキャッチアップ・発信、組織でAI推進ができる',
      'AI活用で生まれた余白を次の業務に活用できている']},
    {label:'業務スキル｜定量・定性',items:[
      '業務の中でAIを使って何か試した経験がある（アカウント設計、投稿作成、工数削減、業務管理などで具体的な課題に対するアプローチとして）',
      '日常の業務の中でスターター・プレイヤーのAI活用をサポートしている']}
  ]}
 ]},

{n:7,tier:'leader',period:'8ヶ月',
 vision:['リーダーと一緒に組織運営ができる'],
 sections:[
  {title:'スタンス',items:[
    '圧倒的な当事者意識を持っている',
    '成長マインドセットを持っている',
    '単にスキルがある人ではなく、成果を出し続ける人である']},
  {title:'コミュニケーション｜改善方針の起案（社内）',items:['指示された内容以外でも、運用面での改善提案ができる（対フロント）']},
  {title:'コミュニケーション｜対外的な役割',items:[
    '社員・リーダーとの橋渡しを行う',
    '他のUnitなどと協働する',
    'チームの代表として成果や問題点を報告できる']},
  {title:'タスク管理｜ユニットメンバー管理',items:['ユニット全体の納期管理ができる']},
  {title:'組織運営｜UL業務（基礎）',items:[
    'メンバーのエスカレ処理ができる',
    'メンバーの面談ができる',
    'アカウント差配ができる',
    '勤務時間・スキル・アカウント数字・求められていることの理解などを鑑みる']},
  {title:'業務スキル｜知見（ユニット横断）',items:[
    '習得した知識・知見をメンバーにレクチャーできる',
    'インスタのアルゴリズムや運用方法を新人にレクチャーできる',
    'ナレッジ箱の中に成果を格納する']},
  {title:'業務スキル｜運用（メンバーディレクション）',items:[
    '運用レポートのチェックができる',
    'アドバンスの企画・投稿予約チェックができる',
    'アドバンス会議への参加・ファシリができる',
    {t:'アポ同行（1回以上参加）',sub:['レポート自分で報告（任意、アカウントによる）']}]}
 ]},

{n:8,tier:'leader',period:'9ヶ月',
 vision:['一人でメンバーマネジメントができる','リーダー育成ができる'],
 sections:[
  {title:'スタンス',items:[
    'メンバーの成長を促し喜べる',
    '高いコミュニケーション能力がある',
    '信頼を積み重ねている']},
  {title:'コミュニケーション｜改善方針の起案（社外）',items:[
    '指示された内容以外でも、運用面での改善提案ができる（対クライアント）',
    'クライアントへの振り返りプレゼンなどが任せられる']},
  {title:'コミュニケーション｜対外的な役割',items:['他部署の社員ともコミュニケーションが問題なく行える']},
  {title:'タスク管理｜ユニット管理',items:['取りこぼしがあったタスクを全て自分ごとにし、対応しようとする状態']},
  {title:'組織運営｜UL業務（応用）',items:[
    '適切な目標設定、行動マネジメント、モチベーション管理ができる',
    'Unit内でのスタンス・方針を発信し、チーム感を作り扇動できる']},
  {title:'業務スキル｜知見（外からの情報収集と展開）',items:[
    '社外（YouTube、記事、セミナーなど）からの積極的な情報収集とトレンドキャッチ',
    '最新情報の全体に向けた展開']},
  {title:'業務スキル｜運用（運用企画）',items:[
    '成果を上げるための新たな運用方法を企画できる',
    '効率の良い運用フローを企画できる']},
  {title:'AI活用',ai:true,groups:[
    {label:'なりたい姿',items:[
      'AIを用いた突破力：AIを中心に業務を設計・実行できる',
      'AI活用の横展開：Claude Codeを用いて業務上の課題を解決するツールを開発・実装できる',
      'リーダー業務として業務改善にClaude Codeの使用ができる']},
    {label:'業務スキル｜定量・定性',items:[
      'ナレッジ共有・勉強会・ツール整備などを通じてAI活用が広まる仕組みを自ら作り、組織に還元できている']}
  ]}
 ]},

{n:9,tier:'exec',period:'12ヶ月',
 vision:['事業責任者になれる'],
 sections:[
  {title:'スタンス｜6SENSEの体現',items:['6SENSEを体現している']},
  {title:'個別設定',custom:true,note:'各項目は面談時に本人とすり合わせて設定する。社会人としての即戦力レベルであることが基準。',items:[
    '社会人基礎｜コミュニケーション','社会人基礎｜タスク管理','社会人基礎｜組織運営',
    '業務スキル｜知見','業務スキル｜運用','専属Unit業務']},
  {title:'AI活用',ai:true,groups:[
    {label:'なりたい姿',items:['AIを用いた新規事業の創出','全ての業務でAIの使用']},
    {label:'業務スキル｜定量・定性',items:[
      'AIを用いた新規事業を創出・運営ができている',
      '全ての業務においてのAI活用をしており、それが周囲から見て明らかである']}
  ]}
 ]},

{n:10,tier:'exec',period:'—',
 vision:['事業責任者として組織を牽引できる'],
 sections:[
  {title:'個別設定',custom:true,note:'各項目は面談時に本人とすり合わせて設定する。社会人としての即戦力レベルであることが基準。',items:[
    '社会人基礎｜コミュニケーション','社会人基礎｜タスク管理','社会人基礎｜組織運営',
    '業務スキル｜知見','業務スキル｜運用','専属Unit業務']},
  {title:'AI活用',ai:true,groups:[
    {label:'なりたい姿',items:['AIを用いた新規事業の創出','全ての業務でAIの使用']},
    {label:'業務スキル｜定量・定性',items:[
      'AIを用いた新規事業を創出・運営ができている',
      '全ての業務においてのAI活用をしており、それが周囲から見て明らかである']}
  ]}
 ]}
];

const ATARIMAE = [
  {k:'late',n:'遅刻数',d:'前日報告以外の遅刻（朝のattendance含む）は月2回以下であること。2ヶ月以上あった場合は除籍対象'},
  {k:'kintai',n:'勤怠管理',d:'連絡なくシフトの修正を行わない'},
  {k:'taido',n:'勤務態度',d:'正当な理由がなく上司に事前承認のない出勤中の不稼働や欠勤、明らかな規律・モラルの欠如と取れる行動があった場合✕'},
  {k:'horenso',n:'報連相',d:'報連相の欠如により会社やメンバーに著しい損害や迷惑がかかった事案があった場合✕'},
  {k:'rule',n:'ルール遵守',d:'社内で広報されているルールが遵守できず、会社やメンバーに著しい損害や迷惑がかかった事案があった場合✕（就業規定や経費規定、オペレーションルール等）'}
];

const STAGES = [
  {t:'ちいさな光',    dsc:'まだ小さな光。ここから全部はじまる。'},
  {t:'ひかる',        dsc:'自分の力で光りはじめた。'},
  {t:'衛星がひとつ',  dsc:'まわりに人がついてきた。'},
  {t:'リング',        dsc:'自分の軌道ができた。'},
  {t:'ふたつめの衛星',dsc:'任せてもらえる範囲が広がった。'},
  {t:'二重のリング',  dsc:'自分の型を持ちはじめた。'},
  {t:'みっつめの衛星',dsc:'まわりを巻き込んで動かせる。'},
  {t:'光をまとう',    dsc:'いるだけで場が明るくなる。'},
  {t:'きらめく',      dsc:'遠くからでも見つけてもらえる。'},
  {t:'まんまるの惑星',dsc:'ひとつの世界をつくった。'}
];

/* ============================================================
   カテゴリ（ステップ一覧の行）
   ============================================================ */
const CATS=[
  {k:'vision',            n:'なりたい姿'},
  {k:'スタンス',           n:'スタンス'},
  {k:'コミュニケーション',   n:'コミュニケーション'},
  {k:'タスク管理',         n:'タスク管理'},
  {k:'組織運営',           n:'組織運営'},
  {k:'業務スキル｜知見',    n:'業務スキル・知見'},
  {k:'業務スキル｜運用',    n:'業務スキル・運用'},
  {k:'AI活用',            n:'AI活用'},
  {k:'個別設定',           n:'個別設定'}
];

/* ============================================================
   項目の展開 — グレード定義から「チェックできる項目」の平坦なリストを作る
   id の形： g<グレード>.<セション番号 or v>.<グループ->?<連番>(.<サブ番号>)?
   ============================================================ */
function gradeItems(g){
  const out=[];
  g.vision.forEach((t,i)=>out.push({id:'g'+g.n+'.v.'+i,t:t,cat:'なりたい姿',vision:true}));
  g.sections.forEach((s,si)=>{
    const push=(list,gl)=>list.forEach((it,ii)=>{
      const base='g'+g.n+'.'+si+'.'+(gl!=null?gl+'-':'')+ii;
      if(typeof it==='string'){ out.push({id:base,t:it,cat:s.title,custom:!!s.custom}); }
      else{
        out.push({id:base,t:it.t,cat:s.title,link:it.link,custom:!!s.custom});
        (it.sub||[]).forEach((st,k)=>out.push({id:base+'.'+k,t:st,cat:s.title,sub:true}));
      }
    });
    if(s.groups) s.groups.forEach((gr,gl)=>push(gr.items,gl));
    else push(s.items,null);
  });
  return out;
}
const ITEMS={}; GRADES.forEach(g=>ITEMS[g.n]=gradeItems(g));
const ALL_ITEMS=[]; GRADES.forEach(g=>ALL_ITEMS.push.apply(ALL_ITEMS,ITEMS[g.n]));
const ITEM_BY_ID={}; ALL_ITEMS.forEach(i=>ITEM_BY_ID[i.id]=i);
const TOTAL_ITEMS=ALL_ITEMS.length;

/* ============================================================
   進捗の計算 — すべて checks（{項目id:true} のオブジェクト）を受け取る。
   本人の画面でも管理者画面でも同じ関数で計算するため、状態は引数で渡す。
   ============================================================ */
function gTotal(gn){ return ITEMS[gn].length; }
function gDone(checks,gn){ return ITEMS[gn].filter(i=>checks[i.id]).length; }
function gIsDone(checks,gn){ return gDone(checks,gn)===gTotal(gn); }
function gPct(checks,gn){ return Math.round(gDone(checks,gn)/gTotal(gn)*100); }
function gradeOf(id){ return +id.slice(1).split('.')[0]; }
/* 挑戦中のグレード＝まだ埋まりきっていない最も低いグレード */
function gCurrentGrade(checks){ for(const g of GRADES){ if(!gIsDone(checks,g.n)) return g.n; } return 10; }
/* ロック：ひとつ下のグレードが埋まっていれば開く。
   加えて「社内で認定されているグレード」以下は最初から開いている。
   在籍が長い人に、終わったはずの下位グレードを埋め直させないため。 */
function gIsLocked(checks,gn,certified){
  if(certified && gn<=+certified) return false;
  return gn>gCurrentGrade(checks);
}
/* 認定グレード以下＝すでに社内で認定されている範囲（画面で印を出すのに使う） */
function gIsCertified(gn,certified){ return !!(certified && gn<=+certified); }

/* ------------------------------------------------------------
   チェックの2段階
     progress の1行は「本人が押した（申請中）」か「ULが承認した」のどちらか。
     raw は {項目id: {at, approved}} か、旧形式の {項目id: 日時 or true}。
     旧形式（承認列がまだ無いDB）のときは、すべて承認済みとして扱う。
   ------------------------------------------------------------ */
function splitChecks(raw){
  const all={}, approved={}, pending=[];
  Object.keys(raw||{}).forEach(k=>{
    const v=raw[k];
    if(!v) return;
    all[k]=true;
    if(typeof v==='object'){ if(v.approved) approved[k]=true; else pending.push(k); }
    else approved[k]=true;   /* 旧形式：押した＝達成 */
  });
  return {all:all, approved:approved, pending:pending};
}
/* 承認待ちの件数（グレードを指定すればそのグレードの分だけ） */
function gPendingCount(all,approved,gn){
  const list = gn? ITEMS[gn] : ALL_ITEMS;
  return list.filter(i=>all[i.id]&&!approved[i.id]).length;
}
function gClearedCount(checks){ return GRADES.filter(g=>gIsDone(checks,g.n)).length; }
function gStage(checks){ return Math.min(gClearedCount(checks)+1,10); }
function gTotalChecked(checks){ return ALL_ITEMS.filter(i=>checks[i.id]).length; }
function gOverallPct(checks){ return Math.round(gTotalChecked(checks)/TOTAL_ITEMS*100); }
function tierOf(gn){ return TIERS[GRADES[gn-1].tier]; }

/* セクション単位・なりたい姿単位の達成数（ステップ一覧のマス目用） */
function secStats(checks,gn,si){
  const its=ITEMS[gn].filter(i=>i.id.split('.')[1]===String(si));
  return {t:its.length, d:its.filter(i=>checks[i.id]).length};
}
function visStats(checks,gn){
  const its=ITEMS[gn].filter(i=>i.id.split('.')[1]==='v');
  return {t:its.length, d:its.filter(i=>checks[i.id]).length};
}
/* ------------------------------------------------------------
   項目が属するセクション（「スタンス」「タスク管理」など）を引く。
   グレード全体は長いので、セクションを1つ埋めたところで小さく褒めるのに使う。
   ------------------------------------------------------------ */
function sectionKeyOf(id){ const p=String(id).split('.'); return p[0]+'.'+p[1]; }
function sectionItems(id){ const k=sectionKeyOf(id); return ALL_ITEMS.filter(i=>sectionKeyOf(i.id)===k); }
function sectionTitleOf(id){
  const p=String(id).split('.'), gn=+p[0].slice(1);
  if(p[1]==='v') return 'なりたい姿';
  const s=GRADES[gn-1].sections[+p[1]];
  return s? s.title : '';
}
/* その項目を入れたことでセクションが埋まりきったか */
function sectionJustDone(checks,id){
  const its=sectionItems(id);
  return its.length>1 && its.every(i=>checks[i.id]);
}
function subLabel(title,cat){
  let r=title.slice(cat.length);
  if(r.charAt(0)==='｜') r=r.slice(1);
  if(r.charAt(0)==='（'&&r.charAt(r.length-1)==='）') r=r.slice(1,-1);
  return r||title;
}

/* ============================================================
   昇格の見込み — 各グレードの標準期間（period）を月数に直して積み上げ、
   入社日からの経過月数と比べて「予定時期」と「遅れ」を出す。
   GRADES[].period は「1ヶ月」「12ヶ月」のような在籍month数（累計）で書かれている。
   ============================================================ */
function periodMonths(gn){
  const m=String(GRADES[gn-1].period).match(/(\d+)/);
  return m?+m[1]:null;
}
/* 入社日から今日までの経過月数（小数） */
function monthsSince(dateStr,now){
  if(!dateStr) return null;
  const d=new Date(dateStr+'T00:00:00');
  if(isNaN(d)) return null;
  const t=(now||new Date());
  return ((t.getFullYear()-d.getFullYear())*12 + (t.getMonth()-d.getMonth())) + (t.getDate()-d.getDate())/30.4;
}
function addMonths(dateStr,months){
  if(!dateStr||months==null) return null;
  const d=new Date(dateStr+'T00:00:00');
  if(isNaN(d)) return null;
  d.setMonth(d.getMonth()+Math.round(months));
  return d.toISOString().slice(0,10);
}
/* 昇格見込み：挑戦中グレードを終える標準時期と、そこからの遅れ月数 */
function promotionOutlook(member,checks,now){
  const cg=gCurrentGrade(checks);
  const pm=periodMonths(cg);
  const elapsed=monthsSince(member.join_date,now);
  const target=member.promotion_target || addMonths(member.join_date,pm);
  let delay=null;
  if(elapsed!=null&&pm!=null) delay=Math.round((elapsed-pm)*10)/10;
  return {grade:cg, targetDate:target, standardMonths:pm, elapsedMonths:elapsed==null?null:Math.round(elapsed*10)/10, delayMonths:delay};
}
/* 詰まっている項目：挑戦中グレードの未チェック項目をカテゴリごとにまとめて返す */
function stuckItems(checks,limit){
  const cg=gCurrentGrade(checks);
  const rest=ITEMS[cg].filter(i=>!checks[i.id]);
  return limit?rest.slice(0,limit):rest;
}
