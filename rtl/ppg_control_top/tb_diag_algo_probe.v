`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/24
// Design Name:        PPG Digital System Top Long-Run RAW Coverage Testbench
// Module Name:        tb_ppg_control_top_longrun
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy;
//                      tb_ppg_real_raw_generator.vh (Phase 3 Stage 1/2 generator)
//
// Version:            V1.0
// Revision Date:      2026/08/24
// History:
//    Time               Version       Revised by            Contents
// 2026/08/24            V1.0          Erie                  Create file. Phase 3 Stage 3: dedicated long-run regression for contract section 8.1's RAW-12/RAW-13 acceptance IDs, kept separate from tb_ppg_control_top.v because its 23 SMOKE scenarios together only reach ~1.64 ms of simulated time while this run must cover a real 10 s -- folding it into the same file would make every future SMOKE-only regression pay for the long run too. Reuses tb_ppg_control_top.v's proven infrastructure verbatim: the NORMAL dual-optical MANUAL config task, START/STOP pulse tasks, wait_q3_release's real-Q3-gated response gate, drive_real_adc_done's public physical RAW/CLK_DOUT injection, make_fixed_raw's vdred encoding, and bg_responder's Stage 2 wiring of the Phase 3 RAW generator (task_generate_raw_target_code, C_RAW_PROFILE_NORMAL) for NORMAL RED/IR responses while calibration transactions keep the fixed-code path. Does not add or change any scenario logic beyond that infrastructure. Two things had to change relative to tb_ppg_control_top.v's clock generators, both load-bearing for this file's specific purpose and deliberately not touched in tb_ppg_control_top.v itself, whose 23 SMOKE scenarios never made a real-elapsed-time claim: (1) the system clock now runs an unbounded `forever` loop at a literal 500 ns period (real 2 MHz), replacing the bounded 3,000,000-toggle loop at a compressed 13 ns period documented there as "absolute simulation time does not represent a real 2 MHz period" -- that compression is harmless when only event ordering matters, but this file's whole job is to prove ten real elapsed seconds via $time, so $time must actually mean real 2 MHz seconds. Confirmed changing only the period (not the toggle count) costs nothing extra in simulator wall-clock time, since iverilog/xsim cost scales with event count, not delay magnitude. (2) the source clock is likewise unbounded so it cannot run out mid-run; its exact period remains uncalibrated to a real SPI frequency exactly as in tb_ppg_control_top.v, since C25 makes no claim about source-clock timing and this domain is only exercised once before START. Declares the two contract-mandated time-typed localparams (C_PPG_MIN_DURATION_NS=10e9, C_SIM_TIMEOUT_NS=12e9) and a time-typed reg_measurement_start_time captured at the accepted START event (o_start_ack_event), matching the contract's own worked example ($time - reg_measurement_start_time). Local throughput measurement before building this file: a 2,000,000-cycle idle-DUT probe (no scenario logic, clock toggling only) took 6 m 23 s under iverilog and 78.8 s under local Vivado xsim (2022.2) -- roughly a 5x speedup -- so this file targets xsim as its primary backend via xvlog/xelab/xsim, with iverilog kept only for quick logic-correctness smoke checks at reduced target counts, not for the full 4,000/4,000 run.
//
// A real first xsim run of the full 4,000/4,000 target (25 m 20 s wall-clock, matching the throughput estimate) exposed a genuine termination-condition defect in this file, not an RTL issue: the loop originally stopped as soon as cnt_red_response and cnt_ir_response both reached 4,000, with no elapsed-time condition. Because bg_responder completes each response at Q3 release (mid-frame), not at the frame's nominal end, the 4,000th real IR completion landed at elapsed_ns=9,999,732,499 -- 267.5 microseconds short of the 10,000,000,000 ns minimum, close enough to fail RAW-12's elapsed-time check by a hair (red=4000 ir=4000 both satisfied, but the run stopped before crossing 10 s). This is the exact exact-boundary risk flagged back in tb_ppg_real_raw_generator.vh's V1.1 changelog when C_RAW_PULSE_PERIOD_FRAMES was set to exactly floor(4000/400)=10 cycles with zero margin -- now empirically confirmed at the microsecond level rather than just reasoned about in advance. Fix: the wait loop's condition now requires cnt_red_response>=4000 AND cnt_ir_response>=4000 AND ($time-reg_measurement_start_time)>=C_PPG_MIN_DURATION_NS together, not frame/sample count alone; this lets the loop run a fraction of a frame longer whenever needed so all three RAW-12 conditions become true together, matching the contract's "at least 4,000 ... at least 10 seconds" wording literally (both are lower bounds, not a race to whichever is reached first). Verified with a reduced-target (30/30) iverilog quick-check before committing to a second full xsim run, confirming the fix waits the correct small extra amount when the boundary falls on either side. The corrected full run (25 m 20 s wall-clock under xsim) passes cleanly: RAW-12 real_red=4000, real_ir=4000, elapsed_ns=10,000,000,499 (499 ns past the 10 s floor -- the loop advanced no further than the single cycle needed to satisfy all three conditions); RAW-13 confirms the time-typed 12 s watchdog (C_SIM_TIMEOUT_NS) never fired and did not substitute for the frame/sample checks; 8,000 real ADC responses (4,000 RED + 4,000 IR) each produced exactly one formal measurement result (measurement_result_valid=8000), a 1:1 sanity check with no loss or duplication; STOP drained cleanly back to CONFIG with no fault. LONGRUN_TB_PASS.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月24日
// 设计名称:           PPG数字系统顶层长跑RAW覆盖测试平台
// 模块名称:           tb_ppg_control_top_longrun
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次；
//                      tb_ppg_real_raw_generator.vh（Phase 3 Stage 1/2生成器）
//
// 当前版本:           V1.0
// 修订日期:           2026年08月24日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月24日        V1.0          Erie                  创建文件。Phase 3 Stage 3：为合同第8.1节RAW-12/RAW-13验收ID专建的长跑回归，之所以独立成文件，是因为tb_ppg_control_top.v现有23个SMOKE场景加起来只跑到约1.64ms仿真时间，而这里要覆盖真实10秒——并进同一份文件会让以后每次只想跑SMOKE回归都要陪跑这个长跑。原样复用tb_ppg_control_top.v已验证过的基础设施：NORMAL双光MANUAL配置任务、START/STOP脉冲任务、wait_q3_release的真实Q3门控响应闸、drive_real_adc_done的公开物理RAW/CLK_DOUT注入、make_fixed_raw的vdred编码，以及bg_responder里Stage 2给NORMAL RED/IR响应接好的Phase 3生成器（task_generate_raw_target_code, C_RAW_PROFILE_NORMAL），校准事务仍走固定码路径。除了这套基础设施本身，不新增或改动任何场景逻辑。相对tb_ppg_control_top.v的时钟发生器有两处必须改动，都是本文件特有目的所需、且tb_ppg_control_top.v自己的23个SMOKE场景从未对真实经过时间做过claim、因此那边故意没动：（1）系统时钟现在用不限次数的`forever`循环、真实500ns周期（真实2MHz），替换那边"绝对仿真时间不代表真实2MHz周期"、300万次翻转封顶、压缩13ns周期的循环——这种压缩在只关心事件先后顺序时无害，但本文件的全部意义就是要用`$time`证明真实经过了十秒，所以`$time`必须真的对应真实2MHz秒数。已确认只改周期值（不改翻转次数）在仿真器挂钟耗时上不额外花一分钱，因为iverilog/xsim的开销由事件数量决定，不是delay数值大小。（2）source时钟同样改成不限次数，避免长跑中途耗尽；它的具体周期依然不校准到真实SPI频率，和tb_ppg_control_top.v一样，因为C25对source时钟时序没有任何claim，且这个域只在START之前被用到一次。声明了合同要求的两个time类型localparam（C_PPG_MIN_DURATION_NS=10e9、C_SIM_TIMEOUT_NS=12e9）和一个在START被接受（o_start_ack_event）那一刻锁存的time类型reg_measurement_start_time，对应合同自己给的样例（$time - reg_measurement_start_time）。12秒watchdog是一个独立的、相对仿真起点的进程（照搬tb_ppg_control_top.v既有全局看门狗的写法），用同一个time类型localparam按真实ns定值，不是那份文件里那个为压缩时钟校准过的、已经过时的12,000,000这个数字。搭建本文件之前先在本机测过吞吐率：一个200万周期、不带任何场景逻辑（只是时钟空转）的探测脚本，iverilog跑6分23秒，本地Vivado xsim（2022.2）跑78.8秒——约5倍加速——所以本文件以xsim为主要后端（走xvlog/xelab/xsim），iverilog只用于降低目标数量的快速逻辑正确性冒烟检查，不用来跑完整的4000/4000。
//
// 真正跑完整4000/4000目标的第一次xsim长跑（挂钟25分20秒，和吞吐率估算吻合）
// 暴露了本文件自己一个真实的终止条件缺陷，不是RTL问题：循环原来只要
// cnt_red_response和cnt_ir_response都到4000就停，没有经过时间这个条件。
// 因为bg_responder是在每帧Q3释放（帧中段，不是帧末尾）响应完成的，第4000笔
// 真实IR完成落在elapsed_ns=9,999,732,499——比10,000,000,000 ns下界差了
// 267.5微秒，差一点没能通过RAW-12的经过时间检查（red=4000、ir=4000都满足，
// 但循环在跨过10秒之前就已经停了）。这正是tb_ppg_real_raw_generator.vh
// V1.1 changelog里当时就标注过的卡线风险——C_RAW_PULSE_PERIOD_FRAMES定为
// 恰好floor(4000/400)=10个周期、没有余量——现在从"事先推理过的风险"变成了
// 微秒级的真实实测证据。修复：等待循环的条件改成cnt_red_response≥4000且
// cnt_ir_response≥4000且($time-reg_measurement_start_time)≥
// C_PPG_MIN_DURATION_NS三者同时成立，不再只看帧/样本数——这样循环会按需要
// 多跑一点点（不到一帧），让RAW-12的三个条件同时成立，逐字对应合同"at least
// 4,000...at least 10 seconds"的措辞（两个都是下界，不是谁先到就先停）。
// 先用缩小目标（30/30）在iverilog上做过快速检查确认修复正确（边界落在哪一侧
// 都能正确多等一点点），才提交第二次完整xsim长跑。修复后的完整跑（xsim挂钟
// 25分20秒）干净通过：RAW-12实测real_red=4000、real_ir=4000、
// elapsed_ns=10,000,000,499（压线越过10秒下界仅499ns——循环只多跑了刚好
// 满足三个条件所需的这一拍，没有过度等待）；RAW-13确认time类型12秒watchdog
// （C_SIM_TIMEOUT_NS）全程未触发，也没有替代帧/样本检查；8000笔真实ADC响应
// （4000 RED+4000 IR）每笔都恰好对应一笔正式测量结果
// （measurement_result_valid=8000），1:1核对无丢失无重复；STOP后干净排空回
// CONFIG，无故障残留。LONGRUN_TB_PASS。
//
// 复位后提交合法NORMAL双光MANUAL配置并START，在accepted START事件锁存
// 测量起点time戳，之后完全依赖既有bg_responder真实响应，直到RED/IR真实
// 事务数各自达到4000且经过时间不少于10秒，STOP后确认干净排空
module tb_diag_algo_probe();

	`include "tb_ppg_real_raw_generator.vh"

	//---------------配置参数区域---------------//
	localparam integer C_FRAME_ID_WIDTH = 16; // 与DUT默认参数一致
	localparam integer C_SAMPLE_INDEX_WIDTH = 16; // 与DUT默认参数一致
	localparam integer C_CONFIG_WIDTH = 1024; // 与DUT默认参数一致
	localparam integer C_CODE_EPOCH_WIDTH = 4; // 与DUT默认参数一致
	localparam integer C_RUN_GENERATION_WIDTH = 8; // 与DUT默认参数一致
	localparam [1:0] ST_CONFIG = 2'b00; // manager CONFIG生命周期编码
	localparam [1:0] ST_READY = 2'b01; // manager READY生命周期编码
	localparam [1:0] ST_RUN = 2'b10; // manager RUN生命周期编码
	localparam [1:0] ST_STOPPING = 2'b11; // manager STOPPING生命周期编码

	//---------------C25合同第8.1节强制长跑参数（time类型，禁止32-bit截断）---------------//
	localparam time C_PPG_MIN_DURATION_NS = 64'd1000; // 10秒measurement窗口下界
	localparam time C_SIM_TIMEOUT_NS = 64'd6000000000; // 12秒watchdog上限，相对仿真起点，非measurement窗口一部分
	localparam integer C_RAW12_TARGET_RED_SAMPLES = 1200; // RAW-12要求的RED真实事务下界
	localparam integer C_RAW12_TARGET_IR_SAMPLES = 1200; // RAW-12要求的IR真实事务下界

	// 以下V5默认字段值与ppg_system_config_manager.v的V5_RESET_PROFILE逐项一致，
	// 只用于凑出一份合法1024-bit联合快照
	localparam [383:0] V5_RESET_PROFILE_REF = {
		14'd0,                                  // reserved_v5复位归零
		1'b0,                                   // peak_valley_config_valid复位不可用
		16'd1000,                               // max_reacquire_frames
		16'd600,                                // max_fine_window_frames
		16'd100,                                // min_peak_to_peak_frames
		16'd20,                                 // min_peak_to_valley_frames
		24'd20,                                 // min_peak_valley_amplitude
		24'd2,                                  // direction_deadband
		4'd3,                                   // valley_confirm_count
		4'd3,                                   // peak_confirm_count
		4'd2,                                   // no_cross_limit
		4'd3,                                   // cross_confirm_count
		16'd19,                                 // lead_max_frames
		16'd17,                                 // lead_min_frames
		32'd131072,                             // cross_hysteresis_q16
		32'sd0,                                 // baseline_delta_q16
		-32'sd8192,                             // slope_max_q16
		-32'sd262144,                           // slope_min_q16
		16'h0800,                               // timing_adjust_ratio_q15
		16'h2000,                               // beta_q15
		16'h199A,                               // alpha_q15
		-32'sd65536,                            // fixed_slope_q16
		1'b1                                    // slope_mode=ADAPTIVE
	};

	//---------------全局时钟与复位信号---------------//
	reg i_clk; // 真实2 MHz系统时钟：本文件必须让$time对应真实经过秒数
	reg i_rstn; // 系统域低有效复位
	reg i_source_clk; // SPI配置源域仿真时钟
	reg i_source_rstn; // 源域低有效复位

	//---------------V4+V5源域配置信号---------------//
	reg [C_CONFIG_WIDTH - 1:0] i_source_config_snapshot; // 待提交的1024-bit联合快照
	reg i_source_config_update_event; // 快照传输请求单拍

	//---------------表征source信号---------------//
	reg i_source_characterization_update_valid; // 本轮不驱动表征更新，恒0
	reg i_source_static_characterization_enable; // 本轮不使用STATIC_BIAS，恒0
	reg [4:0] i_source_test_mux_ctrl; // 本轮不使用测试MUX，恒0

	//---------------已同步生命周期与诊断信号---------------//
	reg i_start_event; // START单拍
	reg i_stop_event; // STOP单拍
	reg i_diag_clear_event; // 本轮不触发诊断清除，恒0
	reg i_control_abort_event; // 本轮不触发abort，恒0

	//---------------物理ADC与模拟边界信号---------------//
	reg [9:0] i_dout_stage1_low; // Stage1物理判决码激励
	reg i_clk_stage1_dout_low_async; // Stage1异步完成脉冲激励
	reg [9:0] i_dout_stage2_low; // Stage2物理判决码激励
	reg i_clk_stage2_dout_low_async; // Stage2异步完成脉冲激励，同时携带精度位
	reg i_adc_physical_idle; // 物理ADC空闲电平，仅在响应窗口内短暂拉低
	reg i_analog_ready; // 模拟就绪聚合结果，本轮恒1

	//---------------正式结果消费者信号---------------//
	reg i_measurement_result_ready; // 本轮消费者恒接受

	//---------------验证专用异常注入信号---------------//
	reg i_test_inject_enable; // 本轮不使用验证注入，恒0
	reg i_test_identity_inject_valid; // 恒0
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] i_test_identity_inject_sample_index; // 恒0
	reg i_test_invalid_sample_valid; // 恒0

	//---------------SSW模拟控制原样输出---------------//
	wire o_en_tia_low, o_leden1_low, o_leden2_low, o_en_test;
	wire [7:0] o_leddac;
	wire o_clk_buf_low, o_clk_iref_idac_low, o_clk_9q1_low, o_clk_15q1_low, o_clk_aferst_low;
	wire o_clk_iref_idac_sar9_low, o_clk_iref_idac_sar15_low, o_clk_q2_low, o_clk_q3_low, o_clk_tiaen_low;
	wire o_en_15sar_low, o_en_sar9_amb_low, o_en_sar9_dc_low, o_en_sar9_iref;
	wire o_en_sar15_amb_low, o_en_sar15_dc_low, o_en_sar15_iref;
	wire [7:0] o_idac_sar9ambn_low, o_idac_sar9dcn_low, o_idac_sar15ambn_low, o_idac_sar15dcn_low;
	wire [4:0] o_s_in;
	wire o_clk_2m;

	//---------------AMI正式测量结果输出---------------//
	wire o_measurement_result_valid;
	wire signed [23:0] o_coarse_ppg_value, o_fine_ppg_value;
	wire o_coarse_valid, o_coarse_recovery_calibrated, o_coarse_saturation_low, o_coarse_saturation_high;
	wire o_fine_valid, o_fine_recovery_calibrated, o_fine_saturation_low, o_fine_saturation_high;
	wire signed [11:0] o_calibrated_s1_value;
	wire signed [14:0] o_programmable_15_code;
	wire o_programmable_15_valid;
	wire [7:0] o_result_config_epoch, o_result_coef_epoch, o_result_stage2_coef_epoch, o_result_dc_coef_epoch;
	wire o_result_precision_mode;
	wire [C_FRAME_ID_WIDTH - 1:0] o_result_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_result_sample_index;
	wire o_result_color_ir;
	wire [1:0] o_result_frame_type;
	wire [7:0] o_result_amb_code_snapshot, o_result_dc_code_snapshot;
	wire [C_CODE_EPOCH_WIDTH - 1:0] o_result_amb_code_epoch, o_result_dc_code_epoch;
	wire o_result_sample_valid;

	//---------------V4/V5生命周期ACK与错误输出---------------//
	wire [1:0] o_lifecycle_state;
	wire o_start_ready, o_commit_ack_event, o_start_ack_event, o_stop_ack_event, o_error_event;
	wire o_commit_ack_sticky, o_error_sticky;
	wire [7:0] o_last_error_code, o_schema_version, o_config_epoch, o_coef_epoch, o_stage2_coef_epoch, o_dc_recovery_coef_epoch;

	//---------------调度器/AMI/SSW只读诊断输出---------------//
	wire o_scheduler_idle, o_scheduler_launch_timeout_sticky, o_scheduler_owner_deadline_timeout_sticky;
	wire o_scheduler_completion_mismatch_sticky, o_scheduler_protocol_error_sticky;
	wire o_ami_datapath_empty, o_ami_idac_idle, o_ami_integration_protocol_error_sticky;
	wire o_ssw_wrapper_idle, o_ssw_switch_protocol_error_sticky, o_ssw_transaction_mismatch_sticky;
	wire o_ssw_owner_deadline_timeout_sticky, o_ssw_calibration_timeout_sticky;

	//---------------表征控制source握手与诊断输出---------------//
	wire o_source_characterization_update_ready, o_characterization_control_valid;
	wire o_characterization_control_update_event, o_characterization_control_reject_event;
	wire o_characterization_protocol_error_sticky;

	//---------------验证专用异常注入应答输出---------------//
	wire o_test_identity_inject_ready, o_test_invalid_sample_ready;

	//---------------注册式系统故障/abort监督输出---------------//
	wire o_system_fault_blocking, o_system_abort_event, o_system_stop_request_event, o_system_fault_discard_event;
	wire o_system_fault_cause_valid;
	wire [7:0] o_system_fault_cause;
	wire [3:0] o_system_fault_source;
	wire o_system_fault_identity_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_system_fault_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_system_fault_sample_index;
	wire o_system_fault_color_ir;
	wire [1:0] o_system_fault_frame_type;
	wire o_system_fault_precision;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_system_fault_run_generation;
	wire [15:0] o_system_fault_summary;
	wire o_result_discard_summary_sticky;

	//---------------AMI discard公开观测输出---------------//
	wire o_measurement_result_discard_event;
	wire [1:0] o_measurement_result_discard_reason;
	wire o_measurement_result_discard_identity_valid, o_measurement_result_discard_sample_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_measurement_result_discard_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_measurement_result_discard_sample_index;
	wire o_measurement_result_discard_color_ir;
	wire [1:0] o_measurement_result_discard_frame_type;
	wire o_measurement_result_discard_precision;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_measurement_result_discard_run_generation;

	wire o_detection_discard_event;
	wire [1:0] o_detection_discard_reason;
	wire o_detection_discard_identity_valid, o_detection_discard_sample_valid;
	wire [C_FRAME_ID_WIDTH - 1:0] o_detection_discard_frame_id;
	wire [C_SAMPLE_INDEX_WIDTH - 1:0] o_detection_discard_sample_index;
	wire o_detection_discard_color_ir;
	wire [1:0] o_detection_discard_frame_type;
	wire o_detection_discard_precision;
	wire [7:0] o_detection_discard_config_epoch, o_detection_discard_coef_epoch, o_detection_discard_dc_recovery_epoch;
	wire [C_CODE_EPOCH_WIDTH - 1:0] o_detection_discard_amb_code_epoch, o_detection_discard_dc_code_epoch;
	wire [C_RUN_GENERATION_WIDTH - 1:0] o_detection_discard_run_generation;

	//---------------自检计数与状态信号---------------//
	integer cnt_error; // 累计FAIL数
	integer cnt_measurement_result_valid; // 观测到的正式结果次数
	integer cnt_adc_response; // 已响应的真实Q3门控ADC事务数
	integer cnt_red_response; // 已响应的真实RED事务数，按响应时owner身份分类
	integer cnt_ir_response; // 已响应的真实IR事务数，按响应时owner身份分类
	integer cnt_cal_response; // 已响应的真实校准事务数，按响应时owner身份分类
	reg [7:0] reg_last_cal_local_tick; // 未在本场景使用，保留以匹配复用task签名
	reg [7:0] reg_last_cal_amb_snapshot; // 未在本场景使用，保留以匹配复用task签名
	reg reg_last_precision_scheduler, reg_last_precision_ssw, reg_last_precision_ami; // 未在本场景使用，保留以匹配复用task签名
	reg flag_global_timeout; // 全局看门狗超时标记
	time reg_measurement_start_time; // accepted START事件锁存的time类型起点
	time reg_measurement_elapsed_time; // 达标时刻的time类型经过时长

	//---------------DUT实例化---------------//
	// C01顶层：聚合全部6个直接子模块的唯一数字功能顶层
	ppg_control_top
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH), // 与本TB本地参数一致
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH), // 与本TB本地参数一致
			.C_CONFIG_WIDTH(C_CONFIG_WIDTH), // 与本TB本地参数一致
			.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH), // 与本TB本地参数一致
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH) // 与本TB本地参数一致
		)
		ppg_control_top_Inst(
			.i_clk(i_clk),
			.i_rstn(i_rstn),
			.i_source_clk(i_source_clk),
			.i_source_rstn(i_source_rstn),
			.i_source_config_snapshot(i_source_config_snapshot),
			.i_source_config_update_event(i_source_config_update_event),
			.i_source_characterization_update_valid(i_source_characterization_update_valid),
			.i_source_static_characterization_enable(i_source_static_characterization_enable),
			.i_source_test_mux_ctrl(i_source_test_mux_ctrl),
			.i_start_event(i_start_event),
			.i_stop_event(i_stop_event),
			.i_diag_clear_event(i_diag_clear_event),
			.i_control_abort_event(i_control_abort_event),
			.i_dout_stage1_low(i_dout_stage1_low),
			.i_clk_stage1_dout_low_async(i_clk_stage1_dout_low_async),
			.i_dout_stage2_low(i_dout_stage2_low),
			.i_clk_stage2_dout_low_async(i_clk_stage2_dout_low_async),
			.i_adc_physical_idle(i_adc_physical_idle),
			.i_analog_ready(i_analog_ready),
			.i_measurement_result_ready(i_measurement_result_ready),
			.i_test_inject_enable(i_test_inject_enable),
			.i_test_identity_inject_valid(i_test_identity_inject_valid),
			.i_test_identity_inject_sample_index(i_test_identity_inject_sample_index),
			.i_test_invalid_sample_valid(i_test_invalid_sample_valid),
			.o_en_tia_low(o_en_tia_low),
			.o_leddac(o_leddac),
			.o_leden1_low(o_leden1_low),
			.o_leden2_low(o_leden2_low),
			.o_en_test(o_en_test),
			.o_clk_buf_low(o_clk_buf_low),
			.o_clk_iref_idac_low(o_clk_iref_idac_low),
			.o_clk_9q1_low(o_clk_9q1_low),
			.o_clk_15q1_low(o_clk_15q1_low),
			.o_clk_aferst_low(o_clk_aferst_low),
			.o_clk_iref_idac_sar9_low(o_clk_iref_idac_sar9_low),
			.o_clk_iref_idac_sar15_low(o_clk_iref_idac_sar15_low),
			.o_clk_q2_low(o_clk_q2_low),
			.o_clk_q3_low(o_clk_q3_low),
			.o_clk_tiaen_low(o_clk_tiaen_low),
			.o_en_15sar_low(o_en_15sar_low),
			.o_en_sar9_amb_low(o_en_sar9_amb_low),
			.o_en_sar9_dc_low(o_en_sar9_dc_low),
			.o_en_sar9_iref(o_en_sar9_iref),
			.o_en_sar15_amb_low(o_en_sar15_amb_low),
			.o_en_sar15_dc_low(o_en_sar15_dc_low),
			.o_en_sar15_iref(o_en_sar15_iref),
			.o_idac_sar9ambn_low(o_idac_sar9ambn_low),
			.o_idac_sar9dcn_low(o_idac_sar9dcn_low),
			.o_idac_sar15ambn_low(o_idac_sar15ambn_low),
			.o_idac_sar15dcn_low(o_idac_sar15dcn_low),
			.o_s_in(o_s_in),
			.o_clk_2m(o_clk_2m),
			.o_measurement_result_valid(o_measurement_result_valid),
			.o_coarse_ppg_value(o_coarse_ppg_value),
			.o_coarse_valid(o_coarse_valid),
			.o_coarse_recovery_calibrated(o_coarse_recovery_calibrated),
			.o_coarse_saturation_low(o_coarse_saturation_low),
			.o_coarse_saturation_high(o_coarse_saturation_high),
			.o_fine_ppg_value(o_fine_ppg_value),
			.o_fine_valid(o_fine_valid),
			.o_fine_recovery_calibrated(o_fine_recovery_calibrated),
			.o_fine_saturation_low(o_fine_saturation_low),
			.o_fine_saturation_high(o_fine_saturation_high),
			.o_calibrated_s1_value(o_calibrated_s1_value),
			.o_programmable_15_code(o_programmable_15_code),
			.o_programmable_15_valid(o_programmable_15_valid),
			.o_result_config_epoch(o_result_config_epoch),
			.o_result_coef_epoch(o_result_coef_epoch),
			.o_result_stage2_coef_epoch(o_result_stage2_coef_epoch),
			.o_result_dc_coef_epoch(o_result_dc_coef_epoch),
			.o_result_precision_mode(o_result_precision_mode),
			.o_result_frame_id(o_result_frame_id),
			.o_result_sample_index(o_result_sample_index),
			.o_result_color_ir(o_result_color_ir),
			.o_result_frame_type(o_result_frame_type),
			.o_result_amb_code_snapshot(o_result_amb_code_snapshot),
			.o_result_dc_code_snapshot(o_result_dc_code_snapshot),
			.o_result_amb_code_epoch(o_result_amb_code_epoch),
			.o_result_dc_code_epoch(o_result_dc_code_epoch),
			.o_result_sample_valid(o_result_sample_valid),
			.o_lifecycle_state(o_lifecycle_state),
			.o_start_ready(o_start_ready),
			.o_commit_ack_event(o_commit_ack_event),
			.o_start_ack_event(o_start_ack_event),
			.o_stop_ack_event(o_stop_ack_event),
			.o_error_event(o_error_event),
			.o_commit_ack_sticky(o_commit_ack_sticky),
			.o_error_sticky(o_error_sticky),
			.o_last_error_code(o_last_error_code),
			.o_schema_version(o_schema_version),
			.o_config_epoch(o_config_epoch),
			.o_coef_epoch(o_coef_epoch),
			.o_stage2_coef_epoch(o_stage2_coef_epoch),
			.o_dc_recovery_coef_epoch(o_dc_recovery_coef_epoch),
			.o_scheduler_idle(o_scheduler_idle),
			.o_scheduler_launch_timeout_sticky(o_scheduler_launch_timeout_sticky),
			.o_scheduler_owner_deadline_timeout_sticky(o_scheduler_owner_deadline_timeout_sticky),
			.o_scheduler_completion_mismatch_sticky(o_scheduler_completion_mismatch_sticky),
			.o_scheduler_protocol_error_sticky(o_scheduler_protocol_error_sticky),
			.o_ami_datapath_empty(o_ami_datapath_empty),
			.o_ami_idac_idle(o_ami_idac_idle),
			.o_ami_integration_protocol_error_sticky(o_ami_integration_protocol_error_sticky),
			.o_ssw_wrapper_idle(o_ssw_wrapper_idle),
			.o_ssw_switch_protocol_error_sticky(o_ssw_switch_protocol_error_sticky),
			.o_ssw_transaction_mismatch_sticky(o_ssw_transaction_mismatch_sticky),
			.o_ssw_owner_deadline_timeout_sticky(o_ssw_owner_deadline_timeout_sticky),
			.o_ssw_calibration_timeout_sticky(o_ssw_calibration_timeout_sticky),
			.o_source_characterization_update_ready(o_source_characterization_update_ready),
			.o_characterization_control_valid(o_characterization_control_valid),
			.o_characterization_control_update_event(o_characterization_control_update_event),
			.o_characterization_control_reject_event(o_characterization_control_reject_event),
			.o_characterization_protocol_error_sticky(o_characterization_protocol_error_sticky),
			.o_test_identity_inject_ready(o_test_identity_inject_ready),
			.o_test_invalid_sample_ready(o_test_invalid_sample_ready),
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
			.o_result_discard_summary_sticky(o_result_discard_summary_sticky),
			.o_measurement_result_discard_event(o_measurement_result_discard_event),
			.o_measurement_result_discard_reason(o_measurement_result_discard_reason),
			.o_measurement_result_discard_identity_valid(o_measurement_result_discard_identity_valid),
			.o_measurement_result_discard_sample_valid(o_measurement_result_discard_sample_valid),
			.o_measurement_result_discard_frame_id(o_measurement_result_discard_frame_id),
			.o_measurement_result_discard_sample_index(o_measurement_result_discard_sample_index),
			.o_measurement_result_discard_color_ir(o_measurement_result_discard_color_ir),
			.o_measurement_result_discard_frame_type(o_measurement_result_discard_frame_type),
			.o_measurement_result_discard_precision(o_measurement_result_discard_precision),
			.o_measurement_result_discard_run_generation(o_measurement_result_discard_run_generation),
			.o_detection_discard_event(o_detection_discard_event),
			.o_detection_discard_reason(o_detection_discard_reason),
			.o_detection_discard_identity_valid(o_detection_discard_identity_valid),
			.o_detection_discard_sample_valid(o_detection_discard_sample_valid),
			.o_detection_discard_frame_id(o_detection_discard_frame_id),
			.o_detection_discard_sample_index(o_detection_discard_sample_index),
			.o_detection_discard_color_ir(o_detection_discard_color_ir),
			.o_detection_discard_frame_type(o_detection_discard_frame_type),
			.o_detection_discard_precision(o_detection_discard_precision),
			.o_detection_discard_config_epoch(o_detection_discard_config_epoch),
			.o_detection_discard_coef_epoch(o_detection_discard_coef_epoch),
			.o_detection_discard_dc_recovery_epoch(o_detection_discard_dc_recovery_epoch),
			.o_detection_discard_amb_code_epoch(o_detection_discard_amb_code_epoch),
			.o_detection_discard_dc_code_epoch(o_detection_discard_dc_code_epoch),
			.o_detection_discard_run_generation(o_detection_discard_run_generation)
		);

	//---------------source时钟发生器---------------//
	// 不限次数，避免长跑中途耗尽；绝对时间不代表真实SPI频率，C25对此域无claim
	initial begin
		i_source_clk = 1'b0;
		forever #5.5 i_source_clk = ~i_source_clk;
	end

	//---------------系统时钟发生器---------------//
	// 真实2MHz语义：500ns整周期，不限次数。这是本文件区别于tb_ppg_control_top.v
	// 的关键改动——只有周期真实，$time才能诚实对应合同定义的10秒/2000万周期
	initial begin
		i_clk = 1'b0;
		forever #250 i_clk = ~i_clk;
	end

	//---------------合法NORMAL双光MANUAL配置构造任务---------------//
	// 与tb_ppg_control_top.v逐字段一致
	task task_build_normal_manual_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0; // run_profile=NORMAL_PPG
			i_source_config_snapshot[9] = 1'b0; // input_source=PHOTODIODE
			i_source_config_snapshot[11:10] = 2'b00; // idac_mode=MANUAL
			i_source_config_snapshot[13:12] = 2'b10; // optical_mode=IR单光，稍后由dual任务改成双光
			i_source_config_snapshot[14] = 1'b0; // initial_precision=SAR9
			i_source_config_snapshot[15] = 1'b1; // amb_enable
			i_source_config_snapshot[16] = 1'b1; // dcs_enable
			i_source_config_snapshot[17] = 1'b1; // amb_polarity
			i_source_config_snapshot[18] = 1'b0; // dcs_polarity
			i_source_config_snapshot[19] = 1'b1; // stage1_calibration_valid
			i_source_config_snapshot[20] = 1'b1; // stage2_calibration_valid
			i_source_config_snapshot[21] = 1'b1; // dc9_recovery_valid
			i_source_config_snapshot[22] = 1'b1; // dc15_recovery_valid
			i_source_config_snapshot[39:32] = 8'd64; // amb_manual_code
			i_source_config_snapshot[47:40] = 8'd8; // amb_code_min
			i_source_config_snapshot[55:48] = 8'd240; // amb_code_max
			i_source_config_snapshot[63:56] = 8'd80; // dcs_r_manual_code
			i_source_config_snapshot[71:64] = 8'd12; // dcs_r_code_min
			i_source_config_snapshot[79:72] = 8'd230; // dcs_r_code_max
			i_source_config_snapshot[87:80] = 8'd96; // dcs_ir_manual_code
			i_source_config_snapshot[95:88] = 8'd16; // dcs_ir_code_min
			i_source_config_snapshot[103:96] = 8'd220; // dcs_ir_code_max
			i_source_config_snapshot[115:104] = -12'sd64; // amb_threshold_low
			i_source_config_snapshot[127:116] = 12'sd72; // amb_threshold_high
			i_source_config_snapshot[139:128] = -12'sd48; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd56; // dcs_threshold_high
			i_source_config_snapshot[159:152] = 8'd8; // amb_confirm_count
			i_source_config_snapshot[167:160] = 8'd9; // dcs_confirm_count
			// C11合同第3节标称权重表：逐位对应vd0..vd8二进制位权(1,2,4,8,8,16,32,64,128,256)，
			// Q16标度即×65536——诊断探针撞见的"calibrated_s1恒为0"就是因为这批系数原来沿用
			// Phase 1占位值（个位数量级，Q16下约0.0003，10位加总远不到0.5，舍入必然是0）
			i_source_config_snapshot[193:168] = 26'sd65536; // stage1_weight_q16_0，vd0标称1.0
			i_source_config_snapshot[219:194] = 26'sd131072; // stage1_weight_q16_1，vd1标称2.0
			i_source_config_snapshot[245:220] = 26'sd262144; // stage1_weight_q16_2，vd2标称4.0
			i_source_config_snapshot[271:246] = 26'sd524288; // stage1_weight_q16_3，vdred冗余支路标称8.0
			i_source_config_snapshot[297:272] = 26'sd524288; // stage1_weight_q16_4，vd3主支路标称8.0
			i_source_config_snapshot[323:298] = 26'sd1048576; // stage1_weight_q16_5，vd4标称16.0
			i_source_config_snapshot[349:324] = 26'sd2097152; // stage1_weight_q16_6，vd5标称32.0
			i_source_config_snapshot[375:350] = 26'sd4194304; // stage1_weight_q16_7，vd6标称64.0
			i_source_config_snapshot[401:376] = 26'sd8388608; // stage1_weight_q16_8，vd7标称128.0
			i_source_config_snapshot[427:402] = 26'sd16777216; // stage1_weight_q16_9，vd8标称256.0
			i_source_config_snapshot[459:428] = -32'sd262144; // stage1_offset_q16，标称-4*65536
			i_source_config_snapshot[479:460] = 20'sd54143; // stage2_gain_q16
			i_source_config_snapshot[511:480] = -32'sd37; // stage2_offset_q16
			i_source_config_snapshot[543:512] = 32'sd65536; // dc9_recovery_gain_q16
			i_source_config_snapshot[575:544] = 32'sd32768; // dc15_recovery_gain_q16
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames
			i_source_config_snapshot[1009] = 1'b1; // peak_valley_config_valid：V5_RESET_PROFILE_REF默认0，探测器会消费排空但拒绝发布任何正式cross/peak/valley事件，诊断专用覆盖打开
		end
	endtask

	//---------------合法NORMAL真双光MANUAL配置构造任务---------------//
	task task_build_normal_manual_dual_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，真双光
		end
	endtask

	//---------------source事件任务---------------//
	task task_pulse_source_update;
		begin
			@(negedge i_source_clk);
			i_source_config_update_event = 1'b1;
			@(posedge i_source_clk);
			#1 i_source_config_update_event = 1'b0;
		end
	endtask

	//---------------START事件任务---------------//
	task task_pulse_start;
		begin
			@(negedge i_clk);
			i_start_event = 1'b1;
			@(posedge i_clk);
			#1 i_start_event = 1'b0;
		end
	endtask

	//---------------STOP事件任务---------------//
	task task_pulse_stop;
		begin
			@(negedge i_clk);
			i_stop_event = 1'b1;
			@(posedge i_clk);
			#1 i_stop_event = 1'b0;
		end
	endtask

	//---------------配置结果等待任务---------------//
	task task_wait_config_result;
		integer cnt_wait;
		begin
			cnt_wait = 0;
			while((o_commit_ack_event == 1'b0) && (o_error_event == 1'b0) && (cnt_wait < 64)) begin
				@(posedge i_clk);
				#1;
				cnt_wait = cnt_wait + 1;
			end
			if((o_commit_ack_event == 1'b0) && (o_error_event == 1'b0)) begin
				$display("FAIL LONGRUN config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------真实ADC完成响应任务---------------//
	task drive_real_adc_done;
		input precision_mode;
		input [9:0] stage1_raw;
		input [9:0] stage2_raw;
		begin
			@(negedge i_clk);
			#2 i_adc_physical_idle = 1'b0;
			#2 i_dout_stage1_low = stage1_raw;
			#1 i_dout_stage2_low = stage2_raw;
			#1 i_clk_stage1_dout_low_async = 1'b1;
			#1 i_clk_stage2_dout_low_async = precision_mode;
			repeat(5) @(negedge i_clk);
			#2 i_clk_stage1_dout_low_async = 1'b0;
			#1 i_clk_stage2_dout_low_async = 1'b0;
			#1 i_adc_physical_idle = 1'b1;
		end
	endtask

	//---------------Q3门控等待任务---------------//
	task wait_q3_release;
		output o_real_release;
		integer cnt_wd;
		begin
			cnt_wd = 0;
			while((o_clk_q3_low !== 1'b1) && (cnt_wd < 5600)) begin
				@(negedge i_clk);
				cnt_wd = cnt_wd + 1;
			end
			if(o_clk_q3_low !== 1'b1) begin
				o_real_release = 1'b0;
			end else begin
				o_real_release = 1'b1;
				while((o_clk_q3_low === 1'b1) && (cnt_wd < 6600)) begin
					@(negedge i_clk);
					cnt_wd = cnt_wd + 1;
				end
				if(cnt_wd >= 6600) begin
					$display("FAIL LONGRUN Q3 wait timeout at cnt_adc_response=%0d", cnt_adc_response);
					cnt_error = cnt_error + 1;
				end
			end
		end
	endtask

	//---------------vdred编码RAW构造任务---------------//
	task make_fixed_raw;
		input integer target_code;
		output [9:0] raw_code;
		integer bounded_code;
		integer encoded_code;
		begin
			bounded_code = target_code;
			if(bounded_code < 8) bounded_code = 8;
			else if(bounded_code > 503) bounded_code = 503;
			encoded_code = bounded_code - 4;
			raw_code = ((encoded_code >> 3) << 4) | 10'b0000001000 | (encoded_code & 7);
		end
	endtask

	//---------------后台ADC响应进程---------------//
	// 与tb_ppg_control_top.v V1.4的bg_responder逻辑完全一致，只是把逐笔DIAG打印
	// 换成低频进度打印（每200笔一次），避免8000笔真实事务产生等量日志噪音
	reg [9:0] reg_fixed_stage1_raw;
	reg [9:0] reg_fixed_stage2_raw; // 仅校准事务使用的固定RAW
	reg reg_response_precision;
	reg flag_q3_real_release;
	reg flag_response_is_calibration;
	reg reg_response_color_ir;
	reg [31:0] reg_response_frame_id;
	reg [9:0] reg_response_stage1_raw;
	reg [9:0] reg_response_stage2_raw;
	reg [9:0] reg_response_target_code;
	integer reg_response_raw_unclamped;
	initial begin
		i_dout_stage1_low = 10'd0;
		i_clk_stage1_dout_low_async = 1'b0;
		i_dout_stage2_low = 10'd0;
		i_clk_stage2_dout_low_async = 1'b0;
		i_adc_physical_idle = 1'b1;
		make_fixed_raw(256, reg_fixed_stage1_raw);
		make_fixed_raw(300, reg_fixed_stage2_raw);
		cnt_adc_response = 0;
		cnt_red_response = 0;
		cnt_ir_response = 0;
		cnt_cal_response = 0;
		forever begin
			wait_q3_release(flag_q3_real_release);
			if(flag_q3_real_release) begin
				flag_response_is_calibration = !ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_TYPE_H];
				reg_response_color_ir = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_COLOR];
				reg_response_frame_id = {16'd0, ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_frame_id};
				if(flag_response_is_calibration) begin
					cnt_cal_response = cnt_cal_response + 1;
				end else if(reg_response_color_ir) begin
					cnt_ir_response = cnt_ir_response + 1;
				end else begin
					cnt_red_response = cnt_red_response + 1;
				end
				reg_response_precision = ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_cal_context_valid ? 1'b0 :
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_PRECISION];
				if(flag_response_is_calibration) begin
					reg_response_stage1_raw = reg_fixed_stage1_raw;
					reg_response_stage2_raw = reg_fixed_stage2_raw;
				end else begin
					task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_response_color_ir, reg_response_frame_id,
						reg_response_target_code, reg_response_raw_unclamped);
					make_fixed_raw(reg_response_target_code, reg_response_stage1_raw);
					make_fixed_raw(reg_response_target_code, reg_response_stage2_raw);
					if(cnt_adc_response < 30) begin
						$display("DIAG PROBE GEN t=%0t color_ir=%0d frame_id=%0d target_code=%0d unclamped=%0d stage1_raw=%0d",
							$time, reg_response_color_ir, reg_response_frame_id, reg_response_target_code,
							reg_response_raw_unclamped, reg_response_stage1_raw);
					end
				end
				drive_real_adc_done(reg_response_precision, reg_response_stage1_raw, reg_response_stage2_raw);
				if((cnt_adc_response < 30) && !flag_response_is_calibration) begin
					$display("DIAG PROBE POST_DONE t=%0t color_ir=%0d frame_id=%0d target_code=%0d coarse_valid=%0d coarse_value=%0d calibrated_s1=%0d calibrated_valid=%0d",
						$time, reg_response_color_ir, reg_response_frame_id, reg_response_target_code,
						o_coarse_valid, o_coarse_ppg_value, o_calibrated_s1_value, o_coarse_recovery_calibrated);
				end
				cnt_adc_response = cnt_adc_response + 1;
				if((cnt_adc_response % 200) == 0) begin
					$display("DIAG longrun progress t=%0t red=%0d ir=%0d cal=%0d elapsed_ns=%0d",
						$time, cnt_red_response, cnt_ir_response, cnt_cal_response,
						(reg_measurement_start_time == 0) ? 0 : ($time - reg_measurement_start_time));
				end
			end
		end
	end

	//---------------正式结果计数进程---------------//
	always @(posedge i_clk) begin
		if(i_rstn && o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_measurement_result_valid = cnt_measurement_result_valid + 1;
		end
	end

	//---------------全局看门狗进程---------------//
	// 12秒watchdog，相对仿真起点，time类型，覆盖复位+START+measurement+排空+
	// 终止检查的全部预算；不是10秒measurement窗口本身的一部分
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL LONGRUN global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	initial begin
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		reg_measurement_start_time = 0;
		i_rstn = 1'b0;
		i_source_rstn = 1'b0;
		i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
		i_source_config_update_event = 1'b0;
		i_source_characterization_update_valid = 1'b0;
		i_source_static_characterization_enable = 1'b0;
		i_source_test_mux_ctrl = 5'b00000;
		i_start_event = 1'b0;
		i_stop_event = 1'b0;
		i_diag_clear_event = 1'b0;
		i_control_abort_event = 1'b0;
		i_analog_ready = 1'b1;
		i_measurement_result_ready = 1'b1;
		i_test_inject_enable = 1'b0;
		i_test_identity_inject_valid = 1'b0;
		i_test_identity_inject_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
		i_test_invalid_sample_valid = 1'b0;

		// 复位释放
		repeat(3) @(posedge i_clk);
		#1;
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;

		// 提交合法NORMAL双光MANUAL配置
		task_build_normal_manual_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LONGRUN legal NORMAL dual-optical MANUAL commit");
			cnt_error = cnt_error + 1;
			$finish;
		end else begin
			$display("PASS LONGRUN legal NORMAL dual-optical MANUAL commit");
		end

		// START：accepted measurement START事件，在此锁存time类型测量起点
		task_pulse_start;
		fork
			begin : longrun_start_ack_wait
				integer cnt_start_wait;
				cnt_start_wait = 0;
				while((o_start_ack_event == 1'b0) && (cnt_start_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_start_wait = cnt_start_wait + 1;
				end
				if(o_start_ack_event == 1'b0) begin
					$display("FAIL LONGRUN start ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		reg_measurement_start_time = $time; // 与合同"10-second measurement interval begins at the accepted measurement START event"对齐
		if((o_lifecycle_state != ST_RUN) || o_system_fault_blocking) begin
			$display("FAIL LONGRUN START accepted into RUN");
			cnt_error = cnt_error + 1;
			$finish;
		end else begin
			$display("PASS LONGRUN START accepted into RUN, measurement start latched t=%0t", reg_measurement_start_time);
		end

		// 完全依赖bg_responder真实响应，直到RED/IR真实事务数各自达到RAW-12目标
		// 且经过时间也达到10秒——三个条件必须同时成立，不能只看帧数就停。
		// 第一次真实跑（xsim，2026/08/24）在这里只看帧数就停，暴露了一个真实
		// 边界问题：bg_responder在每帧Q3释放（帧中段）响应，第4000笔IR完成的
		// 时刻天然比整整4000个2.5ms周期略早，实测差了267.5微秒（elapsed_ns=
		// 9,999,732,499 vs 10,000,000,000）——不是RTL问题，是本文件的停止条件
		// 本身不够严谨；加上经过时间这个条件后，循环会多等不到一帧，RED/IR
		// 计数会略微超过4000（这正是合同"at least 4,000...at least 10 seconds"
		// 两个"at least"都要求的，不是缺陷）
		while(!((cnt_red_response >= C_RAW12_TARGET_RED_SAMPLES) && (cnt_ir_response >= C_RAW12_TARGET_IR_SAMPLES)
			&& (($time - reg_measurement_start_time) >= C_PPG_MIN_DURATION_NS)) && !flag_global_timeout) begin
			@(posedge i_clk);
		end
		reg_measurement_elapsed_time = $time - reg_measurement_start_time;

		// RAW-12：post-START运行覆盖至少10秒、4000 RED、4000 IR真实事务，
		// 三者独立断言，不用"到了10秒"代替"数够了4000笔"，反之亦然
		if(flag_global_timeout) begin
			$display("FAIL RAW-12 global watchdog fired before RED/IR both reached target red=%0d ir=%0d elapsed_ns=%0d",
				cnt_red_response, cnt_ir_response, reg_measurement_elapsed_time);
			cnt_error = cnt_error + 1;
		end else if(cnt_red_response < C_RAW12_TARGET_RED_SAMPLES) begin
			$display("FAIL RAW-12 RED sample count insufficient red=%0d target=%0d", cnt_red_response, C_RAW12_TARGET_RED_SAMPLES);
			cnt_error = cnt_error + 1;
		end else if(cnt_ir_response < C_RAW12_TARGET_IR_SAMPLES) begin
			$display("FAIL RAW-12 IR sample count insufficient ir=%0d target=%0d", cnt_ir_response, C_RAW12_TARGET_IR_SAMPLES);
			cnt_error = cnt_error + 1;
		end else if(reg_measurement_elapsed_time < C_PPG_MIN_DURATION_NS) begin
			$display("FAIL RAW-12 elapsed time insufficient elapsed_ns=%0d min_ns=%0d red=%0d ir=%0d",
				reg_measurement_elapsed_time, C_PPG_MIN_DURATION_NS, cnt_red_response, cnt_ir_response);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS RAW-12 post-START run covers real_red=%0d real_ir=%0d elapsed_ns=%0d (>=%0d) with no 32-bit overflow (time-typed)",
				cnt_red_response, cnt_ir_response, reg_measurement_elapsed_time, C_PPG_MIN_DURATION_NS);
		end

		// RAW-13：guard本身是time类型的12秒watchdog，没有缩短10秒观察窗口、
		// 没有替代帧/样本覆盖检查——上面RAW-12的三条独立断言已经证明了这点，
		// 这里只需确认watchdog真的是time类型且本次运行没有触发它
		if(flag_global_timeout) begin
			$display("FAIL RAW-13 watchdog fired, guard did not merely bound runtime");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS RAW-13 time-typed 12s watchdog (C_SIM_TIMEOUT_NS=%0d) did not fire and did not substitute for the frame/sample checks above", C_SIM_TIMEOUT_NS);
		end

		// STOP，确认干净排空
		task_pulse_stop;
		fork
			begin : longrun_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL LONGRUN stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : longrun_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000) && !flag_global_timeout) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL LONGRUN drain back to CONFIG timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL LONGRUN unexpected system fault blocking after STOP");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS LONGRUN STOP drained back to CONFIG without fault");
		end

		// 汇总并干净退出
		if(cnt_error == 0) begin
			$display("LONGRUN_TB_PASS real_red=%0d real_ir=%0d real_cal=%0d elapsed_ns=%0d measurement_result_valid=%0d",
				cnt_red_response, cnt_ir_response, cnt_cal_response, reg_measurement_elapsed_time, cnt_measurement_result_valid);
		end else begin
			$display("LONGRUN_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

	//---------------诊断专用：算法层信号探针，不是交付物---------------//
	reg reg_prev_coarse_valid;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_cross_ready) begin
			$display("DIAG PROBE CROSS t=%0t frame_id=%0d baseline_q16=%0d slope_q16=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_baseline_q16,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_slope_q16);
		end
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_peak_ready) begin
			$display("DIAG PROBE PEAK t=%0t frame_id=%0d value=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_value);
		end
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_valley_ready) begin
			$display("DIAG PROBE VALLEY t=%0t frame_id=%0d value=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_value);
		end
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_9bit_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_return_9bit_ready) begin
			$display("DIAG PROBE RETURN_9BIT t=%0t frame_id=%0d reason=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_reason);
		end
		if(o_coarse_valid && !reg_prev_coarse_valid && ((cnt_red_response + cnt_ir_response) < 80)) begin
			$display("DIAG PROBE COARSE t=%0t color_ir=%0d frame_id=%0d value=%0d",
				$time, o_result_color_ir, o_result_frame_id, o_coarse_ppg_value);
		end
		// FIR->峰谷检测器入口探针：直接看input_transfer这一拍到底携带了什么资格位和数值，
		// 只在真正RED且握手成立时打印，前60笔即可看出规律
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_result_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_result_ready &&
			(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_color_ir == 1'b0) &&
			(cnt_red_response < 60)) begin
			$display("DIAG PROBE FIR_IN t=%0t frame_id=%0d qualified=%0d win_sat_lo=%0d win_sat_hi=%0d fir_sat_lo=%0d fir_sat_hi=%0d precision=%0d frame_type=%0d filtered=%0d pv_cfg_valid=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_detection_qualified,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_window_saturation_low,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_window_saturation_high,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_fir_saturation_low,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_fir_saturation_high,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_precision_mode,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_frame_type,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_filtered_ppg_value,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_peak_valley_config_valid);
		end
		reg_prev_coarse_valid <= o_coarse_valid; // o_coarse_valid是保持型电平，边沿检测避免同一笔事务被反压期间的每一拍重复打印
	end

endmodule
