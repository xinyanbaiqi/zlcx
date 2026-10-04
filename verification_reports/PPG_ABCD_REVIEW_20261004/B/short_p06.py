from sim import *
p='rtl/ppg_control_top/tb_ppg_control_top_injection.v'
lines=(SNAP/p).read_text(encoding='utf-8').splitlines(True)
prefix=''.join(lines[:631]).replace('.i_test_invalid_sample_valid(i_test_invalid_sample_valid),','.i_test_invalid_sample_valid(i_test_invalid_sample_valid),\n .i_test_calibration_loss_inject_valid(1\'b0),')
init=''.join(lines[632:675]).replace("i_test_inject_enable = 1'b0;","i_test_inject_enable = 1'b1;")
case=''.join(lines[743:791])+'\n end\n end\n end\n'
body=r'''
 integer b_outer_disable_cycles;integer b_leaf_disable_cycles;
 initial begin
 b_outer_disable_cycles=0;b_leaf_disable_cycles=0;
 INIT_HERE
 CASE_HERE
 $display("B_P06 outer_disable_cycles=%0d leaf_disable_cycles=%0d errors=%0d",b_outer_disable_cycles,b_leaf_disable_cycles,cnt_error);
 if(cnt_error!=0)$fatal(1,"B_P06_SETUP_OR_ORIGINAL_FAIL");
 if(b_outer_disable_cycles==0)$fatal(1,"B_P06_NO_OUTER_STIMULUS");
 if(b_leaf_disable_cycles!=0)$fatal(1,"B_P06_LEAF_DISABLED_COUNTEREXAMPLE_REFUTED");
 $display("B_P06_ORIGINAL_PASS_TARGET_ENABLE_NEVER_DISABLED");$finish;
 end
 always@(negedge i_clk)begin
 if(ppg_control_top_Inst.wrapper_run_enable_o===1'b1 && i_test_inject_enable===1'b0)begin
  b_outer_disable_cycles=b_outer_disable_cycles+1;
  if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.i_test_inject_enable===1'b0)b_leaf_disable_cycles=b_leaf_disable_cycles+1;
  $display("B_P06_TRACE outer_enable=%b leaf_enable=%b hold=%b abort=%b",i_test_inject_enable,ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.i_test_inject_enable,ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_test_identity_hold,ppg_control_top_Inst.flag_owner_abort_event);
 end
 end
endmodule
'''
src=[str(x.relative_to(SNAP)).replace('\\','/') for x in (SNAP/'rtl').glob('*/*.v') if x.name.startswith('ppg_')]
ami='rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v'
rtl=(SNAP/ami).read_text(encoding='utf-8');rl=rtl.splitlines(True)
assert 'flag_test_identity_hold <=' in rl[1574] and 'i_start_ack_event' in rl[1575]
rl[1575]=rl[1575].replace('end else if(',"end else if(!i_test_inject_enable) begin\n flag_test_identity_hold <= 1'b0;\n end else if(",1)
newtb=prefix+body.replace('INIT_HERE',init).replace('CASE_HERE',case)
sim('p06_target_enable','tb_ppg_control_top_injection',src,newtb)
sim('p06_target_enable_mutant','tb_ppg_control_top_injection',src,newtb,{Path(ami).name:''.join(rl)})
