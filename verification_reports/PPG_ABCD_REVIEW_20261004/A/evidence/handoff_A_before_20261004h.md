被审提交：`d18c6954621e53e5a6505dd3a6c688c266d23839`
# A组交接（2026-10-03T00:48:59+08:00）

四组共同约定/主责清单已读，原始任务已知事项沿用。A唯一总报告为本目录PPG_FULL_REVIEW_20261002.md；PPG_FULL_REVIEW_20261003.md是上轮同内容阶段副本，不作为新四组汇总的第二作者。共享snapshot/zlcx只读，其他组不得修改原报告/证据。
输出根：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit`
handoff固定路径：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\handoff_A.md`
逐检查项覆盖：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\coverage_A.csv`
跨组待办：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\cross_group_todo.csv`

## 固定资源与工具

快照：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\snapshot`；克隆：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\zlcx`；origin/main仍固定、工作树为空、119范围文件SHA256与初始台账一致。没有fetch/pull/切分支/提交/推送。
Git D:/Git/cmd/git.exe 2.54.0.windows.1；bundled Python C:/Users/DAWN/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe 3.12.14；系统Python 3.8.5。WSL Debian 11.6。
Icarus11.0 stable只读工具包：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\toolchain\icarus11\usr\bin\iverilog`、`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\toolchain\icarus11\usr\bin\vvp`；lib：`C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\toolchain\icarus11\usr\lib\x86_64-linux-gnu\ivl`。Windows不能直接执行Linux ELF，使用wsl.exe -d Debian -- <Linux绝对路径>；Linux路径为/mnt/c/Users/DAWN/...。iverilog必须-B上述lib；vvp用-M上述lib。
Vivado/xsim和Verilator未找到；已运行本仓库erie-verilog-generator analyze/validate的formatter-AST、strict gate、verilog_lint external=none；无verify/repair或formatter写源码。Python使用-B/PYTHONDONTWRITEBYTECODE=1和UTF-8。旧restricted shell曾setup refresh失败；PowerShell只读命令需现有工具的require_escalated auto-review，不能改写其他组目录。

## 检查点与尚未完成

37 RTL按-g2005 -Wall逐模块编译，48活动TB按-g2012 -Wall及精确依赖全部编译；19系统filelist+1芯片filelist+28单位TB_TABLE覆盖全部活动TB，2份legacy排除。37 gate/lint已有同提交证据，勿重复风格门禁。负对照编译3种错误均被检出。
上轮②-B完成：ADC数值叶子主要代码/部分CDC/SPI全文及少量合同，6项模块RTL变异均触发真实FAIL；并未把整份文件语义标完成。阶段报告与evidence/ledger.json有每文件实际范围；交给B/C/D不等于该文件完成。
锚点7403出现位置含重复；177明确文本不匹配（165Top声明+12K出处），14越界，6缺文件待裁定。忽略删除线旧引、区分Cxx:3/小数节号；尚未覆盖全部省略文件名:NNN与所有in-bounds语义。ID表828是候选（含模块/历史/范围），不得当真实系统ID计数或直接缺闭环报告。
A现接管22个唯一主责文件+全局119汇总/ID/端口/锚点/契约冲突。七孤立RTL全部归A，保留原任务。B/C/D的专项证据需要A读取源码、合同、原始日志后复核去重。

## 既有发现：实际为七条

共同约定/协调消息写F-001～F-006比最新报告早；F-007已在协调消息前核实并写入两份阶段报告，必须保留。此处是索引，详细原文/行号/反驳在总报告；各组应读原始证据再作独立裁定。

| 编号 | 严重度 | 主责复核 | 内容与原始证据 |
|---|---|---|---|
| F-001 | S2 TB | B/C | 4注入TBcal-loss valid悬空，21合格点leaf正式资格X；evidence/fir_floating_ab/；disabled/tie0对照资格1，负期望fatal |
| F-002 | S3 合同 | C/B | C13 complete TXN_ID discard比overlap实际小组多5epoch；evidence/c13_port_evidence.json；清除只看generation，未升级S1 |
| F-003 | S3 台账 | A/各组 | 165Top声明引用错误+12K出处指向CDC+14越界；evidence/anchor_failures.csv与带负对照anchor_scan.json |
| F-004 | S3 合同 | C/B | C13 Router registered local-empty不存在且与C12纯组合条款冲突；全Router/AMI实例/AST已查 |
| F-005 | S1 RTL | D/A | SPI真实Mode0读流提前1bit；evidence/spi_map_probe/ physical FAIL0x0100 got1c expected0e；legacy/hypothesis通过38+128字节；仅外部假设副本，无修复入库 |
| F-006 | S2 TB | D/A | 原chip TB在negedge NBA前采旧SDO掩盖F005；evidence/chip_spi_ab/run.log仅采样移到posedge+1ns出现3FAIL，原TB6PASS |
| F-007 | S3 合同 | D/A | 芯片正文53/65/80/82/101仍两路reset_sync，与本合同25勘误及Top284/373单路实际架构冲突；本合同明文许可现有机制，未报S1 |

六项变异：evidence/mutations/及mutation_results.json，S1冗余符号1031FAIL/校准offset1036/重构中心1042/PWC START清sticky4/Router复位2/FSC身份1；进程rc0仍有FAIL，必须看文本判据。SPI假设/采样变异副本只作A/B反驳；绝不把它们的通过当成入库RTL通过。

## 原有全局回归（保留，不重启）

统一exec session=22875；run_all.sh分4并行批次，额外fast session=96661已结束。每TB目录evidence/compile/<name>包含compile.log/compile.rc/sim.vvp/run.sh/run.log/run.rc/run.start/run.end。只有run.rc存在才结束；日志可能C stdio缓冲，不能据空文件判断time0死锁。原脚本每份外部wall-clock timeout3600；rc124必须归外部截断。

上轮baseline_cross 5秒诊断副本推进到1768101500ps并通过JNT54，因此不是time0 delta循环；这尚不能排除之后的delta停滞，继续诊断时不得停止原进程。保存于evidence/compile/tb_ppg_control_top_baseline_cross/progress_probe.log。

| TB | 状态 | rc | PASS行（按实际样式） | 日志 |
|---|---|---:|---:|---|
| tb_diag_algo_probe | 外部3600秒截断，未完成 | 124 | 2 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_diag_algo_probe\run.log |
| tb_ppg_400hz_frame_calibration_scheduler | 原TB结束；不推定语义覆盖完成 | 0 | 59 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_400hz_frame_calibration_scheduler\run.log |
| tb_ppg_active_v4_control_plane_integration | 原TB结束；不推定语义覆盖完成 | 0 | 22 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_active_v4_control_plane_integration\run.log |
| tb_ppg_adc_async_stage_capture | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_adc_async_stage_capture\run.log |
| tb_ppg_adc_dc_recovery | 原TB结束；不推定语义覆盖完成 | 0 | 2 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_adc_dc_recovery\run.log |
| tb_ppg_adc_measurement_idac_integration | 原TB结束；不推定语义覆盖完成 | 0 | 48 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_adc_measurement_idac_integration\run.log |
| tb_ppg_adc_pipeline_overlap_corrector | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_adc_pipeline_overlap_corrector\run.log |
| tb_ppg_adc_programmable_reconstructor | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_adc_programmable_reconstructor\run.log |
| tb_ppg_adc_result_router | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_adc_result_router\run.log |
| tb_ppg_adc_s1_programmable_calibrator | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_adc_s1_programmable_calibrator\run.log |
| tb_ppg_adc_s1_redundancy_corrector | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_adc_s1_redundancy_corrector\run.log |
| tb_ppg_amb_recheck_scheduler | 原TB结束；不推定语义覆盖完成 | 0 | 35 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_amb_recheck_scheduler\run.log |
| tb_ppg_characterization_control_cdc | 原TB结束；不推定语义覆盖完成 | 0 | 26 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_characterization_control_cdc\run.log |
| tb_ppg_chip_digital_top | 原TB结束；不推定语义覆盖完成 | 0 | 6 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_chip_digital_top\run.log |
| tb_ppg_coarse_detection_fir | 原TB结束；不推定语义覆盖完成 | 0 | 103 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_coarse_detection_fir\run.log |
| tb_ppg_control_top | 原TB结束；不推定语义覆盖完成 | 0 | 71 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top\run.log |
| tb_ppg_control_top_adc_numeric_scoreboard | 原TB结束；不推定语义覆盖完成 | 0 | 69 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_adc_numeric_scoreboard\run.log |
| tb_ppg_control_top_baseline_cross | 外部3600秒截断，未完成 | 124 | 0 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_baseline_cross\run.log |
| tb_ppg_control_top_fir_tail_isolation | 外部3600秒截断，未完成 | 124 | 0 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_fir_tail_isolation\run.log |
| tb_ppg_control_top_idac_bus_isolation | 原TB结束；不推定语义覆盖完成 | 0 | 70 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_idac_bus_isolation\run.log |
| tb_ppg_control_top_injection | 原TB结束；不推定语义覆盖完成 | 0 | 15 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_injection\run.log |
| tb_ppg_control_top_input_light_static_matrix | 原TB结束；不推定语义覆盖完成 | 0 | 73 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_input_light_static_matrix\run.log |
| tb_ppg_control_top_lifecycle_fault_adc_anomaly | 原TB结束；不推定语义覆盖完成 | 0 | 80 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_lifecycle_fault_adc_anomaly\run.log |
| tb_ppg_control_top_long_10_cycles | running | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_long_10_cycles\run.log |
| tb_ppg_control_top_longrun | running | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_longrun\run.log |
| tb_ppg_control_top_no_recheck_control | running | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_no_recheck_control\run.log |
| tb_ppg_control_top_normal_slow_tracking | pending | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_normal_slow_tracking\run.log |
| tb_ppg_control_top_owner_identity_backpressure | pending | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_owner_identity_backpressure\run.log |
| tb_ppg_control_top_peak_valley_return | pending | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_peak_valley_return\run.log |
| tb_ppg_control_top_periodic_recheck_recovery | pending | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_periodic_recheck_recovery\run.log |
| tb_ppg_control_top_robustness_corner_waveforms | pending | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_robustness_corner_waveforms\run.log |
| tb_ppg_control_top_startup_idac_calibration | pending | — | — | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_control_top_startup_idac_calibration\run.log |
| tb_ppg_dual_precision_top | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_dual_precision_top\run.log |
| tb_ppg_dynamic_baseline_cross_detector | 原TB结束；不推定语义覆盖完成 | 0 | 65 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_dynamic_baseline_cross_detector\run.log |
| tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence\run.log |
| tb_ppg_idac_code_controller | 原TB结束；不推定语义覆盖完成 | 0 | 148 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_idac_code_controller\run.log |
| tb_ppg_normal_transaction_fork | 原TB结束；不推定语义覆盖完成 | 0 | 50 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_normal_transaction_fork\run.log |
| tb_ppg_peak_valley_window_detector | 原TB结束；不推定语义覆盖完成 | 0 | 54 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_peak_valley_window_detector\run.log |
| tb_ppg_precision_window_controller | 原TB结束；不推定语义覆盖完成 | 0 | 48 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_precision_window_controller\run.log |
| tb_ppg_precision_window_integration | 原TB结束；不推定语义覆盖完成 | 0 | 5 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_precision_window_integration\run.log |
| tb_ppg_real_raw_generator_selfcheck | 原TB结束；不推定语义覆盖完成 | 0 | 40 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_real_raw_generator_selfcheck\run.log |
| tb_ppg_sar9_sar15_safe_selection_wrapper | 原TB结束；不推定语义覆盖完成 | 0 | 52 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_sar9_sar15_safe_selection_wrapper\run.log |
| tb_ppg_system_active_config_unpack | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_system_active_config_unpack\run.log |
| tb_ppg_system_config_manager | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_system_config_manager\run.log |
| tb_ppg_system_fault_abort_supervisor | 原TB结束；不推定语义覆盖完成 | 0 | 14 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_system_fault_abort_supervisor\run.log |
| tb_ppg_timing_3200hz | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_timing_3200hz\run.log |
| tb_ppg_timing_sar15 | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_timing_sar15\run.log |
| tb_ppg_timing_sar9 | 原TB结束；不推定语义覆盖完成 | 0 | 1 | C:\Users\DAWN\.codex\visualizations\2026\10\02\01a0fd16-9489-7e50-a7b6-a1178fd92bf1\ppg_audit\evidence\compile\tb_ppg_timing_sar9\run.log |

## 已知事项与后续入口

scheduler V1.8/AMI V1.15，不包含任务C V1.9；tick248已知，不重复新报。P2S反压前提文档/TB改动不在基准，按进行中，不写已落实。PRC04、N08/N04/P10、TRK01、C11/C14/C15条件豁免、D03冻结、5悬空输出、GFP未复核、旧CDC/锁存/X态审计、SPI仅3诊断读字节、芯片层无ID、7孤立、遗留_tmp filelist按原任务处理，须核实前提。
新范围为RTL功能签核准备；PVT、综合网表、电气延迟、Virtuoso后续，不以它们缺失暂停可做只读功能审阅。没有主责文件全文完成之前不能宣布全量功能正确。
本次先继续现有回归最终判据/工具差异诊断，再审A七孤立RTL+对应TB、Top全端口/参数/逻辑、5全局TB真实覆盖及5合同全文，完成全锚点/ID/台账语义。优先消化B/C/D每批已完成原始证据，避免等全部结束才汇总。
其他组不发消息；通过registry真实ID读取进度。A不能修改协调登记表。主责输出与handoff路径发布后读取并在cross_group_todo.csv登记，不要求用户传文件。

## 2026-10-04更新

总报告实际8条，新增F-008公开measurement-discard宏缺五epoch。七孤立RTL+四TB完成内部审阅，4定向变异触发真实错误；8 RTL skill analyze成功。Top全部有效代码/C01全文实读，但语义闭环、参数拒绝、全局追溯未完。原后台已随环境中断，旧日志已保留；12未完成用例续跑session79583。请以coverage_A.csv/ledger.json及新attempt日志为准，不据旧状态称仍在运行。B/C/D目录已定位，正在独立复核其专项证据。

2026-10-04 增量：F-009..F-015独立复核合并；累计15条，S1=3/S2=5/S3=7。diag probe全文有效代码完成；尚待其回归终态。Q3分工不作为全局缺口。

F-016/017 PRC09空闲周期误归因、PRC10只查相邻重复已保存；累计17条(3/7/7)。longrun/long10/robustness有效代码完成，smoke全3194待读。WSL /mnt/c新访问EIO，用仓库外native_probe.py stdin tar+--exec，原四个长回归仍运行勿杀。
