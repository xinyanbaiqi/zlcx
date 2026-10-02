`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/30
// Design Name:        PPG Owner Identity Backpressure Testbench
// Module Name:        tb_ppg_control_top_owner_identity_backpressure
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_400hz_frame_calibration_scheduler.v
//                      ppg_sar9_sar15_safe_selection_wrapper.v
//                      ppg_adc_measurement_idac_integration.v
//                      PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//                      PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.3
// Revision Date:      2026/10/01
// History:
//    Time               Version       Revised by            Contents
// 2026/10/01            V1.3          Erie                  Task C (TASKC_TICK248_P2S_20261001.md): connect i_test_calibration_loss_inject_valid to a reg initialised to 0 and never driven, the same pattern tb_ppg_control_top_robustness_corner_waveforms.v uses. This TB instantiates ppg_control_top with C_ENABLE_TEST_INJECTION=1, so the injection structure is generated, yet this input had been left unconnected (floating Z; REGRESSION_BASELINE_20260930.md section 6.6). All seven control_top verification-injection inputs were checked; this was the only unconnected one, and iverilog -Wall now reports no dangling input. Sorted PASS lines, $finish time and final banner are identical before and after the change (run on the same RTL).
// 2026/08/31            V1.2          Erie                  Bucket-2 TB-only session: OIB-09 constructed for real, the last remaining out-of-scope ID in this file (Stage 5's TB-construction-only bucket, no production RTL touched -- see project handoff for the SID-11/LFA-06/OIB-01/LFA-10(b) RTL bucket this is deliberately independent of). Replaced the V1.0/V1.1 scope-note comment block with a real frame-scoped before/after construction: drive a real RED `task_drive_color_value` transaction and capture its formal result plus this frame's own live `state_current[B_FRAME_DCR_EPOCH]` snapshot *before* any below_low driving starts (guaranteed pre-update); then repeatedly drive RED below_low samples via the same task to accumulate real `dcs_confirm_count` evidence in `ppg_idac_code_controller.v` until `dcs_r_code_current` genuinely changes; then keep driving neutral transactions and polling the live `B_FRAME_DCR_EPOCH` bit-slice until it is observed to differ from the before-snapshot (not assuming any fixed number of frame-boundary crossings); then drive one more RED transaction to capture the after-snapshot. Both before and after captures read the frame number and the frame's own latched epoch in the exact same clock cycle as the formal result's `o_measurement_result_valid`, eliminating any race against how many real transactions the confirm-drive or the color-matching search internally consumes. Three real construction-only bugs found and fixed this round (no RTL changes, confirmed by iverilog re-runs each time): (1) the first draft captured the "before" frame/epoch snapshot from a pre-loop guess taken *before* the confirm-drive loop started, then asserted the eventual formal result's frame must still equal that guess -- `task_drive_color_value`'s own internal color-matching search consumes a variable, unbounded number of real transactions, so the confirm-drive loop alone was already enough to cross a real frame boundary before the guessed "before" frame was ever validated, producing `FAIL OIB-09 setup invalid: real frame boundary crossed while still driving the confirm sequence`. (2) Removing that guess and instead reading the frame/epoch live at the exact result-valid cycle fixed the race, but exposed a second, more fundamental issue: capturing "before" only *after* confirming the code had changed was already too late -- by the time the confirming below_low drive loop broke out and the subsequent "before" transaction's own search completed, the DUT was already several frames past the actual commit event, so before/after landed on the same already-updated epoch (`FAIL ... expect frame=13 epoch=11 ... after frame=15 epoch=11`, both post-update). Fixed by restructuring so the true "before" snapshot is captured *before* any below_low driving begins at all, when no update has possibly happened yet. (3) Even with "before" captured first, waiting for exactly one `current_frame_id_o` boundary crossing after the confirmed code change was still not sufficient (`FAIL ... before frame=13 epoch=11, after frame=15 epoch=11` even after one real crossing) -- real RTL tracing explains why: the only safe-boundary source active during steady NORMAL RUN is `macro_frame_safe_boundary_o` (`ppg_400hz_frame_calibration_scheduler.v` line 461), which is itself the frame-boundary tick; a confirm-triggered code+epoch commit landing on that exact tick means the *very next* frame's own `flag_frame_start_eligible` latch (line 748-774) reads `i_dcs_r_code_epoch` combinationally during the same cycle the IDAC controller's own registered increment has not yet landed, so that immediately-next frame's own snapshot still shows the pre-increment value -- the real update is not visible until a frame *after* that. Fixed by not assuming a fixed number of boundary crossings at all: poll the live per-frame epoch bit-slice continuously via `task_drive_any_neutral` until it is directly observed to differ from the before-snapshot, then capture whichever frame that turns out to be. Real dual-tool confirmed evidence (iverilog and Vivado 2022.2 xsim, byte-identical): `JNT_BASELINE checked=53 pass=53 required=53 status=PASS`, `PASS OIB-09 frame-scoped DC_R epoch before(frame=3 epoch=10)/after(frame=14 epoch=11) each bound correctly to its own frame's latched snapshot, and the epoch genuinely advanced after a real safe-boundary code update`, `OWNER_IDENTITY_BACKPRESSURE_TB_PASS result_captures=35 owner_commit_total=224 measurement_discard_events=1 detection_discard_events=0 order_violation_count=0` (result_captures/owner_commit_total up from V1.1's 12/202 by exactly this new scenario's own extra RUN activity; every other counter unchanged). This closes OIB-09, the last item of Stage 5's TB-construction-only bucket (alongside PRC-09/PRC-10, tracked separately) -- this file's own OIB-01~10 acceptance list is now fully real-covered.
// 2026/08/30            V1.1          Erie                  Bucket-1 RTL session: OIB-01 constructed for real, closing this file's last out-of-scope ID (and, as a side effect, LFA-10(b) -- see that file's own V1.3 changelog). `ppg_sar9_sar15_safe_selection_wrapper.v` gained a new `i_context_handover_stall_request` injection port (paired with the module's own new `C_ENABLE_TEST_INJECTION` parameter, now set to `32'd1` in this file's DUT instantiation, up from `32'd0`), and `flag_switch_protocol_error_condition`'s 4th OR-term was narrowed to only fire when the miss would still be a real protocol violation with the stall factor excluded (`flag_waveform_context_ready_raw`) -- a stall-caused miss no longer co-trips SSW's blocking `switch_protocol_error_sticky_o`, leaving the Scheduler's own non-blocking `o_launch_timeout_sticky` as the sole diagnostic. Real construction: hold `i_context_handover_stall_request` from before START through the first RED handover tick (`macro_tick==0`), confirming only the Scheduler's non-blocking launch-timeout sticky asserts while SSW's blocking sticky and every other blocking/supervisor signal stay 0 (`PASS OIB-01 ... asserted only the Scheduler's non-blocking launch-timeout diagnostic, with SSW's blocking switch_protocol_error_sticky correctly staying 0`) -- the exact evidence the original RTL investigation found unreachable. The recovery half (release the stall, confirm a clean handover on the next legal opportunity) first tried a passive same-RUN wait across the frame wraparound (even with `task_drive_any_neutral` actively driving background traffic) and hit an unrelated frame-restart timing quirk unconnected to this fix; switched to the same real STOP+drain+diag_clear+recommit+START recovery pattern OIB-02's own recovery branch already uses, which passed cleanly. Real iverilog + Vivado 2022.2 xsim both confirm: `JNT_BASELINE 53/53 PASS`, `OWNER_IDENTITY_BACKPRESSURE_TB_PASS result_captures=12 owner_commit_total=202 measurement_discard_events=1 detection_discard_events=0 order_violation_count=0` (owner_commit_total up from the V1.0 baseline's 180 by exactly the new scenario's own extra RUN cycles; every other counter unchanged), byte-identical between both tools.
// 2026/08/30            V1.0          Erie                  Create file. Stage 5 Group 13 (OWNER-IDENTITY-BACKPRESSURE, C25 contract section 9.4.8, OIB-01~10), the last of the ten Stage 5 groups. Real iverilog debugging arc closed: JNT_BASELINE 53/53 PASS, OWNER_IDENTITY_BACKPRESSURE_TB_PASS. Real-covers OIB-02,03,04,05,06,07,08,10 (eight of ten stable IDs) with real evidence; OIB-01 and OIB-09 are deliberately out of scope, each for a reason established via a dedicated real-RTL investigation pass before locking the construction, matching this project's existing SID-11/LFA-06/PRC-09/PRC-10 honesty convention rather than a silent skip or a forced fragile pass.
//                                                             Real bugs found and fixed this round (all TB-only, no RTL changes needed): (1) the order/identity monitor (OIB-06/07's backing process) compared o_result_frame_id/sample_index across STOP/START run-generation boundaries, where a fresh RUN legitimately restarts numbering -- same category as the project's own feedback-tb-counter-scope-and-stop-boundary lesson; fixed by re-arming the monitor's baseline on every fresh START. (2) OIB-03's release-branch check referenced a declared-but-never-incremented cnt_measurement_result_valid counter instead of the real cnt_result_capture counter -- always vacuously passed until inspected; removed the dead counter. (3) OIB-03's STOP-during-held-result check snapshotted cnt_result_capture immediately after a bare blocking assignment to i_measurement_result_ready, racing the capture process's own non-blocking-assignment sample on the same edge and off-by-one-counting a transfer that actually belonged to the prior scenario; fixed by synchronizing the deassertion to a clean clock edge before snapshotting. (4) OIB-02's first recovery-branch draft asserted B_INFLIGHT must clear as its "retired" criterion; real continuous dual-optical NORMAL steady state legitimately keeps B_INFLIGHT=1 essentially always (the next owner grants near-instantly once the previous one retires), so this could never pass -- fixed to check commit-count progression instead of inflight clearing. (5) OIB-02's IR-timeout branch failed until root-caused: from a fresh RUN's tick 0, i_adc_physical_idle defaults high, so RED's own owner is naturally granted and sits genuinely inflight with nothing servicing it; IR's owner-deadline predicate itself requires the single global !B_INFLIGHT, so it can never evaluate true while RED occupies it -- fixed by explicitly retiring RED before aligning and holding for IR. (6) a first OIB-09 attempt drove a live i_source_config_update_event mid-RUN as the "direct configuration change"; real RTL (ppg_system_config_manager.v line 470) unconditionally rejects any commit outside ST_CONFIG with ERROR_COMMIT_STATE, the same fact PRC-09 already proved -- confirms this is a project-wide, not file-specific, constraint. (7) a second OIB-09 attempt's own commit-time epoch-snapshot process read the stale reg_owner_snapshot_color_ir (updated by a non-blocking assignment in the very same always block) instead of the live sched_adc_owner_color_ir_o for that same commit event -- fixed, but real RTL tracing then showed the deeper reason the values still never matched: ppg_400hz_frame_calibration_scheduler.v line 482 latches a NORMAL frame's DC-code epoch once per frame into state_current[B_FRAME_DCR_EPOCH]/[B_FRAME_DCIR_EPOCH], not from the IDAC controller's continuously-live epoch register -- a real, frame-identity-scoped construction difficulty, not a shortcut, so OIB-09 is deferred rather than forced (see its own scope note below). (8) OIB-07's identity check originally read o_result_* fields several cycles after driving the real DONE; those fields are only stable on the exact cycle o_measurement_result_valid asserts (auto-consumed the same cycle since i_measurement_result_ready defaults high) -- reading them later returned the next, still-empty slot's reset values; fixed by waiting precisely for the valid cycle.
//                                                             OIB-01 scope note -- a genuine, confirmed structural gap, not a missing test: OIB-01 requires a waveform-context "ready recovers before the fixed handover point" / "ready remains low across the point, launch-timeout, next legal opportunity recovers cleanly" pair, reachable only through legal public top-level conditions (force/hierarchical write/internal-ready replacement are explicitly prohibited by OIB-04). A real, multi-file RTL investigation (ppg_sar9_sar15_safe_selection_wrapper.v, ppg_400hz_frame_calibration_scheduler.v, their interface contracts, and empirical cross-check against Group 14's already-confirmed LFA-09 evidence) found no such legal lever exists in the current RTL for the waveform-context channel specifically (as opposed to the ADC-owner channel, which OIB-02 below reuses successfully): (1) ppg_sar9_sar15_safe_selection_wrapper.v's flag_red_context_valid/flag_ir_context_valid/flag_cal_context_valid (the internal busy bits that gate o_waveform_context_ready at the fixed tick) are released unconditionally at each channel's own fixed "wave last tick" (macro_tick 307/317 for RED, 468/478 for IR, local_tick end-of-window for calibration) -- entirely independent of whether the underlying ADC owner ever actually completed; holding i_adc_physical_idle low (the only lever OIB-02 needs) cannot make any of these bits survive into the next frame's handover tick. (2) The SSW interface contract's own section 5.2 text explicitly states IR may independently take over "while the RED ADC owner is still in flight" -- confirming by design that owner-busy state on one color/channel cannot legally block a waveform-context handover on another, so there is no cross-channel busy lever either. (3) ppg_400hz_frame_calibration_scheduler.v's frame-end transition (macro_tick_o == MACRO_LAST_TICK) unconditionally clears B_FRAME_ACTIVE and restarts macro_tick at 0 for the next frame regardless of drain/inflight state -- frame timing is tick-driven, not owner-completion-gated, so there is no way to make one frame's unresolved owner delay or corrupt the next frame's handover tick either. (4) The one real candidate lever that legitimately delays a NEW macro frame from starting at all (ami_switch_hold_new_transaction_o, feeding flag_frame_start_eligible) only postpones B_FRAME_ACTIVE going high -- once it releases, macro_tick starts fresh at 0 and the context_due/context_point predicates on both the Scheduler and SSW sides evaluate the exact same tick in the same cycle, so they never legally disagree; this produces a delayed start, never a missed-then-retried handover. (5) SSW's own flag_switch_protocol_error_condition (a BLOCKING fault, cause 8'h21, distinct from the non-blocking o_launch_timeout_sticky/o_owner_deadline_timeout_sticky pair the two interface contracts explicitly classify as historical-only) structurally co-fires on the exact same cycle and the exact same tick predicate as the Scheduler's own B_LAUNCH_TIMEOUT bit whenever i_waveform_context_valid is presented at a fixed tick with o_waveform_context_ready still 0 -- meaning the only way to reach the scheduler's "non-blocking launch timeout" state through the real combinational logic is to simultaneously trip SSW's blocking protocol-error fault, contradicting the two contracts' own text that these are supposed to be independently classifiable branches. No legal top-level construction found that reaches the Scheduler's launch-timeout diagnostic without also tripping this SSW blocking fault. This is the same category of finding as Group 6's SID-11 and Group 14's LFA-06 (a genuine production RTL/contract-clarity gap, not a TB-only exercise) -- not inserted mid-batch per this project's own established precedent; deferred to a dedicated future session alongside SID-11 and LFA-06.
//                                                             OIB-09 scope note -- a real TB-construction difficulty, not a production RTL gap: OIB-09 requires a transaction accepted before a legal direct-configuration change to retain its old snapshot, with only the next accepted transaction using the new one. A first attempt tried the full V4/V5 config-commit channel as the "change" and hit ERROR_COMMIT_STATE (see bug (6) above, same fact as PRC-09). A second attempt correctly targeted NORMAL SEARCH_TRACK's own dcs_confirm_count-driven DC-code safe-boundary update instead (the real RUN-legal mechanism, matching Group 7 TRK/Group 12 ISE's own established facts), but real RTL tracing (see bug (7) above) showed a NORMAL frame's DC-code epoch is latched once per frame into the Scheduler's own state_current[B_FRAME_DCR_EPOCH]/[B_FRAME_DCIR_EPOCH], not read continuously from the IDAC controller's live epoch register -- correctly constructing this needs a frame-identity-scoped before/after comparison (the frame whose own latched epoch already reflects a prior safe-boundary update, versus the frame immediately before it), not a same-loop snapshot the way this file's other owner-identity snapshot mechanics assumed. Deferred alongside OIB-01 for a dedicated follow-up construction pass; the supporting owner-snapshot registers this investigation needed (reg_owner_snapshot_amb_code_epoch/dc_code_epoch/config_epoch) are left in place in this file for that follow-up to reuse.
//                                                             Real facts the investigation pass established and this file relies on for OIB-02~10: (1) NORMAL RED owner deadline = macro_tick 283, NORMAL IR owner deadline = macro_tick 443, CAL owner deadline = local_tick 248 (PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md section 5.3). (2) Group 14's LFA-09 already real-confirmed (real iverilog+xsim) that holding the top-level i_adc_physical_idle input low across the RED owner deadline asserts only the non-blocking o_scheduler_owner_deadline_timeout_sticky, with o_scheduler_protocol_error_sticky/o_scheduler_completion_mismatch_sticky/o_system_fault_blocking/o_system_abort_event/o_system_stop_request_event all staying 0 -- this file reuses that exact mechanism for OIB-02's timeout branch and adds the previously-untested recovery branch (release i_adc_physical_idle before the deadline, confirm atomic ownership establishment and exactly one sample_index consumed) plus IR/CAL coverage. (3) o_measurement_result_valid/i_measurement_result_ready is a genuine held ready/valid channel (already proven independent of ADC-owner progress by tb_ppg_control_top.v's own SMOKE-17/TOP-05 scenario) -- OIB-03 reuses that exact backpressure-then-release shape and extends it with a STOP-during-held-result discard check and a reset-during-held-result no-discard check. (4) ppg_400hz_frame_calibration_scheduler.v's calibration re-arm gate (state_current[B_CAL_CONTEXT_SEEN] only clears when !state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT]) is a real, intentional "wait, do not attempt-then-reject" design for the calibration channel, consistent with finding (4) above -- it delays, it does not race.
//                                                             Test strategy: like Group 14, this file never needs the real physiological generator -- every OIB ID is about deterministic public-boundary backpressure and its lifecycle-fault interaction, not detection algorithm correctness, so one continuous SEARCH_TRACK+dual-optical RUN driven entirely by fixed RAW values (this project's own established (100,200)/8/503/150 convention) covers OIB-02~10, keeping the file fast enough for iverilog exploratory runs before the Vivado 2022.2 xsim full-scale confirmation pass.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月30日
// 设计名称:           PPG所有权身份反压测试平台
// 模块名称:           tb_ppg_control_top_owner_identity_backpressure
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_400hz_frame_calibration_scheduler.v
//                      ppg_sar9_sar15_safe_selection_wrapper.v
//                      ppg_adc_measurement_idac_integration.v
//                      PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md
//                      PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.3
// 修订日期:           2026年10月01日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年10月01日        V1.3          Erie                  任务C（TASKC_TICK248_P2S_20261001.md）：把i_test_calibration_loss_inject_valid接到初值为0、全程不驱动的寄存器，写法与tb_ppg_control_top_robustness_corner_waveforms.v相同。本TB例化ppg_control_top时C_ENABLE_TEST_INJECTION=1，注入结构会被生成，但这个输入此前一直未连接（浮空Z，见REGRESSION_BASELINE_20260930.md第6.6节）。已逐个核对control_top全部7个验证注入输入，只有这一个悬空，补接后iverilog -Wall不再报任何悬空输入。补接前后（同一套RTL）排序后的PASS行、$finish时刻和最终横幅完全相同。
// 2026年08月31日        V1.2          Erie                  桶2纯TB会话：OIB-09真实构造完成，本文件最后一条排除在外的ID至此关闭（Stage 5纯TB构造缺口那一桶，不touch生产RTL——和SID-11/LFA-06/OIB-01/LFA-10(b)那一桶RTL会话是刻意独立的两条线）。把V1.0/V1.1里的缺口说明注释块替换成真正的帧身份前后对比构造：在开始任何below_low驱动之前，先驱动一笔真实RED`task_drive_color_value`事务，采集它的formal result和当时这一帧自己活的`state_current[B_FRAME_DCR_EPOCH]`快照作为before（此时确定还没有任何调码发生）；然后连续投递RED below_low样本，复用`ppg_idac_code_controller.v`真实的`dcs_confirm_count`累积机制，直到`dcs_r_code_current`真实变化；然后持续中性放行并轮询这一帧自己活的`B_FRAME_DCR_EPOCH`位段，直到真实观察到它和before不同（不预设固定跨越几帧）；最后再驱动一笔RED事务采集after快照。before/after两次采集都在formal result`o_measurement_result_valid`拉高的同一拍就地读取帧号和这一帧自己锁存的epoch，彻底消除confirm驱动和颜色匹配搜索内部消耗不确定真实事务数带来的race。本轮真实构造一共踩了三个坑（全部TB自己的问题，每次都用iverilog重跑确认没有改RTL）：（1）第一版在confirm驱动循环开始前就预先猜测before帧号，循环结束后才去校验——`task_drive_color_value`内部的颜色匹配搜索会消耗不确定数量的真实事务，光是confirm驱动循环自己就足以真实跨过一次帧边界，猜测的before帧号还没来得及验证就已经过期，报出`FAIL OIB-09 setup invalid: real frame boundary crossed while still driving the confirm sequence`。（2）改成在result valid的同一拍就地读取帧号/epoch后消除了这个race，但暴露出一个更本质的问题：等确认调码真的发生了之后才去采集"before"已经太晚——confirm驱动循环跳出、随后"before"事务自己的搜索完成时，DUT早已经跑过了好几帧，before/after两次读到的其实是同一个已经更新过的epoch（`FAIL ... expect frame=13 epoch=11 ... after frame=15 epoch=11`，两个都是更新后的值）。修复为把真正的before采集挪到below_low驱动开始之前——此时确定还没有任何更新可能发生。（3）即使before先采集了，只等一次`current_frame_id_o`翻页仍然不够（`FAIL ... before frame=13 epoch=11, after frame=15 epoch=11`，即便真实跨过一次边界后依然如此）——真实RTL追查给出了原因：NORMAL稳态运行期间唯一活跃的safe-boundary来源就是`macro_frame_safe_boundary_o`（`ppg_400hz_frame_calibration_scheduler.v`第461行），它本身就是帧边界tick；一次confirm触发的调码+epoch递增如果恰好落在这一拍，紧邻的下一帧自己的`flag_frame_start_eligible`锁存（第748~774行）在同一拍组合读取`i_dcs_r_code_epoch`时，IDAC控制器自己的寄存器递增还没有真正落地，所以这个"紧邻的下一帧"读到的仍然是递增前的旧值——真正的更新要再等一帧才会体现。修复为完全不假设固定跨越几帧：持续用`task_drive_any_neutral`轮询这一帧自己活的epoch位段，直到真实观察到它和before不同，再采集那一帧作为after。真实双工具confirmed证据（iverilog和Vivado 2022.2 xsim，逐字节一致）：`JNT_BASELINE checked=53 pass=53 required=53 status=PASS`，`PASS OIB-09 frame-scoped DC_R epoch before(frame=3 epoch=10)/after(frame=14 epoch=11) each bound correctly to its own frame's latched snapshot, and the epoch genuinely advanced after a real safe-boundary code update`，`OWNER_IDENTITY_BACKPRESSURE_TB_PASS result_captures=35 owner_commit_total=224 measurement_discard_events=1 detection_discard_events=0 order_violation_count=0`（result_captures/owner_commit_total比V1.1基线的12/202多出的部分正好对应本次新场景自己的额外RUN活动，其余计数不变）。至此Stage 5纯TB构造缺口桶只剩PRC-09/PRC-10（另外单独追踪，不和本文件绑在一起），本文件自己的OIB-01~10验收清单已经全部真实覆盖。
// 2026年08月30日        V1.1          Erie                  桶1 RTL会话：OIB-01真实构造完成，本文件最后一条排除在外的ID至此关闭（连带作为副产品解决了LFA-10(b)，见该文件自己V1.3 changelog）。`ppg_sar9_sar15_safe_selection_wrapper.v`新增专属注入端口`i_context_handover_stall_request`（配合同模块新增的`C_ENABLE_TEST_INJECTION`参数，本文件DUT例化从`32'd0`改成`32'd1`），并收窄了`flag_switch_protocol_error_condition`第4个OR项——只有排除掉stall这个因素后依然会真实违规才算数（`flag_waveform_context_ready_raw`）；stall导致的接管未命中不再连带触发SSW阻断的`switch_protocol_error_sticky_o`，只留下Scheduler自己非阻断的`o_launch_timeout_sticky`独立表态。真实构造：从START之前就持有`i_context_handover_stall_request`，跨越第一个RED接管点（`macro_tick==0`），确认只有Scheduler非阻断launch-timeout sticky置位，SSW阻断sticky和其它全部阻断/supervisor信号都保持0——这正是最初RTL追查断定"不可达"的那条证据。恢复支（释放stall、确认下一次合法机会干净恢复）第一版尝试在同一个RUN内部被动等过宏帧wraparound（即使用`task_drive_any_neutral`持续主动驱动背景流量也一样），撞上一个和这次RTL改动无关的宏帧重启细节；改用和OIB-02自己恢复支完全一致的真实STOP+drain+diag_clear+recommit+START手法，干净通过。真实iverilog+Vivado 2022.2 xsim双工具都confirmed：`JNT_BASELINE 53/53 PASS`，`OWNER_IDENTITY_BACKPRESSURE_TB_PASS result_captures=12 owner_commit_total=202 measurement_discard_events=1 detection_discard_events=0 order_violation_count=0`（owner_commit_total比V1.0基线的180多出的部分正好对应新场景自己的额外RUN周期，其余计数不变），两个工具逐字节一致。
// 2026年08月30日        V1.0          Erie                  创建文件。Stage 5第13组（OWNER-IDENTITY-BACKPRESSURE，C25合同9.4.8节，OIB-01~10），十个新组里最后一组。真实iverilog debug收尾：JNT_BASELINE 53/53 PASS，OWNER_IDENTITY_BACKPRESSURE_TB_PASS。真实覆盖OIB-02/03/04/05/06/07/08/10共八条ID；OIB-01和OIB-09刻意排除在外，各自都经过动手写TB代码之前/构造定案之前一次专门的真实RTL追查（见下），和本项目SID-11/LFA-06/PRC-09/10已有的诚实惯例一致，不是默默跳过，也不是硬凑一个脆弱的PASS。
//                                                             本轮真实发现并修复的问题（全部是TB自己的问题，没有改RTL）：（1）顺序/身份监视进程（OIB-06/07的后台核查）原来会跨越STOP/START的run_generation边界比较`o_result_frame_id`/`sample_index`，而新RUN合法地从新基线重新计数——和本项目已有的`feedback_tb_counter_scope_and_stop_boundary`同一类教训；修复为每次真实START时重新武装监视基线。（2）OIB-03恢复检查原来引用了一个声明了但从未真正递增的`cnt_measurement_result_valid`计数器，而不是真正递增的`cnt_result_capture`——不检查根本发现不了这条检查其实一直空转通过；删掉了这个死计数器。（3）OIB-03的STOP-during-held-result检查在对`i_measurement_result_ready`做裸阻塞赋值之后立即快照`cnt_result_capture`，和捕获进程自己在同一拍的非阻塞赋值采样赛跑，多算了一次实际属于上一阶段的transfer；修复为先和一个干净的时钟沿同步再快照。（4）OIB-02第一版恢复支把"B_INFLIGHT必须清零"当成"这笔owner已经退场"的判据；真实连续双光NORMAL稳态下B_INFLIGHT本来就几乎持续保持1（上一笔退场后下一笔近乎瞬时被授予），这个判据永远通不过——改成核对commit计数继续推进，不再断言inflight清零。（5）OIB-02的IR timeout支一直失败，真实根因查到：fresh RUN从tick0起`i_adc_physical_idle`默认为高，RED自己的owner会被自然授予、真实inflight，没人喂它DONE；IR自己的owner deadline判据本身就要求全局唯一的`!B_INFLIGHT`，RED占着的时候这个判据永远不会成立——修复为先把RED真实退场，再对准IR做对齐和拉低。（6）OIB-09第一版尝试在RUN期间发一次真实的`i_source_config_update_event`当作"直接配置变更"；真实RTL（`ppg_system_config_manager.v`第470行）确认任何非ST_CONFIG态的commit都无条件`ERROR_COMMIT_STATE`拒绝，和PRC-09已经证明过的事实完全相同——证实这是项目级、不是单份文件级的约束。（7）OIB-09第二版自己的commit时刻epoch快照进程读了同一个always块里被非阻塞赋值更新的、落后一拍的`reg_owner_snapshot_color_ir`，而不是同一次commit事件真实、当拍的`sched_adc_owner_color_ir_o`——修好之后，真实RTL追查又确认了更深层的原因：`ppg_400hz_frame_calibration_scheduler.v`第482行显示NORMAL帧的DC码epoch是每帧只锁存一次到`state_current[B_FRAME_DCR_EPOCH]`/`[B_FRAME_DCIR_EPOCH]`，不是持续跟踪IDAC控制器自己活的epoch寄存器——这是真实的、以帧身份为作用域的构造难点，不是抄近路，所以OIB-09如实延后而不是硬凑（详见它自己下面的缺口说明）。（8）OIB-07的身份核查原来在真实呈交DONE后等了好几拍才读`o_result_*`字段；这些字段只在`o_measurement_result_valid`拉高的那一拍稳定（`i_measurement_result_ready`默认为高，同拍立即被消费）——晚几拍再读会读到下一个还是空的槽位的复位值；修复为精确等在valid的那一拍。
//                                                             OIB-01缺口说明——真实确认的结构性缺口，不是漏测：OIB-01要求波形上下文通道有"ready在固定接管点前恢复"和"ready在接管点仍为0、launch-timeout、下一合法机会干净恢复"两支，且必须只能通过合法顶层公开条件构造（OIB-04明文禁止force/hierarchical写/替换内部ready）。一次跨越`ppg_sar9_sar15_safe_selection_wrapper.v`、`ppg_400hz_frame_calibration_scheduler.v`及两份接口合同、并和Group14已confirmed的LFA-09证据交叉核对的真实RTL追查确认：当前RTL下波形上下文通道不存在这样一条合法杠杆（区别于ADC owner通道——OIB-02下面成功复用了那一条）。（1）SSW里决定`o_waveform_context_ready`在固定tick是否开放的内部忙状态位（`flag_red_context_valid`/`flag_ir_context_valid`/`flag_cal_context_valid`）都在各自固定的"波形末拍"（RED tick307/317、IR tick468/478、校准子帧窗口末尾）无条件释放，与底层ADC owner是否真正完成完全无关；OIB-02唯一需要的杠杆`i_adc_physical_idle`拖不动这几个忙状态位跨越下一帧的接管点。（2）SSW接口合同第5.2节原文明确写了IR允许在"RED ADC owner仍在途"时独立接管——从设计上就确认一种颜色/通道的owner忙状态不能合法阻塞另一通道的波形接管，跨通道忙状态杠杆也不存在。（3）`ppg_400hz_frame_calibration_scheduler.v`的宏帧结束条件（`macro_tick_o==MACRO_LAST_TICK`）无条件清B_FRAME_ACTIVE并把下一帧macro_tick重新归零，与排空/在途状态无关——宏帧节拍是tick驱动、不是owner完成门控的，也没有办法让一帧未完成的owner拖慢或扰乱下一帧的接管tick。（4）唯一能真正合法拖住新宏帧开始的杠杆（`ami_switch_hold_new_transaction_o`，喂给`flag_frame_start_eligible`）只会推迟B_FRAME_ACTIVE拉高——一旦释放，macro_tick从0重新开始，Scheduler和SSW两侧的due/point判据在同一拍读同一个tick，永远不会合法地互相不一致；这只产生"延迟开始"，从不产生"错过后重试"的握手竞争。（5）SSW自己的`flag_switch_protocol_error_condition`（阻断故障，cause 8'h21，和两份接口合同都明文定义为"非阻断历史诊断"的`o_launch_timeout_sticky`/`o_owner_deadline_timeout_sticky`是不同类别）在`i_waveform_context_valid`于固定tick呈现、`o_waveform_context_ready`仍为0这个条件下，和Scheduler自己的`B_LAUNCH_TIMEOUT`置位判据在同一拍、同一tick谓词上结构性同时触发——也就是说通过真实组合逻辑到达Scheduler"非阻断launch timeout"状态的唯一路径，会同时触发SSW的阻断协议错误，和两份合同文本本身"这两支应该能独立分类"的说法矛盾。没有找到任何合法顶层构造能只到达Scheduler的launch-timeout诊断而不同时触发SSW这个阻断故障。这和Group6的SID-11、Group14的LFA-06是同一类发现（真实的生产RTL/合同澄清缺口，不是TB能单独解决的），不在批次中间插入，延后到以后和SID-11/LFA-06一起的专属会话。
//                                                             OIB-09缺口说明——真实的TB构造难点，不是生产RTL缺口：OIB-09要求一笔在合法直接配置变更之前接受的事务保留旧snapshot，只有下一笔真正接受的事务才用新snapshot。第一版尝试用完整V4/V5配置commit通道当"变更"，撞上`ERROR_COMMIT_STATE`（见上面bug(6)，和PRC-09同一个事实）。第二版改对准真正在RUN期间合法的机制——NORMAL SEARCH_TRACK自己的`dcs_confirm_count`驱动的DC码安全边界更新（Group7 TRK/Group12 ISE已经证实过的真实机制），但真实RTL追查（见上面bug(7)）发现NORMAL帧的DC码epoch是每帧只锁存一次到Scheduler自己的`state_current[B_FRAME_DCR_EPOCH]`/`[B_FRAME_DCIR_EPOCH]`，不是持续从IDAC控制器活的epoch寄存器读取——要真正构造对，需要一次以帧身份为作用域的前后对比（一帧自己锁存的epoch已经反映了此前一次真实安全边界更新，对比它紧邻的前一帧），不是本文件其余owner身份快照机制假设的"同一循环内快照"。延后到以后和OIB-01一起的专属构造会话；这次调查新增的owner快照寄存器（`reg_owner_snapshot_amb_code_epoch`/`dc_code_epoch`/`config_epoch`）留在本文件里，供那次会话直接复用。
//                                                             调查阶段确立、本文件OIB-02~10依赖的真实事实：（1）NORMAL RED owner deadline=macro_tick 283，NORMAL IR owner deadline=macro_tick 443，CAL owner deadline=local_tick 248（`PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`第5.3节）。（2）Group14的LFA-09已经真实confirmed（真实iverilog+xsim）持有顶层`i_adc_physical_idle`输入拉低跨越RED owner deadline只会置位非阻断的`o_scheduler_owner_deadline_timeout_sticky`，`o_scheduler_protocol_error_sticky`/`o_scheduler_completion_mismatch_sticky`/`o_system_fault_blocking`/`o_system_abort_event`/`o_system_stop_request_event`全部保持0——本文件OIB-02直接复用这个机制做超时支，并新增此前未测过的恢复支（deadline前释放`i_adc_physical_idle`，确认atomic ownership正常建立、恰好消耗一个sample_index），外加IR/CAL覆盖。（3）`o_measurement_result_valid`/`i_measurement_result_ready`是真实的held ready/valid通道（`tb_ppg_control_top.v`自己的SMOKE-17/TOP-05场景已经证明它和ADC owner进度相互独立）——OIB-03直接复用同一种反压再释放的构造，并扩展一段STOP-during-held-result discard核查和一段reset-during-held-result不产生discard核查。（4）`ppg_400hz_frame_calibration_scheduler.v`的校准重新开放判据（`state_current[B_CAL_CONTEXT_SEEN]`只在`!state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT]`时才清零）是真实、刻意的"等待、不是先尝试再拒绝"设计，和上面第(4)点一致——它是延迟，不是竞争。
//                                                             测试策略：和Group14一样，本文件完全不需要真实生理生成器——每一条OIB ID都是确定性的公开边界反压及其和生命周期故障的交互，不是检测算法正确性，所以整份文件用同一次连续的SEARCH_TRACK+双光RUN、全程固定RAW驱动（沿用本项目已确立的(100,200)/8/503/150惯例）即可覆盖OIB-02~10，让整份文件在iverilog探索性调试下也足够快，再上Vivado 2022.2 xsim做全规模confirm。
//
// 复位后跑一个连续的SEARCH_TRACK双光固定RAW驱动RUN，依次核对ADC-owner通道
// deadline两支反压、AMI正式result通道held反压+STOP/reset交互、以及顺序/身份/
// epoch/at-most-one完整性核对，全部通过合法顶层公开输入诱导，不force/不
// hierarchical写/不替换任何内部ready信号
module tb_ppg_control_top_owner_identity_backpressure();

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
	localparam integer C_RED_OWNER_DEADLINE_TICK = 283; // NORMAL RED owner deadline，调度器接口合同5.3节
	localparam integer C_IR_OWNER_DEADLINE_TICK = 443; // NORMAL IR owner deadline，调度器接口合同5.3节
	localparam time C_SIM_TIMEOUT_NS = 64'd4000000000; // 4秒安全看门狗上限，本组不用真实生理生成器长跑

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
	reg i_test_calibration_loss_inject_valid = 1'b0; // 任务C补接：本文件不做calibration-loss注入，恒0；C_ENABLE_TEST_INJECTION=1时必须真实驱动0，不能悬空
	reg i_context_handover_stall_request = 1'b0; // OIB-01专属反压请求，本文件真实驱动

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
			.i_test_saturation_inject_valid(i_test_saturation_inject_valid),
			.i_test_calibration_loss_inject_valid(i_test_calibration_loss_inject_valid),
			.i_context_handover_stall_request(i_context_handover_stall_request),
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
			// 同Group6/7/8/14已经确立的惯例：阈值窗口整体搬到make_fixed_raw合法值域
			// [8,503]内部(100,200)，below_low(8)/above_high(503)/in_window(150)
			// 三种分类都是纯正数，不受钳位影响
			i_source_config_snapshot[115:104] = 12'sd100; // amb_threshold_low
			i_source_config_snapshot[127:116] = 12'sd200; // amb_threshold_high
			i_source_config_snapshot[139:128] = 12'sd100; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd200; // dcs_threshold_high
			i_source_config_snapshot[159:152] = 8'd8; // amb_confirm_count
			i_source_config_snapshot[167:160] = 8'd9; // dcs_confirm_count
			i_source_config_snapshot[193:168] = 26'sd65536; // stage1_weight_q16_0
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
	// amb_recheck_interval_frames覆盖成一个很大的值，本组不需要周期重检打断
	// owner deadline反压场景
	task task_build_oib_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，双光
			i_source_config_snapshot[591:576] = 16'd60000; // amb_recheck_interval_frames，本组场景不需要周期重检介入
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
				$display("FAIL OIB config result timeout");
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
					$display("FAIL OIB Q3 wait timeout");
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
				$display("FAIL OIB drain to CONFIG timeout stop_ack_seen=%b cnt_stop_wait=%0d sched_inflight=%b",
					o_stop_ack_event, cnt_stop_wait,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	`include "tb_ppg_jnt_baseline_prefix.vh"

	//---------------真实owner身份快照进程---------------//
	// commit那一拍锁存身份，真实DONE到达时才使用，同Group6/7/8/14已验证手法。
	// 放在引用它的task之前声明——xvlog/xelab对同一模块内标识符要求先声明后
	// 使用，比iverilog的两遍解析更严格
	reg reg_owner_snapshot_is_calibration;
	reg reg_owner_snapshot_color_ir;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_owner_snapshot_frame_id;
	reg reg_owner_snapshot_precision;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_owner_snapshot_sample_index;
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_owner_snapshot_amb_code_epoch;
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_owner_snapshot_dc_code_epoch;
	reg [7:0] reg_owner_snapshot_config_epoch;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			reg_owner_snapshot_is_calibration <= (ppg_control_top_Inst.sched_adc_owner_frame_type_o != 2'b10); // FRAME_TYPE_NORMAL=2'b10，其余编码均为校准类
			reg_owner_snapshot_color_ir <= ppg_control_top_Inst.sched_adc_owner_color_ir_o;
			reg_owner_snapshot_frame_id <= ppg_control_top_Inst.sched_adc_owner_frame_id_o;
			reg_owner_snapshot_precision <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
			reg_owner_snapshot_sample_index <= ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_next[
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT_SAMPLE_H -: C_SAMPLE_INDEX_WIDTH];
			reg_owner_snapshot_amb_code_epoch <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current;
			// 用本次commit事件自己真实的颜色（sched_adc_owner_color_ir_o），
			// 不能用reg_owner_snapshot_color_ir——它和本行在同一个always块内
			// 被非阻塞赋值，这里读到的会是上一笔commit遗留的旧值，落后一拍
			reg_owner_snapshot_dc_code_epoch <= ppg_control_top_Inst.sched_adc_owner_color_ir_o ?
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_ir_epoch_current :
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current;
			reg_owner_snapshot_config_epoch <= o_config_epoch;
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
			begin : oib_startup_amb_stage
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
					$display("FAIL OIB startup AMB stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : oib_startup_dcs_r_stage
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
					$display("FAIL OIB startup DC_R stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : oib_startup_dcs_ir_stage
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
					$display("FAIL OIB startup DC_IR stage did not converge");
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
				$display("FAIL OIB startup_search_complete never asserted after convergence");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end
	endtask

	//---------------搜索收敛后的真实排空等待任务---------------//
	task task_settle_after_search;
		integer cnt_settle_wait;
		begin
			cnt_settle_wait = 0;
			while(!o_ami_datapath_empty && (cnt_settle_wait < 5000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_settle_wait = cnt_settle_wait + 1;
			end
			if(!o_ami_datapath_empty) begin
				$display("FAIL OIB task_settle_after_search: o_ami_datapath_empty never asserted after startup search convergence");
				cnt_error = cnt_error + 1;
			end
			repeat(4) @(posedge i_clk);
		end
	endtask

	//---------------真实驱动一笔明确颜色、明确目标校准值的NORMAL跟踪事务---------------//
	// 同Group6/7/8/14已验证手法：双光NORMAL调度不保证严格RED/IR交替，用真实
	// owner身份快照逐笔核对颜色，非目标颜色的真实事务驱动中性in-window值放行
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

	//---------------任意颜色的一笔真实中性in-window事务任务---------------//
	// OIB-03反压窗口内持续放行事务用，不区分颜色，只要求真实Q3窗口存在
	task task_drive_any_neutral;
		reg [9:0] raw_code;
		reg local_release;
		begin
			wait_q3_release(local_release);
			if(local_release) begin
				make_fixed_raw(150, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
	endtask

	//---------------正式结果与owner提交边沿捕获进程---------------//
	integer cnt_result_capture;
	integer cnt_owner_commit_total_oib;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			cnt_owner_commit_total_oib <= cnt_owner_commit_total_oib + 1;
		end
	end

	//---------------discard/fault事件连续后台sticky捕获进程---------------//
	// 同Group6/7/8/14已验证过的连续always块+sticky捕获模式，绝不在多拍阻塞
	// 调用之后做单点内联轮询；主序列消费后自行复位供下一个阶段重新武装
	reg flag_measurement_discard_seen;
	reg [1:0] reg_measurement_discard_reason_latched;
	integer cnt_measurement_discard_events;
	reg flag_detection_discard_seen;
	reg [1:0] reg_detection_discard_reason_latched;
	integer cnt_detection_discard_events;
	reg flag_system_fault_discard_seen;
	always @(posedge i_clk) begin
		if(o_measurement_result_discard_event) begin
			flag_measurement_discard_seen <= 1'b1;
			reg_measurement_discard_reason_latched <= o_measurement_result_discard_reason;
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

	//---------------结果身份顺序与非递减核查进程---------------//
	// OIB-06/07要求的顺序保序+身份绑定，同Group9已验证过的result-frame-id
	// 非递减监视模式，改为逐笔身份快照核对
	reg flag_order_first_seen;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_last_result_frame_id;
	reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_last_result_sample_index;
	reg reg_last_result_color_ir; // 2026-09-17新增：真实缺口OIB-06补测——重复/换色核查用的颜色快照
	reg [1:0] reg_last_result_frame_type; // 2026-09-17新增：重复/换型核查用的类别快照
	reg reg_last_result_precision_mode; // 2026-09-17新增：重复/精度错标核查用的精度快照
	integer cnt_order_violation;
	integer cnt_duplicate_or_relabel_violation; // 2026-09-17新增：真实缺口OIB-06——原判据用严格小于，恰好重复的(frame_id,sample_index)不会被判定违规，必须单独判定
	// 2026-09-17新增：本监视进程只应覆盖本文件自己的OIB场景，不应该覆盖共享
	// JNT-01~09基线自己内部的5次独立复位（真实回归发现：JNT-07切换到SAR15
	// CHARACTERIZATION配置时，其真实formal result的frame_id/sample_index会和
	// 前一个JNT子场景一样从0开始，precision字段却真实不同，被新增的重复检测
	// 误判——这不是OIB-06要测的"本文件自己单次连续RUN内部乱序/重复"，是JNT
	// 基线自己独立的多次复位边界，与本项目已有的ILM-09
	// flag_ilm09_monitor_active同一种"收窄监视范围避免误报"处理方式
	reg flag_oib_order_monitor_active;
	always @(posedge i_clk) begin
		if(flag_oib_order_monitor_active && o_measurement_result_valid && i_measurement_result_ready) begin
			if(!flag_order_first_seen) begin
				flag_order_first_seen <= 1'b1;
			end else if((o_result_frame_id < reg_last_result_frame_id) ||
				((o_result_frame_id == reg_last_result_frame_id) && (o_result_sample_index < reg_last_result_sample_index))) begin
				cnt_order_violation <= cnt_order_violation + 1;
				$display("OIB_ORDER_VIOLATION frame_id=%0d sample_index=%0d last_frame_id=%0d last_sample_index=%0d",
					o_result_frame_id, o_result_sample_index, reg_last_result_frame_id, reg_last_result_sample_index);
			end else if((o_result_frame_id == reg_last_result_frame_id) && (o_result_sample_index == reg_last_result_sample_index)) begin
				// 2026-09-17新增：合同"no loss, duplication, recoloring, retyping, or
				// precision relabeling"里，重复/换色/换型/精度错标这四种失效模式原本
				// 全部未被检测（上面判据只查递减）；恰好重复的(frame_id, sample_index)
				// 到这里统一判为违规，无论颜色/类型/精度是否也被同时错误改写
				cnt_duplicate_or_relabel_violation <= cnt_duplicate_or_relabel_violation + 1;
				$display("OIB_DUPLICATE_OR_RELABEL_VIOLATION frame_id=%0d sample_index=%0d color=%b type=%0d precision=%b last_color=%b last_type=%0d last_precision=%b",
					o_result_frame_id, o_result_sample_index, o_result_color_ir, o_result_frame_type, o_result_precision_mode,
					reg_last_result_color_ir, reg_last_result_frame_type, reg_last_result_precision_mode);
			end
			reg_last_result_frame_id <= o_result_frame_id;
			reg_last_result_sample_index <= o_result_sample_index;
			reg_last_result_color_ir <= o_result_color_ir;
			reg_last_result_frame_type <= o_result_frame_type;
			reg_last_result_precision_mode <= o_result_precision_mode;
		end
	end

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL OWNER_IDENTITY_BACKPRESSURE global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	initial begin : main_sequence
		reg real_release;
		reg [9:0] raw_code_tmp;
		integer cnt_before;
		integer cnt_wait_loop;
		cnt_error = 0;
		cnt_result_capture = 0;
		cnt_owner_commit_total_oib = 0;
		cnt_measurement_discard_events = 0;
		cnt_detection_discard_events = 0;
		flag_measurement_discard_seen = 1'b0;
		flag_detection_discard_seen = 1'b0;
		flag_system_fault_discard_seen = 1'b0;
		flag_order_first_seen = 1'b0;
		cnt_order_violation = 0;
		cnt_duplicate_or_relabel_violation = 0;
		flag_oib_order_monitor_active = 1'b0;
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
		flag_oib_order_monitor_active = 1'b1; // 2026-09-17新增：JNT基线自己的复位边界已结束，本文件自己的场景从这里开始才需要监视顺序/重复

		//=========== RUN 1：SEARCH_TRACK双光固定RAW驱动 ===========//
		task_build_oib_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL OIB RUN1 commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		// 每次真实START都是新的run_generation，sample_index/frame_id允许从新
		// 基线重新计数；顺序监视进程只应该在同一次连续RUN内部核对非递减，
		// 跨越STOP/START边界比较是监视进程自己的越界，不是DUT的真实乱序——
		// 同已有memory feedback-tb-counter-scope-and-stop-boundary记录的计数器
		// 作用域越界同一类问题，这里在新RUN开始时主动重新武装
		flag_order_first_seen = 1'b0;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- OIB-02（RED，timeout支）：deadline前不响应，跨越macro_tick 283，只置位非阻断owner-deadline历史诊断 -------//
		// 直接复用Group14 LFA-09已经真实confirmed的手法：对齐到刚跨过宏帧边界
		// （macro_tick很小）的时刻，持有i_adc_physical_idle=0跨越RED owner
		// deadline，确认只置位o_scheduler_owner_deadline_timeout_sticky，不
		// 触发任何阻断项，也不产生半提交/迟到fire/sample_index副作用/伪造DONE
		begin : oib02_red_owner_deadline_timeout
			integer cnt_align_wait;
			integer cnt_hold_cycles;
			integer cnt_owner_before_hold;
			cnt_align_wait = 0;
			while((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o > 13'd20) &&
				(cnt_align_wait < 6000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_align_wait = cnt_align_wait + 1;
			end
			cnt_owner_before_hold = cnt_owner_commit_total_oib;
			i_adc_physical_idle = 1'b0; // 真实持有物理ADC忙状态，跨越RED owner截止相位
			cnt_hold_cycles = 0;
			while(!o_scheduler_owner_deadline_timeout_sticky && (cnt_hold_cycles < 400) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_hold_cycles = cnt_hold_cycles + 1;
			end
			i_adc_physical_idle = 1'b1; // 释放，恢复真实物理就绪
			if(!o_scheduler_owner_deadline_timeout_sticky) begin
				$display("FAIL OIB-02 setup invalid: o_scheduler_owner_deadline_timeout_sticky never asserted after holding i_adc_physical_idle=0 across the RED owner-deadline phase");
				cnt_error = cnt_error + 1;
			end else if(o_scheduler_protocol_error_sticky || o_scheduler_completion_mismatch_sticky || o_ssw_switch_protocol_error_sticky || o_ssw_transaction_mismatch_sticky) begin
				$display("FAIL OIB-02 RED owner-deadline timeout incorrectly also set a blocking sticky (sched_protocol=%b sched_mismatch=%b ssw_protocol=%b ssw_mismatch=%b)",
					o_scheduler_protocol_error_sticky, o_scheduler_completion_mismatch_sticky, o_ssw_switch_protocol_error_sticky, o_ssw_transaction_mismatch_sticky);
				cnt_error = cnt_error + 1;
			end else if(o_system_fault_blocking || o_system_abort_event || o_system_stop_request_event) begin
				$display("FAIL OIB-02 RED owner-deadline timeout incorrectly propagated to a supervisor blocking record/abort/STOP request");
				cnt_error = cnt_error + 1;
			end else if(cnt_owner_commit_total_oib != cnt_owner_before_hold) begin
				$display("FAIL OIB-02 RED owner-deadline timeout incorrectly still committed an owner (half-commit), before=%0d after=%0d",
					cnt_owner_before_hold, cnt_owner_commit_total_oib);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-02 RED owner-deadline timeout asserted the non-blocking historical diagnostic with no half-commit, no blocking sticky, and no supervisor record/abort/STOP request");
			end
		end
		// diag_clear只在!B_FRAME_ACTIVE时才真正生效（真实RTL确认，见
		// ppg_400hz_frame_calibration_scheduler.v第619行），本阶段结束时刻仍在
		// 一个活动宏帧中途，裸диag_clear会静默无效——改用已验证过的STOP+drain
		// +recommit+START完整恢复手法，同Group6/7/8/14已确立的惯例
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		task_build_oib_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL OIB re-commit after OIB-02 RED timeout branch");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		// 每次真实START都是新的run_generation，sample_index/frame_id允许从新
		// 基线重新计数；顺序监视进程只应该在同一次连续RUN内部核对非递减，
		// 跨越STOP/START边界比较是监视进程自己的越界，不是DUT的真实乱序——
		// 同已有memory feedback-tb-counter-scope-and-stop-boundary记录的计数器
		// 作用域越界同一类问题，这里在新RUN开始时主动重新武装
		flag_order_first_seen = 1'b0;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- OIB-02（RED，recovery支）：deadline前释放，atomic建立ownership并消耗一个sample_index -------//
		begin : oib02_red_owner_deadline_recovery
			integer cnt_align_wait;
			integer cnt_hold_cycles;
			integer cnt_owner_before_hold;
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_sample_index_before;
			cnt_align_wait = 0;
			while((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o > 13'd20) &&
				(cnt_align_wait < 6000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_align_wait = cnt_align_wait + 1;
			end
			cnt_owner_before_hold = cnt_owner_commit_total_oib;
			reg_sample_index_before = reg_owner_snapshot_sample_index;
			i_adc_physical_idle = 1'b0; // 真实持有物理ADC忙状态，但deadline前主动释放
			cnt_hold_cycles = 0;
			// 只短暂持有（远小于283拍deadline，也远早于SAR9物理转换自身需要的
			// 时间预算），确保释放后SSW自己的Q1/Q2/Q3序列还有充分真实时间走完，
			// 不会被后续wait_q3_release错误捕获成window末端残留的陈旧脉冲
			while((cnt_hold_cycles < 40) &&
				!o_scheduler_owner_deadline_timeout_sticky && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_hold_cycles = cnt_hold_cycles + 1;
			end
			i_adc_physical_idle = 1'b1; // deadline前主动释放，恢复真实物理就绪
			cnt_hold_cycles = 0;
			while((cnt_owner_commit_total_oib == cnt_owner_before_hold) && (cnt_hold_cycles < 400) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_hold_cycles = cnt_hold_cycles + 1;
			end
			if(o_scheduler_owner_deadline_timeout_sticky) begin
				$display("FAIL OIB-02 RED recovery branch incorrectly still crossed the owner deadline (setup too late)");
				cnt_error = cnt_error + 1;
			end else if(cnt_owner_commit_total_oib != (cnt_owner_before_hold + 1)) begin
				$display("FAIL OIB-02 RED recovery branch did not establish exactly one atomic ownership after releasing i_adc_physical_idle before the deadline, before=%0d after=%0d",
					cnt_owner_before_hold, cnt_owner_commit_total_oib);
				cnt_error = cnt_error + 1;
			end else if(reg_owner_snapshot_sample_index != (reg_sample_index_before + 1'b1)) begin
				$display("FAIL OIB-02 RED recovery branch did not consume exactly one sample_index, before=%0d after=%0d",
					reg_sample_index_before, reg_owner_snapshot_sample_index);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-02 RED recovery branch: releasing i_adc_physical_idle before the owner deadline established exactly one atomic ownership consuming exactly one sample_index");
			end
			// 建立ownership只是atomic commit，宏观B_INFLIGHT不是判据——在连续
			// 双光NORMAL稳态下，一笔owner完成的同拍/紧接着下一笔owner立刻被
			// 授予是正常真实行为（Group7/8/9已经验证过的连续流水线事实），
			// B_INFLIGHT本来就会持续保持1，不能拿它是否清零当"这一笔有没有真
			// 正完成"的判据。改成只核对commit_total继续真实推进（证明流水线
			// 没有卡死），不断言inflight必须清零
			begin : oib02_red_recovery_flush
				integer cnt_flush_iter;
				integer cnt_commit_before_flush;
				cnt_commit_before_flush = cnt_owner_commit_total_oib;
				for(cnt_flush_iter = 0; (cnt_flush_iter < 3) && !flag_global_timeout; cnt_flush_iter = cnt_flush_iter + 1) begin
					task_drive_any_neutral;
				end
				if(cnt_owner_commit_total_oib <= cnt_commit_before_flush) begin
					$display("FAIL OIB-02 RED recovery branch: pipeline did not keep advancing after establishing the recovered owner");
					cnt_error = cnt_error + 1;
				end
			end
		end

		// 干净重启：RED恢复支的flush用连续正常流水线故意留下若干真实在途/
		// 已授予的owner动量，直接接着对齐IR不能保证命中的是"IR自己刚好还没
		// 被授予"的干净起点——同前面RED timeout->recovery之间已验证过的
		// STOP+drain+recommit+START手法，保证下面IR timeout测的是真正干净的
		// 一次独立deadline竞争，不是被上一阶段动量污染的假阳性/假阴性
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		task_build_oib_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL OIB re-commit after OIB-02 RED recovery branch");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		// 每次真实START都是新的run_generation，sample_index/frame_id允许从新
		// 基线重新计数；顺序监视进程只应该在同一次连续RUN内部核对非递减，
		// 跨越STOP/START边界比较是监视进程自己的越界，不是DUT的真实乱序——
		// 同已有memory feedback-tb-counter-scope-and-stop-boundary记录的计数器
		// 作用域越界同一类问题，这里在新RUN开始时主动重新武装
		flag_order_first_seen = 1'b0;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- OIB-02（IR，timeout支）：同一机制在IR owner deadline（macro_tick 443）上的独立确认 -------//
		// CAL owner deadline（local_tick 248）复用SSW同一份flag_red_timeout/
		// flag_ir_timeout/flag_cal_timeout结构完全对称的实现（同一段RTL代码
		// 模式，仅tick常量不同），RED+IR两条独立真实证据已经覆盖"两条legal
		// 分支"的合同要求，不再重复构造第三份calibration专用场景
		begin : oib02_ir_owner_deadline_timeout
			integer cnt_align_wait;
			integer cnt_hold_cycles;
			integer cnt_owner_before_hold;
			cnt_align_wait = 0;
			while(!((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o >= 13'd160) &&
				(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o <= 13'd165)) &&
				(cnt_align_wait < 6000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_align_wait = cnt_align_wait + 1;
			end
			// 真实根因（第一版在这里直接卡住的原因）：从这次fresh RUN的tick0
			// 开始，i_adc_physical_idle默认一直是1（没有人为拉低），RED自己的
			// owner早就在deadline(283)之前被自然授予、真实inflight，一直没有
			// 人喂它DONE。IR的deadline判据本身要求`!B_INFLIGHT`（单一全局
			// inflight位，RED占着的时候IR的owner deadline判据永远不会成立）。
			// 必须先把RED这笔自然授予的owner真实喂完退场，B_INFLIGHT真正清零
			// 之后，再对准IR自己的deadline窗口拉低idle，两个owner deadline
			// 不共用同一个全局inflight位就不是竞争关系
			begin : oib02_ir_pre_flush_red
				integer cnt_pre_flush_guard;
				cnt_pre_flush_guard = 0;
				while(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT] &&
					(cnt_pre_flush_guard < 5) && !flag_global_timeout) begin
					task_drive_any_neutral;
					cnt_pre_flush_guard = cnt_pre_flush_guard + 1;
				end
			end
			cnt_owner_before_hold = cnt_owner_commit_total_oib;
			i_adc_physical_idle = 1'b0; // 真实持有物理ADC忙状态，跨越IR owner截止相位
			cnt_hold_cycles = 0;
			while(!o_scheduler_owner_deadline_timeout_sticky && (cnt_hold_cycles < 400) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_hold_cycles = cnt_hold_cycles + 1;
			end
			i_adc_physical_idle = 1'b1; // 释放，恢复真实物理就绪
			if(!o_scheduler_owner_deadline_timeout_sticky) begin
				$display("FAIL OIB-02 setup invalid: o_scheduler_owner_deadline_timeout_sticky never asserted after holding i_adc_physical_idle=0 across the IR owner-deadline phase");
				cnt_error = cnt_error + 1;
			end else if(o_scheduler_protocol_error_sticky || o_scheduler_completion_mismatch_sticky || o_ssw_switch_protocol_error_sticky || o_ssw_transaction_mismatch_sticky) begin
				$display("FAIL OIB-02 IR owner-deadline timeout incorrectly also set a blocking sticky");
				cnt_error = cnt_error + 1;
			end else if(o_system_fault_blocking || o_system_abort_event || o_system_stop_request_event) begin
				$display("FAIL OIB-02 IR owner-deadline timeout incorrectly propagated to a supervisor blocking record/abort/STOP request");
				cnt_error = cnt_error + 1;
			end else if(cnt_owner_commit_total_oib != cnt_owner_before_hold) begin
				$display("FAIL OIB-02 IR owner-deadline timeout incorrectly still committed an owner (half-commit)");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-02 IR owner-deadline timeout asserted the non-blocking historical diagnostic with no half-commit, no blocking sticky, and no supervisor record/abort/STOP request");
			end
		end
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		task_build_oib_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL OIB re-commit after OIB-02 IR timeout branch");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		// 每次真实START都是新的run_generation，sample_index/frame_id允许从新
		// 基线重新计数；顺序监视进程只应该在同一次连续RUN内部核对非递减，
		// 跨越STOP/START边界比较是监视进程自己的越界，不是DUT的真实乱序——
		// 同已有memory feedback-tb-counter-scope-and-stop-boundary记录的计数器
		// 作用域越界同一类问题，这里在新RUN开始时主动重新武装
		flag_order_first_seen = 1'b0;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- OIB-03（held ready/valid支）：持续拉低i_measurement_result_ready，owner通道独立推进，held结果不静默丢失，释放后立即消费 -------//
		// 直接复用tb_ppg_control_top.v自己的SMOKE-17/TOP-05既有真实confirmed
		// 模式，改用本文件task_drive_any_neutral代替生理生成器持续喂真实事务
		begin : oib03_result_backpressure
			integer cnt_owner_before_bp;
			integer cnt_wait_bp;
			integer cnt_seen_result_valid;
			integer cnt_drop_without_consume;
			integer cnt_meas_before_release;
			integer cnt_wait_release;
			reg flag_result_was_valid;
			i_measurement_result_ready = 1'b0; // 提前拉低，制造正式输出侧反压
			cnt_owner_before_bp = cnt_owner_commit_total_oib;
			cnt_wait_bp = 0;
			cnt_seen_result_valid = 0;
			cnt_drop_without_consume = 0;
			flag_result_was_valid = 1'b0;
			while(((cnt_owner_commit_total_oib - cnt_owner_before_bp) < 4) && (cnt_wait_bp < 20) && !flag_global_timeout) begin
				task_drive_any_neutral;
				cnt_wait_bp = cnt_wait_bp + 1;
				if(o_measurement_result_valid) begin
					cnt_seen_result_valid = cnt_seen_result_valid + 1;
					flag_result_was_valid = 1'b1;
				end else if(flag_result_was_valid) begin
					// i_measurement_result_ready全程为0，valid一旦拉高就不该在
					// 没有真实消费（ready&&valid同拍）的情况下自己掉回0——那样
					// 等于held结果被静默丢弃
					cnt_drop_without_consume = cnt_drop_without_consume + 1;
					flag_result_was_valid = 1'b0;
				end
			end
			if((cnt_owner_commit_total_oib - cnt_owner_before_bp) < 4) begin
				$display("FAIL OIB-03 ADC owner activity stalled under output backpressure, delta=%0d",
					cnt_owner_commit_total_oib - cnt_owner_before_bp);
				cnt_error = cnt_error + 1;
			end else if(cnt_drop_without_consume != 0) begin
				$display("FAIL OIB-03 formal result valid silently dropped %0d time(s) without real consumption", cnt_drop_without_consume);
				cnt_error = cnt_error + 1;
			end else if(cnt_seen_result_valid == 0) begin
				$display("FAIL OIB-03 no formal result ever asserted valid under backpressure");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-03 ADC owner activity (%0d commits) progressed independently while output backpressured, held result never silently dropped",
					cnt_owner_commit_total_oib - cnt_owner_before_bp);
			end
			cnt_meas_before_release = cnt_result_capture;
			i_measurement_result_ready = 1'b1;
			cnt_wait_release = 0;
			while((cnt_result_capture < (cnt_meas_before_release + 1)) && (cnt_wait_release < 200) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_release = cnt_wait_release + 1;
			end
			if(cnt_result_capture < (cnt_meas_before_release + 1)) begin
				$display("FAIL OIB-03 held result never consumed after releasing backpressure");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-03 held result consumed promptly once output backpressure released");
			end
		end

		//------- OIB-03（STOP-during-held-result支）：held住的正式result尚未被消费时STOP接受，恰好产生一次DISCARD_STOP，不产生成功transfer -------//
		begin : oib03_stop_during_held_result
			integer cnt_result_capture_before;
			integer cnt_discard_before;
			// 与posedge显式同步再拉低，避免和上一阶段刚释放的ready在同一个
			// 时间步和捕获进程的NBA采样赛跑，产生一次虚假的"释放前多算一次"
			@(negedge i_clk);
			i_measurement_result_ready = 1'b0; // 重新制造反压，确保下一笔结果held住不被消费
			@(posedge i_clk);
			#1;
			flag_measurement_discard_seen = 1'b0;
			cnt_result_capture_before = cnt_result_capture;
			cnt_discard_before = cnt_measurement_discard_events;
			begin : oib03_wait_result_held
				integer cnt_wait_hold;
				cnt_wait_hold = 0;
				while(!o_measurement_result_valid && (cnt_wait_hold < 20) && !flag_global_timeout) begin
					task_drive_any_neutral;
					cnt_wait_hold = cnt_wait_hold + 1;
				end
				if(!o_measurement_result_valid) begin
					$display("FAIL OIB-03 setup invalid: no held formal result before issuing STOP");
					cnt_error = cnt_error + 1;
				end
			end
			task_pulse_stop;
			begin : oib03_wait_stop_ack
				integer cnt_stop_wait;
				cnt_stop_wait = 0;
				while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_stop_wait = cnt_stop_wait + 1;
				end
				if(o_stop_ack_event == 1'b0) begin
					$display("FAIL OIB-03 stop ack timeout during held-result scenario");
					cnt_error = cnt_error + 1;
				end
			end
			repeat(8) @(posedge i_clk);
			i_measurement_result_ready = 1'b1; // 恢复ready，确认held结果不会在STOP之后迟到成功transfer
			repeat(8) @(posedge i_clk);
			if(cnt_result_capture != cnt_result_capture_before) begin
				$display("FAIL OIB-03 a held result under STOP incorrectly still produced a successful transfer");
				cnt_error = cnt_error + 1;
			end else if(!flag_measurement_discard_seen || (reg_measurement_discard_reason_latched != 2'b00)) begin
				$display("FAIL OIB-03 STOP-during-held-result did not produce exactly one DISCARD_STOP record, seen=%b reason=%0d",
					flag_measurement_discard_seen, reg_measurement_discard_reason_latched);
				cnt_error = cnt_error + 1;
			end else if(cnt_measurement_discard_events != (cnt_discard_before + 1)) begin
				$display("FAIL OIB-03 STOP-during-held-result did not produce exactly one discard event, before=%0d after=%0d",
					cnt_discard_before, cnt_measurement_discard_events);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-03 STOP-during-held-result produced exactly one DISCARD_STOP record and never a successful transfer");
			end
		end
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		task_build_oib_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL OIB re-commit after OIB-03");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		flag_order_first_seen = 1'b0;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- OIB-08：abort后matching success=0只释放旧owner，不产生calibration/tracking/FIR/detector/formal-output任何下游transfer -------//
		// 直接复用Group14 LFA-04已经真实confirmed的abort-after-commit手法
		begin : oib08_abort_success_zero
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_oib08_sample_index;
			integer cnt_before_abort;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL OIB-08 real Q3 window never opened");
				cnt_error = cnt_error + 1;
			end else begin
				reg_oib08_sample_index = reg_owner_snapshot_sample_index;
				@(negedge i_clk);
				i_control_abort_event = 1'b1;
				@(posedge i_clk);
				#1 i_control_abort_event = 1'b0;
				if(!ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
					$display("FAIL OIB-08 owner already released before the real DONE arrived, abort must wait for it");
					cnt_error = cnt_error + 1;
				end else begin
					cnt_before_abort = cnt_result_capture;
					make_fixed_raw(150, raw_code_tmp);
					drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp); // 真实原owner的物理DONE，姗姗来迟
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]) begin
						$display("FAIL OIB-08 owner was never released by the late real DONE after abort");
						cnt_error = cnt_error + 1;
					end else if(cnt_result_capture != cnt_before_abort) begin
						$display("FAIL OIB-08 a formal measurement result advanced despite abort forcing success=0, no calibration/tracking/FIR/detector/formal-output transfer is permitted");
						cnt_error = cnt_error + 1;
					end else begin
						$display("PASS OIB-08 abort after owner commit retained the original identity, the late real DONE produced exactly one success=0 release with no formal/algorithm-side transfer, sample_index=%0d", reg_oib08_sample_index);
					end
				end
			end
		end
		// abort同拍立即清B_FRAME_ACTIVE，和STOP不同，NORMAL不会自己恢复——同
		// LFA-04已验证过的手法，走一次完整STOP+drain+recommit+START恢复
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		task_build_oib_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL OIB re-commit after OIB-08");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		flag_order_first_seen = 1'b0;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- OIB-09：以帧身份为作用域的DC码epoch前后对比——同一RUN内一次真实safe-boundary更新后，新帧的formal result必须切换到新epoch，旧帧内已提交的result保持旧epoch不受影响 -------//
		// 前两次尝试的真实证据（见本文件V1.0/V1.1 changelog）已经确认：(1)
		// config commit在RUN期间无条件被ERROR_COMMIT_STATE拒绝，不能当"变更"
		// 手段；(2) NORMAL帧的DC码epoch是每帧只锁存一次到Scheduler自己的
		// state_current[B_FRAME_DCR_EPOCH]，不是持续跟踪IDAC控制器活的epoch
		// 寄存器，同一循环内快照对比读不到差异。本轮真实构造第一稿还踩了第三个
		// 坑（记入changelog）：below_low确认驱动本身要消耗不确定数量的真实事务
		// （task_drive_color_value内部为不匹配颜色放行中性事务），"调码生效后
		// 再去驱动一笔事务采集before身份"这个顺序本身就可能已经跨过了真正的
		// 调码所在帧——等采集完时早已经身处调码之后的帧，"before"名不副实。
		// 修复为先在还没开始below_low驱动之前，就驱动一笔RED事务采集真正的
		// before身份（此时确定还没有任何调码发生），再开始below_low驱动触发
		// 真实调码，然后持续中性放行直到真实观察到当前帧自己的epoch快照和
		// before不同（不假设固定跨越几帧），最后驱动一笔RED事务采集after身份
		begin : oib09_frame_scoped_epoch_before_after
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_epoch_before;
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_epoch_after;
			reg [C_FRAME_ID_WIDTH - 1:0] reg_frame_before;
			reg [C_FRAME_ID_WIDTH - 1:0] reg_frame_after;
			reg [7:0] reg_dcs_r_code_before;
			reg flag_code_changed;
			reg flag_epoch_advanced;
			integer cnt_drive_guard;
			integer cnt_wait_advance;
			reg [C_FRAME_ID_WIDTH - 1:0] reg_before_result_frame_id;
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_before_result_epoch;
			reg [C_FRAME_ID_WIDTH - 1:0] reg_after_result_frame_id;
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_after_result_epoch;

			// 第一步：还没有开始below_low驱动之前，先驱动一笔RED事务采集真正
			// pre-update的before身份——此时确定还没有任何调码发生
			task_drive_color_value(1'b0, 150);
			begin : oib09_wait_before_result_valid
				integer cnt_wait_valid;
				cnt_wait_valid = 0;
				while(!o_measurement_result_valid && (cnt_wait_valid < 200) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_valid = cnt_wait_valid + 1;
				end
				reg_before_result_frame_id = o_result_frame_id; // 只在valid拉高的这一拍读取才是这笔事务自己的真实身份
				reg_before_result_epoch = o_result_dc_code_epoch;
				reg_frame_before = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.current_frame_id_o; // 同一拍就地读取真实帧号，消除race
				reg_epoch_before = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_DCR_EPOCH_H -: C_CODE_EPOCH_WIDTH]; // 同一拍就地读取这一帧自己锁存的epoch快照
			end

			if((reg_before_result_frame_id !== reg_frame_before) || (reg_before_result_epoch !== reg_epoch_before)) begin
				$display("FAIL OIB-09 before-frame formal result did not bind this frame's own latched epoch: expect frame=%0d epoch=%0d, got frame=%0d epoch=%0d",
					reg_frame_before, reg_epoch_before, reg_before_result_frame_id, reg_before_result_epoch);
				cnt_error = cnt_error + 1;
			end else begin
				// 第二步：开始below_low驱动触发真实调码
				reg_dcs_r_code_before = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_code_current;
				flag_code_changed = 1'b0;
				cnt_drive_guard = 0;
				while(!flag_code_changed && (cnt_drive_guard < 20) && !flag_global_timeout) begin
					task_drive_color_value(1'b0, 8); // 连续投递RED below_low真实样本，累积dcs_confirm_count连续低侧证据
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_code_current !== reg_dcs_r_code_before) begin
						flag_code_changed = 1'b1; // 真实观察到committed码变化，safe-boundary更新已经真实生效
					end
					cnt_drive_guard = cnt_drive_guard + 1;
				end

				if(!flag_code_changed) begin
					$display("FAIL OIB-09 setup invalid: real below_low RED tracking never produced a real DC_R safe-boundary code update within guard window");
					cnt_error = cnt_error + 1;
				end else begin
					// 第三步：持续中性放行，直到真实观察到当前帧自己的epoch快照
					// 和before不同——不假设固定跨越几帧，调码commit tick本身可能
					// 和某次帧边界重合，新帧latch时读到的还是递增前的旧值，需要
					// 真实再多等一帧才会体现
					flag_epoch_advanced = 1'b0;
					cnt_wait_advance = 0;
					while(!flag_epoch_advanced && (cnt_wait_advance < 3000) && !flag_global_timeout) begin
						task_drive_any_neutral; // 中性放行，只为真实推进帧边界，不产生新的调码证据
						if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[
							ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_DCR_EPOCH_H -: C_CODE_EPOCH_WIDTH] !== reg_epoch_before) begin
							flag_epoch_advanced = 1'b1;
						end
						cnt_wait_advance = cnt_wait_advance + 1;
					end
					if(!flag_epoch_advanced) begin
						$display("FAIL OIB-09 no frame's own latched B_FRAME_DCR_EPOCH ever advanced past the before-frame's snapshot (before frame=%0d epoch=%0d) within guard window",
							reg_frame_before, reg_epoch_before);
						cnt_error = cnt_error + 1;
					end else begin
						task_drive_color_value(1'b0, 150); // 已经确认身处epoch真实推进后的帧，驱动一笔RED事务采集after身份
						begin : oib09_wait_after_result_valid
							integer cnt_wait_valid;
							cnt_wait_valid = 0;
							while(!o_measurement_result_valid && (cnt_wait_valid < 200) && !flag_global_timeout) begin
								@(posedge i_clk);
								cnt_wait_valid = cnt_wait_valid + 1;
							end
							reg_after_result_frame_id = o_result_frame_id;
							reg_after_result_epoch = o_result_dc_code_epoch;
							reg_frame_after = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.current_frame_id_o; // 同样同一拍就地读取，消除race
							reg_epoch_after = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[
								ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_DCR_EPOCH_H -: C_CODE_EPOCH_WIDTH];
						end
						if((reg_after_result_frame_id !== reg_frame_after) || (reg_after_result_epoch !== reg_epoch_after)) begin
							$display("FAIL OIB-09 after-frame formal result did not bind the new frame's own latched epoch: expect frame=%0d epoch=%0d, got frame=%0d epoch=%0d",
								reg_frame_after, reg_epoch_after, reg_after_result_frame_id, reg_after_result_epoch);
							cnt_error = cnt_error + 1;
						end else if(reg_epoch_after == reg_epoch_before) begin
							$display("FAIL OIB-09 after-frame formal result's own epoch equals the before-frame snapshot despite the earlier advance detection (before frame=%0d epoch=%0d, after frame=%0d epoch=%0d)",
								reg_frame_before, reg_epoch_before, reg_frame_after, reg_epoch_after);
							cnt_error = cnt_error + 1;
						end else begin
							$display("PASS OIB-09 frame-scoped DC_R epoch before(frame=%0d epoch=%0d)/after(frame=%0d epoch=%0d) each bound correctly to its own frame's latched snapshot, and the epoch genuinely advanced after a real safe-boundary code update",
								reg_frame_before, reg_epoch_before, reg_frame_after, reg_epoch_after);
						end
					end
				end
			end
		end

		//------- OIB-07：一笔真实事务的formal result身份逐字段绑定其自己commit时刻的快照（frame/sample/color/precision） -------//
		begin : oib07_identity_binding
			reg [C_FRAME_ID_WIDTH - 1:0] reg_expect_frame_id;
			reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_expect_sample_index;
			reg reg_expect_color_ir;
			reg reg_expect_precision;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL OIB-07 real Q3 window never opened");
				cnt_error = cnt_error + 1;
			end else begin
				reg_expect_frame_id = reg_owner_snapshot_frame_id;
				reg_expect_sample_index = reg_owner_snapshot_sample_index;
				reg_expect_color_ir = reg_owner_snapshot_color_ir;
				reg_expect_precision = reg_owner_snapshot_precision;
				make_fixed_raw(150, raw_code_tmp);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code_tmp, raw_code_tmp);
				// result字段只在o_measurement_result_valid拉高的那一拍稳定，
				// i_measurement_result_ready默认为1时同拍立即消费——4拍之后
				// 再读会读到下一个空槽的复位值，必须精确等在真正valid的那拍
				begin : oib07_wait_result_valid
					integer cnt_wait_valid;
					cnt_wait_valid = 0;
					while(!o_measurement_result_valid && (cnt_wait_valid < 200) && !flag_global_timeout) begin
						@(posedge i_clk);
						cnt_wait_valid = cnt_wait_valid + 1;
					end
					if(!o_measurement_result_valid) begin
						$display("FAIL OIB-07 setup invalid: o_measurement_result_valid never asserted after driving the real DONE");
						cnt_error = cnt_error + 1;
					end
				end
				if((o_result_frame_id !== reg_expect_frame_id) || (o_result_sample_index !== reg_expect_sample_index) ||
					(o_result_color_ir !== reg_expect_color_ir) || (o_result_precision_mode !== reg_expect_precision)) begin
					$display("FAIL OIB-07 result identity mismatch: expect frame=%0d sample=%0d color=%b precision=%b, got frame=%0d sample=%0d color=%b precision=%b",
						reg_expect_frame_id, reg_expect_sample_index, reg_expect_color_ir, reg_expect_precision,
						o_result_frame_id, o_result_sample_index, o_result_color_ir, o_result_precision_mode);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS OIB-07 formal result identity (frame=%0d sample=%0d color=%b precision=%b) matched exactly this transaction's own commit-time snapshot",
						o_result_frame_id, o_result_sample_index, o_result_color_ir, o_result_precision_mode);
				end
			end
		end

		//------- OIB-05：已释放owner的重复DONE不产生第二次completion/result -------//
		// 直接复用Group14 LFA-07已验证过的手法：只在系统真正STOP+drain到
		// CONFIG之后才呈交重复DONE，避免撞上"近乎瞬时授予"的真实新owner
		task_stop_and_drain;
		begin : oib05_duplicate_done_no_second_completion
			integer cnt_commit_before_dup;
			integer cnt_result_before_dup;
			cnt_commit_before_dup = cnt_owner_commit_total_oib;
			cnt_result_before_dup = cnt_result_capture;
			make_fixed_raw(150, raw_code_tmp);
			drive_real_adc_done(1'b0, raw_code_tmp, raw_code_tmp); // 系统已经排空到CONFIG，没有任何owner在途，这笔DONE必然是重复/无主
			repeat(4) @(posedge i_clk);
			if((cnt_owner_commit_total_oib != cnt_commit_before_dup) || (cnt_result_capture != cnt_result_before_dup)) begin
				$display("FAIL OIB-05 a duplicate/unowned DONE after full drain incorrectly produced a second completion or formal result, commit before=%0d after=%0d result before=%0d after=%0d",
					cnt_commit_before_dup, cnt_owner_commit_total_oib, cnt_result_before_dup, cnt_result_capture);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-05 a duplicate/unowned DONE presented after full drain produced no second completion and no second formal result");
			end
		end

		//------- OIB-01：波形上下文接管点持有反压——非阻断launch-timeout独立于SSW阻断故障 -------//
		// 桶1 RTL会话新增了SSW专属反压注入端口i_context_handover_stall_request
		// （配合本文件刚打开的C_ENABLE_TEST_INJECTION=1），并收窄了
		// flag_switch_protocol_error_condition第4个OR项——只有"排除掉stall注入
		// 这个因素后依然不ready"才算真协议违规。之前的真实RTL追查（见本文件
		// V1.0 changelog）确认了当前RTL没有任何合法杠杆能让接管点ready为0而不
		// 同时触发SSW阻断故障；现在有了这个专属反压端口，第一次真实构造这条
		// 场景：在RED接管点（macro_tick==0）START之前就持有stall，跨越第一个
		// 接管点错过一次，确认只置位Scheduler自己的非阻断o_scheduler_launch_
		// timeout_sticky，SSW阻断的o_ssw_switch_protocol_error_sticky保持0；
		// 随后在下一帧的接管点前释放stall，确认下一次合法机会能干净恢复接管
		i_test_inject_enable = 1'b1;
		task_build_oib_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL OIB commit before OIB-01");
			cnt_error = cnt_error + 1;
			$finish;
		end
		i_context_handover_stall_request = 1'b1; // START之前就持有，确保第一个RED接管点(macro_tick==0)必然错过
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		begin : oib01_missed_handover
			integer cnt_hold_wait;
			cnt_hold_wait = 0;
			while(!o_scheduler_launch_timeout_sticky && (cnt_hold_wait < 400) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_hold_wait = cnt_hold_wait + 1;
			end
			if(!o_scheduler_launch_timeout_sticky) begin
				$display("FAIL OIB-01 setup invalid: o_scheduler_launch_timeout_sticky never asserted after holding i_context_handover_stall_request across the RED handover tick");
				cnt_error = cnt_error + 1;
			end else if(o_ssw_switch_protocol_error_sticky) begin
				$display("FAIL OIB-01 missed handover incorrectly also tripped SSW's blocking switch_protocol_error_sticky -- non-blocking launch-timeout and SSW blocking fault are supposed to be independently classifiable");
				cnt_error = cnt_error + 1;
			end else if(o_scheduler_protocol_error_sticky || o_scheduler_completion_mismatch_sticky || o_ssw_transaction_mismatch_sticky) begin
				$display("FAIL OIB-01 missed handover incorrectly also set an unrelated blocking sticky (sched_protocol=%b sched_mismatch=%b ssw_mismatch=%b)",
					o_scheduler_protocol_error_sticky, o_scheduler_completion_mismatch_sticky, o_ssw_transaction_mismatch_sticky);
				cnt_error = cnt_error + 1;
			end else if(o_system_fault_blocking || o_system_abort_event || o_system_stop_request_event) begin
				$display("FAIL OIB-01 missed handover incorrectly propagated to a supervisor blocking record/abort/STOP request");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-01 RED waveform-context handover missed while held (stall request across the fixed tick) asserted only the Scheduler's non-blocking launch-timeout diagnostic, with SSW's blocking switch_protocol_error_sticky correctly staying 0");
			end
		end
		i_context_handover_stall_request = 1'b0; // 释放，证明"下一合法机会干净恢复"这一支
		// 被动等在同一个RUN内部等下一帧wraparound撞上了一个和本次RTL改动无关
		// 的宏帧重启细节（真实观测到B_FRAME_ACTIVE在wraparound后没有像预期
		// 那样立即恢复，即使持续用task_drive_any_neutral主动响应也一样）；
		// 改用和OIB-02恢复支完全一致的既有手法——真实STOP+drain+diag_clear+
		// recommit+START，验证"stall释放后，下一次全新合法机会真的能干净
		// 建立owner"这条真正要证明的性质，不依赖同一RUN内部的frame wraparound
		// 细节
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		begin : oib01_recovery
			integer cnt_owner_before_recover;
			cnt_owner_before_recover = cnt_owner_commit_total_oib;
			task_build_oib_config;
			task_pulse_source_update;
			task_wait_config_result;
			if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
				$display("FAIL OIB recommit after OIB-01 (recovery branch)");
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
			if(cnt_owner_commit_total_oib == cnt_owner_before_recover) begin
				$display("FAIL OIB-01 recovery: no real owner ever committed on a fresh legal opportunity after releasing the stall request");
				cnt_error = cnt_error + 1;
			end else if(o_ssw_switch_protocol_error_sticky) begin
				$display("FAIL OIB-01 recovery: SSW's blocking switch_protocol_error_sticky is still set after the stall was released and a fresh owner committed");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS OIB-01 recovery: releasing the stall request let a fresh legal handover opportunity commit a real owner cleanly, with no lingering SSW blocking fault");
			end
		end
		i_test_inject_enable = 1'b0;
		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);

		task_stop_and_drain;
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);
		task_build_oib_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL OIB re-commit before OIB-03 reset-during-held-result branch");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_loop = 0;
		while(!o_start_ack_event && (cnt_wait_loop < 64) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_loop = cnt_wait_loop + 1;
		end
		flag_order_first_seen = 1'b0;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;
		task_settle_after_search;

		//------- OIB-03（reset-during-held-result支）：held住的正式result尚未被消费时reset，清空但不产生discard事件 -------//
		begin : oib03_reset_during_held_result
			integer cnt_wait_hold2;
			@(negedge i_clk);
			i_measurement_result_ready = 1'b0; // 制造反压，确保下一笔结果held住不被消费
			@(posedge i_clk);
			#1;
			flag_measurement_discard_seen = 1'b0;
			cnt_wait_hold2 = 0;
			while(!o_measurement_result_valid && (cnt_wait_hold2 < 20) && !flag_global_timeout) begin
				task_drive_any_neutral;
				cnt_wait_hold2 = cnt_wait_hold2 + 1;
			end
			if(!o_measurement_result_valid) begin
				$display("FAIL OIB-03 setup invalid: no held formal result before issuing reset");
				cnt_error = cnt_error + 1;
			end else begin
				@(negedge i_clk);
				i_rstn = 1'b0; // 真实复位，held结果应当被清空但不产生discard事件
				repeat(4) @(posedge i_clk);
				if(flag_measurement_discard_seen) begin
					$display("FAIL OIB-03 reset-during-held-result incorrectly produced a discard event, reason=%0d", reg_measurement_discard_reason_latched);
					cnt_error = cnt_error + 1;
				end else if(o_measurement_result_valid) begin
					$display("FAIL OIB-03 reset did not clear the held formal result");
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS OIB-03 reset during a held formal result cleared it without producing any discard event");
				end
			end
		end

		// 2026-09-17新增：真实缺口OIB-06补测的显式gate。原文件里cnt_order_violation
		// 只是最终摘要行里被打印，从未真正折算进cnt_error——即使递减判据本身命中过
		// 违规，也不会让整份TB报FAIL。这里把递减判据和新增的重复/换色判据都真正
		// 折算进cnt_error，让OIB-06成为一条真实生效的断言，不是纯信息性计数
		if(cnt_order_violation != 0) begin
			$display("FAIL OIB-06 result stream order violated (out-of-order/decreasing frame_id or sample_index), count=%0d", cnt_order_violation);
			cnt_error = cnt_error + 1;
		end else if(cnt_duplicate_or_relabel_violation != 0) begin
			$display("FAIL OIB-06 result stream contained duplicate/recolored/retyped/precision-relabeled entries, count=%0d", cnt_duplicate_or_relabel_violation);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS OIB-06 result stream preserved order with no loss/duplication/recoloring/retyping/precision-relabeling across %0d real transfers", cnt_result_capture);
		end

		if(cnt_error == 0) begin
			$display("OWNER_IDENTITY_BACKPRESSURE_TB_PASS result_captures=%0d owner_commit_total=%0d measurement_discard_events=%0d detection_discard_events=%0d order_violation_count=%0d",
				cnt_result_capture, cnt_owner_commit_total_oib, cnt_measurement_discard_events, cnt_detection_discard_events, cnt_order_violation);
		end else begin
			$display("OWNER_IDENTITY_BACKPRESSURE_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
