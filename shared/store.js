/* ============================================================
   STEP — データ層
   ------------------------------------------------------------
   データは Supabase の1か所にだけ置く。デモデータもサンプル名簿も持たない。
   管理者画面に出るのは、本人画面から実際に登録した人だけ。

   shared/config.js に接続情報が入っていないときは mode='unconfigured' になり、
   画面側はセットアップ手順の案内を出す（架空のデータで動かしたりはしない）。

   ログインの考え方
     ・パスワードは1人1つ。Supabase Auth が持つ。
     ・共通パスコードは「登録していい人か」を確かめるためのもの。
       ログインのパスワードではない。
     ・管理者キーは、自分をULに昇格させるときだけ使う。
   ============================================================ */
const Store = (() => {
  const CFG = window.STEP_CONFIG || {};
  const CLOUD = !!(CFG.SUPABASE_URL && CFG.SUPABASE_ANON_KEY);
  const LEGACY_KEY = 'careerstep:v1';          // 共有化する前の、端末だけに保存していたデータ
  const MIGRATED_KEY = 'careerstep:migrated';  // その引き継ぎが済んだか
  const QUEUE_KEY = 'careerstep:queue';        // 電波が無いときに溜めておくチェック

  let sb = null;                  // Supabase クライアント
  let me = null;                  // {member, role, isManager}

  /* ---------- localStorage の薄いラッパ（使えない環境でも落ちない） ---------- */
  const mem = {};
  const LS = {
    get(k){ try{ return localStorage.getItem(k); }catch(e){ return mem[k]||null; } },
    set(k,v){ try{ localStorage.setItem(k,v); return true; }catch(e){ mem[k]=v; return false; } },
    del(k){ try{ localStorage.removeItem(k); }catch(e){ delete mem[k]; } }
  };
  const readJSON=(k,fb)=>{ try{ const v=LS.get(k); return v?JSON.parse(v):fb; }catch(e){ return fb; } };

  /* ---------- Supabase クライアントを必要になったときだけ読み込む ---------- */
  function loadScript(src){
    return new Promise((res,rej)=>{
      const s=document.createElement('script');
      s.src=src; s.onload=res; s.onerror=()=>rej(new Error('failed to load '+src));
      document.head.appendChild(s);
    });
  }
  async function client(){
    if(sb) return sb;
    if(!window.supabase) await loadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.111.0/dist/umd/supabase.js');
    sb = window.supabase.createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY, {
      auth:{ persistSession:true, autoRefreshToken:true, storageKey:'careerstep:auth' }
    });
    return sb;
  }
  function need(){
    if(!CLOUD) throw new Error('接続先が設定されていません（SETUP.md 手順4）');
    if(!sb)    throw new Error('接続の準備ができていません。ページを再読み込みしてください');
  }
  /* Supabaseのエラーを日本語にして投げ直す */
  function chk(res){
    if(res && res.error){
      const m=String(res.error.message||'');
      if(/Invalid login credentials/i.test(m)) throw new Error('パスワードが違います');
      if(/User already registered/i.test(m))   throw new Error('このログインはすでに使われています。ページを再読み込みしてやり直してください');
      if(/Password should be/i.test(m))        throw new Error('パスワードは6文字以上にしてください');
      /* 架空のTLD（.local など）はSupabaseが弾く。設定を直さないと誰も登録できない */
      if(/is invalid/i.test(m) && /@/.test(m))
        throw new Error('ログイン用のドメインがSupabaseに拒否されました。shared/config.js の AUTH_EMAIL_DOMAIN を実在するドメインに変えてください（SETUP.md 手順4）');
      if(/row-level security|permission denied/i.test(m)) throw new Error('この操作をする権限がありません');
      if(/Email not confirmed/i.test(m)) throw new Error('Supabaseの「Confirm email」をオフにしてください（SETUP.md 手順3）');
      /* このエラーが出る＝Supabaseが確認メールを送ろうとしている。
         このアプリはメールを一切使わないので、確認メールの設定が残っているということ。 */
      if(/email rate limit/i.test(m))
        throw new Error('Supabaseの「Confirm email」がオンのままです。オフにしてください（SETUP.md 手順3）。オンのあいだは登録のたびに確認メールが送られ、すぐ上限に達します');
      /* 似たエラーが2種類あり、直す場所が違うので分ける */
      if(/email.*signups.*disabled|email_provider_disabled|email provider.*disabled/i.test(m))
        throw new Error('Supabaseの「Email」プロバイダがオフになっています。Authentication → Sign In / Providers → Email を開き、Email provider を「オン」、その中の Confirm email だけを「オフ」にしてください（SETUP.md 手順3）');
      if(/signups? not allowed|Signups not allowed|signup_disabled/i.test(m))
        throw new Error('Supabaseの「Allow new users to sign up」がオフになっています。オンにしてください（SETUP.md 手順3）');
      throw new Error(m||'通信に失敗しました');
    }
    return res ? res.data : null;
  }
  const emailFor = slug => String(slug).toLowerCase()+'@'+(CFG.AUTH_EMAIL_DOMAIN||'intern-career-path.vercel.app');
  const newSlug  = () => 'm-'+Math.random().toString(36).slice(2,8)+Date.now().toString(36).slice(-4);
  const todayISO = () => new Date().toISOString().slice(0,10);

  /* ============================================================
     この端末だけに保存していた時代のデータの引き継ぎ
     ------------------------------------------------------------
     共有化する前に使っていた人が、初めてログインしたときに1回だけ動く。
     すでにサーバー側にチェックがある場合は何もしない（上書き事故を防ぐ）。
     ============================================================ */
  async function migrateLegacy(memberId){
    if(LS.get(MIGRATED_KEY)) return 0;
    const raw=readJSON(LEGACY_KEY,null);
    if(!raw){ LS.set(MIGRATED_KEY,'1'); return 0; }

    const itemIds=Object.keys(raw.checks||{}).filter(k=>raw.checks[k]);
    const has=chk(await sb.from('progress').select('item_id').eq('member_id',memberId).limit(1));
    if(has && has.length){ LS.set(MIGRATED_KEY,'1'); return 0; }

    if(itemIds.length){
      if(caps.approval){
        /* 本人からの直接書き込みは閉じてあるので、1件ずつ関数を通す */
        for(const id of itemIds) chk(await sb.rpc('set_my_check',{p_item_id:id,p_on:true}));
      }else{
        const now=new Date().toISOString();
        chk(await sb.from('progress').upsert(itemIds.map(id=>({member_id:memberId,item_id:id,checked_at:now}))));
      }
    }
    const st={};
    if(raw.buddy)    st.buddy=raw.buddy;
    if(raw.goals)    st.goals=raw.goals;
    if(raw.creed)    st.creed=raw.creed;
    if(raw.atarimae) st.atarimae=raw.atarimae;
    if(raw.custom)   st.custom=raw.custom;
    if(Object.keys(st).length){
      chk(await sb.from('member_state').upsert(Object.assign({member_id:memberId,updated_at:new Date().toISOString()},st)));
    }
    LS.set(MIGRATED_KEY,'1');
    return itemIds.length;
  }

  /* ============================================================
     サーバー側の機能検出
     ------------------------------------------------------------
     supabase/schema.sql の追加分（承認・名前検索・設定など）を
     まだ流していない環境でも、画面がそのまま動くようにする。
     使える機能だけをオンにして、無い機能は従来のやり方に落とす。
     ============================================================ */
  const caps = { approval:false, rosterSearch:false, settings:false, managerRequests:false };
  let capsDone = false;   /* 一度でも通信できたか。電波が悪いだけの結果を信じない */
  async function detectCaps(){
    let ok=true;
    try{
      const r=await sb.from('progress').select('approved_at').limit(1);
      /* 列が無い（42703）ならこの機能は無い。通信自体が失敗したなら判定しない */
      if(r.error && !/column|does not exist|42703/i.test(String(r.error.message||''))) ok=false;
      else caps.approval = !r.error;
    }catch(e){ ok=false; }
    try{
      const r=await sb.rpc('roster_search',{p_q:'',p_managers:false});
      if(r.error && !/function|does not exist|Could not find/i.test(String(r.error.message||''))) ok=false;
      else caps.rosterSearch = !r.error;
    }catch(e){ ok=false; }
    capsDone = capsDone || ok;
  }
  /* 管理者としてログインしたあとに分かるもの */
  async function detectManagerCaps(){
    try{ const r=await sb.rpc('get_app_settings'); caps.settings = !r.error; }catch(e){ caps.settings=false; }
    try{ const r=await sb.from('manager_requests').select('member_id').limit(1); caps.managerRequests = !r.error; }
    catch(e){ caps.managerRequests=false; }
  }

  /* ============================================================
     オフラインでも押せるようにする
     ------------------------------------------------------------
     通信できないときは端末に積んでおき、つながったときに送る。
     移動中や電波の悪い現場で、チェックが素通りしないようにするため。
     ============================================================ */
  const queue = {
    all(){ return readJSON(QUEUE_KEY,[]) || []; },
    save(list){ LS.set(QUEUE_KEY, JSON.stringify(list)); },
    push(job){ const l=queue.all(); l.push(job); queue.save(l); api.queued=l.length; },
    get size(){ return queue.all().length; }
  };
  /* 通信そのものが届かなかったか（＝あとで送り直す価値があるか） */
  function isOffline(e){
    if(typeof navigator!=='undefined' && navigator.onLine===false) return true;
    const m=String((e&&e.message)||e);
    return /Failed to fetch|NetworkError|Load failed|network|timeout/i.test(m);
  }
  async function flushQueue(){
    if(!CLOUD || !sb || !me) return 0;
    const list=queue.all();
    if(!list.length) return 0;
    const rest=[]; let sent=0;
    for(const job of list){
      try{ await sendCheck(job.itemId, job.on); sent++; }
      catch(e){ if(isOffline(e)) rest.push(job); /* それ以外は捨てる（もう不要な操作） */ }
    }
    queue.save(rest); api.queued=rest.length;
    return sent;
  }
  /* 本人のチェック1件を実際に送る */
  async function sendCheck(itemId,on){
    if(caps.approval){ chk(await sb.rpc('set_my_check',{p_item_id:itemId,p_on:!!on})); return; }
    const r = on
      ? await sb.from('progress').upsert({member_id:me.member.id,item_id:itemId,checked_at:new Date().toISOString()})
      : await sb.from('progress').delete().eq('member_id',me.member.id).eq('item_id',itemId);
    /* 直接書き込みが閉じられている＝承認のしくみが入っている。
       判定を取り違えていただけなので、関数経由でやり直す。 */
    if(r.error && /row-level security|permission denied/i.test(String(r.error.message||''))){
      caps.approval=true;
      chk(await sb.rpc('set_my_check',{p_item_id:itemId,p_on:!!on}));
      return;
    }
    chk(r);
  }
  if(typeof window!=='undefined') window.addEventListener('online',()=>{ flushQueue(); });

  /* ============================================================
     公開API
     ============================================================ */
  const api = {
    mode: CLOUD?'cloud':'unconfigured',
    get me(){ return me; },
    get isManager(){ return !!(me && me.isManager); },
    get caps(){ return caps; },
    /* 直前のログイン／登録で、端末に残っていた記録を何件引き継いだか */
    migratedCount: 0,
    /* まだ送れていないチェックの件数（画面の「オフライン」表示に使う） */
    queued: 0,
    flushQueue,

    /* ---------- 起動 ---------- */
    async init(){
      if(!CLOUD) return api.mode;
      await client();
      api.queued = queue.size;
      await detectCaps();
      return api.mode;
    },

    /* 前回のログインが残っていれば復帰する */
    async restore(){
      if(!CLOUD) return null;
      const { data } = await sb.auth.getSession();
      if(!data || !data.session) return null;
      const r=await resolveMe();
      if(r) flushQueue().catch(()=>{});   /* 前回オフラインで押したぶんを送る */
      return r;
    },

    /* ---------- 名簿（ログイン画面用） ----------
       出るのは表示名・Unit・UL・内部ID・権限・パスワード設定済みかどうかだけ。 */
    async roster(){
      if(!CLOUD) return [];
      const r=await sb.from('member_roster').select('id,name,unit,ul,slug,role,linked');
      return chk(r)||[];
    },

    /* ---------- 名前で探す（ログイン画面用） ----------
       60人ぶんの氏名をログイン前に並べないための入口。
       2文字以上を入れた人にだけ、一致した数件を返す。
       サーバー側に検索関数が無い環境では、名簿を取ってから手元で絞る
       （＝従来と同じ見え方になるが、画面の操作は変わらない）。 */
    async searchRoster(q, managersOnly){
      if(!CLOUD) return [];
      const s=String(q||'').trim();
      if(s.length<2) return [];
      if(caps.rosterSearch){
        const r=await sb.rpc('roster_search',{p_q:s,p_managers:!!managersOnly});
        return chk(r)||[];
      }
      const all=await api.roster();
      return all.filter(m=>(!managersOnly||isManagerRole(m.role))&&
        (String(m.name).indexOf(s)>=0||String(m.unit||'').indexOf(s)>=0)).slice(0,10);
    },

    /* 新規登録の Unit 候補。個人名は含まない */
    async rosterUnits(){
      if(!CLOUD) return [];
      if(caps.rosterSearch){
        const r=await sb.rpc('roster_units');
        if(!r.error) return (chk(r)||[]).map(x=>x.unit).filter(Boolean);
      }
      try{
        const all=await api.roster();
        return Array.from(new Set(all.map(m=>m.unit).filter(Boolean))).sort();
      }catch(e){ return []; }
    },

    /* 共通パスコードが合っているか。未設定のあいだは true が返る */
    async checkPasscode(code){
      need();
      const r=await sb.rpc('check_team_passcode',{p_code:code});
      const v=chk(r);
      return v===null||v===undefined? true : !!v;
    },

    /* ---------- 新規登録 ----------
       名簿を一括投入しなくても、登録した人から順に積み上がっていく。
       内部IDはランダムに作る（氏名から作ると同姓同名でぶつかるため）。
         passcode … 部署共通のパスコード（登録していい人かの確認）
         password … 本人だけが知るログインパスワード */
    async registerMember(p, passcode, password){
      need();
      if(!(await api.checkPasscode(passcode))) throw new Error('パスコードが違います');

      const email=emailFor(newSlug());
      let res=await sb.auth.signUp({email,password});
      chk(res);
      if(!res.data.session) chk(res=await sb.auth.signInWithPassword({email,password}));

      chk(await sb.rpc('register_me',{
        p_name:p.name, p_unit:p.unit||null, p_ul:p.ul||null, p_mentor:p.mentor||null,
        p_join_date:p.join_date||null,
        p_certified_grade:p.certified_grade?+p.certified_grade:null,
        p_code:passcode }));

      const r=await resolveMe();
      api.migratedCount = r ? await migrateLegacy(r.member.id) : 0;
      return r;
    },

    /* ---------- ログイン（2回目以降） ----------
       名前を選び、自分のパスワードを入れる。 */
    async signInMember(member, password){
      need();
      chk(await sb.auth.signInWithPassword({email:emailFor(member.slug),password}));
      const r=await resolveMe();
      if(!r) throw new Error('この名前はまだパスワードが設定されていません。「はじめて使う」から進んでください');
      api.migratedCount = await migrateLegacy(r.member.id);
      flushQueue().catch(()=>{});
      return r;
    },

    /* ---------- 初回パスワード設定 ----------
       名簿に行はあるがパスワード未設定の人（ULがログインをリセットした直後など）が、
       共通パスコードと新しいパスワードを入れて繋ぎ直す。 */
    async setPassword(member, passcode, password){
      need();
      if(!(await api.checkPasscode(passcode))) throw new Error('パスコードが違います');
      const email=emailFor(member.slug);
      let res=await sb.auth.signUp({email,password});
      chk(res);
      if(!res.data.session) chk(res=await sb.auth.signInWithPassword({email,password}));
      chk(await sb.rpc('claim_member',{p_member_id:member.id,p_code:passcode}));
      const r=await resolveMe();
      api.migratedCount = r ? await migrateLegacy(r.member.id) : 0;
      return r;
    },

    /* ---------- 管理者ログイン（admin.html） ----------
       名前とパスワードでログインし、まだ管理者でなければ管理者キーで昇格する。 */
    async signInManager(member, password, adminKey, wantRole){
      need();
      chk(await sb.auth.signInWithPassword({email:emailFor(member.slug),password}));
      let r=await resolveMe();
      if(!r){ await api.signOut(); throw new Error('このログインは名簿と紐付いていません。本人画面から登録し直してください'); }
      if(!r.isManager){
        if(!adminKey){ await api.signOut(); throw new Error('このアカウントには管理者ツールを使う権限がありません。管理者キーを入力してください'); }
        let status;
        try{ status=await api.requestManager(adminKey, wantRole); }
        catch(e){ await api.signOut(); throw e; }
        if(status==='pending'){
          await api.signOut();
          throw new Error('申請を受け付けました。いまいる育成・ULが承認すると、この画面に入れるようになります');
        }
        r=me;
      }
      if(!r || !r.isManager){ await api.signOut(); throw new Error('このアカウントには管理者ツールを使う権限がありません'); }
      return r;
    },

    /* 育成／ULとして入りたいと申請する。
       wantRole 'mentor'（育成）か 'ul'。できることは同じで、表示上の役割が違うだけ。
       返り値 'approved' … その場で権限が付いた（まだ育成・ULが1人もいないとき）
              'pending'  … 申請を出した。いまいる育成・ULが承認すると使えるようになる
       サーバーが古い（役割を選べない版／承認制でない版）のときは、そこまで戻して呼び直す。 */
    async requestManager(code, wantRole){
      need();
      const want = wantRole==='mentor' ? 'mentor' : 'ul';
      const missing=e=>/does not exist|Could not find the function/i.test(String((e&&e.message)||''));
      let r=await sb.rpc('request_manager',{p_code:code, p_role:want});
      if(r.error && missing(r.error)) r=await sb.rpc('request_manager',{p_code:code});
      if(r.error && missing(r.error)){
        chk(await sb.rpc('claim_manager',{p_code:code}));
        await resolveMe();
        return 'approved';
      }
      const status=chk(r);
      await resolveMe();
      return status||'pending';
    },

    /* 管理者への昇格を待っている人（管理画面で承認する） */
    async managerRequests(){
      if(!caps.managerRequests) return [];
      const r=await sb.from('manager_requests').select('*').eq('status','pending');
      return chk(r)||[];
    },
    async decideManagerRequest(memberId,approve){
      need();
      chk(await sb.rpc('decide_manager_request',{p_member_id:memberId,p_approve:!!approve}));
    },

    /* ---------- アラートのしきい値（管理画面の設定） ---------- */
    async getSettings(){
      if(!caps.settings) return null;
      try{ return chk(await sb.rpc('get_app_settings'))||{}; }catch(e){ return null; }
    },
    async saveSettings(s){
      if(!caps.settings) throw new Error('この設定を保存するには supabase/schema.sql を貼り直してください');
      return chk(await sb.rpc('set_app_settings',{p_settings:s}));
    },

    /* パスコード・管理者キーが設定済みかどうか（管理者画面の注意表示用） */
    async configStatus(){
      if(!CLOUD) return {team:null,admin:null};
      try{ return chk(await sb.rpc('config_status'))||{team:null,admin:null}; }
      catch(e){ return {team:null,admin:null}; }
    },

    async signOut(){
      me=null;
      if(CLOUD && sb) await sb.auth.signOut();
    },

    /* ---------- 本人のデータ ---------- */
    async myData(){
      need();
      const mid=me.member.id;
      const cols=caps.approval? 'item_id,checked_at,approved_at,approved_by' : 'item_id,checked_at';
      const [p,s]=await Promise.all([
        sb.from('progress').select(cols).eq('member_id',mid),
        sb.from('member_state').select('*').eq('member_id',mid).maybeSingle()
      ]);
      const checks={};
      (chk(p)||[]).forEach(r=>{
        checks[r.item_id] = caps.approval
          ? { at:r.checked_at, approved:!!r.approved_at, approvedBy:r.approved_by||null, approvedAt:r.approved_at||null }
          : r.checked_at;
      });
      const st=chk(s)||{};
      return {
        member:me.member, checks,
        state:{ buddy:st.buddy||'', goals:st.goals||{basic:'',skill:''}, creed:st.creed||[],
          atarimae:st.atarimae||{}, custom:st.custom||{}, seen:st.seen||[], sound:st.sound!==false }
      };
    },

    /* 本人がチェックする。届かなかったときは端末に積んで、つながったら送る。
       返り値 {queued:true} なら、まだサーバーには届いていない。 */
    async setCheck(itemId,on){
      need();
      try{
        await sendCheck(itemId,on);
        if(queue.size) await flushQueue();
        return {queued:false};
      }catch(e){
        if(!isOffline(e)) throw e;
        queue.push({itemId:itemId,on:!!on,at:Date.now()});
        return {queued:true};
      }
    },

    /* 管理者が他の人のチェックを操作する。
       state: 'approved'（承認）/ 'pending'（申請中に戻す）/ 'off'（外す） */
    async setCheckFor(memberId,itemId,state){
      need();
      if(state===true)  state='approved';
      if(state===false) state='off';
      if(caps.approval){ chk(await sb.rpc('set_check_for',{p_member_id:memberId,p_item_id:itemId,p_state:state})); return; }
      if(state==='off') chk(await sb.from('progress').delete().eq('member_id',memberId).eq('item_id',itemId));
      else chk(await sb.from('progress').upsert({member_id:memberId,item_id:itemId,checked_at:new Date().toISOString()}));
    },

    /* 申請中のものをまとめて承認する（面談の最後に1回押す用） */
    async approveItems(memberId,itemIds){
      need();
      if(!caps.approval) return 0;
      return chk(await sb.rpc('approve_items',{p_member_id:memberId,p_item_ids:itemIds||null}))||0;
    },

    /* その人のチェックを全件消す（管理者のみ。申し送りに記録が残る） */
    async clearProgressFor(memberId){
      need();
      if(caps.approval) return chk(await sb.rpc('admin_clear_progress',{p_member_id:memberId}))||0;
      chk(await sb.from('progress').delete().eq('member_id',memberId));
      return 0;
    },

    async saveState(patch){
      need();
      chk(await sb.from('member_state').upsert(Object.assign({member_id:me.member.id,updated_at:new Date().toISOString()},patch)));
    },

    /* 管理者が他の人の member_state を更新する（アタリマエの判定など） */
    async saveStateFor(memberId,patch){
      need();
      chk(await sb.from('member_state').upsert(Object.assign({member_id:memberId,updated_at:new Date().toISOString()},patch)));
    },

    async saveProfile(p){
      need();
      const keep=(a,b)=>a!=null?a:b;
      chk(await sb.rpc('update_my_profile',{
        p_name:p.name||null, p_join_date:p.join_date||null,
        p_certified_grade:p.certified_grade?+p.certified_grade:null,
        p_unit:p.unit||null, p_ul:p.ul||null, p_mentor:p.mentor||null }));
      Object.assign(me.member,{ name:p.name, join_date:p.join_date,
        certified_grade:p.certified_grade,
        unit:keep(p.unit,me.member.unit), ul:keep(p.ul,me.member.ul),
        mentor:keep(p.mentor,me.member.mentor) });
    },

    /* 本人に公開された申し送りだけが返る（RLSが弾く） */
    async myNotes(){
      need();
      const r=await sb.from('notes').select('*').eq('member_id',me.member.id).order('occurred_on',{ascending:false});
      return chk(r)||[];
    },
    async myScores(){
      need();
      const r=await sb.from('quiz_scores').select('*').eq('member_id',me.member.id).order('taken_on',{ascending:false});
      return chk(r)||[];
    },
    async myReviews(){
      need();
      const r=await sb.from('reviews').select('*').eq('member_id',me.member.id).order('period',{ascending:false});
      return chk(r)||[];
    },
    async submitReview(p){
      need();
      chk(await sb.rpc('submit_review',{
        p_kind:p.kind, p_period:p.period,
        p_y:p.y||null, p_w:p.w||null, p_t:p.t||null,
        p_looking_back:p.looking_back||null, p_next_goal:p.next_goal||null }));
      return p;
    },

    /* ---------- 管理者用：まとめて読む ---------- */
    async adminLoad(){
      need();
      await detectManagerCaps();
      const pcols=caps.approval? 'member_id,item_id,checked_at,approved_at,approved_by' : 'member_id,item_id,checked_at';
      const [m,p,s,n,q,rv]=await Promise.all([
        sb.from('members').select('*').order('unit',{nullsFirst:false}).order('name'),
        sb.from('progress').select(pcols),
        sb.from('member_state').select('*'),
        sb.from('notes').select('*').order('occurred_on',{ascending:false}),
        sb.from('quiz_scores').select('*').order('taken_on',{ascending:false}),
        sb.from('reviews').select('*').order('period',{ascending:false})
      ]);
      const progress={};
      (chk(p)||[]).forEach(r=>{
        (progress[r.member_id]=progress[r.member_id]||{})[r.item_id] = caps.approval
          ? { at:r.checked_at, approved:!!r.approved_at, approvedBy:r.approved_by||null, approvedAt:r.approved_at||null }
          : r.checked_at;
      });
      const states={};   (chk(s)||[]).forEach(r=>states[r.member_id]=r);
      const reqs = caps.managerRequests ? await api.managerRequests() : [];
      return { members:chk(m)||[], progress, states, notes:chk(n)||[], scores:chk(q)||[], reviews:chk(rv)||[],
               managerRequests:reqs, fetchedAt:Date.now() };
    },

    /* ---------- 管理者用：書き込み ---------- */
    async addNote(n){
      need();
      const row={
        member_id:n.member_id, kind:n.kind||'memo', occurred_on:n.occurred_on||todayISO(),
        grade:n.grade||null, title:n.title||null, body:n.body, next_action:n.next_action||null,
        author_name:n.author_name||(me&&me.member.name)||null,
        author_id:me.member.id,
        visibility:n.visibility||'shared', pinned:!!n.pinned };
      const r=await sb.from('notes').insert(row).select().single();
      return chk(r);
    },
    async updateNote(id,patch){
      need();
      chk(await sb.from('notes').update(patch).eq('id',id));
    },
    async deleteNote(id){
      need();
      chk(await sb.from('notes').delete().eq('id',id));
    },

    /* テスト結果。(member_id, quiz_name, taken_on) が同じものは上書きする */
    async saveScores(list){
      need();
      if(!list.length) return 0;
      chk(await sb.from('quiz_scores').upsert(list,{onConflict:'member_id,quiz_name,taken_on'}));
      return list.length;
    },
    async deleteScore(id){
      need();
      chk(await sb.from('quiz_scores').delete().eq('id',id));
    },

    async setUlComment(reviewId,text){
      need();
      chk(await sb.rpc('set_ul_comment',{p_review_id:reviewId,p_comment:text}));
    },

    async upsertMember(m){
      need();
      const r = m.id
        ? await sb.from('members').update(m).eq('id',m.id).select().single()
        : await sb.from('members').insert(m).select().single();
      return chk(r);
    },

    /* パスワードを忘れた人の救済。記録は残したまま、ログインの紐付けだけ外す。
       本人は次に名前を選んだとき「初回パスワード設定」に進む。 */
    async resetLogin(memberId){
      need();
      return chk(await sb.rpc('admin_reset_login',{p_member_id:memberId}));
    }
  };

  /* ログイン中の人が誰で、管理者かどうかを確定させる */
  async function resolveMe(){
    const u=await sb.auth.getUser();
    const uid=u&&u.data&&u.data.user&&u.data.user.id;
    if(!uid){ me=null; return null; }
    const m=chk(await sb.from('members').select('*').eq('auth_id',uid).maybeSingle());
    if(!m){ me=null; return null; }
    /* 起動時に電波が悪くて判定できていなければ、ログインできたここでやり直す。
       判定を間違えると、書き込み先（関数か直接か）を取り違えてしまうため。 */
    if(!capsDone) await detectCaps();
    me={member:m, role:m.role, isManager:isManagerRole(m.role)};
    return me;
  }

  return api;
})();
