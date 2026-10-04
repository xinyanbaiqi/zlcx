`timescale 1ns/1ps
module audit_prc09;
reg clk=0,rstn=1,valid=0,inj=0,armed=0,recovered=0;
integer unqual=0;
always #5 clk=~clk;
ppg_coarse_detection_fir #(.C_ENABLE_TEST_INJECTION(1)) dut (
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
.i_result_ready(1'b1));
always @(posedge clk) if(armed)begin
 if(!dut.o_detection_qualified) unqual=unqual+1;
 else recovered=1;
end
integer n,g;
initial begin
 #1 rstn=0; #20 rstn=1;
 for(n=0;n<21;n=n+1)begin
  @(negedge clk);valid=1;
  @(posedge clk);#1;
  @(negedge clk);valid=0;
 end
 g=0;while(dut.o_result_valid!==1 && g<100)begin @(posedge clk);#1;g=g+1;end
 if(dut.o_detection_qualified!==1)$fatal(1,"WARMUP_FAIL");
 @(negedge clk);inj=1;
 @(posedge clk);#1;inj=0;armed=1;
 g=0;while(!recovered && g<200)begin @(posedge clk);#1;g=g+1;end
 armed=0;
 $display("PROBE checker_recovered=%b unqualified_cycles=%0d FIR_armed=%b FIR_valid=%b qualified=%b",recovered,unqual,dut.flag_test_calibration_loss_armed,dut.o_result_valid,dut.o_detection_qualified);
 if(!recovered || unqual!=0 || dut.flag_test_calibration_loss_armed!==1)$fatal(1,"PROBE_UNEXPECTED");
 $display("PROBE_CONFIRMED checker exits before injected sample is consumed");$finish;
end
initial begin #100000;$fatal(1,"PROBE_TIMEOUT");end
endmodule
