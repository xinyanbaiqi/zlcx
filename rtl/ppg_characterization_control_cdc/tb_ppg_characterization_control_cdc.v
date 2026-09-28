`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Codex
//
// Create Date:     2026/08/14
// Design Name:     PPG Characterization Control CDC Testbench
// Module Name:     tb_ppg_characterization_control_cdc
// Description:     Self-check CCC-01 through CCC-26 against the frozen V1.0 contract.
// Simulations:     tb_ppg_characterization_control_cdc
//
// Referrences:     PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md
//
// Dependencies:    ppg_config_cdc_bridge.v,
//                  ppg_characterization_control_cdc.v
//
// Version:         V1.0
// Revision Date:   2026/08/14
// History:
// 2026/08/14       V1.0        Codex          Create real self-checking CDC testbench.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Codex
//
// 创建日期:        2026年08月14日
// 设计名称:        PPG表征控制CDC自检
// 模块名称:        tb_ppg_characterization_control_cdc
// 模块说明:        按冻结合同逐项真实比较CCC-01至CCC-26。
// 仿真工程:        tb_ppg_characterization_control_cdc
//
// 参考资料:        PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md
//
// 依赖文件:        ppg_config_cdc_bridge.v、
//                  ppg_characterization_control_cdc.v
//
// 当前版本:        V1.0
// 修订日期:        2026年08月14日
// 修订历史:
// 2026年08月14日   V1.0        Codex          创建真实比较CDC自检平台。

module tb_ppg_characterization_control_cdc;

	localparam integer C_SYSTEM_CLK_HALF_NS = 5;
	localparam integer C_SOURCE_CLK_HALF_NS = 7;
	localparam integer C_RESULT_TIMEOUT_CYCLES = 80;

	reg i_source_clk;
	reg i_source_rstn;
	reg i_source_update_valid;
	reg i_source_static_characterization_enable;
	reg [4:0]i_source_test_mux_ctrl;
	reg i_clk;
	reg i_rstn;
	reg i_run_enable;
	reg i_diag_clear_event;

	wire o_source_update_ready;
	wire o_static_characterization_enable;
	wire [4:0]o_test_mux_ctrl;
	wire o_control_valid;
	wire o_control_update_event;
	wire o_control_reject_event;
	wire o_protocol_error_sticky;

	integer cnt_error;
	integer cnt_pass;
	integer cnt_update_event;
	integer cnt_reject_event;
	integer cnt_monitor_error;
	reg reg_last_static_enable;
	reg [4:0]reg_last_test_mux_ctrl;
	reg reg_last_control_valid;
	reg flag_event_collision;

	ppg_characterization_control_cdc ppg_characterization_control_cdc_Inst(
		.i_source_clk(i_source_clk),
		.i_source_rstn(i_source_rstn),
		.i_source_update_valid(i_source_update_valid),
		.i_source_static_characterization_enable(i_source_static_characterization_enable),
		.i_source_test_mux_ctrl(i_source_test_mux_ctrl),
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_run_enable(i_run_enable),
		.i_diag_clear_event(i_diag_clear_event),
		.o_source_update_ready(o_source_update_ready),
		.o_static_characterization_enable(o_static_characterization_enable),
		.o_test_mux_ctrl(o_test_mux_ctrl),
		.o_control_valid(o_control_valid),
		.o_control_update_event(o_control_update_event),
		.o_control_reject_event(o_control_reject_event),
		.o_protocol_error_sticky(o_protocol_error_sticky)
	);

	// 2 MHz目标域时钟在仿真中缩短到10 ns周期，保持与source域非整数相位关系。
	always #C_SYSTEM_CLK_HALF_NS i_clk = ~i_clk;

	// SPI source时钟使用14 ns周期，避免与目标时钟形成固定整数倍相位。
	always #C_SOURCE_CLK_HALF_NS i_source_clk = ~i_source_clk;

	// 目标域监视器记录真实事务事件，并检查输出改写是否与单拍提交原子绑定。
	always@(posedge i_clk)begin
		#1;
		if(i_rstn == 1'b0)begin
			cnt_update_event = 0;
			cnt_reject_event = 0;
			cnt_monitor_error = 0;
			reg_last_static_enable = 1'b0;
			reg_last_test_mux_ctrl = 5'b00000;
			reg_last_control_valid = 1'b0;
			flag_event_collision = 1'b0;
		end else begin
			if(o_control_update_event == 1'b1)begin
				cnt_update_event = cnt_update_event + 1;
			end
			if(o_control_reject_event == 1'b1)begin
				cnt_reject_event = cnt_reject_event + 1;
			end
			if((o_control_update_event == 1'b1) && (o_control_reject_event == 1'b1))begin
				flag_event_collision = 1'b1;
				cnt_monitor_error = cnt_monitor_error + 1;
			end
			if(((o_static_characterization_enable != reg_last_static_enable) || (o_test_mux_ctrl != reg_last_test_mux_ctrl) || (o_control_valid != reg_last_control_valid)) && (o_control_update_event != 1'b1))begin
				cnt_monitor_error = cnt_monitor_error + 1;
			end
			reg_last_static_enable = o_static_characterization_enable;
			reg_last_test_mux_ctrl = o_test_mux_ctrl;
			reg_last_control_valid = o_control_valid;
		end
	end

	// 每个合同编号只在对应真实布尔比较通过后输出PASS，否则记录全局失败。
	task check_case;
		input [7:0]case_number;
		input flag_condition;
		begin
			if(flag_condition === 1'b1)begin
				cnt_pass = cnt_pass + 1;
				$display("PASS CCC-%0d", case_number);
			end else begin
				cnt_error = cnt_error + 1;
				$display("FAIL CCC-%0d at %0t", case_number, $time);
			end
		end
	endtask

	// 在source域以保持型valid发起一笔完整控制快照，并仅在ready握手后撤销valid。
	task submit_control;
		input static_enable_value;
		input [4:0]test_mux_value;
		begin
			@(negedge i_source_clk);
			i_source_static_characterization_enable = static_enable_value;
			i_source_test_mux_ctrl = test_mux_value;
			i_source_update_valid = 1'b1;
			while(o_source_update_ready !== 1'b1)begin
				@(posedge i_source_clk);
			end
			@(posedge i_source_clk);
			#1;
			i_source_update_valid = 1'b0;
			@(posedge i_source_clk);
			#1;
		end
	endtask

	// 此任务在刚完成source握手后返回，供复位或STOP插入到CDC在途窗口。
	task launch_control_inflight;
		input static_enable_value;
		input [4:0]test_mux_value;
		begin
			@(negedge i_source_clk);
			i_source_static_characterization_enable = static_enable_value;
			i_source_test_mux_ctrl = test_mux_value;
			i_source_update_valid = 1'b1;
			while(o_source_update_ready !== 1'b1)begin
				@(posedge i_source_clk);
			end
			@(posedge i_source_clk);
			#1;
			i_source_update_valid = 1'b0;
		end
	endtask

	// 等待真实bridge结果事件，并区分目标域接受和整笔拒绝两种互斥结果。
	task wait_for_result;
		output flag_accept;
		output flag_reject;
		integer cnt_wait;
		begin
			flag_accept = 1'b0;
			flag_reject = 1'b0;
			cnt_wait = 0;
			while((o_control_update_event !== 1'b1) && (o_control_reject_event !== 1'b1) && (cnt_wait < C_RESULT_TIMEOUT_CYCLES))begin
				@(posedge i_clk);
				#1;
				cnt_wait = cnt_wait + 1;
			end
			if(o_control_update_event === 1'b1)begin
				flag_accept = 1'b1;
			end
			if(o_control_reject_event === 1'b1)begin
				flag_reject = 1'b1;
			end
			if((flag_accept == 1'b0) && (flag_reject == 1'b0))begin
				cnt_error = cnt_error + 1;
				$display("FAIL CDC result timeout at %0t", $time);
			end
		end
	endtask

	// 固定等待目标域周期，确保脉冲统计和稳定性检查均在非阻塞赋值后完成。
	task wait_system_cycles;
		input [7:0]cycle_count;
		integer cnt_cycle;
		begin
			for(cnt_cycle = 0; cnt_cycle < cycle_count; cnt_cycle = cnt_cycle + 1)begin
				@(posedge i_clk);
				#1;
			end
		end
	endtask

	// 清除源端、目标端和诊断驱动，保证每个场景只有合同允许的控制输入变化。
	task set_idle_inputs;
		begin
			i_source_update_valid = 1'b0;
			i_source_static_characterization_enable = 1'b0;
			i_source_test_mux_ctrl = 5'b00000;
			i_run_enable = 1'b0;
			i_diag_clear_event = 1'b0;
		end
	endtask

	reg flag_accept;
	reg flag_reject;
	reg reg_static_before;
	reg [4:0]reg_mux_before;
	reg reg_valid_before;
	integer cnt_event_before;
	integer cnt_reject_before;
	integer cnt_error_before;
	integer cnt_random_index;

	// 主验证过程按合同顺序驱动异步域事务，并对CCC-01至CCC-26逐项作真实比较。
	initial begin
		i_source_clk = 1'b0;
		i_clk = 1'b0;
		i_source_rstn = 1'b0;
		i_rstn = 1'b0;
		cnt_error = 0;
		cnt_pass = 0;
		cnt_update_event = 0;
		cnt_reject_event = 0;
		cnt_monitor_error = 0;
		reg_last_static_enable = 1'b0;
		reg_last_test_mux_ctrl = 5'b00000;
		reg_last_control_valid = 1'b0;
		flag_event_collision = 1'b0;
		set_idle_inputs;

		// CCC-01: 共同断言复位必须清零两域可见状态、有效位、事件和sticky。
		#3;
		check_case(8'd1, (o_static_characterization_enable === 1'b0) &&
			(o_test_mux_ctrl === 5'b00000) &&
			(o_control_valid === 1'b0) &&
			(o_control_update_event === 1'b0) &&
			(o_control_reject_event === 1'b0) &&
			(o_protocol_error_sticky === 1'b0));

		// CCC-02: 两个时钟域错开释放复位时，不能生成虚假的目标域事务或诊断。
		#4;
		i_source_rstn = 1'b1;
		#17;
		i_rstn = 1'b1;
		wait_system_cycles(8'd6);
		check_case(8'd2, (cnt_update_event == 0) && (cnt_reject_event == 0) &&
			(o_control_valid === 1'b0) && (o_protocol_error_sticky === 1'b0));

		// CCC-03和CCC-04: 首笔传输必须原子提交，并严格保持bit5/bit4:0打包定义。
		submit_control(1'b1, 5'b10101);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd3, (flag_accept === 1'b1) && (flag_reject === 1'b0) &&
			(o_control_valid === 1'b1));
		check_case(8'd4, (o_static_characterization_enable === 1'b1) &&
			(o_test_mux_ctrl === 5'b10101));

		// CCC-05至CCC-08: 故意保持valid，验证只接受一次、busy反压、原子更新和单拍事件。
		cnt_event_before = cnt_update_event;
		@(negedge i_source_clk);
		i_source_static_characterization_enable = 1'b1;
		i_source_test_mux_ctrl = 5'b01011;
		i_source_update_valid = 1'b1;
		@(posedge i_source_clk);
		#1;
		check_case(8'd6, o_source_update_ready === 1'b0);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd4);
		check_case(8'd5, (flag_accept === 1'b1) && (flag_reject === 1'b0) &&
			(o_source_update_ready === 1'b0) && (cnt_update_event == (cnt_event_before + 1)));
		check_case(8'd7, (o_static_characterization_enable === 1'b1) &&
			(o_test_mux_ctrl === 5'b01011) && (cnt_monitor_error == 0));
		check_case(8'd8, cnt_update_event == (cnt_event_before + 1));
		i_source_update_valid = 1'b0;
		@(posedge i_source_clk);
		#1;

		// CCC-09: 没有新提交时，已提交控制和有效位必须长期保持稳定。
		reg_static_before = o_static_characterization_enable;
		reg_mux_before = o_test_mux_ctrl;
		reg_valid_before = o_control_valid;
		cnt_event_before = cnt_update_event;
		wait_system_cycles(8'd12);
		check_case(8'd9, (o_static_characterization_enable === reg_static_before) &&
			(o_test_mux_ctrl === reg_mux_before) && (o_control_valid === reg_valid_before) &&
			(cnt_update_event == cnt_event_before));

		// CCC-10: 前一笔应答返回后，两笔连续事务均必须独立提交。
		cnt_event_before = cnt_update_event;
		submit_control(1'b1, 5'b00110);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		submit_control(1'b1, 5'b11100);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd10, (flag_accept === 1'b1) && (flag_reject === 1'b0) &&
			(o_test_mux_ctrl === 5'b11100) && (cnt_update_event == (cnt_event_before + 2)));

		// CCC-11: 相同控制值重复提交仍是独立事务，必须产生真实update脉冲。
		cnt_event_before = cnt_update_event;
		reg_static_before = o_static_characterization_enable;
		reg_mux_before = o_test_mux_ctrl;
		submit_control(reg_static_before, reg_mux_before);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd11, (flag_accept === 1'b1) && (o_static_characterization_enable === reg_static_before) &&
			(o_test_mux_ctrl === reg_mux_before) && (cnt_update_event == (cnt_event_before + 1)));

		// CCC-12: 在多个source发起相位下传输不同快照，结果与事务数必须一致。
		cnt_event_before = cnt_update_event;
		for(cnt_random_index = 0; cnt_random_index < 3; cnt_random_index = cnt_random_index + 1)begin
			#(cnt_random_index + 1);
			submit_control(1'b1, (5'b10000 + cnt_random_index));
			wait_for_result(flag_accept, flag_reject);
			wait_system_cycles(8'd1);
		end
		check_case(8'd12, (o_static_characterization_enable === 1'b1) &&
			(o_test_mux_ctrl === 5'b10010) && (cnt_update_event == (cnt_event_before + 3)));

		// CCC-13: STATIC_BIAS RUN中使能保持1时允许完整五位MUX原子更新。
		i_run_enable = 1'b1;
		submit_control(1'b1, 5'b01101);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd13, (flag_accept === 1'b1) && (flag_reject === 1'b0) &&
			(o_static_characterization_enable === 1'b1) && (o_test_mux_ctrl === 5'b01101));

		// CCC-14和CCC-16: RUN中从STATIC_BIAS退出必须整笔拒绝，两个控制字段均不能部分提交。
		reg_static_before = o_static_characterization_enable;
		reg_mux_before = o_test_mux_ctrl;
		cnt_reject_before = cnt_reject_event;
		submit_control(1'b0, 5'b00001);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd14, (flag_accept === 1'b0) && (flag_reject === 1'b1) &&
			(o_protocol_error_sticky === 1'b1) && (cnt_reject_event == (cnt_reject_before + 1)));
		check_case(8'd16, (o_static_characterization_enable === reg_static_before) &&
			(o_test_mux_ctrl === reg_mux_before));

		// CCC-15: 先在STOP状态合法进入动态控制，再验证RUN中禁止0到1进入STATIC_BIAS。
		i_run_enable = 1'b0;
		submit_control(1'b0, 5'b00101);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd1);
		i_run_enable = 1'b1;
		submit_control(1'b1, 5'b11111);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd15, (flag_accept === 1'b0) && (flag_reject === 1'b1) &&
			(o_static_characterization_enable === 1'b0) && (o_test_mux_ctrl === 5'b00101));

		// CCC-17: NORMAL RUN可以预装MUX但不会改变已提交的静态使能控制。
		submit_control(1'b0, 5'b11010);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd17, (flag_accept === 1'b1) && (o_static_characterization_enable === 1'b0) &&
			(o_test_mux_ctrl === 5'b11010));

		// CCC-18: STOP只撤销消费者RUN上下文，CDC已提交配置和valid不得被擦除。
		i_run_enable = 1'b0;
		reg_static_before = o_static_characterization_enable;
		reg_mux_before = o_test_mux_ctrl;
		reg_valid_before = o_control_valid;
		wait_system_cycles(8'd5);
		check_case(8'd18, (o_static_characterization_enable === reg_static_before) &&
			(o_test_mux_ctrl === reg_mux_before) && (o_control_valid === reg_valid_before));

		// CCC-19: STOP后run_enable为0时允许重新提交不同的静态模式控制。
		submit_control(1'b1, 5'b00111);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd19, (flag_accept === 1'b1) && (o_static_characterization_enable === 1'b1) &&
			(o_test_mux_ctrl === 5'b00111));

		// CCC-20: abort不属于本CDC端口；没有新source事务时CDC不得自行生成状态或事件。
		reg_static_before = o_static_characterization_enable;
		reg_mux_before = o_test_mux_ctrl;
		cnt_event_before = cnt_update_event;
		cnt_reject_before = cnt_reject_event;
		wait_system_cycles(8'd6);
		check_case(8'd20, (o_static_characterization_enable === reg_static_before) &&
			(o_test_mux_ctrl === reg_mux_before) && (cnt_update_event == cnt_event_before) &&
			(cnt_reject_event == cnt_reject_before));

		// CCC-21: 在途事务后立即STOP，CDC最多结算一次结果且不会自行恢复任何模拟动作。
		i_run_enable = 1'b1;
		cnt_event_before = cnt_update_event;
		cnt_reject_before = cnt_reject_event;
		launch_control_inflight(1'b1, 5'b01001);
		i_run_enable = 1'b0;
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd5);
		check_case(8'd21, ((cnt_update_event + cnt_reject_event) ==
			(cnt_event_before + cnt_reject_before + 1)) && (o_control_update_event === 1'b0) &&
			(o_control_reject_event === 1'b0));

		// CCC-22: 软件清sticky不改配置；若清除与新拒绝同拍，拒绝置位必须优先。
		reg_static_before = o_static_characterization_enable;
		reg_mux_before = o_test_mux_ctrl;
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1;
		i_diag_clear_event = 1'b0;
		wait_system_cycles(8'd1);
		i_run_enable = 1'b1;
		launch_control_inflight(1'b0, 5'b11110);
		i_diag_clear_event = 1'b1;
		wait_for_result(flag_accept, flag_reject);
		i_diag_clear_event = 1'b0;
		wait_system_cycles(8'd2);
		check_case(8'd22, (flag_reject === 1'b1) && (o_protocol_error_sticky === 1'b1) &&
			(o_static_characterization_enable === reg_static_before) && (o_test_mux_ctrl === reg_mux_before));

		// CCC-23: 共同复位在请求同步完成前撤销在途事务，旧请求不得在释放后迟到提交。
		i_run_enable = 1'b0;
		launch_control_inflight(1'b0, 5'b10110);
		#1;
		i_source_rstn = 1'b0;
		i_rstn = 1'b0;
		#9;
		i_source_rstn = 1'b1;
		#11;
		i_rstn = 1'b1;
		wait_system_cycles(8'd8);
		check_case(8'd23, (o_static_characterization_enable === 1'b0) &&
			(o_test_mux_ctrl === 5'b00000) && (o_control_valid === 1'b0) &&
			(o_control_update_event === 1'b0) && (o_control_reject_event === 1'b0) &&
			(o_protocol_error_sticky === 1'b0));

		// CCC-24: 未与valid握手绑定的source shadow变化不允许旁路到目标域输出。
		reg_static_before = o_static_characterization_enable;
		reg_mux_before = o_test_mux_ctrl;
		i_source_static_characterization_enable = 1'b1;
		i_source_test_mux_ctrl = 5'b11111;
		wait_system_cycles(8'd6);
		check_case(8'd24, (o_static_characterization_enable === reg_static_before) &&
			(o_test_mux_ctrl === reg_mux_before) && (o_control_valid === 1'b0));

		// CCC-25: 首笔合法控制尚未提交时，RUN内任何到达更新必须整笔拒绝并置sticky。
		i_run_enable = 1'b1;
		submit_control(1'b1, 5'b00011);
		wait_for_result(flag_accept, flag_reject);
		wait_system_cycles(8'd2);
		check_case(8'd25, (flag_accept === 1'b0) && (flag_reject === 1'b1) &&
			(o_control_valid === 1'b0) && (o_protocol_error_sticky === 1'b1));

		// CCC-26: 整个回归中update与reject必须始终互斥，监视器不得发现任何碰撞。
		check_case(8'd26, (flag_event_collision === 1'b0) && (cnt_monitor_error == 0));

		if(cnt_error == 0)begin
			$display("ALL CCC-01 TO CCC-26 PASS (%0d checks)", cnt_pass);
		end else begin
			$display("CCC REGRESSION FAIL (%0d failures, %0d passes)", cnt_error, cnt_pass);
		end
		#20;
		$finish;
	end

	// 看门狗在任何事务或任务意外悬停时强制结束仿真并输出明确失败标识。
	initial begin
		#20000;
		$display("FAIL watchdog timeout");
		$finish;
	end

endmodule
