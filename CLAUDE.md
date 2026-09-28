# CLAUDE.md

## 强制要求：本仓库的一切Verilog相关工作必须使用 erie-verilog-generator skill

本仓库是PPG芯片数字部分的RTL/testbench/合同交付物。**任何在本仓库内进行的Verilog
生成、既有RTL分析、验证/修复、独立复核、静态lint、testbench编写、格式化或质量
审查工作，必须先加载并使用 `erie-verilog-generator` 这个skill**，不得用其它临时
写的脚本或自建流程代替——本项目所有RTL都遵循该skill定义的`erie_strict`风格规范
（双语文件头、ANSI端口声明、命名前缀约定、区块注释规则等），不经过这个skill的
生成/复核流程，产出的内容会不符合本仓库已有代码的风格与质量门禁，也无法通过
`verilog_generated_deliverable_gate`这类既有质量检查。

skill本体位于 `.claude/skills/erie-verilog-generator/`（Apache-2.0授权，`LICENSE`
在skill目录内），Claude Code会话在本仓库根目录打开时应能自动发现并加载。

## 项目背景

本仓库是从更大的原始开发工作树整理出的当前态快照（RTL+testbench+合同+验证报告），
不含逐日session交接文档、任务分派简报、构建产物。完整目录结构与已完成/待办工作
说明见 [README.md](README.md)。
