# V9/V16进展

- 日期：2026-10-10；远程：`https://github.com/xinyanbaiqi/zlcx.git`；工作分支：`v9-v16`，从main `bb3c1aba12474638fcbefd9b1f324ecfc7524544`创建，已执行 `git fetch origin`。
- V9合同语义及V16参考基线：`origin/b-merge-batch` = `66bebdfabe9e1cb173c34a0ce44e48ba4230398d`。
- 原项目目录仅有未跟踪的V1报告和无remote的空Git仓库，且Windows环境不允许在原目录创建普通目录/写Git文件（返回No such file）。原目录未改动；在本次任务另一个获准写入目录建立了独立检出。本报告不记录本机账号或绝对私有路径。
- 边界：既有RTL/TB/合同/回归脚本不修改；新增交付仅在 `verification_reports/v9_v16/`。使用仓库erie-verilog-generator，保留formatter限制，未以临时解析器替代。

| 子任务 | 状态 | 证据 / 剩余 |
| --- | --- | --- |
| V9 | 已完成只读清点 | 49份TB+2份头文件+3入口；32条机制级清点（高7/中18/低7），历史已修1条。正文、逐文件表、SHA256/AST摘要、原文候选及可复用收集脚本。没有仿真或修复。 |
| V16 | 已通过WSL实际补跑，部分未闭合 | Icarus/vvp 11.0可用，VPI观察器已编译加载；49个TB以g2001编译成功，36个正常结束、当前0个限时中断、13个只编译。29个严格MATCH，5个参考提取口径已解释；芯片结束时间早1000ns和control_top累计结果计数偏移1待定位；未确认RTL竞争，不声称全设计无竞争。 |

V9本地提交：`dcd08e5`。V16另一次独立提交；最新提交号以Git历史为准，避免为了把本commit哈希写入本commit而递归改文件。

推送授权：2026-10-10统筹已明确同意把本分支的新增审计报告与脚本推送到 `xinyanbaiqi/zlcx` 的 `v9-v16`，并要求新增范围、体积、敏感信息自查。此前自动审批未识别到明确上传授权，因此当时只提交本地；取得本次授权后完成自查，以显式分支refspec只推 `v9-v16`。实际推送结果及最终提交号以Git远程引用和交付回复为准。

交付文件（均新增于本目录）：

- `V9_TB_TOLERANCE_INVENTORY.md`、`V9_FILE_REVIEW.tsv`、`V9_SOURCE_COVERAGE.json`、`V9_SCAN_CANDIDATES.tsv`；
- `V16_IVERILOG_CROSSCHECK_TRIAL.md`、`V16_TRIAL_RESULTS.json`；
- `scripts/v9_collect_evidence.py`、`scripts/v16_crosscheck.py`、`scripts/v16_finish_probe.c`；
- `PROGRESS.md`、`.gitignore`（忽略试跑目录和脚本缓存）。

变更边界检查：所有既有跟踪文件无改动；V9全部51份源码SHA256保持不变，V9条目/风险计数与逐文件表一致；V16结果49行与20系统/1芯片/28模块清单一致，finish参考均可统一为fs。技能预检产生的新增pycache已清理；试跑临时目录不入库。

环境调查更正（2026-10-10用户追问后）：默认沙箱的winget/WSL访问受限被前次过早当作环境不足。提升权限发现Debian WSL，下载并在忽略的运行目录解包Icarus 11、TCC及C头文件，未安装系统包或改系统PATH。真实运行和比较结果已替换此前“49未跑”快照。系统级性能较慢，限时中断只记未完成，不当作RTL错误或正常finish。

长预算续跑（2026-10-10用户要求）：原90秒中断的control_top、input_light_static_matrix、owner_identity_backpressure，使用每项14400秒（4小时）预算从原始激励重新完整运行；三项均正常结束、无FAIL、finish与xsim一致。后两项的唯一PASS差异是参考清单未收JNT总结行，与原始xsim同口径逐行一致；control_top的TOP-01累计计数字段32/33与33/34不同，严格DIFF保留，不采用“允许差1”。详情见V16报告D05/D06。

推送前整理：候选TSV保留每个候选的位置、类别和单行原文，去掉重复的相邻多行上下文；原文完整内容从对应基线源码读取。文件检查不含账号凭据、令牌、邮箱或本机绝对路径；没有纳入仿真日志、波形或编译产物。
