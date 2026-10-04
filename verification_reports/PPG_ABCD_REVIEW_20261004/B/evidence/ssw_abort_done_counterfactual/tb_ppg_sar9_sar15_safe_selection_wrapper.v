`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Codex
// Create Date:     2026-08-15
// Design Name:     PPG SAR9/SAR15 Safe Selection Wrapper Testbench
// Module Name:     tb_ppg_sar9_sar15_safe_selection_wrapper
// Description:     Self-checking SSW-01 through SSW-52 for the V1.3.2 waveform, ADC-owner, and characterization qualifications.
// Simulations:     tb_ppg_sar9_sar15_safe_selection_wrapper
// Referrences:     PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
// Dependencies:    ppg_sar9_sar15_safe_selection_wrapper.v
// Version:         V1.5
// Revision Date:   2026-09-10
// History:
// 2026-08-15       V1.3.1      Codex       Add independent waveform and ADC-owner regression.
// 2026-08-24       V1.4        Erie        Re-run this self-check against the current (V1.4) SSW RTL before depending on it for C01 TOP-20 integration evidence. This TB predated the DUT's V1.4 addition of i_run_generation, so the port was left entirely undeclared and floated at the DUT instantiation; unlike the scheduler's equivalent V1.4 gap (17 of 57 cases silently passed with a stale value), here every owner-identity match/release expression that depends on i_run_generation compares against an undriven net, and iverilog leaves an unconnected input floating as an indeterminate value rather than a clean constant, so the regression failed loudly and overtly (pass=12, error=109, FATAL) the first time it was actually run this session rather than passing quietly. Fixed by adding the C_RUN_GENERATION_WIDTH parameter, declaring/connecting i_run_generation, and driving it at a fixed constant in set_defaults; none of SSW-01 through SSW-52 exercise stale-generation rejection, so that remains a coverage gap, not newly added here. The new o_ssw_fault_* register group added alongside i_run_generation in RTL V1.4 is also not yet connected or asserted on by this TB; that is a separate, still-open coverage gap left for a future pass, not fixed here. All 52/52 pass after the fix.
// 2026-09-10       V1.5        Erie        DUT V1.5 stopped driving CTRL_Q2 during AMB_CAL (single-phase integration, contract 6.4). Extended SSW-08 with explicit o_clk_q2_low==0 checks at local tick 262/263/266, extended the SSW-11 all-subframe sweep to assert !o_clk_q2_low at every tick from 2 to 283, and extended SSW-09/SSW-10 with o_clk_q2_low==1 checks at 262/263 to prove DCS_CAL keeps driving Q2 unchanged. All 52/52 still pass.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Codex
// 创建日期:        2026年08月15日
// 设计名称:        PPG SAR9/SAR15 Safe Selection Wrapper Testbench
// 模块名称:        tb_ppg_sar9_sar15_safe_selection_wrapper
// 模块说明:        V1.4波形上下文与ADC所有权分离自检TB，补上RUN代际端口。
// 仿真工程:        tb_ppg_sar9_sar15_safe_selection_wrapper
// 参考资料:        PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
// 依赖文件:        ppg_sar9_sar15_safe_selection_wrapper.v
// 当前版本:        V1.5
// 修订日期:        2026年09月10日
// 修订历史:
// 2026-08-15       V1.3      Codex       增加SSW-01至SSW-48独立通道回归。
// 2026-08-24       V1.4      Erie        为准备C01 TOP-20整机验收证据，先拿这份自检TB对当前V1.4 SSW RTL重跑一遍。这份TB早于DUT V1.4新增的i_run_generation端口，例化里从未声明也从未连接；和scheduler那次同类缺口不同（scheduler是17/57用旧值静默通过），这里owner身份匹配/释放全部依赖i_run_generation，而iverilog把未连接输入端浮空为不确定值而不是干净常量，导致本轮第一次真正跑这份回归时不是静默通过、而是直接响亮失败（pass=12、error=109、FATAL）。修复：新增C_RUN_GENERATION_WIDTH参数，声明并连接i_run_generation，在set_defaults里给它一个全程固定常量——SSW-01至SSW-52本来就没有一条测试跨代际拒绝，这次只是把浮空端口接上，不是新增覆盖，跨代际拒绝仍是待补覆盖项。RTL V1.4同时新增的o_ssw_fault_*故障记录组，这份TB目前也还没有连接或断言，这是另一个仍然待补的覆盖缺口，本次未修复。修复后52/52全过。
// 2026-09-10       V1.5      Erie        DUT V1.5起AMB_CAL不再驱动CTRL_Q2（单相积分改造，合同6.4节）。扩展SSW-08在local tick 262/263/266三点显式断言o_clk_q2_low为0；扩展SSW-11全子帧遍历循环在tick 2至283每一拍都断言!o_clk_q2_low；扩展SSW-09/SSW-10在262/263两点断言o_clk_q2_low为1，证明DCS_CAL的Q2行为未被改动波及。52/52仍全过。
module tb_ppg_sar9_sar15_safe_selection_wrapper;

	localparam [1:0] FRAME_TYPE_AMB    = 2'b00;
	localparam [1:0] FRAME_TYPE_DCS    = 2'b01;
	localparam [1:0] FRAME_TYPE_NORMAL = 2'b10;
	localparam [1:0] OPTICAL_BOTH      = 2'b00;
	localparam [1:0] OPTICAL_RED       = 2'b01;
	localparam [1:0] OPTICAL_IR        = 2'b10;
	localparam integer C_CLK_PERIOD_NS  = 500;
	localparam integer C_RUN_GENERATION_WIDTH = 8;

	reg i_clk;
	reg i_rstn;
	reg i_run_enable;
	reg i_start_ack_event;
	reg i_stop_ack_event;
	reg i_control_abort_event;
	reg i_diag_clear_event;
	reg [C_RUN_GENERATION_WIDTH - 1:0] i_run_generation;
	reg [12:0] i_macro_tick;
	reg [2:0] i_calibration_subframe_index;
	reg [9:0] i_calibration_local_tick;
	reg i_normal_frame_active;
	reg i_calibration_frame_active;
	reg i_macro_frame_safe_boundary;
	reg i_idac_code_safe_boundary;
	reg i_run_profile;
	reg i_input_source;
	reg [1:0] i_optical_mode;
	reg i_precision_mode_committed;
	reg i_static_characterization_enable;
	reg [4:0] i_test_mux_ctrl;
	reg i_waveform_context_valid;
	reg i_waveform_precision_mode;
	reg [15:0] i_waveform_frame_id;
	reg i_waveform_color_ir;
	reg [1:0] i_waveform_frame_type;
	reg [7:0] i_waveform_amb_code_snapshot;
	reg [7:0] i_waveform_dc_code_snapshot;
	reg [3:0] i_waveform_amb_code_epoch;
	reg [3:0] i_waveform_dc_code_epoch;
	reg i_waveform_input_source;
	reg [1:0] i_waveform_optical_mode;
	reg [7:0] i_waveform_leddac_code_snapshot;
	reg i_adc_owner_commit_event;
	reg i_adc_owner_precision_mode;
	reg [15:0] i_adc_owner_frame_id;
	reg i_adc_owner_color_ir;
	reg [1:0] i_adc_owner_frame_type;
	reg [7:0] i_adc_owner_amb_code_snapshot;
	reg [7:0] i_adc_owner_dc_code_snapshot;
	reg [3:0] i_adc_owner_amb_code_epoch;
	reg [3:0] i_adc_owner_dc_code_epoch;
	reg [15:0] i_adc_owner_sample_index;
	reg i_adc_transaction_complete_event;
	reg i_adc_transaction_success;
	reg [15:0] i_adc_complete_sample_index;
	reg i_adc_idle;

	wire o_waveform_context_ready;
	wire o_adc_owner_ready;
	wire o_en_tia_low;
	wire [7:0] o_leddac;
	wire o_leden1_low;
	wire o_leden2_low;
	wire o_en_test;
	wire o_clk_buf_low;
	wire o_clk_iref_idac_low;
	wire o_clk_9q1_low;
	wire o_clk_15q1_low;
	wire o_clk_aferst_low;
	wire o_clk_iref_idac_sar9_low;
	wire o_clk_iref_idac_sar15_low;
	wire o_clk_q2_low;
	wire o_clk_q3_low;
	wire o_clk_tiaen_low;
	wire o_en_15sar_low;
	wire o_en_sar9_amb_low;
	wire o_en_sar9_dc_low;
	wire o_en_sar9_iref;
	wire o_en_sar15_amb_low;
	wire o_en_sar15_dc_low;
	wire o_en_sar15_iref;
	wire [7:0] o_idac_sar9ambn_low;
	wire [7:0] o_idac_sar9dcn_low;
	wire [7:0] o_idac_sar15ambn_low;
	wire [7:0] o_idac_sar15dcn_low;
	wire [4:0] o_s_in;
	wire o_clk_2m;
	wire o_analog_safe;
	wire o_sar_timing_idle;
	wire o_wrapper_idle;
	wire o_precision_active;
	wire o_calibration_wave_active;
	wire o_adc_owner_inflight;
	wire o_switch_protocol_error_sticky;
	wire o_transaction_mismatch_sticky;
	wire o_owner_deadline_timeout_sticky;
	wire o_calibration_timeout_sticky;
	wire o_wrapper_fault_blocking;

	integer cnt_error;
	integer cnt_pass;
	integer cnt_case_error;
	integer cnt_tick;
	integer cnt_subframe;
	reg flag_clock_mismatch;
	reg [7:0] reg_first_amb_code;

	ppg_sar9_sar15_safe_selection_wrapper dut(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_run_enable(i_run_enable),
		.i_start_ack_event(i_start_ack_event),
		.i_stop_ack_event(i_stop_ack_event),
		.i_control_abort_event(i_control_abort_event),
		.i_diag_clear_event(i_diag_clear_event),
		.i_run_generation(i_run_generation),
		.i_macro_tick(i_macro_tick),
		.i_calibration_subframe_index(i_calibration_subframe_index),
		.i_calibration_local_tick(i_calibration_local_tick),
		.i_normal_frame_active(i_normal_frame_active),
		.i_calibration_frame_active(i_calibration_frame_active),
		.i_macro_frame_safe_boundary(i_macro_frame_safe_boundary),
		.i_idac_code_safe_boundary(i_idac_code_safe_boundary),
		.i_run_profile(i_run_profile),
		.i_input_source(i_input_source),
		.i_optical_mode(i_optical_mode),
		.i_precision_mode_committed(i_precision_mode_committed),
		.i_static_characterization_enable(i_static_characterization_enable),
		.i_test_mux_ctrl(i_test_mux_ctrl),
		.i_waveform_context_valid(i_waveform_context_valid),
		.o_waveform_context_ready(o_waveform_context_ready),
		.i_waveform_precision_mode(i_waveform_precision_mode),
		.i_waveform_frame_id(i_waveform_frame_id),
		.i_waveform_color_ir(i_waveform_color_ir),
		.i_waveform_frame_type(i_waveform_frame_type),
		.i_waveform_amb_code_snapshot(i_waveform_amb_code_snapshot),
		.i_waveform_dc_code_snapshot(i_waveform_dc_code_snapshot),
		.i_waveform_amb_code_epoch(i_waveform_amb_code_epoch),
		.i_waveform_dc_code_epoch(i_waveform_dc_code_epoch),
		.i_waveform_input_source(i_waveform_input_source),
		.i_waveform_optical_mode(i_waveform_optical_mode),
		.i_waveform_leddac_code_snapshot(i_waveform_leddac_code_snapshot),
		.o_adc_owner_ready(o_adc_owner_ready),
		.i_adc_owner_commit_event(i_adc_owner_commit_event),
		.i_adc_owner_precision_mode(i_adc_owner_precision_mode),
		.i_adc_owner_frame_id(i_adc_owner_frame_id),
		.i_adc_owner_color_ir(i_adc_owner_color_ir),
		.i_adc_owner_frame_type(i_adc_owner_frame_type),
		.i_adc_owner_amb_code_snapshot(i_adc_owner_amb_code_snapshot),
		.i_adc_owner_dc_code_snapshot(i_adc_owner_dc_code_snapshot),
		.i_adc_owner_amb_code_epoch(i_adc_owner_amb_code_epoch),
		.i_adc_owner_dc_code_epoch(i_adc_owner_dc_code_epoch),
		.i_adc_owner_sample_index(i_adc_owner_sample_index),
		.i_adc_transaction_complete_event(i_adc_transaction_complete_event),
		.i_adc_transaction_success(i_adc_transaction_success),
		.i_adc_complete_sample_index(i_adc_complete_sample_index),
		.i_adc_idle(i_adc_idle),
		.o_en_tia_low(o_en_tia_low),
		.o_leddac(o_leddac),
		.o_leden1_low(o_leden1_low),
		.o_leden2_low(o_leden2_low),
		.o_en_test(o_en_test),
		.o_clk_buf_low(o_clk_buf_low),
		.o_clk_iref_idac_low(o_clk_iref_idac_low),
		.o_clk_9q1_low(o_clk_9q1_low),
		.o_clk_15q1_low(o_clk_15q1_low),
		.o_clk_aferst_low(o_clk_aferst_low),
		.o_clk_iref_idac_sar9_low(o_clk_iref_idac_sar9_low),
		.o_clk_iref_idac_sar15_low(o_clk_iref_idac_sar15_low),
		.o_clk_q2_low(o_clk_q2_low),
		.o_clk_q3_low(o_clk_q3_low),
		.o_clk_tiaen_low(o_clk_tiaen_low),
		.o_en_15sar_low(o_en_15sar_low),
		.o_en_sar9_amb_low(o_en_sar9_amb_low),
		.o_en_sar9_dc_low(o_en_sar9_dc_low),
		.o_en_sar9_iref(o_en_sar9_iref),
		.o_en_sar15_amb_low(o_en_sar15_amb_low),
		.o_en_sar15_dc_low(o_en_sar15_dc_low),
		.o_en_sar15_iref(o_en_sar15_iref),
		.o_idac_sar9ambn_low(o_idac_sar9ambn_low),
		.o_idac_sar9dcn_low(o_idac_sar9dcn_low),
		.o_idac_sar15ambn_low(o_idac_sar15ambn_low),
		.o_idac_sar15dcn_low(o_idac_sar15dcn_low),
		.o_s_in(o_s_in),
		.o_clk_2m(o_clk_2m),
		.o_analog_safe(o_analog_safe),
		.o_sar_timing_idle(o_sar_timing_idle),
		.o_wrapper_idle(o_wrapper_idle),
		.o_precision_active(o_precision_active),
		.o_calibration_wave_active(o_calibration_wave_active),
		.o_adc_owner_inflight(o_adc_owner_inflight),
		.o_switch_protocol_error_sticky(o_switch_protocol_error_sticky),
		.o_transaction_mismatch_sticky(o_transaction_mismatch_sticky),
		.o_owner_deadline_timeout_sticky(o_owner_deadline_timeout_sticky),
		.o_calibration_timeout_sticky(o_calibration_timeout_sticky),
		.o_wrapper_fault_blocking(o_wrapper_fault_blocking)
	);

	always #(C_CLK_PERIOD_NS / 2) i_clk = ~i_clk;

	always@(i_clk or o_clk_2m) begin
		if(o_clk_2m !== i_clk) begin
			flag_clock_mismatch = 1'b1;
		end
	end

	// 测试平台基础输入在每个场景开始前恢复到确定的协议初值。
	task set_defaults;
	begin
		i_run_enable = 1'b0;
		i_start_ack_event = 1'b0;
		i_stop_ack_event = 1'b0;
		i_control_abort_event = 1'b0;
		i_diag_clear_event = 1'b0;
		i_run_generation = {{(C_RUN_GENERATION_WIDTH - 1){1'b0}}, 1'b1};
		i_macro_tick = 13'd0;
		i_calibration_subframe_index = 3'd0;
		i_calibration_local_tick = 10'd0;
		i_normal_frame_active = 1'b0;
		i_calibration_frame_active = 1'b0;
		i_macro_frame_safe_boundary = 1'b0;
		i_idac_code_safe_boundary = 1'b0;
		i_run_profile = 1'b0;
		i_input_source = 1'b0;
		i_optical_mode = OPTICAL_BOTH;
		i_precision_mode_committed = 1'b0;
		i_static_characterization_enable = 1'b0;
		i_test_mux_ctrl = 5'b10101;
		i_waveform_context_valid = 1'b0;
		i_waveform_precision_mode = 1'b0;
		i_waveform_frame_id = 16'd1;
		i_waveform_color_ir = 1'b0;
		i_waveform_frame_type = FRAME_TYPE_NORMAL;
		i_waveform_amb_code_snapshot = 8'h31;
		i_waveform_dc_code_snapshot = 8'h41;
		i_waveform_amb_code_epoch = 4'h1;
		i_waveform_dc_code_epoch = 4'h2;
		i_waveform_input_source = 1'b0;
		i_waveform_optical_mode = OPTICAL_BOTH;
		i_waveform_leddac_code_snapshot = 8'hA1;
		i_adc_owner_commit_event = 1'b0;
		i_adc_owner_precision_mode = 1'b0;
		i_adc_owner_frame_id = 16'd1;
		i_adc_owner_color_ir = 1'b0;
		i_adc_owner_frame_type = FRAME_TYPE_NORMAL;
		i_adc_owner_amb_code_snapshot = 8'h31;
		i_adc_owner_dc_code_snapshot = 8'h41;
		i_adc_owner_amb_code_epoch = 4'h1;
		i_adc_owner_dc_code_epoch = 4'h2;
		i_adc_owner_sample_index = 16'd1;
		i_adc_transaction_complete_event = 1'b0;
		i_adc_transaction_success = 1'b1;
		i_adc_complete_sample_index = 16'd0;
		i_adc_idle = 1'b1;
	end
	endtask

	// 复位后提交一次启动确认，使封装进入可接受波形上下文的运行态。
	task reset_and_start;
	begin
		@(negedge i_clk);
		i_rstn = 1'b0;
		set_defaults;
		repeat(2) @(posedge i_clk);
		@(negedge i_clk);
		i_rstn = 1'b1;
		i_run_enable = 1'b1;
		i_start_ack_event = 1'b1;
		@(posedge i_clk);
		#1 i_start_ack_event = 1'b0;
	end
	endtask

	// 开始一个带独立编号的验收场景并清零该场景错误计数。
	task begin_case;
		input [8 * 8 - 1:0] case_id;
	begin
		cnt_case_error = 0;
		$display("[%0t] BEGIN %0s", $time, case_id);
	end
	endtask

	// 比较一个协议断言并将失败同时计入场景和总回归结果。
	task expect_true;
		input condition;
		input [8 * 128 - 1:0] message;
	begin
		if(condition !== 1'b1) begin
			cnt_error = cnt_error + 1;
			cnt_case_error = cnt_case_error + 1;
			$display("[%0t] FAIL: %0s", $time, message);
		end
	end
	endtask

	// 结束场景，只有该场景没有失败断言时才增加通过计数。
	task end_case;
		input [8 * 8 - 1:0] case_id;
	begin
		if(cnt_case_error == 0) begin
			cnt_pass = cnt_pass + 1;
			$display("[%0t] %0s PASS", $time, case_id);
		end else begin
			$display("[%0t] %0s FAIL (%0d checks)", $time, case_id, cnt_case_error);
		end
	end
	endtask

	// 在统一宏帧相位源上推进一个2 MHz宏帧tick并采样输出。
	task macro_tick;
		input [12:0] tick_value;
	begin
		@(negedge i_clk);
		i_macro_tick = tick_value;
		@(posedge i_clk);
		#1;
	end
	endtask

	// 在校准子帧相位源上推进一个local tick并同步IDAC安全边界。
	task cal_tick;
		input [9:0] tick_value;
	begin
		@(negedge i_clk);
		i_calibration_local_tick = tick_value;
		i_idac_code_safe_boundary = (tick_value == 10'd385);
		@(posedge i_clk);
		#1;
	end
	endtask

	// 在固定接管点提交一笔独立模拟波形上下文，不占用ADC owner。
	task send_waveform;
		input precision_mode;
		input color_ir;
		input [1:0] frame_type;
		input [15:0] frame_id;
		input [7:0] amb_code;
		input [7:0] dc_code;
		input [3:0] amb_epoch;
		input [3:0] dc_epoch;
		input [7:0] led_code;
	begin
		i_waveform_precision_mode = precision_mode;
		i_waveform_color_ir = color_ir;
		i_waveform_frame_type = frame_type;
		i_waveform_frame_id = frame_id;
		i_waveform_amb_code_snapshot = amb_code;
		i_waveform_dc_code_snapshot = dc_code;
		i_waveform_amb_code_epoch = amb_epoch;
		i_waveform_dc_code_epoch = dc_epoch;
		i_waveform_input_source = i_input_source;
		i_waveform_optical_mode = i_optical_mode;
		i_waveform_leddac_code_snapshot = led_code;
		i_normal_frame_active = (frame_type == FRAME_TYPE_NORMAL);
		i_calibration_frame_active = (frame_type != FRAME_TYPE_NORMAL);
		i_precision_mode_committed = precision_mode;
		@(negedge i_clk);
		if(frame_type == FRAME_TYPE_NORMAL) begin
			i_macro_tick = color_ir ? 13'd160 : 13'd0;
		end else begin
			i_calibration_local_tick = 10'd0;
		end
		#1;
		expect_true(o_waveform_context_ready, "scheduled waveform context must be ready at its fixed handoff point");
		i_waveform_context_valid = 1'b1;
		@(posedge i_clk);
		#1 i_waveform_context_valid = 1'b0;
	end
	endtask

	// 提交与已锁存波形逐字段匹配的ADC结果owner事务。
	task send_owner;
		input precision_mode;
		input color_ir;
		input [1:0] frame_type;
		input [15:0] frame_id;
		input [15:0] sample_index;
		input [7:0] amb_code;
		input [7:0] dc_code;
		input [3:0] amb_epoch;
		input [3:0] dc_epoch;
	begin
		i_adc_owner_precision_mode = precision_mode;
		i_adc_owner_color_ir = color_ir;
		i_adc_owner_frame_type = frame_type;
		i_adc_owner_frame_id = frame_id;
		i_adc_owner_sample_index = sample_index;
		i_adc_owner_amb_code_snapshot = amb_code;
		i_adc_owner_dc_code_snapshot = dc_code;
		i_adc_owner_amb_code_epoch = amb_epoch;
		i_adc_owner_dc_code_epoch = dc_epoch;
		#1;
		expect_true(o_adc_owner_ready, "matching owner must be ready before the frozen deadline");
		@(negedge i_clk);
		i_adc_owner_commit_event = 1'b1;
		@(posedge i_clk);
		#1;
		i_adc_owner_commit_event = 1'b0;
		expect_true(o_adc_owner_inflight, "accepted owner commit must establish exactly one inflight owner");
	end
	endtask

	// 以sample_index匹配的DONE旁带释放物理owner，分别覆盖success两种结果。
	task complete_owner;
		input [15:0] sample_index;
		input success_value;
	begin
		@(negedge i_clk);
		i_adc_complete_sample_index = sample_index;
		i_adc_transaction_success = success_value;
		i_adc_transaction_complete_event = 1'b1;
		@(posedge i_clk);
		#1 i_adc_transaction_complete_event = 1'b0;
		expect_true(!o_adc_owner_inflight, "matching ADC done must release the physical owner");
	end
	endtask

	// 主回归过程按合同编号顺序执行48个场景，并在全部断言通过后结束仿真。
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
