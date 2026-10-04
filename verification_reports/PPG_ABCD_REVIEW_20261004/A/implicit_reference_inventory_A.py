from pathlib import Path
import re,json,collections,sys,csv
B=Path(__file__).resolve().parent;E=B/'evidence';S=B/'snapshot';O=E/'global_closure_20261004'
ns={'__file__':str(B/'anchor_audit_v2.py')}
exec((B/'anchor_audit_v2.py').read_text(encoding='utf-8').split('fixture=E/')[0],ns)
rx=ns['rx'];scan=ns['scan'];rows=[]
def contexts(line):
 line=re.sub(r'~~.*?~~','',line);cells=line.split('|') if line.startswith('|') else [line]
 return [(ci,c,m) for ci,c in enumerate(cells) for m in rx.finditer(c)]
# Context extraction must preserve repeated identical refs and cell order.
fixture='| x | `a.v:2` (`:4`), `a.v:5` | `b.v:9` then `:4` |'
assert [m[0] for _,_,m in contexts(fixture)]==['a.v:2','`:4`','a.v:5','b.v:9','`:4`']
assert [i for i,_,m in contexts(fixture) if m[0]=='`:4`']==[2,3]
assert len(scan(fixture))==len(contexts(fixture))
portrows={int(r['line']) for r in csv.DictReader((O/'ledger_port_inventory.csv').read_text(encoding='utf-8-sig').splitlines())}
for path in ['contracts/PPG_CONTRACT_CLOSURE_MATRIX.md','contracts/PPG_ALIAS_MAPPING_TABLE.md']:
 for n,line in enumerate((S/path).read_text(encoding='utf-8').splitlines(),1):
  refs=scan(line);cs=contexts(line);assert len(refs)==len(cs),(path,n,len(refs),len(cs))
  for ri,(ref,(ci,cell,m)) in enumerate(zip(refs,cs)):
   assert ref['reference']==m[0],(path,n,ref,m[0])
   if ref['status']!='ambiguous_inherited_context':continue
   before=cell[:m.start()];after=cell[m.end():]
   mentions=re.findall(r'[A-Za-z0-9_./-]+\.(?:v|vh|md)',before)
   code_tokens=re.findall(r'`([A-Za-z_][A-Za-z0-9_]*)`',before[-180:]+after[:180])
   candidates=list(dict.fromkeys(mentions))
   rows.append(dict(key=f'{path}:{n}:{ri}',source=path,line=n,ordinal=ri,cell=ci,reference=m[0],
    matrix_port_row=(path.endswith('MATRIX.md') and n in portrows),
    preceding=before[-200:],following=after[:220],candidate_mentions=candidates,code_tokens=code_tokens,
    current_cell=cell,state='independent_ruling_pending'))
assert len(rows)==1656
(O/'implicit_reference_inventory_A.json').write_text(json.dumps(dict(records=rows,count=len(rows),
 negative_controls='Repeated same shorthand in distinct cells remains separate; exact raw scanner order and counts verified.',
 note='Contexts and mentions are candidates only; no automatic nearest-file acceptance.'),ensure_ascii=False,indent=2),encoding='utf-8')
print('IMPLICIT_COUNT',len(rows),'MATRIX_PORT_ROW',sum(r['matrix_port_row'] for r in rows),'OTHER',sum(not r['matrix_port_row'] for r in rows))
pick=[r for r in rows if r['source'].endswith('TABLE.md')]
for r in pick[:int(sys.argv[1]) if len(sys.argv)>1 else 30]:
 print(r['line'],r['ordinal'],r['reference'],'FILES',r['candidate_mentions'],'BEFORE',r['preceding'][-90:],'AFTER',r['following'][:100])
