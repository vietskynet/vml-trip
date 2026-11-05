/* =====================================================================
   VML Trip · lớp kết nối Supabase
   Cung cấp đúng những hàm game cần (giống Firebase Realtime Database),
   nhưng lưu dữ liệu trong Supabase. Không dùng Realtime: mỗi máy hỏi
   máy chủ ~1,5 giây một lần, nên không vướng giới hạn tin nhắn/giây.
   ===================================================================== */
(function(){
'use strict';
window.VMLSupabaseShim=function(cfg){
  const sb=window.supabase.createClient(cfg.url,cfg.anonKey,{auth:{persistSession:true,autoRefreshToken:true,storageKey:'vml-trip-auth'}});
  const POLL=cfg.pollMs||1500;
  const root={};const L=[];let since=0,offset=0,uid=null,timer=null,kickT=null,syncing=false,again=false,lastErr='';
  let readyRes;const ready=new Promise(r=>{readyRes=r});
  const parts=p=>String(p||'').split('/').filter(Boolean);
  const clone=v=>v==null?null:JSON.parse(JSON.stringify(v));
  const getAt=p=>{let n=root;for(const k of parts(p)){if(n==null||typeof n!=='object')return null;n=n[k]}return n===undefined?null:n};
  const fixLocal=v=>{if(v&&typeof v==='object'){if(v['.sv'])return Date.now()+offset;const o={};let any=false;for(const k in v){const x=fixLocal(v[k]);if(x!==null&&x!==undefined){o[k]=x;any=true}}return any?o:null}return v};
  function setAt(p,v){v=fixLocal(clone(v));const ps=parts(p);if(!ps.length)return;let n=root;const trail=[];
    for(let i=0;i<ps.length-1;i++){if(n[ps[i]]==null||typeof n[ps[i]]!=='object')n[ps[i]]={};trail.push([n,ps[i]]);n=n[ps[i]]}
    const last=ps[ps.length-1];if(v==null)delete n[last];else n[last]=v;
    for(let i=trail.length-1;i>=0;i--){const [o,k]=trail[i];if(o[k]&&typeof o[k]==='object'&&!Object.keys(o[k]).length)delete o[k];else break}}
  const snap=(p,v)=>({key:parts(p).pop()||null,val:()=>clone(v),exists:()=>v!=null,ref:ref(p)});
  function fire(l){const v=getAt(l.p);
    if(l.ev==='value'){const s=JSON.stringify(v);if(s!==l.last){l.last=s;try{l.cb(snap(l.p,v))}catch(e){console.error(e)}}return}
    const cur=v&&typeof v==='object'?v:{},prev=l.prev||{};
    try{
      if(l.ev==='child_added')for(const k in cur)if(!(k in prev))l.cb(snap(l.p+'/'+k,cur[k]));
      if(l.ev==='child_changed')for(const k in cur)if(k in prev&&JSON.stringify(prev[k])!==JSON.stringify(cur[k]))l.cb(snap(l.p+'/'+k,cur[k]));
      if(l.ev==='child_removed')for(const k in prev)if(!(k in cur))l.cb(snap(l.p+'/'+k,prev[k]));
    }catch(e){console.error(e)}
    l.prev=clone(cur)}
  const notify=()=>{for(const l of L.slice())fire(l)};
  async function sync(){if(!uid)return;if(syncing){again=true;return}syncing=true;
    try{const t0=Date.now();const {data,error}=await sb.rpc('rt_sync',{since:since?since-3000:0});if(error)throw error;
      offset=data.now-Math.round((t0+Date.now())/2);
      (data.docs||[]).forEach(d=>setAt(d.p,d.v));
      root.pos=data.pos||{};root.admins=data.admin?{[uid]:true}:{};
      since=data.now;notify();readyRes(true)}
    catch(e){lastErr=(e&&(e.message||e.msg||e.code))||String(e);console.warn('Đồng bộ Supabase lỗi:',lastErr)}
    finally{syncing=false;if(again){again=false;kick(50)}}}
  const kick=ms=>{clearTimeout(kickT);kickT=setTimeout(sync,ms)};
  function start(){if(timer)return;sync();timer=setInterval(sync,POLL)}
  // vị trí: gộp lại, gửi tối đa 1 lần/giây, nhắc lại mỗi 8 giây để giữ trạng thái online
  let posPending=null,posLast='',posSentAt=0;
  setInterval(()=>{if(!uid||posPending==null)return;const s=JSON.stringify(posPending),now=Date.now();if(s!==posLast||now-posSentAt>8000){posLast=s;posSentAt=now;sb.rpc('pos_set',{v:posPending}).then(r=>{if(r.error)console.warn(r.error.message)})}},1000);
  addEventListener('pagehide',()=>{if(uid)sb.rpc('pos_leave')});
  function write(ops){ops=ops.filter(o=>!/^pos(\/|$)/.test(o.p));if(!ops.length)return Promise.resolve();
    return sb.rpc('rt_write',{ops}).then(r=>{if(r.error){console.warn('Ghi dữ liệu bị từ chối:',r.error.message);since=0;kick(0)}else kick(120)})}
  function ref(path){const p=parts(path).join('/');
    const r={key:parts(p).pop()||null,path:p,
      child:c=>ref(p+'/'+c),
      push:()=>ref(p+'/'+'k'+Date.now().toString(36)+Math.random().toString(36).slice(2,8)),
      set(v){if(/^pos\//.test(p)){if(v==null){posPending=null;sb.rpc('pos_leave')}else posPending=fixLocal(clone(v));setAt(p,v);notify();return Promise.resolve()}
        setAt(p,v);notify();return write([{p,v:v==null?null:v}])},
      update(o){const ops=[];for(const k in o){const q=p?p+'/'+k:k;setAt(q,o[k]);ops.push({p:q,v:o[k]==null?null:o[k]})}notify();return write(ops)},
      remove(){return r.set(null)},
      get(){return Promise.race([ready,new Promise((_,rej)=>setTimeout(()=>rej(new Error(lastErr?'Lỗi đồng bộ: '+lastErr:'Hết thời gian chờ máy chủ')),12000))]).then(()=>snap(p,getAt(p)))},
      on(ev,cb){if(p==='.info/serverTimeOffset'){ready.then(()=>cb(snap(p,offset)));return cb}
        if(p==='.info/connected'){ready.then(()=>cb(snap(p,true)));return cb}
        const l={p,ev,cb};if(ev!=='value')l.prev={};L.push(l);ready.then(()=>fire(l));return cb},
      off(){for(let i=L.length-1;i>=0;i--)if(L[i].p===p)L.splice(i,1)},
      async transaction(fn){await ready;for(let a=0;a<4;a++){const cur=clone(getAt(p));const nv=fn(cur);if(nv===undefined)return{committed:false,snapshot:snap(p,cur)};
          const {data,error}=await sb.rpc('rt_cas',{p,expected:cur,v:nv==null?null:nv});if(error)throw error;
          setAt(p,data.cur);notify();if(data.ok){kick(120);return{committed:true,snapshot:snap(p,data.cur)}}if(data.denied)break}
        return{committed:false,snapshot:snap(p,getAt(p))}},
      onDisconnect:()=>({remove:()=>Promise.resolve()})};
    return r}
  const authCbs=[];
  const auth={
    onAuthStateChanged(cb){authCbs.push(cb);sb.auth.getSession().then(({data})=>{const u=data&&data.session&&data.session.user;if(u){uid=u.id;start()}cb(u?{uid:u.id}:null)});return()=>{const i=authCbs.indexOf(cb);if(i>=0)authCbs.splice(i,1)}},
    signInAnonymously(){return sb.auth.signInAnonymously().then(({data,error})=>{if(error)throw new Error('Đăng nhập ẩn danh lỗi: '+(error.message||error.code));uid=data.user.id;start();authCbs.slice().forEach(cb=>cb({uid}))})},
    signOut(){return sb.rpc('pos_leave').then(()=>sb.auth.signOut()).then(()=>{uid=null})}};
  const database=Object.assign(()=>({ref}),{ServerValue:{TIMESTAMP:{'.sv':'timestamp'}}});
  return{initializeApp(){},auth:()=>auth,database,__supabase:sb};
};
})();
