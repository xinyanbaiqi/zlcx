`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 Resident Macro-Frame Interval Monitor
// Module Name:     v2_mon_frame_interval
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.2 item 4
// Simulations:     verification/v2_v7/tb/tb_v2_monitor_selftest.v, verification/v2_v7/tb/tb_v2_sweep.v
//
// Referrences:     rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v V1.2 F-009 print-only monitor,
//                  contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md V1.13 section 4.2.1 (FSC-03, exception C, F-010)
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Frame-start recognition copied from the F-009 monitor of tb_ppg_control_top_adc_anomaly.v V1.2 (a frame is active at macro tick 0 and the previous cycle was inactive or at tick 4999). Turns the print-only monitor into a verdict: every start must follow the previous start by exactly 5000 cycles, except (1) the first start after START, (2) exception C, accepted only when its condition was actually observed at tick 4999 of the preceding calibration frame (owner in flight, no pending request, NORMAL start eligibility false, AMI calibration request held) and the gap leaves at least 2 idle cycles, and (3) a frame ended by STOP, abort or a blocking fault (C08 4.2.1 item 3, F-010). Each non-5000 start is classified FIRST / EXC-C / BREAK / FAIL on o_gap_class. Synthesizable checker core.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2常驻宏帧间隔监视器
// 模块名称:        v2_mon_frame_interval
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.2节第4项
// 仿真工程:        verification/v2_v7/tb/tb_v2_monitor_selftest.v、verification/v2_v7/tb/tb_v2_sweep.v
//
// 参考资料:        tb_ppg_control_top_adc_anomaly.v V1.2的F-009只打印监视器、
//                  PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md V1.13第4.2.1节（FSC-03、例外C、F-010）
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。宏帧起点识别复制自tb_ppg_control_top_adc_anomaly.v V1.2的F-009监视器（帧在宏帧tick 0活动，且上一拍不活动或处于tick 4999）。把只打印监视器改为判定：相邻起点必须严格相差5000拍，例外只有：(1) START后第一帧；(2) 例外C，仅当前一校准帧tick 4999处实际观测到其条件（owner在途、无pending请求、NORMAL起帧资格不成立、AMI以电平保持校准请求）且间隔至少留出2个空拍时才放行；(3) 被STOP、abort或阻断故障结束的帧（C08第4.2.1节第3条，F-010）。每个非5000起点在o_gap_class上分类为FIRST/EXC-C/BREAK/FAIL。可综合检查核心。

// 宏帧间隔监视：非5000拍的起点间隔只在START首帧、条件成立的例外C、帧被打断时放行
module v2_mon_frame_interval
(
	//---------------全局信号---------------//
	input i_clk,                            // 与DUT同源的2 MHz时钟
	input i_rstn,                           // 低有效监视器复位

	//---------------用户接口---------------//
	input i_frame_active,                   // NORMAL或校准宏帧活动电平
	input i_cal_active,                     // 只区分校准帧，供例外C条件限定在校准帧末拍
	input [12:0] i_macro_tick,              // 调度器宏帧相位
	input i_start_ack,                      // 调度器收到的START确认单拍
	input i_excc_cond,                      // 本拍满足例外C的帧末条件，仅在校准帧tick 4999采信
	input i_frame_break,                    // 本拍有STOP确认、abort或阻断故障
	output [31:0] o_frame_count,            // 已识别宏帧起点总数
	output [31:0] o_first_count,            // START后首帧次数
	output [31:0] o_excc_count,             // 按例外C放行次数
	output [31:0] o_break_count,            // 按帧被打断放行次数
	output [31:0] o_fail_count,             // 不允许的非5000间隔次数
	output o_gap_event,                     // 本拍识别到一个非5000起点
	output [2:0] o_gap_class,               // 该起点分类：1 FIRST、2 EXC-C、3 BREAK、4 FAIL
	output [31:0] o_gap_interval            // 该起点与上一起点的拍距
);

	//---------------配置参数区域---------------//
	localparam [31:0] FRAME_TICKS = 32'd5000;   // FSC-03规定的相邻起点间隔
	localparam [31:0] EXCC_MIN_INTERVAL = 32'd5002; // 例外C至少空2拍
	localparam [12:0] LAST_TICK = 13'd4999;     // 宏帧末拍相位
	localparam [2:0] CLASS_FIRST = 3'd1;        // START后首帧分类码
	localparam [2:0] CLASS_EXCC = 3'd2;         // 例外C分类码
	localparam [2:0] CLASS_BREAK = 3'd3;        // 帧被打断分类码
	localparam [2:0] CLASS_FAIL = 3'd4;         // 不允许间隔分类码

	//---------------计数信号---------------//
	// 拍号与各分类计数
	reg [31:0] cnt_cycle;                   // 监视器自有拍号
	reg [31:0] cnt_last_start;              // 上一起点拍号
	reg [31:0] cnt_frames;                  // 起点总数计数器
	reg [31:0] cnt_first;                   // FIRST分类计数器
	reg [31:0] cnt_excc;                    // 按例外C放行的起点个数
	reg [31:0] cnt_break;                   // 前帧被STOP、abort或故障结束而放行的起点个数
	reg [31:0] cnt_fail;                    // 无任何放行理由的非5000起点个数

	//--------------寄存器信号--------------//
	// 上一拍相位快照
	reg [12:0] reg_prev_tick;               // 上一拍宏帧相位

	//---------------标志信号---------------//
	// 帧起点识别与放行条件
	reg flag_prev_active;                   // 上一拍帧活动
	reg flag_have_last;                     // START后已有上一起点
	reg flag_excc_armed;                    // 前一校准帧末拍观测到例外C条件
	reg flag_break_seen;                    // 上一起点之后出现过帧被打断事件
	wire flag_frame_start;                  // 本拍是宏帧起点
	wire [31:0] flag_interval;              // 本起点与上一起点间隔
	wire flag_gap;                          // 本起点间隔不等于5000或为首帧
	wire [2:0] flag_class;                  // 本起点分类

	//---------------其他信号---------------//

	//---------------输出信号---------------//

	//-------------其他信号连线-------------//
	// 起点识别、间隔与分类
	assign flag_frame_start = i_frame_active && (i_macro_tick == 13'd0) && (!flag_prev_active || (reg_prev_tick == LAST_TICK)) && !i_start_ack; // F-009起点识别，START确认拍只清记录
	assign flag_interval = cnt_cycle - cnt_last_start; // 两起点拍距
	assign flag_gap = flag_frame_start && (!flag_have_last || (flag_interval != FRAME_TICKS)); // 需要分类的起点
	assign flag_class = !flag_have_last ? CLASS_FIRST : ((flag_excc_armed && (flag_interval >= EXCC_MIN_INTERVAL)) ? CLASS_EXCC : (flag_break_seen ? CLASS_BREAK : CLASS_FAIL)); // 按放行条件优先级分类

	//-------------输出信号连线-------------//
	// 计数与分类送出
	assign o_frame_count = cnt_frames;      // 起点总数供汇总
	assign o_first_count = cnt_first;       // 首帧数供汇总
	assign o_excc_count = cnt_excc;         // 例外C数供汇总
	assign o_break_count = cnt_break;       // 打断数供汇总
	assign o_fail_count = cnt_fail;         // 违例数供结论
	assign o_gap_event = flag_gap;          // 非5000起点单拍
	assign o_gap_class = flag_class;        // 分类码随间隔事件同拍送出
	assign o_gap_interval = flag_interval;  // 该起点拍距

	//-------------主要任务处理区域-------------//
	// 自有拍号
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_cycle <= 32'd0;                 // 复位清拍号
		end else begin
			cnt_cycle <= cnt_cycle + 32'd1;     // 每拍加一
		end
	end

	// 记录本起点拍号，供下一起点计算间隔
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_last_start <= 32'd0;            // 复位清起点拍号
		end else if(flag_frame_start == 1'b1)begin
			cnt_last_start <= cnt_cycle;        // 记录本起点
		end else begin
			cnt_last_start <= cnt_last_start;   // 非起点保持
		end
	end

	// START后是否已有起点
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_have_last <= 1'b0;             // 复位后无起点
		end else if(i_start_ack == 1'b1)begin
			flag_have_last <= 1'b0;             // START后重新等待首帧
		end else if(flag_frame_start == 1'b1)begin
			flag_have_last <= 1'b1;             // 识别到起点后有参照
		end else begin
			flag_have_last <= flag_have_last;   // 其余保持
		end
	end

	// 帧活动历史
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_prev_active <= 1'b0;           // 复位视为无帧
		end else begin
			flag_prev_active <= i_frame_active; // 记录本拍帧活动
		end
	end

	// 宏帧相位历史
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_prev_tick <= 13'd0;             // 复位清相位历史
		end else begin
			reg_prev_tick <= i_macro_tick;      // 记录本拍相位
		end
	end

	// 例外C条件锁存：只在校准帧末拍采信，到下一起点消费
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_excc_armed <= 1'b0;            // 复位不放行
		end else if(flag_frame_start == 1'b1)begin
			flag_excc_armed <= 1'b0;            // 起点消费放行资格
		end else if(i_cal_active && (i_macro_tick == LAST_TICK) && i_excc_cond)begin
			flag_excc_armed <= 1'b1;            // 校准帧末拍条件成立
		end else begin
			flag_excc_armed <= flag_excc_armed; // 等待下一起点
		end
	end

	// 帧被打断事件锁存
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_break_seen <= 1'b0;            // 复位无打断
		end else if(flag_frame_start == 1'b1)begin
			flag_break_seen <= 1'b0;            // 新起点清打断记录
		end else if(i_frame_break == 1'b1)begin
			flag_break_seen <= 1'b1;            // 记录STOP、abort或阻断故障
		end else begin
			flag_break_seen <= flag_break_seen; // 保持到下一起点
		end
	end

	// 起点总数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_frames <= 32'd0;                // 复位清起点总数
		end else if(flag_frame_start == 1'b1)begin
			cnt_frames <= cnt_frames + 32'd1;   // 每个起点加一
		end else begin
			cnt_frames <= cnt_frames;           // 没有新起点时总数不变
		end
	end

	// FIRST分类
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_first <= 32'd0;                 // 复位清首帧数
		end else if(flag_gap && (flag_class == CLASS_FIRST))begin
			cnt_first <= cnt_first + 32'd1;     // START后首帧
		end else begin
			cnt_first <= cnt_first;             // 其余起点不计首帧
		end
	end

	// EXC-C分类
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_excc <= 32'd0;                  // 复位清例外C数
		end else if(flag_gap && (flag_class == CLASS_EXCC))begin
			cnt_excc <= cnt_excc + 32'd1;       // 条件成立的例外C
		end else begin
			cnt_excc <= cnt_excc;               // 非例外C起点保持
		end
	end

	// BREAK分类
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_break <= 32'd0;                 // 复位清打断放行数
		end else if(flag_gap && (flag_class == CLASS_BREAK))begin
			cnt_break <= cnt_break + 32'd1;     // 前帧被打断
		end else begin
			cnt_break <= cnt_break;             // 非打断起点保持
		end
	end

	// FAIL分类
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_fail <= 32'd0;                  // 复位清违例数
		end else if(flag_gap && (flag_class == CLASS_FAIL))begin
			cnt_fail <= cnt_fail + 32'd1;       // 不允许的间隔
		end else begin
			cnt_fail <= cnt_fail;               // 合法起点保持
		end
	end

endmodule
