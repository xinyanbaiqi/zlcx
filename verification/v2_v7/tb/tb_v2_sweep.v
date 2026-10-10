`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/10/10
// Design Name:        V2 Per-Tick Sweep Testbench (ppg_control_top + supervisor)
// Module Name:        tb_v2_sweep
// Description:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.3
// Simulations:        Vivado xsim 2022.2 (compiled once, one xsim run per sweep point via -testplusarg)
//
// Referrences:        verification_reports/PRE_TAPEOUT_CLOSURE_PLAN_20261009.md V2,
//                     rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v V1.2 (copy source, see below)
//
// Dependencies:       ppg_control_top.v and its full hierarchy (rtl/ppg_control_top/xsim_adc_anomaly_filelist.f),
//                     rtl/ppg_control_top/tb_ppg_real_raw_generator.vh (included unmodified through -i),
//                     verification/v2_v7/adc_model/v2_adc_behavior_model.v, verification/v2_v7/monitors/*.v
//
// Version:            V1.0
// Revision Date:      2026/10/10
// History:
//    Time               Version       Revised by            Contents
// 2026/10/10            V1.0          Erie                  Create file. Parameterized single-point sweep testbench. Copied verbatim from tb_ppg_control_top_adc_anomaly.v V1.2 (main 2f0c0d0): localparams and V5 reset profile (lines 55-105), signal declarations and the ppg_control_top instance (lines 107-403; the four ADC inputs and i_adc_physical_idle become wires driven by the V2 ADC model), clock generators (405-415), config tasks task_build_normal_manual_config / task_build_normal_manual_dual_config (417-479) and task_build_recheck_generator_config (481-493), source/START/STOP pulse tasks (507-534), task_wait_config_result (536-551), make_fixed_raw (641-654), the owner snapshot process (659-675) and sys_build_search_config (1301-1307). New: the V2 ADC behaviour model replaces bg_adc_responder; the six resident monitor cores with a print layer (V2MON / V2MON-DETAIL lines); plusarg-selected mode (DUAL9, RED15, SEARCH, RECHECK, GEN_DUAL), event (NONE, STOP, START_DELAY, ABORT, LOST, LATE, BUSY, FOREVER, DIAG_CLEAR, COMMIT) and target (macro frame + tick, or calibration subframe + local tick); per-point flow reset -> config -> START -> target frame -> inject -> recover (CONFIG, delay, diag clear, COMMIT, START) -> post frames -> V2POINT line. Every point records where the DUT actually saw the event (V2LAND) and whether that matches the target.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年10月10日
// 设计名称:           V2逐拍扫描测试平台（ppg_control_top含supervisor）
// 模块名称:           tb_v2_sweep
// 模块说明:           verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.3节
// 仿真工程:           Vivado xsim 2022.2（只编译一次，每个扫描点用-testplusarg单独运行xsim）
//
// 参考资料:           PRE_TAPEOUT_CLOSURE_PLAN_20261009.md V2，tb_ppg_control_top_adc_anomaly.v V1.2（复制来源，见下）
//
// 依赖文件:           ppg_control_top.v及完整层次（xsim_adc_anomaly_filelist.f）、tb_ppg_real_raw_generator.vh（经-i原样包含）、
//                     v2_adc_behavior_model.v、monitors/*.v
//
// 当前版本:           V1.0
// 修订日期:           2026年10月10日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年10月10日        V1.0          Erie                  创建文件。参数化单点扫描TB。从tb_ppg_control_top_adc_anomaly.v V1.2（main 2f0c0d0）原样复制：localparam与V5复位档案（第55~105行）、信号声明与ppg_control_top例化（第107~403行；四路ADC输入与i_adc_physical_idle改为由V2 ADC模型驱动的wire）、时钟（405~415）、配置task（417~479、481~493）、source/START/STOP脉冲task（507~534）、task_wait_config_result（536~551）、make_fixed_raw（641~654）、owner快照进程（659~675）、sys_build_search_config（1301~1307）。新写：以V2 ADC行为模型替代bg_adc_responder；六个常驻监视器核心及打印层（V2MON/V2MON-DETAIL行）；plusargs选择工作模式（DUAL9、RED15、SEARCH、RECHECK、GEN_DUAL）、事件（NONE、STOP、START_DELAY、ABORT、LOST、LATE、BUSY、FOREVER、DIAG_CLEAR、COMMIT）与目标落点（宏帧号+tick，或校准子帧+local tick）；单点流程：复位→配置→START→目标帧→注入→恢复（回CONFIG、等待、诊断清除、COMMIT、START）→后续若干帧→V2POINT结论行。每个点记录DUT实际看到事件的拍（V2LAND）并核对是否与目标一致。

// V2逐拍扫描：单点参数化注入与常驻监视
module tb_v2_sweep();

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
	wire [9:0] i_dout_stage1_low;
	wire i_clk_stage1_dout_low_async;
	wire [9:0] i_dout_stage2_low;
	wire i_clk_stage2_dout_low_async;
	wire i_adc_physical_idle;
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

	// 构造启动搜索配置：双光、SEARCH_TRACK，重检间隔保持默认4096
	task sys_build_search_config;
		begin
			task_build_normal_manual_dual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
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

	//===================<V2：前置声明>===================//
	reg [1:0] reg_v2_life_prev;              // 生命周期前值（活性进展）
	reg v2_f3_window;                        // TB声明的F-3合同前提外窗口（扫描默认不注入）

	//===================<V2：层次只读观测网>===================//
	wire w_sched_inflight = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_transaction_inflight; // 调度器owner在途
	wire [C_FRAME_ID_WIDTH - 1:0] w_frame = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_current_frame_id; // 当前宏帧号
	wire [12:0] w_mtick = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_macro_tick; // 宏帧相位
	wire [2:0] w_sf = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_subframe_index; // 校准子帧
	wire [9:0] w_lt = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_local_tick; // 校准局部相位
	wire w_normal_frame = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_normal_frame_active; // NORMAL宏帧活动
	wire w_cal_frame = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active; // 校准宏帧活动
	wire w_frame_start_ev = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_macro_frame_start_event; // 宏帧起点单拍
	wire w_stop_ack_s = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_stop_ack_event; // 调度器看到的STOP确认
	wire w_start_ack_s = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_start_ack_event; // 调度器看到的START确认
	wire w_abort_s = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_control_abort_event; // 调度器看到的owner-abort合并事件
	wire w_commit = ppg_control_top_Inst.sched_adc_owner_commit_event_o; // owner提交
	wire w_commit_cal = (ppg_control_top_Inst.sched_adc_owner_frame_type_o != 2'b10); // 提交的是校准owner
	wire w_done = ppg_control_top_Inst.ami_adc_transaction_complete_event_o; // AMI完成事件
	wire w_done_success = ppg_control_top_Inst.ami_adc_transaction_success_o; // 完成成功资格
	wire w_lost = ppg_control_top_Inst.ami_adc_transaction_lost_event_o; // AMI作废事件
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] w_cidx = ppg_control_top_Inst.ami_adc_complete_sample_index_o; // 完成/作废序号
	wire w_ami_fv = ppg_control_top_Inst.ami_fault_valid_o; // AMI故障记录
	wire w_sched_fv = ppg_control_top_Inst.sched_fault_valid_o; // 调度器故障记录
	wire w_ssw_fv = ppg_control_top_Inst.ssw_fault_valid_o; // SSW故障记录
	wire w_idac_commit = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_amb_code_update ||
		ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_dcs_r_code_update ||
		ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_dcs_ir_code_update; // IDAC码提交
	wire w_startup_done = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_startup_search_complete; // 启动搜索完成
	wire w_active_prec = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_active_precision_mode; // 实时提交精度
	wire w_result = o_measurement_result_valid && i_measurement_result_ready; // 正式结果握手
	wire w_run_or_stopping = (o_lifecycle_state == ST_RUN) || (o_lifecycle_state == ST_STOPPING); // 活性监视运行期
	// 例外C帧末条件（C08 V1.13 §4.2.1）：在途owner、无pending请求、NORMAL起帧资格不成立、AMI以电平保持校准请求。
	// 第4项在RTL中是"AMI的校准请求尚未被消费"：或者valid保持，或者已被调度器接受、仍在AMI在途（flag_calibration_request_inflight）；
	// 在途请求在作废时撤销、于帧末之后的空闲期重新握手，这正是合同所述"校准请求要等宏帧结束后的空闲期握手"（试跑实测间隔5131，与合同记载一致）
	wire w_excc_cond = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] &&
		!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_PENDING] &&
		!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_next_frame_inputs_eligible &&
		(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_calibration_sample_valid || ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight);

	//===================<V2：ADC行为模型>===================//
	reg [1:0] v2_done_mode;                  // DONE形态（+V2_ADC_DONE_MODE）
	reg v2_idle_mode;                        // idle公式（+V2_ADC_IDLE_MODE）
	reg [1:0] v2_idle_delay;                 // idle相对模型内部空闲的同步延迟（+V2_ADC_IDLE_DELAY）
	reg v2_adc_rst_aferst;                   // ADC_RST取CLK_AFERST_LOW上升沿（+V2_ADC_RST_AFERST）
	reg [7:0] v2_latency;                    // 当前事务时延，提交时按种子取值
	reg [9:0] v2_raw1;                       // 当前事务Stage1码，提交时计算
	reg [9:0] v2_raw2;                       // 当前事务Stage2码，提交时计算
	reg v2_fault_arm;                        // 故障武装单拍
	reg [2:0] v2_fault_mode;                 // 故障类型
	reg [1:0] v2_fault_slot;                 // 故障槽位，3表示任意槽位
	reg [15:0] v2_fault_serial;              // 故障首个序号
	reg [7:0] v2_fault_count;                // 故障连续笔数
	reg [2:0] v2_fault_frame_offset;         // 迟到/忙释放帧偏移
	reg [12:0] v2_fault_release_tick;        // 迟到/忙释放相位
	reg v2_aferst_prev;                      // CLK_AFERST_LOW上一拍
	wire w_model_conv_start;                 // 模型转换开始
	wire w_model_done_rise;                  // 模型完成上升
	wire w_model_fault_hit;                  // 模型故障命中
	wire [15:0] w_model_serial;              // 模型槽位序号
	wire [1:0] w_owner_slot = reg_owner_snapshot_is_calibration ? 2'd2 : (reg_owner_snapshot_color_ir ? 2'd1 : 2'd0); // 当前owner槽位
	wire [1:0] w_fault_slot_eff = (v2_fault_slot == 2'd3) ? w_owner_slot : v2_fault_slot; // 任意槽位时等于当前槽位
	always @(posedge i_clk) v2_aferst_prev <= o_clk_aferst_low;
	// slot=ANY：首次命中后锁定到命中的槽位，避免其它槽位的序号1再次命中
	always @(posedge i_clk) if(w_model_fault_hit && (v2_fault_slot == 2'd3)) v2_fault_slot = w_owner_slot;
	v2_adc_behavior_model
		v2_adc_behavior_model_Inst(
			.i_clk(i_clk),
			.i_rstn(i_rstn),
			.i_q1(o_clk_9q1_low || o_clk_15q1_low),
			.i_q3(o_clk_q3_low),
			.i_txn_start(w_commit),
			.i_adc_rst(v2_adc_rst_aferst && o_clk_aferst_low && !v2_aferst_prev),
			.i_owner_slot(w_owner_slot),
			.i_owner_precision(reg_owner_snapshot_is_calibration ? 1'b0 : reg_owner_snapshot_precision),
			.i_active_precision(w_active_prec),
			.i_frame_id(w_frame),
			.i_macro_tick(w_mtick),
			.i_done_mode(v2_done_mode),
			.i_idle_mode(v2_idle_mode),
			.i_idle_delay(v2_idle_delay),
			.i_latency(v2_latency),
			.i_raw_stage1(v2_raw1),
			.i_raw_stage2(v2_raw2),
			.i_fault_arm(v2_fault_arm),
			.i_fault_mode(v2_fault_mode),
			.i_fault_slot(w_fault_slot_eff),
			.i_fault_serial(v2_fault_serial),
			.i_fault_count(v2_fault_count),
			.i_fault_frame_offset(v2_fault_frame_offset),
			.i_fault_release_tick(v2_fault_release_tick),
			.o_dout_stage1(i_dout_stage1_low),
			.o_clk_stage1_dout(i_clk_stage1_dout_low_async),
			.o_dout_stage2(i_dout_stage2_low),
			.o_clk_stage2_dout(i_clk_stage2_dout_low_async),
			.o_adc_physical_idle(i_adc_physical_idle),
			.o_conv_start_event(w_model_conv_start),
			.o_done_rise_event(w_model_done_rise),
			.o_fault_hit_event(w_model_fault_hit),
			.o_slot_serial(w_model_serial)
		);

	// 每次owner提交时按种子取本事务时延与RAW值：NORMAL可选真实生理生成器，校准一律窗口内150
	integer v2_seed;                         // 时延随机种子（+V2_SEED），$random会改写它
	integer v2_seed_cfg;                     // 配置的初始种子，供结论行打印
	integer v2_lat_min;                      // 时延下限（+V2_LAT_MIN）
	integer v2_lat_max;                      // 时延上限（+V2_LAT_MAX）
	reg v2_gen;                              // NORMAL事务用生理生成器（模式GEN_DUAL/RECHECK）
	always @(posedge i_clk) begin : v2_txn_values
		reg [9:0] r_target;
		integer r_unclamped;
		integer r_span;
		if(w_commit) begin
			r_span = v2_lat_max - v2_lat_min + 1;
			v2_latency = v2_lat_min + (($random(v2_seed) & 32'h7fffffff) % ((r_span < 1) ? 1 : r_span));
			if(v2_gen && !w_commit_cal) begin
				task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, ppg_control_top_Inst.sched_adc_owner_color_ir_o, {16'd0, ppg_control_top_Inst.sched_adc_owner_frame_id_o}, r_target, r_unclamped);
				make_fixed_raw(r_target, v2_raw1);
			end else begin
				make_fixed_raw(150, v2_raw1);
			end
			v2_raw2 = v2_raw1;
		end
	end

	//===================<V2：常驻监视器>===================//
	integer v2_detail_max;                   // 每个监视器最多打印的明细条数（+V2_DETAIL）
	reg v2_expect_result;                    // 当前RUN应产生正式结果
	wire w_frame_break = w_stop_ack_s || w_abort_s || o_system_fault_blocking; // 帧被打断
	wire w_fault_record = w_ami_fv || w_ssw_fv || w_sched_fv || o_system_fault_blocking; // 故障记录或阻断保持
	wire w_progress = w_done || w_lost || w_result || w_idac_commit || (o_lifecycle_state != reg_v2_life_prev); // 活性进展
	always @(posedge i_clk) reg_v2_life_prev <= o_lifecycle_state;
	wire [31:0] mon_live_fail, mon_live_max, mon_live_noprog;
	wire mon_live_ev;
	v2_mon_liveness #(.C_LIMIT(15000)) v2_mon_liveness_Inst(
		.i_clk(i_clk), .i_rstn(i_rstn), .i_active(w_run_or_stopping), .i_progress(w_progress), .i_fault_record(w_fault_record),
		.o_fail_count(mon_live_fail), .o_max_noprog(mon_live_max), .o_stall_event(mon_live_ev), .o_noprog(mon_live_noprog));
	wire [31:0] mon_bind_q3, mon_bind_fail;
	wire mon_bind_ev;
	v2_mon_q3_bind v2_mon_q3_bind_Inst(
		.i_clk(i_clk), .i_rstn(i_rstn), .i_q3(o_clk_q3_low), .i_sched_inflight(w_sched_inflight), .i_commit(w_commit), .i_commit_cal(w_commit_cal),
		.i_frame(w_frame), .i_subframe(w_sf), .o_q3_count(mon_bind_q3), .o_violation_count(mon_bind_fail), .o_violation_event(mon_bind_ev));
	wire [31:0] mon_excl_done, mon_excl_lost, mon_excl_fail;
	wire mon_excl_ev;
	v2_mon_void_excl v2_mon_void_excl_Inst(
		.i_clk(i_clk), .i_rstn(i_rstn), .i_done(w_done), .i_lost(w_lost),
		.o_done_count(mon_excl_done), .o_lost_count(mon_excl_lost), .o_violation_count(mon_excl_fail), .o_violation_event(mon_excl_ev));
	wire [31:0] mon_fi_frames, mon_fi_first, mon_fi_excc, mon_fi_break, mon_fi_fail, mon_fi_interval;
	wire mon_fi_ev;
	wire [2:0] mon_fi_class;
	v2_mon_frame_interval v2_mon_frame_interval_Inst(
		.i_clk(i_clk), .i_rstn(i_rstn), .i_frame_active(w_normal_frame || w_cal_frame), .i_cal_active(w_cal_frame), .i_macro_tick(w_mtick),
		.i_start_ack(w_start_ack_s), .i_excc_cond(w_excc_cond), .i_frame_break(w_frame_break),
		.o_frame_count(mon_fi_frames), .o_first_count(mon_fi_first), .o_excc_count(mon_fi_excc), .o_break_count(mon_fi_break), .o_fail_count(mon_fi_fail),
		.o_gap_event(mon_fi_ev), .o_gap_class(mon_fi_class), .o_gap_interval(mon_fi_interval));
	wire [31:0] mon_rc_stop_n, mon_rc_stop_fail, mon_rc_stop_max, mon_rc_start_n, mon_rc_start_fail, mon_rc_start_max, mon_rc_res_n, mon_rc_res_fail, mon_rc_res_max;
	wire mon_rc_ev;
	v2_mon_recovery v2_mon_recovery_Inst(
		.i_clk(i_clk), .i_rstn(i_rstn), .i_stop_ack(w_stop_ack_s), .i_life_config(o_lifecycle_state == ST_CONFIG), .i_fault_record(w_fault_record),
		.i_start_ack(w_start_ack_s), .i_frame_start(w_frame_start_ev), .i_result(w_result), .i_expect_result(v2_expect_result),
		.o_stop_count(mon_rc_stop_n), .o_stop_fail(mon_rc_stop_fail), .o_stop_max(mon_rc_stop_max),
		.o_start_count(mon_rc_start_n), .o_start_fail(mon_rc_start_fail), .o_start_max(mon_rc_start_max),
		.o_result_count(mon_rc_res_n), .o_result_fail(mon_rc_res_fail), .o_result_max(mon_rc_res_max), .o_fail_event(mon_rc_ev));
	wire [31:0] mon_id_commits, mon_id_closed, mon_id_results, mon_id_discards, mon_id_fail, mon_id_excl;
	wire mon_id_ev;
	wire [3:0] mon_id_code;
	v2_mon_identity v2_mon_identity_Inst(
		.i_clk(i_clk), .i_rstn(i_rstn),
		.i_start_ack(w_start_ack_s),
		.i_commit(w_commit), .i_commit_frame(ppg_control_top_Inst.sched_adc_owner_frame_id_o), .i_commit_idx(ppg_control_top_Inst.sched_adc_owner_sample_index_o),
		.i_commit_color(ppg_control_top_Inst.sched_adc_owner_color_ir_o), .i_commit_type(ppg_control_top_Inst.sched_adc_owner_frame_type_o), .i_commit_prec(ppg_control_top_Inst.sched_adc_owner_precision_mode_o),
		.i_sched_inflight(w_sched_inflight),
		.i_ssw_inflight(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.o_adc_owner_inflight),
		.i_ssw_frame(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_frame_id), .i_ssw_idx(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_sample_index),
		.i_ssw_color(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_color_ir), .i_ssw_type(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_frame_type),
		.i_ssw_prec(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_precision_mode),
		.i_ami_inflight(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_adc_transaction_inflight),
		.i_ami_frame(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_frame_id), .i_ami_idx(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_sample_index),
		.i_ami_color(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_color_ir), .i_ami_type(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_frame_type),
		.i_ami_prec(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_precision_mode),
		.i_done(w_done), .i_done_success(w_done_success), .i_lost(w_lost), .i_close_idx(w_cidx),
		.i_result(w_result), .i_res_frame(o_result_frame_id), .i_res_idx(o_result_sample_index), .i_res_color(o_result_color_ir), .i_res_type(o_result_frame_type),
		.i_disc(o_measurement_result_discard_event && o_measurement_result_discard_identity_valid), .i_disc_frame(o_measurement_result_discard_frame_id),
		.i_disc_idx(o_measurement_result_discard_sample_index), .i_disc_color(o_measurement_result_discard_color_ir), .i_disc_type(o_measurement_result_discard_frame_type),
		.i_excl_window(v2_f3_window),
		.o_commit_count(mon_id_commits), .o_close_count(mon_id_closed), .o_result_count(mon_id_results), .o_discard_count(mon_id_discards),
		.o_fail_count(mon_id_fail), .o_excl_count(mon_id_excl), .o_fail_event(mon_id_ev), .o_fail_code(mon_id_code));

	// 监视器明细打印层：每个监视器至多v2_detail_max条
	integer n_det_live, n_det_bind, n_det_excl, n_det_fi, n_det_rc, n_det_id;
	always @(posedge i_clk) begin
		if(mon_live_ev && (n_det_live < v2_detail_max)) begin n_det_live = n_det_live + 1; $display("V2MON-DETAIL LIVENESS t=%0t frame=%0d tick=%0d life=%b noprog=%0d inflight=%b", $time, w_frame, w_mtick, o_lifecycle_state, mon_live_noprog, w_sched_inflight); end
		if(mon_bind_ev && (n_det_bind < v2_detail_max)) begin n_det_bind = n_det_bind + 1; $display("V2MON-DETAIL Q3BIND t=%0t frame=%0d tick=%0d sf=%0d inflight=%b", $time, w_frame, w_mtick, w_sf, w_sched_inflight); end
		if(mon_excl_ev && (n_det_excl < v2_detail_max)) begin n_det_excl = n_det_excl + 1; $display("V2MON-DETAIL VOIDEXCL t=%0t frame=%0d tick=%0d idx=%0d", $time, w_frame, w_mtick, w_cidx); end
		if(mon_fi_ev && (n_det_fi < v2_detail_max)) begin n_det_fi = n_det_fi + 1; $display("V2MON-DETAIL FRAMEGAP t=%0t frame=%0d interval=%0d class=%0s type=%0s", $time, w_frame, mon_fi_interval,
			(mon_fi_class == 3'd1) ? "FIRST" : (mon_fi_class == 3'd2) ? "EXC-C" : (mon_fi_class == 3'd3) ? "BREAK" : "FAIL", w_cal_frame ? "CAL" : "NORMAL"); end
		if(mon_rc_ev && (n_det_rc < v2_detail_max)) begin n_det_rc = n_det_rc + 1; $display("V2MON-DETAIL RECOVERY t=%0t frame=%0d tick=%0d life=%b stop_fail=%0d start_fail=%0d res_fail=%0d", $time, w_frame, w_mtick, o_lifecycle_state, mon_rc_stop_fail, mon_rc_start_fail, mon_rc_res_fail); end
		if(mon_id_ev && (n_det_id < v2_detail_max)) begin n_det_id = n_det_id + 1; $display("V2MON-DETAIL IDENTITY t=%0t frame=%0d tick=%0d code=%0d idx=%0d res_frame=%0d res_idx=%0d", $time, w_frame, w_mtick, mon_id_code, w_cidx, o_result_frame_id, o_result_sample_index); end
	end

	// 汇总打印：每个监视器一行V2MON，汇总脚本只按这些行判定
	task v2_report_monitors;
		begin
			$display("V2MON LIVENESS %0s %0d max_noprog=%0d limit=15000", (mon_live_fail == 0) ? "PASS" : "FAIL", mon_live_fail, mon_live_max);
			$display("V2MON IDENTITY %0s %0d commits=%0d closed=%0d results=%0d discards=%0d excl_f3=%0d", (mon_id_fail == 0) ? "PASS" : "FAIL", mon_id_fail, mon_id_commits, mon_id_closed, mon_id_results, mon_id_discards, mon_id_excl);
			$display("V2MON RECOVERY %0s %0d stop=%0d/%0d max=%0d start=%0d/%0d max=%0d result=%0d/%0d max=%0d", ((mon_rc_stop_fail + mon_rc_start_fail + mon_rc_res_fail) == 0) ? "PASS" : "FAIL",
				mon_rc_stop_fail + mon_rc_start_fail + mon_rc_res_fail, mon_rc_stop_fail, mon_rc_stop_n, mon_rc_stop_max, mon_rc_start_fail, mon_rc_start_n, mon_rc_start_max, mon_rc_res_fail, mon_rc_res_n, mon_rc_res_max);
			$display("V2MON FRAMEGAP %0s %0d frames=%0d first=%0d excc=%0d break=%0d", (mon_fi_fail == 0) ? ((mon_fi_excc != 0) ? "EXC" : "PASS") : "FAIL", mon_fi_fail, mon_fi_frames, mon_fi_first, mon_fi_excc, mon_fi_break);
			$display("V2MON Q3BIND %0s %0d q3=%0d", (mon_bind_fail == 0) ? "PASS" : "FAIL", mon_bind_fail, mon_bind_q3);
			$display("V2MON VOIDEXCL %0s %0d done=%0d lost=%0d", (mon_excl_fail == 0) ? "PASS" : "FAIL", mon_excl_fail, mon_excl_done, mon_excl_lost);
		end
	endtask

	//===================<V2：故障与事件记录>===================//
	reg [255:0] v2_cause_seen;               // 出现过的系统故障原因位图（supervisor首故障）
	reg [255:0] v2_local_cause_seen;         // 出现过的AMI本地故障原因位图
	integer v2_n_lost, v2_n_done, v2_n_result, v2_n_fault_ev, v2_n_q3_model;
	always @(posedge i_clk) begin
		if(o_system_fault_cause_valid) v2_cause_seen[o_system_fault_cause] = 1'b1;
		if(w_ami_fv) v2_local_cause_seen[ppg_control_top_Inst.ami_fault_cause_o] = 1'b1;
		if(w_lost) v2_n_lost = v2_n_lost + 1;
		if(w_done) v2_n_done = v2_n_done + 1;
		if(w_result) v2_n_result = v2_n_result + 1;
		if(w_model_conv_start) v2_n_q3_model = v2_n_q3_model + 1;
		if(w_ami_fv || w_ssw_fv || w_sched_fv) begin
			v2_n_fault_ev = v2_n_fault_ev + 1;
			if(v2_n_fault_ev <= v2_detail_max) $display("V2FAULT t=%0t frame=%0d tick=%0d sf=%0d lt=%0d ami=%b cause=%h ssw=%b sched=%b life=%b", $time, w_frame, w_mtick, w_sf, w_lt, w_ami_fv,
				ppg_control_top_Inst.ami_fault_cause_o, w_ssw_fv, w_sched_fv, o_lifecycle_state);
		end
		if(w_lost && (v2_n_lost <= v2_detail_max)) $display("V2LOST t=%0t frame=%0d tick=%0d sf=%0d lt=%0d idx=%0d", $time, w_frame, w_mtick, w_sf, w_lt, w_cidx);
	end

	// 已知问题签名（只打印V2SIG，由汇总脚本归类，不影响监视器结论）
	// KNOWN-FIX-7：本NORMAL帧内出现过STOP确认、abort或阻断故障，帧末仍发出o_normal_frame_complete_event
	// KNOWN-FIX-4：RUN中manager的stop_episode_active仍为1（STOPPING排空完成与重复STOP同拍后卡住）
	reg v2_frame_broken;                     // 本宏帧内出现过STOP确认、abort或阻断
	integer v2_n_sig7, v2_n_sig4;            // 两类签名次数
	initial begin v2_frame_broken = 1'b0; v2_n_sig7 = 0; v2_n_sig4 = 0; end
	always @(posedge i_clk) begin
		// 先用此前累积的打断状态检查完成事件（帧末完成事件可能与下一帧tick 0上的STOP同拍），再按本拍事件更新
		if(ppg_control_top_Inst.sched_normal_frame_complete_event_o && v2_frame_broken) begin
			v2_n_sig7 = v2_n_sig7 + 1;
			if(v2_n_sig7 <= 3) $display("V2SIG KNOWN-FIX-7 t=%0t frame=%0d tick=%0d life=%b normal frame complete after STOP/abort/fault", $time, w_frame, w_mtick, o_lifecycle_state);
		end
		if(w_frame_start_ev || ppg_control_top_Inst.sched_normal_frame_complete_event_o) v2_frame_broken = 1'b0;
		if(w_stop_ack_s || w_abort_s || o_system_fault_blocking) v2_frame_broken = 1'b1;
		if((o_lifecycle_state == ST_RUN) && ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.o_stop_episode_active) begin
			v2_n_sig4 = v2_n_sig4 + 1;
			if(v2_n_sig4 == 1) $display("V2SIG KNOWN-FIX-4 t=%0t frame=%0d tick=%0d stop_episode_active stuck in RUN", $time, w_frame, w_mtick);
		end
	end

	// 事务追踪（+V2_TRACE_FRAME=<n>）：帧号>=n时逐条打印起帧、提交、完成、作废、结果、IDAC提交、校准请求握手与故障
	integer v2_trace_frame;                  // 开始追踪的帧号，-1关闭
	initial if(!$value$plusargs("V2_TRACE_FRAME=%d", v2_trace_frame)) v2_trace_frame = -1;
	always @(posedge i_clk) if((v2_trace_frame >= 0) && (w_frame >= v2_trace_frame)) begin
		if(w_frame_start_ev) $display("V2TRACE t=%0t frame=%0d tick=%0d FRAME_START cal=%b", $time, w_frame, w_mtick, w_cal_frame);
		if(w_commit) $display("V2TRACE t=%0t frame=%0d tick=%0d sf=%0d lt=%0d COMMIT idx=%0d type=%0d color=%b prec=%b", $time, w_frame, w_mtick, w_sf, w_lt,
			ppg_control_top_Inst.sched_adc_owner_sample_index_o, ppg_control_top_Inst.sched_adc_owner_frame_type_o, ppg_control_top_Inst.sched_adc_owner_color_ir_o, ppg_control_top_Inst.sched_adc_owner_precision_mode_o);
		if(w_done) $display("V2TRACE t=%0t frame=%0d tick=%0d sf=%0d lt=%0d DONE idx=%0d success=%b", $time, w_frame, w_mtick, w_sf, w_lt, w_cidx, w_done_success);
		if(w_lost) $display("V2TRACE t=%0t frame=%0d tick=%0d sf=%0d lt=%0d LOST idx=%0d", $time, w_frame, w_mtick, w_sf, w_lt, w_cidx);
		if(w_result) $display("V2TRACE t=%0t frame=%0d tick=%0d RESULT frame=%0d idx=%0d color=%b", $time, w_frame, w_mtick, o_result_frame_id, o_result_sample_index, o_result_color_ir);
		if(w_idac_commit) $display("V2TRACE t=%0t frame=%0d tick=%0d IDAC_COMMIT", $time, w_frame, w_mtick);
		if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_calibration_sample_valid && ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_sample_ready)
			$display("V2TRACE t=%0t frame=%0d tick=%0d sf=%0d lt=%0d CALREQ_FIRE", $time, w_frame, w_mtick, w_sf, w_lt);
		if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_red_owner_deadline || ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_ir_owner_deadline ||
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_cal_owner_deadline)
			$display("V2TRACE t=%0t frame=%0d tick=%0d sf=%0d lt=%0d OWNER_DEADLINE red=%b ir=%b cal=%b idle=%b", $time, w_frame, w_mtick, w_sf, w_lt,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_red_owner_deadline, ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_ir_owner_deadline,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_cal_owner_deadline, i_adc_physical_idle);
		if(w_ami_fv || w_ssw_fv || w_sched_fv) $display("V2TRACE t=%0t frame=%0d tick=%0d FAULT ami=%b ssw=%b sched=%b", $time, w_frame, w_mtick, w_ami_fv, w_ssw_fv, w_sched_fv);
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_amb_recheck_accept) $display("V2TRACE t=%0t frame=%0d tick=%0d RECHECK_ACCEPT", $time, w_frame, w_mtick);
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.o_fine_window_start_event) $display("V2TRACE t=%0t frame=%0d tick=%0d PREC_TO_15", $time, w_frame, w_mtick);
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.o_precision_15_to_9_event) $display("V2TRACE t=%0t frame=%0d tick=%0d PREC_TO_9", $time, w_frame, w_mtick);
	end

	// 例外C条件逐项打印：每个校准宏帧末拍（tick 4999）一行，供帧间隔监视器的放行判定复核
	always @(posedge i_clk) if(w_cal_frame && (w_mtick == 13'd4999))
		$display("V2EXCC t=%0t frame=%0d inflight=%b req_pending=%b next_inputs_eligible=%b cal_sample_valid=%b cal_req_active=%b ami_cal_req_inflight=%b cond=%b", $time, w_frame,
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT],
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_PENDING],
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.flag_next_frame_inputs_eligible,
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_calibration_sample_valid,
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_ACTIVE],
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_inflight, w_excc_cond);

	// 原因位图打印成列表
	task v2_print_causes;
		input [255:0] map;
		input [8 * 8 - 1:0] tag;
		integer c;
		reg any;
		begin
			any = 1'b0;
			$write("V2CAUSES %0s", tag);
			for(c = 0; c < 256; c = c + 1) if(map[c]) begin $write(" %h", c[7:0]); any = 1'b1; end
			if(!any) $write(" none");
			$write("\n");
		end
	endtask

	//===================<V2：生命周期辅助任务>===================//
	task v2_wait_life;
		input [1:0] life;
		input integer limit;
		output ok;
		integer k;
		begin
			k = 0;
			while((o_lifecycle_state != life) && (k < limit)) begin @(posedge i_clk); k = k + 1; end
			ok = (o_lifecycle_state == life);
		end
	endtask

	task v2_diag_clear;
		begin
			@(negedge i_clk); i_diag_clear_event = 1'b1;
			@(posedge i_clk); #1 i_diag_clear_event = 1'b0;
			repeat(8) @(posedge i_clk);
		end
	endtask

	task v2_pulse_abort;
		begin
			@(negedge i_clk); i_control_abort_event = 1'b1;
			@(posedge i_clk); #1 i_control_abort_event = 1'b0;
		end
	endtask

	// 真实异步复位沿：拉低保持3拍后在下降沿释放
	task v2_reset_dut;
		begin
			@(negedge i_clk); i_rstn = 1'b0; i_source_rstn = 1'b0;
			repeat(3) @(posedge i_clk);
			@(negedge i_source_clk); i_source_rstn = 1'b1;
			@(negedge i_clk); i_rstn = 1'b1;
			repeat(3) @(posedge i_clk);
		end
	endtask

	// 按模式构造配置：0 DUAL9双光MANUAL SAR9；1 RED15表征RED_ONLY固定SAR15；2 SEARCH启动搜索；3 RECHECK周期重检生成器；4 GEN_DUAL双光MANUAL生理生成器
	task v2_build_config;
		input integer mode;
		begin
			if(mode == 0) task_build_normal_manual_dual_config;
			else if(mode == 1) begin
				task_build_normal_manual_config;
				i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION
				i_source_config_snapshot[13:12] = 2'b01; // optical_mode=OPTICAL_RED
				i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15
			end else if(mode == 2) sys_build_search_config;
			else if(mode == 3) task_build_recheck_generator_config;
			else task_build_normal_manual_dual_config;
		end
	endtask

	// 提交配置并START，返回是否进入RUN
	task v2_commit_start;
		input integer mode;
		output ok;
		reg life_ok;
		begin
			v2_build_config(mode);
			task_pulse_source_update;
			task_wait_config_result;
			ok = o_commit_ack_event && !o_error_event && o_start_ready;
			if(!ok) $display("V2INFO commit rejected ack=%b err=%b start_ready=%b code=%h life=%b blocking=%b", o_commit_ack_event, o_error_event, o_start_ready, o_last_error_code, o_lifecycle_state, o_system_fault_blocking);
			task_pulse_start;
			v2_wait_life(ST_RUN, 200, life_ok);
			ok = ok && life_ok;
		end
	endtask

	// 等到第frame帧的宏帧相位等于tick（以上升沿后的值为准），返回是否到达
	task v2_wait_frame_tick;
		input integer frame;
		input integer tick;
		input integer limit;
		output ok;
		integer k;
		begin
			k = 0;
			while(!((w_normal_frame || w_cal_frame) && (w_frame == frame[15:0]) && (w_mtick == tick[12:0])) && (k < limit)) begin @(posedge i_clk); #1; k = k + 1; end
			ok = (k < limit);
		end
	endtask

	//===================<全局看门狗>===================//
	integer v2_timeout_cycles;               // 单点仿真拍数上限（+V2_TIMEOUT_CYCLES）
	reg flag_global_timeout;                 // 单点超时标志
	initial begin
		flag_global_timeout = 1'b0;
		if(!$value$plusargs("V2_TIMEOUT_CYCLES=%d", v2_timeout_cycles)) v2_timeout_cycles = 400000;
		#1;
		repeat(v2_timeout_cycles) @(posedge i_clk);
		flag_global_timeout = 1'b1;
		$display("V2TIMEOUT t=%0t frame=%0d tick=%0d life=%b blocking=%b cause=%h", $time, w_frame, w_mtick, o_lifecycle_state, o_system_fault_blocking, o_system_fault_cause);
		v2_finish_point("TIMEOUT");
	end

	//===================<V2：扫描点参数>===================//
	reg [8 * 16 - 1:0] v2_mode_str;          // 工作模式名（+V2_MODE）
	reg [8 * 16 - 1:0] v2_event_str;         // 事件名（+V2_EVENT）
	reg [8 * 8 - 1:0] v2_slot_str;           // ADC故障槽位名（+V2_SLOT）
	reg [8 * 64 - 1:0] v2_point_str;         // 扫描点标识（+V2_POINT）
	integer v2_mode;                         // 工作模式编码
	integer v2_target_frame;                 // 目标宏帧号（+V2_FRAME）
	integer v2_target_tick;                  // 目标宏帧相位（+V2_TICK，或由+V2_SF/+V2_LT换算）
	integer v2_target_sf;                    // 目标校准子帧（+V2_SF，-1表示按宏帧tick）
	integer v2_target_lt;                    // 目标校准local tick（+V2_LT）
	integer v2_param;                        // 事件参数（+V2_PARAM，START延迟的d等）
	integer v2_post_frames;                  // 恢复后至少再跑的宏帧数（+V2_POST）
	integer v2_ev_frame, v2_ev_tick, v2_ev_sf, v2_ev_lt; // 事件实际落点
	reg v2_ev_landed;                        // 事件已记录落点
	reg v2_ev_active;                        // 落点那一拍是否有NORMAL或校准宏帧处于活动
	reg v2_landing_ok;                       // 实际落点与目标一致
	reg [8 * 16 - 1:0] v2_landing_rule;      // 落点核对口径
	integer v2_restarts;                     // 恢复过程中START次数
	reg v2_restart_ok;                       // 恢复START被接受
	integer v2_t_start_sim;                  // 本点开始的拍号
	integer v2_cycle;                        // TB拍号
	always @(posedge i_clk) v2_cycle = v2_cycle + 1;

	// 事件落点记录：按事件类型取DUT真正看到事件的那一拍
	reg v2_watch_stop, v2_watch_abort, v2_watch_hit, v2_watch_rise, v2_watch_idle, v2_watch_diag, v2_watch_commit;
	reg v2_idle_prev;
	always @(posedge i_clk) begin
		v2_idle_prev <= i_adc_physical_idle;
		if(!v2_ev_landed) begin
			if((v2_watch_stop && w_stop_ack_s) || (v2_watch_abort && w_abort_s) || (v2_watch_hit && w_model_fault_hit) ||
				(v2_watch_rise && w_model_done_rise && (v2_adc_behavior_model_Inst.reg_fault == 3'd2)) || (v2_watch_idle && (v2_adc_behavior_model_Inst.state_current == 3'd5) && (v2_adc_behavior_model_Inst.state_next == 3'd0)) ||
				(v2_watch_diag && ppg_control_top_Inst.i_diag_clear_event) || (v2_watch_commit && ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.i_config_update_event)) begin
				v2_ev_landed = 1'b1;
				v2_ev_frame = w_frame;
				v2_ev_tick = w_mtick;
				v2_ev_sf = w_sf;
				v2_ev_lt = w_lt;
				v2_ev_active = w_normal_frame || w_cal_frame;
				$display("V2LAND t=%0t frame=%0d tick=%0d sf=%0d lt=%0d normal=%b cal=%b inflight=%b", $time, w_frame, w_mtick, w_sf, w_lt, w_normal_frame, w_cal_frame, w_sched_inflight);
			end
		end
	end

	// 结束本点：打印监视器汇总与点结论后退出
	task v2_finish_point;
		input [8 * 16 - 1:0] how;
		integer nfail;
		begin
			repeat(2) @(posedge i_clk);
			v2_report_monitors;
			v2_print_causes(v2_cause_seen, "SYSTEM");
			v2_print_causes(v2_local_cause_seen, "AMI");
			$display("V2STICKY sched_launch=%b sched_deadline=%b sched_mismatch=%b sched_proto=%b ami_proto=%b ssw_switch=%b ssw_mismatch=%b ssw_deadline=%b ssw_cal_timeout=%b owner_lost=%b adc_idle=%b clk_dout1=%b clk_dout2=%b",
				o_scheduler_launch_timeout_sticky, o_scheduler_owner_deadline_timeout_sticky, o_scheduler_completion_mismatch_sticky, o_scheduler_protocol_error_sticky,
				o_ami_integration_protocol_error_sticky, o_ssw_switch_protocol_error_sticky, o_ssw_transaction_mismatch_sticky, o_ssw_owner_deadline_timeout_sticky,
				o_ssw_calibration_timeout_sticky, ppg_control_top_Inst.o_ami_owner_lost_sticky, i_adc_physical_idle, i_clk_stage1_dout_low_async, i_clk_stage2_dout_low_async);
			nfail = mon_live_fail + mon_id_fail + mon_rc_stop_fail + mon_rc_start_fail + mon_rc_res_fail + mon_fi_fail + mon_bind_fail + mon_excl_fail;
			$display("V2POINT point=%0s mode=%0s event=%0s slot=%0s frame=%0d tick=%0d sf=%0d lt=%0d param=%0d done_mode=%0d idle_mode=%0d idle_delay=%0d lat=%0d..%0d seed=%0d landed=%b land_active=%b land_frame=%0d land_tick=%0d land_sf=%0d land_lt=%0d landing_ok=%b rule=%0s end=%0s life=%b blocking=%b restarts=%0d restart_ok=%b lost=%0d done=%0d results=%0d q3=%0d cycles=%0d mon_fail=%0d",
				v2_point_str, v2_mode_str, v2_event_str, v2_slot_str, v2_target_frame, v2_target_tick, v2_target_sf, v2_target_lt, v2_param, v2_done_mode, v2_idle_mode, v2_idle_delay, v2_lat_min, v2_lat_max, v2_seed_cfg,
				v2_ev_landed, v2_ev_active, v2_ev_frame, v2_ev_tick, v2_ev_sf, v2_ev_lt, v2_landing_ok, v2_landing_rule, how, o_lifecycle_state, o_system_fault_blocking, v2_restarts, v2_restart_ok,
				v2_n_lost, v2_n_done, v2_n_result, v2_n_q3_model, v2_cycle - v2_t_start_sim, nfail);
			$display("V2_POINT_END");
			$finish;
		end
	endtask

	// 在目标拍之前lead拍到达时返回（跨帧时取上一帧末尾），用于STOP、abort等有固定传播延迟的事件
	task v2_wait_before_target;
		input integer lead;
		output ok;
		integer pre_frame;
		integer pre_tick;
		begin
			pre_tick = v2_target_tick - lead;
			pre_frame = v2_target_frame;
			if(pre_tick < 0) begin pre_tick = pre_tick + 5000; pre_frame = pre_frame - 1; end
			// 目标在START后首帧的前lead拍之内（pre_frame<0）时无法提前等待：立即发出，落点如实记录并由落点核对标出
			if(pre_frame < 0) ok = 1'b1;
			else v2_wait_frame_tick(pre_frame, pre_tick, (pre_frame + 3) * 5000 + 100000, ok);
		end
	endtask

	// 武装ADC行为模型故障
	task v2_arm_fault;
		input [2:0] mode;
		input [1:0] slot;
		input [15:0] serial;
		input [7:0] count;
		input [2:0] frame_offset;
		input [12:0] release_tick;
		begin
			v2_fault_mode = mode;
			v2_fault_slot = slot;
			v2_fault_serial = serial;
			v2_fault_count = count;
			v2_fault_frame_offset = frame_offset;
			v2_fault_release_tick = release_tick;
			@(negedge i_clk); v2_fault_arm = 1'b1;
			@(negedge i_clk); v2_fault_arm = 1'b0;
		end
	endtask

	// 生命周期离开RUN后的恢复：等CONFIG→等d拍→诊断清除→COMMIT→START
	task v2_recover;
		input integer delay;
		reg ok;
		begin
			v2_wait_life(ST_CONFIG, 60000, ok);
			if(!ok) begin
				$display("V2INFO recover: lifecycle did not return to CONFIG life=%b blocking=%b cause=%h", o_lifecycle_state, o_system_fault_blocking, o_system_fault_cause);
			end else begin
				repeat(delay) @(posedge i_clk);
				v2_diag_clear;
				v2_commit_start(v2_mode, ok);
				v2_restarts = v2_restarts + 1;
				v2_restart_ok = ok;
				if(!ok) $display("V2INFO recover: restart rejected life=%b blocking=%b code=%h", o_lifecycle_state, o_system_fault_blocking, o_last_error_code);
			end
		end
	endtask

	// 等待k个宏帧起点（含校准滚动），或生命周期不在RUN且不会恢复时提前返回
	task v2_run_frames;
		input integer k;
		input integer limit;
		integer n;
		integer c;
		begin
			n = 0; c = 0;
			while((n < k) && (c < limit)) begin
				@(posedge i_clk); #1; c = c + 1;
				if((w_normal_frame || w_cal_frame) && (w_mtick == 13'd0)) n = n + 1;
			end
		end
	endtask

	//===================<V2：主序列>===================//
	initial begin : main_sequence
		reg ok;
		reg [8 * 16 - 1:0] ev;
		integer slot_code;
		integer q3_tick;
		integer stop_delay;
		cnt_error = 0;
		v2_cycle = 0;
		n_det_live = 0; n_det_bind = 0; n_det_excl = 0; n_det_fi = 0; n_det_rc = 0; n_det_id = 0;
		v2_cause_seen = 256'd0; v2_local_cause_seen = 256'd0;
		v2_n_lost = 0; v2_n_done = 0; v2_n_result = 0; v2_n_fault_ev = 0; v2_n_q3_model = 0;
		v2_ev_landed = 1'b0; v2_ev_active = 1'b0; v2_landing_ok = 1'b0; v2_landing_rule = "none";
		v2_ev_frame = -1; v2_ev_tick = -1; v2_ev_sf = -1; v2_ev_lt = -1;
		v2_restarts = 0; v2_restart_ok = 1'b0;
		v2_watch_stop = 1'b0; v2_watch_abort = 1'b0; v2_watch_hit = 1'b0; v2_watch_rise = 1'b0; v2_watch_idle = 1'b0; v2_watch_diag = 1'b0; v2_watch_commit = 1'b0;
		v2_f3_window = 1'b0;
		v2_fault_arm = 1'b0; v2_fault_mode = 3'd0; v2_fault_slot = 2'd0; v2_fault_serial = 16'd1; v2_fault_count = 8'd1; v2_fault_frame_offset = 3'd0; v2_fault_release_tick = 13'd0;
		v2_latency = 8'd10; v2_raw1 = 10'd0; v2_raw2 = 10'd0;
		// 参数读取
		if(!$value$plusargs("V2_POINT=%s", v2_point_str)) v2_point_str = "adhoc";
		if(!$value$plusargs("V2_MODE=%s", v2_mode_str)) v2_mode_str = "DUAL9";
		if(!$value$plusargs("V2_EVENT=%s", v2_event_str)) v2_event_str = "NONE";
		if(!$value$plusargs("V2_SLOT=%s", v2_slot_str)) v2_slot_str = "ANY";
		if(!$value$plusargs("V2_FRAME=%d", v2_target_frame)) v2_target_frame = 3;
		if(!$value$plusargs("V2_SF=%d", v2_target_sf)) v2_target_sf = -1;
		if(!$value$plusargs("V2_LT=%d", v2_target_lt)) v2_target_lt = 0;
		if(!$value$plusargs("V2_TICK=%d", v2_target_tick)) v2_target_tick = 300;
		if(v2_target_sf >= 0) v2_target_tick = 625 * v2_target_sf + v2_target_lt;
		if(!$value$plusargs("V2_PARAM=%d", v2_param)) v2_param = 20;
		if(!$value$plusargs("V2_POST=%d", v2_post_frames)) v2_post_frames = 3;
		if(!$value$plusargs("V2_DETAIL=%d", v2_detail_max)) v2_detail_max = 8;
		if(!$value$plusargs("V2_SEED=%d", v2_seed)) v2_seed = 1;
		v2_seed_cfg = v2_seed;
		if(!$value$plusargs("V2_LAT_MIN=%d", v2_lat_min)) v2_lat_min = 2;
		if(!$value$plusargs("V2_LAT_MAX=%d", v2_lat_max)) v2_lat_max = 20;
		begin : rd_adc
			integer t;
			if($value$plusargs("V2_ADC_DONE_MODE=%d", t)) v2_done_mode = t; else v2_done_mode = 2'd0;
			if($value$plusargs("V2_ADC_IDLE_MODE=%d", t)) v2_idle_mode = t; else v2_idle_mode = 1'b0;
			if($value$plusargs("V2_ADC_IDLE_DELAY=%d", t)) v2_idle_delay = t; else v2_idle_delay = 2'd0;
			v2_adc_rst_aferst = $test$plusargs("V2_ADC_RST_AFERST");
		end
		v2_mode = (v2_mode_str == "DUAL9") ? 0 : (v2_mode_str == "RED15") ? 1 : (v2_mode_str == "SEARCH") ? 2 : (v2_mode_str == "RECHECK") ? 3 : (v2_mode_str == "GEN_DUAL") ? 4 : -1;
		if(v2_mode < 0) begin $display("V2ERROR unknown mode %0s", v2_mode_str); $finish; end
		v2_gen = (v2_mode == 3) || (v2_mode == 4);
		v2_expect_result = (v2_mode == 0) || (v2_mode == 1) || (v2_mode == 4);
		slot_code = (v2_slot_str == "RED") ? 0 : (v2_slot_str == "IR") ? 1 : (v2_slot_str == "CAL") ? 2 : 3;
		ev = v2_event_str;
		$display("V2START point=%0s mode=%0s event=%0s slot=%0s frame=%0d tick=%0d sf=%0d lt=%0d param=%0d done_mode=%0d idle_mode=%0d aferst_rst=%b lat=%0d..%0d seed=%0d",
			v2_point_str, v2_mode_str, v2_event_str, v2_slot_str, v2_target_frame, v2_target_tick, v2_target_sf, v2_target_lt, v2_param, v2_done_mode, v2_idle_mode, v2_adc_rst_aferst, v2_lat_min, v2_lat_max, v2_seed);

		// 复位与初值
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
		i_analog_ready = 1'b1;
		i_measurement_result_ready = 1'b1;
		i_test_inject_enable = 1'b0;
		i_test_identity_inject_valid = 1'b0;
		i_test_identity_inject_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
		i_test_invalid_sample_valid = 1'b0;
		repeat(2) @(posedge i_clk);
		i_rstn = 1'b1; i_source_rstn = 1'b1;
		v2_reset_dut;
		v2_t_start_sim = v2_cycle;

		// 配置并START
		v2_commit_start(v2_mode, ok);
		if(!ok) begin $display("V2ERROR initial START not accepted"); v2_finish_point("START_FAIL"); end

		// 注入事件
		if(ev == "NONE") begin
			v2_landing_rule = "none";
			v2_wait_frame_tick(v2_target_frame, v2_target_tick, (v2_target_frame + 3) * 5000 + 100000, ok);
		end else if((ev == "STOP") || (ev == "START_DELAY")) begin
			// 本TB的等待口径下（v2_wait_frame_tick在上升沿后判定、task_pulse_stop在下一下降沿拉高），STOP到调度器i_stop_ack_event实测2拍，故提前2拍发出
			v2_landing_rule = "exact";
			v2_watch_stop = 1'b1;
			v2_wait_before_target(2, ok);
			task_pulse_stop;
		end else if(ev == "ABORT") begin
			// 外部abort经control_top一级注册后进入调度器，提前1拍发出
			v2_landing_rule = "exact";
			v2_watch_abort = 1'b1;
			v2_wait_before_target(1, ok);
			v2_pulse_abort;
		end else if(ev == "DIAG_CLEAR") begin
			v2_landing_rule = "exact";
			v2_watch_diag = 1'b1;
			v2_wait_before_target(0, ok);
			v2_diag_clear;
		end else if(ev == "COMMIT") begin
			// source域配置更新经CDC到达manager的i_config_update_event实测3拍，故提前3拍发出；RUN中的提交按合同被拒绝
			v2_landing_rule = "exact";
			v2_watch_commit = 1'b1;
			v2_wait_before_target(3, ok);
			v2_build_config(v2_mode);
			task_pulse_source_update;
		end else if((ev == "LOST") || (ev == "FOREVER")) begin
			// 目标拍之后开始的第一笔转换（slot=ANY）或该槽位的下一笔转换被注入故障；落点为该转换的Q3上升沿
			v2_landing_rule = "next_conv";
			v2_watch_hit = 1'b1;
			v2_wait_before_target(1, ok);
			v2_arm_fault((ev == "LOST") ? 3'd1 : 3'd4, slot_code[1:0], 16'd1, (v2_param == 255) ? 8'd255 : 8'd1, 3'd0, 13'd0);
		end else if((ev == "LATE") || (ev == "BUSY")) begin
			// 第target_frame帧中该槽位的那笔转换：完成（LATE）或忙释放（BUSY）推迟到目标拍；目标拍早于该槽位Q3时落在下一帧
			v2_landing_rule = "exact";
			if(ev == "LATE") v2_watch_rise = 1'b1; else v2_watch_idle = 1'b1;
			q3_tick = (slot_code == 1) ? 460 : (slot_code == 2) ? -1 : 300;
			if(slot_code == 2) q3_tick = 625 * ((v2_target_sf >= 0) ? v2_target_sf : 0) + 266;
			v2_wait_frame_tick(v2_target_frame, 1, (v2_target_frame + 3) * 5000 + 100000, ok);
			v2_arm_fault((ev == "LATE") ? 3'd2 : 3'd3, (slot_code == 3) ? 2'd0 : slot_code[1:0], 16'd1, 8'd1,
				(v2_target_tick > q3_tick) ? 3'd0 : 3'd1, v2_target_tick[12:0]);
		end else if(ev == "PREC_IR_LOST") begin
			// F-1（必须覆盖场景1）：生理生成器驱动真实检测链，精度控制器接受切换请求（o_switch_pending上升）后，丢掉下一笔IR完成
			v2_landing_rule = "observe";
			v2_watch_hit = 1'b1;
			begin : wait_switch
				integer k;
				k = 0;
				while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.o_switch_pending && (k < 5800000)) begin @(posedge i_clk); k = k + 1; end
				ok = (k < 5800000);
				$display("V2INFO PREC_IR_LOST switch_pending=%b after %0d cycles frame=%0d tick=%0d target=%b", ok, k, w_frame, w_mtick,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.o_switch_target_precision);
			end
			v2_target_frame = w_frame; v2_target_tick = w_mtick;
			v2_arm_fault(3'd1, 2'd1, 16'd1, 8'd1, 3'd0, 13'd0);
		end else if(ev == "RECHECK_CAL_BUSY") begin
			// 必须覆盖场景2：周期重检接管后，第一笔重检校准转换不发DONE且ADC保持忙，越过校准帧帧尾，到下一宏帧tick 2000才回空闲
			v2_landing_rule = "observe";
			v2_watch_idle = 1'b1;
			begin : wait_recheck
				integer k;
				k = 0;
				while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_amb_recheck_accept && (k < 7800000)) begin @(posedge i_clk); k = k + 1; end
				ok = (k < 7800000);
				$display("V2INFO RECHECK_CAL_BUSY recheck_accept=%b after %0d cycles frame=%0d tick=%0d", ok, k, w_frame, w_mtick);
			end
			v2_target_frame = w_frame; v2_target_tick = 2000;
			v2_arm_fault(3'd3, 2'd2, 16'd1, 8'd1, 3'd1, 13'd2000);
		end else begin
			$display("V2ERROR unsupported event %0s", v2_event_str);
			v2_finish_point("BAD_EVENT");
		end
		if(!ok) begin $display("V2ERROR target frame/tick never reached"); v2_finish_point("NO_TARGET"); end

		// 等事件落点（最多两个宏帧）
		begin : wait_land
			integer k;
			k = 0;
			while(!v2_ev_landed && (v2_landing_rule != "none") && (k < 12000)) begin @(posedge i_clk); k = k + 1; end
		end
		if(v2_landing_rule == "exact") v2_landing_ok = v2_ev_landed && v2_ev_active && ((v2_ev_frame * 5000 + v2_ev_tick) ==
			((v2_target_frame + (((v2_watch_rise || v2_watch_idle) && (v2_fault_frame_offset != 0)) ? 1 : 0)) * 5000 + v2_target_tick + ((v2_watch_rise && (v2_done_mode == 2'd0)) ? 1 : 0))); // 按绝对拍比较；兼容脉冲在触发后一拍上升（与原响应进程一致）
		else if(v2_landing_rule == "next_conv") v2_landing_ok = v2_ev_landed && (v2_ev_frame == v2_target_frame) && (v2_ev_tick >= v2_target_tick);
		else v2_landing_ok = v2_ev_landed || (v2_landing_rule == "none");

		// 恢复：STOP/abort/故障使生命周期离开RUN时，回CONFIG后等d拍重启
		stop_delay = (ev == "START_DELAY") ? v2_param : 20;
		repeat(10) @(posedge i_clk);
		if(o_lifecycle_state != ST_RUN) begin
			v2_recover(stop_delay);
		end else begin
			// 仍在RUN：等可能的作废、迟到完成或长期忙升级（T-lost 4500，长期忙9000）落定
			v2_run_frames(2, 12000);
			if(o_lifecycle_state != ST_RUN) v2_recover(stop_delay);
		end
		// 恢复后至少再跑v2_post_frames帧
		v2_run_frames(v2_post_frames, (v2_post_frames + 2) * 5000 + 20000);
		v2_finish_point("DONE");
	end

endmodule
