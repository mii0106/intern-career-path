/* ============================================================
   STEP — 共通UIパーツ（相棒のSVG・リング・トースト・整形）
   ============================================================ */

/* ------------------------------------------------------------
   権限は3つ。member・mentor（育成）・ul。
   育成とULでできることは同じで、管理者ツールで全員を見られる。
   'admin' は旧「管理者」で、まだ role を移していないサーバーから
   返ってくることがあるので、育成として扱う。
   ------------------------------------------------------------ */
const ROLES=[
  {k:'member', n:'メンバー', s:'メンバー', d:'自分のシートだけ'},
  {k:'mentor', n:'育成',     s:'育成',     d:'管理者ツールで全員を見られる'},
  {k:'ul',     n:'UL',       s:'UL',       d:'管理者ツールで全員を見られる'}
];
function roleKey(role){ return role==='admin' ? 'mentor' : (role||'member'); }
function isManagerRole(role){ const k=roleKey(role); return k==='mentor'||k==='ul'; }
function roleName(role){ const k=roleKey(role); return (ROLES.find(r=>r.k===k)||ROLES[0]).n; }
/* 育成とULをまとめて呼ぶときの言い方。画面の文言をここに集める */
const MANAGER_LABEL='育成・UL';

function star(cx,cy,r,f){
  return '<path d="M'+cx+' '+(cy-r)+' L'+(cx+r*0.32)+' '+(cy-r*0.32)+' L'+(cx+r)+' '+cy+' L'+(cx+r*0.32)+' '+(cy+r*0.32)+' L'+cx+' '+(cy+r)+' L'+(cx-r*0.32)+' '+(cy+r*0.32)+' L'+(cx-r)+' '+cy+' L'+(cx-r*0.32)+' '+(cy-r*0.32)+' Z" fill="'+f+'"/>';
}
/* 相棒：まるい光。育つほど大きくなり、リングと衛星が増えていく */
function creature(st,size,cls){
  const W='#FAF8FF', E='#2C2748', A='#FFC44D', A2='#FF9F45';
  const cx=60, cy=62, r=17+st*1.8;
  const p=[];
  const sp=(x,y,q,f)=>'<path d="M'+x+' '+(y-q)+' Q'+x+' '+y+' '+(x+q)+' '+y+' Q'+x+' '+y+' '+x+' '+(y+q)+' Q'+x+' '+y+' '+(x-q)+' '+y+' Q'+x+' '+y+' '+x+' '+(y-q)+' Z" fill="'+f+'"/>';
  const moon=(deg,rad,mr)=>{const t=deg*Math.PI/180;
    return '<circle cx="'+(cx+Math.cos(t)*rad).toFixed(1)+'" cy="'+(cy+Math.sin(t)*rad).toFixed(1)+'" r="'+mr+'" fill="'+A+'"/>';};

  if(st>=10) p.push('<circle cx="'+cx+'" cy="'+cy+'" r="'+(r+22)+'" fill="'+A+'" opacity=".10"/>');
  if(st>=8)  p.push('<circle cx="'+cx+'" cy="'+cy+'" r="'+(r+11)+'" fill="'+A+'" opacity=".13"/>');

  if(st>=6) p.push('<ellipse cx="'+cx+'" cy="'+cy+'" rx="'+(r+19)+'" ry="'+((r+19)*0.3).toFixed(1)+'" fill="none" stroke="'+A2+'" stroke-width="2.6" opacity=".8" transform="rotate(24 '+cx+' '+cy+')"/>');
  if(st>=4) p.push('<ellipse cx="'+cx+'" cy="'+cy+'" rx="'+(r+14)+'" ry="'+((r+14)*0.3).toFixed(1)+'" fill="none" stroke="'+A+'" stroke-width="3" transform="rotate(-16 '+cx+' '+cy+')"/>');

  p.push('<circle cx="'+cx+'" cy="'+cy+'" r="'+r+'" fill="'+W+'"/>');
  p.push('<circle cx="'+(cx-r*0.34).toFixed(1)+'" cy="'+(cy-r*0.3).toFixed(1)+'" r="'+(r*0.3).toFixed(1)+'" fill="#fff" opacity=".7"/>');

  const er=2.5+st*0.14, ex=r*0.33, ey=cy-r*0.05;
  p.push('<g class="eyes"><circle cx="'+(cx-ex).toFixed(1)+'" cy="'+ey.toFixed(1)+'" r="'+er.toFixed(1)+'" fill="'+E+'"/>'+
         '<circle cx="'+(cx+ex).toFixed(1)+'" cy="'+ey.toFixed(1)+'" r="'+er.toFixed(1)+'" fill="'+E+'"/></g>');
  if(st>=2) p.push('<path d="M'+(cx-r*0.2).toFixed(1)+' '+(ey+r*0.32).toFixed(1)+' q'+(r*0.2).toFixed(1)+' '+(r*0.22).toFixed(1)+' '+(r*0.4).toFixed(1)+' 0" stroke="'+E+'" stroke-width="2.1" fill="none" stroke-linecap="round"/>');

  const ms=[];
  if(st>=3) ms.push(moon(-25,r+17,4.2));
  if(st>=5) ms.push(moon(150,r+17,3.6));
  if(st>=7) ms.push(moon(75,r+17,3));
  if(ms.length) p.push('<g class="orbit">'+ms.join('')+'</g>');

  if(st>=9) p.push(sp(104,26,5,A)+sp(18,44,3.6,A)+sp(96,102,3.2,A));

  return '<svg class="art '+(cls||'')+'" viewBox="0 0 120 120" width="'+size+'" height="'+size+'" aria-hidden="true">'+
    '<g class="mochi">'+p.join('')+'</g></svg>';
}

/* 丸窓：月に向かって相棒が進んでいく。進捗＝月までの距離 */
function porthole(st,pct,accent){
  const cx=110, cy=100, R=78;
  const P0=[88,132], C=[60,100], P1=[132,68];
  const at=t=>[Math.pow(1-t,2)*P0[0]+2*(1-t)*t*C[0]+t*t*P1[0], Math.pow(1-t,2)*P0[1]+2*(1-t)*t*C[1]+t*t*P1[1]];
  const poly=n=>{let d='';for(let i=0;i<=n;i++){const q=at(i/n);d+=(i?' L':'M')+q[0].toFixed(1)+' '+q[1].toFixed(1);}return d;};
  const t=Math.min(1,Math.max(0,pct/100)), pos=at(t);
  const stars=[[52,58,1.6],[70,38,1.2],[96,30,1.8],[128,34,1.2],[160,84,1.5],[168,116,1.2],[62,120,1.4],[46,96,1.2],[92,150,1.6],[128,158,1.2],[150,138,1.5],[84,66,1.1],[112,50,1.3],[176,66,1.2],[58,140,1.2]]
    .map(v=>'<circle cx="'+v[0]+'" cy="'+v[1]+'" r="'+v[2]+'" fill="#fff" opacity=".75"/>').join('');
  const bolts=[0,45,90,135,180,225,270,315].map(a=>{
    const r=(a-90)*Math.PI/180;
    return '<circle cx="'+(cx+Math.cos(r)*84).toFixed(1)+'" cy="'+(cy+Math.sin(r)*84).toFixed(1)+'" r="2.6" fill="#D9D6EB"/>';}).join('');
  const arc=2*Math.PI*88;
  return '<svg viewBox="0 0 220 200" width="212" height="193" aria-hidden="true">'+
   '<defs><radialGradient id="ph_sky" cx="35%" cy="25%"><stop offset="0" stop-color="#33405F"/><stop offset="1" stop-color="#131A2B"/></radialGradient>'+
   '<clipPath id="ph_c"><circle cx="'+cx+'" cy="'+cy+'" r="'+R+'"/></clipPath></defs>'+
   '<circle cx="'+cx+'" cy="'+cy+'" r="84" fill="#F5F4FB"/>'+bolts+
   '<circle cx="'+cx+'" cy="'+cy+'" r="'+R+'" fill="url(#ph_sky)"/>'+
   '<g clip-path="url(#ph_c)">'+stars+
     '<circle cx="152" cy="52" r="30" fill="#fff" opacity=".08"/>'+
     '<circle cx="152" cy="52" r="20" fill="#EFEDE2"/>'+
     '<circle cx="146" cy="46" r="4" fill="#DAD7C7"/><circle cx="158" cy="58" r="3" fill="#DAD7C7"/><circle cx="157" cy="43" r="2.2" fill="#DAD7C7"/>'+
     '<path d="M40 44 l16 -12" stroke="#fff" stroke-width="1.6" opacity=".5" stroke-linecap="round"/>'+
     '<path d="M74 152 l14 -11" stroke="#fff" stroke-width="1.4" opacity=".35" stroke-linecap="round"/>'+
     '<path d="'+poly(24)+'" stroke="#fff" stroke-width="1.6" fill="none" opacity=".25" stroke-dasharray="3 5"/>'+
     (t>0.02?'<path d="'+poly(Math.max(2,Math.round(24*t)))+'" stroke="'+accent+'" stroke-width="2.4" fill="none" opacity=".9" stroke-linecap="round"/>':'')+
     '<g transform="translate('+(pos[0]-41).toFixed(1)+','+(pos[1]-41).toFixed(1)+') scale(.68)">'+creature(st,120,'float')+'</g>'+
   '</g>'+
   '<circle cx="'+cx+'" cy="'+cy+'" r="'+R+'" fill="none" stroke="#E4E2F2" stroke-width="4"/>'+
   '<circle cx="'+cx+'" cy="'+cy+'" r="88" fill="none" stroke="#EDEBF7" stroke-width="5"/>'+
   '<circle cx="'+cx+'" cy="'+cy+'" r="88" fill="none" stroke="'+accent+'" stroke-width="5" stroke-linecap="round" stroke-dasharray="'+arc+'" stroke-dashoffset="'+(arc*(1-t))+'" transform="rotate(-90 '+cx+' '+cy+')"/>'+
   '</svg>';
}

/* ============================================================
   SMALL UI PARTS
   ============================================================ */
const SPK_ON='<svg width="17" height="17" viewBox="0 0 24 24" fill="none"><path d="M4 9.5h3.6L12.5 5v14L7.6 14.5H4z" fill="currentColor"/><path d="M16 9.2a4 4 0 0 1 0 5.6M18.7 6.6a7.6 7.6 0 0 1 0 10.8" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>';
const SPK_OFF='<svg width="17" height="17" viewBox="0 0 24 24" fill="none"><path d="M4 9.5h3.6L12.5 5v14L7.6 14.5H4z" fill="currentColor"/><path d="M16.5 9.5l5 5m0-5l-5 5" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/></svg>';
const LOCK='<svg width="11" height="11" viewBox="0 0 24 24" fill="none"><path d="M7 10V7a5 5 0 0 1 10 0v3" stroke="#B9B4D0" stroke-width="2.6" stroke-linecap="round"/><rect x="4.5" y="10" width="15" height="10.5" rx="3" fill="#B9B4D0"/></svg>';
const CHECK='<svg width="13" height="13" viewBox="0 0 24 24" fill="none"><path d="M4 12.5 L9.5 18 L20 6.5" stroke="#fff" stroke-width="3.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';
function ring(pct,color,label){
  const r=19,c=2*Math.PI*r;
  return '<div class="ring"><svg width="46" height="46" viewBox="0 0 46 46">'+
   '<circle cx="23" cy="23" r="'+r+'" fill="none" stroke="#EFEDF9" stroke-width="5"/>'+
   '<circle cx="23" cy="23" r="'+r+'" fill="none" stroke="'+color+'" stroke-width="5" stroke-linecap="round" stroke-dasharray="'+c+'" stroke-dashoffset="'+(c*(1-pct/100))+'" transform="rotate(-90 23 23)"/>'+
   '</svg><b style="color:'+color+'">'+(label!=null?label:pct)+'</b></div>';
}
/* クリップボードにコピー（本人画面・管理者ツールの両方で使う） */
async function copyText(text,okMsg){
  try{
    await navigator.clipboard.writeText(text);
    toast(okMsg||'コピーしました');
  }catch(e){
    /* 権限が無い環境向けの保険 */
    const ta=document.createElement('textarea');
    ta.value=text; ta.style.position='fixed'; ta.style.opacity='0';
    document.body.appendChild(ta); ta.select();
    try{ document.execCommand('copy'); toast(okMsg||'コピーしました'); }
    catch(e2){ toast('コピーできませんでした','bad'); }
    ta.remove();
  }
}
function esc(s){return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');}
/* トーストは読み上げにも乗せる。表示は3秒（1.5秒だと読み終わらない） */
function toast(msg,cls,ms){
  const box=document.getElementById('toasts');
  if(!box) return;
  const t=document.createElement('div');t.className='toast '+(cls||'');t.textContent=msg;
  box.appendChild(t);
  setTimeout(()=>{t.style.transition='opacity .3s';t.style.opacity='0';setTimeout(()=>t.remove(),320);},ms||3000);
}

/* ============================================================
   再描画のときに、入力中の場所を保つ
   ------------------------------------------------------------
   どちらの画面も innerHTML を丸ごと書き替えているので、
   そのままだと入力欄のフォーカスとカーソル位置が飛ぶ。
   日本語を変換している最中（IME）は、描画そのものを見送る。
   ============================================================ */
let IME_ON=false;
if(typeof document!=='undefined'){
  document.addEventListener('compositionstart',()=>{IME_ON=true;});
  document.addEventListener('compositionend',()=>{IME_ON=false;});
}
function isComposing(){ return IME_ON; }
/* 入力欄を特定するための目印。id か data-* のどれかがあれば戻せる */
function focusKey(el){
  if(!el||!el.tagName) return null;
  const tag=el.tagName.toLowerCase();
  if(tag!=='input'&&tag!=='textarea'&&tag!=='select') return null;
  if(el.id) return '#'+el.id;
  for(const a of ['data-draft','data-field','data-creed','data-custom']){
    const v=el.getAttribute(a);
    if(v!=null) return '['+a+'="'+v.replace(/"/g,'\\"')+'"]';
  }
  return null;
}
function withFocus(fn){
  const el=document.activeElement;
  const key=focusKey(el);
  const pos=key&&el.selectionStart!=null? [el.selectionStart,el.selectionEnd] : null;
  fn();
  if(!key) return;
  const next=document.querySelector(key);
  if(!next) return;
  next.focus();
  if(pos){ try{ next.setSelectionRange(pos[0],pos[1]); }catch(e){} }
}

/* ============================================================
   整形ヘルパー
   ============================================================ */
function fmtDate(d){
  if(!d) return '—';
  const s=String(d).slice(0,10).split('-');
  return s.length===3? (+s[1])+'/'+(+s[2]) : String(d);
}
function fmtDateFull(d){
  if(!d) return '—';
  const s=String(d).slice(0,10).split('-');
  return s.length===3? s[0]+'/'+(+s[1])+'/'+(+s[2]) : String(d);
}
function fmtDateTime(d){
  if(!d) return '—';
  const t=new Date(d);
  if(isNaN(t)) return String(d);
  return t.getFullYear()+'/'+(t.getMonth()+1)+'/'+t.getDate()+' '+String(t.getHours()).padStart(2,'0')+':'+String(t.getMinutes()).padStart(2,'0');
}
function daysAgo(d){
  if(!d) return null;
  const t=new Date(d);
  if(isNaN(t)) return null;
  return Math.floor((Date.now()-t.getTime())/864e5);
}
function relDays(d){
  const n=daysAgo(d);
  if(n==null) return '—';
  if(n<=0) return '今日';
  if(n===1) return '昨日';
  if(n<30) return n+'日前';
  if(n<365) return Math.floor(n/30)+'ヶ月前';
  return Math.floor(n/365)+'年前';
}
function todayStr(){ return new Date().toISOString().slice(0,10); }
/* CSVの1セル。改行・カンマ・引用符を含む場合だけ引用符で囲む */
function csvCell(v){
  const s=v==null?'':String(v);
  return /[",\n\r]/.test(s) ? '"'+s.replace(/"/g,'""')+'"' : s;
}
function csvRows(rows){ return rows.map(r=>r.map(csvCell).join(',')).join('\r\n'); }
/* Excelで開いてもUTF-8と認識されるようBOMを付ける */
function downloadCSV(name,rows){
  downloadBlob(name,'﻿'+csvRows(rows),'text/csv;charset=utf-8');
}
function downloadBlob(name,text,type){
  const b=new Blob([text],{type:type||'application/json'});
  const u=URL.createObjectURL(b), a=document.createElement('a');
  a.href=u; a.download=name; document.body.appendChild(a); a.click(); a.remove();
  setTimeout(()=>URL.revokeObjectURL(u),1000);
}
/* 素朴なCSVパーサ（引用符・エスケープ・CRLF対応） */
function parseCSV(text){
  const rows=[]; let row=[], cell='', q=false;
  const s=text.replace(/^﻿/,'');
  for(let i=0;i<s.length;i++){
    const c=s[i];
    if(q){
      if(c==='"'){ if(s[i+1]==='"'){ cell+='"'; i++; } else q=false; }
      else cell+=c;
    }else if(c==='"'){ q=true; }
    else if(c===','){ row.push(cell); cell=''; }
    else if(c==='\n'){ row.push(cell); cell=''; rows.push(row); row=[]; }
    else if(c!=='\r'){ cell+=c; }
  }
  if(cell!==''||row.length){ row.push(cell); rows.push(row); }
  return rows.filter(r=>r.some(c=>String(c).trim()!==''));
}
function clamp(n,a,b){ return Math.max(a,Math.min(b,n)); }

/* ============================================================
   振り返りの期間キー
     隔週YWT … 'YYYY-MM-A'（1〜15日）/ 'YYYY-MM-B'（16日〜）
     月次     … 'YYYY-MM'
   ============================================================ */
function ywtPeriod(d){
  const t=d?new Date(d):new Date();
  return t.getFullYear()+'-'+String(t.getMonth()+1).padStart(2,'0')+(t.getDate()<=15?'-A':'-B');
}
function monthlyPeriod(d){
  const t=d?new Date(d):new Date();
  return t.getFullYear()+'-'+String(t.getMonth()+1).padStart(2,'0');
}
function periodLabel(kind,p){
  if(!p) return '—';
  if(kind==='ywt'){
    const m=String(p).match(/^(\d{4})-(\d{2})-(A|B)$/);
    return m? (+m[2])+'月'+(m[3]==='A'?'前半':'後半') : p;
  }
  const m=String(p).match(/^(\d{4})-(\d{2})$/);
  return m? (+m[2])+'月' : p;
}
/* 直近 n 期間のキーを新しい順に返す */
function recentPeriods(kind,n){
  const out=[], t=new Date();
  if(kind==='monthly'){
    for(let i=0;i<n;i++){ const d=new Date(t.getFullYear(),t.getMonth()-i,1); out.push(monthlyPeriod(d)); }
  }else{
    let y=t.getFullYear(), mo=t.getMonth(), half=t.getDate()<=15?'A':'B';
    for(let i=0;i<n;i++){
      out.push(y+'-'+String(mo+1).padStart(2,'0')+'-'+half);
      if(half==='B') half='A'; else { half='B'; mo--; if(mo<0){ mo=11; y--; } }
    }
  }
  return out;
}
