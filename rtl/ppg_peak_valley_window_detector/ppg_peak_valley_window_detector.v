`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026/08/11 00:00:00
// Design Name: 	PPG Peak Valley Window Detector
// Module Name: 	ppg_peak_valley_window_detector
// Description: 	Description/ppg_peak_valley_window_detector_Design.pdf
// Dependencies:
// ppg_coarse_detection_fir.v,
// ppg_dynamic_baseline_cross_detector.v
// Simulations:		TestBench/Vivado/2022.2/ppg_peak_valley_window_detector
//
// Referrences:		PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//
//
// Version:			V1.5
// Revision Date:	2026/10/06
// History:
//    Time			   Version	   Revised by			Contents
// 2026/08/11            V1.0          Erie                  Create file.
// 2026/08/22            V1.1          Erie                  Remove i_stop_ack_event/i_control_abort_event direct-clear ports; add PWI-broadcast i_detection_discard group, i_run_generation and o_local_empty per PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md section 14.1.
// 2026/08/23            V1.2          Erie                  Remove i_start_ack_event from the fine_window_timeout/reacquire_timeout/protocol_error sticky clear conditions; only i_diag_clear_event or reset may clear these histories per PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md section 12.4 and acceptance item PVW-37.
// 2026/08/23            V1.3          Erie                  Gate only the peak_valley_config_valid term of flag_active_config_legal on i_characterization_mode per section 3.2's CHARACTERIZATION allowance; the other 6 numeric threshold terms remain mandatory nonzero in both run profiles, since section 7.1's fixed-precision RED characterization scenario needs real debounce/plausibility gating to be meaningful.
// 2026/08/23            V1.4          Erie                  Remove the blanket reacquire_search_active_o term from flag_peak_interval_legal; the min_peak_to_peak_frames plausibility check now only exempts the case with no reliable previous peak reference (flag_previous_peak_valid==0), matching section 7.1's own stated rationale, instead of exempting every reacquire round regardless of whether a real prior peak still exists.
// 2026/10/06            V1.5          Erie                  ABCD review F-018: the valley-accept branch of return_payload_o now also requires return_9bit_valid_o==0, like the timeout and protocol-fallback branches. Previously, while a return request was held under backpressure (return ready=0, reachable from the PWC fault hold), a second legal peak/valley pair overwrote the pending request's frame id (10 -> 21), violating the C22 Section 11.4 hold-type handshake.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026年08月11日
// 设计名称: 		PPG Peak Valley Window Detector
// 模块名称: 		ppg_peak_valley_window_detector
// 模块说明:		Description/ppg_peak_valley_window_detector_Design.pdf
// 依赖文件:
// ppg_coarse_detection_fir.v,
// ppg_dynamic_baseline_cross_detector.v
// 仿真工程: 		TestBench/Vivado/2022.2/ppg_peak_valley_window_detector
//
// 参考资料:		PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.5
// 修订日期:		2026年10月06日
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026年08月11日        V1.0          Erie                  创建文件
// 2026年08月22日        V1.1          Erie                  删除i_stop_ack_event/i_control_abort_event直接清除端口，按合同14.1节新增PWI广播的i_detection_discard组、i_run_generation和o_local_empty
// 2026年08月23日        V1.2          Erie                  按合同12.4节和验收项PVW-37，把fine_window_timeout/reacquire_timeout/protocol_error三个历史sticky的清除条件里的i_start_ack_event去掉，只保留i_diag_clear_event或复位可以清除
// 2026年08月23日        V1.3          Erie                  按合同3.2节CHARACTERIZATION允许条款，只把flag_active_config_legal里peak_valley_config_valid这一项接上i_characterization_mode豁免，其余6个数值门限两种运行档案下都必须非零——合同7.1节固定精度RED表征场景需要真实的去抖/生理合理性门限才有表征意义
// 2026年08月23日        V1.4          Erie                  删除flag_peak_interval_legal里整体豁免reacquire_search_active_o的一项，峰峰最小时间检查现在只在真正没有可靠前一波峰参照时（flag_previous_peak_valid==0）才豁免，和合同7.1节"没有前一波峰因此免除"的原文理由对齐，不再对仍有真实参照的reacquire场景整体放行
// 2026年10月06日        V1.5          Erie                  ABCD复核F-018：return_payload_o的波谷接受分支增加return_9bit_valid_o==0条件，与超时、协议回退两支一致。此前返回请求在反压下保持时（return ready=0，PWC故障保持时可达），第二组合法峰谷会覆盖未握手请求的帧号（10变21），违反C22第11.4节保持型握手
// 使用连续Stage1粗FIR事务确认原始码值波峰和波谷，并可靠控制15-bit窗口退出
module ppg_peak_valley_window_detector
#(
	parameter integer C_DATA_WIDTH = 32'd24,    // Stage1粗FIR统一PPG码宽度
	parameter integer C_FRAME_ID_WIDTH = 32'd16, // 全局400 Hz中心帧编号宽度
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // ADC事务中心序号字段宽度
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // ACTIVE配置版本字段宽度
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8, // Stage1校准系数版本宽度
	parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8, // DC恢复系数版本字段宽度
	parameter integer C_CONFIRM_COUNT_WIDTH = 32'd4, // 峰谷连续方向确认计数宽度
	parameter integer C_INTERVAL_WIDTH = 32'd16, // 峰谷时间和超时字段宽度
	parameter integer C_FIR_GROUP_DELAY_SAMPLES = 32'd10, // 20阶FIR同色有效样本群延时
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // discard组诊断用AMB/DC码版本字段宽度
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8 // manager唯一生产、由PWI逐层广播的RUN代际字段宽度
)
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 2 MHz数字处理域工作时钟
	input i_rstn,                               // 低有效异步复位输入

	//---------------生命周期接口---------------//
	input i_run_enable,                         // RUN状态允许正式峰谷检测
	input i_start_ack_event,                    // 新RUN接受后清除历史并重新获取
	input i_diag_clear_event,                   // 片外软件请求清除sticky诊断
	input i_recheck_accept_event,               // AMB/DC周期重检实际安全接管
	input i_recheck_busy,                       // 重检和FIR恢复期间禁止正式检测
	input i_recheck_done_event,                 // 三帧重检序列结束事件
	input i_recheck_success,                    // 重检结束同拍的整体成功资格
	input i_reacquire_active,                   // 动态基线要求在9-bit重新获取波峰

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
	output o_local_empty,                  // 本模块无pending峰谷/返回事件且无窗口尾部占用时为高，唯一消费者PWI

	//--------------ACTIVE配置接口--------------//
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_peak_confirm_count, // 波峰后的连续下降确认样本数
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_valley_confirm_count, // 波谷后的连续上升确认样本数
	input [C_DATA_WIDTH - 1:0]i_direction_deadband, // 相邻FIR值方向分类的无符号死区
	input [C_DATA_WIDTH - 1:0]i_min_peak_valley_amplitude, // 合格峰谷对的最小无符号幅度
	input [C_INTERVAL_WIDTH - 1:0]i_min_peak_to_valley_frames, // 波峰到波谷的最小帧差
	input [C_INTERVAL_WIDTH - 1:0]i_min_peak_to_peak_frames, // 相邻波峰允许的最小帧差
	input [C_INTERVAL_WIDTH - 1:0]i_max_fine_window_frames, // 正式15-bit窗口最大帧数
	input [C_INTERVAL_WIDTH - 1:0]i_max_reacquire_frames, // 单轮9-bit重新获取最大帧数
	input i_peak_valley_config_valid,           // 峰谷表征参数已经正式提交；unpacker->AMI->PWI->C20/C22/C23唯一通路上的C22消费端 @satisfies: G-FP-01-D01-04
	input i_characterization_mode,              // 表征模式允许临时门限但不放宽协议

	//--------------粗FIR事务接口---------------//
	input i_result_valid,                       // 检测fork分支保持的粗FIR事务valid
	output o_result_ready,                      // 本模块允许上游消费当前FIR事务
	input signed [C_DATA_WIDTH - 1:0]i_filtered_ppg_value, // 与PD接收光强正相关的Stage1粗FIR码
	input i_detection_qualified,                // FIR窗口完整且具备正式检测资格
	input i_window_saturation_low,              // FIR输入窗口包含负向端点样本
	input i_window_saturation_high,             // FIR输入窗口包含正向端点样本
	input i_fir_saturation_low,                 // 当前FIR结果触及signed低端点
	input i_fir_saturation_high,                // 当前FIR结果触及signed高端点
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 中心样本绑定的ACTIVE版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 中心样本采用的Stage1系数组版本
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_dc_recovery_coef_epoch, // 中心样本采用的DC恢复版本
	input i_precision_mode,                     // 中心样本采集时的9-bit或15-bit模式
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id,   // FIR中心样本的400 Hz帧号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // FIR中心样本的全局事务号
	input i_color_ir,                           // 低更新RED状态，高仅消费IR事务
	input [1:0]i_frame_type,                    // 正式检测事务固定使用NORMAL编码10

	//-------------正式精度窗口接口-------------//
	input i_fine_window_start_event,            // PPG 15-bit窗口已经在安全边界提交
	input [C_FRAME_ID_WIDTH - 1:0]i_fine_window_start_frame_id, // 第一笔正式15-bit帧号
	input i_active_precision_mode,              // 当前系统已经提交的精度状态
	output o_return_9bit_valid,                 // 保持型返回9-bit请求
	input i_return_9bit_ready,                  // 模式控制器接受返回请求
	output [1:0]o_return_reason,                // 谷值成功、窗口超时或协议回退原因
	output [C_FRAME_ID_WIDTH - 1:0]o_return_frame_id, // 返回请求绑定的确认或超时帧号

	//---------------波峰事件接口---------------//

	//PEAK接口
	output o_peak_valid,                        // 可靠原始码值波峰事件valid
	input i_peak_ready,                         // 动态基线模块允许消费波峰事件
	output signed [C_DATA_WIDTH - 1:0]o_peak_value, // 保存的Stage1粗FIR运行最大值
	output [C_FRAME_ID_WIDTH - 1:0]o_peak_frame_id, // 波峰实际发生的中心帧编号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_peak_sample_index, // 波峰实际对应的事务序号
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_peak_config_epoch, // 波峰事务对应的ACTIVE版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_peak_coef_epoch, // 波峰事务对应的Stage1系数版本
	output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_peak_dc_recovery_coef_epoch, // 波峰事务对应的DC恢复版本

	//---------------波谷事件接口---------------//

	//VALLEY接口
	output o_valley_valid,                      // 可靠原始码值波谷事件valid
	input i_valley_ready,                       // 动态基线模块允许消费波谷事件
	output signed [C_DATA_WIDTH - 1:0]o_valley_value, // 保存的Stage1粗FIR运行最小值
	output [C_FRAME_ID_WIDTH - 1:0]o_valley_frame_id, // 波谷实际发生的中心帧编号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_valley_sample_index, // 波谷实际对应的事务序号
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_valley_config_epoch, // 波谷事务对应的ACTIVE版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_valley_coef_epoch, // 波谷事务对应的Stage1系数版本
	output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_valley_dc_recovery_coef_epoch, // 波谷事务对应的DC恢复版本

	//---------------只读状态接口---------------//
	output o_detector_idle,                     // 无待提交事件且允许重检安全接管
	output o_fine_window_active,                // 正式PPG 15-bit窗口已经提交
	output o_reacquire_search_active,           // 当前在9-bit重新获取可靠波峰
	output o_fine_window_timeout_sticky,        // 正式窗口超时历史诊断
	output o_reacquire_timeout_sticky,          // 重新获取超时历史诊断
	output o_protocol_error_sticky              // 配置、帧序、epoch或模式协议诊断
);

	//---------------配置参数区域---------------//
	// 协议编码和事件原因由冻结接口合同统一定义
	localparam [1:0]FRAME_TYPE_NORMAL = 2'b10;  // 正式PPG检测事务类别编码
	localparam [1:0]RETURN_REASON_VALLEY = 2'b00; // 合格波谷要求正常返回9-bit
	localparam [1:0]RETURN_REASON_TIMEOUT = 2'b01; // 正式fine窗口超时回退原因
	localparam [1:0]RETURN_REASON_PROTOCOL = 2'b10; // 精度或配置协议异常回退原因

	// 峰谷事件使用相同原子上下文格式避免跨字段撕裂
	localparam integer SAMPLE_CONTEXT_WIDTH = C_DATA_WIDTH + C_FRAME_ID_WIDTH + C_SAMPLE_INDEX_WIDTH + C_CONFIG_EPOCH_WIDTH + C_COEF_EPOCH_WIDTH + C_DC_RECOVERY_EPOCH_WIDTH; // 极值原子载荷总宽度
	localparam integer PREVIOUS_CONTEXT_WIDTH = C_DATA_WIDTH + C_FRAME_ID_WIDTH; // 相邻方向比较保存的值和帧号宽度
	localparam integer RETURN_CONTEXT_WIDTH = 32'd2 + C_FRAME_ID_WIDTH; // 返回原因和绑定帧号总宽度
	localparam [C_INTERVAL_WIDTH - 1:0]FIR_GROUP_DELAY_LIMIT = C_FIR_GROUP_DELAY_SAMPLES; // 精度切换允许的旧中心样本数量

	//---------------状态参数区域---------------//
	// 同一Stage1粗链只在波峰搜索和波谷搜索之间切换
	localparam ST_SEARCH_PEAK = 1'b0;           // 跟踪运行最大值并等待连续下降
	localparam ST_SEARCH_VALLEY = 1'b1;         // 跟踪运行最小值并等待连续上升

	//---------------计数信号区域---------------//
	reg [C_CONFIRM_COUNT_WIDTH - 1:0]cnt_direction_confirm; // 当前连续下降或上升证据数
	wire [C_CONFIRM_COUNT_WIDTH:0]cnt_direction_confirm_next; // 扩位后的下一方向证据计数
	reg [C_INTERVAL_WIDTH - 1:0]cnt_entry_precision_tail; // 进入15-bit后旧9-bit中心样本计数
	reg [C_INTERVAL_WIDTH - 1:0]cnt_exit_precision_tail; // 返回9-bit后旧15-bit中心样本计数

	//--------------状态机信号区域--------------//
	reg state_current;                          // 当前峰谷搜索阶段寄存器
	reg state_next;                             // 下一峰谷搜索阶段组合结果

	//--------------寄存器信号区域--------------//
	reg [PREVIOUS_CONTEXT_WIDTH - 1:0]reg_previous_context; // 上一合格RED样本值和帧号
	reg [SAMPLE_CONTEXT_WIDTH - 1:0]reg_running_context; // 当前运行最大值或最小值上下文
	reg [SAMPLE_CONTEXT_WIDTH - 1:0]reg_previous_peak_context; // 最近正式波峰上下文
	reg [SAMPLE_CONTEXT_WIDTH - 1:0]reg_active_peak_context; // 当前波谷搜索绑定的正式波峰
	reg [C_FRAME_ID_WIDTH - 1:0]reg_fine_window_start_frame_id; // 正式fine窗口起始帧
	reg [C_FRAME_ID_WIDTH - 1:0]reg_reacquire_start_frame_id; // 当前重新获取单轮起始帧

	//---------------标志信号区域---------------//
	reg flag_previous_valid;                    // 上一合格RED样本上下文有效
	reg flag_running_valid;                     // 当前运行极值上下文有效
	reg flag_previous_peak_valid;               // 最近正式波峰可用于峰峰时间检查
	reg flag_active_peak_valid;                 // 当前周期具有可配对波峰
	reg flag_return_accepted;                   // 返回请求已握手且等待实际9-bit
	reg flag_reacquire_timer_valid;             // 当前重新获取计时起点有效
	reg flag_recovery_return_pending;           // timeout或协议回退等待重新获取接管
	reg flag_entry_precision_tail_active;       // 正式进入后仍允许旧9-bit中心样本排空
	reg flag_entry_precision_tail_complete;     // 已观察到第一笔正式15-bit中心样本
	reg flag_exit_precision_tail_active;        // 实际返回后仍允许旧15-bit中心样本排空
	reg flag_running_fine_qualified;            // 当前运行极值来自正式15-bit中心区间
	reg flag_active_peak_fine_qualified;        // 当前活动波峰具备正式fine配对资格
	wire flag_runtime_clear;                    // 代际清空命中、重检接管或离开RUN清除运行上下文
	wire flag_context_clear;                    // 新START或运行终止清除检测状态
	wire flag_input_transfer;                   // 粗FIR事务完成一次正式握手
	wire flag_red_time_transfer;                // RED NORMAL事务用于观察真实帧时间
	wire flag_no_saturation;                    // 当前FIR事务无任何端点饱和
	wire flag_active_config_legal;              // ACTIVE峰谷配置满足正式最小条件
	wire flag_formal_sample;                    // 当前事务允许更新峰谷方向和极值
	wire flag_peak_transfer;                    // 波峰输出事件被动态基线消费
	wire flag_valley_transfer;                  // 波谷输出事件被动态基线消费
	wire flag_return_transfer;                  // 返回9-bit请求被模式控制器接受
	wire flag_reacquire_start_event;            // 外部重新获取要求首次进入本地搜索
	wire flag_tracking_restart;                 // 异常或超时要求重置当前局部趋势
	wire flag_fine_exit_complete;               // 返回握手后观察到系统实际9-bit
	wire flag_frame_contiguous;                 // 相邻合格RED帧号严格递增1
	wire flag_direction_rising;                 // 当前相邻样本形成有效上升
	wire flag_direction_falling;                // 当前相邻样本形成有效下降
	wire flag_peak_interval_legal;              // 首峰豁免或峰峰时间满足门限
	wire flag_peak_epoch_match;                 // 相邻正式波峰版本语义一致
	wire flag_peak_candidate_event;             // 连续下降次数达到配置门限
	wire flag_peak_accept_event;                // 候选峰满足时间和epoch资格
	wire flag_peak_reject_event;                // 局部峰因时间或版本被拒绝
	wire flag_valley_amplitude_legal;           // 峰谷幅度为正且达到配置门限
	wire flag_valley_interval_legal;            // 峰谷时间达到配置门限
	wire flag_valley_epoch_match;               // 峰谷配置和系数版本一致
	wire flag_valley_candidate_event;           // 连续上升次数达到配置门限
	wire flag_valley_accept_event;              // 候选谷满足幅度、时间和版本资格
	wire flag_valley_restart_event;             // 非fine波峰完成粗谷后重新寻找正式波峰
	wire flag_valley_epoch_fault_event;         // 候选谷发现跨epoch周期
	wire flag_fine_window_timeout_event;        // 正式fine窗口达到最大帧数
	wire flag_reacquire_timeout_event;          // 当前9-bit重新获取单轮超时
	wire flag_nonfine_valley_timeout_event;     // 非fine周期峰后长期没有合格波谷
	wire flag_fine_protocol_fallback_event;     // fine窗口配置异常要求安全返回
	wire flag_precision_drop_event;             // 正式窗口未握手返回却提前变成9-bit
	wire flag_epoch_drift_event;                // 连续合格样本ACTIVE版本发生漂移
	wire flag_frame_protocol_error_event;       // 帧差达到半回绕或出现非连续跳帧
	wire flag_config_protocol_error_event;      // 正式运行观察到非法ACTIVE配置
	wire flag_mode_protocol_error_event;        // 精度窗口提交或状态关系异常
	wire flag_fine_center_qualified;            // 当前FIR中心属于正式15-bit窗口
	wire flag_entry_tail_overflow_event;        // 进入尾部超过10笔旧9-bit中心样本
	wire flag_entry_tail_reversion_event;       // 正式15-bit中心后再次出现旧9-bit样本
	wire flag_exit_tail_overflow_event;         // 退出尾部超过10笔旧15-bit中心样本
	wire flag_unauthorized_precision_event;     // 非窗口且非退出尾部观察到15-bit中心
	wire flag_protocol_error_event;             // 任一协议异常要求sticky置位

	//---------------编码信号区域---------------//
	wire [SAMPLE_CONTEXT_WIDTH - 1:0]enc_input_context; // 当前FIR事务的极值候选原子载荷
	wire [PREVIOUS_CONTEXT_WIDTH - 1:0]enc_previous_context; // 当前值和帧号的相邻比较载荷
	wire signed [C_DATA_WIDTH:0]enc_deadband_positive; // 25-bit正向死区边界
	wire signed [C_DATA_WIDTH:0]enc_deadband_negative; // 25-bit负向死区边界

	//---------------译码信号区域---------------//
	wire signed [C_DATA_WIDTH - 1:0]dec_previous_value; // 上一合格RED FIR码值
	wire [C_FRAME_ID_WIDTH - 1:0]dec_previous_frame_id; // 上一合格RED中心帧号
	wire signed [C_DATA_WIDTH - 1:0]dec_running_value; // 当前运行最大值或最小值
	wire [C_FRAME_ID_WIDTH - 1:0]dec_running_frame_id; // 当前运行极值实际帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_running_sample_index; // 当前运行极值事务号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_running_config_epoch; // 当前运行极值ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_running_coef_epoch; // 当前运行极值采用的Stage1校准代次
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_running_dc_epoch; // 当前运行极值DC恢复版本
	wire signed [C_DATA_WIDTH - 1:0]dec_previous_peak_value; // 最近正式波峰值
	wire [C_FRAME_ID_WIDTH - 1:0]dec_previous_peak_frame_id; // 最近正式波峰帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_previous_peak_sample_index; // 最近正式波峰事务号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_previous_peak_config_epoch; // 最近波峰ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_previous_peak_coef_epoch; // 最近正式波峰绑定的Stage1校准代次
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_previous_peak_dc_epoch; // 最近波峰DC恢复版本
	wire signed [C_DATA_WIDTH - 1:0]dec_active_peak_value; // 当前波谷搜索绑定的波峰值
	wire [C_FRAME_ID_WIDTH - 1:0]dec_active_peak_frame_id; // 当前波谷搜索绑定的波峰帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_active_peak_sample_index; // 当前配对波峰事务号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_active_peak_config_epoch; // 当前配对波峰ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_active_peak_coef_epoch; // 当前配对波峰冻结的Stage1校准代次
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_active_peak_dc_epoch; // 当前配对波峰DC恢复版本
	wire signed [C_DATA_WIDTH:0]dec_direction_delta; // 显式扩位的相邻码值差
	wire [C_FRAME_ID_WIDTH - 1:0]dec_previous_frame_step; // 相邻合格RED帧差
	wire [C_FRAME_ID_WIDTH - 1:0]dec_peak_to_peak_frames; // 候选峰相对上一峰的帧差
	wire signed [C_DATA_WIDTH:0]dec_peak_valley_amplitude; // 当前波峰减运行最小值的扩位幅度
	wire [C_FRAME_ID_WIDTH - 1:0]dec_peak_to_valley_frames; // 运行最小值相对波峰的帧差
	wire [C_FRAME_ID_WIDTH - 1:0]dec_fine_window_age; // 当前RED帧相对fine起点的时间
	wire [C_FRAME_ID_WIDTH - 1:0]dec_reacquire_age; // 当前RED帧相对重新获取起点的时间
	wire [C_FRAME_ID_WIDTH - 1:0]dec_active_peak_age; // 当前RED帧相对活动波峰的时间

	//---------------其他信号区域---------------//
	// 本模块没有无法归入计数、状态、寄存、标志、编码或译码类别的内部信号

	//---------------输出信号区域---------------//
	//正式精度窗口接口
	reg [RETURN_CONTEXT_WIDTH - 1:0]return_payload_o; // 返回原因和帧号原子载荷
	reg return_9bit_valid_o;                    // 返回9-bit请求保持寄存器
	wire [1:0]return_reason_o;                  // 返回请求原因字段桥接信号
	wire [C_FRAME_ID_WIDTH - 1:0]return_frame_id_o; // 返回请求确认或超时帧桥接信号

	//波峰事件接口
	reg [SAMPLE_CONTEXT_WIDTH - 1:0]peak_payload_o; // 波峰输出原子载荷寄存器
	reg peak_valid_o;                           // 波峰输出保持valid寄存器
	wire signed [C_DATA_WIDTH - 1:0]peak_value_o; // 波峰码值桥接信号
	wire [C_FRAME_ID_WIDTH - 1:0]peak_frame_id_o; // 波峰实际中心帧桥接信号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]peak_sample_index_o; // 波峰事务序号桥接信号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]peak_config_epoch_o; // 波峰ACTIVE版本桥接信号
	wire [C_COEF_EPOCH_WIDTH - 1:0]peak_coef_epoch_o; // 供动态基线识别波峰系数组代次
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]peak_dc_recovery_coef_epoch_o; // 波峰DC恢复版本桥接信号

	//波谷事件接口
	reg [SAMPLE_CONTEXT_WIDTH - 1:0]valley_payload_o; // 波谷输出原子载荷寄存器
	reg valley_valid_o;                         // 波谷输出保持valid寄存器
	wire signed [C_DATA_WIDTH - 1:0]valley_value_o; // 波谷码值桥接信号
	wire [C_FRAME_ID_WIDTH - 1:0]valley_frame_id_o; // 波谷实际中心帧桥接信号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]valley_sample_index_o; // 波谷事务序号桥接信号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]valley_config_epoch_o; // 波谷ACTIVE版本桥接信号
	wire [C_COEF_EPOCH_WIDTH - 1:0]valley_coef_epoch_o; // 供周期配对识别波谷校准代次
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]valley_dc_recovery_coef_epoch_o; // 波谷DC恢复版本桥接信号

	//只读状态接口
	reg fine_window_active_o;                   // 正式fine窗口资格寄存器
	reg reacquire_search_active_o;              // 本地9-bit重新获取状态
	reg fine_window_timeout_sticky_o;           // 正式窗口超时历史寄存器
	reg reacquire_timeout_sticky_o;             // 重新获取超时历史寄存器
	reg protocol_error_sticky_o;                // 协议异常历史寄存器

	//-------------其他信号连线区域-------------//
	//其他信号连线
	assign {peak_value_o, peak_frame_id_o, peak_sample_index_o, peak_config_epoch_o, peak_coef_epoch_o, peak_dc_recovery_coef_epoch_o} = peak_payload_o; // 原子解码波峰载荷
	assign {valley_value_o, valley_frame_id_o, valley_sample_index_o, valley_config_epoch_o, valley_coef_epoch_o, valley_dc_recovery_coef_epoch_o} = valley_payload_o; // 原子解码波谷载荷
	assign {return_reason_o, return_frame_id_o} = return_payload_o; // 原子解码返回原因和绑定帧号
	// 事务、配置和生命周期组合资格只依赖当前稳定输入与保持状态
	assign flag_runtime_clear = (i_detection_discard_event && (i_detection_discard_run_generation == i_run_generation)) || i_recheck_accept_event || (i_run_enable == 1'b0); // PWI广播的代际清空事件命中当前代际时清理运行状态; @satisfies: PVW-32, PVW-35, PVW-36
	assign flag_context_clear = i_start_ack_event || flag_runtime_clear; // 新RUN同样从空检测上下文开始
	assign flag_input_transfer = i_result_valid && o_result_ready; // 当前FIR事务完成唯一一次消费
	assign flag_red_time_transfer = flag_input_transfer && (i_color_ir == 1'b0) && (i_frame_type == FRAME_TYPE_NORMAL); // RED NORMAL事务推进真实帧时间; @satisfies: PVW-18
	assign flag_no_saturation = (i_window_saturation_low == 1'b0) && (i_window_saturation_high == 1'b0) && (i_fir_saturation_low == 1'b0) && (i_fir_saturation_high == 1'b0); // 任一端点饱和都取消正式方向资格；饱和样本不得成为PEAK/VALLEY正式证据 @satisfies: PRC-03
	assign flag_active_config_legal = (i_peak_valley_config_valid || i_characterization_mode) && (i_peak_confirm_count != {C_CONFIRM_COUNT_WIDTH{1'b0}}) && (i_valley_confirm_count != {C_CONFIRM_COUNT_WIDTH{1'b0}}) && (i_min_peak_to_valley_frames != {C_INTERVAL_WIDTH{1'b0}}) && (i_min_peak_to_peak_frames != {C_INTERVAL_WIDTH{1'b0}}) && (i_max_fine_window_frames != {C_INTERVAL_WIDTH{1'b0}}) && (i_max_reacquire_frames != {C_INTERVAL_WIDTH{1'b0}}); // CHARACTERIZATION只豁免config_valid提交状态，六项数值门限两种模式下均不得为0; @satisfies: PVW-38

	//其他信号连线
	assign flag_formal_sample = flag_red_time_transfer && i_detection_qualified && flag_no_saturation && flag_active_config_legal && (flag_recovery_return_pending == 1'b0); // 只有完整RED事务更新峰谷状态; @satisfies: PVW-19

	//PEAK接口
	assign flag_peak_transfer = peak_valid_o && i_peak_ready; // 波峰事件完成握手

	//VALLEY接口
	assign flag_valley_transfer = valley_valid_o && i_valley_ready; // 波谷事件完成握手
	assign flag_return_transfer = return_9bit_valid_o && i_return_9bit_ready; // 返回请求完成握手
	assign flag_reacquire_start_event = i_reacquire_active && (reacquire_search_active_o == 1'b0); // 外部重新获取要求只捕获一次起点
	assign flag_fine_exit_complete = fine_window_active_o && flag_return_accepted && (i_active_precision_mode == 1'b0); // 已接受请求后观察到实际9-bit
	// 原子上下文编码和解码保证数值、时间与版本始终属于同一事务
	assign enc_input_context = {i_filtered_ppg_value, i_frame_id, i_sample_index, i_config_epoch, i_coef_epoch, i_dc_recovery_coef_epoch}; // 打包当前中心样本完整身份
	assign enc_previous_context = {i_filtered_ppg_value, i_frame_id}; // 打包下一次方向比较所需字段

	//其他信号连线
	assign {dec_previous_value, dec_previous_frame_id} = reg_previous_context; // 解码上一合格RED样本
	assign {dec_running_value, dec_running_frame_id, dec_running_sample_index, dec_running_config_epoch, dec_running_coef_epoch, dec_running_dc_epoch} = reg_running_context; // 解码运行极值上下文
	assign {dec_previous_peak_value, dec_previous_peak_frame_id, dec_previous_peak_sample_index, dec_previous_peak_config_epoch, dec_previous_peak_coef_epoch, dec_previous_peak_dc_epoch} = reg_previous_peak_context; // 解码最近正式波峰上下文
	assign {dec_active_peak_value, dec_active_peak_frame_id, dec_active_peak_sample_index, dec_active_peak_config_epoch, dec_active_peak_coef_epoch, dec_active_peak_dc_epoch} = reg_active_peak_context; // 解码当前配对波峰上下文
	// signed 25-bit方向差避免24-bit自然回绕
	assign dec_direction_delta = $signed({i_filtered_ppg_value[C_DATA_WIDTH-1], i_filtered_ppg_value}) - $signed({dec_previous_value[C_DATA_WIDTH-1], dec_previous_value}); // 当前值减上一合格值; @satisfies: PVW-40
	assign enc_deadband_positive = $signed({1'b0, i_direction_deadband}); // 无符号死区扩展为正signed边界
	assign enc_deadband_negative = -enc_deadband_positive; // 对称生成负signed边界
	assign dec_previous_frame_step = i_frame_id - dec_previous_frame_id; // 使用模减检查相邻正式帧
	assign flag_frame_contiguous = flag_previous_valid && (dec_previous_frame_step == {{(C_FRAME_ID_WIDTH - 1){1'b0}}, 1'b1}); // 连续方向证据要求帧差严格为1

	//其他信号连线
	assign flag_direction_rising = flag_frame_contiguous && (dec_direction_delta > enc_deadband_positive); // 超过正死区才是有效上升；平坦/无脉搏输入恒不过死区，杜绝虚假VALLEY方向证据 @satisfies: PRC-01
	assign flag_direction_falling = flag_frame_contiguous && (dec_direction_delta < enc_deadband_negative); // 低于负死区才是有效下降；平坦/无脉搏输入恒不过死区，杜绝虚假PEAK方向证据 @satisfies: PRC-01
	assign cnt_direction_confirm_next = {1'b0, cnt_direction_confirm} + {{C_CONFIRM_COUNT_WIDTH{1'b0}}, 1'b1}; // 显式扩位防止确认计数回绕
	// 波峰候选需要连续下降、峰峰时间和版本语义全部合格
	assign dec_peak_to_peak_frames = dec_running_frame_id - dec_previous_peak_frame_id; // 候选运行最大值相对上一正式峰
	assign flag_peak_interval_legal = (flag_previous_peak_valid == 1'b0) || ((dec_peak_to_peak_frames[C_FRAME_ID_WIDTH-1] == 1'b0) && (dec_peak_to_peak_frames >= i_min_peak_to_peak_frames)); // 只有无可靠前一波峰参照时才豁免峰峰时间，reacquire期间若参照仍在则继续检查；快/慢合法心动周期的峰峰间隔核对点 @satisfies: PRC-06, PVW-03, PVW-08, PVW-09

	//其他信号连线
	assign flag_peak_epoch_match = (flag_previous_peak_valid == 1'b0) || ((dec_running_config_epoch == dec_previous_peak_config_epoch) && (dec_running_coef_epoch == dec_previous_peak_coef_epoch) && (dec_running_dc_epoch == dec_previous_peak_dc_epoch)); // 正式RUN不得跨ACTIVE和系数版本
	assign flag_peak_candidate_event = flag_formal_sample && (state_current == ST_SEARCH_PEAK) && flag_running_valid && (i_filtered_ppg_value < dec_running_value) && flag_direction_falling && (cnt_direction_confirm_next >= {1'b0, i_peak_confirm_count}); // 当前下降样本达到配置确认次数; @satisfies: PVW-04
	assign flag_peak_accept_event = flag_peak_candidate_event && flag_peak_interval_legal && flag_peak_epoch_match; // 合格候选原子建立正式波峰
	assign flag_peak_reject_event = flag_peak_candidate_event && (flag_peak_accept_event == 1'b0); // 时间不足或版本异常拒绝局部峰

	//其他信号连线
	// 波谷候选需要连续上升、正幅度、峰谷时间和版本语义全部合格
	assign dec_peak_valley_amplitude = $signed({dec_active_peak_value[C_DATA_WIDTH-1], dec_active_peak_value}) - $signed({dec_running_value[C_DATA_WIDTH-1], dec_running_value}); // 活动波峰减运行最小值
	assign dec_peak_to_valley_frames = dec_running_frame_id - dec_active_peak_frame_id; // 运行最小值相对活动波峰帧差
	assign flag_valley_amplitude_legal = (dec_peak_valley_amplitude > 0) && ($unsigned(dec_peak_valley_amplitude) >= {1'b0, i_min_peak_valley_amplitude}); // 正幅度达到SPI最小门限; @satisfies: PVW-14
	assign flag_valley_interval_legal = (dec_peak_to_valley_frames[C_FRAME_ID_WIDTH-1] == 1'b0) && (dec_peak_to_valley_frames >= i_min_peak_to_valley_frames); // 峰谷时间必须小于半回绕且达到下界；快/慢合法心动周期的峰谷间隔核对点 @satisfies: PRC-06, PVW-15

	//其他信号连线
	assign flag_valley_epoch_match = flag_active_peak_valid && (dec_running_config_epoch == dec_active_peak_config_epoch) && (dec_running_coef_epoch == dec_active_peak_coef_epoch) && (dec_running_dc_epoch == dec_active_peak_dc_epoch); // 峰谷必须属于同一配置语义
	assign flag_valley_candidate_event = flag_formal_sample && (state_current == ST_SEARCH_VALLEY) && flag_running_valid && flag_active_peak_valid && (i_filtered_ppg_value > dec_running_value) && flag_direction_rising && (cnt_direction_confirm_next >= {1'b0, i_valley_confirm_count}); // 当前上升样本达到配置确认次数; @satisfies: PVW-10
	assign flag_valley_accept_event = flag_valley_candidate_event && flag_valley_amplitude_legal && flag_valley_interval_legal && flag_valley_epoch_match && ((fine_window_active_o == 1'b0) || flag_active_peak_fine_qualified); // 正式fine窗口只接受合格15-bit中心波峰配对；弱重搏切迹下仍可产生完整合格VALLEY @satisfies: PRC-07, PVW-44
	assign flag_valley_restart_event = flag_valley_candidate_event && flag_valley_amplitude_legal && flag_valley_interval_legal && flag_valley_epoch_match && fine_window_active_o && (flag_active_peak_fine_qualified == 1'b0); // 旧9-bit波峰完成粗谷后继续寻找正式fine波峰; @satisfies: PVW-44

	//其他信号连线
	assign flag_valley_epoch_fault_event = flag_valley_candidate_event && (flag_valley_epoch_match == 1'b0); // 跨epoch谷值不能继续配对旧波峰
	// 超时使用真实RED帧差并在达到半回绕前完成
	assign dec_fine_window_age = i_frame_id - reg_fine_window_start_frame_id; // 正式fine窗口真实帧龄
	assign dec_reacquire_age = i_frame_id - reg_reacquire_start_frame_id; // 当前重新获取单轮真实帧龄
	assign dec_active_peak_age = i_frame_id - dec_active_peak_frame_id; // 当前波峰后的真实跟踪帧龄
	assign flag_fine_center_qualified = fine_window_active_o && i_precision_mode && (dec_fine_window_age[C_FRAME_ID_WIDTH-1] == 1'b0); // 中心精度和帧龄同时证明正式fine资格; @satisfies: PVW-43
	assign flag_entry_tail_overflow_event = fine_window_active_o && flag_entry_precision_tail_active && flag_red_time_transfer && (i_precision_mode == 1'b0) && (cnt_entry_precision_tail >= FIR_GROUP_DELAY_LIMIT); // 第11笔旧9-bit中心样本违反有界尾部; @satisfies: PVW-42
	assign flag_entry_tail_reversion_event = fine_window_active_o && flag_entry_precision_tail_complete && flag_red_time_transfer && (i_precision_mode == 1'b0); // 正式15-bit中心出现后禁止精度倒退
	assign flag_exit_tail_overflow_event = flag_exit_precision_tail_active && flag_red_time_transfer && i_precision_mode && (cnt_exit_precision_tail >= FIR_GROUP_DELAY_LIMIT); // 第11笔旧15-bit中心样本违反退出尾部; @satisfies: PVW-45
	assign flag_unauthorized_precision_event = i_run_enable && (i_characterization_mode == 1'b0) && flag_red_time_transfer && (fine_window_active_o == 1'b0) && i_precision_mode && (flag_exit_precision_tail_active == 1'b0); // 非正式窗口不得静默接收15-bit中心样本; @satisfies: PVW-21

	//其他信号连线
	assign flag_fine_window_timeout_event = flag_red_time_transfer && flag_fine_center_qualified && (flag_recovery_return_pending == 1'b0) && (return_9bit_valid_o == 1'b0) && (flag_return_accepted == 1'b0) && (dec_fine_window_age >= i_max_fine_window_frames) && (flag_valley_accept_event == 1'b0); // 仅从首笔正式15-bit中心样本计算窗口超时; @satisfies: PVW-25
	assign flag_reacquire_timeout_event = flag_red_time_transfer && reacquire_search_active_o && flag_reacquire_timer_valid && (state_current == ST_SEARCH_PEAK) && (dec_reacquire_age[C_FRAME_ID_WIDTH-1] == 1'b0) && (dec_reacquire_age >= i_max_reacquire_frames) && (flag_peak_accept_event == 1'b0); // 重新获取失败后自动开始下一轮；越界心动周期不落入假接受而走超时/重新获取 @satisfies: PRC-06, PVW-26
	assign flag_nonfine_valley_timeout_event = flag_red_time_transfer && (fine_window_active_o == 1'b0) && (state_current == ST_SEARCH_VALLEY) && flag_active_peak_valid && (dec_active_peak_age[C_FRAME_ID_WIDTH-1] == 1'b0) && (dec_active_peak_age >= i_max_fine_window_frames) && (flag_valley_accept_event == 1'b0); // 9-bit不完整周期不得永久阻塞峰值搜索；弱重搏切迹无法确认VALLEY时走超时/重新获取而非停在未资格SAR9 @satisfies: PRC-06, PRC-07, PVW-41
	assign flag_fine_protocol_fallback_event = fine_window_active_o && flag_red_time_transfer && (flag_active_config_legal == 1'b0) && (return_9bit_valid_o == 1'b0) && (flag_return_accepted == 1'b0); // 正式窗口配置失效时请求安全回退
	assign flag_precision_drop_event = fine_window_active_o && (i_active_precision_mode == 1'b0) && (flag_return_accepted == 1'b0); // 未完成返回握手却提前切到9-bit
	// 帧序、版本、配置和精度关系异常统一汇总到sticky诊断
	assign flag_epoch_drift_event = flag_formal_sample && flag_running_valid && ((i_config_epoch != dec_running_config_epoch) || (i_coef_epoch != dec_running_coef_epoch) || (i_dc_recovery_coef_epoch != dec_running_dc_epoch)); // 活动候选期间任一配置语义版本发生漂移; @satisfies: PVW-31
	assign flag_frame_protocol_error_event = (flag_formal_sample && flag_previous_valid && (flag_frame_contiguous == 1'b0)) || (flag_peak_candidate_event && flag_previous_peak_valid && dec_peak_to_peak_frames[C_FRAME_ID_WIDTH-1]) || (flag_valley_candidate_event && dec_peak_to_valley_frames[C_FRAME_ID_WIDTH-1]) || (fine_window_active_o && flag_red_time_transfer && i_precision_mode && dec_fine_window_age[C_FRAME_ID_WIDTH-1]) || (reacquire_search_active_o && flag_red_time_transfer && flag_reacquire_timer_valid && dec_reacquire_age[C_FRAME_ID_WIDTH-1]); // 入口旧9-bit负帧龄合法而其他半回绕时间均非法; @satisfies: PVW-20, PVW-39

	//其他信号连线
	assign flag_config_protocol_error_event = i_run_enable && (i_characterization_mode == 1'b0) && ((flag_red_time_transfer && (flag_active_config_legal == 1'b0)) || (i_fine_window_start_event && (flag_active_config_legal == 1'b0))); // NORMAL正式运行不接受未提交配置; @satisfies: PVW-38
	assign flag_mode_protocol_error_event = (i_run_enable && (i_characterization_mode == 1'b0) && (fine_window_active_o == 1'b0) && (i_fine_window_start_event == 1'b0) && i_active_precision_mode) || (i_fine_window_start_event && (fine_window_active_o || flag_exit_precision_tail_active)) || flag_precision_drop_event || flag_entry_tail_overflow_event || flag_entry_tail_reversion_event || flag_exit_tail_overflow_event || flag_unauthorized_precision_event; // 区分当前精度提交和FIR历史精度尾部后汇总异常
	assign flag_protocol_error_event = flag_frame_protocol_error_event || flag_config_protocol_error_event || flag_mode_protocol_error_event || (flag_peak_reject_event && (flag_peak_epoch_match == 1'b0)) || flag_valley_epoch_fault_event || flag_epoch_drift_event || (i_recheck_accept_event && (o_detector_idle == 1'b0)) || (i_recheck_done_event && (i_recheck_success == 1'b0)); // 汇总全部协议异常来源
	assign flag_tracking_restart = flag_reacquire_start_event || flag_reacquire_timeout_event || flag_nonfine_valley_timeout_event || flag_valley_epoch_fault_event || flag_epoch_drift_event || flag_precision_drop_event; // 异常周期重新从峰值搜索开始

	//-------------输出信号连线区域-------------//
	//粗FIR事务接口
	// 上游只在事件保持寄存器可写时继续前送FIR事务
	assign o_result_ready = i_rstn && i_run_enable && (i_recheck_busy == 1'b0) && (peak_valid_o == 1'b0) && (valley_valid_o == 1'b0); // 峰谷事件反压时冻结唯一缓冲所有权; @satisfies: PVW-34

	//正式精度窗口接口
	assign o_return_9bit_valid = return_9bit_valid_o; // 导出返回9-bit保持请求
	assign o_return_reason = return_reason_o;   // 导出冻结的模式返回原因
	assign o_return_frame_id = return_frame_id_o; // 导出返回请求绑定的真实帧号

	//波峰事件接口
	assign o_peak_valid = peak_valid_o;         // 导出波峰保持valid
	assign o_peak_value = peak_value_o;         // 导出波峰运行最大码值
	assign o_peak_frame_id = peak_frame_id_o;   // 导出波峰实际中心帧号
	assign o_peak_sample_index = peak_sample_index_o; // 导出波峰实际事务序号
	assign o_peak_config_epoch = peak_config_epoch_o; // 导出波峰ACTIVE版本身份
	assign o_peak_coef_epoch = peak_coef_epoch_o; // 导出波峰Stage1校准版本
	assign o_peak_dc_recovery_coef_epoch = peak_dc_recovery_coef_epoch_o; // 导出波峰DC恢复版本

	//波谷事件接口
	assign o_valley_valid = valley_valid_o;     // 导出波谷保持valid
	assign o_valley_value = valley_value_o;     // 导出波谷运行最小码值
	assign o_valley_frame_id = valley_frame_id_o; // 导出波谷实际中心帧号
	assign o_valley_sample_index = valley_sample_index_o; // 导出波谷实际事务序号
	assign o_valley_config_epoch = valley_config_epoch_o; // 导出波谷ACTIVE版本身份
	assign o_valley_coef_epoch = valley_coef_epoch_o; // 导出波谷Stage1校准版本
	assign o_valley_dc_recovery_coef_epoch = valley_dc_recovery_coef_epoch_o; // 导出波谷DC恢复版本

	//只读状态接口
	assign o_detector_idle = (peak_valid_o == 1'b0) && (valley_valid_o == 1'b0) && (return_9bit_valid_o == 1'b0) && (flag_return_accepted == 1'b0) && (flag_recovery_return_pending == 1'b0) && (flag_entry_precision_tail_active == 1'b0); // 真实事务与入口尾部排空后允许接管，被动退出尾部不阻挡; @satisfies: PVW-33, PVW-46
	assign o_local_empty = (o_detector_idle == 1'b1) && (flag_entry_precision_tail_active == 1'b0); // 比重检idle更严格，连入口尾部占用也视为pending; @satisfies: PVW-36
	assign o_fine_window_active = fine_window_active_o; // 导出正式fine窗口资格
	assign o_reacquire_search_active = reacquire_search_active_o; // 导出本地重新获取状态
	assign o_fine_window_timeout_sticky = fine_window_timeout_sticky_o; // 导出fine超时历史
	assign o_reacquire_timeout_sticky = reacquire_timeout_sticky_o; // 导出重新获取超时历史
	assign o_protocol_error_sticky = protocol_error_sticky_o; // 导出协议异常历史

	//-------------输出信号处理区域-------------//
	//波峰事件接口
	// 波峰输出valid在下游握手前保持不变
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			peak_valid_o <= 1'b0;               // 复位禁止伪波峰事件; @satisfies: PVW-01
		end else if(flag_context_clear == 1'b1)begin
			peak_valid_o <= 1'b0;               // 生命周期边界撤销在途波峰
		end else if(flag_peak_transfer == 1'b1)begin
			peak_valid_o <= 1'b0;               // 唯一握手后释放波峰缓冲
		end else if(flag_peak_accept_event == 1'b1)begin
			peak_valid_o <= 1'b1;               // 合格候选建立保持型波峰事件
		end else begin
			peak_valid_o <= peak_valid_o;       // 反压和空拍期间保持valid; @satisfies: PVW-28
		end
	end

	// 波峰载荷只在新事件建立时更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			peak_payload_o <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 复位清除波峰原子输出载荷
		end else if(flag_context_clear == 1'b1)begin
			peak_payload_o <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 生命周期边界删除旧RUN波峰身份
		end else if(flag_peak_accept_event == 1'b1)begin
			peak_payload_o <= reg_running_context; // 冻结运行最大值的实际中心上下文; @satisfies: PVW-17
		end else begin
			peak_payload_o <= peak_payload_o;   // 波峰反压期间逐位保持载荷
		end
	end

	//波谷事件接口
	// 波谷输出valid在下游握手前保持不变
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			valley_valid_o <= 1'b0;             // 复位关闭波谷确认通道
		end else if(flag_context_clear == 1'b1)begin
			valley_valid_o <= 1'b0;             // 新运行边界作废旧波谷结论
		end else if(flag_valley_transfer == 1'b1)begin
			valley_valid_o <= 1'b0;             // 下游接收后释放谷值事件槽
		end else if(flag_valley_accept_event == 1'b1)begin
			valley_valid_o <= 1'b1;             // 完整峰谷资格建立谷值通知
		end else begin
			valley_valid_o <= valley_valid_o;   // 未消费谷值继续保持通知电平; @satisfies: PVW-29
		end
	end

	// 波谷载荷只在新事件建立时更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			valley_payload_o <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 复位清除波谷原子输出载荷
		end else if(flag_context_clear == 1'b1)begin
			valley_payload_o <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 生命周期边界删除旧RUN波谷身份
		end else if(flag_valley_accept_event == 1'b1)begin
			valley_payload_o <= reg_running_context; // 冻结运行最小值的实际中心上下文; @satisfies: PVW-16
		end else begin
			valley_payload_o <= valley_payload_o; // 波谷反压期间逐位保持载荷
		end
	end

	//正式精度窗口接口
	// 返回请求valid覆盖谷值成功、窗口超时和协议回退三类原因
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			return_9bit_valid_o <= 1'b0;        // 复位禁止伪模式请求
		end else if(flag_context_clear == 1'b1)begin
			return_9bit_valid_o <= 1'b0;        // 生命周期边界撤销旧RUN请求
		end else if(flag_return_transfer == 1'b1)begin
			return_9bit_valid_o <= 1'b0;        // 模式控制器接受后释放请求valid
		end else if(flag_valley_accept_event == 1'b1 && fine_window_active_o == 1'b1)begin
			return_9bit_valid_o <= 1'b1;        // 正式窗口合格谷值请求返回9-bit; @satisfies: PVW-24
		end else if(flag_fine_window_timeout_event == 1'b1 || flag_fine_protocol_fallback_event == 1'b1)begin
			return_9bit_valid_o <= 1'b1;        // 异常窗口同样使用保持型安全回退
		end else begin
			return_9bit_valid_o <= return_9bit_valid_o; // 反压期间保持请求; @satisfies: PVW-30
		end
	end

	// 返回载荷在请求建立时冻结原因和当前确认帧
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			return_payload_o <= {RETURN_CONTEXT_WIDTH{1'b0}}; // 复位清除模式返回载荷
		end else if(flag_context_clear == 1'b1)begin
			return_payload_o <= {RETURN_CONTEXT_WIDTH{1'b0}}; // 生命周期边界删除旧窗口身份
		end else if(flag_valley_accept_event == 1'b1 && fine_window_active_o == 1'b1 && return_9bit_valid_o == 1'b0)begin
			return_payload_o <= {RETURN_REASON_VALLEY, i_frame_id}; // 绑定波谷确认样本的真实帧号；已有未握手返回请求时不覆盖，与超时/回退两支对称 @satisfies: PVW-30
		end else if(flag_fine_window_timeout_event == 1'b1)begin
			return_payload_o <= {RETURN_REASON_TIMEOUT, i_frame_id}; // 绑定达到窗口上限的RED帧号
		end else if(flag_fine_protocol_fallback_event == 1'b1)begin
			return_payload_o <= {RETURN_REASON_PROTOCOL, i_frame_id}; // 绑定发现协议错误的RED帧号
		end else begin
			return_payload_o <= return_payload_o; // 返回反压期间禁止原因和帧号漂移
		end
	end

	//只读状态接口
	// 正式fine窗口只由明确提交事件建立并在实际返回后结束
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fine_window_active_o <= 1'b0;       // 复位时没有正式15-bit窗口
		end else if(flag_context_clear == 1'b1 || flag_precision_drop_event == 1'b1)begin
			fine_window_active_o <= 1'b0;       // 生命周期或异常精度下降撤销窗口
		end else if(flag_fine_exit_complete == 1'b1)begin
			fine_window_active_o <= 1'b0;       // 正常请求完成后结束窗口资格; @satisfies: PVW-24
		end else if(i_fine_window_start_event == 1'b1 && flag_active_config_legal == 1'b1)begin
			fine_window_active_o <= 1'b1;       // 模式控制器commit事件建立正式窗口; @satisfies: PVW-22, PVW-23
		end else begin
			fine_window_active_o <= fine_window_active_o; // 普通精度样本不改变正式资格
		end
	end

	// 本地重新获取状态在首峰事件被动态基线消费后结束
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reacquire_search_active_o <= 1'b0;  // 复位等待新START建立重新获取
		end else if(flag_runtime_clear == 1'b1)begin
			reacquire_search_active_o <= 1'b0;  // STOP、abort或重检接管清除本地搜索
		end else if(i_start_ack_event == 1'b1 || (i_recheck_done_event == 1'b1 && i_recheck_success == 1'b1) || flag_reacquire_start_event == 1'b1 || flag_reacquire_timeout_event == 1'b1 || flag_nonfine_valley_timeout_event == 1'b1 || flag_valley_epoch_fault_event == 1'b1)begin
			reacquire_search_active_o <= 1'b1;  // 启动、恢复或不完整周期进入9-bit重新获取; @satisfies: PVW-02
		end else if(flag_peak_transfer == 1'b1)begin
			reacquire_search_active_o <= 1'b0;  // 新锚点被动态基线消费后完成重新获取; @satisfies: PVW-27
		end else begin
			reacquire_search_active_o <= reacquire_search_active_o; // 其余时刻保持本地搜索状态
		end
	end

	// fine窗口超时sticky记录历史而不阻止后续安全恢复
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			fine_window_timeout_sticky_o <= 1'b0; // 复位清除全部历史诊断
		end else if(flag_fine_window_timeout_event == 1'b1)begin
			fine_window_timeout_sticky_o <= 1'b1; // 新超时与同拍clear冲突时置位优先
		end else if(i_diag_clear_event == 1'b1)begin
			fine_window_timeout_sticky_o <= 1'b0; // fine窗口超时历史只认诊断清除命令
		end else begin
			fine_window_timeout_sticky_o <= fine_window_timeout_sticky_o; // 新RUN接受和fine窗口安全退出都不冲刷这段超时记录
		end
	end

	// 重新获取超时sticky同时记录9-bit不完整周期和单轮搜索超时
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reacquire_timeout_sticky_o <= 1'b0; // 复位清除全部重新获取历史
		end else if(flag_reacquire_timeout_event == 1'b1 || flag_nonfine_valley_timeout_event == 1'b1)begin
			reacquire_timeout_sticky_o <= 1'b1; // 任一重新获取超时永久记录到明确清除
		end else if(i_diag_clear_event == 1'b1)begin
			reacquire_timeout_sticky_o <= 1'b0; // 重新获取超时历史需要诊断命令才能翻篇
		end else begin
			reacquire_timeout_sticky_o <= reacquire_timeout_sticky_o; // 新一轮重新获取即便成功命中也不会替我们把旧超时抹掉
		end
	end

	// 协议sticky汇总配置、帧序、epoch、模式和非法重检接管
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			protocol_error_sticky_o <= 1'b0;    // 复位建立无协议故障初态
		end else if(flag_protocol_error_event == 1'b1)begin
			protocol_error_sticky_o <= 1'b1;    // 新协议违例覆盖同拍软件清除; @satisfies: PVW-37
		end else if(i_diag_clear_event == 1'b1)begin
			protocol_error_sticky_o <= 1'b0;    // 只有诊断命令确认协议记录已读才能清除
		end else begin
			protocol_error_sticky_o <= protocol_error_sticky_o; // 新START与无清除授权时均保留协议违例证据; @satisfies: PVW-35, PVW-37
		end
	end

	//----------------状态机区域----------------//
	// 下一状态只描述峰谷方向阶段，精度窗口资格由独立寄存器保持
	always@(*)begin
		state_next = state_current;             // 默认保持当前搜索阶段
		if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1 || flag_fine_window_timeout_event == 1'b1)begin
			state_next = ST_SEARCH_PEAK;        // 生命周期或异常恢复重新寻找波峰
		end else if(flag_peak_accept_event == 1'b1)begin
			state_next = ST_SEARCH_VALLEY;      // 合格波峰后开始跟踪运行最小值
		end else if(flag_peak_reject_event == 1'b1)begin
			state_next = ST_SEARCH_PEAK;        // 局部峰拒绝后重新武装最大值搜索
		end else if(flag_valley_accept_event == 1'b1 || flag_valley_restart_event == 1'b1)begin
			state_next = ST_SEARCH_PEAK;        // 合格波谷后进入下一心搏波峰搜索
		end else begin
			state_next = state_current;         // 其余样本保持当前方向阶段
		end
	end

	// 当前峰谷阶段在异步复位和每个2 MHz上升沿稳定提交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_SEARCH_PEAK;    // 复位后从9-bit首峰获取开始
		end else begin
			state_current <= state_next;        // 提交组合计算的下一检测阶段
		end
	end

	//-------------状态任务处理区域-------------//
	// 运行上下文在搜索峰时保存最大值，在搜索谷时保存最小值
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_running_context <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 复位清除运行极值载荷
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1 || flag_fine_window_timeout_event == 1'b1)begin
			reg_running_context <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 恢复时丢弃不完整局部极值
		end else if(flag_formal_sample == 1'b1)begin
			if(state_current == ST_SEARCH_PEAK)begin
				if((flag_running_valid == 1'b0) || (i_filtered_ppg_value >= dec_running_value) || flag_peak_accept_event == 1'b1 || flag_peak_reject_event == 1'b1)begin
					reg_running_context <= enc_input_context; // 更新最大值平台或初始化下一阶段最小值; @satisfies: PVW-05
				end else begin
					reg_running_context <= reg_running_context; // 非更高样本保留运行最大值
				end
			end else begin
				if((flag_running_valid == 1'b0) || (i_filtered_ppg_value <= dec_running_value) || flag_valley_accept_event == 1'b1 || flag_valley_restart_event == 1'b1)begin
					reg_running_context <= enc_input_context; // 更新最小值平台或初始化下一周期最大值; @satisfies: PVW-11
				end else begin
					reg_running_context <= reg_running_context; // 非更低样本保留运行最小值
				end
			end
		end else begin
			reg_running_context <= reg_running_context; // IR、空拍和无资格事务不移动极值
		end
	end

	// 运行极值精度资格始终与当前运行极值载荷同步更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_running_fine_qualified <= 1'b0; // 复位时没有正式fine极值资格
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1 || flag_fine_window_timeout_event == 1'b1)begin
			flag_running_fine_qualified <= 1'b0; // 恢复边界撤销不完整极值的精度身份
		end else if(flag_formal_sample == 1'b1)begin
			if(state_current == ST_SEARCH_PEAK)begin
				if((flag_running_valid == 1'b0) || (i_filtered_ppg_value >= dec_running_value) || flag_peak_accept_event == 1'b1 || flag_peak_reject_event == 1'b1)begin
					flag_running_fine_qualified <= flag_fine_center_qualified; // 新最大值或下一阶段初值绑定当前中心精度
				end else begin
					flag_running_fine_qualified <= flag_running_fine_qualified; // 保留既有运行最大值精度身份
				end
			end else begin
				if((flag_running_valid == 1'b0) || (i_filtered_ppg_value <= dec_running_value) || flag_valley_accept_event == 1'b1 || flag_valley_restart_event == 1'b1)begin
					flag_running_fine_qualified <= flag_fine_center_qualified; // 新最小值或下一周期初值绑定当前中心精度
				end else begin
					flag_running_fine_qualified <= flag_running_fine_qualified; // 保留既有运行最小值精度身份
				end
			end
		end else begin
			flag_running_fine_qualified <= flag_running_fine_qualified; // 非正式事务不改变极值精度身份
		end
	end

	// 方向确认计数按死区分类累计并在反方向或阶段边界清零
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_direction_confirm <= {C_CONFIRM_COUNT_WIDTH{1'b0}}; // 复位清除连续方向证据
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1 || flag_fine_window_timeout_event == 1'b1 || flag_peak_accept_event == 1'b1 || flag_peak_reject_event == 1'b1 || flag_valley_accept_event == 1'b1 || flag_valley_restart_event == 1'b1)begin
			cnt_direction_confirm <= {C_CONFIRM_COUNT_WIDTH{1'b0}}; // 阶段提交或恢复后重新累计
		end else if(flag_formal_sample == 1'b1 && (flag_frame_contiguous == 1'b0))begin
			cnt_direction_confirm <= {C_CONFIRM_COUNT_WIDTH{1'b0}}; // 跳帧不能拼接连续证据
		end else if(flag_formal_sample == 1'b1 && (state_current == ST_SEARCH_PEAK))begin
			if((flag_running_valid == 1'b0) || (i_filtered_ppg_value >= dec_running_value) || flag_direction_rising == 1'b1)begin
				cnt_direction_confirm <= {C_CONFIRM_COUNT_WIDTH{1'b0}}; // 新最大值或反向上升取消下降候选; @satisfies: PVW-07
			end else if(flag_direction_falling == 1'b1)begin
				if(cnt_direction_confirm < i_peak_confirm_count)begin
					cnt_direction_confirm <= cnt_direction_confirm + {{(C_CONFIRM_COUNT_WIDTH - 1){1'b0}}, 1'b1}; // 有效下降累计到配置上限
				end else begin
					cnt_direction_confirm <= cnt_direction_confirm; // 达到门限后保持防止回绕
				end
			end else begin
				cnt_direction_confirm <= cnt_direction_confirm; // 死区平坦样本既不增加也不清零; @satisfies: PVW-06
			end
		end else if(flag_formal_sample == 1'b1 && (state_current == ST_SEARCH_VALLEY))begin
			if((flag_running_valid == 1'b0) || (i_filtered_ppg_value <= dec_running_value) || flag_direction_falling == 1'b1)begin
				cnt_direction_confirm <= {C_CONFIRM_COUNT_WIDTH{1'b0}}; // 新最小值或反向下降取消上升候选; @satisfies: PVW-13
			end else if(flag_direction_rising == 1'b1)begin
				if(cnt_direction_confirm < i_valley_confirm_count)begin
					cnt_direction_confirm <= cnt_direction_confirm + {{(C_CONFIRM_COUNT_WIDTH - 1){1'b0}}, 1'b1}; // 有效上升累计到配置上限
				end else begin
					cnt_direction_confirm <= cnt_direction_confirm; // 上升证据已满时锁定谷值确认计数
				end
			end else begin
				cnt_direction_confirm <= cnt_direction_confirm; // 死区平坦样本保持既有上升证据; @satisfies: PVW-12
			end
		end else begin
			cnt_direction_confirm <= cnt_direction_confirm; // IR和空拍不改变连续计数
		end
	end

	//-------------主要任务处理区域-------------//
	// 上一合格RED上下文只在正式样本转移时更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_previous_context <= {PREVIOUS_CONTEXT_WIDTH{1'b0}}; // 复位清除相邻比较载荷
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1)begin
			reg_previous_context <= {PREVIOUS_CONTEXT_WIDTH{1'b0}}; // 恢复边界禁止拼接旧方向证据
		end else if(flag_formal_sample == 1'b1)begin
			reg_previous_context <= enc_previous_context; // 保存当前值和真实中心帧
		end else begin
			reg_previous_context <= reg_previous_context; // 无正式RED样本时保持
		end
	end

	// 上一合格样本valid与上下文使用相同清理边界
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_previous_valid <= 1'b0;        // 复位时没有方向参考样本
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1)begin
			flag_previous_valid <= 1'b0;        // 新阶段第一笔样本只建立参考
		end else if(flag_formal_sample == 1'b1)begin
			flag_previous_valid <= 1'b1;        // 当前正式样本可供下一次方向比较
		end else begin
			flag_previous_valid <= flag_previous_valid; // 空拍和IR不改变RED参考资格
		end
	end

	// 运行极值valid在第一笔正式样本后建立
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_running_valid <= 1'b0;         // 复位时没有运行极值
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1 || flag_fine_window_timeout_event == 1'b1)begin
			flag_running_valid <= 1'b0;         // 新搜索阶段等待真实RED样本初始化
		end else if(flag_formal_sample == 1'b1)begin
			flag_running_valid <= 1'b1;         // 当前正式样本建立或延续运行极值
		end else begin
			flag_running_valid <= flag_running_valid; // 无正式样本时保持极值资格
		end
	end

	// 最近正式波峰只由合格候选原子更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_previous_peak_context <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 复位清除峰峰时间参考
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1)begin
			reg_previous_peak_context <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 新RUN或重检后首峰免除周期检查
		end else if(flag_peak_accept_event == 1'b1)begin
			reg_previous_peak_context <= reg_running_context; // 保存波峰实际最大值和中心元数据
		end else begin
			reg_previous_peak_context <= reg_previous_peak_context; // 局部峰和空拍不得覆盖正式波峰
		end
	end

	// 最近正式波峰valid与波峰上下文同步提交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_previous_peak_valid <= 1'b0;   // 复位时没有峰峰时间参考
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1)begin
			flag_previous_peak_valid <= 1'b0;   // 恢复后的首峰不检查上一RUN时间
		end else if(flag_peak_accept_event == 1'b1)begin
			flag_previous_peak_valid <= 1'b1;   // 合格波峰建立后续峰峰门限参考
		end else begin
			flag_previous_peak_valid <= flag_previous_peak_valid; // 其他事件保持正式峰资格
		end
	end

	// 当前活动波峰只服务后续谷值幅度、时间和epoch配对
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_active_peak_context <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 复位清除未完成峰谷对
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1 || flag_fine_window_timeout_event == 1'b1 || flag_valley_accept_event == 1'b1 || flag_valley_restart_event == 1'b1)begin
			reg_active_peak_context <= {SAMPLE_CONTEXT_WIDTH{1'b0}}; // 周期完成或故障恢复释放活动波峰
		end else if(flag_peak_accept_event == 1'b1)begin
			reg_active_peak_context <= reg_running_context; // 冻结本周期波峰供谷值配对
		end else begin
			reg_active_peak_context <= reg_active_peak_context; // 波谷搜索期间保持波峰身份
		end
	end

	// 当前活动波峰valid防止无峰情况下伪造谷值
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_active_peak_valid <= 1'b0;     // 复位时没有可配对波峰
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1 || flag_fine_window_timeout_event == 1'b1 || flag_valley_accept_event == 1'b1 || flag_valley_restart_event == 1'b1)begin
			flag_active_peak_valid <= 1'b0;     // 周期完成或恢复后重新寻找波峰
		end else if(flag_peak_accept_event == 1'b1)begin
			flag_active_peak_valid <= 1'b1;     // 合格波峰开启波谷搜索资格
		end else begin
			flag_active_peak_valid <= flag_active_peak_valid; // 其他事件保持活动峰资格
		end
	end

	// 活动波峰保存其运行最大值是否来自正式15-bit中心区间
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_active_peak_fine_qualified <= 1'b0; // 复位时没有正式fine波峰
		end else if(flag_context_clear == 1'b1 || i_recheck_done_event == 1'b1 || flag_tracking_restart == 1'b1 || flag_fine_window_timeout_event == 1'b1 || flag_valley_accept_event == 1'b1 || flag_valley_restart_event == 1'b1)begin
			flag_active_peak_fine_qualified <= 1'b0; // 周期结束或恢复边界撤销活动fine资格
		end else if(flag_peak_accept_event == 1'b1)begin
			flag_active_peak_fine_qualified <= flag_running_fine_qualified; // 原子绑定被确认运行最大值的历史精度
		end else begin
			flag_active_peak_fine_qualified <= flag_active_peak_fine_qualified; // 波谷搜索期间保持波峰精度身份
		end
	end

	// 返回接受标志等待系统精度状态真正切回9-bit
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_return_accepted <= 1'b0;       // 复位时没有待完成模式切换
		end else if(flag_context_clear == 1'b1 || flag_fine_exit_complete == 1'b1)begin
			flag_return_accepted <= 1'b0;       // 生命周期或实际9-bit完成后释放标志
		end else if(flag_return_transfer == 1'b1)begin
			flag_return_accepted <= 1'b1;       // 握手后等待下一安全帧精度提交
		end else begin
			flag_return_accepted <= flag_return_accepted; // 其他时刻保持返回提交历史
		end
	end

	// 进入15-bit后的旧9-bit中心样本尾部按RED NORMAL事务有界计数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_entry_precision_tail_active <= 1'b0; // 复位时不存在进入尾部
		end else if(flag_context_clear == 1'b1 || flag_fine_exit_complete == 1'b1 || flag_precision_drop_event == 1'b1)begin
			flag_entry_precision_tail_active <= 1'b0; // 生命周期、退出或异常下降终止进入尾部
		end else if(i_fine_window_start_event == 1'b1 && flag_active_config_legal == 1'b1)begin
			flag_entry_precision_tail_active <= 1'b1; // 正式窗口提交后允许最多10笔旧9-bit中心样本
		end else if(fine_window_active_o == 1'b1 && flag_red_time_transfer == 1'b1 && i_precision_mode == 1'b1)begin
			flag_entry_precision_tail_active <= 1'b0; // 首笔15-bit中心样本结束进入尾部
		end else begin
			flag_entry_precision_tail_active <= flag_entry_precision_tail_active; // 其他事务保持尾部状态
		end
	end

	// 进入尾部完成标志用于禁止正式15-bit中心出现后的精度倒退
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_entry_precision_tail_complete <= 1'b0; // 复位时尚未观察正式15-bit中心
		end else if(flag_context_clear == 1'b1 || flag_fine_exit_complete == 1'b1 || flag_precision_drop_event == 1'b1)begin
			flag_entry_precision_tail_complete <= 1'b0; // 窗口结束或生命周期边界清除完成历史
		end else if(i_fine_window_start_event == 1'b1 && flag_active_config_legal == 1'b1)begin
			flag_entry_precision_tail_complete <= 1'b0; // 新窗口重新等待首笔15-bit中心样本
		end else if(fine_window_active_o == 1'b1 && flag_red_time_transfer == 1'b1 && i_precision_mode == 1'b1)begin
			flag_entry_precision_tail_complete <= 1'b1; // 记录正式中心精度已经到达
		end else begin
			flag_entry_precision_tail_complete <= flag_entry_precision_tail_complete; // 其他事务保持完成历史
		end
	end

	// 进入尾部计数仅累计旧9-bit RED NORMAL中心样本
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_entry_precision_tail <= {C_INTERVAL_WIDTH{1'b0}}; // 复位清零进入尾部计数
		end else if(flag_context_clear == 1'b1 || flag_fine_exit_complete == 1'b1 || flag_precision_drop_event == 1'b1 || (i_fine_window_start_event == 1'b1 && flag_active_config_legal == 1'b1))begin
			cnt_entry_precision_tail <= {C_INTERVAL_WIDTH{1'b0}}; // 新窗口或清理边界从零累计
		end else if(flag_entry_precision_tail_active == 1'b1 && flag_red_time_transfer == 1'b1 && i_precision_mode == 1'b0)begin
			if(cnt_entry_precision_tail < FIR_GROUP_DELAY_LIMIT)begin
				cnt_entry_precision_tail <= cnt_entry_precision_tail + {{(C_INTERVAL_WIDTH - 1){1'b0}}, 1'b1}; // 前10笔旧中心样本逐笔累计
			end else begin
				cnt_entry_precision_tail <= cnt_entry_precision_tail; // 超限后保持计数供sticky诊断
			end
		end else begin
			cnt_entry_precision_tail <= cnt_entry_precision_tail; // IR、空拍和新精度样本不增加旧尾部计数
		end
	end

	// 实际返回9-bit后允许FIR继续排空最多10笔旧15-bit中心样本
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_exit_precision_tail_active <= 1'b0; // 复位时不存在退出尾部
		end else if(flag_context_clear == 1'b1 || (i_fine_window_start_event == 1'b1 && flag_active_config_legal == 1'b1))begin
			flag_exit_precision_tail_active <= 1'b0; // 生命周期或新窗口提交清除旧退出尾部
		end else if(flag_fine_exit_complete == 1'b1)begin
			flag_exit_precision_tail_active <= 1'b1; // 实际切回9-bit后等待历史15-bit中心排空
		end else if(flag_exit_precision_tail_active == 1'b1 && flag_red_time_transfer == 1'b1 && i_precision_mode == 1'b0)begin
			flag_exit_precision_tail_active <= 1'b0; // 首笔9-bit中心样本结束退出尾部
		end else begin
			flag_exit_precision_tail_active <= flag_exit_precision_tail_active; // 其他事务保持退出尾部状态
		end
	end

	// 退出尾部计数仅累计旧15-bit RED NORMAL中心样本
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_exit_precision_tail <= {C_INTERVAL_WIDTH{1'b0}}; // 复位清零退出尾部计数
		end else if(flag_context_clear == 1'b1 || flag_fine_exit_complete == 1'b1 || (i_fine_window_start_event == 1'b1 && flag_active_config_legal == 1'b1))begin
			cnt_exit_precision_tail <= {C_INTERVAL_WIDTH{1'b0}}; // 实际退出或新窗口边界从零累计
		end else if(flag_exit_precision_tail_active == 1'b1 && flag_red_time_transfer == 1'b1 && i_precision_mode == 1'b1)begin
			if(cnt_exit_precision_tail < FIR_GROUP_DELAY_LIMIT)begin
				cnt_exit_precision_tail <= cnt_exit_precision_tail + {{(C_INTERVAL_WIDTH - 1){1'b0}}, 1'b1}; // 返回后历史15-bit中心计数递增
			end else begin
				cnt_exit_precision_tail <= cnt_exit_precision_tail; // 退出尾部达到上限后冻结诊断依据
			end
		end else begin
			cnt_exit_precision_tail <= cnt_exit_precision_tail; // IR、空拍和新9-bit中心不增加旧尾部计数
		end
	end

	// fine窗口起始帧只在正式提交事件捕获
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_fine_window_start_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除窗口时间起点
		end else if(flag_context_clear == 1'b1)begin
			reg_fine_window_start_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 生命周期边界删除旧窗口时间
		end else if(i_fine_window_start_event == 1'b1 && flag_active_config_legal == 1'b1)begin
			reg_fine_window_start_frame_id <= i_fine_window_start_frame_id; // 冻结第一笔正式15-bit帧号
		end else begin
			reg_fine_window_start_frame_id <= reg_fine_window_start_frame_id; // 窗口期间保持起点
		end
	end

	// 重新获取计时资格在第一笔RED事务建立
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_reacquire_timer_valid <= 1'b0; // 复位时没有真实帧时间起点
		end else if(flag_context_clear == 1'b1 || (i_recheck_done_event == 1'b1 && i_recheck_success == 1'b1) || flag_reacquire_start_event == 1'b1 || flag_peak_transfer == 1'b1)begin
			flag_reacquire_timer_valid <= 1'b0; // 新一轮等待第一笔RED事务建立起点
		end else if(flag_reacquire_timeout_event == 1'b1 || flag_nonfine_valley_timeout_event == 1'b1 || flag_valley_epoch_fault_event == 1'b1)begin
			flag_reacquire_timer_valid <= 1'b1; // 当前故障帧直接作为下一轮起点
		end else if(reacquire_search_active_o == 1'b1 && flag_red_time_transfer == 1'b1 && (flag_reacquire_timer_valid == 1'b0))begin
			flag_reacquire_timer_valid <= 1'b1; // 捕获单轮第一笔真实RED帧
		end else begin
			flag_reacquire_timer_valid <= flag_reacquire_timer_valid; // 其他时刻保持计时资格
		end
	end

	// 重新获取起始帧在每轮第一笔RED或超时重启时更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_reacquire_start_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除重新获取起点
		end else if(flag_context_clear == 1'b1 || (i_recheck_done_event == 1'b1 && i_recheck_success == 1'b1) || flag_reacquire_start_event == 1'b1)begin
			reg_reacquire_start_frame_id <= {C_FRAME_ID_WIDTH{1'b0}}; // 新一轮等待真实RED帧
		end else if(flag_reacquire_timeout_event == 1'b1 || flag_nonfine_valley_timeout_event == 1'b1 || flag_valley_epoch_fault_event == 1'b1)begin
			reg_reacquire_start_frame_id <= i_frame_id; // 超时或版本故障帧成为下一轮起点
		end else if(reacquire_search_active_o == 1'b1 && flag_red_time_transfer == 1'b1 && (flag_reacquire_timer_valid == 1'b0))begin
			reg_reacquire_start_frame_id <= i_frame_id; // 保存单轮第一笔真实RED帧
		end else begin
			reg_reacquire_start_frame_id <= reg_reacquire_start_frame_id; // 单轮搜索期间保持起点
		end
	end

	// 异常返回等待上层在实际9-bit后反馈重新获取控制
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_recovery_return_pending <= 1'b0; // 复位时没有异常模式恢复
		end else if(flag_context_clear == 1'b1 || (i_recheck_done_event == 1'b1 && i_recheck_success == 1'b1) || flag_reacquire_start_event == 1'b1)begin
			flag_recovery_return_pending <= 1'b0; // 生命周期或正式重新获取接管结束等待
		end else if(flag_fine_window_timeout_event == 1'b1 || flag_fine_protocol_fallback_event == 1'b1 || flag_precision_drop_event == 1'b1 || (i_recheck_done_event == 1'b1 && (i_recheck_success == 1'b0)))begin
			flag_recovery_return_pending <= 1'b1; // timeout或协议异常停止继续形成峰谷事件
		end else begin
			flag_recovery_return_pending <= flag_recovery_return_pending; // 等待模式控制器反馈重新获取
		end
	end

endmodule
