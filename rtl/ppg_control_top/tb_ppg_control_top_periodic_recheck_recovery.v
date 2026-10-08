`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/28
// Design Name:        PPG Periodic Recheck Recovery Testbench
// Module Name:        tb_ppg_control_top_periodic_recheck_recovery
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_amb_recheck_scheduler.v
//                      ppg_idac_code_controller.v
//                      ppg_dynamic_baseline_cross_detector.v
//                      ppg_coarse_detection_fir.v
//                      PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.3
// Revision Date:      2026/10/08
// History:
//    Time               Version       Revised by            Contents
// 2026/08/28            V1.0          Erie                  Create file. Stage 5 Group 8 (PERIODIC-RECHECK-RECOVERY, C25 contract section 9.4.3, RRC-01~12). This is a genuinely new mechanism layered on top of the same ppg_idac_code_controller.v/ppg_amb_recheck_scheduler.v pair Group 6 (startup search) and Group 7 (NORMAL tracking) already exercise: ppg_amb_recheck_scheduler.v counts completed NORMAL macro frames (i_normal_frame_complete_event, gated by flag_period_enabled which itself requires i_startup_search_complete -- confirming the batching plan's Group6-before-Group8 dependency) against ACTIVE's i_amb_recheck_interval_frames (bits [591:576]), latches pending, and only actually accepts (safely takes over NORMAL) once flag_takeover_safe (ADC/fork/IDAC/FIR/peak-valley idle plus a frame-safe-boundary) holds AND a real i_precision_15_to_9_event has been observed -- confirmed by direct RTL read that this return-to-9-bit gate is NOT conditional on "started pending while already in SAR15": ST_MONITOR's own next-state logic requires i_precision_15_to_9_event before ever leaving ST_MONITOR/ST_WAIT_SWITCH, so a genuine SAR9->15->9 round trip is a hard prerequisite for every single accepted recheck cycle, not just RRC-02's specific SAR15-block scenario. Once accepted, ppg_idac_code_controller.v runs the periodic sequence through three NEW, dedicated states (ST_AMB_RECHECK=9, ST_DCS_REVALIDATE_WAIT=10, ST_DCS_REVALIDATE_R=11, ST_DCS_REVALIDATE_IR=12) that first evaluate the ALREADY-COMMITTED code in place (no fresh candidate) -- an in-window result finishes that stage immediately with the code/epoch untouched (RRC-06), while a confirmed same-direction excursion (same cnt_amb_high/cnt_amb_low confirm-count mechanism Group6/7 already use) escalates into the SAME shared bisection states startup search and NORMAL tracking both reuse (ST_AMB_APPLY/WAIT, ST_DCS_R_APPLY/WAIT, ST_DCS_IR_APPLY/WAIT), tagged by CTX_AMB_RECHECK_ORIGIN_BIT/CTX_DCS_REVALIDATE_ORIGIN_BIT so success/failure routes back to o_amb_sequence_done/failed and o_dcs_revalidate_done/failed instead of the startup-completion path. Two levels up, ppg_dynamic_baseline_cross_detector.v and ppg_coarse_detection_fir.v each carry a dedicated i_recheck_accept_event/i_recheck_busy/i_recheck_done_event/i_recheck_success port group (confirmed by direct RTL read, not a shared clear source with Group10's ILM discard mechanism): accept atomically clears FIR history counters (cnt_red_sample/cnt_ir_sample -> 0) and the cross detector's candidate/cycle/direction/previous-sample state, but structurally EXCLUDES reg_peak_context and slope_current_q16_o from every one of those clear lists (RRC-04) -- they are simply held constant through the whole busy window and reused verbatim on a successful resume (flag_resume_pending, RRC-09), while a real done-with-failure (i_recheck_done_event && !i_recheck_success) is the ONLY thing that invalidates them, reloading i_fixed_slope_q16 and asserting o_reacquire_active (RRC-11). ppg_control_top.v itself leaves the scheduler's own o_amb_recheck_pending/accept/busy/o_sequence_done/o_sequence_failed ports UNCONNECTED at the AMI instantiation site (empty parens) -- exactly like o_transaction_inflight/o_startup_search_complete before it, these must be read via hierarchical dot-path into ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst, not through any top-level port. Confirmed C_ENABLE_TEST_INJECTION is not needed for this group -- no RRC-01~12 clause requires identity-mismatch injection, so the DUT is instantiated with its production default (0), unlike Group6/SID-10.
//                                                             Test strategy, confirmed against real RTL before coding rather than assumed: since a real SAR9->15->9 round trip is unavoidable for every accepted cycle, this file reuses two full real recheck episodes inside ONE continuous SEARCH_TRACK+dual-optical RUN driven by the real physiological generator (tb_ppg_real_raw_generator.vh, same C_RAW_PROFILE_NORMAL/NOMINAL-weight setup already proven in Group6/7/the Stage4 baseline-cross file to produce a real first cross by roughly frame 60-65) -- amb_recheck_interval_frames is overridden to a small, test-friendly value (ACTIVE bits [591:576] are fully drivable through the normal COMMIT flow, no force needed) so the first interval genuinely expires before or during that first real cross, letting cycle 1 demonstrate the passive/organic path (RRC-01/02/03/04/05/06/08/09/10) with the naturally-converged, still-in-window AMB/DCS codes left over from an earlier fixed-RAW startup-search phase. Cycle 2 reuses a second, later real cross (the same long-run generator config repeatedly produces multiple real PEAK/VALLEY/CROSS cycles per the project's own Group5 LONG-10-CYCLES evidence, so a second natural round trip is expected within the same continuous run) but this time actively overrides the calibration-frame driving during the busy window: AMB is deliberately driven toward a target outside the confirm window to force a genuine confirmed-excursion re-search that converges to a NEW code (RRC-07, using exactly Group6's already-proven task_drive_amb_toward_target convergence loop against the shared bisection states), then DC_R is deliberately driven to keep evaluating as an unbroken one-directional excursion (task_drive_dcs_toward_target with an unreachable target so it always requests 'increase') until the search genuinely exhausts against its own configured code_max, producing a real RRC-11 failure with real reacquire/fixed-slope-reload evidence. A third, separate, short RUN using plain fixed-RAW driving (no generator at all, same (100,200)/8/503/150 convention as Group6/7) demonstrates RRC-12 cheaply: since a fixed, unvarying in-window drive value never produces a real baseline excursion, the system never leaves SAR9, i_precision_15_to_9_event never fires, and pending can be observed sitting indefinitely before STOP clears it with no code update -- confirmed as a genuine, legitimate consequence of the same RTL gate, not a constructed shortcut.
// 2026/08/29            V1.1          Erie                  Got a real, fully-passing run -- five real issues found and fixed, one of them in DUT RTL (a genuine bug against the module's own contract, not a design gray area). All five recorded here because at least three are directly reusable for future Stage 5 files. (1) Real Xilinx xvlog compile (not just iverilog) failed with "identifier 'reg_owner_snapshot_color_ir' is used before its declaration": xvlog/xelab enforce lexical declaration-before-use for module-level regs referenced inside task bodies, stricter than iverilog's two-pass parsing which silently tolerated the forward reference -- task_drive_color_value was declared before the reg_owner_snapshot_* block. Fixed by moving the owner-snapshot reg declarations + their capture always-block to right after the two `include` lines, before any task references them; this is a real, generalizable Xilinx-vs-iverilog compile-order gotcha worth checking proactively in any future file, not just when it bites. (2) Episode 1's very first driving loop (waiting for the real SAR9->15->9 round trip) was originally bounded by `!flag_recheck_done_seen && !flag_recheck_failed_seen` and drove any incidental calibration transaction with `make_fixed_raw(0,...)` (clamped to 8, below_low) -- a leftover placeholder pattern copied from Group7's phase C, which was safe there only because that file's startup search was already fully separate and done before its own equivalent loop began. In this file, the loop legitimately overruns into the recheck's own busy window (the loop's exit condition was wrong -- it should stop at the return event, not wait for done/failed), so the very first real AMB-recheck evaluation sample could get driven below_low instead of a neutral in-window value, corrupting the "clean in-window" RRC-06 setup. Fixed by changing the loop's exit condition to `!flag_return_9bit_seen` and its calibration branch to a neutral `make_fixed_raw(150,...)`, and applied the same neutral-value fix to two later loops (the RRC-09 21-sample warmup wait and the RRC-10 next-cross wait) that had copied the same now-dead `raw=0` branch defensively. (3) A deeper, genuinely important design bug in episode 2's original three-part structure (a "wait for second accept" loop, then a separate AMB candidate loop, then a separate DC_R candidate loop): `flag_takeover_safe` (and therefore accept) can only become true when the system is genuinely idle, so the very first real Q3 window after accept fires is guaranteed to be the recheck's own first AMB evaluation -- meaning that transaction is always consumed by whichever iteration of the "wait for accept" loop happens to be in-flight at that moment, using that loop's own (neutral, in-window) driving logic, not the AMB-family driving logic in the loop meant to come after it. Since ST_AMB_RECHECK immediately succeeds on an in-window sample with zero escalation, this raced away the entire RRC-07/RRC-11 forced-excursion design every single run, silently and without any error -- only caught by actually reasoning through the exact real-idle timing precondition for accept, not by re-reading the contract text. Fixed by merging all three phases into one continuous loop that reads the real `state_current` on every calibration transaction and picks the correct driving task (AMB-family -> `task_drive_amb_toward_target(...,180)`, DC_R-family -> `task_drive_dcs_toward_target(...,999)`) regardless of which iteration happens to catch the first post-accept transaction, eliminating the race structurally instead of trying to time around it. This is a generalizable lesson for any future Stage 5 file that needs to actively override driving starting from an event that can only fire while the DUT is idle: do not split "wait for the event" and "drive differently once past it" into two loops with different driving logic, because the very first real transaction after the event is not guaranteed to land in the second loop. (4) With (1)-(3) fixed, RRC-02/03 still failed for real under xsim: `flag_takeover_safe`'s `i_frame_safe_boundary` component only pulses once per completed 400 Hz macro frame (`ppg_400hz_frame_calibration_scheduler.v` line 458, `macro_frame_safe_boundary_o = ... && (macro_tick_o==MACRO_SAFE_TICK)`), i.e. once per 5000 `i_clk` cycles at this project's 2 MHz/400 Hz ratio -- the same `>5000 cycles` scale already recorded in [[feedback_tb_counter_scope_and_stop_boundary]] Lesson 5 for a different reason (a coasting post-STOP macro frame), but this is a second, independent place the same scale bites: a passive `@(posedge i_clk)` wait for a real recheck accept after the return event needs a guard of at least one full macro-frame period, not an arbitrary round number like 2000. Widened the guard from 2000 to 12000 cycles. (5) The real, important one: even after (1)-(4), RUN 2's COMMIT genuinely and reproducibly failed with `o_start_ready=0`/`o_system_fault_blocking=1`/`o_controller_fault_blocking=1` stuck indefinitely after a full STOP+drain+`i_diag_clear_event` sequence following episode 2's deliberate DC_R exhaustion (RRC-11). Traced this to a real cross-module deadlock in `ppg_idac_code_controller.v` (not a TB bug): the three FAULT bits driving `o_controller_fault_blocking` were cleared only inside the `i_start_ack_event` block, but `o_controller_fault_blocking` itself (via AMI's `o_ami_fault_active` -> the system fault supervisor's episode-close condition -> config_manager's `flag_start_ready`) is exactly what blocks a fresh `i_start_ack_event` from ever being generated -- a genuine circular deadlock, confirmed for real in xsim, not just traced on paper. Verified against `PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` section 11.3 (line 546) and conformance ID IDC2-23 (line 662) before touching any RTL: the contract explicitly requires these FAULT bits to clear via STOP/abort + idle + root-cause-gone (or async reset), and explicitly forbids clearing them via a fresh START -- the RTL had this exactly backwards. Fixed in `ppg_idac_code_controller.v` V2.2->V2.3 (see that file's own changelog for the full fix and verification, including a real byte-for-byte A/B diff of its own unit-level TB proving zero behavior change outside this exact scenario). After all five fixes: real Vivado 2022.2 xsim run (~10 minutes, two full real recheck episodes plus a third fixed-RAW RUN, matching this project's own established "large-scale/long-run -> xsim, not iverilog" guidance), `JNT_BASELINE 53/53 PASS`, all twelve RRC-01~12 IDs pass with real evidence, `PERIODIC_RECHECK_RECOVERY_TB_PASS result_captures=2821 owner_commit_total=2906`.
// 2026/10/05            V1.2          Erie                  ABCD review F-041: RRC-01 now requires the pending to expire exactly at the configured interval (30 completed real NORMAL macro frames) instead of only checking that pending ever appeared; the PASS text is unchanged. Negative control: AMB recheck interval compare shifted by one frame fails RRC-01.
// 2026/10/08            V1.3          Erie                  ABCD review F-009 (coordinator review item 3): add a print-only macro-frame interval monitor. A frame start is recognised when a frame is active at tick 0 and the previous cycle was inactive or at tick 4999 (this also catches CAL rollover, which has no start pulse); the first frame after START is logged as F009_FRAME_FIRST, and every later start whose distance from the previous start is not 5000 cycles prints F009_FRAME_GAP with the interval, the idle cycles and the previous/next frame type (NORMAL/CAL). It never prints PASS or FAIL and does not touch the verdict.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月28日
// 设计名称:           PPG周期重检恢复测试平台
// 模块名称:           tb_ppg_control_top_periodic_recheck_recovery
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_amb_recheck_scheduler.v
//                      ppg_idac_code_controller.v
//                      ppg_dynamic_baseline_cross_detector.v
//                      ppg_coarse_detection_fir.v
//                      PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.3
// 修订日期:           2026年10月08日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月28日        V1.0          Erie                  创建文件。Stage 5第8组（PERIODIC-RECHECK-RECOVERY，C25合同9.4.3节，RRC-01~12）。这是在Group6（启动搜索）/Group7（NORMAL跟踪）已经使用过的同一对`ppg_idac_code_controller.v`/`ppg_amb_recheck_scheduler.v`之上叠加的一套全新机制：`ppg_amb_recheck_scheduler.v`统计已完成的NORMAL宏帧数（`i_normal_frame_complete_event`，受`flag_period_enabled`门控，该门控本身要求`i_startup_search_complete`——直接证实了批次规划里"Group6先于Group8"这条依赖）对比ACTIVE给出的`i_amb_recheck_interval_frames`（`[591:576]`位），锁存pending，只有`flag_takeover_safe`（ADC/fork/IDAC/FIR/峰谷检测器空闲加帧安全边界）成立且真实观察到过一次`i_precision_15_to_9_event`才真正接管（安全接管NORMAL）——直接读RTL确认这个"返回9-bit"门禁并不区分"pending到来时是否已经在SAR15里"：`ST_MONITOR`自己的下一状态逻辑要求`i_precision_15_to_9_event`才能离开`ST_MONITOR`/`ST_WAIT_SWITCH`，这意味着一次真实的SAR9→15→9往返是每一次真正被接受的重检周期的硬性前提，不只是RRC-02这一条特定场景才需要。一旦接管，`ppg_idac_code_controller.v`通过三个全新专属状态（`ST_AMB_RECHECK=9`、`ST_DCS_REVALIDATE_WAIT=10`、`ST_DCS_REVALIDATE_R=11`、`ST_DCS_REVALIDATE_IR=12`）先评价已经提交在案的当前码（不产生新候选）——窗口内立即结束该阶段且码/epoch不变（RRC-06），确认的同方向漂移（复用Group6/7已经在用的cnt_amb_high/cnt_amb_low确认计数机制）则升级进入启动搜索和NORMAL跟踪共用的同一套二分搜索状态（`ST_AMB_APPLY/WAIT`、`ST_DCS_R_APPLY/WAIT`、`ST_DCS_IR_APPLY/WAIT`），用`CTX_AMB_RECHECK_ORIGIN_BIT`/`CTX_DCS_REVALIDATE_ORIGIN_BIT`打标签，让成功/失败改走`o_amb_sequence_done/failed`和`o_dcs_revalidate_done/failed`而不是启动完成路径。再往上两层，`ppg_dynamic_baseline_cross_detector.v`和`ppg_coarse_detection_fir.v`各自带一组专属的`i_recheck_accept_event`/`i_recheck_busy`/`i_recheck_done_event`/`i_recheck_success`端口（直接读RTL确认，不是和Group10的ILM discard共用的清除源）：accept会原子清除FIR历史计数器（`cnt_red_sample`/`cnt_ir_sample`归零）和穿越检测器的候选/周期/方向/前一样本状态，但结构性地把`reg_peak_context`和`slope_current_q16_o`排除在所有这些清除列表之外（RRC-04）——它们在整个busy窗口期间原样保持，成功恢复后原样复用（`flag_resume_pending`，RRC-09），只有真正的失败结束（`i_recheck_done_event && !i_recheck_success`）才会作废它们，重新装载`i_fixed_slope_q16`并置位`o_reacquire_active`（RRC-11）。`ppg_control_top.v`自己在AMI实例化处把调度器的`o_amb_recheck_pending/accept/busy/o_sequence_done/o_sequence_failed`全部留空未接——和之前的`o_transaction_inflight`/`o_startup_search_complete`一样，必须走层次引用深入`ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst`，不存在任何顶层端口。确认本组不需要`C_ENABLE_TEST_INJECTION`——RRC-01~12没有一条要求身份错配注入，DUT按生产默认值（0）例化，和Group6/SID-10不同。
//                                                             动笔前核实过的测试策略：既然每一次真正被接受的重检都离不开一次真实的SAR9→15→9往返，本文件在同一次连续的SEARCH_TRACK+双光真实RUN里复用两轮完整重检episode，全程用真实生理生成器（`tb_ppg_real_raw_generator.vh`，Group6/7/Stage4穿越检测文件已经反复验证过的同一套C_RAW_PROFILE_NORMAL/幂次权重配置，历史证据显示第一次真实穿越大约在第60~65帧）驱动——`amb_recheck_interval_frames`覆盖成一个很小的、仿真内可行的测试值（ACTIVE`[591:576]`完全可以走正常COMMIT流程驱动，不需要force），让第一个间隔在第一次真实穿越之前或期间到期，第一轮episode演示被动/自然路径（RRC-01/02/03/04/05/06/08/09/10），用的是更早一个固定RAW驱动的启动搜索阶段留下的、仍然窗口内的AMB/DCS码。第二轮episode复用同一次长跑里的第二次真实穿越（同一套长跑生成器配置本来就会反复产生多轮真实PEAK/VALLEY/CROSS，本项目自己Group5 LONG-10-CYCLES的证据就是peak_count=20/valley_count=19/cross_count=9，所以同一次RUN里期待出现第二次真实往返是合理的），但这次在busy窗口期间主动介入驱动：故意把AMB驱动到确认窗口之外，强制一次真实的确认漂移重搜并收敛到一个新码（RRC-07，直接复用Group6已经验证过的`task_drive_amb_toward_target`收敛循环，作用在共用的二分搜索状态上），随后把DC_R持续驱动成一个不会转向的单方向漂移（`task_drive_dcs_toward_target`配一个不可达目标，让它永远请求"increase"）直到搜索在自己配置的`code_max`边界真实耗尽，产生一次真实的RRC-11失败及真实的reacquire/固定斜率重装证据。第三个独立的、更短的RUN只用固定RAW驱动（不用生成器，沿用Group6/7同一套(100,200)/8/503/150惯例）廉价演示RRC-12：固定不变的窗口内驱动值永远不会产生真实的基线漂移，系统永远不会离开SAR9，`i_precision_15_to_9_event`永远不会真实触发，可以直接观察pending无限期悬挂直到STOP把它清零且不产生任何码更新——这是同一条RTL门禁的真实、合法后果，不是刻意构造的取巧手法。
// 2026年08月29日        V1.1          Erie                  真正跑通一次完整PASS，一共发现并修复了五个真实问题，其中一个在DUT RTL自己身上（是违反模块自己合同的真实bug，不是架构灰色地带），全部记录在这里，因为至少三个可以直接复用到未来的Stage5文件。（1）真实Xilinx xvlog编译（不只是iverilog）报错"identifier 'reg_owner_snapshot_color_ir' is used before its declaration"：xvlog/xelab对同一模块内标识符要求严格的"先声明后使用"词法顺序，比iverilog两遍解析式的宽松容忍更严格——本文件`task_drive_color_value`的声明位置早于`reg_owner_snapshot_*`那组reg的声明。修复为把owner快照reg声明+捕获always块整体挪到两条`` `include``之后、任何引用它们的task之前——这是一个真实的、可以推广的Xilinx-vs-iverilog编译顺序陷阱，值得未来每份新文件动笔时主动核查，不是等真的踩上才发现。（2）episode1第一个驱动循环（等待真实SAR9→15→9往返）第一版用`!flag_recheck_done_seen && !flag_recheck_failed_seen`做循环边界，校准分支用`make_fixed_raw(0,...)`（钳制成8，below_low）——这是照抄Group7阶段C的占位手法，那份文件之所以安全是因为它自己的启动搜索早在同类循环开始前就已经独立跑完。本文件里这个循环会真实越过真实回落事件、一路越入周期重检自己的busy窗口（根因是循环退出条件本身写错了——该在回落事件停，不该等done/failed），于是第一笔真实AMB重检评价样本可能被驱动成below_low而不是窗口内中性值，污染RRC-06要求的"纯窗口内"前提。修复为把循环退出条件改成`!flag_return_9bit_seen`，校准分支改成中性的`make_fixed_raw(150,...)`，并把同一个已死的`raw=0`分支同样修正到后面两处循环（RRC-09的21笔预热等待、RRC-10的下一次穿越等待）里防御性抄来的同款代码。（3）episode2原来的三段式结构（一个"等第二次accept"循环，然后分开的AMB候选循环，再分开的DC_R候选循环）藏着一个更重要的真实设计bug：`flag_takeover_safe`（进而accept）只能在系统真正idle时才成立，这意味着accept之后的第一个真实Q3窗口必然就是周期重检自己对当前AMB码的首次评价——也就是说这笔事务必然会被"等accept"循环自己当时正在阻塞的那次迭代吃掉，用的是那个循环自己的（中性、窗口内）驱动逻辑，而不是本该在它之后才生效的AMB专属驱动逻辑。由于`ST_AMB_RECHECK`一遇到窗口内样本就立即成功、完全不升级，这会让RRC-07/RRC-11的强制漂移设计每次都被悄悄绕过、不报任何错误——这条bug只有真正推演清楚"accept只能在真实idle时触发"这个时序前提才能发现，不是把合同文字读得更细就能看出来的。修复为把三个阶段合并成一个连续循环，每笔真实校准事务都先读真实`state_current`再决定用哪个驱动task（AMB族→`task_drive_amb_toward_target(...,180)`，DC_R族→`task_drive_dcs_toward_target(...,999)`），不管accept后第一笔事务被哪次迭代接住都能正确处理，从结构上消除这个竞争，而不是试图掐时间点绕开它。这是一条可以推广的教训：未来任何Stage5文件如果需要在"只能在DUT idle时才触发的事件"之后主动改变驱动策略，不要把"等事件"和"事件后改驱动"拆成两个用不同驱动逻辑的循环——事件后的第一笔真实事务不保证落在第二个循环里。（4）修完（1）~（3），RRC-02/03在真实xsim下仍然真实FAIL：`flag_takeover_safe`里的`i_frame_safe_boundary`分量真实只在完整400Hz宏帧的那一拍脉冲一次（`ppg_400hz_frame_calibration_scheduler.v` 458行，`macro_frame_safe_boundary_o = ... && (macro_tick_o==MACRO_SAFE_TICK)`），本项目2MHz/400Hz比例下就是5000个`i_clk`拍——和[[feedback_tb_counter_scope_and_stop_boundary]] Lesson 5已经记录过的">5000拍"这同一个量级，但这次是完全独立的另一处踩坑：真实回落事件之后被动`@(posedge i_clk)`等待一次真实重检accept，等待窗口至少要留够一整个宏帧周期，不能是2000这种拍脑袋的整数。把guard从2000拍放宽到12000拍。（5）真正重要的一条：修完（1）~（4）之后，episode2故意逼出DC_R搜索耗尽（RRC-11）之后，RUN2的COMMIT在完整STOP+drain+`i_diag_clear_event`之后依然真实、可复现地卡在`o_start_ready=0`/`o_system_fault_blocking=1`/`o_controller_fault_blocking=1`永久不变——追查到这是`ppg_idac_code_controller.v`自己的一个真实跨模块死锁（不是TB的bug）：驱动`o_controller_fault_blocking`的三个FAULT位只在`i_start_ack_event`那一拍清零，但`o_controller_fault_blocking`本身（经AMI的`o_ami_fault_active`→系统故障supervisor的episode关闭判据→config_manager的`flag_start_ready`）恰好就是挡住新`i_start_ack_event`生成的那个信号——一个真实的循环死锁，真实xsim confirmed，不是纸面推演。动手改RTL前先核对了`PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` 11.3节（546行）和一致性条款IDC2-23（662行）：合同明确要求这些FAULT位靠STOP/abort+idle+根因消失来撤销（或异步复位），并明确禁止靠新START清除——RTL原实现正好做反了。已在`ppg_idac_code_controller.v` V2.2→V2.3里修复（完整修复过程和验证见该文件自己的changelog，包含对它自己单元级TB的一次真实逐字节A/B diff，证明这个改动在死锁场景之外零行为变化）。五处修复全部落地后：真实Vivado 2022.2 xsim跑通（约10分钟，含两轮完整真实重检episode加一个固定RAW的RUN，符合本项目"大规模/长跑场景用xsim不用iverilog"的既定惯例），`JNT_BASELINE 53/53 PASS`，全部十二条RRC-01~12都拿到真实证据通过，`PERIODIC_RECHECK_RECOVERY_TB_PASS result_captures=2821 owner_commit_total=2906`。
// 2026年10月05日        V1.2          Erie                  ABCD复核F-041：RRC-01改为要求pending恰好在配置间隔（30个真实完成的NORMAL宏帧）到期，不再只要求pending出现过；PASS文字不变。负对照：AMB重检间隔比较提前一帧时RRC-01失败。
// 2026年10月08日        V1.3          Erie                  ABCD复核F-009（统筹审核第3项）：新增只打印的宏帧间隔监视器。以"帧在tick 0处于活动且上一拍不活动或处于末拍4999"识别宏帧起点（含无起点脉冲的校准滚动）；START后第一帧记为F009_FRAME_FIRST，此后凡与上一起点相距不等于5000拍即打印F009_FRAME_GAP，给出间隔、空闲拍数和前后帧类型（NORMAL/CAL）。不打印PASS/FAIL，不影响结论
//
// 复位后依次跑一个连续的SEARCH_TRACK生成器RUN（含两轮真实周期重检episode）
// 和一个独立的固定RAW驱动RUN，核对周期重检调度器的间隔计数、SAR15阻塞、
// 安全排空接管、FIR/穿越检测器清除与保留、AMB/DC码序列、成功与失败恢复路径
module tb_ppg_control_top_periodic_recheck_recovery();

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
	localparam [4:0] ST_IDAC_AMB_RECHECK = 5'd9; // idac控制器周期检查当前AMB码
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_WAIT = 5'd10; // idac控制器保持DCS重验证请求
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_R = 5'd11; // idac控制器检查当前红光DC码
	localparam [4:0] ST_IDAC_DCS_REVALIDATE_IR = 5'd12; // idac控制器检查当前红外DC码

	localparam integer C_CANDIDATE_GUARD_MAX = 12; // 单阶段候选步数安全上限，8位码空间理论最多8步
	localparam integer C_GENERATOR_FRAME_GUARD = 2000; // 单轮真实穿越/回落搜寻的驱动帧数上限
	localparam time C_SIM_TIMEOUT_NS = 64'd7000000000; // 7秒安全看门狗上限，本组含两轮真实生成器长跑

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
			.C_RUN_GENERATION_WIDTH(C_RUN_GENERATION_WIDTH)
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
			// 同Group6/7已经确立的惯例：阈值窗口整体搬到make_fixed_raw合法值域[8,503]
			// 内部（100,200），below_low(8)/above_high(503)/in_window(150)三种分类
			// 都是纯正数，不受钳位影响
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

	//---------------阶段A/B专用：SEARCH_TRACK+双光+真实生成器阈值，覆盖短周期重检间隔---------------//
	// dcs_threshold_high放宽到400，覆盖生成器真实幅度范围，同Group7的
	// task_build_search_track_generator_config；amb_recheck_interval_frames
	// 覆盖到一个仿真内可行的小值，让第一个间隔在生成器真实第一次穿越前后到期
	task task_build_recheck_generator_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH
			i_source_config_snapshot[151:140] = 12'sd400; // dcs_threshold_high，放宽覆盖生成器真实幅度范围
			i_source_config_snapshot[591:576] = 16'd30; // amb_recheck_interval_frames，缩短到30帧
		end
	endtask

	//---------------阶段C专用：SEARCH_TRACK+双光+固定RAW驱动，专供RRC-12---------------//
	// 极短间隔配合固定不变驱动值：固定驱动永远不产生真实基线漂移，系统永远不会
	// 离开SAR9，i_precision_15_to_9_event永远不会真实触发，pending只能悬挂
	task task_build_recheck_fixed_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH
			i_source_config_snapshot[591:576] = 16'd2; // amb_recheck_interval_frames，极短间隔
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
				$display("FAIL RRC config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------排空回CONFIG任务---------------//
	// 同Group7已验证过的STOP后冲刷手法：STOP接受时若恰好有owner在途，调度器只
	// 把它标成B_INFLIGHT_DISCARD受控丢弃，B_INFLIGHT本身要等一次真实完成才清零
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
				$display("FAIL RRC drain to CONFIG timeout stop_ack_seen=%b cnt_stop_wait=%0d idac_state=%0d sched_inflight=%b",
					o_stop_ack_event, cnt_stop_wait,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]);
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
					$display("FAIL RRC Q3 wait timeout");
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
	`include "tb_ppg_real_raw_generator.vh"

	//---------------真实owner身份快照进程---------------//
	// commit那一拍锁存身份，真实DONE到达时才使用，同Group7已验证手法。放在
	// task_drive_color_value之前声明——xvlog/xelab对同一模块内标识符要求先声明
	// 后使用，比iverilog的两遍解析更严格，第一版声明顺序放在后面导致真实
	// xvlog编译报"used before its declaration"，iverilog没有报出这个问题
	reg reg_owner_snapshot_is_calibration;
	reg reg_owner_snapshot_color_ir;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_owner_snapshot_frame_id;
	reg reg_owner_snapshot_precision;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			reg_owner_snapshot_is_calibration <= (ppg_control_top_Inst.sched_adc_owner_frame_type_o != 2'b10); // FRAME_TYPE_NORMAL=2'b10，其余编码均为校准类
			reg_owner_snapshot_color_ir <= ppg_control_top_Inst.sched_adc_owner_color_ir_o;
			reg_owner_snapshot_frame_id <= ppg_control_top_Inst.sched_adc_owner_frame_id_o;
			reg_owner_snapshot_precision <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
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
	// 提取自Group6已验证过的AMB/DC_R/DC_IR三阶段二分搜索收敛循环，供本文件的
	// 每一个独立RUN在进入NORMAL/周期重检场景前共用
	task task_run_startup_search;
		reg real_release;
		reg [7:0] reg_current_amb_code, reg_current_dcs_r_code, reg_current_dcs_ir_code;
		integer cnt_wait_request;
		begin
			begin : rrc_startup_amb_stage
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
					$display("FAIL RRC startup AMB stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : rrc_startup_dcs_r_stage
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
					$display("FAIL RRC startup DC_R stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : rrc_startup_dcs_ir_stage
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
					$display("FAIL RRC startup DC_IR stage did not converge");
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
				$display("FAIL RRC startup_search_complete never asserted after convergence");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end
	endtask

	//---------------真实驱动一笔明确颜色、明确目标校准值的NORMAL跟踪事务---------------//
	// 同Group7已验证手法：双光NORMAL调度不保证严格RED/IR交替，用真实owner身份
	// 快照逐笔核对颜色，非目标颜色的真实事务驱动中性in-window值放行
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
	integer cnt_owner_commit_total_rrc;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			cnt_owner_commit_total_rrc <= cnt_owner_commit_total_rrc + 1;
		end
	end

	//---------------RRC-01专用：完整NORMAL宏帧完成与周期计数器同步捕获进程---------------//
	// 直接对照调度器自己的cnt_normal_frame_o和真实宏帧完成脉冲，同一个always块
	// 里同时统计owner提交次数（每帧双色两笔），确认间隔计数器只按宏帧递增，不
	// 按ADC结果/owner提交递增
	integer cnt_real_macro_frame_complete;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_normal_frame_complete_event_o) begin
			cnt_real_macro_frame_complete <= cnt_real_macro_frame_complete + 1;
		end
	end

	//---------------RRC-02/09专用：真实精度切换/回落事件连续后台捕获进程---------------//
	// 同Group7已验证过的连续always块+sticky捕获模式，绝不在多拍阻塞调用之后
	// 做单点内联轮询
	reg flag_fine_window_seen;
	reg flag_return_9bit_seen;
	always @(posedge i_clk) begin
		if(!flag_fine_window_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_fine_window_start_event) begin
			flag_fine_window_seen <= 1'b1;
		end
		if(flag_fine_window_seen && !flag_return_9bit_seen &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_9bit_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_return_9bit_ready) begin
			flag_return_9bit_seen <= 1'b1;
		end
	end

	//---------------RRC-03/04/05/06/07/08/09/11专用：周期重检episode连续后台捕获进程---------------//
	// accept/done/failed都是单拍脉冲，绝不能在多拍阻塞调用之后单点轮询——用sticky
	// 寄存器持续捕获，主序列消费后自己复位供下一轮episode重新武装
	reg flag_recheck_accept_seen;
	reg flag_recheck_accept_takeover_safe_ok;
	reg flag_recheck_done_seen;
	reg flag_recheck_failed_seen;
	reg [C_FRAME_ID_WIDTH - 1:0] reg_recheck_accept_time_dummy;
	reg [63:0] t_enter_amb_family, t_enter_dcsr_family, t_enter_dcsir_family;
	reg flag_recheck_busy_prev;
	always @(posedge i_clk) begin
		if(!flag_recheck_busy_prev && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_busy) begin
			t_enter_amb_family <= 64'd0;
			t_enter_dcsr_family <= 64'd0;
			t_enter_dcsir_family <= 64'd0;
		end
		flag_recheck_busy_prev <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_busy;
		if(!flag_recheck_accept_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_accept) begin
			flag_recheck_accept_seen <= 1'b1;
			flag_recheck_accept_takeover_safe_ok <= ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.flag_takeover_safe;
		end
		if(!flag_recheck_done_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_sequence_done) begin
			flag_recheck_done_seen <= 1'b1;
		end
		if(!flag_recheck_failed_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_sequence_failed) begin
			flag_recheck_failed_seen <= 1'b1;
		end
		if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_RECHECK ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_APPLY ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_WAIT) &&
			(t_enter_amb_family == 64'd0)) begin
			t_enter_amb_family <= $time;
		end
		if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_WAIT ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_R ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_APPLY ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_WAIT) &&
			(t_enter_dcsr_family == 64'd0)) begin
			t_enter_dcsr_family <= $time;
		end
		if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_IR ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_APPLY ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_IR_WAIT) &&
			(t_enter_dcsir_family == 64'd0)) begin
			t_enter_dcsir_family <= $time;
		end
	end

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL PERIODIC_RECHECK_RECOVERY global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	initial begin : main_sequence
		reg real_release;
		reg [9:0] raw_target_code;
		reg [7:0] reg_snap_amb_code, reg_snap_dcs_r_code, reg_snap_dcs_ir_code;
		reg [C_CODE_EPOCH_WIDTH - 1:0] reg_snap_amb_epoch, reg_snap_dcs_r_epoch, reg_snap_dcs_ir_epoch;
		reg [79:0] reg_snap_peak_context;
		reg signed [31:0] reg_snap_slope_q16;
		integer cnt_frame_before_pending;
		integer cnt_owner_before, cnt_result_before;
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		cnt_owner_commit_total_rrc = 0;
		cnt_real_macro_frame_complete = 0;
		flag_fine_window_seen = 1'b0;
		flag_return_9bit_seen = 1'b0;
		flag_recheck_accept_seen = 1'b0;
		flag_recheck_accept_takeover_safe_ok = 1'b0;
		flag_recheck_done_seen = 1'b0;
		flag_recheck_failed_seen = 1'b0;
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

		//=========== RUN 1：生成器驱动，含两轮真实周期重检episode ===========//
		task_build_recheck_generator_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL RRC RUN1 commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;

		//------- Episode 1：被动/自然路径，RRC-01/02/03/04/05/06/08/09/10 -------//
		begin : rrc_episode1
			integer cnt_frame_drive;
			reg [9:0] target_code_gen;
			integer raw_unclamped_dummy;
			reg flag_pending_before_fine_window;
			reg flag_fir_cleared_at_accept;
			integer cnt_fir_wait;
			integer cnt_amb_family_ok, cnt_dcsr_family_ok;

			cnt_real_macro_frame_complete = 0; // 从NORMAL真正开始的这一刻起统计，之前的启动搜索不计入宏帧
			flag_pending_before_fine_window = 1'b0;
			flag_fine_window_seen = 1'b0;
			flag_return_9bit_seen = 1'b0;
			flag_recheck_accept_seen = 1'b0;
			flag_recheck_done_seen = 1'b0;
			flag_recheck_failed_seen = 1'b0;

			// 循环边界只到真实回落事件为止（不是done/failed）——若accept碰巧在回落
			// 事件的同一拍或紧接着几拍内就绪，本循环仍可能在下一次迭代里遇到一笔
			// 真实校准请求，所以校准分支统一驱动150（窗口内中性值），不能沿用
			// Group7阶段C那种raw=0占位（那份文件的校准分支只在task_run_startup_
			// search自己的循环内使用，从不会和周期重检的AMB/DC真实评价请求重叠；
			// 本文件这里如果误用raw=0会把恰好撞上的第一笔真实AMB/DC重检评价样本
			// 驱动成below_low，污染RRC-06要求的"纯窗口内"结论）
			for(cnt_frame_drive = 0; (cnt_frame_drive < C_GENERATOR_FRAME_GUARD) && !flag_return_9bit_seen && !flag_global_timeout; cnt_frame_drive = cnt_frame_drive + 1) begin
				wait_q3_release(real_release);
				if(real_release) begin
					if(reg_owner_snapshot_is_calibration) begin
						make_fixed_raw(150, raw_target_code);
						drive_real_adc_done(1'b0, raw_target_code, raw_target_code);
					end else begin
						task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_owner_snapshot_color_ir,
							{16'd0, reg_owner_snapshot_frame_id}, target_code_gen, raw_unclamped_dummy);
						make_fixed_raw(target_code_gen, raw_target_code);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_target_code, raw_target_code);
					end
				end
				//---- RRC-02：记录pending是否在第一次真实进入精细窗口之前就已经到期 ----//
				if(!flag_fine_window_seen &&
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending &&
					!flag_pending_before_fine_window) begin
					flag_pending_before_fine_window = 1'b1;
					cnt_frame_before_pending = cnt_real_macro_frame_complete;
				end
				//---- RRC-02：pending悬挂期间，只要还没看到真实回落事件，AMB/DC码/epoch和busy都不能变 ----//
				if(flag_pending_before_fine_window && !flag_return_9bit_seen) begin
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_busy) begin
						$display("FAIL RRC-02 recheck busy asserted before a real SAR15->SAR9 return event was observed");
						cnt_error = cnt_error + 1;
					end
				end
			end

			if(!flag_pending_before_fine_window) begin
				$display("FAIL RRC-01 recheck pending never asserted within %0d driven frames -- interval/frame-count check is vacuous", cnt_frame_drive);
				cnt_error = cnt_error + 1;
			end else if(cnt_frame_before_pending != 30) begin
				// ABCD F-041：C16按完整NORMAL宏帧计数，配置间隔30时pending必须恰好在第30个真实完成帧到期，
				// 提前或延后都是计数来源/间隔错误，不能只要求pending出现过
				$display("FAIL RRC-01 recheck pending asserted after %0d completed real NORMAL macro frames, expected exactly the configured interval 30", cnt_frame_before_pending);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-01 recheck pending asserted after %0d completed real NORMAL macro frames (configured interval=30, counted by real sched_normal_frame_complete_event_o pulses, not by ADC/owner-commit events)", cnt_frame_before_pending);
			end

			if(!flag_fine_window_seen) begin
				$display("FAIL RRC episode1 no real SAR9->SAR15 transition observed within %0d driven frames -- RRC-02/03/04/05/06/08/09/10 are vacuous", cnt_frame_drive);
				cnt_error = cnt_error + 1;
				$finish;
			end
			if(!flag_return_9bit_seen) begin
				$display("FAIL RRC-02 real SAR15->SAR9 return never observed after entry");
				cnt_error = cnt_error + 1;
				$finish;
			end
			if(!flag_pending_before_fine_window) begin
				$display("FAIL RRC-02 check is vacuous: pending never armed before the real precision transition, cannot demonstrate the SAR15 block");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-02 recheck pending held through the real SAR9->SAR15->SAR9 round trip with no calibration activity/code change, only accepted after the real return event");
			end

			//---- RRC-03：episode真正accept时必须观察到flag_takeover_safe为真 ----//
			// flag_takeover_safe里的i_frame_safe_boundary分量真实只在宏帧的
			// MACRO_SAFE_TICK那一拍脉冲一次（ppg_400hz_frame_calibration_
			// scheduler.v 458行：macro_frame_safe_boundary_o = state_current
			// [B_FRAME_ACTIVE] && flag_lifecycle_active && (macro_tick_o ==
			// MACRO_SAFE_TICK)），周期是一整个宏帧（本项目2MHz/400Hz比例下
			// 5000个i_clk）——第一版这里只等2000拍，真实xsim confirmed FAIL
			// （accept真的没在2000拍内出现），和本项目已确立的"任何在STOP/
			// COMMIT序列附近检查idle类信号都要留够>5000拍宏帧结算窗口"惯例
			// （feedback_tb_counter_scope_and_stop_boundary Lesson 5）是同一类
			// 问题，只是这次不是STOP场景，是真实回落事件之后等待下一个安全边界。
			// 改成两个宏帧周期再加余量
			cnt_frame_drive = 0;
			while(!flag_recheck_accept_seen && (cnt_frame_drive < 12000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_frame_drive = cnt_frame_drive + 1;
			end
			if(!flag_recheck_accept_seen) begin
				$display("FAIL RRC episode1 accept never fired after the real return event -- RRC-03/04/05/06/08/09/10 are vacuous");
				cnt_error = cnt_error + 1;
				$finish;
			end else if(!flag_recheck_accept_takeover_safe_ok) begin
				$display("FAIL RRC-03 accept fired without flag_takeover_safe (ADC/fork/IDAC/FIR/peak-valley idle + frame safe boundary) actually being true");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-03 accept only fired once ADC/NORMAL-fork/IDAC/FIR/peak-valley/frame-boundary drain condition was genuinely true");
			end

			//---- RRC-04：accept那一拍立即快照peak anchor/slope，随后busy期间必须原样不变 ----//
			reg_snap_peak_context = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.reg_peak_context;
			reg_snap_slope_q16 = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.slope_current_q16_o;
			reg_snap_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
			reg_snap_amb_epoch = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current;
			cnt_owner_before = cnt_owner_commit_total_rrc;
			cnt_result_before = cnt_result_capture;

			cnt_fir_wait = 0;
			while(((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.cnt_red_sample != 5'd0) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.cnt_ir_sample != 5'd0)) &&
				(cnt_fir_wait < 16) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_fir_wait = cnt_fir_wait + 1;
			end
			flag_fir_cleared_at_accept =
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.cnt_red_sample == 5'd0) &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.cnt_ir_sample == 5'd0);
			if(!flag_fir_cleared_at_accept) begin
				$display("FAIL RRC-04 FIR RED/IR history depth counters not cleared shortly after real recheck accept");
				cnt_error = cnt_error + 1;
			end

			//---- 驱动整个busy窗口直到done/failed，期间持续核对peak/slope未被扰动、无正式输出 ----//
			for(cnt_frame_drive = 0; (cnt_frame_drive < C_GENERATOR_FRAME_GUARD) && !flag_recheck_done_seen && !flag_recheck_failed_seen && !flag_global_timeout; cnt_frame_drive = cnt_frame_drive + 1) begin
				wait_q3_release(real_release);
				if(real_release) begin
					make_fixed_raw(150, raw_target_code); // 校准帧固定in_window驱动，episode1不主动构造漂移
					drive_real_adc_done(1'b0, raw_target_code, raw_target_code);
				end
				if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.reg_peak_context !== reg_snap_peak_context) ||
					(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.slope_current_q16_o !== reg_snap_slope_q16)) begin
					$display("FAIL RRC-04 peak anchor/slope disturbed during recheck busy window at frame=%0d", cnt_frame_drive);
					cnt_error = cnt_error + 1;
				end
			end
			if(!flag_recheck_done_seen && !flag_recheck_failed_seen) begin
				$display("FAIL RRC episode1 never reached sequence done/failed within %0d driven candidates", cnt_frame_drive);
				cnt_error = cnt_error + 1;
				$finish;
			end
			if(flag_recheck_failed_seen) begin
				$display("FAIL RRC episode1 unexpectedly failed (in-window driving should have succeeded cleanly)");
				cnt_error = cnt_error + 1;
				$finish;
			end
			$display("PASS RRC-04 peak anchor/slope held identical throughout the whole real recheck busy window while FIR RED/IR history was cleared");

			//---- RRC-05/RRC-06：AMB先于DC_R先于DC_IR、AMB窗口内未变但DC仍被重验证 ----//
			cnt_amb_family_ok = (t_enter_amb_family != 64'd0) ? 1 : 0;
			cnt_dcsr_family_ok = ((t_enter_dcsr_family != 64'd0) && (t_enter_dcsr_family > t_enter_amb_family)) ? 1 : 0;
			if(!cnt_amb_family_ok || !cnt_dcsr_family_ok || (t_enter_dcsir_family == 64'd0) || (t_enter_dcsir_family <= t_enter_dcsr_family)) begin
				$display("FAIL RRC-05 recheck stage order was not strictly AMB then DC_R then DC_IR: t_amb=%0t t_dcsr=%0t t_dcsir=%0t", t_enter_amb_family, t_enter_dcsr_family, t_enter_dcsir_family);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-05 real recheck sequence visited AMB, then DC_R, then DC_IR, strictly in that order");
			end
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current != reg_snap_amb_epoch) begin
				$display("FAIL RRC-06 AMB epoch changed even though episode1 drove a clean in-window value, expected the code/epoch to be preserved");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-06 in-window AMB check preserved code/epoch while the state trace still visited DC_R/DC_IR revalidation");
			end

			//---- RRC-08：整个busy窗口期间没有产生任何正式测量结果 ----//
			if(cnt_result_capture != cnt_result_before) begin
				$display("FAIL RRC-08 a formal measurement result was produced during the recheck busy window");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-08 formal NORMAL output stayed inhibited for the entire recheck busy window");
			end

			//---- RRC-09：成功恢复后peak/slope仍等于accept时快照，且RED/IR各自独立累计21笔新样本 ----//
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.reg_peak_context !== reg_snap_peak_context) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.slope_current_q16_o !== reg_snap_slope_q16)) begin
				$display("FAIL RRC-09 peak anchor/slope not identical to their pre-accept snapshot immediately after a successful recheck resume");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-09 peak anchor/slope reused verbatim from the pre-accept snapshot for the resumed baseline");
			end

			cnt_frame_drive = 0;
			while(((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.o_history_full_r == 1'b0) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.o_history_full_ir == 1'b0)) &&
				(cnt_frame_drive < C_GENERATOR_FRAME_GUARD) && !flag_global_timeout) begin
				wait_q3_release(real_release);
				if(real_release) begin
					if(reg_owner_snapshot_is_calibration) begin
						make_fixed_raw(150, raw_target_code); // 窗口内中性值，避免恰好撞上真实校准评价请求时误判成below_low
						drive_real_adc_done(1'b0, raw_target_code, raw_target_code);
					end else begin
						task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_owner_snapshot_color_ir,
							{16'd0, reg_owner_snapshot_frame_id}, target_code_gen, raw_unclamped_dummy);
						make_fixed_raw(target_code_gen, raw_target_code);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_target_code, raw_target_code);
					end
				end
				cnt_frame_drive = cnt_frame_drive + 1;
			end
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.o_history_full_r == 1'b0) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_coarse_detection_fir_Inst.o_history_full_ir == 1'b0)) begin
				$display("FAIL RRC-09 RED/IR FIR history never reached the full 21-sample warmup after resume within %0d driven frames", cnt_frame_drive);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-09 RED and IR each independently accumulated 21 new real qualified NORMAL samples after resume before FIR output qualification returned");
			end

			//---- RRC-10：继续驱动生成器直到形成一次新的真实上穿并进入SAR15 ----//
			flag_fine_window_seen = 1'b0;
			flag_return_9bit_seen = 1'b0;
			for(cnt_frame_drive = 0; (cnt_frame_drive < C_GENERATOR_FRAME_GUARD) && !flag_fine_window_seen && !flag_global_timeout; cnt_frame_drive = cnt_frame_drive + 1) begin
				wait_q3_release(real_release);
				if(real_release) begin
					if(reg_owner_snapshot_is_calibration) begin
						make_fixed_raw(150, raw_target_code); // 窗口内中性值，避免恰好撞上真实校准评价请求时误判成below_low
						drive_real_adc_done(1'b0, raw_target_code, raw_target_code);
					end else begin
						task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_owner_snapshot_color_ir,
							{16'd0, reg_owner_snapshot_frame_id}, target_code_gen, raw_unclamped_dummy);
						make_fixed_raw(target_code_gen, raw_target_code);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_target_code, raw_target_code);
					end
				end
			end
			if(!flag_fine_window_seen) begin
				$display("FAIL RRC-10 no new real upward cross entering SAR15 was formed after resume within %0d driven frames", cnt_frame_drive);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-10 a new real upward cross was formed from fresh post-resume history and entered SAR15 through the normal safe-boundary path");
			end
			if(!flag_return_9bit_seen) begin
				cnt_frame_drive = 0;
				while(!flag_return_9bit_seen && (cnt_frame_drive < C_GENERATOR_FRAME_GUARD) && !flag_global_timeout) begin
					wait_q3_release(real_release);
					if(real_release) begin
						task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_owner_snapshot_color_ir,
							{16'd0, reg_owner_snapshot_frame_id}, target_code_gen, raw_unclamped_dummy);
						make_fixed_raw(target_code_gen, raw_target_code);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_target_code, raw_target_code);
					end
					cnt_frame_drive = cnt_frame_drive + 1;
				end
			end
		end

		//------- Episode 2：主动构造AMB确认漂移+成功重收敛，DC_R确认漂移+真实耗尽 -------//
		begin : rrc_episode2
			integer cnt_frame_drive;
			reg [9:0] target_code_gen;
			integer raw_unclamped_dummy;
			reg [7:0] reg_pre_amb_code;
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_pre_amb_epoch;
			reg [7:0] reg_current_amb_code, reg_current_dcs_r_code;
			integer cnt_wait_request;
			reg flag_amb_family_left;
			reg flag_dcsr_exhausted;

			flag_recheck_accept_seen = 1'b0;
			flag_recheck_done_seen = 1'b0;
			flag_recheck_failed_seen = 1'b0;
			cnt_real_macro_frame_complete = 0;

			// AMB码在pending悬挂期间不会变化（尚未accept），此刻快照的pre-value对
			// 后面RRC-07的"真的改了码/epoch"判断始终有效
			reg_pre_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
			reg_pre_amb_epoch = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current;
			flag_amb_family_left = 1'b0;
			flag_dcsr_exhausted = 1'b0;

			// 用一个统一循环覆盖"等待第二轮accept"+"强制AMB确认漂移收敛"+"强制DC_R
			// 单方向漂移耗尽"三个阶段，而不是分成三个独立循环——第一版分成三段，
			// 中间那段专门等accept的循环用中性150驱动任何校准请求，真实分析发现
			// 这是一个真实的竞争bug：accept只会在系统真正idle时触发（flag_takeover_
			// safe要求ADC/fork等全部空闲），所以accept生效后的下一个真实Q3窗口就是
			// 周期重检自己对当前AMB码的评价请求，恰好会被"等accept"循环自己正在
			// 阻塞的wait_q3_release调用接住，用150（窗口内）去驱动它——这会让AMB
			// 评价当场in-window直接成功，永远走不到RRC-07想要的确认漂移路径。改成
			// 单一循环、每次都先读真实state_current再决定驱动哪个方向，彻底消除
			// 这个"哪次迭代恰好接住第一笔校准请求"的竞争
			for(cnt_frame_drive = 0; (cnt_frame_drive < C_GENERATOR_FRAME_GUARD) && !flag_dcsr_exhausted && !flag_global_timeout; cnt_frame_drive = cnt_frame_drive + 1) begin
				wait_q3_release(real_release);
				if(real_release) begin
					if(reg_owner_snapshot_is_calibration) begin
						if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_RECHECK) ||
							(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_APPLY) ||
							(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_AMB_WAIT)) begin
							reg_current_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
							task_drive_amb_toward_target(reg_current_amb_code, 180); // 强制确认漂移直到收敛到180
						end else if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_WAIT) ||
							(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_R) ||
							(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_APPLY) ||
							(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_R_WAIT)) begin
							reg_current_dcs_r_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
							task_drive_dcs_toward_target(reg_current_dcs_r_code, 999); // 999不可达，永远评价below_low强制increase，逼迫码走到code_max耗尽
						end else begin
							make_fixed_raw(150, raw_target_code); // 尚未接管/其它未预期阶段，安全中性值
							drive_real_adc_done(1'b0, raw_target_code, raw_target_code);
						end
					end else begin
						task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, reg_owner_snapshot_color_ir,
							{16'd0, reg_owner_snapshot_frame_id}, target_code_gen, raw_unclamped_dummy);
						make_fixed_raw(target_code_gen, raw_target_code);
						drive_real_adc_done(reg_owner_snapshot_precision, raw_target_code, raw_target_code);
					end
				end
				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_accept) begin
					flag_recheck_accept_seen = 1'b1; // 冗余捕获，主要依赖背景sticky进程，这里只做本地日志用途
				end
				if(!flag_amb_family_left && ((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_WAIT) ||
					(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == ST_IDAC_DCS_REVALIDATE_R))) begin
					flag_amb_family_left = 1'b1;
				end
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_fault) begin
					$display("FAIL RRC-07 AMB search unexpectedly exhausted while converging to an in-range target");
					cnt_error = cnt_error + 1;
					$finish;
				end
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_fault) begin
					flag_dcsr_exhausted = 1'b1;
				end
			end
			if(!flag_recheck_accept_seen) begin
				$display("FAIL RRC episode2 never reached a second real recheck accept within %0d driven frames -- RRC-07/RRC-11 are vacuous", cnt_frame_drive);
				cnt_error = cnt_error + 1;
				$finish;
			end
			if(!flag_amb_family_left) begin
				$display("FAIL RRC-07 AMB confirmed-excursion re-search never completed within the driving guard");
				cnt_error = cnt_error + 1;
				$finish;
			end
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current == reg_pre_amb_epoch) begin
				$display("FAIL RRC-07 AMB epoch did not increment despite a real confirmed-excursion re-search and code change");
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code == reg_pre_amb_code) begin
				$display("FAIL RRC-07 AMB committed code did not actually change despite a real confirmed excursion");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-07 a real confirmed AMB excursion triggered a full re-search that committed a new code (%0d -> %0d) with epoch bump only at the safe boundary",
					reg_pre_amb_code, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code);
			end
			if(!flag_dcsr_exhausted) begin
				$display("FAIL RRC-11 DC_R search never reached exhaustion under a persistent one-directional excursion");
				cnt_error = cnt_error + 1;
				$finish;
			end
			cnt_wait_request = 0;
			while(!flag_recheck_failed_seen && (cnt_wait_request < 2000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_request = cnt_wait_request + 1;
			end
			if(!flag_recheck_failed_seen) begin
				$display("FAIL RRC-11 o_sequence_failed never propagated to the scheduler after DC_R exhaustion");
				cnt_error = cnt_error + 1;
			end else if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_controller_fault_blocking) begin
				$display("FAIL RRC-11 controller_fault_blocking not asserted after DC_R exhaustion");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-11 a real one-directional DC_R excursion drove the search to genuine exhaustion, asserting failed/fault and blocking formal NORMAL");
			end

			//---- RRC-11：失败必须废止旧peak anchor、重装固定斜率、置位reacquire ----//
			cnt_wait_request = 0;
			while((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.slope_current_q16_o != -32'sd65536) &&
				(cnt_wait_request < 16) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_request = cnt_wait_request + 1;
			end
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.slope_current_q16_o != -32'sd65536) begin
				$display("FAIL RRC-11 slope not reloaded to the configured fixed_slope_q16 (-65536) after a failed recheck");
				cnt_error = cnt_error + 1;
			end else if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_reacquire_active) begin
				$display("FAIL RRC-11 o_reacquire_active not asserted after a failed recheck");
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.baseline_valid_o) begin
				$display("FAIL RRC-11 stale baseline_valid still asserted after a failed recheck invalidated the old anchor");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-11 failed recheck invalidated the old baseline anchor, reloaded the configured fixed slope, and entered reacquire");
			end

			//---- RRC-11：确认阻断故障期间NORMAL不会通过陈旧状态重新开放 ----//
			cnt_owner_before = cnt_owner_commit_total_rrc;
			repeat(3000) @(posedge i_clk);
			if(cnt_owner_commit_total_rrc != cnt_owner_before) begin
				$display("FAIL RRC-11 a real owner commit occurred despite DC_R exhaustion blocking formal NORMAL");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-11 formal NORMAL stayed blocked for 3000 cycles after the recheck failure, no reopening through stale state");
			end
		end

		task_stop_and_drain;
		// DC_R耗尽会置位error_sticky/o_system_fault_blocking（同Group6 SID-10已
		// 确立的模式），STOP排空回CONFIG本身不会清掉它，必须显式脉冲
		// i_diag_clear_event，否则下面RUN2的COMMIT会被这个遗留sticky挡住
		@(negedge i_clk);
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		repeat(4) @(posedge i_clk);

		//=========== RUN 2：固定RAW驱动，专供RRC-12 ===========//
		task_build_recheck_fixed_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL RRC RUN2 commit commit_ack=%b error_event=%b last_error_code=%h error_sticky=%b start_ready=%b lifecycle=%0d system_fault_blocking=%b amb_fault=%b dcs_r_fault=%b dcs_ir_fault=%b ctrl_fault_blocking=%b",
				o_commit_ack_event, o_error_event, o_last_error_code, o_error_sticky, o_start_ready, o_lifecycle_state, o_system_fault_blocking,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_fault,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_fault,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_fault,
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_controller_fault_blocking);
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		task_run_startup_search;

		begin : rrc_episode3_stop_clears_pending
			integer cnt_wait_pending;
			reg [7:0] reg_pre_stop_amb_code, reg_pre_stop_dcs_r_code, reg_pre_stop_dcs_ir_code;
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_pre_stop_amb_epoch;
			integer cnt_guard_cycles;

			flag_recheck_accept_seen = 1'b0;
			flag_recheck_done_seen = 1'b0;
			flag_recheck_failed_seen = 1'b0;

			//---- 固定in_window驱动持续推进真实NORMAL帧，直到pending真实到期 ----//
			cnt_wait_pending = 0;
			while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending &&
				(cnt_wait_pending < 4000) && !flag_global_timeout) begin
				task_drive_color_value(1'b0, 150);
				task_drive_color_value(1'b1, 150);
				cnt_wait_pending = cnt_wait_pending + 1;
			end
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending) begin
				$display("FAIL RRC-12 recheck pending never asserted under fixed in-window driving -- RRC-12 check is vacuous");
				cnt_error = cnt_error + 1;
				$finish;
			end

			reg_pre_stop_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
			reg_pre_stop_amb_epoch = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current;
			reg_pre_stop_dcs_r_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
			reg_pre_stop_dcs_ir_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code;

			//---- 继续固定驱动一段时间，确认pending悬挂期间既不accept也不动码（永远等不到真实回落事件）----//
			cnt_guard_cycles = 0;
			while((cnt_guard_cycles < 400) && !flag_recheck_accept_seen && !flag_global_timeout) begin
				task_drive_color_value(1'b0, 150);
				task_drive_color_value(1'b1, 150);
				cnt_guard_cycles = cnt_guard_cycles + 1;
			end
			if(flag_recheck_accept_seen) begin
				$display("FAIL RRC-12 setup invalid: recheck unexpectedly accepted under fixed unvarying driving (a real SAR9->SAR15->SAR9 round trip should never occur here)");
				cnt_error = cnt_error + 1;
				$finish;
			end
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code != reg_pre_stop_amb_code) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current != reg_pre_stop_amb_epoch) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != reg_pre_stop_dcs_r_code) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code != reg_pre_stop_dcs_ir_code)) begin
				$display("FAIL RRC-12 AMB/DC code changed while recheck pending was genuinely stuck waiting for a return event that never occurred");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-12 recheck pending stayed stuck (no accept, no code change) for %0d cycles while genuinely waiting for a real SAR15->SAR9 return event that never occurred under fixed driving", cnt_guard_cycles);
			end

			//---- STOP必须立刻清pending，且不产生任何码更新；在途owner走正常受控释放（task_stop_and_drain已验证）----//
			task_stop_and_drain;
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_amb_recheck_scheduler_Inst.o_amb_recheck_pending) begin
				$display("FAIL RRC-12 recheck pending still asserted after STOP+drain completed");
				cnt_error = cnt_error + 1;
			end else if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code != reg_pre_stop_amb_code) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.amb_epoch_current != reg_pre_stop_amb_epoch)) begin
				$display("FAIL RRC-12 AMB code/epoch changed by STOP clearing a pending recheck request");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS RRC-12 STOP cleared the pending recheck request with no code update; the already-drained in-flight owner (if any) followed the normal controlled-release rule via task_stop_and_drain");
			end
		end

		if(cnt_error == 0) begin
			$display("PERIODIC_RECHECK_RECOVERY_TB_PASS result_captures=%0d owner_commit_total=%0d", cnt_result_capture, cnt_owner_commit_total_rrc);
		end else begin
			$display("PERIODIC_RECHECK_RECOVERY_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end


	//---------------ABCD F-009：宏帧间隔监视（只打印，不产生PASS/FAIL，不影响结论）---------------//
	// 以"帧在tick 0处于活动且上一拍不活动或上一拍处于末拍4999"识别每个宏帧起点（含校准滚动），START后第一帧只记起点；
	// 凡相邻起点间隔不等于5000拍即打印一行F009_FRAME_GAP：间隔、空闲拍数、前后帧类型（NORMAL/CAL）
	integer f009_cycle;                             // 监视器自有2 MHz拍计数
	integer f009_last_start;                        // 上一宏帧起点拍号，-1表示START后尚无
	integer f009_gap_count;                         // 已打印的非5000间隔数
	integer f009_frame_count;                       // 已识别的宏帧起点数
	reg f009_prev_active;                           // 上一拍是否有活动宏帧
	reg [12:0] f009_prev_tick;                      // 上一拍宏帧tick
	reg f009_last_cal;                              // 上一宏帧是否为校准帧
	initial begin
		f009_cycle = 0;
		f009_last_start = -1;
		f009_gap_count = 0;
		f009_frame_count = 0;
		f009_prev_active = 1'b0;
		f009_prev_tick = 13'd0;
		f009_last_cal = 1'b0;
	end
	always @(posedge i_clk) begin
		f009_cycle = f009_cycle + 1;
		if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_start_ack_event) begin
			f009_last_start = -1;
		end else if((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_normal_frame_active || ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active) && (ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_macro_tick == 13'd0) &&
			(!f009_prev_active || (f009_prev_tick == 13'd4999))) begin
			f009_frame_count = f009_frame_count + 1;
			if(f009_last_start < 0) begin
				$display("F009_FRAME_FIRST t=%0t frame=%0d type=%0s", $time, ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_current_frame_id, ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active ? "CAL" : "NORMAL");
			end else if((f009_cycle - f009_last_start) != 5000) begin
				f009_gap_count = f009_gap_count + 1;
				$display("F009_FRAME_GAP t=%0t frame=%0d interval=%0d idle=%0d prev=%0s next=%0s gaps=%0d frames=%0d", $time, ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_current_frame_id,
					f009_cycle - f009_last_start, f009_cycle - f009_last_start - 5000, f009_last_cal ? "CAL" : "NORMAL",
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active ? "CAL" : "NORMAL", f009_gap_count, f009_frame_count);
			end
			f009_last_start = f009_cycle;
			f009_last_cal = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active;
		end
		f009_prev_active = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_normal_frame_active || ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_calibration_frame_active;
		f009_prev_tick = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_macro_tick;
	end

endmodule
