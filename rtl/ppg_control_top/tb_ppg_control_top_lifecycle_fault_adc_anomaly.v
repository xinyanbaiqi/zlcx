`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/29
// Design Name:        PPG Lifecycle Fault ADC Anomaly Testbench
// Module Name:        tb_ppg_control_top_lifecycle_fault_adc_anomaly
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_idac_code_controller.v
//                      ppg_adc_measurement_idac_integration.v
//                      ppg_400hz_frame_calibration_scheduler.v
//                      ppg_system_fault_abort_supervisor.v
//                      ppg_precision_window_integration.v
//                      PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//                      PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.3
// Revision Date:      2026/08/30
// History:
//    Time               Version       Revised by            Contents
// 2026/08/30            V1.3          Erie                  Bucket-1 RTL session: LFA-06 constructed for real, closing the last of this file's two originally out-of-scope IDs. `ppg_sar9_sar15_safe_selection_wrapper.v` gained a new `o_owner_q3_window_closed` output, wired into `ppg_400hz_frame_calibration_scheduler.v`'s `flag_completion_success` (deliberately NOT `flag_completion_match`/`flag_owner_release`). Real construction found two design issues, both resolved before this evidence was accepted: (1) the first RTL draft gated the Q3 requirement on owner *release* itself; building it for real showed this deadlocks -- an early CLK_DOUT's owner can never be released (its own Q3 will not recur within the same wave), which in turn keeps SSW's `o_wrapper_idle` permanently false, which in turn keeps `transaction_mismatch_sticky_o` permanently un-clearable via `i_diag_clear_event` (its own clear condition requires `o_wrapper_idle`). Fixed by moving the Q3 requirement to `flag_completion_success` only: identity-matched completions still release the owner immediately (no deadlock), they just no longer set the Scheduler's own `B_RED_DONE`/`B_IR_DONE` protocol-success markers. (2) Real construction also showed this Scheduler-level fix does not suppress AMI's own independent `o_measurement_result_valid` stream for the same early completion. Cross-checked against AMI-37's exact contract text ("Q3、包络末沿、固定延时及ADC idle均不能完成owner") together with the user before accepting this as the correct, final scope: AMI's own completion authority is deliberately Q3-agnostic by contract (CLK_DOUT alone), and it is the Scheduler's job -- not AMI's -- to decide whether a completion counts as protocol-level success; extending Q3 into AMI's own completion path would violate AMI-37, not close a gap. Real construction: hold a real NORMAL owner in-flight, present its `drive_real_adc_done` almost immediately (macro_tick ~11, its own Q3 hundreds of ticks away), confirm the owner releases cleanly (no deadlock), `B_RED_DONE`/`B_IR_DONE` never assert, no identity-mismatch sticky fires (this was a genuine identity match, just early -- not a mismatch), and no supervisor blocking fault opens. First attempt threaded this scenario between LFA-04 and LFA-07 and broke LFA-07's own downstream re-grant/re-convergence assumptions (a real, if secondary, test-ordering finding, not an RTL issue) -- relocated LFA-06 to run standalone after LFA-05/LFA-12(final)'s own real startup-search convergence, immediately before this file's final `task_stop_and_drain`, avoiding the interaction entirely. Real iverilog + Vivado 2022.2 xsim both confirm: `JNT_BASELINE 53/53 PASS`, `LIFECYCLE_FAULT_ADC_ANOMALY_TB_PASS result_captures=8 owner_commit_total=221 measurement_discard_events=2 detection_discard_events=0` (one more real transaction and one more raw AMI result than the V1.1/V1.2 baseline, exactly matching LFA-06's own one extra early-but-real completion), byte-identical between both tools.
// 2026/08/29            V1.0          Erie                  Create file. Stage 5 Group 14 (LIFECYCLE-FAULT-ADC-ANOMALY, C25 contract section 9.4.9, LFA-01~12). Covers LFA-01,02,03,04,05,07,09,10,11,12 (ten of twelve stable IDs) with real evidence; LFA-08 and LFA-06 are deliberately out of scope here, for two different reasons documented below rather than silently skipped. Deep RTL investigation (via a dedicated background research pass across ppg_idac_code_controller.v, ppg_adc_measurement_idac_integration.v, ppg_400hz_frame_calibration_scheduler.v, ppg_system_fault_abort_supervisor.v, ppg_precision_window_integration.v, ppg_coarse_detection_fir.v and ppg_sar9_sar15_safe_selection_wrapper.v) confirmed, real signal by real signal, the exact mechanism each LFA ID needs before any TB code was written:
//                                                             LFA-08 scope note: already real-confirmed in ppg_control_top/tb_ppg_control_top_injection.v's INJ-02 scenario (a full joint-top run with C_ENABLE_TEST_INJECTION=1, a mismatched identity injection, production identity-matcher rejection, no owner release/no formal result, propagation through the joint integration fault export and the supervisor, and a clean STOP-triggered original-identity success=0 idempotent recovery) -- that file's own V1.0 changelog documents four real bugs found and fixed getting it there, including a real RTL fix in ppg_adc_measurement_idac_integration.v V1.12. Repeating LFA-08 here would be redundant, not new coverage, so this file cross-references that evidence instead of rebuilding it (this repository's one deliberate exception to the "each Stage 5 file is self-contained" convention, matching the contract's own explicit LFA-08/PRC-08 cross-file exception).
//                                                             LFA-06 scope note -- a genuine, confirmed structural gap, not a missing test: LFA-06 requires "an early CLK_DOUT before the selected Q3 end cannot produce a successful completion." Direct RTL read confirms i_clk_stage1_dout_low_async/i_clk_stage2_dout_low_async (ppg_adc_async_stage_capture.v) are top-level asynchronous inputs wired straight from the physical ADC pins with only a synchronizer in between (flag_capture_accept = flag_selected_done_sync && flag_capture_pending && flag_buffer_available && !i_adc_transaction_start) -- there is no tick counter, no minimum-delay check, and no cross-reference anywhere in the capture/AMI/scheduler completion-identity-matching chain (flag_completion_match checks only sample_index+run_generation, never timing) to the Q3 window that ppg_sar9_sar15_safe_selection_wrapper.v computes entirely privately. AMI's own interface contract (PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md AMI-37 / section 7 item 28 / section 17.28) explicitly goes the OTHER direction -- it forbids using Q3 end, envelope end, fixed delay, or i_adc_idle to FABRICATE a completion in place of a real CLK_DOUT, i.e. it establishes CLK_DOUT as the sole completion authority and explicitly excludes Q3 from gating it. Adding a genuine minimum-Q3-delay gate on CLK_DOUT acceptance, as literal LFA-06 text would require, is a real RTL interface change (new timing-comparison logic reaching into the completion-identity path), the same category of change as Group 6's SID-11 (a change to a production RTL interface contract, not a TB-only exercise) -- explicitly NOT something to insert mid-batch per this project's own established SID-11 precedent. Discussed with the user directly (not silently assumed): confirmed to document this as a real, confirmed structural gap and continue with the other eleven IDs, deferring any RTL decision to a dedicated future session exactly like SID-11.
//                                                             Real facts the investigation pass established and this file relies on: (1) STOP/abort both route through ppg_idac_code_controller.v's single flag_control_cancel = i_stop_ack_event || i_control_abort_event || !i_run_enable, which unconditionally zeroes every PENDING_VALID/TRACK/count/origin context bit the same cycle -- committed codes/epochs (amb_code_current etc, exposed as o_amb_code/o_dcs_r_code/o_dcs_ir_code) are written ONLY inside commit blocks explicitly gated !i_stop_ack_event && !i_control_abort_event, so they are structurally untouched by cancel; the one STOP-vs-abort asymmetry inside this module is that STOP (not abort) additionally clears SEARCH_DONE/EXHAUSTED bits. (2) Abort has its own AMI-exclusive register, flag_adc_transaction_abort (set only by i_control_abort_event while a real owner is inflight/pending, never by STOP), which forces flag_adc_completion_success to 0 once the real matching DONE eventually arrives -- the owner is never released early, it waits for that real DONE. (3) AMI's DC-result fork has a detection-branch discard trigger (flag_detection_discard_trigger = flag_ami_terminal_action && !flag_pwi_detection_datapath_empty && !flag_detection_discard_episode_active) that does NOT reference AMI's own flag_detection_pending at all -- it fires purely off ppg_precision_window_integration.v's aggregate o_detection_datapath_empty (FIR/baseline/peak-valley/precision local-empty ANDed together, one extra register stage of lag), so "AMI's own fork already empty but PWI/FIR/detector generation state still not empty" is a real, RTL-intended case, not a hypothetical corner. (4) DISCARD_REASON_STOP=2'b00/ABORT=2'b01/SYSTEM_FAULT=2'b10 is shared by both the measurement-result and detection discard reason fields, with SYSTEM_FAULT priority latched via flag_system_fault_discard_pending so a later STOP cannot silently overwrite an earlier system-fault episode's recorded reason. (5) The supervisor's own o_system_fault_discard_event (ppg_system_fault_abort_supervisor.v) pulses exactly once on the registered rising edge of its own aggregated blocking-fault episode (any of i_ami_fault_active/i_scheduler_fault_active/i_ssw_fault_active going 0->1) -- this is a clean, independently-triggerable, real system-fault-episode-open event, distinct from STOP/abort. (6) i_diag_clear_event forwards unchanged from Top through AMI down to ppg_idac_code_controller.v's i_status_clear_event, which the RTL itself documents as clearing ONLY CTX_PROTOCOL_ERROR_BIT (a non-blocking historical sticky, o_protocol_error_sticky) and explicitly NOT the AMB/DCS FAULT bits driving o_controller_fault_blocking -- those require the STOP/abort+idle+root-cause-gone path already fixed for real in Group 8 (ppg_idac_code_controller.v V2.2->V2.3, see [[feedback-idac-fault-bit-stop-not-far-not-start-clears]] -- typo guard, real memory name is feedback-idac-fault-bit-stop-not-start-clears). The injection TB's own INJ-02 comment independently confirms the identical pattern at the AMI layer: flag_test_identity_hold "只在新RUN或abort才清" (clears only on new RUN or abort, never on a bare diag_clear) -- this file is the first to actually test the "diag_clear fired BEFORE the STOP/abort recovery, while the fault is still genuinely active" ordering; INJ-02 only ever fires diag_clear AFTER its own STOP-triggered recovery already released the owner. (7) ppg_sar9_sar15_safe_selection_wrapper.v's own local blocking fault (o_ssw_fault_active) is flag_blocking_fault = switch_protocol_error_sticky_o || transaction_mismatch_sticky_o, and transaction_mismatch_sticky_o's trigger (flag_done_mismatch = i_adc_transaction_complete_event && !flag_owner_release) is driven by the exact same physical DONE/completion-identity path the scheduler's own B_COMPLETION_MISMATCH uses -- meaning a duplicate/unmatched real DONE genuinely trips BOTH SSW's and the scheduler's own local mismatch stickies together in this implementation; this file's LFA-10 SSW sub-case documents that honestly (see its own inline note) rather than claiming a total isolation the RTL does not actually provide. (8) o_owner_deadline_timeout_sticky (scheduler) is confirmed NOT part of scheduler_local_fault_blocking_o (= state_current[B_PROTOCOL_ERROR] || state_current[B_COMPLETION_MISMATCH] only) and never sets B_SCHED_FAULT_VALID, matching LFA-09's "non-blocking" requirement exactly.
//                                                             Test strategy: unlike Group 7/8/9, this file never needs the real physiological generator -- every LFA ID is about STOP/abort/reset/duplicate-DONE/fault mechanics, not detection algorithm correctness, so a single continuous SEARCH_TRACK+dual-optical RUN driven entirely by fixed RAW values (this project's own established (100,200)/8/503/150 convention) covers all ten IDs, keeping the whole file fast enough for iverilog exploratory runs. C_ENABLE_TEST_INJECTION is set to 1 (like Group 6's SID-10) purely to reuse the injection TB's own already-debugged identity-mismatch mechanism as a convenient, real, AMI-local-only fault trigger for the combined LFA-02(b)/LFA-10(a)/LFA-11 stage -- i_test_inject_enable stays low for every other stage in this file, so it has zero side effects there per AMI contract rule 1. LFA-02(b)'s "AMI fork empty, PWI/FIR/detector not empty" complementary case and LFA-10's AMI-vs-SSW independence and LFA-11's diag-clear-vs-active-fault contrast are deliberately combined into one stage because they share the exact same real fault episode -- building three separate fault episodes for genuinely the same underlying mechanism would not add coverage, only simulation time.
// 2026/08/29            V1.1          Erie                  Real iverilog debugging arc closed: JNT_BASELINE 53/53 PASS, `LIFECYCLE_FAULT_ADC_ANOMALY_TB_PASS result_captures=7 owner_commit_total=220 measurement_discard_events=2 detection_discard_events=0`. Reaching this took roughly eighteen real simulation iterations and ten distinct real TB-only bugs (no RTL changes needed in this file), each root-caused against real RTL rather than guessed -- summarized here because several are directly reusable for future Stage 5/OIB work: (1) LFA-01/LFA-12(first) checked pending-clear/clean-restart one cycle after the raw i_stop_event/i_start_event request pulse instead of waiting for the real registered o_stop_ack_event/o_start_ack_event -- flag_control_cancel and the clean-search-state condition are keyed on the ack, not the request. (2) LFA-12(a) additionally over-asserted that pending-valid bits must read 0 immediately post-ack; real RTL legitimately arms the first startup candidate within a few cycles of START, which is normal fresh activity, not stale carryover -- relaxed to check only startup_search_complete/B_INFLIGHT. (3) LFA-09 took two wrong theories (grant-then-never-respond; forcing an AMB escalation that does not exist as a direct ST_NORMAL exit) before a real state-machine read confirmed ST_NORMAL only transitions to ST_AMB_RECHECK -- NORMAL slow-tracking confirm-count escalation is only checked inside ST_DCS_REVALIDATE_R (periodic-recheck territory), never reachable directly from ST_NORMAL. The only real, generator-free construction is holding the TB's own i_adc_physical_idle input low across a real macro-frame boundary so RED's context-due pending genuinely cannot be granted for 283+ ticks. (4) LFA-04's abort test corrupted everything downstream the first time: i_control_abort_event immediately zeroes B_FRAME_ACTIVE and sets FRAME_MODE_IDLE in the scheduler, and unlike STOP, NORMAL operation never resumes on its own afterward -- fixed with a full task_stop_and_drain+recommit+START recovery instead of continuing to drive samples into a dead frame. (5) LFA-07 and LFA-05's duplicate/stale-DONE checks both originally expected a diagnostic sticky (first the scheduler's, then AMI's) to fire; real RTL shows the physical capture stage (ppg_adc_async_stage_capture.v) safely drops any CLK_DOUT that was never armed by a real i_adc_transaction_start, with zero side effects and zero diagnostics anywhere in the chain -- the contract text only requires safety (no second completion/result/owner), not a sticky, so both checks were relaxed to the real, minimal, correctly-grounded requirement. (6) LFA-07's duplicate DONE, presented immediately after the base owner released, raced into a genuinely new, legitimately-granted owner (same near-instant-grant fact as #3) and was misread as "produced a second formal result" -- fixed by presenting it only while the system is genuinely stopped via task_stop_and_drain, guaranteeing no new grant is possible. (7) LFA-05's stale DONE, presented too late (two settle delays after START), let the real autonomous startup search begin requesting its first AMB candidate -- the IDAC controller's calibration-search state machine consumes ANY CLK_DOUT arriving while o_amb_sample_request/o_dcs_sample_request is asserted, completely independent of AMI/scheduler's owner-tracking abstraction (a real, generalizable fact distinct from #5's AMI-owner-gated path), silently corrupting the search's own progress before task_run_startup_search ever started tracking it and surfacing many stages later as "DC_R stage did not converge". Fixed by presenting the stale DONE immediately after o_start_ack_event with an explicit guard that FAILs loudly if either request signal is already asserted, proving the construction genuinely hits an idle window. (8) LFA-11(a) originally asserted flag_test_identity_hold must survive a bare i_diag_clear_event; real RTL (found via a continuous per-cycle edge monitor, not more guessing) shows ppg_control_top.v merges this TB's own i_control_abort_event with the supervisor's own automatic one-shot owner-scoped abort (flag_owner_abort_event = i_control_abort_event || supervisor_system_abort_event_o) before it ever reaches AMI/scheduler/SSW -- the supervisor's blocking episode auto-releases the injected-mismatch owner through the real original-identity path almost immediately once it opens, well before this file ever calls STOP or diag_clear manually, making the literal "diag_clear before any recovery" window structurally unobservable through this construction. Rewritten to verify the real safety property instead (the automatic release produced no fabricated formal result), with the finding documented for reuse. (9) LFA-02a had two independent bugs: (a) it snapshotted o_ami_datapath_empty, a broad top-level aggregate that also includes scheduler_idle/controller_idle and other components unrelated to detection state, instead of the actual signal flag_detection_discard_trigger checks (ppg_adc_measurement_idac_integration.v's internal flag_pwi_detection_datapath_empty); (b) it conflated the "held valid formal result" and "STOP discard-pending owner" requirements onto the same single transaction, but a discard-pending owner's real DONE structurally produces success=0 with zero formal data (already separately proven), so there was never a genuine valid-but-stuck result to discard -- split into two correctly-targeted transactions, the first completing normally while ready=0 to populate the held-result register for real, the second undergoing the STOP-during-commit sequence. (10) LFA-10(b) originally planned to reuse the duplicate-DONE mechanism to trigger SSW's own local transaction_mismatch_sticky_o; fact #5 above proves this shared broadcast event never reaches SSW at all when nothing is armed anywhere, so the construction was structurally impossible via this path. Rewritten to document this honestly as a confirmed real construction difficulty (SSW's real trigger, flag_owner_commit_error, needs a genuine scheduler-vs-SSW owner-identity divergence at commit time that this project's own SSW unit-level TB only exercises by directly forcing SSW's raw internal i_adc_owner_* inputs -- not legitimately reachable from the joint ppg_control_top boundary with this file's fixed-RAW driving approach), matching this project's LFA-06/SID-11 honesty convention rather than a fabricated PASS; LFA-10(a) (AMI-side) stands as solid, real, independent evidence.
// 2026/08/30            V1.2          Erie                  LFA-10(b) reclassified from "TB-construction difficulty" to a confirmed real RTL/contract gap, same category as SID-11/LFA-06/OIB-01, after a real construction attempt and a complete real-RTL trace of every OR-term in flag_switch_protocol_error_condition. A cross-session RTL investigation (during Stage 5 Group 13 OIB work) first ruled out identity-mismatch as flag_owner_commit_error's trigger (the Scheduler's commit-event amb/dc code+epoch fields and SSW's own context-acceptance-time snapshot both read the exact same once-per-frame-latched Scheduler register, structurally guaranteed equal within one owner's lifetime) and proposed racing the top-level i_control_abort_event against the Scheduler's own owner-commit event instead, reusing this file's own already-proven-safe LFA-04 abort mechanism. Built and ran it for real: iverilog showed the race successfully detected a real commit event every time, but commit_fire=1 (a normal successful grant), never commit_error. Root cause traced to source: ppg_400hz_frame_calibration_scheduler.v line 449's transaction_start_valid_o (the Scheduler's own precondition for ever asserting the commit event at all) already requires flag_lifecycle_active, which itself requires !i_control_abort_event -- meaning the Scheduler structurally never generates a commit event while abort is asserted, so "commit_event=1 && abort=1" is not a same-cycle timing-engineering problem, it is a logical impossibility on this signal path. Given this real dead end, the other two OR-terms of flag_switch_protocol_error_condition were checked too, closing the set: flag_static_bias_input_source_invalid requires reaching RUN with an illegal STATIC_BIAS+PHOTODIODE combination, but Group 10's ILM-15 already real-confirmed this exact combination is rejected at COMMIT by the V4/V5 config manager (C_ERROR_STATIC_BIAS_INPUT_SOURCE=8'h14, lifecycle stays in ST_CONFIG) and can never reach RUN; (i_normal_frame_active && i_calibration_frame_active) requires the Scheduler's own o_normal_frame_active/o_calibration_frame_active to both be true, but both are defined (lines 556-557) as equality checks against the same single, mutually-exclusive dec_frame_mode field, so they can never both be true by construction. Combined with the fourth term (OIB-01's already-confirmed structural gap), all four legal paths to switch_protocol_error_sticky_o are now independently proven unreachable -- this sticky appears entirely unreachable through any legal ppg_control_top top-level construction in the current RTL. Moved to project-ppg-stage5-deferred-rtl-interface-work as the fourth tracked item; the LFA-10(b) scenario in this file reverts to an honest SKIP carrying this complete evidence chain, not a fabricated PASS.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月29日
// 设计名称:           PPG生命周期故障与ADC异常测试平台
// 模块名称:           tb_ppg_control_top_lifecycle_fault_adc_anomaly
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_idac_code_controller.v
//                      ppg_adc_measurement_idac_integration.v
//                      ppg_400hz_frame_calibration_scheduler.v
//                      ppg_system_fault_abort_supervisor.v
//                      ppg_precision_window_integration.v
//                      PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md
//                      PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.3
// 修订日期:           2026年08月30日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月30日        V1.3          Erie                  桶1 RTL会话：LFA-06真实构造完成，本文件原本两条排除在外的ID至此全部关闭。`ppg_sar9_sar15_safe_selection_wrapper.v`新增`o_owner_q3_window_closed`输出，接入`ppg_400hz_frame_calibration_scheduler.v`的`flag_completion_success`（刻意不接`flag_completion_match`/`flag_owner_release`）。真实构造发现两个需要先解决的RTL设计问题：（1）第一版把Q3门控加在owner释放本身上，真实构造发现会死锁——早到的DONE的owner永远等不到自己这一波的Q3，导致SSW的`o_wrapper_idle`永远为假，连带`transaction_mismatch_sticky_o`永远清不掉（它自己的清除条件要求`o_wrapper_idle`）。改成只在`flag_completion_success`上门控：身份匹配的完成照常立即释放owner（不死锁），只是不再置位Scheduler自己的`B_RED_DONE`/`B_IR_DONE`协议成功标记。（2）真实构造还发现Scheduler层面的修复不会连带压低AMI自己独立的`o_measurement_result_valid`结果流。对照AMI-37原文（"Q3、包络末沿、固定延时及ADC idle均不能完成owner"）并和用户当面确认后，把这个当作最终范围：AMI自己的完成判定按合同就该只认CLK_DOUT、不掺Q3，决定这笔完成算不算"协议意义成功"是Scheduler的职责，不是AMI的；把Q3也接进AMI反而违反AMI-37，不是补缺口。真实构造：让一个真实NORMAL owner在途，在owner刚建立、宏节拍~11（自己的Q3还有几百拍才到）时立即呈交一笔真实DONE，确认owner干净释放（不死锁）、`B_RED_DONE`/`B_IR_DONE`都不置位、不会被误判成身份错配sticky（这确实是身份匹配，只是太早，不是错配）、也不会触发supervisor阻断故障。第一版把这个场景插在LFA-04和LFA-07之间，结果打破了LFA-07自己下游"重新授予/重新收敛"的既有假设（一个真实但次要的测试排序发现，不是RTL问题）——改成挪到LFA-05/LFA-12(final)自己真实收敛完成之后独立运行，紧接在本文件最后的`task_stop_and_drain`之前，彻底避开这个交互。真实iverilog+Vivado 2022.2 xsim双工具都confirmed：`JNT_BASELINE 53/53 PASS`，`LIFECYCLE_FAULT_ADC_ANOMALY_TB_PASS result_captures=8 owner_commit_total=221 measurement_discard_events=2 detection_discard_events=0`（比V1.1/V1.2基线多一笔真实事务、多一笔AMI原始结果，正好对应LFA-06自己这一笔"早但真实"的完成），两个工具逐字节一致。
// 2026年08月29日        V1.0          Erie                  创建文件。Stage 5第14组（LIFECYCLE-FAULT-ADC-ANOMALY，C25合同9.4.9节，LFA-01~12）。真实覆盖LFA-01/02/03/04/05/07/09/10/11/12共十条ID；LFA-08和LFA-06刻意排除在外，原因各不相同、都明确记录，不是默默跳过。LFA-08：已经在`tb_ppg_control_top_injection.v`的INJ-02里拿到真实confirmed证据（含一次真实RTL修复，ppg_adc_measurement_idac_integration.v V1.12），本文件直接引用该证据，不重复构造——这是本项目"每份Stage5文件自包含"惯例里唯一一处刻意的跨文件例外，和合同自己明文规定的LFA-08/PRC-08跨文件例外完全对应。LFA-06：真实确认的结构性缺口，不是漏测——直接读RTL确认`i_clk_stage1_dout_low_async`/`i_clk_stage2_dout_low_async`是直接接物理引脚的顶层异步输入，捕获逻辑`flag_capture_accept`只做电平同步，完成身份匹配链（`flag_completion_match`）只查sample_index+run_generation，全程没有任何tick计数或对SSW私有Q3窗口的时序核对；AMI自己的合同（AMI-37/7节28条/17.28）明确要求的方向反而相反——禁止用Q3末沿等信号伪造完成来代替真实CLK_DOUT，即确立CLK_DOUT是完成的唯一权威、明确排除Q3参与门控，不是禁止额外增加一层"CLK_DOUT必须晚于Q3"的合法性检查。若要真的满足LFA-06字面要求，需要在完成身份链路上新增真实的Q3时序比对逻辑，这是一次真正的生产RTL接口合同改动，性质和Group6 SID-11完全一样——不是验证TB能单独解决的，按本项目SID-11先例明确不在批次中间插入。已经和用户当面讨论过（不是自己默默假设），确认记录为真实缺口，其余十一条ID继续做，RTL决策留给以后单独会话，和SID-11同等对待。
//                                                             调查阶段确立、本文件依赖的真实事实：（1）STOP/abort在`ppg_idac_code_controller.v`里共用同一个`flag_control_cancel = i_stop_ack_event || i_control_abort_event || !i_run_enable`，同拍无条件清零全部PENDING_VALID/TRACK/count/origin context位；已提交码/epoch（`amb_code_current`等，对外为`o_amb_code`/`o_dcs_r_code`/`o_dcs_ir_code`）只在明确要求`!i_stop_ack_event && !i_control_abort_event`的commit块内写入，结构性地不受cancel影响；STOP相对abort唯一的模块内差异是STOP额外清SEARCH_DONE/EXHAUSTED位。（2）abort有自己在AMI里专属的寄存器`flag_adc_transaction_abort`（只由`i_control_abort_event`在真实owner在途/pending时置位，STOP从不置位），迫使`flag_adc_completion_success`在真实DONE最终到达时强制为0——owner不会提前释放，要等这笔真实DONE。（3）AMI的DC-result fork有一个检测分支丢弃触发条件`flag_detection_discard_trigger = flag_ami_terminal_action && !flag_pwi_detection_datapath_empty && !flag_detection_discard_episode_active`，完全不引用AMI自己的`flag_detection_pending`——它纯粹依据`ppg_precision_window_integration.v`聚合的`o_detection_datapath_empty`（FIR/基线/峰谷/精度四路local-empty相与，多一级寄存器延迟）判定，"AMI自己fork已空但PWI/FIR/detector代际状态未空"是真实的RTL设计场景，不是假想边角。（4）`DISCARD_REASON_STOP=2'b00`/`ABORT=2'b01`/`SYSTEM_FAULT=2'b10`在正式结果和检测两条丢弃通道共用，SYSTEM_FAULT优先级经`flag_system_fault_discard_pending`锁存，防止后来的STOP悄悄覆盖掉更早一次系统故障episode记录的原因。（5）supervisor自己的`o_system_fault_discard_event`（`ppg_system_fault_abort_supervisor.v`）只在自己聚合的阻断故障episode（`i_ami_fault_active`/`i_scheduler_fault_active`/`i_ssw_fault_active`任一由0变1）注册式上升沿那一拍脉冲一次——这是一个干净、可独立构造、真实的系统故障episode开启事件，和STOP/abort是两回事。（6）`i_diag_clear_event`从Top经AMI原样转发到`ppg_idac_code_controller.v`的`i_status_clear_event`，RTL自己文档明确只清`CTX_PROTOCOL_ERROR_BIT`（非阻断历史sticky，`o_protocol_error_sticky`），明确不清驱动`o_controller_fault_blocking`的AMB/DCS FAULT位——这些位要走Group8已经真实修复过的STOP/abort+idle+根因消失路径（`ppg_idac_code_controller.v` V2.2→V2.3，见`[[feedback-idac-fault-bit-stop-not-start-clears]]`）。injection TB自己在AMI层的注释独立证实了同一条规律：`flag_test_identity_hold`"只在新RUN或abort才清"（普通diag_clear清不掉）——本文件是第一份真正测试"diag_clear在STOP/abort恢复之前、故障仍然真实活跃时先发生"这个顺序的文件；INJ-02自己的diag_clear全部发生在STOP恢复已经释放owner之后。（7）`ppg_sar9_sar15_safe_selection_wrapper.v`自己的本地阻断故障（`o_ssw_fault_active`）是`flag_blocking_fault = switch_protocol_error_sticky_o || transaction_mismatch_sticky_o`，其中`transaction_mismatch_sticky_o`的触发条件（`flag_done_mismatch = i_adc_transaction_complete_event && !flag_owner_release`）和scheduler自己的`B_COMPLETION_MISMATCH`共用同一条物理DONE/完成身份链路——意味着当前RTL实现下，一笔重复/失配的真实DONE会同时真实触发SSW和scheduler两边的本地失配sticky；本文件LFA-10的SSW子场景对此如实记录（见该阶段内联说明），不假装做到了RTL并未提供的彻底隔离。（8）`o_owner_deadline_timeout_sticky`（scheduler）确认不属于`scheduler_local_fault_blocking_o`（`=state_current[B_PROTOCOL_ERROR] || state_current[B_COMPLETION_MISMATCH]`），也从不置位`B_SCHED_FAULT_VALID`，与LFA-09"non-blocking"的要求精确吻合。
//                                                             测试策略：和Group7/8/9不同，本文件完全不需要真实生理生成器——十一条LFA ID全是STOP/abort/reset/重复DONE/故障机制本身，不是检测算法正确性，所以整份文件用同一次连续的SEARCH_TRACK+双光RUN、全程固定RAW驱动（沿用本项目已确立的(100,200)/8/503/150惯例）即可覆盖全部十条ID，让整份文件在iverilog探索性调试下也足够快。`C_ENABLE_TEST_INJECTION`设为1（和Group6 SID-10一样）纯粹是为了复用injection TB自己已经调试过的身份错配机制，作为LFA-02(b)/LFA-10(a)/LFA-11合并阶段一个方便、真实、AMI本地专属的故障触发源——`i_test_inject_enable`在本文件其余全部阶段保持低电平，按AMI合同规则1零副作用。LFA-02(b)的"AMI fork已空但PWI/FIR/detector未空"互补场景、LFA-10的AMI-vs-SSW独立性、LFA-11的diag-clear-vs-active-fault对比刻意合并进同一个阶段——它们共用同一个真实故障episode，分别构造三次同一种机制不会增加真实覆盖，只会浪费仿真时间。
// 2026年08月29日        V1.1          Erie                  真实iverilog debug收尾：JNT_BASELINE 53/53 PASS，`LIFECYCLE_FAULT_ADC_ANOMALY_TB_PASS result_captures=7 owner_commit_total=220 measurement_discard_events=2 detection_discard_events=0`。这一步走了大约十八轮真实仿真、十个真实的TB自己的问题（本文件全程没有改任何RTL），每一个都真正查到了根因，不是靠猜——记在这里因为其中几条对以后Stage5/OIB的工作直接有用：
//                                                             （1）LFA-01/LFA-12(第一处)在原始请求脉冲i_stop_event/i_start_event后一拍就检查pending清除/干净重启，而不是等真正的注册式ack o_stop_ack_event/o_start_ack_event——flag_control_cancel和干净搜索态判据都是拿ack驱动的，不是原始请求。（2）LFA-12(a)还多断言了pending位在ack后必须立即为0；真实RTL里全新搜索本来就会在START后几拍内建立第一个候选pending，这是正常新活动不是陈旧残留——改成只查startup_search_complete/B_INFLIGHT。（3）LFA-09先后两次基于错误理论的构造（先"授予后不响应"，再"强制AMB升级"——这条升级路径从ST_NORMAL根本走不到）都失败，直接读状态机才确认ST_NORMAL唯一出口是ST_AMB_RECHECK，NORMAL慢速跟踪的confirm-count升级判据只在ST_DCS_REVALIDATE_R（周期重检领域）内部才会被检查。唯一真实、不需要生成器的构造是持有TB自己的i_adc_physical_idle输入拉低跨过一个真实宏帧边界，让RED的tick0 pending真实来不及在283拍内被授予。（4）LFA-04的abort测试第一次拖垮了后面好几个阶段：i_control_abort_event会同拍清B_FRAME_ACTIVE并把FRAME_MODE打回IDLE，和STOP不同，NORMAL不会自己恢复——改成abort后走一次完整的task_stop_and_drain+recommit+START恢复，不再继续对着已经死掉的帧驱动样本。（5）LFA-07和LFA-05的重复/旧DONE检查最初都要求某个诊断sticky置位（先是scheduler的，后来是AMI的）；真实RTL确认物理capture层（ppg_adc_async_stage_capture.v）自己就会安全丢弃任何没被真实i_adc_transaction_start武装过的CLK_DOUT，全程零副作用零诊断——合同原文只要求安全（不产生第二次completion/result/owner），不要求sticky，两处检查都改成了真正、最小、有依据的判据。（6）LFA-07的重复DONE紧跟着owner释放就立即呈交，结果撞上了一个真实、合法、几乎瞬间就被授予的新owner（和第3条同一条近乎瞬时授予的真实事实），被误判成"产生了第二次正式结果"——改成只在系统真正STOP+drain到CONFIG之后才呈交，确保不会有新grant。（7）LFA-05的旧DONE呈交得太晚（START后两次settle延迟），真实自主搜索已经开始请求它自己的第一个AMB候选——IDAC控制器的校准搜索状态机会消费任何在o_amb_sample_request/o_dcs_sample_request保持为真期间到达的CLK_DOUT，完全独立于AMI/scheduler的owner抽象（和第5条AMI owner门控路径是完全不同、同样真实、可推广的事实），悄悄污染了搜索自己的进度，直到好几个阶段之后才以"DC_R stage不收敛"的形式暴露出来。改成o_start_ack_event确认后立即呈交，并显式加了guard，一旦发现任一请求信号已经抬起就直接FAIL报错，证明确实命中了真正空闲的窗口。（8）LFA-11(a)最初断言flag_test_identity_hold必须扛过一次裸的i_diag_clear_event；真实RTL（用逐拍连续edge监视器才查到，不是继续猜）确认ppg_control_top.v把本文件自己的i_control_abort_event和supervisor自己"每个故障episode恰好一次、只扇给事务owner"的自动abort（flag_owner_abort_event = i_control_abort_event || supervisor_system_abort_event_o）合并之后才送到AMI/scheduler/SSW——supervisor的阻断episode一旦打开，几乎立刻就会通过原始身份路径自动释放这笔错配owner，远早于本文件手动调用STOP或diag_clear，"diag_clear在任何恢复之前"这个字面窗口在这条构造下根本观察不到。改成核实真正的安全性质（这次自动释放没有伪造任何formal结果），并把这个发现记录下来供以后复用。（9）LFA-02a有两个独立问题：（a）快照用的是o_ami_datapath_empty（顶层宽泛聚合，还包含scheduler_idle/controller_idle等和检测代际完全无关的分量），不是flag_detection_discard_trigger真正查的那个信号（ppg_adc_measurement_idac_integration.v内部的flag_pwi_detection_datapath_empty）；（b）把"held住的valid正式结果"和"STOP discard-pending owner"两个要求绑在了同一笔事务上，但discard-pending owner的真实DONE结构上就只会产生success=0、零formal data（已经单独验证过），根本没有真正valid又卡住的结果可以discard——拆成两笔各自对准目标的独立事务，第一笔在ready=0期间正常完成、真正把held-result寄存器填上真实值，第二笔再走STOP-during-commit流程。（10）LFA-10(b)原计划复用重复DONE机制触发SSW自己的本地失配故障；上面第5条已经证明这个共享广播事件在无人武装的情况下根本到不了SSW，这条构造从机制上就走不通。改成如实记录为真实确认的构造难点（SSW真正的触发条件flag_owner_commit_error需要一次真实的scheduler-vs-SSW owner身份分歧，本项目自己的SSW单元级TB也只能靠直接force SSW内部原始输入i_adc_owner_*才能构造，联合ppg_control_top边界配合本文件固定RAW驱动惯例够不到），和本项目LFA-06/SID-11的诚实惯例一致，不是硬凑一个假PASS；LFA-10(a)（AMI侧）作为扎实、真实、独立的证据保留。
// 2026年08月30日        V1.2          Erie                  LFA-10(b)从"TB构造难点"改判为和SID-11/LFA-06/OIB-01同一类真实生产RTL/合同缺口——一次真实构造尝试+对`flag_switch_protocol_error_condition`全部四项OR分支做完整真实追查得出的结论。Group13(OIB)工作期间的一次跨会话RTL追查先排除了identity mismatch路径（scheduler commit事件携带的amb/dc code+epoch字段和SSW自己接管时锁存的字段读的是同一个每帧只锁存一次的Scheduler内部寄存器，帧内结构上不可能不一致），转而提出让顶层`i_control_abort_event`和scheduler自己的commit事件真实同拍race，复用本文件LFA-04已经验证过安全可用的同一个abort输入。真实动手构造并用iverilog跑过：race确实每次都真实命中了一笔真实commit事件，但`commit_fire=1`（正常成功建立，不是我们要的错误），从未出现`commit_error`。追到根因：`ppg_400hz_frame_calibration_scheduler.v`第449行`transaction_start_valid_o`（scheduler自己决定要不要发commit事件的判据本身）就要求`flag_lifecycle_active`，而它本身就要求`!i_control_abort_event`——也就是说scheduler看到abort=1根本不会发commit事件，`commit_event=1`和`abort=1`在这条信号链上结构上互斥，不是同拍时序工程问题，是逻辑上的不可能组合。既然这条路真死了，顺手把剩下两项OR分支也查完：`flag_static_bias_input_source_invalid`需要带着STATIC_BIAS+PHOTODIODE非法组合真的走到RUN，但Group10的ILM-15早就真实confirmed这个组合在COMMIT阶段就被V4/V5配置管理器拒绝（`C_ERROR_STATIC_BIAS_INPUT_SOURCE=8'h14`，`o_lifecycle_state`停在ST_CONFIG），永远到不了RUN；`(i_normal_frame_active && i_calibration_frame_active)`要求scheduler自己的`o_normal_frame_active`/`o_calibration_frame_active`同时为真，但两者（第556-557行）都是对同一个互斥的`dec_frame_mode`字段判等，结构上不可能同时成立。加上第四项（OIB-01已经确认的结构性缺口），`flag_switch_protocol_error_condition`全部四条合法路径现在都各自有真实证据（三项静态RTL追查+一项真实iverilog同拍race）确认无法通过任何合法顶层构造触发——这个sticky在当前RTL下看起来整体不可达。已经并入`project-ppg-stage5-deferred-rtl-interface-work`作为第四项被追踪的条目；本文件的LFA-10(b)场景改回一段带完整真实证据链的诚实SKIP，不是硬凑的假PASS。
//
// 复位后跑一个连续的SEARCH_TRACK双光固定RAW驱动RUN，依次核对STOP/abort/reset
// 在启动搜索pending、NORMAL owner在途、周期重检pending三种场景下的取消/discard
// 语义，AMI/scheduler/SSW三路故障独立阻断新launch，diag_clear只清历史sticky，
// 以及合法recovery后新START的干净重启
module tb_ppg_control_top_lifecycle_fault_adc_anomaly();

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

	localparam [4:0] ST_IDAC_AMB_APPLY = 5'd2; // idac控制器AMB候选等待安全生效
	localparam [4:0] ST_IDAC_AMB_WAIT = 5'd3; // idac控制器请求并评价AMB候选
	localparam [4:0] ST_IDAC_DCS_R_APPLY = 5'd4; // idac控制器红光DC候选等待安全生效
	localparam [4:0] ST_IDAC_DCS_R_WAIT = 5'd5; // idac控制器请求并评价红光DC候选
	localparam [4:0] ST_IDAC_DCS_IR_APPLY = 5'd6; // idac控制器红外DC候选等待安全生效
	localparam [4:0] ST_IDAC_DCS_IR_WAIT = 5'd7; // idac控制器请求并评价红外DC候选
	localparam [4:0] ST_IDAC_NORMAL = 5'd8; // idac控制器启动完成并允许NORMAL跟踪

	localparam integer C_CANDIDATE_GUARD_MAX = 12; // 单阶段候选步数安全上限，8位码空间理论最多8步
	localparam time C_SIM_TIMEOUT_NS = 64'd3000000000; // 3秒安全看门狗上限，本组不用真实生理生成器长跑

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
	reg i_clk;
	reg i_rstn;
	reg i_source_clk;
	reg i_source_rstn;

	//---------------V4+V5源域配置信号---------------//
	reg [C_CONFIG_WIDTH - 1:0] i_source_config_snapshot;
	reg i_source_config_update_event;

	//---------------表征source信号---------------//
	reg i_source_characterization_update_valid;
	reg i_source_static_characterization_enable;
	reg [4:0] i_source_test_mux_ctrl;

	//---------------已同步生命周期与诊断信号---------------//
	reg i_start_event;
	reg i_stop_event;
	reg i_diag_clear_event;
	reg i_control_abort_event;

	//---------------物理ADC与模拟边界信号---------------//
	reg [9:0] i_dout_stage1_low;
	reg i_clk_stage1_dout_low_async;
	reg [9:0] i_dout_stage2_low;
	reg i_clk_stage2_dout_low_async;
	reg i_adc_physical_idle;
	reg i_analog_ready;

	//---------------正式结果消费者信号---------------//
	reg i_measurement_result_ready;

	//---------------验证专用异常注入信号---------------//
	reg i_test_inject_enable;
	reg i_test_identity_inject_valid;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] i_test_identity_inject_sample_index;
	reg i_test_invalid_sample_valid;
	reg i_test_saturation_inject_valid = 1'b0; // 本文件不覆盖SID-11场景，恒0安全占位
	reg i_context_handover_stall_request = 1'b0; // LFA-10(b)已并入OIB-01同一sticky，改在OIB文件构造；本文件恒0安全占位

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
	integer cnt_error;
	integer cnt_measurement_result_valid;
	reg flag_global_timeout;

	//---------------DUT实例化---------------//
	ppg_control_top
		#(
			.C_FRAME_ID_WIDTH(C_FRAME_ID_WIDTH),
			.C_SAMPLE_INDEX_WIDTH(C_SAMPLE_INDEX_WIDTH),
			.C_CONFIG_WIDTH(C_CONFIG_WIDTH),
			.C_CODE_EPOCH_WIDTH(C_CODE_EPOCH_WIDTH),
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH),
			.C_ENABLE_TEST_INJECTION(32'd1)
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
			.i_test_saturation_inject_valid(i_test_saturation_inject_valid),
			.i_context_handover_stall_request(i_context_handover_stall_request),
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
	initial begin
		i_source_clk = 1'b0;
		forever #5.5 i_source_clk = ~i_source_clk;
	end

	//---------------系统时钟发生器---------------//
	initial begin
		i_clk = 1'b0;
		forever #250 i_clk = ~i_clk;
	end

	//---------------JNT-01~09基线前缀内部要求的标准配置task名---------------//
	task task_build_normal_manual_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0; // run_profile=NORMAL_PPG
			i_source_config_snapshot[9] = 1'b0; // input_source=PHOTODIODE
			i_source_config_snapshot[11:10] = 2'b00; // idac_mode=MANUAL，JNT基线前缀自用
			i_source_config_snapshot[13:12] = 2'b10; // optical_mode=OPTICAL_IR
			i_source_config_snapshot[14] = 1'b0; // initial_precision=SAR9
			i_source_config_snapshot[15] = 1'b1; // amb_enable
			i_source_config_snapshot[16] = 1'b1; // dcs_enable
			i_source_config_snapshot[17] = 1'b1; // amb_polarity=1，above_high即increase
			i_source_config_snapshot[18] = 1'b0; // dcs_polarity=0，below_low即increase
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
			// 同Group6/7/8已经确立的惯例：阈值窗口整体搬到make_fixed_raw合法值域
			// [8,503]内部(100,200)，below_low(8)/above_high(503)/in_window(150)
			// 三种分类都是纯正数，不受钳位影响
			i_source_config_snapshot[115:104] = 12'sd100; // amb_threshold_low
			i_source_config_snapshot[127:116] = 12'sd200; // amb_threshold_high
			i_source_config_snapshot[139:128] = 12'sd100; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd200; // dcs_threshold_high
			i_source_config_snapshot[159:152] = 8'd8; // amb_confirm_count
			i_source_config_snapshot[167:160] = 8'd9; // dcs_confirm_count
			i_source_config_snapshot[193:168] = 26'sd65536; // stage1_weight_q16_0，Group11已验证target_code恒等式的幂次权重
			i_source_config_snapshot[219:194] = 26'sd131072; // stage1_weight_q16_1
			i_source_config_snapshot[245:220] = 26'sd262144; // stage1_weight_q16_2
			i_source_config_snapshot[271:246] = 26'sd524288; // stage1_weight_q16_3
			i_source_config_snapshot[297:272] = 26'sd524288; // stage1_weight_q16_4
			i_source_config_snapshot[323:298] = 26'sd1048576; // stage1_weight_q16_5
			i_source_config_snapshot[349:324] = 26'sd2097152; // stage1_weight_q16_6
			i_source_config_snapshot[375:350] = 26'sd4194304; // stage1_weight_q16_7
			i_source_config_snapshot[401:376] = 26'sd8388608; // stage1_weight_q16_8
			i_source_config_snapshot[427:402] = 26'sd16777216; // stage1_weight_q16_9
			i_source_config_snapshot[459:428] = -32'sd262144; // stage1_offset_q16
			i_source_config_snapshot[479:460] = 20'sd54143; // stage2_gain_q16
			i_source_config_snapshot[511:480] = -32'sd37; // stage2_offset_q16
			i_source_config_snapshot[543:512] = 32'sd65536; // dc9_recovery_gain_q16
			i_source_config_snapshot[575:544] = 32'sd32768; // dc15_recovery_gain_q16
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames，本组自己的场景task会覆盖
			i_source_config_snapshot[1009] = 1'b1; // peak_valley_config_valid
		end
	endtask

	task task_build_normal_manual_dual_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，真双光
		end
	endtask

	//---------------本组场景专用：SEARCH_TRACK+双光+固定RAW驱动惯例---------------//
	// amb_recheck_interval_frames覆盖成一个很小的、仿真内可行的值，供LFA-03的
	// 周期重检pending场景使用；本文件其余场景不需要它真正过期
	task task_build_lfa_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，双光
			i_source_config_snapshot[591:576] = 16'd2; // amb_recheck_interval_frames，极短间隔供LFA-03使用
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

	//---------------START/STOP事件任务---------------//
	task task_pulse_start;
		begin
			@(negedge i_clk);
			i_start_event = 1'b1;
			@(posedge i_clk);
			#1 i_start_event = 1'b0;
		end
	endtask

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
				$display("FAIL LFA config result timeout");
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

	//---------------Q3窗口等待任务---------------//
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
					$display("FAIL LFA Q3 wait timeout");
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

	//---------------排空回CONFIG任务---------------//
	// 同Group7/8已验证过的STOP后冲刷手法：STOP接受时若恰好有owner在途，调度器
	// 只把它标成B_INFLIGHT_DISCARD受控丢弃，B_INFLIGHT本身要等一次真实完成
	// 才清零
	task task_stop_and_drain;
		integer cnt_stop_wait;
		integer cnt_drain_wait;
		reg local_release;
		reg [9:0] flush_raw;
		integer cnt_post_stop_flush;
		begin
			task_pulse_stop;
			cnt_stop_wait = 0;
			while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
				@(posedge i_clk);
				#1;
				cnt_stop_wait = cnt_stop_wait + 1;
			end
			cnt_post_stop_flush = 0;
			while(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] &&
				(cnt_post_stop_flush < 10) && !flag_global_timeout) begin
				wait_q3_release(local_release);
				if(local_release) begin
					make_fixed_raw(150, flush_raw);
					drive_real_adc_done(1'b0, flush_raw, flush_raw);
				end
				cnt_post_stop_flush = cnt_post_stop_flush + 1;
			end
			cnt_drain_wait = 0;
			while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
				@(posedge i_clk);
				#1;
				cnt_drain_wait = cnt_drain_wait + 1;
			end
			if(o_lifecycle_state != ST_CONFIG) begin
				$display("FAIL LFA drain to CONFIG timeout stop_ack_seen=%b cnt_stop_wait=%0d sched_inflight=%b",
					o_stop_ack_event, cnt_stop_wait,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	`include "tb_ppg_jnt_baseline_prefix.vh"

	//---------------真实owner身份快照进程---------------//
	// commit那一拍锁存身份，真实DONE到达时才使用，同Group7/8已验证手法。放在
	// 引用它的task之前声明——xvlog/xelab对同一模块内标识符要求先声明后使用，
	// 比iverilog的两遍解析更严格
	reg reg_owner_snapshot_is_calibration;
	reg reg_owner_snapshot_color_ir;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_owner_snapshot_frame_id;
	reg reg_owner_snapshot_precision;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_owner_snapshot_sample_index;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			reg_owner_snapshot_is_calibration <= (ppg_control_top_Inst.sched_adc_owner_frame_type_o != 2'b10); // FRAME_TYPE_NORMAL=2'b10，其余编码均为校准类
			reg_owner_snapshot_color_ir <= ppg_control_top_Inst.sched_adc_owner_color_ir_o;
			reg_owner_snapshot_frame_id <= ppg_control_top_Inst.sched_adc_owner_frame_id_o;
			reg_owner_snapshot_precision <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
			reg_owner_snapshot_sample_index <= ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_next[
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_SAMPLE_H -: C_SAMPLE_INDEX_WIDTH];
		end
	end

	//---------------真实候选驱动任务：AMB极性，above即increase---------------//
	task task_drive_amb_toward_target;
		input integer current_code;
		input integer target_code;
		reg [9:0] raw_code;
		integer drive_value;
		begin
			if(current_code < target_code) drive_value = 503; // 强制above_high，AMB极性下触发increase
			else if(current_code > target_code) drive_value = 8; // 强制below_low，触发decrease
			else drive_value = 150; // 强制in_window，[100,200]内
			make_fixed_raw(drive_value, raw_code);
			drive_real_adc_done(1'b0, raw_code, raw_code);
		end
	endtask

	//---------------真实候选驱动任务：DCS极性下below即increase，与AMB相反---------------//
	task task_drive_dcs_toward_target;
		input integer current_code;
		input integer target_code;
		reg [9:0] raw_code;
		integer drive_value;
		begin
			if(current_code < target_code) drive_value = 8; // 强制below_low，DCS极性下触发increase
			else if(current_code > target_code) drive_value = 503; // 强制above_high，触发decrease
			else drive_value = 150; // 强制in_window，[100,200]内
			make_fixed_raw(drive_value, raw_code);
			drive_real_adc_done(1'b0, raw_code, raw_code);
		end
	endtask

	//---------------真实启动搜索收敛任务---------------//
	// 提取自Group6已验证过的AMB/DC_R/DC_IR三阶段二分搜索收敛循环
	task task_run_startup_search;
		reg real_release;
		reg [7:0] reg_current_amb_code, reg_current_dcs_r_code, reg_current_dcs_ir_code;
		integer cnt_wait_request;
		begin
			begin : lfa_startup_amb_stage
				integer cnt_candidate;
				reg flag_amb_converged;
				flag_amb_converged = 1'b0;
				for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_amb_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
					cnt_wait_request = 0;
					while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request &&
						(cnt_wait_request < 5000) && !flag_global_timeout) begin
						@(posedge i_clk);
						cnt_wait_request = cnt_wait_request + 1;
					end
					reg_current_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
					wait_q3_release(real_release);
					if(real_release) task_drive_amb_toward_target(reg_current_amb_code, 64);
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_APPLY ||
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_WAIT) begin
						flag_amb_converged = 1'b1;
					end
				end
				if(!flag_amb_converged) begin
					$display("FAIL LFA startup AMB stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : lfa_startup_dcs_r_stage
				integer cnt_candidate;
				reg flag_r_converged;
				flag_r_converged = 1'b0;
				for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_r_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
					cnt_wait_request = 0;
					while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request &&
						(cnt_wait_request < 5000) && !flag_global_timeout) begin
						@(posedge i_clk);
						cnt_wait_request = cnt_wait_request + 1;
					end
					reg_current_dcs_r_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
					wait_q3_release(real_release);
					if(real_release) task_drive_dcs_toward_target(reg_current_dcs_r_code, 80);
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_APPLY ||
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_WAIT) begin
						flag_r_converged = 1'b1;
					end
				end
				if(!flag_r_converged) begin
					$display("FAIL LFA startup DC_R stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : lfa_startup_dcs_ir_stage
				integer cnt_candidate;
				reg flag_ir_converged;
				flag_ir_converged = 1'b0;
				for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_ir_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
					cnt_wait_request = 0;
					while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request &&
						(cnt_wait_request < 5000) && !flag_global_timeout) begin
						@(posedge i_clk);
						cnt_wait_request = cnt_wait_request + 1;
					end
					reg_current_dcs_ir_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code;
					wait_q3_release(real_release);
					if(real_release) task_drive_dcs_toward_target(reg_current_dcs_ir_code, 96);
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_NORMAL) begin
						flag_ir_converged = 1'b1;
					end
				end
				if(!flag_ir_converged) begin
					$display("FAIL LFA startup DC_IR stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			cnt_wait_request = 0;
			while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete &&
				(cnt_wait_request < 2000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_request = cnt_wait_request + 1;
			end
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete) begin
				$display("FAIL LFA startup_search_complete never asserted after convergence");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end
	endtask

	//---------------搜索收敛后的真实排空等待任务---------------//
	// task_run_startup_search返回时最后一个DC_IR候选自己的owner完成/释放可能
	// 仍在途（state_current先转ST_IDAC_NORMAL，B_INFLIGHT释放稍晚一拍才落地）。
	// LFA-07/LFA-02b/10a/11两处都曾经在task_run_startup_search返回后立即抓下
	// 一笔"真实事务"，结果抓到的其实是这个残留在途owner的自然收尾、不是真正
	// 全新的NORMAL事务，固定repeat(8)不够稳妥，改成真实等datapath空闲
	task task_settle_after_search;
		integer cnt_settle_wait;
		begin
			cnt_settle_wait = 0;
			while(!o_ami_datapath_empty && (cnt_settle_wait < 5000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_settle_wait = cnt_settle_wait + 1;
			end
			if(!o_ami_datapath_empty) begin
				$display("FAIL LFA task_settle_after_search: o_ami_datapath_empty never asserted after startup search convergence");
				cnt_error = cnt_error + 1;
			end
			repeat(4) @(posedge i_clk);
		end
	endtask

	//---------------真实驱动一笔明确颜色、明确目标校准值的NORMAL跟踪事务---------------//
	// 同Group7/8已验证手法：双光NORMAL调度不保证严格RED/IR交替，用真实owner
	// 身份快照逐笔核对颜色，非目标颜色的真实事务驱动中性in-window值放行
	task task_drive_color_value;
		input target_color;
		input integer target_code;
		reg [9:0] raw_code;
		reg local_release;
		integer cnt_guard;
		reg flag_matched;
		begin
			flag_matched = 1'b0;
			cnt_guard = 0;
			while(!flag_matched && (cnt_guard < 30) && !flag_global_timeout) begin
				wait_q3_release(local_release);
				if(!local_release) begin
					cnt_guard = 30;
				end else begin
					if(reg_owner_snapshot_color_ir == target_color) begin
						flag_matched = 1'b1;
						make_fixed_raw(target_code, raw_code);
					end else begin
						make_fixed_raw(150, raw_code); // 中性in_window值，不干扰非目标颜色自身证据
					end
					drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
					cnt_guard = cnt_guard + 1;
				end
			end
			if(!flag_matched) begin
				$display("FAIL task_drive_color_value could not find a real transaction matching target_color=%b within guard window", target_color);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------正式结果与owner提交边沿捕获进程---------------//
	integer cnt_result_capture;
	integer cnt_owner_commit_total_lfa;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			cnt_owner_commit_total_lfa <= cnt_owner_commit_total_lfa + 1;
		end
	end

	//---------------discard/fault事件连续后台sticky捕获进程---------------//
	// 同Group7/8已验证过的连续always块+sticky捕获模式，绝不在多拍阻塞调用之后
	// 做单点内联轮询；主序列消费后自行复位供下一个阶段重新武装
	reg flag_measurement_discard_seen;
	reg [1:0] reg_measurement_discard_reason_latched;
	integer cnt_measurement_discard_events;
	// P01 Facet1新增：discard记录本身的branch ID字段(color_ir/frame_type/sample_index)
	// 此前只接了线、从未真正latch出来核对过真实值，同reason一起用连续always块捕获
	reg reg_measurement_discard_color_ir_latched;
	reg [1:0] reg_measurement_discard_frame_type_latched;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_measurement_discard_sample_index_latched;
	reg flag_detection_discard_seen;
	reg [1:0] reg_detection_discard_reason_latched;
	integer cnt_detection_discard_events;
	reg flag_system_fault_discard_seen;
	always @(posedge i_clk) begin
		if(o_measurement_result_discard_event) begin
			flag_measurement_discard_seen <= 1'b1;
			reg_measurement_discard_reason_latched <= o_measurement_result_discard_reason;
			reg_measurement_discard_color_ir_latched <= o_measurement_result_discard_color_ir;
			reg_measurement_discard_frame_type_latched <= o_measurement_result_discard_frame_type;
			reg_measurement_discard_sample_index_latched <= o_measurement_result_discard_sample_index;
			cnt_measurement_discard_events <= cnt_measurement_discard_events + 1;
		end
		if(o_detection_discard_event) begin
			flag_detection_discard_seen <= 1'b1;
			reg_detection_discard_reason_latched <= o_detection_discard_reason;
			cnt_detection_discard_events <= cnt_detection_discard_events + 1;
		end
		if(o_system_fault_discard_event) begin
			flag_system_fault_discard_seen <= 1'b1;
		end
	end

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL LIFECYCLE_FAULT_ADC_ANOMALY global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	initial begin : main_sequence
		reg real_release;
		reg [9:0] raw_code_tmp;
		reg [7:0] reg_pre_stop_amb_code, reg_pre_stop_dcs_r_code, reg_pre_stop_dcs_ir_code;
		reg [C_CODE_EPOCH_WIDTH - 1:0] reg_pre_stop_amb_epoch, reg_pre_stop_dcs_r_epoch;
		integer cnt_before;
		integer cnt_wait_loop;
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		cnt_owner_commit_total_lfa = 0;
		cnt_measurement_discard_events = 0;
		cnt_detection_discard_events = 0;
		flag_measurement_discard_seen = 1'b0;
		flag_detection_discard_seen = 1'b0;
		flag_system_fault_discard_seen = 1'b0;
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
		i_dout_stage1_low = 10'd0;
		i_clk_stage1_dout_low_async = 1'b0;
		i_dout_stage2_low = 10'd0;
		i_clk_stage2_dout_low_async = 1'b0;
		i_adc_physical_idle = 1'b1;
		i_analog_ready = 1'b1;
		i_measurement_result_ready = 1'b1;
		i_test_inject_enable = 1'b0;
		i_test_identity_inject_valid = 1'b0;
		i_test_identity_inject_sample_index = {C_SAMPLE_INDEX_WIDTH{1'b0}};
		i_test_invalid_sample_valid = 1'b0;

		repeat(3) @(posedge i_clk);
		#1;
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;

		run_jnt_baseline_01_09;

		//=========== RUN 1：SEARCH_TRACK双光固定RAW驱动 ===========//
		task_build_lfa_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA RUN1 commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		//------- LFA-01：STOP在启动搜索AMB pending期间取消未提交、保留已提交、不产生虚构completion -------//
		begin : lfa01_stop_during_startup_search
			reg [7:0] reg_pre_amb_code;
			cnt_wait_loop = 0;
			while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request &&
				(cnt_wait_loop < 5000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_loop = cnt_wait_loop + 1;
			end
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request) begin
				$display("FAIL LFA-01 startup AMB request never asserted");
				cnt_error = cnt_error + 1;
				$finish;
			end
			reg_pre_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
			wait_q3_release(real_release);
			if(real_release) task_drive_amb_toward_target(reg_pre_amb_code, 64); // 制造一笔真实候选样本，产生pending
			repeat(2) @(posedge i_clk);
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_pending_valid) begin
				$display("FAIL LFA-01 setup invalid: AMB pending never asserted before STOP");
				cnt_error = cnt_error + 1;
				$finish;
			end
			cnt_before = cnt_result_capture;
			task_pulse_stop;
			// flag_control_cancel在ppg_idac_code_controller.v里是由i_stop_ack_event
			// （真正的注册式STOP确认）驱动，不是原始请求脉冲i_stop_event本身——必须
			// 等真实ack，不能只等请求脉冲后固定1拍
			cnt_wait_loop = 0;
			while(!o_stop_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_loop = cnt_wait_loop + 1;
			end
			if(!o_stop_ack_event) begin
				$display("FAIL LFA-01 o_stop_ack_event never asserted after STOP request");
				cnt_error = cnt_error + 1;
				$finish;
			end
			@(posedge i_clk);
			#1;
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_pending_valid) begin
				$display("FAIL LFA-01 AMB pending still valid the cycle after STOP acceptance");
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code != reg_pre_amb_code) begin
				$display("FAIL LFA-01 committed AMB code changed by a cancelled STOP pending candidate");
				cnt_error = cnt_error + 1;
			end else if(cnt_result_capture != cnt_before) begin
				$display("FAIL LFA-01 a fabricated measurement result appeared during the STOP cancel");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS LFA-01 STOP during startup search AMB pending cancelled the uncommitted candidate, committed code unchanged, no fabricated completion");
			end
			cnt_wait_loop = 0;
			while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_idac_idle &&
				(cnt_wait_loop < 200) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_loop = cnt_wait_loop + 1;
			end
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_idac_idle) begin
				$display("FAIL LFA-01 o_idac_idle never asserted after STOP cancelled the pending candidate");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS LFA-01 o_idac_idle reached real idle after cancel with no fabricated completion in between");
			end
			cnt_wait_loop = 0;
			while((o_lifecycle_state != ST_CONFIG) && (cnt_wait_loop < 200000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_loop = cnt_wait_loop + 1;
			end
			if(o_lifecycle_state != ST_CONFIG) begin
				$display("FAIL LFA-01 drain to CONFIG timeout");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end

		//------- LFA-12第一段：合法recovery后新START的干净重启（起点，收尾在文件末尾完成第二段） -------//
		task_build_lfa_config;
		i_test_inject_enable = 1'b1; // 后续LFA-02(b)/10(a)/11阶段要用，提前设置对本阶段的其余检查零副作用
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA RUN1 re-commit after LFA-01");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		// 同样要等真实o_start_ack_event，不能只等请求脉冲后固定1拍
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		if(!o_start_ack_event) begin
			$display("FAIL LFA-12 o_start_ack_event never asserted after START request");
			cnt_error = cnt_error + 1;
			$finish;
		end
		@(posedge i_clk);
		#1;
		// 只查startup_search_complete和B_INFLIGHT两个"fresh START那一刻绝不该
		// 为真"的信号；o_amb_pending_valid等pending位不查——真实RTL里全新搜索
		// 自己会在START后几拍内就为第一个候选建立pending，这是干净重启本身
		// 产生的新活动，不是陈旧残留，用它做判据是本文件第一版的错误，不是RTL问题
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete ||
			ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
			$display("FAIL LFA-12 fresh START did not begin from clean search-complete/inflight state (startup_search_complete=%b inflight=%b)",
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS LFA-12(a) fresh START after LFA-01's recovery began with startup_search_complete=0 and no inflight owner, no stale carryover");
		end
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;
		$display("PASS LFA-12(b) startup search re-ran to real convergence from scratch after recovery, no stale event revival stalled it");

		//------- LFA-09：RED owner-deadline失败，非阻断，不消费sample index -------//
		// 前五轮基于"用另一笔真实事务占住B_INFLIGHT"的构造全部失败，这一轮才
		// 找到真正根因：直接读ST_NORMAL的状态转移表确认，ST_NORMAL唯一的出口
		// 只有ST_AMB_RECHECK（周期重检接管点），NORMAL慢速跟踪自己的confirm-
		// count触发（flag_dcs_r_confirm_trigger）只在ST_DCS_REVALIDATE_R（重检
		// 内部）才会被状态机检查——也就是说±1 LSB慢速跟踪调整根本不经过任何
		// 独立的calibration类型Q3窗口，NORMAL态下没有任何合法驱动手段能人为
		// 制造"另一笔事务占线"。真正能构造的是完全不同的机制：`i_adc_physical_
		// idle`本身就是TB直接持有的顶层物理边界输入，真实代表"模拟ADC当前是否
		// 空闲"；`transaction_start_ready_o`硬性要求这一位为真才允许任何owner
		// 提交。在RED上下文到期(tick0)前把它拉低、持续跨过283拍再释放，是
		// 唯一不需要伪造另一笔事务、干净复现"pending真实建立但真实来不及被
		// 授予owner"的合法环境条件——deadline判据本身要求的!B_INFLIGHT在整个
		// 持有期间天然成立，不需要也不能被别的owner占用
		begin : lfa09_owner_deadline
			integer cnt_align_wait;
			integer cnt_hold_cycles;
			reg [12:0] reg_macro_tick_at_hold_start;
			// 对齐到刚跨过宏帧边界（macro_tick很小）的时刻，让RED的tick0 context-due
			// 落在接下来hold期间内，而不是hold开始时已经错过
			cnt_align_wait = 0;
			while((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o > 13'd20) &&
				(cnt_align_wait < 6000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_align_wait = cnt_align_wait + 1;
			end
			reg_macro_tick_at_hold_start = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o;
			i_adc_physical_idle = 1'b0; // 真实持有物理ADC忙状态，跨越RED owner截止相位
			cnt_hold_cycles = 0;
			while(!o_scheduler_owner_deadline_timeout_sticky && (cnt_hold_cycles < 400) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_hold_cycles = cnt_hold_cycles + 1;
			end
			i_adc_physical_idle = 1'b1; // 释放，恢复真实物理就绪
			$display("LFA09_DIAG align_wait=%0d tick_at_hold_start=%0d hold_cycles=%0d deadline_sticky=%b sys_fault_blocking=%b red_pending=%b inflight=%b",
				cnt_align_wait, reg_macro_tick_at_hold_start, cnt_hold_cycles, o_scheduler_owner_deadline_timeout_sticky, o_system_fault_blocking,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_RED_WAVE_PENDING],
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]);
			if(!o_scheduler_owner_deadline_timeout_sticky) begin
				$display("FAIL LFA-09 setup invalid: o_scheduler_owner_deadline_timeout_sticky never asserted after holding i_adc_physical_idle=0 across the RED owner-deadline phase");
				cnt_error = cnt_error + 1;
			end else if(o_scheduler_protocol_error_sticky || o_scheduler_completion_mismatch_sticky) begin
				$display("FAIL LFA-09 owner-deadline timeout incorrectly also set a scheduler blocking sticky (protocol=%b mismatch=%b)",
					o_scheduler_protocol_error_sticky, o_scheduler_completion_mismatch_sticky);
				cnt_error = cnt_error + 1;
			end else if(o_system_fault_blocking || o_system_abort_event || o_system_stop_request_event) begin
				$display("FAIL LFA-09 owner-deadline timeout incorrectly propagated to a supervisor blocking record/abort/STOP request");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS LFA-09 RED owner-deadline timeout asserted the non-blocking historical diagnostic with no scheduler-local blocking sticky and no supervisor blocking record/abort/STOP request");
			end
		end
				task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		task_build_lfa_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA re-commit after LFA-09");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- LFA-04：abort在owner commit之后，保留原identity，真实DONE只产生一次success=0，无formal data -------//
		begin : lfa04_abort_after_commit
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_lfa04_sample_index;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL LFA-04 real Q3 window never opened");
				cnt_error = cnt_error + 1;
			end else begin
				reg_lfa04_sample_index = reg_owner_snapshot_sample_index;
				@(negedge i_clk);
				i_control_abort_event = 1'b1;
				@(posedge i_clk);
				#1 i_control_abort_event = 1'b0;
				if(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					$display("FAIL LFA-04 owner already released before the real DONE arrived, abort must wait for it");
					cnt_error = cnt_error + 1;
				end else begin
					cnt_before = cnt_result_capture;
					make_fixed_raw(150, raw_code_tmp);
					drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp); // 真实原owner的物理DONE，姗姗来迟
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
						$display("FAIL LFA-04 owner was never released by the late real DONE after abort");
						cnt_error = cnt_error + 1;
					end else if(cnt_result_capture != cnt_before) begin
						$display("FAIL LFA-04 a formal measurement result advanced despite abort forcing success=0");
						cnt_error = cnt_error + 1;
					end else begin
						$display("PASS LFA-04 abort after owner commit retained the original identity, the late real DONE produced exactly one success=0 release with no formal data, sample_index=%0d", reg_lfa04_sample_index);
					end
				end
			end
		end
		// abort会同拍立即清B_FRAME_ACTIVE并把FRAME_MODE打回IDLE（真实RTL确认，
		// ppg_400hz_frame_calibration_scheduler.v line 597-598），不像STOP那样
		// 排空后能在同一次RUN内自然恢复——第一版这里直接想继续驱动NORMAL样本，
		// 真实xsim/iverilog下Q3窗口从此再也不开，一路拖累到好几个后续阶段都
		// 拿不到真实事务。修复为abort后老老实实走一次完整STOP+drain+
		// recommit+START+重新收敛，和其它需要"回到干净NORMAL"的阶段一致
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		task_build_lfa_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA re-commit after LFA-04");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- LFA-07：已释放owner的重复DONE不产生第二次completion/result/sample_index变化 -------//
		begin : lfa07_duplicate_done
			reg [9:0] reg_dup_stage1, reg_dup_stage2;
			reg dup_precision;
			cnt_before = o_result_sample_index;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL LFA-07 real Q3 window never opened for the base transaction");
				cnt_error = cnt_error + 1;
			end else begin
				make_fixed_raw(150, raw_code_tmp);
				dup_precision = reg_owner_snapshot_precision;
				reg_dup_stage1 = raw_code_tmp;
				reg_dup_stage2 = raw_code_tmp;
				$display("LFA07_DIAG pre-drive is_cal=%b color=%b precision=%b sample_index=%0d sched_sample=%0d sched_color=%b sched_gen=%0d cur_gen=%0d",
					reg_owner_snapshot_is_calibration, reg_owner_snapshot_color_ir, dup_precision, reg_owner_snapshot_sample_index,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_SAMPLE_H -: C_SAMPLE_INDEX_WIDTH],
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_COLOR],
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_GENERATION_H -: C_RUN_GENERATION_WIDTH],
					ppg_control_top_Inst.flag_run_generation);
				drive_real_adc_done(dup_precision, reg_dup_stage1, reg_dup_stage2); // 正常完成，真实释放一次owner
				cnt_wait_loop = 0;
				while(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] &&
					(cnt_wait_loop < 100) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_loop = cnt_wait_loop + 1;
				end
				$display("LFA07_DIAG post-drive wait_cycles=%0d inflight=%b mismatch_sticky=%b protocol_sticky=%b s1_detect=%b completion_pending=%b",
					cnt_wait_loop,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT],
					o_scheduler_completion_mismatch_sticky, o_scheduler_protocol_error_sticky,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_s1_detect_valid,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_adc_completion_pending);
				if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					$display("FAIL LFA-07 setup invalid: base owner was not released by its own real DONE, mismatch_sticky=%b protocol_sticky=%b",
						o_scheduler_completion_mismatch_sticky, o_scheduler_protocol_error_sticky);
					cnt_error = cnt_error + 1;
				end else begin
					// 真实RTL确认（本轮反复调查才彻底查清，见本文件changelog第9
					// 条事实）：NORMAL跟踪下owner几乎在释放的同一刻就会被新样本
					// 重新占用（同LFA-09探明的"空闲ADC几乎瞬间被授予"同一条
					// 机制），紧跟着立即再送一次DONE，命中的其实是一笔真实的
					// 新owner，不是"无owner"场景，第一版因此误报"产生了第二次
					// 正式结果"——不是bug，是本文件自己没有真正保证"此刻确实无
					// 人在途"这个前提。改成先真实STOP+drain（系统停在CONFIG，
					// 不会再有任何新grant），在真正确定无人在途的条件下才呈交
					// 这笔重复DONE
					task_stop_and_drain;
					cnt_before = cnt_result_capture;
					drive_real_adc_done(dup_precision, reg_dup_stage1, reg_dup_stage2); // 同一笔DONE再来一次，此时系统已停、真实无owner在途
					repeat(4) @(posedge i_clk);
					// 物理capture层（ppg_adc_async_stage_capture.v）自己只在真实
					// i_adc_transaction_start武装过capture_pending之后才接纳一次
					// CLK_DOUT；完全没有任何owner武装过的这笔DONE在这一层就被
					// 安全丢弃，根本不会产生flag_capture_valid，也就轮不到更
					// 上层的flag_adc_capture_without_owner去拦截——从物理层到
					// scheduler全程没有任何一级会为这种"平白多来一次"的脉冲产生
					// 事件或sticky。LFA-07原文本身也只要求"不产生第二次
					// completion/result/update/sample-index变化"，没有要求
					// 必须有诊断置位，真实安全行为就是这里验证的"完全无副作用地
					// 被吞掉"
					if(cnt_result_capture != cnt_before) begin
						$display("FAIL LFA-07 duplicate DONE produced a second formal result");
						cnt_error = cnt_error + 1;
					end else if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
						$display("FAIL LFA-07 duplicate DONE incorrectly established a new in-flight owner");
						cnt_error = cnt_error + 1;
					end else if(o_scheduler_completion_mismatch_sticky || o_ami_integration_protocol_error_sticky) begin
						$display("FAIL LFA-07 duplicate DONE unexpectedly raised a diagnostic sticky (scheduler=%b ami=%b) despite nothing being armed anywhere to receive it",
							o_scheduler_completion_mismatch_sticky, o_ami_integration_protocol_error_sticky);
						cnt_error = cnt_error + 1;
					end else begin
						$display("PASS LFA-07 duplicate DONE for an already-released owner (presented with the system genuinely stopped and idle) was safely dropped at the physical capture stage with no second release/result/owner and no spurious diagnostic");
					end
				end
			end
		end
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		if(o_ami_integration_protocol_error_sticky) begin
			$display("FAIL LFA-07 cleanup: o_ami_integration_protocol_error_sticky did not clear after i_diag_clear_event with no external fault active");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS LFA-07 cleanup: historical AMI protocol-error sticky cleared by i_diag_clear_event once no external fault was active");
		end

		//=========== 重新COMMIT+START，回到NORMAL供LFA-02a使用 ===========//
		task_build_lfa_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA re-commit after LFA-07");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- LFA-02(a)：STOP在NORMAL/SAR15期间，discard-pending owner + held formal result -------//
		begin : lfa02a_stop_during_normal
			reg flag_datapath_was_not_empty;
			// P01 Facet1新增：held-result这笔事务自己真实的身份快照，必须在它自己
			// 完成握手那一拍立刻捕获——reg_owner_snapshot_*是全局实时寄存器，
			// 紧接着的STOP discard-pending owner一旦被grant就会把它覆盖掉
			reg reg_held_result_color_ir;
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_held_result_sample_index;
			// 第一版把"held住的正式结果"和"discard-pending owner"两件事绑在
			// 同一笔事务上：ready=0设在wait_q3_release之前，紧接着这笔owner
			// 自己就被STOP判定discard-pending、真实DONE只产生success=0——根本
			// 不会产生任何正式数据，held-result寄存器里从头到尾都没有真正
			// 到过一笔valid结果，"从未产生discard record"不是bug，是这笔
			// owner压根没有formal data可以held。改成先让一笔独立事务在ready=0
			// 期间正常完成（真实产生一笔valid但卡住无法transfer的正式结果），
			// 再对后一笔owner做STOP discard-pending测试，两个真实场景分开验证
			i_measurement_result_ready = 1'b0; // 让下一笔正式结果被held住，不被消费
			begin : lfa02a_setup_held_result
				integer cnt_setup_guard;
				reg flag_setup_done;
				flag_setup_done = 1'b0;
				cnt_setup_guard = 0;
				while(!flag_setup_done && (cnt_setup_guard < 20) && !flag_global_timeout) begin
					wait_q3_release(real_release);
					if(!real_release) begin
						cnt_setup_guard = 20;
					end else if(reg_owner_snapshot_is_calibration) begin
						// 校准类事务（AMB/DCS_R/DCS_IR）不会产生正式测量结果，只中性放行，
						// 等一笔真正的NORMAL事务
						make_fixed_raw(150, raw_code_tmp);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp);
					end else begin
						// P01 Facet1真实调试发现：身份快照必须在这里、drive_real_adc_done
						// 之前就捕获——reg_owner_snapshot_*是后台每次真实owner commit都会
						// 覆盖的全局寄存器，第一版在下面的等待循环之后才捕获，结果被
						// 循环期间真实commit的下一笔owner（dual-optical下紧跟着的IR）
						// 覆盖掉，导致比对用的"期望值"其实是别的owner的身份，不是这笔
						// 被丢弃事务自己的。此处reg_owner_snapshot_precision已经在用
						// 同样的时机被现有代码读取，证明这个点是安全的
						reg_held_result_color_ir = reg_owner_snapshot_color_ir;
						reg_held_result_sample_index = reg_owner_snapshot_sample_index;
						make_fixed_raw(150, raw_code_tmp);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp); // 正常完成，产生一笔真实valid但因ready=0卡住的formal结果
						cnt_wait_loop = 0;
						while(!o_measurement_result_valid && (cnt_wait_loop < 30) && !flag_global_timeout) begin
							@(posedge i_clk);
							cnt_wait_loop = cnt_wait_loop + 1;
						end
						flag_setup_done = o_measurement_result_valid;
					end
					cnt_setup_guard = cnt_setup_guard + 1;
				end
				if(!flag_setup_done) begin
					$display("FAIL LFA-02a setup invalid: no real NORMAL transaction produced a valid formal result while ready was held low within the guard window");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL LFA-02a real Q3 window never opened");
				cnt_error = cnt_error + 1;
			end else begin
				make_fixed_raw(150, raw_code_tmp);
				// 第一版用o_ami_datapath_empty（顶层聚合，还包含scheduler_idle/
				// controller_idle等和检测代际完全无关的分量）做快照，真实RTL
				// 确认flag_detection_discard_trigger只关心
				// flag_pwi_detection_datapath_empty这一项（PWI自己的FIR/基线/
				// 峰谷/精度四路聚合），用更宽泛的顶层信号做判据会因为"不空"的
				// 原因来自完全无关的分量而误判，改成直接读这个真正被判据使用
				// 的内部信号
				flag_datapath_was_not_empty = !ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_pwi_detection_datapath_empty; // STOP之前先快照，AMI刚commit的owner应仍在途，检测代际理应非空
				flag_measurement_discard_seen = 1'b0;
				flag_detection_discard_seen = 1'b0;
				task_pulse_stop; // STOP接受，本笔已提交的物理owner从此discard-pending，但DONE还没来
				if(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					$display("FAIL LFA-02a owner released before its real DONE arrived, STOP must wait for real completion");
					cnt_error = cnt_error + 1;
				end
				cnt_before = cnt_result_capture;
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp); // 真实DONE姗姗来迟
				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					$display("FAIL LFA-02a owner never released by the STOP-triggered discard-pending real DONE");
					cnt_error = cnt_error + 1;
				end else if(cnt_result_capture != cnt_before) begin
					$display("FAIL LFA-02a a formal measurement result advanced despite STOP discard-pending");
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS LFA-02a STOP-triggered discard-pending owner released by exactly one original-identity success=0 completion, no formal data/IDAC/calibration/detector side effect");
				end
				i_measurement_result_ready = 1'b1; // 恢复消费，让held住的正式结果有机会走DISCARD_STOP而不是无限等ready
				// 同LFA-02a检测代际discard已经踩过的坑，固定拍数不够稳妥，改成
				// 有界轮询
				cnt_wait_loop = 0;
				while(!flag_measurement_discard_seen && (cnt_wait_loop < 50) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_loop = cnt_wait_loop + 1;
				end
				if(!flag_measurement_discard_seen) begin
					$display("FAIL LFA-02a held formal result never produced a public discard record, appears to have waited indefinitely for ready instead");
					cnt_error = cnt_error + 1;
				end else if(reg_measurement_discard_reason_latched != 2'b00) begin
					$display("FAIL LFA-02a held formal result discard reason was %0d, expected DISCARD_STOP(0)", reg_measurement_discard_reason_latched);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS LFA-02a untransferred held formal result produced exactly one public DISCARD_STOP record instead of waiting indefinitely for ready");
				end
				// P01 Facet1：discard记录里的branch ID字段(color_ir/frame_type/sample_index)
				// 此前只确认过discard触发本身和reason编码，从未核对过这些身份字段是否
				// 真的等于被丢弃事务自己的原始值——与setup时捕获的真实快照逐项比对，
				// frame_type固定期望FRAME_TYPE_NORMAL(2'b10)，因为setup循环本身只在
				// 非calibration(即真实NORMAL)事务上才会让flag_setup_done为真
				if(!flag_measurement_discard_seen) begin
					$display("FAIL P01 branch ID check skipped: held formal result discard was never observed above");
					cnt_error = cnt_error + 1;
				end else if(reg_measurement_discard_color_ir_latched != reg_held_result_color_ir) begin
					$display("FAIL P01 discard record color_ir=%b did not match the discarded transaction's own real color_ir=%b",
						reg_measurement_discard_color_ir_latched, reg_held_result_color_ir);
					cnt_error = cnt_error + 1;
				end else if(reg_measurement_discard_frame_type_latched != 2'b10) begin
					$display("FAIL P01 discard record frame_type=%0d did not equal FRAME_TYPE_NORMAL(2'b10)", reg_measurement_discard_frame_type_latched);
					cnt_error = cnt_error + 1;
				end else if(reg_measurement_discard_sample_index_latched != reg_held_result_sample_index) begin
					$display("FAIL P01 discard record sample_index=%0d did not match the discarded transaction's own real sample_index=%0d",
						reg_measurement_discard_sample_index_latched, reg_held_result_sample_index);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS P01 discard record branch ID fields (color_ir=%b, frame_type=NORMAL, sample_index=%0d) exactly match the discarded transaction's own real identity",
						reg_measurement_discard_color_ir_latched, reg_measurement_discard_sample_index_latched);
				end
				// generation-scoped detection discard：本笔owner的下游检测代际状态
				// STOP时理应尚未真实排空（AMI自己fork已空但PWI/FIR/detector未空是
				// 真实RTL场景，见本文件changelog第3条事实），确认discard真实发生。
				// flag_detection_discard_trigger额外要求flag_ami_terminal_action，
				// 第一版固定repeat(4)不够，改成有界轮询等它真实出现
				cnt_wait_loop = 0;
				while(!flag_detection_discard_seen && (cnt_wait_loop < 50) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_loop = cnt_wait_loop + 1;
				end
				if(flag_datapath_was_not_empty && !flag_detection_discard_seen) begin
					$display("FAIL LFA-02a generation-scoped detection discard never fired while downstream detection state was not yet empty at STOP");
					cnt_error = cnt_error + 1;
				end else if(flag_detection_discard_seen && (reg_detection_discard_reason_latched != 2'b00)) begin
					$display("FAIL LFA-02a detection discard reason was %0d, expected DISCARD_STOP(0)", reg_detection_discard_reason_latched);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS LFA-02a generation-scoped detection discard observed (fired=%b), all current-generation detection state settling toward empty",
						flag_detection_discard_seen);
				end
				if(!o_ami_datapath_empty) begin
					$display("FAIL LFA-02a AMI/PWI datapath did not settle to empty after the STOP discard sequence completed");
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS LFA-02a all current-generation detection state reported empty after the STOP discard sequence");
				end
			end
		end
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);

		//=========== 重新COMMIT+START，回到NORMAL供后续阶段使用 ===========//
		task_build_lfa_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA re-commit after LFA-02a");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- P01 Facet2：正式测量结果同拍"正常消费ready=1"与"abort触发discard"
		// 的race——RTL事实：o_measurement_result_valid=flag_measurement_pending &&
		// !flag_result_abort_discard（ppg_adc_measurement_idac_integration.v:1024），
		// valid本身就被abort_discard同一个组合项直接反相，理论上discard和"valid&&
		// ready成功消费"不可能同拍并存；用一次真实同拍race实测验证，不只是读代码
		// 相信 -------//
		begin : p01_facet2_ready_vs_abort_race
			reg reg_race_color_ir;
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_race_sample_index;
			integer cnt_result_capture_before_race;
			i_measurement_result_ready = 1'b0; // 复用LFA-02a已验证过的"先held住"手法建立一笔真实valid的正式结果
			begin : p01_facet2_setup_held_result
				integer cnt_setup_guard;
				reg flag_setup_done;
				flag_setup_done = 1'b0;
				cnt_setup_guard = 0;
				while(!flag_setup_done && (cnt_setup_guard < 20) && !flag_global_timeout) begin
					wait_q3_release(real_release);
					if(!real_release) begin
						cnt_setup_guard = 20;
					end else if(reg_owner_snapshot_is_calibration) begin
						make_fixed_raw(150, raw_code_tmp);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp);
					end else begin
						// 同P01 Facet1的真实调试发现：必须在drive_real_adc_done之前捕获，
						// 不能等下面的等待循环之后再抢救
						reg_race_color_ir = reg_owner_snapshot_color_ir;
						reg_race_sample_index = reg_owner_snapshot_sample_index;
						make_fixed_raw(150, raw_code_tmp);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp);
						// 真实调试发现：drive_real_adc_done末尾把i_adc_physical_idle
						// 恢复成1的那一刻，scheduler近乎瞬时(本文件changelog早已确认过
						// 的真实事实)grant了下一个owner并让它自己的物理Q1/Q2/Q3转换
						// 开始跑；本场景后面故意不再driving任何东西，等这笔新owner
						// 转换到一半时abort把lifecycle带进STOPPING，Q1/Q2/Q3生成本身
						// 似乎随之冻结，这笔新owner从此再也等不到真实Q3——变成一个
						// 永远排不空的孤儿在途owner，wait_q3_release多少次重试都没用。
						// 立刻把物理idle收回去，不给scheduler这次瞬时授予的窗口，
						// 只在真正需要放行时才恢复成1
						i_adc_physical_idle = 1'b0;
						cnt_wait_loop = 0;
						while(!o_measurement_result_valid && (cnt_wait_loop < 30) && !flag_global_timeout) begin
							@(posedge i_clk);
							cnt_wait_loop = cnt_wait_loop + 1;
						end
						flag_setup_done = o_measurement_result_valid;
					end
					cnt_setup_guard = cnt_setup_guard + 1;
				end
				if(!flag_setup_done) begin
					$display("FAIL P01 Facet2 setup invalid: no real NORMAL transaction produced a valid held formal result within the guard window");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			if(!o_measurement_result_valid) begin
				$display("FAIL P01 Facet2 setup invalid: held formal result did not remain valid going into the race cycle");
				cnt_error = cnt_error + 1;
				$finish;
			end
			cnt_result_capture_before_race = cnt_result_capture;
			flag_measurement_discard_seen = 1'b0;
			// 真实调试发现：第一版在同一个下降沿同时拉高两个信号，实测从未构造出
			// 真正的同拍冲突——AMI真正看到的i_control_abort_event端口，接的其实是
			// ppg_control_top.v自己合并出的flag_owner_abort_event（=本文件的
			// i_control_abort_event || supervisor自动abort），这是一个真实的
			// 寄存器，从TB拉高原始信号到AMI端口真正看到1，中间隔着一拍延迟；而
			// i_measurement_result_ready是直接线，没有这一拍。于是第一版的"同一
			// 下降沿"实际上是ready提前一整拍生效，先赢得了pending的release——
			// discard_fire全程为0，AMI从未真正看到abort_discard=1和ready=1同拍
			// 出现过（本session用调试打印P01DEBUG逐信号核实过这条真实时序）。
			// 正确构造：先单独拉一拍原始abort（同task_pulse_abort的标准单拍手法），
			// 让flag_owner_abort_event真正寄存生效，再在它已经稳定为1之后才拉高
			// ready，这样两者才会在AMI内部同一个上升沿都为真
			@(negedge i_clk);
			i_control_abort_event = 1'b1;
			@(posedge i_clk);
			#1 i_control_abort_event = 1'b0;
			if(!ppg_control_top_Inst.flag_owner_abort_event) begin
				$display("FAIL P01 Facet2 setup invalid: flag_owner_abort_event never registered high after the raw abort pulse, cannot construct the intended race");
				cnt_error = cnt_error + 1;
				$finish;
			end
			@(negedge i_clk); // flag_owner_abort_event此刻已经稳定为1，abort_discard在AMI内部已经真实生效
			i_measurement_result_ready = 1'b1;
			@(posedge i_clk); // 这才是真正的同拍冲突：ready和abort_discard在AMI内部这一拍同时为真
			#1;
			if(o_measurement_result_valid) begin
				$display("FAIL P01 Facet2 o_measurement_result_valid stayed 1 on the cycle AMI's own abort_discard and i_measurement_result_ready were both genuinely true together, despite the held result being simultaneously ready-consumable and abort-discardable; expected discard to pre-empt valid on this cycle");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS P01 Facet2 o_measurement_result_valid read 0 on the cycle AMI's own abort_discard and i_measurement_result_ready were both genuinely true together, pre-empting the ready-consumption race before it could complete");
			end
			cnt_wait_loop = 0;
			while(!flag_measurement_discard_seen && (cnt_wait_loop < 50) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_loop = cnt_wait_loop + 1;
			end
			if(!flag_measurement_discard_seen) begin
				$display("FAIL P01 Facet2 measurement discard never fired despite the same-cycle ready/abort race");
				cnt_error = cnt_error + 1;
			end else if(reg_measurement_discard_reason_latched != 2'b01) begin
				$display("FAIL P01 Facet2 discard reason was %0d, expected DISCARD_ABORT(1)", reg_measurement_discard_reason_latched);
				cnt_error = cnt_error + 1;
			end else if((reg_measurement_discard_color_ir_latched != reg_race_color_ir) || (reg_measurement_discard_sample_index_latched != reg_race_sample_index)) begin
				$display("FAIL P01 Facet2 discard identity mismatch: color_ir=%b(expect %b) sample_index=%0d(expect %0d)",
					reg_measurement_discard_color_ir_latched, reg_race_color_ir,
					reg_measurement_discard_sample_index_latched, reg_race_sample_index);
				cnt_error = cnt_error + 1;
			end else if(cnt_result_capture != cnt_result_capture_before_race) begin
				$display("FAIL P01 Facet2 cnt_result_capture advanced from %0d to %0d despite the discard path claiming this same transaction -- double-recorded as both a successful transfer and a discard",
					cnt_result_capture_before_race, cnt_result_capture);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS P01 Facet2 same-cycle i_measurement_result_ready=1/i_control_abort_event=1 race resolved deterministically to discard only (DISCARD_ABORT, correct identity), zero double-recorded successful transfer (cnt_result_capture unchanged at %0d)",
					cnt_result_capture);
			end
			i_measurement_result_ready = 1'b1; // 恢复正常消费，供后续阶段使用
			i_adc_physical_idle = 1'b1; // 竞态窗口已经安全过去，放行物理总线恢复正常
			// abort本身已经把系统带入STOPPING（同LFA-04已确认的真实行为——
			// i_control_abort_event不需要额外STOP请求就会让lifecycle自己转向
			// STOPPING），不需要再发一次多余的STOP请求；上面已经堵住了竞态窗口内
			// 的幽灵owner，这里只需要按LFA-02a已验证过的手法确认真的排空
			begin : p01_facet2_post_race_flush
				integer cnt_flush_attempt;
				cnt_flush_attempt = 0;
				// 一次flush不够：scheduler近乎瞬时grant的下一个owner往往不止一个，
				// 同task_stop_and_drain内部flush循环一样改成有界重试，直到真的
				// 排空或用满预算
				while(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] &&
					(cnt_flush_attempt < 10) && !flag_global_timeout) begin
					wait_q3_release(real_release);
					if(real_release) begin
						make_fixed_raw(150, raw_code_tmp);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp);
					end
					cnt_flush_attempt = cnt_flush_attempt + 1;
				end
			end
			cnt_wait_loop = 0;
			while((o_lifecycle_state != ST_CONFIG) && (cnt_wait_loop < 200000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_loop = cnt_wait_loop + 1;
			end
			if(o_lifecycle_state != ST_CONFIG) begin
				$display("FAIL P01 Facet2 drain to CONFIG timeout after the abort-triggered race, inflight=%b",
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]);
				cnt_error = cnt_error + 1;
				$finish;
			end
		end

		//=========== 重新COMMIT+START，回到NORMAL供LFA-02(b)使用 ===========//
		task_build_lfa_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA re-commit after P01 Facet2");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- LFA-02(b)+LFA-10(a)+LFA-11：合并的AMI本地故障episode -------//
		// 复用injection TB自己已经调试过的INJ-02身份错配机制（C_ENABLE_TEST_
		// INJECTION=1，i_test_inject_enable在START前已设好），产生一个真实、
		// AMI本地专属的阻断故障，同时满足三条ID共用的"一个真实故障episode"前提：
		// LFA-02(b)的system-fault互补场景需要一个真实丢弃episode开启事件；
		// LFA-10(a)需要一个干净的AMI-only故障，独立于scheduler/SSW自身逻辑；
		// LFA-11需要一个diag_clear清不掉的、真正活跃的故障原因
		begin : lfa02b_10a_11_ami_fault_episode
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_original_sample_index;
			reg [9:0] reg_fixed_stage1, reg_fixed_stage2;
			make_fixed_raw(150, reg_fixed_stage1);
			reg_fixed_stage2 = reg_fixed_stage1;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL LFA-02b/10a/11 real Q3 window never opened");
				cnt_error = cnt_error + 1;
			end else begin
				reg_original_sample_index = reg_owner_snapshot_sample_index;
				flag_system_fault_discard_seen = 1'b0;
				flag_measurement_discard_seen = 1'b0;
				flag_detection_discard_seen = 1'b0;
				i_test_identity_inject_sample_index = 16'hFFFF; // 与当前owner真实sample_index必然不同
				i_test_identity_inject_valid = 1'b1;
				drive_real_adc_done(reg_owner_snapshot_precision, reg_fixed_stage1, reg_fixed_stage2);
				if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_test_identity_hold) begin
					$display("FAIL LFA-02b/10a/11 identity injection never fired (flag_test_identity_hold stayed 0)");
					cnt_error = cnt_error + 1;
					$finish;
				end
				i_test_identity_inject_valid = 1'b0;
				cnt_before = cnt_result_capture; // 供LFA-11a核对整段故障episode期间自始至终没有虚假formal结果
				repeat(4) @(posedge i_clk);
				$display("LFA02B_TRACE checkpoint=after_inject_settle identity_hold=%b", ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_test_identity_hold);
				if(!o_ami_integration_protocol_error_sticky) begin
					$display("FAIL LFA-02b/10a/11 setup invalid: o_ami_integration_protocol_error_sticky never asserted after mismatch");
					cnt_error = cnt_error + 1;
					$finish;
				end
				cnt_wait_loop = 0;
				while(!o_system_fault_blocking && (cnt_wait_loop < 500) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_loop = cnt_wait_loop + 1;
				end
				if(!o_system_fault_blocking) begin
					$display("FAIL LFA-02b/10a/11 setup invalid: o_system_fault_blocking never propagated through supervisor");
					cnt_error = cnt_error + 1;
					$finish;
				end
				$display("LFA02B_TRACE checkpoint=after_fault_blocking_wait identity_hold=%b", ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_test_identity_hold);

				//---- LFA-02(b)：system-fault episode开启必须记录为DISCARD_SYSTEM_FAULT，不是STOP/abort ----//
				repeat(4) @(posedge i_clk); // 让detection_datapath_empty的一级额外寄存器延迟稳定下来
				$display("LFA02B_TRACE checkpoint=after_discard_settle identity_hold=%b", ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_test_identity_hold);
				if(!flag_system_fault_discard_seen) begin
					$display("FAIL LFA-02b o_system_fault_discard_event never pulsed on the supervisor's blocking-episode rising edge");
					cnt_error = cnt_error + 1;
				end else if(flag_measurement_discard_seen && (reg_measurement_discard_reason_latched != 2'b10)) begin
					$display("FAIL LFA-02b measurement discard reason was %0d, expected DISCARD_SYSTEM_FAULT(2)", reg_measurement_discard_reason_latched);
					cnt_error = cnt_error + 1;
				end else if(flag_detection_discard_seen && (reg_detection_discard_reason_latched != 2'b10)) begin
					$display("FAIL LFA-02b detection discard reason was %0d, expected DISCARD_SYSTEM_FAULT(2)", reg_detection_discard_reason_latched);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS LFA-02b real system-fault episode produced exactly the DISCARD_SYSTEM_FAULT reason, not DISCARD_STOP or DISCARD_ABORT");
				end

				//---- LFA-10(a)：AMI故障独立阻断新launch，scheduler/SSW自身本地位保持干净 ----//
				if(o_scheduler_protocol_error_sticky || o_scheduler_completion_mismatch_sticky) begin
					$display("FAIL LFA-10a AMI-only fault incorrectly also set a scheduler-local blocking sticky (protocol=%b mismatch=%b)",
						o_scheduler_protocol_error_sticky, o_scheduler_completion_mismatch_sticky);
					cnt_error = cnt_error + 1;
				end else if(o_ssw_transaction_mismatch_sticky || o_ssw_switch_protocol_error_sticky) begin
					$display("FAIL LFA-10a AMI-only fault incorrectly also set an SSW-local blocking sticky (mismatch=%b protocol=%b)",
						o_ssw_transaction_mismatch_sticky, o_ssw_switch_protocol_error_sticky);
					cnt_error = cnt_error + 1;
				end else if(!o_start_ready) begin
					$display("PASS LFA-10a AMI-only fault independently blocked new launches (o_start_ready=0) via o_system_fault_blocking, with scheduler/SSW own local diagnostics untouched");
				end else begin
					$display("FAIL LFA-10a o_start_ready still asserted despite an active AMI-only blocking fault");
					cnt_error = cnt_error + 1;
				end
				$display("LFA02B_TRACE checkpoint=after_lfa10a identity_hold=%b", ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_test_identity_hold);

				//---- LFA-11(a)：diag_clear不能是唯一让owner脱险的路径 ----//
				// 真实RTL确认（本轮反复用edge监视器才彻底查清，见本文件changelog
				// 第9条事实）：AMI真正的i_control_abort_event输入并不是直接接
				// 本文件顶层的i_control_abort_event寄存器，而是接
				// ppg_control_top.v自己合并出的flag_owner_abort_event=
				// i_control_abort_event（外部）||supervisor_system_abort_
				// event_o（supervisor自己的、"每个故障episode恰好一次、仅扇给
				// 事务owner"的注册式abort）。也就是说，supervisor一旦为这次
				// 身份错配打开阻断episode，不需要本文件手动调用task_pulse_stop
				// 或抬高i_control_abort_event，flag_test_identity_hold和
				// scheduler的B_INFLIGHT就已经通过这条supervisor自动abort真实
				// 释放——这是合同9.5.1节规则5"STOP或受控abort应使AMI重新呈交
				// 保留身份"里"受控abort"的真实体现，是设计意图，不是bug。第一版
				// 断言"diag_clear之前必须仍然阻断"的前提本身就不成立——在本文件
				// 能真正调用diag_clear之前，episode早已经被supervisor自己的
				// 自动abort真实关闭了，"diag_clear之前完全没有任何恢复发生"这个
				// 窗口在这条故障通道下根本不存在，无法安全断言。改成核实真正
				// 关键的合同规则5安全性质：这次真实释放走的是原始身份
				// success=0，不是静默丢弃，也没有产生虚假formal结果
				if(cnt_result_capture != cnt_before) begin
					$display("FAIL LFA-11a a formal result appeared during the supervisor's automatic owner-scoped abort release");
					cnt_error = cnt_error + 1;
				end else if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					$display("PASS LFA-11a informational: owner still genuinely in flight at this checkpoint, supervisor auto-abort has not yet resolved it");
				end else begin
					$display("PASS LFA-11a the supervisor's own automatic owner-scoped abort (flag_owner_abort_event, not this TB's own i_control_abort_event) already released the owner through the real original-identity path before any manual diag_clear/STOP, with no formal result fabricated -- diag_clear alone was never the mechanism that discarded it");
				end
				@(negedge i_clk);
				i_diag_clear_event = 1'b1;
				@(posedge i_clk);
				#1 i_diag_clear_event = 1'b0;
				repeat(4) @(posedge i_clk);

				//---- STOP排空回CONFIG（owner这一刻大概率已经被supervisor自动abort
				// 释放，见上面LFA-11a的真实发现；这里再确认一次并推进生命周期）----//
				cnt_before = cnt_measurement_discard_events;
				task_pulse_stop;
				cnt_wait_loop = 0;
				while(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] &&
					(cnt_wait_loop < 200) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_loop = cnt_wait_loop + 1;
				end
				if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					$display("FAIL LFA-02b/10a/11 owner never released after STOP recovery");
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS LFA-02b/10a/11 owner confirmed released via the real original-identity path (by the supervisor's automatic abort and/or this STOP), original sample_index=%0d", reg_original_sample_index);
				end
				cnt_wait_loop = 0;
				while((o_lifecycle_state != ST_CONFIG) && (cnt_wait_loop < 200000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_loop = cnt_wait_loop + 1;
				end
				if(o_lifecycle_state != ST_CONFIG) begin
					$display("FAIL LFA-02b/10a/11 drain to CONFIG timeout after recovery");
					cnt_error = cnt_error + 1;
					$finish;
				end
				@(negedge i_clk);
				i_diag_clear_event = 1'b1;
				@(posedge i_clk);
				#1 i_diag_clear_event = 1'b0;
				repeat(4) @(posedge i_clk);
				if(o_system_fault_blocking || o_ami_integration_protocol_error_sticky) begin
					$display("FAIL LFA-11b diagnostics did not clear after the real STOP/abort recovery condition was met, fault_blocking=%b integration_sticky=%b",
						o_system_fault_blocking, o_ami_integration_protocol_error_sticky);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS LFA-11b once the contractual STOP-recovery condition was met, i_diag_clear_event cleared the diagnostics for real");
				end
			end
		end
		i_test_identity_inject_valid = 1'b0;
		i_test_invalid_sample_valid = 1'b0;

		//=========== 重新COMMIT+START，回到NORMAL供LFA-10(b)/LFA-03使用 ===========//
		task_build_lfa_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA re-commit after LFA-02b/10a/11");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- LFA-10(b)：SSW独立阻断故障 -------//
		// V1.2真实构造尝试（原V1.0/V1.1的"重复DONE"计划已经证伪，见下方
		// changelog）：一次跨Group13(OIB-01/OIB-09)的RTL追查先排除了identity
		// mismatch路径（scheduler commit事件携带的amb/dc code+epoch字段和
		// SSW自己接管时锁存的字段读的是同一个每帧只锁存一次的Scheduler内部
		// 寄存器，帧内结构上不可能不一致），转而尝试flag_owner_commit_fire
		// 自己的!i_control_abort_event项——真实同拍race顶层abort和scheduler
		// 自己的commit事件。real iverilog跑出来commit_fire=1（真实建立成功，
		// 不是我们要的错误），根因追到底：scheduler自己产生commit事件的
		// 判据transaction_start_valid_o本身就要求flag_lifecycle_active
		// （=...&&!i_control_abort_event，ppg_400hz_frame_calibration_
		// scheduler.v第449行），也就是说scheduler只要看到abort=1就根本不会
		// 发出commit事件——commit_event=1和abort=1这两个条件在这条信号链上
		// 结构上互斥，不是同拍竞争的时序工程问题，是逻辑上互斥。
		// 顺手核查了flag_switch_protocol_error_condition剩下的另外两项，
		// 结论一样悲观：flag_static_bias_input_source_invalid需要
		// reg_run_active=1时仍带着STATIC_BIAS+input_source=PHOTODIODE的非法
		// 组合，但Group10 ILM-15已经真实confirmed这个组合在COMMIT阶段就被
		// V4/V5配置管理器拒绝（C_ERROR_STATIC_BIAS_INPUT_SOURCE=8'h14，
		// o_lifecycle_state停在ST_CONFIG），永远到不了RUN；
		// (i_normal_frame_active && i_calibration_frame_active)要求
		// scheduler自己的o_normal_frame_active/o_calibration_frame_active
		// 同时为真，但两者都是对同一个互斥的dec_frame_mode字段判等
		// （ppg_400hz_frame_calibration_scheduler.v第556-557行），结构上不可能
		// V1.3更新：桶1 RTL会话已经把这第四项OR分支本身重新设计（新增
		// i_context_handover_stall_request专属反压端口+收窄判据只在排除
		// stall因素后依然违规才算数），并在Group13 OIB-01里真实构造confirmed：
		// 跨越RED接管点持有stall，Scheduler非阻断o_launch_timeout_sticky
		// 真实置位，SSW阻断的switch_protocol_error_sticky_o保持0——两份合同
		// 文本"这两支应该能独立分类"的要求现在有了真实证据。LFA-10(b)自己
		// 当初尝试的abort-race构造路径本身依然是死的（scheduler结构上不会在
		// abort=1时发commit事件，这个事实没有变，和本次RTL改动无关），但
		// LFA-10(b)真正要证明的性质——SSW自己的阻断故障能独立于Scheduler的
		// 非阻断诊断分类——已经被OIB-01的真实构造证明成立，不需要在本文件
		// 里单独重新构造一遍同一个sticky。详见OIB文件自己V1.1 changelog
		$display("SKIP LFA-10b SSW-side independent blocking fault via this file's own abort-race construction: that specific path remains structurally dead (scheduler never generates a commit event while abort is asserted, unrelated to the bucket-1 RTL redesign) -- but the underlying property LFA-10(b) set out to demonstrate (SSW's blocking fault independently classifiable from the Scheduler's non-blocking diagnostic) is now real-confirmed by Group13 OIB-01's construction (see tb_ppg_control_top_owner_identity_backpressure.v V1.1), so this scenario is not rebuilt here");
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);

		//=========== 重新COMMIT+START，回到NORMAL供LFA-03使用 ===========//
		task_build_lfa_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL LFA re-commit after LFA-10b");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- LFA-03：STOP在周期重检pending期间取消未提交request，不改变已提交码/epoch -------//
		// 自包含构造，同Group8 RRC-12已验证过的手法：amb_recheck_interval_
		// frames已经在task_build_lfa_config里覆盖成极短值，固定in-window驱动
		// 持续推进真实NORMAL帧直到pending真实到期，STOP必须立刻清pending且
		// 不产生任何码更新
		begin : lfa03_stop_during_recheck_pending
			integer cnt_wait_pending;
			cnt_wait_pending = 0;
			while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending &&
				(cnt_wait_pending < 4000) && !flag_global_timeout) begin
				task_drive_color_value(1'b0, 150);
				task_drive_color_value(1'b1, 150);
				cnt_wait_pending = cnt_wait_pending + 1;
			end
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending) begin
				$display("FAIL LFA-03 recheck pending never asserted under fixed in-window driving -- check is vacuous");
				cnt_error = cnt_error + 1;
				$finish;
			end
			reg_pre_stop_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
			reg_pre_stop_amb_epoch = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current;
			reg_pre_stop_dcs_r_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
			reg_pre_stop_dcs_ir_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code;
			task_stop_and_drain;
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending) begin
				$display("FAIL LFA-03 recheck pending still asserted after STOP+drain completed");
				cnt_error = cnt_error + 1;
			end else if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code != reg_pre_stop_amb_code) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current != reg_pre_stop_amb_epoch) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != reg_pre_stop_dcs_r_code) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code != reg_pre_stop_dcs_ir_code)) begin
				$display("FAIL LFA-03 AMB/DC code or epoch changed by STOP clearing an uncommitted recheck-pending request");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS LFA-03 STOP during recheck pending cancelled the uncommitted request with no code/epoch update");
			end
		end

		//------- LFA-05 + LFA-12收尾：reset立即invalidate owner identity，旧DONE不能完成新owner，随后合法recovery干净重启 -------//
		begin : lfa05_reset_and_lfa12_final
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_stale_sample_index;
			reg [9:0] reg_stale_stage1, reg_stale_stage2;
			reg stale_precision;
			//=========== 重新COMMIT+START，制造一个真实在途owner供reset打断 ===========//
			task_build_lfa_config;
			task_pulse_source_update;
			task_wait_config_result;
			if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
				$display("FAIL LFA re-commit before LFA-05");
				cnt_error = cnt_error + 1;
				$finish;
			end
			task_pulse_start;
			repeat(8) @(posedge i_clk);
			task_run_startup_search;
			task_settle_after_search;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL LFA-05 real Q3 window never opened before reset");
				cnt_error = cnt_error + 1;
				$finish;
			end
			reg_stale_sample_index = reg_owner_snapshot_sample_index;
			make_fixed_raw(150, reg_stale_stage1);
			reg_stale_stage2 = reg_stale_stage1;
			stale_precision = reg_owner_snapshot_precision;

			//---- reset：mid-flight打断这笔在途owner ----//
			@(negedge i_clk);
			i_rstn = 1'b0;
			i_source_rstn = 1'b0;
			repeat(5) @(posedge i_clk);
			#1;
			if(|ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current) begin
				$display("FAIL LFA-05 scheduler state_current did not immediately invalidate to zero under reset");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS LFA-05 reset immediately invalidated the scheduler's owner identity state (B_INFLIGHT and its sample/generation fields all zeroed)");
			end
			repeat(3) @(posedge i_clk);
			#1;
			@(negedge i_source_clk);
			i_source_rstn = 1'b1;
			@(negedge i_clk);
			i_rstn = 1'b1;
			repeat(3) @(posedge i_clk);
			#1;

			//---- 重新配置、START，产生新的真实generation，再呈交reset前那笔旧DONE ----//
			task_build_lfa_config;
			task_pulse_source_update;
			task_wait_config_result;
			if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
				$display("FAIL LFA-05 re-commit after reset");
				cnt_error = cnt_error + 1;
				$finish;
			end
			task_pulse_start;
			cnt_wait_loop = 0;
			while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_loop = cnt_wait_loop + 1;
			end
			if(!o_start_ack_event) begin
				$display("FAIL LFA-12c o_start_ack_event never asserted after START request");
				cnt_error = cnt_error + 1;
				$finish;
			end
			@(posedge i_clk);
			#1;
			// LFA-12(c)：fresh START本身必须从干净状态开始，reset之后这个检查
			// 再验证一次，覆盖"reset后的recovery"这个独立分支
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete ||
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
				$display("FAIL LFA-12c fresh START after reset did not begin from clean search/inflight state");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS LFA-12c fresh START after reset began from clean search/inflight state, matching the STOP-recovery case");
			end

			//---- 呈交reset前那笔旧DONE：新generation下必须被身份失配拒绝，不能完成/释放新owner ----//
			// 真实RTL确认（本轮才彻底查清，见本文件changelog第9条）：IDAC控制器
			// 自己的校准搜索状态机在o_amb_sample_request/o_dcs_sample_request
			// 保持为真期间会直接消费任何到达的CLK_DOUT作为候选评价结果，这条
			// 路径完全独立于AMI/scheduler的owner抽象——不是"安全丢弃"能覆盖的
			// 场景。第一版在START后固定等8拍才呈交，真实搜索早已经自主请求了
			// 第一个AMB候选，结果这笔"旧DONE"被控制器当成了真实候选评价，悄悄
			// 污染了搜索自己的收敛进度，直到后面task_run_startup_search自己的
			// AMB/DC_R阶段才暴露出不收敛。改成不等待、START确认后立即呈交，并
			// 显式核实呈交那一刻两个请求信号都还没抬起，确保命中的确实是真正
			// 空闲、search尚未开始请求的窗口
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request ||
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request) begin
				$display("FAIL LFA-05 setup invalid: real startup search already requested a candidate before the stale DONE could be presented, construction needs re-timing");
				cnt_error = cnt_error + 1;
				$finish;
			end
			cnt_before = cnt_owner_commit_total_lfa;
			drive_real_adc_done(stale_precision, reg_stale_stage1, reg_stale_stage2);
			repeat(4) @(posedge i_clk);
			// 呈交这笔旧DONE时新RUN里还没有任何owner在途（LFA-12c已确认）。真实
			// RTL确认（同LFA-07最终查清的事实，见本文件changelog第9条）：物理
			// capture层自己只在真实i_adc_transaction_start武装过之后才接纳
			// CLK_DOUT，完全没有owner武装的这笔旧DONE在物理层就被安全丢弃，
			// 不会产生任何诊断sticky——不需要、也不应该要求一个合同没有要求的
			// sticky，只要确认它真的无法完成/释放一个新owner即可
			if(cnt_owner_commit_total_lfa != cnt_before) begin
				$display("FAIL LFA-05 a pre-reset stale DONE somehow advanced the owner-commit counter in the new RUN");
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
				$display("FAIL LFA-05 the pre-reset stale DONE incorrectly established a new in-flight owner");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS LFA-05 the pre-reset stale DONE was safely dropped at the physical capture stage in the new post-reset generation, could not release or complete a new owner, sample_index=%0d", reg_stale_sample_index);
			end
			@(negedge i_clk);
			i_diag_clear_event = 1'b1;
			@(posedge i_clk);
			#1 i_diag_clear_event = 1'b0;
			repeat(20) @(posedge i_clk); // 呈交那笔旧DONE会真实toggle异步CLK_DOUT/i_adc_physical_idle信号，即使AMI安全丢弃，SSW自己的Q1/Q2/Q3相位跟踪也可能需要更多真实拍数才能确认稳定复位，固定4拍不够稳妥
			$display("LFA12FINAL_DIAG pre-search idac_state=%0d amb_req=%b dcs_req=%b lifecycle=%0d",
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request,
				o_lifecycle_state);

			//---- LFA-12最终收尾证据：新START之后真实完整跑通一次startup search，证明没有任何stale事件复活卡住它 ----//
			task_run_startup_search;
			task_settle_after_search;
			$display("PASS LFA-12(final) post-reset fresh START ran startup search to real convergence, no stale event from the pre-reset owner revived or stalled it");
		end
		//------- LFA-06：早于自身Q3窗口关闭的CLK_DOUT不得构成协议意义的成功完成 -------//
		// 桶1 RTL会话新增了SSW的o_owner_q3_window_closed状态输出，接入Scheduler
		// 的flag_completion_success（不是flag_completion_match/flag_owner_release）
		// 作为新增必要项——这是本文件V1.0/V1.1曾经记录的真实结构性缺口（完成身份
		// 链路全程没有任何Q3时序核对）在RTL层面的修复。真实构造过程中发现两个
		// 需要RTL重新设计的问题，都已经解决：
		// (1) 第一版把Q3门控加在flag_owner_release/flag_completion_match（释放
		// 本身）上，真实构造发现一旦真的命中就会死锁——owner永久卡在in-flight
		// （该owner自己这一帧的Q3不会再来），SSW的transaction_mismatch_sticky_o
		// 又要求owner先idle才能被i_diag_clear_event清除，形成循环死锁。改为门控
		// 放在flag_completion_success上：owner照常合法释放（身份匹配就应该释放
		// 槽位），只是不再产生Scheduler自己的B_RED_DONE/B_IR_DONE协议成功标记，
		// 没有死锁风险。
		// (2) 真实构造还发现Scheduler层面的修复不会连带压低AMI自己独立的正式
		// 测量结果流（o_measurement_result_valid仍然真实产生了一次result）。
		// 和用户一起对照AMI-37原文（"Q3、包络末沿、固定延时及ADC idle均不能
		// 完成owner"）确认：这不是遗漏，是AMI-37明文要求的架构边界——AMI自己
		// 的完成判定必须以真实DONE为唯一权威、不掺杂Q3，这一层的职责只是如实
		// 上报捕获到的东西；真正拥有owner/帧协议记账职责、决定这笔完成算不算
		// "协议意义上成功"的是Scheduler这一层，现在已经真实做到。把Q3也接进
		// AMI会直接违反AMI-37，所以AMI的原始结果流保持不变是有意为之，不是
		// 本次遗留的缺口
		begin : lfa06_early_done
			reg [9:0] reg_early_stage1, reg_early_stage2;
			reg early_precision;
			cnt_wait_loop = 0;
			while(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] &&
				(cnt_wait_loop < 6000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_loop = cnt_wait_loop + 1;
			end
			if(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
				$display("FAIL LFA-06 setup invalid: no real owner became in-flight after startup search settled");
				cnt_error = cnt_error + 1;
			end else begin
				make_fixed_raw(150, raw_code_tmp);
				early_precision = reg_owner_snapshot_precision;
				reg_early_stage1 = raw_code_tmp;
				reg_early_stage2 = raw_code_tmp;
				drive_real_adc_done(early_precision, reg_early_stage1, reg_early_stage2); // 立即呈交，远早于该owner自己的真实Q3窗口
				repeat(20) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					$display("FAIL LFA-06 owner was not cleanly released by the early CLK_DOUT (identity matched, should still release to avoid a permanent in-flight deadlock)");
					cnt_error = cnt_error + 1;
				end else if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_RED_DONE] ||
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_IR_DONE]) begin
					$display("FAIL LFA-06 early CLK_DOUT before Q3 closed was still marked as a protocol-level successful color completion (B_RED_DONE/B_IR_DONE)");
					cnt_error = cnt_error + 1;
				end else if(o_scheduler_completion_mismatch_sticky) begin
					$display("FAIL LFA-06 early CLK_DOUT (a genuine identity match, just too early) was incorrectly routed into the identity-mismatch diagnostic instead of being silently non-successful");
					cnt_error = cnt_error + 1;
				end else if(o_system_fault_blocking) begin
					$display("FAIL LFA-06 early CLK_DOUT unexpectedly escalated to a supervisor blocking fault; this is a silent non-success outcome, not a protocol violation");
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS LFA-06 early CLK_DOUT before the owner's own Q3 window closed released the owner cleanly (no deadlock) but produced no protocol-level successful completion (B_RED_DONE/B_IR_DONE stayed 0), matching AMI-37's Q3-agnostic completion authority at the AMI layer while gating protocol success at the Scheduler layer");
				end
			end
		end

		task_stop_and_drain;

		if(cnt_error == 0) begin
			$display("LIFECYCLE_FAULT_ADC_ANOMALY_TB_PASS result_captures=%0d owner_commit_total=%0d measurement_discard_events=%0d detection_discard_events=%0d",
				cnt_result_capture, cnt_owner_commit_total_lfa, cnt_measurement_discard_events, cnt_detection_discard_events);
		end else begin
			$display("LIFECYCLE_FAULT_ADC_ANOMALY_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
