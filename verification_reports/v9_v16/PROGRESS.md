# V9/V16进展

- 日期：2026-10-10；远程：`https://github.com/xinyanbaiqi/zlcx.git`；工作分支：`v9-v16`，从main `bb3c1aba12474638fcbefd9b1f324ecfc7524544`创建，已执行 `git fetch origin`。
- V9合同语义及V16参考基线：`origin/b-merge-batch` = `66bebdfabe9e1cb173c34a0ce44e48ba4230398d`。
- 原项目目录仅有未跟踪的V1报告和无remote的空Git仓库，且Windows环境不允许在Documents目录创建普通目录/写Git文件（返回No such file）。原目录未改动。实际独立检出位于本次任务获准写入目录：`C:/Users/DAWN/.codex/visualizations/2026/10/10/01a123bb-a6f4-70d0-bcee-3c6128be5f05/zlcx`。
- 边界：既有RTL/TB/合同/回归脚本不修改；新增交付仅在 `verification_reports/v9_v16/`。使用仓库erie-verilog-generator，保留formatter限制，未以临时解析器替代。

| 子任务 | 状态 | 证据 / 剩余 |
| --- | --- | --- |
| V9 | 已完成只读清点 | 49份TB+2份头文件+3入口；32条机制级清点（高7/中18/低7），历史已修1条。正文、逐文件表、SHA256/AST摘要、原文候选及可复用收集脚本。没有仿真或修复。 |
| V16 | 已完成环境核对，实际试跑跳过 | 无可用iverilog/vvp；winget无法启动。49个TB逐项未跑，0个对比完成。git archive内存依赖/参考核对、重跑脚本计划模式与无工具失败退出已验证；动态编译/仿真/VPI未验证。 |

V9本地提交：`dcd08e5`。V16另一次独立提交；最新提交号以Git历史为准，避免为了把本commit哈希写入本commit而递归改文件。

推送状态：**尚未推送**。自动审批拒绝了 `git commit ...; git push -u origin v9-v16` 组合操作，理由是没有识别到 trusted user messages 对这些仓库衍生报告上传GitHub目的地的明确授权。随后只执行获准的本地commit。没有绕过拒绝；待用户明确批准把本分支审计报告推到 `xinyanbaiqi/zlcx` 的 `v9-v16` 后再执行push，不推其他分支。

交付文件（均新增于本目录）：

- `V9_TB_TOLERANCE_INVENTORY.md`、`V9_FILE_REVIEW.tsv`、`V9_SOURCE_COVERAGE.json`、`V9_SCAN_CANDIDATES.tsv`；
- `V16_IVERILOG_CROSSCHECK_TRIAL.md`、`V16_TRIAL_RESULTS.json`；
- `scripts/v9_collect_evidence.py`、`scripts/v16_crosscheck.py`、`scripts/v16_finish_probe.c`；
- `PROGRESS.md`、`.gitignore`（忽略试跑目录和脚本缓存）。

变更边界检查：所有既有跟踪文件无改动；V9全部51份源码SHA256保持不变，V9条目/风险计数与逐文件表一致；V16结果49行与20系统/1芯片/28模块清单一致，finish参考均可统一为fs。技能预检产生的新增pycache已清理；试跑临时目录不入库。
