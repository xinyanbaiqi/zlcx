`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/24
// Design Name:        PPG Digital System Top Verification-Injection Testbench
// Module Name:        tb_ppg_control_top_injection
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md, PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md, PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.1
// Revision Date:      2026/09/06
// History:
//    Time               Version       Revised by            Contents
// 2026/08/24            V1.0          Erie                  Create file, separate from tb_ppg_control_top.v because C_ENABLE_TEST_INJECTION is a compile-time parameter (default 0 in production and in the main smoke TB) that must be overridden to 1 to exercise the injection port group at all. Covers C01 TOP-21~24 with real simulation evidence: INJ-01 is a within-this-build slice of TOP-21 (C_ENABLE_TEST_INJECTION=1 but i_test_inject_enable=0, confirming both injection ready outputs stay 0 and one real transaction completes identically to the non-injection baseline); TOP-21's other half (parameter default 0 in production) is already evidenced by all 22 scenarios in tb_ppg_control_top.v, which never overrides this parameter. INJ-02 is LFA-08, INJ-03 is PRC-08, INJ-04 is the TOP-24 double-request mutex. Getting these three real took four rounds of real bugs, all found by actually running this against real RTL rather than assuming the contract text described the implementation: (1) i_test_inject_enable is a CONFIG/READY-only configuration request that Top latches into flag_test_inject_mode_latched exactly once at START and holds immutable through RUN (AMI contract 6.5b); this TB's first attempt raised the enable mid-RUN inside INJ-01's already-started RUN, so flag_test_inject_effective stayed 0 for the rest of that RUN -- fixed by adding an explicit STOP+drain+re-commit+START cycle between INJ-01 and INJ-02 with the enable set beforehand. (2) o_test_identity_inject_ready/o_test_invalid_sample_ready are one-shot pulses that fire and clear again within the few cycles it takes drive_real_adc_done's blocking physical drive to run, so polling for ready in a while loop AFTER that task returns always saw it already gone; fixed by checking AMI's own flag_test_identity_hold (a level that stays 1 once the mismatch is latched) for identity injection, and by running the invalid-sample arm/drive/ready-detect/result-detect as one continuous fork so no observation gap exists. (3) The genuinely important discovery: LFA-08's STOP-triggered owner recovery was actually undeliverable in the RTL as found -- flag_adc_completion_abort_release additionally required the redundancy corrector's own transient flag_s1_detect_valid, which clears one to two cycles after the original real DONE and never returns, so any STOP/abort arriving later (the entire point of the feature) could never satisfy the release condition and the RUN deadlocked permanently in STOPPING. This TB is what first exercised that exact timing window with injection actually enabled; the real fix landed in ppg_adc_measurement_idac_integration.v V1.12 (dropped the flag_s1_detect_valid term). (4) This TB's own discard-event check then assumed the STOP recovery would surface through o_measurement_result_discard_event, which is scoped to the measurement-fork's own pending state; an LFA-08-mismatched transaction never enters that fork at all (blocked at flag_test_identity_hold before the fork), so that event correctly never fires here -- fixed the check to watch the scheduler's own B_INFLIGHT bit clearing instead, which is what the recovery actually manifests as. Scope note: this file does not attempt every negative rule in AMI contract section 6.5b (e.g. STOP/abort/reset cancellation of an unbound invalid request, a second independent injection attempt while one is already latched) -- only the core LFA-08/PRC-08/TOP-24 flows above are covered; the remaining rules are a known coverage gap, not silently assumed to pass.
// 2026/09/06            V1.1          Erie                  Add a P06 sub-check inside INJ-02, right after flag_test_identity_hold is confirmed latched: deassert i_test_inject_enable for a real-verified-safe 2-cycle window and confirm flag_test_identity_hold stays 1, then restore the enable and continue INJ-02's original STOP-recovery flow unchanged. Closes matrix item P06 ("AMI request slots | Enable deassertion cannot revoke an accepted request") with real evidence -- flag_test_identity_hold's own always block (ppg_adc_measurement_idac_integration.v) never lists i_test_inject_enable in its clear conditions; only reset, i_start_ack_event and i_control_abort_event clear it, so this was a real untested-but-correct RTL behavior, not a bug. (2026-09-28 workline D independent recheck: corrected this line's own "20 cycles" to the actual implemented and matrix-documented "2-cycle" window -- the code itself and the matrix narrative always agreed on 2 cycles; only this changelog line's number was wrong.)
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月24日
// 设计名称:           PPG数字系统顶层验证注入测试平台
// 模块名称:           tb_ppg_control_top_injection
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md、PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md、PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.1
// 修订日期:           2026年09月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月24日        V1.0          Erie                  创建文件，与tb_ppg_control_top.v分开是因为C_ENABLE_TEST_INJECTION是编译期参数（生产默认0，主烟雾TB也从未覆盖过），要真正驱动注入端口组必须单独实例化并覆盖成1。覆盖C01 TOP-21~24并拿到真实仿真证据：INJ-01是TOP-21切片，INJ-02是LFA-08，INJ-03是PRC-08，INJ-04是TOP-24双请求互斥。把这三条真正跑通，一共经历了四轮真实bug——全部是靠真跑RTL发现的，不是靠读合同文字假设实现就是这样。（1）i_test_inject_enable只是CONFIG/READY期间的配置请求，顶层在START那一刻原子锁存进flag_test_inject_mode_latched后RUN期间不可变（AMI合同6.5b节）；本TB第一次尝试在INJ-01已经START的RUN中途拉高enable，导致flag_test_inject_effective那整个RUN都恒为0——修复：在INJ-01和INJ-02之间插入一次显式STOP+排空+重新COMMIT+START，把enable提前设置好。（2）o_test_identity_inject_ready/o_test_invalid_sample_ready都是一次性脉冲，在drive_real_adc_done这个阻塞任务执行期间的几拍内就握手完毕并回落，任务返回后再poll永远只会看到它已经消失；修复：身份注入改查AMI自己的flag_test_identity_hold（错配锁存后保持为1的电平），invalid-sample注入改成把武装/投递/ready检测/结果检测全部放进同一个fork里连续监视，不留观察空档。（3）真正重要的发现：LFA-08 STOP触发的owner恢复在原RTL里实际上不可达——flag_adc_completion_abort_release还额外要求S1冗余校正器自己的瞬态flag_s1_detect_valid，这个信号在原始真实DONE到达后一两拍内就回落且再也不会回来，而STOP/abort按设计恰恰是在那之后任意时刻才会真正发出（这正是这个功能存在的意义），导致释放条件事实上永远等不到，一旦LFA-08错配触发RUN就永久卡死在STOPPING。本TB是第一次真正在打开注入的条件下跑到这个精确时序窗口；真正的修复落在ppg_adc_measurement_idac_integration.v V1.12（去掉flag_s1_detect_valid这一项）。（4）本TB自己的STOP恢复检查最初还假设会经o_measurement_result_discard_event体现——那个信号专属测量结果fork自己pending态的受控丢弃，而LFA-08错配的事务从一开始就被flag_test_identity_hold挡在fork之外，根本不会进入，自然不会触发这个事件；修复为改查scheduler自己的B_INFLIGHT位是否清0，这才是恢复真正体现的地方。范围说明：本文件不追求覆盖AMI合同6.5b节的每一条负向规则（比如STOP/abort/reset对未绑定invalid请求的撤销、同一owner上第二次独立注入尝试），只覆盖上述LFA-08/PRC-08/TOP-24核心流程；其余规则是已知覆盖缺口，不是默默假设通过。
// 2026年09月06日        V1.1          Erie                  在INJ-02内flag_test_identity_hold确认置位之后新增P06子检查：把i_test_inject_enable拉低20拍，确认flag_test_identity_hold依然为1，再恢复enable并继续原有INJ-02的STOP恢复流程不变。关闭矩阵P06项（"AMI request slots | Enable deassertion cannot revoke an accepted request"），真实证据：flag_test_identity_hold自己的always块（ppg_adc_measurement_idac_integration.v）从未把i_test_inject_enable列入清零条件，只有复位、i_start_ack_event、i_control_abort_event三种，这是此前真实存在但从未被测过的正确行为，不是bug。
//
// 复位后原子提交一组合法NORMAL单光MANUAL IDAC配置并启动RUN，用C_ENABLE_TEST_INJECTION=1
// 编译，依次验证注入端口生产旁路、LFA-08身份错配、PRC-08 invalid-sample资格和
// TOP-24双请求互斥，STOP后确认排空与关键输出无X传播
module tb_ppg_control_top_injection();

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
	localparam [1:0] DISCARD_REASON_STOP = 2'b00; // AMI私有discard组STOP排空原因编码，与ppg_adc_measurement_idac_integration.v逐位一致

	// 以下V5默认字段值与ppg_system_config_manager.v的V5_RESET_PROFILE逐项一致，
	// 只用于凑出一份合法1024-bit联合快照；本轮注入验证不exercising峰谷/相交算法
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
	reg i_clk; // 2 MHz语义系统时钟仿真替身
	reg i_rstn; // 系统域低有效复位
	reg i_source_clk; // SPI配置源域仿真时钟
	reg i_source_rstn; // 源域低有效复位

	//---------------V4+V5源域配置信号---------------//
	reg [C_CONFIG_WIDTH - 1:0] i_source_config_snapshot; // 待提交的1024-bit联合快照
	reg i_source_config_update_event; // 快照传输请求单拍

	//---------------表征source信号---------------//
	reg i_source_characterization_update_valid; // 本轮不驱动表征更新，恒0
	reg i_source_static_characterization_enable; // 本轮不使用STATIC_BIAS，恒0
	reg [4:0] i_source_test_mux_ctrl; // 本轮不使用测试MUX，恒0

	//---------------已同步生命周期与诊断信号---------------//
	reg i_start_event; // START单拍
	reg i_stop_event; // STOP单拍
	reg i_diag_clear_event; // 用于清除LFA-08触发的注册式诊断sticky
	reg i_control_abort_event; // 本轮不触发abort，恒0

	//---------------物理ADC与模拟边界信号---------------//
	reg [9:0] i_dout_stage1_low; // Stage1物理判决码激励
	reg i_clk_stage1_dout_low_async; // Stage1异步完成脉冲激励
	reg [9:0] i_dout_stage2_low; // Stage2物理判决码激励
	reg i_clk_stage2_dout_low_async; // Stage2异步完成脉冲激励，同时携带精度位
	reg i_adc_physical_idle; // 物理ADC空闲电平，仅在响应窗口内短暂拉低
	reg i_analog_ready; // 模拟就绪聚合结果，本轮恒1

	//---------------正式结果消费者信号---------------//
	reg i_measurement_result_ready; // 本轮消费者恒接受

	//---------------验证专用异常注入信号---------------//
	reg i_test_inject_enable; // 本文件的核心：验证构建注入使能，配合C_ENABLE_TEST_INJECTION=1
	reg i_test_identity_inject_valid; // LFA-08错误完成身份请求
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] i_test_identity_inject_sample_index; // LFA-08显式错误sample_index
	reg i_test_invalid_sample_valid; // PRC-08 invalid-sample资格请求
	reg i_test_saturation_inject_valid = 1'b0; // 本文件不覆盖SID-11场景，恒0安全占位
	reg i_context_handover_stall_request = 1'b0; // 本文件不覆盖OIB-01场景，恒0安全占位

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
	integer cnt_error; // 累计FAIL数
	integer cnt_source_clock; // source时钟有限循环计数
	integer cnt_system_clock; // 系统时钟有限循环计数
	reg flag_global_timeout; // 全局看门狗超时标记

	//---------------DUT实例化---------------//
	// C01顶层：与主烟雾TB的唯一差异是C_ENABLE_TEST_INJECTION覆盖为1，
	// 使i_test_inject_enable真正有机会生效（flag_test_inject_effective =
	// C_ENABLE_TEST_INJECTION && flag_test_inject_mode_latched）
	ppg_control_top
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 与本TB本地参数一致
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 与本TB本地参数一致
			.C_CONFIG_WIDTH(C_CONFIG_WIDTH), // 与本TB本地参数一致
			.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 与本TB本地参数一致
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH), // 与本TB本地参数一致
			.C_ENABLE_TEST_INJECTION(1) // 本文件的核心覆盖：打开验证专用异常注入结构生成
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
 .i_test_calibration_loss_inject_valid(1'b0),
			.i_test_saturation_inject_valid(i_test_saturation_inject_valid),
			.i_context_handover_stall_request(i_context_handover_stall_request),
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
	// 使用与system时钟互质的仿真周期形成独立CDC相位关系，绝对时间不代表真实SPI频率
	initial begin
		i_source_clk = 1'b0;
		for(cnt_source_clock = 0; cnt_source_clock < 3000000; cnt_source_clock = cnt_source_clock + 1) begin
			#5.5 i_source_clk = ~i_source_clk;
		end
	end

	//---------------系统时钟发生器---------------//
	// 系统时钟只承担边沿语义，绝对仿真时间不代表真实2 MHz周期
	initial begin
		i_clk = 1'b0;
		for(cnt_system_clock = 0; cnt_system_clock < 3000000; cnt_system_clock = cnt_system_clock + 1) begin
			#6.5 i_clk = ~i_clk;
		end
	end

	//---------------全局看门狗进程---------------//
	// 防止任何未预期的挂死导致仿真永不收敛
	initial begin
		flag_global_timeout = 1'b0;
		#12000000;
		flag_global_timeout = 1'b1;
		$display("FAIL INJ global watchdog timeout, forcing finish");
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------合法NORMAL单光MANUAL配置构造任务---------------//
	// 与主烟雾TB task_build_normal_manual_config逐字段一致，复用已验证过的合法值
	task task_build_normal_manual_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0; // run_profile=NORMAL_PPG
			i_source_config_snapshot[9] = 1'b0; // input_source=PHOTODIODE
			i_source_config_snapshot[11:10] = 2'b00; // idac_mode=MANUAL
			i_source_config_snapshot[13:12] = 2'b10; // optical_mode=IR单光
			i_source_config_snapshot[14] = 1'b0; // initial_precision=SAR9
			i_source_config_snapshot[15] = 1'b1; // amb_enable
			i_source_config_snapshot[16] = 1'b1; // dcs_enable
			i_source_config_snapshot[17] = 1'b1; // amb_polarity
			i_source_config_snapshot[18] = 1'b0; // dcs_polarity
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
			i_source_config_snapshot[115:104] = -12'sd64; // amb_threshold_low
			i_source_config_snapshot[127:116] = 12'sd72; // amb_threshold_high
			i_source_config_snapshot[139:128] = -12'sd48; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd56; // dcs_threshold_high
			i_source_config_snapshot[159:152] = 8'd8; // amb_confirm_count
			i_source_config_snapshot[167:160] = 8'd9; // dcs_confirm_count
			i_source_config_snapshot[193:168] = -26'sd17; // stage1_weight_q16_0
			i_source_config_snapshot[219:194] = 26'sd18; // stage1_weight_q16_1
			i_source_config_snapshot[245:220] = -26'sd19; // stage1_weight_q16_2
			i_source_config_snapshot[271:246] = 26'sd20; // stage1_weight_q16_3
			i_source_config_snapshot[297:272] = -26'sd21; // stage1_weight_q16_4
			i_source_config_snapshot[323:298] = 26'sd22; // stage1_weight_q16_5
			i_source_config_snapshot[349:324] = -26'sd23; // stage1_weight_q16_6
			i_source_config_snapshot[375:350] = 26'sd24; // stage1_weight_q16_7
			i_source_config_snapshot[401:376] = -26'sd25; // stage1_weight_q16_8
			i_source_config_snapshot[427:402] = 26'sd26; // stage1_weight_q16_9
			i_source_config_snapshot[459:428] = -32'sd99; // stage1_offset_q16
			i_source_config_snapshot[479:460] = 20'sd54143; // stage2_gain_q16
			i_source_config_snapshot[511:480] = -32'sd37; // stage2_offset_q16
			i_source_config_snapshot[543:512] = 32'sd65536; // dc9_recovery_gain_q16
			i_source_config_snapshot[575:544] = 32'sd32768; // dc15_recovery_gain_q16
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames
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

	//---------------START事件任务---------------//
	task task_pulse_start;
		begin
			@(negedge i_clk);
			i_start_event = 1'b1;
			@(posedge i_clk);
			#1 i_start_event = 1'b0;
		end
	endtask

	//---------------STOP事件任务---------------//
	task task_pulse_stop;
		begin
			@(negedge i_clk);
			i_stop_event = 1'b1;
			@(posedge i_clk);
			#1 i_stop_event = 1'b0;
		end
	endtask

	//---------------abort事件任务---------------//
	task task_pulse_abort;
		begin
			@(negedge i_clk);
			i_control_abort_event = 1'b1;
			@(posedge i_clk);
			#1 i_control_abort_event = 1'b0;
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
				$display("FAIL INJ config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------真实ADC完成响应任务---------------//
	// 只在物理边界注入RAW/CLK_DOUT，不伪造完成脉冲；短暂拉低物理空闲电平模拟一次真实转换
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

	//---------------Q3门控等待任务---------------//
	// 与主烟雾TB同名任务逐行一致：只在观察到真实Q3脉冲出现且释放后才返回，
	// 5600拍内等不到Q3是合法的安全超时，不是异常
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
					$display("FAIL INJ Q3 wait timeout");
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

	//---------------主测试序列---------------//
	reg [9:0] reg_fixed_stage1_raw;
	reg [9:0] reg_fixed_stage2_raw;
	reg flag_q3_real_release;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_original_sample_index;
	reg flag_invalid_sample_fired;
	reg flag_result_seen;
	reg reg_captured_sample_valid;
	reg signed [23:0] reg_captured_coarse_value;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_captured_frame_id;
	integer cnt_wait_loop;
	integer cnt_discard_events;
	integer cnt_discard_before;

	//---------------后台discard事件计数进程---------------//
	// STOP恢复触发的discard事件可能与STOP本身同拍或紧随其后一拍就完成并清0，
	// 场景内fork/join监视存在评估顺序的竞争风险（曾经因此把"已发生、错过了"
	// 误判成"从未发生"）。改用从仿真一开始就持续运行的后台累计计数器，场景
	// 内只需要在动作前后各取一次快照做差，彻底避开一次性fork监视的时序竞争
	reg [1:0] reg_last_discard_reason;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_last_discard_sample_index;
	initial begin
		cnt_discard_events = 0;
		forever begin
			@(posedge i_clk);
			if(o_measurement_result_discard_event) begin
				cnt_discard_events = cnt_discard_events + 1;
				reg_last_discard_reason = o_measurement_result_discard_reason;
				reg_last_discard_sample_index = o_measurement_result_discard_sample_index;
			end
		end
	end


 integer b_mutex_cycles;integer b_eligible_cycles;integer b_ready_cycles;
 initial begin
  b_mutex_cycles=0;b_eligible_cycles=0;b_ready_cycles=0;
 		cnt_error = 0;
		i_rstn = 1'b0;
		i_source_rstn = 1'b0;
		i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
		i_source_config_update_event = 1'b0;
		i_source_characterization_update_valid = 1'b0;
		i_source_static_characterization_enable = 1'b0;
		i_source_test_mux_ctrl = 5'd0;
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
		i_test_inject_enable = 1'b1;
		i_test_identity_inject_valid = 1'b0;
		i_test_identity_inject_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
		i_test_invalid_sample_valid = 1'b0;
		make_fixed_raw(256, reg_fixed_stage1_raw);
		make_fixed_raw(300, reg_fixed_stage2_raw);

		repeat(10) @(posedge i_clk);
		i_rstn = 1'b1;
		i_source_rstn = 1'b1;
		repeat(10) @(posedge i_clk);

		// 合法COMMIT+START，为后续四个注入场景提供一条真实运行中的NORMAL RUN
		task_build_normal_manual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL INJ-00 initial commit before injection scenarios");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS INJ-00 initial commit before injection scenarios");
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

 		begin : inj04_mutex
			wait_q3_release(flag_q3_real_release);
			if(!flag_q3_real_release) begin
				$display("FAIL INJ-04 real Q3 window never opened");
				cnt_error = cnt_error + 1;
			end else begin
				i_test_identity_inject_sample_index = 16'hFFFE;
				i_test_identity_inject_valid = 1'b1;
				i_test_invalid_sample_valid = 1'b1;
 i_measurement_result_ready=0;
				drive_real_adc_done(1'b0, reg_fixed_stage1_raw, reg_fixed_stage2_raw);
 repeat(60) @(negedge i_clk);
				if(o_test_identity_inject_ready || o_test_invalid_sample_ready) begin
					$display("FAIL INJ-04 one or both injection ready outputs asserted during simultaneous double request, identity_ready=%b invalid_ready=%b",
						o_test_identity_inject_ready, o_test_invalid_sample_ready);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS INJ-04 both injection ready outputs stayed 0 during simultaneous double request on the same owner");
				end
				i_test_identity_inject_valid = 1'b0;
				i_test_invalid_sample_valid = 1'b0;
				drive_real_adc_done(1'b0, reg_fixed_stage1_raw, reg_fixed_stage2_raw);
				cnt_wait_loop = 0;
				while(!o_measurement_result_valid && (cnt_wait_loop < 200) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_loop = cnt_wait_loop + 1;
				end
				if(!o_measurement_result_valid || !o_result_sample_valid) begin
					$display("FAIL INJ-04 real transaction did not complete cleanly after blocked double request, valid=%b sample_valid=%b", o_measurement_result_valid, o_result_sample_valid);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS INJ-04 real transaction completed cleanly with no side effect from the blocked double request");
				end
			end
		end

  $display("B_INJ_MUTEX original_window_cycles=%0d eligible_cycles=%0d ready_cycles=%0d errors=%0d",b_mutex_cycles,b_eligible_cycles,b_ready_cycles,cnt_error);
  if(cnt_error!=0 || b_ready_cycles!=0)$fatal(1,"B_INJ_MUTEX_FAIL");
  $display("B_INJ_MUTEX_PASS");$finish;
 end
 always@(posedge i_clk)begin
  if(i_test_identity_inject_valid===1'b1 && i_test_invalid_sample_valid===1'b1)begin
   b_mutex_cycles=b_mutex_cycles+1;
   if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_pending===1'b1 || ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_dc_result_valid===1'b1)b_eligible_cycles=b_eligible_cycles+1;
   if(o_test_identity_inject_ready===1'b1 || o_test_invalid_sample_ready===1'b1)b_ready_cycles=b_ready_cycles+1;
  end
 end
endmodule
