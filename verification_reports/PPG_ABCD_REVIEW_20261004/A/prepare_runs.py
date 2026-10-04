from pathlib import Path
import json, shlex
BASE=Path(__file__).resolve().parent
OUT=BASE/'evidence/compile'
NEG=OUT/'negative'
expected={'good':0,'syntax_bad':2,'include_bad':1,'port_bad':1}
for name in expected:
    code=int((NEG/(name+'.rc')).read_text().strip())
    assert (code==0)==(name=='good'),(name,code)
    print('negative',name,code)
assert int((NEG/'good.run.rc').read_text().strip())==0
assert 'REAL_COMPARISON_PASS' in (NEG/'good.run.log').read_text()
manifest=json.loads((BASE/'evidence/compile_manifest.json').read_text())
for m in manifest:
    assert int((OUT/m['name']/'compile.rc').read_text().strip())==0
def linux(p): return '/mnt/c/'+p.resolve().as_posix()[3:]
def q(p): return shlex.quote(linux(p))
VVP=BASE/'toolchain/icarus11/usr/bin/vvp'
LIB=BASE/'toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl'
scripts=[]
for m in manifest:
    d=OUT/m['name']
    s=d/'run.sh'
    script=['#!/bin/bash','set -u','cd '+q(d), 'date -u +%Y-%m-%dT%H:%M:%SZ > run.start', 'timeout 3600 '+q(VVP)+' -M '+q(LIB)+' sim.vvp > run.log 2>&1','echo "$?" > run.rc','date -u +%Y-%m-%dT%H:%M:%SZ > run.end', 'echo '+m['name']+' run=$(cat run.rc)']
    s.write_bytes(('\n'.join(script)+'\n').encode())
    scripts.append(s)
parallel=['#!/bin/bash','set -u']
for i,s in enumerate(scripts):
    parallel+=['bash '+q(s)+' &']
    if i%4==3: parallel+=['wait']
parallel+=['wait']
(BASE/'run_all.sh').write_bytes(('\n'.join(parallel)+'\n').encode())
print('48 compile passed; run scripts generated')
