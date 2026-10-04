`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/08/06
// Design Name:     PPG System ACTIVE Configuration Unpack Testbench
// Module Name:     tb_ppg_system_active_config_unpack
// Description:     Exhaustive bit mapping and signed interpretation verification
// Simulations:     ppg_system_active_config_unpack.v
//
// Referrences:     ppg_system_active_config_unpack_semantic_contract.md
//
// Dependencies:    ppg_system_active_config_unpack.v
//
// Version:         V5.0
// Revision Date:   2026/08/23
// History:
//     Time          Version     Revised by     Contents
// 2026/08/06        V1.0        Erie          Create self-checking testbench.
// 2026/08/07        V2.0        Erie          Cover every ACTIVE V4 field and reserved bit.
// 2026/08/23        V5.0        Erie          Widen the exhaustive bit-mapping check to the full 1024-bit V4+V5 joint payload and add signed-interpretation coverage for the four signed V5 Q16 fields.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年8月6日
// 设计名称:        PPG系统ACTIVE配置解包自检平台
// 模块名称:        tb_ppg_system_active_config_unpack
// 模块说明:        穷举验证全部位映射、保留位隔离和有符号字段解释
// 仿真工程:        ppg_system_active_config_unpack.v
//
// 参考资料:        ppg_system_active_config_unpack_semantic_contract.md
//
// 依赖文件:        ppg_system_active_config_unpack.v
//
// 当前版本:        V5.0
// 修订日期:        2026年8月23日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年8月6日      V1.0        Erie          创建逐bit自检平台
// 2026年8月7日      V2.0        Erie          覆盖ACTIVE V4全部字段与保留位
// 2026年8月23日     V5.0        Erie          穷举位映射扩展到完整1024-bit V4+V5联合载荷，新增四个signed V5 Q16字段的数值解释覆盖

// 穷举确认V4+V5联合ACTIVE快照的唯一解包位图和signed字段数值语义
module tb_ppg_system_active_config_unpack();

	//-------------配置参数区域-------------//
	localparam [1023:0] FUNCTIONAL_MASK =
		{{14{1'b0}}, {370{1'b1}}, {48{1'b0}}, {560{1'b1}}, {9{1'b0}}, {23{1'b1}}}; // 标记V4+V5定义字段并屏蔽三个保留区域

	//---------------计数信号---------------//
	integer cnt_bit_index;                  // 遍历完整1024-bit输入空间的位索引
	integer cnt_error;                      // 累计所有自检失败以保证完整执行

	//--------------寄存器信号--------------//
	reg [1023:0]reg_active_config;          // 驱动任意V4+V5联合ACTIVE配置位图组合

	//---------------译码信号---------------//
	wire [1023:0]dec_config;                // 把全部功能输出按冻结位图重组供逐bit比对

	//---------------其他信号---------------//

	//---------------输出信号---------------//
	// DUT组合输出观察线按冻结字段顺序覆盖系统模式、IDAC和Stage1系数
	wire [7:0]schema_version_o;             // 观察解包后的schema编号
	wire run_profile_o;                     // 观察解包后的运行配置类型
	wire input_source_o;                    // 观察解包后的模拟输入源
	wire [1:0]idac_mode_o;                  // 观察解包后的IDAC策略编码
	wire [1:0]optical_mode_o;               // 观察解包后的光学调度编码
	wire initial_precision_o;               // 观察解包后的初始精度
	wire amb_enable_o;                      // 观察环境光抵消控制资格
	wire dcs_enable_o;                      // 观察颜色直流抵消闭环资格
	wire amb_polarity_o;                    // 观察AMB调码极性
	wire dcs_polarity_o;                    // 观察颜色直流码修正极性
	wire stage1_calibration_valid_o;        // 观察十个物理位权重组的正式资格
	wire stage2_calibration_valid_o;        // 观察精细残差拟合参数是否完成校准
	wire dc9_recovery_valid_o;              // 观察粗路径DC加回参数的资格声明
	wire dc15_recovery_valid_o;             // 观察15-bit结果能否标记为正式恢复数据
	wire [7:0]amb_manual_code_o;            // 观察AMB初始化或手动码
	wire [7:0]amb_code_min_o;               // 观察AMB最小码边界
	wire [7:0]amb_code_max_o;               // 观察AMB最大码边界
	wire [7:0]dcs_r_manual_code_o;          // 观察红光DCS初始化或手动码
	wire [7:0]dcs_r_code_min_o;             // 观察红光DCS最小码边界
	wire [7:0]dcs_r_code_max_o;             // 观察红光DCS最大码边界
	wire [7:0]dcs_ir_manual_code_o;         // 观察红外通道独立直流起始码
	wire [7:0]dcs_ir_code_min_o;            // 观察红外DCS最小码边界
	wire [7:0]dcs_ir_code_max_o;            // 观察红外DCS最大码边界
	wire signed [11:0]amb_threshold_low_o;  // 观察AMB低阈值的signed整数
	wire signed [11:0]amb_threshold_high_o; // 观察AMB高阈值的signed整数
	wire signed [11:0]dcs_threshold_low_o;  // 观察颜色直流负侧迟滞边界
	wire signed [11:0]dcs_threshold_high_o; // 观察颜色直流正侧迟滞边界
	wire [7:0]cnt_amb_confirm_o;            // 观察AMB连续确认长度
	wire [7:0]cnt_dcs_confirm_o;            // 观察颜色直流连续确认长度
	wire signed [25:0]stage1_weight_q16_0_o; // 观察最低物理位的单位贡献校准值
	wire signed [25:0]stage1_weight_q16_1_o; // 观察第二物理位的二倍贡献校准值
	wire signed [25:0]stage1_weight_q16_2_o; // 观察第三物理位的四倍贡献校准值
	wire signed [25:0]stage1_weight_q16_3_o; // 观察冗余8.0支路的独立拟合结果
	wire signed [25:0]stage1_weight_q16_4_o; // 观察主8.0支路的独立拟合结果
	wire signed [25:0]stage1_weight_q16_5_o; // 观察16.0判决级的校准系数
	wire signed [25:0]stage1_weight_q16_6_o; // 观察中高32.0判决级的校准量
	wire signed [25:0]stage1_weight_q16_7_o; // 观察高64.0判决级的增益量
	wire signed [25:0]stage1_weight_q16_8_o; // 观察128.0高位判决校准值
	wire signed [25:0]stage1_weight_q16_9_o; // 观察256.0最高判决校准值
	wire signed [31:0]stage1_offset_q16_o;  // 观察Stage1 Q16整体偏置
	wire signed [19:0]stage2_gain_q16_o;    // 观察Stage2统一Q16增益
	wire signed [31:0]stage2_offset_q16_o;  // 观察Stage2加性Q16截距
	wire signed [31:0]dc9_recovery_gain_q16_o; // 观察粗精度DC码加回使用的Q16比例
	wire signed [31:0]dc15_recovery_gain_q16_o; // 观察精细路径恢复直流量使用的Q16比例
	wire [15:0]amb_recheck_interval_frames_o; // 观察完整NORMAL帧重检间隔
	wire slope_mode_o;                      // 观察基线斜率固定或自适应模式
	wire signed [31:0]fixed_slope_q16_o;    // 观察固定负斜率的signed Q16值
	wire [15:0]alpha_q15_o;                 // 观察基础斜率幅度比例
	wire [15:0]beta_q15_o;                  // 观察活动斜率平滑比例
	wire [15:0]timing_adjust_ratio_q15_o;   // 观察相交时刻修正比例
	wire signed [31:0]slope_min_q16_o;      // 观察最负斜率边界
	wire signed [31:0]slope_max_q16_o;      // 观察最接近零斜率边界
	wire signed [31:0]baseline_delta_q16_o; // 观察波峰锚点基线偏置
	wire [31:0]cross_hysteresis_q16_o;      // 观察向上相交迟滞量
	wire [15:0]lead_min_frames_o;           // 观察相交提前量合格下界
	wire [15:0]lead_max_frames_o;           // 观察相交提前量合格上界
	wire [3:0]cross_confirm_count_o;        // 观察相交连续确认点数
	wire [3:0]no_cross_limit_o;             // 观察连续无相交重新获取阈值
	wire [3:0]peak_confirm_count_o;         // 观察波峰连续下降确认点数
	wire [3:0]valley_confirm_count_o;       // 观察波谷连续上升确认点数
	wire [23:0]direction_deadband_o;        // 观察相邻FIR方向分类死区
	wire [23:0]min_peak_valley_amplitude_o; // 观察合格峰谷最小幅度
	wire [15:0]min_peak_to_valley_frames_o; // 观察波峰到波谷最小帧差
	wire [15:0]min_peak_to_peak_frames_o;   // 观察相邻波峰最小帧差
	wire [15:0]max_fine_window_frames_o;    // 观察15-bit窗口最大持续帧数
	wire [15:0]max_reacquire_frames_o;      // 观察9-bit重新获取最大帧数
	wire peak_valley_config_valid_o;        // 观察正式peak/valley/cross/fine-window资格位

	//-------------其他信号连线-------------//
	assign dec_config = {
		14'd0,
		peak_valley_config_valid_o,
		max_reacquire_frames_o,
		max_fine_window_frames_o,
		min_peak_to_peak_frames_o,
		min_peak_to_valley_frames_o,
		min_peak_valley_amplitude_o,
		direction_deadband_o,
		valley_confirm_count_o,
		peak_confirm_count_o,
		no_cross_limit_o,
		cross_confirm_count_o,
		lead_max_frames_o,
		lead_min_frames_o,
		cross_hysteresis_q16_o,
		baseline_delta_q16_o,
		slope_max_q16_o,
		slope_min_q16_o,
		timing_adjust_ratio_q15_o,
		beta_q15_o,
		alpha_q15_o,
		fixed_slope_q16_o,
		slope_mode_o,
		48'd0,
		amb_recheck_interval_frames_o,
		dc15_recovery_gain_q16_o,
		dc9_recovery_gain_q16_o,
		stage2_offset_q16_o,
		stage2_gain_q16_o,
		stage1_offset_q16_o,
		stage1_weight_q16_9_o,
		stage1_weight_q16_8_o,
		stage1_weight_q16_7_o,
		stage1_weight_q16_6_o,
		stage1_weight_q16_5_o,
		stage1_weight_q16_4_o,
		stage1_weight_q16_3_o,
		stage1_weight_q16_2_o,
		stage1_weight_q16_1_o,
		stage1_weight_q16_0_o,
		cnt_dcs_confirm_o,
		cnt_amb_confirm_o,
		dcs_threshold_high_o,
		dcs_threshold_low_o,
		amb_threshold_high_o,
		amb_threshold_low_o,
		dcs_ir_code_max_o,
		dcs_ir_code_min_o,
		dcs_ir_manual_code_o,
		dcs_r_code_max_o,
		dcs_r_code_min_o,
		dcs_r_manual_code_o,
		amb_code_max_o,
		amb_code_min_o,
		amb_manual_code_o,
		9'd0,
		dc15_recovery_valid_o,
		dc9_recovery_valid_o,
		stage2_calibration_valid_o,
		stage1_calibration_valid_o,
		dcs_polarity_o,
		amb_polarity_o,
		dcs_enable_o,
		amb_enable_o,
		initial_precision_o,
		optical_mode_o,
		idac_mode_o,
		input_source_o,
		run_profile_o,
		schema_version_o
	};                                      // 重建时强制保留位为0并保持全部功能字段原位置

	//---------------初始化区域---------------//
	// 完成零值、逐bit、有符号数和动态传播四类自检
	initial begin
		cnt_error = 0;                        // 从无失败记录开始执行完整测试集
		reg_active_config = {1024{1'b0}};     // UNPACK-01驱动全零ACTIVE安全快照
		#1;                                   // 等待纯组合连续赋值完成传播
		if(dec_config !== {1024{1'b0}})begin
			cnt_error = cnt_error + 1;        // 记录全零快照未保持安全值
			$display("FAIL UNPACK-01 zero mapping"); // 报告复位安全值映射异常
		end

		for(cnt_bit_index = 0; cnt_bit_index < 1024; cnt_bit_index = cnt_bit_index + 1)begin
			reg_active_config = {1024{1'b0}}; // UNPACK-02每轮先清除上一输入位
			reg_active_config[cnt_bit_index] = 1'b1; // 逐一激励全部功能位和保留位
			#1;                               // 等待当前one-hot输入传播到所有输出
			if(dec_config !== (reg_active_config & FUNCTIONAL_MASK))begin
				cnt_error = cnt_error + 1;    // 记录位段错位、重叠或保留位泄漏
				$display("FAIL UNPACK-02 bit=%0d", cnt_bit_index); // 输出首次级别的实际错误位索引
			end
		end

		reg_active_config = {1024{1'b0}};     // UNPACK-03构造明确的signed边界组合
		reg_active_config[115:104] = -12'sd321; // 驱动负AMB低阈值验证补码解释
		reg_active_config[127:116] = 12'sd777; // 驱动正AMB高阈值验证符号保持
		reg_active_config[139:128] = -12'sd1024; // 驱动负DCS低阈值覆盖较大负数
		reg_active_config[151:140] = 12'sd1023; // 驱动正DCS高阈值覆盖正端范围
		reg_active_config[193:168] = -26'sd12345; // 驱动负S1物理位0权重验证signed Q16路径
		reg_active_config[427:402] = 26'sd16777216; // 驱动标称256.0最高Stage1权重编码
		reg_active_config[459:428] = -32'sd262144; // 驱动标称负4.0 Stage1 Q16偏置
		reg_active_config[479:460] = -20'sd12345; // 驱动负Stage2增益验证signed字段不被改写
		reg_active_config[511:480] = 32'sd7654321; // 驱动正Stage2截距验证32-bit补码解释
		reg_active_config[543:512] = -32'sd987654; // 驱动负SAR9恢复系数验证原始bit pattern
		reg_active_config[575:544] = 32'sd1234567; // 驱动正SAR15恢复系数验证扩展字段
		reg_active_config[672:641] = -32'sd65536; // 驱动负V5固定斜率验证signed Q16路径
		reg_active_config[752:721] = -32'sd999999; // 驱动负V5最负斜率边界覆盖较大负数
		reg_active_config[784:753] = -32'sd1; // 驱动负V5最接近零斜率边界
		reg_active_config[816:785] = 32'sd54321; // 驱动正V5基线偏置验证符号保持
		#1;                                   // 等待全部signed字段完成组合传播
		if((amb_threshold_low_o !== -12'sd321) || (amb_threshold_high_o !== 12'sd777) || (dcs_threshold_low_o !== -12'sd1024) || (dcs_threshold_high_o !== 12'sd1023) || (stage1_weight_q16_0_o !== -26'sd12345) || (stage1_weight_q16_9_o !== 26'sd16777216) || (stage1_offset_q16_o !== -32'sd262144) || (stage2_gain_q16_o !== -20'sd12345) || (stage2_offset_q16_o !== 32'sd7654321) || (dc9_recovery_gain_q16_o !== -32'sd987654) || (dc15_recovery_gain_q16_o !== 32'sd1234567) || (fixed_slope_q16_o !== -32'sd65536) || (slope_min_q16_o !== -32'sd999999) || (slope_max_q16_o !== -32'sd1) || (baseline_delta_q16_o !== 32'sd54321))begin
			cnt_error = cnt_error + 1;        // 记录任一signed字段的数值解释失败
			$display("FAIL UNPACK-03 signed interpretation"); // 报告阈值、权重、offset或V5斜率符号异常
		end

		reg_active_config = {8{128'hA5C3_7E19_2468_1357_F0E1_D2C3_B4A5_9687}}; // UNPACK-04驱动跨字段动态图样
		#1;                                   // 等待复杂图样无寄存延迟地传播
		if(dec_config !== (reg_active_config & FUNCTIONAL_MASK))begin
			cnt_error = cnt_error + 1;        // 记录多字段同时变化时的组合映射异常
			$display("FAIL UNPACK-04 composite propagation"); // 报告完整快照动态传播失败
		end

		if(cnt_error == 0)begin
			$display("PASS: ppg_system_active_config_unpack all checks passed"); // 报告全部V4位图和符号测试成功
		end else begin
			$display("FAIL: ppg_system_active_config_unpack errors=%0d", cnt_error); // 汇总完整测试集失败数量
		end
		$finish;                              // 结束无时钟纯组合模块自检
	end

	//-------------模块实例化区域-------------//
	// 将DUT每个具名端口绑定到自检观察信号
	ppg_system_active_config_unpack ppg_system_active_config_unpack_Inst_dut(
		.i_active_config(reg_active_config),  // 送入当前自检ACTIVE快照
		.o_schema_version(schema_version_o),  // 接收快照schema编号
		.o_run_profile(run_profile_o),        // 接收运行配置类型
		.o_input_source(input_source_o),      // 接收模拟输入源选择
		.o_idac_mode(idac_mode_o),            // 接收IDAC控制策略
		.o_optical_mode(optical_mode_o),      // 接收光学通道模式
		.o_initial_precision(initial_precision_o), // 接收初始精度选择
		.o_amb_enable(amb_enable_o),          // 接收AMB控制资格
		.o_dcs_enable(dcs_enable_o),          // 接收颜色直流闭环资格
		.o_amb_polarity(amb_polarity_o),      // 接收AMB调码方向
		.o_dcs_polarity(dcs_polarity_o),      // 接收颜色直流码修正方向
		.o_stage1_calibration_valid(stage1_calibration_valid_o), // 接收粗级物理位权重校准声明
		.o_stage2_calibration_valid(stage2_calibration_valid_o), // 接收精细残差拟合参数资格
		.o_dc9_recovery_valid(dc9_recovery_valid_o), // 接收9-bit路径DC加回校准状态
		.o_dc15_recovery_valid(dc15_recovery_valid_o), // 接收15-bit恢复结果正式资格
		.o_amb_manual_code(amb_manual_code_o), // 接收AMB初始化或手动码
		.o_amb_code_min(amb_code_min_o),      // 接收AMB码值下限
		.o_amb_code_max(amb_code_max_o),      // 接收AMB码值上限
		.o_dcs_r_manual_code(dcs_r_manual_code_o), // 接收红光DCS初始化或手动码
		.o_dcs_r_code_min(dcs_r_code_min_o),  // 接收红光DCS码值下限
		.o_dcs_r_code_max(dcs_r_code_max_o),  // 接收红光DCS码值上限
		.o_dcs_ir_manual_code(dcs_ir_manual_code_o), // 接收红外通道独立直流起始码
		.o_dcs_ir_code_min(dcs_ir_code_min_o), // 接收红外DCS码值下限
		.o_dcs_ir_code_max(dcs_ir_code_max_o), // 接收红外DCS码值上限
		.o_amb_threshold_low(amb_threshold_low_o), // 接收AMB signed低阈值
		.o_amb_threshold_high(amb_threshold_high_o), // 接收AMB signed高阈值
		.o_dcs_threshold_low(dcs_threshold_low_o), // 接收颜色直流signed低阈值
		.o_dcs_threshold_high(dcs_threshold_high_o), // 接收颜色直流signed高阈值
		.o_amb_confirm_count(cnt_amb_confirm_o), // 接收AMB确认样本数
		.o_dcs_confirm_count(cnt_dcs_confirm_o), // 接收颜色直流确认样本数
		.o_stage1_weight_q16_0(stage1_weight_q16_0_o), // 接收单位贡献物理位拟合权重
		.o_stage1_weight_q16_1(stage1_weight_q16_1_o), // 接收二倍贡献物理位拟合权重
		.o_stage1_weight_q16_2(stage1_weight_q16_2_o), // 接收四倍贡献物理位拟合权重
		.o_stage1_weight_q16_3(stage1_weight_q16_3_o), // 接收冗余8.0判决支路权重
		.o_stage1_weight_q16_4(stage1_weight_q16_4_o), // 接收主8.0判决支路权重
		.o_stage1_weight_q16_5(stage1_weight_q16_5_o), // 接收16.0判决级拟合结果
		.o_stage1_weight_q16_6(stage1_weight_q16_6_o), // 接收中高32.0判决级校准量
		.o_stage1_weight_q16_7(stage1_weight_q16_7_o), // 接收高64.0判决级增益量
		.o_stage1_weight_q16_8(stage1_weight_q16_8_o), // 接收128.0高位校准结果
		.o_stage1_weight_q16_9(stage1_weight_q16_9_o), // 锁定最高物理位256.0贡献的独立拟合系数
		.o_stage1_offset_q16(stage1_offset_q16_o), // 接收Stage1整体Q16偏置
		.o_stage2_gain_q16(stage2_gain_q16_o), // 接收Stage2统一Q16增益
		.o_stage2_offset_q16(stage2_offset_q16_o), // 接收Stage2加性Q16截距
		.o_dc9_recovery_gain_q16(dc9_recovery_gain_q16_o), // 接收粗结果按DC码加回的Q16比例
		.o_dc15_recovery_gain_q16(dc15_recovery_gain_q16_o), // 接收精细结果恢复直流量的Q16比例
		.o_amb_recheck_interval_frames(amb_recheck_interval_frames_o), // 接收AMB周期重检完整帧间隔
		.o_slope_mode(slope_mode_o),          // 接收基线斜率固定或自适应模式
		.o_fixed_slope_q16(fixed_slope_q16_o), // 接收固定负斜率的signed Q16值
		.o_alpha_q15(alpha_q15_o),            // 接收基础斜率幅度比例
		.o_beta_q15(beta_q15_o),              // 接收活动斜率平滑比例
		.o_timing_adjust_ratio_q15(timing_adjust_ratio_q15_o), // 接收相交时刻修正比例
		.o_slope_min_q16(slope_min_q16_o),    // 接收最负斜率边界
		.o_slope_max_q16(slope_max_q16_o),    // 接收最接近零斜率边界
		.o_baseline_delta_q16(baseline_delta_q16_o), // 接收波峰锚点基线偏置
		.o_cross_hysteresis_q16(cross_hysteresis_q16_o), // 接收向上相交迟滞量
		.o_lead_min_frames(lead_min_frames_o), // 接收相交提前量合格下界
		.o_lead_max_frames(lead_max_frames_o), // 接收相交提前量合格上界
		.o_cross_confirm_count(cross_confirm_count_o), // 接收相交连续确认点数
		.o_no_cross_limit(no_cross_limit_o),  // 接收连续无相交重新获取阈值
		.o_peak_confirm_count(peak_confirm_count_o), // 接收波峰连续下降确认点数
		.o_valley_confirm_count(valley_confirm_count_o), // 接收波谷连续上升确认点数
		.o_direction_deadband(direction_deadband_o), // 接收相邻FIR方向分类死区
		.o_min_peak_valley_amplitude(min_peak_valley_amplitude_o), // 接收合格峰谷最小幅度
		.o_min_peak_to_valley_frames(min_peak_to_valley_frames_o), // 接收波峰到波谷最小帧差
		.o_min_peak_to_peak_frames(min_peak_to_peak_frames_o), // 接收相邻波峰最小帧差
		.o_max_fine_window_frames(max_fine_window_frames_o), // 接收15-bit窗口最大持续帧数
		.o_max_reacquire_frames(max_reacquire_frames_o), // 接收9-bit重新获取最大帧数
		.o_peak_valley_config_valid(peak_valley_config_valid_o) // 接收正式peak/valley/cross/fine-window资格位
	);

endmodule
