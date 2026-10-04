import sys,json,pathlib,subprocess,time
cases=json.load(sys.stdin)
root=pathlib.Path('/tmp/ppg_review_C_targeted_20261004')
root.mkdir(exist_ok=True)
tool=pathlib.Path('/tmp/ppg_audit_iverilog_20261004')
results=[]
for case in cases:
    dest=root/case['name']; dest.mkdir(exist_ok=True)
    for item in case['files']:
        (dest/item['name']).write_text(item['content'],encoding='utf-8')
    command=[str(tool/'bin/iverilog'),'-B',str(tool/'lib/x86_64-linux-gnu/ivl'),'-g2012','-Wall','-o',str(dest/'sim.vvp'),str(dest/'dut.v'),str(dest/'tb.v')]
    started=time.time()
    result={'name':case['name'],'rtl_path':case['rtl_path'],'tb_path':case['tb_path'],'compile_command':command}
    try:
        cp=subprocess.run(command,capture_output=True,text=True,timeout=15)
        result.update(compile_rc=cp.returncode,compile_log=cp.stdout+cp.stderr)
        if cp.returncode==0:
            rp=subprocess.run([str(tool/'bin/vvp'),'-M',str(tool/'lib/x86_64-linux-gnu/ivl'),str(dest/'sim.vvp')],capture_output=True,text=True,timeout=20)
            result.update(run_rc=rp.returncode,run_log=rp.stdout+rp.stderr)
    except subprocess.TimeoutExpired as exc:
        result.update(timeout=True,timeout_log=str(exc))
    result['elapsed_seconds']=time.time()-started; results.append(result)
print(json.dumps(results,ensure_ascii=False))
