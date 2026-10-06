`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/27
// Design Name:        PPG Input Light Static Matrix Testbench
// Module Name:        tb_ppg_control_top_input_light_static_matrix
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_SYSTEM_CONFIG_MANAGER interface/semantic contracts
//                      PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.2
// Revision Date:      2026/10/05
// History:
//    Time               Version       Revised by            Contents
// 2026/08/27            V1.0          Erie                  Create file. Stage 5 Group 10 (INPUT-LIGHT-STATIC-MATRIX,
//                                                             C25 contract section 9.4.5), scoped down by user decision after
//                                                             re-verifying every ILM-01..15 acceptance clause directly against the
//                                                             contract table and real RTL (not copied from the prior session's
//                                                             prediction unchecked): ILM-01~10 and ILM-13~15 (thirteen IDs) are
//                                                             covered here; ILM-11/12 (AMB_CAL/DCS_CAL) are deferred, matching
//                                                             Group 12's own precedent, because `ppg_idac_code_controller.v`'s FSM
//                                                             confirms `ST_MANUAL_APPLY` (idac_mode=MANUAL) transitions only to
//                                                             `ST_NORMAL` on the first safe boundary and never visits
//                                                             `ST_AMB_APPLY`/`ST_AMB_WAIT`/any DCS state, so MANUAL mode cannot
//                                                             structurally produce an AMB_CAL/DCS_CAL transaction; those two IDs
//                                                             need Group 6 (startup search) or Group 8 (periodic recheck), neither
//                                                             built yet. Reuses the real-2MHz-clock/JNT-01~09-prefix/
//                                                             wait_q3_release/drive_real_adc_done/make_fixed_raw infrastructure and
//                                                             the JNT-prefix-required standard config task names verbatim from
//                                                             tb_ppg_control_top_idac_bus_isolation.v (Group 12), which itself
//                                                             copied them from tb_ppg_control_top_adc_numeric_scoreboard.v
//                                                             (Group 11) -- dropping both files' numeric golden-model tasks
//                                                             entirely since this group only checks EN_TEST/LEDEN/LEDDAC/S[4:0]/
//                                                             owner-color identity and the config-manager's static legality gate,
//                                                             never a recomputed measurement value. Follows Group 11/12's
//                                                             manual-per-transaction driving style (a bounded for-loop of
//                                                             wait_q3_release + drive_real_adc_done per phase) rather than
//                                                             Group 1~5's persistent bg_responder, since every ILM phase drives a
//                                                             small, exactly-known transaction count and does not need a
//                                                             free-running background process or tb_ppg_jnt_baseline_prefix.vh's
//                                                             flag_jnt_manual_adc_hold coordination gate that only Group 1~5's
//                                                             persistent-responder files require.
//                                                             Legality matrix independently re-derived from
//                                                             ppg_system_config_manager.v (not assumed from memory): CHARACTERIZATION
//                                                             + PHOTODIODE requires optical_mode=RED_ONLY exactly
//                                                             (flag_snapshot_char_photodiode_optical_valid); CHARACTERIZATION +
//                                                             EXTERNAL_TEST_CURRENT (non-STATIC_BIAS) allows all of BOTH/RED_ONLY/
//                                                             IR_ONLY and only rejects the 2'b11 "safe-off" optical_mode encoding
//                                                             (flag_snapshot_char_current_optical_valid, ERROR_FIXED_CURRENT_
//                                                             OPTICAL_MODE=8'h16) -- this is what ILM-08's "EXTERNAL_TEST_CURRENT
//                                                             OFF" actually means; input_source itself is a single bit
//                                                             (PHOTODIODE=0/EXTERNAL_TEST_CURRENT=1), not a three-valued field, so
//                                                             the earlier working assumption that ILM-08 tested a third
//                                                             input_source value was wrong and corrected before writing any code.
//                                                             CHARACTERIZATION allows either initial_precision regardless of
//                                                             input_source/optical_mode (flag_snapshot_profile_precision_valid),
//                                                             so ILM-05/06/07's SAR15 variants are all legal, not just BOTH's.
//                                                             A config_update_event outside ST_CONFIG is unconditionally rejected
//                                                             with ERROR_COMMIT_STATE=8'h02 (line ~470 of the config manager) --
//                                                             this is the exact structural mechanism behind ILM-10's "changes
//                                                             during an accepted transaction may affect only a later legal
//                                                             RUN/snapshot" clause, not a separate ad-hoc latch to go find.
//                                                             ILM-15's negative case is built to land the rejection while still in
//                                                             ST_CONFIG (never reaching READY) by committing static_
//                                                             characterization_enable=1 through the independent CDC path first
//                                                             (confirmed lifecycle-independent while i_run_enable=0, i.e. any time
//                                                             outside ST_RUN, per ppg_characterization_control_cdc.v's
//                                                             flag_destination_control_accept) and only then attempting a
//                                                             CHARACTERIZATION+PHOTODIODE V4 commit, which trips
//                                                             flag_snapshot_static_bias_valid at COMMIT time
//                                                             (ERROR_STATIC_BIAS_INPUT_SOURCE=8'h14) and leaves state_current
//                                                             sitting in ST_CONFIG by the FSM's own default-hold semantics --
//                                                             deliberately avoiding the alternative rejected-at-START path, which
//                                                             would strand the run in ST_READY forever (ppg_system_config_
//                                                             manager.v's ST_READY case has no transition back to ST_CONFIG other
//                                                             than through ST_RUN/ST_STOPPING).
//                                                             ILM-09 (MANUAL-only, no automatic search/tracking/recheck the whole
//                                                             run) is proved as one continuous whole-simulation monitor reading
//                                                             ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.
//                                                             ppg_idac_code_controller_Inst.state_current and asserting it only
//                                                             ever takes ST_IDLE(0)/ST_MANUAL_APPLY(1)/ST_NORMAL(8), never any
//                                                             AMB/DCS/RECHECK/REVALIDATE state -- this is a hierarchy-direct proof,
//                                                             not an inference from absence of AMB_CAL/DCS_CAL transactions.
//                                                             Fourteen phases total in one JNT-prefixed run, in this order after
//                                                             the JNT-01~09 baseline: Phase ILM-15 (STATIC_BIAS invalid-source
//                                                             rejection, kept first because it must stay in CONFIG and never
//                                                             progress the lifecycle) -> Phase ILM-01 (PHOTODIODE NORMAL dual-color,
//                                                             3 RED/IR pairs) -> Phase ILM-02 (PHOTODIODE RED_ONLY SAR9
//                                                             characterization, 3 RED transactions) -> Phase ILM-03 (same at
//                                                             SAR15, with a continuous B_FRAME_PRECISION monitor proving no
//                                                             precision-window transition) -> Phase ILM-10 (PHOTODIODE NORMAL
//                                                             dual-color RUN, a rejected mid-RUN reconfigure attempt to
//                                                             EXTERNAL_TEST_CURRENT+BOTH+SAR9 while confirming the active
//                                                             transaction is unaffected, then a real STOP/drain/re-COMMIT/START of
//                                                             that exact same config proving it only takes effect on the next
//                                                             legal RUN) -> Phase ILM-04 (fresh EXTERNAL_TEST_CURRENT BOTH SAR9,
//                                                             3 pairs) -> Phase ILM-05 (same at SAR15) -> Phase ILM-06
//                                                             (EXTERNAL_TEST_CURRENT RED_ONLY, one SAR9 sub-phase and one SAR15
//                                                             sub-phase, IR owner-commit count frozen throughout both) -> Phase
//                                                             ILM-07 (mirror of ILM-06 for IR_ONLY, RED owner-commit count frozen)
//                                                             -> Phase ILM-08 (EXTERNAL_TEST_CURRENT with optical_mode=2'b11
//                                                             "OFF", rejected at COMMIT, no waveform/owner/LED/frame/sample side
//                                                             effect) -> Phase ILM-13/14 (legal STATIC_BIAS, reusing
//                                                             tb_ppg_control_top.v's SMOKE-19 pattern almost verbatim: the 25-signal
//                                                             frozen netlist static vector, S[4:0] exact match plus one-clock
//                                                             atomic runtime update, and a sustained no-real-ADC-owner/idle-
//                                                             Scheduler-AMI-SSW window).
//                                                             Getting the first clean run took five real bug fixes, all in this
//                                                             file's own design, none in RTL: (1) Phase ILM-15's first draft checked
//                                                             o_characterization_control_valid immediately after
//                                                             task_commit_static_bias_characterization returned, with no wait --
//                                                             but that signal reflects the destination (2 MHz) domain's own accept
//                                                             state after crossing the CDC bridge from the source domain, which
//                                                             takes a few extra i_clk cycles to settle; the immediate check read a
//                                                             stale 0 and reported a false FAIL even though the CDC genuinely
//                                                             accepted moments later -- fixed by adding the same
//                                                             wait-up-to-200-cycles loop already used correctly in the ILM-13/14
//                                                             phase. (2) Every phase driving an exact transaction count (ILM-01/02/
//                                                             03/06/07/10) originally snapshotted cnt_owner_commit_red/ir *after*
//                                                             task_pulse_start's repeat(8)-cycle settle window, the same ordering
//                                                             convention this project's own tb_ppg_control_top.v used before its
//                                                             SMOKE-23 fix -- but RED's context takes over almost the instant
//                                                             START fires, so that settle window can already contain RED's first
//                                                             real owner commit (and that transaction's Q3 window can still be
//                                                             open at the exact snapshot instant), making the loop's first
//                                                             wait_q3_release call catch that already-counted transaction's
//                                                             residual Q3 tail instead of a fresh rising edge and silently
//                                                             under-count by exactly one (ILM-02/03 first exposed this as an exact
//                                                             "expected 3 observed 2" mismatch). Fixed by moving every baseline
//                                                             snapshot to immediately before task_pulse_start, mirroring
//                                                             SMOKE-23's own fix verbatim. (3) Phase ILM-10's mid-RUN rejection
//                                                             check read the live o_error_event signal right after a `fork...join`
//                                                             whose other branch (a 40-cycle continuous LEDEN/LEDDAC monitor) runs
//                                                             far longer than the single-i_source_clk-edge-wide error pulse --  by
//                                                             the time join completed the pulse had long since deasserted, so the
//                                                             live read always saw 0 even though the rejection genuinely happened
//                                                             (o_last_error_code was correctly latched to 0x02 the whole time).
//                                                             Fixed by latching a "saw the error" flag plus the error code inside
//                                                             the same 40-cycle monitor loop instead of reading the live signal
//                                                             after the fork completed. (4) The same ILM-10 phase's final leg
//                                                             re-committed EXTERNAL_TEST_CURRENT+BOTH, ran only repeat(8) settle
//                                                             cycles, then called task_pulse_stop immediately -- OPTICAL_BOTH's RED
//                                                             context takes over at tick 0 same as PHOTODIODE NORMAL, so a real
//                                                             owner was already committed and in flight with no completion ever
//                                                             driven for it; STOPPING's controlled release then waited forever for
//                                                             a real DONE that never came, timing out task_wait_drain_to_config
//                                                             and cascading into the next phase's COMMIT being rejected with
//                                                             ERROR_COMMIT_STATE because lifecycle never actually reached CONFIG.
//                                                             Fixed by driving two real transactions (covering both RED and IR)
//                                                             before that STOP, the same "drive a full pair before stopping"
//                                                             discipline ILM-01 already used. (5) Phase ILM-13/14's steady-state
//                                                             idle-window check initially failed with o_scheduler_idle stuck at 0
//                                                             from the very first checked cycle; direct hierarchical inspection of
//                                                             ppg_400hz_frame_calibration_scheduler_Inst showed B_FRAME_ACTIVE
//                                                             already 1 with macro_tick already around 500, not 0 -- proving this
//                                                             was not a frame this phase itself launched, but a leftover
//                                                             "coasting" macro frame from an earlier phase's plain STOP. Reading
//                                                             ppg_400hz_frame_calibration_scheduler.v's own V1.6 changelog and
//                                                             ppg_idac_code_controller.v line ~1125 confirmed why: a plain STOP
//                                                             deliberately leaves B_FRAME_ACTIVE untouched so any already-open
//                                                             window can drain naturally rather than being force-cleared (only
//                                                             i_control_abort_event forces it), while leaving RUN immediately
//                                                             revokes CTX_STARTUP_COMPLETE_BIT -- so that coasting frame produces
//                                                             zero real waveform/owner activity (i_normal_measurement_eligible is
//                                                             already 0) but still keeps ticking toward its own natural
//                                                             MACRO_LAST_TICK (5000 ticks total) entirely independently of every
//                                                             later phase's own STOP/COMMIT/START cycle, and lifecycle is allowed
//                                                             to reach CONFIG regardless since no new context/owner can form while
//                                                             it coasts. Fixed by adding a 5200-cycle settle wait (just over one
//                                                             full macro-frame period) before the idle-window check begins, giving
//                                                             any such leftover frame time to finish naturally; the substantive
//                                                             claim (zero real ADC owner commits during STATIC_BIAS) had already
//                                                             held throughout every debugging iteration regardless of this
//                                                             diagnostic-bit timing artifact. After all five fixes: real iverilog
//                                                             run, `-Wall` clean (only the two pre-existing unrelated
//                                                             ppg_dynamic_baseline_cross_detector.v warnings), JNT_BASELINE 53/53
//                                                             PASS, all thirteen "now" IDs pass with zero mismatches:
//                                                             `INPUT_LIGHT_STATIC_MATRIX_TB_PASS owner_commit_total=47
//                                                             static_vector_checks=3000`.
// 2026/08/29            V1.1          Erie                  Backfilled the deferred ILM-11/12 now that Group 6 (startup search) exists. Added the four missing pieces of infrastructure this file never needed before (all copied verbatim from Group 6/8/9's already-proven code, none new): `task_run_startup_search`, `task_drive_amb_toward_target`/`task_drive_dcs_toward_target`, and `wait_q3_release_and_sample` (samples LED/EN_TEST/bus state the instant Q3 first opens, same fix Group 6's own SID-03/04 already needed for the same reason). Added one dedicated `task_build_search_track_dual_config` overriding this file's own V1.0 `task_build_normal_manual_config` threshold fields to the (100,200)/8/503/150 convention explicitly, rather than inheriting the stale pre-Group7-fix cross-zero window it still carries -- same defensive fix as the sibling `tb_ppg_control_top_idac_bus_isolation.v` needed for the same reason, done proactively here before ever hitting the bug. The new phase reruns a real dual-optical SEARCH_TRACK startup search and reuses Group 6's own SID-07/08/09 assertions almost verbatim (PHOTODIODE+EN_TEST-low+both-LEDs-off+no-DC-window during AMB_CAL for ILM-11; dedicated-waveform+confirmed-AMB-code+single-color-LED-window during DCS_CAL RED/IR for ILM-12), producing this file's own real evidence rather than borrowing Group 6's. One real bug found and fixed, not in DUT RTL but a genuine scope conflict between this new phase and an existing V1.0 monitor: ILM-09's own continuous background monitor (`state_current` must stay in the small MANUAL-only state set) was written to span the *entire* simulation lifetime, which was a correct and harmless design when every V1.0 phase used `idac_mode=MANUAL` -- but the new SEARCH_TRACK phase legitimately enters `ST_DCS_IR_WAIT` and other real AMB/DCS states as part of its own valid behavior, and real xsim caught the resulting flood of false ILM-09 failures immediately. Fixed by adding a `flag_ilm09_monitor_active` flag (armed by default, matching the original whole-run intent) that main_sequence explicitly disarms right before committing the new SEARCH_TRACK phase's config, scoping ILM-09's claim back down to what it actually contractually covers (MANUAL mode's own behavior) instead of "state_current for the rest of time no matter what gets configured later." This is a reusable lesson for any future backfill that adds a new operating-mode phase to a file whose existing monitors were written assuming the file's original mode never changes. After the fix: real Vivado 2022.2 xsim run (~10 seconds), `JNT_BASELINE 53/53 PASS`, both ILM-11/12 pass with real evidence alongside all thirteen already-passing IDs, `INPUT_LIGHT_STATIC_MATRIX_TB_PASS owner_commit_total=69 static_vector_checks=3000`.
// 2026/10/05            V1.2          Erie                  ABCD review F-028: ILM-04/ILM-05 now monitor EN_TEST=1, LEDEN1/2=0 and LEDDAC=0 on every negedge for the whole fixed-current transaction loop (about 10,460 cycles each), instead of one sample per transaction taken before wait_q3_release; any violating cycle fails the case. An ILM_FIXED_CURRENT_MONITOR info line reports cycles/violations; PASS lines unchanged (73). Negative control: Top LEDDAC forced to 1 while EN_TEST and Q3 are active fails ILM-04 and ILM-05 (about 10,450 violating cycles each).
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月27日
// 设计名称:           PPG输入光路静态矩阵测试平台
// 模块名称:           tb_ppg_control_top_input_light_static_matrix
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_SYSTEM_CONFIG_MANAGER接口/语义合同
//                      PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.2
// 修订日期:           2026年10月05日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月27日        V1.0          Erie                  创建文件。Stage 5第10组（INPUT-LIGHT-STATIC-MATRIX，C25合同9.4.5节），
//                                                             开工前把ILM-01~15每一条子ID都重新对照合同表格原文和真实RTL逐条核实过
//                                                             （不是照抄上一轮会话的预判）：本文件做ILM-01~10加ILM-13~15共十三条；
//                                                             ILM-11/12（AMB_CAL/DCS_CAL）延后，与Group12的先例一致——
//                                                             `ppg_idac_code_controller.v`自己的状态机证实`ST_MANUAL_APPLY`
//                                                             （idac_mode=MANUAL）遇到首个安全边界只会跳到`ST_NORMAL`，从不经过
//                                                             `ST_AMB_APPLY`/`ST_AMB_WAIT`/任何DCS状态，MANUAL模式在结构上就不可能
//                                                             产生一笔AMB_CAL/DCS_CAL事务；这两条需要Group6（启动搜索）或Group8
//                                                             （周期复检），都还没做。原样复用`tb_ppg_control_top_idac_bus_
//                                                             isolation.v`（Group12，其本身又是从`tb_ppg_control_top_adc_numeric_
//                                                             scoreboard.v`即Group11复制而来）已验证过的真实2MHz时钟/JNT-01~09
//                                                             前缀/`wait_q3_release`/`drive_real_adc_done`/`make_fixed_raw`基础设施
//                                                             和JNT前缀内部要求的标准配置task名，完全去掉那两份文件的数值黄金模型
//                                                             task——本组只看EN_TEST/LEDEN/LEDDAC/S[4:0]/owner颜色身份和config
//                                                             manager的静态合法性门，从不重算测量值。沿用Group11/12"逐笔手动驱动"
//                                                             的风格（每个阶段用一个已知精确笔数的for循环调用`wait_q3_release`+
//                                                             `drive_real_adc_done`），不采用Group1~5的常驻bg_responder——本组每个
//                                                             阶段驱动的事务笔数都精确已知，不需要自由运行的后台进程，也不需要
//                                                             `tb_ppg_jnt_baseline_prefix.vh`那个只有Group1~5常驻responder才需要
//                                                             协调的`flag_jnt_manual_adc_hold`门控。
//                                                             合法组合矩阵独立重新核对自`ppg_system_config_manager.v`（不是凭记忆
//                                                             假设）：CHARACTERIZATION+PHOTODIODE必须optical_mode=RED_ONLY恰好一个
//                                                             值（`flag_snapshot_char_photodiode_optical_valid`）；CHARACTERIZATION+
//                                                             EXTERNAL_TEST_CURRENT（非STATIC_BIAS）下BOTH/RED_ONLY/IR_ONLY全部合法，
//                                                             只拒绝2'b11这个"安全关闭"编码（`flag_snapshot_char_current_optical_
//                                                             valid`，`ERROR_FIXED_CURRENT_OPTICAL_MODE`=8'h16）——这才是ILM-08
//                                                             "EXTERNAL_TEST_CURRENT OFF"的真实含义；input_source本身就是1个bit
//                                                             （PHOTODIODE=0/EXTERNAL_TEST_CURRENT=1），不是三值字段，此前"ILM-08在
//                                                             测input_source第三个值"这个工作假设是错的，写代码前已经订正。
//                                                             CHARACTERIZATION下两种initial_precision都合法，跟input_source/
//                                                             optical_mode无关（`flag_snapshot_profile_precision_valid`），所以
//                                                             ILM-05/06/07的SAR15变体全部合法，不只是BOTH那一个。非ST_CONFIG状态
//                                                             收到`config_update_event`无条件拒绝（`ERROR_COMMIT_STATE`=8'h02，
//                                                             config manager约470行）——这正是ILM-10"事务快照之后的改变只能影响
//                                                             下一次合法RUN/快照"背后的真实结构机制，不是另找了一个专门的临时latch。
//                                                             ILM-15的负向用例特意设计成让拒绝落在还停留ST_CONFIG（永远不到READY）
//                                                             的那条路径：先通过独立的CDC路径提交`static_characterization_
//                                                             enable=1`（已核实这条路径只要`i_run_enable=0`即ST_RUN之外任何状态都
//                                                             能接受，见`ppg_characterization_control_cdc.v`的`flag_destination_
//                                                             control_accept`），再尝试提交一份CHARACTERIZATION+PHOTODIODE的V4
//                                                             配置，在COMMIT那一刻触发`flag_snapshot_static_bias_valid`
//                                                             （`ERROR_STATIC_BIAS_INPUT_SOURCE`=8'h14），FSM默认保持语义让
//                                                             state_current停在ST_CONFIG——特意避开另一条"在START时才拒绝"的路径，
//                                                             那条路径会把仿真卡死在ST_READY里出不来（`ppg_system_config_
//                                                             manager.v`的ST_READY分支只有到ST_RUN一条跳转，没有直接回ST_CONFIG
//                                                             的路）。
//                                                             ILM-09（全程MANUAL、自动搜索/跟踪/复检全程不活动）用一个贯穿整个
//                                                             仿真的持续监视进程证明，直接层级读取`ppg_control_top_Inst.
//                                                             ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_
//                                                             Inst.state_current`，断言它全程只取ST_IDLE(0)/ST_MANUAL_APPLY(1)/
//                                                             ST_NORMAL(8)三个值，从不进入任何AMB/DCS/RECHECK/REVALIDATE状态——
//                                                             这是直接层级证据，不是"没看到AMB_CAL/DCS_CAL事务"这种反推。
//                                                             同一次JNT前缀运行里共十四个阶段，JNT-01~09基线之后依次是：阶段
//                                                             ILM-15（STATIC_BIAS非法输入源拒绝，放最前是因为它必须停在CONFIG、
//                                                             不能推进生命周期）→阶段ILM-01（PHOTODIODE NORMAL双光，3对RED/IR）
//                                                             →阶段ILM-02（PHOTODIODE RED_ONLY固定SAR9表征，3笔RED）→阶段ILM-03
//                                                             （同上但SAR15，配一个持续的B_FRAME_PRECISION监视进程证明无precision
//                                                             窗口切换）→阶段ILM-10（PHOTODIODE NORMAL双光RUN中，一次被拒绝的
//                                                             中途重配置尝试——改成EXTERNAL_TEST_CURRENT+BOTH+SAR9，确认当前
//                                                             事务不受影响，再真正STOP/排空/重新COMMIT/START同一份配置，证明
//                                                             它只在下一次合法RUN才生效）→阶段ILM-04（全新EXTERNAL_TEST_CURRENT
//                                                             BOTH SAR9，3对）→阶段ILM-05（同上SAR15）→阶段ILM-06
//                                                             （EXTERNAL_TEST_CURRENT RED_ONLY，SAR9+SAR15各一个子阶段，全程IR
//                                                             owner提交计数冻结）→阶段ILM-07（ILM-06的IR_ONLY镜像，全程RED
//                                                             owner提交计数冻结）→阶段ILM-08（EXTERNAL_TEST_CURRENT+
//                                                             optical_mode=2'b11"安全关闭"，COMMIT即被拒绝，无波形/owner/LED/
//                                                             帧/样本副作用）→阶段ILM-13/14（合法STATIC_BIAS，近乎原样复用
//                                                             `tb_ppg_control_top.v`的SMOKE-19模式：25个netlist静态向量信号逐位
//                                                             冻结、S[4:0]精确匹配加一拍原子运行期更新、以及一段持续的
//                                                             无真实ADC owner/Scheduler-AMI-SSW保持idle窗口）。
//                                                             为拿到第一次真实跑通证据，本轮一共发现并修复了五个真实问题，全部是
//                                                             本文件自己的设计问题，不是RTL：（1）阶段ILM-15第一版在
//                                                             `task_commit_static_bias_characterization`返回后立即检查
//                                                             `o_characterization_control_valid`，没有任何等待——但这个信号反映
//                                                             的是目标域（2MHz）自己跨过CDC桥之后的接受状态，需要再等几拍才会
//                                                             稳定，立即检查读到的是尚未更新的0，误报FAIL，其实CDC稍后确实正常
//                                                             接受了——修复为补上ILM-13/14阶段本来就用对的"最多等200拍"循环。
//                                                             （2）每一个要求精确笔数的阶段（ILM-01/02/03/06/07/10）最初都在
//                                                             `task_pulse_start`的repeat(8)拍settle窗口*之后*才给
//                                                             `cnt_owner_commit_red`/`ir`拍快照，这和本项目`tb_ppg_control_top.v`
//                                                             自己SMOKE-23修复前用的是同一种顺序——但RED context几乎在START那一拍
//                                                             就接管，这个settle窗口本身就可能已经包含了RED第一笔真实owner提交
//                                                             （而且那笔事务的Q3窗口在快照那一刻可能还没关闭），导致循环第一次
//                                                             `wait_q3_release`抓到的是这笔已经计过数的事务的Q3尾部而不是全新
//                                                             上升沿，笔数悄悄少算一笔（ILM-02/03最先把这个问题暴露成精确的
//                                                             "expected 3 observed 2"）。修复为把全部基线快照统一挪到
//                                                             `task_pulse_start`之前，和SMOKE-23的修复手法完全一致。（3）阶段
//                                                             ILM-10中途重配置的拒绝检查在一个`fork...join`之后读取活线
//                                                             `o_error_event`，但另一支（40拍连续LEDEN/LEDDAC监视）跑得比这个
//                                                             只有一个`i_source_clk`边沿宽的错误脉冲长得多——join完成时脉冲早已
//                                                             撤销，活线检查永远读到0，即使拒绝真的发生了（`o_last_error_code`
//                                                             全程正确锁存着0x02）。修复为在同一个40拍监视循环内部latch一个
//                                                             "曾经见过错误"标志和错误码，不在fork结束后读活线。（4）同一个
//                                                             ILM-10阶段最后一段重新提交EXTERNAL_TEST_CURRENT+BOTH后，只跑了
//                                                             repeat(8)settle拍就直接STOP——OPTICAL_BOTH下RED context同样在
//                                                             tick 0接管，一笔真实owner已经在途却从未驱动它的真实完成，
//                                                             STOPPING的受控释放永远等不到真实DONE，`task_wait_drain_to_config`
//                                                             超时，还连带拖累下一阶段的COMMIT因为生命周期从未真正回到CONFIG而
//                                                             被ERROR_COMMIT_STATE拒绝。修复为STOP前先驱动两笔真实事务（覆盖
//                                                             RED和IR），和ILM-01已经用过的"驱动整数对再停"是同一套纪律。
//                                                             （5）阶段ILM-13/14的稳态idle窗口检查最初从第一拍开始就卡在
//                                                             `o_scheduler_idle`=0；直接层级读取
//                                                             `ppg_400hz_frame_calibration_scheduler_Inst`发现`B_FRAME_ACTIVE`
//                                                             已经是1、`macro_tick`已经停在约500而不是0——证明这不是本阶段自己
//                                                             新建立的活动，而是更早某个阶段遗留的"空转"宏帧。回读
//                                                             `ppg_400hz_frame_calibration_scheduler.v`自己的V1.6修订记录和
//                                                             `ppg_idac_code_controller.v`约1125行确认了原因：一次纯STOP按设计
//                                                             故意不动`B_FRAME_ACTIVE`，让已经打开的窗口自然走完再释放（只有
//                                                             `i_control_abort_event`才会强制清零），而离开RUN会立即撤销
//                                                             `CTX_STARTUP_COMPLETE_BIT`——所以这个空转帧不会产生任何真实波形/
//                                                             owner活动（`i_normal_measurement_eligible`早已是0），但仍会独立于
//                                                             后面每一个阶段自己的STOP/COMMIT/START继续朝它自己的
//                                                             `MACRO_LAST_TICK`（共5000 tick）走，而且因为空转期间不会产生任何
//                                                             新context/owner，生命周期照样被允许回到CONFIG。修复为在idle窗口
//                                                             检查前加一段5200拍（略超过一整个宏帧周期）的settle等待，让任何
//                                                             这样的遗留空转帧有机会自然走完；"STATIC_BIAS期间零真实ADC owner
//                                                             提交"这条实质性论断在修复这个诊断位时序假象之前的每一轮调试里其实
//                                                             都已经成立。五处修复全部完成后：真实iverilog跑通，`-Wall`干净
//                                                             （只有两条既有无关的`ppg_dynamic_baseline_cross_detector.v`警告），
//                                                             `JNT_BASELINE 53/53 PASS`，十三条"现在做"的ID全部通过，零失配：
//                                                             `INPUT_LIGHT_STATIC_MATRIX_TB_PASS owner_commit_total=47
//                                                             static_vector_checks=3000`。
// 2026年08月29日        V1.1          Erie                  回补此前延后的ILM-11/12——Group6（启动搜索）已经完成。新增本文件此前从没用过的四个基础设施（全部原样照抄Group6/8/9已验证过的代码，没有新东西）：`task_run_startup_search`、`task_drive_amb_toward_target`/`task_drive_dcs_toward_target`、`wait_q3_release_and_sample`（在Q3刚变高那一拍立即采样LED/EN_TEST/总线状态，和Group6自己的SID-03/04当初需要的是同一个修复）。新增一个专属`task_build_search_track_dual_config`，显式把本文件V1.0自己的`task_build_normal_manual_config`阈值字段覆盖成(100,200)/8/503/150惯例，而不是继承那份还带着Group7修复之前的旧版跨零窗口——和同源的`tb_ppg_control_top_idac_bus_isolation.v`出于同样理由需要的修复一样，这里是提前主动做的，没有真的先踩坑。新阶段重新真实跑一遍双光SEARCH_TRACK启动搜索，几乎原样复用Group6自己的SID-07/08/09断言（AMB_CAL期间PHOTODIODE+EN_TEST低+两个LED都关闭+无DC窗口对应ILM-11；DCS_CAL RED/IR期间专属波形+已确认AMB码+单色LED窗口对应ILM-12），产出本文件自己的真实证据，不借用Group6的。发现并修复了一个真实bug，不在DUT RTL，而是这个新阶段和一个既有V1.0监视进程之间真实的范围冲突：ILM-09自己的连续后台监视进程（`state_current`必须一直落在MANUAL-only这个小状态集合里）写的时候贯穿整个仿真生命周期——V1.0全部阶段都是`idac_mode=MANUAL`时这样写是对的、无害的，但新的SEARCH_TRACK阶段作为自己的合法行为真实进入`ST_DCS_IR_WAIT`等真实AMB/DCS状态，真实xsim立刻抓到了随之而来的大量ILM-09误报。修复为新增一个`flag_ilm09_monitor_active`标志（默认武装，和原意保持一致），main_sequence在提交新SEARCH_TRACK阶段的配置之前显式把它拉低，把ILM-09的断言范围收窄回它真正应该覆盖的东西（MANUAL模式自己的行为），而不是"不管以后配置成什么样，state_current余生都要符合"。这是一条可以复用的教训：给任何文件回补一个新的工作模式阶段时，都要检查它既有的监视进程是不是默默假设了"文件原来的模式永远不会变"。修复后：真实Vivado 2022.2 xsim跑通（约10秒），`JNT_BASELINE 53/53 PASS`，ILM-11/12和此前已经通过的十三条ID一起全部拿到真实证据通过，`INPUT_LIGHT_STATIC_MATRIX_TB_PASS owner_commit_total=69 static_vector_checks=3000`。
// 2026年10月05日        V1.2          Erie                  ABCD复核F-028：ILM-04/ILM-05改为在整个固定电流事务循环期间（每段约10460拍）逐个下降沿检查EN_TEST=1、LEDEN1/2=0、LEDDAC=0，不再每笔只在wait_q3_release之前采样一次；任一拍违规即判失败。新增ILM_FIXED_CURRENT_MONITOR信息行报告拍数/违规数；PASS行不变（73）。负对照：Top在EN_TEST与Q3同时有效时把LEDDAC强制为1，ILM-04、ILM-05均失败（各约10450个违规拍）。
//
// 复位后跑通JNT-01~09基线，依次执行ILM-15负向拒绝、ILM-01双光NORMAL、
// ILM-02/03纯RED固定SAR9/SAR15表征、ILM-10中途重配置拒绝加下一次合法生效、
// ILM-04/05外部电流双色固定SAR9/SAR15、ILM-06/07外部电流单色隔离、ILM-08
// 安全关闭拒绝、ILM-13/14合法STATIC_BIAS，全程另有ILM-09 MANUAL-only持续监视
module tb_ppg_control_top_input_light_static_matrix();

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
	localparam [7:0] C_ERROR_COMMIT_STATE = 8'h02; // 非CONFIG状态收到配置更新事件，对应ILM-10
	localparam [7:0] C_ERROR_STATIC_BIAS_INPUT_SOURCE = 8'h14; // 已提交STATIC_BIAS资格但候选快照非CHARACTERIZATION+外部电流，对应ILM-15
	localparam [7:0] C_ERROR_FIXED_CURRENT_OPTICAL_MODE = 8'h16; // 非STATIC_BIAS固定电流表征选择了安全关闭光学模式，对应ILM-08
	localparam [4:0] C_IDAC_ST_IDLE = 5'd0; // idac控制器复位后空闲态，MANUAL全程只在这三个值间切换
	localparam [4:0] C_IDAC_ST_MANUAL_APPLY = 5'd1; // idac控制器MANUAL装码态
	localparam [4:0] C_IDAC_ST_NORMAL = 5'd8; // idac控制器MANUAL启动完成后的稳态
	// 回补ILM-11/12需要真实SEARCH_TRACK启动搜索，补上MANUAL模式从不经过的
	// AMB/DCS二分搜索状态编码，沿用本文件已有的C_IDAC_ST_前缀命名惯例
	localparam [4:0] C_IDAC_ST_AMB_APPLY = 5'd2; // idac控制器AMB候选等待安全生效
	localparam [4:0] C_IDAC_ST_AMB_WAIT = 5'd3; // idac控制器请求并评价AMB候选
	localparam [4:0] C_IDAC_ST_DCS_R_APPLY = 5'd4; // idac控制器红光DC候选等待安全生效
	localparam [4:0] C_IDAC_ST_DCS_R_WAIT = 5'd5; // idac控制器请求并评价红光DC候选
	localparam [4:0] C_IDAC_ST_DCS_IR_APPLY = 5'd6; // idac控制器红外DC候选等待安全生效
	localparam [4:0] C_IDAC_ST_DCS_IR_WAIT = 5'd7; // idac控制器请求并评价红外DC候选
	localparam integer C_CANDIDATE_GUARD_MAX = 12; // 单阶段候选步数安全上限，8位码空间理论最多8步

	// 2秒放宽到4秒：回补阶段新增真实SEARCH_TRACK启动搜索，比原V1.0纯MANUAL/
	// CHARACTERIZATION静态配置耗时更长
	localparam time C_SIM_TIMEOUT_NS = 64'd4000000000; // 4秒安全看门狗上限（回补后放宽）

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
	integer cnt_static_vector_checks;
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
	// 与Group11/12同理，直接照抄tb_ppg_control_top_baseline_cross.v的双光MANUAL
	// 配置，专供JNT前缀内部自用
	task task_build_normal_manual_config;
		begin
			i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
			i_source_config_snapshot[1023:640] = V5_RESET_PROFILE_REF;
			i_source_config_snapshot[7:0] = 8'h04;
			i_source_config_snapshot[8] = 1'b0; // run_profile=NORMAL_PPG
			i_source_config_snapshot[9] = 1'b0; // input_source=PHOTODIODE
			i_source_config_snapshot[11:10] = 2'b00; // idac_mode=MANUAL
			i_source_config_snapshot[13:12] = 2'b10; // optical_mode=OPTICAL_IR，JNT-03A等子检查需要真实IR事务
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
			i_source_config_snapshot[591:576] = 16'd4096; // amb_recheck_interval_frames
			i_source_config_snapshot[1009] = 1'b1; // peak_valley_config_valid
		end
	endtask

	task task_build_normal_manual_dual_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，ILM-01/ILM-10需要真双光
		end
	endtask

	//---------------ILM-02/03：PHOTODIODE纯RED固定精度表征配置构造任务---------------//
	// CHARACTERIZATION+PHOTODIODE唯一合法组合：optical_mode必须是RED_ONLY
	// （flag_snapshot_char_photodiode_optical_valid），input_source/idac_mode
	// 继承基准任务的PHOTODIODE/MANUAL不变
	task task_build_ilm_photodiode_red_sar9_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION
			i_source_config_snapshot[13:12] = 2'b01; // optical_mode=OPTICAL_RED，PHOTODIODE+CHARACTERIZATION唯一合法值
		end
	endtask

	task task_build_ilm_photodiode_red_sar15_config;
		begin
			task_build_ilm_photodiode_red_sar9_config;
			i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15
		end
	endtask

	//---------------ILM-04/05：外部固定电流双色配置构造任务---------------//
	// CHARACTERIZATION+EXTERNAL_TEST_CURRENT+OPTICAL_BOTH，两种精度都合法
	// （flag_snapshot_profile_precision_valid对CHARACTERIZATION不限制精度）
	task task_build_ilm_ext_current_both_sar9_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION
			i_source_config_snapshot[9] = 1'b1; // input_source=EXTERNAL_TEST_CURRENT
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH
		end
	endtask

	task task_build_ilm_ext_current_both_sar15_config;
		begin
			task_build_ilm_ext_current_both_sar9_config;
			i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15
		end
	endtask

	//---------------ILM-06：外部固定电流纯RED配置构造任务---------------//
	task task_build_ilm_ext_current_red_sar9_config;
		begin
			task_build_ilm_ext_current_both_sar9_config;
			i_source_config_snapshot[13:12] = 2'b01; // optical_mode=OPTICAL_RED，非STATIC_BIAS固定电流下合法（只有2'b11被拒绝）
		end
	endtask

	task task_build_ilm_ext_current_red_sar15_config;
		begin
			task_build_ilm_ext_current_red_sar9_config;
			i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15
		end
	endtask

	//---------------ILM-07：外部固定电流纯IR配置构造任务---------------//
	task task_build_ilm_ext_current_ir_sar9_config;
		begin
			task_build_ilm_ext_current_both_sar9_config;
			i_source_config_snapshot[13:12] = 2'b10; // optical_mode=OPTICAL_IR，非STATIC_BIAS固定电流下合法
		end
	endtask

	task task_build_ilm_ext_current_ir_sar15_config;
		begin
			task_build_ilm_ext_current_ir_sar9_config;
			i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15
		end
	endtask

	//---------------ILM-08：外部固定电流安全关闭光学模式（非法）配置构造任务---------------//
	// optical_mode=2'b11是flag_snapshot_char_current_optical_valid唯一拒绝的编码
	// （ERROR_FIXED_CURRENT_OPTICAL_MODE=8'h16），这就是合同ILM-08"EXTERNAL_
	// TEST_CURRENT OFF"的真实含义，不是input_source的第三个值
	task task_build_ilm_ext_current_off_config;
		begin
			task_build_ilm_ext_current_both_sar9_config;
			i_source_config_snapshot[13:12] = 2'b11; // optical_mode=安全关闭编码，唯一被拒绝的固定电流光学模式
		end
	endtask

	//---------------ILM-13/14：合法STATIC_BIAS V4配置构造任务---------------//
	// 与tb_ppg_control_top.v的task_build_static_bias_v4_config逐字段一致
	task task_build_static_bias_v4_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION
			i_source_config_snapshot[9] = 1'b1; // input_source=EXTERNAL_TEST_CURRENT
		end
	endtask

	task task_commit_static_bias_characterization;
		input [4:0] test_mux;
		integer cnt_wait_ready;
		begin
			@(negedge i_source_clk);
			i_source_static_characterization_enable = 1'b1;
			i_source_test_mux_ctrl = test_mux;
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

	//---------------撤销STATIC_BIAS资格提交任务---------------//
	// 与tb_ppg_control_top.v的task_clear_static_bias_characterization逐字段
	// 一致——已提交的static_characterization_enable=1是sticky的，ILM-15用完
	// 之后必须显式提交回0，否则会污染后续所有阶段的V4配置解释
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
				$display("FAIL ILM config result timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------排空回CONFIG等待任务---------------//
	task task_wait_drain_to_config;
		integer cnt_drain_wait;
		begin
			cnt_drain_wait = 0;
			while((o_lifecycle_state != ST_CONFIG) && (cnt_drain_wait < 200000)) begin
				@(posedge i_clk);
				#1;
				cnt_drain_wait = cnt_drain_wait + 1;
			end
			if(o_lifecycle_state != ST_CONFIG) begin
				$display("FAIL ILM drain back to CONFIG timeout");
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------STOP确认等待任务---------------//
	task task_wait_stop_ack;
		integer cnt_stop_wait;
		begin
			cnt_stop_wait = 0;
			while((o_stop_ack_event == 1'b0) && (cnt_stop_wait < 64)) begin
				@(posedge i_clk);
				#1;
				cnt_stop_wait = cnt_stop_wait + 1;
			end
			if(o_stop_ack_event == 1'b0) begin
				$display("FAIL ILM stop ack timeout");
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
					$display("FAIL ILM Q3 wait timeout");
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

	//---------------回补阶段：真实启动搜索SEARCH_TRACK双光PHOTODIODE配置构造任务---------------//
	// 回补ILM-11/12——本文件V1.0继承的task_build_normal_manual_config阈值窗口
	// 是Group7修复前的旧版跨零窗口（amb_threshold=(-64,72)、dcs_threshold=
	// (-48,56)），原样复用会重新踩到make_fixed_raw钳位陷阱（见memory
	// feedback-make-fixed-raw-threshold-convention）——这里显式覆盖成
	// Group6/7/8已经验证过的真正生效惯例(100,200)阈值配合8/503/150驱动
	task task_build_search_track_dual_config;
		begin
			task_build_normal_manual_dual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK，MANUAL从不经过AMB_CAL/DCS_CAL状态
			i_source_config_snapshot[115:104] = 12'sd100; // amb_threshold_low，覆盖V1.0继承的旧跨零窗口
			i_source_config_snapshot[127:116] = 12'sd200; // amb_threshold_high
			i_source_config_snapshot[139:128] = 12'sd100; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd200; // dcs_threshold_high
		end
	endtask

	//---------------真实候选驱动任务：AMB极性，above即increase---------------//
	task task_drive_amb_toward_target;
		input integer current_code;
		input integer target_code;
		reg [9:0] raw_code_local;
		integer drive_value;
		begin
			if(current_code < target_code) drive_value = 503; // 强制above_high，AMB极性下触发increase
			else if(current_code > target_code) drive_value = 8; // 强制below_low，触发decrease
			else drive_value = 150; // 强制in_window，[100,200]内
			make_fixed_raw(drive_value, raw_code_local);
			drive_real_adc_done(1'b0, raw_code_local, raw_code_local);
		end
	endtask

	//---------------真实候选驱动任务：DCS极性下below即increase，与AMB相反---------------//
	task task_drive_dcs_toward_target;
		input integer current_code;
		input integer target_code;
		reg [9:0] raw_code_local;
		integer drive_value;
		begin
			if(current_code < target_code) drive_value = 8; // 强制below_low，DCS极性下触发increase
			else if(current_code > target_code) drive_value = 503; // 强制above_high，触发decrease
			else drive_value = 150; // 强制in_window，[100,200]内
			make_fixed_raw(drive_value, raw_code_local);
			drive_real_adc_done(1'b0, raw_code_local, raw_code_local);
		end
	endtask

	//---------------Q3窗口内实时采样任务---------------//
	// 与Group6的wait_q3_release_and_sample同源：release-wait子循环本身要再耗费
	// 几拍才能确认Q3真的拉低，等这个task返回时Q3窗口早已经关闭；改为在Q3刚变高
	// 的那一拍立即采样LED/总线状态，仍然等到真正释放才返回
	task wait_q3_release_and_sample;
		output o_real_release;
		output o_sampled_leden1_low;
		output o_sampled_leden2_low;
		output o_sampled_en_test;
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
				o_sampled_leden1_low = 1'b0;
				o_sampled_leden2_low = 1'b0;
				o_sampled_en_test = 1'b0;
				o_sampled_dcn = 8'h00;
				o_sampled_ambn = 8'h00;
			end else begin
				o_real_release = 1'b1;
				o_sampled_leden1_low = o_leden1_low;
				o_sampled_leden2_low = o_leden2_low;
				o_sampled_en_test = o_en_test;
				o_sampled_dcn = o_idac_sar9dcn_low;
				o_sampled_ambn = o_idac_sar9ambn_low;
				while((o_clk_q3_low === 1'b1) && (cnt_wd < 6600)) begin
					@(negedge i_clk);
					cnt_wd = cnt_wd + 1;
				end
				if(cnt_wd >= 6600) begin
					$display("FAIL ILM Q3 wait timeout");
					cnt_error = cnt_error + 1;
				end
			end
		end
	endtask

	//---------------真实启动搜索收敛任务---------------//
	// 提取自Group6/8/9已验证过的AMB/DC_R/DC_IR三阶段二分搜索收敛循环
	task task_run_startup_search;
		reg real_release;
		reg [7:0] reg_current_amb_code, reg_current_dcs_r_code, reg_current_dcs_ir_code;
		integer cnt_wait_request;
		begin
			begin : ilm_startup_amb_stage
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
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_DCS_R_APPLY ||
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_DCS_R_WAIT) begin
						flag_amb_converged = 1'b1;
					end
				end
				if(!flag_amb_converged) begin
					$display("FAIL ILM startup AMB stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : ilm_startup_dcs_r_stage
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
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_DCS_IR_APPLY ||
						ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_DCS_IR_WAIT) begin
						flag_r_converged = 1'b1;
					end
				end
				if(!flag_r_converged) begin
					$display("FAIL ILM startup DC_R stage did not converge");
					cnt_error = cnt_error + 1;
					$finish;
				end
			end
			begin : ilm_startup_dcs_ir_stage
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
					if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_NORMAL) begin
						flag_ir_converged = 1'b1;
					end
				end
				if(!flag_ir_converged) begin
					$display("FAIL ILM startup DC_IR stage did not converge");
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
				$display("FAIL ILM startup_search_complete never asserted after convergence");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end
	endtask

	`include "tb_ppg_jnt_baseline_prefix.vh"

	//---------------owner精度身份快照进程---------------//
	// 供drive_real_adc_done取用真实committed精度，与Group11/12同源
	reg reg_owner_snapshot_precision;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			reg_owner_snapshot_precision <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
		end
	end

	//---------------owner颜色身份计数进程---------------//
	// 直接从scheduler owner commit身份统计RED/IR/总数，ILM-04~07的"只有一种
	// 颜色发生、另一种颜色计数冻结"断言都基于这组计数器的窗口delta，不依赖
	// wait_q3_release/drive_real_adc_done循环笔数本身的记账
	integer cnt_owner_commit_red;
	integer cnt_owner_commit_ir;
	integer cnt_owner_commit_total;
	initial begin
		cnt_owner_commit_red = 0;
		cnt_owner_commit_ir = 0;
		cnt_owner_commit_total = 0;
	end
	always @(posedge i_clk) begin
		if(i_rstn && ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_commit_event) begin
			cnt_owner_commit_total = cnt_owner_commit_total + 1;
			if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_adc_owner_color_ir) begin
				cnt_owner_commit_ir = cnt_owner_commit_ir + 1;
			end else begin
				cnt_owner_commit_red = cnt_owner_commit_red + 1;
			end
		end
	end

	//---------------正式结果边沿捕获进程---------------//
	integer cnt_result_capture;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
	end

	//---------------ILM-09：MANUAL-only全程持续监视进程---------------//
	// 直接层级读取idac控制器自己的state_current，断言全程只取ST_IDLE(0)/
	// ST_MANUAL_APPLY(1)/ST_NORMAL(8)，从不进入任何AMB/DCS/RECHECK/REVALIDATE
	// 状态——这是直接层级证据，不是从"没观察到AMB_CAL/DCS_CAL事务"反推出来的。
	// flag_ilm09_monitor_active默认贯穿整个仿真（V1.0原意，全部阶段都是
	// MANUAL），2026-08-29回补ILM-11/12新增的SEARCH_TRACK阶段会真实进入AMB/
	// DCS状态——这是该阶段自己应有的合法行为，不是ILM-09想要抓的违规，
	// main_sequence在那个阶段开始前会显式把这个flag拉低，真实xsim confirmed
	// 过一次这个范围冲突（第一版忘记收窄，SEARCH_TRACK阶段真实进入DCS_IR_WAIT
	// 状态触发了大量误报FAIL）
	reg flag_ilm09_monitor_active;
	integer cnt_ilm09_manual_only_checks;
	initial cnt_ilm09_manual_only_checks = 0;
	initial flag_ilm09_monitor_active = 1'b1;
	always @(posedge i_clk) begin
		if(i_rstn && flag_ilm09_monitor_active) begin
			cnt_ilm09_manual_only_checks = cnt_ilm09_manual_only_checks + 1;
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current != C_IDAC_ST_IDLE) &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current != C_IDAC_ST_MANUAL_APPLY) &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current != C_IDAC_ST_NORMAL)) begin
				$display("FAIL ILM-09 idac controller left MANUAL-only state set, state_current=%0d at t=%0t",
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current, $time);
				cnt_error = cnt_error + 1;
			end
		end
	end

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL INPUT_LIGHT_STATIC_MATRIX global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	reg flag_fixed_current_monitor_on = 1'b0; // ABCD F-028：固定电流RUN逐拍监视使能
	integer cnt_fixed_current_led_violation = 0; // ABCD F-028：监视窗口内EN_TEST/LEDEN/LEDDAC违规拍数
	integer cnt_fixed_current_monitor_cycles = 0; // ABCD F-028：监视窗口实际覆盖拍数
	// ABCD F-028：C25要求外部固定电流转换全程EN_TEST=1、LEDEN1/2=0、LEDDAC=0，原检查每笔只在等待Q3前采样一次
	always @(negedge i_clk) begin
		if(flag_fixed_current_monitor_on) begin
			cnt_fixed_current_monitor_cycles = cnt_fixed_current_monitor_cycles + 1;
			if((o_en_test !== 1'b1) || (o_leden1_low !== 1'b0) || (o_leden2_low !== 1'b0) || (o_leddac !== 8'h00)) begin
				cnt_fixed_current_led_violation = cnt_fixed_current_led_violation + 1;
			end
		end
	end

	initial begin : main_sequence
		reg real_release;
		reg [9:0] raw_code;
		integer cnt_i;
		integer cnt_red_before, cnt_ir_before, cnt_total_before;
		integer cnt_wait_cdc;
		reg flag_precision_violation;
		reg flag_leden_changed;
		reg leden1_baseline, leden2_baseline;
		reg [7:0] leddac_baseline;
		reg flag_ilm10_saw_error;
		reg [7:0] reg_ilm10_seen_error_code;

		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		cnt_static_vector_checks = 0;
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

		//=========== 阶段ILM-15：STATIC_BIAS非法输入源拒绝 ===========//
		// 先通过独立CDC路径提交static_characterization_enable=1（此时刚跑完
		// JNT基线已回到CONFIG，i_run_enable=0，CDC无条件接受），再尝试提交一份
		// CHARACTERIZATION+PHOTODIODE的V4配置——应在COMMIT当拍被
		// flag_snapshot_static_bias_valid拒绝，state_current停留CONFIG，不产生
		// 静态向量录入/波形/owner/result/码更新/计数器副作用
		cnt_total_before = cnt_owner_commit_total;
		task_commit_static_bias_characterization(5'b11111);
		cnt_wait_cdc = 0;
		while(!o_characterization_control_valid && (cnt_wait_cdc < 200)) begin
			@(posedge i_clk);
			cnt_wait_cdc = cnt_wait_cdc + 1;
		end
		if(!o_characterization_control_valid) begin
			$display("FAIL ILM-15 characterization CDC never reported control valid before negative COMMIT attempt");
			cnt_error = cnt_error + 1;
		end
		task_build_ilm_photodiode_red_sar9_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_error_event || (o_last_error_code != C_ERROR_STATIC_BIAS_INPUT_SOURCE) || (o_lifecycle_state != ST_CONFIG)) begin
			$display("FAIL ILM-15 invalid STATIC_BIAS source COMMIT was not rejected as expected, error_event=%b error_code=%0d lifecycle=%b",
				o_error_event, o_last_error_code, o_lifecycle_state);
			cnt_error = cnt_error + 1;
		end else if(cnt_owner_commit_total != cnt_total_before) begin
			$display("FAIL ILM-15 rejected STATIC_BIAS commit produced a real owner commit side effect, delta=%0d", cnt_owner_commit_total - cnt_total_before);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-15 STATIC_BIAS with PHOTODIODE candidate rejected at COMMIT (error=0x%02h), stayed in CONFIG, no side effect", o_last_error_code);
		end
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		task_clear_static_bias_characterization;

		//=========== 阶段ILM-01：PHOTODIODE NORMAL双光操作 ===========//
		task_build_normal_manual_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-01 commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取，理由同下方各阶段统一注释（SMOKE-23同类
		// 问题的修复手法）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		if(o_en_test !== 1'b0) begin
			$display("FAIL ILM-01 EN_TEST not low under PHOTODIODE NORMAL, observed=%b", o_en_test);
			cnt_error = cnt_error + 1;
		end
		for(cnt_i = 0; cnt_i < 6; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL ILM-01 no real Q3 release observed on transaction %0d", cnt_i);
				cnt_error = cnt_error + 1;
			end else begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		if(((cnt_owner_commit_red - cnt_red_before) < 2) || ((cnt_owner_commit_ir - cnt_ir_before) < 2)) begin
			$display("FAIL ILM-01 dual-color operation did not produce both RED and IR owners, red=%0d ir=%0d",
				cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if(o_en_test !== 1'b0) begin
			$display("FAIL ILM-01 EN_TEST rose during PHOTODIODE NORMAL run");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-01 PHOTODIODE NORMAL dual-color: EN_TEST held low, RED=%0d IR=%0d real owners committed",
				cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		//=========== 阶段ILM-02：PHOTODIODE纯RED固定SAR9表征 ===========//
		task_build_ilm_photodiode_red_sar9_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-02 commit, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取——RED context在宏帧tick 0几乎和START同拍
		// 接管，START后固定settle窗口再取基线会把它自己的第一笔真实commit算
		// 进基线，导致循环第一次wait_q3_release抓到的是这笔已经计过数的
		// 事务尚未回落的Q3尾部而不是全新上升沿，笔数少算一笔（与tb_ppg_
		// control_top.v的SMOKE-23是同一类问题，修复手法照搬）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		for(cnt_i = 0; cnt_i < 3; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL ILM-02 no real Q3 release observed on transaction %0d", cnt_i);
				cnt_error = cnt_error + 1;
			end else begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		if((cnt_owner_commit_red - cnt_red_before) != 3) begin
			$display("FAIL ILM-02 RED transaction count mismatch, expected 3 observed %0d (ir_delta=%0d)", cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if((cnt_owner_commit_ir - cnt_ir_before) != 0) begin
			$display("FAIL ILM-02 unexpected IR transaction observed under RED_ONLY, count=%0d", cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if((ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_amb_code != 8'd64) ||
				(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_dcs_r_code != 8'd80)) begin
			$display("FAIL ILM-02 AMB/DC_R code drifted from SPI committed value, amb=%0d dcs_r=%0d",
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_amb_code,
				ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.i_dcs_r_code);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-02 PHOTODIODE RED_ONLY fixed SAR9: 3 RED transactions, no IR, committed MANUAL AMB/DC_R codes held");
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		//=========== 阶段ILM-03：PHOTODIODE纯RED固定SAR15表征 ===========//
		task_build_ilm_photodiode_red_sar15_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-03 commit, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取——RED context在宏帧tick 0几乎和START同拍
		// 接管，START后固定settle窗口再取基线会把它自己的第一笔真实commit算
		// 进基线，导致循环第一次wait_q3_release抓到的是这笔已经计过数的
		// 事务尚未回落的Q3尾部而不是全新上升沿，笔数少算一笔（与tb_ppg_
		// control_top.v的SMOKE-23是同一类问题，修复手法照搬）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		flag_precision_violation = 1'b0;
		for(cnt_i = 0; cnt_i < 3; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL ILM-03 no real Q3 release observed on transaction %0d", cnt_i);
				cnt_error = cnt_error + 1;
			end else begin
				// 只在真正见过至少一次owner提交之后才检查精度——第一笔owner提交
				// 之前B_FRAME_PRECISION还是复位默认值，不代表精度切换出了SAR15
				if((cnt_owner_commit_red > cnt_red_before) &&
					(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_PRECISION] != 1'b1)) begin
					flag_precision_violation = 1'b1;
				end
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
				if(ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_FRAME_PRECISION] != 1'b1) begin
					flag_precision_violation = 1'b1;
				end
			end
		end
		if((cnt_owner_commit_red - cnt_red_before) != 3) begin
			$display("FAIL ILM-03 RED transaction count mismatch, expected 3 observed %0d", cnt_owner_commit_red - cnt_red_before);
			cnt_error = cnt_error + 1;
		end else if((cnt_owner_commit_ir - cnt_ir_before) != 0) begin
			$display("FAIL ILM-03 unexpected IR transaction observed under RED_ONLY, count=%0d", cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if(flag_precision_violation) begin
			$display("FAIL ILM-03 precision dropped out of SAR15 mid-run, no precision-window transition is permitted");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-03 PHOTODIODE RED_ONLY fixed SAR15: 3 RED transactions, no IR, precision stayed SAR15 throughout");
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		//=========== 阶段ILM-10：中途重配置拒绝加下一次合法生效 ===========//
		task_build_normal_manual_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-10 initial commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		for(cnt_i = 0; cnt_i < 4; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		// 中途尝试改成EXTERNAL_TEST_CURRENT+BOTH+SAR9——预期在ST_RUN被
		// ERROR_COMMIT_STATE(0x02)拒绝。用一个全程latch的"是否曾经变化过"标志
		// 而不是单次事后抽样来确认无副作用：config_update_event脉冲只有一个
		// i_source_clk边沿宽，单次事后检查可能漏掉一拍真实扰动（本文件自己
		// 的第一版真的因此漏检过一次，见文件changelog）
		leden1_baseline = o_leden1_low;
		leden2_baseline = o_leden2_low;
		leddac_baseline = o_leddac;
		flag_leden_changed = 1'b0;
		flag_ilm10_saw_error = 1'b0;
		reg_ilm10_seen_error_code = 8'h00;
		fork
			begin : ilm10_reject_attempt
				task_build_ilm_ext_current_both_sar9_config;
				task_pulse_source_update;
			end
			begin : ilm10_continuous_monitor
				integer cnt_monitor;
				for(cnt_monitor = 0; cnt_monitor < 40; cnt_monitor = cnt_monitor + 1) begin
					@(posedge i_clk);
					if((o_leden1_low !== leden1_baseline) || (o_leden2_low !== leden2_baseline) || (o_leddac !== leddac_baseline)) begin
						flag_leden_changed = 1'b1;
					end
					// o_error_event只是单拍脉冲，fork里另一支task_pulse_source_update
					// 完成得比这个40拍监视循环快得多，join之后再读活线早已错过脉冲——
					// 必须在监视循环内部全程latch是否曾经见过，不能在join之后事后单点
					// 检查（本文件自己的第一版就是这样漏检的，见文件changelog）
					if(o_error_event) begin
						flag_ilm10_saw_error = 1'b1;
						reg_ilm10_seen_error_code = o_last_error_code;
					end
				end
			end
		join
		if(!flag_ilm10_saw_error || (reg_ilm10_seen_error_code != C_ERROR_COMMIT_STATE) || (o_lifecycle_state != ST_RUN)) begin
			$display("FAIL ILM-10 mid-RUN reconfigure attempt was not rejected as expected, saw_error=%b error_code=%0d lifecycle=%b",
				flag_ilm10_saw_error, reg_ilm10_seen_error_code, o_lifecycle_state);
			cnt_error = cnt_error + 1;
		end else if(flag_leden_changed) begin
			$display("FAIL ILM-10 active waveform-context control vector changed during the rejected mid-RUN reconfigure attempt");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-10 mid-RUN reconfigure rejected (error=0x%02h), active transaction's control vector unaffected", reg_ilm10_seen_error_code);
		end
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		for(cnt_i = 0; cnt_i < 2; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		if(((cnt_owner_commit_red - cnt_red_before) < 1) || ((cnt_owner_commit_ir - cnt_ir_before) < 1) || (o_en_test !== 1'b0)) begin
			$display("FAIL ILM-10 original PHOTODIODE dual-color transaction disrupted after the rejected reconfigure attempt");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-10 original PHOTODIODE dual-color transaction continued unaffected after the rejected reconfigure attempt");
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;
		// 现在真正回到CONFIG，重新COMMIT同一份此前被拒绝的EXTERNAL_TEST_
		// CURRENT配置——证明它只在下一次合法RUN/快照才生效
		task_build_ilm_ext_current_both_sar9_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-10 re-commit of the previously-rejected config");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		if(o_en_test !== 1'b1) begin
			$display("FAIL ILM-10 re-committed EXTERNAL_TEST_CURRENT config did not take effect on the next legal RUN, EN_TEST=%b", o_en_test);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-10 previously-rejected config now legally committed and took effect on this new RUN, EN_TEST=1");
		end
		// STOP前必须先真正完成两笔物理转换——OPTICAL_BOTH下RED context几乎和
		// START同拍接管，repeat(8)后RED owner已在途，而它释放后IR owner几乎
		// 立刻跟着提交；本文件第一版只驱动了一笔真实DONE就直接STOP，第二色
		// 的owner还在途，STOPPING的受控释放永远等不到它的真实完成，导致排空
		// 超时（本文件自己的设计问题，drain-to-CONFIG超时正是这里第一次真实
		// 跑出来的，不是RTL缺陷；同一坑ILM-01已经用"驱动整数对"的方式绕开过）
		for(cnt_i = 0; cnt_i < 2; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		//=========== 阶段ILM-04：外部固定电流双色SAR9 ===========//
		task_build_ilm_ext_current_both_sar9_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-04 commit, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取——RED context在宏帧tick 0几乎和START同拍
		// 接管，START后固定settle窗口再取基线会把它自己的第一笔真实commit算
		// 进基线，导致循环第一次wait_q3_release抓到的是这笔已经计过数的
		// 事务尚未回落的Q3尾部而不是全新上升沿，笔数少算一笔（与tb_ppg_
		// control_top.v的SMOKE-23是同一类问题，修复手法照搬）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		flag_leden_changed = 1'b0;
		cnt_fixed_current_led_violation = 0; // ABCD F-028：逐拍监视计数清零
		cnt_fixed_current_monitor_cycles = 0; // ABCD F-028：有效监视拍数清零
		flag_fixed_current_monitor_on = 1'b1; // ABCD F-028：整段固定电流事务期间逐拍检查EN_TEST/LEDEN/LEDDAC
		for(cnt_i = 0; cnt_i < 6; cnt_i = cnt_i + 1) begin
			if((!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
				flag_leden_changed = 1'b1;
			end
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		flag_fixed_current_monitor_on = 1'b0; // ABCD F-028：事务段结束，停止逐拍监视
		if(cnt_fixed_current_led_violation != 0) begin
			flag_leden_changed = 1'b1; // 等待Q3释放期间任一拍违规都判失败
		end
		$display("ILM_FIXED_CURRENT_MONITOR cycles=%0d violations=%0d", cnt_fixed_current_monitor_cycles, cnt_fixed_current_led_violation); // 监视覆盖量信息行
		if(((cnt_owner_commit_red - cnt_red_before) < 2) || ((cnt_owner_commit_ir - cnt_ir_before) < 2)) begin
			$display("FAIL ILM-04 fixed-current BOTH SAR9 did not keep producing intermittent RED/IR transactions, red=%0d ir=%0d",
				cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if(flag_leden_changed) begin
			$display("FAIL ILM-04 EN_TEST/LEDEN/LEDDAC boundary violated during fixed-current BOTH SAR9 run");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-04 EXTERNAL_TEST_CURRENT BOTH SAR9: EN_TEST=1, LEDEN1/2=0, LEDDAC=0 held, RED=%0d IR=%0d",
				cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		//=========== 阶段ILM-05：外部固定电流双色SAR15 ===========//
		task_build_ilm_ext_current_both_sar15_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-05 commit, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取——RED context在宏帧tick 0几乎和START同拍
		// 接管，START后固定settle窗口再取基线会把它自己的第一笔真实commit算
		// 进基线，导致循环第一次wait_q3_release抓到的是这笔已经计过数的
		// 事务尚未回落的Q3尾部而不是全新上升沿，笔数少算一笔（与tb_ppg_
		// control_top.v的SMOKE-23是同一类问题，修复手法照搬）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		flag_leden_changed = 1'b0;
		cnt_fixed_current_led_violation = 0; // ABCD F-028：逐拍监视计数清零
		cnt_fixed_current_monitor_cycles = 0; // ABCD F-028：有效监视拍数清零
		flag_fixed_current_monitor_on = 1'b1; // ABCD F-028：整段固定电流事务期间逐拍检查EN_TEST/LEDEN/LEDDAC
		for(cnt_i = 0; cnt_i < 6; cnt_i = cnt_i + 1) begin
			if((!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
				flag_leden_changed = 1'b1;
			end
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		flag_fixed_current_monitor_on = 1'b0; // ABCD F-028：事务段结束，停止逐拍监视
		if(cnt_fixed_current_led_violation != 0) begin
			flag_leden_changed = 1'b1; // 等待Q3释放期间任一拍违规都判失败
		end
		$display("ILM_FIXED_CURRENT_MONITOR cycles=%0d violations=%0d", cnt_fixed_current_monitor_cycles, cnt_fixed_current_led_violation); // 监视覆盖量信息行
		if(((cnt_owner_commit_red - cnt_red_before) < 2) || ((cnt_owner_commit_ir - cnt_ir_before) < 2)) begin
			$display("FAIL ILM-05 fixed-current BOTH SAR15 did not keep producing intermittent RED/IR transactions, red=%0d ir=%0d",
				cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if(flag_leden_changed) begin
			$display("FAIL ILM-05 EN_TEST/LEDEN/LEDDAC boundary violated during fixed-current BOTH SAR15 run");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-05 EXTERNAL_TEST_CURRENT BOTH SAR15: EN_TEST=1, LEDEN1/2=0, LEDDAC=0 held, RED=%0d IR=%0d",
				cnt_owner_commit_red - cnt_red_before, cnt_owner_commit_ir - cnt_ir_before);
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		//=========== 阶段ILM-06：外部固定电流纯RED（SAR9+SAR15） ===========//
		task_build_ilm_ext_current_red_sar9_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-06 SAR9 commit, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取——RED context在宏帧tick 0几乎和START同拍
		// 接管，START后固定settle窗口再取基线会把它自己的第一笔真实commit算
		// 进基线，导致循环第一次wait_q3_release抓到的是这笔已经计过数的
		// 事务尚未回落的Q3尾部而不是全新上升沿，笔数少算一笔（与tb_ppg_
		// control_top.v的SMOKE-23是同一类问题，修复手法照搬）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		for(cnt_i = 0; cnt_i < 2; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		if((cnt_owner_commit_red - cnt_red_before) != 2) begin
			$display("FAIL ILM-06 SAR9 RED transaction count mismatch, expected 2 observed %0d", cnt_owner_commit_red - cnt_red_before);
			cnt_error = cnt_error + 1;
		end else if((cnt_owner_commit_ir - cnt_ir_before) != 0) begin
			$display("FAIL ILM-06 SAR9 unexpected IR transaction observed under RED_ONLY fixed current, count=%0d", cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if((!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
			$display("FAIL ILM-06 SAR9 EN_TEST/LEDEN/LEDDAC boundary wrong");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-06 EXTERNAL_TEST_CURRENT RED_ONLY fixed SAR9: only RED identity occurred, IR frozen");
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		task_build_ilm_ext_current_red_sar15_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-06 SAR15 commit, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取——RED context在宏帧tick 0几乎和START同拍
		// 接管，START后固定settle窗口再取基线会把它自己的第一笔真实commit算
		// 进基线，导致循环第一次wait_q3_release抓到的是这笔已经计过数的
		// 事务尚未回落的Q3尾部而不是全新上升沿，笔数少算一笔（与tb_ppg_
		// control_top.v的SMOKE-23是同一类问题，修复手法照搬）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		for(cnt_i = 0; cnt_i < 2; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		if((cnt_owner_commit_red - cnt_red_before) != 2) begin
			$display("FAIL ILM-06 SAR15 RED transaction count mismatch, expected 2 observed %0d", cnt_owner_commit_red - cnt_red_before);
			cnt_error = cnt_error + 1;
		end else if((cnt_owner_commit_ir - cnt_ir_before) != 0) begin
			$display("FAIL ILM-06 SAR15 unexpected IR transaction observed under RED_ONLY fixed current, count=%0d", cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if((!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
			// 2026-09-17新增：SAR15子用例原本遗漏了SAR9子用例已有的边界检查
			// （工作线D独立复核真实缺口，ILM_01_15_WORKLINE_D_INDEPENDENT_
			// RECHECK_20260917.md），补齐后与SAR9子用例覆盖深度一致
			$display("FAIL ILM-06 SAR15 EN_TEST/LEDEN/LEDDAC boundary wrong");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-06 EXTERNAL_TEST_CURRENT RED_ONLY fixed SAR15: only RED identity occurred, IR frozen, EN_TEST/LEDEN/LEDDAC boundary held");
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		//=========== 阶段ILM-07：外部固定电流纯IR（SAR9+SAR15） ===========//
		task_build_ilm_ext_current_ir_sar9_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-07 SAR9 commit, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取——RED context在宏帧tick 0几乎和START同拍
		// 接管，START后固定settle窗口再取基线会把它自己的第一笔真实commit算
		// 进基线，导致循环第一次wait_q3_release抓到的是这笔已经计过数的
		// 事务尚未回落的Q3尾部而不是全新上升沿，笔数少算一笔（与tb_ppg_
		// control_top.v的SMOKE-23是同一类问题，修复手法照搬）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		for(cnt_i = 0; cnt_i < 2; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		if((cnt_owner_commit_ir - cnt_ir_before) != 2) begin
			$display("FAIL ILM-07 SAR9 IR transaction count mismatch, expected 2 observed %0d", cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if((cnt_owner_commit_red - cnt_red_before) != 0) begin
			$display("FAIL ILM-07 SAR9 unexpected RED transaction observed under IR_ONLY fixed current, count=%0d", cnt_owner_commit_red - cnt_red_before);
			cnt_error = cnt_error + 1;
		end else if((!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
			$display("FAIL ILM-07 SAR9 EN_TEST/LEDEN/LEDDAC boundary wrong");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-07 EXTERNAL_TEST_CURRENT IR_ONLY fixed SAR9: only IR identity occurred, RED frozen");
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		task_build_ilm_ext_current_ir_sar15_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-07 SAR15 commit, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		// 基线快照必须在START之前取——RED context在宏帧tick 0几乎和START同拍
		// 接管，START后固定settle窗口再取基线会把它自己的第一笔真实commit算
		// 进基线，导致循环第一次wait_q3_release抓到的是这笔已经计过数的
		// 事务尚未回落的Q3尾部而不是全新上升沿，笔数少算一笔（与tb_ppg_
		// control_top.v的SMOKE-23是同一类问题，修复手法照搬）
		cnt_red_before = cnt_owner_commit_red;
		cnt_ir_before = cnt_owner_commit_ir;
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		for(cnt_i = 0; cnt_i < 2; cnt_i = cnt_i + 1) begin
			wait_q3_release(real_release);
			if(real_release) begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
			end
		end
		if((cnt_owner_commit_ir - cnt_ir_before) != 2) begin
			$display("FAIL ILM-07 SAR15 IR transaction count mismatch, expected 2 observed %0d", cnt_owner_commit_ir - cnt_ir_before);
			cnt_error = cnt_error + 1;
		end else if((cnt_owner_commit_red - cnt_red_before) != 0) begin
			$display("FAIL ILM-07 SAR15 unexpected RED transaction observed under IR_ONLY fixed current, count=%0d", cnt_owner_commit_red - cnt_red_before);
			cnt_error = cnt_error + 1;
		end else if((!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac != 8'h00)) begin
			// 2026-09-17新增：SAR15子用例原本遗漏了SAR9子用例已有的边界检查
			// （工作线D独立复核真实缺口，ILM_01_15_WORKLINE_D_INDEPENDENT_
			// RECHECK_20260917.md），补齐后与SAR9子用例覆盖深度一致
			$display("FAIL ILM-07 SAR15 EN_TEST/LEDEN/LEDDAC boundary wrong");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-07 EXTERNAL_TEST_CURRENT IR_ONLY fixed SAR15: only IR identity occurred, RED frozen, EN_TEST/LEDEN/LEDDAC boundary held");
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		//=========== 阶段ILM-08：外部固定电流安全关闭光学模式拒绝 ===========//
		cnt_total_before = cnt_owner_commit_total;
		task_build_ilm_ext_current_off_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_error_event || (o_last_error_code != C_ERROR_FIXED_CURRENT_OPTICAL_MODE) || (o_lifecycle_state != ST_CONFIG)) begin
			$display("FAIL ILM-08 EXTERNAL_TEST_CURRENT OFF was not rejected as expected, error_event=%b error_code=%0d lifecycle=%b",
				o_error_event, o_last_error_code, o_lifecycle_state);
			cnt_error = cnt_error + 1;
		end else if((cnt_owner_commit_total != cnt_total_before) || o_leden1_low || o_leden2_low || o_en_test || (o_leddac != 8'h00)) begin
			$display("FAIL ILM-08 rejected commit produced a real side effect: owner_delta=%0d leden1=%b leden2=%b en_test=%b leddac=%0d",
				cnt_owner_commit_total - cnt_total_before, o_leden1_low, o_leden2_low, o_en_test, o_leddac);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-08 EXTERNAL_TEST_CURRENT OFF rejected at COMMIT (error=0x%02h), no waveform/owner/LED side effect", o_last_error_code);
		end
		i_diag_clear_event = 1'b1;
		@(posedge i_clk);
		#1 i_diag_clear_event = 1'b0;

		//=========== 阶段ILM-13/14：合法STATIC_BIAS ===========//
		task_build_static_bias_v4_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM-13/14 V4 re-commit before STATIC_BIAS scenario, error_code=%0d", o_last_error_code);
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_commit_static_bias_characterization(5'b10101);
		cnt_wait_cdc = 0;
		while(!o_characterization_control_valid && (cnt_wait_cdc < 200)) begin
			@(posedge i_clk);
			cnt_wait_cdc = cnt_wait_cdc + 1;
		end
		if(!o_characterization_control_valid) begin
			$display("FAIL ILM-13/14 characterization CDC never reported control valid");
			cnt_error = cnt_error + 1;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		#1;
		if(!o_en_test || !o_clk_buf_low || !o_clk_iref_idac_low || !o_clk_iref_idac_sar9_low ||
			!o_clk_iref_idac_sar15_low || !o_clk_aferst_low || !o_clk_tiaen_low ||
			!o_en_sar9_amb_low || !o_en_sar9_dc_low || !o_en_sar15_amb_low || !o_en_sar15_dc_low ||
			o_en_tia_low || o_en_sar9_iref || o_en_sar15_iref ||
			o_clk_9q1_low || o_clk_15q1_low || o_clk_q2_low || o_clk_q3_low || o_en_15sar_low ||
			(o_leddac != 8'h00) || o_leden1_low || o_leden2_low ||
			(o_idac_sar9ambn_low != 8'h00) || (o_idac_sar9dcn_low != 8'h00) ||
			(o_idac_sar15ambn_low != 8'h00) || (o_idac_sar15dcn_low != 8'h00)) begin
			$display("FAIL ILM-13/14 STATIC_BIAS netlist static vector mismatch");
			cnt_error = cnt_error + 1;
		end else if(o_s_in != 5'b10101) begin
			$display("FAIL ILM-14 S[4:0] does not match committed test_mux, observed=%b expected=10101", o_s_in);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-13/14 STATIC_BIAS netlist static vector and S[4:0]=%b match contract table", o_s_in);
		end
		// scheduler自己的`o_scheduler_idle`要求B_FRAME_ACTIVE==0；而
		// `ppg_400hz_frame_calibration_scheduler.v`按其V1.6被动排空设计，一次
		// 纯STOP（非abort）不会强制清掉正在途中的宏帧计时，只让它自然走到
		// MACRO_LAST_TICK（5000 tick一帧）才回落——之前十个阶段里任何一次STOP
		// 都可能留下这样一个仍在"空转"但绝不会产生任何owner/波形的宏帧计时
		// （因为idac控制器`startup_search_complete`在离开RUN时立即撤销，
		// 这个空转帧的`i_normal_measurement_eligible`早已是0）。本文件直接
		// 层级读取实测确认过：进入本阶段时确实观察到`macro_tick`停在约500而
		// 不是0，证实这不是本阶段自己新建立的活动，而是更早阶段遗留的空转帧。
		// 在检查"全程idle"之前，先等它自然走完这一整帧的剩余tick，不依赖
		// `cnt_owner_commit_total`本身（那项断言本来就一直为真，因为这个空转帧
		// 从来不会产生真实owner）
		repeat(5200) @(posedge i_clk);
		begin : ilm1314_no_adc_window
			integer cnt_owner_before_static;
			integer cnt_wait_idle;
			reg flag_vector_ok;
			cnt_owner_before_static = cnt_owner_commit_total;
			flag_vector_ok = 1'b1;
			for(cnt_wait_idle = 0; cnt_wait_idle < 3000; cnt_wait_idle = cnt_wait_idle + 1) begin
				@(posedge i_clk);
				cnt_static_vector_checks = cnt_static_vector_checks + 1;
				if(!o_scheduler_idle || !o_ami_datapath_empty || !o_ssw_wrapper_idle) begin
					flag_vector_ok = 1'b0;
				end
			end
			if(cnt_owner_commit_total != cnt_owner_before_static) begin
				$display("FAIL ILM-13 unexpected real ADC owner commit during STATIC_BIAS, delta=%0d", cnt_owner_commit_total - cnt_owner_before_static);
				cnt_error = cnt_error + 1;
			end else if(!flag_vector_ok) begin
				$display("FAIL ILM-13 Scheduler/AMI/SSW did not stay idle throughout the steady-state STATIC_BIAS window");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS ILM-13 no real ADC owner commit and Scheduler/AMI/SSW stayed idle for 3000 steady-state cycles under STATIC_BIAS");
			end
		end
		// ILM-14运行期间原子更新test_mux_ctrl，验证S[4:0]确实跟着新提交值
		// 同拍改变，其余静态输出不受扰动
		task_commit_static_bias_characterization(5'b01010);
		cnt_wait_cdc = 0;
		while((o_s_in != 5'b01010) && (cnt_wait_cdc < 200)) begin
			@(posedge i_clk);
			cnt_wait_cdc = cnt_wait_cdc + 1;
		end
		if(o_s_in != 5'b01010) begin
			$display("FAIL ILM-14 S[4:0] did not follow runtime test_mux_ctrl update, observed=%b", o_s_in);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS ILM-14 S[4:0] followed runtime test_mux_ctrl atomic update to %b during STATIC_BIAS RUN", o_s_in);
		end
		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;
		task_clear_static_bias_characterization;

		if(o_system_fault_blocking) begin
			$display("FAIL INPUT_LIGHT_STATIC_MATRIX unexpected system fault blocking after all phases (before backfill phase)");
			cnt_error = cnt_error + 1;
		end

		//=========== 回补阶段：真实启动搜索SEARCH_TRACK双光PHOTODIODE，回补ILM-11/12 ===========//
		// 2026-08-29回补：ILM-11/12（AMB_CAL/DCS_CAL）原本延后，因为MANUAL模式
		// （本文件其余全部阶段的idac_mode）结构上从不经过ST_AMB_*/ST_DCS_*状态
		// （ppg_idac_code_controller.v的ST_MANUAL_APPLY只跳转ST_NORMAL），只能
		// 通过idac_mode=SEARCH_TRACK启动搜索才能真实触发。Group6已经真实
		// confirmed同款检查（SID-07/08/09），这里在本文件自己的PHOTODIODE双光
		// 配置下重新真实跑一遍，产出ILM-11/12自己的真实证据，不借用Group6的
		// ILM-09的MANUAL-only监视进程范围是V1.0全部阶段都是MANUAL这个前提下
		// 定的，这里即将切到SEARCH_TRACK，真实进入AMB/DCS状态是这个阶段自己
		// 的合法行为，收窄监视范围避免误报
		flag_ilm09_monitor_active = 1'b0;
		task_build_search_track_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ILM backfill phase commit commit_ack=%b error_event=%b last_error_code=%h start_ready=%b lifecycle=%0d",
				o_commit_ack_event, o_error_event, o_last_error_code, o_start_ready, o_lifecycle_state);
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		begin : ilm_amb_cal_stage
			integer cnt_candidate;
			integer cnt_wait_request;
			reg flag_amb_converged;
			reg [7:0] reg_current_amb_code;
			reg real_release, sampled_leden1, sampled_leden2, sampled_en_test;
			reg [7:0] sampled_dcn, sampled_ambn;
			reg flag_ilm11_checked_once;
			flag_amb_converged = 1'b0;
			flag_ilm11_checked_once = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_amb_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
				cnt_wait_request = 0;
				while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_sample_request &&
					(cnt_wait_request < 5000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_request = cnt_wait_request + 1;
				end
				reg_current_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
				wait_q3_release_and_sample(real_release, sampled_leden1, sampled_leden2, sampled_en_test, sampled_dcn, sampled_ambn);
				if(!real_release) begin
					$display("FAIL ILM-11 AMB_CAL candidate %0d real Q3 window never opened", cnt_candidate);
					cnt_error = cnt_error + 1;
				end else begin
					// ILM-11：PHOTODIODE输入语义（本配置input_source本来就是PHOTODIODE）+
					// EN_TEST低+两个LED都关闭+DC总线不驱动任何候选窗口——同Group6
					// SID-07已验证的极性惯例：o_leden1_low/o_leden2_low真实极性是
					// 1=点亮、0=关闭，尽管带着_low后缀
					if(sampled_leden1 || sampled_leden2 || sampled_en_test || (sampled_dcn !== 8'h00)) begin
						$display("FAIL ILM-11 AMB_CAL not isolated: leden1=%b leden2=%b en_test=%b dcn=%h",
							sampled_leden1, sampled_leden2, sampled_en_test, sampled_dcn);
						cnt_error = cnt_error + 1;
					end else begin
						flag_ilm11_checked_once = 1'b1;
					end
					task_drive_amb_toward_target(reg_current_amb_code, 64);
				end
				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_DCS_R_APPLY ||
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_DCS_R_WAIT) begin
					flag_amb_converged = 1'b1;
				end
			end
			if(!flag_amb_converged) begin
				$display("FAIL ILM backfill AMB_CAL stage did not converge within %0d candidates", C_CANDIDATE_GUARD_MAX);
				cnt_error = cnt_error + 1;
				$finish;
			end else if(!flag_ilm11_checked_once) begin
				$display("FAIL ILM-11 no real AMB_CAL candidate was ever cleanly sampled");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS ILM-11 AMB_CAL used PHOTODIODE input semantics, EN_TEST low, the dedicated SAR9 waveform, both LEDs off, and no DC code window across %0d real candidates", cnt_candidate);
			end
		end

		begin : ilm_dcs_cal_stage
			integer cnt_candidate;
			integer cnt_wait_request;
			reg flag_r_converged, flag_ir_converged;
			reg [7:0] reg_current_dcs_r_code, reg_current_dcs_ir_code;
			reg [7:0] reg_confirmed_amb_code;
			reg real_release, sampled_leden1, sampled_leden2, sampled_en_test;
			reg [7:0] sampled_dcn, sampled_ambn;
			reg flag_ilm12_red_checked, flag_ilm12_ir_checked;
			reg_confirmed_amb_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_code;
			flag_r_converged = 1'b0;
			flag_ilm12_red_checked = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_r_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
				cnt_wait_request = 0;
				while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request &&
					(cnt_wait_request < 5000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_request = cnt_wait_request + 1;
				end
				reg_current_dcs_r_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
				wait_q3_release_and_sample(real_release, sampled_leden1, sampled_leden2, sampled_en_test, sampled_dcn, sampled_ambn);
				if(!real_release) begin
					$display("FAIL ILM-12 DCS_CAL RED candidate %0d real Q3 window never opened", cnt_candidate);
					cnt_error = cnt_error + 1;
				end else begin
					// ILM-12红光半句：只有红光LED窗口，AMB总线持有已确认的AMB码，
					// DC总线驱动当前红光候选——同Group6 SID-08已验证的极性惯例
					if(!sampled_leden1 || sampled_leden2) begin
						$display("FAIL ILM-12 DCS_CAL RED LED window wrong: leden1=%b(expect on/1) leden2=%b(expect off/0)", sampled_leden1, sampled_leden2);
						cnt_error = cnt_error + 1;
					end else if(sampled_ambn !== reg_confirmed_amb_code) begin
						$display("FAIL ILM-12 AMB bus not holding confirmed code during DC_R stage, observed=%h expect=%h", sampled_ambn, reg_confirmed_amb_code);
						cnt_error = cnt_error + 1;
					end else begin
						flag_ilm12_red_checked = 1'b1;
					end
					task_drive_dcs_toward_target(reg_current_dcs_r_code, 80);
				end
				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_DCS_IR_APPLY ||
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_DCS_IR_WAIT) begin
					flag_r_converged = 1'b1;
				end
			end
			if(!flag_r_converged) begin
				$display("FAIL ILM backfill DCS_CAL RED stage did not converge within %0d candidates", C_CANDIDATE_GUARD_MAX);
				cnt_error = cnt_error + 1;
				$finish;
			end

			flag_ir_converged = 1'b0;
			flag_ilm12_ir_checked = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < C_CANDIDATE_GUARD_MAX) && !flag_ir_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
				cnt_wait_request = 0;
				while(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_sample_request &&
					(cnt_wait_request < 5000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_request = cnt_wait_request + 1;
				end
				reg_current_dcs_ir_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_code;
				wait_q3_release_and_sample(real_release, sampled_leden1, sampled_leden2, sampled_en_test, sampled_dcn, sampled_ambn);
				if(!real_release) begin
					$display("FAIL ILM-12 DCS_CAL IR candidate %0d real Q3 window never opened", cnt_candidate);
					cnt_error = cnt_error + 1;
				end else begin
					// ILM-12红外半句：只有红外LED窗口，极性同上
					if(sampled_leden1 || !sampled_leden2) begin
						$display("FAIL ILM-12 DCS_CAL IR LED window wrong: leden1=%b(expect off/0) leden2=%b(expect on/1)", sampled_leden1, sampled_leden2);
						cnt_error = cnt_error + 1;
					end else begin
						flag_ilm12_ir_checked = 1'b1;
					end
					task_drive_dcs_toward_target(reg_current_dcs_ir_code, 96);
				end
				repeat(4) @(posedge i_clk);
				if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current == C_IDAC_ST_NORMAL) begin
					flag_ir_converged = 1'b1;
				end
			end
			if(!flag_ir_converged) begin
				$display("FAIL ILM backfill DCS_CAL IR stage did not converge within %0d candidates", C_CANDIDATE_GUARD_MAX);
				cnt_error = cnt_error + 1;
				$finish;
			end else if(!flag_ilm12_red_checked || !flag_ilm12_ir_checked) begin
				$display("FAIL ILM-12 no real DCS_CAL RED and/or IR candidate was ever cleanly sampled: red=%b ir=%b", flag_ilm12_red_checked, flag_ilm12_ir_checked);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS ILM-12 DCS_CAL RED/IR each used the dedicated SAR9 waveform with the confirmed AMB code and selected-color DC candidate, with no opposite-color LED window");
			end
		end

		task_pulse_stop;
		task_wait_stop_ack;
		task_wait_drain_to_config;

		if(o_system_fault_blocking) begin
			$display("FAIL INPUT_LIGHT_STATIC_MATRIX unexpected system fault blocking after all phases");
			cnt_error = cnt_error + 1;
		end

		if(cnt_error == 0) begin
			$display("INPUT_LIGHT_STATIC_MATRIX_TB_PASS owner_commit_total=%0d static_vector_checks=%0d", cnt_owner_commit_total, cnt_static_vector_checks);
		end else begin
			$display("INPUT_LIGHT_STATIC_MATRIX_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
