`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/07
// Design Name:        PPG IDAC Code Controller Self-Checking Testbench
// Module Name:        tb_ppg_idac_code_controller
// Description:        Description/tb_ppg_idac_code_controller_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_idac_code_controller
//
// Referrences:        PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md,
//                     PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_idac_code_controller.v
//
// Version:            V2.2
// Revision Date:      2026/09/30
// History:
//    Time               Version       Revised by            Contents
// 2026/08/07            V2.0          Erie                  Create V2 self-checking regression.
// 2026/08/08            V2.1          Erie                  Add fixed periodic AMB-R-IR sequence coverage.
// 2026/09/30            V2.2          Erie                  TB maintenance (no RTL change): connect i_run_generation, added by controller RTL V2.2 (2026/08/22) and left floating here ever since. The X on the floating port corrupted the pending-candidate generation tag/compare and caused the long-standing "V2.1 regression found 33 errors" already recorded in the RTL's own V2.3 changelog (2026/08/29) as a stale-TB issue; REGRESSION_BASELINE_20260930.md section 6.2 pinned it to this single port. Driven by a constant 0 for the whole run (no case here exercises cross-generation rejection) and C_RUN_GENERATION_WIDTH is passed explicitly. The test-injection inputs stay unconnected on purpose (C_ENABLE_TEST_INJECTION defaults to 0 so they are gated off). Result: 148 PASS, 0 FAIL (xsim and iverilog).
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月07日
// 设计名称:           PPG IDAC码控制器自检测试平台
// 模块名称:           tb_ppg_idac_code_controller
// 模块说明:           Description/tb_ppg_idac_code_controller_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_idac_code_controller
//
// 参考资料:           PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md、
//                     PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_idac_code_controller.v
//
// 当前版本:           V2.2
// 修订日期:           2026年09月30日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月07日        V2.0          Erie                  创建V2自检回归。
// 2026年08月08日        V2.1          Erie                  增加固定AMB、DC_R及DC_IR周期序列覆盖。
// 2026年09月30日        V2.2          Erie                  TB维护（不改RTL）：连接控制器RTL V2.2（2026/08/22）新增、本TB一直悬空的i_run_generation。悬空的X污染了pending候选的代际锁存与比较，这就是RTL自身V2.3 changelog（2026/08/29）早已记录为"单元TB未同步"的"V2.1 regression found 33 errors"；REGRESSION_BASELINE_20260930.md第6.2节把根因精确到这一个端口。全程驱动常量0（本TB没有用例测跨代际拒绝），并显式传入C_RUN_GENERATION_WIDTH。测试注入输入有意保持不连（C_ENABLE_TEST_INJECTION默认0，已被门控屏蔽）。结果：148 PASS，0 FAIL（xsim与iverilog一致）。

// 覆盖启动搜索、固定周期三路重检以及IDT-01至IDT-15慢速跟踪和取消行为
module tb_ppg_idac_code_controller
(
);

	//-------------配置参数区域-------------//
	// 测试时钟和固定接口位宽
	localparam integer C_CLK_PERIOD = 10;   // 100 MHz仿真时钟仅用于缩短回归时间
	localparam integer C_FRAME_ID_WIDTH = 16; // 帧编号字段与DUT默认接口一致
	localparam integer C_SAMPLE_INDEX_WIDTH = 16; // 样本编号字段与DUT默认接口一致
	localparam integer C_IDAC_CODE_WIDTH = 8; // IDAC码和快照均使用8 bit
	localparam integer C_CODE_EPOCH_WIDTH = 4; // 三路码版本均使用4 bit
	localparam integer C_CONFIG_EPOCH_WIDTH = 8; // ACTIVE配置版本使用8 bit
	localparam integer C_COEF_EPOCH_WIDTH = 8; // Stage1系数版本使用8 bit
	localparam integer C_RUN_GENERATION_WIDTH = 8; // V2.2:RUN代际字段宽度与DUT默认值一致

	//--------------寄存器信号--------------//
	// 全局、生命周期和ACTIVE配置驱动
	reg i_clk;                              // DUT主时钟驱动
	reg i_rstn;                             // DUT低有效异步复位驱动
	reg i_run_enable;                       // 控制当前测试是否处于RUN
	reg i_start_ack_event;                  // 产生合法START应答单拍
	reg [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation; // V2.2:全程固定RUN代际，本TB不测跨代际拒绝
	reg i_stop_ack_event;                   // 产生STOP排空单拍
	reg i_status_clear_event;               // 产生协议sticky清除事件
	reg i_control_abort_event;              // 产生阻断错误取消事件
	reg i_frame_safe_boundary;              // 驱动pending安全提交边界
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_active_config_epoch; // 当前测试ACTIVE版本
	reg [1:0]i_idac_mode;                   // 选择手动、搜索保持或搜索跟踪
	reg i_amb_enable;                       // 使能AMB搜索和周期检查
	reg i_dcs_enable;                       // 使能红光与红外DCS控制
	reg i_amb_polarity;                     // AMB正向码极性配置
	reg i_dcs_polarity;                     // DCS正向码极性配置
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_manual_code; // AMB手动装载码
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_min; // AMB自动控制下界
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_max; // AMB自动控制上界
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_manual_code; // 红光DCS手动装载码
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code_min; // 红光DCS允许下界
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code_max; // 红光DCS允许上界
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_manual_code; // 红外DCS手动装载码
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code_min; // 红外DCS允许下界
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code_max; // 红外DCS允许上界
	reg signed [11:0]i_amb_threshold_low;   // AMB测试窗口低边界
	reg signed [11:0]i_amb_threshold_high;  // AMB测试窗口高边界
	reg signed [11:0]i_dcs_threshold_low;   // DCS测试窗口低边界
	reg signed [11:0]i_dcs_threshold_high;  // DCS测试窗口高边界
	reg [7:0]i_amb_confirm_count;           // AMB重检确认次数配置
	reg [7:0]i_dcs_confirm_count;           // DCS跟踪确认次数配置

	// 搜索检查事务驱动
	reg i_search_amb_valid;                 // 驱动AMB_CAL保持型valid
	reg i_search_dcs_valid;                 // 驱动DCS_CAL保持型valid
	reg signed [11:0]i_search_calibrated_s1_value; // 驱动搜索用signed校准残差
	reg i_search_calibration_applied;       // 驱动搜索样本校准资格
	reg i_search_saturation_low;            // 驱动搜索样本低侧饱和
	reg i_search_saturation_high;           // 驱动搜索样本高侧饱和
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_search_config_epoch; // 搜索样本配置版本
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_search_coef_epoch; // 搜索样本系数版本
	reg i_search_precision_mode;            // 搜索样本精度身份
	reg [C_FRAME_ID_WIDTH - 1:0]i_search_frame_id; // 搜索事务共享帧号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_search_sample_index; // 搜索事务顺序编号
	reg i_search_color_ir;                  // 搜索DCS颜色身份
	reg [1:0]i_search_frame_type;           // 搜索事务类别编码
	reg [C_IDAC_CODE_WIDTH - 1:0]i_search_amb_code_snapshot; // 搜索样本AMB码快照
	reg [C_IDAC_CODE_WIDTH - 1:0]i_search_dc_code_snapshot; // 搜索样本DC码快照
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_search_amb_code_epoch; // 搜索样本AMB版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_search_dc_code_epoch; // 搜索样本DC版本

	// NORMAL跟踪事务驱动
	reg i_track_valid;                      // 驱动tracking保持型valid
	reg signed [11:0]i_track_calibrated_s1_value; // 驱动慢速跟踪校准残差
	reg i_track_calibration_applied;        // 驱动NORMAL校准资格
	reg i_track_saturation_low;             // 驱动跟踪低侧饱和标志
	reg i_track_saturation_high;            // 驱动跟踪高侧饱和标志
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_track_config_epoch; // 跟踪事务ACTIVE版本
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_track_coef_epoch; // 跟踪事务Stage1版本
	reg i_track_precision_mode;             // 驱动9-bit或15-bit事务身份
	reg [C_FRAME_ID_WIDTH - 1:0]i_track_frame_id; // 跟踪事务共享帧号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_track_sample_index; // 跟踪事务全局顺序
	reg i_track_color_ir;                   // 选择红光或红外跟踪状态
	reg [1:0]i_track_frame_type;            // 合格跟踪固定使用NORMAL编码
	reg [C_IDAC_CODE_WIDTH - 1:0]i_track_amb_code_snapshot; // 跟踪事务AMB码快照
	reg [C_IDAC_CODE_WIDTH - 1:0]i_track_dc_code_snapshot; // 跟踪事务当前颜色DC快照
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_track_amb_code_epoch; // 跟踪事务AMB版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_track_dc_code_epoch; // 跟踪事务DC版本

	// 序列调度和自检控制
	reg i_amb_sequence_start;               // 驱动周期AMB序列启动事件
	reg i_dcs_revalidate_accept;            // 驱动DCS重验证accept
	integer error_count;                    // 汇总所有自检失败数量
	integer target_amb_code;                // 启动搜索模拟AMB目标码
	integer target_dcs_r_code;              // 启动搜索模拟红光目标码
	integer target_dcs_ir_code;             // 启动搜索模拟红外目标码
	integer startup_stage;                  // 检查AMB到R再到IR的请求顺序
	integer startup_guard;                  // 防止启动搜索任务无限等待

	//---------------其他信号---------------//
	// DUT组合与时序输出观测线
	wire o_search_amb_ready;                // 观测AMB入口ready
	wire o_search_dcs_ready;                // 观测DCS入口ready
	wire o_track_ready;                     // 观测tracking入口ready
	wire o_amb_sample_request;              // 观测AMB_CAL样本请求
	wire o_amb_sequence_busy;               // 观测周期AMB活动状态
	wire o_amb_sequence_done;               // 观测周期AMB完成事件
	wire o_amb_sequence_failed;             // 观测周期AMB失败事件
	wire o_dcs_sample_request;              // 观测DCS_CAL样本请求
	wire o_dcs_sample_color_ir;             // 观测当前DCS请求颜色
	wire o_dcs_revalidate_request;          // 观测DCS重验证保持请求
	wire o_dcs_revalidate_busy;             // 观测DCS重验证活动状态
	wire o_dcs_revalidate_done;             // 观测DCS重验证完成事件
	wire o_dcs_revalidate_failed;           // 观测DCS重验证失败事件
	wire [C_IDAC_CODE_WIDTH - 1:0]o_amb_code; // 观测AMB committed码
	wire [C_IDAC_CODE_WIDTH - 1:0]o_dcs_r_code; // 观测红光DC committed码
	wire [C_IDAC_CODE_WIDTH - 1:0]o_dcs_ir_code; // 观测红外DC committed码
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch; // 观测AMB提交版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_dcs_r_code_epoch; // 观测红光DC版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_dcs_ir_code_epoch; // 观测红外DC版本
	wire o_amb_code_update;                 // 观测AMB实际改码单拍
	wire o_dcs_r_code_update;               // 观测红光DC实际改码单拍
	wire o_dcs_ir_code_update;              // 观测红外DC实际改码单拍
	wire o_dcs_r_track_adjust;              // 观测红光1 LSB跟踪事件
	wire o_dcs_ir_track_adjust;             // 观测红外1 LSB跟踪事件
	wire o_amb_search_done;                 // 观测AMB搜索成功状态
	wire o_dcs_r_search_done;               // 观测红光搜索成功状态
	wire o_dcs_ir_search_done;              // 观测红外搜索成功状态
	wire o_amb_search_exhausted;            // 观测AMB搜索耗尽状态
	wire o_dcs_r_search_exhausted;          // 观测红光搜索耗尽状态
	wire o_dcs_ir_search_exhausted;         // 观测红外搜索耗尽状态
	wire o_amb_pending_valid;               // 观测AMB pending状态
	wire o_dcs_r_pending_valid;             // 观测红光DC pending状态
	wire o_dcs_ir_pending_valid;            // 观测红外DC pending状态
	wire o_amb_code_at_min;                 // 观测AMB下边界状态
	wire o_amb_code_at_max;                 // 观测AMB上边界状态
	wire o_dcs_r_code_at_min;               // 观测红光下边界状态
	wire o_dcs_r_code_at_max;               // 观测红光上边界状态
	wire o_dcs_ir_code_at_min;              // 观测红外下边界状态
	wire o_dcs_ir_code_at_max;              // 观测红外上边界状态
	wire o_amb_fault;                       // 观测AMB阻断故障
	wire o_dcs_r_fault;                     // 观测红光阻断故障
	wire o_dcs_ir_fault;                    // 观测红外阻断故障
	wire o_controller_fault_blocking;       // 观测控制器汇总阻断状态
	wire o_protocol_error_sticky;           // 观测协议错误sticky
	wire o_startup_search_complete;         // 观测启动流程完成资格
	wire o_idac_idle;                       // 观测控制器排空状态

	//-----------主要任务处理区域-----------//
	// 主时钟持续翻转并为所有定向任务提供稳定边沿
	always begin
		#(C_CLK_PERIOD / 2) i_clk = ~i_clk; // 产生50%占空比仿真时钟
	end

	// 记录一项布尔检查结果并输出可检索的PASS或FAIL标签
	task check_condition;
		input condition;                    // 当前检查条件为真表示通过
		input [8 * 96 - 1:0]case_name;      // 输出固定宽度的场景说明字符串
		begin
			if(condition == 1'b1)begin
				$display("PASS: %0s", case_name); // 报告已经执行真实比较的通过场景
			end else begin
				$display("FAIL: %0s", case_name); // 报告当前比较不符合预期
				error_count = error_count + 1; // 累加失败并阻止最终伪PASS
			end
		end
	endtask

	// 在一个完整时钟周期内产生帧安全边界并保留事件供调用者检查
	task pulse_safe_boundary;
		begin
			@(negedge i_clk);               // 避免在DUT采样沿同时改变激励
			i_frame_safe_boundary = 1'b1;   // 允许当前pending在下一上升沿提交
			@(negedge i_clk);               // 等待安全提交沿完成
			i_frame_safe_boundary = 1'b0;   // 撤销边界以防重复提交
		end
	endtask

	// 产生一次合法START应答并让DUT进入新的RUN上下文
	task pulse_start;
		begin
			@(negedge i_clk);               // 在非采样沿准备START事件
			i_run_enable = 1'b1;            // START进入RUN前建立运行许可
			i_start_ack_event = 1'b1;       // 驱动单周期合法START应答
			@(negedge i_clk);               // 等待DUT锁存新上下文
			i_start_ack_event = 1'b0;       // 撤销START单拍
		end
	endtask

	// 产生STOP并撤销RUN许可以验证pending和证据清理
	task pulse_stop;
		begin
			@(negedge i_clk);               // 在时钟低相位准备STOP
			i_stop_ack_event = 1'b1;        // 请求取消当前控制上下文
			i_run_enable = 1'b0;            // 模拟配置管理器进入STOPPING
			@(negedge i_clk);               // 等待DUT执行清理
			i_stop_ack_event = 1'b0;        // 撤销STOP应答事件
		end
	endtask

	// 根据当前样本请求和模拟目标码发送一笔匹配快照的校准事务
	task send_requested_search_sample;
		reg signed [11:0]sample_value;      // 根据当前码与目标关系生成残差方向
		begin
			sample_value = 12'sd0;          // 默认目标码产生窗口内残差
			if(o_amb_sample_request == 1'b1)begin
				if(o_amb_code < target_amb_code)begin
					sample_value = 12'sd20; // 码偏低时提供高侧残差要求增码
				end else if(o_amb_code > target_amb_code)begin
					sample_value = -12'sd20; // 码偏高时提供低侧残差要求减码
				end
			end else if(o_dcs_sample_color_ir == 1'b0)begin
				if(o_dcs_r_code < target_dcs_r_code)begin
					sample_value = 12'sd20; // 红光码偏低时要求提高候选
				end else if(o_dcs_r_code > target_dcs_r_code)begin
					sample_value = -12'sd20; // 红光码偏高时要求降低候选
				end
			end else begin
				if(o_dcs_ir_code < target_dcs_ir_code)begin
					sample_value = 12'sd20; // 红外码偏低时提供高侧证据
				end else if(o_dcs_ir_code > target_dcs_ir_code)begin
					sample_value = -12'sd20; // 红外码偏高时提供低侧证据
				end
			end
			@(negedge i_clk);               // 在非采样沿建立完整搜索事务
			i_search_calibrated_s1_value = sample_value; // 驱动目标相关signed残差
			i_search_calibration_applied = 1'b1; // 搜索样本声明正式校准资格
			i_search_saturation_low = 1'b0; // 普通启动搜索不使用低侧饱和
			i_search_saturation_high = 1'b0; // 普通启动搜索不使用高侧饱和
			i_search_config_epoch = i_active_config_epoch; // 绑定当前ACTIVE版本
			i_search_coef_epoch = 8'h31;    // 提供稳定Stage1诊断版本
			i_search_precision_mode = i_search_sample_index[0]; // 交错精度验证共享搜索状态
			i_search_frame_id = i_search_frame_id + 16'd1; // 推进搜索帧编号
			i_search_sample_index = i_search_sample_index + 16'd1; // 推进搜索事务顺序
			i_search_amb_code_snapshot = o_amb_code; // 绑定当前AMB committed码
			i_search_amb_code_epoch = o_amb_code_epoch; // 绑定当前AMB版本
			if(o_amb_sample_request == 1'b1)begin
				i_search_frame_type = 2'b00; // AMB请求使用AMB_CAL编码
				i_search_color_ir = 1'b0;   // AMB样本颜色字段不参与判断
				i_search_dc_code_snapshot = o_dcs_r_code; // 提供确定但无资格作用的DC快照
				i_search_dc_code_epoch = o_dcs_r_code_epoch; // 提供确定DC诊断版本
				i_search_amb_valid = 1'b1;  // 声明一笔AMB_CAL有效事务
				i_search_dcs_valid = 1'b0;  // 保持DCS分支无效
			end else begin
				i_search_frame_type = 2'b01; // DCS请求使用DCS_CAL编码
				i_search_color_ir = o_dcs_sample_color_ir; // 匹配控制器请求颜色
				i_search_dc_code_snapshot = o_dcs_sample_color_ir ? o_dcs_ir_code : o_dcs_r_code; // 绑定选中色DC码
				i_search_dc_code_epoch = o_dcs_sample_color_ir ? o_dcs_ir_code_epoch : o_dcs_r_code_epoch; // 绑定选中色版本
				i_search_amb_valid = 1'b0;  // 保持AMB分支无效
				i_search_dcs_valid = 1'b1;  // 声明一笔DCS_CAL有效事务
			end
			@(negedge i_clk);               // 等待唯一valid-ready握手沿
			i_search_amb_valid = 1'b0;      // 撤销AMB_CAL valid
			i_search_dcs_valid = 1'b0;      // 撤销DCS_CAL valid
		end
	endtask

	// 自动服务pending和样本请求直到三路启动搜索全部完成
	task complete_startup_search;
		begin
			startup_guard = 0;              // 每次启动重新建立超时保护
			startup_stage = 0;              // 请求顺序从AMB阶段开始
			while((o_startup_search_complete == 1'b0) && (o_controller_fault_blocking == 1'b0) && (startup_guard < 80))begin
				startup_guard = startup_guard + 1; // 限制异常状态机的最大循环次数
				if(o_amb_pending_valid || o_dcs_r_pending_valid || o_dcs_ir_pending_valid)begin
					pulse_safe_boundary;    // 每个搜索候选必须先安全提交
				end else if(o_amb_sample_request == 1'b1)begin
					check_condition(startup_stage == 0, "STARTUP request order begins with AMB"); // 检查首个逻辑阶段
					send_requested_search_sample; // 评价当前AMB候选
				end else if(o_dcs_sample_request == 1'b1)begin
					if(o_dcs_sample_color_ir == 1'b0)begin
						check_condition(startup_stage <= 1, "STARTUP requests red DCS before infrared"); // 检查红光先于红外
						startup_stage = 1;  // 标记已经进入红光阶段
					end else begin
						check_condition(startup_stage >= 1, "STARTUP infrared follows red DCS"); // 检查红外没有越过红光
						startup_stage = 2;  // 标记已经进入红外阶段
					end
					send_requested_search_sample; // 评价当前颜色DCS候选
				end else begin
					@(negedge i_clk);       // 等待组合请求或下一状态生效
				end
			end
			check_condition(startup_guard < 80, "STARTUP search terminates before watchdog"); // 检查搜索没有停滞
			check_condition(o_startup_search_complete && !o_controller_fault_blocking,
				"STARTUP AMB-R-IR binary searches complete without fault"); // 检查最终启动资格
		end
	endtask

	// 启动周期重检并确认AMB、红光DC和红外DC请求按固定顺序全部出现
	task complete_fixed_periodic_recheck;
		integer periodic_guard;             // 限制周期重检服务循环的最大次数
		integer periodic_amb_sample_count;  // 统计本轮AMB_CAL请求数量
		integer periodic_dcs_r_sample_count; // 统计本轮红光DCS_CAL请求数量
		integer periodic_dcs_ir_sample_count; // 统计本轮红外DCS_CAL请求数量
		reg periodic_amb_done_seen;         // 记录AMB阶段成功单拍是否出现
		reg [C_IDAC_CODE_WIDTH - 1:0]amb_code_before; // 保存重检前AMB committed码
		reg [C_IDAC_CODE_WIDTH - 1:0]dcs_r_code_before; // 保存重检前红光DC committed码
		reg [C_IDAC_CODE_WIDTH - 1:0]dcs_ir_code_before; // 保存重检前红外DC committed码
		reg [C_CODE_EPOCH_WIDTH - 1:0]amb_epoch_before; // 保存重检前AMB码版本
		reg [C_CODE_EPOCH_WIDTH - 1:0]dcs_r_epoch_before; // 保存重检前红光DC版本
		reg [C_CODE_EPOCH_WIDTH - 1:0]dcs_ir_epoch_before; // 保存重检前红外DC版本
		begin
			periodic_guard = 0;             // 每轮周期序列重新初始化看门次数
			periodic_amb_sample_count = 0;  // 新序列尚未请求AMB样本
			periodic_dcs_r_sample_count = 0; // 新序列尚未请求红光样本
			periodic_dcs_ir_sample_count = 0; // 新序列尚未请求红外样本
			periodic_amb_done_seen = 1'b0;  // 清除上一轮AMB完成观察结果
			amb_code_before = o_amb_code;   // 快照当前AMB码用于无变化检查
			dcs_r_code_before = o_dcs_r_code; // 快照当前红光DC码用于无变化检查
			dcs_ir_code_before = o_dcs_ir_code; // 快照当前红外DC码用于无变化检查
			amb_epoch_before = o_amb_code_epoch; // 快照当前AMB版本用于无变化检查
			dcs_r_epoch_before = o_dcs_r_code_epoch; // 快照当前红光DC版本用于无变化检查
			dcs_ir_epoch_before = o_dcs_ir_code_epoch; // 快照当前红外DC版本用于无变化检查
			@(negedge i_clk);               // 在稳定低相位产生周期序列启动单拍
			i_amb_sequence_start = 1'b1;    // 请求控制器接管一次周期重检
			@(negedge i_clk);               // 等待DUT进入AMB周期检查状态
			i_amb_sequence_start = 1'b0;    // 撤销启动避免重复接受
			while((o_dcs_revalidate_done == 1'b0) && (o_controller_fault_blocking == 1'b0) && (periodic_guard < 40))begin
				periodic_guard = periodic_guard + 1; // 推进有限服务循环
				if(o_amb_pending_valid || o_dcs_r_pending_valid || o_dcs_ir_pending_valid)begin
					pulse_safe_boundary;    // 提交重搜索产生的任一候选码
				end else if(o_amb_sample_request == 1'b1)begin
					check_condition((periodic_dcs_r_sample_count == 0) &&
						(periodic_dcs_ir_sample_count == 0),
						"PERIODIC AMB samples precede both DCS colors"); // 检查AMB阶段严格在两色DC之前
					periodic_amb_sample_count = periodic_amb_sample_count + 1; // 记录AMB请求被服务
					send_requested_search_sample; // 当前目标码在窗口内且不触发改码
					if(o_amb_sequence_done == 1'b1)begin
						periodic_amb_done_seen = 1'b1; // 捕获AMB阶段完成单拍
					end
				end else if(o_dcs_revalidate_request == 1'b1)begin
					check_condition((periodic_amb_sample_count > 0) && periodic_amb_done_seen,
						"PERIODIC unchanged AMB still requests DCS revalidation"); // 旧实现无法通过的核心回归
					@(negedge i_clk);       // 在稳定低相位接受DCS阶段
					i_dcs_revalidate_accept = 1'b1; // 允许控制器进入红光重验证
					@(negedge i_clk);       // 等待accept被DUT采样
					i_dcs_revalidate_accept = 1'b0; // 撤销保持型接受信号
				end else if(o_dcs_sample_request == 1'b1)begin
					if(o_dcs_sample_color_ir == 1'b0)begin
						check_condition((periodic_amb_sample_count > 0) &&
							(periodic_dcs_ir_sample_count == 0),
							"PERIODIC red DCS follows AMB and precedes infrared"); // 检查红光阶段顺序
						periodic_dcs_r_sample_count = periodic_dcs_r_sample_count + 1; // 记录红光请求
					end else begin
						check_condition(periodic_dcs_r_sample_count > 0,
							"PERIODIC infrared DCS follows red DCS"); // 检查红外不会越过红光
						periodic_dcs_ir_sample_count = periodic_dcs_ir_sample_count + 1; // 记录红外请求
					end
					send_requested_search_sample; // 发送匹配当前DC码的窗口内样本
				end else begin
					@(negedge i_clk);       // 等待下一个序列请求或状态事件
				end
			end
			check_condition(periodic_guard < 40,
				"PERIODIC fixed AMB-R-IR sequence terminates before watchdog"); // 检查状态机有界结束
			check_condition((periodic_amb_sample_count > 0) &&
				(periodic_dcs_r_sample_count > 0) && (periodic_dcs_ir_sample_count > 0),
				"PERIODIC fixed sequence services AMB, red and infrared"); // 检查三路请求均真实出现
			check_condition(o_dcs_revalidate_done && !o_amb_sequence_failed &&
				!o_dcs_revalidate_failed && !o_controller_fault_blocking,
				"PERIODIC fixed sequence completes without failure"); // 检查整体重验证成功
			check_condition((o_amb_code == amb_code_before) &&
				(o_dcs_r_code == dcs_r_code_before) && (o_dcs_ir_code == dcs_ir_code_before) &&
				(o_amb_code_epoch == amb_epoch_before) &&
				(o_dcs_r_code_epoch == dcs_r_epoch_before) &&
				(o_dcs_ir_code_epoch == dcs_ir_epoch_before),
				"PERIODIC in-window revalidation preserves all codes and epochs"); // 检查确认不等于强制调码
		end
	endtask

	// 发送一笔可配置资格、快照和饱和方向的NORMAL跟踪事务
	task send_track_sample;
		input signed [11:0]sample_value;    // 当前NORMAL残差测试值
		input color_ir;                     // 低选择红光且高选择红外
		input precision_mode;               // 低表示9-bit且高表示15-bit
		input calibration_applied;          // 控制样本是否具备正式校准资格
		input snapshot_valid;               // 控制码快照和epoch是否匹配
		input saturation_low;               // 注入明确低侧饱和证据
		input saturation_high;              // 注入明确高侧饱和证据
		begin
			@(negedge i_clk);               // 在非采样沿建立tracking载荷
			i_track_calibrated_s1_value = sample_value; // 驱动signed Stage1残差
			i_track_calibration_applied = calibration_applied; // 驱动校准资格位
			i_track_saturation_low = saturation_low; // 驱动低侧端点标志
			i_track_saturation_high = saturation_high; // 驱动高侧端点标志
			i_track_config_epoch = snapshot_valid ? i_active_config_epoch : (i_active_config_epoch - 8'd1); // 选择新旧配置版本
			i_track_coef_epoch = 8'h31;     // 提供稳定Stage1系数诊断版本
			i_track_precision_mode = precision_mode; // 驱动精度身份而不分裂状态
			i_track_frame_id = i_track_frame_id + 16'd1; // 推进NORMAL帧编号
			i_track_sample_index = i_track_sample_index + 16'd1; // 推进NORMAL事务编号
			i_track_color_ir = color_ir;    // 选择对应颜色计数器
			i_track_frame_type = 2'b10;     // 合格跟踪固定使用NORMAL编码
			i_track_amb_code_snapshot = o_amb_code; // 绑定当前AMB committed码
			i_track_dc_code_snapshot = color_ir ? o_dcs_ir_code : o_dcs_r_code; // 绑定选中颜色DC码
			i_track_amb_code_epoch = o_amb_code_epoch; // 绑定当前AMB提交版本
			i_track_dc_code_epoch = snapshot_valid ?
				(color_ir ? o_dcs_ir_code_epoch : o_dcs_r_code_epoch) :
				((color_ir ? o_dcs_ir_code_epoch : o_dcs_r_code_epoch) - 4'd1); // 选择当前或旧DC版本
			i_track_valid = 1'b1;           // 声明一笔保持型tracking事务
			#1;                             // 允许组合ready稳定
			check_condition(o_track_ready == 1'b1, "tracking branch remains ready for bounded consumption"); // 检查无长期反压
			@(negedge i_clk);               // 等待DUT消费当前tracking事务
			i_track_valid = 1'b0;           // 撤销valid避免重复计数
		end
	endtask

	// 重新启动一轮AUTO_SEARCH_TRACK并配置指定确认数和码范围
	task restart_auto_run;
		input [7:0]confirm_count;           // 新RUN采用的DCS确认次数
		input [7:0]r_min;                   // 新RUN红光DCS下界
		input [7:0]r_max;                   // 新RUN红光DCS上界
		input [7:0]r_target;                // 新RUN红光模拟目标码
		begin
			if(i_run_enable == 1'b1)begin
				pulse_stop;                 // 先停止上一轮并清理pending
			end
			i_active_config_epoch = i_active_config_epoch + 8'd1; // 模拟新ACTIVE原子提交版本
			i_idac_mode = 2'b10;            // 新RUN启用搜索和慢速跟踪
			i_dcs_confirm_count = confirm_count; // 冻结本轮确认次数
			i_amb_code_min = 8'd5;          // 单点AMB范围缩短重启时间
			i_amb_code_max = 8'd5;          // 单点AMB范围固定目标码
			i_amb_manual_code = 8'd5;       // 保持AMB手动字段位于合法范围
			i_dcs_r_code_min = r_min;       // 配置红光DCS测试范围下界
			i_dcs_r_code_max = r_max;       // 配置红光DCS测试范围上界
			i_dcs_r_manual_code = r_target; // 保持红光manual字段在闭区间内
			i_dcs_ir_code_min = 8'd20;      // 保留红外慢速跟踪向下调整空间
			i_dcs_ir_code_max = 8'd30;      // 保留红外慢速跟踪向上调整空间
			i_dcs_ir_manual_code = 8'd24;   // 保持红外manual字段合法
			target_amb_code = 5;            // 设置AMB搜索模型目标
			target_dcs_r_code = r_target;   // 设置红光搜索模型目标
			target_dcs_ir_code = 24;        // 设置红外搜索模型目标
			pulse_start;                    // 进入新的RUN上下文
			complete_startup_search;        // 完成三路启动搜索
		end
	endtask

	// 初始化、执行启动搜索、固定周期重检和IDT-01至IDT-15全部定向检查
	integer c_index;
    reg [7:0] c_expected [0:7];
	initial begin
		i_clk = 1'b0;                       // 时钟初始为低电平
		i_rstn = 1'b0;                      // 初始保持异步复位有效
		i_run_enable = 1'b0;                // 复位期间关闭运行许可
		i_start_ack_event = 1'b0;           // 初始无START事件
		i_run_generation = {C_RUN_GENERATION_WIDTH{1'b0}}; // V2.2:代际全程固定为0
		i_stop_ack_event = 1'b0;            // 初始无STOP事件
		i_status_clear_event = 1'b0;        // 初始无状态清除命令
		i_control_abort_event = 1'b0;       // 初始无控制中止事件
		i_frame_safe_boundary = 1'b0;       // 初始不允许pending提交
		i_active_config_epoch = 8'h20;      // 设置第一轮ACTIVE配置版本
		i_idac_mode = 2'b10;                // 第一轮使用自动搜索跟踪模式
		i_amb_enable = 1'b1;                // 第一轮启用AMB控制
		i_dcs_enable = 1'b1;                // 第一轮启用两色DCS控制
		i_amb_polarity = 1'b1;              // 高残差映射为AMB增码
		i_dcs_polarity = 1'b1;              // 高残差映射为DCS增码
		i_amb_manual_code = 8'd3;           // 保持AMB manual字段合法
		i_amb_code_min = 8'd0;              // 第一轮AMB搜索下界
		i_amb_code_max = 8'd7;              // 第一轮AMB搜索上界
		i_dcs_r_manual_code = 8'd13;        // 保持红光manual字段合法
		i_dcs_r_code_min = 8'd10;           // 第一轮红光搜索下界
		i_dcs_r_code_max = 8'd17;           // 第一轮红光搜索上界
		i_dcs_ir_manual_code = 8'd23;       // 保持红外manual字段合法
		i_dcs_ir_code_min = 8'd20;          // 第一轮红外搜索下界
		i_dcs_ir_code_max = 8'd27;          // 第一轮红外搜索上界
		i_amb_threshold_low = -12'sd10;     // AMB窗口包含零残差
		i_amb_threshold_high = 12'sd10;     // AMB窗口上界设为正十
		i_dcs_threshold_low = -12'sd10;     // DCS窗口下界设为负十
		i_dcs_threshold_high = 12'sd10;     // DCS窗口上界设为正十
		i_amb_confirm_count = 8'd2;         // 周期AMB测试使用两个确认样本
		i_dcs_confirm_count = 8'd3;         // 第一轮跟踪使用三个确认样本
		i_search_amb_valid = 1'b0;          // 初始无AMB_CAL事务
		i_search_dcs_valid = 1'b0;          // 初始无DCS_CAL事务
		i_search_calibrated_s1_value = 12'sd0; // 初始化搜索残差总线
		i_search_calibration_applied = 1'b0; // 复位期间搜索样本无资格
		i_search_saturation_low = 1'b0;     // 初始搜索低饱和无效
		i_search_saturation_high = 1'b0;    // 初始搜索高饱和无效
		i_search_config_epoch = 8'd0;       // 初始化搜索配置版本
		i_search_coef_epoch = 8'd0;         // 初始化搜索系数版本
		i_search_precision_mode = 1'b0;     // 初始化搜索精度为9-bit
		i_search_frame_id = 16'd0;          // 搜索帧编号从零开始
		i_search_sample_index = 16'd0;      // 搜索事务编号从零开始
		i_search_color_ir = 1'b0;           // 初始化搜索颜色为红光
		i_search_frame_type = 2'b00;        // 初始化搜索类别为AMB_CAL
		i_search_amb_code_snapshot = 8'd0;  // 初始化搜索AMB快照
		i_search_dc_code_snapshot = 8'd0;   // 初始化搜索DC快照
		i_search_amb_code_epoch = 4'd0;     // 初始化搜索AMB版本
		i_search_dc_code_epoch = 4'd0;      // 初始化搜索DC版本
		i_track_valid = 1'b0;               // 初始无NORMAL跟踪事务
		i_track_calibrated_s1_value = 12'sd0; // 初始化跟踪残差
		i_track_calibration_applied = 1'b0; // 复位期间跟踪无校准资格
		i_track_saturation_low = 1'b0;      // 初始跟踪低饱和无效
		i_track_saturation_high = 1'b0;     // 初始跟踪高饱和无效
		i_track_config_epoch = 8'd0;        // 初始化跟踪配置版本
		i_track_coef_epoch = 8'd0;          // 初始化跟踪系数版本
		i_track_precision_mode = 1'b0;      // 初始化跟踪精度为9-bit
		i_track_frame_id = 16'd0;           // NORMAL帧编号从零开始
		i_track_sample_index = 16'd0;       // NORMAL事务编号从零开始
		i_track_color_ir = 1'b0;            // 初始化跟踪颜色为红光
		i_track_frame_type = 2'b10;         // 初始化为NORMAL类别
		i_track_amb_code_snapshot = 8'd0;   // 初始化跟踪AMB快照
		i_track_dc_code_snapshot = 8'd0;    // 初始化跟踪DC快照
		i_track_amb_code_epoch = 4'd0;      // 初始化跟踪AMB版本
		i_track_dc_code_epoch = 4'd0;       // 初始化跟踪DC版本
		i_amb_sequence_start = 1'b0;        // 初始不启动周期AMB重检
		i_dcs_revalidate_accept = 1'b0;     // 初始不接受DCS重验证
		error_count = 0;                    // 清零自检失败计数
		target_amb_code = 5;                // 第一轮AMB模拟目标码
		target_dcs_r_code = 15;             // 第一轮红光模拟目标码
		target_dcs_ir_code = 24;            // 第一轮红外模拟目标码
		#(C_CLK_PERIOD * 3);                // 保持复位覆盖多个有效时钟沿
		i_rstn = 1'b1;                      // 释放异步复位
		@(negedge i_clk);                   // 等待复位释放后的稳定半周期
		check_condition((o_amb_code == 8'd0) && (o_dcs_r_code == 8'd0) &&
			(o_dcs_ir_code == 8'd0) && (o_amb_code_epoch == 4'd0) &&
			(o_dcs_r_code_epoch == 4'd0) && (o_dcs_ir_code_epoch == 4'd0) &&
			(o_idac_idle == 1'b1), "RESET three codes, epochs and idle state"); // 检查复位合同
        i_dcs_enable=0; i_amb_code_min=0; i_amb_code_max=255; i_amb_manual_code=0;
        target_amb_code=200;
        c_expected[0]=127; c_expected[1]=191; c_expected[2]=223; c_expected[3]=207;
        c_expected[4]=199; c_expected[5]=203; c_expected[6]=201; c_expected[7]=200;
        pulse_start;
        for(c_index=0;c_index<8;c_index=c_index+1) begin
            pulse_safe_boundary;
            if(o_amb_code!==c_expected[c_index]) $fatal(1,"C_IDAC midpoint[%0d] expected=%0d got=%0d",c_index,c_expected[c_index],o_amb_code);
            if(o_amb_sample_request!==1'b1) $fatal(1,"C_IDAC request missing");
            send_requested_search_sample;
        end
        if(o_startup_search_complete!==1'b1 || o_controller_fault_blocking!==1'b0) $fatal(1,"C_IDAC final qualification");
        $display("C_IDAC_MIDPOINT_PASS count=8 target=200"); $finish;
    end

	// 仿真看门狗用于捕获握手或状态机停滞并保证回归可终止
	initial begin
		#200000;                            // 为多轮启动搜索和IDT场景预留时间
		$display("FAIL: ppg_idac_code_controller V2.1 testbench timeout"); // 报告控制流程未按合同结束
		$finish;                            // 防止工具无限等待
	end

	//------------模块实例化区域------------//
	// 实例化V2.1控制器并逐项连接冻结合同中的全部端口
	ppg_idac_code_controller
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 连接共享帧编号字段宽度
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 连接全局样本编号字段宽度
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH), // 连接三路IDAC码字段宽度
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 连接安全提交版本字段宽度
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 连接ACTIVE配置版本字段宽度
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 连接Stage1系数版本字段宽度
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH) // V2.2:连接RUN代际字段宽度
	)ppg_idac_code_controller_Inst_dut
	(
		.i_clk(i_clk),                      // 连接测试平台主时钟
		.i_rstn(i_rstn),                    // 连接低有效异步复位
		.i_run_enable(i_run_enable),        // 连接RUN生命周期许可
		.i_start_ack_event(i_start_ack_event), // 连接合法START应答事件
		.i_run_generation(i_run_generation), // V2.2:连接固定RUN代际，此前悬空致代际比较为X
		.i_stop_ack_event(i_stop_ack_event), // 连接STOP接受事件
		.i_status_clear_event(i_status_clear_event), // 连接状态清除命令
		.i_control_abort_event(i_control_abort_event), // 连接阻断错误取消事件
		.i_frame_safe_boundary(i_frame_safe_boundary), // 连接pending安全提交边界
		.i_active_config_epoch(i_active_config_epoch), // 连接当前ACTIVE版本
		.i_idac_mode(i_idac_mode),          // 连接IDAC运行模式
		.i_amb_enable(i_amb_enable),        // 连接AMB使能配置
		.i_dcs_enable(i_dcs_enable),        // 连接DCS使能配置
		.i_amb_polarity(i_amb_polarity),    // 连接AMB调码极性
		.i_dcs_polarity(i_dcs_polarity),    // 连接DCS调码极性
		.i_amb_manual_code(i_amb_manual_code), // 连接AMB手动码
		.i_amb_code_min(i_amb_code_min),    // 连接AMB允许下界
		.i_amb_code_max(i_amb_code_max),    // 连接AMB允许上界
		.i_dcs_r_manual_code(i_dcs_r_manual_code), // 连接红光DCS手动码
		.i_dcs_r_code_min(i_dcs_r_code_min), // 连接红光DCS下界
		.i_dcs_r_code_max(i_dcs_r_code_max), // 连接红光DCS上界
		.i_dcs_ir_manual_code(i_dcs_ir_manual_code), // 连接红外DCS手动码
		.i_dcs_ir_code_min(i_dcs_ir_code_min), // 连接红外DCS下界
		.i_dcs_ir_code_max(i_dcs_ir_code_max), // 连接红外DCS上界
		.i_amb_threshold_low(i_amb_threshold_low), // 连接AMB窗口低边界
		.i_amb_threshold_high(i_amb_threshold_high), // 连接AMB窗口高边界
		.i_dcs_threshold_low(i_dcs_threshold_low), // 连接DCS窗口低边界
		.i_dcs_threshold_high(i_dcs_threshold_high), // 连接DCS窗口高边界
		.i_amb_confirm_count(i_amb_confirm_count), // 连接AMB确认次数
		.i_dcs_confirm_count(i_dcs_confirm_count), // 连接DCS确认次数
		.i_search_amb_valid(i_search_amb_valid), // 连接AMB_CAL valid
		.o_search_amb_ready(o_search_amb_ready), // 观测AMB_CAL ready
		.i_search_dcs_valid(i_search_dcs_valid), // 连接DCS_CAL valid
		.o_search_dcs_ready(o_search_dcs_ready), // 观测DCS_CAL ready
		.i_search_calibrated_s1_value(i_search_calibrated_s1_value), // 连接搜索校准残差
		.i_search_calibration_applied(i_search_calibration_applied), // 连接搜索校准资格
		.i_search_saturation_low(i_search_saturation_low), // 连接搜索低侧饱和
		.i_search_saturation_high(i_search_saturation_high), // 连接搜索高侧饱和
		.i_search_config_epoch(i_search_config_epoch), // 连接搜索配置版本
		.i_search_coef_epoch(i_search_coef_epoch), // 连接搜索系数版本
		.i_search_precision_mode(i_search_precision_mode), // 连接搜索精度身份
		.i_search_frame_id(i_search_frame_id), // 连接搜索帧编号
		.i_search_sample_index(i_search_sample_index), // 连接搜索事务编号
		.i_search_color_ir(i_search_color_ir), // 连接搜索颜色身份
		.i_search_frame_type(i_search_frame_type), // 连接搜索事务类别
		.i_search_amb_code_snapshot(i_search_amb_code_snapshot), // 连接搜索AMB快照
		.i_search_dc_code_snapshot(i_search_dc_code_snapshot), // 连接搜索DC快照
		.i_search_amb_code_epoch(i_search_amb_code_epoch), // 连接搜索AMB版本
		.i_search_dc_code_epoch(i_search_dc_code_epoch), // 连接搜索DC版本
		.i_track_valid(i_track_valid),      // 连接NORMAL tracking valid
		.o_track_ready(o_track_ready),      // 观测NORMAL tracking ready
		.i_track_calibrated_s1_value(i_track_calibrated_s1_value), // 连接跟踪校准残差
		.i_track_calibration_applied(i_track_calibration_applied), // 连接跟踪校准资格
		.i_track_saturation_low(i_track_saturation_low), // 连接跟踪低侧饱和
		.i_track_saturation_high(i_track_saturation_high), // 连接跟踪高侧饱和
		.i_track_config_epoch(i_track_config_epoch), // 连接跟踪配置版本
		.i_track_coef_epoch(i_track_coef_epoch), // 连接跟踪系数版本
		.i_track_precision_mode(i_track_precision_mode), // 连接跟踪精度身份
		.i_track_frame_id(i_track_frame_id), // 连接跟踪帧编号
		.i_track_sample_index(i_track_sample_index), // 连接跟踪事务编号
		.i_track_color_ir(i_track_color_ir), // 连接跟踪颜色身份
		.i_track_frame_type(i_track_frame_type), // 连接NORMAL类别编码
		.i_track_amb_code_snapshot(i_track_amb_code_snapshot), // 连接跟踪AMB快照
		.i_track_dc_code_snapshot(i_track_dc_code_snapshot), // 连接跟踪DC快照
		.i_track_amb_code_epoch(i_track_amb_code_epoch), // 连接跟踪AMB版本
		.i_track_dc_code_epoch(i_track_dc_code_epoch), // 连接跟踪DC版本
		.i_amb_sequence_start(i_amb_sequence_start), // 连接周期AMB启动事件
		.o_amb_sample_request(o_amb_sample_request), // 观测AMB样本请求
		.o_amb_sequence_busy(o_amb_sequence_busy), // 观测AMB序列busy
		.o_amb_sequence_done(o_amb_sequence_done), // 观测AMB序列done
		.o_amb_sequence_failed(o_amb_sequence_failed), // 观测AMB序列failed
		.o_dcs_sample_request(o_dcs_sample_request), // 观测DCS样本请求
		.o_dcs_sample_color_ir(o_dcs_sample_color_ir), // 观测DCS请求颜色
		.o_dcs_revalidate_request(o_dcs_revalidate_request), // 观测DCS重验证请求
		.i_dcs_revalidate_accept(i_dcs_revalidate_accept), // 连接DCS重验证accept
		.o_dcs_revalidate_busy(o_dcs_revalidate_busy), // 观测DCS重验证busy
		.o_dcs_revalidate_done(o_dcs_revalidate_done), // 观测DCS重验证done
		.o_dcs_revalidate_failed(o_dcs_revalidate_failed), // 观测DCS重验证failed
		.o_amb_code(o_amb_code),            // 观测AMB committed码
		.o_dcs_r_code(o_dcs_r_code),        // 观测红光DC committed码
		.o_dcs_ir_code(o_dcs_ir_code),      // 观测红外DC committed码
		.o_amb_code_epoch(o_amb_code_epoch), // 观测AMB码版本
		.o_dcs_r_code_epoch(o_dcs_r_code_epoch), // 观测红光DC版本
		.o_dcs_ir_code_epoch(o_dcs_ir_code_epoch), // 观测红外DC版本
		.o_amb_code_update(o_amb_code_update), // 观测AMB更新单拍
		.o_dcs_r_code_update(o_dcs_r_code_update), // 观测红光更新单拍
		.o_dcs_ir_code_update(o_dcs_ir_code_update), // 观测红外更新单拍
		.o_dcs_r_track_adjust(o_dcs_r_track_adjust), // 观测红光跟踪单拍
		.o_dcs_ir_track_adjust(o_dcs_ir_track_adjust), // 观测红外跟踪单拍
		.o_amb_search_done(o_amb_search_done), // 观测AMB搜索done
		.o_dcs_r_search_done(o_dcs_r_search_done), // 观测红光搜索done
		.o_dcs_ir_search_done(o_dcs_ir_search_done), // 观测红外搜索done
		.o_amb_search_exhausted(o_amb_search_exhausted), // 观测AMB搜索耗尽
		.o_dcs_r_search_exhausted(o_dcs_r_search_exhausted), // 观测红光搜索耗尽
		.o_dcs_ir_search_exhausted(o_dcs_ir_search_exhausted), // 观测红外搜索耗尽
		.o_amb_pending_valid(o_amb_pending_valid), // 观测AMB pending
		.o_dcs_r_pending_valid(o_dcs_r_pending_valid), // 观测红光pending
		.o_dcs_ir_pending_valid(o_dcs_ir_pending_valid), // 观测红外pending
		.o_amb_code_at_min(o_amb_code_at_min), // 观测AMB下边界
		.o_amb_code_at_max(o_amb_code_at_max), // 观测AMB上边界
		.o_dcs_r_code_at_min(o_dcs_r_code_at_min), // 观测红光下边界
		.o_dcs_r_code_at_max(o_dcs_r_code_at_max), // 观测红光上边界
		.o_dcs_ir_code_at_min(o_dcs_ir_code_at_min), // 观测红外下边界
		.o_dcs_ir_code_at_max(o_dcs_ir_code_at_max), // 观测红外上边界
		.o_amb_fault(o_amb_fault),          // 观测AMB路径故障
		.o_dcs_r_fault(o_dcs_r_fault),      // 观测红光路径故障
		.o_dcs_ir_fault(o_dcs_ir_fault),    // 观测红外路径故障
		.o_controller_fault_blocking(o_controller_fault_blocking), // 观测汇总阻断故障
		.o_protocol_error_sticky(o_protocol_error_sticky), // 观测协议错误sticky
		.o_startup_search_complete(o_startup_search_complete), // 观测启动搜索完成
		.o_idac_idle(o_idac_idle)           // 观测IDAC控制器排空状态
	);

endmodule
