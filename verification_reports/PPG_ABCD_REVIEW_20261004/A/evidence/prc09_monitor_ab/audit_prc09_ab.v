`timescale 1ns/1ps
module audit_prc09_ab;
reg clk=0,rstn=1,valid=0,inj=0;
reg armed=0,rec_a=0,rec_b=0;
integer unqual_a=0,unqual_b=0,invalid_a=0,invalid_b=0;
always #5 clk=~clk;
ppg_coarse_detection_fir #(.C_ENABLE_TEST_INJECTION(1)) a(
.i_clk(clk),
.i_rstn(rstn),
.i_run_enable(1'b1),
.i_start_ack_event('0),
.i_recheck_accept_event('0),
.i_recheck_busy('0),
.i_detection_discard_event('0),
.i_detection_discard_reason('0),
.i_detection_discard_identity_valid('0),
.i_detection_discard_sample_valid('0),
.i_detection_discard_frame_id('0),
.i_detection_discard_sample_index('0),
.i_detection_discard_color_ir('0),
.i_detection_discard_frame_type('0),
.i_detection_discard_precision('0),
.i_detection_discard_config_epoch('0),
.i_detection_discard_coef_epoch('0),
.i_detection_discard_dc_recovery_epoch('0),
.i_detection_discard_amb_code_epoch('0),
.i_detection_discard_dc_code_epoch('0),
.i_detection_discard_run_generation('0),
.i_run_generation('0),
.i_result_valid(valid),
.i_sample_valid(1'b1),
.i_coarse_ppg_value('0),
.i_coarse_valid(1'b1),
.i_coarse_recovery_calibrated(1'b1),
.i_stage1_saturation_low('0),
.i_stage1_saturation_high('0),
.i_coarse_saturation_low('0),
.i_coarse_saturation_high('0),
.i_config_epoch('0),
.i_coef_epoch('0),
.i_dc_recovery_coef_epoch('0),
.i_precision_mode('0),
.i_frame_id('0),
.i_sample_index('0),
.i_color_ir('0),
.i_frame_type(2'b10),
.i_amb_code_snapshot('0),
.i_dc_code_snapshot('0),
.i_amb_code_epoch('0),
.i_dc_code_epoch('0),
.i_test_inject_enable(1'b1),
.i_test_calibration_loss_inject_valid(inj),
.i_result_ready(1'b1)
);
audit_fir_ignore_loss #(.C_ENABLE_TEST_INJECTION(1)) b(
.i_clk(clk),
.i_rstn(rstn),
.i_run_enable(1'b1),
.i_start_ack_event('0),
.i_recheck_accept_event('0),
.i_recheck_busy('0),
.i_detection_discard_event('0),
.i_detection_discard_reason('0),
.i_detection_discard_identity_valid('0),
.i_detection_discard_sample_valid('0),
.i_detection_discard_frame_id('0),
.i_detection_discard_sample_index('0),
.i_detection_discard_color_ir('0),
.i_detection_discard_frame_type('0),
.i_detection_discard_precision('0),
.i_detection_discard_config_epoch('0),
.i_detection_discard_coef_epoch('0),
.i_detection_discard_dc_recovery_epoch('0),
.i_detection_discard_amb_code_epoch('0),
.i_detection_discard_dc_code_epoch('0),
.i_detection_discard_run_generation('0),
.i_run_generation('0),
.i_result_valid(valid),
.i_sample_valid(1'b1),
.i_coarse_ppg_value('0),
.i_coarse_valid(1'b1),
.i_coarse_recovery_calibrated(1'b1),
.i_stage1_saturation_low('0),
.i_stage1_saturation_high('0),
.i_coarse_saturation_low('0),
.i_coarse_saturation_high('0),
.i_config_epoch('0),
.i_coef_epoch('0),
.i_dc_recovery_coef_epoch('0),
.i_precision_mode('0),
.i_frame_id('0),
.i_sample_index('0),
.i_color_ir('0),
.i_frame_type(2'b10),
.i_amb_code_snapshot('0),
.i_dc_code_snapshot('0),
.i_amb_code_epoch('0),
.i_dc_code_epoch('0),
.i_test_inject_enable(1'b1),
.i_test_calibration_loss_inject_valid(inj),
.i_result_ready(1'b1)
);
always @(posedge clk)begin
 if(armed)begin
  if(!rec_a)begin if(!a.o_detection_qualified)unqual_a=unqual_a+1;else rec_a=1;end
  if(!rec_b)begin if(!b.o_detection_qualified)unqual_b=unqual_b+1;else rec_b=1;end
  if(a.o_result_valid && !a.o_detection_qualified)invalid_a=invalid_a+1;
  if(b.o_result_valid && !b.o_detection_qualified)invalid_b=invalid_b+1;
 end
end
task send;
begin
 @(negedge clk);valid=1;
 @(posedge clk);#1;
 @(negedge clk);valid=0;
 repeat(20)@(negedge clk);
end
endtask
integer n;
initial begin
 #1 rstn=0;#20 rstn=1;
 for(n=0;n<21;n=n+1)send;
 @(negedge clk);inj=1;
 @(posedge clk);#1;inj=0;armed=1;
 for(n=0;n<22;n=n+1)send;
 armed=0;
 $display("A actual-loss checker_pass=%b unqualified_cycles=%0d actual_unqualified_valid=%0d",rec_a && unqual_a>0,unqual_a,invalid_a);
 $display("B ignored-loss checker_pass=%b unqualified_cycles=%0d actual_unqualified_valid=%0d",rec_b && unqual_b>0,unqual_b,invalid_b);
 if(!(rec_a && unqual_a>0 && rec_b && unqual_b>0) || invalid_a!=21 || invalid_b!=0)$fatal(1,"AUDIT_PRC09_AB_FAIL");
 $display("AUDIT_PRC09_AB_CONFIRMED");$finish;
end
initial begin #100000;$fatal(1,"AUDIT_TIMEOUT");end
endmodule
