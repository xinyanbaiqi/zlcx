# V9/V16进展

- 日期：2026-10-10；远程：`https://github.com/xinyanbaiqi/zlcx.git`；工作分支：`v9-v16`，从main `bb3c1aba12474638fcbefd9b1f324ecfc7524544`创建，已执行 `git fetch origin`。
- V9合同语义及V16参考基线：`origin/b-merge-batch` = `66bebdfabe9e1cb173c34a0ce44e48ba4230398d`。
- 原项目目录仅有未跟踪的V1报告和无remote的空Git仓库，且Windows环境不允许在Documents目录创建普通目录/写Git文件（返回No such file）。原目录未改动。实际独立检出位于本次任务获准写入目录：`C:/Users/DAWN/.codex/visualizations/2026/10/10/01a123bb-a6f4-70d0-bcee-3c6128be5f05/zlcx`。
- 边界：既有RTL/TB/合同/回归脚本不修改；新增交付仅在 `verification_reports/v9_v16/`。使用仓库erie-verilog-generator，保留formatter限制，未以临时解析器替代。

| 子任务 | 状态 | 证据 / 剩余 |
| --- | --- | --- |
| V9 | 已完成只读清点 | 49份TB+2份头文件+3入口；32条机制级清点（高7/中18/低7），历史已修1条。正文、逐文件表、SHA256/AST摘要、原文候选及可复用收集脚本。没有仿真或修复。 |
| V16 | 环境核对中 | 无可用iverilog/vvp；winget无法启动。按可选任务记录跳过，不宣称任何双仿真器一致或不存在RTL竞争。 |

每子任务完成后独立commit/push，仅推 `v9-v16`。提交号以Git历史为准，避免为了把本commit哈希写入本commit而递归改文件。
