# 验收编号治理只读核查（为合同合并批次做准备），2026-10-05

## 0. 结论先行

- **快照**：`origin/main` = `2a90a69`。核查全程读取`git archive 2a90a69`导出到仓库外的副本；本次只新增本报告，没有改任何RTL、TB、合同、矩阵、别名表或tools文件。收尾时`origin/main`仍为`2a90a69`，核查期间没有新提交。
- **规模**：合同侧有39个编号族、791个条目；TB侧50个文件、718个带编号检查（按“族+编号”合并字母子标签后计）。对照总表共882行：A一致529、B同号不同义65、C部分一致43、D未登记33、E合同有TB无同名标签131、F TB本地编号58、待定1、N/A 22（核对表的清单编号，不是验收ID）。
- **最严重的发现是FSC全族错位**，远超F-046点名的5处。调度器单元TB按自己的场景顺序给62个检查编号FSC-1…FSC-62：除FSC-1大体对应合同FSC-01外，**TB的FSC-2至FSC-57与C08第18节同号条目含义全部不同**（56处B）。例如TB的FSC-14才是合同FSC-03的“5000周期宏帧”，TB的FSC-3测的是“START后首帧前无帧起点”。按含义反查，合同FSC-18、19、20、21、23、24、27、34、35、43、44、47、48、53、57这15条在该TB中**没有任何同义检查**。
- **这些错位已经被写成“证据”**：C01第38行和核对表第43、420行写“Scheduler FSC-01～57……均已有当前单模块PASS证据”，C08第1206行要求“自检TB必须真实覆盖FSC-01至FSC-57”。日志里的`ALL FSC-01 THROUGH FSC-62 PASSED`看上去满足了这条要求，实际不满足。
- **其他B类**：
  - SUP：SUP03A、SUP09A、SUP10A测的不是C24的SUP-03/09/10；SUP06A也不是看门狗。总横幅“SUP-01 through SUP-10 PASS”把SUP-05、SUP-08（无检查）一并算作通过。
  - DCR：TB第3至7号`drive_and_check`的测试编号与C15第15节错位（例如TB DCR-5实测的是合同DCR-12）。由于这些编号只在FAIL时打印，PASS日志里只有横幅“DCR-01..DCR-22”。
  - SSW-18：TB测的是校准owner截止超时，属于SSW-37/38；合同SSW-18是tick 385 burst超时。
  - LFA-11a：子标签含义属于§9.5.1规则5/P03。
- **AMI-01~45**：与C10逐条对照后，**没有发现同号不同义**。其中17条一致、27条只覆盖部分、AMI-13待定（TB只测反压保持，合同要求同拍替换）。46~49改名后已无撞号。
- **核对脚本`reconcile_acceptance_ids.py`不读TB日志**，只认别名表行和`@satisfies`标签。它的ID正则只覆盖22个族，FSC/AMI/SUP/SSW/DCR/CCC/MGR等29个族根本不在其视野内，所以上述B类撞号对它的分类**影响为0个ID**。但它在zlcx克隆里有两个更直接的问题：
  - 路径仍指向原开发树的`ppg_system_integration/`，原样运行时301个ID中有299个落入B2，结果不可用；
  - 改正路径后，TB文件头修订记录里写着`@satisfies:`的叙述文字会被当作标签，生成22个伪ID。
- **真正的虚假证据通道是文字**：合同和核对表里的“全部PASS”叙述、TB总横幅，以及别名表P05行把SUP06A当看门狗证据。
- **负对照通过**：在仓库外副本中人为加入1处同号不同义（PWC-05）和1处未登记编号（PWC-42），`rescan_diff.py`恰好报出这2处；未改动的副本重跑报0处。

## 1. 快照与输入

| 项 | 值 |
|---|---|
| 快照 | `2a90a69`（不早于要求的`2a90a69`；收尾时`git log --oneline 2a90a69..origin/main`为空） |
| 合同 | 快照`contracts/*.md`，排除矩阵与别名表后共34份 |
| TB | 快照`rtl/**/tb_*.v`与`rtl/**/*.vh`，不含`legacy/`，共50个文件 |
| 日志 | `D:\PPG\verilog\ppg_regression_runs\f485cbc_20261001_unit\tb_*\xsim.log`（模块级）；`…\f485cbc_20261001\rtl\ppg_control_top\xsim_regression_20260906\tb_*\xsim.log`（19-TB系统级，目录名沿用旧日期，实为f485cbc导出）；`…\f485cbc_20261001\rtl\ppg_chip_digital_top\xsim_regression_20261002\…\xsim.log`（芯片顶层） |
| AMI改名后日志 | f485cbc之后只有AMI单元TB改过（`3f4673d`/`2bb6b17`）。本报告用B会话10-05在2bb6b17导出上经入口脚本跑出的xsim.log（50项PASS，横幅匹配） |
| 读过的记忆与文档 | 命名治理规则、核对脚本、双锚点约定、任务C、批次3第二阶段，以及两条行号重映射经验；矩阵§11、§13（含§13.2局限、§13.3治理规则）；`reconcile_acceptance_ids.py`源码；ABCD复核报告F-046行 |

## 2. 方法

1. **合同侧**（`scan_contract_ids.py`）：凡是首列为单个编号的表格行都提取，也兼容`MGR-01复位`这种编号与标题同格的写法，记录文件、行号、所在章节和各列内容。同时检查三类合同自身问题：同一合同内的重复与断号、同一编号在多份合同重复定义、正文“XXX-aa至XXX-bb”类范围超出表格。扫描器避开了已知的陷阱：中文紧邻时`\b`失效，改用显式前后界。
2. **TB侧**（`scan_tb_labels.py`）：
   - 只看去掉`//`注释后的代码中字符串字面量里的编号，以及6个以`%0d`打印编号的TB的数字调用（`check_fsc(n,…)`、`check_case(8'dn,…)`、`drive_and_check(n,…)`、`send/check_transaction(n…)`、`reg_test_case_id=8'dn`、`drive_and_check_transaction(n,…)`）。
   - 每个检查点都附上真实比较代码：`check_*`调用取整条语句，`$display`取向上最近的`if`条件。
   - 子标签（`SUP01A`、`PVW-09-WRAP`、`LFA-02a`、`TC4a`等）并入父编号统计，并在说明里列出。
3. **日志侧**（`scan_logs.py`）：逐行提取实际打印出来的带编号行，保留原文。这样可以确认标签确实被打印，并区分“仅FAIL分支带编号”的情况。
4. **语义判读**：不按行号推算，也不凭注释判断。逐族读检查代码本身（比较的信号与条件）以及它前面的激励，再与合同条目的含义比对。重点族（FSC、SUP、AMI-01~45、DCR、SSW）逐条读完整场景代码；描述性标签族（PWC/PVW/FIR/BSL/OPT/C25各族等）以标签文字加条件代码比对，必要时回读场景。判定结果写在`decisions.py`里，作为附录数据。
5. **E类核实**：没有同名TB标签的合同条目，先查别名表和矩阵中有没有别的TB场景名下的证据（`e_check.py`），再下结论。
6. **核对脚本评估**：在仓库外副本中原样运行一次；再把路径改到`contracts/`（只改副本）运行一次，看分类结果。
7. **负对照与重扫门**：见第12节与附录B。

## 3. 合同侧

### 3.1 各族统计

各族的合同条目数和分类分布见第5节的统计表。合同条目所在位置：

- C08 FSC 57、C09 SSW 52、C10 AMI 54、C24 SUP 10；
- C25：SID 12、TRK 10、RRC 12、NRE 6、ILM 15、ADCN 10、ISE 10、OIB 10、LFA 12、PRC 10、RAW 13；
- C02 MGR 24、C03 AV4C 22、C04 AV4 19、C05 UNPACK 4、C06 CIS 30、C07 CCC 26、C11 CAL 17、C12 RTR 13、C14 PR 14、C15 DCR 22；
- C16：FFK 9、IDT 15、AMR 14、CF4 5；
- C17 IDC2 24、C18 PWI 8、C19 FIR 33、C20 BSL 40、C21 OPT 24、C22 PVW 48；
- C23：PWC 41，另有PWI 5；
- C01 TOP 24；核对表PC 22。
- C13没有编号表。芯片顶层合同没有验收ID族。联合TB说明只引用JNT，没有定义表。

### 3.2 合同侧自身问题

扫描器报告：同一合同内**重复0处、断号0处**；**跨合同重复定义5处**；**正文范围超出表格9处**（另有1处是同一行出现两次）。逐条如下：

| # | 位置 | 问题 |
|---|---|---|
| S1 | C10:30、C10:1340 | 写“AMI-46至AMI-55”，第17节表格只到AMI-54 |
| S2 | C19:3（“FIR-01~36”）、C19:10、C19:686（“FIR-31至FIR-36”） | 表格只到FIR-33 |
| S3 | C18:3（“PWI-01至PWI-10”）、C18:10、C18:690（“PWI-06至PWI-10”） | 表格只到PWI-08 |
| S4 | C18:659 | 写“xsim中PWI-01至PWI-07全部真实比较PASS”，但PWI单元TB只有PWI-01~05 |
| S5 | C23:963-967与C18:639-643 | PWI-01~05在两份合同各定义一次。标题相同，但细节详略不同，归属不唯一 |
| S6 | C22:847-848 | PVW-47/48行比表头多一列（“（2026-09-17新增）”单独成格） |
| S7 | C08:1206；C01:38；核对表:43、:45、:420；C09:878 | 声称FSC-01~57、SSW-01~52“当前PASS/证据完整”。FSC见第6.1节，SSW-18见第6.4节，均不成立 |
| S8 | C02 MGR-12（:349） | 列出错误码0x05，TB未测。TB注释称原IDAC枚举场景已按V4.9改判0x15，RTL仍保留`ERROR_ENUM_ENCODING=8'h05`。0x05是否仍可达**待定** |
| S9 | C02 MGR-18与MGR-23 | 两条都规定OFF→0x16，内容重叠 |
| S10 | C24 SUP-10（:161） | 内容是“AMI本地保留fault-discard原因”，实际归C10 AMI-53，放在supervisor验收表里归属不对 |
| S11 | C17 IDC2-17（:670）对照C16 AMR-10、C10 AMI-18、C08 FSC-21 | IDC2-17说周期AMB在窗口时“不请求DCS重验”，另三份说AMB码未变仍做两色DC重验证；C17第503行限定的是`o_dcs_revalidate_request`握手。可能是两套机制，**待定**，需读RTL确认 |
| S12 | C08:1253 | 已正确声明“V1.3历史日志FSC-01～57 PASS为非规范证据”。保留历史即可，但与S7中的当前声明相互矛盾 |

## 4. TB侧

TB侧统计见下表。“实际日志PASS行出现的标签数”小于“代码中不同标签数”时，说明该TB只在FAIL分支打印编号，或编号只在横幅里。`.vh`中的JNT标签打印在包含它的系统级TB日志里，因此这一行记为0。

| TB | 编号族 | 代码中不同标签数 | 实际日志PASS行出现的标签数 | 总横幅 |
| --- | --- | ---: | ---: | --- |
| tb_diag_algo_probe | RAW | 2 | 2 | — |
| tb_ppg_400hz_frame_calibration_scheduler | FSC | 62 | 62 | `ALL FSC-01 THROUGH FSC-62 PASSED`；`FSC-01 through FSC-62: pass=%0d fail=%0d` |
| tb_ppg_active_v4_control_plane_integration | AV4C | 22 | 22 | `ALL AV4C-01 THROUGH AV4C-22 PASSED` |
| tb_ppg_adc_dc_recovery | DCR | 19 | 2 | `PASS ppg_adc_dc_recovery DCR-01..DCR-22` |
| tb_ppg_adc_measurement_idac_integration | AMI、AMI-DISC、AMI-SID05、N08 | 50 | 50 | `AMI-01 through AMI-45, AMI-DISC-1/2, AMI-SID05-1/2 plus N08-01 PASS: %` |
| tb_ppg_adc_pipeline_overlap_corrector | OVL | 19 | 2 | `PASS ppg_adc_pipeline_overlap_corrector OVL-01..OVL-17 and 1024-code s` |
| tb_ppg_adc_programmable_reconstructor | PR | 16 | 2 | `PASS ppg_adc_programmable_reconstructor PR-01..PR-14 and 1024-code swe` |
| tb_ppg_adc_result_router |  | 0 | 0 | `PASS ppg_adc_result_router RTR-01..RTR-13` |
| tb_ppg_adc_s1_programmable_calibrator | CAL | 17 | 2 | `PASS ppg_adc_s1_programmable_calibrator CAL-01..CAL-17` |
| tb_ppg_amb_recheck_scheduler | AMR | 11 | 11 | — |
| tb_ppg_characterization_control_cdc | CCC | 26 | 26 | `ALL CCC-01 TO CCC-26 PASS (%0d checks)` |
| tb_ppg_chip_digital_top | TC | 7 | 7 | — |
| tb_ppg_coarse_detection_fir | FIR | 33 | 33 | — |
| tb_ppg_control_top | NPA、SMOKE、TOP | 40 | 38 | — |
| tb_ppg_control_top_adc_numeric_scoreboard | ADCN | 7 | 7 | — |
| tb_ppg_control_top_baseline_cross | D01 | 3 | 2 | — |
| tb_ppg_control_top_idac_bus_isolation | ISE | 8 | 8 | — |
| tb_ppg_control_top_injection | INJ、LFA、PRC | 7 | 7 | — |
| tb_ppg_control_top_input_light_static_matrix | ILM | 15 | 14 | — |
| tb_ppg_control_top_lifecycle_fault_adc_anomaly | AMI、LFA、OIB | 18 | 15 | — |
| tb_ppg_control_top_longrun | RAW | 2 | 2 | — |
| tb_ppg_control_top_no_recheck_control | NRE | 6 | 6 | — |
| tb_ppg_control_top_normal_slow_tracking | TRK | 12 | 12 | — |
| tb_ppg_control_top_owner_identity_backpressure | OIB | 8 | 8 | — |
| tb_ppg_control_top_periodic_recheck_recovery | RRC | 12 | 12 | — |
| tb_ppg_control_top_robustness_corner_waveforms | INJ、PRC、RGC | 15 | 14 | — |
| tb_ppg_control_top_startup_idac_calibration | INJ、LFA、SID | 14 | 12 | — |
| tb_ppg_dynamic_baseline_cross_detector | BSL、OPT、OPTC | 65 | 65 | `ALL BSL-01 THROUGH BSL-39, OPT-01 THROUGH OPT-24 AND OPTC-01 THROUGH O` |
| tb_ppg_idac_code_controller | IDT | 15 | 15 | — |
| tb_ppg_jnt_baseline_prefix | JNT | 19 | 0 | — |
| tb_ppg_normal_transaction_fork | FFK | 9 | 9 | `PASS: ppg_normal_transaction_fork completed FFK-01 through FFK-09` |
| tb_ppg_peak_valley_window_detector | PVW | 48 | 48 | `PVW-01 through PVW-48 ALL PASS: %0d checks` |
| tb_ppg_precision_window_controller | PWC | 41 | 41 | `PWC-01 through PWC-41 ALL PASS pass=%0d fail=%0d` |
| tb_ppg_precision_window_integration | PWI | 5 | 5 | `ALL PWI-01 THROUGH PWI-05 PASS count=%0d` |
| tb_ppg_real_raw_generator_selfcheck | RGC | 15 | 15 | — |
| tb_ppg_sar9_sar15_safe_selection_wrapper | SSW | 52 | 52 | `ALL SSW-01 THROUGH SSW-52 PASS` |
| tb_ppg_system_active_config_unpack | UNPACK | 4 | 0 | — |
| tb_ppg_system_config_manager | MGR | 22 | 2 | `PASS: ppg_system_config_manager MGR-01 through MGR-24 all directed che` |
| tb_ppg_system_fault_abort_supervisor | SUP | 14 | 14 | `SUP-01 through SUP-10 PASS: %0d real comparisons` |

几种值得注意的打印形态：

- **编号补零不一致**：FSC打印`FSC-1`（合同`FSC-01`），CCC打印`CCC-1`，ADCN打印`ADCN-1`。按合同编号grep日志会漏掉这些行。
- **只有FAIL分支带编号**：DCR、PR、CAL、MGR、UNPACK的PASS日志只有一行总横幅；RTR的编号只出现在代码注释里。
- **总横幅声称整段区间**：FSC-01~62、SUP-01~10、MGR-01~24、DCR-01..22、PR-01..14、RTR-01..13、CAL-01..17、OVL-01..17、CCC-01~26、AV4C-01~22。区间中没有同义检查的条目也被横幅“覆盖”，见第6节。
- **无条件PASS**：PRC-05、PRC-08的PASS行是直接`$display`引用其他TB的证据，本TB不做比较。LFA-11a的两个分支都打印PASS。

## 5. 对照总表

分类定义：
- A：一致。
- B：同号不同义。
- C：部分一致。
- D：TB有、合同无。
- E：合同有、TB无同名标签（已查别名表/矩阵）。
- F：TB本地编号。
- 待定：缺少判定所需信息。
- N/A：不是验收ID。

### 5.1 各族分类统计

| 族 | 合同条目数 | TB带编号检查数 | A | B | C | D | E | F | 待定 | N/A |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| ADCN | 10 | 7 | 7 | 0 | 0 | 0 | 3 | 0 | 0 | 0 |
| AMI | 54 | 45 | 17 | 0 | 27 | 0 | 9 | 0 | 1 | 0 |
| AMI-DISC | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |
| AMI-SID05 | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |
| AMR | 14 | 11 | 11 | 0 | 0 | 0 | 3 | 0 | 0 | 0 |
| AV4 | 19 | 0 | 0 | 0 | 0 | 0 | 19 | 0 | 0 | 0 |
| AV4C | 22 | 22 | 19 | 0 | 3 | 0 | 0 | 0 | 0 | 0 |
| BSL | 40 | 39 | 39 | 0 | 0 | 0 | 1 | 0 | 0 | 0 |
| CAL | 17 | 17 | 17 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| CCC | 26 | 26 | 25 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| CF4 | 5 | 0 | 0 | 0 | 0 | 0 | 5 | 0 | 0 | 0 |
| CIS | 30 | 0 | 0 | 0 | 0 | 0 | 30 | 0 | 0 | 0 |
| D01 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 |
| DCR | 22 | 19 | 14 | 5 | 0 | 0 | 3 | 0 | 0 | 0 |
| FFK | 9 | 9 | 9 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| FIR | 33 | 33 | 33 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| FSC | 57 | 62 | 0 | 56 | 1 | 5 | 0 | 0 | 0 | 0 |
| IDC2 | 24 | 0 | 0 | 0 | 0 | 0 | 24 | 0 | 0 | 0 |
| IDT | 15 | 15 | 15 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| ILM | 15 | 15 | 15 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| INJ | 0 | 5 | 0 | 0 | 0 | 0 | 0 | 5 | 0 | 0 |
| ISE | 10 | 8 | 7 | 0 | 1 | 0 | 2 | 0 | 0 | 0 |
| JNT | 0 | 9 | 0 | 0 | 0 | 9 | 0 | 0 | 0 | 0 |
| LFA | 12 | 12 | 9 | 0 | 2 | 0 | 1 | 0 | 0 | 0 |
| MGR | 24 | 22 | 21 | 0 | 1 | 0 | 2 | 0 | 0 | 0 |
| N08 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 | 0 | 0 |
| NPA | 0 | 2 | 0 | 0 | 0 | 0 | 0 | 2 | 0 | 0 |
| NRE | 6 | 6 | 6 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| OIB | 10 | 8 | 8 | 0 | 0 | 0 | 2 | 0 | 0 | 0 |
| OPT | 24 | 24 | 24 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| OPTC | 0 | 2 | 0 | 0 | 0 | 2 | 0 | 0 | 0 | 0 |
| OVL | 0 | 17 | 0 | 0 | 0 | 17 | 0 | 0 | 0 | 0 |
| PC | 22 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 22 |
| PR | 14 | 13 | 13 | 0 | 0 | 0 | 1 | 0 | 0 | 0 |
| PRC | 10 | 10 | 8 | 0 | 2 | 0 | 0 | 0 | 0 | 0 |
| PVW | 48 | 48 | 48 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| PWC | 41 | 41 | 41 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| PWI | 8 | 5 | 5 | 0 | 0 | 0 | 3 | 0 | 0 | 0 |
| RAW | 13 | 2 | 2 | 0 | 0 | 0 | 11 | 0 | 0 | 0 |
| RGC | 0 | 15 | 0 | 0 | 0 | 0 | 0 | 15 | 0 | 0 |
| RRC | 12 | 12 | 12 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| RTR | 13 | 0 | 13 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| SID | 12 | 12 | 12 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| SMOKE | 0 | 23 | 0 | 0 | 0 | 0 | 0 | 23 | 0 | 0 |
| SSW | 52 | 52 | 48 | 1 | 3 | 0 | 0 | 0 | 0 | 0 |
| SUP | 10 | 9 | 3 | 3 | 2 | 0 | 2 | 1 | 0 | 0 |
| TC | 0 | 6 | 0 | 0 | 0 | 0 | 0 | 6 | 0 | 0 |
| TOP | 24 | 15 | 14 | 0 | 0 | 0 | 10 | 0 | 0 | 0 |
| TRK | 10 | 10 | 10 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| UNPACK | 4 | 4 | 4 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| **合计** | 791 | 718 | 529 | 65 | 43 | 33 | 131 | 58 | 1 | 22 |

### 5.2 逐ID总表

“TB位置”列给出带编号的检查点，格式为`文件:行`，文件名省去`tb_ppg_`前缀；超过3处时以“…”省略。

| 族 | 编号 | 合同条目标题 | 合同位置 | TB位置（文件:行） | 分类 | 说明 |
| --- | --- | --- | --- | --- | --- | --- |
| ADCN | ADCN-01 | Representative Stage1 RAW encodings matc | C25:649 | control_top_adc_numeric_scoreboard:1192,1196,1254… | A | TB打印为`ADCN-n`不补零 |
| ADCN | ADCN-02 | Negative results, positive results, and  | C25:650 | control_top_adc_numeric_scoreboard:1297,1301,1305 | A | TB打印为`ADCN-n`不补零 |
| ADCN | ADCN-03 | Stage1 arithmetic outside the signed 12- | C25:651 | control_top_adc_numeric_scoreboard:1340,1375 | A | TB打印为`ADCN-n`不补零 |
| ADCN | ADCN-04 | A valid SAR9 transaction produces the fr | C25:652 | — | E | 无独立PASS；别名表267/269行：隐含在ADCN-1/2/3行的"SAR9 fine_valid unexpectedly asserted"未触发 |
| ADCN | ADCN-05 | A valid SAR15 transaction uses the bound | C25:653 | control_top_adc_numeric_scoreboard:1410,1414 | A | TB打印为`ADCN-n`不补零 |
| ADCN | ADCN-06 | SAR15 coarse and fine DC-recovered resul | C25:654 | control_top_adc_numeric_scoreboard:1418 | A | TB打印为`ADCN-n`不补零 |
| ADCN | ADCN-07 | Every numerical comparison binds frame,  | C25:655 | — | E | 无独立PASS；别名表260/270/271行 |
| ADCN | ADCN-08 | Output backpressure holds every numerica | C25:656 | control_top_adc_numeric_scoreboard:1213,1224,1232… | A | TB打印为`ADCN-n`不补零 |
| ADCN | ADCN-09 | The signed 12-bit Stage1 value is never  | C25:657 | — | E | 无独立PASS；别名表272行指向阶段C饱和边界 |
| ADCN | ADCN-10 | Stage2, reconstructed, coarse/fine recov | C25:658 | control_top_adc_numeric_scoreboard:1447,1450 | A | TB打印为`ADCN-n`不补零 |
| AMI | AMI-01 | 复位 | C10:1216 | adc_measurement_idac_integration:1134 | C | 只查复位期间无结果/校准valid、无fire；未查pending/inflight/fork所有权 |
| AMI | AMI-02 | 唯一结果owner fire | C10:1217 | adc_measurement_idac_integration:1161 | C | 只查一次start产生一次fire；未查capture/S1同拍接受 |
| AMI | AMI-03 | start反压 | C10:1218 | adc_measurement_idac_integration:1183 | C | 查资格缺失时ready=0、无fire；"恢复后只启动一次"未查 |
| AMI | AMI-04 | 9-bit RAW链 | C10:1219 | adc_measurement_idac_integration:1169 | C | 查9-bit结果coarse有效、fine无效；未逐级查元数据 |
| AMI | AMI-05 | 15-bit RAW链 | C10:1220 | adc_measurement_idac_integration:1227 | C | 查15-bit结果精度=1、颜色IR |
| AMI | AMI-06 | Stage1校准与router | C10:1221 | adc_measurement_idac_integration:1170 | C | 只查NORMAL进入正式结果；AMB/DCS分支未在此标签下查 |
| AMI | AMI-07 | 非法frame type | C10:1222 | adc_measurement_idac_integration:1254 | A |  |
| AMI | AMI-08 | NORMAL fork | C10:1223 | adc_measurement_idac_integration:1259 | C | 查两分支传输计数相等>0；独立反压未构造 |
| AMI | AMI-09 | overlap角色 | C10:1224 | adc_measurement_idac_integration:1171 | C | 只查9-bit无programmable valid |
| AMI | AMI-10 | 9-bit DC恢复 | C10:1225 | adc_measurement_idac_integration:1172 | C | 只查9-bit精度位=0（coarse/fine在AMI-04） |
| AMI | AMI-11 | 15-bit DC恢复 | C10:1226 | adc_measurement_idac_integration:1228 | C | 查15-bit coarse/fine/programmable有效及Stage2 epoch |
| AMI | AMI-12 | DC恢复双fork | C10:1227 | adc_measurement_idac_integration:1242 | C | 只查反压下结果保持；双fork两种先后顺序未构造 |
| AMI | AMI-13 | 输出同拍替换 | C10:1228 | adc_measurement_idac_integration:1244 | 待定 | TB实测反压5拍后同一结果仍保持（无新事务装入）；合同要求"同拍替换、无空泡和覆盖"。是部分覆盖还是同号不同义，需看是否有别处构造同拍替换 |
| AMI | AMI-14 | 启动AMB搜索 | C10:1229 | adc_measurement_idac_integration:1152 | C | 只查启动搜索完成且AMB码在范围内；握手次数与SID-05重握手不在此标签（见AMI-SID05-1/2） |
| AMI | AMI-15 | 启动DC_R/DC_IR | C10:1230 | adc_measurement_idac_integration:1153 | C | 只查DC码在范围内 |
| AMI | AMI-16 | NORMAL慢速跟踪 | C10:1231 | adc_measurement_idac_integration:1270 | C | 查有调码且正式结果继续交付 |
| AMI | AMI-17 | 周期重检闭环 | C10:1232 | adc_measurement_idac_integration:1318 | C | 查3次重检请求、accept、busy清除；逐阶段匹配未单独查 |
| AMI | AMI-18 | AMB码未改变 | C10:1233 | adc_measurement_idac_integration:1320 | A |  |
| AMI | AMI-19 | 普通精度切换 | C10:1234 | adc_measurement_idac_integration:1299 | C | 查切到15-bit且FIR历史满；旧事务精度未单独查 |
| AMI | AMI-20 | 重检安全接管 | C10:1235 | adc_measurement_idac_integration:1304 | C | 查安全边界前不accept |
| AMI | AMI-21 | STOP排空 | C10:1236 | adc_measurement_idac_integration:1389 | C | 只查STOP后ready=0；排空在AMI-40 |
| AMI | AMI-22 | abort在途 | C10:1237 | adc_measurement_idac_integration:1420 | A |  |
| AMI | AMI-23 | epoch与配置变化 | C10:1238 | adc_measurement_idac_integration:1173 | C | 查结果epoch等于配置快照；未在事务途中改配置（AMI-34做了输入改写） |
| AMI | AMI-24 | blocking fault | C10:1239 | adc_measurement_idac_integration:1546 | C | `!o_wrapper_fault_blocking // !o_transaction_start_ready`，此时无阻断故障时恒真（可能空真） |
| AMI | AMI-25 | NORMAL边界同拍 | C10:1240 | adc_measurement_idac_integration:1379 | A |  |
| AMI | AMI-26 | 快速校准IDAC边界 | C10:1241 | adc_measurement_idac_integration:1356 | A |  |
| AMI | AMI-27 | 宏帧边界隔离 | C10:1242 | adc_measurement_idac_integration:1340 | A |  |
| AMI | AMI-28 | safe frame ID绑定 | C10:1243 | adc_measurement_idac_integration:1362 | A |  |
| AMI | AMI-29 | 生命周期与边界 | C10:1244 | adc_measurement_idac_integration:1401 | C | 只覆盖STOP期间；abort/阻断故障期间未查 |
| AMI | AMI-30 | 完成旁带原子性 | C10:1245 | adc_measurement_idac_integration:1167 | A |  |
| AMI | AMI-31 | 完成旁带双消费者 | C10:1246 | adc_measurement_idac_integration:1177 | C | 模块级只能查完成脉冲不重复；Top双消费者连接不在本TB |
| AMI | AMI-32 | 迟到/失败完成 | C10:1247 | adc_measurement_idac_integration:1421 | A |  |
| AMI | AMI-33 | 两类上下文隔离 | C10:1248 | adc_measurement_idac_integration:1191 | C | 查宏帧边界不fire/不完成；"无兼容别名"为静态条款 |
| AMI | AMI-34 | owner原子提交 | C10:1249 | adc_measurement_idac_integration:1209 | A |  |
| AMI | AMI-35 | START启动边界透传 | C10:1250 | adc_measurement_idac_integration:1145 | A |  |
| AMI | AMI-36 | START启动边界隔离 | C10:1251 | adc_measurement_idac_integration:1147 | C | 查启动边界无fire/无宏帧路由/无完成 |
| AMI | AMI-37 | 真实DONE资格 | C10:1252 | adc_measurement_idac_integration:1163; control_top_lifecycle_fault_adc_anomaly:2160 | C | 查8拍内无完成；Q3/包络末沿等替代完成未逐一构造 |
| AMI | AMI-38 | 完成身份逐字段匹配 | C10:1253 | adc_measurement_idac_integration:1211 | C | 逐字段比较身份；内部失败success=0路径不在此标签 |
| AMI | AMI-39 | abort迟到DONE | C10:1254 | adc_measurement_idac_integration:1424 | A |  |
| AMI | AMI-40 | STOP在途排空 | C10:1255 | adc_measurement_idac_integration:1445 | A |  |
| AMI | AMI-41 | reset后旧DONE | C10:1256 | adc_measurement_idac_integration:1463 | A |  |
| AMI | AMI-42 | 精度切换IDAC保持 | C10:1257 | adc_measurement_idac_integration:1291 | C | 查切换后pending与epoch保持 |
| AMI | AMI-43 | CHARACTERIZATION档案与校准资格隔离 | C10:1258 | adc_measurement_idac_integration:1528 | A |  |
| AMI | AMI-44 | CHARACTERIZATION手动码 | C10:1259 | adc_measurement_idac_integration:1506 | A |  |
| AMI | AMI-45 | CHARACTERIZATION算法边界 | C10:1260 | adc_measurement_idac_integration:1535 | A |  |
| AMI | AMI-46 | 注入默认关闭 | C10:1261 | — | E | 单元TB旧AMI-46已改名AMI-DISC-1（2bb6b17）；C10第30行自述AMI-46至AMI-55为EVIDENCE_PENDING；顶层注入默认关闭证据见TOP-21/INJ-01 |
| AMI | AMI-47 | identity请求绑定 | C10:1262 | — | E | 同上；identity请求绑定的顶层证据见INJ-02/TOP-22。矩阵947/3724/3731/3736、别名表545仍以"AMI-47"指旧TB discard检查（历史叙述，用户决定不改） |
| AMI | AMI-48 | identity matcher拒绝 | C10:1263 | — | E | 单元TB旧AMI-48已改名AMI-SID05-1；matcher拒绝的顶层证据见LFA-08/INJ-02 |
| AMI | AMI-49 | identity恢复 | C10:1264 | — | E | 单元TB旧AMI-49已改名AMI-SID05-2；identity恢复的顶层证据见INJ-02/LFA-04 |
| AMI | AMI-50 | invalid请求绑定 | C10:1265 | — | E | invalid请求绑定：顶层证据见INJ-03/PRC-08/TOP-23 |
| AMI | AMI-51 | invalid正式sideband | C10:1266 | — | E | invalid正式sideband：顶层证据见INJ-03 |
| AMI | AMI-52 | invalid检测隔离 | C10:1267 | — | E | invalid检测隔离：顶层证据见PRC-09/10 |
| AMI | AMI-53 | 延迟fault discard reason | C10:1268 | — | E | 延迟fault-discard原因：顶层证据见LFA-02b |
| AMI | AMI-54 | V5有效资格单一路径 | C10:1269 | — | E | 别名表89行与矩阵3603/3627/3656：随Acceptance-D01-01（D01-01b）一起登记 |
| AMI-DISC | AMI-DISC-01 |  | — | adc_measurement_idac_integration:1567 | F | TB本地：C10第6.10节公开discard端口检查（原AMI-46/47） |
| AMI-DISC | AMI-DISC-02 |  | — | adc_measurement_idac_integration:1591 | F | TB本地：C10第6.10节公开discard端口检查（原AMI-46/47） |
| AMI-SID05 | AMI-SID05-01 |  | — | adc_measurement_idac_integration:1667 | F | TB本地：SID-05截止事件单元断言（原AMI-48/49），带@satisfies: SID-05；子标签：AMI-SID05-1 |
| AMI-SID05 | AMI-SID05-02 |  | — | adc_measurement_idac_integration:1679 | F | TB本地：SID-05截止事件单元断言（原AMI-48/49），带@satisfies: SID-05；子标签：AMI-SID05-2 |
| AMR | AMR-01 | interval为0 | C16:651 | amb_recheck_scheduler:346 | A |  |
| AMR | AMR-02 | MANUAL/SEARCH_HOLD且interval非0 | C16:652 | amb_recheck_scheduler:355,361 | A |  |
| AMR | AMR-03 | TRACK下完成4095帧 | C16:653 | amb_recheck_scheduler:384 | A |  |
| AMR | AMR-04 | TRACK下完成第4096帧 | C16:654 | amb_recheck_scheduler:387 | A |  |
| AMR | AMR-05 | pending等待15-bit到9-bit事件 | C16:655 | amb_recheck_scheduler:391 | A |  |
| AMR | AMR-06 | 切换事件到达但NORMAL/Fork未排空 | C16:656 | amb_recheck_scheduler:403 | A |  |
| AMR | AMR-07 | 第一笔AMB_CHECK在窗口内 | C16:657 | amb_recheck_scheduler:467 | A |  |
| AMR | AMR-08 | AMB同向越界达到确认数 | C16:658 | — | E | 无同名标签；受限二分重搜索由IDAC控制器TB的PERIODIC描述行覆盖（无编号） |
| AMR | AMR-09 | AMB重搜索改变码 | C16:659 | — | E | 同AMR-08 |
| AMR | AMR-10 | AMB码未改变 | C16:660 | amb_recheck_scheduler:467 | A |  |
| AMR | AMR-11 | 三路均在窗口 | C16:661 | amb_recheck_scheduler:512 | A |  |
| AMR | AMR-12 | 搜索耗尽 | C16:662 | amb_recheck_scheduler:545 | A |  |
| AMR | AMR-13 | AMB_CHECK事务到PPG链 | C16:663 | — | E | 无同名标签；"AMB_CHECK事务进PPG链必须判失败"未见专门检查 |
| AMR | AMR-14 | STOP打断周期请求 | C16:664 | amb_recheck_scheduler:575 | A |  |
| AV4 | AV4-01 | 1024-bit逐位连接 | C04:606 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-02 | 唯一解包 | C04:607 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-03 | IDAC字段连接 | C04:608 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-04 | Stage1连接 | C04:609 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-05 | Stage2连接 | C04:610 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-06 | DC恢复连接 | C04:611 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-07 | 重检周期单所有者 | C04:612 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-08 | committed IDAC输出 | C04:613 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-09 | 生命周期 | C04:614 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-10 | 状态清除 | C04:615 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-11 | 排空返回 | C04:616 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-12 | 模拟资格隔离 | C04:617 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-13 | epoch原子性 | C04:618 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-14 | optical安全关闭 | C04:619 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-15 | V4保留位 | C04:620 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-16 | V5参数隔离 | C04:621 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-17 | abort无组合环 | C04:622 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-18 | RUN稳定性 | C04:623 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4 | AV4-19 | 校准责任边界 | C04:624 | — | E | C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖 |
| AV4C | AV4C-01 | 1024-bit联合传输 | C03:295 | active_v4_control_plane_integration:650,653 | A | 标签文字仍写"640-bit atomic CDC"，比较的是当前1024-bit ACTIVE |
| AV4C | AV4C-02 | 唯一解包 | C03:296 | active_v4_control_plane_integration:676,679 | A |  |
| AV4C | AV4C-03 | 合法COMMIT | C03:297 | active_v4_control_plane_integration:680 | C | 与AV4C-02共用同一组比较后打印PASS |
| AV4C | AV4C-04 | 非法COMMIT | C03:298 | active_v4_control_plane_integration:592,595 | A |  |
| AV4C | AV4C-05 | transport与commit区分 | C03:299 | active_v4_control_plane_integration:656,659 | A |  |
| AV4C | AV4C-06 | START资格 | C03:300 | active_v4_control_plane_integration:695,702,705 | A |  |
| AV4C | AV4C-07 | STOP排空 | C03:301 | active_v4_control_plane_integration:731,737,747… | A |  |
| AV4C | AV4C-08 | 状态清除 | C03:302 | active_v4_control_plane_integration:601,604 | A |  |
| AV4C | AV4C-09 | epoch独立性 | C03:303 | active_v4_control_plane_integration:687,778,781 | A |  |
| AV4C | AV4C-10 | V4保留位 | C03:304 | active_v4_control_plane_integration:614,617 | A |  |
| AV4C | AV4C-11 | NORMAL初始精度规则 | C03:305 | active_v4_control_plane_integration:628,631 | A |  |
| AV4C | AV4C-12 | 生命周期稳定 | C03:306 | active_v4_control_plane_integration:712,715 | A |  |
| AV4C | AV4C-13 | reset | C03:307 | active_v4_control_plane_integration:568,571,580 | A |  |
| AV4C | AV4C-14 | source反压 | C03:308 | active_v4_control_plane_integration:640,668,671 | A |  |
| AV4C | AV4C-15 | signed字段 | C03:309 | active_v4_control_plane_integration:681 | C | 与AV4C-02共用同一组比较后打印PASS |
| AV4C | AV4C-16 | V4字段隔离 | C03:310 | active_v4_control_plane_integration:765,768 | A |  |
| AV4C | AV4C-17 | 下游边界 | C03:311 | active_v4_control_plane_integration:682 | C | 与AV4C-02共用同一组比较后打印PASS |
| AV4C | AV4C-18 | abort隔离 | C03:312 | active_v4_control_plane_integration:718,721 | A |  |
| AV4C | AV4C-19 | STATIC_BIAS资格输入 | C03:313 | active_v4_control_plane_integration:799,802 | A |  |
| AV4C | AV4C-20 | 系统阻断与episode透传 | C03:314 | active_v4_control_plane_integration:845,852,856… | A |  |
| AV4C | AV4C-21 | 联合COMMIT拒绝 | C03:315 | active_v4_control_plane_integration:816,819 | A |  |
| AV4C | AV4C-22 | V5资格门控 | C03:316 | active_v4_control_plane_integration:825,834,837 | A |  |
| BSL | BSL-01 | 复位和新START | C20:896 | dynamic_baseline_cross_detector:758 | A |  |
| BSL | BSL-02 | 第一个可靠波峰 | C20:897 | dynamic_baseline_cross_detector:761 | A |  |
| BSL | BSL-03 | signed负斜率 | C20:898 | dynamic_baseline_cross_detector:766 | A |  |
| BSL | BSL-04 | FIR中心帧对齐 | C20:899 | dynamic_baseline_cross_detector:769 | A |  |
| BSL | BSL-05 | 三点确认 | C20:900 | dynamic_baseline_cross_detector:773 | A |  |
| BSL | BSL-06 | 候选中资格丢失 | C20:901 | dynamic_baseline_cross_detector:784 | A |  |
| BSL | BSL-07 | 相交事件反压 | C20:902 | dynamic_baseline_cross_detector:795 | A |  |
| BSL | BSL-08 | `lead<17` | C20:903 | dynamic_baseline_cross_detector:806 | A |  |
| BSL | BSL-09 | `17<=lead<=19` | C20:904 | dynamic_baseline_cross_detector:816 | A |  |
| BSL | BSL-10 | `lead>19` | C20:905 | dynamic_baseline_cross_detector:825 | A |  |
| BSL | BSL-11 | `alpha=0.20` | C20:906 | dynamic_baseline_cross_detector:807 | A |  |
| BSL | BSL-12 | `beta=0.25` | C20:907 | dynamic_baseline_cross_detector:817 | A |  |
| BSL | BSL-13 | 调整比例1/16 | C20:908 | dynamic_baseline_cross_detector:808 | A |  |
| BSL | BSL-14 | 斜率限幅 | C20:909 | dynamic_baseline_cross_detector:835 | A |  |
| BSL | BSL-15 | 单周期无相交 | C20:910 | dynamic_baseline_cross_detector:844 | A |  |
| BSL | BSL-16 | 连续两周期无相交 | C20:911 | dynamic_baseline_cross_detector:847 | A |  |
| BSL | BSL-17 | 普通9/15-bit切换 | C20:912 | dynamic_baseline_cross_detector:857 | A |  |
| BSL | BSL-18 | IR事务 | C20:913 | dynamic_baseline_cross_detector:865 | A |  |
| BSL | BSL-19 | 重检成功 | C20:914 | dynamic_baseline_cross_detector:878 | A |  |
| BSL | BSL-20 | 重检和预热时间 | C20:915 | dynamic_baseline_cross_detector:881 | A |  |
| BSL | BSL-21 | 恢复后位于基线下方 | C20:916 | dynamic_baseline_cross_detector:883 | A |  |
| BSL | BSL-22 | 恢复首样本已在基线上方 | C20:917 | dynamic_baseline_cross_detector:896 | A |  |
| BSL | BSL-23 | 重检失败 | C20:918 | dynamic_baseline_cross_detector:904 | A |  |
| BSL | BSL-24 | FIR/DC恢复无资格或饱和 | C20:919 | dynamic_baseline_cross_detector:913 | A |  |
| BSL | BSL-25 | frame_id回绕 | C20:920 | dynamic_baseline_cross_detector:923 | A |  |
| BSL | BSL-26 | epoch不一致 | C20:921 | dynamic_baseline_cross_detector:932 | A |  |
| BSL | BSL-27 | ACTIVE配置非法 | C20:922 | dynamic_baseline_cross_detector:938 | A |  |
| BSL | BSL-28 | detection discard | C20:923 | dynamic_baseline_cross_detector:948 | A |  |
| BSL | BSL-29 | 退出15-bit历史尾部 | C20:924 | dynamic_baseline_cross_detector:960 | A |  |
| BSL | BSL-30 | 跨精度候选切断 | C20:925 | dynamic_baseline_cross_detector:973 | A |  |
| BSL | BSL-31 | 返回9-bit重新建链 | C20:926 | dynamic_baseline_cross_detector:982 | A |  |
| BSL | BSL-32 | 恢复未知相交精度资格 | C20:927 | dynamic_baseline_cross_detector:1000 | A |  |
| BSL | BSL-33 | 异常返回重新获取 | C20:928 | dynamic_baseline_cross_detector:1010 | A |  |
| BSL | BSL-34 | 正常波谷返回 | C20:929 | dynamic_baseline_cross_detector:1020 | A |  |
| BSL | BSL-35 | 重新获取时旧cross反压 | C20:930 | dynamic_baseline_cross_detector:1033 | A |  |
| BSL | BSL-36 | 重新获取时算术busy | C20:931 | dynamic_baseline_cross_detector:1039 | A |  |
| BSL | BSL-37 | 重新获取后新波峰 | C20:932 | dynamic_baseline_cross_detector:1049 | A |  |
| BSL | BSL-38 | 重新获取与重检相邻 | C20:933 | dynamic_baseline_cross_detector:1065 | A |  |
| BSL | BSL-39 | 非法fine期间重获事件 | C20:934 | dynamic_baseline_cross_detector:1075 | A |  |
| BSL | BSL-40 | V5正式检测门控 | C20:935 | — | E | 别名表89行：随Acceptance-D01-01登记 |
| CAL | CAL-01 | 复位 | C11:370 | adc_s1_programmable_calibrator:197 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-02 | 标称权重遍历全部1024个RAW码 | C11:371 | adc_s1_programmable_calibrator:234,243 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-03 | 十个one-hot RAW码 | C11:372 | adc_s1_programmable_calibrator:269 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-04 | 仅offset和signed负权重 | C11:373 | adc_s1_programmable_calibrator:295 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-05 | 正负半LSB边界 | C11:374 | adc_s1_programmable_calibrator:313,321,329… | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-06 | signed 12-bit范围内边界 | C11:375 | adc_s1_programmable_calibrator:363,371 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-07 | 上下越界 | C11:376 | adc_s1_programmable_calibrator:379,387 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-08 | `active_valid=0` | C11:377 | adc_s1_programmable_calibrator:403 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-09 | CHARACTERIZATION标称系数 | C11:378 | adc_s1_programmable_calibrator:429 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-10 | 合法校准系数 | C11:379 | adc_s1_programmable_calibrator:443 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-11 | 输出反压 | C11:380 | adc_s1_programmable_calibrator:461 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-12 | 同拍消费和新输入 | C11:381 | adc_s1_programmable_calibrator:481,489 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-13 | valid为0时改变输入 | C11:382 | adc_s1_programmable_calibrator:502 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-14 | 接收后改变ACTIVE输入并保持反压 | C11:383 | adc_s1_programmable_calibrator:461 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-15 | 复位打断待消费输出 | C11:384 | adc_s1_programmable_calibrator:517,525,535 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-16 | 全部元数据组合变化 | C11:385 | adc_s1_programmable_calibrator:570 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CAL | CAL-17 | epoch从255回绕到0 | C11:386 | adc_s1_programmable_calibrator:583,592 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| CCC | CCC-01 | 共同复位 | C07:338 | characterization_control_cdc:264 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-02 | 复位释放偏斜 | C07:339 | characterization_control_cdc:277 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-03 | 首笔提交 | C07:340 | characterization_control_cdc:284 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-04 | 固定打包 | C07:341 | characterization_control_cdc:286 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-05 | source保持型valid | C07:342 | characterization_control_cdc:300 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-06 | source反压 | C07:343 | characterization_control_cdc:297 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-07 | 目标域原子更新 | C07:344 | characterization_control_cdc:302 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-08 | 单拍事件 | C07:345 | characterization_control_cdc:304 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-09 | 输出保持 | C07:346 | characterization_control_cdc:315 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-10 | 连续事务 | C07:347 | characterization_control_cdc:327 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-11 | 相同值重提交 | C07:348 | characterization_control_cdc:337 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-12 | 随机时钟相位 | C07:349 | characterization_control_cdc:348 | C | 只查一组相位下的结果与计数，"不同相位"未见循环 |
| CCC | CCC-13 | STATIC_BIAS更新MUX | C07:350 | characterization_control_cdc:356 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-14 | STATIC_BIAS禁止退出 | C07:351 | characterization_control_cdc:366 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-15 | 动态模式禁止进入 | C07:352 | characterization_control_cdc:380 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-16 | 拒绝无部分提交 | C07:353 | characterization_control_cdc:368 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-17 | NORMAL隔离 | C07:354 | characterization_control_cdc:387 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-18 | STOP保持配置 | C07:355 | characterization_control_cdc:396 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-19 | STOP后改模式 | C07:356 | characterization_control_cdc:403 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-20 | abort隔离 | C07:357 | characterization_control_cdc:412 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-21 | 在途传输后STOP/abort | C07:358 | characterization_control_cdc:424 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-22 | sticky清除 | C07:359 | characterization_control_cdc:442 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-23 | 复位取消在途 | C07:360 | characterization_control_cdc:456 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-24 | 无shadow旁路 | C07:361 | characterization_control_cdc:467 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-25 | 首笔前RUN违规 | C07:362 | characterization_control_cdc:475 | A | TB打印为`CCC-n`不补零 |
| CCC | CCC-26 | 事件互斥 | C07:363 | characterization_control_cdc:479 | A | TB打印为`CCC-n`不补零 |
| CF4 | CF4-01 | schema为04且保留位为0 | C16:670 | — | E | C16第15.4节ACTIVE V4字段检查，无TB标签；内容属MGR/AV4C |
| CF4 | CF4-02 | schema仍为03但重检字段非0 | C16:671 | — | E | C16第15.4节ACTIVE V4字段检查，无TB标签；内容属MGR/AV4C |
| CF4 | CF4-03 | `[639:592]`任一位为1 | C16:672 | — | E | C16第15.4节ACTIVE V4字段检查，无TB标签；内容属MGR/AV4C |
| CF4 | CF4-04 | interval为0、1、4096、65535 | C16:673 | — | E | C16第15.4节ACTIVE V4字段检查，无TB标签；内容属MGR/AV4C |
| CF4 | CF4-05 | RUN期间尝试修改interval | C16:674 | — | E | C16第15.4节ACTIVE V4字段检查，无TB标签；内容属MGR/AV4C |
| CIS | CIS-01 | 光电二极管输入 | C06:406 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-02 | 固定电流输入 | C06:407 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-03 | 固定电流LED关闭 | C06:408 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-04 | 固定电流400 Hz | C06:409 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-05 | 固定电流SAR15 | C06:410 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-06 | 禁止自动校准 | C06:411 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-07 | 输入源反压 | C06:412 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-08 | STATIC_BIAS进入 | C06:413 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-09 | STATIC_BIAS无SAR | C06:414 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-10 | STATIC_BIAS测试MUX | C06:415 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-11 | STATIC_BIAS原子更新 | C06:416 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-12 | STATIC_BIAS LED状态 | C06:417 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-13 | NORMAL隔离MUX | C06:418 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-14 | START快照 | C06:419 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-15 | STOP排空 | C06:420 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-16 | abort | C06:421 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-17 | 复位 | C06:422 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-18 | CDC提交 | C06:423 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-19 | AMB边界 | C06:424 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-20 | 非法组合 | C06:425 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-21 | 纯RED光电二极管SAR9 | C06:426 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-22 | 纯RED光电二极管SAR15 | C06:427 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-23 | 表征IDAC策略 | C06:428 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-24 | 表征固定码 | C06:429 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-25 | 非法表征START副作用 | C06:430 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-26 | STATIC_BIAS输入源资格 | C06:431 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-27 | STATIC_BIAS测量隔离 | C06:432 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-28 | STATIC_BIAS模拟许可 | C06:433 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-29 | 固定电流光学模式 | C06:434 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| CIS | CIS-30 | 固定电流OFF拒绝 | C06:435 | — | E | C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC |
| D01 | D01-01 |  | — | control_top_baseline_cross:931,935,939… | F | TB本地：矩阵Acceptance-D01-01a/b子检查；子标签：D01-01、D01-01a、D01-01b |
| DCR | DCR-01 | 复位 | C15:568 | adc_dc_recovery:242,434 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-02 | 9-bit中心值 | C15:569 | adc_dc_recovery:252 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-03 | 9-bit正负边界 | C15:570 | adc_dc_recovery:254 | B | TB drive_and_check(3,…)实测9-bit且DC码0时DC项为0（属合同DCR-04）；合同DCR-03"9-bit正负边界"无同义检查 |
| DCR | DCR-04 | 9-bit DC码为0 | C15:571 | adc_dc_recovery:256 | B | TB DCR-4实测15-bit双结果+K_DC15通路（DC码3）（属合同DCR-07/11）；合同DCR-04由TB DCR-3覆盖 |
| DCR | DCR-05 | K_DC9正值 | C15:572 | adc_dc_recovery:261 | B | TB DCR-5实测CHARACTERIZATION下恢复系数无效时资格为0（属合同DCR-12）；合同DCR-05"K_DC9每增1"仅由TB DCR-2的单点（DC码2）间接覆盖 |
| DCR | DCR-06 | 15-bit DC码为0 | C15:573 | adc_dc_recovery:269 | B | TB DCR-6实测24-bit正端饱和（属合同DCR-09）；合同DCR-06"15-bit DC码0"无同义检查 |
| DCR | DCR-07 | K_DC15正值 | C15:574 | adc_dc_recovery:270 | B | TB DCR-7实测24-bit负端饱和（属合同DCR-09）；合同DCR-07由TB DCR-4部分覆盖 |
| DCR | DCR-08 | Q16半LSB边界 | C15:575 | adc_dc_recovery:272,273 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-09 | signed 24-bit上下溢出 | C15:576 | adc_dc_recovery:285 | A | FAIL标签DCR-09；用force内部舍入网覆盖端点 |
| DCR | DCR-10 | 9/15连续切换 | C15:577 | adc_dc_recovery:292,293,294… | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-11 | 15-bit事务双结果 | C15:578 | — | E | 无同名标签；内容由TB DCR-4（15-bit双结果）覆盖 |
| DCR | DCR-12 | 系数无效CHARACTERIZATION | C15:579 | adc_dc_recovery:264 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-13 | NORMAL无效系数 | C15:580 | — | E | 无同名标签；"模块不伪造校准资格"由TB DCR-5覆盖，"系统不允许正式启动"属系统级 |
| DCR | DCR-14 | 上游Stage1/Stage2饱和 | C15:581 | adc_dc_recovery:373 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-15 | 输出反压 | C15:582 | adc_dc_recovery:308,326 | A | FAIL标签"DCR-15/17 backpressure hold" |
| DCR | DCR-16 | 同拍消费替换 | C15:583 | adc_dc_recovery:334,363 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-17 | 配置输入变化 | C15:584 | — | E | 只出现在组合标签"DCR-15/17"中：反压期间改增益/epoch后保持 |
| DCR | DCR-18 | epoch回绕 | C15:585 | adc_dc_recovery:381,386 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-19 | AMB字段变化 | C15:586 | adc_dc_recovery:397,389,394 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-20 | 多颜色事务 | C15:587 | adc_dc_recovery:402,405 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-21 | 粗精度与精细精度联合拟合 | C15:588 | adc_dc_recovery:412,408,409 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| DCR | DCR-22 | 非NORMAL输入协议检查 | C15:589 | adc_dc_recovery:422,424 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| FFK | FFK-01 | 复位 | C16:617 | normal_transaction_fork:331,332 | A |  |
| FFK | FFK-02 | 输入握手 | C16:618 | normal_transaction_fork:336,337,338… | A |  |
| FFK | FFK-03 | measurement先消费 | C16:619 | normal_transaction_fork:349,350,352… | A |  |
| FFK | FFK-04 | tracking先消费 | C16:620 | normal_transaction_fork:371,372,374 | A |  |
| FFK | FFK-05 | 两分支同时消费 | C16:621 | normal_transaction_fork:390,394,395… | A |  |
| FFK | FFK-06 | 任一分支反压5拍 | C16:622 | normal_transaction_fork:424,426,448… | A |  |
| FFK | FFK-07 | 连续两笔事务 | C16:623 | normal_transaction_fork:409 | A |  |
| FFK | FFK-08 | MANUAL/SEARCH_HOLD模式 | C16:624 | normal_transaction_fork:468,469,471… | A |  |
| FFK | FFK-09 | STOP/复位打断 | C16:625 | normal_transaction_fork:484,489,490… | A |  |
| FIR | FIR-01 | 异步复位 | C19:607 | coarse_detection_fir:728,729,730… | A |  |
| FIR | FIR-02 | 单色前20笔 | C19:608 | coarse_detection_fir:740 | A |  |
| FIR | FIR-03 | 单色第21笔 | C19:609 | coarse_detection_fir:743 | A |  |
| FIR | FIR-04 | 常量输入 | C19:610 | coarse_detection_fir:744 | A |  |
| FIR | FIR-05 | 单位冲激 | C19:611 | coarse_detection_fir:756 | A |  |
| FIR | FIR-06 | 正负半LSB | C19:612 | coarse_detection_fir:765,772 | A |  |
| FIR | FIR-07 | signed 24-bit端点 | C19:613 | coarse_detection_fir:778,783 | A |  |
| FIR | FIR-08 | R/IR交错 | C19:614 | coarse_detection_fir:798 | A |  |
| FIR | FIR-09 | 中心元数据 | C19:615 | coarse_detection_fir:800 | A |  |
| FIR | FIR-10 | 9/15-bit交错 | C19:616 | coarse_detection_fir:801 | A |  |
| FIR | FIR-11 | 15到9无重检 | C19:617 | coarse_detection_fir:806 | A |  |
| FIR | FIR-12 | recheck pending等待 | C19:618 | coarse_detection_fir:810 | A |  |
| FIR | FIR-13 | recheck accept | C19:619 | coarse_detection_fir:815 | A |  |
| FIR | FIR-14 | 三帧重检活动 | C19:620 | coarse_detection_fir:820 | A |  |
| FIR | FIR-15 | 重检后恢复 | C19:621 | coarse_detection_fir:824,827 | A |  |
| FIR | FIR-16 | NORMAL慢速DC调码 | C19:622 | coarse_detection_fir:835 | A |  |
| FIR | FIR-17 | 未校准样本 | C19:623 | coarse_detection_fir:841 | A |  |
| FIR | FIR-18 | 上游饱和样本 | C19:624 | coarse_detection_fir:847 | A |  |
| FIR | FIR-19 | 非NORMAL输入 | C19:625 | coarse_detection_fir:855,857,858 | A |  |
| FIR | FIR-20 | 下游反压 | C19:626 | coarse_detection_fir:870 | A |  |
| FIR | FIR-21 | MAC有界反压 | C19:627 | coarse_detection_fir:880,890 | A |  |
| FIR | FIR-22 | 11次周期MAC | C19:628 | coarse_detection_fir:896,901 | A |  |
| FIR | FIR-23 | 16周期上限 | C19:629 | coarse_detection_fir:903 | A |  |
| FIR | FIR-24 | `o_fir_idle`定义 | C19:630 | coarse_detection_fir:904,907 | A |  |
| FIR | FIR-25 | START/STOP/abort | C19:631 | coarse_detection_fir:915,922,929… | A |  |
| FIR | FIR-26 | recheck接管排空 | C19:632 | coarse_detection_fir:958,963 | A |  |
| FIR | FIR-27 | 两色极值随机回归 | C19:633 | coarse_detection_fir:973 | A |  |
| FIR | FIR-28 | 频率响应 | C19:634 | coarse_detection_fir:975,976,977… | A |  |
| FIR | FIR-29 | 中心精度历史 | C19:635 | coarse_detection_fir:987,992 | A |  |
| FIR | FIR-30 | 计算保护注入 | C19:636 | coarse_detection_fir:1002 | A |  |
| FIR | FIR-31 | 独立invalid事务 | C19:637 | coarse_detection_fir:1017 | A |  |
| FIR | FIR-32 | 资格正交性 | C19:638 | coarse_detection_fir:1056 | A |  |
| FIR | FIR-33 | invalid后恢复 | C19:639 | coarse_detection_fir:1084 | A |  |
| FSC | FSC-01 | 异步复位 | C08:1134 | 400hz_frame_calibration_scheduler:596 | C | TB：复位后无在途、frame/sample为0、无协议sticky；缺完成事件与其他sticky清零 |
| FSC | FSC-02 | 新START | C08:1135 | 400hz_frame_calibration_scheduler:600 | B | TB FSC-2实测：START后恰1个启动IDAC边界；合同FSC-02的同义检查在TB的FSC-6 |
| FSC | FSC-03 | 400 Hz周期 | C08:1136 | 400hz_frame_calibration_scheduler:601 | B | TB FSC-3实测：START后首帧前无帧起点/序号/在途；合同FSC-03的同义检查在TB的FSC-14 |
| FSC | FSC-04 | 双光NORMAL | C08:1137 | 400hz_frame_calibration_scheduler:603 | B | TB FSC-4实测：首个宏帧在macro tick 0开始；合同FSC-04的同义检查在TB的FSC-5、FSC-9、FSC-50 |
| FSC | FSC-05 | 双光编号 | C08:1138 | 400hz_frame_calibration_scheduler:605 | B | TB FSC-5实测：首个波形fire在tick 0且为RED；合同FSC-05的同义检查在TB的FSC-10、FSC-11、FSC-51 |
| FSC | FSC-06 | RED-only | C08:1139 | 400hz_frame_calibration_scheduler:606 | B | TB FSC-6实测：首个owner在tick 1、RED、sample 0；合同FSC-06的同义检查在TB的FSC-16、FSC-17 |
| FSC | FSC-07 | IR-only | C08:1140 | 400hz_frame_calibration_scheduler:607 | B | TB FSC-7实测：owner快照类型NORMAL及AMB/DC码；合同FSC-07的同义检查在TB的FSC-18 |
| FSC | FSC-08 | safe-off | C08:1141 | 400hz_frame_calibration_scheduler:608 | B | TB FSC-8实测：owner快照AMB/DC epoch；合同FSC-08的同义检查在TB的FSC-19 |
| FSC | FSC-09 | SAR9上下文 | C08:1142 | 400hz_frame_calibration_scheduler:610 | B | TB FSC-9实测：第2个波形fire在tick 160且为IR；合同FSC-09的同义检查在TB的FSC-5、FSC-9、FSC-56 |
| FSC | FSC-10 | SAR15上下文 | C08:1143 | 400hz_frame_calibration_scheduler:611 | B | TB FSC-10实测：IR owner在tick 161、sample 1；合同FSC-10的同义检查在TB的FSC-20、FSC-21 |
| FSC | FSC-11 | 同帧精度 | C08:1144 | 400hz_frame_calibration_scheduler:612 | B | TB FSC-11实测：两色同frame 0、IR DC码；合同FSC-11的同义检查在TB的FSC-20 |
| FSC | FSC-12 | 精度pending | C08:1145 | 400hz_frame_calibration_scheduler:613 | B | TB FSC-12实测：波形LEDDAC快照=0x29；合同FSC-12的同义检查在TB的FSC-22 |
| FSC | FSC-13 | AMB_CAL | C08:1146 | 400hz_frame_calibration_scheduler:615 | B | TB FSC-13实测：tick 4760有IDAC边界且启动边界仍为1；合同FSC-13的同义检查在TB的FSC-23、FSC-24 |
| FSC | FSC-14 | DCS_CAL RED | C08:1147 | 400hz_frame_calibration_scheduler:618 | B | TB FSC-14实测：宏帧周期5000（容许5001）；合同FSC-14的同义检查在TB的FSC-26 |
| FSC | FSC-15 | DCS_CAL IR | C08:1148 | 400hz_frame_calibration_scheduler:619 | B | TB FSC-15实测：双光完成事件1次、下一序号2；合同FSC-15的同义检查在TB的FSC-27 |
| FSC | FSC-16 | 3200 Hz容量 | C08:1149 | 400hz_frame_calibration_scheduler:627 | B | TB FSC-16实测：RED-only：owner RED、1次波形、LEDDAC 0x17；合同FSC-16的同义检查在TB的FSC-25 |
| FSC | FSC-17 | 校准请求资格与缓冲 | C08:1150 | 400hz_frame_calibration_scheduler:629 | B | TB FSC-17实测：RED-only：tick 200前仅1次owner；合同FSC-17的同义检查在TB的FSC-49、FSC-58、FSC-59 |
| FSC | FSC-18 | IDAC子周期提交 | C08:1151 | 400hz_frame_calibration_scheduler:636 | B | TB FSC-18实测：IR-only：tick 160波形/161 owner；合同FSC-18在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-19 | 阶段超过8笔 | C08:1152 | 400hz_frame_calibration_scheduler:644 | B | TB FSC-19实测：safe-off：tick 300前无owner/波形；合同FSC-19在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-20 | 三阶段顺序 | C08:1153 | 400hz_frame_calibration_scheduler:651 | B | TB FSC-20实测：SAR15：owner与波形精度位为1；合同FSC-20在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-21 | AMB码未改变 | C08:1154 | 400hz_frame_calibration_scheduler:652 | B | TB FSC-21实测：SAR15：owner tick 161/波形tick 160；合同FSC-21在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-22 | 双光完成事件 | C08:1155 | 400hz_frame_calibration_scheduler:660 | B | TB FSC-22实测：switch_hold：无帧起点/owner/波形；合同FSC-22的同义检查在TB的FSC-15 |
| FSC | FSC-23 | 单光完成事件 | C08:1156 | 400hz_frame_calibration_scheduler:670 | B | TB FSC-23实测：AMB_CAL：owner类型AMB、SAR9、颜色0；合同FSC-23在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-24 | 校准物理完成 | C08:1157 | 400hz_frame_calibration_scheduler:671 | B | TB FSC-24实测：AMB_CAL：波形local tick 0、owner local tick 1、DC码0；合同FSC-24在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-25 | sample index增长 | C08:1158 | 400hz_frame_calibration_scheduler:673 | B | TB FSC-25实测：tick 625处校准local tick 0、子帧1；合同FSC-25的同义检查在TB的FSC-41 |
| FSC | FSC-26 | frame ID增长 | C08:1159 | 400hz_frame_calibration_scheduler:683 | B | TB FSC-26实测：DCS_CAL RED owner；合同FSC-26的同义检查在TB的FSC-55 |
| FSC | FSC-27 | 16-bit回绕 | C08:1160 | 400hz_frame_calibration_scheduler:693 | B | TB FSC-27实测：DCS_CAL IR owner；合同FSC-27在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-28 | 两上下文分离 | C08:1161 | 400hz_frame_calibration_scheduler:700 | B | TB FSC-28实测：波形上下文未ready→launch超时sticky、无owner；合同FSC-28的同义检查在TB的FSC-7、FSC-40 |
| FSC | FSC-29 | 波形接管超时 | C08:1162 | 400hz_frame_calibration_scheduler:707 | B | TB FSC-29实测：owner未ready→tick 284 RED截止超时sticky；合同FSC-29的同义检查在TB的FSC-28 |
| FSC | FSC-30 | DONE身份匹配 | C08:1163 | 400hz_frame_calibration_scheduler:715 | B | TB FSC-30实测：IR-only owner未ready→tick 444超时sticky；合同FSC-30的同义检查在TB的FSC-32 |
| FSC | FSC-31 | STOP排空 | C08:1164 | 400hz_frame_calibration_scheduler:724 | B | TB FSC-31实测：校准owner未ready→tick 260超时sticky；合同FSC-31的同义检查在TB的FSC-35、FSC-36 |
| FSC | FSC-32 | abort | C08:1165 | 400hz_frame_calibration_scheduler:734 | B | TB FSC-32实测：错误sample index DONE→mismatch sticky且仍在途；合同FSC-32的同义检查在TB的FSC-37、FSC-53 |
| FSC | FSC-33 | 诊断清除 | C08:1166 | 400hz_frame_calibration_scheduler:744 | B | TB FSC-33实测：匹配success=0 DONE释放在途；合同FSC-33的同义检查在TB的FSC-45 |
| FSC | FSC-34 | 随机ready/valid | C08:1167 | 400hz_frame_calibration_scheduler:745 | B | TB FSC-34实测：success=0不计NORMAL完成；合同FSC-34在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-35 | 长时间回归 | C08:1168 | 400hz_frame_calibration_scheduler:761 | B | TB FSC-35实测：STOP后DONE释放且无NORMAL完成；合同FSC-35在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-36 | AMI fire一致性 | C08:1169 | 400hz_frame_calibration_scheduler:762 | B | TB FSC-36实测：`!idle // owner==1`（弱断言）；合同FSC-36的同义检查在TB的FSC-42 |
| FSC | FSC-37 | owner资格反压 | C08:1170 | 400hz_frame_calibration_scheduler:773 | B | TB FSC-37实测：start_ready=0时abort→不消费序号、无在途；合同FSC-37的同义检查在TB的FSC-29 |
| FSC | FSC-38 | NORMAL IDAC边界 | C08:1171 | 400hz_frame_calibration_scheduler:780 | B | TB FSC-38实测：AMI故障阻断START后的边界/帧；合同FSC-38的同义检查在TB的FSC-13、FSC-52 |
| FSC | FSC-39 | 快速校准IDAC边界 | C08:1172 | 400hz_frame_calibration_scheduler:787 | B | TB FSC-39实测：SSW故障阻断START后的边界/帧；合同FSC-39的同义检查在TB的FSC-48 |
| FSC | FSC-40 | 边界同拍 | C08:1173 | 400hz_frame_calibration_scheduler:796 | B | TB FSC-40实测：帧内改LED码不影响当前波形快照；合同FSC-40的同义检查在TB的FSC-13 |
| FSC | FSC-41 | 生命周期门控 | C08:1174 | 400hz_frame_calibration_scheduler:797 | B | TB FSC-41实测：第2个owner sample 1、共2次提交；合同FSC-41的同义检查在TB的FSC-38、FSC-44、FSC-54 |
| FSC | FSC-42 | 校准局部tick | C08:1175 | 400hz_frame_calibration_scheduler:803 | B | TB FSC-42实测：start_fire与owner commit同拍、序号1；合同FSC-42的同义检查在TB的FSC-25 |
| FSC | FSC-43 | 校准接管间隔 | C08:1176 | 400hz_frame_calibration_scheduler:804 | B | TB FSC-43实测：`!inflight // owner==1`（弱断言）；合同FSC-43在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-44 | 迟到校准valid | C08:1177 | 400hz_frame_calibration_scheduler:819 | B | TB FSC-44实测：run_enable掉底：无新owner、宏帧自然收尾；合同FSC-44在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-45 | 校准颜色同相位 | C08:1178 | 400hz_frame_calibration_scheduler:828 | B | TB FSC-45实测：诊断清除清协议/mismatch sticky；合同FSC-45的同义检查在TB的FSC-24 |
| FSC | FSC-46 | RED独立owner | C08:1179 | 400hz_frame_calibration_scheduler:838 | B | TB FSC-46实测：复位清在途/序号/launch sticky；合同FSC-46的同义检查在TB的FSC-6、FSC-29 |
| FSC | FSC-47 | IR并行预建立 | C08:1180 | 400hz_frame_calibration_scheduler:850 | B | TB FSC-47实测：故障解除后可重新START；合同FSC-47在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-48 | RED完成后IR owner | C08:1181 | 400hz_frame_calibration_scheduler:859 | B | TB FSC-48实测：校准tick 385前产生校准IDAC边界；合同FSC-48在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-49 | IR owner截止失败 | C08:1182 | 400hz_frame_calibration_scheduler:867 | B | TB FSC-49实测：校准owner frame 0/sample 0；合同FSC-49的同义检查在TB的FSC-30 |
| FSC | FSC-50 | 校准owner截止 | C08:1183 | 400hz_frame_calibration_scheduler:874 | B | TB FSC-50实测：双光2波形2 owner且≥1 DONE；合同FSC-50的同义检查在TB的FSC-31、FSC-60、FSC-61、FSC-62 |
| FSC | FSC-51 | owner原子提交 | C08:1184 | 400hz_frame_calibration_scheduler:875 | B | TB FSC-51实测：owner与波形同frame、sample 1；合同FSC-51的同义检查在TB的FSC-42 |
| FSC | FSC-52 | 连续sample index | C08:1185 | 400hz_frame_calibration_scheduler:882 | B | TB FSC-52实测：tick 300前启动边界1次、宏帧边界0次；合同FSC-52的同义检查在TB的FSC-10、FSC-41、FSC-49 |
| FSC | FSC-53 | SAR15跨色白名单 | C08:1186 | 400hz_frame_calibration_scheduler:895 | B | TB FSC-53实测：abort后可重新START；合同FSC-53在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-54 | 真实完成链 | C08:1187 | 400hz_frame_calibration_scheduler:902 | B | TB FSC-54实测：stop_ack保持时START无边界/帧；合同FSC-54的同义检查在TB的FSC-33、FSC-34 |
| FSC | FSC-55 | START启动边界 | C08:1188 | 400hz_frame_calibration_scheduler:909 | B | TB FSC-55实测：tick 4999处safe_frame_id=current+1；合同FSC-55的同义检查在TB的FSC-2、FSC-3 |
| FSC | FSC-56 | 独立故障阻断 | C08:1189 | 400hz_frame_calibration_scheduler:916 | B | TB FSC-56实测：RED owner类型NORMAL、SAR9；合同FSC-56的同义检查在TB的FSC-38、FSC-39、FSC-47 |
| FSC | FSC-57 | SAR9跨色白名单 | C08:1190 | 400hz_frame_calibration_scheduler:922 | B | TB FSC-57实测：双光后无本地故障/协议sticky（总体健康检查）；合同FSC-57在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围） |
| FSC | FSC-58 |  | — | 400hz_frame_calibration_scheduler:946 | D | TB FSC-58：CHARACTERIZATION run_profile的合法payload请求不被接受、置协议sticky（语义属合同FSC-17） |
| FSC | FSC-59 |  | — | 400hz_frame_calibration_scheduler:964 | D | TB FSC-59：EXTERNAL_TEST_CURRENT input_source的请求不被接受、置协议sticky（语义属合同FSC-17） |
| FSC | FSC-60 |  | — | 400hz_frame_calibration_scheduler:980 | D | TB FSC-60：owner恰在local tick 248提交=按时、无截止事件（语义属合同FSC-50 V1.12补充） |
| FSC | FSC-61 |  | — | 400hz_frame_calibration_scheduler:993 | D | TB FSC-61：owner在tick 247提交、无截止事件（语义属合同FSC-50 V1.12补充） |
| FSC | FSC-62 |  | — | 400hz_frame_calibration_scheduler:1005 | D | TB FSC-62：过tick 248未提交→截止事件1拍落在248、不与提交同拍（语义属合同FSC-50 V1.12补充） |
| IDC2 | IDC2-01 | 异步复位 | C17:654 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-02 | MANUAL启动 | C17:655 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-03 | 自动启动顺序 | C17:656 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-04 | 二分搜索成功 | C17:657 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-05 | 二分搜索耗尽 | C17:658 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-06 | 反压保持 | C17:659 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-07 | 错epoch/快照 | C17:660 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-08 | 双饱和 | C17:661 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-09 | NORMAL窗口内 | C17:662 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-10 | N_CONFIRM=1 | C17:663 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-11 | N_CONFIRM=3 | C17:664 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-12 | R/IR交错 | C17:665 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-13 | 9/15-bit交错 | C17:666 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-14 | pending等待 | C17:667 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-15 | 安全提交 | C17:668 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-16 | min/max继续越界 | C17:669 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-17 | 周期AMB在窗口 | C17:670 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-18 | 周期AMB重搜改码 | C17:671 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-19 | DCS重验证 | C17:672 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-20 | 双入口冲突 | C17:673 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-21 | STOP取消pending | C17:674 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-22 | status clear | C17:675 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-23 | 安全恢复后的新START | C17:676 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDC2 | IDC2-24 | epoch回绕 | C17:677 | — | E | C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签 |
| IDT | IDT-01 | valid为0且总线变化 | C16:631 | idac_code_controller:577 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-02 | 合格窗口内样本 | C16:632 | idac_code_controller:585 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-03 | `N_CONFIRM=1` | C16:633 | idac_code_controller:591 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-04 | `N_CONFIRM=3` | C16:634 | idac_code_controller:599,602 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-05 | 越界方向反转 | C16:635 | idac_code_controller:612,615 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-06 | R/IR交错 | C16:636 | idac_code_controller:625,629 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-07 | 9/15-bit交错 | C16:637 | idac_code_controller:637 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-08 | calibration_applied为0 | C16:638 | idac_code_controller:645 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-09 | snapshot或epoch不匹配 | C16:639 | idac_code_controller:652 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-10 | saturation_high/low | C16:640 | idac_code_controller:660,666 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-11 | pending等待安全边界 | C16:641 | idac_code_controller:674,682 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-12 | 安全边界提交 | C16:642 | idac_code_controller:687,690 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-13 | min/max边界继续越界 | C16:643 | idac_code_controller:700,706 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-14 | 精度切换 | C16:644 | idac_code_controller:714 | A | C16的IDT条目由IDAC控制器单元TB承担 |
| IDT | IDT-15 | STOP/restart/error | C16:645 | idac_code_controller:722,732,744… | A | C16的IDT条目由IDAC控制器单元TB承担 |
| ILM | ILM-01 | PHOTODIODE NORMAL dual-color operation k | C25:629 | control_top_input_light_static_matrix:1399,1410,1416… | A |  |
| ILM | ILM-02 | PHOTODIODE RED_ONLY SAR9 characterizatio | C25:630 | control_top_input_light_static_matrix:1443,1459,1467… | A |  |
| ILM | ILM-03 | PHOTODIODE RED_ONLY SAR15 characterizati | C25:631 | control_top_input_light_static_matrix:1490,1507,1524… | A |  |
| ILM | ILM-04 | EXTERNAL_TEST_CURRENT BOTH SAR9 uses 400 | C25:632 | control_top_input_light_static_matrix:1662,1687,1691… | A |  |
| ILM | ILM-05 | EXTERNAL_TEST_CURRENT BOTH SAR15 preserv | C25:633 | control_top_input_light_static_matrix:1706,1731,1735… | A |  |
| ILM | ILM-06 | EXTERNAL_TEST_CURRENT RED_ONLY in fixed  | C25:634 | control_top_input_light_static_matrix:1750,1771,1774… | A |  |
| ILM | ILM-07 | EXTERNAL_TEST_CURRENT IR_ONLY in fixed S | C25:635 | control_top_input_light_static_matrix:1834,1855,1858… | A |  |
| ILM | ILM-08 | EXTERNAL_TEST_CURRENT OFF is rejected be | C25:636 | control_top_input_light_static_matrix:1919,1923,1927 | A |  |
| ILM | ILM-09 | Every non-STATIC_BIAS characterization m | C25:637 | control_top_input_light_static_matrix:1290 | A | 仅FAIL分支带编号（别名表记为半覆盖） |
| ILM | ILM-10 | After a transaction snapshot, changes to | C25:638 | control_top_input_light_static_matrix:1544,1592,1596… | A |  |
| ILM | ILM-11 | AMB_CAL uses PHOTODIODE input semantics, | C25:639 | control_top_input_light_static_matrix:2074,2082,2101… | A |  |
| ILM | ILM-12 | DCS_CAL RED/IR each use the dedicated SA | C25:640 | control_top_input_light_static_matrix:2130,2136,2139… | A |  |
| ILM | ILM-13 | Legal STATIC_BIAS establishes every froz | C25:641 | control_top_input_light_static_matrix:1938,1949,1963… | A |  |
| ILM | ILM-14 | During legal STATIC_BIAS, all five `S[4: | C25:642 | control_top_input_light_static_matrix:1966,2016,2019 | A |  |
| ILM | ILM-15 | STATIC_BIAS with an invalid input source | C25:643 | control_top_input_light_static_matrix:1373,1380,1384… | A |  |
| INJ | INJ-00 |  | — | control_top_injection:673,676 | F | TB本地：注入场景；C01第946行与别名表用它作TOP-21~24/LFA-08/PRC-08证据 |
| INJ | INJ-01 |  | — | control_top_injection:688,691,701… | F | TB本地：注入场景；C01第946行与别名表用它作TOP-21~24/LFA-08/PRC-08证据 |
| INJ | INJ-02 |  | — | control_top_injection:741,744,751…; control_top_startup_idac_calibration:986 | F | TB本地：注入场景；C01第946行与别名表用它作TOP-21~24/LFA-08/PRC-08证据 |
| INJ | INJ-03 |  | — | control_top_injection:919,953,956…; control_top_robustness_corner_waveforms:1716 | F | TB本地：注入场景；C01第946行与别名表用它作TOP-21~24/LFA-08/PRC-08证据 |
| INJ | INJ-04 |  | — | control_top_injection:996,1004,1008… | F | TB本地：注入场景；C01第946行与别名表用它作TOP-21~24/LFA-08/PRC-08证据 |
| ISE | ISE-01 | AMB/DC code, color, type, precision, and | C25:664 | control_top_idac_bus_isolation:1142,1146,1151… | A |  |
| ISE | ISE-02 | Changing any live code after capture can | C25:665 | — | E | 无独立PASS，出现在组合PASS行"ISE-01/02/03"中（别名表282行） |
| ISE | ISE-03 | The next legal waveform adopts a changed | C25:666 | control_top_idac_bus_isolation:1171,1174 | A |  |
| ISE | ISE-04 | SAR9 NORMAL/DCS drives only SAR9 AMB/DC  | C25:667 | control_top_idac_bus_isolation:777,944,955… | A |  |
| ISE | ISE-05 | SAR15 NORMAL drives only SAR15 AMB/DC bu | C25:668 | control_top_idac_bus_isolation:786,1001,1009… | A |  |
| ISE | ISE-06 | AMB_CAL drives only the SAR9 AMB candida | C25:669 | control_top_idac_bus_isolation:1051,1055,1175 | C | PASS行自注"只覆盖STATIC_BIAS子句，AMB_CAL/DCS_CAL子句另组" |
| ISE | ISE-07 | At least two non-symmetric 8-bit pattern | C25:670 | — | E | 无同名标签；别名表277/287行指向ISE-04/05的非对称码型检查 |
| ISE | ISE-08 | RED and IR committed codes, pending valu | C25:671 | control_top_idac_bus_isolation:1245,1251,1320… | A |  |
| ISE | ISE-09 | A safe boundary with no numerical code c | C25:672 | control_top_idac_bus_isolation:1449,1452 | A |  |
| ISE | ISE-10 | An actual update from epoch 4'hF wraps t | C25:673 | control_top_idac_bus_isolation:1493,1498 | A |  |
| JNT | JNT-01 |  | — | jnt_baseline_prefix:630 | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB |
| JNT | JNT-02 |  | — | jnt_baseline_prefix:635,638,645 | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB；子标签：JNT-02A、JNT-02B |
| JNT | JNT-03 |  | — | jnt_baseline_prefix:639,650,660 | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB；子标签：JNT-03A、JNT-03B |
| JNT | JNT-04 |  | — | jnt_baseline_prefix:654,663 | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB |
| JNT | JNT-05 |  | — | jnt_baseline_prefix:670,679 | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB；子标签：JNT-05A、JNT-05B |
| JNT | JNT-06 |  | — | jnt_baseline_prefix:705 | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB |
| JNT | JNT-07 |  | — | jnt_baseline_prefix:712,714,720… | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB；子标签：JNT-07A、JNT-07B、JNT-07C、JNT-07D、JNT-07E、JNT-07F |
| JNT | JNT-08 |  | — | jnt_baseline_prefix:754 | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB |
| JNT | JNT-09 |  | — | jnt_baseline_prefix:775,791 | D | 联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB |
| LFA | LFA-01 | STOP during startup search prevents new  | C25:694 | control_top_lifecycle_fault_adc_anomaly:1003,1012,1027… | A |  |
| LFA | LFA-02 | STOP during NORMAL or SAR15 prevents new | C25:695 | control_top_lifecycle_fault_adc_anomaly:1411,1418,1434… | A | 子标签：LFA-02a、LFA-02b |
| LFA | LFA-03 | STOP during tracking pending or recheck  | C25:696 | control_top_lifecycle_fault_adc_anomaly:1949,1959,1965… | A |  |
| LFA | LFA-04 | Abort after owner commit retains the min | C25:697 | control_top_lifecycle_fault_adc_anomaly:1192,1201,1209… | A |  |
| LFA | LFA-05 | Reset immediately invalidates all model  | C25:698 | control_top_lifecycle_fault_adc_anomaly:1982,1992,2008… | A |  |
| LFA | LFA-06 | An early `CLK_DOUT` before the selected  | C25:699 | control_top_lifecycle_fault_adc_anomaly:2137,2147,2151… | A |  |
| LFA | LFA-07 | A duplicate DONE for an already released | C25:700 | control_top_lifecycle_fault_adc_anomaly:1257,1284,1312… | A |  |
| LFA | LFA-08 | With protected test mode enabled, only a | C25:701 | control_top_injection:856,884,887…; control_top_startup_idac_calibration:986 | E | 无同名PASS；证据在注入TB的INJ-02名下（别名表TOP-22=LFA-08） |
| LFA | LFA-09 | RED, IR, and calibration owner-deadline  | C25:702 | control_top_lifecycle_fault_adc_anomaly:1150,1153,1157… | A |  |
| LFA | LFA-10 | AMI and SSW faults independently block n | C25:703 | control_top_lifecycle_fault_adc_anomaly:1772,1776,1780… | C | LFA-10a覆盖AMI侧；LFA-10b打印SKIP（SSW侧该构造路径结构性不可达）；子标签：LFA-10a、LFA-10b |
| LFA | LFA-11 | Diagnostic clear removes only historical | C25:704 | control_top_lifecycle_fault_adc_anomaly:1807,1810,1812… | C | LFA-11b覆盖"合法恢复后清除生效"；LFA-11a实测"supervisor自动abort释放owner期间无虚假正式结果"（属合同§9.5.1规则5/P03，同号不同义的子标签，且两个分支都打印PASS）；"活动故障在清除后继续阻断"未断言；子标签：LFA-11a、LFA-11b |
| LFA | LFA-12 | A new START after legal recovery begins  | C25:705 | control_top_lifecycle_fault_adc_anomaly:1087,1099,1104… | A | 子标签：LFA-12c |
| MGR | MGR-01 | 复位 | C02:338 | system_config_manager:178 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-02 | 非法阈值提交 | C02:339 | system_config_manager:224,238 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-03 | 合法NORMAL提交 | C02:340 | system_config_manager:248 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-04 | 合法START | C02:341 | system_config_manager:258 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-05 | RUN期COMMIT | C02:342 | system_config_manager:269 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-06 | STOP及排空 | C02:343 | system_config_manager:283,305 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-07 | 重复STOP | C02:344 | system_config_manager:293 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-08 | CONFIG期START | C02:345 | system_config_manager:319 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-09 | 标称CHARACTERIZATION提交 | C02:346 | system_config_manager:363 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-10 | START资格不足 | C02:347 | system_config_manager:374 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-11 | 命令冲突 | C02:348 | system_config_manager:386 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-12 | 配置拒绝矩阵 | C02:349 | system_config_manager:407,418,428… | C | TB覆盖0x03/0x04/0x06/0x08/0x09/0x0e/0x0f；合同列出的0x05未测（TB注释称原IDAC枚举场景已按V4.9改判0x15，即MGR-20）。0x05是否仍可达待定 |
| MGR | MGR-13 | CONFIG期STOP与事件单拍 | C02:350 | system_config_manager:537,543 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-14 | epoch回绕 | C02:351 | system_config_manager:571,577 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-15 | 非法内部状态 | C02:352 | system_config_manager:587,593 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-16 | 运行类型与初始精度组合 | C02:353 | system_config_manager:621,634,648… | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-17 | 合法组合矩阵 | C02:354 | system_config_manager:709,730 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-18 | 非法组合矩阵 | C02:355 | system_config_manager:755,767,777… | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-19 | STATIC_BIAS源资格 | C02:356 | system_config_manager:800 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-20 | 保留IDAC编码 | C02:357 | system_config_manager:812 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-21 | 校准责任边界 | C02:358 | — | E | 无标签；合同第385行要求在三模块联合TB验证；总横幅"MGR-01 through MGR-24"含此项 |
| MGR | MGR-22 | STATIC_BIAS资格输入所有权 | C02:359 | system_config_manager:837,851,864 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| MGR | MGR-23 | 固定电流光学模式资格 | C02:360 | — | E | 无同名标签；OFF返回0x16由TB的"MGR-18 fixed current optical off rejection"检查（合同MGR-18也列0x16，两条目重叠） |
| MGR | MGR-24 | 系统阻断START门 | C02:361 | system_config_manager:888,900,913 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| N08 | N08-01 |  | — | adc_measurement_idac_integration:1628 | F | TB本地：矩阵N08交接前半检查；子标签：N08-01 |
| NPA | NPA-01 |  | — | control_top:1095 | F | TB本地：Priority-1a NPA端口检查 |
| NPA | NPA-02 |  | — | control_top:1173,1179,1182… | F | TB本地：Priority-1a NPA端口检查 |
| NRE | NRE-01 | With interval zero, pending, accept, bus | C25:618 | control_top_no_recheck_control:1048,1052 | A |  |
| NRE | NRE-02 | No recheck-driven FIR-history clear, det | C25:619 | control_top_no_recheck_control:1057,1063 | A |  |
| NRE | NRE-03 | Both colors complete normal FIR warmup a | C25:620 | control_top_no_recheck_control:1068,1072,1076 | A |  |
| NRE | NRE-04 | A real baseline crossing enters SAR15, a | C25:621 | control_top_no_recheck_control:1010,1013,1016 | A |  |
| NRE | NRE-05 | The cross identity is bound to normal FI | C25:622 | control_top_no_recheck_control:1019,1022,1025 | A |  |
| NRE | NRE-06 | Long operation preserves owner/result or | C25:623 | control_top_no_recheck_control:1081,1084,1087… | A |  |
| OIB | OIB-01 | Public waveform-context backpressure cov | C25:679 | control_top_lifecycle_fault_adc_anomaly:1912; control_top_owner_identity_backpressure:1724,1743,1746… | A |  |
| OIB | OIB-02 | Public ADC-owner/AMI-start backpressure  | C25:680 | control_top_owner_identity_backpressure:1085,1088,1092… | A |  |
| OIB | OIB-03 | Public AMI formal-result backpressure ho | C25:681 | control_top_owner_identity_backpressure:1354,1358,1361… | A |  |
| OIB | OIB-04 | Legal public lifecycle and downstream co | C25:682 | — | E | 别名表165/172-175行：结构性满足、无独立PASS |
| OIB | OIB-05 | Across all induced stalls, each committe | C25:683 | control_top_owner_identity_backpressure:1700,1704 | A |  |
| OIB | OIB-06 | Accepted transactions and results preser | C25:684 | control_top_owner_identity_backpressure:1873,1876,1879 | A |  |
| OIB | OIB-07 | Completion/result identity matches frame | C25:685 | control_top_owner_identity_backpressure:1650,1670,1676… | A |  |
| OIB | OIB-08 | A matching `success=0` completion releas | C25:686 | control_top_owner_identity_backpressure:1470,1479,1487… | A |  |
| OIB | OIB-09 | A transaction accepted before a legal di | C25:687 | control_top_owner_identity_backpressure:1572,1589,1607… | A |  |
| OIB | OIB-10 | Static ready/valid analysis and dynamic  | C25:688 | — | E | 别名表165/172-173行：静态分析+结构性满足 |
| OPT | OPT-01 | signed 24-bit最大合法峰谷幅度 | C21:567 | dynamic_baseline_cross_detector:1079 | A |  |
| OPT | OPT-02 | `T=1` | C21:568 | dynamic_baseline_cross_detector:1080 | A |  |
| OPT | OPT-03 | 最大合法短周期`T=16'h7fff` | C21:569 | dynamic_baseline_cross_detector:1083 | A |  |
| OPT | OPT-04 | 除法半LSB边界 | C21:570 | dynamic_baseline_cross_detector:1086 | A |  |
| OPT | OPT-05 | 最大正平滑差值 | C21:571 | dynamic_baseline_cross_detector:1103 | A |  |
| OPT | OPT-06 | 最大负平滑差值 | C21:572 | dynamic_baseline_cross_detector:1120 | A |  |
| OPT | OPT-07 | 最大合法调整比例 | C21:573 | dynamic_baseline_cross_detector:1134 | A |  |
| OPT | OPT-08 | 候选低于最负边界 | C21:574 | dynamic_baseline_cross_detector:1121 | A |  |
| OPT | OPT-09 | 候选高于近零边界 | C21:575 | dynamic_baseline_cross_detector:1147 | A |  |
| OPT | OPT-10 | 波峰valid在busy期间保持 | C21:576 | dynamic_baseline_cross_detector:1158 | A |  |
| OPT | OPT-11 | 算术完成后的波峰握手 | C21:577 | dynamic_baseline_cross_detector:1170 | A |  |
| OPT | OPT-12 | busy期间FIR事务到达 | C21:578 | dynamic_baseline_cross_detector:1175 | A |  |
| OPT | OPT-13 | busy期间波谷事件到达 | C21:579 | dynamic_baseline_cross_detector:1176 | A |  |
| OPT | OPT-14 | 每个FSM阶段触发STOP | C21:580 | dynamic_baseline_cross_detector:1182 | A |  |
| OPT | OPT-15 | 每个FSM阶段触发abort | C21:581 | dynamic_baseline_cross_detector:1188 | A |  |
| OPT | OPT-16 | 每个FSM阶段触发重检接管 | C21:582 | dynamic_baseline_cross_detector:1194 | A |  |
| OPT | OPT-17 | busy期间异步复位 | C21:583 | dynamic_baseline_cross_detector:1206 | A |  |
| OPT | OPT-18 | 分母异常为0 | C21:584 | dynamic_baseline_cross_detector:1217 | A |  |
| OPT | OPT-19 | 人工制造超过128周期 | C21:585 | dynamic_baseline_cross_detector:1228 | A |  |
| OPT | OPT-20 | pending epoch变化 | C21:586 | dynamic_baseline_cross_detector:1246 | A |  |
| OPT | OPT-21 | 第一个波峰即时路径 | C21:587 | dynamic_baseline_cross_detector:1260 | A |  |
| OPT | OPT-22 | FIXED_SPI即时路径 | C21:588 | dynamic_baseline_cross_detector:1277 | A |  |
| OPT | OPT-23 | 连续两个完整周期 | C21:589 | dynamic_baseline_cross_detector:1282 | A |  |
| OPT | OPT-24 | 优化前后随机差分 | C21:590 | dynamic_baseline_cross_detector:1303 | A |  |
| OPTC | OPTC-01 |  | — | dynamic_baseline_cross_detector:1304 | D | C21只定义OPT-01~24；OPTC-01/02（共享乘法器）未登记 |
| OPTC | OPTC-02 |  | — | dynamic_baseline_cross_detector:1305 | D | C21只定义OPT-01~24；OPTC-01/02（共享乘法器）未登记 |
| OVL | OVL-01 |  | — | adc_pipeline_overlap_corrector:385,394,356 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-02 |  | — | adc_pipeline_overlap_corrector:412,398 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-03 |  | — | adc_pipeline_overlap_corrector:417 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-04 |  | — | adc_pipeline_overlap_corrector:428 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-05 |  | — | adc_pipeline_overlap_corrector:438 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-06 |  | — | adc_pipeline_overlap_corrector:448 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-07 |  | — | adc_pipeline_overlap_corrector:458 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-08 |  | — | adc_pipeline_overlap_corrector:475 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-09 |  | — | adc_pipeline_overlap_corrector:490 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-10 |  | — | adc_pipeline_overlap_corrector:506,512,501 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-11 |  | — | adc_pipeline_overlap_corrector:560,527 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-12 |  | — | adc_pipeline_overlap_corrector:523,582,574 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-13 |  | — | adc_pipeline_overlap_corrector:586 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-14 |  | — | adc_pipeline_overlap_corrector:606 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-15 |  | — | adc_pipeline_overlap_corrector:658,617 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-16 |  | — | adc_pipeline_overlap_corrector:708,715,725… | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| OVL | OVL-17 |  | — | adc_pipeline_overlap_corrector:679,694,663 | D | C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17 |
| PC | PC-01 | waveform通道13个端口逐位对应 | 核对表:393 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-02 | waveform fire只由scheduler valid与SSW ready | 核对表:394 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-03 | waveform fire不消费sample index | 核对表:395 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-04 | ADC transaction通道12个端口逐位对应 | 核对表:396 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-05 | AMI fire严格等于transaction valid与ready | 核对表:397 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-06 | owner commit与AMI真实fire同拍 | 核对表:398 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-07 | owner载荷与AMI事务载荷逐位相同 | 核对表:399 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-08 | sample index只在真实fire绑定并递增 | 核对表:400 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-09 | AMI完成三元组同源、同拍扇出到scheduler和SSW | 核对表:401 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-10 | 匹配`success=0`只释放owner、不形成结果 | 核对表:402 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-11 | START子类型边界和实际IDAC边界不重复连接 | 核对表:403 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-12 | AMI fault与SSW fault独立、高有效接入scheduler | 核对表:404 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-13 | scheduler本地fault不反馈形成组合环 | 核对表:405 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-14 | `o_analog_safe`和`o_sar_timing_idle`来源唯一 | 核对表:406 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-15 | 三模块`i_adc_idle`使用同一物理ADC/DONE空闲事实 | 核对表:407 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-16 | 公共参数宽度和编码完全一致 | 核对表:408 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-17 | 不存在valid/ready/fire组合反馈环 | 核对表:409 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-18 | Q3、固定延时和波形末沿不能伪造DONE | 核对表:410 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-19 | 当前V1.2旧单fire RTL不得作为兼容实现保留 | 核对表:411 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-20 | `analog_run_enable`仅接SSW且高有效 | 核对表:412 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-21 | `measurement_run_enable`仅接Scheduler/AMI且 | 核对表:413 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PC | PC-22 | STATIC_BIAS下测量START和新事务许可为0 | 核对表:414 | — | N/A | 核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID |
| PR | PR-01 | 复位 | C14:329 | adc_programmable_reconstructor:319,386 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-02 | NORMAL 9-bit | C14:330 | adc_programmable_reconstructor:324 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-03 | 标称15-bit | C14:331 | adc_programmable_reconstructor:326 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-04 | Stage2增益变化 | C14:332 | adc_programmable_reconstructor:333,328,330 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-05 | 加性offset正负变化 | C14:333 | adc_programmable_reconstructor:336,337 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-06 | 正负半LSB边界 | C14:334 | adc_programmable_reconstructor:339,340 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-07 | 15-bit上下饱和 | C14:335 | adc_programmable_reconstructor:342,343 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-08 | 全部1024个S2码 | C14:336 | adc_programmable_reconstructor:353,347 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-09 | 输出反压 | C14:337 | adc_programmable_reconstructor:363,357 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-10 | 同拍消费替换 | C14:338 | adc_programmable_reconstructor:368 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-11 | 系数资格组合 | C14:339 | adc_programmable_reconstructor:370,371,372… | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-12 | epoch回绕 | C14:340 | adc_programmable_reconstructor:375,376 | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PR | PR-13 | 有效期间改变配置输入 | C14:341 | — | E | 只出现在组合标签"PR-09/13"中 |
| PR | PR-14 | 9/15/9/15连续切换 | C14:342 | adc_programmable_reconstructor:378,379,380… | A | 仅FAIL分支带编号，PASS只有总横幅 |
| PRC | PRC-01 | A flat or no-pulse deterministic input p | C25:711 | control_top_robustness_corner_waveforms:1371,1374,1377… | A |  |
| PRC | PRC-02 | A below-threshold low-amplitude pulse re | C25:712 | control_top_robustness_corner_waveforms:1394,1397,1400 | A |  |
| PRC | PRC-03 | A high-amplitude or clamped input assert | C25:713 | control_top_robustness_corner_waveforms:1412,1415,1418… | A |  |
| PRC | PRC-04 | Strong bounded baseline drift follows th | C25:714 | control_top_robustness_corner_waveforms:1451,1454,1457… | A | 子标签：PRC-04b |
| PRC | PRC-05 | Every deterministic noise schedule remai | C25:715 | control_top_robustness_corner_waveforms:1711 | C | PASS行是无条件$display引用RGC-06证据，本TB不做比较 |
| PRC | PRC-06 | Fast and slow legal pulse periods satisf | C25:716 | control_top_robustness_corner_waveforms:1542,1545,1548… | A | 子标签：PRC-06a、PRC-06b、PRC-06c |
| PRC | PRC-07 | Weak or missing dicrotic-notch profiles  | C25:717 | control_top_robustness_corner_waveforms:1609,1612,1615 | A |  |
| PRC | PRC-08 | With protected test mode enabled, an exp | C25:718 | control_top_injection:986; control_top_robustness_corner_waveforms:1716 | C | PASS行是无条件$display引用INJ-03证据，本TB不做比较 |
| PRC | PRC-09 | A calibration-qualification-loss sample  | C25:719 | control_top_robustness_corner_waveforms:1668,1685,1688… | A |  |
| PRC | PRC-10 | After invalid or unqualified samples, la | C25:720 | control_top_robustness_corner_waveforms:1697,1700 | A |  |
| PVW | PVW-01 | 异步复位 | C22:801 | peak_valley_window_detector:537 | A |  |
| PVW | PVW-02 | 新START | C22:802 | peak_valley_window_detector:539 | A |  |
| PVW | PVW-03 | 首个可靠波峰 | C22:803 | peak_valley_window_detector:541 | A |  |
| PVW | PVW-04 | 波峰连续3点下降 | C22:804 | peak_valley_window_detector:542 | A |  |
| PVW | PVW-05 | 相同最大值平台 | C22:805 | peak_valley_window_detector:553 | A |  |
| PVW | PVW-06 | 波峰死区平坦 | C22:806 | peak_valley_window_detector:563 | A |  |
| PVW | PVW-07 | 波峰反方向 | C22:807 | peak_valley_window_detector:574 | A |  |
| PVW | PVW-08 | 峰峰时间不足 | C22:808 | peak_valley_window_detector:589 | A |  |
| PVW | PVW-09 | 合格峰峰时间 | C22:809 | peak_valley_window_detector:598,617 | A |  |
| PVW | PVW-10 | 波谷连续3点上升 | C22:810 | peak_valley_window_detector:645 | A |  |
| PVW | PVW-11 | 相同最小值平台 | C22:811 | peak_valley_window_detector:657 | A |  |
| PVW | PVW-12 | 波谷死区平坦 | C22:812 | peak_valley_window_detector:670 | A |  |
| PVW | PVW-13 | 波谷反方向 | C22:813 | peak_valley_window_detector:685 | A |  |
| PVW | PVW-14 | 峰谷幅度不足 | C22:814 | peak_valley_window_detector:701 | A |  |
| PVW | PVW-15 | 峰谷时间不足 | C22:815 | peak_valley_window_detector:714 | A |  |
| PVW | PVW-16 | 合格峰谷 | C22:816 | peak_valley_window_detector:721 | A |  |
| PVW | PVW-17 | FIR群延时 | C22:817 | peak_valley_window_detector:726 | A |  |
| PVW | PVW-18 | IR交错 | C22:818 | peak_valley_window_detector:735 | A |  |
| PVW | PVW-19 | 无效或饱和RED | C22:819 | peak_valley_window_detector:746 | A |  |
| PVW | PVW-20 | 非预期跳帧 | C22:820 | peak_valley_window_detector:754 | A |  |
| PVW | PVW-21 | 9/15-bit普通切换 | C22:821 | peak_valley_window_detector:767 | A |  |
| PVW | PVW-22 | 正式fine start | C22:822 | peak_valley_window_detector:776 | A |  |
| PVW | PVW-23 | 手动15-bit无start | C22:823 | peak_valley_window_detector:784 | A |  |
| PVW | PVW-24 | 谷值返回请求 | C22:824 | peak_valley_window_detector:804 | A |  |
| PVW | PVW-25 | fine窗口超时 | C22:825 | peak_valley_window_detector:815 | A |  |
| PVW | PVW-26 | 重新获取超时 | C22:826 | peak_valley_window_detector:824 | A |  |
| PVW | PVW-27 | 超时后重新获取成功 | C22:827 | peak_valley_window_detector:833 | A |  |
| PVW | PVW-28 | 峰值反压 | C22:828 | peak_valley_window_detector:840 | A |  |
| PVW | PVW-29 | 谷值反压 | C22:829 | peak_valley_window_detector:849 | A |  |
| PVW | PVW-30 | 返回请求反压 | C22:830 | peak_valley_window_detector:859 | A |  |
| PVW | PVW-31 | epoch不一致 | C22:831 | peak_valley_window_detector:872 | A |  |
| PVW | PVW-32 | recheck pending | C22:832 | peak_valley_window_detector:880,884 | A |  |
| PVW | PVW-33 | recheck安全接管 | C22:833 | peak_valley_window_detector:890,895 | A |  |
| PVW | PVW-34 | recheck accept | C22:834 | peak_valley_window_detector:909 | A |  |
| PVW | PVW-35 | STOP | C22:835 | peak_valley_window_detector:920 | A |  |
| PVW | PVW-36 | abort | C22:836 | peak_valley_window_detector:933 | A |  |
| PVW | PVW-37 | sticky清除 | C22:837 | peak_valley_window_detector:960 | A |  |
| PVW | PVW-38 | 非法ACTIVE | C22:838 | peak_valley_window_detector:970 | A |  |
| PVW | PVW-39 | frame_id半回绕 | C22:839 | peak_valley_window_detector:638,976 | A |  |
| PVW | PVW-40 | 随机宽位回归 | C22:840 | peak_valley_window_detector:1024 | A |  |
| PVW | PVW-41 | 9-bit峰后长期无谷 | C22:841 | peak_valley_window_detector:1033 | A |  |
| PVW | PVW-42 | 进入15-bit流水尾部 | C22:842 | peak_valley_window_detector:1044 | A |  |
| PVW | PVW-43 | fine起点前中心样本 | C22:843 | peak_valley_window_detector:1057 | A |  |
| PVW | PVW-44 | fine波峰资格 | C22:844 | peak_valley_window_detector:1091 | A |  |
| PVW | PVW-45 | 返回9-bit流水尾部 | C22:845 | peak_valley_window_detector:1111 | A |  |
| PVW | PVW-46 | 被动退出尾部允许重检接管 | C22:846 | peak_valley_window_detector:1151 | A |  |
| PVW | PVW-47 | （2026-09-17新增） | C22:847 | peak_valley_window_detector:1161,1165 | A |  |
| PVW | PVW-48 | （2026-09-17新增） | C22:848 | peak_valley_window_detector:1175,1178 | A |  |
| PWC | PWC-01 | 异步复位 | C23:914 | precision_window_controller:413 | A |  |
| PWC | PWC-02 | NORMAL合法START | C23:915 | precision_window_controller:417 | A |  |
| PWC | PWC-03 | NORMAL非法初始15-bit | C23:916 | precision_window_controller:425 | A |  |
| PWC | PWC-04 | CHARACTERIZATION 9-bit | C23:917 | precision_window_controller:430,435,439 | A |  |
| PWC | PWC-05 | CHARACTERIZATION 15-bit | C23:918 | precision_window_controller:444 | A |  |
| PWC | PWC-06 | 启动校准期间cross | C23:919 | precision_window_controller:451 | A |  |
| PWC | PWC-07 | cross反压 | C23:920 | precision_window_controller:463 | A |  |
| PWC | PWC-08 | cross握手 | C23:921 | precision_window_controller:470 | A |  |
| PWC | PWC-09 | 下一安全帧进入 | C23:922 | precision_window_controller:473 | A |  |
| PWC | PWC-10 | 进入frame_id | C23:923 | precision_window_controller:475 | A |  |
| PWC | PWC-11 | 模式提交原子性 | C23:924 | precision_window_controller:477 | A |  |
| PWC | PWC-12 | unknown相交 | C23:925 | precision_window_controller:483 | A |  |
| PWC | PWC-13 | fine期间第二cross | C23:926 | precision_window_controller:489 | A |  |
| PWC | PWC-14 | return反压 | C23:927 | precision_window_controller:501 | A |  |
| PWC | PWC-15 | VALLEY正常返回 | C23:928 | precision_window_controller:505,507 | A |  |
| PWC | PWC-16 | FINE timeout返回 | C23:929 | precision_window_controller:515 | A |  |
| PWC | PWC-17 | protocol fallback返回 | C23:930 | precision_window_controller:523 | A |  |
| PWC | PWC-18 | RESERVED返回原因 | C23:931 | precision_window_controller:529 | A |  |
| PWC | PWC-19 | 返回frame_id | C23:932 | precision_window_controller:532 | A |  |
| PWC | PWC-20 | AMB pending | C23:933 | precision_window_controller:539 | A |  |
| PWC | PWC-21 | recheck busy | C23:934 | precision_window_controller:546 | A |  |
| PWC | PWC-22 | 普通切换连续性 | C23:935 | precision_window_controller:552 | A |  |
| PWC | PWC-23 | 等待安全边界 | C23:936 | precision_window_controller:560 | A |  |
| PWC | PWC-24 | 10000周期前提交 | C23:937 | precision_window_controller:566 | A |  |
| PWC | PWC-25 | 安全与阈值同拍 | C23:938 | precision_window_controller:572 | A |  |
| PWC | PWC-26 | 切换超时 | C23:939 | precision_window_controller:586,587 | A |  |
| PWC | PWC-27 | pending期间STOP | C23:940 | precision_window_controller:599 | A |  |
| PWC | PWC-28 | pending期间abort | C23:941 | precision_window_controller:618 | A |  |
| PWC | PWC-29 | pending期间复位 | C23:942 | precision_window_controller:628 | A |  |
| PWC | PWC-30 | cross和return同拍 | C23:943 | precision_window_controller:638 | A |  |
| PWC | PWC-31 | 重复同向请求 | C23:944 | precision_window_controller:646 | A |  |
| PWC | PWC-32 | 异常返回加重检pending | C23:945 | precision_window_controller:656 | A |  |
| PWC | PWC-33 | STOP不清sticky | C23:946 | precision_window_controller:672 | A |  |
| PWC | PWC-34 | diagnostic clear | C23:947 | precision_window_controller:684,685 | A |  |
| PWC | PWC-35 | controller idle | C23:948 | precision_window_controller:691,693 | A |  |
| PWC | PWC-36 | R/IR同帧 | C23:949 | precision_window_controller:700 | A |  |
| PWC | PWC-37 | 进入15-bit历史尾部 | C23:950 | precision_window_controller:704 | A |  |
| PWC | PWC-38 | 返回9-bit历史尾部 | C23:951 | precision_window_controller:709 | A |  |
| PWC | PWC-39 | 尾部不计切换超时 | C23:952 | precision_window_controller:714 | A |  |
| PWC | PWC-40 | V5正式检测门控 | C23:953 | precision_window_controller:734 | A |  |
| PWC | PWC-41 | START不清sticky（2026-09-17新增） | C23:954 | precision_window_controller:746,758 | A |  |
| PWI | PWI-01 | 进入尾部责任分离 | C23:963; C18:639 | precision_window_integration:746 | A |  |
| PWI | PWI-02 | 退出尾部禁止新cross | C23:964; C18:640 | precision_window_integration:769 | A |  |
| PWI | PWI-03 | AMB接管被动尾部 | C23:965; C18:641 | precision_window_integration:816 | A |  |
| PWI | PWI-04 | AMB接管真实事务 | C23:966; C18:642 | precision_window_integration:809 | A |  |
| PWI | PWI-05 | 重检原子清理 | C23:967; C18:643 | precision_window_integration:837 | A |  |
| PWI | PWI-06 | invalid检测隔离 | C18:644 | — | E | PWI单元TB只有PWI-01~05；C18第659行却写"xsim中PWI-01至PWI-07全部真实比较PASS"（合同自述超出TB） |
| PWI | PWI-07 | invalid后合法恢复 | C18:645 | — | E | 同PWI-06 |
| PWI | PWI-08 | V5有效资格扇出 | C18:646 | — | E | 别名表89行：随Acceptance-D01-01登记 |
| RAW | RAW-01 | RED and IR each produce one `PHOTODIODE` | C25:398 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-02 | A trace demonstrates a fast rise, slow d | C25:399 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-03 | The deterministic noise sequence has the | C25:400 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-04 | The code is explicitly clamped at the se | C25:401 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-05 | No `CLK_DOUT` occurs before the selected | C25:402 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-06 | `CLK_DOUT` enters the real AMI async cap | C25:403 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-07 | Completion occurs only after AMI capture | C25:404 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-08 | IR waveform preparation can precede RED  | C25:405 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-09 | SAR9/SAR15 conversion retains the same c | C25:406 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-10 | Abort permits only the matching old-owne | C25:407 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-11 | Missing owner commitment, owner timeout, | C25:408 | — | E | 无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照） |
| RAW | RAW-12 | A post-START run covers at least 10 seco | C25:409 | tb_diag_algo_probe:799,803,806…; control_top_longrun:785,789,792… | A |  |
| RAW | RAW-13 | The guard is a `time`-typed 12-second wa | C25:410 | tb_diag_algo_probe:821,824; control_top_longrun:807,810 | A |  |
| RGC | RGC-01 |  | — | real_raw_generator_selfcheck:85,87 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-02 |  | — | real_raw_generator_selfcheck:91,93 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-03 |  | — | real_raw_generator_selfcheck:125,127 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-04 |  | — | real_raw_generator_selfcheck:153,155 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-05 |  | — | real_raw_generator_selfcheck:179,181 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-06 |  | — | control_top_robustness_corner_waveforms:1711; real_raw_generator_selfcheck:208,210 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-07 |  | — | real_raw_generator_selfcheck:226,228 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-08 |  | — | real_raw_generator_selfcheck:258,260 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-09 |  | — | real_raw_generator_selfcheck:288,290 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-10 |  | — | real_raw_generator_selfcheck:316,318 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-11 |  | — | real_raw_generator_selfcheck:338,340 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-12 |  | — | real_raw_generator_selfcheck:372,374 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-13 |  | — | real_raw_generator_selfcheck:405,407 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-14 |  | — | real_raw_generator_selfcheck:439,441 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RGC | RGC-15 |  | — | real_raw_generator_selfcheck:471,473 | F | TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记 |
| RRC | RRC-01 | The interval counter advances once per c | C25:601 | control_top_periodic_recheck_recovery:1068,1071 | A |  |
| RRC | RRC-02 | Recheck pending during SAR15 cannot star | C25:602 | control_top_periodic_recheck_recovery:1061,1075,1080… | A |  |
| RRC | RRC-03 | Accept remains low until ADC, NORMAL for | C25:603 | control_top_periodic_recheck_recovery:1109,1113,1116 | A |  |
| RRC | RRC-04 | Accept atomically invalidates both FIR h | C25:604 | control_top_periodic_recheck_recovery:1138,1151,1165 | A |  |
| RRC | RRC-05 | The active sequence is exactly AMB, DC_R | C25:605 | control_top_periodic_recheck_recovery:1171,1174 | A |  |
| RRC | RRC-06 | An in-window unchanged AMB code preserve | C25:606 | control_top_periodic_recheck_recovery:1177,1180 | A |  |
| RRC | RRC-07 | An actual AMB, DC_R, or DC_IR change occ | C25:607 | control_top_periodic_recheck_recovery:1333,1342,1347… | A |  |
| RRC | RRC-08 | From accept through successful or failed | C25:608 | control_top_periodic_recheck_recovery:1185,1188 | A |  |
| RRC | RRC-09 | After success, the latest reliable peak  | C25:609 | control_top_periodic_recheck_recovery:1194,1197,1220… | A |  |
| RRC | RRC-10 | After successful re-warmup, a new upward | C25:610 | control_top_periodic_recheck_recovery:1244,1247 | A |  |
| RRC | RRC-11 | A failed AMB/DC stage preserves the cont | C25:611 | control_top_periodic_recheck_recovery:1342,1362,1372… | A |  |
| RRC | RRC-12 | STOP or abort clears pending/active rech | C25:612 | control_top_periodic_recheck_recovery:1459,1477,1485… | A |  |
| RTR | RTR-01 | 复位 | C12:185 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-02 | 无输入事务 | C12:186 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-03 | AMB_CAL | C12:187 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-04 | DCS_CAL反压 | C12:188 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-05 | 红光/红外DCS交错 | C12:189 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-06 | NORMAL 9-bit | C12:190 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-07 | NORMAL 15-bit | C12:191 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-08 | signed边界 | C12:192 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-09 | 校准资格与epoch独立 | C12:193 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-10 | 饱和标志 | C12:194 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-11 | 连续类别切换 | C12:195 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-12 | 非法类别11 | C12:196 | — | A | 编号只在代码注释里，日志只有总横幅 |
| RTR | RTR-13 | 反压期间复位 | C12:197 | — | A | 编号只在代码注释里，日志只有总横幅 |
| SID | SID-01 | START creates exactly one startup IDAC s | C25:549 | control_top_startup_idac_calibration:894,899,902 | A |  |
| SID | SID-02 | Automatic startup requests and accepted  | C25:550 | control_top_startup_idac_calibration:1084,1087 | A |  |
| SID | SID-03 | AMB_CAL, DCS_CAL RED, and DCS_CAL IR eac | C25:551 | control_top_startup_idac_calibration:1134,1269,1390 | A | 仅FAIL分支带编号 |
| SID | SID-04 | Every evaluated candidate uses eight phy | C25:552 | control_top_startup_idac_calibration:1129,1151,1178… | A |  |
| SID | SID-05 | Each calibration ADC owner commits no la | C25:553 | control_top_startup_idac_calibration:1114,1116,1121… | A |  |
| SID | SID-06 | Candidate, confirmed AMB code, color, ty | C25:554 | control_top_startup_idac_calibration:1284,1287,1308… | A |  |
| SID | SID-07 | AMB_CAL follows its dedicated netlist wa | C25:555 | control_top_startup_idac_calibration:1144 | A | 仅FAIL分支带编号 |
| SID | SID-08 | DCS_CAL RED follows its dedicated netlis | C25:556 | control_top_startup_idac_calibration:1250,1258,1261… | A |  |
| SID | SID-09 | DCS_CAL IR follows its dedicated netlist | C25:557 | control_top_startup_idac_calibration:1377,1382,1385 | A |  |
| SID | SID-10 | Exactly eight matching successful result | C25:558 | control_top_startup_idac_calibration:953,959,966… | A |  |
| SID | SID-11 | A double-saturated or otherwise ineligib | C25:559 | control_top_startup_idac_calibration:1027,1033,1049… | A |  |
| SID | SID-12 | Successful AMB/DC_R/DC_IR closure assert | C25:560 | control_top_startup_idac_calibration:1423,1426,1442… | A |  |
| SMOKE | SMOKE-01 |  | — | control_top:1144,1147 | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-02 |  | — | control_top:1190,1193 | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-03 |  | — | control_top:1223,1226 | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-04 |  | — | control_top:1236,1239,1242 | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-05 |  | — | control_top:1260,1286,1293… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-06 |  | — | control_top:1334,1337,1356… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-07 |  | — | control_top:1436,1439,1454… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-08 |  | — | control_top:1510,1513,1531… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-09 |  | — | control_top:1611,1614,1632… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-10 |  | — | control_top:1699,1721,1724… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-11 |  | — | control_top:1757,1761,1778… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-12 |  | — | control_top:1807,1810,1838… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-13 |  | — | control_top:1903,1906,1933… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-14 |  | — | control_top:2010,2013,2037… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-15 |  | — | control_top:2091,2094,2114… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-16 |  | — | control_top:2196,2199,2217… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-17 |  | — | control_top:2275,2278,2313… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-18 |  | — | control_top:2393,2396,2405… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-19 |  | — | control_top:2494,2497,2509… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-20 |  | — | control_top:2657,2661 | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-21 |  | — | control_top:2713,2717,2741… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-22 |  | — | control_top:2826,2830 | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SMOKE | SMOKE-23 |  | — | control_top:2857,2860,2918… | F | TB本地：顶层冒烟场景；C01第942行用它作TOP证据 |
| SSW | SSW-01 | NORMAL SAR9 RED | C09:818 | sar9_sar15_safe_selection_wrapper:465,478 | A |  |
| SSW | SSW-02 | NORMAL SAR15 RED | C09:819 | sar9_sar15_safe_selection_wrapper:480,491 | A |  |
| SSW | SSW-03 | NORMAL SAR9 IR | C09:820 | sar9_sar15_safe_selection_wrapper:493,504 | A |  |
| SSW | SSW-04 | NORMAL SAR15 IR | C09:821 | sar9_sar15_safe_selection_wrapper:506,517 | A |  |
| SSW | SSW-05 | SAR9/SAR15 Q3对齐 | C09:822 | sar9_sar15_safe_selection_wrapper:519,534 | A |  |
| SSW | SSW-06 | 单光RED | C09:823 | sar9_sar15_safe_selection_wrapper:536,553 | A |  |
| SSW | SSW-07 | 单光IR | C09:824 | sar9_sar15_safe_selection_wrapper:555,572 | A |  |
| SSW | SSW-08 | AMB_CAL | C09:825 | sar9_sar15_safe_selection_wrapper:574,588 | A |  |
| SSW | SSW-09 | DCS_CAL RED | C09:826 | sar9_sar15_safe_selection_wrapper:590,602 | A |  |
| SSW | SSW-10 | DCS_CAL IR | C09:827 | sar9_sar15_safe_selection_wrapper:604,616 | A |  |
| SSW | SSW-11 | 8个校准子帧 | C09:828 | sar9_sar15_safe_selection_wrapper:618,635 | C | 查每个子帧Q3在local tick 266、AMB_CAL不驱动Q2；local tick由TB直接驱动，625周期间隔未实测 |
| SSW | SSW-12 | 候选码更新 | C09:829 | sar9_sar15_safe_selection_wrapper:637,646 | A |  |
| SSW | SSW-13 | 预热中改码 | C09:830 | sar9_sar15_safe_selection_wrapper:648,658 | A |  |
| SSW | SSW-14 | 迟到波形接管 | C09:831 | sar9_sar15_safe_selection_wrapper:660,667 | A |  |
| SSW | SSW-15 | AMI反压 | C09:832 | sar9_sar15_safe_selection_wrapper:669,678 | A |  |
| SSW | SSW-16 | ADC完成匹配 | C09:833 | sar9_sar15_safe_selection_wrapper:680,693 | A |  |
| SSW | SSW-17 | ADC完成错配 | C09:834 | sar9_sar15_safe_selection_wrapper:695,703 | A |  |
| SSW | SSW-18 | 校准完成超时 | C09:835 | sar9_sar15_safe_selection_wrapper:705,711 | B | TB SSW-18实测"校准owner缺失在tick 249前超时"（属合同SSW-37/38）；合同SSW-18"tick 385前未准备下一码终止burst"无同义检查 |
| SSW | SSW-19 | SAR9到SAR15 | C09:836 | sar9_sar15_safe_selection_wrapper:713,723 | A |  |
| SSW | SSW-20 | SAR15到SAR9 | C09:837 | sar9_sar15_safe_selection_wrapper:725,735 | A |  |
| SSW | SSW-21 | STOP | C09:838 | sar9_sar15_safe_selection_wrapper:737,747 | A |  |
| SSW | SSW-22 | abort | C09:839 | sar9_sar15_safe_selection_wrapper:749,759 | A |  |
| SSW | SSW-23 | reset | C09:840 | sar9_sar15_safe_selection_wrapper:761,768 | A |  |
| SSW | SSW-24 | 固定电流SAR9表征 | C09:841 | sar9_sar15_safe_selection_wrapper:770,778 | C | 只测一种光学模式；RED_ONLY/IR_ONLY/OFF未逐一构造 |
| SSW | SSW-25 | `o_clk_2m` | C09:842 | sar9_sar15_safe_selection_wrapper:780,783 | A |  |
| SSW | SSW-26 | AMB逐窗口 | C09:843 | sar9_sar15_safe_selection_wrapper:785,798 | A |  |
| SSW | SSW-27 | AMB候选码窗口 | C09:844 | sar9_sar15_safe_selection_wrapper:800,807 | A |  |
| SSW | SSW-28 | AMB输入边界 | C09:845 | sar9_sar15_safe_selection_wrapper:809,816 | A |  |
| SSW | SSW-29 | 固定电流SAR15表征 | C09:846 | sar9_sar15_safe_selection_wrapper:818,826 | C | 同SSW-24，只测一种模式 |
| SSW | SSW-30 | STATIC_BIAS向量 | C09:847 | sar9_sar15_safe_selection_wrapper:828,836 | A |  |
| SSW | SSW-31 | STATIC_BIAS MUX | C09:848 | sar9_sar15_safe_selection_wrapper:838,846 | A |  |
| SSW | SSW-32 | 表征CDC隔离 | C09:849 | sar9_sar15_safe_selection_wrapper:848,855 | A |  |
| SSW | SSW-33 | 两通道分离 | C09:850 | sar9_sar15_safe_selection_wrapper:857,865 | A |  |
| SSW | SSW-34 | 双波形上下文 | C09:851 | sar9_sar15_safe_selection_wrapper:867,877 | A |  |
| SSW | SSW-35 | RED owner截止 | C09:852 | sar9_sar15_safe_selection_wrapper:879,884 | A |  |
| SSW | SSW-36 | IR owner截止 | C09:853 | sar9_sar15_safe_selection_wrapper:886,892 | A |  |
| SSW | SSW-37 | CAL owner截止 | C09:854 | sar9_sar15_safe_selection_wrapper:894,899 | A |  |
| SSW | SSW-38 | owner失败抑制 | C09:855 | sar9_sar15_safe_selection_wrapper:901,908 | A |  |
| SSW | SSW-39 | owner原子性 | C09:856 | sar9_sar15_safe_selection_wrapper:910,919 | A |  |
| SSW | SSW-40 | 单owner约束 | C09:857 | sar9_sar15_safe_selection_wrapper:921,930 | A |  |
| SSW | SSW-41 | SAR15跨色白名单 | C09:858 | sar9_sar15_safe_selection_wrapper:932,941 | A |  |
| SSW | SSW-42 | 真实DONE | C09:859 | sar9_sar15_safe_selection_wrapper:943,951 | A |  |
| SSW | SSW-43 | 生命周期epoch | C09:860 | sar9_sar15_safe_selection_wrapper:953,963 | A |  |
| SSW | SSW-44 | SAR9跨色白名单 | C09:861 | sar9_sar15_safe_selection_wrapper:965,974 | A |  |
| SSW | SSW-45 | SAR9码总线精度隔离 | C09:862 | sar9_sar15_safe_selection_wrapper:976,984 | A |  |
| SSW | SSW-46 | SAR15码总线精度隔离 | C09:863 | sar9_sar15_safe_selection_wrapper:986,994 | A |  |
| SSW | SSW-47 | 逐bit码窗与快照稳定 | C09:864 | sar9_sar15_safe_selection_wrapper:996,1010 | A |  |
| SSW | SSW-48 | 类型和模式矩阵 | C09:865 | sar9_sar15_safe_selection_wrapper:1012,1033 | A |  |
| SSW | SSW-49 | CHARACTERIZATION光电二极管固定SAR9 RED | C09:866 | sar9_sar15_safe_selection_wrapper:1035,1050 | A |  |
| SSW | SSW-50 | CHARACTERIZATION光电二极管固定SAR15 RED | C09:867 | sar9_sar15_safe_selection_wrapper:1052,1064 | A |  |
| SSW | SSW-51 | CHARACTERIZATION固定模式非法组合 | C09:868 | sar9_sar15_safe_selection_wrapper:1066,1091 | A |  |
| SSW | SSW-52 | STATIC_BIAS源资格 | C09:869 | sar9_sar15_safe_selection_wrapper:1093,1100 | A |  |
| SUP | SUPRST |  | — | system_fault_abort_supervisor:304 | F | SUPRST：复位安全默认值，TB本地编号 |
| SUP | SUP-01 | AMI mismatch captures one atomic snapsho | C24:152 | system_fault_abort_supervisor:315,328 | A | SUP01A/01B：首个AMI故障原子快照+三事件各一拍、下一拍不重发；子标签：SUP01A、SUP01B |
| SUP | SUP-02 | Concurrent records use fixed priority; l | C24:153 | system_fault_abort_supervisor:337,402 | A | SUP02A（后到记录只置汇总位）+SUP02B（同拍固定优先级）；子标签：SUP02A、SUP02B |
| SUP | SUP-03 | New fault wins over same-cycle clear. | C24:154 | system_fault_abort_supervisor:352 | B | SUP03A实测"episode开启期间诊断清除无效"（属合同SUP-07前半）；合同SUP-03"新故障胜过同拍清除"无同义检查；子标签：SUP03A |
| SUP | SUP-04 | Discard changes only discard summary. | C24:155 | system_fault_abort_supervisor:424,432 | A | SUP04A/04B：丢弃只改丢弃sticky，清除后归零；子标签：SUP04A、SUP04B |
| SUP | SUP-05 | External/system STOP merge is idempotent | C24:156 | — | E | 合同SUP-05（外部/系统STOP合并幂等）在supervisor单元TB无标签；矩阵P03称由LFA-11a覆盖abort合并半句，STOP合并幂等未见专门检查 |
| SUP | SUP-06 | Watchdog boundary, idle priority and no- | C24:157 | system_fault_abort_supervisor:362,441,458 | C | SUP06B（阈值处超时）/SUP06C（idle后恢复）覆盖看门狗边界；"不伪造完成"未直接断言；SUP06A实测episode关闭后阻断解除，不是看门狗（同号不同义的子标签）；子标签：SUP06A、SUP06B、SUP06C |
| SUP | SUP-07 | Clear cannot release active owner/cause; | C24:158 | system_fault_abort_supervisor:370 | C | SUP07A只测"合法清除去历史"；"清除不能释放活动原因"在SUP03A名下；子标签：SUP07A |
| SUP | SUP-08 | Final Top proves mismatch to STOPPING an | C24:159 | — | E | 合同SUP-08要求最终Top证明，supervisor单元TB不覆盖；Top级证据见LFA-02b/10a/11 |
| SUP | SUP-09 | A blocking fault emits one fault-discard | C24:160 | system_fault_abort_supervisor:470 | B | SUP09A实测"看门狗阈值前idle不超时"（属合同SUP-06）；合同SUP-09"阻断故障发一次fault-discard、外部abort不发"仅前半由SUP01A/01B间接覆盖；子标签：SUP09A |
| SUP | SUP-10 | A single fault-discard event is retained | C24:161 | system_fault_abort_supervisor:480 | B | SUP10A实测"第二个独立episode完整trio+新快照"（K02/N06）；合同SUP-10"AMI本地保留fault-discard原因"在C10 AMI-53，不在本TB；子标签：SUP10A |
| TC | TC-01 |  | — | chip_digital_top:283,668,676… | F | 芯片顶层TB本地；芯片顶层合同无验收ID族，TC6/TC7被合同正文引用 |
| TC | TC-02 |  | — | chip_digital_top:727,737,741 | F | 芯片顶层TB本地；芯片顶层合同无验收ID族，TC6/TC7被合同正文引用 |
| TC | TC-03 |  | — | chip_digital_top:755,773,785… | F | 芯片顶层TB本地；芯片顶层合同无验收ID族，TC6/TC7被合同正文引用 |
| TC | TC-04 |  | — | chip_digital_top:708,716,719… | F | 芯片顶层TB本地；芯片顶层合同无验收ID族，TC6/TC7被合同正文引用；子标签：TC4a、TC4b |
| TC | TC-06 |  | — | chip_digital_top:857,880,899… | F | 芯片顶层TB本地；芯片顶层合同无验收ID族，TC6/TC7被合同正文引用 |
| TC | TC-07 |  | — | chip_digital_top:646,909,911 | F | 芯片顶层TB本地；芯片顶层合同无验收ID族，TC6/TC7被合同正文引用 |
| TOP | TOP-01 | 复位 | C01:913 | control_top:1154,1157,3000… | A |  |
| TOP | TOP-02 | V4/V5 COMMIT/START | C01:914 | control_top:1309,1313 | A |  |
| TOP | TOP-03 | NORMAL双光 | C01:915 | control_top:2857,2860,2947 | A |  |
| TOP | TOP-04 | AMB/DCS | C01:916 | control_top:2091,2094 | A |  |
| TOP | TOP-05 | 双通道反压 | C01:917 | control_top:2275,2278 | A |  |
| TOP | TOP-06 | 精度切换 | C01:918 | control_top:2196,2199 | A |  |
| TOP | TOP-07 | 固定电流 | C01:919 | control_top:2393,2396 | A |  |
| TOP | TOP-08 | STATIC_BIAS | C01:920 | — | E | 别名表35/255行：SMOKE-19(?)，C01第942行映射 |
| TOP | TOP-09 | STOP/abort/reset | C01:921 | control_top:3114,3117,3134… | A |  |
| TOP | TOP-10 | 历史链隔离 | C01:922 | — | E | 别名表37行：综合层次静态检查，非仿真 |
| TOP | TOP-11 | IDAC启动边界 | C01:923 | — | E | 别名表38行：SID-01 |
| TOP | TOP-12 | STATIC_BIAS测量隔离 | C01:924 | — | E | 别名表39行：SMOKE-12(?) |
| TOP | TOP-13 | 纯RED固定SAR9 | C01:925 | control_top:1807,1810 | A |  |
| TOP | TOP-14 | 纯RED固定SAR15 | C01:926 | control_top:1903,1906 | A |  |
| TOP | TOP-15 | 双光共享包络 | C01:927 | control_top:1035,2010,2013… | A |  |
| TOP | TOP-16 | 真实ADC完成 | C01:928 | control_top:1611,1614 | A |  |
| TOP | TOP-17 | 共享物理ADC idle | C01:929 | control_top:1082 | E | 别名表：tb_ppg_control_top.v扇出监测器（无编号） |
| TOP | TOP-18 | RUN许可极性与拆分 | C01:930 | control_top:2576,2579,2582… | A |  |
| TOP | TOP-19 | STATIC_BIAS资格唯一所有权 | C01:931 | — | E | 别名表44行：SMOKE-21/22(?) |
| TOP | TOP-20 | 校准责任边界 | C01:932 | control_top:2713,2717 | A |  |
| TOP | TOP-21 | 注入生产旁路 | C01:933 | — | E | 别名表46行：INJ-01 |
| TOP | TOP-22 | LFA-08顶层传播 | C01:934 | — | E | 别名表47行：INJ-02（=LFA-08） |
| TOP | TOP-23 | PRC-08顶层资格 | C01:935 | — | E | 别名表48行：INJ-03（=PRC-08） |
| TOP | TOP-24 | 注入安全与互斥 | C01:936 | — | E | 别名表49行：INJ-04 |
| TRK | TRK-01 | Invalid tracking input or a changing pay | C25:566 | control_top_normal_slow_tracking:1054,1057 | A |  |
| TRK | TRK-02 | In-window evidence clears the matching d | C25:567 | control_top_normal_slow_tracking:1067,1088,1091… | A |  |
| TRK | TRK-03 | A high/low direction reversal clears the | C25:568 | control_top_normal_slow_tracking:1116,1122 | A |  |
| TRK | TRK-04 | RED and IR evidence, pending code, commi | C25:569 | control_top_normal_slow_tracking:1076,1080 | A |  |
| TRK | TRK-05 | SAR9/SAR15 transitions preserve same-col | C25:570 | control_top_normal_slow_tracking:1526,1530,1533… | A |  |
| TRK | TRK-06 | While pending waits for a safe boundary, | C25:571 | control_top_normal_slow_tracking:1156,1159,1162… | A |  |
| TRK | TRK-07 | A safe boundary commits at most one sign | C25:572 | control_top_normal_slow_tracking:1177,1180,1184… | A |  |
| TRK | TRK-08 | Continued evidence at min/max cannot wra | C25:573 | control_top_normal_slow_tracking:1281,1291,1294… | A |  |
| TRK | TRK-09 | A missing calibration-applied qualificat | C25:574 | control_top_normal_slow_tracking:1210,1213,1224… | A | 子标签：TRK-09a、TRK-09b |
| TRK | TRK-10 | Tracking comparisons use only signed 12- | C25:575 | control_top_normal_slow_tracking:1248,1252 | A |  |
| UNPACK | UNPACK-01 | 全零联合快照产生全部零功能输出 | C05:114 | system_active_config_unpack:217 | A | 仅FAIL分支带编号 |
| UNPACK | UNPACK-02 | 逐一激励1024个物理位，V4/V5定义字段保持原位，所有保留区不泄漏 | C05:115 | system_active_config_unpack:226 | A | 仅FAIL分支带编号 |
| UNPACK | UNPACK-03 | signed 12/20/26/32-bit字段保持负数、正数和Q16编码 | C05:116 | system_active_config_unpack:249 | A | 仅FAIL分支带编号 |
| UNPACK | UNPACK-04 | 多字段同时变化时无状态、无新增周期地完整传播 | C05:117 | system_active_config_unpack:256 | A | 仅FAIL分支带编号 |

## 6. B类详细说明（65处）

### 6.1 FSC（56处B，另1处C、5处D）

- **成因**：调度器单元TB的主`initial`块按场景顺序执行，第n个检查调用`check_fsc(n, cond)`，打印`PASS FSC-n`。编号只是TB内的序号，从未对照C08第18节。
- **对应关系**：总表FSC各行写明了“TB FSC-n实测什么”和“合同FSC-n的同义检查在TB的哪几个编号”。按合同条目反查：
  - 有同义检查：01、02、03、04、05、06、07、08、09、10、11、12、13、14、15、16、17、22、25、26、28、29、30、31、32、33、36、37、38、39、40（部分）、41、42、45、46、49、50、51、52、54、55、56；
  - **无同义检查**：18、19、20、21、23、24、27、34、35、43、44、47、48、53、57。阶段顺序、单光完成事件、16-bit回绕、随机ready/valid、长时间回归、校准接管间隔625、迟到校准valid、IR并行预建立、RED完成后IR owner、两张跨色白名单，都在单元TB里找不到断言。
  - 系统级TB有没有覆盖这些条目，本次未逐条核实：FSC不在别名表和核对脚本的范围内，需要合并批次决定是否补查。
- **F-046的5处**：C08:1136/1147/1150/1167/1168为合同FSC-03/14/17/34/35，TB:601/618/629/745/761为TB的FSC-3/14/17/34/35，5处全部成立，属于上面56处的子集。行号订正：任务说明称这些行号以d18c695为准，但实测它们与`bb39a0f`及之后的版本（含本快照）一致。在d18c695上，C08:1136是FSC-04，TB:601也不是检查行。
- **虚假证据风险**：
  - 日志`ALL FSC-01 THROUGH FSC-62 PASSED`与C08:1206“必须真实覆盖FSC-01至FSC-57”字面吻合；
  - C01:38和核对表:43/:420把它写成“当前单模块PASS证据”；
  - 读者如果按编号查日志`PASS FSC-34`，会以为“随机ready/valid”已验证，而TB的FSC-34实测的是“success=0不计NORMAL完成”。
  - 核对脚本看不到FSC族，所以不会据此判错。风险全部在文字层。

### 6.2 SUP（3处B，另有2个同号不同义的子标签）

| 合同 | 合同含义 | TB标签 | TB实测 | 判定 |
|---|---|---|---|---|
| SUP-03 | 新故障胜过同拍清除 | SUP03A | episode开启期间诊断清除无效（属SUP-07前半） | B |
| SUP-09 | 阻断故障发一次fault-discard，外部abort不发 | SUP09A | 看门狗阈值前idle不超时（属SUP-06） | B |
| SUP-10 | AMI本地保留fault-discard原因 | SUP10A | 第二个独立episode完整trio（K02/N06） | B |
| SUP-06 | 看门狗边界、idle优先、不伪造 | SUP06A | episode关闭后阻断解除，不是看门狗 | 子标签B（SUP-06整体判C） |

- 总横幅“SUP-01 through SUP-10 PASS: 14 real comparisons”把没有任何检查的SUP-05/08，以及含义不符的SUP-03/09/10一并宣称通过。
- 别名表P05行以“SUP06A/B/C”作为5000周期看门狗证据，其中SUP06A与看门狗无关。

### 6.3 DCR（5处B）

TB的`drive_and_check(test_id,…)`只在FAIL时打印`FAIL DCR-%0d`：

| TB测试编号 | TB实测 | 实际对应的合同条目 |
|---|---|---|
| DCR-3 | 9-bit且DC码为0时DC项为0 | DCR-04 |
| DCR-4 | 15-bit双结果+K_DC15 | DCR-07/11 |
| DCR-5 | CHARACTERIZATION下资格为0 | DCR-12 |
| DCR-6 | 24-bit正端饱和 | DCR-09 |
| DCR-7 | 24-bit负端饱和 | DCR-09 |

- 合同DCR-03（9-bit正负边界）和DCR-06（15-bit DC码为0）没有同义检查。DCR-05只被TB DCR-2的单点（DC码2）间接覆盖。
- 风险：PASS时日志只有“PASS ppg_adc_dc_recovery DCR-01..DCR-22”，这行横幅把上述缺口也算进去了；FAIL时打印的编号会把人引到错误的合同条目。

### 6.4 SSW-18（1处B）

TB的SSW-18场景实测“校准owner缺失时在tick 249前超时”，属于合同SSW-37/38。合同SSW-18“tick 385前未准备下一码则终止burst并置sticky”在该TB中没有同义检查。C09:878和核对表:45的“SSW-01至SSW-52全部PASS”因此在SSW-18上不成立。

### 6.5 LFA-11a（子标签B，LFA-11整体判C）

- LFA-11a实测“supervisor自动owner-scoped abort释放owner期间没有虚假正式结果”。按TB自己的注释，这属于合同§9.5.1规则5和矩阵P03；它的两个分支（owner仍在途/已释放）都打印PASS。
- 合同LFA-11“活动故障在清除后继续阻断”的前半句没有断言，后半句由LFA-11b覆盖。

## 7. D类详细说明（33处）

| 族 | 编号 | 说明 |
|---|---|---|
| FSC | 58、59 | 合法payload但run_profile为CHARACTERIZATION，或input_source为EXTERNAL_TEST_CURRENT时，请求不被接受、不产生波形/owner，并置协议sticky。语义属合同FSC-17 |
| FSC | 60、61、62 | SID-05截止事件：tick 248当拍提交算按时、tick 247提交、过248未提交时截止事件恰好1拍且不与提交同拍。语义属FSC-50的V1.12原行补充，带`@satisfies: SID-05` |
| OVL | 01~17 | C13第7节验收用例是8条无编号列表。TB标签来自合同外的“交付文件”，总横幅称OVL-01..OVL-17 |
| OPTC | 01、02 | 共享乘法器的两项检查。C21只定义OPT-01~24 |
| JNT | 01~09（另有JNT-02A等字母子编号及JNT-STARTUP-READY等无号子检查） | 联合TB说明只写了“JNT-01～09（52个子检查）”，没有定义表；别名表128行按TB登记 |

## 8. C类与E类要点

- **C类（43处）**：多数是“TB只测了合同条目的一部分”，缺口逐条写在总表里。需要单独处理的有：
  - AMI-24：`!o_wrapper_fault_blocking || !o_transaction_start_ready`在没有阻断故障时恒真，可能空真；
  - AMI-13（待定）：TB只测反压保持，合同要求同拍替换；
  - SSW-11：local tick由TB直接驱动，625周期间隔未实测；
  - PRC-05/08：无条件PASS；
  - AV4C-03/15/17：与AV4C-02共用同一组比较。
- **E类（131处）**：
  - TOP-08/10/11/12/17/19/21~24、OIB-04/10、ADCN-04/07/09、ISE-02/07、AMI-54、PWI-08、BSL-40：别名表都有指向其他场景名下证据的行，属于正常的跨名证据；
  - AMI-46~53：C10第30行自述EVIDENCE_PENDING，顶层证据分散在INJ/LFA/PRC名下；
  - RAW-01~11：生成器性质由RGC-01~15覆盖，但两者之间没有对照登记；
  - **整族无TB编号**：IDC2（24）、CIS（30）、AV4（19）、CF4（5）。IDAC控制器TB用的是无编号描述行和C16的IDT标签；CIS/AV4/CF4的内容分散在MGR/SSW/ILM/CCC/AV4C中，没有登记对照；
  - 真正没找到证据的：SUP-05（STOP合并幂等）、AMR-13（AMB_CHECK事务进PPG链必须判失败）、MGR-21（合同要求三模块联合TB验证）、PWI-06/07（与S4矛盾）。另有前文提到的FSC 15条、DCR-03/06、SSW-18（这些条目的同号标签含义不符，计在B类）。

## 9. 核对脚本影响评估

- **证据来源**：`reconcile_acceptance_ids.py`只读三样东西：别名表行（非“无映射”即算真实映射）、全仓`*.v`（含TB）中的`@satisfies:`注释，以及矩阵/合同中与编号同行的状态词。它**不读TB日志里的“PASS ID”字样**。
- **覆盖范围**：`ID_PATTERN`只覆盖G-FP、Acceptance-D01、D/L/K/P/N、TOP、JNT、SID、LFA、OIB、PRC、RRC、TRK、NRE、ILM、ADCN、ISE、PVW、PWC、FIR这22个族。本次发现的B类所在的FSC、SUP、DCR、SSW，以及AMI、CCC、MGR、CAL、PR、RTR、BSL、OPT、AV4C、UNPACK、FFK、IDT、AMR等29个族都不在其中。
- **B类撞号对脚本分类的影响：0个ID**。LFA-11a只出现在`$display`文字里，不是`@satisfies`，同样不受影响。反过来说，这29个族的证据完全不受脚本约束。这是§13.2没有记录的盲区。
- **TB中的`@satisfies`标签**：有效标签只有调度器TB的SID-05（6处）、AMI单元TB的SID-05（3处）、ISE-01（2处）、PVW-32（1处），与各自检查含义一致。
- **在zlcx克隆中的可用性**：
  - 脚本用`REPO_ROOT/"ppg_system_integration"`找别名表和矩阵，克隆里没有这个目录。原样运行结果为301个ID，其中B2_ALIAS_ROW_MISSING 299个，**不可用**；`tools/cross_reference_tools/reconciliation_report.*`是原开发树的旧产物。
  - 只在副本中把路径改为`contracts/`后，结果为328个ID：A 266、B 23、B2 22、D 1、E_STALE 16。
  - 这22个B2全是伪ID：TB文件头修订记录的叙述文字里写有`@satisfies: TOP-01`标签之类的字样，脚本按逗号切出“TOP-01标签），”“SMOKE_TB_PASS (49 real ADC responses”等串当作标签。其中“ADCN-03, just not routed…”切出的`ADCN-03`会被当成有效锚点。
- **结论**：B类撞号不会让脚本误判，因为脚本根本不看这些族。虚假证据风险集中在文字层：第3.2节S7、第4节的总横幅、别名表P05行，以及矩阵947/3724/3731/3736行和别名表545行里旧“AMI-46/47”的历史叙述（用户已决定保留不改）。

## 10. 处置建议（只建议，未实施）

命名原则（任务给定）：带合同族前缀的编号必须存在于该合同验收表中且含义相同；TB本地检查用不会与任何合同族混淆的命名。

| 项 | 建议 | 理由 |
|---|---|---|
| FSC-2~57（B） | **改TB标签**，移到TB本地命名空间（例如`SCHT-01`~`SCHT-62`，与AMI-DISC/SID05同一思路）。在C08第18节后增加“单元TB检查→合同条目”对照表（数据即总表FSC列），横幅改为本地名，同步`tools/run_unit_tb_regression.sh`中该TB的横幅判据 | 一个TB检查常对应多个合同条目（例如TB FSC-29对应FSC-37与FSC-46），反过来也一样，按合同编号重排TB做不到一一对应；改成本地名并加对照表，才能保住“前缀=合同同义” |
| FSC-1（C） | 随整组改名，在对照表中标为部分覆盖 | 同上 |
| FSC-58~62（D） | **不在C08新增条目**，改为本地名，在对照表中映射到FSC-17、FSC-50 | 语义已被现有条目包含；用户原计划“在第18节补登FSC-58~62”，但在2~57改为本地名的前提下，补登会造成合同里有58~62、TB里却没有FSC前缀的局面。如果用户仍要补登，只能作为“FSC-17/50的细化子条目”，而且必须先完成2~57的改名，否则继续撞号 |
| 合同FSC 15条无同义检查 | 记为证据缺口，由用户决定补单元断言还是补查系统级证据 | 第6.1节 |
| C08:1206、C01:38、核对表:43/:45/:420、C09:878（S7） | **订正合同文字**：原文加删除线保留，改为“单元TB按对照表覆盖，缺口见……” | 现有文字把错位的PASS当作证据 |
| SUP03A/09A/10A、SUP06A（B） | **改TB子标签**：SUP03A改为SUP07B（清除不释放活动原因）、SUP09A改为SUP06D、SUP10A改为本地名（例如`SUPT-EPISODE2`，K02/N06），SUP06A改为SUP07C（或本地名）；横幅改为列出实际覆盖的编号 | 使子标签前缀与C24含义一致 |
| SUP-03/05/09后半/08 | 记为证据缺口（SUP-08为最终Top，见LFA） | — |
| C24 SUP-10 | **订正合同条目**：标注“归C10 AMI-53”，或移出 | S10 |
| 别名表P05行 | 订正，去掉SUP06A | 第6.2节 |
| DCR TB第3~7号（B） | **改TB测试编号**为实际对应的合同编号（3→04、4→07、5→12、6/7→09）；横幅改为只列出实际有检查的编号 | 数值编号只是TB的入参，改了不影响检查逻辑 |
| DCR-03、DCR-06 | 证据缺口 | — |
| SSW-18（B） | **改TB场景标签**（并入SSW-37/38，或用本地名）；合同SSW-18记为证据缺口，并核实RTL是否实现tick 385 burst终止（**待定**） | 第6.4节 |
| LFA-11a（子标签B） | 改为本地名或标为P03证据；“informational”分支不再打印PASS | 第6.5节 |
| AMI-13（待定） | 先确认有没有其他地方构造同拍替换：有则记C，无则改标签或补检查 | — |
| AMI-24（C，可能空真） | 补一个先确保阻断故障成立的前置条件（TB修改） | 不属于编号治理本身，但同样是证据有效性问题 |
| PRC-05/08 | 把无条件`PASS … cited`改为`INFO CITED …`（TB修改） | C08等合同禁止无条件PASS打印的精神同样适用 |
| OVL（D） | 在C13第7节把8条无编号列表改为OVL-01~17表，或把TB改为本地名。**推荐登记**：TB的17项都是C13相关行为，而合同没有编号 | — |
| OPTC（D） | 在C21登记OPTC-01/02（共享乘法器复用），或改本地名。**推荐登记** | — |
| JNT（D） | 在联合TB说明中加JNT定义表（9项+子检查），或在别名表中明确“TB定义” | — |
| RAW↔RGC、IDC2/CIS/AV4/CF4（E） | 在别名表加对照行，或给相关TB检查加编号 | 整族无编号，现在只能靠人工判断覆盖情况 |
| S1~S4、S6 | 订正合同文字（范围改为表格实际上限；C18:659改为PWI-01~05；PVW-47/48表格修正） | 第3.2节 |
| S5 | 在C23第21节标注“PWI-01~05以C18为准”，或删除重复定义 | 归属唯一 |
| S8、S11 | **待定**，需要读RTL确认 | — |
| 核对脚本 | 修路径、扩充ID_PATTERN覆盖全部合同族、`@satisfies`只认注释末尾的规范形态，并在§13.2补记本节所述盲区（tools修改） | 第9节 |
| 编号补零 | 新标签统一补零；FSC/CCC/ADCN旧标签随改名一并处理 | grep一致性 |

## 11. 合并批次改动清单（编号治理部分）

| 类别 | 文件/位置 | 估计改动处数 | 与ABCD会话重叠 |
|---|---|---:|---|
| 合同 | C08：第18节后加对照表（约62行）；:1206订正；FSC-58~62处置 | 约3处+1张表 | — |
| 合同 | C10：:30、:1340范围订正；AMI-13视待定结论 | 2~3 | — |
| 合同 | C18：:3、:10、:690范围，:659声明 | 4 | — |
| 合同 | C19：:3、:10、:686范围 | 3 | — |
| 合同 | C23第21节PWI-01~05归属说明 | 1 | — |
| 合同 | C22：PVW-47/48表格格式 | 2 | — |
| 合同 | C24：SUP-10归属；第7节证据状态说明 | 2 | — |
| 合同 | C09：:878声明、SSW-18缺口 | 2 | — |
| 合同 | C01：:38声明 | 1 | — |
| 合同 | C02：MGR-12（待定）、MGR-18/23重叠说明 | 1~2 | — |
| 合同 | C13：OVL表（若登记，17行）；C21：OPTC（若登记，2行） | 0~19行 | — |
| 合同 | 核对表：:43、:45、:420 | 3 | — |
| 合同 | 联合TB说明：JNT表（若登记） | 0~1张表 | — |
| 合同 | 各合同按惯例升版并同步依赖表/矩阵§12.4（C08/C10只升一次，与FSC-58~62、C10第30行订正合批） | 按版本惯例 | — |
| 矩阵 | §13.1快照数字过期（矩阵自记184个ID，脚本现为328个）；§13.2补第9节盲区；AMI-46/47历史叙述（947/3724/3731/3736）按用户决定不改 | 2 | — |
| 别名表 | P05行订正；新增FSC/SUP/DCR/RAW↔RGC/IDC2等对照行（数量取决于第10节的选择） | 1+若干 | — |
| TB | 调度器TB：62个标签+2行横幅 | 64 | 否 |
| TB | supervisor TB：SUP03A/06A/09A/10A+横幅。ABCD工作区已改此文件（新增SUP10B） | 5 | **是** |
| TB | DCR TB：5个测试编号+横幅 | 6 | **是**（工作区已改） |
| TB | SSW TB：SSW-18场景标签 | 1~2 | 否 |
| TB | LFA TB：LFA-11a | 2 | 否 |
| TB | PRC TB：PRC-05/08的cited行 | 2 | **是**（工作区已改） |
| TB | 横幅：MGR、PR、RTR、CAL、CCC、OVL、AV4C（若改为只列实际覆盖） | 7 | PR/RTR/CCC/OVL/AV4C **是** |
| TB | AMI TB：AMI-13/24（视待定结论） | 0~2 | 否 |
| tools | `run_unit_tb_regression.sh`：对应TB横幅判据（FSC、SUP、DCR等，随横幅改动） | 3~10 | 否 |
| tools | `reconcile_acceptance_ids.py`：路径、ID正则、`@satisfies`解析（是否纳入本批由用户定） | 3 | 否 |

## 12. ABCD会话期间的变化与重扫

- `git log --oneline 2a90a69..origin/main`为空，ABCD会话在核查期间没有推送提交，因此本报告的结论基于的快照仍是当前HEAD。
- ABCD会话的TB轮修改正在工作区中进行，尚未提交：共17个TB/vh文件加1个脚本，与第11节标“是”的文件重叠。我把这些工作区文件复制到仓库外，叠加到快照副本上，用`rescan_diff.py`试跑：报出31处“B?”（已有编号下的检查代码变了，需要按合同复读含义），0处D。其中包括新增的`SUP10B`，以及PR-06、CCC-22、ISE-01/04/05、OIB-06、RRC-01、PRC-09/10、PWI-01/02、AV4C-02/03/15/17处的改动。这些改动未提交、仍在进行中，**只作提示**。合并批次开工时，应在新HEAD上重跑附录A的扫描器，再用`rescan_diff.py tb_sites.json（本快照基线） <新扫描>`逐条复读。

## 13. 待定项

| # | 项 | 还缺什么 |
|---|---|---|
| T1 | AMI-13：B还是C | 需确认AMI单元TB或其他TB是否构造过“两分支最后消费与新事务装入同拍” |
| T2 | MGR-12的0x05 | 读manager RTL，确认`ERROR_ENUM_ENCODING`是否还有可达路径 |
| T3 | IDC2-17与AMR-10等的DCS重验证语义（S11） | 读IDAC控制器RTL，区分固定周期序列与`o_dcs_revalidate_request`握手 |
| T4 | SSW-18 tick 385 burst终止 | 读SSW RTL，确认该行为是否实现 |
| T5 | 合同FSC 15条无同义检查的条目在系统级TB中是否有证据 | FSC不在别名表中，需要逐条查19-TB |

## 附录A 扫描与判定脚本（完整代码，可在新HEAD上重跑）
运行顺序（`<root>`为`git archive <HEAD>`导出目录；全部输出写在仓库外）：
```bash
python scan_contract_ids.py <root> contract_ids.json
python scan_tb_labels.py <root> tb_sites.json
python scan_logs.py log_labels.json <tb名>=<xsim.log> ...
python join_ids.py contract_ids.json tb_sites.json log_labels.json fam/
python e_check.py <root> contract_ids.json tb_sites.json log_labels.json
python gen_table.py <root> contract_ids.json tb_sites.json log_labels.json table.md stats.md
python tb_stats.py tb_sites.json log_labels.json tbstats.md
python rescan_diff.py <基线tb_sites.json> <新tb_sites.json> contract_ids.json
```
`decisions.py`是本次人工判定的数据（读检查代码得出），不是自动推导；新HEAD上`rescan_diff.py`报出的每一处都要人工复读后再更新它。

### A.scan_tb_labels_lib `scan_tb_labels_lib.py`

```python
"""Shared label grammar for the TB-side and log-side scanners."""
import re

# governed label: FAMILY-NN[a][-n] (family may contain digits/dashes), SUPnnX, SUPRST, TCn
GOV = re.compile(r'(?<![A-Za-z0-9_])('
                 r'[A-Z][A-Z0-9]*(?:-[A-Z][A-Z0-9]*)*-\d{1,3}[A-Za-z]?(?:-\d+)?'
                 r'|SUP\d{2}[A-Z]?|SUPRST|TC\d{1,2}[a-z]?'
                 r')(?![A-Za-z0-9_])')
# tokens of that shape that are not check labels (precision names, signal-ish words)
NOISE_FAM = {'SAR', 'RED-SAR', 'RUN', 'LEDEN', 'IR-SAR', 'Q', 'V', 'P', 'N'}


def family(tok):
    if re.match(r'^SUP(\d|RST$)', tok):
        return 'SUP'
    if re.match(r'^TC\d', tok):
        return 'TC'
    return re.match(r'^(.*?)-\d', tok).group(1)
```

### A.scan_contract_ids `scan_contract_ids.py`

```python
"""ID governance audit, contract side: every table row whose FIRST cell is a single acceptance-style ID.
Usage: python scan_contract_ids.py <repo_root> <out.json>
Output rows: {id, family, file, line, section, cells[1:]} ; also per-file duplicate / gap / range-claim findings."""
import re, sys, json, glob, os, collections

ROOT = sys.argv[1]
OUT = sys.argv[2]
# ID token: FAMILY-NN[a] (family may itself contain digits/dashes, e.g. AV4C-01, G-FP-01) or bare K01/P01 style.
ID_RE = r'(?:[A-Z][A-Z0-9]*(?:-[A-Z][A-Z0-9]*)*-\d{1,3}[A-Za-z]?)'
ROW = re.compile(r'^\|\s*(?:\*\*)?`?(' + ID_RE + r')`?(?:\*\*)?(?![-0-9A-Za-z_])([^|]*)\|(.*)$')
HEAD = re.compile(r'^(#{1,6})\s+(.*)')
SKIP_FILES = {'PPG_CONTRACT_CLOSURE_MATRIX.md', 'PPG_ALIAS_MAPPING_TABLE.md'}
# first-cell tokens that are not acceptance IDs: contract numbers C01..C25 and the matrix-local R/M/D/L/K/P/N rows
NOT_ACCEPT = re.compile(r'^C\d{2}$')


def family(i):
    m = re.match(r'^(.*?)-?(\d{1,3})([A-Za-z]?)$', i)
    return m.group(1), int(m.group(2)), m.group(3)


rows = []
for path in sorted(glob.glob(os.path.join(ROOT, 'contracts', '*.md'))):
    f = os.path.basename(path)
    if f in SKIP_FILES:
        continue
    sec = ''
    for n, line in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
        h = HEAD.match(line)
        if h:
            sec = h.group(2).strip()[:80]
            continue
        m = ROW.match(line)
        if not m or NOT_ACCEPT.match(m.group(1)):
            continue
        cells = [c.strip() for c in m.group(3).rstrip().rstrip('|').split('|')]
        if m.group(2).strip():  # 'MGR-01复位' style: title shares the ID cell
            cells = [m.group(2).strip()] + cells
        fam, num, suf = family(m.group(1))
        rows.append({'id': m.group(1), 'family': fam, 'num': num, 'suffix': suf, 'file': f, 'line': n,
                     'section': sec, 'cells': cells})

# per (file, family) duplicates and gaps
findings = []
by = collections.defaultdict(list)
for r in rows:
    by[(r['file'], r['family'])].append(r)
for (f, fam), rs in sorted(by.items()):
    ids = collections.Counter(r['id'] for r in rs)
    for i, c in ids.items():
        if c > 1:
            findings.append({'kind': 'duplicate', 'file': f, 'family': fam, 'id': i,
                             'lines': [r['line'] for r in rs if r['id'] == i]})
    nums = sorted({r['num'] for r in rs})
    gaps = [k for k in range(nums[0], nums[-1] + 1) if k not in nums]
    if gaps:
        findings.append({'kind': 'gap', 'file': f, 'family': fam, 'missing': gaps, 'range': [nums[0], nums[-1]]})

# same ID defined in more than one contract file
byid = collections.defaultdict(list)
for r in rows:
    byid[r['id']].append(r)
for i, rs in sorted(byid.items()):
    if len({r['file'] for r in rs}) > 1:
        findings.append({'kind': 'cross_file_duplicate', 'id': i,
                         'where': [(r['file'], r['line'], (r['cells'] or [''])[0][:40]) for r in rs]})

# range claims in prose: "FAM-aa至FAM-bb" / "FAM-aa through FAM-bb" / "FAM-aa~bb" / "FAM-aa..FAM-bb" that exceed the table
RANGE = re.compile(r'(?<![A-Za-z0-9_-])([A-Z][A-Z0-9]*(?:-[A-Z][A-Z0-9]*)*)-(\d{2})\s*(?:至|到|~|～|through|to|\.\.|-)\s*(?:\1-)?(\d{2})(?!\d)')
for path in sorted(glob.glob(os.path.join(ROOT, 'contracts', '*.md'))):
    f = os.path.basename(path)
    if f in SKIP_FILES:
        continue
    fams = {fam: max(r['num'] for r in rs) for (ff, fam), rs in by.items() if ff == f}
    for n, line in enumerate(open(path, encoding='utf-8').read().split('\n'), 1):
        for m in RANGE.finditer(line):
            fam, lo, hi = m.group(1), int(m.group(2)), int(m.group(3))
            if fam in fams and hi > fams[fam]:
                findings.append({'kind': 'range_exceeds_table', 'file': f, 'line': n, 'text': m.group(0),
                                 'table_max': fams[fam]})
json.dump({'rows': rows, 'findings': findings}, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
fc = collections.Counter((r['file'], r['family']) for r in rows)
for (f, fam), c in sorted(fc.items()):
    print(f'{f[:58]:58s} {fam:8s} {c:3d}')
print('findings:', collections.Counter(x['kind'] for x in findings))
for x in findings:
    print(' ', x)
```

### A.scan_tb_labels `scan_tb_labels.py`

```python
"""ID governance audit, TB side.
Usage: python scan_tb_labels.py <repo_root> <out.json>
For every rtl/**/tb_*.v and rtl/**/*.vh (legacy/ excluded) emit "label sites":
  * string-literal sites: a non-comment code line whose string literal carries a governed check label;
  * numeric sites: per-TB call rules where the label is printed through a %0d format (FSC-%0d, CCC-%0d ...).
Each site carries the code context (the whole call statement, or the if-condition that guards a $display),
so that the check's real comparison can be read from code rather than from comments."""
import re, sys, os, json, glob, collections

ROOT, OUT = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import GOV, NOISE_FAM, family
STR = re.compile(r'"((?:[^"\\]|\\.)*)"')
# numeric-label rules: file basename -> list of (regex on code, printed family, zero-pad width or 0)
NUM_RULES = {
    'tb_ppg_400hz_frame_calibration_scheduler.v': [(r'\bcheck_fsc\(\s*(\d+)\s*,', 'FSC', 0)],
    'tb_ppg_characterization_control_cdc.v': [(r"\bcheck_case\(\s*8'd(\d+)\s*,", 'CCC', 0)],
    'tb_ppg_adc_dc_recovery.v': [(r'\bdrive_and_check\(\s*(\d+)\s*,', 'DCR', 0)],
    'tb_ppg_adc_programmable_reconstructor.v': [(r'\bcheck_transaction\(\s*(\d+)\s*\)', 'PR', 0),
                                                (r'\bsend_transaction\(\s*(\d+)\s*,', 'PR', 0)],
    'tb_ppg_adc_pipeline_overlap_corrector.v': [(r"\breg_test_case_id\s*=\s*8'd(\d+)\s*;", 'OVL', 0)],
    'tb_ppg_control_top_adc_numeric_scoreboard.v': [(r'\bdrive_and_check_transaction\(\s*(\d+)\s*,', 'ADCN', 0)],
}


def strip_comment(line):
    out, q = [], False
    i = 0
    while i < len(line):
        ch = line[i]
        if ch == '"' and (i == 0 or line[i - 1] != '\\'):
            q = not q
        if not q and line.startswith('//', i):
            break
        out.append(ch)
        i += 1
    return ''.join(out)


def statement_from(code, i):
    """Return (start, end) line indexes of the statement that begins at line i (paren-balanced, ends with ';')."""
    depth, j = 0, i
    while j < len(code):
        depth += code[j].count('(') - code[j].count(')')
        if depth <= 0 and ';' in code[j]:
            return i, j
        j += 1
        if j - i > 25:
            break
    return i, min(j, len(code) - 1)


def guard_from(code, i):
    """For a $display at line i, walk back to the nearest enclosing if/else-if/case-item condition (<=15 lines)."""
    for k in range(i, max(-1, i - 16), -1):
        if re.search(r'\b(if|else\s+if)\s*\(', code[k]) or re.search(r'\bcheck\w*\s*\(|\bexpect\w*\s*\(', code[k]):
            return k, i
    return i, i


sites = []
files = sorted(f for f in glob.glob(os.path.join(ROOT, 'rtl', '**', '*.v'), recursive=True) +
               glob.glob(os.path.join(ROOT, 'rtl', '**', '*.vh'), recursive=True)
               if 'legacy' not in f.replace('\\', '/').split('/') and
               (os.path.basename(f).startswith('tb_') or f.endswith('.vh')))
for path in files:
    rel = os.path.relpath(path, ROOT).replace('\\', '/')
    raw = open(path, encoding='utf-8', errors='replace').read().split('\n')
    code = [strip_comment(l) for l in raw]
    base = os.path.basename(path)
    for i, l in enumerate(code):
        for lit in STR.findall(l):
            toks = [t for t in GOV.findall(lit) if family(t) not in NOISE_FAM]
            if not toks:
                continue
            kind = 'pass' if 'PASS' in lit else ('fail' if re.search(r'FAIL|ERROR|MISMATCH', lit) else 'other')
            if re.search(r'\b(check\w*|begin_case|expect\w*|jnt_check\w*)\s*\(\s*"', l):
                s, e = statement_from(code, i)
                kind = 'call'
            else:
                s, e = guard_from(code, i)
            sites.append({'file': rel, 'line': i + 1, 'labels': toks, 'family': family(toks[0]), 'kind': kind,
                          'literal': lit[:200], 'ctx_lines': [s + 1, e + 1],
                          'ctx': ' '.join(x.strip() for x in code[s:e + 1])[:600]})
    for rx, fam, pad in NUM_RULES.get(base, []):
        for i, l in enumerate(code):
            for m in re.finditer(rx, l):
                n = int(m.group(1))
                s, e = statement_from(code, i)
                lab = f'{fam}-{n}'
                sites.append({'file': rel, 'line': i + 1, 'labels': [lab], 'family': fam, 'kind': 'numeric',
                              'literal': f'{fam}-%0d <- {n}', 'ctx_lines': [s + 1, e + 1],
                              'ctx': ' '.join(x.strip() for x in code[s:e + 1])[:600]})

json.dump(sites, open(OUT, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
c = collections.Counter((s['file'].split('/')[-1], s['family']) for s in sites)
for (f, fam), n in sorted(c.items()):
    print(f'{f[:60]:60s} {fam:10s} {n:4d}')
print('sites', len(sites))
```

### A.scan_logs `scan_logs.py`

```python
"""ID governance audit, log side: which governed labels a real regression run actually printed.
Usage: python scan_logs.py <out.json> <tb_name>=<xsim.log> ...
Every log line carrying a governed label is kept verbatim (first 300 chars) with its occurrence count."""
import os, sys, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import GOV, NOISE_FAM, family

out = {}
for arg in sys.argv[2:]:
    tb, path = arg.split('=', 1)
    lines = collections.OrderedDict()
    for l in open(path, encoding='utf-8', errors='replace'):
        l = l.rstrip('\n')
        if l.startswith(('#', 'INFO:', 'Time resolution', '$finish')):
            continue
        toks = [t for t in GOV.findall(l) if family(t) not in NOISE_FAM]
        if toks:
            key = l[:300]
            if key not in lines:
                lines[key] = {'text': key, 'labels': toks, 'count': 0,
                              'verdict': 'PASS' if 'PASS' in l else ('FAIL' if 'FAIL' in l else 'INFO')}
            lines[key]['count'] += 1
    out[tb] = list(lines.values())
json.dump(out, open(sys.argv[1], 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
for tb, ls in out.items():
    labs = collections.Counter(t for x in ls for t in x['labels'])
    print(f'{tb:60s} lines={len(ls):4d} distinct_labels={len(labs):4d}')
```

### A.join_ids `join_ids.py`

```python
"""Join contract-side rows, TB label sites and log lines per family into review dumps.
Usage: python join_ids.py contract_ids.json tb_sites.json log_labels.json <outdir>
Numbers are compared as integers (FSC-1 == FSC-01); the printed spelling is kept for the report."""
import re, sys, os, json, collections

C = json.load(open(sys.argv[1], encoding='utf-8'))['rows']
T = json.load(open(sys.argv[2], encoding='utf-8'))
L = json.load(open(sys.argv[3], encoding='utf-8'))
OUT = sys.argv[4]
os.makedirs(OUT, exist_ok=True)


sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family


def key(tok):
    """(family, int number, letter suffix, trailing -n) using the same family grammar as the scanners."""
    if tok == 'SUPRST':
        return ('SUP', 0, 'RST', '')
    fam = family(tok)
    rest = tok[len(fam):].lstrip('-')
    m = re.match(r'^(\d{1,3})([A-Za-z]?)((?:-\d+)?)$', rest)
    if not m:
        return (fam, None, rest, '')
    return (fam, int(m.group(1)), m.group(2).upper(), m.group(3))


fams = collections.defaultdict(lambda: {'contract': collections.defaultdict(list),
                                        'tb': collections.defaultdict(list),
                                        'log': collections.defaultdict(list)})
for r in C:
    k = key(r['id'])
    fams[k[0]]['contract'][k].append(r)
for s in T:
    for t in dict.fromkeys(s['labels']):
        k = key(t)
        fams[k[0]]['tb'][k].append(dict(s, label=t))
for tb, lines in L.items():
    for x in lines:
        for t in dict.fromkeys(x['labels']):
            k = key(t)
            fams[k[0]]['log'][k].append(dict(x, tb=tb, label=t))

summary = []
for fam, d in sorted(fams.items()):
    keys = sorted(set(d['contract']) | set(d['tb']) | set(d['log']), key=lambda k: (k[1] or 0, k[2], k[3]))
    nc = len(d['contract']); nt = len(d['tb']); nl = len(d['log'])
    summary.append((fam, nc, nt, nl))
    with open(os.path.join(OUT, f'{fam}.md'), 'w', encoding='utf-8') as f:
        f.write(f'# {fam}: contract={nc} tb={nt} log={nl}\n\n')
        for k in keys:
            f.write(f'## {fam}-{k[1]}{k[2]}{k[3]}\n')
            for r in d['contract'].get(k, []):
                f.write(f"- C {r['file']}:{r['line']} [{r['section'][:30]}] {' | '.join(r['cells'])[:400]}\n")
            for s in d['tb'].get(k, []):
                f.write(f"- T {s['file'].split('/')[-1]}:{s['line']} ({s['kind']}) \"{s['literal'][:160]}\"\n"
                        f"    ctx {s['ctx_lines'][0]}-{s['ctx_lines'][1]}: {s['ctx'][:500]}\n")
            for x in d['log'].get(k, [])[:4]:
                f.write(f"- L {x['tb']} x{x['count']} {x['verdict']}: {x['text'][:220]}\n")
            f.write('\n')
with open(os.path.join(OUT, '_summary.tsv'), 'w', encoding='utf-8') as f:
    f.write('family\tcontract_ids\ttb_ids\tlog_ids\n')
    for row in summary:
        f.write('\t'.join(map(str, row)) + '\n')
for row in summary:
    print('%-12s contract=%3d tb=%3d log=%3d' % row)
```

### A.e_check `e_check.py`

```python
"""List contract IDs with no same-key TB label (code or log) and show where the alias table / matrix
point their evidence. Usage: python e_check.py <repo_root> contract_ids.json tb_sites.json log_labels.json"""
import sys, os, re, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family

ROOT = sys.argv[1]
C = json.load(open(sys.argv[2], encoding='utf-8'))['rows']
T = json.load(open(sys.argv[3], encoding='utf-8'))
L = json.load(open(sys.argv[4], encoding='utf-8'))


def key(tok):
    fam = family(tok) if not tok.startswith('SUPRST') else 'SUP'
    m = re.match(r'^-?(\d{1,3})', tok[len(fam):])
    return (fam, int(m.group(1)) if m else None)


have = set()
for s in T:
    for t in s['labels']:
        have.add(key(t))
for tb, ls in L.items():
    for x in ls:
        for t in x['labels']:
            have.add(key(t))
alias = open(os.path.join(ROOT, 'contracts', 'PPG_ALIAS_MAPPING_TABLE.md'), encoding='utf-8').read().split('\n')
matrix = open(os.path.join(ROOT, 'contracts', 'PPG_CONTRACT_CLOSURE_MATRIX.md'), encoding='utf-8').read().split('\n')
out = []
for r in C:
    k = (r['family'], r['num'])
    if k in have:
        continue
    pat = re.compile(r'(?<![A-Za-z0-9])' + re.escape(r['family']) + r'-0?' + str(r['num']) + r'(?![0-9])')
    al = [i + 1 for i, l in enumerate(alias) if pat.search(l)]
    mx = [i + 1 for i, l in enumerate(matrix) if pat.search(l)]
    first_alias = alias[al[0] - 1][:220] if al else ''
    out.append((r['family'], r['id'], r['file'], r['line'], al[:6], mx[:6], first_alias))
for o in out:
    print('\t'.join(map(str, o)))
print('E candidates:', len(out), collections.Counter(o[0] for o in out))
```

### A.decisions `decisions.py`

```python
"""Manual per-ID verdicts from reading TB check code against contract rows (snapshot 2a90a69).
Keys are (family, number). Value: (class, note). Families not listed fall back to FAMILY_DEFAULT."""

CMAP = {
    'PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md': 'C01',
    'ppg_system_config_manager_semantic_contract.md': 'C02',
    'PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': 'C03',
    'PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md': 'C04',
    'ppg_system_active_config_unpack_semantic_contract.md': 'C05',
    'PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md': 'C06',
    'PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md': 'C07',
    'PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md': 'C08',
    'PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md': 'C09',
    'PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': 'C10',
    'PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md': 'C11',
    'PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md': 'C12',
    'PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md': 'C13',
    'PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md': 'C14',
    'PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md': 'C15',
    'PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md': 'C16',
    'PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md': 'C17',
    'PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': 'C18',
    'PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md': 'C19',
    'PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md': 'C20',
    'PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md': 'C21',
    'PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md': 'C22',
    'PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md': 'C23',
    'PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md': 'C24',
    'PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md': 'C25',
    'PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md': '核对表',
    'PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md': '芯片顶层',
}

# default verdict when a contract row and a same-number TB label both exist
FAMILY_DEFAULT = {
    'AMI': ('A', ''), 'SSW': ('A', ''), 'CCC': ('A', 'TB打印为`CCC-n`不补零'), 'MGR': ('A', '仅FAIL分支带编号，PASS只有总横幅'),
    'DCR': ('A', '仅FAIL分支带编号，PASS只有总横幅'), 'PR': ('A', '仅FAIL分支带编号，PASS只有总横幅'),
    'RTR': ('A', '编号只在代码注释里，日志只有总横幅'), 'CAL': ('A', '仅FAIL分支带编号，PASS只有总横幅'),
    'FFK': ('A', ''), 'IDT': ('A', 'C16的IDT条目由IDAC控制器单元TB承担'), 'AMR': ('A', ''), 'AV4C': ('A', ''),
    'UNPACK': ('A', '仅FAIL分支带编号'), 'PWC': ('A', ''), 'PWI': ('A', ''), 'PVW': ('A', ''), 'FIR': ('A', ''),
    'BSL': ('A', ''), 'OPT': ('A', ''), 'TOP': ('A', ''), 'SID': ('A', ''), 'LFA': ('A', ''), 'OIB': ('A', ''),
    'PRC': ('A', ''), 'ILM': ('A', ''), 'RRC': ('A', ''), 'NRE': ('A', ''), 'TRK': ('A', ''),
    'ADCN': ('A', 'TB打印为`ADCN-n`不补零'), 'ISE': ('A', ''), 'RAW': ('A', ''), 'SUP': ('A', ''),
    'FSC': ('B', ''),
}

# ---------- FSC: TB check n meaning (read from check_fsc(n, cond) and the stimulus before it) ----------
FSC_TB = {
    1: '复位后无在途、frame/sample为0、无协议sticky',
    2: 'START后恰1个启动IDAC边界', 3: 'START后首帧前无帧起点/序号/在途',
    4: '首个宏帧在macro tick 0开始', 5: '首个波形fire在tick 0且为RED', 6: '首个owner在tick 1、RED、sample 0',
    7: 'owner快照类型NORMAL及AMB/DC码', 8: 'owner快照AMB/DC epoch', 9: '第2个波形fire在tick 160且为IR',
    10: 'IR owner在tick 161、sample 1', 11: '两色同frame 0、IR DC码', 12: '波形LEDDAC快照=0x29',
    13: 'tick 4760有IDAC边界且启动边界仍为1', 14: '宏帧周期5000（容许5001）', 15: '双光完成事件1次、下一序号2',
    16: 'RED-only：owner RED、1次波形、LEDDAC 0x17', 17: 'RED-only：tick 200前仅1次owner',
    18: 'IR-only：tick 160波形/161 owner', 19: 'safe-off：tick 300前无owner/波形', 20: 'SAR15：owner与波形精度位为1',
    21: 'SAR15：owner tick 161/波形tick 160', 22: 'switch_hold：无帧起点/owner/波形', 23: 'AMB_CAL：owner类型AMB、SAR9、颜色0',
    24: 'AMB_CAL：波形local tick 0、owner local tick 1、DC码0', 25: 'tick 625处校准local tick 0、子帧1',
    26: 'DCS_CAL RED owner', 27: 'DCS_CAL IR owner', 28: '波形上下文未ready→launch超时sticky、无owner',
    29: 'owner未ready→tick 284 RED截止超时sticky', 30: 'IR-only owner未ready→tick 444超时sticky',
    31: '校准owner未ready→tick 260超时sticky', 32: '错误sample index DONE→mismatch sticky且仍在途',
    33: '匹配success=0 DONE释放在途', 34: 'success=0不计NORMAL完成', 35: 'STOP后DONE释放且无NORMAL完成',
    36: '`!idle || owner==1`（弱断言）', 37: 'start_ready=0时abort→不消费序号、无在途', 38: 'AMI故障阻断START后的边界/帧',
    39: 'SSW故障阻断START后的边界/帧', 40: '帧内改LED码不影响当前波形快照', 41: '第2个owner sample 1、共2次提交',
    42: 'start_fire与owner commit同拍、序号1', 43: '`!inflight || owner==1`（弱断言）', 44: 'run_enable掉底：无新owner、宏帧自然收尾',
    45: '诊断清除清协议/mismatch sticky', 46: '复位清在途/序号/launch sticky', 47: '故障解除后可重新START',
    48: '校准tick 385前产生校准IDAC边界', 49: '校准owner frame 0/sample 0', 50: '双光2波形2 owner且≥1 DONE',
    51: 'owner与波形同frame、sample 1', 52: 'tick 300前启动边界1次、宏帧边界0次', 53: 'abort后可重新START',
    54: 'stop_ack保持时START无边界/帧', 55: 'tick 4999处safe_frame_id=current+1', 56: 'RED owner类型NORMAL、SAR9',
    57: '双光后无本地故障/协议sticky（总体健康检查）',
    58: 'CHARACTERIZATION run_profile的合法payload请求不被接受、置协议sticky',
    59: 'EXTERNAL_TEST_CURRENT input_source的请求不被接受、置协议sticky',
    60: 'owner恰在local tick 248提交=按时、无截止事件', 61: 'owner在tick 247提交、无截止事件',
    62: '过tick 248未提交→截止事件1拍落在248、不与提交同拍',
}
# contract FSC-n -> TB checks that actually test its meaning
FSC_COVER = {
    1: [1, 46], 2: [6], 3: [14], 4: [5, 9, 50], 5: [10, 11, 51], 6: [16, 17], 7: [18], 8: [19], 9: [5, 9, 56],
    10: [20, 21], 11: [20], 12: [22], 13: [23, 24], 14: [26], 15: [27], 16: [25], 17: [49, 58, 59], 22: [15],
    25: [41], 26: [55], 28: [7, 40], 29: [28], 30: [32], 31: [35, 36], 32: [37, 53], 33: [45], 36: [42], 37: [29],
    38: [13, 52], 39: [48], 40: [13], 41: [38, 44, 54], 42: [25], 45: [24], 46: [6, 29], 49: [30],
    50: [31, 60, 61, 62], 51: [42], 52: [10, 41, 49], 54: [33, 34], 55: [2, 3], 56: [38, 39, 47],
}

DEC = {}
for n in range(1, 63):
    tb = FSC_TB[n]
    cov = FSC_COVER.get(n)
    cov_txt = ('合同FSC-%02d的同义检查在TB的%s' % (n, '、'.join('FSC-%d' % c for c in cov))) if cov else \
        ('合同FSC-%02d在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围）' % n)
    if n == 1:
        DEC[('FSC', n)] = ('C', 'TB：%s；缺完成事件与其他sticky清零' % tb)
    elif n <= 57:
        DEC[('FSC', n)] = ('B', 'TB FSC-%d实测：%s；%s' % (n, tb, cov_txt))
    else:
        DEC[('FSC', n)] = ('D', 'TB FSC-%d：%s（语义属合同%s）' % (n, tb, 'FSC-17' if n < 60 else 'FSC-50 V1.12补充'))

DEC.update({
    # ---------- SUP (C24 §7) ----------
    ('SUP', 0): ('F', 'SUPRST：复位安全默认值，TB本地编号'),
    ('SUP', 1): ('A', 'SUP01A/01B：首个AMI故障原子快照+三事件各一拍、下一拍不重发'),
    ('SUP', 2): ('A', 'SUP02A（后到记录只置汇总位）+SUP02B（同拍固定优先级）'),
    ('SUP', 3): ('B', 'SUP03A实测"episode开启期间诊断清除无效"（属合同SUP-07前半）；合同SUP-03"新故障胜过同拍清除"无同义检查'),
    ('SUP', 4): ('A', 'SUP04A/04B：丢弃只改丢弃sticky，清除后归零'),
    ('SUP', 5): ('E', '合同SUP-05（外部/系统STOP合并幂等）在supervisor单元TB无标签；矩阵P03称由LFA-11a覆盖abort合并半句，STOP合并幂等未见专门检查'),
    ('SUP', 6): ('C', 'SUP06B（阈值处超时）/SUP06C（idle后恢复）覆盖看门狗边界；"不伪造完成"未直接断言；SUP06A实测episode关闭后阻断解除，不是看门狗（同号不同义的子标签）'),
    ('SUP', 7): ('C', 'SUP07A只测"合法清除去历史"；"清除不能释放活动原因"在SUP03A名下'),
    ('SUP', 8): ('E', '合同SUP-08要求最终Top证明，supervisor单元TB不覆盖；Top级证据见LFA-02b/10a/11'),
    ('SUP', 9): ('B', 'SUP09A实测"看门狗阈值前idle不超时"（属合同SUP-06）；合同SUP-09"阻断故障发一次fault-discard、外部abort不发"仅前半由SUP01A/01B间接覆盖'),
    ('SUP', 10): ('B', 'SUP10A实测"第二个独立episode完整trio+新快照"（K02/N06）；合同SUP-10"AMI本地保留fault-discard原因"在C10 AMI-53，不在本TB'),
    # ---------- AMI (C10 §17) ----------
    ('AMI', 1): ('C', '只查复位期间无结果/校准valid、无fire；未查pending/inflight/fork所有权'),
    ('AMI', 2): ('C', '只查一次start产生一次fire；未查capture/S1同拍接受'),
    ('AMI', 3): ('C', '查资格缺失时ready=0、无fire；"恢复后只启动一次"未查'),
    ('AMI', 4): ('C', '查9-bit结果coarse有效、fine无效；未逐级查元数据'),
    ('AMI', 5): ('C', '查15-bit结果精度=1、颜色IR'),
    ('AMI', 6): ('C', '只查NORMAL进入正式结果；AMB/DCS分支未在此标签下查'),
    ('AMI', 8): ('C', '查两分支传输计数相等>0；独立反压未构造'),
    ('AMI', 9): ('C', '只查9-bit无programmable valid'),
    ('AMI', 10): ('C', '只查9-bit精度位=0（coarse/fine在AMI-04）'),
    ('AMI', 11): ('C', '查15-bit coarse/fine/programmable有效及Stage2 epoch'),
    ('AMI', 12): ('C', '只查反压下结果保持；双fork两种先后顺序未构造'),
    ('AMI', 13): ('待定', 'TB实测反压5拍后同一结果仍保持（无新事务装入）；合同要求"同拍替换、无空泡和覆盖"。是部分覆盖还是同号不同义，需看是否有别处构造同拍替换'),
    ('AMI', 14): ('C', '只查启动搜索完成且AMB码在范围内；握手次数与SID-05重握手不在此标签（见AMI-SID05-1/2）'),
    ('AMI', 15): ('C', '只查DC码在范围内'),
    ('AMI', 16): ('C', '查有调码且正式结果继续交付'),
    ('AMI', 17): ('C', '查3次重检请求、accept、busy清除；逐阶段匹配未单独查'),
    ('AMI', 19): ('C', '查切到15-bit且FIR历史满；旧事务精度未单独查'),
    ('AMI', 20): ('C', '查安全边界前不accept'),
    ('AMI', 21): ('C', '只查STOP后ready=0；排空在AMI-40'),
    ('AMI', 23): ('C', '查结果epoch等于配置快照；未在事务途中改配置（AMI-34做了输入改写）'),
    ('AMI', 24): ('C', '`!o_wrapper_fault_blocking || !o_transaction_start_ready`，此时无阻断故障时恒真（可能空真）'),
    ('AMI', 29): ('C', '只覆盖STOP期间；abort/阻断故障期间未查'),
    ('AMI', 31): ('C', '模块级只能查完成脉冲不重复；Top双消费者连接不在本TB'),
    ('AMI', 33): ('C', '查宏帧边界不fire/不完成；"无兼容别名"为静态条款'),
    ('AMI', 36): ('C', '查启动边界无fire/无宏帧路由/无完成'),
    ('AMI', 37): ('C', '查8拍内无完成；Q3/包络末沿等替代完成未逐一构造'),
    ('AMI', 38): ('C', '逐字段比较身份；内部失败success=0路径不在此标签'),
    ('AMI', 42): ('C', '查切换后pending与epoch保持'),
    ('AMI', 46): ('E', '单元TB旧AMI-46已改名AMI-DISC-1（2bb6b17）；C10第30行自述AMI-46至AMI-55为EVIDENCE_PENDING；顶层注入默认关闭证据见TOP-21/INJ-01'),
    ('AMI', 47): ('E', '同上；identity请求绑定的顶层证据见INJ-02/TOP-22。矩阵947/3724/3731/3736、别名表545仍以"AMI-47"指旧TB discard检查（历史叙述，用户决定不改）'),
    ('AMI', 48): ('E', '单元TB旧AMI-48已改名AMI-SID05-1；matcher拒绝的顶层证据见LFA-08/INJ-02'),
    ('AMI', 49): ('E', '单元TB旧AMI-49已改名AMI-SID05-2；identity恢复的顶层证据见INJ-02/LFA-04'),
    ('AMI', 50): ('E', 'invalid请求绑定：顶层证据见INJ-03/PRC-08/TOP-23'),
    ('AMI', 51): ('E', 'invalid正式sideband：顶层证据见INJ-03'),
    ('AMI', 52): ('E', 'invalid检测隔离：顶层证据见PRC-09/10'),
    ('AMI', 53): ('E', '延迟fault-discard原因：顶层证据见LFA-02b'),
    ('AMI', 54): ('E', '别名表89行与矩阵3603/3627/3656：随Acceptance-D01-01（D01-01b）一起登记'),
    # ---------- DCR (C15 §15) ----------
    ('DCR', 3): ('B', 'TB drive_and_check(3,…)实测9-bit且DC码0时DC项为0（属合同DCR-04）；合同DCR-03"9-bit正负边界"无同义检查'),
    ('DCR', 4): ('B', 'TB DCR-4实测15-bit双结果+K_DC15通路（DC码3）（属合同DCR-07/11）；合同DCR-04由TB DCR-3覆盖'),
    ('DCR', 5): ('B', 'TB DCR-5实测CHARACTERIZATION下恢复系数无效时资格为0（属合同DCR-12）；合同DCR-05"K_DC9每增1"仅由TB DCR-2的单点（DC码2）间接覆盖'),
    ('DCR', 6): ('B', 'TB DCR-6实测24-bit正端饱和（属合同DCR-09）；合同DCR-06"15-bit DC码0"无同义检查'),
    ('DCR', 7): ('B', 'TB DCR-7实测24-bit负端饱和（属合同DCR-09）；合同DCR-07由TB DCR-4部分覆盖'),
    ('DCR', 9): ('A', 'FAIL标签DCR-09；用force内部舍入网覆盖端点'),
    ('DCR', 11): ('E', '无同名标签；内容由TB DCR-4（15-bit双结果）覆盖'),
    ('DCR', 13): ('E', '无同名标签；"模块不伪造校准资格"由TB DCR-5覆盖，"系统不允许正式启动"属系统级'),
    ('DCR', 15): ('A', 'FAIL标签"DCR-15/17 backpressure hold"'),
    ('DCR', 17): ('E', '只出现在组合标签"DCR-15/17"中：反压期间改增益/epoch后保持'),
    # ---------- SSW (C09 §10) ----------
    ('SSW', 11): ('C', '查每个子帧Q3在local tick 266、AMB_CAL不驱动Q2；local tick由TB直接驱动，625周期间隔未实测'),
    ('SSW', 18): ('B', 'TB SSW-18实测"校准owner缺失在tick 249前超时"（属合同SSW-37/38）；合同SSW-18"tick 385前未准备下一码终止burst"无同义检查'),
    ('SSW', 24): ('C', '只测一种光学模式；RED_ONLY/IR_ONLY/OFF未逐一构造'),
    ('SSW', 29): ('C', '同SSW-24，只测一种模式'),
    # ---------- others ----------
    ('CCC', 12): ('C', '只查一组相位下的结果与计数，"不同相位"未见循环'),
    ('MGR', 12): ('C', 'TB覆盖0x03/0x04/0x06/0x08/0x09/0x0e/0x0f；合同列出的0x05未测（TB注释称原IDAC枚举场景已按V4.9改判0x15，即MGR-20）。0x05是否仍可达待定'),
    ('MGR', 21): ('E', '无标签；合同第385行要求在三模块联合TB验证；总横幅"MGR-01 through MGR-24"含此项'),
    ('MGR', 23): ('E', '无同名标签；OFF返回0x16由TB的"MGR-18 fixed current optical off rejection"检查（合同MGR-18也列0x16，两条目重叠）'),
    ('PR', 13): ('E', '只出现在组合标签"PR-09/13"中'),
    ('AV4C', 1): ('A', '标签文字仍写"640-bit atomic CDC"，比较的是当前1024-bit ACTIVE'),
    ('AV4C', 3): ('C', '与AV4C-02共用同一组比较后打印PASS'),
    ('AV4C', 15): ('C', '与AV4C-02共用同一组比较后打印PASS'),
    ('AV4C', 17): ('C', '与AV4C-02共用同一组比较后打印PASS'),
    ('AMR', 8): ('E', '无同名标签；受限二分重搜索由IDAC控制器TB的PERIODIC描述行覆盖（无编号）'),
    ('AMR', 9): ('E', '同AMR-08'),
    ('AMR', 13): ('E', '无同名标签；"AMB_CHECK事务进PPG链必须判失败"未见专门检查'),
    ('PWI', 6): ('E', 'PWI单元TB只有PWI-01~05；C18第659行却写"xsim中PWI-01至PWI-07全部真实比较PASS"（合同自述超出TB）'),
    ('PWI', 7): ('E', '同PWI-06'),
    ('PWI', 8): ('E', '别名表89行：随Acceptance-D01-01登记'),
    ('BSL', 40): ('E', '别名表89行：随Acceptance-D01-01登记'),
    ('LFA', 8): ('E', '无同名PASS；证据在注入TB的INJ-02名下（别名表TOP-22=LFA-08）'),
    ('LFA', 10): ('C', 'LFA-10a覆盖AMI侧；LFA-10b打印SKIP（SSW侧该构造路径结构性不可达）'),
    ('LFA', 11): ('C', 'LFA-11b覆盖"合法恢复后清除生效"；LFA-11a实测"supervisor自动abort释放owner期间无虚假正式结果"（属合同§9.5.1规则5/P03，同号不同义的子标签，且两个分支都打印PASS）；"活动故障在清除后继续阻断"未断言'),
    ('PRC', 5): ('C', 'PASS行是无条件$display引用RGC-06证据，本TB不做比较'),
    ('PRC', 8): ('C', 'PASS行是无条件$display引用INJ-03证据，本TB不做比较'),
    ('ISE', 6): ('C', 'PASS行自注"只覆盖STATIC_BIAS子句，AMB_CAL/DCS_CAL子句另组"'),
    ('ISE', 2): ('E', '无独立PASS，出现在组合PASS行"ISE-01/02/03"中（别名表282行）'),
    ('ISE', 7): ('E', '无同名标签；别名表277/287行指向ISE-04/05的非对称码型检查'),
    ('ADCN', 4): ('E', '无独立PASS；别名表267/269行：隐含在ADCN-1/2/3行的"SAR9 fine_valid unexpectedly asserted"未触发'),
    ('ADCN', 7): ('E', '无独立PASS；别名表260/270/271行'),
    ('ADCN', 9): ('E', '无独立PASS；别名表272行指向阶段C饱和边界'),
    ('OIB', 4): ('E', '别名表165/172-175行：结构性满足、无独立PASS'),
    ('OIB', 10): ('E', '别名表165/172-173行：静态分析+结构性满足'),
    ('SID', 3): ('A', '仅FAIL分支带编号'), ('SID', 7): ('A', '仅FAIL分支带编号'), ('ILM', 9): ('A', '仅FAIL分支带编号（别名表记为半覆盖）'),
})
for n in (8, 10, 11, 12, 17, 19, 21, 22, 23, 24):
    DEC.setdefault(('TOP', n), ('E', ''))
DEC[('TOP', 8)] = ('E', '别名表35/255行：SMOKE-19(?)，C01第942行映射')
DEC[('TOP', 10)] = ('E', '别名表37行：综合层次静态检查，非仿真')
DEC[('TOP', 11)] = ('E', '别名表38行：SID-01')
DEC[('TOP', 12)] = ('E', '别名表39行：SMOKE-12(?)')
DEC[('TOP', 17)] = ('E', '别名表：tb_ppg_control_top.v扇出监测器（无编号）')
DEC[('TOP', 19)] = ('E', '别名表44行：SMOKE-21/22(?)')
DEC[('TOP', 21)] = ('E', '别名表46行：INJ-01')
DEC[('TOP', 22)] = ('E', '别名表47行：INJ-02（=LFA-08）')
DEC[('TOP', 23)] = ('E', '别名表48行：INJ-03（=PRC-08）')
DEC[('TOP', 24)] = ('E', '别名表49行：INJ-04')
for n in range(1, 12):
    DEC[('RAW', n)] = ('E', '无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照）')

# contract-only families: one shared note each
CONTRACT_ONLY = {
    'AV4': ('E', 'C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖'),
    'CIS': ('E', 'C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC'),
    'IDC2': ('E', 'C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签'),
    'CF4': ('E', 'C16第15.4节ACTIVE V4字段检查，无TB标签；内容属MGR/AV4C'),
    'PC': ('N/A', '核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID'),
}
# TB-only families
TB_ONLY = {
    'AMI-DISC': ('F', 'TB本地：C10第6.10节公开discard端口检查（原AMI-46/47）'),
    'AMI-SID05': ('F', 'TB本地：SID-05截止事件单元断言（原AMI-48/49），带@satisfies: SID-05'),
    'N08': ('F', 'TB本地：矩阵N08交接前半检查'),
    'OVL': ('D', 'C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17'),
    'OPTC': ('D', 'C21只定义OPT-01~24；OPTC-01/02（共享乘法器）未登记'),
    'JNT': ('D', '联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB'),
    'RGC': ('F', 'TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记'),
    'SMOKE': ('F', 'TB本地：顶层冒烟场景；C01第942行用它作TOP证据'),
    'NPA': ('F', 'TB本地：Priority-1a NPA端口检查'),
    'INJ': ('F', 'TB本地：注入场景；C01第946行与别名表用它作TOP-21~24/LFA-08/PRC-08证据'),
    'D01': ('F', 'TB本地：矩阵Acceptance-D01-01a/b子检查'),
    'TC': ('F', '芯片顶层TB本地；芯片顶层合同无验收ID族，TC6/TC7被合同正文引用'),
}
```

### A.gen_table `gen_table.py`

```python
"""Build the per-ID comparison table and per-family statistics for the report.
Usage: python gen_table.py <repo_root> contract_ids.json tb_sites.json log_labels.json out_table.md out_stats.md"""
import sys, os, re, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family
from decisions import DEC, FAMILY_DEFAULT, CONTRACT_ONLY, TB_ONLY, CMAP

ROOT = sys.argv[1]
C = json.load(open(sys.argv[2], encoding='utf-8'))['rows']
T = json.load(open(sys.argv[3], encoding='utf-8'))
L = json.load(open(sys.argv[4], encoding='utf-8'))
BANNER = re.compile(r'(through|THROUGH|\.\.|至| TO )')


def key(tok):
    if tok == 'SUPRST':
        return ('SUP', 0)
    fam = family(tok)
    m = re.match(r'^-?(\d{1,3})', tok[len(fam):])
    return (fam, int(m.group(1)) if m else None)


crow = collections.defaultdict(list)
for r in C:
    crow[(r['family'], r['num'])].append(r)
tsite = collections.defaultdict(list)
banner = collections.defaultdict(list)
for s in T:
    for t in dict.fromkeys(s['labels']):
        k = key(t)
        (banner if (s['kind'] in ('pass', 'other') and BANNER.search(s['literal']) and len(s['labels']) > 1)
         else tsite)[k].append((s, t))
printed = collections.defaultdict(set)
for tb, ls in L.items():
    for x in ls:
        if x['verdict'] != 'PASS':
            continue
        for t in x['labels']:
            printed[key(t)].add(t)
contract_fams = {r['family'] for r in C}
alias = open(os.path.join(ROOT, 'contracts', 'PPG_ALIAS_MAPPING_TABLE.md'), encoding='utf-8').read().split('\n')


def alias_lines(fam, num):
    pat = re.compile(r'(?<![A-Za-z0-9])' + re.escape(fam) + r'-0?' + str(num) + r'(?![0-9])')
    return [i + 1 for i, l in enumerate(alias) if pat.search(l)]


keys = sorted(set(crow) | set(tsite), key=lambda k: (k[0], k[1] if k[1] is not None else -1))
rows = []
for k in keys:
    fam, num = k
    cr = crow.get(k, [])
    ts = tsite.get(k, [])
    cloc = '; '.join('%s:%d' % (CMAP.get(r['file'], r['file']), r['line']) for r in cr) or '—'
    files = collections.OrderedDict()
    for s, t in ts:
        files.setdefault(os.path.splitext(s['file'].split('/')[-1])[0].replace('tb_ppg_', ''), []).append((s['line'], t))
    tloc = '; '.join('%s:%s' % (f, ','.join(str(l) for l, _ in v[:3]) + ('…' if len(v) > 3 else '')) for f, v in files.items()) or '—'
    subs = sorted({t for _, t in ts if re.search(r'\d[A-Za-z]$|-[A-Z]+$|\d-\d', t)})
    if k in DEC:
        cls, note = DEC[k]
    elif fam in TB_ONLY:
        cls, note = TB_ONLY[fam]
    elif fam in CONTRACT_ONLY:
        cls, note = CONTRACT_ONLY[fam]
    elif cr and (ts or fam == 'RTR'):
        cls, note = FAMILY_DEFAULT.get(fam, ('A', ''))
    elif cr:
        al = alias_lines(fam, num)
        cls, note = 'E', ('无同名TB标签；别名表%s行' % '/'.join(map(str, al[:5]))) if al else '无同名TB标签，别名表无映射'
    else:
        cls, note = ('D' if fam in contract_fams else 'F'), '合同无此编号' if fam in contract_fams else 'TB本地编号'
    if not printed.get(k) and ts and cls in ('A', 'C') and 'FAIL' not in note and '注释' not in note and '组合' not in note:
        if all(s['kind'] in ('fail',) for s, _ in ts):
            note = (note + '；' if note else '') + '仅FAIL分支带编号'
    if subs:
        note = (note + '；' if note else '') + '子标签：' + '、'.join(subs[:6])
    title = (cr[0]['cells'][0] if cr and cr[0]['cells'] else '').replace('|', '/')[:40]
    idtxt = 'SUPRST' if k == ('SUP', 0) else '%s-%02d' % (fam, num) if num is not None else fam
    rows.append((fam, idtxt, title, cloc, tloc, cls, note.replace('|', '/')))

with open(sys.argv[5], 'w', encoding='utf-8') as f:
    f.write('| 族 | 编号 | 合同条目标题 | 合同位置 | TB位置（文件:行） | 分类 | 说明 |\n| --- | --- | --- | --- | --- | --- | --- |\n')
    for r in rows:
        f.write('| ' + ' | '.join(r) + ' |\n')
stat = collections.defaultdict(collections.Counter)
for r in rows:
    stat[r[0]][r[5]] += 1
tot = collections.Counter(r[5] for r in rows)
with open(sys.argv[6], 'w', encoding='utf-8') as f:
    cls_order = ['A', 'B', 'C', 'D', 'E', 'F', '待定', 'N/A']
    f.write('| 族 | 合同条目数 | TB带编号检查数 | ' + ' | '.join(cls_order) + ' |\n| --- | ---: | ---: | ' + ' | '.join(['---:'] * len(cls_order)) + ' |\n')
    for fam in sorted(stat):
        nc = sum(1 for k in crow if k[0] == fam)
        nt = sum(1 for k in tsite if k[0] == fam)
        f.write('| %s | %d | %d | ' % (fam, nc, nt) + ' | '.join(str(stat[fam].get(c, 0)) for c in cls_order) + ' |\n')
    f.write('| **合计** | %d | %d | ' % (len(crow), len(tsite)) + ' | '.join(str(tot.get(c, 0)) for c in cls_order) + ' |\n')
print(len(rows), dict(tot))
```

### A.tb_stats `tb_stats.py`

```python
"""TB-side statistics per TB file: families, distinct labels in code, labels seen on PASS lines of the real log.
Usage: python tb_stats.py tb_sites.json log_labels.json out.md"""
import sys, os, re, json, collections
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family

T = json.load(open(sys.argv[1], encoding='utf-8'))
L = json.load(open(sys.argv[2], encoding='utf-8'))
BANNER = re.compile(r'(through|THROUGH|\.\.|至| TO )')
code = collections.defaultdict(set)
fams = collections.defaultdict(set)
banners = collections.defaultdict(set)
for s in T:
    tb = s['file'].split('/')[-1].rsplit('.', 1)[0]
    if s['kind'] in ('pass', 'other') and BANNER.search(s['literal']) and len(s['labels']) > 1:
        banners[tb].add(s['literal'][:70])
        continue
    for t in s['labels']:
        code[tb].add(t)
        fams[tb].add(family(t) if t != 'SUPRST' else 'SUP')
with open(sys.argv[3], 'w', encoding='utf-8') as f:
    f.write('| TB | 编号族 | 代码中不同标签数 | 实际日志PASS行出现的标签数 | 总横幅 |\n| --- | --- | ---: | ---: | --- |\n')
    for tb in sorted(set(code) | set(banners)):
        seen = {t for x in L.get(tb, []) if x['verdict'] == 'PASS' for t in x['labels']} & code[tb]
        f.write('| %s | %s | %d | %d | %s |\n' % (tb, '、'.join(sorted(fams[tb])), len(code[tb]), len(seen),
                                                  '；'.join('`%s`' % b for b in sorted(banners[tb])) or '—'))
print('ok')
```

### A.rescan_diff `rescan_diff.py`

```python
"""Re-scan gate for the merge batch: compare a new TB-label scan against the audited baseline.
Usage: python rescan_diff.py baseline_tb_sites.json new_tb_sites.json contract_ids.json
Reports, for labels whose family owns a contract table:
  B?  a (file, label, check-code) site that did not exist in the baseline -> its meaning must be re-read
      against the contract row of the same number (possible same-number-different-meaning);
  D   a label number that the contract table does not define and the baseline did not already carry.
Line numbers are ignored; only the label and the whitespace-normalised check code are compared."""
import sys, os, re, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from scan_tb_labels_lib import family

base = json.load(open(sys.argv[1], encoding='utf-8'))
new = json.load(open(sys.argv[2], encoding='utf-8'))
rows = json.load(open(sys.argv[3], encoding='utf-8'))['rows']
BANNER = re.compile(r'(through|THROUGH|\.\.|至| TO )')
table = {}
for r in rows:
    table.setdefault(r['family'], set()).add(r['num'])


def num(t):
    m = re.match(r'^-?(\d{1,3})', t[len(family(t)):]) if t != 'SUPRST' else None
    return int(m.group(1)) if m else None


def prints(sites):
    out = set()
    for s in sites:
        if s['kind'] in ('pass', 'other') and BANNER.search(s['literal']) and len(s['labels']) > 1:
            continue  # range banners are judged separately, not per check
        ctx = re.sub(r'\s+', ' ', s['ctx']).strip()
        for t in s['labels']:
            out.add((s['file'], t, ctx))
    return out


b, n = prints(base), prints(new)
b_labels = {(f, t) for f, t, _ in b}
reports = []
for f, t, ctx in sorted(n - b):
    fam = family(t) if t != 'SUPRST' else 'SUP'
    if fam not in table:
        continue
    k = num(t)
    if k is not None and k not in table[fam] and (f, t) not in b_labels:
        reports.append(('D', f, t, ctx[:160]))
    elif k is not None and k in table[fam]:
        reports.append(('B?', f, t, ctx[:160]))
for r in reports:
    print('\t'.join(r))
print('reports=%d' % len(reports))
```


## 附录B 负对照与运行记录

### B.1 负对照（在仓库外副本中进行）

1. 空跑：以本快照扫描结果为基线和新扫描，`rescan_diff.py tb_sites.json tb_sites.json contract_ids.json`输出`reports=0`。
2. 注入：复制快照到`neg/`，在`rtl/ppg_precision_window_controller/tb_ppg_precision_window_controller.v`的PWC-41第二个检查之后插入两行：

```verilog
		check_case("PWC-05 injected same-number check", o_protocol_error_sticky); // negative control: same number, different meaning
		check_case("PWC-42 injected unregistered check", o_switch_timeout_sticky); // negative control: unregistered number
```

3. 重扫与比对：`scan_tb_labels.py neg tb_sites_neg.json`后运行`rescan_diff.py tb_sites.json tb_sites_neg.json contract_ids.json`，输出：

```text
B?	rtl/ppg_precision_window_controller/tb_ppg_precision_window_controller.v	PWC-05	check_case("PWC-05 injected same-number check", o_protocol_error_sticky);
D	rtl/ppg_precision_window_controller/tb_ppg_precision_window_controller.v	PWC-42	check_case("PWC-42 injected unregistered check", o_switch_timeout_sticky);
reports=2
```

恰好报出注入的两处，所以采信扫描结果。（第一次注入时sed把两行拼成了一行，第二行落进注释，只报出1处；随后改用Python逐行插入重做，上面记录的是重做的结果。）

### B.2 扫描器自身的订正

- 合同侧：正文范围检测最初用`\b`做边界，中文紧邻数字时失效，漏掉了C10的“AMI-46至AMI-55”；改为显式前后界后报出。另外放宽了首列匹配，`MGR-01复位`这种编号与标题同格的写法因此被收进来（MGR 24条、PVW-47/48）。
- TB侧：最初的标签语法不认`TC4a`这种字母后缀，漏掉了芯片TB的TC4a/TC4b；修正后重扫。PR TB补了`send_transaction(n,…)`规则。

### B.3 核对脚本运行（仓库外副本）

| 运行 | 结果 |
|---|---|
| 原样运行 `python tools/cross_reference_tools/reconcile_acceptance_ids.py --json …` | 301个ID：B2_ALIAS_ROW_MISSING 299、D_PENDING_KNOWN 1、D2_NO_STATUS_FOUND 1（找不到`ppg_system_integration/`） |
| 副本中把`INTEGRATION_DIR`与`CONTRACT_GLOBS`改为`contracts/` | 328个ID：A_CONSISTENT 266、B_TAG_MISSING 23、B2_ALIAS_ROW_MISSING 22（全是TB修订记录叙述文字产生的伪ID）、D_PENDING_KNOWN 1、E_STALE_MATRIX_TEXT 16 |
