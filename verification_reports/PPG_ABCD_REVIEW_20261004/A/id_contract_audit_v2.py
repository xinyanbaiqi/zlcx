from pathlib import Path
import re,json,collections,csv
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
cm=json.loads((E/'anchor_scan.json').read_text(encoding='utf-8'))['contract_map'];norm={Path(n).name:c for c,n in cm.items()}
rx=re.compile(r'(?<![A-Za-z0-9_-])(?:[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d+[A-Za-z]?(?:-[A-Z0-9]+)*|[KNPRLD]\d{2})(?![A-Za-z0-9_-])')
def ids(text):
    matches=[m for m in rx.finditer(text) if m[0] not in {'SHA-256'}];result=set(m[0] for m in matches)
    for left,right in zip(matches,matches[1:]):
        separator=text[left.end():right.start()]
        if not re.fullmatch(r'[\s`*]*(?:~|～|\.\.|至|through|to)[\s`*]*',separator):continue
        a=re.fullmatch(r'(.*?)(\d+)',left[0]);z=re.fullmatch(r'(.*?)(\d+)',right[0])
        if not a or not z or a[1]!=z[1]:continue
        lo,hi=int(a[2]),int(z[2])
        if 0<=hi-lo<=100:result.update(a[1]+str(n).zfill(len(a[2])) for n in range(lo,hi+1))
    for left in matches:
        a=re.fullmatch(r'(.*?)(\d+)',left[0])
        tail=text[left.end():]
        short=re.match(r'[\s`*]*(?:~|～|\.\.|至)[\s`*]*(\d+)(?![A-Za-z0-9_-])',tail)
        if a and short:
            lo,hi=int(a[2]),int(short[1])
            if 0<=hi-lo<=100:result.update(a[1]+str(n).zfill(len(a[2])) for n in range(lo,hi+1))
    return result
assert ids('MGR-01..MGR-24')=={f'MGR-{n:02}' for n in range(1,25)}
assert ids('P01～P03')=={'P01','P02','P03'}
assert ids('FIR-31, FIR-33')=={'FIR-31','FIR-33'}
assert ids('MGR-01复位、MGR-11命令冲突')=={'MGR-01','MGR-11'}
assert ids('不是MGR-01suffix或SHA-256')==set()
assert ids('JNT-01~09 (9项)')=={f'JNT-{n:02}' for n in range(1,10)}
assert ids('FIR-31至36')=={f'FIR-{n}' for n in range(31,37)}
assert ids('G-FP-01-D01-00~G-FP-01-D01-04')=={f'G-FP-01-D01-{n:02}' for n in range(5)}
def missing(identity,defined,rtl,tb,index):return [k for k,v in [('contract_definition',defined),('rtl_tag',rtl),('tb_text',tb),('matrix_or_alias',index)] if identity not in v]
controls=[missing('TST-01',{'TST-01'},{'TST-01'},{'TST-01'},{'TST-01'})]
for removed in range(4):
    pools=[{'TST-02'} for _ in range(4)];pools[removed]=set();controls.append(missing('TST-02',*pools))
assert controls==[[],['contract_definition'],['rtl_tag'],['tb_text'],['matrix_or_alias']],controls
maps={k:collections.defaultdict(list) for k in ['definition','reference_definition','rtl_tag','tb_text','tb_tag','alias','matrix','waiver']}
def add(kind,identities,ref):
    for identity in identities:maps[kind][identity].append(ref)
for p in (S/'contracts').glob('*.md'):
    if p.name in ('PPG_CONTRACT_CLOSURE_MATRIX.md','PPG_ALIAS_MAPPING_TABLE.md'):continue
    for n,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
        if line.startswith('|'):
            found=ids(line.split('|')[1]);kind='definition' if p.name in norm or p.name=='PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md' else 'reference_definition'
            add(kind,found,{'file':p.relative_to(S).as_posix(),'line':n,'text':line})
for p in (S/'rtl').rglob('*'):
    if not p.is_file() or p.suffix not in ('.v','.vh'):continue
    for n,line in enumerate(p.read_text(encoding='utf-8-sig').splitlines(),1):
        ref={'file':p.relative_to(S).as_posix(),'line':n,'text':line}
        if p.name.startswith('tb_'):
            add('tb_text',ids(line),ref)
            if '@satisfies:' in line:add('tb_tag',ids(line.split('@satisfies:',1)[1]),ref)
        elif '@satisfies:' in line:add('rtl_tag',ids(line.split('@satisfies:',1)[1]),ref)
for filename,kind in [('PPG_ALIAS_MAPPING_TABLE.md','alias'),('PPG_CONTRACT_CLOSURE_MATRIX.md','matrix')]:
    for n,line in enumerate((S/'contracts'/filename).read_text(encoding='utf-8').splitlines(),1):
        if not line.startswith('|'):continue
        found=ids(line.split('|')[1]);ref={'file':'contracts/'+filename,'line':n,'text':line};add(kind,found,ref)
        if found and re.search(r'\bN/A\b|无需.*锚|非RTL锚|静态elaboration|不是RTL',line):add('waiver',found,ref)
index=set(maps['alias'])|set(maps['matrix'])
universe=set(maps['definition'])|set(maps['rtl_tag'])|index
rows=[]
for identity in sorted(universe):
    rows.append({'id':identity,'family':re.sub(r'-\d+.*$','',identity),'contract_definition':maps['definition'].get(identity,[]),'reference_definition':maps['reference_definition'].get(identity,[]),'rtl_tag':maps['rtl_tag'].get(identity,[]),'tb_text':maps['tb_text'].get(identity,[]),'tb_tag':maps['tb_tag'].get(identity,[]),'matrix_or_alias':maps['matrix'].get(identity,[])+maps['alias'].get(identity,[]),'explicit_no_rtl_anchor_reason':maps['waiver'].get(identity,[]),'missing_presence_candidate':missing(identity,maps['definition'],maps['rtl_tag'],maps['tb_text'],index),'semantic_state':'文本机械追溯；TB真实比较/当前条款定义/范围裁定需逐家族语义确认'})
counts={'all_candidates':len(rows),**{k:len(v) for k,v in maps.items()},'missing_edge_candidates':dict(collections.Counter(edge for r in rows for edge in r['missing_presence_candidate']))}
(E/'id_presence_v2.json').write_text(json.dumps({'negative_controls':controls,'range_negative_controls':['MGR01..24','P01..03','GFP D01 00..04','FIR31/33 no inferred32'],'counts':counts,'rows':rows},ensure_ascii=False,indent=2),encoding='utf-8')
with (E/'id_presence_v2.csv').open('w',encoding='utf-8-sig',newline='') as fp:
    writer=csv.DictWriter(fp,fieldnames=['id','family','contract_refs','rtl_refs','tb_refs','index_refs','explicit_reason','missing_candidates','state']);writer.writeheader()
    for r in rows:
        join=lambda key:';'.join(f"{x['file']}:{x['line']}" for x in r[key])
        writer.writerow({'id':r['id'],'family':r['family'],'contract_refs':join('contract_definition'),'rtl_refs':join('rtl_tag'),'tb_refs':join('tb_text'),'index_refs':join('matrix_or_alias'),'explicit_reason':join('explicit_no_rtl_anchor_reason'),'missing_candidates':','.join(r['missing_presence_candidate']),'state':r['semantic_state']})
print('ID_V2_NEGATIVE',controls,'COUNTS',counts)
print('FAMILIES',dict(collections.Counter(r['family'] for r in rows)))
