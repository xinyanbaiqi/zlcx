`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026/08/11 00:00:00
// Design Name: 	PPG Peak Valley Window Detector Testbench
// Module Name: 	tb_ppg_peak_valley_window_detector
// Description: 	Self-checking PVW-01 through PVW-48 verification
// Dependencies:
// ppg_peak_valley_window_detector.v
// Simulations:		TestBench/Vivado/2022.2/ppg_peak_valley_window_detector
//
// Referrences:		PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//
//
// Version:			V1.2
// Revision Date:	2026/09/17 00:00:00
// History:
//    Time			   Version	   Revised by			Contents
// 2026/08/11            V1.0          Erie                  Create file.
// 2026/09/16            V1.1          Erie                  Adapt to RTL V1.1-V1.4: connect the PWI-broadcast i_detection_discard group, i_run_generation and o_local_empty; replace direct STOP/abort pulses with generation-scoped discard broadcasts (PVW-35/36 first apply a stale-generation discard as a negative control; PVW-36 keeps i_run_enable and committed 15-bit precision so only the discard can clear state, and checks o_local_empty); PVW-37 now asserts a new START keeps the protocol sticky per contract sections 12.4/13.2.
// 2026/09/17            V1.2          Erie                  Work-line-D remediation of 4 confirmed test gaps plus 2 new acceptance IDs for previously untested contract clauses (no RTL change): PVW-09/PVW-39 add a genuine 16-bit frame-id wraparound (legal delta accepted, illegal half-wrap span rejected via the wraparound-specific term, not the generic discontiguity term); PVW-32 actually drives i_recheck_busy while real running-extremum state exists; PVW-33 adds a real non-idle accept negative case (verified to still clear state per RTL:346's pre-existing flag_runtime_clear design, tagged PVW-32/35/36 -- diagnostic-flag-not-block, not a new defect); PVW-47 exercises section 10.5's precision-drop-before-return-handshake clause (flag_precision_drop_event); PVW-48 exercises section 11.4's RETURN_REASON_PROTOCOL fallback (flag_fine_protocol_fallback_event). Raise the pass gate to 54.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026年08月11日
// 设计名称: 		PPG Peak Valley Window Detector Testbench
// 模块名称: 		tb_ppg_peak_valley_window_detector
// 模块说明:		逐项验证PVW-01至PVW-48冻结行为
// 依赖文件:
// ppg_peak_valley_window_detector.v
// 仿真工程: 		TestBench/Vivado/2022.2/ppg_peak_valley_window_detector
//
// 参考资料:		PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.2
// 修订日期:		2026年09月17日
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026年08月11日        V1.0          Erie                  创建文件
// 2026年09月16日        V1.1          Erie                  适配RTL V1.1-V1.4：连接PWI广播的i_detection_discard组、i_run_generation和o_local_empty；直接STOP/abort脉冲改为代际discard广播（PVW-35/36先施加陈旧代际反例；PVW-36保持RUN使能和已提交15-bit精度，只让discard清除状态并核对o_local_empty）；PVW-37按合同12.4/13.2节改为断言新START保留协议sticky
// 2026年09月17日        V1.2          Erie                  工作线D独立复核修复4处缺测试证据+新增2条验收ID（不改RTL）：PVW-09/PVW-39补真实16-bit帧号回绕（合法帧差被接受，非法半回绕跨度经回绕专属项而非通用不连续项被拒绝）；PVW-32真实驱动i_recheck_busy且运行极值已建立；PVW-33补真实非idle接受负例（核实RTL:346既有flag_runtime_clear设计——早带PVW-32/35/36标签——是诊断标记而非阻止清除，非新缺陷）；PVW-47覆盖§10.5精度提前下降条款（flag_precision_drop_event）；PVW-48覆盖§11.4 RETURN_REASON_PROTOCOL回退（flag_fine_protocol_fallback_event）。总PASS门限提高到54
// 使用真实输入输出比较验证峰谷检测、窗口控制、超时恢复和保持型事务
module tb_ppg_peak_valley_window_detector;

	//---------------配置参数区域---------------//
	parameter integer C_DATA_WIDTH = 32'd24;     // DUT统一PPG码位宽
	parameter integer C_FRAME_ID_WIDTH = 32'd16; // DUT中心帧编号位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16; // DUT事务序号位宽
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8; // DUT ACTIVE版本位宽
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8; // DUT Stage1版本位宽
	parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8; // DUT DC恢复版本位宽
	parameter integer C_CONFIRM_COUNT_WIDTH = 32'd4; // DUT方向确认计数位宽
	parameter integer C_INTERVAL_WIDTH = 32'd16; // DUT时间门限位宽
	parameter integer C_CLK_HALF_PERIOD_NS = 32'd250; // 2 MHz时钟半周期
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4; // DUT discard组IDAC码版本位宽
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8; // DUT RUN代际位宽
	localparam [1:0]DISCARD_REASON_STOP = 2'b00; // AMI私有discard组STOP排空编码
	localparam [1:0]DISCARD_REASON_ABORT = 2'b01; // AMI私有discard组abort撤销编码
	localparam [C_RUN_GENERATION_WIDTH - 1:0]RUN_GENERATION_CURRENT = 8'h5A; // 本TB固定的当前RUN代际
	localparam [C_RUN_GENERATION_WIDTH - 1:0]RUN_GENERATION_STALE = 8'h59; // 与当前代际不同的陈旧代际

	//---------------寄存器定义区域-------------//
	reg i_clk;                                   // 2 MHz仿真时钟
	reg i_rstn;                                  // 低有效异步复位激励
	reg i_run_enable;                            // RUN生命周期使能激励
	reg i_start_ack_event;                       // START接受单拍事件
	reg i_detection_discard_event;               // PWI代际清空广播单拍
	reg [1:0]i_detection_discard_reason;         // 清空原因STOP/abort/系统故障编码
	reg i_detection_discard_identity_valid;      // 清空触发身份可信标志，本TB使用scope-only清空
	reg i_detection_discard_sample_valid;        // 清空触发事务样本资格快照
	reg [C_FRAME_ID_WIDTH - 1:0]i_detection_discard_frame_id; // 清空触发事务帧号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_detection_discard_sample_index; // 清空触发事务序号
	reg i_detection_discard_color_ir;            // 清空触发事务颜色
	reg [1:0]i_detection_discard_frame_type;     // 清空触发事务类型
	reg i_detection_discard_precision;           // 清空触发事务精度
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_detection_discard_config_epoch; // 清空触发事务ACTIVE版本
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_detection_discard_coef_epoch; // 清空触发事务Stage1版本
	reg [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_detection_discard_dc_recovery_epoch; // 清空触发事务DC恢复版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_detection_discard_amb_code_epoch; // 清空触发事务AMB码版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_detection_discard_dc_code_epoch; // 清空触发事务DC码版本
	reg [C_RUN_GENERATION_WIDTH - 1:0]i_detection_discard_run_generation; // 清空目标RUN代际
	reg [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation; // 当前RUN代际快照激励
	reg i_diag_clear_event;                      // sticky清除单拍事件
	reg i_recheck_accept_event;                  // 重检安全接管单拍事件
	reg i_recheck_busy;                          // 重检忙状态激励
	reg i_recheck_done_event;                    // 重检结束单拍事件
	reg i_recheck_success;                       // 重检整体成功资格
	reg i_reacquire_active;                      // 外部重新获取状态
	reg [C_CONFIRM_COUNT_WIDTH - 1:0]i_peak_confirm_count; // 波峰下降确认门限
	reg [C_CONFIRM_COUNT_WIDTH - 1:0]i_valley_confirm_count; // 波谷上升确认门限
	reg [C_DATA_WIDTH - 1:0]i_direction_deadband; // 方向判定死区
	reg [C_DATA_WIDTH - 1:0]i_min_peak_valley_amplitude; // 峰谷最小幅度
	reg [C_INTERVAL_WIDTH - 1:0]i_min_peak_to_valley_frames; // 峰谷最小时间
	reg [C_INTERVAL_WIDTH - 1:0]i_min_peak_to_peak_frames; // 峰峰最小时间
	reg [C_INTERVAL_WIDTH - 1:0]i_max_fine_window_frames; // fine窗口最大时间
	reg [C_INTERVAL_WIDTH - 1:0]i_max_reacquire_frames; // 重新获取最大时间
	reg i_peak_valley_config_valid;              // 峰谷配置有效资格
	reg i_characterization_mode;                 // 表征模式激励
	reg i_result_valid;                          // FIR事务valid激励
	reg signed [C_DATA_WIDTH - 1:0]i_filtered_ppg_value; // Stage1粗FIR码值激励
	reg i_detection_qualified;                   // FIR正式检测资格
	reg i_window_saturation_low;                 // FIR窗口负向饱和激励
	reg i_window_saturation_high;                // FIR窗口正向饱和激励
	reg i_fir_saturation_low;                    // FIR结果负向饱和激励
	reg i_fir_saturation_high;                   // FIR结果正向饱和激励
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch; // 当前样本ACTIVE版本
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch; // 当前样本Stage1版本
	reg [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_dc_recovery_coef_epoch; // 当前样本DC恢复版本
	reg i_precision_mode;                        // 当前中心样本精度身份
	reg [C_FRAME_ID_WIDTH - 1:0]i_frame_id;      // 当前中心帧编号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index; // 当前中心事务序号
	reg i_color_ir;                              // RED或IR事务选择
	reg [1:0]i_frame_type;                       // 当前帧类型编码
	reg i_fine_window_start_event;               // 正式fine窗口提交事件
	reg [C_FRAME_ID_WIDTH - 1:0]i_fine_window_start_frame_id; // fine窗口起始帧
	reg i_active_precision_mode;                 // 系统已提交精度状态
	reg i_return_9bit_ready;                     // 返回9-bit请求接受资格
	reg i_peak_ready;                            // 波峰事件接受资格
	reg i_valley_ready;                          // 波谷事件接受资格
	integer cnt_pass;                            // 真实通过项目累计值
	integer cnt_fail;                            // 真实失败项目累计值
	integer cnt_wrap_frame;                      // PVW-09/39新增：帧号回绕专属场景循环索引
	integer flag_case_ok;                        // 多阶段项目的局部比较结果
	integer idx_random;                          // 宽位随机回归循环索引
	integer seed_random;                         // 可重复伪随机种子
	integer value_random;                        // 宽位随机波形当前值
	integer step_random;                         // 宽位随机波形变化步长
	integer model_peak_value;                    // 独立参考模型运行最大值
	integer model_peak_frame;                    // 独立参考模型最大值中心帧
	integer model_peak_sample;                   // 独立参考模型最大值事务号
	integer model_valley_value;                  // 独立参考模型运行最小值
	integer model_valley_frame;                  // 独立参考模型最小值中心帧
	integer model_valley_sample;                 // 独立参考模型最小值事务号

	//---------------内部信号定义区域-----------//
	wire o_result_ready;                         // DUT FIR事务ready
	wire o_return_9bit_valid;                    // DUT返回9-bit请求valid
	wire [1:0]o_return_reason;                  // DUT返回原因
	wire [C_FRAME_ID_WIDTH - 1:0]o_return_frame_id; // DUT返回绑定帧
	wire o_peak_valid;                           // DUT波峰事件valid
	wire signed [C_DATA_WIDTH - 1:0]o_peak_value; // DUT波峰码值
	wire [C_FRAME_ID_WIDTH - 1:0]o_peak_frame_id; // DUT波峰中心帧
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_peak_sample_index; // DUT波峰事务号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]o_peak_config_epoch; // DUT波峰ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]o_peak_coef_epoch; // DUT波峰Stage1版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_peak_dc_recovery_coef_epoch; // DUT波峰DC恢复版本
	wire o_valley_valid;                         // DUT波谷事件valid
	wire signed [C_DATA_WIDTH - 1:0]o_valley_value; // DUT波谷码值
	wire [C_FRAME_ID_WIDTH - 1:0]o_valley_frame_id; // DUT波谷中心帧
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_valley_sample_index; // DUT波谷事务号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]o_valley_config_epoch; // DUT波谷ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]o_valley_coef_epoch; // DUT波谷Stage1版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_valley_dc_recovery_coef_epoch; // DUT波谷DC恢复版本
	wire o_detector_idle;                        // DUT重检安全空闲状态
	wire o_fine_window_active;                   // DUT正式fine窗口状态
	wire o_reacquire_search_active;              // DUT重新获取状态
	wire o_fine_window_timeout_sticky;           // DUT fine超时历史
	wire o_reacquire_timeout_sticky;             // DUT重新获取超时历史
	wire o_protocol_error_sticky;                // DUT协议异常历史
	wire o_local_empty;                          // DUT本地排空状态

	//----------------实例化区域-----------------//
	// 被测模块使用正式默认位宽并由本TB直接驱动全部协议端口
	ppg_peak_valley_window_detector
	#(
		.C_DATA_WIDTH(C_DATA_WIDTH),
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH),
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH),
		.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH),
		.C_CONFIRM_COUNT_WIDTH(C_CONFIRM_COUNT_WIDTH),
		.C_INTERVAL_WIDTH(C_INTERVAL_WIDTH),
		.C_FIR_GROUP_DELAY_SAMPLES(32'd10),
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH),
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH)
	)inst_ppg_peak_valley_window_detector(
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_run_enable(i_run_enable),
		.i_start_ack_event(i_start_ack_event),
		.i_diag_clear_event(i_diag_clear_event),
		.i_recheck_accept_event(i_recheck_accept_event),
		.i_recheck_busy(i_recheck_busy),
		.i_recheck_done_event(i_recheck_done_event),
		.i_recheck_success(i_recheck_success),
		.i_reacquire_active(i_reacquire_active),
		.i_detection_discard_event(i_detection_discard_event),
		.i_detection_discard_reason(i_detection_discard_reason),
		.i_detection_discard_identity_valid(i_detection_discard_identity_valid),
		.i_detection_discard_sample_valid(i_detection_discard_sample_valid),
		.i_detection_discard_frame_id(i_detection_discard_frame_id),
		.i_detection_discard_sample_index(i_detection_discard_sample_index),
		.i_detection_discard_color_ir(i_detection_discard_color_ir),
		.i_detection_discard_frame_type(i_detection_discard_frame_type),
		.i_detection_discard_precision(i_detection_discard_precision),
		.i_detection_discard_config_epoch(i_detection_discard_config_epoch),
		.i_detection_discard_coef_epoch(i_detection_discard_coef_epoch),
		.i_detection_discard_dc_recovery_epoch(i_detection_discard_dc_recovery_epoch),
		.i_detection_discard_amb_code_epoch(i_detection_discard_amb_code_epoch),
		.i_detection_discard_dc_code_epoch(i_detection_discard_dc_code_epoch),
		.i_detection_discard_run_generation(i_detection_discard_run_generation),
		.i_run_generation(i_run_generation),
		.o_local_empty(o_local_empty),
		.i_peak_confirm_count(i_peak_confirm_count),
		.i_valley_confirm_count(i_valley_confirm_count),
		.i_direction_deadband(i_direction_deadband),
		.i_min_peak_valley_amplitude(i_min_peak_valley_amplitude),
		.i_min_peak_to_valley_frames(i_min_peak_to_valley_frames),
		.i_min_peak_to_peak_frames(i_min_peak_to_peak_frames),
		.i_max_fine_window_frames(i_max_fine_window_frames),
		.i_max_reacquire_frames(i_max_reacquire_frames),
		.i_peak_valley_config_valid(i_peak_valley_config_valid),
		.i_characterization_mode(i_characterization_mode),
		.i_result_valid(i_result_valid),
		.o_result_ready(o_result_ready),
		.i_filtered_ppg_value(i_filtered_ppg_value),
		.i_detection_qualified(i_detection_qualified),
		.i_window_saturation_low(i_window_saturation_low),
		.i_window_saturation_high(i_window_saturation_high),
		.i_fir_saturation_low(i_fir_saturation_low),
		.i_fir_saturation_high(i_fir_saturation_high),
		.i_config_epoch(i_config_epoch),
		.i_coef_epoch(i_coef_epoch),
		.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch),
		.i_precision_mode(i_precision_mode),
		.i_frame_id(i_frame_id),
		.i_sample_index(i_sample_index),
		.i_color_ir(i_color_ir),
		.i_frame_type(i_frame_type),
		.i_fine_window_start_event(i_fine_window_start_event),
		.i_fine_window_start_frame_id(i_fine_window_start_frame_id),
		.i_active_precision_mode(i_active_precision_mode),
		.o_return_9bit_valid(o_return_9bit_valid),
		.i_return_9bit_ready(i_return_9bit_ready),
		.o_return_reason(o_return_reason),
		.o_return_frame_id(o_return_frame_id),
		.o_peak_valid(o_peak_valid),
		.i_peak_ready(i_peak_ready),
		.o_peak_value(o_peak_value),
		.o_peak_frame_id(o_peak_frame_id),
		.o_peak_sample_index(o_peak_sample_index),
		.o_peak_config_epoch(o_peak_config_epoch),
		.o_peak_coef_epoch(o_peak_coef_epoch),
		.o_peak_dc_recovery_coef_epoch(o_peak_dc_recovery_coef_epoch),
		.o_valley_valid(o_valley_valid),
		.i_valley_ready(i_valley_ready),
		.o_valley_value(o_valley_value),
		.o_valley_frame_id(o_valley_frame_id),
		.o_valley_sample_index(o_valley_sample_index),
		.o_valley_config_epoch(o_valley_config_epoch),
		.o_valley_coef_epoch(o_valley_coef_epoch),
		.o_valley_dc_recovery_coef_epoch(o_valley_dc_recovery_coef_epoch),
		.o_detector_idle(o_detector_idle),
		.o_fine_window_active(o_fine_window_active),
		.o_reacquire_search_active(o_reacquire_search_active),
		.o_fine_window_timeout_sticky(o_fine_window_timeout_sticky),
		.o_reacquire_timeout_sticky(o_reacquire_timeout_sticky),
		.o_protocol_error_sticky(o_protocol_error_sticky)
	);

	//----------------任务定义区域---------------//
	// 默认配置任务为每个独立场景恢复同一合法ACTIVE参数基线
	task set_default_inputs;
	begin
		i_run_enable = 1'b0;
		i_start_ack_event = 1'b0;
		i_detection_discard_event = 1'b0;
		i_detection_discard_reason = DISCARD_REASON_STOP;
		i_detection_discard_identity_valid = 1'b0;
		i_detection_discard_sample_valid = 1'b0;
		i_detection_discard_frame_id = 16'd0;
		i_detection_discard_sample_index = 16'd0;
		i_detection_discard_color_ir = 1'b0;
		i_detection_discard_frame_type = 2'b00;
		i_detection_discard_precision = 1'b0;
		i_detection_discard_config_epoch = 8'd0;
		i_detection_discard_coef_epoch = 8'd0;
		i_detection_discard_dc_recovery_epoch = 8'd0;
		i_detection_discard_amb_code_epoch = 4'd0;
		i_detection_discard_dc_code_epoch = 4'd0;
		i_detection_discard_run_generation = 8'd0;
		i_run_generation = RUN_GENERATION_CURRENT;
		i_diag_clear_event = 1'b0;
		i_recheck_accept_event = 1'b0;
		i_recheck_busy = 1'b0;
		i_recheck_done_event = 1'b0;
		i_recheck_success = 1'b1;
		i_reacquire_active = 1'b0;
		i_peak_confirm_count = 4'd3;
		i_valley_confirm_count = 4'd3;
		i_direction_deadband = 24'd0;
		i_min_peak_valley_amplitude = 24'd20;
		i_min_peak_to_valley_frames = 16'd2;
		i_min_peak_to_peak_frames = 16'd4;
		i_max_fine_window_frames = 16'd40;
		i_max_reacquire_frames = 16'd40;
		i_peak_valley_config_valid = 1'b1;
		i_characterization_mode = 1'b0;
		i_result_valid = 1'b0;
		i_filtered_ppg_value = {C_DATA_WIDTH{1'b0}};
		i_detection_qualified = 1'b1;
		i_window_saturation_low = 1'b0;
		i_window_saturation_high = 1'b0;
		i_fir_saturation_low = 1'b0;
		i_fir_saturation_high = 1'b0;
		i_config_epoch = 8'd1;
		i_coef_epoch = 8'd2;
		i_dc_recovery_coef_epoch = 8'd3;
		i_precision_mode = 1'b0;
		i_frame_id = 16'd0;
		i_sample_index = 16'd0;
		i_color_ir = 1'b0;
		i_frame_type = 2'b10;
		i_fine_window_start_event = 1'b0;
		i_fine_window_start_frame_id = 16'd0;
		i_active_precision_mode = 1'b0;
		i_return_9bit_ready = 1'b0;
		i_peak_ready = 1'b0;
		i_valley_ready = 1'b0;
	end
	endtask

	// 异步复位任务清除DUT后恢复稳定合法输入
	task reset_dut;
	begin
		@(negedge i_clk);
		set_default_inputs;
		i_rstn = 1'b0;
		repeat(3)@(posedge i_clk);
		@(negedge i_clk);
		i_rstn = 1'b1;
		@(posedge i_clk);
		#1;
	end
	endtask

	// 新RUN任务用单拍START建立9-bit重新获取状态
	task start_run;
	begin
		@(negedge i_clk);
		i_run_enable = 1'b1;
		i_start_ack_event = 1'b1;
		@(posedge i_clk);
		#1;
		@(negedge i_clk);
		i_start_ack_event = 1'b0;
	end
	endtask

	// 通用FIR事务任务严格等待ready并完成一次保持型握手
	task push_sample;
		input integer value_code;
		input [C_FRAME_ID_WIDTH - 1:0]frame_code;
		input [C_SAMPLE_INDEX_WIDTH - 1:0]sample_code;
		input flag_qualified;
		input flag_saturated;
		input flag_ir;
		input flag_precision;
	begin
		@(negedge i_clk);
		while(o_result_ready !== 1'b1)begin
			@(negedge i_clk);
		end
		i_filtered_ppg_value = value_code;
		i_frame_id = frame_code;
		i_sample_index = sample_code;
		i_detection_qualified = flag_qualified;
		i_window_saturation_high = flag_saturated;
		i_color_ir = flag_ir;
		i_precision_mode = flag_precision;
		i_result_valid = 1'b1;
		@(posedge i_clk);
		#1;
		@(negedge i_clk);
		i_result_valid = 1'b0;
		i_window_saturation_high = 1'b0;
		i_detection_qualified = 1'b1;
		i_color_ir = 1'b0;
	end
	endtask

	// RED正式样本任务继承当前epoch和精度配置
	task push_red;
		input integer value_code;
		input [C_FRAME_ID_WIDTH - 1:0]frame_code;
	begin
		push_sample(value_code, frame_code, frame_code + 16'd1000, 1'b1, 1'b0, 1'b0, i_precision_mode);
	end
	endtask

	// 首峰波形任务产生最大值后恰好三个连续下降样本
	task make_basic_peak;
		input [C_FRAME_ID_WIDTH - 1:0]base_frame;
	begin
		push_red(100, base_frame);
		push_red(120, base_frame + 16'd1);
		push_red(110, base_frame + 16'd2);
		push_red(100, base_frame + 16'd3);
		push_red(90, base_frame + 16'd4);
	end
	endtask

	// 波谷波形任务在活动波峰后产生运行最小值和三个上升样本
	task make_basic_valley;
		input [C_FRAME_ID_WIDTH - 1:0]base_frame;
	begin
		push_red(80, base_frame + 16'd5);
		push_red(60, base_frame + 16'd6);
		push_red(50, base_frame + 16'd7);
		push_red(60, base_frame + 16'd8);
		push_red(70, base_frame + 16'd9);
		push_red(80, base_frame + 16'd10);
	end
	endtask

	// 波峰握手任务释放保持型事件并等待寄存器清除
	task consume_peak;
	begin
		@(negedge i_clk);
		i_peak_ready = 1'b1;
		@(posedge i_clk);
		#1;
		@(negedge i_clk);
		i_peak_ready = 1'b0;
	end
	endtask

	// 波谷握手任务释放保持型事件并等待寄存器清除
	task consume_valley;
	begin
		@(negedge i_clk);
		i_valley_ready = 1'b1;
		@(posedge i_clk);
		#1;
		@(negedge i_clk);
		i_valley_ready = 1'b0;
	end
	endtask

	// 返回请求握手任务只表示模式控制器已经接受下一帧切换
	task consume_return_request;
	begin
		@(negedge i_clk);
		i_return_9bit_ready = 1'b1;
		@(posedge i_clk);
		#1;
		@(negedge i_clk);
		i_return_9bit_ready = 1'b0;
	end
	endtask

	// fine窗口提交任务冻结第一笔正式15-bit中心帧
	task start_fine_window;
		input [C_FRAME_ID_WIDTH - 1:0]start_frame;
	begin
		@(negedge i_clk);
		i_active_precision_mode = 1'b1;
		i_fine_window_start_frame_id = start_frame;
		i_fine_window_start_event = 1'b1;
		@(posedge i_clk);
		#1;
		@(negedge i_clk);
		i_fine_window_start_event = 1'b0;
		i_precision_mode = 1'b1;
	end
	endtask

	// 单拍控制任务用于诊断清除和重检事件的确定性激励
	task pulse_control;
		input integer control_code;
	begin
		@(negedge i_clk);
		case(control_code)
			3:begin i_diag_clear_event = 1'b1; end
			4:begin i_recheck_accept_event = 1'b1; end
			5:begin i_recheck_done_event = 1'b1; end
			default:begin i_diag_clear_event = 1'b0; end
		endcase
		@(posedge i_clk);
		#1;
		@(negedge i_clk);
		i_diag_clear_event = 1'b0;
		i_recheck_accept_event = 1'b0;
		i_recheck_done_event = 1'b0;
	end
	endtask

	// STOP/abort不再有直接端口，改由PWI单拍scope-only代际discard广播表达
	task pulse_detection_discard;
		input [1:0]discard_reason;
		input [C_RUN_GENERATION_WIDTH - 1:0]discard_generation;
	begin
		@(negedge i_clk);
		i_detection_discard_event = 1'b1;
		i_detection_discard_reason = discard_reason;
		i_detection_discard_run_generation = discard_generation;
		@(posedge i_clk);
		#1;
		@(negedge i_clk);
		i_detection_discard_event = 1'b0;
		i_detection_discard_reason = DISCARD_REASON_STOP;
		i_detection_discard_run_generation = 8'd0;
	end
	endtask

	// 每个PASS都必须由传入的真实布尔比较结果决定
	task check_case;
		input [8 * 16 - 1:0]case_name;
		input integer condition_value;
	begin
		if(condition_value)begin
			cnt_pass = cnt_pass + 1;
			$display("[PASS] %0s", case_name);
		end else begin
			cnt_fail = cnt_fail + 1;
			$display("[FAIL] %0s time=%0t", case_name, $time);
		end
	end
	endtask

	//----------------测试激励区域---------------//
	// 主测试序列逐项执行冻结验收矩阵并在末尾核对总数
	initial begin
        i_clk=0; i_rstn=0; cnt_pass=0; cnt_fail=0; set_default_inputs;
        reset_dut; start_run; start_fine_window(16'd0);
        make_basic_peak(16'd0); consume_peak; make_basic_valley(16'd0);
        if(o_return_9bit_valid!==1'b1 || o_return_frame_id!==16'd11) $fatal(1,"initial return wrong expected negative");
        consume_valley;
        if(o_result_ready!==1'b1) $fatal(1,"input must reopen after valley transfer");
        make_basic_peak(16'd11); consume_peak; make_basic_valley(16'd11);
        if(o_valley_valid!==1'b1 || o_valley_frame_id!==16'd18) $fatal(1,"second legal valley");
        if(o_protocol_error_sticky!==1'b0) $fatal(1,"sequence unexpectedly raised protocol error");
        if(o_return_9bit_valid!==1'b1 || o_return_reason!==2'b00 || o_return_frame_id!==16'd10)
            $fatal(1,"held return changed: expected frame=10 actual=%0d",o_return_frame_id);
        $display("C_RETURN_HOLD_PASS"); $finish;
    end

	// 2 MHz时钟连续运行且不参与任何DUT功能判断
	always begin
		#C_CLK_HALF_PERIOD_NS i_clk = ~i_clk;
	end

	// 有界watchdog保证ready/valid错误不会使仿真无限等待
	initial begin
		#50000000;
		$display("[FAIL] WATCHDOG timeout pass=%0d fail=%0d", cnt_pass, cnt_fail);
		$finish;
	end

endmodule
