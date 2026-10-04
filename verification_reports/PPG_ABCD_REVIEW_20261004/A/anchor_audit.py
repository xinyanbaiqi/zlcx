from pathlib import Path
import re,json,collections
BASE=Path(__file__).resolve().parent
S=BASE/'snapshot'; E=BASE/'evidence'
files=collections.defaultdict(list)
for p in S.rglob('*'):
    if p.is_file(): files[p.name].append(p)
def check(name, nums, expected=None):
    choices=files.get(Path(name).name,[])
    if not choices: return 'missing_file',None
    if len(choices)!=1: return 'ambiguous_file',None
    lines=choices[0].read_text(encoding='utf-8-sig',errors='replace').splitlines()
    if any(n<1 or n>len(lines) for n in nums): return 'out_of_bounds',None
    target='\n'.join(lines[n-1] for n in nums)
    if expected and expected not in target: return 'text_mismatch',target
    return 'in_bounds',target
# Known traps: one wrong text line, one missing file, one out-of-range line.
fixture=E/'anchor_negative'; fixture.mkdir(exist_ok=True)
p=fixture/'audit_anchor_fixture.v'; p.write_text('module fixture;\nwire expected_signal;\nendmodule\n',encoding='utf-8')
files[p.name]=[p]
negative=[check(p.name,[2],'expected_signal')[0],check(p.name,[1],'expected_signal')[0],check('audit_does_not_exist.v',[1])[0],check(p.name,[99])[0]]
assert negative==['in_bounds','text_mismatch','missing_file','out_of_bounds'],negative
(fixture/'results.json').write_text(json.dumps(negative),encoding='utf-8')
crefs={}
matrix=(S/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8').splitlines()
for line in matrix[:280]:
    m=re.match(r'\|\s*(C\d{2})\s*\|.*?`([^`]+\.md)`',line)
    if m: crefs[m[1]]=Path(m[2]).name
def expand(token):
    values=[]
    for bit in token.split(','):
        if '-' in bit:
            a,b=map(int,bit.split('-')); values.extend(range(a,b+1))
        else: values.append(int(bit))
    return values
rows=[]
explicit=re.compile(r'([A-Za-z0-9_./-]+\.(?:v|vh|md|f|py|sh)):(\d+(?:-\d+)?(?:,\d+(?:-\d+)?)*)')
for source in ['contracts/PPG_CONTRACT_CLOSURE_MATRIX.md','contracts/PPG_ALIAS_MAPPING_TABLE.md']:
    for ln,orig in enumerate((S/source).read_text(encoding='utf-8').splitlines(),1):
        line=re.sub(r'~~.*?~~','',orig)
        for m in explicit.finditer(line):
            name,token=m.groups(); nums=expand(token)
            expected=None
            # Only infer a semantic expectation when the cited declaration is followed
            # by quoted Verilog containing the exact formal port name.
            post=line[m.end():]
            decl=re.match(r'`?\s+`(?:input|output)\b[^`]*?\b([io]_[A-Za-z0-9_]+)',post)
            if decl and len(nums)==1: expected=decl[1]
            # Alias provenance: K01..K05 rows explicitly cite matrix entries.
            if source.endswith('ALIAS_MAPPING_TABLE.md') and Path(name).name=='PPG_CONTRACT_CLOSURE_MATRIX.md':
                km=re.match(r'\|\s*(K0[1-5])\b',line)
                if km and len(nums)==1: expected=km[1]
            status,target=check(name,nums,expected)
            rows.append(dict(source=source,line=ln,reference=m[0],kind='explicit_file_line',expected=expected,status=status,target=target))
        for m in re.finditer(r'\b(C\d{2}):(\d+(?:\.\d+)*)(?![\d.])',line):
            c,token=m.groups(); name=crefs.get(c)
            if '.' in token or int(token)<10 and int(token)!=3:
                status,target='section_or_ambiguous',None
            elif name:
                status,target=check(name,[int(token)])
                if token=='3': status='current_version_'+status
            else: status,target='contract_map_unresolved',None
            rows.append(dict(source=source,line=ln,reference=m[0],kind='contract_shorthand',expected=None,status=status,target=target))
out=dict(negative_controls=negative,contract_map=crefs,counts=dict(collections.Counter(r['status'] for r in rows)),references=rows)
(E/'anchor_scan.json').write_text(json.dumps(out,ensure_ascii=False,indent=2),encoding='utf-8')
print('NEGATIVE',negative,'CONTRACT_MAP',len(crefs),'REFS',len(rows),'COUNTS',out['counts'])
for r in rows:
    if r['status'] in ('missing_file','out_of_bounds','text_mismatch'):
        print(r['source'],r['line'],r['reference'],r['expected'],r['status'],repr((r['target'] or '')[:180]))
