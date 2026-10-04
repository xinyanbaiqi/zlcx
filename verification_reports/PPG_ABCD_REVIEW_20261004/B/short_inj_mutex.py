from sim import *
p='rtl/ppg_control_top/tb_ppg_control_top_injection.v'
lines=(SNAP/p).read_text(encoding='utf-8').splitlines(True)
prefix=''.join(lines[:631]).replace('.i_test_invalid_sample_valid(i_test_invalid_sample_valid),','.i_test_invalid_sample_valid(i_test_invalid_sample_valid),\n .i_test_calibration_loss_inject_valid(1\'b0),')
init=''.join(lines[632:675]).replace("i_test_inject_enable = 1'b0;","i_test_inject_enable = 1'b1;")
case=''.join(lines[988:1021])
body=r'''
 integer b_mutex_cycles;integer b_eligible_cycles;integer b_ready_cycles;
 initial begin
  b_mutex_cycles=0;b_eligible_cycles=0;b_ready_cycles=0;
 INIT_HERE
 CASE_HERE
  $display("B_INJ_MUTEX original_window_cycles=%0d eligible_cycles=%0d ready_cycles=%0d errors=%0d",b_mutex_cycles,b_eligible_cycles,b_ready_cycles,cnt_error);
  if(cnt_error!=0 || b_ready_cycles!=0)$fatal(1,"B_INJ_MUTEX_FAIL");
  $display("B_INJ_MUTEX_PASS");$finish;
 end
 always@(posedge i_clk)begin
  if(i_test_identity_inject_valid===1'b1 && i_test_invalid_sample_valid===1'b1)begin
   b_mutex_cycles=b_mutex_cycles+1;
   if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_pending===1'b1 || ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_dc_result_valid===1'b1)b_eligible_cycles=b_eligible_cycles+1;
   if(o_test_identity_inject_ready===1'b1 || o_test_invalid_sample_ready===1'b1)b_ready_cycles=b_ready_cycles+1;
  end
 end
endmodule
'''
src=[str(x.relative_to(SNAP)).replace('\\','/') for x in (SNAP/'rtl').glob('*/*.v') if x.name.startswith('ppg_')]
ami='rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v'
rtl=(SNAP/ami).read_text(encoding='utf-8');rl=rtl.splitlines(True)
assert 'assign o_test_identity_inject_ready' in rl[1011] and 'assign o_test_invalid_sample_ready' in rl[1012]
rl[1011]=rl[1011].replace(' && !i_test_invalid_sample_valid','',1)
rl[1012]=rl[1012].replace(' && !i_test_identity_inject_valid','',1)
mut={Path(ami).name:''.join(rl)}
for strict in ([True] if len(sys.argv)>1 and sys.argv[1]=='v2' else [False,True]):
 chosen=case
 if strict:
  chosen=chosen.replace('repeat(4) @(posedge i_clk);','drive_real_adc_done(1\'b0, reg_fixed_stage1_raw, reg_fixed_stage2_raw);\n repeat(60) @(negedge i_clk);',1)
  chosen=chosen.replace("i_test_invalid_sample_valid = 1'b1;","i_test_invalid_sample_valid = 1'b1;\n i_measurement_result_ready=0;",1)
 newtb=prefix+body.replace('INIT_HERE',init).replace('CASE_HERE',chosen)
 name='inj_mutex_eligible_v2' if strict else 'inj_mutex_original'
 sim(name,'tb_ppg_control_top_injection',src,newtb)
 sim(name+'_mutant','tb_ppg_control_top_injection',src,newtb,mut)
