# B合同合并批次报告（B_MERGE_BATCH_REPORT_20261009）

> 依据：`verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`（下称“交接书”）§7。
> 分支：`b-merge-batch`；基线：`7a8eabf`；终版回归提交：`5d8ceba`；终版回归证据：`b161d13`。
> 分支最终提交是本报告所在的提交（`b-merge-batch` HEAD）。相对终版回归提交`5d8ceba`的改动如下，可用`git diff --stat 5d8ceba HEAD`复核：`rtl/`只有一处注释改动（supervisor补`@satisfies: SUP-08`，去注释后与`7a8eabf`逐字节相同，见`final_strip_proof/`）；`contracts/`为锚点第二轮、C24 V1.7（SUP-08改写）及其版本联动、别名表SUP-08行、矩阵§13.1与§12.4a；`tools/`为锚点工具第二轮（`anchor_history_rules.py`、增量写入与复核）、`verlink`第二次联动、reconcile报告刷新。TB与RTL逻辑没有改动，统筹已裁定这些改动不需要重跑全套回归，终版回归结论适用于分支HEAD。
> 总表：`verification_reports/B_MERGE_BATCH_ITEMS.md`。进度记录：`verification_reports/B_MERGE_BATCH_PROGRESS.md`（条目1~17）。
> 二级清单：`verification_reports/POST_TAPEOUT_DOC_CLEANUP_LIST.md`。证据目录：`verification_reports/b_merge_batch_evidence/`。

---

## 0. 结论

- **合同、矩阵、别名表已按基线`7a8eabf`的RTL一次性改对。** 总表138项中：
  - 已完成116项（含并入BMI-133的BMI-012）；
  - 只登记或不做8项，各有理由（§3）；
  - 二级登记2项，已进二级清单；
  - 排除项12项，各有去向（§3.3；BMI-911为统筹10-09裁定新增）；
  - 待裁定0项。报告初稿§9列出的6项执行判断，统筹已于2026-10-09裁定并已执行（§9）。
- **RTL逻辑没有改动。** 6个RTL文件只动了注释：§3.9点名的3处，加上`@satisfies`17处（含按统筹裁定补的SUP-08）。去掉注释后，与`7a8eabf`逐字节相同。
- **TB只改了标签字符串。** 7个TB去掉注释和字符串后与`7a8eabf`相同（§5）。
- **符号锚点体系已建立并接入门禁。**
  - 矩阵与别名表的9702个旧行号锚点全部有了去向：9254处改为符号锚点；440处作为历史保留（①删除线内8、②"> "历史块30、③被后续条目取代的旧条目402）；8处为非锚点、仓库外引用或其它历史。按统筹10-09裁定，带日期的现行结论也已转换（锚点第二轮，§8）。
  - `anchor_check.py`在HEAD上0报错。
  - 门禁接在模块级回归入口开头，检查失败则整轮报错。回归机上做过两次演示：一次通过，一次负对照失败。
- **回归：基线与终版在同一台回归机上用同一分组运行**（i5-10400，Vivado 2022.2）。
  - 两次结果都是：系统20/20、PASS 1250行、芯片20/0、模块级28/28。
  - `$finish`的时刻和文件名49/49相同。
  - PASS行差异只出现在7个改名TB中，逐行反向映射后与基线完全一致（§4）。
- **矩阵§12.4a**的26行SHA-256由脚本生成。HEAD上26/26相符，干净导出目录中同样26/26。

## 1. 交付物

| 交付物 | 位置 |
|---|---|
| 合同、矩阵、别名表修改 | 阶段2按合同分组提交（附录B），阶段3~5为TB标签改名、锚点符号化、§13与§12.4a |
| 符号锚点检查脚本 | `tools/b_merge_tools/anchor_check.py`，门禁包装`run_anchor_gate.sh`，用法见`tools/b_merge_tools/README.md` |
| 摘要生成脚本 | `tools/b_merge_tools/manifest_digest.py` |
| 锚点转换工具 | `anchor_inventory.py`、`anchor_resolve.py`、`anchor_manual_seed.py`（人工判定表`anchor_manual_decisions.tsv`）、`anchor_mapping.py`、`anchor_apply.py`、`anchor_verify.py` |
| 其它校验工具 | `strip_compare.py`（去注释/去字符串比对）、`gate_compare.py`（deliverable gate前后比对）、`regression_evidence.py`（回归证据导出与比对）、`verlink.py`/`verlink_check.py`（版本联动）、`tb_rename.py`/`tb_rename_bmi145.py`（TB改名）、`tools/id_governance_scan/`（编号扫描器） |
| 总表（终版状态） | `verification_reports/B_MERGE_BATCH_ITEMS.md` |
| 二级清单 | `verification_reports/POST_TAPEOUT_DOC_CLEANUP_LIST.md` |
| 回归比对证据 | `b_merge_batch_evidence/baseline_7a8eabf/`、`final_5d8ceba/`（含`compare.txt`） |

## 2. 总表每项的处置

逐项状态见总表最后一列。按类别汇总如下：

| 类别 | 条数 | 处置 |
|---|---:|---|
| 一级（合同、矩阵、别名表） | 99 | 已完成。阶段2按合同分组提交：C08 V1.13、C09 V1.11、C10 V2.5、C24 V1.6、C16 V2.2、C18 V2.2、C23 V2.7、C17 V2.4、C13 V1.3、C25 V1.8、C01 V1.18勘误、芯片顶层合同V1.17勘误、C02 V4.10、C07 V1.2、C19 V2.6、C03 V1.7、C21 V1.3、核对表§15、矩阵V4.5。然后做版本联动：207处引用逐条核对。阶段3写入别名表映射，阶段4~5完成锚点、§13、§12.4a |
| 一级（合同侧）＋TB标签 | 1 | BMI-103：合同LFA-11前半句如实写明无断言；TB子标签LFA-11a改为AUTOABT-QUIET |
| TB标签 | 6 | BMI-140~145已完成（§5.2） |
| 工具 | 8 | 已完成（§6） |
| RTL注释 | 2 | BMI-155（§3.9）、BMI-160（`@satisfies`）已完成（§5.1） |
| 二级登记 | 2 | BMI-181、186：进入二级清单D-01、D-02 |
| 三级/历史叙述 | 2 | BMI-126、190：不改，属历史叙述 |
| 只登记不做 | 2 | BMI-056、102：交接书Q6规定不改TB判定和PASS行数 |
| RTL疑点 | 1 | BMI-057（§7） |
| 不做 | 3 | BMI-161：交接书§0.3规定TB只允许改PASS标签。BMI-188、189：核对后无需改 |
| 排除项 | 11 | BMI-900~910，去向见§3.3 |

阶段2改写合同时，有两处是核对RTL才发现的。两处都按RTL订正了合同，RTL没有改：
- **BMI-058**：C10 §6.11写的私有datapath discard扇出范围比RTL宽。RTL中只有fork和overlap有`i_datapath_discard_*`端口。
- **BMI-064**：C13写`o_local_empty`的唯一消费者是AMI，并用于`o_datapath_empty`。RTL中AMI只把它接出供观测。

## 3. 不做或延后的项，以及原因

### 3.1 本批不做

| 编号 | 事项 | 原因 |
|---|---|---|
| BMI-056、102 | 改TB判定，或改PASS行数（PRC-05/08） | 交接书Q6只允许登记 |
| BMI-057 | AMI注释与实现不符 | RTL疑点只登记（§7） |
| BMI-126、190 | 历史叙述中的旧编号或旧版本 | 历史叙述不改 |
| BMI-161 | TB侧`@satisfies` | 交接书§0.3：TB只允许改PASS标签 |
| BMI-188、189 | C22 §11.4、C02 | 核对后与RTL一致，无需改 |
| SID-05的`@satisfies` | BMI-160清单中的一项 | 合同含义与代码不完全一致，所以不补：SID-05讲的是截止撤销，owner-lost测试验证的是作废撤销。（SUP-08原也不补，统筹10-09裁定后C24改写为V1.7并已补，§9-4） |
| PR/RTR/CAL/CCC/OVL/AV4C区间横幅 | BMI-145 | 区间内的条目都有同义检查：PR-13在组合标签“PR-09/13”中检查。只有MGR区间含无检查条目（MGR-21），因此只改了MGR横幅 |

### 3.2 二级清单

BMI-181（C02 MGR-18与MGR-23重叠）、BMI-186（C22 PVW-47/48表格多一列）：见`POST_TAPEOUT_DOC_CLEANUP_LIST.md` D-01、D-02。

### 3.3 排除项（交接书§3.8、§8）

| 编号 | 事项 | 去向 |
|---|---|---|
| BMI-900~904、906 | 生命周期§7.1(d)(e)(f)后续、IR提交窗口不一致、TB容差审计、L-6扫描覆盖面、240拍建立预算、F-1实测 | 流片前验证收尾计划（BMI-904需模拟侧确认） |
| BMI-905 | 补测试：FSC-19/23/24/27/44、SSW-18 sticky置1检查 | 本批次之后 |
| BMI-907 | 纯丢DONE变体、L-5 | 用户10-09已定：纯丢DONE变体进收尾计划的逐拍扫描；L-5保留为纵深防御，不可达证明进收尾计划的形式验证 |
| BMI-908 | dynamic baseline TB的EQV采样竞争；芯片层没有验收ID | 只登记 |
| BMI-909 | MGR未使用的`ERROR_ENUM_ENCODING` | RTL注释/清理轮 |
| BMI-910 | IDC2/CIS/AV4/CF4逐条对照 | 流片前验证收尾计划；本批只在别名表做族级登记 |
| BMI-911 | reconcile报告E_STALE_MATRIX_TEXT 16项与B_TAG_MISSING 22项的逐ID闭环 | 流片前验证收尾计划V8逐ID闭环，不进二级清单（统筹10-09裁定；ID清单见总表BMI-911与矩阵§13.1） |
| MGR-21 | 校准责任边界，合同要求三模块联合TB | 单元TB无此检查；MGR横幅已注明例外（BMI-145）。补检查属补测试 |

## 4. 回归比对结论

### 4.1 环境

- **本机Vivado 2019.2只作参考。** 本机基线中途被打断：Claude进程退出时，后台仿真被一并结束。另外，`tb_ppg_coarse_detection_fir`的xelab在“Completed static elaboration”后确定性崩溃（`EXCEPTION_ACCESS_VIOLATION`）。在无其它负载时重跑两次，都在同一位置崩溃，判为2019.2的工具缺陷。没有改RTL或TB。
  - 本机已跑完的44个TB，PASS行与`$finish`与2022.2结果完全相同（旁观会话核对）。
  - 本机部分证据在`baseline_7a8eabf_vivado2019.2_partial/`（`24d0b8d`）。
- **正式基线与终版**都在回归机上运行：i5-10400，Vivado Simulator v2022.2，同一分组，在`git archive`导出目录中执行（交接书§6.8）。运行与回传方法见`REGRESSION_RUN_REQUEST.md`。分支最终提交是本报告所在的提交（`b-merge-batch` HEAD）。相对终版回归提交`5d8ceba`的改动如下，可用`git diff --stat 5d8ceba HEAD`复核：`rtl/`只有一处注释改动（supervisor补`@satisfies: SUP-08`，去注释后与`7a8eabf`逐字节相同，见`final_strip_proof/`）；`contracts/`为锚点第二轮、C24 V1.7（SUP-08改写）及其版本联动、别名表SUP-08行、矩阵§13.1与§12.4a；`tools/`为锚点工具第二轮（`anchor_history_rules.py`、增量写入与复核）、`verlink`第二次联动、reconcile报告刷新。TB与RTL逻辑没有改动，统筹已裁定这些改动不需要重跑全套回归，终版回归结论适用于分支HEAD。
  - 基线证据：`ea60432`（`baseline_7a8eabf/`）。
  - 终版证据：`b161d13`（`final_5d8ceba/`）。
  - 两次回归的`raw/`下各有49个xsim.log。`.gitignore`忽略`*.log`，这些日志是用`git add -f`加入的，`.gitignore`没有改。

### 4.2 结果

| 部分 | 基线`7a8eabf` | 终版`5d8ceba` |
|---|---|---|
| 系统级 | 20/20（rc全0、0 FAIL、`$finish`各1次），PASS 1250行 | 相同 |
| 芯片 | 20/0 | 相同 |
| 模块级 | 28/28（含FIR） | 相同 |

`regression_evidence.py compare baseline_7a8eabf final_5d8ceba`的结果如下（`final_5d8ceba/compare.txt`）：

- 退出码0；SAME 42；`PASSDIFF`+`FINISH_LINE_SHIFT` 7。
- 49个TB的`$finish`时刻与文件名全部相同。
- 7个TB的`$finish`源码行号后移2行，原因是文件头新增了2行修订记录注释。这7个TB是：6个改名TB，加上BMI-145改了横幅的MGR TB。
- 各TB的PASS行数不变。
- 本会话独立复算：把终版PASS行中的新标签反向映射回旧标签后，7个TB的排序PASS行集合与基线逐行相等。
- 旁观会话另从`raw/`原始日志独立重算，结论相同。

| TB | PASS行 | 改变的行 | 来源 |
|---|---:|---:|---|
| `tb_ppg_400hz_frame_calibration_scheduler` | 77 | 62 | FSC-n→SCHT-n，总横幅 |
| `tb_ppg_system_fault_abort_supervisor` | 19 | 5 | SUP03A/06A/09A/10A→CLRBLK/EPICLS/WDIDLE/EPI2ND，横幅 |
| `tb_ppg_adc_measurement_idac_integration` | 79 | 2 | AMI-13→FORK-HOLD，横幅 |
| `tb_ppg_adc_dc_recovery` | 2 | 1 | 横幅（FAIL前缀DCRT-不出现在PASS行） |
| `tb_ppg_sar9_sar15_safe_selection_wrapper` | 60 | 1 | SSW-18→CAL-ODL |
| `tb_ppg_control_top_lifecycle_fault_adc_anomaly` | 80 | 1 | LFA-11a→AUTOABT-QUIET |
| `tb_ppg_system_config_manager` | 1 | 1 | 横幅（除去MGR-21） |

### 4.3 回归过程中修正的工具问题

1. **`regression_evidence.py compare`（`dc7175a`）。** 原先按整行比较`$finish`，行号后移会被误报为`FINISH_DIFF`。现改为按（时刻，文件名）比较；只有行号不同时标`FINISH_LINE_SHIFT`，不计为问题。负对照：自比49 SAME；只改行号报`FINISH_LINE_SHIFT`，退出0；改时刻报`FINISH_DIFF`，退出1（`regression_compare_negctl/`）。
2. **锚点门禁（`871ff61`）。** `c64e9dc`中的`anchor_check.py`用`git ls-files`建文件索引。导出目录不是git仓库，索引为空，门禁必然失败（旁观会话复现：5081个error），因此`c64e9dc`作废。现改为非git目录时遍历目录建索引。
   - 工作区内git索引与walk索引的结果逐项相同。
   - 在干净导出目录中实测：门禁通过；单跑改名TB，先通过门禁、后TB PASS；注入坏锚点后门禁失败、退出1、未开始仿真（`anchor_gate_demo/`）。
   - 终版改为`5d8ceba`。

## 5. RTL注释改动与TB标签改动的证明

### 5.1 RTL：去注释比对与gate

- `final_strip_proof/strip_proof.txt`：HEAD上全部6个改动过的RTL文件，去注释后与`7a8eabf`逐字节相同。
- 每个RTL文件另做了两项检查：skill的comment-only校验器，以及deliverable gate的基线/分支比对（`rtl_comment_proof/`）。

| 文件 | 改动 | gate 基线→分支 | comment-only |
|---|---|---|---|
| `ppg_amb_recheck_scheduler.v` | §3.9（F-9）点名的3处注释（`f8986b3`） | 0/0 → 0/0 | 成功 |
| `ppg_adc_measurement_idac_integration.v` | `@satisfies` 8行：AMI-39/LFA-04、AMI-24、AMI-40 | 11/1 → 11/1，无新增 | 成功 |
| `ppg_adc_s1_redundancy_corrector.v` | AMI-40 | 3/0 → 3/0，无新增 | 成功 |
| `ppg_400hz_frame_calibration_scheduler.v` | FSC-19、FSC-54 | 4/0 → 4/0，无新增 | 成功 |
| `ppg_sar9_sar15_safe_selection_wrapper.v` | SSW-42、SSW-18、SSW-53 | 10/0 → 10/0，无新增 | 成功 |
| `ppg_system_fault_abort_supervisor.v` | P09；SUP-08（统筹10-09裁定后补，`3570ab6`，episode关闭分支） | 1/0 → 1/0，无新增（两次各比对一次） | 成功 |

- 后5个文件在基线上就不满足strict 0/0（共29个error、1个strict warning），因此判据是“不新增发现”。比对按文件、规则、去掉行号的消息逐项进行（`gate_compare.py`），差异为0。
- `@satisfies`都补在已有的实质性中文注释末尾。每处先核对了阶段2改写后的合同行与所在代码一致。
- 负对照：
  - `strip_compare`：把一个`1'b1`改为`1'b0`，报出差异。
  - comment-only校验器：改冗余校正器中的一个代码token，报出差异。

### 5.2 TB：去注释、去字符串比对

- HEAD上全部7个改动过的TB，去掉注释和字符串内容后与`7a8eabf`相同（`final_strip_proof/strip_proof.txt`、`tb_rename_proof/`）。
- 负对照：改一个代码token后报出差异。
- `strip_compare.py`在本批加了一条规则：只含空白的行不参与比较。原因是新增的整行修订记录注释去掉后会留下空行。加规则后重跑了f8986b3的证明，仍然IDENTICAL。
- deliverable gate：这些TB在基线上已有715个error（不是strict交付物）。改后按文件和规则逐项相同。
- `tools/run_unit_tb_regression.sh`的5条横幅正则同步修改（交接书Q3）：调度器、DCR、AMI、supervisor、MGR。

## 6. 检查脚本与负对照证据

| 脚本 | 负对照 | 证据 |
|---|---|---|
| `anchor_check.py` | 注入5处（名字缺失、文件缺失、节号缺失、节号重名、行号锚点），恰好多报5处，原有报错0处消失；TB标签锚点另做一次；写入后在副本中注入的2处范围内故障均报出 | `anchor_check_negctl/`、`anchor_conversion/anchor_verify_negctl.md` |
| `anchor_verify.py` | 在转换结果中注入4处（锚点内符号改名、锚点外文字改动、未转换行改动、恢复旧锚点），恰好报出4处 | `anchor_conversion/anchor_verify_negctl.md` |
| 门禁`run_anchor_gate.sh` | 工作区与导出目录各演示一次：通过一次，注入坏锚点后失败（退出1、未开始仿真）；回归机上也演示过 | `anchor_gate_demo/`、`final_5d8ceba/gate_negctl.out`、`unit_out_gate_head.txt` |
| `manifest_digest.py` | 导出副本中C04改1字节，恰好多报C04；`--write`往返26/26 | `stage5_dryrun/`、`stage5_final/` |
| `strip_compare.py` | 代码token改动报DIFFERENT，恢复后IDENTICAL | `rtl_comment_proof/README.md`、`tb_rename_proof/strip_compare.txt` |
| `regression_evidence.py` | 自比全SAME；行号改动报`FINISH_LINE_SHIFT`，退出0；时刻改动报`FINISH_DIFF`，退出1；早先版本改1行PASS与1行`$finish`恰好报2处 | `regression_compare_negctl/` |
| `verlink_check.py` | 版本联动207/0，负对照恰好报出；第二次联动（C24 V1.6→V1.7）16/0，第一轮复现仍为207/0 | `version_linkage/`（`round2_check.txt`） |
| `anchor_history_rules.py` | 13个构造样例全对；逐条停用"> "块、修订记录节、被取代旧条目三类规则，各恰好2个样例失败 | `anchor_conversion/round2/history_rules_*.txt` |
| `anchor_verify.py --previous`（第二轮） | 注入4处（撤销一处新增转换、保留一处应回退的转换、改写回错符号、改非锚点文字），恰好报出4处；anchor_check在其范围内报出2处 | `anchor_conversion/round2/negctl.md` |
| `tools/id_governance_scan` | 重扫37处，负对照恰好多报2处 | `id_rescan/` |

最终状态：HEAD上`anchor_check.py` 0报错（符号锚点6835、`@satisfies` 113、TB标签184、合同节号2812；allowlist 20行）；`manifest_digest.py --rev HEAD` 26/26。

## 7. RTL疑点（只登记，未修改）

- **BMI-057**：AMI中约第2085行的注释写“overlap只比较该字段”，与实现不符（F28 §1旁注）。不在交接书§3.9点名范围内，未修改，交RTL注释/清理轮。
- 阶段2核对RTL时发现的合同与RTL不一致（BMI-058、BMI-064）属于合同错误，已按RTL订正合同，不是RTL疑点（§2）。

## 8. 锚点转换（BMI-150~153）

- **盘点**：基线`7a8eabf`的矩阵与别名表中共有9702个旧行号锚点。其中4103个的写入时点是2026-09-28的导入提交，git历史从导入开始。
- **口径**（第二轮起按统筹2026-10-09裁定）：
  - 已写明符号的锚点，以格内所写符号为准，在写入时版本中定位（交接书§3.13 Q1）。裸行号追到写入时版本取符号。
  - 保留为历史的只有：删除线内、"> "开头的勘误或说明块、修订记录节、同一格中被后续条目明示取代的旧条目。带日期的现行结论（“CLOSED 2026-09-07…”“2026-09-16重建…”“2026-09-16新增行…”“…复核确认…”之后的证据链）一律转换；拿不准时默认转换，单独计为uncertain。
  - 规则实现在`tools/b_merge_tools/anchor_history_rules.py`，带自测和负对照。
- **两轮**：
  - 第一轮（`3b6df78`快照，`1fab116`写入）把“同格中日期之前”的1473个锚点按历史保留。统筹不接受这一口径（交接书措辞有歧义，统筹已更正）。
  - 第二轮（`557cdfd`快照，`9dd4333`写入）只写增量：新增转换1455个，其中自动1381个、人工74个、uncertain 49个；17个在"> "历史块中，保留；1个是计数“:2”，不是锚点。另外，第一轮已转换的锚点中有12个位于"> "历史块，已恢复原文；4个G-FP-01台账锚点改写。
  - 第二轮人工核对发现并订正两类问题：一是G-FP-01台账“Top边界输入/输出（`ppg_control_top.v:N`）”的行号与写入时版本有偏移，现按本行端口名（规则化，共26处与解析器结果不同）；二是别名表277行的SSW裸行号曾被误归C17，已按格内描述订正。另有一处冒号写节号（“MATRIX.md:12.14节”）。
  - 计数与按类抽样（原文与新锚点）见`anchor_conversion/round2/reclassification.md`，49个uncertain逐条列出。
  - 裁定③“被后续条目取代的旧条目”单列为一类，见`anchor_conversion/round2/history_class3.md`。402个都是删除线内的旧条目，同一格中紧接着取代它的新条目（典型写法“~~旧~~ **2026-09-16重建…**”）。它们同时满足①，按③单列。不划删除线、只用文字明示作废的为0个（判定：同格后文出现“以上/上述/前述…作废/不成立/已被…取代”或“superseded”）。同格后文有带日期勘误或补记但未明示作废前文的98个，按“拿不准时默认转换”转换并标uncertain，逐条列在该文件。判定规则的自测共17个样例，本类6个；逐条停用规则后，各自恰好2个样例失败。
- **结果**（附录A）：

| 分类 | 数量 |
|---|---:|
| 自动转换 | 8925 |
| 人工判定后转换 | 329 |
| ①删除线内（同格中删除线之后无接续条目），保留 | 8 |
| ②"> "历史块，保留 | 30 |
| ②修订记录节，保留 | 0 |
| ③被后续条目取代的旧条目：删除线内、同格后接取代条目（“~~旧~~ **新**”），保留 | 402 |
| ③被后续条目取代的旧条目：无删除线、同格后文明示作废，保留 | 0 |
| 其它历史（gate输出原文） | 1 |
| 非锚点（如“1024-bit”、计数） | 4 |
| 仓库外文档（会话交接文档） | 3 |
| 失效锚点（无法追溯） | 0 |

- **写入与复核**：
  - 两轮都按“写入前快照 → apply → anchor_verify独立复核 → 负对照”执行。
  - 第一轮：7811处、2385行，0处无法定位，复核0不符。
  - 第二轮：增量1471处、338行，0处无法定位。复核从基线按两张表分别重建，0不符；6个第一轮后另有编辑的行，用“撤销增量后等于快照”核对通过。
  - allowlist（`tools/b_merge_tools/anchor_history_allowlist.json`，按行SHA-1）由第一轮的342行降为20行，只剩真正的历史。
  - 新文本全部经anchor_check逐条校验，0报错。
- **门禁**（`de814e7`、`871ff61`）：`run_unit_tb_regression.sh`开头先跑`run_anchor_gate.sh`，失败则整轮在仿真前退出1。

## 9. 已裁定项（统筹2026-10-09）

阶段1的Q-1~Q-5已由统筹裁定。报告初稿列出的6项执行判断，统筹裁定与处置如下：

| # | 事项 | 统筹裁定 | 处置 |
|---|---|---|---|
| 1 | 带日期叙述中的锚点按历史保留（1473处） | 不接受。只有删除线、"> "历史块、修订记录节、同格中被后续条目取代的旧条目保留；带日期的现行结论一律转换，拿不准时默认转换 | 已执行锚点第二轮（§8）：规则脚本`anchor_history_rules.py`及负对照；三类历史分别计数（①8、②30、③402，其中③均为删除线内旧条目后接取代条目，无删除线的明示取代为0）；新增转换1455处（uncertain 49），12处"> "块内锚点恢复原文，4处改写；anchor_verify 0不符、负对照4/4；allowlist降为20行；anchor_check 0报错；§12.4a重算26/26 |
| 2 | 冒号写的节号按节号转换（28处，含C13 §3.1→§4.1、`C10:11`→§11） | 接受 | 维持；第二轮另发现1处同类写法（MATRIX.md:12.14节），同样处理 |
| 3 | 两处格内节号与行号不一致，按格内所写 | 接受 | 维持 |
| 4 | SUP-08未改写、未补标签 | 本次一起改：扩写为“AMI阻断类故障（错配、连续完成丢失cause 06、长期忙cause 07）经supervisor进入STOPPING后，不复位即可合法重启”，补`@satisfies: SUP-08`，别名表映射adc_anomaly TB的重启检查 | C24 V1.7（`3570ab6`）；supervisor episode关闭分支补标签，只改注释（strip IDENTICAL、comment-only成功、gate 1/0→1/0）；版本联动16处（`98a61e4`，verlink_check 16/0）；别名表SUP-08行（`a2f1533`）。覆盖范围如实写出：8'h06由SYS-RESTART-K、SYS-L5-RESTART、SYS-RESTART-CAL覆盖；8'h07由SYS-RESTART-BUSY覆盖；错配类只有8'h02，由SYS-RESTART-IDLE、SYS-RESTART-NEXTRUN、SYS-RESTART-WIN、SYS-RESTART-WIN2覆盖；8'h01、8'h03的重启该TB未覆盖 |
| 5 | E_STALE_MATRIX_TEXT 16项与B_TAG_MISSING 22项 | 列入流片前验证收尾计划的逐ID闭环（V8），不进二级清单 | 总表新增BMI-911；矩阵§13.1注明去向；reconcile重跑为327个ID、A 288（SUP-08转A） |
| 6 | 别名表3处引用未入库的会话交接文档 | 接受 | 维持，标为仓库外引用 |

RTL和TB不变，按统筹裁定不重跑全套回归。

## 10. 过程记录

- **提交问题**：
  - 扫描器`.pyc`被误提交，已在`579689e`用`git rm --cached`移出，没有改写历史。
  - `6197609`因`git add`路径错误，只提交了文件改名，正文由`e30b46c`补齐。
  - 之后提交都按路径逐个`git add`，并确认暂存区没有`__pycache__`。
- **.gitignore**：建议增加`__pycache__/`。本批次未改，不在授权范围内。
- **执行统筹10-09裁定**（进度条目17）：
  - `557cdfd`：锚点第二轮快照。
  - `9dd4333`：第二轮写入。
  - `3570ab6`：SUP-08标签与C24 V1.7。
  - `98a61e4`：版本联动。
  - `a2f1533`：别名表SUP-08行与§13.1。
  - `f9e981b`：§12.4a重算。
- **C08节号**：阶段2新增的“启动搜索空闲边界”小节最初编成§8.2.3，与已有小节重号，在`be82819`改为§8.2.6，同步改了5处引用。重号是anchor_check报出的。
- **三处纯文字节号引用**：在`3b6df78`中补了标题或改了指向，使它们能唯一定位：
  - 矩阵中两处`C01§4.1`；
  - 别名表`§9.2.2`改为“§9.2（第9.2.2段）”；
  - 芯片顶层SPI合同`C01 §4.1 V1.18`补了标题。
- **旁观会话的独立核查**（只读）：
  - TB去注释、去字符串比对（6个TB及`ppg_amb_recheck_scheduler.v`，`68edf17`）；
  - 基线与终版均从原始日志重算，并逐行比对导出的PASS行；
  - 独立运行compare，结果与提交版逐行相同；
  - 2019.2与2022.2结果交叉核对；
  - 复现锚点门禁在导出目录中失败，并在干净导出中核对§12.4a 26/26。
  - 它还发现了§4.3的两处工具问题。

---


## 附录A 锚点转换对照表

完整对照表共9702行（每行一个旧锚点：文件、基线行号、行SHA-1、列、旧文本、类别、写入时提交、分类、新文本、来源、理由），见`verification_reports/b_merge_batch_evidence/anchor_conversion/anchor_mapping_table.tsv`（第二轮终版）。第一轮的表保存在同目录`anchor_mapping_table_round1.tsv`。逐条写入记录见`anchor_apply_report.tsv`（第一轮）与`round2/apply_report.tsv`（第二轮），独立复核记录见`anchor_verify.txt`与`round2/verify.txt`。第二轮的重新分类计数与按类抽样见`round2/reclassification.md`。下面是终版分类计数，以及全部人工判定。

### A.1 分类计数（终版）

| 文件 | 分类 | 来源 | 数量 |
|---|---|---|---:|
| PPG_ALIAS_MAPPING_TABLE.md | convert | auto | 752 |
| PPG_ALIAS_MAPPING_TABLE.md | convert | manual | 117 |
| PPG_ALIAS_MAPPING_TABLE.md | external | manual | 3 |
| PPG_ALIAS_MAPPING_TABLE.md | history | manual | 1 |
| PPG_ALIAS_MAPPING_TABLE.md | history-block | auto | 3 |
| PPG_ALIAS_MAPPING_TABLE.md | history-strike | auto | 8 |
| PPG_ALIAS_MAPPING_TABLE.md | history-superseded-struck | auto | 4 |
| PPG_ALIAS_MAPPING_TABLE.md | not-anchor | manual | 3 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | convert | auto | 8173 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | convert | manual | 212 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | history-block | auto | 27 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | history-superseded-struck | auto | 398 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | not-anchor | manual | 1 |

分类说明：history-strike为裁定①（删除线内且同格无接续条目）；history-block为裁定②；history-superseded-struck为裁定③（删除线内旧条目，同格后接取代条目）；history-revision与history-superseded均为0个，未出现在表中。

### A.2 人工判定（337条）

来源：`tools/b_merge_tools/anchor_manual_decisions.tsv`。理由以“第二轮”开头的，是按统筹10-09裁定新增的判定。“基线行”是`7a8eabf`中的行号。

| 文件 | 基线行 | 旧锚点 | 新文本 | 理由 |
|---|---:|---|---|---|
| 矩阵 | 934 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：参数化位宽约束注释块，同alias P12行 |
| 矩阵 | 937 | ppg_control_top.v:1378-1439 | `ppg_control_top.v` `ppg_system_fault_abort_supervisor_Inst` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内写明“C24 supervisor instantiation” |
| 矩阵 | 999 | C23:18 | C23 §18 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1000 | C17:3 | C17 §3 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1001 | C10:2 | C10 §2 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1001 | C18:2-2 | C18 §2–§2 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1001 | C23:2 | C23 §2 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1001 | C25:2 | C25 §2 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1002 | C18:5 | C18 §5 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1002 | C23:8 | C23 §8 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1003 | C01:6 | C01 §6 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1003 | C10:6 | C10 §6 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 1324 | ppg_control_top.v:121 | `ppg_control_top.v` `i_adc_physical_idle` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1324 | ppg_control_top.v:121 | `ppg_control_top.v` `i_adc_physical_idle` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1332 | ppg_control_top.v:114 | `ppg_control_top.v` `i_control_abort_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1332 | ppg_control_top.v:114 | `ppg_control_top.v` `i_control_abort_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1334 | ppg_control_top.v:113 | `ppg_control_top.v` `i_diag_clear_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1334 | ppg_control_top.v:113 | `ppg_control_top.v` `i_diag_clear_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1334 | `:515` | C01 §5.2 | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“§5.2（当前:515）”指C01合同行 |
| 矩阵 | 1354 | ppg_control_top.v:99 | `ppg_control_top.v` `i_source_rstn` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1354 | ppg_control_top.v:99 | `ppg_control_top.v` `i_source_rstn` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1365 | ppg_control_top.v:130 | `ppg_control_top.v` `i_test_identity_inject_sample_index` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1365 | ppg_control_top.v:130 | `ppg_control_top.v` `i_test_identity_inject_sample_index` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1368 | ppg_control_top.v:131 | `ppg_control_top.v` `i_test_invalid_sample_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1368 | ppg_control_top.v:131 | `ppg_control_top.v` `i_test_invalid_sample_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1381 | `:410` | `ppg_control_top.v` `measurement_allow_new_transaction` | 第二轮：“Top内部网`measurement_allow_new_transaction`（:N）”，按格内网名 |
| 矩阵 | 1388 | ppg_control_top.v:233 | `ppg_control_top.v` `o_characterization_control_reject_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1388 | ppg_control_top.v:233 | `ppg_control_top.v` `o_characterization_control_reject_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1389 | ppg_control_top.v:232 | `ppg_control_top.v` `o_characterization_control_update_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1389 | ppg_control_top.v:232 | `ppg_control_top.v` `o_characterization_control_update_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1390 | ppg_control_top.v:231 | `ppg_control_top.v` `o_characterization_control_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1390 | ppg_control_top.v:231 | `ppg_control_top.v` `o_characterization_control_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1391 | ppg_control_top.v:234 | `ppg_control_top.v` `o_characterization_protocol_error_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1391 | ppg_control_top.v:234 | `ppg_control_top.v` `o_characterization_protocol_error_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1392 | `:1539` | `ppg_control_top.v` `o_characterization_control_reject_event` | 第二轮：“Top内部网`o_characterization_control_reject_event`（:N）”，按格内网名 |
| 矩阵 | 1392 | `:233` | `ppg_control_top.v` `o_characterization_control_reject_event` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_characterization_control_reject_event`同名输出端口 |
| 矩阵 | 1393 | `:1538` | `ppg_control_top.v` `o_characterization_control_update_event` | 第二轮：“Top内部网`o_characterization_control_update_event`（:N）”，按格内网名 |
| 矩阵 | 1393 | `:232` | `ppg_control_top.v` `o_characterization_control_update_event` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_characterization_control_update_event`同名输出端口 |
| 矩阵 | 1394 | `:1537` | `ppg_control_top.v` `o_characterization_control_valid` | 第二轮：“Top内部网`o_characterization_control_valid`（:N）”，按格内网名 |
| 矩阵 | 1394 | `:231` | `ppg_control_top.v` `o_characterization_control_valid` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_characterization_control_valid`同名输出端口 |
| 矩阵 | 1395 | `:1524` | `ppg_control_top.v` `o_ami_datapath_empty` | 第二轮：“Top内部网`o_ami_datapath_empty`（:N）”，按格内网名 |
| 矩阵 | 1395 | `:218` | `ppg_control_top.v` `o_ami_datapath_empty` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_ami_datapath_empty`同名输出端口 |
| 矩阵 | 1398 | `:1525` | `ppg_control_top.v` `o_ami_idac_idle` | 第二轮：“Top内部网`o_ami_idac_idle`（:N）”，按格内网名 |
| 矩阵 | 1398 | `:219` | `ppg_control_top.v` `o_ami_idac_idle` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_ami_idac_idle`同名输出端口 |
| 矩阵 | 1407 | `:1540` | `ppg_control_top.v` `o_characterization_protocol_error_sticky` | 第二轮：“Top内部网`o_characterization_protocol_error_sticky`（:N）”，按格内网名 |
| 矩阵 | 1407 | `:234` | `ppg_control_top.v` `o_characterization_protocol_error_sticky` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_characterization_protocol_error_sticky`同名输出端口 |
| 矩阵 | 1407 | `:1523` | `ppg_control_top.v` `o_scheduler_protocol_error_sticky` | 第二轮：“Top内部网`o_scheduler_protocol_error_sticky`（:N）”，按格内网名 |
| 矩阵 | 1407 | `:217` | `ppg_control_top.v` `o_scheduler_protocol_error_sticky` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_scheduler_protocol_error_sticky`同名输出端口 |
| 矩阵 | 1410 | `:408` | `ppg_control_top.v` `analog_run_enable` | 第二轮：“Top内部网`analog_run_enable`（:N）”，按格内网名 |
| 矩阵 | 1410 | `:409` | `ppg_control_top.v` `measurement_run_enable` | 第二轮：“Top内部网`measurement_run_enable`（:N）”，按格内网名 |
| 矩阵 | 1416 | `:1536` | `ppg_control_top.v` `o_source_characterization_update_ready` | 第二轮：“Top内部网`o_source_characterization_update_ready`（:N）”，按格内网名 |
| 矩阵 | 1416 | `:230` | `ppg_control_top.v` `o_source_characterization_update_ready` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_source_characterization_update_ready`同名输出端口 |
| 矩阵 | 1417 | ppg_control_top.v:200 | `ppg_control_top.v` `o_start_ack_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1417 | ppg_control_top.v:200 | `ppg_control_top.v` `o_start_ack_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1418 | `:409` | `ppg_control_top.v` `measurement_run_enable` | 第二轮：“Top内部网`measurement_run_enable`（:N）”，按格内网名 |
| 矩阵 | 1418 | `:410` | `ppg_control_top.v` `measurement_allow_new_transaction` | 第二轮：“Top内部网`measurement_allow_new_transaction`（:N）”，按格内网名 |
| 矩阵 | 1418 | `:412` | `ppg_control_top.v` `flag_measurement_start_ack_event` | 第二轮：“Top内部网`flag_measurement_start_ack_event`（:N）”，按格内网名 |
| 矩阵 | 1419 | ppg_control_top.v:201 | `ppg_control_top.v` `o_stop_ack_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1419 | ppg_control_top.v:201 | `ppg_control_top.v` `o_stop_ack_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1453 | ppg_control_top.v:122 | `ppg_control_top.v` `i_analog_ready` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1453 | ppg_control_top.v:122 | `ppg_control_top.v` `i_analog_ready` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1453 | `:74-77` | `ppg_control_top.v` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“RTL头注释:74-77已自述该缺口”，Top文件头注释，文件级锚点 |
| 矩阵 | 1467 | ppg_control_top.v:108 | `ppg_control_top.v` `i_source_test_mux_ctrl` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1467 | ppg_control_top.v:108 | `ppg_control_top.v` `i_source_test_mux_ctrl` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1468 | ppg_control_top.v:134 | `ppg_control_top.v` `i_context_handover_stall_request` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1468 | ppg_control_top.v:134 | `ppg_control_top.v` `i_context_handover_stall_request` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1499 | ppg_control_top.v:215 | `ppg_control_top.v` `o_scheduler_owner_deadline_timeout_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1499 | ppg_control_top.v:215 | `ppg_control_top.v` `o_scheduler_owner_deadline_timeout_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1500 | ppg_control_top.v:216 | `ppg_control_top.v` `o_scheduler_completion_mismatch_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1500 | ppg_control_top.v:216 | `ppg_control_top.v` `o_scheduler_completion_mismatch_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1501 | ppg_control_top.v:217 | `ppg_control_top.v` `o_scheduler_protocol_error_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1501 | ppg_control_top.v:217 | `ppg_control_top.v` `o_scheduler_protocol_error_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1502 | ppg_control_top.v:222 | `ppg_control_top.v` `o_ssw_wrapper_idle` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1502 | ppg_control_top.v:222 | `ppg_control_top.v` `o_ssw_wrapper_idle` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1503 | ppg_control_top.v:223 | `ppg_control_top.v` `o_ssw_switch_protocol_error_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1503 | ppg_control_top.v:223 | `ppg_control_top.v` `o_ssw_switch_protocol_error_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1504 | ppg_control_top.v:224 | `ppg_control_top.v` `o_ssw_transaction_mismatch_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1504 | ppg_control_top.v:224 | `ppg_control_top.v` `o_ssw_transaction_mismatch_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1505 | ppg_control_top.v:225 | `ppg_control_top.v` `o_ssw_owner_deadline_timeout_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1505 | ppg_control_top.v:225 | `ppg_control_top.v` `o_ssw_owner_deadline_timeout_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1506 | ppg_control_top.v:226 | `ppg_control_top.v` `o_ssw_calibration_timeout_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1506 | ppg_control_top.v:226 | `ppg_control_top.v` `o_ssw_calibration_timeout_sticky` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1509 | ppg_control_top.v:119 | `ppg_control_top.v` `i_dout_stage2_low` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1509 | ppg_control_top.v:119 | `ppg_control_top.v` `i_dout_stage2_low` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1510 | ppg_control_top.v:120 | `ppg_control_top.v` `i_clk_stage2_dout_low_async` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1510 | ppg_control_top.v:120 | `ppg_control_top.v` `i_clk_stage2_dout_low_async` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1512 | ppg_control_top.v:132 | `ppg_control_top.v` `i_test_saturation_inject_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1512 | ppg_control_top.v:132 | `ppg_control_top.v` `i_test_saturation_inject_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1513 | ppg_control_top.v:133 | `ppg_control_top.v` `i_test_calibration_loss_inject_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1513 | ppg_control_top.v:133 | `ppg_control_top.v` `i_test_calibration_loss_inject_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1571 | ppg_control_top.v:292 | `ppg_control_top.v` `o_s2_raw` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1571 | ppg_control_top.v:292 | `ppg_control_top.v` `o_s2_raw` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1593 | semantic_contract.md:297 | C02 §4 | C02语义合同简写；行号取写入时该合同所在小节 |
| 矩阵 | 1593 | `:88-100` | C02 §2.1 | 续接左侧semantic_contract.md（C02），正式I/O表 |
| 矩阵 | 1640 | semantic_contract.md:297 | C02 §4 | C02语义合同简写 |
| 矩阵 | 1725 | ppg_active_v4_control_plane_integration.v:784 | `ppg_active_v4_control_plane_integration.v` `o_stage1_weight_q16_0` | “C03 wrapper (… area)”指C03的Stage1权重0导出端口；:784属Top，另条处理 |
| 矩阵 | 2220 | `:1006` | `ppg_adc_measurement_idac_integration.v` `o_calibration_sample_valid` | 左侧引文即AMI的assign o_calibration_sample_valid |
| 矩阵 | 2221 | `:1007` | `ppg_adc_measurement_idac_integration.v` `o_calibration_frame_type` | 本行端口为AMI输出o_calibration_frame_type，锚点为其assign |
| 矩阵 | 2224 | `:1010` | `ppg_adc_measurement_idac_integration.v` `o_calibration_request_reason` | 本行端口为AMI输出o_calibration_request_reason，锚点为其assign |
| 矩阵 | 2255 | `:1074` | `ppg_adc_measurement_idac_integration.v` `o_idac_fault_blocking` | 左侧引文即AMI的assign o_idac_fault_blocking |
| 矩阵 | 2257 | `:2426,1076` | `ppg_adc_measurement_idac_integration.v` `startup_search_complete_o` | C17输出经AMI内部线startup_search_complete_o（右侧括注） |
| 矩阵 | 2258 | `:2427,1077` | `ppg_adc_measurement_idac_integration.v` `idac_idle_o` | C17输出经AMI内部线idac_idle_o（右侧括注） |
| 矩阵 | 2505 | `:993` | `ppg_precision_window_integration.v` `i_normal_measurement_active` | PWI内部把本端口同时送给amb_recheck_scheduler |
| 矩阵 | 2517 | `:442` | `ppg_precision_window_integration.v` `dec_return_reason` | 括注符号dec_return_reason（PWI内部线） |
| 矩阵 | 2518 | `:443` | `ppg_precision_window_integration.v` `dec_return_frame_id` | 括注符号dec_return_frame_id（PWI内部线） |
| 矩阵 | 2572 | `:942,946` | `ppg_adc_measurement_idac_integration.v` `flag_detection_transfer`、`flag_result_fork_all_released` | 括注两个fork释放符号均在AMI |
| 矩阵 | 2575 | `:949,2506` | `ppg_adc_measurement_idac_integration.v` `coarse_valid_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2576 | `:949,2507` | `ppg_adc_measurement_idac_integration.v` `coarse_recovery_calibrated_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2578 | `:949,2509` | `ppg_adc_measurement_idac_integration.v` `flag_unused_output_s1_sat_high` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2579 | `:949` | `ppg_adc_measurement_idac_integration.v` `coarse_saturation_low_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2580 | `:949` | `ppg_adc_measurement_idac_integration.v` `coarse_saturation_high_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2581 | `:949,638` | `ppg_adc_measurement_idac_integration.v` `config_epoch_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2582 | `:949,639` | `ppg_adc_measurement_idac_integration.v` `coef_epoch_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2583 | `:949,640` | `ppg_adc_measurement_idac_integration.v` `dc_result_coef_epoch_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2584 | `:949,641` | `ppg_adc_measurement_idac_integration.v` `result_precision_mode_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2585 | `:949,642` | `ppg_adc_measurement_idac_integration.v` `result_frame_id_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2586 | `:949,643` | `ppg_adc_measurement_idac_integration.v` `result_sample_index_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2587 | `:949,644` | `ppg_adc_measurement_idac_integration.v` `result_color_ir_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2588 | `:949,645` | `ppg_adc_measurement_idac_integration.v` `result_frame_type_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2589 | `:949,646,2520` | `ppg_adc_measurement_idac_integration.v` `result_amb_code_snapshot_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2590 | `:949,647` | `ppg_adc_measurement_idac_integration.v` `result_dc_code_snapshot_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2591 | `:949,648` | `ppg_adc_measurement_idac_integration.v` `result_amb_code_epoch_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2592 | `:949,649` | `ppg_adc_measurement_idac_integration.v` `result_dc_code_epoch_o` | C05 unpack结果字段，AMI内同名解包线（payload解包assign） |
| 矩阵 | 2621 | `:1001` | `ppg_adc_measurement_idac_integration.v` `i_macro_frame_safe_boundary` | AMI-hub行，端口i_macro_frame_safe_boundary在AMI内分送两个调度器 |
| 矩阵 | 2635 | `:1138` | `ppg_adc_measurement_idac_integration.v` `o_ami_fault_cause` | 左侧“o_ami_fault_cause=8'h04 dispatch” |
| 矩阵 | 2636 | `:84` | C10 §3 | 格内写明“§3 (:84, integration module scope)”；写入时:84已漂入§2，按格内节号与标题（§3 集成模块范围） |
| 矩阵 | 2652 | `:2634` | `ppg_adc_measurement_idac_integration.v` `o_transaction_start_fire` | 左侧“AMI's own o_transaction_start_fire” |
| 矩阵 | 2682 | `:190-200` | C11 §6.1 事务代际与AMI私有排空 | “§6.1 (…)”指C11合同行 |
| 矩阵 | 2682 | `:224-226` | C11 §6.1 事务代际与AMI私有排空 | “§6.1 port table (…)”指C11合同行 |
| 矩阵 | 2682 | ppg_adc_s1_programmable_calibrator.v:58-116 | `ppg_adc_s1_programmable_calibrator.v` | 整段端口声明（58-116），文件级锚点 |
| 矩阵 | 2697 | `:1855` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_s1_programmable_calibrator_Inst` | 弱解析结果经人工核对接受 |
| 矩阵 | 2718 | `:1986` | `ppg_adc_measurement_idac_integration.v` `flag_router_calibration_applied` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2719 | `:1987` | `ppg_adc_measurement_idac_integration.v` `flag_router_saturation_low` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2720 | `:1988` | `ppg_adc_measurement_idac_integration.v` `flag_router_saturation_high` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2721 | `:1989` | `ppg_adc_measurement_idac_integration.v` `dec_router_config_epoch` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2722 | `:1990` | `ppg_adc_measurement_idac_integration.v` `dec_router_coef_epoch` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2723 | `:1992` | `ppg_adc_measurement_idac_integration.v` `dec_router_stage1_raw` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2724 | `:1991` | `ppg_adc_measurement_idac_integration.v` `dec_router_detect_code` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2725 | `:1993` | `ppg_adc_measurement_idac_integration.v` `dec_router_stage1_code_ext` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2726 | `:1994` | `ppg_adc_measurement_idac_integration.v` `dec_router_stage2_raw` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2727 | `:1995` | `ppg_adc_measurement_idac_integration.v` `flag_router_precision_mode` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2728 | `:1996` | `ppg_adc_measurement_idac_integration.v` `dec_router_frame_id` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2729 | `:1997` | `ppg_adc_measurement_idac_integration.v` `dec_router_sample_index` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2730 | `:1998` | `ppg_adc_measurement_idac_integration.v` `flag_router_color_ir` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2731 | `:1999` | `ppg_adc_measurement_idac_integration.v` `dec_router_frame_type` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2732 | `:2000` | `ppg_adc_measurement_idac_integration.v` `dec_router_amb_code_snapshot` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2733 | `:2001` | `ppg_adc_measurement_idac_integration.v` `dec_router_dc_code_snapshot` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2734 | `:2002` | `ppg_adc_measurement_idac_integration.v` `dec_router_amb_code_epoch` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2735 | `:2003` | `ppg_adc_measurement_idac_integration.v` `dec_router_dc_code_epoch` | AMI内router输出线同时旁路给fork（括注符号） |
| 矩阵 | 2736 | `:1985` | `ppg_adc_measurement_idac_integration.v` `ppg_normal_transaction_fork_Inst` | AMI内fork例化 |
| 矩阵 | 2760 | `:1931` | `ppg_adc_measurement_idac_integration.v` `flag_idac_search_dcs_ready` | 括注符号 |
| 矩阵 | 2927 | `:2138` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_programmable_reconstructor` | 弱解析结果经人工核对接受 |
| 矩阵 | 2985 | `:482-500` | C15 §11.5 | “§11.5 (…)”指C15合同行 |
| 矩阵 | 2985 | ppg_adc_dc_recovery.v:55-145 | `ppg_adc_dc_recovery.v` | 整段端口声明（55-145），文件级锚点 |
| 矩阵 | 2990 | `:2214` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_dc_recovery` | 弱解析结果经人工核对接受 |
| 矩阵 | 3027 | `:949` | `ppg_adc_measurement_idac_integration.v` `coarse_ppg_value_o` | “unpacked at (:949) into coarse_ppg_value_o”，AMI结果解包 |
| 矩阵 | 3070 | `:1377` | `ppg_control_top.v` `ami_fault_active_o` | Top内部线（括注符号） |
| 矩阵 | 3079 | `:1386` | `ppg_control_top.v` `sched_fault_valid_o` | Top内部线（括注符号） |
| 矩阵 | 3089 | `:1396` | `ppg_control_top.v` `ssw_fault_valid_o` | Top内部线（括注符号） |
| 矩阵 | 3119 | `:93-395` | `ppg_adc_measurement_idac_integration.v` | AMI全部265行端口声明，文件级锚点 |
| 矩阵 | 3121 | `:950` | `ppg_adc_measurement_idac_integration.v` `flag_precision_takeover_safe` | AMI内部线/端口（括注符号） |
| 矩阵 | 3124 | `:983` | `ppg_adc_measurement_idac_integration.v` `transaction_start_ready_o` | AMI内部线/端口（括注符号） |
| 矩阵 | 3125 | `:984` | `ppg_adc_measurement_idac_integration.v` `o_transaction_start_fire` | 本行端口o_transaction_start_fire，锚点为其assign |
| 矩阵 | 3126 | `:985` | `ppg_adc_measurement_idac_integration.v` `adc_transaction_complete_event_o` | AMI内部线/端口（括注符号） |
| 矩阵 | 3127 | `:986` | `ppg_adc_measurement_idac_integration.v` `adc_transaction_success_o` | AMI内部线/端口（括注符号） |
| 矩阵 | 3128 | `:987` | `ppg_adc_measurement_idac_integration.v` `adc_complete_sample_index_o` | AMI内部线/端口（括注符号） |
| 矩阵 | 3130 | `:1015` | `ppg_adc_measurement_idac_integration.v` `o_measurement_result_valid` | 本行端口，右侧引文为其assign |
| 矩阵 | 3131 | `:1017` | `ppg_adc_measurement_idac_integration.v` `coarse_ppg_value_o` | AMI内部线/端口（括注符号） |
| 矩阵 | 3148 | `:1034` | `ppg_adc_measurement_idac_integration.v` `result_precision_mode_o` | AMI内部线/端口（括注符号） |
| 矩阵 | 3167 | `:1149` | `ppg_adc_measurement_idac_integration.v` `flag_detection_discard_trigger` | AMI内部线/端口（括注符号） |
| 矩阵 | 3182 | `:1121,1174` | `ppg_adc_measurement_idac_integration.v` `integration_protocol_error_sticky_o` | AMI内部线/端口（括注符号） |
| 矩阵 | 3188 | `:1016` | `ppg_adc_measurement_idac_integration.v` `result_sample_valid_o` | AMI内部线/端口（括注符号） |
| 矩阵 | 3189 | ppg_idac_code_controller.v:2314 | `ppg_adc_measurement_idac_integration.v` `i_idac_code_safe_boundary` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；写入时C17不足2314行，该行号属AMI（C17例化端口连线）；符号i_idac_code_safe_boundary在AMI |
| 矩阵 | 3215 | C10:6 | C10 §6 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3216 | C10:7, 10 | C10 §7、§10 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3216 | C13:3 | C13 §4 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号；C13自导入起从无§3.1（§3为Stage1校准字段），本行内容为generation标记交接，取§4.1 Generation and lifecycle pass-through（原文“.1”保留） |
| 矩阵 | 3216 | C18:5 | C18 §5 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3217 | C16:8-13 | C16 §8–§13 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3217 | C17:10-12 | C17 §10–§12 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3217 | `:928,1001` | `ppg_idac_code_controller.v` `CTX_AMB_PENDING_VALID_BIT` | 写入时两行均为reg_context_next[CTX_AMB_PENDING_VALID_BIT]置位 |
| 矩阵 | 3228 | `:1091,1276` | `ppg_sar9_sar15_safe_selection_wrapper.v` `flag_red_context_valid`、`flag_ir_context_valid` | 本行RED/IR波形上下文锁存，abort立即释放 |
| 矩阵 | 3228 | `:1089,1274` | `ppg_sar9_sar15_safe_selection_wrapper.v` `flag_red_context_valid`、`flag_ir_context_valid` | 本行RED/IR波形上下文锁存，复位清零 |
| 矩阵 | 3229 | `:421-422` | `ppg_dynamic_baseline_cross_detector.v` `flag_reacquire_clear` | 左侧引文flag_reacquire_clear = i_reacquire_request_event |
| 矩阵 | 3232 | `:1499` | `ppg_adc_measurement_idac_integration.v` `reg_adc_inflight_frame_id` | “identity snapshot registers latch”指reg_adc_inflight_*身份快照 |
| 矩阵 | 3232 | `:1604` | `ppg_adc_measurement_idac_integration.v` `flag_adc_transaction_inflight` | 本行物理ADC owner，复位清零 |
| 矩阵 | 3240 | ppg_idac_code_controller.v:26 | `ppg_idac_code_controller.v` | RTL文件头V2.3修订记录，非代码行，文件级锚点 |
| 矩阵 | 3241 | ppg_400hz_frame_calibration_scheduler.v:421 | `ppg_400hz_frame_calibration_scheduler.v` `scheduler_fault_cause_o` | 右侧引文scheduler_fault_cause_o = … |
| 矩阵 | 3241 | `:419` | `ppg_400hz_frame_calibration_scheduler.v` `B_COMPLETION_MISMATCH` | 调度器故障原因位（括注符号） |
| 矩阵 | 3242 | `:48` | `ppg_sar9_sar15_safe_selection_wrapper.v` | SSW文件头V1.4注记，非代码行，文件级锚点 |
| 矩阵 | 3242 | `:480` | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“o_analog_safe/i_analog_safe ... inverse (:480)” |
| 矩阵 | 3246 | `:1171-1172` | `ppg_adc_measurement_idac_integration.v` `integration_protocol_error_sticky_o` | 本行AMI集成协议sticky，START ACK/诊断清除 |
| 矩阵 | 3246 | `:1170` | `ppg_adc_measurement_idac_integration.v` `integration_protocol_error_sticky_o` | 本行AMI集成协议sticky，复位清除 |
| 矩阵 | 3247 | `:521-526,592-613` | `ppg_system_config_manager.v` `dec_error_code` | 本行C02命令拒绝（dec_error_code） |
| 矩阵 | 3263 | C17:11 | C17 §11 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3265 | C01:6 | C01 §6 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3265 | C23:19 | C23 §19 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3266 | C18:5 | C18 §5 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3266 | C23:8 | C23 §8 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3267 | C01:6 | C01 §6 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3267 | C10:6 | C10 §6 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3268 | C10:2 | C10 §2 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3268 | C18:2-2 | C18 §2–§2 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3268 | C23:2 | C23 §2 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3268 | C25:2 | C25 §2 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号 |
| 矩阵 | 3397 | C10:11 | C10 §11 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号；写入时C10第11行为版本日期，同表“matrix 9.”亦为节号写法 |
| 矩阵 | 3401 | `:66,70,124-143` | `ppg_config_cdc_bridge.v` `flag_source_request` | CDC桥源域寄存器（括注符号） |
| 矩阵 | 3401 | ppg_config_cdc_bridge.v:70-190 | `ppg_config_cdc_bridge.v` | 整段两域实现（70-190），文件级锚点 |
| 矩阵 | 3408 | tb_ppg_precision_window_controller.v:737-758 | `tb_ppg_precision_window_controller.v` `"PWC-41 new legal START preserves protocol sticky"` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：PWC-41的两条检查（另一条为switch-timeout sticky） |
| 矩阵 | 3456 | wrapper.v:480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | SSW简写；:480为assign o_analog_safe |
| 矩阵 | 3557 | ppg_sar9_sar15_safe_selection_wrapper.v:480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | 右侧引文assign o_analog_safe |
| 矩阵 | 3561 | `:400-402` | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_macro_tick` | SSW宏帧tick（括注符号） |
| 矩阵 | 3585 | ppg_sar9_sar15_safe_selection_wrapper.v:25,48,480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | :25/:48为文件头修订记录，:480为assign o_analog_safe |
| 矩阵 | 3832 | :2 | （保留原文：not-anchor） | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“前8项:2项(G-FP-02/G-FP-06)”计数，不是行号 |
| 别名表 | 28 | ppg_sar9_sar15_safe_selection_wrapper.v:602 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: TOP-01` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 34 | ppg_sar9_sar15_safe_selection_wrapper.v:379 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: TOP-07` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 39 | ppg_control_top.v:409 | `ppg_control_top.v` `@satisfies: TOP-12` | 行ID/本格点名ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 40 | ppg_400hz_frame_calibration_scheduler.v:754 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: TOP-13` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 41 | ppg_adc_measurement_idac_integration.v:1197 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-16` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 45 | ppg_400hz_frame_calibration_scheduler.v:425 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: TOP-20` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 45 | ppg_system_config_manager.v:394-448 | `ppg_system_config_manager.v` `flag_snapshot_dc_qualification_valid` | 静态检查侧，写入时:448为该汇总资格 |
| 别名表 | 46 | ppg_adc_measurement_idac_integration.v:905 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-21` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 48 | ppg_adc_measurement_idac_integration.v:1010 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-23` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 86 | :1024 | （保留原文：not-anchor） | “1024-bit CDC payload”位宽，不是行号 |
| 别名表 | 90 | :12 | PPG_CONTRACT_CLOSURE_MATRIX.md §12 | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“MATRIX.md:12.14节”用冒号写节号（§12.14），解析器误作第12行；原文“.14”保留 |
| 别名表 | 96 | ppg_sar9_sar15_safe_selection_wrapper.v:480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：写入时:480为assign o_analog_safe |
| 别名表 | 108 | ppg_adc_measurement_idac_integration.v:1605 | `ppg_adc_measurement_idac_integration.v` `flag_adc_transaction_inflight` | 本行“AMI物理ADC owner代表行”；写入时:1605为owner交接注释，AMI无G-FP-01本号标签 |
| 别名表 | 112 | `:26` | `ppg_idac_code_controller.v` | C17文件头V2.3修订记录，文件级锚点 |
| 别名表 | 116 | ppg_config_cdc_bridge.v:66-190 | `ppg_config_cdc_bridge.v` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；整段两域实现，文件级锚点 |
| 别名表 | 143 | tb_ppg_control_top_startup_idac_calibration.v:1278-1305 | `tb_ppg_control_top_startup_idac_calibration.v` `"PASS SID-06 next-subframe waveform snapshot correctly reflects"` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“已补真实断言…见…”指该TB的SID-06下一子帧检查 |
| 别名表 | 153 | ppg_400hz_frame_calibration_scheduler.v:452 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: LFA-01` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 154 | ppg_400hz_frame_calibration_scheduler.v:452 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: LFA-02` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 156 | ppg_400hz_frame_calibration_scheduler.v:876 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: LFA-05` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 167 | ppg_400hz_frame_calibration_scheduler.v:737 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: OIB-02` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 168 | ppg_adc_measurement_idac_integration.v:1024 | `ppg_adc_measurement_idac_integration.v` `@satisfies: OIB-03` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 170 | ppg_adc_measurement_idac_integration.v:1745 | `ppg_adc_measurement_idac_integration.v` `@satisfies: OIB-07` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 172 | PPG_SESSION_HANDOFF_20260826_2.md:1044-1047 | （保留原文：external） | 会话交接文档未随本仓库快照入库，无法读取 |
| 别名表 | 175 | PPG_SESSION_HANDOFF_20260826_2.md:1042-1044 | （保留原文：external） | 会话交接文档未随本仓库快照入库，无法读取 |
| 别名表 | 176 | PPG_SESSION_HANDOFF_20260826_2.md:1042-1044 | （保留原文：external） | 会话交接文档未随本仓库快照入库，无法读取 |
| 别名表 | 177 | ppg_sar9_sar15_safe_selection_wrapper.v:438 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: OIB-01` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 179 | ppg_adc_measurement_idac_integration.v:1010 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-23` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“已打@satisfies: TOP-23, TOP-24(…)” |
| 别名表 | 246 | `:381` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-05` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 246 | `:673-674` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-05` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 246 | `:727-728` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-05` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 247 | `:381` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-06` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 247 | `:673-674` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-06` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 247 | `:389` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-06` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 248 | `:381` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-07` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 248 | `:727-728` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-07` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 248 | `:388` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-07` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 260 | ppg_adc_measurement_idac_integration.v:1745 | `ppg_adc_measurement_idac_integration.v` `reg_result_fork_payload` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：右侧引文reg_result_fork_payload<=enc_dc_result_payload |
| 别名表 | 270 | ppg_adc_measurement_idac_integration.v:1745 | `ppg_adc_measurement_idac_integration.v` `@satisfies: ADCN-07` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 271 | ppg_adc_measurement_idac_integration.v:1745 | `ppg_adc_measurement_idac_integration.v` `@satisfies: ADCN-08` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 277 | ppg_idac_code_controller.v:879 | `ppg_idac_code_controller.v` `@satisfies: ISE-10` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“ISE-10直接追加到…(TRK-07/TRK-08既有锚点)” |
| 别名表 | 277 | `:808` | `ppg_sar9_sar15_safe_selection_wrapper.v` `reg_cal_amb_code` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内写明“SSW自己的…门控快照锁存(:808环境码”；写入时SSW:808为reg_cal_amb_code锁存，解析器误归C17 |
| 别名表 | 277 | `:847` | `ppg_sar9_sar15_safe_selection_wrapper.v` `reg_cal_dc_code` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：同上“:847直流码”；写入时SSW:847为reg_cal_dc_code锁存 |
| 别名表 | 277 | `:652,654,702,704` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-04` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“锚定在SSW的NORMAL运行波形块”SAR9总线；写入时这些SSW行带ISE-04注释 |
| 别名表 | 277 | `:642,644,692,694` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-05` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：同上SAR15总线；写入时这些SSW行带ISE-05注释 |
| 别名表 | 277 | `:642,652` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-07` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“(:642,652追加ISE-07)” |
| 别名表 | 277 | `:615` | `ppg_sar9_sar15_safe_selection_wrapper.v` `reg_control_next` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06 STATIC_BIAS“无条件清零初值”；写入时SSW:615为reg_control_next默认清零 |
| 别名表 | 277 | `:742` | `ppg_sar9_sar15_safe_selection_wrapper.v` `reg_cal_amb_code` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06 AMB总线；写入时SSW:742为reg_cal_amb_code码窗 |
| 别名表 | 277 | `:745` | `ppg_sar9_sar15_safe_selection_wrapper.v` `CTRL_EN_9_DC` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06“EN_9_DC使能门控”；写入时SSW:745为CTRL_EN_9_DC赋值 |
| 别名表 | 277 | `:747` | `ppg_sar9_sar15_safe_selection_wrapper.v` `reg_cal_dc_code` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06“DC9码窗”；写入时SSW:747为reg_cal_dc_code码窗 |
| 别名表 | 282 | `:808` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-02` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 282 | `:847` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-02` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 283 | `:808` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-03` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 283 | `:847` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-03` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 296 | :2026-09 | （保留原文：not-anchor） | “**历史**:2026-09-15”日期，不是行号 |
| 别名表 | 298 | `:837` | C22 §16 | “PVW-37按合同:837”指C22合同行 |
| 别名表 | 302 | `:312` | （保留原文：history） | 记录当时deliverable gate报告的FIR错误行号，属gate输出原文 |
| 别名表 | 303 | `:3532` | PPG_CONTRACT_CLOSURE_MATRIX.md §12.13 Acceptance-D01-01行 | “PWC-40有真实映射但矩阵:3532那一行…”；写入时:3532为续行，含PWC-40映射的行为§12.13 Acceptance-D01-01 |
| 别名表 | 303 | `:10` | C19 文件头 | “FIR合同:10/:686散文” |
| 别名表 | 303 | `:686` | C19 §18 | “FIR合同:10/:686散文” |
| 别名表 | 305 | `:1099` | `tb_ppg_peak_valley_window_detector.v` `"PVW-01 through PVW-48 ALL PASS"` | TB末尾cnt_pass/cnt_fail总判定，对应其PASS打印 |
| 别名表 | 309 | tb_ppg_peak_valley_window_detector.v:534 | `tb_ppg_peak_valley_window_detector.v` `"PVW-01"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 310 | tb_ppg_peak_valley_window_detector.v:536 | `tb_ppg_peak_valley_window_detector.v` `"PVW-02"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 311 | tb_ppg_peak_valley_window_detector.v:538 | `tb_ppg_peak_valley_window_detector.v` `"PVW-03"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 313 | tb_ppg_peak_valley_window_detector.v:550 | `tb_ppg_peak_valley_window_detector.v` `"PVW-05"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 314 | tb_ppg_peak_valley_window_detector.v:560 | `tb_ppg_peak_valley_window_detector.v` `"PVW-06"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 315 | tb_ppg_peak_valley_window_detector.v:571 | `tb_ppg_peak_valley_window_detector.v` `"PVW-07"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 316 | tb_ppg_peak_valley_window_detector.v:586 | `tb_ppg_peak_valley_window_detector.v` `"PVW-08"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 317 | tb_ppg_peak_valley_window_detector.v:595 | `tb_ppg_peak_valley_window_detector.v` `"PVW-09"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 317 | tb_ppg_peak_valley_window_detector.v:615 | `tb_ppg_peak_valley_window_detector.v` `"PVW-09-WRAP"` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“已补PVW-09-WRAP(…)” |
| 别名表 | 319 | tb_ppg_peak_valley_window_detector.v:614 | `tb_ppg_peak_valley_window_detector.v` `"PVW-11"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 320 | tb_ppg_peak_valley_window_detector.v:627 | `tb_ppg_peak_valley_window_detector.v` `"PVW-12"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 321 | tb_ppg_peak_valley_window_detector.v:642 | `tb_ppg_peak_valley_window_detector.v` `"PVW-13"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 322 | tb_ppg_peak_valley_window_detector.v:658 | `tb_ppg_peak_valley_window_detector.v` `"PVW-14"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 323 | tb_ppg_peak_valley_window_detector.v:671 | `tb_ppg_peak_valley_window_detector.v` `"PVW-15"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 324 | tb_ppg_peak_valley_window_detector.v:678 | `tb_ppg_peak_valley_window_detector.v` `"PVW-16"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 325 | tb_ppg_peak_valley_window_detector.v:683 | `tb_ppg_peak_valley_window_detector.v` `"PVW-17"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 326 | tb_ppg_peak_valley_window_detector.v:692 | `tb_ppg_peak_valley_window_detector.v` `"PVW-18"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 327 | tb_ppg_peak_valley_window_detector.v:703 | `tb_ppg_peak_valley_window_detector.v` `"PVW-19"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 328 | tb_ppg_peak_valley_window_detector.v:711 | `tb_ppg_peak_valley_window_detector.v` `"PVW-20"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 329 | tb_ppg_peak_valley_window_detector.v:724 | `tb_ppg_peak_valley_window_detector.v` `"PVW-21"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 330 | tb_ppg_peak_valley_window_detector.v:733 | `tb_ppg_peak_valley_window_detector.v` `"PVW-22"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 331 | tb_ppg_peak_valley_window_detector.v:741 | `tb_ppg_peak_valley_window_detector.v` `"PVW-23"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 332 | tb_ppg_peak_valley_window_detector.v:761 | `tb_ppg_peak_valley_window_detector.v` `"PVW-24"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 333 | tb_ppg_peak_valley_window_detector.v:772 | `tb_ppg_peak_valley_window_detector.v` `"PVW-25"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 334 | tb_ppg_peak_valley_window_detector.v:781 | `tb_ppg_peak_valley_window_detector.v` `"PVW-26"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 335 | tb_ppg_peak_valley_window_detector.v:790 | `tb_ppg_peak_valley_window_detector.v` `"PVW-27"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 336 | tb_ppg_peak_valley_window_detector.v:797 | `tb_ppg_peak_valley_window_detector.v` `"PVW-28"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 337 | tb_ppg_peak_valley_window_detector.v:806 | `tb_ppg_peak_valley_window_detector.v` `"PVW-29"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 338 | tb_ppg_peak_valley_window_detector.v:816 | `tb_ppg_peak_valley_window_detector.v` `"PVW-30"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 339 | tb_ppg_peak_valley_window_detector.v:829 | `tb_ppg_peak_valley_window_detector.v` `"PVW-31"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 340 | tb_ppg_peak_valley_window_detector.v:838 | `tb_ppg_peak_valley_window_detector.v` `"PVW-32"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 340 | tb_ppg_peak_valley_window_detector.v:875 | `tb_ppg_peak_valley_window_detector.v` `"PVW-32-BUSY"` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“已补PVW-32-BUSY(…)” |
| 别名表 | 342 | tb_ppg_peak_valley_window_detector.v:854 | `tb_ppg_peak_valley_window_detector.v` `"PVW-34"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 343 | tb_ppg_peak_valley_window_detector.v:865 | `tb_ppg_peak_valley_window_detector.v` `"PVW-35"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 345 | tb_ppg_peak_valley_window_detector.v:905 | `tb_ppg_peak_valley_window_detector.v` `"PVW-37"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 346 | tb_ppg_peak_valley_window_detector.v:915 | `tb_ppg_peak_valley_window_detector.v` `"PVW-38"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 347 | tb_ppg_peak_valley_window_detector.v:921 | `tb_ppg_peak_valley_window_detector.v` `"PVW-39"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 347 | tb_ppg_peak_valley_window_detector.v:636 | `tb_ppg_peak_valley_window_detector.v` `"PVW-39-WRAP"` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“已补PVW-39-WRAP(…)” |
| 别名表 | 348 | tb_ppg_peak_valley_window_detector.v:969 | `tb_ppg_peak_valley_window_detector.v` `"PVW-40"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 349 | tb_ppg_peak_valley_window_detector.v:978 | `tb_ppg_peak_valley_window_detector.v` `"PVW-41"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 350 | tb_ppg_peak_valley_window_detector.v:989 | `tb_ppg_peak_valley_window_detector.v` `"PVW-42"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 351 | tb_ppg_peak_valley_window_detector.v:1002 | `tb_ppg_peak_valley_window_detector.v` `"PVW-43"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 352 | tb_ppg_peak_valley_window_detector.v:1036 | `tb_ppg_peak_valley_window_detector.v` `"PVW-44"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 353 | tb_ppg_peak_valley_window_detector.v:1056 | `tb_ppg_peak_valley_window_detector.v` `"PVW-45"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 354 | tb_ppg_peak_valley_window_detector.v:1096 | `tb_ppg_peak_valley_window_detector.v` `"PVW-46"` | 行ID即TB check_case用例名；写入时行号已漂移 |
| 别名表 | 358 | `:913-953` | C23 §21 | PWC合同验收表 |
| 别名表 | 362 | `:914-953` | C23 §21 | PWC合同验收表 |
| 别名表 | 376 | ppg_precision_window_controller.v:548 | `ppg_precision_window_controller.v` `@satisfies: PWC-11` | 行ID/本格点名ID在ppg_precision_window_controller.v有@satisfies标签 |
| 别名表 | 391 | ppg_precision_window_controller.v:619 | `ppg_precision_window_controller.v` `@satisfies: PWC-26` | 行ID/本格点名ID在ppg_precision_window_controller.v有@satisfies标签 |
| 别名表 | 398 | ppg_precision_window_controller.v:515 | `ppg_precision_window_controller.v` `@satisfies: PWC-33` | 行ID/本格点名ID在ppg_precision_window_controller.v有@satisfies标签 |
| 别名表 | 399 | ppg_precision_window_controller.v:684 | `ppg_precision_window_controller.v` `@satisfies: PWC-34` | 行ID/本格点名ID在ppg_precision_window_controller.v有@satisfies标签 |
| 别名表 | 462 | ppg_adc_measurement_idac_integration.v:1024 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P01` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 462 | `:1315` | `ppg_adc_measurement_idac_integration.v` `@satisfies: P01` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 462 | ppg_normal_transaction_fork.v:194-309 | `ppg_normal_transaction_fork.v` | 两分支所有权整段（194-309），文件级锚点 |
| 别名表 | 467 | ppg_adc_measurement_idac_integration.v:1569 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P06` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 468 | ppg_adc_measurement_idac_integration.v:1493 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P08` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 472 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` | 参数化位宽约束注释块，紧邻C_ADC_DRAIN_WATCHDOG_CYCLES |
| 别名表 | 474 | ppg_adc_measurement_idac_integration.v:1223 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P14` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 475 | ppg_adc_measurement_idac_integration.v:1223 | `ppg_adc_measurement_idac_integration.v` `@satisfies: LFA-04` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 475 | `:1493` | `ppg_adc_measurement_idac_integration.v` `@satisfies: LFA-04` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 476 | ppg_adc_measurement_idac_integration.v:1223 | `ppg_adc_measurement_idac_integration.v` `@satisfies: OIB-08` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 476 | `:1493` | `ppg_adc_measurement_idac_integration.v` `@satisfies: OIB-08` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 562 | :6 | （保留原文：not-anchor） | “D01链…:6段”数量，不是行号 |
| 别名表 | 568 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` | 同P12行 |

## 附录B 本批提交（`7a8eabf..f9e981b`，按时间顺序；本报告所在的提交在其后）

| 提交 | 说明 |
|---|---|
| `a1ba482` | 新增B合同合并批次交接书与F-9核查报告（只含文档） |
| `b98c021` | B合并批次：新建进度文件，记录开工前确认与用户答复（只含文档） |
| `5c80956` | B合并批次：进度条目2，阶段0基线回归启动记录（只含文档） |
| `ab319b0` | B合并批次阶段1：总表B_MERGE_BATCH_ITEMS（检查点稿，待统筹审核；只含文档） |
| `4a97591` | B合并批次：总表记录统筹审核意见，进入阶段2（只含文档） |
| `e424874` | B合并批次阶段2：C08调度器合同V1.13（BMI-001~015：末拍直接起帧与例外C、F-010滚动门控、L-1/L-3/L-4、R3作废释放与F-7、F-9 §12.3、两个新输入、START/STOP/诊断清除语义、FSC原行补充、§19状态声明订正） |
| `4946328` | B合并批次阶段2：C09 SSW合同V1.11（BMI-020~030：S1改写SSW-18/§5.4/timeout sticky、owner帧/子帧绑定、作废释放与新输入、F-035、L-6 START恢复与新增SSW-53、门禁范围与F-047版本统一） |
| `153dade` | B合并批次阶段2：C10 AMI合同V2.5（BMI-040~055、058：§7.1a完成丢失超时作废与k=2升级、cause 06/07、捕获窗口前提F-3、已知限制F-1/F-2、参数冻结F-6、新端口、discard 2'b11与F-019身份、TXN_KEY收窄与私有扇出订正、七路分发与F-4、F-020/F |
| `3fdf646` | B合并批次：进度条目5，总表标记C08/C09/C10完成（只含文档） |
| `cc197a6` | B合并批次阶段2：C24 supervisor合同V1.6（BMI-090~097：cause 06/07与summary bit 9/10、AMI fault下降条件、F-1/F-2恢复流程、§6超时作废不属伪造与不卡死保证、看门狗参数冻结与仿真开始检查、复位端口名i_rstn、SUP-10归属与证据指针） |
| `4221866` | B合并批次阶段2：C16合同V2.2（BMI-070~072：F-9 §9.4改为校准阶段并写明与物理校准宏帧的关系、F-020撤销输入与规则） |
| `983e528` | B合并批次阶段2：C18 PWI合同V2.2（BMI-071~074：F-020撤销输入、F-043窗口长度消费者订正为峰谷检测器、门禁范围PWI-01~08） |
| `5b233d1` | B合并批次阶段2：C23精度窗口控制器合同V2.7（BMI-075、085、086：F-1已知例外、F-034撤销优先于提交、PWI-01~05以C18为准） |
| `8f4f192` | B合并批次阶段2：C17 IDAC合同V2.4（BMI-080~082：F-033 §8.4末句与IDC2-17按RTL订正，F-032端口名核对） |
| `0dc226f` | B合并批次阶段2：C13合同V1.3（BMI-060、062~064：TXN_KEY收窄与代际匹配、router边界F-004订正、local_empty消费关系、登记OVL-01~17验收表） |
| `49f0ae9` | B合并批次阶段2：C25测试合同V1.8（BMI-100~101：LFA-04超时作废例外、SID-04措辞按RTL与TB订正） |
| `9c6c0dc` | B合并批次阶段2：C01顶层连接合同V1.18勘误（BMI-061、111、113、116、117：o_ami_owner_lost_sticky、正式结果discard身份收窄TXN_KEY、参数冻结与仿真开始检查、诊断清除五路扇出F-048、V1.3.4状态行属历史） |
| `a5b307c` | B合并批次阶段2：芯片顶层合同V1.17勘误（BMI-110~115：F-030 CS_N四点论证、F-007单复位同步器、读移出相位、0x0108 bit6与逐位清除方式、产品固定参数） |
| `acd6815` | B合并批次：进度更新，总表标记已完成合同项（只含文档） |
| `c95d697` | B合并批次阶段2：C02 manager合同V4.10（BMI-180：MGR-12的0x05不可达说明） |
| `60d33d1` | B合并批次阶段2：C07表征CDC合同V1.2（BMI-182：F-039复位后START前提只适用于STATIC_BIAS） |
| `cb33220` | B合并批次阶段2：C19 FIR合同V2.6（BMI-183：F-015证据状态订正、FIR范围上限FIR-33） |
| `e953a89` | B合并批次阶段2：C03 ACTIVE wrapper合同V1.7（BMI-184：AV4C范围订正） |
| `54cdb8e` | B合并批次阶段2：C21动态基线算术优化合同V1.3（BMI-136、185：登记OPTC-01/02、BSL范围订正） |
| `08be871` | B合并批次阶段2：核对表§15补记单模块全部PASS声明订正（BMI-187） |
| `aaf0c34` | B合并批次阶段2：矩阵V4.5内容项（BMI-058、080、118、120、121、124：TXN_KEY、私有扇出订正、P05去SUP06A、P06证据范围、F-032端口名、§13.2盲区与§13.3规则正文） |
| `8b2b259` | B合并批次阶段2：版本联动（15份升版合同在各依赖表与矩阵§12.4/12.4a/12.4b中的207处引用，逐条核对为文件名后首个版本号，负对照通过） |
| `a6121f2` | B合并批次：阶段2完成，新建二级清单POST_TAPEOUT_DOC_CLEANUP_LIST，进度条目6（只含文档） |
| `9e932d6` | B合并批次阶段3：从ID治理报告附录A原样提取扫描器到tools/id_governance_scan，7a8eabf重扫37处与负对照证据入库（BMI-147） |
| `aec4b14` | B合并批次：版本联动脚本verlink.py/verlink_check.py入库并可按提交复现（207/0），附干跑与负对照记录；新增strip_compare.py与anchor_check.py（开发中） |
| `fdf9aff` | B合并批次：进度条目7（旁观会话提醒的处理、阶段3/4准备状态）（只含文档） |
| `579689e` | B合并批次：将误提交的扫描器.pyc移出版本库（git rm --cached），进度条目8 |
| `3dd687b` | B合并批次阶段5脚本开发与试跑：manifest_digest.py（复现3/23、负对照、写入往返）、reconcile脚本路径改到本仓库（逻辑不变，伪ID 22个与缺行13个分类），未写入矩阵；进度条目9 |
| `35aec60` | B合并批次阶段4准备：锚点盘点与解析脚本（只试跑，不改矩阵/别名表） |
| `3b85a42` | B合并批次：进度条目10（中断点：回归中1份模块级xelab=139待重跑；阶段4解析试跑结果；TB改名脚本入库未执行） |
| `24d0b8d` | B合并批次阶段0：基线7a8eabf本机回归部分证据（Vivado 2019.2：系统16/20共985行PASS、芯片20/0、模块级27/28，FIR单元TB xelab确定性崩溃）与补跑请求（只含文档） |
| `6197609` | B合并批次阶段0：回归整套改到回归机（Vivado 2022.2，用户决定）——运行与回传说明REGRESSION_RUN_REQUEST、证据导出/比对脚本regression_evidence.py（含负对照），本机2019.2结果改为仅作参考；进度条目11 |
| `e30b46c` | B合并批次阶段0：补上一提交漏掉的内容——REGRESSION_RUN_REQUEST正文（整套回归在回归机Vivado 2022.2上跑）、regression_evidence.py（export/compare，含负对照）、本机2019.2结果改为仅作参考、进度条目11 |
| `f8986b3` | B合并批次§3.9（F-9）：ppg_amb_recheck_scheduler.v三处点名注释按“阶段沿用本阶段内帧完成”语义改写（只改注释；去注释与7a8eabf逐字节相同，gate 0/0不变，comment-only校验通过，负对照通过） |
| `70fb907` | B合并批次阶段4：anchor_check.py负对照（5处注入恰好报出5处，0处消失），证据入库 |
| `be82819` | B合并批次：订正C08 V1.13新增小节编号——启动搜索空闲边界由§8.2.3改为§8.2.6（原§8.2.3~8.2.5已存在，anchor_check报出节号重名），同步5处引用 |
| `fd348d2` | B合并批次阶段3（不依赖TB改名的部分）：别名表新增“B合同合并批次新增映射”节——13个缺行标签中AMI-24/MGR-11/SSW-22/34/38、SSW-53(L-6)、OVL-01~17、OPTC-01/02、JNT（联合TB说明§11/§5.3）、RAW↔RGC、三轮新增TB本地标签与SYS-*、IDC2/ |
| `affd3e3` | B合并批次阶段3草稿：随TB改名生效的别名表行（合同FSC-01~57↔TB本地SCHT-n、SUP/DCR/SSW-18/AMI-13/LFA-11），由ID治理§5.2生成；未写入别名表，待基线核对通过后与TB改名同提交 |
| `5b93ab1` | B合并批次阶段4：全部9702个旧锚点的人工判定与旧→新对照表（未写入矩阵和别名表） |
| `ea60432` | B合并批次阶段0：基线7a8eabf正式回归证据（Vivado 2022.2，按REGRESSION_RUN_REQUEST §1）——系统20/20、PASS共1250行、芯片20/0、模块级28/28，与参考值全部一致；含export结果、raw/原始日志、MACHINE.txt |
| `68edf17` | B合并批次阶段3：TB标签改名与别名表对照同提交（基线ea60432核对通过后执行） |
| `3b6df78` | B合并批次阶段4（写入前快照）：对照表订正与写入/复核工具 |
| `1fab116` | B合并批次阶段4：矩阵与别名表旧行号锚点一次性改为符号锚点（BMI-151/152） |
| `467a8ad` | B合并批次阶段4：RTL补@satisfies标签（BMI-160）与别名表标签锚点 |
| `de814e7` | B合并批次阶段4：锚点检查接入回归门禁（BMI-153） |
| `c15e648` | B合并批次：BMI-145 MGR区间横幅改为实际覆盖；BMI-105 C24 V1.6证据指针补新标签名 |
| `dc7175a` | B合并批次：regression_evidence.py compare按($finish时刻,文件名)比对，行号后移标FINISH_LINE_SHIFT |
| `f5f6e3f` | B合并批次阶段5：刷新矩阵§13（reconcile脚本，BMI-170） |
| `5d294db` | B合并批次阶段5：矩阵§12.4a 26行SHA-256由manifest_digest.py重算（BMI-171） |
| `c64e9dc` | B合并批次：进度条目14、总表状态（阶段4、5完成）、阶段5证据 |
| `871ff61` | B合并批次：anchor_check.py在git archive导出目录中改用目录遍历建文件索引 |
| `5d8ceba` | B合并批次：锚点门禁导出目录演示证据、运行说明与进度条目15（终版回归提交） |
| `b161d13` | B合并批次阶段6：终版5d8ceba正式回归证据（Vivado 2022.2，按REGRESSION_RUN_REQUEST §2，与基线同机同分组）——系统20/20、PASS共1250行、芯片20/0、模块级28/28；compare退出码0：SAME 42、PASSDIFF+FINISH_LINE_SHIFT 7 |
| `b0d225e` | B合并批次阶段7：批次报告B_MERGE_BATCH_REPORT_20261009、终版全量去注释证明、总表终版状态与进度条目16 |
| `a3bd8fa` | B合并批次报告文字补正：写明分支HEAD与终版回归提交5d8ceba的关系、待裁定项表述、进度条目范围 |
| `557cdfd` | B合并批次锚点第二轮（写入前快照）：按统筹10-09裁定重分类历史锚点，对照表v2与工具 |
| `9dd4333` | B合并批次锚点第二轮写入：带日期的现行结论转换、"> "历史块内锚点恢复原文（统筹10-09裁定） |
| `f50b2ca` | B合并批次：supervisor补@satisfies: SUP-08（统筹10-09裁定，只改注释） |
| `3570ab6` | B合并批次：C24 supervisor合同V1.7——SUP-08按RTL改写（统筹10-09裁定） |
| `98a61e4` | B合并批次：C24 V1.6→V1.7版本联动（16处：各依赖表与矩阵§12.4/12.4a/12.4b） |
| `a2f1533` | B合并批次：别名表SUP-08行、矩阵§13.1刷新与E/B两类去向（统筹10-09裁定） |
| `f9e981b` | B合并批次：矩阵§12.4a摘要重算（锚点第二轮、C24 V1.7及版本联动之后） |
