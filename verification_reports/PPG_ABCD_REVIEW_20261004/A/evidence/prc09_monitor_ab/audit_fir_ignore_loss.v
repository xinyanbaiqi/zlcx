`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/08
// Design Name:        PPG Coarse Detection FIR
// Module Name:        ppg_coarse_detection_fir
// Description:        Description/ppg_coarse_detection_fir_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_coarse_detection_fir
//
// Referrences:        PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md,
//                     ppg_adc_dc_recovery.v
//
// Dependencies:       None
//
// Version:            V2.3
// Revision Date:      2026/08/31
// History:
//    Time               Version       Revised by            Contents
// 2026/08/08            V1.0          Erie                  Create file.
// 2026/08/12            V2.0          Erie                  Upgrade to 21-tap cyclic MAC FIR.
// 2026/08/22            V2.1          Erie                  Remove i_stop_ack_event/i_control_abort_event direct-clear ports; add PWI-broadcast i_detection_discard group, i_run_generation and o_local_empty per PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md section 11.1.
// 2026/08/23            V2.2          Erie                  Add explicit i_sample_valid term to flag_sample_qualified to literally match section 7.3 formula; no behavioral change (already guaranteed by flag_history_transfer).
// 2026/08/31            V2.3          Erie                  Stage 5 bucket-2 RTL session: add a new, additive, default-off verification-only injection group (`C_ENABLE_TEST_INJECTION` parameter, default 0, mirrors the family already frozen on ppg_idac_code_controller.v/ppg_sar9_sar15_safe_selection_wrapper.v in bucket-1) -- `i_test_inject_enable`/`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready` one-shot binds to the very next real `flag_input_transfer` and forces that single sample's own calibration term of `flag_sample_qualified` to 0, without touching the shared `i_coarse_recovery_calibrated` port or any static config bit. This exercises FIR-17's already-documented "an uncalibrated sample still enters history but its covering windows lose formal qualification" behavior under real top-level construction, closing the PRC-09/PRC-10 gap (see PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md V2.5). Production behavior is bit-identical when `C_ENABLE_TEST_INJECTION=0` -- verified this remains true only when the injection ports are correctly tied off by the instantiating wrapper; port threading through ppg_precision_window_integration.v/ppg_adc_measurement_idac_integration.v/ppg_control_top.v is a separate, not-yet-done follow-up.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月08日
// 设计名称:           PPG粗检测有限冲激响应滤波器
// 模块名称:           ppg_coarse_detection_fir
// 模块说明:           Description/ppg_coarse_detection_fir_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_coarse_detection_fir
//
// 参考资料:           PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md、
//                     ppg_adc_dc_recovery.v
//
// 依赖文件:           无
//
// 当前版本:           V2.3
// 修订日期:           2026年08月31日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月08日        V1.0          Erie                  创建文件
// 2026年08月12日        V2.0          Erie                  升级为21抽头周期MAC结构
// 2026年08月22日        V2.1          Erie                  删除i_stop_ack_event/i_control_abort_event直接清除端口，按合同11.1节新增PWI广播的i_detection_discard组、i_run_generation和o_local_empty
// 2026年08月23日        V2.2          Erie                  flag_sample_qualified补充显式i_sample_valid项，字面对齐合同7.3公式，无行为变化（已被flag_history_transfer保证）
// 2026年08月31日        V2.3          Erie                  Stage 5桶2 RTL会话：新增一组默认关闭、纯additive的验证专用注入端口（`C_ENABLE_TEST_INJECTION`参数，默认0，照抄桶1已经在`ppg_idac_code_controller.v`/`ppg_sar9_sar15_safe_selection_wrapper.v`上冻结过的注入端口家族风格）——`i_test_inject_enable`/`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready`一次性绑定下一笔真实`flag_input_transfer`，强制这一笔样本自己的`flag_sample_qualified`校准项为0，不碰共享的`i_coarse_recovery_calibrated`端口、不碰任何静态config。真实构造出FIR-17合同条款已经记录过的"未校准样本仍进历史但让覆盖它的窗口失去正式资格"行为，关闭PRC-09/PRC-10缺口（见`PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md`V2.5）。`C_ENABLE_TEST_INJECTION=0`时生产行为逐位不变——但这个不变性只在例化方正确把新端口接地/悬空时才成立；端口透传到`ppg_precision_window_integration.v`/`ppg_adc_measurement_idac_integration.v`/`ppg_control_top.v`这三层例化是独立的、本轮尚未完成的后续步骤。

// 对两种颜色的粗PPG值分别执行固定Q15低通，并保存窗口中心样本的完整事务身份
module audit_fir_ignore_loss
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16, // 中心样本PPG帧标识字段位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // 中心样本全局事务序号字段位宽
	parameter integer C_IDAC_CODE_WIDTH = 32'd8, // AMB与颜色DC码快照字段位宽
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // IDAC committed码版本字段位宽
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // 完整ACTIVE配置版本字段位宽
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8, // Stage1校准系数组版本字段位宽
	parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8, // DC恢复系数组版本字段位宽
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8, // manager唯一生产、由PWI逐层广播的RUN代际字段位宽
	parameter integer C_ENABLE_TEST_INJECTION = 32'd0 // 默认关闭的验证专用calibration-loss注入结构生成使能，生产网表必须为0
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字处理域工作时钟
	input i_rstn,                           // 低有效异步复位，撤销计算与历史状态

	//-------------生命周期接口-------------//
	input i_run_enable,                     // 当前RUN允许接收NORMAL粗结果
	input i_start_ack_event,                // 新RUN接受后同步重建两色历史
	input i_recheck_accept_event,           // AMB周期重检在安全排空后实际接管
	input i_recheck_busy,                   // 接管等待和三帧校准期间阻止新NORMAL输入

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
	output o_local_empty,                  // MAC与输出保持槽均排空时为高，唯一消费者PWI

	//-------------上游事务接口-------------//
	input i_result_valid,                   // DC恢复模块保持的完整NORMAL事务valid
	output o_result_ready,                  // FIR空闲并可保存当前粗结果
	input i_sample_valid,                   // 独立样本资格，0事务仍消费但禁止历史、MAC和检测推进
	input signed [23:0]i_coarse_ppg_value,  // DC恢复后的统一signed 24-bit粗PPG码
	input i_coarse_valid,                   // 当前事务具有可计算的粗数值
	input i_coarse_recovery_calibrated,     // Stage1与DC9恢复均具备正式资格
	input i_stage1_saturation_low,          // Stage1校准曾触及负向端点
	input i_stage1_saturation_high,         // Stage1校准曾触及正向端点
	input i_coarse_saturation_low,          // 粗DC恢复结果发生负向24-bit饱和
	input i_coarse_saturation_high,         // 粗DC恢复结果发生正向24-bit饱和
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 本笔事务绑定的ACTIVE配置版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 本笔粗结果使用的Stage1系数组版本
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_dc_recovery_coef_epoch, // 本笔使用的DC恢复系数版本
	input i_precision_mode,                 // 低为9-bit事务且高为15-bit事务
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id, // 当前R/IR共享采样帧编号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 当前ADC事务全局顺序编号
	input i_color_ir,                       // 低选择红光历史且高选择红外历史
	input [1:0]i_frame_type,                // 合法粗检测事务固定为NORMAL编码10
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // 本笔积分使用的AMB committed码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 本笔颜色积分使用的DC committed码
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // 本笔AMB码对应的提交版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // 本笔颜色DC码对应的提交版本

	//---------验证专用异常注入接口---------//
	input i_test_inject_enable,             // 当前验证构建允许接受异常注入，需同时C_ENABLE_TEST_INJECTION非0
	input i_test_calibration_loss_inject_valid, // 保持型一次性calibration-loss注入请求valid
	output o_test_calibration_loss_inject_ready, // FIR可把请求原子绑定到下一笔真实被接纳样本

	//-------------下游事务接口-------------//
	input i_result_ready,                   // 动态基线链允许消费当前滤波事务
	output o_result_valid,                  // FIR输出保持寄存器包含完整事务
	output signed [23:0]o_filtered_ppg_value, // 21抽头名义10 Hz低通后的统一PPG码
	output o_detection_qualified,           // 全窗口校准且无输入饱和的正式资格
	output o_window_saturation_low,         // 21点窗口包含负向端点样本
	output o_window_saturation_high,        // 21点窗口包含正向端点样本
	output o_fir_saturation_low,            // FIR舍入结果低于signed 24-bit范围
	output o_fir_saturation_high,           // FIR舍入结果高于signed 24-bit范围
	output o_history_full_r,                // 红光历史已经收集21笔真实样本
	output o_history_full_ir,               // 红外历史已经收集21笔真实样本
	output o_fir_idle,                      // MAC、在途事务与输出缓冲均已排空

	//-------------中心元数据接口-------------//
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch, // 窗口中心样本的ACTIVE版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch, // 标识中心样本采用的Stage1校准系数组
	output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_dc_recovery_coef_epoch, // 窗口中心样本的DC恢复版本
	output o_precision_mode,                  // 窗口中心样本采集时的精度身份
	output [C_FRAME_ID_WIDTH - 1:0]o_frame_id, // 窗口中心对应的PPG帧编号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index, // 窗口中心对应的事务顺序编号
	output o_color_ir,                        // 当前输出所属的红光或红外历史
	output [1:0]o_frame_type,                 // 中心样本保持NORMAL协议编码
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot, // 中心样本使用的AMB码快照
	output [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot, // 中心样本使用的颜色DC码快照
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // 中心样本绑定的AMB码版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch // 记录中心颜色DC码完成提交时的代次
);

	//-------------配置参数区域-------------//
	// 单点记录从数值开始依次保存资格、诊断和全部事务身份
	localparam integer DATA_LSB = 32'd0;    // signed 24-bit粗结果位于样本最低段
	localparam integer QUALIFIED_LSB = DATA_LSB + 32'd24; // 单点正式检测资格紧邻数值字段
	localparam integer SATURATION_LOW_LSB = QUALIFIED_LSB + 32'd1; // 合并负向饱和诊断占用一位
	localparam integer SATURATION_HIGH_LSB = SATURATION_LOW_LSB + 32'd1; // 合并正向饱和诊断位于低侧标志之上
	localparam integer CONFIG_EPOCH_LSB = SATURATION_HIGH_LSB + 32'd1; // ACTIVE版本跟随样本质量属性
	localparam integer COEF_EPOCH_LSB = CONFIG_EPOCH_LSB + C_CONFIG_EPOCH_WIDTH; // Stage1版本位于配置版本上方
	localparam integer DC_RECOVERY_EPOCH_LSB = COEF_EPOCH_LSB + C_COEF_EPOCH_WIDTH; // DC恢复版本保持独立字段
	localparam integer PRECISION_MODE_LSB = DC_RECOVERY_EPOCH_LSB + C_DC_RECOVERY_EPOCH_WIDTH; // 精度身份绑定单笔采样
	localparam integer FRAME_ID_LSB = PRECISION_MODE_LSB + 32'd1; // 帧号位于精度属性之上
	localparam integer SAMPLE_INDEX_LSB = FRAME_ID_LSB + C_FRAME_ID_WIDTH; // 全局序号用于中心延迟核对
	localparam integer COLOR_IR_LSB = SAMPLE_INDEX_LSB + C_SAMPLE_INDEX_WIDTH; // 颜色位区分两套历史
	localparam integer FRAME_TYPE_LSB = COLOR_IR_LSB + 32'd1; // NORMAL协议类别保留两位
	localparam integer AMB_CODE_LSB = FRAME_TYPE_LSB + 32'd2; // AMB实际码用于中心诊断
	localparam integer DC_CODE_LSB = AMB_CODE_LSB + C_IDAC_CODE_WIDTH; // 当前颜色DC实际码独立保存
	localparam integer AMB_CODE_EPOCH_LSB = DC_CODE_LSB + C_IDAC_CODE_WIDTH; // AMB提交版本跟随码快照
	localparam integer DC_CODE_EPOCH_LSB = AMB_CODE_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // DC提交版本位于样本最高段
	localparam integer SAMPLE_WIDTH = DC_CODE_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // 单点数值、资格和元数据总宽度
	localparam integer HISTORY_WIDTH = SAMPLE_WIDTH * 32'd21; // 每个颜色保存21个打包样本
	localparam integer WINDOW_DATA_WIDTH = 32'd24 * 32'd21; // 冻结计算窗口包含21个signed输入值

	// 输出载荷低段保存数值和诊断，高段保持中心样本身份
	localparam integer FILTERED_VALUE_LSB = 32'd0; // signed 24-bit滤波结果位于输出最低段
	localparam integer DETECTION_QUALIFIED_LSB = FILTERED_VALUE_LSB + 32'd24; // 正式检测资格绑定当前结果
	localparam integer WINDOW_SATURATION_LOW_LSB = DETECTION_QUALIFIED_LSB + 32'd1; // 窗口低侧诊断紧邻资格
	localparam integer WINDOW_SATURATION_HIGH_LSB = WINDOW_SATURATION_LOW_LSB + 32'd1; // 窗口高侧诊断独立保留
	localparam integer FIR_SATURATION_LOW_LSB = WINDOW_SATURATION_HIGH_LSB + 32'd1; // FIR低端饱和属性绑定数值
	localparam integer FIR_SATURATION_HIGH_LSB = FIR_SATURATION_LOW_LSB + 32'd1; // FIR高端饱和属性与低端互斥
	localparam integer OUTPUT_CONFIG_EPOCH_LSB = FIR_SATURATION_HIGH_LSB + 32'd1; // 中心ACTIVE版本开始输出元数据段
	localparam integer OUTPUT_COEF_EPOCH_LSB = OUTPUT_CONFIG_EPOCH_LSB + C_CONFIG_EPOCH_WIDTH; // 中心Stage1版本保持可追踪
	localparam integer OUTPUT_DC_RECOVERY_EPOCH_LSB = OUTPUT_COEF_EPOCH_LSB + C_COEF_EPOCH_WIDTH; // 中心恢复版本跟随Stage1版本
	localparam integer OUTPUT_PRECISION_MODE_LSB = OUTPUT_DC_RECOVERY_EPOCH_LSB + C_DC_RECOVERY_EPOCH_WIDTH; // 中心精度模式占用一位
	localparam integer OUTPUT_FRAME_ID_LSB = OUTPUT_PRECISION_MODE_LSB + 32'd1; // 中心帧号位于精度标志之上
	localparam integer OUTPUT_SAMPLE_INDEX_LSB = OUTPUT_FRAME_ID_LSB + C_FRAME_ID_WIDTH; // 中心事务号保留全宽
	localparam integer OUTPUT_COLOR_IR_LSB = OUTPUT_SAMPLE_INDEX_LSB + C_SAMPLE_INDEX_WIDTH; // 输出颜色身份对应选中历史
	localparam integer OUTPUT_FRAME_TYPE_LSB = OUTPUT_COLOR_IR_LSB + 32'd1; // NORMAL编码随中心样本延迟
	localparam integer OUTPUT_AMB_CODE_LSB = OUTPUT_FRAME_TYPE_LSB + 32'd2; // 中心AMB码快照用于诊断
	localparam integer OUTPUT_DC_CODE_LSB = OUTPUT_AMB_CODE_LSB + C_IDAC_CODE_WIDTH; // 中心颜色DC码用于追踪
	localparam integer OUTPUT_AMB_CODE_EPOCH_LSB = OUTPUT_DC_CODE_LSB + C_IDAC_CODE_WIDTH; // 中心AMB版本与码值对齐
	localparam integer OUTPUT_DC_CODE_EPOCH_LSB = OUTPUT_AMB_CODE_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // 中心DC版本位于输出最高段
	localparam integer OUTPUT_WIDTH = OUTPUT_DC_CODE_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // 保持型输出缓存总宽度
	localparam integer CONTEXT_WIDTH = OUTPUT_WIDTH - OUTPUT_CONFIG_EPOCH_LSB; // 中心身份不包含数值与诊断低段
	// 舍入与端点常量扩展到43-bit工作域，避免最负累加值取绝对值回绕
	localparam signed [42:0]ROUND_HALF = 43'sd16384; // Q15右移前加入半LSB幅值
	localparam signed [42:0]FIR_CODE_MAX = 43'sd8388607; // signed 24-bit正向端点
	localparam signed [42:0]FIR_CODE_MIN = -43'sd8388608; // signed 24-bit负向端点

	//---------------状态参数区域---------------//
	// 三段式FSM固定执行窗口快照、十一项MAC和原子提交
	localparam [1:0]ST_IDLE = 2'b00;            // 等待输入并允许预热历史更新
	localparam [1:0]ST_MAC = 2'b01;             // 逐周期复用单乘法器累加十一项
	localparam [1:0]ST_COMMIT = 2'b10;          // 完成舍入饱和并提交输出事务

	//---------------计数信号---------------//
	// 历史计数、MAC项号和有界处理周期分别独立保存
	reg [4:0]cnt_red_sample;                // 红光有效历史深度，最大保持21
	reg [4:0]cnt_ir_sample;                 // 红外有效历史深度，最大保持21
	wire [4:0]cnt_selected_sample;          // 当前颜色在输入沿之前的真实样本数
	reg [3:0]cnt_mac_index;                 // 当前正在累加的对称项或中心项编号
	reg [4:0]cnt_process_cycle;             // 从计算启动到提交的有界周期计数

	//----------------状态机信号----------------//
	// 周期MAC状态寄存器与组合下一状态保持独立
	reg [1:0]state_current;                     // 当前周期MAC阶段
	reg [1:0]state_next;                        // 下一时钟沿提交的MAC阶段

	//--------------寄存器信号--------------//
	// 两色历史和单笔计算快照均在握手边界原子更新
	reg [HISTORY_WIDTH - 1:0]reg_red_history; // 红光21点打包移位历史
	reg [HISTORY_WIDTH - 1:0]reg_ir_history; // 红外21点打包移位历史
	reg [WINDOW_DATA_WIDTH - 1:0]reg_window_data; // 当前在途计算冻结的21点数值窗口
	reg [CONTEXT_WIDTH - 1:0]reg_context_snapshot; // 中心样本全部身份的计算期快照
	reg [2:0]reg_window_status;             // 窗口资格与两侧饱和属性快照
	reg signed [41:0]reg_accumulator;       // 十一项Q15乘积的42-bit精确累加值

	//---------------标志信号---------------//
	// 握手、清理、计算和诊断标志保持清晰的单一组合定义
	wire flag_buffer_available;             // 输出为空或本拍被消费时允许下一笔输入
	wire flag_input_transfer;               // 上游事务在当前沿完成唯一握手
	wire flag_history_transfer;             // 合法NORMAL粗结果进入对应颜色历史
	wire flag_output_transfer;              // 下游消费当前保持结果
	wire flag_compute_start;                // 当前输入使选中色历史形成完整21点窗口
	wire flag_sample_qualified;             // 当前粗结果满足全部单点正式资格
	wire flag_sample_saturation_low;        // 当前样本任一级出现负向饱和
	wire flag_sample_saturation_high;       // 当前样本任一级出现正向饱和
	wire flag_window_qualified;             // 新21点窗口全部样本具备正式资格
	wire flag_window_saturation_low;        // 新窗口任一点携带低侧饱和
	wire flag_window_saturation_high;       // 新窗口任一点携带高侧饱和
	wire flag_process_timeout;              // 计算超过固定16周期保护边界
	wire flag_commit_event;                 // 提交阶段产生唯一一笔输出事务
	wire flag_fir_saturation_low;           // 舍入结果低于允许输出范围
	wire flag_fir_saturation_high;          // 舍入结果高于允许输出范围
	wire flag_fir_idle;                     // 计算、输出和当前输入沿全部排空
	wire flag_recheck_clear;                // 安全idle条件下接受重检清理
	wire flag_history_clear;                // 生命周期或重检要求重建两色状态
	wire flag_transaction_clear;            // 清理在途计算但不一定清除历史
	wire flag_test_calibration_loss_inject_fire; // 验证注入请求在当前沿被原子接受
	reg flag_test_calibration_loss_armed;   // 已绑定，等待命中下一笔真实被接纳样本
	wire flag_test_calibration_loss_active; // 本笔样本被验证注入强制标记为未校准

	//---------------编码信号---------------//
	// 中心样本身份按照输出高段顺序形成原子上下文
	wire [CONTEXT_WIDTH - 1:0]enc_center_context; // 按输出顺序打包中心身份快照

	//---------------译码信号---------------//
	// 当前输入颜色选择历史，组合形成新21点窗口和质量属性
	wire [HISTORY_WIDTH - 1:0]dec_selected_history; // 当前颜色的完整21点旧历史
	wire [SAMPLE_WIDTH - 1:0]dec_sample_input; // 当前粗结果及元数据的原子打包值
	wire [WINDOW_DATA_WIDTH - 1:0]dec_window_data; // 当前输入与旧20点构成的新计算窗口
	wire [19:0]dec_old_qualification;       // 旧20点正式资格向量
	wire [19:0]dec_old_saturation_low;      // 旧20点负向饱和属性向量
	wire [19:0]dec_old_saturation_high;     // 旧20点正向饱和属性向量
	wire [20:0]dec_window_qualification;    // 新窗口全部单点资格向量
	wire [20:0]dec_window_saturation_low;   // 新窗口全部低侧诊断向量
	wire [20:0]dec_window_saturation_high;  // 新窗口全部高侧诊断向量

	// 中心身份固定读取旧tap9，对应加入当前样本后的x[n-10]
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_center_config_epoch; // 中心样本ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_center_coef_epoch; // 中心样本Stage1系数组版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_center_dc_recovery_epoch; // 中心样本DC恢复版本
	wire dec_center_precision_mode;         // 中心样本9/15-bit身份
	wire [C_FRAME_ID_WIDTH - 1:0]dec_center_frame_id; // 中心样本PPG帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_center_sample_index; // 中心样本事务编号
	wire dec_center_color_ir;               // 中心样本颜色属性
	wire [1:0]dec_center_frame_type;        // 中心样本NORMAL类别
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_center_amb_code; // 中心样本AMB码快照
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_center_dc_code; // 中心样本颜色DC码快照
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_center_amb_epoch; // 中心样本AMB提交版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_center_dc_epoch; // 中心颜色抵消码提交代次
	// 单乘法器操作数由MAC项号选择，乘积显式扩展后进入42-bit累加器
	reg signed [24:0]dec_mac_operand;       // 当前对称样本和或中心样本扩展值
	reg signed [15:0]dec_mac_coefficient;   // 当前Q15固定系数
	wire signed [40:0]dec_mac_product;      // 25-bit操作数乘16-bit系数的共享乘积
	wire signed [41:0]dec_mac_product_ext;  // 乘积符号扩展到累加工作域
	// 最终累加值在43-bit幅值域执行对称舍入和显式24-bit端点保护
	wire signed [42:0]dec_accumulator_ext;  // 为最负累加值取绝对值增加保护位
	wire signed [42:0]dec_accumulator_magnitude; // 非负Q15累加幅值
	wire signed [42:0]dec_round_work;       // 加入16384后的舍入工作量
	wire signed [42:0]dec_rounded_magnitude; // 右移15位后的非负整数幅值
	wire signed [42:0]dec_rounded_code;     // 恢复原符号后的整数结果
	wire signed [23:0]dec_filtered_value;   // 显式端点保护后的24-bit输出
	wire [OUTPUT_WIDTH - 1:0]dec_commit_payload; // 提交阶段形成的完整输出载荷

	//---------------其他信号---------------//
	// 常量展开索引只用于生成旧20点窗口抽取连线
	genvar gen_window_index;                // 展开旧历史数值与质量属性的固定索引

	//---------------输出信号---------------//
	// 单元素输出缓存独立保存事务载荷和所有权
	reg [OUTPUT_WIDTH - 1:0]payload_o;      // 已计算的完整粗检测输出载荷
	reg result_valid_o;                     // 当前输出载荷尚未被下游消费

	//-------------其他信号连线-------------//
	// ready只在MAC空闲且输出缓冲可写时允许接纳一笔新事务
	assign flag_buffer_available = (result_valid_o == 1'b0) || i_result_ready; // 支持消费旧输出的同沿接纳
	assign flag_input_transfer = i_result_valid && o_result_ready; // 定义上游事务唯一接纳事件
	assign flag_history_transfer = flag_input_transfer && i_sample_valid && i_coarse_valid && (i_frame_type == 2'b10); // invalid事务仍握手但不得进入两色历史; @satisfies: FIR-19, FIR-31, FIR-32, FIR-33
	assign flag_output_transfer = result_valid_o && i_result_ready; // 定义下游事务唯一消费事件
	assign flag_compute_start = flag_history_transfer && (cnt_selected_sample >= 5'd20); // 当前样本补齐21点窗口; @satisfies: FIR-02, FIR-03
	assign o_test_calibration_loss_inject_ready = (C_ENABLE_TEST_INJECTION != 32'd0) && i_test_inject_enable && i_rstn && !flag_test_calibration_loss_armed; // 没有其它注入pending时才ready；PRC-09/10专属新注入端口,2026-08-31新增并当日闭环 @satisfies: PRC-09, PRC-10
	assign flag_test_calibration_loss_inject_fire = (C_ENABLE_TEST_INJECTION != 32'd0) && i_test_inject_enable && i_test_calibration_loss_inject_valid && o_test_calibration_loss_inject_ready; // ready/valid唯一接纳一次calibration-loss注入
	assign flag_test_calibration_loss_active = flag_input_transfer && (flag_test_calibration_loss_armed || flag_test_calibration_loss_inject_fire); // 命中已绑定的下一笔样本，或注入请求和真实样本同拍接纳
	assign flag_sample_qualified = i_sample_valid && (i_coarse_recovery_calibrated) && (i_stage1_saturation_low == 1'b0) && (i_stage1_saturation_high == 1'b0) && (i_coarse_saturation_low == 1'b0) && (i_coarse_saturation_high == 1'b0); // 汇总单点正式资格，字面对齐合同7.3公式顺序，验证注入生效时强制本笔calibration资格为0; @satisfies: FIR-17, FIR-32
	assign flag_sample_saturation_low = i_stage1_saturation_low || i_coarse_saturation_low; // 合并任一级负向端点信息
	assign flag_sample_saturation_high = i_stage1_saturation_high || i_coarse_saturation_high; // 合并任一级正向端点信息
	assign flag_window_qualified = &dec_window_qualification; // 仅全21点合格时允许正式检测
	assign flag_window_saturation_low = |dec_window_saturation_low; // 保留窗口任一点低侧诊断；高幅度/clamp输入正确置位窗口负向饱和诊断 @satisfies: PRC-03, FIR-18
	assign flag_window_saturation_high = |dec_window_saturation_high; // 保留窗口任一点高侧诊断；高幅度/clamp输入正确置位窗口正向饱和诊断 @satisfies: PRC-03
	assign flag_process_timeout = (state_current != ST_IDLE) && (cnt_process_cycle >= 5'd15); // 第16处理周期仍未结束则撤销事务
	assign flag_commit_event = (state_current == ST_COMMIT) && (flag_process_timeout == 1'b0); // 正常提交阶段生成结果
	assign flag_fir_idle = (state_current == ST_IDLE) && (result_valid_o == 1'b0) && (flag_input_transfer == 1'b0); // 当前输入沿也必须排空; @satisfies: FIR-24
	assign flag_recheck_clear = i_recheck_accept_event && flag_fir_idle; // 危险时刻的重检accept被安全忽略；RRC-04/RRC-09 accept原子清零RED/IR历史深度，成功恢复后必须各自重新累计21笔新样本才能恢复正式检测资格；NRE-02 interval=0时i_recheck_accept_event结构性恒为0，本行永不触发，FIR历史不受重检驱动清零 @satisfies: RRC-04, RRC-09, NRE-02, FIR-13, FIR-26
	assign flag_history_clear = i_start_ack_event || (i_detection_discard_event && (i_detection_discard_run_generation == i_run_generation)) || flag_recheck_clear; // 汇总两色历史重建来源; @satisfies: FIR-11, FIR-12, FIR-16, FIR-25
	assign flag_transaction_clear = flag_history_clear || flag_process_timeout; // 超时只撤销计算而不清历史; @satisfies: FIR-30

	// 当前颜色选择对应打包历史和真实样本计数
	assign dec_selected_history = i_color_ir ? reg_ir_history : reg_red_history; // 读取本笔颜色的旧窗口; @satisfies: FIR-08
	assign cnt_selected_sample = i_color_ir ? cnt_ir_sample : cnt_red_sample; // 读取本笔颜色预热深度
	assign dec_sample_input = {             // 原子打包当前真实样本的数值、资格和身份
		i_dc_code_epoch,
		i_amb_code_epoch,
		i_dc_code_snapshot,
		i_amb_code_snapshot,
		i_frame_type,
		i_color_ir,
		i_sample_index,
		i_frame_id,
		i_precision_mode,
		i_dc_recovery_coef_epoch,
		i_coef_epoch,
		i_config_epoch,
		flag_sample_saturation_high,
		flag_sample_saturation_low,
		flag_sample_qualified,
		i_coarse_ppg_value
	};                                      // 形成固定SAMPLE_WIDTH位单点记录
	// 当前输入位于x[n]，旧tap0至tap19依次对应x[n-1]至x[n-20]
	assign dec_window_data[23:0] = i_coarse_ppg_value; // 新窗口最低段保存当前样本x[n]
	assign dec_window_qualification = {dec_old_qualification, flag_sample_qualified}; // 当前点与旧20点组成完整资格向量
	assign dec_window_saturation_low = {dec_old_saturation_low, flag_sample_saturation_low}; // 当前低侧属性加入窗口归约
	assign dec_window_saturation_high = {dec_old_saturation_high, flag_sample_saturation_high}; // 当前高侧属性加入窗口归约

	// 新窗口中心x[n-10]在输入握手前对应旧历史tap9
	assign dec_center_config_epoch = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + CONFIG_EPOCH_LSB +: C_CONFIG_EPOCH_WIDTH]; // 读取中心ACTIVE版本
	assign dec_center_coef_epoch = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + COEF_EPOCH_LSB +: C_COEF_EPOCH_WIDTH]; // 提取中心样本对应的Stage1系数组代次
	assign dec_center_dc_recovery_epoch = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + DC_RECOVERY_EPOCH_LSB +: C_DC_RECOVERY_EPOCH_WIDTH]; // 读取中心恢复版本
	assign dec_center_precision_mode = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + PRECISION_MODE_LSB]; // 读取中心精度身份; @satisfies: FIR-10, FIR-29
	assign dec_center_frame_id = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + FRAME_ID_LSB +: C_FRAME_ID_WIDTH]; // 读取中心帧号
	assign dec_center_sample_index = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH]; // 读取中心事务号
	assign dec_center_color_ir = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + COLOR_IR_LSB]; // 读取中心颜色位
	assign dec_center_frame_type = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + FRAME_TYPE_LSB +: 2]; // 读取中心NORMAL类别
	assign dec_center_amb_code = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + AMB_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 读取中心AMB码
	assign dec_center_dc_code = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + DC_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 读取中心颜色DC码
	assign dec_center_amb_epoch = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + AMB_CODE_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 读取中心AMB提交版本
	assign dec_center_dc_epoch = dec_selected_history[(SAMPLE_WIDTH * 32'd9) + DC_CODE_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 提取中心颜色抵消码的提交代次
	assign enc_center_context = {           // 按输出高段顺序冻结中心样本身份
		dec_center_dc_epoch,
		dec_center_amb_epoch,
		dec_center_dc_code,
		dec_center_amb_code,
		dec_center_frame_type,
		dec_center_color_ir,
		dec_center_sample_index,
		dec_center_frame_id,
		dec_center_precision_mode,
		dec_center_dc_recovery_epoch,
		dec_center_coef_epoch,
		dec_center_config_epoch
	};                                      // 形成固定CONTEXT_WIDTH位中心快照

	// 单乘法表达式与对称舍入路径组合形成待提交结果
	assign dec_mac_product = dec_mac_operand * dec_mac_coefficient; // 单个乘法表达式形成周期共享乘法器
	assign dec_mac_product_ext = {dec_mac_product[40], dec_mac_product}; // 乘积扩展到42-bit累加域; @satisfies: FIR-27
	assign dec_accumulator_ext = {reg_accumulator[41], reg_accumulator}; // 增加最负数绝对值保护位; @satisfies: FIR-07
	assign dec_accumulator_magnitude = dec_accumulator_ext[42] ? -dec_accumulator_ext : dec_accumulator_ext; // 得到非负Q15幅值
	assign dec_round_work = dec_accumulator_magnitude + ROUND_HALF; // 加入16384实现半LSB远离零; @satisfies: FIR-06
	assign dec_rounded_magnitude = dec_round_work >>> 15; // Q15幅值换算回统一整数码; @satisfies: FIR-04
	assign dec_rounded_code = dec_accumulator_ext[42] ? -dec_rounded_magnitude : dec_rounded_magnitude; // 恢复原始结果符号
	assign flag_fir_saturation_low = dec_rounded_code < FIR_CODE_MIN; // 检查负向24-bit端点
	assign flag_fir_saturation_high = dec_rounded_code > FIR_CODE_MAX; // 检查正向24-bit端点
	assign dec_filtered_value = flag_fir_saturation_low ? 24'sh800000 : (flag_fir_saturation_high ? 24'sh7fffff : dec_rounded_code[23:0]); // 显式输出饱和
	assign dec_commit_payload = {           // 原子组合中心身份、结果诊断和滤波数值
		reg_context_snapshot,
		flag_fir_saturation_high,
		flag_fir_saturation_low,
		reg_window_status[2],
		reg_window_status[1],
		reg_window_status[0],
		dec_filtered_value
	};                                      // 输出字段顺序与端口解包顺序一致

	//-------------输出信号连线-------------//
	// 输入ready和安全idle均显式观察周期MAC状态
	assign o_result_ready = i_rstn && i_run_enable && (i_recheck_busy == 1'b0) && (state_current == ST_IDLE) && flag_buffer_available; // 仅空闲时接纳输入; @satisfies: FIR-14, FIR-21
	assign o_result_valid = result_valid_o; // 桥接保持型输出所有权
	assign o_filtered_ppg_value = payload_o[FILTERED_VALUE_LSB +: 24]; // 解包signed 24-bit滤波值
	assign o_detection_qualified = payload_o[DETECTION_QUALIFIED_LSB]; // 解包全窗口正式资格
	assign o_window_saturation_low = payload_o[WINDOW_SATURATION_LOW_LSB]; // 解包窗口负向端点诊断
	assign o_window_saturation_high = payload_o[WINDOW_SATURATION_HIGH_LSB]; // 解包窗口正向端点诊断
	assign o_fir_saturation_low = payload_o[FIR_SATURATION_LOW_LSB]; // 解包FIR负向端点诊断
	assign o_fir_saturation_high = payload_o[FIR_SATURATION_HIGH_LSB]; // 解包FIR正向端点诊断
	assign o_history_full_r = cnt_red_sample >= 5'd21; // 红光累计21笔后导出满窗状态
	assign o_history_full_ir = cnt_ir_sample >= 5'd21; // 红外累计21笔后导出满窗状态
	assign o_fir_idle = flag_fir_idle;      // 导出供AMB安全接管使用的排空状态
	assign o_local_empty = flag_fir_idle;   // MAC、输出保持槽和当前输入沿均排空时报告本地排空
	// 中心元数据与滤波结果共用一个输出寄存器，反压期间逐位保持
	assign o_config_epoch = payload_o[OUTPUT_CONFIG_EPOCH_LSB +: C_CONFIG_EPOCH_WIDTH]; // 解包中心ACTIVE版本
	assign o_coef_epoch = payload_o[OUTPUT_COEF_EPOCH_LSB +: C_COEF_EPOCH_WIDTH]; // 解包中心Stage1校准代次
	assign o_dc_recovery_coef_epoch = payload_o[OUTPUT_DC_RECOVERY_EPOCH_LSB +: C_DC_RECOVERY_EPOCH_WIDTH]; // 解包中心恢复版本
	assign o_precision_mode = payload_o[OUTPUT_PRECISION_MODE_LSB]; // 解包中心精度模式
	assign o_frame_id = payload_o[OUTPUT_FRAME_ID_LSB +: C_FRAME_ID_WIDTH]; // 解包中心帧号
	assign o_sample_index = payload_o[OUTPUT_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH]; // 解包中心事务号
	assign o_color_ir = payload_o[OUTPUT_COLOR_IR_LSB]; // 解包输出颜色身份
	assign o_frame_type = payload_o[OUTPUT_FRAME_TYPE_LSB +: 2]; // 解包中心NORMAL类别
	assign o_amb_code_snapshot = payload_o[OUTPUT_AMB_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 解包中心AMB码快照
	assign o_dc_code_snapshot = payload_o[OUTPUT_DC_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 解包中心颜色DC码
	assign o_amb_code_epoch = payload_o[OUTPUT_AMB_CODE_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 导出中心样本使用的AMB码代次
	assign o_dc_code_epoch = payload_o[OUTPUT_DC_CODE_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解包中心DC提交代次

	//-----------输出信号处理区域-----------//
	// 输出载荷只在提交阶段更新，消费和生命周期清理恢复确定空值
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			payload_o <= {OUTPUT_WIDTH{1'b0}}; // 异步复位清除旧输出载荷
		end else if(flag_history_clear == 1'b1)begin
			payload_o <= {OUTPUT_WIDTH{1'b0}}; // 生命周期或安全重检删除旧事务
		end else if(flag_commit_event == 1'b1)begin
			payload_o <= dec_commit_payload; // 原子提交滤波结果与中心身份
		end else if(flag_output_transfer == 1'b1)begin
			payload_o <= {OUTPUT_WIDTH{1'b0}}; // 消费完成后恢复空载荷
		end else begin
			payload_o <= payload_o;         // 下游反压期间保持全部字段; @satisfies: FIR-20
		end
	end

	// 输出valid在提交时建立所有权，生命周期事件优先撤销旧结果
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			result_valid_o <= 1'b0;         // 复位后禁止伪输出事务; @satisfies: FIR-01
		end else if(flag_history_clear == 1'b1)begin
			result_valid_o <= 1'b0;         // START、STOP、abort或重检撤销输出
		end else if(flag_commit_event == 1'b1)begin
			result_valid_o <= 1'b1;         // 完整MAC结果建立保持型valid
		end else if(flag_output_transfer == 1'b1)begin
			result_valid_o <= 1'b0;         // 唯一握手后释放输出所有权
		end else begin
			result_valid_o <= result_valid_o; // 无握手时逐拍保持valid
		end
	end

	//--------验证专用异常注入处理区域--------//
	// 一次性绑定寄存器，命中下一笔真实样本或历史被清空时自动撤销
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_test_calibration_loss_armed <= 1'b0; // 异步复位清除已锁存的注入绑定
		end else if(flag_test_calibration_loss_active == 1'b1)begin
			flag_test_calibration_loss_armed <= 1'b0; // 已命中真实样本，一次性生效后自动撤销
		end else if(flag_history_clear == 1'b1)begin
			flag_test_calibration_loss_armed <= 1'b0; // 命中前历史被清空，撤销未绑定请求
		end else if(flag_test_calibration_loss_inject_fire == 1'b1)begin
			flag_test_calibration_loss_armed <= 1'b1; // 原子绑定，等待下一笔真实样本
		end else begin
			flag_test_calibration_loss_armed <= flag_test_calibration_loss_armed; // 无新事件时保持当前绑定状态
		end
	end

	//----------------状态机区域----------------//
	// 三段式FSM组合逻辑只决定下一计算阶段
	always@(*)begin
		state_next = state_current;             // 默认保持当前阶段
		if(flag_process_timeout == 1'b1)begin
			state_next = ST_IDLE;               // 超时保护直接撤销在途计算
		end else begin
			case(state_current)
				ST_IDLE:begin
					if(flag_compute_start == 1'b1)begin
						state_next = ST_MAC;    // 满21点输入启动周期乘加
					end
				end
				ST_MAC:begin
					if(cnt_mac_index == 4'd10)begin
						state_next = ST_COMMIT; // 中心项完成后进入提交阶段; @satisfies: FIR-23
					end
				end
				ST_COMMIT:begin
					state_next = ST_IDLE;       // 单拍提交后恢复输入许可
				end
				default:begin
					state_next = ST_IDLE;       // 非法编码回到安全空闲状态
				end
			endcase
		end
	end

	// 状态寄存器在生命周期、重检和超时时统一返回空闲
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_IDLE;           // 异步复位禁止任何在途MAC
		end else if(flag_transaction_clear == 1'b1)begin
			state_current <= ST_IDLE;           // 所有撤销事件回到安全空闲阶段
		end else begin
			state_current <= state_next;        // 正常推进周期MAC状态
		end
	end

	//-------------状态任务处理区域-------------//
	// 42-bit累加器在第一个MAC周期装入乘积，后续十项逐拍相加
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_accumulator <= 42'sd0;          // 复位清除部分乘加结果
		end else if(flag_transaction_clear == 1'b1)begin
			reg_accumulator <= 42'sd0;          // STOP、abort、重检或超时撤销累加
		end else if(state_current == ST_MAC)begin
			if(cnt_mac_index == 4'd0)begin
				reg_accumulator <= dec_mac_product_ext; // 首项建立精确累加起点
			end else begin
				reg_accumulator <= reg_accumulator + dec_mac_product_ext; // 后续项保持42-bit求和
			end
		end else if(flag_commit_event == 1'b1)begin
			reg_accumulator <= 42'sd0;          // 输出提交后准备下一笔事务
		end else begin
			reg_accumulator <= reg_accumulator; // 非MAC周期保持最终和
		end
	end

	// MAC项号从0递增到10，提交或撤销后返回起点
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_mac_index <= 4'd0;              // 复位从最外层对称项开始
		end else if(flag_transaction_clear == 1'b1)begin
			cnt_mac_index <= 4'd0;              // 异常终止释放项号状态
		end else if(flag_compute_start == 1'b1)begin
			cnt_mac_index <= 4'd0;              // 新窗口准备执行第零项
		end else if(state_current == ST_MAC && cnt_mac_index < 4'd10)begin
			cnt_mac_index <= cnt_mac_index + 4'd1; // 每个MAC周期推进一个固定项; @satisfies: FIR-22
		end else if(flag_commit_event == 1'b1)begin
			cnt_mac_index <= 4'd0;              // 正常提交后恢复初始项号
		end else begin
			cnt_mac_index <= cnt_mac_index;     // 中心项和空闲阶段保持
		end
	end

	// 处理周期计数只在在途状态增加，用于固定16周期超时保护
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_process_cycle <= 5'd0;          // 复位时没有计算年龄
		end else if(flag_transaction_clear == 1'b1)begin
			cnt_process_cycle <= 5'd0;          // 撤销事务后清除年龄
		end else if(flag_compute_start == 1'b1)begin
			cnt_process_cycle <= 5'd0;          // 输入握手定义处理周期起点
		end else if(state_current != ST_IDLE)begin
			cnt_process_cycle <= cnt_process_cycle + 5'd1; // 在途周期逐拍累计
		end else begin
			cnt_process_cycle <= 5'd0;          // 空闲状态保持零年龄
		end
	end

	//-----------主要任务处理区域-----------//
	// 当前MAC项选择一组对称样本或中心样本，并提供对应Q15系数
	always@(*)begin
		dec_mac_operand = 25'sd0;           // 非法状态默认乘零防止X扩散
		case(cnt_mac_index)
			4'd0:begin
				dec_mac_operand = $signed({reg_window_data[23], reg_window_data[23:0]}) + $signed({reg_window_data[503], reg_window_data[503:480]}); // 配对x[n]与x[n-20]
			end
			4'd1:begin
				dec_mac_operand = $signed({reg_window_data[47], reg_window_data[47:24]}) + $signed({reg_window_data[479], reg_window_data[479:456]}); // 配对x[n-1]与x[n-19]
			end
			4'd2:begin
				dec_mac_operand = $signed({reg_window_data[71], reg_window_data[71:48]}) + $signed({reg_window_data[455], reg_window_data[455:432]}); // 配对x[n-2]与x[n-18]
			end
			4'd3:begin
				dec_mac_operand = $signed({reg_window_data[95], reg_window_data[95:72]}) + $signed({reg_window_data[431], reg_window_data[431:408]}); // 配对x[n-3]与x[n-17]
			end
			4'd4:begin
				dec_mac_operand = $signed({reg_window_data[119], reg_window_data[119:96]}) + $signed({reg_window_data[407], reg_window_data[407:384]}); // 配对x[n-4]与x[n-16]
			end
			4'd5:begin
				dec_mac_operand = $signed({reg_window_data[143], reg_window_data[143:120]}) + $signed({reg_window_data[383], reg_window_data[383:360]}); // 配对x[n-5]与x[n-15]
			end
			4'd6:begin
				dec_mac_operand = $signed({reg_window_data[167], reg_window_data[167:144]}) + $signed({reg_window_data[359], reg_window_data[359:336]}); // 配对x[n-6]与x[n-14]
			end
			4'd7:begin
				dec_mac_operand = $signed({reg_window_data[191], reg_window_data[191:168]}) + $signed({reg_window_data[335], reg_window_data[335:312]}); // 配对x[n-7]与x[n-13]
			end
			4'd8:begin
				dec_mac_operand = $signed({reg_window_data[215], reg_window_data[215:192]}) + $signed({reg_window_data[311], reg_window_data[311:288]}); // 配对x[n-8]与x[n-12]
			end
			4'd9:begin
				dec_mac_operand = $signed({reg_window_data[239], reg_window_data[239:216]}) + $signed({reg_window_data[287], reg_window_data[287:264]}); // 配对x[n-9]与x[n-11]
			end
			4'd10:begin
				dec_mac_operand = $signed({reg_window_data[263], reg_window_data[263:240]}); // 扩展中心x[n-10]
			end
			default:begin
				dec_mac_operand = 25'sd0;   // 非法项号保持安全零操作数
			end
		endcase
	end

	// 当前MAC项号独立译码固定Q15系数，避免组合过程同时驱动两个目标
	always@(*)begin
		dec_mac_coefficient = 16'sd0;       // 非法项号默认不改变累加结果
		case(cnt_mac_index)
			4'd0:begin
				dec_mac_coefficient = 16'sd164; // 选择最外层Q15系数; @satisfies: FIR-05, FIR-28
			end
			4'd1:begin
				dec_mac_coefficient = 16'sd231; // 选择第二层固定系数
			end
			4'd2:begin
				dec_mac_coefficient = 16'sd409; // 选择第三层固定系数
			end
			4'd3:begin
				dec_mac_coefficient = 16'sd704; // 选择第四层固定系数
			end
			4'd4:begin
				dec_mac_coefficient = 16'sd1100; // 选择第五层固定系数
			end
			4'd5:begin
				dec_mac_coefficient = 16'sd1566; // 选择第六层固定系数
			end
			4'd6:begin
				dec_mac_coefficient = 16'sd2056; // 选择第七层固定系数
			end
			4'd7:begin
				dec_mac_coefficient = 16'sd2515; // 选择第八层固定系数
			end
			4'd8:begin
				dec_mac_coefficient = 16'sd2891; // 选择第九层固定系数
			end
			4'd9:begin
				dec_mac_coefficient = 16'sd3136; // 选择中心外侧固定系数
			end
			4'd10:begin
				dec_mac_coefficient = 16'sd3224; // 选择中心Q15系数
			end
			default:begin
				dec_mac_coefficient = 16'sd0; // 非法项号禁止累加新数值
			end
		endcase
	end

	// 红光历史在首笔样本时预填物理存储，但真实计数仍只增加一次
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_red_history <= {HISTORY_WIDTH{1'b0}}; // 异步复位清除红光全部tap
		end else if(flag_history_clear == 1'b1)begin
			reg_red_history <= {HISTORY_WIDTH{1'b0}}; // 生命周期边界重建红光历史
		end else if(flag_history_transfer == 1'b1 && i_color_ir == 1'b0)begin
			if(cnt_red_sample == 5'd0)begin
				reg_red_history <= {21{dec_sample_input}}; // 首笔只预填物理值而不伪造满窗
			end else begin
				reg_red_history <= {reg_red_history[HISTORY_WIDTH - SAMPLE_WIDTH - 1:0], dec_sample_input}; // 新样本进入tap0
			end
		end else begin
			reg_red_history <= reg_red_history; // 红外事务和空拍不改变红光状态
		end
	end

	// 红外历史独立移位，颜色交错不会污染红光窗口
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_ir_history <= {HISTORY_WIDTH{1'b0}}; // 异步复位清除红外全部tap
		end else if(flag_history_clear == 1'b1)begin
			reg_ir_history <= {HISTORY_WIDTH{1'b0}}; // 生命周期边界重建红外历史
		end else if(flag_history_transfer == 1'b1 && i_color_ir == 1'b1)begin
			if(cnt_ir_sample == 5'd0)begin
				reg_ir_history <= {21{dec_sample_input}}; // 首笔红外样本预填全部物理tap
			end else begin
				reg_ir_history <= {reg_ir_history[HISTORY_WIDTH - SAMPLE_WIDTH - 1:0], dec_sample_input}; // 红外新值进入tap0
			end
		end else begin
			reg_ir_history <= reg_ir_history; // 红光事务和反压周期保持红外窗口
		end
	end

	// 红光真实样本计数饱和到21，普通精度切换不会触发清零
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_red_sample <= 5'd0;         // 复位时红光尚无真实样本
		end else if(flag_history_clear == 1'b1)begin
			cnt_red_sample <= 5'd0;         // 重检或生命周期事件撤销预热资格；NRE-03 flag_history_clear的重检分支interval=0时结构性恒为0，红光预热深度只沿699行单调递增至满窗，中途不下降 @satisfies: NRE-03, FIR-15
		end else if(flag_history_transfer == 1'b1 && i_color_ir == 1'b0 && cnt_red_sample < 5'd21)begin
			cnt_red_sample <= cnt_red_sample + 5'd1; // 每笔红光NORMAL事务只累计一次
		end else begin
			cnt_red_sample <= cnt_red_sample; // 红外事务和满窗状态保持计数
		end
	end

	// 红外真实样本计数独立累计，慢速DC调码不会破坏连续性
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_ir_sample <= 5'd0;          // 复位时红外历史为空
		end else if(flag_history_clear == 1'b1)begin
			cnt_ir_sample <= 5'd0;          // 安全重检同步撤销红外资格；NRE-03 同一flag_history_clear重检分支interval=0时结构性恒为0，红外预热深度同样只单调递增至满窗 @satisfies: NRE-03
		end else if(flag_history_transfer == 1'b1 && i_color_ir == 1'b1 && cnt_ir_sample < 5'd21)begin
			cnt_ir_sample <= cnt_ir_sample + 5'd1; // 每笔红外NORMAL事务增加一项真实证据
		end else begin
			cnt_ir_sample <= cnt_ir_sample; // 红光事务或计数饱和时保持
		end
	end

	// 完整21点窗口在输入握手时冻结，后续MAC不再读取活动历史
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_window_data <= {WINDOW_DATA_WIDTH{1'b0}}; // 复位清除计算窗口快照
		end else if(flag_transaction_clear == 1'b1)begin
			reg_window_data <= {WINDOW_DATA_WIDTH{1'b0}}; // 撤销在途事务时删除旧窗口
		end else if(flag_compute_start == 1'b1)begin
			reg_window_data <= dec_window_data; // 原子保存当前21点真实窗口
		end else begin
			reg_window_data <= reg_window_data; // MAC期间保持操作数不变
		end
	end

	// 中心身份快照与数值窗口在同一输入握手边界建立
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_context_snapshot <= {CONTEXT_WIDTH{1'b0}}; // 复位删除中心事务身份
		end else if(flag_transaction_clear == 1'b1)begin
			reg_context_snapshot <= {CONTEXT_WIDTH{1'b0}}; // 终止计算时释放身份快照
		end else if(flag_compute_start == 1'b1)begin
			reg_context_snapshot <= enc_center_context; // 保存x[n-10]完整身份; @satisfies: FIR-09
		end else begin
			reg_context_snapshot <= reg_context_snapshot; // 计算期间保持元数据稳定
		end
	end

	// 窗口资格与饱和诊断在计算开始时锁存，避免依赖后续输入
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_window_status <= 3'b000;    // 复位清除待提交窗口状态
		end else if(flag_transaction_clear == 1'b1)begin
			reg_window_status <= 3'b000;    // 取消事务时删除诊断快照
		end else if(flag_compute_start == 1'b1)begin
			reg_window_status <= {flag_window_saturation_high, flag_window_saturation_low, flag_window_qualified}; // 保存完整窗口属性
		end else begin
			reg_window_status <= reg_window_status; // MAC阶段禁止改变待提交属性
		end
	end

	//---------------生成块区域---------------//
	// 固定索引逐项连接旧历史中的数值、资格与饱和属性
	generate
		// 固定索引逐项连接旧历史中的数值、资格与饱和属性
		for(gen_window_index = 0; gen_window_index < 32'd20; gen_window_index = gen_window_index + 32'd1)begin: GEN_WINDOW_EXTRACT
			assign dec_window_data[(32'd24 * (gen_window_index + 32'd1)) +: 24] = dec_selected_history[(SAMPLE_WIDTH * gen_window_index) + DATA_LSB +: 24]; // 展开对应旧tap数值
			assign dec_old_qualification[gen_window_index] = dec_selected_history[(SAMPLE_WIDTH * gen_window_index) + QUALIFIED_LSB]; // 展开旧点正式资格
			assign dec_old_saturation_low[gen_window_index] = dec_selected_history[(SAMPLE_WIDTH * gen_window_index) + SATURATION_LOW_LSB]; // 展开旧点低侧诊断
			assign dec_old_saturation_high[gen_window_index] = dec_selected_history[(SAMPLE_WIDTH * gen_window_index) + SATURATION_HIGH_LSB]; // 展开旧点高侧诊断
		end
	endgenerate

endmodule
