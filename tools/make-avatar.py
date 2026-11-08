#!/usr/bin/env python3
"""Tạo avatar.html từ index.html: bản chỉ để vẽ hình nhân vật/vật phẩm cho trang admin.
Không nạp supabase/firebase, không kết nối mạng, không đăng nhập. Chạy lại mỗi lần sửa index.html."""
import re,sys
src=open('index.html',encoding='utf8').read()
# 1. bỏ các script mạng ở head
for pat in [r'<script src="https://cdn\.jsdelivr\.net/npm/@supabase[^>]*></script>\s*',r'<script src="supabase-shim\.js"></script>\s*',r'<script src="config\.js"></script>\s*']:
    src,n=re.subn(pat,'',src,count=1)
    assert n==1,pat
# 2. thay phần khởi động game bằng API vẽ
a=src.index("const fontsReady=Promise.race(")
b=src.rindex("})();")
api=r'''
const AVL=()=>Object.assign({},lookFromCR(CR));
function avCanvasSkin(K,L,pets){const fr=makeFrames(Object.assign({},L,{cos:K?K.id:''})).down[0],c=document.createElement('canvas');c.width=100;c.height=104;const g=c.getContext('2d');g.imageSmoothingEnabled=false;g.clearRect(0,0,100,104);
 g.save();g.scale(2,2);const x=25,y=49,lift=K&&K.ride?Math.min(RIDE_LIFT[K.ride],10):0;if(K)skinRide(g,K,x,y,1.2,'right',false,false);if(K)skinWing(g,K,x,y-lift,1.2);g.drawImage(fr,x-10,y-31-lift);if(K){skinRide(g,K,x,y,1.2,'right',false,true);skinHead(g,K,x,y-lift-28,1.2,'down')}g.restore();return c.toDataURL()}
const AVC={};
window.__av={ready:true,
 data(){return{skins:SKINS_LIST.map(k=>({id:k.id,n:k.n,p:k.p0!=null?k.p0:k.p,th:k.th,lim:k.lim?1:0,oid:k.oid||null})),limSkins:LIM_SK.map(k=>({id:k.id,n:k.n,t:k.t})),pets:PETS.map((p,i)=>({i,id:p.id||null,n:p.name,p:p.price,cat:p.cat,lim:p.lim?1:0,t:p.t==null?null:p.t})),deco:DECO.map(d=>({id:d.id,n:d.n,p:d.p,slot:d.slot})),cdeco:CDECO.map(d=>({id:d.id,n:d.n,p:d.p,slot:d.slot})),castleN:CASTLE_N,castleP:CASTLE_PRICE.slice(),house:CFG.PRICE,plate:PLATE_PRICE,cplate:CPLATE_PRICE,lim:LIM_ITEMS.map(i=>({id:i.id,kind:i.kind,t:i.t,n:i.n,lf:i.lf,pi:i.pi!=null?i.pi:null,price:i.price})),lmLand:LM_LAND,lmSeeds:LM_SEEDS.map(s=>({id:s.id,n:s.n,p:s.p})),lmJoin:LM_JOIN,roomNames:ROOM_NAMES}},
 unit(t,i){return lodgeName({type:t,i})},
 lmTier:n=>lmTier(n),
 char(look,cos,hr){const k='c|'+JSON.stringify([look,cos,hr]);if(AVC[k])return AVC[k];const L=lookFromCR(normLook(look||{}));try{const hd=hr?hdOf(hr):null;if(hd)L.hd=hd}catch(e){}return AVC[k]=avCanvasSkin(cos&&SKIN_BY[cos]?SKIN_BY[cos]:null,L)},
 skin(id){const k='s|'+id;if(AVC[k])return AVC[k];const K=SKIN_BY[id];if(!K)return'';return AVC[k]=avCanvasSkin(K,AVL())},
 pet(i){try{return petImg(i)}catch(e){return''}},
 deco(id){const k='d|'+id;if(AVC[k])return AVC[k];const d=DECO_BY[id]||CDECO.find(x=>x.id===id);if(!d)return'';const c=document.createElement('canvas');c.width=64;c.height=56;const g=c.getContext('2d');g.imageSmoothingEnabled=false;const y=d.ty||(d.slot==='top'?24:d.slot==='door'?24:52);try{d.d(g,32,y,1.3)}catch(e){}return AVC[k]=c.toDataURL()}};
'''
out=src[:a]+api+src[b:]
open('avatar.html','w',encoding='utf8').write(out)
print('avatar.html',len(out))
