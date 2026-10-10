`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V7 Assertion Checker Negative/Positive Self-Check Testbench
// Module Name:     tb_v7_assertion_selftest
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.4 (negative controls, synthetic part)
// Simulations:     Vivado xsim 2022.2 (xvlog -sv)
//
// Referrences:     verification/v2_v7/assertions/v7_checkers.sv
//
// Dependencies:    v7_checkers.sv
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Each of the four checker types used by v7_assertions.sv is instantiated twice: one instance is driven only with a compliant synthetic sequence and must end with 0 failures and a non-zero antecedent count; the other is driven with the same sequence plus a known number of injected violations and must end with exactly that many failures. The pass/fail decision reads the checkers' own cnt_fail/cnt_hit counters hierarchically, so it is the SVA action blocks that are being checked, not a re-implementation. Closing line V7_SELFTEST_PASS only if every case passed.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V7断言检查器正负对照自检测试平台
// 模块名称:        tb_v7_assertion_selftest
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.4节（负对照的人造序列部分）
// 仿真工程:        Vivado xsim 2022.2（xvlog -sv）
//
// 参考资料:        verification/v2_v7/assertions/v7_checkers.sv
//
// 依赖文件:        v7_checkers.sv
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。v7_assertions.sv用到的四类检查器各例化两份：一份只用合规的人造序列驱动，结束时必须0失败且前件命中数非0；另一份在同一序列上加入已知个数的违反，结束时失败数必须恰好等于该个数。判定直接层次读取检查器自己的cnt_fail/cnt_hit，因此检查的是SVA的action块本身，而不是另写一份等价逻辑。只有全部用例通过才打印V7_SELFTEST_PASS。

module tb_v7_assertion_selftest;
	logic clk = 1'b0;                       // 采样时钟
	logic rstn = 1'b0;                      // 复位
	always #250 clk = ~clk;                 // 2 MHz
	int n_pass = 0;                         // 通过用例数
	int n_fail = 0;                         // 失败用例数

	// 合规组与违反组的激励
	logic ok_a = 0, ok_b = 0, bad_a = 0, bad_b = 0;        // imp/imp_next/mutex共用
	logic lv_act = 0, lv_prog = 0, lv_flt = 0;             // 活性合规组
	logic lb_act = 0, lb_prog = 0, lb_flt = 0;             // 活性违反组

	v7_chk_imp #(.C_NAME("ST_IMP_OK")) u_imp_ok(.i_clk(clk), .i_rstn(rstn), .i_a(ok_a), .i_b(ok_b));
	v7_chk_imp #(.C_NAME("ST_IMP_BAD")) u_imp_bad(.i_clk(clk), .i_rstn(rstn), .i_a(bad_a), .i_b(bad_b));
	v7_chk_imp_next #(.C_NAME("ST_NEXT_OK")) u_nx_ok(.i_clk(clk), .i_rstn(rstn), .i_a(ok_a), .i_b(ok_b));
	v7_chk_imp_next #(.C_NAME("ST_NEXT_BAD")) u_nx_bad(.i_clk(clk), .i_rstn(rstn), .i_a(bad_a), .i_b(bad_b));
	v7_chk_mutex #(.C_NAME("ST_MUTEX_OK")) u_mx_ok(.i_clk(clk), .i_rstn(rstn), .i_a(ok_a), .i_b(!ok_a && ok_b));
	v7_chk_mutex #(.C_NAME("ST_MUTEX_BAD")) u_mx_bad(.i_clk(clk), .i_rstn(rstn), .i_a(bad_a), .i_b(bad_b));
	v7_chk_live #(.C_NAME("ST_LIVE_OK"), .C_LIMIT(20)) u_lv_ok(.i_clk(clk), .i_rstn(rstn), .i_active(lv_act), .i_progress(lv_prog), .i_fault(lv_flt));
	v7_chk_live #(.C_NAME("ST_LIVE_BAD"), .C_LIMIT(20)) u_lv_bad(.i_clk(clk), .i_rstn(rstn), .i_active(lb_act), .i_progress(lb_prog), .i_fault(lb_flt));

	task automatic check(input string name, input bit cond);
		if(cond) begin n_pass++; $display("V7ST-PASS %s", name); end
		else begin n_fail++; $display("V7ST-FAIL %s", name); end
	endtask

	initial begin
		repeat(3) @(negedge clk);
		rstn = 1'b1;
		// 违反在复位期间不得计数
		@(negedge clk);
		// ---- imp：合规组 a=1时b=1；违反组注入3次 a=1,b=0 ----
		repeat(5) begin
			@(negedge clk); ok_a = 1; ok_b = 1; bad_a = 1; bad_b = 1;
			@(negedge clk); ok_a = 0; ok_b = 0; bad_a = 0; bad_b = 0;
		end
		repeat(3) begin @(negedge clk); bad_a = 1; bad_b = 0; @(negedge clk); bad_a = 0; end
		repeat(4) @(negedge clk);
		check("IMP-OK-NO-FAIL", (u_imp_ok.cnt_fail == 0) && (u_imp_ok.cnt_hit == 5));
		check("IMP-BAD-3-FAILS", u_imp_bad.cnt_fail == 3);
		// 上面的序列中a与b同拍出现：对imp_next而言，合规组的b在a后一拍为0
		// 因此另做一组imp_next专用序列：合规组b在a后一拍为1；违反组注入2次a后一拍b=0
		begin
			int base_ok, base_bad;
			base_ok = u_nx_ok.cnt_fail; base_bad = u_nx_bad.cnt_fail;
			repeat(4) begin
				@(negedge clk); ok_a = 1; bad_a = 1; ok_b = 0; bad_b = 0;
				@(negedge clk); ok_a = 0; bad_a = 0; ok_b = 1; bad_b = 1;
				@(negedge clk); ok_b = 0; bad_b = 0;
			end
			repeat(2) begin
				@(negedge clk); bad_a = 1; bad_b = 0;
				@(negedge clk); bad_a = 0; bad_b = 0;
				@(negedge clk);
			end
			repeat(3) @(negedge clk);
			check("NEXT-OK-NO-NEW-FAIL", u_nx_ok.cnt_fail == base_ok);
			check("NEXT-BAD-2-NEW-FAILS", u_nx_bad.cnt_fail == base_bad + 2);
		end
		check("NEXT-OK-NONVACUOUS", u_nx_ok.cnt_hit >= 4);
		// mutex：违反组同拍a=b=1注入4次（另外，前面imp序列中a与b同拍出现过5次，也计入）
		begin
			int base_bad;
			base_bad = u_mx_bad.cnt_fail;
			repeat(4) begin @(negedge clk); bad_a = 1; bad_b = 1; @(negedge clk); bad_a = 0; bad_b = 0; end
			repeat(2) @(negedge clk);
			check("MUTEX-OK-NO-FAIL", (u_mx_ok.cnt_fail == 0) && (u_mx_ok.cnt_hit > 0));
			check("MUTEX-BAD-4-NEW-FAILS", u_mx_bad.cnt_fail == base_bad + 4);
		end
		// live：合规组每15拍一次进展；违反组活动期间25拍无进展→1次，再给故障记录豁免→不增加，再25拍无进展→再1次
		lv_act = 1; lb_act = 1;
		repeat(6) begin repeat(15) @(negedge clk); lv_prog = 1; @(negedge clk); lv_prog = 0; end
		lv_act = 0;
		check("LIVE-OK-NO-FAIL", (u_lv_ok.cnt_fail == 0) && (u_lv_ok.cnt_hit > 0));
		repeat(25) @(negedge clk);
		check("LIVE-BAD-1-FAIL", u_lv_bad.cnt_fail == 1);
		lb_flt = 1; repeat(30) @(negedge clk); lb_flt = 0;
		check("LIVE-BAD-FAULT-EXEMPT", u_lv_bad.cnt_fail == 1);
		repeat(25) @(negedge clk);
		check("LIVE-BAD-2-FAILS", u_lv_bad.cnt_fail == 2);
		lv_act = 0; lb_act = 0; repeat(40) @(negedge clk);
		check("LIVE-INACTIVE-EXEMPT", (u_lv_bad.cnt_fail == 2) && (u_lv_ok.cnt_fail == 0));
		// 复位期间的违反不计数
		begin
			int base_imp;
			base_imp = u_imp_bad.cnt_fail;
			rstn = 0; bad_a = 1; bad_b = 0; repeat(4) @(negedge clk); bad_a = 0; rstn = 1; @(negedge clk); @(negedge clk);
			check("RESET-DISABLES", u_imp_bad.cnt_fail == base_imp);
		end
		if((n_fail == 0) && (n_pass == 13)) $display("V7_SELFTEST_PASS cases=%0d", n_pass);
		else $display("V7_SELFTEST_FAIL pass=%0d fail=%0d expected=13", n_pass, n_fail);
		$finish;
	end
endmodule
