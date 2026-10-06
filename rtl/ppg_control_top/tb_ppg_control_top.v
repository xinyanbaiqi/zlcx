`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/23
// Design Name:        PPG Digital System Top Smoke Testbench
// Module Name:        tb_ppg_control_top
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.8
// Revision Date:      2026/10/06
// History:
//    Time               Version       Revised by            Contents
// 2026/08/23            V1.0          Erie                  Create file. TB-SMOKE-01 minimal smoke test: reset, legal NORMAL MANUAL-IDAC COMMIT, START, respond to several real Q3-gated ADC transactions through the public physical RAW/CLK_DOUT boundary, STOP, and a clean $finish with no X observed on key outputs. This is the first real functional simulation of ppg_control_top; it is scoped as a smoke test only, not TOP-01~24 coverage.
// 2026/08/24            V1.1          Erie                  Extend SMOKE-01~05 to SMOKE-01~20 with real simulation evidence for TOP-01/02/09 baseline plus TOP-04/05/06(protocol slice)/07/08/09/12/13/14/15/16/17/18/19 of the C01 acceptance matrix, plus three targeted scenarios that led to finding and fixing a real AMI STOP-discard defect (ppg_adc_measurement_idac_integration.v V1.11). Also fixed three real defects discovered inside this TB itself while extending coverage, none in DUT RTL: (1) wait_q3_release's internal 5600-cycle timeout was silently treated as a genuine release, so bg_responder fabricated a response roughly every 5600 cycles even when no Q3 window ever legitimately opened (e.g. CONFIG/STATIC_BIAS), inflating every response count reported by this TB since V1.0; the task now reports whether it saw a real release and bg_responder gates on that. (2) bg_responder classified RED/IR/calibration responses from SSW's transient waveform-context valid flags sampled at Q3-release time, which misclassifies a RED response as IR once dual-optical mode's IR context has already gone valid; switched to the scheduler's own commit-time-latched B_INFLIGHT_COLOR/B_INFLIGHT_TYPE bits. (3) drive_real_adc_done's precision_mode argument was hardcoded to SAR9 regardless of the real committed precision, so AMI's async capture module (which waits on the stage2 done pulse specifically for SAR15) could never accept a SAR15 completion; now sampled per response. Also corrected a mislabeled comment: the MANUAL config task's optical_mode field was commented as dual-optical but is actually OPTICAL_IR (2'b10) per the scheduler's own encoding, so SMOKE-01~11 have always exercised IR-only, not dual-optical; added a separate real dual-optical config task for scenarios that need it (TOP-15, TOP-05). TOP-06's dynamic switch-triggered half ("旧15-bit尾部不启动新事务") needs a real physiologically-shaped waveform to trigger baseline-crossing precision switching and is deferred to the Phase 3 real-PPG-waveform-generator work. All 21 scenario groups pass with real simulation evidence.
// 2026/08/24            V1.2          Erie                  Add SMOKE-21/22 for TOP-20 (calibration responsibility boundary): SMOKE-21 runs a full CHARACTERIZATION+EXTERNAL_TEST_CURRENT RUN (real RED/IR transactions keep happening) while confirming AMI's o_calibration_sample_valid stays 0 throughout, evidencing AMI's structural source-side gate (flag_normal_start_search_qualified requires run_profile==NORMAL); SMOKE-22 attempts an illegal NORMAL_PPG+SAR15 COMMIT and confirms manager's static rejection (error=8'h10 per MGR-16/18), which also forecloses any legal path to a real SAR15 calibration request (AMI additionally hardwires o_calibration_precision_mode=1'b0 always). Two real environment interactions surfaced while building these: (a) SMOKE-19's static_characterization_enable=1 commit is sticky across scenarios (only clears via an explicit CDC commit, not by returning to CONFIG or the next V4 COMMIT), so SMOKE-21 now explicitly clears it first via a new task_clear_static_bias_characterization task, otherwise its CHARACTERIZATION+EXTERNAL_TEST_CURRENT config would be silently reinterpreted as STATIC_BIAS; (b) the config manager's error_sticky (set on any illegal operation, contract section 5's start_ready formula) is a real W1C sticky that is NOT cleared by the next legal COMMIT, so SMOKE-20's intentional negative-test rejection left it set and silently blocked SMOKE-21's first START attempt with the generic error 0x0b, requiring an explicit i_diag_clear_event pulse between them -- neither of SMOKE-01~20 needed this because SMOKE-20 was always the last scripted scenario. SMOKE-21's own monitor initially also watched the scheduler's o_calibration_sample_ready and reported a false FAIL; cycle-level tracing showed calibration_sample_ready_o is a pure combinational capacity/readiness level (lifecycle active and not already processing a request) that never references run_profile or input_source, so it is not evidence of an illegal request and was removed from the check. That same trace surfaced a real, more significant finding, independent of any TB bug: the scheduler's receiver-side run_profile/input_source recheck described in both the C01 contract's calibration-responsibility-boundary section and the scheduler contract's section 9.1 formula is not implemented in the current scheduler RTL -- i_run_profile is declared but never referenced anywhere in the module body, and i_input_source is only latched into state_current[B_FRAME_INPUT_SOURCE] and forwarded to SSW's waveform slot for tagging, never used to gate calibration_sample_ready_o or flag_calibration_request_valid (only the SAR9 precision_mode half of that formula is actually implemented). The scheduler contract's own self-check table lists "FSC-17 | calibration request eligibility and buffering" as covering exactly this, but no such case exists in tb_ppg_400hz_frame_calibration_scheduler.v (its real FSC-17 checks an unrelated RED-only owner-commit count) -- this was documentation describing a planned check that was never actually implemented or tested. TOP-20 currently holds only through AMI's single-sided source gate, not the documented AMI+Scheduler two-sided defense; whether to add the missing scheduler-side recheck is a real architectural decision left for the user, not something patched silently here. All 22 scenario groups pass with real simulation evidence; -Wall compile clean (only two pre-existing unrelated warnings from ppg_dynamic_baseline_cross_detector.v, untouched this session).
// 2026/08/24            V1.3          Erie                  Add SMOKE-23 for TOP-03 (NORMAL dual-optical), the last uncovered item in the C01 acceptance matrix -- discovered missing only while writing up the prior handoff document; SMOKE-14 exercises dual-optical but only asserts TOP-15's SAR15-signal persistence, never TOP-03's own four claims. Adds a permanent background monitor (extending the existing owner-commit counter block) that snapshots frame_id/sample_index/precision_mode/macro_tick straight off the scheduler's o_adc_owner_frame_id/o_adc_owner_sample_index/o_adc_owner_precision_mode/macro_tick_o the same cycle o_adc_owner_commit_event fires -- these are held-type outputs valid on that exact edge, so this doesn't depend on bg_responder's Q3-release timing at all. SMOKE-23 captures two full real RED+IR pairs across two macro frames and confirms same frame_id within each pair, consecutive sample_index (IR = RED+1), same committed precision, and Q3 phase fixed across frames (compares pair1 against pair2, not against an assumed tick constant). Two real issues found while first running this against real RTL, neither a false lead: (1) SMOKE-22 is an intentional negative test (illegal NORMAL+SAR15 commit) that leaves the config manager's error_sticky set, silently blocking SMOKE-23's next START the same way it did SMOKE-21's before that fix -- added the same explicit i_diag_clear_event pulse before SMOKE-23. (2) The scenario's baseline (cnt_owner_commit_red/ir snapshot) was originally taken after START plus the usual 8-cycle settle delay, matching every other scenario's convention -- but RED's context takes over at macro tick 0 and its very first owner commits almost immediately after START, while IR's first commit only happens after RED's owner is genuinely released by a real DONE (much later); the 8-cycle settle window was long enough to already include RED's first commit but not IR's, silently shifting the RED delta baseline forward by one real transaction relative to IR's. The observed symptom was the first captured "pair" pairing IR's real frame-0 commit with RED's frame-1 commit instead of frame-0 -- a real frame_id mismatch in the test's own bookkeeping, not the DUT. Fixed by capturing the baseline before task_pulse_start, when no commit can possibly have happened yet. All 23 scenario groups pass with real simulation evidence; per the handoff document's own audit, this closes the last item -- TOP-01 through TOP-24 now all have real simulation or static evidence in this file plus tb_ppg_control_top_injection.v.
// 2026/08/24            V1.4          Erie                  Phase 3 Stage 2: wires the Phase 3 Stage 1 deterministic RAW generator (tb_ppg_real_raw_generator.vh V1.2) into bg_responder, replacing the fixed 256/300 codes that make_fixed_raw previously produced for every NORMAL RED/IR response regardless of color, frame, or precision. Calibration transactions (AMB_CAL/DCS_CAL) are unchanged -- they still use the fixed codes per the generator contract's own section 1 boundary (calibration stays on the existing calibration stimulus model, not the physiological generator). Two things had to be resolved before wiring, both recorded here rather than guessed: (1) read PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md (C14) expecting it to define the Stage1/Stage2 raw-code relationship, but C14 only consumes an already-calibrated Stage1 value and an already-decoded D2_EXT -- the actual raw-code decode lives in ppg_adc_pipeline_overlap_corrector.v, read directly: D1_EXT and D2_EXT are produced by applying the identical vdred redundant-decode formula independently to i_stage1_raw and i_stage2_raw (same formula this TB's own make_fixed_raw already implements the inverse of), then combined with Stage1 taking the dominant nominal weight and Stage2 a small inter-stage overlap-correction weight -- not an integer/fractional coarse-fine split as originally guessed while planning Stage 1. Since both raw codes are independently-decoded samples of the same physical instant, feeding make_fixed_raw the same generator-produced target_code for both stage1_raw and stage2_raw is the representation that matches this real decode structure, not an arbitrary simplification; SAR9 transactions don't care about the stage2 value either way since dec_stage2_raw_qualified masks it to zero whenever i_precision_mode=0. (2) o_adc_owner_frame_id, despite its name and despite being commonly treated in this file as a stable per-owner identity (SMOKE-23's V1.3 background monitor already relied on this), is RTL-confirmed (ppg_400hz_frame_calibration_scheduler.v: o_adc_owner_frame_id = transaction_frame_id_o = current_frame_id_o = state_current[B_FRAME_ID]) to be a live alias of the scheduler's own running macro-frame counter, not a value latched specifically at owner commit -- it is only safe to read while the owner is still genuinely inflight (before drive_real_adc_done lets the real DONE occur and the owner releases), the same timing constraint that already applies to the color/precision fields sampled at this exact point in bg_responder. Frame_id, color, and the calibration/NORMAL branch decision are now all captured together at that one safe point, before flag_hold_next_adc_response's pause can introduce any wait. Full regression with no RTL changed: all 23 SMOKE scenarios re-run and pass (SMOKE_TB_PASS, 47 real ADC responses, 32 measurement results, identical scenario-level assertions to V1.3 since NORMAL's generator profile still produces legal in-window codes); tb_ppg_control_top_injection.v's INJ-00~04 also re-run and pass (INJ_TB_PASS, 14/14) as expected since that file carries its own independent copy of drive_real_adc_done/make_fixed_raw and does not include this generator, so it could not have regressed from this change and this run is a confirmation, not new evidence. `-Wall` compile clean (same two pre-existing unrelated ppg_dynamic_baseline_cross_detector.v warnings as V1.1~V1.3). SAR9/SAR15 NORMAL RED/IR RAW values now vary by real color and real macro-frame number for the first time in this TB's history; no downstream algorithm-level claim (real baseline crossing, real peak/valley detection) is made yet -- that is Phase 3 Stage 3/4 scope.
// 2026/08/26            V1.5          Erie                  Close the stale finding V1.2 left open: ppg_400hz_frame_calibration_scheduler.v was upgraded to V1.7 later the same 2026/08/24 session (not by this TB) to actually wire the receiver-side run_profile/input_source recheck that section 9.1 always specified -- calibration_sample_ready_o is now gated by flag_calibration_request_valid, which requires i_run_profile==RUN_PROFILE_NORMAL && i_input_source==INPUT_SOURCE_PHOTODIODE, with real unit-level coverage in tb_ppg_400hz_frame_calibration_scheduler.v's new FSC-58/59 (re-run this session via a fresh iverilog compile: 59/59 PASS, no stale claim taken on faith). V1.2's comment that "calibration_sample_ready_o is a pure combinational level that never references run_profile or input_source" is therefore no longer accurate for the current RTL and is corrected in place rather than left to mislead a future reader. SMOKE-21's monitor now also samples ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_sample_ready throughout the CHARACTERIZATION+EXTERNAL_TEST_CURRENT run and fails if it is ever observed high -- this is a real, newly-true assertion (it would have failed before scheduler V1.7): the scheduler's own eligibility computation must independently agree that the current run_profile/input_source is not qualified, even though AMI's structural source-side gate means AMI never actually offers it a request to reject in this exact integration scenario (that unreachable-request case is exactly why FSC-58/59 exist as a scheduler-unit-level direct-drive test, and remains the sole authority for the "an illegal request actually arrives and gets rejected" claim -- SMOKE-21 only proves the ready computation itself stays low, not a full request/reject transaction). No RTL changed by this revision. All 23 SMOKE scenarios re-run and pass (SMOKE_TB_PASS, 47 real ADC responses, 32 measurement results, unchanged from V1.4 since this only adds a monitor to an existing scenario).
// 2026年08月26日        V1.5          Erie                  收尾V1.2留下的过期发现：ppg_400hz_frame_calibration_scheduler.v在同一天（2026/08/24）晚些时候已经升级到V1.7（不是本TB做的），把合同9.1节一直写着的接收端run_profile/input_source复核真正接上了线——calibration_sample_ready_o现在由flag_calibration_request_valid把关，要求i_run_profile==RUN_PROFILE_NORMAL且i_input_source==INPUT_SOURCE_PHOTODIODE，真实单元级测试覆盖见tb_ppg_400hz_frame_calibration_scheduler.v新增的FSC-58/59（本轮用新的iverilog编译重新跑过一遍确认：59/59 PASS，没有凭旧记录就当真）。V1.2那条"calibration_sample_ready_o是纯组合电平，从不引用run_profile或input_source"的注释对当前RTL已经不成立，就地订正，不留着误导以后的读者。SMOKE-21的监控现在同时持续采样ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_sample_ready，只要在CHARACTERIZATION+EXTERNAL_TEST_CURRENT全程里观察到它出现过一次高电平就判FAIL——这是一条真实的、此前不成立现在才成立的新断言（scheduler V1.7之前跑这条一定会FAIL）：即使AMI的结构性源端门控意味着这个真实集成场景里AMI根本不会真的递交一笔请求给scheduler拒绝，scheduler自己的资格判断也必须独立认定当前run_profile/input_source不合格（这个"请求根本递不到"的真实空白正是FSC-58/59要作为调度器单元级直接驱动测试存在的原因，"非法请求真的到达并被拒绝"这条claim的权威证据仍然是FSC-58/59，SMOKE-21只证明ready计算本身保持低电平，不是一次完整的请求/拒绝事务）。本次修订未改动任何RTL。全部23个SMOKE场景重跑通过（SMOKE_TB_PASS，47笔真实ADC响应，32笔正式结果，和V1.4完全一致，因为本次只是给已有场景加了一个监控）。
// 2026/09/02            V1.6          Erie                  Priority-1a dedicated acceptance evidence for the two new C01 top-level ports added in V1.3/V1.4 (o_active_precision_mode, o_source_config_update_ready), which previously had zero direct assertion anywhere -- existing background monitors only ever hierarchically probed the internal AMI wire, never the new port itself. Wires both new ports into this file's DUT instantiation for the first time. NPA-01: permanent every-cycle background monitor (same style as the existing TOP-17 fanout check) comparing o_active_precision_mode against the AMI-forwarded internal wire ppg_control_top_Inst.ami_active_precision_mode_o; ran clean across the entire 23-scenario suite including every SAR9<->SAR15 transition, confirming the V1.3 continuous-assignment passthrough is bit-identical with no tearing window. NPA-02: extends SMOKE-02's first real COMMIT into a busy-window rejection test -- confirms o_source_config_update_ready=1 idle-high before the first pulse, confirms it drops to 0 after the pulse (with an explicit vacuousness guard so the test cannot silently pass if busy is never observed), fires a second i_source_config_update_event with a deliberately different config (idac_mode=SEARCH_TRACK vs the real MANUAL) while still busy, then relies on SMOKE-02's own o_config_epoch==1 check to prove the second pulse was silently dropped per ppg_config_cdc_bridge.v's busy-latch semantics (lines 127/138: source domain neither re-latches nor re-toggles while flag_source_busy=1), not merged or queued as a real second commit. One real methodology bug found and fixed in this TB while first constructing NPA-02, not a DUT defect: initially asserted o_source_config_update_ready returns to 1 the same cycle o_commit_ack_event fires; real iverilog evidence showed FAIL immediately -- o_commit_ack_event only reflects the destination-domain config manager accepting config_transport_update_o, while o_source_config_update_ready additionally needs that acceptance to propagate back through ppg_config_cdc_bridge.v's flag_ack_sync_meta/flag_ack_sync two-flop synchronizer into the source domain, a strictly later, independent event -- fixed by replacing the same-cycle check with a bounded 64-source_clk-cycle poll (matches this file's own task_wait_config_result convention); re-run confirmed ready returns after exactly 1 source_clk cycle. Both new checks pass with real dual-tool evidence (iverilog -Wall clean compile plus full run, and Vivado 2022.2 xsim full elaboration plus run, both zero FAIL); the pre-existing SMOKE_TB_PASS baseline (all 23 scenarios, 47 real ADC responses, 32 measurement results) is unchanged from V1.5, confirming zero regression from this addition. No RTL changed.
// 2026/09/17            V1.7          Erie                  Work-line-D remediation of the 5 confirmed TOP-01/02/09/15/18 gaps (no RTL change; investigation-driven, several false starts corrected against real simulation evidence rather than assumed). TOP-01: SMOKE-01 gains a real o_s_in==5'b00000 check (RTL:604 already carried an unverified @satisfies:TOP-01 tag); a new standalone scenario at file end drives a real in-flight owner then resets mid-transaction, confirming state fully clears and the result counter does not silently advance, then confirms a fresh commit+start genuinely produces a new result. TOP-02: a new negative scenario between SMOKE-05 and SMOKE-06 corrupts only the V5 reserved field (contract-legal V4 fields untouched) and confirms the whole 1024-bit snapshot is atomically rejected with config_epoch unchanged; a diag_clear pulse was added afterward since the config manager's error_sticky is W1C and would have silently blocked SMOKE-06's next legitimate commit otherwise. TOP-09: a new standalone scenario (not reusing SMOKE-06's early-STOP window, which real simulation proved has zero pending measurement result to discard by construction) builds a genuinely held result via output backpressure then STOPs while it is still held, for the first real assertion on o_measurement_result_discard_event (previously only a $display). TOP-15: a permanent background monitor compares o_adc_owner_commit_event against state_current[B_INFLIGHT] on the same edge (both read with blocking semantics, so both reflect pre-this-edge settled values on a common time basis); an earlier version that added an extra one-cycle delay register was wrong and produced 11 false positives by mis-timing the reference point against the scheduler's intentional zero-cycle release-then-reestablish scheduling (confirmed by direct multi-cycle waveform tracing, not assumed). TOP-18: SMOKE-19's existing 4000-cycle STATIC_BIAS steady-state loop gains two per-cycle checks; the first attempt asserted both analog_run_enable and measurement_run_enable at 0 and real simulation immediately failed the analog half -- ppg_control_top.v:408's own comment (also tagged @satisfies:TOP-18) states analog_run_enable must keep following RUN under STATIC_BIAS so SSW can still drive the static vector, so the assertion was corrected to measurement_run_enable==0 and analog_run_enable==1, matching the RTL's own documented intent rather than the literal but incorrect first reading of the contract prose. All 5 fixes independently mutation-tested where practical (TOP-02 and TOP-18 against real single-line RTL mutants restoring the pre-fix behavior; both correctly fail). Full regression re-run: 0 FAIL, SMOKE_TB_PASS (49 real ADC responses, 33 measurement results).
// 2026/10/06            V1.8          Erie                  ABCD review F-024/F-014: at simulation start the TB reads the actually elaborated parameters hierarchically and checks them. PARAM-FIXED: Top config width 1024, config/coef/DC-recovery epoch widths 8, code epoch 4, generation 8, frame/sample 16/16, and the wrapper-internal config manager (1024/8) and config CDC bridge (1024), which Top does not parameterize. PARAM-WDOG: supervisor watchdog 5000/13 and legal (width >= clog2(cycles+1)). Guards against a changed parameter being silently truncated at a width-mismatched port, which only warns. Two new PASS lines (71 -> 73). Negative controls: Top watchdog width 12 fails PARAM-WDOG; manager generation width 9 fails PARAM-FIXED.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月23日
// 设计名称:           PPG数字系统顶层烟雾测试平台
// 模块名称:           tb_ppg_control_top
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.8
// 修订日期:           2026年10月06日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月23日        V1.0          Erie                  创建文件。TB-SMOKE-01最小烟雾测试：复位、合法NORMAL MANUAL IDAC COMMIT、START、通过公开物理RAW/CLK_DOUT边界响应若干笔真实Q3门控ADC事务、STOP，最终干净$finish且关键输出无X。这是ppg_control_top第一次真正的功能仿真，本轮只做烟雾测试，不是TOP-01~24全量覆盖。
// 2026年08月24日        V1.1          Erie                  把SMOKE-01~05扩展到SMOKE-01~20，为C01验收矩阵的TOP-01/02/09基础路径加上TOP-04/05/06（协议一致性部分）/07/08/09/12/13/14/15/16/17/18/19拿到真实仿真证据，其中三个定向场景带出并修复了AMI一个真实的STOP-discard缺陷（见ppg_adc_measurement_idac_integration.v V1.11）。扩展过程中还发现并修复了三个本TB自身的真实缺陷，都不在DUT RTL里：（1）wait_q3_release内部5600拍超时被静默当成真实释放处理，导致bg_responder在CONFIG/STATIC_BIAS这类Q3本来就不该开的时段，大约每5600拍就凭空伪造一次响应，从V1.0开始这份TB报出的每一个响应计数都被这样污染过；现在任务会明确报告有没有真的等到释放，bg_responder据此才响应。（2）bg_responder原来靠在Q3释放瞬间采样SSW的波形上下文valid瞬时标志来区分RED/IR/校准响应，双光模式下IR上下文可能已经提前建立，会把RED的响应误判成IR；改用scheduler自己在owner提交时刻原子锁存的B_INFLIGHT_COLOR/B_INFLIGHT_TYPE位。（3）drive_real_adc_done的precision_mode参数原来无论实际committed精度是什么都硬编码成SAR9，导致AMI的异步捕获模块（SAR15专门等stage2 DONE脉冲）永远等不到一次SAR15完成；现在按每次响应的真实精度采样。另外订正了一处注释错误：MANUAL配置任务的optical_mode字段注释写着双光，但按scheduler自己的编码实际是OPTICAL_IR（2'b10），SMOKE-01~11从头到尾跑的都是IR单光而不是双光；为需要真双光的场景（TOP-15、TOP-05）新增了独立的真双光配置任务。TOP-06"旧15-bit尾部不启动新事务"这一半需要真实生理波形触发基线穿越精度切换，留给Phase 3真实PPG波形生成器就绪后再补。全部21个场景组均已拿到真实仿真证据通过。
// 2026年08月24日        V1.2          Erie                  新增SMOKE-21/22覆盖TOP-20（校准责任边界）：SMOKE-21全程真实跑CHARACTERIZATION+EXTERNAL_TEST_CURRENT（RED/IR真实事务持续发生），确认AMI的o_calibration_sample_valid全程为0，证实AMI的结构性源端门控（flag_normal_start_search_qualified要求run_profile==NORMAL）确实生效；SMOKE-22尝试非法NORMAL_PPG+SAR15 COMMIT，确认manager按MGR-16/18静态拒绝（error=8'h10），这条同时说明"非法SAR15校准请求"在当前架构下没有任何合法路径可达（AMI还把o_calibration_precision_mode硬编码常量0）。搭建过程中撞上两个真实环境交互：（a）SMOKE-19提交的static_characterization_enable=1是跨场景sticky的（只能靠显式CDC提交清除，回到CONFIG或下一次V4 COMMIT都不会自动清），SMOKE-21因此新增task_clear_static_bias_characterization任务先显式清回0，否则CHARACTERIZATION+EXTERNAL_TEST_CURRENT会被静默误判成STATIC_BIAS；（b）config manager的error_sticky（合同5节start_ready公式里的项，任何非法操作即置位）是真正的W1C sticky，不会被下一次合法COMMIT带走，SMOKE-20故意触发的负向测试拒绝把它留在1，静默挡住了SMOKE-21第一次START尝试并报出通用的0x0b错误，需要在两者之间插入一次显式i_diag_clear_event脉冲——SMOKE-01~20都没遇到过这个问题，因为SMOKE-20一直是脚本里最后一个场景。SMOKE-21的监控最初还查了调度器的o_calibration_sample_ready，报出一次假FAIL；逐拍追踪后发现calibration_sample_ready_o只是纯组合的容量/就绪电平（生命周期活动且未在处理别的请求就是1），从未引用run_profile或input_source，不能作为非法请求的证据，已从检查里去掉。这条追踪线索带出一个更重要、与TB自身无关的真实发现：C01合同"校准责任边界"和调度器合同9.1节公式里描述的调度器接收端run_profile/input_source复核，在当前调度器RTL里根本没有实现——i_run_profile端口声明后在模块正文里从未被引用，i_input_source只被锁存进state_current[B_FRAME_INPUT_SOURCE]转发给SSW波形槽做标记，从未参与calibration_sample_ready_o或flag_calibration_request_valid的判断（这条公式里只有SAR9 precision_mode那一项真的实现了）。调度器合同自己的自检用例表写着"FSC-17|校准请求资格与缓冲"正好覆盖这个，但tb_ppg_400hz_frame_calibration_scheduler.v里根本不存在这条用例（真实的FSC-17测的是纯RED场景一个无关的owner commit计数）——这是一条只停留在文档层面、从未真正实现或测试过的规划。TOP-20目前只靠AMI单边源端门控成立，不是合同描述的AMI+Scheduler双边防御；要不要在调度器里补上这条接收端复核是需要用户决定的真实架构问题，本轮不擅自静默打补丁。全部22个场景组均已拿到真实仿真证据通过；-Wall编译干净（仅两条本轮未碰的ppg_dynamic_baseline_cross_detector.v既有无关警告）。
// 2026年08月24日        V1.3          Erie                  新增SMOKE-23覆盖TOP-03（NORMAL双光）——C01验收矩阵里最后一条未覆盖的项，是整理上一份交接文档时才发现的遗漏：SMOKE-14虽然跑双光，但只断言了TOP-15那四个SAR15信号的持久性，从未验证TOP-03自己的四条claim。新增一个持久后台监测进程（扩展既有owner commit计数block），在o_adc_owner_commit_event同拍直接从scheduler的o_adc_owner_frame_id/o_adc_owner_sample_index/o_adc_owner_precision_mode/macro_tick_o采样——这些都是那一拍就有效的保持型输出，完全不依赖bg_responder的Q3释放时机。SMOKE-23真实跑两个连续宏帧的RED+IR配对，核对帧内同一frame_id、sample_index连续（IR=RED+1）、同一committed精度，以及跨帧Q3相位固定（拿pair1和pair2互相比对，不是拿一个假设的固定tick数字去核对）。第一次真正跑起来撞上两个真实问题，都不是走错方向的弯路：（1）SMOKE-22是故意触发的负向测试（非法NORMAL+SAR15 COMMIT），会把manager的error_sticky留在1，跟此前挡住SMOKE-21第一次START的是同一个坑——照搬同样的修复，在SMOKE-23前也插入一次显式i_diag_clear_event。（2）场景基线（cnt_owner_commit_red/ir快照）最初按其它场景的惯例在START后固定等8拍再取，但RED context在宏帧tick 0接管，START后几乎立刻就提交第一笔owner，而IR要等RED的owner被一次真实DONE释放后才能提交（晚得多）——这8拍settle窗口足够长到已经把RED第一笔提交算进基线，却还没轮到IR，导致RED这边的delta基准点被悄悄推后了一整笔真实事务。表现出来的现象是：第一次捕获的"一对"把IR真实的frame-0提交和RED的frame-1提交配成了一对，而不是frame-0——这是TB自己记账的真实frame_id错配，不是DUT的问题。修复：把基线改到task_pulse_start之前取，那时不可能有任何提交发生。全部23个场景组均已拿到真实仿真证据通过；按交接文档自己审计的结论，这条补完后TOP-01至TOP-24在本文件加tb_ppg_control_top_injection.v里全部拿到了真实仿真或静态证据。
// 2026年08月24日        V1.4          Erie                  Phase 3 Stage 2：把Phase 3 Stage 1的确定性RAW生成器（tb_ppg_real_raw_generator.vh V1.2）接入bg_responder，替换掉之前make_fixed_raw无论颜色/帧号/精度永远产出的固定256/300码。校准事务（AMB_CAL/DCS_CAL）未改动——按生成器合同自己第1节的边界，校准继续走既有固定码模型，不归生理生成器管。接线前有两件事必须先弄清楚，都记在这里而不是凭空猜：（1）本来预期PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md（C14）会定义Stage1/Stage2物理码的对应关系，读完发现C14其实只消费已经校准过的Stage1值和已经解码过的D2_EXT，真正的物理码解码在ppg_adc_pipeline_overlap_corrector.v里——直接读RTL确认：D1_EXT和D2_EXT是对i_stage1_raw和i_stage2_raw各自独立套用完全相同的vdred冗余解码公式（正是本TB自己的make_fixed_raw编码的逆运算）得到的，然后Stage1取主导权重、Stage2取小幅级间重叠修正权重叠加——不是Stage 1规划时猜测的"整数/小数残差"那种粗细拆分关系。既然两路物理码本来就是对同一物理瞬间的两次独立解码采样，给make_fixed_raw喂同一个生成器target_code产出stage1_raw和stage2_raw，才是真正贴合这个解码结构的表示，不是随手简化；SAR9事务两路码值都无所谓，因为dec_stage2_raw_qualified在i_precision_mode=0时会把S2直接清零屏蔽。（2）o_adc_owner_frame_id这个名字、以及本文件此前一直把它当成稳定的per-owner身份来用（V1.3的SMOKE-23后台监测进程就是这么依赖它的），但RTL实测（ppg_400hz_frame_calibration_scheduler.v：o_adc_owner_frame_id=transaction_frame_id_o=current_frame_id_o=state_current[B_FRAME_ID]）证实它其实只是调度器当前宏帧计数器的直通别名，不是owner提交时刻专门锁存的值——只有在owner确实还在途（也就是drive_real_adc_done真正让DONE发生、owner释放之前）读它才安全，这和bg_responder同一时刻已经在依赖的color/precision字段是同一条时序约束。现在frame_id、颜色、校准/NORMAL分支判断都在这同一个安全时刻一起采样，在flag_hold_next_adc_response可能引入的等待开始之前。全量回归、未改动任何RTL：全部23个SMOKE场景重跑通过（SMOKE_TB_PASS，47笔真实ADC响应，32笔正式结果，场景级断言与V1.3完全一致，因为NORMAL档位产出的码值本来就落在合法窗口内）；tb_ppg_control_top_injection.v的INJ-00~04也重跑通过（INJ_TB_PASS，14/14）——这份TB自己有一套独立的drive_real_adc_done/make_fixed_raw，没有`include本生成器，逻辑上不可能因为这次改动回归，这次重跑是确认，不是新证据。`-Wall`编译干净（和V1.1~V1.3一样，只有两条本轮未碰的ppg_dynamic_baseline_cross_detector.v既有无关警告）。这是本TB历史上第一次SAR9/SAR15 NORMAL RED/IR的RAW值真正随真实颜色和真实宏帧号变化；本轮不对下游算法层（真实基线穿越、真实峰谷检测）做任何断言，那是Phase 3 Stage 3/4的范围。
// 2026年09月02日        V1.6          Erie                  为V1.3/V1.4新增的两个C01顶层端口（o_active_precision_mode、o_source_config_update_ready）补上专属验收证据——此前从未有任何直接断言碰过这两个端口本身，既有的后台监控都只是层次化探针内部AMI线，没有验证过端口本身。首次把这两个新端口接入本文件的DUT实例化。NPA-01：新增一个全程逐拍的后台监控进程（和既有TOP-17扇出检查同一风格），比对o_active_precision_mode和AMI转发内部线ppg_control_top_Inst.ami_active_precision_mode_o，全部23个场景组（含每一次SAR9↔SAR15切换）全程跑下来零FAIL，确认V1.3那条纯组合透传逐位一致、没有撕裂窗口。NPA-02：把SMOKE-02第一次真实COMMIT扩展成一次忙碌期节流拒绝测试——先确认o_source_config_update_ready闲时为1，打第一拍后确认它跌为0（带一个"从未观测到忙碌"防空判条件测试）；忙碌期间故意打第二拍i_source_config_update_event（内容故意不同：idac_mode=SEARCH_TRACK而不是真正的MANUAL），随后靠SMOKE-02自己原有的o_config_epoch==1检查证明第二拍确实被ppg_config_cdc_bridge.v的忙碌锁存语义（第127/138行：flag_source_busy==1时source域既不重新锁存也不重新翻转代际）真实静默丢弃，没有被合并或排队成第二次真实提交。构造NPA-02过程中发现并修复了一个本TB自己的方法论错误，不是DUT缺陷：最初断言o_source_config_update_ready会在o_commit_ack_event置位的同一拍恢复为1，真实iverilog证据立刻FAIL——o_commit_ack_event只反映destination域的config manager已经接受了config_transport_update_o，而o_source_config_update_ready还需要这次接受再经过ppg_config_cdc_bridge.v的flag_ack_sync_meta/flag_ack_sync两级同步器真正传回source域，是一个更晚、独立的事件；改成有界64个source_clk周期的轮询（和本文件已有的task_wait_config_result同一惯例）后重跑，确认ready确实在1个source_clk周期后就恢复。两条新检查都拿到真实双工具证据（iverilog -Wall编译干净+全量跑通，Vivado 2022.2 xsim全量elaborate+跑通，均零FAIL）；原有SMOKE_TB_PASS基线（全部23个场景、47笔真实ADC响应、32笔正式结果）与V1.5完全一致，确认本次新增没有引入任何回归。未改动任何RTL。
// 2026年09月17日        V1.7          Erie                  工作线D独立复核修复5个确认缺口TOP-01/02/09/15/18（不改RTL；调查驱动，过程中好几次最初假设都被真实仿真证据纠正，不是凭空猜对）。TOP-01：SMOKE-01新增真实`o_s_in==5'b00000`核对（RTL:604早已带着一个从未被验证过的`@satisfies:TOP-01`标签）；文件末尾新增独立场景，真实建立在途事务后触发复位，确认状态完全清零、结果计数不因旧事务静默递增，再确认重新COMMIT+START真的能产生全新结果。TOP-02：SMOKE-05与SMOKE-06之间新增负向场景，只破坏V5保留位段（V4合法字段不动），确认整份1024-bit快照原子拒绝且config_epoch不变；随后补了一次diag_clear脉冲，因为manager的error_sticky是W1C的，不清掉会静默挡住SMOKE-06紧接着的合法提交。TOP-09：新增独立场景（没有沿用SMOKE-06的"STOP早于DONE"窗口——真实仿真证明那个窗口结构上就没有正式结果可丢弃），用输出反压真实建立一笔held结果后在其仍被反压保持时STOP，第一次给`o_measurement_result_discard_event`加上真实断言（此前只是`$display`）。TOP-15：新增全程常驻后台监测，在同一个边沿以阻塞方式直接比较`o_adc_owner_commit_event`和`state_current[B_INFLIGHT]`（两者都读到进入本次边沿之前已结算的值，天然同一时间基准）；早先一版额外加了一拍延迟寄存器，结果用错了参照点，把调度器有意设计的"零周期浪费、释放同拍立即重建"衔接误判成11次重入（用多拍波形直接追证据核实，不是凭猜测下结论）。TOP-18：SMOKE-19已有的4000拍STATIC_BIAS steady-state循环新增两项逐拍核对；最初断言`analog_run_enable`和`measurement_run_enable`都该是0，真实仿真立刻让analog那半FAIL——`ppg_control_top.v:408`自己的注释（同样带`@satisfies:TOP-18`标签）写明STATIC_BIAS下`analog_run_enable`仍须跟随RUN以便SSW继续驱动静态向量，遂改为`measurement_run_enable==0`且`analog_run_enable==1`，按RTL自己记录的真实意图而不是对合同原文的字面误读。5条修复里TOP-02和TOP-18有条件地做了变异测试（针对真实单行RTL做还原式mutant，两者都正确FAIL）。完整回归重跑：0 FAIL，SMOKE_TB_PASS（49笔真实ADC响应，33笔正式结果）。
// 2026年10月06日        V1.8          Erie                  ABCD复核F-024/F-014：仿真开始时按层次读取实际例化参数核对。PARAM-FIXED：Top配置宽度1024，配置/系数/DC恢复版本宽度8，码版本4，代际8，帧号/序号16/16，以及Top未参数化的wrapper内部config manager（1024/8）和配置CDC桥（1024）。PARAM-WDOG：supervisor看门狗5000/13且合法（宽度>=clog2(周期+1)）。防止参数被改后在位宽不匹配端口处只告警、被静默截断。新增两条PASS行（71变73）。负对照：Top看门狗宽度改12时PARAM-WDOG失败；manager代际宽度改9时PARAM-FIXED失败
//
// 复位后原子提交一组合法NORMAL双光MANUAL IDAC配置并启动RUN，只通过公开物理边界响应真实
// Q1/Q2/Q3门控的ADC事务，STOP后确认排空与关键输出无X传播
module tb_ppg_control_top();

	//---------------Phase 3确定性PPG RAW生成器模型引入---------------//
	// V1.4引入，为NORMAL RED/IR事务提供按颜色/帧号变化的生理波形，替换bg_responder
	// 原来那一对与颜色/帧号完全无关的固定码；校准事务（AMB_CAL/DCS_CAL）不引入本
	// 生成器，继续走既有固定码逻辑（C25合同第1节：校准事务由既有校准模型管）
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

	// 以下V5默认字段值与ppg_system_config_manager.v的V5_RESET_PROFILE逐项一致，
	// 只用于凑出一份合法1024-bit联合快照；本轮烟雾测试不exercising峰谷/相交算法
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
	reg i_clk; // 2 MHz语义系统时钟仿真替身
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
	reg i_analog_ready; // 模拟就绪聚合结果，本轮恒1（对应真实板级先稳压后启动的流程）

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
	wire o_ami_datapath_empty, o_ami_idac_idle, o_active_precision_mode, o_ami_integration_protocol_error_sticky;
	wire o_ssw_wrapper_idle, o_ssw_switch_protocol_error_sticky, o_ssw_transaction_mismatch_sticky;
	wire o_ssw_owner_deadline_timeout_sticky, o_ssw_calibration_timeout_sticky;

	//---------------表征控制source握手与诊断输出---------------//
	wire o_source_config_update_ready; // NPA-01/NPA-02新增顶层端口：source侧CDC邮箱可接受下一笔快照，与config_transport_busy互为反相
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
	integer cnt_npa02_ready_wait; // NPA-02等待o_source_config_update_ready恢复的有界轮询计数
	reg [7:0] cnt_top02_epoch_before; // TOP-02新增：V5非法提交前的config_epoch快照
	integer cnt_top09_discard_event; // TOP-09新增：drain期间o_measurement_result_discard_event真实脉冲计数
	integer cnt_top15_commit_checked; // TOP-15新增：监测进程实际检查过的owner commit次数，防止空跑
	integer cnt_top15_reentrant; // TOP-15新增：真实检测到的重入次数
	integer cnt_top01_result_before; // TOP-01新增：复位前的正式结果计数快照
	integer cnt_source_clock; // source时钟有限循环计数
	integer cnt_system_clock; // 系统时钟有限循环计数
	integer cnt_measurement_result_valid; // 观测到的正式结果次数
	integer cnt_adc_response; // 已响应的真实Q3门控ADC事务数
	integer cnt_red_response; // 已响应的真实RED事务数，按响应时SSW red_ctx分类
	integer cnt_ir_response; // 已响应的真实IR事务数，按响应时SSW ir_ctx分类
	integer cnt_cal_response; // 已响应的真实校准事务数，按响应时SSW cal_ctx分类
	integer cnt_macro_frame_start; // 已观察到的真实宏帧起点事件数
	integer cnt_owner_commit_red; // 直接从scheduler owner commit身份统计的RED owner提交数，独立于bg_responder的上下文采样
	integer cnt_owner_commit_ir; // 直接从scheduler owner commit身份统计的IR owner提交数
	integer cnt_owner_commit_total; // 不分颜色/类型的真实owner提交总数——唯一可信的"是否发生过真实ADC事务"判据，
	                                 // cnt_adc_response会被一个即使在CONFIG态、没有任何owner时也持续存在的物理
	                                 // Q3周期性toggle污染（bg_responder对它一样会响应），不能用来判断有没有真实事务
	reg [9:0] reg_last_cal_local_tick; // 最近一次校准响应时刻采样的校准局部相位，供TOP-04核对CAL_Q3_TICK=266
	reg [7:0] reg_last_cal_amb_snapshot; // 最近一次校准响应时刻采样的校准AMB快照，供TOP-04核对未使用旧候选码
	reg reg_last_precision_scheduler; // 最近一次响应时刻采样的scheduler owner精度身份，供TOP-06三方核对
	reg reg_last_precision_ssw; // 最近一次响应时刻采样的SSW owner精度身份
	reg reg_last_precision_ami; // 最近一次响应时刻采样的AMI异步捕获精度身份

	//---------------TOP-03双光owner身份快照---------------//
	// 与o_adc_owner_commit_event同拍采样scheduler直接输出的owner身份字段
	// （frame_id/sample_index/precision/颜色）和当时的macro_tick，不依赖
	// bg_responder的Q3释放时机——commit事件和这些身份字段本来就是同一拍的
	// 保持型输出。分别记住最近一次RED和最近一次IR的快照，供双光场景核对
	// 同一frame_id、连续sample_index、同一committed精度和固定Q3相位
	reg [C_FRAME_ID_WIDTH - 1:0] reg_last_red_frame_id, reg_last_ir_frame_id;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_last_red_sample_index, reg_last_ir_sample_index;
	reg reg_last_red_precision, reg_last_ir_precision;
	reg [12:0] reg_last_red_tick, reg_last_ir_tick;
	integer reg_top03_red_before, reg_top03_ir_before; // SMOKE-23基线，必须在START前捕获（见该场景注释：RED首笔提交几乎与START同拍，START后固定延迟再取基线会把它算漏）
	reg flag_run_phase_active; // RUN期间X传播监测使能
	reg flag_global_timeout; // 全局看门狗超时标记

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
			.o_active_precision_mode(o_active_precision_mode),
			.o_ami_integration_protocol_error_sticky(o_ami_integration_protocol_error_sticky),
			.o_ssw_wrapper_idle(o_ssw_wrapper_idle),
			.o_ssw_switch_protocol_error_sticky(o_ssw_switch_protocol_error_sticky),
			.o_ssw_transaction_mismatch_sticky(o_ssw_transaction_mismatch_sticky),
			.o_ssw_owner_deadline_timeout_sticky(o_ssw_owner_deadline_timeout_sticky),
			.o_ssw_calibration_timeout_sticky(o_ssw_calibration_timeout_sticky),
			.o_source_config_update_ready(o_source_config_update_ready),
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
	// 使用与system时钟互质的仿真周期形成独立CDC相位关系，绝对时间不代表真实SPI频率
	initial begin
		i_source_clk = 1'b0;
		for(cnt_source_clock = 0; cnt_source_clock < 3000000; cnt_source_clock = cnt_source_clock + 1) begin
			#5.5 i_source_clk = ~i_source_clk;
		end
	end

	//---------------系统时钟发生器---------------//
	// 系统时钟只承担边沿语义，绝对仿真时间不代表真实2 MHz周期
	initial begin
		i_clk = 1'b0;
		for(cnt_system_clock = 0; cnt_system_clock < 3000000; cnt_system_clock = cnt_system_clock + 1) begin
			#6.5 i_clk = ~i_clk;
		end
	end

	//---------------合法NORMAL双光MANUAL配置构造任务---------------//
	// 复用ACTIVE wrapper自检平台已验证过的合法V4字段值，只把IDAC模式改成MANUAL，
	// 避免本轮烟雾测试还要陪跑AMB/DCS自动搜索收敛过程
	task task_build_normal_manual_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0; // run_profile=NORMAL_PPG
			i_source_config_snapshot[9] = 1'b0; // input_source=PHOTODIODE
			i_source_config_snapshot[11:10] = 2'b00; // idac_mode=MANUAL，本轮不exercising自动搜索
			i_source_config_snapshot[13:12] = 2'b10; // optical_mode=IR单光（OPTICAL_IR，非双光——SMOKE-01~11一直跑的是这个单色路径，不是NORMAL双光；真双光见task_build_normal_manual_dual_config）
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
			i_source_config_snapshot[193:168] = -26'sd17; // stage1_weight_q16_0
			i_source_config_snapshot[219:194] = 26'sd18; // stage1_weight_q16_1
			i_source_config_snapshot[245:220] = -26'sd19; // stage1_weight_q16_2
			i_source_config_snapshot[271:246] = 26'sd20; // stage1_weight_q16_3
			i_source_config_snapshot[297:272] = -26'sd21; // stage1_weight_q16_4
			i_source_config_snapshot[323:298] = 26'sd22; // stage1_weight_q16_5
			i_source_config_snapshot[349:324] = -26'sd23; // stage1_weight_q16_6
			i_source_config_snapshot[375:350] = 26'sd24; // stage1_weight_q16_7
			i_source_config_snapshot[401:376] = -26'sd25; // stage1_weight_q16_8
			i_source_config_snapshot[427:402] = 26'sd26; // stage1_weight_q16_9
			i_source_config_snapshot[459:428] = -32'sd99; // stage1_offset_q16
			i_source_config_snapshot[479:460] = 20'sd54143; // stage2_gain_q16
			i_source_config_snapshot[511:480] = -32'sd37; // stage2_offset_q16
			i_source_config_snapshot[543:512] = 32'sd65536; // dc9_recovery_gain_q16
			i_source_config_snapshot[575:544] = 32'sd32768; // dc15_recovery_gain_q16
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames
		end
	endtask

	//---------------合法NORMAL双光SEARCH_TRACK配置构造任务---------------//
	// 与task_build_normal_manual_config逐字段一致，只把idac_mode改回原始
	// SEARCH_TRACK（2'b10），专供SMOKE-08校准窗口定向场景触发真实AMB/DCS
	// 自动校准请求；本任务不重复整份字段列表的逐行注释，差异只在idac_mode
	task task_build_normal_search_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK，本场景需要真实校准请求
		end
	endtask

	//---------------合法NORMAL真双光MANUAL配置构造任务---------------//
	// 与task_build_normal_manual_config逐字段一致，只把optical_mode从IR单光
	// （2'b10）改成真正的双光（OPTICAL_BOTH=2'b00），专供TOP-15双光共享包络等
	// 需要真实RED+IR交替事务的场景
	task task_build_normal_manual_dual_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，真双光
		end
	endtask

	//---------------合法NORMAL纯RED固定SAR9 MANUAL配置构造任务---------------//
	// optical_mode改成OPTICAL_RED（2'b01），initial_precision保持SAR9（bit14=0，
	// 与基准任务一致），专供TOP-13纯RED固定SAR9场景
	// 注意：run_profile仍是NORMAL、optical_mode=RED_ONLY这个组合在MGR-17/18合法
	// 矩阵里根本不存在——config manager合同明确写着RED_ONLY+PHOTODIODE只在
	// run_profile=CHARACTERIZATION下合法（MGR-17），NORMAL+RED_ONLY不在合法列表
	// 里，本任务因此改用CHARACTERIZATION+PHOTODIODE+RED_ONLY，不是最初以为的
	// NORMAL+RED_ONLY——这是先跑了一次空跑才发现的，不是凭空猜的
	task task_build_char_photodiode_red_sar9_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION，RED_ONLY+PHOTODIODE的唯一合法run_profile
			i_source_config_snapshot[13:12] = 2'b01; // optical_mode=OPTICAL_RED
		end
	endtask

	//---------------合法CHARACTERIZATION纯RED固定SAR15配置构造任务---------------//
	// 与上一任务一致，只把initial_precision改成SAR15，专供TOP-14纯RED固定SAR15场景
	task task_build_char_photodiode_red_sar15_config;
		begin
			task_build_char_photodiode_red_sar9_config;
			i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15
		end
	endtask

	//---------------非法NORMAL+SAR15 MANUAL配置构造任务---------------//
	// 专供SMOKE-22验证manager MGR-16/18静态非法组合表：run_profile=NORMAL_PPG
	// 时initial_precision必须为SAR9，NORMAL+SAR15属于静态非法组合，必须在
	// COMMIT/START前就被manager拒绝（error=8'h10），不得进入READY/RUN。这条
	// 反过来说明TOP-20“非法SAR15校准请求”这半句在当前架构下无法通过任何合法
	// NORMAL RUN路径构造：NORMAL模式本身就不能提交SAR15
	task task_build_normal_manual_sar15_illegal_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15，与run_profile=NORMAL_PPG静态冲突
		end
	endtask

	//---------------合法CHARACTERIZATION外部固定电流双光配置构造任务---------------//
	// run_profile=CHARACTERIZATION，input_source=EXTERNAL_TEST_CURRENT，
	// optical_mode=OPTICAL_BOTH，idac_mode保持MANUAL（继承自基准任务）——专供
	// TOP-07固定电流表征场景，按合同C06§5.2：LED全程关闭，SAR仍按正常NORMAL
	// 400Hz间歇事务运行，只是输入源换成外部精密电流
	task task_build_char_external_current_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION
			i_source_config_snapshot[9] = 1'b1; // input_source=EXTERNAL_TEST_CURRENT
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH
		end
	endtask

	//---------------合法CHARACTERIZATION STATIC_BIAS V4配置构造任务---------------//
	// run_profile=CHARACTERIZATION、input_source=EXTERNAL_TEST_CURRENT——按合同
	// C06§6.1，这是STATIC_BIAS唯一合法的V4侧进入条件；optical_mode对STATIC_BIAS
	// 无意义（SSW在STATIC_BIAS下改走独立静态向量输出，不消费optical_mode），
	// 保留基准任务继承来的值即可。真正的STATIC_BIAS使能位不在V4快照里，走独立
	// 表征控制CDC，见task_commit_static_bias_characterization
	task task_build_static_bias_v4_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION
			i_source_config_snapshot[9] = 1'b1; // input_source=EXTERNAL_TEST_CURRENT
		end
	endtask

	//---------------表征控制CDC提交任务---------------//
	// 按合同C07：source端保持valid直到source_fire（valid&&ready）发生后撤销，
	// 不在busy期间产生第二笔请求；必须在i_run_enable==0（CONFIG/READY）期间提交，
	// 目标域才会无条件接受。提交static_characterization_enable=1和五位测试MUX码
	task task_commit_static_bias_characterization;
		input [4:0] test_mux;
		integer cnt_wait_ready;
		begin
			@(negedge i_source_clk);
			i_source_static_characterization_enable = 1'b1;
			i_source_test_mux_ctrl = test_mux;
			i_source_characterization_update_valid = 1'b1;
			@(posedge i_source_clk); // source_fire在此沿发生（ready原本为1）
			@(negedge i_source_clk);
			i_source_characterization_update_valid = 1'b0; // 单笔请求后立即撤销valid，避免busy期间再触发一次
			cnt_wait_ready = 0;
			while((o_source_characterization_update_ready == 1'b0) && (cnt_wait_ready < 200)) begin
				@(posedge i_source_clk);
				cnt_wait_ready = cnt_wait_ready + 1;
			end
		end
	endtask

	//---------------撤销STATIC_BIAS资格提交任务---------------//
	// SMOKE-19把static_characterization_enable提交为1后，这个已提交使能是
	// sticky的，不会因为回到CONFIG或下一次COMMIT就自动清零（合同：只在RUN外
	// 才允许改变，不代表会自己变回默认值）。SMOKE-21需要一次真正的
	// CHARACTERIZATION+EXTERNAL_TEST_CURRENT（而不是被这个残留的1误判成
	// STATIC_BIAS），必须先走同一条CDC握手把它显式提交回0
	task task_clear_static_bias_characterization;
		integer cnt_wait_ready;
		begin
			@(negedge i_source_clk);
			i_source_static_characterization_enable = 1'b0;
			i_source_test_mux_ctrl = 5'b00000;
			i_source_characterization_update_valid = 1'b1;
			@(posedge i_source_clk);
			@(negedge i_source_clk);
			i_source_characterization_update_valid = 1'b0;
			cnt_wait_ready = 0;
			while((o_source_characterization_update_ready == 1'b0) && (cnt_wait_ready < 200)) begin
				@(posedge i_source_clk);
				cnt_wait_ready = cnt_wait_ready + 1;
			end
		end
	endtask

	//---------------真实响应静默等待任务---------------//
	// 一次STOP即使lifecycle已经回到CONFIG，也可能还有一笔STOP时恰好在途的owner
	// 靠V1.6被动drain机制在背景里等真实DONE收尾（cnt_adc_response还会再跳一次）；
	// 下一个场景如果紧接着就开始观察"无真实ADC事务"，可能会撞上这笔迟到的、
	// 属于上一个场景收尾的响应。等cnt_adc_response连续i_settle_cycles拍不再
	// 变化，才能确认背景响应真的静默下来，不是"看起来快"就当作已经停了
	task task_wait_response_quiescent;
		input integer i_settle_cycles;
		input integer i_bound_cycles;
		integer cnt_last_response;
		integer cnt_stable;
		integer cnt_total;
		begin
			cnt_last_response = cnt_adc_response;
			cnt_stable = 0;
			cnt_total = 0;
			while((cnt_stable < i_settle_cycles) && (cnt_total < i_bound_cycles) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_total = cnt_total + 1;
				if(cnt_adc_response != cnt_last_response) begin
					cnt_last_response = cnt_adc_response;
					cnt_stable = 0;
				end else begin
					cnt_stable = cnt_stable + 1;
				end
			end
		end
	endtask

	//---------------source事件任务---------------//
	// 在source时钟边沿提交一次快照传输请求
	task task_pulse_source_update;
		begin
			@(negedge i_source_clk);
			i_source_config_update_event = 1'b1;
			@(posedge i_source_clk);
			#1 i_source_config_update_event = 1'b0;
		end
	endtask

	//---------------START事件任务---------------//
	// 在2 MHz域提供一个无并发配置命令的START单拍
	task task_pulse_start;
		begin
			@(negedge i_clk);
			i_start_event = 1'b1;
			@(posedge i_clk);
			#1 i_start_event = 1'b0;
		end
	endtask

	//---------------STOP事件任务---------------//
	// 在2 MHz域提供一个无并发配置命令的STOP单拍
	task task_pulse_stop;
		begin
			@(negedge i_clk);
			i_stop_event = 1'b1;
			@(posedge i_clk);
			#1 i_stop_event = 1'b0;
		end
	endtask

	//---------------abort事件任务---------------//
	// 在2 MHz域提供一个无并发配置命令的外部abort单拍，用于定向验证V1.6修复未
	// 触碰的abort立即清零分支
	task task_pulse_abort;
		begin
			@(negedge i_clk);
			i_control_abort_event = 1'b1;
			@(posedge i_clk);
			#1 i_control_abort_event = 1'b0;
		end
	endtask

	//---------------配置结果等待任务---------------//
	// 等待顶层对已到达快照给出唯一COMMIT ACK或ERROR事件，超时记录FAIL
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
				$display("FAIL SMOKE config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------真实ADC完成响应任务---------------//
	// 只在物理边界注入RAW/CLK_DOUT，不伪造完成脉冲；短暂拉低物理空闲电平模拟一次真实转换
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
	// 只在观察到真实Q3脉冲出现且释放后才允许响应，不使用固定延时伪造完成时机
	// 注意：本任务5600拍内等不到Q3第一次拉高是合法的"这段时间根本没有真实
	// 事务"（比如CONFIG/STATIC_BIAS下Q3本来就不该开），不是异常——只有已经
	// 观察到Q3真实拉高之后，第二段等它释放又超过6600拍才是真正的协议异常。
	// 调用方必须检查o_real_release，不能把"等到超时"和"等到真实释放"混为一谈，
	// 否则会对着一个从未真实打开过的Q3窗口去响应一次伪造事务——这正是这次
	// 排查STATIC_BIAS背景周期性idle抖动时才发现的真实TB缺陷，不是RTL问题
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
				o_real_release = 1'b0; // 5600拍内从未观察到真实Q3拉高，只是安全超时，不是真实事务
			end else begin
				o_real_release = 1'b1;
				while((o_clk_q3_low === 1'b1) && (cnt_wd < 6600)) begin
					@(negedge i_clk);
					cnt_wd = cnt_wd + 1;
				end
				if(cnt_wd >= 6600) begin
					$display("FAIL SMOKE Q3 wait timeout at cnt_adc_response=%0d", cnt_adc_response);
					cnt_error = cnt_error + 1;
				end
			end
		end
	endtask

	//---------------vdred编码RAW构造任务---------------//
	// 使用与既有joint TB相同的vdred=1公开物理位编码，只取一个固定中间量程码值
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

	//---------------后台ADC响应暂停控制信号---------------//
	// 主序列在需要构造"owner已提交但真实DONE尚未到达"这一精确时序窗口时置位
	// flag_hold_next_adc_response；bg_responder在真实观察到Q3释放（意味着owner
	// 已经提交、物理转换窗口已打开）后如果看到该请求，先不响应、只置位
	// flag_adc_response_held告知主序列，直到主序列清除请求才补发真实完成，
	// 不构造任何伪造完成或固定延时
	reg flag_hold_next_adc_response; // 主序列请求暂停下一次真实ADC响应
	reg flag_adc_response_held;      // bg_responder确认已在Q3释放后暂停

	//---------------后台ADC响应进程---------------//
	// 整个仿真期间循环等待真实Q3释放再响应，覆盖NORMAL测量和SEARCH_TRACK模式下
	// 触发的自动校准两类事务共用的同一物理路径
	reg [9:0] reg_fixed_stage1_raw;
	reg [9:0] reg_fixed_stage2_raw; // 仅校准事务(AMB_CAL/DCS_CAL)使用的固定RAW，V1.4起NORMAL RED/IR不再用它
	reg reg_response_precision; // 按真实上下文取的本次响应committed精度，供drive_real_adc_done使用
	reg flag_q3_real_release; // wait_q3_release本次返回是不是真的等到了Q3拉高，不是安全超时
	reg flag_response_is_calibration; // 本次响应是不是校准事务，决定走固定码还是生成器
	reg reg_response_color_ir; // 本次响应的颜色身份，0=RED，1=IR，供生成器调用
	reg [31:0] reg_response_frame_id; // 本次响应绑定的owner物理帧号，供生成器调用
	reg [9:0] reg_response_stage1_raw; // NORMAL RED/IR事务实际送出的Stage1物理码
	reg [9:0] reg_response_stage2_raw; // NORMAL RED/IR事务实际送出的Stage2物理码
	reg [9:0] reg_response_target_code; // 生成器本次产出的target_code，clamp后
	integer reg_response_raw_unclamped; // 生成器本次产出的clamp前原始值，仅诊断用
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
		flag_hold_next_adc_response = 1'b0;
		flag_adc_response_held = 1'b0;
		forever begin
			wait_q3_release(flag_q3_real_release);
			// flag_q3_real_release=0表示5600拍内根本没等到Q3拉高（比如CONFIG/
			// STATIC_BIAS下Q3本来就不该开），只是任务自己的安全超时返回，不是
			// 真实事务——之前这里没检查这个返回值，把每次超时都当成"该响应了"，
			// 结果每隔约5600拍就凭空伪造一次响应，产生了一段时间排查不清的
			// "背景周期性idle抖动"，根因在这里，不是RTL的问题
			if(flag_q3_real_release) begin
				$display("DIAG bg_responder about to respond t=%0t cnt_adc_response(before)=%0d lifecycle=%b sched_idle=%b frame_active=%b macro_tick=%0d red_ctx=%b ir_ctx=%b cal_ctx=%b",
					$time, cnt_adc_response, o_lifecycle_state, o_scheduler_idle,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE],
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o,
					ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_red_context_valid,
					ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_ir_context_valid,
					ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_cal_context_valid);
				// 按scheduler锁存的owner身份分类，不用SSW的波形上下文valid——上下文是
				// 波形接管期间的瞬时标志，双光模式下RED上下文可能在RED自己的真实Q3
				// 物理完成之前就已经释放、IR上下文又已经提前建立，用SSW上下文在Q3释放
				// 时采样会把RED的响应误判成IR（TOP-15第一次真正跑双光才暴露）；
				// state_current[B_INFLIGHT_COLOR]/B_INFLIGHT_TYPE_H是owner提交时原子
				// 锁存、整个在途期间保持稳定的身份，才是正确的分类依据
				// V1.4：同一拍把是否校准事务、颜色身份都锁存下来，供本次响应稍后
				// 决定走固定码还是生成器使用——这两个身份和精度一样，必须在owner
				// 还在途、flag_hold_next_adc_response可能引入的等待开始之前采样，
				// 不能等到下面drive_real_adc_done调用前才读，那时owner可能已经变化
				flag_response_is_calibration = !ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_TYPE_H];
				reg_response_color_ir = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_COLOR];
				// o_adc_owner_frame_id字面上像是owner专属的锁存身份，但RTL定义
				// （transaction_frame_id_o=current_frame_id_o=state_current[B_FRAME_ID]）
				// 其实只是调度器当前宏帧计数器的直通别名，真实宏帧边界递增时会跟着变；
				// 只有在owner确认仍在途（也就是这里，drive_real_adc_done真正让DONE
				// 发生、owner被释放之前）读它才安全，一旦释放后才读就可能已经翻到
				// 下一宏帧——这个坑和TOP-06交接记录里color/precision的坑是同一类
				reg_response_frame_id = {16'd0, ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_frame_id};
				if(flag_response_is_calibration) begin
					cnt_cal_response = cnt_cal_response + 1;
					// TOP-04：同步采样校准局部相位与AMB快照，供主序列核对CAL_Q3_TICK=266
					// 且快照确实取自当时真实候选码，不是复用某个冻结旧值
					reg_last_cal_local_tick = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_local_tick;
					reg_last_cal_amb_snapshot = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_waveform_amb_code_snapshot;
				end else if(reg_response_color_ir) begin
					cnt_ir_response = cnt_ir_response + 1;
				end else begin
					cnt_red_response = cnt_red_response + 1;
				end
				// TOP-06：每次真实响应都同步采样scheduler/SSW/AMI三方各自锁存的owner
				// 精度身份，供主序列核对三方是否使用同一笔事务的同一个精度
				reg_last_precision_scheduler = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_precision_mode;
				reg_last_precision_ssw = ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_owner_precision_mode;
				reg_last_precision_ami = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_adc_async_stage_capture_Inst.reg_capture_mode;
				if(flag_hold_next_adc_response == 1'b1) begin
					flag_adc_response_held = 1'b1;
					wait(flag_hold_next_adc_response == 1'b0);
					flag_adc_response_held = 1'b0;
				end
				// 按当前真实上下文取committed精度：校准恒为SAR9，NORMAL/CHARACTERIZATION
				// 帧取state_current[B_FRAME_PRECISION]——之前这里硬编码1'b0，导致SAR15
				// 事务的AMI异步捕获模块永远等不到stage2 DONE，TOP-14第一次真正跑SAR15
				// 完整流程才暴露；这是TB自己的激励缺口，不是RTL问题
				reg_response_precision = ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.flag_cal_context_valid ? 1'b0 :
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_PRECISION];
				// V1.4：校准事务继续用既有固定码（C25合同第1节：校准事务由既有校准
				// 模型管，不归生理生成器管）；NORMAL RED/IR事务改用Phase 3生成器
				// 按颜色+真实owner帧号产出target_code。S1/S2物理码使用同一个
				// target_code独立做vdred编码——按ppg_adc_pipeline_overlap_corrector.v
				// 实测：D1_EXT/D2_EXT是对i_stage1_raw/i_stage2_raw各自独立应用完全
				// 相同的vdred冗余解码公式得到的，S1取主导权重、S2取小幅级间重叠修正
				// 权重叠加，不是"整数部分/小数残差"那种粗细拆分关系；两路本来就该是
				// 同一次物理转换、同一个生理样本，喂同一个target_code是最贴近这个
				// 硬件语义的选择，SAR9场景下S2会被overlap corrector按precision_mode
				// 直接清零屏蔽，值本身不重要
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
			end
		end
	end

	//---------------正式结果计数进程---------------//
	// 只统计真实o_measurement_result_valid拉高次数，不参与握手
	always @(posedge i_clk) begin
		if(i_rstn && o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_measurement_result_valid = cnt_measurement_result_valid + 1;
		end
	end

	//---------------idle三信号变化追踪进程（排查用）---------------//
	reg flag_debug_idle_trace;
	always @(o_scheduler_idle or o_ami_datapath_empty or o_ssw_wrapper_idle or
		ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.o_sar_timing_idle or
		ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.adc_owner_inflight_o or
		i_adc_physical_idle) begin
		if(flag_debug_idle_trace) begin
			$display("DIAG IDLE_TRACE t=%0t sched_idle=%b ami_empty=%b ssw_idle=%b sar_timing_idle=%b ssw_owner_inflight=%b i_adc_physical_idle=%b",
				$time, o_scheduler_idle, o_ami_datapath_empty, o_ssw_wrapper_idle,
				ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.o_sar_timing_idle,
				ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.adc_owner_inflight_o,
				i_adc_physical_idle);
		end
	end

	//---------------Q3电平变化追踪进程（排查用）---------------//
	// 只在flag_debug_q3_trace置位时启用，任何电平变化（不受限于posedge采样
	// 分辨率）都打印，用于确认背景周期性事件是否真的有一次Q3脉冲、脉冲多宽
	reg flag_debug_q3_trace;
	always @(o_clk_q3_low) begin
		if(flag_debug_q3_trace) begin
			$display("DIAG Q3_TRACE t=%0t o_clk_q3_low=%b", $time, o_clk_q3_low);
		end
	end

	//---------------AMI捕获链逐拍追踪进程（排查用）---------------//
	// 只在flag_debug_ami_capture_trace置位时启用，逐拍打印capture_valid/
	// s1_detect_valid/calibrated_valid/completion_emit/i_clk_stageX_dout_low_async
	// 的变化，用于抓住500拍采样间隔可能漏掉的瞬时活动
	reg flag_debug_ami_capture_trace;
	integer cnt_debug_ami_capture_trace;
	always @(posedge i_clk) begin
		if(flag_debug_ami_capture_trace) begin
			if(cnt_debug_ami_capture_trace < 8000) begin
				$display("DIAG AMI_TRACE t=%0t capture_valid=%b s1_detect_valid=%b calibrated_valid=%b completion_emit=%b s1_stage1_async=%b s2_stage2_async=%b adc_idle=%b capture_mode=%b precision_committed=%b transaction_start=%b capture_pending=%b",
					$time,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_capture_valid,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_s1_detect_valid,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_calibrated_valid,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_emit,
					i_clk_stage1_dout_low_async, i_clk_stage2_dout_low_async, i_adc_physical_idle,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_adc_async_stage_capture_Inst.reg_capture_mode,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_adc_async_stage_capture_Inst.i_precision_mode_committed,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_adc_async_stage_capture_Inst.i_adc_transaction_start,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_adc_async_stage_capture_Inst.flag_capture_pending);
				cnt_debug_ami_capture_trace = cnt_debug_ami_capture_trace + 1;
			end else begin
				flag_debug_ami_capture_trace = 1'b0;
			end
		end
	end

	//---------------宏帧起点计数进程---------------//
	// 只统计真实o_macro_frame_start_event拉高次数，供TOP-13/14/15这类
	// "每帧仅一笔事务"场景比对
	initial begin
		cnt_macro_frame_start = 0;
		cnt_owner_commit_red = 0;
		cnt_owner_commit_ir = 0;
		cnt_owner_commit_total = 0;
		cnt_top15_commit_checked = 0;
		cnt_top15_reentrant = 0;
		reg_last_cal_local_tick = 10'd0;
		reg_last_cal_amb_snapshot = 8'd0;
		reg_last_precision_scheduler = 1'b0;
		reg_last_precision_ssw = 1'b0;
		reg_last_precision_ami = 1'b0;
		reg_last_red_frame_id = {C_FRAME_ID_WIDTH{1'b0}};
		reg_last_ir_frame_id = {C_FRAME_ID_WIDTH{1'b0}};
		reg_last_red_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
		reg_last_ir_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
		reg_last_red_precision = 1'b0;
		reg_last_ir_precision = 1'b0;
		reg_last_red_tick = 13'd0;
		reg_last_ir_tick = 13'd0;
	end
	always @(posedge i_clk) begin
		if(i_rstn && ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_macro_frame_start_event) begin
			cnt_macro_frame_start = cnt_macro_frame_start + 1;
		end
		// TOP-15新增：真实检测RED/IR共享单一物理ADC事务时是否曾经重入。commit_event
		// 和state_current[B_INFLIGHT]都在此处以阻塞方式同拍直接读取，读到的都是"进入
		// 本次边沿之前"的已结算值（调度器自己对该寄存器的非阻塞更新要到这个event region
		// 结束才真正落地），所以两者天然按同一时间基准比较，不需要额外一拍延迟寄存器——
		// 调试时先试过一版额外延迟一拍的"上一拍快照"寄存器，结果发现那样反而引入了
		// 错误的参照点，把"释放的同一拍立即建立下一笔"这种设计上合法的零浪费衔接
		// 误判成重入（探针实测：释放发生的那一拍b_inflight已经现读为0，commit_event
		// 才为1，两者之间没有真正重叠）；直接同拍比较才是真正有效的重入判据
		if(i_rstn && ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_commit_event) begin
			cnt_top15_commit_checked = cnt_top15_commit_checked + 1;
			if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
				cnt_top15_reentrant = cnt_top15_reentrant + 1;
				$display("FAIL TOP-15 reentrant owner commit: new commit fired while B_INFLIGHT was still 1 at t=%0t", $time);
				cnt_error = cnt_error + 1;
			end
		end
		if(i_rstn && ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_commit_event) begin
			cnt_owner_commit_total = cnt_owner_commit_total + 1;
			if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_color_ir) begin
				cnt_owner_commit_ir = cnt_owner_commit_ir + 1;
				// TOP-03：IR owner提交同拍采样scheduler直接保持型输出的身份字段
				reg_last_ir_frame_id = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_frame_id;
				reg_last_ir_sample_index = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_sample_index;
				reg_last_ir_precision = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_precision_mode;
				reg_last_ir_tick = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o;
			end else begin
				cnt_owner_commit_red = cnt_owner_commit_red + 1;
				// TOP-03：RED owner提交同拍采样，与上面IR分支对称
				reg_last_red_frame_id = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_frame_id;
				reg_last_red_sample_index = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_sample_index;
				reg_last_red_precision = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_precision_mode;
				reg_last_red_tick = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o;
			end
		end
	end

	//---------------RUN期间X传播监测进程---------------//
	// 只在RUN期间对关键输出做X检查，避免CONFIG/READY过渡态误报
	always @(posedge i_clk) begin
		if(flag_run_phase_active) begin
			if(^o_measurement_result_valid === 1'bx || ^o_lifecycle_state === 1'bx || ^o_system_fault_blocking === 1'bx) begin
				$display("FAIL SMOKE X propagation on key output at time %0t", $time);
				cnt_error = cnt_error + 1;
			end
		end
	end

	//---------------TOP-17物理ADC idle单一真源扇出监测进程---------------//
	// 全程持续核对5个消费者（ACTIVE平面、scheduler、SSW、AMI、supervisor）各自
	// 收到的物理idle输入，与顶层公开输入i_adc_physical_idle逐位一致，用真实
	// 仿真证据确认它们确实同源自同一根线扇出，不存在任何消费者自己独立同步、
	// 延迟或另起一份拷贝的可能
	always @(posedge i_clk) begin
		if(i_rstn) begin
			if((ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.i_adc_idle !== i_adc_physical_idle) ||
				(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_adc_idle !== i_adc_physical_idle) ||
				(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.i_adc_idle !== i_adc_physical_idle) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.i_adc_idle !== i_adc_physical_idle) ||
				(ppg_control_top_Inst.ppg_system_fault_abort_supervisor_Inst.i_adc_physical_idle !== i_adc_physical_idle)) begin
				$display("FAIL TOP-17 physical idle fanout mismatch at t=%0t", $time);
				cnt_error = cnt_error + 1;
			end
		end
	end

	//---------------NPA-01顶层精度透传监测进程---------------//
	// 全程持续核对新增顶层输出o_active_precision_mode与AMI转发内部线
	// ami_active_precision_mode_o逐位一致，用真实仿真证据确认这条纯组合透传
	// （V1.3新增）没有引入任何延迟或撕裂窗口，不是只看RTL赋值语句就下结论
	always @(posedge i_clk) begin
		if(i_rstn) begin
			if(o_active_precision_mode !== ppg_control_top_Inst.ami_active_precision_mode_o) begin
				$display("FAIL NPA-01 o_active_precision_mode diverged from AMI-forwarded internal wire at t=%0t top=%b internal=%b",
					$time, o_active_precision_mode, ppg_control_top_Inst.ami_active_precision_mode_o);
				cnt_error = cnt_error + 1;
			end
		end
	end

	//---------------全局看门狗进程---------------//
	// 防止任何未预期的挂死导致仿真永不收敛
	initial begin
		flag_global_timeout = 1'b0;
		#12000000;
		flag_global_timeout = 1'b1;
		$display("FAIL SMOKE global watchdog timeout, forcing finish");
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主测试序列---------------//
	initial begin
		i_rstn = 1'b0;
		i_source_rstn = 1'b0;
		i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
		i_source_config_update_event = 1'b0;
		i_source_characterization_update_valid = 1'b0;
		i_source_static_characterization_enable = 1'b0;
		i_source_test_mux_ctrl = 5'd0;
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
		cnt_error = 0;
		// ABCD F-024/F-014（TB本地名PARAM-FIXED/PARAM-WDOG）：控制顶层参数为产品固定值，仿真开始即按层次读取实际例化值核对，
		// 防止有人改了顶层参数后因端口位宽不匹配只告警、被静默截断；看门狗参数另核合法性CYCLES>=1且WIDTH>=$clog2(CYCLES+1)
		if((ppg_control_top_Inst.C_CONFIG_WIDTH == 1024) && (ppg_control_top_Inst.C_CONFIG_EPOCH_WIDTH == 8) && (ppg_control_top_Inst.C_COEF_EPOCH_WIDTH == 8) &&
			(ppg_control_top_Inst.C_DC_RECOVERY_EPOCH_WIDTH == 8) && (ppg_control_top_Inst.C_CODE_EPOCH_WIDTH == 4) && (ppg_control_top_Inst.C_RUN_GENERATION_WIDTH == 8) &&
			(ppg_control_top_Inst.C_FRAME_ID_WIDTH == 16) && (ppg_control_top_Inst.C_SAMPLE_INDEX_WIDTH == 16) &&
			(ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.C_CONFIG_WIDTH == 1024) && (ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.C_RUN_GENERATION_WIDTH == 8) &&
			(ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_cdc_bridge_Inst.C_CONFIG_WIDTH == 1024))begin
			$display("PASS PARAM-FIXED control-top parameters equal the frozen product values (config 1024, epochs 8/8/8, code epoch 4, generation 8, frame/sample 16/16, manager and CDC bridge 1024/8)");
		end else begin
			$display("FAIL PARAM-FIXED control-top parameter differs from the frozen product value: config=%0d cfg_ep=%0d coef_ep=%0d dc_ep=%0d code_ep=%0d gen=%0d mgr_cfg=%0d mgr_gen=%0d bridge_cfg=%0d",
				ppg_control_top_Inst.C_CONFIG_WIDTH, ppg_control_top_Inst.C_CONFIG_EPOCH_WIDTH, ppg_control_top_Inst.C_COEF_EPOCH_WIDTH, ppg_control_top_Inst.C_DC_RECOVERY_EPOCH_WIDTH, ppg_control_top_Inst.C_CODE_EPOCH_WIDTH, ppg_control_top_Inst.C_RUN_GENERATION_WIDTH,
				ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.C_CONFIG_WIDTH, ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_manager_Inst.C_RUN_GENERATION_WIDTH, ppg_control_top_Inst.ppg_active_v4_control_plane_integration_Inst.config_cdc_bridge_Inst.C_CONFIG_WIDTH);
			cnt_error = cnt_error + 1;
		end
		if((ppg_control_top_Inst.ppg_system_fault_abort_supervisor_Inst.C_ADC_DRAIN_WATCHDOG_CYCLES == 5000) && (ppg_control_top_Inst.ppg_system_fault_abort_supervisor_Inst.C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH == 13) &&
			(ppg_control_top_Inst.ppg_system_fault_abort_supervisor_Inst.C_ADC_DRAIN_WATCHDOG_CYCLES >= 1) && (ppg_control_top_Inst.ppg_system_fault_abort_supervisor_Inst.C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH >= $clog2(ppg_control_top_Inst.ppg_system_fault_abort_supervisor_Inst.C_ADC_DRAIN_WATCHDOG_CYCLES + 1)))begin
			$display("PASS PARAM-WDOG supervisor watchdog parameters are the frozen 5000/13 and legal (width >= clog2(cycles+1))");
		end else begin
			$display("FAIL PARAM-WDOG supervisor watchdog parameters cycles=%0d width=%0d are not the frozen legal 5000/13", ppg_control_top_Inst.ppg_system_fault_abort_supervisor_Inst.C_ADC_DRAIN_WATCHDOG_CYCLES, ppg_control_top_Inst.ppg_system_fault_abort_supervisor_Inst.C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH);
			cnt_error = cnt_error + 1;
		end
		cnt_measurement_result_valid = 0;
		flag_run_phase_active = 1'b0;
		flag_debug_ami_capture_trace = 1'b0;
		cnt_debug_ami_capture_trace = 0;
		flag_debug_q3_trace = 1'b0;
		flag_debug_idle_trace = 1'b0;

		// SMOKE-01：两域复位释放，确认复位后回到CONFIG且无残留事件
		repeat(3) @(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_CONFIG) || o_commit_ack_event || o_error_event || o_start_ack_event || o_stop_ack_event) begin
			$display("FAIL SMOKE-01 reset isolation");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-01 reset isolation");
		end
		// TOP-01新增："SSW为安全向量"这半句此前全项目零断言。SSW的
		// reg_control_vector异步复位清零（ppg_sar9_sar15_safe_selection_wrapper.v:604，
		// 该行注释本身就写着"复位后SSW为安全向量"并带@satisfies: TOP-01标签），
		// o_s_in是它的一个字段切片，安全向量即全零
		if(o_s_in !== 5'b00000) begin
			$display("FAIL TOP-01 SSW o_s_in is not the safe all-zero vector after reset, observed=%b", o_s_in);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-01 SSW o_s_in is the safe all-zero vector after reset");
		end
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;

		// NPA-02：验证新增顶层端口o_source_config_update_ready的忙碌节流语义——
		// 复位后先确认它闲时为1，随后在真实CDC事务在途（o_source_config_update_ready=0）
		// 期间故意打第二次i_source_config_update_event（内容明显不同的配置），确认
		// 被ppg_config_cdc_bridge.v第127/138行"flag_source_busy==1时source域既不
		// 锁存新快照也不翻转请求代际"真实静默丢弃，不产生第二次COMMIT；最终依赖
		// 紧随其后的SMOKE-02在o_config_epoch上的检查，证明全程只发生过一次真实提交
		if(o_source_config_update_ready !== 1'b1) begin
			$display("FAIL NPA-02 precondition: o_source_config_update_ready not idle-high before first pulse");
			cnt_error = cnt_error + 1;
		end
		task_build_normal_manual_config; // 构造第一笔、也是唯一应当被接受的合法配置
		task_pulse_source_update; // 发起真实CDC事务，source域立即进入忙碌
		if(o_source_config_update_ready !== 1'b0) begin
			$display("FAIL NPA-02 busy window never observed after first pulse -- rejection test would be vacuous, o_source_config_update_ready=%b", o_source_config_update_ready);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS NPA-02 busy window confirmed (o_source_config_update_ready=0) before attempting the rejected second pulse");
		end
		task_build_normal_search_config; // 构造内容明显不同（idac_mode=SEARCH_TRACK）的第二笔配置，专门用于验证忙碌期间被拒绝
		task_pulse_source_update; // 忙碌期间再次发起，按ppg_config_cdc_bridge.v的忙碌锁存语义必须被静默丢弃

		// SMOKE-02：提交合法NORMAL双光MANUAL配置，确认COMMIT被接受
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY) || (o_config_epoch != 8'd1)) begin
			$display("FAIL SMOKE-02 legal NORMAL MANUAL commit");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-02 legal NORMAL MANUAL commit");
		end
		if(o_config_epoch != 8'd1) begin
			$display("FAIL NPA-02 busy-window second pulse was not rejected -- config_epoch=%0d indicates it was merged or queued as a real second commit", o_config_epoch);
			cnt_error = cnt_error + 1;
		end else begin
			// o_commit_ack_event只反映destination域manager已接受config_transport_update_o；
			// o_source_config_update_ready要等这次ack再经ppg_config_cdc_bridge.v的
			// flag_ack_sync_meta/flag_ack_sync两级同步器真正传回source域才会清忙碌，
			// 这是比commit_ack_event更晚的独立事件，不应假设两者同拍——首次实测已经
			// 证实同拍检查是本TB自己的时序假设错误，不是DUT缺陷，改成有界轮询
			cnt_npa02_ready_wait = 0;
			while((o_source_config_update_ready !== 1'b1) && (cnt_npa02_ready_wait < 64)) begin
				@(posedge i_source_clk);
				#1;
				cnt_npa02_ready_wait = cnt_npa02_ready_wait + 1;
			end
			if(o_source_config_update_ready !== 1'b1) begin
				$display("FAIL NPA-02 o_source_config_update_ready never returned to idle-high within 64 source_clk cycles after the real commit completed");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS NPA-02 busy-window second pulse correctly ignored (config_epoch=1) and o_source_config_update_ready polarity confirmed correct on both edges (ready returned after %0d source_clk cycle(s))", cnt_npa02_ready_wait);
			end
		end

		// SMOKE-03：START被接受并进入RUN，供应商供电就绪聚合已恒1
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_RUN) || o_system_fault_blocking) begin
			$display("FAIL SMOKE-03 START accepted into RUN");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-03 START accepted into RUN");
		end
		flag_run_phase_active = 1'b1;

		// SMOKE-04：在RUN期间等待若干笔真实Q3门控ADC事务完成，覆盖MANUAL模式下的
		// NORMAL双光测量链路，确认正式结果确实产生
		while((cnt_adc_response < 6) && !flag_global_timeout) begin
			@(posedge i_clk);
		end
		if(cnt_adc_response < 6) begin
			$display("FAIL SMOKE-04 insufficient real ADC responses observed");
			cnt_error = cnt_error + 1;
		end else if(cnt_measurement_result_valid < 1) begin
			$display("FAIL SMOKE-04 no formal measurement result observed");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-04 real ADC responses=%0d measurement_result_valid=%0d", cnt_adc_response, cnt_measurement_result_valid);
		end

		// SMOKE-05：STOP被接受，系统排空回到CONFIG（manager STOPPING排空完成后的
		// 唯一目标态是ST_CONFIG，不是ST_READY——数字与模拟均安全后才允许重新配置）
		// 且无阻断故障残留
		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-05 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
					if((cnt_drain_wait % 500) == 0) begin
						$display("DIAG t=%0t cnt=%0d lifecycle=%b sched_idle=%b frame_active=%b macro_tick=%0d started=%b stop_drain=%b inflight=%b inflight_discard=%b q3=%b adc_resp=%0d",
							$time, cnt_drain_wait, o_lifecycle_state, o_scheduler_idle,
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE],
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o,
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_STARTED],
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_STOP_DRAIN],
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT],
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_DISCARD],
							o_clk_q3_low, cnt_adc_response);
					end
	end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-05 drain back to CONFIG timeout, final lifecycle=%b sched_idle=%b ami_datapath_empty=%b ssw_wrapper_idle=%b adc_physical_idle=%b",
						o_lifecycle_state, o_scheduler_idle, o_ami_datapath_empty, o_ssw_wrapper_idle, i_adc_physical_idle);
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-05 unexpected system fault blocking after STOP");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-05 STOP drained back to CONFIG without fault");
		end

		// TOP-02新增：V4字段合法但V5字段非法（保留位段非零）时，整份1024-bit联合快照
		// 必须原子拒绝——config_epoch不递增、ACTIVE配置不受影响。此前SMOKE-02/03只测过
		// "V4/V5均合法"这一条正向路径，全项目零"一方非法"负向测试。此刻系统刚drain回
		// ST_CONFIG（SMOKE-05验证过），是一次干净的COMMIT尝试窗口
		cnt_top02_epoch_before = o_config_epoch;
		task_build_normal_manual_config;              // 复用合法V4字段
		i_source_config_snapshot[1023:1010] = 14'd1;  // 只破坏V5保留位段（ppg_system_config_manager.v:340要求全零），V4字段保持合法
		task_pulse_source_update;
		task_wait_config_result;
		if(o_commit_ack_event || !o_error_event || (o_config_epoch != cnt_top02_epoch_before)) begin
			$display("FAIL TOP-02 illegal V5 reserved field must reject whole snapshot atomically, commit=%b error=%b epoch_before=%0d epoch_after=%0d",
				o_commit_ack_event, o_error_event, cnt_top02_epoch_before, o_config_epoch);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-02 illegal V5 reserved field correctly rejected atomically, epoch unchanged at %0d, ACTIVE config preserved", o_config_epoch);
		end
		// manager的error_sticky是真正的W1C sticky，不会被下一次合法COMMIT自动带走
		// （同SMOKE-20->21之间已踩过的坑，见V1.2 changelog）；这里显式清一次，
		// 避免我方才这次故意的非法提交静默挡住紧接着SMOKE-06的合法COMMIT
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1;
		i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);

		// SMOKE-06：重新COMMIT+START后，恰好在ADC owner已提交（B_INFLIGHT=1，
		// context已接管且owner已经建立，但真实DONE尚未到达）的时刻发STOP。这是
		// V1.6修复覆盖的另一条独立路径：B_INFLIGHT=1时STOP只标记INFLIGHT_DISCARD，
		// 排空要等真实DONE到达后按discard旁带释放，而不是靠tick自然推进；本场景
		// 之前从未真正仿真验证过（SMOKE-05观测到的死锁场景B_INFLIGHT恒为0）
		task_build_normal_manual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-06 re-commit before inflight-stop scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-06 re-commit before inflight-stop scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		// 请求下一次真实ADC响应先暂停在Q3释放之后，构造owner已提交待DONE的窗口
		flag_hold_next_adc_response = 1'b1;
		fork
			begin : wait_response_held
				integer cnt_wait_hold;
				cnt_wait_hold = 0;
				while((flag_adc_response_held == 1'b0) && (cnt_wait_hold < 20000)) begin
					@(posedge i_clk);
					cnt_wait_hold = cnt_wait_hold + 1;
				end
				if(flag_adc_response_held == 1'b0) begin
					$display("FAIL SMOKE-06 bg_responder never held before Q3-released response");
					cnt_error = cnt_error + 1;
				end
			end
		join

		// 确认此刻真实owner确实已在途（B_INFLIGHT=1），这是本场景要覆盖的精确时序窗口，
		// 不是靠猜测的延时凑出来的
		if(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
			$display("FAIL SMOKE-06 B_INFLIGHT not actually 1 when STOP about to fire");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-06 confirmed B_INFLIGHT=1 before STOP");
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop; // STOP恰好命中owner已提交但未完成DONE的窗口
		// stop_ack是STOP被接受进入STOPPING的单拍边沿事件，必须与释放暂停响应
		// 并发监测，不能先delay几拍再开始等待，否则会错过这个单拍脉冲
		fork
			begin : smoke06_release_hold
				repeat(6) @(posedge i_clk);
				#1;
				flag_hold_next_adc_response = 1'b0; // 放行被暂停的真实DONE，STOP之后才真正完成
			end
			begin : smoke06_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-06 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke06_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
					if((cnt_drain_wait % 500) == 0) begin
						$display("DIAG SMOKE-06 drain t=%0t cnt=%0d lifecycle=%b overlap_valid=%b recon_valid=%b dc_valid=%b detect_pending=%b meas_pending=%b result_valid=%b discard_ev=%b",
							$time, cnt_drain_wait, o_lifecycle_state,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_overlap_result_valid,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_reconstructor_result_valid,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_dc_result_valid,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_detection_pending,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_measurement_pending,
							o_measurement_result_valid, o_measurement_result_discard_event);
					end
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-06 inflight-stop drain back to CONFIG timeout, final lifecycle=%b sched_idle=%b",
						o_lifecycle_state, o_scheduler_idle);
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-06 unexpected system fault blocking after inflight-STOP");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-06 STOP-with-owner-inflight drained back to CONFIG without fault");
		end

		// SMOKE-07：重新COMMIT+START后，RUN期间直接以外部i_control_abort_event
		// 撤销控制，而不是走STOP。验证V1.6修复没有意外改变abort分支行为——abort应
		// 该立即清零B_FRAME_ACTIVE/B_FRAME_MODE（与SSW侧context立即失效同拍），仍
		// 然干净收敛回CONFIG且无阻断故障残留；abort路径本轮之前从未真正驱动过
		task_build_normal_manual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-07 re-commit before abort scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-07 re-commit before abort scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : smoke07_wait_responses
			integer cnt_target_response;
			cnt_target_response = cnt_adc_response + 3;
			while((cnt_adc_response < cnt_target_response) && !flag_global_timeout) begin
				@(posedge i_clk);
			end
			if(cnt_adc_response < cnt_target_response) begin
				$display("FAIL SMOKE-07 insufficient real ADC responses before abort");
				cnt_error = cnt_error + 1;
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_abort; // 外部abort，而不是STOP

		fork
			begin : smoke07_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-07 abort-drain stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke07_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-07 abort drain back to CONFIG timeout, final lifecycle=%b sched_idle=%b",
						o_lifecycle_state, o_scheduler_idle);
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-07 unexpected system fault blocking after abort");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-07 abort drained back to CONFIG without fault");
		end

		// SMOKE-08：重新COMMIT+START，本次改用SEARCH_TRACK idac_mode触发真实
		// AMB/DCS自动校准请求，等待真实校准宏帧窗口打开（B_FRAME_ACTIVE=1且
		// dec_frame_mode==FRAME_MODE_CAL）后恰好在窗口内发STOP。V1.6修复机制在
		// 代码结构上对NORMAL和校准宏帧一视同仁（同一个if(state_current[B_FRAME_ACTIVE])
		// tick推进分支），但本轮MANUAL模式的场景从未真正触发过自动校准，这条路径
		// 之前只是代码走读推断，没有真实仿真验证过
		task_build_normal_search_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-08 re-commit before calibration-window-stop scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-08 re-commit before calibration-window-stop scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		fork
			begin : smoke08_wait_cal_window
				integer cnt_wait_cal;
				cnt_wait_cal = 0;
				while(!(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE] &&
						(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode == ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.FRAME_MODE_CAL))
						&& (cnt_wait_cal < 60000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_cal = cnt_wait_cal + 1;
					if((cnt_wait_cal % 200) == 0) begin
						$display("DIAG SMOKE-08 waiting_cal t=%0t cnt=%0d idac_state=%0d cal_req_pending=%b cal_req_active=%b frame_active=%b frame_mode=%b amb_pending=%b amb_seq_busy=%b ctrl_fault=%b",
							$time, cnt_wait_cal,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_PENDING],
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_CAL_REQ_ACTIVE],
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE],
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_pending_valid,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sequence_busy,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_controller_fault_blocking);
					end
				end
				if(!(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE] &&
						(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode == ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.FRAME_MODE_CAL))) begin
					$display("FAIL SMOKE-08 real calibration window never opened under SEARCH_TRACK, cnt_wait_cal=%0d", cnt_wait_cal);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS SMOKE-08 real calibration window opened at t=%0t after %0d cycles", $time, cnt_wait_cal);
				end
			end
		join

		flag_run_phase_active = 1'b0;
		task_pulse_stop; // STOP恰好命中已经打开的校准波形窗口

		fork
			begin : smoke08_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-08 calibration-window stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke08_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
					if((cnt_drain_wait % 500) == 0) begin
						$display("DIAG SMOKE-08 drain t=%0t cnt=%0d lifecycle=%b sched_idle=%b frame_active=%b frame_mode=%b macro_tick=%0d cal_local_tick=%0d",
							$time, cnt_drain_wait, o_lifecycle_state, o_scheduler_idle,
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE],
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode,
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o,
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.calibration_local_tick_o);
					end
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-08 calibration-window-stop drain back to CONFIG timeout, final lifecycle=%b sched_idle=%b",
						o_lifecycle_state, o_scheduler_idle);
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-08 unexpected system fault blocking after calibration-window STOP");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-08 STOP-during-calibration-window drained back to CONFIG without fault");
		end

		// SMOKE-09（TOP-16）：重新COMMIT+START后，故意长时间悬置一笔真实ADC owner
		// （已经真实观察到Q3释放、owner已在途）的响应，验证owner release只能由
		// 真实CLK_DOUT同步+RAW捕获+sample_index匹配后的AMI旁带触发，不存在任何
		// 基于Q3窗口结束、macro tick或固定延时的捷径释放——长时间悬置期间
		// B_INFLIGHT必须保持1、不能产生任何正式测量结果，真实DONE到达后才释放
		task_build_normal_manual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-09 re-commit before TOP-16 no-shortcut-release scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-09 re-commit before TOP-16 no-shortcut-release scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		flag_hold_next_adc_response = 1'b1;
		fork
			begin : smoke09_wait_response_held
				integer cnt_wait_hold;
				cnt_wait_hold = 0;
				while((flag_adc_response_held == 1'b0) && (cnt_wait_hold < 20000)) begin
					@(posedge i_clk);
					cnt_wait_hold = cnt_wait_hold + 1;
				end
				if(flag_adc_response_held == 1'b0) begin
					$display("FAIL SMOKE-09 bg_responder never held before Q3-released response");
					cnt_error = cnt_error + 1;
				end
			end
		join

		if(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
			$display("FAIL SMOKE-09 B_INFLIGHT not actually 1 before long hold");
			cnt_error = cnt_error + 1;
		end

		begin : smoke09_long_hold
			integer cnt_long_hold;
			integer cnt_meas_before_hold;
			reg flag_hold_case_ok;
			cnt_meas_before_hold = cnt_measurement_result_valid;
			flag_hold_case_ok = 1'b1;
			for(cnt_long_hold = 0; cnt_long_hold < 3000; cnt_long_hold = cnt_long_hold + 1) begin
				@(posedge i_clk);
				if(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					flag_hold_case_ok = 1'b0;
				end
			end
			if(!flag_hold_case_ok) begin
				$display("FAIL SMOKE-09 owner released without real CLK_DOUT during long hold");
				cnt_error = cnt_error + 1;
			end else if(cnt_measurement_result_valid != cnt_meas_before_hold) begin
				$display("FAIL SMOKE-09 spurious measurement result produced during long hold");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-09 owner stayed inflight for 3000 cycles with no shortcut release");
			end
		end

		flag_hold_next_adc_response = 1'b0;
		begin : smoke09_confirm_real_release
			integer cnt_release_wait;
			cnt_release_wait = 0;
			while(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] && (cnt_release_wait < 64)) begin
				@(posedge i_clk);
				cnt_release_wait = cnt_release_wait + 1;
			end
			if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
				$display("FAIL SMOKE-09 real CLK_DOUT release timeout after hold released");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-09 real CLK_DOUT promptly released owner once delivered");
			end
		end
		flag_run_phase_active = 1'b0;

		// SMOKE-10（TOP-17）：物理idle电平抖动不得被解释成完成——在owner真实在途、
		// 后台响应被悬置期间，手动扰动i_adc_physical_idle（不伴随任何真实RAW/
		// CLK_DOUT数据），验证这种抖动本身绝不会被系统当成一次完成、不会让owner
		// 提前释放、也不会产生任何正式测量结果；之后放行真实响应，确认协议仍然
		// 正常完成。TOP-17的"单一真源同源扇出"这一半由本文件顶部的持续监测进程
		// 全程覆盖，这里补的是"数字流水idle不得替代物理idle语义"这一半
		flag_hold_next_adc_response = 1'b1;
		fork
			begin : smoke10_wait_response_held
				integer cnt_wait_hold;
				cnt_wait_hold = 0;
				while((flag_adc_response_held == 1'b0) && (cnt_wait_hold < 20000)) begin
					@(posedge i_clk);
					cnt_wait_hold = cnt_wait_hold + 1;
				end
				if(flag_adc_response_held == 1'b0) begin
					$display("FAIL SMOKE-10 bg_responder never held before Q3-released response");
					cnt_error = cnt_error + 1;
				end
			end
		join

		begin : smoke10_idle_perturbation
			integer cnt_meas_before_perturb;
			integer flag_inflight_before_perturb;
			cnt_meas_before_perturb = cnt_measurement_result_valid;
			flag_inflight_before_perturb = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT];
			// 手动抖动物理idle电平，完全不触碰RAW/CLK_DOUT——纯粹的数字idle噪声
			@(negedge i_clk);
			i_adc_physical_idle = 1'b0;
			repeat(3) @(negedge i_clk);
			i_adc_physical_idle = 1'b1;
			repeat(3) @(negedge i_clk);
			i_adc_physical_idle = 1'b0;
			repeat(3) @(negedge i_clk);
			i_adc_physical_idle = 1'b1;
			repeat(4) @(posedge i_clk);
			if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] != flag_inflight_before_perturb) begin
				$display("FAIL SMOKE-10 idle perturbation changed owner inflight state");
				cnt_error = cnt_error + 1;
			end else if(cnt_measurement_result_valid != cnt_meas_before_perturb) begin
				$display("FAIL SMOKE-10 idle perturbation produced a spurious measurement result");
				cnt_error = cnt_error + 1;
			end else if(o_system_fault_blocking) begin
				$display("FAIL SMOKE-10 idle perturbation triggered unexpected system fault blocking");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-10 physical idle perturbation alone did not fabricate completion");
			end
		end

		flag_hold_next_adc_response = 1'b0;
		begin : smoke10_confirm_real_release
			integer cnt_release_wait;
			cnt_release_wait = 0;
			while(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] && (cnt_release_wait < 64)) begin
				@(posedge i_clk);
				cnt_release_wait = cnt_release_wait + 1;
			end
			if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
				$display("FAIL SMOKE-10 real CLK_DOUT release timeout after idle perturbation test");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-10 protocol completed normally after idle perturbation test");
			end
		end

		// SMOKE-11（TOP-18，NORMAL模式正向部分）：确认NORMAL RUN期间analog_run_enable
		// 只送SSW且为高有效、measurement_run_enable只送Scheduler/AMI且为高有效——
		// 这两个内部网在NORMAL RUN下都应为1，真实测量活动的存在本身已经隐含证明了
		// 这一点，这里做成显式断言而不是只靠隐含证据。STATIC_BIAS下两者应强制为0
		// 的反向部分，留到Tier 3做STATIC_BIAS场景时一并验证，避免这里重复摸索
		// STATIC_BIAS配置字段，浪费两次调查成本
		if(!ppg_control_top_Inst.analog_run_enable || !ppg_control_top_Inst.measurement_run_enable) begin
			$display("FAIL SMOKE-11 NORMAL RUN analog/measurement_run_enable not both 1, analog=%b measurement=%b",
				ppg_control_top_Inst.analog_run_enable, ppg_control_top_Inst.measurement_run_enable);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-11 NORMAL RUN analog_run_enable and measurement_run_enable both 1");
		end

		// 收尾SMOKE-09~11这一整个RUN episode：STOP并排空回CONFIG，否则SMOKE-12
		// 的COMMIT会撞见非CONFIG状态被拒绝（ERROR_COMMIT_STATE）
		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke11_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-11 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke11_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-11 drain back to CONFIG timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join

		// SMOKE-12（TOP-13）：纯RED固定SAR9——重新COMMIT+START，CHARACTERIZATION+
		// PHOTODIODE+RED_ONLY+SAR9（MGR-17合法组合），验证每帧仅一笔RED事务、
		// AMB/DC_R全程取SPI committed码（MANUAL模式恒为amb_manual_code/
		// dcs_r_manual_code，不发生任何搜索改码）、全程无IR事务
		task_build_char_photodiode_red_sar9_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-12 re-commit before TOP-13 RED-SAR9 scenario, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-12 re-commit before TOP-13 RED-SAR9 scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : smoke12_red_sar9_window
			integer cnt_frame_before;
			integer cnt_red_before;
			integer cnt_ir_before;
			integer cnt_frame_delta;
			integer cnt_red_delta;
			integer cnt_ir_delta;
			integer cnt_wait_frames;
			cnt_frame_before = cnt_macro_frame_start;
			cnt_red_before = cnt_red_response;
			cnt_ir_before = cnt_ir_response;
			cnt_wait_frames = 0;
			while((cnt_macro_frame_start < (cnt_frame_before + 3)) && (cnt_wait_frames < 20000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_frames = cnt_wait_frames + 1;
			end
			cnt_frame_delta = cnt_macro_frame_start - cnt_frame_before;
			cnt_red_delta = cnt_red_response - cnt_red_before;
			cnt_ir_delta = cnt_ir_response - cnt_ir_before;
			if(cnt_frame_delta < 3) begin
				$display("FAIL SMOKE-12 insufficient macro frame starts observed, delta=%0d", cnt_frame_delta);
				cnt_error = cnt_error + 1;
			end else if(cnt_ir_delta != 0) begin
				$display("FAIL SMOKE-12 unexpected IR transaction observed under OPTICAL_RED, count=%0d", cnt_ir_delta);
				cnt_error = cnt_error + 1;
			end else if(cnt_red_delta != cnt_frame_delta) begin
				$display("FAIL SMOKE-12 RED transaction count does not match one-per-frame, frame_delta=%0d red_delta=%0d", cnt_frame_delta, cnt_red_delta);
				cnt_error = cnt_error + 1;
			end else if((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_amb_code != 8'd64) ||
					(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_dcs_r_code != 8'd80)) begin
				$display("FAIL SMOKE-12 AMB/DC_R code drifted from SPI committed value, amb=%0d dcs_r=%0d",
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_amb_code,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_dcs_r_code);
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
				// 不能只信bg_responder"响应过"这个动作本身——必须确认owner真的被
				// 消费释放了，否则会像TOP-14 SAR15那次一样，响应次数对上了但实际
				// 从未真正完成过
				$display("FAIL SMOKE-12 owner still inflight after final response, real completion never happened");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-12 pure RED fixed SAR9: %0d frames, exactly one RED transaction each, no IR, committed AMB/DC_R codes held, owner cleanly released", cnt_frame_delta);
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke12_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-12 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke12_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-12 drain back to CONFIG timeout after RED-SAR9 scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join

		// SMOKE-13（TOP-14）：纯RED固定SAR15——重新COMMIT+START，CHARACTERIZATION+
		// PHOTODIODE+RED_ONLY+SAR15（MGR-17合法组合），验证整个RUN固定SAR15、无
		// fine-window切换事件、每帧仅一笔RED事务
		task_build_char_photodiode_red_sar15_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-13 re-commit before TOP-14 RED-SAR15 scenario, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-13 re-commit before TOP-14 RED-SAR15 scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : smoke13_red_sar15_window
			integer cnt_frame_before;
			integer cnt_red_before;
			integer cnt_ir_before;
			integer cnt_frame_delta;
			integer cnt_red_delta;
			integer cnt_ir_delta;
			integer cnt_wait_frames;
			cnt_frame_before = cnt_macro_frame_start;
			cnt_red_before = cnt_red_response;
			cnt_ir_before = cnt_ir_response;
			cnt_wait_frames = 0;
			while((cnt_macro_frame_start < (cnt_frame_before + 3)) && (cnt_wait_frames < 20000) && !flag_global_timeout) begin
				@(posedge i_clk);
				// 只在真正见过至少一个宏帧起点之后才检查精度——B_FRAME_PRECISION在
				// 第一个宏帧真正开始锁存i_active_precision_mode之前读到的是复位默认值，
				// 不代表精度"掉出了SAR15"
				if((cnt_macro_frame_start > cnt_frame_before) &&
					(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_PRECISION] != 1'b1)) begin
					$display("FAIL SMOKE-13 precision dropped out of SAR15 mid-run at t=%0t", $time);
					cnt_error = cnt_error + 1;
					cnt_wait_frames = 20000;
				end
				cnt_wait_frames = cnt_wait_frames + 1;
			end
			cnt_frame_delta = cnt_macro_frame_start - cnt_frame_before;
			cnt_red_delta = cnt_red_response - cnt_red_before;
			cnt_ir_delta = cnt_ir_response - cnt_ir_before;
			if(cnt_frame_delta < 3) begin
				$display("FAIL SMOKE-13 insufficient macro frame starts observed, delta=%0d", cnt_frame_delta);
				cnt_error = cnt_error + 1;
			end else if(cnt_ir_delta != 0) begin
				$display("FAIL SMOKE-13 unexpected IR transaction observed under OPTICAL_RED, count=%0d", cnt_ir_delta);
				cnt_error = cnt_error + 1;
			end else if(cnt_red_delta != cnt_frame_delta) begin
				$display("FAIL SMOKE-13 RED transaction count does not match one-per-frame, frame_delta=%0d red_delta=%0d", cnt_frame_delta, cnt_red_delta);
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
				// 同SMOKE-12：不能只信bg_responder"响应过"这个动作本身，必须确认
				// owner真的被消费释放了
				$display("FAIL SMOKE-13 owner still inflight after final response, real completion never happened");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-13 pure RED fixed SAR15: %0d frames, exactly one RED transaction each, no IR, precision stayed SAR15 throughout, owner cleanly released", cnt_frame_delta);
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke13_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-13 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke13_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
					if((cnt_drain_wait % 500) == 0) begin
						$display("DIAG SMOKE-13 drain t=%0t cnt=%0d ami_inflight=%b capture_valid=%b s1_detect_valid=%b calibrated_valid=%b adc_response_cnt=%0d",
							$time, cnt_drain_wait,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_adc_transaction_inflight,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_capture_valid,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_s1_detect_valid,
							ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_calibrated_valid,
							cnt_adc_response);
					end
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-13 drain back to CONFIG timeout after RED-SAR15 scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join

		// SMOKE-14（TOP-15）：双光共享包络——重新COMMIT+START，optical_mode=
		// OPTICAL_BOTH，验证RED/IR交替事务持续产生、ADC结果事务始终严格单笔
		// 在途（B_INFLIGHT与B_INFLIGHT不重入），两色都真实出现过
		task_build_normal_manual_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-14 re-commit before TOP-15 dual-optical scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-14 re-commit before TOP-15 dual-optical scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : smoke14_dual_window
			integer cnt_red_before;
			integer cnt_ir_before;
			integer cnt_red_delta;
			integer cnt_ir_delta;
			integer cnt_wait_responses;
			cnt_red_before = cnt_red_response;
			cnt_ir_before = cnt_ir_response;
			cnt_wait_responses = 0;
			while(((cnt_red_response - cnt_red_before) < 3 || (cnt_ir_response - cnt_ir_before) < 3) && (cnt_wait_responses < 60000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_responses = cnt_wait_responses + 1;
			end
			cnt_red_delta = cnt_red_response - cnt_red_before;
			cnt_ir_delta = cnt_ir_response - cnt_ir_before;
			if((cnt_red_delta < 3) || (cnt_ir_delta < 3)) begin
				$display("FAIL SMOKE-14 dual-optical did not produce both colors, red=%0d ir=%0d owner_commit_red=%0d owner_commit_ir=%0d", cnt_red_delta, cnt_ir_delta, cnt_owner_commit_red, cnt_owner_commit_ir);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-14 dual-optical produced both RED (%0d) and IR (%0d) real transactions", cnt_red_delta, cnt_ir_delta);
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke14_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-14 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke14_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-14 drain back to CONFIG timeout after dual-optical scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-14 unexpected system fault blocking after dual-optical run");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-14 dual-optical drained back to CONFIG without fault");
		end

		// SMOKE-15（TOP-04）：AMB/DCS校准——SEARCH_TRACK真实触发校准请求，验证
		// 校准物理Q3窗口确实围绕SSW的CAL_Q3_TICK=266（合同"CAL Q3严格围绕中心266"），
		// 且校准波形快照在tick 0接管时确实取自当时真实候选码（能读到committed
		// AMB码的合法范围内的值，不是某个冻结/复用的旧值或X）
		task_build_normal_search_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-15 re-commit before TOP-04 calibration scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-15 re-commit before TOP-04 calibration scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		fork
			begin : smoke15_wait_cal_window
				integer cnt_wait_cal;
				cnt_wait_cal = 0;
				while(!(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE] &&
						(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode == ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.FRAME_MODE_CAL))
						&& (cnt_wait_cal < 60000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_cal = cnt_wait_cal + 1;
				end
				if(!(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_ACTIVE] &&
						(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.dec_frame_mode == ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.FRAME_MODE_CAL))) begin
					$display("FAIL SMOKE-15 real calibration window never opened under SEARCH_TRACK");
					cnt_error = cnt_error + 1;
				end
			end
		join

		begin : smoke15_wait_cal_response
			integer cnt_cal_before;
			integer cnt_wait_cal_response;
			cnt_cal_before = cnt_cal_response;
			cnt_wait_cal_response = 0;
			while((cnt_cal_response < (cnt_cal_before + 1)) && (cnt_wait_cal_response < 5000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_cal_response = cnt_wait_cal_response + 1;
			end
			if(cnt_cal_response < (cnt_cal_before + 1)) begin
				$display("FAIL SMOKE-15 no real calibration response observed after window opened");
				cnt_error = cnt_error + 1;
			end else if((reg_last_cal_local_tick < 10'd260) || (reg_last_cal_local_tick > 10'd272)) begin
				$display("FAIL SMOKE-15 calibration Q3 not centered on local tick 266, observed=%0d", reg_last_cal_local_tick);
				cnt_error = cnt_error + 1;
			end else if((reg_last_cal_amb_snapshot < 8'd8) || (reg_last_cal_amb_snapshot > 8'd240)) begin
				// 合法AMB候选码范围取自task_build_normal_manual_config里的amb_code_min/max
				// （8/240），落在这个区间内说明快照确实是一个真实候选码，不是X或越界的
				// 冻结旧值
				$display("FAIL SMOKE-15 calibration AMB snapshot out of legal candidate range, observed=%0d", reg_last_cal_amb_snapshot);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-15 calibration Q3 centered on local tick %0d, AMB snapshot=%0d within legal candidate range", reg_last_cal_local_tick, reg_last_cal_amb_snapshot);
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke15_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-15 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke15_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-15 drain back to CONFIG timeout after calibration scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-15 unexpected system fault blocking after calibration scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-15 calibration scenario drained back to CONFIG without fault");
		end

		// SMOKE-16（TOP-06，协议一致性部分）：重新COMMIT+START为CHARACTERIZATION+
		// RED_ONLY+SAR15，验证同一笔真实事务在AMI、scheduler和SSW三方各自锁存的
		// owner精度身份完全一致——这是TOP-06"AMI、调度器和SSW使用同一笔事务精度"
		// 这半句的直接验证。注意：TOP-06另一半"旧15-bit尾部不启动新事务"要求真实
		// 触发一次精度切换（SAR9<->SAR15），这需要基线穿越/波峰波谷检测算法真正
		// 判断出穿越点，而这需要真实PPG波形（不是我们目前的固定码激励）才能触发
		// ——按之前商定的顺序，这部分留给Phase 3真实波形生成器就绪后再补
		task_build_char_photodiode_red_sar15_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-16 re-commit before TOP-06 precision-consistency scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-16 re-commit before TOP-06 precision-consistency scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : smoke16_wait_response
			integer cnt_response_before;
			integer cnt_wait_response;
			cnt_response_before = cnt_adc_response;
			cnt_wait_response = 0;
			while((cnt_adc_response < (cnt_response_before + 1)) && (cnt_wait_response < 20000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_response = cnt_wait_response + 1;
			end
			if(cnt_adc_response < (cnt_response_before + 1)) begin
				$display("FAIL SMOKE-16 no real response observed");
				cnt_error = cnt_error + 1;
			end else if((reg_last_precision_scheduler != 1'b1) || (reg_last_precision_ssw != 1'b1) || (reg_last_precision_ami != 1'b1)) begin
				$display("FAIL SMOKE-16 precision mismatch across scheduler/SSW/AMI, scheduler=%b ssw=%b ami=%b",
					reg_last_precision_scheduler, reg_last_precision_ssw, reg_last_precision_ami);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-16 scheduler/SSW/AMI agree on SAR15 owner precision for the same real transaction");
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke16_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-16 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke16_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-16 drain back to CONFIG timeout after precision-consistency scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-16 unexpected system fault blocking after precision-consistency scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-16 precision-consistency scenario drained back to CONFIG without fault");
		end

		// SMOKE-17（TOP-05）：双通道反压——持续拉低i_measurement_result_ready制造
		// 正式输出侧反压，验证ADC owner层面的真实事务（Q1/Q2/Q3物理转换、身份匹配、
		// owner释放）仍然独立推进，不会被下游尚未消费的正式结果卡住；同时已经
		// 产生的正式结果必须持续保持valid、不能在下游还没消费时静默清零丢失
		task_build_normal_manual_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-17 re-commit before TOP-05 backpressure scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-17 re-commit before TOP-05 backpressure scenario");
		end

		i_measurement_result_ready = 1'b0; // 提前拉低，START之前就已经反压
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : smoke17_backpressure_window
			integer cnt_owner_before;
			integer cnt_wait_owner;
			integer cnt_seen_result_valid;
			integer cnt_drop_without_consume;
			reg flag_result_was_valid;
			cnt_owner_before = cnt_owner_commit_red + cnt_owner_commit_ir;
			cnt_wait_owner = 0;
			cnt_seen_result_valid = 0;
			cnt_drop_without_consume = 0;
			flag_result_was_valid = 1'b0;
			while(((cnt_owner_commit_red + cnt_owner_commit_ir) < (cnt_owner_before + 3)) && (cnt_wait_owner < 60000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_owner = cnt_wait_owner + 1;
				if(o_measurement_result_valid) begin
					cnt_seen_result_valid = cnt_seen_result_valid + 1;
					flag_result_was_valid = 1'b1;
				end else if(flag_result_was_valid) begin
					// i_measurement_result_ready全程为0，valid一旦拉高就不该在
					// 没有真实消费（ready&&valid同拍）的情况下自己掉回0——那样等于
					// 结果被静默丢弃
					cnt_drop_without_consume = cnt_drop_without_consume + 1;
					flag_result_was_valid = 1'b0;
				end
			end
			if((cnt_owner_commit_red + cnt_owner_commit_ir) < (cnt_owner_before + 3)) begin
				$display("FAIL SMOKE-17 ADC owner activity stalled under output backpressure, delta=%0d",
					(cnt_owner_commit_red + cnt_owner_commit_ir) - cnt_owner_before);
				cnt_error = cnt_error + 1;
			end else if(cnt_drop_without_consume != 0) begin
				$display("FAIL SMOKE-17 formal result valid silently dropped %0d time(s) without real consumption", cnt_drop_without_consume);
				cnt_error = cnt_error + 1;
			end else if(cnt_seen_result_valid == 0) begin
				$display("FAIL SMOKE-17 no formal result ever asserted valid under backpressure");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-17 ADC owner activity (%0d commits) progressed independently while output backpressured, held result never silently dropped",
					(cnt_owner_commit_red + cnt_owner_commit_ir) - cnt_owner_before);
			end
		end

		begin : smoke17_release_backpressure
			integer cnt_meas_before_release;
			integer cnt_wait_release;
			cnt_meas_before_release = cnt_measurement_result_valid;
			i_measurement_result_ready = 1'b1;
			cnt_wait_release = 0;
			while((cnt_measurement_result_valid < (cnt_meas_before_release + 1)) && (cnt_wait_release < 200) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_release = cnt_wait_release + 1;
			end
			if(cnt_measurement_result_valid < (cnt_meas_before_release + 1)) begin
				$display("FAIL SMOKE-17 held result never consumed after releasing backpressure");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-17 held result consumed promptly once output backpressure released");
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke17_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-17 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke17_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-17 drain back to CONFIG timeout after backpressure scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-17 unexpected system fault blocking after backpressure scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-17 backpressure scenario drained back to CONFIG without fault");
		end

		// SMOKE-18（TOP-07）：固定电流表征——CHARACTERIZATION+EXTERNAL_TEST_CURRENT+
		// OPTICAL_BOTH，验证EN_TEST=1、LEDEN1/2关闭、LEDDAC无有效驱动窗口，同时
		// SAR仍按正常NORMAL 400Hz间歇事务真实运行（RED/IR都真实产生事务，不是
		// 3200Hz连续快速校准也不是STATIC_BIAS）
		task_build_char_external_current_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-18 re-commit before TOP-07 fixed-current scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-18 re-commit before TOP-07 fixed-current scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		if(!o_en_test || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
			$display("FAIL SMOKE-18 fixed-current mode boundary wrong, en_test=%b leden1=%b leden2=%b leddac=%0d",
				o_en_test, o_leden1_low, o_leden2_low, o_leddac);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-18 fixed-current mode boundary correct: EN_TEST=1, LEDEN1/2=0, LEDDAC=0");
		end

		begin : smoke18_wait_both_colors
			integer cnt_red_before;
			integer cnt_ir_before;
			integer cnt_wait_responses;
			cnt_red_before = cnt_owner_commit_red;
			cnt_ir_before = cnt_owner_commit_ir;
			cnt_wait_responses = 0;
			while(((cnt_owner_commit_red - cnt_red_before) < 2 || (cnt_owner_commit_ir - cnt_ir_before) < 2) && (cnt_wait_responses < 60000) && !flag_global_timeout) begin
				@(posedge i_clk);
				if(!o_en_test || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
					$display("FAIL SMOKE-18 fixed-current mode boundary changed mid-run at t=%0t", $time);
					cnt_error = cnt_error + 1;
					cnt_wait_responses = 60000;
				end
				cnt_wait_responses = cnt_wait_responses + 1;
			end
			if(((cnt_owner_commit_red - cnt_red_before) < 2) || ((cnt_owner_commit_ir - cnt_ir_before) < 2)) begin
				$display("FAIL SMOKE-18 SAR did not keep producing normal intermittent RED/IR transactions, red=%0d ir=%0d",
					cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-18 SAR kept producing normal NORMAL-style intermittent RED (%0d) and IR (%0d) transactions under fixed current",
					cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke18_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-18 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke18_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-18 drain back to CONFIG timeout after fixed-current scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-18 unexpected system fault blocking after fixed-current scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-18 fixed-current scenario drained back to CONFIG without fault");
		end

		// lifecycle回到CONFIG不代表背景响应已经完全静默——STOP時可能恰好命中一笔
		// 在途owner，其真实DONE按V1.6被动drain机制稍后才到达；SMOKE-19要观察
		// "STATIC_BIAS下无真实ADC事务"，必须先确认上一场景的收尾响应已经真正
		// 结束，不能让它错误地被算成STATIC_BIAS期间的事务
		task_wait_response_quiescent(6500, 200000);

		// SMOKE-19（TOP-08/TOP-12）：STATIC_BIAS——先提交CHARACTERIZATION+
		// EXTERNAL_TEST_CURRENT的V4配置进入READY，再走独立表征控制CDC提交
		// static_characterization_enable=1和一笔真实测试MUX码，确认CDC真的
		// 接受（o_characterization_control_update_event），START后验证：
		// (a) 合同§6.2冻结的25个netlist静态向量信号逐位匹配；
		// (b) S[4:0]确实等于CDC已提交的测试MUX码；
		// (c) 全程无真实ADC事务（AMI/Scheduler保持空闲，帧计数不推进）
		task_build_static_bias_v4_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-19 V4 re-commit before STATIC_BIAS scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-19 V4 re-commit before STATIC_BIAS scenario");
		end

		task_commit_static_bias_characterization(5'b10101);
		begin : smoke19_wait_cdc_commit
			integer cnt_wait_cdc;
			cnt_wait_cdc = 0;
			while(!o_characterization_control_valid && (cnt_wait_cdc < 200)) begin
				@(posedge i_clk);
				cnt_wait_cdc = cnt_wait_cdc + 1;
			end
			if(!o_characterization_control_valid) begin
				$display("FAIL SMOKE-19 characterization CDC never reported control valid");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-19 characterization CDC accepted static_characterization_enable=1, test_mux=5'b10101");
			end
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		if(!o_en_test || !o_clk_buf_low || !o_clk_iref_idac_low || !o_clk_iref_idac_sar9_low ||
			!o_clk_iref_idac_sar15_low || !o_clk_aferst_low || !o_clk_tiaen_low ||
			!o_en_sar9_amb_low || !o_en_sar9_dc_low || !o_en_sar15_amb_low || !o_en_sar15_dc_low ||
			o_en_tia_low || o_en_sar9_iref || o_en_sar15_iref ||
			o_clk_9q1_low || o_clk_15q1_low || o_clk_q2_low || o_clk_q3_low || o_en_15sar_low ||
			(o_leddac != 8'h00) || o_leden1_low || o_leden2_low ||
			(o_idac_sar9ambn_low != 8'h00) || (o_idac_sar9dcn_low != 8'h00) ||
			(o_idac_sar15ambn_low != 8'h00) || (o_idac_sar15dcn_low != 8'h00)) begin
			$display("FAIL SMOKE-19 STATIC_BIAS netlist static vector mismatch");
			cnt_error = cnt_error + 1;
		end else if(o_s_in != 5'b10101) begin
			$display("FAIL SMOKE-19 S[4:0] does not match committed test_mux, observed=%b expected=10101", o_s_in);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-19 STATIC_BIAS netlist static vector and S[4:0]=%b match contract table", o_s_in);
		end

		begin : smoke19_no_adc_window
			integer cnt_owner_before;
			integer cnt_wait_idle;
			reg flag_vector_ok;
			reg flag_measurement_run_enable_ok; // TOP-18新增：STATIC_BIAS期间measurement_run_enable应保持为0
			reg flag_analog_run_enable_ok; // TOP-18新增：STATIC_BIAS期间analog_run_enable应继续跟随RUN为1（ppg_control_top.v:408注释：仍需建立静态向量），不是也被清0
			// 根因已经查清并在源头修复：之前观察到的"背景周期性idle抖动"不是
			// RTL问题，是bg_responder自己的wait_q3_release任务把"5600拍内没等到
			// Q3拉高"（CONFIG/STATIC_BIAS下Q3本来就不该开，这是合法状态）和
			// "真的等到Q3拉高"混为一谈，超时也照样往下走，凭空伪造一次响应。
			// 修复后bg_responder只在真正观察到Q3拉高时才响应，这里不再需要额外
			// 的settle等待或宽容窗口
			cnt_owner_before = cnt_owner_commit_total;
			flag_vector_ok = 1'b1;
			flag_measurement_run_enable_ok = 1'b1;
			flag_analog_run_enable_ok = 1'b1;
			for(cnt_wait_idle = 0; cnt_wait_idle < 4000; cnt_wait_idle = cnt_wait_idle + 1) begin
				@(posedge i_clk);
				if(!o_scheduler_idle || !o_ami_datapath_empty || !o_ssw_wrapper_idle) begin
					flag_vector_ok = 1'b0;
				end
				if(ppg_control_top_Inst.measurement_run_enable) begin
					flag_measurement_run_enable_ok = 1'b0; // TOP-18：STATIC_BIAS下measurement_run_enable必须为0
				end
				if(!ppg_control_top_Inst.analog_run_enable) begin
					flag_analog_run_enable_ok = 1'b0; // TOP-18：analog_run_enable应继续跟随RUN为1，不该被STATIC_BIAS清0
				end
			end
			if(cnt_owner_commit_total != cnt_owner_before) begin
				$display("FAIL SMOKE-19 unexpected real ADC owner commit during STATIC_BIAS, delta=%0d", cnt_owner_commit_total - cnt_owner_before);
				cnt_error = cnt_error + 1;
			end else if(!flag_vector_ok) begin
				$display("FAIL SMOKE-19 Scheduler/AMI/SSW did not stay idle throughout the steady-state STATIC_BIAS window, sched_idle=%b ami_empty=%b ssw_idle=%b", o_scheduler_idle, o_ami_datapath_empty, o_ssw_wrapper_idle);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-19 no real ADC owner commit and Scheduler/AMI/SSW stayed idle for 4000 steady-state cycles under STATIC_BIAS");
			end
			if(!flag_measurement_run_enable_ok) begin
				$display("FAIL SMOKE-19 TOP-18 STATIC_BIAS did not hold measurement_run_enable at 0 for all 4000 steady-state cycles");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-19 TOP-18 STATIC_BIAS held measurement_run_enable at 0 for 4000 steady-state cycles");
			end
			if(!flag_analog_run_enable_ok) begin
				$display("FAIL SMOKE-19 TOP-18 STATIC_BIAS incorrectly dropped analog_run_enable (must stay 1, following RUN, so SSW can keep driving the static vector)");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-19 TOP-18 STATIC_BIAS correctly kept analog_run_enable at 1 (following RUN) while measurement_run_enable stayed 0");
			end
		end
		flag_debug_idle_trace = 1'b0;
		flag_debug_q3_trace = 1'b0;

		// STATIC_BIAS运行期间允许原子更新test_mux_ctrl（合同9.1节），验证S[4:0]
		// 确实跟着新提交值同拍改变
		task_commit_static_bias_characterization(5'b01010);
		begin : smoke19_mux_update
			integer cnt_wait_update;
			cnt_wait_update = 0;
			while((o_s_in != 5'b01010) && (cnt_wait_update < 200)) begin
				@(posedge i_clk);
				cnt_wait_update = cnt_wait_update + 1;
			end
			if(o_s_in != 5'b01010) begin
				$display("FAIL SMOKE-19 S[4:0] did not follow runtime test_mux update, observed=%b", o_s_in);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-19 S[4:0] followed runtime test_mux_ctrl update to %b during STATIC_BIAS RUN", o_s_in);
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke19_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-19 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke19_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-19 drain back to CONFIG timeout after STATIC_BIAS scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-19 unexpected system fault blocking after STATIC_BIAS scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-19 STATIC_BIAS scenario drained back to CONFIG without fault");
		end

		// SMOKE-20（TOP-19）：STATIC_BIAS资格唯一所有权——表征CDC里
		// static_characterization_enable仍保持已提交的1（本模块合同规定RUN外
		// 才允许改变，而我们当前在CONFIG，允许），此时尝试提交一份
		// input_source=PHOTODIODE（0）的V4配置，必须被拒绝
		// （ERROR_STATIC_BIAS_INPUT_SOURCE=8'h14），不能进入COMMIT
		task_build_normal_manual_config; // input_source保持默认0（PHOTODIODE）
		task_pulse_source_update;
		task_wait_config_result;
		if(o_commit_ack_event || !o_error_event || (o_last_error_code != 8'h14)) begin
			$display("FAIL SMOKE-20 illegal static_characterization_enable=1 + input_source=0 was not rejected, commit_ack=%b error=%b code=%0d",
				o_commit_ack_event, o_error_event, o_last_error_code);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-20 static_characterization_enable=1 + input_source=PHOTODIODE correctly rejected with ERROR_STATIC_BIAS_INPUT_SOURCE");
		end

		// SMOKE-20的拒绝本身是预期行为，但manager的error_sticky是真正的sticky
		// （合同5节start_ready公式里的error_sticky项，RTL里dec_error_present==1
		// 就置位，且只由合法i_status_clear_event/W1C清除，不会被下一次合法
		// COMMIT自动带走）——这是本轮插入SMOKE-21/22之后才第一次真正撞到的
		// 真实交互：SMOKE-20之后如果不显式发一次诊断清除，下一次START会被
		// error_sticky挡住并报通用的0x0b（START资格不足），而不是什么与本场景
        // 相关的错误。顶层唯一诊断清除输入i_diag_clear_event同源扇出到
		// manager的本地状态清除和AMI/Scheduler/SSW/supervisor，之前19个场景
		// 从未真正需要触发过这个清除，因为SMOKE-20一直是最后一个场景
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1;
		i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);

		// SMOKE-21（TOP-20，源端资格边界）：CHARACTERIZATION+EXTERNAL_TEST_CURRENT+
		// OPTICAL_BOTH全程真实RUN——AMI的flag_normal_start_search_qualified要求
		// run_profile==NORMAL_PPG，本场景run_profile=CHARACTERIZATION，结构上
		// AMI根本不会建立启动搜索来源，因此ami_calibration_sample_valid_o必须
		// 全程为0；同时确认RED/IR真实事务仍在正常产生（不是靠系统空闲侥幸通过），
		// 排除"因为没有真实活动所以自然没有校准请求"这种假阳性。SMOKE-19把
		// static_characterization_enable提交为1后是sticky的，先显式清回0，
		// 否则本场景的input_source=EXTERNAL_TEST_CURRENT会被当成STATIC_BIAS
		// （STATIC_BIAS=static_characterization_enable=1且input_source=1）
		//
		// 历史发现+V1.5收尾（V1.2排查记录，V1.5更正）：本场景最初把
		// ppg_400hz_frame_calibration_scheduler_Inst的o_calibration_sample_ready
		// 也当成"非法请求泄漏"的判据，结果第一次跑就"FAIL"——当时（V1.2，
		// 2026-08-24早些时候）逐拍追踪发现calibration_sample_ready_o是纯组合的
		// 容量/就绪信号，完全不检查run_profile/input_source，遂把这条断言去掉，
		// 同时带出一个更重要的事实：调度器RTL里i_run_profile这个输入端口从声明
		// 之后在整个模块正文里从未被引用过，i_input_source只被锁存转发给SSW做
		// 诊断标记，C01合同"校准责任边界"和scheduler合同9.1节描述的接收端
		// run_profile/input_source复核当时确实没有实现，只靠AMI单边源端结构性
		// 门控成立。**这条发现当天晚些时候已经处理**：
		// ppg_400hz_frame_calibration_scheduler.v同一天升级到V1.7，把
		// flag_calibration_request_valid扩展成同时要求i_run_profile==NORMAL且
		// i_input_source==PHOTODIODE并直接与到calibration_sample_ready_o里，
		// tb_ppg_400hz_frame_calibration_scheduler.v新增FSC-58/59拿到了真实单元
		// 级测试覆盖。也就是说上面这段V1.2的排查结论——"calibration_sample_
		// ready_o从不引用run_profile/input_source"——对当前RTL已经不成立，
		// 本场景的监控相应恢复，同时保留对ami_calibration_sample_valid_o的检查
		// （AMI结构性源端门控这一层证据依然有效，两层证据不冲突）
		task_clear_static_bias_characterization;
		task_build_char_external_current_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-21 re-commit before TOP-20 calibration-source-eligibility scenario, commit_ack=%b error=%b code=%0d lifecycle=%0d",
				o_commit_ack_event, o_error_event, o_last_error_code, o_lifecycle_state);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-21 re-commit before TOP-20 calibration-source-eligibility scenario");
		end

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : smoke21_no_calibration_source
			integer cnt_red_before;
			integer cnt_ir_before;
			integer cnt_wait_responses;
			reg flag_calibration_leaked;
			reg flag_scheduler_ready_leaked;
			cnt_red_before = cnt_owner_commit_red;
			cnt_ir_before = cnt_owner_commit_ir;
			cnt_wait_responses = 0;
			flag_calibration_leaked = 1'b0;
			flag_scheduler_ready_leaked = 1'b0;
			while(((cnt_owner_commit_red - cnt_red_before) < 2 || (cnt_owner_commit_ir - cnt_ir_before) < 2) && (cnt_wait_responses < 60000) && !flag_global_timeout) begin
				@(posedge i_clk);
				// 查AMI真实发出的请求valid（结构性源端门控证据）
				if(ppg_control_top_Inst.ami_calibration_sample_valid_o && !flag_calibration_leaked) begin
					flag_calibration_leaked = 1'b1;
					$display("DIAG SMOKE-21 calibration source leak observed at t=%0t cnt_wait=%0d idac_mode=%b lifecycle=%0d",
						$time, cnt_wait_responses,
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.i_idac_mode, o_lifecycle_state);
				end
				// V1.5新增：scheduler V1.7已经把calibration_sample_ready_o接上了
				// flag_calibration_request_valid（run_profile/input_source复核），
				// 现在同步监控这个信号在本场景全程是否曾经出现过高电平——这是一条
				// 只有scheduler自己的资格判断也认定当前模式不合格才会为真的独立断言，
				// 不依赖AMI是否真的递交过请求
				if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_sample_ready && !flag_scheduler_ready_leaked) begin
					flag_scheduler_ready_leaked = 1'b1;
					$display("DIAG SMOKE-21 scheduler o_calibration_sample_ready unexpectedly asserted at t=%0t cnt_wait=%0d lifecycle=%0d",
						$time, cnt_wait_responses, o_lifecycle_state);
				end
				cnt_wait_responses = cnt_wait_responses + 1;
			end
			if(((cnt_owner_commit_red - cnt_red_before) < 2) || ((cnt_owner_commit_ir - cnt_ir_before) < 2)) begin
				$display("FAIL SMOKE-21 SAR did not keep producing real intermittent RED/IR transactions under fixed current, red=%0d ir=%0d",
					cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
				cnt_error = cnt_error + 1;
			end else if(flag_calibration_leaked) begin
				$display("FAIL SMOKE-21 AMI calibration request source (o_calibration_sample_valid) fired during CHARACTERIZATION+EXTERNAL_TEST_CURRENT RUN");
				cnt_error = cnt_error + 1;
			end else if(flag_scheduler_ready_leaked) begin
				$display("FAIL SMOKE-21 scheduler receiver-side eligibility check (o_calibration_sample_ready) asserted during CHARACTERIZATION+EXTERNAL_TEST_CURRENT RUN");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-21 both calibration defenses held for the entire RUN while real RED (%0d) and IR (%0d) transactions kept happening: AMI's ami_calibration_sample_valid_o stayed 0 (structural source-side gate) and the scheduler's own o_calibration_sample_ready also stayed 0 throughout (receiver-side run_profile/input_source recheck, scheduler RTL V1.7)",
					cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke21_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-21 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke21_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-21 drain back to CONFIG timeout after calibration-source-eligibility scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-21 unexpected system fault blocking after calibration-source-eligibility scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-21 calibration-source-eligibility scenario drained back to CONFIG without fault");
		end

		// SMOKE-22（TOP-20，manager静态边界与SAR15校准请求的不可达性）：尝试提交
		// run_profile=NORMAL_PPG + initial_precision=SAR15，按MGR-16/18这是静态
		// 非法组合，manager必须在COMMIT/START前就拒绝（error=8'h10），不进入
		// READY，不启动RUN。这条证据同时说明：AMI的o_calibration_precision_mode
		// 硬编码常量0（校准固定SAR9，见ppg_adc_measurement_idac_integration.v
		// assign o_calibration_precision_mode = 1'b0）与manager这条静态拒绝叠加后，
		// "非法SAR15校准请求"在当前架构下没有任何合法路径可以真正发生——
		// 不是"发生了但被拒绝"，而是从COMMIT这一步就已经被排除，scheduler合同
		// 里"若AMI校准请求携带precision_mode=1，调度器不得接受"那条属于纵深
		// 防御，在现有合法输入空间下不可达，不能靠force去违反合同人为触发
		task_build_normal_manual_sar15_illegal_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(o_commit_ack_event || !o_error_event || (o_last_error_code != 8'h10)) begin
			$display("FAIL SMOKE-22 illegal NORMAL_PPG+SAR15 was not rejected, commit_ack=%b error=%b code=%0d",
				o_commit_ack_event, o_error_event, o_last_error_code);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-22 NORMAL_PPG+SAR15 correctly rejected pre-COMMIT with error=8'h10; no legal path exists to reach a real SAR15 calibration request");
		end

		// SMOKE-22是故意触发的负向测试，会把manager的error_sticky留在1（见
		// SMOKE-21前那次同类教训：这个W1C sticky不会被下一次合法COMMIT带走，
		// 只会在下一次START时静默挡住并报通用的0x0b）。SMOKE-23需要真正START
		// 成功，必须先发一次显式诊断清除
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1;
		i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);

		// SMOKE-23（TOP-03，NORMAL双光）：C01验收矩阵TOP-03要求NORMAL双光下
		// RED/IR共享同一frame_id、sample_index连续、使用同一committed精度、
		// Q3相位固定——这条此前从未被任何一层Tier显式覆盖过（SMOKE-14验证的
		// 是TOP-15双光共享包络里那四个SAR15控制信号的持久性，不是TOP-03这四条
		// 具体claim），整理交接文档时才发现的遗漏，这里补上。真实跑两个连续
		// 宏帧的RED+IR配对，分别在scheduler的o_adc_owner_commit_event同拍
		// 采样身份字段（不依赖bg_responder的Q3释放时机，commit事件和身份
		// 字段本来就是同一拍的保持型输出），核对帧内一致性（同一frame_id、
		// 连续sample_index、同一精度）和跨帧一致性（Q3相位固定不变）
		task_build_normal_manual_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SMOKE-23 re-commit before TOP-03 dual-optical identity scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-23 re-commit before TOP-03 dual-optical identity scenario");
		end

		// 基线必须在START之前取——RED context在tick 0接管、几乎与START同拍就
		// 提交，如果按其它场景的惯例在START后固定等8拍才取基线，这8拍很可能
		// 已经把RED第一笔真实提交算在基线里了（IR因为要等RED owner真实释放后
		// 才能提交，不会这么快），导致RED这边的delta基准点被悄悄推后一整帧——
		// 这正是本场景第一次真正跑起来才发现的真实时序陷阱，不是猜出来的
		reg_top03_red_before = cnt_owner_commit_red;
		reg_top03_ir_before = cnt_owner_commit_ir;

		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : smoke23_dual_optical_identity
			integer cnt_red_before, cnt_ir_before;
			integer cnt_wait_pair;
			reg [C_FRAME_ID_WIDTH - 1:0] pair1_red_frame_id, pair1_ir_frame_id, pair2_red_frame_id, pair2_ir_frame_id;
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] pair1_red_sample, pair1_ir_sample, pair2_red_sample, pair2_ir_sample;
			reg pair1_red_precision, pair1_ir_precision, pair2_red_precision, pair2_ir_precision;
			reg [12:0] pair1_red_tick, pair1_ir_tick, pair2_red_tick, pair2_ir_tick;

			cnt_red_before = reg_top03_red_before;
			cnt_ir_before = reg_top03_ir_before;

			// 等第一对RED+IR都真实提交
			cnt_wait_pair = 0;
			while(((cnt_owner_commit_red - cnt_red_before) < 1 || (cnt_owner_commit_ir - cnt_ir_before) < 1) && (cnt_wait_pair < 60000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_pair = cnt_wait_pair + 1;
			end
			pair1_red_frame_id = reg_last_red_frame_id;
			pair1_ir_frame_id = reg_last_ir_frame_id;
			pair1_red_sample = reg_last_red_sample_index;
			pair1_ir_sample = reg_last_ir_sample_index;
			pair1_red_precision = reg_last_red_precision;
			pair1_ir_precision = reg_last_ir_precision;
			pair1_red_tick = reg_last_red_tick;
			pair1_ir_tick = reg_last_ir_tick;

			// 再等第二对RED+IR都真实提交，用于核对Q3相位跨帧固定
			cnt_wait_pair = 0;
			while(((cnt_owner_commit_red - cnt_red_before) < 2 || (cnt_owner_commit_ir - cnt_ir_before) < 2) && (cnt_wait_pair < 60000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_pair = cnt_wait_pair + 1;
			end
			pair2_red_frame_id = reg_last_red_frame_id;
			pair2_ir_frame_id = reg_last_ir_frame_id;
			pair2_red_sample = reg_last_red_sample_index;
			pair2_ir_sample = reg_last_ir_sample_index;
			pair2_red_precision = reg_last_red_precision;
			pair2_ir_precision = reg_last_ir_precision;
			pair2_red_tick = reg_last_red_tick;
			pair2_ir_tick = reg_last_ir_tick;

			if(((cnt_owner_commit_red - cnt_red_before) < 2) || ((cnt_owner_commit_ir - cnt_ir_before) < 2)) begin
				$display("FAIL SMOKE-23 did not observe two full real RED+IR pairs, red=%0d ir=%0d",
					cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
				cnt_error = cnt_error + 1;
			end else if(pair1_red_frame_id != pair1_ir_frame_id) begin
				$display("FAIL SMOKE-23 pair1 RED/IR frame_id mismatch, red=%0d ir=%0d", pair1_red_frame_id, pair1_ir_frame_id);
				cnt_error = cnt_error + 1;
			end else if(pair1_ir_sample != (pair1_red_sample + 1'b1)) begin
				$display("FAIL SMOKE-23 pair1 sample_index not consecutive, red=%0d ir=%0d", pair1_red_sample, pair1_ir_sample);
				cnt_error = cnt_error + 1;
			end else if(pair1_red_precision != pair1_ir_precision) begin
				$display("FAIL SMOKE-23 pair1 RED/IR precision mismatch, red=%b ir=%b", pair1_red_precision, pair1_ir_precision);
				cnt_error = cnt_error + 1;
			end else if(pair2_red_frame_id != pair2_ir_frame_id) begin
				$display("FAIL SMOKE-23 pair2 RED/IR frame_id mismatch, red=%0d ir=%0d", pair2_red_frame_id, pair2_ir_frame_id);
				cnt_error = cnt_error + 1;
			end else if(pair2_ir_sample != (pair2_red_sample + 1'b1)) begin
				$display("FAIL SMOKE-23 pair2 sample_index not consecutive, red=%0d ir=%0d", pair2_red_sample, pair2_ir_sample);
				cnt_error = cnt_error + 1;
			end else if(pair2_red_precision != pair2_ir_precision) begin
				$display("FAIL SMOKE-23 pair2 RED/IR precision mismatch, red=%b ir=%b", pair2_red_precision, pair2_ir_precision);
				cnt_error = cnt_error + 1;
			end else if(pair2_red_frame_id != (pair1_red_frame_id + 1'b1)) begin
				$display("FAIL SMOKE-23 pair2 frame_id did not advance one real macro frame from pair1, pair1=%0d pair2=%0d", pair1_red_frame_id, pair2_red_frame_id);
				cnt_error = cnt_error + 1;
			end else if((pair1_red_tick != pair2_red_tick) || (pair1_ir_tick != pair2_ir_tick)) begin
				$display("FAIL SMOKE-23 Q3 phase not fixed across frames, red pair1=%0d pair2=%0d, ir pair1=%0d pair2=%0d",
					pair1_red_tick, pair2_red_tick, pair1_ir_tick, pair2_ir_tick);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SMOKE-23 TOP-03: same frame_id (%0d/%0d), consecutive sample_index (RED %0d->IR %0d, RED %0d->IR %0d), same committed precision, and fixed Q3 phase (RED tick=%0d, IR tick=%0d) confirmed across two real macro frames",
					pair1_red_frame_id, pair2_red_frame_id, pair1_red_sample, pair1_ir_sample, pair2_red_sample, pair2_ir_sample, pair1_red_tick, pair1_ir_tick);
			end
		end

		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		fork
			begin : smoke23_stop_ack_wait
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
					@(posedge i_clk);
					#1;
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL SMOKE-23 stop ack timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		fork
			begin : smoke23_drain_wait
				integer cnt_drain_wait;
				cnt_drain_wait = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
					@(posedge i_clk);
					#1;
					cnt_drain_wait = cnt_drain_wait + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL SMOKE-23 drain back to CONFIG timeout after dual-optical identity scenario");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL SMOKE-23 unexpected system fault blocking after dual-optical identity scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SMOKE-23 dual-optical identity scenario drained back to CONFIG without fault");
		end

		// TOP-01新增："无旧事务恢复"——全项目此前仅有的两处i_rstn=1'b0都是场景
		// 最开头的上电复位，从未在RUN期间真实在途事务时触发过复位。本场景真实
		// 建立一笔在途owner，在复位释放后验证：(a)旧事务没有被静默恢复完成
		// （结果计数在复位窗口内保持不变），(b)复位后系统仍功能健康，重新
		// COMMIT+START确实能产生一笔全新的真实结果
		task_build_normal_manual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL TOP-01 re-commit before stale-transaction reset scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-01 re-commit before stale-transaction reset scenario");
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : top01_wait_inflight
			integer cnt_wait_inflight;
			cnt_wait_inflight = 0;
			while(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] && (cnt_wait_inflight < 2000)) begin
				@(posedge i_clk);
				cnt_wait_inflight = cnt_wait_inflight + 1;
			end
		end
		if(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
			$display("FAIL TOP-01 stale-transaction scenario never reached a real in-flight owner before reset");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-01 confirmed real in-flight owner before reset (frame_id=%0d)", ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_frame_id);
		end

		flag_run_phase_active = 1'b0;
		cnt_top01_result_before = cnt_measurement_result_valid;
		// 真实在途事务期间触发复位（不是处女态复位）
		@(negedge i_clk);
		i_rstn = 1'b0;
		@(negedge i_source_clk);
		i_source_rstn = 1'b0;
		repeat(3) @(posedge i_clk);
		#1;
		if((o_lifecycle_state != ST_CONFIG) || o_commit_ack_event || o_error_event || o_start_ack_event || o_stop_ack_event ||
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] ||
			o_measurement_result_valid || (cnt_measurement_result_valid != cnt_top01_result_before)) begin
			$display("FAIL TOP-01 reset during real in-flight transaction did not fully clear owner/pending/lifecycle state, or stale transaction silently completed (result_before=%0d result_after=%0d)",
				cnt_top01_result_before, cnt_measurement_result_valid);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-01 reset during real in-flight transaction fully cleared state; stale transaction produced zero results (count stayed at %0d)", cnt_measurement_result_valid);
		end
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;

		// 复位后重新COMMIT+START，验证系统功能健康、能产生一笔全新的真实结果
		// （而不是复位后system永久卡死这种"表面上也不会恢复旧事务"的假阳性）
		task_build_normal_manual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL TOP-01 re-commit after stale-transaction reset");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-01 re-commit after stale-transaction reset");
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;
		begin : top01_wait_new_result
			integer cnt_wait_result;
			cnt_wait_result = 0;
			while((cnt_measurement_result_valid == cnt_top01_result_before) && (cnt_wait_result < 20000)) begin
				@(posedge i_clk);
				cnt_wait_result = cnt_wait_result + 1;
			end
		end
		if(cnt_measurement_result_valid == cnt_top01_result_before) begin
			$display("FAIL TOP-01 no new genuine measurement result observed after reset+restart, system may be stuck");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-01 system produced a genuine new measurement result after reset+restart (count %0d -> %0d)", cnt_top01_result_before, cnt_measurement_result_valid);
		end
		flag_run_phase_active = 1'b0;
		task_pulse_stop;
		begin : top01_drain_wait
			integer cnt_drain_wait;
			cnt_drain_wait = 0;
			while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
				@(posedge i_clk);
				#1;
				cnt_drain_wait = cnt_drain_wait + 1;
			end
			if(o_lifecycle_state != ST_CONFIG) begin
				$display("FAIL TOP-01 drain back to CONFIG timeout after stale-transaction scenario");
				cnt_error = cnt_error + 1;
			end
		end
		if(o_system_fault_blocking) begin
			$display("FAIL TOP-01 unexpected system fault blocking after stale-transaction scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-01 stale-transaction scenario drained back to CONFIG without fault");
		end

		// TOP-09新增（独立场景）：正式结果在下游反压保持在途期间触发STOP，验证
		// 排空真的经由显式o_measurement_result_discard_event完成，不只是"最终
		// 状态干净"这种活性检查。参照SMOKE-17建立反压保持结果的手法，但不正常
		// 释放反压消费，而是在结果仍被反压保持在途时直接STOP，触发
		// flag_measurement_result_discard_fire（需要flag_measurement_pending真实
		// 为1，即正式结果已进入AMI pipeline，不是ADC owner刚claim但DONE未到的
		// 早期窗口——那个窗口本就没有"正式结果"可丢弃，之前直接沿用SMOKE-06的
		// 早期STOP窗口做这个测试，实测零脉冲，追根因后确认是选错了场景阶段，
		// 不是RTL缺陷，遂改为本场景）
		task_build_normal_manual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL TOP-09 re-commit before discard-event scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-09 re-commit before discard-event scenario");
		end
		i_measurement_result_ready = 1'b0; // 提前反压，START之前就已经反压
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		flag_run_phase_active = 1'b1;

		begin : top09_wait_pending_result
			integer cnt_wait_pending;
			cnt_wait_pending = 0;
			while(!o_measurement_result_valid && (cnt_wait_pending < 60000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_pending = cnt_wait_pending + 1;
			end
		end
		if(!o_measurement_result_valid) begin
			$display("FAIL TOP-09 discard-event scenario never reached a real held measurement result before STOP");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-09 confirmed a real held measurement result before STOP (still backpressured)");
		end

		flag_run_phase_active = 1'b0;
		cnt_top09_discard_event = 0;
		task_pulse_stop; // 结果仍被反压保持在途时STOP，而不是像SMOKE-17那样先正常消费
		begin : top09_count_discard
			integer cnt_wait_discard;
			cnt_wait_discard = 0;
			while((o_lifecycle_state != ST_CONFIG) && (cnt_wait_discard < 200000)) begin
				@(posedge i_clk);
				#1;
				cnt_wait_discard = cnt_wait_discard + 1;
				if(o_measurement_result_discard_event === 1'b1) begin
					cnt_top09_discard_event = cnt_top09_discard_event + 1;
				end
			end
			if(o_lifecycle_state != ST_CONFIG) begin
				$display("FAIL TOP-09 drain back to CONFIG timeout after discard-event scenario");
				cnt_error = cnt_error + 1;
			end
		end
		i_measurement_result_ready = 1'b1; // 恢复默认，避免影响后续场景
		if(cnt_top09_discard_event < 1) begin
			$display("FAIL TOP-09 drain-to-CONFIG with a genuinely held result produced zero real o_measurement_result_discard_event pulses, count=%0d", cnt_top09_discard_event);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-09 drain-to-CONFIG with a genuinely held result completed via %0d real o_measurement_result_discard_event pulse(s)", cnt_top09_discard_event);
		end
		if(o_system_fault_blocking) begin
			$display("FAIL TOP-09 unexpected system fault blocking after discard-event scenario");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-09 discard-event scenario drained back to CONFIG without fault");
		end

		// TOP-15常驻监测进程汇总：确认监测本身不是空跑（真的检查过多笔commit），
		// 且全程零重入
		if(cnt_top15_commit_checked < 1) begin
			$display("FAIL TOP-15 background monitor never observed any real owner commit event -- vacuous check");
			cnt_error = cnt_error + 1;
		end else if(cnt_top15_reentrant != 0) begin
			$display("FAIL TOP-15 detected %0d reentrant owner commit(s) across %0d checked commits", cnt_top15_reentrant, cnt_top15_commit_checked);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TOP-15 single-in-flight monitor checked %0d real owner commits across the full suite, zero reentrant", cnt_top15_commit_checked);
		end

		// 汇总并干净退出
		if(cnt_error == 0) begin
			$display("SMOKE_TB_PASS real_adc_responses=%0d measurement_result_valid=%0d", cnt_adc_response, cnt_measurement_result_valid);
		end else begin
			$display("SMOKE_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
