from pathlib import Path
import subprocess, sys, json, os
BASE = Path(__file__).resolve().parent
SNAP = BASE / 'snapshot'
SKILL = SNAP / '.claude/skills/erie-verilog-generator'
OUT = BASE / 'evidence/gates'
OUT.mkdir(parents=True, exist_ok=True)
env = dict(os.environ, PYTHONDONTWRITEBYTECODE='1', PYTHONIOENCODING='utf-8')
for p in sorted(SNAP.glob('rtl/**/*.v')):
    if p.name.startswith('tb_'): continue
    name = p.stem
    cmds = {
        'gate': [sys.executable, '-B', '-m', 'scripts.python.validation.verilog_generated_deliverable_gate', str(p), '--json', str(OUT / (name+'.json')), '--markdown', str(OUT / (name+'.md'))],
        'lint': [sys.executable, '-B', '-m', 'scripts.python.quality.verilog_lint', str(p), '--external', 'none'],
    }
    for kind, cmd in cmds.items():
        r = subprocess.run(cmd, cwd=SKILL, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
        (OUT / (name+'.'+kind+'.log')).write_bytes(r.stdout)
        print(name, kind, 'rc='+str(r.returncode), flush=True)
