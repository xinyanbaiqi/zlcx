from pathlib import Path
import json,subprocess,datetime,time,concurrent.futures,hashlib
from resume_vpi_paths import relocate,transfer,P,TOOL,LIB
B=Path(__file__).resolve().parent;E=B/'evidence';ROOT='/tmp/ppg_native_cap_retry_20261004'
names=[d.name for d in (E/'compile').iterdir() if d.name.startswith('tb_')]
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def eligible(rc,ended):return rc=='124' and ended
controls=[('completed',eligible('0',True),False),('running',eligible('RUNNING_NATIVE_RECOVERY',False),False),
 ('incomplete_terminal_write',eligible('124',False),False),('external_cap',eligible('124',True),True),
 ('design_error',eligible('1',True),False)]
assert all(a==e for _,a,e in controls),controls
(E/'external_cap_retry_controls.json').write_text(json.dumps(controls,indent=2),encoding='utf-8')

def active_count():
 output=subprocess.run(P+['ps','-eo','args'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True).stdout.decode('utf-8',errors='replace')
 return sum(1 for l in output.splitlines() if '/bin/vvp ' in l and not l.lstrip().startswith('timeout') and ('ppg_' in l or '/evidence/compile/' in l))

def retry(name):
 d=E/'compile'/name
 assert eligible((d/'run.rc').read_text().strip(),(d/'run.end').exists())
 stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
 a=E/'resume_attempts'/name/('external_cap_'+stamp);a.mkdir(parents=True,exist_ok=False)
 for fn in ('run.log','run.rc','run.start','run.end'):(a/fn).write_bytes((d/fn).read_bytes())
 raw=(d/'sim.vvp').read_bytes();new,changed=relocate(raw);root=ROOT+'/'+name
 transfer(new,root)
 # Full original testbench restarts only after the old process ended; its own
 # watchdog and DUT image are unchanged. Increase external wall-clock allowance.
 cmd=P+['timeout','86400',TOOL+'/bin/vvp','-M',LIB,'-i',root+'/sim.vvp']
 (d/'run.start').write_text(now(),encoding='utf-8');(d/'run.end').unlink()
 (d/'run.rc').write_text('RUNNING_NATIVE_CAP_RETRY',encoding='utf-8')
 record={'tb':name,'command':cmd,'original_sha256':hashlib.sha256(raw).hexdigest(),
  'relocated_sha256':hashlib.sha256(new).hexdigest(),'changed_vpi_path_lines':changed,
  'inverse_identical':True,'prior_attempt':str(a),'started_utc':now(),
  'note':'Actual rc124 external cap only; complete original TB, no RTL/TB changes. Original log preserved.'}
 (a/'retry.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
 print('CAP_RETRY_START',name,str(a),flush=True)
 with (d/'run.log').open('wb') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT)
 (d/'run.rc').write_text(str(r.returncode),encoding='utf-8');(d/'run.end').write_text(now(),encoding='utf-8')
 record.update(run_rc=r.returncode,ended_utc=now())
 (a/'retry.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
 print('CAP_RETRY_END',name,r.returncode,flush=True)

if __name__=='__main__':
 handled=set(); running={};deadline=time.monotonic()+48*3600
 print('EXTERNAL_CAP_WATCH_START',len(names),'controls passed',flush=True)
 with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
  while time.monotonic()<deadline:
   for name,future in list(running.items()):
    if future.done():future.result();handled.add(name);del running[name]
   pending=[];busy=[]
   for name in names:
    d=E/'compile'/name;rc=(d/'run.rc').read_text().strip() if (d/'run.rc').exists() else ''
    if eligible(rc,(d/'run.end').exists()) and name not in handled and name not in running:pending.append(name)
    elif not rc.lstrip('-').isdigit():busy.append(name)
   count=active_count()
   q=E/'vpi_recovery_state.json'
   queued=json.loads(q.read_text(encoding='utf-8')).get('queued',[]) if q.exists() else []
   # Give the existing queue priority, maintain the same global four-process cap.
   if pending and not running and count<4 and not queued:
    name=sorted(pending)[0];running[name]=pool.submit(retry,name)
   (E/'external_cap_retry_state.json').write_text(json.dumps({'updated_utc':now(),
    'running_retry':sorted(running),'pending_external_cap':pending,'handled':sorted(handled),
    'active_simulations':count,'waiting_original':busy,'original_queue':queued},indent=2),encoding='utf-8')
   if not busy and not pending and not running:break
   time.sleep(20)
 print('EXTERNAL_CAP_WATCH_END',len(handled),flush=True)
