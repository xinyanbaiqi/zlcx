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

module tb_ppg_adc_dc_recovery;
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
		// S1=256 gives round(3533837/2^17)=27; DC=2 and K=1 adds 2.
		drive_and_check(2, 1'b0, 12'sd256, 15'sd1000, 8'd2, 32'sd65536, 32'sd65536);
		// DC=0 must contribute zero and 9-bit fine output is invalid/zero.
		drive_and_check(3, 1'b0, 12'sd256, 15'sd1000, 8'd0, 32'sd65536, 32'sd65536);
		// 15-bit mode carries both results and uses the independent K_DC15 path.
		drive_and_check(4, 1'b1, 12'sd256, 15'sd1000, 8'd3, 32'sd131072, 32'sd131072);
		// CHARACTERIZATION calculation is allowed while formal DC validity is low.
		@(negedge i_clk);
		i_dc9_recovery_valid = 1'b0;
		i_dc15_recovery_valid = 1'b0;
		drive_and_check(5, 1'b1, 12'sd256, 15'sd1000, 8'd1, 32'sd65536, 32'sd65536);
		if(o_coarse_recovery_calibrated !== 1'b0 || o_fine_recovery_calibrated !== 1'b0)begin
			error_count = error_count + 1;
			$display("FAIL DCR-12 qualification");
		end
		// 24-bit positive and negative endpoint saturation.
		i_dc9_recovery_valid = 1'b1;
		i_dc15_recovery_valid = 1'b1;
		drive_and_check(6, 1'b1, 12'sd256, 15'sd16383, 8'hff, 32'sh7fffffff, 32'sh7fffffff);
		drive_and_check(7, 1'b1, 12'sd256, -15'sd16384, 8'hff, -32'sh80000000, -32'sh80000000);
		// 正负半LSB必须采用对称且远离零的舍入规则。
		drive_and_check(8, 1'b1, 12'sd256, 15'sd0, 8'd1, 32'sd0, 32'sd32768);
		drive_and_check(8, 1'b1, 12'sd256, 15'sd0, 8'd1, 32'sd0, -32'sd32768);
		// 通过强制舍入观察点覆盖24-bit上下端点保护逻辑。
		@(negedge i_clk);
		i_result_valid = 1'b1;
		i_result_ready = 1'b1;
		i_precision_mode = 1'b1;
		force dut.dec_coarse_rounded_code = 43'sd8388608;
		force dut.dec_fine_rounded_code = -43'sd8388609;
		@(posedge i_clk); #1;
		if(o_coarse_ppg_value !== 24'sd8388607 || o_coarse_saturation_high !== 1'b1 ||
			o_fine_ppg_value !== -24'sd8388608 || o_fine_saturation_low !== 1'b1)begin
			error_count = error_count + 1;
			$display("FAIL DCR-09 saturation endpoints");
		end
		release dut.dec_coarse_rounded_code;
		release dut.dec_fine_rounded_code;
		@(negedge i_clk);
		i_result_valid = 1'b0;
		// 9/15/9/15连续切换检查两路资格不会错拍。
		drive_and_check(10, 1'b0, 12'sd260, 15'sd31, 8'd1, 32'sd65536, 32'sd65536);
		drive_and_check(10, 1'b1, 12'sd261, 15'sd32, 8'd2, 32'sd65536, 32'sd65536);
		drive_and_check(10, 1'b0, 12'sd262, 15'sd33, 8'd3, 32'sd65536, 32'sd65536);
		drive_and_check(10, 1'b1, 12'sd263, 15'sd34, 8'd4, 32'sd65536, 32'sd65536);
		// 反压期间所有输出必须保持。
		@(negedge i_clk);
		i_result_ready = 1'b0;
		i_dc9_recovery_gain_q16 = 32'sd65536;
		i_dc15_recovery_gain_q16 = 32'sd65536;
		i_result_valid = 1'b1;
		i_precision_mode = 1'b1;
		i_programmable_15_code = 15'sd123;
		i_dc_code_snapshot = 8'd4;
		@(posedge i_clk); #1;
		if(o_result_valid !== 1'b1 || o_fine_ppg_value !== 24'sd127)begin
			error_count = error_count + 1;
			$display("FAIL DCR-15 initial hold");
		end
		@(negedge i_clk);
		held_coarse = o_coarse_ppg_value;
		held_fine = o_fine_ppg_value;
		held_dc_code = o_dc_code_snapshot;
		i_programmable_15_code = -15'sd321;
		i_dc_code_snapshot = 8'd7;
		i_dc9_recovery_gain_q16 = -32'sd123456;
		i_dc15_recovery_gain_q16 = 32'sd7654321;
		i_dc_recovery_coef_epoch = 8'hff;
		i_config_epoch = 8'hfe;
		i_amb_code_snapshot = 8'hee;
		@(posedge i_clk); #1;
		if(o_result_valid !== 1'b1 || o_coarse_ppg_value !== held_coarse ||
			o_fine_ppg_value !== held_fine || o_dc_code_snapshot !== held_dc_code ||
			o_dc_recovery_coef_epoch !== 8'h2a || o_config_epoch !== 8'h11)begin
			error_count = error_count + 1;
			$display("FAIL DCR-15/17 backpressure hold");
		end
		@(negedge i_clk);
		i_result_ready = 1'b1;
		i_result_valid = 1'b0;
		@(posedge i_clk); #1;
		if(o_result_valid !== 1'b0)begin
			error_count = error_count + 1;
			$display("FAIL DCR-16 consume");
		end
		// 下游消费旧事务的同一拍直接装入新事务，valid不得出现空拍。
		@(negedge i_clk);
		i_result_ready = 1'b0;
		i_result_valid = 1'b1;
		i_precision_mode = 1'b1;
		i_programmable_15_code = 15'sd200;
		i_calibrated_s1_value = 12'sd256;
		i_dc_code_snapshot = 8'd1;
		i_dc9_recovery_gain_q16 = 32'sd65536;
		i_dc15_recovery_gain_q16 = 32'sd65536;
		i_config_epoch = 8'ha0;
		i_dc_recovery_coef_epoch = 8'h10;
		@(posedge i_clk); #1;
		@(negedge i_clk);
		calculate_model(1'b1, 12'sd257, 15'sd300, 8'd2, 32'sd65536, 32'sd65536);
		i_result_ready = 1'b1;
		i_result_valid = 1'b1;
		i_calibrated_s1_value = 12'sd257;
		i_programmable_15_code = 15'sd300;
		i_dc_code_snapshot = 8'd2;
		i_config_epoch = 8'ha1;
		i_dc_recovery_coef_epoch = 8'h11;
		@(posedge i_clk); #1;
		if(o_result_valid !== 1'b1 || o_coarse_ppg_value !== expected_coarse ||
			o_fine_ppg_value !== expected_fine || o_config_epoch !== 8'ha1 ||
			o_dc_recovery_coef_epoch !== 8'h11)begin
			error_count = error_count + 1;
			$display("FAIL DCR-16 same-cycle replace");
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;
		@(posedge i_clk); #1;
		// 上游Stage1/Stage2饱和诊断必须保留，不得丢弃事务。
		i_stage1_saturation_low = 1'b1;
		i_stage1_saturation_high = 1'b0;
		i_programmable_saturation_low = 1'b0;
		i_programmable_saturation_high = 1'b1;
		drive_and_check(14, 1'b1, 12'sd270, 15'sd400, 8'd3, 32'sd65536, 32'sd65536);
		i_stage1_saturation_low = 1'b0;
		i_programmable_saturation_high = 1'b0;
		// 所有epoch按bit pattern透传，数值回绕不参与资格推导。
		i_config_epoch = 8'hff;
		i_coef_epoch = 8'hff;
		i_stage2_coef_epoch = 8'hff;
		i_dc_recovery_coef_epoch = 8'hff;
		drive_and_check(18, 1'b1, 12'sd271, 15'sd401, 8'd4, 32'sd65536, 32'sd65536);
		i_config_epoch = 8'h00;
		i_coef_epoch = 8'h00;
		i_stage2_coef_epoch = 8'h00;
		i_dc_recovery_coef_epoch = 8'h00;
		drive_and_check(18, 1'b1, 12'sd272, 15'sd402, 8'd5, 32'sd65536, 32'sd65536);
		// AMB码变化只能改变透传字段，不能改变粗细恢复算术。
		i_amb_code_snapshot = 8'h01;
		drive_and_check(19, 1'b1, 12'sd280, 15'sd500, 8'd6, 32'sd65536, 32'sd65536);
		held_coarse = o_coarse_ppg_value;
		held_fine = o_fine_ppg_value;
		i_amb_code_snapshot = 8'hfe;
		i_amb_code_epoch = 4'hf;
		drive_and_check(19, 1'b1, 12'sd280, 15'sd500, 8'd6, 32'sd65536, 32'sd65536);
		if(o_coarse_ppg_value !== held_coarse || o_fine_ppg_value !== held_fine)begin
			error_count = error_count + 1;
			$display("FAIL DCR-19 AMB entered arithmetic");
		end
		// 红光和红外共享精度系数，但必须各自使用事务中的DC快照。
		i_color_ir = 1'b0;
		i_frame_id = 16'h2000;
		drive_and_check(20, 1'b1, 12'sd290, 15'sd600, 8'd2, 32'sd65536, 32'sd65536);
		i_color_ir = 1'b1;
		i_frame_id = 16'h2000;
		drive_and_check(20, 1'b1, 12'sd290, 15'sd600, 8'd9, 32'sd65536, 32'sd65536);
		// 选取同一公共标度码，验证粗结果与精细结果不存在固定模式台阶。
		i_color_ir = 1'b0;
		drive_and_check(21, 1'b0, 12'sd256, 15'sd27, 8'd4, 32'sd65536, 32'sd65536);
		drive_and_check(21, 1'b1, 12'sd256, 15'sd27, 8'd4, 32'sd65536, 32'sd65536);
		if(o_coarse_ppg_value !== o_fine_ppg_value)begin
			error_count = error_count + 1;
			$display("FAIL DCR-21 cross-mode alignment");
		end
		// 非NORMAL输入属于上游集成错误，TB识别后只检查协议字段透传。
		@(negedge i_clk);
		i_frame_type = 2'b01;
		i_result_ready = 1'b1;
		i_result_valid = 1'b1;
		@(posedge i_clk); #1;
		if(o_result_valid !== 1'b1 || o_frame_type !== 2'b01)begin
			error_count = error_count + 1;
			$display("FAIL DCR-22 protocol observation");
		end else begin
			$display("PASS DCR-22 non-NORMAL protocol error detected by TB");
		end
		@(negedge i_clk);
		i_result_valid = 1'b0;
		i_frame_type = 2'b10;
		@(negedge i_clk);
		i_rstn = 1'b0;
		#1;
		if(o_result_valid !== 1'b0 || o_result_ready !== 1'b0)begin
			error_count = error_count + 1;
			$display("FAIL DCR-01 asynchronous reset");
		end
		if(error_count == 0)begin
			$display("PASS ppg_adc_dc_recovery DCR-01..DCR-22");
		end else begin
			$display("FAIL ppg_adc_dc_recovery errors=%0d", error_count);
		end
		#20 $finish;
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
