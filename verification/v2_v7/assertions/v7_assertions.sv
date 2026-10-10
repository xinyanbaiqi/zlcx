`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V7 First-Batch Protocol Assertions bound into ppg_control_top
// Module Name:     v7_bind_control_top (+ bind statement)
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.4, properties 1-9
// Simulations:     verification/v2_v7/tb/tb_v2_sweep.v (xelab elaborates the bind); any TB that instantiates ppg_control_top
//
// Referrences:     PRE_TAPEOUT_CLOSURE_PLAN_20261009.md V7; p0-closure V1_CONFLICT_*.md (assertion suggestions, property 9)
//
// Dependencies:    v7_checkers.sv; the RTL is not modified (bind + read-only upward hierarchical references)
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. `bind ppg_control_top` attaches v7_bind_control_top to every instance of the module, so the same file can later be added to all system TBs without editing them. Inside, signals of the scheduler, SSW, AMI (with its capture, S1 redundancy corrector, IDAC controller, precision window controller and recheck scheduler), the manager and the supervisor are read through upward hierarchical names relative to the bound ppg_control_top instance. Property list and names: see the V7 table in verification_reports/V2_V7_FRAMEWORK_TRIAL_20261010.md.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        绑定到ppg_control_top的V7首批协议断言
// 模块名称:        v7_bind_control_top（含bind语句）
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.4节，性质1~9
// 仿真工程:        verification/v2_v7/tb/tb_v2_sweep.v（由xelab展开bind）；任何例化ppg_control_top的TB
//
// 参考资料:        PRE_TAPEOUT_CLOSURE_PLAN_20261009.md V7；p0-closure分支V1_CONFLICT_*.md中的断言建议（性质9）
//
// 依赖文件:        v7_checkers.sv；不修改RTL（bind加只读的向上层次引用）
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。`bind ppg_control_top`把v7_bind_control_top挂到该模块的每个实例上，因此以后加进全部系统TB时无需改动这些TB。模块内通过相对于被绑定ppg_control_top实例的向上层次名，只读访问调度器、SSW、AMI（含捕获、S1冗余校正器、IDAC控制器、精度窗口控制器、重检调度器）、manager与supervisor的信号。性质清单与名称见verification_reports/V2_V7_FRAMEWORK_TRIAL_20261010.md的V7表。

module v7_bind_control_top
(
	input logic i_clk,                      // ppg_control_top的2 MHz时钟
	input logic i_rstn,                     // ppg_control_top的低有效复位
	// ppg_control_top作用域内的简单名信号经bind端口传入（简单名不做向上查找，带点的层次名才会）
	input logic i_commit,                   // sched_adc_owner_commit_event_o
	input logic i_done,                     // ami_adc_transaction_complete_event_o
	input logic i_lost,                     // ami_adc_transaction_lost_event_o
	input logic [1:0] i_life,               // o_lifecycle_state
	input logic i_result,                   // o_measurement_result_valid && i_measurement_result_ready
	input logic i_fault                     // ami/sched/ssw fault_valid或o_system_fault_blocking
);
	//---------------观测网（向上层次引用，只读）---------------//
	wire w_commit = i_commit;                                          // owner提交
	wire w_done = i_done;                                      // AMI完成
	wire w_lost = i_lost;                                          // AMI作废
	wire w_close = w_done || w_lost;                                                         // owner关闭
	wire w_sched_inflight = ppg_400hz_frame_calibration_scheduler_Inst.o_transaction_inflight; // 调度器在途
	wire w_ssw_inflight = ppg_sar9_sar15_safe_selection_wrapper_Inst.o_adc_owner_inflight;    // SSW在途
	wire w_ami_inflight = ppg_adc_measurement_idac_integration_Inst.flag_adc_transaction_inflight; // AMI在途
	wire [36:0] w_ssw_key = {ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_frame_id, ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_sample_index,
		ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_color_ir, ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_frame_type,
		ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_precision_mode};                 // SSW记录的owner身份
	wire [36:0] w_ami_key = {ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_frame_id, ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_sample_index,
		ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_color_ir, ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_frame_type,
		ppg_adc_measurement_idac_integration_Inst.reg_adc_inflight_precision_mode};           // AMI记录的owner身份
	logic r_commit_d1;                                                                      // 上一拍提交
	always @(posedge i_clk or negedge i_rstn) if(!i_rstn) r_commit_d1 <= 1'b0; else r_commit_d1 <= w_commit;
	wire w_stable = !w_commit && !r_commit_d1 && !w_close;                                   // 非提交/关闭过渡拍
	// AMI故障lane 01/02/03/06/07（L-5、性质6）
	wire w_lanes = ppg_adc_measurement_idac_integration_Inst.flag_test_identity_hold || ppg_adc_measurement_idac_integration_Inst.flag_owner_protocol_fault_hold ||
		ppg_adc_measurement_idac_integration_Inst.flag_recovery_context_fault_hold || ppg_adc_measurement_idac_integration_Inst.flag_owner_lost_fault_hold ||
		ppg_adc_measurement_idac_integration_Inst.flag_adc_busy_fault_hold;
	wire w_ami_start = ppg_adc_measurement_idac_integration_Inst.i_start_ack_event;         // AMI看到的START
	wire w_ami_abort = ppg_adc_measurement_idac_integration_Inst.i_control_abort_event;     // AMI看到的abort合并事件
	wire w_life_run = (i_life == 2'b10) || (i_life == 2'b11);         // RUN或STOPPING
	logic [1:0] r_life_prev;                                                                // 生命周期前值
	always @(posedge i_clk) r_life_prev <= i_life;
	wire w_progress = w_done || w_lost || i_result ||
		ppg_adc_measurement_idac_integration_Inst.o_amb_code_update || ppg_adc_measurement_idac_integration_Inst.o_dcs_r_code_update ||
		ppg_adc_measurement_idac_integration_Inst.o_dcs_ir_code_update || (i_life != r_life_prev); // 活性进展
	wire w_fault = i_fault; // 故障记录或阻断
	logic [2:0] r_mgr_state_prev;                                                           // manager上一拍状态
	always @(posedge i_clk) r_mgr_state_prev <= ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.state_current;

	//---------------性质1：owner唯一与三方一致---------------//
	v7_chk_imp #(.C_NAME("P1a_OWNER_UNIQUE_COMMIT")) u_p1a(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(w_commit), .i_b(!w_sched_inflight || w_close));
	v7_chk_imp #(.C_NAME("P1b_INFLIGHT_THREE_WAY")) u_p1b(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(w_stable),
		.i_b((w_sched_inflight == w_ssw_inflight) && (w_ssw_inflight == w_ami_inflight)));
	v7_chk_imp #(.C_NAME("P1c_OWNER_IDENTITY_SSW_AMI")) u_p1c(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(w_ssw_inflight && w_ami_inflight && !w_commit),
		.i_b(w_ssw_key == w_ami_key));
	//---------------性质2：作废与完成互斥---------------//
	v7_chk_mutex #(.C_NAME("P2_VOID_COMPLETE_MUTEX")) u_p2(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(w_done), .i_b(w_lost));
	//---------------性质3：冗余校正器不变量---------------//
	v7_chk_imp #(.C_NAME("P3_RC_CAPTURE_HAS_CONTEXT")) u_p3(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a(ppg_adc_measurement_idac_integration_Inst.ppg_adc_async_stage_capture_Inst.flag_capture_pending || ppg_adc_measurement_idac_integration_Inst.ppg_adc_s1_redundancy_corrector_Inst.i_capture_valid),
		.i_b(ppg_adc_measurement_idac_integration_Inst.ppg_adc_s1_redundancy_corrector_Inst.flag_context_valid || ppg_adc_measurement_idac_integration_Inst.ppg_adc_s1_redundancy_corrector_Inst.flag_capture_drop_armed));
	//---------------性质4：START后可恢复（L-6）---------------//
	v7_chk_imp_next #(.C_NAME("P4_START_NO_RESIDUAL_CONTEXT")) u_p4(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(ppg_sar9_sar15_safe_selection_wrapper_Inst.i_start_ack_event),
		.i_b(!ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_red_context_valid && !ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_ir_context_valid && !ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_cal_context_valid));
	//---------------性质5：L-5清零在系统级不起作用---------------//
	v7_chk_imp #(.C_NAME("P5_L5_CLEAR_NEVER_EFFECTIVE")) u_p5(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a(ppg_adc_measurement_idac_integration_Inst.flag_run_context_drained && !w_ami_start && !w_ami_abort), .i_b(!w_lanes));
	//---------------性质6：故障lane在START或abort后一拍落下---------------//
	v7_chk_imp_next #(.C_NAME("P6_LANES_FALL_AFTER_START_ABORT")) u_p6(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(w_ami_start || w_ami_abort), .i_b(!w_lanes));
	//---------------性质7：有界活性---------------//
	v7_chk_live #(.C_NAME("P7_BOUNDED_LIVENESS"), .C_LIMIT(15000)) u_p7(.i_clk(i_clk), .i_rstn(i_rstn), .i_active(w_life_run), .i_progress(w_progress), .i_fault(w_fault));
	//---------------性质8：IDAC控制器IDLE时无挂起valid---------------//
	v7_chk_imp #(.C_NAME("P8_IDAC_IDLE_NO_PENDING")) u_p8(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a(ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == 5'd0),
		.i_b(!ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_pending_valid && !ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid &&
			!ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_pending_valid && !ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request &&
			!ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request));
	//---------------性质9：V1冲突报告建议的断言---------------//
	// V1_CONFLICT_MGR：stop_ack的上一拍状态必为RUN或STOPPING；CONFIG/READY时stop_episode_active为0（MGR-C1护栏）
	v7_chk_imp #(.C_NAME("P9a_MGR_STOP_ACK_FROM_RUN")) u_p9a(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.o_stop_ack_event),
		.i_b((r_mgr_state_prev == 3'b010) || (r_mgr_state_prev == 3'b011)));
	v7_chk_imp #(.C_NAME("P9b_MGR_IDLE_NO_STOP_EPISODE")) u_p9b(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a((ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.state_current == 3'b000) || (ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.state_current == 3'b001)),
		.i_b(!ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.o_stop_episode_active));
	// V1_CONFLICT_IDAC：AMB重检期间无DCS pending
	v7_chk_imp #(.C_NAME("P9c_IDAC_RECHECK_NO_DCS_PENDING")) u_p9c(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a(ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == 5'd9),
		.i_b(!ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid && !ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_pending_valid));
	// V1_CONFLICT_SSW：START确认拍flag_start_restore必成立
	v7_chk_imp #(.C_NAME("P9d_SSW_START_RESTORE")) u_p9d(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(ppg_sar9_sar15_safe_selection_wrapper_Inst.i_start_ack_event),
		.i_b(ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_start_restore));
	// V1_CONFLICT_RDC：吞掉迟到RAW的拍不得同时配对
	v7_chk_mutex #(.C_NAME("P9e_RC_DROP_NOT_TRANSFER")) u_p9e(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a(ppg_adc_measurement_idac_integration_Inst.ppg_adc_s1_redundancy_corrector_Inst.flag_capture_drop), .i_b(ppg_adc_measurement_idac_integration_Inst.ppg_adc_s1_redundancy_corrector_Inst.flag_capture_transfer));
	// V1_CONFLICT_PWC（V1-PWC-C3护栏）：精度控制器IDLE时无pending来源位
	v7_chk_imp #(.C_NAME("P9f_PWC_IDLE_NO_PENDING_SOURCE")) u_p9f(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a(ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.state_current == 3'd0),
		.i_b(!ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.flag_pending_cross &&
			!ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.flag_pending_return));
	// V1_CONFLICT_SCH：未START时调度器不发出任何上下文、请求ready或事务valid
	v7_chk_imp #(.C_NAME("P9g_SCH_NOT_STARTED_QUIET")) u_p9g(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a(!ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_400hz_frame_calibration_scheduler_Inst.B_STARTED]),
		.i_b(!ppg_400hz_frame_calibration_scheduler_Inst.o_waveform_context_valid && !ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_sample_ready && !ppg_400hz_frame_calibration_scheduler_Inst.o_transaction_start_valid));
	// V1_CONFLICT_RCK：重检请求transfer拍不会同时被IDAC消费
	v7_chk_mutex #(.C_NAME("P9h_RCK_TRANSFER_NOT_ACCEPTED")) u_p9h(.i_clk(i_clk), .i_rstn(i_rstn),
		.i_a(ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_calibration_transfer),
		.i_b(ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_matching_sample_accepted));
	// V1_CONFLICT_AMI：校准请求fire拍不得同时撤销或被消费
	v7_chk_imp #(.C_NAME("P9i_AMI_CAL_FIRE_EXCLUSIVE")) u_p9i(.i_clk(i_clk), .i_rstn(i_rstn), .i_a(ppg_adc_measurement_idac_integration_Inst.calibration_request_fire_o),
		.i_b(!ppg_adc_measurement_idac_integration_Inst.flag_calibration_request_withdraw && !ppg_adc_measurement_idac_integration_Inst.flag_amb_sample_accepted && !ppg_adc_measurement_idac_integration_Inst.flag_dcs_sample_accepted));
endmodule

bind ppg_control_top v7_bind_control_top u_v7_bind(.i_clk(i_clk), .i_rstn(i_rstn), .i_commit(sched_adc_owner_commit_event_o), .i_done(ami_adc_transaction_complete_event_o),
	.i_lost(ami_adc_transaction_lost_event_o), .i_life(o_lifecycle_state), .i_result(o_measurement_result_valid && i_measurement_result_ready),
	.i_fault(ami_fault_valid_o || sched_fault_valid_o || ssw_fault_valid_o || o_system_fault_blocking));
