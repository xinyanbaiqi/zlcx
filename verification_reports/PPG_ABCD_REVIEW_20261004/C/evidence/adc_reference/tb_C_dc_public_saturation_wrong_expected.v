`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Design Name:        PPG ADC DC Recovery Self-Checking Testbench
// Module Name:        tb_ppg_adc_dc_recovery
// Description:        Contract-directed checks for arithmetic, saturation and holding protocol.
///////////////////////////////////Chinese////////////////////////////////////////
// 公司:                Erie
// 设计名称:            PPG ADC DC恢复自检测试平台
// 模块名称:            tb_ppg_adc_dc_recovery
// 模块说明:            覆盖DC恢复公式、舍入、饱和、模式切换和反压保持合同。

module tb_C_dc_public_saturation;
	localparam integer C_FRAME_ID_WIDTH = 16;
	localparam integer C_SAMPLE_INDEX_WIDTH = 16;
	localparam integer C_IDAC_CODE_WIDTH = 8;
	localparam integer C_CODE_EPOCH_WIDTH = 4;
	localparam integer C_CONFIG_EPOCH_WIDTH = 8;
	localparam integer C_COEF_EPOCH_WIDTH = 8;
	localparam integer C_DC_RECOVERY_EPOCH_WIDTH = 8;
	localparam integer A1_FIXED_Q16 = 3533837;

	reg i_clk;
	reg i_rstn;
	reg i_active_valid;
	reg i_dc9_recovery_valid;
	reg i_dc15_recovery_valid;
	reg signed [31:0]i_dc9_recovery_gain_q16;
	reg signed [31:0]i_dc15_recovery_gain_q16;
	reg [7:0]i_dc_recovery_coef_epoch;
	reg i_result_valid;
	wire o_result_ready;
	reg i_result_ready;
	reg signed [11:0]i_calibrated_s1_value;
	reg i_calibration_applied;
	reg i_stage1_saturation_low;
	reg i_stage1_saturation_high;
	reg signed [14:0]i_programmable_15_code;
	reg i_programmable_15_valid;
	reg i_programmable_15_calibration_applied;
	reg i_programmable_saturation_low;
	reg i_programmable_saturation_high;
	reg [7:0]i_config_epoch;
	reg [7:0]i_coef_epoch;
	reg [7:0]i_stage2_coef_epoch;
	reg i_precision_mode;
	reg [15:0]i_frame_id;
	reg [15:0]i_sample_index;
	reg i_color_ir;
	reg [1:0]i_frame_type;
	reg [7:0]i_amb_code_snapshot;
	reg [7:0]i_dc_code_snapshot;
	reg [3:0]i_amb_code_epoch;
	reg [3:0]i_dc_code_epoch;

	wire o_result_valid;
	wire signed [23:0]o_coarse_ppg_value;
	wire o_coarse_valid;
	wire o_coarse_recovery_calibrated;
	wire o_coarse_saturation_low;
	wire o_coarse_saturation_high;
	wire signed [23:0]o_fine_ppg_value;
	wire o_fine_valid;
	wire o_fine_recovery_calibrated;
	wire o_fine_saturation_low;
	wire o_fine_saturation_high;
	wire [7:0]o_dc_recovery_coef_epoch;
	wire signed [11:0]o_calibrated_s1_value;
	wire o_calibration_applied;
	wire o_stage1_saturation_low;
	wire o_stage1_saturation_high;
	wire signed [14:0]o_programmable_15_code;
	wire o_programmable_15_valid;
	wire o_programmable_15_calibration_applied;
	wire o_programmable_saturation_low;
	wire o_programmable_saturation_high;
	wire [7:0]o_config_epoch;
	wire [7:0]o_coef_epoch;
	wire [7:0]o_stage2_coef_epoch;
	wire o_precision_mode;
	wire [15:0]o_frame_id;
	wire [15:0]o_sample_index;
	wire o_color_ir;
	wire [1:0]o_frame_type;
	wire [7:0]o_amb_code_snapshot;
	wire [7:0]o_dc_code_snapshot;
	wire [3:0]o_amb_code_epoch;
	wire [3:0]o_dc_code_epoch;
	integer error_count;
	reg signed [63:0]model_dc_code;
	reg signed [63:0]model_coarse_acc;
	reg signed [63:0]model_fine_acc;
	reg signed [63:0]model_coarse_rounded;
	reg signed [63:0]model_fine_rounded;
	reg signed [23:0]expected_coarse;
	reg signed [23:0]expected_fine;
	reg expected_coarse_low;
	reg expected_coarse_high;
	reg expected_fine_low;
	reg expected_fine_high;
	reg signed [23:0]held_coarse;
	reg signed [23:0]held_fine;
	reg [7:0]held_dc_code;

	// 使用独立64-bit定点模型复现合同公式、对称舍入和24-bit饱和。
	task calculate_model;
		input precision;
		input signed [11:0]s1_value;
		input signed [14:0]fine_value;
		input [7:0]dc_code;
		input signed [31:0]gain9;
		input signed [31:0]gain15;
		begin
			model_dc_code = {56'd0, dc_code};
			model_coarse_acc = (($signed(s1_value) * 64'sd2) - 64'sd511) *
				64'sd3533837 + model_dc_code * $signed(gain9) * 64'sd2;
			model_fine_acc = $signed(fine_value) * 64'sd131072 +
				model_dc_code * $signed(gain15) * 64'sd2;
			if(model_coarse_acc < 0)begin
				model_coarse_rounded = -(((-model_coarse_acc) + 64'sd65536) >>> 17);
			end else begin
				model_coarse_rounded = (model_coarse_acc + 64'sd65536) >>> 17;
			end
			if(model_fine_acc < 0)begin
				model_fine_rounded = -(((-model_fine_acc) + 64'sd65536) >>> 17);
			end else begin
				model_fine_rounded = (model_fine_acc + 64'sd65536) >>> 17;
			end
			expected_coarse_low = (model_coarse_rounded < -64'sd8388608);
			expected_coarse_high = (model_coarse_rounded > 64'sd8388607);
			expected_fine_low = precision && (model_fine_rounded < -64'sd8388608);
			expected_fine_high = precision && (model_fine_rounded > 64'sd8388607);
			if(expected_coarse_low)begin
				expected_coarse = -24'sd8388608;
			end else if(expected_coarse_high)begin
				expected_coarse = 24'sd8388607;
			end else begin
				expected_coarse = model_coarse_rounded[23:0];
			end
			if(precision == 1'b0)begin
				expected_fine = 24'sd0;
			end else if(expected_fine_low)begin
				expected_fine = -24'sd8388608;
			end else if(expected_fine_high)begin
				expected_fine = 24'sd8388607;
			end else begin
				expected_fine = model_fine_rounded[23:0];
			end
		end
	endtask

	task drive_and_check;
		input integer test_id;
		input precision;
		input signed [11:0]s1_value;
		input signed [14:0]fine_value;
		input [7:0]dc_code;
		input signed [31:0]gain9;
		input signed [31:0]gain15;
		begin
			calculate_model(precision, s1_value, fine_value, dc_code, gain9, gain15);
			@(negedge i_clk);
			i_precision_mode = precision;
			i_calibrated_s1_value = s1_value;
			i_programmable_15_code = fine_value;
			i_dc_code_snapshot = dc_code;
			i_dc9_recovery_gain_q16 = gain9;
			i_dc15_recovery_gain_q16 = gain15;
			i_result_valid = 1'b1;
			i_result_ready = 1'b1;
			@(posedge i_clk);
			#1;
			if(o_result_valid !== 1'b1 || o_coarse_ppg_value !== expected_coarse ||
				o_fine_ppg_value !== expected_fine || o_coarse_valid !== 1'b1 ||
				o_fine_valid !== precision || o_dc_code_snapshot !== dc_code ||
				o_coarse_saturation_low !== expected_coarse_low ||
				o_coarse_saturation_high !== expected_coarse_high ||
				o_fine_saturation_low !== expected_fine_low ||
				o_fine_saturation_high !== expected_fine_high ||
				o_coarse_recovery_calibrated !== (i_calibration_applied && i_dc9_recovery_valid) ||
				o_fine_recovery_calibrated !== (i_programmable_15_calibration_applied && i_dc15_recovery_valid) ||
				o_config_epoch !== i_config_epoch || o_coef_epoch !== i_coef_epoch ||
				o_stage2_coef_epoch !== i_stage2_coef_epoch ||
				o_dc_recovery_coef_epoch !== i_dc_recovery_coef_epoch ||
				o_frame_id !== i_frame_id || o_sample_index !== i_sample_index ||
				o_color_ir !== i_color_ir || o_frame_type !== i_frame_type ||
				o_amb_code_snapshot !== i_amb_code_snapshot ||
				o_amb_code_epoch !== i_amb_code_epoch || o_dc_code_epoch !== i_dc_code_epoch ||
				o_stage1_saturation_low !== i_stage1_saturation_low ||
				o_stage1_saturation_high !== i_stage1_saturation_high ||
				o_programmable_saturation_low !== i_programmable_saturation_low ||
				o_programmable_saturation_high !== i_programmable_saturation_high)begin
				error_count = error_count + 1;
				$display("FAIL DCR-%0d coarse=%0d fine=%0d", test_id, $signed(o_coarse_ppg_value), $signed(o_fine_ppg_value));
			end
			@(negedge i_clk);
			i_result_valid = 1'b0;
		end
	endtask

	always begin
		#5 i_clk = ~i_clk;
	end

	initial begin
		i_clk = 1'b0;
		i_rstn = 1'b0;
		i_active_valid = 1'b0;
		i_dc9_recovery_valid = 1'b0;
		i_dc15_recovery_valid = 1'b0;
		i_dc9_recovery_gain_q16 = 32'sd0;
		i_dc15_recovery_gain_q16 = 32'sd0;
		i_dc_recovery_coef_epoch = 8'h2a;
		i_result_valid = 1'b0;
		i_result_ready = 1'b0;
		i_calibrated_s1_value = 12'sd256;
		i_calibration_applied = 1'b1;
		i_stage1_saturation_low = 1'b0;
		i_stage1_saturation_high = 1'b0;
		i_programmable_15_code = 15'sd1000;
		i_programmable_15_valid = 1'b1;
		i_programmable_15_calibration_applied = 1'b1;
		i_programmable_saturation_low = 1'b0;
		i_programmable_saturation_high = 1'b0;
		i_config_epoch = 8'h11;
		i_coef_epoch = 8'h22;
		i_stage2_coef_epoch = 8'h33;
		i_precision_mode = 1'b0;
		i_frame_id = 16'h1234;
		i_sample_index = 16'h0056;
		i_color_ir = 1'b0;
		i_frame_type = 2'b10;
		i_amb_code_snapshot = 8'h5a;
		i_dc_code_snapshot = 8'h00;
		i_amb_code_epoch = 4'h7;
		i_dc_code_epoch = 4'h8;
		error_count = 0;
		#2;
		if(o_result_valid !== 1'b0 || o_result_ready !== 1'b0 || o_coarse_ppg_value !== 24'sd0)begin
			error_count = error_count + 1;
			$display("FAIL DCR-01 reset");
		end
		@(negedge i_clk);
		i_rstn = 1'b1;
		i_active_valid = 1'b1;
		i_dc9_recovery_valid = 1'b1;
		i_dc15_recovery_valid = 1'b1;
		i_dc9_recovery_gain_q16 = 32'sd65536;
		i_dc15_recovery_gain_q16 = 32'sd65536;
 drive_and_check(101,1'b1,12'sd2047,15'sd16383,8'd255,32'sh7fffffff,32'sh7fffffff);
 if(o_coarse_ppg_value !== 24'sd8388607 || !o_coarse_saturation_high || o_coarse_saturation_low || o_fine_ppg_value !== 24'sd8372224 || o_fine_saturation_low || o_fine_saturation_high) $fatal(1,"C_DC_PUBLIC_POS_FAIL");
 $display("C_DC_PUBLIC_POS_PASS coarse=%0d fine=%0d",$signed(o_coarse_ppg_value),$signed(o_fine_ppg_value));
 drive_and_check(102,1'b1,-12'sd2048,-15'sd16384,8'd255,-32'sh80000000,-32'sh80000000);
 if(o_coarse_ppg_value !== -24'sd8388608 || !o_coarse_saturation_low || o_coarse_saturation_high || o_fine_ppg_value !== -24'sd8372224 || o_fine_saturation_low || o_fine_saturation_high) $fatal(1,"C_DC_PUBLIC_NEG_FAIL");
 if(error_count!=0) $fatal(1,"C_DC_MODEL_FAIL");
 $display("C_DC_PUBLIC_SATURATION_PASS cases=2"); $finish;
 end
	ppg_adc_dc_recovery dut(
		.i_clk(i_clk), .i_rstn(i_rstn), .i_active_valid(i_active_valid),
		.i_dc9_recovery_valid(i_dc9_recovery_valid), .i_dc15_recovery_valid(i_dc15_recovery_valid),
		.i_dc9_recovery_gain_q16(i_dc9_recovery_gain_q16), .i_dc15_recovery_gain_q16(i_dc15_recovery_gain_q16),
		.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch), .i_result_valid(i_result_valid),
		.o_result_ready(o_result_ready), .i_result_ready(i_result_ready),
		.i_calibrated_s1_value(i_calibrated_s1_value), .i_calibration_applied(i_calibration_applied),
		.i_stage1_saturation_low(i_stage1_saturation_low), .i_stage1_saturation_high(i_stage1_saturation_high),
		.i_programmable_15_code(i_programmable_15_code), .i_programmable_15_valid(i_programmable_15_valid),
		.i_programmable_15_calibration_applied(i_programmable_15_calibration_applied),
		.i_programmable_saturation_low(i_programmable_saturation_low), .i_programmable_saturation_high(i_programmable_saturation_high),
		.i_config_epoch(i_config_epoch), .i_coef_epoch(i_coef_epoch), .i_stage2_coef_epoch(i_stage2_coef_epoch),
		.i_precision_mode(i_precision_mode), .i_frame_id(i_frame_id), .i_sample_index(i_sample_index),
		.i_color_ir(i_color_ir), .i_frame_type(i_frame_type), .i_amb_code_snapshot(i_amb_code_snapshot),
		.i_dc_code_snapshot(i_dc_code_snapshot), .i_amb_code_epoch(i_amb_code_epoch), .i_dc_code_epoch(i_dc_code_epoch),
		.o_result_valid(o_result_valid), .o_coarse_ppg_value(o_coarse_ppg_value), .o_coarse_valid(o_coarse_valid),
		.o_coarse_recovery_calibrated(o_coarse_recovery_calibrated), .o_coarse_saturation_low(o_coarse_saturation_low),
		.o_coarse_saturation_high(o_coarse_saturation_high), .o_fine_ppg_value(o_fine_ppg_value), .o_fine_valid(o_fine_valid),
		.o_fine_recovery_calibrated(o_fine_recovery_calibrated), .o_fine_saturation_low(o_fine_saturation_low),
		.o_fine_saturation_high(o_fine_saturation_high), .o_dc_recovery_coef_epoch(o_dc_recovery_coef_epoch),
		.o_calibrated_s1_value(o_calibrated_s1_value), .o_calibration_applied(o_calibration_applied),
		.o_stage1_saturation_low(o_stage1_saturation_low), .o_stage1_saturation_high(o_stage1_saturation_high),
		.o_programmable_15_code(o_programmable_15_code), .o_programmable_15_valid(o_programmable_15_valid),
		.o_programmable_15_calibration_applied(o_programmable_15_calibration_applied),
		.o_programmable_saturation_low(o_programmable_saturation_low), .o_programmable_saturation_high(o_programmable_saturation_high),
		.o_config_epoch(o_config_epoch), .o_coef_epoch(o_coef_epoch), .o_stage2_coef_epoch(o_stage2_coef_epoch),
		.o_precision_mode(o_precision_mode),
		.o_frame_id(o_frame_id), .o_sample_index(o_sample_index), .o_color_ir(o_color_ir), .o_frame_type(o_frame_type),
		.o_amb_code_snapshot(o_amb_code_snapshot), .o_dc_code_snapshot(o_dc_code_snapshot),
		.o_amb_code_epoch(o_amb_code_epoch), .o_dc_code_epoch(o_dc_code_epoch)
	);
endmodule
