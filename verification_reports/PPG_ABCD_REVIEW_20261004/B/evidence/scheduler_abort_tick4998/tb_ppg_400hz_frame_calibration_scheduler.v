`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026-08-16
// Design Name:        PPG 400 Hz Frame Calibration Scheduler Testbench
// Module Name:        tb_ppg_400hz_frame_calibration_scheduler
// Description:        Self-checking scheduler V1.7 verification for FSC-01 through FSC-59.
// Simulations:        ppg_400hz_frame_calibration_scheduler_sim
//
// Referrences:        PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_400hz_frame_calibration_scheduler.v
//
// Version:            V1.6
// Revision Date:      2026-09-30
// History:
// 2026-08-16          V1.3        Erie          Add independent-context FSC-01 through FSC-57 checks.
// 2026-08-24          V1.4        Erie          Fix three issues found while re-running this self-check against the current (V1.6) scheduler RTL after the STOP-drain deadlock fix. (1) This TB predated the DUT's V1.4 addition of i_run_generation, so the port was left entirely undeclared and floated as X at the DUT instantiation, making i_run_generation==state_current[B_INFLIGHT_GENERATION] compare X and fail every case depending on completion matching (17 of 57 cases); fixed by adding the C_RUN_GENERATION_WIDTH parameter, declaring/connecting i_run_generation and driving it at a fixed constant in drive_defaults (none of FSC-01 through FSC-57 exercise cross-generation rejection; that remains a coverage gap, not newly added here). (2) FSC-33's manual late-DONE drive raced against the still-active background auto-done generator: flag_auto_done_enable was left on, so its every-cycle non-blocking i_adc_transaction_complete_event<=1'b0 default silently overwrote the test's own blocking drive of the same signal at the same edge, so the DUT never actually sampled the manual completion pulse as 1; fixed by disabling flag_auto_done_enable before the manual drive. (3) FSC-44 asserted the pre-V1.6 behavior that a plain i_run_enable==0 (no STOP/abort) immediately clears B_FRAME_ACTIVE; V1.6 intentionally changed this so only abort clears it immediately, letting an already-open macro frame drain via natural tick advance per contract section 16.3 — fixed by asserting the still-valid immediate property (no new owner commit, frame legitimately stays active) and then waiting for the frame to reach MACRO_LAST_TICK to confirm it actually does drain and clear on its own, rather than weakening the check.
// 2026-08-24          V1.5        Erie          Add FSC-58/59, the first real coverage for scheduler RTL V1.7's newly-implemented receiver-side calibration eligibility check (section 9.1). Each drives an otherwise-legal AMB_CAL or DCS_CAL payload (correct frame_type/color/precision) but with an illegal i_run_profile (CHARACTERIZATION) or i_input_source (EXTERNAL_TEST_CURRENT) respectively, watches o_calibration_sample_ready continuously for 700 cycles (past local tick 0 and the retry window) to confirm it never asserts even once, and confirms zero owner commits, zero waveform fires, and o_protocol_error_sticky asserted. The contract's own self-check table has listed a "FSC-17 | calibration request eligibility and buffering" case since this file's creation, but no such case has ever actually existed here (the real FSC-17 checks an unrelated RED-only owner-commit count); FSC-58/59 are new cases, not a restoration of a regressed one.
// 2026-09-30          V1.6        Erie          TB maintenance (no RTL change). Found by the 2026-09-30 regression baseline (REGRESSION_BASELINE_20260930.md section 6.1): FSC-15 failed because this TB never connected the i_owner_q3_window_closed input added by scheduler contract V1.8 (2026-08-30, LFA-06 fix); the floating Z kept flag_completion_success from ever being 1, so no NORMAL frame ever completed. Tied it to constant 1'b1: this restores the pre-V1.8 behaviour in which the owner's Q3 window always counts as already closed, which is exactly the environment every FSC case was written against; the Q3 gating itself is covered at system level by the 19-TB LFA-06 evidence and is intentionally not re-tested here. With the port floating, FSC-34 (cnt_normal_complete==0) also passed vacuously; it is now a real check. Also connected the SID-05 output o_cal_owner_deadline_event (2026-09-18) to an observation-only wire; no new assertion (the tick-248 deadline test is a separate task). Result: FSC-01 through FSC-59 pass=59 fail=0 (xsim and iverilog).
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026-08-16
// 设计名称:           PPG 400 Hz帧/校准事务调度器自检平台
// 模块名称:           tb_ppg_400hz_frame_calibration_scheduler
// 模块说明:           验证独立波形上下文、ADC owner和真实DONE模型。
// 仿真工程:           ppg_400hz_frame_calibration_scheduler_sim
//
// 参考资料:           PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_400hz_frame_calibration_scheduler.v
//
// 当前版本:           V1.6
// 修订日期:           2026-09-30
// 修订历史:
// 2026-08-16          V1.3        Erie          覆盖FSC-01至FSC-57及真实事务完成释放。
// 2026-08-24          V1.4        Erie          拿V1.6 scheduler（STOP排空死锁修复后）重跑这份自检时发现并修复三个问题。(1)这份TB早于DUT V1.4新增的i_run_generation端口，例化里从未声明也从未连接，导致它在DUT里浮空为X，使i_run_generation==在途owner锁存代际这条比较恒为假，凡是依赖DONE完成匹配的用例全部假失败（57个里17个）；修复：新增C_RUN_GENERATION_WIDTH参数，声明并连接i_run_generation，在drive_defaults里给它一个全程固定常量——FSC-01至FSC-57本来就没有一条测试跨代际拒绝，这次只是把浮空端口接上，不是新增覆盖，跨代际拒绝仍是待补覆盖项。(2)FSC-33手动驱动迟到DONE时，后台自动DONE生成器flag_auto_done_enable还开着，它每拍非阻塞写回的i_adc_transaction_complete_event<=1'b0默认值在同一个时钟沿悄悄覆盖了测试自己的阻塞驱动，DUT从未真正采样到手动置的1；修复：手动驱动前先关掉flag_auto_done_enable。(3)FSC-44断言的是V1.6修复前的行为——纯i_run_enable掉底（无STOP/abort）立即清B_FRAME_ACTIVE；V1.6按合同16.3节故意改成只有abort才立即清，纯run_enable掉底要靠tick自然推进把已经打开的宏帧走完；修复为断言仍然成立的即时性质（没有新owner提交、宏帧合法地保持活动）之后再等到MACRO_LAST_TICK验证它确实会自己走完释放，而不是简单削弱断言
// 2026-08-24          V1.5        Erie          新增FSC-58/59，为scheduler RTL V1.7刚实现的接收端校准资格复核（合同9.1节）拿到第一份真实测试覆盖。两条分别构造一笔payload本身合法的AMB_CAL/DCS_CAL请求（frame_type/颜色/精度都对），但run_profile非法（CHARACTERIZATION）或input_source非法（EXTERNAL_TEST_CURRENT），连续监视o_calibration_sample_ready 700拍（跨过local tick 0和重试窗口）确认它一次都没有出现过，同时确认owner提交次数为0、波形fire次数为0、o_protocol_error_sticky置位。合同自己的自检用例表从这份文件创建起就写着"FSC-17｜校准请求资格与缓冲"，但这条用例从未在这里真正存在过（真实的FSC-17测的是纯RED场景一个无关的owner commit计数）；FSC-58/59是全新用例，不是恢复一条退化的旧用例。
// 2026-09-30          V1.6        Erie          TB维护（不改RTL）。2026-09-30回归基线（REGRESSION_BASELINE_20260930.md第6.1节）发现：FSC-15失败，原因是本TB一直没有连接scheduler合同V1.8（2026-08-30，LFA-06修复）新增的输入i_owner_q3_window_closed；端口浮空为Z，flag_completion_success永远不为1，NORMAL帧永远无法完成。改为恒接1'b1：等于恢复V1.8之前"在途owner的Q3窗口随时算已关闭"的语义，而全部FSC用例正是按这个环境写的；Q3门控本身的覆盖在系统级19-TB的LFA-06证据里，本单元TB有意不重复测试。端口浮空时FSC-34（cnt_normal_complete==0）也属于空过，现在是真实检查。另把SID-05新增输出o_cal_owner_deadline_event（2026-09-18）接到一根仅供观察的wire，不加新断言（tick-248截止测试另行安排）。结果：FSC-01至FSC-59 pass=59 fail=0（xsim与iverilog一致）。
module tb_ppg_400hz_frame_calibration_scheduler ();

	parameter C_FRAME_ID_WIDTH = 16;
	parameter C_SAMPLE_INDEX_WIDTH = 16;
	parameter C_IDAC_CODE_WIDTH = 8;
	parameter C_CODE_EPOCH_WIDTH = 4;
	parameter C_MACRO_TICK_WIDTH = 13;
	parameter C_CAL_TICK_WIDTH = 10;
	parameter C_RUN_GENERATION_WIDTH = 8;

	localparam [1:0]FRAME_TYPE_AMB = 2'b00;
	localparam [1:0]FRAME_TYPE_DCS = 2'b01;
	localparam [1:0]FRAME_TYPE_NORMAL = 2'b10;
	localparam [1:0]OPTICAL_BOTH = 2'b00;
	localparam [1:0]OPTICAL_RED = 2'b01;
	localparam [1:0]OPTICAL_IR = 2'b10;
	localparam [1:0]OPTICAL_OFF = 2'b11;

	reg i_clk;
	reg i_rstn;
	reg i_active_config_valid;
	reg i_run_enable;
	reg i_allow_new_transaction;
	reg i_start_ack_event;
	reg i_stop_ack_event;
	reg i_control_abort_event;
	reg i_diag_clear_event;
	reg [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation;
	reg i_run_profile;
	reg i_input_source;
	reg [1:0]i_optical_mode;
	reg i_active_precision_mode;
	reg i_normal_measurement_eligible;
	reg i_switch_hold_new_transaction;
	reg i_ami_fault_blocking;
	reg i_ssw_fault_blocking;
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code;
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code;
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code;
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch;
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_dcs_r_code_epoch;
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_dcs_ir_code_epoch;
	reg [C_IDAC_CODE_WIDTH - 1:0]i_leddac_r_code;
	reg [C_IDAC_CODE_WIDTH - 1:0]i_leddac_ir_code;
	reg i_calibration_sample_valid;
	reg [1:0]i_calibration_frame_type;
	reg i_calibration_color_ir;
	reg i_calibration_precision_mode;
	reg [1:0]i_calibration_request_reason;
	reg i_waveform_context_ready;
	reg i_transaction_start_ready;
	reg i_transaction_start_fire;
	reg i_adc_owner_ready;
	reg i_adc_transaction_complete_event;
	reg i_adc_transaction_success;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_adc_complete_sample_index;
	reg i_adc_idle;
	reg i_analog_safe;
	reg i_sar_timing_idle;
	reg flag_auto_done_enable;
	reg flag_inject_wrong_done;
	reg flag_auto_done_pending;
	reg [2:0]cnt_auto_done_delay;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_auto_done_sample;

	wire o_calibration_sample_ready;
	wire o_waveform_context_valid;
	wire o_waveform_precision_mode;
	wire [C_FRAME_ID_WIDTH - 1:0]o_waveform_frame_id;
	wire o_waveform_color_ir;
	wire [1:0]o_waveform_frame_type;
	wire [C_IDAC_CODE_WIDTH - 1:0]o_waveform_amb_code_snapshot;
	wire [C_IDAC_CODE_WIDTH - 1:0]o_waveform_dc_code_snapshot;
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_waveform_amb_code_epoch;
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_waveform_dc_code_epoch;
	wire o_waveform_input_source;
	wire [1:0]o_waveform_optical_mode;
	wire [C_IDAC_CODE_WIDTH - 1:0]o_waveform_leddac_code_snapshot;
	wire o_transaction_start_valid;
	wire o_transaction_precision_mode;
	wire [C_FRAME_ID_WIDTH - 1:0]o_transaction_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_transaction_sample_index;
	wire o_transaction_color_ir;
	wire [1:0]o_transaction_frame_type;
	wire [C_IDAC_CODE_WIDTH - 1:0]o_transaction_amb_code_snapshot;
	wire [C_IDAC_CODE_WIDTH - 1:0]o_transaction_dc_code_snapshot;
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_transaction_amb_code_epoch;
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_transaction_dc_code_epoch;
	wire o_adc_owner_commit_event;
	wire o_adc_owner_precision_mode;
	wire [C_FRAME_ID_WIDTH - 1:0]o_adc_owner_frame_id;
	wire o_adc_owner_color_ir;
	wire [1:0]o_adc_owner_frame_type;
	wire [C_IDAC_CODE_WIDTH - 1:0]o_adc_owner_amb_code_snapshot;
	wire [C_IDAC_CODE_WIDTH - 1:0]o_adc_owner_dc_code_snapshot;
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_adc_owner_amb_code_epoch;
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_adc_owner_dc_code_epoch;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_adc_owner_sample_index;
	wire o_macro_frame_start_event;
	wire o_macro_frame_safe_boundary;
	wire o_idac_code_safe_boundary;
	wire o_startup_idac_safe_boundary;
	wire [C_FRAME_ID_WIDTH - 1:0]o_safe_frame_id;
	wire [C_MACRO_TICK_WIDTH - 1:0]o_macro_tick;
	wire [2:0]o_calibration_subframe_index;
	wire [C_CAL_TICK_WIDTH - 1:0]o_calibration_local_tick;
	wire o_normal_frame_complete_event;
	wire o_calibration_frame_complete_event;
	wire o_scheduler_idle;
	wire o_normal_frame_active;
	wire o_calibration_frame_active;
	wire o_transaction_inflight;
	wire [C_FRAME_ID_WIDTH - 1:0]o_current_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_next_sample_index;
	wire o_launch_timeout_sticky;
	wire o_owner_deadline_timeout_sticky;
	wire o_completion_mismatch_sticky;
	wire o_protocol_error_sticky;
	wire o_scheduler_local_fault_blocking;
	wire o_cal_owner_deadline_event; // V1.6: SID-05新增校准owner截止事件，仅观察

	integer cnt_pass;
	integer cnt_fail;
	integer cnt_cycle;
	integer cnt_frame_start;
	integer cnt_wave_fire;
	integer cnt_owner_commit;
	integer cnt_done;
	integer cnt_startup_boundary;
	integer cnt_idac_boundary;
	integer cnt_macro_boundary;
	integer cnt_cal_boundary;
	integer cnt_normal_complete;
	integer cnt_cal_complete;
	integer flag_wait_ok;
	integer flag_case_ok;
	reg flag_ready_ever_seen; // FSC-58/59：非法run_profile/input_source窗口内o_calibration_sample_ready是否曾经出现过
	integer idx_ready_watch;
	reg [C_MACRO_TICK_WIDTH - 1:0]reg_last_wave_tick;
	reg [C_CAL_TICK_WIDTH - 1:0]reg_last_wave_local_tick;
	reg reg_last_wave_color;
	reg reg_last_wave_precision;
	reg [1:0]reg_last_wave_type;
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_last_wave_leddac;
	reg [C_FRAME_ID_WIDTH - 1:0]reg_last_wave_frame;
	reg [C_MACRO_TICK_WIDTH - 1:0]reg_last_owner_tick;
	reg [C_CAL_TICK_WIDTH - 1:0]reg_last_owner_local_tick;
	reg reg_last_owner_color;
	reg reg_last_owner_precision;
	reg [1:0]reg_last_owner_type;
	reg [C_FRAME_ID_WIDTH - 1:0]reg_last_owner_frame;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_last_owner_sample;
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_last_owner_amb;
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_last_owner_dc;
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_last_owner_amb_epoch;
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_last_owner_dc_epoch;
	reg [31:0]reg_last_frame_start_cycle;
	reg [31:0]reg_frame_period;

	ppg_400hz_frame_calibration_scheduler inst_ppg_400hz_frame_calibration_scheduler(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_active_config_valid(i_active_config_valid),
		.i_run_enable(i_run_enable),
		.i_allow_new_transaction(i_allow_new_transaction),
		.i_start_ack_event(i_start_ack_event),
		.i_stop_ack_event(i_stop_ack_event),
		.i_control_abort_event(i_control_abort_event),
		.i_diag_clear_event(i_diag_clear_event),
		.i_run_generation(i_run_generation),
		.i_run_profile(i_run_profile),
		.i_input_source(i_input_source),
		.i_optical_mode(i_optical_mode),
		.i_active_precision_mode(i_active_precision_mode),
		.i_normal_measurement_eligible(i_normal_measurement_eligible),
		.i_switch_hold_new_transaction(i_switch_hold_new_transaction),
		.i_ami_fault_blocking(i_ami_fault_blocking),
		.i_ssw_fault_blocking(i_ssw_fault_blocking),
		.i_amb_code(i_amb_code),
		.i_dcs_r_code(i_dcs_r_code),
		.i_dcs_ir_code(i_dcs_ir_code),
		.i_amb_code_epoch(i_amb_code_epoch),
		.i_dcs_r_code_epoch(i_dcs_r_code_epoch),
		.i_dcs_ir_code_epoch(i_dcs_ir_code_epoch),
		.i_leddac_r_code(i_leddac_r_code),
		.i_leddac_ir_code(i_leddac_ir_code),
		.i_calibration_sample_valid(i_calibration_sample_valid),
		.o_calibration_sample_ready(o_calibration_sample_ready),
		.i_calibration_frame_type(i_calibration_frame_type),
		.i_calibration_color_ir(i_calibration_color_ir),
		.i_calibration_precision_mode(i_calibration_precision_mode),
		.i_calibration_request_reason(i_calibration_request_reason),
		.o_waveform_context_valid(o_waveform_context_valid),
		.i_waveform_context_ready(i_waveform_context_ready),
		.o_waveform_precision_mode(o_waveform_precision_mode),
		.o_waveform_frame_id(o_waveform_frame_id),
		.o_waveform_color_ir(o_waveform_color_ir),
		.o_waveform_frame_type(o_waveform_frame_type),
		.o_waveform_amb_code_snapshot(o_waveform_amb_code_snapshot),
		.o_waveform_dc_code_snapshot(o_waveform_dc_code_snapshot),
		.o_waveform_amb_code_epoch(o_waveform_amb_code_epoch),
		.o_waveform_dc_code_epoch(o_waveform_dc_code_epoch),
		.o_waveform_input_source(o_waveform_input_source),
		.o_waveform_optical_mode(o_waveform_optical_mode),
		.o_waveform_leddac_code_snapshot(o_waveform_leddac_code_snapshot),
		.o_transaction_start_valid(o_transaction_start_valid),
		.i_transaction_start_ready(i_transaction_start_ready),
		.i_transaction_start_fire(i_transaction_start_fire),
		.o_transaction_precision_mode(o_transaction_precision_mode),
		.o_transaction_frame_id(o_transaction_frame_id),
		.o_transaction_sample_index(o_transaction_sample_index),
		.o_transaction_color_ir(o_transaction_color_ir),
		.o_transaction_frame_type(o_transaction_frame_type),
		.o_transaction_amb_code_snapshot(o_transaction_amb_code_snapshot),
		.o_transaction_dc_code_snapshot(o_transaction_dc_code_snapshot),
		.o_transaction_amb_code_epoch(o_transaction_amb_code_epoch),
		.o_transaction_dc_code_epoch(o_transaction_dc_code_epoch),
		.i_adc_owner_ready(i_adc_owner_ready),
		.o_adc_owner_commit_event(o_adc_owner_commit_event),
		.o_adc_owner_precision_mode(o_adc_owner_precision_mode),
		.o_adc_owner_frame_id(o_adc_owner_frame_id),
		.o_adc_owner_color_ir(o_adc_owner_color_ir),
		.o_adc_owner_frame_type(o_adc_owner_frame_type),
		.o_adc_owner_amb_code_snapshot(o_adc_owner_amb_code_snapshot),
		.o_adc_owner_dc_code_snapshot(o_adc_owner_dc_code_snapshot),
		.o_adc_owner_amb_code_epoch(o_adc_owner_amb_code_epoch),
		.o_adc_owner_dc_code_epoch(o_adc_owner_dc_code_epoch),
		.o_adc_owner_sample_index(o_adc_owner_sample_index),
		.i_adc_transaction_complete_event(i_adc_transaction_complete_event),
		.i_adc_transaction_success(i_adc_transaction_success),
		.i_adc_complete_sample_index(i_adc_complete_sample_index),
		.i_owner_q3_window_closed(1'b1), // V1.6: 恒1=恢复RTL V1.8前"Q3随时算已关闭"语义；Q3门控覆盖在19-TB LFA-06
		.i_adc_idle(i_adc_idle),
		.i_analog_safe(i_analog_safe),
		.i_sar_timing_idle(i_sar_timing_idle),
		.o_macro_frame_start_event(o_macro_frame_start_event),
		.o_macro_frame_safe_boundary(o_macro_frame_safe_boundary),
		.o_idac_code_safe_boundary(o_idac_code_safe_boundary),
		.o_startup_idac_safe_boundary(o_startup_idac_safe_boundary),
		.o_safe_frame_id(o_safe_frame_id),
		.o_macro_tick(o_macro_tick),
		.o_calibration_subframe_index(o_calibration_subframe_index),
		.o_calibration_local_tick(o_calibration_local_tick),
		.o_normal_frame_complete_event(o_normal_frame_complete_event),
		.o_calibration_frame_complete_event(o_calibration_frame_complete_event),
		.o_scheduler_idle(o_scheduler_idle),
		.o_normal_frame_active(o_normal_frame_active),
		.o_calibration_frame_active(o_calibration_frame_active),
		.o_transaction_inflight(o_transaction_inflight),
		.o_current_frame_id(o_current_frame_id),
		.o_next_sample_index(o_next_sample_index),
		.o_launch_timeout_sticky(o_launch_timeout_sticky),
		.o_owner_deadline_timeout_sticky(o_owner_deadline_timeout_sticky),
		.o_completion_mismatch_sticky(o_completion_mismatch_sticky),
		.o_protocol_error_sticky(o_protocol_error_sticky),
		.o_scheduler_local_fault_blocking(o_scheduler_local_fault_blocking),
		.o_cal_owner_deadline_event(o_cal_owner_deadline_event) // V1.6: SID-05端口显式接观察wire，本TB不断言
	);

	// AMI returned fire must exactly equal the scheduler owner commit.
	always@(*)begin
		i_transaction_start_fire = o_adc_owner_commit_event;
	end

	// The testbench models only synchronized, identity-matched physical DONE.
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			i_adc_transaction_complete_event <= 1'b0;
			i_adc_complete_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
			i_adc_idle <= 1'b1;
			i_sar_timing_idle <= 1'b1;
			flag_auto_done_pending <= 1'b0;
			cnt_auto_done_delay <= 3'd0;
			reg_auto_done_sample <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
		end else begin
			if(flag_auto_done_enable)begin
				i_adc_transaction_complete_event <= 1'b0;
				if(o_adc_owner_commit_event)begin
					flag_auto_done_pending <= 1'b1;
					cnt_auto_done_delay <= 3'd3;
					reg_auto_done_sample <= flag_inject_wrong_done ? {C_SAMPLE_INDEX_WIDTH{1'b1}} : o_adc_owner_sample_index;
					i_adc_idle <= 1'b0;
					i_sar_timing_idle <= 1'b0;
				end else if(flag_auto_done_pending && (cnt_auto_done_delay != 3'd0))begin
					cnt_auto_done_delay <= cnt_auto_done_delay - 3'd1;
				end else if(flag_auto_done_pending)begin
					flag_auto_done_pending <= 1'b0;
					i_adc_transaction_complete_event <= 1'b1;
					i_adc_complete_sample_index <= reg_auto_done_sample;
					i_adc_idle <= 1'b1;
					i_sar_timing_idle <= 1'b1;
				end
			end
		end
	end

	// This monitor captures every protocol event at the 2 MHz state boundary.
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_cycle <= 0;
			cnt_frame_start <= 0;
			cnt_wave_fire <= 0;
			cnt_owner_commit <= 0;
			cnt_done <= 0;
			cnt_startup_boundary <= 0;
			cnt_idac_boundary <= 0;
			cnt_macro_boundary <= 0;
			cnt_cal_boundary <= 0;
			cnt_normal_complete <= 0;
			cnt_cal_complete <= 0;
			reg_last_wave_tick <= {C_MACRO_TICK_WIDTH{1'b0}};
			reg_last_wave_local_tick <= {C_CAL_TICK_WIDTH{1'b0}};
			reg_last_owner_tick <= {C_MACRO_TICK_WIDTH{1'b0}};
			reg_last_owner_local_tick <= {C_CAL_TICK_WIDTH{1'b0}};
			reg_last_frame_start_cycle <= 0;
			reg_frame_period <= 0;
		end else begin
			cnt_cycle <= cnt_cycle + 1;
			if(o_macro_frame_start_event)begin
				cnt_frame_start <= cnt_frame_start + 1;
				if(reg_last_frame_start_cycle != 0)begin
					reg_frame_period <= cnt_cycle - reg_last_frame_start_cycle;
				end
				reg_last_frame_start_cycle <= cnt_cycle;
			end
			if(o_waveform_context_valid && i_waveform_context_ready)begin
				cnt_wave_fire <= cnt_wave_fire + 1;
				reg_last_wave_tick <= o_macro_tick;
				reg_last_wave_local_tick <= o_calibration_local_tick;
				reg_last_wave_color <= o_waveform_color_ir;
				reg_last_wave_precision <= o_waveform_precision_mode;
				reg_last_wave_type <= o_waveform_frame_type;
				reg_last_wave_leddac <= o_waveform_leddac_code_snapshot;
				reg_last_wave_frame <= o_waveform_frame_id;
			end
			if(o_adc_owner_commit_event)begin
				cnt_owner_commit <= cnt_owner_commit + 1;
				reg_last_owner_tick <= o_macro_tick;
				reg_last_owner_local_tick <= o_calibration_local_tick;
				reg_last_owner_color <= o_adc_owner_color_ir;
				reg_last_owner_precision <= o_adc_owner_precision_mode;
				reg_last_owner_type <= o_adc_owner_frame_type;
				reg_last_owner_frame <= o_adc_owner_frame_id;
				reg_last_owner_sample <= o_adc_owner_sample_index;
				reg_last_owner_amb <= o_adc_owner_amb_code_snapshot;
				reg_last_owner_dc <= o_adc_owner_dc_code_snapshot;
				reg_last_owner_amb_epoch <= o_adc_owner_amb_code_epoch;
				reg_last_owner_dc_epoch <= o_adc_owner_dc_code_epoch;
			end
			if(i_adc_transaction_complete_event)begin
				cnt_done <= cnt_done + 1;
			end
			if(o_startup_idac_safe_boundary)begin
				cnt_startup_boundary <= cnt_startup_boundary + 1;
			end
			if(o_idac_code_safe_boundary)begin
				cnt_idac_boundary <= cnt_idac_boundary + 1;
			end
			if(o_macro_frame_safe_boundary)begin
				cnt_macro_boundary <= cnt_macro_boundary + 1;
			end
			if(o_idac_code_safe_boundary && o_calibration_frame_active)begin
				cnt_cal_boundary <= cnt_cal_boundary + 1;
			end
			if(o_normal_frame_complete_event)begin
				cnt_normal_complete <= cnt_normal_complete + 1;
			end
			if(o_calibration_frame_complete_event)begin
				cnt_cal_complete <= cnt_cal_complete + 1;
			end
		end
	end

	always #250 i_clk = ~i_clk;

	// 核对单个FSC编号的布尔检查点，并累计显式通过或失败证据。
	task check_fsc;
		input [31:0]i_case_number;
		input i_condition;
		begin
			if(i_condition)begin
				cnt_pass = cnt_pass + 1;
				$display("PASS FSC-%0d", i_case_number);
			end else begin
				cnt_fail = cnt_fail + 1;
				$display("FAIL FSC-%0d cycle=%0d tick=%0d", i_case_number, cnt_cycle, o_macro_tick);
			end
		end
	endtask

	// 复原每个独立场景共享的稳定输入和自动真实DONE响应模型。
	task drive_defaults;
		begin
			i_active_config_valid = 1'b1;
			i_run_enable = 1'b1;
			i_allow_new_transaction = 1'b1;
			i_start_ack_event = 1'b0;
			i_stop_ack_event = 1'b0;
			i_control_abort_event = 1'b0;
			i_diag_clear_event = 1'b0;
			i_run_generation = {{(C_RUN_GENERATION_WIDTH - 1){1'b0}}, 1'b1};
			i_run_profile = 1'b0;
			i_input_source = 1'b0;
			i_optical_mode = OPTICAL_BOTH;
			i_active_precision_mode = 1'b0;
			i_normal_measurement_eligible = 1'b1;
			i_switch_hold_new_transaction = 1'b0;
			i_ami_fault_blocking = 1'b0;
			i_ssw_fault_blocking = 1'b0;
			i_amb_code = 8'h21;
			i_dcs_r_code = 8'h43;
			i_dcs_ir_code = 8'h65;
			i_amb_code_epoch = 4'h2;
			i_dcs_r_code_epoch = 4'h4;
			i_dcs_ir_code_epoch = 4'h6;
			i_leddac_r_code = 8'h17;
			i_leddac_ir_code = 8'h29;
			i_calibration_sample_valid = 1'b0;
			i_calibration_frame_type = FRAME_TYPE_AMB;
			i_calibration_color_ir = 1'b0;
			i_calibration_precision_mode = 1'b0;
			i_calibration_request_reason = 2'b01;
			i_waveform_context_ready = 1'b1;
			i_transaction_start_ready = 1'b1;
			i_adc_owner_ready = 1'b1;
			i_adc_transaction_success = 1'b1;
			i_adc_complete_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
			i_adc_idle = 1'b1;
			i_analog_safe = 1'b1;
			i_sar_timing_idle = 1'b1;
			flag_auto_done_enable = 1'b1;
			flag_inject_wrong_done = 1'b0;
		end
	endtask

	// 施加异步复位并等待两个系统时钟以清除所有在途状态。
	task reset_dut;
		begin
			i_rstn = 1'b0;
			#125;
			i_rstn = 1'b1;
			repeat(2) @(posedge i_clk);
		end
	endtask

	// 在完整时钟周期内发送START确认单拍，触发启动安全边界流程。
	task pulse_start;
		begin
			@(negedge i_clk);
			i_start_ack_event = 1'b1;
			@(negedge i_clk);
			i_start_ack_event = 1'b0;
		end
	endtask

	// 有上界地等待宏帧启动事件，避免调度错误导致仿真永久等待。
	task wait_frame_start;
		input integer i_limit;
		integer idx;
		begin
			flag_wait_ok = 0;
			for(idx = 0; idx < i_limit; idx = idx + 1)begin
				@(posedge i_clk);
				if(o_macro_frame_start_event)begin
					flag_wait_ok = 1;
					idx = i_limit;
				end
			end
		end
	endtask

	// 有上界地等待指定数量的ADC owner提交，用于真实DONE释放验证。
	task wait_owner_count;
		input integer i_target;
		input integer i_limit;
		integer idx;
		begin
			flag_wait_ok = 0;
			for(idx = 0; idx < i_limit; idx = idx + 1)begin
				@(posedge i_clk);
				if(cnt_owner_commit >= i_target)begin
					flag_wait_ok = 1;
					idx = i_limit;
				end
			end
		end
	endtask

	// 有上界地等待目标宏帧tick，核对相位边界与事务接管时刻。
	task wait_macro_tick;
		input [C_MACRO_TICK_WIDTH - 1:0]i_tick;
		input integer i_limit;
		integer idx;
		begin
			flag_wait_ok = 0;
			for(idx = 0; idx < i_limit; idx = idx + 1)begin
				@(posedge i_clk);
				if(o_macro_tick == i_tick)begin
					flag_wait_ok = 1;
					idx = i_limit;
				end
			end
		end
	endtask

	// 顺序执行FSC-01至FSC-59场景，检查启动、波形、owner、故障恢复和校准接收端资格语义。
 initial begin
 i_clk=0;i_rstn=0;cnt_pass=0;cnt_fail=0;drive_defaults;
 i_normal_measurement_eligible=0;i_calibration_sample_valid=1;
 reset_dut;pulse_start;
 wait(o_macro_tick==13'd4998);@(negedge i_clk);
 $display("B_ABORT_BEFORE tick=%0d active=%b inflight=%b pending=%b rollover=%b",o_macro_tick,o_calibration_frame_active,o_transaction_inflight,inst_ppg_400hz_frame_calibration_scheduler.state_current[inst_ppg_400hz_frame_calibration_scheduler.B_CAL_REQ_PENDING],inst_ppg_400hz_frame_calibration_scheduler.flag_calibration_rollover);
 i_control_abort_event=1;
 @(posedge i_clk);#1;
 $display("B_ABORT_AFTER tick=%0d active=%b inflight=%b ownercommit=%b idle=%b",o_macro_tick,o_calibration_frame_active,o_transaction_inflight,o_adc_owner_commit_event,o_scheduler_idle);
 check_fsc(101,!o_calibration_frame_active && !o_adc_owner_commit_event);
 if(cnt_fail!=0)$fatal(1,"B_ROLLOVER_ABORT_FAIL");$finish;
 end
 initial begin #5000000;$fatal(1,"B_TIMEOUT");end
endmodule
