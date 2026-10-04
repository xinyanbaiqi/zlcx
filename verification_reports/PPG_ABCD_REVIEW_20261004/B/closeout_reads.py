from review import *
import re
if sys.argv[1]=='registry':
 for name in ['PPG_CONTRACT_CLOSURE_MATRIX.md','PPG_ALIAS_MAPPING_TABLE.md']:
  print('\n'+name)
  for n,line in enumerate((SNAP/'contracts'/name).read_text(encoding='utf-8-sig').splitlines(),1):
   if re.search(r'12\.4|\bC(?:08|09|10|16|18|23|24)\b|\b(?:FSC|SSW|SUP|AMR|IDT|PWI)-',line):
    if n>1300 and re.search(r'\bC\d\d\b',line) and not re.search(r'\b(?:FSC|SSW|SUP|AMR|IDT|PWI)-',line):continue
    print(f'{n}: {line}')
elif sys.argv[1]=='amr_labels':
 p=SNAP/'rtl/ppg_amb_recheck_scheduler/tb_ppg_amb_recheck_scheduler.v'
 for n,line in enumerate(p.read_text(encoding='utf-8-sig').splitlines(),1):
  if 'AMR-' in line:print(f'{n}: {line.strip()}')
elif sys.argv[1]=='status':
 rows=list(csv.DictReader((OUT/'coverage.csv').open(encoding='utf-8-sig')))
 for layer in ['RTL','TB','合同']:
  paths=[f['path'] for f in FILES if f['layer']==layer]
  completed=[p for p in paths if all(r['status']=='完成' for r in rows if r['path']==p)]
  print(layer,len(paths),'complete',len(completed),'remaining',len(paths)-len(completed))
elif sys.argv[1]=='matrix_versions':
 p=SNAP/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md'
 lines=p.read_text(encoding='utf-8-sig').splitlines()
 for n,line in enumerate(lines,1):
  if 1189<=n<=1450 and (re.search(r'^###? |\| C(?:08|09|10|16|18|23|24) \|',line) or '| C09:' in line or 'V1.9' in line and 'C09' in line):print(f'{n}: {line}')
elif sys.argv[1]=='missing':
 rows=json.loads((OUT/'evidence'/'id_four_link_audit.json').read_text(encoding='utf-8'))['rows']
 for key in ['rtl_tags','tb_code_mentions','matrix_or_alias_mentions']:
  print(key+': '+', '.join(r['id'] for r in rows if not r[key]))
elif sys.argv[1]=='known':
 for name in ['PPG_4CHAT_COMMON.md','PPG_4CHAT_ORIGINAL_TASK.md']:
  print('\n'+name)
  lines=(COMMON/name).read_text(encoding='utf-8-sig').splitlines()
  if name.endswith('COMMON.md'):
   for n,line in enumerate(lines,1):print(f'{n}: {line}')
  else:
   start=next(i for i,x in enumerate(lines) if x.startswith('## 4.'))
   end=next(i for i,x in enumerate(lines[start+1:],start+1) if x.startswith('## 5.'))
   for n in range(start,end):print(f'{n+1}: {lines[n]}')
