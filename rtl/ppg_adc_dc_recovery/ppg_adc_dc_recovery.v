`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:			Erie
// Engineer:		Erie
//
// Create Date: 	2026/08/07 00:00:00
// Design Name: 	PPG ADC DC Recovery
// Module Name: 	ppg_adc_dc_recovery
// Description: 	Restore color DC cancellation into a common signed 24-bit PPG code.
// Dependencies:	None
// Simulations:		TestBench/Vivado/2021.1/ppg_adc_dc_recovery
//
// Referrences:		None
//
//
// Version:			V1.1
// Revision Date:	2026/08/23 00:00:00
// History:
//    Time			   Version	   Revised by			Contents
// 2026/08/07			V1.0		 Erie		Create file.
// 2026/08/23			V1.1		 Erie		Add the 8 diagnostic passthrough port pairs (detect_code/stage1_raw/stage1_code_ext/stage2_raw/stage2_code_ext/nominal_15_code/nominal_15_valid/nominal_saturated) required by PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md section 11.3; folded into the existing single-buffer atomic payload so they latch/hold/replace on the same edge as every other transaction field.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:		Erie
// 开发人员:		Erie
//
// 创建日期: 		2026年08月07日
// 设计名称: 		PPG ADC DC Recovery
// 模块名称: 		ppg_adc_dc_recovery
// 模块说明:		Restore color DC cancellation into a common signed 24-bit PPG code.
// 依赖文件:		None
// 仿真工程: 		TestBench/Vivado/2021.1/ppg_adc_dc_recovery
//
// 参考资料:		None
//
//
// 当前版本:		V1.1
// 修订日期:		2026年08月23日
// 修订历史:
//	时间			    版本		修订人				修订内容
// 2026年08月07日		V1.0		 Erie		创建文件
// 2026年08月23日		V1.1		 Erie		按合同11.3节新增8组诊断透传端口（detect_code/stage1_raw/stage1_code_ext/stage2_raw/stage2_code_ext/nominal_15_code/nominal_15_valid/nominal_saturated），并入既有单缓存原子载荷，随其余事务字段同拍锁存/保持/替换
module ppg_adc_dc_recovery
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16, // PPG帧标识位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // 样本序号位宽
	parameter integer C_IDAC_CODE_WIDTH = 32'd8, // 颜色DC码位宽
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // IDAC码版本位宽
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // ACTIVE配置版本位宽
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8, // Stage1/Stage2系数版本位宽
	parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 32'd8 // DC恢复系数版本位宽
)
(
	//-----------------全局信号-----------------//
	input i_clk,                                // 数字处理域工作时钟
	input i_rstn,                               // 低有效异步复位

	//--------------ACTIVE配置接口--------------//
	input i_active_valid,                       // ACTIVE快照允许接收NORMAL事务
	input i_dc9_recovery_valid,                 // SAR9 DC恢复系数有效标志
	input i_dc15_recovery_valid,                // 精细链DC恢复参数已完成片外表征
	input signed [31:0]i_dc9_recovery_gain_q16, // SAR9 signed 32-bit Q16恢复系数
	input signed [31:0]i_dc15_recovery_gain_q16, // 精细链每个DC码对应的统一PPG增量
	input [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]i_dc_recovery_coef_epoch, // DC系数版本

	//-------------上游事务输入接口-------------//

	//RESULT接口
	input i_result_valid,                       // 上游完整NORMAL事务有效
	output o_result_ready,                      // 本模块可以接收新事务
	input i_result_ready,                       // 下游允许消费当前事务
	input signed [11:0]i_calibrated_s1_value,   // Stage1正式校准结果
	input i_calibration_applied,                // Stage1正式校准资格
	input i_stage1_saturation_low,              // Stage1负向饱和诊断
	input i_stage1_saturation_high,             // Stage1正向饱和诊断
	input signed [14:0]i_programmable_15_code,  // 15-bit可编程重构结果
	input i_programmable_15_valid,              // 15-bit结果有效
	input i_programmable_15_calibration_applied, // 本笔精细残差同时具备两级合法系数
	input i_programmable_saturation_low,        // 15-bit重构负向饱和诊断
	input i_programmable_saturation_high,       // 15-bit重构正向饱和诊断
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 本笔ACTIVE版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 本笔Stage1系数版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_stage2_coef_epoch, // 精细重构实际采用的第二级提交代号
	input i_precision_mode,                     // 0为9-bit，1为15-bit
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id,   // 帧标识
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 样本序号
	input i_color_ir,                           // 0为红光，1为红外
	input [1:0]i_frame_type,                    // NORMAL事务类别
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // AMB码快照，仅透传
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 本笔颜色DC码快照
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // AMB码版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // DC码版本
	input [8:0]i_detect_code,                   // 固定Stage1黄金检测码，仅供离线对照使用
	input [9:0]i_stage1_raw,                    // Stage1物理判决位诊断值
	input signed [10:0]i_stage1_code_ext,       // 固定公式D1_EXT诊断值
	input [9:0]i_stage2_raw,                    // 第二级冗余物理判决位，供级间增益核对
	input signed [10:0]i_stage2_code_ext,       // 第二级冗余解码诊断值，供增益核对使用
	input signed [14:0]i_nominal_15_code,       // 固定标称15-bit黄金重构结果
	input i_nominal_15_valid,                   // 固定标称结果精度资格
	input i_nominal_saturated,                  // 固定标称结果饱和诊断

	//-------------下游事务输出接口-------------//
	output o_result_valid,                      // 输出事务保持有效
	output signed [23:0]o_coarse_ppg_value,     // 9-bit粗结果统一PPG码
	output o_coarse_valid,                      // 粗结果资格
	output o_coarse_recovery_calibrated,        // 粗结果正式校准资格
	output o_coarse_saturation_low,             // 粗结果负向24-bit饱和
	output o_coarse_saturation_high,            // 粗结果正向24-bit饱和
	output signed [23:0]o_fine_ppg_value,       // 15-bit精细结果统一PPG码
	output o_fine_valid,                        // 精细结果资格
	output o_fine_recovery_calibrated,          // 精细结果正式校准资格
	output o_fine_saturation_low,               // 精细结果负向24-bit饱和
	output o_fine_saturation_high,              // 精细结果正向24-bit饱和
	output [C_DC_RECOVERY_EPOCH_WIDTH - 1:0]o_dc_recovery_coef_epoch, // 实际DC系数版本

	//------------事务元数据输出接口------------//
	output signed [11:0]o_calibrated_s1_value,  // Stage1校准值
	output o_calibration_applied,               // Stage1校准资格
	output o_stage1_saturation_low,             // Stage1负向饱和
	output o_stage1_saturation_high,            // Stage1正向饱和
	output signed [14:0]o_programmable_15_code, // 原始15-bit重构值
	output o_programmable_15_valid,             // 原始15-bit结果资格
	output o_programmable_15_calibration_applied, // 原始15-bit校准资格
	output o_programmable_saturation_low,       // 原始15-bit负向饱和
	output o_programmable_saturation_high,      // 原始15-bit正向饱和
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch, // ACTIVE版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch, // Stage1版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_stage2_coef_epoch, // Stage2版本
	output o_precision_mode,                    // 9-bit或15-bit事务精度快照
	output [C_FRAME_ID_WIDTH - 1:0]o_frame_id,  // 帧标识
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index, // 导出已锁存事务的算法流顺序编号
	output o_color_ir,                          // 颜色身份
	output [1:0]o_frame_type,                   // 保留上游限定后的NORMAL协议类别
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot, // AMB码快照
	output [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot, // DC码快照
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // AMB码版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch, // DC码版本
	output [8:0]o_detect_code,                  // 固定Stage1黄金检测码诊断输出
	output [9:0]o_stage1_raw,                   // Stage1物理判决位诊断输出
	output signed [10:0]o_stage1_code_ext,      // 固定公式D1_EXT诊断输出
	output [9:0]o_stage2_raw,                   // 第二级冗余物理判决位输出
	output signed [10:0]o_stage2_code_ext,      // 第二级冗余解码诊断输出
	output signed [14:0]o_nominal_15_code,      // 固定标称15-bit黄金重构结果输出
	output o_nominal_15_valid,                  // 固定标称结果精度资格输出
	output o_nominal_saturated                  // 固定标称结果饱和诊断输出
);

	//---------------配置参数区域---------------//
	localparam signed [22:0]A1_FIXED_Q16 = 23'sd3533837; // Stage1统一标度固定Q16比例
	localparam signed [42:0]ROUND_HALF_Q17 = 43'sd65536; // Q17半LSB舍入量
	localparam signed [42:0]PPG_CODE_MAX = 43'sd8388607; // signed 24-bit正端点
	localparam signed [42:0]PPG_CODE_MIN = -43'sd8388608; // signed 24-bit负端点

	// 事务载荷字段的LSB位置，保证反压时结果与元数据同拍保持。
	localparam integer DC_EPOCH_LSB = 32'd0;    // DC码版本占据载荷最低字段
	localparam integer AMB_EPOCH_LSB = DC_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // AMB版本紧邻DC版本保存
	localparam integer DC_CODE_LSB = AMB_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // 颜色DC快照位于版本字段之上
	localparam integer AMB_CODE_LSB = DC_CODE_LSB + C_IDAC_CODE_WIDTH; // AMB快照只作为诊断字段透传
	localparam integer FRAME_TYPE_LSB = AMB_CODE_LSB + C_IDAC_CODE_WIDTH; // NORMAL类别保留两位协议字段
	localparam integer COLOR_LSB = FRAME_TYPE_LSB + 32'd2; // 红光红外身份位跟随事务类别
	localparam integer SAMPLE_INDEX_LSB = COLOR_LSB + 32'd1; // 样本序号位于颜色身份上方
	localparam integer FRAME_ID_LSB = SAMPLE_INDEX_LSB + C_SAMPLE_INDEX_WIDTH; // PPG帧号保持R和IR配对
	localparam integer PRECISION_LSB = FRAME_ID_LSB + C_FRAME_ID_WIDTH; // 精度模式位于公共身份字段之上
	localparam integer PROGRAMMABLE_SAT_HIGH_LSB = PRECISION_LSB + 32'd1; // 保存15-bit正向饱和诊断
	localparam integer PROGRAMMABLE_SAT_LOW_LSB = PROGRAMMABLE_SAT_HIGH_LSB + 32'd1; // 保存15-bit负向饱和诊断
	localparam integer PROGRAMMABLE_CAL_LSB = PROGRAMMABLE_SAT_LOW_LSB + 32'd1; // 保存两级正式校准资格
	localparam integer PROGRAMMABLE_VALID_LSB = PROGRAMMABLE_CAL_LSB + 32'd1; // 保存15-bit数值有效资格
	localparam integer PROGRAMMABLE_CODE_LSB = PROGRAMMABLE_VALID_LSB + 32'd1; // 保存原始15-bit重构残差
	localparam integer STAGE1_SAT_HIGH_LSB = PROGRAMMABLE_CODE_LSB + 32'd15; // 标记逐位校准曾触及正端点
	localparam integer STAGE1_SAT_LOW_LSB = STAGE1_SAT_HIGH_LSB + 32'd1; // 标记逐位校准曾触及负端点
	localparam integer STAGE1_CAL_LSB = STAGE1_SAT_LOW_LSB + 32'd1; // 保存Stage1正式系数资格
	localparam integer STAGE1_VALUE_LSB = STAGE1_CAL_LSB + 32'd1; // 保存signed 12-bit Stage1结果
	localparam integer STAGE2_EPOCH_LSB = STAGE1_VALUE_LSB + 32'd12; // 保存参与精细重构的Stage2版本
	localparam integer COEF_EPOCH_LSB = STAGE2_EPOCH_LSB + C_COEF_EPOCH_WIDTH; // 保存Stage1逐位系数版本
	localparam integer CONFIG_EPOCH_LSB = COEF_EPOCH_LSB + C_COEF_EPOCH_WIDTH; // 保存整套ACTIVE配置版本
	localparam integer DC_RECOVERY_EPOCH_LSB = CONFIG_EPOCH_LSB + C_CONFIG_EPOCH_WIDTH; // 保存DC恢复系数组版本
	localparam integer COARSE_SAT_HIGH_LSB = DC_RECOVERY_EPOCH_LSB + C_DC_RECOVERY_EPOCH_WIDTH; // 保存粗结果正向饱和
	localparam integer COARSE_SAT_LOW_LSB = COARSE_SAT_HIGH_LSB + 32'd1; // 保存粗结果负向饱和
	localparam integer COARSE_CAL_LSB = COARSE_SAT_LOW_LSB + 32'd1; // 保存粗路径恢复校准资格
	localparam integer COARSE_VALID_LSB = COARSE_CAL_LSB + 32'd1; // 保存粗结果数值有效资格
	localparam integer COARSE_VALUE_LSB = COARSE_VALID_LSB + 32'd1; // 保存signed 24-bit粗结果
	localparam integer FINE_SAT_HIGH_LSB = COARSE_VALUE_LSB + 32'd24; // 保存精细结果正向饱和
	localparam integer FINE_SAT_LOW_LSB = FINE_SAT_HIGH_LSB + 32'd1; // 保存精细结果负向饱和
	localparam integer FINE_CAL_LSB = FINE_SAT_LOW_LSB + 32'd1; // 保存精细恢复校准资格
	localparam integer FINE_VALID_LSB = FINE_CAL_LSB + 32'd1; // 保存精细结果数值资格
	localparam integer FINE_VALUE_LSB = FINE_VALID_LSB + 32'd1; // 保存signed 24-bit精细结果
	localparam integer NOMINAL_SATURATED_LSB = FINE_VALUE_LSB + 32'd24; // 保存固定标称结果饱和诊断
	localparam integer NOMINAL_VALID_LSB = NOMINAL_SATURATED_LSB + 32'd1; // 保存固定标称结果精度资格
	localparam integer NOMINAL_CODE_LSB = NOMINAL_VALID_LSB + 32'd1; // 保存固定标称15-bit黄金重构结果
	localparam integer STAGE2_CODE_EXT_LSB = NOMINAL_CODE_LSB + 32'd15; // 保存第二级冗余解码诊断值
	localparam integer STAGE2_RAW_LSB = STAGE2_CODE_EXT_LSB + 32'd11; // 保存第二级冗余物理判决位
	localparam integer STAGE1_CODE_EXT_LSB = STAGE2_RAW_LSB + 32'd10; // 保存固定公式D1_EXT诊断值
	localparam integer STAGE1_RAW_LSB = STAGE1_CODE_EXT_LSB + 32'd11; // 保存Stage1物理判决位诊断值
	localparam integer DETECT_CODE_LSB = STAGE1_RAW_LSB + 32'd10; // 保存固定Stage1黄金检测码
	localparam integer PAYLOAD_WIDTH = DETECT_CODE_LSB + 32'd9; // 汇总完整原子事务载荷位宽

	//-----------------标志信号-----------------//
	wire flag_buffer_available;                 // 输出缓存可写条件
	wire flag_input_transfer;                   // 上游事务接收事件
	wire flag_output_transfer;                  // 下游事务消费事件
	wire flag_coarse_negative;                  // 粗路径累加结果符号
	wire flag_fine_negative;                    // 精细路径累加结果符号
	wire flag_coarse_overflow_low;              // 粗路径负向溢出
	wire flag_coarse_overflow_high;             // 粗路径正向溢出
	wire flag_fine_overflow_low;                // 精细路径负向溢出
	wire flag_fine_overflow_high;               // 精细路径正向溢出

	//-----------------译码信号-----------------//
	wire signed [13:0]dec_s1_ext;               // Stage1符号扩展值
	wire signed [13:0]dec_s1_center_x2;         // Stage1中心化并加入半粗码补偿
	wire signed [36:0]dec_s1_operand;           // Stage1乘法显式扩展操作数
	wire signed [36:0]dec_a1_operand;           // 固定比例显式扩展操作数
	wire signed [36:0]dec_s1_product_q16;       // Stage1 Q16乘积
	wire signed [40:0]dec_dc9_code_ext;         // DC码无符号转signed扩展
	wire signed [40:0]dec_dc15_code_ext;        // 精细路径复制无符号DC快照后扩展
	wire signed [40:0]dec_dc9_gain_ext;         // DC9系数扩展操作数
	wire signed [40:0]dec_dc15_gain_ext;        // 精细恢复系数扩展到乘法器宽度
	wire signed [40:0]dec_dc9_product_q16;      // DC9 Q16乘积
	wire signed [40:0]dec_dc15_product_q16;     // DC15 Q16乘积
	wire signed [41:0]dec_dc9_term_q17;         // DC9乘积移入Q17
	wire signed [41:0]dec_dc15_term_q17;        // 精细DC贡献提升到公共Q17标度
	wire signed [41:0]dec_s1_product_q17_ext;   // Stage1乘积扩展到42位
	wire signed [41:0]dec_coarse_acc_q17;       // 粗路径Q17累加器
	wire signed [41:0]dec_fine_base_q17;        // 精细结果左移到Q17
	wire signed [41:0]dec_fine_acc_q17;         // 精细路径Q17累加器
	wire signed [42:0]dec_coarse_acc_ext;       // 粗路径保护位
	wire signed [42:0]dec_fine_acc_ext;         // 精细路径保护位
	wire [42:0]dec_coarse_magnitude;            // 粗路径绝对值
	wire [42:0]dec_fine_magnitude;              // 精细路径绝对值
	wire [42:0]dec_coarse_rounded_magnitude;    // 粗路径舍入幅值
	wire [42:0]dec_fine_rounded_magnitude;      // 精细路径舍入幅值
	wire signed [42:0]dec_coarse_rounded_code;  // 粗路径舍入结果
	wire signed [42:0]dec_fine_rounded_code;    // 精细路径舍入结果
	wire signed [23:0]dec_coarse_value;         // 粗路径饱和输出
	wire signed [23:0]dec_fine_value;           // 精细路径饱和输出
	wire [PAYLOAD_WIDTH - 1:0]dec_payload_input; // 原子事务载荷

	//-----------------其他信号-----------------//

	//-----------------输出信号-----------------//
	//下游事务输出接口
	reg result_valid_o;                         // 输出事务有效寄存器
	reg [PAYLOAD_WIDTH - 1:0]payload_o;         // 输出事务缓存

	//---------------其他信号连线---------------//
	//RESULT接口
	assign flag_buffer_available = (result_valid_o == 1'b0) || i_result_ready; // 缓存为空或本拍消费
	assign flag_input_transfer = i_result_valid && o_result_ready; // 上游握手
	assign flag_output_transfer = result_valid_o && i_result_ready; // 下游握手
	assign dec_s1_ext = {{2{i_calibrated_s1_value[11]}}, i_calibrated_s1_value}; // Stage1显式符号扩展，完整12-bit参与粗恢复运算，不截断为9-bit @satisfies: ADCN-09
	assign dec_s1_center_x2 = (dec_s1_ext <<< 1) - 14'sd511; // 实现粗量化区间中心估计
	assign dec_s1_operand = {{23{dec_s1_center_x2[13]}}, dec_s1_center_x2}; // 对齐37位乘法

	//其他信号连线
	assign dec_a1_operand = {{14{A1_FIXED_Q16[22]}}, A1_FIXED_Q16}; // 对齐37位固定比例

	//RESULT接口
	assign dec_s1_product_q16 = dec_s1_operand * dec_a1_operand; // 得到Q16乘积
	assign dec_dc9_code_ext = {{(32'd41 - C_IDAC_CODE_WIDTH - 32'd1){1'b0}}, 1'b0, i_dc_code_snapshot}; // DC码按无符号扩展
	assign dec_dc15_code_ext = {{(32'd41 - C_IDAC_CODE_WIDTH - 32'd1){1'b0}}, 1'b0, i_dc_code_snapshot}; // 精细通路保持DC码无符号数值
	assign dec_dc9_gain_ext = {{9{i_dc9_recovery_gain_q16[31]}}, i_dc9_recovery_gain_q16}; // DC9系数扩展
	assign dec_dc15_gain_ext = {{9{i_dc15_recovery_gain_q16[31]}}, i_dc15_recovery_gain_q16}; // 精细系数保持补码符号参与乘法

	//其他信号连线
	assign dec_dc9_product_q16 = dec_dc9_code_ext * dec_dc9_gain_ext; // DC9等效恢复量
	assign dec_dc15_product_q16 = dec_dc15_code_ext * dec_dc15_gain_ext; // 计算15-bit链专用DC等效贡献
	assign dec_dc9_term_q17 = dec_dc9_product_q16 <<< 1; // 粗恢复项由Q16精确转到Q17
	assign dec_dc15_term_q17 = dec_dc15_product_q16 <<< 1; // 精细恢复项由Q16精确转到Q17

	//RESULT接口
	assign dec_s1_product_q17_ext = {{5{dec_s1_product_q16[36]}}, dec_s1_product_q16}; // Stage1乘积扩展
	assign dec_coarse_acc_q17 = dec_s1_product_q17_ext + dec_dc9_term_q17; // 粗路径完整Q17累加
	assign dec_fine_base_q17 = {{10{i_programmable_15_code[14]}}, i_programmable_15_code, 17'b0}; // 精细结果转Q17
	assign dec_fine_acc_q17 = dec_fine_base_q17 + dec_dc15_term_q17; // 精细路径完整Q17累加
	assign dec_coarse_acc_ext = {dec_coarse_acc_q17[41], dec_coarse_acc_q17}; // 粗路径增加保护位
	assign dec_fine_acc_ext = {dec_fine_acc_q17[41], dec_fine_acc_q17}; // 精细路径增加保护位
	assign flag_coarse_negative = dec_coarse_acc_ext[42]; // 粗路径符号
	assign flag_fine_negative = dec_fine_acc_ext[42]; // 精细路径符号
	assign dec_coarse_magnitude = flag_coarse_negative ? ((~dec_coarse_acc_ext) + 43'd1) : dec_coarse_acc_ext; // 对粗累加值安全取绝对幅度
	assign dec_fine_magnitude = flag_fine_negative ? ((~dec_fine_acc_ext) + 43'd1) : dec_fine_acc_ext; // 对精细累加值安全取绝对幅度
	assign dec_coarse_rounded_magnitude = (dec_coarse_magnitude + ROUND_HALF_Q17) >>> 17; // 粗路径执行半LSB远离零舍入
	assign dec_fine_rounded_magnitude = (dec_fine_magnitude + ROUND_HALF_Q17) >>> 17; // 精细路径执行半LSB远离零舍入
	assign dec_coarse_rounded_code = flag_coarse_negative ? -$signed(dec_coarse_rounded_magnitude) : $signed(dec_coarse_rounded_magnitude); // 粗路径恢复符号
	assign dec_fine_rounded_code = flag_fine_negative ? -$signed(dec_fine_rounded_magnitude) : $signed(dec_fine_rounded_magnitude); // 精细路径恢复符号
	assign flag_coarse_overflow_low = dec_coarse_rounded_code < PPG_CODE_MIN; // 粗路径负向饱和判定
	assign flag_coarse_overflow_high = dec_coarse_rounded_code > PPG_CODE_MAX; // 粗路径正向饱和判定
	assign flag_fine_overflow_low = dec_fine_rounded_code < PPG_CODE_MIN; // 精细路径负向饱和判定
	assign flag_fine_overflow_high = dec_fine_rounded_code > PPG_CODE_MAX; // 精细路径正向饱和判定
	assign dec_coarse_value = flag_coarse_overflow_low ? -24'sd8388608 : flag_coarse_overflow_high ? 24'sd8388607 : dec_coarse_rounded_code[23:0]; // 粗路径显式24位饱和
	assign dec_fine_value = (i_precision_mode == 1'b0) ? 24'sd0 : flag_fine_overflow_low ? -24'sd8388608 : flag_fine_overflow_high ? 24'sd8388607 : dec_fine_rounded_code[23:0]; // 9-bit事务精细结果固定清零，15-bit事务按舍入饱和模型输出 @satisfies: ADCN-04, ADCN-06

	//其他信号连线
	// 同一输入事务同时携带两路结果，保证版本和诊断字段原子对齐。
	assign dec_payload_input = {i_detect_code, i_stage1_raw, i_stage1_code_ext, i_stage2_raw, i_stage2_code_ext, i_nominal_15_code, i_nominal_15_valid, i_nominal_saturated, dec_fine_value, (i_precision_mode && i_programmable_15_valid), (i_programmable_15_calibration_applied && i_dc15_recovery_valid), (i_precision_mode && flag_fine_overflow_low), (i_precision_mode && flag_fine_overflow_high), dec_coarse_value, 1'b1, (i_calibration_applied && i_dc9_recovery_valid), flag_coarse_overflow_low, flag_coarse_overflow_high, i_dc_recovery_coef_epoch, i_config_epoch, i_coef_epoch, i_stage2_coef_epoch, i_calibrated_s1_value, i_calibration_applied, i_stage1_saturation_low, i_stage1_saturation_high, i_programmable_15_code, i_programmable_15_valid, i_programmable_15_calibration_applied, i_programmable_saturation_low, i_programmable_saturation_high, i_precision_mode, i_frame_id, i_sample_index, i_color_ir, i_frame_type, i_amb_code_snapshot, i_dc_code_snapshot, i_amb_code_epoch, i_dc_code_epoch}; // 事务结果和元数据统一打包

	//---------------输出信号连线---------------//
	//上游事务输入接口
	//上游结果事务输入
	assign o_result_ready = i_rstn && i_active_valid && flag_buffer_available; // 复位或无ACTIVE时禁止接收

	//下游事务输出接口
	//统一结果事务输出
	assign o_result_valid = result_valid_o;     // 输出有效桥接
	assign o_coarse_ppg_value = payload_o[COARSE_VALUE_LSB+:24]; // 粗结果桥接
	assign o_coarse_valid = payload_o[COARSE_VALID_LSB]; // 粗结果资格桥接
	assign o_coarse_recovery_calibrated = payload_o[COARSE_CAL_LSB]; // 粗校准资格桥接
	assign o_coarse_saturation_low = payload_o[COARSE_SAT_LOW_LSB]; // 粗负向饱和桥接
	assign o_coarse_saturation_high = payload_o[COARSE_SAT_HIGH_LSB]; // 粗正向饱和桥接
	assign o_fine_ppg_value = payload_o[FINE_VALUE_LSB+:24]; // 精细结果桥接
	assign o_fine_valid = payload_o[FINE_VALID_LSB]; // 精细结果资格桥接
	assign o_fine_recovery_calibrated = payload_o[FINE_CAL_LSB]; // 精细校准资格桥接
	assign o_fine_saturation_low = payload_o[FINE_SAT_LOW_LSB]; // 精细负向饱和桥接
	assign o_fine_saturation_high = payload_o[FINE_SAT_HIGH_LSB]; // 精细正向饱和桥接
	assign o_dc_recovery_coef_epoch = payload_o[DC_RECOVERY_EPOCH_LSB+:C_DC_RECOVERY_EPOCH_WIDTH]; // DC版本桥接

	//事务元数据输出接口
	//原子透传元数据输出
	assign o_calibrated_s1_value = payload_o[STAGE1_VALUE_LSB+:12]; // Stage1值桥接
	assign o_calibration_applied = payload_o[STAGE1_CAL_LSB]; // Stage1资格桥接
	assign o_stage1_saturation_low = payload_o[STAGE1_SAT_LOW_LSB]; // Stage1负饱和桥接
	assign o_stage1_saturation_high = payload_o[STAGE1_SAT_HIGH_LSB]; // Stage1正饱和桥接
	assign o_programmable_15_code = payload_o[PROGRAMMABLE_CODE_LSB+:15]; // 原始15位结果桥接
	assign o_programmable_15_valid = payload_o[PROGRAMMABLE_VALID_LSB]; // 原始15位资格桥接
	assign o_programmable_15_calibration_applied = payload_o[PROGRAMMABLE_CAL_LSB]; // 原始15位校准桥接
	assign o_programmable_saturation_low = payload_o[PROGRAMMABLE_SAT_LOW_LSB]; // 原始15位负饱和桥接
	assign o_programmable_saturation_high = payload_o[PROGRAMMABLE_SAT_HIGH_LSB]; // 原始15位正饱和桥接
	assign o_config_epoch = payload_o[CONFIG_EPOCH_LSB+:C_CONFIG_EPOCH_WIDTH]; // 导出本笔整套配置提交代号
	assign o_coef_epoch = payload_o[COEF_EPOCH_LSB+:C_COEF_EPOCH_WIDTH]; // 导出本笔Stage1权重提交代号
	assign o_stage2_coef_epoch = payload_o[STAGE2_EPOCH_LSB+:C_COEF_EPOCH_WIDTH]; // 导出精细重构增益提交代号
	assign o_precision_mode = payload_o[PRECISION_LSB]; // 导出与结果原子绑定的精度快照
	assign o_frame_id = payload_o[FRAME_ID_LSB+:C_FRAME_ID_WIDTH]; // 帧号桥接
	assign o_sample_index = payload_o[SAMPLE_INDEX_LSB+:C_SAMPLE_INDEX_WIDTH]; // 样本序号桥接
	assign o_color_ir = payload_o[COLOR_LSB];   // 颜色身份桥接
	assign o_frame_type = payload_o[FRAME_TYPE_LSB+:2]; // 事务类型桥接
	assign o_amb_code_snapshot = payload_o[AMB_CODE_LSB+:C_IDAC_CODE_WIDTH]; // AMB码桥接
	assign o_dc_code_snapshot = payload_o[DC_CODE_LSB+:C_IDAC_CODE_WIDTH]; // DC码桥接
	assign o_amb_code_epoch = payload_o[AMB_EPOCH_LSB+:C_CODE_EPOCH_WIDTH]; // 导出仅诊断使用的AMB提交代号
	assign o_dc_code_epoch = payload_o[DC_EPOCH_LSB+:C_CODE_EPOCH_WIDTH]; // DC码版本桥接
	assign o_detect_code = payload_o[DETECT_CODE_LSB+:9]; // 固定黄金检测码桥接
	assign o_stage1_raw = payload_o[STAGE1_RAW_LSB+:10]; // Stage1物理判决位桥接
	assign o_stage1_code_ext = payload_o[STAGE1_CODE_EXT_LSB+:11]; // 固定D1_EXT诊断值桥接
	assign o_stage2_raw = payload_o[STAGE2_RAW_LSB+:10]; // 第二级冗余物理判决位桥接
	assign o_stage2_code_ext = payload_o[STAGE2_CODE_EXT_LSB+:11]; // 第二级冗余解码诊断值桥接
	assign o_nominal_15_code = payload_o[NOMINAL_CODE_LSB+:15]; // 固定标称15-bit结果桥接
	assign o_nominal_15_valid = payload_o[NOMINAL_VALID_LSB]; // 固定标称结果资格桥接
	assign o_nominal_saturated = payload_o[NOMINAL_SATURATED_LSB]; // 固定标称结果饱和诊断桥接

	//-------------输出信号处理区域-------------//
	//下游事务输出接口
	//统一结果事务输出
	// 复位清空缓存；输入握手时锁存完整结果；消费且无新输入时撤销valid。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			payload_o <= {PAYLOAD_WIDTH{1'b0}}; // 复位清空所有结果和元数据
		end else if(flag_input_transfer == 1'b1)begin
			payload_o <= dec_payload_input;     // 原子锁存当前事务
		end
	end

	// valid寄存器区分装载、同拍替换与仅消费三种缓存状态。
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			result_valid_o <= 1'b0;             // 复位撤销输出事务
		end else if(flag_input_transfer == 1'b1)begin
			result_valid_o <= 1'b1;             // 接收新事务后产生一拍寄存延迟
		end else if(flag_output_transfer == 1'b1)begin
			result_valid_o <= 1'b0;             // 消费完成且无替换事务
		end
	end

endmodule
