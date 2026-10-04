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
// Version:            V1.0
// Revision Date:      2026/08/07
// History:
//    Time               Version       Revised by            Contents
// 2026/08/07            V1.0          Erie                  Create self-checking testbench.
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
// 当前版本:           V1.0
// 修订日期:           2026年08月07日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月07日        V1.0          Erie                  创建PR-01至PR-14自检平台

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
		i_clk=0; i_rstn=0; i_active_valid=1; i_result_valid=0; i_result_ready=1; cnt_error=0;
		drive_transaction(0,256,256,0,0,0,1,1,1,1,1,0);
		#2; if (o_result_valid !== 0 || o_result_ready !== 0) $fatal(1,"C_PR reset failure");
		@(negedge i_clk); i_rstn=1;
		@(negedge i_clk); drive_transaction(1,256,256,0,0,-32'sd1734151,1,1,1,1,1,1); i_result_valid=1;
		@(posedge i_clk); #1; if(o_result_valid !== 1 || o_programmable_15_code !== 15'sd0 || o_programmable_saturation_low !== 0 || o_programmable_saturation_high !== 0) $fatal(1,"C_PR half-boundary case 0 got=%0d",$signed(o_programmable_15_code));
		$display("PASS C_PR half-boundary 0 expected=0");
		@(negedge i_clk); drive_transaction(1,256,256,0,0,-32'sd1734150,1,1,1,1,1,2); i_result_valid=1;
		@(posedge i_clk); #1; if(o_result_valid !== 1 || o_programmable_15_code !== 15'sd1 || o_programmable_saturation_low !== 0 || o_programmable_saturation_high !== 0) $fatal(1,"C_PR half-boundary case 1 got=%0d",$signed(o_programmable_15_code));
		$display("PASS C_PR half-boundary 1 expected=1");
		@(negedge i_clk); drive_transaction(1,256,256,0,0,-32'sd1799686,1,1,1,1,1,3); i_result_valid=1;
		@(posedge i_clk); #1; if(o_result_valid !== 1 || o_programmable_15_code !== 15'sd0 || o_programmable_saturation_low !== 0 || o_programmable_saturation_high !== 0) $fatal(1,"C_PR half-boundary case 2 got=%0d",$signed(o_programmable_15_code));
		$display("PASS C_PR half-boundary 2 expected=0");
		@(negedge i_clk); drive_transaction(1,256,256,0,0,-32'sd1799687,1,1,1,1,1,4); i_result_valid=1;
		@(posedge i_clk); #1; if(o_result_valid !== 1 || o_programmable_15_code !== -15'sd1 || o_programmable_saturation_low !== 0 || o_programmable_saturation_high !== 0) $fatal(1,"C_PR half-boundary case 3 got=%0d",$signed(o_programmable_15_code));
		$display("PASS C_PR half-boundary 3 expected=-1");
		$display("PASS C_PR 4 independent half-boundary vectors"); $finish;
	end

	// 看门狗防止ready/valid错误导致测试无限等待
	initial begin
		#2000000; $fatal(1,"C_PR watchdog timeout"); // 超时终止挂起仿真
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
