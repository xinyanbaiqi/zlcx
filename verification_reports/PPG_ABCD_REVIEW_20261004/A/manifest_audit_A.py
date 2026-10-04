from pathlib import Path
import re,hashlib,json
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
def digest(data):return hashlib.sha256(data).hexdigest()
def normalized(data):
    rows=list(re.finditer(rb'(?m)^\| M01 \|[^\r\n]*',data));assert len(rows)==1
    row=rows[0];hashes=list(re.finditer(rb'(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])',row[0]));assert len(hashes)==1
    h=hashes[0];a=row.start()+h.start();b=row.start()+h.end()
    return data[:a]+b'<SELF_SHA256>'+data[b:]
def audit(rows,files):
    out=[]
    for row in rows:
        r=dict(row);key=row['file']
        if key not in files:r['status']='missing'
        else:
            data=files[key];r['actual']=digest(normalized(data) if row['id']=='M01' else data)
            r['status']='match' if r['actual']==row['declared'] else 'mismatch'
        out.append(r)
    return out
good=b'UTF8\r\n';bad=b'UTF8_changed\r\n'
controls=audit([{'id':'C01','file':'good','declared':digest(good)},{'id':'C02','file':'changed','declared':digest(good)},{'id':'C03','file':'wrongdigest','declared':'0'*64},{'id':'C04','file':'missing','declared':digest(good)}],{'good':good,'changed':bad,'wrongdigest':good})
assert [r['status'] for r in controls]==['match','mismatch','mismatch','missing'],controls
fixture=b'line\r\n| M01 | matrix | `'+b'0'*64+b'` |\r\n'
assert normalized(fixture)==normalized(fixture.replace(b'0'*64,b'f'*64))
assert digest(normalized(fixture))!=digest(normalized(fixture.replace(b'line',b'wrong')))
(E/'manifest_negative_controls.json').write_text(json.dumps({'cases':controls,'self_digest_field_ignored':True,'other_text_change_detected':True},indent=2),encoding='utf-8')
p=S/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md';raw=p.read_bytes();lines=raw.decode('utf-8').splitlines();rows=[]
for n,line in enumerate(lines,1):
    if n<1234 or n>1262:continue
    m=re.match(r'^\| (C\d\d|M01) \|',line)
    if not m:continue
    cells=line.split('|');h=re.findall(r'(?<![0-9a-f])[0-9a-f]{64}(?![0-9a-f])',line);assert len(h)==1
    f=cells[3].strip().strip('`');rows.append({'id':m[1],'file':f,'manifest_line':n,'declared':h[0]})
assert len(rows)==26 and len({r['id'] for r in rows})==26,rows
files={r['file']:(S/'contracts'/r['file']).read_bytes() for r in rows}
results=audit(rows,files)
(E/'manifest_audit_A.json').write_text(json.dumps({'commit':'d18c6954621e53e5a6505dd3a6c688c266d23839','method':'Full raw UTF8/CRLF bytes; M01 only its own digest field normalized per matrix 1226-1232. Negative controls executed before audit.','rows':results},ensure_ascii=False,indent=2),encoding='utf-8')
for r in results:print(r['id'],r['status'],r['manifest_line'],r.get('actual'))
print('MANIFEST_NEGATIVE_CONTROLS_PASS',len(controls))
