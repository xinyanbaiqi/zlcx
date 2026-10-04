from pathlib import Path
import json,re
from native_probe import run
B=Path(__file__).resolve().parent; S=B/'snapshot'; E=B/'evidence'; d=E/'inj_identity_A';d.mkdir(exist_ok=True)
top=S/'rtl/ppg_control_top/ppg_control_top.v'; tb=S/'rtl/ppg_control_top/tb_ppg_control_top_injection.v'
src=top.read_text(encoding='utf-8'); original=tb.read_text(encoding='utf-8')
connection='assign o_result_frame_id = ami_result_frame_id_o;'
assert src.count(connection)==1
mut=src.replace(connection,'assign o_result_frame_id = ami_result_frame_id_o ^ (o_result_sample_valid ? {C_FRAME_ID_WIDTH{1\'b0}} : {{(C_FRAME_ID_WIDTH-1){1\'b0}},1\'b1});')
mt=d/'ppg_control_top_frame_mutant.v';mt.write_text(mut,encoding='utf-8')
ot=original.replace('reg reg_captured_sample_valid;','reg reg_captured_sample_valid;\nreg [C_FRAME_ID_WIDTH-1:0] audit_expected_frame;')
arm="i_test_invalid_sample_valid = 1'b1; // 先武装，反压保持到真正握手"
assert ot.count(arm)==1
ot=ot.replace(arm,'audit_expected_frame = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_frame_id;\n'+arm)
capture='reg_captured_frame_id = o_result_frame_id;'
assert ot.count(capture)==1
oracle='\n$display("AUDIT_IDENTITY expected_frame=%0d observed_frame=%0d sample_valid=%b", audit_expected_frame, reg_captured_frame_id, reg_captured_sample_valid);\nif(reg_captured_frame_id !== audit_expected_frame) $display("AUDIT_IDENTITY_FAIL invalid result frame differs from the real accepted owner");'
ot=ot.replace(capture,capture+oracle)
observed=d/'tb_observed.v'; observed.write_text(ot,encoding='utf-8')
control=d/'tb_expected_control.v';control.write_text(ot.replace('if(reg_captured_frame_id !== audit_expected_frame) $display','if(reg_captured_frame_id !== audit_expected_frame) begin cnt_error=cnt_error+1; $display').replace('real accepted owner");','real accepted owner"); end'),encoding='utf-8')
filelist=S/'rtl/ppg_control_top/xsim_injection_filelist.f'
sources=[(filelist.parent/l.strip()).resolve() for l in filelist.read_text(encoding='utf-8').splitlines() if l.strip() and not l.lstrip().startswith('#')]
results=[]
for name,dut,bench in [('positive',top,observed),('finite_frame_mutant',mt,observed),('negative_expected_comparison',mt,control)]:
    inputs=[dut if p==top else bench if p==tb else p for p in sources]
    result=run('inj_identity_A/'+name,inputs,'tb_ppg_control_top_injection',timeout=180)
    log=(E/'inj_identity_A'/name/'native.run.log').read_text(encoding='utf-8',errors='replace')
    lines=[x for x in log.splitlines() if 'AUDIT_IDENTITY' in x or 'INJ-03' in x or '_TB_' in x]
    print(name,*lines,sep='\n');results.append(dict(name=name,compile_rc=result['compile_rc'],run_rc=result['run_rc'],key_lines=lines))
(d/'comparison.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf-8')
