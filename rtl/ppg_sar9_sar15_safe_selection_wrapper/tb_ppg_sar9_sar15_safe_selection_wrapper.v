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
// Version:         V1.6
// Revision Date:   2026-10-06
// History:
// 2026-08-15       V1.3.1      Codex       Add independent waveform and ADC-owner regression.
// 2026-08-24       V1.4        Erie        Re-run this self-check against the current (V1.4) SSW RTL before depending on it for C01 TOP-20 integration evidence. This TB predated the DUT's V1.4 addition of i_run_generation, so the port was left entirely undeclared and floated at the DUT instantiation; unlike the scheduler's equivalent V1.4 gap (17 of 57 cases silently passed with a stale value), here every owner-identity match/release expression that depends on i_run_generation compares against an undriven net, and iverilog leaves an unconnected input floating as an indeterminate value rather than a clean constant, so the regression failed loudly and overtly (pass=12, error=109, FATAL) the first time it was actually run this session rather than passing quietly. Fixed by adding the C_RUN_GENERATION_WIDTH parameter, declaring/connecting i_run_generation, and driving it at a fixed constant in set_defaults; none of SSW-01 through SSW-52 exercise stale-generation rejection, so that remains a coverage gap, not newly added here. The new o_ssw_fault_* register group added alongside i_run_generation in RTL V1.4 is also not yet connected or asserted on by this TB; that is a separate, still-open coverage gap left for a future pass, not fixed here. All 52/52 pass after the fix.
// 2026-09-10       V1.5        Erie        DUT V1.5 stopped driving CTRL_Q2 during AMB_CAL (single-phase integration, contract 6.4). Extended SSW-08 with explicit o_clk_q2_low==0 checks at local tick 262/263/266, extended the SSW-11 all-subframe sweep to assert !o_clk_q2_low at every tick from 2 to 283, and extended SSW-09/SSW-10 with o_clk_q2_low==1 checks at 262/263 to prove DCS_CAL keeps driving Q2 unchanged. All 52/52 still pass.
// 2026-10-06       V1.6        Erie        ABCD review F-035: add TB-local case ABT-DONE (no SSW-nn number taken): abort and a matching DONE in the same cycle must release the owner while the RED waveform is still cancelled, the wrapper must go idle, and after STOP, diag clear and a generation-2 START a new owner must be established and released. Pass criterion 52 -> 53; banner unchanged. Negative control: with abort-hold ahead of release (SSW V1.5 order) ABT-DONE fails 6 checks.
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
// 当前版本:        V1.6
// 修订日期:        2026年10月06日
// 修订历史:
// 2026-08-15       V1.3      Codex       增加SSW-01至SSW-48独立通道回归。
// 2026-08-24       V1.4      Erie        为准备C01 TOP-20整机验收证据，先拿这份自检TB对当前V1.4 SSW RTL重跑一遍。这份TB早于DUT V1.4新增的i_run_generation端口，例化里从未声明也从未连接；和scheduler那次同类缺口不同（scheduler是17/57用旧值静默通过），这里owner身份匹配/释放全部依赖i_run_generation，而iverilog把未连接输入端浮空为不确定值而不是干净常量，导致本轮第一次真正跑这份回归时不是静默通过、而是直接响亮失败（pass=12、error=109、FATAL）。修复：新增C_RUN_GENERATION_WIDTH参数，声明并连接i_run_generation，在set_defaults里给它一个全程固定常量——SSW-01至SSW-52本来就没有一条测试跨代际拒绝，这次只是把浮空端口接上，不是新增覆盖，跨代际拒绝仍是待补覆盖项。RTL V1.4同时新增的o_ssw_fault_*故障记录组，这份TB目前也还没有连接或断言，这是另一个仍然待补的覆盖缺口，本次未修复。修复后52/52全过。
// 2026-09-10       V1.5      Erie        DUT V1.5起AMB_CAL不再驱动CTRL_Q2（单相积分改造，合同6.4节）。扩展SSW-08在local tick 262/263/266三点显式断言o_clk_q2_low为0；扩展SSW-11全子帧遍历循环在tick 2至283每一拍都断言!o_clk_q2_low；扩展SSW-09/SSW-10在262/263两点断言o_clk_q2_low为1，证明DCS_CAL的Q2行为未被改动波及。52/52仍全过。
// 2026-10-06       V1.6      Erie        ABCD复核F-035：新增TB本地用例ABT-DONE（不占用SSW编号）：abort与匹配DONE同拍时必须释放owner，同时RED波形仍被撤销，wrapper回到idle；随后STOP、诊断清除、第2代START后必须能建立并释放新owner。判据52改为53，横幅不变。负对照：恢复V1.5的abort保持优先顺序时ABT-DONE有6项失败
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
		.i_adc_transaction_lost_event(1'b0), // owner生命周期轮新增作废输入，既有场景无作废，接地
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
	initial begin
		i_clk = 1'b0;
		i_rstn = 1'b0;
		cnt_error = 0;
		cnt_pass = 0;
		cnt_case_error = 0;
		flag_clock_mismatch = 1'b0;
		set_defaults;

		begin_case("SSW-01");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd101, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd101, 16'd1, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd44);
		expect_true(!o_analog_safe, "SAR9 RED envelope must begin at macro tick 44");
		macro_tick(13'd300);
		expect_true(o_clk_q3_low && o_clk_9q1_low && !o_clk_15q1_low, "SAR9 RED Q3 and Q1 selection must match the netlist profile");
		expect_true(o_leden1_low && !o_leden2_low && o_leddac == 8'hA1, "SAR9 RED must drive only the RED LED snapshot");
		expect_true(o_idac_sar9ambn_low == 8'h31 && o_idac_sar9dcn_low == 8'h41, "SAR9 RED code windows must use the accepted snapshots");
		complete_owner(16'd1, 1'b1);
		macro_tick(13'd317);
		end_case("SSW-01");

		begin_case("SSW-02");
		reset_and_start;
		send_waveform(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd102, 8'h52, 8'h62, 4'h3, 4'h4, 8'hA2);
		macro_tick(13'd1);
		send_owner(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd102, 16'd2, 8'h52, 8'h62, 4'h3, 4'h4);
		macro_tick(13'd27);
		expect_true(!o_analog_safe, "SAR15 RED envelope must begin at macro tick 27");
		macro_tick(13'd300);
		expect_true(o_clk_q3_low && o_clk_15q1_low && !o_clk_9q1_low && o_precision_active, "SAR15 RED must retain Q3=300 and select only SAR15");
		complete_owner(16'd2, 1'b1);
		macro_tick(13'd307);
		end_case("SSW-02");

		begin_case("SSW-03");
		reset_and_start;
		send_waveform(1'b0, 1'b1, FRAME_TYPE_NORMAL, 16'd103, 8'h33, 8'h43, 4'h1, 4'h2, 8'hB3);
		macro_tick(13'd161);
		send_owner(1'b0, 1'b1, FRAME_TYPE_NORMAL, 16'd103, 16'd3, 8'h33, 8'h43, 4'h1, 4'h2);
		macro_tick(13'd204);
		expect_true(!o_analog_safe, "SAR9 IR envelope must begin at macro tick 204");
		macro_tick(13'd460);
		expect_true(o_clk_q3_low && o_clk_9q1_low && o_leden2_low && !o_leden1_low, "SAR9 IR must retain Q3=460 and select only IR LED");
		complete_owner(16'd3, 1'b1);
		macro_tick(13'd477);
		end_case("SSW-03");

		begin_case("SSW-04");
		reset_and_start;
		send_waveform(1'b1, 1'b1, FRAME_TYPE_NORMAL, 16'd104, 8'h54, 8'h64, 4'h3, 4'h4, 8'hB4);
		macro_tick(13'd161);
		send_owner(1'b1, 1'b1, FRAME_TYPE_NORMAL, 16'd104, 16'd4, 8'h54, 8'h64, 4'h3, 4'h4);
		macro_tick(13'd187);
		expect_true(!o_analog_safe, "SAR15 IR envelope must begin at macro tick 187");
		macro_tick(13'd460);
		expect_true(o_clk_q3_low && o_clk_15q1_low && o_leden2_low && !o_leden1_low, "SAR15 IR must retain Q3=460 and select SAR15");
		complete_owner(16'd4, 1'b1);
		macro_tick(13'd467);
		end_case("SSW-04");

		begin_case("SSW-05");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd105, 8'h11, 8'h22, 4'h1, 4'h2, 8'hA5);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd105, 16'd5, 8'h11, 8'h22, 4'h1, 4'h2);
		macro_tick(13'd300);
		expect_true(o_clk_q3_low, "SAR9 RED Q3 must include macro tick 300");
		complete_owner(16'd5, 1'b1);
		macro_tick(13'd317);
		reset_and_start;
		send_waveform(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd106, 8'h11, 8'h22, 4'h1, 4'h2, 8'hA6);
		macro_tick(13'd1);
		send_owner(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd106, 16'd6, 8'h11, 8'h22, 4'h1, 4'h2);
		macro_tick(13'd300);
		expect_true(o_clk_q3_low, "SAR15 RED Q3 must include the same macro tick 300");
		end_case("SSW-05");

		begin_case("SSW-06");
		reset_and_start;
		i_optical_mode = OPTICAL_RED;
		i_waveform_optical_mode = OPTICAL_RED;
		i_normal_frame_active = 1'b1;
		i_macro_tick = 13'd160;
		i_waveform_color_ir = 1'b1;
		i_waveform_context_valid = 1'b1;
		#1 expect_true(!o_waveform_context_ready, "RED-only must not accept IR waveform context");
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		reset_and_start;
		i_optical_mode = OPTICAL_RED;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd107, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA7);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd107, 16'd7, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300);
		expect_true(o_leden1_low && !o_leden2_low, "RED-only must preserve the RED phase without an IR LED window");
		end_case("SSW-06");

		begin_case("SSW-07");
		reset_and_start;
		i_optical_mode = OPTICAL_IR;
		i_waveform_optical_mode = OPTICAL_IR;
		i_normal_frame_active = 1'b1;
		i_macro_tick = 13'd0;
		i_waveform_color_ir = 1'b0;
		i_waveform_context_valid = 1'b1;
		#1 expect_true(!o_waveform_context_ready, "IR-only must not accept RED waveform context");
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		reset_and_start;
		i_optical_mode = OPTICAL_IR;
		send_waveform(1'b0, 1'b1, FRAME_TYPE_NORMAL, 16'd108, 8'h31, 8'h41, 4'h1, 4'h2, 8'hB8);
		macro_tick(13'd161);
		send_owner(1'b0, 1'b1, FRAME_TYPE_NORMAL, 16'd108, 16'd8, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd460);
		expect_true(!o_leden1_low && o_leden2_low, "IR-only must preserve the IR phase without a RED LED window");
		end_case("SSW-07");

		begin_case("SSW-08");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd109, 8'h35, 8'h45, 4'h1, 4'h2, 8'hA9);
		cal_tick(10'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd109, 16'd9, 8'h35, 8'h45, 4'h1, 4'h2);
		cal_tick(10'd262);
		expect_true(!o_clk_q2_low, "AMB_CAL must not drive Q2 at local tick 262 (single-phase integration, V1.5 6.4)");
		cal_tick(10'd263);
		expect_true(!o_clk_q2_low, "AMB_CAL must not drive Q2 at local tick 263 (single-phase integration, V1.5 6.4)");
		cal_tick(10'd266);
		expect_true(o_clk_q3_low && o_calibration_wave_active, "AMB_CAL must use local Q3 tick 266");
		expect_true(!o_clk_q2_low, "AMB_CAL must not drive Q2 while Q3 is asserted at local tick 266");
		expect_true(!o_leden1_low && !o_leden2_low && o_leddac == 8'h00, "AMB_CAL must keep both LEDs and LEDDAC off");
		expect_true(o_idac_sar9ambn_low == 8'h35 && o_idac_sar9dcn_low == 8'h00, "AMB_CAL must use only the SAR9 AMB code window");
		end_case("SSW-08");

		begin_case("SSW-09");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_DCS, 16'd110, 8'h36, 8'h46, 4'h1, 4'h2, 8'hAA);
		cal_tick(10'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_DCS, 16'd110, 16'd10, 8'h36, 8'h46, 4'h1, 4'h2);
		cal_tick(10'd262);
		expect_true(o_clk_q2_low, "DCS_CAL RED must keep driving Q2 at local tick 262 (asymmetric chopping, unaffected by AMB_CAL change)");
		cal_tick(10'd263);
		expect_true(o_clk_q2_low, "DCS_CAL RED must keep driving Q2 at local tick 263 (asymmetric chopping, unaffected by AMB_CAL change)");
		cal_tick(10'd266);
		expect_true(o_clk_q3_low && o_leden1_low && !o_leden2_low, "DCS RED must use local Q3 and only RED LED");
		expect_true(o_idac_sar9ambn_low == 8'h36 && o_idac_sar9dcn_low == 8'h46, "DCS RED must keep AMB and RED DC snapshots stable");
		end_case("SSW-09");

		begin_case("SSW-10");
		reset_and_start;
		send_waveform(1'b0, 1'b1, FRAME_TYPE_DCS, 16'd111, 8'h37, 8'h47, 4'h1, 4'h2, 8'hBB);
		cal_tick(10'd1);
		send_owner(1'b0, 1'b1, FRAME_TYPE_DCS, 16'd111, 16'd11, 8'h37, 8'h47, 4'h1, 4'h2);
		cal_tick(10'd262);
		expect_true(o_clk_q2_low, "DCS_CAL IR must keep driving Q2 at local tick 262 (asymmetric chopping, unaffected by AMB_CAL change)");
		cal_tick(10'd263);
		expect_true(o_clk_q2_low, "DCS_CAL IR must keep driving Q2 at local tick 263 (asymmetric chopping, unaffected by AMB_CAL change)");
		cal_tick(10'd266);
		expect_true(o_clk_q3_low && !o_leden1_low && o_leden2_low, "DCS IR must use local Q3 and only IR LED");
		expect_true(o_idac_sar9ambn_low == 8'h37 && o_idac_sar9dcn_low == 8'h47, "DCS IR must keep AMB and IR DC snapshots stable");
		end_case("SSW-10");

		begin_case("SSW-11");
		reset_and_start;
		for(cnt_subframe = 0; cnt_subframe < 8; cnt_subframe = cnt_subframe + 1) begin
			i_calibration_subframe_index = cnt_subframe[2:0];
			send_waveform(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd120 + cnt_subframe, 8'h38, 8'h00, 4'h1, 4'h0, 8'h00);
			cal_tick(10'd1);
			send_owner(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd120 + cnt_subframe, 16'd20 + cnt_subframe, 8'h38, 8'h00, 4'h1, 4'h0);
			for(cnt_tick = 2; cnt_tick < 284; cnt_tick = cnt_tick + 1) begin
				cal_tick(cnt_tick[9:0]);
				if(cnt_tick == 266) begin
					expect_true(o_clk_q3_low, "every calibration subframe must place Q3 at local tick 266");
				end
				expect_true(!o_clk_q2_low, "AMB_CAL must never drive Q2 at any local tick across all 8 subframes (V1.5 6.4)");
			end
			complete_owner(16'd20 + cnt_subframe, 1'b1);
			cal_tick(10'd284);
		end
		end_case("SSW-11");

		begin_case("SSW-12");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_DCS, 16'd112, 8'h56, 8'h78, 4'h1, 4'h2, 8'hAC);
		cal_tick(10'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_DCS, 16'd112, 16'd12, 8'h56, 8'h78, 4'h1, 4'h2);
		i_waveform_amb_code_snapshot = 8'h9A;
		i_waveform_dc_code_snapshot = 8'hBC;
		cal_tick(10'd266);
		expect_true(o_idac_sar9ambn_low == 8'h56 && o_idac_sar9dcn_low == 8'h78, "current calibration subframe must ignore post-handoff code updates");
		end_case("SSW-12");

		begin_case("SSW-13");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd113, 8'h19, 8'h2A, 4'h1, 4'h2, 8'hAD);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd113, 16'd13, 8'h19, 8'h2A, 4'h1, 4'h2);
		i_waveform_amb_code_snapshot = 8'hE1;
		i_waveform_dc_code_snapshot = 8'hE2;
		i_waveform_leddac_code_snapshot = 8'hE3;
		macro_tick(13'd300);
		expect_true(o_idac_sar9ambn_low == 8'h19 && o_idac_sar9dcn_low == 8'h2A && o_leddac == 8'hAD, "preheat updates must not contaminate the accepted waveform snapshot");
		end_case("SSW-13");

		begin_case("SSW-14");
		reset_and_start;
		i_normal_frame_active = 1'b1;
		i_macro_tick = 13'd1;
		i_waveform_context_valid = 1'b1;
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		expect_true(o_switch_protocol_error_sticky && !o_clk_q3_low, "late waveform context must be rejected without moving Q3");
		end_case("SSW-14");

		begin_case("SSW-15");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd115, 8'h31, 8'h41, 4'h1, 4'h2, 8'hAF);
		macro_tick(13'd160);
		i_waveform_color_ir = 1'b1;
		i_waveform_frame_id = 16'd116;
		i_waveform_context_valid = 1'b1;
		#1 expect_true(o_waveform_context_ready && !o_adc_owner_inflight, "AMI backpressure must not block the independent IR waveform handoff");
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		end_case("SSW-15");

		begin_case("SSW-16");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd116, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd116, 16'd16, 8'h31, 8'h41, 4'h1, 4'h2);
		complete_owner(16'd16, 1'b1);
		macro_tick(13'd317);
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd117, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd117, 16'd17, 8'h31, 8'h41, 4'h1, 4'h2);
		complete_owner(16'd17, 1'b0);
		expect_true(!o_transaction_mismatch_sticky, "matching success=0 completion must release without becoming a mismatch");
		end_case("SSW-16");

		begin_case("SSW-17");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd117, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd117, 16'd18, 8'h31, 8'h41, 4'h1, 4'h2);
		@(negedge i_clk); i_adc_complete_sample_index = 16'hDEAD; i_adc_transaction_complete_event = 1'b1;
		@(posedge i_clk); #1 i_adc_transaction_complete_event = 1'b0;
		expect_true(o_transaction_mismatch_sticky && o_adc_owner_inflight && o_wrapper_fault_blocking, "mismatched DONE must preserve owner and raise a blocking diagnostic");
		end_case("SSW-17");

		begin_case("SSW-18");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd118, 8'h31, 8'h00, 4'h1, 4'h0, 8'h00);
		expect_true(dut.flag_cal_context_valid, "calibration context must remain valid while its owner is pending");
		cal_tick(10'd249);
		expect_true(o_owner_deadline_timeout_sticky, "missing calibration owner must time out before the local tick-249 back-end window");
		end_case("SSW-18");

		begin_case("SSW-19");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd119, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd119, 16'd19, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300); expect_true(o_clk_9q1_low && !o_clk_15q1_low, "SAR9 phase must not double-drive SAR15");
		complete_owner(16'd19, 1'b1); macro_tick(13'd317);
		reset_and_start;
		send_waveform(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd120, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd120, 16'd20, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300); expect_true(!o_clk_9q1_low && o_clk_15q1_low, "SAR15 handoff must have no SAR9 double drive");
		end_case("SSW-19");

		begin_case("SSW-20");
		reset_and_start;
		send_waveform(1'b1, 1'b1, FRAME_TYPE_NORMAL, 16'd121, 8'h31, 8'h41, 4'h1, 4'h2, 8'hB1);
		macro_tick(13'd161); send_owner(1'b1, 1'b1, FRAME_TYPE_NORMAL, 16'd121, 16'd21, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd460); expect_true(!o_clk_9q1_low && o_clk_15q1_low, "SAR15 IR must select exactly one Q1 path");
		complete_owner(16'd21, 1'b1); macro_tick(13'd467);
		reset_and_start;
		send_waveform(1'b0, 1'b1, FRAME_TYPE_NORMAL, 16'd122, 8'h31, 8'h41, 4'h1, 4'h2, 8'hB2);
		macro_tick(13'd161); send_owner(1'b0, 1'b1, FRAME_TYPE_NORMAL, 16'd122, 16'd22, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd460); expect_true(o_clk_9q1_low && !o_clk_15q1_low && o_clk_q3_low, "SAR15 to SAR9 must preserve Q3 placement and isolate Q1");
		end_case("SSW-20");

		begin_case("SSW-21");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd123, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd123, 16'd23, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300);
		@(negedge i_clk); i_stop_ack_event = 1'b1;
		@(posedge i_clk); #1 i_stop_ack_event = 1'b0;
		expect_true(o_clk_q3_low, "STOP must not truncate an already active Q3 window");
		complete_owner(16'd23, 1'b1); macro_tick(13'd317);
		expect_true(!o_waveform_context_ready && o_wrapper_idle, "STOP must drain then reject new starts");
		end_case("SSW-21");

		begin_case("SSW-22");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd124, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd124, 16'd24, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300);
		@(negedge i_clk); i_control_abort_event = 1'b1;
		@(posedge i_clk); #1 i_control_abort_event = 1'b0;
		expect_true(!o_clk_q3_low && o_analog_safe && o_adc_owner_inflight, "abort must cancel waveform while retaining minimal owner release identity");
		complete_owner(16'd24, 1'b0);
		expect_true(!o_clk_q3_low, "late abort completion must only release owner and must not reactivate timing");
		end_case("SSW-22");

		begin_case("SSW-23");
		reset_and_start;
		send_waveform(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd125, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd125, 16'd25, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300);
		@(negedge i_clk); i_rstn = 1'b0;
		#1 expect_true(!o_clk_q3_low && !o_en_15sar_low && !o_leden1_low && !o_leden2_low && !o_adc_owner_inflight, "reset must invalidate owner identity and drive the safe output vector");
		end_case("SSW-23");

		begin_case("SSW-24");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b1;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd126, 8'h55, 8'h66, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd126, 16'd26, 8'h55, 8'h66, 4'h1, 4'h2);
		macro_tick(13'd300);
		expect_true(o_en_test && !o_leden1_low && !o_leden2_low && o_leddac == 8'h00, "fixed-current SAR9 must select input test path and suppress LED drive");
		expect_true(o_clk_9q1_low && o_clk_q3_low, "fixed-current SAR9 must keep the normal intermittent SAR timing");
		end_case("SSW-24");

		begin_case("SSW-25");
		repeat(20) @(posedge i_clk);
		expect_true(!flag_clock_mismatch, "o_clk_2m must remain identical to i_clk without gating");
		end_case("SSW-25");

		begin_case("SSW-26");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd127, 8'hA5, 8'h00, 4'h1, 4'h0, 8'h00);
		cal_tick(10'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd127, 16'd27, 8'hA5, 8'h00, 4'h1, 4'h0);
		for(cnt_tick = 10; cnt_tick < 284; cnt_tick = cnt_tick + 1) begin
			cal_tick(cnt_tick[9:0]);
			if((cnt_tick < 224) || (cnt_tick >= 276)) begin
				expect_true(o_idac_sar9ambn_low == 8'h00, "AMB code must remain zero outside [224,276)");
			end
			if((cnt_tick >= 265) && (cnt_tick < 267)) begin
				expect_true(o_clk_q3_low, "AMB Q3 window must include ticks 265 and 266");
			end
		end
		end_case("SSW-26");

		begin_case("SSW-27");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd128, 8'hA5, 8'h00, 4'h1, 4'h0, 8'h00);
		cal_tick(10'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd128, 16'd28, 8'hA5, 8'h00, 4'h1, 4'h0);
		i_waveform_amb_code_snapshot = 8'h5A;
		cal_tick(10'd224); expect_true(o_idac_sar9ambn_low == 8'hA5, "AMB lower code window edge must use the tick-zero snapshot");
		cal_tick(10'd276); expect_true(o_idac_sar9ambn_low == 8'h00, "AMB upper code window edge must be exclusive");
		end_case("SSW-27");

		begin_case("SSW-28");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd129, 8'h3C, 8'h99, 4'h1, 4'h2, 8'hFF);
		cal_tick(10'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd129, 16'd29, 8'h3C, 8'h99, 4'h1, 4'h2);
		cal_tick(10'd266);
		expect_true(!o_en_test && !o_leden1_low && !o_leden2_low && o_leddac == 8'h00, "AMB input boundary must retain photodiode selection and LEDs off");
		expect_true(!o_en_sar9_dc_low && o_idac_sar9dcn_low == 8'h00 && o_idac_sar15ambn_low == 8'h00 && o_idac_sar15dcn_low == 8'h00, "AMB must suppress every DC and SAR15 code path");
		end_case("SSW-28");

		begin_case("SSW-29");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b1;
		send_waveform(1'b1, 1'b1, FRAME_TYPE_NORMAL, 16'd130, 8'h57, 8'h67, 4'h1, 4'h2, 8'hB1);
		macro_tick(13'd161); send_owner(1'b1, 1'b1, FRAME_TYPE_NORMAL, 16'd130, 16'd30, 8'h57, 8'h67, 4'h1, 4'h2);
		macro_tick(13'd460);
		expect_true(o_en_test && o_en_15sar_low && o_clk_15q1_low, "fixed-current SAR15 must retain its normal timing envelope");
		expect_true(!o_leden1_low && !o_leden2_low && o_leddac == 8'h00, "fixed-current SAR15 must suppress every LED output");
		end_case("SSW-29");

		begin_case("SSW-30");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b1; i_static_characterization_enable = 1'b1;
		@(posedge i_clk); #1;
		expect_true(o_en_test && o_clk_buf_low && o_clk_iref_idac_low, "STATIC_BIAS must apply the declared netlist high vector");
		expect_true(o_clk_iref_idac_sar9_low && o_clk_iref_idac_sar15_low && o_clk_aferst_low && o_clk_tiaen_low, "STATIC_BIAS must retain every declared high clock control");
		expect_true(!o_clk_q2_low && !o_clk_q3_low && !o_en_15sar_low && o_leddac == 8'h00, "STATIC_BIAS must suppress SAR sampling and LED output");
		expect_true(o_idac_sar9ambn_low == 8'h00 && o_idac_sar9dcn_low == 8'h00 && o_idac_sar15ambn_low == 8'h00 && o_idac_sar15dcn_low == 8'h00, "STATIC_BIAS must hold all IDAC buses at zero");
		end_case("SSW-30");

		begin_case("SSW-31");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b1; i_static_characterization_enable = 1'b1; i_test_mux_ctrl = 5'b00110;
		@(posedge i_clk); #1 expect_true(o_s_in == 5'b00110, "STATIC_BIAS must expose the atomically committed test MUX value");
		@(negedge i_clk); i_test_mux_ctrl = 5'b11001;
		@(posedge i_clk); #1 expect_true(o_s_in == 5'b11001, "STATIC_BIAS must update all MUX bits on one visible edge");
		i_static_characterization_enable = 1'b0;
		@(posedge i_clk); #1 expect_true(o_s_in == 5'b00000, "test MUX must be isolated outside STATIC_BIAS");
		end_case("SSW-31");

		begin_case("SSW-32");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b1; i_static_characterization_enable = 1'b1; i_test_mux_ctrl = 5'b01010;
		@(posedge i_clk); #1;
		@(negedge i_clk); i_control_abort_event = 1'b1;
		@(posedge i_clk); #1 i_control_abort_event = 1'b0;
		expect_true(!o_en_test && o_s_in == 5'b00000, "abort must prevent late characterization control effects");
		end_case("SSW-32");

		begin_case("SSW-33");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd133, 8'h53, 8'h63, 4'h1, 4'h2, 8'hA3);
		expect_true(!o_adc_owner_inflight, "waveform context fire must not establish an ADC owner");
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd133, 16'd33, 8'h53, 8'h63, 4'h1, 4'h2);
		i_waveform_amb_code_snapshot = 8'h00; i_waveform_dc_code_snapshot = 8'h00;
		macro_tick(13'd300);
		expect_true(o_idac_sar9ambn_low == 8'h53 && o_idac_sar9dcn_low == 8'h63, "owner commit must not rewrite waveform snapshot state");
		end_case("SSW-33");

		begin_case("SSW-34");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd134, 8'h34, 8'h44, 4'h1, 4'h2, 8'hA4);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd134, 16'd34, 8'h34, 8'h44, 4'h1, 4'h2);
		macro_tick(13'd160);
		i_waveform_color_ir = 1'b1; i_waveform_frame_id = 16'd135; i_waveform_leddac_code_snapshot = 8'hB5; i_waveform_context_valid = 1'b1;
		#1 expect_true(o_waveform_context_ready && o_adc_owner_inflight, "IR waveform must be accepted while RED owner remains inflight");
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		macro_tick(13'd204);
		expect_true(o_clk_iref_idac_sar9_low, "independent IR context must enter preheat without clobbering RED owner");
		end_case("SSW-34");

		begin_case("SSW-35");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd135, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd283); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd135, 16'd35, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300); expect_true(o_clk_q3_low && !o_owner_deadline_timeout_sticky, "RED owner committed at tick 283 must preserve Q3=300");
		end_case("SSW-35");

		begin_case("SSW-36");
		reset_and_start;
		i_optical_mode = OPTICAL_IR;
		send_waveform(1'b0, 1'b1, FRAME_TYPE_NORMAL, 16'd136, 8'h31, 8'h41, 4'h1, 4'h2, 8'hB1);
		macro_tick(13'd443); send_owner(1'b0, 1'b1, FRAME_TYPE_NORMAL, 16'd136, 16'd36, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd460); expect_true(o_clk_q3_low && !o_owner_deadline_timeout_sticky, "IR owner committed at tick 443 must preserve Q3=460");
		end_case("SSW-36");

		begin_case("SSW-37");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd137, 8'h31, 8'h00, 4'h1, 4'h0, 8'h00);
		cal_tick(10'd248); send_owner(1'b0, 1'b0, FRAME_TYPE_AMB, 16'd137, 16'd37, 8'h31, 8'h00, 4'h1, 4'h0);
		cal_tick(10'd249); expect_true(o_clk_aferst_low && !o_calibration_timeout_sticky, "CAL owner at tick 248 must stabilize before the tick-249 back-end window");
		end_case("SSW-37");

		begin_case("SSW-38");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd138, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd284);
		expect_true(o_owner_deadline_timeout_sticky, "owner absence past RED deadline must raise timeout sticky");
		macro_tick(13'd300);
		expect_true(!o_clk_q3_low && !o_leden1_low && !o_leden2_low, "owner timeout must suppress sampling, LEDs and result acceptance");
		end_case("SSW-38");

		begin_case("SSW-39");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd139, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1);
		i_adc_owner_precision_mode = 1'b0; i_adc_owner_color_ir = 1'b0; i_adc_owner_frame_type = FRAME_TYPE_NORMAL; i_adc_owner_frame_id = 16'd139;
		i_adc_owner_amb_code_snapshot = 8'h31; i_adc_owner_dc_code_snapshot = 8'h41; i_adc_owner_amb_code_epoch = 4'h1; i_adc_owner_dc_code_epoch = 4'h2; i_adc_owner_sample_index = 16'd39;
		@(negedge i_clk); i_adc_owner_frame_id = 16'hFFFF; i_adc_owner_commit_event = 1'b1;
		@(posedge i_clk); #1 i_adc_owner_commit_event = 1'b0;
		expect_true(!o_adc_owner_inflight && o_switch_protocol_error_sticky, "owner commit with mismatched identity must be rejected atomically");
		end_case("SSW-39");

		begin_case("SSW-40");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd140, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd140, 16'd40, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd160);
		i_waveform_color_ir = 1'b1; i_waveform_frame_id = 16'd141; i_waveform_context_valid = 1'b1;
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		macro_tick(13'd284);
		expect_true(!o_adc_owner_ready && o_adc_owner_inflight, "single-owner rule must hold IR owner ready low until RED is released");
		end_case("SSW-40");

		begin_case("SSW-41");
		reset_and_start;
		send_waveform(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd141, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd141, 16'd41, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd160); i_waveform_color_ir = 1'b1; i_waveform_frame_id = 16'd142; i_waveform_leddac_code_snapshot = 8'hB2; i_waveform_context_valid = 1'b1;
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		macro_tick(13'd204);
		expect_true(o_clk_iref_idac_sar15_low && o_en_sar15_iref && o_en_sar15_amb_low, "SAR15 may continuously retain only its documented cross-color whitelist controls");
		expect_true(!o_leden1_low && !o_leden2_low && !o_clk_q3_low, "SAR15 preheat overlap must not create LED or Q3 overlap");
		end_case("SSW-41");

		begin_case("SSW-42");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd142, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd142, 16'd42, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300); expect_true(o_adc_owner_inflight, "Q3 must not release owner without a real completion event");
		macro_tick(13'd317); expect_true(o_adc_owner_inflight, "waveform end must not release owner without a real completion event");
		complete_owner(16'd42, 1'b0);
		expect_true(!o_adc_owner_inflight, "matching success=0 DONE must nevertheless release the physical owner");
		end_case("SSW-42");

		begin_case("SSW-43");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd143, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd143, 16'd43, 8'h31, 8'h41, 4'h1, 4'h2);
		@(negedge i_clk); i_control_abort_event = 1'b1;
		@(posedge i_clk); #1 i_control_abort_event = 1'b0;
		complete_owner(16'd43, 1'b0);
		@(negedge i_clk); i_adc_complete_sample_index = 16'd43; i_adc_transaction_complete_event = 1'b1;
		@(posedge i_clk); #1 i_adc_transaction_complete_event = 1'b0;
		expect_true(!o_clk_q3_low && o_transaction_mismatch_sticky, "post-release stale DONE must never revive an aborted lifecycle");
		end_case("SSW-43");

		begin_case("SSW-44");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd144, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd144, 16'd44, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd160); i_waveform_color_ir = 1'b1; i_waveform_frame_id = 16'd145; i_waveform_context_valid = 1'b1;
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		macro_tick(13'd44); expect_true(o_clk_iref_idac_sar9_low, "SAR9 RED IREF window must start at tick 44");
		macro_tick(13'd203); expect_true(o_clk_iref_idac_sar9_low, "SAR9 whitelist must remain active before IR starts");
		macro_tick(13'd204); expect_true(o_clk_iref_idac_sar9_low && !o_clk_q3_low, "SAR9 cross-color overlap may retain IREF only, not Q3");
		end_case("SSW-44");

		begin_case("SSW-45");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd145, 8'hA5, 8'h3C, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd145, 16'd45, 8'hA5, 8'h3C, 4'h1, 4'h2);
		for(cnt_tick = 44; cnt_tick < 318; cnt_tick = cnt_tick + 1) begin
			macro_tick(cnt_tick[12:0]);
			expect_true(o_idac_sar15ambn_low == 8'h00 && o_idac_sar15dcn_low == 8'h00, "SAR9 transaction must hold both SAR15 code buses at zero");
		end
		end_case("SSW-45");

		begin_case("SSW-46");
		reset_and_start;
		send_waveform(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd146, 8'h5A, 8'hC3, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd146, 16'd46, 8'h5A, 8'hC3, 4'h1, 4'h2);
		for(cnt_tick = 27; cnt_tick < 308; cnt_tick = cnt_tick + 1) begin
			macro_tick(cnt_tick[12:0]);
			expect_true(o_idac_sar9ambn_low == 8'h00 && o_idac_sar9dcn_low == 8'h00, "SAR15 transaction must hold both SAR9 code buses at zero");
		end
		end_case("SSW-46");

		begin_case("SSW-47");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd147, 8'hA5, 8'h3C, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd147, 16'd47, 8'hA5, 8'h3C, 4'h1, 4'h2);
		reg_first_amb_code = 8'h00;
		for(cnt_tick = 44; cnt_tick <= 300; cnt_tick = cnt_tick + 1) begin
			macro_tick(cnt_tick[12:0]);
			if(o_idac_sar9ambn_low != 8'h00) begin
				reg_first_amb_code = o_idac_sar9ambn_low;
			end
		end
		expect_true(reg_first_amb_code == 8'hA5, "non-symmetric SAR9 AMB snapshot must pass through its own code window bit-for-bit");
		i_waveform_amb_code_snapshot = 8'h5A;
		macro_tick(13'd300); expect_true(o_idac_sar9ambn_low == 8'hA5, "live code updates must not modify an inflight code window");
		end_case("SSW-47");

		begin_case("SSW-48");
		reset_and_start;
		i_normal_frame_active = 1'b0;
		i_calibration_frame_active = 1'b1;
		i_precision_mode_committed = 1'b1;
		i_waveform_precision_mode = 1'b1;
		i_waveform_color_ir = 1'b0;
		i_waveform_frame_type = FRAME_TYPE_AMB;
		i_waveform_frame_id = 16'd148;
		i_waveform_amb_code_snapshot = 8'hFF;
		i_waveform_dc_code_snapshot = 8'hFF;
		i_waveform_amb_code_epoch = 4'h1;
		i_waveform_dc_code_epoch = 4'h2;
		i_waveform_input_source = i_input_source;
		i_waveform_optical_mode = i_optical_mode;
		i_waveform_leddac_code_snapshot = 8'hFF;
		@(negedge i_clk); i_calibration_local_tick = 10'd0;
		#1 expect_true(!o_waveform_context_ready, "illegal SAR15 calibration must be rejected before any code bus can toggle");
		i_waveform_context_valid = 1'b1;
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		expect_true(o_switch_protocol_error_sticky && o_idac_sar9ambn_low == 8'h00 && o_idac_sar9dcn_low == 8'h00 && o_idac_sar15ambn_low == 8'h00 && o_idac_sar15dcn_low == 8'h00, "illegal calibration must hold all four IDAC buses at zero");
		end_case("SSW-48");

		begin_case("SSW-49");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b0; i_optical_mode = OPTICAL_RED;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd149, 8'hA6, 8'h3D, 4'h3, 4'h4, 8'hC1);
		macro_tick(13'd1); send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd149, 16'd49, 8'hA6, 8'h3D, 4'h3, 4'h4);
		macro_tick(13'd44);
		expect_true(!o_analog_safe && !o_en_test, "characterization photodiode RED SAR9 must use the physical photodiode path");
		macro_tick(13'd160);
		i_waveform_color_ir = 1'b1; i_waveform_frame_id = 16'd150;
		expect_true(!o_waveform_context_ready, "characterization RED-only SAR9 must reject the IR handoff point");
		macro_tick(13'd300);
		expect_true(o_clk_q3_low && o_clk_9q1_low && !o_clk_15q1_low, "characterization RED SAR9 must retain Q3 center 300 and SAR9 timing");
		expect_true(o_leden1_low && !o_leden2_low && o_leddac == 8'hC1, "characterization RED SAR9 must drive only the RED LED snapshot");
		expect_true(o_idac_sar9ambn_low == 8'hA6 && o_idac_sar9dcn_low == 8'h3D && o_idac_sar15ambn_low == 8'h00 && o_idac_sar15dcn_low == 8'h00, "characterization RED SAR9 must retain only SAR9 manual IDAC buses");
		complete_owner(16'd49, 1'b1);
		end_case("SSW-49");

		begin_case("SSW-50");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b0; i_optical_mode = OPTICAL_RED;
		send_waveform(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd150, 8'h5C, 8'hA3, 4'h5, 4'h6, 8'hC2);
		macro_tick(13'd1); send_owner(1'b1, 1'b0, FRAME_TYPE_NORMAL, 16'd150, 16'd50, 8'h5C, 8'hA3, 4'h5, 4'h6);
		macro_tick(13'd27);
		expect_true(!o_analog_safe && !o_en_test, "characterization RED SAR15 must enter its netlist preheat at tick 27 without EN_TEST");
		macro_tick(13'd300);
		expect_true(o_clk_q3_low && o_clk_15q1_low && o_en_15sar_low && !o_clk_9q1_low, "characterization RED SAR15 must retain Q3 center 300 and SAR15 timing");
		expect_true(o_leden1_low && !o_leden2_low && o_leddac == 8'hC2, "characterization RED SAR15 must drive only the RED LED snapshot");
		expect_true(o_idac_sar15ambn_low == 8'h5C && o_idac_sar15dcn_low == 8'hA3 && o_idac_sar9ambn_low == 8'h00 && o_idac_sar9dcn_low == 8'h00, "characterization RED SAR15 must retain only SAR15 manual IDAC buses");
		complete_owner(16'd50, 1'b1);
		end_case("SSW-50");

		begin_case("SSW-51");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b0; i_optical_mode = OPTICAL_BOTH;
		i_normal_frame_active = 1'b1; i_calibration_frame_active = 1'b0; i_precision_mode_committed = 1'b0;
		i_waveform_precision_mode = 1'b0; i_waveform_color_ir = 1'b0; i_waveform_frame_type = FRAME_TYPE_NORMAL; i_waveform_frame_id = 16'd151;
		i_waveform_amb_code_snapshot = 8'hFF; i_waveform_dc_code_snapshot = 8'hFF; i_waveform_amb_code_epoch = 4'h1; i_waveform_dc_code_epoch = 4'h2;
		i_waveform_input_source = 1'b0; i_waveform_optical_mode = OPTICAL_BOTH; i_waveform_leddac_code_snapshot = 8'hFF;
		macro_tick(13'd0);
		expect_true(!o_waveform_context_ready, "characterization photodiode modes other than RED-only must be rejected at the handoff point");
		i_waveform_context_valid = 1'b1;
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		expect_true(o_switch_protocol_error_sticky && !o_adc_owner_ready && !o_adc_owner_inflight, "illegal characterization optical mode must not create a waveform or owner");
		expect_true(o_idac_sar9ambn_low == 8'h00 && o_idac_sar9dcn_low == 8'h00 && o_idac_sar15ambn_low == 8'h00 && o_idac_sar15dcn_low == 8'h00, "illegal characterization optical mode must hold every IDAC bus at zero");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b0; i_optical_mode = OPTICAL_RED;
		i_normal_frame_active = 1'b1; i_calibration_frame_active = 1'b0; i_precision_mode_committed = 1'b0;
		i_waveform_precision_mode = 1'b1; i_waveform_color_ir = 1'b0; i_waveform_frame_type = FRAME_TYPE_NORMAL; i_waveform_frame_id = 16'd152;
		i_waveform_amb_code_snapshot = 8'hFF; i_waveform_dc_code_snapshot = 8'hFF; i_waveform_amb_code_epoch = 4'h1; i_waveform_dc_code_epoch = 4'h2;
		i_waveform_input_source = 1'b0; i_waveform_optical_mode = OPTICAL_RED; i_waveform_leddac_code_snapshot = 8'hFF;
		macro_tick(13'd0);
		expect_true(!o_waveform_context_ready, "characterization RED context with a precision mismatch must be rejected before a precision switch can occur");
		i_waveform_context_valid = 1'b1;
		@(posedge i_clk); #1 i_waveform_context_valid = 1'b0;
		expect_true(o_switch_protocol_error_sticky && !o_adc_owner_ready && !o_adc_owner_inflight, "rejected characterization precision mismatch must not create a waveform or owner");
		expect_true(o_idac_sar9ambn_low == 8'h00 && o_idac_sar9dcn_low == 8'h00 && o_idac_sar15ambn_low == 8'h00 && o_idac_sar15dcn_low == 8'h00, "rejected characterization precision mismatch must hold every IDAC bus at zero");
		end_case("SSW-51");

		begin_case("SSW-52");
		reset_and_start;
		i_run_profile = 1'b1; i_input_source = 1'b0; i_static_characterization_enable = 1'b1; i_test_mux_ctrl = 5'b10110;
		@(posedge i_clk); #1;
		expect_true(o_switch_protocol_error_sticky && !o_en_test && !o_clk_buf_low && o_s_in == 5'b00000, "STATIC_BIAS with input_source zero must reject the static vector and report a protocol error");
		expect_true(!o_adc_owner_ready && !o_adc_owner_inflight && o_analog_safe, "invalid STATIC_BIAS must not create a waveform or ADC owner");
		expect_true(o_idac_sar9ambn_low == 8'h00 && o_idac_sar9dcn_low == 8'h00 && o_idac_sar15ambn_low == 8'h00 && o_idac_sar15dcn_low == 8'h00, "invalid STATIC_BIAS must hold every IDAC bus at zero");
		end_case("SSW-52");

		// ABT-DONE（ABCD F-035，TB本地名，不占用SSW族编号）：abort与匹配身份的DONE同拍到达时，DONE必须照常释放owner，
		// abort仍撤销波形；随后STOP、诊断清除、新代际START后必须能建立并释放新owner（缺陷时owner残留到复位）
		begin_case("ABT-DONE");
		reset_and_start;
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd101, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd101, 16'd1, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300);
		@(negedge i_clk);
		i_adc_complete_sample_index = 16'd1; i_adc_transaction_success = 1'b1; i_adc_transaction_complete_event = 1'b1;
		i_control_abort_event = 1'b1;
		@(posedge i_clk); #1 i_adc_transaction_complete_event = 1'b0; i_control_abort_event = 1'b0;
		expect_true(!o_adc_owner_inflight, "a matching DONE in the same cycle as abort must still release the owner");
		macro_tick(13'd301);
		expect_true(!o_leden1_low && !o_clk_q3_low, "abort must still cancel the RED waveform");
		repeat(20) @(posedge i_clk); #1;
		expect_true(!o_adc_owner_inflight && o_wrapper_idle, "owner must stay released and the wrapper must become idle after abort");
		i_run_enable = 1'b0;
		@(negedge i_clk); i_stop_ack_event = 1'b1; @(posedge i_clk); #1 i_stop_ack_event = 1'b0;
		repeat(5) @(posedge i_clk);
		@(negedge i_clk); i_diag_clear_event = 1'b1; @(posedge i_clk); #1 i_diag_clear_event = 1'b0;
		i_run_generation = 8'd2; i_run_enable = 1'b1;
		@(negedge i_clk); i_start_ack_event = 1'b1; @(posedge i_clk); #1 i_start_ack_event = 1'b0;
		repeat(5) @(posedge i_clk);
		send_waveform(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd102, 8'h31, 8'h41, 4'h1, 4'h2, 8'hA1);
		macro_tick(13'd1);
		send_owner(1'b0, 1'b0, FRAME_TYPE_NORMAL, 16'd102, 16'd2, 8'h31, 8'h41, 4'h1, 4'h2);
		macro_tick(13'd300);
		complete_owner(16'd2, 1'b1);
		macro_tick(13'd317);
		expect_true(!o_adc_owner_inflight, "a new-generation owner must be established and released after recovery");
		end_case("ABT-DONE");

		if((cnt_error == 0) && (cnt_pass == 53)) begin
			$display("ALL SSW-01 THROUGH SSW-52 PASS");
			$finish;
		end else begin
			$fatal(1, "SSW regression failed: pass=%0d error=%0d", cnt_pass, cnt_error);
		end
	end

	// 看门狗限制异常握手场景的最长仿真时间，避免回归静默挂起。
	initial begin
		#30000000;
		$fatal(1, "SSW watchdog timeout");
	end

endmodule
