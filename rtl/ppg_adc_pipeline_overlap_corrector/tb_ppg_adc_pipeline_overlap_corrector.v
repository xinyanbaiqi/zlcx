`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/04
// Design Name:        PPG ADC Pipeline Overlap Corrector Testbench
// Module Name:        tb_ppg_adc_pipeline_overlap_corrector
// Description:        TestBench/Vivado/2022.2/ppg_adc_pipeline_overlap_corrector
// Simulations:        Vivado xsim 2022.2
//
// Referrences:        PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md,
//                     PPG_ADC_PIPELINE_OVERLAP_CORRECTOR_NEXT_CHAT_HANDOFF.md,
//                     ppg_adc_pipeline_overlap_corrector.v
//
// Dependencies:       ppg_adc_pipeline_overlap_corrector
//
// Version:            V1.0
// Revision Date:      2026/08/06
// History:
//    Time               Version       Revised by            Contents
// 2026/08/04            V1.0          Erie                  Create file.
// 2026/08/05            V1.0          Erie                  Verify aligned S1/S2 raw-code preservation.
// 2026/08/06            V1.0          Erie                  Verify calibrated payload and epoch alignment.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月04日
// 设计名称:           PPG ADC两级Pipeline重叠重构器测试平台
// 模块名称:           tb_ppg_adc_pipeline_overlap_corrector
// 模块说明:           TestBench/Vivado/2022.2/ppg_adc_pipeline_overlap_corrector
// 仿真工程:           Vivado xsim 2022.2
//
// 参考资料:           PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md、
//                     PPG_ADC_PIPELINE_OVERLAP_CORRECTOR_NEXT_CHAT_HANDOFF.md、
//                     ppg_adc_pipeline_overlap_corrector.v
//
// 依赖文件:           ppg_adc_pipeline_overlap_corrector
//
// 当前版本:           V1.0
// 修订日期:           2026年08月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月04日        V1.0          Erie                  创建文件
// 2026年08月05日        V1.0          Erie                  补充两级物理码对齐与保持检查
// 2026年08月06日        V1.0          Erie                  验证校准载荷与版本标签原子对齐

// 使用独立64-bit整数黄金模型验证S2逐码译码、Q16重构、事务保持和同拍替换
module tb_ppg_adc_pipeline_overlap_corrector();

	//-------------配置参数区域-------------//
	// 2 MHz测试时钟与DUT默认元数据位宽保持一致
	localparam integer C_CLK_PERIOD = 32'd500; // 一个数字处理周期为500 ns
	localparam integer C_FRAME_ID_WIDTH = 32'd16; // 测试帧号字段采用16 bit
	localparam integer C_SAMPLE_INDEX_WIDTH = 32'd16; // 测试样本号字段采用16 bit
	localparam integer C_IDAC_CODE_WIDTH = 32'd8; // 测试IDAC码快照采用8 bit
	localparam integer C_CODE_EPOCH_WIDTH = 32'd4; // 测试IDAC版本标签采用4 bit
	localparam integer C_CONFIG_EPOCH_WIDTH = 32'd8; // 测试ACTIVE配置版本采用8 bit
	localparam integer C_COEF_EPOCH_WIDTH = 32'd8; // 测试Stage1系数组版本采用8 bit

	//---------------计数信号---------------//
	// 全部PASS判断由真实比较累计的错误数决定
	integer cnt_error;                      // 记录所有定向和遍历用例失败数量
	integer cnt_raw_code;                   // 遍历1024个S2物理码的循环索引
	integer cnt_idle_cycle;                 // 空闲总线扰动检查的循环索引
	integer cnt_clock_toggle;               // 覆盖watchdog窗口的测试时钟翻转索引
	integer reg_cross_d1_value;             // 逐码交叉测试使用的确定性D1_EXT值

	//--------------寄存器信号--------------//
	// 测试平台驱动router NORMAL分支的完整保持型载荷
	reg i_clk;                              // 产生2 MHz同步事务观察边沿
	reg i_rstn;                             // 驱动DUT低有效异步复位
	reg i_normal_valid;                     // 声明输入总线当前包含有效NORMAL事务
	reg signed [11:0]i_calibrated_s1_value; // 驱动Stage1可编程校准结果
	reg i_calibration_applied;              // 驱动合法校准系数资格
	reg i_saturation_low;                   // 驱动Stage1负向饱和诊断
	reg i_saturation_high;                  // 驱动Stage1正向饱和诊断
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch; // 驱动ACTIVE配置版本
	reg [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch; // 驱动Stage1系数组版本
	reg [8:0]i_detect_code;                 // 驱动黄金比较与标称表征使用的固定S1码
	reg [9:0]i_stage1_raw;                  // 驱动与D1_EXT对齐的S1物理决策码
	reg signed [10:0]i_stage1_code_ext;     // 驱动未钳位D1_EXT重构输入
	reg [9:0]i_stage2_raw;                  // 驱动S2物理10-bit决策码
	reg i_precision_mode;                   // 驱动当前事务9-bit或15-bit资格
	reg [C_FRAME_ID_WIDTH - 1:0]i_frame_id; // 驱动R/IR共享PPG周期编号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index; // 驱动全局ADC结果序号
	reg i_color_ir;                         // 驱动红光或红外事务标签
	reg [1:0]i_frame_type;                  // NORMAL分支固定使用2'b10
	reg [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot; // 驱动本次积分使用的AMB码
	reg [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot; // 驱动当前颜色使用的DC码
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch; // 驱动AMB安全提交版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch; // 驱动当前颜色DC版本
	reg i_result_ready;                     // 控制下游消费或反压统一结果事务
	reg [7:0]reg_test_case_id;              // 在WDB中标识OVL-01至OVL-16阶段

	// 反压和空闲场景保存参考载荷，检查输入变化不会污染输出缓存
	reg signed [11:0]reg_hold_calibrated_s1_value; // 保存反压开始时的Stage1校准值
	reg reg_hold_calibration_applied;       // 保存反压事务的校准资格
	reg reg_hold_saturation_low;            // 保存反压事务的负向饱和标志
	reg reg_hold_saturation_high;           // 保存反压事务的正向饱和标志
	reg [C_CONFIG_EPOCH_WIDTH - 1:0]reg_hold_config_epoch; // 保存反压事务的ACTIVE版本
	reg [C_COEF_EPOCH_WIDTH - 1:0]reg_hold_coef_epoch; // 保存反压事务的系数组版本
	reg [8:0]reg_hold_detect_code;          // 保存反压开始时的S1检测码
	reg [9:0]reg_hold_stage1_raw;           // 保存反压开始时的S1物理决策码
	reg signed [10:0]reg_hold_stage1_code_ext; // 保存反压开始时的D1_EXT
	reg [9:0]reg_hold_stage2_raw;           // 保存反压开始时的S2物理决策码
	reg signed [10:0]reg_hold_stage2_code_ext; // 保存反压开始时的D2_EXT
	reg signed [14:0]reg_hold_nominal_15_code; // 保存反压开始时的标称15-bit码
	reg reg_hold_nominal_15_valid;          // 保存反压事务的fine资格
	reg reg_hold_nominal_saturated;         // 保存反压事务的饱和诊断
	reg reg_hold_precision_mode;            // 保存反压事务的精度快照
	reg [C_FRAME_ID_WIDTH - 1:0]reg_hold_frame_id; // 保存反压事务的帧身份
	reg [C_SAMPLE_INDEX_WIDTH - 1:0]reg_hold_sample_index; // 保存反压事务的样本编号
	reg reg_hold_color_ir;                  // 保存反压事务的颜色标签
	reg [1:0]reg_hold_frame_type;           // 保存反压事务的NORMAL类别字段
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_hold_amb_code_snapshot; // 保存反压事务的AMB码快照
	reg [C_IDAC_CODE_WIDTH - 1:0]reg_hold_dc_code_snapshot; // 保存反压事务的DC码快照
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_hold_amb_code_epoch; // 保存反压事务的AMB码版本
	reg [C_CODE_EPOCH_WIDTH - 1:0]reg_hold_dc_code_epoch; // 保存反压事务的DC码版本

	//---------------标志信号---------------//
	// 两个观察标志对应DUT定义的唯一输入与输出握手事件
	wire flag_input_transfer;               // 当前上升沿接收一笔NORMAL事务
	wire flag_output_transfer;              // 当前上升沿消费一笔统一结果事务

	//---------------输出信号---------------//
	// 观察DUT弹性缓存、数值结果、fine资格和全部元数据
	wire o_normal_ready;                    // DUT返回router的NORMAL分支ready
	wire o_result_valid;                    // DUT保持型统一输出valid
	wire signed [11:0]o_calibrated_s1_value; // 输出保持型事务中的Stage1校准值
	wire o_calibration_applied;             // 输出与校准值绑定的资格
	wire o_saturation_low;                  // 输出Stage1负向饱和诊断
	wire o_saturation_high;                 // 输出Stage1正向饱和诊断
	wire [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch; // 输出绑定的ACTIVE版本
	wire [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch; // 输出绑定的Stage1系数组版本
	wire [8:0]o_detect_code;                // 输出保持型事务中的固定S1黄金码
	wire [9:0]o_stage1_raw;                 // 输出与D1_EXT同事务的S1物理决策码
	wire signed [10:0]o_stage1_code_ext;    // 输出未钳位D1_EXT
	wire [9:0]o_stage2_raw;                 // 输出按精度资格保存或屏蔽的S2物理码
	wire signed [10:0]o_stage2_code_ext;    // 输出冗余解码后的D2_EXT
	wire signed [14:0]o_nominal_15_code;    // 输出舍入饱和后的标称15-bit码
	wire o_nominal_15_valid;                // 输出当前事务fine资格
	wire o_nominal_saturated;               // 输出15-bit端点保护标志
	wire o_precision_mode;                  // 输出事务精度快照
	wire [C_FRAME_ID_WIDTH - 1:0]o_frame_id; // 输出R/IR共享帧号
	wire [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index; // 输出结果顺序编号
	wire o_color_ir;                        // 输出红光或红外身份
	wire [1:0]o_frame_type;                 // 输出透传NORMAL类别
	wire [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot; // 输出绑定的AMB码快照
	wire [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot; // 输出绑定的当前颜色DC码
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch; // 输出绑定的AMB版本
	wire [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch; // 输出绑定的DC版本

	//-------------其他信号连线-------------//
	// 波形观察事件与DUT的ready/valid定义完全一致
	assign flag_input_transfer = i_normal_valid && o_normal_ready; // 标记输入事务真正被缓存接纳
	assign flag_output_transfer = o_result_valid && i_result_ready; // 标记输出事务真正被下游消费

	//-----------主要任务处理区域-----------//
	// 独立黄金函数逐位复现Verilog-A的S2冗余译码公式
	function signed [10:0]golden_decode_stage2;
		input [9:0]raw_code;                // 按vd8至vd3、vdred、vd2至vd0解释物理码
		integer decode_value;               // 使用32-bit整数承载-4至515译码范围
		begin
			decode_value =
				(raw_code[9] ? 32'd256 : 32'd0) +
				(raw_code[8] ? 32'd128 : 32'd0) +
				(raw_code[7] ? 32'd64 : 32'd0) +
				(raw_code[6] ? 32'd32 : 32'd0) +
				(raw_code[5] ? 32'd16 : 32'd0) +
				(raw_code[4] ? 32'd8 : 32'd0) +
				(raw_code[3] ? 32'd8 : 32'd0) - 32'd4 +
				(raw_code[2] ? 32'd4 : 32'd0) +
				(raw_code[1] ? 32'd2 : 32'd0) +
				(raw_code[0] ? 32'd1 : 32'd0); // 汇总十个物理决策位的冻结权重
			golden_decode_stage2 = decode_value; // 返回可直接比较的11-bit有符号D2_EXT
		end
	endfunction

	// 64-bit黄金函数复现倍增形式Q16乘加和正负对称舍入
	function signed [21:0]golden_rounded_code;
		input signed [10:0]stage1_code_ext; // 输入当前事务未钳位D1_EXT
		input [9:0]stage2_raw;              // 输入当前事务S2物理决策码
		reg signed [63:0]stage1_signed;     // 黄金模型D1中心码
		reg signed [63:0]stage2_signed;     // 黄金模型D2中心码
		reg signed [63:0]accumulator_q17;   // 黄金模型两项Q17累加结果
		reg signed [63:0]accumulator_magnitude; // 黄金模型对称舍入绝对值
		begin
			stage1_signed = stage1_code_ext - 64'sd256; // 把D1_EXT转换为以中点为零
			stage2_signed = golden_decode_stage2(stage2_raw) - 64'sd256; // 把D2_EXT转换为以中点为零
			accumulator_q17 = ((stage1_signed * 64'sd2) + 64'sd1) * 64'sd3533837 +
				(stage2_signed * 64'sd2) * 64'sd54143; // 使用冻结Q16系数组合两级中心码
			if(accumulator_q17 < 64'sd0)begin
				accumulator_magnitude = -accumulator_q17; // 负数先取幅度以避免算术右移偏置
				golden_rounded_code = -((accumulator_magnitude + 64'sd65536) >>> 17); // 半LSB时向远离零方向舍入
			end else begin
				accumulator_magnitude = accumulator_q17; // 正数幅度等于原Q17累加结果
				golden_rounded_code = (accumulator_magnitude + 64'sd65536) >>> 17; // 正向采用同一半LSB门限
			end
		end
	endfunction

	// 输出黄金函数把舍入整数限制到有符号15-bit端点
	function signed [14:0]golden_saturated_code;
		input signed [10:0]stage1_code_ext; // 输入待验证的D1_EXT
		input [9:0]stage2_raw;              // 输入待验证的S2物理码
		reg signed [21:0]rounded_code;      // 保存黄金模型未饱和舍入结果
		begin
			rounded_code = golden_rounded_code(stage1_code_ext, stage2_raw); // 先执行统一Q16舍入模型
			if(rounded_code > 22'sd16383)begin
				golden_saturated_code = 15'sd16383; // 正向越界钳位到最大正码
			end else if(rounded_code < -22'sd16384)begin
				golden_saturated_code = 15'sh4000; // 负向越界钳位到-16384
			end else begin
				golden_saturated_code = rounded_code[14:0]; // 合法范围保留低15位补码
			end
		end
	endfunction

	// 饱和黄金函数独立判断未截断舍入结果是否超过任一端点
	function golden_saturation_flag;
		input signed [10:0]stage1_code_ext; // 输入待判断的D1_EXT
		input [9:0]stage2_raw;              // 输入待判断的S2物理码
		reg signed [21:0]rounded_code;      // 保存端点比较前的完整舍入结果
		begin
			rounded_code = golden_rounded_code(stage1_code_ext, stage2_raw); // 取得未饱和标称整数
			golden_saturation_flag = (rounded_code > 22'sd16383) ||
				(rounded_code < -22'sd16384); // 任一方向越界均置位诊断
		end
	endfunction

	// 统一载荷驱动任务减少各定向场景重复赋值并保持元数据差异可见
	task drive_payload;
		input precision_mode;               // 指定该事务粗精度或高精度
		input signed [10:0]stage1_code_ext; // 指定该事务D1_EXT
		input [9:0]stage2_raw;              // 指定该事务S2物理码
		input [8:0]detect_code;             // 指定随事务透传的固定S1黄金码
		input [15:0]frame_id;               // 指定R/IR共享PPG周期编号
		input [15:0]sample_index;           // 指定输出流样本序号
		input color_ir;                     // 指定红光零或红外一
		input [7:0]amb_code;                // 指定本次AMB实际码快照
		input [7:0]dc_code;                 // 指定本次颜色DC实际码
		input [3:0]amb_epoch;               // 指定AMB码提交版本
		input [3:0]dc_epoch;                // 指定当前颜色DC版本
		begin
			i_precision_mode = precision_mode; // 驱动事务精度资格
			i_calibrated_s1_value = $signed({stage1_code_ext[10], stage1_code_ext}); // 生成可追踪的signed校准值
			i_calibration_applied = sample_index[0]; // 交错覆盖校准资格零和一
			i_saturation_low = (stage1_code_ext == 11'sh400); // 用负向异常端点产生独立诊断
			i_saturation_high = (stage1_code_ext == 11'sd1023); // 用正向异常端点产生独立诊断
			i_config_epoch = frame_id[7:0]; // 从帧号生成可核对的ACTIVE版本
			i_coef_epoch = sample_index[7:0] ^ 8'ha5; // 从样本号生成不同的系数组版本
			i_stage1_raw = {stage1_code_ext[4:0], stage2_raw[4:0]}; // 构造独立可追踪的S1物理位载荷
			i_stage1_code_ext = stage1_code_ext; // 驱动精细重构使用的D1_EXT
			i_stage2_raw = stage2_raw;      // 驱动第二级物理决策码
			i_detect_code = detect_code;    // 驱动始终保留的黄金比较结果
			i_frame_id = frame_id;          // 驱动当前PPG周期身份
			i_sample_index = sample_index;  // 驱动当前事务排序标签
			i_color_ir = color_ir;          // 驱动颜色状态标识
			i_frame_type = 2'b10;           // 所有DUT输入均来自router NORMAL分支
			i_amb_code_snapshot = amb_code; // 驱动环境光抵消码快照
			i_dc_code_snapshot = dc_code;   // 驱动颜色相关直流码快照
			i_amb_code_epoch = amb_epoch;   // 驱动AMB安全提交代号
			i_dc_code_epoch = dc_epoch;     // 驱动DC码版本标签
		end
	endtask

	// 每笔正常事务均核对握手结果、数值字段、fine资格和完整元数据
	task check_output_transaction;
		input precision_mode;               // 指定预期输出精度资格
		input signed [10:0]stage1_code_ext; // 指定预期D1_EXT
		input [9:0]stage2_raw;              // 指定黄金S2译码输入
		input [8:0]detect_code;             // 指定预期S1检测码
		input [15:0]frame_id;               // 指定预期PPG周期编号
		input [15:0]sample_index;           // 指定预期样本顺序号
		input color_ir;                     // 指定预期颜色身份
		input [7:0]amb_code;                // 指定预期AMB码快照
		input [7:0]dc_code;                 // 指定预期DC码快照
		input [3:0]amb_epoch;               // 指定预期AMB版本
		input [3:0]dc_epoch;                // 指定预期DC版本
		reg signed [10:0]expected_stage2_code_ext; // 保存黄金模型D2_EXT
		reg signed [14:0]expected_nominal_code; // 保存黄金模型饱和标称码
		reg expected_saturation;            // 保存黄金模型端点保护状态
		reg signed [11:0]expected_calibrated_s1_value; // 保存预期Stage1校准透传值
		reg expected_calibration_applied;   // 保存预期校准资格
		reg expected_saturation_low;        // 保存预期负向饱和诊断
		reg expected_saturation_high;       // 保存预期正向饱和诊断
		reg [7:0]expected_config_epoch;     // 保存预期ACTIVE版本
		reg [7:0]expected_coef_epoch;       // 保存预期Stage1系数组版本
		reg [9:0]expected_stage1_raw;       // 保存任务按同一规则构造的S1物理码
		reg [9:0]expected_stage2_raw;       // 保存按精度资格屏蔽后的S2物理码
		begin
			expected_calibrated_s1_value = $signed({stage1_code_ext[10], stage1_code_ext}); // 复现驱动任务的signed校准值
			expected_calibration_applied = sample_index[0]; // 复现交错校准资格
			expected_saturation_low = (stage1_code_ext == 11'sh400); // 复现负向诊断条件
			expected_saturation_high = (stage1_code_ext == 11'sd1023); // 复现正向诊断条件
			expected_config_epoch = frame_id[7:0]; // 复现ACTIVE版本生成规则
			expected_coef_epoch = sample_index[7:0] ^ 8'ha5; // 复现系数组版本生成规则
			expected_stage1_raw = {stage1_code_ext[4:0], stage2_raw[4:0]}; // 与驱动任务生成的S1载荷保持一致
			expected_stage2_raw = precision_mode ? stage2_raw : 10'b0000000000; // 9-bit事务不得输出历史S2码
			expected_stage2_code_ext = precision_mode ? golden_decode_stage2(stage2_raw) : 11'sd0; // 粗精度期望S2为零
			expected_nominal_code = precision_mode ? golden_saturated_code(stage1_code_ext, stage2_raw) : 15'sd0; // 粗精度不产生标称码
			expected_saturation = precision_mode ? golden_saturation_flag(stage1_code_ext, stage2_raw) : 1'b0; // 粗精度不报告饱和
			if((o_result_valid !== 1'b1) || (o_calibrated_s1_value !== expected_calibrated_s1_value) || (o_calibration_applied !== expected_calibration_applied) || (o_saturation_low !== expected_saturation_low) || (o_saturation_high !== expected_saturation_high) || (o_config_epoch !== expected_config_epoch) || (o_coef_epoch !== expected_coef_epoch) || (o_detect_code !== detect_code) || (o_stage1_raw !== expected_stage1_raw) || (o_stage1_code_ext !== stage1_code_ext) || (o_stage2_raw !== expected_stage2_raw) || (o_stage2_code_ext !== expected_stage2_code_ext) || (o_nominal_15_code !== expected_nominal_code) || (o_nominal_15_valid !== precision_mode) || (o_nominal_saturated !== expected_saturation) || (o_precision_mode !== precision_mode) || (o_frame_id !== frame_id) || (o_sample_index !== sample_index) || (o_color_ir !== color_ir) || (o_frame_type !== 2'b10) || (o_amb_code_snapshot !== amb_code) || (o_dc_code_snapshot !== dc_code) || (o_amb_code_epoch !== amb_epoch) || (o_dc_code_epoch !== dc_epoch))begin
				cnt_error = cnt_error + 1;  // 任一事务字段错误都阻止最终PASS
				$display("FAIL OVL-%0d sample=%0d precision=%b d1=%0d raw=%h got_d2=%0d exp_d2=%0d got_nom=%0d exp_nom=%0d sat=%b exp_sat=%b", reg_test_case_id, sample_index, precision_mode, stage1_code_ext, stage2_raw, o_stage2_code_ext, expected_stage2_code_ext, o_nominal_15_code, expected_nominal_code, o_nominal_saturated, expected_saturation); // 输出足够信息定位数值或对齐错误
			end
		end
	endtask

	// 反压稳定性任务逐拍核对ready和完整缓存快照，防止载荷或元数据错拍
	task check_held_output;
		begin
			if((o_normal_ready !== 1'b0) || (o_result_valid !== 1'b1) || (o_calibrated_s1_value !== reg_hold_calibrated_s1_value) || (o_calibration_applied !== reg_hold_calibration_applied) || (o_saturation_low !== reg_hold_saturation_low) || (o_saturation_high !== reg_hold_saturation_high) || (o_config_epoch !== reg_hold_config_epoch) || (o_coef_epoch !== reg_hold_coef_epoch) || (o_detect_code !== reg_hold_detect_code) || (o_stage1_raw !== reg_hold_stage1_raw) || (o_stage1_code_ext !== reg_hold_stage1_code_ext) || (o_stage2_raw !== reg_hold_stage2_raw) || (o_stage2_code_ext !== reg_hold_stage2_code_ext) || (o_nominal_15_code !== reg_hold_nominal_15_code) || (o_nominal_15_valid !== reg_hold_nominal_15_valid) || (o_nominal_saturated !== reg_hold_nominal_saturated) || (o_precision_mode !== reg_hold_precision_mode) || (o_frame_id !== reg_hold_frame_id) || (o_sample_index !== reg_hold_sample_index) || (o_color_ir !== reg_hold_color_ir) || (o_frame_type !== reg_hold_frame_type) || (o_amb_code_snapshot !== reg_hold_amb_code_snapshot) || (o_dc_code_snapshot !== reg_hold_dc_code_snapshot) || (o_amb_code_epoch !== reg_hold_amb_code_epoch) || (o_dc_code_epoch !== reg_hold_dc_code_epoch))begin
				cnt_error = cnt_error + 1;  // 记录反压期间任一载荷位发生变化
				$display("FAIL OVL-%0d backpressure ready or payload changed", reg_test_case_id); // 报告反压握手或事务保持合同被破坏
			end
		end
	endtask

	//-----------主要任务处理区域-----------//
	// 固定周期时钟组织同步握手并提供清晰的2 MHz波形刻度
	initial begin
		i_clk = 1'b0;                       // 从低电平建立唯一2 MHz测试时钟驱动
		for(cnt_clock_toggle = 0; cnt_clock_toggle < 8000; cnt_clock_toggle = cnt_clock_toggle + 1)begin
			#250 i_clk = ~i_clk;            // 每250 ns翻转并覆盖完整watchdog窗口
		end
	end

	// 依次执行交付文件OVL-01至OVL-17及1024码确定性交叉比较
	initial begin
		i_rstn = 1'b0;                      // 初始异步复位清空弹性缓存
		i_normal_valid = 1'b0;              // 复位期间不提交NORMAL事务
		i_calibrated_s1_value = 12'sd0;     // 清除初始Stage1校准值
		i_calibration_applied = 1'b0;       // 清除初始校准资格
		i_saturation_low = 1'b0;            // 清除初始负向饱和诊断
		i_saturation_high = 1'b0;           // 清除初始正向饱和诊断
		i_config_epoch = 8'd0;              // 清除初始ACTIVE版本
		i_coef_epoch = 8'd0;                // 清除初始系数组版本
		i_detect_code = 9'd0;               // 清除初始S1检测输入
		i_stage1_raw = 10'd0;               // 清除初始S1物理码输入
		i_stage1_code_ext = 11'sd0;         // 清除初始D1_EXT输入
		i_stage2_raw = 10'd0;               // 清除初始S2物理码
		i_precision_mode = 1'b0;            // 初始载荷采用9-bit资格
		i_frame_id = 16'd0;                 // 清除初始帧身份
		i_sample_index = 16'd0;             // 清除初始样本编号
		i_color_ir = 1'b0;                  // 初始颜色选择红光
		i_frame_type = 2'b10;               // DUT只接收NORMAL类别
		i_amb_code_snapshot = 8'd0;         // 清除初始AMB码快照
		i_dc_code_snapshot = 8'd0;          // 清除初始DC码快照
		i_amb_code_epoch = 4'd0;            // 清除初始AMB版本
		i_dc_code_epoch = 4'd0;             // 清除初始DC版本
		i_result_ready = 1'b0;              // 复位阶段关闭下游消费
		reg_test_case_id = 8'd1;            // OVL-01验证数字复位确定状态
		cnt_error = 0;                      // 开始所有检查前清空失败计数
		reg_hold_calibrated_s1_value = 12'sd0; // 初始化反压参考校准值
		reg_hold_calibration_applied = 1'b0; // 初始化反压参考校准资格
		reg_hold_saturation_low = 1'b0;     // 初始化反压参考负向饱和标志
		reg_hold_saturation_high = 1'b0;    // 初始化反压参考正向饱和标志
		reg_hold_config_epoch = 8'd0;       // 初始化反压参考ACTIVE版本
		reg_hold_coef_epoch = 8'd0;         // 初始化反压参考系数组版本
		reg_hold_detect_code = 9'd0;        // 初始化反压参考检测码
		reg_hold_stage1_raw = 10'd0;        // 初始化反压参考S1物理码
		reg_hold_stage1_code_ext = 11'sd0;  // 初始化反压参考D1_EXT
		reg_hold_stage2_raw = 10'd0;        // 初始化反压参考S2物理码
		reg_hold_stage2_code_ext = 11'sd0;  // 初始化反压参考D2_EXT
		reg_hold_nominal_15_code = 15'sd0;  // 初始化反压参考标称码
		reg_hold_nominal_15_valid = 1'b0;   // 初始化反压参考fine资格
		reg_hold_nominal_saturated = 1'b0;  // 初始化反压参考饱和状态
		reg_hold_precision_mode = 1'b0;     // 初始化反压参考精度
		reg_hold_frame_id = 16'd0;          // 初始化反压参考帧号
		reg_hold_sample_index = 16'd0;      // 初始化反压参考样本号
		reg_hold_color_ir = 1'b0;           // 初始化反压参考颜色
		reg_hold_frame_type = 2'b00;        // 初始化反压参考帧类别
		reg_hold_amb_code_snapshot = 8'd0;  // 初始化反压参考AMB码
		reg_hold_dc_code_snapshot = 8'd0;   // 初始化反压参考DC码
		reg_hold_amb_code_epoch = 4'd0;     // 初始化反压参考AMB版本
		reg_hold_dc_code_epoch = 4'd0;      // 初始化反压参考DC版本

		#125;
		if((o_normal_ready !== 1'b0) || (o_result_valid !== 1'b0) || (o_calibrated_s1_value !== 12'sd0) || (o_calibration_applied !== 1'b0) || (o_saturation_low !== 1'b0) || (o_saturation_high !== 1'b0) || (o_config_epoch !== 8'd0) || (o_coef_epoch !== 8'd0) || (o_nominal_15_valid !== 1'b0) || (o_detect_code !== 9'd0) || (o_stage1_raw !== 10'd0) || (o_stage1_code_ext !== 11'sd0) || (o_stage2_raw !== 10'd0) || (o_stage2_code_ext !== 11'sd0) || (o_nominal_15_code !== 15'sd0) || (o_nominal_saturated !== 1'b0) || (o_precision_mode !== 1'b0) || (o_frame_id !== 16'd0) || (o_sample_index !== 16'd0) || (o_color_ir !== 1'b0) || (o_frame_type !== 2'b00) || (o_amb_code_snapshot !== 8'd0) || (o_dc_code_snapshot !== 8'd0) || (o_amb_code_epoch !== 4'd0) || (o_dc_code_epoch !== 4'd0))begin
			cnt_error = cnt_error + 1;      // 记录复位输出存在未知或历史状态
			$display("FAIL OVL-01 reset state"); // 报告数字复位合同异常
		end

		@(negedge i_clk);
		i_rstn = 1'b1;                      // 在下降沿释放复位避免检查竞争
		@(posedge i_clk);
		#1;
		if(o_normal_ready !== 1'b1)begin
			cnt_error = cnt_error + 1;      // 记录空缓存没有向router开放ready
			$display("FAIL OVL-01 ready after reset release"); // 报告复位恢复后的握手错误
		end

		// OVL-02与OVL-15：valid为零时任意改变输入总线不得生成或改写输出事务
		reg_test_case_id = 8'd2;            // 标识空闲输入不产生事务场景
		i_result_ready = 1'b1;              // 保持下游开放以观察伪valid
		for(cnt_idle_cycle = 0; cnt_idle_cycle < 4; cnt_idle_cycle = cnt_idle_cycle + 1)begin
			@(negedge i_clk);
			drive_payload(cnt_idle_cycle[0], cnt_idle_cycle * 11'sd173 - 11'sd260,
				cnt_idle_cycle * 10'h155, cnt_idle_cycle * 9'd91,
				16'h1000 + cnt_idle_cycle, 16'h0100 + cnt_idle_cycle,
				cnt_idle_cycle[0], 8'h20 + cnt_idle_cycle, 8'h60 + cnt_idle_cycle,
				4'h1 + cnt_idle_cycle, 4'h4 + cnt_idle_cycle); // 逐拍扰动全部输入字段
			i_normal_valid = 1'b0;          // 明确禁止空闲总线被解释为事务
			@(posedge i_clk);
			#1;
			if(o_result_valid !== 1'b0)begin
				cnt_error = cnt_error + 1;  // 记录无valid条件下产生伪输出
				$display("FAIL OVL-02 idle input produced transaction"); // 报告输入资格门控失效
			end
		end

		// OVL-03：红光9-bit事务透传检测码与元数据，所有fine字段保持零
		reg_test_case_id = 8'd3;            // 标识正常粗精度红光事务
		@(negedge i_clk);
		drive_payload(1'b0, 11'sd188, 10'h3ff, 9'd188, 16'h2001, 16'h0001,
			1'b0, 8'h24, 8'h55, 4'h2, 4'h6); // S2故意非零以证明粗精度屏蔽
		i_normal_valid = 1'b1;              // 提交首笔有效NORMAL事务
		@(posedge i_clk);
		#1;
		check_output_transaction(1'b0, 11'sd188, 10'h3ff, 9'd188, 16'h2001,
			16'h0001, 1'b0, 8'h24, 8'h55, 4'h2, 4'h6); // 核对粗精度红光结果

		// OVL-04：红外9-bit事务同拍替换红光事务且保持独立DC快照
		reg_test_case_id = 8'd4;            // 标识正常粗精度红外事务
		@(negedge i_clk);
		drive_payload(1'b0, 11'sd92, 10'h2a5, 9'd92, 16'h2001, 16'h0002,
			1'b1, 8'h24, 8'h87, 4'h2, 4'h9); // 使用红外颜色与独立DC版本
		@(posedge i_clk);
		#1;
		check_output_transaction(1'b0, 11'sd92, 10'h2a5, 9'd92, 16'h2001,
			16'h0002, 1'b1, 8'h24, 8'h87, 4'h2, 4'h9); // 核对红外粗精度上下文

		// OVL-05：红光15-bit事务同时保留检测码并产生标称重构结果
		reg_test_case_id = 8'd5;            // 标识正常高精度红光事务
		@(negedge i_clk);
		drive_payload(1'b1, 11'sd233, 10'h2a5, 9'd233, 16'h2002, 16'h0003,
			1'b0, 8'h25, 8'h58, 4'h3, 4'h7); // 提供可识别S2物理码
		@(posedge i_clk);
		#1;
		check_output_transaction(1'b1, 11'sd233, 10'h2a5, 9'd233, 16'h2002,
			16'h0003, 1'b0, 8'h25, 8'h58, 4'h3, 4'h7); // 比较红光Q16黄金结果

		// OVL-06：红外15-bit事务复用算术硬件但保持全部红外元数据
		reg_test_case_id = 8'd6;            // 标识正常高精度红外事务
		@(negedge i_clk);
		drive_payload(1'b1, 11'sd301, 10'h15a, 9'd301, 16'h2002, 16'h0004,
			1'b1, 8'h25, 8'h91, 4'h3, 4'hb); // 保持同帧红外身份和DC码
		@(posedge i_clk);
		#1;
		check_output_transaction(1'b1, 11'sd301, 10'h15a, 9'd301, 16'h2002,
			16'h0004, 1'b1, 8'h25, 8'h91, 4'h3, 4'hb); // 比较红外Q16与上下文

		// OVL-07：遍历全部1024个S2物理码并用变化D1_EXT交叉检查标称结果
		reg_test_case_id = 8'd7;            // 标识S2全码空间遍历阶段
		for(cnt_raw_code = 0; cnt_raw_code < 1024; cnt_raw_code = cnt_raw_code + 1)begin
			reg_cross_d1_value = -4 + ((cnt_raw_code * 37) % 520); // 生成覆盖-4至515范围的确定性D1序列
			@(negedge i_clk);
			drive_payload(1'b1, reg_cross_d1_value, cnt_raw_code[9:0],
				reg_cross_d1_value[8:0], 16'h3000, cnt_raw_code[15:0],
				cnt_raw_code[0], 8'h2a, 8'h70 + cnt_raw_code[4:0], 4'h4,
				cnt_raw_code[3:0]);         // 为每个S2码绑定可追踪元数据
			@(posedge i_clk);
			#1;
			check_output_transaction(1'b1, reg_cross_d1_value, cnt_raw_code[9:0],
				reg_cross_d1_value[8:0], 16'h3000, cnt_raw_code[15:0],
				cnt_raw_code[0], 8'h2a, 8'h70 + cnt_raw_code[4:0], 4'h4,
				cnt_raw_code[3:0]);         // 逐码核对D2_EXT和Q16重构
		end

		// OVL-08：覆盖D1_EXT的冗余边界、中点两侧和正向量程端点
		reg_test_case_id = 8'd8;            // 标识Stage1边界数值检查
		@(negedge i_clk); drive_payload(1'b1, -11'sd4, 10'h155, 9'd0, 16'h4000, 16'h0001, 1'b0, 8'h30, 8'h60, 4'h5, 4'h1);
		@(posedge i_clk); #1; check_output_transaction(1'b1, -11'sd4, 10'h155, 9'd0, 16'h4000, 16'h0001, 1'b0, 8'h30, 8'h60, 4'h5, 4'h1);
		@(negedge i_clk); drive_payload(1'b1, 11'sd0, 10'h155, 9'd0, 16'h4000, 16'h0002, 1'b1, 8'h30, 8'h61, 4'h5, 4'h2);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd0, 10'h155, 9'd0, 16'h4000, 16'h0002, 1'b1, 8'h30, 8'h61, 4'h5, 4'h2);
		@(negedge i_clk); drive_payload(1'b1, 11'sd255, 10'h155, 9'd255, 16'h4000, 16'h0003, 1'b0, 8'h30, 8'h62, 4'h5, 4'h3);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd255, 10'h155, 9'd255, 16'h4000, 16'h0003, 1'b0, 8'h30, 8'h62, 4'h5, 4'h3);
		@(negedge i_clk); drive_payload(1'b1, 11'sd256, 10'h155, 9'd256, 16'h4000, 16'h0004, 1'b1, 8'h30, 8'h63, 4'h5, 4'h4);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd256, 10'h155, 9'd256, 16'h4000, 16'h0004, 1'b1, 8'h30, 8'h63, 4'h5, 4'h4);
		@(negedge i_clk); drive_payload(1'b1, 11'sd511, 10'h155, 9'd511, 16'h4000, 16'h0005, 1'b0, 8'h30, 8'h64, 4'h5, 4'h5);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd511, 10'h155, 9'd511, 16'h4000, 16'h0005, 1'b0, 8'h30, 8'h64, 4'h5, 4'h5);
		@(negedge i_clk); drive_payload(1'b1, 11'sd515, 10'h155, 9'd511, 16'h4000, 16'h0006, 1'b1, 8'h30, 8'h65, 4'h5, 4'h6);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd515, 10'h155, 9'd511, 16'h4000, 16'h0006, 1'b1, 8'h30, 8'h65, 4'h5, 4'h6);

		// OVL-09：选择半LSB门限上下的正负样本验证舍入完全对称
		reg_test_case_id = 8'd9;            // 标识正负半LSB附近舍入检查
		@(negedge i_clk); drive_payload(1'b1, 11'sd370, 10'h09d, 9'd370, 16'h5000, 16'h0001, 1'b0, 8'h31, 8'h70, 4'h6, 4'h1);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd370, 10'h09d, 9'd370, 16'h5000, 16'h0001, 1'b0, 8'h31, 8'h70, 4'h6, 4'h1);
		@(negedge i_clk); drive_payload(1'b1, 11'sd277, 10'h22a, 9'd277, 16'h5000, 16'h0002, 1'b1, 8'h31, 8'h71, 4'h6, 4'h2);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd277, 10'h22a, 9'd277, 16'h5000, 16'h0002, 1'b1, 8'h31, 8'h71, 4'h6, 4'h2);
		@(negedge i_clk); drive_payload(1'b1, 11'sd27, 10'h1c9, 9'd27, 16'h5000, 16'h0003, 1'b0, 8'h31, 8'h72, 4'h6, 4'h3);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd27, 10'h1c9, 9'd27, 16'h5000, 16'h0003, 1'b0, 8'h31, 8'h72, 4'h6, 4'h3);
		@(negedge i_clk); drive_payload(1'b1, 11'sd120, 10'h03c, 9'd120, 16'h5000, 16'h0004, 1'b1, 8'h31, 8'h73, 4'h6, 4'h4);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd120, 10'h03c, 9'd120, 16'h5000, 16'h0004, 1'b1, 8'h31, 8'h73, 4'h6, 4'h4);

		// OVL-10：注入接口可表达的异常D1_EXT证明上下端饱和不会二进制回绕
		reg_test_case_id = 8'd10;           // 标识正负饱和保护检查
		@(negedge i_clk); drive_payload(1'b1, 11'sd1023, 10'h3ff, 9'd511, 16'h6000, 16'h0001, 1'b0, 8'h32, 8'h7f, 4'h7, 4'h1);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd1023, 10'h3ff, 9'd511, 16'h6000, 16'h0001, 1'b0, 8'h32, 8'h7f, 4'h7, 4'h1);
		if((o_nominal_15_code !== 15'sd16383) || (o_nominal_saturated !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 明确要求正向异常输入到达最大端点
			$display("FAIL OVL-10 positive saturation endpoint"); // 报告正向保护结果错误
		end
		@(negedge i_clk); drive_payload(1'b1, 11'sh400, 10'h000, 9'd0, 16'h6000, 16'h0002, 1'b1, 8'h32, 8'h80, 4'h7, 4'h2);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sh400, 10'h000, 9'd0, 16'h6000, 16'h0002, 1'b1, 8'h32, 8'h80, 4'h7, 4'h2);
		if((o_nominal_15_code !== 15'sh4000) || (o_nominal_saturated !== 1'b1))begin
			cnt_error = cnt_error + 1;      // 明确要求负向异常输入到达最小端点
			$display("FAIL OVL-10 negative saturation endpoint"); // 报告负向保护结果错误
		end

		// 清空前一事务，为反压用例建立空的单元素输出缓存
		@(negedge i_clk);
		i_normal_valid = 1'b0;              // 停止连续输入以允许最后结果被消费
		i_result_ready = 1'b1;              // 保持下游开放完成最后事务
		@(posedge i_clk);
		#1;
		if(o_result_valid !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录无替换输入时valid未清除
			$display("FAIL OVL-12 output did not clear before backpressure test"); // 报告缓存释放失败
		end

		// OVL-11：下游持续反压时所有数值、资格和元数据逐拍保持
		reg_test_case_id = 8'd11;           // 标识统一事务反压稳定性场景
		@(negedge i_clk);
		i_result_ready = 1'b0;              // 在空缓存接纳后阻止下游消费
		drive_payload(1'b1, 11'sd333, 10'h2d3, 9'd333, 16'h7001, 16'h0101,
			1'b1, 8'h40, 8'ha5, 4'h8, 4'hd); // 装入具有鲜明元数据的红外事务
		i_normal_valid = 1'b1;              // 允许空缓存接收反压测试事务
		@(posedge i_clk);
		#1;
		reg_hold_calibrated_s1_value = o_calibrated_s1_value; // 保存反压开始时校准值
		reg_hold_calibration_applied = o_calibration_applied; // 保存反压开始时校准资格
		reg_hold_saturation_low = o_saturation_low; // 保存反压开始时负向诊断
		reg_hold_saturation_high = o_saturation_high; // 保存反压开始时正向诊断
		reg_hold_config_epoch = o_config_epoch; // 保存反压开始时ACTIVE版本
		reg_hold_coef_epoch = o_coef_epoch; // 保存反压开始时系数组版本
		reg_hold_detect_code = o_detect_code; // 保存反压开始时检测码
		reg_hold_stage1_raw = o_stage1_raw; // 保存反压开始时S1物理码
		reg_hold_stage1_code_ext = o_stage1_code_ext; // 保存反压开始时D1_EXT
		reg_hold_stage2_raw = o_stage2_raw; // 保存反压开始时S2物理码
		reg_hold_stage2_code_ext = o_stage2_code_ext; // 保存反压开始时D2_EXT
		reg_hold_nominal_15_code = o_nominal_15_code; // 保存反压开始时标称码
		reg_hold_nominal_15_valid = o_nominal_15_valid; // 保存反压开始时fine资格
		reg_hold_nominal_saturated = o_nominal_saturated; // 保存反压开始时饱和状态
		reg_hold_precision_mode = o_precision_mode; // 保存反压开始时精度快照
		reg_hold_frame_id = o_frame_id;     // 保存反压开始时帧号
		reg_hold_sample_index = o_sample_index; // 保存反压开始时样本号
		reg_hold_color_ir = o_color_ir;     // 保存反压开始时颜色
		reg_hold_frame_type = o_frame_type; // 保存反压开始时NORMAL类别
		reg_hold_amb_code_snapshot = o_amb_code_snapshot; // 保存反压开始时AMB码
		reg_hold_dc_code_snapshot = o_dc_code_snapshot; // 保存反压开始时DC码
		reg_hold_amb_code_epoch = o_amb_code_epoch; // 保存反压开始时AMB版本
		reg_hold_dc_code_epoch = o_dc_code_epoch; // 保存反压开始时DC版本
		if(o_normal_ready !== 1'b0)begin
			cnt_error = cnt_error + 1;      // 记录满缓存反压时仍错误开放ready
			$display("FAIL OVL-11 ready remained high under backpressure"); // 报告缓存占用控制错误
		end
		repeat(4)begin
			@(negedge i_clk);
			drive_payload(1'b0, -11'sd4, 10'h000, 9'd0, 16'h7fff,
				i_sample_index + 16'd1, ~i_color_ir, i_amb_code_snapshot + 8'd1,
				i_dc_code_snapshot + 8'd3, i_amb_code_epoch + 4'd1,
				i_dc_code_epoch + 4'd1);    // 扰动router载荷证明满缓存不重新采样
			@(posedge i_clk);
			#1;
			check_held_output;              // 对比全部保持字段
		end

		// OVL-12：解除反压后当前事务只消费一次并释放缓存
		reg_test_case_id = 8'd12;           // 标识反压解除与单次消费场景
		@(negedge i_clk);
		i_normal_valid = 1'b0;              // 防止消费旧事务时装入新载荷
		i_result_ready = 1'b1;              // 开放下游完成唯一输出握手
		@(posedge i_clk);
		#1;
		if((o_result_valid !== 1'b0) || (o_nominal_15_valid !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录旧事务消费后仍重复有效
			$display("FAIL OVL-12 transaction was not consumed exactly once"); // 报告反压解除语义错误
		end

		// OVL-13：旧输出消费与新输入接收同拍发生时valid连续且载荷完整替换
		reg_test_case_id = 8'd13;           // 标识单元素缓存无气泡替换场景
		@(negedge i_clk);
		i_result_ready = 1'b0;              // 先装入一笔等待消费的旧事务
		drive_payload(1'b0, 11'sd140, 10'h3ab, 9'd140, 16'h8001, 16'h0201,
			1'b0, 8'h41, 8'h66, 4'h9, 4'h2); // 旧事务采用红光9-bit载荷
		i_normal_valid = 1'b1;              // 空缓存允许接收旧事务
		@(posedge i_clk);
		#1;
		check_output_transaction(1'b0, 11'sd140, 10'h3ab, 9'd140, 16'h8001,
			16'h0201, 1'b0, 8'h41, 8'h66, 4'h9, 4'h2); // 确认旧事务已经占用输出缓存
		@(negedge i_clk);
		i_result_ready = 1'b1;              // 本拍允许旧事务被下游消费
		drive_payload(1'b1, 11'sd388, 10'h17c, 9'd388, 16'h8002, 16'h0202,
			1'b1, 8'h42, 8'h99, 4'ha, 4'he); // 同拍提供新的红外15-bit事务
		@(posedge i_clk);
		#1;
		check_output_transaction(1'b1, 11'sd388, 10'h17c, 9'd388, 16'h8002,
			16'h0202, 1'b1, 8'h42, 8'h99, 4'ha, 4'he); // valid应连续且载荷全部替换

		// OVL-14：连续9/15/9/15事务的fine资格只由各自精度快照决定
		reg_test_case_id = 8'd14;           // 标识交替精度连续事务场景
		@(negedge i_clk); drive_payload(1'b0, 11'sd170, 10'h3ff, 9'd170, 16'h9000, 16'h0001, 1'b0, 8'h43, 8'h70, 4'hb, 4'h1);
		@(posedge i_clk); #1; check_output_transaction(1'b0, 11'sd170, 10'h3ff, 9'd170, 16'h9000, 16'h0001, 1'b0, 8'h43, 8'h70, 4'hb, 4'h1);
		@(negedge i_clk); drive_payload(1'b1, 11'sd270, 10'h111, 9'd270, 16'h9000, 16'h0002, 1'b1, 8'h43, 8'h80, 4'hb, 4'h2);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd270, 10'h111, 9'd270, 16'h9000, 16'h0002, 1'b1, 8'h43, 8'h80, 4'hb, 4'h2);
		@(negedge i_clk); drive_payload(1'b0, 11'sd190, 10'h2aa, 9'd190, 16'h9000, 16'h0003, 1'b0, 8'h43, 8'h71, 4'hb, 4'h3);
		@(posedge i_clk); #1; check_output_transaction(1'b0, 11'sd190, 10'h2aa, 9'd190, 16'h9000, 16'h0003, 1'b0, 8'h43, 8'h71, 4'hb, 4'h3);
		@(negedge i_clk); drive_payload(1'b1, 11'sd290, 10'h222, 9'd290, 16'h9000, 16'h0004, 1'b1, 8'h43, 8'h81, 4'hb, 4'h4);
		@(posedge i_clk); #1; check_output_transaction(1'b1, 11'sd290, 10'h222, 9'd290, 16'h9000, 16'h0004, 1'b1, 8'h43, 8'h81, 4'hb, 4'h4);

		// OVL-15：输出消费后valid为零，随后输入总线变化不能复活或改写旧事务
		reg_test_case_id = 8'd15;           // 标识空闲输出状态保持检查
		@(negedge i_clk);
		i_normal_valid = 1'b0;              // 停止输入以消费最后交替精度事务
		i_result_ready = 1'b1;              // 允许最后结果离开缓存
		@(posedge i_clk);
		#1;
		reg_hold_calibrated_s1_value = o_calibrated_s1_value; // 保存空闲阶段校准值参考
		reg_hold_calibration_applied = o_calibration_applied; // 保存空闲阶段校准资格参考
		reg_hold_saturation_low = o_saturation_low; // 保存空闲阶段负向诊断参考
		reg_hold_saturation_high = o_saturation_high; // 保存空闲阶段正向诊断参考
		reg_hold_config_epoch = o_config_epoch; // 保存空闲阶段ACTIVE版本参考
		reg_hold_coef_epoch = o_coef_epoch; // 保存空闲阶段系数组版本参考
		reg_hold_detect_code = o_detect_code; // 保存valid清零后的内部载荷状态
		reg_hold_stage1_raw = o_stage1_raw; // 保存空闲阶段S1物理码参考值
		reg_hold_stage1_code_ext = o_stage1_code_ext; // 保存空闲阶段D1_EXT参考值
		reg_hold_stage2_raw = o_stage2_raw; // 保存空闲阶段S2物理码参考值
		reg_hold_stage2_code_ext = o_stage2_code_ext; // 保存空闲阶段D2_EXT参考值
		reg_hold_nominal_15_code = o_nominal_15_code; // 保存空闲阶段标称码参考值
		reg_hold_nominal_15_valid = o_nominal_15_valid; // 保存空闲阶段fine资格参考值
		reg_hold_nominal_saturated = o_nominal_saturated; // 保存空闲阶段饱和状态参考值
		reg_hold_precision_mode = o_precision_mode; // 保存空闲阶段精度参考值
		reg_hold_frame_id = o_frame_id;     // 保存空闲阶段帧号参考值
		reg_hold_sample_index = o_sample_index; // 保存空闲阶段样本号参考值
		reg_hold_color_ir = o_color_ir;     // 保存空闲阶段颜色参考值
		reg_hold_frame_type = o_frame_type; // 保存空闲阶段帧类别参考值
		reg_hold_amb_code_snapshot = o_amb_code_snapshot; // 保存空闲阶段AMB码参考值
		reg_hold_dc_code_snapshot = o_dc_code_snapshot; // 保存空闲阶段DC码参考值
		reg_hold_amb_code_epoch = o_amb_code_epoch; // 保存空闲阶段AMB版本参考值
		reg_hold_dc_code_epoch = o_dc_code_epoch; // 保存空闲阶段DC版本参考值
		repeat(3)begin
			@(negedge i_clk);
			drive_payload(~i_precision_mode, i_stage1_code_ext + 11'sd111,
				i_stage2_raw + 10'h077, i_detect_code + 9'd33, i_frame_id + 16'd1,
				i_sample_index + 16'd1, ~i_color_ir, i_amb_code_snapshot + 8'd2,
				i_dc_code_snapshot + 8'd4, i_amb_code_epoch + 4'd1,
				i_dc_code_epoch + 4'd1);    // 持续扰动无效输入总线
			i_normal_valid = 1'b0;          // 始终保持无输入事务资格
			@(posedge i_clk);
			#1;
			if((o_result_valid !== 1'b0) || (o_calibrated_s1_value !== reg_hold_calibrated_s1_value) || (o_calibration_applied !== reg_hold_calibration_applied) || (o_saturation_low !== reg_hold_saturation_low) || (o_saturation_high !== reg_hold_saturation_high) || (o_config_epoch !== reg_hold_config_epoch) || (o_coef_epoch !== reg_hold_coef_epoch) || (o_detect_code !== reg_hold_detect_code) || (o_stage1_raw !== reg_hold_stage1_raw) || (o_stage1_code_ext !== reg_hold_stage1_code_ext) || (o_stage2_raw !== reg_hold_stage2_raw) || (o_stage2_code_ext !== reg_hold_stage2_code_ext) || (o_nominal_15_code !== reg_hold_nominal_15_code) || (o_nominal_15_valid !== reg_hold_nominal_15_valid) || (o_nominal_saturated !== reg_hold_nominal_saturated) || (o_precision_mode !== reg_hold_precision_mode) || (o_frame_id !== reg_hold_frame_id) || (o_sample_index !== reg_hold_sample_index) || (o_color_ir !== reg_hold_color_ir) || (o_frame_type !== reg_hold_frame_type) || (o_amb_code_snapshot !== reg_hold_amb_code_snapshot) || (o_dc_code_snapshot !== reg_hold_dc_code_snapshot) || (o_amb_code_epoch !== reg_hold_amb_code_epoch) || (o_dc_code_epoch !== reg_hold_dc_code_epoch))begin
				cnt_error = cnt_error + 1;  // 记录空闲总线变化影响内部保持状态
				$display("FAIL OVL-15 invalid input changed output state"); // 报告无valid采样错误
			end
		end

		// OVL-17：校准signed端点、独立状态位和版本标签必须逐位保持
		reg_test_case_id = 8'd17;           // 标识校准扩展载荷边界检查
		@(negedge i_clk);
		i_result_ready = 1'b1;              // 开放下游以连续检查两个校准端点
		drive_payload(1'b1, 11'sd256, 10'h155, 9'd256, 16'hb0e1, 16'h0471,
			1'b0, 8'h61, 8'h91, 4'hd, 4'h1); // 构造负向校准端点所属事务
		i_calibrated_s1_value = -12'sd2048; // 覆盖signed 12-bit最小端点
		i_calibration_applied = 1'b1;       // 证明资格不由数值或epoch推导
		i_saturation_low = 1'b1;            // 仅置位负向饱和诊断
		i_saturation_high = 1'b0;           // 保持正向诊断关闭
		i_config_epoch = 8'he1;             // 使用鲜明ACTIVE版本标签
		i_coef_epoch = 8'h71;               // 使用独立系数组版本标签
		i_normal_valid = 1'b1;              // 提交负向端点事务
		@(posedge i_clk);
		#1;
		if((o_calibrated_s1_value !== -12'sd2048) || (o_calibration_applied !== 1'b1) || (o_saturation_low !== 1'b1) || (o_saturation_high !== 1'b0) || (o_config_epoch !== 8'he1) || (o_coef_epoch !== 8'h71))begin
			cnt_error = cnt_error + 1;      // 记录负向端点或绑定字段损坏
			$display("FAIL OVL-17 negative calibrated endpoint payload"); // 报告负向校准载荷错误
		end
		@(negedge i_clk);
		drive_payload(1'b0, 11'sd255, 10'h2aa, 9'd255, 16'hb02c, 16'h048e,
			1'b1, 8'h62, 8'h92, 4'he, 4'h2); // 构造正向校准端点所属事务
		i_calibrated_s1_value = 12'sd2047;  // 覆盖signed 12-bit最大端点
		i_calibration_applied = 1'b0;       // 覆盖无正式校准资格的独立状态
		i_saturation_low = 1'b0;            // 保持负向诊断关闭
		i_saturation_high = 1'b1;           // 仅置位正向饱和诊断
		i_config_epoch = 8'h2c;             // 切换ACTIVE版本证明无错拍
		i_coef_epoch = 8'h8e;               // 切换系数组版本证明原子替换
		@(posedge i_clk);
		#1;
		if((o_calibrated_s1_value !== 12'sd2047) || (o_calibration_applied !== 1'b0) || (o_saturation_low !== 1'b0) || (o_saturation_high !== 1'b1) || (o_config_epoch !== 8'h2c) || (o_coef_epoch !== 8'h8e))begin
			cnt_error = cnt_error + 1;      // 记录正向端点或同拍替换损坏
			$display("FAIL OVL-17 positive calibrated endpoint payload"); // 报告正向校准载荷错误
		end

		// OVL-16：有效输出等待期间异步复位必须立即清除valid和全部结果字段
		reg_test_case_id = 8'd16;           // 标识反压等待中的数字复位场景
		@(negedge i_clk);
		i_result_ready = 1'b0;              // 让新事务在输出缓存中等待
		drive_payload(1'b1, 11'sd345, 10'h2f0, 9'd345, 16'ha001, 16'h0301,
			1'b1, 8'h50, 8'hb0, 4'hc, 4'hf); // 装入复位中断测试载荷
		i_normal_valid = 1'b1;              // 允许空缓存接收最后事务
		@(posedge i_clk);
		#1;
		if(o_result_valid !== 1'b1)begin
			cnt_error = cnt_error + 1;      // 记录复位前没有形成有效等待事务
			$display("FAIL OVL-16 reset-interrupt setup"); // 报告复位用例准备失败
		end
		#37;
		i_rstn = 1'b0;                      // 在非时钟边沿异步断言数字复位
		#1;
		if((o_normal_ready !== 1'b0) || (o_result_valid !== 1'b0) || (o_calibrated_s1_value !== 12'sd0) || (o_calibration_applied !== 1'b0) || (o_saturation_low !== 1'b0) || (o_saturation_high !== 1'b0) || (o_config_epoch !== 8'd0) || (o_coef_epoch !== 8'd0) || (o_nominal_15_valid !== 1'b0) || (o_detect_code !== 9'd0) || (o_stage1_raw !== 10'd0) || (o_stage1_code_ext !== 11'sd0) || (o_stage2_raw !== 10'd0) || (o_stage2_code_ext !== 11'sd0) || (o_nominal_15_code !== 15'sd0) || (o_nominal_saturated !== 1'b0) || (o_precision_mode !== 1'b0) || (o_frame_id !== 16'd0) || (o_sample_index !== 16'd0) || (o_color_ir !== 1'b0) || (o_frame_type !== 2'b00) || (o_amb_code_snapshot !== 8'd0) || (o_dc_code_snapshot !== 8'd0) || (o_amb_code_epoch !== 4'd0) || (o_dc_code_epoch !== 4'd0))begin
			cnt_error = cnt_error + 1;      // 记录异步复位未清空完整统一事务
			$display("FAIL OVL-16 asynchronous reset clear"); // 报告复位确定性错误
		end
		@(negedge i_clk);
		i_normal_valid = 1'b0;              // 复位期间撤销测试输入valid
		i_result_ready = 1'b1;              // 复位释放后保持下游可接收
		i_rstn = 1'b1;                      // 下降沿释放复位等待下一有效事务
		@(posedge i_clk);
		#1;
		if((o_normal_ready !== 1'b1) || (o_result_valid !== 1'b0))begin
			cnt_error = cnt_error + 1;      // 记录复位释放后旧事务复活或ready未恢复
			$display("FAIL OVL-16 reset recovery"); // 报告复位恢复合同错误
		end

		if(cnt_error == 0)begin
			$display("PASS ppg_adc_pipeline_overlap_corrector OVL-01..OVL-17 and 1024-code sweep"); // 所有真实比较通过后报告唯一PASS
		end else begin
			$display("FAIL ppg_adc_pipeline_overlap_corrector errors=%0d", cnt_error); // 汇总错误数阻止假通过
		end
		#1000;
		$finish;                            // 保留两拍尾部波形后正常结束仿真
	end

	// 独立看门狗在激励流程挂起时输出FAIL并强制结束xsim
	initial begin
		#2000000;
		$display("FAIL ppg_adc_pipeline_overlap_corrector watchdog timeout"); // 超时说明握手或测试流程未完成
		$finish;                            // 防止仿真无限等待时钟事件
	end

	// 实例化待验证的PPG ADC两级Pipeline重叠重构器
	ppg_adc_pipeline_overlap_corrector
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 对齐测试帧号字段宽度
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 对齐测试样本编号字段宽度
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH), // 对齐测试IDAC码快照宽度
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 对齐测试调码版本字段宽度
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 对齐测试ACTIVE配置版本宽度
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH) // 对齐测试Stage1系数组版本宽度
	)ppg_adc_pipeline_overlap_corrector_Inst_dut(
		.i_clk(i_clk),                      // 连接2 MHz测试时钟
		.i_rstn(i_rstn),                    // 连接低有效异步复位
		.i_normal_valid(i_normal_valid),    // 驱动router NORMAL分支valid
		.i_calibrated_s1_value(i_calibrated_s1_value), // 驱动正式Stage1校准结果
		.i_calibration_applied(i_calibration_applied), // 驱动校准资格
		.i_saturation_low(i_saturation_low), // 驱动负向饱和诊断
		.i_saturation_high(i_saturation_high), // 驱动正向饱和诊断
		.i_config_epoch(i_config_epoch),    // 驱动ACTIVE配置版本
		.i_coef_epoch(i_coef_epoch),        // 驱动Stage1系数组版本
		.i_detect_code(i_detect_code),      // 驱动固定S1黄金比较结果
		.i_stage1_raw(i_stage1_raw),        // 驱动与事务对齐的S1物理决策码
		.i_stage1_code_ext(i_stage1_code_ext), // 驱动未钳位D1_EXT
		.i_stage2_raw(i_stage2_raw),        // 驱动S2物理决策码
		.i_precision_mode(i_precision_mode), // 驱动事务精度资格
		.i_frame_id(i_frame_id),            // 驱动R/IR共享PPG周期编号
		.i_sample_index(i_sample_index),    // 驱动全局ADC结果序号
		.i_color_ir(i_color_ir),            // 驱动红光或红外身份
		.i_frame_type(i_frame_type),        // 驱动NORMAL事务类别
		.i_amb_code_snapshot(i_amb_code_snapshot), // 驱动AMB实际码快照
		.i_dc_code_snapshot(i_dc_code_snapshot), // 驱动当前颜色DC码快照
		.i_amb_code_epoch(i_amb_code_epoch), // 驱动AMB安全提交版本
		.i_dc_code_epoch(i_dc_code_epoch),  // 驱动当前颜色DC版本
		.o_normal_ready(o_normal_ready),    // 观察返回router的反压许可
		.i_result_ready(i_result_ready),    // 驱动统一结果下游ready
		.o_result_valid(o_result_valid),    // 观察保持型统一事务valid
		.o_calibrated_s1_value(o_calibrated_s1_value), // 观察保持型Stage1校准值
		.o_calibration_applied(o_calibration_applied), // 观察校准资格对齐
		.o_saturation_low(o_saturation_low), // 观察负向饱和诊断对齐
		.o_saturation_high(o_saturation_high), // 观察正向饱和诊断对齐
		.o_config_epoch(o_config_epoch),    // 观察ACTIVE配置版本对齐
		.o_coef_epoch(o_coef_epoch),        // 观察Stage1系数组版本对齐
		.o_detect_code(o_detect_code),      // 观察透传S1检测码
		.o_stage1_raw(o_stage1_raw),        // 观察逐物理位校准所需S1码
		.o_stage1_code_ext(o_stage1_code_ext), // 观察保存的D1_EXT
		.o_stage2_raw(o_stage2_raw),        // 观察按精度资格保存的S2码
		.o_stage2_code_ext(o_stage2_code_ext), // 观察冗余解码D2_EXT
		.o_nominal_15_code(o_nominal_15_code), // 观察Q16标称重构结果
		.o_nominal_15_valid(o_nominal_15_valid), // 观察统一事务fine资格
		.o_nominal_saturated(o_nominal_saturated), // 观察标称结果饱和诊断
		.o_precision_mode(o_precision_mode), // 观察精度模式快照
		.o_frame_id(o_frame_id),            // 观察R/IR共享帧号
		.o_sample_index(o_sample_index),    // 观察ADC结果顺序编号
		.o_color_ir(o_color_ir),            // 观察红光或红外标签
		.o_frame_type(o_frame_type),        // 观察NORMAL类别透传
		.o_amb_code_snapshot(o_amb_code_snapshot), // 观察AMB码快照对齐
		.o_dc_code_snapshot(o_dc_code_snapshot), // 观察当前颜色DC码对齐
		.o_amb_code_epoch(o_amb_code_epoch), // 观察AMB版本标签对齐
		.o_dc_code_epoch(o_dc_code_epoch)   // 观察当前颜色DC版本对齐
	);

endmodule
