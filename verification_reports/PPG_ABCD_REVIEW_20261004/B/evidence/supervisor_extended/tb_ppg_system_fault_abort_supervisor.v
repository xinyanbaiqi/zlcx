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
// Version:         V1.1
// Revision Date:   2026-09-28
// History:
// 2026-08-23           V1.0       Erie        Create file.
// 2026-09-28           V1.1       Erie        Add SUP10A: a second, independently-closed episode after SUP09A, asserting the full abort/STOP/discard trio and a fresh snapshot fire again -- closes a real dynamic-coverage gap for K02/N06's "later episode independent of first-fault history" claim, which previously had only static RTL-reading support and no simulation evidence.
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
// 当前版本:        V1.1
// 修订日期:        2026年09月28日
// 修订历史:
// 2026-08-23           V1.0       Erie        创建文件
// 2026-09-28           V1.1       Erie        新增SUP10A：在SUP09A之后、独立完整关闭一次episode后，再验证第二个episode依然完整触发abort/STOP/丢弃三事件并锁存全新快照——补齐K02/N06"后续episode独立于首故障历史"这条此前只有RTL静态阅读支持、从未被真实仿真动态验证过的缺口

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
  i_clk=0;i_rstn=0;cnt_pass=0;cnt_fail=0;drive_idle_inputs;
  repeat(3) @(negedge i_clk);i_rstn=1;@(negedge i_clk);
  pulse_ami_fault(8'h01,1'b1,16'h1234,16'h5678);
  check_case("BOPEN1", o_system_abort_event === 1'b1);
  @(negedge i_clk);
  check_case("BCLOSE",o_system_fault_blocking === 1'b0 && o_system_fault_cause_valid === 1'b1);
  pulse_ami_fault(8'h02,1'b1,16'h1111,16'h2222);
  check_case("BREARM",o_system_abort_event === 1'b1 && o_system_stop_request_event === 1'b1 && o_system_fault_discard_event === 1'b1 && o_system_fault_cause === 8'h01 && o_system_fault_frame_id === 16'h1234 && o_system_fault_summary === 16'h0003);
  @(negedge i_clk);i_diag_clear_event=1;
  @(negedge i_clk);i_diag_clear_event=0;
  @(negedge i_clk);
  i_ami_fault_valid=1;i_ami_fault_cause=8'h03;i_diag_clear_event=1;
  @(negedge i_clk);i_ami_fault_valid=0;i_diag_clear_event=0;
  check_case("BNEWCL",o_system_fault_cause_valid === 1'b1 && o_system_fault_cause === 8'h03 && o_system_abort_event === 1'b1 && o_system_fault_summary[2] === 1'b1);
  @(negedge i_clk);i_diag_clear_event=1;
  @(negedge i_clk);i_diag_clear_event=0;
  @(negedge i_clk);i_stop_episode_active=1;i_adc_physical_idle=0;
  repeat(C_WD_CYCLES-1) @(negedge i_clk);
  check_case("BWDN1",o_system_fault_cause_valid === 1'b0 && o_system_abort_event === 1'b0);
  i_adc_physical_idle=1;@(negedge i_clk);
  check_case("BWDIDL",o_system_fault_cause_valid === 1'b0 && o_system_abort_event === 1'b0);
  $display("B_SUPERVISOR comparisons=%0d failures=%0d",cnt_pass,cnt_fail);
  if(cnt_fail!=0)$fatal(1,"B_SUPERVISOR_FAIL");
  $finish;
 end
 initial begin #50000;$fatal(1,"B_SUPERVISOR_TIMEOUT");end
endmodule
