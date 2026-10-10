# V10（Python部分）：静态扫描重跑

- 分支：`p0-closure`（已合并 origin/main `bb3c1ab`）。扫描对象为当前RTL/合同，RTL/TB与main `c56296d`/`7a8eabf`相同。
- 环境：云端会话，Python 3，无仿真器。
- 上次报告：仓库`tools/cross_reference_tools/`下已提交的`*_report.json/md`（CDC为2026-09-15，lint、文字滞后为09-13；快照提交时间09-28）。
- 本次原始输出：`V10_raw/`（各脚本的JSON；deliverable gate逐文件汇总`deliverable_gate_summary.txt`）。

## 0. 结论摘要

| 项 | 上次 | 本次 | 新增项判断 |
|---|---|---|---|
| CDC Phase1 可达性/域标注 | 452个寄存器标注，30个可达模块类型 | 466个，30个 | 新增14个寄存器全部属于CLK_2M域，来自owner生命周期轮（AMI、校正器、SSW）。没有域变化，没有新的异步信号。**误报风险：无；属于正常新增** |
| CDC Phase2 跨域读候选 | 主候选0，门控候选1 | 主候选0，门控候选1（同一项） | 无新增 |
| CDC Phase3 手写同步分类 | — | 全部字段逐项相同 | 无新增 |
| CDC Phase4 多跳assign边界 | 漏检0，深链寄存器181 | 漏检0，深链寄存器189 | 新增8个、消失1个，全部为CLK_2M同域链。**无跨域问题** |
| 语义类静态lint | 0 | 0 | 无新增 |
| 文字滞后扫描 | 33条命中 | 25条命中 | 新增1条，为删除线文字，**误报**；另有1条是旧行移动。消失的9条来自本环境中不存在的方案文件 |
| skill deliverable gate（芯片层级30个文件） | 仅10个文件有可比的上次结果 | 见§3 | 10个可比文件的问题数与OLR §6.1逐项相同，无新增；其余文件以本次为新基线，非零项都是风格或注释类 |

**没有发现需要立即处理的CDC或语义问题。** 一处任务书口径需要订正：任务书说芯片顶层"1个VG031"是已接受的豁免，但本次gate显示**芯片顶层只有46个VG010；那个VG031在`ppg_control_top.v`**，与OLR §6.1"control_top错误1"一致。

---

## 1. 运行方式与改动

### 1.1 为什么不能原地运行
仓库内脚本是在原开发工作树的布局下写的，有三处路径依赖：
1. `PATH_PROJECT_ROOT = Path(__file__).resolve().parents[2]`，并按`ppg_*`顶层目录收集RTL（`static_lint_semantic_sweep.collect_real_source_files`）。本仓库的RTL在`rtl/ppg_*`下，脚本在`tools/cross_reference_tools/`下，原地运行会扫不到任何RTL。
2. `reconcile_acceptance_ids.py`的`INTEGRATION_DIR = REPO_ROOT/"ppg_system_integration"`，以及`CONTRACT_GLOBS = ["ppg_system_integration/*CONTRACT*.md", "*/*_semantic_contract.md"]`。本仓库的合同都在`contracts/`下。
3. `PATH_SKILL_ROOT = Path(r"C:\Users\d\.claude\skills\erie-verilog-generator")`；`prose_staleness_scanner.PATH_PLAN_FILE = C:\Users\d\.claude\plans\sprightly-wobbling-wadler.md`。

### 1.2 做法（仓库内文件一律未改）
- 在会话scratchpad中建一个只读镜像，复现原工作树布局：
  - `mirror/ppg_<模块>/*.v`：从`rtl/ppg_<模块>/`复制直接子目录下的`.v`，共86个文件；
  - `mirror/ppg_system_integration/*.md`：复制`contracts/`下除`*_semantic_contract.md`以外的全部合同；
  - `mirror/ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md`和`mirror/ppg_system_active_config_unpack/ppg_system_active_config_unpack_semantic_contract.md`按矩阵C02、C05的原路径放置；
  - 把`tools/cross_reference_tools/*.py`复制到`mirror/ppg_system_integration/cross_reference_tools/`，这样`parents[2]`正好指向镜像根，报告中的相对路径与上次报告完全同形，可以逐项比较。
- 对复制件只改一处：五个脚本中的`PATH_SKILL_ROOT`改为本仓库的`.claude/skills/erie-verilog-generator`（sed逐字替换该常量），没有改任何逻辑。
- `PATH_PLAN_FILE`在本环境中不存在，脚本自带`exists()`判断会跳过它，所以没有修改。
- 命令（在镜像的`cross_reference_tools/`下执行）：
  ```
  python3 static_lint_semantic_sweep.py --json lint.json
  python3 cdc_domain_reachability_tagger.py --json p1.json
  python3 cdc_cross_domain_read_candidate_detector.py --json p2.json --markdown p2.md
  python3 cdc_handrolled_class_classifier.py --json p3.json --markdown p3.md
  python3 cdc_phase4_multihop_assign_boundary_check.py --json p4.json --markdown p4.md
  python3 prose_staleness_scanner.py --json prose.json
  ```
  全部返回0；各脚本内置的自检和合成负例全部PASS（日志中FAIL计数为0）。
- `regression_freshness_watchdog.py`依赖统筹机器上的回归目录，按任务书跳过。
- 合同版本：主扫描用main当前的`contracts/`。文字滞后扫描另外用`origin/b-merge-batch`的合同跑了一遍对照（见§2.6）。

### 1.3 扫描范围与上次的差别
上次的候选文件为93个（lint为109个，含TB），本次为86个。少掉的都是本仓库快照中不存在的历史文件：
- `ppg_timing_sar9/ppg_timing_sar9_new.v`；
- `ppg_timing_sar15/ppg_timing_sar15_{new,v1,6667hz_v1}.v`；
- `ppg_idac_code_controller/tb_ppg_idac_code_controller_wave.v`；
- `ppg_system_integration/tb_ppg_scheduler_ssw_ami_integration.v`；
- `*_3200hz_new`两个模块。

它们都不在芯片层级内，因此不影响可达集合：可达模块类型和实例节点都是30/37，与上次相同。

---

## 2. 与上次结果的差异

### 2.1 `cdc_domain_reachability_tagger.py`（Phase 1）
- 顶层仍为`ppg_chip_digital_top`，可达模块类型30个、实例节点37个，`ambiguous`/`noncanonical`/`instance_issues`/`reachable_but_unparseable_files`均为空，与上次相同。
- 不可达模块：上次12个，本次10个。少掉的`ppg_timing_sar9_3200hz_new`、`ppg_timing_sar15_3200hz_new`已不在快照中。其余为：
  - 孤立RTL：`ppg_digital_esd_shell`、`ppg_digital_shell`、`ppg_dual_precision_top`、`ppg_timing_sar9_3200hz`、`ppg_timing_sar15_3200hz`；
  - 5个TB顶层。
- 解析失败：上次51个，本次46个，全部属于"已确认不被引用"的文件（`parse_failed_files_possibly_needed_but_unparseable`为空）。
  - 新增1个：`ppg_control_top/tb_ppg_control_top_adc_anomaly.v`（`control parser strict failure`）。这是TB，不在芯片层级内，对CDC结论没有影响，判为**误报（工具对TB语法的限制）**。
  - 非TB解析失败只有`ppg_timing_sar9.v`、`ppg_timing_sar15.v`，属于孤立模块，上次同样如此。
- 寄存器标注：上次452个，本次466个。**新增14个，消失0个，域变化0个**：
  - AMI：`adc_transaction_lost_event_o`、`cnt_lost_red/ir/cal`、`cnt_owner_age`、`flag_adc_busy_fault_hold`、`flag_owner_lost_fault_hold`、`flag_ami_fault_pending_06/07`、`owner_lost_sticky_o`、`flag_run_context_ended`、`flag_detection_branch_sample_valid`；
  - 冗余校正器：`flag_capture_drop_armed`；
  - SSW：`reg_owner_cal_subframe`。

  全部被标为CLK_2M（域计数CLK_2M从401变为415，其余三类不变）。判断：都是owner生命周期轮、F-009轮、ABCD轮新增的同域寄存器，**不是CDC问题**。
- 异步信号标注：7个，与上次逐项相同（两路DONE、两路DOUT、`w_idle_mux_async`等）。已知信号交叉检查4项全部PASS。

### 2.2 `cdc_cross_domain_read_candidate_detector.py`（Phase 2）
扫描24个模块，跳过3个白名单IP（`ppg_config_cdc_bridge`等）。主候选0个；门控候选1个，为`ppg_spi_register_file.reg_diag_snapshot`被`reg_diag_snapshot_gated`门控读取，与上次相同。合成负例与真实V1.3用例均PASS。**无差异。**

### 2.3 `cdc_handrolled_class_classifier.py`（Phase 3）
JSON七个顶层字段（白名单自洽、class1外部异步审计、class2标准复位同步、class2借用复位、分类候选、phase2汇总、自检）**与上次逐字节相同**。

### 2.4 `cdc_phase4_multihop_assign_boundary_check.py`（Phase 4）
- 漏检的多跳跨域候选：上次0，本次0。扫描模块数和含深链的模块数不变。
- 深链（≥2跳）寄存器：181个变为189个，全部为CLK_2M写域：
  - AMI：新增`cnt_owner_age`、`flag_adc_busy_fault_hold`、`flag_ami_fault_pending_06/07`、`flag_detection_branch_sample_valid`、`flag_owner_lost_fault_hold`；消失`result_sample_valid_o`（该寄存器的读链不再达到2跳）。另外`reg_adc_inflight_frame_type`的最大跳数从2变为3，`flag_measurement_pending`从3变为4。
  - 冗余校正器：新增`flag_capture_drop_armed`。
  - SSW：新增`reg_owner_cal_subframe`、`reg_owner_frame_id`。
  - SPI：`state_current`第1跳frontier少了`dec_read_load_addr`（SPI_SCLK同域）。
- 判断：都是同域组合链的增长，Phase 4的唯一结论项"漏检跨域候选"仍为0，**无问题**。

### 2.5 `static_lint_semantic_sweep.py`
语义类规则（ALWAYS_STAR、MIXED_ASSIGN、COMB_NONBLOCKING_ASSIGN、SEQ_BLOCKING_ASSIGN、IF_ELSE_LATCH）命中：上次0，本次0。**无差异。**

### 2.6 `prose_staleness_scanner.py`
- 扫描文件：上次28个（含方案文件），本次27个（方案文件不存在）。命中：上次33条，本次25条。
- 消失10条：
  - 9条来自方案文件`sprightly-wobbling-wadler.md`。本环境中没有这个文件，所以不是"已修正"，而是"未扫描"。
  - 1条为矩阵旧第3085行，同一句话现在在第3271行（引用锚点从`C01:22-30, C08:1240`改为`C01:28-36, C08:1253`）。这是移动，不是新问题。
- 新增：
  - 矩阵第1314行`EN_pending_phrase`，命中文字为`~~whether to rebuild the C01 rows is pending user decision.~~`。这句已被删除线划掉，扫描器的删除线识别没有覆盖这种长行中的情况。**误报。**
  - 矩阵第3271行即上面的移动项。内容为"retained only as historical evidence; current status is fail-closed and evidence is pending"，是矩阵对旧PASS措辞的定性说明，属于既有项，**误报（既有）**。
- 用`origin/b-merge-batch`的合同重跑：同样是27个文件、25条命中，唯一差别是第3271行在b-merge-batch中移到第3289行，锚点改成了"C01 文件头, C08 §20"。B批次没有引入新的文字滞后命中。
- 其余23条命中与上次相同（例如FIR §686、PWI §690的2026-09-13勘误行，原文已带勘误说明），上次已人工核实过，本次不重复判断。

---

## 3. skill deliverable gate

### 3.1 运行方式
在`.claude/skills/erie-verilog-generator/`下逐文件运行：
```
python3 -m scripts.python.validation.verilog_generated_deliverable_gate <rtl/ppg_x/ppg_x.v> --json <out>.json --markdown <out>.md
```
对象为芯片层级内的30个模块（取自Phase 1可达集合，每个模块一个文件`rtl/<m>/<m>.v`），以及单列的esd_shell和6个孤立模块。

### 3.2 芯片层级内30个文件

| 文件 | delivery_ready | 错误 | strict告警 | 规则 | 上次（OLR §6.1，0ffb439后） | 判断 |
|---|---|---|---|---|---|---|
| `ppg_chip_digital_top` | 否 | 46 | 0 | VG010×46 | VG010×46 | 相同；已接受的封装引脚命名豁免 |
| `ppg_control_top` | 否 | 1 | 0 | VG031×1（缺固定区块banner） | 错误1 | 相同；即任务书中的"1个VG031"，实际属于control_top |
| `ppg_adc_measurement_idac_integration`（AMI） | 否 | 2 | 1 | VG061、VG066、VG014（`o_test_calibration_loss_inject_ready`/`idac_test_saturation_inject_ready_o`的区块归属、注释复用） | 错误2、strict 1 | 相同 |
| `ppg_sar9_sar15_safe_selection_wrapper`（SSW） | 否 | 10 | 0 | VG060×3（注释列）、VG061×1、VG066×6（RED/IR/CAL三个同构信号的注释近似重复） | 错误10 | 相同 |
| `ppg_precision_window_integration`（PWI） | 否 | 0 | 1 | VG014（`o_test_calibration_loss_inject_ready`无assign桥） | strict 1 | 相同 |
| 调度器、冗余校正器、重检调度器、SPI、supervisor | 是 | 0 | 0 | — | 0/0 | 相同 |
| `ppg_coarse_detection_fir` | 否 | 3 | 0 | VG052、VG061（`o_test_calibration_loss_inject_ready`位于"其他信号连线"区）、VG061（一个always块位于"输出信号处理区域"） | 无可比结果 | **新基线**；风格/区块归属，非功能 |
| `ppg_idac_code_controller` | 否 | 3 | 0 | VG052、VG061（`o_test_saturation_inject_ready`区块归属）、VG066（注释复用） | 无可比结果 | **新基线**；风格，非功能 |
| `ppg_reset_sync` | 否 | 10 | 0 | VG060×10（行内注释列应为44，实际为52~56） | 无可比结果 | **新基线**；纯注释排版 |
| 其余17个文件 | 是 | 0 | 0 | — | 无可比结果 | 新基线，干净 |

"其余17个文件"为：`ppg_active_v4_control_plane_integration`、`ppg_adc_async_stage_capture`、`ppg_adc_dc_recovery`、`ppg_adc_pipeline_overlap_corrector`、`ppg_adc_programmable_reconstructor`、`ppg_adc_result_router`、`ppg_adc_s1_programmable_calibrator`、`ppg_characterization_control_cdc`、`ppg_config_cdc_bridge`、`ppg_dynamic_baseline_cross_detector`、`ppg_normal_transaction_fork`、`ppg_p2s_packer`、`ppg_peak_valley_window_detector`、`ppg_precision_window_controller`、`ppg_pulse_cdc_sync`、`ppg_system_active_config_unpack`、`ppg_system_config_manager`。

- 可比的10个文件（OLR §6.1列出的RTL）问题数全部与上次相同，**无新增**。本次没有做去行号的逐条比对，因为OLR的逐条结果在统筹机器上；规则码与计数一致。
- 其余20个文件仓库中找不到上次的gate结果，**以本次为新基线**。其中只有FIR、IDAC控制器、reset_sync三个文件非零，全部是区块归属（VG052/VG061）、注释复用（VG066）和注释列对齐（VG060），**没有功能、复位、FSM或综合类规则命中**。FIR和IDAC控制器的条目都集中在验证专用注入就绪端口`o_test_*_inject_ready`上，推测是加这些端口时没有过gate，属于待查（风格）。
- 去掉已接受的豁免（芯片顶层VG010×46、control_top VG031×1）后，芯片层级内剩余：错误28（AMI 2、SSW 10、FIR 3、IDAC控制器 3、reset_sync 10），strict告警2（AMI 1、PWI 1）。

### 3.3 `ppg_digital_esd_shell`（保留，封装引脚边界）
- delivery_ready为否，错误163，strict告警89：VG004×52、VG010×52、VG011×52、VG041×52、VG014×37、VG007×4、VG001、VG009、VG040。
- 判断：这是一个黑盒壳层，端口为物理引脚名，不带`i_/o_`前缀。VG010、VG011（前缀）、VG041、VG004（端口分组注释和桥接）这一类与芯片顶层VG010豁免同源，按同一原则应当一并列为豁免。VG001（文件头）、VG007、VG009、VG040需要人工确认是否为壳层本身的写法问题。仓库中找不到上次结果，**以本次为新基线**。

### 3.4 P1将归档的6个孤立模块（单列，不计入）

| 文件 | 错误 | strict告警 | 主要规则 |
|---|---|---|---|
| `ppg_dual_precision_top` | 301 | 0 | VG060×234、VG066×61、VG021×4、VG061×2 |
| `ppg_timing_sar9` | 202 | 0 | VG060×198，VG000（解析失败）、VG007、VG040 |
| `ppg_timing_sar15` | 193 | 0 | 同上 |
| `ppg_timing_sar9_3200hz` | 97 | 75 | VG060×46、VG064×47、VG041×46、VG014×29 |
| `ppg_timing_sar15_3200hz` | 97 | 75 | 同上 |
| `ppg_digital_shell` | 135 | 65 | 与esd_shell同类 |
| `ppg_timing_3200hz_validation` | — | — | 该目录下只有`tb_ppg_timing_3200hz.v`和`filelist.f`，没有RTL；对TB跑gate只得到VG000×1（解析失败） |

---

## 4. 新增项汇总

| 来源 | 新增项 | 判断 |
|---|---|---|
| CDC Phase1 | 14个新寄存器标注（AMI 12、校正器1、SSW 1），全部为CLK_2M | 正常新增，非问题 |
| CDC Phase1 | `tb_ppg_control_top_adc_anomaly.v`解析失败 | 误报（TB，不在芯片层级内） |
| CDC Phase4 | 8个新的同域深链寄存器、2个跳数增加 | 正常新增，非问题；漏检跨域候选仍为0 |
| 文字滞后 | 矩阵第1314行 | 误报（删除线文字） |
| 文字滞后 | 矩阵第3271行（原3085行移动） | 误报（既有，历史证据说明） |
| gate | FIR、IDAC控制器、reset_sync的非零项 | 新基线；风格类，待查（不影响功能） |
| gate | esd_shell的163/89 | 新基线；建议按芯片顶层VG010的原则列入封装边界豁免，VG001/VG007/VG009/VG040待人工确认 |
| 任务书口径 | "芯片顶层1个VG031" | 订正：VG031在`ppg_control_top.v`，芯片顶层只有VG010×46 |

**真问题：0。待查：2项（FIR、IDAC控制器gate中的注入就绪端口区块归属；esd_shell中的非命名类规则）。**
