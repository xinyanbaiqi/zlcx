from pathlib import Path
import json,hashlib
from native_probe import run
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
manifest=json.loads((E/'compile_manifest.json').read_text(encoding='utf-8'))
m=next(x for x in manifest if x['name']=='tb_ppg_control_top')
p=S/m['tb'];raw=p.read_bytes();text=raw.decode('utf-8-sig');old='if(ppg_control_top_Inst.measurement_run_enable) begin'
assert text.count(old)==1
d=E/'smoke_negative_A';d.mkdir(exist_ok=True);mut=d/p.name;mut.write_bytes(text.replace(old,'if(!ppg_control_top_Inst.measurement_run_enable) begin').encode('utf-8'))
src=[mut if S/x==p else S/x for x in m['files']]
src.extend((S/'rtl/ppg_control_top').glob('tb_*.vh'))
result=run('smoke_negative_A',src,'tb_ppg_control_top',timeout=600)
log=(d/'native.run.log').read_bytes().decode('utf-8',errors='replace').replace('\x00','')
assert result['compile_rc']==0 and result['run_rc']==0
assert 'FAIL SMOKE-19 TOP-18 STATIC_BIAS did not hold measurement_run_enable' in log
assert 'SMOKE_TB_FAIL' in log and 'SMOKE_TB_PASS' not in log
(d/'negative_assertions.json').write_text(json.dumps({'source_sha256':hashlib.sha256(raw).hexdigest(),'mutation':'invert STATIC_BIAS measurement permit expectation only','expected_fail_observed':True,'key_output':[l for l in log.splitlines() if 'FAIL' in l or 'TB_' in l]},ensure_ascii=False,indent=2),encoding='utf-8')
print('SMOKE_ASSERTION_NEGATIVE_VERIFIED')
