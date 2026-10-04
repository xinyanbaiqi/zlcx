`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/07
// Design Name:        PPG ADC Programmable Reconstructor
// Module Name:        ppg_adc_programmable_reconstructor
// Description:        Description/ppg_adc_programmable_reconstructor_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_adc_programmable_reconstructor
//
// Referrences:        PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_adc_pipeline_overlap_corrector
//
// Version:            V1.0
// Revision Date:      2026/08/07
// History:
//    Time               Version       Revised by            Contents
// 2026/08/07            V1.0          Erie                  Create file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月07日
// 设计名称:           PPG ADC 15-bit可编程重构器
// 模块名称:           ppg_adc_programmable_reconstructor
// 模块说明:           Description/ppg_adc_programmable_reconstructor_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_adc_programmable_reconstructor
//
// 参考资料:           PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_adc_pipeline_overlap_corrector
//
// 当前版本:           V1.0
// 修订日期:           2026年08月07日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月07日        V1.0          Erie                  创建15-bit可编程固定系数重构通路

// 对已校准Stage1结果和Stage2总残差项执行ACTIVE固定系数重构并保持统一NORMAL事务
module ppg_adc_programmable_reconstructor
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16, // R/IR共享PPG周期标识字段位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16, // 精细结果数据流中的样本序号位宽
	parameter integer C_IDAC_CODE_WIDTH = 32'd8, // AMB和颜色DC码快照使用的字段位宽
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4, // IDAC安全提交版本标签的字段位宽
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8, // 整套ACTIVE配置版本标签的字段位宽
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8 // Stage1和Stage2系数版本标签的字段位宽
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字处理域工作时钟
	input i_rstn,                           // 低有效异步复位，释放由系统顶层同步

	//-------------ACTIVE配置接口-------------//
	input i_active_valid,                     // 当前ACTIVE V2快照具备事务接收资格
	input i_stage2_calibration_valid,         // Stage2系数来自合法片外拟合提交
	input signed [19:0]i_stage2_gain_q16,     // D2_EXT中心码使用的signed 20-bit Q16增益
	input signed [31:0]i_stage2_offset_q16,   // 最终15-bit残差使用的signed 32-bit Q16偏置
	input [C_COEF_EPOCH_WIDTH - 1:0]i_stage2_coef_epoch, // 当前Stage2系数组独立版本

	//-------------上游事务输入接口-------------//
	input i_result_valid,                       // overlap保持的完整NORMAL事务有效标志
	input signed [11:0]i_calibrated_s1_value,   // 已完成逐物理位校准的signed 12-bit Stage1值
	input i_calibration_applied,                // 本笔Stage1结果使用合法片外拟合系数
	input i_saturation_low,                     // Stage1校准结果曾触发负向12-bit饱和
	input i_saturation_high,                    // Stage1校准结果曾触发正向12-bit饱和
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 本笔样本绑定的ACTIVE配置版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 本笔样本绑定的Stage1系数组版本
	input [8:0]i_detect_code,                   // 固定9-bit黄金检测码，仅供观察和诊断
	input [9:0]i_stage1_raw,                    // 片外拟合核对使用的完整S1物理判决位
	input signed [10:0]i_stage1_code_ext,       // 固定冗余公式生成的未钳位D1_EXT
	input [9:0]i_stage2_raw,                    // 保留供未来Stage2逐物理位模型使用的RAW码
	input signed [10:0]i_stage2_code_ext,       // overlap解码得到的未钳位D2_EXT
	input signed [14:0]i_nominal_15_code,       // 固定系数黄金结果，只作为旁路字段透传
	input i_nominal_15_valid,                   // 当前事务携带固定标称15-bit结果的资格
	input i_nominal_saturated,                  // 固定标称重构结果触发端点保护的诊断
	input i_precision_mode,                     // 低为9-bit透传事务，高为15-bit重构事务
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id,   // R/IR共享PPG周期的事务标识
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 当前颜色结果在数据流中的顺序编号
	input i_color_ir,                           // 低表示红光，高表示红外
	input [1:0]i_frame_type,                    // router限定后的NORMAL事务类别
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // 本次积分绑定的AMB抵消码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 本次颜色采样绑定的DC抵消码
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // AMB码实际提交时对应的版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // 当前颜色DC码实际提交时对应的版本
	output o_result_ready,                      // 单元素输出缓存允许上游接收新事务

	//-------------下游事务输出接口-------------//
	input i_result_ready,                       // DC恢复或精细输出链允许消费完整事务
	output o_result_valid,                      // 统一结果载荷保持有效直到下游握手
	output signed [14:0]o_programmable_15_code, // ACTIVE系数重构并饱和后的signed 15-bit残差
	output o_programmable_15_valid,             // 仅15-bit事务具有正式可编程结果资格
	output o_programmable_15_calibration_applied, // Stage1和Stage2均使用合法拟合系数
	output o_programmable_saturation_low,       // 可编程结果低于-16384时的保护标志
	output o_programmable_saturation_high,      // 可编程结果高于+16383时的保护标志
	output [C_COEF_EPOCH_WIDTH - 1:0]o_stage2_coef_epoch, // 真正参与本笔重构的Stage2版本
	output signed [11:0]o_calibrated_s1_value,  // 原子透传正式Stage1校准结果
	output o_calibration_applied,               // 原样保留Stage1片外校准资格
	output o_stage1_saturation_low,             // 保留Stage1负向饱和诊断供数据导出
	output o_stage1_saturation_high,            // 保留Stage1正向饱和诊断供数据导出
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch, // 输出本笔事务绑定的ACTIVE版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch, // 标记Stage1逐位权重组实际参与本笔校准的版本
	output [8:0]o_detect_code,                  // 透传固定9-bit黄金检测码
	output [9:0]o_stage1_raw,                   // 透传Stage1完整物理判决码
	output signed [10:0]o_stage1_code_ext,      // 透传固定公式D1_EXT诊断值
	output [9:0]o_stage2_raw,                   // 导出第二级物理位供流片表征与模型升级
	output signed [10:0]o_stage2_code_ext,      // 导出第二级冗余解码结果供增益核对
	output signed [14:0]o_nominal_15_code,      // 透传固定标称15-bit黄金结果
	output o_nominal_15_valid,                  // 保留固定标称结果的精度资格
	output o_nominal_saturated,                 // 保留固定标称结果的饱和诊断
	output o_precision_mode,                    // 输出本笔事务的9-bit或15-bit模式快照
	output [C_FRAME_ID_WIDTH - 1:0]o_frame_id,  // 保持红光与红外结果配对所需帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index, // 保持精细数据流的样本顺序
	output o_color_ir,                          // 保持当前结果的红光或红外身份
	output [1:0]o_frame_type,                   // 保留NORMAL类别用于协议检查
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot, // 输出本笔采样使用的AMB码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot, // 输出当前颜色采样使用的DC码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // 输出与AMB码快照对应的版本
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch // 标记当前颜色DC码在帧安全边界的提交代号
);

	//-------------配置参数区域-------------//
	// 固定定点常量复现已冻结Stage1比例和signed 15-bit输出端点
	localparam signed [22:0] A1_FIXED_Q16 = 23'sd3533837; // Stage1中心码到15-bit标度的固定Q16比例
	localparam [38:0] ROUND_HALF_Q17 = 39'd65536; // Q17对称舍入所需的半整数LSB
	localparam signed [14:0] PROGRAMMABLE_CODE_MAX = 15'sd16383; // signed 15-bit正向饱和端点
	localparam signed [14:0] PROGRAMMABLE_CODE_MIN = 15'sh4000; // signed 15-bit负向饱和端点-16384
	// 元数据字段从低位开始固定排布，保持R/IR身份与IDAC快照原子更新
	localparam integer C_DC_EPOCH_LSB = 32'd0; // DC码版本位于公共元数据最低段
	localparam integer C_AMB_EPOCH_LSB = C_DC_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // AMB版本紧邻DC版本字段
	localparam integer C_DC_CODE_LSB = C_AMB_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // 颜色DC码位于两组版本之上
	localparam integer C_AMB_CODE_LSB = C_DC_CODE_LSB + C_IDAC_CODE_WIDTH; // AMB码快照跟随颜色DC码
	localparam integer C_FRAME_TYPE_LSB = C_AMB_CODE_LSB + C_IDAC_CODE_WIDTH; // NORMAL类别占据两位协议字段
	localparam integer C_COLOR_LSB = C_FRAME_TYPE_LSB + 32'd2; // 颜色身份位于事务类别之上
	localparam integer C_SAMPLE_INDEX_LSB = C_COLOR_LSB + 32'd1; // 样本编号紧随颜色字段
	localparam integer C_FRAME_ID_LSB = C_SAMPLE_INDEX_LSB + C_SAMPLE_INDEX_WIDTH; // PPG帧号位于公共元数据最高段
	localparam integer C_METADATA_WIDTH = C_FRAME_ID_LSB + C_FRAME_ID_WIDTH; // 汇总全部公共事务身份字段
	// 观察字段按上游语义排列，禁止把固定结果混入可编程算术
	localparam integer C_PRECISION_LSB = C_METADATA_WIDTH; // 精度快照位于公共元数据之上
	localparam integer C_NOMINAL_SATURATION_LSB = C_PRECISION_LSB + 32'd1; // 固定结果饱和标志独立保存
	localparam integer C_NOMINAL_VALID_LSB = C_NOMINAL_SATURATION_LSB + 32'd1; // 固定15-bit资格紧邻诊断位
	localparam integer C_NOMINAL_CODE_LSB = C_NOMINAL_VALID_LSB + 32'd1; // 标称黄金码占用独立15-bit字段
	localparam integer C_STAGE2_CODE_EXT_LSB = C_NOMINAL_CODE_LSB + 32'd15; // D2_EXT保留在黄金结果下方
	localparam integer C_STAGE2_RAW_LSB = C_STAGE2_CODE_EXT_LSB + 32'd11; // S2物理码与解码结果共同保存
	localparam integer C_STAGE1_CODE_EXT_LSB = C_STAGE2_RAW_LSB + 32'd10; // D1_EXT保持固定参考路径语义
	localparam integer C_DETECT_CODE_LSB = C_STAGE1_CODE_EXT_LSB + 32'd11; // 9-bit黄金检测码独立于校准值
	localparam integer C_STAGE1_RAW_LSB = C_DETECT_CODE_LSB + 32'd9; // S1物理码供片外拟合核对
	// Stage1校准状态、两级系数版本和正式15-bit结果组成payload最高段
	localparam integer C_STAGE1_SATURATION_HIGH_LSB = C_STAGE1_RAW_LSB + 32'd10; // Stage1正饱和诊断占一位
	localparam integer C_STAGE1_SATURATION_LOW_LSB = C_STAGE1_SATURATION_HIGH_LSB + 32'd1; // Stage1负饱和诊断相邻保存
	localparam integer C_STAGE1_CALIBRATION_APPLIED_LSB = C_STAGE1_SATURATION_LOW_LSB + 32'd1; // Stage1校准资格不由epoch推导
	localparam integer C_CALIBRATED_S1_VALUE_LSB = C_STAGE1_CALIBRATION_APPLIED_LSB + 32'd1; // signed 12-bit Stage1值保持原位宽
	localparam integer C_STAGE1_COEF_EPOCH_LSB = C_CALIBRATED_S1_VALUE_LSB + 32'd12; // Stage1系数组版本绑定当前样本
	localparam integer C_CONFIG_EPOCH_LSB = C_STAGE1_COEF_EPOCH_LSB + C_COEF_EPOCH_WIDTH; // ACTIVE版本跟随Stage1版本
	localparam integer C_STAGE2_COEF_EPOCH_LSB = C_CONFIG_EPOCH_LSB + C_CONFIG_EPOCH_WIDTH; // Stage2独立版本只对精细结果有效
	localparam integer C_PROGRAMMABLE_CALIBRATION_APPLIED_LSB = C_STAGE2_COEF_EPOCH_LSB + C_COEF_EPOCH_WIDTH; // 两级校准资格合并保存
	localparam integer C_PROGRAMMABLE_SATURATION_HIGH_LSB = C_PROGRAMMABLE_CALIBRATION_APPLIED_LSB + 32'd1; // 15-bit正向保护标志
	localparam integer C_PROGRAMMABLE_SATURATION_LOW_LSB = C_PROGRAMMABLE_SATURATION_HIGH_LSB + 32'd1; // 15-bit负向保护标志
	localparam integer C_PROGRAMMABLE_VALID_LSB = C_PROGRAMMABLE_SATURATION_LOW_LSB + 32'd1; // 精细结果资格由本笔精度决定
	localparam integer C_PROGRAMMABLE_CODE_LSB = C_PROGRAMMABLE_VALID_LSB + 32'd1; // signed 15-bit结果位于payload最高段
	localparam integer C_PAYLOAD_WIDTH = C_PROGRAMMABLE_CODE_LSB + 32'd15; // 单元素缓存覆盖完整不可拆分事务

	//---------------标志信号---------------//
	// 握手资格和定点边界标志只组合读取当前稳定输入与缓存状态
	wire flag_output_buffer_available;      // 输出为空或本拍将被消费时允许替换
	wire flag_input_transfer;               // 当前上升沿接纳一笔完整上游事务
	wire flag_output_transfer;              // 当前上升沿下游消费现有结果
	wire flag_calculation_qualified;        // 有效15-bit输入允许乘法器观察操作数
	wire flag_accumulator_negative;         // Q17累加结果为负时选择负向舍入
	wire flag_programmable_overflow_low;    // 舍入整数低于signed 15-bit下端点
	wire flag_programmable_overflow_high;   // 舍入整数高于signed 15-bit上端点
	wire flag_programmable_valid;           // 当前payload是否携带可编程15-bit结果
	wire flag_programmable_calibration_applied; // 两级系数均合法时声明校准完成
	wire flag_programmable_saturation_low;  // 精细结果有效且发生负向饱和
	wire flag_programmable_saturation_high; // 精细结果有效且发生正向饱和

	//---------------译码信号---------------//
	// Stage1中心化保持完整signed 12-bit输入范围并精确加入半码偏移
	wire signed [13:0]dec_stage1_value_ext; // Stage1校准值扩展两位防止中心化溢出
	wire signed [13:0]dec_stage1_center_x2; // 两倍中心码加1实现S1_CENTER+0.5
	wire signed [13:0]dec_stage1_center_x2_active; // 9-bit事务将Stage1乘法输入隔离为零
	// D2_EXT来自冻结overlap解码，合法范围-4至515保证窄化后无信息丢失
	wire signed [12:0]dec_stage2_value_ext; // D2_EXT扩展后执行安全移位和减中点
	wire signed [12:0]dec_stage2_center_x2_full; // 保留完整端口范围的两倍中心码
	wire signed [10:0]dec_stage2_center_x2; // 合法物理D2_EXT对应的11-bit中心项
	wire signed [10:0]dec_stage2_center_x2_active; // 粗精度事务屏蔽Stage2乘法活动
	wire signed [19:0]dec_stage2_gain_active; // 仅精细事务选通ACTIVE Stage2增益
	wire signed [32:0]dec_stage2_offset_q17; // Q16 offset左移一位转换到Q17标度
	wire signed [32:0]dec_stage2_offset_q17_active; // 9-bit事务不向累加器注入偏置
	// 两个乘积显式扩展到公共38-bit Q17累加标度
	wire signed [36:0]dec_stage1_product_q17; // 固定A1与14-bit Stage1中心项的乘积
	wire signed [30:0]dec_stage2_product_q17; // 可编程增益与11-bit Stage2中心项的乘积
	wire signed [37:0]dec_stage1_product_ext; // Stage1乘积符号扩展到累加器宽度
	wire signed [37:0]dec_stage2_product_ext; // 把第二级可调增益贡献提升到公共Q17宽度
	wire signed [37:0]dec_stage2_offset_ext; // Stage2 offset符号扩展到公共Q17宽度
	wire signed [37:0]dec_accumulator_q17;  // 两级贡献与offset的38-bit Q17总和
	// 对称舍入先取39-bit绝对值，再进行半LSB偏置和端点比较
	wire signed [38:0]dec_accumulator_ext;  // 累加器增加保护位以安全处理最小负数
	wire [38:0]dec_accumulator_magnitude;   // Q17总和的无符号绝对值
	wire [38:0]dec_rounding_magnitude_biased; // 绝对值加65536形成半LSB舍入条件
	wire [38:0]dec_rounded_magnitude;       // 去除17个小数位后的正向整数幅度
	wire signed [38:0]dec_rounded_code;     // 恢复符号后的完整舍入结果
	wire signed [14:0]dec_saturated_code;   // 显式限制到signed 15-bit端点
	wire signed [14:0]dec_programmable_code; // 9-bit事务强制输出零的正式结果
	wire [C_COEF_EPOCH_WIDTH - 1:0]dec_stage2_epoch_qualified; // 9-bit事务清除未使用的Stage2版本
	wire [C_PAYLOAD_WIDTH - 1:0]dec_payload_input; // 当前输入沿待锁存的完整结果载荷

	//---------------其他信号---------------//

	//---------------输出信号---------------//
	// 单个宽寄存器保证数值、资格、版本和全部身份字段同拍替换
	reg [C_PAYLOAD_WIDTH - 1:0]payload_o;   // 反压期间保持完整统一结果载荷
	reg result_valid_o;                     // 指示payload_o中存在一笔待消费事务

	//-------------其他信号连线-------------//
	// 单元素弹性缓存允许同拍消费旧事务并接收新事务
	assign flag_output_buffer_available = (result_valid_o == 1'b0) || i_result_ready; // 计算当前缓存写入许可
	assign flag_input_transfer = i_result_valid && o_result_ready; // 定义唯一上游事务接收事件
	assign flag_output_transfer = result_valid_o && i_result_ready; // 定义唯一输出事务消费事件
	assign flag_calculation_qualified = i_result_valid && i_precision_mode; // 只让有效精细事务激活算术操作数
	// 中心化公式直接作用于校准Stage1和overlap产生的D2_EXT
	assign dec_stage1_value_ext = {{2{i_calibrated_s1_value[11]}}, i_calibrated_s1_value}; // 扩展Stage1符号至14 bit
	assign dec_stage1_center_x2 = (dec_stage1_value_ext <<< 1) - 14'sd511; // 实现2*(S1-256)+1
	assign dec_stage1_center_x2_active = flag_calculation_qualified ? dec_stage1_center_x2 : 14'sd0; // 隔离粗精度Stage1操作数
	assign dec_stage2_value_ext = {{2{i_stage2_code_ext[10]}}, i_stage2_code_ext}; // 扩展D2_EXT后再左移
	assign dec_stage2_center_x2_full = (dec_stage2_value_ext <<< 1) - 13'sd512; // 完整计算2*(D2-256)
	assign dec_stage2_center_x2 = dec_stage2_center_x2_full[10:0]; // 依据D2_EXT合法范围显式窄化
	assign dec_stage2_center_x2_active = flag_calculation_qualified ? dec_stage2_center_x2 : 11'sd0; // 屏蔽9-bit Stage2项
	assign dec_stage2_gain_active = flag_calculation_qualified ? i_stage2_gain_q16 : 20'sd0; // 仅15-bit事务选通增益
	assign dec_stage2_offset_q17 = $signed({i_stage2_offset_q16, 1'b0}); // 把Q16偏置精确转换为Q17
	assign dec_stage2_offset_q17_active = flag_calculation_qualified ? dec_stage2_offset_q17 : 33'sd0; // 粗精度不注入offset
	// 乘加路径使用显式signed操作数和统一38-bit累加器
	assign dec_stage1_product_q17 = $signed(dec_stage1_center_x2_active) * $signed(A1_FIXED_Q16); // 形成Stage1固定比例贡献
	assign dec_stage2_product_q17 = $signed(dec_stage2_center_x2_active) * $signed(dec_stage2_gain_active); // 形成Stage2可编程贡献
	assign dec_stage1_product_ext = {{1{dec_stage1_product_q17[36]}}, dec_stage1_product_q17}; // 扩展Stage1乘积符号
	assign dec_stage2_product_ext = {{7{dec_stage2_product_q17[30]}}, dec_stage2_product_q17}; // 对齐第二级贡献到38-bit累加标度
	assign dec_stage2_offset_ext = {{5{dec_stage2_offset_q17_active[32]}}, dec_stage2_offset_q17_active}; // 扩展Q17偏置符号
	assign dec_accumulator_q17 = dec_stage1_product_ext + dec_stage2_product_ext + dec_stage2_offset_ext; // 汇总完整Q17结果，使用本事务绑定的Stage1/Stage2值，非标称或原始替代值 @satisfies: ADCN-05
	// 舍入逻辑对正负数使用相同幅度规则并在比较后才截位
	assign dec_accumulator_ext = {dec_accumulator_q17[37], dec_accumulator_q17}; // 增加取绝对值保护位
	assign flag_accumulator_negative = dec_accumulator_ext[38]; // 记录舍入前的结果符号
	assign dec_accumulator_magnitude = flag_accumulator_negative ?
		((~dec_accumulator_ext) + 39'd1) : dec_accumulator_ext; // 安全取得Q17幅度
	assign dec_rounding_magnitude_biased = dec_accumulator_magnitude + ROUND_HALF_Q17; // 加半LSB实现最近整数舍入
	assign dec_rounded_magnitude = dec_rounding_magnitude_biased >> 17; // 移除Q17小数部分
	assign dec_rounded_code = flag_accumulator_negative ?
		-$signed(dec_rounded_magnitude) : $signed(dec_rounded_magnitude); // 对幅度恢复原始符号
	assign flag_programmable_overflow_low = dec_rounded_code < -39'sd16384; // 检测负向超出signed 15-bit范围
	assign flag_programmable_overflow_high = dec_rounded_code > 39'sd16383; // 检测正向超出signed 15-bit范围
	assign dec_saturated_code = flag_programmable_overflow_low ? PROGRAMMABLE_CODE_MIN :
		flag_programmable_overflow_high ? PROGRAMMABLE_CODE_MAX : dec_rounded_code[14:0]; // 显式选择端点或范围内结果
	// 精度资格同时控制结果、Stage2版本和最终校准状态
	assign dec_programmable_code = i_precision_mode ? dec_saturated_code : 15'sd0; // 9-bit事务不携带精细数值
	assign flag_programmable_valid = i_precision_mode; // 仅15-bit输入产生正式精细资格
	assign flag_programmable_calibration_applied = i_precision_mode &&
		i_calibration_applied && i_stage2_calibration_valid; // 两级均合法才声明完整校准
	assign flag_programmable_saturation_low = i_precision_mode && flag_programmable_overflow_low; // 屏蔽9-bit负饱和
	assign flag_programmable_saturation_high = i_precision_mode && flag_programmable_overflow_high; // 屏蔽9-bit正饱和
	assign dec_stage2_epoch_qualified = i_precision_mode ? i_stage2_coef_epoch :
		{C_COEF_EPOCH_WIDTH{1'b0}};         // 粗精度事务清除未参与计算的Stage2版本
	// 打包顺序与字段LSB常量一一对应，确保一次写入替换全部事务身份
	assign dec_payload_input = {
		dec_programmable_code,
		flag_programmable_valid,
		flag_programmable_saturation_low,
		flag_programmable_saturation_high,
		flag_programmable_calibration_applied,
		dec_stage2_epoch_qualified,
		i_config_epoch,
		i_coef_epoch,
		i_calibrated_s1_value,
		i_calibration_applied,
		i_saturation_low,
		i_saturation_high,
		i_stage1_raw,
		i_detect_code,
		i_stage1_code_ext,
		i_stage2_raw,
		i_stage2_code_ext,
		i_nominal_15_code,
		i_nominal_15_valid,
		i_nominal_saturated,
		i_precision_mode,
		i_frame_id,
		i_sample_index,
		i_color_ir,
		i_frame_type,
		i_amb_code_snapshot,
		i_dc_code_snapshot,
		i_amb_code_epoch,
		i_dc_code_epoch
	};                                      // 形成186-bit统一缓存写入数据

	//-------------输出信号连线-------------//
	// 所有复杂输出只读取已锁存payload，反压期间不会跟随输入总线变化
	assign o_result_ready = i_rstn && i_active_valid && flag_output_buffer_available; // ACTIVE无效或复位时关闭接收
	assign o_result_valid = result_valid_o; // 桥接统一输出事务有效标志
	assign o_programmable_15_code = payload_o[C_PROGRAMMABLE_CODE_LSB +: 15]; // 取出signed 15-bit可编程结果
	assign o_programmable_15_valid = payload_o[C_PROGRAMMABLE_VALID_LSB]; // 取出精细结果有效资格
	assign o_programmable_saturation_low = payload_o[C_PROGRAMMABLE_SATURATION_LOW_LSB]; // 取出15-bit负饱和标志
	assign o_programmable_saturation_high = payload_o[C_PROGRAMMABLE_SATURATION_HIGH_LSB]; // 取出15-bit正饱和标志
	assign o_programmable_15_calibration_applied = payload_o[C_PROGRAMMABLE_CALIBRATION_APPLIED_LSB]; // 取出两级校准资格
	assign o_stage2_coef_epoch = payload_o[C_STAGE2_COEF_EPOCH_LSB +: C_COEF_EPOCH_WIDTH]; // 读取精细增益对应的独立提交代号
	assign o_config_epoch = payload_o[C_CONFIG_EPOCH_LSB +: C_CONFIG_EPOCH_WIDTH]; // 取出完整ACTIVE版本
	assign o_coef_epoch = payload_o[C_STAGE1_COEF_EPOCH_LSB +: C_COEF_EPOCH_WIDTH]; // 读取逐物理位校准权重的事务标签
	assign o_calibrated_s1_value = payload_o[C_CALIBRATED_S1_VALUE_LSB +: 12]; // 取出正式Stage1校准值
	assign o_calibration_applied = payload_o[C_STAGE1_CALIBRATION_APPLIED_LSB]; // 取出Stage1校准资格
	assign o_stage1_saturation_low = payload_o[C_STAGE1_SATURATION_LOW_LSB]; // 取出Stage1负饱和诊断
	assign o_stage1_saturation_high = payload_o[C_STAGE1_SATURATION_HIGH_LSB]; // 取出Stage1正饱和诊断
	assign o_stage1_raw = payload_o[C_STAGE1_RAW_LSB +: 10]; // 取出S1物理码
	assign o_detect_code = payload_o[C_DETECT_CODE_LSB +: 9]; // 取出固定检测码
	assign o_stage1_code_ext = payload_o[C_STAGE1_CODE_EXT_LSB +: 11]; // 取出D1_EXT观察值
	assign o_stage2_raw = payload_o[C_STAGE2_RAW_LSB +: 10]; // 恢复第二级原始判决位供测试导出
	assign o_stage2_code_ext = payload_o[C_STAGE2_CODE_EXT_LSB +: 11]; // 恢复级间增益计算使用的D2_EXT
	assign o_nominal_15_code = payload_o[C_NOMINAL_CODE_LSB +: 15]; // 取出固定标称15-bit结果
	assign o_nominal_15_valid = payload_o[C_NOMINAL_VALID_LSB]; // 取出固定标称结果资格
	assign o_nominal_saturated = payload_o[C_NOMINAL_SATURATION_LSB]; // 取出固定标称饱和诊断
	assign o_precision_mode = payload_o[C_PRECISION_LSB]; // 取出事务精度快照
	assign o_dc_code_epoch = payload_o[C_DC_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 取出颜色DC码版本
	assign o_amb_code_epoch = payload_o[C_AMB_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 取出AMB码版本
	assign o_dc_code_snapshot = payload_o[C_DC_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 取出颜色DC码快照
	assign o_amb_code_snapshot = payload_o[C_AMB_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 取出AMB码快照
	assign o_frame_type = payload_o[C_FRAME_TYPE_LSB +: 2]; // 取出NORMAL类别字段
	assign o_color_ir = payload_o[C_COLOR_LSB]; // 取出红光或红外身份
	assign o_sample_index = payload_o[C_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH]; // 取出样本顺序编号
	assign o_frame_id = payload_o[C_FRAME_ID_LSB +: C_FRAME_ID_WIDTH]; // 取出共享PPG帧号

	//-----------输出信号处理区域-----------//
	// payload只在唯一输入握手沿更新，复位立即清除所有不可用载荷
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			payload_o <= {C_PAYLOAD_WIDTH{1'b0}}; // 复位清除完整结果缓存
		end else if(flag_input_transfer == 1'b1)begin
			payload_o <= dec_payload_input; // 原子锁存算术结果、资格和事务元数据
		end
	end

	// valid独立管理空闲、反压和同拍消费替换，不与payload形成多目标过程
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			result_valid_o <= 1'b0;         // 复位撤销任何待消费事务
		end else if(flag_input_transfer == 1'b1)begin
			result_valid_o <= 1'b1;         // 新输入接纳后保持输出有效
		end else if(flag_output_transfer == 1'b1)begin
			result_valid_o <= 1'b0;         // 仅消费旧事务时返回空闲
		end
	end

endmodule
