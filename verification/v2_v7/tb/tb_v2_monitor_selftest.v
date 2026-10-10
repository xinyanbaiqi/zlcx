`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026/10/10
// Design Name:     V2 Resident Monitor Negative/Positive Self-Check Testbench
// Module Name:     tb_v2_monitor_selftest
// Description:     verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md section 3.2 (monitor negative controls)
// Simulations:     Vivado xsim 2022.2
//
// Referrences:     verification/v2_v7/monitors/*.v
//
// Dependencies:    v2_mon_liveness.v, v2_mon_q3_bind.v, v2_mon_void_excl.v, v2_mon_frame_interval.v, v2_mon_recovery.v, v2_mon_identity.v
//
// Version:         V1.0
// Revision Date:   2026/10/10
// History:
//     Time          Version     Revised by     Contents
// 2026/10/10        V1.0        Erie          Create file. Drives every monitor core without any DUT, once with a compliant synthetic sequence (the fail count must stay 0) and once per rule with a violating sequence (the fail count must rise by exactly the expected amount, and for the identity scoreboard the reported failure code must be the expected one). Small limits are used through parameters (liveness 20, recovery 50, identity resolve 100) so the sequences stay short; the frame-interval monitor runs real 5000-cycle frames. Each case prints MONST-PASS / MONST-FAIL; the closing line MONITOR_SELFTEST_PASS appears only if every case passed and the expected number of cases ran.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年10月10日
// 设计名称:        V2常驻监视器正负对照自检测试平台
// 模块名称:        tb_v2_monitor_selftest
// 模块说明:        verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md第3.2节（监视器负对照）
// 仿真工程:        Vivado xsim 2022.2
//
// 参考资料:        verification/v2_v7/monitors/*.v
//
// 依赖文件:        六个监视器核心
//
// 当前版本:        V1.0
// 修订日期:        2026年10月10日
// 修订历史:
//     时间          版本        修订人        修订内容
// 2026年10月10日   V1.0        Erie          创建文件。不接DUT，逐个驱动监视器核心：先用合规的人造序列（失败计数必须保持0），再对每条规则用违反序列（失败计数必须恰好增加预期值；身份记分板还要核对失败码）。通过参数缩小门限（活性20、恢复50、身份了结100）以缩短序列；帧间隔监视器用真实的5000拍帧。每个用例打印MONST-PASS/MONST-FAIL，只有全部通过且用例数等于预期时才打印MONITOR_SELFTEST_PASS。

// 监视器自检：人造合规与违反序列
module tb_v2_monitor_selftest();

	localparam integer C_EXPECTED_CASES = 43;      // 预期用例数

	reg i_clk;                                     // 激励时钟
	reg i_rstn;                                    // 监视器复位
	integer cnt_pass;                              // 通过用例数
	integer cnt_fail;                              // 失败用例数

	initial begin
		i_clk = 1'b0;                              // 时钟初值
		forever #250 i_clk = ~i_clk;               // 2 MHz
	end

	// 检查一条用例
	task st_check;
		input [8 * 40 - 1:0] label;                // 用例名
		input cond;                                // 判定条件
		begin
			if(cond === 1'b1) begin cnt_pass = cnt_pass + 1; $display("MONST-PASS %0s", label); end
			else begin cnt_fail = cnt_fail + 1; $display("MONST-FAIL %0s", label); end
		end
	endtask


	//===================<活性监视>===================//
	reg lv_active, lv_progress, lv_fault;          // 活性输入
	wire [31:0] lv_fail, lv_max, lv_noprog;        // 活性输出
	wire lv_ev;                                    // 活性停滞事件
	v2_mon_liveness #(.C_LIMIT(20)) u_live(.i_clk(i_clk), .i_rstn(i_rstn), .i_active(lv_active), .i_progress(lv_progress), .i_fault_record(lv_fault),
		.o_fail_count(lv_fail), .o_max_noprog(lv_max), .o_stall_event(lv_ev), .o_noprog(lv_noprog));

	//===================<Q3绑定>===================//
	reg qb_q3, qb_inflight, qb_commit, qb_commit_cal; // Q3绑定输入
	reg [15:0] qb_frame;                           // 当前帧号
	reg [2:0] qb_sf;                               // 当前子帧
	wire [31:0] qb_q3n, qb_fail;                   // Q3绑定输出
	wire qb_ev;                                    // Q3绑定违例事件
	v2_mon_q3_bind u_bind(.i_clk(i_clk), .i_rstn(i_rstn), .i_q3(qb_q3), .i_sched_inflight(qb_inflight), .i_commit(qb_commit), .i_commit_cal(qb_commit_cal),
		.i_frame(qb_frame), .i_subframe(qb_sf), .o_q3_count(qb_q3n), .o_violation_count(qb_fail), .o_violation_event(qb_ev));

	//===================<作废与完成互斥>===================//
	reg ve_done, ve_lost;                          // 互斥输入
	wire [31:0] ve_dn, ve_ln, ve_fail;             // 互斥输出
	wire ve_ev;                                    // 互斥违例事件
	v2_mon_void_excl u_excl(.i_clk(i_clk), .i_rstn(i_rstn), .i_done(ve_done), .i_lost(ve_lost), .o_done_count(ve_dn), .o_lost_count(ve_ln), .o_violation_count(ve_fail), .o_violation_event(ve_ev));

	//===================<帧间隔>===================//
	reg fi_active, fi_cal, fi_start_ack, fi_excc, fi_break; // 帧间隔输入
	reg [12:0] fi_tick;                            // 人造宏帧相位
	wire [31:0] fi_frames, fi_first, fi_excc_n, fi_break_n, fi_fail, fi_interval; // 帧间隔输出
	wire fi_ev;                                    // 非5000起点事件
	wire [2:0] fi_class;                           // 起点分类
	v2_mon_frame_interval u_fi(.i_clk(i_clk), .i_rstn(i_rstn), .i_frame_active(fi_active), .i_cal_active(fi_cal), .i_macro_tick(fi_tick), .i_start_ack(fi_start_ack),
		.i_excc_cond(fi_excc), .i_frame_break(fi_break), .o_frame_count(fi_frames), .o_first_count(fi_first), .o_excc_count(fi_excc_n), .o_break_count(fi_break_n),
		.o_fail_count(fi_fail), .o_gap_event(fi_ev), .o_gap_class(fi_class), .o_gap_interval(fi_interval));

	//===================<恢复检查>===================//
	reg rc_stop, rc_config, rc_fault, rc_start, rc_fstart, rc_result, rc_expect; // 恢复输入
	wire [31:0] rc_sn, rc_sf, rc_sm, rc_tn, rc_tf, rc_tm, rc_rn, rc_rf, rc_rm; // 恢复输出
	wire rc_ev;                                    // 恢复超界事件
	v2_mon_recovery #(.C_STOP_CONFIG_MAX(50), .C_START_FRAME_MAX(50), .C_RESULT_MAX(50)) u_rc(.i_clk(i_clk), .i_rstn(i_rstn), .i_stop_ack(rc_stop), .i_life_config(rc_config),
		.i_fault_record(rc_fault), .i_start_ack(rc_start), .i_frame_start(rc_fstart), .i_result(rc_result), .i_expect_result(rc_expect),
		.o_stop_count(rc_sn), .o_stop_fail(rc_sf), .o_stop_max(rc_sm), .o_start_count(rc_tn), .o_start_fail(rc_tf), .o_start_max(rc_tm),
		.o_result_count(rc_rn), .o_result_fail(rc_rf), .o_result_max(rc_rm), .o_fail_event(rc_ev));

	//===================<身份记分板>===================//
	reg id_start, id_commit, id_done, id_succ, id_lost, id_res, id_disc, id_excl; // 身份事件输入
	reg [15:0] id_cf, id_ci;                       // 提交帧号与序号
	reg id_cc, id_cp;                              // 提交颜色与精度
	reg [1:0] id_ct;                               // 提交类型
	reg id_si, id_ss, id_sa;                       // 三方在途
	reg [15:0] id_sf, id_sx, id_af, id_ax;         // SSW/AMI帧号与序号
	reg id_sc, id_ac, id_sp, id_ap;                // SSW/AMI颜色与精度
	reg [1:0] id_st, id_at;                        // SSW/AMI类型
	reg [15:0] id_close;                           // 关闭序号
	reg [15:0] id_rf, id_rx, id_df, id_dx;         // 结果与discard帧号序号
	reg id_rc, id_dc;                              // 结果与discard颜色
	reg [1:0] id_rt, id_dt;                        // 结果与discard类型
	wire [31:0] id_n_commit, id_n_close, id_n_res, id_n_disc, id_fail, id_n_excl; // 身份输出
	wire id_ev;                                    // 身份违例事件
	wire [3:0] id_code;                            // 身份失败码
	reg [3:0] id_last_code;                        // 最近一次失败码
	always @(posedge i_clk) if(id_ev) begin id_last_code <= id_code; if($test$plusargs("MONST_DBG")) $display("DBG id_ev code=%0d t=%0t", id_code, $time); end
	v2_mon_identity #(.C_RESOLVE_MAX(100)) u_id(.i_clk(i_clk), .i_rstn(i_rstn), .i_start_ack(id_start),
		.i_commit(id_commit), .i_commit_frame(id_cf), .i_commit_idx(id_ci), .i_commit_color(id_cc), .i_commit_type(id_ct), .i_commit_prec(id_cp), .i_sched_inflight(id_si),
		.i_ssw_inflight(id_ss), .i_ssw_frame(id_sf), .i_ssw_idx(id_sx), .i_ssw_color(id_sc), .i_ssw_type(id_st), .i_ssw_prec(id_sp),
		.i_ami_inflight(id_sa), .i_ami_frame(id_af), .i_ami_idx(id_ax), .i_ami_color(id_ac), .i_ami_type(id_at), .i_ami_prec(id_ap),
		.i_done(id_done), .i_done_success(id_succ), .i_lost(id_lost), .i_close_idx(id_close),
		.i_result(id_res), .i_res_frame(id_rf), .i_res_idx(id_rx), .i_res_color(id_rc), .i_res_type(id_rt),
		.i_disc(id_disc), .i_disc_frame(id_df), .i_disc_idx(id_dx), .i_disc_color(id_dc), .i_disc_type(id_dt), .i_excl_window(id_excl),
		.o_commit_count(id_n_commit), .o_close_count(id_n_close), .o_result_count(id_n_res), .o_discard_count(id_n_disc), .o_fail_count(id_fail), .o_excl_count(id_n_excl),
		.o_fail_event(id_ev), .o_fail_code(id_code));

	// 身份记分板：一笔合规的提交（下一拍三方记录与提交一致）
	task id_do_commit;
		input [15:0] f;                            // 帧号
		input [15:0] x;                            // 序号
		input c;                                   // 颜色
		input [1:0] t;                             // 类型
		begin
			@(negedge i_clk); id_commit = 1'b1; id_cf = f; id_ci = x; id_cc = c; id_ct = t; id_cp = 1'b0;
			@(negedge i_clk); id_commit = 1'b0;
			id_si = 1'b1; id_ss = 1'b1; id_sa = 1'b1;
			id_sf = f; id_sx = x; id_sc = c; id_st = t; id_sp = 1'b0;
			id_af = f; id_ax = x; id_ac = c; id_at = t; id_ap = 1'b0;
			repeat(3) @(negedge i_clk);
		end
	endtask

	// 身份记分板：完成（succ=1/0）或作废，关闭拍后三方标志落下
	task id_do_close;
		input lost;                                // 1作废，0完成
		input succ;                                // 完成成功资格
		input [15:0] x;                            // 关闭序号
		begin
			@(negedge i_clk); id_done = !lost; id_lost = lost; id_succ = succ; id_close = x;
			@(negedge i_clk); id_done = 1'b0; id_lost = 1'b0; id_succ = 1'b0;
			id_si = 1'b0; id_ss = 1'b0; id_sa = 1'b0;
			repeat(2) @(negedge i_clk);
		end
	endtask

	// 身份记分板：正式结果
	task id_do_result;
		input [15:0] f;                            // 结果帧号
		input [15:0] x;                            // 结果序号
		input c;                                   // 结果颜色
		begin
			@(negedge i_clk); id_res = 1'b1; id_rf = f; id_rx = x; id_rc = c; id_rt = 2'b10;
			@(negedge i_clk); id_res = 1'b0;
			repeat(2) @(negedge i_clk);
		end
	endtask

	// 身份记分板：discard
	task id_do_disc;
		input [15:0] f;                            // discard帧号
		input [15:0] x;                            // discard序号
		input c;                                   // discard颜色
		input [1:0] t;                             // discard类型
		begin
			@(negedge i_clk); id_disc = 1'b1; id_df = f; id_dx = x; id_dc = c; id_dt = t;
			@(negedge i_clk); id_disc = 1'b0;
			repeat(2) @(negedge i_clk);
		end
	endtask

	// 帧间隔：从当前相位推进n拍（帧活动时相位0..4999循环）
	task fi_run;
		input integer n;                           // 推进拍数
		integer k;
		begin
			for(k = 0; k < n; k = k + 1) begin
				@(negedge i_clk);
				if(fi_active) fi_tick = (fi_tick == 13'd4999) ? 13'd0 : fi_tick + 13'd1;
			end
		end
	endtask

	// 帧间隔：空闲gap拍后在tick 0起一帧
	task fi_restart;
		input integer gap;                         // 空闲拍数
		input cal;                                 // 新帧是否校准帧
		begin
			@(negedge i_clk); fi_active = 1'b0;
			repeat(gap) @(negedge i_clk);
			fi_tick = 13'd0; fi_active = 1'b1; fi_cal = cal;
		end
	endtask

	// 复位全部监视器
	task st_reset;
		begin
			@(negedge i_clk); i_rstn = 1'b0; id_si = 1'b0; id_ss = 1'b0; id_sa = 1'b0; // 复位拉低，同时撤销人造三方在途标志
			repeat(2) @(negedge i_clk);            // 复位保持
			i_rstn = 1'b1;                         // 释放
			@(negedge i_clk);                      // 稳定一拍
		end
	endtask

	initial begin : main_sequence
		integer base;
		integer k;
		cnt_pass = 0; cnt_fail = 0;
		i_rstn = 1'b0;
		lv_active = 0; lv_progress = 0; lv_fault = 0;
		qb_q3 = 0; qb_inflight = 0; qb_commit = 0; qb_commit_cal = 0; qb_frame = 0; qb_sf = 0;
		ve_done = 0; ve_lost = 0;
		fi_active = 0; fi_cal = 0; fi_start_ack = 0; fi_excc = 0; fi_break = 0; fi_tick = 0;
		rc_stop = 0; rc_config = 1; rc_fault = 0; rc_start = 0; rc_fstart = 0; rc_result = 0; rc_expect = 0;
		id_start = 0; id_commit = 0; id_done = 0; id_succ = 0; id_lost = 0; id_res = 0; id_disc = 0; id_excl = 0;
		id_cf = 0; id_ci = 0; id_cc = 0; id_cp = 0; id_ct = 0; id_si = 0; id_ss = 0; id_sa = 0;
		id_sf = 0; id_sx = 0; id_af = 0; id_ax = 0; id_sc = 0; id_ac = 0; id_sp = 0; id_ap = 0; id_st = 0; id_at = 0;
		id_close = 0; id_rf = 0; id_rx = 0; id_df = 0; id_dx = 0; id_rc = 0; id_dc = 0; id_rt = 0; id_dt = 0; id_last_code = 0;
		st_reset;

		//---------------活性---------------//
		lv_active = 1;
		for(k = 0; k < 10; k = k + 1) begin repeat(15) @(negedge i_clk); lv_progress = 1; @(negedge i_clk); lv_progress = 0; end
		st_check("LIVE-OK-PROGRESS-EVERY-15", lv_fail == 0);
		repeat(25) @(negedge i_clk);
		st_check("LIVE-NEG-25-SILENT", lv_fail == 1);
		repeat(40) @(negedge i_clk);
		st_check("LIVE-NEG-ONE-COUNT-PER-RUN", lv_fail == 1);
		lv_fault = 1; @(negedge i_clk); lv_fault = 0; base = lv_fail;
		lv_fault = 1; repeat(40) @(negedge i_clk); lv_fault = 0; @(negedge i_clk);
		st_check("LIVE-OK-FAULT-HOLD-EXEMPT", lv_fail == base);
		lv_active = 0; repeat(40) @(negedge i_clk);
		st_check("LIVE-OK-INACTIVE-EXEMPT", lv_fail == base);
		lv_active = 1; repeat(22) @(negedge i_clk); lv_active = 0;
		st_check("LIVE-NEG-AFTER-REARM", lv_fail == base + 1);

		//---------------Q3绑定---------------//
		st_reset;
		qb_frame = 5; @(negedge i_clk); qb_commit = 1; qb_commit_cal = 0; @(negedge i_clk); qb_commit = 0; qb_inflight = 1;
		repeat(3) @(negedge i_clk); qb_q3 = 1; repeat(2) @(negedge i_clk); qb_q3 = 0; repeat(2) @(negedge i_clk);
		st_check("Q3BIND-OK-SAME-FRAME", (qb_fail == 0) && (qb_q3n == 1));
		qb_inflight = 0; qb_q3 = 1; repeat(2) @(negedge i_clk); qb_q3 = 0; repeat(2) @(negedge i_clk);
		st_check("Q3BIND-NEG-NO-OWNER", qb_fail == 1);
		qb_inflight = 1; qb_frame = 6; qb_q3 = 1; repeat(2) @(negedge i_clk); qb_q3 = 0; repeat(2) @(negedge i_clk);
		st_check("Q3BIND-NEG-CROSS-FRAME", qb_fail == 2);
		qb_frame = 7; qb_sf = 1; @(negedge i_clk); qb_commit = 1; qb_commit_cal = 1; @(negedge i_clk); qb_commit = 0;
		qb_q3 = 1; repeat(2) @(negedge i_clk); qb_q3 = 0; repeat(2) @(negedge i_clk);
		st_check("Q3BIND-OK-CAL-SAME-SUBFRAME", qb_fail == 2);
		qb_sf = 2; qb_q3 = 1; repeat(2) @(negedge i_clk); qb_q3 = 0; repeat(2) @(negedge i_clk);
		st_check("Q3BIND-NEG-CAL-CROSS-SUBFRAME", qb_fail == 3);

		//---------------作废与完成互斥---------------//
		st_reset;
		@(negedge i_clk); ve_done = 1; @(negedge i_clk); ve_done = 0; ve_lost = 1; @(negedge i_clk); ve_lost = 0; @(negedge i_clk);
		st_check("VOIDEXCL-OK-SEPARATE", (ve_fail == 0) && (ve_dn == 1) && (ve_ln == 1));
		ve_done = 1; ve_lost = 1; @(negedge i_clk); ve_done = 0; ve_lost = 0; @(negedge i_clk);
		st_check("VOIDEXCL-NEG-SAME-CYCLE", ve_fail == 1);

		//---------------恢复检查---------------//
		st_reset;
		rc_config = 0; @(negedge i_clk); rc_stop = 1; @(negedge i_clk); rc_stop = 0; repeat(30) @(negedge i_clk); rc_config = 1; repeat(3) @(negedge i_clk);
		st_check("RECOVERY-OK-STOP-30", (rc_sf == 0) && (rc_sn == 1) && (rc_sm >= 30));
		rc_config = 0; @(negedge i_clk); rc_stop = 1; @(negedge i_clk); rc_stop = 0; repeat(60) @(negedge i_clk); rc_config = 1; repeat(3) @(negedge i_clk);
		st_check("RECOVERY-NEG-STOP-SILENT-60", rc_sf == 1);
		rc_config = 0; @(negedge i_clk); rc_stop = 1; @(negedge i_clk); rc_stop = 0; repeat(10) @(negedge i_clk); rc_fault = 1; @(negedge i_clk); rc_fault = 0;
		repeat(60) @(negedge i_clk); rc_config = 1; repeat(3) @(negedge i_clk);
		st_check("RECOVERY-OK-STOP-LONG-WITH-FAULT", rc_sf == 1);
		rc_config = 0; rc_expect = 1; @(negedge i_clk); rc_start = 1; @(negedge i_clk); rc_start = 0; repeat(20) @(negedge i_clk);
		rc_fstart = 1; @(negedge i_clk); rc_fstart = 0; repeat(30) @(negedge i_clk); rc_result = 1; @(negedge i_clk); rc_result = 0; repeat(3) @(negedge i_clk);
		st_check("RECOVERY-OK-START-AND-RESULT", (rc_tf == 0) && (rc_rf == 0) && (rc_tn == 1) && (rc_rn == 1));
		@(negedge i_clk); rc_start = 1; @(negedge i_clk); rc_start = 0; repeat(60) @(negedge i_clk); rc_fstart = 1; @(negedge i_clk); rc_fstart = 0; repeat(3) @(negedge i_clk);
		st_check("RECOVERY-NEG-START-NO-FRAME-60", rc_tf == 1);
		repeat(60) @(negedge i_clk);
		st_check("RECOVERY-NEG-NO-RESULT-60", rc_rf == 1);
		rc_expect = 0; @(negedge i_clk); rc_start = 1; @(negedge i_clk); rc_start = 0; repeat(10) @(negedge i_clk); rc_fstart = 1; @(negedge i_clk); rc_fstart = 0; repeat(80) @(negedge i_clk);
		st_check("RECOVERY-OK-NO-RESULT-NOT-EXPECTED", rc_rf == 1);

		//---------------身份记分板---------------//
		st_reset;
		id_do_commit(16'd3, 16'd10, 1'b0, 2'b10); id_do_close(1'b0, 1'b1, 16'd10); id_do_result(16'd3, 16'd10, 1'b0);
		id_do_commit(16'd3, 16'd11, 1'b1, 2'b10); id_do_close(1'b0, 1'b1, 16'd11); id_do_result(16'd3, 16'd11, 1'b1);
		id_do_commit(16'd4, 16'd12, 1'b0, 2'b00); id_do_close(1'b0, 1'b1, 16'd12);
		id_do_commit(16'd4, 16'd13, 1'b0, 2'b10); id_do_close(1'b1, 1'b0, 16'd13); id_do_disc(16'd4, 16'd13, 1'b0, 2'b10);
		st_check("IDENT-OK-NORMAL-CAL-LOST-DISCARD", (id_fail == 0) && (id_n_res == 2) && (id_n_disc == 1) && (id_n_commit == 4) && (id_n_close == 4));
		// 1 重复提交
		base = id_fail; id_do_commit(16'd5, 16'd20, 1'b0, 2'b10); id_do_commit(16'd5, 16'd21, 1'b0, 2'b10);
		st_check("IDENT-NEG-DOUBLE-COMMIT", (id_fail == base + 1) && (id_last_code == 4'd1));
		id_do_close(1'b0, 1'b0, 16'd21);
		// 2 记录不一致
		st_reset; base = id_fail;
		@(negedge i_clk); id_commit = 1; id_cf = 6; id_ci = 30; id_cc = 0; id_ct = 2'b10; @(negedge i_clk); id_commit = 0;
		id_si = 1; id_ss = 1; id_sa = 1; id_sf = 6; id_sx = 31; id_st = 2'b10; id_af = 6; id_ax = 30; id_at = 2'b10; repeat(1) @(negedge i_clk);
		st_check("IDENT-NEG-SSW-RECORD-MISMATCH", (id_fail == base + 1) && (id_last_code == 4'd2));
		id_sx = 30; id_do_close(1'b0, 1'b0, 16'd30);
		// 3 在途标志不一致
		st_reset; base = id_fail; id_do_commit(16'd7, 16'd40, 1'b0, 2'b10);
		id_sa = 0; @(negedge i_clk); id_sa = 1; repeat(2) @(negedge i_clk);
		st_check("IDENT-NEG-INFLIGHT-DISAGREE", (id_fail == base + 1) && (id_last_code == 4'd3));
		id_do_close(1'b0, 1'b0, 16'd40);
		// 4 无owner关闭
		base = id_fail; id_do_close(1'b0, 1'b1, 16'd40);
		st_check("IDENT-NEG-CLOSE-WITHOUT-OWNER", (id_fail == base + 1) && (id_last_code == 4'd4));
		// 5 关闭序号不符
		st_reset; base = id_fail; id_do_commit(16'd8, 16'd50, 1'b0, 2'b10); id_do_close(1'b0, 1'b1, 16'd51);
		st_check("IDENT-NEG-CLOSE-INDEX", (id_fail == base + 1) && (id_last_code == 4'd5));
		// 6 无owner结果
		st_reset; base = id_fail; id_do_result(16'd9, 16'd60, 1'b0);
		st_check("IDENT-NEG-RESULT-WITHOUT-OWNER", (id_fail == base + 1) && (id_last_code == 4'd6));
		// 6' 结果错绑到另一帧号
		st_reset; base = id_fail; id_do_commit(16'd9, 16'd61, 1'b0, 2'b10); id_do_close(1'b0, 1'b1, 16'd61); id_do_result(16'd10, 16'd61, 1'b0);
		st_check("IDENT-NEG-RESULT-WRONG-FRAME", (id_fail >= base + 1) && (id_last_code == 4'd6));
		// 7 无owner discard
		st_reset; base = id_fail; id_do_disc(16'd11, 16'd70, 1'b1, 2'b10);
		st_check("IDENT-NEG-DISCARD-WITHOUT-OWNER", (id_fail == base + 1) && (id_last_code == 4'd7));
		// 8 完成未了结
		st_reset; base = id_fail; id_do_commit(16'd12, 16'd80, 1'b0, 2'b10); id_do_close(1'b0, 1'b1, 16'd80); repeat(120) @(negedge i_clk);
		st_check("IDENT-NEG-UNRESOLVED", (id_fail == base + 1) && (id_last_code == 4'd8));
		// 9 START时owner仍打开
		st_reset; base = id_fail; id_do_commit(16'd13, 16'd90, 1'b0, 2'b10); @(negedge i_clk); id_start = 1; @(negedge i_clk); id_start = 0; repeat(2) @(negedge i_clk);
		st_check("IDENT-NEG-OPEN-AT-START", (id_fail == base + 1) && (id_last_code == 4'd9));
		// 10 待决表溢出
		st_reset; base = id_fail;
		id_do_commit(16'd14, 16'd1, 1'b0, 2'b10); id_do_close(1'b0, 1'b1, 16'd1);
		id_do_commit(16'd14, 16'd2, 1'b1, 2'b10); id_do_close(1'b0, 1'b1, 16'd2);
		id_do_commit(16'd15, 16'd3, 1'b0, 2'b10); id_do_close(1'b0, 1'b1, 16'd3);
		st_check("IDENT-NEG-PENDING-OVERFLOW", (id_fail == base + 1) && (id_last_code == 4'd10));
		// F-3前提窗口：违例计入excl而非fail
		st_reset; base = id_fail; id_excl = 1; id_do_close(1'b0, 1'b1, 16'd99); id_excl = 0;
		st_check("IDENT-OK-F3-WINDOW-EXCLUDED", (id_fail == base) && (id_n_excl == 1));
		// 作废与原因11 discard同拍（RTL实际时序）
		st_reset; base = id_fail; id_do_commit(16'd17, 16'd6, 1'b0, 2'b10);
		@(negedge i_clk); id_lost = 1; id_close = 16'd6; id_disc = 1; id_df = 16'd17; id_dx = 16'd6; id_dc = 1'b0; id_dt = 2'b10;
		@(negedge i_clk); id_lost = 0; id_disc = 0; id_si = 0; id_ss = 0; id_sa = 0; repeat(3) @(negedge i_clk);
		st_check("IDENT-OK-VOID-AND-DISCARD-SAME-CYCLE", (id_fail == base) && (id_n_disc == 1));
		// 成功完成被discard了结（不是结果）
		st_reset; base = id_fail; id_do_commit(16'd16, 16'd5, 1'b1, 2'b10); id_do_close(1'b0, 1'b1, 16'd5); id_do_disc(16'd16, 16'd5, 1'b1, 2'b10); repeat(120) @(negedge i_clk);
		st_check("IDENT-OK-SUCCESS-THEN-DISCARD", (id_fail == base) && (id_n_disc == 1));

		//---------------帧间隔（真实5000拍帧）---------------//
		st_reset;
		@(negedge i_clk); fi_start_ack = 1; @(negedge i_clk); fi_start_ack = 0;
		fi_restart(5, 1'b0); fi_run(15002);
		st_check("FRAMEGAP-OK-FIRST-THEN-5000", (fi_fail == 0) && (fi_first == 1) && (fi_frames == 4));
		// 非5000间隔且无放行理由
		fi_restart(3, 1'b0); fi_run(100);
		st_check("FRAMEGAP-NEG-GAP-NO-REASON", fi_fail == 1);
		// 帧被打断后的间隔放行
		fi_run(4899); @(negedge i_clk); fi_break = 1; @(negedge i_clk); fi_break = 0; fi_restart(10, 1'b0); fi_run(100);
		st_check("FRAMEGAP-OK-BREAK", (fi_fail == 1) && (fi_break_n == 1));
		// 例外C：校准帧末拍条件成立、空2拍以上
		fi_cal = 1; while(fi_tick != 13'd4998) fi_run(1); fi_excc = 1; fi_run(1); @(negedge i_clk); fi_excc = 0; fi_restart(4, 1'b1); fi_run(100);
		st_check("FRAMEGAP-OK-EXCC-CONDITIONED", (fi_fail == 1) && (fi_excc_n == 1));
		// 例外C条件成立但间隔只有5001（空不足2拍）
		while(fi_tick != 13'd4998) fi_run(1); fi_excc = 1; fi_run(1); @(negedge i_clk); fi_excc = 0; fi_active = 0; @(negedge i_clk); fi_tick = 13'd0; fi_active = 1; fi_run(100);
		st_check("FRAMEGAP-NEG-EXCC-TOO-SHORT", fi_fail == 2);
		// 校准帧末拍条件不成立时同样的空拍判FAIL
		while(fi_tick != 13'd4998) fi_run(1); fi_run(1); fi_restart(4, 1'b1); fi_run(100);
		st_check("FRAMEGAP-NEG-EXCC-COND-ABSENT", fi_fail == 3);
		// NORMAL帧末拍的例外C条件不采信
		fi_cal = 0; while(fi_tick != 13'd4998) fi_run(1); fi_excc = 1; fi_run(1); fi_excc = 0; fi_restart(4, 1'b0); fi_run(100);
		st_check("FRAMEGAP-NEG-EXCC-ON-NORMAL-FRAME", fi_fail == 4);
		// START后首帧不计
		@(negedge i_clk); fi_start_ack = 1; @(negedge i_clk); fi_start_ack = 0; fi_restart(37, 1'b0); fi_run(100);
		st_check("FRAMEGAP-OK-FIRST-AFTER-START", (fi_fail == 4) && (fi_first == 2));

		if((cnt_fail == 0) && (cnt_pass == C_EXPECTED_CASES)) $display("MONITOR_SELFTEST_PASS cases=%0d", cnt_pass);
		else $display("MONITOR_SELFTEST_FAIL pass=%0d fail=%0d expected=%0d", cnt_pass, cnt_fail, C_EXPECTED_CASES);
		$finish;
	end

endmodule
