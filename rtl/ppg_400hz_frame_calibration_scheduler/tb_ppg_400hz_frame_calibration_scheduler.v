`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026-08-16
// Design Name:        PPG 400 Hz Frame Calibration Scheduler Testbench
// Module Name:        tb_ppg_400hz_frame_calibration_scheduler
// Description:        Self-checking scheduler V1.9 verification for FSC-01 through FSC-62.
// Simulations:        ppg_400hz_frame_calibration_scheduler_sim
//
// Referrences:        PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_400hz_frame_calibration_scheduler.v
//
// Version:            V1.9
// Revision Date:      2026-10-08
// History:
// 2026-08-16          V1.3        Erie          Add independent-context FSC-01 through FSC-57 checks.
// 2026-08-24          V1.4        Erie          Fix three issues found while re-running this self-check against the current (V1.6) scheduler RTL after the STOP-drain deadlock fix. (1) This TB predated the DUT's V1.4 addition of i_run_generation, so the port was left entirely undeclared and floated as X at the DUT instantiation, making i_run_generation==state_current[B_INFLIGHT_GENERATION] compare X and fail every case depending on completion matching (17 of 57 cases); fixed by adding the C_RUN_GENERATION_WIDTH parameter, declaring/connecting i_run_generation and driving it at a fixed constant in drive_defaults (none of FSC-01 through FSC-57 exercise cross-generation rejection; that remains a coverage gap, not newly added here). (2) FSC-33's manual late-DONE drive raced against the still-active background auto-done generator: flag_auto_done_enable was left on, so its every-cycle non-blocking i_adc_transaction_complete_event<=1'b0 default silently overwrote the test's own blocking drive of the same signal at the same edge, so the DUT never actually sampled the manual completion pulse as 1; fixed by disabling flag_auto_done_enable before the manual drive. (3) FSC-44 asserted the pre-V1.6 behavior that a plain i_run_enable==0 (no STOP/abort) immediately clears B_FRAME_ACTIVE; V1.6 intentionally changed this so only abort clears it immediately, letting an already-open macro frame drain via natural tick advance per contract section 16.3 — fixed by asserting the still-valid immediate property (no new owner commit, frame legitimately stays active) and then waiting for the frame to reach MACRO_LAST_TICK to confirm it actually does drain and clear on its own, rather than weakening the check.
// 2026-08-24          V1.5        Erie          Add FSC-58/59, the first real coverage for scheduler RTL V1.7's newly-implemented receiver-side calibration eligibility check (section 9.1). Each drives an otherwise-legal AMB_CAL or DCS_CAL payload (correct frame_type/color/precision) but with an illegal i_run_profile (CHARACTERIZATION) or i_input_source (EXTERNAL_TEST_CURRENT) respectively, watches o_calibration_sample_ready continuously for 700 cycles (past local tick 0 and the retry window) to confirm it never asserts even once, and confirms zero owner commits, zero waveform fires, and o_protocol_error_sticky asserted. The contract's own self-check table has listed a "FSC-17 | calibration request eligibility and buffering" case since this file's creation, but no such case has ever actually existed here (the real FSC-17 checks an unrelated RED-only owner-commit count); FSC-58/59 are new cases, not a restoration of a regressed one.
// 2026-09-30          V1.6        Erie          TB maintenance (no RTL change). Found by the 2026-09-30 regression baseline (REGRESSION_BASELINE_20260930.md section 6.1): FSC-15 failed because this TB never connected the i_owner_q3_window_closed input added by scheduler contract V1.8 (2026-08-30, LFA-06 fix); the floating Z kept flag_completion_success from ever being 1, so no NORMAL frame ever completed. Tied it to constant 1'b1: this restores the pre-V1.8 behaviour in which the owner's Q3 window always counts as already closed, which is exactly the environment every FSC case was written against; the Q3 gating itself is covered at system level by the 19-TB LFA-06 evidence and is intentionally not re-tested here. With the port floating, FSC-34 (cnt_normal_complete==0) also passed vacuously; it is now a real check. Also connected the SID-05 output o_cal_owner_deadline_event (2026-09-18) to an observation-only wire; no new assertion (the tick-248 deadline test is a separate task). Result: FSC-01 through FSC-59 pass=59 fail=0 (xsim and iverilog).
// 2026-10-01          V1.7        Erie          Task C (TASKC_TICK248_P2S_20261001.md): add FSC-60..62, the SID-05 unit assertions for o_cal_owner_deadline_event, matching scheduler RTL V1.9 (event masked by a same-cycle owner commit). In the first calibration subframe the owner is held off with i_adc_owner_ready=0 and released at a negedge so the commit lands exactly on a chosen local tick. FSC-60: commit at tick 248 (legal on-time commit) -> one commit at local tick 248, zero deadline events, no owner-deadline sticky. FSC-61: commit at tick 247 -> same, commit at 247. FSC-62: never released -> exactly one deadline-event cycle, at tick 248, not coincident with a commit, zero commits, o_owner_deadline_timeout_sticky set (the pre-existing SID-05 behaviour). The event is counted by a new always block sampling at posedge, i.e. the value AMI actually samples (stimulus only changes at negedge, registers update in NBA, so the read is race-free). Pass criterion and banner raised from 59 to 62. Negative control: on the pre-fix RTL V1.8 FSC-60 fails (one event coincident with the commit) while FSC-61/62 pass.
// 2026-10-06          V1.8        Erie          ABCD review F-010: add TB-local checks CAL-ROLLOVER-ABORT and CAL-ROLLOVER-STOP (task check_local; no FSC-nn number is taken). With a level-held AMB calibration request, abort or STOP-ack is applied on tick 4999 of the second CAL macro frame; the scheduler must be idle within 4 cycles, frame_id must settle at 2 (natural end of frame 1) and stay there, and no new macro frame, owner or waveform may appear for 6000 cycles. Pass criterion 62 -> 64; banner unchanged. Negative control: scheduler V1.9 without the lifecycle term goes idle only after 5000 cycles at frame 3, both checks FAIL.
// 2026-10-08          V1.9        Erie          Owner-lifecycle round (OWNER_LIFECYCLE_ROUND_20261007) step 3: inputs i_idac_boundary_request and i_adc_transaction_lost_event are now TB regs; new TB-local checks LOST-REL (matching void releases B_INFLIGHT, FRAME_FAILED), LOST-MISM (unmatched void -> COMPLETION_MISMATCH), L1-NOREPEND (no macro-end re-pend while B_INFLIGHT), L4-EXPIRE / L4-ONTIME (candidate expiry after the deadline vs on-time commit), L3-IDLEBND / L3-NOEXTRA (one-shot idle IDAC boundary). Pass gate 64 -> 71.
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
// 当前版本:           V1.9
// 修订日期:           2026年10月08日
// 修订历史:
// 2026-08-16          V1.3        Erie          覆盖FSC-01至FSC-57及真实事务完成释放。
// 2026-08-24          V1.4        Erie          拿V1.6 scheduler（STOP排空死锁修复后）重跑这份自检时发现并修复三个问题。(1)这份TB早于DUT V1.4新增的i_run_generation端口，例化里从未声明也从未连接，导致它在DUT里浮空为X，使i_run_generation==在途owner锁存代际这条比较恒为假，凡是依赖DONE完成匹配的用例全部假失败（57个里17个）；修复：新增C_RUN_GENERATION_WIDTH参数，声明并连接i_run_generation，在drive_defaults里给它一个全程固定常量——FSC-01至FSC-57本来就没有一条测试跨代际拒绝，这次只是把浮空端口接上，不是新增覆盖，跨代际拒绝仍是待补覆盖项。(2)FSC-33手动驱动迟到DONE时，后台自动DONE生成器flag_auto_done_enable还开着，它每拍非阻塞写回的i_adc_transaction_complete_event<=1'b0默认值在同一个时钟沿悄悄覆盖了测试自己的阻塞驱动，DUT从未真正采样到手动置的1；修复：手动驱动前先关掉flag_auto_done_enable。(3)FSC-44断言的是V1.6修复前的行为——纯i_run_enable掉底（无STOP/abort）立即清B_FRAME_ACTIVE；V1.6按合同16.3节故意改成只有abort才立即清，纯run_enable掉底要靠tick自然推进把已经打开的宏帧走完；修复为断言仍然成立的即时性质（没有新owner提交、宏帧合法地保持活动）之后再等到MACRO_LAST_TICK验证它确实会自己走完释放，而不是简单削弱断言
// 2026-08-24          V1.5        Erie          新增FSC-58/59，为scheduler RTL V1.7刚实现的接收端校准资格复核（合同9.1节）拿到第一份真实测试覆盖。两条分别构造一笔payload本身合法的AMB_CAL/DCS_CAL请求（frame_type/颜色/精度都对），但run_profile非法（CHARACTERIZATION）或input_source非法（EXTERNAL_TEST_CURRENT），连续监视o_calibration_sample_ready 700拍（跨过local tick 0和重试窗口）确认它一次都没有出现过，同时确认owner提交次数为0、波形fire次数为0、o_protocol_error_sticky置位。合同自己的自检用例表从这份文件创建起就写着"FSC-17｜校准请求资格与缓冲"，但这条用例从未在这里真正存在过（真实的FSC-17测的是纯RED场景一个无关的owner commit计数）；FSC-58/59是全新用例，不是恢复一条退化的旧用例。
// 2026-09-30          V1.6        Erie          TB维护（不改RTL）。2026-09-30回归基线（REGRESSION_BASELINE_20260930.md第6.1节）发现：FSC-15失败，原因是本TB一直没有连接scheduler合同V1.8（2026-08-30，LFA-06修复）新增的输入i_owner_q3_window_closed；端口浮空为Z，flag_completion_success永远不为1，NORMAL帧永远无法完成。改为恒接1'b1：等于恢复V1.8之前"在途owner的Q3窗口随时算已关闭"的语义，而全部FSC用例正是按这个环境写的；Q3门控本身的覆盖在系统级19-TB的LFA-06证据里，本单元TB有意不重复测试。端口浮空时FSC-34（cnt_normal_complete==0）也属于空过，现在是真实检查。另把SID-05新增输出o_cal_owner_deadline_event（2026-09-18）接到一根仅供观察的wire，不加新断言（tick-248截止测试另行安排）。结果：FSC-01至FSC-59 pass=59 fail=0（xsim与iverilog一致）。
// 2026-10-01          V1.7        Erie          任务C（TASKC_TICK248_P2S_20261001.md）：新增FSC-60~62，即o_cal_owner_deadline_event的SID-05单元断言，对应scheduler RTL V1.9（截止事件被同拍owner提交屏蔽）。在第一个校准子帧内用i_adc_owner_ready=0推迟owner，在下降沿放开，使提交精确落在指定local tick。FSC-60：tick 248提交（合法按时提交）→ 恰好一次提交且在local tick 248，截止事件0次，不置owner截止sticky。FSC-61：tick 247提交 → 同上，提交在247。FSC-62：始终不放开 → 截止事件恰好一个周期、在tick 248、不与提交同拍，提交0次，o_owner_deadline_timeout_sticky置位（SID-05既有行为）。事件由新增的上升沿采样always块计数，即AMI实际采样到的值（激励只在下降沿变化、寄存器在NBA阶段更新，读数无竞争）。通过判据与横幅由59提高到62。负对照：在修复前的RTL V1.8上FSC-60失败（有一次与提交同拍的截止事件），FSC-61/62通过。
// 2026-10-06          V1.8        Erie          ABCD复核F-010：新增TB本地检查CAL-ROLLOVER-ABORT和CAL-ROLLOVER-STOP（check_local任务，不占用FSC编号）。电平保持AMB校准请求，在第二个CAL宏帧tick 4999施加abort或STOP确认；scheduler须在4拍内idle，frame_id停在2（帧1自然结束）并保持，6000拍内不得出现新宏帧、owner或波形。判据62改为64，横幅不变。负对照：去掉生命周期项的V1.9在5000拍后才idle且frame为3，两项均FAIL
// 2026-10-08          V1.9        Erie          owner生命周期轮（OWNER_LIFECYCLE_ROUND_20261007）第三步：输入i_idac_boundary_request与i_adc_transaction_lost_event改为TB寄存器驱动；新增TB本地检查LOST-REL（匹配作废释放B_INFLIGHT并FRAME_FAILED）、LOST-MISM（不匹配作废记COMPLETION_MISMATCH）、L1-NOREPEND（B_INFLIGHT时宏帧末不重挂）、L4-EXPIRE/L4-ONTIME（截止后候选过期与按时提交对照）、L3-IDLEBND/L3-NOEXTRA（空闲IDAC边界只发一次）。判据64改为71。
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
	reg i_idac_boundary_request;   // owner生命周期轮L-3：模拟AMI内IDAC候选待提交请求
	reg i_adc_transaction_lost_event; // owner生命周期轮方案甲：模拟AMI在途owner超时作废单拍
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
	wire o_cal_owner_deadline_event; // SID-05新增校准owner截止事件，V1.7起由FSC-60~62断言

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
	integer cnt_cal_deadline_event; // V1.7：o_cal_owner_deadline_event为1的周期数（上升沿采样） @satisfies: SID-05
	integer cnt_cal_deadline_with_commit; // V1.7：截止事件与owner提交同拍出现的周期数
	reg [C_CAL_TICK_WIDTH - 1:0]reg_last_deadline_local_tick; // V1.7：最近一次截止事件所在的local tick
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
		.i_idac_boundary_request(i_idac_boundary_request), // owner生命周期轮L-3边界请求，既有场景恒为0
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
		.i_adc_transaction_lost_event(i_adc_transaction_lost_event), // owner生命周期轮作废输入，既有场景恒为0
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
		.o_cal_owner_deadline_event(o_cal_owner_deadline_event) // V1.6接线；V1.7起由FSC-60~62断言
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

	// V1.7：SID-05截止事件逐拍观测。在上升沿读取组合输出，即AMI实际采样到的值；激励只在下降沿变化、寄存器在NBA阶段才更新，读数无竞争；复位清零 @satisfies: SID-05
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_cal_deadline_event <= 0;
			cnt_cal_deadline_with_commit <= 0;
			reg_last_deadline_local_tick <= {C_CAL_TICK_WIDTH{1'b0}};
		end else if(o_cal_owner_deadline_event)begin
			cnt_cal_deadline_event <= cnt_cal_deadline_event + 1;
			reg_last_deadline_local_tick <= o_calibration_local_tick;
			if(o_adc_owner_commit_event)begin
				cnt_cal_deadline_with_commit <= cnt_cal_deadline_with_commit + 1;
			end
		end
	end

	always #250 i_clk = ~i_clk;

	// 核对单个FSC编号的布尔检查点，并累计显式通过或失败证据。
	// TB本地命名检查（不占用合同FSC族编号），计入同一通过计数
	task check_local;
		input [8 * 24 - 1:0]i_label;
		input i_condition;
		begin
			if(i_condition)begin
				cnt_pass = cnt_pass + 1;
				$display("PASS %0s", i_label);
			end else begin
				cnt_fail = cnt_fail + 1;
				$display("FAIL %0s cycle=%0d tick=%0d", i_label, cnt_cycle, o_macro_tick);
			end
		end
	endtask

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
			i_idac_boundary_request = 1'b0;
			i_adc_transaction_lost_event = 1'b0;
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

	// V1.7：有上界地在下降沿等待第一个校准子帧的指定local tick，用于把owner提交精确放在该拍 @satisfies: SID-05
	task wait_cal_local_tick_negedge;
		input [C_CAL_TICK_WIDTH - 1:0]i_tick;
		input integer i_limit;
		integer idx;
		begin
			flag_wait_ok = 0;
			for(idx = 0; idx < i_limit; idx = idx + 1)begin
				@(negedge i_clk);
				if(o_calibration_frame_active && (o_calibration_subframe_index == 3'd0) && (o_calibration_local_tick == i_tick))begin
					flag_wait_ok = 1;
					idx = i_limit;
				end
			end
		end
	endtask

	integer idx_rollover_case;               // ABCD F-010：0=abort 1=STOP
	integer idx_rollover_wait;               // ABCD F-010：有界等待索引
	integer cnt_rollover_idle_cycle;         // ABCD F-010：撤销后到idle的拍数
	integer cnt_rollover_owner_base;         // ABCD F-010：撤销时owner提交计数基线
	integer cnt_rollover_wave_base;          // ABCD F-010：撤销时波形fire计数基线
	reg flag_rollover_new_frame;             // ABCD F-010：撤销后出现新宏帧或frame_id变化
	integer idx_olr_wait;                    // owner生命周期轮：有界等待索引
	integer cnt_olr_owner_base;              // owner生命周期轮：场景开始时owner提交计数
	integer cnt_olr_wave_base;               // owner生命周期轮：场景开始时波形fire计数
	integer cnt_olr_frame_base;              // owner生命周期轮：场景开始时宏帧起点计数
	integer cnt_olr_bnd_base;                // owner生命周期轮：场景开始时IDAC边界计数
	integer cnt_olr_nc_base;                 // owner生命周期轮：场景开始时NORMAL完成计数
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_olr_owner_idx; // owner生命周期轮：被作废owner的序号
	reg flag_olr_ok;                         // owner生命周期轮：场景内中间判据
	reg flag_olr_red_late;                   // owner生命周期轮L-4：截止后是否出现RED提交
	// 顺序执行FSC-01至FSC-62场景，检查启动、波形、owner、故障恢复、校准接收端资格和SID-05截止事件语义。
	initial begin
		i_clk = 1'b0;
		i_rstn = 1'b0;
		cnt_pass = 0;
		cnt_fail = 0;

		drive_defaults;
		reset_dut;
		check_fsc(1, !o_transaction_inflight && (o_current_frame_id == 0) && (o_next_sample_index == 0) && !o_protocol_error_sticky);

		pulse_start;
		repeat(2) @(posedge i_clk);
		check_fsc(2, cnt_startup_boundary == 1);
		check_fsc(3, (cnt_frame_start == 0) && (o_next_sample_index == 0) && !o_transaction_inflight);
		wait_frame_start(20);
		check_fsc(4, flag_wait_ok && o_normal_frame_active && (o_macro_tick == 0));
		wait_owner_count(1, 20);
		check_fsc(5, flag_wait_ok && (cnt_wave_fire == 1) && (reg_last_wave_tick == 0) && !reg_last_wave_color);
		check_fsc(6, (reg_last_owner_tick == 1) && !reg_last_owner_color && (reg_last_owner_sample == 0));
		check_fsc(7, (reg_last_owner_type == FRAME_TYPE_NORMAL) && (reg_last_owner_amb == 8'h21) && (reg_last_owner_dc == 8'h43));
		check_fsc(8, (reg_last_owner_amb_epoch == 4'h2) && (reg_last_owner_dc_epoch == 4'h4));
		wait_owner_count(2, 220);
		check_fsc(9, flag_wait_ok && (cnt_wave_fire == 2) && (reg_last_wave_tick == 160) && reg_last_wave_color);
		check_fsc(10, (reg_last_owner_tick == 161) && reg_last_owner_color && (reg_last_owner_sample == 1));
		check_fsc(11, (reg_last_owner_frame == 0) && (reg_last_wave_frame == 0) && (reg_last_owner_dc == 8'h65));
		check_fsc(12, reg_last_wave_leddac == 8'h29);
		wait_macro_tick(13'd4760, 5000);
		check_fsc(13, flag_wait_ok && (cnt_idac_boundary >= 1) && (cnt_startup_boundary == 1));
		wait_frame_start(300);
		@(posedge i_clk);
		check_fsc(14, flag_wait_ok && ((reg_frame_period == 5000) || (reg_frame_period == 5001)));
		check_fsc(15, (cnt_normal_complete == 1) && (o_next_sample_index == 2));

		drive_defaults;
		i_optical_mode = OPTICAL_RED;
		reset_dut;
		pulse_start;
		wait_frame_start(20);
		wait_owner_count(1, 20);
		check_fsc(16, flag_wait_ok && !reg_last_owner_color && (cnt_wave_fire == 1) && (reg_last_wave_leddac == 8'h17));
		wait_macro_tick(13'd200, 260);
		check_fsc(17, cnt_owner_commit == 1);

		drive_defaults;
		i_optical_mode = OPTICAL_IR;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 220);
		check_fsc(18, flag_wait_ok && reg_last_owner_color && (reg_last_wave_tick == 160) && (reg_last_owner_tick == 161));

		drive_defaults;
		i_optical_mode = OPTICAL_OFF;
		reset_dut;
		pulse_start;
		wait_frame_start(20);
		wait_macro_tick(13'd300, 400);
		check_fsc(19, flag_wait_ok && (cnt_owner_commit == 0) && (cnt_wave_fire == 0));

		drive_defaults;
		i_active_precision_mode = 1'b1;
		reset_dut;
		pulse_start;
		wait_owner_count(2, 220);
		check_fsc(20, flag_wait_ok && reg_last_owner_precision && reg_last_wave_precision);
		check_fsc(21, (reg_last_owner_tick == 161) && (reg_last_wave_tick == 160));

		drive_defaults;
		i_switch_hold_new_transaction = 1'b1;
		reset_dut;
		pulse_start;
		wait_frame_start(20);
		wait_macro_tick(13'd300, 400);
		check_fsc(22, (cnt_frame_start == 0) && (cnt_owner_commit == 0) && (cnt_wave_fire == 0));

		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_calibration_frame_type = FRAME_TYPE_AMB;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 40);
		i_calibration_sample_valid = 1'b0;
		check_fsc(23, flag_wait_ok && (reg_last_owner_type == FRAME_TYPE_AMB) && !reg_last_owner_precision && !reg_last_owner_color);
		check_fsc(24, (reg_last_wave_local_tick == 0) && (reg_last_owner_local_tick == 1) && (reg_last_owner_dc == 0));
		wait_macro_tick(13'd625, 800);
		check_fsc(25, flag_wait_ok && (o_calibration_local_tick == 0) && (o_calibration_subframe_index == 1));

		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_calibration_frame_type = FRAME_TYPE_DCS;
		i_calibration_color_ir = 1'b0;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 40);
		check_fsc(26, flag_wait_ok && (reg_last_owner_type == FRAME_TYPE_DCS) && !reg_last_owner_color && (reg_last_owner_dc == 8'h43));

		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_calibration_frame_type = FRAME_TYPE_DCS;
		i_calibration_color_ir = 1'b1;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 40);
		check_fsc(27, flag_wait_ok && (reg_last_owner_type == FRAME_TYPE_DCS) && reg_last_owner_color && (reg_last_owner_dc == 8'h65));

		drive_defaults;
		i_waveform_context_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_macro_tick(13'd10, 40);
		check_fsc(28, flag_wait_ok && o_launch_timeout_sticky && (cnt_owner_commit == 0));

		drive_defaults;
		i_adc_owner_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_macro_tick(13'd284, 340);
		check_fsc(29, flag_wait_ok && o_owner_deadline_timeout_sticky && (cnt_owner_commit == 0));

		drive_defaults;
		i_optical_mode = OPTICAL_IR;
		i_adc_owner_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_macro_tick(13'd444, 520);
		check_fsc(30, flag_wait_ok && o_owner_deadline_timeout_sticky && (cnt_owner_commit == 0));

		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_normal_measurement_eligible = 1'b0;
		i_adc_owner_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_macro_tick(13'd260, 320);
		check_fsc(31, flag_wait_ok && o_owner_deadline_timeout_sticky && (cnt_owner_commit == 0));

		drive_defaults;
		i_optical_mode = OPTICAL_RED;
		flag_inject_wrong_done = 1'b1;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 30);
		repeat(12) @(posedge i_clk);
		flag_inject_wrong_done = 1'b0;
		check_fsc(32, o_completion_mismatch_sticky && o_transaction_inflight);
		// 停用后台自动DONE生成器再手动驱动，否则它每拍非阻塞写回0会和这里的
		// 阻塞驱动在同一个时钟沿竞争，DUT永远采样不到手动置的1
		flag_auto_done_enable = 1'b0;
		i_adc_complete_sample_index = reg_last_owner_sample;
		i_adc_transaction_success = 1'b0;
		i_adc_transaction_complete_event = 1'b1;
		@(posedge i_clk);
		i_adc_transaction_complete_event = 1'b0;
		@(posedge i_clk);
		check_fsc(33, !o_transaction_inflight);
		check_fsc(34, cnt_normal_complete == 0);

		drive_defaults;
		i_optical_mode = OPTICAL_RED;
		flag_auto_done_enable = 1'b0;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 30);
		i_stop_ack_event = 1'b1;
		@(posedge i_clk);
		i_stop_ack_event = 1'b0;
		i_adc_complete_sample_index = reg_last_owner_sample;
		i_adc_transaction_complete_event = 1'b1;
		@(posedge i_clk);
		i_adc_transaction_complete_event = 1'b0;
		@(posedge i_clk);
		check_fsc(35, !o_transaction_inflight && !o_normal_frame_complete_event);
		check_fsc(36, !o_scheduler_idle || (cnt_owner_commit == 1));

		drive_defaults;
		i_optical_mode = OPTICAL_RED;
		i_transaction_start_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_macro_tick(13'd10, 40);
		i_control_abort_event = 1'b1;
		@(posedge i_clk);
		i_control_abort_event = 1'b0;
		check_fsc(37, (o_next_sample_index == 0) && !o_transaction_inflight);

		drive_defaults;
		i_ami_fault_blocking = 1'b1;
		reset_dut;
		pulse_start;
		repeat(20) @(posedge i_clk);
		check_fsc(38, (cnt_startup_boundary == 0) && (cnt_frame_start == 0));

		drive_defaults;
		i_ssw_fault_blocking = 1'b1;
		reset_dut;
		pulse_start;
		repeat(20) @(posedge i_clk);
		check_fsc(39, (cnt_startup_boundary == 0) && (cnt_frame_start == 0));

		drive_defaults;
		reset_dut;
		pulse_start;
		wait_frame_start(20);
		i_leddac_r_code = 8'haa;
		i_leddac_ir_code = 8'h55;
		wait_owner_count(2, 220);
		check_fsc(40, reg_last_wave_leddac == 8'h29);
		check_fsc(41, (reg_last_owner_sample == 1) && (cnt_owner_commit == 2));

		drive_defaults;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 30);
		check_fsc(42, (i_transaction_start_fire == o_adc_owner_commit_event) && (o_next_sample_index == 1));
		check_fsc(43, !o_transaction_inflight || (cnt_owner_commit == 1));

		drive_defaults;
		reset_dut;
		pulse_start;
		wait_frame_start(20);
		i_run_enable = 1'b0;
		repeat(4) @(posedge i_clk);
		// 按V1.6合同16.3节：纯run_enable掉底（无STOP/abort）不再立即清FRAME_ACTIVE，
		// 已经打开的宏帧窗口必须靠tick自然推进到MACRO_LAST_TICK才收尾；这里先确认
		// 掉底后没有新owner产生、宏帧仍然合法地处于"draining"而不是被强制清零，
		// 再等到自然末拍验证它确实会自己走完释放，不是永久卡住
		flag_case_ok = (cnt_owner_commit == 0) && o_normal_frame_active;
		wait_macro_tick(13'd4999, 5010);
		@(posedge i_clk);
		check_fsc(44, flag_case_ok && flag_wait_ok && (cnt_owner_commit == 0) && !o_normal_frame_active);

		drive_defaults;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 30);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		i_diag_clear_event = 1'b0;
		check_fsc(45, !o_protocol_error_sticky && !o_completion_mismatch_sticky);

		drive_defaults;
		i_optical_mode = OPTICAL_RED;
		flag_auto_done_enable = 1'b0;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 30);
		i_rstn = 1'b0;
		#100;
		check_fsc(46, !o_transaction_inflight && (o_next_sample_index == 0) && !o_launch_timeout_sticky);
		i_rstn = 1'b1;

		drive_defaults;
		i_ami_fault_blocking = 1'b1;
		reset_dut;
		pulse_start;
		repeat(4) @(posedge i_clk);
		i_ami_fault_blocking = 1'b0;
		repeat(4) @(posedge i_clk);
		pulse_start;
		wait_frame_start(20);
		check_fsc(47, (cnt_startup_boundary >= 1) && (cnt_frame_start >= 1));

		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		wait_macro_tick(13'd385, 450);
		@(posedge i_clk);
		check_fsc(48, flag_wait_ok && (cnt_cal_boundary >= 1));

		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 40);
		check_fsc(49, flag_wait_ok && (reg_last_owner_frame == 0) && (reg_last_owner_sample == 0));

		drive_defaults;
		reset_dut;
		pulse_start;
		wait_frame_start(20);
		wait_owner_count(2, 220);
		check_fsc(50, (cnt_wave_fire == 2) && (cnt_owner_commit == 2) && (cnt_done >= 1));
		check_fsc(51, (reg_last_owner_frame == reg_last_wave_frame) && (reg_last_owner_sample == 1));

		drive_defaults;
		reset_dut;
		pulse_start;
		wait_frame_start(20);
		wait_macro_tick(13'd300, 400);
		check_fsc(52, (cnt_startup_boundary == 1) && (cnt_macro_boundary == 0));

		drive_defaults;
		i_optical_mode = OPTICAL_RED;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 30);
		i_control_abort_event = 1'b1;
		@(posedge i_clk);
		i_control_abort_event = 1'b0;
		pulse_start;
		wait_frame_start(20);
		@(posedge i_clk);
		check_fsc(53, (cnt_startup_boundary >= 2) && (cnt_frame_start >= 1));

		drive_defaults;
		i_stop_ack_event = 1'b1;
		reset_dut;
		pulse_start;
		repeat(10) @(posedge i_clk);
		check_fsc(54, (cnt_startup_boundary == 0) && (cnt_frame_start == 0));

		drive_defaults;
		reset_dut;
		pulse_start;
		wait_frame_start(20);
		wait_macro_tick(13'd4999, 5200);
		check_fsc(55, flag_wait_ok && (o_safe_frame_id == (o_current_frame_id + 1)));

		drive_defaults;
		i_optical_mode = OPTICAL_RED;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 30);
		check_fsc(56, (reg_last_owner_type == FRAME_TYPE_NORMAL) && !reg_last_owner_color && (reg_last_owner_precision == 0));

		drive_defaults;
		reset_dut;
		pulse_start;
		wait_owner_count(2, 220);
		check_fsc(57, flag_wait_ok && !o_scheduler_local_fault_blocking && !o_protocol_error_sticky);

		// FSC-58/59：合同9.1节接收端资格负向覆盖——之前这条只停留在合同文档，
		// 从未真正实现或测试过（i_run_profile在RTL里是死端口，i_input_source
		// 只用于诊断锁存）；本轮补上flag_calibration_request_valid里的
		// run_profile/input_source两项后，这里加真实用例验证：payload本身合法
		// （AMB_CAL/DCS_CAL、SAR9、颜色正确）但run_profile或input_source非法时，
		// o_calibration_sample_ready必须全程为0（不是事后才置协议错误），
		// 不得建立任何波形/owner/pending，且o_protocol_error_sticky必须置位
		drive_defaults;
		i_run_profile = 1'b1; // CHARACTERIZATION，payload其余字段合法
		i_calibration_sample_valid = 1'b1;
		i_calibration_frame_type = FRAME_TYPE_AMB;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		flag_ready_ever_seen = 1'b0;
		for(idx_ready_watch = 0; idx_ready_watch < 700; idx_ready_watch = idx_ready_watch + 1)begin
			@(posedge i_clk);
			if(o_calibration_sample_ready)begin
				flag_ready_ever_seen = 1'b1;
			end
		end
		i_calibration_sample_valid = 1'b0;
		check_fsc(58, !flag_ready_ever_seen && (cnt_owner_commit == 0) && (cnt_wave_fire == 0) && o_protocol_error_sticky);

		drive_defaults;
		i_input_source = 1'b1; // EXTERNAL_TEST_CURRENT，payload其余字段合法
		i_calibration_sample_valid = 1'b1;
		i_calibration_frame_type = FRAME_TYPE_DCS;
		i_calibration_color_ir = 1'b0;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		flag_ready_ever_seen = 1'b0;
		for(idx_ready_watch = 0; idx_ready_watch < 700; idx_ready_watch = idx_ready_watch + 1)begin
			@(posedge i_clk);
			if(o_calibration_sample_ready)begin
				flag_ready_ever_seen = 1'b1;
			end
		end
		i_calibration_sample_valid = 1'b0;
		check_fsc(59, !flag_ready_ever_seen && (cnt_owner_commit == 0) && (cnt_wave_fire == 0) && o_protocol_error_sticky);

		// FSC-60~62（V1.7，SID-05截止事件单元断言）：第一个校准子帧内用i_adc_owner_ready
		// 推迟owner，在下降沿放开，使提交精确落在指定local tick。合同4.5/10.3节：owner不得
		// 晚于tick 248提交，截止事件只在截止点到达仍未提交时回报。
		// FSC-60：owner恰在local tick 248提交属合法按时提交，不得产生截止事件或超时诊断 @satisfies: SID-05
		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_normal_measurement_eligible = 1'b0;
		i_adc_owner_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_cal_local_tick_negedge(10'd248, 400);
		flag_case_ok = flag_wait_ok;
		i_adc_owner_ready = 1'b1;
		wait_macro_tick(13'd260, 40);
		check_fsc(60, flag_case_ok && flag_wait_ok && (cnt_owner_commit == 1) && (reg_last_owner_local_tick == 10'd248) && (reg_last_owner_type == FRAME_TYPE_AMB) && (cnt_cal_deadline_event == 0) && !o_owner_deadline_timeout_sticky);

		// FSC-61：owner在local tick 247提交，截止之前的正常提交，同样不得产生截止事件 @satisfies: SID-05
		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_normal_measurement_eligible = 1'b0;
		i_adc_owner_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_cal_local_tick_negedge(10'd247, 400);
		flag_case_ok = flag_wait_ok;
		i_adc_owner_ready = 1'b1;
		wait_macro_tick(13'd260, 40);
		check_fsc(61, flag_case_ok && flag_wait_ok && (cnt_owner_commit == 1) && (reg_last_owner_local_tick == 10'd247) && (cnt_cal_deadline_event == 0) && !o_owner_deadline_timeout_sticky);

		// FSC-62：owner过tick 248仍未提交，截止事件恰好一个周期、落在tick 248且不与提交同拍，超时诊断照旧置位 @satisfies: SID-05
		drive_defaults;
		i_calibration_sample_valid = 1'b1;
		i_normal_measurement_eligible = 1'b0;
		i_adc_owner_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_cal_local_tick_negedge(10'd248, 400);
		flag_case_ok = flag_wait_ok;
		wait_macro_tick(13'd260, 40);
		check_fsc(62, flag_case_ok && flag_wait_ok && (cnt_owner_commit == 0) && (cnt_cal_deadline_event == 1) && (cnt_cal_deadline_with_commit == 0) && (reg_last_deadline_local_tick == 10'd248) && o_owner_deadline_timeout_sticky);

		// CAL-ROLLOVER-ABORT / CAL-ROLLOVER-STOP（ABCD F-010，TB本地名）：电平保持的校准请求使CAL宏帧逐帧滚动；
		// 第二个CAL宏帧的最后一拍（tick 4999）与abort或STOP确认同拍时，滚动覆盖不得把主FSM已清除的帧上下文
		// 重新置回：必须在4拍内回到idle；tick 4999是帧1的真实末拍，frame_id按FSC-26自然进到2后保持不变（缺陷时滚入的多余
		// CAL帧会再走5000拍并跳到3），此后6000拍内不得出现新的宏帧、owner或波形
		for(idx_rollover_case = 0; idx_rollover_case < 2; idx_rollover_case = idx_rollover_case + 1)begin
			drive_defaults;
			i_normal_measurement_eligible = 1'b0;
			reset_dut;
			pulse_start;
			@(negedge i_clk);
			i_calibration_sample_valid = 1'b1; // 电平保持请求，模拟周期重检/启动搜索期间AMI的保持行为
			i_calibration_frame_type = FRAME_TYPE_AMB;
			flag_case_ok = 1'b0;
			for(idx_rollover_wait = 0; idx_rollover_wait < 12000; idx_rollover_wait = idx_rollover_wait + 1)begin
				if(o_calibration_frame_active && (o_current_frame_id == 1) && (o_macro_tick == 13'd4999))begin
					flag_case_ok = 1'b1;
					idx_rollover_wait = 12000;
				end else begin
					@(negedge i_clk);
				end
			end
			if(idx_rollover_case == 0) i_control_abort_event = 1'b1; else i_stop_ack_event = 1'b1; // 与CAL末拍同拍撤销
			@(negedge i_clk);
			i_control_abort_event = 1'b0;
			i_stop_ack_event = 1'b0;
			i_run_enable = 1'b0;           // manager在STOP/abort后离开RUN
			cnt_rollover_owner_base = cnt_owner_commit;
			cnt_rollover_wave_base = cnt_wave_fire;
			cnt_rollover_idle_cycle = -1;
			flag_rollover_new_frame = 1'b0;
			for(idx_rollover_wait = 0; idx_rollover_wait < 6000; idx_rollover_wait = idx_rollover_wait + 1)begin
				if(o_scheduler_idle && (cnt_rollover_idle_cycle < 0)) cnt_rollover_idle_cycle = idx_rollover_wait;
				if(o_macro_frame_start_event || (o_current_frame_id != 2)) flag_rollover_new_frame = 1'b1;
				@(negedge i_clk);
			end
			if(idx_rollover_case == 0)begin
				check_local("CAL-ROLLOVER-ABORT", flag_case_ok && (cnt_rollover_idle_cycle >= 0) && (cnt_rollover_idle_cycle < 4) && !flag_rollover_new_frame &&
					!o_calibration_frame_active && (cnt_owner_commit == cnt_rollover_owner_base) && (cnt_wave_fire == cnt_rollover_wave_base));
			end else begin
				check_local("CAL-ROLLOVER-STOP", flag_case_ok && (cnt_rollover_idle_cycle >= 0) && (cnt_rollover_idle_cycle < 4) && !flag_rollover_new_frame &&
					!o_calibration_frame_active && (cnt_owner_commit == cnt_rollover_owner_base) && (cnt_wave_fire == cnt_rollover_wave_base));
			end
			$display("CAL_ROLLOVER_CANCEL case=%0d idle_after=%0d frame=%0d", idx_rollover_case, cnt_rollover_idle_cycle, o_current_frame_id);
		end

		// ===== owner生命周期轮（OWNER_LIFECYCLE_ROUND_20261007）调度器单元检查，全部TB本地名 =====
		// LOST-REL（方案甲作废释放）：双光NORMAL，RED owner提交后不给DONE；tick 100送一拍序号匹配的作废，
		// 在途必须释放、不置错配、不置RED完成；IR在160接管后照常提交；本帧被判失败，不产生NORMAL完成
		drive_defaults;
		flag_auto_done_enable = 1'b0;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 6000);
		flag_olr_ok = flag_wait_ok && o_transaction_inflight && (reg_last_owner_color == 1'b0);
		reg_olr_owner_idx = reg_last_owner_sample;
		cnt_olr_nc_base = cnt_normal_complete;
		wait_macro_tick(13'd100, 400);
		@(negedge i_clk);
		i_adc_complete_sample_index = reg_olr_owner_idx;
		i_adc_transaction_lost_event = 1'b1;
		@(negedge i_clk);
		i_adc_transaction_lost_event = 1'b0;
		flag_olr_ok = flag_olr_ok && !o_transaction_inflight && !o_completion_mismatch_sticky && !o_scheduler_local_fault_blocking &&
			inst_ppg_400hz_frame_calibration_scheduler.state_current[inst_ppg_400hz_frame_calibration_scheduler.B_FRAME_FAILED];
		flag_auto_done_enable = 1'b1;
		wait_owner_count(2, 600);
		flag_olr_ok = flag_olr_ok && flag_wait_ok && (reg_last_owner_color == 1'b1);
		wait_macro_tick(13'd4999, 6000);
		repeat(3) @(posedge i_clk);
		check_local("LOST-REL", flag_olr_ok && (cnt_normal_complete == cnt_olr_nc_base)); // 服务方案甲：作废只释放、不计成功，帧判失败

		// LOST-MISM：序号不符的作废事件不得释放在途owner，按DONE错配置阻断
		drive_defaults;
		flag_auto_done_enable = 1'b0;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 6000);
		flag_olr_ok = flag_wait_ok;
		@(negedge i_clk);
		i_adc_complete_sample_index = reg_last_owner_sample + 16'd5;
		i_adc_transaction_lost_event = 1'b1;
		@(negedge i_clk);
		i_adc_transaction_lost_event = 1'b0;
		check_local("LOST-MISM", flag_olr_ok && o_transaction_inflight && o_completion_mismatch_sticky && o_scheduler_local_fault_blocking); // 服务方案甲：身份不符的作废按错配处理

		// L1-NOREPEND（L-1）：一笔校准请求握手后其owner在sf0提交且始终无DONE，宏帧末不得把这笔已成owner的请求
		// 重新挂起，因此此后没有新的宏帧、波形或owner（旧逻辑会在下一宏帧sf0再发一个注定错绑的校准波形）
		drive_defaults;
		flag_auto_done_enable = 1'b0;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		@(negedge i_clk);
		i_calibration_sample_valid = 1'b1;
		flag_olr_ok = 1'b0;
		for(idx_olr_wait = 0; idx_olr_wait < 400; idx_olr_wait = idx_olr_wait + 1)begin
			if(o_calibration_sample_ready)begin
				flag_olr_ok = 1'b1;
				idx_olr_wait = 400;
			end
			@(negedge i_clk);
		end
		i_calibration_sample_valid = 1'b0; // AMI握手后撤销valid，在途期间不再发新请求
		wait_owner_count(1, 1000);
		flag_olr_ok = flag_olr_ok && flag_wait_ok;
		cnt_olr_frame_base = cnt_frame_start;
		cnt_olr_wave_base = cnt_wave_fire;
		wait_macro_tick(13'd4999, 6000);
		repeat(3000) @(posedge i_clk);
		check_local("L1-NOREPEND", flag_olr_ok && o_transaction_inflight && (cnt_frame_start == cnt_olr_frame_base) && (cnt_wave_fire == cnt_olr_wave_base) && (cnt_owner_commit == 1) &&
			!inst_ppg_400hz_frame_calibration_scheduler.state_current[inst_ppg_400hz_frame_calibration_scheduler.B_CAL_REQ_PENDING]); // L-1 @satisfies: FSC-17

		// L4-EXPIRE（L-4）：帧0的IR owner跨入帧1无DONE，帧1的RED在tick 0接管后因在途被挡；帧1 tick 300才送旧IR的
		// 匹配DONE，此后RED候选已过截止283，不得再提交RED，只能截止收尾；随后的提交只能是本帧IR
		drive_defaults;
		reset_dut;
		pulse_start;
		wait_owner_count(1, 6000); // 帧0 RED
		wait_owner_count(2, 6000); // 帧0 IR
		flag_auto_done_enable = 1'b0;
		reg_olr_owner_idx = reg_last_owner_sample;
		flag_olr_ok = flag_wait_ok && (reg_last_owner_color == 1'b1);
		wait_frame_start(6000);
		flag_olr_ok = flag_olr_ok && flag_wait_ok && o_transaction_inflight;
		wait_macro_tick(13'd300, 400);
		cnt_olr_owner_base = cnt_owner_commit;
		@(negedge i_clk);
		i_adc_complete_sample_index = reg_olr_owner_idx;
		i_adc_transaction_complete_event = 1'b1;
		@(negedge i_clk);
		i_adc_transaction_complete_event = 1'b0;
		flag_olr_red_late = 1'b0;
		for(idx_olr_wait = 0; idx_olr_wait < 200; idx_olr_wait = idx_olr_wait + 1)begin
			@(posedge i_clk);
			if(o_adc_owner_commit_event && !o_adc_owner_color_ir) flag_olr_red_late = 1'b1;
		end
		check_local("L4-EXPIRE", flag_olr_ok && !flag_olr_red_late && (cnt_owner_commit == cnt_olr_owner_base + 1) && (reg_last_owner_color == 1'b1) && o_owner_deadline_timeout_sticky); // L-4 @satisfies: FSC-46, FSC-49

		// L4-ONTIME（L-4对照）：RED owner恰在截止相位tick 283提交仍属按时，不报截止
		drive_defaults;
		i_adc_owner_ready = 1'b0;
		reset_dut;
		pulse_start;
		wait_frame_start(6000);
		flag_olr_ok = flag_wait_ok;
		for(idx_olr_wait = 0; idx_olr_wait < 400; idx_olr_wait = idx_olr_wait + 1)begin
			@(negedge i_clk);
			if(o_macro_tick == 13'd283) idx_olr_wait = 400;
		end
		i_adc_owner_ready = 1'b1;
		wait_owner_count(1, 4);
		check_local("L4-ONTIME", flag_olr_ok && flag_wait_ok && (reg_last_owner_tick == 13'd283) && (reg_last_owner_color == 1'b0) && !o_owner_deadline_timeout_sticky); // L-4按时提交对照 @satisfies: FSC-46

		// L3-IDLEBND（L-3）：启动搜索中（NORMAL资格为0）、调度器空闲且没有校准请求时，IDAC候选待提交请求须在数拍内
		// 得到一个IDAC安全边界；TB见到边界即撤销请求（模拟IDAC提交后pending清零），边界只出现一拍
		drive_defaults;
		i_normal_measurement_eligible = 1'b0;
		reset_dut;
		pulse_start;
		repeat(50) @(negedge i_clk);   // START一次性边界已经发布
		cnt_olr_bnd_base = cnt_idac_boundary;
		flag_olr_ok = o_scheduler_idle;
		i_idac_boundary_request = 1'b1;
		flag_wait_ok = 0;
		for(idx_olr_wait = 0; idx_olr_wait < 8; idx_olr_wait = idx_olr_wait + 1)begin
			@(posedge i_clk);
			if(o_idac_code_safe_boundary)begin
				flag_wait_ok = 1;
				idx_olr_wait = 8;
			end
		end
		@(negedge i_clk);
		i_idac_boundary_request = 1'b0;
		repeat(20) @(posedge i_clk);
		check_local("L3-IDLEBND", flag_olr_ok && flag_wait_ok && (cnt_idac_boundary == cnt_olr_bnd_base + 1) && (cnt_frame_start == 0)); // L-3

		// L3-NOEXTRA（L-3对照）：NORMAL资格成立时即使请求一直为1也不得出现空闲边界，一帧内只有宏帧边界一次
		drive_defaults;
		reset_dut;
		pulse_start;
		wait_frame_start(6000);
		i_idac_boundary_request = 1'b1;
		cnt_olr_bnd_base = cnt_idac_boundary;
		wait_frame_start(6000);
		flag_olr_ok = flag_wait_ok;
		wait_frame_start(6000);
		i_idac_boundary_request = 1'b0;
		check_local("L3-NOEXTRA", flag_olr_ok && flag_wait_ok && (cnt_idac_boundary == cnt_olr_bnd_base + 2)); // L-3只在启动搜索空闲期补边界 @satisfies: FSC-38

		$display("FSC-01 through FSC-62: pass=%0d fail=%0d", cnt_pass, cnt_fail);
		if(cnt_fail == 0 && cnt_pass == 71)begin
			$display("ALL FSC-01 THROUGH FSC-62 PASSED");
		end
		$finish;
	end

endmodule
