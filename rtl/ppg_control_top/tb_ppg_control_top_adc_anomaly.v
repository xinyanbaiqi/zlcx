`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/10/08
// Design Name:        PPG Control Top ADC Anomaly Owner-Lifecycle Testbench
// Module Name:        tb_ppg_control_top_adc_anomaly
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        Vivado xsim 2022.2
//
// Referrences:        verification_reports/OWNER_LIFECYCLE_DESIGN_20261007.md,
//                     verification_reports/LOST_COMPLETION_NORMAL_AND_LATENESS_20261006.md,
//                     verification_reports/SSW18_TICK385_INVESTIGATION_20261006.md
//
// Dependencies:       ppg_control_top.v and its full hierarchy, tb_ppg_jnt_baseline_prefix.vh,
//                     tb_ppg_real_raw_generator.vh
//
// Version:            V1.0
// Revision Date:      2026/10/08
// History:
//    Time               Version       Revised by            Contents
// 2026/10/08            V1.0          Erie                  Create file. Owner-lifecycle round (F-020, S1, L-1..L-5, scheme A) permanent system regression at control_top level including the supervisor. The DUT instantiation, lifecycle/config tasks, physiological RAW generator, startup-search task, owner snapshot and recheck monitors are reused verbatim from tb_ppg_control_top_periodic_recheck_recovery.v; the main sequence is new and turns the temporary TBs of LOST_COMPLETION_NORMAL_AND_LATENESS_20261006 / SSW18_TICK385_INVESTIGATION_20261006 into checks with TB-local names (SYS-*). A policy-driven background ADC responder answers every real Q3 release (drop / delay / dead per slot). Passive monitors: Q3-to-owner binding (every Q3 must belong to an owner committed in the same frame, and for calibration the same subframe), void/completion exclusivity, and a generic liveness monitor (RUN or STOPPING for 3 macro frames with no completion, void, result, IDAC commit, lifecycle change or fault record while no system fault is reported -> FAIL).
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年10月08日
// 设计名称:           PPG控制顶层ADC异常owner生命周期测试平台
// 模块名称:           tb_ppg_control_top_adc_anomaly
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           Vivado xsim 2022.2
//
// 参考资料:           OWNER_LIFECYCLE_DESIGN_20261007.md、LOST_COMPLETION_NORMAL_AND_LATENESS_20261006.md、
//                     SSW18_TICK385_INVESTIGATION_20261006.md
//
// 依赖文件:           ppg_control_top.v及其完整层次、tb_ppg_jnt_baseline_prefix.vh、tb_ppg_real_raw_generator.vh
//
// 当前版本:           V1.0
// 修订日期:           2026年10月08日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年10月08日        V1.0          Erie                  创建文件。owner生命周期轮（F-020、S1、L-1~L-5，方案甲）的永久系统级回归，control_top层含supervisor。DUT例化、生命周期/配置任务、真实生理RAW生成器、启动搜索任务、owner快照与重检监视原样复用tb_ppg_control_top_periodic_recheck_recovery.v；主序列为新写，把两份临时TB（LOST_COMPLETION/SSW18报告）的场景改成TB本地名检查（SYS-*）。后台ADC响应进程按策略应答每次真实Q3释放（按槽位丢一次/推迟/持续失联）。被动监视：Q3与owner绑定（每次Q3必须属于同帧提交的owner，校准还须同子帧）、作废与完成互斥、通用活性监视（RUN或STOPPING中连续3个宏帧既无完成、作废、结果、IDAC提交、生命周期变化也无故障记录、且未报系统故障即FAIL）。

// owner生命周期轮ADC异常系统级回归：丢失作废与恢复、合法迟到、按槽位升级、排空中丢失、迟到旧DONE、竞争窗口、
// L-1/L-3/L-4/L-5原场景、ADC长期忙与看门狗、校准丢失后NORMAL帧不错绑
module tb_ppg_control_top_adc_anomaly();

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
	localparam [4:0] ST_IDAC_AMB_RECHECK = 5'd9; // idac控制器周期检查当前AMB码
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_WAIT = 5'd10; // idac控制器保持DCS重验证请求
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_R = 5'd11; // idac控制器检查当前红光DC码
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_IR = 5'd12; // idac控制器检查当前红外DC码

	localparam integer C_CANDIDATE_GUARD_MAX = 12; // 单阶段候选步数安全上限，8位码空间理论最多8步
	localparam integer C_GENERATOR_FRAME_GUARD = 2000; // 单轮真实穿越/回落搜寻的驱动帧数上限
	localparam time C_SIM_TIMEOUT_NS = 64'd7000000000; // 7秒安全看门狗上限，R阶段真实生成器需跑过第2个脉搏周期才出现首次精细窗口

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
			// 同Group6/7已经确立的惯例：阈值窗口整体搬到make_fixed_raw合法值域[8,503]
			// 内部（100,200），below_low(8)/above_high(503)/in_window(150)三种分类
			// 都是纯正数，不受钳位影响
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
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames，本组自己的场景task会覆盖
			i_source_config_snapshot[1009] = 1'b1; // peak_valley_config_valid
		end
	endtask

	task task_build_normal_manual_dual_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，真双光
		end
	endtask

	//---------------阶段A/B专用：SEARCH_TRACK+双光+真实生成器阈值，覆盖短周期重检间隔---------------//
	// dcs_threshold_high放宽到400，覆盖生成器真实幅度范围，同Group7的
	// task_build_search_track_generator_config；amb_recheck_interval_frames
	// 覆盖到一个仿真内可行的小值，让第一个间隔在生成器真实第一次穿越前后到期
	task task_build_recheck_generator_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH
			i_source_config_snapshot[151:140] = 12'sd400; // dcs_threshold_high，放宽覆盖生成器真实幅度范围
			i_source_config_snapshot[591:576] = 16'd30; // amb_recheck_interval_frames，缩短到30帧
		end
	endtask

	//---------------阶段C专用：SEARCH_TRACK+双光+固定RAW驱动，专供RRC-12---------------//
	// 极短间隔配合固定不变驱动值：固定驱动永远不产生真实基线漂移，系统永远不会
	// 离开SAR9，i_precision_15_to_9_event永远不会真实触发，pending只能悬挂
	task task_build_recheck_fixed_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH
			i_source_config_snapshot[591:576] = 16'd2; // amb_recheck_interval_frames，极短间隔
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
				$display("FAIL RRC config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------排空回CONFIG任务---------------//
	// 同Group7已验证过的STOP后冲刷手法：STOP接受时若恰好有owner在途，调度器只
	// 把它标成B_INFLIGHT_DISCARD受控丢弃，B_INFLIGHT本身要等一次真实完成才清零
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
				$display("FAIL RRC drain to CONFIG timeout stop_ack_seen=%b cnt_stop_wait=%0d idac_state=%0d sched_inflight=%b",
					o_stop_ack_event, cnt_stop_wait,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]);
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
					$display("FAIL RRC Q3 wait timeout");
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
	// commit那一拍锁存身份，真实DONE到达时才使用，同Group7已验证手法。放在
	// task_drive_color_value之前声明——xvlog/xelab对同一模块内标识符要求先声明
	// 后使用，比iverilog的两遍解析更严格，第一版声明顺序放在后面导致真实
	// xvlog编译报"used before its declaration"，iverilog没有报出这个问题
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
	// 提取自Group6已验证过的AMB/DC_R/DC_IR三阶段二分搜索收敛循环，供本文件的
	// 每一个独立RUN在进入NORMAL/周期重检场景前共用
	task task_run_startup_search;
		reg real_release;
		reg [7:0] reg_current_amb_code, reg_current_dcs_r_code, reg_current_dcs_ir_code;
		integer cnt_wait_request;
		begin
			begin : rrc_startup_amb_stage
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
					$display("FAIL RRC startup AMB stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : rrc_startup_dcs_r_stage
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
					$display("FAIL RRC startup DC_R stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : rrc_startup_dcs_ir_stage
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
					$display("FAIL RRC startup DC_IR stage did not converge");
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
				$display("FAIL RRC startup_search_complete never asserted after convergence");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end
	endtask

	//---------------真实驱动一笔明确颜色、明确目标校准值的NORMAL跟踪事务---------------//
	// 同Group7已验证手法：双光NORMAL调度不保证严格RED/IR交替，用真实owner身份
	// 快照逐笔核对颜色，非目标颜色的真实事务驱动中性in-window值放行
	task task_drive_color_value;
		input target_color;
		input integer target_code;
		reg [9:0] raw_code;
		reg local_release;
		integer cnt_guard;
		reg flag_matched;
		begin
			flag_matched = 1'b0;
			cnt_guard = 0;
			while(!flag_matched && (cnt_guard < 30) && !flag_global_timeout) begin
				wait_q3_release(local_release);
				if(!local_release) begin
					cnt_guard = 30;
				end else begin
					if(reg_owner_snapshot_color_ir == target_color) begin
						flag_matched = 1'b1;
						make_fixed_raw(target_code, raw_code);
					end else begin
						make_fixed_raw(150, raw_code); // 中性in_window值，不干扰非目标颜色自身证据
					end
					drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
					cnt_guard = cnt_guard + 1;
				end
			end
			if(!flag_matched) begin
				$display("FAIL task_drive_color_value could not find a real transaction matching target_color=%b within guard window", target_color);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------正式结果与owner提交边沿捕获进程---------------//
	integer cnt_result_capture;
	integer cnt_owner_commit_total_rrc;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			cnt_owner_commit_total_rrc <= cnt_owner_commit_total_rrc + 1;
		end
	end

	//---------------RRC-01专用：完整NORMAL宏帧完成与周期计数器同步捕获进程---------------//
	// 直接对照调度器自己的cnt_normal_frame_o和真实宏帧完成脉冲，同一个always块
	// 里同时统计owner提交次数（每帧双色两笔），确认间隔计数器只按宏帧递增，不
	// 按ADC结果/owner提交递增
	integer cnt_real_macro_frame_complete;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_normal_frame_complete_event_o) begin
			cnt_real_macro_frame_complete <= cnt_real_macro_frame_complete + 1;
		end
	end

	//---------------RRC-02/09专用：真实精度切换/回落事件连续后台捕获进程---------------//
	// 同Group7已验证过的连续always块+sticky捕获模式，绝不在多拍阻塞调用之后
	// 做单点内联轮询
	reg flag_fine_window_seen;
	reg flag_return_9bit_seen;
	always @(posedge i_clk) begin
		if(!flag_fine_window_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_fine_window_start_event) begin
			flag_fine_window_seen <= 1'b1;
		end
		if(flag_fine_window_seen && !flag_return_9bit_seen &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_9bit_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_return_9bit_ready) begin
			flag_return_9bit_seen <= 1'b1;
		end
	end

	//---------------RRC-03/04/05/06/07/08/09/11专用：周期重检episode连续后台捕获进程---------------//
	// accept/done/failed都是单拍脉冲，绝不能在多拍阻塞调用之后单点轮询——用sticky
	// 寄存器持续捕获，主序列消费后自己复位供下一轮episode重新武装
	reg flag_recheck_accept_seen;
	reg flag_recheck_accept_takeover_safe_ok;
	reg flag_recheck_done_seen;
	reg flag_recheck_failed_seen;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_recheck_accept_time_dummy;
	reg [63:0] t_enter_amb_family, t_enter_dcsr_family, t_enter_dcsir_family;
	reg flag_recheck_busy_prev;
	always @(posedge i_clk) begin
		if(!flag_recheck_busy_prev && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_busy) begin
			t_enter_amb_family <= 64'd0;
			t_enter_dcsr_family <= 64'd0;
			t_enter_dcsir_family <= 64'd0;
		end
		flag_recheck_busy_prev <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_busy;
		if(!flag_recheck_accept_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_accept) begin
			flag_recheck_accept_seen <= 1'b1;
			flag_recheck_accept_takeover_safe_ok <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_takeover_safe;
		end
		if(!flag_recheck_done_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_sequence_done) begin
			flag_recheck_done_seen <= 1'b1;
		end
		if(!flag_recheck_failed_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_sequence_failed) begin
			flag_recheck_failed_seen <= 1'b1;
		end
		if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_RECHECK ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_APPLY ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_WAIT) &&
			(t_enter_amb_family == 64'd0)) begin
			t_enter_amb_family <= $time;
		end
		if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_WAIT ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_R ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_APPLY ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_WAIT) &&
			(t_enter_dcsr_family == 64'd0)) begin
			t_enter_dcsr_family <= $time;
		end
		if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_IR ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_APPLY ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_WAIT) &&
			(t_enter_dcsir_family == 64'd0)) begin
			t_enter_dcsir_family <= $time;
		end
	end


	//===================<owner生命周期轮：层次观测网>===================//
	wire w_sched_inflight = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_transaction_inflight; // 调度器owner在途
	wire [C_FRAME_ID_WIDTH - 1:0] w_frame = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_current_frame_id; // 当前宏帧号
	wire [12:0] w_mtick = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_macro_tick; // 宏帧相位
	wire [2:0] w_sf = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_subframe_index; // 校准子帧
	wire [9:0] w_lt = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_local_tick; // 校准局部相位
	wire w_normal_frame = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_normal_frame_active; // NORMAL宏帧活动
	wire w_commit = ppg_control_top_Inst.sched_adc_owner_commit_event_o; // owner提交
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] w_commit_idx = ppg_control_top_Inst.sched_adc_owner_sample_index_o; // 提交序号
	wire w_commit_cal = (ppg_control_top_Inst.sched_adc_owner_frame_type_o != 2'b10); // 提交的是校准owner
	wire w_commit_color = ppg_control_top_Inst.sched_adc_owner_color_ir_o; // 提交颜色
	wire w_done = ppg_control_top_Inst.ami_adc_transaction_complete_event_o; // AMI完成事件
	wire w_done_success = ppg_control_top_Inst.ami_adc_transaction_success_o; // 完成成功资格
	wire w_lost = ppg_control_top_Inst.ami_adc_transaction_lost_event_o; // AMI作废事件
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] w_cidx = ppg_control_top_Inst.ami_adc_complete_sample_index_o; // 完成/作废序号
	wire [15:0] w_owner_age = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.cnt_owner_age; // AMI owner年龄
	wire w_ami_fv = ppg_control_top_Inst.ami_fault_valid_o; // AMI故障记录
	wire [7:0] w_ami_fc = ppg_control_top_Inst.ami_fault_cause_o; // AMI故障原因
	wire w_sched_fv = ppg_control_top_Inst.sched_fault_valid_o; // 调度器故障记录
	wire w_ssw_fv = ppg_control_top_Inst.ssw_fault_valid_o; // SSW故障记录
	wire w_idac_commit = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_amb_code_update ||
		ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_dcs_r_code_update ||
		ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_dcs_ir_code_update; // IDAC码提交
	wire w_startup_done = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_startup_search_complete; // 启动搜索完成

	//===================<owner生命周期轮：被动监视>===================//
	integer cnt_sys_pass = 0;          // SYS-*检查通过数
	reg flag_sysfault_clear_req = 1'b0; // 主序列请求清零故障episode锁存
	integer cnt_cyc = 0;               // 拍计数
	integer cnt_q3 = 0;                // Q3上升沿累计
	integer cnt_bind_violation = 0;    // Q3不属于同帧/同子帧owner的次数
	integer cnt_lost_ev = 0;           // 作废事件累计
	integer cnt_excl_violation = 0;    // 作废与完成同拍次数
	integer cnt_done_ev = 0;           // 完成事件累计
	integer cnt_res = 0;               // 正式结果累计
	integer cnt_disc11 = 0;            // 原因11 discard累计
	integer cnt_ami02 = 0;             // AMI cause 02记录累计
	integer cnt_ami06 = 0;             // AMI cause 06记录累计
	integer cnt_ami07 = 0;             // AMI cause 07记录累计
	integer cnt_ssw_fault = 0;         // SSW故障记录累计
	integer cnt_sched_fault = 0;       // 调度器故障记录累计
	integer cnt_noprog = 0;            // 活性监视：无进展拍数
	integer cnt_live_fail = 0;         // 活性监视报错次数
	integer cnt_last_commit_cyc = 0;   // 最近提交拍
	integer cnt_lost_age = 0;          // 最近作废时距提交拍数
	reg [C_FRAME_ID_WIDTH - 1:0] reg_last_commit_frame = 0; // 最近提交帧
	reg [2:0] reg_last_commit_sf = 0;  // 最近提交子帧
	reg reg_last_commit_cal = 1'b0;    // 最近提交是否校准
	reg reg_last_commit_color = 1'b0;  // 最近提交颜色
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_last_commit_idx = 0; // 最近提交序号
	reg [C_FRAME_ID_WIDTH - 1:0] reg_lost_frame = 0; // 作废发生时的帧
	reg [12:0] reg_lost_mtick = 0;     // 作废发生时的宏帧相位
	reg [C_FRAME_ID_WIDTH - 1:0] reg_lost_commit_frame = 0; // 被作废owner的提交帧
	reg reg_lost_cal = 1'b0;           // 被作废owner是否校准
	reg reg_lost_color = 1'b0;         // 被作废owner颜色
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_lost_idx = 0; // 作废序号
	reg [1:0] reg_disc_type = 0;       // 最近原因11 discard类型
	reg reg_disc_color = 0;            // 最近原因11 discard颜色
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_disc_idx = 0; // 最近原因11 discard序号
	reg [C_FRAME_ID_WIDTH - 1:0] reg_max_red_res_frame = 0; // 最近RED结果帧
	reg [C_FRAME_ID_WIDTH - 1:0] reg_max_ir_res_frame = 0;  // 最近IR结果帧
	reg [1:0] reg_life_prev = 2'b00;   // 生命周期前值
	reg flag_q3_prev = 1'b0;           // Q3前值
	reg flag_live_reported = 1'b0;     // 本次停滞已报告
	reg flag_cal_lost_wait = 1'b0;     // 校准owner已作废，等待下一宏帧开始
	reg [C_FRAME_ID_WIDTH - 1:0] reg_cal_lost_frame = 0; // 校准作废发生时的宏帧号
	integer cnt_cal_lost_next = 0;     // 已记录"作废后下一宏帧类型"的校准作废次数
	reg [1:0] reg_cal_lost_next_cal = 2'b00; // 最近两次校准作废后的下一宏帧是否为校准帧，bit0为最近一次
	reg flag_r_trace = 1'b0;           // R阶段打印校准请求握手与IDAC样本接收时刻
	reg [C_FRAME_ID_WIDTH - 1:0] reg_busy_frame = 0; // 忙变体校准owner所在的校准宏帧
	reg flag_busy_frame_valid = 1'b0;  // 忙变体已开始，reg_busy_frame有效
	reg flag_busy_red_res = 1'b0;      // 忙变体的下一宏帧出现了RED正式结果
	reg flag_busy_next_commit = 1'b0;  // 忙变体的下一宏帧内出现了任何owner提交（RED/IR应拿不到ADC）
	integer reg_busy_red_dl_mtick = -1; // 忙变体下一宏帧中RED owner截止事件首次出现的宏帧相位（-1=未出现）
	integer reg_busy_ir_dl_mtick = -1;  // 同上，IR
	reg flag_sysfault_seen = 1'b0;     // 自上次清零以来出现过系统故障episode（abort清lane后episode很快关闭，须锁存）
	reg [7:0] reg_sysfault_cause = 8'h00; // 该episode开启时的首故障原因快照
	always @(posedge i_clk) begin
		cnt_cyc <= cnt_cyc + 1;
		flag_q3_prev <= o_clk_q3_low;
		reg_life_prev <= o_lifecycle_state;
		if(w_commit) begin
			cnt_last_commit_cyc <= cnt_cyc;
			reg_last_commit_frame <= w_frame;
			reg_last_commit_sf <= w_sf;
			reg_last_commit_cal <= w_commit_cal;
			reg_last_commit_color <= w_commit_color;
			reg_last_commit_idx <= w_commit_idx;
		end
		if(o_clk_q3_low && !flag_q3_prev) begin
			cnt_q3 <= cnt_q3 + 1;
			if(!w_sched_inflight || (reg_last_commit_frame != w_frame) || (reg_last_commit_cal && (reg_last_commit_sf != w_sf))) begin
				cnt_bind_violation <= cnt_bind_violation + 1;
				$display("SYSMON BIND-VIOLATION t=%0t frame=%0d mtick=%0d sf=%0d inflight=%b owner_frame=%0d owner_sf=%0d owner_cal=%b", $time, w_frame, w_mtick, w_sf,
					w_sched_inflight, reg_last_commit_frame, reg_last_commit_sf, reg_last_commit_cal);
			end
		end
		if(flag_cal_lost_wait && (w_frame != reg_cal_lost_frame) && (w_normal_frame ||
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active)) begin
			flag_cal_lost_wait <= 1'b0;
			cnt_cal_lost_next <= cnt_cal_lost_next + 1;
			reg_cal_lost_next_cal <= {reg_cal_lost_next_cal[0], ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active};
			$display("SYSMON NEXT-FRAME-AFTER-CAL-LOST t=%0t frame=%0d normal=%b", $time, w_frame, w_normal_frame);
		end
		if(w_done) cnt_done_ev <= cnt_done_ev + 1;
		if(o_system_fault_blocking && !flag_sysfault_seen) flag_sysfault_seen <= 1'b1;
		if(o_system_fault_cause_valid && o_system_fault_blocking) reg_sysfault_cause <= o_system_fault_cause;
		if(flag_sysfault_clear_req) begin flag_sysfault_seen <= 1'b0; reg_sysfault_cause <= 8'h00; end
		if(w_lost) begin
			cnt_lost_ev <= cnt_lost_ev + 1;
			cnt_lost_age <= cnt_cyc - cnt_last_commit_cyc;
			reg_lost_frame <= w_frame;
			reg_lost_mtick <= w_mtick;
			reg_lost_commit_frame <= reg_last_commit_frame;
			reg_lost_cal <= reg_last_commit_cal;
			reg_lost_color <= reg_last_commit_color;
			reg_lost_idx <= w_cidx;
			if(reg_last_commit_cal) begin flag_cal_lost_wait <= 1'b1; reg_cal_lost_frame <= w_frame; end
			if(w_done) cnt_excl_violation <= cnt_excl_violation + 1;
			$display("SYSMON LOST t=%0t frame=%0d mtick=%0d sf=%0d lt=%0d idx=%0d age=%0d cal=%b color=%b", $time, w_frame, w_mtick, w_sf, w_lt, w_cidx,
				cnt_cyc - cnt_last_commit_cyc, reg_last_commit_cal, reg_last_commit_color);
		end
		if(o_measurement_result_discard_event && (o_measurement_result_discard_reason == 2'b11)) begin
			cnt_disc11 <= cnt_disc11 + 1;
			reg_disc_type <= o_measurement_result_discard_frame_type;
			reg_disc_color <= o_measurement_result_discard_color_ir;
			reg_disc_idx <= o_measurement_result_discard_sample_index;
		end
		if(flag_r_trace && ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_calibration_request_fire)
			$display("SYSMON CALREQ t=%0t frame=%0d normal=%b cal=%b sf=%0d lt=%0d mtick=%0d", $time, w_frame, w_normal_frame,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active, w_sf, w_lt, w_mtick);
		if(flag_r_trace && (ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_amb_sample_accepted || ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_dcs_sample_accepted))
			$display("SYSMON CALACC t=%0t frame=%0d normal=%b cal=%b sf=%0d lt=%0d mtick=%0d amb=%b dcs=%b", $time, w_frame, w_normal_frame,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active, w_sf, w_lt, w_mtick, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_amb_sample_accepted, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_dcs_sample_accepted);
		if(flag_busy_frame_valid && w_commit && (w_frame == reg_busy_frame + 1'b1)) flag_busy_next_commit <= 1'b1;
		if(flag_busy_frame_valid && (w_frame == reg_busy_frame + 1'b1) && ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_red_owner_deadline && (reg_busy_red_dl_mtick < 0)) reg_busy_red_dl_mtick <= w_mtick;
		if(flag_busy_frame_valid && (w_frame == reg_busy_frame + 1'b1) && ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_ir_owner_deadline && (reg_busy_ir_dl_mtick < 0)) reg_busy_ir_dl_mtick <= w_mtick;
		if(flag_busy_frame_valid && o_measurement_result_valid && i_measurement_result_ready && !o_result_color_ir &&
			(o_result_frame_id == reg_busy_frame + 1'b1)) flag_busy_red_res <= 1'b1;
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_res <= cnt_res + 1;
			if(o_result_color_ir) reg_max_ir_res_frame <= o_result_frame_id; else reg_max_red_res_frame <= o_result_frame_id;
		end
		if(w_ami_fv && (w_ami_fc == 8'h02)) cnt_ami02 <= cnt_ami02 + 1;
		if(w_ami_fv && (w_ami_fc == 8'h06)) cnt_ami06 <= cnt_ami06 + 1;
		if(w_ami_fv && (w_ami_fc == 8'h07)) cnt_ami07 <= cnt_ami07 + 1;
		if(w_ssw_fv) cnt_ssw_fault <= cnt_ssw_fault + 1;
		if(w_sched_fv) cnt_sched_fault <= cnt_sched_fault + 1;
		if(w_ami_fv || w_ssw_fv || w_sched_fv)
			$display("SYSMON FAULT t=%0t ami=%b cause=%h ssw=%b sched=%b life=%b", $time, w_ami_fv, w_ami_fc, w_ssw_fv, w_sched_fv, o_lifecycle_state);
		// 通用活性监视：RUN或STOPPING中连续3个宏帧既无进展也未报系统故障即判停滞
		if(w_done || w_lost || (o_measurement_result_valid && i_measurement_result_ready) || w_idac_commit || (o_lifecycle_state != reg_life_prev) ||
			w_ami_fv || w_ssw_fv || w_sched_fv || o_system_fault_blocking || ((o_lifecycle_state != ST_RUN) && (o_lifecycle_state != ST_STOPPING))) begin
			cnt_noprog <= 0;
			flag_live_reported <= 1'b0;
		end else begin
			cnt_noprog <= cnt_noprog + 1;
			if((cnt_noprog >= 15000) && !flag_live_reported) begin
				flag_live_reported <= 1'b1;
				cnt_live_fail <= cnt_live_fail + 1;
				$display("FAIL SYS-LIVENESS silent stall: 15000 cycles in lifecycle=%b without progress or reported fault t=%0t frame=%0d inflight=%b", o_lifecycle_state, $time, w_frame, w_sched_inflight);
			end
		end
	end

	//===================<owner生命周期轮：后台ADC响应进程>===================//
	// 只在真实Q3释放后应答；按槽位丢弃、推迟或持续失联，其余一律以窗口内值150真实应答（校准搜索因此首候选即收敛）
	reg rsp_on = 1'b0;                 // 响应进程使能
	reg rsp_gen = 1'b0;                // NORMAL事务用真实生理生成器取值
	integer rsp_drop_red = 0;          // 接下来要丢弃的RED完成数
	integer rsp_drop_ir = 0;           // 接下来要丢弃的IR完成数
	integer rsp_drop_cal = 0;          // 接下来要丢弃的校准完成数
	reg rsp_dead_red = 1'b0;           // RED槽位持续失联
	reg rsp_dead_cal = 1'b0;           // 校准槽位持续失联
	integer rsp_cal_serial = 0;        // 已到达的校准Q3序号
	integer rsp_cal_delay_serial = 0;  // 需要推迟应答的校准Q3序号（0=不推迟）
	integer rsp_cal_delay_sf = 0;      // 推迟到的子帧
	integer rsp_cal_delay_lt = 0;      // 推迟到的local tick
	integer rsp_red_delay_tick = 0;    // 下一笔RED推迟到的宏帧相位（0=不推迟）
	integer cnt_rsp_skip = 0;          // 响应进程丢弃次数
	integer rsp_busy_cal_serial = 0;   // 该序号的校准Q3不应答且ADC保持忙到下一宏帧中途（0=不启用）
	integer rsp_busy_release_mtick = 2000; // 忙变体在下一宏帧该相位回空闲，不发DONE
	reg flag_busy_next_normal = 1'b0;  // 忙变体：下一宏帧按NORMAL起帧时校准owner仍在途
	reg flag_busy_dl_before = 1'b0;    // 忙变体开始时调度器owner截止sticky
	reg flag_busy_dl_after = 1'b0;     // 忙变体下一宏帧结束时调度器owner截止sticky
	reg flag_busy_released = 1'b0;     // 忙变体已在下一宏帧中途回空闲
	initial begin : bg_adc_responder
		reg r_cal;
		reg r_color;
		reg r_prec;
		reg [C_FRAME_ID_WIDTH - 1:0] r_frame;
		reg [9:0] r_raw;
		reg [9:0] r_target;
		integer r_unclamped;
		reg r_skip;
		integer r_guard;
		forever begin
			@(negedge i_clk);
			if(rsp_on && (o_clk_q3_low === 1'b1)) begin
				r_cal = reg_owner_snapshot_is_calibration;
				r_color = reg_owner_snapshot_color_ir;
				r_prec = reg_owner_snapshot_precision;
				r_frame = reg_owner_snapshot_frame_id;
				if(r_cal && $test$plusargs("OLR_DBG_GEN")) $display("SYSDBG calq3 t=%0t frame=%0d sf=%0d lt=%0d mtick=%0d", $time, r_frame, w_sf, w_lt, w_mtick);
				r_guard = 0;
				while((o_clk_q3_low === 1'b1) && (r_guard < 100)) begin
					@(negedge i_clk);
					r_guard = r_guard + 1;
				end
				r_skip = 1'b0;
				if(r_cal) begin
					rsp_cal_serial = rsp_cal_serial + 1;
					if((rsp_busy_cal_serial != 0) && (rsp_cal_serial == rsp_busy_cal_serial)) begin
						// 忙变体：转换已启动但DONE丢失，物理ADC一直忙，越过校准帧帧尾，到下一宏帧中途回空闲且始终无DONE
						i_adc_physical_idle = 1'b0;
						reg_busy_frame = r_frame;
						flag_busy_frame_valid = 1'b1;
						flag_busy_dl_before = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_owner_deadline_timeout_sticky;
						$display("SYSRSP busy start t=%0t frame=%0d sf=%0d lt=%0d deadline_sticky=%b", $time, r_frame, w_sf, w_lt, flag_busy_dl_before);
						r_guard = 0;
						while(!((w_frame != r_frame) && (w_normal_frame || ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active)) && (r_guard < 20000)) begin
							@(negedge i_clk);
							r_guard = r_guard + 1;
						end
						flag_busy_next_normal = w_normal_frame && w_sched_inflight;
						$display("SYSRSP busy next frame t=%0t frame=%0d normal=%b sched_inflight=%b", $time, w_frame, w_normal_frame, w_sched_inflight);
						r_guard = 0;
						while((w_mtick < rsp_busy_release_mtick) && (r_guard < 20000)) begin
							@(negedge i_clk);
							r_guard = r_guard + 1;
						end
						i_adc_physical_idle = 1'b1;
						flag_busy_released = 1'b1;
						$display("SYSRSP busy release t=%0t frame=%0d mtick=%0d", $time, w_frame, w_mtick);
						r_guard = 0;
						while((w_frame == reg_busy_frame + 1'b1) && (r_guard < 20000)) begin
							@(negedge i_clk);
							r_guard = r_guard + 1;
						end
						flag_busy_dl_after = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_owner_deadline_timeout_sticky;
						rsp_busy_cal_serial = 0;
						r_skip = 1'b1;
					end else if(rsp_dead_cal) r_skip = 1'b1;
					else if(rsp_drop_cal > 0) begin r_skip = 1'b1; rsp_drop_cal = rsp_drop_cal - 1; end
				end else if(!r_color) begin
					if(rsp_dead_red) r_skip = 1'b1;
					else if(rsp_drop_red > 0) begin r_skip = 1'b1; rsp_drop_red = rsp_drop_red - 1; end
				end else begin
					if(rsp_drop_ir > 0) begin r_skip = 1'b1; rsp_drop_ir = rsp_drop_ir - 1; end
				end
				if(r_skip) begin
					cnt_rsp_skip = cnt_rsp_skip + 1;
					$display("SYSRSP skip t=%0t cal=%b color=%b frame=%0d sf=%0d lt=%0d mtick=%0d", $time, r_cal, r_color, r_frame, w_sf, w_lt, w_mtick);
				end else begin
					if(r_cal && (rsp_cal_delay_serial != 0) && (rsp_cal_serial == rsp_cal_delay_serial)) begin
						r_guard = 0;
						while(!((w_sf == rsp_cal_delay_sf) && (w_lt >= rsp_cal_delay_lt)) && (r_guard < 20000)) begin
							@(negedge i_clk);
							r_guard = r_guard + 1;
						end
						rsp_cal_delay_serial = 0;
						$display("SYSRSP delayed calibration DONE t=%0t sf=%0d lt=%0d", $time, w_sf, w_lt);
					end
					if(!r_cal && !r_color && (rsp_red_delay_tick != 0)) begin
						r_guard = 0;
						while((w_mtick < rsp_red_delay_tick) && (r_guard < 6000)) begin
							@(negedge i_clk);
							r_guard = r_guard + 1;
						end
						rsp_red_delay_tick = 0;
						$display("SYSRSP delayed RED DONE t=%0t mtick=%0d", $time, w_mtick);
					end
					if(rsp_gen && !r_cal) begin
						task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, r_color, {16'd0, r_frame}, r_target, r_unclamped);
						make_fixed_raw(r_target, r_raw);
						if($test$plusargs("OLR_DBG_GEN") && ((r_frame % 10) == 0)) $display("SYSDBG gen frame=%0d color=%b target=%0d raw=%h prec=%b", r_frame, r_color, r_target, r_raw, r_prec);
					end else begin
						make_fixed_raw(150, r_raw);
					end
					drive_real_adc_done(r_cal ? 1'b0 : r_prec, r_raw, r_raw);
				end
			end
		end
	end

	//===================<owner生命周期轮：场景辅助任务>===================//
	// TB本地检查：PASS/FAIL行供回归脚本计数
	task sys_check;
		input [8 * 24 - 1:0] label;
		input cond;
		begin
			if(cond === 1'b1) begin
				cnt_sys_pass = cnt_sys_pass + 1;
				$display("PASS %0s", label);
			end else begin
				cnt_error = cnt_error + 1;
				$display("FAIL %0s t=%0t frame=%0d life=%b blocking=%b summary=%h cause=%h", label, $time, w_frame, o_lifecycle_state, o_system_fault_blocking,
					o_system_fault_summary, o_system_fault_cause);
			end
		end
	endtask

	// 清零故障episode锁存，场景开始前调用
	task sys_arm_fault;
		begin
			@(negedge i_clk); flag_sysfault_clear_req = 1'b1;
			@(negedge i_clk); flag_sysfault_clear_req = 1'b0;
		end
	endtask

	// 有界等待故障episode锁存
	task sys_wait_fault;
		input integer limit;
		integer k2;
		begin
			k2 = 0;
			while(!flag_sysfault_seen && (k2 < limit)) begin @(posedge i_clk); k2 = k2 + 1; end
			sys_wait(5);
		end
	endtask

	// 等待指定拍数
	task sys_wait;
		input integer n;
		begin
			repeat(n) @(posedge i_clk);
		end
	endtask

	// 有界等待生命周期到达目标值，返回是否到达
	task sys_wait_life;
		input [1:0] life;
		input integer limit;
		output ok;
		integer k;
		begin
			k = 0;
			while((o_lifecycle_state != life) && (k < limit)) begin
				@(posedge i_clk);
				k = k + 1;
			end
			ok = (o_lifecycle_state == life);
		end
	endtask

	// 有界等待作废事件计数超过基线
	task sys_wait_lost;
		input integer base;
		input integer limit;
		output ok;
		integer k;
		begin
			k = 0;
			while((cnt_lost_ev <= base) && (k < limit)) begin
				@(posedge i_clk);
				k = k + 1;
			end
			ok = (cnt_lost_ev > base);
		end
	endtask

	// 注册式诊断清除单拍
	task sys_diag_clear;
		begin
			@(negedge i_clk);
			i_diag_clear_event = 1'b1;
			@(posedge i_clk);
			#1 i_diag_clear_event = 1'b0;
			sys_wait(8);
		end
	endtask

	// 构造启动搜索配置：双光、SEARCH_TRACK，重检间隔保持默认4096
	task sys_build_search_config;
		begin
			task_build_normal_manual_dual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
		end
	endtask

	// 提交配置并START；kind=0双光MANUAL，1启动搜索，2周期重检生成器配置；返回是否进入RUN
	task sys_commit_start;
		input integer kind;
		output ok;
		reg life_ok;
		begin
			if(kind == 0) task_build_normal_manual_dual_config;
			else if(kind == 1) sys_build_search_config;
			else task_build_recheck_generator_config;
			task_pulse_source_update;
			task_wait_config_result;
			ok = o_commit_ack_event && !o_error_event && o_start_ready;
			if(!ok) $display("SYSINFO commit rejected ack=%b err=%b start_ready=%b code=%h life=%b blocking=%b", o_commit_ack_event, o_error_event, o_start_ready,
				o_last_error_code, o_lifecycle_state, o_system_fault_blocking);
			task_pulse_start;
			sys_wait_life(ST_RUN, 200, life_ok);
			ok = ok && life_ok;
		end
	endtask

	// STOP→诊断清除→START，不复位；先等回到CONFIG（系统STOP或主机STOP），返回重启是否被接受
	task sys_restart;
		input integer kind;
		input integer drain_limit;
		output ok;
		reg life_ok;
		begin
			if(o_lifecycle_state == ST_RUN) task_pulse_stop;
			sys_wait_life(ST_CONFIG, drain_limit, life_ok);
			sys_wait(20);
			sys_diag_clear;
			sys_commit_start(kind, ok);
			ok = ok && life_ok && !o_system_fault_blocking;
		end
	endtask

	// 物理idle保持为1、只拉CLK_DOUT的迟到DONE（模拟同步链窗口附近到达）
	task sys_done_keep_idle;
		reg [9:0] raw;
		begin
			make_fixed_raw(150, raw);
			i_dout_stage1_low = raw;
			i_dout_stage2_low = raw;
			i_clk_stage1_dout_low_async = 1'b1;
			repeat(5) @(negedge i_clk);
			i_clk_stage1_dout_low_async = 1'b0;
		end
	endtask

	// 等待下一笔指定颜色的NORMAL owner提交（返回其提交帧）
	task sys_wait_normal_commit;
		input color;
		input integer limit;
		output ok;
		integer k;
		begin
			k = 0;
			ok = 1'b0;
			while(!ok && (k < limit)) begin
				@(posedge i_clk);
				if(w_commit && !w_commit_cal && (w_commit_color == color)) ok = 1'b1;
				k = k + 1;
			end
			@(posedge i_clk);
		end
	endtask

	//===================<全局看门狗>===================//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL ADC_ANOMALY global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//===================<主序列>===================//
	initial begin : main_sequence
		reg ok;
		reg ok2;
		integer base_live;
		integer base_lost, base_res, base_disc, base_ami02, base_ami06, base_ami07, base_ssw, base_sched, base_q3, base_skip, base_done;
		reg [C_FRAME_ID_WIDTH - 1:0] f_lost;
		integer base_next, base_07;
		reg [C_FRAME_ID_WIDTH - 1:0] f_done;
		integer k;
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		cnt_owner_commit_total_rrc = 0;
		cnt_real_macro_frame_complete = 0;
		flag_fine_window_seen = 1'b0;
		flag_return_9bit_seen = 1'b0;
		flag_recheck_accept_seen = 1'b0;
		flag_recheck_accept_takeover_safe_ok = 1'b0;
		flag_recheck_done_seen = 1'b0;
		flag_recheck_failed_seen = 1'b0;
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

		//=========== 阶段N：双光MANUAL NORMAL ===========//
		if(!$test$plusargs("OLR_ONLY_R")) begin : phase_n_to_c
		rsp_on = 1'b1;
		sys_commit_start(0, ok);
		sys_wait(3 * 5001);
		sys_check("SYS-N-BASELINE", ok && (cnt_res >= 4) && (cnt_lost_ev == 0) && !o_system_fault_blocking && (cnt_bind_violation == 0));

		// SYS-LOST-RED（方案甲+L-4原场景DROPRED）：丢一次RED完成，同帧内年龄4500作废（早于下一帧RED接管），发原因11 discard，
		// 不升级故障、不出现SSW 0x21、不进STOPPING；下一帧RED/IR结果都正常
		base_lost = cnt_lost_ev; base_disc = cnt_disc11; base_ssw = cnt_ssw_fault;
		rsp_drop_red = 1;
		sys_wait_lost(base_lost, 12000, ok);
		f_lost = reg_lost_commit_frame;
		sys_wait(2 * 5001);
		$display("SYSINFO LOST-RED age=%0d lost_frame=%0d commit_frame=%0d mtick=%0d red_res_frame=%0d ir_res_frame=%0d", cnt_lost_age, reg_lost_frame, f_lost, reg_lost_mtick,
			reg_max_red_res_frame, reg_max_ir_res_frame);
		sys_check("SYS-LOST-RED", ok && (cnt_lost_age >= 4500) && (cnt_lost_age <= 4504) && (reg_lost_frame == f_lost) && (reg_lost_mtick < 13'd4999) && !reg_lost_cal && !reg_lost_color &&
			(cnt_disc11 == base_disc + 1) && (reg_disc_type == 2'b10) && (reg_disc_color == 1'b0) && (cnt_ssw_fault == base_ssw) && !o_system_fault_blocking &&
			(o_lifecycle_state == ST_RUN) && (reg_max_red_res_frame > f_lost) && (reg_max_ir_res_frame > f_lost) && ppg_control_top_Inst.o_ami_owner_lost_sticky); // 方案甲：作废释放、下一帧RED/IR结果照常产生、历史sticky置位

		// SYS-LOST-IR（方案甲+L-1 NORMAL原场景DROPIR）：丢一次IR完成，同帧作废，下一帧不在旧IR owner名下执行Q3、不输出错帧号结果
		base_lost = cnt_lost_ev;
		rsp_drop_ir = 1;
		sys_wait_lost(base_lost, 12000, ok);
		f_lost = reg_lost_commit_frame;
		sys_wait(2 * 5001);
		sys_check("SYS-LOST-IR", ok && (reg_lost_frame == f_lost) && reg_lost_color && !reg_lost_cal && !o_system_fault_blocking && (o_lifecycle_state == ST_RUN) &&
			(reg_max_ir_res_frame > f_lost) && (cnt_bind_violation == 0) && (cnt_excl_violation == 0)); // L-1 @satisfies: SSW-38

		// SYS-K-CLEAR：RED丢一次→RED正常→RED再丢一次，按槽位计数被真实完成清零，不升级
		base_ami06 = cnt_ami06; base_lost = cnt_lost_ev;
		rsp_drop_red = 1;
		sys_wait_lost(base_lost, 12000, ok);
		sys_wait(5001);
		base_lost = cnt_lost_ev;
		rsp_drop_red = 1;
		sys_wait_lost(base_lost, 12000, ok2);
		sys_wait(3000);
		sys_check("SYS-K-CLEAR", ok && ok2 && (cnt_ami06 == base_ami06) && !o_system_fault_blocking && (o_lifecycle_state == ST_RUN));

		// SYS-LATE-RED（合法迟到）：RED完成推迟到宏帧相位400（仍远小于4500），不作废、照常成功、不升级
		base_lost = cnt_lost_ev; base_done = cnt_done_ev;
		rsp_red_delay_tick = 400;
		sys_wait(2 * 5001);
		sys_check("SYS-LATE-RED", (cnt_lost_ev == base_lost) && (cnt_done_ev > base_done) && !o_system_fault_blocking && (o_lifecycle_state == ST_RUN));

		// SYS-K-RED2：只有RED一路持续失联（IR应答正常），第2次RED作废报cause 06，身份为RED；随后系统STOP排空结束
		base_ami06 = cnt_ami06; base_lost = cnt_lost_ev;
		sys_arm_fault;
		rsp_dead_red = 1'b1;
		sys_wait_fault(30000);
		$display("SYSINFO K-RED2 lost=%0d cause=%h color=%b type=%0d summary=%h ir_count=%0d", cnt_lost_ev - base_lost, o_system_fault_cause, o_system_fault_color_ir,
			o_system_fault_frame_type, o_system_fault_summary, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.cnt_lost_ir);
		sys_check("SYS-K-RED2", flag_sysfault_seen && (cnt_ami06 == base_ami06 + 1) && (cnt_lost_ev == base_lost + 2) && (o_system_fault_cause == 8'h06) &&
			(o_system_fault_source == 4'h1) && (o_system_fault_color_ir == 1'b0) && (o_system_fault_frame_type == 2'b10) && o_system_fault_summary[9] &&
			(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.cnt_lost_ir == 4'd0)); // 同槽位真实完成清零连续作废计数
		rsp_dead_red = 1'b0;
		sys_wait_life(ST_CONFIG, 20000, ok);
		sys_check("SYS-K-STOP", ok && !o_system_fault_blocking);
		// SYS-RESTART-K：STOP→诊断清除→START不复位，START被接受并恢复出结果
		base_res = cnt_res;
		sys_restart(0, 20000, ok);
		sys_wait(3 * 5001);
		sys_check("SYS-RESTART-K", ok && (cnt_res > base_res + 3) && !o_system_fault_blocking);

		// SYS-DRAIN-LOST（STOP排空中丢失）：RED owner提交后不给DONE并立即STOP，排空在作废后结束，不卡死
		rsp_drop_red = 1;
		sys_wait_normal_commit(1'b0, 12000, ok);
		base_lost = cnt_lost_ev;
		task_pulse_stop;
		sys_wait_life(ST_CONFIG, 12000, ok2);
		sys_check("SYS-DRAIN-LOST", ok && ok2 && (cnt_lost_ev == base_lost + 1) && !o_system_fault_blocking);
		sys_restart(0, 2000, ok);
		sys_check("SYS-RESTART-DRAIN", ok);

		// SYS-LATE-DRAIN + SYS-L5-RESTART（迟到旧DONE①排空期间，L-5原场景）：RED连续失联→cause 06→abort+系统STOP；排空期间到达的旧DONE
		// 被拒（cause 02记录、无完成事件），lane随RUN结束排空落下，诊断清除后START被接受
		rsp_dead_red = 1'b1;
		k = 0;
		while(!o_system_fault_blocking && (k < 30000)) begin @(posedge i_clk); k = k + 1; end
		rsp_dead_red = 1'b0;
		rsp_on = 1'b0;
		sys_wait_life(ST_STOPPING, 200, ok);
		base_ami02 = cnt_ami02; base_done = cnt_done_ev;
		drive_real_adc_done(1'b0, 10'h125, 10'h125);
		sys_wait(20);
		sys_wait_life(ST_CONFIG, 20000, ok2);
		sys_check("SYS-LATE-DRAIN", ok && ok2 && (cnt_ami02 == base_ami02 + 1) && (cnt_done_ev == base_done) && o_system_fault_summary[1] && o_system_fault_summary[9]);
		rsp_on = 1'b1;
		sys_restart(0, 2000, ok);
		sys_check("SYS-L5-RESTART", ok);

		// SYS-LATE-IDLE（迟到旧DONE②排空完成后的空闲期）：作废一次后主机STOP回CONFIG，空闲期到达旧DONE留下cause 02记录，START仍被接受
		base_lost = cnt_lost_ev;
		rsp_drop_red = 1;
		sys_wait_lost(base_lost, 12000, ok);
		rsp_on = 1'b0;
		sys_wait(400);
		task_pulse_stop;
		sys_wait_life(ST_CONFIG, 12000, ok2);
		sys_wait(50);
		base_ami02 = cnt_ami02; base_done = cnt_done_ev;
		drive_real_adc_done(1'b0, 10'h125, 10'h125);
		sys_wait(200);
		sys_check("SYS-LATE-IDLE", ok && ok2 && (cnt_ami02 == base_ami02 + 1) && (cnt_done_ev == base_done) && o_ami_integration_protocol_error_sticky);
		rsp_on = 1'b1;
		sys_restart(0, 2000, ok);
		sys_check("SYS-RESTART-IDLE", ok);

		// SYS-LATE-NEXTRUN（迟到旧DONE③下一次RUN、首个start fire之前）：作废→STOP→新START后立刻到达旧DONE（物理忙，阻止新事务启动）
		// 必须按无owner捕获拒绝并升级，不得绑定到新owner；随后STOP→诊断清除→START恢复
		base_lost = cnt_lost_ev;
		rsp_drop_red = 1;
		sys_wait_lost(base_lost, 12000, ok);
		rsp_on = 1'b0;
		sys_wait(400);
		task_pulse_stop;
		sys_wait_life(ST_CONFIG, 12000, ok2);
		sys_diag_clear;
		task_build_normal_manual_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		base_ami02 = cnt_ami02; base_done = cnt_done_ev;
		sys_arm_fault;
		task_pulse_start;
		drive_real_adc_done(1'b0, 10'h125, 10'h125);
		rsp_on = 1'b1;
		sys_wait_fault(2000);
		sys_check("SYS-LATE-NEXTRUN", ok && ok2 && (cnt_ami02 == base_ami02 + 1) && (cnt_done_ev == base_done) && flag_sysfault_seen && (reg_sysfault_cause == 8'h02));
		sys_restart(0, 20000, ok);
		sys_wait(5001);
		sys_check("SYS-RESTART-NEXTRUN", ok && !o_system_fault_blocking && (cnt_bind_violation == 0));

		// SYS-WIN-BEFORE / SYS-WIN-IN / SYS-WIN-AFTER（竞争窗口）：物理idle保持1只拉CLK_DOUT；年龄4497到达按正常完成；4499到达时作废先发生、
		// 迟到完成被拒并报cause 02，STOP后不复位重启；作废后到达同样被拒
		base_lost = cnt_lost_ev; base_done = cnt_done_ev;
		rsp_drop_red = 1;
		sys_wait_normal_commit(1'b0, 12000, ok);
		k = 0; while((w_owner_age != 4497) && (k < 6000)) begin @(negedge i_clk); k = k + 1; end
		sys_done_keep_idle;
		sys_wait(20);
		sys_check("SYS-WIN-BEFORE", ok && (cnt_lost_ev == base_lost) && (cnt_done_ev == base_done + 1) && !o_system_fault_blocking);
		sys_wait(5001);
		base_lost = cnt_lost_ev; base_ami02 = cnt_ami02; base_done = cnt_done_ev;
		sys_arm_fault;
		rsp_drop_red = 1;
		sys_wait_normal_commit(1'b0, 12000, ok);
		k = 0; while((w_owner_age != 4499) && (k < 6000)) begin @(negedge i_clk); k = k + 1; end
		sys_done_keep_idle;
		sys_wait(40);
		sys_check("SYS-WIN-IN", ok && (cnt_lost_ev == base_lost + 1) && (cnt_ami02 == base_ami02 + 1) && (cnt_done_ev == base_done) && flag_sysfault_seen && (reg_sysfault_cause == 8'h02));
		sys_restart(0, 20000, ok);
		sys_check("SYS-RESTART-WIN", ok);
		base_lost = cnt_lost_ev; base_ami02 = cnt_ami02; base_done = cnt_done_ev;
		sys_arm_fault;
		rsp_drop_red = 1;
		sys_wait_lost(base_lost, 12000, ok);
		rsp_on = 1'b0;
		sys_wait(100);
		sys_done_keep_idle;
		sys_wait(40);
		rsp_on = 1'b1;
		sys_check("SYS-WIN-AFTER", ok && (cnt_ami02 == base_ami02 + 1) && (cnt_done_ev == base_done) && flag_sysfault_seen && (reg_sysfault_cause == 8'h02));
		sys_restart(0, 20000, ok);
		sys_check("SYS-RESTART-WIN2", ok);

		// SYS-BUSY-Q3 / SYS-BUSY-07 / SYS-BUSY-WDOG / SYS-BUSY-RECOVER（ADC长期不回空闲）：RED owner的Q3释放后物理ADC一直忙、不给DONE；
		// 年龄超过4717后下一帧RED的Q3被压掉；年龄9000报cause 07→abort+系统STOP；排空中看门狗再报0x31；ADC回idle后作废、排空结束、重启
		rsp_on = 1'b0;
		sys_wait_normal_commit(1'b0, 12000, ok);
		f_lost = w_frame;
		wait_q3_release(ok2);
		i_adc_physical_idle = 1'b0;
		k = 0; while((w_frame == f_lost) && (k < 6000)) begin @(posedge i_clk); k = k + 1; end
		base_q3 = cnt_q3;
		k = 0; while((w_mtick < 13'd330) && (k < 400)) begin @(posedge i_clk); k = k + 1; end
		sys_check("SYS-BUSY-Q3", ok && ok2 && (cnt_q3 == base_q3) && w_sched_inflight && (w_owner_age > 16'd4717) && (cnt_bind_violation == 0)); // L-1第二道防线 @satisfies: SSW-38
		base_ami07 = cnt_ami07; base_lost = cnt_lost_ev;
		k = 0; while(!o_system_fault_blocking && (k < 6000)) begin @(posedge i_clk); k = k + 1; end
		sys_wait(5);
		sys_check("SYS-BUSY-07", (cnt_ami07 == base_ami07 + 1) && (o_system_fault_cause == 8'h07) && o_system_fault_summary[10] && (cnt_lost_ev == base_lost) && w_sched_inflight);
		k = 0; while(!o_system_fault_summary[6] && (k < 8000)) begin @(posedge i_clk); k = k + 1; end
		sys_check("SYS-BUSY-WDOG", o_system_fault_summary[6] && (o_lifecycle_state == ST_STOPPING));
		i_adc_physical_idle = 1'b1;
		sys_wait_life(ST_CONFIG, 2000, ok);
		sys_check("SYS-BUSY-RECOVER", ok && (cnt_lost_ev == base_lost + 1) && !w_sched_inflight);
		rsp_on = 1'b1;
		sys_restart(0, 2000, ok);
		sys_wait(2 * 5001);
		sys_check("SYS-RESTART-BUSY", ok && !o_system_fault_blocking);
		task_pulse_stop;
		sys_wait_life(ST_CONFIG, 12000, ok);

		//=========== 阶段C：启动搜索（校准路径） ===========//
		// SYS-CAL-LATE385（合法迟到+S1）：第1笔校准完成推迟到同子帧local tick 400，不作废，S1迟到诊断置位，搜索照常完成
		sys_diag_clear;
		base_lost = cnt_lost_ev;
		rsp_cal_serial = 0; rsp_cal_delay_serial = 1; rsp_cal_delay_sf = 0; rsp_cal_delay_lt = 400;
		sys_commit_start(1, ok);
		k = 0; while(!w_startup_done && (k < 60000)) begin @(posedge i_clk); k = k + 1; end
		sys_check("SYS-CAL-LATE385", ok && w_startup_done && (cnt_lost_ev == base_lost) && o_ssw_calibration_timeout_sticky && !o_system_fault_blocking); // S1
		task_pulse_stop;
		sys_wait_life(ST_CONFIG, 12000, ok);

		// SYS-CAL-LATE6SF（实测最晚合法迟到+L-3原场景）：第2笔校准（sf1提交）完成推迟到sf7 local tick 600，不作废、按其码消费，
		// 末子帧385之后才消费也不死锁，启动搜索完成
		sys_diag_clear;
		base_lost = cnt_lost_ev;
		rsp_cal_serial = 0; rsp_cal_delay_serial = 2; rsp_cal_delay_sf = 7; rsp_cal_delay_lt = 600;
		sys_commit_start(1, ok);
		k = 0; while(!w_startup_done && (k < 80000)) begin @(posedge i_clk); k = k + 1; end
		sys_check("SYS-CAL-LATE6SF", ok && w_startup_done && (cnt_lost_ev == base_lost) && !o_system_fault_blocking); // L-3
		task_pulse_stop;
		sys_wait_life(ST_CONFIG, 12000, ok);

		// SYS-CAL-LOST（L-1校准原场景NODONE）：第2笔校准完成丢失，年龄4500作废（discard类型为校准），撤销后重发同一候选，搜索完成且无错绑
		sys_diag_clear;
		base_lost = cnt_lost_ev; base_disc = cnt_disc11;
		rsp_cal_serial = 0; rsp_drop_cal = 0;
		sys_commit_start(1, ok);
		k = 0; while((rsp_cal_serial < 1) && (k < 20000)) begin @(posedge i_clk); k = k + 1; end
		rsp_drop_cal = 1;
		k = 0; while(!w_startup_done && (k < 80000)) begin @(posedge i_clk); k = k + 1; end
		sys_check("SYS-CAL-LOST", ok && w_startup_done && (cnt_lost_ev == base_lost + 1) && reg_lost_cal && (cnt_disc11 == base_disc + 1) && (reg_disc_type != 2'b10) &&
			!o_system_fault_blocking && (cnt_bind_violation == 0)); // L-1 @satisfies: FSC-17
		task_pulse_stop;
		sys_wait_life(ST_CONFIG, 12000, ok);

		// SYS-CAL-K2 / SYS-RESTART-CAL：启动搜索中校准持续失联，第2次校准作废报cause 06（类型为校准）；STOP→诊断清除→START后搜索完成
		sys_diag_clear;
		base_ami06 = cnt_ami06;
		rsp_dead_cal = 1'b1;
		sys_arm_fault;
		sys_commit_start(1, ok);
		sys_wait_fault(40000);
		sys_check("SYS-CAL-K2", ok && flag_sysfault_seen && (cnt_ami06 == base_ami06 + 1) && (o_system_fault_cause == 8'h06) && (o_system_fault_frame_type != 2'b10));
		rsp_dead_cal = 1'b0;
		sys_restart(1, 20000, ok);
		k = 0; while(!w_startup_done && (k < 60000)) begin @(posedge i_clk); k = k + 1; end
		sys_check("SYS-RESTART-CAL", ok && w_startup_done && !o_system_fault_blocking);
		task_pulse_stop;
		sys_wait_life(ST_CONFIG, 12000, ok);

		end
		// 负对照快速运行可用+OLR_SKIP_R跳过本阶段（约25分钟仿真）；正式回归不带该参数
		if(!$test$plusargs("OLR_SKIP_R")) begin : phase_r
			//=========== 阶段R：周期重检中的校准完成丢失 ===========//
			// 真实生成器驱动到SAR9→15→9往返与重检接管。各重检阶段首次取样都在新校准宏帧的第0子帧、local tick 248前提交（实测，结构原因见报告），
			// 年龄4500的作废落在同一5000拍校准帧的子帧7内，单纯丢DONE时校准owner不会在途跨入NORMAL帧。
			// SYS-CAL-LOST-RETRY：第1笔重检校准Q3不应答，作废后的下一宏帧是校准重试帧，重检照常完成，之后NORMAL帧RED/IR有结果，全程零错绑。
			// SYS-CAL-BUSY-NORMAL（设计§10.7本意的可达变体）：第3笔重检校准Q3不应答且物理ADC保持忙，越过校准帧帧尾，到下一宏帧tick 2000回空闲且无DONE。
			// 实测第3笔是重试帧内sf1起动的下一阶段owner：跨帧重试后阶段帧完成锁存沿用上一帧（统筹F-9），下一阶段在重试帧内接管。
			// 预期：帧尾不重挂（L-1），下一帧按NORMAL起帧，该帧无owner提交、RED截止事件出现、无RED结果；回空闲后作废（年龄<9000，无cause 07），
			// F-020撤销后重新请求，下一帧为校准重试，重检完成；全程零错绑、活性监视不报、无系统故障
			sys_diag_clear;
			rsp_on = 1'b0;
			task_build_recheck_generator_config;
			task_pulse_source_update;
			task_wait_config_result;
			task_pulse_start;
			repeat(8) @(posedge i_clk);
			task_run_startup_search;
			flag_recheck_accept_seen = 1'b0;
			flag_recheck_done_seen = 1'b0;
			flag_recheck_failed_seen = 1'b0;
			base_lost = cnt_lost_ev; base_q3 = cnt_bind_violation;
			base_next = cnt_cal_lost_next; base_07 = cnt_ami07; base_live = cnt_live_fail;
			rsp_gen = 1'b1;
			rsp_cal_serial = 0;
			rsp_drop_cal = 1;
			rsp_busy_cal_serial = 3;
			flag_r_trace = 1'b1;
			rsp_on = 1'b1;
			k = 0;
			while(!flag_recheck_done_seen && !flag_recheck_failed_seen && (k < 6000000) && !flag_global_timeout) begin
				@(posedge i_clk);
				k = k + 1;
				if((k % 100000) == 0) $display("SYSINFO RECHECK-PROGRESS k=%0d frame=%0d results=%0d fine=%b return=%b pending=%b accept=%b precision=%b life=%b", k, w_frame, cnt_res,
					flag_fine_window_seen, flag_return_9bit_seen, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending,
					flag_recheck_accept_seen, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_active_precision_mode, o_lifecycle_state);
			end
			f_done = w_frame;
			k = 0;
			while(((reg_max_red_res_frame <= f_done) || (reg_max_ir_res_frame <= f_done)) && (k < 30000)) begin @(posedge i_clk); k = k + 1; end
			flag_r_trace = 1'b0;
			$display("SYSINFO RECHECK accept=%b done=%b failed=%b done_frame=%0d lost=%0d next_after_cal_lost=%0d/%b bind=%0d red_res=%0d ir_res=%0d", flag_recheck_accept_seen,
				flag_recheck_done_seen, flag_recheck_failed_seen, f_done, cnt_lost_ev - base_lost, cnt_cal_lost_next - base_next, reg_cal_lost_next_cal,
				cnt_bind_violation - base_q3, reg_max_red_res_frame, reg_max_ir_res_frame);
			$display("SYSINFO BUSY frame=%0d red_deadline_mtick=%0d ir_deadline_mtick=%0d next_normal=%b next_commit=%b red_res_in_next=%b deadline_sticky %b->%b released=%b last_lost frame=%0d age=%0d cal=%b ami07=%0d live_fail=%0d",
				reg_busy_frame, reg_busy_red_dl_mtick, reg_busy_ir_dl_mtick, flag_busy_next_normal, flag_busy_next_commit, flag_busy_red_res, flag_busy_dl_before, flag_busy_dl_after, flag_busy_released, reg_lost_frame, cnt_lost_age,
				reg_lost_cal, cnt_ami07 - base_07, cnt_live_fail - base_live);
			sys_check("SYS-CAL-LOST-RETRY", flag_recheck_accept_seen && flag_recheck_done_seen && (cnt_cal_lost_next == base_next + 2) && reg_cal_lost_next_cal[1] &&
				(reg_max_red_res_frame > f_done) && (reg_max_ir_res_frame > f_done) && (cnt_bind_violation == base_q3)); // F-020/L-1
			sys_check("SYS-CAL-BUSY-NORMAL", flag_recheck_done_seen && flag_busy_released && flag_busy_next_normal && !flag_busy_next_commit && !flag_busy_red_res && (reg_busy_red_dl_mtick >= 0) &&
				reg_lost_cal && (reg_lost_frame == reg_busy_frame + 1'b1) && (cnt_lost_age >= 4500) && (cnt_lost_age < 9000) &&
				reg_cal_lost_next_cal[0] && (cnt_lost_ev == base_lost + 2) && (cnt_ami07 == base_07) && (cnt_live_fail == base_live) &&
				(cnt_bind_violation == base_q3) && !o_system_fault_blocking); // L-1/F-020
			rsp_gen = 1'b0;
			rsp_busy_cal_serial = 0;
			task_pulse_stop;
			sys_wait_life(ST_CONFIG, 12000, ok);
		end

		//=========== 阶段B：ADC永不回空闲 ===========//
		// SYS-BUSY-FOREVER：ADC卡忙不恢复时停在STOPPING并已报cause 07与看门狗0x31，系统故障阻断保持，不是静默卡死（活性监视不报）
		sys_diag_clear;
		rsp_on = 1'b1;
		sys_commit_start(0, ok);
		sys_wait(5001);
		rsp_on = 1'b0;
		sys_wait_normal_commit(1'b0, 12000, ok);
		wait_q3_release(ok2);
		i_adc_physical_idle = 1'b0;
		k = 0; while(!o_system_fault_summary[6] && (k < 20000)) begin @(posedge i_clk); k = k + 1; end
		base_live = cnt_live_fail;
		sys_wait(30000);
		sys_check("SYS-BUSY-FOREVER", ok && ok2 && (o_lifecycle_state == ST_STOPPING) && o_system_fault_blocking && o_system_fault_summary[10] && o_system_fault_summary[6] &&
			(cnt_live_fail == base_live));

		// 全程监视量
		sys_check("SYS-MON-BIND", cnt_bind_violation == 0);
		sys_check("SYS-MON-EXCL", (cnt_excl_violation == 0) && (cnt_lost_ev > 0));
		sys_check("SYS-MON-LIVE", cnt_live_fail == 0);
		$display("SYSINFO totals lost=%0d done=%0d results=%0d disc11=%0d ami02=%0d ami06=%0d ami07=%0d ssw_fault=%0d sched_fault=%0d skip=%0d",
			cnt_lost_ev, cnt_done_ev, cnt_res, cnt_disc11, cnt_ami02, cnt_ami06, cnt_ami07, cnt_ssw_fault, cnt_sched_fault, cnt_rsp_skip);
		if((cnt_error == 0) && (cnt_sys_pass == 37)) begin
			$display("ADC_ANOMALY_TB_PASS checks=%0d", cnt_sys_pass);
		end else begin
			$display("FAIL ADC_ANOMALY_TB pass=%0d errors=%0d", cnt_sys_pass, cnt_error);
		end
		$finish;
	end

endmodule
