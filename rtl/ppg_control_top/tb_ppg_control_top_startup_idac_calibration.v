`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/27
// Design Name:        PPG Startup IDAC Calibration Search Testbench
// Module Name:        tb_ppg_control_top_startup_idac_calibration
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_idac_code_controller.v
//                      ppg_400hz_frame_calibration_scheduler.v
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.2
// Revision Date:      2026/09/18
// History:
//    Time               Version       Revised by            Contents
// 2026/09/18            V1.2          Erie                  Workline-D pending-item investigation, SID-05 (DC_R/DC_IR half) and SID-06: (1) Extracted the AMB-stage-only tick-248 deadline-suppression logic into a reusable task_verify_deadline_suppression and applied it for real to the DC_R and DC_IR stages' first candidate, which 2026-09-17 had found got permanently stuck (Q3 window never opens again after the deadline fires) when the same logic was copy-pasted in -- confirmed via a real iverilog A/B trace (not just re-reading code) that this is a genuine AMI (ppg_adc_measurement_idac_integration.v) RTL deadlock, not a TB construction mistake: flag_calibration_request_inflight only ever clears on a real consumed search result or STOP/abort, never on the scheduler's own graceful deadline-suppression, so a deadline-suppressed request strands AMI forever with no retry. Fixed at the RTL level (ppg_400hz_frame_calibration_scheduler.v V1.8 new o_cal_owner_deadline_event, AMI V1.15 consumes it as an additional inflight-clear condition, ppg_control_top.v V1.6 wires them together) -- see those files' own changelogs for the real root cause and fix. With the RTL fix in place, the same task_verify_deadline_suppression + wait_q3_release construction that already worked for AMB now genuinely works for DC_R/DC_IR too, confirmed by a clean real iverilog run (STARTUP_IDAC_CALIBRATION_TB_PASS, zero FAIL). (2) Built the first real test for SID-06 (previously only a PASS message piggybacked on SID-04's "AMB converged to target code" check, which tests a completely different property): directly reads the SSW's internal reg_cal_dc_code register (the actual per-subframe waveform-snapshot latch that only updates on its own tick-0 context handoff, ppg_sar9_sar15_safe_selection_wrapper.v) across a real DC_R candidate's tick-385 commit boundary, confirming the snapshot stays unperturbed through the rest of that same subframe and is only picked up by the very next subframe's real Q3 sample -- both PASS with real, non-vacuous code changes (old=0x42, newly committed=0x5d) confirmed by a real run. First construction attempt captured the "before" baseline too early (reading reg_cal_dc_code directly before that subframe's own Q3 sample), which is provably stale (SSW had not yet caught up to the PREVIOUS commit at that point) and produced a false FAIL; fixed by sourcing the baseline from the real Q3-sampled reg_sampled_dcn instead, which is guaranteed fresh for the current subframe. Per this project's standing methodology, this false FAIL was itself only caught by really running the test and tracing tick/register values, not by re-reading the diff. See WORKLINE_D_SID05_SID06_20260918.md for the full investigation.
// 2026/08/30            V1.1          Erie                  Bucket-1 RTL session: `ppg_idac_code_controller.v` gained a dedicated `i_test_saturation_inject_valid`/`o_test_saturation_inject_ready` injection port (does not touch the shared `i_search_saturation_low`/`i_search_saturation_high` nets), letting SID-11's double-saturation half be constructed for real for the first time. Added Phase B2: a fresh COMMIT/START cleanly separated from Phase B's SID-10 hard fault, real AMB request wait, `wait_q3_release`, then hold `i_test_saturation_inject_valid=1` across a real `task_drive_amb_toward_target` call. First real run found one genuine timing bug in this new test code (not DUT RTL): checking the injection-fire sticky immediately after the drive task returned raced ahead of AMI's real capture/S1/calibration/router pipeline latency between the raw CLK_DOUT and the sample actually reaching `idac_code_controller`'s own `i_search_amb_valid` -- the injection was in fact firing correctly on schedule, but the check read it before it happened. Fixed with a bounded poll loop (up to 200 cycles) on the continuous-monitor sticky, matching this project's established "single-cycle pulse after a multi-cycle task call needs a continuous sticky monitor, not an immediate post-task read" lesson. Real iverilog + Vivado 2022.2 xsim both confirm SID-11 PASS with the committed AMB code unchanged, no fabricated success, and no escalation to a hard system fault -- `JNT_BASELINE 53/53 PASS`, `STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2`, byte-identical to the pre-existing V1.0 baseline on every other ID.
// 2026/08/27            V1.0          Erie                  Create file. Stage 5 Group 6 (STARTUP-IDAC-CALIBRATION, C25 contract section 9.4.1, SID-01~12). All twelve IDs are covered in this file -- unlike Group 10/12's deferred AMB_CAL/DCS_CAL clauses, this group IS the startup binary-search algorithm itself, so there is no MANUAL-mode structural block here. Read `ppg_idac_code_controller.v` in full for the search algorithm: it is a genuine floor-midpoint binary search evaluated ONE real physical SAR9 sample per candidate (`flag_amb_transfer`/`flag_dcs_transfer` single valid/ready pulses in `ST_AMB_WAIT`/`ST_DCS_R_WAIT`/`ST_DCS_IR_WAIT`, lines 894-976) -- there is no internal 8-sample accumulator in this module. Re-read against SID-04/SID-10's "eight physical SAR9 subframes"/"exactly eight matching successful results per candidate evaluation" wording, the only self-consistent reading is that "eight subframes"/"eight results" describes the full binary-search episode for one stage (AMB, or DC_R, or DC_IR) taking up to eight real candidate steps to converge across an 8-bit code range (`ceil(log2(232))=8` for `amb_code_min=8`/`amb_code_max=240`) -- not eight samples averaged into one decision. This file drives each candidate through the real physical Q3/CLK_DOUT/AMI pipeline (`wait_q3_release`/`drive_real_adc_done`/`make_fixed_raw`, copied verbatim from Group 11/12's own validated infrastructure) using a real committed RAW code chosen so the resulting calibrated Stage1 value lands clearly above/below/within the real threshold window, exactly mirroring `ppg_idac_code_controller/tb_ppg_idac_code_controller.v`'s own `send_requested_search_sample` task's above/below/in-window driving logic but through the real hardware path instead of a direct internal signal force. Base config task is copied from Group 12's `task_build_normal_manual_config` (the power-of-2 Q16 weight set: 65536/131072/262144/524288/524288/1048576/2097152/4194304/8388608/16777216, `stage1_offset_q16=-262144`) rather than the smoke-test file's or this session's own Group 10 file's "-17,18,-19,20..." weight pattern, because Group 11's own memory established that `make_fixed_raw(target_code)`'s vdred redundant encoding only decodes back to exactly `target_code` as the calibrated Stage1 residual under THIS specific nominal weight set -- Group 10 never needed that numeric identity (it only checked protocol-level facts), but this group's entire binary-search-direction logic depends on it, so it must use the same weight set Group 11 validated the identity against, not the unrelated smoke-test pattern.
//                                                             One RTL fact was confirmed before writing any stimulus: literal "double-saturation" (SID-11's first listed trigger, `i_search_saturation_low && i_search_saturation_high` both true) is mathematically UNREACHABLE through any legitimate single RAW value -- `ppg_adc_s1_programmable_calibrator.v` computes `flag_saturation_low = dec_rounded_value < -2048` and `flag_saturation_high = dec_rounded_value > 2047` as two mutually-exclusive comparisons on the SAME signed value (lines 232-233), so no real stimulus can ever set both.
//                                                             Getting a real clean run required finding and fixing four real problems, none in DUT RTL, three of them genuine methodology mistakes in this file's first draft and one a real config-manager parameter miss: (1) the DUT instantiation never overrode `C_ENABLE_TEST_INJECTION` (default 0 in production, `ppg_control_top.v` line 82/1071), so `flag_test_inject_effective` was permanently 0 and the identity-injection port group used below for SID-10 could never fire at all -- fixed by instantiating with `C_ENABLE_TEST_INJECTION(32'd1)`, the same override `tb_ppg_control_top_injection.v` already documents as mandatory for that port group. (2) the first draft tried to construct SID-10's "wrong type" case by `force`-ing `ppg_idac_code_controller_Inst.i_search_frame_type` for one real candidate's completion, expecting the controller's own `flag_amb_sample_qualified` gate to produce a quiet, non-advancing reject. Instead it produced a real `o_ami_integration_protocol_error_sticky` and `o_system_fault_blocking` -- tracing it back: `i_search_frame_type` and `i_search_calibration_applied` are both driven from AMI-internal wires (`dec_router_frame_type`/`flag_router_calibration_applied`) that fan out to several real consumers inside `ppg_adc_measurement_idac_integration.v` (lines 1868/1904/1978/2332 and 1881/1917/1991/2341), not private single-consumer signals -- `force` on a hierarchical port reference forces the shared net itself in iverilog, corrupting every other real consumer on that net, not just the one idac_code_controller input this test meant to isolate. That is a real methodology finding, not a soft-reject counterexample: forcing a shared net to fake "this one consumer sees a mismatch" does not hold on this RTL. (3) reusing `tb_ppg_control_top_injection.v`'s own INJ-02 (LFA-08) mechanism instead -- `i_test_identity_inject_sample_index`, a genuinely independent bypass channel that occupies no production net -- correctly reproduced a real mismatched-identity completion for a calibration (AMB_CAL) transaction for the first time; it retains the owner, sets `o_ami_integration_protocol_error_sticky`, and propagates to `o_system_fault_blocking`, exactly matching INJ-02's own established NORMAL-path behavior. This settles what SID-10's "wrong type, color, sample index, code snapshot, or epoch...consumed only by its contractual reject path" actually means at the RTL level: it is the same hard, system-wide reject path already proven for NORMAL transactions, not two different severities as the first draft's (incorrect) reading of the controller's own narrower qualification gate had assumed. (4) SID-10's hard-fault path leaves `error_sticky` set (a real W1C sticky, same pattern `tb_ppg_control_top.v`'s SMOKE-20-to-21 transition already established), which is not cleared by STOP-drain-to-CONFIG alone -- the first draft's next COMMIT (Phase C) failed until an explicit `i_diag_clear_event` pulse was added between Phase B and Phase C.
//                                                             A fifth investigation, not a bug fix, determined SID-11's "otherwise ineligible" clause is genuinely UNREACHABLE within this group's scope and is deferred rather than force-hacked into a misleading PASS: `i_stage1_calibration_valid=0` (the only legitimate "otherwise ineligible" trigger identified in the controller's own `flag_amb_sample_qualified`/`flag_dcs_sample_qualified` gate, `i_search_calibration_applied` term, lines 456/463) requires `run_profile=CHARACTERIZATION` to even COMMIT at all (`flag_snapshot_coef_qualification_valid`, `ppg_system_config_manager.v` lines 413-414, since NORMAL_PPG mandates `stage1_calibration_valid=1`) -- but `run_profile=CHARACTERIZATION` independently forces `idac_mode=MANUAL` (`flag_snapshot_char_idac_valid`, same file lines 364-365), which structurally forbids `idac_mode=SEARCH_TRACK` from ever starting a search in the first place. The two COMMIT-time legality gates intersect to an empty set: SEARCH_TRACK and `stage1_calibration_valid=0` can never coexist in any legal configuration. And per finding (2) above, `i_search_calibration_applied` is one of the same shared, multi-consumer AMI nets that `force` cannot safely target for a single-consumer mismatch either. With both the double-saturation trigger and the calibration-invalid trigger closed off, and no dedicated calibration-identity injection channel existing in the current RTL, SID-11 has no safe legitimate construction path in Group 6 today -- it is recorded here as a genuine structural-unreachability finding (distinct in kind from ILM-11/12's "needs Group 6/8 first" deferrals) and left for a future revision if the RTL ever grows a dedicated calibration-sample-eligibility injection port.
//                                                             Four phases, each independently committed after a fresh drain to CONFIG (Group 6's own scenarios cannot share RUN state -- SEARCH_TRACK's startup search only ever runs once per RUN, from the very first START): Phase A (SID-01) commits a fresh SEARCH_TRACK config and confirms START creates exactly one `o_startup_idac_safe_boundary` pulse with zero waveform/owner/macro-frame/result/sample-index advance before the first real AMB request even begins. Phase B (SID-10) uses the real identity-injection mechanism described above on the very first AMB candidate, confirming both halves: the search does not advance on the mismatched completion, and the hard fault genuinely propagates to `o_system_fault_blocking`; an explicit `i_diag_clear_event` then clears the resulting `error_sticky` before Phase C. Phase C (SID-02/03/04/05/06/07/08/09/12-positive) is the real convergence walk: drives real AMB candidates toward `target_amb_code=64` (within `[8,240]`), then real DC_R candidates toward `target_dcs_r_code=80` (within `[12,230]`, RED-only LED window, confirmed AMB code held on the AMB bus), then real DC_IR candidates toward `target_dcs_ir_code=96` (within `[16,220]`, IR-only LED window) -- checking strict stage ordering, the dedicated Q3=266 local tick, 625-tick candidate spacing, and the LED/DC-bus isolation windows at every real candidate step, with the SID-05 deadline-miss (holding `i_adc_physical_idle=0` across the tick-248 owner-commit deadline for one candidate window) folded in as a one-off perturbation on the second AMB candidate before letting the real search continue and converge, finally confirming `o_startup_search_complete` asserts before any real NORMAL owner ever commits and that NORMAL transactions genuinely begin afterward. Phase D (SID-12 exhaustion) commits SEARCH_TRACK with `amb_threshold_low=72`/`amb_threshold_high=-64` (deliberately inverted into an empty window so no candidate can ever land in-window regardless of the driven value) and confirms the AMB search runs to exhaustion, asserting `o_amb_fault`/`o_amb_search_exhausted`/`o_controller_fault_blocking`, leaving `o_startup_search_complete` low, and blocking NORMAL indefinitely.
//                                                             After all four fixes: real iverilog run, `JNT_BASELINE 53/53 PASS`, all eleven attempted IDs (SID-01~10, SID-12) pass with real simulation evidence, SID-11 deferred as documented above: `STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2`.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月27日
// 设计名称:           PPG启动IDAC校准搜索测试平台
// 模块名称:           tb_ppg_control_top_startup_idac_calibration
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_idac_code_controller.v
//                      ppg_400hz_frame_calibration_scheduler.v
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.2
// 修订日期:           2026年09月18日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年09月18日        V1.2          Erie                  工作线D待查清单调查：SID-05（DC_R/DC_IR半句）与SID-06。（1）把原本只在AMB阶段用过一次的tick-248截止抑制逻辑提取为可复用的`task_verify_deadline_suppression`，真实应用到DC_R/DC_IR阶段各自的第一个候选——2026-09-17曾发现原样复制这段逻辑会导致永久卡死（截止触发后Q3窗口再也不会打开）；这次真实iverilog A/B trace确认（不是只回头重读代码）这是AMI（`ppg_adc_measurement_idac_integration.v`）真实RTL死锁，不是TB构造失误：`flag_calibration_request_inflight`只在真实消费到搜索结果或STOP/abort时才清零，调度器自己优雅降级式的deadline抑制不会触发清零，被抑制的请求从此永久搁浅、再也不重试。已在RTL层面修复（`ppg_400hz_frame_calibration_scheduler.v`V1.8新增`o_cal_owner_deadline_event`，AMI V1.15把它接成额外的inflight清零条件，`ppg_control_top.v`V1.6把两端接起来）——真实根因和修法见这几份文件各自的修订记录。RTL修复落地后，AMB早已用过的同一套`task_verify_deadline_suppression`+`wait_q3_release`构造对DC_R/DC_IR同样真实生效，真实iverilog干净跑通确认（`STARTUP_IDAC_CALIBRATION_TB_PASS`，零FAIL）。（2）为SID-06构造第一份真实测试（此前只有一条挂靠SID-04"AMB收敛到目标码"检查的PASS消息，测的完全是另一件事）：直接层次化读取SSW自己的内部寄存器`reg_cal_dc_code`（真正的每子帧波形快照锁存，只在自己的tick 0上下文接管点更新，`ppg_sar9_sar15_safe_selection_wrapper.v`），跨过一次真实DC_R候选的tick-385提交边界，确认快照在本子帧剩余部分保持不受扰动，直到下一子帧真实Q3采样才真正看到新码——两半句都用真实发生的码变化（旧=0x42，新提交=0x5d）真实通过。第一版构造把"旧值"基线取早了（在本子帧自己的Q3采样之前就直接读`reg_cal_dc_code`），这个读法可证明是陈旧的（此时SSW还没赶上*上一次*提交），导致一次假FAIL；改成从真实Q3采样得到的`reg_sampled_dcn`取基线，保证对当前子帧而言一定是新鲜值。按本项目一贯方法论，这次假FAIL正是靠真的跑一遍测试、追踪tick和寄存器真实取值才抓到的，不是回头重读diff看出来的。完整调查过程见`WORKLINE_D_SID05_SID06_20260918.md`。
// 2026年08月30日        V1.1          Erie                  桶1 RTL会话：`ppg_idac_code_controller.v`新增专属`i_test_saturation_inject_valid`/`o_test_saturation_inject_ready`注入端口（不touch共享的`i_search_saturation_low`/`i_search_saturation_high`输入线），第一次真实构造出SID-11的双向饱和半句。新增阶段B2：独立于阶段B（SID-10硬故障）重新COMMIT/START，等真实AMB请求、`wait_q3_release`，然后在一次真实`task_drive_amb_toward_target`调用期间保持`i_test_saturation_inject_valid=1`。第一次真实跑通发现本文件新代码自己的一个真实时序bug（不在DUT RTL）：task返回后立刻检查注入fire的sticky，抢在了原始CLK_DOUT到真正抵达`idac_code_controller`自己`i_search_amb_valid`之间AMI捕获/S1/校准/router这段真实流水线延迟前面——注入其实按设计真的按时fire了，只是检查读早了。改成对同一个连续监视sticky做有界轮询（最多200拍）修复，和本项目已确立的"多拍task调用之后的单拍脉冲需要连续监视sticky，不能task返回后立刻读"这条教训一致。真实iverilog+Vivado 2022.2 xsim双工具都确认SID-11 PASS：committed AMB码不变、无虚假success、未连带触发硬系统故障——`JNT_BASELINE 53/53 PASS`，`STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2`，和V1.0既有基线在其它每一条ID上逐字节一致。
// 2026年08月27日        V1.0          Erie                  创建文件。Stage 5第6组（STARTUP-IDAC-CALIBRATION，C25合同9.4.1节，SID-01~12）。十二条本轮全部做完——和Group10/12被迫延后的AMB_CAL/DCS_CAL半句不同，这一组本身就是启动二分搜索算法，MANUAL模式的结构性阻挡在这里不存在。完整读过`ppg_idac_code_controller.v`的搜索算法：这是一个真正的floor中点二分搜索，每个候选码只评价一笔真实物理SAR9样本（`ST_AMB_WAIT`/`ST_DCS_R_WAIT`/`ST_DCS_IR_WAIT`里的`flag_amb_transfer`/`flag_dcs_transfer`单次valid/ready握手，892-976行）——这个模块内部完全没有8样本累加器。回头再看SID-04/SID-10"八个物理SAR9子帧"/"每个候选评价恰好八个匹配成功结果"的措辞，唯一自洽的理解是"八个子帧/八个结果"描述的是一个阶段（AMB，或DC_R，或DC_IR）完整二分搜索走完最多需要八个真实候选步骤才能收敛（8位码空间`ceil(log2(232))=8`，对应`amb_code_min=8`/`amb_code_max=240`）——不是八个样本平均成一个决策。本文件让每个候选码都走真实物理Q3/CLK_DOUT/AMI管线（`wait_q3_release`/`drive_real_adc_done`/`make_fixed_raw`，原样复用Group11/12已验证的基础设施），驱动一个真实RAW码使校准后的Stage1值精确落在阈值窗口的上方/下方/窗口内——和`ppg_idac_code_controller/tb_ppg_idac_code_controller.v`自己的`send_requested_search_sample`task的上/下/窗口内驱动逻辑完全同构，只是走真实硬件路径而不是直接强制内部信号。基础配置task照抄Group12的`task_build_normal_manual_config`（幂次Q16权重组：65536/131072/262144/524288/524288/1048576/2097152/4194304/8388608/16777216，`stage1_offset_q16=-262144`），而不是烟雾测试文件或本会话自己Group10文件用的"-17,18,-19,20..."权重模式——因为Group11自己的memory已经确立`make_fixed_raw(target_code)`的vdred冗余编码只有在这一组特定的nominal权重下才会原样解码回`target_code`本身作为校准后的Stage1残差值；Group10从来不需要这个数值恒等式（它只检查协议层面的事实），但本组整个二分搜索方向判定逻辑都依赖它，所以必须沿用Group11验证过恒等式的这一组权重，不能用不相关的烟雾测试模式。
//                                                             动笔前确认了一个真实RTL事实：字面意义的"双向饱和"（SID-11列出的第一个触发条件，`i_search_saturation_low && i_search_saturation_high`同时为真）在任何合法单一RAW值下都数学上不可达——`ppg_adc_s1_programmable_calibrator.v`把`flag_saturation_low = dec_rounded_value < -2048`和`flag_saturation_high = dec_rounded_value > 2047`算成对同一个signed值的两个互斥比较（232-233行），没有任何真实激励能让两者同时成立。
//                                                             拿到真实跑通的干净结果一共发现并修复了四个真实问题，全部不在DUT RTL里，其中三个是本文件第一版自己的方法论错误，一个是遗漏的配置管理器参数：（1）DUT例化从未覆盖`C_ENABLE_TEST_INJECTION`（生产默认0，`ppg_control_top.v`82/1071行），导致`flag_test_inject_effective`恒为0，下面SID-10要用的身份注入端口组根本不可能fire——修复为例化时显式`C_ENABLE_TEST_INJECTION(32'd1)`，和`tb_ppg_control_top_injection.v`自己记录过的这组端口的强制要求完全一致。（2）第一版尝试用对`ppg_idac_code_controller_Inst.i_search_frame_type`的`force`来构造SID-10"错误类型"场景，本以为控制器自己的`flag_amb_sample_qualified`门控会产生一次安静的不推进拒绝。结果真实观测到`o_ami_integration_protocol_error_sticky`和`o_system_fault_blocking`都置位——顺藤摸瓜查下去：`i_search_frame_type`和`i_search_calibration_applied`都接的是AMI内部共享网线（`dec_router_frame_type`/`flag_router_calibration_applied`），在`ppg_adc_measurement_idac_integration.v`里同时扇给好几个真实消费者（1868/1904/1978/2332行和1881/1917/1991/2341行），不是私有的单消费者信号——iverilog里对一个层级化端口引用做`force`，force的其实是那根共享网线本身，会污染同一根线上的所有其它真实消费者，而不是只隔离出本次测试想要孤立的那一个idac_code_controller输入。这是一个真实的方法论发现，不是"温和拒绝"的反例：在这颗RTL上用force一根共享网线来假装"只有这一个消费者看到了错配"根本不成立。（3）改用`tb_ppg_control_top_injection.v`自己INJ-02（LFA-08）已验证过的机制——`i_test_identity_inject_sample_index`，一条真正独立、不占用任何生产网线的旁路注入通道——第一次真实构造出一笔校准（AMB_CAL）事务的身份错配完成：它保留owner、置位`o_ami_integration_protocol_error_sticky`，并传播到`o_system_fault_blocking`，和INJ-02已确立的NORMAL路径行为完全一致。这就把SID-10"错误类型、颜色、样本序号、码快照或版本……只能被其自身的合同拒绝路径消费"在RTL层面的真实含义敲定了：这就是NORMAL事务上已经证实过的同一条硬性、系统级拒绝路径，不是第一版误读控制器自己更窄的qualified门控后得出的"两种不同严重程度"。（4）SID-10这条硬故障路径会留下置位的`error_sticky`（真实W1C保持位，和`tb_ppg_control_top.v`SMOKE-20→21已确立的模式一致），STOP排空回CONFIG本身不会清掉它——第一版阶段B之后的下一次COMMIT（阶段C）因此失败，直到在阶段B、C之间补上一次显式`i_diag_clear_event`脉冲。
//                                                             第五项是一次调查，不是bug修复：确认SID-11的"其它不合格"半句在本组范围内真实结构性不可达，不用不安全的手法勉强凑一个误导性的PASS——`i_stage1_calibration_valid=0`（控制器自己`flag_amb_sample_qualified`/`flag_dcs_sample_qualified`门控里唯一合法的"其它不合格"触发条件，`i_search_calibration_applied`那一项，456/463行）要求`run_profile=CHARACTERIZATION`才能COMMIT成功（`flag_snapshot_coef_qualification_valid`，`ppg_system_config_manager.v`413-414行，因为NORMAL_PPG强制要求`stage1_calibration_valid=1`）——但`run_profile=CHARACTERIZATION`又独立强制`idac_mode=MANUAL`（`flag_snapshot_char_idac_valid`，同文件364-365行），结构性地禁止`idac_mode=SEARCH_TRACK`从一开始就启动搜索。两条COMMIT层legality gate交集为空：SEARCH_TRACK和`stage1_calibration_valid=0`在任何合法配置下都不可能同时成立。而根据上面第（2）条发现，`i_search_calibration_applied`同样是那类多消费者共享AMI网线，也不能安全地用force单独构造成"这一个消费者看到的错配"。双向饱和触发条件和calibration-invalid触发条件都被堵死，当前RTL又没有专属的校准身份注入通道，SID-11在Group6范围内今天没有任何安全合法的构造路径——记为一个真实的结构性不可达发现（和ILM-11/12"需要Group6/8先做完"那种延后在性质上不同），留给以后RTL如果新增专属校准样本资格注入端口时再补测。
//                                                             四个阶段，每个阶段排空回CONFIG后独立重新提交（本组场景之间不能共享RUN状态——SEARCH_TRACK的启动搜索每次RUN只在第一次START时跑一次）：阶段A（SID-01）提交全新SEARCH_TRACK配置，确认START产生恰好一次`o_startup_idac_safe_boundary`脉冲，且在第一笔真实AMB请求发起之前波形/owner/宏帧/结果/样本序号全程零推进。阶段B（SID-10）在第一个真实AMB候选上用上面确立的真实身份注入机制，同时确认两半：搜索在错配完成上不推进，硬故障真实传播到`o_system_fault_blocking`；随后显式`i_diag_clear_event`清掉留下的`error_sticky`才能进阶段C。阶段C（SID-02/03/04/05/06/07/08/09/12正向半句）是真实的收敛走查：驱动真实AMB候选逼近`target_amb_code=64`（落在[8,240]内），再驱动真实DC_R候选逼近`target_dcs_r_code=80`（落在[12,230]内，仅红光LED窗口，AMB总线保持已确认AMB码），再驱动真实DC_IR候选逼近`target_dcs_ir_code=96`（落在[16,220]内，仅红外LED窗口）——每一个真实候选步骤都核对严格阶段顺序、专属Q3=266本地拍、625拍候选间隔和LED/DC总线隔离窗口，SID-05的错过tick 248截止时限（在第二个AMB候选窗口上把`i_adc_physical_idle`拉低越过截止时限）作为一次性扰动穿插其中，之后放手让真实搜索继续收敛，最终确认`o_startup_search_complete`在任何真实NORMAL owner提交之前置位，且之后真的开始出现真实NORMAL事务。阶段D（SID-12耗尽半句）提交`amb_threshold_low=72`/`amb_threshold_high=-64`（刻意反转成空窗口，使任何候选无论驱动什么值都不可能落入窗口内）的SEARCH_TRACK，确认AMB搜索真实耗尽，置位`o_amb_fault`/`o_amb_search_exhausted`/`o_controller_fault_blocking`，`o_startup_search_complete`保持低，NORMAL被无限期阻断。
//                                                             四个修复全部落地后：真实iverilog跑通，`JNT_BASELINE 53/53 PASS`，尝试的十一条ID（SID-01~10、SID-12）全部拿到真实仿真证据通过，SID-11按上文记录延后：`STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2`。
//
// 复位后独立提交四种SEARCH_TRACK场景配置，核对启动IDAC二分搜索算法的顺序、
// 时序常量、LED/DC总线隔离、拒绝路径与耗尽故障处理
module tb_ppg_control_top_startup_idac_calibration();

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

	localparam time C_SIM_TIMEOUT_NS = 64'd3000000000; // 3秒安全看门狗上限，本组含多轮完整二分搜索耗时更长
	localparam integer C_CANDIDATE_GUARD_MAX = 12; // 单阶段候选步数安全上限，8位码空间理论最多8步

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
	reg i_test_saturation_inject_valid = 1'b0; // SID-11：新专属饱和注入请求，默认0，构造SID-11时驱动
	reg i_context_handover_stall_request = 1'b0; // 本文件不覆盖OIB-01场景，恒0安全占位

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
			.C_ENABLE_TEST_INJECTION(32'd1) // SID-10需要真实驱动身份注入端口组，生产默认0必须覆盖成1，同`tb_ppg_control_top_injection.v`
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
	// 照抄Group11/12已验证过target_code恒等式的幂次Q16权重配置，专供JNT前缀
	// 内部自用；本组自己的SEARCH_TRACK场景task在此基础上覆盖idac_mode等字段
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
			// 阈值刻意选在make_fixed_raw可驱动范围[8,503]内部（不是Group11/12
			// 惯用的正负小数值窗口）——第一版沿用了±64/72，但make_fixed_raw把
			// 任何target_code钳制到[8,503]，永远不可能产生真正的负值，导致
			// "below_low"方向根本不可达：每次想驱动decrease方向实际上都被钳制
			// 成8，恰好落在[-64,72]窗口内，被误判成立刻收敛。真实RTL没有问题，
			// 是本文件驱动策略与固定编码函数值域没对齐——现在把窗口整体移到
			// [100,200]，200以上/100以下都在[8,503]内可以真实驱动到
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
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames
			i_source_config_snapshot[1009] = 1'b1; // peak_valley_config_valid
		end
	endtask

	task task_build_normal_manual_dual_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，真双光
		end
	endtask

	//---------------阶段A/B/C/D：SEARCH_TRACK场景配置构造任务---------------//
	// idac_mode=SEARCH_TRACK(2'b10)是本组的核心场景开关，其余字段沿用基线
	task task_build_search_track_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
		end
	endtask

	//---------------阶段D：SID-12耗尽场景配置构造任务---------------//
	// 反转AMB阈值窗口（low=72 > high=-64）构造一个永远为空的窗口，任何候选
	// 无论驱动什么校准值都不可能落入窗口内，保证二分搜索必然走到耗尽
	// 第一版尝试反转amb_threshold_low(200)>amb_threshold_high(100)构造一个
	// 空窗口，真实COMMIT被拒绝——flag_snapshot_threshold_valid
	// （ppg_system_config_manager.v 395-397行）硬性要求low<high，反转本身就
	// 不合法，是真实COMMIT-time legality gate，不是本文件能绕过的配置技巧。
	// 改为沿用主流程完全相同的合法[100,200]窗口，耗尽改由下面driving逻辑
	// 保证：每个候选无论当前码是多少，永远驱动above_high（503），二分搜索
	// 在amb_polarity=1下只会一路increase，走到amb_code_max=240后
	// flag_amb_search_has_next再也无法为真，自然真实耗尽
	task task_build_search_track_unreachable_config;
		begin
			task_build_search_track_config;
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
				$display("FAIL SID config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------排空回CONFIG任务---------------//
	task task_stop_and_drain;
		integer cnt_stop_wait;
		integer cnt_drain_wait;
		begin
			task_pulse_stop;
			cnt_stop_wait = 0;
			while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
				@(posedge i_clk);
				#1;
				cnt_stop_wait = cnt_stop_wait + 1;
			end
			cnt_drain_wait = 0;
			while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
				@(posedge i_clk);
				#1;
				cnt_drain_wait = cnt_drain_wait + 1;
			end
			if(o_lifecycle_state != ST_CONFIG) begin
				$display("FAIL SID drain to CONFIG timeout");
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
					$display("FAIL SID Q3 wait timeout");
					cnt_error = cnt_error + 1;
				end
			end
		end
	endtask

	//---------------Q3窗口内实时采样任务---------------//
	// wait_q3_release只在Q3完全释放（拉低）之后才返回，第一版曾在返回后才去
	// 读calibration_local_tick/leden1/leden2/dcn，真实观测到tick恒为268
	// （不是266）、leden1/leden2恒为0（不是1，AMB_CAL本应两个LED都关闭）——
	// 根因不是RTL错误，是采样时机太晚：release-wait子循环本身要再耗费几拍
	// 才能确认Q3真的拉低，等这个task返回时Q3窗口早已经关闭，取到的是窗口
	// 关闭后的下一个瞬态值。改为在Q3刚变高的那一拍立即采样，仍然等到真正
	// 释放才返回，语义不变，只是把采样点提前到窗口内部
	task wait_q3_release_and_sample;
		output o_real_release;
		output [9:0] o_sampled_local_tick;
		output o_sampled_leden1_low;
		output o_sampled_leden2_low;
		output [7:0] o_sampled_dcn;
		output [7:0] o_sampled_ambn;
		integer cnt_wd;
		begin
			cnt_wd = 0;
			while((o_clk_q3_low !== 1'b1) && (cnt_wd < 5600)) begin
				@(negedge i_clk);
				cnt_wd = cnt_wd + 1;
			end
			if(o_clk_q3_low !== 1'b1) begin
				o_real_release = 1'b0;
				o_sampled_local_tick = 10'd0;
				o_sampled_leden1_low = 1'b0;
				o_sampled_leden2_low = 1'b0;
				o_sampled_dcn = 8'h00;
				o_sampled_ambn = 8'h00;
			end else begin
				o_real_release = 1'b1;
				o_sampled_local_tick = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_local_tick;
				o_sampled_leden1_low = o_leden1_low;
				o_sampled_leden2_low = o_leden2_low;
				o_sampled_dcn = o_idac_sar9dcn_low;
				o_sampled_ambn = o_idac_sar9ambn_low;
				while((o_clk_q3_low === 1'b1) && (cnt_wd < 6600)) begin
					@(negedge i_clk);
					cnt_wd = cnt_wd + 1;
				end
				if(cnt_wd >= 6600) begin
					$display("FAIL SID Q3 wait timeout");
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

	`include "tb_ppg_jnt_baseline_prefix.vh"

	//---------------正式结果与owner提交边沿捕获进程---------------//
	integer cnt_result_capture;
	integer cnt_owner_commit_total_sid;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
		if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.adc_owner_commit_event_o) begin
			cnt_owner_commit_total_sid <= cnt_owner_commit_total_sid + 1;
		end
	end

	//---------------SID-11饱和注入单拍fire捕获进程---------------//
	// flag_test_saturation_inject_fire只在真实样本transfer那一拍组合成立，task
	// 调用返回后已经回落，必须用连续监视sticky住，不能在task返回后直接采样
	reg reg_saw_saturation_inject_fire = 1'b0;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.flag_test_saturation_inject_fire) begin
			reg_saw_saturation_inject_fire <= 1'b1;
		end
	end

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL STARTUP_IDAC_CALIBRATION global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------真实候选驱动任务：给定当前码和目标码，驱动一笔使校准结果---------------//
	//---------------明确落在阈值窗口外/内的真实RAW事务（AMB极性，above即increase）---------------//
	// make_fixed_raw把target_code钳制到[8,503]（vdred固定编码函数的真实值域，
	// 不是任意范围）——阈值窗口已经改到[100,200]完全落在这个值域内部，所以
	// 503（>200，真实above_high）和8（<100，真实below_low）都能被真实驱动到，
	// 不再依赖之前±1500那种会被钳制回8、永远到不了负值的错误假设
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

	//---------------2026-09-17新增：tick-248截止抑制验证任务（真实缺口SID-05，---------------//
	//---------------工作线D独立复核发现原本只在AMB阶段验证过一次，DC_R/DC_IR阶段---------------//
	//---------------结构上同样受此约束但从未验证；提取AMB阶段原有逻辑为可复用task，---------------//
	//---------------只负责"等新候选窗口开头->压住idle到248拍截止->松开->确认无owner---------------//
	//---------------提交"这段与具体阶段无关的部分，码是否变化仍由调用方按自己的码---------------//
	//---------------寄存器核对，因为Verilog-2001任务不能传信号引用---------------//
	task task_verify_deadline_suppression;
		input [8 * 24 - 1:0] case_id;
		integer cnt_wait_tick0;
		integer cnt_wait_deadline;
		integer cnt_owner_before_local;
		begin
			cnt_wait_tick0 = 0;
			while((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_local_tick > 10'd5) &&
				(cnt_wait_tick0 < 700) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_tick0 = cnt_wait_tick0 + 1;
			end
			cnt_owner_before_local = cnt_owner_commit_total_sid;
			i_adc_physical_idle = 1'b0;
			cnt_wait_deadline = 0;
			while((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_local_tick <= 10'd248) &&
				(cnt_wait_deadline < 700) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_deadline = cnt_wait_deadline + 1;
			end
			i_adc_physical_idle = 1'b1;
			if(cnt_owner_commit_total_sid != cnt_owner_before_local) begin
				$display("FAIL %0s a real owner commit occurred despite holding i_adc_physical_idle=0 through the tick-248 deadline", case_id);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS %0s candidate window suppressed after missing the tick-248 owner-commit deadline, no owner committed", case_id);
			end
		end
	endtask

	//---------------主序列---------------//
	initial begin : main_sequence
		reg real_release;
		integer cnt_candidate_guard;
		integer cnt_owner_before;
		integer cnt_frame_before;
		integer cnt_result_before;
		reg [7:0] reg_confirmed_amb_code;
		reg [7:0] reg_current_amb_code, reg_current_dcs_r_code, reg_current_dcs_ir_code;
		reg [4:0] reg_state_before;
		integer cnt_wait_request;
		time time_prev_q3, time_this_q3;
		integer cnt_boundary_pulses;
		reg [9:0] raw_code_exhaustion;
		reg [9:0] reg_sampled_tick;
		reg reg_sampled_leden1, reg_sampled_leden2;
		reg [7:0] reg_sampled_dcn;
		reg [7:0] reg_sampled_ambn;
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		cnt_owner_commit_total_sid = 0;
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

		//=========== 阶段A：SID-01，START唯一安全边界+零副作用 ===========//
		task_build_search_track_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SID phase A commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		cnt_owner_before = cnt_owner_commit_total_sid;
		cnt_frame_before = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o;
		cnt_result_before = cnt_result_capture;
		cnt_boundary_pulses = 0;
		task_pulse_start;
		begin : sid01_boundary_window
			integer cnt_watch;
			for(cnt_watch = 0; cnt_watch < 400; cnt_watch = cnt_watch + 1) begin
				@(posedge i_clk);
				if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_startup_idac_safe_boundary) begin
					cnt_boundary_pulses = cnt_boundary_pulses + 1;
				end
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request) begin
					cnt_watch = 400; // 真实AMB请求已经发起，SID-01观察窗口到此为止
				end
			end
		end
		if(cnt_boundary_pulses != 1) begin
			$display("FAIL SID-01 expected exactly one startup safe boundary pulse, observed=%0d", cnt_boundary_pulses);
			cnt_error = cnt_error + 1;
		end else if((cnt_owner_commit_total_sid != cnt_owner_before) ||
			(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o != cnt_frame_before) ||
			(cnt_result_capture != cnt_result_before)) begin
			$display("FAIL SID-01 unexpected owner/frame/result advance before first real AMB request");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SID-01 START produced exactly one startup safe boundary pulse with zero waveform/owner/frame/result advance before the first real AMB request");
		end
		task_stop_and_drain;

		//=========== 阶段B：SID-10，用专属验证注入口构造真实wrong-identity ===========//
		// 本文件第一版曾尝试对idac_code_controller的i_search_frame_type/
		// i_search_calibration_applied端口直接force，第一次真实跑通后发现这是
		// 方法论错误：两个端口在AMI内部都连到共享网线（dec_router_frame_type、
		// flag_router_calibration_applied，ppg_adc_measurement_idac_integration.v
		// 分别在1881/1917/1991/2341行和1868/1904/1978/2332行同时接给多个消费者），
		// force这类端口在iverilog里实际force的是共享网线本身，不是"只有这一个
		// 消费者看到的隔离视角"——会同时污染同一根线的其它真实消费者，触发一个
		// 完全不相关、更严重的协议错误（真实观测到o_ami_integration_protocol_
		// error_sticky置位、o_system_fault_blocking跟着置位），而不是
		// idac_code_controller自己qualified门控那种温和拒绝。这是本轮第一个真实
		// RTL/方法论发现：直接force一个共享net做"单一消费者视角错配"测试在这颗
		// RTL上不成立，必须改用专门为此设计的验证注入口。
		// 改用`tb_ppg_control_top_injection.v`INJ-02（LFA-08）已验证过的
		// i_test_identity_inject_sample_index机制——它是AMI真正独立的旁路注入
		// 通道，不占用任何生产网线，专门用于构造一次真实的completion身份错配。
		// 该注入口的ready条件（AMI 993行）不区分NORMAL还是校准帧类型，本组
		// 完全可以复用。同时确认了本轮第二个真实发现：SID-11的"其它不合格"
		// 半句（stage1_calibration_valid=0）在COMMIT层结构性不可达——
		// flag_snapshot_char_idac_valid（ppg_system_config_manager.v 364-365行）
		// 规定run_profile=CHARACTERIZATION时idac_mode必须是MANUAL，而
		// flag_snapshot_coef_qualification_valid（同文件413-414行）规定
		// stage1_calibration_valid=0时唯一合法路径恰好就是run_profile=
		// CHARACTERIZATION——两条规则交集为空，SEARCH_TRACK和
		// stage1_calibration_valid=0在任何合法配置下都不可能同时成立；而且
		// i_search_calibration_applied同样是上面确认过的共享网线，就算配置能
		// 绕过去，也不能用force安全地单独构造。加上双向饱和数学不可达，SID-11
		// 在本组（STARTUP-IDAC-CALIBRATION）范围内没有任何安全、合法的构造
		// 路径——记为结构性不可达，留待后续如果RTL新增专属校准身份注入通道再
		// 补测，不在这里用不安全的手法勉强凑一个误导性的PASS
		i_test_inject_enable = 1'b1;
		task_build_search_track_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SID phase B commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_request = 0;
		while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request &&
			(cnt_wait_request < 5000) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_request = cnt_wait_request + 1;
		end
		if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request) begin
			$display("FAIL SID-10 AMB sample request never asserted");
			cnt_error = cnt_error + 1;
		end else begin
			reg_current_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL SID-10 real Q3 window never opened");
				cnt_error = cnt_error + 1;
			end else begin
				i_test_identity_inject_sample_index = 16'hFFFF; // 与当前owner真实sample_index必然不同
				i_test_identity_inject_valid = 1'b1;
				task_drive_amb_toward_target(reg_current_amb_code, reg_current_amb_code);
				if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_test_identity_hold) begin
					$display("FAIL SID-10 identity injection never fired (flag_test_identity_hold stayed 0)");
					cnt_error = cnt_error + 1;
				end else begin
					i_test_identity_inject_valid = 1'b0;
					repeat(4) @(posedge i_clk);
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code != reg_current_amb_code) begin
						$display("FAIL SID-10 AMB code advanced despite mismatched injected identity");
						cnt_error = cnt_error + 1;
					end else begin
						$display("PASS SID-10 AMB search did not advance on a mismatched-identity completion (search evidence side)");
					end
					cnt_wait_request = 0;
					while(!o_system_fault_blocking && (cnt_wait_request < 500) && !flag_global_timeout) begin
						@(posedge i_clk);
						cnt_wait_request = cnt_wait_request + 1;
					end
					if(!o_system_fault_blocking) begin
						$display("FAIL SID-10 o_system_fault_blocking never propagated through supervisor after mismatched identity");
						cnt_error = cnt_error + 1;
					end else begin
						$display("PASS SID-10 mismatched calibration identity correctly propagated to o_system_fault_blocking (hard reject path, same severity as INJ-02/LFA-08)");
					end
				end
			end
		end
		i_test_inject_enable = 1'b0;
		task_stop_and_drain;
		// SID-10的硬故障路径会置位error_sticky（真实W1C保持位，同
		// tb_ppg_control_top.v SMOKE-20→21已确立的模式），STOP排空回CONFIG本身
		// 不会清掉它，必须显式脉冲i_diag_clear_event，否则下面阶段C的COMMIT
		// 会被这个遗留的sticky挡住——第一版遗漏了这一步，真实COMMIT失败
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);

		//=========== 阶段B2：SID-11，用专属饱和注入口构造真实双向饱和拒绝 ===========//
		// 本组RTL会话新增了idac_code_controller自己的i_test_saturation_inject_valid/
		// o_test_saturation_inject_ready专属注入口（不touch共享的i_search_
		// saturation_low/high输入线），直接覆盖flag_amb_sample_qualified/
		// flag_dcs_sample_qualified里的饱和判据项。与SID-10共用同一阶段会残留
		// SID-10自己触发的o_system_fault_blocking硬故障，所以独立开一个干净的
		// 阶段：重新COMMIT+START，等到真实AMB请求窗口，再驱动注入
		i_test_inject_enable = 1'b1;
		task_build_search_track_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SID phase B2 commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		cnt_wait_request = 0;
		while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request &&
			(cnt_wait_request < 5000) && !flag_global_timeout) begin
			@(posedge i_clk);
			cnt_wait_request = cnt_wait_request + 1;
		end
		if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request) begin
			$display("FAIL SID-11 AMB sample request never asserted");
			cnt_error = cnt_error + 1;
		end else begin
			reg_current_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL SID-11 real Q3 window never opened");
				cnt_error = cnt_error + 1;
			end else begin
				reg_saw_saturation_inject_fire = 1'b0;
				i_test_saturation_inject_valid = 1'b1;
				task_drive_amb_toward_target(reg_current_amb_code, reg_current_amb_code);
				// task_drive_amb_toward_target只负责递送CLK_DOUT本身；真实样本还要经过
				// AMI捕获/S1重构/校准/router若干级流水线才能到达idac_code_controller
				// 自己的i_search_amb_valid，不能在task返回的当拍立即判定——第一版就是
				// 因为没等这段流水线延迟，真实注入其实已经按设计生效，却被判定成FAIL
				cnt_wait_request = 0;
				while(!reg_saw_saturation_inject_fire && (cnt_wait_request < 200) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_request = cnt_wait_request + 1;
				end
				if(!reg_saw_saturation_inject_fire) begin
					$display("FAIL SID-11 saturation injection never fired (flag_test_saturation_inject_fire stayed 0 throughout the real transfer)");
					cnt_error = cnt_error + 1;
				end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code != reg_current_amb_code) begin
					$display("FAIL SID-11 AMB code advanced despite forced double-saturation on the injected sample");
					cnt_error = cnt_error + 1;
				end else if(o_system_fault_blocking || o_error_event) begin
					$display("FAIL SID-11 forced double-saturation unexpectedly escalated to a hard system fault (o_system_fault_blocking=%0d o_error_event=%0d), expected a silent local reject",
						o_system_fault_blocking, o_error_event);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS SID-11 double-saturated sample consumed by its own qualified-gate reject path, committed AMB code unchanged, no fabricated success, no escalation to a hard system fault");
				end
				i_test_saturation_inject_valid = 1'b0;
			end
		end
		i_test_inject_enable = 1'b0;
		task_stop_and_drain;



		//=========== 阶段C：真实收敛走查，SID-02/03/04/05/06/07/08/09/12正向半句 ===========//
		task_build_search_track_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SID phase C commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		//------- SID-02阶段顺序：入口必须先是AMB -------//
		reg_state_before = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current;
		if((reg_state_before != ST_IDAC_AMB_APPLY) && (reg_state_before != ST_IDAC_AMB_WAIT)) begin
			$display("FAIL SID-02 startup search did not enter AMB stage first, state=%0d", reg_state_before);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SID-02 startup search entered AMB stage first as required");
		end

		//------- AMB阶段真实二分搜索收敛 -------//
		begin : sid_amb_stage
			integer cnt_candidate;
			reg flag_amb_converged;
			reg flag_sid05_injected;
			flag_amb_converged = 1'b0;
			flag_sid05_injected = 1'b0;
			time_prev_q3 = 0;
			for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_amb_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
				cnt_wait_request = 0;
				while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request &&
					(cnt_wait_request < 5000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_request = cnt_wait_request + 1;
				end
				reg_current_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;

				if(!flag_sid05_injected) begin
					flag_sid05_injected = 1'b1;
					// 2026-09-17重构：原内联逻辑提取为task_verify_deadline_suppression，
					// 行为不变，只是把"等窗口开头->压idle到248拍->松开->确认无owner提交"
					// 这段与阶段无关的部分变成可复用task，供下方DC_R/DC_IR阶段同款
					// 补测调用（工作线D独立复核真实缺口，SID_01_12_WORKLINE_D_
					// INDEPENDENT_RECHECK_20260917.md）
					task_verify_deadline_suppression("SID-05-AMB");
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code != reg_current_amb_code) begin
						$display("FAIL SID-05-AMB AMB code advanced despite the missed-deadline window");
						cnt_error = cnt_error + 1;
					end
					wait_q3_release(real_release);
					if(!real_release) begin
						$display("FAIL SID-05 retried candidate real Q3 window never opened after the missed-deadline window");
						cnt_error = cnt_error + 1;
					end else begin
						task_drive_amb_toward_target(reg_current_amb_code, 64);
					end
				end else begin
					wait_q3_release_and_sample(real_release, reg_sampled_tick, reg_sampled_leden1, reg_sampled_leden2, reg_sampled_dcn, reg_sampled_ambn);
					if(!real_release) begin
						$display("FAIL SID-04 AMB candidate %0d real Q3 window never opened", cnt_candidate);
						cnt_error = cnt_error + 1;
					end else begin
						//---- SID-03：本地tick必须是校准专属265/266窗口内，不是NORMAL的Q3位置 ----//
						if((reg_sampled_tick != 10'd265) && (reg_sampled_tick != 10'd266)) begin
							$display("FAIL SID-03 AMB candidate calibration_local_tick not in [265,266], observed=%0d", reg_sampled_tick);
							cnt_error = cnt_error + 1;
						end
						//---- SID-07：AMB_CAL期间两个LED都关闭，DC总线不活动 ----//
						//---- o_leden1_low/o_leden2_low虽然带_low后缀，真实极性是 ----//
						//---- 1=点亮、0=关闭（tb_ppg_control_top.v的SMOKE-18已经确立 ----//
						//---- 这个约定，本文件第一版按字面"_low"猜成了active-low， ----//
						//---- 误把真实关闭状态(0,0)当成故障报出来，是TB自己的极性 ----//
						//---- 假设错误，不是RTL缺陷 ----//
						if(reg_sampled_leden1 || reg_sampled_leden2 || (reg_sampled_dcn !== 8'h00)) begin
							$display("FAIL SID-07 AMB_CAL LED/DC bus not isolated: leden1=%b leden2=%b dcn=%h",
								reg_sampled_leden1, reg_sampled_leden2, reg_sampled_dcn);
							cnt_error = cnt_error + 1;
						end
						time_this_q3 = $time;
						if(time_prev_q3 != 0) begin
							if((time_this_q3 - time_prev_q3) != (625 * 500)) begin
								$display("FAIL SID-04 AMB candidate spacing != 625 ticks, observed=%0d ns", time_this_q3 - time_prev_q3);
								cnt_error = cnt_error + 1;
							end
						end
						time_prev_q3 = time_this_q3;
						task_drive_amb_toward_target(reg_current_amb_code, 64);
					end
				end

				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_APPLY ||
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_WAIT) begin
					flag_amb_converged = 1'b1;
					reg_confirmed_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
				end
			end
			if(!flag_amb_converged) begin
				$display("FAIL SID AMB stage did not converge within %0d candidates", C_CANDIDATE_GUARD_MAX);
				cnt_error = cnt_error + 1;
			end else if(reg_confirmed_amb_code != 64) begin
				$display("FAIL SID AMB stage converged to wrong code, expected=64 observed=%0d", reg_confirmed_amb_code);
				cnt_error = cnt_error + 1;
			end else begin
				// 2026-09-18工作线D待查清单修复：去掉误导性的"/06"标签——这条消息
				// 只测了"AMB搜索最终收敛到正确目标码"，跟SID-06真正要求的"快照
				// 何时锁定/tick 385之后的更新只影响下一子帧"是两件事，真实SID-06
				// 覆盖见下方DC_R阶段新增的专属检查
				$display("PASS SID-04 AMB stage converged to target code 64 with real physical candidates 625 ticks apart");
			end
		end

		//------- DC_R阶段真实二分搜索收敛 -------//
		begin : sid_dcs_r_stage
			integer cnt_candidate;
			integer cnt_sid06_wait;
			reg flag_dcs_r_converged;
			reg flag_sid05_dcr_injected;
			reg flag_sid06_front_done;
			reg flag_sid06_bus_check_pending;
			reg [7:0] reg_sid06_bus_before;
			reg [7:0] reg_sid06_committed_after;
			flag_dcs_r_converged = 1'b0;
			flag_sid05_dcr_injected = 1'b0;
			flag_sid06_front_done = 1'b0;
			flag_sid06_bus_check_pending = 1'b0;
			time_prev_q3 = 0;
			for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_dcs_r_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
				cnt_wait_request = 0;
				while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request &&
					(cnt_wait_request < 5000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_request = cnt_wait_request + 1;
				end
				reg_current_dcs_r_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
				if(!flag_sid05_dcr_injected) begin
					flag_sid05_dcr_injected = 1'b1;
					// 2026-09-18工作线D待查清单修复：2026-09-17曾在此处尝试同AMB
					// 阶段一样调用task_verify_deadline_suppression，真实回归发现
					// 抑制检查本身能通过但DC_R的Q3窗口从此再也不会打开——真实根因
					// 不在这个task或DC_R阶段本身，而是AMI（ppg_adc_measurement_
					// idac_integration.v）的flag_calibration_request_inflight只在
					// 真实消费到搜索结果或STOP/abort时才清零，被deadline抑制的请求
					// 两者都不会发生，永久卡住不再重新发起请求；已修复（AMI V1.15
					// 新增i_cal_owner_deadline_event接调度器V1.8新增的
					// o_cal_owner_deadline_event，另加为inflight清零条件），
					// 真实iverilog A/B trace确认修复前卡死、修复后DC_R/DC_IR均
					// 正常收敛，见WORKLINE_D_SID05_SID06_20260918.md
					task_verify_deadline_suppression("SID-05-DCR");
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != reg_current_dcs_r_code) begin
						$display("FAIL SID-05-DCR DCS_R code advanced despite the missed-deadline window");
						cnt_error = cnt_error + 1;
					end
					wait_q3_release(real_release);
					if(!real_release) begin
						$display("FAIL SID-05-DCR retried candidate real Q3 window never opened after the missed-deadline window");
						cnt_error = cnt_error + 1;
					end else begin
						task_drive_dcs_toward_target(reg_current_dcs_r_code, 80);
					end
				end else begin
				// 2026-09-18工作线D待查清单修复（真实缺口SID-06）：合同要求候选/
				// 已确认AMB码/颜色/类型/epoch必须在准备窗口前锁定，tick 385之后的
				// 更新只影响下一子帧、不能扰动当前子帧；此前只有一条挂靠SID-04的
				// PASS消息，从未真正测过这条时序性质。RTL锚点确认：SSW（ppg_sar9_
				// sar15_safe_selection_wrapper.v）reg_cal_dc_code只在flag_context_
				// fire && flag_context_is_cal（本地tick 0波形上下文接管）那一拍
				// 锁存，两次接管之间恒定；调度器flag_calibration_boundary_o（本地
				// tick恰为385，CAL_IDAC_LOCAL_TICK）是IDAC控制器候选提交的唯一安全
				// 边界。真实构造：在候选真正变化的一次提交前后，直接层次化读取
				// reg_cal_dc_code这个RTL内部锁存寄存器（不是TB自己维护的镜像），
				// 跨过本子帧385之后确认它还没变，下一子帧真实Q3采样确认它已经变。
				// 基线故意取自本次真实Q3采样得到的reg_sampled_dcn（tick 265/266，
				// 早已跨过本子帧自己的tick 0上下文接管点，是稳定值），不能在Q3
				// 采样之前就去读reg_cal_dc_code——第一版这样做过，真实回归testFAIL：
				// 此时该寄存器可能还没赶上*上一次*提交（SSW只在自己的tick 0接管
				// 点才刷新），读到的是更早一拍尚未生效的陈旧值，导致后面比较基准
				// 本身就是错的，误报"当前子帧被扰动"，其实只是基线取早了
				wait_q3_release_and_sample(real_release, reg_sampled_tick, reg_sampled_leden1, reg_sampled_leden2, reg_sampled_dcn, reg_sampled_ambn);
				if(!real_release) begin
					$display("FAIL SID-08 DC_R candidate %0d real Q3 window never opened", cnt_candidate);
					cnt_error = cnt_error + 1;
				end else begin
					//---- SID-08：DCS_CAL RED期间只有红光LED窗口，AMB总线保持 ----//
					//---- 已确认的AMB码，DC总线携带当前红光候选。真实极性1=点亮、 ----//
					//---- 0=关闭（同SID-07注释，SMOKE-18已确立），第一版这里也 ----//
					//---- 猜反了 ----//
					if(!reg_sampled_leden1 || reg_sampled_leden2) begin
						$display("FAIL SID-08 DCS_CAL RED LED window wrong: leden1=%b(expect on/1) leden2=%b(expect off/0)", reg_sampled_leden1, reg_sampled_leden2);
						cnt_error = cnt_error + 1;
					end else if(reg_sampled_ambn !== reg_confirmed_amb_code) begin
						$display("FAIL SID-08 AMB bus not holding confirmed code during DC_R stage, observed=%h expect=%h", reg_sampled_ambn, reg_confirmed_amb_code);
						cnt_error = cnt_error + 1;
					end else begin
						$display("PASS SID-08 DCS_CAL RED: only RED LED window active, AMB bus holds confirmed code %h", reg_confirmed_amb_code);
					end
					// 2026-09-17新增：DC_R候选同样必须落在校准专属265/266窗口
					// （真实缺口SID-03），且相邻真实候选间隔恰好625拍（真实缺口SID-04）
					if((reg_sampled_tick != 10'd265) && (reg_sampled_tick != 10'd266)) begin
						$display("FAIL SID-03-DCR DC_R candidate calibration_local_tick not in [265,266], observed=%0d", reg_sampled_tick);
						cnt_error = cnt_error + 1;
					end
					time_this_q3 = $time;
					if(time_prev_q3 != 0) begin
						if((time_this_q3 - time_prev_q3) != (625 * 500)) begin
							$display("FAIL SID-04-DCR DC_R candidate spacing != 625 ticks, observed=%0d ns", time_this_q3 - time_prev_q3);
							cnt_error = cnt_error + 1;
						end
					end
					time_prev_q3 = time_this_q3;
					//---- SID-06后半句：新子帧的真实Q3采样必须已经看到上一次提交的新码 ----//
					if(flag_sid06_bus_check_pending) begin
						flag_sid06_bus_check_pending = 1'b0;
						if(reg_sampled_dcn !== reg_sid06_committed_after) begin
							$display("FAIL SID-06 next-subframe waveform snapshot did not pick up the prior tick-385 commit, expected=%h observed=%h", reg_sid06_committed_after, reg_sampled_dcn);
							cnt_error = cnt_error + 1;
						end else begin
							$display("PASS SID-06 next-subframe waveform snapshot correctly reflects the code committed at the prior subframe's tick-385 boundary, code=%h", reg_sampled_dcn);
						end
					end
					//---- SID-06前半句基线：本次真实Q3采样得到的值是本子帧当前稳定 ----//
					//---- 持有的旧码，只在第一次真实驱动前捕获一次 ----//
					if(!flag_sid06_front_done) begin
						reg_sid06_bus_before = reg_sampled_dcn;
					end
					task_drive_dcs_toward_target(reg_current_dcs_r_code, 80);
					//---- SID-06前半句：本子帧385拍之后，SSW锁存寄存器必须仍是旧值，不能被本次刚提交的新候选提前扰动 ----//
					//---- 只在第一次真实驱动后运行一次，避免后续候选反复复用同一个陈旧基线误判 ----//
					if(!flag_sid06_front_done && (reg_current_dcs_r_code != 80)) begin
						flag_sid06_front_done = 1'b1;
						cnt_sid06_wait = 0;
						while((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_local_tick <= 10'd385) &&
							(cnt_sid06_wait < 400) && !flag_global_timeout) begin
							@(posedge i_clk);
							cnt_sid06_wait = cnt_sid06_wait + 1;
						end
						reg_sid06_committed_after = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
						if(reg_sid06_committed_after == reg_sid06_bus_before) begin
							$display("FAIL SID-06 check is vacuous: candidate committed at tick-385 did not actually change the DC_R code (still %h), cannot prove non-perturbation", reg_sid06_bus_before);
							cnt_error = cnt_error + 1;
						end else if(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_dc_code !== reg_sid06_bus_before) begin
							$display("FAIL SID-06 current-subframe waveform snapshot was perturbed by the tick-385 commit, expected(unchanged)=%h observed=%h",
								reg_sid06_bus_before, ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_dc_code);
							cnt_error = cnt_error + 1;
						end else begin
							$display("PASS SID-06 current-subframe waveform snapshot unperturbed past the tick-385 commit boundary (old=%h, newly committed=%h, not yet visible)", reg_sid06_bus_before, reg_sid06_committed_after);
						end
						flag_sid06_bus_check_pending = 1'b1;
					end
				end
				end
				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_APPLY ||
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_WAIT) begin
					flag_dcs_r_converged = 1'b1;
				end
			end
			if(!flag_dcs_r_converged) begin
				$display("FAIL SID DC_R stage did not converge within %0d candidates", C_CANDIDATE_GUARD_MAX);
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != 80) begin
				$display("FAIL SID DC_R stage converged to wrong code, expected=80 observed=%0d",
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SID DC_R stage converged to target code 80");
			end
		end

		//------- DC_IR阶段真实二分搜索收敛 -------//
		begin : sid_dcs_ir_stage
			integer cnt_candidate;
			reg flag_dcs_ir_converged;
			reg flag_sid05_dcir_injected;
			flag_dcs_ir_converged = 1'b0;
			flag_sid05_dcir_injected = 1'b0;
			time_prev_q3 = 0; // 2026-09-17新增：DC_IR阶段独立重置候选间隔基线，避免跨阶段边界误判625拍间隔
			for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_dcs_ir_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
				cnt_wait_request = 0;
				while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request &&
					(cnt_wait_request < 5000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_request = cnt_wait_request + 1;
				end
				reg_current_dcs_ir_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code;
				if(!flag_sid05_dcir_injected) begin
					flag_sid05_dcir_injected = 1'b1;
					// 2026-09-18工作线D待查清单修复：同DC_R阶段，2026-09-17真实回归
					// 曾发现这里同样会卡死不收敛，根因是AMI flag_calibration_
					// request_inflight缺少deadline超时清零路径，与DC_R同一根因、
					// 同一次RTL修复解决（AMI V1.15 + 调度器V1.8），见DC_R阶段注释
					// 与WORKLINE_D_SID05_SID06_20260918.md
					task_verify_deadline_suppression("SID-05-DCIR");
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code != reg_current_dcs_ir_code) begin
						$display("FAIL SID-05-DCIR DCS_IR code advanced despite the missed-deadline window");
						cnt_error = cnt_error + 1;
					end
					wait_q3_release(real_release);
					if(!real_release) begin
						$display("FAIL SID-05-DCIR retried candidate real Q3 window never opened after the missed-deadline window");
						cnt_error = cnt_error + 1;
					end else begin
						task_drive_dcs_toward_target(reg_current_dcs_ir_code, 96);
					end
				end else begin
				wait_q3_release_and_sample(real_release, reg_sampled_tick, reg_sampled_leden1, reg_sampled_leden2, reg_sampled_dcn, reg_sampled_ambn);
				if(!real_release) begin
					$display("FAIL SID-09 DC_IR candidate %0d real Q3 window never opened", cnt_candidate);
					cnt_error = cnt_error + 1;
				end else begin
					//---- SID-09：DCS_CAL IR期间只有红外LED窗口，极性同SID-08注释 ----//
					if(reg_sampled_leden1 || !reg_sampled_leden2) begin
						$display("FAIL SID-09 DCS_CAL IR LED window wrong: leden1=%b(expect off/0) leden2=%b(expect on/1)", reg_sampled_leden1, reg_sampled_leden2);
						cnt_error = cnt_error + 1;
					end else begin
						$display("PASS SID-09 DCS_CAL IR: only IR LED window active");
					end
					// 2026-09-17新增：DC_IR候选同样必须落在校准专属265/266窗口
					// （真实缺口SID-03），且相邻真实候选间隔恰好625拍（真实缺口SID-04）
					if((reg_sampled_tick != 10'd265) && (reg_sampled_tick != 10'd266)) begin
						$display("FAIL SID-03-DCIR DC_IR candidate calibration_local_tick not in [265,266], observed=%0d", reg_sampled_tick);
						cnt_error = cnt_error + 1;
					end
					time_this_q3 = $time;
					if(time_prev_q3 != 0) begin
						if((time_this_q3 - time_prev_q3) != (625 * 500)) begin
							$display("FAIL SID-04-DCIR DC_IR candidate spacing != 625 ticks, observed=%0d ns", time_this_q3 - time_prev_q3);
							cnt_error = cnt_error + 1;
						end
					end
					time_prev_q3 = time_this_q3;
					task_drive_dcs_toward_target(reg_current_dcs_ir_code, 96);
				end
				end
				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_NORMAL) begin
					flag_dcs_ir_converged = 1'b1;
				end
			end
			if(!flag_dcs_ir_converged) begin
				$display("FAIL SID DC_IR stage did not converge within %0d candidates", C_CANDIDATE_GUARD_MAX);
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code != 96) begin
				$display("FAIL SID DC_IR stage converged to wrong code, expected=96 observed=%0d",
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SID DC_IR stage converged to target code 96");
			end
		end

		//------- SID-12正向半句：startup_search_complete在任何NORMAL owner之前置位 -------//
		if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete) begin
			$display("FAIL SID-12 startup_search_complete did not assert after all three stages converged");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS SID-12 startup_search_complete asserted after AMB/DC_R/DC_IR closure, before this phase drove any NORMAL owner");
		end

		//------- 收尾：确认NORMAL现在真的可以推进 -------//
		cnt_owner_before = cnt_owner_commit_total_sid;
		begin : sid_normal_unblock
			integer cnt_wait_normal;
			cnt_wait_normal = 0;
			while((cnt_owner_commit_total_sid == cnt_owner_before) && (cnt_wait_normal < 20000) && !flag_global_timeout) begin
				wait_q3_release(real_release);
				if(real_release) begin
					drive_real_adc_done(1'b0, 10'h100, 10'h100);
				end
				cnt_wait_normal = cnt_wait_normal + 1;
			end
			if(cnt_owner_commit_total_sid == cnt_owner_before) begin
				$display("FAIL SID-12 NORMAL never produced a real owner commit after startup search completed");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SID-12 NORMAL genuinely unblocked after startup search completion");
			end
		end
		task_stop_and_drain;

		//=========== 阶段D：SID-12耗尽半句，反转阈值窗口强制AMB搜索走到耗尽 ===========//
		task_build_search_track_unreachable_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL SID phase D commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		begin : sid_exhaustion
			integer cnt_candidate;
			reg flag_exhausted_seen;
			flag_exhausted_seen = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < (C_CANDIDATE_GUARD_MAX + 2)) && !flag_exhausted_seen && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
				wait_q3_release(real_release);
				if(real_release) begin
					make_fixed_raw(0, raw_code_exhaustion);
					drive_real_adc_done(1'b0, raw_code_exhaustion, raw_code_exhaustion);
				end
				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_search_exhausted ||
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_fault) begin
					flag_exhausted_seen = 1'b1;
				end
			end
			if(!flag_exhausted_seen) begin
				$display("FAIL SID-12 AMB search never reached exhaustion under an unreachable threshold window");
				cnt_error = cnt_error + 1;
			end else if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_controller_fault_blocking) begin
				$display("FAIL SID-12 controller_fault_blocking not asserted after AMB exhaustion");
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete) begin
				$display("FAIL SID-12 startup_search_complete incorrectly asserted after exhaustion");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SID-12 AMB search reached exhaustion under an unreachable threshold window: fault/exhausted asserted, startup_search_complete stayed low");
			end

			cnt_owner_before = cnt_owner_commit_total_sid;
			repeat(3000) @(posedge i_clk);
			if(cnt_owner_commit_total_sid != cnt_owner_before) begin
				$display("FAIL SID-12 a real owner commit occurred despite AMB search exhaustion blocking NORMAL");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS SID-12 NORMAL stayed blocked for 3000 cycles after AMB search exhaustion");
			end
		end

		if(cnt_error == 0) begin
			$display("STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=%0d", cnt_result_capture);
		end else begin
			$display("STARTUP_IDAC_CALIBRATION_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
