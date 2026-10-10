`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V7 Generic Protocol Property Checkers (SVA)
// Module Name:     v7_chk_imp, v7_chk_imp_next, v7_chk_mutex, v7_chk_live
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.4
// Simulations:     verification/v2_v7/tb/tb_v7_assertion_selftest.sv (self-check), bound into ppg_control_top by v7_assertions.sv
//
// Referrences:     verification_reports/PRE_TAPEOUT_CLOSURE_PLAN_20261009.md V7
//
// Dependencies:    None (SystemVerilog, compiled separately with xvlog -sv; the RTL stays Verilog-2001)
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Four reusable checkers built on SVA concurrent assertions, which xsim 2022.2 was shown to evaluate correctly (a passing and a deliberately failing assertion, bind, hierarchical references, ##[m:n] and $past; cover property is not supported and is not used). v7_chk_imp: a |-> b. v7_chk_imp_next: a |=> b. v7_chk_mutex: !(a && b). v7_chk_live: while i_active, a run of C_LIMIT cycles with neither i_progress nor i_fault is a failure (counter-based, so no unbounded SVA operators are needed). Every checker is disabled while i_rstn is low, counts antecedent hits (to show it is not vacuous) and failures, prints "V7FAIL <name> ..." for the first C_DETAIL failures and one "V7SUM <name> PASS|FAIL fails=<n> hits=<n>" line from a final block.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V7通用协议性质检查器（SVA）
// 模块名称:        v7_chk_imp、v7_chk_imp_next、v7_chk_mutex、v7_chk_live
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.4节
// 仿真工程:        verification/v2_v7/tb/tb_v7_assertion_selftest.sv（自测），经v7_assertions.sv绑定到ppg_control_top
//
// 参考资料:        PRE_TAPEOUT_CLOSURE_PLAN_20261009.md V7
//
// 依赖文件:        无（SystemVerilog，单独用xvlog -sv编译；RTL保持Verilog-2001）
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。四个可复用检查器，基于SVA并发断言（已证实xsim 2022.2能正确判定：通过与故意失败各一条、bind、跨层次引用、##[m:n]、$past；cover property不支持，不使用）。v7_chk_imp：a |-> b；v7_chk_imp_next：a |=> b；v7_chk_mutex：!(a && b)；v7_chk_live：i_active期间连续C_LIMIT拍既无i_progress也无i_fault即失败（用计数器实现，不需要无界SVA算子）。复位为低时全部失效；统计前件命中次数（证明不是空真）与失败次数；前C_DETAIL次失败打印"V7FAIL <名称> ..."，final块打印一行"V7SUM <名称> PASS|FAIL fails=<n> hits=<n>"。

// 同拍蕴含：a成立的每一拍b都必须成立
module v7_chk_imp #(parameter string C_NAME = "imp", parameter int C_DETAIL = 5)
(
	input logic i_clk,                      // 采样时钟
	input logic i_rstn,                     // 低有效复位，期间不检查
	input logic i_a,                        // 前件
	input logic i_b                         // 后件
);
	int unsigned cnt_hit = 0;               // 前件命中次数
	int unsigned cnt_fail = 0;              // 失败次数
	always @(posedge i_clk) if(i_rstn && i_a) cnt_hit <= cnt_hit + 1;
	a_imp: assert property(@(posedge i_clk) disable iff(!i_rstn) i_a |-> i_b)
		else begin cnt_fail = cnt_fail + 1; if(cnt_fail <= C_DETAIL) $display("V7FAIL %s t=%0t", C_NAME, $time); end
	final $display("V7SUM %s %s fails=%0d hits=%0d", C_NAME, (cnt_fail == 0) ? "PASS" : "FAIL", cnt_fail, cnt_hit);
endmodule

// 下一拍蕴含：a成立后的下一拍b必须成立
module v7_chk_imp_next #(parameter string C_NAME = "imp_next", parameter int C_DETAIL = 5)
(
	input logic i_clk,                      // 采样时钟
	input logic i_rstn,                     // 低有效复位，期间不检查
	input logic i_a,                        // 前件
	input logic i_b                         // 下一拍的后件
);
	int unsigned cnt_hit = 0;               // 前件命中次数
	int unsigned cnt_fail = 0;              // 失败次数
	always @(posedge i_clk) if(i_rstn && i_a) cnt_hit <= cnt_hit + 1;
	a_imp_next: assert property(@(posedge i_clk) disable iff(!i_rstn) i_a |=> i_b)
		else begin cnt_fail = cnt_fail + 1; if(cnt_fail <= C_DETAIL) $display("V7FAIL %s t=%0t", C_NAME, $time); end
	final $display("V7SUM %s %s fails=%0d hits=%0d", C_NAME, (cnt_fail == 0) ? "PASS" : "FAIL", cnt_fail, cnt_hit);
endmodule

// 互斥：a与b不得同拍为1
module v7_chk_mutex #(parameter string C_NAME = "mutex", parameter int C_DETAIL = 5)
(
	input logic i_clk,                      // 采样时钟
	input logic i_rstn,                     // 低有效复位，期间不检查
	input logic i_a,                        // 事件一
	input logic i_b                         // 事件二
);
	int unsigned cnt_hit = 0;               // 任一事件出现次数
	int unsigned cnt_fail = 0;              // 失败次数
	always @(posedge i_clk) if(i_rstn && (i_a || i_b)) cnt_hit <= cnt_hit + 1;
	a_mutex: assert property(@(posedge i_clk) disable iff(!i_rstn) !(i_a && i_b))
		else begin cnt_fail = cnt_fail + 1; if(cnt_fail <= C_DETAIL) $display("V7FAIL %s t=%0t", C_NAME, $time); end
	final $display("V7SUM %s %s fails=%0d hits=%0d", C_NAME, (cnt_fail == 0) ? "PASS" : "FAIL", cnt_fail, cnt_hit);
endmodule

// 有界活性：i_active期间C_LIMIT拍内必须出现进展或故障记录
module v7_chk_live #(parameter string C_NAME = "live", parameter int C_LIMIT = 15000, parameter int C_DETAIL = 5)
(
	input logic i_clk,                      // 采样时钟
	input logic i_rstn,                     // 低有效复位，期间不检查
	input logic i_active,                   // 需要活性的生命周期阶段
	input logic i_progress,                 // 进展事件
	input logic i_fault                     // 故障记录或阻断保持
);
	int unsigned cnt_run = 0;               // 当前无进展游程
	int unsigned cnt_hit = 0;               // 活动拍数
	int unsigned cnt_fail = 0;              // 失败次数
	always @(posedge i_clk) begin
		if(!i_rstn || !i_active || i_progress || i_fault) cnt_run <= 0;
		else cnt_run <= cnt_run + 1;
		if(i_rstn && i_active) cnt_hit <= cnt_hit + 1;
	end
	a_live: assert property(@(posedge i_clk) disable iff(!i_rstn) (cnt_run != C_LIMIT))
		else begin cnt_fail = cnt_fail + 1; if(cnt_fail <= C_DETAIL) $display("V7FAIL %s t=%0t run=%0d", C_NAME, $time, cnt_run); end
	final $display("V7SUM %s %s fails=%0d hits=%0d", C_NAME, (cnt_fail == 0) ? "PASS" : "FAIL", cnt_fail, cnt_hit);
endmodule
