from pathlib import Path
import json,collections,csv
B=Path(__file__).resolve().parent;E=B/'evidence';S=B/'snapshot';O=E/'global_closure_20261004'
d=json.loads((E/'anchor_scan_v2.json').read_text(encoding='utf-8'))
ls={p:(S/p).read_text(encoding='utf-8').splitlines() for p in {r['source'] for r in d['references']}}
for status in ['ambiguous_inherited_context','bounds_only']:
 a=[r for r in d['references'] if r['status']==status]
 print('STATUS',status,'COUNT',len(a),'CONTEXT',dict(collections.Counter('GFP' if ls[r['source']][r['source_line']-1].startswith('| C') else 'other' for r in a)))
 rows=sorted({(r['source'],r['source_line']) for r in a if not ls[r['source']][r['source_line']-1].startswith('| C')})
 for p,n in rows[:8]:print('OTHER',p,n,ls[p][n-1][:300])
 print('GFP_SAMPLES')
 seen=set()
 for r in a:
  p,n=r['source'],r['source_line'];line=ls[p][n-1]
  if not line.startswith('| C'):continue
  cells=line.split('|');code=cells[1].strip()
  if code in seen or len(code)!=3:continue
  seen.add(code);print('ROW',n,code,'PORT',cells[4].strip(),'LAST',cells[-2].strip()[:700])
 print('GFP_CODES',sorted(seen))
print('DISPOSITION', (O/'static_residual_disposition_A.json').read_text(encoding='utf-8'))
