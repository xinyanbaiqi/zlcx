from pathlib import Path
import csv,json,subprocess,os,sys
B=Path(__file__).resolve().parent; S=B/'snapshot'; E=B/'evidence'
C=Path('C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd39-7e50-7671-8810-299165a4df40')
rows=[]
for ent in csv.DictReader((C/'OWNERSHIP_4CHAT.csv').open(encoding='utf-8-sig')):
    if ent['owner']!='A' or ent['layer']!='RTL': continue
    p=E/'skill_inputs_A'/ent['path']; p.parent.mkdir(parents=True,exist_ok=True)
    p.write_bytes((S/ent['path']).read_bytes())
    out=E/'skill_analysis_A'/p.stem; out.mkdir(parents=True,exist_ok=True)
    args=[sys.executable,'-B','-m','scripts.python.workflow.cli','analyze-existing','--source',str(p),'--out-dir',str(out),'--no-state']
    r=subprocess.run(args,cwd=B,capture_output=True,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',PYTHONPATH=str(S/'.claude/skills/erie-verilog-generator'),PYTHONUTF8='1'))
    (out/'cli.log').write_bytes(r.stdout+r.stderr)
    row=dict(path=ent['path'],rc=r.returncode,log=str(out/'cli.log'),original_gate=str(E/'gates'/(p.stem+'.json')))
    rows.append(row); print(p.stem,'analyze_rc',r.returncode,flush=True)
    (E/'skill_analysis_A.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
