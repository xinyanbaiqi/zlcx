from review import *
import re
paths=[f['path'] for f in FILES if f['path'].startswith('rtl/ppg_control_top/')]
seed='rtl/ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v'
def tasks(path):
 lines=(SNAP/path).read_text(encoding='utf-8-sig').splitlines()
 result=[];start=None
 for i,line in enumerate(lines):
  code=line.split('//',1)[0].strip()
  m=re.match(r'(task|function)\s+(?:\[[^]]+\]\s+)?(\w+)',code)
  if m:start=(i+1,m.group(2))
  if re.match(r'end(task|function)\b',code) and start:
   s,n=start;canonical='\n'.join(x.split('//',1)[0].strip() for x in lines[s-1:i+1] if x.split('//',1)[0].strip())
   result.append(dict(name=n,start=s,end=i+1,code_sha256=hashlib.sha256(canonical.encode()).hexdigest()))
   start=None
 return result
known={x['code_sha256']:x for x in tasks(seed)}
report=[]
for p in paths:
 entry=dict(path=p,tasks=tasks(p))
 for task in entry['tasks']:
  task['same_as_lifecycle']=known.get(task['code_sha256'])
 report.append(entry)
(OUT/'evidence/system_task_inventory.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
for x in report:
 print(x['path'])
 for t in x['tasks']:print(t['name'],f"{t['start']}-{t['end']}",'SAME' if t['same_as_lifecycle'] else 'NEW')
