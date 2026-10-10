# V16：Icarus交叉检查试跑记录（WSL实跑更正）

2026-10-10。**当前平台可以运行Icarus。49个TB全部以 `-g2001` 编译成功；36个正常结束，当前没有宿主限时中断项，13个只编译未运行。原3项90秒中断已按用户要求改为每项4小时预算并完整重跑。**

与已提交参考清单严格比较：29个TB的排序PASS及结束时刻完全一致；5个存在参考提取口径差异，已核对原始xsim日志同口径结果完全一致；1个芯片TB的PASS一致但结束时刻不同；1个control_top TB的累计结果计数字段不同。后两项已在仓库外用Icarus 11 / XSIM 2019.2完成定因，统筹认可为TB同沿竞争，**不是RTL竞争**；原始DIFF保留，实验补丁未应用到仓库TB。**不声称49个TB全部通过，本次结论不外推为整个RTL无缺陷。**

## 环境调查更正

前一版报告基于默认沙箱中 `iverilog/vvp` 不存在、winget启动失败而跳过。用户追问后，提升权限的只读检查发现winget可用、本机有Debian WSL；前次环境调查不充分，现以本次真实运行更正。

实际环境为Windows宿主、WSL2 Debian GNU/Linux 11、Icarus Verilog **11.0 stable**、vvp **11.0**。Windows Python **3.12.14**编排直接WSL argv调用，不要求发行版安装Python。Icarus Debian包 `iverilog_11.0-1_amd64.deb` 的SHA256已核对：

```text
337d0f723aba0f56651b47ae0e240077f076b3128bc7be0237f84a1aafc2ccf8
```

Icarus、TCC和libc6-dev头文件仅下载并解包到任务目录下被忽略的 `runs/icarus11/`，未安装系统包、未修改系统PATH。只读VPI观察器已实际编译并加载，读取仿真结束时间，不驱动任何信号。

**源码和参考严格使用** `66bebdfabe9e1cb173c34a0ce44e48ba4230398d`。通过 `git archive`导出RTL、原回归表/filelist及对应 `verification_reports/b_merge_batch_evidence/final_5d8ceba/`，不拿main或其他分支源码混跑。源码导出与归档内容逐文件SHA256核对；既有RTL、TB、合同、回归入口均未改。

## 汇总

| 项目 | 数量 | 含义 |
| --- | ---: | --- |
| 编译成功 | 49 | 最低尝试标准2001即成功，无SV回退 |
| 正常运行结束 | 36 | 模块28、芯片1、系统7；全部tool run rc=0且未检出FAIL |
| 严格参考清单和finish均MATCH | 29 | 保留完整文字、时间、计数和身份字段，排序后逐行比较 |
| 参考提取口径差异 | 5 | ADC数值scoreboard、启动IDAC校准、输入矩阵、owner反压、PWC；与原始xsim日志按相同口径逐行MATCH |
| 正常结束时刻差异 | 1 | 原始芯片TB早1000ns（两个500ns周期）；D04已确认TB竞争 |
| 累计结果计数差异 | 1 | 原始control_top计数字段偏移1，finish一致；D06已确认TB竞争 |
| 当前宿主限时中断 | 0 | 原3项在每项14400秒预算下已正常完成，不放宽判据 |
| 只编译未运行 | 13 | 其余系统级及两份10秒长跑，时间预算子集，不是工具不可用 |

原“49个TB未跑”的快照已被本文件及 `V16_TRIAL_RESULTS.json` 的真实结果替换。计数按最终各TB结果统计，不重复累计重跑。

## 命令与可复用脚本

脚本：`scripts/v16_crosscheck.py`；结束时间观察器：`scripts/v16_finish_probe.c`。完整逐TB编译/运行argv见JSON，私有绝对路径用 `${REPO}`替代；源码依赖来自指定提交的原filelist/回归表。Icarus `-o`紧跟可执行文件，语言标准依次尝试2001、2005、2005-sv、2012；本次49份均止于2001。

```text
iverilog -o <case>/sim.vvp -B <runtime>/usr/lib/x86_64-linux-gnu/ivl -g2001 -s <TB> -I <源码目录> ... <原filelist全部源文件>
vvp -M <观察器目录> -m v16_finish_probe <case>/sim.vvp
```

`run_command`直接构造 `wsl.exe -d Debian --cd <目录> -- <程序及参数>`，避免PowerShell和Linux shell之间的变量展开。WSL宿主stderr为UTF-16、Linux stdout为UTF-8，因此分别采集；初次混流造成首条PASS前出现NUL，是采集问题，修正后3个冒烟TB已经真实重跑并严格MATCH，未对DUT输出删改字段。

在Debian中隔离准备工具（可采用已有安装的gcc/iverilog-vpi替代TCC；没有必要重新安装系统包）：

```sh
apt-get download iverilog tcc libc6-dev
dpkg-deb --extract <iverilog包> runtime
dpkg-deb --extract <tcc包> runtime
dpkg-deb --extract <libc6-dev包> runtime
runtime/usr/bin/tcc -B runtime/usr/lib/x86_64-linux-gnu/tcc \
  -I runtime/usr/include -I runtime/usr/include/x86_64-linux-gnu \
  -I runtime/usr/include/iverilog -nostdlib -shared \
  <脚本目录>/v16_finish_probe.c -o v16_finish_probe.vpi
```

本次实际编排命令（仓库根，Windows Python）：

```powershell
python -B verification_reports/v9_v16/scripts/v16_crosscheck.py --revision 66bebdf --run-name wsl_trial --wsl-distribution Debian --tool-root verification_reports/v9_v16/runs/icarus11/runtime --vpi-module verification_reports/v9_v16/runs/icarus11/v16_finish_probe.vpi --execute --run-group unit --run-group chip --timeout-seconds 90 --reuse-results
```

另以 `--tb`重复选取RAW自检、control_top、数值scoreboard、injection、输入矩阵、owner反压、启动IDAC等短系统候选，最终结果见下表。`--reuse-results`仅复用同一源码基线且核对导出哈希，避免把已验证TB重复计数。宿主限时在Linux侧使用 `timeout --kill-after=5s`，防止只杀wsl启动器而留下vvp进程。

所有输出在被忽略的 `runs/<run-name>/`，包含源码快照、编译/运行stdout及stderr、VPI二进制和完整差异。**不入库大体积日志/波形/产物**；入库仅摘要、必要摘录、命令与JSON表。后续要完整跑系统和长跑，增加 `--timeout-seconds`；两份10秒TB需 `--include-long`。不能缩小刺激后冒充同基线对比。

RC1后必须同时改变 `--revision <RC1提交>`和 `--reference-dir <该提交包含的对应xsim证据目录>`。不能用5d8ceba参考关闭RC1；若TB数/回归表变动，先更新49-TB预期和对应证据。

## 比较方法与差异分类

### D01：参考提取口径（5份TB已解释，无RTL差异）

实际运行按独立PASS单词收集文字，保留重复行；以已提交 `*.pass_sorted.txt` 为正式严格参考，发现额外总结行后，另外读取同提交原始xsim日志，使用完全相同提取口径比较。**正式DIFF仍保留在表中，不静默忽略新增行来制造MATCH。**

| TB | 提交清单行数 | Icarus/原始xsim同口径行数 | 唯一额外行 |
| --- | ---: | ---: | --- |
| tb_ppg_precision_window_controller | 50 | 51 | `PWC-01 through PWC-41 ALL PASS pass=50 fail=0` |
| tb_ppg_control_top_adc_numeric_scoreboard | 69 | 70 | `JNT_BASELINE checked=54 pass=54 required=54 status=PASS` |
| tb_ppg_control_top_startup_idac_calibration | 83 | 84 | 同一JNT总结行 |
| tb_ppg_control_top_input_light_static_matrix | 73 | 74 | 同一JNT总结行 |
| tb_ppg_control_top_owner_identity_backpressure | 68 | 69 | 同一JNT总结行 |

原始xsim路径分别为 `raw/unit/tb_ppg_precision_window_controller/xsim.log`、`raw/sys_g2/tb_ppg_control_top_adc_numeric_scoreboard/xsim.log`、`raw/sys_g4/tb_ppg_control_top_startup_idac_calibration/xsim.log`，均相对同一final_5d8ceba目录。输入矩阵原始日志在 `raw/sys_g3/tb_ppg_control_top_input_light_static_matrix/xsim.log`，owner反压在 `raw/sys_g3/tb_ppg_control_top_owner_identity_backpressure/xsim.log`。统一提取后51/70/84/74/69行分别逐行一致，finish亦一致，属于参考清单提取口径，不是仿真器算术或RTL竞争。

### D04：芯片TB结束时间差异（已闭合：TB同沿竞争）

原始 `tb_ppg_chip_digital_top` 的20条PASS一致、0 FAIL，但XSIM结束于11,362,750 ns、Icarus结束于11,361,750 ns，相差1000 ns。原始finish DIFF保留，不放宽时间判据。

`cnt_chip_lost`在 `always @(posedge CLK_2M_PAD)` 内以阻塞赋值递增，`wait_chip_lost`在同一Active时间区读该计数，进程先后改变后续SPI/STOP排期。仓库外最小实验只在wait_chip_lost的posedge后加 `#1`，保留原等待计数增量和超时上限；Icarus 11及XSIM 2019.2均20 PASS、0 FAIL、正常结束于 **11,361,750 ns**。扩展实验将相关复位释放/计数更新错开，并改为下降沿读取，结果亦一致。

原始两边真实输出的五笔结果，其身份、时间与拍号完全相同；三笔completion-lost身份相同，第三笔时刻随TB排期移动。最小实验后lost、START/STOP和结果序列及拍号一致。因此D04归入V9 **Q02：TB计数更新/读取竞争**，不是RTL竞争；没有修改仓库TB或RTL。

实验源码固定为 `66bebdfabe9e1cb173c34a0ce44e48ba4230398d`。本次XSIM 2019.2复现原XSIM 2022.2参考差异；未在本机运行2022.2或Icarus 12。完整diff、TXN和运行汇总见 [定因报告](D04_D06_CAUSE_REPORT.md)、[TXN摘录](TXN_EVIDENCE.tsv)、[运行汇总](RUN_RESULTS.json)。

### D05：原宿主限时中断已完成补跑

此前90秒预算中断的三个TB，按用户要求使用 **每项14400秒（4小时）** 的宿主预算完整重跑。`--reuse-results`只保留其他TB的既有证据，不恢复vvp运行状态；这三个TB从原始reset/初始激励重新运行，没有缩小样本或修改源码。三者均正常结束、tool rc=0、无FAIL，finish均与xsim一致。

| TB | Icarus及xsim结束时间 | PASS文字比较 |
| --- | --- | --- |
| tb_ppg_control_top | 1,655,648.5 ns | 73/73行；TOP-01两条累计计数字段不同，见D06 |
| tb_ppg_control_top_input_light_static_matrix | 54,319,751 ns | 清单73行、实跑74行；原始xsim同口径74行一致 |
| tb_ppg_control_top_owner_identity_backpressure | 105,193,250 ns | 清单68行、实跑69行；原始xsim同口径69行一致 |

重跑命令在上一段WSL命令基础上改为：

```powershell
python -B verification_reports/v9_v16/scripts/v16_crosscheck.py --revision 66bebdf --run-name wsl_trial --wsl-distribution Debian --tool-root verification_reports/v9_v16/runs/icarus11/runtime --vpi-module verification_reports/v9_v16/runs/icarus11/v16_finish_probe.vpi --execute --tb tb_ppg_control_top --tb tb_ppg_control_top_input_light_static_matrix --tb tb_ppg_control_top_owner_identity_backpressure --timeout-seconds 14400 --reuse-results
```

`cbEndOfSimulation`在SIGTERM时也可能执行，原90秒中断时打印的时间不能冒充TB正常finish。本次未发生宿主中断，不再把历史中断列入当前结果。

### D06：control_top累计结果计数差异（已闭合：TB同沿竞争）

原始两边均73条PASS、49笔ADC响应、0 FAIL，finish同为1,655,648.5 ns，但XSIM最终33笔正式结果、Icarus为34；TOP-01旧事务检查分别打印32/33，新结果检查打印32→33/33→34。原始排序DIFF保留，不允许计数差1、不删除字段。

逐拍TXN证实差异发生在 **SMOKE-23**：复位epoch0、RUN15、frame_id=1/sample_index=2的RED NORMAL SAR9结果，在第126039拍（1,638,500.5 ns）由Icarus真实输出，XSIM则产生STOP discard（reason=0）。XSIM的STOP_ACK在126037拍，Icarus在126038拍；后续复位在1,642,875 ns，因此这笔差异不是重复计数或被复位清掉。

根因是SMOKE-23主刺激在posedge读取由另一个posedge进程阻塞更新的owner计数/身份快照，导致退出等待并驱动下一次STOP早晚相差一拍。最小实验仅在两个读取点加 `#1`，两边都恢复为 **73 PASS、49 ADC/33 results、finish=1,655,648.5 ns、0 FAIL**，差异TXN在两边同拍STOP丢弃，完整输出/正式丢弃身份序列一致。

单独调整SMOKE-17 ready下降沿驱动及结果计数#1更新未消除D06，不能将本次差异归因SMOKE-17。最小SMOKE-23补丁也未处理其他同沿等待点，RUN11前两笔输出仍有13 ns偏移，另有四个STOP_ACK相差13或26 ns。扩展实验将owner计数/身份更新延后#1、相关读取/ready驱动改到下降沿，两边均49 ADC/34 results，完整事务去向及运行期观测拍号全部一致；33/34来自两种明确的STOP排期，不是放宽结果接受标准。

统筹认可D06为 **V9 Q01：TB同沿计数更新/读取竞争，不是RTL竞争**。原公开discard_generation在差异笔实测为0，证据原样保留；RUN15由当前RUN和接受owner身份关联，本轮未评价该字段的独立合同一致性。实验版本为Icarus 11 / XSIM 2019.2，未修改仓库TB/RTL；详见 [定因报告](D04_D06_CAUSE_REPORT.md)。

## 逐TB结果

“清单MATCH/DIFF”使用已提交排序清单；参考口径差异另有原始日志MATCH证据。未完整运行的项不作通过判定。

| 层级 | TB | 编译/标准 | 运行 | Icarus/清单PASS数 | 清单比较 | finish比较 | 裁定 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| system | `tb_ppg_control_top_longrun` | 成功/2001 | 未跑 | —/5 | 未比较 | 未比较 | 只编译 |
| system | `tb_diag_algo_probe` | 成功/2001 | 未跑 | —/5 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_real_raw_generator_selfcheck` | 成功/2001 | 正常结束 | 40/40 | MATCH | MATCH | 观测一致 |
| system | `tb_ppg_control_top` | 成功/2001 | 正常结束 | 73/73 | DIFF | MATCH | TB竞争已确认（Q01）；原DIFF保留 |
| system | `tb_ppg_control_top_baseline_cross` | 成功/2001 | 未跑 | —/75 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_long_10_cycles` | 成功/2001 | 未跑 | —/129 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_fir_tail_isolation` | 成功/2001 | 未跑 | —/80 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_adc_numeric_scoreboard` | 成功/2001 | 正常结束 | 70/69 | DIFF | MATCH | 参考口径：原始日志MATCH |
| system | `tb_ppg_control_top_idac_bus_isolation` | 成功/2001 | 未跑 | —/70 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_injection` | 成功/2001 | 正常结束 | 15/15 | MATCH | MATCH | 观测一致 |
| system | `tb_ppg_control_top_lifecycle_fault_adc_anomaly` | 成功/2001 | 未跑 | —/80 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_input_light_static_matrix` | 成功/2001 | 正常结束 | 74/73 | DIFF | MATCH | 参考口径：原始日志MATCH |
| system | `tb_ppg_control_top_normal_slow_tracking` | 成功/2001 | 未跑 | —/72 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_no_recheck_control` | 成功/2001 | 未跑 | —/61 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_owner_identity_backpressure` | 成功/2001 | 正常结束 | 69/68 | DIFF | MATCH | 参考口径：原始日志MATCH |
| system | `tb_ppg_control_top_peak_valley_return` | 成功/2001 | 未跑 | —/75 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_periodic_recheck_recovery` | 成功/2001 | 未跑 | —/70 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_robustness_corner_waveforms` | 成功/2001 | 未跑 | —/67 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_startup_idac_calibration` | 成功/2001 | 正常结束 | 84/83 | DIFF | MATCH | 参考口径：原始日志MATCH |
| system | `tb_ppg_control_top_adc_anomaly` | 成功/2001 | 未跑 | —/40 | 未比较 | 未比较 | 只编译 |
| chip | `tb_ppg_chip_digital_top` | 成功/2001 | 正常结束 | 20/20 | MATCH | DIFF | TB竞争已确认（Q02）；原DIFF保留 |
| unit | `tb_ppg_400hz_frame_calibration_scheduler` | 成功/2001 | 正常结束 | 77/77 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_active_v4_control_plane_integration` | 成功/2001 | 正常结束 | 22/22 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_adc_async_stage_capture` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_adc_dc_recovery` | 成功/2001 | 正常结束 | 2/2 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_adc_measurement_idac_integration` | 成功/2001 | 正常结束 | 79/79 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_adc_pipeline_overlap_corrector` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_adc_programmable_reconstructor` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_adc_result_router` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_adc_s1_programmable_calibrator` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_adc_s1_redundancy_corrector` | 成功/2001 | 正常结束 | 2/2 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_amb_recheck_scheduler` | 成功/2001 | 正常结束 | 37/37 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_characterization_control_cdc` | 成功/2001 | 正常结束 | 27/27 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_coarse_detection_fir` | 成功/2001 | 正常结束 | 103/103 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_dynamic_baseline_cross_detector` | 成功/2001 | 正常结束 | 66/66 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_idac_code_controller` | 成功/2001 | 正常结束 | 150/150 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_normal_transaction_fork` | 成功/2001 | 正常结束 | 52/52 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_peak_valley_window_detector` | 成功/2001 | 正常结束 | 56/56 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_precision_window_controller` | 成功/2001 | 正常结束 | 51/50 | DIFF | MATCH | 参考口径：原始日志MATCH |
| unit | `tb_ppg_precision_window_integration` | 成功/2001 | 正常结束 | 6/6 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_sar9_sar15_safe_selection_wrapper` | 成功/2001 | 正常结束 | 60/60 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_system_active_config_unpack` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_system_config_manager` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_system_fault_abort_supervisor` | 成功/2001 | 正常结束 | 19/19 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_dual_precision_top` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_timing_sar9` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_timing_sar15` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |
| unit | `tb_ppg_timing_3200hz` | 成功/2001 | 正常结束 | 1/1 | MATCH | MATCH | 观测一致 |

## 结论及待办

Icarus平台可用，原3项限时中断已全部正常完成。D04/D06定因完成，统筹认可两项为TB同沿竞争，不是RTL竞争；证据已归档，实际TB/RTL未改，本阶段结束。剩余13项系统级TB维持只编译状态，RC1后由统筹在本机用Icarus 12和既有脚本补跑，并使用RC1对应的XSIM参考及统一提取口径。本试跑不是最终签核，不把未跑项或仅有PASS文本当作通过。原始运行JSON和DIFF作为历史观测保留，定因实验另见 `RUN_RESULTS.json`。
