# PPG 全套回归基线（2026-09-30）

## 0. 结论先行

| 分组 | TB 数 | 通过 | 失败 / 未跑起来 | 与历史基线对比 |
|---|---|---|---|---|
| 19-TB 主回归（`ppg_control_top`） | 19 | **19**（合计 **1208 PASS / 0 FAIL**） | 0 | 与 09-19 基线逐 TB 相同；19 份的 PASS 行排序后逐行 diff 全为 0；18 份的 `$finish` 时刻与横幅计数逐字相同，1 份（robustness）横幅计数与结束时刻不同，已逐条解释（§3.3） |
| 芯片顶层（`ppg_chip_digital_top`） | 1 | **1**（6 PASS） | 0 | 与 09-17 逐字相同（PASS 行、`$finish` 时刻 2558250 ns），**SID-05 之后首次运行，无回归** |
| 模块级 · 芯片层级内 | 26 | 20 | **6**（2 份仿真 FAIL、3 份 xelab 失败、1 份集成 TB FAIL） | 6 份全部根因为 **TB 落后于 RTL**，每份都用诊断副本实证；**未发现 RTL 回归** |
| 模块级 · 孤立模块 | 4 | **4** | 0 | — |

- 被测 commit：**`e769a67`**（`xinyanbaiqi/zlcx` main；本报告提交时 origin/main 已到 `b4fda05`，该 commit 只改了 `contracts/` 和一份报告，`git diff e769a67 b4fda05 -- rtl` 为空，结论照样适用）。
- **本次未改任何 RTL/TB**（第 0 步补的两个 `.vh` 除外）。所有诊断副本都在仓库外的临时目录中，没有提交。
- 需要用户决定的事项汇总在 §8。

## 1. 被测对象、工具与运行方式

| 项 | 值 |
|---|---|
| 被测 commit | `e769a67ddefe302c30ffa2b5a7bc208047152ad5` |
| 仿真器（主） | Vivado Simulator v2022.2（SW Build 3671981，本机 `C:\Xilinx\Vivado\2022.2\bin` 下的 xvlog/xelab/xsim） |
| 仿真器（辅助交叉验证） | Icarus Verilog 12.0 (devel) (s20150603-1539-g2693dd32b) |
| 运行目录（仓库外） | `D:\PPG\verilog\ppg_regression_runs\e769a67_20260930\` |
| 运行时间 | 19-TB：2026-09-30 14:14:39 → 16:41:11；芯片顶层：14:14:44 → 14:15:00；模块级：14:22:25 → 14:33:48 |

**导出方式与一处偏差（如实记录）**：按计划用 `git archive e769a67 rtl | tar -x` 导出，但该克隆设置了 `core.autocrlf=true`，`git archive` 会按这个设置把全部 143 个文件转成 CRLF，导出字节与 commit 的 blob 不一致（逐文件 `git hash-object --no-filters` 与 `ls-tree` 比对：143/143 不同），`.sh` 带 CRLF 在 bash 下也会出问题。改用 **`git -c core.autocrlf=false archive e769a67 rtl | tar -x`** 重新导出，复核结果为 **143/143 与 blob 逐字节一致**。

**并发说明**：19-TB 与芯片顶层、模块级批次是在不同目录中并行运行的（各自的 `xsim.dir` 相互独立）。耗时列仅供参考，受并发负载影响，不能作为性能对比。

## 2. 第 0 步：仓库缺陷修复（commit `e769a67`，已 push）

- 缺失文件：`rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh`（源文件 mtime 09-17 19:53）、`rtl/ppg_control_top/tb_ppg_real_raw_generator.vh`（08-24 16:12）。两者都早于 09-19 产出 1208 基线的那次回归（该次日志 mtime 为 09-18 22:04 至 09-19 00:13），所以就是基线所用的版本。
- 从 `D:\PPG\verilog\jxa\ppg_control_top\` 原样复制，逐字节比对一致：sha256 `b150c8a4…7101b` / `0eb1b544…1323`；提交后的 blob 哈希与源文件 `git hash-object --no-filters` 也一致（`a411db91…` / `6cd33f01…`）。
- 独立扫描：仓库内共 106 个 `.v/.vh/.sv/.svh` 文件，全部 `` `include `` 共 26 处，分布在 18 份 TB 中，**全部指向这两个文件**；补齐后没有其它断链。19 份主回归 TB 中唯一不 include 的是 `tb_ppg_control_top_injection.v`。
- 只 `git add` 了这两个具体路径；提交前用 `ListAgents` 确认并与另一会话协调过。

## 3. 19-TB 主回归（`rtl/ppg_control_top/run_xsim_regression.sh`）

判定标准（四条都要满足）：xvlog/xelab/xsim 返回码均为 0；日志中有 `$finish called`；没有 `^FAIL`/`ERROR:`/`FATAL`；TB 自带的最终结论横幅存在且为 PASS 版本。逐个读 `xsim.log` 判定，**未使用 summary.tsv**（原因见 §7）。

### 3.1 逐 TB 结果

| TB | xvlog/xelab/xsim | PASS（新/09-19） | FAIL | `$finish` | 横幅 | PASS 行 diff | `$finish` 时刻相同 | 耗时 s（新/旧） |
|---|---|---|---|---|---|---|---|---|
| tb_diag_algo_probe | 0/0/0 | 5 / 5 | 0 | 1 | `LONGRUN_TB_PASS real_red=1200 real_ir=1200 …` | 0 | 是 | 474 / 463 |
| tb_ppg_real_raw_generator_selfcheck | 0/0/0 | 40 / 40 | 0 | 1 | `RAWGEN_SELFCHECK_PASS` | 0 | 是 | 9 / 8 |
| tb_ppg_control_top | 0/0/0 | 71 / 71 | 0 | 1 | `SMOKE_TB_PASS real_adc_responses=49 measurement_result_valid=33` | 0 | 是 | 21 / 19 |
| tb_ppg_control_top_baseline_cross | 0/0/0 | 75 / 75 | 0 | 1 | `BASELINE_CROSS_TB_PASS …` | 0 | 是 | 466 / 426 |
| tb_ppg_control_top_fir_tail_isolation | 0/0/0 | 80 / 80 | 0 | 1 | `FIR_TAIL_ISOLATION_TB_PASS …` | 0 | 是 | 376 / 350 |
| tb_ppg_control_top_adc_numeric_scoreboard | 0/0/0 | 69 / 69 | 0 | 1 | `ADC_NUMERIC_SCOREBOARD_TB_PASS result_captures=16 track_branch_fires=16` | 0 | 是 | 17 / 16 |
| tb_ppg_control_top_idac_bus_isolation | 0/0/0 | 70 / 70 | 0 | 1 | `IDAC_BUS_ISOLATION_TB_PASS …` | 0 | 是 | 83 / 78 |
| tb_ppg_control_top_injection | 0/0/0 | 15 / 15 | 0 | 1 | `INJ_TB_PASS` | 0 | 是 | 15 / 13 |
| tb_ppg_control_top_lifecycle_fault_adc_anomaly | 0/0/0 | 80 / 80 | 0 | 1 | `LIFECYCLE_FAULT_ADC_ANOMALY_TB_PASS …` | 0 | 是 | 29 / 27 |
| tb_ppg_control_top_input_light_static_matrix | 0/0/0 | 73 / 73 | 0 | 1 | `INPUT_LIGHT_STATIC_MATRIX_TB_PASS …` | 0 | 是 | 23 / 22 |
| tb_ppg_control_top_normal_slow_tracking | 0/0/0 | 72 / 72 | 0 | 1 | `NORMAL_SLOW_TRACKING_TB_PASS …` | 0 | 是 | 327 / 321 |
| tb_ppg_control_top_no_recheck_control | 0/0/0 | 61 / 61 | 0 | 1 | `NO_RECHECK_CONTROL_TB_PASS …` | 0 | 是 | 323 / 318 |
| tb_ppg_control_top_owner_identity_backpressure | 0/0/0 | 68 / 68 | 0 | 1 | `OWNER_IDENTITY_BACKPRESSURE_TB_PASS …` | 0 | 是 | 31 / 29 |
| tb_ppg_control_top_peak_valley_return | 0/0/0 | 75 / 75 | 0 | 1 | `PEAK_VALLEY_RETURN_TB_PASS …` | 0 | 是 | 283 / 273 |
| tb_ppg_control_top_periodic_recheck_recovery | 0/0/0 | 70 / 70 | 0 | 1 | `PERIODIC_RECHECK_RECOVERY_TB_PASS result_captures=2821 owner_commit_total=2906` | 0 | 是 | 545 / 537 |
| tb_ppg_control_top_robustness_corner_waveforms | 0/0/0 | 67 / 67 | 0 | 1 | `ROBUSTNESS_CORNER_WAVEFORMS_TB_PASS measurement_result_valid=13924 order_violation_count=0`（旧 12126） | 0 | **否**（15158849751 → 17407042751 ns） | 2673 / 2284 |
| tb_ppg_control_top_startup_idac_calibration | 0/0/0 | 83 / 83 | 0 | 1 | `STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2` | 0 | 是 | 15 / 14 |
| tb_ppg_control_top_long_10_cycles | 0/0/0 | 129 / 129 | 0 | 1 | `LONG_10_CYCLES_TB_PASS …` | 0 | 是 | 1544 / 1536 |
| tb_ppg_control_top_longrun | 0/0/0 | 5 / 5 | 0 | 1 | `LONGRUN_TB_PASS real_red=4000 real_ir=4000 …` | 0 | 是 | 1530 / 1482 |
| **合计** | | **1208 / 1208** | **0** | | | | | |

- 除 robustness 外，18 份的最终横幅（含全部计数字段）与 09-19 **逐字相同**。
- xvlog 警告数 19 份均为 0（新旧相同）；xelab 警告数新旧逐份相同（17 份各 2 条、robustness 1 条、raw_generator 0 条），内容都是 `o_active_precision_mode` 等输出未连接，以及测试注入输入 `is not connected`（后者见 §6.3）。
- 旧日志：`D:\PPG\verilog\jxa\ppg_control_top\xsim_regression_20260906\<tb>\xsim.log`（mtime 09-18 22:04 至 09-19 00:13）。

### 3.2 `adc_numeric_scoreboard`：09-28 增加了 ADCN-03/07 检查，PASS 数为什么没变（69 = 69）

- **PASS 行逐行 diff 为 0**，横幅与 `$finish` 时刻（24455251 ns）也完全相同。
- 原因：09-28 的 V1.1 新增的 ADCN-03（`o_saturation_low/high` 直接读取）和 ADCN-07（8 字段身份绑定）检查，都实现为**已有逐事务判定内部、只在不一致时打印 `FAIL` 并累加 `cnt_error` 的门控**，本身不打印 PASS 行。所以按设计 PASS 数不会增加；TB 自己的 V1.1 changelog 记录的 09-28 双工具结果也正是 `result_captures=16 track_branch_fires=16`、0 FAIL，从未说过 PASS 数会增加。
- **门控是否真的执行过（变异探针）**：只看"0 条 FAIL"，区分不了"执行了且通过"和"根本没执行"。于是在临时副本里把第 1101 行 `reg_cap_frame_type !== reg_owner_snapshot_frame_type` 改成 `===` 后重跑，结果打出 **13 条 `identity binding mismatch`**，横幅变为 `ADC_NUMERIC_SCOREBOARD_TB_FAIL error_count=13`。这证明 16 次 capture 中有 13 次走这条 8 字段核对路径，原始运行中这 13 次核对确实执行并全部一致。

### 3.3 `robustness_corner_waveforms`：横幅计数与结束时刻不同的逐条解释

- **67 条 PASS 行逐行完全相同**，所以断言集合与结论都没有变化。
- 差异来源：这份 TB 在 09-19 之后有新版本。09-18 的 V1.6/V1.7 和 09-19 的 V1.8/V1.9 是 PRC-04/PRC-06 调查期间的修改；09-19 基线的这份日志 mtime 为 09-18 23:22，用的是较早的版本。**这些代码并不是"休眠监视"**：V1.8 在 profile 4 中新增了一段真实运行的 **PRC-04b 子阶段**（零脉搏幅度 + 强漂移，red=900 个样本），并带有 `DIAG PRC04B_TRACE` 周期追踪和 2 条 `INFO PRC-04b …` 结论行。
- 定量核对：
  - 900 帧 × 2.5 ms ≈ 2.25 s；实测 `$finish` 时刻差 17407042751 − 15158849751 = **2 248 193 000 ns**。
  - 横幅 `measurement_result_valid` 13924 − 12126 = **1798** ≈ 900 红 + 898 红外（这一段产生的结果）。
  - 峰/谷/穿越 `CAPTURE` 行（frame_id、数值、计数）**逐条相同**：插入点之前的 64 条时移为 0，之后的 34 条统一时移 **2 248 193 000 000 ps**，与上面的差值完全一致。
  - 去掉 PRC-04b 相关行和时间戳后，剩下的差异只有：① 9 条额外的 `DIAG progress … profile=4`，是那 900 个样本期间打印的；② 后续 profile 5/6/7/0 的进度打印中 red/ir 计数差 ±1。后者是打印时机问题：进度打印的时移为 2 248 273 000 000 ps，比帧时移多 80 µs，正好是 R/IR 之间的偏移，于是打印落在 IR 采样的另一侧。这是纯显示差异。
- 结论：差异 = PRC-04b 这段额外激励本身，其余行为逐位一致，**不是 RTL 变化引起的**。旧基线的 1208 与本次 1208 中，这份 TB 都是 67。

### 3.4 其它 09-19 之后改过的文件

- `tb_ppg_control_top_injection.v`（只改注释）：15/15，PASS 行、横幅、`$finish` 均相同。
- 共享 RTL `ppg_dynamic_baseline_cross_detector.v`（只改注释标签）：所有 19 份除 robustness 已解释的差异外，逐字相同。

## 4. 芯片顶层（`rtl/ppg_chip_digital_top/run_xsim_regression.sh`）

| TB | xvlog/xelab/xsim | PASS | FAIL | `$finish` | 横幅 | 与 09-17 对比 | 耗时 s |
|---|---|---|---|---|---|---|---|
| tb_ppg_chip_digital_top | 0/0/0 | 6 | 0 | 1（2558250 ns） | `TB_CHIP_DIGITAL_TOP_PASS all scenarios passed` | 6 条 PASS 行逐字相同，`$finish` 时刻相同；xvlog/xelab 警告 0/0（旧 0/0） | 15（旧 13） |

这是芯片顶层 TB **第一次在 SID-05（09-18 改动 `ppg_control_top` 等 3 个共享 RTL）之后的代码上运行**，结果与 09-17 逐字一致，没有回归。注：该脚本的输出目录名用运行日期，本次为 `xsim_regression_20260930`。

## 5. 模块级 unit TB（30 份）

做法：每份 TB 使用独立的工作目录（`<运行目录>\unit\<tb>\`），xvlog 编译"全部 37 个非 TB RTL + 该 TB"（`-i` 指向 TB 所在目录），xelab 以 TB 模块为顶层，参数与项目脚本一致（`-timescale 1ns/1ps`），然后 `xsim -runall`。37 个非 TB RTL 之间没有重名模块。驱动脚本 `run_unit_tbs.sh` 放在运行目录中。第一次尝试因 runner 把 MSYS 路径 `/d/…` 传给了 Windows 版 `xvlog.bat` 而全部编译失败，属于 runner 自身的 bug；已改用 `D:/…` 路径重跑，旧产物保留在 `unit_failed_msys_path_attempt\`。

"PASS" 一列取 TB 自己报告的计数；只打一行汇总的 TB 记为"汇总 1 行"（逐条检查在失败时才打印）。

### 5.1 芯片层级内（26 份）

| TB | xvlog/xelab/xsim | PASS | FAIL | `$finish` | 自带结论横幅 | 历史 / 差异 | 耗时 s |
|---|---|---|---|---|---|---|---|
| tb_ppg_400hz_frame_calibration_scheduler | 0/0/0 | 58 | **1** | 1 | `FSC-01 through FSC-59: pass=58 fail=1` | 历史 59/59 → **FAIL，见 §6.1** | 10 |
| tb_ppg_active_v4_control_plane_integration | 0/0/0 | 22 | 0 | 1 | `ALL AV4C-01 THROUGH AV4C-22 PASSED` | 一致 | 9 |
| tb_ppg_adc_async_stage_capture | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS ppg_adc_async_stage_capture explicit-frame checks` | — | 9 |
| tb_ppg_adc_dc_recovery | 0/0/0 | 汇总 2 行 | 0 | 1 | `PASS ppg_adc_dc_recovery DCR-01..DCR-22` | 悬空 8 个输入，tie-0 探针结果相同（§6.3） | 8 |
| tb_ppg_adc_measurement_idac_integration（AMI） | 0/0/0 | 48 | 0 | 1 | `AMI-01 through AMI-47 plus N08-01 PASS: 48 real comparisons` | 与 09-08 的 48/48 相同；SID-05 新增的 `i_cal_owner_deadline_event` 在此 TB 中悬空、未被覆盖（§6.3） | 15 |
| tb_ppg_adc_pipeline_overlap_corrector | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS … OVL-01..OVL-17 and 1024-code sweep` | 悬空 10 个输入，tie-0 相同 | 14 |
| tb_ppg_adc_programmable_reconstructor | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS … PR-01..PR-14 and 1024-code sweep` | — | 86 |
| tb_ppg_adc_result_router | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS ppg_adc_result_router RTR-01..RTR-13` | 悬空 `i_run_generation`，tie-0 相同 | 9 |
| tb_ppg_adc_s1_programmable_calibrator | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS … CAL-01..CAL-17` | — | 38 |
| tb_ppg_adc_s1_redundancy_corrector | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS … integrated exhaustive checks` | — | 53 |
| tb_ppg_amb_recheck_scheduler | 0/**1**/— | — | — | — | — | **xelab 失败，见 §6.3** | 5 |
| tb_ppg_characterization_control_cdc | 0/0/0 | 26 | 0 | 1 | `ALL CCC-01 TO CCC-26 PASS (26 checks)` | — | 9 |
| tb_ppg_coarse_detection_fir | 0/0/0 | 103（`[PASS]` 格式） | 0 | 1 | `PPG_COARSE_DETECTION_FIR_V2_TB_PASS pass=103` | 历史 98 → 103，见 §6.5 | 10 |
| tb_ppg_dynamic_baseline_cross_detector | 0/0/0 | 65 | 0 | 1 | `ALL BSL-01 THROUGH BSL-39, OPT-01 THROUGH OPT-24 AND OPTC-01 THROUGH OPTC-02 PASS count=65` | — | 10 |
| tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence | 0/0/0 | 汇总 1 行 | 0 | 1 | `PHASE_A_ARITH_EQV PASS vectors=20005` | — | 9 |
| tb_ppg_idac_code_controller | 0/0/0 | 67 行 | **34 行（33 errors）** | 1 | `FAIL: ppg_idac_code_controller V2.1 regression found 33 errors` | **FAIL，见 §6.2** | 11 |
| tb_ppg_idac_code_controller_wave | 0/**1**/— | — | — | — | — | **xelab 失败，过时的演示 TB，见 §6.3** | 4 |
| tb_ppg_normal_transaction_fork | 0/0/0 | 50 | 0 | 1 | `PASS: ppg_normal_transaction_fork completed FFK-01 through FFK-09` | 与 50/50 相同；悬空 10 个输入，tie-0 相同 | 8 |
| tb_ppg_peak_valley_window_detector（PVW） | 0/0/0 | 54 checks（`[PASS]` 格式） | 0 | 1 | `PVW-01 through PVW-48 ALL PASS: 54 checks` | 历史 46 → 54，见 §6.5 | 12 |
| tb_ppg_precision_window_controller（PWC） | 0/0/0 | 48 | 0 | 1 | `PWC-01 through PWC-41 ALL PASS pass=48 fail=0` | 历史 40 → 48，见 §6.5 | 8 |
| tb_ppg_precision_window_integration（PWI） | 0/**1**/— | — | — | — | — | **xelab 失败，见 §6.3** | 4 |
| tb_ppg_sar9_sar15_safe_selection_wrapper（SSW） | 0/0/0 | 52 条 `SSW-nn PASS` | 0 | 1 | `ALL SSW-01 THROUGH SSW-52 PASS` | 悬空 2 个输入，tie-0 相同 | 10 |
| tb_ppg_system_active_config_unpack | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS: ppg_system_active_config_unpack all checks passed` | — | 7 |
| tb_ppg_system_config_manager | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS: … MGR-01 through MGR-24 all directed checks passed` | — | 10 |
| tb_ppg_system_fault_abort_supervisor | 0/0/0 | 14 | 0 | 1 | `SUP-01 through SUP-10 PASS: 14 real comparisons` | 与 14/14 相同（09-28 SUP10A 之后） | 9 |
| ppg_system_integration/tb_ppg_scheduler_ssw_ami_integration（仅改输出路径的副本，见 §5.3） | 0/0/0 | 1558 行 | **1038 行** | 1 | 没有 `JOINT_TB_*` 横幅；`SCOREBOARD_SUMMARY pass=43 fail=19 not_closed=45` | **FAIL，见 §6.4** | 260 |

### 5.2 孤立模块（不在芯片层级内，4 份）

| TB | xvlog/xelab/xsim | PASS | FAIL | `$finish` | 自带结论横幅 | 耗时 s |
|---|---|---|---|---|---|---|
| tb_ppg_dual_precision_top | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS: ppg_dual_precision_top CDC and frame-safe timing contract verified` | 10 |
| tb_ppg_timing_sar9 | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS: ppg_timing_sar9 optical, test-MUX, and static characterization modes matched.` | 9 |
| tb_ppg_timing_sar15 | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS: ppg_timing_sar15 optical, test-MUX, and static characterization modes matched.` | 9 |
| tb_ppg_timing_3200hz | 0/0/0 | 汇总 1 行 | 0 | 1 | `PASS: 3200 Hz frame, 80 us R/IR offsets, and Q3-center alignment verified.` | 9 |

`tb_ppg_timing_3200hz` 的 2 条 xelab 警告是输出 `o_en_tia_low` 未连接，无害。

### 5.3 AMI 集成 TB 的运行方式（用户已确认）

`tb_ppg_scheduler_ssw_ami_integration.v` 在第 1713、5967、6438、6456 行写死了 `D:/PPG/verilog/jxa/ppg_system_integration/` 下的绝对路径（`tb_scenario_result.log` 以 `"w"` 模式打开，另有 `tb_ppg_event_trace.log`），原样运行会在 jxa 下新建或覆盖文件。经用户确认，在运行目录的 `patched_tb\` 中生成**只改这 4 处输出路径**的副本（diff 见 `patched_tb\ami_integration_path_redirect.diff`，逐行只有路径不同），输出落在 `ami_integration_outputs\`。运行后核对过 jxa 下没有生成这两个文件。**这个硬编码路径本身也是一个发现**（§8）。

## 6. 失败 / 未跑起来的 TB 根因（均已用诊断副本实证）

"诊断副本"都在会话临时目录中（仓库外），只做注明的最小改动，没有提交，也没有改动仓库里的 TB。

### 6.1 scheduler FSC-15 FAIL：TB 未连接 08-30 新增的 `i_owner_q3_window_closed`

- 现象：`FAIL FSC-15 cycle=5007 tick=1`。FSC-15 断言第一个宏帧后 `cnt_normal_complete == 1 && o_next_sample_index == 2`。
- 机理：scheduler 合同 V1.8（08-30，"桶1 RTL 会话"，LFA-06 修复）新增输入 `i_owner_q3_window_closed`，并接入 `flag_completion_success = … && i_owner_q3_window_closed`（RTL 第 460 行）。这份 TB 最后一次修订是 08-24（V1.5），从未连接这个端口（xelab `VRFC 10-3645`，iverilog `dangling input port 72`）。端口浮空为 Z，`flag_completion_success` 不为 1，`B_RED_DONE/B_IR_DONE` 永远不置位，`o_normal_frame_complete_event` 不会产生，`cnt_normal_complete` 保持 0。
- 实证：副本中只加 `.i_owner_q3_window_closed(1'b1)` 一行，结果 **FSC-01~59 pass=59 fail=0**，`$finish` 时刻不变（10389750 ns）。改接 0 仍然 FAIL（"Q3 永不关闭"与浮空效果相同）。
- 附带发现：FSC-34 断言 `cnt_normal_complete == 0`，在端口浮空时是**空过**（因为 NORMAL 完成永远不会发生），所以原样运行中 FSC-34 的 PASS 不能算证据；接 1 的副本里它是真实通过的。
- 结论：**TB 落后于 RTL**，不是 SID-05（09-18）带来的回归（这个端口 08-30 就已存在）。

### 6.2 idac_code_controller 33 errors：TB 未连接 08-22 新增的 `i_run_generation`

- 现象：`FAIL: ppg_idac_code_controller V2.1 regression found 33 errors`（STARTUP/PERIODIC/IDT-01~14 多处）。
- 机理：控制器 V2.2（08-22）新增 `i_run_generation`，用于 pending 候选的代际锁存与提交校验；这份 TB 最后一次修订是 08-08（V2.1），从未连接这个端口，代际比较被 X 污染。
- 实证：副本中把 3 个悬空输入都接 0，结果 **148 PASS / 0 FAIL**；**只接 `i_run_generation=0` 也是 148/0**，所以根因就是这一个端口。iverilog 跑原样 TB 同样是 67 PASS 行 / 34 FAIL 行，两个仿真器一致。
- 与历史记录一致：控制器 V2.3（08-29）的 changelog 已写明"用 iverilog 对本单元 TB 做修复前后 A/B diff，输出完全一致（含它自己既有的 33 个失败）……该单元 TB 自身早就没跟 V2.2 同步"。本次把这个已知遗留问题的根因精确到了单个端口。

### 6.3 三份 xelab 失败的 TB

| TB | xelab 错误 | 根因 | 诊断副本结果 |
|---|---|---|---|
| tb_ppg_amb_recheck_scheduler | `cannot find port 'i_adc_idle'` | RTL V1.1（08-23）把 `i_adc_idle` **纯改名**为 `i_precision_takeover_safe`（逻辑不变）；TB 最后修订为 08-11 | 只改 `.i_adc_idle(` 为 `.i_precision_takeover_safe(` 一处：**35 PASS / 0 FAIL**，横幅 `PASS: ppg_amb_recheck_scheduler completed scheduler regression` |
| tb_ppg_precision_window_integration | `cannot find port` × 3：`i_stop_ack_event`、`i_control_abort_event`、`i_adc_idle` | RTL V1.1（08-22）删除了前两个 wrapper 端口，并新增 `i_run_generation`、`i_detection_discard_*` 组、`i_sample_valid` 等；V1.3（08-23）把 `i_adc_idle` 改名。TB 只有 08-12 的 V1.0 | 删除 2 个已不存在端口的连接 + 改名，其余 19 个悬空输入接 0：5/5 FAIL（`i_sample_valid=0` 时样本不进入算法历史）；再把 `i_sample_valid` 改接 1（旧 TB 的语义是所有样本都有效）：**`ALL PWI-01 THROUGH PWI-05 PASS count=5`** |
| tb_ppg_idac_code_controller_wave | 19 个 `cannot find port`（`i_analog_ready`、`i_cfg_shadow_*`、`o_idac_code` 等），iverilog 另报 4 个参数不存在 | 这是控制器 **V1.0 时代（07-23/24）的波形演示 TB**，针对的整套 V1 接口已在 08-07 的 V2.0 重构中被整体替换。TB 带内联检查（14 处 `FAIL:`、1 处 `PASS:`），以 `$stop` 结尾停在 GUI，**没有 `$finish`** | 无法机械适配，未做副本。定性为"过时的演示 TB" |

结论：三份都是 **TB 落后于 RTL**。amb_recheck 和 PWI 的副本证明 RTL 在对应场景下行为正确。

### 6.4 AMI 集成 TB（`tb_ppg_scheduler_ssw_ami_integration.v`，V1.5 08-17）

- 原样运行（只改输出路径）：每个 run 的 `JNT_BASELINE` 都是 **31/52**（共 49 个 run，失败集中在 JNT-PHASE-ORDER/OWNER-WAIT/DONE-WAIT/03~08），合计 1558 PASS 行 / 1038 FAIL 行，结尾 `SCOREBOARD_SUMMARY pass=43 fail=19 not_closed=45`，在 2716118500 ns 结束，没有 `JOINT_TB_*` 横幅。
- 根因：iverilog 列出 14 个悬空输入，都是 08-17 之后新增的：3 个模块的 `i_run_generation`、scheduler 的 `i_owner_q3_window_closed`、AMI 的 `i_cal_owner_deadline_event`（SID-05）/`i_system_fault_discard_event`/6 个测试端口、SSW 的 `i_context_handover_stall_request`/`i_test_inject_enable`。
- 实证：副本按 `ppg_control_top.v` 的连法接线（`i_run_generation` 统一接 0；`i_owner_q3_window_closed` 接 `SSW.o_owner_q3_window_closed`；`i_cal_owner_deadline_event` 接 `scheduler.o_cal_owner_deadline_event`；其余接 0）。结果：已完成的 4 个 run 中 JNT 都是 **51/52**，共 208 PASS / 4 FAIL，**4 条全是 JNT-08**。
- 剩下的 JNT-08：这份 TB 第 6404 行断言 STOP 拦截的在途 owner `reg_last_completion_success==1`。`tb_ppg_jnt_baseline_prefix.vh` 的 changelog（第 125~132 行）早已记录这是照抄源 TB 的错误假设：合同 scheduler 第 1070 行规定 STOP 接受时已提交的 owner 必须以 `success=0` 丢弃释放。`.vh` 已改为断言 `success==0`，但这份源 TB 没有回移这个修正。
- 另一个限制：接线修正后，各场景能真正运行下去，默认的全场景模式（不带 plusarg，53 个 run，含 10 s 级长场景）在第 4 个 run 后触发了 TB 自己的 `JOINT_TB_TIMEOUT`（`C_SIM_TIMEOUT_NS` = 12 s）。原样运行之所以能在 2.7 s 结束，只是因为每个 run 都在 JNT 阶段很快失败。
- 结论：**TB 落后于 RTL**（接口 + JNT-08 旧假设），另有默认模式超出自身超时。它的职责已由 19-TB 继承（JNT 前缀就源自这份 TB）。

### 6.5 与 TB 文件头历史通过数不同的解释

| TB | 历史数 | 本次 | 解释（来自 TB 自己的 changelog） |
|---|---|---|---|
| FIR | 98 | 103 | 98 是 09-16 V2.1 适配时的数；09-17 V2.2（工作线D补 4 处测试缺口）把通过门槛提高到 103，横幅 `pass=103` 与门槛一致 |
| PVW | 46 | 54 checks | 09-17 V1.2 补 4 处缺口并新增 2 个验收 ID（横幅 `PVW-01 through PVW-48 ALL PASS: 54 checks`） |
| PWC | 40 | 48 | 09-17 V1.2 新增 PWC-41，V1.3 补 6 处缺口 |
| AMI | 48/48（09-08） | 48 | 数字不变。SID-05 改了 AMI RTL，但这份 unit TB 没有连接新端口 `i_cal_owner_deadline_event`（悬空）；tie-0 探针结果逐行相同。即 **SID-05 的新路径不在这份 unit TB 的覆盖范围内**，它的覆盖来自 09-18 SID-05 的专项验证与 19-TB |
| supervisor | 14/14 | 14 | 一致 |
| fork | 50/50 | 50 | 一致 |
| scheduler | 59/59 | 58/1 | §6.1 |

### 6.6 悬空输入普查（iverilog 12 `-Wall` 的 `dangling input port`，覆盖全部 50 份 TB）

xelab 对每个例化似乎只报第一个未连接端口（例：scheduler 副本接上 `i_owner_q3_window_closed` 后，xelab 才报出下一个 `o_cal_owner_deadline_event`），不是完整清单，所以用 iverilog 做了普查。

| TB | 悬空输入 | 对结论的影响 |
|---|---|---|
| 19-TB 中 16 份 | `ppg_control_top` 的 `i_context_handover_stall_request`、`i_test_calibration_loss_inject_valid`、`i_test_saturation_inject_valid` | 这 3 个输入在 RTL 中都与 `C_ENABLE_TEST_INJECTION != 0` 相与（SSW/FIR 直接与；IDAC 与 `o_test_saturation_inject_ready`，而后者本身又被 `flag_test_inject_effective` 门控），这 16 份都是默认参数 0，被屏蔽，无害 |
| injection / lifecycle / owner_identity / startup | 只有 `i_test_calibration_loss_inject_valid` | 这 4 份打开了 `C_ENABLE_TEST_INJECTION=1`，所以悬空的 valid 在 enable=1 时会给 FIR 注入判据带进 X，**存在潜在 X 风险**。robustness 的作者在第 175~176 行注释中明确写了"C_ENABLE_TEST_INJECTION=1时必须真实驱动0，不能悬空"，这 4 份没有照做。09-19 基线时就已存在，结论与基线逐字相同 |
| unit：dc_recovery(8)、AMI(7)、pipeline_overlap(10)、result_router(1)、fork(10)、SSW(2) | 见 §5.1 | **tie-0 探针**（全部接 0 后重跑，比较 PASS/FAIL/横幅/`$finish` 行）：6 份**全部相同**，悬空不影响结论 |
| unit：scheduler(1)、idac(3)、PWI(19+)、AMI 集成(14) | 见 §6.1~6.4 | 是失败的根因 |

## 7. `summary.tsv` 脚本 bug（本次只记录，没有修）

- 位置：`rtl/ppg_control_top/run_xsim_regression.sh` 和 `rtl/ppg_chip_digital_top/run_xsim_regression.sh` 中的 `pass_count=$(grep -c … || echo 0)` 这 3 行。
- 机理：`grep -c` 在 0 匹配时**会打印 `0` 并返回 1**，于是 `|| echo 0` 再打印一个 `0`，变量值就成了 `"0\n0"`，把 `fail_count` 列和其后的 `finished` 列拆到下一行。本次两份 summary.tsv 和驱动日志中每个 0-FAIL 的 TB 都出现 `0\n0` 拆行，与已知现象一致。
- 本报告的判定没有使用 summary.tsv，全部逐个读 `xsim.log` 得出。修复方案（例如改成 `$(grep -c … ; true)` 或 `|| true`）等用户同意后另起单独 commit。

## 8. 需要用户决定的事项

1. **summary.tsv 脚本 bug 是否修**（§7）。修复只改两个 `.sh`，不影响任何 TB 或 RTL。
2. **6 份落后于 RTL 的模块级 TB 是否适配**（§6.1~6.4）：scheduler（1 个端口）、idac_code_controller（1 个端口）、amb_recheck（1 处改名）、PWI（删 2 个端口 + 改名 + 新端口的语义选择，例如 `i_sample_valid` 接 1）、AMI 集成 TB（14 个端口 + 回移 JNT-08 修正 + 超时/运行方式）、idac_wave（过时的演示 TB，建议删除或归档，而不是适配）。改的都是 TB，不影响本基线的 RTL 结论；但适配之后这 6 份的结果会变化，需要另行建基线。
3. **测试注入输入悬空的潜在 X 风险**（§6.6）：4 份打开 `C_ENABLE_TEST_INJECTION=1` 的 19-TB 是否补驱动 `i_test_calibration_loss_inject_valid=0`。这会改 19-TB，改了之后应重跑。
4. **AMI 集成 TB 写死 jxa 绝对路径**（§5.3），打包进仓库后在其它机器上会写到不存在的目录，或者写进开发树。
5. **模块级 TB 没有统一入口**：本次用运行目录中的 `run_unit_tbs.sh` 临时驱动，是否要正式进仓库。

## 9. 产物位置（仓库外，未提交）

- 运行目录：`D:\PPG\verilog\ppg_regression_runs\e769a67_20260930\`
  - 19-TB：`rtl\ppg_control_top\xsim_regression_20260906\<tb>\{xvlog,xelab,xsim,xsim_stdout}.log` 与 `summary.tsv`（目录名中的日期是脚本写死的，不代表运行日期）；驱动日志 `ctrl19_driver.log`
  - 芯片顶层：`rtl\ppg_chip_digital_top\xsim_regression_20260930\`；`chip_driver.log`
  - 模块级：`unit\<tb>\` 与 `unit\unit_summary.tsv`；`unit_driver.log`；驱动脚本 `run_unit_tbs.sh`、清单 `unit_tb_list.txt`
  - AMI 集成 TB：路径副本 `patched_tb\` 及其 diff，输出 `ami_integration_outputs\`
- 诊断副本（scheduler 接 1、idac/PWI/amb 适配、6 份 tie-0、AMI 集成接线、ADCN 变异、iverilog 悬空普查）都在本会话的临时 scratchpad 目录中，只用于定位根因，不构成基线。
