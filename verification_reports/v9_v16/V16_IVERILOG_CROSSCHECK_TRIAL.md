# V16：Icarus交叉检查试跑记录

2026-10-10。**状态：按任务书可选条款跳过实际编译/仿真。49个TB均未跑，0个PASS比较完成，0个结束时间比较完成；RTL竞争是否存在未验证。**

## 环境与基线

- Windows、PowerShell；Git `2.54.0.windows.1`；本次脚本运行用Python `3.12.14`。
- `Get-Command iverilog,vvp`没有结果；`shutil.which`对 `iverilog/vvp/iverilog-vpi`全部返回null。另查常见安装路径及 `D:/DevSoftwares`，未找到可执行文件。
- `winget`命令别名存在，但实际 `winget search --name 'Icarus Verilog' --source winget --disable-interactivity`启动失败，系统报告“系统无法访问此文件”。未安装软件、未调用Vivado/远端验证。这里的跳过是本次已配置环境的限制，不声称用户机器永久无法安装Icarus。
- V9/V16工作分支从main `bb3c1ab`创建；**V16源码和参考严格使用** `66bebdfabe9e1cb173c34a0ce44e48ba4230398d`，即任务书指定B分支提交。参考目录为 `verification_reports/b_merge_batch_evidence/final_5d8ceba/`，xsim参考版本Vivado 2022.2。
- 已运行 `git archive`并在内存读取该提交的RTL、回归表、filelist与49套参考PASS/finish资料；依赖路径及每份参考PASS行数均核对，不拿main源码冒充B基线，不修改既有文件。

## 本次做过的检查与没有做过的检查

已做：脚本语法/命令行验证、49唯一TB映射、参考文件完整性、PASS清单长度与index一致、finish的fs/ps/ns/us单位精确换算、源文件依赖存在性。V16脚本以默认计划模式运行完成；加 `--execute`后因无Icarus/vvp而全体标未跑并返回1，未把工具缺失算通过。

尚未做：任何Icarus编译、VPI本地编译、vvp运行、xsim/iverilog实际PASS或finish对比、RTL/TB竞争最小复现。语言标准**未选定**，工具版本**不可用**；表中的参考PASS数/结束时刻只来自既有xsim证据。

Windows长路径限制：初版落盘完整证据目录时遇到tarfile严格目录句柄权限错误，显式校验的普通文件导出又遇到WinError 206。最终缺工具/计划模式在内存核对 `git archive`，不需要落盘源码。脚本实际执行分支及VPI编译分支因工具缺失未验证；后续在Windows进行真实运行应使用较短的仓库检出路径及新的 `--run-name`，不复用没有完整revision标记的部分导出。

## 重跑脚本与命令

脚本：`scripts/v16_crosscheck.py`。结束时间观察器：`scripts/v16_finish_probe.c`。VPI只注册仿真结束回调、读取全局仿真时间及precision，不驱动任何RTL/TB信号；不用修改导出的TB来插入display。缺少 `iverilog-vpi`或VPI编译失败时，finish标UNAVAILABLE，不能判两工具一致。

Icarus准备好后的命令（从仓库根运行）：

```powershell
# 指定基线的计划/依赖核对，不运行仿真
python -B verification_reports/v9_v16/scripts/v16_crosscheck.py --revision 66bebdf --run-name plan_66bebdf

# 关键子集试跑；未选TB仍列出，整体未完整跑完时返回1
python -B verification_reports/v9_v16/scripts/v16_crosscheck.py --revision 66bebdf --run-name first_trial --execute --tb tb_ppg_adc_dc_recovery --tb tb_ppg_adc_programmable_reconstructor --tb tb_ppg_adc_measurement_idac_integration --tb tb_ppg_400hz_frame_calibration_scheduler

# 完整短跑；两份10秒TB默认标“未跑：长跑默认跳过”
python -B verification_reports/v9_v16/scripts/v16_crosscheck.py --revision 66bebdf --run-name short_suite --execute --timeout-seconds 1800

# 有时间预算时才加入长跑，可提高宿主超时；不得缩小刺激后冒充同基线对比
python -B verification_reports/v9_v16/scripts/v16_crosscheck.py --revision 66bebdf --run-name full_suite --execute --include-long --timeout-seconds 14400
```

每TB实际编译命令记录到results.json，模板为：

```text
iverilog -o <case>/sim.vvp -g2001 -s <TB> -I <实际源码目录> ... <原filelist中的全部源文件>
```

`-o`始终紧跟可执行文件，避免任务书记录的Git Bash参数问题。依次尝试2001、2005、2005-sv、2012，记录最低可成功标准和各次完整日志；若最终需要SV标准，应记编译兼容差异，不能声称只用Verilog-2001已过。

```text
iverilog-vpi <scripts>/v16_finish_probe.c
vvp -M <vpi模块目录> -m v16_finish_probe <case>/sim.vvp
```

PASS采用独立 `PASS`单词文本口径（包含 `PASS:`、`[PASS]`及 `ALL ... PASS`，不混入 `_TB_PASS`、`PASSED`），已核对49套参考都符合此口径；排序后保留重复行，逐行严格比较。**不删除时间、计数或身份字段来制造一致**。VPI报告ticks及十进制precision指数，使用Decimal统一转成fs与xsim带单位时刻精确比较。宿主超时单独记录，不能当正常finish。

脚本只自动标“观测一致”或“差异待人工分类”，不自动把差异定性为RTL错误。分类需读完整日志及代码：编译不兼容、TB竞争、RTL竞争、仿真器语义差异。RTL竞争必须给符号、逐拍因果与最小复现。即使全部观测一致，也不能证明全设计没有竞争。

输出在本目录被忽略的 `runs/<run-name>/`，包括归档源码副本、revision标记、编译/运行日志、PASS差异与results.json。执行前再次核对导出文件SHA256，拒绝混基线/修改过的快照；本次入库的紧凑环境及依赖清单为 `V16_TRIAL_RESULTS.json`。

RC1后：`--revision <RC1提交>`必须配 `--reference-dir <同一提交所含的对应xsim参考目录>`，不能沿用5d8ceba参考声称RC1一致。当前清单预期49个唯一TB；RC1若改变数量/回归表或引入filelist选项，脚本会明确拒绝，应先更新预期与对应参考。

## 逐TB结果

每行的“未跑/未比较”是实际本次状态，不是模拟执行结果。

| 层级 | TB | 编译 | 运行 | PASS比较 | finish比较 | xsim参考PASS行 | xsim参考finish | 差异归类 |
| --- | --- | --- | --- | --- | --- | ---: | --- | --- |
| system | `tb_ppg_control_top_longrun` | 未跑 | 未跑 | 未比较 | 未比较 | 5 | 10000007251 ns | 未跑：环境无工具 |
| system | `tb_diag_algo_probe` | 未跑 | 未跑 | 未比较 | 未比较 | 5 | 2997746251 ns | 未跑：环境无工具 |
| system | `tb_ppg_real_raw_generator_selfcheck` | 未跑 | 未跑 | 未比较 | 未比较 | 40 | 0 fs | 未跑：环境无工具 |
| system | `tb_ppg_control_top` | 未跑 | 未跑 | 未比较 | 未比较 | 73 | 1655648500 ps | 未跑：环境无工具 |
| system | `tb_ppg_control_top_baseline_cross` | 未跑 | 未跑 | 未比较 | 未比较 | 75 | 2754606751 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_long_10_cycles` | 未跑 | 未跑 | 未比较 | 未比较 | 129 | 10001375751 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_fir_tail_isolation` | 未跑 | 未跑 | 未比较 | 未比较 | 80 | 2246370751 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_adc_numeric_scoreboard` | 未跑 | 未跑 | 未比较 | 未比较 | 69 | 24450751 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_idac_bus_isolation` | 未跑 | 未跑 | 未比较 | 未比较 | 70 | 395559251 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_injection` | 未跑 | 未跑 | 未比较 | 未比较 | 15 | 223203500 ps | 未跑：环境无工具 |
| system | `tb_ppg_control_top_lifecycle_fault_adc_anomaly` | 未跑 | 未跑 | 未比较 | 未比较 | 80 | 87842251 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_input_light_static_matrix` | 未跑 | 未跑 | 未比较 | 未比较 | 73 | 54319751 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_normal_slow_tracking` | 未跑 | 未跑 | 未比较 | 未比较 | 72 | 1785249500 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_no_recheck_control` | 未跑 | 未跑 | 未比较 | 未比较 | 61 | 2038876751 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_owner_identity_backpressure` | 未跑 | 未跑 | 未比较 | 未比较 | 68 | 105193250 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_peak_valley_return` | 未跑 | 未跑 | 未比较 | 未比较 | 75 | 1746375751 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_periodic_recheck_recovery` | 未跑 | 未跑 | 未比较 | 未比较 | 70 | 3567743251 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_robustness_corner_waveforms` | 未跑 | 未跑 | 未比较 | 未比较 | 67 | 17403562751 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_startup_idac_calibration` | 未跑 | 未跑 | 未比较 | 未比较 | 83 | 12728250 ns | 未跑：环境无工具 |
| system | `tb_ppg_control_top_adc_anomaly` | 未跑 | 未跑 | 未比较 | 未比较 | 40 | 1714036750 ns | 未跑：环境无工具 |
| chip | `tb_ppg_chip_digital_top` | 未跑 | 未跑 | 未比较 | 未比较 | 20 | 11362750 ns | 未跑：环境无工具 |
| unit | `tb_ppg_400hz_frame_calibration_scheduler` | 未跑 | 未跑 | 未比较 | 未比较 | 77 | 86763 us | 未跑：环境无工具 |
| unit | `tb_ppg_active_v4_control_plane_integration` | 未跑 | 未跑 | 未比较 | 未比较 | 22 | 1034500 ps | 未跑：环境无工具 |
| unit | `tb_ppg_adc_async_stage_capture` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 36288 ns | 未跑：环境无工具 |
| unit | `tb_ppg_adc_dc_recovery` | 未跑 | 未跑 | 未比较 | 未比较 | 2 | 571 ns | 未跑：环境无工具 |
| unit | `tb_ppg_adc_measurement_idac_integration` | 未跑 | 未跑 | 未比较 | 未比较 | 79 | 806750 ns | 未跑：环境无工具 |
| unit | `tb_ppg_adc_pipeline_overlap_corrector` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 537 us | 未跑：环境无工具 |
| unit | `tb_ppg_adc_programmable_reconstructor` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 10593 ns | 未跑：环境无工具 |
| unit | `tb_ppg_adc_result_router` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 8253 ns | 未跑：环境无工具 |
| unit | `tb_ppg_adc_s1_programmable_calibrator` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 10706 ns | 未跑：环境无工具 |
| unit | `tb_ppg_adc_s1_redundancy_corrector` | 未跑 | 未跑 | 未比较 | 未比较 | 2 | 3140288 ns | 未跑：环境无工具 |
| unit | `tb_ppg_amb_recheck_scheduler` | 未跑 | 未跑 | 未比较 | 未比较 | 37 | 1312040 ns | 未跑：环境无工具 |
| unit | `tb_ppg_characterization_control_cdc` | 未跑 | 未跑 | 未比较 | 未比较 | 27 | 1776 ns | 未跑：环境无工具 |
| unit | `tb_ppg_coarse_detection_fir` | 未跑 | 未跑 | 未比较 | 未比较 | 103 | 1887 us | 未跑：环境无工具 |
| unit | `tb_ppg_dynamic_baseline_cross_detector` | 未跑 | 未跑 | 未比较 | 未比较 | 66 | 58720 ns | 未跑：环境无工具 |
| unit | `tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 0 fs | 未跑：环境无工具 |
| unit | `tb_ppg_idac_code_controller` | 未跑 | 未跑 | 未比较 | 未比较 | 150 | 4090 ns | 未跑：环境无工具 |
| unit | `tb_ppg_normal_transaction_fork` | 未跑 | 未跑 | 未比较 | 未比较 | 52 | 38 us | 未跑：环境无工具 |
| unit | `tb_ppg_peak_valley_window_detector` | 未跑 | 未跑 | 未比较 | 未比较 | 56 | 33389500 ns | 未跑：环境无工具 |
| unit | `tb_ppg_precision_window_controller` | 未跑 | 未跑 | 未比较 | 未比较 | 50 | 2636 ns | 未跑：环境无工具 |
| unit | `tb_ppg_precision_window_integration` | 未跑 | 未跑 | 未比较 | 未比较 | 6 | 59970 ns | 未跑：环境无工具 |
| unit | `tb_ppg_sar9_sar15_safe_selection_wrapper` | 未跑 | 未跑 | 未比较 | 未比较 | 60 | 2295751 ns | 未跑：环境无工具 |
| unit | `tb_ppg_system_active_config_unpack` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 1027 ns | 未跑：环境无工具 |
| unit | `tb_ppg_system_config_manager` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 1016 ns | 未跑：环境无工具 |
| unit | `tb_ppg_system_fault_abort_supervisor` | 未跑 | 未跑 | 未比较 | 未比较 | 19 | 690 ns | 未跑：环境无工具 |
| unit | `tb_ppg_dual_precision_top` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 32503500 ns | 未跑：环境无工具 |
| unit | `tb_ppg_timing_sar9` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 20001751 ns | 未跑：环境无工具 |
| unit | `tb_ppg_timing_sar15` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 20001751 ns | 未跑：环境无工具 |
| unit | `tb_ppg_timing_3200hz` | 未跑 | 未跑 | 未比较 | 未比较 | 1 | 435250 ns | 未跑：环境无工具 |

## RTL竞争项

**未验证，无可报告的动态RTL竞争发现或最小复现。** V9中的容差/空真/超时证据风险不能自动升级为V16的RTL竞争结论。建议正式试跑先覆盖FSC、AMI、PWI、PWC、SSW及芯片SPI/P2S，再做系统大规模生理波形和长跑；任何不一致必须保留日志，定位后再决定归类。
