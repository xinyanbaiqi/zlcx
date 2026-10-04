from pathlib import Path
import subprocess, json, shutil, hashlib, concurrent.futures, datetime

B=Path(__file__).resolve().parent; E=B/'evidence'; L='/mnt/c'+B.as_posix()[2:]
T=L+'/toolchain/icarus11/usr'; LIB=T+'/lib/x86_64-linux-gnu/ivl'
now=datetime.datetime.now(datetime.timezone.utc).isoformat()
jobs=[]; archival=[]
for ent in json.loads((E/'compile_manifest.json').read_text(encoding='utf-8')):
    d=E/'compile'/ent['name']; rc=d/'run.rc'
    if rc.exists() and rc.read_text().strip()=='0': continue
    a=E/'resume_attempts'/ent['name']/'before_20261004'; a.mkdir(parents=True,exist_ok=True)
    for name in ['run.log','run.rc','run.start','run.end']:
        p=d/name
        if p.exists() and not (a/name).exists(): shutil.copyfile(p,a/name)
    archival.append(dict(tb=ent['name'],previous_status='external_cap' if rc.exists() else 'interrupted_or_pending',archive=str(a),restart_utc=now))
    jobs.append((ent['name'],d))
(E/'regression_resume_attempts.json').write_text(json.dumps(archival,indent=2),encoding='utf-8')
print('RESTART_ONLY_UNFINISHED',len(jobs),[n for n,d in jobs],flush=True)
def run(job):
    name,d=job
    (d/'run.start').write_text(datetime.datetime.now(datetime.timezone.utc).isoformat(),encoding='utf-8')
    # Attempt status is explicit before launching; completed-at file is removed only
    # after archival above. Original files and compiled DUT are never changed.
    (d/'run.rc').write_text('RUNNING_RESUMED',encoding='utf-8')
    with (d/'run.log').open('wb') as fp:
        r=subprocess.run(['wsl.exe','-d','Debian','--','timeout','21600',T+'/bin/vvp','-M',LIB,'-i',L+'/evidence/compile/'+name+'/sim.vvp'],cwd=d,stdout=fp,stderr=subprocess.STDOUT)
    (d/'run.rc').write_text(str(r.returncode),encoding='utf-8')
    (d/'run.end').write_text(datetime.datetime.now(datetime.timezone.utc).isoformat(),encoding='utf-8')
    print(name,'run',r.returncode,flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    list(pool.map(run,jobs))
