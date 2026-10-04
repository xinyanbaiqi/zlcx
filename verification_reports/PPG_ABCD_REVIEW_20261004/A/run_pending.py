from pathlib import Path
import json, subprocess, shlex
B=Path(__file__).resolve().parent; E=B/'evidence'; L='/mnt/c'+B.as_posix()[2:]
names=['tb_ppg_control_top_normal_slow_tracking','tb_ppg_control_top_owner_identity_backpressure',
       'tb_ppg_control_top_peak_valley_return','tb_ppg_control_top_periodic_recheck_recovery',
       'tb_ppg_control_top_robustness_corner_waveforms','tb_ppg_control_top_startup_idac_calibration']
# Existing finished runners must not be rerun when the original queue reaches them.
# Running runners are untouched. This changes only audit-owned scripts outside source.
for d in (E/'compile').iterdir():
    p=d/'run.sh'
    if p.exists() and ((d/'run.rc').exists() or not (d/'run.start').exists()):
        t=p.read_text(encoding='utf-8')
        guard='if [ -f run.rc ]; then exit 0; fi\n'
        if guard not in t:
            lines=t.splitlines(keepends=True)
            pos=next(i for i,v in enumerate(lines) if v.startswith('cd '))
            lines.insert(pos+1,guard); p.write_bytes(''.join(lines).encode('utf-8'))
pending=[n for n in names if not (E/'compile'/n/'run.start').exists()]
lines=['#!/bin/bash\nset -u\n']
for i,n in enumerate(pending):
    lines.append(shlex.join(['bash',L+'/evidence/compile/'+n+'/run.sh'])+' &\n')
    if i%4==3: lines.append('wait\n')
lines.append('wait\n')
p=B/'run_pending.sh'; p.write_bytes(''.join(lines).encode('utf-8'))
(E/'pending_launch.json').write_text(json.dumps(pending,indent=2),encoding='utf-8')
print('PENDING_START',pending,flush=True)
subprocess.run(['wsl.exe','-d','Debian','--','bash',L+'/run_pending.sh'])
