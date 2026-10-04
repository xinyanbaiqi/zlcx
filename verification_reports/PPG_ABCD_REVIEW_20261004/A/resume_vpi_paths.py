from pathlib import Path
import subprocess,tarfile,io,json,hashlib,datetime,time,concurrent.futures,re
B=Path(__file__).resolve().parent;E=B/'evidence';TOOL='/tmp/ppg_audit_iverilog_20261004'
P=['wsl.exe','-d','Debian','--cd','/tmp','--exec']
OLD='/mnt/c/'+str(B/'toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl').replace('\\','/')[3:]
LIB=TOOL+'/lib/x86_64-linux-gnu/ivl'
ROOT='/tmp/ppg_native_regressions_vpi_20261004'
def now():return datetime.datetime.now(datetime.timezone.utc).isoformat()
def transfer(raw,root):
    stream=io.BytesIO()
    with tarfile.open(fileobj=stream,mode='w') as tar:
        info=tarfile.TarInfo('sim.vvp');info.size=len(raw);info.mode=0o644;tar.addfile(info,io.BytesIO(raw))
    subprocess.run(P+['mkdir','-p',root],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True)
    subprocess.run(P+['tar','-xf','-','-C',root],input=stream.getvalue(),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True)
def relocate(raw):
    # Only the six vpi_module path literals may change. Reverse transformation
    # must reproduce the original elaborated image byte-for-byte.
    old=OLD.encode();lib=LIB.encode();lines=raw.splitlines(keepends=True)
    changed=[];out=[]
    for i,line in enumerate(lines):
        if line.startswith(b':vpi_module "'+old+b'/'):
            new=line.replace(old,lib,1);changed.append(i+1);out.append(new)
        else:out.append(line)
    assert len(changed)==6,changed
    new=b''.join(out)
    restored=b''.join(line.replace(lib,old,1) if line.startswith(b':vpi_module "'+lib+b'/') else line for line in new.splitlines(keepends=True))
    assert restored==raw
    return new,changed
def run_raw(raw,root):
    transfer(raw,root)
    cmd=P+['timeout','60',TOOL+'/bin/vvp','-M',LIB,'-i',root+'/sim.vvp']
    r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    return r,cmd
def controls():
    d=E/'vpi_relocation_controls';d.mkdir(exist_ok=True)
    raw=(E/'compile/tb_ppg_adc_async_stage_capture/sim.vvp').read_bytes()
    good,changed=relocate(raw)
    checks=[]
    for name,data,expect in [('relocated_good',good,True),('missing_system_vpi',good.replace((LIB+'/system.vpi').encode(),(LIB+'/known_missing.vpi').encode(),1),False)]:
        r,cmd=run_raw(data,ROOT+'/'+name);(d/(name+'.log')).write_bytes(r.stdout)
        log=r.stdout.decode('utf-8',errors='replace').replace('\x00','')
        passed=r.returncode==0 and 'PASS ppg_adc_async_stage_capture explicit-frame checks' in log
        assert passed==expect,(name,r.returncode,log[-1000:])
        checks.append({'case':name,'run_rc':r.returncode,'pass_banner':passed,'command':cmd})
    # Native VPI binaries must be the exact extracted original tool files.
    expected={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (B/'toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl').glob('*.vpi')}
    actual=subprocess.run(P+['sha256sum']+[LIB+'/'+n for n in expected],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,check=True).stdout.decode('utf-8',errors='replace').replace('\x00','')
    for n,h in expected.items():assert re.search(r'^'+h+r'\s+.*?/'+re.escape(n)+r'$',actual,re.M),(n,h)
    (d/'controls.json').write_text(json.dumps({'cases':checks,'changed_lines':changed,'native_vpi_hashes':expected,'inverse_identical':True},ensure_ascii=False,indent=2),encoding='utf-8')
    print('VPI_RELOCATION_CONTROLS_PASS',len(checks),len(expected),flush=True)
def active():
    ps=subprocess.run(P+['ps','-eo','args'],stdout=subprocess.PIPE,stderr=subprocess.STDOUT).stdout.decode('utf-8',errors='replace')
    return sum(1 for l in ps.splitlines() if '/toolchain/icarus11/usr/bin/vvp ' in l and '/evidence/compile/' in l and not l.lstrip().startswith('timeout'))
def recover(name):
    d=E/'compile'/name;a=E/'resume_attempts'/name/'vpi_path_failure_20261004';a.mkdir(parents=True,exist_ok=True)
    for fn in ['run.log','run.rc','run.start','run.end']:
        if (d/fn).exists() and not (a/fn).exists():(a/fn).write_bytes((d/fn).read_bytes())
    raw=(d/'sim.vvp').read_bytes();new,changed=relocate(raw);transfer(new,ROOT+'/'+name)
    (a/'sim.relocated.vvp').write_bytes(new)
    cmd=P+['timeout','21600',TOOL+'/bin/vvp','-M',LIB,'-i',ROOT+'/'+name+'/sim.vvp']
    (d/'run.start').write_text(now(),encoding='utf-8');(d/'run.rc').write_text('RUNNING_NATIVE_RECOVERY',encoding='utf-8')
    if (d/'run.end').exists():(d/'run.end').unlink()
    print('VPI_RECOVERY_START',name,flush=True)
    with (d/'run.log').open('wb') as fp:r=subprocess.run(cmd,stdout=fp,stderr=subprocess.STDOUT)
    (d/'run.rc').write_text(str(r.returncode),encoding='utf-8');(d/'run.end').write_text(now(),encoding='utf-8')
    (a/'recovery.json').write_text(json.dumps({'tb':name,'command':cmd,'run_rc':r.returncode,'original_sha256':hashlib.sha256(raw).hexdigest(),'relocated_sha256':hashlib.sha256(new).hexdigest(),'changed_lines':changed,'inverse_identical':True,'note':'Only six simulator VPI library path literals relocated; no RTL/TB bytes or simulation instructions changed.'},ensure_ascii=False,indent=2),encoding='utf-8')
    print('VPI_RECOVERY_END',name,r.returncode,flush=True)
if __name__=='__main__':
    controls()
    names=[]
    for d in (E/'compile').iterdir():
        if not d.name.startswith('tb_') or not (d/'run.log').exists():continue
        log=(d/'run.log').read_bytes().decode('utf-8',errors='replace').replace('\x00','')
        if 'Unable to find module file' in log and 'Program not runnable' in log:names.append(d.name)
    print('VPI_RECOVERY_ELIGIBLE',names,flush=True)
    for n in names:
        d=E/'compile'/n;a=E/'resume_attempts'/n/'vpi_path_failure_20261004';a.mkdir(parents=True,exist_ok=True)
        for fn in ['run.log','run.rc','run.start','run.end']:
            if (d/fn).exists() and not (a/fn).exists():(a/fn).write_bytes((d/fn).read_bytes())
        (d/'run.rc').write_text('PENDING_VPI_RECOVERY',encoding='utf-8')
    done=set();running={};deadline=time.monotonic()+24*3600
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        while time.monotonic()<deadline:
            for n,f in list(running.items()):
                if f.done():f.result();done.add(n);del running[n]
            slots=max(0,4-active()-len(running))
            for n in [n for n in names if n not in done and n not in running][:slots]:running[n]=pool.submit(recover,n)
            (E/'vpi_recovery_state.json').write_text(json.dumps({'updated_utc':now(),'done':sorted(done),'running_native':sorted(running),'queued':[n for n in names if n not in done and n not in running],'old_active':active()},indent=2),encoding='utf-8')
            if len(done)==len(names):break
            time.sleep(10)
