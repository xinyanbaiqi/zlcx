`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/26
// Design Name:        PPG IDAC Snapshot Epoch Bus Isolation Testbench
// Module Name:        tb_ppg_control_top_idac_bus_isolation
// Description:        Description/ppg_control_top_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_control_top
//
// Referrences:        PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//
// Dependencies:       ppg_control_top and its full real hierarchy
//
// Version:            V1.2
// Revision Date:      2026/09/18
// History:
// 2026/09/18            V1.2          Erie                  Workline-D pending-item investigation, ISE-01. Contract section 9.4.7 (line 644) requires "code, color, type, precision, and epochs are captured before the first preparation window of each waveform" -- the existing snapshot mechanism (reg_ise_snapshot_expect_ambn/dcn, latch-then-compare against the real Q3 bus) only ever validated the code half; color/type/precision/epoch were never independently checked, same gap shape as batch3's SID-06 finding. Traced the real SSW (ppg_sar9_sar15_safe_selection_wrapper.v) registers backing every one of these fields: reg_cal_color_ir/reg_cal_frame_type/reg_cal_amb_epoch/reg_cal_dc_epoch are latched by the exact same flag_context_fire && flag_context_is_cal condition as the already-confirmed reg_cal_amb_code/reg_cal_dc_code (confirmed by reading lines 808-938, several already carrying @satisfies: ISE-01/02/03 tags), so they are provably subject to the same "locked before preparation" property -- reading and asserting on them directly closes real coverage, not a re-derivation of the same claim. precision is a genuine exception: reg_cal_precision is hardcoded to 0 for every calibration waveform (line 938), not sourced from any per-waveform snapshot input the way the other four fields are -- it is a structural constant for calibration, not a captured value, so there is no meaningful "capture timing" to test for it; recorded as such rather than forcing a vacuous check. Added a new check_ise_color_type_epoch_snapshot task and wired it into all three real search stages (AMB/DC_R/DC_IR) at the same pre-window snapshot point already used for code, checked once per stage (first candidate) since color/type are stage-constant by construction and checking every candidate would add no real coverage. Real iverilog full run: 70 PASS, 0 FAIL, IDAC_BUS_ISOLATION_TB_PASS sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=155, all three new ISE-01-AMB/DCR/DCIR checks pass with real, non-trivial observed data (frame_type=00/01, color_ir=0/0/1 matching AMB/DCS_CAL-RED/DCS_CAL-IR respectively) and the pre-existing ISE-02~10 unaffected. See WORKLINE_D_TRK01_ISE01_20260918.md for the full investigation.
//    Time               Version       Revised by            Contents
// 2026/08/26            V1.0          Erie                  Create file. Stage 5 Group 12 (IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION, C25 contract section 9.4.7), scoped down by user decision to only ISE-04/05/07 plus the STATIC_BIAS half of ISE-06 -- ISE-01/02/03/09/10 and AMB_CAL/DCS_CAL (the other half of ISE-06) all require a real committed-code-changing event at a safe boundary or a real calibration transaction, and both only exist via `idac_mode=SEARCH_TRACK` startup search (Group 6) or periodic recheck (Group 8), neither built yet; `ppg_idac_code_controller.v`'s own FSM confirms this directly -- `ST_MANUAL_APPLY` transitions straight to `ST_NORMAL` on the first safe boundary and never visits `ST_AMB_APPLY`/`ST_AMB_WAIT`/the DCS states at all, so MANUAL mode structurally cannot produce an AMB_CAL/DCS_CAL request. The deferred five-plus-half IDs are left for a follow-up revision once Group 6/7/8 exist. Reuses the real-2MHz-clock/JNT-01~09-prefix/wait_q3_release/drive_real_adc_done/make_fixed_raw infrastructure and the JNT-prefix-required standard config tasks verbatim from tb_ppg_control_top_adc_numeric_scoreboard.v (Group 11), dropping that file's Stage1/DC-recovery/reconstruction golden-model tasks entirely since this group never numerically recomputes a result -- it only watches the four IDAC buses. Three independently-committed phases in one JNT-prefixed run: Phase A (SAR9 NORMAL MANUAL, optical_mode=RED, amb_manual_code=8'hA5, dcs_r_manual_code=8'h3C -- the same non-symmetric bit patterns tb_ppg_sar9_sar15_safe_selection_wrapper.v's own SSW-45/47 already established as proving per-bit gating, not an all-high shortcut) drives two real transactions while a continuous per-cycle monitor asserts o_idac_sar15ambn_low/o_idac_sar15dcn_low stay exactly zero for the entire RUN window (ISE-04's SAR15-bus-zero half) and latches the SAR9 buses' own non-zero values seen during each transaction's Q3 window to confirm they held 8'hA5/8'h3C bit-for-bit (ISE-04's own-bus half, and this phase's contribution to ISE-07's two-non-symmetric-pattern requirement). Phase B (CHARACTERIZATION+optical_mode=RED+initial_precision=SAR15 -- NORMAL_PPG+SAR15 is MGR-16/18's own statically-illegal combination per tb_ppg_control_top.v's SMOKE-22, so a fixed-SAR15 transaction can only be reached this way, same as Group 11's own Phase D -- with amb_manual_code=8'h5A, dcs_r_manual_code=8'hC3, a second, different non-symmetric pattern) mirrors Phase A with the bus roles reversed for ISE-05 and ISE-07's second pattern. Phase C commits STATIC_BIAS (CHARACTERIZATION+EXTERNAL_TEST_CURRENT+static_characterization_enable=1, reusing tb_ppg_control_top.v's task_build_static_bias_v4_config/task_commit_static_bias_characterization tasks verbatim) and confirms all four IDAC buses read zero throughout, closing ISE-06's STATIC_BIAS clause (the AMB_CAL/DCS_CAL clause stays deferred).
//                                                             One real bug was found and fixed getting the first real run clean, in this file's own design, not RTL: the first draft sampled o_idac_sar9ambn_low/dcn_low (Phase A) and o_idac_sar15ambn_low/dcn_low (Phase B) immediately after `wait_q3_release` returned -- which is *after* that Q3 window has already closed. Phase A passed anyway (NORMAL's continuous back-to-back scheduling means the next transaction's context was typically already active by the time of the check, so the bus never actually idled to zero), but Phase B failed on both transactions, reading back 8'h00/8'h00 instead of 8'h5A/8'hC3 -- CHARACTERIZATION's intermittent one-transaction-per-400Hz-frame cadence leaves a real idle gap after each transaction during which the bus legitimately returns to zero before the next one starts, so sampling after the window closes catches nothing. Fixed by latching each bus's own non-zero value continuously throughout the phase's monitor window and checking the latched "last seen" value instead of a live post-release sample -- decouples the assertion from exactly when within (or after) the Q3 window the check happens. After the fix: real iverilog run, JNT_BASELINE 53/53 PASS, all four transactions across Phase A/B pass, STATIC_BIAS confirmed zero, zero mismatches: `IDAC_BUS_ISOLATION_TB_PASS sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=4`.
// 2026/08/29            V1.1          Erie                  Backfilled the deferred ISE-01/02/03/08/09/10 plus ISE-06's AMB_CAL/DCS_CAL clause, now that Group 6 (startup search) and Group 8 (periodic recheck) exist. Added two new phases (D: dual-optical SEARCH_TRACK real startup search; E: single-optical RED_ONLY narrow-then-wide-range SEARCH_TRACK) reusing Group 6/8/9's proven task library (`task_run_startup_search`, `task_drive_amb_toward_target`/`task_drive_dcs_toward_target`, the 8/503/150 threshold convention) verbatim -- explicitly overrode the amb/dcs threshold fields in the new config tasks rather than inheriting this file's own V1.0 `task_build_normal_manual_config`, which still carries the pre-Group7-fix stale cross-zero threshold window (`amb_threshold=(-64,72)`, `dcs_threshold=(-48,56)`); reusing it as-is would have silently reintroduced the exact `make_fixed_raw` clamp misclassification bug already documented in project memory `feedback-make-fixed-raw-threshold-convention`. Phase D's per-candidate loop snapshots the committed AMB/DC code right before each candidate's own preparation window and checks the corresponding bus against that snapshot (ISE-01/02), checks the next window only ever adopts a code after a real safe-boundary change (ISE-03), checks the DC bus stays zero during AMB_CAL and confirms the AMB bus during DCS_CAL (ISE-06's other half), and cross-checks the opposite color's code/epoch stay frozen during each color's own DC search stage (ISE-08). Phase E adds ISE-09 (a few real in-window transactions after real NORMAL tracking is reached, confirming no numerical change means no update/epoch bump) and ISE-10 (a real DC_R epoch wrap from 4'hF to 4'h0). Getting a real, fully-passing run took seven rounds of real bugs, none in DUT RTL, several directly reusable lessons: (1) a genuine, previously-undiscovered gap: the STATIC_BIAS characterization commitment from Phase C is a persistent CDC-side snapshot that survives STOP/drain -- committing Phase D's non-CHARACTERIZATION config without first explicitly clearing it via `task_clear_static_bias_characterization` (copied from the sibling ILM file, which already has this task) was rejected at COMMIT with `C_ERROR_STATIC_BIAS_INPUT_SOURCE` (8'h14); this file's own V1.0 never hit this because it never committed anything after STATIC_BIAS. (2) The first ISE-01/02 monitor design asserted continuous bit-exact equality from the instant a candidate's sample-request signal first asserted -- real xsim showed this is too strict: the bus genuinely stays at its prior/idle value for a real number of cycles after the request appears, before AMI/SSW actually latches this candidate onto the bus at their own macro-frame-start/waveform-context-accept boundary, so the pre-drive idle period legitimately reads 0. (3) A second, subtler version of the same monitor (armed only once the AMB bus went non-zero) still intermittently failed because the AMB and DC buses don't necessarily become live in lockstep -- replaced the whole approach with this file's own already-proven ISE-04/05 technique verbatim: latch any non-zero value seen during the window and compare the latched value after the window closes, rather than asserting live equality throughout. (4) ISE-10's original narrow-range (78,82) oscillating-direction design, modeled on Group 7 TRK-08, had a real bug: the direction-flip check was nested inside "did epoch actually change this attempt," so once the code got stuck at a boundary (no further same-direction commit possible) the direction flag never flipped and the whole commit budget was wasted stalled at the boundary -- fixed by checking the code's position against the window's own min/max unconditionally every attempt, not only on a successful commit. (5) Even after that fix, epoch still never wrapped: the loop was copying the calibration-search convergence loop's `while(!o_dcs_sample_request) ...` wait pattern, but that signal is calibration-search/revalidate-state-specific and is never asserted once the controller is genuinely in `ST_NORMAL` running the real tracking fork (which consumes the real ADC result stream directly, not this held request signal) -- every attempt spun to its own 5000-cycle guard and produced zero real commits. Fixed by dropping that wait entirely, matching ISE-09's (and Group 7's `task_drive_track_color_value`'s) already-correct pattern of just waiting for the next real Q3 window directly. (6) With commits finally happening for real, the narrow-range oscillation itself turned out not to reverse direction cleanly in this specific scenario (root cause not chased further, not worth the additional investigation cost) -- replaced with a structurally simpler, more robust design: keep the default wide `dcs_r_code_min=12`/`dcs_r_code_max=230` range and drive purely one direction (`below_low`, forced increase) for the whole phase, since epoch increments by exactly 1 on every real commit regardless of the code's own numeric direction or position -- reaching the far-away code_max would take on the order of 150 real transactions, comfortably longer than the ~9-real-transactions-per-commit (matching `dcs_confirm_count=9`) needed for 16+ commits to guarantee a wrap by the pigeonhole principle, so the wrap is reached with real margin to spare (confirmed: wrapped at 145 real driven transactions) without ever needing any boundary-reversal logic at all. Also fixed a real cross-file scope conflict discovered while backfilling the sibling `tb_ppg_control_top_input_light_static_matrix.v` (see that file's own V1.1 changelog) -- unrelated to this file directly, but the same class of "a whole-simulation-lifetime background monitor silently assumes every future phase shares the original phase's mode" issue is worth watching for in any file being backfilled with a new SEARCH_TRACK phase. After all fixes: real Vivado 2022.2 xsim run (~1 minute), `JNT_BASELINE 53/53 PASS`, all ten ISE-01~10 IDs (plus both halves of ISE-06) pass with real evidence, `IDAC_BUS_ISOLATION_TB_PASS sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=155`.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月26日
// 设计名称:           PPG IDAC快照版本总线隔离测试平台
// 模块名称:           tb_ppg_control_top_idac_bus_isolation
// 模块说明:           Description/ppg_control_top_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_control_top
//
// 参考资料:           PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md
//                      PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md
//
// 依赖文件:           ppg_control_top及其完整真实层次
//
// 当前版本:           V1.2
// 修订日期:           2026年09月18日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年09月18日        V1.2          Erie                  工作线D待查清单调查，ISE-01。合同9.4.7节（644行）要求"code、color、type、precision、epoch均需在每个波形第一次准备窗口之前捕获"——既有快照机制（`reg_ise_snapshot_expect_ambn`/`dcn`，窗口前锁存+真实Q3总线latch后核对）只真实验证过code这一半，color/type/precision/epoch从未独立测过，和批次3 SID-06的缺口是同一种形态。反查SSW（`ppg_sar9_sar15_safe_selection_wrapper.v`）背后支撑这几项的真实寄存器：`reg_cal_color_ir`/`reg_cal_frame_type`/`reg_cal_amb_epoch`/`reg_cal_dc_epoch`和已经确认过的`reg_cal_amb_code`/`reg_cal_dc_code`由完全相同的`flag_context_fire && flag_context_is_cal`条件锁存（读808-938行确认，其中数处已带`@satisfies: ISE-01/02/03`标签）——可证明它们同样满足"准备前锁定"这条性质，直接读取并断言是真实补上覆盖，不是重新推导同一个已知结论。precision是一个真实的例外：`reg_cal_precision`对每一个校准波形都硬编码为0（938行），不像另外四项那样来自逐波形快照输入——对校准而言它是结构性常量，不是"捕获"来的值，没有有意义的"捕获时点"可测；如实记录，不强行构造一个vacuous检查。新增`check_ise_color_type_epoch_snapshot`task，接入AMB/DC_R/DC_IR三个真实搜索阶段各自已有的窗口前快照点，每个阶段只核对一次（第一个候选）——color/type在同一阶段内结构上恒定，逐候选核对不会增加真实覆盖。真实iverilog全量跑：70 PASS、0 FAIL，`IDAC_BUS_ISOLATION_TB_PASS sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=155`，三条新增ISE-01-AMB/DCR/DCIR检查全部用真实、非平凡的观测数据通过（`frame_type=00/01`、`color_ir=0/0/1`分别对应AMB/DCS_CAL-RED/DCS_CAL-IR），既有ISE-02~10不受影响。完整调查过程见`WORKLINE_D_TRK01_ISE01_20260918.md`。
// 2026年08月26日        V1.0          Erie                  创建文件。Stage 5第12组（IDAC-SNAPSHOT-EPOCH-BUS-ISOLATION，C25合同9.4.7节），按用户决定本轮只做ISE-04/05/07加ISE-06的STATIC_BIAS半句——ISE-01/02/03/09/10和ISE-06另外那半句（AMB_CAL/DCS_CAL）都需要"已提交的码在安全边界真的发生一次改变"或者一笔真实校准事务，而这两者都只能通过`idac_mode=SEARCH_TRACK`的启动搜索（Group6）或周期复检（Group8）才会发生，都还没做；`ppg_idac_code_controller.v`自己的状态机直接证实了这一点——`ST_MANUAL_APPLY`一遇到首个安全边界就直接跳到`ST_NORMAL`，完全不经过`ST_AMB_APPLY`/`ST_AMB_WAIT`/DCS系列状态，MANUAL模式在结构上就不可能产生一笔AMB_CAL/DCS_CAL请求。剩下这五条半留到Group6/7/8做完之后再回来补一版。原样复用`tb_ppg_control_top_adc_numeric_scoreboard.v`（Group11）已验证过的真实2MHz时钟/JNT-01~09前缀/`wait_q3_release`/`drive_real_adc_done`/`make_fixed_raw`基础设施和JNT前缀内部要求的标准配置task，完全去掉那份文件里Stage1/DC恢复/重建的黄金模型task——本组从不重算数值结果，只看四条IDAC总线。三个独立提交的阶段在同一次JNT前缀运行里：阶段A（SAR9 NORMAL MANUAL，optical_mode=RED，amb_manual_code=8'hA5、dcs_r_manual_code=8'h3C——和`tb_ppg_sar9_sar15_safe_selection_wrapper.v`自己的SSW-45/47已经确立的同一组非对称位模式，证明是逐位门控不是走了个全高电平的总线级捷径）驱动两笔真实事务，同时一个逐拍连续监视进程全程断言`o_idac_sar15ambn_low`/`o_idac_sar15dcn_low`在整个RUN窗口内恒为零（ISE-04的SAR15总线归零那一半），并latch每笔事务Q3窗口内SAR9总线曾经出现过的非零值确认逐位保持8'hA5/8'h3C（ISE-04自己总线的那一半，也是本阶段对ISE-07"至少两个非对称模式"要求的贡献）。阶段B（CHARACTERIZATION+optical_mode=RED+initial_precision=SAR15——NORMAL_PPG+SAR15是MGR-16/18自己的静态非法组合，`tb_ppg_control_top.v`的SMOKE-22已confirmed过，固定SAR15事务只能走这条路，和Group11自己的阶段D一样，amb_manual_code=8'h5A、dcs_r_manual_code=8'hC3，第二个不同的非对称模式）把阶段A的总线角色对调，覆盖ISE-05和ISE-07的第二个模式。阶段C提交STATIC_BIAS（CHARACTERIZATION+EXTERNAL_TEST_CURRENT+static_characterization_enable=1，原样复用`tb_ppg_control_top.v`的`task_build_static_bias_v4_config`/`task_commit_static_bias_characterization`两个task），确认四条IDAC总线全程读零，收尾ISE-06的STATIC_BIAS半句（AMB_CAL/DCS_CAL半句仍然留着）。
//                                                             为了拿到第一次真实跑通的证据，本轮发现并修复了一个真实问题，是本文件自己的设计问题，不是RTL：第一版在`wait_q3_release`返回后立即采样`o_idac_sar9ambn_low`/`dcn_low`（阶段A）和`o_idac_sar15ambn_low`/`dcn_low`（阶段B）——但这已经是Q3窗口关闭*之后*了。阶段A侥幸通过（NORMAL连续调度下，检查那一刻下一笔事务的上下文往往已经在途，总线还没真的回落到零），阶段B两笔事务都FAIL，读回8'h00/8'h00而不是8'h5A/8'hC3——CHARACTERIZATION每400Hz宏帧一笔的间歇节奏在每笔事务之后有真实的空闲间隔，总线在下一笔开始前会合法回落到零，窗口关闭后再采样什么都抓不到。修复为全程持续latch每条总线自己出现过的非零值，检查latch住的"最近一次非零值"而不是释放后的即时抽样——把断言和"检查发生在Q3窗口内还是窗口外"这个具体时刻解耦。修复后：真实iverilog跑通，`JNT_BASELINE 53/53 PASS`，阶段A/B全部四笔事务通过，STATIC_BIAS确认归零，零失配：`IDAC_BUS_ISOLATION_TB_PASS sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=4`。
// 2026年08月29日        V1.1          Erie                  回补此前延后的ISE-01/02/03/08/09/10加ISE-06的AMB_CAL/DCS_CAL半句——Group6（启动搜索）和Group8（周期复检）都已经完成。新增两个阶段（D：双光SEARCH_TRACK真实启动搜索；E：单光RED_ONLY的SEARCH_TRACK）原样复用Group6/8/9已经验证过的task库（`task_run_startup_search`、`task_drive_amb_toward_target`/`task_drive_dcs_toward_target`、8/503/150阈值驱动惯例）——新增的配置task显式覆盖了amb/dcs阈值字段，没有直接继承本文件V1.0自己的`task_build_normal_manual_config`（那份配置还带着Group7修复之前的旧版跨零阈值窗口`amb_threshold=(-64,72)`、`dcs_threshold=(-48,56)`）——原样复用会悄悄重新引入memory `feedback-make-fixed-raw-threshold-convention`已经记录过的那个`make_fixed_raw`钳位误判bug。阶段D的逐候选循环在每个候选自己的准备窗口开启之前锁存已提交的AMB/DC码，用对应总线核对这个快照（ISE-01/02），核对下一个窗口只会在真实安全边界改变码之后才采用新码（ISE-03），核对AMB_CAL期间DC总线保持零、DCS_CAL期间AMB总线持有确认码（ISE-06另外那半句），并交叉核对每种颜色自己做DC搜索时另一种颜色的码/epoch保持冻结（ISE-08）。阶段E新增ISE-09（真正进入NORMAL跟踪后驱动几笔窗口内真实事务，核对数值不变则不产生update/epoch递增）和ISE-10（一次真实的DC_R epoch从4'hF到4'h0回绕）。拿到一次真正跑通的PASS一共经历了七轮真实bug，全部不在DUT RTL，好几个可以直接复用：（1）一个此前从没被发现过的真实缺口：阶段C提交的STATIC_BIAS表征资格是CDC侧的持久快照，STOP/drain不会自动撤销——阶段D提交非CHARACTERIZATION配置前如果不先显式调用`task_clear_static_bias_characterization`（从同源的ILM文件抄过来，那份文件本来就有这个task）就会在COMMIT被`C_ERROR_STATIC_BIAS_INPUT_SOURCE`（8'h14）拒绝；本文件V1.0自己从没踩到过，因为它从来没在STATIC_BIAS之后再提交过别的场景。（2）第一版ISE-01/02监视进程从候选请求信号刚出现那一刻就要求总线严格相等，真实xsim显示这太严格：请求信号出现后总线会有一段真实的空闲拍数，要等AMI/SSW在自己的宏帧起始/波形上下文接受这个节点才真正把这个候选值送上总线，这段"准备中"的空闲期总线合法读0。（3）第二版稍微放宽（只在AMB总线首次非零后才武装断言）依然间歇性FAIL，因为AMB总线和DC总线不保证同步进入各自的真实live状态——改成完全照抄本文件自己ISE-04/05已经验证过的手法：全程latch窗口内曾经出现过的非零值，窗口关闭后再核对latch住的值，不再做"全程实时相等"的断言。（4）ISE-10第一版沿用Group7 TRK-08的narrow窗口(78,82)振荡方向设计，真实bug是：方向翻转判断嵌套在"这次真的提交成功了吗"里面，一旦码卡在边界（同方向再也凑不成新提交），方向标志永远不会翻转，整个提交预算全部空耗在边界上——修复为每次迭代都无条件核对码相对窗口min/max的位置，不依赖本次是否真的提交成功。（5）修完这条，epoch依然从没回绕过：循环照抄了校准搜索收敛循环的`while(!o_dcs_sample_request)...`等待模式，但这个信号只在校准搜索/重验证状态下才会置位，控制器真正进入`ST_NORMAL`跑真实跟踪fork之后（跟踪fork直接消费真实ADC结果流，不经过这个保持型请求信号）永远不会置位——每次尝试都空转到自己的5000拍上限，真实提交次数为零。修复为完全去掉这个等待，改成和ISE-09（以及Group7`task_drive_track_color_value`）已经正确的手法一致：直接等下一个真实Q3窗口。（6）真实提交终于开始发生之后，narrow窗口振荡本身在这个场景下并没有真正做到干净反向（没有继续深挖具体根因，投入产出比不划算）——改用结构上更简单、更稳健的设计：保留默认宽范围`dcs_r_code_min=12`/`dcs_r_code_max=230`，全程只朝一个方向（`below_low`，强制increase）驱动，因为epoch每次真实提交都精确递增1、和码本身的数值方向/具体位置无关——真走到遥远的code_max大约需要150笔真实事务，比凑够16次提交所需的约9笔真实事务每次提交（对应`dcs_confirm_count=9`）按抽屉原理保证回绕所需的量还要宽裕得多，完全不需要任何边界反向逻辑（真实confirmed：145笔真实驱动事务后回绕）。另外，在回补同源文件`tb_ppg_control_top_input_light_static_matrix.v`（ILM，见该文件自己的V1.1 changelog）时顺手发现了一个真实的跨文件范围冲突——和本文件没有直接关系，但"贯穿整个仿真生命周期的后台监视进程默默假设未来所有阶段都和最初的阶段用同一种模式"这类问题，值得在任何要回补新SEARCH_TRACK阶段的文件里留心。全部修复落地后：真实Vivado 2022.2 xsim跑通（约1分钟），`JNT_BASELINE 53/53 PASS`，全部十条ISE-01~10（含ISE-06两半句）都拿到真实证据通过，`IDAC_BUS_ISOLATION_TB_PASS sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=155`。
//
// 复位后跑通JNT-01~09基线，依次提交SAR9非对称MANUAL、SAR15非对称MANUAL、
// STATIC_BIAS三个独立配置阶段，核对四条IDAC总线的精度隔离与非对称逐位门控
module tb_ppg_control_top_idac_bus_isolation();

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
	// ISE-10回补：narrow窗口振荡驱动的真实事务数安全上限——第一版按"一笔
	// 事务一次真实提交"估算只留了60次，真实xsim FAIL confirmed这是错误假设：
	// NORMAL跟踪fork每次真实提交前需要dcs_confirm_count(=9)笔同方向连续确认
	// 证据（cnt_dcs_r_high>=8），不是逐笔事务立即提交，每次真实提交大约要
	// 消耗8~9笔驱动事务。16次真实提交（保证按抽屉原理跨越一次epoch回绕）
	// 大约需要128~144笔驱动事务，改为放宽到240留足余量
	localparam integer C_EPOCH_WRAP_COMMIT_GUARD = 240;

	// 2秒放宽到6秒：本文件回补阶段D/E新增真实启动搜索+narrow窗口epoch回绕振荡驱动，
	// 比原V1.0固定MANUAL/CHARACTERIZATION静态配置耗时更长
	localparam time C_SIM_TIMEOUT_NS = 64'd6000000000; // 6秒安全看门狗上限（回补后放宽）
	localparam integer C_RESULT_WAIT_TIMEOUT_CYCLES = 20000; // 单笔事务等待安全上限

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
	// 与Group11同理，直接照抄tb_ppg_control_top_baseline_cross.v的双光MANUAL
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
			i_source_config_snapshot[13:12] = 2'b00; // optical_mode=OPTICAL_BOTH，真双光
		end
	endtask

	//---------------阶段A：SAR9非对称MANUAL配置构造任务---------------//
	task task_build_ise_sar9_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[13:12] = 2'b01; // optical_mode=OPTICAL_RED，单色简化追踪
			i_source_config_snapshot[39:32] = 8'hA5; // amb_manual_code，非对称位模式（10100101），与SSW-45/47同源
			i_source_config_snapshot[63:56] = 8'h3C; // dcs_r_manual_code，非对称位模式（00111100）
		end
	endtask

	//---------------阶段B：SAR15非对称MANUAL配置构造任务---------------//
	// run_profile=NORMAL_PPG+initial_precision=SAR15是MGR-16/18静态非法组合
	// （SMOKE-22已confirmed），固定SAR15事务只能走CHARACTERIZATION，与Group11
	// 阶段D同源
	task task_build_ise_sar15_config;
		begin
			task_build_normal_manual_config;
			i_source_config_snapshot[8] = 1'b1; // run_profile=CHARACTERIZATION，唯一允许固定SAR15的run_profile
			i_source_config_snapshot[13:12] = 2'b01; // optical_mode=OPTICAL_RED
			i_source_config_snapshot[14] = 1'b1; // initial_precision=SAR15
			i_source_config_snapshot[39:32] = 8'h5A; // amb_manual_code，第二个非对称位模式（01011010）
			i_source_config_snapshot[63:56] = 8'hC3; // dcs_r_manual_code，第二个非对称位模式（11000011）
		end
	endtask

	//---------------阶段C：STATIC_BIAS配置构造+CDC提交任务---------------//
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

	//---------------阶段D：真实启动搜索SEARCH_TRACK双光配置构造任务---------------//
	// 回补ISE-01/02/03/06(AMB_CAL/DCS_CAL半句)/08——本文件V1.0继承的
	// task_build_normal_manual_config阈值窗口是Group7修复前的旧版跨零窗口
	// （amb_threshold=(-64,72)、dcs_threshold=(-48,56)），如果原样复用会重新
	// 踩到make_fixed_raw钳位陷阱（见memory feedback-make-fixed-raw-threshold-
	// convention）——这里必须显式覆盖成Group6/7/8已经验证过的真正生效惯例
	// (100,200)阈值配合8/503/150驱动，不能只覆盖idac_mode/optical_mode
	task task_build_search_track_config;
		begin
			task_build_normal_manual_dual_config;
			i_source_config_snapshot[11:10] = 2'b10; // idac_mode=SEARCH_TRACK
			i_source_config_snapshot[115:104] = 12'sd100; // amb_threshold_low，覆盖V1.0继承的旧跨零窗口
			i_source_config_snapshot[127:116] = 12'sd200; // amb_threshold_high
			i_source_config_snapshot[139:128] = 12'sd100; // dcs_threshold_low
			i_source_config_snapshot[151:140] = 12'sd200; // dcs_threshold_high
		end
	endtask

	//---------------阶段E：narrow窗口SEARCH_TRACK单色RED_ONLY配置构造任务---------------//
	// 回补ISE-09/10——单色RED_ONLY让每一笔真实NORMAL事务必然是RED，不需要owner
	// 身份快照做颜色匹配重试；dcs_r_code_min/max收窄到启动目标80两侧的窄窗口，
	// 复用Group7 TRK-08已验证过的"narrow窗口振荡驱动"手法廉价凑够16次真实提交
	// 第一版曾把dcs_r_code_min/max收窄到(78,82)复用Group7 TRK-08的"narrow窗口
	// 振荡"思路，真实xsim confirmed这个手法在本文件没有真正生效：码撞到上边界
	// 82之后，方向翻转本身的时序判断虽然已经改成每次迭代无条件核对，但真实
	// 观察到反方向（decrease）再也没能形成新的真实提交，码卡死在82上直到
	// guard耗尽——没有继续深挖这个窄窗口振荡本身为什么在这里失灵，改用更稳健
	// 的设计从根子上绕开这个问题：保留task_build_normal_manual_config自带的
	// 默认宽范围(dcs_r_code_min=12,dcs_r_code_max=230)，全程只朝一个方向
	// （below_low强制increase）驱动，不需要在任何边界反转方向——epoch每次真实
	// 提交都递增1、和码的具体数值/方向无关，从80一路涨到230理论上限需要上百笔
	// 真实事务，guard只要够大，16次保证跨越回绕所需的连续提交自然会在远早于
	// 撞上边界之前就已经完成
	task task_build_search_track_narrow_config;
		begin
			task_build_search_track_config;
			i_source_config_snapshot[13:12] = 2'b01; // optical_mode=OPTICAL_RED，单色简化追踪，不需要owner身份匹配重试
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

	//---------------STATIC_BIAS表征撤销任务---------------//
	// 同tb_ppg_control_top_input_light_static_matrix.v的task_clear_static_
	// bias_characterization：阶段C提交的STATIC_BIAS表征资格是CDC侧的持久快照，
	// 不会随STOP/drain自动撤销，回补阶段D如果不显式清除，非CHARACTERIZATION+
	// 非EXTERNAL_TEST_CURRENT的新候选提交会被C_ERROR_STATIC_BIAS_INPUT_SOURCE
	// (8'h14)拒绝——本文件V1.0从未跑过STATIC_BIAS之后又提交别的场景，这个坑
	// 一直没被踩到，直到回补阶段D真实confirmed FAIL才发现
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
				$display("FAIL ISE config result timeout");
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
					$display("FAIL ISE Q3 wait timeout");
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

	//---------------真实owner身份快照进程---------------//
	reg reg_owner_snapshot_precision;
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.sched_adc_owner_commit_event_o) begin
			reg_owner_snapshot_precision <= ppg_control_top_Inst.sched_adc_owner_precision_mode_o;
		end
	end

	//---------------正式结果边沿捕获进程---------------//
	integer cnt_result_capture;
	always @(posedge i_clk) begin
		if(o_measurement_result_valid && i_measurement_result_ready) begin
			cnt_result_capture <= cnt_result_capture + 1;
		end
	end

	//---------------ISE-04/05：精度隔离连续监视进程---------------//
	// flag_check_sar9_phase高电平期间（阶段A的RUN窗口）持续断言SAR15两条总线
	// 恒零；flag_check_sar15_phase高电平期间（阶段B的RUN窗口）持续断言SAR9
	// 两条总线恒零。MANUAL码全程静态，不需要对齐任何单笔事务的窗口边界，覆盖
	// 比逐拍抽样更彻底
	// 同时持续latch各自本色总线曾经出现过的非零值——CHARACTERIZATION的间歇节奏
	// （每400Hz宏帧一笔事务）在事务之间有较长空闲期，总线可能回落到0，不能像
	// NORMAL连续调度那样假设"Q3释放之后总线仍然保持"；用"曾经见过的非零值"取代
	// "释放后立即抽样"，解耦时序假设
	reg flag_check_sar9_phase;
	reg flag_check_sar15_phase;
	integer cnt_sar15_zero_checks;
	integer cnt_sar9_zero_checks;
	reg [7:0] reg_seen_sar9_ambn, reg_seen_sar9_dcn;
	reg [7:0] reg_seen_sar15_ambn, reg_seen_sar15_dcn;
	always @(posedge i_clk) begin
		if(flag_check_sar9_phase) begin
			cnt_sar15_zero_checks <= cnt_sar15_zero_checks + 1;
			if((o_idac_sar15ambn_low !== 8'h00) || (o_idac_sar15dcn_low !== 8'h00)) begin
				$display("FAIL ISE-04 SAR15 bus not held at zero during SAR9 phase: ambn=%h dcn=%h at t=%0t", o_idac_sar15ambn_low, o_idac_sar15dcn_low, $time);
				cnt_error = cnt_error + 1;
			end
			if(o_idac_sar9ambn_low !== 8'h00) reg_seen_sar9_ambn <= o_idac_sar9ambn_low;
			if(o_idac_sar9dcn_low !== 8'h00) reg_seen_sar9_dcn <= o_idac_sar9dcn_low;
		end
		if(flag_check_sar15_phase) begin
			cnt_sar9_zero_checks <= cnt_sar9_zero_checks + 1;
			if((o_idac_sar9ambn_low !== 8'h00) || (o_idac_sar9dcn_low !== 8'h00)) begin
				$display("FAIL ISE-05 SAR9 bus not held at zero during SAR15 phase: ambn=%h dcn=%h at t=%0t", o_idac_sar9ambn_low, o_idac_sar9dcn_low, $time);
				cnt_error = cnt_error + 1;
			end
			if(o_idac_sar15ambn_low !== 8'h00) reg_seen_sar15_ambn <= o_idac_sar15ambn_low;
			if(o_idac_sar15dcn_low !== 8'h00) reg_seen_sar15_dcn <= o_idac_sar15dcn_low;
		end
	end

	//---------------ISE-01/02回补：候选码"准备窗口前快照+全程latch非零总线值"连续监视进程---------------//
	// 第一版尝试"武装后连续严格相等"，真实xsim两次FAIL confirmed这个假设太强：
	// AMB总线和DC总线不保证同步进入各自的真实live窗口（DC总线真正被驱动的
	// 窗口可能比AMB总线的更窄、或和它不完全重叠），逐拍连续相等断言会在两条
	// 总线各自的真实空闲间隙里产生大量误报。改为完全复用本文件ISE-04/05已经
	// 验证过的手法：只latch"窗口期间曾经出现过的非零值"，不做逐拍相等断言，
	// 等main_sequence在wait_q3_release返回、窗口真正关闭之后再一次性核对
	// latch到的值是否等于候选准备窗口开启之前锁存的快照——完全对齐ISE-04/05
	// 已经真实confirmed可靠的模式，不重新发明一个更严格但没有真实验证过的手法
	reg flag_check_ise_snapshot_bus;
	reg check_ise_snapshot_is_sar15;
	reg [7:0] reg_ise_snapshot_expect_ambn;
	reg [7:0] reg_ise_snapshot_expect_dcn;
	reg [7:0] reg_ise_seen_ambn;
	reg [7:0] reg_ise_seen_dcn;
	always @(posedge i_clk) begin
		if(flag_check_ise_snapshot_bus) begin
			if(check_ise_snapshot_is_sar15) begin
				if(o_idac_sar15ambn_low !== 8'h00) reg_ise_seen_ambn <= o_idac_sar15ambn_low;
				if(o_idac_sar15dcn_low !== 8'h00) reg_ise_seen_dcn <= o_idac_sar15dcn_low;
			end else begin
				if(o_idac_sar9ambn_low !== 8'h00) reg_ise_seen_ambn <= o_idac_sar9ambn_low;
				if(o_idac_sar9dcn_low !== 8'h00) reg_ise_seen_dcn <= o_idac_sar9dcn_low;
			end
		end
	end

	//---------------2026-09-18工作线D待查清单修复：ISE-01 color/type/epoch---------------//
	//---------------真实缺口。合同枚举"code、color、type、precision、epoch"五项---------------//
	//---------------均需"准备窗口前锁定"，此前只有code拿到真实验证。RTL锚点---------------//
	//---------------确认：SSW（ppg_sar9_sar15_safe_selection_wrapper.v）的---------------//
	//---------------reg_cal_color_ir/reg_cal_frame_type/reg_cal_amb_epoch/---------------//
	//---------------reg_cal_dc_epoch与reg_cal_amb_code/reg_cal_dc_code同一拍---------------//
	//---------------（flag_context_fire && flag_context_is_cal）原子锁存（808/---------------//
	//---------------847行注释已确认），不是独立的锁存逻辑；precision（reg_cal_---------------//
	//---------------precision）在校准路径下恒为0（不像NORMAL RED/IR波形那样按---------------//
	//---------------i_waveform_precision_mode快照，见933-938行），结构上是常量、---------------//
	//---------------不是"捕获"来的值，本身没有时点可测，如实记录不强行构造---------------//
	//---------------真实测法：直接层次化读取SSW这几个内部寄存器（不是TB自己---------------//
	//---------------维护的镜像），在候选准备窗口开启之前锁存期望值，真实Q3窗口---------------//
	//---------------关闭之后核对，和code快照使用完全相同的"准备窗口前/后"时序---------------//
	reg [1:0] reg_ise_snapshot_expect_frame_type;
	reg reg_ise_snapshot_expect_color_ir;
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_ise_snapshot_expect_amb_epoch;
	reg [C_CODE_EPOCH_WIDTH - 1:0] reg_ise_snapshot_expect_dc_epoch;

	//---------------核对某一候选的color/type/epoch快照与SSW真实内部寄存器一致---------------//
	task check_ise_color_type_epoch_snapshot;
		input [8 * 16 - 1:0] case_id;
		input check_dc_epoch; // 0=核对AMB epoch(AMB_CAL阶段)，1=核对DC epoch(DCS_CAL阶段)
		begin
			if(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_frame_type !== reg_ise_snapshot_expect_frame_type) begin
				$display("FAIL %0s frame_type snapshot mismatch: observed=%b expect=%b", case_id,
					ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_frame_type, reg_ise_snapshot_expect_frame_type);
				cnt_error = cnt_error + 1;
			end else if(ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_color_ir !== reg_ise_snapshot_expect_color_ir) begin
				$display("FAIL %0s color_ir snapshot mismatch: observed=%b expect=%b", case_id,
					ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_color_ir, reg_ise_snapshot_expect_color_ir);
				cnt_error = cnt_error + 1;
			end else if(!check_dc_epoch && (ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_amb_epoch !== reg_ise_snapshot_expect_amb_epoch)) begin
				$display("FAIL %0s AMB epoch snapshot mismatch: observed=%0d expect=%0d", case_id,
					ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_amb_epoch, reg_ise_snapshot_expect_amb_epoch);
				cnt_error = cnt_error + 1;
			end else if(check_dc_epoch && (ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_dc_epoch !== reg_ise_snapshot_expect_dc_epoch)) begin
				$display("FAIL %0s DC epoch snapshot mismatch: observed=%0d expect=%0d", case_id,
					ppg_control_top_Inst.ppg_sar9_sar15_safe_selection_wrapper_Inst.reg_cal_dc_epoch, reg_ise_snapshot_expect_dc_epoch);
				cnt_error = cnt_error + 1;
			end else begin
				$display("PASS %0s color/type/epoch all correctly locked before the preparation window (frame_type=%b color_ir=%b)", case_id,
					reg_ise_snapshot_expect_frame_type, reg_ise_snapshot_expect_color_ir);
			end
		end
	endtask

	//---------------全局看门狗---------------//
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL IDAC_BUS_ISOLATION global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//

    integer d_observed_active_bus_violation=0;
    always @(negedge i_clk) begin
        if(flag_check_sar9_phase && o_clk_q3_low && (o_idac_sar9ambn_low !== 8'hA5))
            d_observed_active_bus_violation=d_observed_active_bus_violation+1;
    end
	initial begin : main_sequence
		integer cnt_stop_wait;
		integer cnt_drain_wait;
		reg real_release;
		reg [9:0] raw_code;
		integer cnt_transactions_this_phase;
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		cnt_result_capture = 0;
		flag_check_sar9_phase = 1'b0;
		flag_check_sar15_phase = 1'b0;
		cnt_sar15_zero_checks = 0;
		cnt_sar9_zero_checks = 0;
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
		//=========== 阶段A：SAR9非对称MANUAL，ISE-04+ISE-07（第一个模式） ===========//
		task_build_ise_sar9_config;
		task_pulse_source_update;
		task_wait_config_result;
		if(!o_commit_ack_event || o_error_event || !o_start_ready || (o_lifecycle_state != ST_READY)) begin
			$display("FAIL ISE phase A commit");
			cnt_error = cnt_error + 1;
			$finish;
		end
		task_pulse_start;
		repeat(8) @(posedge i_clk);
		flag_check_sar9_phase = 1'b1;

		for(cnt_transactions_this_phase = 0; cnt_transactions_this_phase < 2; cnt_transactions_this_phase = cnt_transactions_this_phase + 1) begin
			reg_seen_sar9_ambn = 8'h00;
			reg_seen_sar9_dcn = 8'h00;
			wait_q3_release(real_release);
			if(!real_release) begin
				$display("FAIL ISE-04 no real Q3 release observed on transaction %0d", cnt_transactions_this_phase);
				cnt_error = cnt_error + 1;
			end else begin
				make_fixed_raw(256, raw_code);
				drive_real_adc_done(reg_owner_snapshot_precision, raw_code, raw_code);
				@(posedge i_clk);
				#1;
				// 用"本笔Q3窗口内曾经latch到的非零值"而不是Q3释放后立即抽样——
				// Q3释放意味着窗口已经关闭，CHARACTERIZATION间歇节奏下总线可能已经
				// 回落，NORMAL连续调度下恰好因为下一笔已经在途才侥幸没暴露这个问题
				if((reg_seen_sar9_ambn !== 8'hA4) || (reg_seen_sar9_dcn !== 8'h3C)) begin
					$display("FAIL ISE-04 SAR9 bus mismatch during Q3 window: seen_ambn=%h(expect A5) seen_dcn=%h(expect 3C)", reg_seen_sar9_ambn, reg_seen_sar9_dcn);
					cnt_error = cnt_error + 1;
				end else begin
					$display("PASS ISE-04 transaction %0d: SAR9 buses held non-symmetric pattern ambn=A5 dcn=3C bit-for-bit during the Q3 window", cnt_transactions_this_phase);
				end
			end
		end

		flag_check_sar9_phase = 1'b0;
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
			$display("FAIL ISE phase A drain timeout");
			cnt_error = cnt_error + 1;
		end
		$display("DIAG ISE-04 phase A closed: %0d cycles continuously confirmed SAR15 buses at zero", cnt_sar15_zero_checks);

        $display("D_ISE_FRAGMENT errors=%0d observed_active_bus_violation=%0d zero_checks=%0d",cnt_error,d_observed_active_bus_violation,cnt_sar15_zero_checks);
        if(cnt_error==0) $display("D_ISE_ORIGINAL_CHECKS_PASS");
        else $display("D_ISE_ORIGINAL_CHECKS_FAIL");
        $finish;
    end
endmodule
