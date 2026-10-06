`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company:             Erie
// Engineer:            Erie
//
// Create Date:         2026-08-12
// Design Name:         PPG Precision Window Integration Verification
// Module Name:         tb_ppg_precision_window_integration
// Description:         Self-checking PWI-01 through PWI-05 integration test.
// Simulations:         Vivado xsim 2022.2
// Referrences:         PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
// Dependencies:        ppg_precision_window_integration.v and five real submodules
// Version:             V1.1
// Revision Date:       2026-09-30
// History:             V1.0 - Create file
//                      V1.1 (2026-09-30) - TB maintenance, no RTL change. This TB (V1.0, 2026-08-12) predated
//                      wrapper RTL V1.1 (2026-08-22: removed i_stop_ack_event/i_control_abort_event, added
//                      i_run_generation, the AMI-broadcast i_detection_discard_* group and the independent
//                      i_sample_valid qualifier) and V1.3 (2026-08-23: pure rename i_adc_idle ->
//                      i_precision_takeover_safe), so it no longer elaborated (REGRESSION_BASELINE_20260930.md
//                      section 6.3). Removed the two dead connections, renamed the third, tied i_sample_valid to
//                      1 (every NORMAL transaction this TB drives is a qualified sample, i.e. the behaviour that
//                      existed before the qualifier was added; with 0 no sample ever enters the algorithm
//                      history), and tied i_run_generation, the whole discard group and the two test-injection
//                      inputs to explicit inactive constants (this TB does not exercise generation discard).
//                      The TB-side i_stop_ack_event/i_control_abort_event regs are left in place, now unused.
//                      Result: ALL PWI-01 THROUGH PWI-05 PASS count=5 (xsim and iverilog). Negative control:
//                      the same TB with i_sample_valid tied to 0 fails all five checks (fine/cross/peak/valley
//                      counters stay 0), so the five checks are live, not vacuous.
//////////////////////////////////////////////////////////////////////////////////
// 版权所有:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026-08-12
// 设计名称:           PPG精度窗口集成自检
// 模块名称:           tb_ppg_precision_window_integration
// 模块说明:           通过真实FIR、双消费者fork、动态基线、峰谷检测、精度控制和
//                      AMB调度器闭环覆盖PWI-01至PWI-05。
// 仿真工程:           Vivado xsim 2022.2
// 参考资料:           PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
// 依赖文件:           ppg_precision_window_integration.v及五个真实子模块
// 当前版本:           V1.1
// 修订日期:           2026-09-30
// 修订历史:           V1.0 - 创建文件
//                      V1.1（2026-09-30）- TB维护，不改RTL。本TB（V1.0，2026-08-12）早于wrapper RTL V1.1
//                      （2026-08-22：删除i_stop_ack_event/i_control_abort_event，新增i_run_generation、AMI广播的
//                      i_detection_discard_*组和独立样本资格i_sample_valid）与V1.3（2026-08-23：i_adc_idle纯改名为
//                      i_precision_takeover_safe），因此无法elaborate（REGRESSION_BASELINE_20260930.md第6.3节）。
//                      删除两处已不存在的端口连接，改名第三处；i_sample_valid恒接1（本TB驱动的每笔NORMAL事务都是
//                      合格样本，即该资格端口加入之前的行为；接0则没有任何样本进入算法历史）；i_run_generation、
//                      整个discard组和两个测试注入输入显式接非活动常量（本TB不测代际清空）。TB侧的
//                      i_stop_ack_event/i_control_abort_event寄存器保留但已不再使用。
//                      结果：ALL PWI-01 THROUGH PWI-05 PASS count=5（xsim与iverilog一致）。负向对照：同一TB把
//                      i_sample_valid接0时5条检查全部FAIL（fine/cross/peak/valley计数均为0），说明这5条检查是真实
//                      执行的，不是空过。
//////////////////////////////////////////////////////////////////////////////////

module tb_ppg_precision_window_integration;

//===================<参数定义>===================//

// 仿真保持合同默认字段宽度，并使用10 ns时钟周期缩短执行时间。
localparam integer C_DATA_WIDTH = 24;             // 统一粗PPG和FIR数据宽度
localparam integer C_FRAME_ID_WIDTH = 16;         // 物理400 Hz帧号宽度
localparam integer C_SAMPLE_INDEX_WIDTH = 16;     // ADC事务全局序号宽度
localparam integer C_SLOPE_WIDTH = 32;            // signed Q16活动斜率宽度
localparam integer C_CLK_PERIOD = 10;             // 仿真时钟周期纳秒数
localparam [1:0]IDAC_MODE_TRACK = 2'b10;          // 周期AMB重检允许模式
localparam [1:0]FRAME_TYPE_NORMAL = 2'b10;        // 正式NORMAL事务协议编码

//===================<寄存器信号>===================//

// 全局、生命周期和ACTIVE配置输入由测试流程集中驱动。
reg i_clk;                                       // 仿真2 MHz逻辑时钟替身
reg i_rstn;                                      // DUT低有效异步复位
reg i_run_enable;                                // RUN生命周期电平资格
reg i_start_ack_event;                           // 新RUN开始单拍
reg i_stop_ack_event;                            // STOP确认单拍
reg i_control_abort_event;                       // 阻断故障撤销单拍
reg i_diag_clear_event;                          // sticky诊断清除单拍
reg i_active_config_valid;                       // ACTIVE配置整体合法资格
reg i_run_profile;                               // NORMAL或CHARACTERIZATION选择
reg i_initial_precision;                         // 表征模式初始精度
reg i_normal_measurement_active;                 // 正式NORMAL测量资格
reg i_slope_mode;                                // 固定或自适应斜率选择
reg signed [31:0]i_fixed_slope_q16;              // 动态基线固定负斜率
reg [15:0]i_alpha_q15;                           // 基础斜率幅度比例
reg [15:0]i_beta_q15;                            // 活动斜率平滑比例
reg [15:0]i_timing_adjust_ratio_q15;             // 相交时刻修正比例
reg signed [31:0]i_slope_min_q16;                // 最负斜率边界
reg signed [31:0]i_slope_max_q16;                // 最接近零斜率边界
reg signed [31:0]i_baseline_delta_q16;           // 波峰锚点基线偏置
reg [31:0]i_cross_hysteresis_q16;                // 向上相交迟滞
reg [15:0]i_lead_min_frames;                     // 提前量窗口下界
reg [15:0]i_lead_max_frames;                     // 提前量窗口上界
reg [3:0]i_cross_confirm_count;                  // 相交连续确认点数
reg [3:0]i_no_cross_limit;                       // 无相交重新获取阈值
reg [3:0]i_peak_confirm_count;                   // 波峰连续下降确认点数
reg [3:0]i_valley_confirm_count;                 // 波谷连续上升确认点数
reg [23:0]i_direction_deadband;                  // 方向分类死区
reg [23:0]i_min_peak_valley_amplitude;           // 合格峰谷最小幅度
reg [15:0]i_min_peak_to_valley_frames;           // 波峰至波谷最小帧差
reg [15:0]i_min_peak_to_peak_frames;             // 相邻波峰最小帧差
reg [15:0]i_max_fine_window_frames;              // fine窗口最大持续帧数
reg [15:0]i_max_reacquire_frames;                // 重新获取最大持续帧数
reg i_peak_valley_config_valid;                  // 峰谷配置正式有效资格
reg [1:0]i_idac_mode;                            // IDAC工作模式编码
reg i_amb_enable;                                // 周期AMB重检使能
reg i_dcs_enable;                                // 两色DC重验证使能
reg [15:0]i_amb_recheck_interval_frames;         // AMB重检完整帧间隔

// NORMAL粗结果输入保存当前事务值和完整中心元数据。
reg i_normal_result_valid;                       // 上游保持型NORMAL事务valid
reg signed [23:0]i_coarse_ppg_value;             // DC恢复后的统一粗PPG值
reg i_coarse_valid;                              // 当前事务具有粗结果
reg i_coarse_recovery_calibrated;                // Stage1和DC恢复正式有效
reg i_stage1_saturation_low;                     // Stage1负向饱和诊断
reg i_stage1_saturation_high;                    // Stage1正向饱和诊断
reg i_coarse_saturation_low;                     // 粗恢复负向饱和诊断
reg i_coarse_saturation_high;                    // 粗恢复正向饱和诊断
reg [7:0]i_config_epoch;                         // 当前事务ACTIVE版本
reg [7:0]i_coef_epoch;                           // 当前事务Stage1版本
reg [7:0]i_dc_recovery_coef_epoch;               // 当前事务DC恢复版本
reg i_precision_mode;                            // 当前事务开始时精度快照
reg [15:0]i_frame_id;                            // 当前物理帧号
reg [15:0]i_sample_index;                        // 当前ADC事务序号
reg i_color_ir;                                  // 当前事务颜色身份
reg [1:0]i_frame_type;                           // 当前事务NORMAL编码
reg [7:0]i_amb_code_snapshot;                    // 当前AMB committed码
reg [7:0]i_dc_code_snapshot;                     // 当前颜色DC committed码
reg [3:0]i_amb_code_epoch;                       // 当前AMB码版本
reg [3:0]i_dc_code_epoch;                        // 当前颜色DC码版本

// 安全边界、排空和IDAC协作输入驱动真实精度和重检控制路径。
reg i_frame_safe_boundary;                       // 下一帧安全提交边界单拍
reg [15:0]i_safe_frame_id;                       // 即将启动帧的真实编号
reg i_adc_idle;                                  // ADC和结果流水排空资格
reg i_analog_safe;                               // 模拟精度提交安全资格
reg i_normal_fork_idle;                          // 上游NORMAL fork排空资格
reg i_idac_idle;                                 // IDAC控制器排空资格
reg i_startup_search_complete;                   // 启动搜索完成资格
reg i_normal_frame_complete_event;               // 完整NORMAL帧结束单拍
reg i_calibration_frame_complete_event;          // 当前校准帧结束单拍
reg i_amb_sample_request;                        // IDAC请求AMB_CAL样本
reg i_amb_sequence_done;                         // AMB检查或搜索成功单拍
reg i_amb_sequence_failed;                       // AMB搜索失败单拍
reg i_dcs_revalidate_request;                    // IDAC请求两色DC重验证
reg i_dcs_sample_request;                        // IDAC请求当前DCS_CAL样本
reg i_dcs_sample_color_ir;                       // 当前DCS_CAL颜色身份
reg i_dcs_revalidate_done;                       // 两色DC重验证成功单拍
reg i_dcs_revalidate_failed;                     // 任一路DC重验证失败单拍
reg i_amb_sample_accepted_event;                 // 匹配AMB结果已经消费
reg i_dcs_sample_accepted_event;                 // 匹配DCS结果已经消费
reg i_calibration_sample_ready;                  // 模拟调度器校准采样ready

// 自检计数和波形生成状态用于真实结果比较。
integer cnt_pass;                                // PWI真实通过项累计
integer cnt_fail;                                // PWI真实失败项累计
integer cnt_watchdog;                            // 有界等待保护计数
integer cnt_red_frame;                           // RED输入物理帧计数
integer cnt_ir_frame;                            // IR输入物理帧计数
integer cnt_sample_global;                       // 全局ADC事务计数
integer cnt_fine_start_event;                    // 真实进入fine提交事件次数
integer cnt_return_event;                        // 真实返回9-bit提交事件次数
integer cnt_recheck_accept_event;                // AMB安全接管事件次数
integer cnt_recheck_done_event;                  // 三阶段重检成功次数
integer cnt_baseline_fork_transfer;              // 动态基线分支真实消费次数
integer cnt_peak_valley_fork_transfer;           // 峰谷分支真实消费次数
integer cnt_peak_transfer;                       // 可靠波峰真实握手次数
integer cnt_valley_transfer;                     // 可靠波谷真实握手次数
integer cnt_return_transfer;                     // 返回请求真实握手次数
integer cnt_cross_before_tail;                   // 退出尾部前cross次数快照
integer idx_sample;                              // 定向波形循环索引
reg flag_case_ok;                                // 当前PWI场景组合判定结果
reg signed [31:0]reg_slope_before_recheck;       // 重检接管前活动斜率快照

//===================<线网信号>===================//

// Wrapper全部合同输出均由TB显式连接并参与检查或波形诊断。
wire o_normal_result_ready;                      // FIR真实输入接收资格
wire o_amb_sequence_start;                       // AMB检查启动事件
wire o_dcs_revalidate_accept;                    // 两色DC重验证接受事件
wire o_calibration_sample_valid;                 // 保持型校准采样请求
wire [1:0]o_calibration_frame_type;              // 当前校准帧类型
wire o_calibration_color_ir;                     // 当前校准颜色身份
wire o_calibration_precision_mode;               // 校准固定SAR9精度
wire o_calibration_frame_start;                  // 当前校准帧开始事件
wire [1:0]o_calibration_stage;                   // 当前三阶段状态编码
wire o_active_precision_mode;                    // 唯一committed采集精度
wire o_fine_window_active;                       // 正式15-bit窗口状态
wire o_fine_window_start_event;                  // 真实进入fine提交事件
wire [15:0]o_fine_window_start_frame_id;         // 第一笔正式15-bit帧号
wire o_precision_15_to_9_event;                  // 真实返回9-bit提交事件
wire [15:0]o_precision_15_to_9_frame_id;         // 第一笔恢复9-bit帧号
wire o_reacquire_request_event;                  // 异常返回重新获取事件
wire o_switch_hold_new_transaction;              // 停止新ADC事务要求
wire o_mode_fault_event;                         // 精度控制阻断故障事件
wire [15:0]o_normal_frame_count;                 // AMB周期NORMAL帧计数
wire o_amb_recheck_pending;                      // 等待下一次15到9状态
wire o_amb_recheck_accept;                       // 真实安全接管事件
wire o_amb_recheck_busy;                         // 重检和预热占用状态
wire o_normal_output_inhibit;                    // 正式输出禁止状态
wire o_recheck_sequence_done;                    // 三阶段重检整体成功事件
wire o_recheck_sequence_failed;                  // 任一重检阶段失败事件
wire o_fir_history_full_r;                       // RED FIR历史已满
wire o_fir_history_full_ir;                      // IR FIR历史已满
wire o_fir_idle;                                 // FIR内部排空状态
wire o_detection_fork_idle;                      // 检测fork排空状态
wire o_detector_idle;                            // 峰谷检测器允许接管状态
wire o_controller_idle;                          // 精度控制器排空状态
wire o_scheduler_idle;                           // AMB调度器排空状态
wire o_cross_pending;                            // 动态基线保持cross请求
wire o_peak_pending;                             // 峰谷检测器保持peak事件
wire o_valley_pending;                           // 峰谷检测器保持valley事件
wire o_return_pending;                           // 峰谷检测器保持return请求
wire o_baseline_valid;                           // 当前动态基线有效资格
wire o_reacquire_active;                         // 动态基线重新获取状态
wire o_detector_fine_window_active;              // 峰谷检测器fine状态
wire o_switch_pending;                           // 精度请求等待安全提交
wire o_switch_target_precision;                  // 当前pending目标精度
wire signed [31:0]o_slope_current_q16;           // 当前活动斜率
wire o_baseline_protocol_error_sticky;           // 动态基线协议异常历史
wire o_fine_window_timeout_sticky;               // 峰谷fine窗口超时历史
wire o_reacquire_timeout_sticky;                 // 峰谷重新获取超时历史
wire o_peak_valley_protocol_error_sticky;        // 峰谷协议异常历史
wire o_switch_timeout_sticky;                    // 精度提交超时历史
wire o_precision_protocol_error_sticky;          // 精度控制协议异常历史

//===================<时钟生成>===================//

// 固定翻转时钟驱动全部单时钟域RTL。
always #(C_CLK_PERIOD / 2) i_clk = ~i_clk;        // 生成周期稳定的仿真时钟

//===================<监测逻辑>===================//

// 统计真实控制事件和内部握手，证明fork及跨模块事务没有丢失或重复消费。
always@(posedge i_clk or negedge i_rstn)begin
	if(i_rstn == 1'b0)begin
		cnt_fine_start_event <= 0;          // 复位清除fine提交次数
		cnt_return_event <= 0;              // 复位清除返回9-bit次数
		cnt_recheck_accept_event <= 0;      // 复位清除重检接管次数
		cnt_recheck_done_event <= 0;        // 复位清除重检完成次数
		cnt_baseline_fork_transfer <= 0;    // 复位清除动态基线消费次数
		cnt_peak_valley_fork_transfer <= 0; // 复位清除峰谷分支消费次数
		cnt_peak_transfer <= 0;             // 复位清除波峰握手次数
		cnt_valley_transfer <= 0;           // 复位清除波谷握手次数
		cnt_return_transfer <= 0;           // 复位清除返回请求握手次数
	end else begin
		if(o_fine_window_start_event)cnt_fine_start_event <= cnt_fine_start_event + 1; // 记录真实fine提交事件
		if(o_precision_15_to_9_event)cnt_return_event <= cnt_return_event + 1; // 记录真实返回9-bit事件
		if(o_amb_recheck_accept)cnt_recheck_accept_event <= cnt_recheck_accept_event + 1; // 记录真实重检接管
		if(o_recheck_sequence_done)cnt_recheck_done_event <= cnt_recheck_done_event + 1; // 记录三阶段成功事件
		if(dut.flag_baseline_transfer)cnt_baseline_fork_transfer <= cnt_baseline_fork_transfer + 1; // 记录动态基线分支唯一消费
		if(dut.flag_peak_valley_transfer)cnt_peak_valley_fork_transfer <= cnt_peak_valley_fork_transfer + 1; // 记录峰谷分支唯一消费
		if(dut.peak_pending_o && dut.flag_peak_ready)cnt_peak_transfer <= cnt_peak_transfer + 1; // 记录可靠波峰实际握手
		if(dut.valley_pending_o && dut.flag_valley_ready)cnt_valley_transfer <= cnt_valley_transfer + 1; // 记录可靠波谷实际握手
		if(dut.return_pending_o && dut.flag_return_9bit_ready)cnt_return_transfer <= cnt_return_transfer + 1; // 记录返回请求实际握手
	end
end

//===================<测试任务>===================//

// 初始化所有DUT输入，避免X传播掩盖协议错误。
task initialize_inputs;
begin
	i_rstn = 1'b0;                          // 上电保持异步复位
	i_run_enable = 1'b0;                    // 上电尚未进入RUN
	i_start_ack_event = 1'b0;               // 清除START单拍
	i_stop_ack_event = 1'b0;                // 清除STOP单拍
	i_control_abort_event = 1'b0;           // 清除阻断故障单拍
	i_diag_clear_event = 1'b0;              // 清除诊断清除单拍
	i_active_config_valid = 1'b1;           // 默认ACTIVE配置合法
	i_run_profile = 1'b0;                   // 默认NORMAL_PPG模式
	i_initial_precision = 1'b0;             // NORMAL启动固定采用9-bit
	i_normal_measurement_active = 1'b1;     // 默认允许正式NORMAL测量
	i_slope_mode = 1'b0;                    // 定向测试采用固定斜率
	i_fixed_slope_q16 = -32'sd65536;        // 基线每帧下降一个统一码
	i_alpha_q15 = 16'd6554;                 // 保留合同默认20%比例
	i_beta_q15 = 16'd8192;                  // 保留合同默认25%平滑
	i_timing_adjust_ratio_q15 = 16'd1024;   // 使用小比例时刻调整步长
	i_slope_min_q16 = -32'sd16777216;       // 允许充分负向斜率范围
	i_slope_max_q16 = -32'sd1;              // 最接近零边界保持负值
	i_baseline_delta_q16 = 32'sd0;          // 波峰锚点处基线不额外偏移
	i_cross_hysteresis_q16 = 32'd0;         // 定向测试关闭相交迟滞
	i_lead_min_frames = 16'd16;             // 满足10点群延时和两点相交确认保护
	i_lead_max_frames = 16'd200;            // 覆盖定向波形周期
	i_cross_confirm_count = 4'd2;           // 首次越过加一个连续上方样本形成cross
	i_no_cross_limit = 4'd15;               // 禁止测试期间意外重新获取
	i_peak_confirm_count = 4'd1;            // 首个明确下降点确认波峰
	i_valley_confirm_count = 4'd1;          // 首个明确上升点确认波谷
	i_direction_deadband = 24'd0;           // 定向大幅波形不需要死区
	i_min_peak_valley_amplitude = 24'd10;   // 排除微小噪声峰谷对
	i_min_peak_to_valley_frames = 16'd1;    // 允许紧凑定向波形
	i_min_peak_to_peak_frames = 16'd1;      // 允许紧凑连续周期
	i_max_fine_window_frames = 16'd300;     // 避免定向fine波形超时
	i_max_reacquire_frames = 16'd300;       // 避免启动重新获取超时
	i_peak_valley_config_valid = 1'b1;      // 峰谷配置正式有效
	i_idac_mode = IDAC_MODE_TRACK;          // 允许周期AMB重检
	i_amb_enable = 1'b1;                    // 启用AMB重检
	i_dcs_enable = 1'b1;                    // 启用两色DC重验证
	i_amb_recheck_interval_frames = 16'd0;  // 默认关闭周期重检
	i_normal_result_valid = 1'b0;           // 上电没有NORMAL事务
	i_coarse_ppg_value = 24'sd0;            // 初始化粗PPG数据
	i_coarse_valid = 1'b1;                  // 默认每笔事务具有粗结果
	i_coarse_recovery_calibrated = 1'b1;    // 默认校准资格完整
	i_stage1_saturation_low = 1'b0;         // 默认没有Stage1负饱和
	i_stage1_saturation_high = 1'b0;        // 默认没有Stage1正饱和
	i_coarse_saturation_low = 1'b0;         // 默认没有粗恢复负饱和
	i_coarse_saturation_high = 1'b0;        // 默认没有粗恢复正饱和
	i_config_epoch = 8'h11;                 // 使用稳定ACTIVE版本
	i_coef_epoch = 8'h22;                   // 使用稳定Stage1版本
	i_dc_recovery_coef_epoch = 8'h33;       // 使用稳定DC恢复版本
	i_precision_mode = 1'b0;                // 初始事务采用9-bit
	i_frame_id = 16'd0;                     // 初始化物理帧号
	i_sample_index = 16'd0;                 // 初始化全局事务号
	i_color_ir = 1'b0;                      // 默认选择RED
	i_frame_type = FRAME_TYPE_NORMAL;       // 固定NORMAL帧类型
	i_amb_code_snapshot = 8'h40;            // 使用稳定AMB码快照
	i_dc_code_snapshot = 8'h50;             // 使用稳定DC码快照
	i_amb_code_epoch = 4'h1;                // 使用稳定AMB码版本
	i_dc_code_epoch = 4'h2;                 // 使用稳定DC码版本
	i_frame_safe_boundary = 1'b0;           // 默认不处于精度提交边界
	i_safe_frame_id = 16'd0;                // 初始化安全帧编号
	i_adc_idle = 1'b1;                      // 默认ADC和结果流水排空
	i_analog_safe = 1'b1;                   // 默认模拟相位允许提交
	i_normal_fork_idle = 1'b1;              // 默认上游NORMAL fork排空
	i_idac_idle = 1'b1;                     // 默认IDAC控制器排空
	i_startup_search_complete = 1'b1;       // 默认启动搜索已完成
	i_normal_frame_complete_event = 1'b0;   // 清除NORMAL帧完成单拍
	i_calibration_frame_complete_event = 1'b0; // 清除校准帧完成单拍
	i_amb_sample_request = 1'b0;            // 清除AMB样本请求
	i_amb_sequence_done = 1'b0;             // 清除AMB成功单拍
	i_amb_sequence_failed = 1'b0;           // 清除AMB失败单拍
	i_dcs_revalidate_request = 1'b0;        // 清除DC重验证请求
	i_dcs_sample_request = 1'b0;            // 清除DCS样本请求
	i_dcs_sample_color_ir = 1'b0;           // 默认选择DC_R
	i_dcs_revalidate_done = 1'b0;           // 清除DC整体成功单拍
	i_dcs_revalidate_failed = 1'b0;         // 清除DC失败单拍
	i_amb_sample_accepted_event = 1'b0;     // 清除AMB结果消费单拍
	i_dcs_sample_accepted_event = 1'b0;     // 清除DCS结果消费单拍
	i_calibration_sample_ready = 1'b0;      // 默认校准采样反压
	cnt_red_frame = 0;                      // 清除RED输入帧计数
	cnt_ir_frame = 0;                       // 清除IR输入帧计数
	cnt_sample_global = 0;                  // 清除全局事务序号
end
endtask

// 异步复位覆盖多个时钟沿并等待全部输出回到稳定初值。
task reset_dut;
begin
	@(negedge i_clk);                       // 在下降沿开始复位避免竞争
	i_rstn = 1'b0;                          // 异步清除全部子模块状态
	repeat(3)@(negedge i_clk);              // 保证复位覆盖有效时钟沿
	i_rstn = 1'b1;                          // 在下降沿释放低有效复位
	repeat(3)@(negedge i_clk);              // 等待组合ready和idle稳定
end
endtask

// 新RUN单拍并联初始化五个真实子模块。
task start_run;
begin
	@(negedge i_clk);                       // 对齐下一个有效上升沿
	i_run_enable = 1'b1;                    // 建立RUN持续资格
	i_start_ack_event = 1'b1;               // 广播新RUN初始化事件
	@(negedge i_clk);                       // 单拍跨越一个上升沿
	i_start_ack_event = 1'b0;               // 清除START事件
end
endtask

// 发送一笔RED NORMAL粗结果并严格等待FIR ready完成唯一握手。
task send_red_sample;
	input integer value_code;               // 当前RED统一粗PPG码
	input precision_code;                   // 当前事务精度快照
begin
	@(negedge i_clk);                       // 在下降沿准备稳定载荷
	cnt_watchdog = 0;                       // 清除ready等待保护计数
	while(o_normal_result_ready !== 1'b1 && cnt_watchdog < 2000)begin
		@(negedge i_clk);                   // 等待真实周期MAC输入空闲
		cnt_watchdog = cnt_watchdog + 1;   // 累计有界等待周期
	end
	if(o_normal_result_ready !== 1'b1)begin
		$display("FAIL NORMAL RED ready timeout"); // 报告FIR入口永久反压
		cnt_fail = cnt_fail + 1;           // 将超时纳入最终失败累计
	end
	i_coarse_ppg_value = value_code;        // 驱动当前粗PPG数据
	i_precision_mode = precision_code;      // 绑定事务开始时真实精度
	i_frame_id = cnt_red_frame[15:0];       // 使用连续RED物理帧号
	i_sample_index = cnt_sample_global[15:0]; // 使用全局递增事务号
	i_color_ir = 1'b0;                      // 选择RED FIR历史
	i_normal_result_valid = 1'b1;           // 建立保持型上游valid
	@(posedge i_clk);                       // 当前沿完成一次真实握手
	#1;                                     // 等待非阻塞赋值提交
	@(negedge i_clk);                       // 在安全边沿释放valid
	i_normal_result_valid = 1'b0;           // 结束本笔事务所有权
	cnt_red_frame = cnt_red_frame + 1;      // 下一RED样本使用相邻帧号
	cnt_sample_global = cnt_sample_global + 1; // 推进全局事务序号
end
endtask

// 发送一笔IR NORMAL粗结果并维持独立颜色帧计数。
task send_ir_sample;
	input integer value_code;               // 当前IR统一粗PPG码
	input precision_code;                   // 当前事务精度快照
begin
	@(negedge i_clk);                       // 在下降沿准备稳定载荷
	cnt_watchdog = 0;                       // 清除ready等待保护计数
	while(o_normal_result_ready !== 1'b1 && cnt_watchdog < 2000)begin
		@(negedge i_clk);                   // 等待真实FIR入口ready
		cnt_watchdog = cnt_watchdog + 1;   // 累计有界等待周期
	end
	if(o_normal_result_ready !== 1'b1)begin
		$display("FAIL NORMAL IR ready timeout"); // 报告IR入口永久反压
		cnt_fail = cnt_fail + 1;           // 将超时纳入最终失败累计
	end
	i_coarse_ppg_value = value_code;        // 驱动当前IR粗PPG值
	i_precision_mode = precision_code;      // 绑定当前真实精度
	i_frame_id = cnt_ir_frame[15:0];        // 使用IR颜色独立帧编号
	i_sample_index = cnt_sample_global[15:0]; // 使用全局递增事务号
	i_color_ir = 1'b1;                      // 选择IR FIR历史
	i_normal_result_valid = 1'b1;           // 建立保持型上游valid
	@(posedge i_clk);                       // 当前沿完成唯一输入握手
	#1;                                     // 等待DUT时序更新
	@(negedge i_clk);                       // 在下降沿释放事务
	i_normal_result_valid = 1'b0;           // 清除当前valid
	cnt_ir_frame = cnt_ir_frame + 1;        // 推进IR物理帧编号
	cnt_sample_global = cnt_sample_global + 1; // 推进全局事务序号
end
endtask

// 等待FIR、检测fork和两个消费者完成当前全部事务。
task wait_detection_idle;
begin
	cnt_watchdog = 0;                       // 清除排空等待保护计数
	while((o_fir_idle !== 1'b1 || o_detection_fork_idle !== 1'b1) && cnt_watchdog < 4000)begin
		@(negedge i_clk);                   // 等待MAC输出和分支握手排空
		cnt_watchdog = cnt_watchdog + 1;   // 累计有界等待周期
	end
	if(cnt_watchdog >= 4000)begin
		$display("FAIL detection pipeline idle timeout"); // 报告检测链永久占用
		cnt_fail = cnt_fail + 1;           // 将排空失败纳入最终结果
	end
end
endtask

// 在一个真实安全边界提交精度切换并绑定下一物理帧号。
task pulse_safe_boundary;
	input [15:0]safe_frame;                 // 即将采用新精度的帧号
begin
	@(negedge i_clk);                       // 在下降沿准备边界信息
	i_safe_frame_id = safe_frame;           // 绑定下一帧真实编号
	i_frame_safe_boundary = 1'b1;           // 拉高一个完整时钟周期
	@(posedge i_clk);                       // 当前沿执行原子精度提交
	#1;                                     // 允许观察提交单拍输出
	@(negedge i_clk);                       // 边界单拍结束
	i_frame_safe_boundary = 1'b0;           // 恢复普通非边界状态
end
endtask

// 产生一个完整NORMAL帧完成事件以推进AMB周期计数。
task pulse_normal_frame_complete;
begin
	@(negedge i_clk);                       // 对齐调度器计数沿
	i_normal_frame_complete_event = 1'b1;   // 声明一帧NORMAL已经完整结束
	@(negedge i_clk);                       // 单拍跨越一个有效上升沿
	i_normal_frame_complete_event = 1'b0;   // 清除完成事件
end
endtask

// 产生校准物理帧结束单拍，驱动真实三阶段scheduler前进。
task pulse_calibration_frame_complete;
begin
	@(negedge i_clk);                       // 对齐scheduler状态更新沿
	i_calibration_frame_complete_event = 1'b1; // 声明当前校准帧物理结束
	@(negedge i_clk);                       // 单拍跨越一个有效上升沿
	i_calibration_frame_complete_event = 1'b0; // 清除校准帧完成事件
end
endtask

// 用长平台和大幅单调段形成一个可靠9-bit峰谷周期及下一次向上相交。
task build_9bit_cross_request;
begin
	for(idx_sample = 0; idx_sample < 24; idx_sample = idx_sample + 1)begin
		send_red_sample(100, 1'b0);          // 预热FIR并建立低平台
	end
	for(idx_sample = 0; idx_sample < 24; idx_sample = idx_sample + 1)begin
		send_red_sample(100 + idx_sample * 100, 1'b0); // 形成平滑上升至码值波峰
	end
	for(idx_sample = 0; idx_sample < 30; idx_sample = idx_sample + 1)begin
		send_red_sample(2500 - idx_sample * 100, 1'b0); // 形成波峰后的持续下降段
	end
	for(idx_sample = 0; idx_sample < 40 && o_switch_pending !== 1'b1; idx_sample = idx_sample + 1)begin
		send_red_sample(-400 + idx_sample * 100, 1'b0); // 从波谷持续上升直至穿越动态基线
	end
	wait_detection_idle;                   // 等待最后一笔相交证据完成消费
end
endtask

// 在正式fine中心建立波峰、波谷和正常返回9-bit请求。
task build_fine_peak_valley_return;
begin
	for(idx_sample = 0; idx_sample < 12; idx_sample = idx_sample + 1)begin
		send_red_sample(300 + idx_sample * 150, 1'b1); // 建立正式15-bit中心上升段
	end
	for(idx_sample = 0; idx_sample < 24; idx_sample = idx_sample + 1)begin
		send_red_sample(2100 - idx_sample * 100, 1'b1); // 越过fine码值波峰并下降
	end
	for(idx_sample = 0; idx_sample < 24 && o_switch_pending !== 1'b1; idx_sample = idx_sample + 1)begin
		send_red_sample(-300 + idx_sample * 120, 1'b1); // 越过运行最小值后连续上升
	end
	wait_detection_idle;                   // 等待波谷和return请求完成内部握手
end
endtask

// 完成真实AMB、DC_R和DC_IR三帧成功序列。
task complete_recheck_sequence;
begin
	@(negedge i_clk);                       // 等待scheduler进入AMB阶段
	i_amb_sample_request = 1'b1;            // IDAC请求第一笔AMB_CAL样本
	i_calibration_sample_ready = 1'b1;      // 模拟调度器立即接受校准请求
	@(negedge i_clk);                       // 完成一次校准采样握手
	i_calibration_sample_ready = 1'b0;      // 撤销模拟调度器ready
	i_amb_sample_accepted_event = 1'b1;     // 匹配AMB数字结果完成消费
	@(negedge i_clk);                       // 释放在途AMB样本所有权
	i_amb_sample_accepted_event = 1'b0;     // 清除AMB结果消费单拍
	i_amb_sample_request = 1'b0;            // IDAC撤销AMB样本请求
	pulse_calibration_frame_complete;       // 声明AMB物理帧已经结束
	@(negedge i_clk);                       // 对齐AMB搜索成功事件
	i_amb_sequence_done = 1'b1;             // 声明AMB检查或搜索成功
	@(negedge i_clk);                       // 单拍跨越scheduler上升沿
	i_amb_sequence_done = 1'b0;             // 清除AMB成功事件
	i_dcs_revalidate_request = 1'b1;        // IDAC请求固定两色DC重验证
	@(negedge i_clk);                       // Scheduler接受DC_R阶段
	i_dcs_revalidate_request = 1'b0;        // 清除DC重验证入口请求
	i_dcs_sample_request = 1'b1;            // 请求DC_R校准样本
	i_dcs_sample_color_ir = 1'b0;           // 当前选择红光DC
	i_calibration_sample_ready = 1'b1;      // 模拟调度器接受DC_R请求
	@(negedge i_clk);                       // 完成DC_R采样握手
	i_calibration_sample_ready = 1'b0;      // 撤销采样ready
	i_dcs_sample_accepted_event = 1'b1;     // 匹配DC_R结果完成消费
	@(negedge i_clk);                       // 释放DC_R在途所有权
	i_dcs_sample_accepted_event = 1'b0;     // 清除DCS结果消费单拍
	i_dcs_sample_color_ir = 1'b1;           // IDAC转为请求DC_IR
	pulse_calibration_frame_complete;       // 声明DC_R物理帧结束
	i_calibration_sample_ready = 1'b1;      // 允许DC_IR校准请求握手
	@(negedge i_clk);                       // 完成DC_IR采样握手
	i_calibration_sample_ready = 1'b0;      // 撤销采样ready
	i_dcs_sample_accepted_event = 1'b1;     // 匹配DC_IR结果完成消费
	@(negedge i_clk);                       // 释放DC_IR在途所有权
	i_dcs_sample_accepted_event = 1'b0;     // 清除DCS结果消费单拍
	i_dcs_sample_request = 1'b0;            // 清除DCS样本请求
	i_dcs_revalidate_done = 1'b1;           // 声明两色DC数字重验证成功
	@(negedge i_clk);                       // 保存数字成功事实
	i_dcs_revalidate_done = 1'b0;           // 清除DC整体成功事件
	pulse_calibration_frame_complete;       // 声明最后一个DC_IR物理帧结束
end
endtask

// 统一输出每个PWI用例的真实比较结果。
task check_case;
	input [8 * 16 - 1:0]case_name;          // 固定长度PWI场景名称
	input condition_value;                  // 当前真实比较布尔结果
begin
	if(condition_value === 1'b1)begin
		cnt_pass = cnt_pass + 1;             // 只有真实比较成立才累计PASS
		$display("PASS %0s", case_name);    // 输出通过场景名称
	end else begin
		cnt_fail = cnt_fail + 1;             // 任一比较失败累计到最终结果
		$display("FAIL %0s time=%0t mode=%0b fine=%0b cross=%0b peak=%0b valley=%0b return=%0b recheck=%0b", case_name, $time, o_active_precision_mode, o_fine_window_active, o_cross_pending, o_peak_pending, o_valley_pending, o_return_pending, o_amb_recheck_busy); // 输出关键闭环状态
	end
end
endtask

//===================<模块例化>===================//

// 例化唯一集成wrapper，五个真实子模块只能通过该层连接参与测试。
ppg_precision_window_integration dut(
	.i_clk(i_clk),                              // 连接仿真工作时钟
	.i_rstn(i_rstn),                            // 连接低有效异步复位
	.i_run_enable(i_run_enable),                // 连接RUN生命周期状态
	.i_start_ack_event(i_start_ack_event),      // 连接新RUN开始事件
	// V1.1：RTL V1.1已删除wrapper的i_stop_ack_event/i_control_abort_event，改由AMI代际discard广播清空；
	// 本TB不测清空路径，以下新增端口全部显式接非活动常量，避免悬空X
	.i_run_generation(8'd0),                    // V1.1:固定RUN代际
	.i_detection_discard_event(1'b0),           // V1.1:无代际清空事件
	.i_detection_discard_identity_valid(1'b0),  // V1.1:清空身份不可信(无清空)
	.i_detection_discard_reason(2'b00),         // V1.1:清空原因占位
	.i_detection_discard_run_generation(8'd0),  // V1.1:清空目标代际占位
	.i_detection_discard_frame_id(16'd0),       // V1.1:清空帧号占位
	.i_detection_discard_sample_index(16'd0),   // V1.1:清空序号占位
	.i_detection_discard_color_ir(1'b0),        // V1.1:清空颜色占位
	.i_detection_discard_frame_type(2'b00),     // V1.1:清空帧类型占位
	.i_detection_discard_precision(1'b0),       // V1.1:清空精度占位
	.i_detection_discard_sample_valid(1'b0),    // V1.1:清空样本资格占位
	.i_detection_discard_config_epoch(8'd0),    // V1.1:清空ACTIVE版本占位
	.i_detection_discard_coef_epoch(8'd0),      // V1.1:清空Stage1版本占位
	.i_detection_discard_dc_recovery_epoch(8'd0), // V1.1:清空DC恢复版本占位
	.i_detection_discard_amb_code_epoch(4'd0),  // V1.1:清空AMB码版本占位
	.i_detection_discard_dc_code_epoch(4'd0),   // V1.1:清空DC码版本占位
	.i_test_inject_enable(1'b0),                // V1.1:生产配置关闭验证注入
	.i_test_calibration_loss_inject_valid(1'b0), // V1.1:无calibration-loss注入
	.i_diag_clear_event(i_diag_clear_event),    // 连接诊断清除事件
	.i_active_config_valid(i_active_config_valid), // 连接ACTIVE整体资格
	.i_run_profile(i_run_profile),              // 连接RUN profile
	.i_initial_precision(i_initial_precision),  // 连接初始精度选择
	.i_normal_measurement_active(i_normal_measurement_active), // 连接NORMAL测量资格
	.i_slope_mode(i_slope_mode),                // 连接动态斜率模式
	.i_fixed_slope_q16(i_fixed_slope_q16),      // 连接固定负斜率
	.i_alpha_q15(i_alpha_q15),                  // 连接基础斜率比例
	.i_beta_q15(i_beta_q15),                    // 连接斜率平滑比例
	.i_timing_adjust_ratio_q15(i_timing_adjust_ratio_q15), // 连接时刻调整比例
	.i_slope_min_q16(i_slope_min_q16),          // 连接最负斜率边界
	.i_slope_max_q16(i_slope_max_q16),          // 连接近零斜率边界
	.i_baseline_delta_q16(i_baseline_delta_q16), // 连接锚点基线偏置
	.i_cross_hysteresis_q16(i_cross_hysteresis_q16), // 连接相交迟滞
	.i_lead_min_frames(i_lead_min_frames),      // 连接提前量下界
	.i_lead_max_frames(i_lead_max_frames),      // 连接提前量上界
	.i_cross_confirm_count(i_cross_confirm_count), // 连接相交确认数
	.i_no_cross_limit(i_no_cross_limit),        // 连接无相交限制
	.i_peak_confirm_count(i_peak_confirm_count), // 连接波峰确认数
	.i_valley_confirm_count(i_valley_confirm_count), // 连接波谷确认数
	.i_direction_deadband(i_direction_deadband), // 连接方向死区
	.i_min_peak_valley_amplitude(i_min_peak_valley_amplitude), // 连接峰谷最小幅度
	.i_min_peak_to_valley_frames(i_min_peak_to_valley_frames), // 连接峰谷最小帧差
	.i_min_peak_to_peak_frames(i_min_peak_to_peak_frames), // 连接峰峰最小帧差
	.i_max_fine_window_frames(i_max_fine_window_frames), // 连接fine窗口上限
	.i_max_reacquire_frames(i_max_reacquire_frames), // 连接重获窗口上限
	.i_peak_valley_config_valid(i_peak_valley_config_valid), // 连接峰谷配置资格
	.i_idac_mode(i_idac_mode),                  // 连接IDAC工作模式
	.i_amb_enable(i_amb_enable),                // 连接AMB重检使能
	.i_dcs_enable(i_dcs_enable),                // 连接DC重验证使能
	.i_amb_recheck_interval_frames(i_amb_recheck_interval_frames), // 连接重检帧间隔
	.i_normal_result_valid(i_normal_result_valid), // 连接NORMAL事务valid
	.i_sample_valid(1'b1),                      // V1.1:每笔事务都是合格样本，等价于该端口加入前的语义
	.o_normal_result_ready(o_normal_result_ready), // 观察FIR真实输入ready
	.i_coarse_ppg_value(i_coarse_ppg_value),    // 连接统一粗PPG数据
	.i_coarse_valid(i_coarse_valid),            // 连接粗结果有效资格
	.i_coarse_recovery_calibrated(i_coarse_recovery_calibrated), // 连接恢复校准资格
	.i_stage1_saturation_low(i_stage1_saturation_low), // 连接Stage1负饱和
	.i_stage1_saturation_high(i_stage1_saturation_high), // 连接Stage1正饱和
	.i_coarse_saturation_low(i_coarse_saturation_low), // 连接粗恢复负饱和
	.i_coarse_saturation_high(i_coarse_saturation_high), // 连接粗恢复正饱和
	.i_config_epoch(i_config_epoch),            // 连接事务ACTIVE版本
	.i_coef_epoch(i_coef_epoch),                // 连接事务Stage1版本
	.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch), // 连接事务DC恢复版本
	.i_precision_mode(i_precision_mode),        // 连接事务真实精度快照
	.i_frame_id(i_frame_id),                    // 连接物理帧号
	.i_sample_index(i_sample_index),            // 连接事务全局序号
	.i_color_ir(i_color_ir),                    // 连接颜色身份
	.i_frame_type(i_frame_type),                // 连接NORMAL帧类型
	.i_amb_code_snapshot(i_amb_code_snapshot),  // 连接AMB码快照
	.i_dc_code_snapshot(i_dc_code_snapshot),    // 连接DC码快照
	.i_amb_code_epoch(i_amb_code_epoch),        // 连接AMB码版本
	.i_dc_code_epoch(i_dc_code_epoch),          // 连接DC码版本
	.i_frame_safe_boundary(i_frame_safe_boundary), // 连接安全帧边界
	.i_safe_frame_id(i_safe_frame_id),          // 连接下一真实帧号
	.i_precision_takeover_safe(i_adc_idle),     // V1.1:RTL V1.3把i_adc_idle纯改名，TB激励名不变
	.i_analog_safe(i_analog_safe),              // 连接模拟安全资格
	.i_normal_fork_idle(i_normal_fork_idle),    // 连接上游fork排空资格
	.i_idac_idle(i_idac_idle),                  // 连接IDAC排空资格
	.i_startup_search_complete(i_startup_search_complete), // 连接启动搜索完成资格
	.i_normal_frame_complete_event(i_normal_frame_complete_event), // 连接NORMAL帧完成事件
	.i_calibration_frame_complete_event(i_calibration_frame_complete_event), // 连接校准帧完成事件
	.i_amb_sample_request(i_amb_sample_request), // 连接AMB样本请求
	.i_amb_sequence_done(i_amb_sequence_done),  // 连接AMB成功事件
	.i_amb_sequence_failed(i_amb_sequence_failed), // 连接AMB失败事件
	.i_dcs_revalidate_request(i_dcs_revalidate_request), // 连接DC重验证请求
	.i_dcs_sample_request(i_dcs_sample_request), // 连接DCS样本请求
	.i_dcs_sample_color_ir(i_dcs_sample_color_ir), // 连接DCS颜色身份
	.i_dcs_revalidate_done(i_dcs_revalidate_done), // 连接DC整体成功事件
	.i_dcs_revalidate_failed(i_dcs_revalidate_failed), // 连接DC失败事件
	.i_amb_sample_accepted_event(i_amb_sample_accepted_event), // 连接AMB结果消费事件
	.i_dcs_sample_accepted_event(i_dcs_sample_accepted_event), // 连接DCS结果消费事件
	.o_amb_sequence_start(o_amb_sequence_start), // 观察AMB检查启动事件
	.o_dcs_revalidate_accept(o_dcs_revalidate_accept), // 观察DC重验证接受事件
	.i_calibration_sample_ready(i_calibration_sample_ready), // 连接校准采样ready
	.o_calibration_sample_valid(o_calibration_sample_valid), // 观察校准采样valid
	.o_calibration_frame_type(o_calibration_frame_type), // 观察校准帧类型
	.o_calibration_color_ir(o_calibration_color_ir), // 观察校准颜色身份
	.o_calibration_precision_mode(o_calibration_precision_mode), // 观察固定SAR9精度
	.o_calibration_frame_start(o_calibration_frame_start), // 观察校准帧开始事件
	.o_calibration_stage(o_calibration_stage),  // 观察当前校准阶段
	.o_active_precision_mode(o_active_precision_mode), // 观察唯一committed精度
	.o_fine_window_active(o_fine_window_active), // 观察正式fine窗口
	.o_fine_window_start_event(o_fine_window_start_event), // 观察进入fine事件
	.o_fine_window_start_frame_id(o_fine_window_start_frame_id), // 观察首个fine帧号
	.o_precision_15_to_9_event(o_precision_15_to_9_event), // 观察返回9-bit事件
	.o_precision_15_to_9_frame_id(o_precision_15_to_9_frame_id), // 观察首个恢复帧号
	.o_reacquire_request_event(o_reacquire_request_event), // 观察异常重获事件
	.o_switch_hold_new_transaction(o_switch_hold_new_transaction), // 观察停止新事务要求
	.o_mode_fault_event(o_mode_fault_event),    // 观察精度故障事件
	.o_normal_frame_count(o_normal_frame_count), // 观察周期NORMAL帧计数
	.o_amb_recheck_pending(o_amb_recheck_pending), // 观察重检pending
	.o_amb_recheck_accept(o_amb_recheck_accept), // 观察真实重检接管
	.o_amb_recheck_busy(o_amb_recheck_busy),    // 观察重检占用状态
	.o_normal_output_inhibit(o_normal_output_inhibit), // 观察正式输出禁止
	.o_recheck_sequence_done(o_recheck_sequence_done), // 观察重检成功事件
	.o_recheck_sequence_failed(o_recheck_sequence_failed), // 观察重检失败事件
	.o_fir_history_full_r(o_fir_history_full_r), // 观察RED历史预热状态
	.o_fir_history_full_ir(o_fir_history_full_ir), // 观察IR历史预热状态
	.o_fir_idle(o_fir_idle),                    // 观察FIR内部排空
	.o_detection_fork_idle(o_detection_fork_idle), // 观察检测fork排空
	.o_detector_idle(o_detector_idle),          // 观察峰谷检测排空
	.o_controller_idle(o_controller_idle),      // 观察精度控制排空
	.o_scheduler_idle(o_scheduler_idle),        // 观察AMB调度器排空
	.o_cross_pending(o_cross_pending),          // 观察cross保持请求
	.o_peak_pending(o_peak_pending),            // 观察peak保持事件
	.o_valley_pending(o_valley_pending),        // 观察valley保持事件
	.o_return_pending(o_return_pending),        // 观察return保持请求
	.o_baseline_valid(o_baseline_valid),        // 观察动态基线有效资格
	.o_reacquire_active(o_reacquire_active),    // 观察动态基线重获状态
	.o_detector_fine_window_active(o_detector_fine_window_active), // 观察检测器fine状态
	.o_switch_pending(o_switch_pending),        // 观察精度切换pending
	.o_switch_target_precision(o_switch_target_precision), // 观察pending目标精度
	.o_slope_current_q16(o_slope_current_q16),  // 观察当前活动斜率
	.o_baseline_protocol_error_sticky(o_baseline_protocol_error_sticky), // 观察基线协议诊断
	.o_fine_window_timeout_sticky(o_fine_window_timeout_sticky), // 观察fine超时诊断
	.o_reacquire_timeout_sticky(o_reacquire_timeout_sticky), // 观察重获超时诊断
	.o_peak_valley_protocol_error_sticky(o_peak_valley_protocol_error_sticky), // 观察峰谷协议诊断
	.o_switch_timeout_sticky(o_switch_timeout_sticky), // 观察精度超时诊断
	.o_precision_protocol_error_sticky(o_precision_protocol_error_sticky) // 观察精度协议诊断
);

//===================<主测试流程>===================//

// 依次运行五个PWI集成场景，任何PASS均来自真实端口和握手比较。
initial begin
	i_clk = 1'b0;                            // 初始化仿真时钟低电平
	cnt_pass = 0;                            // 清除PWI通过累计
	cnt_fail = 0;                            // 清除PWI失败累计
	initialize_inputs;                       // 为全部DUT端口建立确定初值

	// PWI-01：真实cross握手后在安全边界进入fine，并验证10笔入口尾部与第11笔违规。
	reset_dut;                               // 清除所有历史和诊断
	start_run;                               // 建立NORMAL 9-bit重新获取状态
	build_9bit_cross_request;                // 通过真实FIR峰谷和基线产生cross
	flag_case_ok = o_switch_pending && o_switch_target_precision && o_baseline_valid; // 确认cross已由控制器接受
	pulse_safe_boundary(cnt_red_frame[15:0]); // 下一安全帧真实提交15-bit；ABCD F-036：安全帧号=下一笔RED样本的真实帧号（send_red_sample先用后加）
	@(negedge i_clk);                        // ABCD F-036：等fine事件计数沿完成后再读计数，否则读到计数前的旧值
	flag_case_ok = flag_case_ok && o_active_precision_mode && o_fine_window_active && (cnt_fine_start_event == 1); // 确认真正进入fine
	for(idx_sample = 0; idx_sample < 10; idx_sample = idx_sample + 1)begin
		send_red_sample(500, 1'b0);            // 故意保留10笔旧9-bit中心尾部
	end
	wait_detection_idle;                     // 等待第10笔尾部被两个分支消费
	flag_case_ok = flag_case_ok && (o_peak_valley_protocol_error_sticky == 1'b0); // 合法尾部不得报错
	send_red_sample(500, 1'b0);              // 第11笔旧9-bit中心违反有界尾部
	wait_detection_idle;                     // 等待违规中心到达峰谷检测器
	check_case("PWI-01", flag_case_ok && o_peak_valley_protocol_error_sticky && (cnt_fine_start_event == 1) && o_active_precision_mode && o_fine_window_active); // ABCD F-036：终判纳入前10笔合法尾部的累计前提 // 检查责任分离和尾部上限

	// PWI-02：正常波谷返回后旧15-bit尾部不能产生新cross，首笔9-bit只重建相邻上下文。
	initialize_inputs;                       // 恢复定向配置和输入初值
	reset_dut;                               // 清除PWI-01故意产生的sticky
	start_run;                               // 重新建立NORMAL 9-bit运行
	build_9bit_cross_request;                // 产生合法进入15-bit请求
	pulse_safe_boundary(cnt_red_frame[15:0]); // 提交正式fine窗口；ABCD F-036：安全帧号=下一笔RED样本帧号，原+1使首笔15-bit中心帧龄为负
	for(idx_sample = 0; idx_sample < 10; idx_sample = idx_sample + 1)begin
		send_red_sample(300, 1'b1);            // 用真实15-bit输入排出10笔旧9-bit中心
	end
	build_fine_peak_valley_return;           // 通过真实fine峰谷形成正常return
	flag_case_ok = o_switch_pending && (o_switch_target_precision == 1'b0) && (cnt_return_transfer >= 1); // 确认return已被控制器接受
	pulse_safe_boundary(cnt_red_frame[15:0] + 16'd1); // 下一安全帧真实返回9-bit
	@(negedge i_clk);                        // ABCD F-036：等返回事件计数沿完成后再读计数
	flag_case_ok = flag_case_ok && (o_active_precision_mode == 1'b0) && (o_fine_window_active == 1'b0) && (cnt_return_event == 1) && (o_reacquire_request_event == 1'b0); // 正常波谷返回不触发重获
	cnt_cross_before_tail = cnt_fine_start_event; // 保存进入事件次数作为禁止新cross基准
	for(idx_sample = 0; idx_sample < 10; idx_sample = idx_sample + 1)begin
		send_red_sample(3000, 1'b0);           // 输入新9-bit但输出仍为旧15-bit中心尾部
	end
	wait_detection_idle;                     // 等待全部合法退出尾部消费
	flag_case_ok = flag_case_ok && (o_cross_pending == 1'b0) && (cnt_fine_start_event == cnt_cross_before_tail) && (o_peak_valley_protocol_error_sticky == 1'b0); // 旧15-bit中心不得建立cross，合法退出尾部不得报错
	send_red_sample(3000, 1'b0);             // 第一笔恢复9-bit中心只重建相邻上下文
	wait_detection_idle;                     // 等待首个恢复中心被消费
	check_case("PWI-02", flag_case_ok && (o_cross_pending == 1'b0) && (cnt_fine_start_event == cnt_cross_before_tail) && (cnt_return_event == 1) && (cnt_return_transfer >= 1)); // 检查退出尾部隔离

	// PWI-03至PWI-05共用一次真实fine返回和周期AMB三帧重检流程。
	initialize_inputs;                       // 恢复所有输入和计数初值
	i_amb_recheck_interval_frames = 16'd1;   // 一帧NORMAL完成即锁存重检pending
	reset_dut;                               // 清除此前检测和调度状态
	start_run;                               // 建立新RUN
	build_9bit_cross_request;                // 产生新的合法进入fine请求
	pulse_safe_boundary(cnt_red_frame[15:0]); // 提交15-bit模式；ABCD F-036：安全帧号=下一笔RED样本帧号
	for(idx_sample = 0; idx_sample < 10; idx_sample = idx_sample + 1)begin
		send_red_sample(300, 1'b1);            // 排出入口旧9-bit中心尾部
	end
	pulse_normal_frame_complete;             // 使AMB重检间隔正式到期
	flag_case_ok = o_amb_recheck_pending && (o_amb_recheck_busy == 1'b0); // pending仅锁存而不抢占fine
	build_fine_peak_valley_return;           // 形成真实正常return请求
	flag_case_ok = flag_case_ok && (o_return_pending || o_switch_pending || (cnt_return_transfer >= 1)) && (o_amb_recheck_accept == 1'b0); // return事务存在时不得提前接管

	// 在返回提交前启动一笔真实FIR事务，使15到9事件后仍存在需要排空的检测链所有权。
	send_red_sample(777, 1'b1);              // 该样本在精度提交后仍由旧事务流水处理
	i_frame_safe_boundary = 1'b1;            // 准备真实返回9-bit安全边界
	i_safe_frame_id = cnt_red_frame[15:0] + 16'd1; // 绑定第一笔恢复9-bit帧号
	@(posedge i_clk);                        // 当前沿提交返回9-bit
	#1;                                      // 观察PWC提交事件
	@(negedge i_clk);                        // 安全边界结束
	i_frame_safe_boundary = 1'b0;            // 阻止scheduler立即接管
	cnt_watchdog = 0;                        // 清除15到9事件等待保护
	while(o_amb_recheck_busy !== 1'b1 && cnt_watchdog < 100)begin
		@(negedge i_clk);                    // 等待scheduler观察真实返回事件
		cnt_watchdog = cnt_watchdog + 1;    // 累计有界等待周期
	end
	flag_case_ok = flag_case_ok && (cnt_return_event == 1) && o_amb_recheck_busy && o_normal_output_inhibit; // 真实返回后进入受控等待

	// PWI-04首先在FIR或fork未排空期间提供安全边界，接管必须保持为零。
	i_frame_safe_boundary = 1'b1;            // 尝试在检测链尚未排空时接管
	@(posedge i_clk);                        // Scheduler在真实busy条件下评估安全条件
	#1;                                      // 观察接管事件输出
	flag_case_ok = flag_case_ok && (o_amb_recheck_accept == 1'b0) && ((o_fir_idle == 1'b0) || (o_detection_fork_idle == 1'b0) || (o_detector_idle == 1'b0)); // 任一真实事务占用必须阻止接管
	@(negedge i_clk);                        // 结束本次安全边界尝试
	i_frame_safe_boundary = 1'b0;            // 等待真实事务自然排空
	wait_detection_idle;                     // 不丢失地完成旧FIR事务双分支消费
	check_case("PWI-04", flag_case_ok && (cnt_baseline_fork_transfer == cnt_peak_valley_fork_transfer) && (o_peak_pending == 1'b0) && (o_valley_pending == 1'b0) && (o_return_pending == 1'b0)); // 检查事务释放和消费次数一致

	// PWI-03允许被动退出尾部存在，但必须等FIR、fork和真实事件排空后的安全边界才接管。
	reg_slope_before_recheck = o_slope_current_q16; // 保存成功重检应保留的活动斜率
	pulse_safe_boundary(cnt_red_frame[15:0] + 16'd2); // 在完整安全条件下允许scheduler接管
	@(negedge i_clk);                       // 等待接管事件计数器完成非阻塞更新
	flag_case_ok = (cnt_recheck_accept_event == 1) && o_amb_recheck_busy && o_normal_output_inhibit && o_detection_fork_idle && (o_cross_pending == 1'b0); // 检查真实安全接管
	check_case("PWI-03", flag_case_ok);      // 报告被动尾部安全接管结果

	// PWI-05接管同拍原子清理两色FIR历史、fork和检测临时状态。
	flag_case_ok = (o_fir_history_full_r == 1'b0) && (o_fir_history_full_ir == 1'b0) && o_detection_fork_idle && (o_peak_pending == 1'b0) && (o_valley_pending == 1'b0) && (o_return_pending == 1'b0) && (o_slope_current_q16 == reg_slope_before_recheck); // 成功路径保留活动斜率
	complete_recheck_sequence;              // 驱动真实AMB、DC_R和DC_IR三帧协议
	cnt_watchdog = 0;                        // 清除重检完成等待保护
	while(cnt_recheck_done_event < 1 && cnt_watchdog < 200)begin
		@(negedge i_clk);                    // 等待scheduler产生整体成功事件
		cnt_watchdog = cnt_watchdog + 1;    // 累计有界等待周期
	end
	flag_case_ok = flag_case_ok && (cnt_recheck_done_event == 1) && (o_amb_recheck_busy == 1'b0) && (o_fir_history_full_r == 1'b0) && (o_fir_history_full_ir == 1'b0); // 重检后仍需重新预热
	for(idx_sample = 0; idx_sample < 20; idx_sample = idx_sample + 1)begin
		send_red_sample(100, 1'b0);          // RED只收集20笔不足完整窗口
	end
	for(idx_sample = 0; idx_sample < 20; idx_sample = idx_sample + 1)begin
		send_ir_sample(100, 1'b0);           // IR只收集20笔不足完整窗口
	end
	flag_case_ok = flag_case_ok && (o_fir_history_full_r == 1'b0) && (o_fir_history_full_ir == 1'b0); // 两色均不得提前恢复资格
	send_red_sample(100, 1'b0);             // RED第21笔恢复完整历史
	send_ir_sample(100, 1'b0);              // IR第21笔恢复完整历史
	wait_detection_idle;                    // 等待最后两笔MAC和fork事务排空
	check_case("PWI-05", flag_case_ok && o_fir_history_full_r && o_fir_history_full_ir && (o_slope_current_q16 == reg_slope_before_recheck) && (cnt_recheck_accept_event == 1) && (cnt_recheck_done_event == 1)); // 检查原子清理和真实21点重预热

	if(cnt_fail == 0 && cnt_pass == 5)begin
		$display("ALL PWI-01 THROUGH PWI-05 PASS count=%0d", cnt_pass); // 仅五项真实比较全部通过才成功
	end else begin
		$display("PWI REGRESSION FAIL pass=%0d fail=%0d", cnt_pass, cnt_fail); // 汇总任一失败项
	end
	$finish;                                  // 结束集成自检仿真
end

// 全局看门狗防止协议错误造成仿真永久挂起。
initial begin
	repeat(200000)@(posedge i_clk);          // 提供覆盖全部五项场景的上限
	$display("FAIL PWI global watchdog timeout"); // 报告全局仿真超时
	$finish;                                 // 强制终止不可收敛测试
end

endmodule
