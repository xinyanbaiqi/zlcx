////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/25
// Design Name:        JNT-01~09 Shared Baseline Prefix (Architecture A)
// Module Name:        tb_ppg_jnt_baseline_prefix (Verilog include fragment)
// Description:        Phase 3 Stage 4/5 shared JNT-01~09 (52 sub-check) baseline
//                      prefix task library, `include`-d into each
//                      tb_ppg_control_top_<group>.v file right after that file's
//                      own common ST_CONFIG/ST_READY/ST_RUN/ST_STOPPING localparam
//                      block. Not synthesizable, not a chip RTL block, not a
//                      standalone module -- a textual fragment that shares its
//                      including module's scope (i_clk/i_rstn/i_source_*,
//                      ppg_control_top_Inst, cnt_error, task_build_normal_manual_
//                      dual_config/task_pulse_source_update/task_wait_config_
//                      result/task_pulse_start/task_pulse_stop/drive_real_adc_
//                      done/wait_q3_release/make_fixed_raw, and C_FRAME_ID_WIDTH/
//                      C_SAMPLE_INDEX_WIDTH/C_CONFIG_WIDTH, all of which must
//                      already be declared above the include point).
//
// Referrences:        PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md section 11 (JNT-01~09
//                      fixed baseline, 52 sub-checks, independent-reset-first
//                      gate for every Scheduler/SSW/AMI-touching group).
//                      ppg_system_integration/tb_ppg_scheduler_ssw_ami_
//                      integration.v run_jnt_baseline task (source semantics).
//                      ppg_system_integration/PPG_JNT_BASELINE_PORTING_
//                      FEASIBILITY_20260825.md (signal-availability research
//                      this file implements; see its section 3 for the full
//                      source-name -> ppg_control_top hierarchical-path map).
//
// Dependencies:       ppg_control_top.v real hierarchy (Scheduler/SSW/AMI are
//                      its direct children per C01); the including
//                      tb_ppg_control_top_<group>.v file's own DUT instance
//                      (must be named ppg_control_top_Inst) and shared tasks.
//
// Version:            V1.2
// Revision Date:      2026/10/05
// History:
//    Time               Version       Revised by            Contents
// 2026/08/25            V1.0          Erie                  Create file. Architecture A (user-confirmed 2026-08-25, see project memory
//                                                             project-ppg-jnt-baseline-deferred): one shared JNT-01~09 task library
//                                                             `include`-d into all five Group1~5 tb_ppg_control_top_<group>.v files,
//                                                             instead of hand-copying the 52-check logic into each file separately.
//                                                             This is a real re-implementation against ppg_control_top's true V4
//                                                             lifecycle and hierarchical signal paths, not a byte-for-byte port of
//                                                             tb_ppg_scheduler_ssw_ami_integration.v's isolated three-module
//                                                             run_jnt_baseline task -- see PPG_JNT_BASELINE_PORTING_FEASIBILITY_20260825.md
//                                                             section 4 for why a literal port is not possible: the source TB drives
//                                                             Scheduler/SSW/AMI's standalone scalar i_run_profile/i_input_source/
//                                                             i_optical_mode/i_initial_precision/i_idac_mode inputs and pulses
//                                                             i_stop_ack_event/i_start_ack_event directly, none of which exist as
//                                                             ppg_control_top ports (they are fields inside the 1024-bit V4+V5 ACTIVE
//                                                             snapshot, unpacked internally); and several raw observability signals
//                                                             the checks need (o_transaction_inflight, o_startup_search_complete,
//                                                             o_startup_idac_safe_boundary, per-module fault_blocking) are left
//                                                             unconnected at ppg_control_top's own submodule instantiation and must be
//                                                             read via hierarchical reference straight into the Scheduler/SSW/AMI
//                                                             instances, the same technique every Group1~5 file already uses two levels
//                                                             deeper for AMI's internal peak/valley/cross detector signals.
//                                                             Key design decisions: (1) reuses the including file's own
//                                                             task_build_normal_manual_dual_config/task_pulse_source_update/
//                                                             task_wait_config_result/task_pulse_start/task_pulse_stop/
//                                                             drive_real_adc_done/wait_q3_release verbatim (all five Group files share
//                                                             identical task names/signatures, confirmed by direct grep across all four
//                                                             existing files before writing this fragment) instead of duplicating them.
//                                                             (2) Adds one new config-builder, jnt_build_characterization_manual_sar15_
//                                                             config, for JNT-07's CHARACTERIZATION+EXTERNAL_TEST_CURRENT+SAR15+MANUAL
//                                                             scenario, which none of Group1~5's existing NORMAL_PPG-only config
//                                                             infrastructure has ever needed to build before -- flagged in the
//                                                             feasibility doc as the one genuinely new (not just relocated) piece of
//                                                             logic. (3) Each including file's pre-existing background ADC responder
//                                                             process (the "forever begin wait_q3_release(...); ...
//                                                             drive_real_adc_done(...); end" loop) must be paused for the duration of
//                                                             run_jnt_baseline_01_09, because JNT-05/06/08/09 need to script the exact
//                                                             ADC completion/abort/reset/idle timing by hand (late DONE after abort,
//                                                             stale DONE after reset, DONE during STOP drain, forced ADC-unavailable
//                                                             deadline timeout) and two processes driving i_dout_stage1_low/
//                                                             i_clk_stage1_dout_low_async concurrently would race. flag_jnt_manual_adc_
//                                                             hold is the gate; each Group file's bg_responder loop needs one added
//                                                             `while(flag_jnt_manual_adc_hold) @(negedge i_clk);` line right after its
//                                                             existing wait_q3_release call -- a required, minimal, identical one-line
//                                                             edit to all five Group files alongside adding the two `include`/call
//                                                             sites, not something this fragment can do on its own since bg_responder
//                                                             is declared in the including file, after this fragment's include point.
//                                                             (4) The four watchdog cycle-count constants below (C_JNT_STARTUP_
//                                                             WATCHDOG_CYCLES etc.) are deliberately generous provisional bounds, not
//                                                             re-derivations of the source TB's own tick constants (JNT-02A's
//                                                             `<=13'd283`, JNT-09's `cnt_watchdog<650`, etc.) -- those were measured
//                                                             against the source TB's simplified direct-pulse startup path, which
//                                                             skips ppg_control_top's real V4 CONFIG->READY->RUN lifecycle entirely, so
//                                                             carrying the old numbers forward unexamined would silently misstate what
//                                                             is actually being bounded (feasibility doc section 4, point 1). These
//                                                             must be tightened from real first-run iverilog/xsim evidence once
//                                                             measured, the same "measure first, then encode" discipline already
//                                                             applied to every other timing constant in this project's TBs (e.g.
//                                                             wait_q3_release's own 5600/6600 cycle bounds). JNT-01~09's checks
//                                                             themselves assert real protocol content (owner identity, completion
//                                                             success/sample_index, IDAC bus selection, fault-blocking quiescence,
//                                                             abort/reset/STOP/deadline-timeout semantics); only the watchdog *ceilings*
//                                                             are provisional. Not yet run under iverilog -- this revision is the first
//                                                             implementation pass, staged small-scale verification per this project's
//                                                             established practice comes next.
// 2026/08/25            V1.1          Erie                  Staged small-scale iverilog verification (90-red-sample) against
//                                                             tb_ppg_control_top_baseline_cross.v found and fixed four real bugs in this
//                                                             file's own logic, none in ppg_control_top's RTL: (1) jnt_wait_owner_commit_
//                                                             count/jnt_wait_completion_count were called with absolute thresholds (1, 2)
//                                                             in the JNT-02/03/05/07 sections, but cnt_jnt_owner_commit/cnt_jnt_completion
//                                                             are cumulative counters reset only once at the very start of
//                                                             run_jnt_baseline_01_09 -- from JNT-05 onward the "wait for count==1" checks
//                                                             resolved instantly against already-elapsed history instead of waiting for a
//                                                             fresh owner/completion, so JNT-05A's first real run read stale JNT-04 IR
//                                                             owner data. Fixed by switching every wait call to the same
//                                                             cnt_before/cnt_before+N relative-increment pattern JNT-06/08 already used
//                                                             correctly. (2) JNT-06 cannot resume JNT-05's still-running session the way
//                                                             the source TB does: ppg_control_top.v lines 344/353 register the external
//                                                             i_control_abort_event into flag_abort_drain_stop_request, which three-way
//                                                             merges into flag_stop_request_event -- on this real six-module top, abort
//                                                             also triggers a genuine STOP drain, a V4-lifecycle cascade the isolated
//                                                             three-module source TB has no equivalent of (it has no V4 wrapper at all).
//                                                             Fixed by giving JNT-06 its own independent reset+config+START instead of
//                                                             continuing JNT-05's session; this is why C_JNT_REQUIRED_SUBCHECKS is 53
//                                                             here, not the source spec's 52 -- the extra START contributes one extra
//                                                             JNT-STARTUP-READY sub-check, the checked *content* still matches the source
//                                                             spec exactly. (3) JNT-08 asserted reg_last_completion_success==1 for the
//                                                             owner STOP catches in flight, copying the source TB's own assumption
//                                                             verbatim without checking it against this project's actual contract --
//                                                             PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md line 1070 states
//                                                             explicitly that an owner already committed when STOP is accepted is marked
//                                                             discard-pending and can only be released via a success=0 sideband, must not
//                                                             be counted successful. The real DUT run confirmed success=0, contradicting
//                                                             the copied assumption; fixed to assert success==0 per the real contract
//                                                             text, not the source TB's unexamined behavior. (4) JNT-09's ADC-unavailable
//                                                             provocation held i_adc_physical_idle at 1 (idle/available) the whole time,
//                                                             which does not block owner *commit* at all (only blocks the physical
//                                                             conversion afterward) -- the owner committed normally and sat stuck
//                                                             in-flight forever, a state ppg_400hz_frame_calibration_scheduler.v's own
//                                                             flag_red_owner_deadline/flag_ir_owner_deadline (lines 461/462) explicitly
//                                                             exclude via their own !state_current[B_INFLIGHT] guard, so the deadline
//                                                             sticky never had a chance to fire. Fixed by flipping i_adc_physical_idle to 0
//                                                             only after confirming JNT-09-STARTUP readiness, exactly mirroring the source
//                                                             TB's own i_adc_idle=1-then-0 sequencing that this file had misread. After all
//                                                             four fixes, tb_ppg_control_top_baseline_cross.v ran real 700-red-sample
//                                                             iverilog clean end to end: JNT_BASELINE checked=53 pass=53 required=53
//                                                             status=PASS, followed by its own existing Group1/2 scenario reaching
//                                                             BASELINE_CROSS_TB_PASS with the same event sequence and B[f] recomputation
//                                                             match as the pre-JNT baseline evidence. The same integration (three
//                                                             identical edits: `include` placement, one bg_responder gate line, one call
//                                                             site) was applied to tb_ppg_control_top_peak_valley_return.v (Group3),
//                                                             tb_ppg_control_top_fir_tail_isolation.v (Group4), and
//                                                             tb_ppg_control_top_long_10_cycles.v (Group5); all three confirmed clean
//                                                             JNT_BASELINE 53/53 PASS. A separate, pre-existing bg_responder classification
//                                                             timing hazard (not introduced by this file) was found and fixed in all five
//                                                             Group files while chasing an unexpected real_cal=1 informational-counter
//                                                             discrepancy -- see each Group file's own changelog for that fix, since it
//                                                             lives in code this file does not own.
// 2026/10/05            V1.2          Erie                  ABCD review F-037: when the checked or passed sub-check count falls short of
//                                                             C_JNT_REQUIRED_SUBCHECKS, the closeout now adds one to the shared cnt_error even if
//                                                             none of the executed sub-checks failed; previously only cnt_run_jnt_fail was added, so
//                                                             a short JNT prefix printed status=FAIL but the calling TB could still end in PASS.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月25日
// 设计名称:           JNT-01~09共享基线前缀（架构方案A）
// 模块名称:           tb_ppg_jnt_baseline_prefix（Verilog include片段）
// 模块说明:           Phase 3 Stage 4/5共享JNT-01~09（52个子检查）基线前缀task库，
//                      `include`进每一份tb_ppg_control_top_<group>.v文件，紧跟在
//                      该文件自己的ST_CONFIG/ST_READY/ST_RUN/ST_STOPPING公共
//                      localparam区块之后。不可综合、不是芯片RTL、不是独立模块——
//                      是一段与调用方模块共享作用域的文本片段（i_clk/i_rstn/
//                      i_source_*、ppg_control_top_Inst、cnt_error、
//                      task_build_normal_manual_dual_config/task_pulse_source_
//                      update/task_wait_config_result/task_pulse_start/
//                      task_pulse_stop/drive_real_adc_done/wait_q3_release/
//                      make_fixed_raw，以及C_FRAME_ID_WIDTH/C_SAMPLE_INDEX_WIDTH/
//                      C_CONFIG_WIDTH，这些全部必须已经在include点之前声明好）。
//
// 参考资料:           PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md第11节（JNT-01~09固定
//                      基线，52个子检查，每个触碰Scheduler/SSW/AMI的组必须独立
//                      复位后先跑通）。
//                      ppg_system_integration/tb_ppg_scheduler_ssw_ami_
//                      integration.v的run_jnt_baseline task（语义来源）。
//                      ppg_system_integration/PPG_JNT_BASELINE_PORTING_
//                      FEASIBILITY_20260825.md（本文件实现的信号可用性研究，
//                      第3节是完整的"源TB信号名->ppg_control_top层次路径"映射表）。
//
// 依赖文件:           ppg_control_top.v真实层次（Scheduler/SSW/AMI是C01定义的
//                      直接子模块）；调用方tb_ppg_control_top_<group>.v文件自己
//                      的DUT实例（必须命名为ppg_control_top_Inst）和共享task。
//
// 当前版本:           V1.2
// 修订日期:           2026年10月05日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月25日        V1.0          Erie                  创建文件。架构方案A（用户2026-08-25已确认，见项目记忆
//                                                             project-ppg-jnt-baseline-deferred）：一份共享JNT-01~09 task库
//                                                             `include`进全部五份Group1~5的tb_ppg_control_top_<group>.v文件，
//                                                             不是把52检查逻辑手工分别复制进每个文件。这是针对
//                                                             ppg_control_top真实V4生命周期和真实层次信号路径的重新实现，
//                                                             不是tb_ppg_scheduler_ssw_ami_integration.v孤立三模块
//                                                             run_jnt_baseline task的逐字节移植——原因见
//                                                             PPG_JNT_BASELINE_PORTING_FEASIBILITY_20260825.md第4节：源TB
//                                                             直接驱动Scheduler/SSW/AMI各自独立的标量输入
//                                                             i_run_profile/i_input_source/i_optical_mode/i_initial_precision/
//                                                             i_idac_mode，直接脉冲i_stop_ack_event/i_start_ack_event，这些在
//                                                             ppg_control_top上都不存在（是1024-bit V4+V5 ACTIVE快照内部字段，
//                                                             由内部解包）；且检查用到的部分原始可观测信号
//                                                             （o_transaction_inflight、o_startup_search_complete、
//                                                             o_startup_idac_safe_boundary、逐模块fault_blocking）在
//                                                             ppg_control_top自己的子模块例化处留空未接，必须用层次引用
//                                                             直接读进Scheduler/SSW/AMI各自的实例，和Group1~5现有文件已经在
//                                                             用的、读取AMI内部峰谷/穿越检测器信号的深两层层次引用是同一种
//                                                             手法。关键设计决定：（1）原样复用调用方文件自己已有的
//                                                             task_build_normal_manual_dual_config/task_pulse_source_update/
//                                                             task_wait_config_result/task_pulse_start/task_pulse_stop/
//                                                             drive_real_adc_done/wait_q3_release（写本文件前已经用grep核对过
//                                                             现有四份文件的task名字/签名完全一致），不重复实现。
//                                                             （2）新增一个配置构造task——
//                                                             jnt_build_characterization_manual_sar15_config，专供JNT-07的
//                                                             CHARACTERIZATION+EXTERNAL_TEST_CURRENT+SAR15+MANUAL场景使用，
//                                                             这是可行性研究里标记出的、Group1~5现有NORMAL_PPG专用配置
//                                                             基础设施从未构造过的真正新工作，不是搬运。（3）调用方文件已有
//                                                             的后台ADC自动响应进程（"forever begin wait_q3_release(...); ...
//                                                             drive_real_adc_done(...); end"循环）在run_jnt_baseline_01_09
//                                                             执行期间必须暂停——JNT-05/06/08/09需要手工脚本化ADC完成/abort/
//                                                             复位/idle的精确时序（abort后的迟到DONE、复位后的旧DONE、STOP
//                                                             排空期间的DONE、强制ADC不可用触发deadline超时），两个进程同时
//                                                             驱动i_dout_stage1_low/i_clk_stage1_dout_low_async会产生竞争。
//                                                             flag_jnt_manual_adc_hold是这个互斥旗标；每份Group文件自己的
//                                                             bg_responder循环需要在既有wait_q3_release调用之后加一行
//                                                             `while(flag_jnt_manual_adc_hold) @(negedge i_clk);`——这是五份
//                                                             Group文件都必须做的、和加`include`/加调用点同等必要的最小化
//                                                             一致改动，本片段自己做不到，因为bg_responder声明在调用方文件里，
//                                                             在本片段include点之后。（4）下面四个watchdog周期数常量
//                                                             （C_JNT_STARTUP_WATCHDOG_CYCLES等）是刻意宽松的临时上界，
//                                                             不是重新推导源TB自己的tick常量（JNT-02A的`<=13'd283`、JNT-09的
//                                                             `cnt_watchdog<650`等）——那些是相对源TB自己简化直连启动路径
//                                                             测出来的，那条路径完全跳过了ppg_control_top真实V4
//                                                             CONFIG->READY->RUN生命周期，不经核实就照搬旧数字会悄悄断言错
//                                                             东西（可行性文档第4节第1点）。这些常量必须等第一次真实
//                                                             iverilog/xsim证据出来后收紧，和本项目对其余每一个时序常量
//                                                             （例如wait_q3_release自己的5600/6600周期上界）一贯坚持的"先
//                                                             测量再固化"原则一致。JNT-01~09的检查本身断言的是真实协议内容
//                                                             （owner身份、完成success/sample_index、IDAC总线选中情况、
//                                                             fault_blocking静默、abort/复位/STOP/deadline超时语义）；只有
//                                                             watchdog的上界是临时的。本版本尚未跑过iverilog——这是第一版
//                                                             实现，接下来按本项目一贯做法分阶段小规模验证。
// 2026年08月25日        V1.1          Erie                  对tb_ppg_control_top_baseline_cross.v做分阶段小规模iverilog验证
//                                                             （90个RED样本），发现并修复本文件自己逻辑里的四个真实bug，都不是
//                                                             ppg_control_top的RTL问题：（1）JNT-02/03/05/07段落里
//                                                             jnt_wait_owner_commit_count/jnt_wait_completion_count用的是绝对
//                                                             阈值（1、2），但cnt_jnt_owner_commit/cnt_jnt_completion是
//                                                             run_jnt_baseline_01_09全程单调递增、只在最开头清零一次的累计
//                                                             计数器——从JNT-05开始"等到count==1"这类检查会直接对着已经
//                                                             发生过的历史值瞬间判真，不会真的等一次新的owner/完成，导致
//                                                             JNT-05A第一次真实跑读到的是JNT-04残留的IR owner数据。修复为
//                                                             全部改用JNT-06/08原本就用对的"cnt_before/cnt_before+N"相对增量
//                                                             模式。（2）JNT-06不能像源TB那样直接续用JNT-05还在跑的会话：
//                                                             ppg_control_top.v第344/353行把外部i_control_abort_event独立注册
//                                                             进flag_abort_drain_stop_request，再三路合并进
//                                                             flag_stop_request_event——这个真实六模块顶层上，abort也会连带
//                                                             触发一次真实STOP排空，是孤立三模块源TB完全没有的V4生命周期
//                                                             级联效应（源TB根本没有V4 wrapper）。修复为JNT-06改成自己独立
//                                                             复位+配置+START，不再续用JNT-05的会话；这也是
//                                                             C_JNT_REQUIRED_SUBCHECKS在本文件是53、不是源规格52的原因——
//                                                             多出的这次START多贡献一次JNT-STARTUP-READY子检查，检查的
//                                                             "内容"和源规格逐条对应，没有变化。（3）JNT-08原来断言
//                                                             reg_last_completion_success==1（STOP排空已提交owner时的完成
//                                                             success资格），是原样照抄源TB自己的假设，没有对照本项目真实
//                                                             合同核实过——PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_
//                                                             CONTRACT.md第1070行明文规定：STOP接受时已提交的owner标记为
//                                                             discard-pending，只能通过success=0旁带释放，不得计为成功。
//                                                             真实DUT跑出来的确实是success=0，和照抄来的假设矛盾；修复为
//                                                             按真实合同原文断言success==0，不再沿用源TB未经核实的行为。
//                                                             （4）JNT-09的"ADC不可用"激励把i_adc_physical_idle一直保持在1
//                                                             （idle/可用），这完全不会阻止owner*提交*（只会阻止提交之后的
//                                                             物理转换），owner照常提交、永远卡在in-flight状态——而
//                                                             ppg_400hz_frame_calibration_scheduler.v自己的
//                                                             flag_red_owner_deadline/flag_ir_owner_deadline（461/462行）
//                                                             明确要求!state_current[B_INFLIGHT]才会判定截止超时，deadline
//                                                             sticky因此永远没有机会触发。修复为在确认JNT-09-STARTUP就绪之后
//                                                             才把i_adc_physical_idle翻转成0，和源TB自己"先1后0"的时序顺序
//                                                             对齐（本文件第一版看反了这个顺序）。四处修复完成后，
//                                                             tb_ppg_control_top_baseline_cross.v真实700个RED样本的iverilog
//                                                             跑干净通过：JNT_BASELINE checked=53 pass=53 required=53
//                                                             status=PASS，随后该文件自己既有的Group1/2场景也跑到
//                                                             BASELINE_CROSS_TB_PASS，事件序列和B[f]重算比对结果与JNT接入前
//                                                             的既有证据一致。同样的接入方式（三处完全相同的改动：`include`
//                                                             位置、一行bg_responder让路语句、一处调用点）也应用到了
//                                                             tb_ppg_control_top_peak_valley_return.v（Group3）、
//                                                             tb_ppg_control_top_fir_tail_isolation.v（Group4）、
//                                                             tb_ppg_control_top_long_10_cycles.v（Group5），三份都确认
//                                                             JNT_BASELINE 53/53干净PASS。追查一个意外的`real_cal=1`展示计数
//                                                             异常时，另外发现并修复了五个Group文件都有的一个既有
//                                                             bg_responder分类时序缺陷（不是本文件引入的）——具体修复内容见
//                                                             各Group文件自己的changelog，因为代码归属在那边，不在本文件。
// 2026年10月05日        V1.2          Erie                  ABCD复核F-037：已执行或通过的子检查数量不足C_JNT_REQUIRED_SUBCHECKS时，
//                                                             即使已执行的子检查无一失败也给共享cnt_error加1；此前只加cnt_run_jnt_fail，
//                                                             前提不足时打印status=FAIL但调用方TB仍可能以PASS结束。

//===================<JNT-01~09基线控制参数>===================//
localparam integer C_JNT_REQUIRED_SUBCHECKS = 54; // 源TB是52（PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md第11节），52+1（JNT-06独立起手式多产生一次JNT-STARTUP-READY，见下）=53，工作线D 2026-09-17批次1独立复核发现JNT-02原本对应源规格JNT-02B的"IR波形上下文在RED owner未释放时已真实预建立"整段检查在移植时静默丢失，本次补回新增JNT-02-IR-PREESTABLISH一条子检查，53+1=54；JNT-06在ppg_control_top上不能像源TB那样直接续用JNT-05的残留run——ppg_control_top.v第344/353行把外部i_control_abort_event独立注册进STOP合并路径，abort会连带触发真实STOP排空，这是孤立三模块源TB没有的V4级联效应（第一次真实iverilog冒烟跑测出来的），所以JNT-06改成独立复位+配置+START，多出的这一次START多产生一次JNT-STARTUP-READY子检查，子检查的"内容"和源TB定义完全对应，只是JNT-06多了一次独立起手式
localparam integer C_JNT_STARTUP_WATCHDOG_CYCLES = 2000; // 提交配置到START ACK/startup就绪的宽松临时上界，待真实实测收紧
localparam integer C_JNT_OWNER_WATCHDOG_CYCLES = 2000; // 等待下一次owner提交的宽松临时上界
localparam integer C_JNT_COMPLETION_WATCHDOG_CYCLES = 2000; // 等待下一次完成旁带的宽松临时上界
localparam integer C_JNT_TIMEOUT_WATCHDOG_CYCLES = 3000; // JNT-09等待owner deadline超时sticky置位的宽松临时上界

//===================<JNT-01~09互斥与追踪状态>===================//
reg flag_jnt_manual_adc_hold; // bg_responder互斥旗标：1表示JNT基线正在手工控制ADC完成时序，bg_responder必须暂停
reg flag_jnt_baseline_ran; // 本次仿真是否已经跑过JNT-01~09
reg flag_jnt_baseline_pass; // JNT-01~09本次是否52项全部PASS
integer cnt_run_jnt_checked; // 本次JNT-01~09已经执行的子检查数
integer cnt_run_jnt_pass; // 本次JNT-01~09通过的子检查数
integer cnt_run_jnt_fail; // 本次JNT-01~09失败的子检查数
reg [8 * 24 - 1:0] reg_jnt_first_failure_id; // 本次JNT-01~09首个失败子检查标识

reg reg_jnt_last_owner_color_ir; // 最近一次真实owner提交的颜色身份（层次引用自Scheduler内部转发线）
reg [C_FRAME_ID_WIDTH - 1:0] reg_jnt_last_owner_frame_id; // 最近一次真实owner提交的帧号身份
reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_jnt_last_owner_sample_index; // 最近一次真实owner提交的正式序号
reg reg_jnt_last_owner_precision_mode; // 最近一次真实owner提交的精度身份
integer cnt_jnt_owner_commit; // 本次JNT-01~09已观测到的真实owner提交次数
integer cnt_jnt_completion; // 本次JNT-01~09已观测到的真实完成旁带次数
reg reg_jnt_last_completion_success; // 最近一次真实完成旁带的success资格
reg [C_SAMPLE_INDEX_WIDTH - 1:0] reg_jnt_last_completion_sample_index; // 最近一次真实完成旁带绑定的序号
integer cnt_jnt_startup_boundary; // 本次JNT-01~09已观测到的startup IDAC安全边界脉冲次数
reg [1:0] reg_jnt_phase_progress; // Q1->Q2->Q3相位顺序进度：0=未见Q1，1=已见Q1等Q2，2=Q1/Q2均已按序观测到
reg [9:0] reg_jnt_stage1_raw; // JNT-01~09手工驱动完成用的Stage1 RAW码，来自make_fixed_raw(300,...)
reg [9:0] reg_jnt_stage2_raw; // JNT-01~09手工驱动完成用的Stage2 RAW码，来自make_fixed_raw(300,...)

//===================<2026-09-17工作线D补测状态：波形上下文快照与身份一致性>===================//
// 2026-09-17新增：JNT-02原本对应源规格JNT-02B"IR上下文在RED owner未释放时预建立"的
// 检查在架构方案A移植时静默丢失，同时JNT-02/03/07多处owner身份检查也丢失了源规格
// 里"owner提交身份与其预建立波形上下文快照一致"这项比对（详见
// JNT_01_09_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md）。本节新增状态支持这两类
// 补测，复用已有jnt_owner_commit_monitor的觉察时机，不重新发明监视风格
reg flag_jnt02_ir_context_while_red_inflight; // JNT-02新增：IR波形上下文是否已在RED owner真实在途期间预建立
reg reg_jnt_red_ctx_precision; // 最近一次RED波形上下文握手的精度快照，供owner提交时比对
reg [7:0] reg_jnt_red_ctx_amb; // 最近一次RED波形上下文握手的AMB码快照
reg [7:0] reg_jnt_red_ctx_dc; // 最近一次RED波形上下文握手的DC码快照
reg reg_jnt_ir_ctx_precision; // 最近一次IR波形上下文握手的精度快照，供owner提交时比对
reg [7:0] reg_jnt_ir_ctx_amb; // 最近一次IR波形上下文握手的AMB码快照
reg [7:0] reg_jnt_ir_ctx_dc; // 最近一次IR波形上下文握手的DC码快照
reg flag_jnt_owner_identity_match; // 最近一次owner提交时，其精度/AMB码/DC码是否与对应颜色最近一次波形上下文快照一致
integer cnt_jnt_formal_result; // 本文件自建的正式结果计数（o_measurement_result_valid&&i_measurement_result_ready边沿），不复用各调用方自己声明的同名计数器——本次发现调用方之间该计数器命名并不统一（如tb_ppg_control_top_owner_identity_backpressure.v已删除同名死计数器改用cnt_result_capture），自建计数器避免共享前缀依赖调用方内部命名一致性

//===================<层次引用信号别名>===================//
// 源自PPG_JNT_BASELINE_PORTING_FEASIBILITY_20260825.md第3.2/3.3节的映射表：
// 前六个是ppg_control_top自己的内部单跳转发线（Top例化时确实接了线，只是没送到
// 顶层端口）；后三个是Top例化时留空、必须直接进Scheduler/AMI子模块实例本身的两跳
// 层次引用。全部都不是新增RTL端口，只是本文件对已经真实存在的内部信号建立观测别名。
wire w_jnt_owner_ready = ppg_control_top_Inst.ssw_adc_owner_ready_o; // 接SSW内部转发线：最早pending owner是否可提交
wire w_jnt_owner_inflight = ppg_control_top_Inst.ssw_adc_owner_inflight_o; // 接SSW内部转发线：真实owner在途状态
wire w_jnt_normal_measurement_eligible = ppg_control_top_Inst.ami_normal_measurement_eligible_o; // 接AMI内部转发线：正式NORMAL测量资格
wire w_jnt_scheduler_fault_blocking = ppg_control_top_Inst.sched_fault_active_o; // 接Top内部转发线：Scheduler本地阻断故障持续状态
wire w_jnt_ssw_fault_blocking = ppg_control_top_Inst.ssw_wrapper_fault_blocking_o; // 接Top内部转发线：SSW阻断故障持续状态
wire w_jnt_ami_fault_blocking = ppg_control_top_Inst.ami_wrapper_fault_blocking_o; // 接Top内部转发线：AMI阻断故障持续状态
wire w_jnt_transaction_inflight = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_transaction_inflight; // 两跳层次引用：Top例化时留空，直接读Scheduler实例自己的端口
wire w_jnt_startup_search_complete = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_startup_search_complete; // 两跳层次引用：Top例化时留空，直接读AMI实例自己的端口
wire w_jnt_startup_idac_safe_boundary = ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.o_startup_idac_safe_boundary; // 两跳层次引用：Top例化时留空，直接读Scheduler实例自己的端口

//===================<真实owner/完成/启动边界连续监视进程>===================//
// 与本文件其余捕获进程（PEAK/VALLEY/RETURN_9BIT）同一种valid&&event边沿判定风格；
// 不受flag_jnt_manual_adc_hold影响，全程运行，JNT-01~09窗口内外都能正确计数
always @(posedge i_clk) begin : jnt_owner_commit_monitor
	if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
		reg_jnt_last_owner_color_ir <= ppg_control_top_Inst.sched_adc_owner_color_ir_o;
		reg_jnt_last_owner_frame_id <= ppg_control_top_Inst.sched_adc_owner_frame_id_o;
		reg_jnt_last_owner_sample_index <= ppg_control_top_Inst.sched_adc_owner_sample_index_o;
		reg_jnt_last_owner_precision_mode <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
		cnt_jnt_owner_commit <= cnt_jnt_owner_commit + 1;
		// 2026-09-17新增：owner提交身份（精度/AMB码/DC码）与其颜色对应的最近一次波形
		// 上下文快照比对，源规格JNT-02A/03B/07A/07D原有此项，移植时丢失，本次补回
		flag_jnt_owner_identity_match <= ppg_control_top_Inst.sched_adc_owner_color_ir_o ?
			((ppg_control_top_Inst.sched_adc_owner_precision_mode_o == reg_jnt_ir_ctx_precision) &&
			(ppg_control_top_Inst.sched_adc_owner_amb_code_snapshot_o == reg_jnt_ir_ctx_amb) &&
			(ppg_control_top_Inst.sched_adc_owner_dc_code_snapshot_o == reg_jnt_ir_ctx_dc)) :
			((ppg_control_top_Inst.sched_adc_owner_precision_mode_o == reg_jnt_red_ctx_precision) &&
			(ppg_control_top_Inst.sched_adc_owner_amb_code_snapshot_o == reg_jnt_red_ctx_amb) &&
			(ppg_control_top_Inst.sched_adc_owner_dc_code_snapshot_o == reg_jnt_red_ctx_dc));
	end
end

// 2026-09-17新增：波形上下文握手快照+IR在RED owner在途期间预建立的检测，源规格
// JNT-02B原有此项，移植时静默丢失（JNT_01_09_WORKLINE_D_INDEPENDENT_RECHECK_
// 20260917.md真实缺口1），本次补回。sched_waveform_context_valid_o/
// ssw_waveform_context_ready_o/sched_waveform_color_ir_o等均为ppg_control_top.v
// 已有的真实内部转发线，非新增RTL端口
always @(posedge i_clk) begin : jnt_waveform_context_monitor
	if(ppg_control_top_Inst.sched_waveform_context_valid_o && ppg_control_top_Inst.ssw_waveform_context_ready_o) begin
		if(ppg_control_top_Inst.sched_waveform_color_ir_o) begin
			reg_jnt_ir_ctx_precision <= ppg_control_top_Inst.sched_waveform_precision_mode_o;
			reg_jnt_ir_ctx_amb <= ppg_control_top_Inst.sched_waveform_amb_code_snapshot_o;
			reg_jnt_ir_ctx_dc <= ppg_control_top_Inst.sched_waveform_dc_code_snapshot_o;
			if(w_jnt_transaction_inflight && !reg_jnt_last_owner_color_ir) begin
				flag_jnt02_ir_context_while_red_inflight <= 1'b1; // IR上下文在RED owner真实在途时已握手
			end
		end else begin
			reg_jnt_red_ctx_precision <= ppg_control_top_Inst.sched_waveform_precision_mode_o;
			reg_jnt_red_ctx_amb <= ppg_control_top_Inst.sched_waveform_amb_code_snapshot_o;
			reg_jnt_red_ctx_dc <= ppg_control_top_Inst.sched_waveform_dc_code_snapshot_o;
		end
	end
end

// 2026-09-17新增：自建正式结果计数，供JNT-05/JNT-08"success=0路径不产生正式结果"
// 补测使用（真实缺口3），不依赖各调用方内部同名计数器命名是否一致
always @(posedge i_clk) begin : jnt_formal_result_monitor
	if(o_measurement_result_valid && i_measurement_result_ready) begin
		cnt_jnt_formal_result <= cnt_jnt_formal_result + 1;
	end
end

always @(posedge i_clk) begin : jnt_completion_monitor
	if(ppg_control_top_Inst.ami_adc_transaction_complete_event_o) begin
		reg_jnt_last_completion_success <= ppg_control_top_Inst.ami_adc_transaction_success_o;
		reg_jnt_last_completion_sample_index <= ppg_control_top_Inst.ami_adc_complete_sample_index_o;
		cnt_jnt_completion <= cnt_jnt_completion + 1;
	end
end

always @(posedge i_clk) begin : jnt_startup_boundary_monitor
	if(w_jnt_startup_idac_safe_boundary) begin
		cnt_jnt_startup_boundary <= cnt_jnt_startup_boundary + 1;
	end
end

// Q1->Q2->Q3相位顺序进度：只在jnt_wait_conversion_phase每次调用时清零，本进程只负责
// 按序推进，不负责清零，避免和task内的清零语句竞争同一拍
always @(posedge i_clk) begin : jnt_phase_progress_monitor
	if((reg_jnt_phase_progress == 2'd0) && (reg_jnt_last_owner_precision_mode ? o_clk_15q1_low : o_clk_9q1_low)) begin
		reg_jnt_phase_progress <= 2'd1;
	end else if((reg_jnt_phase_progress == 2'd1) && o_clk_q2_low) begin
		reg_jnt_phase_progress <= 2'd2;
	end
end

//===================<JNT基线判定task>===================//
task jnt_check_case;
	input [8 * 32 - 1:0] case_id;
	input condition;
	begin
		cnt_run_jnt_checked = cnt_run_jnt_checked + 1;
		if(condition) begin
			cnt_run_jnt_pass = cnt_run_jnt_pass + 1;
			$display("PASS %0s (jnt %0d/%0d)", case_id, cnt_run_jnt_checked, C_JNT_REQUIRED_SUBCHECKS);
		end else begin
			cnt_run_jnt_fail = cnt_run_jnt_fail + 1;
			if(reg_jnt_first_failure_id == "NONE") reg_jnt_first_failure_id = case_id;
			$display("FAIL %0s (jnt %0d/%0d)", case_id, cnt_run_jnt_checked, C_JNT_REQUIRED_SUBCHECKS);
		end
	end
endtask

//===================<独立复位释放task>===================//
// 与本文件主序列自己的"复位释放"区域逐字段一致，供JNT-01~09内部每个需要独立复位的
// 子场景（JNT-05/07/08/09入口，以及JNT-01~09整体收尾）复用，不重新发明
task jnt_reset_release;
	begin
		i_rstn = 1'b0;
		i_source_rstn = 1'b0;
		i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
		i_source_config_update_event = 1'b0;
		i_start_event = 1'b0;
		i_stop_event = 1'b0;
		i_control_abort_event = 1'b0;
		i_adc_physical_idle = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;
	end
endtask

//===================<abort事件脉冲task>===================//
task jnt_pulse_abort;
	begin
		@(negedge i_clk);
		i_control_abort_event = 1'b1;
		@(posedge i_clk);
		#1 i_control_abort_event = 1'b0;
	end
endtask

//===================<CHARACTERIZATION+SAR15配置构造task>===================//
// JNT-07专用：外部固定电流SAR15双光MANUAL档位（PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md
// 第3节"外部固定电流SAR15双光"行），在task_build_normal_manual_config的NORMAL/
// PHOTODIODE/SAR9基础上只覆盖run_profile/input_source/optical_mode/
// initial_precision四个字段，idac_mode保留MANUAL不变
task jnt_build_characterization_manual_sar15_config;
	begin
		task_build_normal_manual_config;
		i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION
		i_source_config_snapshot[9] = 1'b1; // input_source=EXTERNAL_TEST_CURRENT
		i_source_config_snapshot[13:12] = 2'b00; // optical_mode=BOTH
		i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15
	end
endtask

//===================<配置提交+START task>===================//
// use_characterization_sar15=0时走既有NORMAL双光MANUAL配置（JNT-01~06/08/09），
// =1时走上面新增的CHARACTERIZATION+SAR15配置（JNT-07）；START ACK等待和
// JNT-STARTUP-READY子检查每次调用都记一次，与源TB start_manual_run每次调用都记一次
// JNT-STARTUP-READY的构成一致（52个子检查里5次start_manual_run贡献5个JNT-STARTUP-READY）
task jnt_submit_manual_config_and_start;
	input use_characterization_sar15;
	integer cnt_wd;
	begin
		if(use_characterization_sar15) jnt_build_characterization_manual_sar15_config;
		else task_build_normal_manual_dual_config;
		task_pulse_source_update;
		task_wait_config_result;
		task_pulse_start;
		cnt_wd = 0;
		while((o_start_ack_event == 1'b0) && (cnt_wd < C_JNT_STARTUP_WATCHDOG_CYCLES)) begin
			@(posedge i_clk);
			#1;
			cnt_wd = cnt_wd + 1;
		end
		cnt_wd = 0;
		while((!w_jnt_startup_search_complete || !w_jnt_normal_measurement_eligible) && (cnt_wd < C_JNT_STARTUP_WATCHDOG_CYCLES)) begin
			@(negedge i_clk);
			cnt_wd = cnt_wd + 1;
		end
		jnt_check_case("JNT-STARTUP-READY", w_jnt_startup_search_complete && w_jnt_normal_measurement_eligible);
	end
endtask

//===================<owner提交等待task>===================//
task jnt_wait_owner_commit_count;
	input integer expected_count;
	integer cnt_wd;
	begin
		cnt_wd = 0;
		while((cnt_jnt_owner_commit < expected_count) && (cnt_wd < C_JNT_OWNER_WATCHDOG_CYCLES)) begin
			@(negedge i_clk);
			cnt_wd = cnt_wd + 1;
		end
		jnt_check_case("JNT-OWNER-WAIT", cnt_jnt_owner_commit >= expected_count);
	end
endtask

//===================<完成旁带等待task>===================//
task jnt_wait_completion_count;
	input integer expected_count;
	integer cnt_wd;
	begin
		cnt_wd = 0;
		while((cnt_jnt_completion < expected_count) && (cnt_wd < C_JNT_COMPLETION_WATCHDOG_CYCLES)) begin
			@(negedge i_clk);
			cnt_wd = cnt_wd + 1;
		end
		jnt_check_case("JNT-DONE-WAIT", cnt_jnt_completion >= expected_count);
	end
endtask

//===================<相位顺序+Q3释放等待task>===================//
// 复用本文件已有的wait_q3_release；相位顺序进度reg由jnt_phase_progress_monitor
// 按reg_jnt_last_owner_precision_mode选择的9Q1/15Q1标记位持续推进
task jnt_wait_conversion_phase;
	reg real_release;
	begin
		reg_jnt_phase_progress = 2'd0;
		wait_q3_release(real_release);
		jnt_check_case("JNT-PHASE-ORDER", reg_jnt_phase_progress == 2'd2);
		jnt_check_case("JNT-Q3-RELEASE", real_release);
	end
endtask

//===================<IDAC总线选中核查task>===================//
// 逐位核对：当前owner精度对应的AMB/DC总线应等于MANUAL配置码（amb=64，
// dcs_r=80/dcs_ir=96，均来自task_build_normal_manual_config/
// jnt_build_characterization_manual_sar15_config共同复用的基础配置），未选精度的
// 两组总线全程应为8'h00，比较方式与源TB run_jnt_baseline同名检查逐位一致
task jnt_check_idac_bus;
	input [8 * 24 - 1:0] case_id;
	reg [7:0] expected_amb;
	reg [7:0] expected_dc;
	reg bus_ok;
	begin
		expected_amb = 8'd64;
		expected_dc = reg_jnt_last_owner_color_ir ? 8'd96 : 8'd80;
		if(reg_jnt_last_owner_precision_mode) begin
			bus_ok = (o_idac_sar15ambn_low == expected_amb) && (o_idac_sar15dcn_low == expected_dc) &&
				(o_idac_sar9ambn_low == 8'h00) && (o_idac_sar9dcn_low == 8'h00);
		end else begin
			bus_ok = (o_idac_sar9ambn_low == expected_amb) && (o_idac_sar9dcn_low == expected_dc) &&
				(o_idac_sar15ambn_low == 8'h00) && (o_idac_sar15dcn_low == 8'h00);
		end
		jnt_check_case(case_id, bus_ok);
	end
endtask

//===================<JNT-01~09主序列task>===================//
// 每一次owner/completion等待都必须用"调用前先拍下当前计数、等待相对增量"的模式
// （cnt_owner_before/cnt_completion_before + wait(before+N)），不能用绝对计数——
// cnt_jnt_owner_commit/cnt_jnt_completion是run_jnt_baseline_01_09全程单调递增的
// 累计计数器，只在task最开头清零一次，JNT-05及以后每个子场景开始时都已经不是0了；
// 90样本首次iverilog冒烟跑在这一点上踩到过真实bug（JNT-05A读到的是JNT-04残留的
// IR owner身份而不是复位后的新RED owner，因为jnt_wait_owner_commit_count(1)在
// cnt_jnt_owner_commit已经是2的情况下不等待就直接判真），JNT-06/08原来就是对的
// 写法，本版本把JNT-02/03/05/07统一改成同一种相对增量模式
task run_jnt_baseline_01_09;
	integer cnt_wd;
	integer cnt_completion_before;
	integer cnt_owner_before;
	integer cnt_jnt_result_before; // 2026-09-17新增：JNT-05/08"不产生正式结果"补测专用的调用前快照
	begin
		cnt_run_jnt_checked = 0;
		cnt_run_jnt_pass = 0;
		cnt_run_jnt_fail = 0;
		reg_jnt_first_failure_id = "NONE";
		flag_jnt_baseline_ran = 1'b1;
		flag_jnt_manual_adc_hold = 1'b1;
		cnt_jnt_owner_commit = 0;
		cnt_jnt_completion = 0;
		cnt_jnt_startup_boundary = 0;
		cnt_jnt_formal_result = 0;
		flag_jnt02_ir_context_while_red_inflight = 1'b0;
		flag_jnt_owner_identity_match = 1'b0;
		reg_jnt_red_ctx_precision = 1'b0;
		reg_jnt_red_ctx_amb = 8'h00;
		reg_jnt_red_ctx_dc = 8'h00;
		reg_jnt_ir_ctx_precision = 1'b0;
		reg_jnt_ir_ctx_amb = 8'h00;
		reg_jnt_ir_ctx_dc = 8'h00;
		$display("JNT_BASELINE_BEGIN required=%0d", C_JNT_REQUIRED_SUBCHECKS);

		//----- JNT-01: START边界只提交手动码，不生成owner -----//
		jnt_reset_release;
		jnt_submit_manual_config_and_start(1'b0);
		jnt_check_case("JNT-01", (cnt_jnt_startup_boundary == 1) && (cnt_jnt_owner_commit == 0));

		//----- JNT-02: RED owner先提交 -----//
		cnt_owner_before = cnt_jnt_owner_commit;
		jnt_wait_owner_commit_count(cnt_owner_before + 1);
		jnt_check_case("JNT-02A", (!reg_jnt_last_owner_color_ir) && (reg_jnt_last_owner_sample_index == 0) && flag_jnt_owner_identity_match);
		flag_jnt02_ir_context_while_red_inflight = 1'b0; // 2026-09-17新增：清零后开始观察IR上下文是否在本RED owner在途期间预建立
		jnt_wait_conversion_phase;
		jnt_check_case("JNT-02-IR-PREESTABLISH", flag_jnt02_ir_context_while_red_inflight); // 2026-09-17新增：补回源规格JNT-02B，真实缺口1
		jnt_check_idac_bus("JNT-03-IDAC");
		cnt_completion_before = cnt_jnt_completion;
		make_fixed_raw(300, reg_jnt_stage1_raw);
		make_fixed_raw(300, reg_jnt_stage2_raw);
		drive_real_adc_done(reg_jnt_last_owner_precision_mode, reg_jnt_stage1_raw, reg_jnt_stage2_raw);
		jnt_wait_completion_count(cnt_completion_before + 1);
		jnt_check_case("JNT-02B", reg_jnt_last_completion_success && (reg_jnt_last_completion_sample_index == 0));

		//----- JNT-03: RED完成后IR owner提交 -----//
		cnt_owner_before = cnt_jnt_owner_commit;
		jnt_wait_owner_commit_count(cnt_owner_before + 1);
		jnt_check_case("JNT-03A", reg_jnt_last_owner_color_ir && (reg_jnt_last_owner_sample_index == 1) && flag_jnt_owner_identity_match);

		//----- JNT-04: IR自己的Q3完成后真实捕获完成，两侧无协议故障 -----//
		jnt_wait_conversion_phase;
		jnt_check_idac_bus("JNT-04-IDAC");
		cnt_completion_before = cnt_jnt_completion;
		make_fixed_raw(300, reg_jnt_stage1_raw);
		make_fixed_raw(300, reg_jnt_stage2_raw);
		drive_real_adc_done(reg_jnt_last_owner_precision_mode, reg_jnt_stage1_raw, reg_jnt_stage2_raw);
		jnt_wait_completion_count(cnt_completion_before + 1);
		jnt_check_case("JNT-03B", reg_jnt_last_completion_success && (reg_jnt_last_completion_sample_index == 1) &&
			!w_jnt_transaction_inflight && !w_jnt_owner_inflight &&
			!w_jnt_scheduler_fault_blocking && !w_jnt_ssw_fault_blocking && !w_jnt_ami_fault_blocking);
		jnt_check_case("JNT-04", reg_jnt_last_completion_success && (reg_jnt_last_completion_sample_index == 1));

		//----- JNT-05: abort保留原owner身份，迟到DONE以success=0释放且不出正式结果 -----//
		jnt_reset_release;
		jnt_submit_manual_config_and_start(1'b0);
		cnt_owner_before = cnt_jnt_owner_commit;
		jnt_wait_owner_commit_count(cnt_owner_before + 1);
		jnt_check_case("JNT-05A", (!reg_jnt_last_owner_color_ir) && (reg_jnt_last_owner_sample_index == 0));
		jnt_wait_conversion_phase;
		cnt_jnt_result_before = cnt_jnt_formal_result; // 2026-09-17新增：abort前快照，供下方"未产生新正式结果"补测使用
		jnt_pulse_abort;
		cnt_completion_before = cnt_jnt_completion;
		make_fixed_raw(300, reg_jnt_stage1_raw);
		make_fixed_raw(300, reg_jnt_stage2_raw);
		drive_real_adc_done(reg_jnt_last_owner_precision_mode, reg_jnt_stage1_raw, reg_jnt_stage2_raw);
		jnt_wait_completion_count(cnt_completion_before + 1);
		jnt_check_case("JNT-05B", (!reg_jnt_last_completion_success) && (reg_jnt_last_completion_sample_index == 0) &&
			!w_jnt_transaction_inflight && !w_jnt_owner_inflight && (cnt_jnt_formal_result == cnt_jnt_result_before));

		//----- JNT-06: 复位清除owner身份，复位后旧物理DONE不产生完成旁带 -----//
		// 不能直接接着JNT-05残留的run继续等下一次owner：ppg_control_top.v第344/353行
		// 把外部i_control_abort_event独立注册进flag_abort_drain_stop_request，再三路
		// 合并进flag_stop_request_event——也就是说本Top上abort会连带触发一次真实STOP
		// 排空，这是孤立三模块源TB没有的V4控制平面级联效应（源TB没有V4 wrapper，
		// pulse_control_abort只影响Scheduler/SSW自己的owner FSM）。90样本首次冒烟跑
		// 已经真实验证到这一点：JNT-05后直接等下一次owner会在watchdog上界内等不到，
		// 因为整个RUN已经在往STOP排空走。改为JNT-06自己独立复位+提交配置+START，
		// 不依赖JNT-05的残留会话
		jnt_reset_release;
		jnt_submit_manual_config_and_start(1'b0);
		cnt_owner_before = cnt_jnt_owner_commit;
		jnt_wait_owner_commit_count(cnt_owner_before + 1);
		jnt_wait_conversion_phase;
		cnt_completion_before = cnt_jnt_completion;
		@(negedge i_clk);
		i_rstn = 1'b0;
		repeat(3) @(negedge i_clk);
		i_rstn = 1'b1;
		make_fixed_raw(300, reg_jnt_stage1_raw);
		make_fixed_raw(300, reg_jnt_stage2_raw);
		drive_real_adc_done(reg_jnt_last_owner_precision_mode, reg_jnt_stage1_raw, reg_jnt_stage2_raw);
		repeat(12) @(negedge i_clk);
		jnt_check_case("JNT-06", (cnt_jnt_completion == cnt_completion_before) && !w_jnt_transaction_inflight && !w_jnt_owner_inflight);

		//----- JNT-07: 独立SAR15表征run重复RED/IR相位顺序、IDAC隔离与真实捕获 -----//
		jnt_reset_release;
		jnt_submit_manual_config_and_start(1'b1);
		cnt_owner_before = cnt_jnt_owner_commit;
		jnt_wait_owner_commit_count(cnt_owner_before + 1);
		jnt_check_case("JNT-07A", (!reg_jnt_last_owner_color_ir) && reg_jnt_last_owner_precision_mode && (reg_jnt_last_owner_sample_index == 0) && flag_jnt_owner_identity_match);
		jnt_wait_conversion_phase;
		jnt_check_idac_bus("JNT-07B");
		cnt_completion_before = cnt_jnt_completion;
		make_fixed_raw(300, reg_jnt_stage1_raw);
		make_fixed_raw(300, reg_jnt_stage2_raw);
		drive_real_adc_done(reg_jnt_last_owner_precision_mode, reg_jnt_stage1_raw, reg_jnt_stage2_raw);
		jnt_wait_completion_count(cnt_completion_before + 1);
		jnt_check_case("JNT-07C", reg_jnt_last_completion_success && (reg_jnt_last_completion_sample_index == 0));
		cnt_owner_before = cnt_jnt_owner_commit;
		jnt_wait_owner_commit_count(cnt_owner_before + 1);
		jnt_check_case("JNT-07D", reg_jnt_last_owner_color_ir && reg_jnt_last_owner_precision_mode && (reg_jnt_last_owner_sample_index == 1) && flag_jnt_owner_identity_match);
		jnt_wait_conversion_phase;
		jnt_check_idac_bus("JNT-07E");
		cnt_completion_before = cnt_jnt_completion;
		make_fixed_raw(300, reg_jnt_stage1_raw);
		make_fixed_raw(300, reg_jnt_stage2_raw);
		drive_real_adc_done(reg_jnt_last_owner_precision_mode, reg_jnt_stage1_raw, reg_jnt_stage2_raw);
		jnt_wait_completion_count(cnt_completion_before + 1);
		jnt_check_case("JNT-07F", reg_jnt_last_completion_success && (reg_jnt_last_completion_sample_index == 1) &&
			!w_jnt_transaction_inflight && !w_jnt_owner_inflight &&
			!w_jnt_scheduler_fault_blocking && !w_jnt_ssw_fault_blocking && !w_jnt_ami_fault_blocking);

		//----- JNT-08: STOP以原完成资格排空已提交owner，随后阻断新owner -----//
		jnt_reset_release;
		jnt_submit_manual_config_and_start(1'b0);
		cnt_owner_before = cnt_jnt_owner_commit;
		jnt_wait_owner_commit_count(cnt_owner_before + 1);
		jnt_wait_conversion_phase;
		cnt_jnt_result_before = cnt_jnt_formal_result; // 2026-09-17新增：STOP前快照，供下方"未产生新正式结果"补测使用
		task_pulse_stop;
		cnt_completion_before = cnt_jnt_completion;
		make_fixed_raw(300, reg_jnt_stage1_raw);
		make_fixed_raw(300, reg_jnt_stage2_raw);
		drive_real_adc_done(reg_jnt_last_owner_precision_mode, reg_jnt_stage1_raw, reg_jnt_stage2_raw);
		jnt_wait_completion_count(cnt_completion_before + 1);
		// PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md第1070行明文：
		// 已提交ADC owner在STOP接受时标记为discard-pending，AMI返回的原身份
		// success=0旁带才是唯一释放路径，不得计为成功——90样本冒烟跑第一次带诊断
		// 探针的真实运行确认了这一点（success读回0，不是1），源TB的同名检查断言
		// success=1，但那是孤立三模块TB自己的假设，和ppg_control_top真实合同定义
		// 的STOP-drain收尾语义不一致，这里按真实合同改成期望success=0
		jnt_check_case("JNT-08", (!reg_jnt_last_completion_success) && (reg_jnt_last_completion_sample_index == 0) &&
			!w_jnt_transaction_inflight && !w_jnt_owner_inflight && (cnt_jnt_formal_result == cnt_jnt_result_before));

		//----- JNT-09: 一次性IDAC启动边界提交后，ADC不可用必须触发owner deadline超时 -----//
		i_rstn = 1'b0;
		i_source_rstn = 1'b0;
		i_source_config_snapshot = {C_CONFIG_WIDTH{1'b0}};
		i_source_config_update_event = 1'b0;
		i_start_event = 1'b0;
		i_stop_event = 1'b0;
		i_control_abort_event = 1'b0;
		i_adc_physical_idle = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;
		@(negedge i_source_clk);
		i_source_rstn = 1'b1;
		@(negedge i_clk);
		i_rstn = 1'b1;
		repeat(3) @(posedge i_clk);
		#1;
		jnt_submit_manual_config_and_start(1'b0);
		jnt_check_case("JNT-09-STARTUP", w_jnt_startup_search_complete && w_jnt_normal_measurement_eligible);
		// 90样本冒烟跑第一次带诊断探针的真实运行发现：一直把i_adc_physical_idle
		// 保持在1（可用/idle）并不能复现"ADC不可用"——owner照常提交、卡在真实in-flight
		// 状态（inflight=1），而ppg_400hz_frame_calibration_scheduler.v第461/462行的
		// flag_red_owner_deadline/flag_ir_owner_deadline都要求!state_current[B_INFLIGHT]
		// 才会判定截止超时，永远不会对"已提交但完成旁带迟迟不来"的owner触发。真正的
		// "ADC不可用"必须让owner连提交都做不到：STARTUP边界确认之后才把
		// i_adc_physical_idle翻转成0（不可用），源TB自己在这一点上也是同样的顺序
		// （pulse_normal_start_ack+确认o_startup_search_complete之后才把i_adc_idle
		// 从1改成0），第一版实现看反了这个翻转时机导致这条检查白跑
		i_adc_physical_idle = 1'b0;
		cnt_wd = 0;
		while((!o_scheduler_owner_deadline_timeout_sticky) && (cnt_wd < C_JNT_TIMEOUT_WATCHDOG_CYCLES)) begin
			@(negedge i_clk);
			cnt_wd = cnt_wd + 1;
		end
		jnt_check_case("JNT-09", (cnt_wd < C_JNT_TIMEOUT_WATCHDOG_CYCLES) && o_scheduler_owner_deadline_timeout_sticky &&
			!w_jnt_transaction_inflight && !w_jnt_owner_inflight && !w_jnt_ssw_fault_blocking && !w_jnt_ami_fault_blocking);
		i_adc_physical_idle = 1'b1;

		//----- 收尾：确认52项子检查全部PASS，独立清洁复位后交还调用方 -----//
		flag_jnt_baseline_pass = (cnt_run_jnt_checked == C_JNT_REQUIRED_SUBCHECKS) && (cnt_run_jnt_pass == C_JNT_REQUIRED_SUBCHECKS) && (cnt_run_jnt_fail == 0);
		if(flag_jnt_baseline_pass) begin
			$display("JNT_BASELINE checked=%0d pass=%0d required=%0d status=PASS", cnt_run_jnt_checked, cnt_run_jnt_pass, C_JNT_REQUIRED_SUBCHECKS);
		end else begin
			$display("JNT_BASELINE checked=%0d pass=%0d fail=%0d required=%0d first_failure=%0s status=FAIL", cnt_run_jnt_checked, cnt_run_jnt_pass, cnt_run_jnt_fail, C_JNT_REQUIRED_SUBCHECKS, reg_jnt_first_failure_id);
			// ABCD F-037：子检查数量或通过数不足时，即使已执行的子检查无一失败也必须计入统一错误数，
			// 否则调用方只看cnt_error会在JNT前提不成立时继续跑组场景并最终PASS
			cnt_error = cnt_error + cnt_run_jnt_fail + (((cnt_run_jnt_checked != C_JNT_REQUIRED_SUBCHECKS) || (cnt_run_jnt_pass != C_JNT_REQUIRED_SUBCHECKS)) ? 1 : 0);
		end
		flag_jnt_manual_adc_hold = 1'b0;
		jnt_reset_release;
	end
endtask
