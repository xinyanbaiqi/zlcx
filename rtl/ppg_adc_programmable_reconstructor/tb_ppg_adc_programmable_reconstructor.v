`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/07
// Design Name:        PPG ADC Programmable Reconstructor Testbench
// Module Name:        tb_ppg_adc_programmable_reconstructor
// Description:        TestBench/Vivado/2022.2/ppg_adc_programmable_reconstructor
// Simulations:        Vivado xsim 2022.2
//
// Referrences:        PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_adc_programmable_reconstructor
//
// Version:            V1.1
// Revision Date:      2026/10/05
// History:
//    Time               Version       Revised by            Contents
// 2026/08/07            V1.0          Erie                  Create self-checking testbench.
// 2026/10/05            V1.1          Erie                  ABCD review F-027: the two original PR-06 vectors (offset +/-32768) never put the total Q17 accumulator on the rounding threshold. Add four reachable threshold neighbours via public inputs (S1=256, D2=256, offset -1734151/-1734150/-1799686/-1799687 giving ACC=+65535/+65537/-65535/-65537), each checked by the golden model and by independent literals 0/1/0/-1. Negative controls: ROUND_HALF_Q17 65534 and 65538 both fail.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月07日
// 设计名称:           PPG ADC 15-bit可编程重构器自检平台
// 模块名称:           tb_ppg_adc_programmable_reconstructor
// 模块说明:           TestBench/Vivado/2022.2/ppg_adc_programmable_reconstructor
// 仿真工程:           Vivado xsim 2022.2
//
// 参考资料:           PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_adc_programmable_reconstructor
//
// 当前版本:           V1.1
// 修订日期:           2026年10月05日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月07日        V1.0          Erie                  创建PR-01至PR-14自检平台
// 2026年10月05日        V1.1          Erie                  ABCD复核F-027：原PR-06两笔（offset ±32768）从未使Q17总累加值落在舍入门限。新增四个经公开输入可达的门限邻点（S1=256、D2=256，offset分别为-1734151/-1734150/-1799686/-1799687，对应ACC=+65535/+65537/-65535/-65537），同时经黄金模型和独立字面量0/1/0/-1比较。负对照：ROUND_HALF_Q17改为65534或65538均失败。

// 独立黄金模型覆盖Q17算术、9/15-bit资格、饱和、epoch和保持型事务行为
module tb_ppg_adc_programmable_reconstructor();

	//-------------配置参数区域-------------//
	localparam integer C_FRAME_ID_WIDTH = 16; // 测试共享PPG帧号字段宽度
	localparam integer C_SAMPLE_INDEX_WIDTH = 16; // 测试样本顺序字段宽度
	localparam integer C_IDAC_CODE_WIDTH = 8; // 测试IDAC码快照字段宽度
	localparam integer C_CODE_EPOCH_WIDTH = 4; // 测试IDAC码版本字段宽度
	localparam integer C_CONFIG_EPOCH_WIDTH = 8; // 测试ACTIVE配置版本宽度
	localparam integer C_COEF_EPOCH_WIDTH = 8; // 测试系数版本字段宽度
	localparam signed [19:0] STAGE2_GAIN_NOMINAL_Q16 = 20'sd54143; // 冻结Stage2标称增益
	localparam integer C_PAYLOAD_WIDTH = 186; // 汇总DUT全部事务输出字段宽度

	//--------------寄存器信号--------------//
	reg i_clk; // 测试时钟源
	reg i_rstn; // 低有效异步复位激励
	reg i_active_valid; // ACTIVE配置接收资格
	reg i_stage2_calibration_valid; // Stage2系数合法资格
	reg signed [19:0]i_stage2_gain_q16; // Stage2统一Q16增益
	reg signed [31:0]i_stage2_offset_q16; // Stage2 Q16偏置
	reg [7:0]i_stage2_coef_epoch; // Stage2独立版本
	reg i_result_valid; // 上游事务valid
	reg signed [11:0]i_calibrated_s1_value; // Stage1校准值
	reg i_calibration_applied; // Stage1系数资格
	reg i_saturation_low; // Stage1负饱和旁路
	reg i_saturation_high; // Stage1正饱和旁路
	reg [7:0]i_config_epoch; // ACTIVE版本标签
	reg [7:0]i_coef_epoch; // Stage1版本标签
	reg [8:0]i_detect_code; // 固定9-bit检测码
	reg [9:0]i_stage1_raw; // Stage1物理码
	reg signed [10:0]i_stage1_code_ext; // D1_EXT旁路
	reg [9:0]i_stage2_raw; // Stage2物理码
	reg signed [10:0]i_stage2_code_ext; // D2_EXT输入
	reg signed [14:0]i_nominal_15_code; // 固定黄金码旁路
	reg i_nominal_15_valid; // 固定黄金码资格
	reg i_nominal_saturated; // 固定黄金码饱和旁路
	reg i_precision_mode; // 9-bit或15-bit模式
	reg [15:0]i_frame_id; // 共享PPG帧号
	reg [15:0]i_sample_index; // 颜色样本序号
	reg i_color_ir; // 红光或红外身份
	reg [1:0]i_frame_type; // NORMAL事务类别
	reg [7:0]i_amb_code_snapshot; // AMB码快照
	reg [7:0]i_dc_code_snapshot; // DC码快照
	reg [3:0]i_amb_code_epoch; // AMB版本
	reg [3:0]i_dc_code_epoch; // DC版本
	reg i_result_ready; // 下游ready

	//--------------计数信号--------------//
	integer cnt_error; // 全部比较失败计数
	integer cnt_raw; // 1024码遍历索引
	integer cnt_expected_d2; // 独立D2_EXT结果
	integer cnt_hold; // 反压保持周期索引

	//---------------其他信号---------------//
	wire o_result_ready; // DUT上游ready
	wire o_result_valid; // DUT下游valid
	wire signed [14:0]o_programmable_15_code; // 正式15-bit结果
	wire o_programmable_15_valid; // 正式15-bit资格
	wire o_programmable_15_calibration_applied; // 两级校准合并资格
	wire o_programmable_saturation_low; // 正式负饱和标志
	wire o_programmable_saturation_high; // 正式正饱和标志
	wire [7:0]o_stage2_coef_epoch; // 输出Stage2版本
	wire signed [11:0]o_calibrated_s1_value; // 透传Stage1校准值
	wire o_calibration_applied; // 透传Stage1资格
	wire o_stage1_saturation_low; // 透传Stage1负饱和
	wire o_stage1_saturation_high; // 透传Stage1正饱和
	wire [7:0]o_config_epoch; // 输出ACTIVE版本
	wire [7:0]o_coef_epoch; // 输出Stage1版本
	wire [8:0]o_detect_code; // 透传检测码
	wire [9:0]o_stage1_raw; // 透传S1物理码
	wire signed [10:0]o_stage1_code_ext; // 透传D1_EXT
	wire [9:0]o_stage2_raw; // 透传S2物理码
	wire signed [10:0]o_stage2_code_ext; // 透传D2_EXT
	wire signed [14:0]o_nominal_15_code; // 透传固定黄金码
	wire o_nominal_15_valid; // 透传固定黄金资格
	wire o_nominal_saturated; // 透传固定黄金饱和
	wire o_precision_mode; // 透传精度模式
	wire [15:0]o_frame_id; // 透传帧号
	wire [15:0]o_sample_index; // 透传样本号
	wire o_color_ir; // 透传颜色身份
	wire [1:0]o_frame_type; // 透传事务类别
	wire [7:0]o_amb_code_snapshot; // 透传AMB快照
	wire [7:0]o_dc_code_snapshot; // 透传DC快照
	wire [3:0]o_amb_code_epoch; // 透传AMB版本
	wire [3:0]o_dc_code_epoch; // 透传DC版本
	wire [C_PAYLOAD_WIDTH - 1:0]dec_observed_payload; // 汇总全部输出供反压比较

	//-------------其他信号连线-------------//
	assign dec_observed_payload = {
		o_programmable_15_code, o_programmable_15_valid,
		o_programmable_saturation_low, o_programmable_saturation_high,
		o_programmable_15_calibration_applied, o_stage2_coef_epoch,
		o_config_epoch, o_coef_epoch, o_calibrated_s1_value,
		o_calibration_applied, o_stage1_saturation_low,
		o_stage1_saturation_high, o_stage1_raw, o_detect_code,
		o_stage1_code_ext, o_stage2_raw, o_stage2_code_ext,
		o_nominal_15_code, o_nominal_15_valid, o_nominal_saturated,
		o_precision_mode, o_frame_id, o_sample_index, o_color_ir,
		o_frame_type, o_amb_code_snapshot, o_dc_code_snapshot,
		o_amb_code_epoch, o_dc_code_epoch
	}; // 汇总186-bit结果和事务身份字段

	//-------------寄存器信号-------------//
	reg signed [63:0]reg_model_accumulator; // 黄金Q17累加器
	reg signed [63:0]reg_model_rounded; // 黄金舍入整数
	reg signed [14:0]reg_expected_code; // 黄金15-bit结果
	reg reg_expected_low; // 黄金负饱和标志
	reg reg_expected_high; // 黄金正饱和标志
	reg [C_PAYLOAD_WIDTH - 1:0]reg_payload_hold; // 反压起点payload快照

	//-------------函数定义区域-------------//
	// 使用与合同相同的整数公式计算当前Stage1和D2_EXT的期望结果
	task model_result;
		input signed [11:0]i_model_s1; // 黄金Stage1输入
		input signed [10:0]i_model_d2; // 黄金D2_EXT输入
		input signed [19:0]i_model_gain; // 黄金Stage2增益
		input signed [31:0]i_model_offset; // 黄金Stage2偏置
		begin
			reg_model_accumulator = ((i_model_s1 * 64'sd2 - 64'sd511) * 64'sd3533837) +
				((i_model_d2 * 64'sd2 - 64'sd512) * i_model_gain) +
				(i_model_offset * 64'sd2); // 计算ACC_Q17
			if(reg_model_accumulator < 0)begin
				reg_model_rounded = -(((-reg_model_accumulator) + 64'sd65536) >>> 17); // 负向对称舍入
			end else begin
				reg_model_rounded = (reg_model_accumulator + 64'sd65536) >>> 17; // 正向对称舍入
			end
			if(reg_model_rounded < -64'sd16384)begin
				reg_expected_code = -15'sd16384; // 负向显式饱和
				reg_expected_low = 1'b1; // 置位负饱和标志
				reg_expected_high = 1'b0; // 负饱和时关闭正标志
			end else if(reg_model_rounded > 64'sd16383)begin
				reg_expected_code = 15'sd16383; // 正向显式饱和
				reg_expected_low = 1'b0; // 正饱和时关闭负标志
				reg_expected_high = 1'b1; // 置位正饱和标志
			end else begin
				reg_expected_code = reg_model_rounded[14:0]; // 合法范围保留补码结果
				reg_expected_low = 1'b0; // 合法范围不产生负饱和
				reg_expected_high = 1'b0; // 合法范围不产生正饱和
			end
		end
	endtask

	// 装载一笔带有完整元数据的事务，便于检查原子payload保持
	task drive_transaction;
		input i_drive_precision; // 当前事务精度模式
		input signed [11:0]i_drive_s1; // 当前Stage1值
		input signed [10:0]i_drive_d2; // 当前D2_EXT
		input [9:0]i_drive_s2_raw; // 当前S2物理码
		input signed [19:0]i_drive_gain; // 当前Stage2增益
		input signed [31:0]i_drive_offset; // 当前Stage2偏置
		input i_drive_s1_valid; // Stage1资格
		input i_drive_s2_valid; // Stage2资格
		input [7:0]i_drive_cfg; // ACTIVE版本
		input [7:0]i_drive_coef; // Stage1版本
		input [7:0]i_drive_s2_epoch; // Stage2版本
		input integer i_drive_seq; // 事务序号
		begin
			i_precision_mode = i_drive_precision; // 绑定精度快照
			i_calibrated_s1_value = i_drive_s1; // 绑定Stage1校准值
			i_stage2_code_ext = i_drive_d2; // 绑定D2_EXT计算输入
			i_stage2_raw = i_drive_s2_raw; // 绑定S2物理码旁路
			i_stage2_gain_q16 = i_drive_gain; // 绑定Stage2增益
			i_stage2_offset_q16 = i_drive_offset; // 绑定Stage2偏置
			i_stage2_calibration_valid = i_drive_s2_valid; // 绑定Stage2资格
			i_calibration_applied = i_drive_s1_valid; // 绑定Stage1资格
			i_config_epoch = i_drive_cfg; // 绑定ACTIVE epoch
			i_coef_epoch = i_drive_coef; // 绑定Stage1 epoch
			i_stage2_coef_epoch = i_drive_s2_epoch; // 绑定Stage2 epoch
			i_saturation_low = i_drive_seq[0]; // 变化Stage1负饱和旁路
			i_saturation_high = i_drive_seq[1]; // 变化Stage1正饱和旁路
			i_detect_code = i_drive_seq[8:0]; // 变化固定检测码
			i_stage1_raw = i_drive_seq[9:0]; // 变化Stage1物理码
			i_stage1_code_ext = i_drive_s1[10:0]; // 变化D1_EXT旁路
			i_nominal_15_code = i_drive_seq - 15'sd1000; // 变化固定黄金旁路
			i_nominal_15_valid = i_drive_precision; // 固定结果资格
			i_nominal_saturated = i_drive_seq[2]; // 固定结果饱和旁路
			i_frame_id = 16'h4000 + i_drive_seq; // 唯一共享帧号
			i_sample_index = i_drive_seq[15:0]; // 唯一样本序号
			i_color_ir = i_drive_seq[0]; // 红光红外交替
			i_frame_type = 2'b10; // NORMAL事务类别
			i_amb_code_snapshot = 8'h20 + i_drive_seq[7:0]; // AMB快照
			i_dc_code_snapshot = 8'h80 + i_drive_seq[7:0]; // DC快照
			i_amb_code_epoch = i_drive_seq[3:0]; // AMB版本
			i_dc_code_epoch = i_drive_seq[7:4]; // DC版本
		end
	endtask

	// 比较一笔已锁存输出的算术、资格和全部透传字段
	task check_transaction;
		input integer i_check_id; // PR用例编号
		begin
			model_result(i_calibrated_s1_value, i_stage2_code_ext, i_stage2_gain_q16, i_stage2_offset_q16); // 计算黄金结果
			if(i_precision_mode == 1'b0)begin
				reg_expected_code = 15'sd0; // 9-bit事务结果清零
				reg_expected_low = 1'b0; // 9-bit事务负饱和清零
				reg_expected_high = 1'b0; // 9-bit事务正饱和清零
			end
			if((o_result_valid !== 1'b1) || (o_programmable_15_code !== reg_expected_code) ||
				(o_programmable_15_valid !== i_precision_mode) ||
				(o_programmable_saturation_low !== reg_expected_low) ||
				(o_programmable_saturation_high !== reg_expected_high))begin
				cnt_error = cnt_error + 1; // 算术或精度资格比较失败
				$display("FAIL PR-%0d result expected=%0d actual=%0d", i_check_id, $signed(reg_expected_code), $signed(o_programmable_15_code)); // 报告正式结果偏差
			end
			if(o_programmable_15_calibration_applied !== (i_precision_mode && i_calibration_applied && i_stage2_calibration_valid))begin
				cnt_error = cnt_error + 1; // 两级资格组合失败
				$display("FAIL PR-%0d qualification", i_check_id); // 报告两级校准资格错误
			end
			if(o_stage2_coef_epoch !== (i_precision_mode ? i_stage2_coef_epoch : 8'h00))begin
				cnt_error = cnt_error + 1; // Stage2版本清除或透传失败
				$display("FAIL PR-%0d stage2 epoch", i_check_id); // 报告Stage2 epoch错误
			end
			if((o_calibrated_s1_value !== i_calibrated_s1_value) || (o_calibration_applied !== i_calibration_applied) ||
				(o_config_epoch !== i_config_epoch) || (o_coef_epoch !== i_coef_epoch) ||
				(o_detect_code !== i_detect_code) || (o_stage1_raw !== i_stage1_raw) ||
				(o_stage1_code_ext !== i_stage1_code_ext) || (o_stage2_raw !== i_stage2_raw) ||
				(o_stage2_code_ext !== i_stage2_code_ext) || (o_nominal_15_code !== i_nominal_15_code) ||
				(o_nominal_15_valid !== i_nominal_15_valid) || (o_nominal_saturated !== i_nominal_saturated) ||
				(o_precision_mode !== i_precision_mode) || (o_frame_id !== i_frame_id) ||
				(o_sample_index !== i_sample_index) || (o_color_ir !== i_color_ir) ||
				(o_frame_type !== i_frame_type) || (o_amb_code_snapshot !== i_amb_code_snapshot) ||
				(o_dc_code_snapshot !== i_dc_code_snapshot) || (o_amb_code_epoch !== i_amb_code_epoch) ||
				(o_dc_code_epoch !== i_dc_code_epoch))begin
				cnt_error = cnt_error + 1; // 完整事务payload透传失败
				$display("FAIL PR-%0d payload", i_check_id); // 报告元数据或诊断字段错位
			end
		end
	endtask

	// 在下降沿驱动输入并在下一上升沿检查一拍缓存结果
	task send_transaction;
		input integer i_send_id; // PR用例编号
		input i_send_precision; // 事务精度
		input signed [11:0]i_send_s1; // Stage1值
		input signed [10:0]i_send_d2; // D2_EXT值
		input [9:0]i_send_s2_raw; // S2物理码
		input signed [19:0]i_send_gain; // Stage2增益
		input signed [31:0]i_send_offset; // Stage2偏置
		input i_send_s1_valid; // Stage1资格
		input i_send_s2_valid; // Stage2资格
		input [7:0]i_send_cfg; // ACTIVE epoch
		input [7:0]i_send_coef; // Stage1 epoch
		input [7:0]i_send_s2_epoch; // Stage2 epoch
		input integer i_send_seq; // 事务序号
		begin
			@(negedge i_clk);
			i_result_ready = 1'b1; // 定向算术用例持续开放下游
			drive_transaction(i_send_precision, i_send_s1, i_send_d2, i_send_s2_raw,
				i_send_gain, i_send_offset, i_send_s1_valid, i_send_s2_valid,
				i_send_cfg, i_send_coef, i_send_s2_epoch, i_send_seq); // 驱动完整事务
			i_result_valid = 1'b1; // 保持上游valid完成握手
			@(posedge i_clk);
			#1;
			check_transaction(i_send_id); // 检查一拍寄存后的结果
		end
	endtask

	//-------------主要任务处理区域-------------//
	// 产生10 ns周期测试时钟
	always begin
		#5;
		i_clk = ~i_clk; // 时钟每5 ns翻转
	end

	// 执行PR-01至PR-14定向检查和1024个S2码遍历
	initial begin
		i_clk = 1'b0; i_rstn = 1'b0; i_active_valid = 1'b0; i_stage2_calibration_valid = 1'b0; // 初始化全局控制
		i_stage2_gain_q16 = STAGE2_GAIN_NOMINAL_Q16; i_stage2_offset_q16 = 32'sd0; i_stage2_coef_epoch = 8'd0; // 初始化Stage2配置
		i_result_valid = 1'b0; i_calibrated_s1_value = 12'sd0; i_calibration_applied = 1'b0; i_saturation_low = 1'b0; i_saturation_high = 1'b0; // 初始化Stage1输入
		i_config_epoch = 8'd0; i_coef_epoch = 8'd0; i_detect_code = 9'd0; i_stage1_raw = 10'd0; i_stage1_code_ext = 11'sd0; // 初始化Stage1元数据
		i_stage2_raw = 10'd0; i_stage2_code_ext = 11'sd0; i_nominal_15_code = 15'sd0; i_nominal_15_valid = 1'b0; i_nominal_saturated = 1'b0; // 初始化Stage2旁路
		i_precision_mode = 1'b0; i_frame_id = 16'd0; i_sample_index = 16'd0; i_color_ir = 1'b0; i_frame_type = 2'b10; // 初始化PPG身份
		i_amb_code_snapshot = 8'd0; i_dc_code_snapshot = 8'd0; i_amb_code_epoch = 4'd0; i_dc_code_epoch = 4'd0; i_result_ready = 1'b0; // 初始化IDAC和握手
		cnt_error = 0; reg_expected_code = 15'sd0; reg_expected_low = 1'b0; reg_expected_high = 1'b0; reg_payload_hold = 0; // 初始化比较状态
		#2;
		if((o_result_ready !== 1'b0) || (o_result_valid !== 1'b0) || (dec_observed_payload !== 0))begin
			cnt_error = cnt_error + 1; // PR-01复位输出必须全零
			$display("FAIL PR-01 reset outputs"); // 报告复位失败
		end
		@(negedge i_clk); i_rstn = 1'b1; i_active_valid = 1'b1; i_stage2_calibration_valid = 1'b1; // 释放复位并装入合法配置

		// PR-02：9-bit事务只透传不生成15-bit结果
		send_transaction(2, 1'b0, 12'sd321, 11'sd444, 10'h2aa, STAGE2_GAIN_NOMINAL_Q16, 32'sd123456, 1'b1, 1'b1, 8'h12, 8'h34, 8'h56, 2);
		// PR-03：标称Stage2系数独立黄金结果
		send_transaction(3, 1'b1, 12'sd300, 11'sd310, 10'h155, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b1, 8'h13, 8'h35, 8'h57, 3);
		// PR-04：增益变化应改变非零D2中心项结果
		send_transaction(4, 1'b1, 12'sd256, 11'sd300, 10'h12c, 20'sd40000, 32'sd0, 1'b1, 1'b1, 8'h14, 8'h36, 8'h58, 4);
		reg_payload_hold = dec_observed_payload; // 保存增益变化前结果字段
		send_transaction(4, 1'b1, 12'sd256, 11'sd300, 10'h12c, 20'sd70000, 32'sd0, 1'b1, 1'b1, 8'h14, 8'h36, 8'h59, 5);
		if(o_programmable_15_code === reg_payload_hold[185:171])begin
			cnt_error = cnt_error + 1; // PR-04防止Stage2增益通路恒定
			$display("FAIL PR-04 gain did not change result"); // 报告增益无效
		end
		// PR-05：正负offset符号扩展
		send_transaction(5, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, 32'sd65536, 1'b1, 1'b1, 8'h15, 8'h37, 8'h5a, 6);
		send_transaction(5, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, -32'sd65536, 1'b1, 1'b1, 8'h15, 8'h37, 8'h5a, 7);
		// PR-06：正负半LSB边界由黄金模型逐笔比较
		send_transaction(6, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, 32'sd32768, 1'b1, 1'b1, 8'h16, 8'h38, 8'h5b, 8);
		send_transaction(6, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, -32'sd32768, 1'b1, 1'b1, 8'h16, 8'h38, 8'h5b, 9);
		// PR-06补强（ABCD F-027）：上面两笔offset=±32768只把总累加值移开半LSB，并未落在舍入门限；
		// S1=256、D2=256时ACC_Q17=3533837+2*offset恒为奇数，取ACC=±65535/±65537这四个可达门限邻点，
		// 期望输出独立按合同取整写成字面量0/1/0/-1，并同时经黄金模型逐笔比较
		send_transaction(6, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, -32'sd1734151, 1'b1, 1'b1, 8'h16, 8'h38, 8'h5b, 12); // ACC=+65535
		if(o_programmable_15_code !== 15'sd0)begin
			cnt_error = cnt_error + 1; // PR-06正侧门限下方邻点取整错误
			$display("FAIL PR-06 ACC=+65535 expected 0 got %0d", o_programmable_15_code); // 报告正侧门限下方错误
		end
		send_transaction(6, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, -32'sd1734150, 1'b1, 1'b1, 8'h16, 8'h38, 8'h5b, 13); // ACC=+65537
		if(o_programmable_15_code !== 15'sd1)begin
			cnt_error = cnt_error + 1; // PR-06正侧门限上方邻点取整错误
			$display("FAIL PR-06 ACC=+65537 expected 1 got %0d", o_programmable_15_code); // 报告正侧门限上方错误
		end
		send_transaction(6, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, -32'sd1799686, 1'b1, 1'b1, 8'h16, 8'h38, 8'h5b, 14); // ACC=-65535
		if(o_programmable_15_code !== 15'sd0)begin
			cnt_error = cnt_error + 1; // PR-06负侧门限内侧邻点取整错误
			$display("FAIL PR-06 ACC=-65535 expected 0 got %0d", o_programmable_15_code); // 报告负侧门限内侧错误
		end
		send_transaction(6, 1'b1, 12'sd256, 11'sd256, 10'h100, 20'sd0, -32'sd1799687, 1'b1, 1'b1, 8'h16, 8'h38, 8'h5b, 15); // ACC=-65537
		if(o_programmable_15_code !== -15'sd1)begin
			cnt_error = cnt_error + 1; // PR-06负侧门限外侧邻点取整错误
			$display("FAIL PR-06 ACC=-65537 expected -1 got %0d", o_programmable_15_code); // 报告负侧门限外侧错误
		end
		// PR-07：大幅正负offset触发15-bit饱和
		send_transaction(7, 1'b1, 12'sd2047, 11'sd515, 10'h3ff, 20'sd524287, 32'sd2147483647, 1'b1, 1'b1, 8'h17, 8'h39, 8'h5c, 10);
		send_transaction(7, 1'b1, -12'sd2048, -11'sd4, 10'h000, -20'sd524288, -32'sd2147483648, 1'b1, 1'b1, 8'h17, 8'h39, 8'h5c, 11);
		// PR-08：遍历全部1024个Stage2物理码
		for(cnt_raw = 0; cnt_raw < 1024; cnt_raw = cnt_raw + 1)begin
			cnt_expected_d2 = ((((cnt_raw >> 4) & 63) * 8) + (cnt_raw & 7) + (((cnt_raw >> 3) & 1) ? 4 : -4)); // 独立D2_EXT公式
			send_transaction(8, 1'b1, 12'sd256, cnt_expected_d2, cnt_raw[9:0], STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b1, 8'h18, 8'h3a, 8'h5d, cnt_raw + 100);
		end
		@(negedge i_clk); i_result_valid = 1'b0; i_result_ready = 1'b1; // 排空最后一笔逐码结果
		@(posedge i_clk); #1;
		if(o_result_valid !== 1'b0)begin
			cnt_error = cnt_error + 1; // PR-08检查单次消费
			$display("FAIL PR-08 drain"); // 报告排空失败
		end
		// PR-09和PR-13：反压期间保持完整payload且ready拉低
		@(negedge i_clk); i_result_ready = 1'b0; drive_transaction(1'b1, 12'sd400, 11'sd333, 10'h2d3, STAGE2_GAIN_NOMINAL_Q16, 32'sd77777, 1'b1, 1'b1, 8'hf0, 8'hf1, 8'hf2, 16'h900); i_result_valid = 1'b1; // 装入反压事务
		@(posedge i_clk); #1; check_transaction(9); reg_payload_hold = dec_observed_payload; // 保存反压起点payload
		for(cnt_hold = 0; cnt_hold < 4; cnt_hold = cnt_hold + 1)begin
			@(negedge i_clk); drive_transaction(1'b1, -12'sd700 + cnt_hold, -11'sd4 + cnt_hold, 10'h001 + cnt_hold, -20'sd30000, -32'sd1234567, 1'b0, 1'b0, cnt_hold, cnt_hold + 8'h10, cnt_hold + 8'h20, 16'ha00 + cnt_hold); i_result_valid = 1'b1; // 扰动所有输入配置总线
			@(posedge i_clk); #1;
			if((o_result_ready !== 1'b0) || (o_result_valid !== 1'b1) || (dec_observed_payload !== reg_payload_hold))begin
				cnt_error = cnt_error + 1; // PR-09反压保持必须完全稳定
				$display("FAIL PR-09/13 hold cycle=%0d", cnt_hold); // 报告反压期间载荷漂移
			end
		end
		// PR-10：消费旧事务并同拍替换新事务
		@(negedge i_clk); i_result_ready = 1'b1; drive_transaction(1'b1, 12'sd355, 11'sd299, 10'h12b, 20'sd60000, -32'sd33333, 1'b1, 1'b0, 8'ha0, 8'ha1, 8'ha2, 16'hb00); i_result_valid = 1'b1; // 同拍提供替换事务
		@(posedge i_clk); #1; check_transaction(10); // PR-10要求valid连续且载荷替换
		// PR-11：四种Stage1/Stage2资格组合
		send_transaction(11, 1'b1, 12'sd270, 11'sd280, 10'h118, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b0, 1'b0, 8'h21, 8'h41, 8'h61, 16'hc00);
		send_transaction(11, 1'b1, 12'sd270, 11'sd280, 10'h118, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b0, 1'b1, 8'h21, 8'h41, 8'h62, 16'hc01);
		send_transaction(11, 1'b1, 12'sd270, 11'sd280, 10'h118, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b0, 8'h21, 8'h42, 8'h61, 16'hc02);
		send_transaction(11, 1'b1, 12'sd270, 11'sd280, 10'h118, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b1, 8'h21, 8'h42, 8'h62, 16'hc03);
		// PR-12：epoch回绕不改变资格判定规则
		send_transaction(12, 1'b1, 12'sd280, 11'sd290, 10'h122, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b0, 1'b0, 8'hff, 8'hff, 8'hff, 16'hd00);
		send_transaction(12, 1'b1, 12'sd280, 11'sd290, 10'h122, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b1, 8'h00, 8'h00, 8'h00, 16'hd01);
		// PR-14：9/15/9/15连续切换
		send_transaction(14, 1'b0, 12'sd290, 11'sd300, 10'h12c, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b1, 8'h31, 8'h51, 8'h71, 16'he00);
		send_transaction(14, 1'b1, 12'sd291, 11'sd301, 10'h12d, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b1, 8'h32, 8'h52, 8'h72, 16'he01);
		send_transaction(14, 1'b0, 12'sd292, 11'sd302, 10'h12e, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b1, 8'h33, 8'h53, 8'h73, 16'he02);
		send_transaction(14, 1'b1, 12'sd293, 11'sd303, 10'h12f, STAGE2_GAIN_NOMINAL_Q16, 32'sd0, 1'b1, 1'b1, 8'h34, 8'h54, 8'h74, 16'he03);
		// PR-01补充：异步复位立即清除等待事务
		@(negedge i_clk); i_result_valid = 1'b0; i_result_ready = 1'b0; #2; i_rstn = 1'b0; #1;
		if((o_result_ready !== 1'b0) || (o_result_valid !== 1'b0) || (dec_observed_payload !== 0))begin
			cnt_error = cnt_error + 1; // 复位必须清除valid和全部payload
			$display("FAIL PR-01 asynchronous reset"); // 报告异步复位清除失败
		end
		if(cnt_error == 0)begin
			$display("PASS ppg_adc_programmable_reconstructor PR-01..PR-14 and 1024-code sweep"); // 真实比较全部通过后报告PASS
		end else begin
			$display("FAIL ppg_adc_programmable_reconstructor errors=%0d", cnt_error); // 汇总失败数量
		end
		#20; $finish; // 正常结束仿真
	end

	// 看门狗防止ready/valid错误导致测试无限等待
	initial begin
		#2000000; $display("FAIL ppg_adc_programmable_reconstructor watchdog timeout"); $finish; // 超时终止挂起仿真
	end

	//------------模块实例化区域------------//
	// 实例化待验证的15-bit可编程重构器
	ppg_adc_programmable_reconstructor
	#(
		.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 连接帧号参数
		.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 连接样本参数
		.C_IDAC_CODE_WIDTH(C_IDAC_CODE_WIDTH), // 连接IDAC码参数
		.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 连接IDAC版本参数
		.C_CONFIG_EPOCH_WIDTH(C_CONFIG_EPOCH_WIDTH), // 连接配置版本参数
		.C_COEF_EPOCH_WIDTH(C_COEF_EPOCH_WIDTH) // 连接系数版本参数
	)ppg_adc_programmable_reconstructor_Inst_dut(
		.i_clk(i_clk), .i_rstn(i_rstn), .i_active_valid(i_active_valid), .i_stage2_calibration_valid(i_stage2_calibration_valid), .i_stage2_gain_q16(i_stage2_gain_q16), .i_stage2_offset_q16(i_stage2_offset_q16), .i_stage2_coef_epoch(i_stage2_coef_epoch), .i_result_valid(i_result_valid), .i_calibrated_s1_value(i_calibrated_s1_value), .i_calibration_applied(i_calibration_applied), .i_saturation_low(i_saturation_low), .i_saturation_high(i_saturation_high), .i_config_epoch(i_config_epoch), .i_coef_epoch(i_coef_epoch), .i_detect_code(i_detect_code), .i_stage1_raw(i_stage1_raw), .i_stage1_code_ext(i_stage1_code_ext), .i_stage2_raw(i_stage2_raw), .i_stage2_code_ext(i_stage2_code_ext), .i_nominal_15_code(i_nominal_15_code), .i_nominal_15_valid(i_nominal_15_valid), .i_nominal_saturated(i_nominal_saturated), .i_precision_mode(i_precision_mode), .i_frame_id(i_frame_id), .i_sample_index(i_sample_index), .i_color_ir(i_color_ir), .i_frame_type(i_frame_type), .i_amb_code_snapshot(i_amb_code_snapshot), .i_dc_code_snapshot(i_dc_code_snapshot), .i_amb_code_epoch(i_amb_code_epoch), .i_dc_code_epoch(i_dc_code_epoch), .o_result_ready(o_result_ready), .i_result_ready(i_result_ready), .o_result_valid(o_result_valid), .o_programmable_15_code(o_programmable_15_code), .o_programmable_15_valid(o_programmable_15_valid), .o_programmable_15_calibration_applied(o_programmable_15_calibration_applied), .o_programmable_saturation_low(o_programmable_saturation_low), .o_programmable_saturation_high(o_programmable_saturation_high), .o_stage2_coef_epoch(o_stage2_coef_epoch), .o_calibrated_s1_value(o_calibrated_s1_value), .o_calibration_applied(o_calibration_applied), .o_stage1_saturation_low(o_stage1_saturation_low), .o_stage1_saturation_high(o_stage1_saturation_high), .o_config_epoch(o_config_epoch), .o_coef_epoch(o_coef_epoch), .o_detect_code(o_detect_code), .o_stage1_raw(o_stage1_raw), .o_stage1_code_ext(o_stage1_code_ext), .o_stage2_raw(o_stage2_raw), .o_stage2_code_ext(o_stage2_code_ext), .o_nominal_15_code(o_nominal_15_code), .o_nominal_15_valid(o_nominal_15_valid), .o_nominal_saturated(o_nominal_saturated), .o_precision_mode(o_precision_mode), .o_frame_id(o_frame_id), .o_sample_index(o_sample_index), .o_color_ir(o_color_ir), .o_frame_type(o_frame_type), .o_amb_code_snapshot(o_amb_code_snapshot), .o_dc_code_snapshot(o_dc_code_snapshot), .o_amb_code_epoch(o_amb_code_epoch), .o_dc_code_epoch(o_dc_code_epoch) // 连接完整冻结接口
	);

endmodule
