from pathlib import Path
import subprocess, json, datetime, re

B=Path(__file__).resolve().parent
L='/mnt/c/'+B.as_posix()[3:]
V=L+'/toolchain/icarus11/usr/bin/vvp'
M=L+'/toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl'
E=B/'evidence/progress_probe'; E.mkdir(exist_ok=True)
results=[]
for tb in ['tb_ppg_control_top_baseline_cross','tb_ppg_control_top_fir_tail_isolation','tb_diag_algo_probe']:
    for sec in [5,10]:
        cmd=['wsl.exe','-d','Debian','--','bash','-c',
             f"cd '{L}/evidence/compile/{tb}' && timeout -k 1 -s INT {sec} '{V}' -M '{M}' -v -i sim.vvp"]
        r=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=sec+30)
        p=E/f'{tb}_{sec}s.log'; p.write_bytes(r.stdout)
        t=r.stdout.decode('utf-8',errors='replace')
        row=dict(tb=tb,seconds=sec,rc=r.returncode,log=str(p),tail=t[-1800:])
        results.append(row)
        print(json.dumps(row,ensure_ascii=False),flush=True)
        (E/'results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
