# PPG Phase 6 — Vivado xsim 回归整合报告

生成时间：2026-09-06（对话B，独立于A1/A2轨道并行完成）
生成方式：本表由 [run_xsim_regression.sh](../ppg_control_top/run_xsim_regression.sh) 驱动 xvlog+xelab+xsim 真实跑出，非人工誊写。

## 范围声明（开工前已与用户确认）

本报告覆盖的是：`ppg_control_top/` 下 **19个各自独立的TB文件**（每个文件自己就是一个 top module），逐个通过 Vivado 2022.2 的 `xvlog` → `xelab` → `xsim` 跑一遍，再汇总成一份回归报告。

**不是**把整颗芯片摆进同一次仿真里跑的全新联合顶层TB——这项工作目前完全不存在，用户已确认不在本次任务范围内。

工具版本：`Vivado Simulator v2022.2`（`C:\Xilinx\Vivado\2022.2\bin`）。

## 与工作顺序文档"18个TB文件"的口径差异

工作顺序文档写"18个已有TB文件"，实际 `ppg_control_top/` 下用 `module tb_` 声明的顶层共 **19个**（多出的是 [tb_ppg_real_raw_generator_selfcheck.v](../ppg_control_top/tb_ppg_real_raw_generator_selfcheck.v)——它不例化任何DUT，只是Phase 3 Stage 1对RAW生成器模型本身的独立自检）。本报告按实际找到的19个跑全，不因文档口径而漏跑，差异如实记录在此，不做静默调整。

## 方法

- 13个TB此前已有历史 `xsim_*_filelist.f`（沿用不变）；本次为另外6个补建了filelist（[xsim_main_filelist.f](../ppg_control_top/xsim_main_filelist.f)、[xsim_adc_numeric_scoreboard_filelist.f](../ppg_control_top/xsim_adc_numeric_scoreboard_filelist.f)、[xsim_idac_bus_isolation_filelist.f](../ppg_control_top/xsim_idac_bus_isolation_filelist.f)、[xsim_injection_filelist.f](../ppg_control_top/xsim_injection_filelist.f)、[xsim_input_light_static_matrix_filelist.f](../ppg_control_top/xsim_input_light_static_matrix_filelist.f)、[xsim_raw_generator_selfcheck_filelist.f](../ppg_control_top/xsim_raw_generator_selfcheck_filelist.f)），沿用既有filelist的`../module/module.v`相对路径约定（cwd=`ppg_control_top/`）。
- 每个TB独立走一次 `xvlog -f <filelist> -i .` → `xelab <top> -s snap_<top> -timescale 1ns/1ps` → `xsim snap_<top> -runall -log <logdir>/xsim.log`，三个工具的返回码逐一记录。
- PASS/FAIL统计直接从各自的 `xsim.log` 原文重新提取（`grep -c -E "^PASS "` 统计PASS，`grep -c -E "^FAIL |ERROR:|FATAL_ERROR|UVM_ERROR"` 统计失败标记，`grep -c "finish called"` 确认仿真是否正常跑到`$finish`而非挂起/超时中断）。首版驱动脚本第91行的正则转义写错（`"\\$finish called"` 在bash双引号里把`$finish`当成变量展开，触发`set -u`报错），已在[run_xsim_regression.sh:91](../ppg_control_top/run_xsim_regression.sh:91)修正为纯字符串匹配；本报告的数字是修正后直接对已生成日志重新提取的，不是那次报错输出。

## 结果汇总

19/19 全部 `xvlog`/`xelab`/`xsim` 返回码为0，19/19 日志中FAIL/ERROR类关键字命中数为0，19/19 确认跑到 `$finish called`（无一挂起或被杀）。PASS断言合计 **1162条**。

| # | TB (top module) | filelist | PASS | FAIL/ERR | \$finish | 仿真墙钟耗时 | 日志路径 |
|---|---|---:|---:|---:|:---:|---:|---|
| 1 | tb_diag_algo_probe | xsim_diag_filelist.f | 5 | 0 | ✓ | 499s (8m19s) | ppg_control_top/xsim_regression_20260906/tb_diag_algo_probe/xsim.log |
| 2 | tb_ppg_real_raw_generator_selfcheck | xsim_raw_generator_selfcheck_filelist.f | 40 | 0 | ✓ | 9s | ppg_control_top/xsim_regression_20260906/tb_ppg_real_raw_generator_selfcheck/xsim.log |
| 3 | tb_ppg_control_top | xsim_main_filelist.f | 56 | 0 | ✓ | 23s | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top/xsim.log |
| 4 | tb_ppg_control_top_baseline_cross | xsim_baseline_cross_filelist.f | 68 | 0 | ✓ | 315s (5m15s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_baseline_cross/xsim.log |
| 5 | tb_ppg_control_top_fir_tail_isolation | xsim_fir_tail_isolation_filelist.f | 79 | 0 | ✓ | 401s (6m41s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_fir_tail_isolation/xsim.log |
| 6 | tb_ppg_control_top_adc_numeric_scoreboard | xsim_adc_numeric_scoreboard_filelist.f | 68 | 0 | ✓ | 16s | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_adc_numeric_scoreboard/xsim.log |
| 7 | tb_ppg_control_top_idac_bus_isolation | xsim_idac_bus_isolation_filelist.f | 66 | 0 | ✓ | 78s | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_idac_bus_isolation/xsim.log |
| 8 | tb_ppg_control_top_injection | xsim_injection_filelist.f | 14 | 0 | ✓ | 12s | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_injection/xsim.log |
| 9 | tb_ppg_control_top_lifecycle_fault_adc_anomaly | xsim_lifecycle_fault_adc_anomaly_filelist.f | 76 | 0 | ✓ | 25s | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_lifecycle_fault_adc_anomaly/xsim.log |
| 10 | tb_ppg_control_top_input_light_static_matrix | xsim_input_light_static_matrix_filelist.f | 72 | 0 | ✓ | 21s | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_input_light_static_matrix/xsim.log |
| 11 | tb_ppg_control_top_normal_slow_tracking | xsim_normal_slow_tracking_filelist.f | 71 | 0 | ✓ | 322s (5m22s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_normal_slow_tracking/xsim.log |
| 12 | tb_ppg_control_top_no_recheck_control | xsim_no_recheck_control_filelist.f | 60 | 0 | ✓ | 320s (5m20s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_no_recheck_control/xsim.log |
| 13 | tb_ppg_control_top_owner_identity_backpressure | xsim_owner_identity_backpressure_filelist.f | 66 | 0 | ✓ | 30s | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_owner_identity_backpressure/xsim.log |
| 14 | tb_ppg_control_top_peak_valley_return | xsim_peak_valley_return_filelist.f | 74 | 0 | ✓ | 276s (4m36s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_peak_valley_return/xsim.log |
| 15 | tb_ppg_control_top_periodic_recheck_recovery | xsim_periodic_recheck_recovery_filelist.f | 69 | 0 | ✓ | 549s (9m9s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_periodic_recheck_recovery/xsim.log |
| 16 | tb_ppg_control_top_robustness_corner_waveforms | xsim_robustness_corner_waveforms_filelist.f | 65 | 0 | ✓ | 1949s (32m29s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_robustness_corner_waveforms/xsim.log |
| 17 | tb_ppg_control_top_startup_idac_calibration | xsim_startup_idac_calibration_filelist.f | 80 | 0 | ✓ | 14s | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_startup_idac_calibration/xsim.log |
| 18 | tb_ppg_control_top_long_10_cycles | xsim_long_10_cycles_filelist.f | 128 | 0 | ✓ | 1548s (25m48s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_long_10_cycles/xsim.log |
| 19 | tb_ppg_control_top_longrun | xsim_longrun_filelist.f | 5 | 0 | ✓ | 1497s (24m57s) | ppg_control_top/xsim_regression_20260906/tb_ppg_control_top_longrun/xsim.log |

合计仿真墙钟耗时约7404秒（约2小时3分）。

## 人工抽查确认（不止信关键字计数）

`grep`对"mismatch/miscompare/timeout"类关键字的命中，逐条人工核对后确认全部是TB**有意构造的场景**且被正确处理，不是真实失败，例如：

- `tb_ppg_control_top_owner_identity_backpressure/xsim.log:82`：`PASS OIB-01 RED waveform-context handover missed while held ... only the Scheduler's non-blocking launch-timeout diagnostic`——故意制造超时场景，核对的是"只触发非阻塞诊断、不触发阻塞态"。
- `tb_ppg_control_top_normal_slow_tracking/xsim.log:83`：`PASS TRK-09b forced code-snapshot mismatch consumed without altering tracking evidence`——故意注入mismatch，核对的是被正确吸收而不污染追踪证据。
- `tb_ppg_control_top_periodic_recheck_recovery/xsim.log:83`：`PASS RRC-11 a real one-directional DC_R excursion drove the search to genuine exhaustion, asserting failed/fault`——故意制造搜索耗尽场景，核对的是正确置位fault并阻塞NORMAL。

三个含"HISTORICAL_DIAG ... asserted during the run (non-blocking per contract)"的`INFO`行（baseline_cross/fir_tail_isolation/peak_valley_return各一条）同理：契约本就允许该诊断位在特定场景下置位，非阻塞、非失败。

## 诚实边界

- 本回归证明的是"这19个已有TB各自在Vivado xsim下仍能编译、例化、无挂起地跑完并保持原有PASS结论"——是**回归确认**，不是新增验证覆盖，也不是流片正确性本身的担保。
- 未做：覆盖率采集（按工作顺序文档，等AMI/Top端口新增工作落地后再做）、`report_cdc`/综合（已排后，见 [project-ppg-report-cdc-verification-pending-20260905](../../../../.claude/projects/D--PPG-verilog-jxa/memory/project-ppg-report-cdc-verification-pending-20260905.md) 同等结论）。
- 本次为5个TB+1个自检TB新建的filelist（共6个）此前不存在对应的xsim filelist；用的是历史13个filelist完全一致的`../module/module.v`模式，未改动任何RTL或已有TB文件本身。
- `PPG_CONTRACT_CLOSURE_MATRIX.md`当前有其他并行对话在改，本报告刻意存成独立文件、未触碰该矩阵，避免写坏风险；矩阵整合留给对话C（Phase 7）汇总时处理。
