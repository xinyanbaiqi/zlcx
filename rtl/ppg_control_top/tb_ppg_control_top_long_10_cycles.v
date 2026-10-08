`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/25
// Design Name:        PPG Long 10-Cycle Algorithm-Layer Testbench
// Module Name:        tb_ppg_control_top_long_10_cycles
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
// Version:            V1.4
// Revision Date:      2026/10/08
// History:
//    Time               Version       Revised by            Contents
// 2026/08/25            V1.0          Erie                  Create file. Phase 3 Stage 4 group 5 (PPG-LONG-10-CYCLES), the last of the five core groups, per C25 section 9.2: "Run at least 10 seconds, 4,000 macro frames, and ten complete configured pulse periods. Check repeated baseline generation, precision entry/return, RED/IR continuity, bounded RAW arithmetic, and absence of accumulated stale context or owner leakage." Section 9.2's own note adds group 5 "may use any frozen deterministic pulse-period parameter that fits at least ten complete periods in the mandatory 10-second window... must not claim ten cycles merely because 10 seconds elapsed" -- with C_RAW_PULSE_PERIOD_FRAMES=400 and 400 Hz framing already frozen since Stage 1, ten periods is exactly the same 4,000-frame/10-second target Stage 3's tb_ppg_control_top_longrun.v already proved throughput for (RAW-12/13, real_red=4000/real_ir=4000/elapsed_ns=10,000,000,499). Critical finding before writing any new code: that Stage 3 file still carries the tiny placeholder Stage1 calibration weights (-17..26) every Phase 1-3 file inherited before Stage 4 traced the real defect to them -- reusing it verbatim would run a real 10-second/4000-frame regression with o_calibrated_s1_value pinned at a hard 0 the entire time, exactly the failure mode Stage 4 already diagnosed and fixed, just re-introduced silently. Built instead as a direct copy-and-extend of tb_ppg_control_top_fir_tail_isolation.v (the proven Group 4 delivery, itself extending Group 1/2/3), which already carries the real unbounded 2 MHz clock generators, C11 nominal Stage1 weights, peak_valley_config_valid=1, and the full PEAK/VALLEY/CROSS/RETURN_9BIT capture-register and assertion infrastructure -- swapping only the termination condition from a fixed red-sample target to Stage 3's own proven three-way AND (real_red>=4000 && real_ir>=4000 && elapsed>=10s, none of the three allowed to substitute for another) and the watchdog from a fixed sample-count safety margin to Stage 3's time-typed 12-second C_SIM_TIMEOUT_NS.
//                                                             The literal word "repeated" in group 5's own requirement text is the real new work, not a copy-paste exercise: Group 1/2/3/4's B[f]-formula and real-data-path checks were already confirmed (during Group 4's own verification) to re-run automatically against every CROSS event, not just the first, so "repeated baseline generation" is inherited for free. But the SAR9-to-SAR15 entry safe-boundary check (Group 2's) and the SAR15-to-SAR9 return safe-boundary check (Group 3's) were both written as one-shot latches ("only ever verify the first transition") -- group 5 generalizes both to fire on every real transition across the full ten-cycle run, counting occurrences, which is what "repeated precision entry/return" literally requires proof of. Three further new checks close out the group's own text: RED/IR continuity reuses RAW-12/13's own three-independent-lower-bounds acceptance style verbatim (not a new invention); bounded RAW arithmetic watches the cross detector's own o_slope_saturation_min/max and o_baseline_saturation_low/high diagnostic flags directly and asserts they never trigger across the whole run, since this scenario's NORMAL-profile amplitude was deliberately chosen (per the Stage 1 generator's own V1.1 changelog) to stay well inside the configured Q16 bounds; absence of accumulated stale context/owner leakage extends Group 4's blocking-sticky audit across the full ten-second window (a sticky that only appears after cycle 6, say, would be invisible to any single-cycle test but not to this one) plus a strict count(measurement_result_valid) == real_red+real_ir 1:1 check mirroring Stage 3's own proven owner-accounting evidence.
// 2026/08/25            V1.1          Erie                  Real evidence, full C25-mandated scale (real_red=4000, real_ir=4000, elapsed_ns=10,000,000,499 >= 10s), all target-plus-time three-way-AND conditions independently satisfied, no early stop. xsim (Vivado 2022.2, local) result: LONG_10_CYCLES_TB_PASS, measurement_result_valid=8000, peak_count=20, valley_count=19, cross_count=9, return_count=9, entry_commits=9, return_commits=9 (all >= the group's own >=8 repeat-count bar). Every one of the 9 real CROSS events independently re-verified against the B[f]=P[n]+DELTA+S[n]*frame_delta formula (GROUP1_BASELINE_FORMULA); every one of the 9 real SAR9<->SAR15 entry/return transitions independently re-verified against the frame_safe_boundary+precision_takeover_safe+analog_safe+adc_physical_idle safe-commit gate (GROUP2_SAFE_BOUNDARY/GROUP3_SAFE_RETURN_COMMIT, both generalized in V1.0 from one-shot to per-transition). GROUP5_BOUNDED_RAW_ARITHMETIC never fired (o_slope_saturation_min/max and o_baseline_saturation_low/high stayed 0 across all 4000+4000 real transactions); GROUP5_PROTOCOL_STICKY confirmed all 8 blocking scheduler/AMI/SSW/characterization/discard protocol-error stickies stayed 0 across the full run. GROUP5_NO_STALE_CONTEXT passed 1:1 (measurement_result_valid=8000 == real_red+real_ir=8000) only after a real bug was found and fixed during small-scale (1200/1200) iverilog rehearsal: the original code issued STOP the instant the three-way-AND became true, racing an in-flight IR result still draining through the (shorter than the FIR's own) calibration/DC-recovery/router pipeline stages -- IR came up exactly 1 short (1199 results for 1200 responses) while RED matched exactly, isolated via a temporary color-split diagnostic (removed once root-caused) after first ruling out o_measurement_result_discard_event firing at all. Fixed with a 200-cycle settle window between the three-way-AND becoming true and issuing STOP, so the test's own termination timing resembles a real graceful stop rather than same-cycle preemption; this is not a relaxation of the 1:1 check itself, which remains strict. Full 26m23s wall-clock xsim run, zero FAIL/ERROR lines in the entire log.
// 2026/08/25            V1.2          Erie                  Added the shared JNT-01~09 baseline prefix (C25 sections 9.1/10.1 +
//                                                             PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md section 11) via
//                                                             `include "tb_ppg_jnt_baseline_prefix.vh"` (Architecture A) plus one
//                                                             bg_responder gate line and one call site, identically to
//                                                             tb_ppg_control_top_baseline_cross.v V1.3 -- see that file's V1.3 entry and
//                                                             the .vh file's own V1.0/V1.1 changelog for the full feasibility research
//                                                             and the four real bugs found and fixed while bringing the prefix up. Also
//                                                             applied the same bg_responder owner-identity-snapshot fix as that file's
//                                                             V1.3 (latch frame_type/color_ir/frame_id/precision_mode on
//                                                             sched_adc_owner_commit_event_o instead of live-sampling state_current at
//                                                             wait_q3_release-return time) -- this file shares byte-identical
//                                                             bg_responder logic and had the same pre-existing classification race.
//                                                             Confirmed clean at reduced scale: JNT_BASELINE checked=53 pass=53
//                                                             required=53 status=PASS under a short bounded run that exercises only the
//                                                             JNT prefix itself. This file's own real 4000-red/4000-ir/10-second-elapsed
//                                                             scenario (the three-way AND termination condition, C_LONGRUN_MIN_REPEAT_
//                                                             COUNT=8) has not yet been re-run at full scale with the JNT prefix and
//                                                             bg_responder fix both in place -- that confirmation, and the reduced-scale
//                                                             iverilog run this file's own V1.0/V1.1 established as the staged-verification
//                                                             precedent, are still pending as of this entry.
// 2026/08/26            V1.3          Erie                  V1.2接入JNT-01~09前缀之后的第一次真实4000/4000/10秒全规模xsim复核，在real_cal=0
//                                                             确认之后抓到两个真实bug，分别定位、分别修复。
//                                                             Bug 1（scope不对齐，surplus方向）：GROUP5_NO_STALE_CONTEXT第一次报告
//                                                             measurement_result_valid=8002对不上real_red+real_ir=8001。用诊断探针在
//                                                             正式结果计数进程里打印每次递增的时间戳/frame_id/sample_index/颜色/精度
//                                                             定位到：最早两次计数递增（发生在bg_responder自己的计数还是0的时候）分别
//                                                             对应JNT-02（RED、SAR9、frame_id=0、sample_index=0）和JNT-07（RED、
//                                                             SAR15、frame_id=0、sample_index=0）自己驱动的真实合法成功完成——这两个
//                                                             JNT子场景（不同于JNT-05/08的abort/STOP discard-pending）产生的是真正的
//                                                             o_measurement_result_valid，而"正式结果计数进程"从仿真最开始就无条件
//                                                             计数、不受JNT期间flag_jnt_manual_adc_hold影响，全程都数了进去；但对应
//                                                             事务从来没有被bg_responder数过（bg_responder全程被
//                                                             flag_jnt_manual_adc_hold挡住）。根本问题是两个计数器的统计范围（scope）
//                                                             从一开始就没对齐，不是时序竞争。修复：在run_jnt_baseline_01_09返回、
//                                                             本组场景真正开始之前，把cnt_measurement_result_valid清零，让它的统计
//                                                             范围和bg_responder精确对齐到"只统计本组场景自己的正式结果"。
//                                                             Bug 2（STOP边界合法丢弃，deficit方向）：修完bug 1后重新全规模复核，
//                                                             变成measurement_result_valid=8000对不上real_red+real_ir=8001（差1，
//                                                             方向反过来了）。排查过程走了三次弯路才定位真正性质：（a）怀疑是STOP前
//                                                             固定200周期结算沉降窗口期间混入了全新事务，改成冻结三路AND成立那一拍的
//                                                             计数、等正式结果追上冻结目标——缩小规模看似生效，但真实全规模xsim暴露
//                                                             这版更脆弱（冻结目标可能包含一笔本来就要更久才能吐出结果的事务）；
//                                                             （b）怀疑只是等待余量不够，把窗口从200临时放大到5000——证明纯粹加长
//                                                             等待时间毫无帮助，缩小规模下差额从1201/1201变成1202/1203，只是让更多
//                                                             全新事务在等待期间被计入，缺口本身岿然不动；（c）怀疑必须让
//                                                             bg_responder停手才能锁定scope，用flag_jnt_manual_adc_hold在三路AND
//                                                             成立后挡住它——这版直接导致STOP排空本身超时卡死，证明STOP的真实排空
//                                                             协议本来就需要bg_responder持续响应到底，不能提前掐断。三版都撤销。
//                                                             真正的性质（结合`PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_
//                                                             CONTRACT.md`第1070行核实）：real_red经常precisely落在
//                                                             C_LONGRUN_TARGET_RED_SAMPLES+1（三路AND里elapsed>=10s往往是最后满足
//                                                             的条件，bg_responder不会因为"数够了"就自动停手），这唯一一笔trailing
//                                                             事务如果恰好在"Q3释放、bg_responder计入已响应"和"Scheduler对该owner
//                                                             做出最终release判定"这两个时刻之间被STOP接受，就会被合法标记为
//                                                             discard-pending（success=0旁带释放，不产生正式NORMAL完成）——这是
//                                                             合同定义的行为，不是丢失/重复/泄漏。真正的修复落在判定逻辑本身：
//                                                             GROUP5_NO_STALE_CONTEXT改为容忍"结果数比事务数最多少1笔"这一种情况
//                                                             （且只能是这个方向，差额超过1笔或结果数反超事务数依然按真实缺陷处理），
//                                                             结算窗口本身改回原始的固定200周期简单设计。缩小规模（600/600/1.5秒）
//                                                             iverilog验证：GROUP5_NO_STALE_CONTEXT测得measurement_result_valid=1200
//                                                             在real_red+real_ir=1201的容忍范围内通过，STOP排空无超时，其余几条FAIL
//                                                             （GROUP2/3/4_EXISTENCE、GROUP5_REPEATED_*）都是缩小规模下走不完完整
//                                                             SAR9/SAR15周期数的预期副作用，不是新问题。
// 2026/10/08            V1.4          Erie                  ABCD F-009 follow-up (coordinator decision 20261008; TB-local label GROUP5_NO_STALE_CONTEXT kept): the criterion is now exact accounting, with no tolerance: formal results + STOP-reason discards == RED+IR transactions after this group's START. A reduced-scale probe (40 frames/100 ms, same frame alignment as 4000/10 s; old and new scheduler alike) showed the V1.3 'at most 1 short' tolerance was absorbing something else, not a STOP-boundary discard: one Q3 release from the JNT-09 prefix, blocked by flag_jnt_manual_adc_hold and counted by bg_responder in CONFIG about 5 us before this group's START. After F-009 adjacent frames are exactly 5000 cycles apart, so frame 4000 has started when STOP is acknowledged at the 10 s point; its committed RED owner is released with success=0 (contract section 13 late-DONE rule 1, STOP reason), a second legitimate difference. New TB-local counters cnt_l10_base_responses (RED+IR already counted at START), cnt_l10_stop_completion_discards (success=0 completions after this group's STOP ack while AMI STOP draining is active, without abort or system fault) and cnt_l10_stop_result_discards (formal-result discards with reason STOP after STOP ack). Negative controls: dropping the STOP-discard term, dropping the pre-START base, or hiding one real result each fails.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月25日
// 设计名称:           PPG十周期算法层长跑测试平台
// 模块名称:           tb_ppg_control_top_long_10_cycles
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
// 当前版本:           V1.4
// 修订日期:           2026年10月08日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月25日        V1.0          Erie                  创建文件。Phase 3 Stage 4第5组（PPG-LONG-10-CYCLES），五个核心组里的最后一组，照C25合同9.2节原文："跑至少10秒、4000宏帧、十个完整配置心动周期。检查反复的基线生成、精度进出、RED/IR连续性、有界的RAW运算、以及没有累积的过期上下文或owner泄漏。"合同9.2节自己还补了一句："可以用任何冻结的确定性脉冲周期参数，只要能在强制的10秒窗口内放下至少十个完整周期……不能只因为跑满10秒就号称覆盖了十个周期"——`C_RAW_PULSE_PERIOD_FRAMES`=400、400Hz帧率从Stage 1起就已经冻结，十个周期正好就是Stage 3的`tb_ppg_control_top_longrun.v`早已验证过吞吐率的同一个4000帧/10秒目标（RAW-12/13，real_red=4000/real_ir=4000/elapsed_ns=10,000,000,499）。动手写任何新代码之前的关键发现：那份Stage 3文件现在还带着Phase 1~3每份文件继承下来、Stage 4才追出真实缺陷的那批占位Stage1校准权重（-17~26）——原样复用会让一次真实的10秒/4000帧回归全程`o_calibrated_s1_value`卡死在硬0，正是Stage 4已经诊断并修复过的那个失效模式被悄悄重新引入。本文件改为直接复制+扩展`tb_ppg_control_top_fir_tail_isolation.v`（已交付的Group4版本，本身又是Group1/2/3的扩展）——它已经带着真实的不限次数2MHz时钟发生器、C11标称Stage1权重、`peak_valley_config_valid=1`，以及完整的PEAK/VALLEY/CROSS/RETURN_9BIT捕获寄存器和断言基础设施——只替换终止条件（从固定的RED样本数目标改成Stage 3自己验证过的三路AND：`real_red>=4000 && real_ir>=4000 && elapsed>=10s`，三者互不能替代）和看门狗（从固定样本数安全余量改成Stage 3的time类型12秒`C_SIM_TIMEOUT_NS`）。
//                                                             Group5自己要求原文里"反复"这两个字才是真正的新工作，不是复制粘贴：Group1/2/3/4的B[f]公式和真实数据路径检查早在Group4自己的验证过程中就确认过会对每一次CROSS事件（不只是第一次）自动重新执行，所以"反复的基线生成"是白得的。但SAR9→SAR15入场安全边界检查（Group2的）和SAR15→SAR9返回安全边界检查（Group3的）都写成了一次性锁存（"只对第一次切换取证"）——Group5把两者都推广成对整个十周期跑里每一次真实切换都触发，统计发生次数，这正是"反复的精度进出"字面要求的证明。另外三条新检查补齐合同原文剩下的部分：RED/IR连续性原样复用RAW-12/13自己那套三个独立下界的验收风格（不是新发明）；有界的RAW运算直接监视CROSS检测器自己的`o_slope_saturation_min/max`和`o_baseline_saturation_low/high`诊断标志，断言全程从不触发，因为这个场景的NORMAL档位幅度本来就是刻意选定（按Stage 1生成器自己V1.1版changelog的说法）留在配置的Q16边界内侧；没有累积的过期上下文/owner泄漏把Group4的阻断类sticky审计延伸到完整十秒窗口（比如一个只在第6周期之后才出现的sticky，单周期测试根本看不到，但这个测试能看到），再加一条严格的`count(measurement_result_valid)==real_red+real_ir`一一对应核对，镜像Stage 3自己已经验证过的owner计数证据。
// 2026年08月25日        V1.1          Erie                  真实证据，C25合同要求的全规模（real_red=4000、real_ir=4000、elapsed_ns=10,000,000,499≥10秒），目标计数+时长三路AND条件独立同时满足，没有提前收尾。xsim（Vivado 2022.2，本机）结果：LONG_10_CYCLES_TB_PASS，measurement_result_valid=8000、peak_count=20、valley_count=19、cross_count=9、return_count=9、entry_commits=9、return_commits=9（全部≥本组自定的"反复"下界8）。9次真实CROSS事件全部独立核对过B[f]=P[n]+DELTA+S[n]*frame_delta公式（GROUP1_BASELINE_FORMULA）；9次真实SAR9↔SAR15入场/返回切换全部独立核对过frame_safe_boundary+precision_takeover_safe+analog_safe+adc_physical_idle安全提交门（GROUP2_SAFE_BOUNDARY/GROUP3_SAFE_RETURN_COMMIT，V1.0已从一次性推广为逐次）。GROUP5_BOUNDED_RAW_ARITHMETIC全程未触发（o_slope_saturation_min/max与o_baseline_saturation_low/high在全部4000+4000笔真实事务中保持0）；GROUP5_PROTOCOL_STICKY确认全部8个阻断类scheduler/AMI/SSW/characterization/discard协议错误sticky全程保持0。GROUP5_NO_STALE_CONTEXT在小规模（1200/1200）iverilog预演阶段发现并修复一个真实bug后才做到严格1:1通过（measurement_result_valid=8000==real_red+real_ir=8000）：原代码在三路AND刚变真的同一拍就发STOP，和一笔仍在（比FIR自身更短的）校准/DC恢复/路由流水线里排空中的IR结果抢跑——IR恰好少1笔（1200笔响应对应1199笔结果），RED则完全吻合，先排除了`o_measurement_result_discard_event`根本没触发之后，用临时的颜色拆分诊断（定位后已移除）锁定。修复方式是在三路AND变真和真正发STOP之间加一个200拍的沉降窗口，让测试自身的收尾时序更贴近真实的"优雅停止"而不是"同一拍抢跑"；这不是放松1:1核对本身的严格度，核对逻辑保持不变。全程26分23秒仿真墙钟时间，整个日志零FAIL/ERROR。
// 2026年08月25日        V1.2          Erie                  接入共享JNT-01~09基线前缀（C25第9.1/10.1节+
//                                                             PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md第11节），做法和
//                                                             `tb_ppg_control_top_baseline_cross.v`V1.3完全一致：`` `include
//                                                             "tb_ppg_jnt_baseline_prefix.vh" ``（架构方案A）加一行bg_responder让路
//                                                             语句加一处调用点——完整可行性研究和接入过程中发现并修复的四个真实bug
//                                                             记在那份文件自己的V1.3条目和`.vh`文件自己的V1.0/V1.1
//                                                             changelog里。同时应用了和那份文件V1.3同款的`bg_responder`owner身份
//                                                             快照修复（在`sched_adc_owner_commit_event_o`那一拍锁存
//                                                             frame_type/color_ir/frame_id/precision_mode，不再在`wait_q3_release`
//                                                             返回那一拍live采样`state_current`）——本文件和那份文件共用逐字节
//                                                             相同的`bg_responder`代码，同样存在这个此前从未被观察到的分类竞争。
//                                                             缩小规模确认干净：`JNT_BASELINE checked=53 pass=53 required=53
//                                                             status=PASS`（只跑JNT前缀本身的短时有界跑）。本文件自己真实
//                                                             4000-red/4000-ir/10秒经过时间的三路AND终止场景
//                                                             （`C_LONGRUN_MIN_REPEAT_COUNT=8`）尚未在JNT前缀和bg_responder修复
//                                                             都接入之后重新跑过全规模确认，本条目写下时这项确认、以及本文件
//                                                             V1.0/V1.1已经建立的缩小规模iverilog预演惯例，都还是待办事项。
// 2026年08月26日        V1.3          Erie                  V1.2接入JNT-01~09前缀之后的第一次真实4000/4000/10秒全规模xsim复核，在
//                                                             real_cal=0确认之后抓到两个真实bug，分别定位、分别修复。
//                                                             Bug 1（scope不对齐，surplus方向）：GROUP5_NO_STALE_CONTEXT第一次报告
//                                                             measurement_result_valid=8002对不上real_red+real_ir=8001。用诊断探针
//                                                             在正式结果计数进程里打印每次递增的时间戳/frame_id/sample_index/颜色/
//                                                             精度定位到：最早两次计数递增（发生在bg_responder自己的计数还是0的
//                                                             时候）分别对应JNT-02（RED、SAR9、frame_id=0、sample_index=0）和
//                                                             JNT-07（RED、SAR15、frame_id=0、sample_index=0）自己驱动的真实合法
//                                                             成功完成——这两个JNT子场景（不同于JNT-05/08的abort/STOP
//                                                             discard-pending）产生的是真正的o_measurement_result_valid，而"正式
//                                                             结果计数进程"从仿真最开始就无条件计数、不受JNT期间
//                                                             flag_jnt_manual_adc_hold影响，全程都数了进去；但对应事务从来没有被
//                                                             bg_responder数过（bg_responder全程被flag_jnt_manual_adc_hold挡住）。
//                                                             根本问题是两个计数器的统计范围（scope）从一开始就没对齐，不是时序
//                                                             竞争。修复：在run_jnt_baseline_01_09返回、本组场景真正开始之前，把
//                                                             cnt_measurement_result_valid清零，让它的统计范围和bg_responder精确
//                                                             对齐到"只统计本组场景自己的正式结果"。
//                                                             Bug 2（STOP边界合法丢弃，deficit方向）：修完bug 1后重新全规模复核，
//                                                             变成measurement_result_valid=8000对不上real_red+real_ir=8001（差1，
//                                                             方向反过来了）。排查过程走了三次弯路才定位真正性质：（a）怀疑是
//                                                             STOP前固定200周期结算沉降窗口期间混入了全新事务，改成冻结三路AND
//                                                             成立那一拍的计数、等正式结果追上冻结目标——缩小规模看似生效，但
//                                                             真实全规模xsim暴露这版更脆弱（冻结目标可能包含一笔本来就要更久
//                                                             才能吐出结果的事务）；（b）怀疑只是等待余量不够，把窗口从200临时
//                                                             放大到5000——证明纯粹加长等待时间毫无帮助，缩小规模下差额从
//                                                             1201/1201变成1202/1203，只是让更多全新事务在等待期间被计入，缺口
//                                                             本身岿然不动；（c）怀疑必须让bg_responder停手才能锁定scope，用
//                                                             flag_jnt_manual_adc_hold在三路AND成立后挡住它——这版直接导致STOP
//                                                             排空本身超时卡死，证明STOP的真实排空协议本来就需要bg_responder
//                                                             持续响应到底，不能提前掐断。三版都撤销。
//                                                             真正的性质（结合`PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_
//                                                             CONTRACT.md`第1070行核实）：real_red经常precisely落在
//                                                             C_LONGRUN_TARGET_RED_SAMPLES+1（三路AND里elapsed>=10s往往是最后
//                                                             满足的条件，bg_responder不会因为"数够了"就自动停手），这唯一一笔
//                                                             trailing事务如果恰好在"Q3释放、bg_responder计入已响应"和
//                                                             "Scheduler对该owner做出最终release判定"这两个时刻之间被STOP接受，
//                                                             就会被合法标记为discard-pending（success=0旁带释放，不产生正式
//                                                             NORMAL完成）——这是合同定义的行为，不是丢失/重复/泄漏。真正的
//                                                             修复落在判定逻辑本身：GROUP5_NO_STALE_CONTEXT改为容忍"结果数比
//                                                             事务数最多少1笔"这一种情况（且只能是这个方向，差额超过1笔或结果数
//                                                             反超事务数依然按真实缺陷处理），结算窗口本身改回原始的固定200周期
//                                                             简单设计。缩小规模（600/600/1.5秒）iverilog验证：
//                                                             GROUP5_NO_STALE_CONTEXT测得measurement_result_valid=1200在
//                                                             real_red+real_ir=1201的容忍范围内通过，STOP排空无超时，其余几条
//                                                             FAIL（GROUP2/3/4_EXISTENCE、GROUP5_REPEATED_*）都是缩小规模下走
//                                                             不完完整SAR9/SAR15周期数的预期副作用，不是新问题。
// 2026年10月08日        V1.4          Erie                  ABCD F-009后续（统筹决定20261008；TB本地标签GROUP5_NO_STALE_CONTEXT不变）：判据改为精确核算，不再容忍差额：正式结果数+STOP原因丢弃数==本组START之后的RED+IR事务数。缩小规模探针（40帧/100毫秒，与4000帧/10秒帧对齐相同，旧/新调度器一致）表明V1.3'最多少1笔'容忍吸收的并非STOP边界丢弃，而是JNT-09前缀中被flag_jnt_manual_adc_hold挡住的一次Q3释放，bg_responder在CONFIG中、本组START前约5微秒把它计成1笔RED。F-009后相邻宏帧严格5000拍，10秒到点时第4000帧已开始，STOP确认落在其RED owner提交之后，该owner按合同第13节迟到DONE规则1以success=0释放（STOP原因），构成第二笔合法差额。新增TB本地计数cnt_l10_base_responses（START时已计入的RED+IR）、cnt_l10_stop_completion_discards（本组STOP确认后、AMI STOP排空期间且无abort/系统故障的success=0完成）、cnt_l10_stop_result_discards（STOP确认后STOP原因的正式结果丢弃）。负对照：去掉STOP丢弃项、去掉START前基数、或隐去1笔真实结果，均失败。
//
// 复位后提交合法NORMAL双光MANUAL配置（含C11标称Stage1校准权重、
// peak_valley_config_valid=1）并START，之后完全依赖既有bg_responder真实响应，
// 直到real_red/real_ir均不少于4000且经过时间不少于10秒（Stage 3已验证的三路
// AND终止条件）才收尾，期间持续核对Group1/2/3/4已验证的断言、Group5新增的
// 反复精度进出/RED-IR连续性/RAW运算有界/无累积过期上下文断言，STOP后确认
// 干净排空
module tb_ppg_control_top_long_10_cycles();

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

	//---------------Group 5场景控制参数：直接复用Stage 3 RAW-12/13已验证的三路AND终止条件---------------//
	// C25合同第8.1节/Group5第9.2节共同的强制长跑参数（time类型，禁止32-bit截断）：
	// 必须real_red>=4000且real_ir>=4000且经过时间>=10秒三者同时成立才收尾，不能
	// 只看帧/样本数就停（Stage 3 V1.0已经真实踩过这个坑：bg_responder在Q3释放时
	// 完成响应而不是帧末尾，只看计数会在10秒下界前几百微秒就提前停止）
	localparam time C_PPG_MIN_DURATION_NS = 64'd10000000000; // 10秒measurement窗口下界
	localparam time C_SIM_TIMEOUT_NS = 64'd12000000000; // 12秒watchdog上限，相对仿真起点，非measurement窗口本身
	localparam integer C_LONGRUN_TARGET_RED_SAMPLES = 4000; // Group5要求的RED真实事务下界
	localparam integer C_LONGRUN_TARGET_IR_SAMPLES = 4000; // Group5要求的IR真实事务下界
	// Group5"反复"断言的最小重复次数下界：10个完整心动周期理论上产生10次CROSS/
	// 10次SAR9->SAR15入场/10次SAR15->SAR9返回，但边界处最后一个周期可能因为
	// 10秒下界先到而不完整，取8留合理裕量，同时仍然远高于Group1~4的1~2次
	localparam integer C_LONGRUN_MIN_REPEAT_COUNT = 8;
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
	integer cnt_l10_base_responses; // ABCD F-009：本组START被接受时已计入的RED+IR响应数（JNT前缀残留，不属于本组事务）
	integer cnt_l10_stop_completion_discards; // ABCD F-009：本组STOP确认后以success=0旁带释放的已提交owner笔数（STOP原因）
	integer cnt_l10_stop_result_discards; // ABCD F-009：本组STOP确认后以STOP原因丢弃的正式结果笔数
	reg flag_l10_scenario_started; // ABCD F-009：本组START已被接受
	reg flag_l10_scenario_stopped; // ABCD F-009：本组STOP已被确认
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

	//---------------Group 5事件捕获与断言状态：反复精度进出计数+RAW运算有界+存在性---------------//
	reg [15:0] cnt_entry_commits; // 真实SAR9->SAR15安全入场次数，Group2检查2推广为逐次取证后的计数
	reg [15:0] cnt_return_commits; // 真实SAR15->SAR9安全返回次数，Group3检查4推广为逐次取证后的计数
	reg flag_raw_arith_unbounded; // CROSS检测器自己的斜率/基线饱和诊断标志是否曾经触发过
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
	// 从仿真最开始就无条件计数，不受flag_jnt_manual_adc_hold影响（不像bg_responder
	// 那样在JNT-01~09期间被挡住）。诊断探针（已移除）确认了真实根因：JNT-02（RED，
	// SAR9）和JNT-07（RED，SAR15）自己驱动的都是真实合法成功事务（不是JNT-05/08
	// 那种abort/STOP discard-pending），会产生真实的o_measurement_result_valid，
	// 这个进程照样计数——但对应的事务从来没有被bg_responder数过（bg_responder在
	// JNT期间被flag_jnt_manual_adc_hold挡住），造成cnt_measurement_result_valid和
	// cnt_red_response+cnt_ir_response统计范围本来就对不上，不是时序竞争。真正的
	// 修复是run_jnt_baseline_01_09返回之后、本组场景真正开始之前把这个计数器清零
	// （见主序列JNT调用之后的cnt_measurement_result_valid=0），让它和bg_responder
	// 的计数范围对齐，只统计本组场景自己的正式结果
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

	//---------------Group2检查2：SAR9->SAR15安全切换取证进程（Group5推广为对每一次真实入场都取证）---------------//
	// 路径口径：ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.
	// ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst。
	// Group1~4只对第一次SAR9->SAR15切换取证，Group5合同要求"反复的精度进出"，
	// 所以这里去掉"只处理一次"的外层门控，改成每次o_fine_window_start_event
	// 真实握手都重新执行一遍完整的安全边界+连续性+码快照核对；
	// flag_group2_transition_checked保持sticky语义不变（一旦置1永远为1），
	// 继续给Group3/Group4依赖"SAR15是否已经至少入场过一次"的下游逻辑使用，
	// 不受这次推广影响；新增cnt_entry_commits统计真实入场次数供Group5存在性
	// 断言使用
	always @(posedge i_clk) begin
		if(!i_rstn) begin
			flag_group2_transition_checked <= 1'b0;
			cnt_entry_commits <= 16'd0;
		end else if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_precision_window_controller_Inst.o_fine_window_start_event) begin
			flag_group2_transition_checked <= 1'b1;
			cnt_entry_commits <= cnt_entry_commits + 16'd1;
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

	//---------------Group3检查4：SAR15->SAR9安全返回取证进程（Group5推广为对每一次真实返回都取证）---------------//
	// 完全镜像Group2检查2入场侧的做法：AMI层转发的o_active_precision_mode是电平信号，
	// 真正做返回判决的flag_return_commit和入场侧flag_enter_commit结构对称（同样门控
	// i_frame_safe_boundary&&i_precision_takeover_safe&&i_analog_safe），但
	// ami_active_precision_mode_o寄存器输出比判决拍晚一拍，所以核对上一拍锁存的门控
	// 快照，不是下降沿这一拍的瞬时值——直接复用Group2已经验证过的这个时序对齐结论，
	// 不重新踩坑。Group1~4只对第一次SAR15->SAR9返回取证，Group5合同要求"反复的
	// 精度进出"，去掉"只处理一次"的外层门控，改成每次真实下降沿都重新执行安全
	// 边界核对；flag_group3_return_commit_checked保持sticky语义不变（一旦置1
	// 永远为1），继续给Group4的尾部隔离窗口触发逻辑使用（只处理第一次返回后的
	// 尾部，这个范围收窄是刻意的设计决定，见本文件changelog），不受这次推广
	// 影响；新增cnt_return_commits统计真实返回次数供Group5存在性断言使用
	always @(posedge i_clk) begin
		if(!i_rstn) begin
			flag_group3_return_commit_checked <= 1'b0;
			cnt_return_commits <= 16'd0;
		end else if(flag_group2_transition_checked &&
			(reg_prev_active_precision_mode == 1'b1) && (ppg_control_top_Inst.ami_active_precision_mode_o == 1'b0)) begin
			flag_group3_return_commit_checked <= 1'b1;
			cnt_return_commits <= cnt_return_commits + 16'd1;
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

	//---------------Group5：有界RAW运算监视进程---------------//
	// 直接监视CROSS检测器自己的斜率/基线饱和诊断标志（o_slope_saturation_min/max、
	// o_baseline_saturation_low/high），断言整个10秒长跑里从不触发。这些标志是
	// RTL自己在斜率/基线运算触及ACTIVE配置边界时置位的诊断位，不是本文件推导出来
	// 的间接证据；本场景NORMAL档位幅度是Stage 1生成器V1.1版changelog里刻意选定、
	// 留在Q16配置边界内侧的取值，长跑不应该触发饱和——真触发了就是真实发现，不是
	// 断言写错
	always @(posedge i_clk) begin
		if(ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_slope_saturation_min ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_slope_saturation_max ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_baseline_saturation_low ||
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_baseline_saturation_high) begin
			if(!flag_raw_arith_unbounded) begin
				$display("FAIL GROUP5_BOUNDED_RAW_ARITHMETIC slope/baseline saturation diagnostic asserted during the run t=%0t slope_min=%0d slope_max=%0d baseline_low=%0d baseline_high=%0d",
					$time,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_slope_saturation_min,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_slope_saturation_max,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_baseline_saturation_low,
					ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.ppg_precision_window_integration_Inst.ppg_dynamic_baseline_cross_detector_Inst.o_baseline_saturation_high);
				cnt_error = cnt_error + 1;
			end
			flag_raw_arith_unbounded <= 1'b1;
		end
	end

	//---------------全局看门狗进程---------------//
	// 12秒watchdog，相对仿真起点，time类型，覆盖复位+START+measurement+排空+
	// 终止检查的全部预算；不是10秒measurement窗口本身的一部分
	initial begin
		flag_global_timeout = 1'b0;
		#(C_SIM_TIMEOUT_NS);
		flag_global_timeout = 1'b1;
		$display("FAIL LONG_10_CYCLES global watchdog timeout at t=%0t, forcing finish", $time);
		cnt_error = cnt_error + 1;
		$finish;
	end

	//---------------主序列---------------//
	initial begin
		cnt_error = 0;
		cnt_measurement_result_valid = 0;
		reg_measurement_start_time = 0;
		cnt_l10_base_responses = 0;
		cnt_l10_stop_completion_discards = 0;
		cnt_l10_stop_result_discards = 0;
		flag_l10_scenario_started = 1'b0;
		flag_l10_scenario_stopped = 1'b0;
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
		cnt_entry_commits = 16'd0;
		cnt_return_commits = 16'd0;
		flag_raw_arith_unbounded = 1'b0;
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

		// JNT-02/JNT-07自己驱动的是真实合法成功事务，会产生真实o_measurement_result_
		// valid，被上面那个不受flag_jnt_manual_adc_hold影响的计数进程计入了
		// cnt_measurement_result_valid，但对应事务从未被bg_responder数过（bg_responder
		// 全程被JNT期间的flag_jnt_manual_adc_hold挡住）。GROUP5_NO_STALE_CONTEXT的
		// 4000/4000/10秒全规模真实xsim复核第一次在这里抓到real_cal=0之后的下一个真实
		// bug：measurement_result_valid=8002对不上real_red+real_ir=8001，诊断探针
		// （已移除）定位到最早两次计数增量分别对应JNT-02（RED/SAR9）和JNT-07
		// （RED/SAR15）frame_id=0/sample_index=0的真实成功完成，在bg_responder自己的
		// 计数还是0的时候就已经发生。这不是时序竞争，是两个计数器的统计范围本来就没
		// 对齐；清零这里，让计数范围和bg_responder精确对齐到"只统计本组场景自己的
		// 正式结果"
		cnt_measurement_result_valid = 0;

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
		cnt_l10_base_responses = cnt_red_response + cnt_ir_response; // ABCD F-009：START前已计入的响应不属于本组
		flag_l10_scenario_started = 1'b1;
		if((o_lifecycle_state != ST_RUN) || o_system_fault_blocking) begin
			$display("FAIL LONGRUN START accepted into RUN");
			cnt_error = cnt_error + 1;
			$finish;
		end else begin
			$display("PASS LONGRUN START accepted into RUN, measurement start latched t=%0t", reg_measurement_start_time);
		end

		// 事件驱动主循环：完全依赖bg_responder的真实响应和上面各专用捕获/断言进程，
		// 主序列本身只负责等待覆盖窗口跑完。终止条件直接复用Stage 3 RAW-12已验证
		// 过的三路AND——red>=4000且ir>=4000且经过时间>=10秒必须同时成立，不能只看
		// 帧/样本数就停（Stage 3自己的V1.0真实踩过"只看计数提前几百微秒停止"这个坑）
		while(!((cnt_red_response >= C_LONGRUN_TARGET_RED_SAMPLES) && (cnt_ir_response >= C_LONGRUN_TARGET_IR_SAMPLES)
			&& (($time - reg_measurement_start_time) >= C_PPG_MIN_DURATION_NS)) && !flag_global_timeout) begin
			@(posedge i_clk);
		end
		reg_measurement_elapsed_time = $time - reg_measurement_start_time;

		// 结算沉降窗口：三路AND条件成立的那一拍，最后一笔刚被bg_responder计数为
		// "已响应"的RED/IR事务，其正式结果（校准+DC恢复+router）可能还没来得及
		// 传播到o_measurement_result_valid——这不是FIR的10样本群延时（那个只影响
		// 算法层detection fork分支），是更短的正式结果流水延迟。给200个时钟周期
		// （100us，相对10秒窗口可忽略）的结算沉降时间，等这类已经在途、马上就
		// 完成的正式结果真正吐出来，再发STOP——这是让测试时序贴近真实"优雅停止"
		// 场景，不是放松GROUP5_NO_STALE_CONTEXT本身核对的严格度。
		//
		// 本文件V1.3先后尝试过三版修复才定位到这里真正的教训，完整排查过程见
		// 下方GROUP5_NO_STALE_CONTEXT判定处的注释：（1）冻结三路AND成立那一拍的
		// 计数、等正式结果追上冻结目标——真实xsim复核发现冻结目标本身可能包含
		// 一笔需要更久才能吐出结果的事务，这版更脆弱；（2）把窗口从200临时放大到
		// 5000——证明纯粹加长等待时间毫无帮助，只要bg_responder还在继续响应
		// 新事务，任何时刻检查都会有恰好一笔"刚被计数、结果还没吐出来"的在途
		// 事务，缺口永远补不上；（3）三路AND一成立就用flag_jnt_manual_adc_hold
		// 让bg_responder停手——这版反而让STOP排空本身超时卡死，证明STOP的真实
		// 排空协议本来就需要bg_responder持续响应到底（哪怕是本次核对scope之外
		// 的事务），不能提前掐断。三版都撤销，结算窗口改回原始的固定200周期
		// 简单设计，真正的修复落在下方判定逻辑本身，不在这个等待窗口
		repeat(200) @(posedge i_clk);

		// RAW-12风格：post-START运行覆盖至少10秒、4000 RED、4000 IR真实事务，
		// 三者独立断言，不用"到了10秒"代替"数够了4000笔"，反之亦然
		if(flag_global_timeout) begin
			$display("FAIL LONGRUN10_COVERAGE global watchdog fired before RED/IR both reached target red=%0d ir=%0d elapsed_ns=%0d",
				cnt_red_response, cnt_ir_response, reg_measurement_elapsed_time);
			cnt_error = cnt_error + 1;
		end else if(cnt_red_response < C_LONGRUN_TARGET_RED_SAMPLES) begin
			$display("FAIL LONGRUN10_COVERAGE RED sample count insufficient red=%0d target=%0d", cnt_red_response, C_LONGRUN_TARGET_RED_SAMPLES);
			cnt_error = cnt_error + 1;
		end else if(cnt_ir_response < C_LONGRUN_TARGET_IR_SAMPLES) begin
			$display("FAIL LONGRUN10_COVERAGE IR sample count insufficient ir=%0d target=%0d", cnt_ir_response, C_LONGRUN_TARGET_IR_SAMPLES);
			cnt_error = cnt_error + 1;
		end else if(reg_measurement_elapsed_time < C_PPG_MIN_DURATION_NS) begin
			$display("FAIL LONGRUN10_COVERAGE elapsed time insufficient elapsed_ns=%0d min_ns=%0d red=%0d ir=%0d",
				reg_measurement_elapsed_time, C_PPG_MIN_DURATION_NS, cnt_red_response, cnt_ir_response);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS LONGRUN10_COVERAGE post-START run covers real_red=%0d real_ir=%0d elapsed_ns=%0d (>=%0d) with no 32-bit overflow (time-typed)",
				cnt_red_response, cnt_ir_response, reg_measurement_elapsed_time, C_PPG_MIN_DURATION_NS);
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

		// Group5存在性断言：证明"反复"真实发生过至少C_LONGRUN_MIN_REPEAT_COUNT次，
		// 不是只测了Group1~4那样的单轮/双轮周期就号称覆盖了10周期长跑要求；同时
		// 核对RED/IR事务与正式结果之间没有累积的丢失/重复（owner泄漏的直接证据）
		if(reg_cross_count < C_LONGRUN_MIN_REPEAT_COUNT) begin
			$display("FAIL GROUP5_REPEATED_BASELINE fewer than %0d real CROSS events captured (count=%0d), repeated baseline generation not demonstrated",
				C_LONGRUN_MIN_REPEAT_COUNT, reg_cross_count);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP5_REPEATED_BASELINE cross_count=%0d >= %0d real crossings, each independently B[f]-formula-verified",
				reg_cross_count, C_LONGRUN_MIN_REPEAT_COUNT);
		end
		if(cnt_entry_commits < C_LONGRUN_MIN_REPEAT_COUNT) begin
			$display("FAIL GROUP5_REPEATED_PRECISION_ENTRY fewer than %0d real SAR9->SAR15 safe-boundary commits observed (count=%0d)",
				C_LONGRUN_MIN_REPEAT_COUNT, cnt_entry_commits);
			cnt_error = cnt_error + 1;
		end else if(cnt_return_commits < C_LONGRUN_MIN_REPEAT_COUNT) begin
			$display("FAIL GROUP5_REPEATED_PRECISION_RETURN fewer than %0d real SAR15->SAR9 safe-boundary commits observed (count=%0d)",
				C_LONGRUN_MIN_REPEAT_COUNT, cnt_return_commits);
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP5_REPEATED_PRECISION_ENTRY_RETURN entry_commits=%0d return_commits=%0d, both >= %0d, each independently safe-boundary-verified",
				cnt_entry_commits, cnt_return_commits, C_LONGRUN_MIN_REPEAT_COUNT);
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
					$display("FAIL LONG_10_CYCLES stop ack timeout");
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
					$display("FAIL LONG_10_CYCLES drain back to CONFIG timeout");
					cnt_error = cnt_error + 1;
				end
			end
		join
		if(o_system_fault_blocking) begin
			$display("FAIL LONG_10_CYCLES unexpected system fault blocking after STOP");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS LONG_10_CYCLES STOP drained back to CONFIG without fault");
		end

		// Group5检查：没有累积的过期上下文/owner泄漏——核对RED/IR真实事务与正式
		// 结果笔数。这条检查特意放在STOP+排空之后而不是主循环刚退出那一刻：结果流水
		// 从ADC响应到o_measurement_result_valid之间有真实的多级管线延迟（DC恢复、FIR
		// 群延时等），主循环退出时最后一两笔响应的结果可能还在管线里没吐出来，此时
		// 核对1:1会误报"丢失"；STOP+排空强制清空管线之后再核对，才是Stage 3自己
		// LONGRUN_TB_PASS最终横幅里"8000笔ADC响应对应8000笔正式结果"那条证据真正
		// 核对的时刻，本文件沿用同一时机，不是新发明。
		//
		// V1.3真实4000/4000/10秒xsim复核确认real_red经常precisely落在
		// C_LONGRUN_TARGET_RED_SAMPLES+1（三路AND里elapsed>=10s往往是最后满足的
		// 条件，红/绿计数在那之前就已经跑过目标值，bg_responder不会因为"数够了"
		// 就自动停手），且完整STOP+排空之后，这笔"多出来"的最后事务的正式结果
		// 有时依然不出现——排查过（1）冻结计数窗口、（2）放大固定等待窗口、
		// （3）三路AND一成立就让bg_responder停手（这版反而让STOP排空本身卡死
		// 超时，证明STOP真实排空协议需要bg_responder持续响应到底）三种思路，
		// 全部证明这不是等待时长或时序竞争的问题：`PPG_400HZ_FRAME_CALIBRATION_
		// SCHEDULER_INTERFACE_CONTRACT.md`第1070行明文规定，STOP接受时已提交但
		// 尚未被Scheduler正式释放的owner标记为discard-pending，只能通过
		// success=0旁带释放，不产生正式NORMAL完成——bg_responder在Q3释放当拍就
		// 计入"已响应"（早于Scheduler对该owner做出最终release判定），如果STOP
		// 恰好在这两个时刻之间被接受，这唯一一笔trailing事务被合法标记为
		// discard-pending完全符合合同定义，不是丢失、重复或泄漏。因此核对改为
		// 容忍"最多1笔"的合法差额（且只能是正式结果少于真实事务这个方向——
		// 结果数超过事务数、或差额超过1笔，仍然按真实缺陷处理）
		// ABCD F-009（统筹决定20261008，TB本地名GROUP5_NO_STALE_CONTEXT，判据改为精确核算，不再容忍差额）：
		// 实测（缩小规模探针，旧/新调度器一致）旧版"容忍少1笔"吸收的并不是STOP边界丢弃，而是JNT-09前缀里被
		// flag_jnt_manual_adc_hold挡住的一次Q3释放——hold撤销后bg_responder在本组START前把它计成1笔RED；
		// F-009后相邻宏帧严格5000拍，10秒到点后第4000帧已开始，STOP确认落在其RED owner提交之后，
		// 该owner按合同第13节迟到DONE规则1以success=0旁带释放（STOP原因），又多出1笔合法差额。
		// 精确核算：正式结果数 + STOP原因丢弃数（success=0旁带释放 + STOP原因正式结果丢弃） == 本组START之后的RED+IR事务数
		if((cnt_measurement_result_valid + cnt_l10_stop_completion_discards + cnt_l10_stop_result_discards) !=
			(cnt_red_response + cnt_ir_response - cnt_l10_base_responses)) begin
			$display("FAIL GROUP5_NO_STALE_CONTEXT measurement_result_valid=%0d + stop_discards=%0d (completion=%0d result=%0d) != scenario transactions=%0d (real_red+real_ir=%0d - pre_start=%0d), possible loss/duplication/owner leakage",
				cnt_measurement_result_valid, cnt_l10_stop_completion_discards + cnt_l10_stop_result_discards, cnt_l10_stop_completion_discards, cnt_l10_stop_result_discards,
				cnt_red_response + cnt_ir_response - cnt_l10_base_responses, cnt_red_response + cnt_ir_response, cnt_l10_base_responses);
			cnt_error = cnt_error + 1;
		end else if(flag_raw_arith_unbounded) begin
			$display("FAIL GROUP5_NO_STALE_CONTEXT slope/baseline saturation was observed during the run, see the earlier GROUP5_BOUNDED_RAW_ARITHMETIC FAIL for detail");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP5_NO_STALE_CONTEXT measurement_result_valid=%0d + stop_discards=%0d (completion=%0d result=%0d) == scenario transactions=%0d (real_red+real_ir=%0d - pre_start=%0d) after STOP drain, no RAW-arithmetic saturation observed",
				cnt_measurement_result_valid, cnt_l10_stop_completion_discards + cnt_l10_stop_result_discards, cnt_l10_stop_completion_discards, cnt_l10_stop_result_discards,
				cnt_red_response + cnt_ir_response - cnt_l10_base_responses, cnt_red_response + cnt_ir_response, cnt_l10_base_responses);
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
			$display("FAIL GROUP5_PROTOCOL_STICKY o_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_scheduler_completion_mismatch_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_scheduler_completion_mismatch_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_scheduler_protocol_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_scheduler_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ami_integration_protocol_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_ami_integration_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ssw_switch_protocol_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_ssw_switch_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_ssw_transaction_mismatch_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_ssw_transaction_mismatch_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_characterization_protocol_error_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_characterization_protocol_error_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else if(o_result_discard_summary_sticky) begin
			$display("FAIL GROUP5_PROTOCOL_STICKY o_result_discard_summary_sticky asserted during the run");
			cnt_error = cnt_error + 1;
		end else begin
			$display("PASS GROUP5_PROTOCOL_STICKY all blocking scheduler/AMI/SSW/characterization/discard protocol-error stickies stayed 0 across real_red=%0d real_ir=%0d transactions",
				cnt_red_response, cnt_ir_response);
		end
		// 非阻断历史诊断类sticky：只记录观测结果，不计入cnt_error，理由见上方大注释
		if(o_scheduler_launch_timeout_sticky) begin
			$display("INFO GROUP5_HISTORICAL_DIAG o_scheduler_launch_timeout_sticky asserted during the run (non-blocking per contract)");
		end
		if(o_scheduler_owner_deadline_timeout_sticky) begin
			$display("INFO GROUP5_HISTORICAL_DIAG o_scheduler_owner_deadline_timeout_sticky asserted during the run (non-blocking per contract)");
		end
		if(o_ssw_owner_deadline_timeout_sticky) begin
			$display("INFO GROUP5_HISTORICAL_DIAG o_ssw_owner_deadline_timeout_sticky asserted during the run (non-blocking per contract)");
		end
		if(o_ssw_calibration_timeout_sticky) begin
			$display("INFO GROUP5_HISTORICAL_DIAG o_ssw_calibration_timeout_sticky asserted during the run (non-blocking per contract)");
		end

		// 汇总并干净退出
		if(cnt_error == 0) begin
			$display("LONG_10_CYCLES_TB_PASS real_red=%0d real_ir=%0d real_cal=%0d elapsed_ns=%0d measurement_result_valid=%0d peak_count=%0d valley_count=%0d cross_count=%0d return_count=%0d entry_commits=%0d return_commits=%0d",
				cnt_red_response, cnt_ir_response, cnt_cal_response, reg_measurement_elapsed_time, cnt_measurement_result_valid,
				reg_peak_count, reg_valley_count, reg_cross_count, reg_return_count,
				cnt_entry_commits, cnt_return_commits);
		end else begin
			$display("LONG_10_CYCLES_TB_FAIL error_count=%0d", cnt_error);
		end
		$finish;
	end


	//---------------ABCD F-009：本组STOP原因丢弃计数（服务GROUP5_NO_STALE_CONTEXT精确核算）---------------//
	// 只统计本组START之后、本组STOP确认之后的丢弃：已提交owner的success=0旁带释放须发生在AMI STOP排空期间且无abort/系统故障；
	// 正式结果丢弃须带STOP原因编码。abort、系统故障或完成丢失类丢弃不计入，出现即导致核算不平
	always @(posedge i_clk) begin
		if(flag_l10_scenario_started && o_stop_ack_event) flag_l10_scenario_stopped = 1'b1;
		if(flag_l10_scenario_stopped && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_adc_transaction_complete_event && !ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_adc_transaction_success &&
			ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_stop_result_draining && !ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_abort_draining && !ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.flag_system_fault_discard_pending)
			cnt_l10_stop_completion_discards = cnt_l10_stop_completion_discards + 1;
		if(flag_l10_scenario_stopped && ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_measurement_result_discard_event && (ppg_control_top_Inst.ppg_adc_measurement_idac_integration_Inst.o_measurement_result_discard_reason == 2'b00))
			cnt_l10_stop_result_discards = cnt_l10_stop_result_discards + 1;
	end

endmodule
