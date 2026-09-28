# 流片前最终确认指南

> 本文档创建于2026-09-15，是"PPG流片就绪整合验证方案"全部四阶段（Stage 1-4）+ Stage 3
> Item 4a/4b完成后，专为下一轮"流片前最终确认"审阅准备的入口文档。它不重复矩阵/方案文件的
> 实质内容，只负责指路——真实结论和证据都在下面点名的文件里，不要只信本文档的摘要，去开
> 原始文件核对。

## 从这里开始看

1. **`sprightly-wobbling-wadler.md`**（`C:\Users\d\.claude\plans\sprightly-wobbling-wadler.md`）
   ——完整的Stage 1-4执行记录，从Stage 1的xsim双工具确认到Stage 4的最终收尾，含每一步的
   真实PASS/FAIL计数。**先看文件末尾的Status区最后几条dated条目**，那是最新、最权威的
   收口总结，不用从头读全文。
2. **`ppg-item4b-cdc-ledger-plan.md`**（同目录）——Stage 3 Item 4b（项目级CDC三分类机器
   可核对台账）独立的四阶段建设记录，`sprightly-wobbling-wadler.md`的Stage 3 Item 4b
   条目只是摘要，完整过程在这份文件里。
3. **`ppg_system_integration/PPG_CONTRACT_CLOSURE_MATRIX.md`**——项目唯一权威的合同闭环
   判定矩阵。重点看新增的**§9.2**（Item 4b机器可核对CDC台账：452条寄存器域标注、3个白名单
   IP的真实实例清单、7个外部异步源信号判定、全项目唯一1处手搓跨域机制及其Class 3(a)安全
   判定）。

## 最新真实回归状态（2026-09-14 Stage 4重跑，非历史记录）

| 回归 | 结果 |
|---|---|
| `ppg_control_top` 19-TB xsim回归 | 19/19 PASS，0 FAIL |
| `ppg_control_top` SMOKE复核 | 56 PASS，0 FAIL |
| `ppg_chip_digital_top`（TC1-TC6） | 6/6 PASS，0 FAIL，`$finish`=2558250ns |
| 核对脚本`reconcile_acceptance_ids.py` | `A_CONSISTENT=149, B_TAG_MISSING=21, D_PENDING_KNOWN=1, E_STALE_MATRIX_TEXT=13`，`D2_NO_STATUS_FOUND`归零 |
| 看门狗`regression_freshness_watchdog.py` | 24/24 FRESH，0 STALE |
| Item 4b全项目CDC扫描 | 全真实可达层级仅1处手搓跨域机制，已确认Class 3(a)安全 |

真实日志/报告文件路径见`sprightly-wobbling-wadler.md`Stage 4收尾条目和
`ppg_system_integration/cross_reference_tools/`下各工具的`.json`/`.md`报告。

## 这份方案证明了什么、没证明什么（务必先读这一段）

**证明了**：数字RTL在事件驱动仿真下的功能正确性（iverilog+Vivado xsim双工具）、文档与RTL
的一致性（核对脚本）、跨时钟域结构正确性（CDC三分类审计，Item 4a+4b）、全项目latch/case
完整性（Stage 3 Item 1）。

**没有证明、也不试图证明**：
- **门级静态时序分析（STA，跨PVT角）**——功能仿真用理想时序模型，综合、布局布线之后能否
  满足目标频率的setup/hold，是这份方案的工具链回答不了的问题，需要独立的STA流程。
- **数模混合后仿真**——这是用户自己独立的、必须做的后续步骤，这份方案只是给它准备一个
  可信的起点，不是替代。

## 真实存在、故意没处理的范围

- **矩阵系统级`NOT_CLOSED`判定**——矩阵自己的设计是fail-closed：不会因为任何数量的
  子项核对/PASS结论自动翻转，只能靠拿到全部证据（含物理signoff）的人主动做一次产品级
  声明。这是**唯一真正意义上还开放的线索**，是用户自己的产品决定，不归这份方案管，不要
  被误读成"还有代码层面的事没做完"。
- D01的`Acceptance-D01-01`、N08、C11/C14/C15 discard-broadcast缺口——这几项在方案自己
  2026-09-07/08就已经点名"不归这份方案管"，且实际上已经被其他工作关闭（详见
  `sprightly-wobbling-wadler.md`的Notes-on-scope一节），不是遗留缺口。

## 这次整理动了什么（供审阅者知情，不是审阅对象本身）

2026-09-15，为方便本次审阅，对工作目录做了一次纯文件整理（不涉及任何RTL/TB语义改动）：

- 7个功能目录下新增`_formatter_candidates_archive/`子文件夹，归档了16个已被Item 4b
  Phase 1真实核实为non-canonical的历史格式化候选/baseline文件（原样搬入，未改内容）。
- `ppg_system_integration/cross_reference_tools/`下归档了6个Stage 2批次工作期间的
  scratch文本导出到`_batch_scratch_exports_20260910/`（内容早已并入memory和矩阵正文）。
- 顶层孤立的`xvlog.log`残留移入既有归档目录`_archive_build_artifacts_20260831/`。
- `README.md`订正了`ppg_digital_shell`/`ppg_digital_esd_shell`两处过时描述（确认孤立，
  非"过渡中"）和一处已不存在目录（`workspace_tool_history/`）的过期引用。

完整整理依据见规划文件`C:\Users\d\.claude\plans\eventual-puzzling-perlis.md`。
真实RTL/TB/合同文件内容本身，这次整理**零改动**。
