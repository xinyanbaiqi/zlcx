`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/08/06
// Design Name:     PPG System Configuration and Lifecycle Manager
// Module Name:     ppg_system_config_manager
// Description:     Description/ppg_system_config_manager_Design.pdf
// Simulations:     tb_ppg_system_config_manager.v
//
// Referrences:     ../ppg_system_integration/PPG_SYSTEM_CONFIG_LIFECYCLE_CONTRACT_DRAFT.md
//
// Dependencies:    None
//
// Version:         V4.9
// Revision Date:   2026/08/23
// History:
//     Time          Version     Revised by     Contents
// 2026/08/06        V1.0        Erie          Create file.
// 2026/08/06        V1.0        Erie          Freeze the reviewed V1 control contract.
// 2026/08/06        V1.0        Erie          Preserve the V1 FSM encoding through synthesis.
// 2026/08/07        V2.0        Erie          Upgrade ACTIVE storage and checks to 640-bit V4.
// 2026/08/13        V2.1        Erie          Reject NORMAL configurations that request initial SAR15.
// 2026/08/23        V4.9        Erie          Bring RTL up to the current ppg_system_config_manager_semantic_contract.md V4.9: widen ACTIVE to the 1024-bit joint V4+V5 payload, add the 20-field V5 detection-config validation and its reset/default profile, add STATIC_BIAS/EXTERNAL_TEST_CURRENT/reserved-IDAC combination checks and error codes 0x11-0x18, add o_run_generation (sole generation producer, increments once per accepted START) and o_stop_episode_active (asserted by accepted STOP, idempotent in STOPPING), and add the i_system_fault_blocking START gate and i_static_characterization_enable STATIC_BIAS qualification input. Existing V4-only validation, FSM and epoch logic is retained unchanged.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年08月06日
// 设计名称:        PPG系统配置与生命周期管理器
// 模块名称:        ppg_system_config_manager
// 模块说明:        在2 MHz系统域原子验证1024-bit V4+V5联合配置快照并管理CONFIG至STOPPING生命周期，唯一生产run_generation和stop_episode_active
// 仿真工程:        tb_ppg_system_config_manager.v
//
// 参考资料:        ../ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md
//
// 依赖文件:        无
//
// 当前版本:        V4.9
// 修订日期:        2026年08月23日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年08月06日   V1.0        Erie          创建文件
// 2026年08月06日   V1.0        Erie          冻结审查后的V1控制合同
// 2026年08月06日   V1.0        Erie          保持综合后的V1状态编码与安全恢复路径
// 2026年08月07日   V2.0        Erie          升级为640-bit ACTIVE V4原子配置合同
// 2026年08月13日   V2.1        Erie          拒绝请求SAR15初始精度的NORMAL配置
// 2026年08月23日   V4.9        Erie          按当前ppg_system_config_manager_semantic_contract.md V4.9补齐：ACTIVE扩展为1024-bit V4+V5联合载荷，新增V5共20个检测配置字段的校验与复位默认档案，新增STATIC_BIAS/EXTERNAL_TEST_CURRENT/保留IDAC编码组合校验及错误码0x11~0x18，新增o_run_generation（唯一代际生产者，每次合法START递增一次）和o_stop_episode_active（合法STOP置位，STOPPING期间幂等），新增i_system_fault_blocking的START阻断门和i_static_characterization_enable的STATIC_BIAS资格输入。既有V4校验、状态机和epoch逻辑保持不变

// 在2 MHz系统域原子验证1024-bit V4+V5联合配置快照并管理CONFIG至STOPPING生命周期
module ppg_system_config_manager
#(
	//---------------参数定义---------------//
	parameter integer C_CONFIG_WIDTH = 1024, // V4[639:0]+V5[1023:640]联合配置总位宽，必须与ACTIVE wrapper、解包器和CDC桥elaboration时一致
	parameter integer C_RUN_GENERATION_WIDTH = 8 // run_generation字段位宽，必须与Top、Scheduler、AMI、SSW一致
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz系统控制时钟
	input i_rstn,                           // 低有效异步复位，释放由上层同步

	//-------------目标域命令事件-------------//
	input [C_CONFIG_WIDTH - 1:0]i_config_snapshot, // CDC桥已经稳定传入的V4+V5联合完整配置快照
	input i_config_update_event,              // 完整配置到达2 MHz域的单周期事件
	input i_start_event,                      // 经过事件CDC重建的START单周期命令
	input i_stop_event,                       // 请求RUN链停止接纳新事务并进入排空阶段
	input i_status_clear_event,               // 经过事件CDC重建的sticky状态清除命令

	//-------------系统资格与排空-------------//
	input i_analog_ready,                     // 偏置、参考和模拟开关已经具备启动资格
	input i_adc_idle,                         // 当前无ADC转换且两个DONE均已回低
	input i_datapath_empty,                   // 捕获至最终输出的保持型事务流水已经排空
	input i_idac_idle,                        // IDAC比较、候选码和安全提交均无在途动作
	input i_analog_safe,                      // 停止后模拟控制已经回到安全保持状态
	input i_system_fault_blocking,            // supervisor经Top与wrapper送达的注册系统阻断故障电平，拒绝START且不能被本地清除
	input i_static_characterization_enable,   // 表征控制CDC在2 MHz域已提交的STATIC_BIAS资格电平，仅COMMIT/START组合校验使用

	//-------------ACTIVE配置输出------------//
	output [C_CONFIG_WIDTH - 1:0]o_active_config, // 最近一次合法COMMIT原子生效的完整V4+V5联合配置
	output o_active_valid,                   // ACTIVE配置具备本轮启动资格
	output [7:0]o_config_epoch,              // 每次合法完整COMMIT递增的配置版本
	output [7:0]o_coef_epoch,                // 合法校准系数提交时递增的Stage1版本
	output [7:0]o_stage2_coef_epoch,         // 合法Stage2校准系数提交对应的独立版本
	output [7:0]o_dc_recovery_coef_epoch,    // 每次合法DC恢复字段组提交对应的版本

	//-------------生命周期状态输出------------//
	output [1:0]o_lifecycle_state,             // 输出CONFIG、READY、RUN或STOPPING生命周期编码
	output o_start_ready,                      // READY且全部系统启动资格同时满足
	output o_run_enable,                       // 仅在RUN状态允许功能链工作
	output o_allow_new_transaction,            // 仅在RUN状态允许发起新ADC事务
	output [C_RUN_GENERATION_WIDTH - 1:0]o_run_generation, // 唯一代际生产者，合法START原子递增一次，RUN/STOPPING期间保持
	output o_stop_episode_active,              // 合法STOP置位、STOPPING期间幂等的排空episode电平，供supervisor watchdog仲裁

	//-------------响应与错误状态-------------//
	output o_commit_ack_event,                // 合法配置已经成为ACTIVE的单周期应答
	output o_start_ack_event,                 // START被合法接受的单周期应答
	output o_stop_ack_event,                  // STOP被接受或幂等处理的单周期应答
	output o_error_event,                     // 当前拍命令或快照被拒绝的单周期事件
	output o_commit_ack_sticky,               // 至显式清除前保持的配置成功状态
	output o_error_sticky,                    // 至显式清除前保持的错误汇总状态
	output [7:0]o_last_error_code             // 最近一次错误的稳定8-bit分类码
);

	//-------------配置参数区域-------------//
	// V4错误码定义
	localparam [7:0] ERROR_NONE = 8'h00;    // 当前没有记录错误
	localparam [7:0] ERROR_COMMAND_CONFLICT = 8'h01; // 同一系统拍出现多个互斥命令事件
	localparam [7:0] ERROR_COMMIT_STATE = 8'h02; // 非CONFIG状态收到配置更新事件
	localparam [7:0] ERROR_SCHEMA_VERSION = 8'h03; // 快照schema不是冻结的V4编码
	localparam [7:0] ERROR_RESERVED_BITS = 8'h04; // 快照保留位包含非零值
	localparam [7:0] ERROR_ENUM_ENCODING = 8'h05; // IDAC模式等枚举字段使用保留编码
	localparam [7:0] ERROR_IDAC_RANGE = 8'h06; // 手动码没有落在对应最小最大范围内
	localparam [7:0] ERROR_THRESHOLD_RANGE = 8'h07; // AMB或DCS低阈值不小于高阈值
	localparam [7:0] ERROR_CONFIRM_COUNT = 8'h08; // 至少一组连续确认次数被配置为零
	localparam [7:0] ERROR_STAGE1_COEFFICIENT = 8'h09; // 运行资格或标称Stage1系数不符合合同
	localparam [7:0] ERROR_START_STATE = 8'h0a; // 非READY状态收到START事件
	localparam [7:0] ERROR_START_QUALIFICATION = 8'h0b; // READY状态的系统启动资格仍不完整
	localparam [7:0] ERROR_STOP_STATE = 8'h0c; // CONFIG或READY状态收到STOP事件
	localparam [7:0] ERROR_FSM_STATE = 8'h0d; // 非法内部状态触发安全恢复
	localparam [7:0] ERROR_STAGE2_COEFFICIENT = 8'h0e; // Stage2资格或增益极性不符合合同
	localparam [7:0] ERROR_DC_RECOVERY_COEFFICIENT = 8'h0f; // DC恢复资格或增益极性不符合合同
	localparam [7:0] ERROR_NORMAL_INITIAL_PRECISION = 8'h10; // NORMAL配置错误请求SAR15初始精度
	localparam [7:0] ERROR_NORMAL_EXTERNAL_CURRENT = 8'h11; // NORMAL_PPG错误请求外部固定电流输入源
	localparam [7:0] ERROR_CHARACTERIZATION_AUTO_IDAC = 8'h12; // CHARACTERIZATION错误请求自动IDAC模式
	localparam [7:0] ERROR_CHARACTERIZATION_OPTICAL_MODE = 8'h13; // 光电二极管CHARACTERIZATION未使用纯红光模式
	localparam [7:0] ERROR_STATIC_BIAS_INPUT_SOURCE = 8'h14; // 已提交STATIC_BIAS资格但候选或ACTIVE输入源不是外部固定电流
	localparam [7:0] ERROR_RESERVED_IDAC_MODE = 8'h15; // idac_mode使用保留编码2'b11
	localparam [7:0] ERROR_FIXED_CURRENT_OPTICAL_MODE = 8'h16; // 非STATIC_BIAS固定电流表征错误选择安全关闭光学模式
	localparam [7:0] ERROR_V5_SCHEMA_RESERVED = 8'h17; // V5保留位段包含非零值
	localparam [7:0] ERROR_V5_FIELD_RANGE = 8'h18; // V5字段取值范围或跨字段关系不合法

	// V1 Stage1标称Q16系数
	localparam signed [25:0] NOMINAL_WEIGHT_0 = 26'sd65536; // S1_RAW[0]标称权重1.0的Q16编码
	localparam signed [25:0] NOMINAL_WEIGHT_1 = 26'sd131072; // 第二物理判决位贡献二个ADC码单位
	localparam signed [25:0] NOMINAL_WEIGHT_2 = 26'sd262144; // 第三物理判决位贡献四个ADC码单位
	localparam signed [25:0] NOMINAL_WEIGHT_3 = 26'sd524288; // 冗余判决位标称权重8.0的Q16编码
	localparam signed [25:0] NOMINAL_WEIGHT_4 = 26'sd524288; // 主8.0判决支路使用独立Q16黄金系数
	localparam signed [25:0] NOMINAL_WEIGHT_5 = 26'sd1048576; // 16.0判决级的未校准参考贡献
	localparam signed [25:0] NOMINAL_WEIGHT_6 = 26'sd2097152; // 中高32.0物理位的动态范围基准
	localparam signed [25:0] NOMINAL_WEIGHT_7 = 26'sd4194304; // 高64.0物理位的半量程增量基准
	localparam signed [25:0] NOMINAL_WEIGHT_8 = 26'sd8388608; // 次高128.0判决级的Q16黄金值
	localparam signed [25:0] NOMINAL_WEIGHT_9 = 26'sd16777216; // 最高256.0判决级所需的Q16黄金值
	localparam signed [31:0] NOMINAL_OFFSET = -32'sd262144; // 固定冗余公式中-4.0偏置的Q16编码

	//---------V5检测配置复位默认档案区域---------//
	// 合同C04§5.2冻结的V5唯一复位值，不构成第二个ACTIVE producer，peak_valley_config_valid恒为0
	localparam V5_DEFAULT_SLOPE_MODE = 1'b1;      // 默认ADAPTIVE基线斜率模式
	localparam signed [31:0] V5_DEFAULT_FIXED_SLOPE_Q16 = -32'sd65536; // 默认固定斜率-1.0的Q16编码
	localparam [15:0] V5_DEFAULT_ALPHA_Q15 = 16'h199A; // 默认基础斜率幅度比例
	localparam [15:0] V5_DEFAULT_BETA_Q15 = 16'h2000; // 默认活动斜率平滑比例
	localparam [15:0] V5_DEFAULT_TIMING_ADJUST_RATIO_Q15 = 16'h0800; // 默认相交时刻修正比例
	localparam signed [31:0] V5_DEFAULT_SLOPE_MIN_Q16 = -32'sd262144; // 默认最负斜率边界
	localparam signed [31:0] V5_DEFAULT_SLOPE_MAX_Q16 = -32'sd8192; // 默认最接近零斜率边界
	localparam signed [31:0] V5_DEFAULT_BASELINE_DELTA_Q16 = 32'sd0; // 默认波峰锚点基线偏置
	localparam [31:0] V5_DEFAULT_CROSS_HYSTERESIS_Q16 = 32'd131072; // 默认向上相交迟滞量
	localparam [15:0] V5_DEFAULT_LEAD_MIN_FRAMES = 16'd17; // 默认相交提前量合格下界
	localparam [15:0] V5_DEFAULT_LEAD_MAX_FRAMES = 16'd19; // 默认相交提前量合格上界
	localparam [3:0] V5_DEFAULT_CROSS_CONFIRM_COUNT = 4'd3; // 默认相交连续确认点数
	localparam [3:0] V5_DEFAULT_NO_CROSS_LIMIT = 4'd2; // 默认连续无相交重新获取阈值
	localparam [3:0] V5_DEFAULT_PEAK_CONFIRM_COUNT = 4'd3; // 默认波峰连续下降确认点数
	localparam [3:0] V5_DEFAULT_VALLEY_CONFIRM_COUNT = 4'd3; // 默认波谷连续上升确认点数
	localparam [23:0] V5_DEFAULT_DIRECTION_DEADBAND = 24'd2; // 默认相邻FIR方向分类死区
	localparam [23:0] V5_DEFAULT_MIN_PEAK_VALLEY_AMPLITUDE = 24'd20; // 默认合格峰谷最小幅度
	localparam [15:0] V5_DEFAULT_MIN_PEAK_TO_VALLEY_FRAMES = 16'd20; // 默认波峰到波谷最小帧差
	localparam [15:0] V5_DEFAULT_MIN_PEAK_TO_PEAK_FRAMES = 16'd100; // 默认相邻波峰最小帧差
	localparam [15:0] V5_DEFAULT_MAX_FINE_WINDOW_FRAMES = 16'd600; // 默认15-bit窗口最大持续帧数
	localparam [15:0] V5_DEFAULT_MAX_REACQUIRE_FRAMES = 16'd1000; // 默认9-bit重新获取最大帧数
	localparam V5_DEFAULT_PEAK_VALLEY_CONFIG_VALID = 1'b0; // 复位后正式检测资格恒为不可用
	localparam [13:0] V5_DEFAULT_RESERVED = 14'd0; // V5保留位复位归零
	localparam [383:0] V5_RESET_PROFILE = {       // 按C04§5.2位段顺序从高位到低位拼接的唯一V5复位384-bit档案
		V5_DEFAULT_RESERVED,
		V5_DEFAULT_PEAK_VALLEY_CONFIG_VALID,
		V5_DEFAULT_MAX_REACQUIRE_FRAMES,
		V5_DEFAULT_MAX_FINE_WINDOW_FRAMES,
		V5_DEFAULT_MIN_PEAK_TO_PEAK_FRAMES,
		V5_DEFAULT_MIN_PEAK_TO_VALLEY_FRAMES,
		V5_DEFAULT_MIN_PEAK_VALLEY_AMPLITUDE,
		V5_DEFAULT_DIRECTION_DEADBAND,
		V5_DEFAULT_VALLEY_CONFIRM_COUNT,
		V5_DEFAULT_PEAK_CONFIRM_COUNT,
		V5_DEFAULT_NO_CROSS_LIMIT,
		V5_DEFAULT_CROSS_CONFIRM_COUNT,
		V5_DEFAULT_LEAD_MAX_FRAMES,
		V5_DEFAULT_LEAD_MIN_FRAMES,
		V5_DEFAULT_CROSS_HYSTERESIS_Q16,
		V5_DEFAULT_BASELINE_DELTA_Q16,
		V5_DEFAULT_SLOPE_MAX_Q16,
		V5_DEFAULT_SLOPE_MIN_Q16,
		V5_DEFAULT_TIMING_ADJUST_RATIO_Q15,
		V5_DEFAULT_BETA_Q15,
		V5_DEFAULT_ALPHA_Q15,
		V5_DEFAULT_FIXED_SLOPE_Q16,
		V5_DEFAULT_SLOPE_MODE
	};

	//-------------状态参数区域-------------//
	// 内部保留非法编码空间，外部仍输出冻结的2-bit生命周期编码
	localparam [2:0] ST_CONFIG = 3'b000;    // 允许接收完整静态配置的安全停止状态
	localparam [2:0] ST_READY = 3'b001;     // ACTIVE配置有效且等待合法START的状态
	localparam [2:0] ST_RUN = 3'b010;       // 功能链运行并允许发起ADC事务的状态
	localparam [2:0] ST_STOPPING = 3'b011;  // 禁止新事务并等待系统完全排空的状态

	//--------------状态机信号--------------//
	// 生命周期状态寄存器
	(* fsm_encoding = "user_encoding", fsm_safe_state = "default_state" *) // 禁止综合重编码并保留非法状态的default恢复路径
	reg [2:0]state_current;                 // 当前内部生命周期状态
	reg [2:0]state_next;                    // 根据合法事件和排空条件形成的下一状态

	//---------------标志信号---------------//
	// 状态资格、快照校验和命令接收条件
	wire flag_state_invalid;                // 指示内部FSM进入未定义的安全恢复编码
	wire flag_command_conflict;             // 指示同拍存在两个或更多命令事件
	wire flag_snapshot_schema_valid;        // 指示快照采用V4 schema版本
	wire flag_snapshot_reserved_valid;      // 指示全部V4保留位保持为零
	wire flag_snapshot_enum_valid;          // 指示IDAC模式没有使用保留编码
	wire flag_snapshot_profile_precision_valid; // 指示NORMAL固定采用SAR9初始精度
	wire flag_snapshot_idac_range_valid;    // 指示三组手动码均位于各自上下限内
	wire flag_snapshot_threshold_valid;     // 指示AMB和DCS迟滞窗口关系均合法
	wire flag_snapshot_confirm_valid;       // 指示两组连续确认次数均不为零
	wire flag_snapshot_nominal_coef_valid;  // 指示未校准表征使用完整标称Stage1系数
	wire flag_snapshot_coef_qualification_valid; // 指示运行资格与Stage1系数声明一致
	wire flag_snapshot_stage2_value_valid;  // 指示有效Stage2增益保持正系统极性
	wire flag_snapshot_stage2_qualification_valid; // 指示运行类型与Stage2资格声明一致
	wire flag_snapshot_dc_value_valid;      // 指示有效DC恢复增益保持正系统极性
	wire flag_snapshot_dc_qualification_valid; // 指示运行类型与两组DC恢复资格一致
	wire flag_snapshot_v5_reserved_valid;   // 指示V5保留位段全部为零
	wire flag_snapshot_v5_range_valid;      // 指示V5全部字段取值范围与跨字段关系合法
	wire flag_snapshot_normal_current_valid; // 指示NORMAL_PPG没有错误请求外部固定电流输入源
	wire flag_snapshot_char_idac_valid;     // 指示CHARACTERIZATION没有错误请求自动IDAC模式
	wire flag_snapshot_char_photodiode_optical_valid; // 指示光电二极管CHARACTERIZATION使用纯红光光学模式
	wire flag_snapshot_char_current_optical_valid; // 指示非STATIC_BIAS固定电流表征没有选择安全关闭光学模式
	wire flag_snapshot_static_bias_valid;   // 指示已提交STATIC_BIAS资格时候选快照满足CHARACTERIZATION加外部固定电流
	wire flag_start_static_bias_valid;      // 指示START拍已提交STATIC_BIAS资格时ACTIVE满足CHARACTERIZATION加外部固定电流
	wire flag_snapshot_valid;               // 汇总整组配置快照的全部合法性检查
	wire flag_commit_accept;                // CONFIG状态接受一笔合法完整配置
	wire flag_start_accept;                 // READY状态接受一笔资格完整的START
	wire flag_stop_accept;                  // RUN或STOPPING状态接受STOP
	wire flag_stopping_complete;            // 全部数字流水排空且模拟已经安全
	wire flag_start_ready;                  // 汇总READY状态下的全部启动资格

	//---------------译码信号---------------//
	// signed阈值解释和固定优先级错误分类
	wire signed [11:0]dec_amb_threshold_low; // 按二进制补码解释的AMB低阈值
	wire signed [11:0]dec_amb_threshold_high; // 按二进制补码解释的AMB高阈值
	wire signed [11:0]dec_dcs_threshold_low; // 颜色直流残差减码侧的有符号边界
	wire signed [11:0]dec_dcs_threshold_high; // 颜色直流残差加码侧的有符号边界
	wire signed [19:0]dec_stage2_gain_q16;  // 按二进制补码解释Stage2统一Q16增益
	wire signed [31:0]dec_dc9_recovery_gain_q16; // SAR9粗精度DC加回系数的signed译码值
	wire signed [31:0]dec_dc15_recovery_gain_q16; // SAR15精细精度DC加回系数的signed译码值
	wire [1:0]dec_lifecycle_state;          // 把内部状态安全映射为外部2-bit编码
	wire [7:0]dec_error_code;               // 根据固定优先级选择当前拒绝错误码
	wire dec_error_present;                 // 当前拍的固定优先级译码产生拒绝原因

	//-------------V5检测配置译码信号-------------//
	// 按C04§5.2固定位段从联合快照高384-bit解释的V5检测配置字段
	wire dec_v5_slope_mode;                       // 基线斜率固定或自适应模式
	wire signed [31:0]dec_v5_fixed_slope_q16;     // 固定signed Q16负斜率
	wire [15:0]dec_v5_alpha_q15;                  // 基础斜率幅度比例
	wire [15:0]dec_v5_beta_q15;                   // 活动斜率平滑比例
	wire [15:0]dec_v5_timing_adjust_ratio_q15;    // 相交时刻修正比例
	wire signed [31:0]dec_v5_slope_min_q16;       // 最负斜率边界
	wire signed [31:0]dec_v5_slope_max_q16;       // 最接近零斜率边界
	wire signed [31:0]dec_v5_baseline_delta_q16;  // 波峰锚点基线偏置
	wire [31:0]dec_v5_cross_hysteresis_q16;       // 向上相交迟滞量
	wire [15:0]dec_v5_lead_min_frames;            // 相交提前量合格下界
	wire [15:0]dec_v5_lead_max_frames;            // 相交提前量合格上界
	wire [3:0]dec_v5_cross_confirm_pts;           // 相交连续确认点数
	wire [3:0]dec_v5_no_cross_limit;              // 连续无相交重新获取阈值
	wire [3:0]dec_v5_peak_confirm_pts;            // 波峰连续下降确认点数
	wire [3:0]dec_v5_valley_confirm_pts;          // 波谷连续上升确认点数
	wire [23:0]dec_v5_direction_deadband;         // 相邻FIR方向分类死区
	wire [23:0]dec_v5_min_peak_valley_amplitude;  // 合格峰谷最小幅度
	wire [15:0]dec_v5_min_peak_to_valley_frames;  // 波峰到波谷最小帧差
	wire [15:0]dec_v5_min_peak_to_peak_frames;    // 相邻波峰最小帧差
	wire [15:0]dec_v5_max_fine_window_frames;     // 15-bit窗口最大持续帧数
	wire [15:0]dec_v5_max_reacquire_frames;       // 9-bit重新获取最大帧数
	wire [13:0]dec_v5_reserved;                   // V5保留位段

	//---------------其他信号---------------//

	//---------------输出信号---------------//
	// ACTIVE配置、版本标签和软件可见事件寄存器
	reg [C_CONFIG_WIDTH - 1:0]active_config_o; // 原子保存最近一次合法完整V4+V5联合配置
	reg active_valid_o;                     // 标记ACTIVE配置是否可供本轮启动
	reg [7:0]config_epoch_o;                // 对合法完整提交次数进行模计数
	reg [7:0]coef_epoch_o;                  // 对有效Stage1系数提交次数进行模计数
	reg [7:0]stage2_coef_epoch_o;           // 记录正式Stage2残差拟合参数的提交序号
	reg [7:0]dc_recovery_coef_epoch_o;      // 对合法DC恢复字段组提交次数进行模计数
	reg [C_RUN_GENERATION_WIDTH - 1:0]run_generation_o; // 唯一代际寄存，合法START原子递增一次
	reg stop_episode_active_o;              // 合法STOP置位、STOPPING期间幂等的排空episode寄存
	reg commit_ack_event_o;                 // 配置成功应答的目标域单拍寄存器
	reg start_ack_event_o;                  // START成功应答的目标域单拍寄存器
	reg stop_ack_event_o;                   // STOP接受应答的目标域单拍寄存器
	reg error_event_o;                      // 拒绝事件的目标域单拍寄存器
	reg commit_ack_sticky_o;                // 保存至少一次未清除的配置成功事件
	reg error_sticky_o;                     // 保存至少一次未清除的错误事件
	reg [7:0]last_error_code_o;             // 保存最近一次拒绝原因供SPI读回

	//-------------其他信号连线-------------//
	assign flag_state_invalid =
		(state_current != ST_CONFIG) &&
		(state_current != ST_READY) &&
		(state_current != ST_RUN) &&
		(state_current != ST_STOPPING);     // 捕获3-bit状态寄存器的四个保留编码
	assign flag_command_conflict =
		(i_config_update_event && i_start_event) ||
		(i_config_update_event && i_stop_event) ||
		(i_config_update_event && i_status_clear_event) ||
		(i_start_event && i_stop_event) ||
		(i_start_event && i_status_clear_event) ||
		(i_stop_event && i_status_clear_event); // 任意两个事件同时出现都拒绝全部动作
	assign flag_snapshot_schema_valid = i_config_snapshot[7:0] == 8'h04; // V4只接收冻结的schema编号4
	assign flag_snapshot_reserved_valid =
		(i_config_snapshot[31:23] == 9'd0) &&
		(i_config_snapshot[639:592] == 48'd0); // V4头部和高位扩展保留区必须全部写零
	assign flag_snapshot_enum_valid = i_config_snapshot[11:10] != 2'b11; // 拒绝保留的IDAC模式编码，V4.9起归类为ERROR_RESERVED_IDAC_MODE
	assign dec_v5_slope_mode = i_config_snapshot[640]; // V5[0]译码为基线斜率固定或自适应选择
	assign dec_v5_fixed_slope_q16 = $signed(i_config_snapshot[672:641]); // V5[32:1]译码为固定负斜率的signed Q16值
	assign dec_v5_alpha_q15 = i_config_snapshot[688:673]; // V5[48:33]译码为基础斜率幅度比例
	assign dec_v5_beta_q15 = i_config_snapshot[704:689]; // V5[64:49]译码为活动斜率平滑比例
	assign dec_v5_timing_adjust_ratio_q15 = i_config_snapshot[720:705]; // V5[80:65]译码为相交时刻修正比例
	assign dec_v5_slope_min_q16 = $signed(i_config_snapshot[752:721]); // V5[112:81]译码为最负斜率边界
	assign dec_v5_slope_max_q16 = $signed(i_config_snapshot[784:753]); // V5[144:113]译码为最接近零斜率边界
	assign dec_v5_baseline_delta_q16 = $signed(i_config_snapshot[816:785]); // V5[176:145]译码为波峰锚点基线偏置
	assign dec_v5_cross_hysteresis_q16 = i_config_snapshot[848:817]; // V5[208:177]译码为向上相交迟滞量
	assign dec_v5_lead_min_frames = i_config_snapshot[864:849]; // V5[224:209]译码为相交提前量合格下界
	assign dec_v5_lead_max_frames = i_config_snapshot[880:865]; // V5[240:225]译码为相交提前量合格上界
	assign dec_v5_cross_confirm_pts = i_config_snapshot[884:881]; // V5[244:241]译码为相交连续确认点数
	assign dec_v5_no_cross_limit = i_config_snapshot[888:885]; // V5[248:245]译码为连续无相交重新获取阈值
	assign dec_v5_peak_confirm_pts = i_config_snapshot[892:889]; // V5[252:249]译码为波峰连续下降确认点数
	assign dec_v5_valley_confirm_pts = i_config_snapshot[896:893]; // V5[256:253]译码为波谷连续上升确认点数
	assign dec_v5_direction_deadband = i_config_snapshot[920:897]; // V5[280:257]译码为相邻FIR方向分类死区
	assign dec_v5_min_peak_valley_amplitude = i_config_snapshot[944:921]; // V5[304:281]译码为合格峰谷最小幅度
	assign dec_v5_min_peak_to_valley_frames = i_config_snapshot[960:945]; // V5[320:305]译码为波峰到波谷最小帧差
	assign dec_v5_min_peak_to_peak_frames = i_config_snapshot[976:961]; // V5[336:321]译码为相邻波峰最小帧差
	assign dec_v5_max_fine_window_frames = i_config_snapshot[992:977]; // V5[352:337]译码为15-bit窗口最大持续帧数
	assign dec_v5_max_reacquire_frames = i_config_snapshot[1008:993]; // V5[368:353]译码为9-bit重新获取最大帧数
	assign dec_v5_reserved = i_config_snapshot[1023:1010]; // V5[383:370]译码为保留位段，必须全部为零
	assign flag_snapshot_v5_reserved_valid = dec_v5_reserved == 14'd0; // V5保留位段必须全部写零
	assign flag_snapshot_v5_range_valid =
		(dec_v5_slope_min_q16 < dec_v5_slope_max_q16) && (dec_v5_slope_max_q16 < 32'sd0) &&
		(dec_v5_fixed_slope_q16 < 32'sd0) &&
		(dec_v5_fixed_slope_q16 >= dec_v5_slope_min_q16) &&
		(dec_v5_fixed_slope_q16 <= dec_v5_slope_max_q16) &&
		(dec_v5_alpha_q15 <= 16'h7fff) &&
		(dec_v5_beta_q15 <= 16'h7fff) &&
		(dec_v5_timing_adjust_ratio_q15 <= 16'h7fff) &&
		(dec_v5_cross_hysteresis_q16 != 32'd0) &&
		(dec_v5_lead_min_frames <= dec_v5_lead_max_frames) &&
		(dec_v5_cross_confirm_pts != 4'd0) &&
		(dec_v5_no_cross_limit != 4'd0) &&
		(dec_v5_peak_confirm_pts != 4'd0) &&
		(dec_v5_valley_confirm_pts != 4'd0) &&
		(dec_v5_min_peak_valley_amplitude != 24'd0) &&
		(dec_v5_min_peak_to_valley_frames != 16'd0) &&
		(dec_v5_min_peak_to_peak_frames != 16'd0) &&
		(dec_v5_min_peak_to_valley_frames <= dec_v5_min_peak_to_peak_frames) &&
		(dec_v5_max_fine_window_frames != 16'd0) &&
		(dec_v5_max_reacquire_frames != 16'd0); // V5全部字段取值范围及跨字段关系逐项核对
	assign flag_snapshot_normal_current_valid =
		!((i_config_snapshot[8] == 1'b0) && (i_config_snapshot[9] == 1'b1)); // 禁止NORMAL_PPG请求外部固定电流输入源
	assign flag_snapshot_char_idac_valid =
		!((i_config_snapshot[8] == 1'b1) && (i_config_snapshot[11:10] != 2'b00)); // CHARACTERIZATION只允许MANUAL IDAC模式
	assign flag_snapshot_char_photodiode_optical_valid =
		!((i_config_snapshot[8] == 1'b1) && (i_config_snapshot[9] == 1'b0)) ||
		(i_config_snapshot[13:12] == 2'b01); // 光电二极管CHARACTERIZATION必须为纯红光
	assign flag_snapshot_char_current_optical_valid =
		!((i_config_snapshot[8] == 1'b1) && (i_static_characterization_enable == 1'b0) && (i_config_snapshot[9] == 1'b1)) ||
		(i_config_snapshot[13:12] != 2'b11); // 非STATIC_BIAS固定电流表征禁止安全关闭光学模式；ILM-08 optical_mode=2'b11(安全关闭)在此结构性判假，479行ERROR_FIXED_CURRENT_OPTICAL_MODE(0x16)COMMIT阶段直接拒绝，active_config_o从未被这组非法快照污染，RUN/波形/owner阶段永不触发 @satisfies: ILM-08
	assign flag_snapshot_static_bias_valid =
		!i_static_characterization_enable ||
		((i_config_snapshot[8] == 1'b1) && (i_config_snapshot[9] == 1'b1)); // 已提交STATIC_BIAS资格时候选必须为CHARACTERIZATION加外部固定电流；ILM-15 static_characterization_enable=1但input_source快照仍为PHOTODIODE(bit9=0)时本条件结构性为假，481行ERROR_STATIC_BIAS_INPUT_SOURCE(0x14)COMMIT阶段拒绝，停留ST_CONFIG，静态向量/波形/owner/码/计数器零侧效应 @satisfies: ILM-15
	assign flag_start_static_bias_valid =
		!i_static_characterization_enable ||
		((active_config_o[8] == 1'b1) && (active_config_o[9] == 1'b1)); // START拍复核ACTIVE，允许COMMIT后、START前资格由0变1
	assign flag_snapshot_profile_precision_valid =
		i_config_snapshot[8] ||
		(i_config_snapshot[14] == 1'b0);    // NORMAL只允许SAR9，表征允许两种初始精度
	assign flag_snapshot_idac_range_valid =
		(i_config_snapshot[47:40] <= i_config_snapshot[39:32]) &&
		(i_config_snapshot[39:32] <= i_config_snapshot[55:48]) &&
		(i_config_snapshot[71:64] <= i_config_snapshot[63:56]) &&
		(i_config_snapshot[63:56] <= i_config_snapshot[79:72]) &&
		(i_config_snapshot[95:88] <= i_config_snapshot[87:80]) &&
		(i_config_snapshot[87:80] <= i_config_snapshot[103:96]); // 检查AMB及两种颜色DCS码的闭区间关系
	assign dec_amb_threshold_low = $signed(i_config_snapshot[115:104]); // 保留负阈值的二进制补码语义
	assign dec_amb_threshold_high = $signed(i_config_snapshot[127:116]); // 为AMB有符号窗口比较提供上界
	assign dec_dcs_threshold_low = $signed(i_config_snapshot[139:128]); // 保留DCS残差负侧范围
	assign dec_dcs_threshold_high = $signed(i_config_snapshot[151:140]); // 解包颜色直流闭环正侧迟滞边界
	assign dec_stage2_gain_q16 = $signed(i_config_snapshot[479:460]); // 保留Stage2统一增益的signed Q16语义
	assign dec_dc9_recovery_gain_q16 = $signed(i_config_snapshot[543:512]); // 将粗精度DC每码恢复量解释为signed Q16
	assign dec_dc15_recovery_gain_q16 = $signed(i_config_snapshot[575:544]); // 将精细精度DC每码恢复量解释为signed Q16
	assign flag_snapshot_threshold_valid =
		(dec_amb_threshold_low < dec_amb_threshold_high) &&
		(dec_dcs_threshold_low < dec_dcs_threshold_high); // 两组迟滞窗口都要求严格低于关系
	assign flag_snapshot_confirm_valid =
		(i_config_snapshot[159:152] != 8'd0) &&
		(i_config_snapshot[167:160] != 8'd0); // 禁止零次确认导致无定义的立即调码
	assign flag_snapshot_nominal_coef_valid =
		($signed(i_config_snapshot[193:168]) == NOMINAL_WEIGHT_0) &&
		($signed(i_config_snapshot[219:194]) == NOMINAL_WEIGHT_1) &&
		($signed(i_config_snapshot[245:220]) == NOMINAL_WEIGHT_2) &&
		($signed(i_config_snapshot[271:246]) == NOMINAL_WEIGHT_3) &&
		($signed(i_config_snapshot[297:272]) == NOMINAL_WEIGHT_4) &&
		($signed(i_config_snapshot[323:298]) == NOMINAL_WEIGHT_5) &&
		($signed(i_config_snapshot[349:324]) == NOMINAL_WEIGHT_6) &&
		($signed(i_config_snapshot[375:350]) == NOMINAL_WEIGHT_7) &&
		($signed(i_config_snapshot[401:376]) == NOMINAL_WEIGHT_8) &&
		($signed(i_config_snapshot[427:402]) == NOMINAL_WEIGHT_9) &&
		($signed(i_config_snapshot[459:428]) == NOMINAL_OFFSET); // 未校准表征必须逐位复现固定黄金公式
	assign flag_snapshot_coef_qualification_valid =
		i_config_snapshot[19] ||
		(i_config_snapshot[8] && flag_snapshot_nominal_coef_valid); // NORMAL必须校准，表征可使用完整标称权重
	assign flag_snapshot_stage2_value_valid =
		(i_config_snapshot[20] == 1'b0) ||
		(dec_stage2_gain_q16 > 20'sd0);     // 声明有效时拒绝零值或反向Stage2增益
	assign flag_snapshot_stage2_qualification_valid =
		(i_config_snapshot[8] || i_config_snapshot[20]) &&
		flag_snapshot_stage2_value_valid;   // NORMAL要求正式Stage2系数，表征允许临时系数
	assign flag_snapshot_dc_value_valid =
		((i_config_snapshot[21] == 1'b0) ||
			(dec_dc9_recovery_gain_q16 > 32'sd0)) &&
		((i_config_snapshot[22] == 1'b0) ||
			(dec_dc15_recovery_gain_q16 > 32'sd0)); // 有效DC恢复系数必须符合加回正极性
	assign flag_snapshot_dc_qualification_valid =
		(i_config_snapshot[8] ||
			(i_config_snapshot[21] && i_config_snapshot[22])) &&
		flag_snapshot_dc_value_valid;       // NORMAL要求粗精度与精细精度恢复资格完整
	assign flag_snapshot_valid =
		flag_snapshot_schema_valid &&
		flag_snapshot_reserved_valid &&
		flag_snapshot_v5_reserved_valid &&
		flag_snapshot_v5_range_valid &&
		flag_snapshot_enum_valid &&
		flag_snapshot_profile_precision_valid &&
		flag_snapshot_normal_current_valid &&
		flag_snapshot_char_photodiode_optical_valid &&
		flag_snapshot_char_current_optical_valid &&
		flag_snapshot_char_idac_valid &&
		flag_snapshot_static_bias_valid &&
		flag_snapshot_idac_range_valid &&
		flag_snapshot_threshold_valid &&
		flag_snapshot_confirm_valid &&
		flag_snapshot_coef_qualification_valid &&
		flag_snapshot_stage2_qualification_valid &&
		flag_snapshot_dc_qualification_valid; // 任一字段失败都会拒绝整组快照
	assign flag_start_ready =
		(state_current == ST_READY) && active_valid_o &&
		i_analog_ready && i_adc_idle && i_datapath_empty && i_idac_idle &&
		flag_start_static_bias_valid &&
		(i_system_fault_blocking == 1'b0) &&
		(error_sticky_o == 1'b0);           // 启动前要求配置、模拟、数字链、STATIC_BIAS资格和系统阻断全部就绪
	assign flag_commit_accept =
		i_config_update_event && (flag_command_conflict == 1'b0) &&
		(state_current == ST_CONFIG) && flag_snapshot_valid; // 仅CONFIG状态可原子接纳合法快照；ILM-10 RUN期间state_current非ST_CONFIG，本条件结构性为假，任何mid-RUN重配置提交都被拒绝；配合522行active_config_o仅在合法COMMIT才替换，当前事务快照的输入源/光学模式/初始精度/MANUAL码在RUN全程保持不变，只有后续合法RUN才会采用新提交值 @satisfies: ILM-10
	assign flag_start_accept =
		i_start_event && (flag_command_conflict == 1'b0) && flag_start_ready; // START不允许产生任何部分运行动作
	assign flag_stop_accept =
		i_stop_event && (flag_command_conflict == 1'b0) &&
		((state_current == ST_RUN) || (state_current == ST_STOPPING)); // STOPPING重复STOP按幂等命令接受；STOP立即禁止新事务的接受判据 @satisfies: TOP-09
	assign flag_stopping_complete =
		i_adc_idle && i_datapath_empty && i_idac_idle && i_analog_safe; // 禁止用固定延时替代显式排空证明
	assign dec_error_present = dec_error_code != ERROR_NONE; // 非零错误码产生单拍和sticky错误
	assign dec_lifecycle_state = flag_state_invalid ? 2'b00 :
		state_current[1:0];                 // 非法内部编码对外只呈现CONFIG安全状态
	assign dec_error_code = flag_state_invalid ? ERROR_FSM_STATE :
		flag_command_conflict ? ERROR_COMMAND_CONFLICT :
		(i_config_update_event && (state_current != ST_CONFIG)) ? ERROR_COMMIT_STATE :
		(i_config_update_event && !flag_snapshot_schema_valid) ? ERROR_SCHEMA_VERSION :
		(i_config_update_event && !flag_snapshot_reserved_valid) ? ERROR_RESERVED_BITS :
		(i_config_update_event && !flag_snapshot_v5_reserved_valid) ? ERROR_V5_SCHEMA_RESERVED :
		(i_config_update_event && !flag_snapshot_v5_range_valid) ? ERROR_V5_FIELD_RANGE :
		(i_config_update_event && !flag_snapshot_enum_valid) ? ERROR_RESERVED_IDAC_MODE :
		(i_config_update_event && !flag_snapshot_profile_precision_valid) ? ERROR_NORMAL_INITIAL_PRECISION :
		(i_config_update_event && !flag_snapshot_normal_current_valid) ? ERROR_NORMAL_EXTERNAL_CURRENT :
		(i_config_update_event && !flag_snapshot_char_photodiode_optical_valid) ? ERROR_CHARACTERIZATION_OPTICAL_MODE :
		(i_config_update_event && !flag_snapshot_char_current_optical_valid) ? ERROR_FIXED_CURRENT_OPTICAL_MODE :
		(i_config_update_event && !flag_snapshot_char_idac_valid) ? ERROR_CHARACTERIZATION_AUTO_IDAC :
		(i_config_update_event && !flag_snapshot_static_bias_valid) ? ERROR_STATIC_BIAS_INPUT_SOURCE :
		(i_config_update_event && !flag_snapshot_idac_range_valid) ? ERROR_IDAC_RANGE :
		(i_config_update_event && !flag_snapshot_threshold_valid) ? ERROR_THRESHOLD_RANGE :
		(i_config_update_event && !flag_snapshot_confirm_valid) ? ERROR_CONFIRM_COUNT :
		(i_config_update_event && !flag_snapshot_coef_qualification_valid) ? ERROR_STAGE1_COEFFICIENT :
		(i_config_update_event && !flag_snapshot_stage2_qualification_valid) ? ERROR_STAGE2_COEFFICIENT :
		(i_config_update_event && !flag_snapshot_dc_qualification_valid) ? ERROR_DC_RECOVERY_COEFFICIENT :
		(i_start_event && (state_current != ST_READY)) ? ERROR_START_STATE :
		(i_start_event && !flag_start_static_bias_valid) ? ERROR_STATIC_BIAS_INPUT_SOURCE :
		(i_start_event && !flag_start_ready) ? ERROR_START_QUALIFICATION :
		(i_stop_event && (state_current != ST_RUN) &&
			(state_current != ST_STOPPING)) ? ERROR_STOP_STATE : ERROR_NONE; // 固定顺序保证软件得到确定的首个失败原因

	//-------------输出信号连线-------------//
	assign o_active_config = active_config_o; // 输出经整组校验后原子保存的ACTIVE快照
	assign o_active_valid = active_valid_o &&
		(flag_state_invalid == 1'b0);       // 非法状态出现时组合撤销当前运行资格
	assign o_config_epoch = config_epoch_o; // 输出静态配置提交版本
	assign o_coef_epoch = coef_epoch_o;     // 输出真正校准Stage1系数的版本
	assign o_stage2_coef_epoch = stage2_coef_epoch_o; // 输出Stage2校准系数组独立版本
	assign o_dc_recovery_coef_epoch = dc_recovery_coef_epoch_o; // 输出DC恢复字段组独立版本
	assign o_lifecycle_state = dec_lifecycle_state; // 输出安全映射后的四态生命周期编码
	assign o_start_ready = flag_start_ready; // 向SPI状态寄存器暴露组合启动资格
	assign o_run_enable = state_current == ST_RUN; // RUN以外状态关闭功能链运行许可
	assign o_allow_new_transaction = state_current == ST_RUN; // STOP进入后立即阻止发起新ADC事务
	assign o_run_generation = run_generation_o; // 输出唯一代际寄存
	assign o_stop_episode_active = stop_episode_active_o; // 输出排空episode电平供supervisor watchdog仲裁
	assign o_commit_ack_event = commit_ack_event_o; // 输出合法COMMIT的单周期应答
	assign o_start_ack_event = start_ack_event_o; // 报告系统已从READY进入RUN
	assign o_stop_ack_event = stop_ack_event_o; // 输出STOP接受或幂等处理应答
	assign o_error_event = error_event_o;   // 输出命令或快照拒绝事件
	assign o_commit_ack_sticky = commit_ack_sticky_o; // 输出未清除的提交成功历史
	assign o_error_sticky = error_sticky_o; // 输出未清除的错误历史
	assign o_last_error_code = last_error_code_o; // 输出最近一次确定错误分类

	//-----------输出信号处理区域-----------//
	// 合法COMMIT以单个宽寄存器原子替换全部ACTIVE字段，复位V5段落到合同冻结的唯一默认档案
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			active_config_o <= {V5_RESET_PROFILE, 640'd0}; // V4段复位安全不具备运行资格，V5段使用合同冻结默认档案
		end else if(flag_commit_accept == 1'b1)begin
			active_config_o <= i_config_snapshot; // 同一时钟沿保存完整1024-bit合法V4+V5联合配置；单寄存器原子替换，仅legal时提交；ILM-10 拒绝分支(524行)使当前事务下游消费的active_config_o在整个RUN内原样保持，只有后续合法快照才会替换 @satisfies: TOP-02, ILM-10
		end else begin
			active_config_o <= active_config_o; // 拒绝和运行期间禁止部分字段变化
		end
	end

	// flag_start_accept本身已经把i_system_fault_blocking和STATIC_BIAS组合门控在内，这里只需在该拍原子加一
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 复位代际归零
		end else if(flag_start_accept == 1'b1)begin
			run_generation_o <= run_generation_o + 1'b1; // 合法START时递增，i_system_fault_blocking为高时flag_start_accept恒为0不会误增；manager唯一generation生产者 @satisfies: N02
		end else begin
			run_generation_o <= run_generation_o; // 非START拍保持当前代际
		end
	end

	// 排空episode电平由Top合并STOP置位，STOPPING期间幂等，排空完成或复位后清零
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stop_episode_active_o <= 1'b0;  // 复位清除episode证据
		end else if(flag_stop_accept == 1'b1)begin
			stop_episode_active_o <= 1'b1;  // 接受STOP或STOPPING中重复STOP均保持置位
		end else if((state_current == ST_STOPPING) &&
			(flag_stopping_complete == 1'b1))begin
			stop_episode_active_o <= 1'b0;  // 全部数字与模拟排空完成后清零，允许下一次episode
		end else begin
			stop_episode_active_o <= stop_episode_active_o; // 其余情况保持当前episode电平
		end
	end

	// ACTIVE资格在合法提交后建立并在STOPPING完成时撤销
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			active_valid_o <= 1'b0;         // 复位后必须重新完整COMMIT
		end else if(flag_state_invalid == 1'b1)begin
			active_valid_o <= 1'b0;         // 异常状态恢复时撤销所有运行资格
		end else if(flag_commit_accept == 1'b1)begin
			active_valid_o <= 1'b1;         // 当前ACTIVE快照通过所有V4检查
		end else if((state_current == ST_STOPPING) &&
			(flag_stopping_complete == 1'b1))begin
			active_valid_o <= 1'b0;         // 每次STOP完成后要求新一轮配置提交
		end else begin
			active_valid_o <= active_valid_o; // READY、RUN和排空期间保持资格稳定
		end
	end

	// Stage2版本只对声明为有效校准系数的合法提交递增
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stage2_coef_epoch_o <= 8'd0;    // 标称或临时Stage2参数不冒充校准版本
		end else if((flag_commit_accept == 1'b1) &&
			(i_config_snapshot[20] == 1'b1))begin
			stage2_coef_epoch_o <= stage2_coef_epoch_o + 8'd1; // 正式Stage2系数生效后更新版本
		end else begin
			stage2_coef_epoch_o <= stage2_coef_epoch_o; // 未声明校准资格时保持版本
		end
	end

	// DC恢复版本绑定每次合法提交的两组系数和值有效标志
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			dc_recovery_coef_epoch_o <= 8'd0; // 复位后没有可关联的DC恢复字段组
		end else if(flag_commit_accept == 1'b1)begin
			dc_recovery_coef_epoch_o <= dc_recovery_coef_epoch_o + 8'd1; // 完整字段组原子生效后形成新版本
		end else begin
			dc_recovery_coef_epoch_o <= dc_recovery_coef_epoch_o; // 拒绝或生命周期命令不改变版本
		end
	end

	// 配置版本对每次合法完整提交执行模递增
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			config_epoch_o <= 8'd0;         // 复位版本从零开始
		end else if(flag_commit_accept == 1'b1)begin
			config_epoch_o <= config_epoch_o + 8'd1; // 相同内容的完整提交也形成新版本
		end else begin
			config_epoch_o <= config_epoch_o; // 非提交操作不改变静态配置版本
		end
	end

	// Stage1物理位权重组的正式资格提交更新粗级校准版本
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			coef_epoch_o <= 8'd0;           // 标称复位系数不冒充已校准版本
		end else if((flag_commit_accept == 1'b1) &&
			(i_config_snapshot[19] == 1'b1))begin
			coef_epoch_o <= coef_epoch_o + 8'd1; // 真正校准系数成为ACTIVE后更新版本
		end else begin
			coef_epoch_o <= coef_epoch_o;   // 标称表征提交保持校准版本不变
		end
	end

	// 合法完整配置生效后输出恰好一个时钟周期的最终ACK
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			commit_ack_event_o <= 1'b0;     // 复位期间禁止伪造提交应答
		end else begin
			commit_ack_event_o <= flag_commit_accept; // transport ACK之外独立报告ACTIVE生效
		end
	end

	// 合法START进入RUN时产生单拍应答
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			start_ack_event_o <= 1'b0;      // 复位期间没有启动事务
		end else begin
			start_ack_event_o <= flag_start_accept; // 不合格START不会产生部分ACK
		end
	end

	// RUN中的STOP和STOPPING中的重复STOP都返回确定应答
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stop_ack_event_o <= 1'b0;       // 复位期间禁止STOP应答
		end else begin
			stop_ack_event_o <= flag_stop_accept; // 重复STOP幂等确认但不重启排空动作
		end
	end

	// 任一确定错误码产生一拍错误事件
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			error_event_o <= 1'b0;          // 复位期间不报告历史错误
		end else begin
		error_event_o <= dec_error_present; // 每个被拒绝请求只上报一次事件
		end
	end

	// 提交成功sticky由显式状态清除命令撤销，新成功事件优先
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			commit_ack_sticky_o <= 1'b0;    // 复位清除软件可读成功历史
		end else if(flag_commit_accept == 1'b1)begin
			commit_ack_sticky_o <= 1'b1;    // 保存最终ACTIVE提交成功事实
		end else if((i_status_clear_event == 1'b1) &&
			(flag_command_conflict == 1'b0))begin
			commit_ack_sticky_o <= 1'b0;    // 独立W1C事件清除成功状态
		end else begin
			commit_ack_sticky_o <= commit_ack_sticky_o; // 普通生命周期操作不丢失读回状态
		end
	end

	// 错误sticky在新错误与清除同拍时保持新错误优先
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			error_sticky_o <= 1'b0;         // 复位清除错误汇总
		end else if(dec_error_present == 1'b1)begin
			error_sticky_o <= 1'b1;         // 任一非法操作都留下可轮询证据
		end else if((i_status_clear_event == 1'b1) &&
			(flag_command_conflict == 1'b0))begin
			error_sticky_o <= 1'b0;         // 合法W1C事件撤销历史错误
		end else begin
			error_sticky_o <= error_sticky_o; // 没有清除时持续保持错误证据
		end
	end

	// 最近错误码只在新错误到来或合法清除时改变
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			last_error_code_o <= ERROR_NONE; // 复位读回无错误编码
		end else if(dec_error_present == 1'b1)begin
			last_error_code_o <= dec_error_code; // 固定优先级保存本拍拒绝原因
		end else if((i_status_clear_event == 1'b1) &&
			(flag_command_conflict == 1'b0))begin
			last_error_code_o <= ERROR_NONE; // W1C同时恢复无错误码
		end else begin
			last_error_code_o <= last_error_code_o; // 成功操作不会隐式覆盖旧错误码
		end
	end

	//---------------状态机区域---------------//
	// 生命周期寄存器在异步复位后只进入CONFIG安全状态
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_CONFIG;       // 复位不允许直接获得READY或RUN资格
		end else begin
			state_current <= state_next;      // 每拍只采纳经过合同检查的下一状态
		end
	end

	// 下一状态只由已接受事件和显式排空条件决定
	always@(*)begin
		state_next = state_current;           // 默认保持可避免组合状态存储缺口
		case(state_current)
			ST_CONFIG:begin
				if(flag_commit_accept == 1'b1)begin
					state_next = ST_READY;    // 合法完整配置原子生效后等待START
				end
			end
			ST_READY:begin
				if(flag_start_accept == 1'b1)begin
					state_next = ST_RUN;      // 所有资格成立后一次性进入运行状态
				end
			end
			ST_RUN:begin
				if(flag_stop_accept == 1'b1)begin
					state_next = ST_STOPPING; // STOP立即关闭新事务并开始排空
				end
			end
			ST_STOPPING:begin
				if(flag_stopping_complete == 1'b1)begin
					state_next = ST_CONFIG;   // 数字与模拟均安全后允许重新配置
				end
			end
			default:begin
				state_next = ST_CONFIG;       // 异常状态强制回到安全配置态
			end
		endcase
	end

endmodule
