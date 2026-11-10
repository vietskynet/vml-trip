/* VML Trip · lớp dịch EN (chỉ đổi HIỂN THỊ, không đụng logic game).
   Chạy TRƯỚC script game: bọc canvas fillText/measureText + MutationObserver cho DOM.
   Từ điển: window.EN_D (en-dict.js, sinh bởi tools/make-en.py từ tools/en-dict.json). */
(function(){
'use strict';
var D=window.EN_D||{},VI=/[ăâđêôơưàáạảãèéẹẻẽìíịỉĩòóọỏõùúụủũỳýỵỷỹĂÂĐÊÔƠƯÀÁẠẢÃÈÉẸẺẼÌÍỊỈĨÒÓỌỎÕÙÚỤỦŨỲÝỴỶỸ]/;
var M=new Map(Object.keys(D).map(function(k){return[k,D[k]]})),cache=new Map(),phr=null;
function esc(s){return s.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')}
function phrases(){if(phr)return phr;var ks=Object.keys(D).filter(function(k){return k.length>=6&&k.indexOf(' ')>0}).sort(function(a,b){return b.length-a.length});phr=ks.length?new RegExp(ks.map(esc).join('|'),'g'):/$^/;return phr}
var RL=null;
function rules(){if(RL)return RL;var R=window.EN_R||{};RL=Object.keys(R).map(function(k){var parts=k.trim().split(/\{\d+\}/),n=0;var re=new RegExp('^'+parts.map(esc).join('(.+?)')+'$');return{re:re,en:R[k],len:parts.join('').length}}).sort(function(a,b){return b.len-a.len});return RL}
function rule(s){var t=s.trim(),L=rules();for(var i=0;i<L.length;i++){var m=L[i].re.exec(t);if(m){var c=m;return s.replace(t,function(){return L[i].en.replace(/\{(\d+)\}/g,function(_,n){var v=c[+n];return v==null?'':tr(v)})})}}return null}
function one(s){var t=s.trim();if(!t)return s;var e=M.get(t);if(e!=null)return s.replace(t,function(){return e});return null}
function tr(s){
 if(typeof s!=='string'||s.length<2||!VI.test(s))return s;
 var c=cache.get(s);if(c!==undefined)return c;
 var r=one(s);
 if(r==null)r=rule(s);
 if(r==null){
  /* tách theo " · " rồi dịch từng đoạn đủ khớp, sau đó thay các cụm dài */
  if(s.indexOf(' · ')>0)r=s.split(' · ').map(function(p){var o=one(p);return o==null?p.replace(phrases(),function(m){return D[m]}):o}).join(' · ');
  else r=s.replace(phrases(),function(m){return D[m]});
 }
 var left=(r.match(/[ăâđêôơưàáạảãèéẹẻẽìíịỉĩòóọỏõùúụủũỳýỵỷỹĂÂĐÊÔƠƯÀÁẠẢÃÈÉẸẺẼÌÍỊỈĨÒÓỌỎÕÙÚỤỦŨỲÝỴỶỸ]/g)||[]).length;if(r!==s&&left>2&&left>=(s.match(/[ăâđêôơưàáạảãèéẹẻẽìíịỉĩòóọỏõùúụủũỳýỵỷỹĂÂĐÊÔƠƯÀÁẠẢÃÈÉẸẺẼÌÍỊỈĨÒÓỌỎÕÙÚỤỦŨỲÝỴỶỸ]/g)||[]).length*.25)r=s; /* còn nhiều tiếng Việt chưa dịch: giữ nguyên câu gốc cho khỏi lẫn lộn */
 if(cache.size>6000)cache.clear();
 cache.set(s,r);return r}
window.__tr=tr;
/* ---- canvas ---- */
var CP=window.CanvasRenderingContext2D&&CanvasRenderingContext2D.prototype;
if(CP){['fillText','strokeText'].forEach(function(n){var o=CP[n];CP[n]=function(t,x,y,w){return w===undefined?o.call(this,tr(t),x,y):o.call(this,tr(t),x,y,w)}});
 var mt=CP.measureText;CP.measureText=function(t){return mt.call(this,tr(t))}}
/* ---- DOM ---- */
var SKIP='SCRIPT,STYLE,TEXTAREA,INPUT,CODE';
function skip(n){for(;n&&n!==document;n=n.parentNode){if(n.nodeType===1&&(SKIP.indexOf(n.tagName)>=0||n.id==='chatLog'||n.hasAttribute&&n.hasAttribute('data-notr')))return true}return false}
function fixText(n){var v=n.nodeValue;if(!v||!VI.test(v))return;if(skip(n.parentNode))return;var r=tr(v);if(r!==v)n.nodeValue=r}
var ATT=['placeholder','title','aria-label','alt'];
function fixEl(e){ATT.forEach(function(a){var v=e.getAttribute&&e.getAttribute(a);if(v&&VI.test(v)){var r=tr(v);if(r!==v)e.setAttribute(a,r)}})}
function walk(root){if(!root)return;if(root.nodeType===3){fixText(root);return}if(root.nodeType!==1)return;if(skip(root))return;fixEl(root);var w=document.createTreeWalker(root,5),n;while((n=w.nextNode())){if(n.nodeType===3)fixText(n);else if(!skip(n))fixEl(n)}}
function start(){document.documentElement.lang='en';if(document.title)document.title=tr(document.title);
 walk(document.body);
 var ob=new MutationObserver(function(rs){for(var i=0;i<rs.length;i++){var r=rs[i];if(r.type==='childList'){for(var j=0;j<r.addedNodes.length;j++)walk(r.addedNodes[j])}else if(r.type==='characterData')fixText(r.target);else if(r.type==='attributes')fixEl(r.target)}ob.takeRecords()});
 ob.observe(document.body,{childList:true,subtree:true,characterData:true,attributes:true,attributeFilter:ATT})}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start);else start();
})();
