/* ============================================================
   STEP — データ層
   ------------------------------------------------------------
   2つのモードを同じ呼び出し方で使えるようにしている。

     cloud … shared/config.js に Supabase の情報が入っているとき。
             全員のデータが1か所に集まり、管理者画面が使える。
     local … 情報が空のとき。いままでどおり自分の端末だけに保存する。
             管理者画面はデモデータで動作確認できる。

   画面側（index.html / admin.html）はモードを気にせず Store.* を呼ぶ。
   ============================================================ */
const Store = (() => {
  const CFG = window.STEP_CONFIG || {};
  const CLOUD = !!(CFG.SUPABASE_URL && CFG.SUPABASE_ANON_KEY);
  const SELF_KEY = 'careerstep:v1';        // 既存ユーザーのデータ。キーは変えない
  const DEMO_KEY = 'careerstep:demo:v1';   // ローカルモードで管理者画面を試すためのデモ
  const SESSION_KEY = 'careerstep:session';
  /* ローカルモードで本人側の画面にもデモの中身を流し込むかどうか。
     実運用で空の画面に架空の記録が出ると混乱するので、既定はオフ。
     URLに ?demo=1 を付けたときだけ、見本として表示する。 */
  const SELF_DEMO = (()=>{ try{ return /[?&]demo=1/.test(location.search); }catch(e){ return false; } })();

  let sb = null;                  // Supabase クライアント
  let me = null;                  // {member, role, isManager}
  let demo = null;                // ローカルモードのデモデータ

  /* ---------- localStorage の薄いラッパ（使えない環境でも落ちない） ---------- */
  const mem = {};
  const LS = {
    get(k){ try{ return localStorage.getItem(k); }catch(e){ return mem[k]||null; } },
    set(k,v){ try{ localStorage.setItem(k,v); return true; }catch(e){ mem[k]=v; return false; } },
    del(k){ try{ localStorage.removeItem(k); }catch(e){ delete mem[k]; } }
  };
  const readJSON=(k,fb)=>{ try{ const v=LS.get(k); return v?JSON.parse(v):fb; }catch(e){ return fb; } };
  const writeJSON=(k,v)=>LS.set(k,JSON.stringify(v));

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
    if(!window.supabase) await loadScript('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.js');
    sb = window.supabase.createClient(CFG.SUPABASE_URL, CFG.SUPABASE_ANON_KEY, {
      auth:{ persistSession:true, autoRefreshToken:true, storageKey:'careerstep:auth' }
    });
    return sb;
  }
  /* Supabaseのエラーを日本語にして投げ直す */
  function chk(res){
    if(res && res.error){
      const m=String(res.error.message||'');
      if(/Invalid login credentials/i.test(m)) throw new Error('パスコードが違います');
      if(/row-level security|permission denied/i.test(m)) throw new Error('この操作をする権限がありません');
      if(/Email not confirmed/i.test(m)) throw new Error('Supabaseの「Confirm email」をオフにしてください（SETUP.md参照）');
      throw new Error(m||'通信に失敗しました');
    }
    return res ? res.data : null;
  }
  const emailFor = slug => String(slug).toLowerCase()+'@'+(CFG.AUTH_EMAIL_DOMAIN||'step-app.local');

  /* ============================================================
     デモデータ（ローカルモード専用）
     乱数は固定シードなので、開くたびに同じ顔ぶれ・同じ進捗になる。
     ============================================================ */
  function rng(seed){ return ()=>{ seed=(seed+0x6D2B79F5)|0;
    let t=seed; t=Math.imul(t^t>>>15,t|1); t^=t+Math.imul(t^t>>>7,t|61);
    return ((t^t>>>14)>>>0)/4294967296; }; }

  function buildDemo(){
    const saved=readJSON(DEMO_KEY,null);
    if(saved && saved.v===3) return saved;
    const r=rng(20260812);
    const sei='佐藤 鈴木 高橋 田中 伊藤 渡辺 山本 中村 小林 加藤 吉田 山田 佐々木 山口 松本 井上 木村 林 斎藤 清水 山崎 森 池田 橋本 石川 前田 藤田 後藤 岡田 長谷川'.split(' ');
    const mei='陽菜 蓮 結菜 湊 咲良 樹 芽依 悠真 莉子 大翔 凛 陽翔 花 颯真 美桜 律 心春 朝陽 結愛 碧 澪 新 杏 暖 楓 翔 葵 悠 詩 円'.split(' ');
    const units=['Unit A','Unit B','Unit C','Unit D'];
    const members=[], progress={}, states={}, notes=[], scores=[], reviews=[];
    const QUIZ=['AI基礎クイズ','バイブコーディング基礎','スターター編 理解度','Instagramアルゴリズム','個人情報・コンプライアンス'];
    const today=new Date();

    /* UL 4名 ＋ メンバー56名。ULもキャリアステップの途中なので進捗を持たせる */
    const uls=units.map((u,i)=>({
      id:'ul'+i, name:sei[i]+' '+mei[i+10], slug:'ul'+i, unit:u, role:'ul',
      join_date:iso(addM(today,-(20+i*3))), certified_grade:7+(i%2), active:true, ul:null, mentor:null
    }));
    uls.forEach((m,i)=>{
      members.push(m);
      const checks={};
      for(let g=1; g<=6+(i%2); g++) ITEMS[g].forEach(it=>{ checks[it.id]=iso(addM(today,-(8-g))); });
      const cur=7+(i%2);
      ITEMS[cur].forEach((it,idx)=>{ if(idx/ITEMS[cur].length < 0.3+r()*0.5) checks[it.id]=iso(addD(today,-Math.floor(r()*30))); });
      progress[m.id]=checks;
      states[m.id]={ buddy:'', goals:{basic:'',skill:''}, creed:[], atarimae:{}, custom:{}, seen:[], sound:true };
    });

    for(let i=0;i<56;i++){
      const unit=units[i%4];
      /* 新しい人のほうが多い組織になるよう、在籍月数は短いほうへ寄せる */
      const monthsIn=1+Math.floor(r()*r()*13);          // 在籍1〜13ヶ月
      const m={
        id:'m'+i,
        name:sei[(i*7+3)%sei.length]+' '+mei[(i*11+5)%mei.length],
        slug:'demo-'+i, unit:unit,
        ul:uls[i%4].name,
        mentor:members.length>4? members[4+((i*3)%Math.max(1,members.length-4))].name : null,
        join_date:iso(addM(today,-monthsIn)),
        certified_grade:null, promotion_target:null,
        role:'member', active:true
      };
      /* 在籍月数に応じた進捗。1〜2割は意図的に遅らせて「詰まっている人」を作る */
      const pace = r()<0.18 ? 0.45+r()*0.25 : 0.8+r()*0.5;
      const reachGrade = Math.max(1, Math.min(10, Math.round(gradeForMonths(monthsIn*pace))));
      const checks={};
      for(let g=1; g<reachGrade; g++) ITEMS[g].forEach(it=>{ checks[it.id]=iso(addM(today,-(reachGrade-g)*1.4)); });
      const partial=0.15+r()*0.75;
      ITEMS[reachGrade].forEach((it,idx)=>{ if(idx/ITEMS[reachGrade].length < partial) checks[it.id]=iso(addD(today,-Math.floor(r()*40))); });
      m.certified_grade=Math.max(1,reachGrade-(r()<0.3?1:0));
      progress[m.id]=checks;
      states[m.id]={ buddy:['コスモ','ぽち','ルナ','ひかり','たま','そら',''][Math.floor(r()*7)],
        goals:{basic:'',skill:''}, creed:[], atarimae:{}, custom:{}, seen:[], sound:true };
      members.push(m);

      /* テスト結果。1人目は本人側の画面を確認する見本になるので必ず埋める */
      QUIZ.forEach((q,qi)=>{
        if(i>0 && r()<0.35) return;
        const max=10, sc=Math.max(3,Math.min(10,Math.round(5+r()*5)));
        scores.push({ id:'s'+i+'-'+qi, member_id:m.id, quiz_name:q, score:sc, max_score:max,
          passed:sc>=9, taken_on:iso(addD(today,-Math.floor(r()*120))), source:'csv' });
      });

      /* 申し送り。1人目は本人側の画面の見本になるので必ず本人公開ぶんを入れる */
      const nk=i===0?4:Math.floor(r()*4);
      for(let k=0;k<nk;k++){
        const kinds=['memo','handover','interview','promotion','escalation','praise'];
        const kind=kinds[Math.floor(r()*kinds.length)];
        notes.push({ id:'n'+i+'-'+k, member_id:m.id, kind:kind,
          occurred_on:iso(addD(today,-Math.floor(r()*70))),
          grade: kind==='promotion'? reachGrade : null,
          title:'', body:DEMO_NOTE[kind][Math.floor(r()*DEMO_NOTE[kind].length)],
          next_action: r()<0.5? '次回の定例で進捗を確認する' : '',
          author_name: uls[i%4].name,
          visibility: (i===0&&k<3) ? 'shared' : (r()<0.75? 'shared':'admin'), pinned:false,
          created_at:new Date(Date.now()-Math.floor(r()*70)*864e5).toISOString() });
      }

      /* 振り返り */
      for(let b=0;b<Math.min(4,monthsIn*2);b++){
        if(r()<0.25) continue;
        const d=addD(today,-b*14);
        reviews.push({ id:'r'+i+'-y'+b, member_id:m.id, kind:'ywt',
          period: iso(d).slice(0,7)+(d.getDate()<=15?'-A':'-B'),
          y:'担当2社の投稿作成とレポート提出。ストーリーズを毎日更新した。',
          w:'画像の並び順でリーチが変わることがわかった。保存数は1枚目で決まる。',
          t:'次の2週間は1枚目の型を3パターン試して、数値を比較する。',
          submitted_at:new Date(d.getTime()).toISOString(),
          ul_comment: r()<0.4? '比較の観点が良いです。結果を定例で共有してください。':null,
          ul_comment_by: r()<0.4? uls[i%4].name:null });
      }
      for(let b=0;b<Math.min(3,monthsIn);b++){
        if(r()<0.35) continue;
        const d=addM(today,-b);
        reviews.push({ id:'r'+i+'-m'+b, member_id:m.id, kind:'monthly', period:iso(d).slice(0,7),
          looking_back:'フォロワーは目標に届かなかったが、投稿の質は安定してきた。',
          next_goal:'フォロワー+200とCV1件。ペルソナ分析を作り直す。',
          submitted_at:new Date(d.getTime()).toISOString() });
      }
    }
    const d={ v:3, members, progress, states, notes, scores, reviews };
    writeJSON(DEMO_KEY,d);
    return d;
  }
  const DEMO_NOTE={
    memo:['定例で担当アカウントの数値を確認。リーチが落ちている原因を一緒に整理した。','タスクの抱え込みが見られたので、優先順位のつけ方を一緒に確認した。'],
    handover:['〇〇様のアカウントを本日より引き継ぎ。ハイライトの更新ルールを共有済み。','産休メンバーの担当2社を移管。過去のレポートは共有ドライブに格納した。'],
    interview:['月次面談。業務量は問題ないが、レポートの考察に自信がないとのこと。次回サンプルを見ながら一緒に書く。','隔週面談。他Unitとの関わりを増やしたいと希望あり。ナレッジ会での発表を打診した。'],
    promotion:['昇格面談実施。運用の基礎は問題なし。レポートの考察が及第点に届かないため、1ヶ月継続としフォロー項目を設定。','昇格面談実施。数値・スタンスともに基準クリア。次グレードへ昇格で合意。'],
    escalation:['クライアント様への投稿時間の連絡漏れが発生。本人と再発防止策を確認し、チェックフローを二重化した。'],
    praise:['ナレッジ賞にノミネート。画像選定の分析を自主的にまとめて共有してくれた。']
  };
  function gradeForMonths(mo){ for(let g=1;g<=10;g++){ const p=periodMonths(g); if(p==null) return 10; if(mo<p) return g; } return 10; }
  function addM(d,n){ const x=new Date(d); x.setMonth(x.getMonth()+Math.round(n)); return x; }
  function addD(d,n){ const x=new Date(d); x.setDate(x.getDate()+Math.round(n)); return x; }
  function iso(d){ return new Date(d).toISOString().slice(0,10); }

  /* 自分（ローカルモード）のデータを、既存の careerstep:v1 の形から読む */
  function selfLocal(){
    const raw=readJSON(SELF_KEY,{})||{};
    return {
      member:{ id:'self', name:(raw.profile&&raw.profile.name)||'', slug:'self',
        unit:null, ul:null, mentor:null,
        join_date:(raw.profile&&raw.profile.join)||null,
        certified_grade:(raw.profile&&raw.profile.grade)?+raw.profile.grade:null,
        promotion_target:null, role:'member', active:true },
      checks: raw.checks || {},
      state:{ buddy:raw.buddy||'', goals:raw.goals||{basic:'',skill:''},
        creed:raw.creed||[], atarimae:raw.atarimae||{}, custom:raw.custom||{},
        seen:raw.seen||[], sound:raw.sound!==false, log:raw.log||[] }
    };
  }
  function writeSelfLocal(mut){
    const raw=readJSON(SELF_KEY,{})||{};
    mut(raw);
    writeJSON(SELF_KEY,raw);
  }

  /* ============================================================
     公開API
     ============================================================ */
  const api = {
    mode: CLOUD?'cloud':'local',
    get me(){ return me; },
    get isManager(){ return !!(me && me.isManager); },
    get demoData(){ return demo; },

    /* ---------- 起動 ---------- */
    async init(){
      if(!CLOUD){ demo=buildDemo(); return api.mode; }
      await client();
      return api.mode;
    },

    /* 前回のログインが残っていれば復帰する */
    async restore(){
      if(!CLOUD){
        const s=readJSON(SESSION_KEY,null);
        if(s&&s.demoManager){ me={member:{id:'demo-ul',name:'（デモ）UL',role:'ul'},role:'ul',isManager:true}; return me; }
        const self=selfLocal();
        me={member:self.member, role:'member', isManager:false};
        return me;
      }
      const { data } = await sb.auth.getSession();
      if(!data || !data.session) return null;
      return await resolveMe();
    },

    /* ---------- 名簿（ログイン画面用） ---------- */
    async roster(){
      if(!CLOUD) return demo.members.filter(m=>m.active).map(m=>({id:m.id,name:m.name,unit:m.unit,slug:m.slug}));
      const r=await sb.from('member_roster').select('id,name,unit,slug');
      return chk(r)||[];
    },

    /* ---------- ログイン ---------- */
    /* 名前を選び、部署共通のパスコードを入れる。
       初回はそのパスコードでアカウントを作り、以降は同じパスコードでログインする。 */
    async signInMember(member, passcode){
      if(!CLOUD){
        writeSelfLocal(r=>{ r.profile=Object.assign({name:'',join:'',grade:''},r.profile||{}); if(!r.profile.name) r.profile.name=member.name; });
        LS.del(SESSION_KEY);
        const self=selfLocal();
        me={member:self.member, role:'member', isManager:false};
        return me;
      }
      const email=emailFor(member.slug);
      let res=await sb.auth.signInWithPassword({email,password:passcode});
      if(res.error && /Invalid login credentials/i.test(res.error.message)){
        /* まだアカウントが無い＝初回。パスコードで作る */
        const up=await sb.auth.signUp({email,password:passcode});
        chk(up);
        if(!up.data.session){
          res=await sb.auth.signInWithPassword({email,password:passcode});
        }else res={data:up.data,error:null};
      }
      chk(res);
      await sb.rpc('claim_member',{p_member_id:member.id}).then(chk);
      return await resolveMe();
    },

    /* UL/管理者はメールアドレスとパスワードでログインする */
    async signInManager(email, password){
      if(!CLOUD){
        writeJSON(SESSION_KEY,{demoManager:true});
        me={member:{id:'demo-ul',name:'（デモ）UL',role:'ul'},role:'ul',isManager:true};
        return me;
      }
      chk(await sb.auth.signInWithPassword({email:String(email).trim(),password}));
      const r=await resolveMe();
      if(!r || !r.isManager){ await api.signOut(); throw new Error('このアカウントには管理者権限がありません'); }
      return r;
    },

    async signOut(){
      me=null;
      LS.del(SESSION_KEY);
      if(CLOUD) await sb.auth.signOut();
    },

    /* ---------- 本人のデータ ---------- */
    async myData(){
      if(!CLOUD) return selfLocal();
      const mid=me.member.id;
      const [p,s]=await Promise.all([
        sb.from('progress').select('item_id,checked_at').eq('member_id',mid),
        sb.from('member_state').select('*').eq('member_id',mid).maybeSingle()
      ]);
      const checks={}; (chk(p)||[]).forEach(r=>checks[r.item_id]=r.checked_at);
      const st=chk(s)||{};
      return {
        member:me.member, checks,
        state:{ buddy:st.buddy||'', goals:st.goals||{basic:'',skill:''}, creed:st.creed||[],
          atarimae:st.atarimae||{}, custom:st.custom||{}, seen:st.seen||[], sound:st.sound!==false }
      };
    },

    async setCheck(itemId,on){ return api.setCheckFor(me.member.id,itemId,on); },

    async setCheckFor(memberId,itemId,on){
      if(!CLOUD){
        if(memberId==='self'){
          writeSelfLocal(r=>{
            r.checks=r.checks||{};
            if(on){ r.checks[itemId]=true; r.log=(r.log||[]).concat(Date.now()).slice(-400); }
            else delete r.checks[itemId];
          });
        }else{
          demo.progress[memberId]=demo.progress[memberId]||{};
          if(on) demo.progress[memberId][itemId]=todayStr(); else delete demo.progress[memberId][itemId];
          writeJSON(DEMO_KEY,demo);
        }
        return;
      }
      if(on) chk(await sb.from('progress').upsert({member_id:memberId,item_id:itemId,checked_at:new Date().toISOString()}));
      else   chk(await sb.from('progress').delete().eq('member_id',memberId).eq('item_id',itemId));
    },

    async saveState(patch){
      if(!CLOUD){
        writeSelfLocal(r=>{
          if('buddy'    in patch) r.buddy=patch.buddy;
          if('goals'    in patch) r.goals=patch.goals;
          if('creed'    in patch) r.creed=patch.creed;
          if('atarimae' in patch) r.atarimae=patch.atarimae;
          if('custom'   in patch) r.custom=patch.custom;
          if('seen'     in patch) r.seen=patch.seen;
          if('sound'    in patch) r.sound=patch.sound;
        });
        return;
      }
      chk(await sb.from('member_state').upsert(Object.assign({member_id:me.member.id,updated_at:new Date().toISOString()},patch)));
    },

    async saveProfile(p){
      if(!CLOUD){
        writeSelfLocal(r=>{ r.profile=Object.assign({},r.profile||{},{
          name:p.name!=null?p.name:(r.profile||{}).name,
          join:p.join_date!=null?p.join_date:(r.profile||{}).join,
          grade:p.certified_grade!=null?p.certified_grade:(r.profile||{}).grade }); });
        Object.assign(me.member,{name:p.name,join_date:p.join_date,certified_grade:p.certified_grade});
        return;
      }
      chk(await sb.rpc('update_my_profile',{
        p_name:p.name||null, p_join_date:p.join_date||null,
        p_certified_grade:p.certified_grade?+p.certified_grade:null }));
      Object.assign(me.member,{name:p.name,join_date:p.join_date,certified_grade:p.certified_grade});
    },

    /* 本人に公開された申し送りだけが返る（cloudではRLSが弾く） */
    async myNotes(){
      if(!CLOUD) return SELF_DEMO? demoNotesForSelf() : [];
      const r=await sb.from('notes').select('*').eq('member_id',me.member.id).order('occurred_on',{ascending:false});
      return chk(r)||[];
    },
    async myScores(){
      if(!CLOUD) return SELF_DEMO? demoAsSelf('scores','taken_on') : [];
      const r=await sb.from('quiz_scores').select('*').eq('member_id',me.member.id).order('taken_on',{ascending:false});
      return chk(r)||[];
    },
    async myReviews(){
      if(!CLOUD){
        const own=readJSON('careerstep:selfreviews',[]);
        if(!SELF_DEMO) return own.slice().sort((a,b)=>String(b.period).localeCompare(String(a.period)));
        return own.concat(demoAsSelf('reviews','period').filter(d=>!own.some(o=>o.kind===d.kind&&o.period===d.period)))
                  .sort((a,b)=>String(b.period).localeCompare(String(a.period)));
      }
      const r=await sb.from('reviews').select('*').eq('member_id',me.member.id).order('period',{ascending:false});
      return chk(r)||[];
    },
    async submitReview(p){
      if(!CLOUD){
        const list=readJSON('careerstep:selfreviews',[]);
        const i=list.findIndex(x=>x.kind===p.kind&&x.period===p.period);
        const row=Object.assign({id:'local-'+p.kind+'-'+p.period,member_id:'self',submitted_at:new Date().toISOString()},
          i>=0?list[i]:{}, p, {updated_at:new Date().toISOString()});
        if(i>=0) list[i]=row; else list.unshift(row);
        writeJSON('careerstep:selfreviews',list);
        return row;
      }
      chk(await sb.rpc('submit_review',{
        p_kind:p.kind, p_period:p.period,
        p_y:p.y||null, p_w:p.w||null, p_t:p.t||null,
        p_looking_back:p.looking_back||null, p_next_goal:p.next_goal||null }));
      return p;
    },

    /* ---------- 管理者用：まとめて読む ---------- */
    async adminLoad(){
      if(!CLOUD){
        return { members:demo.members, progress:demo.progress, states:demo.states,
                 notes:demo.notes.slice(), scores:demo.scores.slice(), reviews:demo.reviews.slice() };
      }
      const [m,p,s,n,q,rv]=await Promise.all([
        sb.from('members').select('*').order('unit',{nullsFirst:false}).order('name'),
        sb.from('progress').select('member_id,item_id,checked_at'),
        sb.from('member_state').select('*'),
        sb.from('notes').select('*').order('occurred_on',{ascending:false}),
        sb.from('quiz_scores').select('*').order('taken_on',{ascending:false}),
        sb.from('reviews').select('*').order('period',{ascending:false})
      ]);
      const progress={}; (chk(p)||[]).forEach(r=>{ (progress[r.member_id]=progress[r.member_id]||{})[r.item_id]=r.checked_at; });
      const states={};   (chk(s)||[]).forEach(r=>states[r.member_id]=r);
      return { members:chk(m)||[], progress, states, notes:chk(n)||[], scores:chk(q)||[], reviews:chk(rv)||[] };
    },

    /* ---------- 管理者用：書き込み ---------- */
    async addNote(n){
      const row=Object.assign({
        member_id:n.member_id, kind:n.kind||'memo', occurred_on:n.occurred_on||todayStr(),
        grade:n.grade||null, title:n.title||null, body:n.body, next_action:n.next_action||null,
        author_name:n.author_name||(me&&me.member.name)||null,
        visibility:n.visibility||'shared', pinned:!!n.pinned },
        CLOUD?{author_id:me.member.id}:{});
      if(!CLOUD){
        row.id='n-local-'+Date.now(); row.created_at=new Date().toISOString();
        demo.notes.unshift(row); writeJSON(DEMO_KEY,demo); return row;
      }
      const r=await sb.from('notes').insert(row).select().single();
      return chk(r);
    },
    async updateNote(id,patch){
      if(!CLOUD){
        const i=demo.notes.findIndex(x=>x.id===id);
        if(i>=0) Object.assign(demo.notes[i],patch);
        writeJSON(DEMO_KEY,demo); return;
      }
      chk(await sb.from('notes').update(patch).eq('id',id));
    },
    async deleteNote(id){
      if(!CLOUD){ demo.notes=demo.notes.filter(x=>x.id!==id); writeJSON(DEMO_KEY,demo); return; }
      chk(await sb.from('notes').delete().eq('id',id));
    },

    /* テスト結果。(member_id, quiz_name, taken_on) が同じものは上書きする */
    async saveScores(list){
      if(!list.length) return 0;
      if(!CLOUD){
        list.forEach(s=>{
          const i=demo.scores.findIndex(x=>x.member_id===s.member_id&&x.quiz_name===s.quiz_name&&x.taken_on===s.taken_on);
          const row=Object.assign({id:'s-local-'+Math.random().toString(36).slice(2)},i>=0?demo.scores[i]:{},s);
          if(i>=0) demo.scores[i]=row; else demo.scores.unshift(row);
        });
        writeJSON(DEMO_KEY,demo); return list.length;
      }
      chk(await sb.from('quiz_scores').upsert(list,{onConflict:'member_id,quiz_name,taken_on'}));
      return list.length;
    },
    async deleteScore(id){
      if(!CLOUD){ demo.scores=demo.scores.filter(x=>x.id!==id); writeJSON(DEMO_KEY,demo); return; }
      chk(await sb.from('quiz_scores').delete().eq('id',id));
    },

    async setUlComment(reviewId,text){
      if(!CLOUD){
        const i=demo.reviews.findIndex(x=>x.id===reviewId);
        if(i>=0){ demo.reviews[i].ul_comment=text; demo.reviews[i].ul_comment_by=(me&&me.member.name)||'UL'; }
        writeJSON(DEMO_KEY,demo); return;
      }
      chk(await sb.rpc('set_ul_comment',{p_review_id:reviewId,p_comment:text}));
    },

    async upsertMember(m){
      if(!CLOUD){
        const i=demo.members.findIndex(x=>x.id===m.id);
        if(i>=0) Object.assign(demo.members[i],m);
        else { m.id=m.id||'m-local-'+Date.now(); demo.members.push(m); demo.progress[m.id]={}; }
        writeJSON(DEMO_KEY,demo); return m;
      }
      const r = m.id
        ? await sb.from('members').update(m).eq('id',m.id).select().single()
        : await sb.from('members').insert(m).select().single();
      return chk(r);
    },

    /* ローカルモードのデモデータを作り直す */
    resetDemo(){ LS.del(DEMO_KEY); demo=buildDemo(); }
  };

  /* ログイン中の人が誰で、管理者かどうかを確定させる */
  async function resolveMe(){
    const u=await sb.auth.getUser();
    const uid=u&&u.data&&u.data.user&&u.data.user.id;
    if(!uid){ me=null; return null; }
    const m=chk(await sb.from('members').select('*').eq('auth_id',uid).maybeSingle());
    if(!m){ me=null; return null; }
    me={member:m, role:m.role, isManager:m.role==='ul'||m.role==='admin'};
    return me;
  }

  /* ローカルモードでは、本人側の画面も中身が入っている状態で確認したい。
     デモの1人目のメンバーのデータを自分宛てとして見せる。 */
  function demoAsSelf(key,sortField){
    const first=demo.members.find(m=>m.role==='member');
    const id=first&&first.id;
    return demo[key].filter(x=>x.member_id===id)
      .map(x=>Object.assign({},x,{member_id:'self'}))
      .sort((a,b)=>String(b[sortField]||'').localeCompare(String(a[sortField]||'')));
  }
  function demoNotesForSelf(){
    return demoAsSelf('notes','occurred_on').filter(n=>n.visibility==='shared');
  }

  return api;
})();
