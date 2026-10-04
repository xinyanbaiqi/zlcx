`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026/08/10 00:00:00
// Design Name: 	PPG Dynamic Baseline Cross Detector
// Module Name: 	ppg_dynamic_baseline_cross_detector
// Description: 	Description/ppg_dynamic_baseline_cross_detector_Design.pdf
// Dependencies:
// ppg_coarse_detection_fir.v,
// ppg_peak_valley_window_detector.v
// ppg_coarse_detection_fir.v、
// Simulations:		TestBench/Vivado/2022.2/ppg_dynamic_baseline_cross_detector
//
// Referrences:		PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md
//
//
// Version:			V1.4
// Revision Date:	2026/08/27
// History:
//    Time			   Version	   Revised by			Contents
// 2026/08/10            V1.0          Erie                  Create file.
// 2026/08/22            V1.1          Erie                  Remove i_stop_ack_event/i_control_abort_event direct-clear ports; add PWI-broadcast i_detection_discard group, i_run_generation and o_local_empty per PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md section 14.1.
// 2026/08/22            V1.2          Erie                  Add i_peak_valley_config_valid (V5 formal-detection gate) per PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md section 14.4; gate below_seen arming and cross emission on it.
// 2026/08/23            V1.3          Erie                  Close the section 14.4 gating gap: also gate flag_candidate_start/flag_candidate_continue on i_peak_valley_config_valid so cross-confirmation counting and reg_candidate_context latching cannot advance while the V5 gate is low.
// 2026/08/27            V1.4          Erie                  Cosmetic-only fix: PPG_Q16_MAX/PPG_Q16_MIN's sized hex literals each carried 2 redundant leading "00" hex digits (14 hex digits given for a 48-bit/12-digit localparam), the source of iverilog -Wall's long-standing "extra digits given for sized hex constant" warning surfaced repeatedly across Stage 5's joint-verification TBs. Hand-verified against the comment-stated intent (signed 24-bit Q16 endpoints, 0x7FFFFF0000/-0x8000000000) and IEEE 1364's mandated truncate-from-the-MSB-side rule for over-specified sized literals: the low-order 12 hex digits the standard keeps were already numerically correct, so this was a pure literal-width-matching cleanup with zero semantic change, not a bug fix. Verified with real iverilog: this file alone compiles -Wall-clean; re-ran both ppg_control_top/tb_ppg_control_top.v (SMOKE_TB_PASS real_adc_responses=47 measurement_result_valid=32, identical to prior documented runs) and ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v (STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2, identical to its own prior run) end to end -- both reproduce their previously-recorded PASS numbers exactly, confirming zero behavioral change. Note: this module's own tb_ppg_dynamic_baseline_cross_detector.v is separately stale (still wires i_stop_ack_event/i_control_abort_event, removed in V1.1) and could not be used for this regression -- a pre-existing gap, out of scope here, not touched.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026年08月10日
// 设计名称: 		PPG Dynamic Baseline Cross Detector
// 模块名称: 		ppg_dynamic_baseline_cross_detector
// 模块说明:		Description/ppg_dynamic_baseline_cross_detector_Design.pdf
// 依赖文件:
// ppg_coarse_detection_fir.v,
// ppg_peak_valley_window_detector.v
// ppg_coarse_detection_fir.v、
// 仿真工程: 		TestBench/Vivado/2022.2/ppg_dynamic_baseline_cross_detector
//
// 参考资料:		PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.4
// 修订日期:		2026年08月27日
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026年08月10日        V1.0          Erie                  创建文件
// 2026年08月22日        V1.1          Erie                  删除i_stop_ack_event/i_control_abort_event直接清除端口，按合同14.1节新增PWI广播的i_detection_discard组、i_run_generation和o_local_empty
// 2026年08月22日        V1.2          Erie                  按合同14.4节新增i_peak_valley_config_valid（V5正式检测门控），并用它限定below_seen武装与相交发布
// 2026年08月23日        V1.3          Erie                  补齐合同14.4节门控缺口——flag_candidate_start/flag_candidate_continue同样接入i_peak_valley_config_valid，V5资格无效期间不得推进连续确认计数或锁存reg_candidate_context候选身份
// 2026年08月27日        V1.4          Erie                  纯规范化修复，不改数值语义：PPG_Q16_MAX/PPG_Q16_MIN的十六进制字面量各自多写了2个前导"00"字符（48-bit/12位localparam却给了14位十六进制），这就是iverilog -Wall里那条长期存在、Stage5多个联合验证TB反复观察到的"extra digits given for sized hex constant"警告的直接来源。按注释语义（signed 24-bit的Q16端点，0x7FFFFF0000/-0x8000000000）手工核算，并对照IEEE 1364规定的"过量位数sized字面量按标准从最高位截断，保留最低位"规则：标准截断后保留的低12位十六进制本来就是数值正确的，所以这纯粹是字面量位数和声明宽度不匹配的书写清理，不是数值bug修复。真实iverilog核实：本文件单独编译-Wall已完全干净；完整重跑了ppg_control_top/tb_ppg_control_top.v（SMOKE_TB_PASS real_adc_responses=47 measurement_result_valid=32，和此前已记录的历史跑分完全一致）和ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v（STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2，和它自己此前的跑分完全一致）——两者都精确复现了此前已记录的PASS数字，确认零行为变化。备注：本模块自己的tb_ppg_dynamic_baseline_cross_detector.v另有历史遗留的过期问题（还在给已在V1.1删除的i_stop_ack_event/i_control_abort_event接线），本轮回归无法用它，是范围外的既有缺口，本轮未处理
// 使用RED粗滤波码值建立负斜率动态基线，并在连续向上穿越后请求下一安全帧进入15-bit
module ppg_dynamic_baseline_cross_detector
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16, // 全局400 Hz中心帧编号宽度
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // ADC事务中心序号字段宽度
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // ACTIVE配置版本字段宽度
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8, // Stage1校准系数版本宽度
	parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8, // DC恢复系数版本字段宽度
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // discard组诊断用AMB/DC码版本字段宽度
	parameter integer C_SLOPE_WIDTH = 32'd32,   // signed Q16活动斜率字段宽度
	parameter integer C_BASELINE_WIDTH = 32'd48, // signed Q16基线运算字段宽度
	parameter integer C_RATIO_WIDTH = 32'd16,   // unsigned Q1.15比例字段宽度
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8 // manager唯一生产、由PWI逐层广播的RUN代际字段宽度
)
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 2 MHz数字处理域工作时钟
	input i_rstn,                               // 低有效异步复位输入

	//---------------生命周期接口---------------//
	input i_run_enable,                         // RUN状态允许接受正式检测事务
	input i_start_ack_event,                    // 新RUN接受后装载固定斜率种子
	input i_fine_window_active,                 // 当前已经处于15-bit精度采集窗口
	input i_reacquire_request_event,            // 异常返回9-bit后废止旧基线并重新获取
	input i_recheck_accept_event,               // AMB/DC周期重检实际完成安全接管
	input i_recheck_busy,                       // 重检与FIR预热期间禁止正式样本进入
	input i_recheck_done_event,                 // 三帧重检序列结束的单周期事件
	input i_recheck_success,                    // 与重检结束同拍给出的整体成功资格

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
	input [C_CODE_EPOCH_WIDTH - 1:0]i_detection_discard_dc_code_epoch, // 触发事务颜色DC码版本，仅诊断用途
	input [C_RUN_GENERATION_WIDTH - 1:0]i_detection_discard_run_generation, // 本次清空目标RUN代际
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // PWI层级扇出的当前RUN代际实时快照
	output o_local_empty,                  // 本模块无pending、无输出且无在途算术时为高，唯一消费者PWI

	//--------------粗FIR事务接口---------------//
	input i_result_valid,                       // 检测fork分支保持的粗FIR事务valid
	output o_result_ready,                      // 本模块允许上游消费当前FIR事务
	input signed [23:0]i_filtered_ppg_value,    // 与PD接收光强正相关的统一PPG粗码
	input i_detection_qualified,                // FIR窗口完整且具备正式检测资格
	input i_window_saturation_low,              // FIR输入窗口包含负向端点样本
	input i_window_saturation_high,             // FIR输入窗口包含正向端点样本
	input i_fir_saturation_low,                 // 当前FIR结果触及signed 24-bit低端
	input i_fir_saturation_high,                // 当前FIR结果触及signed 24-bit高端
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 中心样本绑定的ACTIVE版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 中心样本采用的Stage1系数组版本
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_dc_recovery_coef_epoch, // 中心样本采用的DC恢复版本
	input i_precision_mode,                     // FIR中心历史精度，低电平才允许建立新相交
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id,   // FIR中心样本的400 Hz帧号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // FIR中心样本的全局事务号
	input i_color_ir,                           // 低更新RED检测状态，高仅消费IR事务
	input [1:0]i_frame_type,                    // 正式检测事务固定使用NORMAL编码10

	//---------------波峰事件接口---------------//

	//PEAK接口
	input i_peak_valid,                         // 峰谷检测器保持的可靠码值波峰事件
	output o_peak_ready,                        // 本模块允许消费新的RED波峰锚点
	input signed [23:0]i_peak_value,            // Stage1粗FIR确认的原始码值波峰
	input [C_FRAME_ID_WIDTH - 1:0]i_peak_frame_id, // 波峰实际发生的中心帧编号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_peak_sample_index, // 波峰实际对应的事务序号
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_peak_config_epoch, // 波峰事务对应的ACTIVE版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_peak_coef_epoch, // 波峰事务对应的Stage1系数版本
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_peak_dc_recovery_coef_epoch, // 波峰事务对应的DC恢复版本

	//---------------波谷事件接口---------------//

	//VALLEY接口
	input i_valley_valid,                       // 峰谷检测器保持的可靠码值波谷事件
	output o_valley_ready,                      // 本模块允许记录当前周期的运行最小值
	input signed [23:0]i_valley_value,          // Stage1粗FIR确认的原始码值波谷
	input [C_FRAME_ID_WIDTH - 1:0]i_valley_frame_id, // 波谷实际发生的中心帧编号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_valley_sample_index, // 波谷实际对应的事务序号
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_valley_config_epoch, // 波谷事务携带的ACTIVE版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_valley_coef_epoch, // 波谷事务携带的Stage1系数版本
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_valley_dc_recovery_coef_epoch, // 波谷事务携带的DC恢复版本

	//--------------ACTIVE配置接口--------------//
	input i_slope_mode,                         // 低选择SPI固定斜率且高选择自适应更新
	input signed [C_SLOPE_WIDTH - 1:0]i_fixed_slope_q16, // 启动、恢复和固定模式使用的负斜率
	input [C_RATIO_WIDTH - 1:0]i_alpha_q15,     // 峰谷幅度形成基础斜率的Q1.15比例
	input [C_RATIO_WIDTH - 1:0]i_beta_q15,      // 活动斜率靠近基础斜率的Q1.15比例
	input [C_RATIO_WIDTH - 1:0]i_timing_adjust_ratio_q15, // 相交时刻闭环修正的Q1.15相对步长
	input signed [C_SLOPE_WIDTH - 1:0]i_slope_min_q16, // 允许的最负signed Q16斜率边界
	input signed [C_SLOPE_WIDTH - 1:0]i_slope_max_q16, // 最接近零的signed Q16斜率边界
	input signed [C_SLOPE_WIDTH - 1:0]i_baseline_delta_q16, // 波峰锚点处的signed Q16基线偏置
	input [C_SLOPE_WIDTH - 1:0]i_cross_hysteresis_q16, // 相交比较使用的对称Q16迟滞量
	input [C_FRAME_ID_WIDTH - 1:0]i_lead_min_frames, // 允许提前量窗口的最小帧数
	input [C_FRAME_ID_WIDTH - 1:0]i_lead_max_frames, // 允许提前量窗口的最大帧数
	input [3:0]i_cross_confirm_count,           // 包含首次越过点的连续确认样本数
	input [3:0]i_no_cross_limit,                // 连续无相交后重新获取锚点的周期数
	input i_peak_valley_config_valid,           // PWI经AMI注册转发的V5正式检测资格，为0禁止武装/发布正式cross

	//---------------相交事件接口---------------//
	input i_cross_ready,                        // 精度控制器允许消费保持的相交请求
	output o_cross_valid,                       // 完整相交事件已锁存并等待握手
	output [C_FRAME_ID_WIDTH - 1:0]o_cross_frame_id, // 首次越过中心帧或未知事件发现帧
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_cross_sample_index, // 相交候选首次越过对应的事务号
	output o_cross_time_unknown,                // 重检空窗可能已相交的诊断标志
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_cross_config_epoch, // 相交事件绑定的ACTIVE版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_cross_coef_epoch, // 相交事件绑定的Stage1系数版本
	output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_cross_dc_recovery_coef_epoch, // 相交事件绑定的DC恢复版本
	output signed [C_SLOPE_WIDTH - 1:0]o_cross_slope_q16, // 本次比较使用的活动负斜率
	output signed [C_BASELINE_WIDTH - 1:0]o_cross_baseline_q16, // 相交时刻的饱和诊断基线

	//---------------只读状态接口---------------//
	output o_baseline_valid,                    // 当前波峰锚点和斜率可用于比较
	output o_adaptive_slope_valid,              // 至少一个完整周期已更新自适应斜率
	output signed [C_SLOPE_WIDTH - 1:0]o_slope_current_q16, // 当前锚点周期实际使用的signed Q16斜率
	output signed [C_SLOPE_WIDTH - 1:0]o_slope_base_q16, // 最近完整周期计算得到的基础斜率
	output [C_FRAME_ID_WIDTH - 1:0]o_last_lead_frames, // 最近时间已知相交的提前帧数
	output [3:0]o_no_cross_count,               // 连续完整无相交周期累计值
	output o_reacquire_active,                  // 正在等待新的可靠码值波峰锚点
	output o_slope_saturation_min,              // 最近斜率更新触及最负配置边界
	output o_slope_saturation_max,              // 最近斜率更新触及最接近零配置边界
	output o_baseline_saturation_low,           // 最近比较基线低于signed 24-bit端点
	output o_baseline_saturation_high,          // 最近比较基线高于signed 24-bit端点
	output o_protocol_error_sticky              // 配置、帧序或事件顺序错误累计标志
);

	//---------------配置参数区域---------------//
	// 协议编码和定点端点由冻结接口合同统一定义
	localparam [1:0]FRAME_TYPE_NORMAL = 2'b10;  // 正式PPG检测事务类别编码
	localparam SLOPE_MODE_FIXED = 1'b0;         // SPI固定斜率运行方式
	localparam SLOPE_MODE_ADAPTIVE = 1'b1;      // 逐心搏周期自适应斜率方式
	localparam signed [C_BASELINE_WIDTH - 1:0]PPG_Q16_MAX = 48'sh007fffff0000; // signed 24-bit正端点的Q16表示
	localparam signed [C_BASELINE_WIDTH - 1:0]PPG_Q16_MIN = -48'sh008000000000; // signed 24-bit负端点的Q16表示
	localparam [49:0]Q15_ROUND_HALF_50 = 50'd16383; // 50-bit平滑乘积对称舍入的半LSB
	localparam [47:0]Q15_ROUND_HALF_48 = 48'd16384; // 48-bit时刻修正乘积最近舍入的半LSB
	localparam [6:0]C_SLOPE_UPDATE_MAX_CYCLES = 7'd127; // 计数0至127覆盖最多128个算术周期
	localparam [5:0]C_DIVIDE_LAST_ITERATION = 6'd41; // 恢复除法迭代0至41共处理42个被除数位

	// 峰、谷、候选和相交载荷使用原子打包寄存器避免跨字段撕裂
	localparam integer PEAK_CONTEXT_WIDTH = 32'd24 + C_FRAME_ID_WIDTH + C_SAMPLE_INDEX_WIDTH + C_CONFIG_EPOCH_WIDTH + C_COEF_EPOCH_WIDTH + C_DC_RECOVERY_EPOCH_WIDTH; // 波峰锚点上下文总宽度
	localparam integer VALLEY_CONTEXT_WIDTH = PEAK_CONTEXT_WIDTH; // 波谷上下文保持与波峰一致的元数据
	localparam integer EVENT_CONTEXT_WIDTH = C_FRAME_ID_WIDTH + C_SAMPLE_INDEX_WIDTH + C_CONFIG_EPOCH_WIDTH + C_COEF_EPOCH_WIDTH + C_DC_RECOVERY_EPOCH_WIDTH + C_SLOPE_WIDTH + C_BASELINE_WIDTH; // 相交载荷除time_unknown外总宽度
	localparam integer PREVIOUS_CONTEXT_WIDTH = C_FRAME_ID_WIDTH + C_BASELINE_WIDTH + C_BASELINE_WIDTH; // 前一正式样本值、基线和帧号总宽度

	//---------------状态参数区域---------------//
	// 阶段C算术状态将共享乘法、逐位除法、舍入、限幅和原子提交明确分离
	localparam [3:0]ST_IDLE = 4'd0;             // 等待稳定波峰valid并允许普通FIR与波谷事务
	localparam [3:0]ST_CAPTURE = 4'd1;          // 判定快照应走即时路径还是自适应算术路径
	localparam [3:0]ST_MUL_ALPHA = 4'd2;        // 共享乘法器执行正幅度乘alpha
	localparam [3:0]ST_PREPARE_DIVIDE = 4'd3;   // 加入半分母并初始化42-bit恢复除法器
	localparam [3:0]ST_DIVIDE = 4'd4;           // 每周期恢复一位无符号商
	localparam [3:0]ST_BUILD_SLOPE_BASE = 4'd5; // 对完整商取负并执行32-bit防御饱和
	localparam [3:0]ST_MUL_BETA = 4'd6;         // 共享乘法器执行signed斜率差乘beta
	localparam [3:0]ST_ROUND_BETA = 4'd7;       // 对signed平滑乘积执行对称最近舍入
	localparam [3:0]ST_MUL_ADJUST = 4'd8;       // 共享乘法器执行基础斜率幅值乘调整比例
	localparam [3:0]ST_ROUND_ADJUST = 4'd9;     // 舍入调整步长并选择lead修正方向
	localparam [3:0]ST_CLAMP = 4'd10;           // 合成下一斜率并按ACTIVE边界夹紧
	localparam [3:0]ST_WAIT_PEAK_COMMIT = 4'd11; // 算术结果就绪后开放波峰正式握手
	localparam [3:0]ST_TIMEOUT_FALLBACK = 4'd12; // 除零、配置漂移或超时转固定斜率提交

	//-----------------计数信号-----------------//
	reg [3:0]cnt_cross_confirm;                 // 当前候选已经连续位于正迟滞上方的点数
	reg [6:0]cnt_arithmetic_cycles;             // 从波峰快照到可提交状态的有界周期计数
	reg [5:0]cnt_divide_iteration;              // 当前已经执行的42-bit恢复除法位序号
	reg [3:0]cnt_arith_no_cross;                // 捕获时尚未提交的无相交累计值

	//----------------状态机信号----------------//
	reg [3:0]state_current;                     // 阶段C共享算术引擎当前寄存状态
	reg [3:0]state_next;                        // 完整组合译码得到的下一算术状态

	//----------------寄存器信号----------------//
	reg [PEAK_CONTEXT_WIDTH - 1:0]reg_peak_context; // 当前动态基线采用的可靠波峰锚点
	reg [VALLEY_CONTEXT_WIDTH - 1:0]reg_valley_context; // 当前锚点周期已经确认的码值波谷
	reg [EVENT_CONTEXT_WIDTH - 1:0]reg_candidate_context; // 首次向上越过样本的精确事件载荷
	reg [EVENT_CONTEXT_WIDTH - 1:0]reg_cycle_cross_context; // 本周期用于lead计算的已知相交载荷
	reg [PREVIOUS_CONTEXT_WIDTH - 1:0]reg_previous_context; // 相邻正式RED样本的Q16比较上下文
	reg [PEAK_CONTEXT_WIDTH - 1:0]reg_arith_old_peak_context; // 算术启动时冻结的旧波峰锚点与全部epoch
	reg [VALLEY_CONTEXT_WIDTH - 1:0]reg_arith_valley_context; // 算术启动时冻结的本周期波谷证据
	reg [PEAK_CONTEXT_WIDTH - 1:0]reg_arith_new_peak_context; // ready拉低期间由本模块暂时拥有的新波峰载荷
	reg [EVENT_CONTEXT_WIDTH - 1:0]reg_arith_cycle_cross_context; // 算术启动时冻结的本周期精确相交上下文
	reg signed [C_SLOPE_WIDTH - 1:0]reg_arith_slope_current_q16; // 本次平滑运算使用的旧活动斜率快照
	reg signed [C_SLOPE_WIDTH - 1:0]reg_arith_fixed_slope_q16; // 异常回退与即时固定模式使用的斜率快照
	reg [C_RATIO_WIDTH - 1:0]reg_arith_alpha_q15; // 基础斜率幅度比例的事务级快照
	reg [C_RATIO_WIDTH - 1:0]reg_arith_beta_q15; // 逐周期平滑比例的事务级快照
	reg [C_RATIO_WIDTH - 1:0]reg_arith_adjust_ratio_q15; // lead闭环相对调整比例的事务级快照
	reg signed [C_SLOPE_WIDTH - 1:0]reg_arith_slope_min_q16; // 本次候选允许的最负斜率快照
	reg signed [C_SLOPE_WIDTH - 1:0]reg_arith_slope_max_q16; // 本次候选允许的近零斜率快照
	reg [C_FRAME_ID_WIDTH - 1:0]reg_arith_lead_min_frames; // 相交过晚判定的冻结提前量下界
	reg [C_FRAME_ID_WIDTH - 1:0]reg_arith_lead_max_frames; // 相交过早判定的冻结提前量上界
	reg [3:0]reg_arith_no_cross_limit;          // 连续无相交重新获取限制的事务快照
	reg [24:0]reg_arith_cycle_amplitude;        // 旧波峰减旧波谷得到的正幅度快照
	reg [C_FRAME_ID_WIDTH - 1:0]reg_arith_period_frames; // 新旧波峰之间的合法短周期帧数
	reg [C_FRAME_ID_WIDTH - 1:0]reg_arith_lead_frames; // 新波峰相对旧相交的提前量快照
	reg [41:0]reg_base_numerator;               // 共享alpha操作输出补足Q15到Q16后的分子
	reg [41:0]reg_base_rounded_numerator;       // 顺序除法开始前加入半分母的42-bit分子
	reg [41:0]reg_div_input_data;               // 恢复除法器逐位送入余数的被除数移位寄存器
	reg [15:0]reg_divisor;                      // 本次42周期运算保持不变的非零周期除数
	reg [16:0]reg_div_remainder;                // 恢复除法器保留一位比较保护位的当前余数
	reg [41:0]reg_div_quotient;                 // 恢复除法器从高位到低位构造的完整商
	reg signed [C_SLOPE_WIDTH - 1:0]reg_arith_slope_base_q16; // 完整42-bit商饱和后的基础负斜率
	reg signed [49:0]reg_smooth_product;        // 共享beta操作保存的完整signed乘积
	reg signed [33:0]reg_arith_smooth_delta;    // 对称舍入后恢复符号的平滑增量
	reg [47:0]reg_adjust_product;               // 共享adjust操作保存的无符号完整乘积
	reg signed [32:0]reg_arith_adjust_step;     // 最近舍入且至少一个LSB的正调整步长
	reg signed [32:0]reg_arith_timing_term;     // 由无相交或lead窗口选择的有符号修正项
	reg signed [C_SLOPE_WIDTH - 1:0]reg_arith_slope_next_q16; // 等待波峰握手原子提交的下一活动斜率

	//-----------------标志信号-----------------//
	reg flag_valley_valid;                      // 当前周期已经收到合格波谷事件
	reg flag_below_seen;                        // 已观察到低于负迟滞边界的正式样本
	reg flag_candidate_active;                  // 首次越过已经锁存且等待连续确认
	reg flag_previous_valid;                    // 前一笔正式RED比较上下文可用
	reg flag_cross_issued;                      // 当前锚点周期已经产生过一次fine请求
	reg flag_cycle_cross_valid;                 // 当前周期具有时间已知的正式相交
	reg flag_cycle_qualified;                   // 当前周期未跨重检且允许自适应统计
	reg flag_resume_pending;                    // 重检成功后等待第一笔正式FIR恢复样本
	reg flag_pending_valid;                     // 本模块已经捕获且尚未释放的波峰事务所有权
	reg flag_pending_adaptive_request;          // 当前快照需要执行完整阶段B自适应算术
	reg flag_pending_adaptive_result_valid;     // 逐位除法及后续计算已得到完整合法结果
	reg flag_pending_fallback;                  // 本次波峰应使用固定斜率异常回退提交
	reg flag_pending_baseline_valid;            // 捕获时旧波峰锚点是否有效
	reg flag_pending_period_legal;              // 捕获时新旧波峰短跨度是否合法
	reg flag_pending_config_legal;              // 捕获时ACTIVE动态基线字段是否合法
	reg flag_pending_no_cross;                  // 捕获周期没有时间已知的正式相交
	reg flag_pending_no_cross_reacquire;        // 当前无相交累计达到重新获取阈值
	reg flag_pending_clamp_min;                 // 待提交候选触及最负斜率边界
	reg flag_pending_clamp_max;                 // 待提交候选触及近零斜率边界
	reg flag_pending_cross_valid;               // 捕获周期具有可用于lead闭环的精确相交
	wire flag_control_clear;                    // STOP或abort要求清除运行上下文
	wire flag_reacquire_clear;                  // 精度异常返回要求废止旧锚点与周期证据
	wire flag_arithmetic_cancel;                // 生命周期或重检要求无条件撤销在途算术
	wire flag_arithmetic_busy;                  // 非空闲状态正在占用波峰上下文或等待提交
	wire flag_peak_payload_match;               // 外部保持载荷仍与捕获的新波峰逐位一致
	wire flag_peak_hold_violation;              // ready为低期间valid撤销或波峰载荷改变
	wire flag_pending_config_match;             // 当前ACTIVE算术字段仍与捕获快照一致
	wire flag_pending_config_violation;         // 自适应计算期间检测到配置版本漂移
	wire flag_arithmetic_timeout;               // 算术周期计数达到冻结的128周期上限
	wire flag_divide_zero;                      // 防御性识别顺序除法器零分母
	wire flag_state_invalid;                    // 状态寄存器不属于任一冻结算术状态
	wire flag_arithmetic_error_event;           // 阶段B协议、除零、超时或状态异常事件汇总
	wire flag_config_legal;                     // ACTIVE动态基线字段满足NORMAL约束
	wire flag_current_slope_legal;              // 保留活动斜率仍处于当前合法负边界
	wire flag_result_transfer;                  // 粗FIR事务在当前沿完成握手
	wire flag_peak_transfer;                    // 波峰事件在当前沿完成握手
	wire flag_valley_transfer;                  // 波谷事件在当前沿完成握手
	wire flag_formal_red_result;                // 当前事务可作为RED检测证据
	wire flag_cross_eligible_red_result;        // 当前正式RED中心样本具备9-bit相交资格
	wire flag_result_frame_legal;               // 当前中心帧距锚点小于半回绕
	wire flag_candidate_start;                  // 当前样本形成首次向上越过
	wire flag_candidate_continue;               // 已有候选继续保持在正迟滞上方
	wire flag_candidate_complete;               // 当前样本达到配置连续确认点数
	wire flag_candidate_break;                  // 候选因跌回正迟滞下方而取消
	wire flag_unknown_cross_emit;               // 恢复首样本已位于基线上方
	wire flag_known_cross_emit;                 // 精确候选完成全部连续确认
	wire flag_cross_emit;                       // 任一种相交事件可写入空闲输出槽
	wire flag_peak_period_legal;                // 新旧波峰帧差非零且小于半回绕
	wire flag_valley_order_legal;               // 波谷位于当前波峰之后的合法短跨度
	wire flag_cycle_epoch_match;                // 峰谷和相交事件使用一致校准版本
	wire flag_cycle_amplitude_legal;            // 当前峰谷幅度保持正极性
	wire flag_cycle_complete;                   // 当前波峰闭合一个可更新完整周期
	wire flag_cycle_candidate_complete;         // 尚未握手的新波峰具备完整周期算术资格
	wire flag_cycle_candidate_no_cross;         // 捕获前完整周期没有时间已知相交
	wire flag_candidate_no_cross_reacquire;     // 捕获前无相交计数将在本周期达到限制
	wire flag_peak_commit;                      // 保持载荷一致的波峰在WAIT状态正式提交
	wire flag_peak_capture_event;               // IDLE观察稳定valid后锁存新波峰与旧周期快照
	wire flag_fallback_commit;                  // 异常算术结果以固定斜率完成波峰提交
	wire flag_cycle_no_cross;                   // 完整周期没有时间已知正式相交
	wire flag_no_cross_reacquire;               // 本次无相交达到重新获取阈值
	wire flag_slope_clamp_min;                  // 新斜率候选低于最负允许值
	wire flag_slope_clamp_max;                  // 新斜率候选高于最接近零允许值
	wire flag_div_trial_ge_divisor;             // 当前恢复除法试减足以生成商位一
	wire flag_pending_candidate_clamp_min;      // pending候选低于冻结最负边界
	wire flag_pending_candidate_clamp_max;      // pending候选高于冻结近零边界

	//-----------------编码信号-----------------//
	wire signed [32:0]enc_arith_smooth_difference; // 冻结基础斜率与旧活动斜率的完整差值
	//-----------------译码信号-----------------//
	wire signed [23:0]dec_peak_value;           // 当前锚点的signed 24-bit码值波峰
	wire [C_FRAME_ID_WIDTH - 1:0]dec_peak_frame_id; // 当前锚点实际中心帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_peak_sample_index; // 当前锚点事务序号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_peak_config_epoch; // 当前锚点ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_peak_coef_epoch; // 当前锚点Stage1系数版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_peak_dc_epoch; // 当前锚点DC恢复版本
	wire signed [23:0]dec_valley_value;         // 当前周期已保存的signed 24-bit波谷
	wire [C_FRAME_ID_WIDTH - 1:0]dec_valley_frame_id; // 已保存波谷实际中心帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_valley_sample_index; // 已保存波谷对应的事务序号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_valley_config_epoch; // 已保存波谷ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_valley_coef_epoch; // 已保存波谷Stage1系数版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_valley_dc_epoch; // 已保存波谷DC恢复版本
	wire [C_FRAME_ID_WIDTH - 1:0]dec_cycle_cross_frame_id; // 本周期首次精确越过中心帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_cycle_cross_sample_index; // 本周期精确相交对应的事务序号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_cycle_cross_config_epoch; // 本周期相交ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_cycle_cross_coef_epoch; // 本周期相交使用的Stage1校准代次
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_cycle_cross_dc_epoch; // 本周期相交DC恢复版本
	wire signed [C_SLOPE_WIDTH - 1:0]dec_cycle_cross_slope_q16; // 本周期相交时采用的活动斜率
	wire signed [C_BASELINE_WIDTH - 1:0]dec_cycle_cross_baseline_q16; // 本周期相交时记录的诊断基线
	wire signed [C_BASELINE_WIDTH - 1:0]dec_previous_value_q16; // 前一正式样本的扩展Q16码值
	wire signed [C_BASELINE_WIDTH - 1:0]dec_previous_baseline_q16; // 前一正式样本对应的Q16动态基线
	wire [C_FRAME_ID_WIDTH - 1:0]dec_previous_frame_id; // 前一正式样本的中心帧编号
	wire [C_FRAME_ID_WIDTH - 1:0]dec_result_frame_delta; // 当前FIR中心帧相对锚点的模差
	wire [C_FRAME_ID_WIDTH - 1:0]dec_peak_period_frames; // 新波峰相对旧波峰的完整周期帧数
	wire [C_FRAME_ID_WIDTH - 1:0]dec_valley_frame_delta; // 波谷相对当前锚点的中心帧差
	wire [C_FRAME_ID_WIDTH - 1:0]dec_lead_frames; // 下一波峰相对已知相交的提前量
	wire signed [C_BASELINE_WIDTH - 1:0]dec_filtered_value_q16; // 当前signed 24-bit FIR码的Q16扩展
	wire signed [C_BASELINE_WIDTH - 1:0]dec_peak_value_q16; // 当前波峰锚点码值的Q16扩展
	wire signed [C_BASELINE_WIDTH - 1:0]dec_baseline_delta_q16; // ACTIVE起点偏置的基线宽度扩展
	wire signed [C_SLOPE_WIDTH:0]dec_frame_delta_signed; // 正值帧差的显式signed扩展
	wire signed [C_SLOPE_WIDTH + C_FRAME_ID_WIDTH:0]dec_slope_product_q16; // 活动斜率乘中心帧差的Q16乘积
	wire signed [63:0]dec_baseline_wide_q16;    // 波峰、偏置和斜率乘积的宽位求和
	wire signed [C_BASELINE_WIDTH - 1:0]dec_baseline_q16; // 当前中心帧的内部Q16动态基线
	wire signed [C_BASELINE_WIDTH - 1:0]dec_baseline_low_q16; // 减去迟滞后的重新武装边界
	wire signed [C_BASELINE_WIDTH - 1:0]dec_baseline_high_q16; // 加上迟滞后的正向确认边界
	wire signed [C_BASELINE_WIDTH - 1:0]dec_baseline_diagnostic_q16; // 限制到signed 24-bit范围的事件基线
	wire signed [24:0]dec_cycle_amplitude;      // 当前锚点波峰减去本周期波谷的正幅度
	wire signed [C_SLOPE_WIDTH - 1:0]dec_slope_base_q16; // 限制到32-bit的基础斜率诊断值
	wire signed [C_SLOPE_WIDTH - 1:0]dec_slope_next_q16; // 按配置边界夹紧的下一周期斜率
	wire signed [32:0]dec_shared_operand_a;     // 状态选择后的共享33-bit signed左操作数
	wire signed [16:0]dec_shared_operand_b;     // 比例补零形成的共享17-bit signed右操作数
	wire signed [49:0]dec_shared_product;       // 唯一33乘17周期更新乘法器完整结果
	wire [41:0]dec_arith_rounded_numerator;     // 由寄存分子和冻结半分母形成的除法输入
	wire [16:0]dec_div_trial_remainder;         // 当前迭代移入一位后的17-bit试减余数
	wire [16:0]dec_div_remainder_next;          // 当前迭代完成试减后的下一余数
	wire [41:0]dec_div_quotient_next;           // 当前迭代移入判断位后的下一商
	wire signed [42:0]dec_arith_slope_base_wide; // 完整顺序商取负后的43-bit基础斜率
	wire [49:0]dec_arith_smooth_product_abs;    // 寄存beta乘积的50-bit绝对值
	wire [49:0]dec_arith_smooth_rounded_abs;    // 平滑绝对值加入半LSB后的右移结果
	wire signed [33:0]dec_arith_smooth_delta;   // 平滑结果按乘积符号恢复的34-bit增量
	wire [31:0]dec_arith_base_abs;              // 防御饱和后基础负斜率的无符号绝对值
	wire [47:0]dec_arith_adjust_rounded;        // 调整乘积加入半LSB后的右移结果
	wire signed [32:0]dec_arith_adjust_step;    // 调整结果至少为一个Q16 LSB的正步长
	wire signed [34:0]dec_arith_slope_candidate; // 冻结三项斜率量合成的35-bit候选
	wire signed [C_SLOPE_WIDTH - 1:0]dec_arith_clamped_slope_q16; // 等待原子提交的边界夹紧结果

	//-----------------其他信号-----------------//

	//-----------------输出信号-----------------//
	// 相交载荷寄存器将帧号、版本、斜率和基线作为一个保持单元
	reg [EVENT_CONTEXT_WIDTH - 1:0]cross_payload_o; // 相交帧号、epoch、斜率和基线原子载荷

	//相交事件接口
	reg cross_valid_o;                          // 相交事件输出槽占用标志
	reg cross_time_unknown_o;                   // 当前输出缺少精确穿越时刻

	//只读状态接口
	reg baseline_valid_o;                       // 当前锚点允许计算动态基线
	reg adaptive_slope_valid_o;                 // 活动斜率已经由完整周期自适应更新
	reg signed [C_SLOPE_WIDTH - 1:0]slope_current_q16_o; // 从当前波峰到下一波峰使用的活动斜率
	reg signed [C_SLOPE_WIDTH - 1:0]slope_base_q16_o; // 最近合法峰谷周期导出的基础斜率
	reg [C_FRAME_ID_WIDTH - 1:0]last_lead_frames_o; // 最近时间可知相交距离下一波峰的帧数
	reg [3:0]cnt_no_cross_o;                    // 尚未观察正式相交的完整周期累计数
	reg reacquire_active_o;                     // 当前等待新的可靠波峰重新建立基线
	reg slope_saturation_min_o;                 // 最近候选被夹紧到最负斜率边界
	reg slope_saturation_max_o;                 // 最近候选被夹紧到最接近零边界
	reg baseline_saturation_low_o;              // 最近基线低于统一PPG负端点
	reg baseline_saturation_high_o;             // 最近基线高于统一PPG正端点
	reg protocol_error_sticky_o;                // 任一配置或事件顺序错误保持至清理

	//---------------其他信号连线---------------//
	// 生命周期和配置合法性决定各输入接口是否接受正式事务
	assign flag_control_clear = i_detection_discard_event && (i_detection_discard_run_generation == i_run_generation); // PWI广播的代际清空事件命中当前代际时终止RUN上下文
	assign flag_reacquire_clear = i_reacquire_request_event; // 单拍事件在本时钟沿原子废止异常fine窗口的旧检测上下文
	assign flag_arithmetic_cancel = i_start_ack_event || flag_control_clear || flag_reacquire_clear || i_recheck_accept_event || i_recheck_busy || (i_run_enable == 1'b0); // 生命周期、异常重获和重检优先撤销在途波峰计算
	assign flag_arithmetic_busy = (state_current != ST_IDLE); // 捕获后直至正式提交或撤销均视为算术占用期
	assign flag_config_legal = (i_fixed_slope_q16 < 0) && (i_slope_min_q16 < i_slope_max_q16) && (i_slope_max_q16 < 0) && (i_fixed_slope_q16 >= i_slope_min_q16) && (i_fixed_slope_q16 <= i_slope_max_q16) && (i_alpha_q15 != 0) && (i_beta_q15 != 0) && (i_timing_adjust_ratio_q15 != 0) && (i_lead_min_frames <= i_lead_max_frames) && (i_lead_min_frames >= ({{(C_FRAME_ID_WIDTH - 4){1'b0}}, i_cross_confirm_count} + {{(C_FRAME_ID_WIDTH - 4){1'b0}}, 4'd14})) && (i_cross_confirm_count >= 4'd2) && (i_no_cross_limit >= 4'd1); // 检查NORMAL运行全部冻结约束
	assign flag_current_slope_legal = (slope_current_q16_o < 0) && (slope_current_q16_o >= i_slope_min_q16) && (slope_current_q16_o <= i_slope_max_q16); // 新锚点只能继承仍满足当前ACTIVE边界的保留斜率
	assign flag_peak_payload_match = ({i_peak_value, i_peak_frame_id, i_peak_sample_index, i_peak_config_epoch, i_peak_coef_epoch, i_peak_dc_recovery_coef_epoch} == reg_arith_new_peak_context); // 比较ready拉低期间全部波峰字段是否保持
	assign flag_peak_hold_violation = flag_pending_valid && flag_arithmetic_busy && ((i_peak_valid == 1'b0) || (flag_peak_payload_match == 1'b0)); // 捕获后撤销valid或改变载荷均丢失事务所有权
	assign flag_pending_config_match = (i_slope_mode == SLOPE_MODE_ADAPTIVE) && (i_fixed_slope_q16 == reg_arith_fixed_slope_q16) && (i_alpha_q15 == reg_arith_alpha_q15) && (i_beta_q15 == reg_arith_beta_q15) && (i_timing_adjust_ratio_q15 == reg_arith_adjust_ratio_q15) && (i_slope_min_q16 == reg_arith_slope_min_q16) && (i_slope_max_q16 == reg_arith_slope_max_q16) && (i_lead_min_frames == reg_arith_lead_min_frames) && (i_lead_max_frames == reg_arith_lead_max_frames) && (i_no_cross_limit == reg_arith_no_cross_limit); // 阶段B只允许使用捕获时冻结的ACTIVE算术字段
	assign flag_pending_config_violation = flag_pending_valid && flag_pending_adaptive_request && (flag_pending_fallback == 1'b0) && (flag_pending_config_match == 1'b0); // ACTIVE漂移取消自适应但仍允许固定斜率提交
	assign flag_arithmetic_timeout = flag_pending_valid && (state_current != ST_IDLE) && (state_current != ST_WAIT_PEAK_COMMIT) && (state_current != ST_TIMEOUT_FALLBACK) && (cnt_arithmetic_cycles == C_SLOPE_UPDATE_MAX_CYCLES); // 计数达到127后下一步必须进入回退而非回绕
	assign flag_divide_zero = (state_current == ST_PREPARE_DIVIDE) && (reg_arith_period_frames == {C_FRAME_ID_WIDTH{1'b0}}); // 合法性前置之外仍防御零周期分母
	assign flag_state_invalid = (state_current > ST_TIMEOUT_FALLBACK); // 任一未编码状态触发安全恢复和sticky诊断
	assign flag_arithmetic_error_event = flag_peak_hold_violation || flag_pending_config_violation || flag_arithmetic_timeout || flag_divide_zero || flag_state_invalid; // 汇总阶段B新增的可观测协议错误
	assign flag_result_transfer = i_result_valid && o_result_ready; // 当前沿完成一笔FIR事务消费

	//PEAK接口
	assign flag_peak_commit = i_peak_valid && o_peak_ready && flag_pending_valid && flag_peak_payload_match; // 只有稳定保持的pending波峰才具有正式提交资格
	assign flag_peak_capture_event = (state_current == ST_IDLE) && i_run_enable && (i_recheck_busy == 1'b0) && i_peak_valid; // ready尚低时先取得波峰事务的临时所有权
	assign flag_peak_transfer = flag_peak_commit; // 复用原周期边界名称驱动全部原子状态更新
	assign flag_fallback_commit = flag_peak_commit && flag_pending_fallback; // 标识固定斜率异常回退已被上游正式消费

	//VALLEY接口
	assign flag_valley_transfer = i_valley_valid && o_valley_ready; // 当前沿接受一个可靠波谷事件
	assign flag_formal_red_result = flag_result_transfer && i_detection_qualified && (i_color_ir == 1'b0) && (i_frame_type == FRAME_TYPE_NORMAL) && (i_window_saturation_low == 1'b0) && (i_window_saturation_high == 1'b0) && (i_fir_saturation_low == 1'b0) && (i_fir_saturation_high == 1'b0); // 限定RED正式检测证据；饱和样本不得成为CROSS/baseline正式证据 @satisfies: PRC-03
	assign flag_cross_eligible_red_result = flag_formal_red_result && (i_fine_window_active == 1'b0) && (i_precision_mode == 1'b0); // 当前窗口和中心历史精度均为9-bit才允许形成相交证据；旧15-bit尾部(precision_mode=1)期间恒为0,不启动新候选 @satisfies: TOP-06

	//其他信号连线
	// 打包峰谷字段解码保持各元数据位宽与合同逐项一致
	assign {dec_peak_value, dec_peak_frame_id, dec_peak_sample_index, dec_peak_config_epoch, dec_peak_coef_epoch, dec_peak_dc_epoch} = reg_peak_context; // 解码当前波峰锚点上下文
	assign {dec_valley_value, dec_valley_frame_id, dec_valley_sample_index, dec_valley_config_epoch, dec_valley_coef_epoch, dec_valley_dc_epoch} = reg_valley_context; // 解码当前波谷及其版本上下文
	assign {dec_cycle_cross_frame_id, dec_cycle_cross_sample_index, dec_cycle_cross_config_epoch, dec_cycle_cross_coef_epoch, dec_cycle_cross_dc_epoch, dec_cycle_cross_slope_q16, dec_cycle_cross_baseline_q16} = reg_cycle_cross_context; // 解码本周期相交时间与版本字段
	assign {dec_previous_value_q16, dec_previous_baseline_q16, dec_previous_frame_id} = reg_previous_context; // 解码前一正式样本比较上下文
	// 中心帧模减只接受最高位为零的短跨度
	assign dec_result_frame_delta = i_frame_id - dec_peak_frame_id; // 计算当前FIR样本相对锚点的真实帧差
	assign dec_peak_period_frames = i_peak_frame_id - dec_peak_frame_id; // 计算相邻码值波峰的峰峰周期
	assign dec_valley_frame_delta = i_valley_frame_id - dec_peak_frame_id; // 计算波谷相对锚点的顺序距离
	assign dec_lead_frames = i_peak_frame_id - dec_cycle_cross_frame_id; // 计算相交距离下一波峰的提前量
	assign flag_result_frame_legal = (dec_result_frame_delta[C_FRAME_ID_WIDTH-1] == 1'b0); // 拒绝达到半回绕的基线时间
	assign flag_peak_period_legal = (dec_peak_period_frames != 0) && (dec_peak_period_frames[C_FRAME_ID_WIDTH-1] == 1'b0); // 限定合法完整周期跨度
	assign flag_valley_order_legal = (dec_valley_frame_delta != 0) && (dec_valley_frame_delta[C_FRAME_ID_WIDTH-1] == 1'b0); // 限定波谷发生在锚点之后
	// 基线公式严格使用B=P+DELTA+S*frame_delta，避免双重负号
	assign dec_filtered_value_q16 = {{(C_BASELINE_WIDTH - 40){i_filtered_ppg_value[23]}}, i_filtered_ppg_value, 16'd0}; // FIR整数码显式扩展为Q16

	//其他信号连线
	assign dec_peak_value_q16 = {{(C_BASELINE_WIDTH - 40){dec_peak_value[23]}}, dec_peak_value, 16'd0}; // 波峰整数码显式扩展为Q16
	assign dec_baseline_delta_q16 = {{(C_BASELINE_WIDTH - C_SLOPE_WIDTH){i_baseline_delta_q16[C_SLOPE_WIDTH-1]}}, i_baseline_delta_q16}; // 起点偏置符号扩展到基线宽度
	assign dec_frame_delta_signed = $signed({1'b0, {{(C_SLOPE_WIDTH - C_FRAME_ID_WIDTH){1'b0}}, dec_result_frame_delta}}); // 无符号短帧差转换为正signed量
	assign dec_slope_product_q16 = $signed(slope_current_q16_o) * $signed({1'b0, dec_result_frame_delta}); // 活动负斜率乘中心帧差

	//其他信号连线
	assign dec_baseline_wide_q16 = $signed(dec_peak_value_q16) + $signed(dec_baseline_delta_q16) + $signed(dec_slope_product_q16); // 合成当前中心帧动态基线
	assign dec_baseline_q16 = (dec_baseline_wide_q16 > $signed({{(64 - C_BASELINE_WIDTH){1'b0}}, {1'b0, {(C_BASELINE_WIDTH - 1){1'b1}}}})) ? {1'b0, {(C_BASELINE_WIDTH - 1){1'b1}}} : ((dec_baseline_wide_q16 < $signed({{(64 - C_BASELINE_WIDTH){1'b1}}, {1'b1, {(C_BASELINE_WIDTH - 1){1'b0}}}})) ? {1'b1, {(C_BASELINE_WIDTH - 1){1'b0}}} : dec_baseline_wide_q16[C_BASELINE_WIDTH - 1:0]); // 防止内部48-bit基线自然回绕；强基线漂移下限幅而非环绕，保证数值不出现算术wrap @satisfies: PRC-04
	assign dec_baseline_low_q16 = $signed(dec_baseline_q16) - $signed({{(C_BASELINE_WIDTH - C_SLOPE_WIDTH){1'b0}}, i_cross_hysteresis_q16}); // 生成重新武装负迟滞边界
	assign dec_baseline_high_q16 = $signed(dec_baseline_q16) + $signed({{(C_BASELINE_WIDTH - C_SLOPE_WIDTH){1'b0}}, i_cross_hysteresis_q16}); // 生成向上确认正迟滞边界

	//其他信号连线
	assign dec_baseline_diagnostic_q16 = (dec_baseline_q16 > PPG_Q16_MAX) ? PPG_Q16_MAX : ((dec_baseline_q16 < PPG_Q16_MIN) ? PPG_Q16_MIN : dec_baseline_q16); // 事件基线限制到统一PPG端点
	// 相交必须由相邻正式样本跨越两侧迟滞边界并连续保持
	assign flag_candidate_start = i_peak_valley_config_valid && flag_cross_eligible_red_result && baseline_valid_o && flag_result_frame_legal && (flag_cross_issued == 1'b0) && (flag_candidate_active == 1'b0) && flag_below_seen && flag_previous_valid && (dec_previous_value_q16 <= ($signed(dec_previous_baseline_q16) - $signed({{(C_BASELINE_WIDTH - C_SLOPE_WIDTH){1'b0}}, i_cross_hysteresis_q16}))) && (dec_filtered_value_q16 >= dec_baseline_high_q16); // V5资格无效时不得建立新候选或锁存首次越过身份；平坦/无脉搏输入恒不满足双侧迟滞越过，杜绝虚假CROSS；unpacker->AMI->PWI->C20/C22/C23唯一通路上的C20消费端,真实门控点 @satisfies: PRC-01, G-FP-01-D01-04
	assign flag_candidate_continue = i_peak_valley_config_valid && flag_cross_eligible_red_result && flag_candidate_active && flag_result_frame_legal && (dec_filtered_value_q16 >= dec_baseline_high_q16); // V5资格无效时冻结连续确认计数，候选只允许连续9-bit正式中心点保持
	assign flag_candidate_complete = flag_candidate_continue && ((cnt_cross_confirm + 4'd1) >= i_cross_confirm_count); // 当前样本补足配置连续确认点数

	//其他信号连线
	assign flag_candidate_break = flag_cross_eligible_red_result && flag_candidate_active && (dec_filtered_value_q16 < dec_baseline_high_q16); // 合格9-bit样本跌回正边界下方立即取消候选
	assign flag_unknown_cross_emit = flag_cross_eligible_red_result && flag_resume_pending && baseline_valid_o && flag_result_frame_legal && (flag_cross_issued == 1'b0) && (dec_filtered_value_q16 >= dec_baseline_high_q16); // 空窗恢复首笔合格9-bit样本位于基线上方
	assign flag_known_cross_emit = flag_candidate_complete && (flag_cross_issued == 1'b0); // 精确候选在末个确认点产生事件
	assign flag_cross_emit = i_peak_valley_config_valid && (cross_valid_o == 1'b0) && (flag_unknown_cross_emit || flag_known_cross_emit); // 仅空输出槽且V5正式资格有效时允许锁存新相交载荷

	//其他信号连线
	// 完整周期要求峰谷、时序、极性、epoch和重检资格同时有效
	assign dec_cycle_amplitude = $signed({dec_peak_value[23], dec_peak_value}) - $signed({dec_valley_value[23], dec_valley_value}); // 使用P[n]-V[n]得到正峰谷幅度
	assign flag_cycle_amplitude_legal = (dec_cycle_amplitude > 0); // 原始码值波峰必须严格高于波谷
	assign flag_cycle_epoch_match = (dec_peak_config_epoch == dec_valley_config_epoch) && (dec_peak_coef_epoch == dec_valley_coef_epoch) && (dec_peak_dc_epoch == dec_valley_dc_epoch) && (dec_peak_config_epoch == i_peak_config_epoch) && (dec_peak_coef_epoch == i_peak_coef_epoch) && (dec_peak_dc_epoch == i_peak_dc_recovery_coef_epoch) && ((flag_cycle_cross_valid == 1'b0) || ((dec_peak_config_epoch == dec_cycle_cross_config_epoch) && (dec_peak_coef_epoch == dec_cycle_cross_coef_epoch) && (dec_peak_dc_epoch == dec_cycle_cross_dc_epoch))); // 拒绝跨配置版本的自适应更新；强基线漂移期间禁止跨版本混用，杜绝身份丢失 @satisfies: PRC-04

	//其他信号连线
	assign flag_cycle_candidate_complete = i_peak_valid && baseline_valid_o && flag_valley_valid && flag_cycle_qualified && flag_peak_period_legal && flag_cycle_amplitude_legal && flag_cycle_epoch_match; // 未握手波峰的旧周期证据满足全部自适应资格
	assign flag_cycle_candidate_no_cross = flag_cycle_candidate_complete && (flag_cycle_cross_valid == 1'b0); // 捕获前识别完整但无精确相交的周期
	assign flag_candidate_no_cross_reacquire = flag_cycle_candidate_no_cross && ((cnt_no_cross_o + 4'd1) >= i_no_cross_limit); // 达到限制的周期走即时重新获取而不启动除法
	assign flag_cycle_complete = flag_peak_commit && flag_pending_adaptive_result_valid && (flag_pending_fallback == 1'b0); // 只有完整阶段B结果与新锚点同拍提交才更新周期状态
	assign flag_cycle_no_cross = flag_cycle_complete && flag_pending_no_cross; // 使用捕获快照判断本次成功提交是否无相交
	assign flag_no_cross_reacquire = flag_peak_commit && flag_pending_no_cross_reacquire; // 即时路径在原子波峰提交沿废止旧基线
	assign flag_slope_clamp_min = flag_pending_clamp_min; // 对外状态更新只观察已完成的pending限幅结果
	assign flag_slope_clamp_max = flag_pending_clamp_max; // 近零诊断与最负诊断在同一提交边界生效
	assign dec_slope_base_q16 = reg_arith_slope_base_q16; // 兼容原状态更新命名并改由顺序商结果驱动
	assign dec_slope_next_q16 = reg_arith_slope_next_q16; // 兼容原提交路径并禁止读取组合变量除法
	// 阶段C由状态选择冻结操作数并只保留一个signed 33乘17乘法表达式
	assign dec_shared_operand_a = (state_current == ST_MUL_ALPHA) ? $signed({8'd0, reg_arith_cycle_amplitude}) : ((state_current == ST_MUL_BETA) ? $signed(enc_arith_smooth_difference) : ((state_current == ST_MUL_ADJUST) ? $signed({1'b0, dec_arith_base_abs}) : 33'sd0)); // alpha和adjust补零而beta保持33-bit符号
	assign dec_shared_operand_b = (state_current == ST_MUL_ALPHA) ? $signed({1'b0, reg_arith_alpha_q15}) : ((state_current == ST_MUL_BETA) ? $signed({1'b0, reg_arith_beta_q15}) : ((state_current == ST_MUL_ADJUST) ? $signed({1'b0, reg_arith_adjust_ratio_q15}) : 17'sd0)); // 每个乘法状态只选择对应Q1.15比例
	assign dec_shared_product = $signed(dec_shared_operand_a) * $signed(dec_shared_operand_b); // 单一乘法器依次服务alpha、beta和adjust运算
	assign dec_arith_rounded_numerator = reg_base_numerator + ({{(42 - C_FRAME_ID_WIDTH){1'b0}}, reg_arith_period_frames} >> 1); // 在42-bit域加入冻结周期的一半
	assign dec_div_trial_remainder = {reg_div_remainder[15:0], reg_div_input_data[41]}; // 将当前被除数最高位移入恢复余数
	assign flag_div_trial_ge_divisor = (dec_div_trial_remainder >= {1'b0, reg_divisor}); // 比较试减余数决定当前商位
	assign dec_div_remainder_next = flag_div_trial_ge_divisor ? (dec_div_trial_remainder - {1'b0, reg_divisor}) : dec_div_trial_remainder; // 恢复不足除数的余数并保留成功试减结果
	assign dec_div_quotient_next = {reg_div_quotient[40:0], flag_div_trial_ge_divisor}; // 从高位到低位逐周期构造42-bit商
	assign dec_arith_slope_base_wide = -$signed({1'b0, reg_div_quotient}); // 对完整顺序商补零后安全取负
	assign enc_arith_smooth_difference = $signed({reg_arith_slope_base_q16[C_SLOPE_WIDTH-1], reg_arith_slope_base_q16}) - $signed({reg_arith_slope_current_q16[C_SLOPE_WIDTH-1], reg_arith_slope_current_q16}); // 以33-bit保存基础斜率与旧活动斜率差
	assign dec_arith_smooth_product_abs = reg_smooth_product[49] ? (~reg_smooth_product + 50'd1) : $unsigned(reg_smooth_product); // 提取已寄存平滑乘积的绝对值
	assign dec_arith_smooth_rounded_abs = (dec_arith_smooth_product_abs + Q15_ROUND_HALF_50) >> 15; // 对平滑绝对值执行最近舍入
	assign dec_arith_smooth_delta = reg_smooth_product[49] ? -$signed({1'b0, dec_arith_smooth_rounded_abs[32:0]}) : $signed({1'b0, dec_arith_smooth_rounded_abs[32:0]}); // 按原乘积符号恢复34-bit增量
	assign dec_arith_base_abs = reg_arith_slope_base_q16[C_SLOPE_WIDTH-1] ? $unsigned(-$signed(reg_arith_slope_base_q16)) : $unsigned(reg_arith_slope_base_q16); // 基础斜率已排除signed最小值后再取幅值
	assign dec_arith_adjust_rounded = (reg_adjust_product + Q15_ROUND_HALF_48) >> 15; // 对已寄存调整乘积执行Q1.15最近舍入
	assign dec_arith_adjust_step = (dec_arith_adjust_rounded == 0) ? 33'sd1 : $signed({1'b0, dec_arith_adjust_rounded[31:0]}); // 小比例配置仍保证至少一个Q16 LSB
	assign dec_arith_slope_candidate = $signed({{3{reg_arith_slope_current_q16[C_SLOPE_WIDTH-1]}}, reg_arith_slope_current_q16}) + $signed({reg_arith_smooth_delta[33], reg_arith_smooth_delta}) + $signed({{2{reg_arith_timing_term[32]}}, reg_arith_timing_term}); // 在35-bit域合成平滑与时刻修正
	assign flag_pending_candidate_clamp_min = (dec_arith_slope_candidate < $signed({{3{reg_arith_slope_min_q16[C_SLOPE_WIDTH-1]}}, reg_arith_slope_min_q16})); // 比较冻结的最负斜率边界
	assign flag_pending_candidate_clamp_max = (dec_arith_slope_candidate > $signed({{3{reg_arith_slope_max_q16[C_SLOPE_WIDTH-1]}}, reg_arith_slope_max_q16})); // 比较冻结的近零斜率边界
	assign dec_arith_clamped_slope_q16 = flag_pending_candidate_clamp_min ? reg_arith_slope_min_q16 : (flag_pending_candidate_clamp_max ? reg_arith_slope_max_q16 : dec_arith_slope_candidate[C_SLOPE_WIDTH - 1:0]); // 生成等待握手的夹紧斜率

	//---------------输出信号连线---------------//
	//相交载荷接口
	assign o_cross_frame_id = cross_payload_o[EVENT_CONTEXT_WIDTH - 1-:C_FRAME_ID_WIDTH]; // 导出首次越过或发现帧号
	assign o_cross_sample_index = cross_payload_o[EVENT_CONTEXT_WIDTH - C_FRAME_ID_WIDTH - 1-:C_SAMPLE_INDEX_WIDTH]; // 导出相交中心事务序号
	assign o_cross_config_epoch = cross_payload_o[EVENT_CONTEXT_WIDTH - C_FRAME_ID_WIDTH - C_SAMPLE_INDEX_WIDTH - 1-:C_CONFIG_EPOCH_WIDTH]; // 导出相交ACTIVE配置版本
	assign o_cross_coef_epoch = cross_payload_o[EVENT_CONTEXT_WIDTH - C_FRAME_ID_WIDTH - C_SAMPLE_INDEX_WIDTH - C_CONFIG_EPOCH_WIDTH - 1-:C_COEF_EPOCH_WIDTH]; // 导出相交Stage1系数组版本
	assign o_cross_dc_recovery_coef_epoch = cross_payload_o[C_BASELINE_WIDTH + C_SLOPE_WIDTH + C_DC_RECOVERY_EPOCH_WIDTH - 1-:C_DC_RECOVERY_EPOCH_WIDTH]; // 导出相交DC恢复系数版本
	assign o_cross_slope_q16 = cross_payload_o[C_BASELINE_WIDTH + C_SLOPE_WIDTH - 1-:C_SLOPE_WIDTH]; // 导出相交时活动负斜率
	assign o_cross_baseline_q16 = cross_payload_o[C_BASELINE_WIDTH - 1:0]; // 导出相交时诊断基线

	//粗FIR事务接口
	assign o_result_ready = (flag_arithmetic_cancel == 1'b0) && (state_current == ST_IDLE); // 算术快照占用或生命周期撤销期间反压FIR分支

	//波峰事件接口
	assign o_peak_ready = (flag_arithmetic_cancel == 1'b0) && (state_current == ST_WAIT_PEAK_COMMIT); // 仅结果就绪且本拍无撤销时允许波峰正式提交

	//波谷事件接口
	assign o_valley_ready = (flag_arithmetic_cancel == 1'b0) && (state_current == ST_IDLE); // 在途算术或生命周期撤销期间冻结波谷所有权

	//相交事件接口
	// 相交事件输出从保持寄存器解码，反压期间所有字段保持原值
	assign o_cross_valid = cross_valid_o;       // 导出相交输出槽占用状态
	assign o_cross_time_unknown = cross_time_unknown_o; // 导出精确时刻未知属性

	//只读状态接口
	// 只读状态直接映射内部唯一所有者寄存器
	assign o_baseline_valid = baseline_valid_o; // 导出当前基线可比较资格
	assign o_adaptive_slope_valid = adaptive_slope_valid_o; // 导出自适应斜率历史资格
	assign o_slope_current_q16 = slope_current_q16_o; // 导出当前周期活动斜率
	assign o_slope_base_q16 = slope_base_q16_o; // 导出最近基础斜率
	assign o_last_lead_frames = last_lead_frames_o; // 导出最近精确相交提前量
	assign o_no_cross_count = cnt_no_cross_o;   // 导出连续无相交周期数
	assign o_reacquire_active = reacquire_active_o; // 导出波峰锚点重新获取状态
	assign o_slope_saturation_min = slope_saturation_min_o; // 导出最近最负斜率限幅诊断
	assign o_slope_saturation_max = slope_saturation_max_o; // 导出最近近零斜率限幅诊断
	assign o_baseline_saturation_low = baseline_saturation_low_o; // 导出最近基线负端点诊断
	assign o_baseline_saturation_high = baseline_saturation_high_o; // 导出最近基线正端点诊断
	assign o_protocol_error_sticky = protocol_error_sticky_o; // 导出运行期协议错误累计状态

	//本地排空观测接口
	assign o_local_empty = (cross_valid_o == 1'b0) && (flag_pending_valid == 1'b0) && (flag_arithmetic_busy == 1'b0); // 无保持相交输出、无捕获波峰所有权且无在途算术时报告本地排空

	//-------------输出信号处理区域-------------//
	//相交事件接口
	// 相交valid在事件锁存后保持至下游完成握手
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cross_valid_o <= 1'b0;              // 异步复位清空输出所有权
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1)begin
			cross_valid_o <= 1'b0;              // 生命周期或异常重获丢弃旧RUN在途事件
		end else if(flag_cross_emit == 1'b1)begin
			cross_valid_o <= 1'b1;              // 新事件占用保持型输出槽
		end else if(cross_valid_o == 1'b1 && i_cross_ready == 1'b1)begin
			cross_valid_o <= 1'b0;              // 握手完成后释放输出槽
		end else begin
			cross_valid_o <= cross_valid_o;     // 反压期间持续保持valid
		end
	end

	// time_unknown与事件载荷同拍写入且只在下一事件覆盖
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cross_time_unknown_o <= 1'b0;       // 复位后没有未知时刻事件
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1)begin
			cross_time_unknown_o <= 1'b0;       // 新RUN和异常重获不继承旧诊断属性
		end else if(flag_cross_emit == 1'b1)begin
			cross_time_unknown_o <= flag_unknown_cross_emit; // 区分精确候选与空窗发现事件
		end else begin
			cross_time_unknown_o <= cross_time_unknown_o; // 输出反压时维持属性稳定
		end
	end

	// 原子相交载荷与valid使用同一输出区域并独立保持
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cross_payload_o <= {EVENT_CONTEXT_WIDTH{1'b0}}; // 复位清空全部相交元数据
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1)begin
			cross_payload_o <= {EVENT_CONTEXT_WIDTH{1'b0}}; // 生命周期或异常重获删除旧相交载荷
		end else if(flag_cross_emit == 1'b1)begin
			if(flag_unknown_cross_emit == 1'b1)begin
				cross_payload_o <= {i_frame_id, i_sample_index, i_config_epoch, i_coef_epoch, i_dc_recovery_coef_epoch, slope_current_q16_o, dec_baseline_diagnostic_q16}; // 未知事件记录恢复后发现帧
			end else begin
				cross_payload_o <= reg_candidate_context; // 精确事件使用首次越过时锁存的载荷
			end
		end else begin
			cross_payload_o <= cross_payload_o; // 输出未握手前禁止载荷变化
		end
	end

	//只读状态接口
	// 当前斜率仅在START、故障回退或新波峰周期边界提交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			slope_current_q16_o <= {C_SLOPE_WIDTH{1'b0}}; // 复位时活动斜率没有运行含义
		end else if(i_start_ack_event == 1'b1)begin
			slope_current_q16_o <= i_fixed_slope_q16; // 新RUN装载ACTIVE固定负斜率种子
		end else if(flag_control_clear == 1'b1)begin
			slope_current_q16_o <= {C_SLOPE_WIDTH{1'b0}}; // STOP或abort移除旧RUN活动值
		end else if(i_recheck_done_event == 1'b1 && i_recheck_success == 1'b0)begin
			slope_current_q16_o <= i_fixed_slope_q16; // 重检失败退回固定斜率等待新锚点；RRC-11 真实重检失败把活动斜率重装为ACTIVE配置的固定负斜率 @satisfies: RRC-11
		end else if(flag_peak_transfer == 1'b1)begin
			slope_current_q16_o <= reg_arith_slope_next_q16; // 与新波峰锚点同拍提交即时、自适应或回退结果
		end else begin
			slope_current_q16_o <= slope_current_q16_o; // 当前周期内禁止中途改变斜率；RRC-04/RRC-09 accept同样不在本斜率的作废条件里，busy窗口原样保持并在成功恢复后原样复用 @satisfies: RRC-04, RRC-09
		end
	end

	// 最近基础斜率只由完整合法周期更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			slope_base_q16_o <= {C_SLOPE_WIDTH{1'b0}}; // 复位清空基础斜率诊断
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1)begin
			slope_base_q16_o <= {C_SLOPE_WIDTH{1'b0}}; // 新RUN或异常重获重新建立周期统计
		end else if(flag_cycle_complete == 1'b1)begin
			slope_base_q16_o <= dec_slope_base_q16; // 保存A乘alpha除T的负Q16结果
		end else begin
			slope_base_q16_o <= slope_base_q16_o; // 非完整周期保留最近诊断值
		end
	end

	// 基线资格在可靠波峰建立，在严重异常时失效
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			baseline_valid_o <= 1'b0;           // 复位后没有波峰锚点
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1)begin
			baseline_valid_o <= 1'b0;           // 新RUN、终止或异常返回均废止旧锚点
		end else if(i_recheck_done_event == 1'b1 && i_recheck_success == 1'b0)begin
			baseline_valid_o <= 1'b0;           // 重检失败禁止沿用旧模拟基线；RRC-11 真实失败作废旧基线锚点资格，不允许陈旧状态重新开放正式NORMAL @satisfies: RRC-11
		end else if(flag_no_cross_reacquire == 1'b1)begin
			baseline_valid_o <= 1'b0;           // 连续无相交废止无限延伸基线
		end else if(flag_peak_transfer == 1'b1)begin
			baseline_valid_o <= flag_pending_config_legal && (flag_pending_period_legal || (flag_pending_baseline_valid == 1'b0)); // 使用捕获快照原子建立或更新锚点
		end else begin
			baseline_valid_o <= baseline_valid_o; // 普通精度切换不影响基线资格
		end
	end

	// 自适应资格只在成功提交周期斜率后建立
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			adaptive_slope_valid_o <= 1'b0;     // 复位时没有完整自适应周期
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1)begin
			adaptive_slope_valid_o <= 1'b0;     // 每个RUN和异常重获独立积累自适应证据
		end else if(i_recheck_done_event == 1'b1 && i_recheck_success == 1'b0)begin
			adaptive_slope_valid_o <= 1'b0;     // 重检失败撤销旧自适应资格
		end else if(flag_fallback_commit == 1'b1)begin
			adaptive_slope_valid_o <= 1'b0;     // 超时、除零或配置漂移回退不声明自适应有效
		end else if(flag_no_cross_reacquire == 1'b1 || (flag_peak_transfer == 1'b1 && (flag_pending_period_legal == 1'b0)))begin
			adaptive_slope_valid_o <= 1'b0;     // 帧序异常或重获路径退回固定模式
		end else if(flag_cycle_complete == 1'b1 && i_slope_mode == SLOPE_MODE_ADAPTIVE)begin
			adaptive_slope_valid_o <= 1'b1;     // 首个完整周期后允许声明自适应有效
		end else begin
			adaptive_slope_valid_o <= adaptive_slope_valid_o; // 成功重检和精度切换均保留历史资格
		end
	end

	// 重新获取状态从START开始并在可靠波峰建立后退出
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reacquire_active_o <= 1'b0;         // 非RUN复位态不执行波峰搜索
		end else if(i_start_ack_event == 1'b1)begin
			reacquire_active_o <= flag_config_legal; // 合法RUN先等待第一个9-bit码值波峰
		end else if(flag_control_clear == 1'b1)begin
			reacquire_active_o <= 1'b0;         // STOP或abort结束重新获取流程
		end else if(flag_reacquire_clear == 1'b1)begin
			reacquire_active_o <= 1'b1;         // 异常返回9-bit后等待新的可靠码值波峰
		end else if(i_recheck_done_event == 1'b1 && i_recheck_success == 1'b0)begin
			reacquire_active_o <= 1'b1;         // 重检失败要求重新建立模拟基线；RRC-11 真实失败置位重新获取，等待新的可靠波峰锚点 @satisfies: RRC-11
		end else if(flag_no_cross_reacquire == 1'b1 || (flag_peak_transfer == 1'b1 && (flag_pending_period_legal == 1'b0) && flag_pending_baseline_valid == 1'b1))begin
			reacquire_active_o <= 1'b1;         // 无相交或异常周期转入固定斜率重获
		end else if(flag_peak_transfer == 1'b1 && flag_pending_config_legal == 1'b1)begin
			reacquire_active_o <= 1'b0;         // 可靠波峰完成锚点建立
		end else begin
			reacquire_active_o <= reacquire_active_o; // 等待波峰期间保持状态
		end
	end

	// 连续无相交计数在精确相交时清零并在完整无相交周期递增
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_no_cross_o <= 4'd0;             // 复位清除周期故障计数
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_known_cross_emit == 1'b1 || flag_no_cross_reacquire == 1'b1 || flag_fallback_commit == 1'b1)begin
			cnt_no_cross_o <= 4'd0;             // 新RUN、异常返回、相交成功或重获触发后清零
		end else if(flag_cycle_no_cross == 1'b1)begin
			cnt_no_cross_o <= cnt_no_cross_o + 4'd1; // 每个完整无相交周期累计一次
		end else begin
			cnt_no_cross_o <= cnt_no_cross_o;   // 不完整周期不影响故障计数
		end
	end

	// 最近lead只在时间已知且周期完整时更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			last_lead_frames_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清空提前量诊断
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1)begin
			last_lead_frames_o <= {C_FRAME_ID_WIDTH{1'b0}}; // 新RUN或异常重获重新统计相交时刻
		end else if(flag_cycle_complete == 1'b1 && flag_pending_cross_valid == 1'b1)begin
			last_lead_frames_o <= reg_arith_lead_frames; // 保存捕获的新波峰减旧相交帧号
		end else begin
			last_lead_frames_o <= last_lead_frames_o; // 无精确相交时不伪造lead
		end
	end

	// 斜率限幅诊断描述最近一次完整自适应提交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			slope_saturation_min_o <= 1'b0;     // 复位清除最负限幅诊断
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1)begin
			slope_saturation_min_o <= 1'b0;     // 新RUN从未限幅状态开始
		end else if(flag_cycle_complete == 1'b1 && i_slope_mode == SLOPE_MODE_ADAPTIVE)begin
			slope_saturation_min_o <= flag_slope_clamp_min; // 记录候选触及最负边界
		end else begin
			slope_saturation_min_o <= slope_saturation_min_o; // 非更新周期保留最近结果
		end
	end

	// 近零限幅标志与最负标志互相独立
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			slope_saturation_max_o <= 1'b0;     // 复位清除近零限幅诊断
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1)begin
			slope_saturation_max_o <= 1'b0;     // 新RUN重新观察斜率边界
		end else if(flag_cycle_complete == 1'b1 && i_slope_mode == SLOPE_MODE_ADAPTIVE)begin
			slope_saturation_max_o <= flag_slope_clamp_max; // 记录候选触及最接近零边界
		end else begin
			slope_saturation_max_o <= slope_saturation_max_o; // 无新候选时保持诊断
		end
	end

	// 基线24-bit端点诊断在每笔正式RED比较时刷新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			baseline_saturation_low_o <= 1'b0;  // 复位清除基线负端点诊断
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1)begin
			baseline_saturation_low_o <= 1'b0;  // 新RUN重新观察基线范围
		end else if(flag_formal_red_result == 1'b1 && baseline_valid_o == 1'b1 && flag_result_frame_legal == 1'b1)begin
			baseline_saturation_low_o <= (dec_baseline_q16 < PPG_Q16_MIN); // 标记低于统一PPG负端点
		end else begin
			baseline_saturation_low_o <= baseline_saturation_low_o; // 非比较事务保持最近诊断
		end
	end

	// 基线正端点诊断与负端点采用同一正式样本时刻
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			baseline_saturation_high_o <= 1'b0; // 复位清除基线正端点诊断
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1)begin
			baseline_saturation_high_o <= 1'b0; // 新RUN清理旧范围状态
		end else if(flag_formal_red_result == 1'b1 && baseline_valid_o == 1'b1 && flag_result_frame_legal == 1'b1)begin
			baseline_saturation_high_o <= (dec_baseline_q16 > PPG_Q16_MAX); // 标记高于统一PPG正端点
		end else begin
			baseline_saturation_high_o <= baseline_saturation_high_o; // 非比较事务保留最近诊断
		end
	end

	// 协议错误sticky覆盖非法配置、异常帧差和错误事件顺序
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			protocol_error_sticky_o <= 1'b0;    // 复位清除全部协议诊断
		end else if(flag_control_clear == 1'b1)begin
			protocol_error_sticky_o <= 1'b0;    // STOP或abort结束旧RUN诊断
		end else if(i_start_ack_event == 1'b1)begin
			protocol_error_sticky_o <= (flag_config_legal == 1'b0); // 非法ACTIVE不允许静默启动
		end else if((flag_reacquire_clear == 1'b1 && i_fine_window_active == 1'b1) || flag_arithmetic_error_event == 1'b1 || (flag_formal_red_result == 1'b1 && baseline_valid_o == 1'b1 && (flag_result_frame_legal == 1'b0)) || (flag_peak_transfer == 1'b1 && flag_pending_baseline_valid == 1'b1 && (flag_pending_period_legal == 1'b0)) || (flag_valley_transfer == 1'b1 && ((baseline_valid_o == 1'b0) || (flag_valley_order_legal == 1'b0))) || (flag_peak_transfer == 1'b1 && flag_valley_transfer == 1'b1) || ((flag_known_cross_emit == 1'b1 || flag_unknown_cross_emit == 1'b1) && cross_valid_o == 1'b1))begin
			protocol_error_sticky_o <= 1'b1;    // 保存帧序、事件顺序或输出溢出错误
		end else begin
			protocol_error_sticky_o <= protocol_error_sticky_o; // 正常运行期间保持已发现问题
		end
	end

	//---------------状态机区域---------------//
	// 算术状态寄存器在任一生命周期撤销后立即回到空闲态
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_IDLE;         // 异步复位终止全部阶段B运算
		end else begin
			state_current <= state_next;      // 每个2 MHz沿提交完整next-state译码
		end
	end

	// 下一状态逻辑优先处理撤销、上游违约、超时和配置漂移
	always@(*)begin
		state_next = state_current;           // 默认保持当前算术阶段
		if(flag_arithmetic_cancel == 1'b1)begin
			state_next = ST_IDLE;             // STOP、abort、新START、异常重获或重检无条件撤销
		end else if(flag_state_invalid == 1'b1)begin
			state_next = ST_IDLE;             // 非法编码采用安全空闲恢复
		end else if(flag_peak_hold_violation == 1'b1)begin
			state_next = ST_IDLE;             // 失去波峰事务所有权后禁止继续提交
		end else if(flag_arithmetic_timeout == 1'b1)begin
			state_next = ST_TIMEOUT_FALLBACK; // 达到128周期上限时转固定斜率回退
		end else if(flag_pending_config_violation == 1'b1)begin
			state_next = ST_TIMEOUT_FALLBACK; // ACTIVE漂移不得混用捕获前后配置
		end else begin
			case(state_current)
				ST_IDLE:begin
					if(flag_peak_capture_event == 1'b1)begin
						state_next = ST_CAPTURE; // 先冻结波峰和旧周期再决定算术路径
					end else begin
						state_next = ST_IDLE; // 无波峰valid时保持普通事务开放
					end
				end
				ST_CAPTURE:begin
					if(flag_pending_adaptive_request == 1'b1)begin
						state_next = ST_MUL_ALPHA; // 完整周期进入多周期自适应计算
					end else begin
						state_next = ST_WAIT_PEAK_COMMIT; // 首峰、固定或重获路径直接等待提交
					end
				end
				ST_MUL_ALPHA:begin
					state_next = ST_PREPARE_DIVIDE; // alpha乘积寄存后准备除法操作数
				end
				ST_PREPARE_DIVIDE:begin
					if(flag_divide_zero == 1'b1)begin
						state_next = ST_TIMEOUT_FALLBACK; // 零分母不进入迭代器
					end else begin
						state_next = ST_DIVIDE; // 非零周期启动固定42次恢复除法
					end
				end
				ST_DIVIDE:begin
					if(cnt_divide_iteration == C_DIVIDE_LAST_ITERATION)begin
						state_next = ST_BUILD_SLOPE_BASE; // 第42位商写入后构建负基础斜率
					end else begin
						state_next = ST_DIVIDE; // 未完成42位前保持逐位迭代
					end
				end
				ST_BUILD_SLOPE_BASE:begin
					state_next = ST_MUL_BETA; // 饱和基础斜率就绪后计算平滑项
				end
				ST_MUL_BETA:begin
					state_next = ST_ROUND_BETA; // 共享beta操作寄存后执行对称舍入
				end
				ST_ROUND_BETA:begin
					state_next = ST_MUL_ADJUST; // signed平滑增量完成后计算时刻步长
				end
				ST_MUL_ADJUST:begin
					state_next = ST_ROUND_ADJUST; // 共享adjust操作寄存后恢复Q16
				end
				ST_ROUND_ADJUST:begin
					state_next = ST_CLAMP;    // 调整方向和步长就绪后合成候选
				end
				ST_CLAMP:begin
					state_next = ST_WAIT_PEAK_COMMIT; // 全部结果寄存后开放原子握手
				end
				ST_WAIT_PEAK_COMMIT:begin
					if(flag_peak_commit == 1'b1)begin
						state_next = ST_IDLE; // 新锚点和全部结果同拍提交后释放接口
					end else begin
						state_next = ST_WAIT_PEAK_COMMIT; // 上游保持valid时ready持续为高
					end
				end
				ST_TIMEOUT_FALLBACK:begin
					state_next = ST_WAIT_PEAK_COMMIT; // 固定斜率回退结果准备完毕后提交波峰
				end
				default:begin
					state_next = ST_IDLE;     // 状态软错误不允许永久占用ready
				end
			endcase
		end
	end

	//-----------状态任务处理区域-----------//
	// 算术总周期计数在捕获时清零并于WAIT前饱和停止
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_arithmetic_cycles <= 7'd0;  // 复位清除阶段B有界反压计时
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			cnt_arithmetic_cycles <= 7'd0;  // 撤销或正式提交释放本次计时上下文
		end else if(flag_peak_capture_event == 1'b1)begin
			cnt_arithmetic_cycles <= 7'd0;  // 捕获波峰定义为算术周期零
		end else if(flag_pending_valid == 1'b1 && state_current != ST_WAIT_PEAK_COMMIT && state_current != ST_TIMEOUT_FALLBACK && cnt_arithmetic_cycles < C_SLOPE_UPDATE_MAX_CYCLES)begin
			cnt_arithmetic_cycles <= cnt_arithmetic_cycles + 7'd1; // 每个非提交阶段增加一个2 MHz周期
		end else begin
			cnt_arithmetic_cycles <= cnt_arithmetic_cycles; // WAIT和饱和值禁止自然回绕
		end
	end

	// 除法位计数严格覆盖0至41且不依赖输入数值提前结束
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_divide_iteration <= 6'd0;   // 复位清除逐位迭代位置
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			cnt_divide_iteration <= 6'd0;   // 生命周期结束禁止旧位序继续运行
		end else if(state_current == ST_PREPARE_DIVIDE)begin
			cnt_divide_iteration <= 6'd0;   // 第一位迭代开始前指向位序零
		end else if(state_current == ST_DIVIDE && cnt_divide_iteration < C_DIVIDE_LAST_ITERATION)begin
			cnt_divide_iteration <= cnt_divide_iteration + 6'd1; // 每拍完成一个固定商位
		end else begin
			cnt_divide_iteration <= cnt_divide_iteration; // 最后一次迭代后保持41供状态跳转
		end
	end

	//-------------主要任务处理区域-------------//
	// pending有效标志描述波峰从观察捕获到正式提交的临时所有权
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_valid <= 1'b0;         // 复位后没有暂存波峰事务
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || flag_state_invalid == 1'b1)begin
			flag_pending_valid <= 1'b0;         // 撤销、违约、提交或非法状态释放所有权
		end else if(flag_peak_capture_event == 1'b1)begin
			flag_pending_valid <= 1'b1;         // IDLE观察valid后开始要求上游保持载荷
		end else begin
			flag_pending_valid <= flag_pending_valid; // 计算和WAIT期间持续占有事务
		end
	end

	// 自适应请求在捕获沿冻结且重新获取周期禁止启动除法
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_adaptive_request <= 1'b0; // 复位清除多周期路径资格
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			flag_pending_adaptive_request <= 1'b0; // 事务结束后不继承旧算术资格
		end else if(flag_peak_capture_event == 1'b1)begin
			flag_pending_adaptive_request <= flag_cycle_candidate_complete && (i_slope_mode == SLOPE_MODE_ADAPTIVE) && (flag_candidate_no_cross_reacquire == 1'b0); // 仅完整非重获周期进入阶段B
		end else begin
			flag_pending_adaptive_request <= flag_pending_adaptive_request; // 迭代期间保持启动判定
		end
	end

	//-----------状态任务处理区域-----------//
	// 完整自适应结果只在CLAMP状态生成并在异常回退时撤销
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_adaptive_result_valid <= 1'b0; // 复位后没有待提交自适应斜率
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || state_current == ST_TIMEOUT_FALLBACK)begin
			flag_pending_adaptive_result_valid <= 1'b0; // 撤销或回退禁止提交部分算术结果
		end else if(state_current == ST_CLAMP)begin
			flag_pending_adaptive_result_valid <= 1'b1; // 限幅结果写入后声明全部阶段完成
		end else begin
			flag_pending_adaptive_result_valid <= flag_pending_adaptive_result_valid; // 其他状态保持结果资格
		end
	end

	// fallback标志区分除零、超时和配置漂移的固定斜率提交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_fallback <= 1'b0;  // 复位后没有异常提交事务
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || flag_peak_capture_event == 1'b1)begin
			flag_pending_fallback <= 1'b0;  // 新捕获和事务结束均从正常路径开始
		end else if(state_current == ST_TIMEOUT_FALLBACK)begin
			flag_pending_fallback <= 1'b1;  // 回退状态锁存固定斜率提交属性
		end else begin
			flag_pending_fallback <= flag_pending_fallback; // WAIT期间保持诊断属性
		end
	end

	//-------------主要任务处理区域-------------//
	// 捕获时保存旧基线资格供即时路径原子更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_baseline_valid <= 1'b0; // 复位清除旧锚点资格快照
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			flag_pending_baseline_valid <= 1'b0; // 事务释放后删除过期基线资格
		end else if(flag_peak_capture_event == 1'b1)begin
			flag_pending_baseline_valid <= baseline_valid_o; // 冻结捕获前是否已经存在锚点
		end else begin
			flag_pending_baseline_valid <= flag_pending_baseline_valid; // busy期间不观察外部状态变化
		end
	end

	// 周期合法性快照决定新峰是否可替换旧锚点
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_period_legal <= 1'b0;  // 复位后没有峰峰周期
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			flag_pending_period_legal <= 1'b0;  // 释放事务时清除周期判断
		end else if(flag_peak_capture_event == 1'b1)begin
			flag_pending_period_legal <= flag_peak_period_legal; // 冻结新旧峰帧差合法性
		end else begin
			flag_pending_period_legal <= flag_pending_period_legal; // 迭代期间不重算帧差
		end
	end

	// ACTIVE合法性在捕获沿冻结用于最终基线资格提交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_config_legal <= 1'b0;  // 复位后没有运行配置资格
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			flag_pending_config_legal <= 1'b0;  // 事务结束后删除旧配置判断
		end else if(flag_peak_capture_event == 1'b1)begin
			flag_pending_config_legal <= flag_config_legal; // 保存本次波峰使用的配置合法性
		end else begin
			flag_pending_config_legal <= flag_pending_config_legal; // pending期间禁止后续ACTIVE覆盖
		end
	end

	// 无相交属性在捕获时冻结供计数和时刻修正共同使用
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_no_cross <= 1'b0;      // 复位后没有周期统计含义
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			flag_pending_no_cross <= 1'b0;      // 事务结束清除旧周期属性
		end else if(flag_peak_capture_event == 1'b1)begin
			flag_pending_no_cross <= flag_cycle_candidate_no_cross; // 冻结本周期是否缺少精确相交
		end else begin
			flag_pending_no_cross <= flag_pending_no_cross; // 多周期运算期间保持原判定
		end
	end

	// 达到无相交限制的周期走固定斜率重新获取即时路径
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_no_cross_reacquire <= 1'b0; // 复位后不触发重新获取
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			flag_pending_no_cross_reacquire <= 1'b0; // 提交或撤销后清除一次性动作
		end else if(flag_peak_capture_event == 1'b1)begin
			flag_pending_no_cross_reacquire <= flag_candidate_no_cross_reacquire; // 捕获计数达到限制的周期
		end else begin
			flag_pending_no_cross_reacquire <= flag_pending_no_cross_reacquire; // WAIT前保持重获决定
		end
	end

	// 捕获周期的相交资格决定lead诊断与修正方向
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_cross_valid <= 1'b0;   // 复位清除精确相交快照
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			flag_pending_cross_valid <= 1'b0;   // 事务结束删除旧lead资格
		end else if(flag_peak_capture_event == 1'b1)begin
			flag_pending_cross_valid <= flag_cycle_cross_valid; // 冻结当前周期精确相交属性
		end else begin
			flag_pending_cross_valid <= flag_pending_cross_valid; // busy期间不被周期清理覆盖
		end
	end

	//-----------状态任务处理区域-----------//
	// 限幅低标志仅在CLAMP状态从冻结边界比较结果更新
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_clamp_min <= 1'b0; // 复位清除待提交低限幅诊断
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || state_current == ST_TIMEOUT_FALLBACK)begin
			flag_pending_clamp_min <= 1'b0; // 回退路径不得携带部分限幅结果
		end else if(state_current == ST_CLAMP)begin
			flag_pending_clamp_min <= flag_pending_candidate_clamp_min; // 锁存候选触及最负边界
		end else begin
			flag_pending_clamp_min <= flag_pending_clamp_min; // 其他阶段保持最终诊断
		end
	end

	// 限幅高标志与低标志独立保存并同拍提交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pending_clamp_max <= 1'b0; // 复位清除待提交高限幅诊断
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || state_current == ST_TIMEOUT_FALLBACK)begin
			flag_pending_clamp_max <= 1'b0; // 异常固定路径不声明自适应夹紧
		end else if(state_current == ST_CLAMP)begin
			flag_pending_clamp_max <= flag_pending_candidate_clamp_max; // 锁存候选触及近零边界
		end else begin
			flag_pending_clamp_max <= flag_pending_clamp_max; // 等待正式波峰握手时保持
		end
	end

	//-------------主要任务处理区域-------------//
	// 三个峰谷上下文快照为本次算术隔离全部值和epoch
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_old_peak_context <= {PEAK_CONTEXT_WIDTH{1'b0}}; // 复位清空旧锚点快照
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_old_peak_context <= {PEAK_CONTEXT_WIDTH{1'b0}}; // 事务释放后删除旧周期副本
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_old_peak_context <= reg_peak_context; // 原子保存旧波峰值、时间和版本
		end else begin
			reg_arith_old_peak_context <= reg_arith_old_peak_context; // 运算期间保持不可变
		end
	end

	// 波谷快照保留本周期幅度证据及其独立元数据
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_valley_context <= {VALLEY_CONTEXT_WIDTH{1'b0}}; // 复位清空冻结波谷
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_valley_context <= {VALLEY_CONTEXT_WIDTH{1'b0}}; // 结束事务后释放波谷副本
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_valley_context <= reg_valley_context; // 保存旧周期运行最小值与epoch
		end else begin
			reg_arith_valley_context <= reg_arith_valley_context; // 有界反压期间保持旧证据
		end
	end

	// 新波峰快照在ready为零时必须与上游保持载荷逐位一致
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_new_peak_context <= {PEAK_CONTEXT_WIDTH{1'b0}}; // 复位清除待提交波峰
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_new_peak_context <= {PEAK_CONTEXT_WIDTH{1'b0}}; // 提交或违约后释放快照
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_new_peak_context <= {i_peak_value, i_peak_frame_id, i_peak_sample_index, i_peak_config_epoch, i_peak_coef_epoch, i_peak_dc_recovery_coef_epoch}; // 捕获完整波峰载荷
		end else begin
			reg_arith_new_peak_context <= reg_arith_new_peak_context; // 算术busy期间保持原子字段
		end
	end

	// 相交快照保留旧周期的精确时间和版本供lead闭环使用
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_cycle_cross_context <= {EVENT_CONTEXT_WIDTH{1'b0}}; // 复位清空旧相交证据
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_cycle_cross_context <= {EVENT_CONTEXT_WIDTH{1'b0}}; // 事务完成后释放相交副本
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_cycle_cross_context <= reg_cycle_cross_context; // 原子冻结frame、epoch和诊断载荷
		end else begin
			reg_arith_cycle_cross_context <= reg_arith_cycle_cross_context; // 计算期间禁止活动状态清理影响
		end
	end

	// 活动斜率快照是beta平滑的旧周期参考值
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_slope_current_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 复位清除旧活动斜率快照
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_slope_current_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 事务释放后清除算术操作数
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_slope_current_q16 <= slope_current_q16_o; // 捕获本周期实际使用的负斜率
		end else begin
			reg_arith_slope_current_q16 <= reg_arith_slope_current_q16; // 多周期计算不读取活动输出
		end
	end

	// 固定斜率快照供即时模式和所有异常回退使用
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_fixed_slope_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 复位清除回退值
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_fixed_slope_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 事务结束移除旧配置快照
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_fixed_slope_q16 <= i_fixed_slope_q16; // 保存捕获时的SPI固定负斜率
		end else begin
			reg_arith_fixed_slope_q16 <= reg_arith_fixed_slope_q16; // ACTIVE漂移时仍使用原快照回退
		end
	end

	// alpha比例只在波峰捕获沿采样一次
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_alpha_q15 <= {C_RATIO_WIDTH{1'b0}}; // 复位清除幅度比例操作数
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_alpha_q15 <= {C_RATIO_WIDTH{1'b0}}; // 释放事务时清除旧比例
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_alpha_q15 <= i_alpha_q15; // 冻结A到基础斜率的Q1.15比例
		end else begin
			reg_arith_alpha_q15 <= reg_arith_alpha_q15; // 阶段B执行期间保持常量
		end
	end

	// beta比例快照隔离RUN期间的配置变化
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_beta_q15 <= {C_RATIO_WIDTH{1'b0}}; // 复位清除平滑比例操作数
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_beta_q15 <= {C_RATIO_WIDTH{1'b0}}; // 事务释放后移除旧beta
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_beta_q15 <= i_beta_q15;   // 保存逐周期平滑的Q1.15比例
		end else begin
			reg_arith_beta_q15 <= reg_arith_beta_q15; // 运算状态不重新采样SPI字段
		end
	end

	// 时刻调整比例快照供独立adjust乘法器使用
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_adjust_ratio_q15 <= {C_RATIO_WIDTH{1'b0}}; // 复位清除lead调整比例
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_adjust_ratio_q15 <= {C_RATIO_WIDTH{1'b0}}; // 事务完成后清除调整操作数
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_adjust_ratio_q15 <= i_timing_adjust_ratio_q15; // 冻结相对调整步长比例
		end else begin
			reg_arith_adjust_ratio_q15 <= reg_arith_adjust_ratio_q15; // busy期间保持配置隔离
		end
	end

	// 最负斜率边界快照用于CLAMP阶段精确比较
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_slope_min_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 复位清除低边界快照
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_slope_min_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 事务结束移除旧边界
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_slope_min_q16 <= i_slope_min_q16; // 冻结最负允许斜率
		end else begin
			reg_arith_slope_min_q16 <= reg_arith_slope_min_q16; // 算术期间边界不可变化
		end
	end

	// 近零斜率边界快照与低边界独立保持
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_slope_max_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 复位清除高边界快照
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_slope_max_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 完成事务后清除近零边界
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_slope_max_q16 <= i_slope_max_q16; // 冻结最接近零的负斜率
		end else begin
			reg_arith_slope_max_q16 <= reg_arith_slope_max_q16; // 多周期计算保持边界稳定
		end
	end

	// lead窗口下界快照用于判定相交是否过晚
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_lead_min_frames <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除提前量下界
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_lead_min_frames <= {C_FRAME_ID_WIDTH{1'b0}}; // 事务结束释放窗口快照
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_lead_min_frames <= i_lead_min_frames; // 保存合格提前量最小帧数
		end else begin
			reg_arith_lead_min_frames <= reg_arith_lead_min_frames; // 舍入阶段读取冻结窗口
		end
	end

	// lead窗口上界快照用于判定相交是否过早
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_lead_max_frames <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除提前量上界
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_lead_max_frames <= {C_FRAME_ID_WIDTH{1'b0}}; // 事务结束删除旧窗口上界
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_lead_max_frames <= i_lead_max_frames; // 保存合格提前量最大帧数
		end else begin
			reg_arith_lead_max_frames <= reg_arith_lead_max_frames; // 时刻闭环期间保持常量
		end
	end

	// 无相交限制快照与捕获计数共同决定是否重获
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_no_cross_limit <= 4'd0;   // 复位清除周期故障限制
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_no_cross_limit <= 4'd0;   // 提交后删除旧限制快照
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_no_cross_limit <= i_no_cross_limit; // 冻结重新获取阈值
		end else begin
			reg_arith_no_cross_limit <= reg_arith_no_cross_limit; // pending期间保持阈值
		end
	end

	// 捕获无相交计数用于诊断事务与旧周期上下文一致性
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_arith_no_cross <= 4'd0;         // 复位清除累计值快照
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			cnt_arith_no_cross <= 4'd0;         // 事务完成后释放旧累计值
		end else if(flag_peak_capture_event == 1'b1)begin
			cnt_arith_no_cross <= cnt_no_cross_o; // 保存捕获前的连续无相交次数
		end else begin
			cnt_arith_no_cross <= cnt_arith_no_cross; // 运算期间保持统计快照
		end
	end

	// 正峰谷幅度在捕获沿转换为无符号25-bit操作数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_cycle_amplitude <= 25'd0; // 复位清除alpha乘法幅度
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_cycle_amplitude <= 25'd0; // 事务结束删除旧峰谷差
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_cycle_amplitude <= dec_cycle_amplitude[24:0]; // 冻结P减V的正幅度
		end else begin
			reg_arith_cycle_amplitude <= reg_arith_cycle_amplitude; // 后续状态不再读取活动峰谷
		end
	end

	// 峰峰周期快照是顺序除法器唯一正式分母
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_period_frames <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除除法周期
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_period_frames <= {C_FRAME_ID_WIDTH{1'b0}}; // 事务结束清除除数来源
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_period_frames <= dec_peak_period_frames; // 保存新峰减旧峰的短帧差
		end else begin
			reg_arith_period_frames <= reg_arith_period_frames; // 42次迭代期间分母不可变
		end
	end

	// lead快照在新波峰到达时计算且不受后续事件清理影响
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_lead_frames <= {C_FRAME_ID_WIDTH{1'b0}}; // 复位清除时刻闭环操作数
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_lead_frames <= {C_FRAME_ID_WIDTH{1'b0}}; // 事务释放后清除旧lead
		end else if(flag_peak_capture_event == 1'b1)begin
			reg_arith_lead_frames <= dec_lead_frames; // 保存下一波峰减旧相交帧号
		end else begin
			reg_arith_lead_frames <= reg_arith_lead_frames; // 调整状态始终使用捕获值
		end
	end

	//-----------状态任务处理区域-----------//
	// alpha乘积在专用状态补偿Q15到Q16的一位比例
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_base_numerator <= 42'd0;    // 复位清除基础斜率分子
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_base_numerator <= 42'd0;    // 事务结束禁止旧乘积复用
		end else if(state_current == ST_MUL_ALPHA)begin
			reg_base_numerator <= {dec_shared_product[40:0], 1'b0}; // 捕获共享乘积并形成A乘alpha再乘2的42-bit正分子
		end else begin
			reg_base_numerator <= reg_base_numerator; // 非alpha状态停止该乘法结果翻转
		end
	end

	// 最近舍入分子在除法初始化状态一次性保存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_base_rounded_numerator <= 42'd0; // 复位清除顺序除法被除数
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_base_rounded_numerator <= 42'd0; // 撤销时禁止部分分子后续写回
		end else if(state_current == ST_PREPARE_DIVIDE)begin
			reg_base_rounded_numerator <= dec_arith_rounded_numerator; // 保存加半分母后的精确42-bit值
		end else begin
			reg_base_rounded_numerator <= reg_base_rounded_numerator; // 除法期间保持原始诊断输入
		end
	end

	// 被除数移位寄存器每个DIVIDE周期固定左移一位
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_div_input_data <= 42'd0;    // 复位清除逐位输入序列
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_div_input_data <= 42'd0;    // 撤销计算时删除未处理位
		end else if(state_current == ST_PREPARE_DIVIDE)begin
			reg_div_input_data <= dec_arith_rounded_numerator; // 初始化完整42-bit被除数
		end else if(state_current == ST_DIVIDE)begin
			reg_div_input_data <= {reg_div_input_data[40:0], 1'b0}; // 每拍向余数送入当前最高位
		end else begin
			reg_div_input_data <= reg_div_input_data; // 非迭代状态停止移位
		end
	end

	// 除数在PREPARE状态锁存并贯穿全部42次迭代
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_divisor <= 16'd0;           // 复位清除周期分母
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_divisor <= 16'd0;           // 事务结束释放除法操作数
		end else if(state_current == ST_PREPARE_DIVIDE)begin
			reg_divisor <= reg_arith_period_frames[15:0]; // 锁存冻结峰峰周期
		end else begin
			reg_divisor <= reg_divisor;     // 迭代期间保持分母稳定
		end
	end

	// 恢复余数从零开始并在每个迭代沿保存试减结果
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_div_remainder <= 17'd0;     // 复位清除除法余数
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_div_remainder <= 17'd0;     // 撤销时丢弃部分余数
		end else if(state_current == ST_PREPARE_DIVIDE)begin
			reg_div_remainder <= 17'd0;     // 新被除数从空余数开始
		end else if(state_current == ST_DIVIDE)begin
			reg_div_remainder <= dec_div_remainder_next; // 保存当前商位对应的恢复余数
		end else begin
			reg_div_remainder <= reg_div_remainder; // 非DIVIDE状态保持最终余数
		end
	end

	// 42-bit商每拍左移并在最低位写入当前比较结果
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_div_quotient <= 42'd0;      // 复位清除顺序除法商
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_div_quotient <= 42'd0;      // 生命周期撤销禁止旧商迟到提交
		end else if(state_current == ST_PREPARE_DIVIDE)begin
			reg_div_quotient <= 42'd0;      // 每次除法从空商开始构造
		end else if(state_current == ST_DIVIDE)begin
			reg_div_quotient <= dec_div_quotient_next; // 逐位写入完整无符号商
		end else begin
			reg_div_quotient <= reg_div_quotient; // 构建基础斜率前保持最终商
		end
	end

	// 基础斜率在完整商产生后取负并排除signed最小值
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_slope_base_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 复位清除待提交基础斜率
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || state_current == ST_TIMEOUT_FALLBACK)begin
			reg_arith_slope_base_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 回退不得使用部分商结果
		end else if(state_current == ST_BUILD_SLOPE_BASE)begin
			reg_arith_slope_base_q16 <= (dec_arith_slope_base_wide < -43'sd2147483647) ? -32'sd2147483647 : dec_arith_slope_base_wide[C_SLOPE_WIDTH - 1:0]; // 完整43-bit比较后饱和
		end else begin
			reg_arith_slope_base_q16 <= reg_arith_slope_base_q16; // 后续乘法使用稳定基础斜率
		end
	end

	// beta共享乘法结果只在对应状态写入平滑专用寄存器
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_smooth_product <= 50'sd0;   // 复位清除平滑乘积
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_smooth_product <= 50'sd0;   // 事务终止禁止旧乘积被舍入
		end else if(state_current == ST_MUL_BETA)begin
			reg_smooth_product <= dec_shared_product; // 保存共享乘法器的完整signed平滑结果
		end else begin
			reg_smooth_product <= reg_smooth_product; // 其他状态停止beta结果寄存器翻转
		end
	end

	// signed平滑增量在ROUND_BETA状态对称舍入并恢复符号
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_smooth_delta <= 34'sd0; // 复位清除待提交平滑项
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || state_current == ST_TIMEOUT_FALLBACK)begin
			reg_arith_smooth_delta <= 34'sd0; // 异常路径不保留部分平滑值
		end else if(state_current == ST_ROUND_BETA)begin
			reg_arith_smooth_delta <= dec_arith_smooth_delta; // 保存去除Q15小数位的34-bit增量
		end else begin
			reg_arith_smooth_delta <= reg_arith_smooth_delta; // CLAMP前保持舍入结果
		end
	end

	// adjust共享乘法结果只在MUL_ADJUST状态更新专用乘积
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_adjust_product <= 48'd0;    // 复位清除时刻调整乘积
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_adjust_product <= 48'd0;    // 撤销时删除未舍入乘积
		end else if(state_current == ST_MUL_ADJUST)begin
			reg_adjust_product <= dec_shared_product[47:0]; // 保存共享乘法器的正调整比例结果
		end else begin
			reg_adjust_product <= reg_adjust_product; // 非调整状态关闭寄存器写使能
		end
	end

	// 正调整步长在ROUND_ADJUST状态执行最近舍入且禁止退化为零
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_adjust_step <= 33'sd0; // 复位清除时刻修正幅值
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || state_current == ST_TIMEOUT_FALLBACK)begin
			reg_arith_adjust_step <= 33'sd0; // 回退路径丢弃旧调整步长
		end else if(state_current == ST_ROUND_ADJUST)begin
			reg_arith_adjust_step <= dec_arith_adjust_step; // 保存至少一个LSB的正步长
		end else begin
			reg_arith_adjust_step <= reg_arith_adjust_step; // 等待CLAMP时保持幅值
		end
	end

	// timing项按无相交、过晚、合格和过早四种情况选择符号
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_timing_term <= 33'sd0; // 复位清除lead修正项
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1 || state_current == ST_TIMEOUT_FALLBACK)begin
			reg_arith_timing_term <= 33'sd0; // 异常回退不提交部分时刻修正
		end else if(state_current == ST_ROUND_ADJUST)begin
			reg_arith_timing_term <= (flag_pending_cross_valid == 1'b0) ? -dec_arith_adjust_step : ((reg_arith_lead_frames < reg_arith_lead_min_frames) ? -dec_arith_adjust_step : ((reg_arith_lead_frames > reg_arith_lead_max_frames) ? dec_arith_adjust_step : 33'sd0)); // 晚或无相交更负且早相交减弱负斜率
		end else begin
			reg_arith_timing_term <= reg_arith_timing_term; // 候选合成前保持修正方向
		end
	end

	// 下一活动斜率在捕获时准备即时值并于CLAMP或回退状态覆盖
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_arith_slope_next_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 复位清除待提交活动斜率
		end else if(flag_arithmetic_cancel == 1'b1 || flag_peak_hold_violation == 1'b1 || flag_peak_commit == 1'b1)begin
			reg_arith_slope_next_q16 <= {C_SLOPE_WIDTH{1'b0}}; // 事务释放后禁止旧结果迟到写回
		end else if(flag_peak_capture_event == 1'b1)begin
			if(flag_candidate_no_cross_reacquire == 1'b1 || (baseline_valid_o == 1'b1 && flag_peak_period_legal == 1'b0) || i_slope_mode == SLOPE_MODE_FIXED || flag_current_slope_legal == 1'b0)begin
				reg_arith_slope_next_q16 <= i_fixed_slope_q16; // 即时重获、异常周期和固定模式使用SPI值
			end else begin
				reg_arith_slope_next_q16 <= slope_current_q16_o; // 首峰或不完整周期保持旧活动斜率
			end
		end else if(state_current == ST_CLAMP)begin
			reg_arith_slope_next_q16 <= dec_arith_clamped_slope_q16; // 保存完整自适应候选
		end else if(state_current == ST_TIMEOUT_FALLBACK)begin
			reg_arith_slope_next_q16 <= reg_arith_fixed_slope_q16; // 超时、除零或配置漂移统一回退
		end else begin
			reg_arith_slope_next_q16 <= reg_arith_slope_next_q16; // WAIT期间保持原子提交值
		end
	end

	//-------------主要任务处理区域-------------//
	// 波峰上下文在每个接受事件上原子替换
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_peak_context <= {PEAK_CONTEXT_WIDTH{1'b0}}; // 复位清空锚点数值和版本
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || (i_recheck_done_event == 1'b1 && (i_recheck_success == 1'b0)))begin
			reg_peak_context <= {PEAK_CONTEXT_WIDTH{1'b0}}; // 异常返回或重检失败禁止使用旧锚点时间
		end else if(flag_peak_transfer == 1'b1 && flag_no_cross_reacquire == 1'b0 && (flag_pending_period_legal == 1'b1 || (flag_pending_baseline_valid == 1'b0)))begin
			reg_peak_context <= reg_arith_new_peak_context; // pending波峰与斜率及诊断同拍成为下一周期起点
		end else begin
			reg_peak_context <= reg_peak_context; // 非波峰事件保持当前锚点；RRC-04/RRC-09 accept不在本always块的作废条件里，整个busy窗口原样保持，成功恢复后原样复用为新基线起点 @satisfies: RRC-04, RRC-09
		end
	end

	// 波谷上下文只接受当前锚点之后且epoch一致的事件
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_valley_context <= {VALLEY_CONTEXT_WIDTH{1'b0}}; // 复位清空周期波谷
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1)begin
			reg_valley_context <= {VALLEY_CONTEXT_WIDTH{1'b0}}; // 新周期、异常返回或重检使旧波谷失去资格
		end else if(flag_valley_transfer == 1'b1 && baseline_valid_o == 1'b1 && flag_valley_order_legal == 1'b1 && (i_valley_config_epoch == dec_peak_config_epoch) && (i_valley_coef_epoch == dec_peak_coef_epoch) && (i_valley_dc_recovery_coef_epoch == dec_peak_dc_epoch))begin
			reg_valley_context <= {i_valley_value, i_valley_frame_id, i_valley_sample_index, i_valley_config_epoch, i_valley_coef_epoch, i_valley_dc_recovery_coef_epoch}; // 保存本周期可靠运行最小值
		end else begin
			reg_valley_context <= reg_valley_context; // 无合格波谷时保持旧值
		end
	end

	// 波谷valid与波谷上下文采用相同生命周期边界
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_valley_valid <= 1'b0;          // 复位时当前周期没有波谷
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1)begin
			flag_valley_valid <= 1'b0;          // 新周期、异常返回和重检清除旧幅度证据
		end else if(flag_valley_transfer == 1'b1 && baseline_valid_o == 1'b1 && flag_valley_order_legal == 1'b1 && (i_valley_config_epoch == dec_peak_config_epoch) && (i_valley_coef_epoch == dec_peak_coef_epoch) && (i_valley_dc_recovery_coef_epoch == dec_peak_dc_epoch))begin
			flag_valley_valid <= 1'b1;          // 合格波谷允许后续计算A[n]
		end else begin
			flag_valley_valid <= flag_valley_valid; // 未出现新事件时保持资格
		end
	end

	// 首次越过上下文在候选建立时保存精确中心元数据
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_candidate_context <= {EVENT_CONTEXT_WIDTH{1'b0}}; // 复位清空候选载荷
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1)begin
			reg_candidate_context <= {EVENT_CONTEXT_WIDTH{1'b0}}; // 周期边界或异常返回取消旧相交候选；RRC-04/RRC-10 accept原子作废旧相交候选，新上穿只能由accept之后的全新历史重新形成；NRE-02/NRE-05 interval=0时i_recheck_accept_event结构性恒为0，候选载荷不受隐藏重检清零，真实穿越身份只能绑定累积证据 @satisfies: RRC-04, RRC-10, NRE-02, NRE-05
		end else if(flag_candidate_start == 1'b1)begin
			reg_candidate_context <= {i_frame_id, i_sample_index, i_config_epoch, i_coef_epoch, i_dc_recovery_coef_epoch, slope_current_q16_o, dec_baseline_diagnostic_q16}; // 保存首次越过时刻而非确认末点
		end else begin
			reg_candidate_context <= reg_candidate_context; // 连续确认期间保持候选元数据
		end
	end

	// 候选活动标志在资格丢失、重检或确认结束时清除
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_candidate_active <= 1'b0;      // 复位时没有在途连续确认
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1)begin
			flag_candidate_active <= 1'b0;      // 新周期、异常返回和重检禁止沿用候选
		end else if(flag_candidate_complete == 1'b1 || flag_candidate_break == 1'b1 || (flag_result_transfer == 1'b1 && (i_color_ir == 1'b0) && (flag_cross_eligible_red_result == 1'b0)))begin
			flag_candidate_active <= 1'b0;      // 完成、跌落、fine状态或旧15-bit中心均取消候选
		end else if(flag_candidate_start == 1'b1)begin
			flag_candidate_active <= 1'b1;      // 首次越过进入连续确认阶段
		end else begin
			flag_candidate_active <= flag_candidate_active; // 等待下一正式RED样本时保持
		end
	end

	// 连续确认计数包含首次越过样本本身
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_cross_confirm <= 4'd0;          // 复位清零候选点数
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1 || flag_candidate_complete == 1'b1 || flag_candidate_break == 1'b1 || (flag_result_transfer == 1'b1 && (i_color_ir == 1'b0) && (flag_cross_eligible_red_result == 1'b0)))begin
			cnt_cross_confirm <= 4'd0;          // 候选结束、fine状态或旧15-bit中心切断连续计数
		end else if(flag_candidate_start == 1'b1)begin
			cnt_cross_confirm <= 4'd1;          // 首次越过定义为确认第一个点
		end else if(flag_candidate_continue == 1'b1)begin
			cnt_cross_confirm <= cnt_cross_confirm + 4'd1; // 每个连续上方样本增加一次
		end else begin
			cnt_cross_confirm <= cnt_cross_confirm; // 无正式候选样本时保持点数
		end
	end

	// below_seen确保基线从波峰出发时不会立即误判相交
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_below_seen <= 1'b0;            // 复位后尚未到达负迟滞下方
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1 || flag_known_cross_emit == 1'b1 || flag_unknown_cross_emit == 1'b1)begin
			flag_below_seen <= 1'b0;            // 新锚点、异常返回、重检或相交完成重新武装
		end else if(flag_result_transfer == 1'b1 && (i_color_ir == 1'b0) && (flag_cross_eligible_red_result == 1'b0))begin
			flag_below_seen <= 1'b0;            // 无资格、fine或旧15-bit中心要求重新观察9-bit低边界；尾部结束后可从重建证据里真实恢复(GROUP4_REBUILD_EVIDENCE) @satisfies: TOP-06
		end else if(flag_cross_eligible_red_result == 1'b1 && baseline_valid_o == 1'b1 && flag_result_frame_legal == 1'b1 && (dec_filtered_value_q16 <= dec_baseline_low_q16) && i_peak_valley_config_valid == 1'b1)begin
			flag_below_seen <= 1'b1;            // 合格9-bit中心样本到达负迟滞下方且V5资格有效时完成武装
		end else if(flag_candidate_break == 1'b1)begin
			flag_below_seen <= (dec_filtered_value_q16 <= dec_baseline_low_q16) && i_peak_valley_config_valid; // 候选失败时仅在V5资格有效时允许当前低样本重新武装
		end else begin
			flag_below_seen <= flag_below_seen; // 迟滞带内部保持历史武装状态
		end
	end

	// 前一样本上下文只跟踪允许比较的正式RED事务
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_previous_context <= {PREVIOUS_CONTEXT_WIDTH{1'b0}}; // 复位清空相邻样本比较历史
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1)begin
			reg_previous_context <= {PREVIOUS_CONTEXT_WIDTH{1'b0}}; // 新周期、异常返回和重检删除旧相邻关系
		end else if(flag_cross_eligible_red_result == 1'b1 && baseline_valid_o == 1'b1 && flag_result_frame_legal == 1'b1)begin
			reg_previous_context <= {dec_filtered_value_q16, dec_baseline_q16, i_frame_id}; // 保存当前中心帧比较值供下一点使用
		end else begin
			reg_previous_context <= reg_previous_context; // IR或fine事务不得改写RED历史
		end
	end

	// 前一样本资格在任一RED无资格事务出现时撤销
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_previous_valid <= 1'b0;        // 复位时没有相邻正式样本
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1)begin
			flag_previous_valid <= 1'b0;        // 新锚点、异常返回和重检要求重建相邻关系
		end else if(flag_result_transfer == 1'b1 && (i_color_ir == 1'b0) && (flag_cross_eligible_red_result == 1'b0))begin
			flag_previous_valid <= 1'b0;        // 无资格、fine或旧15-bit中心不能连接9-bit候选
		end else if(flag_cross_eligible_red_result == 1'b1 && baseline_valid_o == 1'b1 && flag_result_frame_legal == 1'b1)begin
			flag_previous_valid <= 1'b1;        // 保存一笔可与下个中心样本相邻比较的事务
		end else begin
			flag_previous_valid <= flag_previous_valid; // IR事务完全不影响RED连续性
		end
	end

	// 当前周期相交上下文用于下一波峰计算lead和epoch一致性
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_cycle_cross_context <= {EVENT_CONTEXT_WIDTH{1'b0}}; // 复位清空周期相交统计
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1)begin
			reg_cycle_cross_context <= {EVENT_CONTEXT_WIDTH{1'b0}}; // 新周期、异常返回和重检不继承精确相交时刻
		end else if(flag_known_cross_emit == 1'b1)begin
			reg_cycle_cross_context <= reg_candidate_context; // 保存首次越过时刻供周期闭环使用
		end else begin
			reg_cycle_cross_context <= reg_cycle_cross_context; // 非精确事件不改写lead统计
		end
	end

	// 精确相交资格不接受重检空窗的未知时刻替代
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_cycle_cross_valid <= 1'b0;     // 复位时当前周期没有相交
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1 || i_recheck_accept_event == 1'b1)begin
			flag_cycle_cross_valid <= 1'b0;     // 每个新周期、异常返回和重检重新统计
		end else if(flag_known_cross_emit == 1'b1)begin
			flag_cycle_cross_valid <= 1'b1;     // 只有时间已知的三点确认可参与lead闭环
		end else begin
			flag_cycle_cross_valid <= flag_cycle_cross_valid; // 未出现新精确相交时保持
		end
	end

	// 每个锚点周期最多产生一次相交请求
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_cross_issued <= 1'b0;          // 复位后没有周期请求
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || flag_peak_transfer == 1'b1)begin
			flag_cross_issued <= 1'b0;          // 新锚点或异常重获后重新允许一次请求
		end else if(flag_known_cross_emit == 1'b1 || flag_unknown_cross_emit == 1'b1)begin
			flag_cross_issued <= 1'b1;          // 精确或未知事件均占用本周期配额
		end else begin
			flag_cross_issued <= flag_cross_issued; // 普通fine切换不撤销请求事实
		end
	end

	// 重检使跨空窗周期失去自适应资格但不暂停基线数学时间
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_cycle_qualified <= 1'b0;       // 复位时没有完整周期统计
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1)begin
			flag_cycle_qualified <= 1'b0;       // 新RUN或异常重获等待第一个锚点周期
		end else if(i_recheck_accept_event == 1'b1)begin
			flag_cycle_qualified <= 1'b0;       // 跨三帧重检周期禁止更新斜率
		end else if(flag_peak_transfer == 1'b1 && flag_no_cross_reacquire == 1'b0)begin
			flag_cycle_qualified <= 1'b1;       // 新波峰开始一个新的完整性统计周期
		end else begin
			flag_cycle_qualified <= flag_cycle_qualified; // 普通9/15-bit切换保持周期资格
		end
	end

	// 重检成功后只检查第一笔正式恢复样本是否已经越过基线
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_resume_pending <= 1'b0;        // 复位时没有恢复检查
		end else if(i_start_ack_event == 1'b1 || flag_control_clear == 1'b1 || flag_reacquire_clear == 1'b1 || i_recheck_accept_event == 1'b1)begin
			flag_resume_pending <= 1'b0;        // 异常重获或接管阶段不保留恢复相交资格
		end else if(i_recheck_done_event == 1'b1)begin
			flag_resume_pending <= i_recheck_success && baseline_valid_o; // 成功重检保留锚点并等待首样本
		end else if(flag_cross_eligible_red_result == 1'b1)begin
			flag_resume_pending <= 1'b0;        // 第一笔正式9-bit恢复样本完成一次性判断
		end else begin
			flag_resume_pending <= flag_resume_pending; // FIR预热无输出期间持续等待
		end
	end

endmodule
