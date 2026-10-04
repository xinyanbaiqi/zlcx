import pathlib,json,subprocess,sys
root=pathlib.Path(__file__).resolve().parent
linux=(root/'linux_runner.py').read_text(encoding='utf-8')
plan=(root/'plan.json').read_bytes()
cp=subprocess.run(['wsl','--distribution','Debian','--cd','/','--','/usr/bin/python3','-c',linux],input=plan,capture_output=True,timeout=180)
(root/'wsl_stdout.log').write_bytes(cp.stdout)
(root/'wsl_stderr.log').write_bytes(cp.stderr)
if cp.returncode:
    print('WSL_RUNNER_FAILED',cp.returncode); sys.exit(cp.returncode)
results=json.loads(cp.stdout.decode('utf-8'))
(root/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
for result in results:
    dest=root/result['name'];dest.mkdir(exist_ok=True)
    (dest/'compile.log').write_text(result.get('compile_log',''),encoding='utf-8')
    (dest/'run.log').write_text(result.get('run_log',''),encoding='utf-8')
    print(json.dumps({key:value for key,value in result.items() if key not in ['compile_log','compile_command','rtl_path','tb_path']},ensure_ascii=False))
