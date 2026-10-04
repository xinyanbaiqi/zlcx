from pathlib import Path
import json,re,collections,csv
B=Path(__file__).resolve().parent; S=B/'snapshot'; E=B/'evidence'
idrx=re.compile(r'(?<![\w-])(?:[A-Z][A-Z0-9]*(?:-[A-Z0-9]+)*-\d+[A-Za-z]?(?:-[A-Z0-9]+)*|[KNPRLD]\d{2})(?![\w-])')
def evaluate(identity,defined,rtl,tb,alias):
    return [name for name,pool in [('contract_table',defined),('rtl_tag',rtl),('tb_tag_or_text',tb),('alias_row',alias)] if identity not in pool]
# Three independent missing links plus an all-present control.
fixture=[evaluate('TST-01',{'TST-01'},{'TST-01'},{'TST-01'},{'TST-01'}),evaluate('TST-02',set(),{'TST-02'},{'TST-02'},{'TST-02'}),evaluate('TST-03',{'TST-03'},set(),{'TST-03'},{'TST-03'}),evaluate('TST-04',{'TST-04'},{'TST-04'},set(),{'TST-04'})]
assert fixture==[[],['contract_table'],['rtl_tag'],['tb_tag_or_text']],fixture
defined=collections.defaultdict(list); rtl=collections.defaultdict(list); tb=collections.defaultdict(list); alias=collections.defaultdict(list)
for p in (S/'contracts').glob('*.md'):
    if p.name in ('PPG_CONTRACT_CLOSURE_MATRIX.md','PPG_ALIAS_MAPPING_TABLE.md'):continue
    for ln,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1):
        if line.startswith('|'):
            first=line.split('|')[1]
            for identity in idrx.findall(first): defined[identity].append(f'{p.relative_to(S).as_posix()}:{ln}')
for p in (S/'rtl').rglob('*'):
    if not p.is_file() or p.suffix not in ('.v','.vh'): continue
    is_tb=p.name.startswith('tb_')
    for ln,line in enumerate(p.read_text(encoding='utf-8-sig').splitlines(),1):
        if is_tb:
            for identity in idrx.findall(line): tb[identity].append(f'{p.relative_to(S).as_posix()}:{ln}')
        elif '@satisfies:' in line:
            for identity in idrx.findall(line.split('@satisfies:',1)[1]): rtl[identity].append(f'{p.relative_to(S).as_posix()}:{ln}')
for ln,line in enumerate((S/'contracts/PPG_ALIAS_MAPPING_TABLE.md').read_text(encoding='utf-8').splitlines(),1):
    if line.startswith('|'):
        for identity in idrx.findall(line.split('|')[1]): alias[identity].append(f'contracts/PPG_ALIAS_MAPPING_TABLE.md:{ln}')
allids=sorted(set(defined)|set(rtl)|set(alias))
rows=[]
for identity in allids:
    rows.append(dict(id=identity,contract_table=defined.get(identity,[]),rtl_tag=rtl.get(identity,[]),tb_tag_or_text=tb.get(identity,[]),alias_row=alias.get(identity,[]),missing_candidate=evaluate(identity,defined,rtl,tb,alias)))
(E/'id_presence.json').write_text(json.dumps({'negative_controls':fixture,'counts':{'union':len(allids),'contract_table':len(defined),'rtl_tag':len(rtl),'alias_row':len(alias)},'rows':rows},ensure_ascii=False,indent=2),encoding='utf-8')
with (E/'id_presence.csv').open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
print('ID_COUNTS',len(allids),len(defined),len(rtl),len(alias),'CANDIDATE_MISSING',dict(collections.Counter(m for r in rows for m in r['missing_candidate'])))
for r in rows:
    if r['missing_candidate'] and r['rtl_tag']: print(r['id'],r['missing_candidate'])
# Version/dependency text extraction only: historical and normative statuses must
# be resolved manually; no claim that a regex proves dependency consistency.
contracts={}
for c,name in json.loads((E/'anchor_scan.json').read_text(encoding='utf-8'))['contract_map'].items():
    lines=(S/'contracts'/name).read_text(encoding='utf-8').splitlines()
    header=[(n,l) for n,l in enumerate(lines[:50],1) if 'normative version' in l.lower() or '当前规范' in l]
    deps=[]
    for n,line in enumerate(lines,1):
        if re.match(r'\|\s*C\d{2}\s*\|',line): deps.append(dict(line=n,text=line))
    contracts[c]=dict(file=name,version_header=header,dependency_rows=deps)
(E/'contract_version_inventory.json').write_text(json.dumps(contracts,ensure_ascii=False,indent=2),encoding='utf-8')
print('VERSION_INVENTORY',len(contracts),'with_English_or_CN_header',sum(bool(x['version_header']) for x in contracts.values()))
