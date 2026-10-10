`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 Resident Liveness Monitor
// Module Name:     v2_mon_liveness
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.2 item 1
// Simulations:     verification/v2_v7/tb/tb_v2_monitor_selftest.v, verification/v2_v7/tb/tb_v2_sweep.v
//
// Referrences:     rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v V1.2 generic liveness monitor
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Module form of the generic liveness monitor copied from tb_ppg_control_top_adc_anomaly.v V1.2 (lines 1079-1091): while the lifecycle is RUN or STOPPING, a run of C_LIMIT consecutive cycles (default 15000 = 3 macro frames) with no progress pulse and no fault record is one silent stall. Progress and fault inputs are pre-OR'ed by the instantiating TB from read-only hierarchical observations; the monitor never forces anything. Synthesizable checker core without system tasks; the instantiating TB prints the V2MON-DETAIL and V2MON LIVENESS lines from o_stall_event, o_noprog, o_fail_count and o_max_noprog.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2常驻活性监视器
// 模块名称:        v2_mon_liveness
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.2节第1项
// 仿真工程:        verification/v2_v7/tb/tb_v2_monitor_selftest.v、verification/v2_v7/tb/tb_v2_sweep.v
//
// 参考资料:        rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v V1.2的通用活性监视
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。把tb_ppg_control_top_adc_anomaly.v V1.2第1079~1091行的通用活性监视复制改写为模块：生命周期处于RUN或STOPPING时，连续C_LIMIT拍（默认15000拍即3个宏帧）既无进展脉冲也无故障记录，记一次静默停滞。进展与故障输入由例化TB用只读层次观测预先求或，本模块不force任何信号。本模块为不含系统任务的可综合检查核心，V2MON-DETAIL明细与V2MON LIVENESS汇总行由例化TB依据o_stall_event、o_noprog、o_fail_count、o_max_noprog打印。

// 活性监视：RUN/STOPPING中连续C_LIMIT拍无进展且无故障记录即判静默停滞
module v2_mon_liveness
#(
	parameter integer C_LIMIT = 15000                // 判定静默停滞的连续无进展拍数
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 与DUT同源的2 MHz时钟
	input i_rstn,                           // 低有效监视器复位

	//---------------用户接口---------------//
	input i_active,                         // 生命周期处于RUN或STOPPING
	input i_progress,                       // 本拍有任一进展事件
	input i_fault_record,                   // 本拍有故障记录或阻断保持
	output [31:0] o_fail_count,             // 已判定的静默停滞次数
	output [31:0] o_max_noprog,             // 观测到的最长无进展游程
	output o_stall_event,                   // 本拍新判定一次停滞，供TB打印明细
	output [31:0] o_noprog                  // 当前无进展游程长度
);

	//---------------计数信号---------------//
	// 无进展游程、停滞次数与最长游程
	reg [31:0] cnt_noprog;                  // 当前连续无进展拍数
	reg [31:0] cnt_stall;                   // 已判定的停滞次数
	reg [31:0] cnt_max_noprog;              // 运行以来无进展游程的峰值寄存
	reg [7:0] cnt_detail;                   // 已打印的停滞明细条数

	//---------------标志信号---------------//
	// 本游程是否已经报告
	reg flag_reported;                      // 当前无进展游程已计入一次停滞
	wire flag_reset_run;                    // 本拍结束无进展游程
	wire flag_new_stall;                    // 本拍首次越过停滞门限

	//---------------其他信号---------------//

	//---------------输出信号---------------//

	//-------------其他信号连线-------------//
	// 游程重置与停滞判定
	assign flag_reset_run = i_progress || i_fault_record || !i_active; // 有进展、有故障或不在运行期都清游程
	assign flag_new_stall = !flag_reset_run && (cnt_noprog >= C_LIMIT) && !flag_reported; // 首次越限的那一拍

	//-------------输出信号连线-------------//
	// 停滞计数送出
	assign o_fail_count = cnt_stall;        // 汇总给TB结论逻辑
	assign o_max_noprog = cnt_max_noprog;   // 最长游程供汇总行引用
	assign o_stall_event = flag_new_stall;  // 新停滞单拍供明细打印
	assign o_noprog = cnt_noprog;           // 游程长度供明细打印

	//-------------主要任务处理区域-------------//
	// 无进展游程计数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_noprog <= 32'd0;                // 复位清游程
		end else if(flag_reset_run == 1'b1)begin
			cnt_noprog <= 32'd0;                // 进展或故障出现时游程归零
		end else begin
			cnt_noprog <= cnt_noprog + 32'd1;   // 运行期无进展累加
		end
	end

	// 最长游程记录
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_max_noprog <= 32'd0;            // 复位清最长游程
		end else if(cnt_noprog > cnt_max_noprog)begin
			cnt_max_noprog <= cnt_noprog;       // 刷新最长无进展游程
		end else begin
			cnt_max_noprog <= cnt_max_noprog;   // 未超过时保持
		end
	end

	// 本游程已报告标志
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			flag_reported <= 1'b0;              // 复位后未报告
		end else if(flag_reset_run == 1'b1)begin
			flag_reported <= 1'b0;              // 游程结束允许下次再报
		end else if(flag_new_stall == 1'b1)begin
			flag_reported <= 1'b1;              // 同一游程只计一次
		end else begin
			flag_reported <= flag_reported;     // 游程中保持报告状态
		end
	end

	// 停滞次数累计
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_stall <= 32'd0;                 // 复位清停滞次数
		end else if(flag_new_stall == 1'b1)begin
			cnt_stall <= cnt_stall + 32'd1;     // 每次新停滞加一
		end else begin
			cnt_stall <= cnt_stall;             // 无新停滞时保持
		end
	end

endmodule
