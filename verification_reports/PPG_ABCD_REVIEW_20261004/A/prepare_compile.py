from pathlib import Path
import re, json, shlex
BASE = Path(__file__).resolve().parent
SNAP = BASE/'snapshot'
OUT = BASE/'evidence/compile'
OUT.mkdir(parents=True, exist_ok=True)
def linux(p): return '/mnt/c/'+p.resolve().as_posix()[3:]
def q(p): return shlex.quote(linux(p))
TOOL = BASE/'toolchain/icarus11/usr/bin/iverilog'
LIB = BASE/'toolchain/icarus11/usr/lib/x86_64-linux-gnu/ivl'
VVP = BASE/'toolchain/icarus11/usr/bin/vvp'
command = q(TOOL)+' -B '+q(LIB)
manifest = []
for filelist in sorted(SNAP.glob('rtl/ppg_control_top/xsim_*_filelist.f')) + sorted(SNAP.glob('rtl/ppg_chip_digital_top/xsim_*_filelist.f')):
    files=[(filelist.parent/x.strip()).resolve() for x in filelist.read_text().splitlines() if x.strip() and not x.startswith('#')]
    tbs=[p for p in files if p.name.startswith('tb_')]
    assert len(tbs)==1,(filelist,tbs)
    tb=tbs[0]
    assert all(p.is_file() for p in files),filelist
    manifest.append(dict(name=tb.stem, layer='system' if 'ppg_control_top' in str(filelist) else 'chip',tb=tb,files=files,source=filelist.relative_to(SNAP).as_posix()))
for line in (SNAP/'tools/run_unit_tb_regression.sh').read_text().splitlines():
    m=re.match(r'\s*"(tb_[^"\n]+)"\s*$',line)
    if not m: continue
    name,group,tbpath,banner,deps=m[1].split('|')
    tb=SNAP/'rtl'/tbpath
    files=[SNAP/'rtl'/x for x in deps.split()]+[tb]
    assert all(p.is_file() for p in files),name
    manifest.append(dict(name=name,layer=group,tb=tb,files=files,source='tools/run_unit_tb_regression.sh'))
assert len(manifest)==48,len(manifest)
assert {m['tb'].resolve() for m in manifest} == {p.resolve() for p in SNAP.glob('rtl/**/tb_*.v')}
negative=OUT/'negative'
negative.mkdir(exist_ok=True)
fixtures={
 'good':'module good; initial begin $display("REAL_COMPARISON_PASS"); $finish; end endmodule\n',
 'syntax_bad':'module syntax_bad; initial begin this is malformed; end endmodule\n',
 'include_bad':'`include "AUDIT_INTENTIONALLY_MISSING.vh"\nmodule include_bad; endmodule\n',
 'port_bad':'module leaf(input a); endmodule\nmodule port_bad; leaf x(.NO_SUCH_PORT(1\'b0)); endmodule\n',
}
script=['#!/bin/bash','set -u','mkdir -p '+q(OUT), 'cd '+q(negative)]
for name,body in fixtures.items():
    f=negative/(name+'.v');f.write_text(body,encoding='utf-8')
    script += [command+' -g2012 -Wall -s '+name+' -o '+q(negative/(name+'.vvp'))+' '+q(f)+' > '+q(negative/(name+'.log'))+' 2>&1','echo "$?" > '+q(negative/(name+'.rc'))]
script += [q(VVP)+' -M '+q(LIB)+' '+q(negative/'good.vvp')+' > '+q(negative/'good.run.log')+' 2>&1', 'echo "$?" > '+q(negative/'good.run.rc')]
for m in manifest:
    d=OUT/m['name'];d.mkdir(exist_ok=True)
    args=command+' -g2012 -Wall -s '+m['name']+' -I '+q(m['tb'].parent)+' -o '+q(d/'sim.vvp')+' '+' '.join(q(p) for p in m['files'])
    (d/'command.txt').write_text(args+'\n',encoding='utf-8')
    script += ['cd '+q(d),args+' > '+q(d/'compile.log')+' 2>&1','echo "$?" > '+q(d/'compile.rc'),'echo '+m['name']+' compile=$(cat '+q(d/'compile.rc')+')']
rtl=sorted(p for p in SNAP.glob('rtl/**/*.v') if not p.name.startswith('tb_'))
for p in rtl:
    d=OUT/p.stem;d.mkdir(exist_ok=True)
    args=command+' -g2005 -Wall -s '+p.stem+' -o '+q(d/'sim.vvp')+' '+' '.join(q(x) for x in rtl)
    script += ['cd '+q(d),args+' > '+q(d/'compile.log')+' 2>&1','echo "$?" > '+q(d/'compile.rc'),'echo '+p.stem+' compile=$(cat '+q(d/'compile.rc')+')']
(BASE/'compile_all.sh').write_bytes(('\n'.join(script)+'\n').encode('utf-8'))
(BASE/'evidence/compile_manifest.json').write_text(json.dumps([{**m,'tb':m['tb'].relative_to(SNAP).as_posix(),'files':[p.relative_to(SNAP).as_posix() for p in m['files']]} for m in manifest],indent=2),encoding='utf-8')
print('MANIFEST',len(manifest),'RTL',len(rtl))
