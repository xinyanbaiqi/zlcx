import re, subprocess, sys
TBS = sys.argv[1:]
def table(root):
    t = open(root + '/tools/run_unit_tb_regression.sh', encoding='utf-8').read()
    rows = {}
    for l in t.split('\n'):
        l = l.strip()
        if l.startswith('"tb_') and '|' in l:
            r = l.strip('"').split('|'); rows[r[0]] = r
    return rows
for tb in TBS:
    out = {}
    for tag, root in (('old', 'D:/PPG/verilog/ppg_github_release'), ('new', 'D:/PPG/verilog/ppg_regression_runs/abcd_20261004/phase2/rtl1')):
        r = table(root)[tb]
        files = [root + '/rtl/' + r[2]] + [root + '/rtl/' + d for d in r[4].split()]
        import os
        inc = os.path.dirname(root + '/rtl/' + r[2])
        p = subprocess.run(['D:/iverilog/bin/iverilog', '-o', 'NUL', '-Wall', '-g2005', '-I', inc] + files, capture_output=True, text=True, errors='replace')
        lines = sorted(set(re.sub(r':\d+:', ':N:', re.sub(r'^.*/rtl/', '', l)) for l in (p.stdout + p.stderr).splitlines() if l.strip()))
        out[tag] = (p.returncode, lines)
    new_only = [l for l in out['new'][1] if l not in out['old'][1]]
    gone = [l for l in out['old'][1] if l not in out['new'][1]]
    print(f"{tb}: rc old/new={out['old'][0]}/{out['new'][0]} warn old/new={len(out['old'][1])}/{len(out['new'][1])} new_only={len(new_only)} gone={len(gone)}")
    for l in new_only[:8]: print('   +', l[:200])
    for l in gone[:4]: print('   -', l[:200])
