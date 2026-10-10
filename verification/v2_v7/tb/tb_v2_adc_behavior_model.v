`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 ADC Behaviour Model Self-Check Testbench
// Module Name:     tb_v2_adc_behavior_model
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.1
// Simulations:     Vivado xsim 2022.2
//
// Referrences:     verification/v2_v7/adc_model/v2_adc_behavior_model.v
//
// Dependencies:    v2_adc_behavior_model.v
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Drives synthetic Q3 windows, transaction-start and ADC_RST pulses into the model without any DUT and measures every output edge cycle by cycle: compatibility pulse (width 5, one cycle after Q3 closes, idle low only during the pulse), the three level modes (rise exactly i_latency edges after the Q3 rise, held until the selected ADC_RST event), both idle formulas, 15-bit Stage1-before-Stage2 ordering, DOUT stable before the rising edge, lost / late / busy-recover / busy-forever faults, and per-slot occurrence selection. Every check prints ADCM-PASS or ADCM-FAIL with the measured values; the closing line is ADCM_SELFTEST_PASS only when every check passed and the expected number of checks ran.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2 ADC行为模型自检测试平台
// 模块名称:        tb_v2_adc_behavior_model
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.1节
// 仿真工程:        Vivado xsim 2022.2
//
// 参考资料:        verification/v2_v7/adc_model/v2_adc_behavior_model.v
//
// 依赖文件:        v2_adc_behavior_model.v
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。不接DUT，直接向模型施加人造Q3窗口、事务启动与ADC_RST脉冲，逐拍测量各输出沿：兼容脉冲（宽5拍、Q3关闭后一拍、仅脉冲期间idle为低）、三种电平模式（Q3上升沿后恰好i_latency拍上升，保持到所选ADC_RST事件）、两种idle公式、15位Stage1先于Stage2、DOUT先于上升沿稳定、丢失/迟到/忙后恢复/永久忙故障、按槽位序号命中。每项检查打印ADCM-PASS或ADCM-FAIL及实测值；只有全部通过且检查数等于预期时才打印ADCM_SELFTEST_PASS。

// ADC行为模型自检：人造激励逐拍测量完成电平、码线与物理空闲
module tb_v2_adc_behavior_model();

	//---------------配置参数区域---------------//
	localparam integer C_EXPECTED_CHECKS = 46;       // 本自检预期执行的检查条数

	//---------------全局时钟与复位信号---------------//
	reg i_clk;                                       // 2 MHz激励时钟
	reg i_rstn;                                      // 模型低有效复位

	//---------------模型激励信号---------------//
	reg i_q1; // 人造CLK_Q1窗口电平
	reg i_q3;                                        // 人造Q3窗口电平
	reg i_txn_start;                                 // 人造事务启动单拍
	reg i_adc_rst;                                   // 人造外部ADC_RST单拍
	reg [1:0] i_owner_slot;                          // 人造owner槽位
	reg i_owner_precision;                           // 人造owner精度
	reg i_active_precision;                          // 人造实时提交精度
	reg [15:0] i_frame_id;                           // 人造宏帧号
	reg [12:0] i_macro_tick;                         // 人造宏帧相位
	reg [1:0] i_done_mode;                           // 被测DONE形态
	reg i_idle_mode;                                 // 被测idle公式
	reg [7:0] i_latency;                             // 被测转换时延
	reg [9:0] i_raw_stage1;                          // 激励Stage1码
	reg [9:0] i_raw_stage2;                          // 激励Stage2码
	reg i_fault_arm;                                 // 故障武装单拍
	reg [2:0] i_fault_mode;                          // 故障类型
	reg [1:0] i_fault_slot;                          // 故障槽位
	reg [15:0] i_fault_serial;                       // 故障首个序号
	reg [7:0] i_fault_count;                         // 故障连续笔数
	reg [2:0] i_fault_frame_offset;                  // 落点帧偏移
	reg [12:0] i_fault_release_tick;                 // 落点相位

	//---------------模型输出观测信号---------------//
	wire [9:0] o_dout_stage1;                        // 模型Stage1码
	wire o_clk_stage1_dout;                          // 模型Stage1完成
	wire [9:0] o_dout_stage2;                        // 模型Stage2码
	wire o_clk_stage2_dout;                          // 模型Stage2完成
	wire o_adc_physical_idle;                        // 模型物理空闲
	wire o_conv_start_event;                         // 模型转换开始事件
	wire o_done_rise_event;                          // 模型完成上升事件
	wire o_fault_hit_event;                          // 模型故障命中事件
	wire [15:0] o_slot_serial;                       // 模型槽位序号

	//---------------自检计数信号---------------//
	integer cnt_cycle;                               // 自复位释放起的拍号
	integer cnt_pass;                                // 通过检查数
	integer cnt_fail;                                // 失败检查数
	integer t_q1_seen; // 模型看到Q1高的首个拍号
	integer t_s2_fall; // Stage2完成回低后首个拍号
	reg flag_q1_prev_tb; // Q1上一拍值
	integer t_q3_seen;                               // 模型看到Q3高的首个拍号
	integer t_q3_fall_seen;                          // 模型看到Q3回低的首个拍号
	integer t_s1_rise;                               // Stage1完成上升后首个拍号
	integer t_s1_fall;                               // Stage1完成回低后首个拍号
	integer t_s2_rise;                               // Stage2完成上升后首个拍号
	integer t_idle_fall;                             // 物理空闲回低后首个拍号
	integer t_idle_rise;                             // 物理空闲回高后首个拍号
	integer n_s1_rise;                               // 窗口内Stage1上升次数
	integer n_s2_rise;                               // 窗口内Stage2上升次数
	reg [9:0] reg_dout1_at_rise;                     // Stage1上升前一拍的码线
	reg flag_s1_prev;                                // Stage1完成上一拍值
	reg flag_s2_prev;                                // Stage2完成上一拍值
	reg flag_idle_prev;                              // 物理空闲上一拍值
	reg flag_q3_prev_tb;                             // Q3上一拍值
	reg [9:0] reg_dout1_prev;                        // 码线上一拍值

	//---------------被测模型实例---------------//
	v2_adc_behavior_model
		v2_adc_behavior_model_Inst(
			.i_clk(i_clk),                           // 激励时钟
			.i_rstn(i_rstn),                         // 激励复位
			.i_q1(i_q1), // 人造Q1
			.i_q3(i_q3),                             // 人造Q3
			.i_txn_start(i_txn_start),               // 人造启动
			.i_adc_rst(i_adc_rst),                   // 人造ADC_RST
			.i_owner_slot(i_owner_slot),             // 人造槽位
			.i_owner_precision(i_owner_precision),   // 人造精度
			.i_active_precision(i_active_precision), // 人造实时精度
			.i_frame_id(i_frame_id),                 // 人造帧号
			.i_macro_tick(i_macro_tick),             // 人造相位
			.i_done_mode(i_done_mode),               // 被测DONE形态
			.i_idle_mode(i_idle_mode),
			.i_idle_delay(2'd0), // 自测不加同步延迟，沿口径与预期值一致               // 被测idle公式
			.i_latency(i_latency),                   // 被测时延
			.i_raw_stage1(i_raw_stage1),             // 激励Stage1码
			.i_raw_stage2(i_raw_stage2),             // 激励Stage2码
			.i_fault_arm(i_fault_arm),               // 故障武装
			.i_fault_mode(i_fault_mode),             // 故障类型
			.i_fault_slot(i_fault_slot),             // 故障槽位
			.i_fault_serial(i_fault_serial),         // 故障序号
			.i_fault_count(i_fault_count),           // 故障笔数
			.i_fault_frame_offset(i_fault_frame_offset), // 落点帧偏移
			.i_fault_release_tick(i_fault_release_tick), // 落点相位
			.o_dout_stage1(o_dout_stage1),           // 观测Stage1码
			.o_clk_stage1_dout(o_clk_stage1_dout),   // 观测Stage1完成
			.o_dout_stage2(o_dout_stage2),           // 观测Stage2码
			.o_clk_stage2_dout(o_clk_stage2_dout),   // 观测Stage2完成
			.o_adc_physical_idle(o_adc_physical_idle), // 观测物理空闲
			.o_conv_start_event(o_conv_start_event), // 观测转换开始
			.o_done_rise_event(o_done_rise_event),   // 观测完成上升
			.o_fault_hit_event(o_fault_hit_event),   // 观测故障命中
			.o_slot_serial(o_slot_serial)            // 观测槽位序号
		);

	//---------------时钟发生器---------------//
	initial begin
		i_clk = 1'b0;                                // 时钟初值
		forever #250 i_clk = ~i_clk;                 // 500 ns周期即2 MHz
	end

	//---------------人造宏帧相位发生器---------------//
	// 帧号与相位在上升沿推进，供迟到与忙释放落点比较
	always @(posedge i_clk) begin
		if(!i_rstn) begin
			i_macro_tick <= 13'd0;                   // 复位期间相位归零
			i_frame_id <= 16'd0;                     // 复位期间帧号归零
		end else if(i_macro_tick == 13'd4999) begin
			i_macro_tick <= 13'd0;                   // 末拍后进入下一帧
			i_frame_id <= i_frame_id + 16'd1;        // 帧号加一
		end else begin
			i_macro_tick <= i_macro_tick + 13'd1;    // 帧内相位递增
		end
	end

	//---------------逐拍沿测量进程---------------//
	// 在每个上升沿之后采样输出，记录各沿首次出现的拍号；模型输出在上升沿更新，故记录的是"更新后首拍"
	always @(posedge i_clk) begin
		#1;
		cnt_cycle = cnt_cycle + 1;                   // 拍号推进
		if(i_q1 && !flag_q1_prev_tb && (t_q1_seen < 0)) t_q1_seen = cnt_cycle; // 模型在本沿看到Q1高
		if(!o_clk_stage2_dout && flag_s2_prev && (t_s2_fall < 0)) t_s2_fall = cnt_cycle; // 记录首个Stage2回低
		flag_q1_prev_tb = i_q1; // 推进Q1历史
		if(i_q3 && !flag_q3_prev_tb && (t_q3_seen < 0)) t_q3_seen = cnt_cycle; // 模型在本沿看到Q3高
		if(!i_q3 && flag_q3_prev_tb && (t_q3_fall_seen < 0)) t_q3_fall_seen = cnt_cycle; // 模型在本沿看到Q3回低
		if(o_clk_stage1_dout && !flag_s1_prev) begin
			n_s1_rise = n_s1_rise + 1;               // 统计Stage1上升
			if(t_s1_rise < 0) begin
				t_s1_rise = cnt_cycle;               // 记录首个Stage1上升
				reg_dout1_at_rise = reg_dout1_prev;  // 记录上升前一拍码线
			end
		end
		if(!o_clk_stage1_dout && flag_s1_prev && (t_s1_fall < 0)) t_s1_fall = cnt_cycle; // 记录首个Stage1回低
		if(o_clk_stage2_dout && !flag_s2_prev) begin
			n_s2_rise = n_s2_rise + 1;               // 统计Stage2上升
			if(t_s2_rise < 0) t_s2_rise = cnt_cycle; // 记录首个Stage2上升
		end
		if(!o_adc_physical_idle && flag_idle_prev && (t_idle_fall < 0)) t_idle_fall = cnt_cycle; // 记录idle回低
		if(o_adc_physical_idle && !flag_idle_prev && (t_idle_rise < 0)) t_idle_rise = cnt_cycle; // 记录idle回高
		flag_s1_prev = o_clk_stage1_dout;            // 推进Stage1历史
		flag_s2_prev = o_clk_stage2_dout;            // 推进Stage2历史
		flag_idle_prev = o_adc_physical_idle;        // 推进idle历史
		flag_q3_prev_tb = i_q3;                      // 推进Q3历史
		reg_dout1_prev = o_dout_stage1;              // 推进码线历史
	end

	//---------------检查任务---------------//
	// 打印单条检查结论并计数
	task adcm_check;
		input [8 * 32 - 1:0] label;                  // 检查名
		input cond;                                  // 检查条件
		begin
			if(cond === 1'b1) begin
				cnt_pass = cnt_pass + 1;             // 通过计数
				$display("ADCM-PASS %0s q3=%0d q3f=%0d s1r=%0d s1f=%0d s2r=%0d idlef=%0d idler=%0d n1=%0d n2=%0d", label, t_q3_seen, t_q3_fall_seen, t_s1_rise, t_s1_fall, t_s2_rise, t_idle_fall, t_idle_rise, n_s1_rise, n_s2_rise); // 通过行带实测值
			end else begin
				cnt_fail = cnt_fail + 1;             // 失败计数
				$display("ADCM-FAIL %0s q3=%0d q3f=%0d s1r=%0d s1f=%0d s2r=%0d idlef=%0d idler=%0d n1=%0d n2=%0d", label, t_q3_seen, t_q3_fall_seen, t_s1_rise, t_s1_fall, t_s2_rise, t_idle_fall, t_idle_rise, n_s1_rise, n_s2_rise); // 失败行带实测值
			end
		end
	endtask

	// 清空沿测量记录，开始新一次测量
	task adcm_clear;
		begin
			t_q1_seen = -1; // 清Q1记录
			t_s2_fall = -1; // 清Stage2回低记录
			t_q3_seen = -1;                          // 清Q3记录
			t_q3_fall_seen = -1;                     // 清Q3回低记录
			t_s1_rise = -1;                          // 清Stage1上升记录
			t_s1_fall = -1;                          // 清Stage1回低记录
			t_s2_rise = -1;                          // 清Stage2上升记录
			t_idle_fall = -1;                        // 清idle回低记录
			t_idle_rise = -1;                        // 清idle回高记录
			n_s1_rise = 0;                           // 清Stage1次数
			n_s2_rise = 0;                           // 清Stage2次数
		end
	endtask

	// 施加一笔owner的模拟时序：Q1先拉高9拍，第7拍起Q3拉高2拍（与SAR9 RED的Q1 293、Q3 300相对位置一致）
	task adcm_q3;
		begin
			@(negedge i_clk); i_q1 = 1'b1;           // Q1拉高
			repeat(7) @(negedge i_clk);              // Q1领先Q3 7拍
			i_q3 = 1'b1;                             // Q3拉高
			@(negedge i_clk);                        // Q3保持第2拍
			@(negedge i_clk); i_q3 = 1'b0; i_q1 = 1'b0; // Q3与Q1同拍回低
		end
	endtask

	// 只施加Q3、不施加Q1，用于证明保持型DONE不被Q3清除
	task adcm_q3_only;
		begin
			@(negedge i_clk); i_q3 = 1'b1;           // Q3单独拉高
			@(negedge i_clk);                        // Q3保持第2拍
			@(negedge i_clk); i_q3 = 1'b0;           // Q3单独回低
		end
	endtask

	// 在下降沿施加单拍事务启动
	task adcm_start;
		begin
			@(negedge i_clk); i_txn_start = 1'b1;    // 启动拉高
			@(negedge i_clk); i_txn_start = 1'b0;    // 启动回低
		end
	endtask

	// 在下降沿施加单拍外部ADC_RST
	task adcm_rst;
		begin
			@(negedge i_clk); i_adc_rst = 1'b1;      // ADC_RST拉高
			@(negedge i_clk); i_adc_rst = 1'b0;      // ADC_RST回低
		end
	endtask

	// 武装故障配置
	task adcm_arm;
		input [2:0] mode;                            // 故障类型
		input [1:0] slot;                            // 故障槽位
		input [15:0] serial;                         // 首个序号
		input [7:0] count;                           // 连续笔数
		begin
			i_fault_mode = mode;                     // 设故障类型
			i_fault_slot = slot;                     // 设故障槽位
			i_fault_serial = serial;                 // 设首个序号
			i_fault_count = count;                   // 设笔数
			@(negedge i_clk); i_fault_arm = 1'b1;    // 武装拉高
			@(negedge i_clk); i_fault_arm = 1'b0;    // 武装回低
		end
	endtask

	// 模型复位
	task adcm_reset;
		begin
			@(negedge i_clk); i_rstn = 1'b0;         // 复位拉低
			repeat(2) @(negedge i_clk);              // 复位保持
			i_rstn = 1'b1;                           // 释放复位
			repeat(2) @(negedge i_clk);              // 等待稳定
		end
	endtask

	//---------------主激励序列---------------//
	initial begin : main_sequence
		integer k;                                   // 循环变量
		integer lat;                                 // 当前被测时延
		cnt_cycle = 0;                               // 拍号初值
		cnt_pass = 0;                                // 通过数初值
		cnt_fail = 0;                                // 失败数初值
		flag_s1_prev = 1'b0;                         // 历史初值
		flag_s2_prev = 1'b0;                         // 历史初值
		flag_idle_prev = 1'b1;                       // 历史初值
		flag_q1_prev_tb = 1'b0; // Q1历史初值
		i_q1 = 1'b0; // Q1初值
		flag_q3_prev_tb = 1'b0;                      // 历史初值
		reg_dout1_prev = 10'd0;                      // 历史初值
		reg_dout1_at_rise = 10'd0;                   // 记录初值
		i_rstn = 1'b0;                               // 上电复位
		i_q3 = 1'b0;                                 // Q3初值
		i_txn_start = 1'b0;                          // 启动初值
		i_adc_rst = 1'b0;                            // ADC_RST初值
		i_owner_slot = 2'd0;                         // 槽位初值RED
		i_owner_precision = 1'b0;                    // 精度初值9位
		i_active_precision = 1'b0;                   // 实时精度初值
		i_done_mode = 2'd0;                          // 兼容模式
		i_idle_mode = 1'b0;                          // 无转换即空闲
		i_latency = 8'd10;                           // 时延初值
		i_raw_stage1 = 10'h155;                      // Stage1码初值
		i_raw_stage2 = 10'h2AA;                      // Stage2码初值
		i_fault_arm = 1'b0;                          // 武装初值
		i_fault_mode = 3'd0;                         // 无故障
		i_fault_slot = 2'd0;                         // 槽位初值
		i_fault_serial = 16'd1;                      // 序号初值
		i_fault_count = 8'd1;                        // 笔数初值
		i_fault_frame_offset = 3'd0;                 // 帧偏移初值
		i_fault_release_tick = 13'd0;                // 相位初值
		adcm_clear;                                  // 清测量记录
		repeat(3) @(negedge i_clk);                  // 复位保持
		i_rstn = 1'b1;                               // 释放复位
		repeat(3) @(negedge i_clk);                  // 等待稳定

		// 1 兼容模式9位：Q3关闭后一拍起5拍脉冲，idle只在脉冲期间为低，Stage2不动
		adcm_clear; adcm_q3; repeat(12) @(negedge i_clk);
		adcm_check("COMPAT-RISE-AFTER-Q3-FALL", t_s1_rise == t_q3_fall_seen + 1); // 回低识别后一拍上升
		adcm_check("COMPAT-WIDTH-5", (t_s1_fall - t_s1_rise) == 5); // 宽5拍
		adcm_check("COMPAT-IDLE-ONLY-PULSE", (t_idle_fall == t_s1_rise) && (t_idle_rise == t_s1_fall)); // idle与脉冲同拍
		adcm_check("COMPAT-S2-QUIET-9BIT", n_s2_rise == 0); // 9位不拉Stage2
		adcm_check("COMPAT-DOUT-BEFORE-RISE", reg_dout1_at_rise == 10'h155); // 上升前码已稳定

		// 2 兼容模式15位：Stage2随Stage1同拍
		i_owner_precision = 1'b1;
		adcm_clear; adcm_q3; repeat(12) @(negedge i_clk);
		adcm_check("COMPAT-15BIT-S2", (n_s2_rise == 1) && (t_s2_rise == t_s1_rise)); // 15位两级同拍
		i_owner_precision = 1'b0;

		// 3 电平模式1（到下次Q3）：时延2/10/20/1/30逐个核对上升拍，保持到下次Q3
		adcm_reset;
		i_done_mode = 2'd1;
		for(k = 0; k < 5; k = k + 1) begin
			lat = (k == 0) ? 2 : (k == 1) ? 10 : (k == 2) ? 20 : (k == 3) ? 1 : 30;
			i_latency = lat;
			adcm_clear; adcm_q3; repeat(lat + 6) @(negedge i_clk);
			adcm_check("LVL1-RISE-AT-LATENCY", (t_s1_rise == t_q3_seen + lat) && (n_s1_rise == 1)); // 恰好lat拍后上升
			adcm_check("LVL1-HOLD-HIGH", (o_clk_stage1_dout === 1'b1) && ((t_s1_fall < 0) || (t_s1_fall == t_q1_seen))); // 上升后持续为高
		end
		adcm_check("LVL1-IDLE-WINDOW", (t_idle_fall == t_q1_seen) && (t_idle_rise == t_s1_rise)); // 从Q1起忙到完成上升
		adcm_clear; adcm_q3; repeat(4) @(negedge i_clk);
		adcm_check("LVL1-FALL-AT-NEXT-Q1", t_s1_fall == t_q1_seen); // 下一笔owner的Q1当拍回低
		repeat(40) @(negedge i_clk);                 // 等本次30拍转换结束
		adcm_clear; adcm_q3_only; repeat(40) @(negedge i_clk);
		adcm_check("LVL1-Q3-ALONE-KEEPS", (t_s1_fall < 0) && (o_clk_stage1_dout === 1'b1)); // 没有Q1时DONE不回落

		// 4 idle公式1：DONE保持高期间idle为低
		i_idle_mode = 1'b1; i_latency = 8'd5;
		adcm_clear; adcm_q3; repeat(20) @(negedge i_clk);
		adcm_check("IDLE1-LOW-WHILE-DONE-HIGH", (o_clk_stage1_dout === 1'b1) && (o_adc_physical_idle === 1'b0)); // 完成高时不空闲
		i_idle_mode = 1'b0;

		// 5 电平模式2（到下次启动fire）
		adcm_reset;
		i_done_mode = 2'd2; i_latency = 8'd6;
		adcm_clear; adcm_q3; repeat(20) @(negedge i_clk);
		adcm_check("LVL2-HOLD-ACROSS-Q3-GAP", (o_clk_stage1_dout === 1'b1)); // 无启动时一直保持
		adcm_clear; adcm_start; repeat(2) @(negedge i_clk);
		adcm_check("LVL2-FALL-AT-START", (t_s1_fall >= 0) && (o_clk_stage1_dout === 1'b0)); // 启动后回低
		adcm_clear; adcm_q3; repeat(10) @(negedge i_clk);
		adcm_check("LVL2-NEXT-RISE", t_s1_rise == t_q3_seen + 6); // 下一笔正常上升

		// 6 电平模式3（外部ADC_RST）
		adcm_reset;
		i_done_mode = 2'd3; i_latency = 8'd4;
		adcm_clear; adcm_q3; repeat(10) @(negedge i_clk); adcm_q3; repeat(10) @(negedge i_clk);
		adcm_check("LVL3-Q3-DOES-NOT-CLEAR", o_clk_stage1_dout === 1'b1); // Q3本身不清完成
		adcm_clear; adcm_rst; repeat(2) @(negedge i_clk);
		adcm_check("LVL3-FALL-AT-RST", (t_s1_fall >= 0) && (o_clk_stage1_dout === 1'b0)); // ADC_RST清完成

		// 7 15位电平模式：Stage1比Stage2早2拍
		adcm_reset;
		i_done_mode = 2'd1; i_latency = 8'd12; i_owner_precision = 1'b1; i_active_precision = 1'b1;
		adcm_q3; repeat(18) @(negedge i_clk);        // 第一笔15位让Stage2先变高
		adcm_clear; adcm_q3; repeat(18) @(negedge i_clk);
		adcm_check("LVL15-S1-LEADS-BY-6", (t_s2_rise == t_q3_seen + 12) && (t_s1_rise == t_q3_seen + 6)); // Stage1领先最终完成6拍
		adcm_check("LVL15-S2-FALLS-AFTER-S1", (t_s2_fall == t_s1_rise + 1) && (t_s2_rise - t_s2_fall == 5)); // Stage2在Stage1上升后回落并低5拍
		adcm_check("LVL15-IDLE-AT-S2", (t_idle_fall == t_q1_seen) && (t_idle_rise == t_s2_rise)); // idle从Q1忙到最终完成
		i_latency = 8'd4;
		adcm_clear; adcm_q3; repeat(12) @(negedge i_clk);
		adcm_check("LVL15-MIN-LOW-4", (t_s1_rise == t_q3_seen + 1) && (t_s2_fall == t_q3_seen + 2) && (t_s2_rise == t_q3_seen + 6)); // 时延过短时Stage2仍至少低4拍
		i_owner_precision = 1'b0; i_active_precision = 1'b0;

		// 8 丢失：不发DONE，idle照常回1
		adcm_reset;
		i_done_mode = 2'd1; i_latency = 8'd8;
		adcm_arm(3'd1, 2'd0, 16'd1, 8'd1);
		adcm_clear; adcm_q3; repeat(16) @(negedge i_clk);
		adcm_check("LOST-NO-DONE", n_s1_rise == 0); // 不发完成
		adcm_check("LOST-IDLE-BACK", (t_idle_fall == t_q1_seen) && (t_idle_rise == t_q3_seen + 8)); // idle按时延回高
		adcm_clear; adcm_q3; repeat(16) @(negedge i_clk);
		adcm_check("LOST-ONLY-SERIAL-1", n_s1_rise == 1); // 第2笔不再命中

		// 9 迟到到下一帧tick 400：转换期间一直忙，落点当拍完成并回空闲
		adcm_reset;
		i_done_mode = 2'd1; i_latency = 8'd8; i_fault_frame_offset = 3'd1; i_fault_release_tick = 13'd400;
		adcm_arm(3'd2, 2'd0, 16'd1, 8'd1);
		adcm_clear; adcm_q3;
		k = 0; while(!(o_clk_stage1_dout === 1'b1) && (k < 12000)) begin @(negedge i_clk); k = k + 1; end
		adcm_check("LATE-AT-ABS-TICK", (o_clk_stage1_dout === 1'b1) && (i_macro_tick == 13'd401) && (n_s1_rise == 1)); // 下一帧400后首拍为高
		adcm_check("LATE-BUSY-UNTIL-DONE", t_idle_rise == t_s1_rise); // 落点前一直忙

		// 10 忙后恢复：落点回空闲且不发DONE
		adcm_reset;
		i_fault_frame_offset = 3'd0; i_fault_release_tick = i_macro_tick + 13'd300;
		adcm_arm(3'd3, 2'd0, 16'd1, 8'd1);
		adcm_clear; adcm_q3;
		k = 0; while(!(o_adc_physical_idle === 1'b1 && t_idle_fall >= 0) && (k < 12000)) begin @(negedge i_clk); k = k + 1; end
		repeat(5) @(negedge i_clk);
		adcm_check("BUSY-RECOVER-NO-DONE", (n_s1_rise == 0) && (t_idle_rise > t_idle_fall + 200)); // 忙到落点后空闲且无完成

		// 11 永久忙：保持忙直到重新武装
		adcm_reset;
		adcm_arm(3'd4, 2'd0, 16'd1, 8'd1);
		adcm_clear; adcm_q3; repeat(3000) @(negedge i_clk);
		adcm_check("FOREVER-BUSY", (o_adc_physical_idle === 1'b0) && (n_s1_rise == 0)); // 3000拍后仍忙
		adcm_arm(3'd0, 2'd0, 16'd1, 8'd1); repeat(2) @(negedge i_clk);
		adcm_check("FOREVER-RELEASE-BY-ARM", o_adc_physical_idle === 1'b1); // 武装解除

		// 12 按槽位序号命中：IR序号2丢失，RED与IR序号1不受影响
		adcm_reset;
		i_latency = 8'd4;
		adcm_arm(3'd1, 2'd1, 16'd2, 8'd1);
		i_owner_slot = 2'd0; adcm_clear; adcm_q3; repeat(8) @(negedge i_clk);
		adcm_check("SLOT-RED-UNAFFECTED", n_s1_rise == 1); // RED不命中
		i_owner_slot = 2'd1; adcm_clear; adcm_q3; repeat(8) @(negedge i_clk);
		adcm_check("SLOT-IR-SERIAL1-OK", n_s1_rise == 1); // IR第1笔不命中
		i_owner_slot = 2'd1; adcm_clear; adcm_q3; repeat(8) @(negedge i_clk);
		adcm_check("SLOT-IR-SERIAL2-LOST", (n_s1_rise == 0) && (o_slot_serial == 16'd2)); // IR第2笔命中
		i_owner_slot = 2'd2; adcm_clear; adcm_q3; repeat(8) @(negedge i_clk);
		adcm_check("SLOT-CAL-UNAFFECTED", n_s1_rise == 1); // CAL不命中

		// 13 连续命中：CAL丢失count=255时持续失联
		adcm_reset;
		adcm_arm(3'd1, 2'd2, 16'd1, 8'd255);
		i_owner_slot = 2'd2;
		adcm_clear; adcm_q3; repeat(8) @(negedge i_clk); adcm_q3; repeat(8) @(negedge i_clk); adcm_q3; repeat(8) @(negedge i_clk);
		adcm_check("CAL-DEAD-3-IN-A-ROW", n_s1_rise == 0); // 三笔都无完成

		// 14 兼容模式丢失与迟到
		adcm_reset;
		i_done_mode = 2'd0; i_owner_slot = 2'd0;
		adcm_arm(3'd1, 2'd0, 16'd1, 8'd1);
		adcm_clear; adcm_q3; repeat(12) @(negedge i_clk);
		adcm_check("COMPAT-LOST-QUIET", (n_s1_rise == 0) && (t_idle_fall < 0)); // 兼容丢失全程空闲且无完成
		i_fault_frame_offset = 3'd0; i_fault_release_tick = i_macro_tick + 13'd100;
		adcm_arm(3'd2, 2'd0, 16'd1, 8'd1);
		adcm_clear; adcm_q3; repeat(120) @(negedge i_clk);
		adcm_check("COMPAT-LATE-BUSY-THEN-PULSE", (n_s1_rise == 1) && (t_idle_fall == t_q3_fall_seen) && (t_idle_rise == t_s1_fall) && (t_s1_rise > t_q3_seen + 90)); // 兼容迟到：Q3关闭起保持忙，落点后发脉冲，脉冲结束才空闲

		// 15 按时完成后继续忙（模式5）：电平模式DONE按时延上升且保持，idle保持为低直到落点；兼容模式脉冲照常，脉冲后继续忙
		adcm_reset;
		i_done_mode = 2'd2; i_latency = 8'd6; i_owner_slot = 2'd2;
		i_fault_frame_offset = 3'd0; i_fault_release_tick = i_macro_tick + 13'd200;
		adcm_arm(3'd5, 2'd2, 16'd1, 8'd1);
		adcm_clear; adcm_q3; repeat(230) @(negedge i_clk);
		adcm_check("POSTBUSY-LEVEL-DONE-ON-TIME", (n_s1_rise == 1) && (t_s1_rise == t_q3_seen + 6) && (t_idle_rise > t_s1_rise + 150)); // 完成按时、空闲推迟
		adcm_reset;
		i_done_mode = 2'd0;
		i_fault_frame_offset = 3'd0; i_fault_release_tick = i_macro_tick + 13'd200;
		adcm_arm(3'd5, 2'd2, 16'd1, 8'd1);
		adcm_clear; adcm_q3; repeat(230) @(negedge i_clk);
		adcm_check("POSTBUSY-COMPAT-PULSE-THEN-BUSY", (n_s1_rise == 1) && (t_s1_fall == t_s1_rise + 5) && (t_idle_rise > t_s1_fall + 150)); // 脉冲照常、之后继续忙

		repeat(5) @(negedge i_clk);
		if((cnt_fail == 0) && (cnt_pass == C_EXPECTED_CHECKS)) begin
			$display("ADCM_SELFTEST_PASS checks=%0d", cnt_pass); // 全部通过
		end else begin
			$display("ADCM_SELFTEST_FAIL pass=%0d fail=%0d expected=%0d", cnt_pass, cnt_fail, C_EXPECTED_CHECKS); // 未全部通过
		end
		$finish;                                     // 结束仿真
	end

endmodule
