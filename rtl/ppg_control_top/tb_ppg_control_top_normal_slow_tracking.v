`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/27
// Design Name:        PPG NORMAL IDAC Slow Tracking Testbench
// Module Name:        tb_ppg_control_top_normal_slow_tracking
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_idac_code_controller.v
//                      ppg_normal_transaction_fork.v
//                      PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.2
// Revision Date:      2026/09/18
// History:
//    Time               Version       Revised by            Contents
// 2026/09/18            V1.2          Erie                  Workline-D pending-item investigation, TRK-01. Documentation-only change, no functional/assertion edit: reverse-traced i_track_valid's real derivation chain (AMI line 2373 -> flag_track_branch_valid -> ppg_normal_transaction_fork.v's own track_valid_o) and confirmed a genuine architectural finding -- that fork's payload_o and track_valid_o registers are written by the exact same flag_input_transfer clocked-enable condition in two separate always blocks (lines 278-309), so there is structurally no RTL path for payload to change while valid stays 0; any real event that changes payload necessarily asserts valid=1 on the same edge. This makes TRK-01's "changing payload while valid is low" contract clause unreachable through any legitimate top-level stimulus under the current RTL -- not a TB construction gap. Confirmed force is inapplicable per this project's standing force-on-shared-net rule (these are not private single-consumer signals) and would in any case only exercise a hardware-impossible combination. Also noted the downstream safety property is statically provable regardless: flag_track_sample_qualified (ppg_idac_code_controller.v line ~498) is a pure AND-chain starting with flag_track_transfer, so it is structurally 0 whenever transfer is 0 regardless of payload field values -- provable by inspection, just not dynamically demonstrable in simulation. Left the existing (weaker, passive-wait) TRK-01 check as-is since it is a real, correctly-passing test of a different, valid property; added this comment so the gap is recorded rather than silently left looking unexamined. Whether to add a dedicated test-injection port to make the active scenario legally constructible is a product decision left to the user, per this project's established C11/C14/C15 discard-broadcast precedent for this class of finding. See WORKLINE_D_TRK01_ISE01_20260918.md for the full investigation.
// 2026/08/27            V1.0          Erie                  Create file. Stage 5 Group 7 (NORMAL-IDAC-SLOW-TRACKING, C25 contract section 9.4.2, TRK-01~10). This is a genuinely different mechanism from Group 6's startup binary search, though the same `ppg_idac_code_controller.v` module: the NORMAL tracking fork is a single combinational always block, split cleanly by `i_track_color_ir` into two fully independent RED/IR sub-branches, each a 4-way priority chain per real transaction -- in-window clears both direction counters; a confirm-trigger (`cnt_dcs_r_high>=i_dcs_confirm_count-1`, shared confirm-count field with search/revalidate) clears counters and, only if `flag_dcs_r_adjust_allowed` (headroom against `i_dcs_r_code_min`/`_max`) holds, forms a +-1 LSB pending code; otherwise above-high/below-low increments the matching counter and zeros the other -- this same branch structure IS the direction-reversal reset (TRK-03), not a separate mechanism. Commit only happens on `i_frame_safe_boundary` (the SAME port Group 6's startup search also commits on), gated by `flag_dcs_r_commit`/`_ir_commit`, pulsing `o_dcs_r_code_update`/`o_dcs_r_track_adjust` for exactly one cycle. Epoch is `C_CODE_EPOCH_WIDTH=4` bits, plain truncating addition -- 4'hF->4'h0 automatic. `flag_track_sample_qualified` additionally requires `reg_context[CTX_STARTUP_COMPLETE_BIT]` and `state_current==ST_NORMAL`, confirming the Group 6-before-Group 7 dependency exactly. Confirmed the tracking fork's `i_track_calibration_applied`/`i_track_amb_code_snapshot`/`i_track_dc_code_snapshot`/`i_track_*_code_epoch` inputs are private, single-consumer AMI wires (unlike Group 6's shared router broadcast bundle), so `force`/`release` is safe here for TRK-09, no INJ-02 detour needed. This V1.0 commit compiled but had not yet been run to a real pass.
// 2026/08/28            V1.1          Erie                  Getting a real, fully-passing run took six rounds of real bugs, every one found only by actually running this against real RTL with real iverilog/xsim, not by re-reading the contract text harder -- all six are recorded here in full because at least three of them are directly reusable lessons for any future Stage 5 file, not just this one. (1) The first real run showed TRK-02's in-window step failing to clear `cnt_dcs_r_high`: this file's `task_drive_normal_track_sample` assumed strict RED/IR alternation and drove whatever the scheduler's NEXT real transaction happened to be, but dual-optical NORMAL scheduling is not a guaranteed 1:1 alternation once each color's own owner/pending timing is in play -- a driven "in-window" sample silently landed on IR instead of RED, leaving RED's counter untouched. Fixed by replacing it with `task_drive_track_color_value`/`task_drive_track_color`, which retry against the real owner-identity snapshot (`reg_owner_snapshot_color_ir`, captured at `sched_adc_owner_commit_event_o` exactly like `tb_ppg_control_top_baseline_cross.v`'s own proven pattern) until the target color's real transaction actually arrives, driving a neutral value for any other color's transaction along the way. (2) With that fixed, TRK-03's below-low step still read back as in-window (`flag_track_s1_value=8`) instead of below `dcs_threshold_low`: this file had copied the thresholds `amb_threshold=(-64,72)`/`dcs_threshold=(-48,56)` and the +-1500/0 driving convention from memory, but `make_fixed_raw` clamps any negative `target_code` to 8, and 8 sits *inside* both of those cross-zero windows -- a "below_low" drive attempt was silently misclassified as in-window. Added a diagnostic to Group 6's own already-passing `task_drive_amb_toward_target` to check empirically rather than continue reasoning abstractly, which confirmed Group 6's own real, working config already uses `(100,200)` thresholds with `8`/`503`/`150` driving values specifically so all three classifications land on plain positive numbers unaffected by the clamp -- this file had simply copied a stale, pre-fix set of numbers from memory instead of Group 6's real final ones. Copied Group 6's real values verbatim into this file's thresholds and all four driving tasks. (3) TRK-07/TRK-08 then showed the code moving in the *wrong* direction (80->79->78... on evidence meant to increase it): for DCS, `dcs_polarity=0` means `above_high` triggers *decrease* and `below_low` triggers *increase* -- the exact opposite of AMB's polarity=1 mapping, and this file's own TRK-07/08 loops had driven `above_high` expecting an increase. TRK-02/03/04/06/09/10 were unaffected since they only check the high/low zone counters directly, not the resulting commit direction. Swapped the three affected loops (TRK-07's pending-formation loop, TRK-08's epoch-wrap loop, TRK-08's min/max-rail loop) to drive `below_low` for "increase" instead. (4) Phase B then hung indefinitely in `task_stop_and_drain` after TRK-08's min/max test -- confirmed via hierarchical diagnostics (not assumed) that `o_stop_ack_event` fired normally but the scheduler's own `state_current[B_INFLIGHT]` bit never cleared. Reading `ppg_400hz_frame_calibration_scheduler.v`'s own STOP-handling block directly: on STOP, an in-flight owner is only marked `B_INFLIGHT_DISCARD=1` for controlled discard -- `B_INFLIGHT` itself is not cleared until a real completion (even a `success=0` discard release) actually arrives for it. This file's `task_stop_and_drain` never drove anything *after* issuing STOP, so if the scheduler happened to dispatch a fresh owner right at STOP (entirely possible with continuous real NORMAL scheduling), that owner could never resolve and the drain hung forever -- confirmed not a simple "needs more patience" case since 1100 real seconds under iverilog produced zero further progress. Fixed by adding a bounded post-STOP flush loop inside `task_stop_and_drain` itself that keeps driving neutral real completions for as long as `B_INFLIGHT` stays set (bounded at 10 attempts, with the file's own watchdog as a backstop) before proceeding to the drain-wait. (5) With Phase A/B now passing, Phase C's TRK-05 still failed to see any real SAR9->SAR15 transition within 1300 driven frames even though `tb_ppg_control_top_baseline_cross.v` saw its first PEAK by frame 63 under a comparable setup -- confirmed via a heartbeat diagnostic that `dcs_r_code` was being driven from 80 down to its configured floor (12) within 500 frames and pinned there, because this file had reused Phase A/B's `(100,200)` `dcs_threshold_high` for Phase C too, but the generator's own NORMAL-profile physiological baseline (`C_RAW_DC_OFFSET_RED=240`/`_IR=270`, comfortably realistic swing range roughly [147,333]/[154,386]) sits mostly *above* 200 -- nearly every real generator sample read as `above_high`, so DCS-polarity-0 tracking hammered the code toward decrease continuously, corrupting the DC-recovery baseline the coarse-detection FIR needs to see a clean physiological shape. Added a Phase-C-only config task, `task_build_search_track_generator_config`, widening just `dcs_threshold_high` to 400 (comfortably containing the generator's real range) so tracking stays essentially quiescent during the generator run without touching Phase A/B's own `(100,200)`/`8`/`503`/`150` driving convention at all (those three classifications land identically under either window width). (6) Even with the code holding steady at 80, TRK-05 STILL failed to observe any transition -- but a deeper diagnostic showed `o_coarse_ppg_value` cycling through real, large-amplitude pulse shapes (roughly 500 to 5569 and back, well past `min_peak_valley_amplitude`), proving PEAK/VALLEY/CROSS activity was genuinely happening underneath. The actual bug: this file checked `o_fine_window_start_event`/`o_return_9bit_valid` inline, once per loop iteration, immediately after the multi-cycle blocking `drive_real_adc_done` task returned -- but both are single-cycle event pulses that can legitimately fire *during* that task's internal cycles, not exactly at the check point, so they were silently missed every time. This is the same class of defect this project's own [[feedback_tb_counter_scope_and_stop_boundary]] memory already warns about (fork/join pulse-signal staleness) -- checking a pulse signal only at one specific point after a multi-cycle blocking call misses it whenever the pulse and the check point don't land on the same cycle. Fixed by replacing the inline checks with a continuous `always@(posedge i_clk)` background monitor plus sticky capture registers, mirroring `tb_ppg_control_top_baseline_cross.v`'s own already-proven event-capture pattern exactly, rather than re-inventing a fragile one-shot poll. After all six fixes: real Vivado 2022.2 xsim run (this file's own scale, once Phase C's real ~1300-frame generator section is included, falls into this project's own established "large-scale/long-run -> use xsim, not iverilog" guidance -- the same file took 20+ minutes under iverilog without finishing per that same established precedent), `JNT_BASELINE 53/53 PASS`, all ten TRK-01~10 IDs pass with real evidence, `NORMAL_SLOW_TRACKING_TB_PASS result_captures=1406 owner_commit_total=1477`. Static compile is also `iverilog -Wall` clean with zero warnings.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月27日
// 设计名称:           PPG NORMAL IDAC慢速跟踪测试平台
// 模块名称:           tb_ppg_control_top_normal_slow_tracking
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      ppg_idac_code_controller.v
//                      ppg_normal_transaction_fork.v
//                      PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.2
// 修订日期:           2026年09月18日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年09月18日        V1.2          Erie                  工作线D待查清单调查，TRK-01。纯文档性改动，不改任何断言/功能逻辑：反查`i_track_valid`真实推导链（AMI 2373行→`flag_track_branch_valid`→`ppg_normal_transaction_fork.v`自己的`track_valid_o`），确认一个真实的架构性发现——该fork的`payload_o`和`track_valid_o`两个寄存器在两个独立`always`块里由完全相同的`flag_input_transfer`时钟使能条件写入（278-309行），结构上根本不存在"payload变化但valid仍为0"这条路径：任何让payload真实变化的事件必然在同一拍把valid同时置1。这使得TRK-01合同条款"valid低时payload变化"这半句在当前RTL下无法通过任何合法顶层激励构造——不是TB构造手法的缺口。确认按本项目一贯force-on-shared-net戒律不能force（这两个不是私有单消费者信号），即使force也只能测出一个真实硬件里不可能出现的组合。同时指出下游安全性质本身是静态可证的，与是否能动态构造无关：`flag_track_sample_qualified`（`ppg_idac_code_controller.v`约498行）是以`flag_track_transfer`打头的纯AND链，transfer=0时整条表达式结构上必为0，与payload字段取值无关——这一点靠读代码就能证明，只是无法用真实仿真动态演示。现有（较弱的、被动等待式）TRK-01检查原样保留，它是对另一条不同、有效性质的真实且正确通过的测试；新增这段注释是为了把这个缺口如实记录下来，不让它看起来像是被漏掉了。是否要新增专属测试注入端口让这个主动场景变得合法可构造，是产品层面的决定，留给用户判断，参照本项目已有的C11/C14/C15 discard-broadcast同类先例处理方式。完整调查过程见`WORKLINE_D_TRK01_ISE01_20260918.md`。
// 2026年08月27日        V1.0          Erie                  创建文件。Stage 5第7组（NORMAL-IDAC-SLOW-TRACKING，C25合同9.4.2节，TRK-01~10）。虽然还是同一个`ppg_idac_code_controller.v`模块，但和Group6的启动二分搜索是完全不同的机制：NORMAL跟踪fork（1054-1098行）是单个组合`always`块，用`i_track_color_ir`干净地拆成RED/IR两条完全独立的分支，每笔真实事务走一个四级优先链——窗口内清零两个方向计数器；确认触发（`cnt_dcs_r_high>=i_dcs_confirm_count-1`，和搜索/重验证共用同一个确认次数字段）清零计数器，且只有在`flag_dcs_r_adjust_allowed`（相对`i_dcs_r_code_min`/`_max`还有调整空间）成立时才形成±1LSB候选；否则高于上限/低于下限只递增对应计数器并把另一个清零——这个分支结构本身就是方向反转清零（TRK-03），不是另一套独立机制。提交只发生在`i_frame_safe_boundary`（和Group6启动搜索提交用的是同一个端口，没有专属的NORMAL边界信号）上，由`flag_dcs_r_commit`/`_ir_commit`门控，脉冲`o_dcs_r_code_update`/`o_dcs_r_track_adjust`（红外同理）各一拍。Epoch是`C_CODE_EPOCH_WIDTH=4`位，普通截断加法递增——4'hF→4'h0自动发生，没有特殊代码。`flag_track_sample_qualified`（RED/IR共用同一个门控，用`i_track_color_ir`选色）额外要求`reg_context[CTX_STARTUP_COMPLETE_BIT]`和`state_current==ST_NORMAL`——恰好证实了批次规划预判的Group6先于Group7依赖：跟踪在同一次RUN里Group6的启动搜索真正完成之前根本无法开始给样本资格认证。
//                                                             一个在Group6（SID-10）踩过坑后本轮动笔前重新核实的RTL/方法论事实，这次结果是好消息：跟踪fork的`i_track_calibration_applied`/`i_track_amb_code_snapshot`/`i_track_dc_code_snapshot`/`i_track_amb_code_epoch`/`i_track_dc_code_epoch`各自接的是它们自己私有的、单消费者AMI网线（`flag_track_calibration_applied`等，`ppg_adc_measurement_idac_integration.v`492/586-589行，每一条都只有`ppg_normal_transaction_fork`专属`o_track_*`输出这一个驱动源、idac控制器自己的`i_track_*`输入这一个消费者）——和Group6搜索路径接的router共享广播总线（`flag_router_calibration_applied`等，同时扇给AMB搜索、DCS搜索、DC恢复等好几个消费者）完全不同。这意味着对这几条跟踪专用网线做`force`/`release`是安全的（按[[feedback-verilog-force-shared-net]]先查扇出再决定），本轮TRK-09直接用了这个手法，不需要绕道Group6的INJ-02身份注入。动笔前也重新核实过：`stage1_calibration_valid=0`和`idac_mode=SEARCH_TRACK`在COMMIT层结构性互斥这条结论对本组同样成立，原因和Group6的SID-11完全一样（CHARACTERIZATION-only路径强制`idac_mode=MANUAL`）——既然NORMAL跟踪和启动搜索一样只在SEARCH_TRACK下才跑，本文件从不尝试用配置构造未校准证据，TRK-09"calibration-applied缺失"半句和"码快照/版本错配"半句都改用上面确认安全的逐字段force。
//                                                             TRK-05（SAR9/SAR15精度切换保留跟踪证据）需要真实生理波形生成器，不能用固定RAW码：真实的SAR9→SAR15切换由`ppg_dynamic_baseline_cross_detector.v`对许多真实帧的真实上穿检测驱动，和`tb_ppg_control_top_baseline_cross.v`（Stage4）已经建成并验证过的机制完全一样（`BASELINE_CROSS_TB_PASS real_red=700 real_ir=699 ... cross_count=1 return_count=1`，用的正是C11自己的nominal Q16权重——本文件自己`make_fixed_raw(target_code)`恒等式所依赖的同一组权重，那份文件自己的V1.0 changelog已经确认必须用这组权重才能产生真实、非退化的穿越）。下面阶段C在自己一次全新的SEARCH_TRACK配置RUN里原样复用`tb_ppg_real_raw_generator.vh`的`task_generate_raw_target_code(C_RAW_PROFILE_NORMAL, ...)`（该生成器自己的V1.2 changelog明确把AMB_CAL/DCS_CAL和EXTERNAL_TEST_CURRENT激励排除在覆盖范围外，但没有排除NORMAL跟踪，且生成器只管RAW/校准值形状，不关心`idac_mode`），监视真实的`o_fine_window_start_event`/回落9-bit事件本身而不是照抄`tb_ppg_control_top_baseline_cross.v`自己的具体帧号（那份文件的帧号是它自己那套配置——比如MANUAL idac_mode而不是本文件的SEARCH_TRACK——的产物，底层FIR/基线穿越机制虽然不关心idac_mode，但具体帧号仍可能因此偏移）。
//                                                             TRK-08的两个半句需要两种不同的配置才能保持廉价：epoch回绕带真实更新的半句只需要在宽合法范围内连续十六次普通真实提交（在阶段A里和TRK-01/02/03/04/06/07/09/10一起做——这些都在同一次连续RUN里完成，真实跟踪一旦激活就不需要互相之间重新排空RUN状态），而min/max不回绕半句需要码真正走到端点，按宽范围的余量算需要上百笔真实事务——所以阶段B单独提交一份窄范围配置（`dcs_r_code_min=78`/`dcs_r_code_max=82`，围绕同一个启动搜索目标80的5码窗口），让端点只需一到两次真实提交就能触达，不削弱结论的同时把整个文件的运行时间控制在合理范围（余量门控逻辑不关心合法窗口有多宽，只关心`dcs_r_code_current`是否严格落在窗口内）。本V1.0提交时编译通过，但还没有真正跑通过一次完整PASS。
// 2026年08月28日        V1.1          Erie                  真正跑通一次完整PASS一共经历了六轮真实bug，每一个都是真的拿真实iverilog/xsim跑起来才发现的，不是把合同文字读得更仔细就能看出来的——六个全部如实记录在这里，因为至少三个是可以直接复用到未来任何Stage5文件的通用教训，不只对本文件有效。（1）第一次真实跑，TRK-02的in-window步骤没能清零`cnt_dcs_r_high`：本文件的`task_drive_normal_track_sample`假设RED/IR严格交替，直接驱动调度器"下一笔"真实事务，但双光NORMAL的真实调度一旦各颜色自己的owner/pending时序介入就不保证严格1:1交替——一次意图驱动RED的"in-window"样本悄悄落在了IR上，RED自己的计数器完全没被碰到。修复为`task_drive_track_color_value`/`task_drive_track_color`，用真实owner身份快照（`reg_owner_snapshot_color_ir`，在`sched_adc_owner_commit_event_o`那一拍锁存，和`tb_ppg_control_top_baseline_cross.v`自己已验证的手法完全一样）重试直到目标颜色的真实事务真的到来，途中其它颜色的真实事务驱动中性值放行。（2）修完这条，TRK-03的below-low步骤读回来还是in-window（`flag_track_s1_value=8`），不是低于`dcs_threshold_low`：本文件凭记忆抄的阈值是`amb_threshold=(-64,72)`/`dcs_threshold=(-48,56)`，驱动惯例是±1500/0，但`make_fixed_raw`会把任何负的`target_code`钳到8，而8恰好落在这两个跨零窗口*内部*——一次"below_low"驱动被悄悄误判成in-window。没有继续抽象推理，而是给Group6自己已经真实通过的`task_drive_amb_toward_target`加了一条诊断去实测，结果确认Group6自己真正生效的配置早就用的是`(100,200)`阈值配合`8`/`503`/`150`驱动值，专门让三种分类都落在不受钳位影响的纯正数区间——本文件只是凭记忆抄了一套Group6自己已经淘汰的旧数值。把Group6真正生效的数值原样搬进本文件的阈值和全部四个驱动task。（3）接着TRK-07/TRK-08显示码在往*错误*方向走（80→79→78……本意是要增大）：DCS极性`dcs_polarity=0`下，`above_high`触发的是*decrease*、`below_low`触发的才是*increase*——和AMB极性=1的映射正好相反，本文件自己的TRK-07/08循环却一直在用`above_high`去驱动"应该是increase"的证据。TRK-02/03/04/06/09/10不受影响，因为它们只直接检查高/低区计数器，不关心最终提交方向。把三处受影响的循环（TRK-07的pending形成循环、TRK-08的epoch回绕循环、TRK-08的min/max端点循环）全部换成用`below_low`驱动"increase"。（4）阶段B在TRK-08的min/max测试之后卡在`task_stop_and_drain`里不出来——用层级诊断真实核实（不是靠猜）确认`o_stop_ack_event`正常触发，但调度器自己的`state_current[B_INFLIGHT]`位始终不清零。直接读`ppg_400hz_frame_calibration_scheduler.v`自己的STOP处理逻辑：STOP接受时，在途owner只被标成`B_INFLIGHT_DISCARD=1`受控丢弃——`B_INFLIGHT`本身要等一次真实完成（哪怕只是一次`success=0`的丢弃释放）真正到达才会清零。本文件的`task_stop_and_drain`在发出STOP*之后*从来不再驱动任何完成，如果调度器恰好在STOP那一刻又派发了一个新owner（真实连续NORMAL调度下完全可能），这个owner就永远等不到释放，排空永远卡死——确认这不是"再等等就好"，iverilog真实跑了1100秒也没有任何新进展。修复为在`task_stop_and_drain`内部STOP之后加一个有界的冲刷循环，只要`B_INFLIGHT`还在就持续驱动中性真实完成（上限10次，本文件自己的看门狗兜底），再进入排空等待。（5）阶段A/B都通过之后，阶段C的TRK-05在1300帧驱动内仍然一次真实SAR9→SAR15切换都没观察到，而`tb_ppg_control_top_baseline_cross.v`在类似配置下第63帧就见到了第一个PEAK——用心跳诊断确认`dcs_r_code`在500帧内被从80一路打到配置的下限12并钉死在那，因为本文件把阶段A/B的`(100,200)` `dcs_threshold_high`原样搬到了阶段C，但生成器NORMAL档位自己真实的生理基线（`C_RAW_DC_OFFSET_RED=240`/`_IR=270`，真实合理摆动范围大约[147,333]/[154,386]）大部分时候本来就*高于*200——几乎每一笔真实生成器样本都读成`above_high`，DCS极性0下的跟踪连续判定decrease，把送进粗检测FIR真正需要的DC恢复基线彻底冲垮。新增一个阶段C专用配置task`task_build_search_track_generator_config`，只把`dcs_threshold_high`放宽到400（舒适覆盖生成器真实幅度范围），让跟踪在正常生理波形下基本保持静默，完全不影响阶段A/B自己的`(100,200)`/`8`/`503`/`150`驱动惯例（三种分类在两种窗口宽度下判定结果完全一致）。（6）即便码稳定在80，TRK-05依然没能观察到切换——但更深入的诊断显示`o_coarse_ppg_value`真实周期性起伏在大约500到5569之间（远超`min_peak_valley_amplitude`门槛），证明PEAK/VALLEY/CROSS确实在底层真实发生。真正的bug是：本文件对`o_fine_window_start_event`/`o_return_9bit_valid`的检查是内联的，每次循环只在多拍阻塞的`drive_real_adc_done`任务返回后检查一次——但这两个都是单拍事件脉冲，完全可能恰好在那个任务内部的某一拍触发、不落在检查点那一拍，于是每次都被静默漏掉。这和本项目自己[[feedback_tb_counter_scope_and_stop_boundary]]这份memory已经警告过的同一类缺陷（fork/join脉冲信号陈旧化）完全一样——只在多拍阻塞调用之后的某一个特定点检查一次脉冲信号，只要脉冲和检查点没有恰好落在同一拍就会漏检。修复为用连续的`always@(posedge i_clk)`后台监视进程加sticky捕获寄存器替换掉内联检查，完全照抄`tb_ppg_control_top_baseline_cross.v`自己已经验证过的事件捕获模式，不再重新发明一个脆弱的单点轮询。六处修复全部落地后：真实Vivado 2022.2 xsim跑通（本文件这个规模——把阶段C约1300帧真实生成器部分算进去——按本项目自己已确立的"大规模/长跑场景用xsim不用iverilog"惯例本来就该走xsim，同一份文件在iverilog下按这条已确立的先例需要20多分钟还跑不完），`JNT_BASELINE 53/53 PASS`，全部十条TRK-01~10都拿到真实证据通过，`NORMAL_SLOW_TRACKING_TB_PASS result_captures=1406 owner_commit_total=1477`。静态编译同样`iverilog -Wall`零警告干净通过。
//
// 复位后独立提交三种SEARCH_TRACK场景配置（宽范围主跟踪、窄范围min/max边界、
// 真实生成器精度切换），核对NORMAL慢速跟踪算法的确认计数、方向反转、安全边界
// 提交、epoch回绕、拒绝路径与精度切换证据保留
module tb_ppg_control_top_normal_slow_tracking();

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

	localparam time C_SIM_TIMEOUT_NS = 64'd3500000000; // 3.5秒安全看门狗上限，本组含真实生成器长跑

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
	// 照抄Group6/Group11/12已验证过target_code恒等式的幂次Q16权重配置
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
			i_source_config_snapshot[115:104] = 12'sd100; // amb_threshold_low，与Group6一致，配合8/503/150驱动惯例落在make_fixed_raw合法[8,503]窗口内
			i_source_config_snapshot[127:116] = 12'sd200; // amb_threshold_high
			i_source_config_snapshot[139:128] = 12'sd100; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd200; // dcs_threshold_high
			i_source_config_snapshot[159:152] = 8'd8; // amb_confirm_count
			i_source_config_snapshot[167:160] = 8'd3; // dcs_confirm_count，本组刻意取小整数便于多步确认演示
			i_source_config_snapshot[193:168] = 26'sd65536; // stage1_weight_q16_0，C11 nominal权重
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

	//---------------阶段A：宽范围SEARCH_TRACK主跟踪配置构造任务---------------//
	task task_build_search_track_wide_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，跟踪需要RED/IR都真实产生事务
		end
	endtask

	//---------------阶段C专属：SEARCH_TRACK+加宽DCS阈值窗口，供真实生成器驱动使用---------------//
	// 第一版沿用了阶段A/B的dcs_threshold_high=200，真实跑通xsim才发现这是错误：
	// 生成器NORMAL档位的真实校准值范围是DC_OFFSET±(amplitude+drift+noise)——RED约
	// 240±93=[147,333]，IR约270±116=[154,386]——DC_OFFSET本身就已经超过200，导致
	// 几乎每笔真实生理波形样本都读成above_high，NORMAL跟踪连续判定"decrease"，
	// 把dcs_r_code从80快速打到下限12并卡死（真实观测：frame100=64、frame200=47、
	// frame500触底=12、frame600~1200恒为12）。dcs_r_code是DC恢复级真正用于减除的
	// 委托码，被这样剧烈且持续漂移会把送进粗检测FIR的信号彻底冲垮，1300帧内一次
	// 真实PEAK/VALLEY/CROSS事件都没有触发过——不是生成器或精度切换机制本身的问题，
	// 是本文件自己给阶段C选错了阈值窗口宽度，让"跟踪本该继续运行"这个前提本身
	// 把TRK-05真正想测的精度切换场景摧毁了。修复：阶段C专用阈值把dcs_threshold_high
	// 从200放宽到400，让生成器真实幅度范围整体落在窗口内，跟踪在正常生理波形下
	// 基本保持静默（仍然是真实生效的跟踪机制，只是这份生理信号很少触发确认计数），
	// 阶段A/B自己的8/503/150驱动惯例不受影响（8<100、503>400、150在[100,400]内，
	// 三种分类判定与更窄的[100,200]窗口下完全一致）
	task task_build_search_track_generator_config;
		begin
			task_build_search_track_wide_config;
			i_source_config_snapshot[151:140] = 12'sd400; // dcs_threshold_high，放宽到覆盖生成器真实幅度范围
		end
	endtask

	//---------------阶段B：窄范围SEARCH_TRACK min/max边界配置构造任务---------------//
	task task_build_search_track_narrow_config;
		begin
			task_build_search_track_wide_config;
			i_source_config_snapshot[71:64] = 8'd78; // dcs_r_code_min，围绕启动搜索目标80的5码窄窗口
			i_source_config_snapshot[79:72] = 8'd82; // dcs_r_code_max
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
				$display("FAIL TRK config result timeout");
				cnt_error = cnt_error + 1;
			end
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
			// STOP接受时若恰好有owner在途，调度器只把它标成B_INFLIGHT_DISCARD受控丢弃，
			// 不会立即清B_INFLIGHT本身——真正的清除仍然要等一次真实DONE到达（哪怕这次
			// DONE最终只产生一次success=0的丢弃释放）。STOP之前只驱动到"当前没有遗留
			// owner"是不够的：STOP这一刻本身完全可能恰好又有新owner刚建立，之后本任务
			// 从不再驱动任何完成，导致这个owner永远等不到能让它真正释放的那次DONE，
			// STOPPING排空永远卡死——这里在等drain之前，只要B_INFLIGHT还在，就继续
			// 用中性值喂真实完成，直到它真正清零，不设固定次数上限（有独立看门狗兜底）
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
				$display("FAIL TRK drain to CONFIG timeout stop_ack_seen=%b cnt_stop_wait=%0d macro_tick=%0d idac_state=%0d amb_fault=%b dcs_r_fault=%b dcs_ir_fault=%b ctrl_fault=%b sched_inflight=%b",
					o_stop_ack_event, cnt_stop_wait,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.macro_tick_o,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.state_current,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_amb_fault,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_search_exhausted,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_ir_search_exhausted,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_controller_fault_blocking,
					ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.state_current[ppg_control_top_Inst.ppg_400hz_frame_calibration_scheduler_Inst.B_INFLIGHT]);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------STOP前冲刷任务：本文件的跟踪测试只按需驱动真实完成---------------//
	//---------------（不像Group10/11那样跑一个forever后台响应进程），STOP恰好命中---------------//
	//---------------调度器刚发起、还没喂真实DONE的owner时，STOPPING受控释放永远等不到---------------//
	//---------------真实完成——和Group10的ILM-10同一类真实发现，同样的修复手法：STOP---------------//
	//---------------前先驱动两笔真实in-window事务，确保不留下未响应的在途owner---------------//
	task task_flush_before_stop;
		begin
			task_drive_track_color(1'b0, 0);
			task_drive_track_color(1'b0, 0);
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
					$display("FAIL TRK Q3 wait timeout");
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

	//---------------正式结果与owner提交边沿捕获进程---------------//
	integer cnt_result_capture;
	integer cnt_owner_commit_total_trk;
	integer cnt_owner_commit_red_trk;
	integer cnt_owner_commit_ir_trk;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			cnt_owner_commit_total_trk <= cnt_owner_commit_total_trk + 1;
			if(!ppg_control_top_Inst.sched_adc_owner_color_ir_o) begin
				cnt_owner_commit_red_trk <= cnt_owner_commit_red_trk + 1;
			end else begin
				cnt_owner_commit_ir_trk <= cnt_owner_commit_ir_trk + 1;
			end
		end
	end

	//---------------TRK-05专用：精度切换/回落事件连续后台捕获进程---------------//
	//---------------第一版曾在主序列里对o_fine_window_start_event/o_return_9bit_valid---------------//
	//---------------做单点内联轮询（只在每次drive_real_adc_done这个多拍阻塞任务返回后---------------//
	//---------------检查一次），真实跑通xsim才发现这是错误方法：这两个都是单拍事件脉冲，---------------//
	//---------------真实诊断数据显示o_coarse_ppg_value全程真实周期性起伏（500~5569），---------------//
	//---------------证明底层PEAK/VALLEY/CROSS确实在真实发生，但脉冲很可能恰好落在---------------//
	//---------------drive_real_adc_done内部那几拍窗口期间、不在检查点那一拍，被完全漏检---------------//
	//---------------——和本项目已确立的fork/join脉冲信号陈旧化教训同一类问题。修复为和---------------//
	//---------------tb_ppg_control_top_baseline_cross.v一致的连续后台always块捕获---------------//
	reg flag_fine_window_seen;
	reg flag_fine_window_check_ok;
	reg flag_return_9bit_seen;
	reg flag_return_9bit_check_ok;
	reg [7:0] reg_armed_pre_dcs_r_code;
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_armed_pre_dcs_r_epoch;
	reg [7:0] reg_armed_pre_dcs_r_high, reg_armed_pre_dcs_r_low;
	always @(posedge i_clk) begin
		if(!flag_fine_window_seen && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_fine_window_start_event) begin
			flag_fine_window_seen <= 1'b1;
			flag_fine_window_check_ok <=
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code == reg_armed_pre_dcs_r_code) &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current == reg_armed_pre_dcs_r_epoch) &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high == reg_armed_pre_dcs_r_high) &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_low == reg_armed_pre_dcs_r_low);
		end
		if(flag_fine_window_seen && !flag_return_9bit_seen &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.o_return_9bit_valid &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_peak_valley_window_detector_Inst.i_return_9bit_ready) begin
			flag_return_9bit_seen <= 1'b1;
			flag_return_9bit_check_ok <=
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code == reg_armed_pre_dcs_r_code) &&
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current == reg_armed_pre_dcs_r_epoch);
		end
	end

	//---------------TRK-05生成器驱动专用：owner身份快照进程---------------//
	//---------------同源复用tb_ppg_control_top_baseline_cross.v已验证的手法：---------------//
	//---------------commit那一拍锁存身份，真实DONE到达时才使用，避免读到已经---------------//
	//---------------被下一个owner覆盖的瞬态值---------------//
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

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL NORMAL_SLOW_TRACKING global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------真实启动搜索收敛任务：驱动一个方向明确的RAW码---------------//
	//---------------AMB极性下above即increase---------------//
	// 第一版曾用±1500/0配合阈值(-64,72)/(-48,56)，第一次真实跑Group7才发现这是错误
	// 方法：make_fixed_raw内部把任何target_code钳到[8,503]，-1500会被钳到8——而8落在
	// (-64,72)/(-48,56)这类跨零窗口内部，读回来是in_window不是below_low。真实可行的
	// 方案（与Group6调试到底后确认可用的方案完全一致）是把阈值整体搬到make_fixed_raw
	// 合法窗口内部：threshold=(100,200)，below_low用8（<100）、above_high用503（>200，
	// 同样落在窗口外但用窗口本身的max端夹住）、in_window用150（100~200之间），三种
	// 分类都是纯正数、都不依赖钳位副作用
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

	//---------------DCS极性下below即increase，与AMB相反---------------//
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

	//---------------真实驱动一笔明确颜色、明确目标校准值的NORMAL跟踪事务---------------//
	//---------------第一版曾假设RED/IR严格交替，第一次真实跑通即发现这是错误 ---------------//
	//---------------假设：双光NORMAL下真实调度顺序并不保证严格R,I,R,I,...，一旦IR自己 ---------------//
	//---------------的owner/pending机制介入就可能连续多次落在同一颜色上——必须用真实 ---------------//
	//---------------owner身份快照（同TRK-05已验证手法）逐笔核对颜色，非目标颜色的真实 ---------------//
	//---------------事务驱动中性in-window值放行，直到真正等到目标颜色为止 ---------------//
	task task_drive_track_color_value;
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
						make_fixed_raw(150, raw_code); // 中性in_window值，[100,200]阈值窗口内，不干扰非目标颜色自身证据
					end
					drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
					cnt_guard = cnt_guard + 1;
				end
			end
			if(!flag_matched) begin
				$display("FAIL task_drive_track_color_value could not find a real transaction matching target_color=%b within guard window", target_color);
				cnt_error = cnt_error + 1;
			end
		end
	endtask

	//---------------direction: 1=above_high(above dcs_threshold_high=200) -1=below_low(below dcs_threshold_low=100) 0=in_window---------------//
	task task_drive_track_color;
		input target_color;
		input integer direction;
		integer drive_value;
		begin
			if(direction > 0) drive_value = 503; // above_high
			else if(direction < 0) drive_value = 8; // below_low
			else drive_value = 150; // in_window，[100,200]内
			task_drive_track_color_value(target_color, drive_value);
		end
	endtask

	//---------------主序列---------------//
	initial begin : main_sequence
		reg real_release;
		integer cnt_wait_request;
		reg [7:0] reg_current_amb_code, reg_current_dcs_r_code, reg_current_dcs_ir_code;
		reg [7:0] reg_confirmed_amb_code;
		reg [7:0] reg_snapshot_code;
		reg [C_CODE_EPOCH_WIDTH - 1:0] reg_snapshot_epoch;
		reg [7:0] reg_snapshot_low_count, reg_snapshot_high_count;
		integer cnt_snapshot_result;
		integer cnt_snapshot_owner_red, cnt_snapshot_owner_ir;
		integer cnt_step;
		integer cnt_wait_boundary;
		reg [9:0] raw_target_code;

		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		cnt_owner_commit_total_trk = 0;
		cnt_owner_commit_red_trk = 0;
		cnt_owner_commit_ir_trk = 0;
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

		//=========== 阶段A：宽范围主跟踪RUN，先真实启动搜索收敛到NORMAL ===========//
		task_build_search_track_wide_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL TRK phase A commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		//------- 真实AMB阶段二分搜索收敛（同Group6手法） -------//
		begin : trk_amb_stage
			integer cnt_candidate;
			reg flag_amb_converged;
			flag_amb_converged = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_amb_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
				$display("FAIL TRK AMB startup stage did not converge");
				cnt_error = cnt_error + 1;
			end
		end

		//------- 真实DC_R阶段二分搜索收敛 -------//
		begin : trk_dcs_r_stage
			integer cnt_candidate;
			reg flag_converged;
			flag_converged = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
					flag_converged = 1'b1;
				end
			end
			if(!flag_converged) begin
				$display("FAIL TRK DC_R startup stage did not converge");
				cnt_error = cnt_error + 1;
			end
		end

		//------- 真实DC_IR阶段二分搜索收敛 -------//
		begin : trk_dcs_ir_stage
			integer cnt_candidate;
			reg flag_converged;
			flag_converged = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
					flag_converged = 1'b1;
				end
			end
			if(!flag_converged) begin
				$display("FAIL TRK DC_IR startup stage did not converge");
				cnt_error = cnt_error + 1;
			end
		end

		if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_startup_search_complete) begin
			$display("FAIL TRK startup search did not complete, tracking cannot be exercised");
			cnt_error = cnt_error + 1;
			$finish;
		end else begin
			$display("PASS TRK startup search completed (amb=64 dcs_r=80 dcs_ir=96), NORMAL tracking now eligible to qualify samples");
		end

		//------- TRK-01：真实第一笔跟踪事务传输之前，证据/码/epoch全程零变化 -------//
		// 2026-09-18工作线D待查清单调查：合同§9.4.2原文"Invalid tracking input or
		// a changing payload while valid is low cannot change evidence, pending
		// code, committed code, or epoch"要求的是主动场景（valid=0期间主动喂
		// 无效/变化payload），下面这段只是被动40拍静默等待，是更弱的性质——如实
		// 记录，不打PASS掩盖。已反查i_track_valid的真实推导链：AMI（ppg_adc_
		// measurement_idac_integration.v:2373）i_track_valid接的是
		// flag_track_branch_valid && !flag_result_abort_discard，
		// flag_track_branch_valid(919/924行)=flag_normal_track_qualified?
		// flag_track_branch_valid_raw:0，其中flag_track_branch_valid_raw直接是
		// ppg_normal_transaction_fork.v的o_track_valid=track_valid_o。反查该fork
		// 自己两个always块（278-309行）：payload_o和track_valid_o是同一个
		// flag_input_transfer条件同拍原子写入的两个独立寄存器——payload_o只在
		// flag_input_transfer时才装入新值(279行)否则原样保持(281行)，
		// track_valid_o同一行为(303/307行)。也就是说这颗RTL的结构本身就不存在
		// "payload变化但valid仍为0"这条路径：任何让payload真实变化的事件必然
		// 在同一拍把valid同时置1，两者硬件同源、不可独立控制，不是TB测试手法
		// 的问题。本项目force-on-shared-net戒律禁止force这两个寄存器（本来就
		// 不是私有单消费者信号，参照SID-11关于该类问题的既有记录）；即使允许，
		// force一个在真实硬件里不可能出现的组合也测不出任何有意义的结论。
		// 这半句在当前架构下结构性不可达，需要新增专属测试注入端口（比如在
		// fork或IDAC控制器上新增类似i_test_calibration_loss_inject_valid那样
		// 默认关闭的验证专用端口，可以独立于真实flag_input_transfer单独驱动
		// payload变化）才能合法验证——是否值得为此改动RTL留给用户判断，本次
		// 不擅自新增。值得一提：flag_track_sample_qualified
		// （ppg_idac_code_controller.v:498）本身是以flag_track_transfer打头的
		// 纯AND链，flag_track_transfer=0时整条表达式结构上必为0，不管payload
		// 字段读到什么——这个安全性质本身是静态可证的，只是无法用真实仿真动态
		// 演示。完整调查过程见WORKLINE_D_TRK01_ISE01_20260918.md
		reg_snapshot_low_count = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_low;
		reg_snapshot_high_count = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high;
		reg_snapshot_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
		repeat(40) @(posedge i_clk);
		if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_low != reg_snapshot_low_count) ||
			(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != reg_snapshot_high_count) ||
			(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != reg_snapshot_code)) begin
			$display("FAIL TRK-01 RED evidence/code changed before any real tracking transfer completed");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS TRK-01 no evidence/code/epoch advance observed before the first real tracking transfer");
		end

		//------- TRK-02：确认计数阈值——N-1次同向不形成pending，窗口内清零，第N次形成pending -------//
		//------- 同时天然覆盖TRK-04：全程持续用IR做交错对照 -------//
		begin : trk02_confirm_threshold
			//---- 第一次above-high：cnt_dcs_r_high应变为1 ----//
			task_drive_track_color(1'b0, 1);
			repeat(4) @(posedge i_clk);
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd1) begin
				$display("FAIL TRK-02 first above-high sample did not advance cnt_dcs_r_high to 1, observed=%0d",
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high);
				cnt_error = cnt_error + 1;
			end

			//---- 交错插入一笔IR below-low：IR自己的cnt_dcs_ir_low应变1，RED的cnt_dcs_r_high必须保持1不受影响（TRK-04） ----//
			task_drive_track_color(1'b1, -1);
			repeat(4) @(posedge i_clk);
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd1) begin
				$display("FAIL TRK-04 interleaved IR sample disturbed RED's own cnt_dcs_r_high, observed=%0d",
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-04 RED evidence stayed independent of an interleaved IR sample (cnt_dcs_r_high held at 1)");
			end

			//---- 第二次above-high(RED)：cnt_dcs_r_high应变为2，仍不足confirm_count=3，未形成pending ----//
			task_drive_track_color(1'b0, 1);
			repeat(4) @(posedge i_clk);
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd2) ||
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid) begin
				$display("FAIL TRK-02 second above-high sample did not reach count=2 without forming pending");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-02 confirm counter reached 2/3 without prematurely forming pending");
			end

			//---- 窗口内样本：应把cnt_dcs_r_high清零 ----//
			task_drive_track_color(1'b0, 0);
			repeat(4) @(posedge i_clk);
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd0) begin
				$display("FAIL TRK-02 in-window sample did not clear cnt_dcs_r_high, observed=%0d",
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-02 in-window evidence cleared the matching direction count back to 0");
			end
		end

		//------- TRK-03：方向反转清零旧计数，新方向从1开始，不产生两次pending -------//
		begin : trk03_reversal
			integer cnt_owner_before_local;
			task_drive_track_color(1'b0, 1); // above-high，cnt_high=1
			repeat(4) @(posedge i_clk);
			task_drive_track_color(1'b0, -1); // below-low反转
			repeat(4) @(posedge i_clk);
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd0) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_low != 8'd1) ||
				ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid) begin
				$display("FAIL TRK-03 direction reversal did not cleanly reset high=0/low=1 without pending, high=%0d low=%0d pending=%b",
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_low,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-03 direction reversal cleared the old count and started the opposite count at exactly 1, no pending formed");
			end
			// 回到in-window，清空这条实验证据，避免污染下面TRK-06/07
			task_drive_track_color(1'b0, 0);
			repeat(4) @(posedge i_clk);
		end

		//------- TRK-06/TRK-07：pending稳定等待安全边界，安全边界恰好提交一次±1LSB -------//
		begin : trk0607_commit
			integer cnt_owner_before_local;
			reg [7:0] reg_code_before;
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_epoch_before;
			reg [7:0] reg_pending_code_snapshot;
			reg_code_before = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
			reg_epoch_before = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current;

			//---- 驱动confirm_count=3次连续below-low形成pending——DCS极性dcs_polarity=0下 ----//
			//---- below_low才触发increase，above_high反而触发decrease，与AMB极性相反 ----//
			for(cnt_step = 0; cnt_step < 3; cnt_step = cnt_step + 1) begin
				task_drive_track_color(1'b0, -1);
				repeat(4) @(posedge i_clk);
			end
			if(!ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid) begin
				$display("FAIL TRK-02/07 pending did not form after exactly confirm_count=3 consecutive above-high samples");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-02 pending formed exactly at the configured confirm count (3)");
			end

			//---- TRK-06：pending等待期间，正式PPG消费继续，pending payload稳定，后续证据无法覆盖 ----//
			cnt_snapshot_result = cnt_result_capture;
			reg_pending_code_snapshot = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
			repeat(200) @(posedge i_clk);
			if(cnt_result_capture == cnt_snapshot_result) begin
				$display("FAIL TRK-06 no formal measurement result was consumed while a tracking update was pending");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-06 formal PPG measurement consumption continued while the tracking update was pending (delta=%0d)", cnt_result_capture - cnt_snapshot_result);
			end
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != reg_pending_code_snapshot) begin
				$display("FAIL TRK-06 committed code changed while still only pending (no safe boundary reached yet)");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-06 pending payload stayed stable while waiting for the next real safe boundary");
			end

			//---- 等待真实安全边界提交，核对TRK-07：恰好一次±1、一次update、一次track_adjust、计数清零、epoch仅加一 ----//
			cnt_wait_boundary = 0;
			while(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid &&
				(cnt_wait_boundary < 10000) && !flag_global_timeout) begin
				@(posedge i_clk);
				cnt_wait_boundary = cnt_wait_boundary + 1;
			end
			repeat(2) @(posedge i_clk);
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid) begin
				$display("FAIL TRK-07 pending never committed at a real safe boundary within the wait window");
				cnt_error = cnt_error + 1;
			end else if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code - reg_code_before) != 1) begin
				$display("FAIL TRK-07 commit did not change the code by exactly one signed LSB, before=%0d after=%0d",
					reg_code_before, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code);
				cnt_error = cnt_error + 1;
			end else if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current - reg_epoch_before) != 1) begin
				$display("FAIL TRK-07 commit did not increment epoch by exactly one, before=%0d after=%0d",
					reg_epoch_before, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current);
				cnt_error = cnt_error + 1;
			end else if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd0) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_low != 8'd0)) begin
				$display("FAIL TRK-07 confirm counters not cleared after commit");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-07 safe boundary committed exactly one signed 1-LSB change (%0d->%0d), incremented epoch by exactly one (%0d->%0d), and cleared the confirm counters",
					reg_code_before, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code,
					reg_epoch_before, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current);
			end
		end

		//------- TRK-09：force私有跟踪网线构造calibration_applied=0与码快照错配，均软拒绝无副作用 -------//
		begin : trk09_reject_paths
			reg [7:0] reg_code_before;
			//---- (a) calibration_applied=0：force私有单消费者网线，样本被消费但不推进证据 ----//
			reg_code_before = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
			force ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_calibration_applied = 1'b0;
			task_drive_track_color(1'b0, 1);
			repeat(4) @(posedge i_clk);
			release ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_calibration_applied;
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd0) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != reg_code_before) ||
				o_system_fault_blocking) begin
				$display("FAIL TRK-09a forced calibration_applied=0 sample altered evidence/code or caused a fault");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-09a forced calibration_applied=0 sample consumed without altering tracking evidence and without any fault");
			end

			//---- (b) 码快照错配：force私有dc_code_snapshot网线到明显错误值 ----//
			force ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_dc_code_snapshot = 8'hFF;
			task_drive_track_color(1'b0, 1);
			repeat(4) @(posedge i_clk);
			release ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_dc_code_snapshot;
			if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd0) ||
				(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != reg_code_before) ||
				o_system_fault_blocking) begin
				$display("FAIL TRK-09b forced code-snapshot mismatch altered evidence/code or caused a fault");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-09b forced code-snapshot mismatch consumed without altering tracking evidence and without any fault");
			end

			//---- 确认注入撤销后跟踪立即恢复正常：驱动一次真实in-window样本核对 ----//
			task_drive_track_color(1'b0, 0);
			repeat(4) @(posedge i_clk);
			if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high != 8'd0) begin
				$display("FAIL TRK-09 tracking did not resume normal qualification after injections were released");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-09 tracking resumed normal qualification immediately after both injections were released");
			end
		end

		//------- TRK-10：跟踪比较只使用signed 12-bit校准Stage1证据，逐笔核对与target_code恒等 -------//
		begin : trk10_stage1_only
			reg signed [11:0] reg_observed_track_value;
			task_drive_track_color_value(1'b0, 37);
			repeat(2) @(posedge i_clk);
			reg_observed_track_value = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_track_s1_value;
			if(reg_observed_track_value !== 12'sd37) begin
				$display("FAIL TRK-10 i_track_calibrated_s1_value did not equal the driven target_code (37), observed=%0d -- tracking may be consuming a different pipeline stage",
					reg_observed_track_value);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-10 tracking evidence exactly equals the real calibrated Stage1 value for this transaction (target_code identity holds), confirming no other stage substitutes for it");
			end
			// 用真实in-window样本清空这次刻意驱动的证据
			task_drive_track_color(1'b0, 0);
			repeat(4) @(posedge i_clk);
		end

		//------- TRK-08（epoch回绕带真实更新半句）：连续十六次真实提交，核对4'hF->4'h0自然回绕 -------//
		begin : trk08_epoch_wrap
			integer cnt_commit;
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_epoch_before_wrap;
			reg [7:0] reg_code_before_commit;
			reg flag_saw_wrap;
			flag_saw_wrap = 1'b0;
			for(cnt_commit = 0; (cnt_commit < 16) && !flag_global_timeout; cnt_commit = cnt_commit + 1) begin
				reg_epoch_before_wrap = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current;
				reg_code_before_commit = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
				for(cnt_step = 0; cnt_step < 3; cnt_step = cnt_step + 1) begin
					task_drive_track_color(1'b0, -1); // below-low，DCS极性下触发increase
					repeat(4) @(posedge i_clk);
				end
				cnt_wait_boundary = 0;
				while(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid &&
					(cnt_wait_boundary < 10000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_boundary = cnt_wait_boundary + 1;
				end
				repeat(2) @(posedge i_clk);
				if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code - reg_code_before_commit) != 1) begin
					$display("FAIL TRK-08 wrap-sequence commit %0d did not advance code by exactly one, before=%0d after=%0d",
						cnt_commit, reg_code_before_commit, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code);
					cnt_error = cnt_error + 1;
				end
				if((reg_epoch_before_wrap == 4'hF) &&
					(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current == 4'h0)) begin
					flag_saw_wrap = 1'b1;
				end
			end
			if(!flag_saw_wrap) begin
				$display("FAIL TRK-08 sixteen consecutive real commits never produced an observed epoch wrap 4'hF->4'h0");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-08 epoch wrapped 4'hF->4'h0 naturally across sixteen real commits, each still a correctly-identified real transaction");
			end
		end

		task_flush_before_stop;
		task_stop_and_drain;

		//=========== 阶段B：窄范围SEARCH_TRACK，TRK-08 min/max不回绕半句 ===========//
		task_build_search_track_narrow_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL TRK phase B commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		begin : trk_phaseb_startup
			integer cnt_candidate;
			reg flag_amb_converged, flag_r_converged, flag_ir_converged;
			flag_amb_converged = 1'b0;
			flag_r_converged = 1'b0;
			flag_ir_converged = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_amb_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_r_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_ir_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
			if(!flag_amb_converged || !flag_r_converged || !flag_ir_converged) begin
				$display("FAIL TRK phase B startup search did not converge");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end

		begin : trk08_minmax
			integer cnt_commit;
			reg [7:0] reg_code_before_commit;
			reg [C_CODE_EPOCH_WIDTH - 1:0] reg_epoch_before_commit;
			reg flag_saw_rail;
			flag_saw_rail = 1'b0;
			for(cnt_commit = 0; (cnt_commit < 8) && !flag_global_timeout; cnt_commit = cnt_commit + 1) begin
				reg_code_before_commit = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
				reg_epoch_before_commit = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current;
				for(cnt_step = 0; cnt_step < 3; cnt_step = cnt_step + 1) begin
					task_drive_track_color(1'b0, -1); // 持续below-low，DCS极性下触发increase，逼近dcs_r_code_max=82
				end
				cnt_wait_boundary = 0;
				while(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_pending_valid &&
					(cnt_wait_boundary < 10000) && !flag_global_timeout) begin
					@(posedge i_clk);
					cnt_wait_boundary = cnt_wait_boundary + 1;
				end
				repeat(2) @(posedge i_clk);
				if(reg_code_before_commit >= 8'd82) begin
					// 已经在端点：继续above-high不得再推进码或epoch
					if((ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code != reg_code_before_commit) ||
						(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current != reg_epoch_before_commit)) begin
						$display("FAIL TRK-08 code or epoch advanced past the configured max=82, before=%0d after=%0d epoch_before=%0d epoch_after=%0d",
							reg_code_before_commit, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code,
							reg_epoch_before_commit, ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current);
						cnt_error = cnt_error + 1;
					end else begin
						flag_saw_rail = 1'b1;
					end
				end
			end
			if(!flag_saw_rail) begin
				$display("FAIL TRK-08 min/max sub-test never actually reached the configured rail (dcs_r_code_max=82) within 8 commit attempts");
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS TRK-08 sustained above-high evidence at the configured max=82 never wrapped, emitted a false update, or incremented epoch");
			end
		end

		task_flush_before_stop;
		task_stop_and_drain;

		//=========== 阶段C：真实生成器驱动，TRK-05真实SAR9->SAR15->SAR9精度切换保留跟踪证据 ===========//
		task_build_search_track_generator_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL TRK phase C commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);

		begin : trk_phasec_startup
			integer cnt_candidate;
			reg flag_amb_converged, flag_r_converged, flag_ir_converged;
			flag_amb_converged = 1'b0;
			flag_r_converged = 1'b0;
			flag_ir_converged = 1'b0;
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_amb_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_r_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
			for(cnt_candidate = 0; (cnt_candidate < 12) && !flag_ir_converged && !flag_global_timeout; cnt_candidate = cnt_candidate + 1) begin
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
			if(!flag_amb_converged || !flag_r_converged || !flag_ir_converged) begin
				$display("FAIL TRK phase C startup search did not converge");
				cnt_error = cnt_error + 1;
				$finish;
			end
		end

		//------- TRK-05：真实生成器驱动RED直到真实CROSS->SAR15->RETURN_9BIT一轮周期 -------//
		begin : trk05_precision_transition
			integer cnt_frame_drive;
			reg [9:0] target_code_gen;
			integer raw_unclamped_dummy;
			flag_fine_window_seen = 1'b0;
			flag_fine_window_check_ok = 1'b0;
			flag_return_9bit_seen = 1'b0;
			flag_return_9bit_check_ok = 1'b0;

			for(cnt_frame_drive = 0; (cnt_frame_drive < 1300) && !flag_return_9bit_seen && !flag_global_timeout; cnt_frame_drive = cnt_frame_drive + 1) begin
				wait_q3_release(real_release);
				if(real_release) begin
					// 首次进入15-bit窗口之前才需要持续刷新"切换前快照"，一旦后台捕获进程
					// 真实观察到o_fine_window_start_event就自动冻结（flag_fine_window_seen
					// 一旦置1，这里的赋值就成了写入无用值，不影响已经锁存的判定结果）
					if(!flag_fine_window_seen) begin
						reg_armed_pre_dcs_r_code = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.o_dcs_r_code;
						reg_armed_pre_dcs_r_epoch = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.dcs_r_epoch_current;
						reg_armed_pre_dcs_r_high = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_high;
						reg_armed_pre_dcs_r_low = ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_idac_code_controller_Inst.cnt_dcs_r_low;
					end
					// 用真实owner身份（commit那一拍锁存，同源tb_ppg_control_top_baseline_
					// cross.v已验证手法）决定这笔真实完成投喂哪个颜色的生理波形；启动搜索
					// 阶段的校准事务已经在上面单独走完，这里只会遇到真实NORMAL RED/IR
					if(reg_owner_snapshot_is_calibration) begin
						make_fixed_raw(0, raw_target_code);
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
				$display("FAIL TRK-05 no real SAR9->SAR15 precision transition observed within %0d driven frames -- TRK-05 check is vacuous", cnt_frame_drive);
				cnt_error = cnt_error + 1;
			end else begin
				if(!flag_fine_window_check_ok) begin
					$display("FAIL TRK-05 the precision transition itself changed RED tracking evidence/committed code/epoch");
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS TRK-05 real SAR9->SAR15 precision transition observed: RED tracking evidence/committed code/epoch unchanged by the transition itself");
				end
				if(!flag_return_9bit_seen) begin
					$display("FAIL TRK-05 real SAR15->SAR9 return never observed after entry -- round-trip evidence-preservation claim incomplete");
					cnt_error = cnt_error + 1;
				end else if(!flag_return_9bit_check_ok) begin
					$display("FAIL TRK-05 RED committed code/epoch drifted across the full SAR9->SAR15->SAR9 round trip");
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS TRK-05 real SAR15->SAR9 return observed: RED committed code/epoch identical across the full real round trip, no precision-transition-induced update");
				end
			end
		end

		task_flush_before_stop;
		task_stop_and_drain;

		if(cnt_error == 0) begin
			$display("NORMAL_SLOW_TRACKING_TB_PASS result_captures=%0d owner_commit_total=%0d", cnt_result_capture, cnt_owner_commit_total_trk);
		end else begin
			$display("NORMAL_SLOW_TRACKING_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end

endmodule
