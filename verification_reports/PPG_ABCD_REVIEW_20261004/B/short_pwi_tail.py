from sim import *
p='rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v'
tb=(SNAP/p).read_text(encoding='utf-8')
lines=tb.splitlines(True)
short=''.join(lines[:746])+r'''
 $display("B_PWI_TAIL saved_preconditions=%b pass=%0d fail=%0d",flag_case_ok,cnt_pass,cnt_fail);
 if(cnt_fail!=0)$fatal(1,"B_PWI_TAIL_FAIL");$finish;
end
initial begin #2000000;$fatal(1,"B_PWI_TAIL_TIMEOUT");end
endmodule
'''
strict=short.replace('check_case("PWI-01", o_peak_valley_protocol_error_sticky','check_case("PWI-01", flag_case_ok && o_peak_valley_protocol_error_sticky')
assert strict!=short
pv=SNAP/'rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v'
rtl=pv.read_text(encoding='utf-8')
mut=rtl.replace('FIR_GROUP_DELAY_LIMIT = C_FIR_GROUP_DELAY_SAMPLES','FIR_GROUP_DELAY_LIMIT = 0')
assert mut!=rtl
src=[str(p.relative_to(SNAP)).replace('\\','/') for p in SNAP.glob('rtl/*/ppg_*.v')]
if 'v2' not in sys.argv:
 sim('pwi_tail_original_check','tb_ppg_precision_window_integration',src,short)
 sim('pwi_tail_early_overflow_mutant','tb_ppg_precision_window_integration',src,short,{pv.name:mut})
 sim('pwi_tail_strict_check','tb_ppg_precision_window_integration',src,strict)
 sim('pwi_tail_strict_early_overflow_mutant','tb_ppg_precision_window_integration',src,strict,{pv.name:mut})
else:
 fixed=strict.replace('flag_case_ok = flag_case_ok && o_active_precision_mode', '@(negedge i_clk);\n\t$display("B_FINE_COUNTER mode=%b fine=%b count=%0d",o_active_precision_mode,o_fine_window_active,cnt_fine_start_event);\n\tflag_case_ok = flag_case_ok && o_active_precision_mode',1)
 fixed=fixed.replace('flag_case_ok = flag_case_ok && (o_peak_valley_protocol_error_sticky', '$display("B_TAIL10 sticky=%b saved=%b",o_peak_valley_protocol_error_sticky,flag_case_ok);\n\tflag_case_ok = flag_case_ok && (o_peak_valley_protocol_error_sticky',1)
 sim('pwi_tail_sampled_strict','tb_ppg_precision_window_integration',src,fixed)
 sim('pwi_tail_sampled_strict_early_mutant','tb_ppg_precision_window_integration',src,fixed,{pv.name:mut})
