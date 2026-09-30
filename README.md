# PPG Chip Digital Design

PPG（光电容积脉搏波）芯片数字部分的RTL、testbench与合同文档，从长期开发工作目录中整理而来，只保留当前正确、必要的交付物，剔除迭代过程中的构建产物（xsim快照、综合报告、deliverable gate中间版本等）。

本仓库仅作备份与展示用途，不授权使用，详见 [LICENSE](LICENSE)。

**在本仓库内进行任何Verilog相关工作（生成/分析/验证/复核/lint等），必须使用
`.claude/skills/erie-verilog-generator/` 这个skill，见 [CLAUDE.md](CLAUDE.md)。**

## 目录结构

```
.claude/skills/erie-verilog-generator/   本仓库Verilog工作的强制skill（Apache-2.0，见其自带LICENSE）
rtl/                        每个功能模块一个子目录，包含该模块当前的RTL、testbench、约束/filelist与回归脚本
contracts/                  各模块接口合同、系统级合同闭合矩阵、验收ID别名映射表
verification_reports/       独立复核 / gap修复 / 阶段性关闭报告——记录验证逻辑与结论，不含中间过程
tools/                      交叉引用核对工具（cross_reference_tools）
legacy/                     已退役的testbench与脚本（原样保留，见 legacy/README.md）
```

### rtl/

每个子目录对应一个功能模块（IP block），命名与模块名一致，例如 `rtl/ppg_control_top/`。目录内：

- `<module>.v` —— 该模块当前的可综合RTL
- `tb_<module>*.v` —— 该模块的一个或多个testbench（部分模块有多份针对不同场景的testbench）
- `*.sdc` / `*.f` —— 约束文件与仿真filelist（如存在）
- `run_*.sh` / `run_*.ps1` —— 回归/仿真驱动脚本（如存在）

`ppg_control_top/` 是数字控制链的顶层，`ppg_chip_digital_top/` 是glue顶层（集成SPI、P2S等）。系统级内容在 `contracts/` 与 `verification_reports/` 里。原来的 `rtl/ppg_system_integration/`（一份scheduler+SSW+AMI三模块联合testbench）已于2026-09-30退役，移入 `legacy/rtl/ppg_system_integration/`，其职责由 `ppg_control_top/` 的19-TB主回归继承。

### contracts/

`PPG_CONTRACT_CLOSURE_MATRIX.md` 是系统级验收ID的权威闭合状态矩阵；`PPG_ALIAS_MAPPING_TABLE.md` 记录每个验收ID对应的testbench场景名与RTL锚点位置。其余为各模块接口合同（`*_INTERFACE_CONTRACT.md` / `*_CONTRACT.md`）与两份模块语义合同。

### verification_reports/

记录"工作线D"独立复核方法论逐家族执行的过程与结论（每份报告对应一批验收ID），以及若干次gap修复、阶段性关闭报告。这些文档说明了验证逻辑本身（为什么认为某项已验证/未验证），不是简单的PASS/FAIL罗列。

### tools/

`cross_reference_tools/` 下是用于CDC（跨时钟域）审计、验收ID核对、回归新鲜度检查、文字滞后扫描的独立Python工具，附带各自最近一次真实运行产出的报告。原来的联合场景批量回归脚本 `run_v1_3_scenarios.ps1`、`aggregate_v1_3_results.py/.ps1` 只服务于已退役的三模块联合testbench，已随它一起移入 `legacy/tools/`。

### legacy/

已退役、不再参与回归的testbench与脚本，用 `git mv` 原样移入，保留原来的相对路径（`legacy/rtl/...`、`legacy/tools/...`）。每个文件的退役原因见 [legacy/README.md](legacy/README.md)。

## SAR9/SAR15 DC综合入口的版本判断（已解决）

`ppg_timing_sar9/`、`ppg_timing_sar15/` 各自内部都有两套DC综合脚本+约束（不带后缀 vs 带`_new`后缀），外加各自顶层还有一份内容雷同的独立`ppg_timing_sar9_synthesis/`、`ppg_timing_sar15_synthesis/`目录。逐项对比后判定：

- **权威版本是模块目录内部、不带`_new`后缀的一套**（即`rtl/ppg_timing_sar9/`、`rtl/ppg_timing_sar15/`下的`dc_flow.tcl`/`dc_setup.tcl`/`check_tcl_syntax.tcl`/`*.sdc`，含base和`_3200hz`两个时钟档），本次已经收录进对应模块目录。判断依据：
  1. `ppg_timing_sar9/README.md`原文明确写道"活动综合入口位于`ppg_timing_sar9_synthesis/`……根目录的`ppg_timing_sar9.sdc`和`legacy_root_script_copies/dc_flow.tcl`是内容相同的兼容副本"——指的正是模块目录内部这一套；
  2. `dc_setup.tcl`里的`RTL_PATH`相对路径实测可解析到真实存在的RTL文件（`$SYN_PATH/..`指向`ppg_timing_sar9/`本身），而`dc_setup_new.tcl`的`RTL_PATH`指向`$SYN_PATH/../rtl`，这个`rtl/`子目录在磁盘上并不存在，该脚本实际跑不通；
  3. `_new.v`（如`ppg_timing_sar9_new.v`）与主RTL逐行diff只有模块名/头部注释不同，功能代码完全一致，且没有任何同名testbench覆盖它——是一次未完成的改名实验，不是真实的功能修订；
  4. `ppg_timing_3200hz_validation/tb_ppg_timing_3200hz.v`联合测试平台引用的是不带后缀的`_3200hz.v`，进一步确认其为受测的正式版本。
- 顶层独立的`ppg_timing_sar9_synthesis/`、`ppg_timing_sar15_synthesis/`目录未被任何README提及为canonical，且与模块内部版本内容重复（sdc内容仅差1行、tcl完全相同），判定为整理前遗留的重复目录，未收录。
- `_new`/`_v1`/`_6667hz_v1`等RTL变体（`ppg_timing_sar9_new.v`、`ppg_timing_sar15_new.v`、`ppg_timing_sar15_v1.v`、`ppg_timing_sar15_6667hz_v1.v`等）同样没有对应命名的testbench覆盖，判定为未完成/被取代的候选，未收录；仅`ppg_timing_sar9.v`/`ppg_timing_sar9_3200hz.v`/`ppg_timing_sar15.v`/`ppg_timing_sar15_3200hz.v`（均有对应testbench）进入本仓库。
- `ppg_timing_optical_modes/`未纳入：其内容以`.rpt`综合报告和`.str`（Vivado进程状态文件，纯运行时产物）为主，混有少量`synth_*.tcl`/`run_*.tcl`脚本但没有独立README或其它文档说明其权威性，且未见任何testbench引用，判断价值有限，未收录。

## 已知未纳入的内容（如实说明）

以下内容不属于核心交付物，本次整理未纳入，如需要请从原工作目录单独确认后补充：

- 归档目录（原 `_archive_*`）、`legacy_ppg_reference/`（非本项目设计本身的参考RTL）、`ppg_system_integration/baselines/`（一份历史快照）——均为历史/参考材料，不是当前交付物。
- 逐日session交接文档（`HANDOFF_*`/`PPG_SESSION_HANDOFF_*`）与任务分派简报（`TASKBRIEF_*`）——是对话协作过程产物，不是工程交付物。
