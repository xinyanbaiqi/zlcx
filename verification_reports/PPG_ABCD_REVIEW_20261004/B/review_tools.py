from review import *
os.environ['PYTHONDONTWRITEBYTECODE']='1'
os.environ['PYTHONIOENCODING']='utf-8'
SKILL=SNAP/'.claude/skills/erie-verilog-generator'
sys.path.insert(0,str(SKILL))
from scripts.python.facade.existing_rtl_api import analyze_existing_verilog
from scripts.python.quality.formatter_ast import build_ast_report_for_path
if sys.argv[1]=='skill':
 for f in FILES:
  if f['layer']!='RTL':continue
  p=SNAP/f['path'];dest=OUT/'evidence'/'skill'/p.stem
  result=analyze_existing_verilog(p,out_dir=dest)
  ast=build_ast_report_for_path(p)
  (dest/'formatter_ast.json').write_text(json.dumps(ast,ensure_ascii=False,indent=2),encoding='utf-8')
  print(p.stem,result['status'],'ast_ok',ast.get('ok'),flush=True)
  for suffix in ['json','md','gate.log','lint.log']:
   q=AUDIT/'evidence'/'gates'/(p.stem+'.'+suffix)
   if q.exists():(dest/('reused.'+suffix)).write_bytes(q.read_bytes())
elif sys.argv[1]=='code':
 p=SNAP/sys.argv[2];lines=p.read_text(encoding='utf-8-sig').splitlines()
 start=int(sys.argv[3]) if len(sys.argv)>3 else 1
 end=int(sys.argv[4]) if len(sys.argv)>4 else len(lines)
 print(p)
 for i in range(start-1,min(end,len(lines))):
  s=lines[i].split('//',1)[0].rstrip()
  if s.strip():print(f'{i+1}: {s}')
elif sys.argv[1]=='old':
 for f in FILES:
  if f['layer']=='合同':continue
  p=SNAP/f['path'];stem=p.stem
  gate=AUDIT/'evidence'/'gates'/(stem+'.json')
  if gate.exists():
   d=json.loads(gate.read_text(encoding='utf-8'))
   print(stem,'gate',d.get('errors'),d.get('strict_warnings'),d.get('delivery_issues_by_rule'),{k:v.get('status') for k,v in d.get('checks',{}).items()})
  logs=list((AUDIT/'evidence'/'compile'/stem).glob('*log'))
  for q in logs:
   ls=q.read_text(encoding='utf-8',errors='replace').splitlines()
   print(str(q),'lines',len(ls))
   print('\n'.join(ls[:5]+ls[-5:]))
