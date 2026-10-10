`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 Sweep Two-Stage SAR ADC Behaviour Model
// Module Name:     v2_adc_behavior_model
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.1
// Simulations:     verification/v2_v7/tb/tb_v2_adc_behavior_model.v
//
// Referrences:     verification_reports/PRE_TAPEOUT_CLOSURE_PLAN_20261009.md V12/V15,
//                  contracts/PPG_ADC_IDAC_INTEGRATION_SPEC.md sections 2 and 5.2,
//                  contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md section 6.2.1
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Verification-only behaviour model of the 9-bit (Stage1) and 15-bit (Stage1+Stage2) pipeline SAR ADC seen by ppg_control_top. A conversion starts at the rising edge of the owner Q3 window; the selected CLK_DOUT rises i_latency cycles later with DOUT stable one cycle before the edge. Three DONE shapes are selectable: compatibility (the 5-cycle pulse issued one cycle after Q3 closes, equivalent to the bg_adc_responder of tb_ppg_control_top_adc_anomaly.v V1.2), and three level modes in which DONE stays high after the conversion: mode 1 is the held behaviour confirmed by the analog designer on 2026-10-10 (Stage1 DONE falls at the rising edge of the next owner transaction's Q1, CLK_9Q1_LOW or CLK_15Q1_LOW, and the ADC counts as busy from that Q1; on a 15-bit transaction Stage2 falls only after Stage1 has risen, stays low 5 cycles (at least 4) and rises at the end of the Stage2 comparison); mode 2 drops DONE at the transaction-start fire and is a non-physical contrast only; mode 3 drops it on an external pulse. Physical idle is either "no conversion in progress" or the C01 6.2.1 formula that also requires the selected DONE to be low, optionally delayed by 0..3 cycles (i_idle_delay) to mimic the single-point synchronizer outside ppg_control_top. Per-slot (RED/IR/CAL) fault injection by occurrence number: lost completion, late completion at an absolute frame/tick, converted at conversion start into an absolute cycle count (frame offset x 5000 + tick - current tick) so that it still expires when frames stall behind an in-flight owner (the ADC stays busy until the late DONE in every mode, so a late DONE never arrives after physical idle), busy then recover without DONE, busy forever, and DONE on time followed by continued physical busy until an absolute release point (for the SID-05 calibration-deadline scenario).
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2扫描用两级SAR ADC行为模型
// 模块名称:        v2_adc_behavior_model
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.1节
// 仿真工程:        verification/v2_v7/tb/tb_v2_adc_behavior_model.v
//
// 参考资料:        PRE_TAPEOUT_CLOSURE_PLAN_20261009.md的V12/V15、PPG_ADC_IDAC_INTEGRATION_SPEC.md第2节与5.2节、
//                  PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md第6.2.1节
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。仅供验证的9位（Stage1）与15位（Stage1+Stage2）流水线SAR ADC行为模型。转换在owner的Q3窗口上升沿开始，所选CLK_DOUT在i_latency拍后上升，DOUT在上升沿前一拍已稳定。DONE形态可选：兼容模式（Q3关闭后一拍发出5拍脉冲，等价于tb_ppg_control_top_adc_anomaly.v V1.2的bg_adc_responder），以及三种电平模式，DONE在转换结束后保持高：模式1是模拟设计者2026-10-10确认的保持型行为（Stage1 DONE在下一笔有owner事务的Q1上升沿回落，即CLK_9Q1_LOW或CLK_15Q1_LOW，ADC从该Q1起算忙；15位事务Stage2在Stage1上升之后才回落，低5拍、最短4拍，在Stage2比较结束时上升）；模式2在事务启动fire时回落，非物理行为，只作对照；模式3由外部脉冲回落。物理空闲可取"无转换进行"或C01第6.2.1节"另要求所选DONE为低"的公式，可再按i_idle_delay延迟0~3拍，模拟ppg_control_top之外的单点同步器。按槽位（RED/IR/CAL）与序号注入故障：完成丢失、迟到到指定绝对帧/拍（转换开始时换算为绝对拍数：帧偏移×5000+目标相位−当前相位，因此在途owner使宏帧停顿时照样到期；各模式下迟到期间ADC都保持忙，迟到DONE不会出现在物理空闲之后）、忙后恢复不发DONE、永久忙，以及按时给出DONE后物理ADC继续忙到绝对落点（供SID-05校准截止场景）。

// 两级SAR ADC行为模型：Q3上升沿启动转换，按模式产生完成电平、物理空闲和故障
module v2_adc_behavior_model
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz系统时钟，与DUT同一时钟
	input i_rstn,                           // 低有效模型复位，复位后回到空闲

	//---------------用户接口---------------//
	//-------------DUT观测输入-------------//
	input i_q1,                            // DUT输出的CLK_9Q1_LOW与CLK_15Q1_LOW之或，上升沿使保持型DONE回落
	input i_q3,                            // DUT输出的CLK_Q3电平，上升沿即转换开始
	input i_txn_start,                     // DUT事务启动fire单拍，供DONE回低模式2使用
	input i_adc_rst,                       // 外部ADC_RST单拍，供DONE回低模式3使用
	input [1:0] i_owner_slot,              // 当前在途owner槽位，0为RED、1为IR、2为CAL
	input i_owner_precision,               // 当前在途owner精度，0为9位、1为15位
	input i_active_precision,              // DUT实时提交精度，供idle二选一
	input [15:0] i_frame_id,               // DUT当前宏帧号，供迟到与忙释放的绝对落点
	input [12:0] i_macro_tick,             // DUT当前宏帧相位，供绝对落点比较
	//-------------模型配置输入-------------//
	input [1:0] i_done_mode,                // 0兼容脉冲，1保持到下一次owner的Q1，2保持到下一次启动fire，3保持到外部ADC_RST
	input i_idle_mode,                      // 0为无转换即空闲，1为另要求所选DONE为低
	input [1:0] i_idle_delay,               // 物理空闲输出相对模型内部空闲的同步延迟拍数，芯片层单点两级同步取2
	input [7:0] i_latency,                  // Q3上升沿到所选DONE上升沿的拍数，最小按1处理；保持型15位最小按6处理
	input [9:0] i_raw_stage1,               // 本次转换结束时呈现的Stage1物理码
	input [9:0] i_raw_stage2,               // 仅15位事务使用的第二级残差码来源
	//-------------故障注入输入-------------//
	input i_fault_arm,                      // 单拍重新武装故障并清零各槽位序号
	input [2:0] i_fault_mode,               // 0无故障，1丢失，2迟到，3忙后恢复，4永久忙，5按时完成后继续忙
	input [1:0] i_fault_slot,               // 故障命中的槽位编码
	input [15:0] i_fault_serial,            // 故障命中的首个槽位序号，从1起算
	input [7:0] i_fault_count,              // 自首个序号起连续命中的笔数，255表示一直命中
	input [2:0] i_fault_frame_offset,       // 迟到或忙释放落点相对转换开始帧的帧偏移
	input [12:0] i_fault_release_tick,      // 迟到或忙释放落点所在帧内的宏帧相位

	//-------------ADC物理输出-------------//
	output [9:0] o_dout_stage1,            // 送DUT的Stage1物理码
	output o_clk_stage1_dout,              // 送DUT的Stage1完成电平
	output [9:0] o_dout_stage2,            // 第二级残差码线，9位事务时保持旧值不被采用
	output o_clk_stage2_dout,              // 第二级末位完成，只在15位事务中上升
	output o_adc_physical_idle,            // 送DUT的已同步物理空闲电平
	//-------------模型观测输出-------------//
	output o_conv_start_event,              // 本拍识别到一次转换开始
	output o_done_rise_event,               // 本拍所选完成电平上升
	output o_fault_hit_event,               // 本拍转换开始命中故障配置
	output [15:0] o_slot_serial             // 本次转换在其槽位内的序号
);

	//-------------配置参数区域-------------//
	// 故障模式、DONE形态与时序常量
	localparam [2:0] FAULT_NONE = 3'd0;     // 不注入故障
	localparam [2:0] FAULT_LOST = 3'd1;     // 完成丢失，空闲照常回到1
	localparam [2:0] FAULT_LATE = 3'd2;     // 完成迟到到绝对落点
	localparam [2:0] FAULT_BUSY = 3'd3;     // 忙到绝对落点后恢复空闲，不发完成
	localparam [2:0] FAULT_FOREVER = 3'd4;  // 永久忙且不发完成
	localparam [2:0] FAULT_POSTBUSY = 3'd5; // 按时发DONE释放owner，但物理ADC继续忙到落点，供SID-05截止场景
	localparam [1:0] DONE_COMPAT = 2'd0;    // 兼容旧TB的5拍完成脉冲
	localparam [1:0] DONE_HELD_Q1 = 2'd1;   // 保持型：完成电平保持到下一笔owner的Q1上升沿
	localparam [1:0] DONE_TO_START = 2'd2;  // 完成电平保持到下一次事务启动fire
	localparam [1:0] DONE_TO_RST = 2'd3;    // 完成电平保持到外部ADC_RST
	localparam [7:0] COMPAT_PULSE_CYCLES = 8'd5; // 兼容脉冲宽度，与旧响应进程一致
	localparam [7:0] HELD15_MIN_CYCLES = 8'd6; // 保持型15位最短时延：Stage1上升、Stage2回落再低4拍
	localparam [7:0] HELD15_S1_LEAD = 8'd6; // 保持型15位Stage1上升领先最终完成的拍数
	localparam [7:0] PRE_BUSY_LIMIT = 8'd64; // Q1后迟迟没有Q3时忙状态的上限
	localparam [7:0] S2_LAG_CYCLES = 8'd2;  // 15位事务Stage2相对Stage1的完成滞后
	localparam [1:0] SLOT_RED = 2'd0;       // RED槽位编码
	localparam [1:0] SLOT_IR = 2'd1;        // 红外NORMAL事务对应的槽位值
	localparam [1:0] SLOT_CAL = 2'd2;       // AMB_CAL与DCS_CAL共用的校准槽位值

	//-------------状态参数区域-------------//
	// 行为模型主状态编码
	localparam [2:0] ST_IDLE = 3'd0;        // 无转换进行，等待Q3上升沿
	localparam [2:0] ST_WAIT_Q3_END = 3'd1; // 兼容模式等待Q3窗口关闭
	localparam [2:0] ST_CONVERT = 3'd2;     // 电平模式转换中，按时延计数
	localparam [2:0] ST_PULSE = 3'd3;       // 兼容模式完成脉冲保持期
	localparam [2:0] ST_LATE = 3'd4;        // 迟到完成：保持忙直到绝对落点再上升
	localparam [2:0] ST_BUSY = 3'd5;        // 忙后恢复：保持忙直到绝对落点且不发DONE
	localparam [2:0] ST_FOREVER = 3'd6;     // 永久忙：直到复位或重新武装才释放
	localparam [2:0] ST_COMPAT_LATE = 3'd7; // 兼容模式迟到：Q3关闭后保持忙，落点到达再发脉冲

	//---------------计数信号---------------//
	// 转换时延、脉冲宽度与槽位序号计数
	reg [7:0] cnt_conv;                     // 转换开始后的已过拍数
	reg [7:0] cnt_pre_busy;                 // Q1上升后等待Q3的拍数
	reg [7:0] cnt_pulse;                    // 兼容脉冲已保持拍数
	reg [16:0] cnt_since_start;             // 自转换开始起的绝对拍数，不依赖宏帧是否继续推进
	reg [15:0] cnt_serial_red;              // RED槽位自武装以来的转换序号
	reg [15:0] cnt_serial_ir;               // 红外事务转换开始次数，供按序号命中
	reg [15:0] cnt_serial_cal;              // 校准事务转换开始次数，含AMB与DCS

	//--------------状态机信号--------------//
	// 三段式状态机现态与次态
	reg [2:0] state_current;                // 行为模型当前状态
	reg [2:0] state_next;                   // 行为模型组合次态

	//--------------寄存器信号--------------//
	// 每次转换开始时锁存的事务属性
	reg reg_precision;                      // 本次转换锁存的精度
	reg [7:0] reg_conv_cycles;              // 本次转换锁存并下限为1的时延
	reg [2:0] reg_fault;                    // 本次转换命中的故障类型
	reg [16:0] reg_release_wait;            // 转换开始拍到迟到或忙释放落点的绝对拍数，按5000拍宏帧换算
	reg [9:0] reg_raw1;                     // 本次转换锁存的Stage1码
	reg [9:0] reg_raw2;                     // 高精度残差码在转换开始拍的快照
	reg [15:0] reg_serial;                  // 本次转换在槽位内的序号快照

	//---------------标志信号---------------//
	// 输入边沿历史与组合判定
	reg flag_q1_prev;                       // 上一拍Q1电平
	reg flag_pre_busy;                      // 保持型模式下Q1到Q3之间的忙状态
	wire flag_held;                         // 当前为保持型DONE模式
	wire flag_q1_rise;                      // 本拍Q1上升沿
	wire flag_s2_fall;                      // 本拍保持型15位事务的Stage2回落
	reg flag_q3_prev;                       // 上一拍Q3电平，用于上升下降沿检测
	wire flag_q3_rise;                      // Q3上升沿：转换开始
	wire flag_q3_fall;                      // Q3下降沿：兼容模式响应起点
	wire [15:0] flag_slot_serial_next;      // 本次转换将获得的槽位序号
	wire flag_fault_hit;                    // 本次转换开始命中故障配置
	wire [16:0] flag_release_wait_next;     // 转换开始拍换算出的释放等待拍数
	wire flag_release_point;                // 已到达迟到或忙释放的绝对落点
	wire [7:0] flag_s1_rise_cycle;          // 本次转换Stage1上升所在的计数值
	wire flag_s1_rise;                      // 本拍Stage1完成电平上升
	wire flag_s2_rise;                      // 15位事务最终完成沿，晚于Stage1两拍
	wire flag_conv_end;                     // 本拍按时延到达转换结束
	wire flag_adc_rst;                      // 本拍发生ADC_RST，电平模式下DONE回低
	wire flag_idle_raw;                     // 未经同步延迟的物理空闲
	reg flag_idle_d1;                       // 物理空闲延迟1拍
	reg flag_idle_d2;                       // 对应芯片层两级同步器的空闲输出
	reg flag_idle_d3;                       // 比两级同步再多一拍的余量档

	//---------------其他信号---------------//

	//---------------输出信号---------------//
	// 输出端口的内部寄存驱动
	reg [9:0] dout_stage1_o;                // Stage1物理码输出寄存
	reg clk_stage1_dout_o;                  // Stage1完成电平输出寄存
	reg [9:0] dout_stage2_o;                // 第二级码线驱动寄存器
	reg clk_stage2_dout_o;                  // 第二级完成电平驱动寄存器

	//-------------其他信号连线-------------//
	// 边沿、序号、故障命中与落点判定
	assign flag_held = (i_done_mode == DONE_HELD_Q1); // 保持型模式判定
	assign flag_q1_rise = i_q1 && !flag_q1_prev; // Q1由低变高
	assign flag_q3_rise = i_q3 && !flag_q3_prev; // Q3由低变高的一拍
	assign flag_q3_fall = !i_q3 && flag_q3_prev; // Q3由高变低的一拍
	assign flag_slot_serial_next = (i_owner_slot == SLOT_RED) ? (cnt_serial_red + 16'd1) : ((i_owner_slot == SLOT_IR) ? (cnt_serial_ir + 16'd1) : (cnt_serial_cal + 16'd1)); // 按槽位取下一序号
	assign flag_fault_hit = (i_fault_mode != FAULT_NONE) && (i_owner_slot == i_fault_slot) && (flag_slot_serial_next >= i_fault_serial) && ((i_fault_count == 8'd255) || (flag_slot_serial_next < (i_fault_serial + {8'd0, i_fault_count}))); // 槽位与序号区间同时命中
	assign flag_release_wait_next = ({14'd0, i_fault_frame_offset} * 17'd5000) + {4'd0, i_fault_release_tick} - {4'd0, i_macro_tick}; // 偏移帧数乘5000加目标相位减当前相位
	assign flag_release_point = (cnt_since_start >= reg_release_wait); // 按绝对拍数到达落点；宏帧因在途owner停顿时照样到期
	assign flag_s1_rise_cycle = (flag_held && reg_precision) ? ((reg_conv_cycles > HELD15_S1_LEAD) ? (reg_conv_cycles - HELD15_S1_LEAD) : 8'd1) : ((reg_precision && (reg_conv_cycles > S2_LAG_CYCLES)) ? (reg_conv_cycles - S2_LAG_CYCLES) : reg_conv_cycles); // 15位时Stage1早于Stage2完成
	assign flag_conv_end = (state_current == ST_CONVERT) && (cnt_conv == reg_conv_cycles); // 电平模式转换时延到达
	assign flag_s2_fall = flag_held && reg_precision && (state_current == ST_CONVERT) && ((((reg_fault == FAULT_NONE) || (reg_fault == FAULT_POSTBUSY)) && (cnt_conv == (flag_s1_rise_cycle + 8'd1))) || (!((reg_fault == FAULT_NONE) || (reg_fault == FAULT_POSTBUSY)) && flag_conv_end)); // Stage1上升后一拍Stage2回落；故障事务在时延到时回落
	assign flag_s1_rise = ((state_current == ST_CONVERT) && (cnt_conv == flag_s1_rise_cycle) && ((reg_fault == FAULT_NONE) || (reg_fault == FAULT_POSTBUSY))) || ((state_current == ST_LATE) && flag_release_point) || ((state_current == ST_PULSE) && (cnt_pulse == 8'd0)); // 正常、迟到落点或兼容脉冲首拍
	assign flag_s2_rise = reg_precision && (((state_current == ST_CONVERT) && flag_conv_end && ((reg_fault == FAULT_NONE) || (reg_fault == FAULT_POSTBUSY))) || ((state_current == ST_LATE) && flag_release_point) || ((state_current == ST_PULSE) && (cnt_pulse == 8'd0))); // 15位事务的最终完成电平上升
	assign flag_adc_rst = (flag_held && flag_q1_rise) || ((i_done_mode == DONE_TO_START) && i_txn_start) || ((i_done_mode == DONE_TO_RST) && i_adc_rst); // 使完成电平回落的事件：保持型取Q1上升沿
	assign flag_idle_raw = ((state_current == ST_IDLE) || ((state_current == ST_WAIT_Q3_END) && (i_done_mode == DONE_COMPAT)) || ((state_current == ST_PULSE) && (cnt_pulse == 8'd0) && (reg_fault != FAULT_LATE))) && !flag_pre_busy && (!i_idle_mode || !(i_active_precision ? clk_stage2_dout_o : clk_stage1_dout_o)); // 无转换进行且按模式要求所选DONE为低；兼容迟到的脉冲空档拍仍算忙

	//-------------输出信号连线-------------//
	// 物理输出与观测事件连接到端口
	assign o_dout_stage1 = dout_stage1_o;   // Stage1码送DUT
	assign o_clk_stage1_dout = clk_stage1_dout_o; // Stage1完成电平送DUT
	assign o_dout_stage2 = dout_stage2_o;   // Stage2码送DUT
	assign o_clk_stage2_dout = clk_stage2_dout_o; // 15位最终完成电平转发到端口
	assign o_adc_physical_idle = (i_idle_delay == 2'd0) ? flag_idle_raw : ((i_idle_delay == 2'd1) ? flag_idle_d1 : ((i_idle_delay == 2'd2) ? flag_idle_d2 : flag_idle_d3)); // 按配置的同步延迟送DUT
	assign o_conv_start_event = flag_q3_rise && (state_current == ST_IDLE); // 空闲中识别到的Q3上升沿才算新转换
	assign o_done_rise_event = reg_precision ? flag_s2_rise : flag_s1_rise; // 所选完成电平上升事件
	assign o_fault_hit_event = o_conv_start_event && flag_fault_hit; // 新转换开始即命中故障
	assign o_slot_serial = reg_serial;      // 最近一次转换的槽位序号

	//-------------输出信号处理区域-------------//
	// Stage1码：转换开始后一拍呈现新码，保证早于完成上升沿稳定
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			dout_stage1_o <= 10'd0;             // 复位清零Stage1码线
		end else if((state_current == ST_CONVERT) && (cnt_conv == 8'd1))begin
			dout_stage1_o <= reg_raw1;          // 电平模式转换首拍呈现结果码
		end else if((state_current == ST_WAIT_Q3_END) && flag_q3_fall)begin
			dout_stage1_o <= reg_raw1;          // 兼容模式Q3关闭时呈现结果码
		end else begin
			dout_stage1_o <= dout_stage1_o;     // 结果码保持到下一次转换
		end
	end

	// 第二级码线：随第一级码同拍换成本次残差码
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			dout_stage2_o <= 10'd0;             // 复位时第二级码线为全0
		end else if((state_current == ST_CONVERT) && (cnt_conv == 8'd1))begin
			dout_stage2_o <= reg_raw2;          // 电平模式首拍把残差码放上第二级码线
		end else if((state_current == ST_WAIT_Q3_END) && flag_q3_fall)begin
			dout_stage2_o <= reg_raw2;          // 兼容模式Q3关闭拍放上残差码
		end else begin
			dout_stage2_o <= dout_stage2_o;     // 第二级码线维持到下次换码
		end
	end

	// Stage1完成电平：上升事件置高，电平模式按ADC_RST回低，兼容模式随脉冲结束回低
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			clk_stage1_dout_o <= 1'b0;          // 复位后无完成电平
		end else if(flag_s1_rise == 1'b1)begin
			clk_stage1_dout_o <= 1'b1;          // 转换结束拉高Stage1完成
		end else if((i_done_mode == DONE_COMPAT) && (state_current == ST_PULSE) && (cnt_pulse == COMPAT_PULSE_CYCLES))begin
			clk_stage1_dout_o <= 1'b0;          // 兼容脉冲末拍回低
		end else if((i_done_mode != DONE_COMPAT) && flag_adc_rst)begin
			clk_stage1_dout_o <= 1'b0;          // 电平模式ADC_RST使Stage1回低
		end else begin
			clk_stage1_dout_o <= clk_stage1_dout_o; // 其余时刻保持电平
		end
	end

	// 第二级完成电平：15位事务的捕获依据，9位事务保持低
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			clk_stage2_dout_o <= 1'b0;          // 复位时第二级完成为低
		end else if(flag_s2_rise == 1'b1)begin
			clk_stage2_dout_o <= 1'b1;          // 15位转换最终完成沿
		end else if((i_done_mode == DONE_COMPAT) && (state_current == ST_PULSE) && (cnt_pulse == COMPAT_PULSE_CYCLES))begin
			clk_stage2_dout_o <= 1'b0;          // 兼容脉冲末拍第二级也落下
		end else if(flag_s2_fall == 1'b1)begin
			clk_stage2_dout_o <= 1'b0;          // 保持型15位：Stage1上升后Stage2先回落
		end else if((i_done_mode != DONE_COMPAT) && !flag_held && flag_adc_rst)begin
			clk_stage2_dout_o <= 1'b0;          // 电平模式由所选ADC_RST事件清第二级完成
		end else begin
			clk_stage2_dout_o <= clk_stage2_dout_o; // 无事件时第二级完成电平不动
		end
	end

	//----------------状态机区域----------------//
	// 状态机第一段：现态寄存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			state_current <= ST_IDLE;           // 复位后无转换进行
		end else begin
			state_current <= state_next;        // 每拍采用组合次态
		end
	end

	// 状态机第二段：按DONE形态与故障类型决定次态
	always@(*)begin
		state_next = state_current;             // 默认保持当前状态
		case(state_current)
			ST_IDLE:begin
				if(flag_q3_rise == 1'b1)begin
					if(i_done_mode == DONE_COMPAT)begin
						state_next = (flag_fault_hit && (i_fault_mode == FAULT_LOST)) ? ST_IDLE : ST_WAIT_Q3_END; // 兼容丢失不产生任何活动
					end else begin
						state_next = ST_CONVERT; // 电平模式进入转换计数
					end
				end
			end
			ST_WAIT_Q3_END:begin
				if(flag_q3_fall == 1'b1)begin
					if(reg_fault == FAULT_LATE)begin
						state_next = ST_COMPAT_LATE; // 兼容迟到先保持空闲等待落点
					end else if(reg_fault == FAULT_BUSY)begin
						state_next = ST_BUSY;   // 兼容忙后恢复在Q3关闭后拉忙
					end else if(reg_fault == FAULT_FOREVER)begin
						state_next = ST_FOREVER; // 兼容永久忙在Q3关闭后拉忙
					end else begin
						state_next = ST_PULSE;  // 兼容正常响应发5拍脉冲
					end
				end
			end
			ST_CONVERT:begin
				if(flag_conv_end == 1'b1)begin
					if(reg_fault == FAULT_LATE)begin
						state_next = ST_LATE;   // 迟到：时延到后继续保持忙
					end else if(reg_fault == FAULT_BUSY)begin
						state_next = ST_BUSY;   // 忙后恢复：时延到后继续保持忙
					end else if(reg_fault == FAULT_FOREVER)begin
						state_next = ST_FOREVER; // 永久忙：时延到后不再释放
					end else if(reg_fault == FAULT_POSTBUSY)begin
						state_next = ST_BUSY;   // 完成已发出，物理ADC继续忙到落点
					end else begin
						state_next = ST_IDLE;   // 正常或丢失：转换结束回空闲
					end
				end
			end
			ST_PULSE:begin
				if((cnt_pulse == COMPAT_PULSE_CYCLES) && (reg_fault == FAULT_POSTBUSY))begin
					state_next = ST_BUSY;       // 兼容脉冲发完后物理ADC继续忙
				end else if(cnt_pulse == COMPAT_PULSE_CYCLES)begin
					state_next = ST_IDLE;       // 脉冲保持满5拍后回空闲
				end
			end
			ST_LATE:begin
				if(flag_release_point == 1'b1)begin
					state_next = ST_IDLE;       // 迟到落点到达，完成上升同拍回空闲
				end
			end
			ST_BUSY:begin
				if(flag_release_point == 1'b1)begin
					state_next = ST_IDLE;       // 忙释放落点到达，不发完成回空闲
				end
			end
			ST_FOREVER:begin
				if(i_fault_arm == 1'b1)begin
					state_next = ST_IDLE;       // 只有重新武装才能解除永久忙
				end
			end
			ST_COMPAT_LATE:begin
				if(flag_release_point == 1'b1)begin
					state_next = ST_PULSE;      // 兼容迟到落点到达后发脉冲
				end
			end
			default:begin
				state_next = ST_IDLE;           // 非法编码回到空闲
			end
		endcase
	end

	//-------------状态任务处理区域-------------//
	// 转换计数：电平模式转换中逐拍递增
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_conv <= 8'd0;                   // 复位清零转换拍数
		end else if((state_current == ST_IDLE) && flag_q3_rise)begin
			cnt_conv <= 8'd1;                   // 转换开始拍之后的第一拍计为1
		end else if((state_current == ST_CONVERT) && (cnt_conv != 8'd255))begin
			cnt_conv <= cnt_conv + 8'd1;        // 转换中逐拍累加且饱和
		end else begin
			cnt_conv <= cnt_conv;               // 其余状态保持最近计数
		end
	end

	// 兼容脉冲宽度计数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_pulse <= 8'd0;                  // 复位清零脉冲宽度
		end else if(state_current == ST_PULSE)begin
			cnt_pulse <= cnt_pulse + 8'd1;      // 脉冲期间逐拍累加
		end else begin
			cnt_pulse <= 8'd0;                  // 离开脉冲期即清零备下次
		end
	end

	// Q1之后、Q3之前ADC已不算空闲：模拟侧从owner的Q1起即在转换
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_pre_busy <= 1'b0;              // 复位不忙
		end else if(flag_held && flag_q1_rise && (state_current == ST_IDLE))begin
			flag_pre_busy <= 1'b1;              // owner的Q1上升起算忙
		end else if(flag_q3_rise || (cnt_pre_busy >= PRE_BUSY_LIMIT))begin
			flag_pre_busy <= 1'b0;              // Q3到来交给转换计数，或Q1后长期无Q3时放弃
		end else begin
			flag_pre_busy <= flag_pre_busy;     // Q1与Q3之间保持忙
		end
	end

	//-------------主要任务处理区域-------------//
	// RED槽位序号：武装清零，每次RED转换开始加1
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_serial_red <= 16'd0;            // 复位清零RED序号
		end else if(i_fault_arm == 1'b1)begin
			cnt_serial_red <= 16'd0;            // 重新武装时RED从头计数
		end else if(o_conv_start_event && (i_owner_slot == SLOT_RED))begin
			cnt_serial_red <= flag_slot_serial_next; // RED转换开始取得新序号
		end else begin
			cnt_serial_red <= cnt_serial_red;   // 非RED转换不改变RED序号
		end
	end

	// 红外序号计数：只统计IR owner的Q3上升沿
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_serial_ir <= 16'd0;             // 复位令红外计数归零
		end else if(i_fault_arm == 1'b1)begin
			cnt_serial_ir <= 16'd0;             // 故障重新武装时红外计数重新从0开始
		end else if(o_conv_start_event && (i_owner_slot == SLOT_IR))begin
			cnt_serial_ir <= flag_slot_serial_next; // 红外转换开始，序号前进一位
		end else begin
			cnt_serial_ir <= cnt_serial_ir;     // 其他槽位转换时红外计数保持
		end
	end

	// 校准序号计数：AMB与DCS校准合并统计
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_serial_cal <= 16'd0;            // 复位令校准计数归零
		end else if(i_fault_arm == 1'b1)begin
			cnt_serial_cal <= 16'd0;            // 武装脉冲把校准计数拉回起点
		end else if(o_conv_start_event && (i_owner_slot == SLOT_CAL))begin
			cnt_serial_cal <= flag_slot_serial_next; // 校准Q3上升沿使校准计数递增
		end else begin
			cnt_serial_cal <= cnt_serial_cal;   // NORMAL转换不影响校准计数
		end
	end

	// Q3电平历史，供边沿检测
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_q3_prev <= 1'b0;               // 复位时视Q3为低
		end else begin
			flag_q3_prev <= i_q3;               // 每拍记录Q3电平
		end
	end

	// Q1电平历史，供保持型DONE回落检测
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_q1_prev <= 1'b0;               // 上电时Q1历史为低
		end else begin
			flag_q1_prev <= i_q1;               // 逐拍保存CLK_Q1之或，用于找上升沿
		end
	end

	// Q1后等待Q3的计时
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_pre_busy <= 8'd0;               // 复位清等待计时
		end else if(flag_pre_busy == 1'b1)begin
			cnt_pre_busy <= cnt_pre_busy + 8'd1; // 忙等Q3期间累加
		end else begin
			cnt_pre_busy <= 8'd0;               // 不在Q1到Q3之间时为0
		end
	end

	// 物理空闲同步延迟第1级
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_idle_d1 <= 1'b1;               // 复位后视为空闲
		end else begin
			flag_idle_d1 <= flag_idle_raw;      // 采样未延迟空闲
		end
	end

	// 物理空闲同步延迟第2级，对应芯片层两级同步器输出
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_idle_d2 <= 1'b1;               // 上电时第二级空闲为1
		end else begin
			flag_idle_d2 <= flag_idle_d1;       // 推进一级
		end
	end

	// 物理空闲同步延迟第3级，留作余量
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_idle_d3 <= 1'b1;               // 第三级上电空闲
		end else begin
			flag_idle_d3 <= flag_idle_d2;       // 再推进一级
		end
	end

	// 转换开始锁存精度
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_precision <= 1'b0;              // 复位默认9位
		end else if(o_conv_start_event == 1'b1)begin
			reg_precision <= i_owner_precision; // 采用在途owner的精度
		end else begin
			reg_precision <= reg_precision;     // 转换期间精度不变
		end
	end

	// 转换开始锁存时延并下限为1
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_conv_cycles <= 8'd1;            // 复位默认1拍时延
		end else if(o_conv_start_event == 1'b1)begin
			reg_conv_cycles <= (flag_held && i_owner_precision && (i_latency < HELD15_MIN_CYCLES)) ? HELD15_MIN_CYCLES : ((i_latency == 8'd0) ? 8'd1 : i_latency); // 0拍按1拍处理
		end else begin
			reg_conv_cycles <= reg_conv_cycles; // 转换期间时延不变
		end
	end

	// 转换开始锁存命中的故障类型
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_fault <= FAULT_NONE;            // 复位后无故障
		end else if((o_conv_start_event == 1'b1) && (flag_fault_hit == 1'b1))begin
			reg_fault <= i_fault_mode;          // 命中时记下故障类型
		end else if(o_conv_start_event == 1'b1)begin
			reg_fault <= FAULT_NONE;            // 未命中的新转换按正常处理
		end else begin
			reg_fault <= reg_fault;             // 本次转换期间故障类型不变
		end
	end

	// 转换开始锁存释放落点的绝对等待拍数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_release_wait <= 17'd0;          // 复位清零等待拍数
		end else if(o_conv_start_event == 1'b1)begin
			reg_release_wait <= flag_release_wait_next; // 以本转换开始拍为零点
		end else begin
			reg_release_wait <= reg_release_wait; // 等待期间落点不变
		end
	end

	// 自转换开始起的绝对拍数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_since_start <= 17'd0;           // 复位清零绝对拍数
		end else if(o_conv_start_event == 1'b1)begin
			cnt_since_start <= 17'd1;           // 以转换开始为原点，下一拍记作第1拍
		end else if(cnt_since_start != 17'h1ffff)begin
			cnt_since_start <= cnt_since_start + 17'd1; // 逐拍累加且饱和
		end else begin
			cnt_since_start <= cnt_since_start; // 饱和后保持
		end
	end

	// 转换开始锁存Stage1码
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_raw1 <= 10'd0;                  // 复位清零Stage1待发码
		end else if(o_conv_start_event == 1'b1)begin
			reg_raw1 <= i_raw_stage1;           // 记录本次Stage1结果
		end else begin
			reg_raw1 <= reg_raw1;               // 转换期间Stage1待发码不变
		end
	end

	// 高精度残差码与第一级码在同一开始拍取样
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_raw2 <= 10'd0;                  // 复位令残差码快照归零
		end else if(o_conv_start_event == 1'b1)begin
			reg_raw2 <= i_raw_stage2;           // 取TB给出的残差码作为本次第二级结果
		end else begin
			reg_raw2 <= reg_raw2;               // 残差码快照在两次转换开始之间冻结
		end
	end

	// 转换开始锁存槽位序号快照
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_serial <= 16'd0;                // 复位清零序号快照
		end else if(o_conv_start_event == 1'b1)begin
			reg_serial <= flag_slot_serial_next; // 记录本次转换序号
		end else begin
			reg_serial <= reg_serial;           // 两次转换之间保持
		end
	end

endmodule
