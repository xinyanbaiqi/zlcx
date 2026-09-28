`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/24
// Design Name:        PPG FIR Precision-Tail Isolation Testbench
// Module Name:        tb_ppg_control_top_fir_tail_isolation
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md
//                      PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//                      PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md
//                      PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy;
//                      tb_ppg_real_raw_generator.vh (Phase 3 Stage 1/2 generator)
//
// Version:            V1.2
// Revision Date:      2026/08/25
// History:
//    Time               Version       Revised by            Contents
// 2026/08/24            V1.0          Erie                  Create file. Phase 3 Stage 4 group 4 (PPG-FIR-TAIL-ISOLATION) per C25 section 9.2: "Exercise SAR15-to-SAR9 return with valid old SAR15 FIR history present. Confirm that the old precision tail cannot qualify a new SAR9 cross and that restored SAR9 samples rebuild only the permitted same-precision adjacency evidence." Direct RTL research (not assumption) before writing any assertion: PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md section 8 states mixed-precision 21-tap windows are explicitly legal and mathematically valid ("both modes use the same Stage1 coarse result and the same coarse DC-recovery scale... precision_mode only describes the center sample, it does not change the filter math") -- the FIR itself is deliberately NOT the isolation point and does not reset on a normal return. Reading ppg_dynamic_baseline_cross_detector.v and ppg_peak_valley_window_detector.v directly showed the two downstream detectors handle this asymmetrically by design: the cross detector's flag_cross_eligible_red_result explicitly ANDs i_precision_mode==0, and -- more importantly -- reg_previous_context/flag_previous_valid/flag_below_seen (the three pieces of state flag_candidate_start requires together) are each explicitly torn down to 0 by every single ineligible (precision_mode==1 tail) RED transaction, not merely left unset; flag_candidate_start's own assign statement ANDs flag_cross_eligible_red_result, flag_previous_valid, and the previous-sample threshold state together, so a new candidate structurally cannot form from anything but two genuinely-adjacent, genuinely-post-tail eligible samples. The peak/valley detector, by contrast, does NOT gate its own extremum tracking (flag_formal_sample/flag_previous_valid) on precision_mode at all -- waveform-shape detection is precision-invariant by design, consistent with the FIR contract's own "same physical scale" statement -- it only tracks flag_exit_precision_tail_active/cnt_exit_precision_tail as a bounded (<=10-sample) protocol diagnostic, not a functional gate. Built as a direct copy-and-extend of tb_ppg_control_top_peak_valley_return.v (the proven Group 3 delivery), keeping every Group 1/2/3 assertion running as regression insurance on the shared warmup/cross/SAR15-entry/first-return path. C_TARGET_RED_SAMPLES is extended from 700 to 900 (past the earlier files' scope) because group 4 needs to observe not just the first real SAR15-to-SAR9 return (already captured at frame 605 by the shared infrastructure) but a full second cross-into-SAR15 cycle forming from rebuilt evidence, which prior diagnostic runs placed around VALLEY@795/CROSS@810/PEAK@864 -- proving the isolation mechanism does not leave the system permanently unable to detect a legitimate cross after one tail episode is exactly what "rebuild... evidence" requires positive proof of, not just the absence of a spurious early one.
//                                                             Four new checks, all anchored to real captured hierarchical signals at the cross detector's own port boundary, not inference: (1) the tail is real and bounded -- count consecutive RED handshakes at the cross detector's i_result_valid&&o_result_ready&&!i_color_ir port with i_precision_mode==1 immediately after the first real RETURN_9BIT capture, assert at least one such handshake occurs (the tail scenario is genuinely exercised) and the count never exceeds C_FIR_GROUP_DELAY_SAMPLES(10); (2) the tail cannot arm or start a candidate -- for every one of those tail handshakes, assert the detector's own flag_below_seen and flag_previous_valid read back 0 on the following cycle (an external black-box observation of the RTL's internal reset behavior described above, not merely trusted from reading the source) and that no flag_candidate_start fires during the window; (3) restored evidence rebuilds correctly -- the first genuinely-eligible (precision_mode==0) RED handshake after the tail ends is captured and confirmed to only arm flag_previous_valid (reference-only, per the RTL's own comment "save one transaction that can be compared against the next center sample"), not to complete a crossing by itself; (4) the system demonstrably recovers -- the second real CROSS event is captured and its candidate_start payload traced back to a real precision_mode==0 adjacent-pair handshake at the cross detector's own port, mirroring group 2's real-data-path tracing technique for the first CROSS, proving the eventual crossing is built from genuine rebuilt post-tail evidence and not a leftover artifact.
// 2026/08/25            V1.1          Erie                  Verified for real, staged like every prior file in this group: iverilog 650-sample quick check first (all four new checks fired correctly on the very first attempt -- no bugs found this time, unlike every prior file in this session -- with the tail landing at exactly 10 precision_mode=1 handshakes, the theoretical maximum, ending at frame_id=616; the existence check correctly FAILed at this reduced scale since it had not yet reached the second cross, exactly as designed). C_TARGET_RED_SAMPLES was then restored to 900 and re-run: GROUP4_TAIL_BOUNDED, GROUP4_REBUILD_EVIDENCE, and GROUP4_EXISTENCE all passed with real non-trivial values, and the second real CROSS landed at frame_id=810 -- matching the prior diagnostic session's observation almost exactly -- with GROUP2_REAL_DATAPATH and GROUP1_BASELINE_FORMULA automatically re-verifying against this second crossing (recomputed B[f]=-11717189 matched o_cross_baseline_q16 bit-for-bit, from peak_value=301/peak_frame=625/cross_frame=810/frame_delta=185/slope=-169965), confirming those two checks generalize correctly to any cross event, not just the first one they were originally written against. The full local Vivado 2022.2 xsim flow (xvlog/xelab/xsim) then ran clean end to end in 5m56s wall-clock: FIR_TAIL_ISOLATION_TB_PASS real_red=900 real_ir=899 real_cal=0 measurement_result_valid=1798 peak_count=5 valley_count=4 cross_count=2 return_count=1, identical in every observed value to the iverilog run. This is real, staged simulation evidence for group 4 of Stage 4, not a placeholder.
// 2026/08/25            V1.2          Erie                  Added the shared JNT-01~09 baseline prefix (C25 sections 9.1/10.1 +
//                                                             PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md section 11) via
//                                                             `include "tb_ppg_jnt_baseline_prefix.vh"` (Architecture A) plus one
//                                                             bg_responder gate line and one call site, identically to
//                                                             tb_ppg_control_top_baseline_cross.v V1.3 -- see that file's V1.3 entry and
//                                                             the .vh file's own V1.0/V1.1 changelog for the full feasibility research
//                                                             and the four real bugs found and fixed while bringing the prefix up.
//                                                             JNT_BASELINE checked=53 pass=53 required=53 status=PASS confirmed clean.
//                                                             Also applied the same bg_responder owner-identity-snapshot fix as that
//                                                             file's V1.3 (latch frame_type/color_ir/frame_id/precision_mode on
//                                                             sched_adc_owner_commit_event_o instead of live-sampling state_current at
//                                                             wait_q3_release-return time) -- this file shares byte-identical
//                                                             bg_responder logic and had the exact same pre-existing, previously-invisible
//                                                             classification race, surfaced by the same real_cal=1 anomaly while
//                                                             confirming this file's own group-4 tail-isolation evidence still matched
//                                                             after the JNT prefix's extra reset cycles.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月24日
// 设计名称:           PPG FIR精度尾部隔离测试平台
// 模块名称:           tb_ppg_control_top_fir_tail_isolation
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md
//                      PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md
//                      PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md
//                      PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次；
//                      tb_ppg_real_raw_generator.vh（Phase 3 Stage 1/2生成器）
//
// 当前版本:           V1.2
// 修订日期:           2026年08月25日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月24日        V1.0          Erie                  创建文件。Phase 3 Stage 4第4组（PPG-FIR-TAIL-ISOLATION），照C25合同9.2节原文："在存在合法旧SAR15 FIR历史的情况下执行SAR15到SAR9的返回。确认旧精度尾部不能拿来凑成一次新的SAR9穿越，且恢复的SAR9样本只能重建被允许的同精度相邻证据"。动手写断言之前先做了真实RTL调研，不是凭空假设：`PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md`第8节明确说混合精度的21点窗口是合法且数学上有效的（"两种模式都使用同一Stage1粗结果和同一粗DC恢复标度……precision_mode只描述中心样本，不改变滤波数学"）——FIR本身故意不是隔离点，正常返回不会清空它的历史。直接读`ppg_dynamic_baseline_cross_detector.v`和`ppg_peak_valley_window_detector.v`发现下游两个检测器的做法是刻意不对称的：CROSS检测器的`flag_cross_eligible_red_result`显式要求`i_precision_mode==0`；更关键的是，`flag_candidate_start`需要同时具备的三块状态——`reg_previous_context`/`flag_previous_valid`/`flag_below_seen`——每一笔不合格（precision_mode==1的尾部）RED事务都会把它们显式清零，不是放着不管；`flag_candidate_start`自己的赋值语句把`flag_cross_eligible_red_result`、`flag_previous_valid`和前一样本的门槛状态一起AND起来，结构上就决定了新候选只能由两笔真正相邻、真正退出尾部之后的合格样本组成。峰谷检测器则相反——它自己的极值跟踪（`flag_formal_sample`/`flag_previous_valid`）完全不检查precision_mode，波形形状检测本来就和精度标签无关，和FIR合同"同一物理标度"的说法一致；它只用`flag_exit_precision_tail_active`/`cnt_exit_precision_tail`做一个有界（≤10笔）的协议诊断，不是功能性门控。本文件是`tb_ppg_control_top_peak_valley_return.v`（已交付的Group3版本）的直接复制+扩展，原样保留Group1/2/3全部断言作为共享预热/穿越/SAR15提交/首次返回路径的回归保险。`C_TARGET_RED_SAMPLES`从700延长到900（超出此前几份文件的覆盖范围），因为Group4不仅要观察第一次真实SAR15→SAR9返回（共享基础设施已经在frame 605捕获过），还要观察一次完整的、由重建证据形成的第二次穿越进入SAR15的周期——此前的诊断跑显示这大约发生在VALLEY@795/CROSS@810/PEAK@864附近——证明隔离机制不会让系统在一次尾部事件后永久丧失穿越检测能力，这正是"重建证据"这个要求需要的正向证明，不能只满足于"没有过早误触发"这种消极结论。
//                                                             四条新检查全部锚定在CROSS检测器自己端口上真实捕获的层级信号，不是推断：（1）尾部真实存在且有界——在第一次真实RETURN_9BIT捕获之后，统计CROSS检测器`i_result_valid&&o_result_ready&&!i_color_ir`端口上`i_precision_mode==1`的连续RED握手笔数，断言至少出现一笔（尾部场景确实被真实触发）且笔数从不超过`C_FIR_GROUP_DELAY_SAMPLES`(10)；（2）尾部不能武装或启动候选——对这段窗口里的每一笔尾部握手，断言检测器自己的`flag_below_seen`和`flag_previous_valid`在下一拍读回0（这是对上面描述的RTL内部复位行为的外部黑盒观测，不是单纯相信读源码得到的结论），且窗口期间`flag_candidate_start`从未触发；（3）恢复的证据正确重建——尾部结束后第一笔真正合格（precision_mode==0）的RED握手被捕获，确认它只武装了`flag_previous_valid`（仅供参考，对应RTL自己的注释"保存一笔可与下个中心样本相邻比较的事务"），不会单独就完成一次穿越；（4）系统确实恢复——捕获第二次真实CROSS事件，把它的`candidate_start`载荷回溯到CROSS检测器自己端口上一对真实的precision_mode==0相邻握手，沿用Group2给第一次CROSS做真实数据路径回溯时的同款手法，证明最终形成的穿越确实建立在真实重建的尾部之后证据上，不是残留假象。
// 2026年08月25日        V1.1          Erie                  和这一组之前每份文件一样严格分阶段真实验证：先iverilog 650样本快速跑——四条新检查第一次跑就全部正确触发，这次没有抓到任何bug（和本会话里之前每份文件都不一样），尾部长度精确落在10笔precision_mode=1握手（理论上界），结束于frame_id=616；存在性检查在这个缩小规模下如预期正确FAIL，因为还没跑到第二次穿越。随后把`C_TARGET_RED_SAMPLES`恢复到900重新跑：`GROUP4_TAIL_BOUNDED`、`GROUP4_REBUILD_EVIDENCE`、`GROUP4_EXISTENCE`全部用真实、非平凡的数值通过，第二次真实CROSS精确落在frame_id=810——和此前诊断会话观察到的结果几乎完全一致——`GROUP2_REAL_DATAPATH`和`GROUP1_BASELINE_FORMULA`自动对这第二次穿越重新验证了一遍（重算得到的B[f]=-11717189与`o_cross_baseline_q16`逐位相符，来自peak_value=301/peak_frame=625/cross_frame=810/frame_delta=185/slope=-169965），确认这两条检查能正确推广到任意一次穿越事件，不只是它们最初针对的第一次。随后走本机Vivado 2022.2完整xsim流程（xvlog/xelab/xsim）干净跑通，挂钟耗时5分56秒：`FIR_TAIL_ISOLATION_TB_PASS real_red=900 real_ir=899 real_cal=0 measurement_result_valid=1798 peak_count=5 valley_count=4 cross_count=2 return_count=1`，每一个观测值都和iverilog跑完全一致。这是Stage 4第4组真实、分阶段的仿真证据，不是占位文字。
// 2026年08月25日        V1.2          Erie                  接入共享JNT-01~09基线前缀（C25第9.1/10.1节+
//                                                             PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md第11节），做法和
//                                                             `tb_ppg_control_top_baseline_cross.v`V1.3完全一致：`` `include
//                                                             "tb_ppg_jnt_baseline_prefix.vh" ``（架构方案A）加一行bg_responder让路
//                                                             语句加一处调用点——完整可行性研究和接入过程中发现并修复的四个真实bug
//                                                             记在那份文件自己的V1.3条目和`.vh`文件自己的V1.0/V1.1
//                                                             changelog里。真实跑确认`JNT_BASELINE checked=53 pass=53 required=53
//                                                             status=PASS`。同时应用了和那份文件V1.3同款的`bg_responder`
//                                                             owner身份快照修复（在`sched_adc_owner_commit_event_o`那一拍锁存
//                                                             frame_type/color_ir/frame_id/precision_mode，不再在`wait_q3_release`
//                                                             返回那一拍live采样`state_current`）——本文件和那份文件共用逐字节
//                                                             相同的`bg_responder`代码，同样一直存在这个此前从未被观察到的分类
//                                                             竞争，是在核对本文件自己的Group4尾部隔离证据在JNT前缀多次复位之后
//                                                             是否依然一致时，被同一个`real_cal=1`异常牵出来的。
//
// 复位后提交合法NORMAL双光MANUAL配置（含C11标称Stage1校准权重、
// peak_valley_config_valid=1）并START，之后完全依赖既有bg_responder真实响应，
// 等待第一次真实PEAK/CROSS/SAR15提交/RETURN_9BIT完整序列出现，先核对Group 1/2/3
// 已验证的断言仍然成立，再核对Group 4合同要求的四条新增断言（尾部有界、尾部
// 不能武装候选、恢复证据正确重建、系统真实恢复形成第二次穿越），STOP后确认
// 干净排空
module tb_ppg_control_top_fir_tail_isolation();

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

	//---------------Group 1/2场景控制参数---------------//
	// 全局看门狗：相对仿真起点，只是安全防挂死上限，不是本文件要证明的验收目标
	// （那是Stage 3/RAW-12的范围）；诊断阶段观察到完整一轮SAR9->SAR15->SAR9周期
	// 在约frame 625处完成，留出充分裕量
	localparam time C_SIM_TIMEOUT_NS = 64'd3000000000; // 3秒安全看门狗上限
	localparam integer C_TARGET_RED_SAMPLES = 900; // 延长到覆盖第二次CROSS（诊断证据约在frame~810），证明尾部隔离后系统真实恢复穿越检测能力
	// C20第5.4节/C22第4.2节冻结的粗检测FIR群延时：中心样本x[n-10]，固定10个同色有效样本
	localparam integer C_FIR_GROUP_DELAY_SAMPLES = 10;
	// 群延时检查B的容差：21抽头线性相位FIR平滑分段线性波形的尖角转折点可能让表观
	// 极值挪动，容差取FIR半窗口量级（10）+1帧余量，不要求逐帧相等
	localparam integer C_GROUP_DELAY_TOLERANCE_FRAMES = 11;
	// 检查B独立复现生成器task_generate_pulse_shape的RED收缩快升终点公式
	// （rise_end_frame=(pulse_period_frames*C_RAW_RISE_PCT)/100），C_RAW_PULSE_PERIOD_FRAMES
	// 和C_RAW_RISE_PCT均来自`include的tb_ppg_real_raw_generator.vh，NORMAL档位下就是400*15/100=60
	localparam integer C_RAW_RISE_END_FRAME_RED = (C_RAW_PULSE_PERIOD_FRAMES * C_RAW_RISE_PCT) / 100;
	// B[f]公式独立重算用：与V5_RESET_PROFILE_REF的baseline_delta_q16字段逐位一致（本场景恒为0）
	localparam signed [31:0] C_BASELINE_DELTA_Q16 = 32'sd0;

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

	//---------------Group 1/2事件捕获与断言状态---------------//
	integer reg_peak_count; // 已捕获的真实PEAK事件数
	integer reg_valley_count; // 已捕获的真实VALLEY事件数
	integer reg_cross_count; // 已捕获的真实CROSS事件数
	integer reg_return_count; // 已捕获的真实RETURN_9BIT事件数
	reg signed [23:0] reg_peak_value; // 最近一次PEAK事件的Stage1粗FIR码值
	reg [C_FRAME_ID_WIDTH - 1:0] reg_peak_frame_id; // 最近一次PEAK事件的中心帧号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_peak_sample_index; // 最近一次PEAK事件对应的事务序号
	reg signed [23:0] reg_valley_value; // 最近一次VALLEY事件的Stage1粗FIR码值
	reg [C_FRAME_ID_WIDTH - 1:0] reg_valley_frame_id; // 最近一次VALLEY事件的中心帧号
	reg [C_FRAME_ID_WIDTH - 1:0] reg_cross_frame_id; // 最近一次CROSS事件首次越过的中心帧号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_cross_sample_index; // 最近一次CROSS事件对应的事务序号
	reg reg_cross_time_unknown; // 最近一次CROSS事件是否为重检后未知时刻类型
	reg signed [31:0] reg_cross_slope_q16; // 最近一次CROSS事件锁存的活动斜率
	reg signed [47:0] reg_cross_baseline_q16; // 最近一次CROSS事件RTL上报的诊断基线
	reg [C_FRAME_ID_WIDTH - 1:0] reg_return_frame_id; // 最近一次RETURN_9BIT事件绑定的帧号
	reg [1:0] reg_return_reason; // 最近一次RETURN_9BIT事件原因
	reg flag_baseline_ever_valid; // 曾经观察到o_baseline_valid为高的sticky标志，Group1检查1的判定基准
	reg [C_FRAME_ID_WIDTH - 1:0] reg_expected_cross_frame_id; // candidate_start那一拍锁存的真实RED FIR事务帧号
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_expected_cross_sample_index; // candidate_start那一拍锁存的真实RED FIR事务序号
	reg flag_expected_cross_from_real_red; // candidate_start那一拍是否确实绑定了一笔真实RED握手
	reg [C_FRAME_ID_WIDTH - 1:0] reg_live_frame_id_at_first_peak; // 首个PEAK握手拍同步采样的调度器活值frame_id
	reg [C_FRAME_ID_WIDTH - 1:0] reg_live_frame_id_at_first_cross; // 首个CROSS握手拍同步采样的调度器活值frame_id
	reg flag_first_peak_captured; // 首个PEAK是否已经处理过检查A/B，避免后续PEAK重复计入
	reg flag_first_cross_captured; // 首个CROSS是否已经处理过检查A，避免后续CROSS重复计入
	// Group1检查2（IR不变性）用的握手前快照
	reg flag_ir_check_pending; // 上一拍是否刚捕获过一笔IR握手，等待本拍核对RED运行态未变
	reg reg_ir_pre_baseline_valid; // IR握手那一拍采样到的o_baseline_valid
	reg signed [31:0] reg_ir_pre_slope_current_q16; // IR握手那一拍采样到的o_slope_current_q16
	reg signed [31:0] reg_ir_pre_slope_base_q16; // IR握手那一拍采样到的o_slope_base_q16
	reg [3:0] reg_ir_pre_no_cross_count; // IR握手那一拍采样到的o_no_cross_count
	reg reg_ir_pre_reacquire_active; // IR握手那一拍采样到的o_reacquire_active
	// Group2检查3（SAR9<->SAR15切换连续性）用的最近正式结果与切换前快照
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_last_result_sample_index; // 最近一笔正式结果的sample_index
	reg [7:0] reg_last_result_amb_code_snapshot; // 最近一笔正式结果的AMB码快照
	reg [7:0] reg_last_result_dc_code_snapshot; // 最近一笔正式结果的颜色DC码快照
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_last_result_amb_code_epoch; // 最近一笔正式结果的AMB码提交版本
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_last_result_dc_code_epoch; // 最近一笔正式结果的颜色DC码提交版本
	reg reg_last_result_color_ir; // 最近一笔正式结果的颜色
	reg flag_last_result_valid; // 是否已经出现过至少一笔正式结果
	// Group2检查3b专用：dcs_r_manual_code与dcs_ir_manual_code在本场景配置里逐色独立
	// （RED=80、IR=96），AMB/DC快照+epoch的稳定性只能同色比较，不能用"最近一笔任意
	// 颜色结果"当基准，否则RED/IR交替天然会让DC快照看起来"变了"
	reg [7:0] reg_last_red_result_amb_code_snapshot; // 最近一笔RED正式结果的AMB码快照
	reg [7:0] reg_last_red_result_dc_code_snapshot; // 最近一笔RED正式结果的颜色DC码快照
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_last_red_result_amb_code_epoch; // 最近一笔RED正式结果的AMB码提交版本
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_last_red_result_dc_code_epoch; // 最近一笔RED正式结果的颜色DC码提交版本
	reg flag_last_red_result_valid; // 是否已经出现过至少一笔RED正式结果
	// Group2检查2专用：o_fine_window_start_event是fine_window_start_event_o寄存器输出，
	// 比真正做出安全边界判决的flag_enter_commit晚一拍；i_frame_safe_boundary是逐帧单拍
	// 脉冲，到寄存器脉冲出现的那一拍往往已经撤销，必须用上一拍锁存的门控快照才能对齐
	// 因果关系，不能直接在事件拍读三个门控信号的"当前"值
	reg reg_prev_frame_safe_boundary; // 上一拍采样到的i_frame_safe_boundary
	reg reg_prev_precision_takeover_safe; // 上一拍采样到的i_precision_takeover_safe
	reg reg_prev_analog_safe; // 上一拍采样到的i_analog_safe
	reg reg_prev_adc_physical_idle; // 上一拍采样到的TB自驱i_adc_physical_idle

	//---------------Group 3事件捕获与断言状态---------------//
	// SAR15阶段身份追踪：只对"SAR15提交后第一次出现"的PEAK/VALLEY取证，避免SAR9阶段
	// 已经统计过的旧事件（如PEAK@225）被误当成Group3自己的证据
	reg flag_sar15_active; // 当前是否已经真实提交SAR15（对应o_active_precision_mode==1）
	reg flag_first_peak_in_sar15_captured; // SAR15提交后首个PEAK是否已经取证
	reg flag_first_valley_in_sar15_captured; // SAR15提交后首个VALLEY是否已经取证
	reg [C_FRAME_ID_WIDTH - 1:0] reg_first_peak_in_sar15_frame_id; // SAR15提交后首个PEAK的frame_id
	reg [C_FRAME_ID_WIDTH - 1:0] reg_first_valley_in_sar15_frame_id; // SAR15提交后首个VALLEY的frame_id
	// 检查2"中心样本身份的绑定"用：直接在峰谷检测器自己的FIR输入端口上实时追踪最近一笔
	// 真实RED+SAR15握手的frame_id，作为PEAK/VALLEY上报frame_id的独立上界证据来源
	reg [C_FRAME_ID_WIDTH - 1:0] reg_last_real_red_sar15_frame_id; // 峰谷检测器输入端口最近一笔真实RED+SAR15 FIR握手frame_id
	reg flag_last_real_red_sar15_frame_id_valid; // 上述追踪值是否已经出现过至少一次
	// 检查3"合同规定的RETURN请求"用：SAR15提交后首个确认VALLEY的frame_id，供核对
	// o_return_frame_id不早于它
	reg [C_FRAME_ID_WIDTH - 1:0] reg_confirmed_valley_frame_id_for_return; // 供RETURN请求核对用的确认谷值frame_id
	reg [C_FRAME_ID_WIDTH - 1:0] reg_sar15_entry_frame_id; // SAR15_TRANSITION捕获拍锁存的o_fine_window_start_frame_id，供检查2下界使用
	// 检查4"SAR15→SAR9的安全提交"用：镜像Group2入场侧的做法，监视o_active_precision_mode
	// 下降沿，核对"上一拍"锁存的门控快照而不是当拍瞬时值
	reg reg_prev_active_precision_mode; // 上一拍采样到的o_active_precision_mode，用于检测下降沿
	reg flag_group3_return_commit_checked; // 只对第一次SAR15->SAR9返回取证，避免后续切换稀释首次证据

	//---------------Group 4事件捕获与断言状态---------------//
	// 尾部窗口：从第一次真实返回提交（flag_group3_return_commit_checked置位）开始，
	// 到CROSS检测器端口第一笔precision_mode==0的真实RED握手为止
	reg flag_tail_window_active; // 当前是否处于精度尾部监视窗口内
	reg flag_tail_observed; // 尾部场景是否真实被触发过至少一次（存在性证据）
	reg flag_tail_ended; // 尾部窗口是否已经结束，sticky，只处理第一次尾部
	reg [7:0] cnt_tail_red_handshakes; // 尾部窗口内已观察到的precision_mode==1 RED握手笔数
	reg flag_tail_check_pending; // 上一拍是尾部握手，这一拍核对武装状态是否已清零
	reg flag_rebuild_check_pending; // 上一拍是尾部结束后首笔合格握手，这一拍核对武装状态
	reg flag_first_eligible_post_tail_captured; // 尾部结束后首笔合格RED握手是否已经取证
	reg [C_FRAME_ID_WIDTH - 1:0] reg_first_eligible_post_tail_frame_id; // 该笔握手的frame_id
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_pretransition_sample_index; // SAR15切换前锁存的sample_index
	reg [7:0] reg_pretransition_amb_code_snapshot; // SAR15切换前锁存的AMB码快照
	reg [7:0] reg_pretransition_dc_code_snapshot; // SAR15切换前锁存的颜色DC码快照
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_pretransition_amb_code_epoch; // SAR15切换前锁存的AMB码提交版本
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_pretransition_dc_code_epoch; // SAR15切换前锁存的颜色DC码提交版本
	reg flag_awaiting_posttransition_any; // 等待切换后紧邻的任意一笔结果核对sample_index连续性
	reg flag_awaiting_posttransition_red; // 等待切换后紧邻的一笔RED结果核对AMB/DC快照+epoch
	reg flag_group2_transition_checked; // 只对第一次SAR9->SAR15切换取证，避免后续切换稀释首次证据

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
			i_source_config_snapshot[1009] = 1'b1; // peak_valley_config_valid：V5_RESET_PROFILE_REF默认0会让探测器消费排空但拒绝发布任何正式cross/peak/valley事件（C22 3.3节非法配置清单），Group 1/2必须显式打开
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

	// xvlog要求声明先于使用（ppg_control_top.v V1.1changelog记录过同类教训），本
	// include必须放在DUT例化、全部wire声明和task_build_normal_manual_config等
	// 共享task定义之后、bg_responder使用flag_jnt_manual_adc_hold之前
	`include "tb_ppg_jnt_baseline_prefix.vh"

	//---------------后台ADC响应进程---------------//
	// 与tb_ppg_control_top.v V1.4的bg_responder逻辑完全一致，本文件不加逐笔打印，
	// 事件级证据改由下面的专用捕获进程提供
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

	//---------------真实owner身份快照进程（供bg_responder使用）---------------//
	// bg_responder原来在wait_q3_release返回那一拍才live采样
	// ppg_400hz_frame_calibration_scheduler_Inst.state_current的B_INFLIGHT_TYPE_H/
	// B_INFLIGHT_COLOR/B_FRAME_PRECISION字段，和SSW的flag_cal_context_valid；JNT-01~09
	// 接入后第一次真实iverilog全规模跑发现这个采样点和owner真正提交（o_adc_owner_
	// commit_event）的那一拍没有严格对齐——FRAME_TYPE_AMB恰好编码为2'b00，和
	// state_current复位默认值撞车，此前从未观察到只是因为在此之前state_current
	// 复位到的一直是Verilog未初始化的X（!X在if判断里按false处理），JNT-01~09让
	// 同一次仿真里发生多次真实复位后，X变成了确定的0，这个既有采样时序缺陷才第一次
	// 被暴露（不影响任何已断言的检查，cnt_cal_response从未被assert过，只是展示计数）。
	// 修复：在owner真正提交那一拍把身份字段锁存进影子寄存器，bg_responder只读快照，
	// 不再live采样state_current，和本文件其余捕获进程（PEAK/VALLEY/owner-commit
	// 监视等）已经在用的"事件边沿锁存"手法保持一致
	reg reg_owner_snapshot_is_calibration;
	reg reg_owner_snapshot_color_ir;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_owner_snapshot_frame_id;
	reg reg_owner_snapshot_precision;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			reg_owner_snapshot_is_calibration <= (ppg_control_top_Inst.sched_adc_owner_frame_type_o != 2'b10); // FRAME_TYPE_NORMAL=2'b10，其余编码均为校准类（AMB/DCS）
			reg_owner_snapshot_color_ir <= ppg_control_top_Inst.sched_adc_owner_color_ir_o;
			reg_owner_snapshot_frame_id <= ppg_control_top_Inst.sched_adc_owner_frame_id_o;
			reg_owner_snapshot_precision <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
		end
	end

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
			while(flag_jnt_manual_adc_hold) @(negedge i_clk); // JNT-01~09手工控制ADC完成时序期间，后台自动响应进程必须让路，避免双写i_dout_stage1_low
			if(flag_q3_real_release) begin
				flag_response_is_calibration = reg_owner_snapshot_is_calibration;
				reg_response_color_ir = reg_owner_snapshot_color_ir;
				reg_response_frame_id = {16'd0, reg_owner_snapshot_frame_id};
				if(flag_response_is_calibration) begin
					cnt_cal_response = cnt_cal_response + 1;
				end else if(reg_response_color_ir) begin
					cnt_ir_response = cnt_ir_response + 1;
				end else begin
					cnt_red_response = cnt_red_response + 1;
				end
				reg_response_precision = reg_owner_snapshot_is_calibration ? 1'b0 : reg_owner_snapshot_precision; // 校准事务合同强制SAR9，其余用锁存的owner精度身份
				if(flag_response_is_calibration) begin
					reg_response_stage1_raw = reg_fixed_stage1_raw;
					reg_response_stage2_raw = reg_fixed_stage2_raw;
				end else begin
					task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_response_color_ir, reg_response_frame_id,
						reg_response_target_code, reg_response_raw_unclamped);
					make_fixed_raw(reg_response_target_code, reg_response_stage1_raw);
					make_fixed_raw(reg_response_target_code, reg_response_stage2_raw);
				end
				drive_real_adc_done(reg_response_precision, reg_response_stage1_raw, reg_response_stage2_raw);
				cnt_adc_response = cnt_adc_response + 1;
				if((cnt_adc_response % 200) == 0) begin
					$display("DIAG progress t=%0t red=%0d ir=%0d cal=%0d", $time, cnt_red_response, cnt_ir_response, cnt_cal_response);
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

	//---------------Group 3：SAR15阶段身份追踪进程---------------//
	// 每拍无条件采样o_active_precision_mode供检查4边沿检测；同时直接在峰谷检测器自己的
	// FIR输入端口上实时追踪最近一笔真实RED+SAR15握手frame_id，供检查2给PEAK/VALLEY
	// 上报frame_id提供独立的可信上界（不依赖PEAK/VALLEY自己上报的值，避免自证）
	always @(posedge i_clk) begin
		reg_prev_active_precision_mode <= ppg_control_top_Inst.ami_active_precision_mode_o;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_result_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_result_ready &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_precision_mode &&
			!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_color_ir) begin
			reg_last_real_red_sar15_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_frame_id;
			flag_last_real_red_sar15_frame_id_valid <= 1'b1;
		end
	end

	//---------------PEAK事件捕获与检查A/B（群延时验证）进程---------------//
	// 路径口径：ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.
	// ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst，
	// 与tb_diag_algo_probe.v已验证过的边沿检测方式一致（valid&&ready才是真正握手拍）
	always @(posedge i_clk) begin : peak_capture_block
		integer this_live_frame_id;
		integer this_peak_frame_id_signed;
		integer theoretical_rise_frame;
		integer frame_diff;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_peak_ready) begin
			reg_peak_value <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_value;
			reg_peak_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id;
			reg_peak_sample_index <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_sample_index;
			reg_peak_count <= reg_peak_count + 1;
			$display("PEAK CAPTURE t=%0t frame_id=%0d value=%0d count=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_value,
				reg_peak_count + 1);
			if(!flag_first_peak_captured) begin
				flag_first_peak_captured <= 1'b1;
				this_peak_frame_id_signed = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id;
				this_live_frame_id = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_current_frame_id;
				reg_live_frame_id_at_first_peak <= this_live_frame_id;
				// 检查A：事件握手拍同步采样调度器活值frame_id，确认RTL确实用中心frame_id标签而非墙钟到达帧
				if((this_live_frame_id - this_peak_frame_id_signed) < C_FIR_GROUP_DELAY_SAMPLES) begin
					$display("FAIL GROUP1_BSL04_CHECK_A first PEAK frame_id not group-delay-tagged live_frame_id=%0d peak_frame_id=%0d diff=%0d need>=%0d",
						this_live_frame_id, this_peak_frame_id_signed, this_live_frame_id - this_peak_frame_id_signed, C_FIR_GROUP_DELAY_SAMPLES);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP1_BSL04_CHECK_A first PEAK live_frame_id=%0d peak_frame_id=%0d diff=%0d >= %0d",
						this_live_frame_id, this_peak_frame_id_signed, this_live_frame_id - this_peak_frame_id_signed, C_FIR_GROUP_DELAY_SAMPLES);
				end
				// 检查B：独立用生成器自己的pulse_shape闭式公式算出RED理论快升转折点帧号，容差内比对
				theoretical_rise_frame = ((this_peak_frame_id_signed / C_RAW_PULSE_PERIOD_FRAMES) * C_RAW_PULSE_PERIOD_FRAMES) + C_RAW_RISE_END_FRAME_RED;
				frame_diff = this_peak_frame_id_signed - theoretical_rise_frame;
				if(frame_diff < 0) frame_diff = -frame_diff;
				if(frame_diff > C_GROUP_DELAY_TOLERANCE_FRAMES) begin
					$display("FAIL GROUP1_PVW17_CHECK_B first PEAK frame_id far from generator theoretical rise-corner peak_frame_id=%0d theoretical=%0d diff=%0d tol=%0d",
						this_peak_frame_id_signed, theoretical_rise_frame, frame_diff, C_GROUP_DELAY_TOLERANCE_FRAMES);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP1_PVW17_CHECK_B first PEAK frame_id=%0d theoretical_rise_corner=%0d diff=%0d <= tol=%0d",
						this_peak_frame_id_signed, theoretical_rise_frame, frame_diff, C_GROUP_DELAY_TOLERANCE_FRAMES);
				end
			end
			// Group3检查1/2（PEAK侧）：SAR15提交后首个PEAK的顺序取证与中心样本身份绑定核对，
			// 只在o_fine_window_start_event真实握手之后才取证，避免SAR9阶段旧PEAK（如PEAK@225）
			// 被误算成Group3自己的证据
			if(flag_group2_transition_checked && !flag_first_peak_in_sar15_captured) begin
				flag_first_peak_in_sar15_captured <= 1'b1;
				reg_first_peak_in_sar15_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id;
				if(!flag_last_real_red_sar15_frame_id_valid ||
					(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id < reg_sar15_entry_frame_id) ||
					(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id > reg_last_real_red_sar15_frame_id)) begin
					$display("FAIL GROUP3_CENTER_SAMPLE_IDENTITY first SAR15 PEAK frame_id out of bound peak_frame_id=%0d sar15_entry_frame_id=%0d last_real_red_sar15_frame_id=%0d valid=%0d",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id,
						reg_sar15_entry_frame_id, reg_last_real_red_sar15_frame_id, flag_last_real_red_sar15_frame_id_valid);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP3_CENTER_SAMPLE_IDENTITY first SAR15 PEAK frame_id=%0d bounded within [sar15_entry=%0d, last_real_red_sar15=%0d]",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id,
						reg_sar15_entry_frame_id, reg_last_real_red_sar15_frame_id);
				end
				// Group3检查1：波峰先于波谷的顺序——若VALLEY已经先取证，说明顺序违反合同要求
				if(flag_first_valley_in_sar15_captured) begin
					$display("FAIL GROUP3_PEAK_BEFORE_VALLEY_ORDER first SAR15 VALLEY frame_id=%0d already captured before first SAR15 PEAK frame_id=%0d",
						reg_first_valley_in_sar15_frame_id,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_peak_frame_id);
					cnt_error = cnt_error + 1;
				end
			end
		end
	end

	//---------------VALLEY事件捕获进程---------------//
	always @(posedge i_clk) begin : valley_capture_block
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_valley_ready) begin
			reg_valley_value <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_value;
			reg_valley_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id;
			reg_valley_count <= reg_valley_count + 1;
			$display("VALLEY CAPTURE t=%0t frame_id=%0d value=%0d count=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_value,
				reg_valley_count + 1);
			// Group3检查1/2（VALLEY侧）：SAR15提交后首个VALLEY的顺序取证与中心样本身份绑定核对
			if(flag_group2_transition_checked && !flag_first_valley_in_sar15_captured) begin
				flag_first_valley_in_sar15_captured <= 1'b1;
				reg_first_valley_in_sar15_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id;
				reg_confirmed_valley_frame_id_for_return <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id;
				if(!flag_last_real_red_sar15_frame_id_valid ||
					(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id < reg_sar15_entry_frame_id) ||
					(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id > reg_last_real_red_sar15_frame_id)) begin
					$display("FAIL GROUP3_CENTER_SAMPLE_IDENTITY first SAR15 VALLEY frame_id out of bound valley_frame_id=%0d sar15_entry_frame_id=%0d last_real_red_sar15_frame_id=%0d valid=%0d",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id,
						reg_sar15_entry_frame_id, reg_last_real_red_sar15_frame_id, flag_last_real_red_sar15_frame_id_valid);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP3_CENTER_SAMPLE_IDENTITY first SAR15 VALLEY frame_id=%0d bounded within [sar15_entry=%0d, last_real_red_sar15=%0d]",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id,
						reg_sar15_entry_frame_id, reg_last_real_red_sar15_frame_id);
				end
				// Group3检查1：波峰先于波谷的顺序——正式核验点，此时首个PEAK必须已经先取证
				if(!flag_first_peak_in_sar15_captured) begin
					$display("FAIL GROUP3_PEAK_BEFORE_VALLEY_ORDER first SAR15 VALLEY frame_id=%0d captured before any SAR15 PEAK",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id);
					cnt_error = cnt_error + 1;
				end else if(reg_first_peak_in_sar15_frame_id >= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id) begin
					$display("FAIL GROUP3_PEAK_BEFORE_VALLEY_ORDER first SAR15 PEAK frame_id=%0d not strictly before first SAR15 VALLEY frame_id=%0d",
						reg_first_peak_in_sar15_frame_id,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP3_PEAK_BEFORE_VALLEY_ORDER first SAR15 PEAK frame_id=%0d strictly before first SAR15 VALLEY frame_id=%0d",
						reg_first_peak_in_sar15_frame_id,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id);
				end
			end
		end
	end

	//---------------RETURN_9BIT事件捕获进程---------------//
	always @(posedge i_clk) begin : return_capture_block
		reg valley_confirmed_same_cycle;
		reg [C_FRAME_ID_WIDTH - 1:0] effective_valley_frame_id;
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_9bit_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_return_9bit_ready) begin
			reg_return_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_frame_id;
			reg_return_reason <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_reason;
			reg_return_count <= reg_return_count + 1;
			$display("RETURN_9BIT CAPTURE t=%0t frame_id=%0d reason=%0d count=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_reason,
				reg_return_count + 1);
			// Group3检查3：合同规定的RETURN请求——只对第一次RETURN取证（reg_return_count此刻
			// 仍是nonblocking更新前的旧值，==0即代表这是首次捕获）。原因必须是C22第11.4节冻结的
			// VALLEY_CONFIRMED(2'b00)，frame_id不早于本组已确认的SAR15谷值frame_id（PVW-10记录的
			// 3点确认延迟，不要求逐帧相等）。真实跑发现VALLEY和RETURN_9BIT经常是同一检测结论的
			// 两个独立握手通道、在同一拍完成握手（C22第11.4节"波谷和返回9-bit请求属于同一检测
			// 结论，但分别完成各自握手"），此时VALLEY捕获块的flag_first_valley_in_sar15_captured
			// 还是nonblocking更新前的旧值（本拍看不到），必须额外核对峰谷检测器自己VALLEY端口
			// 在同一拍是否也正在握手，不能只看上一拍锁存的寄存器
			if(reg_return_count == 0) begin
				valley_confirmed_same_cycle = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_valid &&
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_valley_ready;
				effective_valley_frame_id = flag_first_valley_in_sar15_captured ? reg_confirmed_valley_frame_id_for_return :
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_valley_frame_id;
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_reason != 2'b00) begin
					$display("FAIL GROUP3_RETURN_REQUEST first RETURN_9BIT reason is not VALLEY_CONFIRMED reason=%0d",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_reason);
					cnt_error = cnt_error + 1;
				end else if(!flag_first_valley_in_sar15_captured && !valley_confirmed_same_cycle) begin
					$display("FAIL GROUP3_RETURN_REQUEST first RETURN_9BIT observed before any confirmed SAR15 VALLEY was captured");
					cnt_error = cnt_error + 1;
				end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_frame_id < effective_valley_frame_id) begin
					$display("FAIL GROUP3_RETURN_REQUEST first RETURN_9BIT frame_id=%0d earlier than confirmed SAR15 valley frame_id=%0d",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_frame_id,
						effective_valley_frame_id);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP3_RETURN_REQUEST first RETURN_9BIT reason=VALLEY_CONFIRMED frame_id=%0d >= confirmed_valley_frame_id=%0d same_cycle=%0d",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_frame_id,
						effective_valley_frame_id, valley_confirmed_same_cycle);
				end
			end
		end
	end

	//---------------CROSS检测器状态监视与Group1检查1/2取证/Group1检查3/检查A（首个CROSS）进程---------------//
	// 路径口径：ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.
	// ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst
	always @(posedge i_clk) begin : cross_detector_monitor_block
		integer this_live_frame_id;
		integer this_cross_frame_id_signed;
		integer frame_delta_unsigned;
		reg signed [47:0] peak_value_q16;
		reg signed [47:0] delta_q16_extended;
		reg signed [63:0] slope_product_wide;
		reg signed [47:0] expected_baseline_q16;
		// 首个PEAK建立o_baseline_valid之前不能出现真实cross握手的判定基准，sticky一旦置1永不清零
		if(!i_rstn) begin
			flag_baseline_ever_valid <= 1'b0;
		end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_baseline_valid) begin
			flag_baseline_ever_valid <= 1'b1;
		end
		// Group1检查1：历史不足不能形成合格穿越——首个PEAK建立o_baseline_valid之前不能有cross握手
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_cross_ready &&
			!flag_baseline_ever_valid) begin
			$display("FAIL GROUP1_HISTORY_INSUFFICIENT cross handshake observed before baseline_valid ever asserted t=%0t", $time);
			cnt_error = cnt_error + 1;
		end
		// Group2检查1取证：候选首次越过必须绑定一笔真实RED FIR握手，而不是凭空产生
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.flag_candidate_start) begin
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_result_valid &&
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_result_ready &&
				!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_color_ir) begin
				reg_expected_cross_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_frame_id;
				reg_expected_cross_sample_index <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_sample_index;
				flag_expected_cross_from_real_red <= 1'b1;
			end else begin
				flag_expected_cross_from_real_red <= 1'b0;
			end
		end
		// CROSS事件正式捕获与握手拍取证/公式核对
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_cross_ready) begin
			reg_cross_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id;
			reg_cross_sample_index <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_sample_index;
			reg_cross_time_unknown <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_time_unknown;
			reg_cross_slope_q16 <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_slope_q16;
			reg_cross_baseline_q16 <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_baseline_q16;
			reg_cross_count <= reg_cross_count + 1;
			$display("CROSS CAPTURE t=%0t frame_id=%0d sample_index=%0d baseline_q16=%0d slope_q16=%0d time_unknown=%0d count=%0d",
				$time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_sample_index,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_baseline_q16,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_slope_q16,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_time_unknown,
				reg_cross_count + 1);
			// Group2检查1：cross载荷必须精确等于candidate_start那一拍锁存的真实RED FIR事务身份（精确类型事件适用）
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_time_unknown) begin
				if(!flag_expected_cross_from_real_red) begin
					$display("FAIL GROUP2_REAL_DATAPATH cross payload not traceable to a real RED FIR handshake at candidate_start t=%0t", $time);
					cnt_error = cnt_error + 1;
				end else if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id !== reg_expected_cross_frame_id) ||
					(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_sample_index !== reg_expected_cross_sample_index)) begin
					$display("FAIL GROUP2_REAL_DATAPATH cross payload frame_id/sample_index mismatch vs captured real RED handshake reported_frame=%0d expected_frame=%0d reported_sample=%0d expected_sample=%0d",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id,
						reg_expected_cross_frame_id,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_sample_index,
						reg_expected_cross_sample_index);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP2_REAL_DATAPATH cross frame_id=%0d sample_index=%0d traced to a real RED FIR handshake at candidate_start",
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_sample_index);
				end
			end
			// Group1检查3：用捕获的PEAK锚点和CROSS载荷重算B[f]=P[n]+DELTA+S[n]*frame_delta(f,F_P[n])，核对o_cross_baseline_q16
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_time_unknown && (reg_peak_count > 0)) begin
				frame_delta_unsigned = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id - reg_peak_frame_id; // 与RTL dec_result_frame_delta一致的16-bit模差算法
				frame_delta_unsigned = frame_delta_unsigned & 32'h0000FFFF;
				peak_value_q16 = {{8{reg_peak_value[23]}}, reg_peak_value, 16'd0}; // 与RTL dec_peak_value_q16构造方式一致：24-bit波峰码值扩展为Q16
				delta_q16_extended = {{16{C_BASELINE_DELTA_Q16[31]}}, C_BASELINE_DELTA_Q16};
				slope_product_wide = $signed(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_slope_q16) * $signed({1'b0, frame_delta_unsigned[15:0]});
				expected_baseline_q16 = peak_value_q16 + delta_q16_extended + slope_product_wide[47:0];
				if(expected_baseline_q16 !== ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_baseline_q16) begin
					$display("FAIL GROUP1_BASELINE_FORMULA recomputed B[f] mismatch expected=%0d rtl_reported=%0d peak_value=%0d peak_frame=%0d cross_frame=%0d frame_delta=%0d slope=%0d",
						expected_baseline_q16,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_baseline_q16,
						reg_peak_value, reg_peak_frame_id,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id,
						frame_delta_unsigned,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_slope_q16);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP1_BASELINE_FORMULA recomputed B[f]=%0d matches RTL o_cross_baseline_q16 peak_value=%0d peak_frame=%0d cross_frame=%0d frame_delta=%0d slope=%0d",
						expected_baseline_q16, reg_peak_value, reg_peak_frame_id,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id,
						frame_delta_unsigned,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_slope_q16);
				end
			end
			// 检查A（应用于首个CROSS事件）：事件握手拍同步采样调度器活值frame_id
			if(!flag_first_cross_captured) begin
				flag_first_cross_captured <= 1'b1;
				this_cross_frame_id_signed = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_cross_frame_id;
				this_live_frame_id = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_current_frame_id;
				reg_live_frame_id_at_first_cross <= this_live_frame_id;
				if((this_live_frame_id - this_cross_frame_id_signed) < C_FIR_GROUP_DELAY_SAMPLES) begin
					$display("FAIL GROUP2_BSL04_CHECK_A first CROSS frame_id not group-delay-tagged live_frame_id=%0d cross_frame_id=%0d diff=%0d need>=%0d",
						this_live_frame_id, this_cross_frame_id_signed, this_live_frame_id - this_cross_frame_id_signed, C_FIR_GROUP_DELAY_SAMPLES);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP2_BSL04_CHECK_A first CROSS live_frame_id=%0d cross_frame_id=%0d diff=%0d >= %0d",
						this_live_frame_id, this_cross_frame_id_signed, this_live_frame_id - this_cross_frame_id_signed, C_FIR_GROUP_DELAY_SAMPLES);
				end
			end
		end
	end

	//---------------Group1检查2：IR事务前后RED运行态逐位不变进程---------------//
	always @(posedge i_clk) begin : ir_invariance_block
		if(flag_ir_check_pending) begin
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_baseline_valid !== reg_ir_pre_baseline_valid) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_slope_current_q16 !== reg_ir_pre_slope_current_q16) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_slope_base_q16 !== reg_ir_pre_slope_base_q16) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_no_cross_count !== reg_ir_pre_no_cross_count) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_reacquire_active !== reg_ir_pre_reacquire_active)) begin
				$display("FAIL GROUP1_IR_INVARIANCE RED running state changed across an IR transaction t=%0t", $time);
				cnt_error = cnt_error + 1;
			end
			flag_ir_check_pending <= 1'b0;
		end
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_result_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_result_ready &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_color_ir) begin
			reg_ir_pre_baseline_valid <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_baseline_valid;
			reg_ir_pre_slope_current_q16 <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_slope_current_q16;
			reg_ir_pre_slope_base_q16 <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_slope_base_q16;
			reg_ir_pre_no_cross_count <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_no_cross_count;
			reg_ir_pre_reacquire_active <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_reacquire_active;
			flag_ir_check_pending <= 1'b1;
		end
	end

	//---------------Group2检查2安全门控信号逐拍锁存进程---------------//
	// 每拍无条件采样，供下面的取证进程在观察到延迟一拍的o_fine_window_start_event
	// 寄存器脉冲时，回看真正做出提交判决那一拍（flag_enter_commit所在拍）的门控快照
	always @(posedge i_clk) begin
		reg_prev_frame_safe_boundary <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.i_frame_safe_boundary;
		reg_prev_precision_takeover_safe <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.i_precision_takeover_safe;
		reg_prev_analog_safe <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.i_analog_safe;
		reg_prev_adc_physical_idle <= i_adc_physical_idle;
	end

	//---------------正式结果最近快照跟踪进程（供Group2检查3使用）---------------//
	always @(posedge i_clk) begin
		if(!i_rstn) begin
			flag_last_result_valid <= 1'b0;
			flag_last_red_result_valid <= 1'b0;
			flag_awaiting_posttransition_any <= 1'b0;
			flag_awaiting_posttransition_red <= 1'b0;
		end else if(o_measurement_result_valid && i_measurement_result_ready) begin
			// Group2检查3a：切换后紧邻的下一笔结果，sample_index必须严格连续+1
			if(flag_awaiting_posttransition_any) begin
				if(o_result_sample_index !== (reg_pretransition_sample_index + {{(C_SAMPLE_INDEX_WIDTH - 1){1'b0}}, 1'b1})) begin
					$display("FAIL GROUP2_SAMPLE_CONTINUITY sample_index not continuous across SAR9->SAR15 transition pretransition=%0d posttransition=%0d",
						reg_pretransition_sample_index, o_result_sample_index);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP2_SAMPLE_CONTINUITY sample_index continuous across transition pretransition=%0d posttransition=%0d",
						reg_pretransition_sample_index, o_result_sample_index);
				end
				flag_awaiting_posttransition_any <= 1'b0;
			end
			// Group2检查3b：切换后紧邻的下一笔同色（RED）结果，AMB/DC码快照+提交版本必须保持不变
			if(flag_awaiting_posttransition_red && (o_result_color_ir == 1'b0)) begin
				if((o_result_amb_code_snapshot !== reg_pretransition_amb_code_snapshot) ||
					(o_result_amb_code_epoch !== reg_pretransition_amb_code_epoch) ||
					(o_result_dc_code_snapshot !== reg_pretransition_dc_code_snapshot) ||
					(o_result_dc_code_epoch !== reg_pretransition_dc_code_epoch)) begin
					$display("FAIL GROUP2_CODE_SNAPSHOT_STABILITY AMB/DC snapshot or epoch changed across SAR9->SAR15 transition pre_amb=%0d post_amb=%0d pre_amb_epoch=%0d post_amb_epoch=%0d pre_dc=%0d post_dc=%0d pre_dc_epoch=%0d post_dc_epoch=%0d",
						reg_pretransition_amb_code_snapshot, o_result_amb_code_snapshot,
						reg_pretransition_amb_code_epoch, o_result_amb_code_epoch,
						reg_pretransition_dc_code_snapshot, o_result_dc_code_snapshot,
						reg_pretransition_dc_code_epoch, o_result_dc_code_epoch);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP2_CODE_SNAPSHOT_STABILITY AMB/DC snapshot+epoch unchanged across transition amb_snapshot=%0d amb_epoch=%0d dc_snapshot=%0d dc_epoch=%0d",
						o_result_amb_code_snapshot, o_result_amb_code_epoch, o_result_dc_code_snapshot, o_result_dc_code_epoch);
				end
				flag_awaiting_posttransition_red <= 1'b0;
			end
			reg_last_result_sample_index <= o_result_sample_index;
			reg_last_result_amb_code_snapshot <= o_result_amb_code_snapshot;
			reg_last_result_amb_code_epoch <= o_result_amb_code_epoch;
			reg_last_result_dc_code_snapshot <= o_result_dc_code_snapshot;
			reg_last_result_dc_code_epoch <= o_result_dc_code_epoch;
			reg_last_result_color_ir <= o_result_color_ir;
			flag_last_result_valid <= 1'b1;
			if(o_result_color_ir == 1'b0) begin
				reg_last_red_result_amb_code_snapshot <= o_result_amb_code_snapshot;
				reg_last_red_result_amb_code_epoch <= o_result_amb_code_epoch;
				reg_last_red_result_dc_code_snapshot <= o_result_dc_code_snapshot;
				reg_last_red_result_dc_code_epoch <= o_result_dc_code_epoch;
				flag_last_red_result_valid <= 1'b1;
			end
		end
	end

	//---------------Group2检查2：SAR9->SAR15安全切换取证进程---------------//
	// 路径口径：ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.
	// ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst；
	// 只对第一次SAR9->SAR15切换取证，与C_TARGET_RED_SAMPLES=700覆盖的单轮周期对齐
	always @(posedge i_clk) begin
		if(!i_rstn) begin
			flag_group2_transition_checked <= 1'b0;
		end else if(!flag_group2_transition_checked &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.o_fine_window_start_event) begin
			flag_group2_transition_checked <= 1'b1;
			reg_sar15_entry_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.o_fine_window_start_frame_id; // Group3检查2下界证据，锁存避免后续依赖易变的活值线
			$display("SAR15_TRANSITION CAPTURE t=%0t safe_frame_id=%0d", $time,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.o_fine_window_start_frame_id);
			// Group2检查2：提交只能发生在真实安全边界，绝不能抢占在途转换——同时核对RTL内部三个门控信号
			// 和TB自己驱动的物理ADC忙闲状态两类独立证据。o_fine_window_start_event是
			// fine_window_start_event_o寄存器输出，比真正做出判决的flag_enter_commit晚一拍，
			// 而i_frame_safe_boundary是逐帧单拍脉冲，到寄存器脉冲出现这一拍往往已经撤销，
			// 所以这里核对的是上一拍（判决真正发生那一拍）锁存的门控快照，不是当前拍的
			// 瞬时值——这是iverilog小规模验证阶段真实发现并修复过的一个TB自身时序对齐bug
			if(!(reg_prev_frame_safe_boundary && reg_prev_precision_takeover_safe && reg_prev_analog_safe)) begin
				$display("FAIL GROUP2_SAFE_BOUNDARY fine_window_start_event committed without all three safe-boundary gates asserted at the actual commit cycle t=%0t", $time);
				cnt_error = cnt_error + 1;
			end else if(reg_prev_adc_physical_idle !== 1'b1) begin
				$display("FAIL GROUP2_SAFE_BOUNDARY fine_window_start_event committed while TB-driven physical ADC bus mid-transaction at the actual commit cycle t=%0t", $time);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS GROUP2_SAFE_BOUNDARY fine_window_start_event committed only with frame_safe_boundary+precision_takeover_safe+analog_safe asserted and physical ADC idle at the actual commit cycle");
			end
			// 为检查3准备切换前快照：sample_index连续性看"最近一笔任意颜色结果"，
			// AMB/DC快照+epoch稳定性看"最近一笔RED结果"——dcs_r_manual_code(80)和
			// dcs_ir_manual_code(96)本场景配置里逐色独立，混色比较会把颜色交替误判成
			// 码值变化，这也是iverilog小规模验证阶段真实发现并修复过的一个TB自身bug
			if(flag_last_result_valid) begin
				reg_pretransition_sample_index <= reg_last_result_sample_index;
				flag_awaiting_posttransition_any <= 1'b1;
			end
			if(flag_last_red_result_valid) begin
				reg_pretransition_amb_code_snapshot <= reg_last_red_result_amb_code_snapshot;
				reg_pretransition_amb_code_epoch <= reg_last_red_result_amb_code_epoch;
				reg_pretransition_dc_code_snapshot <= reg_last_red_result_dc_code_snapshot;
				reg_pretransition_dc_code_epoch <= reg_last_red_result_dc_code_epoch;
				flag_awaiting_posttransition_red <= 1'b1;
			end
		end
	end

	//---------------Group3检查4：SAR15->SAR9安全返回取证进程---------------//
	// 完全镜像Group2检查2入场侧的做法：AMI层转发的o_active_precision_mode是电平信号，
	// 真正做返回判决的flag_return_commit和入场侧flag_enter_commit结构对称（同样门控
	// i_frame_safe_boundary&&i_precision_takeover_safe&&i_analog_safe），但
	// ami_active_precision_mode_o寄存器输出比判决拍晚一拍，所以核对上一拍锁存的门控
	// 快照，不是下降沿这一拍的瞬时值——直接复用Group2已经验证过的这个时序对齐结论，
	// 不重新踩坑。只对第一次SAR15->SAR9返回取证，本文件C_TARGET_RED_SAMPLES延长到
	// 900是为了在此之后继续观察Group4自己的尾部隔离窗口和第二次CROSS
	always @(posedge i_clk) begin
		if(!i_rstn) begin
			flag_group3_return_commit_checked <= 1'b0;
		end else if(!flag_group3_return_commit_checked && flag_group2_transition_checked &&
			(reg_prev_active_precision_mode == 1'b1) && (ppg_control_top_Inst.ami_active_precision_mode_o == 1'b0)) begin
			flag_group3_return_commit_checked <= 1'b1;
			$display("SAR9_RETURN_TRANSITION CAPTURE t=%0t", $time);
			if(!(reg_prev_frame_safe_boundary && reg_prev_precision_takeover_safe && reg_prev_analog_safe)) begin
				$display("FAIL GROUP3_SAFE_RETURN_COMMIT SAR15->SAR9 return committed without all three safe-boundary gates asserted at the actual commit cycle t=%0t", $time);
				cnt_error = cnt_error + 1;
			end else if(reg_prev_adc_physical_idle !== 1'b1) begin
				$display("FAIL GROUP3_SAFE_RETURN_COMMIT SAR15->SAR9 return committed while TB-driven physical ADC bus mid-transaction at the actual commit cycle t=%0t", $time);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS GROUP3_SAFE_RETURN_COMMIT SAR15->SAR9 return committed only with frame_safe_boundary+precision_takeover_safe+analog_safe asserted and physical ADC idle at the actual commit cycle");
			end
		end
	end

	//---------------Group4：FIR精度尾部隔离监视进程---------------//
	// 路径口径：ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.
	// ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst。
	// 只监视第一次真实返回（flag_group3_return_commit_checked置位）之后到尾部结束
	// 为止的窗口。检查1（尾部真实存在且有界）、检查2（尾部不能武装/启动候选）、
	// 检查3（尾部结束后首笔合格样本只武装参考、不能单独形成候选）全部锚定在
	// CROSS检测器自己端口上的真实握手和内部状态回读，不是推断。检查4（系统真实
	// 恢复、第二次CROSS由真实重建证据形成）不需要额外新代码——GROUP2_REAL_DATAPATH
	// 和GROUP1_BASELINE_FORMULA两条检查已经在cross_detector_monitor_block里对
	// 每一次真实CROSS事件（不只是第一次）重新执行，第二次CROSS到来时会自动重新
	// 验证一遍，本文件只需要在存在性断言里额外要求reg_cross_count>=2
	always @(posedge i_clk) begin : fir_tail_isolation_block
		reg this_red_handshake;
		reg this_precision_mode;
		if(!i_rstn) begin
			flag_tail_window_active <= 1'b0;
			flag_tail_observed <= 1'b0;
			flag_tail_ended <= 1'b0;
			cnt_tail_red_handshakes <= 8'd0;
			flag_tail_check_pending <= 1'b0;
			flag_rebuild_check_pending <= 1'b0;
			flag_first_eligible_post_tail_captured <= 1'b0;
		end else begin
			this_red_handshake = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_result_valid &&
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_result_ready &&
				!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_color_ir;
			this_precision_mode = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_precision_mode;

			// 检查2实际核验：上一拍是尾部握手，这一拍核对武装状态确实已经清零
			if(flag_tail_check_pending) begin
				flag_tail_check_pending <= 1'b0;
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.flag_below_seen ||
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.flag_previous_valid) begin
					$display("FAIL GROUP4_TAIL_CANNOT_ARM a tail (precision_mode=1) RED handshake left flag_below_seen or flag_previous_valid armed t=%0t", $time);
					cnt_error = cnt_error + 1;
				end
			end
			// 检查3实际核验：上一拍是尾部结束后首笔合格握手，这一拍核对只武装了参考
			if(flag_rebuild_check_pending) begin
				flag_rebuild_check_pending <= 1'b0;
				if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.flag_previous_valid) begin
					$display("FAIL GROUP4_REBUILD_EVIDENCE first genuinely-eligible post-tail RED handshake did not arm flag_previous_valid frame_id=%0d",
						reg_first_eligible_post_tail_frame_id);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS GROUP4_REBUILD_EVIDENCE first genuinely-eligible post-tail RED handshake frame_id=%0d correctly armed flag_previous_valid as reference-only",
						reg_first_eligible_post_tail_frame_id);
				end
			end
			// 尾部窗口内任何一拍都不能触发新候选起点，连续核对，不等到下一拍
			if(flag_tail_window_active &&
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.flag_candidate_start) begin
				$display("FAIL GROUP4_TAIL_CANNOT_ARM flag_candidate_start fired while still inside the precision-tail window t=%0t", $time);
				cnt_error = cnt_error + 1;
			end

			// 尾部窗口起点：第一次真实返回提交之后立即开始监视，只处理一次
			if(flag_group3_return_commit_checked && !flag_tail_window_active && !flag_tail_ended) begin
				flag_tail_window_active <= 1'b1;
			end

			if(flag_tail_window_active && this_red_handshake) begin
				if(this_precision_mode) begin
					// 真实尾部握手：存在性+有界性证据
					flag_tail_observed <= 1'b1;
					cnt_tail_red_handshakes <= cnt_tail_red_handshakes + 8'd1;
					flag_tail_check_pending <= 1'b1;
					if(cnt_tail_red_handshakes >= C_FIR_GROUP_DELAY_SAMPLES) begin
						$display("FAIL GROUP4_TAIL_BOUNDED tail exceeded C_FIR_GROUP_DELAY_SAMPLES(%0d) precision_mode=1 RED handshakes without returning to precision_mode=0",
							C_FIR_GROUP_DELAY_SAMPLES);
						cnt_error = cnt_error + 1;
					end
				end else begin
					// 尾部结束：这是第一笔真正合格的RED握手
					flag_tail_window_active <= 1'b0;
					flag_tail_ended <= 1'b1;
					$display("PASS GROUP4_TAIL_BOUNDED tail observed=%0d ended after %0d precision_mode=1 RED handshakes (<=%0d), first eligible frame_id=%0d",
						flag_tail_observed, cnt_tail_red_handshakes, C_FIR_GROUP_DELAY_SAMPLES,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_frame_id);
					if(!flag_first_eligible_post_tail_captured) begin
						flag_first_eligible_post_tail_captured <= 1'b1;
						reg_first_eligible_post_tail_frame_id <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.i_frame_id;
						flag_rebuild_check_pending <= 1'b1;
					end
				end
			end
		end
	end

	//---------------全局看门狗进程---------------//
	// 12秒watchdog，相对仿真起点，time类型，覆盖复位+START+measurement+排空+
	// 终止检查的全部预算；不是10秒measurement窗口本身的一部分
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL FIR_TAIL_ISOLATION global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	initial begin
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		reg_measurement_start_time = 0;
		// Group 1/2事件捕获与断言状态的显式初始化：integer/reg在Verilog中默认是X，
		// 靠隐式0初始化的假设会让`if(!flag_xxx)`这类判断在X上被当成false直接跳过，
		// 这是本文件编写时真实踩到的一个bug（iverilog小规模跑通阶段发现Check A/B
		// 从未执行），必须在这里显式清零，不能依赖复位或默认值
		reg_peak_count = 0;
		reg_valley_count = 0;
		reg_cross_count = 0;
		reg_return_count = 0;
		flag_baseline_ever_valid = 1'b0;
		flag_expected_cross_from_real_red = 1'b0;
		flag_first_peak_captured = 1'b0;
		flag_first_cross_captured = 1'b0;
		flag_ir_check_pending = 1'b0;
		flag_last_result_valid = 1'b0;
		flag_awaiting_posttransition_any = 1'b0;
		flag_awaiting_posttransition_red = 1'b0;
		flag_group2_transition_checked = 1'b0;
		flag_last_red_result_valid = 1'b0;
		reg_prev_frame_safe_boundary = 1'b0;
		reg_prev_precision_takeover_safe = 1'b0;
		reg_prev_analog_safe = 1'b0;
		reg_prev_adc_physical_idle = 1'b0;
		flag_sar15_active = 1'b0;
		flag_first_peak_in_sar15_captured = 1'b0;
		flag_first_valley_in_sar15_captured = 1'b0;
		flag_last_real_red_sar15_frame_id_valid = 1'b0;
		flag_group3_return_commit_checked = 1'b0;
		reg_prev_active_precision_mode = 1'b0;
		flag_tail_window_active = 1'b0;
		flag_tail_observed = 1'b0;
		flag_tail_ended = 1'b0;
		cnt_tail_red_handshakes = 8'd0;
		flag_tail_check_pending = 1'b0;
		flag_rebuild_check_pending = 1'b0;
		flag_first_eligible_post_tail_captured = 1'b0;
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

		// C25合同9.1/10.1节+PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md第11节：独立复位后
		// 必须先完整跑通JNT-01~09（52个子检查全部PASS）才能启动本组场景；task内部
		// 自带独立复位/配置/START子序列，结束时会做一次干净复位把DUT交还给下面的
		// 本组场景起手式，不需要额外处理
		run_jnt_baseline_01_09;

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

		// 事件驱动主循环：完全依赖bg_responder的真实响应和上面各专用捕获/断言
		// 进程，主序列本身只负责等待覆盖窗口跑完，不重复任何判定逻辑
		while((cnt_red_response < C_TARGET_RED_SAMPLES) && !flag_global_timeout) begin
			@(posedge i_clk);
		end
		if(flag_global_timeout) begin
			$display("FAIL FIR_TAIL_ISOLATION global watchdog fired before target red sample count reached red=%0d", cnt_red_response);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS FIR_TAIL_ISOLATION main sequence reached target red=%0d within watchdog budget", cnt_red_response);
		end

		// 存在性断言：Group 1/2的全部逐拍检查只在对应事件真实出现时才会执行，
		// 必须额外确认这些事件确实发生过，避免配置或生成器退化导致断言整体
		// vacuous pass（例如o_calibrated_s1_value又恒0导致零事件却全程无FAIL）
		if(!flag_baseline_ever_valid) begin
			$display("FAIL GROUP1_EXISTENCE o_baseline_valid never asserted during the whole run, history-insufficient check is vacuous");
			cnt_error = cnt_error + 1;
		end else if(reg_peak_count < 2) begin
			$display("FAIL GROUP1_EXISTENCE fewer than 2 real PEAK events captured (count=%0d), warmup cycle not exercised", reg_peak_count);
			cnt_error = cnt_error + 1;
		end else if(reg_valley_count < 2) begin
			$display("FAIL GROUP1_EXISTENCE fewer than 2 real VALLEY events captured (count=%0d), warmup cycle not exercised", reg_valley_count);
			cnt_error = cnt_error + 1;
		end else if(!flag_first_peak_captured) begin
			$display("FAIL GROUP1_EXISTENCE first-PEAK group-delay checks A/B never ran");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP1_EXISTENCE real PEAK/VALLEY warmup cycle observed peak_count=%0d valley_count=%0d", reg_peak_count, reg_valley_count);
		end
		if(reg_cross_count < 1) begin
			$display("FAIL GROUP2_EXISTENCE no real CROSS event captured, Group2 SAR15-entry checks are vacuous");
			cnt_error = cnt_error + 1;
		end else if(!flag_first_cross_captured) begin
			$display("FAIL GROUP2_EXISTENCE first-CROSS group-delay check A never ran");
			cnt_error = cnt_error + 1;
		end else if(!flag_group2_transition_checked) begin
			$display("FAIL GROUP2_EXISTENCE no real SAR9->SAR15 fine_window_start_event observed, safe-boundary/continuity checks are vacuous");
			cnt_error = cnt_error + 1;
		end else if(reg_return_count < 1) begin
			$display("FAIL GROUP2_EXISTENCE no real RETURN_9BIT event captured, SAR15->SAR9 round trip not exercised");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP2_EXISTENCE real CROSS/SAR15-entry/RETURN_9BIT cycle observed cross_count=%0d return_count=%0d", reg_cross_count, reg_return_count);
		end

		// Group3存在性断言：确认四条新增检查确实都真实执行过，不是因为SAR15阶段没有
		// 真实PEAK/VALLEY/RETURN事件而全程静默跳过
		if(!flag_first_peak_in_sar15_captured) begin
			$display("FAIL GROUP3_EXISTENCE no real PEAK captured after SAR15 entry, group3 peak-side checks are vacuous");
			cnt_error = cnt_error + 1;
		end else if(!flag_first_valley_in_sar15_captured) begin
			$display("FAIL GROUP3_EXISTENCE no real VALLEY captured after SAR15 entry, group3 valley-side/return checks are vacuous");
			cnt_error = cnt_error + 1;
		end else if(!flag_group3_return_commit_checked) begin
			$display("FAIL GROUP3_EXISTENCE no real SAR15->SAR9 return transition observed, safe-return-commit check is vacuous");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP3_EXISTENCE real SAR15-phase PEAK(frame_id=%0d)/VALLEY(frame_id=%0d)/safe-return cycle observed",
				reg_first_peak_in_sar15_frame_id, reg_first_valley_in_sar15_frame_id);
		end

		// Group4存在性断言：确认尾部场景真实被触发过、检查2/3真实执行过、且系统
		// 真实恢复形成了第二次CROSS（不只是消极地没有过早误触发）
		if(!flag_tail_observed) begin
			$display("FAIL GROUP4_EXISTENCE no real precision_mode=1 tail RED handshake observed after the return, tail-bounded/cannot-arm checks are vacuous");
			cnt_error = cnt_error + 1;
		end else if(!flag_tail_ended) begin
			$display("FAIL GROUP4_EXISTENCE precision tail never ended within the run budget, rebuild-evidence check is vacuous");
			cnt_error = cnt_error + 1;
		end else if(!flag_first_eligible_post_tail_captured) begin
			$display("FAIL GROUP4_EXISTENCE no genuinely-eligible post-tail RED handshake captured, rebuild-evidence check is vacuous");
			cnt_error = cnt_error + 1;
		end else if(reg_cross_count < 2) begin
			$display("FAIL GROUP4_EXISTENCE fewer than 2 real CROSS events captured (count=%0d), system recovery into a second crossing not demonstrated", reg_cross_count);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP4_EXISTENCE real precision tail observed, bounded, ended at frame_id=%0d, and system recovered to form cross_count=%0d real crossings",
				reg_first_eligible_post_tail_frame_id, reg_cross_count);
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
					$display("FAIL FIR_TAIL_ISOLATION stop ack timeout");
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
					$display("FAIL FIR_TAIL_ISOLATION drain back to CONFIG timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL FIR_TAIL_ISOLATION unexpected system fault blocking after STOP");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS FIR_TAIL_ISOLATION STOP drained back to CONFIG without fault");
		end

		// 全程协议错误sticky核查：这些信号从Phase 1的tb_ppg_control_top.v到Stage 3长跑
		// 一直只是接了线，从未被真正断言过——本轮真实生成器驱动的事务是迄今唯一一次在
		// 真实连续算法层激励下核对这批sticky的机会。sticky语义是"一旦置位保持到诊断
		// 清除或复位"，所以在STOP排空之后读一次末值，等价于核实了整个测量窗口内的历史，
		// 不需要逐拍监视。
		// 第一次真实跑就在这里抓到`o_ssw_owner_deadline_timeout_sticky`真实置位过——
		// 查证后确认这不是缺陷：PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_
		// CONTRACT.md第597/614节和PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_
		// CONTRACT.md第981节都明文把launch_timeout_sticky/owner_deadline_timeout_sticky
		// （scheduler和SSW两侧）以及SSW的calibration_timeout_sticky定义成"历史诊断，
		// 不单独永久拉高fault_blocking、不产生supervisor fault record"——它们和真正的
		// protocol_error_sticky/completion_mismatch_sticky/transaction_mismatch_sticky
		// 不是同一类信号，后者才是合同定义的阻断项，必须全程保持0；前者只做观测记录，
		// 不计入cnt_error（这个分类是从Group1/2那份文件里同一次真实发现后确认的结论，
		// 本文件直接复用，不重新推导）
		if(o_error_sticky) begin
			$display("FAIL GROUP4_PROTOCOL_STICKY o_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_scheduler_completion_mismatch_sticky) begin
			$display("FAIL GROUP4_PROTOCOL_STICKY o_scheduler_completion_mismatch_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_scheduler_protocol_error_sticky) begin
			$display("FAIL GROUP4_PROTOCOL_STICKY o_scheduler_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ami_integration_protocol_error_sticky) begin
			$display("FAIL GROUP4_PROTOCOL_STICKY o_ami_integration_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ssw_switch_protocol_error_sticky) begin
			$display("FAIL GROUP4_PROTOCOL_STICKY o_ssw_switch_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ssw_transaction_mismatch_sticky) begin
			$display("FAIL GROUP4_PROTOCOL_STICKY o_ssw_transaction_mismatch_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_characterization_protocol_error_sticky) begin
			$display("FAIL GROUP4_PROTOCOL_STICKY o_characterization_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_result_discard_summary_sticky) begin
			$display("FAIL GROUP4_PROTOCOL_STICKY o_result_discard_summary_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP4_PROTOCOL_STICKY all blocking scheduler/AMI/SSW/characterization/discard protocol-error stickies stayed 0 across real_red=%0d real_ir=%0d transactions",
				cnt_red_response, cnt_ir_response);
		end
		// 非阻断历史诊断类sticky：只记录观测结果，不计入cnt_error，理由见上方大注释
		if(o_scheduler_launch_timeout_sticky) begin
			$display("INFO GROUP4_HISTORICAL_DIAG o_scheduler_launch_timeout_sticky asserted during the run (non-blocking per contract)");
		end
		if(o_scheduler_owner_deadline_timeout_sticky) begin
			$display("INFO GROUP4_HISTORICAL_DIAG o_scheduler_owner_deadline_timeout_sticky asserted during the run (non-blocking per contract)");
		end
		if(o_ssw_owner_deadline_timeout_sticky) begin
			$display("INFO GROUP4_HISTORICAL_DIAG o_ssw_owner_deadline_timeout_sticky asserted during the run (non-blocking per contract)");
		end
		if(o_ssw_calibration_timeout_sticky) begin
			$display("INFO GROUP4_HISTORICAL_DIAG o_ssw_calibration_timeout_sticky asserted during the run (non-blocking per contract)");
		end

		// 汇总并干净退出
		if(cnt_error == 0) begin
			$display("FIR_TAIL_ISOLATION_TB_PASS real_red=%0d real_ir=%0d real_cal=%0d measurement_result_valid=%0d peak_count=%0d valley_count=%0d cross_count=%0d return_count=%0d first_sar15_peak_frame=%0d first_sar15_valley_frame=%0d",
				cnt_red_response, cnt_ir_response, cnt_cal_response, cnt_measurement_result_valid,
				reg_peak_count, reg_valley_count, reg_cross_count, reg_return_count,
				reg_first_peak_in_sar15_frame_id, reg_first_valley_in_sar15_frame_id);
		end else begin
			$display("FIR_TAIL_ISOLATION_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
