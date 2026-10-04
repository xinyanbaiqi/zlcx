`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/12
// Design Name:        PPG Precision Window Controller Self-Checking Testbench
// Module Name:        tb_ppg_precision_window_controller
// Description:        Description/tb_ppg_precision_window_controller_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_precision_window_controller
//
// Referrences:        PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_precision_window_controller.v
//
// Version:            V1.3
// Revision Date:      2026/09/17
// History:
//    Time               Version       Revised by            Contents
// 2026/08/12            V1.0          Erie                  Create file.
// 2026/09/16            V1.1          Erie                  Adapt to RTL V1.1-V1.3: connect the PWI-broadcast i_detection_discard group, i_run_generation, i_peak_valley_config_valid, o_local_empty and the o_mode_fault_* group; rename i_adc_idle to i_precision_takeover_safe; PWC-27/28/33 now use generation-scoped DISCARD_STOP/DISCARD_ABORT/DISCARD_SYSTEM_FAULT broadcasts instead of direct ports (PWC-27 adds a stale-generation negative control); add isolated PWC-40 V5 formal-detection gate check and raise the pass gate to 40.
// 2026/09/17            V1.2          Erie                  Add PWC-41: new legal START must not clear switch_timeout_sticky/protocol_error_sticky (contract :205/:731), mirroring PVW-37's fix; raise the pass gate to 42.
// 2026/09/17            V1.3          Erie                  Work-line-D remediation of 6 confirmed test gaps (independent recheck, no RTL change): PWC-15 adds a correctly-timed second check so it can no longer pass on an abnormal return; PWC-21 adds the missing o_switch_pending==0 clause; PWC-26 adds an exact single-pulse fault-report count instead of relying on sticky/hold alone; PWC-34 adds a direct o_mode_fault_active assertion so diag-clear-releases-fault-hold mutants are caught; PWC-35 adds a real non-idle negative case; PWC-04 drives an actual cross/return request in CHARACTERIZATION profile instead of asserting on an unstimulated reset state. Raise the pass gate to 48.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月12日
// 设计名称:           PPG精度窗口模式控制器自检平台
// 模块名称:           tb_ppg_precision_window_controller
// 模块说明:           Description/tb_ppg_precision_window_controller_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_precision_window_controller
//
// 参考资料:           PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_precision_window_controller.v
//
// 当前版本:           V1.3
// 修订日期:           2026年09月17日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月12日        V1.0          Erie                  创建文件。
// 2026年09月16日        V1.1          Erie                  适配RTL V1.1-V1.3：连接PWI广播的i_detection_discard组、i_run_generation、i_peak_valley_config_valid、o_local_empty和o_mode_fault组；i_adc_idle改名为i_precision_takeover_safe；PWC-27/28/33改用代际DISCARD_STOP/DISCARD_ABORT/DISCARD_SYSTEM_FAULT广播替代直接端口（PWC-27先施加陈旧代际反例）；新增隔离的PWC-40 V5正式检测门控断言，总PASS门限提高到40
// 2026年09月17日        V1.2          Erie                  新增PWC-41：新合法START不得清除switch_timeout_sticky/protocol_error_sticky（合同:205/:731），修法参照PVW-37；总PASS门限提高到42
// 2026年09月17日        V1.3          Erie                  工作线D独立复核确认的6处缺测试证据修复（不改RTL）：PWC-15补一个正确采样拍的第二条断言使其不再对异常返回也PASS；PWC-21补上缺失的o_switch_pending==0；PWC-26改用精确单拍故障计数而不是只看sticky/hold；PWC-34直接断言o_mode_fault_active以抓住"诊断清除误解除故障保持"这类变异；PWC-35补一个真实非idle负向用例；PWC-04在表征profile下真实驱动一次cross/return请求而不是只测未激励的复位态。总PASS门限提高到48
// 使用真实ready/valid、提交事件、超时边界和生命周期比较覆盖PWC-01至PWC-41
module tb_ppg_precision_window_controller
(
);

	//---------------配置参数区域---------------//
	// 仿真缩短模式提交保护时间但保持合同边界关系
	localparam integer C_CLK_PERIOD = 10;        // 测试平台主时钟周期为10 ns
	localparam integer C_TEST_TIMEOUT_CYCLES = 8; // 用八个周期验证两帧保护逻辑
	localparam integer C_TEST_TIMEOUT_WIDTH = 4; // 能够表达仿真保护阈值
	localparam [1:0]RETURN_VALLEY_CONFIRMED = 2'b00; // 正常波谷返回原因
	localparam [1:0]RETURN_FINE_TIMEOUT = 2'b01; // 精细窗口超时原因
	localparam [1:0]RETURN_PROTOCOL_FALLBACK = 2'b10; // 协议异常安全回退原因
	localparam [1:0]RETURN_RESERVED = 2'b11;     // 非法保留返回原因
	localparam [1:0]DISCARD_REASON_STOP = 2'b00; // AMI私有discard组STOP排空编码
	localparam [1:0]DISCARD_REASON_ABORT = 2'b01; // AMI私有discard组abort撤销编码
	localparam [1:0]DISCARD_REASON_SYSTEM_FAULT = 2'b10; // AMI私有discard组系统故障编码
	localparam [7:0]RUN_GENERATION_CURRENT = 8'hA5; // 本TB固定的当前RUN代际
	localparam [7:0]RUN_GENERATION_STALE = 8'hA4; // 与当前代际不同的陈旧代际

	//-----------------寄存器信号-----------------//
	// 生命周期和ACTIVE输入由主测试序列逐项驱动
	reg i_clk;                                   // DUT测试时钟
	reg i_rstn;                                  // DUT低有效异步复位
	reg i_run_enable;                            // 当前RUN资格
	reg i_start_ack_event;                       // 新RUN开始单拍
	reg i_detection_discard_event;               // PWI代际清空广播单拍
	reg [1:0]i_detection_discard_reason;         // 清空原因STOP/abort/系统故障编码
	reg i_detection_discard_identity_valid;      // 清空触发身份可信标志，本TB使用scope-only清空
	reg i_detection_discard_sample_valid;        // 清空触发事务样本资格快照
	reg [15:0]i_detection_discard_frame_id;      // 清空触发事务帧号
	reg [15:0]i_detection_discard_sample_index;  // 清空触发事务序号
	reg i_detection_discard_color_ir;            // 清空触发事务颜色
	reg [1:0]i_detection_discard_frame_type;     // 清空触发事务类型
	reg i_detection_discard_precision;           // 清空触发事务精度
	reg [7:0]i_detection_discard_config_epoch;   // 清空触发事务ACTIVE版本
	reg [7:0]i_detection_discard_coef_epoch;     // 清空触发事务Stage1版本
	reg [7:0]i_detection_discard_dc_recovery_epoch; // 清空触发事务DC恢复版本
	reg [3:0]i_detection_discard_amb_code_epoch; // 清空触发事务AMB码版本
	reg [3:0]i_detection_discard_dc_code_epoch;  // 清空触发事务DC码版本
	reg [7:0]i_detection_discard_run_generation; // 清空目标RUN代际
	reg [7:0]i_run_generation;                   // 当前RUN代际快照激励
	reg i_diag_clear_event;                      // 历史诊断清除单拍
	reg i_active_config_valid;                   // ACTIVE配置合法性
	reg i_run_profile;                           // NORMAL或CHARACTERIZATION选择
	reg i_initial_precision;                     // 表征模式固定精度
	reg i_normal_measurement_active;             // 正式NORMAL测量资格
	reg i_peak_valley_config_valid;              // V5正式检测资格

	// 相交请求输入包含完整原子元数据
	reg i_cross_valid;                           // 相交保持请求valid
	reg [15:0]i_cross_frame_id;                  // 相交中心帧号
	reg [15:0]i_cross_sample_index;              // 相交中心事务号
	reg i_cross_time_unknown;                    // 相交时间未知诊断
	reg [7:0]i_cross_config_epoch;               // 相交ACTIVE版本
	reg [7:0]i_cross_coef_epoch;                 // 相交Stage1版本
	reg [7:0]i_cross_dc_recovery_coef_epoch;     // 相交DC恢复版本

	// 返回请求输入由峰谷检测器行为模型驱动
	reg i_return_9bit_valid;                     // 返回9-bit保持请求
	reg [1:0]i_return_reason;                    // 返回控制原因
	reg [15:0]i_return_frame_id;                 // 返回结论真实帧号

	// 安全提交输入独立制造等待、成功和超时场景
	reg i_frame_safe_boundary;                   // 帧级安全边界
	reg [15:0]i_safe_frame_id;                   // 下一物理帧号
	reg i_precision_takeover_safe;                              // AMI复合精度接管资格
	reg i_analog_safe;                           // 模拟相位允许切换
	reg i_recheck_busy;                          // AMB/DC重检占用

	// 自检统计只依据实际比较结果递增
	integer cnt_error;                           // 失败用例累计数
	integer cnt_pass;                            // 通过用例累计数
	integer cnt_loop;                            // 有界周期循环索引
	integer cnt_fault_pulse;                     // PWC-26新增：故障单拍逐拍计数
	reg flag_saved_mode;                         // 精度稳定性观察快照
	reg flag_saved_window;                       // fine窗口稳定性观察快照
	reg [15:0]reg_saved_cross_frame;             // 反压前内部相交帧快照
	reg [1:0]enc_saved_return_reason;             // pending返回原因快照
	reg flag_case_ok;                            // 多阶段用例的局部比较累积结果

	//-----------------其他信号-----------------//
	// DUT全部可见输出均连接到自检比较网络
	wire o_cross_ready;                          // 观察相交请求ready
	wire o_return_9bit_ready;                    // 观察返回请求ready
	wire o_active_precision_mode;                // 观察唯一已提交精度
	wire o_fine_window_active;                   // 观察正式fine窗口
	wire o_fine_window_start_event;              // 观察进入15-bit提交单拍
	wire [15:0]o_fine_window_start_frame_id;     // 观察首笔正式15-bit帧
	wire o_precision_15_to_9_event;              // 观察真实返回9-bit单拍
	wire [15:0]o_precision_15_to_9_frame_id;     // 观察首笔恢复9-bit帧
	wire o_reacquire_request_event;              // 观察异常重新获取单拍
	wire o_mode_fault_event;                     // 观察控制故障报告单拍
	wire o_switch_pending;                       // 观察安全提交等待状态
	wire o_switch_target_precision;              // 观察pending目标精度
	wire o_switch_hold_new_transaction;          // 观察新事务阻断
	wire o_controller_idle;                      // 观察控制事务排空
	wire o_last_cross_time_unknown;              // 观察最近相交时间属性
	wire [1:0]o_last_return_reason;               // 观察最近返回原因
	wire o_switch_timeout_sticky;                // 观察切换超时历史
	wire o_protocol_error_sticky;                // 观察协议异常历史
	wire o_local_empty;                          // 观察本地排空状态
	wire o_mode_fault_active;                    // 观察当前代际故障保持电平
	wire o_mode_fault_identity_valid;            // 观察故障身份有效性
	wire [15:0]o_mode_fault_frame_id;            // 观察故障绑定帧号
	wire [15:0]o_mode_fault_sample_index;        // 观察故障绑定事务号
	wire o_mode_fault_color_ir;                  // 观察故障绑定颜色
	wire [1:0]o_mode_fault_frame_type;           // 观察故障绑定事务类别
	wire o_mode_fault_precision;                 // 观察故障绑定精度
	wire [7:0]o_mode_fault_run_generation;       // 观察故障绑定RUN代际

	//------------主要任务处理区域-----------//
	// 连续时钟驱动所有同步握手和状态提交
	always begin
		#(C_CLK_PERIOD / 2) i_clk = ~i_clk;    // 每半周期翻转一次测试时钟
	end

	// 每个用例开始前恢复确定性输入默认值
	task set_default_inputs;
		begin
			i_run_enable = 1'b0;                  // 默认不处于RUN
			i_start_ack_event = 1'b0;             // 默认无START事件
			i_detection_discard_event = 1'b0;     // 默认无代际discard事件
			i_detection_discard_reason = DISCARD_REASON_STOP; // 默认原因编码
			i_detection_discard_identity_valid = 1'b0; // scope-only清空不携带触发身份
			i_detection_discard_sample_valid = 1'b0; // 身份无效时样本资格为0
			i_detection_discard_frame_id = 16'd0; // 身份无效时帧号为0
			i_detection_discard_sample_index = 16'd0; // 身份无效时事务号为0
			i_detection_discard_color_ir = 1'b0;  // 身份无效时颜色为0
			i_detection_discard_frame_type = 2'b00; // 身份无效时类别为0
			i_detection_discard_precision = 1'b0; // 身份无效时精度为0
			i_detection_discard_config_epoch = 8'd0; // 身份无效时ACTIVE版本为0
			i_detection_discard_coef_epoch = 8'd0; // 身份无效时Stage1版本为0
			i_detection_discard_dc_recovery_epoch = 8'd0; // 身份无效时DC恢复版本为0
			i_detection_discard_amb_code_epoch = 4'd0; // 身份无效时AMB码版本为0
			i_detection_discard_dc_code_epoch = 4'd0; // 身份无效时DC码版本为0
			i_detection_discard_run_generation = 8'd0; // 默认无清空目标代际
			i_run_generation = RUN_GENERATION_CURRENT; // 固定当前RUN代际
			i_diag_clear_event = 1'b0;            // 默认无诊断清除
			i_active_config_valid = 1'b1;         // 默认ACTIVE合法
			i_run_profile = 1'b0;                 // 默认NORMAL_PPG
			i_initial_precision = 1'b0;           // 默认9-bit初始精度
			i_normal_measurement_active = 1'b1;   // 默认允许正式测量
			i_peak_valley_config_valid = 1'b1;    // 默认V5正式检测资格有效
			i_cross_valid = 1'b0;                 // 默认无相交请求
			i_cross_frame_id = 16'd0;             // 默认相交帧清零
			i_cross_sample_index = 16'd0;         // 默认相交事务号清零
			i_cross_time_unknown = 1'b0;          // 默认相交时间已知
			i_cross_config_epoch = 8'd0;          // 默认ACTIVE版本清零
			i_cross_coef_epoch = 8'd0;            // 默认Stage1版本清零
			i_cross_dc_recovery_coef_epoch = 8'd0; // 默认DC恢复版本清零
			i_return_9bit_valid = 1'b0;           // 默认无返回请求
			i_return_reason = RETURN_VALLEY_CONFIRMED; // 默认正常返回原因
			i_return_frame_id = 16'd0;            // 默认返回帧清零
			i_frame_safe_boundary = 1'b0;         // 默认不在安全边界
			i_safe_frame_id = 16'd0;              // 默认安全帧号清零
			i_precision_takeover_safe = 1'b1;                    // 默认AMI复合接管资格成立
			i_analog_safe = 1'b1;                 // 默认模拟相位允许切换
			i_recheck_busy = 1'b0;                // 默认无周期重检占用
		end
	endtask

	// 同步前进一个时钟并等待非阻塞赋值稳定
	task step_clock;
		begin
			@(posedge i_clk);                     // 等待DUT同步采样沿
			#1;                                    // 留出非阻塞更新观察时间
		end
	endtask

	// 异步复位后建立确定空闲状态
	task reset_dut;
		begin
			set_default_inputs;                    // 先驱动所有输入确定值
			i_rstn = 1'b0;                         // 拉低异步复位
			#2;                                    // 覆盖组合和异步寄存器路径
			step_clock;                             // 观察复位状态一个时钟
			i_rstn = 1'b1;                         // 释放复位供后续用例运行
			step_clock;                             // 等待复位释放后的稳定拍
		end
	endtask

	// 产生一次具有指定配置的START确认事件
	task start_run;
		input profile;
		input initial_precision;
		input active_valid;
		begin
			i_run_enable = 1'b1;                  // START事件同时建立RUN资格
			i_run_profile = profile;              // 驱动本RUN配置类型
			i_initial_precision = initial_precision; // 驱动配置初始精度
			i_active_config_valid = active_valid; // 驱动ACTIVE合法性
			i_start_ack_event = 1'b1;             // 提交新RUN配置
			step_clock;                             // DUT在此沿完成初始化
			i_start_ack_event = 1'b0;             // START固定单拍
			step_clock;                             // 观察初始化后的稳定状态
		end
	endtask

	// 提交一笔完整相交请求并在握手后释放valid
	task request_cross;
		input [15:0]frame_id;
		input [15:0]sample_index;
		input time_unknown;
		input [7:0]config_epoch;
		input [7:0]coef_epoch;
		input [7:0]dc_epoch;
		begin
			i_cross_frame_id = frame_id;          // 驱动相交中心帧
			i_cross_sample_index = sample_index;  // 驱动相交事务号
			i_cross_time_unknown = time_unknown;  // 驱动时间诊断属性
			i_cross_config_epoch = config_epoch;  // 驱动ACTIVE版本
			i_cross_coef_epoch = coef_epoch;      // 驱动Stage1版本
			i_cross_dc_recovery_coef_epoch = dc_epoch; // 驱动DC恢复版本
			i_cross_valid = 1'b1;                 // 建立保持型请求
			step_clock;                             // ready为高时完成真实握手
			i_cross_valid = 1'b0;                 // 上游观察握手后释放valid
		end
	endtask

	// 在下一物理帧安全边界提交当前pending精度
	task commit_safe_frame;
		input [15:0]safe_frame_id;
		begin
			i_safe_frame_id = safe_frame_id;      // 指定即将开始的真实物理帧号
			i_frame_safe_boundary = 1'b1;         // 产生单拍安全边界
			i_precision_takeover_safe = 1'b1;                    // 确认AMI复合接管资格成立
			i_analog_safe = 1'b1;                 // 确认模拟相位允许切换
			step_clock;                             // DUT在此沿原子提交精度
			i_frame_safe_boundary = 1'b0;         // 安全边界事件固定单拍
		end
	endtask

	// 快速建立一个正式15-bit窗口供返回路径测试
	task enter_fine_window;
		input [15:0]cross_frame_id;
		input [15:0]safe_frame_id;
		begin
			request_cross(cross_frame_id, cross_frame_id + 16'd100, 1'b0, 8'h11, 8'h22, 8'h33); // 建立合法进入请求
			commit_safe_frame(safe_frame_id);      // 下一安全帧真实进入15-bit
			step_clock;                             // 越过提交事件单拍
		end
	endtask

	// 提交一笔峰谷检测器返回请求
	task request_return;
		input [1:0]reason;
		input [15:0]frame_id;
		begin
			i_return_reason = reason;              // 驱动返回控制原因
			i_return_frame_id = frame_id;          // 驱动返回结论帧号
			i_return_9bit_valid = 1'b1;           // 建立保持型返回请求
			step_clock;                             // ready为高时完成握手
			i_return_9bit_valid = 1'b0;           // 上游释放已消费请求
		end
	endtask

	// 统一输出每个PWC用例的真实比较结论
	task check_case;
		input [8 * 96 - 1:0]case_name;
		input condition;
		begin
			if(condition)begin
				cnt_pass = cnt_pass + 1;             // 只有真实布尔比较为真才累计PASS
				$display("PASS %0s", case_name);   // 输出可检索用例标识
			end else begin
				cnt_error = cnt_error + 1;           // 任一不匹配累计失败
				$display("FAIL %0s time=%0t", case_name, $time); // 报告失败发生时刻
			end
		end
	endtask

	//----------------例化模块区域----------------//
	// 使用缩短超时参数例化完整精度窗口控制器
	ppg_precision_window_controller
	#(
		.C_FRAME_ID_WIDTH(16),                  // 测试合同默认帧号宽度
		.C_SAMPLE_INDEX_WIDTH(16),              // 测试合同默认事务号宽度
		.C_CONFIG_EPOCH_WIDTH(8),               // 测试ACTIVE版本宽度
		.C_COEF_EPOCH_WIDTH(8),                 // 测试Stage1版本宽度
		.C_DC_RECOVERY_EPOCH_WIDTH(8),          // 测试DC恢复版本宽度
		.C_SWITCH_TIMEOUT_CYCLES(C_TEST_TIMEOUT_CYCLES), // 缩短有界等待回归时间
		.C_SWITCH_TIMEOUT_COUNTER_WIDTH(C_TEST_TIMEOUT_WIDTH), // 匹配仿真阈值位宽
		.C_CODE_EPOCH_WIDTH(4),                 // 测试discard组码版本宽度
		.C_RUN_GENERATION_WIDTH(8)              // 测试RUN代际宽度
	)dut(
		.i_clk(i_clk),                           // 连接主测试时钟
		.i_rstn(i_rstn),                         // 连接低有效异步复位
		.i_run_enable(i_run_enable),             // 连接RUN资格
		.i_start_ack_event(i_start_ack_event),   // 连接START确认事件
		.i_detection_discard_event(i_detection_discard_event), // 连接代际discard事件
		.i_detection_discard_reason(i_detection_discard_reason), // 连接discard原因
		.i_detection_discard_identity_valid(i_detection_discard_identity_valid), // 连接触发身份有效性
		.i_detection_discard_sample_valid(i_detection_discard_sample_valid), // 连接触发样本资格
		.i_detection_discard_frame_id(i_detection_discard_frame_id), // 连接触发帧号
		.i_detection_discard_sample_index(i_detection_discard_sample_index), // 连接触发事务号
		.i_detection_discard_color_ir(i_detection_discard_color_ir), // 连接触发颜色
		.i_detection_discard_frame_type(i_detection_discard_frame_type), // 连接触发类别
		.i_detection_discard_precision(i_detection_discard_precision), // 连接触发精度
		.i_detection_discard_config_epoch(i_detection_discard_config_epoch), // 连接触发ACTIVE版本
		.i_detection_discard_coef_epoch(i_detection_discard_coef_epoch), // 连接触发Stage1版本
		.i_detection_discard_dc_recovery_epoch(i_detection_discard_dc_recovery_epoch), // 连接触发DC恢复版本
		.i_detection_discard_amb_code_epoch(i_detection_discard_amb_code_epoch), // 连接触发AMB码版本
		.i_detection_discard_dc_code_epoch(i_detection_discard_dc_code_epoch), // 连接触发DC码版本
		.i_detection_discard_run_generation(i_detection_discard_run_generation), // 连接清空目标代际
		.i_run_generation(i_run_generation),     // 连接当前RUN代际
		.o_local_empty(o_local_empty),           // 连接本地排空状态
		.i_diag_clear_event(i_diag_clear_event), // 连接诊断清除事件
		.i_active_config_valid(i_active_config_valid), // 连接ACTIVE合法性
		.i_run_profile(i_run_profile),           // 连接运行配置类型
		.i_initial_precision(i_initial_precision), // 连接初始精度配置
		.i_normal_measurement_active(i_normal_measurement_active), // 连接正式测量资格
		.i_peak_valley_config_valid(i_peak_valley_config_valid), // 连接V5正式检测资格
		.i_cross_valid(i_cross_valid),           // 连接相交请求valid
		.o_cross_ready(o_cross_ready),           // 连接相交请求ready
		.i_cross_frame_id(i_cross_frame_id),     // 连接相交中心帧号
		.i_cross_sample_index(i_cross_sample_index), // 连接相交事务号
		.i_cross_time_unknown(i_cross_time_unknown), // 连接相交时间属性
		.i_cross_config_epoch(i_cross_config_epoch), // 连接相交ACTIVE版本
		.i_cross_coef_epoch(i_cross_coef_epoch), // 连接相交Stage1版本
		.i_cross_dc_recovery_coef_epoch(i_cross_dc_recovery_coef_epoch), // 连接相交DC恢复版本
		.i_return_9bit_valid(i_return_9bit_valid), // 连接返回请求valid
		.o_return_9bit_ready(o_return_9bit_ready), // 连接返回请求ready
		.i_return_reason(i_return_reason),       // 连接返回原因
		.i_return_frame_id(i_return_frame_id),   // 连接返回结论帧号
		.i_frame_safe_boundary(i_frame_safe_boundary), // 连接帧安全边界
		.i_safe_frame_id(i_safe_frame_id),       // 连接下一物理帧号
		.i_precision_takeover_safe(i_precision_takeover_safe),                 // 连接AMI复合接管资格
		.i_analog_safe(i_analog_safe),           // 连接模拟安全条件
		.i_recheck_busy(i_recheck_busy),         // 连接重检占用条件
		.o_active_precision_mode(o_active_precision_mode), // 连接已提交精度
		.o_fine_window_active(o_fine_window_active), // 连接正式fine窗口
		.o_fine_window_start_event(o_fine_window_start_event), // 连接进入提交单拍
		.o_fine_window_start_frame_id(o_fine_window_start_frame_id), // 连接首个15-bit帧号
		.o_precision_15_to_9_event(o_precision_15_to_9_event), // 连接返回9-bit单拍
		.o_precision_15_to_9_frame_id(o_precision_15_to_9_frame_id), // 连接首个9-bit帧号
		.o_reacquire_request_event(o_reacquire_request_event), // 连接重新获取单拍
		.o_mode_fault_event(o_mode_fault_event), // 连接控制故障单拍
		.o_switch_pending(o_switch_pending),     // 连接pending状态
		.o_switch_target_precision(o_switch_target_precision), // 连接pending目标精度
		.o_switch_hold_new_transaction(o_switch_hold_new_transaction), // 连接新事务阻断
		.o_controller_idle(o_controller_idle),   // 连接控制事务排空状态
		.o_last_cross_time_unknown(o_last_cross_time_unknown), // 连接相交时间诊断
		.o_last_return_reason(o_last_return_reason), // 连接最近返回原因
		.o_switch_timeout_sticky(o_switch_timeout_sticky), // 连接超时历史
		.o_protocol_error_sticky(o_protocol_error_sticky), // 连接协议异常历史
		.o_mode_fault_active(o_mode_fault_active), // 连接故障保持电平
		.o_mode_fault_identity_valid(o_mode_fault_identity_valid), // 连接故障身份有效性
		.o_mode_fault_frame_id(o_mode_fault_frame_id), // 连接故障帧号
		.o_mode_fault_sample_index(o_mode_fault_sample_index), // 连接故障事务号
		.o_mode_fault_color_ir(o_mode_fault_color_ir), // 连接故障颜色
		.o_mode_fault_frame_type(o_mode_fault_frame_type), // 连接故障类别
		.o_mode_fault_precision(o_mode_fault_precision), // 连接故障精度
		.o_mode_fault_run_generation(o_mode_fault_run_generation) // 连接故障RUN代际
	);

	//----------------主程序区域----------------//
	// 依次执行PWC-01至PWC-41并由真实比较决定最终结果
 integer reason;
 initial begin
  i_clk=0;i_rstn=1;cnt_error=0;cnt_pass=0;set_default_inputs;
  for(reason=0;reason<3;reason=reason+1)begin
   reset_dut; start_run(0,0,1);
   request_cross(16'h8000,16'h8001,0,8'h11,8'h22,8'h33);
   check_case("BSETUP_ENTER",o_switch_pending===1'b1 && o_active_precision_mode===1'b0);
   @(negedge i_clk);
   i_detection_discard_event=1;i_detection_discard_reason=reason;
   i_detection_discard_run_generation=RUN_GENERATION_CURRENT;
   i_frame_safe_boundary=1;i_safe_frame_id=16'h8002;
   step_clock;
   $display("B_CANCEL_ENTER reason=%0d mode=%b window=%b start=%b pending=%b state=%0d",reason,o_active_precision_mode,o_fine_window_active,o_fine_window_start_event,o_switch_pending,dut.state_current);
   check_case("BCANCEL_ENTER",o_active_precision_mode===1'b0 && o_fine_window_active===1'b0 && o_fine_window_start_event===1'b0 && o_switch_pending===1'b0);
   reset_dut; start_run(0,0,1); enter_fine_window(16'h8100,16'h8101);
   request_return(RETURN_FINE_TIMEOUT,16'h8102);
   check_case("BSETUP_RETURN",o_switch_pending===1'b1 && o_active_precision_mode===1'b1);
   @(negedge i_clk);
   i_detection_discard_event=1;i_detection_discard_reason=reason;
   i_detection_discard_run_generation=RUN_GENERATION_CURRENT;
   i_frame_safe_boundary=1;i_safe_frame_id=16'h8103;
   step_clock;
   $display("B_CANCEL_RETURN reason=%0d mode=%b window=%b return=%b pending=%b state=%0d",reason,o_active_precision_mode,o_fine_window_active,o_precision_15_to_9_event,o_switch_pending,dut.state_current);
   check_case("BCANCEL_RETURN",o_active_precision_mode===1'b1 && o_fine_window_active===1'b0 && o_precision_15_to_9_event===1'b0 && o_switch_pending===1'b0);
  end
  reset_dut; start_run(0,0,1);
  request_cross(16'h8200,16'h8201,0,1,2,3);
  @(negedge i_clk);i_detection_discard_event=1;i_detection_discard_run_generation=RUN_GENERATION_STALE;
  commit_safe_frame(16'h8202);
  check_case("BSTALE_COMMITS",o_active_precision_mode===1'b1 && o_fine_window_active===1'b1 && o_fine_window_start_event===1'b1);
  reset_dut; start_run(0,0,1); enter_fine_window(16'h8300,16'h8301);
  request_return(RETURN_VALLEY_CONFIRMED,16'h8302);commit_safe_frame(16'h8303);
  check_case("BNORMAL_RETURN",o_active_precision_mode===1'b0 && o_fine_window_active===1'b0 && o_precision_15_to_9_event===1'b1);
  $display("B_PWC_CANCEL pass=%0d fail=%0d",cnt_pass,cnt_error);
  if(cnt_error!=0)$fatal(1,"B_PWC_CANCEL_FAIL");$finish;
 end
 initial begin #50000;$fatal(1,"B_PWC_TIMEOUT");end
endmodule
