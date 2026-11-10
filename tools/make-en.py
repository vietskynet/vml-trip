#!/usr/bin/env python3
"""Sinh bản tiếng Anh /en từ index.html (KHÔNG sửa logic game, chỉ nhúng lớp dịch hiển thị).
   Dùng: python3 tools/make-en.py   (chạy sau mỗi lần phát hành index.html)
   Từ điển: tools/en-dict.json  { "cụm tiếng Việt": "English" }  — thêm/sửa trực tiếp file này.
   Thống kê còn thiếu: python3 tools/make-en.py --missing"""
import json,os,re,sys
R=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src=open(R+'/index.html',encoding='utf8').read()
D=json.load(open(R+'/tools/en-dict.json',encoding='utf8'))
if '--missing' in sys.argv:
    vi=re.compile(r'[ăâđêôơưàáạảãèéẹẻẽìíịỉĩòóọỏõùúụủũỳýỵỷỹĂÂĐÊÔƠƯÀÁẠẢÃÈÉẸẺẼÌÍỊỈĨÒÓỌỎÕÙÚỤỦŨỲÝỴỶỸ]')
    lit=re.compile(r"'((?:[^'\\\n]|\\.)*)'|\"((?:[^\"\\\n]|\\.)*)\"|`((?:[^`\\]|\\.)*)`")
    fr=set()
    def split(t):
        t=re.sub(r'\$\{(?:[^{}]|\{[^{}]*\})*\}','\x00',t);t=re.sub(r'<[^>]*>','\x00',t)
        t=t.replace('\\n','\x00').replace("\\'","'")
        for p in t.split('\x00'):
            p=p.strip()
            if p and vi.search(p) and len(p)<=70 and not re.search(r"[;{}=]",p): fr.add(p)
    for m in lit.finditer(src):
        t=m.group(1) or m.group(2) or m.group(3)
        if t and vi.search(t): split(t)
    miss=sorted(x for x in fr if x not in D)
    print(len(fr),'cụm,',len(miss),'chưa dịch'); open(R+'/tools/en-missing.txt','w',encoding='utf8').write('\n'.join(miss)); sys.exit()
out=R+'/en';os.makedirs(out,exist_ok=True)
h=src
for f in ('config.js','supabase-shim.js','techcombank.png'):
    h=h.replace('"'+f+'"','"../'+f+'"')
h=h.replace('<html lang="vi">','<html lang="en">')
tag='<script src="en-dict.js"></script><script src="en.js"></script>'
i=h.index('<title>');h=h[:i]+tag+h[i:]
open(out+'/index.html','w',encoding='utf8').write(h)
open(out+'/en-dict.js','w',encoding='utf8').write('window.EN_D='+json.dumps(D,ensure_ascii=False,separators=(',',':'))+';')
open(out+'/en.js','w',encoding='utf8').write(open(R+'/tools/en-runtime.js',encoding='utf8').read())
print('en/ ok:',len(D),'mục từ điển')
