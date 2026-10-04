`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/08/06
// Design Name:     PPG System ACTIVE Configuration Unpack
// Module Name:     ppg_system_active_config_unpack
// Description:     Description/ppg_system_active_config_unpack_Design.pdf
// Simulations:     tb_ppg_system_active_config_unpack.v
//
// Referrences:     ../ppg_system_integration/PPG_SYSTEM_CONFIG_LIFECYCLE_CONTRACT_DRAFT.md
//
// Dependencies:    None
//
// Version:         V5.0
// Revision Date:   2026/08/23
// History:
//     Time          Version     Revised by     Contents
// 2026/08/06        V1.0        Erie          Create V1 combinational unpack.
// 2026/08/07        V2.0        Erie          Add the complete 640-bit ACTIVE V4 field map.
// 2026/08/23        V5          Erie          Widen the input to the 1024-bit V4+V5 joint payload and add the 20-field V5 detection-config combinational image per ppg_system_active_config_unpack_semantic_contract.md V5.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年8月6日
// 设计名称:        PPG系统ACTIVE配置解包
// 模块名称:        ppg_system_active_config_unpack
// 模块说明:        Description/ppg_system_active_config_unpack_Design.pdf
// 仿真工程:        tb_ppg_system_active_config_unpack.v
//
// 参考资料:        ppg_system_active_config_unpack_semantic_contract.md
//
// 依赖文件:        无
//
// 当前版本:        V5.0
// 修订日期:        2026年8月23日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年8月6日      V1.0        Erie          创建V1纯组合解包模块
// 2026年8月7日      V2.0        Erie          增加完整640-bit ACTIVE V4字段映射
// 2026年8月23日     V5          Erie          输入扩展为1024-bit V4+V5联合载荷，按合同V5新增20个检测配置字段的组合镜像输出

// 将唯一的1024-bit V4+V5联合ACTIVE快照解释为校准、IDAC恢复、系统调度和检测算法使用的稳定具名字段
module ppg_system_active_config_unpack
(
	//---------------用户接口---------------//
	input [1023:0]i_active_config,          // 配置管理器已经原子提交并保持稳定的V4+V5联合ACTIVE快照

	//---------------系统模式输出---------------//
	output [7:0]o_schema_version,               // 输出V4快照格式版本供诊断和只读状态使用
	output o_run_profile,                       // 选择NORMAL_PPG或CHARACTERIZATION运行语义
	output o_input_source,                      // 选择光电二极管或外部测试电流输入路径
	output [1:0]o_idac_mode,                    // 选择手动、搜索保持或搜索跟踪IDAC策略
	output [1:0]o_optical_mode,                 // 选择双光、红光、红外或安全关闭光学调度
	output o_initial_precision,                 // 给出每次RUN启动时的9-bit或15-bit初始精度
	output o_amb_enable,                        // 授权环境光抵消控制参与当前运行
	output o_dcs_enable,                        // 授权红光和红外DCS控制参与当前运行
	output o_amb_polarity,                      // 定义AMB残差偏高时的数字调码方向
	output o_dcs_polarity,                      // 定义颜色直流残差越过上界时的码值修正极性
	output o_stage1_calibration_valid,          // 声明十个Stage1权重和offset为完整片外拟合系数
	output o_stage2_calibration_valid,          // 声明Stage2统一增益和截距为正式拟合系数
	output o_dc9_recovery_valid,                // 声明粗精度DC加回系数已经完成正式表征
	output o_dc15_recovery_valid,               // 声明精细精度DC恢复参数允许用于正式输出

	//---------------IDAC码值输出---------------//
	output [7:0]o_amb_manual_code,              // 输出AMB手动模式或自动模式初始化码
	output [7:0]o_amb_code_min,                 // 限制AMB数字控制允许提交的最小码
	output [7:0]o_amb_code_max,                 // 限制AMB数字控制允许提交的最大码
	output [7:0]o_dcs_r_manual_code,            // 输出红光DCS手动模式或自动模式初始化码
	output [7:0]o_dcs_r_code_min,               // 限制红光DCS数字控制允许提交的最小码
	output [7:0]o_dcs_r_code_max,               // 限制红光DCS数字控制允许提交的最大码
	output [7:0]o_dcs_ir_manual_code,           // 输出红外通道独立的直流抵消起始码
	output [7:0]o_dcs_ir_code_min,              // 限制红外DCS数字控制允许提交的最小码
	output [7:0]o_dcs_ir_code_max,              // 限制红外DCS数字控制允许提交的最大码

	//---------------IDAC判决输出---------------//
	output signed [11:0]o_amb_threshold_low,    // 按signed 12-bit整数输出AMB低阈值
	output signed [11:0]o_amb_threshold_high,   // 按signed 12-bit整数输出AMB高阈值
	output signed [11:0]o_dcs_threshold_low,    // 按signed 12-bit整数输出共用DCS低阈值
	output signed [11:0]o_dcs_threshold_high,   // 按signed 12-bit整数输出共用DCS高阈值
	output [7:0]o_amb_confirm_count,            // 输出AMB连续有效样本确认次数
	output [7:0]o_dcs_confirm_count,            // 输出对应颜色DCS连续有效样本确认次数

	//---------------Stage1系数输出---------------//
	output signed [25:0]o_stage1_weight_q16_0,    // 输出S1最低物理位标称1.0贡献的拟合权重
	output signed [25:0]o_stage1_weight_q16_1,    // 输出S1第二物理位标称2.0贡献的拟合权重
	output signed [25:0]o_stage1_weight_q16_2,    // 输出S1第三物理位标称4.0贡献的拟合权重
	output signed [25:0]o_stage1_weight_q16_3,    // 输出与主8.0位配对的冗余判决位拟合权重
	output signed [25:0]o_stage1_weight_q16_4,    // 输出S1主8.0物理位的独立失配补偿权重
	output signed [25:0]o_stage1_weight_q16_5,    // 输出S1标称16.0物理位的片外拟合结果
	output signed [25:0]o_stage1_weight_q16_6,    // 输出中高32.0判决级的失配校准系数
	output signed [25:0]o_stage1_weight_q16_7,    // 输出高位64.0判决级的增益校准系数
	output signed [25:0]o_stage1_weight_q16_8,    // 输出S1标称128.0高位判决的校准权重
	output signed [25:0]o_stage1_weight_q16_9,    // 输出S1标称256.0最高物理位的校准权重
	output signed [31:0]o_stage1_offset_q16,      // 输出Stage1乘加使用的signed 32-bit Q16偏置

	//---------------Stage2系数输出---------------//
	output signed [19:0]o_stage2_gain_q16,        // 输出Stage2剩余误差拟合使用的统一Q16增益
	output signed [31:0]o_stage2_offset_q16,      // 输出直接加入Stage2残差项的signed Q16截距

	//---------------DC恢复系数输出---------------//
	output signed [31:0]o_dc9_recovery_gain_q16,  // 输出粗精度DC码每LSB对应的统一PPG Q16量
	output signed [31:0]o_dc15_recovery_gain_q16, // 输出精细路径使用的DC输入等效Q16比例

	//---------------系统调度输出---------------//
	output [15:0]o_amb_recheck_interval_frames, // 输出完整NORMAL帧计数的AMB周期重检间隔

	//---------------V5基线斜率输出---------------//
	output o_slope_mode,                          // 输出基线斜率固定或自适应模式选择
	output signed [31:0]o_fixed_slope_q16,        // 输出固定负斜率的signed Q16值
	output [15:0]o_alpha_q15,                     // 输出基础斜率幅度比例
	output [15:0]o_beta_q15,                      // 输出活动斜率平滑比例
	output [15:0]o_timing_adjust_ratio_q15,       // 输出相交时刻修正比例
	output signed [31:0]o_slope_min_q16,          // 输出最负斜率边界
	output signed [31:0]o_slope_max_q16,          // 输出最接近零斜率边界
	output signed [31:0]o_baseline_delta_q16,     // 输出波峰锚点基线偏置
	output [31:0]o_cross_hysteresis_q16,          // 输出向上相交迟滞量

	//---------------V5相交与重获取输出---------------//
	output [15:0]o_lead_min_frames,                   // 输出相交提前量合格下界
	output [15:0]o_lead_max_frames,                   // 输出相交提前量合格上界
	output [3:0]o_cross_confirm_count,                // 输出相交连续确认点数
	output [3:0]o_no_cross_limit,                     // 输出连续无相交重新获取阈值

	//---------------V5峰谷检测输出---------------//
	output [3:0]o_peak_confirm_count,             // 输出波峰连续下降确认点数
	output [3:0]o_valley_confirm_count,           // 输出波谷连续上升确认点数
	output [23:0]o_direction_deadband,            // 输出相邻FIR方向分类死区
	output [23:0]o_min_peak_valley_amplitude,     // 输出合格峰谷最小幅度
	output [15:0]o_min_peak_to_valley_frames,     // 输出波峰到波谷最小帧差
	output [15:0]o_min_peak_to_peak_frames,       // 输出相邻波峰最小帧差

	//---------------V5精度窗口输出---------------//
	output [15:0]o_max_fine_window_frames,        // 输出15-bit窗口最大持续帧数
	output [15:0]o_max_reacquire_frames,          // 输出9-bit重新获取最大帧数
	output o_peak_valley_config_valid             // 输出正式peak/valley/cross/fine-window资格位
);

	//-------------输出信号连线-------------//
	assign o_schema_version = i_active_config[7:0]; // 固定提取快照最低字节的V4 schema编号
	assign o_run_profile = i_active_config[8]; // 固定提取运行配置类型选择位
	assign o_input_source = i_active_config[9]; // 固定提取模拟输入源选择位
	assign o_idac_mode = i_active_config[11:10]; // 固定提取三种IDAC运行策略编码
	assign o_optical_mode = i_active_config[13:12]; // 固定提取R与IR光学通道调度编码
	assign o_initial_precision = i_active_config[14]; // 固定提取RUN初始ADC精度选择位
	assign o_amb_enable = i_active_config[15]; // 固定提取AMB控制资格位
	assign o_dcs_enable = i_active_config[16]; // 授权红光或红外直流抵消闭环运行
	assign o_amb_polarity = i_active_config[17]; // 固定提取AMB码值方向映射位
	assign o_dcs_polarity = i_active_config[18]; // 解包颜色直流码的闭环修正极性
	assign o_stage1_calibration_valid = i_active_config[19]; // 固定提取Stage1拟合系数完整资格位
	assign o_stage2_calibration_valid = i_active_config[20]; // 取得Stage2统一拟合参数的正式资格位
	assign o_dc9_recovery_valid = i_active_config[21]; // 提取粗精度DC加回参数的校准声明
	assign o_dc15_recovery_valid = i_active_config[22]; // 提取精细恢复链正式数据资格
	assign o_amb_manual_code = i_active_config[39:32]; // 固定提取AMB当前初始化或手动目标码
	assign o_amb_code_min = i_active_config[47:40]; // 固定提取AMB搜索区间下界
	assign o_amb_code_max = i_active_config[55:48]; // 固定提取AMB搜索区间上界
	assign o_dcs_r_manual_code = i_active_config[63:56]; // 固定提取红光DCS当前初始化或手动目标码
	assign o_dcs_r_code_min = i_active_config[71:64]; // 固定提取红光DCS搜索区间下界
	assign o_dcs_r_code_max = i_active_config[79:72]; // 固定提取红光DCS搜索区间上界
	assign o_dcs_ir_manual_code = i_active_config[87:80]; // 取得红外通道专用直流抵消目标码
	assign o_dcs_ir_code_min = i_active_config[95:88]; // 固定提取红外DCS搜索区间下界
	assign o_dcs_ir_code_max = i_active_config[103:96]; // 固定提取红外DCS搜索区间上界
	assign o_amb_threshold_low = $signed(i_active_config[115:104]); // 保留AMB低阈值的二进制补码负值语义
	assign o_amb_threshold_high = $signed(i_active_config[127:116]); // 保留AMB高阈值的二进制补码正负语义
	assign o_dcs_threshold_low = $signed(i_active_config[139:128]); // 保留共用DCS低阈值的有符号标度
	assign o_dcs_threshold_high = $signed(i_active_config[151:140]); // 保留共用DCS高阈值的有符号标度
	assign o_amb_confirm_count = i_active_config[159:152]; // 固定提取AMB迟滞窗口连续确认长度
	assign o_dcs_confirm_count = i_active_config[167:160]; // 固定提取当前颜色DCS连续确认长度
	assign o_stage1_weight_q16_0 = $signed(i_active_config[193:168]); // 把最低判决位的单位贡献字段解释为signed Q16
	assign o_stage1_weight_q16_1 = $signed(i_active_config[219:194]); // 把第二判决位的二倍贡献字段解释为signed Q16
	assign o_stage1_weight_q16_2 = $signed(i_active_config[245:220]); // 把第三判决位的四倍贡献字段解释为signed Q16
	assign o_stage1_weight_q16_3 = $signed(i_active_config[271:246]); // 单独保留冗余8.0判决支路的失配校准值
	assign o_stage1_weight_q16_4 = $signed(i_active_config[297:272]); // 单独保留主8.0判决支路的失配校准值
	assign o_stage1_weight_q16_5 = $signed(i_active_config[323:298]); // 传递16.0判决级片外拟合后的有符号系数
	assign o_stage1_weight_q16_6 = $signed(i_active_config[349:324]); // 解释32.0中高位判决级的Q16校准量
	assign o_stage1_weight_q16_7 = $signed(i_active_config[375:350]); // 解释64.0高位判决级的Q16增益量
	assign o_stage1_weight_q16_8 = $signed(i_active_config[401:376]); // 传递128.0高位判决级的有符号校准系数
	assign o_stage1_weight_q16_9 = $signed(i_active_config[427:402]); // 传递可容纳256.0标称值的最高位Q16系数
	assign o_stage1_offset_q16 = $signed(i_active_config[459:428]); // 保留Stage1整体偏置的signed Q16解释
	assign o_stage2_gain_q16 = $signed(i_active_config[479:460]); // 传递Stage2剩余误差拟合的统一增益
	assign o_stage2_offset_q16 = $signed(i_active_config[511:480]); // 保留Stage2加性截距的二进制补码解释
	assign o_dc9_recovery_gain_q16 = $signed(i_active_config[543:512]); // 解释粗结果DC码加回所用signed比例
	assign o_dc15_recovery_gain_q16 = $signed(i_active_config[575:544]); // 解释15-bit结果恢复直流量的signed比例
	assign o_amb_recheck_interval_frames = i_active_config[591:576]; // 传递完整NORMAL帧单位的周期检查间隔
	assign o_slope_mode = i_active_config[640]; // 固定提取基线斜率固定或自适应选择位
	assign o_fixed_slope_q16 = $signed(i_active_config[672:641]); // 保留固定负斜率的二进制补码语义
	assign o_alpha_q15 = i_active_config[688:673]; // 固定提取基础斜率幅度比例
	assign o_beta_q15 = i_active_config[704:689]; // 固定提取活动斜率平滑比例
	assign o_timing_adjust_ratio_q15 = i_active_config[720:705]; // 固定提取相交时刻修正比例
	assign o_slope_min_q16 = $signed(i_active_config[752:721]); // 保留最负斜率边界的二进制补码语义
	assign o_slope_max_q16 = $signed(i_active_config[784:753]); // 保留最接近零斜率边界的二进制补码语义
	assign o_baseline_delta_q16 = $signed(i_active_config[816:785]); // 保留波峰锚点基线偏置的二进制补码语义
	assign o_cross_hysteresis_q16 = i_active_config[848:817]; // 固定提取向上相交迟滞量
	assign o_lead_min_frames = i_active_config[864:849]; // 固定提取相交提前量合格下界
	assign o_lead_max_frames = i_active_config[880:865]; // 固定提取相交提前量合格上界
	assign o_cross_confirm_count = i_active_config[884:881]; // 固定提取相交连续确认点数
	assign o_no_cross_limit = i_active_config[888:885]; // 固定提取连续无相交重新获取阈值
	assign o_peak_confirm_count = i_active_config[892:889]; // 固定提取波峰连续下降确认点数
	assign o_valley_confirm_count = i_active_config[896:893]; // 固定提取波谷连续上升确认点数
	assign o_direction_deadband = i_active_config[920:897]; // 固定提取相邻FIR方向分类死区
	assign o_min_peak_valley_amplitude = i_active_config[944:921]; // 固定提取合格峰谷最小幅度
	assign o_min_peak_to_valley_frames = i_active_config[960:945]; // 固定提取波峰到波谷最小帧差
	assign o_min_peak_to_peak_frames = i_active_config[976:961]; // 固定提取相邻波峰最小帧差
	assign o_max_fine_window_frames = i_active_config[992:977]; // 固定提取15-bit窗口最大持续帧数
	assign o_max_reacquire_frames = i_active_config[1008:993]; // 固定提取9-bit重新获取最大帧数
	assign o_peak_valley_config_valid = i_active_config[1009]; // 固定提取正式peak/valley/cross/fine-window资格位；unpacker->AMI->PWI->C20/C22/C23唯一通路起点 @satisfies: G-FP-01-D01-04

endmodule
