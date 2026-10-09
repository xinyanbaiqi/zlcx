# B合同合并批次进度（B_MERGE_BATCH_PROGRESS）

> 依据：`verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`（下称"交接书"）。
> 用途：交接书§1要求的进度保存文件。会话被压缩或中断后，从本文件恢复。
> 分支：`b-merge-batch`，从main `a1ba482` 切出。`a1ba482`与基线`7a8eabf`的差异只有两份新增报告（交接书与F9核查报告），RTL/TB逐字节相同，已用`git diff --stat 7a8eabf a1ba482`核实。

---

## 当前状态

- **已完成**：克隆仓库、切出分支、首次回复、用户答复落定（条目1）；在仓库根目录重开会话并加载skill（条目2）；阶段0基线回归已在后台启动（条目2）。
- **当前项**：阶段2已完成（全部一级合同改写、矩阵内容项、版本联动、二级清单）。基线回归仍在后台运行。
- **下一步**：① 基线回归跑完后按交接书§6.8核对参考值；**若不符，阶段3改TB标签之前停下报告**；② 阶段3：提取IDG附录A扫描器，对`2a90a69`建基线`tb_sites.json`、对`7a8eabf`重扫，`rescan_diff.py`逐条复读；③ 别名表内容项（P05、SID-11、FSC/SUP/DCR/RAW↔RGC/JNT/OVL/OPTC/L6等映射）随阶段3做。
- **未决问题**：无。

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
- 版本联动：207处引用，脚本`scratchpad/verlink.py`（严格规则：版本号须是文件名后的第一个版本记号），独立核对脚本`verlink_check.py`逐条配对通过，负对照（人为改错1处）恰好报出1处。第一次宽松匹配会误改6处，已回滚重做，记入报告。
- 新发现并处理：BMI-058（C10私有discard扇出）、BMI-064（C13 local_empty消费关系）、C07 F-039按RTL判定（`o_control_valid`只观测）。
- 二级清单`POST_TAPEOUT_DOC_CLEANUP_LIST.md`新建，9条。
- 别名表的内容项全部移到阶段3（与编号治理一起做，只升一次版）。
- 基线回归：S1可编程校准器单元TB在2019.2下xelab约22分钟（2.7 GB），最终PASS；其余正常。
