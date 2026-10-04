from pathlib import Path
import subprocess,tarfile,io,json,hashlib,datetime,time,concurrent.futures,threading
B=Path(__file__).resolve().parent;E=B/'evidence';TOOL='/tmp/ppg_audit_iverilog_20261004'
P=['wsl.exe','-d','Debian','--cd','/tmp','--exec']
names=[x['tb'] for x in json.loads((E/'regression_resume_attempts.json').read_text(encoding='utf-8'))]
running={};done=set();guard=threading.Lock()
root='/tmp/ppg_native_regressions_d18c6954_20261004'
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def recover(name):
    d=E/'compile'/name;a=E/'resume_attempts'/name/'drvfs_failure_20261004';a.mkdir(parents=True,exist_ok=True)
    for fn in ['run.log','run.rc','run.start','run.end']:
        if (d/fn).exists():(a/fn).write_bytes((d/fn).read_bytes())
    raw=(d/'sim.vvp').read_bytes();subroot=root+'/'+name
    stream=io.BytesIO()
    with tarfile.open(fileobj=stream,mode='w') as tar:
        info=tarfile.TarInfo('sim.vvp');info.size=len(raw);info.mode=0o644;tar.addfile(info,io.BytesIO(raw))
    subprocess.run(P+['mkdir','-p',subroot],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True)
    subprocess.run(P+['tar','-xf','-','-C',subroot],input=stream.getvalue(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True)
    cmd=P+['timeout','21600',TOOL+'/bin/vvp','-M',TOOL+'/lib/x86_64-linux-gnu/ivl','-i',subroot+'/sim.vvp']
    (d/'run.start').write_text(now(),encoding='utf-8');(d/'run.rc').write_text('RUNNING_NATIVE_RECOVERY',encoding='utf-8')
    print('NATIVE_RECOVERY_START',name,flush=True)
    with (d/'run.log').open('wb') as fp:r=subprocess.run(cmd,stdout=fp,stderr=subprocess.STDOUT)
    (d/'run.rc').write_text(str(r.returncode),encoding='utf-8');(d/'run.end').write_text(now(),encoding='utf-8')
    record={'tb':name,'command':cmd,'vvp_sha256':hashlib.sha256(raw).hexdigest(),'run_rc':r.returncode,'prior_attempt':str(a),'note':'Reuse unchanged original elaborated image; only source of runtime file loading changed.'}
    (a/'native_recovery.json').write_text(json.dumps(record,ensure_ascii=False,indent=2),encoding='utf-8')
    print('NATIVE_RECOVERY_END',name,r.returncode,flush=True)
def old_active_count():
    ps=subprocess.run(P+['ps','-eo','args'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT).stdout.decode('utf-8',errors='replace')
    return sum(1 for l in ps.splitlines() if '/toolchain/icarus11/usr/bin/vvp ' in l and '/evidence/compile/' in l and not l.lstrip().startswith('timeout'))
deadline=time.monotonic()+24*3600
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    print('WATCH_DR VFS_FAILURES'.replace('DR V','DRV'),len(names),'original active',old_active_count(),flush=True)
    while time.monotonic()<deadline:
        for n,f in list(running.items()):
            if f.done():
                try:f.result()
                except Exception as exc:print('RECOVERY_ENVIRONMENT_ERROR',n,str(exc),flush=True)
                done.add(n);del running[n]
        left=[];eligible=[]
        for n in names:
            if n in done or n in running:continue
            d=E/'compile'/n;rc=(d/'run.rc').read_text(encoding='utf-8').strip() if (d/'run.rc').exists() else ''
            if rc=='0':done.add(n);continue
            if rc in ('126','127') and (d/'run.end').exists():
                log=(d/'run.log').read_bytes().decode('utf-8',errors='replace').replace('\x00','')
                if 'Input/output error' in log or 'Permission denied' in log or 'No such file' in log:eligible.append(n)
                else:done.add(n)
            elif rc and rc.lstrip('-').isdigit():done.add(n)
            else:left.append(n)
        slots=max(0,4-old_active_count()-len(running))
        for n in eligible[:slots]:running[n]=pool.submit(recover,n)
        state={'updated_utc':now(),'handled':sorted(done),'running_native':sorted(running),'waiting_original':left,'environment_failed_pending':eligible,'old_active':old_active_count()}
        (E/'native_recovery_state.json').write_text(json.dumps(state,ensure_ascii=False,indent=2),encoding='utf-8')
        if len(done)==len(names) and not running:break
        time.sleep(10)
    print('NATIVE_RECOVERY_WATCH_END',len(done),len(names),flush=True)
