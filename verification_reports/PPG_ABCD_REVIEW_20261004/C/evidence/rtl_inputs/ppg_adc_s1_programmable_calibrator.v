`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/06
// Design Name:        PPG ADC Stage1 Programmable Calibrator
// Module Name:        ppg_adc_s1_programmable_calibrator
// Description:        Description/ppg_adc_s1_programmable_calibrator_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_adc_s1_programmable_calibrator
//
// Referrences:        PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
//
// Dependencies:       ppg_adc_s1_redundancy_corrector,
//                     ppg_system_active_config_unpack,
//                     ppg_system_config_manager
//
// Version:            V1.0
// Revision Date:      2026/08/06
// History:
//    Time               Version       Revised by            Contents
// 2026/08/06            V1.0          Erie                  Create file.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月06日
// 设计名称:           PPG ADC Stage1逐物理位可编程校准器
// 模块名称:           ppg_adc_s1_programmable_calibrator
// 模块说明:           Description/ppg_adc_s1_programmable_calibrator_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_adc_s1_programmable_calibrator
//
// 参考资料:           PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
//
// 依赖文件:           ppg_adc_s1_redundancy_corrector、
//                     ppg_system_active_config_unpack、
//                     ppg_system_config_manager
//
// 当前版本:           V1.0
// 修订日期:           2026年08月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月06日        V1.0          Erie                  创建文件

// 直接对S1十个物理判决位执行ACTIVE Q16固定系数乘加，并原子保持校准结果及事务元数据
module ppg_adc_s1_programmable_calibrator
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16,                         // R/IR共享PPG周期标识字段位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16,                     // 各颜色结果排序使用的样本编号位宽
	parameter integer C_IDAC_CODE_WIDTH = 32'd8,                         // 当前事务绑定的AMB与DC码值宽度
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4,                        // IDAC安全提交版本标签位宽
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8,                      // 完整ACTIVE配置版本标签位宽
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8                         // Stage1校准系数组版本标签位宽
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字处理域工作时钟
	input i_rstn,                           // 低有效异步复位，释放由系统顶层同步

	//-------------ACTIVE配置接口-------------//
	input i_active_valid,                     // 当前ACTIVE快照具备接收新事务的运行资格
	input i_stage1_calibration_valid,         // 当前权重来自合法提交的片外拟合系数
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 当前完整ACTIVE配置的提交版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 当前Stage1系数组的独立版本
	input signed [25:0]i_stage1_weight_q16_0, // vd0最低物理位对应的1.0级绝对权重
	input signed [25:0]i_stage1_weight_q16_1, // vd1物理位对应的2.0级独立权重
	input signed [25:0]i_stage1_weight_q16_2, // vd2由第三判决器建立4.0级量化跨度
	input signed [25:0]i_stage1_weight_q16_3, // 作用于S1_RAW[3]冗余支路的独立权重
	input signed [25:0]i_stage1_weight_q16_4, // 作用于S1_RAW[4]主8.0支路的拟合权重
	input signed [25:0]i_stage1_weight_q16_5, // vd4进入高位链时使用的16.0级拟合权重
	input signed [25:0]i_stage1_weight_q16_6, // vd5中高位判决使用的32.0级拟合权重
	input signed [25:0]i_stage1_weight_q16_7, // vd6跨入64.0级高位区间的拟合权重
	input signed [25:0]i_stage1_weight_q16_8, // vd7负责128.0级次高位跨度的拟合权重
	input signed [25:0]i_stage1_weight_q16_9, // vd8最高物理位使用的256.0级拟合权重
	input signed [31:0]i_stage1_offset_q16,   // 与十个物理位贡献共同累加的Q16偏置

	//-------------上游事务输入接口-------------//
	input i_result_valid,                       // S1固定重构器保持的完整输入事务有效标志
	input [9:0]i_stage1_raw,                    // 十个物理判决位构成的唯一校准算术输入
	input [8:0]i_detect_code,                   // 固定黄金9-bit检测码，仅作为诊断字段透传
	input signed [10:0]i_stage1_code_ext,       // 未钳位D1_EXT，仅用于黄金对照和量程观察
	input [9:0]i_stage2_raw,                    // 为后续15-bit可编程重构保留的物理码
	input i_precision_mode,                     // 与当前事务绑定的9-bit或15-bit模式快照
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id,   // R/IR共享PPG周期的事务标识
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 当前颜色内结果的顺序编号
	input i_color_ir,                           // 低为红光，高为红外的颜色属性
	input [1:0]i_frame_type,                    // 当前事务属于AMB_CAL、DCS_CAL或NORMAL
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // 本次积分实际施加的AMB码快照
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 本次颜色实际施加的DC码快照
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // 本次AMB码对应的提交版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // 本次颜色DC码对应的提交版本
	output o_result_ready,                      // 返回上游的唯一完整事务接收许可

	//-------------下游校准输出接口-------------//
	input i_calibrated_ready,                   // router允许接收当前完整校准载荷
	output o_calibrated_valid,                  // 校准结果及全部元数据的保持型有效标志
	output signed [11:0]o_calibrated_s1_value,  // 对称舍入并饱和到signed 12-bit的Stage1值
	output o_calibration_applied,               // 指明该笔结果使用合法片外拟合系数
	output o_saturation_low,                    // 未钳位舍入结果低于-2048的诊断标志
	output o_saturation_high,                   // 未钳位舍入结果高于+2047的诊断标志
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch, // 输出本笔计算使用的ACTIVE配置版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch, // 输出本笔计算使用的Stage1系数版本
	output [9:0]o_stage1_raw,                   // 原子透传本笔校准使用的S1物理位
	output [8:0]o_detect_code,                  // 原子透传固定黄金检测码
	output signed [10:0]o_stage1_code_ext,      // 原子透传未钳位D1_EXT
	output [9:0]o_stage2_raw,                   // 原子透传同一事务的S2物理位
	output o_precision_mode,                    // 输出本笔事务的已提交精度快照
	output [C_FRAME_ID_WIDTH - 1:0]o_frame_id,  // 输出与校准结果绑定的共享帧号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index, // 输出与校准结果绑定的样本序号
	output o_color_ir,                          // 输出当前载荷所属颜色
	output [1:0]o_frame_type,                   // 输出当前载荷的AMB、DCS或NORMAL类别
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot, // 输出本笔采样实际使用的AMB码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot, // 输出本笔采样实际使用的颜色DC码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // 输出本笔AMB码版本标签
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch // 输出本笔颜色DC码版本标签
);

	//-------------配置参数区域-------------//
	// payload字段从低位事务元数据逐段扩展到最高位校准结果
	localparam integer C_DC_EPOCH_LSB = 32'd0; // payload最低段保存颜色DC码版本
	localparam integer C_AMB_EPOCH_LSB = C_DC_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // AMB版本紧邻DC版本字段
	localparam integer C_DC_CODE_LSB = C_AMB_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // 颜色DC码位于两组epoch之上
	localparam integer C_AMB_CODE_LSB = C_DC_CODE_LSB + C_IDAC_CODE_WIDTH; // AMB码快照跟随颜色DC码
	localparam integer C_FRAME_TYPE_LSB = C_AMB_CODE_LSB + C_IDAC_CODE_WIDTH; // 帧类别占据码值字段之后两位
	localparam integer C_COLOR_LSB = C_FRAME_TYPE_LSB + 32'd2; // 颜色标志位于帧类别之上
	localparam integer C_SAMPLE_INDEX_LSB = C_COLOR_LSB + 32'd1; // 样本序号跟随颜色属性
	localparam integer C_FRAME_ID_LSB = C_SAMPLE_INDEX_LSB + C_SAMPLE_INDEX_WIDTH; // 帧号占据事务元数据最高段
	localparam integer C_METADATA_WIDTH = C_FRAME_ID_LSB + C_FRAME_ID_WIDTH; // 汇总原始事务元数据总宽度
	localparam integer C_PRECISION_LSB = C_METADATA_WIDTH; // 精度快照位于公共事务元数据之上
	localparam integer C_STAGE2_RAW_LSB = C_PRECISION_LSB + 32'd1; // S2物理码紧随精度资格
	localparam integer C_STAGE1_CODE_EXT_LSB = C_STAGE2_RAW_LSB + 32'd10; // D1_EXT位于S2物理码之上
	localparam integer C_DETECT_CODE_LSB = C_STAGE1_CODE_EXT_LSB + 32'd11; // 固定检测码跟随扩展码
	localparam integer C_STAGE1_RAW_LSB = C_DETECT_CODE_LSB + 32'd9; // S1物理位位于固定检测码之上
	localparam integer C_COEF_EPOCH_LSB = C_STAGE1_RAW_LSB + 32'd10; // 系数版本绑定全部ADC数值字段
	localparam integer C_CONFIG_EPOCH_LSB = C_COEF_EPOCH_LSB + C_COEF_EPOCH_WIDTH; // 完整配置版本位于系数版本之上
	localparam integer C_SATURATION_HIGH_LSB = C_CONFIG_EPOCH_LSB + C_CONFIG_EPOCH_WIDTH; // 正向饱和标志占据单独一位
	localparam integer C_SATURATION_LOW_LSB = C_SATURATION_HIGH_LSB + 32'd1; // 负向饱和标志与正向标志相邻
	localparam integer C_CALIBRATION_APPLIED_LSB = C_SATURATION_LOW_LSB + 32'd1; // 校准资格位绑定当前计算
	localparam integer C_CALIBRATED_VALUE_LSB = C_CALIBRATION_APPLIED_LSB + 32'd1; // signed 12-bit校准值位于payload最高段
	localparam integer C_PAYLOAD_WIDTH = C_CALIBRATED_VALUE_LSB + 32'd12; // 单元素输出缓存完整载荷宽度
	localparam signed [11:0] CALIBRATED_VALUE_MAX = 12'sd2047; // signed 12-bit正向饱和端点
	localparam signed [11:0] CALIBRATED_VALUE_MIN = -12'sd2048; // signed 12-bit负向饱和端点

	//---------------标志信号---------------//
	// 三个握手标志定义缓存可写、输入接收和输出消费的唯一事件
	wire flag_output_buffer_available;      // 输出为空或本拍将被下游消费
	wire flag_input_transfer;               // 当前上升沿接纳一笔完整S1事务
	wire flag_output_transfer;              // 当前上升沿下游消费现有校准事务
	wire flag_accumulator_negative;         // Q16累加器为负时选择对称负向舍入
	wire flag_saturation_low;               // 舍入整数低于signed 12-bit范围
	wire flag_saturation_high;              // 舍入整数高于signed 12-bit范围

	//---------------译码信号---------------//
	// 每个物理位只门控同索引权重，全部贡献显式扩展到公共33-bit Q16宽度
	wire signed [32:0]dec_offset_q16_ext;   // 32-bit Q16偏置的符号扩展值
	wire signed [32:0]dec_weight_q16_0;     // vd0最低位选通后的1.0级Q16贡献
	wire signed [32:0]dec_weight_q16_1;     // vd1置位时加入2.0级Q16贡献
	wire signed [32:0]dec_weight_q16_2;     // vd2第三判决位形成4.0级Q16贡献
	wire signed [32:0]dec_weight_q16_3;     // S1_RAW[3]选通后的冗余8.0贡献
	wire signed [32:0]dec_weight_q16_4;     // S1_RAW[4]选通后的主8.0贡献
	wire signed [32:0]dec_weight_q16_5;     // vd4选通后注入16.0级高位链贡献
	wire signed [32:0]dec_weight_q16_6;     // vd5选通后注入32.0级中高位贡献
	wire signed [32:0]dec_weight_q16_7;     // vd6导通64.0级高位拟合分量
	wire signed [32:0]dec_weight_q16_8;     // vd7跨越128.0级次高位量化跨度
	wire signed [32:0]dec_weight_q16_9;     // vd8控制256.0级最高位拟合分量
	wire signed [32:0]dec_accumulator_q16;  // 十个物理位贡献与offset的33-bit Q16总和
	wire signed [33:0]dec_accumulator_ext;  // 舍入前增加保护位的有符号累加器
	wire [33:0]dec_accumulator_magnitude;   // 累加器的无符号绝对值
	wire [34:0]dec_rounding_magnitude_biased; // 绝对值加Q16半LSB后的保护宽度结果
	wire [18:0]dec_rounded_magnitude;       // 去除16个小数位后的非负整数幅度
	wire signed [19:0]dec_rounded_value;    // 恢复符号且尚未执行12-bit饱和的整数
	wire signed [11:0]dec_calibrated_value; // 显式端点保护后的最终Stage1校准值
	wire [C_PAYLOAD_WIDTH - 1:0]dec_payload_input; // 当前待接纳事务的完整组合载荷

	//---------------其他信号---------------//

	//---------------输出信号---------------//
	// 单元素缓存只用一个payload寄存目标保证全部字段原子替换
	reg [C_PAYLOAD_WIDTH - 1:0]payload_o;   // 反压期间保持校准结果、资格、版本和原事务载荷
	reg calibrated_valid_o;                 // 指示payload缓存拥有一笔尚未消费的事务

	//-------------其他信号连线-------------//
	// ACTIVE资格和单元素输出状态共同决定是否允许上游完成传输
	assign flag_output_buffer_available = (calibrated_valid_o == 1'b0) || i_calibrated_ready; // 支持旧输出消费和新输入同拍替换
	assign flag_input_transfer = i_result_valid && o_result_ready; // 定义唯一输入事务接收事件
	assign flag_output_transfer = calibrated_valid_o && i_calibrated_ready; // 定义唯一输出事务消费事件

	// 偏置和十个权重先各自符号扩展，避免条件运算破坏signed传播
	assign dec_offset_q16_ext = {i_stage1_offset_q16[31], i_stage1_offset_q16}; // 把Q16偏置扩展到公共累加宽度
	assign dec_weight_q16_0 = i_stage1_raw[0] ?
		{{7{i_stage1_weight_q16_0[25]}}, i_stage1_weight_q16_0} : 33'sd0; // vd0未选中时贡献严格为零
	assign dec_weight_q16_1 = i_stage1_raw[1] ?
		{{7{i_stage1_weight_q16_1[25]}}, i_stage1_weight_q16_1} : 33'sd0; // vd1按物理位决定是否加入总和
	assign dec_weight_q16_2 = i_stage1_raw[2] ?
		{{7{i_stage1_weight_q16_2[25]}}, i_stage1_weight_q16_2} : 33'sd0; // vd2独立控制其四倍标称贡献
	assign dec_weight_q16_3 = i_stage1_raw[3] ?
		{{7{i_stage1_weight_q16_3[25]}}, i_stage1_weight_q16_3} : 33'sd0; // 冗余判决位不与主8.0支路合并
	assign dec_weight_q16_4 = i_stage1_raw[4] ?
		{{7{i_stage1_weight_q16_4[25]}}, i_stage1_weight_q16_4} : 33'sd0; // 主8.0物理位保留独立失配权重
	assign dec_weight_q16_5 = i_stage1_raw[5] ?
		{{7{i_stage1_weight_q16_5[25]}}, i_stage1_weight_q16_5} : 33'sd0; // vd4为高位链加入16.0标称项
	assign dec_weight_q16_6 = i_stage1_raw[6] ?
		{{7{i_stage1_weight_q16_6[25]}}, i_stage1_weight_q16_6} : 33'sd0; // vd5门控中高位32.0拟合项
	assign dec_weight_q16_7 = i_stage1_raw[7] ?
		{{7{i_stage1_weight_q16_7[25]}}, i_stage1_weight_q16_7} : 33'sd0; // vd6门控64.0高位拟合项
	assign dec_weight_q16_8 = i_stage1_raw[8] ?
		{{7{i_stage1_weight_q16_8[25]}}, i_stage1_weight_q16_8} : 33'sd0; // vd7选通128.0标称级权重
	assign dec_weight_q16_9 = i_stage1_raw[9] ?
		{{7{i_stage1_weight_q16_9[25]}}, i_stage1_weight_q16_9} : 33'sd0; // vd8选通最高256.0标称级权重

	// 全部33-bit signed操作数直接相加，覆盖V1合法系数和offset的最坏组合
	assign dec_accumulator_q16 = dec_offset_q16_ext +
		dec_weight_q16_0 + dec_weight_q16_1 + dec_weight_q16_2 +
		dec_weight_q16_3 + dec_weight_q16_4 + dec_weight_q16_5 +
		dec_weight_q16_6 + dec_weight_q16_7 + dec_weight_q16_8 +
		dec_weight_q16_9;                   // 形成逐物理位绝对权重模型的Q16结果 @satisfies: ADCN-01

	// 先扩展再取绝对值并加32768，实现正负对称且半LSB远离零
	assign dec_accumulator_ext = {dec_accumulator_q16[32], dec_accumulator_q16}; // 增加保护位避免最小负值取反溢出
	assign flag_accumulator_negative = dec_accumulator_ext[33]; // 使用扩展累加器符号位选择恢复方向
	assign dec_accumulator_magnitude = flag_accumulator_negative ?
		((~dec_accumulator_ext) + 34'd1) : dec_accumulator_ext; // 取得不丢位的Q16绝对值
	assign dec_rounding_magnitude_biased =
		{1'b0, dec_accumulator_magnitude} + 35'd32768; // 增加Q16半LSB形成tie远离零条件 @satisfies: ADCN-02
	assign dec_rounded_magnitude = dec_rounding_magnitude_biased[34:16]; // 去除16个小数位并保留完整整数幅度
	assign dec_rounded_value = flag_accumulator_negative ?
		-$signed({1'b0, dec_rounded_magnitude}) :
		$signed({1'b0, dec_rounded_magnitude}); // 恢复符号而不对负值产生算术右移偏置

	// 舍入后先比较完整整数，再选择signed 12-bit端点或正常低位
	assign flag_saturation_low = dec_rounded_value < -20'sd2048; // 检测负向超出校准残差可表示范围 @satisfies: ADCN-03
	assign flag_saturation_high = dec_rounded_value > 20'sd2047; // 检测正向超出校准残差可表示范围 @satisfies: ADCN-03
	assign dec_calibrated_value = flag_saturation_high ? CALIBRATED_VALUE_MAX :
		flag_saturation_low ? CALIBRATED_VALUE_MIN : dec_rounded_value[11:0]; // 显式饱和禁止自然截断回绕 @satisfies: ADCN-03

	// 校准结果、资格、版本、原始ADC字段和事务身份按冻结顺序组合成单一载荷
	assign dec_payload_input = {
		dec_calibrated_value,
		i_stage1_calibration_valid,
		flag_saturation_low,
		flag_saturation_high,
		i_config_epoch,
		i_coef_epoch,
		i_stage1_raw,
		i_detect_code,
		i_stage1_code_ext,
		i_stage2_raw,
		i_precision_mode,
		i_frame_id,
		i_sample_index,
		i_color_ir,
		i_frame_type,
		i_amb_code_snapshot,
		i_dc_code_snapshot,
		i_amb_code_epoch,
		i_dc_code_epoch
	};                                      // 只在输入握手沿锁存当前组合结果

	//-------------输出信号连线-------------//
	// 上游ready与下游全部字段均由当前缓存状态和已锁存payload驱动
	assign o_result_ready = i_rstn && i_active_valid && flag_output_buffer_available; // 复位或ACTIVE无效时阻止接收新事务
	// 顶层端口只观察已经锁存的payload，ACTIVE或上游总线变化不能污染旧事务
	assign o_calibrated_valid = calibrated_valid_o; // 桥接单元素缓存的事务所有权
	assign o_calibrated_s1_value = payload_o[C_CALIBRATED_VALUE_LSB +: 12]; // 取出最终signed 12-bit校准值
	assign o_calibration_applied = payload_o[C_CALIBRATION_APPLIED_LSB]; // 取出本笔片外系数资格快照
	assign o_saturation_low = payload_o[C_SATURATION_LOW_LSB]; // 取出负向端点保护诊断
	assign o_saturation_high = payload_o[C_SATURATION_HIGH_LSB]; // 取出正向端点保护诊断
	assign o_config_epoch = payload_o[C_CONFIG_EPOCH_LSB +: C_CONFIG_EPOCH_WIDTH]; // 取出本笔完整配置版本
	assign o_coef_epoch = payload_o[C_COEF_EPOCH_LSB +: C_COEF_EPOCH_WIDTH]; // 取出本笔Stage1系数版本
	assign o_stage1_raw = payload_o[C_STAGE1_RAW_LSB +: 10]; // 取出真正参与乘加的S1物理码
	assign o_detect_code = payload_o[C_DETECT_CODE_LSB +: 9]; // 取出固定黄金9-bit观察码
	assign o_stage1_code_ext = payload_o[C_STAGE1_CODE_EXT_LSB +: 11]; // 取出固定未钳位D1_EXT
	assign o_stage2_raw = payload_o[C_STAGE2_RAW_LSB +: 10]; // 取出后续精细链使用的S2物理码
	assign o_precision_mode = payload_o[C_PRECISION_LSB]; // 取出当前事务精度模式
	assign o_dc_code_epoch = payload_o[C_DC_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解包颜色DC码版本
	assign o_amb_code_epoch = payload_o[C_AMB_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解包AMB码提交代号
	assign o_dc_code_snapshot = payload_o[C_DC_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 解包颜色DC码快照
	assign o_amb_code_snapshot = payload_o[C_AMB_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 解包AMB码快照
	assign o_frame_type = payload_o[C_FRAME_TYPE_LSB +: 2]; // 解包AMB、DCS或NORMAL类别
	assign o_color_ir = payload_o[C_COLOR_LSB]; // 解包红光或红外身份
	assign o_sample_index = payload_o[C_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH]; // 解包样本顺序编号
	assign o_frame_id = payload_o[C_FRAME_ID_LSB +: C_FRAME_ID_WIDTH]; // 解包共享PPG帧号

	//-----------输出信号处理区域-----------//
	// 唯一输入握手沿原子替换完整payload，反压或空闲期间保持旧载荷
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			payload_o <= {C_PAYLOAD_WIDTH{1'b0}}; // 复位清除全部不可用结果和元数据
		end else if(flag_input_transfer == 1'b1)begin
			payload_o <= dec_payload_input; // 同拍锁存算术结果、配置标签和输入载荷
		end else begin
			payload_o <= payload_o;         // 无新事务时禁止任一输出字段漂移
		end
	end

	// 新输入优先于旧输出消费，保证连续事务同拍替换时valid不产生空拍
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			calibrated_valid_o <= 1'b0;     // 复位期间撤销全部历史事务
		end else if(flag_input_transfer == 1'b1)begin
			calibrated_valid_o <= 1'b1;     // 完整payload已经在本沿写入输出缓存
		end else if(flag_output_transfer == 1'b1)begin
			calibrated_valid_o <= 1'b0;     // 下游消费且无替换输入时释放缓存
		end else begin
			calibrated_valid_o <= calibrated_valid_o; // 空闲或反压期间保持事务所有权
		end
	end

endmodule
