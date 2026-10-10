`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 Resident Void/Completion Exclusivity Monitor
// Module Name:     v2_mon_void_excl
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.2 item 6
// Simulations:     verification/v2_v7/tb/tb_v2_monitor_selftest.v, verification/v2_v7/tb/tb_v2_sweep.v
//
// Referrences:     rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v V1.2 lines 1037-1047 (cnt_excl_violation)
//
// Dependencies:    None
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Module form of the void/completion exclusivity count copied from tb_ppg_control_top_adc_anomaly.v V1.2: AMI's completion-lost void event and its completion event must never be asserted in the same cycle. Also counts voids and completions so the TB can show the check was not vacuous. Synthesizable checker core.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2常驻作废与完成互斥监视器
// 模块名称:        v2_mon_void_excl
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.2节第6项
// 仿真工程:        verification/v2_v7/tb/tb_v2_monitor_selftest.v、verification/v2_v7/tb/tb_v2_sweep.v
//
// 参考资料:        rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v V1.2第1037~1047行（cnt_excl_violation）
//
// 依赖文件:        无
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。把tb_ppg_control_top_adc_anomaly.v V1.2的作废与完成互斥计数复制改写为模块：AMI的完成丢失作废事件与完成事件不得同拍出现。同时统计作废与完成次数，供TB说明检查不是空真。可综合检查核心。

// 作废与完成互斥监视：同一拍不得既作废又完成
module v2_mon_void_excl
(
	//---------------全局信号---------------//
	input i_clk,                            // 与DUT同源的2 MHz时钟
	input i_rstn,                           // 低有效监视器复位

	//---------------用户接口---------------//
	input i_done,                           // AMI完成事件单拍
	input i_lost,                           // AMI完成丢失作废单拍
	output [31:0] o_done_count,             // 完成事件累计
	output [31:0] o_lost_count,             // 作废事件累计
	output [31:0] o_violation_count,        // 同拍既作废又完成的次数
	output o_violation_event                // 本拍发生互斥违例
);

	//---------------计数信号---------------//
	// 完成、作废与违例次数
	reg [31:0] cnt_complete;                // 完成事件计数器
	reg [31:0] cnt_lost;                    // 作废事件计数器
	reg [31:0] cnt_violation;               // 互斥违例计数器

	//---------------标志信号---------------//
	// 互斥判定
	wire flag_violation;                    // 本拍完成与作废同时为1

	//---------------其他信号---------------//

	//---------------输出信号---------------//

	//-------------其他信号连线-------------//
	// 互斥判定组合逻辑
	assign flag_violation = i_done && i_lost; // 两事件同拍即违例

	//-------------输出信号连线-------------//
	// 计数与事件送出
	assign o_done_count = cnt_complete;     // 完成次数供汇总说明非空真
	assign o_lost_count = cnt_lost;         // 作废次数供汇总说明非空真
	assign o_violation_count = cnt_violation; // 违例次数供结论
	assign o_violation_event = flag_violation; // 违例单拍供明细

	//-------------主要任务处理区域-------------//
	// 完成次数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_complete <= 32'd0;              // 复位清完成次数
		end else if(i_done == 1'b1)begin
			cnt_complete <= cnt_complete + 32'd1; // 每次完成加一
		end else begin
			cnt_complete <= cnt_complete;       // 无完成保持
		end
	end

	// 作废次数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_lost <= 32'd0;                  // 复位清作废次数
		end else if(i_lost == 1'b1)begin
			cnt_lost <= cnt_lost + 32'd1;       // 每次作废加一
		end else begin
			cnt_lost <= cnt_lost;               // 无作废保持
		end
	end

	// 违例次数
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			cnt_violation <= 32'd0;             // 复位清违例次数
		end else if(flag_violation == 1'b1)begin
			cnt_violation <= cnt_violation + 32'd1; // 同拍冲突加一
		end else begin
			cnt_violation <= cnt_violation;     // 无冲突保持
		end
	end

endmodule
