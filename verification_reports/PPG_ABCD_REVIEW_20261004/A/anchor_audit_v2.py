from pathlib import Path
import json,re,collections,csv
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
old=json.loads((E/'anchor_scan.json').read_text(encoding='utf-8'));cm=old['contract_map']
files=collections.defaultdict(list)
for p in S.rglob('*'):
    if p.is_file():files[p.name].append(p)
rx=re.compile(r'(?P<file>[A-Za-z0-9_./-]+\.(?:v|vh|md|f|py|sh)):(?P<fn>\d+(?:\.\d+)*(?:-\d+)?(?:,\d+(?:-\d+)?)*)|\b(?P<c>C\d{2}):(?P<cn>\d+(?:\.\d+)*(?:-\d+)?(?:,\d+(?:-\d+)?)*)|(?P<bare>`:(?P<bn>\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)`)')
linecache={}
def expand(token):
    arr=[]
    for bit in token.split(','):
        if '-' in bit:
            a,z=map(int,bit.split('-'));arr.extend(range(a,z+1))
        else:arr.append(int(bit))
    return arr
def target_status(name,token,expected):
    if '.' in token:return 'section_or_ambiguous',None
    ps=files.get(Path(name).name,[]) if name else []
    if not name:return 'unresolved_inheritance',None
    if not ps:return 'missing_file',None
    if len(ps)>1:return 'ambiguous_file',None
    if ps[0] not in linecache:linecache[ps[0]]=ps[0].read_text(encoding='utf-8-sig',errors='replace').splitlines()
    lines=linecache[ps[0]];ns=expand(token)
    if not ns or min(ns)<1 or max(ns)>len(lines):return 'out_of_bounds',None
    text='\n'.join(lines[n-1] for n in ns)
    if expected:
        return ('semantic_match' if re.search(r'(?<![A-Za-z0-9_])'+re.escape(expected)+r'(?![A-Za-z0-9_])',text) else 'text_mismatch'),text
    return 'bounds_only',text
def scan(line):
    line=re.sub(r'~~.*?~~','',line);cells=line.split('|') if line.startswith('|') else [line]
    rowports=[]
    if len(cells)>=7 and re.fullmatch(r'\s*C\d{2}\s*',cells[1]):
        rowports=re.findall(r'`([io]_[A-Za-z0-9_]+)`',cells[4])
    result=[]
    for cellidx,cell in enumerate(cells):
        context=None;matches=list(rx.finditer(cell))
        # Source cells deliberately keep an original absolute reference followed
        # by a dated current shorthand. Only the final current token is active.
        override=re.search(r'当前\s*`?:(\d+(?:-\d+)?)',cell) if cellidx==2 and rowports else None
        for m in matches:
            if m['file']:name=m['file'];token=m['fn'];kind='explicit';context=name
            elif m['c']:name=cm.get(m['c']);token=m['cn'];kind='Cxx';context=name
            else:
                name=context;token=m['bn'];kind='inherited'
                # Outside the formal Source cell, omission does not necessarily
                # mean the nearest filename: a child declaration can intervene,
                # and “当前” often returns to the owning contract. Do not silently
                # map those endpoint references to a child and report fake OOB.
                if cellidx!=2 or not rowports:
                    before=cell[max(0,m.start()-24):m.start()]
                    cx=re.search(r'(C\d{2})[^`]{0,12}当前\s*$',before)
                    if cx:name=cm.get(cx[1])
                    else:
                        result.append({'reference':m[0],'resolved_file':None,'line_token':token,'kind':kind,'expected':None,'status':'ambiguous_inherited_context','target':None});continue
            expectation=None
            if rowports and len(rowports)==1 and cellidx==2 and not ('分组文字行' in cell or '端口名不在' in cell):expectation=rowports[0]
            post=cell[m.end():]
            decl=re.match(r'`?\s+`(?:input|output)\b[^`]*?\b([io]_[A-Za-z0-9_]+)',post)
            if decl:expectation=decl[1]
            if kind=='Cxx' and token=='3':expectation=None
            if kind=='Cxx' and ('.' in token or token.isdigit() and int(token)<10 and token!='3'):status,text='section_or_ambiguous',None
            elif override and m.start()<override.start():status,text='historical_superseded_source',None
            else:status,text=target_status(name,token,expectation)
            result.append({'reference':m[0],'resolved_file':name,'line_token':token,'kind':kind,'expected':expectation,'status':status,'target':text})
    return result
fixture=E/'anchor_negative_v2';fixture.mkdir(exist_ok=True)
p=fixture/'audit_anchor_v2_fixture.v';p.write_text('module fixture;\ninput i_good;\nendmodule\n',encoding='utf-8');files[p.name]=[p]
def row(name,oldline,current,port):return f'| C00 | `{name}:{oldline}`<br>~~`:{oldline}`~~ **当前`:{current}`** | input | `{port}` | none | none |'
controls=[scan(row(p.name,99,2,'i_good')),scan(row(p.name,2,1,'i_good')),scan(row(p.name,2,2,'i_wrong')),scan(row(p.name,2,99,'i_good'))]
active=lambda rows:[r['status'] for r in rows if r['status']!='historical_superseded_source']
assert list(map(active,controls))==[['semantic_match'],['text_mismatch'],['text_mismatch'],['out_of_bounds']],controls
intervening=scan(f'| item | owning.v:1 then `{p.name}:2` child declaration; owning endpoint `:846` |')
assert intervening[-1]['status']=='ambiguous_inherited_context' and intervening[-1]['resolved_file'] is None,intervening
controls.append(intervening)
(fixture/'results.json').write_text(json.dumps(controls,ensure_ascii=False,indent=2),encoding='utf-8')
rows=[]
for rel in ['contracts/PPG_CONTRACT_CLOSURE_MATRIX.md','contracts/PPG_ALIAS_MAPPING_TABLE.md']:
    for n,line in enumerate((S/rel).read_text(encoding='utf-8').splitlines(),1):
        for record in scan(line):rows.append({'source':rel,'source_line':n,**record})
counts=collections.Counter(r['status'] for r in rows);kinds=collections.Counter(r['kind'] for r in rows)
(E/'anchor_scan_v2.json').write_text(json.dumps({'negative_controls':list(map(active,controls)),'counts':dict(counts),'kinds':dict(kinds),'references':rows},ensure_ascii=False,indent=2),encoding='utf-8')
bad=[r for r in rows if r['status'] in ('out_of_bounds','text_mismatch','missing_file')]
with (E/'anchor_failures_v2.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=rows[0]);writer.writeheader();writer.writerows(bad)
print('ANCHOR_V2_NEGATIVE',list(map(active,controls)),'TOTAL',len(rows),'COUNTS',dict(counts),'KINDS',dict(kinds))
for row in bad[:15]:print('CANDIDATE',row['source_line'],row['reference'],row['expected'],row['status'],repr((row['target'] or '')[:90]))
