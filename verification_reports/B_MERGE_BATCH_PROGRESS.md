# B合同合并批次进度（B_MERGE_BATCH_PROGRESS）

> 依据：`verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`（下称"交接书"）。
> 用途：交接书§1要求的进度保存文件。会话被压缩或中断后，从本文件恢复。
> 分支：`b-merge-batch`，从main `a1ba482` 切出。`a1ba482`与基线`7a8eabf`的差异只有两份新增报告（交接书与F9核查报告），RTL/TB逐字节相同，已用`git diff --stat 7a8eabf a1ba482`核实。

---

## 当前状态

- **已完成**：克隆仓库、切出分支、首次回复、用户答复落定（条目1）；在仓库根目录重开会话并加载skill（条目2）；阶段0基线回归已在后台启动（条目2）。
- **当前项**：阶段0基线已在回归机上核对通过（条目13）；阶段3（TB标签改名与别名表对照）已完成；下一步做阶段4锚点写入。
- **下一步**：① 阶段4：按`anchor_conversion/anchor_mapping_table.tsv`把锚点一次性写入矩阵和别名表；生成`anchor_history_allowlist.json`；补`@satisfies`（BMI-160）；HEAD上anchor_check 0报错；独立复核；接入门禁。② 阶段5：正式重算§12.4a，刷新§13。③ 把最终提交号交给回归机，按`REGRESSION_RUN_REQUEST.md` §2跑终版回归，用`regression_evidence.py compare`与`baseline_7a8eabf`比对。④ 阶段7报告。
- **未决问题**：无。“回归机Vivado须为2022.2”已确认（`ea60432`的MACHINE.txt为Vivado Simulator v2022.2）。

---

## 进度条目

### 条目1（2026-10-09）：开工前确认，用户答复

**任务理解（已经用户确认无误）**
1. 本批次只改文档层：合同、矩阵、别名表。以`7a8eabf`最终RTL为准，一次性落地三份交B清单（ABCD §12.8、生命周期§8、F-009 §9）与交接书§3的裁定，按一级改、二级登记、三级不做处理。
2. 把行号锚点全部换成符号锚点，附旧→新对照表。检查脚本先做负对照，再接入门禁。§12.4a摘要改为脚本生成。
3. 权威顺序：RTL > 交接书§3（覆盖点见§3.12）> 交B清单 > 更早报告。
4. RTL逻辑不改，只改§3.9点名的注释和追加`@satisfies`。TB只改PASS标签和格式串。RTL疑点只登记，不修。
5. 同机、同版本跑基线和终版两次回归，逐TB比对PASS行与`$finish`，证据入库。

**阶段计划**：按交接书§4的阶段0~7执行。阶段1的总表推到分支后**停下**。

**用户答复（权威）**
- **Vivado**：使用2019.2，`VIVADO_BIN=/d/vivado/2019.2/bin`（本机没有2022.2）。
  - 先跑基线，与参考值核对：系统TB 20/20、PASS 1250行（按`grep -E '\bPASS\b'`计，排除含`pass=`的汇总行）、芯片20/0、模块级28/28。
  - **对不上就停下报告，不得为迁就版本改RTL/TB。**
  - 合并前统筹会在其机器上用2022.2复跑分支终版，作为最终验收。报告中注明本批次回归使用2019.2。
- **推送**：账号`lichenxizhang-lang`已加为`xinyanbaiqi/zlcx`协作者，直接推`b-merge-batch`，不fork。
  - 2026-10-09用`git push --dry-run`验证写权限通过。
- **代理**：git全局配置`http(s).proxy=127.0.0.1:7897`连不上。网络操作只在单条命令里临时加`-c http.proxy=http://127.0.0.1:12450 -c https.proxy=http://127.0.0.1:12450`。**不改全局git配置。**
- **skill**：在仓库根目录`D:\ppg_zlcx\zlcx`重开会话，让`CLAUDE.md`与`.claude/skills/erie-verilog-generator/`（v0.4.0）自动加载，避免长任务压缩后丢失规范。
- **阶段1检查点**：总表`B_MERGE_BATCH_ITEMS.md`推到分支后停下，由用户转统筹审核。统筹暂时无法审核时由用户直接确认，并在最终报告中注明"总表未经统筹审核"。

**环境记录**
- Git Bash，Windows 11。Python 3.8.5（`/d/DevSoftwares/Python38`）与Python 3.12.4（`/c/Users/DAWN/AppData/Local/Programs/Python/Python312`）都已安装。本机无`gh`。
- iverilog在`/d/iverilog/bin`，本批次不用（回归以xsim为准）。

### 条目2（2026-10-09）：重开会话，阶段0启动

- 会话在`D:\ppg_zlcx\zlcx`重开，CLAUDE.md与`erie-verilog-generator`skill已加载。
- 基线导出：`git -c core.autocrlf=false archive 7a8eabf | tar -x`，导出到仓库外`D:/ppg_zlcx/b_merge_runs/baseline_7a8eabf/`下6个独立目录（`sys_g1..g4`、`chip`、`unit`）；`.sh`无CR。
- 系统TB分4组并行。分组只改各组**本地运行副本**中`run_xsim_regression.sh`的`ORDER=(...)`数组（不提交，其余逐字未动）：
  - g1：longrun、diag_algo_probe、raw_generator_selfcheck、control_top(smoke)、baseline_cross
  - g2：long_10_cycles、fir_tail_isolation、adc_numeric_scoreboard、idac_bus_isolation、injection
  - g3：lifecycle_fault_adc_anomaly、input_light_static_matrix、normal_slow_tracking、no_recheck_control、owner_identity_backpressure
  - g4：peak_valley_return、periodic_recheck_recovery、robustness_corner_waveforms、startup_idac_calibration、adc_anomaly
- 芯片：`rtl/ppg_chip_digital_top/run_xsim_regression.sh`；模块级：`tools/run_unit_tb_regression.sh -o <baseline>/unit_runs -g all`。
- `VIVADO_BIN=/d/vivado/2019.2/bin`。终版回归须用相同分组与相同Vivado。

### 条目3（2026-10-09）：阶段1总表

- 读完三份交B清单（ABCD §12.8与§10(b)、OLR §8、F009 §9）、IDG/IDF、F28、F9R、SSW18 §5、LCN §5，合成总表`B_MERGE_BATCH_ITEMS.md`。
- 条目编号用`BMI-nnn`（全仓grep确认未被占用）。一级95条，另有TB标签、工具、RTL注释、二级、排除项等；5个待裁定问题见总表§18。
- 表中引用的RTL符号已在`7a8eabf`的非TB RTL中逐个grep确认存在。

### 条目4（2026-10-09）：统筹审核通过总表

- 统筹批准总表，进入阶段2。7条意见已原文记入总表§20，并落到BMI-027（L-6给编号）、BMI-063/136（OVL、OPTC在C13/C21登记，对不上标"仅TB检查"；JNT先查联合TB说明）、BMI-135/910（族级登记，逐条对照列收尾计划）、BMI-141（SUP一律本地名）、BMI-907。
- 基线回归若不符：阶段3改TB标签之前停下报告；阶段2可先进行。

### 条目5（2026-10-09）：阶段2进行中

- 已提交：C08 V1.13（`e424874`）、C09 V1.11（`4946328`，新增SSW-53=L-6，编号先全仓grep确认未占用）、C10 V2.5（`153dade`）。
- 改写方式：每处改动都写成“原行补充”或删除线+新文，带日期的历史叙述不改；新文字引用RTL符号（文件+符号）。
- 新发现并已处理：BMI-058（C10 §6.11私有datapath discard扇出与RTL不符）。
- **待做的版本联动**：各合同升版后，其它合同的依赖表与矩阵§12.4中的版本号在阶段2末尾统一改一次（单独提交），见交接书“版本联动”先例（CONTRACT_SYNC_BATCH3_PHASE2）。
- 编号决定：AMI的作废/升级规则按OLR §8.3指定并入AMI-39/40/24与LFA-04，不新增AMI编号。

### 条目6（2026-10-09）：阶段2完成

- 合同提交（按合同一个提交）：C08 V1.13、C09 V1.11、C10 V2.5、C24 V1.6、C16 V2.2、C18 V2.2、C23 V2.7、C17 V2.4、C13 V1.3、C25 V1.8、C01 V1.18勘误、芯片顶层V1.17勘误、C02 V4.10、C07 V1.2、C19 V2.6、C03 V1.7、C21 V1.3、核对表§15补记、矩阵V4.5内容项。
- 版本联动：207处引用，脚本`tools/b_merge_tools/verlink.py`（严格规则：版本号须是文件名后的第一个版本记号），独立核对脚本`tools/b_merge_tools/verlink_check.py`逐条配对通过（证据`verification_reports/b_merge_batch_evidence/version_linkage/`，可用`verlink_check.py . 8b2b259~1 8b2b259 contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:4`复现），负对照（人为改错1处）恰好报出1处。第一次宽松匹配会误改6处，已回滚重做，记入报告。
- 新发现并处理：BMI-058（C10私有discard扇出）、BMI-064（C13 local_empty消费关系）、C07 F-039按RTL判定（`o_control_valid`只观测）。
- 二级清单`POST_TAPEOUT_DOC_CLEANUP_LIST.md`新建，9条。
- 别名表的内容项全部移到阶段3（与编号治理一起做，只升一次版）。
- 基线回归：S1可编程校准器单元TB在2019.2下xelab约22分钟（2.7 GB），最终PASS；其余正常。

### 条目7（2026-10-09）：旁观会话转达的两点提醒（已处理）

- 旧会话（只读旁观核查）转达用户两点：① 阶段4对矩阵与别名表锚点的正式改写须等阶段3（TB标签改名与别名表映射）完成后再落盘，检查脚本与追溯可先做——与本会话计划一致；② 版本联动脚本须入库——已将`verlink.py`、`verlink_check.py`放入`tools/b_merge_tools/`（`aec4b14`），`verlink_check.py`改为可按两个提交复现，干跑记录与负对照记录入`verification_reports/b_merge_batch_evidence/version_linkage/`。最终报告将指明这些位置。
- 旧会话也在独立核对基线回归；本会话照常核对。
- 阶段3准备：扫描器在`tools/id_governance_scan/`，重扫37处已复读（只有TB FSC-14属新的同号不同义，其余36处是TB轮加严、含义不变），负对照恰好多报2处；TB改名脚本已备好、未执行（等基线核对）。本地名：SCHT-n、CLRBLK/EPICLS/WDIDLE/EPI2ND、DCRT-n、CAL-ODL、FORK-HOLD、AUTOABT-QUIET（全仓grep未占用）。
- 阶段4准备：`tools/b_merge_tools/anchor_check.py`首跑：阶段2写入合同的39个符号锚点全部能在RTL中找到；4处节号引用需消歧；矩阵与别名表旧行号锚点共7409处待转换（矩阵6662、别名表747）。

### 条目8（2026-10-09）：误提交的.pyc已移出版本库

- 提交`9e932d6`误带入`tools/id_governance_scan/__pycache__/scan_tb_labels_lib.cpython-38.pyc`（运行扫描器时由Python生成）。本提交用`git rm --cached`将其移出版本库，不改历史、不force push。
- 今后提交一律按路径逐个`git add`，提交前用`git status`确认暂存区没有`__pycache__`。`.gitignore`不在本批次授权范围内，不改；最终报告中提一句建议。

### 条目9（2026-10-09）：阶段5脚本开发与试跑（未写入矩阵）

- 应旁观会话转达的用户要求，利用基线回归等待时间开发阶段5脚本，只开发和试跑：
  - `tools/b_merge_tools/manifest_digest.py`（F-045）：在`7a8eabf`与`3f4673d`上都复现§12.4a的26行清单，3个相符（C04、C05、C21）、23个不符；负对照（导出副本中C04改1字节）恰好多报C04一处；`--write`往返后26/26相符。分支HEAD当前0相符（预期，正式重算在阶段5最后）。
  - `tools/cross_reference_tools/reconcile_acceptance_ids.py`：只改路径（`contracts/`、`tools/cross_reference_tools/`）并排除`.claude/`，ID正则与分类逻辑不变。试跑341个ID：A 267、B 22、B2 35、D 1、E_STALE 16（基线与HEAD相同）。B2中22个是TB文件头修订记录切出的伪ID（已知误报清单），13个是RTL中真实存在、别名表缺行的`@satisfies`标签（AMI-24、FSC-03/17/31/32/38/46/49/50、MGR-11、SSW-22/34/38），在阶段3补别名表行。已提交的`reconciliation_report.*`未刷新。
  - 证据：`verification_reports/b_merge_batch_evidence/stage5_dryrun/`。

### 条目10（2026-10-09 12:31）：中断点（会话额度用尽）

- 基线回归仍在跑（6路后台）。已完成：芯片20/0；系统TB 6份全部0 FAIL；模块级18份PASS、**1份FAIL：xelab返回139（疑似并行负载下xelab崩溃/内存不足，xsim未运行）**，须单独重跑该TB确认是环境问题再下结论；对不上参考值前不做阶段3改TB标签。
- 阶段4准备：`tools/b_merge_tools/anchor_inventory.py`、`anchor_resolve.py`已入库（`35aec60`），只试跑。基线7a8eabf上9702个旧锚点：约9000个自动解析（含by-name与TB标签），约390个需人工（RTL unresolved 153、裸`:N`歧义176+未解析22、weak 25、symbol-gone 4、合同6）；4103个的写入时点为2026-09-28导入提交。尚未定：带日期叙述中锚点的转换口径。
- 下一步：① 确认xelab 139的TB并单独重跑；② 基线核对通过后执行阶段3（`scratchpad/tb_rename.py`需先移入`tools/b_merge_tools/`）、别名表映射（含13个真实缺行标签）；③ 阶段4改写。

### 条目11（2026-10-09 15:40）：本机基线中断与FIR崩溃；回归整套改到回归机（用户决定）

（本条由旁观会话应用户要求写入。）
- **中断**：约14:22 Claude进程退出，后台仿真被一并结束。系统TB完成16/20，全部rc=0、0 FAIL、`$finish`各1次，PASS 985行。未完成：`baseline_cross`、`robustness_corner_waveforms`（中断），`startup_idac_calibration`、`adc_anomaly`（未开始）。芯片20/0。模块级27/28。
- **FIR崩溃不是负载问题**：`tb_ppg_coarse_detection_fir`的xelab在"Completed static elaboration"后崩溃（`EXCEPTION_ACCESS_VIOLATION`）。在无其它负载时单独重跑两次（默认设置；`-mt off`），都在同一位置崩溃，判定为Vivado 2019.2的确定性工具缺陷。没有改RTL/TB。
- **用户决定**：基线和终版回归整套改在另一台性能更好的机器（回归机）上，用Vivado 2022.2运行。
  - 本机结果只作参考：`verification_reports/b_merge_batch_evidence/baseline_7a8eabf_vivado2019.2_partial/`（`24d0b8d`）。
  - 运行与回传说明：`verification_reports/b_merge_batch_evidence/REGRESSION_RUN_REQUEST.md`，分组与条目2相同。
- **新工具**：`tools/b_merge_tools/regression_evidence.py`。
  - `export`：逐TB生成排序PASS行、`$finish`行和`index.tsv`。
  - `compare`：逐行列出PASS差异；`$finish`有差异或TB缺失时退出码为1。
  - 负对照：改1行PASS、1行`$finish`，恰好报出这2处。
  - 自比对：45个TB全部SAME，退出码0。

### 条目12（2026-10-09）：等待回归机期间的工作（不涉及TB改名）

- **§3.9 RTL注释（BMI-155，`f8986b3`）**：`ppg_amb_recheck_scheduler.v`中点名的3处注释，按"阶段沿用本阶段内帧完成"的语义改写。去掉注释后与`7a8eabf`逐字节相同。skill的deliverable gate在基线和分支上都是0 error / 0 strict warning；skill的comment-only校验通过。负对照：往代码里改1个字符，比对随即报出。证据在`b_merge_batch_evidence/rtl_comment_proof/`。
- **C08节号订正（`be82819`）**：阶段2新增的"启动搜索空闲边界"小节编成了§8.2.3，与已有的§8.2.3~8.2.5重号（anchor_check报section-ambiguous）。现改为§8.2.6，同步改了5处引用。
- **anchor_check负对照（BMI-150，`70fb907`）**：注入5处错误，恰好多报5处，原有报错没有一处消失。支持TB标签锚点（`` `tb_x.v` `"label"` ``）后又补做一次负对照（`fd348d2`）。证据在`anchor_check_negctl/`。
- **别名表映射行（`fd348d2`）**：新增"B合同合并批次新增映射"一节，包括：13个缺行标签中不依赖TB改名的部分（AMI-24、MGR-11、SSW-22/34/38）；SSW-53（L-6）；OVL-01~17与OPTC-01/02，各对应C13/C21的规则或RTL行为，对不上的标"仅TB检查"；JNT（联合TB说明§11/§5.3）；RAW↔RGC；三轮新增TB本地标签；SYS-*；IDC2/CIS/AV4/CF4族级登记。另订正P05行（去掉SUP06A）和SID-11行（F-050）。46个符号、15个`@satisfies`、1个TB标签全部通过anchor_check。
- **阶段3别名草稿（BMI-133，`affd3e3`）**：`tools/b_merge_tools/make_alias_draft_renamed.py`由ID治理§5.2生成57行FSC对照（合同FSC-nn ↔ TB本地SCHT-n），以及SUP/DCR/SSW-18/AMI-13/LFA-11各行。这些行只在TB改名后才成立，未写入别名表，与TB改名同一次提交。
- **阶段4旧→新对照表（BMI-151，本次提交）**：
  - 基线`7a8eabf`上共9702个旧锚点，全部已定。自动转换7612；人工判定后转换199；带日期叙述按历史保留1473；删除线保留410；其它历史1；非锚点4；仓库外文档3；失效锚点0。
  - 人工判定共207条（条目10时约390条，解析器改进后减少）。逐条写在`tools/b_merge_tools/anchor_manual_decisions.tsv`，每条附理由，由`anchor_manual_seed.py`生成，由`anchor_mapping.py`汇总。
  - 带日期叙述的口径（条目10未定项）现定为：同一格内锚点之前出现日期的，按历史保留原文；无日期的一律转换。
  - 7811条新文本逐条用anchor_check检查，0 error。另有210条"Cxx 文件头"不在检查范围，已人工抽查。
  - 证据在`b_merge_batch_evidence/anchor_conversion/`（README、TSV、汇总）。**未写入矩阵和别名表。**
- 仍是旧写法的出处：alias第118行的`MATRIX.md §9.2.2`（该节不存在），写入时一并处理。

### 条目13（2026-10-09）：基线核对通过；阶段3完成

- **基线**：回归机证据`ea60432`（i5-10400，Vivado Simulator v2022.2）位于`baseline_7a8eabf/`。旁观会话从raw/的49个xsim.log独立重算过，本会话又核对了`index.tsv`。结果：49个TB全部rc=0、verdict PASS、`$finish`各1次；系统20/20、PASS 1250行，芯片20/0，模块级28/28（含FIR），与参考值一致。旁观会话另做了交叉验证：本机2019.2已跑完的44个TB，PASS行和`$finish`与2022.2完全相同。
- **TB标签改名（BMI-103、140~144、146）**：由`tools/b_merge_tools/tb_rename.py`执行。共6个TB，只改字符串和文件头修订记录（LFA TB另有2处注释同步）；`tools/run_unit_tb_regression.sh`的4条横幅正则同步改了。新标签名在仓库其它文件中无撞号。
  - `strip_compare --strings 7a8eabf`：6个TB全部IDENTICAL。负对照：改1个代码token报DIFFERENT，恢复后IDENTICAL。`strip_compare.py`新增一条规则：只含空白的行不参与比较（新增整行注释去掉后会留下空行）；加规则后f8986b3的RTL证明仍为IDENTICAL。
  - deliverable gate：这些TB在基线上已有715个error（不是strict交付物）。改后按文件和规则逐项相同，即无新增发现（`tools/b_merge_tools/gate_compare.py`）。
  - 证据在`b_merge_batch_evidence/tb_rename_proof/`。
- **别名表（BMI-133）**：`alias_draft_renamed.md`两小节已写入别名表，包括57行FSC↔SCHT对照，以及SUP/DCR/SSW-18/AMI-13/LFA-11各行。旧行LFA-11、P03、P09、N06原先引用改名前的标签，已在原文旁注明新名。anchor_check在写入前后都是747个报错（746个旧行号锚点加第118行`§9.2.2`），新写入的行没有报错。
- 未做：BMI-145（区间横幅），视重扫结论再定；BMI-105（C25中FSC/SUP/RRC编号引用的核对），放在阶段4一并处理。
