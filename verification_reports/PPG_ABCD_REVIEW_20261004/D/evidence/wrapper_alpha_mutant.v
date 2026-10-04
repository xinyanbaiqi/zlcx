`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/14
// Design Name:        PPG ACTIVE V4 Control Plane Integration Wrapper
// Module Name:        ppg_active_v4_control_plane_integration
// Description:       640-bit configuration CDC, lifecycle manager and unique V4 unpack point
// Simulations:        tb_ppg_active_v4_control_plane_integration.v
//
// Referrences:        PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md,
//                     PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_config_cdc_bridge.v,
//                     ppg_system_config_manager.v,
//                     ppg_system_active_config_unpack.v
//
// Version:            V1.6
// Revision Date:      2026/08/23
// History:
// 2026/08/14          V1.0        Erie          Create frozen 640-bit control-plane wrapper.
// 2026/08/23          V1.6        Erie          Widen the source snapshot and ACTIVE bus to the 1024-bit V4+V5 joint payload, add transparent i_system_fault_blocking/i_static_characterization_enable/o_run_generation/o_stop_episode_active forwarding to/from the manager, and export the 20-field V5 unpack image per the current contract's Section 8.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月14日
// 设计名称:           PPG ACTIVE V4控制平面集成Wrapper
// 模块名称:           ppg_active_v4_control_plane_integration
// 模块说明:           连接1024-bit V4+V5联合配置CDC、生命周期管理器和唯一字段解包点
// 仿真工程:           tb_ppg_active_v4_control_plane_integration.v
//
// 参考资料:           PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md、
//                     PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_config_cdc_bridge.v、
//                     ppg_system_config_manager.v、
//                     ppg_system_active_config_unpack.v
//
// 当前版本:           V1.6
// 修订日期:           2026年08月23日
// 修订历史:
// 2026年08月14日       V1.0        Erie          创建冻结的640-bit控制平面Wrapper。
// 2026年08月23日       V1.6        Erie          source快照与ACTIVE总线扩展为1024-bit V4+V5联合载荷，新增i_system_fault_blocking/i_static_characterization_enable/o_run_generation/o_stop_episode_active透明转发，按当前合同§8导出V5解包20个字段

// 该Wrapper只连接配置传输、ACTIVE生命周期和唯一字段解包，不实现PPG算法或模拟波形。
module ppg_active_v4_control_plane_integration
(
	//---------------全局信号---------------//
	input i_source_clk,                     //source配置时钟
	input i_source_rstn,                    //source域低有效复位
	input [1023:0]i_source_config_snapshot, //source域完整V4+V5联合shadow快照
	input i_source_config_update_event,     //source域请求传输快照的单周期事件

	//---------------用户接口---------------//
	input i_clk,                            //2 MHz系统控制时钟
	input i_rstn,                           //控制域低有效复位，撤销生命周期状态
	input i_start_event,                    //已同步START事件
	input i_stop_event,                     //请求停止并进入排空流程的同步事件
	input i_status_clear_event,             //已同步sticky清除事件

	//---------------系统资格与排空输入---------------//
	input i_analog_ready,                             //模拟偏置和参考具备启动资格
	input i_adc_idle,                                 //物理ADC和DONE捕获链已经排空
	input i_datapath_empty,                           //AMI保持型数据链已经排空
	input i_idac_idle,                                //AMI IDAC搜索和提交已经排空
	input i_analog_safe,                              //模拟控制已经回到安全保持状态
	input i_system_fault_blocking,                    //supervisor经Top送达的注册系统阻断故障电平，只透明送manager并阻断START
	input i_static_characterization_enable,           //顶层唯一2 MHz已提交STATIC_BIAS资格电平，直连manager

	//---------------配置传输状态输出---------------//
	output o_config_transport_busy,                 //source快照CDC事务仍在途
	output o_config_transport_update,               //destination域已收到完整快照的单周期事件

	//---------------ACTIVE快照与版本输出---------------//
	output [1023:0]o_active_config,                     //manager合法提交并保持的V4+V5联合ACTIVE快照
	output o_active_valid,                              //ACTIVE具备本轮启动资格
	output [7:0]o_config_epoch,                         //完整配置版本
	output [7:0]o_coef_epoch,                           //Stage1系数版本
	output [7:0]o_stage2_coef_epoch,                    //Stage2增益和偏置字段的独立版本
	output [7:0]o_dc_recovery_coef_epoch,               //DC恢复系数版本

	//---------------生命周期状态输出---------------//
	output [1:0]o_lifecycle_state,                  //CONFIG、READY、RUN或STOPPING
	output o_start_ready,                           //READY且所有启动资格满足
	output o_run_enable,                            //RUN功能链许可
	output o_allow_new_transaction,                 //新ADC事务发起许可
	output [7:0]o_run_generation,                   //manager唯一产生的代际，Wrapper仅逐位转发
	output o_stop_episode_active,                   //manager唯一产生的排空episode电平，Wrapper仅逐位转发

	//---------------响应与错误状态输出-------------//
	output o_commit_ack_event,                      //合法配置成为ACTIVE的单周期应答
	output o_start_ack_event,                       //START合法接受的单周期应答
	output o_stop_ack_event,                        //STOP接受或幂等处理的单周期应答
	output o_error_event,                           //当前配置或命令被拒绝的单周期事件
	output o_commit_ack_sticky,                     //配置成功sticky状态
	output o_error_sticky,                          //错误汇总sticky状态
	output [7:0]o_last_error_code,                  //最近一次错误分类码

	//---------------V4系统模式解包输出-------------//
	output [7:0]o_schema_version,                   //V4快照格式版本
	output o_run_profile,                           //NORMAL或CHARACTERIZATION档位
	output o_input_source,                          //光电二极管或外部测试输入
	output [1:0]o_idac_mode,                        //MANUAL、SEARCH_HOLD或SEARCH_TRACK
	output [1:0]o_optical_mode,                     //双光、RED、IR或安全关闭
	output o_initial_precision,                     //RUN初始SAR精度
	output o_amb_enable,                            //AMB控制参与资格
	output o_dcs_enable,                            //红光和红外DC码搜索功能使能
	output o_amb_polarity,                          //AMB调码极性
	output o_dcs_polarity,                          //DC搜索时数字码的递增方向
	output o_stage1_calibration_valid,              //Stage1系数有效标志
	output o_stage2_calibration_valid,              //Stage2恢复计算参数已表征的标志
	output o_dc9_recovery_valid,                    //SAR9 DC恢复有效标志
	output o_dc15_recovery_valid,                   //SAR15精度链DC恢复数据可采用标志

	//---------------V4 IDAC码值解包输出-------------//
	output [7:0]o_amb_manual_code,                   //AMB初始或手动码
	output [7:0]o_amb_code_min,                      //AMB最小提交码
	output [7:0]o_amb_code_max,                      //AMB最大提交码
	output [7:0]o_dcs_r_manual_code,                 //红光DC初始或手动码
	output [7:0]o_dcs_r_code_min,                    //红光DC最小提交码
	output [7:0]o_dcs_r_code_max,                    //红光DC最大提交码
	output [7:0]o_dcs_ir_manual_code,                //红外DC初始或手动码
	output [7:0]o_dcs_ir_code_min,                   //红外DC最小提交码
	output [7:0]o_dcs_ir_code_max,                   //红外DC最大提交码

	//---------------V4阈值与计数解包输出-------------//
	output signed [11:0]o_amb_threshold_low,          //AMB低阈值
	output signed [11:0]o_amb_threshold_high,         //AMB高阈值
	output signed [11:0]o_dcs_threshold_low,          //DCS低阈值
	output signed [11:0]o_dcs_threshold_high,         //DCS高阈值
	output [7:0]o_amb_confirm_count,                  //AMB连续确认次数
	output [7:0]o_dcs_confirm_count,                  //红光和红外DC候选码的收敛确认次数

	//---------------Stage1系数解包输出---------------//
	output signed [25:0]o_stage1_weight_q16_0,        //Stage1权重0
	output signed [25:0]o_stage1_weight_q16_1,        //Stage1权重1
	output signed [25:0]o_stage1_weight_q16_2,        //Stage1权重2
	output signed [25:0]o_stage1_weight_q16_3,        //Stage1权重3
	output signed [25:0]o_stage1_weight_q16_4,        //Stage1权重4
	output signed [25:0]o_stage1_weight_q16_5,        //Stage1权重5
	output signed [25:0]o_stage1_weight_q16_6,        //Stage1权重6
	output signed [25:0]o_stage1_weight_q16_7,        //Stage1权重7
	output signed [25:0]o_stage1_weight_q16_8,        //Stage1权重8
	output signed [25:0]o_stage1_weight_q16_9,        //Stage1权重9
	output signed [31:0]o_stage1_offset_q16,          //Stage1加性offset

	//---------------Stage2与DC恢复解包输出----------//
	output signed [19:0]o_stage2_gain_q16,           //Stage2统一增益
	output signed [31:0]o_stage2_offset_q16,         //Stage2加性offset
	output signed [31:0]o_dc9_recovery_gain_q16,     //SAR9 DC恢复增益
	output signed [31:0]o_dc15_recovery_gain_q16,    //SAR15精度域DC恢复使用的Q16增益

	//---------------调度配置解包输出-----------------//
	output [15:0]o_amb_recheck_interval_frames,       //NORMAL完整帧重检间隔

	//---------------V5基线斜率解包输出---------------//
	output o_slope_mode,                              //基线斜率固定或自适应模式
	output signed [31:0]o_fixed_slope_q16,            //固定负斜率的signed Q16值
	output [15:0]o_alpha_q15,                         //基础斜率幅度比例
	output [15:0]o_beta_q15,                          //活动斜率平滑比例
	output [15:0]o_timing_adjust_ratio_q15,           //相交时刻修正比例
	output signed [31:0]o_slope_min_q16,              //最负斜率边界
	output signed [31:0]o_slope_max_q16,              //最接近零斜率边界
	output signed [31:0]o_baseline_delta_q16,         //波峰锚点基线偏置
	output [31:0]o_cross_hysteresis_q16,              //向上相交迟滞量

	//---------------V5相交与峰谷解包输出---------------//
	output [15:0]o_lead_min_frames,                     //相交提前量合格下界
	output [15:0]o_lead_max_frames,                     //相交提前量合格上界
	output [3:0]o_cross_confirm_count,                  //相交连续确认点数
	output [3:0]o_no_cross_limit,                       //连续无相交重新获取阈值
	output [3:0]o_peak_confirm_count,                   //波峰连续下降确认点数
	output [3:0]o_valley_confirm_count,                 //波谷连续上升确认点数
	output [23:0]o_direction_deadband,                  //相邻FIR方向分类死区
	output [23:0]o_min_peak_valley_amplitude,           //合格峰谷最小幅度
	output [15:0]o_min_peak_to_valley_frames,           //波峰到波谷最小帧差
	output [15:0]o_min_peak_to_peak_frames,             //相邻波峰最小帧差

	//---------------V5精度窗口解包输出---------------//
	output [15:0]o_max_fine_window_frames,            //15-bit窗口最大持续帧数
	output [15:0]o_max_reacquire_frames,              //9-bit重新获取最大帧数
	output o_peak_valley_config_valid                 //正式peak/valley/cross/fine-window资格位
);

	//------------模块实例化信号------------//
	//CDC内部连线
	wire [1023:0]wire_destination_config;   //destination域原子接收的完整V4+V5联合快照
	wire wire_source_busy;                  //source域CDC事务尚未完成标志

	//---------------输出信号---------------//
	//生命周期管理器输出缓存
	wire config_transport_busy_o;           //CDC物理占用状态的内部输出
	wire config_transport_update_o;         //CDC到达事件的内部输出
	wire [1023:0]active_config_o;           //manager提交后的V4+V5联合ACTIVE总线
	wire active_valid_o;                    //本运行轮次ACTIVE合法状态
	wire [7:0]config_epoch_o;               //整体V4配置提交版本
	wire [7:0]coef_epoch_o;                 //Stage1系数提交版本
	wire [7:0]stage2_coef_epoch_o;          //Stage2校准字段提交版本
	wire [7:0]dc_recovery_coef_epoch_o;     //DC恢复字段提交版本
	wire [1:0]lifecycle_state_o;            //manager生命周期状态编码
	wire start_ready_o;                     //所有START资格同时满足标志
	wire run_enable_o;                      //RUN阶段数据处理许可
	wire allow_new_transaction_o;           //采样调度新事务许可
	wire [7:0]run_generation_o;             //manager唯一产生的代际内部输出
	wire stop_episode_active_o;             //manager唯一产生的排空episode内部输出
	wire commit_ack_event_o;                //合法COMMIT确认脉冲
	wire start_ack_event_o;                 //合法START接受脉冲
	wire stop_ack_event_o;                  //STOP处理完成脉冲
	wire error_event_o;                     //控制协议拒绝脉冲
	wire commit_ack_sticky_o;               //已成功提交配置历史标志
	wire error_sticky_o;                    //控制面错误历史标志
	wire [7:0]last_error_code_o;            //最近拒绝原因编码

	//ACTIVE字段解包输出缓存
	wire [7:0]schema_version_o;             //ACTIVE快照格式版本字段
	wire run_profile_o;                     //NORMAL与CHARACTERIZATION选择字段
	wire input_source_o;                    //光学输入来源选择字段
	wire [1:0]idac_mode_o;                  //IDAC运行策略字段
	wire [1:0]optical_mode_o;               //红光红外子帧模式字段
	wire initial_precision_o;               //首笔SAR精度选择字段
	wire amb_enable_o;                      //AMB搜索参与字段
	wire dcs_enable_o;                      //红光红外DC码闭环的授权字段
	wire amb_polarity_o;                    //AMB码调整方向字段
	wire dcs_polarity_o;                    //DC搜索向目标区间移动的方向字段
	wire stage1_calibration_valid_o;        //Stage1参数合法字段
	wire stage2_calibration_valid_o;        //精细重构增益与偏置可使用字段
	wire dc9_recovery_valid_o;              //SAR9恢复参数合法字段
	wire dc15_recovery_valid_o;             //15-bit DC恢复算术路径授权字段
	wire [7:0]amb_manual_code_o;            //AMB固定起始码字段
	wire [7:0]amb_code_min_o;               //AMB候选下界字段
	wire [7:0]amb_code_max_o;               //AMB候选上界字段
	wire [7:0]dcs_r_manual_code_o;          //红光子帧DC闭环的初始码字段
	wire [7:0]dcs_r_code_min_o;             //RED DC搜索下限字段
	wire [7:0]dcs_r_code_max_o;             //RED DC搜索上限字段
	wire [7:0]dcs_ir_manual_code_o;         //红外子帧DC闭环的初始码字段
	wire [7:0]dcs_ir_code_min_o;            //红外DC候选空间的最小边界字段
	wire [7:0]dcs_ir_code_max_o;            //红外DC候选空间的最大边界字段
	wire signed [11:0]amb_threshold_low_o;  //AMB低比较门限字段
	wire signed [11:0]amb_threshold_high_o; //AMB高比较门限字段
	wire signed [11:0]dcs_threshold_low_o;  //DC码递增触发的下侧判定字段
	wire signed [11:0]dcs_threshold_high_o; //DC码递减触发的上侧判定字段
	wire [7:0]cnt_amb_confirm_count_o;      //AMB连续收敛样本数量字段
	wire [7:0]cnt_dcs_confirm_count_o;      //DC红光红外共同使用的确认深度字段
	wire signed [25:0]stage1_weight_q16_0_o; //Stage1 FIR最远历史端的Q16系数
	wire signed [25:0]stage1_weight_q16_1_o; //Stage1 FIR最早相邻历史端的Q16系数
	wire signed [25:0]stage1_weight_q16_2_o; //Stage1 FIR第三历史位置的Q16系数
	wire signed [25:0]stage1_weight_q16_3_o; //Stage1 FIR第四历史位置的Q16系数
	wire signed [25:0]stage1_weight_q16_4_o; //Stage1 FIR第五历史位置的Q16系数
	wire signed [25:0]stage1_weight_q16_5_o; //Stage1中心抽头的Q16权重
	wire signed [25:0]stage1_weight_q16_6_o; //Stage1 FIR中心右侧第一位置Q16系数
	wire signed [25:0]stage1_weight_q16_7_o; //Stage1 FIR中心右侧第二位置Q16系数
	wire signed [25:0]stage1_weight_q16_8_o; //Stage1 FIR中心右侧第三位置Q16系数
	wire signed [25:0]stage1_weight_q16_9_o; //Stage1 FIR最新有效样本侧Q16系数
	wire signed [31:0]stage1_offset_q16_o;  //Stage1加性Q16偏置字段
	wire signed [19:0]stage2_gain_q16_o;    //Stage2统一Q16增益字段
	wire signed [31:0]stage2_offset_q16_o;  //精细重构输出修正的Q16偏置字段
	wire signed [31:0]dc9_recovery_gain_q16_o; //SAR9恢复使用的Q16增益字段
	wire signed [31:0]dc15_recovery_gain_q16_o; //15-bit精度DC恢复专用Q16增益字段
	wire [15:0]amb_recheck_interval_frames_o; //NORMAL周期AMB重检间隔字段
	wire slope_mode_o;                      //基线斜率固定或自适应模式字段
	wire signed [31:0]fixed_slope_q16_o;    //固定负斜率signed Q16字段
	wire [15:0]alpha_q15_o;                 //基础斜率幅度比例字段
	wire [15:0]beta_q15_o;                  //活动斜率平滑比例字段
	wire [15:0]timing_adjust_ratio_q15_o;   //相交时刻修正比例字段
	wire signed [31:0]slope_min_q16_o;      //最负斜率边界字段
	wire signed [31:0]slope_max_q16_o;      //最接近零斜率边界字段
	wire signed [31:0]baseline_delta_q16_o; //波峰锚点基线偏置字段
	wire [31:0]cross_hysteresis_q16_o;      //向上相交迟滞量字段
	wire [15:0]lead_min_frames_o;           //相交提前量合格下界字段
	wire [15:0]lead_max_frames_o;           //相交提前量合格上界字段
	wire [3:0]cross_confirm_pts_o;          //相交连续确认点数字段
	wire [3:0]no_cross_limit_o;             //连续无相交重新获取阈值字段
	wire [3:0]peak_confirm_pts_o;           //波峰连续下降确认点数字段
	wire [3:0]valley_confirm_pts_o;         //波谷连续上升确认点数字段
	wire [23:0]direction_deadband_o;        //相邻FIR方向分类死区字段
	wire [23:0]min_peak_valley_amplitude_o; //合格峰谷最小幅度字段
	wire [15:0]min_peak_to_valley_frames_o; //波峰到波谷最小帧差字段
	wire [15:0]min_peak_to_peak_frames_o;   //相邻波峰最小帧差字段
	wire [15:0]max_fine_window_frames_o;    //15-bit窗口最大持续帧数字段
	wire [15:0]max_reacquire_frames_o;      //9-bit重新获取最大帧数字段
	wire peak_valley_config_valid_o;        //正式peak/valley/cross/fine-window资格位字段

	//-------------输出信号连线-------------//
	//顶层输出桥接
	assign o_config_transport_busy = config_transport_busy_o; //向source侧公开CDC占用状态
	assign o_config_transport_update = config_transport_update_o; //向系统侧公开CDC快照到达脉冲
	assign o_active_config = active_config_o; //发布唯一manager拥有的ACTIVE总线
	assign o_active_valid = active_valid_o; //发布ACTIVE对START的资格结论
	assign o_config_epoch = config_epoch_o; //发布完整配置的当前版本号
	assign o_coef_epoch = coef_epoch_o;     //发布Stage1系数版本号
	assign o_stage2_coef_epoch = stage2_coef_epoch_o; //发布Stage2参数版本号
	assign o_dc_recovery_coef_epoch = dc_recovery_coef_epoch_o; //发布DC恢复参数版本号
	assign o_lifecycle_state = lifecycle_state_o; //发布CONFIG到STOPPING状态机编码
	assign o_start_ready = start_ready_o;   //发布所有启动前置条件汇总
	assign o_run_enable = run_enable_o;     //发布RUN执行许可
	assign o_allow_new_transaction = allow_new_transaction_o; //发布ADC新事务准入许可
	assign o_run_generation = run_generation_o; //透明转发manager唯一产生的代际
	assign o_stop_episode_active = stop_episode_active_o; //透明转发manager唯一产生的排空episode电平
	assign o_commit_ack_event = commit_ack_event_o; //发布本次合法COMMIT完成脉冲
	assign o_start_ack_event = start_ack_event_o; //发布本次START接受脉冲
	assign o_stop_ack_event = stop_ack_event_o; //发布本次STOP应答脉冲
	assign o_error_event = error_event_o;   //发布协议拒绝的瞬态通知
	assign o_commit_ack_sticky = commit_ack_sticky_o; //发布至少一次提交成功记录
	assign o_error_sticky = error_sticky_o; //发布控制面故障保持记录
	assign o_last_error_code = last_error_code_o; //发布最后一笔拒绝分类
	assign o_schema_version = schema_version_o; //导出ACTIVE格式版本字段
	assign o_run_profile = run_profile_o;   //导出NORMAL或表征运行档位
	assign o_input_source = input_source_o; //导出光电或测试信号来源
	assign o_idac_mode = idac_mode_o;       //导出IDAC控制策略选择
	assign o_optical_mode = optical_mode_o; //导出RED与IR使能组合
	assign o_initial_precision = initial_precision_o; //导出启动时SAR精度选择
	assign o_amb_enable = amb_enable_o;     //导出AMB调码是否参与
	assign o_dcs_enable = dcs_enable_o;     //导出红外红光DC调码是否参与
	assign o_amb_polarity = amb_polarity_o; //导出AMB搜索码方向
	assign o_dcs_polarity = dcs_polarity_o; //导出红光红外DC闭环所采用的码步进方向
	assign o_stage1_calibration_valid = stage1_calibration_valid_o; //导出Stage1表征结果有效性
	assign o_stage2_calibration_valid = stage2_calibration_valid_o; //导出精细重构参数可安全采用的结论
	assign o_dc9_recovery_valid = dc9_recovery_valid_o; //导出SAR9恢复参数适用性
	assign o_dc15_recovery_valid = dc15_recovery_valid_o; //导出15-bit通道恢复参数的适用性
	assign o_amb_manual_code = amb_manual_code_o; //导出AMB手动初始数字码
	assign o_amb_code_min = amb_code_min_o; //导出AMB搜索允许下界
	assign o_amb_code_max = amb_code_max_o; //导出AMB搜索允许上界
	assign o_dcs_r_manual_code = dcs_r_manual_code_o; //导出红光DC手动初始数字码
	assign o_dcs_r_code_min = dcs_r_code_min_o; //导出红光DC搜索允许下界
	assign o_dcs_r_code_max = dcs_r_code_max_o; //导出红光DC搜索允许上界
	assign o_dcs_ir_manual_code = dcs_ir_manual_code_o; //导出红外DC手动初始数字码
	assign o_dcs_ir_code_min = dcs_ir_code_min_o; //导出红外DC搜索允许下界
	assign o_dcs_ir_code_max = dcs_ir_code_max_o; //导出红外DC搜索允许上界
	assign o_amb_threshold_low = amb_threshold_low_o; //导出AMB比较的低门限
	assign o_amb_threshold_high = amb_threshold_high_o; //导出AMB比较的高门限
	assign o_dcs_threshold_low = dcs_threshold_low_o; //导出推动DC码递增的下侧判定边界
	assign o_dcs_threshold_high = dcs_threshold_high_o; //导出推动DC码递减的上侧判定边界
	assign o_amb_confirm_count = cnt_amb_confirm_count_o; //导出AMB连续确认计数要求
	assign o_dcs_confirm_count = cnt_dcs_confirm_count_o; //导出红光红外DC共同收敛的计数要求
	assign o_stage1_weight_q16_0 = stage1_weight_q16_0_o; //导出最早侧Stage1滤波权重
	assign o_stage1_weight_q16_1 = stage1_weight_q16_1_o; //导出第二个Stage1滤波权重
	assign o_stage1_weight_q16_2 = stage1_weight_q16_2_o; //导出第三个Stage1滤波权重
	assign o_stage1_weight_q16_3 = stage1_weight_q16_3_o; //导出第四个Stage1滤波权重
	assign o_stage1_weight_q16_4 = stage1_weight_q16_4_o; //导出第五个Stage1滤波权重
	assign o_stage1_weight_q16_5 = stage1_weight_q16_5_o; //导出中心Stage1滤波权重
	assign o_stage1_weight_q16_6 = stage1_weight_q16_6_o; //导出第七个Stage1滤波权重
	assign o_stage1_weight_q16_7 = stage1_weight_q16_7_o; //导出第八个Stage1滤波权重
	assign o_stage1_weight_q16_8 = stage1_weight_q16_8_o; //导出第九个Stage1滤波权重
	assign o_stage1_weight_q16_9 = stage1_weight_q16_9_o; //导出最新侧Stage1滤波权重
	assign o_stage1_offset_q16 = stage1_offset_q16_o; //导出Stage1加性偏置
	assign o_stage2_gain_q16 = stage2_gain_q16_o; //导出Stage2统一增益
	assign o_stage2_offset_q16 = stage2_offset_q16_o; //导出精细重构输出修正偏置
	assign o_dc9_recovery_gain_q16 = dc9_recovery_gain_q16_o; //导出SAR9恢复增益
	assign o_dc15_recovery_gain_q16 = dc15_recovery_gain_q16_o; //导出15-bit专属的DC恢复增益
	assign o_amb_recheck_interval_frames = amb_recheck_interval_frames_o; //导出NORMAL重检间隔帧数
	assign o_slope_mode = slope_mode_o;     //导出基线斜率固定或自适应模式
	assign o_fixed_slope_q16 = fixed_slope_q16_o; //导出固定负斜率的signed Q16值
	assign o_alpha_q15 = 16'h0000;       //导出基础斜率幅度比例
	assign o_beta_q15 = beta_q15_o;         //导出活动斜率平滑比例
	assign o_timing_adjust_ratio_q15 = timing_adjust_ratio_q15_o; //导出相交时刻修正比例
	assign o_slope_min_q16 = slope_min_q16_o; //导出最负斜率边界
	assign o_slope_max_q16 = slope_max_q16_o; //导出最接近零斜率边界
	assign o_baseline_delta_q16 = baseline_delta_q16_o; //导出波峰锚点基线偏置
	assign o_cross_hysteresis_q16 = cross_hysteresis_q16_o; //导出向上相交迟滞量
	assign o_lead_min_frames = lead_min_frames_o; //导出相交提前量合格下界
	assign o_lead_max_frames = lead_max_frames_o; //导出相交提前量合格上界
	assign o_cross_confirm_count = cross_confirm_pts_o; //导出相交连续确认点数
	assign o_no_cross_limit = no_cross_limit_o; //导出连续无相交重新获取阈值
	assign o_peak_confirm_count = peak_confirm_pts_o; //导出波峰连续下降确认点数
	assign o_valley_confirm_count = valley_confirm_pts_o; //导出波谷连续上升确认点数
	assign o_direction_deadband = direction_deadband_o; //导出相邻FIR方向分类死区
	assign o_min_peak_valley_amplitude = min_peak_valley_amplitude_o; //导出合格峰谷最小幅度
	assign o_min_peak_to_valley_frames = min_peak_to_valley_frames_o; //导出波峰到波谷最小帧差
	assign o_min_peak_to_peak_frames = min_peak_to_peak_frames_o; //导出相邻波峰最小帧差
	assign o_max_fine_window_frames = max_fine_window_frames_o; //导出15-bit窗口最大持续帧数
	assign o_max_reacquire_frames = max_reacquire_frames_o; //导出9-bit重新获取最大帧数
	assign o_peak_valley_config_valid = peak_valley_config_valid_o; //导出正式peak/valley/cross/fine-window资格位；V4控制平面段直通,链路第二跳 @satisfies: G-FP-01-D01-04

	//------------模块实例化区域------------//
	//配置CDC桥将source shadow快照作为一个原子1024-bit事务搬运至控制域。
	ppg_config_cdc_bridge #(.C_CONFIG_WIDTH(1024))config_cdc_bridge_Inst( //固定1024-bit V4+V5联合快照宽度的CDC实例
		.i_source_clk(i_source_clk),        //驱动source侧握手的配置时钟
		.i_source_rstn(i_source_rstn),      //清除source侧CDC状态的复位
		.i_source_config(i_source_config_snapshot), //待传输的完整shadow快照
		.i_source_update(i_source_config_update_event), //锁定并发起本次CDC传输事件
		.o_source_busy(config_transport_busy_o), //返回source端不可重发的占用状态
		.i_destination_clk(i_clk),          //接收配置的2 MHz控制时钟
		.i_destination_rstn(i_rstn),        //清除destination同步器的复位
		.o_destination_config(wire_destination_config), //交付给manager的稳定快照
		.o_destination_update(config_transport_update_o) //标识destination原子更新到达
	);

	//生命周期管理器独占ACTIVE提交、启动停止仲裁与独立epoch计数。
	ppg_system_config_manager config_manager_Inst(
		.i_clk(i_clk),                      //驱动manager状态机的控制时钟
		.i_rstn(i_rstn),                    //复位manager的生命周期寄存器
		.i_config_snapshot(wire_destination_config), //消费CDC完成的V4快照
		.i_config_update_event(config_transport_update_o), //通知一笔新配置可接受
		.i_start_event(i_start_event),      //请求由READY切入RUN
		.i_stop_event(i_stop_event),        //请求停止并等待相关链路排空
		.i_status_clear_event(i_status_clear_event), //清除可清除的诊断sticky
		.i_analog_ready(i_analog_ready),    //确认模拟准备允许启动
		.i_adc_idle(i_adc_idle),            //确认ADC和捕获链已经静止
		.i_datapath_empty(i_datapath_empty), //确认AMI保持数据已消费
		.i_idac_idle(i_idac_idle),          //确认IDAC搜索不存在在途更新
		.i_analog_safe(i_analog_safe),      //确认模拟端返回安全控制点
		.i_system_fault_blocking(i_system_fault_blocking), //透明送入supervisor系统阻断电平
		.i_static_characterization_enable(i_static_characterization_enable), //透明送入STATIC_BIAS资格电平
		.o_active_config(active_config_o),  //保存合法提交后的唯一ACTIVE快照
		.o_active_valid(active_valid_o),    //表示ACTIVE满足本轮运行契约
		.o_config_epoch(config_epoch_o),    //输出全配置版本推进值
		.o_coef_epoch(coef_epoch_o),        //输出Stage1系数版本推进值
		.o_stage2_coef_epoch(stage2_coef_epoch_o), //输出Stage2字段版本推进值
		.o_dc_recovery_coef_epoch(dc_recovery_coef_epoch_o), //输出DC恢复字段版本推进值
		.o_lifecycle_state(lifecycle_state_o), //输出当前CONFIG或运行生命周期
		.o_start_ready(start_ready_o),      //输出START接受前的资格汇总
		.o_run_enable(run_enable_o),        //输出RUN中功能链使能
		.o_allow_new_transaction(allow_new_transaction_o), //输出采样请求准入条件
		.o_run_generation(run_generation_o), //输出manager唯一产生的代际
		.o_stop_episode_active(stop_episode_active_o), //输出manager唯一产生的排空episode电平
		.o_commit_ack_event(commit_ack_event_o), //发出合法COMMIT单周期确认
		.o_start_ack_event(start_ack_event_o), //发出已接受START的单周期确认
		.o_stop_ack_event(stop_ack_event_o), //发出STOP完成或幂等确认
		.o_error_event(error_event_o),      //发出错误拒绝单周期指示
		.o_commit_ack_sticky(commit_ack_sticky_o), //保持曾合法提交的历史状态
		.o_error_sticky(error_sticky_o),    //保持曾发生控制错误的历史状态
		.o_last_error_code(last_error_code_o) //保留最后一次拒绝的错误分类
	);

	//唯一字段解包器把ACTIVE位段解释为命名控制信号，Wrapper不重复解码。
	ppg_system_active_config_unpack active_config_unpack_Inst(
		.i_active_config(active_config_o),  //输入manager拥有的完整ACTIVE快照
		.o_schema_version(schema_version_o), //取出配置格式版本号
		.o_run_profile(run_profile_o),      //取出NORMAL或表征档位
		.o_input_source(input_source_o),    //取出被选择的输入源
		.o_idac_mode(idac_mode_o),          //取出IDAC运行模式
		.o_optical_mode(optical_mode_o),    //取出红光红外工作组合
		.o_initial_precision(initial_precision_o), //取出本轮起始SAR精度
		.o_amb_enable(amb_enable_o),        //取出AMB控制参与开关
		.o_dcs_enable(dcs_enable_o),        //取出红光红外DC闭环授权
		.o_amb_polarity(amb_polarity_o),    //取出AMB候选码极性
		.o_dcs_polarity(dcs_polarity_o),    //取出DC搜索向目标窗口移动的方向
		.o_stage1_calibration_valid(stage1_calibration_valid_o), //取出Stage1校准可用标志
		.o_stage2_calibration_valid(stage2_calibration_valid_o), //取出精细重构参数可用结论
		.o_dc9_recovery_valid(dc9_recovery_valid_o), //取出SAR9恢复可用标志
		.o_dc15_recovery_valid(dc15_recovery_valid_o), //取出15-bit恢复路径可用结论
		.o_amb_manual_code(amb_manual_code_o), //取出AMB固定数字码
		.o_amb_code_min(amb_code_min_o),    //取出AMB搜索最低界限
		.o_amb_code_max(amb_code_max_o),    //取出AMB搜索最高界限
		.o_dcs_r_manual_code(dcs_r_manual_code_o), //取出红光时隙使用的DC初始码
		.o_dcs_r_code_min(dcs_r_code_min_o), //取出RED DC最小候选码
		.o_dcs_r_code_max(dcs_r_code_max_o), //取出RED DC最大候选码
		.o_dcs_ir_manual_code(dcs_ir_manual_code_o), //取出红外时隙使用的DC初始码
		.o_dcs_ir_code_min(dcs_ir_code_min_o), //取出红外DC候选空间最低边界
		.o_dcs_ir_code_max(dcs_ir_code_max_o), //取出红外DC候选空间最高边界
		.o_amb_threshold_low(amb_threshold_low_o), //取出AMB偏低比较阈值
		.o_amb_threshold_high(amb_threshold_high_o), //取出AMB偏高比较阈值
		.o_dcs_threshold_low(dcs_threshold_low_o), //取出促使DC码增加的下侧阈值
		.o_dcs_threshold_high(dcs_threshold_high_o), //取出促使DC码减少的上侧阈值
		.o_amb_confirm_count(cnt_amb_confirm_count_o), //取出AMB收敛确认计数
		.o_dcs_confirm_count(cnt_dcs_confirm_count_o), //取出双颜色DC共同收敛确认深度
		.o_stage1_weight_q16_0(stage1_weight_q16_0_o), //取出最早侧Stage1权重
		.o_stage1_weight_q16_1(stage1_weight_q16_1_o), //取出次早侧Stage1权重
		.o_stage1_weight_q16_2(stage1_weight_q16_2_o), //取出第三位置Stage1权重
		.o_stage1_weight_q16_3(stage1_weight_q16_3_o), //取出第四位置Stage1权重
		.o_stage1_weight_q16_4(stage1_weight_q16_4_o), //取出第五位置Stage1权重
		.o_stage1_weight_q16_5(stage1_weight_q16_5_o), //取出中心位置Stage1权重
		.o_stage1_weight_q16_6(stage1_weight_q16_6_o), //取出第七位置Stage1权重
		.o_stage1_weight_q16_7(stage1_weight_q16_7_o), //取出第八位置Stage1权重
		.o_stage1_weight_q16_8(stage1_weight_q16_8_o), //取出第九位置Stage1权重
		.o_stage1_weight_q16_9(stage1_weight_q16_9_o), //取出最新侧Stage1权重
		.o_stage1_offset_q16(stage1_offset_q16_o), //取出Stage1加性偏置
		.o_stage2_gain_q16(stage2_gain_q16_o), //取出Stage2公共增益
		.o_stage2_offset_q16(stage2_offset_q16_o), //取出精细重构的输出修正偏置
		.o_dc9_recovery_gain_q16(dc9_recovery_gain_q16_o), //取出SAR9 DC恢复增益
		.o_dc15_recovery_gain_q16(dc15_recovery_gain_q16_o), //取出15-bit精度专属DC恢复增益
		.o_amb_recheck_interval_frames(amb_recheck_interval_frames_o), //取出NORMAL重检帧间隔
		.o_slope_mode(slope_mode_o),        //取出基线斜率固定或自适应模式
		.o_fixed_slope_q16(fixed_slope_q16_o), //取出固定负斜率的signed Q16值
		.o_alpha_q15(alpha_q15_o),          //取出基础斜率幅度比例
		.o_beta_q15(beta_q15_o),            //取出活动斜率平滑比例
		.o_timing_adjust_ratio_q15(timing_adjust_ratio_q15_o), //取出相交时刻修正比例
		.o_slope_min_q16(slope_min_q16_o),  //取出最负斜率边界
		.o_slope_max_q16(slope_max_q16_o),  //取出最接近零斜率边界
		.o_baseline_delta_q16(baseline_delta_q16_o), //取出波峰锚点基线偏置
		.o_cross_hysteresis_q16(cross_hysteresis_q16_o), //取出向上相交迟滞量
		.o_lead_min_frames(lead_min_frames_o), //取出相交提前量合格下界
		.o_lead_max_frames(lead_max_frames_o), //取出相交提前量合格上界
		.o_cross_confirm_count(cross_confirm_pts_o), //取出相交连续确认点数
		.o_no_cross_limit(no_cross_limit_o), //取出连续无相交重新获取阈值
		.o_peak_confirm_count(peak_confirm_pts_o), //取出波峰连续下降确认点数
		.o_valley_confirm_count(valley_confirm_pts_o), //取出波谷连续上升确认点数
		.o_direction_deadband(direction_deadband_o), //取出相邻FIR方向分类死区
		.o_min_peak_valley_amplitude(min_peak_valley_amplitude_o), //取出合格峰谷最小幅度
		.o_min_peak_to_valley_frames(min_peak_to_valley_frames_o), //取出波峰到波谷最小帧差
		.o_min_peak_to_peak_frames(min_peak_to_peak_frames_o), //取出相邻波峰最小帧差
		.o_max_fine_window_frames(max_fine_window_frames_o), //取出15-bit窗口最大持续帧数
		.o_max_reacquire_frames(max_reacquire_frames_o), //取出9-bit重新获取最大帧数
		.o_peak_valley_config_valid(peak_valley_config_valid_o) //取出正式peak/valley/cross/fine-window资格位
	);

endmodule
