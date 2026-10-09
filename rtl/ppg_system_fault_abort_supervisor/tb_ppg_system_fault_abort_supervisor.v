`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:         Erie
// Engineer:        Erie
//
// Create Date:     2026-08-23
// Design Name:     PPG System Fault Abort Supervisor Verification
// Module Name:     tb_ppg_system_fault_abort_supervisor
// Description:     Self-checking SUP-01 through SUP-12 directed regression.
// Simulations:     Vivado xsim 2022.2
//
// Referrences:     PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md
//
// Dependencies:
//      DUT only, no child submodules
//
// Version:         V1.5
// Revision Date:   2026-10-09
// History:
// 2026-08-23           V1.0       Erie        Create file.
// 2026-09-28           V1.1       Erie        Add SUP10A: a second, independently-closed episode after SUP09A, asserting the full abort/STOP/discard trio and a fresh snapshot fire again -- closes a real dynamic-coverage gap for K02/N06's "later episode independent of first-fault history" claim, which previously had only static RTL-reading support and no simulation evidence.
// 2026-10-05           V1.2       Erie        ABCD review F-012: add the TB-local check RE-ARM (deliberately not a SUP-nn label: contract C24 SUP-10 means something else). After SUP10A the first-fault snapshot is deliberately NOT diag-cleared; once the episode really closes, an independent Scheduler cause 0x11 record must open a new episode with a full abort/STOP/discard trio while cause 0x03/source/identity stay as the retained first fault and only summary bit 0x0008 is added (contract section 4). Pass criterion 14 -> 15. Negative control: RTL episode-open changed from !blocking to !cause_valid passes the old 14 but fails RE-ARM.
// 2026-10-06           V1.3       Erie        ABCD review F-014: add TB-local check WDPARM (6-character label like the others): the instantiated watchdog parameters must be legal, CYCLES>=1 and COUNTER_WIDTH>=$clog2(CYCLES+1). This TB deliberately uses the shortened 8/4; the frozen product values 5000/13 are checked in the control-top and chip-top TBs. Pass criterion 15 -> 16. Negative control: with C_WD_WIDTH=3 only WDPARM fails, while every behavioural check still passes, which is exactly the silent risk the check guards against.
// 2026-10-08           V1.4       Erie        Owner-lifecycle round step 3: new TB-local checks SUM-06 / SUM-07 (AMI-originated cause 8'h06 sets summary bit 9 = 0x0200, cause 8'h07 sets summary bit 10 = 0x0400, source 4'h1). Pass gate 16 -> 18.
// 2026-10-09           V1.5       Erie        B merge batch (ID governance): label strings only. SUP03A->CLRBLK, SUP06A->EPICLS, SUP09A->WDIDLE, SUP10A->EPI2ND (they do not test the same-numbered C24 rows); the final banner lists the SUP rows actually checked. Checks and counts unchanged.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:        Erie
// 开发人员:        Erie
//
// 创建日期:        2026年08月23日
// 设计名称:        PPG系统故障与abort监督器验证
// 模块名称:        tb_ppg_system_fault_abort_supervisor
// 模块说明:        自检式SUP-01至SUP-12回归，DUT为单一模块，不例化任何子模块
// 仿真工程:        Vivado xsim 2022.2
//
// 参考资料:        PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md
//
// 依赖文件:
//      仅DUT本体
//
// 当前版本:        V1.4
// 修订日期:        2026年10月09日
// 修订历史:
// 2026-08-23           V1.0       Erie        创建文件
// 2026-09-28           V1.1       Erie        新增SUP10A：在SUP09A之后、独立完整关闭一次episode后，再验证第二个episode依然完整触发abort/STOP/丢弃三事件并锁存全新快照——补齐K02/N06"后续episode独立于首故障历史"这条此前只有RTL静态阅读支持、从未被真实仿真动态验证过的缺口
// 2026-10-05           V1.2       Erie        ABCD复核F-012：新增TB本地检查RE-ARM（刻意不用SUP族编号：合同C24的SUP-10是另一含义）。SUP10A之后故意不做诊断清除，episode真实关闭后送入独立的Scheduler cause 0x11记录，必须重新开episode并发出完整abort/STOP/丢弃三事件，首故障cause 0x03/来源/身份保持不变，只新增汇总位0x0008（合同第4节）。判据14项改为15项。负对照：RTL把episode开启条件由!blocking改为!cause_valid时，旧14项仍全通过，RE-ARM失败。
// 2026-10-06           V1.3       Erie        ABCD复核F-014：新增TB本地检查WDPARM（与其余标签同为6字符）：实际例化的看门狗参数必须合法，CYCLES>=1且COUNTER_WIDTH>=$clog2(CYCLES+1)。本TB故意用缩短的8/4；产品固定值5000/13由控制顶层与芯片顶层TB核对。判据15改为16。负对照：C_WD_WIDTH改为3时只有WDPARM失败，其余行为检查全部仍通过，这正是该检查要防的静默风险
// 2026-10-08           V1.4       Erie        owner生命周期轮第三步：新增TB本地检查SUM-06/SUM-07（AMI来源cause 8'h06置summary bit 9=0x0200，cause 8'h07置bit 10=0x0400，来源4'h1）。判据16改为18。
// 2026-10-09           V1.5       Erie        B合并批次（编号治理）：只改标签字符串。SUP03A->CLRBLK、SUP06A->EPICLS、SUP09A->WDIDLE、SUP10A->EPI2ND（它们测的不是C24同号条目）；总横幅改为列出实际检查的SUP条目。判定与计数不变。

module tb_ppg_system_fault_abort_supervisor ();

	//===================<参数定义>===================//
	localparam integer C_CLK_PERIOD = 10;       // 仿真时钟周期纳秒数
	localparam integer C_WD_CYCLES = 8;         // 缩短后的看门狗阈值，加快仿真
	localparam integer C_WD_WIDTH = 4;          // 缩短阈值对应的计数器位宽

	//===================<寄存器信号>===================//
	reg i_clk;                                  // 仿真工作时钟
	reg i_rstn;                                 // DUT低有效异步复位
	reg i_ami_fault_valid;                      // AMI单周期记录valid
	reg i_ami_fault_active;                     // AMI lane-active电平
	reg [7:0]i_ami_fault_cause;                 // AMI记录cause
	reg i_ami_fault_identity_valid;             // AMI记录身份可信位
	reg [15:0]i_ami_fault_frame_id;             // AMI记录帧号
	reg [15:0]i_ami_fault_sample_index;         // AMI记录序号
	reg i_ami_fault_color_ir;                   // AMI记录颜色
	reg [1:0]i_ami_fault_frame_type;            // AMI记录类型
	reg i_ami_fault_precision;                  // AMI记录精度
	reg [7:0]i_ami_fault_run_generation;        // AMI记录代次
	reg i_scheduler_fault_valid;                // Scheduler单周期记录valid
	reg i_scheduler_fault_active;                // Scheduler active电平
	reg [7:0]i_scheduler_fault_cause;           // Scheduler记录cause
	reg i_scheduler_fault_identity_valid;       // Scheduler记录身份可信位
	reg [15:0]i_scheduler_fault_frame_id;       // Scheduler记录帧号
	reg [15:0]i_scheduler_fault_sample_index;   // Scheduler记录序号
	reg i_scheduler_fault_color_ir;             // Scheduler记录颜色
	reg [1:0]i_scheduler_fault_frame_type;      // Scheduler记录类型
	reg i_scheduler_fault_precision;            // Scheduler记录精度
	reg [7:0]i_scheduler_fault_run_generation;  // Scheduler记录代次
	reg i_ssw_fault_valid;                      // SSW单周期记录valid
	reg i_ssw_fault_active;                     // SSW active电平
	reg [7:0]i_ssw_fault_cause;                 // SSW记录cause
	reg i_ssw_fault_identity_valid;             // SSW记录身份可信位
	reg [15:0]i_ssw_fault_frame_id;             // SSW记录帧号
	reg [15:0]i_ssw_fault_sample_index;         // SSW记录序号
	reg i_ssw_fault_color_ir;                   // SSW记录颜色
	reg [1:0]i_ssw_fault_frame_type;            // SSW记录类型
	reg i_ssw_fault_precision;                  // SSW记录精度
	reg [7:0]i_ssw_fault_run_generation;        // SSW记录代次
	reg i_stop_episode_active;                  // 接受drain episode电平
	reg i_adc_physical_idle;                    // 物理ADC空闲事实
	reg i_diag_clear_event;                     // 诊断清除单周期事件
	reg i_measurement_result_discard_event;     // AMI正式结果丢弃单周期观测
	integer cnt_pass;                           // 累计真实通过比较数
	integer cnt_fail;                           // 累计真实失败比较数
	integer int_wait_index;                     // 看门狗等待循环索引

	//===================<导线信号>===================//
	wire o_system_fault_blocking;               // DUT输出：阻断状态
	wire o_system_abort_event;                  // DUT输出：abort单拍
	wire o_system_stop_request_event;           // DUT输出：STOP请求单拍
	wire o_system_fault_discard_event;          // DUT输出：丢弃选择单拍
	wire o_system_fault_cause_valid;            // DUT输出：首故障快照是否锁存
	wire [7:0]o_system_fault_cause;             // DUT输出：首故障cause快照
	wire [3:0]o_system_fault_source;            // DUT输出：首故障来源快照
	wire o_system_fault_identity_valid;         // DUT输出：首故障身份可信位快照
	wire [15:0]o_system_fault_frame_id;         // DUT输出：首故障帧号快照
	wire [15:0]o_system_fault_sample_index;     // DUT输出：首故障序号快照
	wire o_system_fault_color_ir;               // DUT输出：首故障颜色快照
	wire [1:0]o_system_fault_frame_type;        // DUT输出：首故障类型快照
	wire o_system_fault_precision;              // DUT输出：首故障精度快照
	wire [7:0]o_system_fault_run_generation;    // DUT输出：首故障代次快照
	wire [15:0]o_system_fault_summary;          // DUT输出：历史汇总位图
	wire o_result_discard_summary_sticky;       // DUT输出：结果丢弃历史sticky

	//===================<DUT例化>===================//
	// 看门狗阈值缩短为8拍，仅为加快仿真，不改变DUT本体逻辑。
	ppg_system_fault_abort_supervisor #(
		.C_FRAME_ID_WIDTH(16),
		.C_SAMPLE_INDEX_WIDTH(16),
		.C_CONFIG_EPOCH_WIDTH(8),
		.C_COEF_EPOCH_WIDTH(8),
		.C_DC_RECOVERY_EPOCH_WIDTH(8),
		.C_CODE_EPOCH_WIDTH(4),
		.C_RUN_GENERATION_WIDTH(8),
		.C_FAULT_CAUSE_WIDTH(8),
		.C_FAULT_SOURCE_WIDTH(4),
		.C_FAULT_SUMMARY_WIDTH(16),
		.C_ADC_DRAIN_WATCHDOG_CYCLES(C_WD_CYCLES),
		.C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH(C_WD_WIDTH)
	) dut (
		.i_clk(i_clk),
		.i_rstn(i_rstn),
		.i_ami_fault_valid(i_ami_fault_valid),
		.i_ami_fault_active(i_ami_fault_active),
		.i_ami_fault_cause(i_ami_fault_cause),
		.i_ami_fault_identity_valid(i_ami_fault_identity_valid),
		.i_ami_fault_frame_id(i_ami_fault_frame_id),
		.i_ami_fault_sample_index(i_ami_fault_sample_index),
		.i_ami_fault_color_ir(i_ami_fault_color_ir),
		.i_ami_fault_frame_type(i_ami_fault_frame_type),
		.i_ami_fault_precision(i_ami_fault_precision),
		.i_ami_fault_run_generation(i_ami_fault_run_generation),
		.i_scheduler_fault_valid(i_scheduler_fault_valid),
		.i_scheduler_fault_active(i_scheduler_fault_active),
		.i_scheduler_fault_cause(i_scheduler_fault_cause),
		.i_scheduler_fault_identity_valid(i_scheduler_fault_identity_valid),
		.i_scheduler_fault_frame_id(i_scheduler_fault_frame_id),
		.i_scheduler_fault_sample_index(i_scheduler_fault_sample_index),
		.i_scheduler_fault_color_ir(i_scheduler_fault_color_ir),
		.i_scheduler_fault_frame_type(i_scheduler_fault_frame_type),
		.i_scheduler_fault_precision(i_scheduler_fault_precision),
		.i_scheduler_fault_run_generation(i_scheduler_fault_run_generation),
		.i_ssw_fault_valid(i_ssw_fault_valid),
		.i_ssw_fault_active(i_ssw_fault_active),
		.i_ssw_fault_cause(i_ssw_fault_cause),
		.i_ssw_fault_identity_valid(i_ssw_fault_identity_valid),
		.i_ssw_fault_frame_id(i_ssw_fault_frame_id),
		.i_ssw_fault_sample_index(i_ssw_fault_sample_index),
		.i_ssw_fault_color_ir(i_ssw_fault_color_ir),
		.i_ssw_fault_frame_type(i_ssw_fault_frame_type),
		.i_ssw_fault_precision(i_ssw_fault_precision),
		.i_ssw_fault_run_generation(i_ssw_fault_run_generation),
		.i_stop_episode_active(i_stop_episode_active),
		.i_adc_physical_idle(i_adc_physical_idle),
		.i_diag_clear_event(i_diag_clear_event),
		.i_measurement_result_discard_event(i_measurement_result_discard_event),
		.o_system_fault_blocking(o_system_fault_blocking),
		.o_system_abort_event(o_system_abort_event),
		.o_system_stop_request_event(o_system_stop_request_event),
		.o_system_fault_discard_event(o_system_fault_discard_event),
		.o_system_fault_cause_valid(o_system_fault_cause_valid),
		.o_system_fault_cause(o_system_fault_cause),
		.o_system_fault_source(o_system_fault_source),
		.o_system_fault_identity_valid(o_system_fault_identity_valid),
		.o_system_fault_frame_id(o_system_fault_frame_id),
		.o_system_fault_sample_index(o_system_fault_sample_index),
		.o_system_fault_color_ir(o_system_fault_color_ir),
		.o_system_fault_frame_type(o_system_fault_frame_type),
		.o_system_fault_precision(o_system_fault_precision),
		.o_system_fault_run_generation(o_system_fault_run_generation),
		.o_system_fault_summary(o_system_fault_summary),
		.o_result_discard_summary_sticky(o_result_discard_summary_sticky)
	);

	//===================<时钟生成>===================//
	// 固定周期自由振荡时钟，行为级验证不追求真实2 MHz时序。
	always #(C_CLK_PERIOD / 2) i_clk = ~i_clk;

	//===================<仿真辅助任务>===================//
	// 真实条件比较后才允许打印对应SUP通过信息。
	task check_case;
		input [8 * 6 - 1:0]case_id;
		input condition;
		begin
			if(condition === 1'b1)begin
				cnt_pass = cnt_pass + 1;
				$display("PASS %s", case_id);
			end else begin
				cnt_fail = cnt_fail + 1;
				$display("FAIL %s at %0t", case_id, $time);
			end
		end
	endtask

	// 清空全部三路故障输入与生命周期输入到安全默认值。
	task drive_idle_inputs;
		begin
			i_ami_fault_valid = 1'b0;
			i_ami_fault_active = 1'b0;
			i_ami_fault_cause = 8'h00;
			i_ami_fault_identity_valid = 1'b0;
			i_ami_fault_frame_id = 16'h0000;
			i_ami_fault_sample_index = 16'h0000;
			i_ami_fault_color_ir = 1'b0;
			i_ami_fault_frame_type = 2'b00;
			i_ami_fault_precision = 1'b0;
			i_ami_fault_run_generation = 8'h00;
			i_scheduler_fault_valid = 1'b0;
			i_scheduler_fault_active = 1'b0;
			i_scheduler_fault_cause = 8'h00;
			i_scheduler_fault_identity_valid = 1'b0;
			i_scheduler_fault_frame_id = 16'h0000;
			i_scheduler_fault_sample_index = 16'h0000;
			i_scheduler_fault_color_ir = 1'b0;
			i_scheduler_fault_frame_type = 2'b00;
			i_scheduler_fault_precision = 1'b0;
			i_scheduler_fault_run_generation = 8'h00;
			i_ssw_fault_valid = 1'b0;
			i_ssw_fault_active = 1'b0;
			i_ssw_fault_cause = 8'h00;
			i_ssw_fault_identity_valid = 1'b0;
			i_ssw_fault_frame_id = 16'h0000;
			i_ssw_fault_sample_index = 16'h0000;
			i_ssw_fault_color_ir = 1'b0;
			i_ssw_fault_frame_type = 2'b00;
			i_ssw_fault_precision = 1'b0;
			i_ssw_fault_run_generation = 8'h00;
			i_stop_episode_active = 1'b0;
			i_adc_physical_idle = 1'b1;
			i_diag_clear_event = 1'b0;
			i_measurement_result_discard_event = 1'b0;
		end
	endtask

	// AMI单周期记录脉冲在下降沿建立，保证下一个上升沿被DUT唯一采样。
	task pulse_ami_fault;
		input [7:0]cause;
		input identity_valid;
		input [15:0]frame_id;
		input [15:0]sample_index;
		begin
			@(negedge i_clk);
			i_ami_fault_valid = 1'b1;
			i_ami_fault_cause = cause;
			i_ami_fault_identity_valid = identity_valid;
			i_ami_fault_frame_id = frame_id;
			i_ami_fault_sample_index = sample_index;
			i_ami_fault_color_ir = 1'b1;
			i_ami_fault_frame_type = 2'b10;
			i_ami_fault_precision = 1'b1;
			i_ami_fault_run_generation = 8'h05;
			@(negedge i_clk);
			i_ami_fault_valid = 1'b0;
		end
	endtask

	// Scheduler单周期记录脉冲，字段与AMI互不相同，便于区分快照来源。
	task pulse_scheduler_fault;
		input [7:0]cause;
		begin
			@(negedge i_clk);
			i_scheduler_fault_valid = 1'b1;
			i_scheduler_fault_cause = cause;
			i_scheduler_fault_identity_valid = 1'b1;
			i_scheduler_fault_frame_id = 16'hAAAA;
			i_scheduler_fault_sample_index = 16'hBBBB;
			@(negedge i_clk);
			i_scheduler_fault_valid = 1'b0;
		end
	endtask

	// SSW单周期记录脉冲，字段同样与AMI/Scheduler不同。
	task pulse_ssw_fault;
		input [7:0]cause;
		begin
			@(negedge i_clk);
			i_ssw_fault_valid = 1'b1;
			i_ssw_fault_cause = cause;
			i_ssw_fault_identity_valid = 1'b1;
			i_ssw_fault_frame_id = 16'hCCCC;
			i_ssw_fault_sample_index = 16'hDDDD;
			@(negedge i_clk);
			i_ssw_fault_valid = 1'b0;
		end
	endtask

	//===================<主测试流程>===================//
	initial begin
		i_clk = 1'b0;
		i_rstn = 1'b0;
		cnt_pass = 0;
		cnt_fail = 0;
		// WDPARM（ABCD F-014，TB本地名，标签宽6字符）：按层次读取实际例化的看门狗参数核对合法性CYCLES>=1且WIDTH>=$clog2(CYCLES+1)；
		// 本TB为加速仿真故意缩短阈值（8/4），产品固定值5000/13由控制顶层与芯片顶层TB核对
		check_case("WDPARM", (dut.C_ADC_DRAIN_WATCHDOG_CYCLES >= 1) && (dut.C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH >= $clog2(dut.C_ADC_DRAIN_WATCHDOG_CYCLES + 1)));
		drive_idle_inputs;
		repeat (3) @(negedge i_clk);
		i_rstn = 1'b1;
		@(negedge i_clk);

		// SUP-RESET：复位释放后全部输出必须处于安全默认值。
		check_case("SUPRST", (o_system_fault_blocking === 1'b0) &&
			(o_system_fault_cause_valid === 1'b0) &&
			(o_system_fault_summary === 16'h0000) &&
			(o_result_discard_summary_sticky === 1'b0) &&
			(o_system_abort_event === 1'b0) &&
			(o_system_stop_request_event === 1'b0) &&
			(o_system_fault_discard_event === 1'b0));

		// SUP-01：AMI cause 8'h01首次到达，episode开启，快照原子锁存，三事件各拉一拍。
		// pulse_ami_fault内部的第二个negedge紧跟在DUT采样valid的那个posedge之后，此刻检查才能看到事件脉冲仍为高。
		pulse_ami_fault(8'h01, 1'b1, 16'h1234, 16'h5678);
		check_case("SUP01A", (o_system_fault_blocking === 1'b1) &&
			(o_system_fault_cause_valid === 1'b1) &&
			(o_system_fault_cause === 8'h01) &&
			(o_system_fault_source === 4'h1) &&
			(o_system_fault_identity_valid === 1'b1) &&
			(o_system_fault_frame_id === 16'h1234) &&
			(o_system_fault_sample_index === 16'h5678) &&
			(o_system_abort_event === 1'b1) &&
			(o_system_stop_request_event === 1'b1) &&
			(o_system_fault_discard_event === 1'b1) &&
			(o_system_fault_summary[0] === 1'b1));
		i_ami_fault_active = 1'b1;
		@(negedge i_clk);
		check_case("SUP01B", (o_system_abort_event === 1'b0) &&
			(o_system_stop_request_event === 1'b0) &&
			(o_system_fault_discard_event === 1'b0) &&
			(o_system_fault_blocking === 1'b1));

		// SUP-02：episode仍开启期间SSW cause 8'h21到达，快照不得被覆盖，仅新增汇总位，且不重发三事件。
		pulse_ssw_fault(8'h21);
		i_ssw_fault_active = 1'b1;
		@(negedge i_clk);
		check_case("SUP02A", (o_system_fault_cause === 8'h01) &&
			(o_system_fault_source === 4'h1) &&
			(o_system_fault_frame_id === 16'h1234) &&
			(o_system_fault_summary[0] === 1'b1) &&
			(o_system_fault_summary[4] === 1'b1) &&
			(o_system_abort_event === 1'b0) &&
			(o_system_stop_request_event === 1'b0) &&
			(o_system_fault_discard_event === 1'b0));

		// SUP-03：episode仍开启期间诊断清除到达，不得产生任何效果。
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(negedge i_clk);
		i_diag_clear_event = 1'b0;
		@(negedge i_clk);
		check_case("CLRBLK", (o_system_fault_cause_valid === 1'b1) &&
			(o_system_fault_cause === 8'h01) &&
			(o_system_fault_blocking === 1'b1) &&
			(o_system_fault_summary[0] === 1'b1) &&
			(o_system_fault_summary[4] === 1'b1));

		// 撤销两路active，等待episode关闭判据在下一拍成立。
		i_ami_fault_active = 1'b0;
		i_ssw_fault_active = 1'b0;
		@(negedge i_clk);
		check_case("EPICLS", o_system_fault_blocking === 1'b0);

		// SUP-07：全部恢复后诊断清除生效，快照、汇总、丢弃sticky一并归零。
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(negedge i_clk);
		i_diag_clear_event = 1'b0;
		@(negedge i_clk);
		check_case("SUP07A", (o_system_fault_cause_valid === 1'b0) &&
			(o_system_fault_cause === 8'h00) &&
			(o_system_fault_source === 4'h0) &&
			(o_system_fault_identity_valid === 1'b0) &&
			(o_system_fault_frame_id === 16'h0000) &&
			(o_system_fault_summary === 16'h0000));

		// SUP-02b：同拍三路一起到达时，优先级AMI>Scheduler>SSW决定快照来源，三路各自汇总位仍全部置位。
		@(negedge i_clk);
		i_ami_fault_valid = 1'b1;
		i_ami_fault_cause = 8'h02;
		i_ami_fault_identity_valid = 1'b1;
		i_ami_fault_frame_id = 16'h9001;
		i_ami_fault_sample_index = 16'h9002;
		i_scheduler_fault_valid = 1'b1;
		i_scheduler_fault_cause = 8'h11;
		i_scheduler_fault_identity_valid = 1'b1;
		i_scheduler_fault_frame_id = 16'hAAAA;
		i_scheduler_fault_sample_index = 16'hBBBB;
		i_ssw_fault_valid = 1'b1;
		i_ssw_fault_cause = 8'h22;
		i_ssw_fault_identity_valid = 1'b1;
		i_ssw_fault_frame_id = 16'hCCCC;
		i_ssw_fault_sample_index = 16'hDDDD;
		i_ami_fault_active = 1'b1;
		i_scheduler_fault_active = 1'b1;
		i_ssw_fault_active = 1'b1;
		@(negedge i_clk);
		i_ami_fault_valid = 1'b0;
		i_scheduler_fault_valid = 1'b0;
		i_ssw_fault_valid = 1'b0;
		@(negedge i_clk);
		check_case("SUP02B", (o_system_fault_cause === 8'h02) &&
			(o_system_fault_source === 4'h1) &&
			(o_system_fault_frame_id === 16'h9001) &&
			(o_system_fault_summary[1] === 1'b1) &&
			(o_system_fault_summary[3] === 1'b1) &&
			(o_system_fault_summary[5] === 1'b1));

		// 恢复三路active并合法清除，回到全空闲基线，为看门狗测试腾出快照槽位。
		i_ami_fault_active = 1'b0;
		i_scheduler_fault_active = 1'b0;
		i_ssw_fault_active = 1'b0;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(negedge i_clk);
		i_diag_clear_event = 1'b0;
		@(negedge i_clk);

		// SUP-04：丢弃事件独立于阻断故障，只置位丢弃sticky，不产生阻断、不占用快照、不进汇总位图。
		i_measurement_result_discard_event = 1'b1;
		@(negedge i_clk);
		i_measurement_result_discard_event = 1'b0;
		@(negedge i_clk);
		check_case("SUP04A", (o_result_discard_summary_sticky === 1'b1) &&
			(o_system_fault_blocking === 1'b0) &&
			(o_system_fault_cause_valid === 1'b0) &&
			(o_system_fault_summary === 16'h0000));
		i_diag_clear_event = 1'b1;
		@(negedge i_clk);
		i_diag_clear_event = 1'b0;
		@(negedge i_clk);
		check_case("SUP04B", o_result_discard_summary_sticky === 1'b0);

		// SUP-06：看门狗在接受drain episode内连续非idle达到缩短阈值后超时，快照身份不可信、cause固定8'h31。
		i_stop_episode_active = 1'b1;
		i_adc_physical_idle = 1'b0;
		// 循环恰好等待到看门狗第C_WD_CYCLES个非idle采样的那个posedge，此刻立即检查才能看到事件脉冲仍为高。
		for (int_wait_index = 0; int_wait_index < C_WD_CYCLES; int_wait_index = int_wait_index + 1) begin
			@(negedge i_clk);
		end
		check_case("SUP06B", (o_system_fault_blocking === 1'b1) &&
			(o_system_fault_cause_valid === 1'b1) &&
			(o_system_fault_cause === 8'h31) &&
			(o_system_fault_source === 4'h4) &&
			(o_system_fault_identity_valid === 1'b0) &&
			(o_system_fault_frame_id === 16'h0000) &&
			(o_system_fault_summary[6] === 1'b1) &&
			(o_system_abort_event === 1'b1) &&
			(o_system_stop_request_event === 1'b1) &&
			(o_system_fault_discard_event === 1'b1));

		// 真实idle到达后watchdog轻量恢复，drain episode结束后episode关闭，验证不产生完成或idle伪造以外的副作用。
		// flag_watchdog_recovery_pending是寄存器：idle到达那一拍先采样，下一拍才对外表现为已恢复，因此这里多等一拍。
		i_adc_physical_idle = 1'b1;
		i_stop_episode_active = 1'b0;
		@(negedge i_clk);
		@(negedge i_clk);
		check_case("SUP06C", o_system_fault_blocking === 1'b0);
		i_diag_clear_event = 1'b1;
		@(negedge i_clk);
		i_diag_clear_event = 1'b0;
		@(negedge i_clk);

		// SUP-09：真实idle在阈值前到达时看门狗不得超时，计数器清零，不产生任何故障记录。
		i_stop_episode_active = 1'b1;
		i_adc_physical_idle = 1'b0;
		repeat (C_WD_CYCLES - 2) @(negedge i_clk);
		i_adc_physical_idle = 1'b1;
		repeat (4) @(negedge i_clk);
		check_case("WDIDLE", (o_system_fault_blocking === 1'b0) &&
			(o_system_fault_cause_valid === 1'b0) &&
			(o_system_fault_summary === 16'h0000));
		i_stop_episode_active = 1'b0;

		// SUP-10：验证第二个独立episode（此前episode均已完整关闭+诊断清除，非同一episode延续）依然
		// 完整触发abort/STOP/丢弃三事件并锁存全新快照——这是K02"episode开合独立于首故障快照历史，
		// 后续episode照样发一次完整trio"这条声明里此前只有RTL结构性阅读支持、从未被本文件任何真实
		// 仿真动态验证过的那一半，本次补齐。
		pulse_ami_fault(8'h03, 1'b1, 16'h4321, 16'h8765);
		check_case("EPI2ND", (o_system_fault_blocking === 1'b1) &&
			(o_system_fault_cause_valid === 1'b1) &&
			(o_system_fault_cause === 8'h03) &&
			(o_system_fault_source === 4'h1) &&
			(o_system_fault_frame_id === 16'h4321) &&
			(o_system_fault_sample_index === 16'h8765) &&
			(o_system_abort_event === 1'b1) &&
			(o_system_stop_request_event === 1'b1) &&
			(o_system_fault_discard_event === 1'b1));
		// RE-ARM（ABCD F-012，TB本地名，不沿用合同SUP族编号）：合同第4节要求episode关闭不清首故障快照，此后新的独立阻断记录
		// 即使首故障快照尚未收到诊断清除，也必须重新开一个episode并发出一次完整trio，且只置
		// 自己的汇总位、不覆盖保留的首故障cause/source/身份。SUP10A在诊断清除之后才重开，构不成
		// 这个前提；这里在SUP10A之后不清除历史，等episode真实关闭后再送Scheduler cause 0x11。
		int_wait_index = 0;
		while((o_system_fault_blocking !== 1'b0) && (int_wait_index < 20))begin
			@(negedge i_clk);
			int_wait_index = int_wait_index + 1;
		end
		pulse_scheduler_fault(8'h11);
		check_case("RE-ARM", (int_wait_index < 20) &&
			(o_system_fault_blocking === 1'b1) &&
			(o_system_abort_event === 1'b1) &&
			(o_system_stop_request_event === 1'b1) &&
			(o_system_fault_discard_event === 1'b1) &&
			(o_system_fault_cause_valid === 1'b1) &&
			(o_system_fault_cause === 8'h03) &&
			(o_system_fault_source === 4'h1) &&
			(o_system_fault_frame_id === 16'h4321) &&
			(o_system_fault_sample_index === 16'h8765) &&
			(o_system_fault_summary === 16'h000C));
		// 本次未持续拉高active，episode下一拍即满足关闭判据，等其真实关闭后再发诊断清除收尾。
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(negedge i_clk);
		i_diag_clear_event = 1'b0;
		@(negedge i_clk);

		// SUM-06 / SUM-07（owner生命周期轮，TB本地名，6字符）：AMI新原因码8'h06（同槽位连续完成丢失）与8'h07（ADC长期不回空闲）
		// 必须分别并入历史汇总bit 9与bit 10，并作为首故障原子快照，来源为AMI
		pulse_ami_fault(8'h06, 1'b1, 16'h0606, 16'h0660);
		@(negedge i_clk);
		check_case("SUM-06", (o_system_fault_cause === 8'h06) && (o_system_fault_source === 4'h1) &&
			(o_system_fault_sample_index === 16'h0660) && (o_system_fault_summary === 16'h0200));
		int_wait_index = 0;
		while((o_system_fault_blocking !== 1'b0) && (int_wait_index < 20))begin
			@(negedge i_clk);
			int_wait_index = int_wait_index + 1;
		end
		@(negedge i_clk); i_diag_clear_event = 1'b1;
		@(negedge i_clk); i_diag_clear_event = 1'b0;
		@(negedge i_clk);
		pulse_ami_fault(8'h07, 1'b1, 16'h0707, 16'h0770);
		@(negedge i_clk);
		check_case("SUM-07", (o_system_fault_cause === 8'h07) && (o_system_fault_source === 4'h1) &&
			(o_system_fault_sample_index === 16'h0770) && (o_system_fault_summary === 16'h0400));
		int_wait_index = 0;
		while((o_system_fault_blocking !== 1'b0) && (int_wait_index < 20))begin
			@(negedge i_clk);
			int_wait_index = int_wait_index + 1;
		end
		@(negedge i_clk); i_diag_clear_event = 1'b1;
		@(negedge i_clk); i_diag_clear_event = 1'b0;
		@(negedge i_clk);

		if(cnt_fail == 0 && cnt_pass == 18)begin
			$display("SUP-01/02/04/06/07 and TB-local supervisor checks PASS: %0d real comparisons", cnt_pass);
		end else begin
			$display("SUPERVISOR REGRESSION FAIL: pass=%0d fail=%0d", cnt_pass, cnt_fail);
		end
		$finish;
	end

	// 仿真watchdog确保任何握手死锁都以明确失败结束。
	initial begin
		#50000;
		$display("FAIL SUPERVISOR-WATCHDOG");
		$finish;
	end

endmodule
