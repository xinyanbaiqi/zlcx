`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/04
// Design Name:        PPG ADC Pipeline Overlap Corrector
// Module Name:        ppg_adc_pipeline_overlap_corrector
// Description:        Description/ppg_adc_pipeline_overlap_corrector_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_adc_pipeline_overlap_corrector
//
// Referrences:        PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md,
//                     PPG_ADC_PIPELINE_OVERLAP_CORRECTOR_NEXT_CHAT_HANDOFF.md,
//                     sar15bit_dual_fft_test Verilog-A checker
//
// Dependencies:       ppg_adc_result_router
//
// Version:            V1.1
// Revision Date:      2026/08/22
// History:
//    Time               Version       Revised by            Contents
// 2026/08/04            V1.0          Erie                  Create file.
// 2026/08/05            V1.0          Erie                  Preserve physical raw codes and clarify S2 qualification.
// 2026/08/06            V1.0          Erie                  Carry calibrated Stage1 payload and version tags.
// 2026/08/22            V1.1          Erie                  Add i_run_generation latch, the AMI private i_datapath_discard_* generation-scoped flush group, o_run_generation and o_local_empty per PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md section 4.1.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月04日
// 设计名称:           PPG ADC两级Pipeline重叠重构器
// 模块名称:           ppg_adc_pipeline_overlap_corrector
// 模块说明:           Description/ppg_adc_pipeline_overlap_corrector_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_adc_pipeline_overlap_corrector
//
// 参考资料:           PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md、
//                     PPG_ADC_PIPELINE_OVERLAP_CORRECTOR_NEXT_CHAT_HANDOFF.md、
//                     sar15bit_dual_fft_test Verilog-A检查器
//
// 依赖文件:           ppg_adc_result_router
//
// 当前版本:           V1.1
// 修订日期:           2026年08月22日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月04日        V1.0          Erie                  创建文件
// 2026年08月05日        V1.0          Erie                  保留两级物理码并明确按精度屏蔽S2
// 2026年08月06日        V1.0          Erie                  原子携带Stage1校准载荷与版本标签
// 2026年08月22日        V1.1          Erie                  按合同4.1节新增i_run_generation锁存、AMI私有i_datapath_discard_*代际清空组，以及o_run_generation/o_local_empty

// 在统一NORMAL事务内保留S1固定黄金码，并为高精度样本生成S1与S2标称重构结果
module ppg_adc_pipeline_overlap_corrector
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16,                         // R/IR共享PPG周期标识字段位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16,                     // 正常ADC结果全局排序字段位宽
	parameter integer C_IDAC_CODE_WIDTH = 32'd8,                         // AMB与当前颜色DC码快照位宽
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4,                         // IDAC安全提交版本标签位宽
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8,                       // ACTIVE配置版本标签位宽
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8,                         // Stage1系数组版本标签位宽
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8                     // manager唯一产生、AMI逐层传入的RUN代际字段位宽
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字处理域工作时钟
	input i_rstn,                           // 低有效异步复位，释放由系统顶层同步

	//---------AMI私有终止释放接口---------//
	input i_datapath_discard_event,        // AMI注册式代际清空事件，无ready/ack
	input [1:0]i_datapath_discard_reason,  // 清空原因分类，取值含STOP排空、abort撤销、系统故障三类
	input i_datapath_discard_identity_valid, // 触发事务身份是否可信
	input [C_FRAME_ID_WIDTH - 1:0]i_datapath_discard_frame_id, // 触发事务帧号，仅诊断用途
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_datapath_discard_sample_index, // 触发事务序号，仅诊断用途
	input i_datapath_discard_color_ir,     // 触发事务颜色，仅诊断用途
	input [1:0]i_datapath_discard_frame_type, // 触发事务类型，仅诊断用途
	input i_datapath_discard_precision,    // 触发事务精度，仅诊断用途
	input [C_RUN_GENERATION_WIDTH - 1:0]i_datapath_discard_run_generation, // 本次清空目标RUN代际

	//----------NORMAL事务输入接口----------//
	input i_normal_valid,                   // router保持完整NORMAL载荷有效直到ready
	input signed [11:0]i_calibrated_s1_value, // Stage1可编程校准器生成的正式signed结果
	input i_calibration_applied,            // 当前事务是否使用合法校准系数
	input i_saturation_low,                 // Stage1校准结果负向饱和标志
	input i_saturation_high,                // Stage1校准结果正向饱和标志
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 当前事务绑定的ACTIVE配置版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 当前事务绑定的Stage1系数组版本
	input [8:0]i_detect_code,               // 黄金比较、范围观察和标称表征使用的固定S1码
	input [9:0]i_stage1_raw,                // 与固定D1_EXT对齐的完整S1物理决策位
	input signed [10:0]i_stage1_code_ext,   // S1黄金公式生成的未钳位D1_EXT
	input [9:0]i_stage2_raw,                // 仅高精度事务具有意义的S2物理码
	input i_precision_mode,                 // 低为9-bit事务，高为15-bit事务
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id, // 同一PPG周期的红光与红外共享标识
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 当前ADC结果在输出流中的顺序编号
	input i_color_ir,                       // 低表示红光，高表示红外光
	input [1:0]i_frame_type,                // router透传的事务类别，NORMAL应为2'b10
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // 本次积分实际使用的AMB抵消码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 本次颜色实际使用的DC抵消码
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // AMB码安全提交后的版本标签
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // 当前颜色DC码对应的版本标签
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // router经本笔事务原样透传的当前RUN代际
	output o_normal_ready,                  // 单元素输出缓存允许接收当前NORMAL事务

	//----------统一结果输出接口----------//
	input i_result_ready,                 // 下游允许在当前上升沿消费完整结果事务
	output o_result_valid,                // 输出载荷有效并保持至ready完成消费
	output signed [11:0]o_calibrated_s1_value, // 与NORMAL事务原子对齐的正式Stage1校准结果
	output o_calibration_applied,         // 与校准结果绑定的合法系数资格
	output o_saturation_low,              // 与校准结果绑定的负向饱和诊断
	output o_saturation_high,             // 与校准结果绑定的正向饱和诊断
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch, // 输出事务绑定的ACTIVE配置版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch, // 输出事务绑定的Stage1系数组版本
	output [8:0]o_detect_code,            // 透传固定S1黄金码，不作为正常IDAC主控制量
	output [9:0]o_stage1_raw,             // 逐物理位校准与测试导出使用的S1物理码
	output signed [10:0]o_stage1_code_ext, // 保留供固定标称重构与诊断使用的D1_EXT
	output [9:0]o_stage2_raw,             // 与D2_EXT对齐保留的S2物理决策位
	output signed [10:0]o_stage2_code_ext, // S2物理码按同一冗余公式得到的D2_EXT
	output signed [14:0]o_nominal_15_code, // 设计标称系数重构并饱和后的15-bit码
	output o_nominal_15_valid,            // 当前统一事务携带有效标称15-bit结果的资格
	output o_nominal_saturated,           // 标称舍入结果超出有符号15-bit范围的标志
	output o_precision_mode,              // 与输出载荷原子对齐的精度模式快照
	output [C_FRAME_ID_WIDTH - 1:0]o_frame_id, // 保持R/IR结果配对所需的PPG周期编号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index, // 保持当前结果的全局样本顺序编号
	output o_color_ir,                    // 保持当前事务的红光或红外身份
	output [1:0]o_frame_type,             // 保留NORMAL类别用于协议诊断
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot, // 保持该结果绑定的AMB实际码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot, // 保持该颜色绑定的DC实际码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // 保持AMB调码前后样本区分标签
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch, // 保持当前颜色DC调码版本标签
	output [C_RUN_GENERATION_WIDTH - 1:0]o_run_generation, // 与统一结果原子对齐、随载荷保持到消费或匹配清空的RUN代际

	//-------------本地排空观测接口-------------//
	output o_local_empty                        // 输出缓存无pending事务时为高，唯一消费者AMI
);

	//-------------配置参数区域-------------//
	// 标称重构使用冻结的Q16系数和有符号15-bit输出端点
	localparam integer C_COEF_FRAC_WIDTH = 32'd16; // 两个标称系数的小数位数
	localparam signed [22:0] A1_Q16 = 23'sd3533837; // Stage1输入等效增益53.9220779的Q16值
	localparam signed [22:0] A2_NOM_Q16 = 23'sd54143; // Stage2标称增益0.8261563的Q16值
	localparam [37:0] ROUND_HALF_Q17 = 38'd65536; // Q17对称舍入所需的半LSB偏置
	localparam signed [14:0] NOMINAL_CODE_MAX = 15'sd16383; // 有符号15-bit正向饱和端点
	localparam signed [14:0] NOMINAL_CODE_MIN = 15'sh4000; // 有符号15-bit负向饱和端点-16384
	// 元数据按固定字段位置打包，保证一次写入即可原子替换全部事务身份
	localparam integer C_DC_EPOCH_LSB = 32'd0; // DC版本标签位于元数据最低段
	localparam integer C_AMB_EPOCH_LSB = C_DC_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // AMB版本字段紧随DC版本
	localparam integer C_DC_CODE_LSB = C_AMB_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // 当前颜色DC码位于epoch字段之上
	localparam integer C_AMB_CODE_LSB = C_DC_CODE_LSB + C_IDAC_CODE_WIDTH; // AMB码快照紧邻DC码快照
	localparam integer C_FRAME_TYPE_LSB = C_AMB_CODE_LSB + C_IDAC_CODE_WIDTH; // 帧类别保留两位协议字段
	localparam integer C_COLOR_LSB = C_FRAME_TYPE_LSB + 32'd2; // 颜色标签位于帧类别之上
	localparam integer C_SAMPLE_INDEX_LSB = C_COLOR_LSB + 32'd1; // 样本编号字段位于颜色标签之上
	localparam integer C_FRAME_ID_LSB = C_SAMPLE_INDEX_LSB + C_SAMPLE_INDEX_WIDTH; // 帧号占据元数据最高段
	localparam integer C_METADATA_WIDTH = C_FRAME_ID_LSB + C_FRAME_ID_WIDTH; // 完整事务元数据寄存器位宽
	localparam integer C_COEF_EPOCH_PAYLOAD_LSB = 32'd0; // 系数组版本位于校准载荷最低段
	localparam integer C_CONFIG_EPOCH_PAYLOAD_LSB = C_COEF_EPOCH_PAYLOAD_LSB + C_COEF_EPOCH_WIDTH; // ACTIVE版本紧随系数组版本
	localparam integer C_SATURATION_HIGH_PAYLOAD_LSB = C_CONFIG_EPOCH_PAYLOAD_LSB + C_CONFIG_EPOCH_WIDTH; // 正向饱和标志位于版本字段之上
	localparam integer C_SATURATION_LOW_PAYLOAD_LSB = C_SATURATION_HIGH_PAYLOAD_LSB + 32'd1; // 负向饱和标志紧邻正向诊断
	localparam integer C_CALIBRATION_APPLIED_PAYLOAD_LSB = C_SATURATION_LOW_PAYLOAD_LSB + 32'd1; // 校准资格与两个饱和标志共同保存
	localparam integer C_CALIBRATED_VALUE_PAYLOAD_LSB = C_CALIBRATION_APPLIED_PAYLOAD_LSB + 32'd1; // signed校准值占据载荷最高段
	localparam integer C_CALIBRATION_PAYLOAD_WIDTH = C_CALIBRATED_VALUE_PAYLOAD_LSB + 32'd12; // 完整校准载荷寄存器位宽

	//---------------标志信号---------------//
	// 两个握手事件分别表示输入接纳和输出消费，缓存可用条件支持同拍替换
	wire flag_output_buffer_available;      // 缓存为空或旧事务将在本拍被消费
	wire flag_input_transfer;               // router与本模块真正交付一笔NORMAL事务
	wire flag_output_transfer;              // 下游真正消费当前统一结果事务
	wire flag_discard_apply;                // AMI代际清空事件命中当前持有代际时无条件清空本地pending
	wire flag_accumulator_negative;         // Q17累加结果为负时选择对称负数舍入
	wire flag_nominal_overflow_high;        // 舍入结果超过正向15-bit端点
	wire flag_nominal_overflow_low;         // 舍入结果低于负向15-bit端点
	wire flag_nominal_saturated;            // 任一方向越界时请求饱和保护

	//---------------译码信号---------------//
	// S2译码保持与S1 Verilog-A模型完全相同的位序和冗余偏置
	wire [9:0]dec_stage2_raw_qualified;     // 9-bit事务强制屏蔽无意义S2总线
	wire [9:0]dec_stage2_base_code;         // 不含vdred正负偏置的S2基础码
	wire signed [10:0]dec_stage2_code_ext;  // 冗余解码后的D2_EXT，物理范围-4至515
	wire signed [11:0]dec_stage1_signed;    // D1_EXT减去ADC中点256后的有符号码
	wire signed [11:0]dec_stage2_signed;    // 高精度尾级冗余码相对中点的带符号偏差
	wire signed [12:0]dec_stage1_signed_ext; // Stage1倍增前使用的显式符号扩展值
	wire signed [12:0]dec_stage2_signed_ext; // 尾级补偿乘法输入使用的13-bit符号扩展
	wire signed [12:0]dec_stage1_center_x2; // 精确保留Stage1加0.5后的二倍中心码
	wire signed [12:0]dec_stage2_x2;        // Stage2中心码的二倍整数形式
	wire signed [35:0]dec_stage1_product_q17; // Stage1中心码与A1_Q16的完整乘积
	wire signed [35:0]dec_stage2_product_q17; // 级间重叠修正项乘A2后的完整Q17乘积
	wire signed [36:0]dec_accumulator_q17;  // 两级乘积显式符号扩展后的Q17累加值
	wire [36:0]dec_accumulator_magnitude;   // 对称舍入使用的Q17绝对值
	wire [37:0]dec_rounding_magnitude_biased; // 绝对值增加半LSB后的非负中间量
	wire [20:0]dec_rounded_magnitude;       // 去除17个小数位后的非负整数幅度
	wire signed [21:0]dec_rounded_code;     // 恢复原符号后的对称舍入结果
	wire signed [14:0]dec_saturated_code;   // 限制到-16384至+16383的最终标称码

	//---------------其他信号---------------//
	// 输入元数据只在唯一握手沿进入输出保持寄存器
	wire [C_METADATA_WIDTH - 1:0]metadata_input; // 当前NORMAL载荷的完整数字上下文
	wire [C_CALIBRATION_PAYLOAD_WIDTH - 1:0]calibration_payload_input; // 当前NORMAL事务的校准数值和版本载荷

	//---------------输出信号---------------//
	// 单元素弹性缓存把数值、资格与元数据作为不可拆分载荷保存
	reg [C_CALIBRATION_PAYLOAD_WIDTH - 1:0]calibration_payload_o; // 原子保存校准值、状态和版本标签
	reg [8:0]detect_code_o;                 // 反压期间保持稳定的固定S1黄金结果
	reg [9:0]stage1_raw_o;                  // 保留逐物理位Stage1拟合和固定乘加输入
	reg signed [10:0]stage1_code_ext_o;     // 与检测码同拍保存的未钳位D1_EXT
	reg [9:0]stage2_raw_o;                  // 保留Stage2扩展模型需要的物理判决位
	reg signed [10:0]stage2_code_ext_o;     // 高精度事务保存的D2_EXT诊断结果
	reg signed [14:0]nominal_15_code_o;     // Q16舍入和饱和后的标称精细结果
	reg nominal_saturated_o;                // 当前精细结果曾触发输出端点保护
	reg precision_mode_o;                   // 决定统一事务是否具有fine资格的模式快照
	reg [C_METADATA_WIDTH - 1:0]metadata_o; // 与全部结果字段同步更新的事务身份
	reg result_valid_o;                     // 声明输出缓存拥有一笔尚未消费的事务
	reg [C_RUN_GENERATION_WIDTH - 1:0]run_generation_o; // 当前缓存事务建立时刻锁存的RUN代际

	//-------------其他信号连线-------------//
	// 单元素缓存为空或旧事务本拍消费时允许接纳下一笔输入
	assign flag_output_buffer_available = (result_valid_o == 1'b0) || i_result_ready; // 支持下游消费与上游写入同拍发生
	assign flag_input_transfer = i_normal_valid && o_normal_ready; // 定义唯一NORMAL输入接纳事件
	assign flag_output_transfer = result_valid_o && i_result_ready; // 定义唯一结果输出消费事件
	assign flag_discard_apply = i_datapath_discard_event && (run_generation_o == i_run_generation); // AMI清空事件命中当前持有代际时无条件清除本地pending

	// 只有高精度事务才让S2总线参与冗余译码和后续乘加
	assign dec_stage2_raw_qualified = i_precision_mode ? i_stage2_raw : 10'b0000000000; // 屏蔽粗精度事务的S2残留
	assign dec_stage2_base_code = {1'b0, dec_stage2_raw_qualified[9:4], 3'b000} +
		{7'b0000000, dec_stage2_raw_qualified[2:0]}; // 组合vd8至vd3与vd2至vd0的基础权重
	assign dec_stage2_code_ext = i_precision_mode ?
		($signed({1'b0, dec_stage2_base_code}) +
		(dec_stage2_raw_qualified[3] ? 11'sd4 : -11'sd4)) : 11'sd0; // 实现vdred乘8后减4的冻结公式

	// 两级扩展码减去256形成以ADC中点为零的有符号输入
	assign dec_stage1_signed = $signed({i_stage1_code_ext[10], i_stage1_code_ext}) - 12'sd256; // 保留接口异常范围供饱和测试
	assign dec_stage2_signed = i_precision_mode ?
		($signed({dec_stage2_code_ext[10], dec_stage2_code_ext}) - 12'sd256) : 12'sd0; // 粗精度事务不形成S2中心码
	assign dec_stage1_signed_ext = {dec_stage1_signed[11], dec_stage1_signed}; // 把D1中心码扩展到倍增操作宽度
	assign dec_stage2_signed_ext = {dec_stage2_signed[11], dec_stage2_signed}; // 把D2中心码扩展到公共乘法输入宽度
	assign dec_stage1_center_x2 = (dec_stage1_signed_ext <<< 1) + 13'sd1; // 用2*D1+1无损表达D1+0.5
	assign dec_stage2_x2 = dec_stage2_signed_ext <<< 1; // 用二倍形式匹配Q17统一缩放

	// 13-bit中心码乘23-bit Q16系数得到显式36-bit Q17乘积
	assign dec_stage1_product_q17 = $signed(dec_stage1_center_x2) * $signed(A1_Q16); // 形成占主导权重的Stage1标称项
	assign dec_stage2_product_q17 = $signed(dec_stage2_x2) * $signed(A2_NOM_Q16); // 形成级间重叠修正使用的Stage2项
	assign dec_accumulator_q17 =
		{dec_stage1_product_q17[35], dec_stage1_product_q17} +
		{dec_stage2_product_q17[35], dec_stage2_product_q17}; // 37-bit累加阻止两项相加产生自然溢出

	// 对绝对值增加2^16后右移17位，实现半LSB远离零的正负对称舍入
	assign flag_accumulator_negative = dec_accumulator_q17[36]; // 使用累加器符号位选择舍入方向
	assign dec_accumulator_magnitude = flag_accumulator_negative ?
		((~dec_accumulator_q17) + 37'd1) : dec_accumulator_q17; // 把负数转换为同宽无符号绝对值
	assign dec_rounding_magnitude_biased = {1'b0, dec_accumulator_magnitude} + ROUND_HALF_Q17; // 加入冻结的Q17半LSB
	assign dec_rounded_magnitude = dec_rounding_magnitude_biased[37:C_COEF_FRAC_WIDTH + 1]; // 舍弃倍增形式的17个小数位
	assign dec_rounded_code = flag_accumulator_negative ?
		-$signed({1'b0, dec_rounded_magnitude}) :
		$signed({1'b0, dec_rounded_magnitude}); // 恢复符号且不对负数引入截断偏置

	// 舍入后显式比较端点，禁止依赖截位回绕形成错误的15-bit结果
	assign flag_nominal_overflow_high = dec_rounded_code > 22'sd16383; // 检测正向超出可表示范围
	assign flag_nominal_overflow_low = dec_rounded_code < -22'sd16384; // 检测负向超出可表示范围
	assign flag_nominal_saturated = flag_nominal_overflow_high || flag_nominal_overflow_low; // 汇总两种端点保护条件
	assign dec_saturated_code = flag_nominal_overflow_high ? NOMINAL_CODE_MAX :
		flag_nominal_overflow_low ? NOMINAL_CODE_MIN : dec_rounded_code[14:0]; // 正常区间保留舍入结果低15位

	// 元数据顺序与S1重构器和router共享的字段语义保持一致
	assign metadata_input = {
		i_frame_id,
		i_sample_index,
		i_color_ir,
		i_frame_type,
		i_amb_code_snapshot,
		i_dc_code_snapshot,
		i_amb_code_epoch,
		i_dc_code_epoch
	};                                      // 组合当前待接纳NORMAL事务的身份载荷
	assign calibration_payload_input = {
		i_calibrated_s1_value,
		i_calibration_applied,
		i_saturation_low,
		i_saturation_high,
		i_config_epoch,
		i_coef_epoch
	};                                      // 组合当前待接纳NORMAL事务的校准载荷

	//-------------输出信号连线-------------//
	// 复位期间关闭上游许可，运行期直接反映弹性缓存可写状态
	assign o_normal_ready = i_rstn && flag_output_buffer_available; // 返回router NORMAL分支的唯一反压信号
	assign o_result_valid = result_valid_o; // 桥接统一输出事务的保持型valid
	assign o_calibrated_s1_value = calibration_payload_o[C_CALIBRATED_VALUE_PAYLOAD_LSB +: 12]; // 解包正式Stage1校准结果
	assign o_calibration_applied = calibration_payload_o[C_CALIBRATION_APPLIED_PAYLOAD_LSB]; // 解包校准资格
	assign o_saturation_low = calibration_payload_o[C_SATURATION_LOW_PAYLOAD_LSB]; // 解包负向饱和诊断
	assign o_saturation_high = calibration_payload_o[C_SATURATION_HIGH_PAYLOAD_LSB]; // 解包正向饱和诊断
	assign o_config_epoch = calibration_payload_o[C_CONFIG_EPOCH_PAYLOAD_LSB +: C_CONFIG_EPOCH_WIDTH]; // 解包ACTIVE配置版本
	assign o_coef_epoch = calibration_payload_o[C_COEF_EPOCH_PAYLOAD_LSB +: C_COEF_EPOCH_WIDTH]; // 解包Stage1系数组版本
	assign o_detect_code = detect_code_o;   // 桥接黄金比较和标称表征使用的S1码
	assign o_stage1_raw = stage1_raw_o;     // 桥接完整S1物理位供校准与导出
	assign o_stage1_code_ext = stage1_code_ext_o; // 桥接未钳位第一级扩展结果
	assign o_stage2_raw = stage2_raw_o;     // 桥接与D2_EXT同拍保存的S2物理码
	assign o_stage2_code_ext = stage2_code_ext_o; // 桥接仅高精度有效的第二级扩展结果
	assign o_nominal_15_code = nominal_15_code_o; // 桥接标称两级重构输出码
	assign o_nominal_15_valid = result_valid_o && precision_mode_o; // 资格位绑定统一事务valid和精度快照
	assign o_nominal_saturated = nominal_saturated_o; // 桥接当前高精度事务的饱和诊断
	assign o_precision_mode = precision_mode_o; // 桥接输出载荷所属精度模式
	assign o_dc_code_epoch = metadata_o[C_DC_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解包当前颜色DC版本标签
	assign o_amb_code_epoch = metadata_o[C_AMB_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解包AMB安全提交代号
	assign o_dc_code_snapshot = metadata_o[C_DC_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 解包本次颜色实际DC码
	assign o_amb_code_snapshot = metadata_o[C_AMB_CODE_LSB +: C_IDAC_CODE_WIDTH]; // 解包本次积分AMB码
	assign o_frame_type = metadata_o[C_FRAME_TYPE_LSB +: 2]; // 解包router保留的NORMAL类别
	assign o_color_ir = metadata_o[C_COLOR_LSB]; // 解包红光或红外事务身份
	assign o_sample_index = metadata_o[C_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH]; // 解包全局结果顺序编号
	assign o_frame_id = metadata_o[C_FRAME_ID_LSB +: C_FRAME_ID_WIDTH]; // 解包R/IR共享PPG周期标识
	assign o_run_generation = run_generation_o; // 桥接与统一结果原子对齐的保持型RUN代际
	assign o_local_empty = !result_valid_o; // 输出缓存无pending事务时报告本地排空

	//-----------输出信号处理区域-----------//
	// 校准结果及其资格、饱和状态、版本标签必须在同一输入握手沿原子锁存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			calibration_payload_o <= {C_CALIBRATION_PAYLOAD_WIDTH{1'b0}}; // 复位清除全部校准事务历史
		end else if(flag_input_transfer == 1'b1)begin
			calibration_payload_o <= calibration_payload_input; // 输入握手时原子替换全部校准字段
		end else begin
			calibration_payload_o <= calibration_payload_o; // 反压或空闲期间保持完整校准载荷
		end
	end

	// 唯一输入握手沿更新固定S1黄金码，反压期间不重新观察router组合总线
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			detect_code_o <= 9'd0;          // 数字复位移除历史固定S1黄金结果
		end else if(flag_input_transfer == 1'b1)begin
			detect_code_o <= i_detect_code; // 原子保存当前NORMAL事务固定S1黄金码
		end else begin
			detect_code_o <= detect_code_o; // 无新事务时保持黄金观察载荷稳定
		end
	end

	// S1物理判决位与固定检测码在同一输入握手沿进入输出缓存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stage1_raw_o <= 10'b0000000000; // 复位移除不可用的S1物理码历史
		end else if(flag_input_transfer == 1'b1)begin
			stage1_raw_o <= i_stage1_raw;   // 保存逐物理位绝对权重模型的输入基项
		end else begin
			stage1_raw_o <= stage1_raw_o;   // 下游反压期间维持S1原始载荷
		end
	end

	// 未钳位D1_EXT与同一事务的检测码同步进入输出缓存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stage1_code_ext_o <= 11'sd0;    // 复位清除第一级扩展诊断值
		end else if(flag_input_transfer == 1'b1)begin
			stage1_code_ext_o <= i_stage1_code_ext; // 保存精细重构真正使用的S1输入
		end else begin
			stage1_code_ext_o <= stage1_code_ext_o; // 输出等待期间禁止D1_EXT漂移
		end
	end

	// 仅15-bit事务保留S2物理决策位，粗精度事务明确输出零
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stage2_raw_o <= 10'b0000000000; // 复位清除不可用的S2物理决策历史
		end else if(flag_input_transfer == 1'b1)begin
			if(i_precision_mode == 1'b1)begin
				stage2_raw_o <= i_stage2_raw; // 高精度事务保存完整S2物理码
			end else begin
				stage2_raw_o <= 10'b0000000000; // 粗精度事务明确屏蔽S2残留
			end
		end else begin
			stage2_raw_o <= stage2_raw_o;   // 输出未消费时保持S2原始载荷稳定
		end
	end

	// 仅15-bit事务保存D2_EXT，粗精度事务明确输出零避免伪数据
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			stage2_code_ext_o <= 11'sd0;    // 复位移除历史第二级译码结果
		end else if(flag_input_transfer == 1'b1)begin
			stage2_code_ext_o <= i_precision_mode ? dec_stage2_code_ext : 11'sd0; // 按事务资格锁存或清零S2
		end else begin
			stage2_code_ext_o <= stage2_code_ext_o; // 反压时保持当前D2_EXT不变
		end
	end

	// 高精度事务锁存Q16标称码，9-bit事务统一把精细数据字段置零
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			nominal_15_code_o <= 15'sd0;    // 复位清除不可用精细重构码
		end else if(flag_input_transfer == 1'b1)begin
			nominal_15_code_o <= i_precision_mode ? dec_saturated_code : 15'sd0; // 只为有效S2事务保存标称值
		end else begin
			nominal_15_code_o <= nominal_15_code_o; // 下游阻塞期间保持结果位完全稳定
		end
	end

	// 饱和标志只描述当前有效15-bit事务，粗精度载荷固定报告未饱和
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			nominal_saturated_o <= 1'b0;    // 复位期间不存在端点保护事件
		end else if(flag_input_transfer == 1'b1)begin
			nominal_saturated_o <= i_precision_mode ? flag_nominal_saturated : 1'b0; // 保存本笔精细结果越界状态
		end else begin
			nominal_saturated_o <= nominal_saturated_o; // 事务未消费时保持诊断属性
		end
	end

	// 精度快照决定同一输出事务内部fine字段是否具有解释资格
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			precision_mode_o <= 1'b0;       // 复位默认采用9-bit事务解释
		end else if(flag_input_transfer == 1'b1)begin
			precision_mode_o <= i_precision_mode; // 原子锁存router提供的精度属性
		end else begin
			precision_mode_o <= precision_mode_o; // 后续模式切换不得重解释旧结果
		end
	end

	// 全部颜色、帧号、样本号和IDAC快照通过一个寄存目标同步替换
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			metadata_o <= {C_METADATA_WIDTH{1'b0}}; // 复位清空输出事务身份字段
		end else if(flag_input_transfer == 1'b1)begin
			metadata_o <= metadata_input;   // 把当前NORMAL上下文绑定到重构结果
		end else begin
			metadata_o <= metadata_o;       // 反压阶段维持R/IR与码快照对齐
		end
	end

	// 新输入优先于同拍旧输出消费，连续事务替换时valid保持为高
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			result_valid_o <= 1'b0;         // 复位后不得报告虚假统一事务
		end else if(flag_input_transfer == 1'b1)begin
			result_valid_o <= 1'b1;         // 数值、资格和元数据已完整装入缓存
		end else if(flag_output_transfer == 1'b1 || flag_discard_apply == 1'b1)begin
			result_valid_o <= 1'b0;         // 下游消费或被AMI代际清空后释放缓存
		end else begin
			result_valid_o <= result_valid_o; // 空闲或反压期间保持当前所有权
		end
	end

	// 唯一输入握手沿原子锁存本笔事务所属的RUN代际，供代际清空匹配判断使用
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 复位清除历史代际快照
		end else if(flag_input_transfer == 1'b1)begin
			run_generation_o <= i_run_generation; // 新事务装入时锁存router透传的当前RUN代际
		end else begin
			run_generation_o <= run_generation_o; // 无新事务时保持已锁存代际
		end
	end

endmodule
