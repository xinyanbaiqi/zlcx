import pathlib,json,subprocess,sys,io,tarfile,uuid,time,hashlib
root=pathlib.Path(__file__).resolve().parent
cases=json.loads((root/'plan.json').read_text(encoding='utf-8'))
prefix=['wsl.exe','--distribution','Debian','--cd','/tmp','--exec']
tool='/tmp/ppg_audit_iverilog_20261004'
results=[]
for case in cases:
    started=time.time();dest=root/case['name'];dest.mkdir(exist_ok=True)
    scratch='/tmp/ppg_review_C_targeted_20261004/'+case['name']+'_'+uuid.uuid4().hex[:8]
    result={'name':case['name'],'rtl_path':case['rtl_path'],'tb_path':case['tb_path'],'linux_root':scratch}
    try:
        stream=io.BytesIO();paths=[];hashes=[]
        with tarfile.open(fileobj=stream,mode='w') as arc:
            for item in case['files']:
                data=item['content'].encode('utf-8');info=tarfile.TarInfo(item['name']);info.size=len(data);info.mode=0o644;arc.addfile(info,io.BytesIO(data));paths.append(scratch+'/'+item['name']);hashes.append(hashlib.sha256(data).hexdigest())
        result['input_sha256']=hashes
        subprocess.run(prefix+['mkdir','-p',scratch],capture_output=True,check=True,timeout=10)
        subprocess.run(prefix+['tar','-xf','-','-C',scratch],input=stream.getvalue(),capture_output=True,check=True,timeout=10)
        command=prefix+[tool+'/bin/iverilog','-B',tool+'/lib/x86_64-linux-gnu/ivl','-g2012','-Wall','-o',scratch+'/sim.vvp']+paths
        cp=subprocess.run(command,capture_output=True,timeout=20)
        (dest/'compile.log').write_bytes(cp.stdout+cp.stderr)
        result.update(compile_rc=cp.returncode,compile_command=command)
        if cp.returncode==0:
            rp=subprocess.run(prefix+['timeout','20',tool+'/bin/vvp','-M',tool+'/lib/x86_64-linux-gnu/ivl','-i',scratch+'/sim.vvp'],capture_output=True,timeout=25)
            (dest/'run.log').write_bytes(rp.stdout+rp.stderr)
            result.update(run_rc=rp.returncode)
            print(case['name'],'compile',cp.returncode,'run',rp.returncode)
            print(rp.stdout.decode('utf-8',errors='replace')[-2500:])
        else:
            print(case['name'],'COMPILE FAILED',cp.returncode,cp.stdout.decode('utf-8',errors='replace'),cp.stderr.decode('utf-8',errors='replace'))
    except Exception as exc:
        result.update(error=repr(exc));print(case['name'],repr(exc))
    result['elapsed_seconds']=time.time()-started;results.append(result)
    (root/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
