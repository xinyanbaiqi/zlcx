from sim import *
p='rtl/ppg_precision_window_controller/ppg_precision_window_controller.v'
rtl=(SNAP/p).read_text(encoding='utf-8')
tb=(SNAP/'rtl/ppg_precision_window_controller/tb_ppg_precision_window_controller.v').read_text(encoding='utf-8')
prefix=tb[:tb.index('\n\tinitial begin')]
body=r'''
 integer reason;
 initial begin
  i_clk=0;i_rstn=1;cnt_error=0;cnt_pass=0;set_default_inputs;
  for(reason=0;reason<3;reason=reason+1)begin
   reset_dut; start_run(0,0,1);
   request_cross(16'h8000,16'h8001,0,8'h11,8'h22,8'h33);
   check_case("BSETUP_ENTER",o_switch_pending===1'b1 && o_active_precision_mode===1'b0);
   @(negedge i_clk);
   i_detection_discard_event=1;i_detection_discard_reason=reason;
   i_detection_discard_run_generation=RUN_GENERATION_CURRENT;
   i_frame_safe_boundary=1;i_safe_frame_id=16'h8002;
   step_clock;
   $display("B_CANCEL_ENTER reason=%0d mode=%b window=%b start=%b pending=%b state=%0d",reason,o_active_precision_mode,o_fine_window_active,o_fine_window_start_event,o_switch_pending,dut.state_current);
   check_case("BCANCEL_ENTER",o_active_precision_mode===1'b0 && o_fine_window_active===1'b0 && o_fine_window_start_event===1'b0 && o_switch_pending===1'b0);
   reset_dut; start_run(0,0,1); enter_fine_window(16'h8100,16'h8101);
   request_return(RETURN_FINE_TIMEOUT,16'h8102);
   check_case("BSETUP_RETURN",o_switch_pending===1'b1 && o_active_precision_mode===1'b1);
   @(negedge i_clk);
   i_detection_discard_event=1;i_detection_discard_reason=reason;
   i_detection_discard_run_generation=RUN_GENERATION_CURRENT;
   i_frame_safe_boundary=1;i_safe_frame_id=16'h8103;
   step_clock;
   $display("B_CANCEL_RETURN reason=%0d mode=%b window=%b return=%b pending=%b state=%0d",reason,o_active_precision_mode,o_fine_window_active,o_precision_15_to_9_event,o_switch_pending,dut.state_current);
   check_case("BCANCEL_RETURN",o_active_precision_mode===1'b1 && o_fine_window_active===1'b0 && o_precision_15_to_9_event===1'b0 && o_switch_pending===1'b0);
  end
  reset_dut; start_run(0,0,1);
  request_cross(16'h8200,16'h8201,0,1,2,3);
  @(negedge i_clk);i_detection_discard_event=1;i_detection_discard_run_generation=RUN_GENERATION_STALE;
  commit_safe_frame(16'h8202);
  check_case("BSTALE_COMMITS",o_active_precision_mode===1'b1 && o_fine_window_active===1'b1 && o_fine_window_start_event===1'b1);
  reset_dut; start_run(0,0,1); enter_fine_window(16'h8300,16'h8301);
  request_return(RETURN_VALLEY_CONFIRMED,16'h8302);commit_safe_frame(16'h8303);
  check_case("BNORMAL_RETURN",o_active_precision_mode===1'b0 && o_fine_window_active===1'b0 && o_precision_15_to_9_event===1'b1);
  $display("B_PWC_CANCEL pass=%0d fail=%0d",cnt_pass,cnt_error);
  if(cnt_error!=0)$fatal(1,"B_PWC_CANCEL_FAIL");$finish;
 end
 initial begin #50000;$fatal(1,"B_PWC_TIMEOUT");end
endmodule
'''
newtb=prefix+body
sim('pwc_cancel_commit','tb_ppg_precision_window_controller',[p],newtb)
mut=rtl.replace('assign flag_enter_commit = (state_current == ST_WAIT_ENTER) &&','assign flag_enter_commit = !flag_lifecycle_cancel && (state_current == ST_WAIT_ENTER) &&').replace('assign flag_return_commit = (state_current == ST_WAIT_RETURN) &&','assign flag_return_commit = !flag_lifecycle_cancel && (state_current == ST_WAIT_RETURN) &&')
assert mut!=rtl
sim('pwc_cancel_commit_counterfactual','tb_ppg_precision_window_controller',[p],newtb,{Path(p).name:mut})
