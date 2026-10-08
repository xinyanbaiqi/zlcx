`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/23
// Design Name:        PPG System Fault Abort Supervisor
// Module Name:        ppg_system_fault_abort_supervisor
// Description:        Description/ppg_system_fault_abort_supervisor_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_system_fault_abort_supervisor
//
// Referrences:        PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md
//
// Dependencies:       None
//
// Version:            V1.1
// Revision Date:      2026/10/07
// History:
//    Time               Version       Revised by            Contents
// 2026/08/23            V1.0          Erie                  Create file. First RTL implementation of contract C24 (V1.5): blocking-fault aggregation across AMI/Scheduler/SSW, first-fault snapshot, historical summary, ADC physical-drain watchdog, episode-scoped abort/stop-request/fault-discard event generation, and result-discard sticky.
// 2026/10/07            V1.1          Erie                  Owner-lifecycle round: summary mapping adds AMI cause 8'h06 (consecutive ADC completion loss) to bit 9 and 8'h07 (ADC not returning idle) to bit 10.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月23日
// 设计名称:           PPG系统故障与abort监督器
// 模块名称:           ppg_system_fault_abort_supervisor
// 模块说明:           Description/ppg_system_fault_abort_supervisor_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_system_fault_abort_supervisor
//
// 参考资料:           PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md
//
// 依赖文件:           无
//
// 当前版本:           V1.1
// 修订日期:           2026年10月07日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月23日        V1.0          Erie                  创建文件。合同C24（V1.5）首次RTL实现：聚合AMI/Scheduler/SSW三路阻断故障、首故障快照、历史汇总位图、ADC物理排空看门狗、episode范围内的abort/stop请求/故障丢弃事件生成，以及结果丢弃历史sticky
// 2026年10月07日        V1.1          Erie                  owner生命周期轮：汇总位映射新增AMI cause 8'h06（连续完成丢失）到bit 9、8'h07（ADC长期不回空闲）到bit 10。
// 聚合AMI、Scheduler、SSW三路注册式阻断故障记录，维护首故障快照与历史汇总，驱动ADC物理排空看门狗，并在每个故障episode开启时各发出一次注册式abort、STOP请求与丢弃事件
module ppg_system_fault_abort_supervisor
#(
	parameter integer C_FRAME_ID_WIDTH                   = 32'd16, // 故障绑定事务的物理帧号字段位宽
	parameter integer C_SAMPLE_INDEX_WIDTH               = 32'd16, // 故障绑定事务的全局顺序编号字段位宽
	parameter integer C_CONFIG_EPOCH_WIDTH               = 32'd8, // 合同1节声明的保留宽度参数，供以后ACTIVE配置版本类字段扩展
	parameter integer C_COEF_EPOCH_WIDTH                 = 32'd8, // 合同1节声明的保留宽度参数，供以后Stage1系数版本类字段扩展
	parameter integer C_DC_RECOVERY_EPOCH_WIDTH          = 32'd8, // 合同1节声明的保留宽度参数，供以后DC恢复版本类字段扩展
	parameter integer C_CODE_EPOCH_WIDTH                 = 32'd4, // 合同1节声明的保留宽度参数，供以后IDAC码版本类字段扩展
	parameter integer C_RUN_GENERATION_WIDTH             = 32'd8, // 故障绑定事务所属RUN代际字段位宽
	parameter integer C_FAULT_CAUSE_WIDTH                = 32'd8, // 故障cause编码字段位宽
	parameter integer C_FAULT_SOURCE_WIDTH               = 32'd4, // 故障来源编码字段位宽
	parameter integer C_FAULT_SUMMARY_WIDTH              = 32'd16, // 历史汇总位图字段位宽
	parameter integer C_ADC_DRAIN_WATCHDOG_CYCLES        = 32'd5000, // 看门狗超时判定的连续非idle采样周期数
	parameter integer C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH = 32'd13 // 看门狗计数器字段位宽
)
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 2 MHz系统控制时钟
	input i_rstn,                               // 低有效异步复位输入

	//---------------AMI故障记录接口---------------//
	input i_ami_fault_valid,                       // AMI七路阻断故障分发器本拍产生一条注册记录
	input i_ami_fault_active,                      // AMI七路lane-active按位或，仍有未解决阻断故障时为高
	input [C_FAULT_CAUSE_WIDTH - 1:0]i_ami_fault_cause, // AMI本条记录锁定的故障来源编码
	input i_ami_fault_identity_valid,              // AMI本条记录是否绑定真实事务身份
	input [C_FRAME_ID_WIDTH - 1:0]i_ami_fault_frame_id, // AMI本条记录绑定事务的真实物理帧号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_ami_fault_sample_index, // AMI本条记录绑定事务的全局顺序编号
	input i_ami_fault_color_ir,                    // AMI本条记录绑定事务的颜色身份
	input [1:0]i_ami_fault_frame_type,             // AMI本条记录绑定事务的帧类型编码
	input i_ami_fault_precision,                   // AMI本条记录绑定事务建立时所属的精度模式
	input [C_RUN_GENERATION_WIDTH - 1:0]i_ami_fault_run_generation, // AMI本条记录绑定事务所属的RUN代际

	//------------Scheduler故障记录接口------------//
	input i_scheduler_fault_valid,                 // 来自Scheduler的阻断故障本拍新产生一条注册记录
	input i_scheduler_fault_active,                // 来自Scheduler的阻断故障尚未解决时持续保持为高
	input [C_FAULT_CAUSE_WIDTH - 1:0]i_scheduler_fault_cause, // 锁定本条Scheduler记录所指向的故障来源编码
	input i_scheduler_fault_identity_valid,        // 标记本条Scheduler记录携带的事务身份是否可以采信
	input [C_FRAME_ID_WIDTH - 1:0]i_scheduler_fault_frame_id, // 本条Scheduler记录所指事务在物理帧序列中的编号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_scheduler_fault_sample_index, // 本条Scheduler记录所指事务在全局事务流中的顺序位置
	input i_scheduler_fault_color_ir,              // 本条Scheduler记录所指事务采集的颜色通道
	input [1:0]i_scheduler_fault_frame_type,       // 本条Scheduler记录所指事务的AMB/DCS/NORMAL类型归类
	input i_scheduler_fault_precision,             // 本条Scheduler记录所指事务建立时锁定的SAR9或SAR15精度
	input [C_RUN_GENERATION_WIDTH - 1:0]i_scheduler_fault_run_generation, // 本条Scheduler记录所指事务归属的RUN运行代际

	//---------------SSW故障记录接口---------------//
	input i_ssw_fault_valid,                       // SSW一侧的阻断故障在本拍生成一条新的注册记录
	input i_ssw_fault_active,                      // SSW一侧阻断故障只要仍未解决就持续保持这一电平为高
	input [C_FAULT_CAUSE_WIDTH - 1:0]i_ssw_fault_cause, // 指出SSW这条记录属于哪一类故障来源
	input i_ssw_fault_identity_valid,              // 说明SSW这条记录携带的事务身份是否可以采信
	input [C_FRAME_ID_WIDTH - 1:0]i_ssw_fault_frame_id, // 给出SSW这条记录关联事务的真实物理帧编号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_ssw_fault_sample_index, // 给出SSW这条记录关联事务的全局顺序编号
	input i_ssw_fault_color_ir,                    // 给出SSW这条记录关联事务采集的颜色通道
	input [1:0]i_ssw_fault_frame_type,             // 给出SSW这条记录关联事务所属的AMB/DCS/NORMAL类型
	input i_ssw_fault_precision,                   // 给出SSW这条记录关联事务建立时的精度身份
	input [C_RUN_GENERATION_WIDTH - 1:0]i_ssw_fault_run_generation, // 给出SSW这条记录关联事务所属的RUN代际编号

	//---------------生命周期与看门狗接口---------------//
	input i_stop_episode_active,                        // manager经ACTIVE wrapper与Top转发的接受STOP/系统STOP/abort排空episode电平
	input i_adc_physical_idle,                          // Top同步转发的物理ADC空闲事实，不是完成或数字排空
	input i_diag_clear_event,                           // Top唯一注册式系统诊断清除事件
	input i_measurement_result_discard_event,           // AMI正式结果生命周期丢弃单周期观测，唯一驱动结果丢弃历史的输入

	//---------------阻断与生命周期输出---------------//
	output o_system_fault_blocking,                   // 注册式阻断状态，经Top->ACTIVE wrapper->manager阻止新START
	output o_system_abort_event,                      // 每个故障episode恰好一次的注册式abort事件，仅扇给事务owner
	output o_system_stop_request_event,               // 每个故障episode恰好一次的注册式STOP请求事件
	output o_system_fault_discard_event,              // 每个阻断故障episode恰好一次的注册式丢弃选择事件，仅AMI消费

	//---------------首故障快照观测输出---------------//
	output o_system_fault_cause_valid,                // 首个阻断故障原子快照是否已锁存
	output [C_FAULT_CAUSE_WIDTH - 1:0]o_system_fault_cause, // 首故障cause编码快照
	output [C_FAULT_SOURCE_WIDTH - 1:0]o_system_fault_source, // 首故障来源编码快照
	output o_system_fault_identity_valid,             // 首故障绑定身份是否可信快照
	output [C_FRAME_ID_WIDTH - 1:0]o_system_fault_frame_id, // 首故障绑定事务的真实物理帧号快照
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_system_fault_sample_index, // 首故障绑定事务的全局顺序编号快照
	output o_system_fault_color_ir,                   // 首故障绑定事务的颜色身份快照
	output [1:0]o_system_fault_frame_type,            // 首故障绑定事务的帧类型编码快照
	output o_system_fault_precision,                  // 首故障绑定事务建立时所属的精度模式快照
	output [C_RUN_GENERATION_WIDTH - 1:0]o_system_fault_run_generation, // 首故障绑定事务所属的RUN代际快照

	//---------------历史观测输出---------------//
	output [C_FAULT_SUMMARY_WIDTH - 1:0]o_system_fault_summary, // 按位记录的历史阻断故障来源汇总
	output o_result_discard_summary_sticky      // 正式结果生命周期丢弃历史sticky，非阻断
);

	//---------------配置参数区域---------------//
	//===================<参数定义>===================//
	localparam [3:0]SOURCE_AMI = 4'h1;          // 故障来源编码，标记首故障快照来自AMI
	localparam [3:0]SOURCE_SCHEDULER = 4'h2;    // 故障来源编码，仅在Scheduler占用捕获仲裁时写入快照
	localparam [3:0]SOURCE_SSW = 4'h3;          // 故障来源编码，四路里优先级最低，前三路都未命中才会用到它
	localparam [3:0]SOURCE_SUPERVISOR = 4'h4;   // 故障来源编码，标记首故障快照来自本模块看门狗
	localparam [7:0]CAUSE_WATCHDOG_TIMEOUT = 8'h31; // ADC物理排空看门狗超时的固定cause编码

	//----------------计数信号----------------//
	reg [C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH - 1:0]cnt_adc_drain_watchdog = {C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH{1'b0}}; // 看门狗连续非idle采样计数器

	//-----------------标志信号-----------------//
	reg flag_watchdog_timeout_latch = 1'b0;     // 阻止同一drain episode内重复触发看门狗事件的锁存
	reg flag_watchdog_recovery_pending = 1'b0;  // 看门狗轻量恢复判据，等待首次采样到真实idle才清除
	wire flag_watchdog_recovered;               // 看门狗轻量恢复资格，供episode关闭判据使用
	wire flag_watchdog_window_active;           // 本拍是否处于允许看门狗计数递增的窗口内
	wire flag_watchdog_timeout_fire;            // 本拍看门狗计数到达阈值，产生一次超时事件
	wire flag_local_actives_low;                // AMI、Scheduler、SSW三路active本拍均为低
	wire flag_episode_close_condition;          // 三路active均低且看门狗已恢复，满足episode关闭判据
	wire flag_new_any;                          // AMI、Scheduler、SSW或看门狗任一本拍产生新记录
	wire flag_episode_open_edge;                // episode由关闭转为开启的唯一判定沿
	wire flag_diag_clear_legal;                 // 本拍诊断清除是否合法生效
	wire flag_capture_watchdog;                 // 首故障快照本拍由看门狗超时占用
	wire flag_capture_ami;                      // 首故障快照本拍由AMI记录占用
	wire flag_capture_scheduler;                // 看门狗和AMI均未占用捕获仲裁时改由Scheduler记录占用
	wire flag_capture_ssw;                      // 前三路都未占用捕获仲裁时最后轮到SSW记录占用
	wire [C_FAULT_SUMMARY_WIDTH - 1:0]flag_new_summary_bits; // 本拍新命中的历史汇总位掩码
	wire flag_selected_identity_valid;          // 本拍捕获仲裁选中来源的身份可信位，看门狗分支天然为0
	wire flag_selected_color_ir;                // 本拍捕获仲裁选中来源的颜色身份，身份不可信或看门狗分支强制为0
	wire flag_selected_precision;               // 本拍捕获仲裁选中来源的精度模式，身份不可信或看门狗分支强制为0

	//-----------------译码信号-----------------//
	wire [C_FAULT_CAUSE_WIDTH - 1:0]dec_selected_cause; // 本拍捕获仲裁选中来源的cause，看门狗分支固定映射8'h31
	wire [C_FAULT_SOURCE_WIDTH - 1:0]dec_selected_source; // 本拍捕获仲裁选中来源对应的固定来源常量
	wire [C_FRAME_ID_WIDTH - 1:0]dec_selected_frame_id; // 本拍捕获仲裁选中来源的物理帧号，身份不可信或看门狗分支强制为0
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_selected_sample_index; // 本拍捕获仲裁选中来源的全局序号，身份不可信或看门狗分支强制为0
	wire [1:0]dec_selected_frame_type;          // 本拍捕获仲裁选中来源的帧类型编码，身份不可信或看门狗分支强制为0
	wire [C_RUN_GENERATION_WIDTH - 1:0]dec_selected_run_generation; // 本拍捕获仲裁选中来源的RUN代际，身份不可信或看门狗分支强制为0

	//-----------------其他信号-----------------//

	//-----------------输出信号-----------------//
	//阻断、episode事件与首故障快照
	reg system_fault_blocking_o = 1'b0;         // episode开合状态寄存，直接充当阻断输出
	reg system_abort_event_o = 1'b0;            // episode开启沿注册式abort脉冲
	reg system_stop_request_event_o = 1'b0;     // episode开启沿注册式STOP请求脉冲
	reg system_fault_discard_event_o = 1'b0;    // episode开启沿注册式丢弃选择脉冲
	reg system_fault_cause_valid_o = 1'b0;      // 首故障快照是否已锁存
	reg [C_FAULT_CAUSE_WIDTH - 1:0]system_fault_cause_o = {C_FAULT_CAUSE_WIDTH{1'b0}}; // 首故障cause快照寄存
	reg [C_FAULT_SOURCE_WIDTH - 1:0]system_fault_source_o = {C_FAULT_SOURCE_WIDTH{1'b0}}; // 首故障来源快照寄存
	reg system_fault_identity_valid_o = 1'b0;   // 首故障身份可信位快照寄存
	reg [C_FRAME_ID_WIDTH - 1:0]system_fault_frame_id_o = {C_FRAME_ID_WIDTH{1'b0}}; // 首故障帧号快照寄存
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]system_fault_sample_index_o = {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 首故障序号快照寄存
	reg system_fault_color_ir_o = 1'b0;         // 首故障颜色快照寄存
	reg [1:0]system_fault_frame_type_o = 2'b00; // 首故障类型快照寄存
	reg system_fault_precision_o = 1'b0;        // 首故障精度快照寄存
	reg [C_RUN_GENERATION_WIDTH - 1:0]system_fault_run_generation_o = {C_RUN_GENERATION_WIDTH{1'b0}}; // 首故障代际快照寄存
	reg [C_FAULT_SUMMARY_WIDTH - 1:0]system_fault_summary_o = {C_FAULT_SUMMARY_WIDTH{1'b0}}; // 历史汇总位图寄存
	reg result_discard_summary_sticky_o = 1'b0; // 结果丢弃历史sticky寄存

	//---------------其他信号连线---------------//
	// 轻量恢复判据只需要首次采样到真实idle，比看门狗自身锁存的清除条件更宽松。
	assign flag_watchdog_recovered = !flag_watchdog_recovery_pending; // 无未决恢复标记时即视为已恢复
	// 计数窗口严格限定在接受的drain episode内，真实idle或episode结束都立即停止递增。
	assign flag_watchdog_window_active = i_stop_episode_active && !i_adc_physical_idle && !flag_watchdog_timeout_latch; // 非idle且未被超时锁存阻止时才允许计数
	assign flag_watchdog_timeout_fire = flag_watchdog_window_active && (cnt_adc_drain_watchdog == (C_ADC_DRAIN_WATCHDOG_CYCLES - 1)); // 第C_ADC_DRAIN_WATCHDOG_CYCLES个连续非idle采样触发一次；SUP06A/B/C+SUP09A实测确认边界与恢复 @satisfies: P05, N06
	// episode关闭需要三路子模块active全部撤销，且看门狗轻量恢复判据同时成立。
	assign flag_local_actives_low = !i_ami_fault_active && !i_scheduler_fault_active && !i_ssw_fault_active; // 三路子模块自身状态均已清空
	assign flag_episode_close_condition = flag_local_actives_low && flag_watchdog_recovered; // 与看门狗轻量恢复判据合并
	// 新记录判定覆盖四路来源，用于episode开合优先级判断与首故障捕获仲裁。
	assign flag_new_any = i_ami_fault_valid || i_scheduler_fault_valid || i_ssw_fault_valid || flag_watchdog_timeout_fire; // 任一来源本拍产生新记录
	assign flag_episode_open_edge = flag_new_any && !system_fault_blocking_o; // 仅在episode由关闭转为开启的那一拍成立；open/close/rearm独立于首故障快照历史 @satisfies: K02
	// 诊断清除必须等待episode真正关闭，且不得被同拍到达的新故障抢先覆盖。
	assign flag_diag_clear_legal = i_diag_clear_event && !system_fault_blocking_o && !flag_new_any; // 新故障优先于同拍诊断清除；LFA-11诊断清除只在system_fault_blocking_o已经真实关闭后才合法，只能清历史sticky，不能替代195行flag_episode_close_condition的真实恢复判据 @satisfies: LFA-11
	// 首故障捕获仲裁固定顺序：看门狗、AMI、Scheduler、SSW，且只在快照尚未锁存时生效。
	assign flag_capture_watchdog = flag_watchdog_timeout_fire && !system_fault_cause_valid_o; // 看门狗优先级最高
	assign flag_capture_ami = !flag_capture_watchdog && i_ami_fault_valid && !system_fault_cause_valid_o; // 看门狗未占用时轮到AMI
	assign flag_capture_scheduler = !flag_capture_watchdog && !flag_capture_ami && i_scheduler_fault_valid && !system_fault_cause_valid_o; // 看门狗和AMI均未占用时轮到Scheduler
	assign flag_capture_ssw = !flag_capture_watchdog && !flag_capture_ami && !flag_capture_scheduler && i_ssw_fault_valid && !system_fault_cause_valid_o; // 前三路均未占用时轮到SSW
	// 捕获仲裁四路互斥，下面每个select直接按四路占用结果选取对应来源的字段，看门狗分支没有对应输入组，固定给出常量或全零。
	assign dec_selected_cause = flag_capture_watchdog ? CAUSE_WATCHDOG_TIMEOUT : (flag_capture_ami ? i_ami_fault_cause : (flag_capture_scheduler ? i_scheduler_fault_cause : (flag_capture_ssw ? i_ssw_fault_cause : {C_FAULT_CAUSE_WIDTH{1'b0}}))); // 四路占用互斥，直接选出对应cause；固定优先级watchdog>AMI>Scheduler>SSW,SUP02B实测同拍三路到达确认 @satisfies: N03, P10
	assign dec_selected_source = flag_capture_watchdog ? SOURCE_SUPERVISOR : (flag_capture_ami ? SOURCE_AMI : (flag_capture_scheduler ? SOURCE_SCHEDULER : (flag_capture_ssw ? SOURCE_SSW : {C_FAULT_SOURCE_WIDTH{1'b0}}))); // 四路占用互斥，直接选出对应来源常量
	assign flag_selected_identity_valid = flag_capture_ami ? i_ami_fault_identity_valid : (flag_capture_scheduler ? i_scheduler_fault_identity_valid : (flag_capture_ssw ? i_ssw_fault_identity_valid : 1'b0)); // 看门狗没有对应输入组，隐含按0处理
	assign dec_selected_frame_id = flag_selected_identity_valid ? (flag_capture_ami ? i_ami_fault_frame_id : (flag_capture_scheduler ? i_scheduler_fault_frame_id : i_ssw_fault_frame_id)) : {C_FRAME_ID_WIDTH{1'b0}}; // 身份不可信或看门狗分支一律清零
	assign dec_selected_sample_index = flag_selected_identity_valid ? (flag_capture_ami ? i_ami_fault_sample_index : (flag_capture_scheduler ? i_scheduler_fault_sample_index : i_ssw_fault_sample_index)) : {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 序号跟随身份可信位，不可信时不采纳任何来源的数值
	assign flag_selected_color_ir = flag_selected_identity_valid && (flag_capture_ami ? i_ami_fault_color_ir : (flag_capture_scheduler ? i_scheduler_fault_color_ir : i_ssw_fault_color_ir)); // 与身份可信位共享同一AND门
	assign dec_selected_frame_type = flag_selected_identity_valid ? (flag_capture_ami ? i_ami_fault_frame_type : (flag_capture_scheduler ? i_scheduler_fault_frame_type : i_ssw_fault_frame_type)) : 2'b00; // 类型跟随身份可信位，不可信时不采纳任何来源的编码
	assign flag_selected_precision = flag_selected_identity_valid && (flag_capture_ami ? i_ami_fault_precision : (flag_capture_scheduler ? i_scheduler_fault_precision : i_ssw_fault_precision)); // 精度身份同样借用身份可信位这一AND门
	assign dec_selected_run_generation = flag_selected_identity_valid ? (flag_capture_ami ? i_ami_fault_run_generation : (flag_capture_scheduler ? i_scheduler_fault_run_generation : i_ssw_fault_run_generation)) : {C_RUN_GENERATION_WIDTH{1'b0}}; // 代次跟随身份可信位，不可信时不采纳任何来源的数值
	// 历史汇总位图与首故障快照相互独立：每路来源命中都会置位自己的汇总位，不受快照是否已锁存影响。
	assign flag_new_summary_bits =
		(i_ami_fault_valid ? (
			(i_ami_fault_cause == 8'h01) ? (16'h0001) :
			(i_ami_fault_cause == 8'h02) ? (16'h0002) :
			(i_ami_fault_cause == 8'h03) ? (16'h0004) :
			(i_ami_fault_cause == 8'h04) ? (16'h0080) :
			(i_ami_fault_cause == 8'h05) ? (16'h0100) :
			(i_ami_fault_cause == 8'h06) ? (16'h0200) :
			(i_ami_fault_cause == 8'h07) ? (16'h0400) : (16'h0000)
		) : (16'h0000)) |
		((i_scheduler_fault_valid && (i_scheduler_fault_cause == 8'h11)) ? (16'h0008) : (16'h0000)) |
		(i_ssw_fault_valid ? (
			(i_ssw_fault_cause == 8'h21) ? (16'h0010) :
			(i_ssw_fault_cause == 8'h22) ? (16'h0020) : (16'h0000)
		) : (16'h0000)) |
		(flag_watchdog_timeout_fire ? (16'h0040) : (16'h0000)); // 按合同3节固定cause到汇总位映射表逐路展开；AMI连续完成丢失8'h06占bit 9、ADC长期忙8'h07占bit 10

	//---------------输出信号连线---------------//
	assign o_system_fault_blocking = system_fault_blocking_o; // 导出 o_system_fault_blocking
	assign o_system_abort_event = system_abort_event_o; // 导出 o_system_abort_event
	assign o_system_stop_request_event = system_stop_request_event_o; // 导出 o_system_stop_request_event
	assign o_system_fault_discard_event = system_fault_discard_event_o; // 导出 o_system_fault_discard_event
	assign o_system_fault_cause_valid = system_fault_cause_valid_o; // 导出 o_system_fault_cause_valid
	assign o_system_fault_cause = system_fault_cause_o; // 导出 o_system_fault_cause
	assign o_system_fault_source = system_fault_source_o; // 导出 o_system_fault_source
	assign o_system_fault_identity_valid = system_fault_identity_valid_o; // 导出 o_system_fault_identity_valid
	assign o_system_fault_frame_id = system_fault_frame_id_o; // 导出 o_system_fault_frame_id
	assign o_system_fault_sample_index = system_fault_sample_index_o; // 导出 o_system_fault_sample_index
	assign o_system_fault_color_ir = system_fault_color_ir_o; // 导出 o_system_fault_color_ir
	assign o_system_fault_frame_type = system_fault_frame_type_o; // 导出 o_system_fault_frame_type
	assign o_system_fault_precision = system_fault_precision_o; // 导出 o_system_fault_precision
	assign o_system_fault_run_generation = system_fault_run_generation_o; // 导出 o_system_fault_run_generation
	assign o_system_fault_summary = system_fault_summary_o; // 导出 o_system_fault_summary
	assign o_result_discard_summary_sticky = result_discard_summary_sticky_o; // 导出 o_result_discard_summary_sticky

	//-------------输出信号处理区域-------------//
	//生命周期与episode开合
	// episode开合状态：新记录到达立即开启并优先于同拍关闭判据，三路active与看门狗均恢复后才关闭。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_blocking_o <= 1'b0;    // 复位解除阻断状态
		end else if(flag_new_any == 1'b1)begin
			system_fault_blocking_o <= 1'b1;    // 新记录到达立即开启或维持episode
		end else if(flag_episode_close_condition == 1'b1)begin
			system_fault_blocking_o <= 1'b0;    // 全部本地条件恢复后关闭episode
		end
	end

	// episode开启沿产生的注册式abort事件，同一episode内只产生一次，只扇给事务owner。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_abort_event_o <= 1'b0;       // 复位不产生伪造abort事件
		end else if(flag_episode_open_edge == 1'b1)begin
			system_abort_event_o <= 1'b1;       // episode由关闭转为开启的那一拍产生一次abort
		end else begin
			system_abort_event_o <= 1'b0;       // 脉冲以外的周期明确报告无abort事件
		end
	end

	// episode开启沿产生的注册式STOP请求事件，同一episode内只产生一次，交由Top合并进manager STOP输入。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_stop_request_event_o <= 1'b0; // 复位不产生伪造STOP请求事件
		end else if(flag_episode_open_edge == 1'b1)begin
			system_stop_request_event_o <= 1'b1; // episode由关闭转为开启的那一拍产生一次STOP请求；SUP01A/SUP06B实测确认,与Top侧abort合并成独立STOP合并路径 @satisfies: P03
		end else begin
			system_stop_request_event_o <= 1'b0; // 脉冲以外的周期明确报告无STOP请求事件
		end
	end

	// episode开启沿产生的注册式丢弃选择事件，同一episode内只产生一次，仅AMI消费。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_discard_event_o <= 1'b0; // 复位不产生伪造丢弃选择事件
		end else if(flag_episode_open_edge == 1'b1)begin
			system_fault_discard_event_o <= 1'b1; // episode由关闭转为开启的那一拍产生一次丢弃选择
		end else begin
			system_fault_discard_event_o <= 1'b0; // 脉冲以外的周期明确报告无丢弃选择事件
		end
	end

	//首故障原子快照
	// 首故障快照是否已锁存，只由合法诊断清除释放，新episode不会重复占用已锁存的快照。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_cause_valid_o <= 1'b0; // 复位清除快照锁存状态
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_cause_valid_o <= 1'b1; // 四路里恰好一路占用本拍捕获仲裁即锁存快照；首故障原子快照,SUP01A/SUP01B实测确认 @satisfies: P04
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_cause_valid_o <= 1'b0; // 全部恢复后的合法诊断清除释放快照
		end
	end

	// 首故障cause编码快照，捕获仲裁命中任一来源时整体接入已经选好的cause。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_cause_o <= {C_FAULT_CAUSE_WIDTH{1'b0}}; // 复位不保留任何历史cause
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_cause_o <= dec_selected_cause; // 锁存捕获仲裁选中来源的cause
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_cause_o <= {C_FAULT_CAUSE_WIDTH{1'b0}}; // 诊断清除后不再保留旧cause
		end
	end

	// 首故障来源编码快照，捕获仲裁命中任一来源时写入对应的固定来源常量。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_source_o <= {C_FAULT_SOURCE_WIDTH{1'b0}}; // 复位不保留任何历史来源
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_source_o <= dec_selected_source; // 锁存捕获仲裁选中来源对应的常量编码
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_source_o <= {C_FAULT_SOURCE_WIDTH{1'b0}}; // 诊断清除后不再保留旧来源
		end
	end

	// 首故障身份可信位快照：看门狗分支天然给出0，其余三路已经在select阶段照抄各自的identity_valid。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_identity_valid_o <= 1'b0; // 复位默认不存在可信身份
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_identity_valid_o <= flag_selected_identity_valid; // 锁存捕获仲裁选中来源的身份可信位
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_identity_valid_o <= 1'b0; // 诊断清除后不再保留旧身份可信位
		end
	end

	// 首故障绑定事务在400 Hz物理帧序列中的编号，取自捕获阶段已经按身份可信位筛选过的select。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位不保留任何历史帧号
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_frame_id_o <= dec_selected_frame_id; // 锁存捕获仲裁选中来源的物理帧号
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 诊断清除后不再保留旧帧号
		end
	end

	// 首故障绑定事务在全局事务流中的顺序位置，取自捕获阶段已经按身份可信位筛选过的select。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 复位不保留任何历史序号
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_sample_index_o <= dec_selected_sample_index; // 锁存捕获仲裁选中来源的全局序号
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}}; // 诊断清除后不再保留旧序号
		end
	end

	// 首故障绑定事务采集的红光或红外颜色通道，取自捕获阶段已经按身份可信位筛选过的select。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_color_ir_o <= 1'b0;    // 复位不保留任何历史颜色
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_color_ir_o <= flag_selected_color_ir; // 锁存捕获仲裁选中来源的颜色通道
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_color_ir_o <= 1'b0;    // 诊断清除后不再保留旧颜色
		end
	end

	// 首故障绑定事务的AMB/DCS/NORMAL类型归类，取自捕获阶段已经按身份可信位筛选过的select。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_frame_type_o <= 2'b00; // 复位不保留任何历史类型
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_frame_type_o <= dec_selected_frame_type; // 锁存捕获仲裁选中来源的事务类型
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_frame_type_o <= 2'b00; // 诊断清除后不再保留旧类型
		end
	end

	// 首故障绑定事务建立时的SAR9或SAR15精度身份，取自捕获阶段已经按身份可信位筛选过的select。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_precision_o <= 1'b0;   // 复位不保留任何历史精度
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_precision_o <= flag_selected_precision; // 锁存捕获仲裁选中来源的精度身份
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_precision_o <= 1'b0;   // 诊断清除后不再保留旧精度
		end
	end

	// 首故障绑定事务所属的RUN运行代次，取自捕获阶段已经按身份可信位筛选过的select。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 复位不保留任何历史代次
		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
			system_fault_run_generation_o <= dec_selected_run_generation; // 锁存捕获仲裁选中来源的RUN代次
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 诊断清除后不再保留旧代次
		end
	end

	//历史与sticky观测
	// 历史汇总位图，按位sticky OR，只由合法诊断清除整体归零。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			system_fault_summary_o <= {C_FAULT_SUMMARY_WIDTH{1'b0}}; // 复位清除历史汇总
		end else if(flag_new_summary_bits != {C_FAULT_SUMMARY_WIDTH{1'b0}})begin
			system_fault_summary_o <= system_fault_summary_o | flag_new_summary_bits; // 按位并入本拍新命中的汇总位；历史汇总独立于活动/首故障诊断,SUP02A/SUP03A实测确认 @satisfies: P09
		end else if(flag_diag_clear_legal == 1'b1)begin
			system_fault_summary_o <= {C_FAULT_SUMMARY_WIDTH{1'b0}}; // 合法诊断清除整体归零历史汇总
		end
	end

	// 结果丢弃历史sticky，只由AMI正式结果丢弃事件置位，只由合法诊断清除归零，从不claim阻断故障。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			result_discard_summary_sticky_o <= 1'b0; // 复位清除丢弃历史sticky
		end else if(i_measurement_result_discard_event == 1'b1)begin
			result_discard_summary_sticky_o <= 1'b1; // 唯一置位来源是AMI正式结果丢弃事件
		end else if(flag_diag_clear_legal == 1'b1)begin
			result_discard_summary_sticky_o <= 1'b0; // 合法诊断清除归零丢弃历史sticky
		end
	end

	//-------------主要任务处理区域-------------//
	//===================<主要任务处理区域>===================//
	// 看门狗计数器仅在接受的drain episode内、真实非idle时递增；真实idle或episode结束在每一拍都优先清零。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_adc_drain_watchdog <= {C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH{1'b0}}; // 复位清零计数
		end else if(i_adc_physical_idle == 1'b1 || i_stop_episode_active == 1'b0)begin
			cnt_adc_drain_watchdog <= {C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH{1'b0}}; // 真实idle或未接受drain时保持归零
		end else if(flag_watchdog_window_active == 1'b1)begin
			cnt_adc_drain_watchdog <= cnt_adc_drain_watchdog + 1'b1; // 每个非idle采样周期递增一次
		end
	end

	// 超时锁存只为阻止同一episode内重复产生看门狗事件，真实idle且episode结束后才允许下一次计数。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_watchdog_timeout_latch <= 1'b0; // 复位解除超时锁存
		end else if(i_adc_physical_idle == 1'b1 && i_stop_episode_active == 1'b0)begin
			flag_watchdog_timeout_latch <= 1'b0; // 真实idle且drain episode已结束才允许下一次重新计数
		end else if(flag_watchdog_timeout_fire == 1'b1)begin
			flag_watchdog_timeout_latch <= 1'b1; // 本拍超时立即锁存，阻止同一episode内重复触发
		end
	end

	// 轻量恢复标记只需要首次采样到真实idle即可清除，供episode关闭判据单独使用。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_watchdog_recovery_pending <= 1'b0; // 复位解除轻量恢复未决状态
		end else if(i_adc_physical_idle == 1'b1)begin
			flag_watchdog_recovery_pending <= 1'b0; // 首次采样到真实idle即视为轻量恢复
		end else if(flag_watchdog_timeout_fire == 1'b1)begin
			flag_watchdog_recovery_pending <= 1'b1; // 本拍超时进入轻量恢复未决状态
		end
	end

endmodule
