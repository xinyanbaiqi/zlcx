from pathlib import Path
import json,shlex,subprocess
BASE=Path(__file__).resolve().parent
M=json.loads((BASE/'evidence/compile_manifest.json').read_text(encoding='utf-8'))
def linux(p):return '/mnt/c/'+p.resolve().as_posix()[3:]
selected=[m for m in M if m['layer'] in ('hier','orphan','chip') or m['name']=='tb_ppg_real_raw_generator_selfcheck']
script=['#!/bin/bash','set -u']
for i,m in enumerate(selected):
    d=BASE/'evidence/compile'/m['name']
    p=d/'run.sh'
    if not (d/'run.start').exists():
        s=p.read_text(encoding='utf-8')
        s=s.replace('date -u +%Y-%m-%dT%H:%M:%SZ > run.start','if [ -f run.rc ]; then exit 0; fi\ndate -u +%Y-%m-%dT%H:%M:%SZ > run.start')
        p.write_bytes(s.encode())
    script+=['bash '+shlex.quote(linux(p))+' &']
    if i%2==1:script+=['wait']
script+=['wait']
(BASE/'run_fast.sh').write_bytes(('\n'.join(script)+'\n').encode())
r=subprocess.run(['wsl.exe','-d','Debian','--','bash',linux(BASE/'run_fast.sh')])
raise SystemExit(r.returncode)
