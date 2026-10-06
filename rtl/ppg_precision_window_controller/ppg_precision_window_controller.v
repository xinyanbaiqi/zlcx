`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026/08/12 00:00:00
// Design Name: 	PPG Precision Window Controller
// Module Name: 	ppg_precision_window_controller
// Description: 	Description/ppg_precision_window_controller_Design.pdf
// Dependencies:
// ppg_dynamic_baseline_cross_detector.v,
// ppg_peak_valley_window_detector.v,
// ppg_amb_recheck_scheduler.v
// ppg_dynamic_baseline_cross_detector.v、
// ppg_peak_valley_window_detector.v、
// Simulations:		TestBench/Vivado/2022.2/ppg_precision_window_controller
//
// Referrences:		PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md
//
//
// Version:			V1.5
// Revision Date:	2026/10/06
// History:
//    Time			   Version	   Revised by			Contents
// 2026/08/12            V1.0          Erie                  Create file.
// 2026/08/22            V1.1          Erie                  Remove i_stop_ack_event/i_control_abort_event direct-clear ports; add PWI-broadcast i_detection_discard group, i_run_generation and o_local_empty per PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md section 18.1a.
// 2026/08/22            V1.2          Erie                  Add i_peak_valley_config_valid (V5 formal-detection gate, PWC-40) and the registered o_mode_fault_active/identity_valid/<FAULT_ID> group for the AMI cause 8'h04 fault dispatcher, per PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md sections 15.3/18.2/18.6.
// 2026/08/23            V1.3          Erie                  Rename i_adc_idle to i_precision_takeover_safe (pure port rename, no logic change) to match PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md sections 18.5/19 literal naming; the connected value was already the AMI composite predicate, never physical ADC idle.
// 2026/09/17            V1.4          Erie                  Fix a real defect: a new legal START (i_start_ack_event) silently cleared the two history stickies switch_timeout_sticky_o and protocol_error_sticky_o, violating contract section 6.2 (:205, a new RUN does not clear history diagnostics) and section 17.1 (:731, a new legal START or STOP by itself does not clear stickies). Both now clear only on i_diag_clear_event; a protocol error raised in the same cycle as a new START is still latched. Covered by PWC-41 (tags at the two clear branches); see PWC_STICKY_CLEAR_RTL_FIX_20260917.md. This changelog entry was recorded on 2026/10/01 (task C) because the header had not been updated with the 09/17 code change; no code changed when it was added.
// 2026/10/06            V1.5          Erie                  ABCD review F-034: flag_enter_commit and flag_return_commit now also require flag_lifecycle_cancel==0, so a current-generation detection discard (or leaving RUN) in the same cycle as the safe frame boundary wins over the precision commit, as the contract freezes (generation discard > safe commit, no precision switch on cancel). Previously the commit still changed the precision while the cancel cleared the window/FSM, leaving precision, window and FSM inconsistent.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026年08月12日
// 设计名称: 		PPG Precision Window Controller
// 模块名称: 		ppg_precision_window_controller
// 模块说明:		Description/ppg_precision_window_controller_Design.pdf
// 依赖文件:
// ppg_dynamic_baseline_cross_detector.v,
// ppg_peak_valley_window_detector.v,
// ppg_amb_recheck_scheduler.v
// ppg_dynamic_baseline_cross_detector.v、
// ppg_peak_valley_window_detector.v、
// 仿真工程: 		TestBench/Vivado/2022.2/ppg_precision_window_controller
//
// 参考资料:		PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.5
// 修订日期:		2026年10月06日
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026年08月12日        V1.0          Erie                  创建文件。
// 2026年08月22日        V1.1          Erie                  删除i_stop_ack_event/i_control_abort_event直接清除端口，按合同18.1a节新增PWI广播的i_detection_discard组、i_run_generation和o_local_empty
// 2026年08月22日        V1.2          Erie                  按合同15.3/18.2/18.6节新增i_peak_valley_config_valid（V5正式检测门控，PWC-40）和注册式o_mode_fault_active/identity_valid/<FAULT_ID>组，供AMI cause 8'h04故障分发器观测
// 2026年08月23日        V1.3          Erie                  按合同18.5/19节把i_adc_idle改名为i_precision_takeover_safe（纯端口改名，不改逻辑）——该端口连接的值本来就是AMI导出的复合资格，从未是物理ADC空闲
// 2026年09月17日        V1.4          Erie                  修复一个真实缺陷：新的合法START（i_start_ack_event）会悄悄清掉switch_timeout_sticky_o和protocol_error_sticky_o两个历史sticky，违反合同6.2节（:205，新RUN不清除历史诊断）与17.1节（:731，新的合法START和STOP本身不清sticky）。两者现在只在i_diag_clear_event时清除；与新START同拍出现的协议异常仍会被锁存。由PWC-41覆盖（两个清除分支处已打标签），详见PWC_STICKY_CLEAR_RTL_FIX_20260917.md。本条于2026年10月01日（任务C）补记，因为09月17日改代码时没有同步文件头；补记本身不改任何代码。
// 2026年10月06日        V1.5          Erie                  ABCD复核F-034：flag_enter_commit与flag_return_commit增加flag_lifecycle_cancel==0条件，安全帧边界与当前代际detection discard（或离开RUN）同拍时撤销优先于精度提交，符合合同冻结的"代际discard > 安全提交，撤销不得产生精度切换"。此前提交仍改精度而撤销清窗口和状态机，三者不一致
// 在下一安全400 Hz帧原子提交9-bit或15-bit模式，并协调异常重新获取和重检事件
module ppg_precision_window_controller
#(
	parameter C_FRAME_ID_WIDTH = 16,            // 统一400 Hz物理帧号宽度
	parameter C_SAMPLE_INDEX_WIDTH = 16,        // 相交事务序号字段宽度
	parameter C_CONFIG_EPOCH_WIDTH = 8,         // ACTIVE配置版本字段宽度
	parameter C_COEF_EPOCH_WIDTH = 8,           // Stage1校准系数版本字段宽度
	parameter C_DC_RECOVERY_EPOCH_WIDTH = 8,    // DC恢复系数版本字段宽度
	parameter C_SWITCH_TIMEOUT_CYCLES = 10000,  // 模拟精度安全提交的最大等待周期
	parameter C_SWITCH_TIMEOUT_COUNTER_WIDTH = 14, // 覆盖两帧保护阈值的计数宽度
	parameter C_CODE_EPOCH_WIDTH = 4,           // discard组诊断用AMB/DC码版本字段宽度
	parameter C_RUN_GENERATION_WIDTH = 8        // manager唯一生产、由PWI逐层广播的RUN代际字段宽度
)
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 2 MHz数字处理时钟
	input i_rstn,                               // 低有效异步复位输入

	//---------------生命周期接口---------------//
	input i_run_enable,                         // 生命周期管理器声明当前处于RUN
	input i_start_ack_event,                    // 新RUN被正式接受的初始化单拍
	input i_diag_clear_event,                   // 软件清除历史sticky的单拍

	//-------AMI/PWI检测代际清空接口-------//
	input i_detection_discard_event,       // PWI原样广播的AMI注册式代际清空事件，无ready/ack
	input [1:0]i_detection_discard_reason, // 清空原因分类，取值含STOP排空、abort撤销、系统故障三类
	input i_detection_discard_identity_valid, // 触发事务身份是否可信，为0时是合法scope-only清空
	input i_detection_discard_sample_valid, // 触发事务的独立样本资格快照
	input [C_FRAME_ID_WIDTH - 1:0]i_detection_discard_frame_id, // 触发事务帧号，仅诊断用途
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_detection_discard_sample_index, // 触发事务序号，仅诊断用途
	input i_detection_discard_color_ir,    // 触发事务颜色，仅诊断用途
	input [1:0]i_detection_discard_frame_type, // 触发事务类型，仅诊断用途
	input i_detection_discard_precision,   // 触发事务精度，仅诊断用途
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_detection_discard_config_epoch, // 触发事务ACTIVE版本，仅诊断用途
	input [C_COEF_EPOCH_WIDTH - 1:0]i_detection_discard_coef_epoch, // 触发事务Stage1系数版本，仅诊断用途
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_detection_discard_dc_recovery_epoch, // 触发事务DC恢复版本，仅诊断用途
	input [C_CODE_EPOCH_WIDTH - 1:0]i_detection_discard_amb_code_epoch, // 触发事务环境光抵消码提交版本，仅诊断用途
	input [C_CODE_EPOCH_WIDTH - 1:0]i_detection_discard_dc_code_epoch, // 触发事务颜色DC码提交版本，仅诊断用途
	input [C_RUN_GENERATION_WIDTH - 1:0]i_detection_discard_run_generation, // 本次清空目标RUN代际
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // PWI层级扇出的当前RUN代际实时快照
	output o_local_empty,                  // 本模块无pending、无延迟动作且无故障保持时为高，唯一消费者PWI

	//--------------ACTIVE配置接口--------------//
	input i_active_config_valid,                // 已提交ACTIVE配置通过合法性检查
	input i_run_profile,                        // 低为NORMAL_PPG且高为CHARACTERIZATION
	input i_initial_precision,                  // CHARACTERIZATION启动时采用的固定精度
	input i_normal_measurement_active,          // 启动校准完成且允许正式NORMAL事务
	input i_peak_valley_config_valid,           // PWI经AMI注册转发的V5正式检测资格，为0禁止新cross消费

	//---------------相交请求接口---------------//
	input i_cross_valid,                        // 动态基线保持的进入15-bit请求
	output o_cross_ready,                       // 控制器允许消费当前相交载荷
	input [C_FRAME_ID_WIDTH - 1:0]i_cross_frame_id, // 相交中心对应的真实物理帧号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_cross_sample_index, // 相交中心对应的ADC事务号
	input i_cross_time_unknown,                 // 相交发生时间缺少正式中心样本证明
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_cross_config_epoch, // 相交事务绑定的ACTIVE版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_cross_coef_epoch, // 相交事务绑定的Stage1系数版本
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_cross_dc_recovery_coef_epoch, // 相交事务绑定的DC恢复版本

	//---------------返回请求接口---------------//
	input i_return_9bit_valid,                  // 峰谷检测器保持的返回9-bit请求
	output o_return_9bit_ready,                 // 控制器允许消费当前返回载荷
	input [1:0]i_return_reason,                 // 波谷成功、窗口超时或协议回退原因
	input [C_FRAME_ID_WIDTH - 1:0]i_return_frame_id, // 返回结论绑定的真实检测帧号

	//---------------安全提交接口---------------//
	input i_frame_safe_boundary,                // 下一物理帧开始前的安全边界单拍
	input [C_FRAME_ID_WIDTH - 1:0]i_safe_frame_id, // 即将采用新精度的物理帧号
	input i_precision_takeover_safe,            // PWI原样转发AMI复合资格：物理ADC/DONE已空闲，且ADC事务、异步capture和结果所有权已排空；不是物理idle事实
	input i_analog_safe,                        // 模拟相位允许修改下一帧精度
	input i_recheck_busy,                       // AMB/DC重检及FIR恢复占用测量调度

	//------------精度与控制事件输出------------//
	output o_active_precision_mode,             // 当前唯一已提交的采集精度
	output o_fine_window_active,                // 正式相交建立的15-bit窗口资格
	output o_fine_window_start_event,           // 真实进入正式15-bit窗口的单拍
	output [C_FRAME_ID_WIDTH - 1:0]o_fine_window_start_frame_id, // 第一笔正式15-bit帧号
	output o_precision_15_to_9_event,           // 正式窗口真实返回9-bit的单拍
	output [C_FRAME_ID_WIDTH - 1:0]o_precision_15_to_9_frame_id, // 第一笔恢复9-bit帧号
	output o_reacquire_request_event,           // 异常返回后废止旧基线的单拍
	output o_mode_fault_event,                  // 切换超时或阻断协议故障单拍
	output o_mode_fault_active,                 // 当前RUN代际的精度阻断故障保持电平，仅discard/reset解除；本模块唯一故障出口，无直连manager/supervisor路径，是cause 8'h04分发链起点 @satisfies: K01, K05, G-FP-03
	output o_mode_fault_identity_valid,         // 故障是否绑定真实事务身份
	output [C_FRAME_ID_WIDTH - 1:0]o_mode_fault_frame_id, // 故障绑定事务的真实物理帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_mode_fault_sample_index, // 故障绑定事务的全局事务号
	output o_mode_fault_color_ir,               // 精度控制器只处理RED来源事务，恒为0
	output [1:0]o_mode_fault_frame_type,        // 触发事务类别，有效时恒为NORMAL编码
	output o_mode_fault_precision,              // 故障绑定事务建立时所属的精度模式
	output [C_RUN_GENERATION_WIDTH - 1:0]o_mode_fault_run_generation, // 故障绑定的RUN代际

	//---------------状态诊断接口---------------//
	output o_switch_pending,                    // 已接受请求且等待安全边界提交
	output o_switch_target_precision,           // 当前pending要求的目标精度
	output o_switch_hold_new_transaction,       // 顶层必须阻止新ADC事务
	output o_controller_idle,                   // 当前没有控制事务或故障保持
	output o_last_cross_time_unknown,           // 最近接受相交请求的时间诊断
	output [1:0]o_last_return_reason,           // 最近接受返回请求的原因
	output o_switch_timeout_sticky,             // 至少一次模式安全提交超时历史
	output o_protocol_error_sticky              // 至少一次精度控制协议异常历史
);

	//---------------配置参数区域---------------//
	// 精度和返回原因编码由冻结合同统一定义
	localparam PRECISION_9BIT = 1'b0;           // 粗采样模式编码
	localparam PRECISION_15BIT = 1'b1;          // 高精度采样模式编码
	localparam RUN_PROFILE_NORMAL = 1'b0;       // 自动PPG精度窗口运行配置
	localparam RUN_PROFILE_CHARACTERIZATION = 1'b1; // 固定精度片外表征配置
	localparam [1:0]RETURN_VALLEY_CONFIRMED = 2'b00; // 正常波谷经过后的返回原因
	localparam [1:0]RETURN_FINE_TIMEOUT = 2'b01; // 精细窗口未闭合的超时原因
	localparam [1:0]RETURN_PROTOCOL_FALLBACK = 2'b10; // 峰谷协议异常的回退原因
	localparam [1:0]RETURN_RESERVED = 2'b11;    // 非法保留原因需要归一化回退
	localparam [C_SWITCH_TIMEOUT_COUNTER_WIDTH - 1:0]TIMEOUT_LIMIT_MINUS_ONE = (C_SWITCH_TIMEOUT_CYCLES <= 1) ? {C_SWITCH_TIMEOUT_COUNTER_WIDTH{1'b0}} : C_SWITCH_TIMEOUT_CYCLES - 1; // 超时关系比较使用固定目标位宽

	//---------------状态参数区域---------------//
	// 状态机分离空闲、两种提交等待、异常事件交付和故障保持
	localparam [2:0]ST_IDLE = 3'd0;             // 当前没有待提交精度请求
	localparam [2:0]ST_WAIT_ENTER = 3'd1;       // 已接受相交并等待15-bit安全提交
	localparam [2:0]ST_FINE = 3'd2;             // 正式15-bit窗口正在运行
	localparam [2:0]ST_WAIT_RETURN = 3'd3;      // 已接受返回并等待9-bit安全提交
	localparam [2:0]ST_REACQUIRE = 3'd4;        // 异常返回提交后交付重新获取事件
	localparam [2:0]ST_FAULT = 3'd5;            // 超时后保持原精度并阻断新事务

	//---------------计数信号区域---------------//
	reg [C_SWITCH_TIMEOUT_COUNTER_WIDTH - 1:0]cnt_switch_timeout; // 已等待安全提交的2 MHz周期数

	//--------------状态机信号区域--------------//
	reg [2:0]state_current;                     // 当前精度控制阶段
	reg [2:0]state_next;                        // 下一拍精度控制阶段

	//--------------寄存器信号区域--------------//
	reg [C_FRAME_ID_WIDTH - 1:0]reg_cross_frame_snapshot; // 相交请求中心帧原子快照
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_cross_sample_snapshot; // 相交请求事务号原子快照
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]reg_cross_config_snapshot; // 相交请求ACTIVE版本原子快照
	reg [C_COEF_EPOCH_WIDTH - 1:0]reg_cross_coef_snapshot; // 相交沿采用的Stage1校准代次
	reg [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]reg_cross_dc_snapshot; // 相交请求DC恢复版本原子快照
	reg [C_FRAME_ID_WIDTH - 1:0]reg_return_frame_snapshot; // 返回结论真实帧原子快照

	//---------------标志信号区域---------------//
	reg flag_pending_return_reacquire;          // 当前返回提交后需要重新获取
	reg flag_fault_hold;                        // 超时后持续阻止新事务的活动故障
	reg flag_pending_cross_time_unknown;        // pending进入请求的时间未知快照
	reg flag_pending_cross;                     // 当前pending来自相交请求
	reg flag_pending_return;                    // 当前pending来自返回请求
	reg flag_return_reserved;                   // 当前返回原因原始值为保留编码
	reg flag_return_protocol_fallback;          // 峰谷协议回退原因需要锁存诊断
	reg flag_protocol_fault_pulse;              // 当前拍需要报告阻断协议故障
	reg flag_normal_start_illegal;              // NORMAL使用15-bit初始精度的非法组合
	reg flag_characterization_request;          // 表征模式收到自动精度请求
	reg flag_duplicate_cross;                   // 等待期间出现第二笔相交请求
	reg flag_duplicate_return;                  // 等待期间出现第二笔返回请求
	reg flag_cross_return_collision;            // 相交和返回在同拍同时有效
	reg flag_recheck_in_fine;                   // 正式窗口观察到重检busy异常
	reg flag_invalid_direction_request;         // 当前精度不允许对应请求方向
	reg flag_active_config_fault;               // START时ACTIVE配置无效
	reg flag_leave_run_cancel;                  // 生命周期离开RUN时撤销控制上下文
	wire flag_cross_transfer;                   // 相交ready和valid真实传输事件
	wire flag_return_transfer;                  // 返回ready和valid真实传输事件
	wire flag_normal_cross_transfer;            // NORMAL模式取得正式相交请求所有权
	wire flag_normal_return_transfer;           // NORMAL模式取得正式返回请求所有权
	wire flag_enter_commit;                     // 等待进入状态满足安全提交条件
	wire flag_return_commit;                    // 等待返回状态满足安全提交条件
	wire flag_switch_timeout_event;             // 当前拍达到有界等待上限
	wire flag_lifecycle_cancel;                 // STOP、abort或离开RUN撤销控制
	wire flag_protocol_error_event;             // 当前拍任一协议异常汇总
	wire flag_blocking_protocol_fault;          // 当前拍需要进入故障保持的协议异常
	wire flag_pending_state;                    // 当前处于任一安全提交等待状态

	//---------------编码信号区域---------------//
	reg [1:0]enc_return_reason_snapshot;        // 归一化返回原因原子快照

	//---------------其他信号区域---------------//
	// 本模块没有无法归入计数、状态、寄存、标志或编码类别的内部信号

	//---------------输出信号区域---------------//
	//精度与控制事件输出
	reg active_precision_mode_o;                // 唯一已提交精度输出桥接寄存器
	reg fine_window_active_o;                   // 正式fine窗口输出桥接寄存器
	reg fine_window_start_event_o;              // 进入15-bit提交事件寄存器
	reg [C_FRAME_ID_WIDTH - 1:0]fine_window_start_frame_id_o; // 第一笔正式15-bit帧号寄存器
	reg precision_15_to_9_event_o;              // 返回9-bit提交事件寄存器
	reg [C_FRAME_ID_WIDTH - 1:0]precision_15_to_9_frame_id_o; // 第一笔恢复9-bit帧号寄存器
	reg reacquire_request_event_o;              // 异常重新获取事件寄存器
	reg mode_fault_event_o;                     // 控制故障单拍寄存器
	reg fault_identity_valid_o;                 // 故障是否绑定真实事务身份寄存器
	reg [C_FRAME_ID_WIDTH - 1:0]fault_frame_id_o; // 故障绑定事务真实物理帧号寄存器
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]fault_sample_index_o; // 故障绑定事务全局事务号寄存器
	reg fault_precision_o;                      // 故障绑定事务建立时活动精度寄存器
	reg [C_RUN_GENERATION_WIDTH - 1:0]fault_run_generation_o; // 故障绑定RUN代际寄存器

	//状态诊断接口
	reg switch_pending_o;                       // pending占用输出桥接
	reg switch_target_precision_o;              // pending目标精度输出桥接
	reg switch_hold_new_transaction_o;          // 新事务阻断输出桥接
	reg controller_idle_o;                      // 控制事务排空输出桥接
	reg last_cross_time_unknown_o;              // 最近相交时间诊断输出桥接
	reg [1:0]last_return_reason_o;              // 最近返回原因输出桥接寄存器
	reg switch_timeout_sticky_o;                // 切换超时sticky寄存器
	reg protocol_error_sticky_o;                // 协议异常sticky寄存器

	//-------------其他信号连线区域-------------//
	// ready只在当前运行语义允许的唯一请求方向上开放
	assign flag_cross_transfer = i_cross_valid && o_cross_ready; // 相交载荷只在真实握手沿取得所有权; @satisfies: PWC-07
	assign flag_return_transfer = i_return_9bit_valid && o_return_9bit_ready; // 返回载荷只在真实握手沿取得所有权; @satisfies: PWC-14

	//其他信号连线
	assign flag_normal_cross_transfer = flag_cross_transfer && (i_run_profile == RUN_PROFILE_NORMAL); // 表征模式请求只消费不建立窗口
	assign flag_normal_return_transfer = flag_return_transfer && (i_run_profile == RUN_PROFILE_NORMAL); // 表征模式返回只消费不改变精度
	assign flag_enter_commit = (state_current == ST_WAIT_ENTER) && i_frame_safe_boundary && i_precision_takeover_safe && i_analog_safe && (i_recheck_busy == 1'b0) && (flag_lifecycle_cancel == 1'b0); // 下一安全帧原子进入15-bit；同拍当前代际discard或离开RUN撤销优先，不提交精度; @satisfies: PWC-09, PWC-22, PWC-37, PWC-27
	assign flag_return_commit = (state_current == ST_WAIT_RETURN) && i_frame_safe_boundary && i_precision_takeover_safe && i_analog_safe && (flag_lifecycle_cancel == 1'b0); // 下一安全帧原子返回9-bit；同拍撤销优先，不产生精度切换; @satisfies: PWC-32, PWC-38, PWC-27
	assign flag_pending_state = (state_current == ST_WAIT_ENTER) || (state_current == ST_WAIT_RETURN); // 两种pending状态共享超时保护; @satisfies: PWC-39
	assign flag_lifecycle_cancel = (i_detection_discard_event && (i_detection_discard_run_generation == i_run_generation)) || flag_leave_run_cancel; // PWI广播的代际清空事件命中当前代际时统一撤销在途请求；仅generation-scoped discard参与，复位分支独立不经此路径；G-FP-02精度切换pending的STOP/abort/system fault释放路径 @satisfies: K04, N02, G-FP-02, PWC-27, PWC-28
	assign flag_switch_timeout_event = flag_pending_state && (flag_enter_commit == 1'b0) && (flag_return_commit == 1'b0) && (cnt_switch_timeout >= TIMEOUT_LIMIT_MINUS_ONE); // 安全提交与阈值同拍时提交优先; @satisfies: PWC-25
	assign flag_protocol_error_event = flag_normal_start_illegal || flag_characterization_request || flag_duplicate_cross || flag_duplicate_return || flag_cross_return_collision || flag_recheck_in_fine || flag_invalid_direction_request || flag_return_reserved || flag_return_protocol_fallback || flag_active_config_fault; // 汇总所有合同定义的协议异常

	//其他信号连线
	assign flag_blocking_protocol_fault = flag_normal_start_illegal || flag_active_config_fault; // START配置故障需要阻断当前RUN

	//-------------输出信号连线区域-------------//
	//相交请求接口
	// 请求ready不会因对方未握手载荷而组合采样上下文
	assign o_cross_ready = i_run_enable && i_active_config_valid && i_peak_valley_config_valid && (flag_fault_hold == 1'b0) && (((i_run_profile == RUN_PROFILE_NORMAL) && i_normal_measurement_active && (state_current == ST_IDLE) && (active_precision_mode_o == PRECISION_9BIT) && (fine_window_active_o == 1'b0) && (i_recheck_busy == 1'b0)) || (i_run_profile == RUN_PROFILE_CHARACTERIZATION)); // NORMAL建立窗口而表征模式只安全消费，V5无效时禁止接纳新cross；peak_valley_config_valid链末端消费点；低幅度输入没有真实CROSS就不接纳进入15-bit请求，杜绝伪造fine窗口 @satisfies: G-FP-01-D01-04, PRC-02, PWC-06, PWC-21, PWC-40

	//返回请求接口
	assign o_return_9bit_ready = i_run_enable && (flag_fault_hold == 1'b0) && (((i_run_profile == RUN_PROFILE_NORMAL) && (state_current == ST_FINE) && (active_precision_mode_o == PRECISION_15BIT) && fine_window_active_o) || (i_run_profile == RUN_PROFILE_CHARACTERIZATION)); // 正式fine接受返回且表征模式仅诊断消费

	//精度与控制事件输出
	// 精度、事件和诊断均通过内部桥接信号导出
	assign o_active_precision_mode = active_precision_mode_o; // 导出当前唯一committed精度; @satisfies: PWC-36
	assign o_fine_window_active = fine_window_active_o; // 导出正式15-bit窗口资格
	assign o_fine_window_start_event = fine_window_start_event_o; // 导出进入提交单拍
	assign o_fine_window_start_frame_id = fine_window_start_frame_id_o; // 导出首个正式15-bit帧号
	assign o_precision_15_to_9_event = precision_15_to_9_event_o; // 导出实际返回9-bit单拍
	assign o_precision_15_to_9_frame_id = precision_15_to_9_frame_id_o; // 导出首个恢复9-bit帧号
	assign o_reacquire_request_event = reacquire_request_event_o; // 导出异常返回重新获取单拍
	assign o_mode_fault_event = mode_fault_event_o; // 导出阻断故障报告单拍
	assign o_mode_fault_active = flag_fault_hold; // 导出当前代际故障保持电平
	assign o_mode_fault_identity_valid = fault_identity_valid_o; // 导出故障身份是否可信
	assign o_mode_fault_frame_id = fault_frame_id_o; // 导出故障绑定事务帧号，捕获时已按有效性清零
	assign o_mode_fault_sample_index = fault_sample_index_o; // 导出故障绑定事务全局序号，捕获时已按有效性清零
	assign o_mode_fault_color_ir = 1'b0;        // 本模块只处理RED来源事务，颜色恒为0
	assign o_mode_fault_frame_type = fault_identity_valid_o ? 2'b10 : 2'b00; // 有效时固定输出NORMAL类别
	assign o_mode_fault_precision = fault_precision_o; // 导出故障绑定事务建立时的精度模式
	assign o_mode_fault_run_generation = fault_run_generation_o; // 导出故障绑定的RUN代际

	//状态诊断接口
	// pending和历史诊断不承担FIR精度尾部计数责任
	assign o_switch_pending = switch_pending_o; // 导出请求所有权占用状态
	assign o_switch_target_precision = switch_target_precision_o; // 导出当前pending目标精度
	assign o_switch_hold_new_transaction = switch_hold_new_transaction_o; // 导出事务启动阻断条件
	assign o_controller_idle = controller_idle_o; // 导出控制事务排空状态
	assign o_local_empty = controller_idle_o;   // 控制事务排空状态同时满足本地排空定义
	assign o_last_cross_time_unknown = last_cross_time_unknown_o; // 导出最近相交时间属性
	assign o_last_return_reason = last_return_reason_o; // 导出最近返回原因
	assign o_switch_timeout_sticky = switch_timeout_sticky_o; // 导出切换超时历史
	assign o_protocol_error_sticky = protocol_error_sticky_o; // 导出协议异常历史

	//-------------输出信号处理区域-------------//
	//精度与控制事件输出
	// 活动精度只在复位、合法START和真实安全提交沿修改
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			active_precision_mode_o <= PRECISION_9BIT; // 复位固定安全9-bit; @satisfies: PWC-01
		end else if(i_start_ack_event == 1'b1)begin
			if(i_active_config_valid == 1'b0 || ((i_run_profile == RUN_PROFILE_NORMAL) && i_initial_precision == 1'b1))begin
				active_precision_mode_o <= PRECISION_9BIT; // 非法NORMAL配置强制安全精度
			end else if(i_run_profile == RUN_PROFILE_CHARACTERIZATION)begin
				active_precision_mode_o <= i_initial_precision; // 表征RUN固定采用配置精度; @satisfies: PWC-04, PWC-05
			end else begin
				active_precision_mode_o <= PRECISION_9BIT; // 合法NORMAL固定粗精度启动; @satisfies: PWC-02
			end
		end else if(flag_enter_commit == 1'b1)begin
			active_precision_mode_o <= PRECISION_15BIT; // 安全边界提交高精度
		end else if(flag_return_commit == 1'b1)begin
			active_precision_mode_o <= PRECISION_9BIT; // 安全边界恢复粗精度
		end else begin
			active_precision_mode_o <= active_precision_mode_o; // STOP和abort不在转换中途改精度
		end
	end

	// 正式fine资格只由NORMAL相交提交建立并由返回或生命周期清除
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fine_window_active_o <= 1'b0;       // 复位不存在正式fine窗口
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			fine_window_active_o <= 1'b0;       // 生命周期边界废止旧窗口资格
		end else if(flag_enter_commit == 1'b1)begin
			fine_window_active_o <= 1'b1;       // 进入提交后开启正式fine资格
		end else if(flag_return_commit == 1'b1)begin
			fine_window_active_o <= 1'b0;       // 真实9-bit提交立即结束窗口
		end else begin
			fine_window_active_o <= fine_window_active_o; // 其他拍保持窗口身份
		end
	end

	// 进入15-bit事件固定在安全提交沿保持一个2 MHz周期
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fine_window_start_event_o <= 1'b0;  // 复位清除提交单拍
		end else if(flag_enter_commit == 1'b1)begin
			fine_window_start_event_o <= 1'b1;  // 真实进入提交产生事件
		end else begin
			fine_window_start_event_o <= 1'b0;  // 非提交拍自动撤销
		end
	end

	// 第一笔正式15-bit帧号只在进入提交沿更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fine_window_start_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除历史帧号
		end else if(flag_enter_commit == 1'b1)begin
			fine_window_start_frame_id_o <= i_safe_frame_id; // 记录真实安全边界帧号; @satisfies: PWC-10
		end else begin
			fine_window_start_frame_id_o <= fine_window_start_frame_id_o; // 其他拍保持最近提交
		end
	end

	// 返回9-bit事件固定在安全提交沿保持一个2 MHz周期
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			precision_15_to_9_event_o <= 1'b0;  // 复位清除返回单拍
		end else if(flag_return_commit == 1'b1)begin
			precision_15_to_9_event_o <= 1'b1;  // 正式窗口真实恢复9-bit; @satisfies: PWC-20
		end else begin
			precision_15_to_9_event_o <= 1'b0;  // 其他拍不伪造切换事件
		end
	end

	// 第一笔恢复9-bit帧号只在返回提交沿更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			precision_15_to_9_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除返回帧历史
		end else if(flag_return_commit == 1'b1)begin
			precision_15_to_9_frame_id_o <= i_safe_frame_id; // 锁存真实粗精度首帧; @satisfies: PWC-19
		end else begin
			precision_15_to_9_frame_id_o <= precision_15_to_9_frame_id_o; // 非提交拍保持
		end
	end

	// 异常返回在9-bit提交后的下一拍交付一次重新获取请求
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reacquire_request_event_o <= 1'b0;  // 复位清除重获单拍
		end else if(state_current == ST_REACQUIRE)begin
			reacquire_request_event_o <= 1'b1;  // 下游此时已观察稳定9-bit精度; @satisfies: PWC-16
		end else begin
			reacquire_request_event_o <= 1'b0;  // 其他拍不重复请求
		end
	end

	// 模式故障事件覆盖切换超时和START阻断配置错误
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			mode_fault_event_o <= 1'b0;         // 复位清除故障报告单拍
		end else if(flag_switch_timeout_event == 1'b1 || flag_protocol_fault_pulse == 1'b1 || (flag_return_commit == 1'b1 && i_recheck_busy == 1'b1))begin
			mode_fault_event_o <= 1'b1;         // 当前拍向生命周期管理器报告阻断故障
		end else begin
			mode_fault_event_o <= 1'b0;         // 非故障拍自动清零
		end
	end

	// 故障身份有效性与三个触发源共享同一拍：切换超时和return期间recheck busy绑定真实事务，START阻断无身份
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fault_identity_valid_o <= 1'b0;     // 复位清除历史身份有效位
		end else if(flag_switch_timeout_event == 1'b1 || (flag_return_commit == 1'b1 && i_recheck_busy == 1'b1))begin
			fault_identity_valid_o <= 1'b1;     // 绑定真实pending事务身份
		end else if(flag_protocol_fault_pulse == 1'b1)begin
			fault_identity_valid_o <= 1'b0;     // START阻断异常没有具体事务可绑定
		end else begin
			fault_identity_valid_o <= fault_identity_valid_o; // 非故障拍保持历史身份有效性
		end
	end

	// 故障帧号在超时或return提交故障沿从对应pending快照原子锁存，非法START清零
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fault_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位撤销上一次故障绑定的帧号快照
		end else if(flag_switch_timeout_event == 1'b1)begin
			fault_frame_id_o <= flag_pending_cross ? reg_cross_frame_snapshot : reg_return_frame_snapshot; // 按pending类型选择快照来源
		end else if(flag_return_commit == 1'b1 && i_recheck_busy == 1'b1)begin
			fault_frame_id_o <= reg_return_frame_snapshot; // return提交沿使用返回快照
		end else if(flag_protocol_fault_pulse == 1'b1)begin
			fault_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}}; // START阻断异常没有具体帧号
		end else begin
			fault_frame_id_o <= fault_frame_id_o; // 非故障拍保持历史帧号
		end
	end

	// 故障事务号只有相交请求携带，return类触发恒为0
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 复位清除历史事务号
		end else if(flag_switch_timeout_event == 1'b1)begin
			fault_sample_index_o <= flag_pending_cross ? reg_cross_sample_snapshot : {C_SAMPLE_INDEX_WIDTH{1'b0}}; // return类pending没有事务号字段
		end else if(flag_return_commit == 1'b1 && i_recheck_busy == 1'b1)begin
			fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // return提交沿本身不携带事务号
		end else if(flag_protocol_fault_pulse == 1'b1)begin
			fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // START阻断异常没有具体事务号
		end else begin
			fault_sample_index_o <= fault_sample_index_o; // 非故障拍保持历史事务号
		end
	end

	// 故障精度按触发来源固定：相交源自9-bit，return源自15-bit
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fault_precision_o <= 1'b0;          // 复位清除历史精度快照
		end else if(flag_switch_timeout_event == 1'b1)begin
			fault_precision_o <= flag_pending_cross ? PRECISION_9BIT : PRECISION_15BIT; // 按pending方向确定原精度
		end else if(flag_return_commit == 1'b1 && i_recheck_busy == 1'b1)begin
			fault_precision_o <= PRECISION_15BIT; // return提交沿必然源自正式15-bit窗口
		end else if(flag_protocol_fault_pulse == 1'b1)begin
			fault_precision_o <= 1'b0;          // START阻断异常没有具体精度身份
		end else begin
			fault_precision_o <= fault_precision_o; // 非故障拍保持历史精度快照
		end
	end

	// 故障代际固定锁存当前RUN代际，供AMI/supervisor核对是否跨代际
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fault_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 复位清除历史代际快照
		end else if(flag_switch_timeout_event == 1'b1 || (flag_return_commit == 1'b1 && i_recheck_busy == 1'b1))begin
			fault_run_generation_o <= i_run_generation; // 绑定触发沿的当前RUN代际
		end else if(flag_protocol_fault_pulse == 1'b1)begin
			fault_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // START阻断异常没有具体代际身份
		end else begin
			fault_run_generation_o <= fault_run_generation_o; // 非故障拍保持历史代际快照
		end
	end

	//状态诊断接口
	// 超时sticky独立记录历史且诊断清除不解除活动故障
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			switch_timeout_sticky_o <= 1'b0;    // 复位清除超时历史
		end else if(i_diag_clear_event == 1'b1)begin
			switch_timeout_sticky_o <= 1'b0;    // 仅软件诊断清除可清历史，新START/STOP不清（合同:205/:731）; @satisfies: PWC-41
		end else if(flag_switch_timeout_event == 1'b1)begin
			switch_timeout_sticky_o <= 1'b1;    // 达到两帧保护阈值锁存历史
		end else begin
			switch_timeout_sticky_o <= switch_timeout_sticky_o; // 未触发时保持
		end
	end

	// 协议sticky覆盖非法配置、方向、重复请求和状态关系异常
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			protocol_error_sticky_o <= 1'b0;    // 复位清除协议历史
		end else if(i_diag_clear_event == 1'b1)begin
			protocol_error_sticky_o <= 1'b0;    // 软件只清除历史标志，新START/STOP不清（合同:205/:731）
		end else if(flag_protocol_error_event == 1'b1)begin
			protocol_error_sticky_o <= 1'b1;    // 任一协议异常锁存历史（含新START同拍触发的协议异常）
		end else begin
			protocol_error_sticky_o <= protocol_error_sticky_o; // 无新异常时保持，新START本身不清; @satisfies: PWC-33, PWC-41
		end
	end

	// pending占用状态由状态机直接编码并在提交沿保持阻断
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			switch_pending_o <= 1'b0;           // 复位不存在待提交请求
		end else if(state_next == ST_WAIT_ENTER || state_next == ST_WAIT_RETURN)begin
			switch_pending_o <= 1'b1;           // 下一状态拥有模式请求; @satisfies: PWC-23
		end else begin
			switch_pending_o <= 1'b0;           // 提交、取消或故障释放pending
		end
	end

	// pending目标精度在请求握手时确定且不被重复请求覆盖
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			switch_target_precision_o <= PRECISION_9BIT; // 复位诊断目标为安全粗精度
		end else if(flag_cross_transfer == 1'b1)begin
			switch_target_precision_o <= PRECISION_15BIT; // 相交请求目标固定高精度
		end else if(flag_return_transfer == 1'b1)begin
			switch_target_precision_o <= PRECISION_9BIT; // 返回请求目标固定粗精度
		end else begin
			switch_target_precision_o <= switch_target_precision_o; // 无新握手时保持诊断值
		end
	end

	// 阻断输出覆盖pending、提交沿、重新获取、故障和生命周期取消
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			switch_hold_new_transaction_o <= 1'b0; // 复位不保留旧事务阻断
		end else begin
			switch_hold_new_transaction_o <= (state_next == ST_WAIT_ENTER) || (state_next == ST_WAIT_RETURN) || (state_next == ST_REACQUIRE) || (state_next == ST_FAULT) || flag_enter_commit || flag_return_commit || flag_lifecycle_cancel; // 下一拍事务只能看到稳定新精度; @satisfies: PWC-11
		end
	end

	// idle仅描述控制事务排空且不表示当前必须处于9-bit
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			controller_idle_o <= 1'b1;          // 复位后没有控制事务
		end else begin
			controller_idle_o <= (state_next == ST_IDLE || state_next == ST_FINE) && (state_current != ST_REACQUIRE) && (flag_fault_hold == 1'b0) && (flag_enter_commit == 1'b0) && (flag_return_commit == 1'b0) && (reacquire_request_event_o == 1'b0) && (mode_fault_event_o == 1'b0); // 排除pending、延迟动作和当拍事件; @satisfies: PWC-35
		end
	end

	// 最近相交未知时间属性只在合法相交握手沿更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			last_cross_time_unknown_o <= 1'b0;  // 复位清除诊断历史
		end else if(flag_cross_transfer == 1'b1)begin
			last_cross_time_unknown_o <= i_cross_time_unknown; // 保存真实握手载荷属性; @satisfies: PWC-12
		end else begin
			last_cross_time_unknown_o <= last_cross_time_unknown_o; // 反压与重复请求不覆盖
		end
	end

	// 最近返回原因记录归一化后的安全控制原因
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			last_return_reason_o <= RETURN_VALLEY_CONFIRMED; // 复位诊断值采用正常返回编码
		end else if(flag_return_transfer == 1'b1)begin
			if(i_return_reason == RETURN_RESERVED)begin
				last_return_reason_o <= RETURN_PROTOCOL_FALLBACK; // 保留编码统一安全回退; @satisfies: PWC-18
			end else begin
				last_return_reason_o <= i_return_reason; // 保存合法返回原因
			end
		end else begin
			last_return_reason_o <= last_return_reason_o; // 其他拍保持历史
		end
	end

	//----------------状态机区域----------------//
	// 当前状态寄存器只在生命周期取消、提交、超时和请求握手边界切换
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_IDLE;           // 复位回到无窗口9-bit控制状态
		end else begin
			state_current <= state_next;        // 同步提交下一控制阶段
		end
	end

	// 下一状态逻辑保持请求所有权直到安全提交或明确取消
	always@(*)begin
		state_next = state_current;             // 默认维持当前控制阶段
		if(i_start_ack_event == 1'b1)begin
			if(flag_blocking_protocol_fault == 1'b1)begin
				state_next = ST_FAULT;          // 非法START进入阻断故障保持
			end else begin
				state_next = ST_IDLE;           // 合法新RUN重新建立精度所有权
			end
		end else if(flag_lifecycle_cancel == 1'b1)begin
			state_next = ST_IDLE;               // STOP、abort或离开RUN撤销在途控制
		end else begin
			case(state_current)
				ST_IDLE:begin
					if(flag_normal_cross_transfer == 1'b1)begin
						state_next = ST_WAIT_ENTER; // 取得相交请求后等待安全帧
					end
				end
				ST_WAIT_ENTER:begin
					if(flag_enter_commit == 1'b1)begin
						state_next = ST_FINE;   // 真实15-bit提交建立正式窗口
					end else if(flag_switch_timeout_event == 1'b1)begin
						state_next = ST_FAULT;  // 两帧内无法安全提交进入故障保持; @satisfies: PWC-26
					end
				end
				ST_FINE:begin
					if(flag_normal_return_transfer == 1'b1)begin
						state_next = ST_WAIT_RETURN; // 取得返回请求后等待安全帧
					end
				end
				ST_WAIT_RETURN:begin
					if(flag_return_commit == 1'b1)begin
						if(flag_pending_return_reacquire == 1'b1)begin
							state_next = ST_REACQUIRE; // 异常返回下一拍交付重获事件
						end else begin
							state_next = ST_IDLE; // 正常波谷返回直接恢复9-bit; @satisfies: PWC-15
						end
					end else if(flag_switch_timeout_event == 1'b1)begin
						state_next = ST_FAULT;  // 返回安全边界异常触发保护
					end
				end
				ST_REACQUIRE:begin
					state_next = ST_IDLE;       // 单拍交付后允许9-bit重新获取调度
				end
				ST_FAULT:begin
					state_next = ST_FAULT;      // 仅生命周期取消或新START解除保持
				end
				default:begin
					state_next = ST_FAULT;      // 非法状态安全进入阻断故障
				end
			endcase
		end
	end

	//-------------状态任务处理区域-------------//
	// 重复相交只在进入请求已经取得所有权时判定
	always@(*)begin
		flag_duplicate_cross = (state_current == ST_WAIT_ENTER) && i_cross_valid; // pending期间第二相交请求不得覆盖快照; @satisfies: PWC-31
	end

	// 重复返回只在返回请求等待安全提交期间判定
	always@(*)begin
		flag_duplicate_return = (state_current == ST_WAIT_RETURN) && i_return_9bit_valid; // pending期间第二返回请求不得覆盖快照
	end

	// 活动精度与请求方向不一致时产生协议诊断
	always@(*)begin
		flag_invalid_direction_request = i_run_enable && (((state_current == ST_IDLE) && (active_precision_mode_o == PRECISION_9BIT) && i_return_9bit_valid) || ((state_current == ST_FINE) && i_cross_valid)); // 当前活动精度拒绝反方向请求; @satisfies: PWC-13
	end

	// RUN资格撤销为在途控制建立统一取消条件
	always@(*)begin
		flag_leave_run_cancel = (i_run_enable == 1'b0) && (state_current != ST_IDLE); // RUN资格撤销时清理在途控制
	end

	//-------------主要任务处理区域-------------//
	// 活动故障在超时或阻断START错误后保持至生命周期取消或复位
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_fault_hold <= 1'b0;            // 复位解除活动故障
		end else if(flag_lifecycle_cancel == 1'b1)begin
			flag_fault_hold <= 1'b0;            // 代际清空命中或离开RUN结束保持
		end else if(i_start_ack_event == 1'b1)begin
			flag_fault_hold <= flag_blocking_protocol_fault; // 新RUN重新评估启动合法性
		end else if(flag_switch_timeout_event == 1'b1)begin
			flag_fault_hold <= 1'b1;            // 模式提交超时阻止新事务
		end else begin
			flag_fault_hold <= flag_fault_hold; // 诊断清除不得解除活动保持; @satisfies: PWC-34
		end
	end

	// 超时计数从请求握手后的下一周期开始且安全提交优先清零
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_switch_timeout <= {C_SWITCH_TIMEOUT_COUNTER_WIDTH{1'b0}}; // 复位清除等待周期
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1 || flag_enter_commit == 1'b1 || flag_return_commit == 1'b1 || flag_switch_timeout_event == 1'b1)begin
			cnt_switch_timeout <= {C_SWITCH_TIMEOUT_COUNTER_WIDTH{1'b0}}; // 生命周期、提交和超时边界清零
		end else if(flag_pending_state == 1'b1)begin
			if(cnt_switch_timeout < TIMEOUT_LIMIT_MINUS_ONE)begin
				cnt_switch_timeout <= cnt_switch_timeout + {{(C_SWITCH_TIMEOUT_COUNTER_WIDTH - 1){1'b0}}, 1'b1}; // 每个未提交周期递增; @satisfies: PWC-24
			end else begin
				cnt_switch_timeout <= cnt_switch_timeout; // 阈值边界冻结供超时组合判断
			end
		end else begin
			cnt_switch_timeout <= {C_SWITCH_TIMEOUT_COUNTER_WIDTH{1'b0}}; // 无pending时保持确定零值
		end
	end

	// pending相交上下文在握手沿原子锁存并在生命周期边界清除
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cross_frame_snapshot <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除相交帧快照; @satisfies: PWC-29
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			reg_cross_frame_snapshot <= {C_FRAME_ID_WIDTH{1'b0}}; // 新RUN或取消删除旧上下文
		end else if(flag_cross_transfer == 1'b1)begin
			reg_cross_frame_snapshot <= i_cross_frame_id; // 握手沿锁存真实中心帧; @satisfies: PWC-08
		end else begin
			reg_cross_frame_snapshot <= reg_cross_frame_snapshot; // 等待期间保持载荷
		end
	end

	// pending相交事务号独立保持防止反压载荷变化影响所有权
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cross_sample_snapshot <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 复位清除事务号快照
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			reg_cross_sample_snapshot <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 生命周期边界删除旧事务
		end else if(flag_cross_transfer == 1'b1)begin
			reg_cross_sample_snapshot <= i_cross_sample_index; // 握手沿锁存相交事务号
		end else begin
			reg_cross_sample_snapshot <= reg_cross_sample_snapshot; // pending期间保持
		end
	end

	// 相交ACTIVE版本在请求取得所有权时冻结
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cross_config_snapshot <= {C_CONFIG_EPOCH_WIDTH{1'b0}}; // 复位清除ACTIVE版本
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			reg_cross_config_snapshot <= {C_CONFIG_EPOCH_WIDTH{1'b0}}; // 生命周期清理旧版本
		end else if(flag_cross_transfer == 1'b1)begin
			reg_cross_config_snapshot <= i_cross_config_epoch; // 原子保存相交ACTIVE版本
		end else begin
			reg_cross_config_snapshot <= reg_cross_config_snapshot; // 等待期间保持
		end
	end

	// 相交Stage1系数版本独立冻结供后续顶层诊断
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cross_coef_snapshot <= {C_COEF_EPOCH_WIDTH{1'b0}}; // 复位清除系数版本
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			reg_cross_coef_snapshot <= {C_COEF_EPOCH_WIDTH{1'b0}}; // 新生命周期废止旧Stage1代次
		end else if(flag_cross_transfer == 1'b1)begin
			reg_cross_coef_snapshot <= i_cross_coef_epoch; // 锁存Stage1版本快照
		end else begin
			reg_cross_coef_snapshot <= reg_cross_coef_snapshot; // 等待期间维持系数版本一致
		end
	end

	// 相交DC恢复版本在请求握手时保持到提交或取消
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cross_dc_snapshot <= {C_DC_RECOVERY_EPOCH_WIDTH{1'b0}}; // 复位清除DC恢复身份
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			reg_cross_dc_snapshot <= {C_DC_RECOVERY_EPOCH_WIDTH{1'b0}}; // 生命周期删除旧快照
		end else if(flag_cross_transfer == 1'b1)begin
			reg_cross_dc_snapshot <= i_cross_dc_recovery_coef_epoch; // 锁存DC恢复版本
		end else begin
			reg_cross_dc_snapshot <= reg_cross_dc_snapshot; // 安全提交前维持DC身份稳定
		end
	end

	// pending相交时间属性在握手沿原子锁存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_cross_time_unknown <= 1'b0; // 复位清除时间属性
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			flag_pending_cross_time_unknown <= 1'b0; // 生命周期边界删除旧属性
		end else if(flag_cross_transfer == 1'b1)begin
			flag_pending_cross_time_unknown <= i_cross_time_unknown; // 锁存握手载荷
		end else begin
			flag_pending_cross_time_unknown <= flag_pending_cross_time_unknown; // 提交前保持时间诊断属性
		end
	end

	// 返回帧号在返回请求真实握手沿锁存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_return_frame_snapshot <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除返回帧快照
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			reg_return_frame_snapshot <= {C_FRAME_ID_WIDTH{1'b0}}; // 生命周期删除旧返回上下文
		end else if(flag_return_transfer == 1'b1)begin
			reg_return_frame_snapshot <= i_return_frame_id; // 锁存返回结论帧号
		end else begin
			reg_return_frame_snapshot <= reg_return_frame_snapshot; // 返回提交前保持结论时间
		end
	end

	// 返回原因在握手沿归一化并保持至9-bit安全提交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			enc_return_reason_snapshot <= RETURN_VALLEY_CONFIRMED; // 复位采用正常原因编码
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
			enc_return_reason_snapshot <= RETURN_VALLEY_CONFIRMED; // 生命周期清理旧原因
		end else if(flag_return_transfer == 1'b1)begin
			if(i_return_reason == RETURN_RESERVED)begin
				enc_return_reason_snapshot <= RETURN_PROTOCOL_FALLBACK; // 保留值归一化为安全回退
			end else begin
				enc_return_reason_snapshot <= i_return_reason; // 保存合法原因
			end
		end else begin
			enc_return_reason_snapshot <= enc_return_reason_snapshot; // 9-bit提交前保持归一化结果
		end
	end

	// 返回是否需要重新获取由归一化原因在握手沿确定
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_return_reacquire <= 1'b0; // 复位不需要重获
		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1 || flag_return_commit == 1'b1)begin
			flag_pending_return_reacquire <= 1'b0; // 生命周期或提交后清除pending属性
		end else if(flag_return_transfer == 1'b1)begin
			flag_pending_return_reacquire <= (i_return_reason != RETURN_VALLEY_CONFIRMED); // 超时、回退和保留原因需要重获
		end else begin
			flag_pending_return_reacquire <= flag_pending_return_reacquire; // 等待提交期间保持
		end
	end

	// pending来源标志辅助诊断且不影响FIR精度尾部
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_cross <= 1'b0;         // 复位不存在进入请求
		end else if(flag_cross_transfer == 1'b1)begin
			flag_pending_cross <= 1'b1;         // 记录进入请求所有权
		end else if(flag_lifecycle_cancel == 1'b1 || flag_enter_commit == 1'b1 || flag_switch_timeout_event == 1'b1)begin
			flag_pending_cross <= 1'b0;         // 提交、取消或超时释放标志
		end else begin
			flag_pending_cross <= flag_pending_cross; // 15-bit提交前保留进入方向
		end
	end

	// pending返回标志记录当前请求方向
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_return <= 1'b0;        // 复位不存在返回请求
		end else if(flag_return_transfer == 1'b1)begin
			flag_pending_return <= 1'b1;        // 记录返回请求所有权
		end else if(flag_lifecycle_cancel == 1'b1 || flag_return_commit == 1'b1 || flag_switch_timeout_event == 1'b1)begin
			flag_pending_return <= 1'b0;        // 返回所有权在终止边界释放
		end else begin
			flag_pending_return <= flag_pending_return; // 9-bit提交前保留返回方向
		end
	end

	// START边界检查ACTIVE配置是否具备正式运行资格
	always@(*)begin
		flag_active_config_fault = i_start_ack_event && (i_active_config_valid == 1'b0); // 无合法ACTIVE不得开始正式RUN
	end

	// 固定精度表征模式收到自动窗口请求时记录诊断
	always@(*)begin
		flag_characterization_request = i_run_enable && (i_run_profile == RUN_PROFILE_CHARACTERIZATION) && (i_cross_valid || i_return_9bit_valid); // 表征模式自动请求必须安全消费并诊断
	end

	// 两个相反方向的请求同拍有效时标记载荷冲突
	always@(*)begin
		flag_cross_return_collision = i_run_enable && i_cross_valid && i_return_9bit_valid; // 同拍双方向请求属于协议异常; @satisfies: PWC-30
	end

	// NORMAL启动配置强制检查粗精度初始条件
	always@(*)begin
		flag_normal_start_illegal = i_start_ack_event && (i_run_profile == RUN_PROFILE_NORMAL) && i_initial_precision; // NORMAL禁止以15-bit启动; @satisfies: PWC-03
	end

	// 阻断型START错误转换为生命周期可见的故障单拍
	always@(*)begin
		flag_protocol_fault_pulse = i_start_ack_event && flag_blocking_protocol_fault; // START阻断异常产生一次故障报告
	end

	// 正式fine窗口与AMB重检必须保持调度互斥
	always@(*)begin
		flag_recheck_in_fine = i_run_enable && fine_window_active_o && i_recheck_busy; // 正式fine期间重检占用违反调度关系
	end

	// 回退类返回原因汇总为需要保留的协议历史
	always@(*)begin
		flag_return_protocol_fallback = flag_return_transfer && ((i_return_reason == RETURN_PROTOCOL_FALLBACK) || (i_return_reason == RETURN_RESERVED)); // 协议回退原因必须留下诊断历史; @satisfies: PWC-17
	end

	// 保留返回原因单独触发归一化和错误诊断
	always@(*)begin
		flag_return_reserved = flag_return_transfer && (i_return_reason == RETURN_RESERVED); // 保留返回原因需要诊断并回退
	end

endmodule

