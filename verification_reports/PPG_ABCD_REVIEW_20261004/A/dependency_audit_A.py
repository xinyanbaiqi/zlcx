from pathlib import Path
import re,json,hashlib,subprocess
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
version=lambda t:re.search(r'(?<![A-Za-z0-9])V\d+(?:\.\d+)*(?!\d|\.\d)',t)[0]
assert [version(t) for t in ['> V1.10修订','> V2.3, current','> V1.2.3. state']]==['V1.10','V2.3','V1.2.3']
def check(declared,header,exists=True):return 'missing' if not exists else 'match' if declared==version(header) else 'mismatch'
controls=[check('V1.10','> V1.10修订'),check('V1.9','> V1.10修订'),check('V1.10','> V1.10修订',False)]
assert controls==['match','mismatch','missing']
raw=(S/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8');lines=raw.splitlines();ids={}
for line in lines[1195:1222]:
    m=re.match(r'^\| (C\d\d) \| `([^`]+)`',line)
    if m:ids[m[1]]=Path(m[2]).name
assert len(ids)==25
rows=[]
rx=r'(C\d\d) `([^`]+)` (V\d+(?:\.\d+)*) \[(C\d\d):(\d+) -> (C\d\d):3\]'
for n,line in enumerate(lines,1):
    if not 1284<=n<=1310:continue
    for m in re.finditer(rx,line):
        target,path,declared,source,ln,target2=m.groups();assert target==target2
        p=S/'contracts'/ids[target];slines=(S/'contracts'/ids[source]).read_text(encoding='utf-8').splitlines()
        header=p.read_text(encoding='utf-8').splitlines()[2];source_line=slines[int(ln)-1]
        rows.append({'matrix_line':n,'source':source,'source_line_number':int(ln),'target':target,'path':path,'target_header_line':3,'declared':declared,'header_version':version(header),'status':check(declared,header),'source_path_text_matches':Path(path).name in source_line,'source_version_text_matches':declared in source_line,'source_text':source_line})
assert len(rows)==141,len(rows)
git='D:/Git/cmd/git.exe';clone=B/'zlcx';fixed='d18c6954621e53e5a6505dd3a6c688c266d23839'
blobs=[]
for f in list(ids.values())+['PPG_CONTRACT_CLOSURE_MATRIX.md']:
    blob=subprocess.run([git,'-C',str(clone),'cat-file','blob',fixed+':contracts/'+f],stdout=subprocess.PIPE,check=True).stdout
    actual=(S/'contracts'/f).read_bytes();assert blob==actual,f
    blobs.append({'file':f,'sha256':hashlib.sha256(blob).hexdigest(),'blob_equals_snapshot':True})
(E/'dependency_audit_A.json').write_text(json.dumps({'negative_controls':controls,'bindings':rows,'raw_blob_verification':blobs,'limitation':'Header/version comparisons do not resolve normative-label supersession. C09:7 explicitly retains V1.9 authority, so V1.10 header differences are metadata candidates, not proof of illegal dependency bindings.'},ensure_ascii=False,indent=2),encoding='utf-8')
print('BINDINGS',len(rows),'HEADER_DIFF',[(r['source'],r['target'],r['source_line_number']) for r in rows if r['status']!='match'])
print('SOURCE_TEXT_MISMATCH',[(r['source'],r['target'],r['source_line_number']) for r in rows if not r['source_path_text_matches'] or not r['source_version_text_matches']])
print('RAW_GIT_BLOBS_EQUAL_SNAPSHOT',len(blobs),'NEGATIVE_CONTROLS_PASS')
