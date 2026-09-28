`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026-08-12
// Design Name: 	PPG Precision Window Integration
// Module Name: 	ppg_precision_window_integration
// Description: 	Integrates the coarse FIR, dynamic baseline detector,
// Dependencies:
// Five independently verified PPG control-chain modules
// 五个已经独立验证的PPG控制链模块
// Simulations:		tb_ppg_precision_window_integration
//
// Referrences:		PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
//
// Version:			V1.4
// Revision Date:	2026-08-31
// History:
//    Time			   Version	   Revised by			Contents
// 2026-08-12			V1.0		 Erie		Create file.
// 2026-08-22			V1.1		 Erie		Remove i_stop_ack_event/i_control_abort_event wrapper ports and their direct forwarding into the five children; add i_run_generation, the AMI-facing i_detection_discard_* group, broadcast wiring to FIR/baseline/peak-valley/precision-controller, and o_detection_datapath_empty per PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md section 5.10.
// 2026-08-22			V1.2		 Erie		Add o_mode_fault_active/identity_valid/<FAULT_ID> wrapper outputs and the named flag_precision_controller_fault_* internal nets that register the precision-controller child's fault group, per PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md section 5.11, so AMI's cause 8'h04 lane has a real source.
// 2026-08-23			V1.3		 Erie		Rename i_adc_idle to i_precision_takeover_safe (pure port rename, no logic change) and its unchanged forwarding to the precision-controller and AMB-scheduler children, per PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md sections 5.4/5.10/7/9; the connected value was already AMI's composite switch-safety predicate.
// 2026-08-31			V1.4		 Erie		Stage 5 bucket-2 RTL session, port-threading step: add a new, additive, default-off `C_ENABLE_TEST_INJECTION` parameter (was previously absent on this wrapper) plus a pure pass-through `i_test_inject_enable`/`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready` group, wired straight through to the child FIR's own newly-added injection ports (ppg_coarse_detection_fir.v V2.3). No local gating logic added at this layer -- FIR already does the full gating internally. Bit-identical production behavior confirmed by re-running the main smoke TB through the full ppg_control_top hierarchy (SMOKE_TB_PASS, identical counters) and the injection TB with C_ENABLE_TEST_INJECTION=1 actually live (INJ_TB_PASS, all existing INJ-00~04 unaffected).
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026-08-12
// 设计名称: 		PPG Precision Window Integration
// 模块名称: 		ppg_precision_window_integration
// 模块说明:		Integrates the coarse FIR, dynamic baseline detector,
// 依赖文件:
// Five independently verified PPG control-chain modules
// 五个已经独立验证的PPG控制链模块
// 仿真工程: 		tb_ppg_precision_window_integration
//
// 参考资料:		PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
//
// 当前版本:		V1.4
// 修订日期:		2026-08-31
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026-08-12		V1.0		 Erie		创建文件
// 2026-08-22		V1.1		 Erie		删除i_stop_ack_event/i_control_abort_event wrapper端口及其对五个子模块的直接转发；按合同5.10节新增i_run_generation、AMI侧i_detection_discard_*组、向FIR/动态基线/峰谷/精度控制器的广播接线，以及o_detection_datapath_empty
// 2026-08-22		V1.2		 Erie		按合同5.11节新增o_mode_fault_active/identity_valid/<FAULT_ID> wrapper输出，以及登记精度控制器子模块故障组的具名内部网flag_precision_controller_fault_*，使AMI cause 8'h04通道拥有真实来源
// 2026-08-23		V1.3		 Erie		按合同5.4/5.10/7/9节把i_adc_idle改名为i_precision_takeover_safe（纯端口改名，不改逻辑），对精度控制器和AMB调度器两个子模块的转发保持原样——该端口连接的值本来就是AMI导出的复合切换资格，从未是物理ADC空闲
// 2026-08-31		V1.4		 Erie		Stage 5桶2 RTL会话端口透传步骤：新增本wrapper此前完全没有的默认关闭`C_ENABLE_TEST_INJECTION`参数，配一组纯直通的`i_test_inject_enable`/`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready`，原样透传给子模块FIR新增的注入端口（`ppg_coarse_detection_fir.v`V2.3）。这一层不加任何本地门控逻辑——FIR内部已经做完整门控。真实回归确认逐位不变：主烟雾TB跑通完整`ppg_control_top`层次（`SMOKE_TB_PASS`，计数与改动前逐字节一致）+`C_ENABLE_TEST_INJECTION=1`真实生效状态下的注入TB（`INJ_TB_PASS`，既有INJ-00~04全部不受影响）
module ppg_precision_window_integration
#(
	parameter integer C_DATA_WIDTH = 32'd24,    // 统一signed粗PPG和FIR数据字段宽度
	parameter integer C_FRAME_ID_WIDTH = 32'd16, // 全局400 Hz物理帧编号字段宽度
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // ADC事务全局顺序编号字段宽度
	parameter integer C_IDAC_CODE_WIDTH = 32'd8, // AMB和颜色DC码快照字段宽度
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // IDAC committed码版本字段宽度
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // ACTIVE配置版本字段宽度
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8, // Stage1校准系数组版本字段宽度
	parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8, // DC恢复系数组版本字段宽度
	parameter integer C_SLOPE_WIDTH = 32'd32,   // signed Q16动态基线斜率字段宽度
	parameter integer C_BASELINE_WIDTH = 32'd48, // signed Q16动态基线运算字段宽度
	parameter integer C_RATIO_WIDTH = 32'd16,   // unsigned Q1.15自适应比例字段宽度
	parameter integer C_CONFIRM_COUNT_WIDTH = 32'd4, // 峰谷连续方向确认计数字段宽度
	parameter integer C_INTERVAL_WIDTH = 32'd16, // 峰谷时间间隔和超时字段宽度
	parameter integer C_FIR_GROUP_DELAY_SAMPLES = 32'd10, // 20阶FIR固定同色群延时
	parameter integer C_SWITCH_TIMEOUT_CYCLES = 32'd10000, // 精度安全提交最大2 MHz等待周期
	parameter integer C_SWITCH_TIMEOUT_COUNTER_WIDTH = 32'd14, // 精度提交超时计数器字段宽度
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8, // manager唯一生产、由AMI逐层传入的RUN代际字段宽度；本参数原样透传给599/690/804/904行子模块,父子等宽由构造保证 @satisfies: K03, G-FP-05
	parameter integer C_ENABLE_TEST_INJECTION = 32'd0 // 默认关闭的验证专用异常注入结构生成使能，逐层透传自AMI/顶层，生产网表必须为0
)
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 2 MHz数字处理域工作时钟
	input i_rstn,                               // 低有效异步复位输入

	//---------------生命周期接口---------------//
	input i_run_enable,                         // 当前生命周期处于RUN状态
	input i_start_ack_event,                    // 新RUN正式开始的单周期事件
	input i_diag_clear_event,                   // 软件清除sticky诊断的单周期事件

	//-------AMI检测代际清空广播接口-------//
	input i_detection_discard_event,       // AMI注册式代际清空事件，无ready/ack
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
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // AMI逐层传入的当前RUN代际
	output o_detection_datapath_empty,     // fork、FIR、基线、峰谷、精度控制器和discard广播状态全部排空时为高，唯一消费者AMI

	//--------------ACTIVE配置接口--------------//
	input i_active_config_valid,                // 已提交ACTIVE配置整体合法资格
	input i_run_profile,                        // 低为NORMAL且高为CHARACTERIZATION
	input i_initial_precision,                  // 表征模式启动时采用的固定精度
	input i_normal_measurement_active,          // 启动搜索完成并允许正式NORMAL测量
	input i_slope_mode,                         // 低选择固定斜率且高选择自适应斜率
	input signed [C_SLOPE_WIDTH - 1:0]i_fixed_slope_q16, // 启动和回退使用的signed Q16负斜率
	input [C_RATIO_WIDTH - 1:0]i_alpha_q15,     // 峰谷幅度形成基础斜率的Q1.15比例
	input [C_RATIO_WIDTH - 1:0]i_beta_q15,      // 活动斜率逐周期平滑的Q1.15比例
	input [C_RATIO_WIDTH - 1:0]i_timing_adjust_ratio_q15, // 相交提前量修正的Q1.15相对步长
	input signed [C_SLOPE_WIDTH - 1:0]i_slope_min_q16, // 允许的最负signed Q16斜率边界
	input signed [C_SLOPE_WIDTH - 1:0]i_slope_max_q16, // 允许的最接近零斜率边界
	input signed [C_SLOPE_WIDTH - 1:0]i_baseline_delta_q16, // 波峰锚点处的signed Q16基线偏置
	input [C_SLOPE_WIDTH - 1:0]i_cross_hysteresis_q16, // 向上相交比较使用的Q16迟滞量
	input [C_FRAME_ID_WIDTH - 1:0]i_lead_min_frames, // 相交提前量合格窗口下界
	input [C_FRAME_ID_WIDTH - 1:0]i_lead_max_frames, // 相交提前量合格窗口上界
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_cross_confirm_count, // 向上相交所需连续确认点数
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_no_cross_limit, // 连续无相交触发重新获取阈值
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_peak_confirm_count, // 波峰后连续下降确认点数
	input [C_CONFIRM_COUNT_WIDTH - 1:0]i_valley_confirm_count, // 波谷后连续上升确认点数
	input [C_DATA_WIDTH - 1:0]i_direction_deadband, // 相邻FIR值方向分类的无符号死区
	input [C_DATA_WIDTH - 1:0]i_min_peak_valley_amplitude, // 合格峰谷对要求的最小幅度
	input [C_INTERVAL_WIDTH - 1:0]i_min_peak_to_valley_frames, // 波峰至波谷允许的最小帧差
	input [C_INTERVAL_WIDTH - 1:0]i_min_peak_to_peak_frames, // 相邻波峰允许的最小帧差
	input [C_INTERVAL_WIDTH - 1:0]i_max_fine_window_frames, // 正式15-bit窗口最大持续帧数
	input [C_INTERVAL_WIDTH - 1:0]i_max_reacquire_frames, // 单轮9-bit重新获取最大持续帧数
	input i_peak_valley_config_valid,           // 峰谷检测配置已经正式提交
	input [1:0]i_idac_mode,                     // IDAC控制器当前工作模式编码
	input i_amb_enable,                         // 允许执行周期环境光码重检
	input i_dcs_enable,                         // 允许固定执行DC_R和DC_IR重验证
	input [15:0]i_amb_recheck_interval_frames,  // 周期AMB重检的完整NORMAL帧间隔

	//-------------NORMAL粗结果接口-------------//
	input i_normal_result_valid,                // 上游保持的完整NORMAL粗结果valid
	output o_normal_result_ready,               // FIR允许唯一消费当前NORMAL事务
	input i_sample_valid,                       // 上游独立样本资格，0事务只释放握手而不得进入算法历史
	input signed [C_DATA_WIDTH - 1:0]i_coarse_ppg_value, // DC恢复后的统一signed粗PPG值
	input i_coarse_valid,                       // 当前事务具有可用于检测的粗结果
	input i_coarse_recovery_calibrated,         // Stage1和DC9恢复均具备正式资格
	input i_stage1_saturation_low,              // Stage1校准结果触及负向端点
	input i_stage1_saturation_high,             // Stage1校准结果触及正向端点
	input i_coarse_saturation_low,              // 粗恢复结果发生负向24-bit饱和
	input i_coarse_saturation_high,             // 粗恢复结果发生正向24-bit饱和
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 当前事务绑定的ACTIVE配置版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 当前事务采用的Stage1系数组版本
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_dc_recovery_coef_epoch, // 当前事务采用的DC恢复版本
	input i_precision_mode,                     // 事务开始时快照的committed精度
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id,   // 当前物理400 Hz帧编号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 当前ADC事务全局顺序编号
	input i_color_ir,                           // 低为红光事务且高为红外事务
	input [1:0]i_frame_type,                    // 正式检测事务固定使用NORMAL编码10
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // 当前积分使用的AMB committed码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 当前颜色积分使用的DC committed码
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // 当前AMB committed码版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // 当前颜色DC committed码版本

	//-------------帧与排空控制接口-------------//
	input i_frame_safe_boundary,                // 下一物理帧开始前的安全边界单拍
	input [C_FRAME_ID_WIDTH - 1:0]i_safe_frame_id, // 即将启动帧的真实frame_id
	input i_precision_takeover_safe,            // AMI导出的复合精度切换资格：物理ADC/DONE已空闲，且ADC、capture和结果流水已排空；它不是物理idle事实
	input i_analog_safe,                        // 模拟相位允许提交新的采集精度
	input i_normal_fork_idle,                   // 上游NORMAL测量和跟踪fork已经排空
	input i_idac_idle,                          // IDAC控制器无pending或在途提交
	input i_startup_search_complete,            // 启动AMB和DC搜索已经完成
	input i_normal_frame_complete_event,        // 一帧完整NORMAL测量结束单拍
	input i_calibration_frame_complete_event,   // 当前AMB或DCS校准帧结束单拍

	//---------------IDAC协作接口---------------//
	input i_amb_sample_request,                 // IDAC保持请求下一笔AMB_CAL样本
	input i_amb_sequence_done,                  // AMB检查或搜索成功单拍
	input i_amb_sequence_failed,                // AMB搜索耗尽失败单拍
	input i_dcs_revalidate_request,             // IDAC保持请求进入两色DC重验证
	input i_dcs_sample_request,                 // IDAC保持请求当前颜色DCS_CAL样本
	input i_dcs_sample_color_ir,                // 低选择DC_R且高选择DC_IR
	input i_dcs_revalidate_done,                // 两色DC重验证整体成功单拍
	input i_dcs_revalidate_failed,              // 任一路DC重验证失败单拍
	input i_amb_sample_accepted_event,          // 匹配AMB_CAL结果已经被控制器消费
	input i_dcs_sample_accepted_event,          // 确认当前颜色直流校准结果完成消费
	output o_amb_sequence_start,                // 安全接管后启动AMB检查单拍
	output o_dcs_revalidate_accept,             // AMB帧后接受两色DC重验证单拍

	//-------------校准采样调度接口-------------//
	input i_calibration_sample_ready,           // 模拟调度器允许接受SAR9校准请求
	output o_calibration_sample_valid,          // 保持型AMB_CAL或DCS_CAL采样请求
	output [1:0]o_calibration_frame_type,       // 低编码AMB_CAL且01编码DCS_CAL
	output o_calibration_color_ir,              // DCS_CAL当前颜色选择
	output o_calibration_precision_mode,        // 周期重检固定选择SAR9精度
	output o_calibration_frame_start,           // 每个校准帧开始的单周期事件
	output [1:0]o_calibration_stage,            // 当前校准阶段的只读编码

	//---------------精度控制输出---------------//
	output o_active_precision_mode,             // 系统唯一committed采集精度
	output o_fine_window_active,                // 正式PPG 15-bit窗口状态
	output o_fine_window_start_event,           // 真实进入15-bit窗口的提交单拍
	output [C_FRAME_ID_WIDTH - 1:0]o_fine_window_start_frame_id, // 第一笔真实15-bit物理帧号
	output o_precision_15_to_9_event,           // 正式窗口真实返回9-bit的提交单拍
	output [C_FRAME_ID_WIDTH - 1:0]o_precision_15_to_9_frame_id, // 第一笔恢复9-bit物理帧号
	output o_reacquire_request_event,           // 异常返回后废止旧锚点的单拍
	output o_switch_hold_new_transaction,       // 顶层必须停止启动新ADC事务
	output o_mode_fault_event,                  // 精度控制发生阻断故障单拍
	output o_mode_fault_active,                 // 当前RUN代际精度阻断故障保持电平，唯一消费者AMI
	output o_mode_fault_identity_valid,         // 精度阻断故障是否绑定真实事务身份
	output [C_FRAME_ID_WIDTH - 1:0]o_mode_fault_frame_id, // 精度阻断故障绑定事务的真实物理帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_mode_fault_sample_index, // 精度阻断故障绑定事务的全局事务号
	output o_mode_fault_color_ir,               // 精度阻断故障绑定事务颜色，本链路只处理RED来源恒为0
	output [1:0]o_mode_fault_frame_type,        // 精度阻断故障绑定事务类别，有效时恒为NORMAL编码
	output o_mode_fault_precision,              // 精度阻断故障绑定事务建立时所属的精度模式
	output [C_RUN_GENERATION_WIDTH - 1:0]o_mode_fault_run_generation, // 精度阻断故障绑定的RUN代际

	//---------------AMB重检输出----------------//
	output [15:0]o_normal_frame_count,          // 当前周期累计的完整NORMAL帧数

	//AMB_RECHECK接口
	output o_amb_recheck_pending,               // 重检间隔到期并等待15到9事件
	output o_amb_recheck_accept,                // 安全接管真正发生的单拍
	output o_amb_recheck_busy,                  // 三帧校准与恢复预热占用状态
	output o_normal_output_inhibit,             // 重检期间禁止正式PPG输出
	output o_recheck_sequence_done,             // 固定三阶段重检成功单拍
	output o_recheck_sequence_failed,           // 任一重检阶段失败单拍

	//--------------可观测状态接口--------------//
	output o_fir_history_full_r,                // 红光FIR历史已经收集21笔真实样本
	output o_fir_history_full_ir,               // 红外FIR历史已经收集21笔真实样本
	output o_fir_idle,                          // FIR的MAC和输出保持槽已经排空
	output o_detection_fork_idle,               // 两个检测分支均无事务所有权
	output o_detector_idle,                     // 峰谷真实事务和入口尾部允许重检接管
	output o_controller_idle,                   // 精度控制器没有pending或故障保持
	output o_scheduler_idle,                    // AMB scheduler没有pending或在途样本
	output o_cross_pending,                     // 动态基线存在未消费cross请求
	output o_peak_pending,                      // 峰谷检测器存在未消费peak事件
	output o_valley_pending,                    // 保存尚待基线模块接收的波谷事件
	output o_return_pending,                    // 峰谷检测器存在未消费返回请求
	output o_baseline_valid,                    // 当前动态基线锚点和斜率有效
	output o_reacquire_active,                  // 动态基线要求9-bit重新获取波峰
	output o_detector_fine_window_active,       // 峰谷检测器观察到的正式fine状态
	output o_switch_pending,                    // 精度切换请求正在等待安全提交
	output o_switch_target_precision,           // 当前pending要求的目标精度
	output signed [C_SLOPE_WIDTH - 1:0]o_slope_current_q16, // 当前锚点周期使用的活动斜率
	output o_baseline_protocol_error_sticky,    // 动态基线协议异常历史诊断
	output o_fine_window_timeout_sticky,        // 峰谷fine窗口超时历史诊断
	output o_reacquire_timeout_sticky,          // 峰谷重新获取超时历史诊断
	output o_peak_valley_protocol_error_sticky, // 峰谷帧序、epoch或模式异常历史
	output o_switch_timeout_sticky,             // 精度安全提交超时历史诊断
	output o_precision_protocol_error_sticky,   // 精度控制协议异常历史诊断

	//---------验证专用异常注入接口---------//
	input i_test_inject_enable,             // 逐层透传自AMI的验证注入使能，与C_ENABLE_TEST_INJECTION共同限定
	input i_test_calibration_loss_inject_valid, // 保持型一次性calibration-loss注入请求valid，直通FIR
	output o_test_calibration_loss_inject_ready // FIR可把请求原子绑定到下一笔真实被接纳样本
);

	//---------------配置参数区域---------------//
	// Fork载荷宽度覆盖两个消费者共同使用的全部FIR结果和中心元数据。
	localparam integer FORK_PAYLOAD_WIDTH = C_DATA_WIDTH + 5 + C_CONFIG_EPOCH_WIDTH + C_COEF_EPOCH_WIDTH + C_DC_RECOVERY_EPOCH_WIDTH + 1 + C_FRAME_ID_WIDTH + C_SAMPLE_INDEX_WIDTH + 1 + 2; // 原子保存完整FIR检测事务

	//-----------------计数信号-----------------//
	wire [3:0]cnt_no_cross;                     // 连续完整无相交周期计数

	//----------------寄存器信号----------------//
	reg [FORK_PAYLOAD_WIDTH - 1:0]reg_fork_payload = {FORK_PAYLOAD_WIDTH{1'b0}}; // 当前等待两个检测分支消费的完整FIR载荷

	//-----------------标志信号-----------------//
	reg flag_baseline_pending = 1'b0;           // 动态基线分支尚未消费当前载荷
	reg flag_peak_valley_pending = 1'b0;        // 峰谷检测分支尚未消费当前载荷
	reg flag_recheck_detector_busy = 1'b0;      // 安全接管后才冻结两个检测消费者
	wire flag_fir_result_valid;                 // FIR输出保持槽包含一笔完整事务
	wire flag_fir_result_ready;                 // Fork允许接收或替换当前FIR事务
	wire flag_fir_output_transfer;              // FIR输出在本沿转移到检测fork
	wire flag_baseline_transfer;                // 动态基线分支完成唯一一次消费
	wire flag_peak_valley_transfer;             // 峰谷检测分支完成唯一一次消费
	wire flag_baseline_result_ready;            // 动态基线当前允许消费fork载荷
	wire flag_peak_valley_result_ready;         // 峰谷检测当前允许消费fork载荷
	wire flag_all_current_released;             // 当前载荷的两个所有权可在本沿释放
	wire flag_fork_clear;                       // 生命周期或重检接管要求撤销fork状态
	wire flag_fork_detection_qualified;         // 已保存事务的正式检测资格
	wire flag_fork_window_saturation_low;       // 已保存窗口包含负向饱和样本
	wire flag_fork_window_saturation_high;      // 已保存窗口包含正向饱和样本
	wire flag_fork_fir_saturation_low;          // 已保存FIR结果触及负端点
	wire flag_fork_fir_saturation_high;         // 已保存FIR结果触及正端点
	wire flag_fork_precision_mode;              // 已保存中心样本的历史精度
	wire flag_fork_color_ir;                    // 已保存事务的颜色身份
	wire flag_fir_detection_qualified;          // FIR当前输出的正式检测资格
	wire flag_fir_window_saturation_low;        // FIR窗口包含负向饱和样本
	wire flag_fir_window_saturation_high;       // FIR窗口包含正向饱和样本
	wire flag_fir_saturation_low;               // FIR舍入结果低于signed端点
	wire flag_fir_saturation_high;              // FIR舍入结果高于signed端点
	wire flag_fir_precision_mode;               // FIR中心样本的历史精度
	wire flag_fir_color_ir;                     // FIR中心样本的颜色身份
	wire flag_peak_ready;                       // 动态基线允许提交当前波峰
	wire flag_valley_ready;                     // 动态基线允许提交当前波谷
	wire flag_cross_ready;                      // 精度控制器允许消费相交请求
	wire flag_cross_time_unknown;               // 当前相交缺少正式中心时刻证明
	wire flag_return_9bit_ready;                // 精度控制器允许消费返回9-bit请求
	wire flag_recheck_done_event;               // 成功或失败结束三阶段重检序列
	wire flag_recheck_success;                  // 当前重检完成事件具有整体成功资格
	wire flag_detection_discard_apply;          // AMI代际清空事件命中当前代际，替代原i_stop_ack_event/i_control_abort_event直连
	reg flag_fir_idle_to_scheduler = 1'b0;      // 锁存FIR与检测fork稳定排空资格
	wire flag_adaptive_slope_valid;             // 动态基线已经完成至少一次自适应更新
	wire flag_slope_saturation_min;             // 活动斜率触及最负配置边界
	wire flag_slope_saturation_max;             // 活动斜率触及近零配置边界
	wire flag_baseline_saturation_low;          // 最近基线比较低于数据端点
	wire flag_baseline_saturation_high;         // 最近基线比较高于数据端点
	wire flag_reacquire_search_active;          // 峰谷检测器正在执行9-bit重新获取
	wire flag_last_cross_time_unknown;          // 控制器最近相交时间诊断
	wire flag_precision_controller_fault_event; // 精度控制器故障新episode单周期事件，PWI私有登记网
	wire flag_precision_controller_fault_active; // 精度控制器当前RUN代际故障保持电平，PWI私有登记网
	wire flag_precision_controller_fault_identity_valid; // 精度控制器故障身份是否可信，PWI私有登记网
	wire [C_FRAME_ID_WIDTH - 1:0]flag_precision_controller_fault_frame_id; // 精度控制器故障绑定事务的真实帧号，PWI私有登记网
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]flag_precision_controller_fault_sample_index; // 精度控制器故障绑定事务的全局序号，PWI私有登记网
	wire flag_precision_controller_fault_color_ir; // 精度控制器故障绑定事务颜色，PWI私有登记网
	wire [1:0]flag_precision_controller_fault_frame_type; // 精度控制器故障绑定事务类别，PWI私有登记网
	wire flag_precision_controller_fault_precision; // 精度控制器故障绑定事务所属精度模式，PWI私有登记网
	wire [C_RUN_GENERATION_WIDTH - 1:0]flag_precision_controller_fault_run_generation; // 精度控制器故障绑定的RUN代际，PWI私有登记网
	//-----------------编码信号-----------------//
	wire [FORK_PAYLOAD_WIDTH - 1:0]enc_fir_payload; // FIR输出组合形成的原子载荷

	//-----------------译码信号-----------------//
	wire signed [C_DATA_WIDTH - 1:0]dec_fork_filtered_ppg_value; // 已保存的signed粗FIR结果
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_fork_config_epoch; // 已保存中心样本的ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_fork_coef_epoch; // 锁存双消费者共用的Stage1系数版本
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_fork_dc_recovery_coef_epoch; // 已保存中心样本的DC恢复版本
	wire [C_FRAME_ID_WIDTH - 1:0]dec_fork_frame_id; // 已保存中心样本的真实帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_fork_sample_index; // 已保存中心样本的事务号
	wire [1:0]dec_fork_frame_type;              // 已保存事务的NORMAL类型编码
	wire signed [C_DATA_WIDTH - 1:0]dec_fir_filtered_ppg_value; // FIR当前输出的signed结果
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_fir_config_epoch; // FIR中心样本的ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_fir_coef_epoch; // 标记滤波中心采用的Stage1系数组
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_fir_dc_recovery_coef_epoch; // FIR中心样本的DC恢复版本
	wire [C_FRAME_ID_WIDTH - 1:0]dec_fir_frame_id; // FIR中心样本的物理帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_fir_sample_index; // FIR中心样本的事务序号
	wire [1:0]dec_fir_frame_type;               // FIR中心样本的NORMAL编码
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_fir_amb_code_snapshot; // 未进入检测器的中心AMB码诊断
	wire [C_IDAC_CODE_WIDTH - 1:0]dec_fir_dc_code_snapshot; // 保留中心颜色直流码用于链路诊断
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_fir_amb_code_epoch; // 未进入检测器的中心AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]dec_fir_dc_code_epoch; // 保留中心颜色直流码提交版本
	wire signed [C_DATA_WIDTH - 1:0]dec_peak_value; // 可靠波峰的Stage1粗FIR码值
	wire [C_FRAME_ID_WIDTH - 1:0]dec_peak_frame_id; // 波峰实际发生的中心帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_peak_sample_index; // 波峰实际对应的事务号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_peak_config_epoch; // 波峰绑定的ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_peak_coef_epoch; // 记录波峰形成时的Stage1系数组
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_peak_dc_recovery_coef_epoch; // 波峰绑定的DC恢复版本
	wire signed [C_DATA_WIDTH - 1:0]dec_valley_value; // 可靠波谷的Stage1粗FIR码值
	wire [C_FRAME_ID_WIDTH - 1:0]dec_valley_frame_id; // 波谷实际发生的中心帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_valley_sample_index; // 波谷实际对应的事务号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_valley_config_epoch; // 波谷绑定的ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_valley_coef_epoch; // 记录波谷形成时的Stage1系数组
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_valley_dc_recovery_coef_epoch; // 波谷绑定的DC恢复版本
	wire [C_FRAME_ID_WIDTH - 1:0]dec_cross_frame_id; // 相交首次越过对应的中心帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]dec_cross_sample_index; // 相交首次越过对应的事务号
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]dec_cross_config_epoch; // 相交绑定的ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_cross_coef_epoch; // 记录相交样本使用的Stage1系数组
	wire [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]dec_cross_dc_recovery_coef_epoch; // 相交绑定的DC恢复版本
	wire [1:0]dec_return_reason;                // 波谷成功、超时或协议回退原因
	wire [C_FRAME_ID_WIDTH - 1:0]dec_return_frame_id; // 返回请求绑定的真实检测帧号
	wire signed [C_SLOPE_WIDTH - 1:0]dec_slope_base_q16; // 最近完整周期形成的基础斜率
	wire [C_FRAME_ID_WIDTH - 1:0]dec_last_lead_frames; // 最近时间已知相交提前量
	wire [1:0]dec_last_return_reason;           // 控制器最近返回原因诊断

	//-----------------其他信号-----------------//
	// 未分类控制线已在标志区声明，此区域保留规范顺序锚点。

	//-----------------输出信号-----------------//
	//NORMAL粗结果接口
	wire normal_result_ready_o;                 // FIR允许接收上游NORMAL粗结果

	//IDAC协作接口
	wire enc_amb_sequence_start_o;              // 触发环境光码检查序列
	wire dcs_revalidate_accept_o;               // 接受两色直流码重验证

	//校准采样调度接口
	wire calibration_sample_valid_o;            // 保持校准采样请求资格
	wire [1:0]calibration_frame_type_o;         // 标识环境光或直流校准帧
	wire calibration_color_ir_o;                // 选择直流校准颜色通道
	wire calibration_precision_mode_o;          // 固定校准事务采用SAR9
	wire calibration_frame_start_o;             // 标记校准物理帧起始
	wire [1:0]calibration_stage_o;              // 指示三帧重检当前阶段

	//精度控制输出
	wire active_precision_mode_o;               // 给出唯一已提交采集精度
	wire fine_window_active_o;                  // 声明正式精细窗口有效期
	wire fine_window_start_event_o;             // 脉冲指示真实进入精细窗口
	wire [C_FRAME_ID_WIDTH - 1:0]fine_window_start_frame_id_o; // 绑定首笔精细采集帧号
	wire precision_15_to_9_event_o;             // 脉冲指示精细窗口退出提交
	wire [C_FRAME_ID_WIDTH - 1:0]precision_15_to_9_frame_id_o; // 绑定首笔恢复粗采集帧号
	wire reacquire_request_event_o;             // 请求废止旧锚点重新获取
	wire switch_hold_new_transaction_o;         // 阻止安全切换期间启动ADC

	//AMB重检输出
	wire [15:0]cnt_normal_frame_o;              // 导出周期重检帧间隔计数
	wire amb_recheck_pending_o;                 // 记录间隔到期等待切换状态
	wire amb_recheck_accept_o;                  // 标记重检安全接管时刻
	wire amb_recheck_busy_o;                    // 表示校准与FIR恢复占用
	wire normal_output_inhibit_o;               // 禁止重检期间正式PPG输出
	wire enc_recheck_sequence_done_o;           // 编码三阶段重检整体成功
	wire enc_recheck_sequence_failed_o;         // 编码任一重检阶段失败

	//可观测状态接口
	wire fir_history_full_r_o;                  // 指示红光FIR历史完成预热
	wire fir_history_full_ir_o;                 // 指示红外FIR历史完成预热
	wire fir_idle_o;                            // 指示FIR运算与输出均排空
	wire detection_fork_idle_o;                 // Fork没有任何分支保留事务所有权
	wire fir_local_empty_o;                     // FIR子模块本地排空回报
	wire baseline_local_empty_o;                // 动态基线子模块本地排空回报
	wire peak_valley_local_empty_o;             // 峰谷检测子模块本地排空回报
	wire precision_local_empty_o;               // 精度控制子模块本地排空回报
	reg detection_datapath_empty_o;             // 广播下一拍起五路本地排空的注册聚合结果
	wire detector_idle_o;                       // 允许重检接管峰谷检测状态
	wire controller_idle_o;                     // 表示精度控制无待办事务
	wire scheduler_idle_o;                      // 表示重检调度无在途序列
	wire cross_pending_o;                       // 动态基线保持的进入15-bit请求
	wire peak_pending_o;                        // 峰谷检测器保存可靠波峰事件
	wire valley_pending_o;                      // 峰谷检测器保存可靠波谷事件
	wire return_pending_o;                      // 峰谷检测器保持的返回9-bit请求
	wire baseline_valid_o;                      // 指示动态基线锚点可用于比较
	wire reacquire_active_o;                    // 指示粗模式正在重新获取峰谷
	wire detector_fine_window_active_o;         // 反映峰谷检测器精细窗口状态
	wire switch_pending_o;                      // 指示精度请求等待安全提交
	wire switch_target_precision_o;             // 给出待提交精度目标值
	wire signed [C_SLOPE_WIDTH - 1:0]slope_current_q16_o; // 导出活动基线负斜率
	wire baseline_protocol_error_sticky_o;      // 锁存动态基线协议异常历史
	wire fine_window_timeout_sticky_o;          // 锁存精细窗口超时历史
	wire reacquire_timeout_sticky_o;            // 锁存粗模式重新获取超时
	wire peak_valley_protocol_error_sticky_o;   // 锁存峰谷时序协议异常
	wire switch_timeout_sticky_o;               // 锁存精度切换等待超时
	wire precision_protocol_error_sticky_o;     // 锁存精度控制协议异常

	//---------------其他信号连线---------------//
	// 双消费者事务组合连接，以下均为内部握手和载荷译码。
	// 组合完整FIR载荷，确保数据和全部中心元数据在同一沿锁存。
	assign enc_fir_payload = {dec_fir_filtered_ppg_value, flag_fir_detection_qualified, flag_fir_window_saturation_low, flag_fir_window_saturation_high, flag_fir_saturation_low, flag_fir_saturation_high, dec_fir_config_epoch, dec_fir_coef_epoch, dec_fir_dc_recovery_coef_epoch, flag_fir_precision_mode, dec_fir_frame_id, dec_fir_sample_index, flag_fir_color_ir, dec_fir_frame_type}; // 按固定字段顺序打包FIR事务
	// 逐位译码保存载荷，使两个消费者观察完全相同的事务内容。
	assign {dec_fork_filtered_ppg_value, flag_fork_detection_qualified, flag_fork_window_saturation_low, flag_fork_window_saturation_high, flag_fork_fir_saturation_low, flag_fork_fir_saturation_high, dec_fork_config_epoch, dec_fork_coef_epoch, dec_fork_dc_recovery_coef_epoch, flag_fork_precision_mode, dec_fork_frame_id, dec_fork_sample_index, flag_fork_color_ir, dec_fork_frame_type} = reg_fork_payload; // 原子恢复fork载荷字段
	assign flag_baseline_transfer = flag_baseline_pending && flag_baseline_result_ready; // 动态基线分支完成当前事务握手
	assign flag_peak_valley_transfer = flag_peak_valley_pending && flag_peak_valley_result_ready; // 峰谷分支完成当前事务握手
	assign flag_all_current_released = (!flag_baseline_pending || flag_baseline_result_ready) && (!flag_peak_valley_pending || flag_peak_valley_result_ready); // 两个分支均可在本沿释放旧载荷
	assign detection_fork_idle_o = !flag_baseline_pending && !flag_peak_valley_pending; // 两个pending均低才表示fork真正空闲
	assign flag_fir_result_ready = detection_fork_idle_o || flag_all_current_released; // 空fork或同沿全释放允许接收下一笔
	assign flag_fir_output_transfer = flag_fir_result_valid && flag_fir_result_ready; // FIR输出完成一次进入fork的唯一转移
	assign flag_recheck_done_event = enc_recheck_sequence_done_o || enc_recheck_sequence_failed_o; // 任一结束原因广播重检完成事件
	assign flag_recheck_success = enc_recheck_sequence_done_o; // 只有完整三阶段成功具有恢复资格
	assign flag_detection_discard_apply = i_detection_discard_event && (i_detection_discard_run_generation == i_run_generation); // AMI广播的代际清空事件命中当前代际时无条件生效；仅generation-scoped discard,复位路径独立不经此线 @satisfies: K04
	assign flag_fork_clear = (i_run_enable == 1'b0) || i_start_ack_event || flag_detection_discard_apply || amb_recheck_accept_o; // 生命周期和真实重检接管撤销fork

	//---------------输出信号连线---------------//
	//NORMAL粗结果接口
	assign o_normal_result_ready = normal_result_ready_o; // 上游ready只返回真实FIR输入接收资格

	//IDAC协作接口
	assign o_amb_sequence_start = enc_amb_sequence_start_o; // 转发环境光检查启动脉冲
	assign o_dcs_revalidate_accept = dcs_revalidate_accept_o; // 转发两色直流重验证接受

	//校准采样调度接口
	assign o_calibration_sample_valid = calibration_sample_valid_o; // 转发保持型校准采样资格
	assign o_calibration_frame_type = calibration_frame_type_o; // 转发校准事务类型编码
	assign o_calibration_color_ir = calibration_color_ir_o; // 转发直流校准颜色选择
	assign o_calibration_precision_mode = calibration_precision_mode_o; // 转发固定SAR9校准精度
	assign o_calibration_frame_start = calibration_frame_start_o; // 转发校准帧开始事件
	assign o_calibration_stage = calibration_stage_o; // 转发三帧校准阶段编码

	//精度控制输出
	assign o_active_precision_mode = active_precision_mode_o; // 转发唯一已提交采集精度
	assign o_fine_window_active = fine_window_active_o; // 转发正式精细窗口资格
	assign o_fine_window_start_event = fine_window_start_event_o; // 转发精细窗口提交事件
	assign o_fine_window_start_frame_id = fine_window_start_frame_id_o; // 转发首笔精细采集帧号
	assign o_precision_15_to_9_event = precision_15_to_9_event_o; // 转发返回粗模式提交事件
	assign o_precision_15_to_9_frame_id = precision_15_to_9_frame_id_o; // 转发首笔粗模式采集帧号
	assign o_reacquire_request_event = reacquire_request_event_o; // 转发异常重新获取请求
	assign o_switch_hold_new_transaction = switch_hold_new_transaction_o; // 转发暂停新ADC事务要求
	assign o_mode_fault_event = flag_precision_controller_fault_event; // 转发精度控制故障事件
	assign o_mode_fault_active = flag_precision_controller_fault_active; // 转发精度控制当前代际故障保持电平；precision controller私有flag→PWI输出,链路中段 @satisfies: K01
	assign o_mode_fault_identity_valid = flag_precision_controller_fault_identity_valid; // 转发精度控制故障身份可信度
	assign o_mode_fault_frame_id = flag_precision_controller_fault_frame_id; // 转发精度控制故障绑定的真实帧号
	assign o_mode_fault_sample_index = flag_precision_controller_fault_sample_index; // 转发精度控制故障绑定的全局事务号
	assign o_mode_fault_color_ir = flag_precision_controller_fault_color_ir; // 转发精度控制故障绑定的事务颜色
	assign o_mode_fault_frame_type = flag_precision_controller_fault_frame_type; // 转发精度控制故障绑定的事务类别
	assign o_mode_fault_precision = flag_precision_controller_fault_precision; // 转发精度控制故障绑定的精度模式
	assign o_mode_fault_run_generation = flag_precision_controller_fault_run_generation; // 转发精度控制故障绑定的RUN代际

	//AMB重检输出
	assign o_normal_frame_count = cnt_normal_frame_o; // 转发周期NORMAL帧累计值
	assign o_amb_recheck_pending = amb_recheck_pending_o; // 转发等待切换重检状态
	assign o_amb_recheck_accept = amb_recheck_accept_o; // 转发重检安全接管事件
	assign o_amb_recheck_busy = amb_recheck_busy_o; // 转发重检与预热占用状态
	assign o_normal_output_inhibit = normal_output_inhibit_o; // 转发正式测量输出禁止
	assign o_recheck_sequence_done = enc_recheck_sequence_done_o; // 转发三阶段重检成功事件
	assign o_recheck_sequence_failed = enc_recheck_sequence_failed_o; // 转发重检序列失败事件

	//可观测状态接口
	assign o_fir_history_full_r = fir_history_full_r_o; // 转发红光历史预热完成
	assign o_fir_history_full_ir = fir_history_full_ir_o; // 转发红外历史预热完成
	assign o_fir_idle = fir_idle_o;             // 转发FIR真实排空状态
	assign o_detection_datapath_empty = detection_datapath_empty_o; // 转发五路本地排空的注册聚合结果
	assign o_detection_fork_idle = detection_fork_idle_o; // 导出双分支事务所有权排空状态
	assign o_detector_idle = detector_idle_o;   // 转发峰谷检测安全空闲
	assign o_controller_idle = controller_idle_o; // 转发精度控制排空状态
	assign o_scheduler_idle = scheduler_idle_o; // 转发重检调度排空状态
	assign o_cross_pending = cross_pending_o;   // 导出动态基线保持的cross事务状态
	assign o_peak_pending = peak_pending_o;     // 导出峰谷检测器保持的peak事务状态
	assign o_valley_pending = valley_pending_o; // 暴露待基线消费的波谷保持状态
	assign o_return_pending = return_pending_o; // 暴露待精度控制消费的返回状态
	assign o_baseline_valid = baseline_valid_o; // 转发动态基线有效资格
	assign o_reacquire_active = reacquire_active_o; // 转发粗模式重新获取状态
	assign o_detector_fine_window_active = detector_fine_window_active_o; // 转发检测器精细窗口状态
	assign o_switch_pending = switch_pending_o; // 转发安全切换等待状态
	assign o_switch_target_precision = switch_target_precision_o; // 转发待提交精度目标
	assign o_slope_current_q16 = slope_current_q16_o; // 转发活动Q16负斜率
	assign o_baseline_protocol_error_sticky = baseline_protocol_error_sticky_o; // 转发基线协议异常锁存
	assign o_fine_window_timeout_sticky = fine_window_timeout_sticky_o; // 转发精细窗口超时锁存
	assign o_reacquire_timeout_sticky = reacquire_timeout_sticky_o; // 转发重新获取超时锁存
	assign o_peak_valley_protocol_error_sticky = peak_valley_protocol_error_sticky_o; // 转发峰谷协议异常锁存
	assign o_switch_timeout_sticky = switch_timeout_sticky_o; // 转发切换超时历史锁存
	assign o_precision_protocol_error_sticky = precision_protocol_error_sticky_o; // 转发精度协议异常锁存

	//-------------输出信号处理区域-------------//
	// 注册聚合五路本地排空，广播沿本身不得报告排空，最早下一拍才可能为高
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			detection_datapath_empty_o <= 1'b0; // 复位后必须重新证明全链路排空
		end else begin
			detection_datapath_empty_o <= detection_fork_idle_o && fir_local_empty_o && baseline_local_empty_o && peak_valley_local_empty_o && precision_local_empty_o; // 汇总fork与四个检测子模块的本地排空
		end
	end

	//-------------主要任务处理区域-------------//
	// 保存新FIR载荷；旧载荷在两个分支同沿释放时允许零气泡替换。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_fork_payload <= {FORK_PAYLOAD_WIDTH{1'b0}}; // 异步复位清除残留载荷内容
		end else if(flag_fork_clear == 1'b1)begin
			reg_fork_payload <= {FORK_PAYLOAD_WIDTH{1'b0}}; // 生命周期边界不保留跨边界元数据
		end else if(flag_fir_output_transfer == 1'b1)begin
			reg_fork_payload <= enc_fir_payload; // 接收完整FIR输出并覆盖已经释放的旧载荷
		end
	end

	// 动态基线pending只由该分支握手释放，新载荷同沿到达时重新取得所有权。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_baseline_pending <= 1'b0;      // 复位后动态基线分支没有事务
		end else if(flag_fork_clear == 1'b1)begin
			flag_baseline_pending <= 1'b0;      // 安全接管或生命周期边界撤销所有权
		end else if(flag_fir_output_transfer == 1'b1)begin
			flag_baseline_pending <= 1'b1;      // 每笔新FIR载荷必须由动态基线消费一次
		end else if(flag_baseline_transfer == 1'b1)begin
			flag_baseline_pending <= 1'b0;      // 本分支握手后释放当前载荷
		end
	end

	// 峰谷pending独立于动态基线分支，防止单侧反压造成丢失或重复消费。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_peak_valley_pending <= 1'b0;   // 复位后峰谷分支没有事务
		end else if(flag_fork_clear == 1'b1)begin
			flag_peak_valley_pending <= 1'b0;   // 重检接管时保证fork回到空闲
		end else if(flag_fir_output_transfer == 1'b1)begin
			flag_peak_valley_pending <= 1'b1;   // 每笔新载荷必须由峰谷检测消费一次
		end else if(flag_peak_valley_transfer == 1'b1)begin
			flag_peak_valley_pending <= 1'b0;   // 本分支唯一握手完成后释放所有权
		end
	end

	// Scheduler等待排空时仅阻止FIR接收新输入；真实accept后才冻结检测器状态。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_recheck_detector_busy <= 1'b0; // 复位后检测器未被重检占用
		end else if(i_start_ack_event == 1'b1 || flag_detection_discard_apply == 1'b1 || flag_recheck_done_event == 1'b1 || (i_run_enable == 1'b0))begin
			flag_recheck_detector_busy <= 1'b0; // 生命周期边界或序列结束释放检测链
		end else if(amb_recheck_accept_o == 1'b1)begin
			flag_recheck_detector_busy <= 1'b1; // 安全排空完成后冻结重检期间检测状态
		end
	end

	// 返回粗模式后先锁存稳定排空事实，切断安全接管对FIR ready的组合反馈。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_fir_idle_to_scheduler <= 1'b0; // 复位后必须重新证明检测流水排空
		end else if(i_start_ack_event == 1'b1 || flag_detection_discard_apply == 1'b1 || precision_15_to_9_event_o == 1'b1 || amb_recheck_accept_o == 1'b1 || (i_run_enable == 1'b0))begin
			flag_fir_idle_to_scheduler <= 1'b0; // 生命周期和接管边界废止旧排空快照
		end else if(fir_idle_o == 1'b1 && detection_fork_idle_o == 1'b1)begin
			flag_fir_idle_to_scheduler <= 1'b1; // WAIT_DRAIN阻止新输入后保存稳定空闲证明
		end else begin
			flag_fir_idle_to_scheduler <= 1'b0; // 任一所有权未释放时禁止安全接管
		end
	end

	//--------------模块实例化区域--------------//
	// 21抽头周期MAC FIR为两色粗检测链提供带中心时间戳的滤波事务。
	ppg_coarse_detection_fir
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 统一向下传递物理帧号宽度
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 保持ADC事务序号字段一致
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH),  // 保持IDAC码快照位宽一致
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 保持IDAC码版本位宽一致
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // FIR中心元数据沿用wrapper级ACTIVE版本位宽
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // FIR中心元数据沿用wrapper级Stage1系数版本位宽
		.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH), // FIR中心元数据沿用wrapper级DC恢复版本位宽
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH), // FIR侧discard比对代际所用位宽，来自wrapper参数
		.C_ENABLE_TEST_INJECTION(C_ENABLE_TEST_INJECTION) // FIR验证注入结构生成开关，逐层透传自wrapper参数，生产网表恒为0

	// 完成粗FIR共享参数绑定并开始端口连接。
	)ppg_coarse_detection_fir_Inst(
		.i_clk(i_clk),                          // 连接2 MHz数字处理时钟
		.i_rstn(i_rstn),                        // 连接低有效异步复位
		.i_run_enable(i_run_enable),            // 并联RUN生命周期状态
		.i_start_ack_event(i_start_ack_event),  // 并联新RUN开始事件
		// 以下整组按合同5.10节原样广播给FIR，命中当前generation时清两色历史与MAC
		.i_detection_discard_event(i_detection_discard_event), // 清空事件本身
		.i_detection_discard_reason(i_detection_discard_reason), // STOP/abort/系统故障分类
		.i_detection_discard_identity_valid(i_detection_discard_identity_valid), // 0代表scope-only
		.i_detection_discard_sample_valid(i_detection_discard_sample_valid), // 触发事务的样本资格快照
		.i_detection_discard_frame_id(i_detection_discard_frame_id), // 追溯用帧号
		.i_detection_discard_sample_index(i_detection_discard_sample_index), // 追溯用全局序号
		.i_detection_discard_color_ir(i_detection_discard_color_ir), // 追溯用颜色身份
		.i_detection_discard_frame_type(i_detection_discard_frame_type), // 追溯用协议类别
		.i_detection_discard_precision(i_detection_discard_precision), // 追溯用精度身份
		.i_detection_discard_config_epoch(i_detection_discard_config_epoch), // 追溯用ACTIVE版本
		.i_detection_discard_coef_epoch(i_detection_discard_coef_epoch), // 追溯用Stage1系数版本
		.i_detection_discard_dc_recovery_epoch(i_detection_discard_dc_recovery_epoch), // 追溯用DC恢复版本
		.i_detection_discard_amb_code_epoch(i_detection_discard_amb_code_epoch), // 追溯用AMB码版本
		.i_detection_discard_dc_code_epoch(i_detection_discard_dc_code_epoch), // 追溯用颜色DC码版本
		.i_detection_discard_run_generation(i_detection_discard_run_generation), // 锁定这次要撤销哪一代
		.i_run_generation(i_run_generation),    // FIR侧比对代际用的实时快照
		.o_local_empty(fir_local_empty_o),      // 回收FIR两色历史与MAC均排空的回报
		.i_recheck_accept_event(amb_recheck_accept_o), // 真实安全接管才清除FIR历史
		.i_recheck_busy(amb_recheck_busy_o),    // 重检及恢复期间阻止NORMAL输入
		.i_result_valid(i_normal_result_valid), // 接收完整NORMAL粗结果valid
		.o_result_ready(normal_result_ready_o), // 返回FIR真实输入ready
		.i_sample_valid(i_sample_valid),        // 逐位传递独立样本资格，禁止映射到任何fork ready
		.i_coarse_ppg_value(i_coarse_ppg_value), // 输入DC恢复后的统一粗PPG值
		.i_coarse_valid(i_coarse_valid),        // 输入当前粗结果有效资格
		.i_coarse_recovery_calibrated(i_coarse_recovery_calibrated), // 输入正式恢复校准资格
		.i_stage1_saturation_low(i_stage1_saturation_low), // 输入Stage1负饱和诊断
		.i_stage1_saturation_high(i_stage1_saturation_high), // 输入Stage1正饱和诊断
		.i_coarse_saturation_low(i_coarse_saturation_low), // 输入粗恢复负饱和诊断
		.i_coarse_saturation_high(i_coarse_saturation_high), // 输入粗恢复正饱和诊断
		.i_config_epoch(i_config_epoch),        // 输入事务ACTIVE版本
		.i_coef_epoch(i_coef_epoch),            // 送入FIR的中心样本Stage1系数组
		.i_dc_recovery_coef_epoch(i_dc_recovery_coef_epoch), // 输入事务DC恢复版本
		.i_precision_mode(i_precision_mode),    // 保存事务开始时的真实精度
		.i_frame_id(i_frame_id),                // 输入当前物理帧号
		.i_sample_index(i_sample_index),        // 输入当前事务序号
		.i_color_ir(i_color_ir),                // 选择红光或红外历史
		.i_frame_type(i_frame_type),            // 输入NORMAL帧类型编码
		.i_amb_code_snapshot(i_amb_code_snapshot), // 保存中心AMB码快照
		.i_dc_code_snapshot(i_dc_code_snapshot), // 保存中心颜色DC码快照
		.i_amb_code_epoch(i_amb_code_epoch),    // 保存中心AMB码版本
		.i_dc_code_epoch(i_dc_code_epoch),      // 保存中心颜色DC码版本
		.i_test_inject_enable(i_test_inject_enable), // 直通AMI逐层传入的验证注入使能
		.i_test_calibration_loss_inject_valid(i_test_calibration_loss_inject_valid), // 直通calibration-loss注入请求valid
		.o_test_calibration_loss_inject_ready(o_test_calibration_loss_inject_ready), // 直通FIR的注入绑定ready
		.i_result_ready(flag_fir_result_ready), // Fork空闲或同沿释放时接收输出
		.o_result_valid(flag_fir_result_valid), // 输出保持型FIR事务valid
		.o_filtered_ppg_value(dec_fir_filtered_ppg_value), // 输出21抽头低通结果
		.o_detection_qualified(flag_fir_detection_qualified), // 输出完整窗口检测资格
		.o_window_saturation_low(flag_fir_window_saturation_low), // 输出窗口负端点诊断
		.o_window_saturation_high(flag_fir_window_saturation_high), // 输出窗口正端点诊断
		.o_fir_saturation_low(flag_fir_saturation_low), // 输出FIR负向饱和诊断
		.o_fir_saturation_high(flag_fir_saturation_high), // 输出FIR正向饱和诊断
		.o_history_full_r(fir_history_full_r_o), // 导出红光历史预热状态
		.o_history_full_ir(fir_history_full_ir_o), // 导出红外历史预热状态
		.o_fir_idle(fir_idle_o),                // 导出FIR内部排空状态
		.o_config_epoch(dec_fir_config_epoch),  // 接收中心ACTIVE版本
		.o_coef_epoch(dec_fir_coef_epoch),      // 捕获滤波中心的Stage1系数组
		.o_dc_recovery_coef_epoch(dec_fir_dc_recovery_coef_epoch), // 接收中心DC恢复版本
		.o_precision_mode(flag_fir_precision_mode), // 接收中心历史精度
		.o_frame_id(dec_fir_frame_id),          // 接收中心物理帧号
		.o_sample_index(dec_fir_sample_index),  // 接收中心事务序号
		.o_color_ir(flag_fir_color_ir),         // 接收中心颜色身份
		.o_frame_type(dec_fir_frame_type),      // 接收中心NORMAL编码
		.o_amb_code_snapshot(dec_fir_amb_code_snapshot), // 接收中心AMB码诊断
		.o_dc_code_snapshot(dec_fir_dc_code_snapshot), // 捕获中心颜色直流码快照
		.o_amb_code_epoch(dec_fir_amb_code_epoch), // 接收中心AMB码版本
		.o_dc_code_epoch(dec_fir_dc_code_epoch) // 捕获中心颜色直流码版本
	);

	// 例化动态基线检测器，依据粗模式上穿条件形成精细窗口请求。
	ppg_dynamic_baseline_cross_detector
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 统一传递400 Hz帧号宽度
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 设定峰谷极值事务序号位数
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 设定峰谷事件ACTIVE标签位数
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 设定基线周期的Stage1版本位宽
		.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH), // 设定峰谷恢复系数标签位数
		.C_SLOPE_WIDTH(C_SLOPE_WIDTH),          // 统一传递signed Q16斜率宽度
		.C_BASELINE_WIDTH(C_BASELINE_WIDTH),    // 统一传递基线内部运算宽度
		.C_RATIO_WIDTH(C_RATIO_WIDTH),          // 统一传递Q1.15比例宽度
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 保持discard组诊断码版本位宽一致
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH) // 保持RUN代际位宽一致

	// 完成动态基线算术参数绑定并开始端口连接。
	)ppg_dynamic_baseline_cross_detector_Inst(
		.i_clk(i_clk),                          // 驱动基线算术与握手时序
		.i_rstn(i_rstn),                        // 清除基线锚点和在途运算
		.i_run_enable(i_run_enable),            // 允许基线检测参与当前RUN
		.i_start_ack_event(i_start_ack_event),  // 初始化新RUN的基线状态
		.i_detection_discard_event(i_detection_discard_event), // 原样广播AMI代际清空事件
		.i_detection_discard_reason(i_detection_discard_reason), // 原样广播清空原因分类
		.i_detection_discard_identity_valid(i_detection_discard_identity_valid), // 原样广播触发事务身份资格
		.i_detection_discard_sample_valid(i_detection_discard_sample_valid), // 原样广播触发事务样本资格快照
		.i_detection_discard_frame_id(i_detection_discard_frame_id), // 原样广播触发事务帧号
		.i_detection_discard_sample_index(i_detection_discard_sample_index), // 原样广播触发事务序号
		.i_detection_discard_color_ir(i_detection_discard_color_ir), // 原样广播触发事务颜色
		.i_detection_discard_frame_type(i_detection_discard_frame_type), // 原样广播触发事务类型
		.i_detection_discard_precision(i_detection_discard_precision), // 原样广播触发事务精度
		.i_detection_discard_config_epoch(i_detection_discard_config_epoch), // 原样广播触发事务ACTIVE版本
		.i_detection_discard_coef_epoch(i_detection_discard_coef_epoch), // 原样广播触发事务Stage1系数版本
		.i_detection_discard_dc_recovery_epoch(i_detection_discard_dc_recovery_epoch), // 原样广播触发事务DC恢复版本
		.i_detection_discard_amb_code_epoch(i_detection_discard_amb_code_epoch), // 环境光抵消码版本诊断快照
		.i_detection_discard_dc_code_epoch(i_detection_discard_dc_code_epoch), // 原样广播触发事务颜色DC码版本
		.i_detection_discard_run_generation(i_detection_discard_run_generation), // 原样广播本次清空目标RUN代际
		.i_run_generation(i_run_generation),    // 并联AMI逐层传入的当前RUN代际
		.o_local_empty(baseline_local_empty_o), // 捕获动态基线本地排空回报
		.i_fine_window_active(fine_window_active_o), // 正式fine窗口禁止新相交
		.i_reacquire_request_event(reacquire_request_event_o), // 异常返回原子废止旧锚点
		.i_recheck_accept_event(amb_recheck_accept_o), // 安全重检接管清除临时候选
		.i_recheck_busy(flag_recheck_detector_busy), // 等待排空仍消费旧fork，accept后才冻结
		.i_recheck_done_event(flag_recheck_done_event), // 广播重检整体结束事件
		.i_recheck_success(flag_recheck_success), // 广播重检整体成功资格
		.i_result_valid(flag_baseline_pending), // Fork为动态基线保持独立valid
		.o_result_ready(flag_baseline_result_ready), // 动态基线返回本分支ready
		.i_filtered_ppg_value(dec_fork_filtered_ppg_value), // 输入保存的粗FIR码值
		.i_detection_qualified(flag_fork_detection_qualified), // 输入保存的检测资格
		.i_window_saturation_low(flag_fork_window_saturation_low), // 输入保存的窗口负饱和
		.i_window_saturation_high(flag_fork_window_saturation_high), // 输入保存的窗口正饱和
		.i_fir_saturation_low(flag_fork_fir_saturation_low), // 输入保存的FIR负饱和
		.i_fir_saturation_high(flag_fork_fir_saturation_high), // 输入保存的FIR正饱和
		.i_config_epoch(dec_fork_config_epoch), // 输入保存的ACTIVE版本
		.i_coef_epoch(dec_fork_coef_epoch),     // 绑定基线比较采用的Stage1系数组
		.i_dc_recovery_coef_epoch(dec_fork_dc_recovery_coef_epoch), // 输入保存的DC恢复版本
		.i_precision_mode(flag_fork_precision_mode), // 使用FIR中心真实历史精度
		.i_frame_id(dec_fork_frame_id),         // 输入FIR中心真实帧号
		.i_sample_index(dec_fork_sample_index), // 输入FIR中心事务序号
		.i_color_ir(flag_fork_color_ir),        // 红外事务只消费不更新RED状态
		.i_frame_type(dec_fork_frame_type),     // 输入FIR中心NORMAL编码
		.i_peak_valid(peak_pending_o),          // 接收保持型可靠波峰事件
		.o_peak_ready(flag_peak_ready),         // 返回波峰算术提交ready
		.i_peak_value(dec_peak_value),          // 输入可靠波峰码值
		.i_peak_frame_id(dec_peak_frame_id),    // 输入波峰实际帧号
		.i_peak_sample_index(dec_peak_sample_index), // 输入波峰实际事务号
		.i_peak_config_epoch(dec_peak_config_epoch), // 输入波峰ACTIVE版本
		.i_peak_coef_epoch(dec_peak_coef_epoch), // 校验波峰锚点Stage1系数组
		.i_peak_dc_recovery_coef_epoch(dec_peak_dc_recovery_coef_epoch), // 输入波峰DC恢复版本
		.i_valley_valid(valley_pending_o),      // 接收保持型可靠波谷事件
		.o_valley_ready(flag_valley_ready),     // 返回波谷事件消费ready
		.i_valley_value(dec_valley_value),      // 输入可靠波谷码值
		.i_valley_frame_id(dec_valley_frame_id), // 输入波谷实际帧号
		.i_valley_sample_index(dec_valley_sample_index), // 输入波谷实际事务号
		.i_valley_config_epoch(dec_valley_config_epoch), // 输入波谷ACTIVE版本
		.i_valley_coef_epoch(dec_valley_coef_epoch), // 校验波谷事件Stage1系数组
		.i_valley_dc_recovery_coef_epoch(dec_valley_dc_recovery_coef_epoch), // 输入波谷DC恢复版本
		.i_slope_mode(i_slope_mode),            // 选择固定或自适应斜率模式
		.i_fixed_slope_q16(i_fixed_slope_q16),  // 输入固定负斜率种子
		.i_alpha_q15(i_alpha_q15),              // 输入基础斜率幅度比例
		.i_beta_q15(i_beta_q15),                // 输入逐周期平滑比例
		.i_timing_adjust_ratio_q15(i_timing_adjust_ratio_q15), // 输入时刻闭环修正比例
		.i_slope_min_q16(i_slope_min_q16),      // 输入最负斜率边界
		.i_slope_max_q16(i_slope_max_q16),      // 输入近零斜率边界
		.i_baseline_delta_q16(i_baseline_delta_q16), // 输入波峰锚点基线偏置
		.i_cross_hysteresis_q16(i_cross_hysteresis_q16), // 输入向上相交迟滞量
		.i_lead_min_frames(i_lead_min_frames),  // 输入提前量窗口下界
		.i_lead_max_frames(i_lead_max_frames),  // 输入提前量窗口上界
		.i_cross_confirm_count(i_cross_confirm_count), // 输入相交连续确认点数
		.i_no_cross_limit(i_no_cross_limit),    // 输入无相交重新获取阈值
		.i_peak_valley_config_valid(i_peak_valley_config_valid), // 输入V5正式检测资格，限定below_seen武装和相交发布
		.i_cross_ready(flag_cross_ready),       // 精度控制器提供相交ready
		.o_cross_valid(cross_pending_o),        // 输出保持型进入15-bit请求
		.o_cross_frame_id(dec_cross_frame_id),  // 输出首次越过中心帧号
		.o_cross_sample_index(dec_cross_sample_index), // 输出首次越过事务序号
		.o_cross_time_unknown(flag_cross_time_unknown), // 输出相交时刻未知诊断
		.o_cross_config_epoch(dec_cross_config_epoch), // 输出相交ACTIVE版本
		.o_cross_coef_epoch(dec_cross_coef_epoch), // 导出相交事务Stage1系数组
		.o_cross_dc_recovery_coef_epoch(dec_cross_dc_recovery_coef_epoch), // 输出相交DC恢复版本
		.o_cross_slope_q16(),                   // 相交斜率诊断不参与闭环控制
		.o_cross_baseline_q16(),                // 相交基线诊断不参与闭环控制
		.o_baseline_valid(baseline_valid_o),    // 导出当前基线有效资格
		.o_adaptive_slope_valid(flag_adaptive_slope_valid), // 保存自适应更新资格诊断
		.o_slope_current_q16(slope_current_q16_o), // 导出当前活动负斜率
		.o_slope_base_q16(dec_slope_base_q16),  // 保存最近基础斜率诊断
		.o_last_lead_frames(dec_last_lead_frames), // 保存最近相交提前量诊断
		.o_no_cross_count(cnt_no_cross),        // 保存连续无相交周期计数
		.o_reacquire_active(reacquire_active_o), // 驱动峰谷检测重新获取状态
		.o_slope_saturation_min(flag_slope_saturation_min), // 保存最负斜率限幅诊断
		.o_slope_saturation_max(flag_slope_saturation_max), // 保存近零斜率限幅诊断
		.o_baseline_saturation_low(flag_baseline_saturation_low), // 保存基线低端饱和诊断
		.o_baseline_saturation_high(flag_baseline_saturation_high), // 保存基线高端饱和诊断
		.o_protocol_error_sticky(baseline_protocol_error_sticky_o) // 导出动态基线协议诊断
	);

	// 例化峰谷窗口检测器，确认极值并保持返回粗模式的协议请求。
	ppg_peak_valley_window_detector
	#(
		.C_DATA_WIDTH(C_DATA_WIDTH),            // 统一传递粗FIR数据字段宽度
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 统一传递物理帧号字段宽度
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 统一传递ADC事务序号宽度
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 统一传递ACTIVE版本宽度
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 设定峰谷Stage1系数标签位数
		.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH), // 统一传递DC恢复版本宽度
		.C_CONFIRM_COUNT_WIDTH(C_CONFIRM_COUNT_WIDTH), // 统一传递连续确认计数宽度
		.C_INTERVAL_WIDTH(C_INTERVAL_WIDTH),    // 统一传递峰谷时间字段宽度
		.C_FIR_GROUP_DELAY_SAMPLES(C_FIR_GROUP_DELAY_SAMPLES), // 固定传递20阶FIR群延时
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 峰谷侧discard诊断字段共用此位宽
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH) // 峰谷侧discard比对代际所用位宽，来自wrapper参数

	// 完成峰谷检测参数绑定并开始端口连接。
	)ppg_peak_valley_window_detector_Inst(
		.i_clk(i_clk),                          // 驱动峰谷连续确认状态更新
		.i_rstn(i_rstn),                        // 清除极值历史和保持事件
		.i_run_enable(i_run_enable),            // 允许峰谷检测处理RUN样本
		.i_start_ack_event(i_start_ack_event),  // 建立粗模式重新获取初态
		// 以下整组转发给峰谷检测器，命中当前generation时清极值、窗口与返回pending
		.i_detection_discard_event(i_detection_discard_event), // 是否发生清空
		.i_detection_discard_reason(i_detection_discard_reason), // 清空来源分类编码
		.i_detection_discard_identity_valid(i_detection_discard_identity_valid), // scope-only判别位
		.i_detection_discard_sample_valid(i_detection_discard_sample_valid), // 触发样本当时的资格
		.i_detection_discard_frame_id(i_detection_discard_frame_id), // 峰谷侧核对帧号用
		.i_detection_discard_sample_index(i_detection_discard_sample_index), // 峰谷侧核对序号用
		.i_detection_discard_color_ir(i_detection_discard_color_ir), // 峰谷侧核对颜色用
		.i_detection_discard_frame_type(i_detection_discard_frame_type), // 峰谷侧核对类别用
		.i_detection_discard_precision(i_detection_discard_precision), // 峰谷侧核对精度用
		.i_detection_discard_config_epoch(i_detection_discard_config_epoch), // 峰谷侧核对ACTIVE版本用
		.i_detection_discard_coef_epoch(i_detection_discard_coef_epoch), // 峰谷侧核对系数版本用
		.i_detection_discard_dc_recovery_epoch(i_detection_discard_dc_recovery_epoch), // 峰谷侧核对恢复版本用
		.i_detection_discard_amb_code_epoch(i_detection_discard_amb_code_epoch), // 环境光抵消码提交版本，仅存档
		.i_detection_discard_dc_code_epoch(i_detection_discard_dc_code_epoch), // 颜色直流抵消码版本，仅存档
		.i_detection_discard_run_generation(i_detection_discard_run_generation), // 清空所指向的具体代际
		.i_run_generation(i_run_generation),    // 峰谷侧比对代际的实时快照
		.o_local_empty(peak_valley_local_empty_o), // 回收峰谷极值与pending均排空的回报
		.i_diag_clear_event(i_diag_clear_event), // 并联软件诊断清除事件
		.i_recheck_accept_event(amb_recheck_accept_o), // 真实重检接管清除尾部和极值
		.i_recheck_busy(flag_recheck_detector_busy), // 等待排空仍释放旧事务，accept后才冻结
		.i_recheck_done_event(flag_recheck_done_event), // 通知峰谷链重检序列已经结束
		.i_recheck_success(flag_recheck_success), // 允许成功重检后重新预热检测
		.i_reacquire_active(reacquire_active_o), // 接收动态基线重新获取要求
		.i_peak_confirm_count(i_peak_confirm_count), // 输入波峰连续下降确认数
		.i_valley_confirm_count(i_valley_confirm_count), // 输入波谷连续上升确认数
		.i_direction_deadband(i_direction_deadband), // 输入方向分类死区
		.i_min_peak_valley_amplitude(i_min_peak_valley_amplitude), // 输入合格峰谷最小幅度
		.i_min_peak_to_valley_frames(i_min_peak_to_valley_frames), // 输入波峰至波谷最小帧差
		.i_min_peak_to_peak_frames(i_min_peak_to_peak_frames), // 输入相邻波峰最小帧差
		.i_max_fine_window_frames(i_max_fine_window_frames), // 输入fine窗口最大持续帧数
		.i_max_reacquire_frames(i_max_reacquire_frames), // 输入重新获取最大持续帧数
		.i_peak_valley_config_valid(i_peak_valley_config_valid), // 输入峰谷配置正式资格
		.i_characterization_mode(i_run_profile), // 直接使用唯一RUN profile控制位
		.i_result_valid(flag_peak_valley_pending), // Fork为峰谷检测保持独立valid
		.o_result_ready(flag_peak_valley_result_ready), // 峰谷检测返回本分支ready
		.i_filtered_ppg_value(dec_fork_filtered_ppg_value), // 提供峰谷方向判断的滤波码值
		.i_detection_qualified(flag_fork_detection_qualified), // 限定可更新极值的正式样本
		.i_window_saturation_low(flag_fork_window_saturation_low), // 阻断含负饱和窗口的极值判定
		.i_window_saturation_high(flag_fork_window_saturation_high), // 阻断含正饱和窗口的极值判定
		.i_fir_saturation_low(flag_fork_fir_saturation_low), // 记录峰谷数据负端饱和风险
		.i_fir_saturation_high(flag_fork_fir_saturation_high), // 记录峰谷数据正端饱和风险
		.i_config_epoch(dec_fork_config_epoch), // 绑定峰谷事件所用ACTIVE配置
		.i_coef_epoch(dec_fork_coef_epoch),     // 绑定峰谷事件所用Stage1系数
		.i_dc_recovery_coef_epoch(dec_fork_dc_recovery_coef_epoch), // 绑定峰谷事件所用恢复系数
		.i_precision_mode(flag_fork_precision_mode), // 校验中心样本所属精度窗口
		.i_frame_id(dec_fork_frame_id),         // 保存实际极值中心物理帧号
		.i_sample_index(dec_fork_sample_index), // 输入FIR中心事务号
		.i_color_ir(flag_fork_color_ir),        // 选择参与控制的红光样本身份
		.i_frame_type(dec_fork_frame_type),     // 限定峰谷链只处理NORMAL事务
		.i_fine_window_start_event(fine_window_start_event_o), // 接收真实进入15-bit提交事件
		.i_fine_window_start_frame_id(fine_window_start_frame_id_o), // 接收第一笔正式15-bit帧号
		.i_active_precision_mode(active_precision_mode_o), // 检查系统真实committed精度
		.o_return_9bit_valid(return_pending_o), // 输出保持型返回9-bit请求
		.i_return_9bit_ready(flag_return_9bit_ready), // 接收精度控制器return ready
		.o_return_reason(dec_return_reason),    // 输出返回原因编码
		.o_return_frame_id(dec_return_frame_id), // 输出返回请求检测帧号
		.o_peak_valid(peak_pending_o),          // 输出保持型可靠波峰事件
		.i_peak_ready(flag_peak_ready),         // 接收动态基线波峰ready
		.o_peak_value(dec_peak_value),          // 输出可靠波峰码值
		.o_peak_frame_id(dec_peak_frame_id),    // 输出波峰实际帧号
		.o_peak_sample_index(dec_peak_sample_index), // 输出波峰实际事务号
		.o_peak_config_epoch(dec_peak_config_epoch), // 输出波峰ACTIVE版本
		.o_peak_coef_epoch(dec_peak_coef_epoch), // 输出波峰锁存的Stage1系数组
		.o_peak_dc_recovery_coef_epoch(dec_peak_dc_recovery_coef_epoch), // 输出波峰DC恢复版本
		.o_valley_valid(valley_pending_o),      // 输出保持型可靠波谷事件
		.i_valley_ready(flag_valley_ready),     // 接收动态基线波谷ready
		.o_valley_value(dec_valley_value),      // 输出可靠波谷码值
		.o_valley_frame_id(dec_valley_frame_id), // 输出波谷实际帧号
		.o_valley_sample_index(dec_valley_sample_index), // 输出波谷实际事务号
		.o_valley_config_epoch(dec_valley_config_epoch), // 输出波谷ACTIVE版本
		.o_valley_coef_epoch(dec_valley_coef_epoch), // 输出波谷锁存的Stage1系数组
		.o_valley_dc_recovery_coef_epoch(dec_valley_dc_recovery_coef_epoch), // 输出波谷DC恢复版本
		.o_detector_idle(detector_idle_o),      // 导出允许重检接管的真实idle
		.o_fine_window_active(detector_fine_window_active_o), // 导出检测器fine状态
		.o_reacquire_search_active(flag_reacquire_search_active), // 保存检测器重新获取诊断
		.o_fine_window_timeout_sticky(fine_window_timeout_sticky_o), // 导出fine超时历史
		.o_reacquire_timeout_sticky(reacquire_timeout_sticky_o), // 导出重新获取超时历史
		.o_protocol_error_sticky(peak_valley_protocol_error_sticky_o) // 导出峰谷协议诊断
	);

	// 例化精度窗口控制器，在安全帧边界原子提交模式切换。
	ppg_precision_window_controller
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),    // 配置安全提交帧号字段位宽
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 统一传递相交事务号宽度
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 配置相交请求ACTIVE版本位宽
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH), // 设置控制器接收的Stage1标签位数
		.C_DC_RECOVERY_EPOCH_WIDTH(C_DC_RECOVERY_EPOCH_WIDTH), // 配置相交请求恢复版本位宽
		.C_SWITCH_TIMEOUT_CYCLES(C_SWITCH_TIMEOUT_CYCLES), // 传递精度提交超时周期数
		.C_SWITCH_TIMEOUT_COUNTER_WIDTH(C_SWITCH_TIMEOUT_COUNTER_WIDTH), // 传递超时计数器位宽
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 精度控制器discard诊断字段共用此位宽
		.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH) // 精度控制器discard比对代际所用位宽，来自wrapper参数

	// 完成精度控制参数绑定并开始端口连接。
	)ppg_precision_window_controller_Inst(
		.i_clk(i_clk),                          // 驱动精度请求和安全提交状态
		.i_rstn(i_rstn),                        // 恢复初始精度并撤销pending
		.i_run_enable(i_run_enable),            // 允许NORMAL精度窗口自动控制
		.i_start_ack_event(i_start_ack_event),  // 按配置建立启动精度状态
		// 以下整组接入精度控制器，命中当前generation时撤销相交/返回/切换pending
		.i_detection_discard_event(i_detection_discard_event), // 清空是否命中本拍
		.i_detection_discard_reason(i_detection_discard_reason), // 区分STOP/abort/系统故障
		.i_detection_discard_identity_valid(i_detection_discard_identity_valid), // 为0即scope-only
		.i_detection_discard_sample_valid(i_detection_discard_sample_valid), // 记录触发样本的资格位
		.i_detection_discard_frame_id(i_detection_discard_frame_id), // 控制器诊断可追溯帧号
		.i_detection_discard_sample_index(i_detection_discard_sample_index), // 控制器诊断可追溯序号
		.i_detection_discard_color_ir(i_detection_discard_color_ir), // 控制器诊断可追溯颜色
		.i_detection_discard_frame_type(i_detection_discard_frame_type), // 控制器诊断可追溯类别
		.i_detection_discard_precision(i_detection_discard_precision), // 控制器诊断可追溯精度
		.i_detection_discard_config_epoch(i_detection_discard_config_epoch), // 控制器诊断可追溯ACTIVE版本
		.i_detection_discard_coef_epoch(i_detection_discard_coef_epoch), // 控制器诊断可追溯系数版本
		.i_detection_discard_dc_recovery_epoch(i_detection_discard_dc_recovery_epoch), // 控制器诊断可追溯恢复版本
		.i_detection_discard_amb_code_epoch(i_detection_discard_amb_code_epoch), // 事后排障用，控制器本身不使用IDAC码版本
		.i_detection_discard_dc_code_epoch(i_detection_discard_dc_code_epoch), // 事后排障用，同样不参与控制器自身判断
		.i_detection_discard_run_generation(i_detection_discard_run_generation), // 清空事件锁定的代际编号
		.i_run_generation(i_run_generation),    // 控制器现场比对代际的实时值
		.o_local_empty(precision_local_empty_o), // 回收控制器无pending无故障保持的回报
		.i_diag_clear_event(i_diag_clear_event), // 清除精度控制历史诊断
		.i_active_config_valid(i_active_config_valid), // 输入ACTIVE整体合法资格
		.i_run_profile(i_run_profile),          // 输入NORMAL或表征模式
		.i_initial_precision(i_initial_precision), // 输入表征模式初始精度
		.i_normal_measurement_active(i_normal_measurement_active), // 输入正式NORMAL测量资格
		.i_peak_valley_config_valid(i_peak_valley_config_valid), // 输入V5正式检测资格，限定新cross接纳
		.i_cross_valid(cross_pending_o),        // 接收动态基线保持的cross请求
		.o_cross_ready(flag_cross_ready),       // 返回cross请求消费ready
		.i_cross_frame_id(dec_cross_frame_id),  // 输入相交真实中心帧号
		.i_cross_sample_index(dec_cross_sample_index), // 输入相交事务序号
		.i_cross_time_unknown(flag_cross_time_unknown), // 输入相交时刻未知诊断
		.i_cross_config_epoch(dec_cross_config_epoch), // 输入相交ACTIVE版本
		.i_cross_coef_epoch(dec_cross_coef_epoch), // 检查相交请求Stage1系数组
		.i_cross_dc_recovery_coef_epoch(dec_cross_dc_recovery_coef_epoch), // 输入相交DC恢复版本
		.i_return_9bit_valid(return_pending_o), // 接收峰谷保持的return请求
		.o_return_9bit_ready(flag_return_9bit_ready), // 允许峰谷链提交返回粗模式请求
		.i_return_reason(dec_return_reason),    // 输入返回原因编码
		.i_return_frame_id(dec_return_frame_id), // 输入返回请求检测帧号
		.i_frame_safe_boundary(i_frame_safe_boundary), // 输入下一帧安全提交边界
		.i_safe_frame_id(i_safe_frame_id),      // 输入即将启动帧的真实编号
		.i_precision_takeover_safe(i_precision_takeover_safe), // 层级原样转发AMI复合切换资格
		.i_analog_safe(i_analog_safe),          // 要求模拟相位允许精度切换
		.i_recheck_busy(amb_recheck_busy_o),    // 重检占用期间禁止精度抢占
		.o_active_precision_mode(active_precision_mode_o), // 导出唯一committed精度
		.o_fine_window_active(fine_window_active_o), // 导出正式15-bit窗口资格
		.o_fine_window_start_event(fine_window_start_event_o), // 导出真实进入fine事件
		.o_fine_window_start_frame_id(fine_window_start_frame_id_o), // 导出第一笔fine帧号
		.o_precision_15_to_9_event(precision_15_to_9_event_o), // 导出真实返回9-bit事件
		.o_precision_15_to_9_frame_id(precision_15_to_9_frame_id_o), // 导出第一笔恢复9-bit帧号
		.o_reacquire_request_event(reacquire_request_event_o), // 导出异常返回重新获取事件
		.o_mode_fault_event(flag_precision_controller_fault_event), // 接住阻断故障新episode单拍，供PWI登记网转发
		.o_mode_fault_active(flag_precision_controller_fault_active), // 接住当前代际故障保持电平，直到discard或reset解除；precision controller→PWI私有flag,链路起点 @satisfies: K01
		.o_mode_fault_identity_valid(flag_precision_controller_fault_identity_valid), // 接住身份是否可信标志，无效时全部字段应为0
		.o_mode_fault_frame_id(flag_precision_controller_fault_frame_id), // 接住故障样本所属的真实物理帧号
		.o_mode_fault_sample_index(flag_precision_controller_fault_sample_index), // 接住故障样本的全局事务顺序编号
		.o_mode_fault_color_ir(flag_precision_controller_fault_color_ir), // 接住颜色标记，本链路只处理RED故障恒为0
		.o_mode_fault_frame_type(flag_precision_controller_fault_frame_type), // 接住事务类别编码，有效身份固定为NORMAL
		.o_mode_fault_precision(flag_precision_controller_fault_precision), // 接住故障建立时所属的9/15-bit精度模式
		.o_mode_fault_run_generation(flag_precision_controller_fault_run_generation), // 接住故障绑定时刻锁存的RUN代际编号
		.o_switch_pending(switch_pending_o),    // 导出等待安全提交状态
		.o_switch_target_precision(switch_target_precision_o), // 导出当前pending目标精度
		.o_switch_hold_new_transaction(switch_hold_new_transaction_o), // 导出停止新ADC事务要求
		.o_controller_idle(controller_idle_o),  // 导出精度控制排空状态
		.o_last_cross_time_unknown(flag_last_cross_time_unknown), // 保存最近相交时间诊断
		.o_last_return_reason(dec_last_return_reason), // 保存最近返回原因诊断
		.o_switch_timeout_sticky(switch_timeout_sticky_o), // 导出精度提交超时历史
		.o_protocol_error_sticky(precision_protocol_error_sticky_o) // 导出精度协议异常历史
	);

	// 例化AMB重检调度器，在返回粗模式后组织固定三帧校准序列。
	ppg_amb_recheck_scheduler ppg_amb_recheck_scheduler_Inst(
		.i_clk(i_clk),                          // AMB时钟
		.i_rstn(i_rstn),                        // AMB复位
		.i_run_enable(i_run_enable),            // RUN计数
		.i_start_ack_event(i_start_ack_event),  // START定点
		// scheduler原有的两个独立取消端口未删除，只是改接同一根flag_detection_discard_apply
		.i_stop_ack_event(flag_detection_discard_apply), // AMI已经不再区分STOP与abort两种取消来源，二者统一折叠进这一根线路
		.i_control_abort_event(flag_detection_discard_apply), // 这一行只是把上一行的相同判断结果再送一份，满足scheduler原有的两路输入形状
		.i_idac_mode(i_idac_mode),              // IDAC选模
		.i_amb_enable(i_amb_enable),            // AMB许可
		.i_dcs_enable(i_dcs_enable),            // 为0时跳过DCS_CAL环节，只走AMB_CAL和恢复预热两段
		.i_amb_recheck_interval_frames(i_amb_recheck_interval_frames), // 重检间隔帧数
		.i_startup_search_complete(i_startup_search_complete), // 输入启动搜索完成资格
		.i_normal_measurement_active(i_normal_measurement_active), // 输入NORMAL测量资格
		.i_normal_frame_complete_event(i_normal_frame_complete_event), // 输入完整NORMAL帧结束事件
		.i_precision_15_to_9_event(precision_15_to_9_event_o), // 只观察真实返回9-bit提交事件
		.i_precision_takeover_safe(i_precision_takeover_safe), // 要求重检接管前ADC复合流水排空
		.i_normal_fork_idle(i_normal_fork_idle), // 要求上游NORMAL fork排空
		.i_idac_idle(i_idac_idle),              // 要求IDAC控制器没有在途事务
		.i_fir_idle(flag_fir_idle_to_scheduler), // 同时要求FIR和检测fork排空
		.i_peak_valley_idle(detector_idle_o),   // 要求峰谷真实事务允许接管
		.i_frame_safe_boundary(i_frame_safe_boundary), // 当前沿必须是安全帧边界
		.i_calibration_frame_complete_event(i_calibration_frame_complete_event), // 输入当前校准帧结束事件
		.i_amb_sample_request(i_amb_sample_request), // 输入AMB_CAL样本请求
		.i_amb_sequence_done(i_amb_sequence_done), // 输入AMB检查或搜索成功
		.i_amb_sequence_failed(i_amb_sequence_failed), // 输入AMB搜索失败
		.i_dcs_revalidate_request(i_dcs_revalidate_request), // 输入两色DC重验证请求
		.i_dcs_sample_request(i_dcs_sample_request), // 输入当前DCS_CAL样本请求
		.i_dcs_sample_color_ir(i_dcs_sample_color_ir), // 输入当前DCS颜色身份
		.i_dcs_revalidate_done(i_dcs_revalidate_done), // 输入两色DC整体成功
		.i_dcs_revalidate_failed(i_dcs_revalidate_failed), // 输入任一路DC失败
		.i_amb_sample_accepted_event(i_amb_sample_accepted_event), // 输入AMB_CAL结果消费事件
		.i_dcs_sample_accepted_event(i_dcs_sample_accepted_event), // 确认颜色直流校准样本已消费
		.o_amb_sequence_start(enc_amb_sequence_start_o), // 导出AMB检查启动事件
		.o_dcs_revalidate_accept(dcs_revalidate_accept_o), // 导出两色DC重验证接受事件
		.i_calibration_sample_ready(i_calibration_sample_ready), // 输入模拟调度器采样ready
		.o_calibration_sample_valid(calibration_sample_valid_o), // 导出保持型校准采样valid
		.o_calibration_frame_type(calibration_frame_type_o), // 导出AMB或DCS帧类型
		.o_calibration_color_ir(calibration_color_ir_o), // 导出DCS_CAL颜色选择
		.o_calibration_precision_mode(calibration_precision_mode_o), // 导出固定SAR9精度
		.o_calibration_frame_start(calibration_frame_start_o), // 导出校准帧开始事件
		.o_calibration_stage(calibration_stage_o), // 导出当前三阶段编码
		.o_normal_frame_count(cnt_normal_frame_o), // 导出周期NORMAL帧计数
		.o_amb_recheck_pending(amb_recheck_pending_o), // 导出等待下一次15到9状态
		.o_amb_recheck_accept(amb_recheck_accept_o), // 导出真实安全接管事件
		.o_amb_recheck_busy(amb_recheck_busy_o), // 导出重检和恢复占用状态
		.o_normal_output_inhibit(normal_output_inhibit_o), // 导出正式输出禁止状态
		.o_sequence_done(enc_recheck_sequence_done_o), // 导出三阶段整体成功事件
		.o_sequence_failed(enc_recheck_sequence_failed_o), // 导出任一阶段失败事件
		.o_scheduler_idle(scheduler_idle_o)     // 导出scheduler排空状态
	);

endmodule
