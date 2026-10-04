`timescale 1ns/1ps
module tb_C_fir;
reg clk=0, rstn=0, vin=0; reg signed [23:0] sample=0; wire rin,vout,qual,satlo,sathi; wire signed [23:0] value; integer waitcycles;
always #5 clk=~clk;
ppg_coarse_detection_fir dut(
.i_clk(clk),
.i_rstn(rstn),
.i_run_enable(1'b1),
.i_start_ack_event('d0),
.i_recheck_accept_event('d0),
.i_recheck_busy('d0),
.i_detection_discard_event('d0),
.i_detection_discard_reason('d0),
.i_detection_discard_identity_valid('d0),
.i_detection_discard_sample_valid('d0),
.i_detection_discard_frame_id('d0),
.i_detection_discard_sample_index('d0),
.i_detection_discard_color_ir('d0),
.i_detection_discard_frame_type('d0),
.i_detection_discard_precision('d0),
.i_detection_discard_config_epoch('d0),
.i_detection_discard_coef_epoch('d0),
.i_detection_discard_dc_recovery_epoch('d0),
.i_detection_discard_amb_code_epoch('d0),
.i_detection_discard_dc_code_epoch('d0),
.i_detection_discard_run_generation('d0),
.i_run_generation(8'd1),
.o_local_empty(),
.i_result_valid(vin),
.o_result_ready(rin),
.i_sample_valid(1'b1),
.i_coarse_ppg_value(sample),
.i_coarse_valid(1'b1),
.i_coarse_recovery_calibrated(1'b1),
.i_stage1_saturation_low('d0),
.i_stage1_saturation_high('d0),
.i_coarse_saturation_low('d0),
.i_coarse_saturation_high('d0),
.i_config_epoch('d0),
.i_coef_epoch('d0),
.i_dc_recovery_coef_epoch('d0),
.i_precision_mode('d0),
.i_frame_id('d0),
.i_sample_index('d0),
.i_color_ir('d0),
.i_frame_type(2'b10),
.i_amb_code_snapshot('d0),
.i_dc_code_snapshot('d0),
.i_amb_code_epoch('d0),
.i_dc_code_epoch('d0),
.i_test_inject_enable('d0),
.i_test_calibration_loss_inject_valid('d0),
.o_test_calibration_loss_inject_ready(),
.i_result_ready(1'b0),
.o_result_valid(vout),
.o_filtered_ppg_value(value),
.o_detection_qualified(qual),
.o_window_saturation_low(),
.o_window_saturation_high(),
.o_fir_saturation_low(satlo),
.o_fir_saturation_high(sathi),
.o_history_full_r(),
.o_history_full_ir(),
.o_fir_idle(),
.o_config_epoch(),
.o_coef_epoch(),
.o_dc_recovery_coef_epoch(),
.o_precision_mode(),
.o_frame_id(),
.o_sample_index(),
.o_color_ir(),
.o_frame_type(),
.o_amb_code_snapshot(),
.o_dc_code_snapshot(),
.o_amb_code_epoch(),
.o_dc_code_epoch()
);
initial begin
// 合同向量0，每次独立真实21点预热。
rstn=0; vin=0; repeat(2) @(negedge clk); rstn=1;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
waitcycles=0; while(vout!==1'b1 && waitcycles<16) begin @(negedge clk); waitcycles=waitcycles+1; end
if(vout!==1'b1 || value!==24'sd8388607 || qual!==1'b1 || satlo!==1'b0 || sathi!==1'b0) $fatal(1,"C_FIR_VECTOR_FAIL case=0 value=%0d expected=8388607 qual=%b",value,qual);
$display("C_FIR_VECTOR_PASS case=0 value=%0d",value);
// 合同向量1，每次独立真实21点预热。
rstn=0; vin=0; repeat(2) @(negedge clk); rstn=1;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
waitcycles=0; while(vout!==1'b1 && waitcycles<16) begin @(negedge clk); waitcycles=waitcycles+1; end
if(vout!==1'b1 || value!==-24'sd8388608 || qual!==1'b1 || satlo!==1'b0 || sathi!==1'b0) $fatal(1,"C_FIR_VECTOR_FAIL case=1 value=%0d expected=-8388608 qual=%b",value,qual);
$display("C_FIR_VECTOR_PASS case=1 value=%0d",value);
// 合同向量2，每次独立真实21点预热。
rstn=0; vin=0; repeat(2) @(negedge clk); rstn=1;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
waitcycles=0; while(vout!==1'b1 && waitcycles<16) begin @(negedge clk); waitcycles=waitcycles+1; end
if(vout!==1'b1 || value!==24'sd0 || qual!==1'b1 || satlo!==1'b0 || sathi!==1'b0) $fatal(1,"C_FIR_VECTOR_FAIL case=2 value=%0d expected=0 qual=%b",value,qual);
$display("C_FIR_VECTOR_PASS case=2 value=%0d",value);
// 合同向量3，每次独立真实21点预热。
rstn=0; vin=0; repeat(2) @(negedge clk); rstn=1;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd8388607; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd8388608; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
waitcycles=0; while(vout!==1'b1 && waitcycles<16) begin @(negedge clk); waitcycles=waitcycles+1; end
if(vout!==1'b1 || value!==-24'sd40960 || qual!==1'b1 || satlo!==1'b0 || sathi!==1'b0) $fatal(1,"C_FIR_VECTOR_FAIL case=3 value=%0d expected=-40960 qual=%b",value,qual);
$display("C_FIR_VECTOR_PASS case=3 value=%0d",value);
// 合同向量4，每次独立真实21点预热。
rstn=0; vin=0; repeat(2) @(negedge clk); rstn=1;
@(negedge clk); sample=24'sd1000; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1016; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1032; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1048; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1064; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1080; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1096; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1112; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1128; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1144; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1160; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1176; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1192; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1208; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1224; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1240; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1256; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1272; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1288; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1304; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1320; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
waitcycles=0; while(vout!==1'b1 && waitcycles<16) begin @(negedge clk); waitcycles=waitcycles+1; end
if(vout!==1'b1 || value!==24'sd1160 || qual!==1'b1 || satlo!==1'b0 || sathi!==1'b0) $fatal(1,"C_FIR_VECTOR_FAIL case=4 value=%0d expected=1160 qual=%b",value,qual);
$display("C_FIR_VECTOR_PASS case=4 value=%0d",value);
// 合同向量5，每次独立真实21点预热。
rstn=0; vin=0; repeat(2) @(negedge clk); rstn=1;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd12; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd83; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
waitcycles=0; while(vout!==1'b1 && waitcycles<16) begin @(negedge clk); waitcycles=waitcycles+1; end
if(vout!==1'b1 || value!==24'sd1 || qual!==1'b1 || satlo!==1'b0 || sathi!==1'b0) $fatal(1,"C_FIR_VECTOR_FAIL case=5 value=%0d expected=1 qual=%b",value,qual);
$display("C_FIR_VECTOR_PASS case=5 value=%0d",value);
// 合同向量6，每次独立真实21点预热。
rstn=0; vin=0; repeat(2) @(negedge clk); rstn=1;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd0; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd12; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd83; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
waitcycles=0; while(vout!==1'b1 && waitcycles<16) begin @(negedge clk); waitcycles=waitcycles+1; end
if(vout!==1'b1 || value!==-24'sd1 || qual!==1'b1 || satlo!==1'b0 || sathi!==1'b0) $fatal(1,"C_FIR_VECTOR_FAIL case=6 value=%0d expected=-1 qual=%b",value,qual);
$display("C_FIR_VECTOR_PASS case=6 value=%0d",value);
// 合同向量7，每次独立真实21点预热。
rstn=0; vin=0; repeat(2) @(negedge clk); rstn=1;
@(negedge clk); sample=-24'sd8311485; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd1625704; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd5214323; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd4722866; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd2117161; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd7820028; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd980001; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd5860026; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd4077163; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd2762864; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd7174325; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd334298; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd6505729; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd3431460; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd3408567; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd6528622; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd311405; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd7151432; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd2785757; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=-24'sd4054270; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
@(negedge clk); sample=24'sd5882919; vin=1; @(posedge clk); #1; @(negedge clk); vin=0;
waitcycles=0; while(vout!==1'b1 && waitcycles<16) begin @(negedge clk); waitcycles=waitcycles+1; end
if(vout!==1'b1 || value!==24'sd412853 || qual!==1'b1 || satlo!==1'b0 || sathi!==1'b0) $fatal(1,"C_FIR_VECTOR_FAIL case=7 value=%0d expected=412853 qual=%b",value,qual);
$display("C_FIR_VECTOR_PASS case=7 value=%0d",value);
$display("C_FIR_CONTRACT_VECTORS_PASS count=8"); $finish; end
initial begin #100000; $fatal(1,"C_FIR_VECTOR_TIMEOUT"); end
endmodule
