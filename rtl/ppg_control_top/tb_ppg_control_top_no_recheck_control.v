`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/29
// Design Name:        PPG No-Recheck Cross Control Testbench
// Module Name:        tb_ppg_control_top_no_recheck_control
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_amb_recheck_scheduler.v
//                      ppg_idac_code_controller.v
//                      ppg_dynamic_baseline_cross_detector.v
//                      ppg_coarse_detection_fir.v
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.0
// Revision Date:      2026/08/29
// History:
//    Time               Version       Revised by            Contents
// 2026/08/29            V1.0          Erie                  Create file. Stage 5 Group 9 (NO-RECHECK-CROSS-CONTROL, C25 contract section 9.4.4, NRE-01~06). Confirmed against Group 8's real RTL findings before coding rather than re-deriving from scratch: `ppg_amb_recheck_scheduler.v`'s `flag_period_enabled` unconditionally includes `(i_amb_recheck_interval_frames != 16'd0)` (line 177) -- with `amb_recheck_interval_frames=0`, the completed-macro-frame counter never increments, `flag_interval_hit` can never fire, and every downstream recheck signal (pending/busy/accept/done/failed) is therefore held at its reset value for the entire RUN by construction, not merely "unlikely to happen." This makes NRE-01/02 a direct, mechanical consequence of the interval field itself rather than something requiring careful timing to avoid triggering -- the real verification value is in NRE-03~06: proving the *normal* NORMAL-tracking/FIR-warmup/baseline-cross/SAR15-entry/SAR9-return path genuinely completes through its ordinary evidence-driven mechanism with zero interference, not just that the recheck side stays quiet. Reused Group 8's DUT instantiation, task library (`task_drive_amb_toward_target`/`task_drive_dcs_toward_target`/`task_run_startup_search`/`wait_q3_release`/`drive_real_adc_done`/`make_fixed_raw`), owner-identity-snapshot pattern, and the real physiological generator (`tb_ppg_real_raw_generator.vh`, same C_RAW_PROFILE_NORMAL/nominal-weight setup already proven to produce a real first cross by roughly frame 60-65) verbatim -- this group needed no new driving mechanism, only new continuous background monitors proving *absence* of recheck activity across a real, undisturbed long run. Confirmed `C_ENABLE_TEST_INJECTION` is not needed (same as Group 8, no RRC/NRE clause here needs identity injection either). One continuous SEARCH_TRACK+dual-optical generator-driven RUN (not two episodes like Group 8 -- there is nothing to force here) covers all six IDs: NRE-01/02 via continuous zero-activity monitors on the scheduler's own `o_amb_recheck_pending/accept/busy/o_sequence_done/o_sequence_failed` plus the FIR's and cross detector's own `i_recheck_accept_event/i_recheck_busy` inputs (checked directly at their point of use, not just inferred transitively from the scheduler); NRE-03 via a high-watermark monitor on `cnt_red_sample`/`cnt_ir_sample` that fails if either ever *decreases* before latching full (proving the warmup history is never invalidated mid-course); NRE-04/05 via the same `o_fine_window_start_event`/`o_return_9bit_valid` sticky-capture pattern Group 7's TRK-05 and Group 8 already proved, plus an explicit ordering check that the real cross only forms after both colors' FIR history had already latched full (evidence the cross is built from genuine accumulated history, not some START/reset artifact); NRE-06 via continuing the same driven run further and checking `o_result_frame_id` is observed non-decreasing across every captured result and `amb_epoch_current` (the one epoch field only a real recheck could ever touch during NORMAL, since the tracking fork never writes AMB) stays bit-identical to its post-startup-search value all the way through. Real Vivado 2022.2 xsim run (~5.5 minutes) passed clean on the first attempt with zero bugs found -- the only Stage 5 file so far to do so, consistent with the batching plan's own prediction that this group would be comparatively cheap once Group 8's infrastructure and RTL facts were already proven: `JNT_BASELINE 53/53 PASS`, all six NRE-01~06 IDs pass with real evidence, `NO_RECHECK_CONTROL_TB_PASS result_captures=1627 owner_commit_total=1655`.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月29日
// 设计名称:           PPG无重检穿越控制测试平台
// 模块名称:           tb_ppg_control_top_no_recheck_control
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_amb_recheck_scheduler.v
//                      ppg_idac_code_controller.v
//                      ppg_dynamic_baseline_cross_detector.v
//                      ppg_coarse_detection_fir.v
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.0
// 修订日期:           2026年08月29日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月29日        V1.0          Erie                  创建文件。Stage 5第9组（NO-RECHECK-CROSS-CONTROL，C25合同9.4.4节，NRE-01~06）。动笔前先核实Group8已经确认过的真实RTL事实，不重新从零推导：`ppg_amb_recheck_scheduler.v`的`flag_period_enabled`无条件包含`(i_amb_recheck_interval_frames != 16'd0)`（177行）——`amb_recheck_interval_frames=0`时，已完成宏帧计数器永远不会递增，`flag_interval_hit`永远不可能触发，下游全部重检信号（pending/busy/accept/done/failed）因此在整个RUN期间结构性地保持复位值，不是"碰巧没触发"。这让NRE-01/02本质上是间隔字段本身的直接、机械后果，不需要小心避开触发时机——本组真正的验证价值在NRE-03~06：证明*正常*的NORMAL跟踪/FIR预热/基线穿越/SAR15接管/SAR9回落路径真的通过自己原有的证据驱动机制完整走完、零干扰，不只是"重检那边很安静"。直接复用Group8的DUT例化、task库（`task_drive_amb_toward_target`/`task_drive_dcs_toward_target`/`task_run_startup_search`/`wait_q3_release`/`drive_real_adc_done`/`make_fixed_raw`）、owner身份快照手法，以及真实生理生成器（`tb_ppg_real_raw_generator.vh`，同一套C_RAW_PROFILE_NORMAL/幂次权重配置，历史证据显示第一次真实穿越大约在第60~65帧）——本组不需要任何新的驱动机制，只需要新增几个证明"重检活动确实不存在"的连续后台监视进程。确认本组同样不需要`C_ENABLE_TEST_INJECTION`（和Group8一样，RRC/NRE都没有一条要求身份注入）。用一次连续的SEARCH_TRACK+双光真实生成器RUN（不是Group8那样的两轮episode——这里没有任何东西需要主动构造）覆盖全部六条ID：NRE-01/02用连续零活动监视进程直接盯调度器自己的`o_amb_recheck_pending/accept/busy/o_sequence_done/o_sequence_failed`，以及FIR和穿越检测器自己的`i_recheck_accept_event`/`i_recheck_busy`输入（在真正被消费的那个点直接检查，不只是从调度器信号间接推断）；NRE-03用`cnt_red_sample`/`cnt_ir_sample`的高水位监视——一旦在锁定满窗之前观察到任何一次真实下降就判FAIL（证明预热历史在中途从未被作废）；NRE-04/05复用Group7的TRK-05和Group8已经验证过的`o_fine_window_start_event`/`o_return_9bit_valid`sticky捕获手法，外加一条明确的先后顺序检查——真实穿越只能在两种颜色的FIR历史都已经真实锁满之后才形成（证明穿越是建立在真实累积历史上，不是START/复位的巧合产物）；NRE-06继续同一次驱动跑更久，检查每一笔捕获到的正式结果`o_result_frame_id`都是非递减的，且`amb_epoch_current`（NORMAL态下唯一只有真实重检才可能触碰的epoch字段，NORMAL跟踪fork从不写AMB）从启动搜索完成后的值到跑完全程逐字节保持不变。真实Vivado 2022.2 xsim跑通（约5.5分钟），第一次真实跑就干净PASS、零bug——是目前Stage5唯一一份一次通过的文件，符合批次规划预判"Group6/7/8的基础设施和RTL事实都已经验证过之后，这一组应该相对便宜"：`JNT_BASELINE 53/53 PASS`，全部六条NRE-01~06都拿到真实证据通过，`NO_RECHECK_CONTROL_TB_PASS result_captures=1627 owner_commit_total=1655`。
//
// 复位后跑一次连续的SEARCH_TRACK+双光真实生成器RUN（amb_recheck_interval_frames=0），
// 核对周期重检机制在整个RUN期间结构性完全不介入，NORMAL跟踪/FIR预热/基线穿越/
// SAR15接管/SAR9回落全部通过自己原有的证据驱动机制正常完整走完
module tb_ppg_control_top_no_recheck_control();

	//---------------配置参数区域---------------//
	localparam integer C_FRAME_ID_WIDTH = 16; // 与DUT默认参数一致
	localparam integer C_SAMPLE_INDEX_WIDTH = 16; // 与DUT默认参数一致
	localparam integer C_CONFIG_WIDTH = 1024; // 与DUT默认参数一致
	localparam integer C_CODE_EPOCH_WIDTH = 4; // 与DUT默认参数一致
	localparam integer C_RUN_GENERATION_WIDTH = 8; // 与DUT默认参数一致
	localparam [1:0] ST_CONFIG = 2'b00; // manager CONFIG生命周期编码
	localparam [1:0] ST_READY = 2'b01; // manager READY生命周期编码
	localparam [1:0] ST_RUN = 2'b10; // manager RUN生命周期编码
	localparam [1:0] ST_STOPPING = 2'b11; // manager STOPPING生命周期编码

	localparam [4:0] ST_IDAC_AMB_APPLY = 5'd2; // idac控制器AMB候选等待安全生效
	localparam [4:0] ST_IDAC_AMB_WAIT = 5'd3; // idac控制器请求并评价AMB候选
	localparam [4:0] ST_IDAC_DCS_R_APPLY = 5'd4; // idac控制器红光DC候选等待安全生效
	localparam [4:0] ST_IDAC_DCS_R_WAIT = 5'd5; // idac控制器请求并评价红光DC候选
	localparam [4:0] ST_IDAC_DCS_IR_APPLY = 5'd6; // idac控制器红外DC候选等待安全生效
	localparam [4:0] ST_IDAC_DCS_IR_WAIT = 5'd7; // idac控制器请求并评价红外DC候选
	localparam [4:0] ST_IDAC_NORMAL = 5'd8; // idac控制器启动完成并允许NORMAL跟踪
	localparam [4:0] ST_IDAC_AMB_RECHECK = 5'd9; // idac控制器周期检查当前AMB码（本组不应到达）
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_WAIT = 5'd10; // idac控制器保持DCS重验证请求（本组不应到达）
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_R = 5'd11; // idac控制器检查当前红光DC码（本组不应到达）
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_IR = 5'd12; // idac控制器检查当前红外DC码（本组不应到达）

	localparam integer C_CANDIDATE_GUARD_MAX = 12; // 单阶段候选步数安全上限，8位码空间理论最多8步
	localparam integer C_GENERATOR_FRAME_GUARD = 2000; // 单轮真实穿越/回落搜寻的驱动帧数上限
	localparam integer C_LONG_RUN_EXTRA_FRAMES = 400; // NRE-06额外长跑帧数，穿越/回落之后继续驱动
	localparam time C_SIM_TIMEOUT_NS = 64'd5000000000; // 5秒安全看门狗上限

	localparam [383:0] V5_RESET_PROFILE_REF = {
		14'd0,                                  // reserved_v5复位归零
		1'b0,                                   // peak_valley_config_valid复位不可用
		16'd1000,                               // max_reacquire_frames
		16'd600,                                // max_fine_window_frames
		16'd100,                                // min_peak_to_peak_frames
		16'd20,                                 // min_peak_to_valley_frames
		24'd20,                                 // min_peak_valley_amplitude
		24'd2,                                  // direction_deadband
		4'd3,                                   // valley_confirm_count
		4'd3,                                   // peak_confirm_count
		4'd2,                                   // no_cross_limit
		4'd3,                                   // cross_confirm_count
		16'd19,                                 // lead_max_frames
		16'd17,                                 // lead_min_frames
		32'd131072,                             // cross_hysteresis_q16
		32'sd0,                                 // baseline_delta_q16
		-32'sd8192,                             // slope_max_q16
		-32'sd262144,                           // slope_min_q16
		16'h0800,                               // timing_adjust_ratio_q15
		16'h2000,                               // beta_q15
		16'h199A,                               // alpha_q15
		-32'sd65536,                            // fixed_slope_q16
		1'b1                                    // slope_mode=ADAPTIVE
	};

	//---------------全局时钟与复位信号---------------//
	reg i_clk;
	reg i_rstn;
	reg i_source_clk;
	reg i_source_rstn;

	//---------------V4+V5源域配置信号---------------//
	reg [C_CONFIG_WIDTH - 1:0] i_source_config_snapshot;
	reg i_source_config_update_event;

	//---------------表征source信号---------------//
	reg i_source_characterization_update_valid;
	reg i_source_static_characterization_enable;
	reg [4:0] i_source_test_mux_ctrl;

	//---------------已同步生命周期与诊断信号---------------//
	reg i_start_event;
	reg i_stop_event;
	reg i_diag_clear_event;
	reg i_control_abort_event;

	//---------------物理ADC与模拟边界信号---------------//
	reg [9:0] i_dout_stage1_low;
	reg i_clk_stage1_dout_low_async;
	reg [9:0] i_dout_stage2_low;
	reg i_clk_stage2_dout_low_async;
	reg i_adc_physical_idle;
	reg i_analog_ready;

	//---------------正式结果消费者信号---------------//
	reg i_measurement_result_ready;

	//---------------验证专用异常注入信号---------------//
	reg i_test_inject_enable;
	reg i_test_identity_inject_valid;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] i_test_identity_inject_sample_index;
	reg i_test_invalid_sample_valid;

	//---------------SSW模拟控制原样输出---------------//
	wire o_en_tia_low, o_leden1_low, o_leden2_low, o_en_test;
	wire [7:0] o_leddac;
	wire o_clk_buf_low, o_clk_iref_idac_low, o_clk_9q1_low, o_clk_15q1_low, o_clk_aferst_low;
	wire o_clk_iref_idac_sar9_low, o_clk_iref_idac_sar15_low, o_clk_q2_low, o_clk_q3_low, o_clk_tiaen_low;
	wire o_en_15sar_low, o_en_sar9_amb_low, o_en_sar9_dc_low, o_en_sar9_iref;
	wire o_en_sar15_amb_low, o_en_sar15_dc_low, o_en_sar15_iref;
	wire [7:0] o_idac_sar9ambn_low, o_idac_sar9dcn_low, o_idac_sar15ambn_low, o_idac_sar15dcn_low;
	wire [4:0] o_s_in;
	wire o_clk_2m;

	//---------------AMI正式测量结果输出---------------//
	wire o_measurement_result_valid;
	wire signed [23:0] o_coarse_ppg_value, o_fine_ppg_value;
	wire o_coarse_valid, o_coarse_recovery_calibrated, o_coarse_saturation_low, o_coarse_saturation_high;
	wire o_fine_valid, o_fine_recovery_calibrated, o_fine_saturation_low, o_fine_saturation_high;
	wire signed [11:0] o_calibrated_s1_value;
	wire signed [14:0] o_programmable_15_code;
	wire o_programmable_15_valid;
	wire [7:0] o_result_config_epoch, o_result_coef_epoch, o_result_stage2_coef_epoch, o_result_dc_coef_epoch;
	wire o_result_precision_mode;
	wire [C_FRAME_ID_WIDTH - 1:0] o_result_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_result_sample_index;
	wire o_result_color_ir;
	wire [1:0] o_result_frame_type;
	wire [7:0] o_result_amb_code_snapshot, o_result_dc_code_snapshot;
	wire [C_CODE_EPOCH_WIDTH - 1:0] o_result_amb_code_epoch, o_result_dc_code_epoch;
	wire o_result_sample_valid;

	//---------------V4/V5生命周期ACK与错误输出---------------//
	wire [1:0] o_lifecycle_state;
	wire o_start_ready, o_commit_ack_event, o_start_ack_event, o_stop_ack_event, o_error_event;
	wire o_commit_ack_sticky, o_error_sticky;
	wire [7:0] o_last_error_code, o_schema_version, o_config_epoch, o_coef_epoch, o_stage2_coef_epoch, o_dc_recovery_coef_epoch;

	//---------------调度器/AMI/SSW只读诊断输出---------------//
	wire o_scheduler_idle, o_scheduler_launch_timeout_sticky, o_scheduler_owner_deadline_timeout_sticky;
	wire o_scheduler_completion_mismatch_sticky, o_scheduler_protocol_error_sticky;
	wire o_ami_datapath_empty, o_ami_idac_idle, o_ami_integration_protocol_error_sticky;
	wire o_ssw_wrapper_idle, o_ssw_switch_protocol_error_sticky, o_ssw_transaction_mismatch_sticky;
	wire o_ssw_owner_deadline_timeout_sticky, o_ssw_calibration_timeout_sticky;

	//---------------表征控制source握手与诊断输出---------------//
	wire o_source_characterization_update_ready, o_characterization_control_valid;
	wire o_characterization_control_update_event, o_characterization_control_reject_event;
	wire o_characterization_protocol_error_sticky;

	//---------------验证专用异常注入应答输出---------------//
	wire o_test_identity_inject_ready, o_test_invalid_sample_ready;

	//---------------注册式系统故障/abort监督输出---------------//
	wire o_system_fault_blocking, o_system_abort_event, o_system_stop_request_event, o_system_fault_discard_event;
	wire o_system_fault_cause_valid;
	wire [7:0] o_system_fault_cause;
	wire [3:0] o_system_fault_source;
	wire o_system_fault_identity_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_system_fault_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_system_fault_sample_index;
	wire o_system_fault_color_ir;
	wire [1:0] o_system_fault_frame_type;
	wire o_system_fault_precision;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_system_fault_run_generation;
	wire [15:0] o_system_fault_summary;
	wire o_result_discard_summary_sticky;

	//---------------AMI discard公开观测输出---------------//
	wire o_measurement_result_discard_event;
	wire [1:0] o_measurement_result_discard_reason;
	wire o_measurement_result_discard_identity_valid, o_measurement_result_discard_sample_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_measurement_result_discard_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_measurement_result_discard_sample_index;
	wire o_measurement_result_discard_color_ir;
	wire [1:0] o_measurement_result_discard_frame_type;
	wire o_measurement_result_discard_precision;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_measurement_result_discard_run_generation;

	wire o_detection_discard_event;
	wire [1:0] o_detection_discard_reason;
	wire o_detection_discard_identity_valid, o_detection_discard_sample_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_detection_discard_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_detection_discard_sample_index;
	wire o_detection_discard_color_ir;
	wire [1:0] o_detection_discard_frame_type;
	wire o_detection_discard_precision;
	wire [7:0] o_detection_discard_config_epoch, o_detection_discard_coef_epoch, o_detection_discard_dc_recovery_epoch;
	wire [C_CODE_EPOCH_WIDTH - 1:0] o_detection_discard_amb_code_epoch, o_detection_discard_dc_code_epoch;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_detection_discard_run_generation;

	//---------------自检计数与状态信号---------------//
	integer cnt_error;
	integer cnt_measurement_result_valid;
	reg flag_global_timeout;

	//---------------DUT实例化---------------//
	ppg_control_top
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),
			.C_CONFIG_WIDTH(C_CONFIG_WIDTH),
			.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH),
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH)
		)
		ppg_control_top_Inst(
			.i_clk(i_clk),
			.i_rstn(i_rstn),
			.i_source_clk(i_source_clk),
			.i_source_rstn(i_source_rstn),
			.i_source_config_snapshot(i_source_config_snapshot),
			.i_source_config_update_event(i_source_config_update_event),
			.i_source_characterization_update_valid(i_source_characterization_update_valid),
			.i_source_static_characterization_enable(i_source_static_characterization_enable),
			.i_source_test_mux_ctrl(i_source_test_mux_ctrl),
			.i_start_event(i_start_event),
			.i_stop_event(i_stop_event),
			.i_diag_clear_event(i_diag_clear_event),
			.i_control_abort_event(i_control_abort_event),
			.i_dout_stage1_low(i_dout_stage1_low),
			.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async),
			.i_dout_stage2_low(i_dout_stage2_low),
			.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async),
			.i_adc_physical_idle(i_adc_physical_idle),
			.i_analog_ready(i_analog_ready),
			.i_measurement_result_ready(i_measurement_result_ready),
			.i_test_inject_enable(i_test_inject_enable),
			.i_test_identity_inject_valid(i_test_identity_inject_valid),
			.i_test_identity_inject_sample_index(i_test_identity_inject_sample_index),
			.i_test_invalid_sample_valid(i_test_invalid_sample_valid),
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
			.o_measurement_result_valid(o_measurement_result_valid),
			.o_coarse_ppg_value(o_coarse_ppg_value),
			.o_coarse_valid(o_coarse_valid),
			.o_coarse_recovery_calibrated(o_coarse_recovery_calibrated),
			.o_coarse_saturation_low(o_coarse_saturation_low),
			.o_coarse_saturation_high(o_coarse_saturation_high),
			.o_fine_ppg_value(o_fine_ppg_value),
			.o_fine_valid(o_fine_valid),
			.o_fine_recovery_calibrated(o_fine_recovery_calibrated),
			.o_fine_saturation_low(o_fine_saturation_low),
			.o_fine_saturation_high(o_fine_saturation_high),
			.o_calibrated_s1_value(o_calibrated_s1_value),
			.o_programmable_15_code(o_programmable_15_code),
			.o_programmable_15_valid(o_programmable_15_valid),
			.o_result_config_epoch(o_result_config_epoch),
			.o_result_coef_epoch(o_result_coef_epoch),
			.o_result_stage2_coef_epoch(o_result_stage2_coef_epoch),
			.o_result_dc_coef_epoch(o_result_dc_coef_epoch),
			.o_result_precision_mode(o_result_precision_mode),
			.o_result_frame_id(o_result_frame_id),
			.o_result_sample_index(o_result_sample_index),
			.o_result_color_ir(o_result_color_ir),
			.o_result_frame_type(o_result_frame_type),
			.o_result_amb_code_snapshot(o_result_amb_code_snapshot),
			.o_result_dc_code_snapshot(o_result_dc_code_snapshot),
			.o_result_amb_code_epoch(o_result_amb_code_epoch),
			.o_result_dc_code_epoch(o_result_dc_code_epoch),
			.o_result_sample_valid(o_result_sample_valid),
			.o_lifecycle_state(o_lifecycle_state),
			.o_start_ready(o_start_ready),
			.o_commit_ack_event(o_commit_ack_event),
			.o_start_ack_event(o_start_ack_event),
			.o_stop_ack_event(o_stop_ack_event),
			.o_error_event(o_error_event),
			.o_commit_ack_sticky(o_commit_ack_sticky),
			.o_error_sticky(o_error_sticky),
			.o_last_error_code(o_last_error_code),
			.o_schema_version(o_schema_version),
			.o_config_epoch(o_config_epoch),
			.o_coef_epoch(o_coef_epoch),
			.o_stage2_coef_epoch(o_stage2_coef_epoch),
			.o_dc_recovery_coef_epoch(o_dc_recovery_coef_epoch),
			.o_scheduler_idle(o_scheduler_idle),
			.o_scheduler_launch_timeout_sticky(o_scheduler_launch_timeout_sticky),
			.o_scheduler_owner_deadline_timeout_sticky(o_scheduler_owner_deadline_timeout_sticky),
			.o_scheduler_completion_mismatch_sticky(o_scheduler_completion_mismatch_sticky),
			.o_scheduler_protocol_error_sticky(o_scheduler_protocol_error_sticky),
			.o_ami_datapath_empty(o_ami_datapath_empty),
			.o_ami_idac_idle(o_ami_idac_idle),
			.o_ami_integration_protocol_error_sticky(o_ami_integration_protocol_error_sticky),
			.o_ssw_wrapper_idle(o_ssw_wrapper_idle),
			.o_ssw_switch_protocol_error_sticky(o_ssw_switch_protocol_error_sticky),
			.o_ssw_transaction_mismatch_sticky(o_ssw_transaction_mismatch_sticky),
			.o_ssw_owner_deadline_timeout_sticky(o_ssw_owner_deadline_timeout_sticky),
			.o_ssw_calibration_timeout_sticky(o_ssw_calibration_timeout_sticky),
			.o_source_characterization_update_ready(o_source_characterization_update_ready),
			.o_characterization_control_valid(o_characterization_control_valid),
			.o_characterization_control_update_event(o_characterization_control_update_event),
			.o_characterization_control_reject_event(o_characterization_control_reject_event),
			.o_characterization_protocol_error_sticky(o_characterization_protocol_error_sticky),
			.o_test_identity_inject_ready(o_test_identity_inject_ready),
			.o_test_invalid_sample_ready(o_test_invalid_sample_ready),
			.o_system_fault_blocking(o_system_fault_blocking),
			.o_system_abort_event(o_system_abort_event),
			.o_system_stop_request_event(o_system_stop_request_event),
			.o_system_fault_discard_event(o_system_fault_discard_event),
			.o_system_fault_cause_valid(o_system_fault_cause_valid),
			.o_system_fault_cause(o_system_fault_cause),
			.o_system_fault_source(o_system_fault_source),
			.o_system_fault_identity_valid(o_system_fault_identity_valid),
			.o_system_fault_frame_id(o_system_fault_frame_id),
			.o_system_fault_sample_index(o_system_fault_sample_index),
			.o_system_fault_color_ir(o_system_fault_color_ir),
			.o_system_fault_frame_type(o_system_fault_frame_type),
			.o_system_fault_precision(o_system_fault_precision),
			.o_system_fault_run_generation(o_system_fault_run_generation),
			.o_system_fault_summary(o_system_fault_summary),
			.o_result_discard_summary_sticky(o_result_discard_summary_sticky),
			.o_measurement_result_discard_event(o_measurement_result_discard_event),
			.o_measurement_result_discard_reason(o_measurement_result_discard_reason),
			.o_measurement_result_discard_identity_valid(o_measurement_result_discard_identity_valid),
			.o_measurement_result_discard_sample_valid(o_measurement_result_discard_sample_valid),
			.o_measurement_result_discard_frame_id(o_measurement_result_discard_frame_id),
			.o_measurement_result_discard_sample_index(o_measurement_result_discard_sample_index),
			.o_measurement_result_discard_color_ir(o_measurement_result_discard_color_ir),
			.o_measurement_result_discard_frame_type(o_measurement_result_discard_frame_type),
			.o_measurement_result_discard_precision(o_measurement_result_discard_precision),
			.o_measurement_result_discard_run_generation(o_measurement_result_discard_run_generation),
			.o_detection_discard_event(o_detection_discard_event),
			.o_detection_discard_reason(o_detection_discard_reason),
			.o_detection_discard_identity_valid(o_detection_discard_identity_valid),
			.o_detection_discard_sample_valid(o_detection_discard_sample_valid),
			.o_detection_discard_frame_id(o_detection_discard_frame_id),
			.o_detection_discard_sample_index(o_detection_discard_sample_index),
			.o_detection_discard_color_ir(o_detection_discard_color_ir),
			.o_detection_discard_frame_type(o_detection_discard_frame_type),
			.o_detection_discard_precision(o_detection_discard_precision),
			.o_detection_discard_config_epoch(o_detection_discard_config_epoch),
			.o_detection_discard_coef_epoch(o_detection_discard_coef_epoch),
			.o_detection_discard_dc_recovery_epoch(o_detection_discard_dc_recovery_epoch),
			.o_detection_discard_amb_code_epoch(o_detection_discard_amb_code_epoch),
			.o_detection_discard_dc_code_epoch(o_detection_discard_dc_code_epoch),
			.o_detection_discard_run_generation(o_detection_discard_run_generation)
		);

	//---------------source时钟发生器---------------//
	initial begin
		i_source_clk = 1'b0;
		forever #5.5 i_source_clk = ~i_source_clk;
	end

	//---------------系统时钟发生器---------------//
	initial begin
		i_clk = 1'b0;
		forever #250 i_clk = ~i_clk;
	end

	//---------------JNT-01~09基线前缀内部要求的标准配置task名---------------//
	task task_build_normal_manual_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0; // run_profile=NORMAL_PPG
			i_source_config_snapshot[9] = 1'b0; // input_source=PHOTODIODE
			i_source_config_snapshot[11:10] = 2'b00; // idac_mode=MANUAL，JNT基线前缀自用
			i_source_config_snapshot[13:12] = 2'b10; // optical_mode=OPTICAL_IR
			i_source_config_snapshot[14] = 1'b0; // initial_precision=SAR9
			i_source_config_snapshot[15] = 1'b1; // amb_enable
			i_source_config_snapshot[16] = 1'b1; // dcs_enable
			i_source_config_snapshot[17] = 1'b1; // amb_polarity=1，above_high即increase
			i_source_config_snapshot[18] = 1'b0; // dcs_polarity=0，below_low即increase
			i_source_config_snapshot[19] = 1'b1; // stage1_calibration_valid
			i_source_config_snapshot[20] = 1'b1; // stage2_calibration_valid
			i_source_config_snapshot[21] = 1'b1; // dc9_recovery_valid
			i_source_config_snapshot[22] = 1'b1; // dc15_recovery_valid
			i_source_config_snapshot[39:32] = 8'd64; // amb_manual_code
			i_source_config_snapshot[47:40] = 8'd8; // amb_code_min
			i_source_config_snapshot[55:48] = 8'd240; // amb_code_max
			i_source_config_snapshot[63:56] = 8'd80; // dcs_r_manual_code
			i_source_config_snapshot[71:64] = 8'd12; // dcs_r_code_min
			i_source_config_snapshot[79:72] = 8'd230; // dcs_r_code_max
			i_source_config_snapshot[87:80] = 8'd96; // dcs_ir_manual_code
			i_source_config_snapshot[95:88] = 8'd16; // dcs_ir_code_min
			i_source_config_snapshot[103:96] = 8'd220; // dcs_ir_code_max
			// 同Group6/7/8已经确立的惯例：阈值窗口整体搬到make_fixed_raw合法值域
			// [8,503]内部（100,200），below_low(8)/above_high(503)/in_window(150)
			// 三种分类都是纯正数，不受钳位影响
			i_source_config_snapshot[115:104] = 12'sd100; // amb_threshold_low
			i_source_config_snapshot[127:116] = 12'sd200; // amb_threshold_high
			i_source_config_snapshot[139:128] = 12'sd100; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd200; // dcs_threshold_high
			i_source_config_snapshot[159:152] = 8'd8; // amb_confirm_count
			i_source_config_snapshot[167:160] = 8'd9; // dcs_confirm_count
			i_source_config_snapshot[193:168] = 26'sd65536; // stage1_weight_q16_0，Group11已验证target_code恒等式的幂次权重
			i_source_config_snapshot[219:194] = 26'sd131072; // stage1_weight_q16_1
			i_source_config_snapshot[245:220] = 26'sd262144; // stage1_weight_q16_2
			i_source_config_snapshot[271:246] = 26'sd524288; // stage1_weight_q16_3
			i_source_config_snapshot[297:272] = 26'sd524288; // stage1_weight_q16_4
			i_source_config_snapshot[323:298] = 26'sd1048576; // stage1_weight_q16_5
			i_source_config_snapshot[349:324] = 26'sd2097152; // stage1_weight_q16_6
			i_source_config_snapshot[375:350] = 26'sd4194304; // stage1_weight_q16_7
			i_source_config_snapshot[401:376] = 26'sd8388608; // stage1_weight_q16_8
			i_source_config_snapshot[427:402] = 26'sd16777216; // stage1_weight_q16_9
			i_source_config_snapshot[459:428] = -32'sd262144; // stage1_offset_q16
			i_source_config_snapshot[479:460] = 20'sd54143; // stage2_gain_q16
			i_source_config_snapshot[511:480] = -32'sd37; // stage2_offset_q16
			i_source_config_snapshot[543:512] = 32'sd65536; // dc9_recovery_gain_q16
			i_source_config_snapshot[575:544] = 32'sd32768; // dc15_recovery_gain_q16
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames，本组自己的场景task会覆盖成0
			i_source_config_snapshot[1009] = 1'b1; // peak_valley_config_valid
		end
	endtask

	task task_build_normal_manual_dual_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，真双光
		end
	endtask

	//---------------阶段A/B专用：SEARCH_TRACK+双光+真实生成器阈值，周期重检间隔归零---------------//
	// dcs_threshold_high放宽到400，覆盖生成器真实幅度范围，同Group7/8的
	// task_build_search_track_generator_config；amb_recheck_interval_frames
	// 显式设成0——本组核心场景开关，ppg_amb_recheck_scheduler.v的
	// flag_period_enabled无条件要求这个字段非零，等于0时整条重检链路
	// 结构性地永远不会激活
	task task_build_no_recheck_generator_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH
			i_source_config_snapshot[151:140] = 12'sd400; // dcs_threshold_high，放宽覆盖生成器真实幅度范围
			i_source_config_snapshot[591:576] = 16'd0; // amb_recheck_interval_frames=0，本组核心场景开关
		end
	endtask

	//---------------source事件任务---------------//
	task task_pulse_source_update;
		begin
			@(negedge i_source_clk);
			i_source_config_update_event = 1'b1;
			@(posedge i_source_clk);
			#1 i_source_config_update_event = 1'b0;
		end
	endtask

	//---------------START/STOP事件任务---------------//
	task task_pulse_start;
		begin
			@(negedge i_clk);
			i_start_event = 1'b1;
			@(posedge i_clk);
			#1 i_start_event = 1'b0;
		end
	endtask

	task task_pulse_stop;
		begin
			@(negedge i_clk);
			i_stop_event = 1'b1;
			@(posedge i_clk);
			#1 i_stop_event = 1'b0;
		end
	endtask

	//---------------配置结果等待任务---------------//
	task task_wait_config_result;
		integer cnt_wait;
		begin
			cnt_wait = 0;
			while((o_commit_ack_event == 1'b0) && (o_error_event == 1'b0) && (cnt_wait < 64)) begin
				@(posedge i_clk);
				#1;
				cnt_wait = cnt_wait + 1;
			end
			if((o_commit_ack_event == 1'b0) && (o_error_event == 1'b0)) begin
				$display("FAIL NRE config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------排空回CONFIG任务---------------//
	task task_stop_and_drain;
		integer cnt_stop_wait;
		integer cnt_drain_wait;
		reg local_release;
		reg [9:0] flush_raw;
		integer cnt_post_stop_flush;
		begin
			task_pulse_stop;
			cnt_stop_wait = 0;
			while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
				@(posedge i_clk);
				#1;
				cnt_stop_wait = cnt_stop_wait + 1;
			end
			// 同Group7/8已验证过的STOP后冲刷手法：STOP接受时若恰好有owner在途，
			// 调度器只把它标成B_INFLIGHT_DISCARD受控丢弃，B_INFLIGHT本身要等一次
			// 真实完成才清零
			cnt_post_stop_flush = 0;
			while(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] &&
				(cnt_post_stop_flush < 10) && !flag_global_timeout) begin
				wait_q3_release(local_release);
				if(local_release) begin
					make_fixed_raw(150, flush_raw);
					drive_real_adc_done(1'b0, flush_raw, flush_raw);
				end
				cnt_post_stop_flush = cnt_post_stop_flush + 1;
			end
			cnt_drain_wait = 0;
			while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
				@(posedge i_clk);
				#1;
				cnt_drain_wait = cnt_drain_wait + 1;
			end
			if(o_lifecycle_state != ST_CONFIG) begin
				$display("FAIL NRE drain to CONFIG timeout stop_ack_seen=%b cnt_stop_wait=%0d",
					o_stop_ack_event, cnt_stop_wait);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------真实ADC完成响应任务---------------//
	task drive_real_adc_done;
		input precision_mode;
		input [9:0] stage1_raw;
		input [9:0] stage2_raw;
		begin
			@(negedge i_clk);
			#2 i_adc_physical_idle = 1'b0;
			#2 i_dout_stage1_low = stage1_raw;
			#1 i_dout_stage2_low = stage2_raw;
			#1 i_clk_stage1_dout_low_async = 1'b1;
			#1 i_clk_stage2_dout_low_async = precision_mode;
			repeat(5) @(negedge i_clk);
			#2 i_clk_stage1_dout_low_async = 1'b0;
			#1 i_clk_stage2_dout_low_async = 1'b0;
			#1 i_adc_physical_idle = 1'b1;
		end
	endtask

	//---------------Q3窗口等待任务---------------//
	task wait_q3_release;
		output o_real_release;
		integer cnt_wd;
		begin
			cnt_wd = 0;
			while((o_clk_q3_low !== 1'b1) && (cnt_wd < 5600)) begin
				@(negedge i_clk);
				cnt_wd = cnt_wd + 1;
			end
			if(o_clk_q3_low !== 1'b1) begin
				o_real_release = 1'b0;
			end else begin
				o_real_release = 1'b1;
				while((o_clk_q3_low === 1'b1) && (cnt_wd < 6600)) begin
					@(negedge i_clk);
					cnt_wd = cnt_wd + 1;
				end
				if(cnt_wd >= 6600) begin
					$display("FAIL NRE Q3 wait timeout");
					cnt_error = cnt_error + 1;
				end
			end
		end
	endtask

	//---------------vdred编码RAW构造任务---------------//
	task make_fixed_raw;
		input integer target_code;
		output [9:0] raw_code;
		integer bounded_code;
		integer encoded_code;
		begin
			bounded_code = target_code;
			if(bounded_code < 8) bounded_code = 8;
			else if(bounded_code > 503) bounded_code = 503;
			encoded_code = bounded_code - 4;
			raw_code = ((encoded_code >> 3) << 4) | 10'b0000001000 | (encoded_code & 7);
		end
	endtask

	`include "tb_ppg_jnt_baseline_prefix.vh"
	`include "tb_ppg_real_raw_generator.vh"

	//---------------真实owner身份快照进程---------------//
	// commit那一拍锁存身份，真实DONE到达时才使用，同Group7/8已验证手法。放在
	// 任何引用它的task之前声明——xvlog/xelab对同一模块内标识符要求先声明后
	// 使用，Group8已经真实踩过这个坑
	reg reg_owner_snapshot_is_calibration;
	reg reg_owner_snapshot_color_ir;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_owner_snapshot_frame_id;
	reg reg_owner_snapshot_precision;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			reg_owner_snapshot_is_calibration <= (ppg_control_top_Inst.sched_adc_owner_frame_type_o != 2'b10); // FRAME_TYPE_NORMAL=2'b10，其余编码均为校准类
			reg_owner_snapshot_color_ir <= ppg_control_top_Inst.sched_adc_owner_color_ir_o;
			reg_owner_snapshot_frame_id <= ppg_control_top_Inst.sched_adc_owner_frame_id_o;
			reg_owner_snapshot_precision <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
		end
	end

	//---------------真实候选驱动任务：AMB极性，above即increase---------------//
	task task_drive_amb_toward_target;
		input integer current_code;
		input integer target_code;
		reg [9:0] raw_code;
		integer drive_value;
		begin
			if(current_code < target_code) drive_value = 503; // 强制above_high，AMB极性下触发increase
			else if(current_code > target_code) drive_value = 8; // 强制below_low，触发decrease
			else drive_value = 150; // 强制in_window，[100,200]内
			make_fixed_raw(drive_value, raw_code);
			drive_real_adc_done(1'b0, raw_code, raw_code);
		end
	endtask

	//---------------真实候选驱动任务：DCS极性下below即increase，与AMB相反---------------//
	task task_drive_dcs_toward_target;
		input integer current_code;
		input integer target_code;
		reg [9:0] raw_code;
		integer drive_value;
		begin
			if(current_code < target_code) drive_value = 8; // 强制below_low，DCS极性下触发increase
			else if(current_code > target_code) drive_value = 503; // 强制above_high，触发decrease
			else drive_value = 150; // 强制in_window，[100,200]内
			make_fixed_raw(drive_value, raw_code);
			drive_real_adc_done(1'b0, raw_code, raw_code);
		end
	endtask

	//---------------真实启动搜索收敛任务---------------//
	// 提取自Group6/8已验证过的AMB/DC_R/DC_IR三阶段二分搜索收敛循环
	task task_run_startup_search;
		reg real_release;
		reg [7:0] reg_current_amb_code, reg_current_dcs_r_code, reg_current_dcs_ir_code;
		integer cnt_wait_request;
		begin
			begin : nre_startup_amb_stage
				integer cnt_candidate;
				reg flag_amb_converged;
				flag_amb_converged = 1'b0;
				for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_amb_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
					cnt_wait_request = 0;
					while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request &&
						(cnt_wait_request < 5000) && !flag_global_timeout) begin
						@(posedge i_clk);
						cnt_wait_request = cnt_wait_request + 1;
					end
					reg_current_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
					wait_q3_release(real_release);
					if(real_release) task_drive_amb_toward_target(reg_current_amb_code, 64);
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_APPLY ||
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_WAIT) begin
						flag_amb_converged = 1'b1;
					end
				end
				if(!flag_amb_converged) begin
					$display("FAIL NRE startup AMB stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : nre_startup_dcs_r_stage
				integer cnt_candidate;
				reg flag_r_converged;
				flag_r_converged = 1'b0;
				for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_r_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
					cnt_wait_request = 0;
					while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request &&
						(cnt_wait_request < 5000) && !flag_global_timeout) begin
						@(posedge i_clk);
						cnt_wait_request = cnt_wait_request + 1;
					end
					reg_current_dcs_r_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
					wait_q3_release(real_release);
					if(real_release) task_drive_dcs_toward_target(reg_current_dcs_r_code, 80);
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_APPLY ||
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_WAIT) begin
						flag_r_converged = 1'b1;
					end
				end
				if(!flag_r_converged) begin
					$display("FAIL NRE startup DC_R stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : nre_startup_dcs_ir_stage
				integer cnt_candidate;
				reg flag_ir_converged;
				flag_ir_converged = 1'b0;
				for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_ir_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
					cnt_wait_request = 0;
					while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request &&
						(cnt_wait_request < 5000) && !flag_global_timeout) begin
						@(posedge i_clk);
						cnt_wait_request = cnt_wait_request + 1;
					end
					reg_current_dcs_ir_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code;
					wait_q3_release(real_release);
					if(real_release) task_drive_dcs_toward_target(reg_current_dcs_ir_code, 96);
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_NORMAL) begin
						flag_ir_converged = 1'b1;
					end
				end
				if(!flag_ir_converged) begin
					$display("FAIL NRE startup DC_IR stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			cnt_wait_request = 0;
			while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete &&
				(cnt_wait_request < 2000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_request = cnt_wait_request + 1;
			end
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete) begin
				$display("FAIL NRE startup_search_complete never asserted after convergence");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end
	endtask

	//---------------正式结果与owner提交边沿捕获进程---------------//
	integer cnt_result_capture;
	integer cnt_owner_commit_total_nre;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			cnt_owner_commit_total_nre <= cnt_owner_commit_total_nre + 1;
		end
	end

	//---------------NRE-01/02专用：周期重检全局零活动连续监视进程---------------//
	// 直接盯调度器自己的pending/accept/busy/done/failed，以及FIR和穿越检测器
	// 自己真正消费的i_recheck_accept_event/i_recheck_busy输入——不是从别处
	// 间接推断，是在每一个真正被使用的点上直接检查。amb_recheck_interval_
	// frames=0时flag_period_enabled结构性恒为0，这组信号理论上应该从复位
	// 到仿真结束全程保持0，一旦观察到任何一次真实置1立即锁存违规
	reg flag_nre_violation_pending;
	reg flag_nre_violation_accept;
	reg flag_nre_violation_busy;
	reg flag_nre_violation_done;
	reg flag_nre_violation_failed;
	reg flag_nre_violation_fir_recheck_accept;
	reg flag_nre_violation_fir_recheck_busy;
	reg flag_nre_violation_cross_recheck_accept;
	reg flag_nre_violation_cross_recheck_busy;
	reg flag_nre_violation_idac_recheck_state;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending) flag_nre_violation_pending <= 1'b1;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_accept) flag_nre_violation_accept <= 1'b1;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_busy) flag_nre_violation_busy <= 1'b1;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_sequence_done) flag_nre_violation_done <= 1'b1;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_sequence_failed) flag_nre_violation_failed <= 1'b1;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.i_recheck_accept_event) flag_nre_violation_fir_recheck_accept <= 1'b1;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.i_recheck_busy) flag_nre_violation_fir_recheck_busy <= 1'b1;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_recheck_accept_event) flag_nre_violation_cross_recheck_accept <= 1'b1;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_recheck_busy) flag_nre_violation_cross_recheck_busy <= 1'b1;
		if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_RECHECK) ||
			(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_WAIT) ||
			(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_R) ||
			(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_IR)) begin
			flag_nre_violation_idac_recheck_state <= 1'b1;
		end
	end

	//---------------NRE-03专用：FIR RED/IR预热历史高水位监视进程---------------//
	// 一旦满窗（cnt_*_sample==21）之前观察到任何一次真实下降立即锁存违规——
	// 证明预热历史在中途从未被作废/清零。cnt_red_sample/cnt_ir_sample是
	// ppg_coarse_detection_fir.v的内部reg，直接层次引用观测
	reg [4:0] reg_prev_cnt_red_sample, reg_prev_cnt_ir_sample;
	reg flag_nre_fir_red_ever_latched_full;
	reg flag_nre_fir_ir_ever_latched_full;
	reg flag_nre_violation_fir_red_dropped;
	reg flag_nre_violation_fir_ir_dropped;
	always @(posedge i_clk) begin
		if(!i_rstn) begin
			reg_prev_cnt_red_sample <= 5'd0;
			reg_prev_cnt_ir_sample <= 5'd0;
		end else begin
			if(!flag_nre_fir_red_ever_latched_full &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.cnt_red_sample < reg_prev_cnt_red_sample)) begin
				flag_nre_violation_fir_red_dropped <= 1'b1;
			end
			if(!flag_nre_fir_ir_ever_latched_full &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.cnt_ir_sample < reg_prev_cnt_ir_sample)) begin
				flag_nre_violation_fir_ir_dropped <= 1'b1;
			end
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.o_history_full_r) flag_nre_fir_red_ever_latched_full <= 1'b1;
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.o_history_full_ir) flag_nre_fir_ir_ever_latched_full <= 1'b1;
			reg_prev_cnt_red_sample <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.cnt_red_sample;
			reg_prev_cnt_ir_sample <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.cnt_ir_sample;
		end
	end

	//---------------NRE-04/05专用：真实精度切换/回落事件连续后台捕获进程---------------//
	// 同Group7/8已验证过的连续always块+sticky捕获模式
	reg flag_fine_window_seen;
	reg flag_return_9bit_seen;
	reg flag_nre05_fir_full_before_cross; // NRE-05：穿越形成时两色FIR历史是否都已经真实锁满
	always @(posedge i_clk) begin
		if(!flag_fine_window_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_fine_window_start_event) begin
			flag_fine_window_seen <= 1'b1;
			flag_nre05_fir_full_before_cross <= flag_nre_fir_red_ever_latched_full && flag_nre_fir_ir_ever_latched_full;
		end
		if(flag_fine_window_seen && !flag_return_9bit_seen &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_9bit_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_return_9bit_ready) begin
			flag_return_9bit_seen <= 1'b1;
		end
	end

	//---------------NRE-06专用：正式结果frame_id非递减连续监视进程---------------//
	reg flag_nre06_result_seen_once;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_nre06_prev_frame_id;
	reg flag_nre_violation_frame_id_decreased;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			if(flag_nre06_result_seen_once && (o_result_frame_id < reg_nre06_prev_frame_id)) begin
				flag_nre_violation_frame_id_decreased <= 1'b1;
			end
			reg_nre06_prev_frame_id <= o_result_frame_id;
			flag_nre06_result_seen_once <= 1'b1;
		end
	end

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL NO_RECHECK_CONTROL global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	initial begin : main_sequence
		reg real_release;
		reg [9:0] raw_target_code;
		reg [7:0] reg_snap_amb_code;
		reg [C_CODE_EPOCH_WIDTH - 1:0] reg_snap_amb_epoch;
		integer cnt_frame_drive;
		reg [9:0] target_code_gen;
		integer raw_unclamped_dummy;
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		cnt_owner_commit_total_nre = 0;
		flag_nre_violation_pending = 1'b0;
		flag_nre_violation_accept = 1'b0;
		flag_nre_violation_busy = 1'b0;
		flag_nre_violation_done = 1'b0;
		flag_nre_violation_failed = 1'b0;
		flag_nre_violation_fir_recheck_accept = 1'b0;
		flag_nre_violation_fir_recheck_busy = 1'b0;
		flag_nre_violation_cross_recheck_accept = 1'b0;
		flag_nre_violation_cross_recheck_busy = 1'b0;
		flag_nre_violation_idac_recheck_state = 1'b0;
		flag_nre_fir_red_ever_latched_full = 1'b0;
		flag_nre_fir_ir_ever_latched_full = 1'b0;
		flag_nre_violation_fir_red_dropped = 1'b0;
		flag_nre_violation_fir_ir_dropped = 1'b0;
		flag_fine_window_seen = 1'b0;
		flag_return_9bit_seen = 1'b0;
		flag_nre05_fir_full_before_cross = 1'b0;
		flag_nre06_result_seen_once = 1'b0;
		flag_nre_violation_frame_id_decreased = 1'b0;
		i_rstn = 1'b0;
		i_source_rstn = 1'b0;
		i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
		i_source_config_update_event = 1'b0;
		i_source_characterization_update_valid = 1'b0;
		i_source_static_characterization_enable = 1'b0;
		i_source_test_mux_ctrl = 5'b00000;
		i_start_event = 1'b0;
		i_stop_event = 1'b0;
		i_diag_clear_event = 1'b0;
		i_control_abort_event = 1'b0;
		i_dout_stage1_low = 10'd0;
		i_clk_stage1_dout_low_async = 1'b0;
		i_dout_stage2_low = 10'd0;
		i_clk_stage2_dout_low_async = 1'b0;
		i_adc_physical_idle = 1'b1;
		i_analog_ready = 1'b1;
		i_measurement_result_ready = 1'b1;
		i_test_inject_enable = 1'b0;
		i_test_identity_inject_valid = 1'b0;
		i_test_identity_inject_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
		i_test_invalid_sample_valid = 1'b0;

		repeat(3) @(posedge i_clk);
		#1;
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;

		run_jnt_baseline_01_09;

		//=========== 唯一一个RUN：SEARCH_TRACK+双光真实生成器，amb_recheck_interval_frames=0 ===========//
		task_build_no_recheck_generator_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL NRE RUN commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;

		reg_snap_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
		reg_snap_amb_epoch = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current;

		//------- 真实生成器驱动：先跑到FIR两色都真实锁满+一次真实穿越->SAR15->回落9-bit -------//
		begin : nre_main_drive
			for(cnt_frame_drive = 0; (cnt_frame_drive < C_GENERATOR_FRAME_GUARD) && !flag_return_9bit_seen && !flag_global_timeout; cnt_frame_drive = cnt_frame_drive + 1) begin
				wait_q3_release(real_release);
				if(real_release) begin
					if(reg_owner_snapshot_is_calibration) begin
						make_fixed_raw(150, raw_target_code); // 窗口内中性值，本组从不主动构造校准帧，正常也不应该出现
						drive_real_adc_done(1'b0, raw_target_code, raw_target_code);
					end else begin
						task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_owner_snapshot_color_ir,
							{16'd0, reg_owner_snapshot_frame_id}, target_code_gen, raw_unclamped_dummy);
						make_fixed_raw(target_code_gen, raw_target_code);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_target_code, raw_target_code);
					end
				end
			end
			if(!flag_fine_window_seen) begin
				$display("FAIL NRE-04 no real SAR9->SAR15 transition observed within %0d driven frames -- NRE-04/05 are vacuous", cnt_frame_drive);
				cnt_error = cnt_error + 1;
			end else if(!flag_return_9bit_seen) begin
				$display("FAIL NRE-04 real SAR15->SAR9 return never observed after entry");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS NRE-04 a real baseline crossing entered SAR15 and a qualified peak/valley sequence returned to SAR9 through the normal path, with zero recheck event observed anywhere in between");
			end
			if(!flag_fine_window_seen) begin
				$display("FAIL NRE-05 check is vacuous: no real cross was ever formed");
				cnt_error = cnt_error + 1;
			end else if(!flag_nre05_fir_full_before_cross) begin
				$display("FAIL NRE-05 the real cross formed before both RED and IR FIR history had genuinely latched full -- cross identity cannot be attributed to real accumulated evidence");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS NRE-05 the real cross was formed only after both RED and IR FIR history had already latched full, bound to genuine accumulated NORMAL evidence, not to START/reset/a hidden recheck clear");
			end

			//------- NRE-06：继续同一次驱动跑更久，核对长跑期间owner/结果/epoch的连续性 -------//
			for(cnt_frame_drive = 0; (cnt_frame_drive < C_LONG_RUN_EXTRA_FRAMES) && !flag_global_timeout; cnt_frame_drive = cnt_frame_drive + 1) begin
				wait_q3_release(real_release);
				if(real_release) begin
					if(reg_owner_snapshot_is_calibration) begin
						make_fixed_raw(150, raw_target_code);
						drive_real_adc_done(1'b0, raw_target_code, raw_target_code);
					end else begin
						task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_owner_snapshot_color_ir,
							{16'd0, reg_owner_snapshot_frame_id}, target_code_gen, raw_unclamped_dummy);
						make_fixed_raw(target_code_gen, raw_target_code);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_target_code, raw_target_code);
					end
				end
			end
		end

		//------- NRE-01/02：整个RUN期间周期重检的全部信号必须原地保持0 -------//
		if(flag_nre_violation_pending || flag_nre_violation_accept || flag_nre_violation_busy ||
			flag_nre_violation_done || flag_nre_violation_failed) begin
			$display("FAIL NRE-01 recheck pending/accept/busy/done/failed observed active at some point during the RUN despite amb_recheck_interval_frames=0: pending=%b accept=%b busy=%b done=%b failed=%b",
				flag_nre_violation_pending, flag_nre_violation_accept, flag_nre_violation_busy, flag_nre_violation_done, flag_nre_violation_failed);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS NRE-01 recheck pending/accept/busy/done/failed stayed inactive for the entire RUN with amb_recheck_interval_frames=0");
		end
		if(flag_nre_violation_fir_recheck_accept || flag_nre_violation_fir_recheck_busy ||
			flag_nre_violation_cross_recheck_accept || flag_nre_violation_cross_recheck_busy ||
			flag_nre_violation_idac_recheck_state) begin
			$display("FAIL NRE-02 a recheck-driven FIR-history-clear/detector-clear/calibration-request signal was observed active: fir_accept=%b fir_busy=%b cross_accept=%b cross_busy=%b idac_recheck_state=%b",
				flag_nre_violation_fir_recheck_accept, flag_nre_violation_fir_recheck_busy,
				flag_nre_violation_cross_recheck_accept, flag_nre_violation_cross_recheck_busy,
				flag_nre_violation_idac_recheck_state);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS NRE-02 no recheck-driven FIR-history clear, detector clear, or calibration request occurred at any point (checked directly at the FIR/cross-detector i_recheck_accept_event/i_recheck_busy inputs and at the idac controller's own recheck-family states)");
		end

		//------- NRE-03：FIR预热历史高水位从未在满窗之前真实下降，且两色最终都真实锁满 -------//
		if(flag_nre_violation_fir_red_dropped || flag_nre_violation_fir_ir_dropped) begin
			$display("FAIL NRE-03 FIR RED/IR history depth was observed decreasing before latching full: red_dropped=%b ir_dropped=%b",
				flag_nre_violation_fir_red_dropped, flag_nre_violation_fir_ir_dropped);
			cnt_error = cnt_error + 1;
		end else if(!flag_nre_fir_red_ever_latched_full || !flag_nre_fir_ir_ever_latched_full) begin
			$display("FAIL NRE-03 RED/IR FIR history never reached the full warmup within the driven run: red_full=%b ir_full=%b",
				flag_nre_fir_red_ever_latched_full, flag_nre_fir_ir_ever_latched_full);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS NRE-03 both RED and IR completed normal FIR warmup and retained uninterrupted qualified history (depth never decreased before latching full)");
		end

		//------- NRE-06：正式结果frame_id全程非递减，AMB epoch从启动搜索完成后到跑完全程逐字节不变 -------//
		if(flag_nre_violation_frame_id_decreased) begin
			$display("FAIL NRE-06 a formal result was observed with a decreasing o_result_frame_id during the long run");
			cnt_error = cnt_error + 1;
		end else if(cnt_result_capture == 0) begin
			$display("FAIL NRE-06 no formal result was ever captured during the long run -- result-continuity check is vacuous");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS NRE-06 formal result order stayed continuous (o_result_frame_id never decreased) across %0d captured results and %0d owner commits over the long run", cnt_result_capture, cnt_owner_commit_total_nre);
		end
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current != reg_snap_amb_epoch) begin
			$display("FAIL NRE-06 AMB code epoch changed during the long no-recheck run, expected=%0d observed=%0d",
				reg_snap_amb_epoch, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current);
			cnt_error = cnt_error + 1;
		end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code != reg_snap_amb_code) begin
			$display("FAIL NRE-06 AMB code changed during the long no-recheck run despite epoch staying the same, expected=%0d observed=%0d",
				reg_snap_amb_code, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS NRE-06 AMB code and epoch remained bit-identical from post-startup-search through the entire long no-recheck run");
		end

		task_stop_and_drain;

		if(cnt_error == 0) begin
			$display("NO_RECHECK_CONTROL_TB_PASS result_captures=%0d owner_commit_total=%0d", cnt_result_capture, cnt_owner_commit_total_nre);
		end else begin
			$display("NO_RECHECK_CONTROL_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
