# B合同合并批次报告（B_MERGE_BATCH_REPORT_20261009）

> 依据：`verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`（下称“交接书”）§7。
> 分支：`b-merge-batch`；基线：`7a8eabf`；终版回归提交：`5d8ceba`；终版回归证据：`b161d13`。
> 分支最终提交是本报告所在的提交（`b-merge-batch` HEAD）。相对终版回归提交`5d8ceba`的改动如下，可用`git diff --stat 5d8ceba HEAD`复核：`rtl/`只有一处注释改动（supervisor补`@satisfies: SUP-08`，去注释后与`7a8eabf`逐字节相同，见`final_strip_proof/`）；`contracts/`为锚点第二轮、C24 V1.7（SUP-08改写）及其版本联动、别名表SUP-08行、矩阵§13.1与§12.4a；`tools/`为锚点工具第二、三轮（`anchor_history_rules.py`、`anchor_semantics.py`、`anchor_round3.py`、增量写入与复核）、anchor_check语义模式（随门禁执行）、`verlink`第二次联动、reconcile报告刷新。TB与RTL逻辑没有改动，统筹已裁定这些改动不需要重跑全套回归，终版回归结论适用于分支HEAD。
> 总表：`verification_reports/B_MERGE_BATCH_ITEMS.md`。进度记录：`verification_reports/B_MERGE_BATCH_PROGRESS.md`（条目1~20）。
> 二级清单：`verification_reports/POST_TAPEOUT_DOC_CLEANUP_LIST.md`。证据目录：`verification_reports/b_merge_batch_evidence/`。

---

## 0. 结论

- **合同、矩阵、别名表已按基线`7a8eabf`的RTL一次性改对。** 总表139项中：
  - 已完成116项（含并入BMI-133的BMI-012）；
  - 只登记或不做8项，各有理由（§3）；
  - 二级登记2项，已进二级清单；
  - 排除项13项，各有去向（§3.3；BMI-911、BMI-912为统筹10-09、10-10意见新增）；
  - 待裁定0项。报告初稿§9列出的6项执行判断，统筹已于2026-10-09裁定并已执行（§9）。
- **RTL逻辑没有改动。** 6个RTL文件只动了注释：§3.9点名的3处，加上`@satisfies`17处（含按统筹裁定补的SUP-08）。去掉注释后，与`7a8eabf`逐字节相同。
- **TB只改了标签字符串。** 7个TB去掉注释和字符串后与`7a8eabf`相同（§5）。
- **符号锚点体系已建立并接入门禁。**
  - 矩阵与别名表的9702个旧行号锚点全部有了去向：9254处改为符号锚点；440处作为历史保留（①删除线内8、②"> "历史块30、③被后续条目取代的旧条目402）；8处为非锚点、仓库外引用或其它历史。按统筹10-09裁定，带日期的现行结论也已转换（锚点第二轮）；按统筹10-10核对意见，又做了语义一致性复查（锚点第三轮，§8）。其后按统筹的跟进意见补正了端口台账：端口列是行主题，锚点文件有同名端口即取同名。第三轮终版相对第二轮共改写554处，低置信56处列表。
  - `anchor_check.py`在HEAD上0报错，含语义模式，规则有两条：锚点符号必须等于格内写明的符号；端口台账行中，锚点文件有本行同名端口时，锚点必须取它。该模式随门禁执行，负对照恰好命中。
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
| BMI-912 | SUP-08：cause 8'h01、8'h03经STOPPING后不复位重启的检查（终版TB只覆盖8'h02/06/07） | P1补测试，用现有注入机制构造（统筹10-10），本批不做 |
| MGR-21 | 校准责任边界，合同要求三模块联合TB | 单元TB无此检查；MGR横幅已注明例外（BMI-145）。补检查属补测试 |

## 4. 回归比对结论

### 4.1 环境

- **本机Vivado 2019.2只作参考。** 本机基线中途被打断：Claude进程退出时，后台仿真被一并结束。另外，`tb_ppg_coarse_detection_fir`的xelab在“Completed static elaboration”后确定性崩溃（`EXCEPTION_ACCESS_VIOLATION`）。在无其它负载时重跑两次，都在同一位置崩溃，判为2019.2的工具缺陷。没有改RTL或TB。
  - 本机已跑完的44个TB，PASS行与`$finish`与2022.2结果完全相同（旁观会话核对）。
  - 本机部分证据在`baseline_7a8eabf_vivado2019.2_partial/`（`24d0b8d`）。
- **正式基线与终版**都在回归机上运行：i5-10400，Vivado Simulator v2022.2，同一分组，在`git archive`导出目录中执行（交接书§6.8）。运行与回传方法见`REGRESSION_RUN_REQUEST.md`。分支最终提交是本报告所在的提交（`b-merge-batch` HEAD）。相对终版回归提交`5d8ceba`的改动如下，可用`git diff --stat 5d8ceba HEAD`复核：`rtl/`只有一处注释改动（supervisor补`@satisfies: SUP-08`，去注释后与`7a8eabf`逐字节相同，见`final_strip_proof/`）；`contracts/`为锚点第二轮、C24 V1.7（SUP-08改写）及其版本联动、别名表SUP-08行、矩阵§13.1与§12.4a；`tools/`为锚点工具第二、三轮（`anchor_history_rules.py`、`anchor_semantics.py`、`anchor_round3.py`、增量写入与复核）、anchor_check语义模式（随门禁执行）、`verlink`第二次联动、reconcile报告刷新。TB与RTL逻辑没有改动，统筹已裁定这些改动不需要重跑全套回归，终版回归结论适用于分支HEAD。
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
| anchor_check语义模式（第三轮新增） | 在第三轮前文本上报出71处，含矩阵1442行（锚点`o_system_fault_discard_event`，格内声明原文为`o_system_fault_cause`）；在副本中把锚点换成同文件中存在的另一端口（W1、W2各1处），恰好报出2处；同副本`--no-semantic`为0报错 | `anchor_conversion/round3/semantic_negctl.md` |
| anchor_check端口台账检查（第三轮补正新增） | 在已推送第三轮文本（`77d281a`）上：第5列报出49个锚点（44行，对应统筹的49/493），其它列230个，W10写明名21个。在副本中各改1处，恰好各报出1处：一行三个模块锚点中只把AMI一个换成AMI相邻端口；一个Consumer锚点换成相邻例化连接；一个W10锚点换成相邻连接。未改副本与`--no-semantic`均为0报错 | `anchor_conversion/round3b/port_negctl.md`、`round3b/review.md` |
| `anchor_semantics.py` | 19个构造样例全对：W1~W7、W10，无写明符号的反例，related()正反例 | `anchor_conversion/round3b/semantics_selftest.txt` |
| `anchor_verify.py --previous`（第二轮） | 注入4处（撤销一处新增转换、保留一处应回退的转换、改写回错符号、改非锚点文字），恰好报出4处；anchor_check在其范围内报出2处 | `anchor_conversion/round2/negctl.md` |
| `tools/id_governance_scan` | 重扫37处，负对照恰好多报2处 | `id_rescan/` |

最终状态：HEAD上`anchor_check.py` 0报错（符号锚点6707、`@satisfies` 188、TB标签184、合同节号2812、写明名核对1847处、端口台账1803行/5545个锚点、语义例外5处、allowlist 20行）；`manifest_digest.py --rev HEAD` 26/26。

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
- **第三轮：语义一致性复查**（统筹2026-10-10核对意见；快照`ad905e8`，写入`c0190c1`）：
  - **根因**：仓库git历史始于2026-09-28的导入提交`b858bf0`。凡在此之前写入的矩阵或别名表行，git blame都落在导入提交（第一轮统计4103个锚点），所以“写入时版本”取晚了，被引文件的行号可能已漂移。例如§12.5台账写于09-16，09-18的SID-05改动使行号偏移2行。解析器又让该行内容压过了格内写明的符号（违反交接书§3.13 Q1），于是矩阵§12.5 `o_system_fault_cause`行的锚点被解析为`o_system_fault_discard_event`。
  - **(a) 格内写明的符号为准**：判定见`tools/b_merge_tools/anchor_semantics.py`，包括W1锚点后的声明原文、W2/W3“模块.端口（…声明”、W4“Top内部网”、W5“Top边界输入/输出”+本行端口、W6/W7括注内名，以及W8“`a.v:N` (`b.v:M`)”括注锚点取前一锚点的符号。纠正105处（同文件55、换文件38、人工12），人工保留1处。
  - **(b) 无格内符号的锚点**：解析符号必须出现在本行，或与本行端口同名（i_/o_互为对端）。不满足的，按以下方式处理：别名表行ID在该文件有`@satisfies`标签的改为标签（79）；写入时点为导入提交的，在导入版本被引行±5行内找本行所述符号，找到即改（漂移校正63）；写入时点为真实提交的保留（246）；仍无法确认的保留原解析、标“低置信”并列表（141），不猜。
  - **(c)** 98个uncertain一并复查，其中4个改为行ID标签。第二轮新转换的1455个和全部人工判定也都在复查范围内。
  - 第三轮改写247处（a类105、b类142），0处无法定位；anchor_verify对快照0不符。
  - **(d) 检查模式**：anchor_check新增语义模式，覆盖矩阵与别名表全部行，§12.5 G-FP-01端口台账及其它带端口/信号列的表都在内。规则：锚点符号必须等于格内写明的符号，不等即报错。4处经人工判定保留的情形记入`tools/b_merge_tools/anchor_semantic_exceptions.json`，按行SHA-1与锚点原文绑定。该模式默认开启，经`run_anchor_gate.sh`进入门禁。
  - 被纠正项全表、人工保留与低置信列表见`anchor_conversion/round3/review.md`。
- **第三轮补正：端口台账以端口列为行主题**（统筹10-10核对意见的跟进；快照`85e8678`，写入`de06123`）：
  - **起因**：已推送的第三轮中，矩阵1362、1366、1376、1378等端口台账行（当前行号）的第5列仍取错。(a)只认格内写明的符号，而第5列只写“（子模块声明）”。另外，(b)把“写入时点为真实提交”的246个锚点当作可靠而保留，这一前提不成立：blame给出的是最后改动该行的提交，不是写入锚点的提交。例如矩阵1867~1923行的Consumer锚点blame为`bb39a0f`，Top例化端口表实际已漂移15行以上。
  - **规则**：
    - W9：端口台账第5列中，锚点文件有本行同名端口（声明或例化连接`.port(`）即取同名。该模块确实没有同名时，在决定表写明理由；只有1处，即F-032改名的`i_status_clear_event`→`i_diag_clear_event`。
    - W9b：其它列无格内符号、原解析与本行无关、而锚点文件有本行端口的，取本行端口。
    - W10：锚点后写明`` `.port()` ``的，以它为写明名。
    - 撤销“写入时点可靠”类：一律做写入时版本与导入版本±5行的漂移搜索，找不到就标低置信。
    - 关联判定改为词干互相包含；行内写明的`family_*`通配族视为关联；行内的文件名不算写明了例化名。
  - **与统筹49/493对照**：矩阵第5列含锚点的端口台账行恰为493行。已推送文本中，第5列错误锚点49个，分布在44行（5行各有2个模块锚点同时错）。第5列以外另有230个（W9b类），W10写明名不一致21个，一并改正。
  - **结果**：第三轮终版计数为：(a)纠正178（W9 94、同文件31、换文件38、人工15），(a)保留2；(b)纠正376（W9b 294、行ID标签78、漂移4），低置信56。
  - 相对已推送第三轮增量改写311处（286行），0处无法定位，anchor_verify对快照0不符。
  - 新增的端口台账检查（anchor_check 1c）报出另外2处：基线2927、2990行，例化名被误认为“行内写明”，实为行内文件名。补“文件名不算写明”后改正。所以写入提交中的对照表比快照多改2处。人工判定保留1处（矩阵2242行`REASON_RECHECK`），记入例外表。
  - 全表与低置信列表见`anchor_conversion/round3b/review.md`。
- **结果**（附录A）：

| 分类 | 数量 |
|---|---:|
| 自动转换 | 8288 |
| 人工判定后转换（含第三轮纠正） | 966 |
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
| 4 | SUP-08未改写、未补标签 | 本次一起改：扩写为“AMI阻断类故障（错配、连续完成丢失cause 06、长期忙cause 07）经supervisor进入STOPPING后，不复位即可合法重启”，补`@satisfies: SUP-08`，别名表映射adc_anomaly TB的重启检查 | C24 V1.7（`3570ab6`）；supervisor episode关闭分支补标签，只改注释（strip IDENTICAL、comment-only成功、gate 1/0→1/0）；版本联动16处（`98a61e4`，verlink_check 16/0）；别名表SUP-08行（`a2f1533`）。覆盖范围如实写出：8'h06由SYS-RESTART-K、SYS-L5-RESTART、SYS-RESTART-CAL覆盖；8'h07由SYS-RESTART-BUSY覆盖；错配类只有8'h02，由SYS-RESTART-IDLE、SYS-RESTART-NEXTRUN、SYS-RESTART-WIN、SYS-RESTART-WIN2覆盖；8'h01、8'h03的重启该TB未覆盖，统筹10-10意见列入P1补测试（用现有注入机制构造，总表BMI-912），本批不做 |
| 5 | E_STALE_MATRIX_TEXT 16项与B_TAG_MISSING 22项 | 列入流片前验证收尾计划的逐ID闭环（V8），不进二级清单 | 总表新增BMI-911；矩阵§13.1注明去向；reconcile重跑为327个ID、A 288（SUP-08转A） |
| 6 | 别名表3处引用未入库的会话交接文档 | 接受 | 维持，标为仓库外引用 |

RTL和TB不变，按统筹裁定不重跑全套回归。

统筹2026-10-10对`9d62ad4`的核对意见（第1、4项确认完成；发现第一轮转换遗留的符号错误）已执行：锚点第三轮语义一致性复查（§8）；SUP-08 cause 01/03重启检查列入P1补测试（BMI-912）。其后按统筹跟进意见补正了端口台账锚点（§8“第三轮补正”）。RTL和TB仍不变，不重跑回归。

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
- **执行统筹10-10核对意见**（进度条目19）：
  - `ad905e8`：锚点第三轮快照。
  - `c0190c1`：第三轮写入与anchor_check语义模式。
  - `510fd8d`：§12.4a重算。
- **执行统筹10-10核对意见的跟进**（进度条目20）：
  - `85e8678`：第三轮补正快照。
  - `de06123`：补正写入，anchor_check新增端口台账检查与W10。
  - `4010f2e`：§12.4a重算。
- 旁观会话说明：它此前核对锚点时只验证了符号存在、门禁0报错，没有核对符号是否就是本行所指的符号。
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

完整对照表共9702行，见`verification_reports/b_merge_batch_evidence/anchor_conversion/anchor_mapping_table.tsv`（第三轮补正后终版）。每行一个旧锚点：文件、基线行号、行SHA-1、列、旧文本、类别、写入时提交、分类、新文本、来源、理由。第一、二轮的表分别为同目录`anchor_mapping_table_round1.tsv`、`anchor_mapping_table_round2.tsv`。写入与复核记录：第一轮`anchor_apply_report.tsv`/`anchor_verify.txt`，第二轮`round2/`，第三轮`round3/`。第三轮的被纠正项全表、人工保留与低置信列表见`round3/review.md`；补正后的改写与低置信列表见`round3b/review.md`。下面是终版分类计数，以及全部人工判定与第三轮纠正。

### A.1 分类计数（终版）

| 文件 | 分类 | 来源 | 数量 |
|---|---|---|---:|
| PPG_ALIAS_MAPPING_TABLE.md | convert | auto | 677 |
| PPG_ALIAS_MAPPING_TABLE.md | convert | manual | 192 |
| PPG_ALIAS_MAPPING_TABLE.md | external | manual | 3 |
| PPG_ALIAS_MAPPING_TABLE.md | history | manual | 1 |
| PPG_ALIAS_MAPPING_TABLE.md | history-block | auto | 3 |
| PPG_ALIAS_MAPPING_TABLE.md | history-strike | auto | 8 |
| PPG_ALIAS_MAPPING_TABLE.md | history-superseded-struck | auto | 4 |
| PPG_ALIAS_MAPPING_TABLE.md | not-anchor | manual | 3 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | convert | auto | 7611 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | convert | manual | 774 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | history-block | auto | 27 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | history-superseded-struck | auto | 398 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | not-anchor | manual | 1 |

分类说明：history-strike为裁定①（删除线内且同格无接续条目）；history-block为裁定②；history-superseded-struck为裁定③（删除线内旧条目，同格后接取代条目）；history-revision与history-superseded均为0个，未出现在表中。

### A.2 人工判定与第三轮纠正（974条）

来源：`tools/b_merge_tools/anchor_manual_decisions.tsv`（第一、二轮）与`tools/b_merge_tools/anchor_round3_decisions.tsv`（第三轮及补正）。理由以“第二轮”“第三轮”开头的分别为统筹10-09、10-10意见后新增。“基线行”是`7a8eabf`中的行号。

| 文件 | 基线行 | 旧锚点 | 新文本 | 理由 |
|---|---:|---|---|---|
| 矩阵 | 934 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点为导入提交，行号可能漂移；解析符号C_ADC_DRAIN_WATCHDOG_CYCLES与本行无关联，±5行内也无本行所述符号；第二轮（统筹10-09裁定：带日期的现行结论一律转换）：参数化位宽约束注释块，同alias P12行 |
| 矩阵 | 937 | ppg_control_top.v:1378-1439 | `ppg_control_top.v` `ppg_system_fault_abort_supervisor_Inst` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点为导入提交，行号可能漂移；解析符号ppg_system_fault_abort_supervisor_Inst与本行无关联，±5行内也无本行所述符号；第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内写明“C24 supervisor instantiation” |
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
| 矩阵 | 1323 | ppg_400hz_frame_calibration_scheduler.v:95 | `ppg_400hz_frame_calibration_scheduler.v` `i_active_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_active_precision_mode`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_input_source（导入版本行号漂移） |
| 矩阵 | 1323 | ppg_400hz_frame_calibration_scheduler.v:95 | `ppg_400hz_frame_calibration_scheduler.v` `i_active_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_active_precision_mode`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_input_source（导入版本行号漂移） |
| 矩阵 | 1324 | ppg_control_top.v:121 | `ppg_control_top.v` `i_adc_physical_idle` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1324 | ppg_control_top.v:121 | `ppg_control_top.v` `i_adc_physical_idle` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1325 | ppg_400hz_frame_calibration_scheduler.v:84 | `ppg_400hz_frame_calibration_scheduler.v` `i_allow_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_allow_new_transaction`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_active_config_valid（导入版本行号漂移） |
| 矩阵 | 1325 | ppg_adc_measurement_idac_integration.v:101 | `ppg_adc_measurement_idac_integration.v` `i_allow_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_allow_new_transaction`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_active_config_valid（导入版本行号漂移） |
| 矩阵 | 1325 | ppg_400hz_frame_calibration_scheduler.v:84 | `ppg_400hz_frame_calibration_scheduler.v` `i_allow_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_allow_new_transaction`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_active_config_valid（导入版本行号漂移） |
| 矩阵 | 1325 | ppg_adc_measurement_idac_integration.v:101 | `ppg_adc_measurement_idac_integration.v` `i_allow_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_allow_new_transaction`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_active_config_valid（导入版本行号漂移） |
| 矩阵 | 1326 | ppg_400hz_frame_calibration_scheduler.v:98 | `ppg_400hz_frame_calibration_scheduler.v` `i_ami_fault_blocking` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_ami_fault_blocking`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_normal_measurement_eligible（导入版本行号漂移） |
| 矩阵 | 1326 | ppg_400hz_frame_calibration_scheduler.v:98 | `ppg_400hz_frame_calibration_scheduler.v` `i_ami_fault_blocking` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_ami_fault_blocking`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_normal_measurement_eligible（导入版本行号漂移） |
| 矩阵 | 1327 | ppg_400hz_frame_calibration_scheduler.v:165 | `ppg_400hz_frame_calibration_scheduler.v` `i_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_analog_safe`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_owner_q3_window_closed（导入版本行号漂移） |
| 矩阵 | 1327 | ppg_adc_measurement_idac_integration.v:142 | `ppg_adc_measurement_idac_integration.v` `i_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_analog_safe`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_clk_stage2_dout_low_async（导入版本行号漂移） |
| 矩阵 | 1327 | ppg_400hz_frame_calibration_scheduler.v:165 | `ppg_400hz_frame_calibration_scheduler.v` `i_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_analog_safe`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_owner_q3_window_closed（导入版本行号漂移） |
| 矩阵 | 1327 | ppg_adc_measurement_idac_integration.v:142 | `ppg_adc_measurement_idac_integration.v` `i_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_analog_safe`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_clk_stage2_dout_low_async（导入版本行号漂移） |
| 矩阵 | 1332 | ppg_control_top.v:114 | `ppg_control_top.v` `i_control_abort_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1332 | ppg_control_top.v:114 | `ppg_control_top.v` `i_control_abort_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1334 | ppg_control_top.v:113 | `ppg_control_top.v` `i_diag_clear_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1334 | ppg_control_top.v:113 | `ppg_control_top.v` `i_diag_clear_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1334 | `:515` | C01 §5.2 | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“§5.2（当前:515）”指C01合同行 |
| 矩阵 | 1335 | ppg_adc_measurement_idac_integration.v:144 | `ppg_adc_measurement_idac_integration.v` `i_idac_code_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_idac_code_safe_boundary`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_analog_safe（导入版本行号漂移） |
| 矩阵 | 1335 | ppg_adc_measurement_idac_integration.v:144 | `ppg_adc_measurement_idac_integration.v` `i_idac_code_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_idac_code_safe_boundary`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_analog_safe（导入版本行号漂移） |
| 矩阵 | 1339 | ppg_adc_measurement_idac_integration.v:143 | `ppg_adc_measurement_idac_integration.v` `i_macro_frame_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_macro_frame_safe_boundary`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_adc_idle（导入版本行号漂移） |
| 矩阵 | 1339 | ppg_adc_measurement_idac_integration.v:143 | `ppg_adc_measurement_idac_integration.v` `i_macro_frame_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_macro_frame_safe_boundary`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_adc_idle（导入版本行号漂移） |
| 矩阵 | 1343 | ppg_400hz_frame_calibration_scheduler.v:96 | `ppg_400hz_frame_calibration_scheduler.v` `i_normal_measurement_eligible` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_normal_measurement_eligible`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_optical_mode（导入版本行号漂移） |
| 矩阵 | 1343 | ppg_400hz_frame_calibration_scheduler.v:96 | `ppg_400hz_frame_calibration_scheduler.v` `i_normal_measurement_eligible` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_normal_measurement_eligible`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_optical_mode（导入版本行号漂移） |
| 矩阵 | 1344 | ppg_400hz_frame_calibration_scheduler.v:94 | `ppg_400hz_frame_calibration_scheduler.v` `i_optical_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_optical_mode`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_run_profile（导入版本行号漂移） |
| 矩阵 | 1344 | ppg_400hz_frame_calibration_scheduler.v:94 | `ppg_400hz_frame_calibration_scheduler.v` `i_optical_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_optical_mode`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_run_profile（导入版本行号漂移） |
| 矩阵 | 1348 | ppg_400hz_frame_calibration_scheduler.v:89 | `ppg_400hz_frame_calibration_scheduler.v` `i_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_run_generation`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_control_abort_event（导入版本行号漂移） |
| 矩阵 | 1348 | ppg_adc_measurement_idac_integration.v:106 | `ppg_adc_measurement_idac_integration.v` `i_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_run_generation`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_control_abort_event（导入版本行号漂移） |
| 矩阵 | 1348 | ppg_400hz_frame_calibration_scheduler.v:89 | `ppg_400hz_frame_calibration_scheduler.v` `i_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_run_generation`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_control_abort_event（导入版本行号漂移） |
| 矩阵 | 1348 | ppg_adc_measurement_idac_integration.v:106 | `ppg_adc_measurement_idac_integration.v` `i_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_run_generation`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_control_abort_event（导入版本行号漂移） |
| 矩阵 | 1349 | ppg_adc_measurement_idac_integration.v:244 | `ppg_adc_measurement_idac_integration.v` `i_run_profile` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_run_profile`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_dc15_recovery_gain_q16（导入版本行号漂移） |
| 矩阵 | 1349 | ppg_adc_measurement_idac_integration.v:244 | `ppg_adc_measurement_idac_integration.v` `i_run_profile` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_run_profile`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_dc15_recovery_gain_q16（导入版本行号漂移） |
| 矩阵 | 1350 | ppg_adc_measurement_idac_integration.v:145 | `ppg_adc_measurement_idac_integration.v` `i_safe_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_safe_frame_id`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_macro_frame_safe_boundary（导入版本行号漂移） |
| 矩阵 | 1350 | ppg_adc_measurement_idac_integration.v:145 | `ppg_adc_measurement_idac_integration.v` `i_safe_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_safe_frame_id`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_macro_frame_safe_boundary（导入版本行号漂移） |
| 矩阵 | 1351 | ppg_400hz_frame_calibration_scheduler.v:166 | `ppg_400hz_frame_calibration_scheduler.v` `i_sar_timing_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_sar_timing_idle`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_adc_idle（导入版本行号漂移） |
| 矩阵 | 1351 | ppg_400hz_frame_calibration_scheduler.v:166 | `ppg_400hz_frame_calibration_scheduler.v` `i_sar_timing_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_sar_timing_idle`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_adc_idle（导入版本行号漂移） |
| 矩阵 | 1354 | ppg_control_top.v:99 | `ppg_control_top.v` `i_source_rstn` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1354 | ppg_control_top.v:99 | `ppg_control_top.v` `i_source_rstn` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1357 | ppg_400hz_frame_calibration_scheduler.v:99 | `ppg_400hz_frame_calibration_scheduler.v` `i_ssw_fault_blocking` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_ssw_fault_blocking`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_switch_hold_new_transaction（导入版本行号漂移） |
| 矩阵 | 1357 | ppg_400hz_frame_calibration_scheduler.v:99 | `ppg_400hz_frame_calibration_scheduler.v` `i_ssw_fault_blocking` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_ssw_fault_blocking`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_switch_hold_new_transaction（导入版本行号漂移） |
| 矩阵 | 1358 | ppg_400hz_frame_calibration_scheduler.v:85 | `ppg_400hz_frame_calibration_scheduler.v` `i_start_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_start_ack_event`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_run_enable（导入版本行号漂移） |
| 矩阵 | 1358 | ppg_adc_measurement_idac_integration.v:102 | `ppg_adc_measurement_idac_integration.v` `i_start_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_start_ack_event`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_run_enable（导入版本行号漂移） |
| 矩阵 | 1358 | ppg_400hz_frame_calibration_scheduler.v:85 | `ppg_400hz_frame_calibration_scheduler.v` `i_start_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_start_ack_event`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_run_enable（导入版本行号漂移） |
| 矩阵 | 1358 | ppg_adc_measurement_idac_integration.v:102 | `ppg_adc_measurement_idac_integration.v` `i_start_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_start_ack_event`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_run_enable（导入版本行号漂移） |
| 矩阵 | 1360 | ppg_400hz_frame_calibration_scheduler.v:86 | `ppg_400hz_frame_calibration_scheduler.v` `i_stop_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_stop_ack_event`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_allow_new_transaction（导入版本行号漂移） |
| 矩阵 | 1360 | ppg_adc_measurement_idac_integration.v:103 | `ppg_adc_measurement_idac_integration.v` `i_stop_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_stop_ack_event`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_allow_new_transaction（导入版本行号漂移） |
| 矩阵 | 1360 | ppg_400hz_frame_calibration_scheduler.v:86 | `ppg_400hz_frame_calibration_scheduler.v` `i_stop_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_stop_ack_event`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_allow_new_transaction（导入版本行号漂移） |
| 矩阵 | 1360 | ppg_adc_measurement_idac_integration.v:103 | `ppg_adc_measurement_idac_integration.v` `i_stop_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_stop_ack_event`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_allow_new_transaction（导入版本行号漂移） |
| 矩阵 | 1363 | ppg_400hz_frame_calibration_scheduler.v:97 | `ppg_400hz_frame_calibration_scheduler.v` `i_switch_hold_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_switch_hold_new_transaction`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_active_precision_mode（导入版本行号漂移） |
| 矩阵 | 1363 | ppg_400hz_frame_calibration_scheduler.v:97 | `ppg_400hz_frame_calibration_scheduler.v` `i_switch_hold_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_switch_hold_new_transaction`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_active_precision_mode（导入版本行号漂移） |
| 矩阵 | 1365 | ppg_control_top.v:130 | `ppg_control_top.v` `i_test_identity_inject_sample_index` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1365 | ppg_control_top.v:130 | `ppg_control_top.v` `i_test_identity_inject_sample_index` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1368 | ppg_control_top.v:131 | `ppg_control_top.v` `i_test_invalid_sample_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1368 | ppg_control_top.v:131 | `ppg_control_top.v` `i_test_invalid_sample_valid` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1369 | ppg_adc_measurement_idac_integration.v:133 | `ppg_adc_measurement_idac_integration.v` `i_transaction_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_amb_code_epoch`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_amb_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1369 | ppg_adc_measurement_idac_integration.v:133 | `ppg_adc_measurement_idac_integration.v` `i_transaction_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_amb_code_epoch`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_amb_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1370 | ppg_adc_measurement_idac_integration.v:131 | `ppg_adc_measurement_idac_integration.v` `i_transaction_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_amb_code_snapshot`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_color_ir（导入版本行号漂移） |
| 矩阵 | 1370 | ppg_adc_measurement_idac_integration.v:131 | `ppg_adc_measurement_idac_integration.v` `i_transaction_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_amb_code_snapshot`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_color_ir（导入版本行号漂移） |
| 矩阵 | 1371 | ppg_adc_measurement_idac_integration.v:129 | `ppg_adc_measurement_idac_integration.v` `i_transaction_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_color_ir`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_frame_id（导入版本行号漂移） |
| 矩阵 | 1371 | ppg_adc_measurement_idac_integration.v:129 | `ppg_adc_measurement_idac_integration.v` `i_transaction_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_color_ir`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_frame_id（导入版本行号漂移） |
| 矩阵 | 1372 | ppg_adc_measurement_idac_integration.v:134 | `ppg_adc_measurement_idac_integration.v` `i_transaction_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_dc_code_epoch`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_dc_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1372 | ppg_adc_measurement_idac_integration.v:134 | `ppg_adc_measurement_idac_integration.v` `i_transaction_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_dc_code_epoch`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_dc_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1373 | ppg_adc_measurement_idac_integration.v:132 | `ppg_adc_measurement_idac_integration.v` `i_transaction_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_dc_code_snapshot`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_frame_type（导入版本行号漂移） |
| 矩阵 | 1373 | ppg_adc_measurement_idac_integration.v:132 | `ppg_adc_measurement_idac_integration.v` `i_transaction_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_dc_code_snapshot`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_frame_type（导入版本行号漂移） |
| 矩阵 | 1374 | ppg_adc_measurement_idac_integration.v:127 | `ppg_adc_measurement_idac_integration.v` `i_transaction_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_frame_id`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_adc_complete_sample_index（导入版本行号漂移） |
| 矩阵 | 1374 | ppg_adc_measurement_idac_integration.v:127 | `ppg_adc_measurement_idac_integration.v` `i_transaction_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_frame_id`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_adc_complete_sample_index（导入版本行号漂移） |
| 矩阵 | 1375 | ppg_adc_measurement_idac_integration.v:130 | `ppg_adc_measurement_idac_integration.v` `i_transaction_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_frame_type`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_sample_index（导入版本行号漂移） |
| 矩阵 | 1375 | ppg_adc_measurement_idac_integration.v:130 | `ppg_adc_measurement_idac_integration.v` `i_transaction_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_frame_type`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_sample_index（导入版本行号漂移） |
| 矩阵 | 1376 | ppg_adc_measurement_idac_integration.v:126 | `ppg_adc_measurement_idac_integration.v` `i_transaction_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_precision_mode`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_adc_transaction_success（导入版本行号漂移） |
| 矩阵 | 1376 | ppg_adc_measurement_idac_integration.v:126 | `ppg_adc_measurement_idac_integration.v` `i_transaction_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_precision_mode`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_adc_transaction_success（导入版本行号漂移） |
| 矩阵 | 1377 | ppg_adc_measurement_idac_integration.v:128 | `ppg_adc_measurement_idac_integration.v` `i_transaction_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_sample_index`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_precision_mode（导入版本行号漂移） |
| 矩阵 | 1377 | ppg_adc_measurement_idac_integration.v:128 | `ppg_adc_measurement_idac_integration.v` `i_transaction_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`i_transaction_sample_index`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为i_transaction_precision_mode（导入版本行号漂移） |
| 矩阵 | 1381 | `:410` | `ppg_control_top.v` `measurement_allow_new_transaction` | 第二轮：“Top内部网`measurement_allow_new_transaction`（:N）”，按格内网名 |
| 矩阵 | 1383 | ppg_400hz_frame_calibration_scheduler.v:183 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_frame_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_calibration_frame_active`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_scheduler_idle（导入版本行号漂移） |
| 矩阵 | 1383 | ppg_400hz_frame_calibration_scheduler.v:183 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_frame_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_calibration_frame_active`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_scheduler_idle（导入版本行号漂移） |
| 矩阵 | 1384 | ppg_400hz_frame_calibration_scheduler.v:176 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_local_tick` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_calibration_local_tick`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_macro_tick（导入版本行号漂移） |
| 矩阵 | 1384 | ppg_400hz_frame_calibration_scheduler.v:176 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_local_tick` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_calibration_local_tick`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_macro_tick（导入版本行号漂移） |
| 矩阵 | 1387 | ppg_400hz_frame_calibration_scheduler.v:175 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_subframe_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_calibration_subframe_index`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_safe_frame_id（导入版本行号漂移） |
| 矩阵 | 1387 | ppg_400hz_frame_calibration_scheduler.v:175 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_subframe_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_calibration_subframe_index`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_safe_frame_id（导入版本行号漂移） |
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
| 矩阵 | 1395 | ppg_adc_measurement_idac_integration.v:355 | `ppg_adc_measurement_idac_integration.v` `o_datapath_empty` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_datapath_empty`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_adc_chain_idle（导入版本行号漂移） |
| 矩阵 | 1395 | ppg_adc_measurement_idac_integration.v:355 | `ppg_adc_measurement_idac_integration.v` `o_datapath_empty` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_datapath_empty`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_adc_chain_idle（导入版本行号漂移） |
| 矩阵 | 1395 | `:1524` | `ppg_control_top.v` `o_ami_datapath_empty` | 第二轮：“Top内部网`o_ami_datapath_empty`（:N）”，按格内网名 |
| 矩阵 | 1395 | `:218` | `ppg_control_top.v` `o_ami_datapath_empty` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_ami_datapath_empty`同名输出端口 |
| 矩阵 | 1397 | ppg_400hz_frame_calibration_scheduler.v:171 | `ppg_400hz_frame_calibration_scheduler.v` `o_idac_code_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_code_safe_boundary`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_macro_frame_start_event（导入版本行号漂移） |
| 矩阵 | 1397 | ppg_400hz_frame_calibration_scheduler.v:171 | `ppg_400hz_frame_calibration_scheduler.v` `o_idac_code_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_code_safe_boundary`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_macro_frame_start_event（导入版本行号漂移） |
| 矩阵 | 1398 | ppg_adc_measurement_idac_integration.v:303 | `ppg_adc_measurement_idac_integration.v` `o_idac_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_idle`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_idac_fault_blocking（导入版本行号漂移） |
| 矩阵 | 1398 | ppg_adc_measurement_idac_integration.v:303 | `ppg_adc_measurement_idac_integration.v` `o_idac_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_idle`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_idac_fault_blocking（导入版本行号漂移） |
| 矩阵 | 1398 | `:1525` | `ppg_control_top.v` `o_ami_idac_idle` | 第二轮：“Top内部网`o_ami_idac_idle`（:N）”，按格内网名 |
| 矩阵 | 1398 | `:219` | `ppg_control_top.v` `o_ami_idac_idle` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_ami_idac_idle`同名输出端口 |
| 矩阵 | 1402 | ppg_400hz_frame_calibration_scheduler.v:174 | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_tick` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_macro_tick`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_startup_idac_safe_boundary（导入版本行号漂移） |
| 矩阵 | 1402 | ppg_400hz_frame_calibration_scheduler.v:174 | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_tick` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_macro_tick`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_startup_idac_safe_boundary（导入版本行号漂移） |
| 矩阵 | 1407 | ppg_400hz_frame_calibration_scheduler.v:190 | `ppg_400hz_frame_calibration_scheduler.v` `o_protocol_error_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_protocol_error_sticky`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_owner_deadline_timeout_sticky（导入版本行号漂移） |
| 矩阵 | 1407 | `:1540` | `ppg_control_top.v` `o_characterization_protocol_error_sticky` | 第二轮：“Top内部网`o_characterization_protocol_error_sticky`（:N）”，按格内网名 |
| 矩阵 | 1407 | `:234` | `ppg_control_top.v` `o_characterization_protocol_error_sticky` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_characterization_protocol_error_sticky`同名输出端口 |
| 矩阵 | 1407 | ppg_400hz_frame_calibration_scheduler.v:190 | `ppg_400hz_frame_calibration_scheduler.v` `o_protocol_error_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_protocol_error_sticky`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_owner_deadline_timeout_sticky（导入版本行号漂移） |
| 矩阵 | 1407 | `:1523` | `ppg_control_top.v` `o_scheduler_protocol_error_sticky` | 第二轮：“Top内部网`o_scheduler_protocol_error_sticky`（:N）”，按格内网名 |
| 矩阵 | 1407 | `:217` | `ppg_control_top.v` `o_scheduler_protocol_error_sticky` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_scheduler_protocol_error_sticky`同名输出端口 |
| 矩阵 | 1410 | `:408` | `ppg_control_top.v` `analog_run_enable` | 第二轮：“Top内部网`analog_run_enable`（:N）”，按格内网名 |
| 矩阵 | 1410 | `:409` | `ppg_control_top.v` `measurement_run_enable` | 第二轮：“Top内部网`measurement_run_enable`（:N）”，按格内网名 |
| 矩阵 | 1413 | ppg_400hz_frame_calibration_scheduler.v:173 | `ppg_400hz_frame_calibration_scheduler.v` `o_safe_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_safe_frame_id`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_idac_code_safe_boundary（导入版本行号漂移） |
| 矩阵 | 1413 | ppg_400hz_frame_calibration_scheduler.v:173 | `ppg_400hz_frame_calibration_scheduler.v` `o_safe_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_safe_frame_id`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_idac_code_safe_boundary（导入版本行号漂移） |
| 矩阵 | 1416 | `:1536` | `ppg_control_top.v` `o_source_characterization_update_ready` | 第二轮：“Top内部网`o_source_characterization_update_ready`（:N）”，按格内网名 |
| 矩阵 | 1416 | `:230` | `ppg_control_top.v` `o_source_characterization_update_ready` | 第二轮：“→Top边界输出:N”即紧前Top内部网`o_source_characterization_update_ready`同名输出端口 |
| 矩阵 | 1417 | ppg_control_top.v:200 | `ppg_control_top.v` `o_start_ack_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1417 | ppg_control_top.v:200 | `ppg_control_top.v` `o_start_ack_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1418 | `:409` | `ppg_control_top.v` `measurement_run_enable` | 第二轮：“Top内部网`measurement_run_enable`（:N）”，按格内网名 |
| 矩阵 | 1418 | `:410` | `ppg_control_top.v` `measurement_allow_new_transaction` | 第二轮：“Top内部网`measurement_allow_new_transaction`（:N）”，按格内网名 |
| 矩阵 | 1418 | `:412` | `ppg_control_top.v` `flag_measurement_start_ack_event` | 第二轮：“Top内部网`flag_measurement_start_ack_event`（:N）”，按格内网名 |
| 矩阵 | 1419 | ppg_control_top.v:201 | `ppg_control_top.v` `o_stop_ack_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1419 | ppg_control_top.v:201 | `ppg_control_top.v` `o_stop_ack_event` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1421 | ppg_adc_measurement_idac_integration.v:313 | `ppg_adc_measurement_idac_integration.v` `o_switch_hold_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_switch_hold_new_transaction`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_precision_15_to_9_event（导入版本行号漂移） |
| 矩阵 | 1421 | ppg_adc_measurement_idac_integration.v:313 | `ppg_adc_measurement_idac_integration.v` `o_switch_hold_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_switch_hold_new_transaction`在子模块中的声明，ppg_adc_measurement_idac_integration.v有同名端口，原解析为o_precision_15_to_9_event（导入版本行号漂移） |
| 矩阵 | 1424 | ppg_control_top.v:248 | `ppg_control_top.v` `o_system_fault_cause` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_cause`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_discard_event（导入版本行号漂移） |
| 矩阵 | 1424 | ppg_control_top.v:248 | `ppg_control_top.v` `o_system_fault_cause` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_cause`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_discard_event（导入版本行号漂移） |
| 矩阵 | 1428 | ppg_control_top.v:251 | `ppg_control_top.v` `o_system_fault_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_frame_id`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_source（导入版本行号漂移） |
| 矩阵 | 1428 | ppg_control_top.v:251 | `ppg_control_top.v` `o_system_fault_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_frame_id`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_source（导入版本行号漂移） |
| 矩阵 | 1429 | ppg_control_top.v:254 | `ppg_control_top.v` `o_system_fault_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_frame_type`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_sample_index（导入版本行号漂移） |
| 矩阵 | 1429 | ppg_control_top.v:254 | `ppg_control_top.v` `o_system_fault_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_frame_type`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_sample_index（导入版本行号漂移） |
| 矩阵 | 1432 | ppg_control_top.v:256 | `ppg_control_top.v` `o_system_fault_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_run_generation`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_frame_type（导入版本行号漂移） |
| 矩阵 | 1432 | ppg_control_top.v:256 | `ppg_control_top.v` `o_system_fault_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_run_generation`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_frame_type（导入版本行号漂移） |
| 矩阵 | 1433 | ppg_control_top.v:252 | `ppg_control_top.v` `o_system_fault_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_sample_index`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_identity_valid（导入版本行号漂移） |
| 矩阵 | 1433 | ppg_control_top.v:252 | `ppg_control_top.v` `o_system_fault_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_sample_index`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_identity_valid（导入版本行号漂移） |
| 矩阵 | 1434 | ppg_control_top.v:249 | `ppg_control_top.v` `o_system_fault_source` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_source`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_cause_valid（导入版本行号漂移） |
| 矩阵 | 1434 | ppg_control_top.v:249 | `ppg_control_top.v` `o_system_fault_source` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_source`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_cause_valid（导入版本行号漂移） |
| 矩阵 | 1435 | ppg_control_top.v:257 | `ppg_control_top.v` `o_system_fault_summary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_summary`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_precision（导入版本行号漂移） |
| 矩阵 | 1435 | ppg_control_top.v:257 | `ppg_control_top.v` `o_system_fault_summary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_system_fault_summary`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_system_fault_precision（导入版本行号漂移） |
| 矩阵 | 1439 | ppg_400hz_frame_calibration_scheduler.v:145 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_amb_code_epoch`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_amb_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1439 | ppg_400hz_frame_calibration_scheduler.v:145 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_amb_code_epoch`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_amb_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1440 | ppg_400hz_frame_calibration_scheduler.v:143 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_amb_code_snapshot`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_color_ir（导入版本行号漂移） |
| 矩阵 | 1440 | ppg_400hz_frame_calibration_scheduler.v:143 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_amb_code_snapshot`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_color_ir（导入版本行号漂移） |
| 矩阵 | 1441 | ppg_400hz_frame_calibration_scheduler.v:141 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_color_ir`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_frame_id（导入版本行号漂移） |
| 矩阵 | 1441 | ppg_400hz_frame_calibration_scheduler.v:141 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_color_ir`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_frame_id（导入版本行号漂移） |
| 矩阵 | 1442 | ppg_400hz_frame_calibration_scheduler.v:146 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_dc_code_epoch`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_dc_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1442 | ppg_400hz_frame_calibration_scheduler.v:146 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_dc_code_epoch`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_dc_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1443 | ppg_400hz_frame_calibration_scheduler.v:144 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_dc_code_snapshot`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_frame_type（导入版本行号漂移） |
| 矩阵 | 1443 | ppg_400hz_frame_calibration_scheduler.v:144 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_dc_code_snapshot`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_frame_type（导入版本行号漂移） |
| 矩阵 | 1444 | ppg_400hz_frame_calibration_scheduler.v:139 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_frame_id`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_transaction_start_fire（导入版本行号漂移） |
| 矩阵 | 1444 | ppg_400hz_frame_calibration_scheduler.v:139 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_frame_id`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_transaction_start_fire（导入版本行号漂移） |
| 矩阵 | 1445 | ppg_400hz_frame_calibration_scheduler.v:142 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_frame_type`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_sample_index（导入版本行号漂移） |
| 矩阵 | 1445 | ppg_400hz_frame_calibration_scheduler.v:142 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_frame_type`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_sample_index（导入版本行号漂移） |
| 矩阵 | 1446 | ppg_400hz_frame_calibration_scheduler.v:138 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_precision_mode`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_transaction_start_ready（导入版本行号漂移） |
| 矩阵 | 1446 | ppg_400hz_frame_calibration_scheduler.v:138 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_precision_mode`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为i_transaction_start_ready（导入版本行号漂移） |
| 矩阵 | 1447 | ppg_400hz_frame_calibration_scheduler.v:140 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_sample_index`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_precision_mode（导入版本行号漂移） |
| 矩阵 | 1447 | ppg_400hz_frame_calibration_scheduler.v:140 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_transaction_sample_index`在子模块中的声明，ppg_400hz_frame_calibration_scheduler.v有同名端口，原解析为o_transaction_precision_mode（导入版本行号漂移） |
| 矩阵 | 1453 | ppg_control_top.v:122 | `ppg_control_top.v` `i_analog_ready` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1453 | ppg_control_top.v:122 | `ppg_control_top.v` `i_analog_ready` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1453 | `:74-77` | `ppg_control_top.v` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“RTL头注释:74-77已自述该缺口”，Top文件头注释，文件级锚点 |
| 矩阵 | 1460 | ppg_control_top.v:205 | `ppg_control_top.v` `o_last_error_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_last_error_code`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_commit_ack_sticky（导入版本行号漂移） |
| 矩阵 | 1460 | ppg_control_top.v:205 | `ppg_control_top.v` `o_last_error_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_last_error_code`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_commit_ack_sticky（导入版本行号漂移） |
| 矩阵 | 1461 | ppg_control_top.v:206 | `ppg_control_top.v` `o_schema_version` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_schema_version`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_error_sticky（导入版本行号漂移） |
| 矩阵 | 1461 | ppg_control_top.v:206 | `ppg_control_top.v` `o_schema_version` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_schema_version`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_error_sticky（导入版本行号漂移） |
| 矩阵 | 1462 | ppg_control_top.v:207 | `ppg_control_top.v` `o_config_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_config_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_last_error_code（导入版本行号漂移） |
| 矩阵 | 1462 | ppg_control_top.v:207 | `ppg_control_top.v` `o_config_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_config_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_last_error_code（导入版本行号漂移） |
| 矩阵 | 1463 | ppg_control_top.v:208 | `ppg_control_top.v` `o_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_schema_version（导入版本行号漂移） |
| 矩阵 | 1463 | ppg_control_top.v:208 | `ppg_control_top.v` `o_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_schema_version（导入版本行号漂移） |
| 矩阵 | 1464 | ppg_control_top.v:209 | `ppg_control_top.v` `o_stage2_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_stage2_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_config_epoch（导入版本行号漂移） |
| 矩阵 | 1464 | ppg_control_top.v:209 | `ppg_control_top.v` `o_stage2_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_stage2_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_config_epoch（导入版本行号漂移） |
| 矩阵 | 1465 | ppg_control_top.v:210 | `ppg_control_top.v` `o_dc_recovery_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_dc_recovery_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_coef_epoch（导入版本行号漂移） |
| 矩阵 | 1465 | ppg_control_top.v:210 | `ppg_control_top.v` `o_dc_recovery_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_dc_recovery_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_coef_epoch（导入版本行号漂移） |
| 矩阵 | 1467 | ppg_control_top.v:108 | `ppg_control_top.v` `i_source_test_mux_ctrl` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1467 | ppg_control_top.v:108 | `ppg_control_top.v` `i_source_test_mux_ctrl` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1468 | ppg_control_top.v:134 | `ppg_control_top.v` `i_context_handover_stall_request` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1468 | ppg_control_top.v:134 | `ppg_control_top.v` `i_context_handover_stall_request` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1491 | ppg_control_top.v:159 | `ppg_control_top.v` `o_idac_sar9ambn_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_sar9ambn_low`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_en_sar15_dc_low（导入版本行号漂移） |
| 矩阵 | 1491 | ppg_control_top.v:159 | `ppg_control_top.v` `o_idac_sar9ambn_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_sar9ambn_low`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_en_sar15_dc_low（导入版本行号漂移） |
| 矩阵 | 1492 | ppg_control_top.v:160 | `ppg_control_top.v` `o_idac_sar9dcn_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_sar9dcn_low`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_en_sar15_iref（导入版本行号漂移） |
| 矩阵 | 1492 | ppg_control_top.v:160 | `ppg_control_top.v` `o_idac_sar9dcn_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_sar9dcn_low`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_en_sar15_iref（导入版本行号漂移） |
| 矩阵 | 1493 | ppg_control_top.v:161 | `ppg_control_top.v` `o_idac_sar15ambn_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_sar15ambn_low`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_idac_sar9ambn_low（导入版本行号漂移） |
| 矩阵 | 1493 | ppg_control_top.v:161 | `ppg_control_top.v` `o_idac_sar15ambn_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_sar15ambn_low`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_idac_sar9ambn_low（导入版本行号漂移） |
| 矩阵 | 1494 | ppg_control_top.v:162 | `ppg_control_top.v` `o_idac_sar15dcn_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_sar15dcn_low`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_idac_sar9dcn_low（导入版本行号漂移） |
| 矩阵 | 1494 | ppg_control_top.v:162 | `ppg_control_top.v` `o_idac_sar15dcn_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_idac_sar15dcn_low`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_idac_sar9dcn_low（导入版本行号漂移） |
| 矩阵 | 1495 | ppg_control_top.v:163 | `ppg_control_top.v` `o_s_in` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_s_in`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_idac_sar15ambn_low（导入版本行号漂移） |
| 矩阵 | 1495 | ppg_control_top.v:163 | `ppg_control_top.v` `o_s_in` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_s_in`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_idac_sar15ambn_low（导入版本行号漂移） |
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
| 矩阵 | 1520 | ppg_control_top.v:173 | `ppg_control_top.v` `o_fine_ppg_value` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_fine_ppg_value`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_coarse_saturation_low（导入版本行号漂移） |
| 矩阵 | 1520 | ppg_control_top.v:173 | `ppg_control_top.v` `o_fine_ppg_value` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_fine_ppg_value`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_coarse_saturation_low（导入版本行号漂移） |
| 矩阵 | 1525 | ppg_control_top.v:178 | `ppg_control_top.v` `o_calibrated_s1_value` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_calibrated_s1_value`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_fine_saturation_low（导入版本行号漂移） |
| 矩阵 | 1525 | ppg_control_top.v:178 | `ppg_control_top.v` `o_calibrated_s1_value` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_calibrated_s1_value`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_fine_saturation_low（导入版本行号漂移） |
| 矩阵 | 1526 | ppg_control_top.v:179 | `ppg_control_top.v` `o_programmable_15_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_programmable_15_code`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_fine_saturation_high（导入版本行号漂移） |
| 矩阵 | 1526 | ppg_control_top.v:179 | `ppg_control_top.v` `o_programmable_15_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_programmable_15_code`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_fine_saturation_high（导入版本行号漂移） |
| 矩阵 | 1528 | ppg_control_top.v:181 | `ppg_control_top.v` `o_result_config_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_config_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_programmable_15_code（导入版本行号漂移） |
| 矩阵 | 1528 | ppg_control_top.v:181 | `ppg_control_top.v` `o_result_config_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_config_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_programmable_15_code（导入版本行号漂移） |
| 矩阵 | 1529 | ppg_control_top.v:182 | `ppg_control_top.v` `o_result_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_programmable_15_valid（导入版本行号漂移） |
| 矩阵 | 1529 | ppg_control_top.v:182 | `ppg_control_top.v` `o_result_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_programmable_15_valid（导入版本行号漂移） |
| 矩阵 | 1530 | ppg_control_top.v:183 | `ppg_control_top.v` `o_result_stage2_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_stage2_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_config_epoch（导入版本行号漂移） |
| 矩阵 | 1530 | ppg_control_top.v:183 | `ppg_control_top.v` `o_result_stage2_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_stage2_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_config_epoch（导入版本行号漂移） |
| 矩阵 | 1531 | ppg_control_top.v:184 | `ppg_control_top.v` `o_result_dc_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_dc_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_coef_epoch（导入版本行号漂移） |
| 矩阵 | 1531 | ppg_control_top.v:184 | `ppg_control_top.v` `o_result_dc_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_dc_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_coef_epoch（导入版本行号漂移） |
| 矩阵 | 1533 | ppg_control_top.v:186 | `ppg_control_top.v` `o_result_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_frame_id`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_dc_coef_epoch（导入版本行号漂移） |
| 矩阵 | 1533 | ppg_control_top.v:186 | `ppg_control_top.v` `o_result_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_frame_id`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_dc_coef_epoch（导入版本行号漂移） |
| 矩阵 | 1534 | ppg_control_top.v:187 | `ppg_control_top.v` `o_result_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_sample_index`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_precision_mode（导入版本行号漂移） |
| 矩阵 | 1534 | ppg_control_top.v:187 | `ppg_control_top.v` `o_result_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_sample_index`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_precision_mode（导入版本行号漂移） |
| 矩阵 | 1536 | ppg_control_top.v:189 | `ppg_control_top.v` `o_result_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_frame_type`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_sample_index（导入版本行号漂移） |
| 矩阵 | 1536 | ppg_control_top.v:189 | `ppg_control_top.v` `o_result_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_frame_type`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_sample_index（导入版本行号漂移） |
| 矩阵 | 1537 | ppg_control_top.v:190 | `ppg_control_top.v` `o_result_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_amb_code_snapshot`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_color_ir（导入版本行号漂移） |
| 矩阵 | 1537 | ppg_control_top.v:190 | `ppg_control_top.v` `o_result_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_amb_code_snapshot`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_color_ir（导入版本行号漂移） |
| 矩阵 | 1538 | ppg_control_top.v:191 | `ppg_control_top.v` `o_result_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_dc_code_snapshot`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_frame_type（导入版本行号漂移） |
| 矩阵 | 1538 | ppg_control_top.v:191 | `ppg_control_top.v` `o_result_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_dc_code_snapshot`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_frame_type（导入版本行号漂移） |
| 矩阵 | 1539 | ppg_control_top.v:192 | `ppg_control_top.v` `o_result_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_amb_code_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_amb_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1539 | ppg_control_top.v:192 | `ppg_control_top.v` `o_result_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_amb_code_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_amb_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1540 | ppg_control_top.v:193 | `ppg_control_top.v` `o_result_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_dc_code_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_dc_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1540 | ppg_control_top.v:193 | `ppg_control_top.v` `o_result_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_result_dc_code_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_result_dc_code_snapshot（导入版本行号漂移） |
| 矩阵 | 1549 | ppg_control_top.v:265 | `ppg_control_top.v` `o_measurement_result_discard_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_measurement_result_discard_frame_id`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_measurement_result_discard_identity_valid（导入版本行号漂移） |
| 矩阵 | 1549 | ppg_control_top.v:265 | `ppg_control_top.v` `o_measurement_result_discard_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_measurement_result_discard_frame_id`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_measurement_result_discard_identity_valid（导入版本行号漂移） |
| 矩阵 | 1550 | ppg_control_top.v:266 | `ppg_control_top.v` `o_measurement_result_discard_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_measurement_result_discard_sample_index`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_measurement_result_discard_sample_valid（导入版本行号漂移） |
| 矩阵 | 1550 | ppg_control_top.v:266 | `ppg_control_top.v` `o_measurement_result_discard_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_measurement_result_discard_sample_index`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_measurement_result_discard_sample_valid（导入版本行号漂移） |
| 矩阵 | 1552 | ppg_control_top.v:268 | `ppg_control_top.v` `o_measurement_result_discard_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_measurement_result_discard_frame_type`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_measurement_result_discard_sample_index（导入版本行号漂移） |
| 矩阵 | 1552 | ppg_control_top.v:268 | `ppg_control_top.v` `o_measurement_result_discard_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_measurement_result_discard_frame_type`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_measurement_result_discard_sample_index（导入版本行号漂移） |
| 矩阵 | 1554 | ppg_control_top.v:270 | `ppg_control_top.v` `o_measurement_result_discard_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_measurement_result_discard_run_generation`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_measurement_result_discard_frame_type（导入版本行号漂移） |
| 矩阵 | 1554 | ppg_control_top.v:270 | `ppg_control_top.v` `o_measurement_result_discard_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_measurement_result_discard_run_generation`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_measurement_result_discard_frame_type（导入版本行号漂移） |
| 矩阵 | 1558 | ppg_control_top.v:277 | `ppg_control_top.v` `o_detection_discard_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_frame_id`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_identity_valid（导入版本行号漂移） |
| 矩阵 | 1558 | ppg_control_top.v:277 | `ppg_control_top.v` `o_detection_discard_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_frame_id`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_identity_valid（导入版本行号漂移） |
| 矩阵 | 1559 | ppg_control_top.v:278 | `ppg_control_top.v` `o_detection_discard_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_sample_index`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_sample_valid（导入版本行号漂移） |
| 矩阵 | 1559 | ppg_control_top.v:278 | `ppg_control_top.v` `o_detection_discard_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_sample_index`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_sample_valid（导入版本行号漂移） |
| 矩阵 | 1561 | ppg_control_top.v:280 | `ppg_control_top.v` `o_detection_discard_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_frame_type`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_sample_index（导入版本行号漂移） |
| 矩阵 | 1561 | ppg_control_top.v:280 | `ppg_control_top.v` `o_detection_discard_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_frame_type`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_sample_index（导入版本行号漂移） |
| 矩阵 | 1563 | ppg_control_top.v:282 | `ppg_control_top.v` `o_detection_discard_config_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_config_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_frame_type（导入版本行号漂移） |
| 矩阵 | 1563 | ppg_control_top.v:282 | `ppg_control_top.v` `o_detection_discard_config_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_config_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_frame_type（导入版本行号漂移） |
| 矩阵 | 1564 | ppg_control_top.v:283 | `ppg_control_top.v` `o_detection_discard_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_precision（导入版本行号漂移） |
| 矩阵 | 1564 | ppg_control_top.v:283 | `ppg_control_top.v` `o_detection_discard_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_coef_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_precision（导入版本行号漂移） |
| 矩阵 | 1565 | ppg_control_top.v:284 | `ppg_control_top.v` `o_detection_discard_dc_recovery_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_dc_recovery_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_config_epoch（导入版本行号漂移） |
| 矩阵 | 1565 | ppg_control_top.v:284 | `ppg_control_top.v` `o_detection_discard_dc_recovery_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_dc_recovery_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_config_epoch（导入版本行号漂移） |
| 矩阵 | 1566 | ppg_control_top.v:285 | `ppg_control_top.v` `o_detection_discard_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_amb_code_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_coef_epoch（导入版本行号漂移） |
| 矩阵 | 1566 | ppg_control_top.v:285 | `ppg_control_top.v` `o_detection_discard_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_amb_code_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_coef_epoch（导入版本行号漂移） |
| 矩阵 | 1567 | ppg_control_top.v:286 | `ppg_control_top.v` `o_detection_discard_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_dc_code_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_dc_recovery_epoch（导入版本行号漂移） |
| 矩阵 | 1567 | ppg_control_top.v:286 | `ppg_control_top.v` `o_detection_discard_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_dc_code_epoch`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_dc_recovery_epoch（导入版本行号漂移） |
| 矩阵 | 1568 | ppg_control_top.v:287 | `ppg_control_top.v` `o_detection_discard_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_run_generation`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_amb_code_epoch（导入版本行号漂移） |
| 矩阵 | 1568 | ppg_control_top.v:287 | `ppg_control_top.v` `o_detection_discard_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9 端口台账第5列为本行端口`o_detection_discard_run_generation`在子模块中的声明，ppg_control_top.v有同名端口，原解析为o_detection_discard_amb_code_epoch（导入版本行号漂移） |
| 矩阵 | 1571 | ppg_control_top.v:292 | `ppg_control_top.v` `o_s2_raw` | 第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1571 | ppg_control_top.v:292 | `ppg_control_top.v` `o_s2_raw` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；第二轮：G-FP-01台账“Top边界输入/输出（ppg_control_top.v:N）”指本行端口（第4列）；台账行号与写入时版本有偏移，按格内端口名 |
| 矩阵 | 1576 | ppg_control_top.v:109,724 | `ppg_control_top.v` `i_start_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_source_static_characterization_enable与本行无关；ppg_control_top.v有本行端口`i_start_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1579 | ppg_control_top.v:120,727 | `ppg_control_top.v` `i_analog_ready` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_clk_stage1_dout_low_async与本行无关；ppg_control_top.v有本行端口`i_analog_ready`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1585 | `:245` | `ppg_system_config_manager.v` `i_static_characterization_enable` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析dec_amb_threshold_low与本行无关；ppg_system_config_manager.v有本行端口`i_static_characterization_enable`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1590 | ppg_control_top.v:740 | `ppg_control_top.v` `o_stage2_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_analog_ready与本行无关；ppg_control_top.v有本行端口`o_stage2_coef_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1590 | ppg_control_top.v:1502 | `ppg_control_top.v` `o_stage2_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_result_dc_code_snapshot与本行无关；ppg_control_top.v有本行端口`o_stage2_coef_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1591 | ppg_control_top.v:741 | `ppg_control_top.v` `o_dc_recovery_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_idle与本行无关；ppg_control_top.v有本行端口`o_dc_recovery_coef_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1591 | ppg_control_top.v:1503 | `ppg_control_top.v` `o_dc_recovery_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_result_amb_code_epoch与本行无关；ppg_control_top.v有本行端口`o_dc_recovery_coef_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1593 | semantic_contract.md:297 | C02 §4 | C02语义合同简写；行号取写入时该合同所在小节 |
| 矩阵 | 1593 | `:88-100` | C02 §2.1 | 续接左侧semantic_contract.md（C02），正式I/O表 |
| 矩阵 | 1606 | ppg_control_top.v:120,727 | `ppg_control_top.v` `i_analog_ready` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_clk_stage1_dout_low_async与本行无关；ppg_control_top.v有本行端口`i_analog_ready`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1608 | ppg_control_top.v:722 | `ppg_control_top.v` `i_clk` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析sup_system_fault_summary_o与本行无关；ppg_control_top.v有本行端口`i_clk`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1611 | ppg_control_top.v:723 | `ppg_control_top.v` `i_rstn` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析sup_result_discard_summary_sticky_o与本行无关；ppg_control_top.v有本行端口`i_rstn`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1612 | ppg_control_top.v:718 | `ppg_control_top.v` `i_source_clk` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析sup_system_fault_frame_id_o与本行无关；ppg_control_top.v有本行端口`i_source_clk`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1613 | ppg_control_top.v:720 | `ppg_control_top.v` `i_source_config_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析sup_system_fault_frame_type_o与本行无关；ppg_control_top.v有本行端口`i_source_config_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1614 | ppg_control_top.v:721 | `ppg_control_top.v` `i_source_config_update_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析sup_system_fault_run_generation_o与本行无关；ppg_control_top.v有本行端口`i_source_config_update_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1615 | ppg_control_top.v:719 | `ppg_control_top.v` `i_source_rstn` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析sup_system_fault_sample_index_o与本行无关；ppg_control_top.v有本行端口`i_source_rstn`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1616 | ppg_control_top.v:109,724 | `ppg_control_top.v` `i_start_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_source_static_characterization_enable与本行无关；ppg_control_top.v有本行端口`i_start_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1617 | ppg_control_top.v:305,733 | `ppg_control_top.v` `i_static_characterization_enable` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_source_config_snapshot与本行无关；ppg_control_top.v有本行端口`i_static_characterization_enable`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1639 | ppg_control_top.v:742,1490 | `ppg_control_top.v` `o_lifecycle_state` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_datapath_empty、o_programmable_15_code与本行无关；ppg_control_top.v有本行端口`o_lifecycle_state`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1640 | semantic_contract.md:297 | C02 §4 | C02语义合同简写 |
| 矩阵 | 1640 | ppg_control_top.v:743,1491 | `ppg_control_top.v` `o_start_ready` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_idac_idle、o_programmable_15_valid与本行无关；ppg_control_top.v有本行端口`o_start_ready`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1643 | ppg_control_top.v:757 | `ppg_control_top.v` `o_input_source` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_run_enable与本行无关；ppg_control_top.v有本行端口`o_input_source`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1644 | ppg_control_top.v:758 | `ppg_control_top.v` `o_idac_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_allow_new_transaction与本行无关；ppg_control_top.v有本行端口`o_idac_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1645 | ppg_control_top.v:759 | `ppg_control_top.v` `o_optical_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_run_generation与本行无关；ppg_control_top.v有本行端口`o_optical_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1646 | ppg_control_top.v:760 | `ppg_control_top.v` `o_initial_precision` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stop_episode_active与本行无关；ppg_control_top.v有本行端口`o_initial_precision`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1647 | ppg_control_top.v:761 | `ppg_control_top.v` `o_amb_enable` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_commit_ack_event与本行无关；ppg_control_top.v有本行端口`o_amb_enable`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1648 | ppg_control_top.v:762 | `ppg_control_top.v` `o_dcs_enable` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_start_ack_event与本行无关；ppg_control_top.v有本行端口`o_dcs_enable`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1649 | ppg_control_top.v:763 | `ppg_control_top.v` `o_amb_polarity` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stop_ack_event与本行无关；ppg_control_top.v有本行端口`o_amb_polarity`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1650 | ppg_control_top.v:764 | `ppg_control_top.v` `o_dcs_polarity` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_error_event与本行无关；ppg_control_top.v有本行端口`o_dcs_polarity`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1651 | ppg_control_top.v:765 | `ppg_control_top.v` `o_stage1_calibration_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_commit_ack_sticky与本行无关；ppg_control_top.v有本行端口`o_stage1_calibration_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1652 | ppg_control_top.v:766 | `ppg_control_top.v` `o_stage2_calibration_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_error_sticky与本行无关；ppg_control_top.v有本行端口`o_stage2_calibration_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1653 | ppg_control_top.v:767 | `ppg_control_top.v` `o_dc9_recovery_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_last_error_code与本行无关；ppg_control_top.v有本行端口`o_dc9_recovery_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1654 | ppg_control_top.v:768 | `ppg_control_top.v` `o_dc15_recovery_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_schema_version与本行无关；ppg_control_top.v有本行端口`o_dc15_recovery_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1655 | ppg_control_top.v:769 | `ppg_control_top.v` `o_amb_manual_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_run_profile与本行无关；ppg_control_top.v有本行端口`o_amb_manual_code`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1656 | ppg_control_top.v:770 | `ppg_control_top.v` `o_amb_code_min` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_input_source与本行无关；ppg_control_top.v有本行端口`o_amb_code_min`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1657 | ppg_control_top.v:771 | `ppg_control_top.v` `o_amb_code_max` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_idac_mode与本行无关；ppg_control_top.v有本行端口`o_amb_code_max`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1658 | ppg_control_top.v:772 | `ppg_control_top.v` `o_dcs_r_manual_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_optical_mode与本行无关；ppg_control_top.v有本行端口`o_dcs_r_manual_code`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1659 | ppg_control_top.v:773 | `ppg_control_top.v` `o_dcs_r_code_min` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_initial_precision与本行无关；ppg_control_top.v有本行端口`o_dcs_r_code_min`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1660 | ppg_control_top.v:774 | `ppg_control_top.v` `o_dcs_r_code_max` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_amb_enable与本行无关；ppg_control_top.v有本行端口`o_dcs_r_code_max`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1661 | ppg_control_top.v:775 | `ppg_control_top.v` `o_dcs_ir_manual_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_enable与本行无关；ppg_control_top.v有本行端口`o_dcs_ir_manual_code`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1662 | ppg_control_top.v:776 | `ppg_control_top.v` `o_dcs_ir_code_min` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_amb_polarity与本行无关；ppg_control_top.v有本行端口`o_dcs_ir_code_min`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1663 | ppg_control_top.v:777 | `ppg_control_top.v` `o_dcs_ir_code_max` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_polarity与本行无关；ppg_control_top.v有本行端口`o_dcs_ir_code_max`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1664 | ppg_control_top.v:778 | `ppg_control_top.v` `o_amb_threshold_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_calibration_valid与本行无关；ppg_control_top.v有本行端口`o_amb_threshold_low`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1665 | ppg_control_top.v:779 | `ppg_control_top.v` `o_amb_threshold_high` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage2_calibration_valid与本行无关；ppg_control_top.v有本行端口`o_amb_threshold_high`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1666 | ppg_control_top.v:780 | `ppg_control_top.v` `o_dcs_threshold_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dc9_recovery_valid与本行无关；ppg_control_top.v有本行端口`o_dcs_threshold_low`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1667 | ppg_control_top.v:781 | `ppg_control_top.v` `o_dcs_threshold_high` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dc15_recovery_valid与本行无关；ppg_control_top.v有本行端口`o_dcs_threshold_high`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1670 | ppg_control_top.v:784 | `ppg_control_top.v` `o_stage1_weight_q16_0` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_amb_code_max与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_0`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1671 | ppg_control_top.v:785 | `ppg_control_top.v` `o_stage1_weight_q16_1` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_r_manual_code与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_1`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1672 | ppg_control_top.v:786 | `ppg_control_top.v` `o_stage1_weight_q16_2` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_r_code_min与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_2`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1673 | ppg_control_top.v:787 | `ppg_control_top.v` `o_stage1_weight_q16_3` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_r_code_max与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_3`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1674 | ppg_control_top.v:788 | `ppg_control_top.v` `o_stage1_weight_q16_4` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_ir_manual_code与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_4`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1675 | ppg_control_top.v:789 | `ppg_control_top.v` `o_stage1_weight_q16_5` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_ir_code_min与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_5`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1676 | ppg_control_top.v:790 | `ppg_control_top.v` `o_stage1_weight_q16_6` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_ir_code_max与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_6`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1677 | ppg_control_top.v:791 | `ppg_control_top.v` `o_stage1_weight_q16_7` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_amb_threshold_low与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_7`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1678 | ppg_control_top.v:792 | `ppg_control_top.v` `o_stage1_weight_q16_8` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_amb_threshold_high与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_8`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1679 | ppg_control_top.v:793 | `ppg_control_top.v` `o_stage1_weight_q16_9` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_threshold_low与本行无关；ppg_control_top.v有本行端口`o_stage1_weight_q16_9`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1680 | ppg_control_top.v:794 | `ppg_control_top.v` `o_stage1_offset_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_threshold_high与本行无关；ppg_control_top.v有本行端口`o_stage1_offset_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1681 | ppg_control_top.v:795 | `ppg_control_top.v` `o_stage2_gain_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_amb_confirm_count与本行无关；ppg_control_top.v有本行端口`o_stage2_gain_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1682 | ppg_control_top.v:796 | `ppg_control_top.v` `o_stage2_offset_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dcs_confirm_count与本行无关；ppg_control_top.v有本行端口`o_stage2_offset_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1683 | ppg_control_top.v:797 | `ppg_control_top.v` `o_dc9_recovery_gain_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_0与本行无关；ppg_control_top.v有本行端口`o_dc9_recovery_gain_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1684 | ppg_control_top.v:798 | `ppg_control_top.v` `o_dc15_recovery_gain_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_1与本行无关；ppg_control_top.v有本行端口`o_dc15_recovery_gain_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1685 | ppg_control_top.v:799 | `ppg_control_top.v` `o_amb_recheck_interval_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_2与本行无关；ppg_control_top.v有本行端口`o_amb_recheck_interval_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1686 | ppg_control_top.v:800 | `ppg_control_top.v` `o_slope_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_3与本行无关；ppg_control_top.v有本行端口`o_slope_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1687 | ppg_control_top.v:801 | `ppg_control_top.v` `o_fixed_slope_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_4与本行无关；ppg_control_top.v有本行端口`o_fixed_slope_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1688 | ppg_control_top.v:802 | `ppg_control_top.v` `o_alpha_q15` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_5与本行无关；ppg_control_top.v有本行端口`o_alpha_q15`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1689 | ppg_control_top.v:803 | `ppg_control_top.v` `o_beta_q15` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_6与本行无关；ppg_control_top.v有本行端口`o_beta_q15`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1690 | ppg_control_top.v:804 | `ppg_control_top.v` `o_timing_adjust_ratio_q15` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_7与本行无关；ppg_control_top.v有本行端口`o_timing_adjust_ratio_q15`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1691 | ppg_control_top.v:805 | `ppg_control_top.v` `o_slope_min_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_8与本行无关；ppg_control_top.v有本行端口`o_slope_min_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1692 | ppg_control_top.v:806 | `ppg_control_top.v` `o_slope_max_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_weight_q16_9与本行无关；ppg_control_top.v有本行端口`o_slope_max_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1693 | ppg_control_top.v:807 | `ppg_control_top.v` `o_baseline_delta_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage1_offset_q16与本行无关；ppg_control_top.v有本行端口`o_baseline_delta_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1694 | ppg_control_top.v:808 | `ppg_control_top.v` `o_cross_hysteresis_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage2_gain_q16与本行无关；ppg_control_top.v有本行端口`o_cross_hysteresis_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1695 | ppg_control_top.v:809 | `ppg_control_top.v` `o_lead_min_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_stage2_offset_q16与本行无关；ppg_control_top.v有本行端口`o_lead_min_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1696 | ppg_control_top.v:810 | `ppg_control_top.v` `o_lead_max_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_dc9_recovery_gain_q16与本行无关；ppg_control_top.v有本行端口`o_lead_max_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1698 | ppg_control_top.v:812 | `ppg_control_top.v` `o_no_cross_limit` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_amb_recheck_interval_frames与本行无关；ppg_control_top.v有本行端口`o_no_cross_limit`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1701 | ppg_control_top.v:815 | `ppg_control_top.v` `o_direction_deadband` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_alpha_q15与本行无关；ppg_control_top.v有本行端口`o_direction_deadband`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1702 | ppg_control_top.v:816 | `ppg_control_top.v` `o_min_peak_valley_amplitude` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_beta_q15与本行无关；ppg_control_top.v有本行端口`o_min_peak_valley_amplitude`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1703 | ppg_control_top.v:817 | `ppg_control_top.v` `o_min_peak_to_valley_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_timing_adjust_ratio_q15与本行无关；ppg_control_top.v有本行端口`o_min_peak_to_valley_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1704 | ppg_control_top.v:818 | `ppg_control_top.v` `o_min_peak_to_peak_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_slope_min_q16与本行无关；ppg_control_top.v有本行端口`o_min_peak_to_peak_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1705 | ppg_control_top.v:819 | `ppg_control_top.v` `o_max_fine_window_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_slope_max_q16与本行无关；ppg_control_top.v有本行端口`o_max_fine_window_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1706 | ppg_control_top.v:820 | `ppg_control_top.v` `o_max_reacquire_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_baseline_delta_q16与本行无关；ppg_control_top.v有本行端口`o_max_reacquire_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1712 | ppg_adc_measurement_idac_integration.v:2322 | `ppg_adc_measurement_idac_integration.v` `i_amb_code_min` | 第三轮（统筹10-10核对：格内写明的符号为准）：W8 格内写明`i_amb_code_min`，原解析为i_amb_code_max |
| 矩阵 | 1713 | ppg_adc_measurement_idac_integration.v:2334 | `ppg_adc_measurement_idac_integration.v` `i_amb_confirm_count` | 第三轮（统筹10-10核对：格内写明的符号为准）：W8 格内写明`i_amb_confirm_count`，原解析为i_amb_polarity |
| 矩阵 | 1714 | ppg_adc_measurement_idac_integration.v:2317 | `ppg_adc_measurement_idac_integration.v` `i_amb_enable` | 第三轮（统筹10-10核对：格内写明的符号为准）：W8 格内写明`i_amb_enable`，原解析为C_ENABLE_TEST_INJECTION |
| 矩阵 | 1715 | ppg_adc_measurement_idac_integration.v:2321 | `ppg_adc_measurement_idac_integration.v` `i_amb_manual_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W8 格内写明`i_amb_manual_code`，原解析为i_clk |
| 矩阵 | 1717 | ppg_adc_measurement_idac_integration.v:2331 | `ppg_adc_measurement_idac_integration.v` `i_amb_threshold_high` | 第三轮（统筹10-10核对：格内写明的符号为准）：W8 格内写明`i_amb_threshold_high`，原解析为i_idac_mode |
| 矩阵 | 1718 | ppg_adc_measurement_idac_integration.v:2330 | `ppg_adc_measurement_idac_integration.v` `i_amb_threshold_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W8 格内写明`i_amb_threshold_low`，原解析为i_active_config_epoch |
| 矩阵 | 1725 | ppg_active_v4_control_plane_integration.v:784 | `ppg_active_v4_control_plane_integration.v` `o_stage1_weight_q16_0` | “C03 wrapper (… area)”指C03的Stage1权重0导出端口；:784属Top，另条处理 |
| 矩阵 | 1803 | ppg_control_top.v:828 | `ppg_control_top.v` `i_source_clk` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_direction_deadband与本行无关；ppg_control_top.v有本行端口`i_source_clk`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1804 | ppg_control_top.v:829 | `ppg_control_top.v` `i_source_rstn` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_min_peak_valley_amplitude与本行无关；ppg_control_top.v有本行端口`i_source_rstn`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1805 | ppg_control_top.v:830 | `ppg_control_top.v` `i_clk` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_min_peak_to_valley_frames与本行无关；ppg_control_top.v有本行端口`i_clk`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1806 | ppg_control_top.v:831 | `ppg_control_top.v` `i_rstn` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_min_peak_to_peak_frames与本行无关；ppg_control_top.v有本行端口`i_rstn`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1808 | ppg_control_top.v:833 | `ppg_control_top.v` `i_source_static_characterization_enable` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_max_reacquire_frames与本行无关；ppg_control_top.v有本行端口`i_source_static_characterization_enable`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1809 | ppg_control_top.v:834 | `ppg_control_top.v` `i_source_test_mux_ctrl` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_peak_valley_config_valid与本行无关；ppg_control_top.v有本行端口`i_source_test_mux_ctrl`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1823 | ppg_400hz_frame_calibration_scheduler.v:84 | `ppg_400hz_frame_calibration_scheduler.v` `i_allow_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_active_config_valid与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_allow_new_transaction`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1824 | ppg_400hz_frame_calibration_scheduler.v:85 | `ppg_400hz_frame_calibration_scheduler.v` `i_start_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_run_enable与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_start_ack_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1825 | ppg_400hz_frame_calibration_scheduler.v:86 | `ppg_400hz_frame_calibration_scheduler.v` `i_stop_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_allow_new_transaction与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_stop_ack_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1826 | ppg_400hz_frame_calibration_scheduler.v:87 | `ppg_400hz_frame_calibration_scheduler.v` `i_control_abort_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_start_ack_event与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_control_abort_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1827 | ppg_400hz_frame_calibration_scheduler.v:88 | `ppg_400hz_frame_calibration_scheduler.v` `i_diag_clear_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_stop_ack_event与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_diag_clear_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1828 | ppg_400hz_frame_calibration_scheduler.v:89 | `ppg_400hz_frame_calibration_scheduler.v` `i_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_control_abort_event与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_run_generation`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1831 | ppg_400hz_frame_calibration_scheduler.v:94 | `ppg_400hz_frame_calibration_scheduler.v` `i_optical_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_run_profile与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_optical_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1832 | ppg_400hz_frame_calibration_scheduler.v:95 | `ppg_400hz_frame_calibration_scheduler.v` `i_active_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_input_source与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_active_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1833 | ppg_400hz_frame_calibration_scheduler.v:96 | `ppg_400hz_frame_calibration_scheduler.v` `i_normal_measurement_eligible` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_optical_mode与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_normal_measurement_eligible`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1834 | ppg_400hz_frame_calibration_scheduler.v:97 | `ppg_400hz_frame_calibration_scheduler.v` `i_switch_hold_new_transaction` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_active_precision_mode与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_switch_hold_new_transaction`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1835 | ppg_400hz_frame_calibration_scheduler.v:98 | `ppg_400hz_frame_calibration_scheduler.v` `i_ami_fault_blocking` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_normal_measurement_eligible与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_ami_fault_blocking`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1836 | ppg_400hz_frame_calibration_scheduler.v:99 | `ppg_400hz_frame_calibration_scheduler.v` `i_ssw_fault_blocking` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_switch_hold_new_transaction与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_ssw_fault_blocking`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1837 | ppg_400hz_frame_calibration_scheduler.v:100 | `ppg_400hz_frame_calibration_scheduler.v` `i_amb_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_ami_fault_blocking与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_amb_code`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1838 | ppg_400hz_frame_calibration_scheduler.v:101 | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_r_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_ssw_fault_blocking与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_dcs_r_code`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1839 | ppg_400hz_frame_calibration_scheduler.v:102 | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_ir_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_amb_code与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_dcs_ir_code`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1840 | ppg_400hz_frame_calibration_scheduler.v:103 | `ppg_400hz_frame_calibration_scheduler.v` `i_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dcs_r_code与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_amb_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1841 | ppg_400hz_frame_calibration_scheduler.v:104 | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_r_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dcs_ir_code与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_dcs_r_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1842 | ppg_400hz_frame_calibration_scheduler.v:105 | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_ir_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_amb_code_epoch与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_dcs_ir_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1843 | ppg_400hz_frame_calibration_scheduler.v:106 | `ppg_400hz_frame_calibration_scheduler.v` `i_leddac_r_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dcs_r_code_epoch与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_leddac_r_code`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1844 | ppg_400hz_frame_calibration_scheduler.v:107 | `ppg_400hz_frame_calibration_scheduler.v` `i_leddac_ir_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dcs_ir_code_epoch与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_leddac_ir_code`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1847 | ppg_400hz_frame_calibration_scheduler.v:112 | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_calibration_sample_valid与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_calibration_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1848 | ppg_400hz_frame_calibration_scheduler.v:113 | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_calibration_sample_ready与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_calibration_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1849 | ppg_400hz_frame_calibration_scheduler.v:114 | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_calibration_frame_type与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_calibration_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1850 | ppg_400hz_frame_calibration_scheduler.v:115 | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_request_reason` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_calibration_color_ir与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_calibration_request_reason`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1853 | ppg_400hz_frame_calibration_scheduler.v:120 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_context_valid与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1854 | ppg_400hz_frame_calibration_scheduler.v:121 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_context_ready与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1855 | ppg_400hz_frame_calibration_scheduler.v:122 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_precision_mode与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1856 | ppg_400hz_frame_calibration_scheduler.v:123 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_frame_id与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1857 | ppg_400hz_frame_calibration_scheduler.v:124 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_color_ir与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_amb_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1858 | ppg_400hz_frame_calibration_scheduler.v:125 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_frame_type与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_dc_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1859 | ppg_400hz_frame_calibration_scheduler.v:126 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_amb_code_snapshot与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_amb_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1860 | ppg_400hz_frame_calibration_scheduler.v:127 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_dc_code_snapshot与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_dc_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1861 | ppg_400hz_frame_calibration_scheduler.v:128 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_input_source` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_amb_code_epoch与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_input_source`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1862 | ppg_400hz_frame_calibration_scheduler.v:129 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_optical_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_dc_code_epoch与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_optical_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1863 | ppg_400hz_frame_calibration_scheduler.v:130 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_leddac_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_input_source与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_waveform_leddac_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1866 | ppg_400hz_frame_calibration_scheduler.v:137 | `ppg_400hz_frame_calibration_scheduler.v` `i_transaction_start_fire` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_start_valid与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_transaction_start_fire`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1867 | ppg_400hz_frame_calibration_scheduler.v:138 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_transaction_start_ready与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1867 | ppg_control_top.v:905 | `ppg_control_top.v` `o_transaction_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_frame_id与本行无关；ppg_control_top.v有本行端口`o_transaction_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1868 | ppg_400hz_frame_calibration_scheduler.v:139 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_transaction_start_fire与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1868 | ppg_control_top.v:906 | `ppg_control_top.v` `o_transaction_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_color_ir与本行无关；ppg_control_top.v有本行端口`o_transaction_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1869 | ppg_400hz_frame_calibration_scheduler.v:140 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_precision_mode与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1869 | ppg_control_top.v:907 | `ppg_control_top.v` `o_transaction_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_frame_type与本行无关；ppg_control_top.v有本行端口`o_transaction_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1870 | ppg_400hz_frame_calibration_scheduler.v:141 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_frame_id与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1870 | ppg_control_top.v:908 | `ppg_control_top.v` `o_transaction_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_amb_code_snapshot与本行无关；ppg_control_top.v有本行端口`o_transaction_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1871 | ppg_400hz_frame_calibration_scheduler.v:142 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_sample_index与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1871 | ppg_control_top.v:909 | `ppg_control_top.v` `o_transaction_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_dc_code_snapshot与本行无关；ppg_control_top.v有本行端口`o_transaction_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1872 | ppg_400hz_frame_calibration_scheduler.v:143 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_color_ir与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_amb_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1872 | ppg_control_top.v:910 | `ppg_control_top.v` `o_transaction_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_amb_code_epoch与本行无关；ppg_control_top.v有本行端口`o_transaction_amb_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1873 | ppg_400hz_frame_calibration_scheduler.v:144 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_frame_type与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_dc_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1873 | ppg_control_top.v:911 | `ppg_control_top.v` `o_transaction_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_dc_code_epoch与本行无关；ppg_control_top.v有本行端口`o_transaction_dc_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1874 | ppg_400hz_frame_calibration_scheduler.v:145 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_amb_code_snapshot与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_amb_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1874 | ppg_control_top.v:912 | `ppg_control_top.v` `o_transaction_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_input_source与本行无关；ppg_control_top.v有本行端口`o_transaction_amb_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1875 | ppg_400hz_frame_calibration_scheduler.v:146 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_dc_code_snapshot与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_dc_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1875 | ppg_control_top.v:913 | `ppg_control_top.v` `o_transaction_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_optical_mode与本行无关；ppg_control_top.v有本行端口`o_transaction_dc_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1878 | ppg_400hz_frame_calibration_scheduler.v:151 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_ready与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1879 | ppg_400hz_frame_calibration_scheduler.v:152 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_commit_event与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1880 | ppg_400hz_frame_calibration_scheduler.v:153 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_precision_mode与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1881 | ppg_400hz_frame_calibration_scheduler.v:154 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_frame_id与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1882 | ppg_400hz_frame_calibration_scheduler.v:155 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_color_ir与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_amb_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1883 | ppg_400hz_frame_calibration_scheduler.v:156 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_frame_type与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_dc_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1884 | ppg_400hz_frame_calibration_scheduler.v:157 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_amb_code_snapshot与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_amb_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1885 | ppg_400hz_frame_calibration_scheduler.v:158 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_dc_code_snapshot与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_dc_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1886 | ppg_400hz_frame_calibration_scheduler.v:159 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_amb_code_epoch与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_adc_owner_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1887 | ppg_400hz_frame_calibration_scheduler.v:160 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_transaction_complete_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_dc_code_epoch与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_adc_transaction_complete_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1888 | ppg_400hz_frame_calibration_scheduler.v:161 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_transaction_success` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_sample_index与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_adc_transaction_success`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1889 | ppg_400hz_frame_calibration_scheduler.v:162 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_complete_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_transaction_complete_event与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_adc_complete_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1890 | ppg_400hz_frame_calibration_scheduler.v:163 | `ppg_400hz_frame_calibration_scheduler.v` `i_owner_q3_window_closed` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_transaction_success与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_owner_q3_window_closed`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1891 | ppg_400hz_frame_calibration_scheduler.v:164 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_complete_sample_index与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_adc_idle`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1892 | ppg_400hz_frame_calibration_scheduler.v:165 | `ppg_400hz_frame_calibration_scheduler.v` `i_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_owner_q3_window_closed与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_analog_safe`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1893 | ppg_400hz_frame_calibration_scheduler.v:166 | `ppg_400hz_frame_calibration_scheduler.v` `i_sar_timing_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_idle与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`i_sar_timing_idle`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1894 | ppg_control_top.v:932 | `ppg_control_top.v` `o_macro_frame_start_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_macro_frame_start_event`，原解析为o_adc_owner_frame_type |
| 矩阵 | 1896 | ppg_400hz_frame_calibration_scheduler.v:171 | `ppg_400hz_frame_calibration_scheduler.v` `o_idac_code_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_macro_frame_start_event与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_idac_code_safe_boundary`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1897 | ppg_control_top.v:935 | `ppg_control_top.v` `o_startup_idac_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_startup_idac_safe_boundary`，原解析为o_macro_frame_start_event |
| 矩阵 | 1898 | ppg_400hz_frame_calibration_scheduler.v:173 | `ppg_400hz_frame_calibration_scheduler.v` `o_safe_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_idac_code_safe_boundary与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_safe_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1899 | ppg_400hz_frame_calibration_scheduler.v:174 | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_tick` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_startup_idac_safe_boundary与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_macro_tick`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1900 | ppg_400hz_frame_calibration_scheduler.v:175 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_subframe_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_safe_frame_id与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_calibration_subframe_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1901 | ppg_400hz_frame_calibration_scheduler.v:176 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_local_tick` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_macro_tick与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_calibration_local_tick`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1902 | ppg_400hz_frame_calibration_scheduler.v:177 | `ppg_400hz_frame_calibration_scheduler.v` `o_normal_frame_complete_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_calibration_subframe_index与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_normal_frame_complete_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1903 | ppg_400hz_frame_calibration_scheduler.v:178 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_frame_complete_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_calibration_local_tick与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_calibration_frame_complete_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1906 | ppg_400hz_frame_calibration_scheduler.v:183 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_frame_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_idle与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_calibration_frame_active`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1907 | ppg_400hz_frame_calibration_scheduler.v:184 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_inflight` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_normal_frame_active与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_transaction_inflight`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1907 | ppg_control_top.v:945 | `ppg_control_top.v` `o_transaction_inflight` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_transaction_inflight`，原解析为o_macro_frame_start_event |
| 矩阵 | 1908 | ppg_400hz_frame_calibration_scheduler.v:185 | `ppg_400hz_frame_calibration_scheduler.v` `o_current_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_calibration_frame_active与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_current_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1908 | ppg_control_top.v:946 | `ppg_control_top.v` `o_current_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_current_frame_id`，原解析为o_macro_frame_safe_boundary |
| 矩阵 | 1909 | ppg_400hz_frame_calibration_scheduler.v:186 | `ppg_400hz_frame_calibration_scheduler.v` `o_next_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_inflight与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_next_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1909 | ppg_control_top.v:947 | `ppg_control_top.v` `o_next_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_next_sample_index`，原解析为o_idac_code_safe_boundary |
| 矩阵 | 1910 | ppg_400hz_frame_calibration_scheduler.v:187 | `ppg_400hz_frame_calibration_scheduler.v` `o_launch_timeout_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_current_frame_id与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_launch_timeout_sticky`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1911 | ppg_400hz_frame_calibration_scheduler.v:188 | `ppg_400hz_frame_calibration_scheduler.v` `o_owner_deadline_timeout_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_next_sample_index与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_owner_deadline_timeout_sticky`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1912 | ppg_400hz_frame_calibration_scheduler.v:189 | `ppg_400hz_frame_calibration_scheduler.v` `o_completion_mismatch_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_launch_timeout_sticky与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_completion_mismatch_sticky`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1913 | ppg_400hz_frame_calibration_scheduler.v:190 | `ppg_400hz_frame_calibration_scheduler.v` `o_protocol_error_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_owner_deadline_timeout_sticky与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_protocol_error_sticky`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1914 | ppg_control_top.v:952 | `ppg_control_top.v` `o_scheduler_local_fault_blocking` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_scheduler_local_fault_blocking`，原解析为o_scheduler_fault_active |
| 矩阵 | 1915 | ppg_400hz_frame_calibration_scheduler.v:194 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_local_fault_blocking与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_scheduler_fault_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1916 | ppg_control_top.v:954 | `ppg_control_top.v` `o_scheduler_fault_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_calibration_frame_complete_event与本行无关；ppg_control_top.v有本行端口`o_scheduler_fault_active`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1917 | ppg_control_top.v:955 | `ppg_control_top.v` `o_scheduler_fault_cause` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_idle与本行无关；ppg_control_top.v有本行端口`o_scheduler_fault_cause`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1918 | ppg_400hz_frame_calibration_scheduler.v:197 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_identity_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_fault_valid与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_scheduler_fault_identity_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1918 | ppg_control_top.v:956 | `ppg_control_top.v` `o_scheduler_fault_identity_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_normal_frame_active与本行无关；ppg_control_top.v有本行端口`o_scheduler_fault_identity_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1919 | ppg_400hz_frame_calibration_scheduler.v:198 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_fault_active与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_scheduler_fault_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1919 | ppg_control_top.v:957 | `ppg_control_top.v` `o_scheduler_fault_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_calibration_frame_active与本行无关；ppg_control_top.v有本行端口`o_scheduler_fault_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1920 | ppg_400hz_frame_calibration_scheduler.v:199 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_fault_cause与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_scheduler_fault_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1920 | ppg_control_top.v:958 | `ppg_control_top.v` `o_scheduler_fault_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_inflight与本行无关；ppg_control_top.v有本行端口`o_scheduler_fault_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1921 | ppg_400hz_frame_calibration_scheduler.v:200 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_fault_identity_valid与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_scheduler_fault_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1921 | ppg_control_top.v:959 | `ppg_control_top.v` `o_scheduler_fault_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_current_frame_id与本行无关；ppg_control_top.v有本行端口`o_scheduler_fault_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1922 | ppg_400hz_frame_calibration_scheduler.v:201 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_fault_frame_id与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_scheduler_fault_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1922 | ppg_control_top.v:960 | `ppg_control_top.v` `o_scheduler_fault_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_next_sample_index与本行无关；ppg_control_top.v有本行端口`o_scheduler_fault_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1923 | ppg_400hz_frame_calibration_scheduler.v:202 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_scheduler_fault_sample_index与本行无关；ppg_400hz_frame_calibration_scheduler.v有本行端口`o_scheduler_fault_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1923 | ppg_control_top.v:961 | `ppg_control_top.v` `o_scheduler_fault_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_launch_timeout_sticky与本行无关；ppg_control_top.v有本行端口`o_scheduler_fault_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1927 | ppg_sar9_sar15_safe_selection_wrapper.v:67 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_run_enable` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_clk与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_run_enable`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1928 | ppg_sar9_sar15_safe_selection_wrapper.v:68 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_start_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_rstn与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_start_ack_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1929 | ppg_sar9_sar15_safe_selection_wrapper.v:69 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_stop_ack_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_run_enable与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_stop_ack_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1930 | ppg_sar9_sar15_safe_selection_wrapper.v:70 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_control_abort_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_start_ack_event与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_control_abort_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1931 | ppg_sar9_sar15_safe_selection_wrapper.v:71 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_diag_clear_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_stop_ack_event与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_diag_clear_event`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1932 | ppg_sar9_sar15_safe_selection_wrapper.v:72 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_run_generation` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_control_abort_event与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_run_generation`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1935 | ppg_sar9_sar15_safe_selection_wrapper.v:77 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_calibration_local_tick` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_macro_tick与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_calibration_local_tick`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1936 | ppg_sar9_sar15_safe_selection_wrapper.v:78 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_normal_frame_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_calibration_subframe_index与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_normal_frame_active`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1937 | ppg_sar9_sar15_safe_selection_wrapper.v:79 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_calibration_frame_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_calibration_local_tick与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_calibration_frame_active`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1938 | ppg_sar9_sar15_safe_selection_wrapper.v:80 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_macro_frame_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_normal_frame_active与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_macro_frame_safe_boundary`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1939 | ppg_sar9_sar15_safe_selection_wrapper.v:81 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_idac_code_safe_boundary` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_calibration_frame_active与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_idac_code_safe_boundary`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1942 | ppg_sar9_sar15_safe_selection_wrapper.v:86 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_optical_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_run_profile与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_optical_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1943 | ppg_sar9_sar15_safe_selection_wrapper.v:87 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_precision_mode_committed` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_input_source与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_precision_mode_committed`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1944 | ppg_sar9_sar15_safe_selection_wrapper.v:88 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_static_characterization_enable` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_optical_mode与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_static_characterization_enable`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1945 | ppg_sar9_sar15_safe_selection_wrapper.v:89 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_test_mux_ctrl` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_precision_mode_committed与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_test_mux_ctrl`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1950 | ppg_sar9_sar15_safe_selection_wrapper.v:98 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_context_valid与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1951 | ppg_sar9_sar15_safe_selection_wrapper.v:99 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_waveform_context_ready与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1952 | ppg_sar9_sar15_safe_selection_wrapper.v:100 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_precision_mode与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1953 | ppg_sar9_sar15_safe_selection_wrapper.v:101 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_frame_id与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1954 | ppg_sar9_sar15_safe_selection_wrapper.v:102 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_color_ir与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_amb_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1955 | ppg_sar9_sar15_safe_selection_wrapper.v:103 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_frame_type与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_dc_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1956 | ppg_sar9_sar15_safe_selection_wrapper.v:104 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_amb_code_snapshot与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_amb_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1957 | ppg_sar9_sar15_safe_selection_wrapper.v:105 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_dc_code_snapshot与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_dc_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1958 | ppg_sar9_sar15_safe_selection_wrapper.v:106 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_input_source` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_amb_code_epoch与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_input_source`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1959 | ppg_sar9_sar15_safe_selection_wrapper.v:107 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_optical_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_dc_code_epoch与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_optical_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1960 | ppg_sar9_sar15_safe_selection_wrapper.v:108 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_waveform_leddac_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_waveform_input_source与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_waveform_leddac_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1963 | ppg_sar9_sar15_safe_selection_wrapper.v:113 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_ready与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1964 | ppg_sar9_sar15_safe_selection_wrapper.v:114 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_commit_event与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1965 | ppg_sar9_sar15_safe_selection_wrapper.v:115 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_precision_mode与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1966 | ppg_sar9_sar15_safe_selection_wrapper.v:116 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_frame_id与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1967 | ppg_sar9_sar15_safe_selection_wrapper.v:117 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_color_ir与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_amb_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1968 | ppg_sar9_sar15_safe_selection_wrapper.v:118 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_frame_type与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_dc_code_snapshot`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1969 | ppg_sar9_sar15_safe_selection_wrapper.v:119 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_amb_code_snapshot与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_amb_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1970 | ppg_sar9_sar15_safe_selection_wrapper.v:120 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_dc_code_snapshot与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_dc_code_epoch`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1971 | ppg_sar9_sar15_safe_selection_wrapper.v:121 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_owner_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_owner_amb_code_epoch与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_owner_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1974 | ppg_sar9_sar15_safe_selection_wrapper.v:126 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_complete_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_transaction_complete_event与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_complete_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 1975 | ppg_sar9_sar15_safe_selection_wrapper.v:127 | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_adc_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_transaction_success与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`i_adc_idle`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2006 | ppg_sar9_sar15_safe_selection_wrapper.v:162 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_wrapper_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_analog_safe与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_wrapper_idle`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2007 | ppg_sar9_sar15_safe_selection_wrapper.v:163 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_precision_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_sar_timing_idle与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_precision_active`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2010 | ppg_sar9_sar15_safe_selection_wrapper.v:166 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_owner_q3_window_closed` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_calibration_wave_active与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_owner_q3_window_closed`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2011 | ppg_sar9_sar15_safe_selection_wrapper.v:167 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_switch_protocol_error_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_inflight与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_switch_protocol_error_sticky`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2012 | ppg_sar9_sar15_safe_selection_wrapper.v:168 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_transaction_mismatch_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_owner_q3_window_closed与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_transaction_mismatch_sticky`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2013 | ppg_sar9_sar15_safe_selection_wrapper.v:169 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_owner_deadline_timeout_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_switch_protocol_error_sticky与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_owner_deadline_timeout_sticky`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2014 | ppg_sar9_sar15_safe_selection_wrapper.v:170 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_calibration_timeout_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_transaction_mismatch_sticky与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_calibration_timeout_sticky`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2015 | ppg_sar9_sar15_safe_selection_wrapper.v:171 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_wrapper_fault_blocking` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_owner_deadline_timeout_sticky与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_wrapper_fault_blocking`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2016 | ppg_control_top.v:1068 | `ppg_control_top.v` `o_ssw_fault_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_s_in与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2017 | ppg_control_top.v:1069 | `ppg_control_top.v` `o_ssw_fault_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_clk_2m与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_active`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2018 | ppg_sar9_sar15_safe_selection_wrapper.v:176 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_ssw_fault_cause` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_ssw_fault_valid与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_ssw_fault_cause`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2018 | ppg_control_top.v:1070 | `ppg_control_top.v` `o_ssw_fault_cause` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_analog_safe与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_cause`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2019 | ppg_sar9_sar15_safe_selection_wrapper.v:177 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_ssw_fault_identity_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_ssw_fault_active与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_ssw_fault_identity_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2019 | ppg_control_top.v:1071 | `ppg_control_top.v` `o_ssw_fault_identity_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_sar_timing_idle与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_identity_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2020 | ppg_sar9_sar15_safe_selection_wrapper.v:178 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_ssw_fault_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_ssw_fault_cause与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_ssw_fault_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2020 | ppg_control_top.v:1072 | `ppg_control_top.v` `o_ssw_fault_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_wrapper_idle与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2021 | ppg_sar9_sar15_safe_selection_wrapper.v:179 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_ssw_fault_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_ssw_fault_identity_valid与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_ssw_fault_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2021 | ppg_control_top.v:1073 | `ppg_control_top.v` `o_ssw_fault_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_precision_active与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_sample_index`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2022 | ppg_sar9_sar15_safe_selection_wrapper.v:180 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_ssw_fault_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_ssw_fault_frame_id与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_ssw_fault_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2022 | ppg_control_top.v:1074 | `ppg_control_top.v` `o_ssw_fault_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_calibration_wave_active与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_color_ir`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2023 | ppg_sar9_sar15_safe_selection_wrapper.v:181 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_ssw_fault_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_ssw_fault_sample_index与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_ssw_fault_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2023 | ppg_control_top.v:1075 | `ppg_control_top.v` `o_ssw_fault_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_adc_owner_inflight与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_frame_type`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2024 | ppg_sar9_sar15_safe_selection_wrapper.v:182 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_ssw_fault_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_ssw_fault_color_ir与本行无关；ppg_sar9_sar15_safe_selection_wrapper.v有本行端口`o_ssw_fault_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2024 | ppg_control_top.v:1076 | `ppg_control_top.v` `o_ssw_fault_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_owner_q3_window_closed与本行无关；ppg_control_top.v有本行端口`o_ssw_fault_precision_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2195 | `:203-224` | `ppg_amb_recheck_scheduler.v` `o_scheduler_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_amb_sequence_start、o_dcs_revalidate_accept、o_calibration_sample_valid、o_calibration_frame_type与本行无关；ppg_amb_recheck_scheduler.v有本行端口`o_scheduler_idle`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2220 | `:1006` | `ppg_adc_measurement_idac_integration.v` `o_calibration_sample_valid` | 左侧引文即AMI的assign o_calibration_sample_valid |
| 矩阵 | 2221 | `:1007` | `ppg_adc_measurement_idac_integration.v` `o_calibration_frame_type` | 本行端口为AMI输出o_calibration_frame_type，锚点为其assign |
| 矩阵 | 2224 | `:1010` | `ppg_adc_measurement_idac_integration.v` `o_calibration_request_reason` | 本行端口为AMI输出o_calibration_request_reason，锚点为其assign |
| 矩阵 | 2255 | `:1074` | `ppg_adc_measurement_idac_integration.v` `o_idac_fault_blocking` | 左侧引文即AMI的assign o_idac_fault_blocking |
| 矩阵 | 2257 | `:2426,1076` | `ppg_adc_measurement_idac_integration.v` `startup_search_complete_o` | C17输出经AMI内部线startup_search_complete_o（右侧括注） |
| 矩阵 | 2258 | `:2427,1077` | `ppg_adc_measurement_idac_integration.v` `idac_idle_o` | C17输出经AMI内部线idac_idle_o（右侧括注） |
| 矩阵 | 2260 | `:2570,1090` | `ppg_adc_measurement_idac_integration.v` `o_amb_recheck_pending` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_fine_window_start_frame_id、o_idac_protocol_error_sticky与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`o_amb_recheck_pending`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2261 | `:2571,1091` | `ppg_adc_measurement_idac_integration.v` `o_amb_recheck_accept` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_precision_15_to_9_event、o_startup_search_complete与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`o_amb_recheck_accept`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2262 | `:2572,1092` | `ppg_adc_measurement_idac_integration.v` `o_amb_recheck_busy` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_precision_15_to_9_frame_id、o_idac_idle与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`o_amb_recheck_busy`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2263 | `:2573,1093` | `ppg_adc_measurement_idac_integration.v` `o_normal_output_inhibit` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_reacquire_request_event与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`o_normal_output_inhibit`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2272 | `:959,716` | `ppg_precision_window_controller.v` `reacquire_request_event_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内“cluster ⑤'s ppg_precision_window_controller (reacquire_request_event_o, …)”，生产方为PWC |
| 矩阵 | 2273 | `:219,717` | `ppg_precision_window_integration.v` `amb_recheck_accept_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内写明amb_recheck_accept_o；该名只存在于PWI（重检调度器o_amb_recheck_accept接出的网） |
| 矩阵 | 2313 | `:872,740` | `ppg_dynamic_baseline_cross_detector.v` `dec_peak_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_peak_frame_id`，原解析为i_peak_frame_id |
| 矩阵 | 2317 | `:876,744` | `ppg_precision_window_integration.v` `dec_peak_dc_recovery_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_peak_dc_recovery_coef_epoch`，原解析文件ppg_dynamic_baseline_cross_detector.v无此名，按声明所在文件 |
| 矩阵 | 2318 | `:877,745` | `ppg_precision_window_integration.v` `valley_pending_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内写明valley_pending_o；该名只存在于PWI |
| 矩阵 | 2325 | `:884,752` | `ppg_precision_window_integration.v` `dec_valley_dc_recovery_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_valley_dc_recovery_coef_epoch`，原解析文件ppg_dynamic_baseline_cross_detector.v无此名，按声明所在文件 |
| 矩阵 | 2367 | `:219,831` | `ppg_precision_window_integration.v` `amb_recheck_accept_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：同上 |
| 矩阵 | 2416 | `:956,863` | `ppg_precision_window_controller.v` `fine_window_start_frame_id_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内“ppg_precision_window_controller (fine_window_start_frame_id_o, …)” |
| 矩阵 | 2417 | `:953,864` | `ppg_precision_window_controller.v` `active_precision_mode_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内“ppg_precision_window_controller (active_precision_mode_o, …)” |
| 矩阵 | 2419 | `:945,866` | `ppg_precision_window_integration.v` `flag_return_9bit_ready` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_return_9bit_ready`，原解析文件ppg_peak_valley_window_detector.v无此名，按声明所在文件 |
| 矩阵 | 2444 | `:244` | `ppg_adc_measurement_idac_integration.v` `i_slope_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dc15_recovery_gain_q16与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_slope_mode`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2447 | `:247` | `ppg_adc_measurement_idac_integration.v` `i_beta_q15` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_run_profile与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_beta_q15`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2448 | `:248` | `ppg_adc_measurement_idac_integration.v` `i_timing_adjust_ratio_q15` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_initial_precision与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_timing_adjust_ratio_q15`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2449 | `:249` | `ppg_adc_measurement_idac_integration.v` `i_slope_min_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_slope_mode与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_slope_min_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2450 | `:250` | `ppg_adc_measurement_idac_integration.v` `i_slope_max_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_fixed_slope_q16与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_slope_max_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2451 | `:251` | `ppg_adc_measurement_idac_integration.v` `i_baseline_delta_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_alpha_q15与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_baseline_delta_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2452 | `:252` | `ppg_adc_measurement_idac_integration.v` `i_cross_hysteresis_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_beta_q15与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_cross_hysteresis_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2453 | `:253` | `ppg_adc_measurement_idac_integration.v` `i_lead_min_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_timing_adjust_ratio_q15与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_lead_min_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2454 | `:254` | `ppg_adc_measurement_idac_integration.v` `i_lead_max_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_slope_min_q16与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_lead_max_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2455 | `:255` | `ppg_adc_measurement_idac_integration.v` `i_cross_confirm_count` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_slope_max_q16与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_cross_confirm_count`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2456 | `:256` | `ppg_adc_measurement_idac_integration.v` `i_no_cross_limit` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_baseline_delta_q16与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_no_cross_limit`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2457 | `:257` | `ppg_adc_measurement_idac_integration.v` `i_peak_confirm_count` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_cross_hysteresis_q16与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_peak_confirm_count`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2458 | `:258` | `ppg_adc_measurement_idac_integration.v` `i_valley_confirm_count` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_lead_min_frames与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_valley_confirm_count`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2459 | `:259` | `ppg_adc_measurement_idac_integration.v` `i_direction_deadband` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_lead_max_frames与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_direction_deadband`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2460 | `:260` | `ppg_adc_measurement_idac_integration.v` `i_min_peak_valley_amplitude` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_cross_confirm_count与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_min_peak_valley_amplitude`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2461 | `:261` | `ppg_adc_measurement_idac_integration.v` `i_min_peak_to_valley_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_no_cross_limit与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_min_peak_to_valley_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2462 | `:262` | `ppg_adc_measurement_idac_integration.v` `i_min_peak_to_peak_frames` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_peak_confirm_count与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_min_peak_to_peak_frames`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2465 | `:265` | `ppg_adc_measurement_idac_integration.v` `i_peak_valley_config_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_min_peak_valley_amplitude与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_peak_valley_config_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2466 | ppg_control_top.v:1297 | `ppg_control_top.v` `o_detection_fork_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_detection_fork_idle`，原解析为o_precision_15_to_9_event |
| 矩阵 | 2467 | ppg_control_top.v:1298 | `ppg_control_top.v` `o_detector_idle` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_detector_idle`，原解析为o_precision_15_to_9_frame_id |
| 矩阵 | 2468 | ppg_control_top.v:1301 | `ppg_control_top.v` `o_cross_pending` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_cross_pending`，原解析为o_mode_fault_event |
| 矩阵 | 2469 | ppg_control_top.v:1302 | `ppg_control_top.v` `o_peak_pending` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_peak_pending`，原解析为o_normal_frame_count |
| 矩阵 | 2470 | ppg_control_top.v:1303 | `ppg_control_top.v` `o_valley_pending` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_valley_pending`，原解析为o_amb_recheck_pending |
| 矩阵 | 2471 | ppg_control_top.v:1304 | `ppg_control_top.v` `o_return_pending` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_return_pending`，原解析为o_amb_recheck_accept |
| 矩阵 | 2472 | ppg_control_top.v:1305 | `ppg_control_top.v` `o_baseline_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_baseline_valid`，原解析为o_amb_recheck_busy |
| 矩阵 | 2473 | ppg_control_top.v:1306 | `ppg_control_top.v` `o_reacquire_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_reacquire_active`，原解析为o_normal_output_inhibit |
| 矩阵 | 2474 | ppg_control_top.v:1307 | `ppg_control_top.v` `o_detector_fine_window_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_detector_fine_window_active`，原解析为o_recheck_sequence_done |
| 矩阵 | 2475 | ppg_control_top.v:1310 | `ppg_control_top.v` `o_slope_current_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_slope_current_q16`，原解析为o_fir_history_full_ir |
| 矩阵 | 2476 | ppg_control_top.v:1311 | `ppg_control_top.v` `o_baseline_protocol_error_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_baseline_protocol_error_sticky`，原解析为o_fir_idle |
| 矩阵 | 2477 | ppg_control_top.v:1312 | `ppg_control_top.v` `o_fine_window_timeout_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_fine_window_timeout_sticky`，原解析为o_detection_fork_idle |
| 矩阵 | 2478 | ppg_control_top.v:1313 | `ppg_control_top.v` `o_reacquire_timeout_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_reacquire_timeout_sticky`，原解析为o_detector_idle |
| 矩阵 | 2479 | ppg_control_top.v:1314 | `ppg_control_top.v` `o_peak_valley_protocol_error_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_peak_valley_protocol_error_sticky`，原解析为o_controller_idle |
| 矩阵 | 2503 | ppg_adc_measurement_idac_integration.v:242 | `ppg_adc_measurement_idac_integration.v` `i_run_profile` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dc15_recovery_valid与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_run_profile`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2504 | `:243` | `ppg_adc_measurement_idac_integration.v` `i_initial_precision` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dc9_recovery_gain_q16与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_initial_precision`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2505 | `:993` | `ppg_precision_window_integration.v` `ppg_amb_recheck_scheduler` | 第三轮（统筹10-10核对：格内写明的符号为准）：W6 格内写明`ppg_amb_recheck_scheduler`，原解析为i_normal_measurement_active；此前：PWI内部把本端口同时送给amb_recheck_scheduler |
| 矩阵 | 2507 | ppg_dynamic_baseline_cross_detector.v:550 | `ppg_dynamic_baseline_cross_detector.v` `o_cross_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：括注名cross_pending_o是AMI网、不在显式文件中；本行端口i_cross_valid，写入时版本:550为assign o_cross_valid，按显式文件与本行端口 |
| 矩阵 | 2510 | `:532` | `ppg_precision_window_integration.v` `dec_cross_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_cross_sample_index`，原解析文件ppg_dynamic_baseline_cross_detector.v无此名，按声明所在文件 |
| 矩阵 | 2515 | ppg_peak_valley_window_detector.v:441 | `ppg_peak_valley_window_detector.v` `o_return_9bit_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：括注名return_pending_o是AMI网、不在显式文件中；本行端口i_return_9bit_valid，导入版本:440为assign o_return_9bit_valid（漂移1行） |
| 矩阵 | 2517 | `:442` | `ppg_precision_window_integration.v` `dec_return_reason` | 括注符号dec_return_reason（PWI内部线） |
| 矩阵 | 2518 | `:443` | `ppg_precision_window_integration.v` `dec_return_frame_id` | 括注符号dec_return_frame_id（PWI内部线） |
| 矩阵 | 2519 | `:1001` | `ppg_amb_recheck_scheduler.v` `ppg_amb_recheck_scheduler` | 第三轮（统筹10-10核对：格内写明的符号为准）：W6 格内写明`ppg_amb_recheck_scheduler`，原解析文件ppg_400hz_frame_calibration_scheduler.v无此名，按声明所在文件 |
| 矩阵 | 2520 | `:2525` | `ppg_adc_measurement_idac_integration.v` `i_safe_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_coarse_saturation_low与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_safe_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2522 | `:2527` | `ppg_adc_measurement_idac_integration.v` `i_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_config_epoch与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_analog_safe`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2532 | `:1135` | `ppg_adc_measurement_idac_integration.v` `o_ami_fault_active` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内“ORed into `o_ami_fault_active` (:1135)”，AMI的5路lane-active汇总（原解析为PWI o_mode_fault_active，文件错归） |
| 矩阵 | 2534 | `:1140` | `ppg_adc_measurement_idac_integration.v` `o_ami_fault_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W6 格内写明`o_ami_fault_frame_id`，原解析文件ppg_precision_window_integration.v无此名，按声明所在文件 |
| 矩阵 | 2536 | `:362` | `ppg_adc_measurement_idac_integration.v` `o_ami_fault_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W6 格内写明`o_ami_fault_color_ir`，原解析文件ppg_precision_window_integration.v无此名，按声明所在文件 |
| 矩阵 | 2538 | `:364` | `ppg_adc_measurement_idac_integration.v` `o_ami_fault_precision` | 第三轮（统筹10-10核对：格内写明的符号为准）：W6 格内写明`o_ami_fault_precision`，原解析文件ppg_precision_window_integration.v无此名，按声明所在文件 |
| 矩阵 | 2552 | `:219` | `ppg_precision_window_integration.v` `amb_recheck_accept_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：同上 |
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
| 矩阵 | 2594 | ppg_adc_measurement_idac_integration.v:393 | `ppg_adc_measurement_idac_integration.v` `i_test_calibration_loss_inject_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_test_identity_inject_sample_index与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_test_calibration_loss_inject_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2619 | `:242` | `ppg_adc_measurement_idac_integration.v` `i_run_profile` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dc15_recovery_valid与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_run_profile`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2620 | `:243` | `ppg_adc_measurement_idac_integration.v` `i_initial_precision` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_dc9_recovery_gain_q16与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_initial_precision`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2621 | `:1001` | `ppg_adc_measurement_idac_integration.v` `i_macro_frame_safe_boundary` | AMI-hub行，端口i_macro_frame_safe_boundary在AMI内分送两个调度器 |
| 矩阵 | 2622 | `:143` | `ppg_adc_measurement_idac_integration.v` `i_safe_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_adc_idle与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_safe_frame_id`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2623 | `:140` | `ppg_adc_measurement_idac_integration.v` `i_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_clk_stage1_dout_low_async与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_analog_safe`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2624 | `:393` | `ppg_adc_measurement_idac_integration.v` `i_test_calibration_loss_inject_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_test_identity_inject_sample_index与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_test_calibration_loss_inject_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2625 | `:394,2601` | `ppg_adc_measurement_idac_integration.v` `o_test_calibration_loss_inject_ready` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_test_invalid_sample_valid、o_return_pending与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`o_test_calibration_loss_inject_ready`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2635 | `:1138` | `ppg_adc_measurement_idac_integration.v` `o_ami_fault_cause` | 左侧“o_ami_fault_cause=8'h04 dispatch” |
| 矩阵 | 2636 | `:84` | C10 §3 | 格内写明“§3 (:84, integration module scope)”；写入时:84已漂入§2，按格内节号与标题（§3 集成模块范围） |
| 矩阵 | 2641 | `:316` | `ppg_adc_measurement_idac_integration.v` `i_dout_stage1_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_switch_hold_new_transaction与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_dout_stage1_low`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2642 | `:317` | `ppg_adc_measurement_idac_integration.v` `i_clk_stage1_dout_low_async` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_mode_fault_event与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_clk_stage1_dout_low_async`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2643 | `:318` | `ppg_adc_measurement_idac_integration.v` `i_dout_stage2_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_normal_frame_count与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_dout_stage2_low`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2652 | `:2634` | `ppg_adc_measurement_idac_integration.v` `o_transaction_start_fire` | 左侧“AMI's own o_transaction_start_fire” |
| 矩阵 | 2682 | `:190-200` | C11 §6.1 事务代际与AMI私有排空 | “§6.1 (…)”指C11合同行 |
| 矩阵 | 2682 | `:224-226` | C11 §6.1 事务代际与AMI私有排空 | “§6.1 port table (…)”指C11合同行 |
| 矩阵 | 2682 | ppg_adc_s1_programmable_calibrator.v:58-116 | `ppg_adc_s1_programmable_calibrator.v` | 整段端口声明（58-116），文件级锚点 |
| 矩阵 | 2689 | `:1847` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_0` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析C_FRAME_ID_WIDTH与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage1_weight_q16_0`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2690 | `:1848` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_1` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析C_SAMPLE_INDEX_WIDTH与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage1_weight_q16_1`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2691 | `:1849` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_2` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析C_IDAC_CODE_WIDTH与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage1_weight_q16_2`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2692 | `:1850` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_3` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析C_CODE_EPOCH_WIDTH与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage1_weight_q16_3`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2693 | `:1851` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_4` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析C_CONFIG_EPOCH_WIDTH与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage1_weight_q16_4`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2694 | `:1852` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_5` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析C_COEF_EPOCH_WIDTH与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage1_weight_q16_5`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2697 | `:1855` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_8` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析ppg_adc_s1_programmable_calibrator_Inst与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage1_weight_q16_8`（声明或例化连接），取本行端口（行号漂移）；此前：弱解析结果经人工核对接受 |
| 矩阵 | 2698 | `:1856` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_9` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析i_clk与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage1_weight_q16_9`（声明或例化连接），取本行端口（行号漂移） |
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
| 矩阵 | 2736 | ppg_adc_measurement_idac_integration.v:1938-1956 | `ppg_adc_measurement_idac_integration.v` `ppg_adc_result_router_Inst` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内“At AMI's instantiation (…:1938-1956), all 18 of router's shared-payload output ports are left empty”：锚点是router在AMI中的例化（各输出端口名在AMI中多处例化重复出现，取例化名） |
| 矩阵 | 2736 | `:1985` | `ppg_adc_measurement_idac_integration.v` `ppg_normal_transaction_fork_Inst` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点bb39a0f（blame为最后改动该行的提交，不一定是写入锚点的提交），行号可能漂移；解析符号ppg_normal_transaction_fork_Inst与本行无关联，±5行内也无本行所述符号；AMI内fork例化 |
| 矩阵 | 2760 | `:1931` | `ppg_adc_measurement_idac_integration.v` `flag_idac_search_dcs_ready` | 括注符号 |
| 矩阵 | 2767 | ppg_adc_measurement_idac_integration.v:1938 | `ppg_adc_measurement_idac_integration.v` `o_calibrated_s1_value` | 第三轮（统筹10-10核对：格内写明的符号为准）：W10 格内写明`o_calibrated_s1_value`，原解析为i_sample_index |
| 矩阵 | 2872 | ppg_normal_transaction_fork.v:101 | `ppg_normal_transaction_fork.v` `i_normal_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析o_measurement_valid与本行无关；ppg_normal_transaction_fork.v有本行端口`i_normal_valid`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2927 | `:2138` | `ppg_adc_measurement_idac_integration.v` `i_stage2_offset_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析ppg_adc_programmable_reconstructor与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_stage2_offset_q16`（声明或例化连接），取本行端口（行号漂移）；此前：弱解析结果经人工核对接受 |
| 矩阵 | 2985 | `:482-500` | C15 §11.5 | “§11.5 (…)”指C15合同行 |
| 矩阵 | 2985 | ppg_adc_dc_recovery.v:55-145 | `ppg_adc_dc_recovery.v` | 整段端口声明（55-145），文件级锚点 |
| 矩阵 | 2985 | ppg_adc_measurement_idac_integration.v:2268-2290 | `ppg_adc_measurement_idac_integration.v` `o_programmable_15_calibration_applied` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，写入时点为导入提交，行号可能漂移；写入时版本第2283行（距引用0行）出现本行所述`o_programmable_15_calibration_applied` |
| 矩阵 | 2990 | `:2214` | `ppg_adc_measurement_idac_integration.v` `i_dc15_recovery_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析ppg_adc_dc_recovery与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_dc15_recovery_valid`（声明或例化连接），取本行端口（行号漂移）；此前：弱解析结果经人工核对接受 |
| 矩阵 | 2991 | `:2215` | `ppg_adc_measurement_idac_integration.v` `i_dc9_recovery_gain_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析C_FRAME_ID_WIDTH与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_dc9_recovery_gain_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 2992 | `:2216` | `ppg_adc_measurement_idac_integration.v` `i_dc15_recovery_gain_q16` | 第三轮（统筹10-10核对：格内写明的符号为准）：W9b 无格内符号，原解析C_SAMPLE_INDEX_WIDTH与本行无关；ppg_adc_measurement_idac_integration.v有本行端口`i_dc15_recovery_gain_q16`（声明或例化连接），取本行端口（行号漂移） |
| 矩阵 | 3027 | `:949` | `ppg_adc_measurement_idac_integration.v` `coarse_ppg_value_o` | “unpacked at (:949) into coarse_ppg_value_o”，AMI结果解包 |
| 矩阵 | 3028 | `:2252` | `ppg_adc_measurement_idac_integration.v` `flag_dc_coarse_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_coarse_valid`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3029 | `:2253` | `ppg_adc_measurement_idac_integration.v` `flag_dc_coarse_calibrated` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_coarse_calibrated`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3030 | `:2254` | `ppg_adc_measurement_idac_integration.v` `flag_dc_coarse_saturation_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_coarse_saturation_low`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3031 | `:2255` | `ppg_adc_measurement_idac_integration.v` `flag_dc_coarse_saturation_high` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_coarse_saturation_high`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3032 | `:2256` | `ppg_adc_measurement_idac_integration.v` `dec_dc_fine_ppg_value` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_fine_ppg_value`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3033 | `:2257` | `ppg_adc_measurement_idac_integration.v` `flag_dc_fine_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_fine_valid`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3034 | `:2258` | `ppg_adc_measurement_idac_integration.v` `flag_dc_fine_calibrated` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_fine_calibrated`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3035 | `:2259` | `ppg_adc_measurement_idac_integration.v` `flag_dc_fine_saturation_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_fine_saturation_low`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3036 | `:2260` | `ppg_adc_measurement_idac_integration.v` `flag_dc_fine_saturation_high` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_fine_saturation_high`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3037 | `:2261` | `ppg_adc_measurement_idac_integration.v` `dec_dc_recovery_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_recovery_epoch`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3038 | `:2262` | `ppg_adc_measurement_idac_integration.v` `dec_dc_s1_value` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_s1_value`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3039 | `:2263` | `ppg_adc_measurement_idac_integration.v` `flag_dc_s1_calibration_applied` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_s1_calibration_applied`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3040 | `:2264` | `ppg_adc_measurement_idac_integration.v` `flag_dc_s1_saturation_low` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_s1_saturation_low`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3041 | `:2265` | `ppg_adc_measurement_idac_integration.v` `flag_dc_s1_saturation_high` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_s1_saturation_high`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3042 | `:2266` | `ppg_adc_measurement_idac_integration.v` `dec_dc_programmable_15_code` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_programmable_15_code`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3043 | `:2267` | `ppg_adc_measurement_idac_integration.v` `flag_dc_programmable_15_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_programmable_15_valid`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3047 | `:2271` | `ppg_adc_measurement_idac_integration.v` `dec_dc_config_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_config_epoch`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3048 | `:2272` | `ppg_adc_measurement_idac_integration.v` `dec_dc_coef_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_coef_epoch`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3049 | `:2273` | `ppg_adc_measurement_idac_integration.v` `dec_dc_stage2_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_stage2_epoch`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3050 | `:2274` | `ppg_adc_measurement_idac_integration.v` `flag_dc_precision_mode` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_precision_mode`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3051 | `:2275` | `ppg_adc_measurement_idac_integration.v` `dec_dc_frame_id` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_frame_id`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3052 | `:2276` | `ppg_adc_measurement_idac_integration.v` `dec_dc_sample_index` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_sample_index`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3053 | `:2277` | `ppg_adc_measurement_idac_integration.v` `flag_dc_color_ir` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`flag_dc_color_ir`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3054 | `:2278` | `ppg_adc_measurement_idac_integration.v` `dec_dc_frame_type` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_frame_type`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3055 | `:2279` | `ppg_adc_measurement_idac_integration.v` `dec_dc_amb_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_amb_code_snapshot`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3056 | `:2280` | `ppg_adc_measurement_idac_integration.v` `dec_dc_dc_code_snapshot` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_dc_code_snapshot`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3057 | `:2281` | `ppg_adc_measurement_idac_integration.v` `dec_dc_amb_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_amb_code_epoch`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3058 | `:2282` | `ppg_adc_measurement_idac_integration.v` `dec_dc_dc_code_epoch` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`dec_dc_dc_code_epoch`，原解析文件ppg_adc_dc_recovery.v无此名，按声明所在文件 |
| 矩阵 | 3070 | `:1377` | `ppg_control_top.v` `ami_fault_active_o` | Top内部线（括注符号） |
| 矩阵 | 3079 | `:1386` | `ppg_control_top.v` `sched_fault_valid_o` | Top内部线（括注符号） |
| 矩阵 | 3089 | `:1396` | `ppg_control_top.v` `ssw_fault_valid_o` | Top内部线（括注符号） |
| 矩阵 | 3104 | ppg_control_top.v:348 | `ppg_control_top.v` `supervisor_system_abort_event_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：W7 格内写明`supervisor_system_abort_event_o`，原解析为o_system_abort_event |
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
| 矩阵 | 3157 | `:988` | `ppg_adc_measurement_idac_integration.v` `measurement_result_discard_event_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：W6 格内写明`measurement_result_discard_event_o`，原解析文件ppg_system_fault_abort_supervisor.v无此名，按声明所在文件 |
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
| 矩阵 | 3217 | `:167,218,246-254` | `ppg_amb_recheck_scheduler.v` `amb_recheck_pending_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内“C16/amb_recheck_scheduler's own pending state (amb_recheck_pending_o, …)” |
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
| 矩阵 | 3246 | `:1171-1172` | `ppg_adc_measurement_idac_integration.v` `i_diag_clear_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：W6 格内写明`i_diag_clear_event`，原解析为integration_protocol_error_sticky_o；此前：本行AMI集成协议sticky，START ACK/诊断清除 |
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
| 矩阵 | 3381 | ppg_adc_measurement_idac_integration.v:2432-2446 | `ppg_adc_measurement_idac_integration.v` `C_DATA_WIDTH` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，写入时点为导入提交，行号可能漂移；写入时版本第2447行（距引用1行）出现本行所述`C_DATA_WIDTH` |
| 矩阵 | 3397 | C10:11 | C10 §11 | 写入人用冒号写节号（同格/同表为节号写法），解析器误作行号；写入时C10第11行为版本日期，同表“matrix 9.”亦为节号写法 |
| 矩阵 | 3401 | `:66,70,124-143` | `ppg_config_cdc_bridge.v` `flag_source_request` | CDC桥源域寄存器（括注符号） |
| 矩阵 | 3401 | ppg_config_cdc_bridge.v:70-190 | `ppg_config_cdc_bridge.v` | 整段两域实现（70-190），文件级锚点 |
| 矩阵 | 3402 | ppg_control_top.v:308-313,324-330 | `ppg_control_top.v` `flag_diag_clear_event` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，写入时点为导入提交，行号可能漂移；写入时版本第318行（距引用0行）出现本行所述`flag_diag_clear_event` |
| 矩阵 | 3408 | tb_ppg_precision_window_controller.v:737-758 | `tb_ppg_precision_window_controller.v` `"PWC-41 new legal START preserves protocol sticky"` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：PWC-41的两条检查（另一条为switch-timeout sticky） |
| 矩阵 | 3456 | wrapper.v:480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点为导入提交，行号可能漂移；解析符号o_analog_safe与本行无关联，±5行内也无本行所述符号；SSW简写；:480为assign o_analog_safe |
| 矩阵 | 3552 | ppg_control_top.v:120 | `ppg_control_top.v` `i_analog_ready` | 第三轮（统筹10-10核对：格内写明的符号为准）：段落上一行写明`i_analog_ready`，锚点后引的注释原文“已同步模拟偏置/参考/输入选择RUN启动资格聚合结果”即基线该端口声明行（:126）的注释（原解析为:120处的i_clk_stage1_dout_low_async，行号漂移6行） |
| 矩阵 | 3557 | ppg_sar9_sar15_safe_selection_wrapper.v:480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | 右侧引文assign o_analog_safe |
| 矩阵 | 3561 | `:400-402` | `ppg_sar9_sar15_safe_selection_wrapper.v` `i_macro_tick` | SSW宏帧tick（括注符号） |
| 矩阵 | 3585 | ppg_sar9_sar15_safe_selection_wrapper.v:25,48,480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点为导入提交，行号可能漂移；解析符号o_analog_safe与本行无关联，±5行内也无本行所述符号；:25/:48为文件头修订记录，:480为assign o_analog_safe |
| 矩阵 | 3585 | ppg_control_top.v:120 | `ppg_control_top.v` `i_analog_ready` | 第三轮（统筹10-10核对：格内写明的符号为准）：D03（cause 8'h22模拟收敛检测）引用的Top锚点即上方冻结决定段（矩阵3550-3553行）所述`i_analog_ready`（原解析i_clk_stage1_dout_low_async，行号漂移） |
| 矩阵 | 3832 | :2 | （保留原文：not-anchor） | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“前8项:2项(G-FP-02/G-FP-06)”计数，不是行号 |
| 别名表 | 28 | ppg_sar9_sar15_safe_selection_wrapper.v:602 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: TOP-01` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 29 | ppg_system_config_manager.v:394-448,455-457,521-522,593-599 | `ppg_system_config_manager.v` `@satisfies: TOP-02` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_commit_accept、active_config_o、config_epoch_o、@satisfies: ILM-10与本行无关；本行ID在ppg_system_config_manager.v有@satisfies标签 |
| 别名表 | 29 | ppg_system_config_manager.v:340 | `ppg_system_config_manager.v` `@satisfies: TOP-02` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析dec_v5_reserved与本行无关；本行ID在ppg_system_config_manager.v有@satisfies标签 |
| 别名表 | 30 | ppg_400hz_frame_calibration_scheduler.v:458 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: TOP-03` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析adc_owner_commit_event_o与本行无关；本行ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 31 | ppg_sar9_sar15_safe_selection_wrapper.v:207 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: TOP-04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析RED_Q3_TICK与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 31 | ppg_400hz_frame_calibration_scheduler.v:224 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: TOP-04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析MACRO_SAFE_TICK与本行无关；本行ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 32 | ppg_400hz_frame_calibration_scheduler.v:222-223 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: TOP-05` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析INPUT_SOURCE_PHOTODIODE、MACRO_LAST_TICK与本行无关；本行ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 33 | ppg_dynamic_baseline_cross_detector.v:446,1590 | `ppg_dynamic_baseline_cross_detector.v` `@satisfies: TOP-06` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_cross_eligible_red_result、flag_below_seen与本行无关；本行ID在ppg_dynamic_baseline_cross_detector.v有@satisfies标签 |
| 别名表 | 34 | ppg_sar9_sar15_safe_selection_wrapper.v:379 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: TOP-07` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 35 | ppg_characterization_control_cdc.v:118 | `ppg_characterization_control_cdc.v` `@satisfies: TOP-08` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_test_mux_ctrl与本行无关；本行ID在ppg_characterization_control_cdc.v有@satisfies标签 |
| 别名表 | 36 | ppg_system_config_manager.v:460-462 | `ppg_system_config_manager.v` `@satisfies: TOP-09` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_stop_accept、@satisfies: TOP-09与本行无关；本行ID在ppg_system_config_manager.v有@satisfies标签 |
| 别名表 | 38 | ppg_400hz_frame_calibration_scheduler.v:549 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: TOP-11` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_macro_frame_start_event与本行无关；本行ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 39 | ppg_control_top.v:409 | `ppg_control_top.v` `@satisfies: TOP-12` | 行ID/本格点名ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 40 | ppg_400hz_frame_calibration_scheduler.v:754 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: TOP-13` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 41 | ppg_adc_measurement_idac_integration.v:1197 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-16` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 42 | ppg_control_top.v:414 | `ppg_control_top.v` `@satisfies: TOP-17` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_measurement_start_ack_event与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 43 | ppg_control_top.v:408-409 | `ppg_control_top.v` `@satisfies: TOP-18` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析wrapper_start_ack_event_o与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 44 | ppg_control_top.v:848 | `ppg_control_top.v` `@satisfies: TOP-19` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析i_run_enable与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 45 | ppg_400hz_frame_calibration_scheduler.v:425 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: TOP-20` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 45 | ppg_system_config_manager.v:394-448 | `ppg_system_config_manager.v` `flag_snapshot_dc_qualification_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点bb39a0f（blame为最后改动该行的提交，不一定是写入锚点的提交），行号可能漂移；解析符号flag_snapshot_dc_qualification_valid与本行无关联，±5行内也无本行所述符号；静态检查侧，写入时:448为该汇总资格 |
| 别名表 | 46 | ppg_adc_measurement_idac_integration.v:905 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-21` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 47 | ppg_adc_measurement_idac_integration.v:908,909 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-22` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_test_inject_effective、flag_test_identity_inject_fire与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 48 | ppg_adc_measurement_idac_integration.v:1010 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-23` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 49 | ppg_adc_measurement_idac_integration.v:1009,1010 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-24` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_measurement_result_discard_run_generation与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 59 | ppg_precision_window_integration.v:308,472,961 | `ppg_precision_window_integration.v` `@satisfies: K01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_precision_controller_fault_active、o_mode_fault_active与本行无关；本行ID在ppg_precision_window_integration.v有@satisfies标签 |
| 别名表 | 60 | ppg_adc_measurement_idac_integration.v:2573 | `ppg_adc_measurement_idac_integration.v` `@satisfies: K01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_reacquire_request_event与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 61 | ppg_adc_measurement_idac_integration.v:1150,450-451,1455-1474 | `ppg_adc_measurement_idac_integration.v` `@satisfies: K01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_ami_fault_active、flag_ami_fault_pending_01、flag_ami_fault_pending_02、flag_ami_fault_pending_04与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 62 | ppg_idac_code_controller.v:638 | `ppg_idac_code_controller.v` `@satisfies: K01` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_controller_fault_blocking与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 62 | ppg_adc_measurement_idac_integration.v:2431-2432 | `ppg_adc_measurement_idac_integration.v` `@satisfies: K01` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_controller_fault_blocking、o_controller_fault_event与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 63 | ppg_system_fault_abort_supervisor.v:198,251-299 | `ppg_system_fault_abort_supervisor.v` `@satisfies: K02` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_episode_open_edge与本行无关；本行ID在ppg_system_fault_abort_supervisor.v有@satisfies标签 |
| 别名表 | 64 | ppg_precision_window_integration.v:71 | `ppg_precision_window_integration.v` `@satisfies: K03` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析C_RUN_GENERATION_WIDTH与本行无关；本行ID在ppg_precision_window_integration.v有@satisfies标签 |
| 别名表 | 65 | ppg_idac_code_controller.v:61 | `ppg_idac_code_controller.v` `@satisfies: K03` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析C_RUN_GENERATION_WIDTH与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 66 | ppg_adc_measurement_idac_integration.v:92 | `ppg_adc_measurement_idac_integration.v` `@satisfies: K03` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析C_RUN_GENERATION_WIDTH与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 68 | ppg_precision_window_integration.v:443 | `ppg_precision_window_integration.v` `@satisfies: K04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_detection_discard_apply与本行无关；本行ID在ppg_precision_window_integration.v有@satisfies标签 |
| 别名表 | 75 | ppg_system_active_config_unpack.v:209 | `ppg_system_active_config_unpack.v` `@satisfies: G-FP-01-D01-04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_peak_valley_config_valid与本行无关；本行ID在ppg_system_active_config_unpack.v有@satisfies标签 |
| 别名表 | 76 | ppg_active_v4_control_plane_integration.v:375 | `ppg_active_v4_control_plane_integration.v` `@satisfies: G-FP-01-D01-04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析o_peak_valley_config_valid与本行无关；本行ID在ppg_active_v4_control_plane_integration.v有@satisfies标签 |
| 别名表 | 77 | ppg_adc_measurement_idac_integration.v:2512 | `ppg_adc_measurement_idac_integration.v` `@satisfies: G-FP-01-D01-04` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析i_peak_valley_config_valid与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 78 | ppg_dynamic_baseline_cross_detector.v:480 | `ppg_dynamic_baseline_cross_detector.v` `@satisfies: G-FP-01-D01-04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_candidate_start与本行无关；本行ID在ppg_dynamic_baseline_cross_detector.v有@satisfies标签 |
| 别名表 | 79 | ppg_peak_valley_window_detector.v:111 | `ppg_peak_valley_window_detector.v` `@satisfies: G-FP-01-D01-04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析i_peak_valley_config_valid与本行无关；本行ID在ppg_peak_valley_window_detector.v有@satisfies标签 |
| 别名表 | 86 | :1024 | （保留原文：not-anchor） | “1024-bit CDC payload”位宽，不是行号 |
| 别名表 | 89 | ppg_adc_measurement_idac_integration.v:2509 | `ppg_adc_measurement_idac_integration.v` `i_peak_valley_config_valid` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，写入时点bb39a0f（blame为最后改动该行的提交，不一定是写入锚点的提交），行号可能漂移；写入时版本第2512行（距引用3行）出现本行所述`i_peak_valley_config_valid` |
| 别名表 | 90 | :12 | PPG_CONTRACT_CLOSURE_MATRIX.md §12 | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“MATRIX.md:12.14节”用冒号写节号（§12.14），解析器误作第12行；原文“.14”保留 |
| 别名表 | 96 | ppg_sar9_sar15_safe_selection_wrapper.v:480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：写入时:480为assign o_analog_safe |
| 别名表 | 106 | ppg_control_top.v:316,722 | `ppg_control_top.v` `@satisfies: G-FP-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析sup_system_fault_summary_o与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 107 | ppg_control_top.v:355 | `ppg_control_top.v` `@satisfies: G-FP-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_owner_abort_event与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 108 | ppg_adc_measurement_idac_integration.v:1605 | `ppg_adc_measurement_idac_integration.v` `flag_adc_transaction_inflight` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点为导入提交，行号可能漂移；解析符号flag_adc_transaction_inflight与本行无关联，±5行内也无本行所述符号；本行“AMI物理ADC owner代表行”；写入时:1605为owner交接注释，AMI无G-FP-01本号标签 |
| 别名表 | 109 | ppg_sar9_sar15_safe_selection_wrapper.v:1089-1097,1274-1282 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: G-FP-02` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_ir_context_valid、flag_red_context_valid与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 110 | ppg_precision_window_controller.v:266-270,829,831,842,844 | `ppg_precision_window_controller.v` `@satisfies: G-FP-02` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_enter_commit、flag_return_commit、flag_pending_state、flag_lifecycle_cancel与本行无关；本行ID在ppg_precision_window_controller.v有@satisfies标签 |
| 别名表 | 112 | `:26` | `ppg_idac_code_controller.v` | C17文件头V2.3修订记录，文件级锚点 |
| 别名表 | 115 | ppg_precision_window_integration.v:55-72 | `ppg_precision_window_integration.v` `@satisfies: G-FP-05` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析C_DATA_WIDTH、C_FRAME_ID_WIDTH、C_SAMPLE_INDEX_WIDTH、C_IDAC_CODE_WIDTH与本行无关；本行ID在ppg_precision_window_integration.v有@satisfies标签 |
| 别名表 | 116 | ppg_config_cdc_bridge.v:66-190 | `ppg_config_cdc_bridge.v` | uncertain：同格后文有带日期的勘误/补记但未明示作废前文，按“拿不准时默认转换”处理；整段两域实现，文件级锚点 |
| 别名表 | 116 | :112-120 | `ppg_config_cdc_bridge.v` `destination_config_o` | 第三轮（统筹10-10核对：格内写明的符号为准）：W6 格内写明`destination_config_o`，原解析文件ppg_active_v4_control_plane_integration.v无此名，按声明所在文件 |
| 别名表 | 117 | ppg_idac_code_controller.v:580 | `ppg_idac_code_controller.v` `@satisfies: G-FP-06` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_control_cancel与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 135 | ppg_400hz_frame_calibration_scheduler.v:463-464 | `ppg_400hz_frame_calibration_scheduler.v` `o_owner_deadline_timeout_sticky` | 第三轮（统筹10-10核对：格内写明的符号为准）：格内“o_scheduler_owner_deadline_timeout_sticky(scheduler.v:463-464附近deadline逻辑)”：Top端口由调度器o_owner_deadline_timeout_sticky驱动，锚点文件为调度器 |
| 别名表 | 143 | tb_ppg_control_top_startup_idac_calibration.v:1278-1305 | `tb_ppg_control_top_startup_idac_calibration.v` `"PASS SID-06 next-subframe waveform snapshot correctly reflects"` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“已补真实断言…见…”指该TB的SID-06下一子帧检查 |
| 别名表 | 153 | ppg_400hz_frame_calibration_scheduler.v:452 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: LFA-01` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 153 | ppg_idac_code_controller.v:1124 | `ppg_idac_code_controller.v` `@satisfies: LFA-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_context_next与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 154 | ppg_400hz_frame_calibration_scheduler.v:452 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: LFA-02` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 156 | ppg_400hz_frame_calibration_scheduler.v:876 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: LFA-05` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 156 | ppg_adc_async_stage_capture.v:107 | `ppg_adc_async_stage_capture.v` `@satisfies: LFA-05` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_capture_accept与本行无关；本行ID在ppg_adc_async_stage_capture.v有@satisfies标签 |
| 别名表 | 157 | ppg_adc_async_stage_capture.v:107 | `ppg_adc_async_stage_capture.v` `@satisfies: LFA-07` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_capture_accept与本行无关；本行ID在ppg_adc_async_stage_capture.v有@satisfies标签 |
| 别名表 | 160 | ppg_idac_code_controller.v:1138 | `ppg_idac_code_controller.v` `@satisfies: LFA-12` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_context_next与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 167 | ppg_400hz_frame_calibration_scheduler.v:737 | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: OIB-02` | 行ID/本格点名ID在ppg_400hz_frame_calibration_scheduler.v有@satisfies标签 |
| 别名表 | 168 | ppg_adc_measurement_idac_integration.v:1024 | `ppg_adc_measurement_idac_integration.v` `@satisfies: OIB-03` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 169 | ppg_adc_async_stage_capture.v:107 | `ppg_adc_async_stage_capture.v` `@satisfies: OIB-05` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_capture_accept与本行无关；本行ID在ppg_adc_async_stage_capture.v有@satisfies标签 |
| 别名表 | 170 | ppg_adc_measurement_idac_integration.v:1745 | `ppg_adc_measurement_idac_integration.v` `@satisfies: OIB-07` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 172 | PPG_SESSION_HANDOFF_20260826_2.md:1044-1047 | （保留原文：external） | 会话交接文档未随本仓库快照入库，无法读取 |
| 别名表 | 175 | PPG_SESSION_HANDOFF_20260826_2.md:1042-1044 | （保留原文：external） | 会话交接文档未随本仓库快照入库，无法读取 |
| 别名表 | 176 | PPG_SESSION_HANDOFF_20260826_2.md:1042-1044 | （保留原文：external） | 会话交接文档未随本仓库快照入库，无法读取 |
| 别名表 | 177 | ppg_sar9_sar15_safe_selection_wrapper.v:438 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: OIB-01` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 179 | ppg_adc_measurement_idac_integration.v:1010 | `ppg_adc_measurement_idac_integration.v` `@satisfies: TOP-23` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“已打@satisfies: TOP-23, TOP-24(…)” |
| 别名表 | 188 | ppg_coarse_detection_fir.v:120-122,309,312-313,315 | `ppg_coarse_detection_fir.v` `@satisfies: PRC-09` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析i_test_inject_enable、i_test_calibration_loss_inject_valid、o_test_calibration_loss_inject_ready、flag_history_transfer与本行无关；本行ID在ppg_coarse_detection_fir.v有@satisfies标签 |
| 别名表 | 199 | ppg_dynamic_baseline_cross_detector.v:1510,632 | `ppg_dynamic_baseline_cross_detector.v` `@satisfies: RRC-09` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_peak_context、slope_current_q16_o与本行无关；本行ID在ppg_dynamic_baseline_cross_detector.v有@satisfies标签 |
| 别名表 | 214 | ppg_idac_code_controller.v:1084 | `ppg_idac_code_controller.v` `@satisfies: TRK-03` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_context_next与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 214 | `:1087` | `ppg_idac_code_controller.v` `@satisfies: TRK-03` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_context_next与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 215 | ppg_idac_code_controller.v:1070 | `ppg_idac_code_controller.v` `@satisfies: TRK-04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_context_next与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 215 | `:1091` | `ppg_idac_code_controller.v` `@satisfies: TRK-04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_context_next与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 233 | ppg_dynamic_baseline_cross_detector.v:1545 | `ppg_dynamic_baseline_cross_detector.v` `@satisfies: NRE-05` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_candidate_context与本行无关；本行ID在ppg_dynamic_baseline_cross_detector.v有@satisfies标签 |
| 别名表 | 241 | ppg_idac_code_controller.v:703 | `ppg_idac_code_controller.v` `@satisfies: ILM-09` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析state_next与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 246 | `:381` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-05` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 246 | `:673-674` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-05` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 246 | `:727-728` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-05` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 247 | `:381` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-06` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 247 | `:673-674` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-06` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 247 | `:389` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-06` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 248 | `:381` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-07` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 248 | `:727-728` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-07` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 248 | `:388` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-07` | 行ID/本格点名ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 250 | ppg_idac_code_controller.v:703 | `ppg_idac_code_controller.v` `@satisfies: ILM-09` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析state_next与本行无关；本行ID在ppg_idac_code_controller.v有@satisfies标签 |
| 别名表 | 253 | ppg_sar9_sar15_safe_selection_wrapper.v:387 | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-12` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_calibration_mode_legal与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 253 | `:741-742` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-12` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_control_next、@satisfies: SID-08与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 253 | `:762` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-12` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_control_next与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 253 | `:763` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ILM-12` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_control_next与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签 |
| 别名表 | 260 | ppg_adc_measurement_idac_integration.v:1745 | `ppg_adc_measurement_idac_integration.v` `reg_result_fork_payload` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：右侧引文reg_result_fork_payload<=enc_dc_result_payload |
| 别名表 | 270 | ppg_adc_measurement_idac_integration.v:1745 | `ppg_adc_measurement_idac_integration.v` `@satisfies: ADCN-07` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 271 | ppg_adc_measurement_idac_integration.v:1745 | `ppg_adc_measurement_idac_integration.v` `@satisfies: ADCN-08` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 277 | ppg_idac_code_controller.v:879 | `ppg_idac_code_controller.v` `@satisfies: ISE-10` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“ISE-10直接追加到…(TRK-07/TRK-08既有锚点)” |
| 别名表 | 277 | `:808` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_cal_amb_code与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签；此前：第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内写明“SSW自己的…门控快照锁存(:808环境码”；写入时SSW:808为reg_cal_amb_code锁存，解析器误归C17 |
| 别名表 | 277 | `:847` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_cal_dc_code与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签；此前：第二轮（统筹10-09裁定：带日期的现行结论一律转换）：同上“:847直流码”；写入时SSW:847为reg_cal_dc_code锁存 |
| 别名表 | 277 | `:652,654,702,704` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-04` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：“锚定在SSW的NORMAL运行波形块”SAR9总线；写入时这些SSW行带ISE-04注释 |
| 别名表 | 277 | `:642,644,692,694` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-05` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：同上SAR15总线；写入时这些SSW行带ISE-05注释 |
| 别名表 | 277 | `:642,652` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-07` | 第二轮（统筹10-09裁定：带日期的现行结论一律转换）：格内“(:642,652追加ISE-07)” |
| 别名表 | 277 | `:615` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_control_next与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签；此前：第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06 STATIC_BIAS“无条件清零初值”；写入时SSW:615为reg_control_next默认清零 |
| 别名表 | 277 | `:742` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_cal_amb_code与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签；此前：第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06 AMB总线；写入时SSW:742为reg_cal_amb_code码窗 |
| 别名表 | 277 | `:745` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析CTRL_EN_9_DC与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签；此前：第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06“EN_9_DC使能门控”；写入时SSW:745为CTRL_EN_9_DC赋值 |
| 别名表 | 277 | `:747` | `ppg_sar9_sar15_safe_selection_wrapper.v` `@satisfies: ISE-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析reg_cal_dc_code与本行无关；本行ID在ppg_sar9_sar15_safe_selection_wrapper.v有@satisfies标签；此前：第二轮（统筹10-09裁定：带日期的现行结论一律转换）：ISE-06“DC9码窗”；写入时SSW:747为reg_cal_dc_code码窗 |
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
| 别名表 | 408 | `:607-639` | `ppg_coarse_detection_fir.v` `@satisfies: FIR-01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析dec_mac_operand、dec_mac_coefficient与本行无关；本行ID在ppg_coarse_detection_fir.v有@satisfies标签 |
| 别名表 | 455 | ppg_adc_measurement_idac_integration.v:908,909 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P07` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_test_inject_effective、flag_test_identity_inject_fire与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 456 | ppg_control_top.v:414 | `ppg_control_top.v` `@satisfies: P17` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_measurement_start_ack_event与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 458 | ppg_precision_window_controller.v:269 | `ppg_precision_window_controller.v` `@satisfies: N02` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_lifecycle_cancel与本行无关；本行ID在ppg_precision_window_controller.v有@satisfies标签 |
| 别名表 | 462 | ppg_adc_measurement_idac_integration.v:1024 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P01` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 462 | `:1315` | `ppg_adc_measurement_idac_integration.v` `@satisfies: P01` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 462 | ppg_normal_transaction_fork.v:194-309 | `ppg_normal_transaction_fork.v` | 两分支所有权整段（194-309），文件级锚点 |
| 别名表 | 463 | ppg_adc_measurement_idac_integration.v:967 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P02` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_ami_fault_dispatch_03与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 464 | ppg_system_fault_abort_supervisor.v:279 | `ppg_system_fault_abort_supervisor.v` `@satisfies: P03` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析system_stop_request_event_o与本行无关；本行ID在ppg_system_fault_abort_supervisor.v有@satisfies标签 |
| 别名表 | 465 | ppg_system_fault_abort_supervisor.v:302 | `ppg_system_fault_abort_supervisor.v` `@satisfies: P04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析system_fault_cause_valid_o与本行无关；本行ID在ppg_system_fault_abort_supervisor.v有@satisfies标签 |
| 别名表 | 466 | ppg_system_fault_abort_supervisor.v:192 | `ppg_system_fault_abort_supervisor.v` `@satisfies: P05` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_watchdog_timeout_fire与本行无关；本行ID在ppg_system_fault_abort_supervisor.v有@satisfies标签 |
| 别名表 | 467 | ppg_adc_measurement_idac_integration.v:1569 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P06` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 468 | ppg_adc_measurement_idac_integration.v:1493 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P08` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 469 | ppg_system_fault_abort_supervisor.v:413 | `ppg_system_fault_abort_supervisor.v` `@satisfies: P09` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析system_fault_summary_o与本行无关；本行ID在ppg_system_fault_abort_supervisor.v有@satisfies标签 |
| 别名表 | 470 | ppg_system_fault_abort_supervisor.v:207 | `ppg_system_fault_abort_supervisor.v` `@satisfies: P10` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析dec_selected_cause与本行无关；本行ID在ppg_system_fault_abort_supervisor.v有@satisfies标签 |
| 别名表 | 471 | ppg_control_top.v:391 | `ppg_control_top.v` `@satisfies: P11` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_test_inject_mode_latched与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 472 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点为导入提交，行号可能漂移；解析符号C_ADC_DRAIN_WATCHDOG_CYCLES与本行无关联，±5行内也无本行所述符号；参数化位宽约束注释块，紧邻C_ADC_DRAIN_WATCHDOG_CYCLES |
| 别名表 | 474 | ppg_adc_measurement_idac_integration.v:1223 | `ppg_adc_measurement_idac_integration.v` `@satisfies: P14` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 475 | ppg_adc_measurement_idac_integration.v:1223 | `ppg_adc_measurement_idac_integration.v` `@satisfies: LFA-04` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 475 | `:1493` | `ppg_adc_measurement_idac_integration.v` `@satisfies: LFA-04` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 476 | ppg_adc_measurement_idac_integration.v:1223 | `ppg_adc_measurement_idac_integration.v` `@satisfies: OIB-08` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 476 | `:1493` | `ppg_adc_measurement_idac_integration.v` `@satisfies: OIB-08` | 行ID/本格点名ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 477 | ppg_control_top.v:1387 | `ppg_control_top.v` `@satisfies: P15` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析C_RUN_GENERATION_WIDTH与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 478 | ppg_adc_measurement_idac_integration.v:967 | `ppg_adc_measurement_idac_integration.v` `@satisfies: N01` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_ami_fault_dispatch_03与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 479 | ppg_system_fault_abort_supervisor.v:207 | `ppg_system_fault_abort_supervisor.v` `@satisfies: N03` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析dec_selected_cause与本行无关；本行ID在ppg_system_fault_abort_supervisor.v有@satisfies标签 |
| 别名表 | 480 | ppg_control_top.v:327 | `ppg_control_top.v` `@satisfies: N04` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_diag_clear_event与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 481 | ppg_control_top.v:391 | `ppg_control_top.v` `@satisfies: N05` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_test_inject_mode_latched与本行无关；本行ID在ppg_control_top.v有@satisfies标签 |
| 别名表 | 482 | ppg_system_fault_abort_supervisor.v:192 | `ppg_system_fault_abort_supervisor.v` `@satisfies: N06` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_watchdog_timeout_fire与本行无关；本行ID在ppg_system_fault_abort_supervisor.v有@satisfies标签 |
| 别名表 | 483 | ppg_adc_measurement_idac_integration.v:978 | `ppg_adc_measurement_idac_integration.v` `@satisfies: N08` | 第三轮（统筹10-10核对：格内写明的符号为准）：无格内符号，原解析flag_datapath_discard_precision与本行无关；本行ID在ppg_adc_measurement_idac_integration.v有@satisfies标签 |
| 别名表 | 562 | :6 | （保留原文：not-anchor） | “D01链…:6段”数量，不是行号 |
| 别名表 | 568 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` | 第三轮（统筹10-10核对：格内写明的符号为准）：低置信：无格内符号，写入时点为导入提交，行号可能漂移；解析符号C_ADC_DRAIN_WATCHDOG_CYCLES与本行无关联，±5行内也无本行所述符号；同P12行 |

## 附录B 本批提交（`7a8eabf..4010f2e`，按时间顺序；本报告所在的提交在其后）

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
| `f8aaf4b` | B合并批次：报告、总表、进度按统筹10-09裁定更新 |
| `9d62ad4` | B合并批次：锚点历史裁定③类“被后续条目取代的旧条目”单列 |
| `ad905e8` | B合并批次锚点第三轮（写入前快照）：语义一致性复查（统筹10-10核对意见） |
| `c0190c1` | B合并批次锚点第三轮写入：格内写明的符号为准，语义复查纠正247处；anchor_check新增语义模式（统筹10-10核对意见） |
| `510fd8d` | B合并批次：矩阵§12.4a摘要重算（锚点第三轮后，仅M01变化，26/26） |
| `d93ea89` | B合并批次：报告、总表、进度按统筹10-10核对意见更新（锚点第三轮、语义检查模式、BMI-912） |
| `77d281a` | B合并批次：HEAD上§12.4a与anchor_check（含语义模式）复核记录 |
| `85e8678` | B合并批次锚点第三轮补正（写入前快照）：端口台账端口列为行主题（W9/W9b），例化连接`.port()`写明名（W10），撤销“写入时点可靠”类 |
| `de06123` | B合并批次锚点第三轮补正写入：端口台账端口列为行主题，增量改写311处；anchor_check新增端口台账检查（1c）与W10 |
| `4010f2e` | B合并批次：矩阵§12.4a摘要重算（锚点第三轮补正后，仅M01变化，26/26） |
