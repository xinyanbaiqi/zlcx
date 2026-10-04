from sim import *
p='rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v'
rtl=(SNAP/p).read_text(encoding='utf-8')
tb=(SNAP/'rtl/ppg_sar9_sar15_safe_selection_wrapper/tb_ppg_sar9_sar15_safe_selection_wrapper.v').read_text(encoding='utf-8')
prefix=tb[:tb.index('\n\tinitial begin')]
body=r'''
 integer precision_test;integer success_test;
 task setup_owner;
  input prec;
  begin
   reset_and_start;
   send_waveform(prec,0,FRAME_TYPE_NORMAL,16'h9000,8'h31,8'h41,1,2,8'hA1);
   macro_tick(1);send_owner(prec,0,FRAME_TYPE_NORMAL,16'h9000,16'h9001,8'h31,8'h41,1,2);
   macro_tick(310);i_adc_idle=1;
  end
 endtask
 initial begin
  i_clk=0;i_rstn=0;cnt_error=0;cnt_pass=0;cnt_case_error=0;flag_clock_mismatch=0;set_defaults;
  for(precision_test=0;precision_test<2;precision_test=precision_test+1)begin
   for(success_test=0;success_test<2;success_test=success_test+1)begin
    begin_case("BEQ_DONE");setup_owner(precision_test);
    @(negedge i_clk);i_control_abort_event=1;i_run_enable=0;i_adc_transaction_complete_event=1;
    i_adc_complete_sample_index=16'h9001;i_adc_transaction_success=success_test;
    #1;expect_true(dut.flag_owner_release===1'b1,"matching real completion is recognized before edge");
    @(posedge i_clk);#1;
    $display("B_ABORT_DONE precision=%0d success=%0d recognized=%b inflight=%b idle=%b waveidle=%b physicalidle=%b",precision_test,success_test,dut.flag_owner_release,o_adc_owner_inflight,o_wrapper_idle,o_sar_timing_idle,i_adc_idle);
    expect_true(o_adc_owner_inflight===1'b0 && o_wrapper_idle===1'b1,"abort plus matching one-cycle completion must release owner");
    @(negedge i_clk);i_control_abort_event=0;i_adc_transaction_complete_event=0;
    repeat(20)@(negedge i_clk);
    expect_true(o_adc_owner_inflight===1'b0 && o_wrapper_idle===1'b1,"completed idle ADC must not leave internal owner permanently occupied");
    expect_true(o_clk_q3_low===1'b0 && o_leden1_low===1'b0 && o_leden2_low===1'b0,"abort never resumes waveform");
    end_case("BEQ_DONE");
   end
  end
  begin_case("B_LATE");setup_owner(0);
  @(negedge i_clk);i_control_abort_event=1;i_run_enable=0;
  @(posedge i_clk);#1;expect_true(o_adc_owner_inflight===1'b1,"abort alone retains real owner");
  @(negedge i_clk);i_control_abort_event=0;complete_owner(16'h9001,0);
  expect_true(o_wrapper_idle===1'b1,"later matching failure completion releases");end_case("B_LATE");
  begin_case("B_WRONG");setup_owner(0);
  @(negedge i_clk);i_control_abort_event=1;i_adc_transaction_complete_event=1;i_adc_complete_sample_index=16'hFFFF;
  @(posedge i_clk);#1;expect_true(o_adc_owner_inflight===1'b1,"wrong identity must retain original owner on abort");
  @(negedge i_clk);i_control_abort_event=0;i_adc_transaction_complete_event=0;complete_owner(16'h9001,0);
  end_case("B_WRONG");
  $display("B_SSW_ABORT_DONE cases_pass=%0d failures=%0d",cnt_pass,cnt_error);
  if(cnt_error!=0)$fatal(1,"B_SSW_ABORT_DONE_FAIL");$finish;
 end
 initial begin #500000;$fatal(1,"B_SSW_ABORT_DONE_TIMEOUT");end
endmodule
'''
newtb=prefix+body
if not (OUT/'evidence/ssw_abort_done/result.json').exists():
 sim('ssw_abort_done','tb_ppg_sar9_sar15_safe_selection_wrapper',[p],newtb)
lines=rtl.splitlines(True)
assert 'i_control_abort_event' in lines[513] and 'adc_owner_inflight_o <= adc_owner_inflight_o' in lines[514]
mut=''.join(lines[:513]+lines[515:])
assert mut!=rtl
sim('ssw_abort_done_counterfactual','tb_ppg_sar9_sar15_safe_selection_wrapper',[p],newtb,{Path(p).name:mut})
