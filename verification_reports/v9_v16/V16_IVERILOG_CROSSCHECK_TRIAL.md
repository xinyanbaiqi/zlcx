# V16：Icarus交叉检查试跑记录（WSL实跑更正）

2026-10-10。**当前平台可以运行Icarus。49个TB全部以 `-g2001` 编译成功；33个正常结束，3个在90秒宿主预算下中断，13个只编译未运行。**

与已提交参考清单严格比较：29个TB的排序PASS及结束时刻完全一致；3个存在参考提取口径差异，已核对原始xsim日志同口径结果完全一致；1个芯片TB的PASS一致但结束时刻不同，原因未闭合。**不声称49个TB全部通过，也不声称不存在RTL竞争。**

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
| 正常运行结束 | 33 | 模块28、芯片1、系统4；全部tool run rc=0且未检出FAIL |
| 严格参考清单和finish均MATCH | 29 | 保留完整文字、时间、计数和身份字段，排序后逐行比较 |
| 参考提取口径差异 | 3 | ADC数值scoreboard、启动IDAC校准、PWC；与原始xsim日志按相同口径逐行MATCH |
| 正常结束时刻差异 | 1 | 芯片TB早1000ns（两个500ns主时钟周期），待定位 |
| 宿主限时中断 | 3 | control_top、input_light_static_matrix、owner_identity_backpressure；不能作为RTL/TB错误或正常finish |
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

### D01–D03：参考提取口径（已解释，无RTL差异）

实际运行按独立PASS单词收集文字，保留重复行；以已提交 `*.pass_sorted.txt` 为正式严格参考，发现额外总结行后，另外读取同提交原始xsim日志，使用完全相同提取口径比较。**正式DIFF仍保留在表中，不静默忽略新增行来制造MATCH。**

| TB | 提交清单行数 | Icarus/原始xsim同口径行数 | 唯一额外行 |
| --- | ---: | ---: | --- |
| tb_ppg_precision_window_controller | 50 | 51 | `PWC-01 through PWC-41 ALL PASS pass=50 fail=0` |
| tb_ppg_control_top_adc_numeric_scoreboard | 69 | 70 | `JNT_BASELINE checked=54 pass=54 required=54 status=PASS` |
| tb_ppg_control_top_startup_idac_calibration | 83 | 84 | 同一JNT总结行 |

原始xsim路径分别为 `raw/unit/tb_ppg_precision_window_controller/xsim.log`、`raw/sys_g2/tb_ppg_control_top_adc_numeric_scoreboard/xsim.log`、`raw/sys_g4/tb_ppg_control_top_startup_idac_calibration/xsim.log`，均相对同一final_5d8ceba目录。统一提取后51/70/84行逐行一致，finish亦一致，属于参考清单提取口径，不是仿真器算术或RTL竞争。

### D04：芯片TB结束时间差异（未闭合）

`tb_ppg_chip_digital_top`的20条正式参考PASS完全一致，均无FAIL、tool rc=0，最终成功横幅也出现；但xsim在 **11,362,750ns**结束，Icarus在 **11,361,750ns**结束，差 **-1000ns**。VPI全局ticks/precision转成fs后精确比较，其他TB正常结束时刻一致，不能把这一差异抹平为时间格式。

已定位的TB竞争候选：同文件的 `cnt_chip_lost`由 `always @(posedge CLK_2M_PAD)`以阻塞赋值更新，`wait_chip_lost`也在同一posedge时间槽读取它；`wait_chip_stopped`也在posedge后立即读生命周期。读/写先后可影响等待器提前或晚一拍返回。符号锚点：owner生命周期监视块、`wait_chip_lost`、`wait_chip_stopped`；本基线约779/785/797行。

```verilog
// 源码摘录，未修改；以下两进程共享posedge时间槽
cnt_chip_lost = cnt_chip_lost + 1;
while((cnt_chip_lost < target) && (cnt_wd < 30000))begin
    @(posedge CLK_2M_PAD); cnt_wd = cnt_wd + 1;
end
```

这证明存在需要审阅的TB同沿计数结构，**尚未证明它就是本次1000ns差异的全部原因，也尚未排除其他RTL/TB时序原因**。需下一轮将SPI步骤、lost监视/等待返回和STOP排空时刻对应起来，再裁定。只记录、不改原TB或RTL；本次没有确认RTL竞争，故没有伪造“RTL最小复现”。

### D05：宿主限时（不当作逻辑差异）

control_top、输入矩阵、owner反压在90秒宿主预算下尚未到正常TB结束。`cbEndOfSimulation`在SIGTERM时也可能执行并打印时间；运行rc为HOST_TIMEOUT时这些时间只记 `interrupted_time_fs`，**不叫实际finish，也不与xsim正常finish比较**。已完成前缀的PASS不能代替后续未覆盖场景。三者需要更大的真实时间预算继续，不属于“不能运行Icarus”。

## 逐TB结果

“清单MATCH/DIFF”使用已提交排序清单；参考口径差异另有原始日志MATCH证据。未完整运行的项不作通过判定。

| 层级 | TB | 编译/标准 | 运行 | Icarus/清单PASS数 | 清单比较 | finish比较 | 裁定 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| system | `tb_ppg_control_top_longrun` | 成功/2001 | 未跑 | —/5 | 未比较 | 未比较 | 只编译 |
| system | `tb_diag_algo_probe` | 成功/2001 | 未跑 | —/5 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_real_raw_generator_selfcheck` | 成功/2001 | 正常结束 | 40/40 | MATCH | MATCH | 观测一致 |
| system | `tb_ppg_control_top` | 成功/2001 | 宿主90s中断 | 44/73 | 未比较：宿主限时中断 | 未比较：非正常finish | 未完成 |
| system | `tb_ppg_control_top_baseline_cross` | 成功/2001 | 未跑 | —/75 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_long_10_cycles` | 成功/2001 | 未跑 | —/129 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_fir_tail_isolation` | 成功/2001 | 未跑 | —/80 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_adc_numeric_scoreboard` | 成功/2001 | 正常结束 | 70/69 | DIFF | MATCH | 参考口径：原始日志MATCH |
| system | `tb_ppg_control_top_idac_bus_isolation` | 成功/2001 | 未跑 | —/70 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_injection` | 成功/2001 | 正常结束 | 15/15 | MATCH | MATCH | 观测一致 |
| system | `tb_ppg_control_top_lifecycle_fault_adc_anomaly` | 成功/2001 | 未跑 | —/80 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_input_light_static_matrix` | 成功/2001 | 宿主90s中断 | 70/73 | 未比较：宿主限时中断 | 未比较：非正常finish | 未完成 |
| system | `tb_ppg_control_top_normal_slow_tracking` | 成功/2001 | 未跑 | —/72 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_no_recheck_control` | 成功/2001 | 未跑 | —/61 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_owner_identity_backpressure` | 成功/2001 | 宿主90s中断 | 58/68 | 未比较：宿主限时中断 | 未比较：非正常finish | 未完成 |
| system | `tb_ppg_control_top_peak_valley_return` | 成功/2001 | 未跑 | —/75 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_periodic_recheck_recovery` | 成功/2001 | 未跑 | —/70 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_robustness_corner_waveforms` | 成功/2001 | 未跑 | —/67 | 未比较 | 未比较 | 只编译 |
| system | `tb_ppg_control_top_startup_idac_calibration` | 成功/2001 | 正常结束 | 84/83 | DIFF | MATCH | 参考口径：原始日志MATCH |
| system | `tb_ppg_control_top_adc_anomaly` | 成功/2001 | 未跑 | —/40 | 未比较 | 未比较 | 只编译 |
| chip | `tb_ppg_chip_digital_top` | 成功/2001 | 正常结束 | 20/20 | MATCH | DIFF | 时间差待定位 |
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

Icarus平台可用，初版跳过结论已更正。V16试跑已取得真实模块级及部分系统/芯片级证据；尚需：D04芯片结束时间差异定因、3项限时中断及13项未运行系统TB补跑、RC1对应参考提取口径统一。本试跑不是最终签核，不把未跑项、宿主中断或仅有PASS文本当作闭合。
