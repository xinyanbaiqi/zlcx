from review import *
from collections import Counter
import re

git=r'D:\Git\cmd\git.exe'
def git_read(*args):
 # This read-only clone belongs to DAWN, while sandbox reads use a different
 # Windows account. The exception is command-local; no Git config is written.
 return subprocess.check_output([git,'--no-optional-locks','-c','safe.directory='+str(AUDIT/'zlcx'),'-C',str(AUDIT/'zlcx'),*args])
head=git_read('rev-parse','HEAD').decode().strip()
status=git_read('status','--porcelain','--untracked-files=all').decode('utf-8')
files=[]
for f in FILES:
 data=(SNAP/f['path']).read_bytes()
 blob=git_read('show',COMMIT+':'+f['path'])
 files.append(dict(path=f['path'],layer=f['layer'],lines=len(data.splitlines()),same_as_git=data==blob,sha256=hashlib.sha256(data).hexdigest()))
 # Deliberate corruption of a private byte buffer must be detected.
 assert data==blob
 assert data+b'\nNOT_SOURCE'!=blob
 assert data[:-1]!=blob
baseline={'commit':COMMIT,'head':head,'head_matches':head==COMMIT,'clone_status_porcelain':status,'files':files,'negative_controls':'appended bytes and removed final byte detected for each file; shared files untouched','scope':'29 B-owned files; no claim about changes to unrelated files/snapshot outside scope'}
(OUT/'evidence'/'final_baseline.json').write_text(json.dumps(baseline,ensure_ascii=False,indent=2),encoding='utf-8')
assert head==COMMIT
assert not status, status
print('Fixed HEAD matches; clone clean; 29/29 snapshot files match Git blobs')
print('Lines by layer:',dict((k,sum(f['lines'] for f in files if f['layer']==k)) for k in ['RTL','TB','合同']))

gates=[]
for p in sorted((OUT/'evidence'/'skill').glob('*/reused.json')):
 d=json.loads(p.read_text(encoding='utf-8-sig'))
 ast=json.loads((p.parent/'formatter_ast.json').read_text(encoding='utf-8-sig'))
 gates.append({'module':p.parent.name,'errors':d['errors'],'warnings':d['strict_warnings'],'rules':d['delivery_issues_by_rule'],'checks':d['checks'],'own_formatter_ast':ast})
 print(p.parent.name, 'errors',d['errors'],'warnings',d['strict_warnings'],'rules',d['delivery_issues_by_rule'])
assert len(gates)==7
(OUT/'evidence'/'final_gate_inventory.json').write_text(json.dumps(gates,ensure_ascii=False,indent=2),encoding='utf-8')

# Preserve all existing trials. Invalid setup trials are included and never
# silently promoted to design failures or omitted in favor of a PASS trial.
runs=[]
for p in sorted((OUT/'evidence').glob('*/result.json')):
 d=json.loads(p.read_text(encoding='utf-8-sig'))
 run=p.parent/'run.log'; compile_log=p.parent/'compile.log'
 log=run.read_text(encoding='utf-8-sig',errors='replace') if run.exists() else ''
 # WSL's host warning is UTF-16 mixed into vvp's UTF-8 pipe and may leave a
 # leading NUL before the first simulator line. Retain raw logs unchanged.
 normalized=log.replace('\x00','')
 passes=[s for s in normalized.splitlines() if re.match(r'^\s*PASS(?:\s|:|$)',s)]
 fails=[s for s in normalized.splitlines() if re.match(r'^\s*FAIL(?:\s|:|$)',s)]
 fatal=[s for s in normalized.splitlines() if s.startswith('FATAL:')]
 runs.append({'case':p.parent.name,'compile_rc':d.get('compile_rc'),'run_rc':d.get('run_rc'),'runner_fail_count':d.get('fail_count'),'observed_PASS_lines':len(passes),'observed_FAIL_lines':len(fails),'fail_lines':fails,'fatal_lines':fatal,'run_log_exists':run.exists(),'compile_log_exists':compile_log.exists(),'limits':'Normalized leading NUL from host warning only; raw logs retained. Entire observed comparison-line counts, possibly including setup/shared prefix; final *_PASS markers excluded. Not a per-requirement or full-regression verdict.'})
(OUT/'evidence'/'final_trial_inventory.json').write_text(json.dumps(runs,ensure_ascii=False,indent=2),encoding='utf-8')
print('Existing trials indexed:',len(runs),'; no simulations started')
for r in runs:
 if r['case'] in ['supervisor_original','supervisor_original_rearm_mutant','supervisor_extended','supervisor_extended_rearm_mutant','scheduler_cadence','recheck_deadline_v4','branch_qualification','top_abort_done_v3','top_abort_done_v3_counterfactual','inj_mutex_eligible_v2','inj_mutex_eligible_v2_mutant','p06_target_enable','p06_target_enable_mutant']:
  print(r['case'],'compile',r['compile_rc'],'run',r['run_rc'],'observed PASS/FAIL',r['observed_PASS_lines'],r['observed_FAIL_lines'])
