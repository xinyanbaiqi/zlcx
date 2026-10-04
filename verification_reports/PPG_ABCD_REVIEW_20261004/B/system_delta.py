from review import *
import difflib,re
inventory=json.loads((OUT/'evidence/system_task_inventory.json').read_text())
seed=next(x for x in inventory if 'lifecycle_fault' in x['path'])
target=next(x for x in inventory if sys.argv[1] in x['path'])
def code(path,s,e):
 lines=(SNAP/path).read_text(encoding='utf-8-sig').splitlines()
 result=[]
 for i in range(s-1,e):
  c=lines[i].split('//',1)[0].strip()
  if c:
   if c.startswith('module tb_'):c='module TB();'
   result.append((i+1,c))
 return result
def diff(name,a,b):
 print('\nREGION',name,'source',target['path'],'reference',seed['path'])
 ac=[x[1] for x in a];bc=[x[1] for x in b]
 print('nonblank code lines',len(a),len(b),'target SHA256',hashlib.sha256('\n'.join(bc).encode()).hexdigest())
 changes=list(difflib.SequenceMatcher(None,ac,bc,autojunk=False).get_grouped_opcodes(3))
 if not changes:print('EXACT same executable code (module name normalized only for prefix)')
 for group in changes:
  print('...')
  for tag,i,j,k,l in group:
   if tag in ['delete','replace']:
    for ln,c in a[i:j]:print(f'REF-{ln}: {c}')
   for ln,c in b[k:l]:print(f'{"+" if tag in ["insert","replace"] else " "}{ln}: {c}')
diff('declarations/parameters/DUT/clocks',code(seed['path'],1,seed['tasks'][0]['start']-1),code(target['path'],1,target['tasks'][0]['start']-1))
for t in target['tasks']:
 if t['same_as_lifecycle']:
  print('REUSE',t['name'],t['start'],t['end'],'verified SHA256',t['code_sha256'],'from',t['same_as_lifecycle']['start'],t['same_as_lifecycle']['end']);continue
 old=next((x for x in seed['tasks'] if x['name']==t['name']),None)
 if old:diff(t['name'],code(seed['path'],old['start'],old['end']),code(target['path'],t['start'],t['end']))
 else:
  print('\nNEW TASK',t['name'],t['start'],t['end'])
  for ln,c in code(target['path'],t['start'],t['end']):print(f'{ln}: {c}')
