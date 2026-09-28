# PPG Phase 7 — 最终"基础清洁"报告

生成时间：2026-09-06（对话C，Phase 7，汇总轨道A2与轨道B的独立产出）

本报告不做新的调查，只汇总两条已完成轨道的真实产物：

- 轨道A（对话A1 → A2）：双锚点标签约定 + 别名映射表 + 25项P/N与L01的穷尽核对 +
  `PPG_CONTRACT_CLOSURE_MATRIX.md` §13 自动交叉引用表。
- 轨道B（对话B，独立并行）：`ppg_control_top/` 下19个既有TB文件的 Vivado xsim 回归。

来源文件：
- [PPG_CONTRACT_CLOSURE_MATRIX.md §13](PPG_CONTRACT_CLOSURE_MATRIX.md)（Phase 4产物，2026-09-06T17:09:16快照）
- [PPG_PHASE6_XSIM_REGRESSION_REPORT_20260906.md](PPG_PHASE6_XSIM_REGRESSION_REPORT_20260906.md)（Phase 6产物）
- [PPG_ALIAS_MAPPING_TABLE.md](PPG_ALIAS_MAPPING_TABLE.md)（Phase 1a/1b/3累积产物）

## 1. 已定论清零部分（有锚点、有回归证据）

### 1.1 交叉引用侧（§13快照，184个验收ID分类）

| 分类 | 数量 | 状态 |
| --- | ---: | --- |
| A_CONSISTENT | 50 | 别名表映射+RTL `@satisfies`标签+矩阵文字三方一致 |
| B_TAG_MISSING | 53 | 证据链已确认，只是RTL标签本身尚未逐处打上（非证据缺口） |
| C_UNVERIFIED_CLOSED | 0 | 矩阵目前没有裸断言未经核实的CLOSED/PARTIAL声明 |

即103个验收ID（A+B）的证据链本身已经过真实核实，其中53个待补的只是标签动作，不是待补的证据。

### 1.2 具体已关闭批次

- **TOP-01~24**：全部24项CLOSED（Priority-1b，2026-09-02；TOP-06的动态切换半证据2026-09-05补齐）。
- **G-FP-01~07**：全部9个批次（0, 1-6, 7a/7b/7c, 8）CLOSED，2026-09-06完成§12.1/§12.12统一收口。
- **K01-K05**：全部CLOSED（2026-09-05），均为"语义已核实，卡在已关闭的G-FP台账"同款情况。
- **L01**：CLOSED（2026-09-06，Phase 3）——同K04一样，阻塞项"all-file legacy audit"即G-FP-04，已于Batch 0关闭。
- **P/N 25项中19项CLOSED**：P02, P03, P04, P05, P07(=LFA-08=TOP-22), P08, P09, P10, P11, P12,
  P14, P15, P17(=TOP-17), N02, N03, N04, N05, N06, N07（2026-09-06，Phase 3）。
  其中P03/P04/P05/P09/P10/N03/N06共7项的证据来自本项目第三种隐藏证据形态——
  `ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v` 独立module-level
  unit TB，本session用iverilog重新编译确认13/13 PASS（非双工具，已如实注明）。
- **Stage4/5 JNT/SID/LFA/OIB/PRC/RRC共107个ID**：Stage4/5阶段已用iverilog+xsim双工具跑通，
  Phase 1b对其中10~15个做了轻量抽查，确认引用的TB/PASS标记依然真实存在，抽查通过后批量接入
  别名映射表，未发现TOP-06式的"悄悄过期"情况。

### 1.3 回归侧（Phase 6, Vivado xsim）

19个既有TB文件（`ppg_control_top/`下）逐个跑 `xvlog → xelab → xsim`：

- 19/19 三个工具返回码均为0；
- 19/19 日志中FAIL/ERROR类关键字命中数为0；
- 19/19 确认跑到 `$finish called`，无一挂起或被杀；
- PASS断言合计 **1162条**；
- 对"mismatch/miscompare/timeout"类关键字命中做了人工抽查，确认均为TB有意构造的场景
  （如OIB-01的非阻塞诊断、TRK-09b的注入mismatch吸收、RRC-11的搜索耗尽fault），不是真实失败。

这证明的是"这19个TB在Vivado xsim下仍能编译、例化、无挂起地跑完并保持原有PASS结论"——是
**回归确认**，不是新增验证覆盖。

## 2. 诚实保留的开放项

### 2.1 D01 — PARTIAL

- 定义/接线锚点（12.13的9行target ledger）已由G-FP-01~07的真实per-hop证据覆盖，不再是空白。
- **`Acceptance-D01-01`（AMI-54/PWI-08/BSL-40/PWC-40）仍无TB**：需要一个真实场景——在
  一次事务进行中把 `i_peak_valley_config_valid` 拉低，确认AMI/PWI/C20/C22/C23四个消费者
  安全drain到各自idle/empty状态且不产生新的正式cross/peak/valley/fine-window事件。全仓库
  grep这4个ID，唯一命中是`ppg_precision_window_controller.v:28,55`的changelog注释，不是测试。
  这是**新建构造工作**，不是文档任务，2a调查时已作为PWI-08的旁注留下过同一个缺口。

### 2.2 P01 — PARTIAL

discard+reason编码facet证据充分（LFA-02a/LFA-02b），但"branch ID"身份字段和同拍
transfer-priority竞争facet仍无TB证据，未强行关闭。

### 2.3 P06/P13/N01/N08 — 已穷尽核对，确认无证据（EVIDENCE_PENDING，如实保留）

| ID | RTL锚点 | 缺口 |
| --- | --- | --- |
| P06 | `ppg_adc_measurement_idac_integration.v:460-461,1569-1577` | 18份TB从未在请求已接受后才拉低enable |
| P13 | `ppg_normal_transaction_fork.v:187-271` | 信号为AMI内部信号非顶层端口，18份TB从未层次化引用或独立反压验证 |
| N01 | PWI全链discard+local-empty RTL完整 | 最接近的两份TB自己PASS输出显式报告`detection_discard_events=0`，是vacuous pass |
| N08 | RTL匹配声明 | `o_detection_discard_identity_valid`从未被任何TB assert，比N01证据更弱 |

这4项不是"没查过"，是查过、证据真实缺失，按项目约定诚实标注，不现场补建TB。

### 2.4 交叉引用侧的两类待处理（不是证据缺口）

- **D2_NO_STATUS_FOUND（61项）**：别名表无映射、RTL无标签、脚本未在同一行找到状态词。多数是
  Stage5未点名的TRK/NRE/ILM/ADCN/ISE五个family（不在本次工作顺序字面范围内）以及JNT系列的
  字母后缀子ID（脚本已知局限，见§13.2）。这是别名表覆盖范围尚未扩展到的区域，不代表这些ID
  本身证据缺失——只是本轮工作没有把它们纳入。
- **E_STALE_MATRIX_TEXT（14项）**：别名表已有真实映射，但矩阵正文某些历史grouped段落
  （§11.2、§12.16等）仍写着EVIDENCE_PENDING/NOT_CLOSED的旧措辞。已在原地加注更正说明，
  但原文本身尚未逐条改写。

### 2.5 一个本报告汇总时发现、值得记录但未在Phase 7范围内处理的落差

`PPG_CONTRACT_CLOSURE_MATRIX.md` §12.16（V4.2 post-edit independent rerun）明确写着是"2026-08-20 rerun"
（矩阵行3407），其Top-down/Bottom-up/Reverse-port三个审计轴仍引用`G-FP-01`/`G-FP-02`/
`G-FP-03`/`G-FP-05`作为`NOT_CLOSED`的理由——但这些G-FP台账本身已在2026-09-06全部关闭
（见1.2）。也就是说，**系统级`NOT_CLOSED`判定文字本身，比它引用的证据状态更旧**，这正是
本项目反复出现过的"早前确认过的东西后来悄悄过期"模式（TOP-06式），只是这次发生在判定层
而不是单个ID层。这不是一个可以在Phase 7汇总动作里顺手改写的小修订——§12.16是一次完整的
四轴（Top-down/Bottom-up/Reverse-port/Legacy-text）独立审计重跑，工作量接近一次独立G-FP
批次，超出"汇总"这个动作的范围，如实记录、留给用户决定是否值得单独排期，不在本报告内
擅自重跑或悄悄改写verdict文字。

## 3. 边界声明

本报告是数模混合后仿的基础，不是流片正确性本身的担保。

- 覆盖率采集、`report_cdc`/综合、AMI/Top端口新增本身均已排后，不在本报告范围内（见
  Phase 6报告"未做"一节 + `project-ppg-report-cdc-verification-pending-20260905`）。
- Phase 6的19个TB回归证明的是既有场景在Vivado工具链下仍然成立，不是新增了验证覆盖面。
- P06/P13/N01/N08/P01开放半项/D01的Acceptance-D01-01，是本项目目前唯一真正需要**新建TB**
  才能关闭的缺口集合；其余"未关闭"标记（D2/E类共75项）是流程性的（标签/措辞滞后），
  不是证据性的。
- §12.16系统级`NOT_CLOSED`判定的措辞本身已滞后于G-FP台账的真实关闭状态（见2.5），
  这是本报告发现但明确未处理的一项，留待用户决定后续排期。

## 4. 关联

- 承接 [[project-ppg-phase3-pn-reconciliation-20260906]]、[[project-ppg-phase6-xsim-regression-done-20260906]]、
  [[project-ppg-gfp-ledger-batching-plan-20260902]]、[[project-ppg-d01-partial-reconciled-20260905]]。
- 本报告独立成文，不改写`PPG_CONTRACT_CLOSURE_MATRIX.md`正文；矩阵内仅追加一条指向本文件
  的§14最小索引（见下）。
