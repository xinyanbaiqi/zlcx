`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 Resident Q3-to-Owner Binding Monitor
// Module Name:     v2_mon_q3_bind
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.2 item 5
// Simulations:     verification/v2_v7/tb/tb_v2_monitor_selftest.v, verification/v2_v7/tb/tb_v2_sweep.v
//
// Referrences:     rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v V1.2 lines 1010-1025 (SYSMON BIND-VIOLATION)
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Module form of the Q3/owner binding monitor copied from tb_ppg_control_top_adc_anomaly.v V1.2: the most recent owner commit is latched (frame, subframe, calibration flag); every rising edge of CLK_Q3 must occur while the scheduler reports an owner in flight, inside the same macro frame as that commit and, for a calibration owner, inside the same calibration subframe. Synthesizable checker core; the TB prints the V2MON lines.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2常驻Q3与owner绑定监视器
// 模块名称:        v2_mon_q3_bind
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.2节第5项
// 仿真工程:        verification/v2_v7/tb/tb_v2_monitor_selftest.v、verification/v2_v7/tb/tb_v2_sweep.v
//
// 参考资料:        rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v V1.2第1010~1025行（SYSMON BIND-VIOLATION）
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。把tb_ppg_control_top_adc_anomaly.v V1.2的Q3与owner绑定监视复制改写为模块：锁存最近一次owner提交的帧号、子帧与是否校准；CLK_Q3每个上升沿都必须发生在调度器报告owner在途期间，与该次提交处于同一宏帧，校准owner还须处于同一校准子帧。可综合检查核心，V2MON行由TB打印。

// Q3与owner绑定监视：每次Q3上升沿必须属于同帧（校准同子帧）提交的在途owner
module v2_mon_q3_bind
(
	//---------------全局信号---------------//
	input i_clk,                            // 与DUT同源的2 MHz时钟
	input i_rstn,                           // 低有效监视器复位

	//---------------用户接口---------------//
	input i_q3,                             // DUT输出CLK_Q3电平
	input i_sched_inflight,                 // 调度器报告的owner在途电平
	input i_commit,                         // 调度器owner提交单拍
	input i_commit_cal,                     // 提交的owner属于校准类型
	input [15:0] i_frame,                   // 调度器当前宏帧号
	input [2:0] i_subframe,                 // 调度器当前校准子帧号
	output [31:0] o_q3_count,               // 已观测的Q3上升沿次数
	output [31:0] o_violation_count,        // 绑定违例次数
	output o_violation_event                // 本拍发生一次绑定违例
);

	//---------------计数信号---------------//
	// Q3次数与违例次数
	reg [31:0] cnt_q3;                      // Q3上升沿累计
	reg [31:0] cnt_violation;               // 绑定违例累计

	//--------------寄存器信号--------------//
	// 最近一次提交的帧与子帧身份
	reg [15:0] reg_commit_frame;            // 最近提交所在宏帧
	reg [2:0] reg_commit_subframe;          // 最近提交所在校准子帧
	reg reg_commit_cal;                     // 最近提交是否为校准owner

	//---------------标志信号---------------//
	// Q3边沿与违例判定
	reg flag_q3_prev;                       // 上一拍Q3电平
	wire flag_q3_rise;                      // 本拍Q3上升沿
	wire flag_violation;                    // 本拍Q3上升沿不属于合法在途owner

	//---------------其他信号---------------//

	//---------------输出信号---------------//

	//-------------其他信号连线-------------//
	// 绑定判定组合逻辑
	assign flag_q3_rise = i_q3 && !flag_q3_prev; // Q3由低变高
	assign flag_violation = flag_q3_rise && (!i_sched_inflight || (reg_commit_frame != i_frame) || (reg_commit_cal && (reg_commit_subframe != i_subframe))); // 无owner、跨帧或校准跨子帧

	//-------------输出信号连线-------------//
	// 计数与事件送出
	assign o_q3_count = cnt_q3;             // Q3累计供汇总
	assign o_violation_count = cnt_violation; // 违例累计供汇总
	assign o_violation_event = flag_violation; // 违例单拍供明细打印

	//-------------主要任务处理区域-------------//
	// Q3电平历史
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_q3_prev <= 1'b0;               // 复位时视Q3为低
		end else begin
			flag_q3_prev <= i_q3;               // 记录本拍Q3
		end
	end

	// 最近提交帧号
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_commit_frame <= 16'd0;          // 复位清提交帧
		end else if(i_commit == 1'b1)begin
			reg_commit_frame <= i_frame;        // 提交拍锁存当前帧
		end else begin
			reg_commit_frame <= reg_commit_frame; // 两次提交之间保持
		end
	end

	// 最近提交子帧号
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_commit_subframe <= 3'd0;        // 复位清提交子帧
		end else if(i_commit == 1'b1)begin
			reg_commit_subframe <= i_subframe;  // 子帧快照随提交刷新，否则不动
		end else begin
			reg_commit_subframe <= reg_commit_subframe; // 提交间隔内子帧快照不变
		end
	end

	// 最近提交类型
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_commit_cal <= 1'b0;             // 复位视为NORMAL
		end else if(i_commit == 1'b1)begin
			reg_commit_cal <= i_commit_cal;     // 提交拍锁存类型
		end else begin
			reg_commit_cal <= reg_commit_cal;   // 类型快照保持到下次提交
		end
	end

	// Q3次数累计
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_q3 <= 32'd0;                    // 复位清Q3次数
		end else if(flag_q3_rise == 1'b1)begin
			cnt_q3 <= cnt_q3 + 32'd1;           // 每个上升沿加一
		end else begin
			cnt_q3 <= cnt_q3;                   // 无上升沿保持
		end
	end

	// 违例次数累计
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_violation <= 32'd0;             // 复位清违例次数
		end else if(flag_violation == 1'b1)begin
			cnt_violation <= cnt_violation + 32'd1; // 每次违例加一
		end else begin
			cnt_violation <= cnt_violation;     // 无违例保持
		end
	end

endmodule
