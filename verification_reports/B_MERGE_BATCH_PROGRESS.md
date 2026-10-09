# B合同合并批次进度（B_MERGE_BATCH_PROGRESS）

> 依据：`verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`（下称"交接书"）。
> 用途：交接书§1要求的进度保存文件。会话被压缩或中断后，从本文件恢复。
> 分支：`b-merge-batch`，从main `a1ba482` 切出。`a1ba482`与基线`7a8eabf`的差异只有两份新增报告（交接书与F9核查报告），RTL/TB逐字节相同，已用`git diff --stat 7a8eabf a1ba482`核实。

---

## 当前状态

- **已完成**：克隆仓库、切出分支、首次回复（理解/计划/阻塞问题）、用户答复全部落定（见条目1）。
- **当前项**：等待用户在仓库根目录 `D:\ppg_zlcx\zlcx` 重开会话（让CLAUDE.md与skill自动加载）。
- **下一步**：重开会话后读交接书，然后开始阶段0：设定`VIVADO_BIN=/d/vivado/2019.2/bin`，用`git -c core.autocrlf=false archive 7a8eabf | tar -x`导出到仓库外独立目录，在后台跑基线回归（系统TB 20份分3~4组，芯片，模块级`-g all`），同时开始阶段1。
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
