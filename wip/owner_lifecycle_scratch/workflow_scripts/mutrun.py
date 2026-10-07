# mutrun.py <tb> <rtl_rel> <old> <new> <tag> : copy RTL with one textual mutation, run unit TB in xsim, summarize
import sys, os, re, subprocess, shutil
tb, rel, old, new, tag = sys.argv[1:6]
root = 'D:/PPG/verilog/ppg_regression_runs/abcd_20261004'
src = root + '/src_668a5ea'
tbroot = os.environ.get('TBROOT', src)
rtlroot = os.environ.get('RTLROOT', src)
table = open(tbroot + '/tools/run_unit_tb_regression.sh', encoding='utf-8').read()
row = [l for l in table.split('\n') if l.strip().startswith('"' + tb + '|')][0].strip().strip('"').split('|')
tbfile, banner, deps = row[2], row[3], row[4].split()
w = root + '/probes/mut/' + tag
shutil.rmtree(w, ignore_errors=True); os.makedirs(w)
files = []
for d in deps:
    p = rtlroot + '/rtl/' + d
    if d == rel and old != 'NONE':
        t = open(p, encoding='utf-8').read()
        assert t.count(old) == 1, ('mutation anchor count', t.count(old))
        mp = w + '/' + os.path.basename(d)
        open(mp, 'w', encoding='utf-8', newline='\n').write(t.replace(old, new))
        files.append(mp)
    else:
        files.append(p)
top = re.search(r'module\s+(\w+)', open(tbroot + '/rtl/' + tbfile, encoding='utf-8').read()).group(1)
cmd = ['bash', root + '/probes/run_xsim.sh', w + '/xs', top, 'NONE', tbroot + '/rtl/' + os.path.dirname(tbfile), tbroot + '/rtl/' + tbfile] + files
r = subprocess.run(cmd, capture_output=True, text=True)
log = open(w + '/xs/xsim.log', encoding='utf-8', errors='replace').read()
npass = len(re.findall(r'^(\[PASS\]|PASS)', log, re.M))
fails = [l for l in log.split('\n') if re.search(r'FAIL|ERROR:|FATAL', l)]
ban = bool(re.search(banner, log, re.M))
print(f'{tag}: {r.stdout.strip()} pass_lines={npass} banner={ban} fail_lines={len(fails)}')
for l in fails[:4]: print('   ', l.strip()[:160])
