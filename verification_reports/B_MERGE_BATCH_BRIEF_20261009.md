# B合同合并批次交接书（B_MERGE_BATCH_BRIEF_20261009）

> **状态**：定稿。统筹会话撰写，2026-10-09，基线`7a8eabf`。
> **读者**：接手B合同合并批次的会话。它运行在另一个账号上，只能看到本仓库，看不到统筹机器上的记忆、会话记录和仓库外的回归目录。凡是完成本批次所需而原本只存在于那些地方的信息，本文件都已写入。
> **用途**：汇总已定事项、材料位置、工作顺序和验收标准。它不替代各报告原文；改合同时以原文和RTL为据。

---

## 0. 先读这一节

### 0.1 你的任务
把合同、验收矩阵、别名表这一层，按基线`7a8eabf`的最终RTL一次性改对，并建立符号锚点体系及其检查门禁。项目背景：PPG芯片数字部分。之前三轮RTL修复（RTL第一轮、owner生命周期轮、F-009轮）都已合并，各轮报告都附有"交B清单"，留给本批次统一处理。

### 0.2 权威顺序（发生冲突时）
1. **基线`7a8eabf`的RTL原文**：合同描述的是RTL的实际行为。
2. **本文件§3列出的用户裁定**：这些是之后才定的，覆盖各报告中与之不同的写法，已知的覆盖点见§3.12。
3. **三份轮次报告的交B清单**：ABCD报告§12.8、生命周期报告§8、F-009报告§9。
4. 更早的调查与核查报告。

报告与RTL不一致时，以RTL为准，并在你的报告中列出差异。

### 0.3 边界
- **合同、矩阵、别名表**：由你改。
- **RTL**：不改逻辑。只允许两类注释改动：
  - §3.9点名的注释；
  - 符号锚点转换中，在已有实质性中文注释的行尾追加`@satisfies`标签（§3.10）。
  每改一个RTL文件，都要证明去掉注释后与基线逐字节相同，并对该文件跑skill的deliverable gate，不得新增问题。
- **TB**：只允许按§3.3改PASS标签字符串，不改任何判定逻辑。
- **工具**：新脚本放在`tools/`下。
- **回归**：在你自己的机器上跑（§6.8）。
- **发现RTL疑点**：不修。在报告的"RTL疑点"一节写清现象、证据和所涉合同条款，然后继续工作。
- **必须使用skill**：按根目录`CLAUDE.md`，凡涉及Verilog的分析、核对、格式检查，都使用`.claude/skills/erie-verilog-generator/`。

### 0.4 沟通
你无法与统筹会话直接通信。问题、阶段结果和完成通知都写进报告，推到分支，再告诉用户，由用户转达。遇到本文件没有覆盖、又会影响合同实质内容的取舍，写进报告的"待用户裁定"一节，先做不受影响的部分。

### 0.5 第一次回复用户时请给出
读完本文件和§2的必读材料后，先回复用户：
- 你对任务的理解，三五句话即可；
- 计划的阶段安排（参照§4）；
- 阻塞性问题（如有）。

确认没有误解后再开工。

## 1. 基线、分支、冻结与进度保存

- **基线**：`7a8eabf`。它是F-009轮合并后的main，统筹已独立核对。本批次之前不会再有RTL轮次（F-9已裁定不改RTL，见§3.9）。
- **分支**：在`b-merge-batch`上工作，不直接推main。完成后由统筹核对，再合并。
- **冻结**：你工作期间，统筹一侧不改`contracts/`，也不改RTL和TB。如有例外，统筹会通过用户通知你rebase，并列出受影响的符号。
- **权限**：推送需要对`xinyanbaiqi/zlcx`有写权限。也可以fork后提PR。
- **进度保存**：本批次工作量大，你的对话可能被压缩或中断。请维护`verification_reports/B_MERGE_BATCH_PROGRESS.md`，每完成一步就更新，并经常把它提交到分支。内容包括：已完成项、当前项、下一步、未决问题。中断后从这个文件恢复。

## 2. 材料

### 2.1 C编号与合同文件对应
- 各报告和矩阵用C01~C25指代合同。对应表在`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md`的"§2 Active Contract Sources and Source Classification"（约第130~160行）。
- 表中路径前缀`ppg_system_integration/`等是原开发树的路径。在本仓库中，这些文件都在`contracts/`下。
- 常用对应：

| 编号 | 文件（`contracts/`下） | 编号 | 文件 |
|---|---|---|---|
| C01 | PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT | C16 | PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT |
| C08 | PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT | C17 | PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT |
| C09 | PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT | C18 | PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT |
| C10 | PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT | C23 | PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT |
| C13 | PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT | C24 | PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT |
| | | C25 | PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT（测试合同，含LFA、RRC、SID等验收表） |

- 没有C编号的合同：芯片顶层`PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md`（SPI诊断地图在其中），以及`PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md`、`PPG_ADC_IDAC_INTEGRATION_SPEC.md`、`PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md`、`TAPEOUT_FINAL_REVIEW_GUIDE.md`。

### 2.2 必读材料（都在仓库内）

| 文件 | 读什么 |
|---|---|
| `CLAUDE.md`、`README.md` | 仓库约定、目录结构 |
| `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md` | §1.1身份组展开；§2合同来源表；§12.4a 26个文件的基线清单（SHA256摘要）；§13自动交叉引用表与§13.3命名治理规则 |
| `contracts/PPG_ALIAS_MAPPING_TABLE.md` | 表头schema；现有锚点写法 |
| `verification_reports/ABCD_REVIEW_VERIFICATION_20261004.md` | §4总表（F-xxx编号的含义）、§10~§12；§12.5 F-030四点论证；**§12.8交B清单** |
| `verification_reports/OWNER_LIFECYCLE_DESIGN_20261007.md` | 方案甲设计。§10、§11是用户裁定，优先于其它节 |
| `verification_reports/OWNER_LIFECYCLE_ROUND_20261007.md` | §1.3设计订正；§2.2冗余校正器；§4.3可达性；§7待定与统筹预审；**§8交B清单** |
| `verification_reports/F009_ROUND_20261008.md` | §1.3~§1.5事件表、审核点B订正、起帧采样输入；§4例外C；§6 L-6；**§9交B清单** |
| `verification_reports/F9_RECHECK_STAGE_FRAME_REVIEW_20261009.md` | F-9核查（与本文件一同提交）：§2合同引用、§3功能论证、§5修法3原文 |
| `verification_reports/ID_GOVERNANCE_AUDIT_20261005.md`、`ID_GOVERNANCE_AUDIT_FOLLOWUP_20261005.md` | 编号治理的全部依据；附录A扫描器；需订正的状态声明清单 |
| `verification_reports/F002_F008_EPOCH_CONSUMER_CHECK_20261006.md` | F-002/F-008收窄依据与措辞建议（第3节） |
| `verification_reports/SSW18_TICK385_INVESTIGATION_20261006.md` | SSW-18与S1；第128行附近FSC-35改判 |
| `verification_reports/LOST_COMPLETION_NORMAL_AND_LATENESS_20261006.md` | L-1~L-4的来源；编号改称记录 |
| `verification_reports/CONTRACT_SYNC_BATCH2_20260930.md`、`CONTRACT_SYNC_BATCH3_20261001.md`、`CONTRACT_SYNC_BATCH3_PHASE2_20261004.md` | 以往合同批次的格式、版本记录写法和做法先例 |

## 3. 用户已定事项（权威，不再讨论）

### 3.1 合同分级
- **一级（流片前必须改对）**：对外接口（端口名、位宽、方向、复位值）、编码（原因码、discard原因、SPI位）、恢复流程（诊断清除、STOP/START、abort）、功能规则（时序、优先级、例外）、验收ID及其含义。
- **二级（可延后）**：内部说明文字、设计理由的叙述。本批次不改，逐条登记到新建的`verification_reports/POST_TAPEOUT_DOC_CLEANUP_LIST.md`。每条写明：合同与节号、问题、为何属二级、建议改法。
- **三级（不做）**：历史叙述、行号、摘要。摘要改由脚本自动生成，见§3.2。

### 3.2 符号锚点（取代"文件:行号"）与摘要
- **新格式**：矩阵和别名表中证据列、锚点列写成"**模块文件名 + 端口/信号/实例名或`@satisfies`标签 + 合同节号（§x.y）**"。
  - 例：`ppg_sar9_sar15_safe_selection_wrapper.v` `flag_red_context_valid`（C09 §x.y）。
  - 合同之间的互引（`Cxx:NNN`）也改为节号。
- **一次性转换**：
  - 按基线HEAD读出每个现有行号锚点所在行的内容，提取对应的符号；
  - 有歧义的逐条人工判定；
  - 保留"旧锚点 → 新锚点"的转换对照表，作为报告附录；
  - F-003（矩阵和别名表中的失效锚点，如别名表约第58行出处`MATRIX:872`）的重建并入这次转换；
  - 带日期的历史叙述保持原样。
- **检查脚本**（放在`tools/`）检查三件事：
  - 被引用的文件存在；
  - 名字或`@satisfies` ID在该文件中按词边界确实存在（能用skill的formatter AST取端口、信号名的就用AST）；
  - 引用的合同节号存在。
  - **先做负对照**：人为改错几处，脚本必须恰好报出这几处，不多不少。
- **接入回归门禁**：放在回归入口开头或作为独立一步，检查失败则整轮报错。在真实回归中演示一次通过、一次负对照失败。
- **摘要（F-045）**：矩阵§12.4a"26-file Baseline Manifest"中的SHA256摘要，现有26个中23个已不符。不再手工维护，写脚本按当时文件自动生成。这一步放在所有合同改动之后（§4阶段5）。

### 3.3 编号治理
- **规则**：TB标签只有在与合同同号条目含义**完全一致**时才用合同编号，否则用TB本地名，对应关系记入别名表。
- 不在C08建对照表。FSC-58~62不登记为合同条目。
- **已知映射**：
  - 调度器TB中唯一可直接改用合同编号的，是TB的FSC-32（= 合同FSC-30）；
  - TB FSC-14对应合同FSC-03：F-011已将其收紧为严格5000，标签仍保留FSC-14。
- **已改称的编号**：
  - SSW-18报告里的N-1、N-2改称L-1、L-2；
  - F-009轮的新缺陷改称L-6（曾暂称N-2）；
  - TB标签N2-START改为L6-START，N2SCAN改为L6SCAN（已完成）。
- **FSC-35**：改判为"部分"（SSW18报告第128行附近）。
- 需订正的状态声明、门禁范围、SUP06A误引，以及需改名的TB标签清单（调度器TB的FSC-n场景序号、SUP03A/09A/10A、DCR `drive_and_check`第3~7号、SSW-18、LFA-11a等），见ID_GOVERNANCE_AUDIT_FOLLOWUP。改名前在基线上重跑扫描器复核（§6.3）。
- **新增编号前**：先查矩阵§13和§13.3规则，再grep对应合同的验收表和全仓库，确认编号未被占用、没有歧义。不要看TB里最后一个编号就+1。本项目多次因此撞号。

### 3.4 (d)类七项
- **N-1**：RTL已改（AMI诊断清除加`!flag_integration_blocking`门控，"RUN上下文已结束且datapath empty"时也可清）。合同按RTL写。
- **F-032**：IDAC端口`i_status_clear_event`已改名为`i_diag_clear_event`。合同和矩阵中登记的RTL名、锚点都要更新。
- **F-030**：CS_N作异步复位和门控。改合同，写入四点安全论证（ABCD报告§12.5）。
- **F-014/F-024**：相关参数在合同中冻结为固定值，并注明参数检查所在的TB：supervisor单元TB、控制顶层TB、芯片顶层TB。
- **F-002/F-008**：收窄C13 §4.1、C01与C10的公开端口表、矩阵§1.1中的`i_datapath_discard_*`与`o_measurement_result_discard_*`身份组。
  - 只保留RTL实际的6个字段：`frame_id`、`sample_index`、`color_ir`、`frame_type`、`precision`、`run_generation`。正式结果组另有`sample_valid`。
  - 另立一个缩小的身份组名（如`TXN_KEY`），避免与完整的`TXN_ID`混用。
  - 措辞写"在16位计数回绕窗口内唯一"，并注明"按代际匹配（generation-scoped），身份字段仅作诊断"。见F002_F008报告第3节。
- **F-044**：注明证据范围只到叶子级。

### 3.5 SSW-18（S1修复）
- 按S1修复后的RTL改写C09：
  - SSW-18验收行（约第835行）；
  - "若当前结果未能在local tick 385前支持下一候选码准备…"一段（约第373行）；
  - `o_calibration_timeout_sticky`的端口说明（约第602行）。
- 改写要点：
  - 迟到诊断只置sticky，不终止burst；
  - sticky的条件是"本子帧校准owner在tick 385仍未完成"，owner与子帧绑定；
  - 迟到结果由三道防护挡住，不复用旧码；
  - 明文写出前提："ADC在Q3（tick 266）已完成采样，迟到的只是读出"。
- 细节见SSW18报告与生命周期报告§8.4第4条。

### 3.6 ADC完成丢失：方案甲（owner生命周期轮）
- **参数**：
  - T-lost=4500拍：从owner的start fire起计年龄；ADC物理空闲、没有捕获在途时才作废；
  - k=2：按RED/IR/CAL槽位分别计数，同槽位的真实完成清零计数。
- **编码**：
  - discard原因`2'b11`=COMPLETION_LOST，这是2位字段的最后一个空位；
  - cause `8'h06`：同槽位连续丢失，summary bit 9；
  - cause `8'h07`：owner在途≥9000拍、ADC仍不回idle，summary bit 10；
  - 两者source都是`4'h1`。
- **职责**：AMI是唯一裁决点。lost sticky在AMI，经SPI 0x0108 bit6导出，START不清。
- **冗余校正器**：作废输入`i_transaction_abandon`是第三步新增的，见生命周期报告§2.2。
- **约2拍竞争窗口**：不改`async_stage_capture`，把这个窗口写成合同前提，并写明窗口内错绑的结果会以success=1正式输出（F-3）。
- **完整改动清单**：按生命周期报告§8.4逐条做，涉及C10、C25 LFA-04、C24、C09、C08、C18/C16、C01与芯片顶层SPI地图、冗余校正器、精度窗口控制器合同。本节以下各条是统筹预审的补充（F-1~F-7）和覆盖说明。
- **F-1（已知例外，用户裁定不改RTL）**：
  - 双光模式下，若IR完成丢失与精度切换挂起发生在同一帧：作废约在mt4810，晚于精度提交点mt4760（`MACRO_SAFE_TICK`）；
  - 切换挂起会阻止下一个NORMAL帧，10000拍后切换超时，报cause 04，abort+STOP，诊断清除后可重启；
  - 设计"单次丢失不升级"要加上这个例外；
  - C10、C24、C23（精度窗口控制器）和软件恢复流程都要写明。
- **F-2**：第k次作废若落在STOP后的排空末尾：lane 06只保持1拍，cause 06的episode在回到CONFIG后才开，manager记0x0C，START前须先诊断清除。
- **F-4**：C10 §6.11（"AMI local fault-record arbitration"，约第657~659行）原句"`diag_clear`, STOP, abort, a result discard, enable deassertion and START neither remove a pending fault record nor clear an active lane"与RTL不符。
  - 按RTL改写：lane 01/02/03/06/07在START、abort、"RUN已由STOP结束且AMI排空"时清零，新故障置位优先；
  - 分发器扩为七路。
- **F-6**：`C_ADC_COMPLETION_LOST_CYCLES`、`C_ADC_COMPLETION_LOST_LIMIT`冻结为固定值4500/2（同F-014/F-024先例），并写明合法范围：LIMIT为1~15，CYCLES小于32768。
- **F-7**：作废置失败的是"当前宏帧"，不是owner所在帧。
- **L-5**：RTL已修复——STOP结束且排空后lane落下。但该修复在当前生产构建的系统级不可观测，因为supervisor的abort会先清掉lane，属纵深防御（生命周期报告§7.1(c)）。C10 §15.2原限制说明"需主机ABORT"要改写为"已修复"，并注明系统级不可观测、属纵深防御，不能只写"已修复"。

### 3.7 F-009轮（以F-009报告§9.4为准）
- **C08 §4.2**：补"宏帧末拍、下一帧资格成立即直接起帧"条款，门控与F-010滚动相同；校准与否取帧末处理后的请求pending。
- **FSC-03**（相邻宏帧起点严格相差5000）现对所有帧末成立，**例外C**除外：
  - 条件：CAL帧末owner在途、无pending、NORMAL资格不成立（如启动搜索期）、AMI以电平保持校准请求；
  - 此时间隔不是5000，至少空2拍，具体由在途owner的释放时刻决定。回归实测为5004和5131，换回旧调度器也相同，属既有行为；
  - 全套回归中4份带帧间隔监视器的TB，没有发现其它非5000间隔。
- **调度器诊断sticky**：清除要求`!B_FRAME_ACTIVE`，所以只能在RUN之外清除。生命周期报告§7.1(d)的事实也作为已知限制写入C08：周期重检期间，夹在校准帧之间的NORMAL帧会出现无owner的RED/IR波形，owner截止sticky因此被置位，所以重检期间这个sticky不能作为异常指示。
- **STOP语义**：manager的STOPPING不等帧结束；已建立的帧在CONFIG中以空帧走完，不触发任何STOPPING计时。
- **L-6**（无现成合同编号，是否给编号按§3.3规则定）：
  - 规则：新RUN的START确认时，如果没有在途owner且ADC空闲，SSW作废上一RUN残留的未提交RED/IR/CAL波形上下文和停止挂起，与abort一致；
  - 前提写明：STOPPING完成要求ADC空闲且数据链排空。
  - C09据此补写。
- **别名表**：调度器TB标签FSC-14 ↔ 合同FSC-03。

### 3.8 不由本批次处理的事项
以下事项的**后续验证或是否改RTL**不在本批次，只在你的报告中引用登记，由统筹另行安排进流片前验证收尾计划：
- 生命周期报告§7.1(d)(e)(f)。其中(d)的合同说明仍按§3.7写入C08，这里只把它的验证工作排除在本批次之外；
- F-3附带的调度器与SSW在IR提交窗口上的不一致；
- TB容差审计；
- F-009报告§9.4第6条各项；
- START后IDAC码提交到第一帧接管只隔2~16拍，以及240拍建立预算本身是否足够，都需要模拟侧确认。

### 3.9 F-9：重检阶段沿用更早宏帧的"帧完成"（用户已裁定：不改RTL，合同写明）
- **现象**：阶段延长或跨帧重试之后，重检调度器`ppg_amb_recheck_scheduler.v`的`flag_stage_frame_complete`沿用本阶段内较早锁存的校准宏帧完成。阶段在结果出来时立即推进，下一阶段在同一物理校准帧的后续子帧接管。
  - 正常运行即可触发：periodic_recheck_recovery TB的RRC-07段就走这条路径。
  - 作废重试同样会触发。
- **依据**：
  - C08 §12.3已允许阶段延长到后续校准宏帧，且阶段身份保持不变；
  - IDAC样本资格（`ppg_idac_code_controller.v`的`flag_amb_sample_qualified`、`flag_dcs_sample_qualified`）要求快照码和epoch等于当前已提交的码和epoch，所以下一阶段不可能用未生效的码；
  - 实测下一阶段首样本距上次码提交≥865拍。
- **本批次要做**：
  1. C16 §9.4流程图把"第1/2/3个9-bit校准帧"改为"第1/2/3个校准阶段"，并写明：
     - 每个阶段从一个新的物理校准宏帧开始；
     - 阶段跨宏帧延长（C08 §9.6）或跨宏帧重试之后，下一阶段可以在同一物理校准宏帧的后续子帧开始；
     - 下一阶段首样本用的是上一阶段最终已提交的码。
     必要时同步§17、§18的措辞。
  2. C08 §12.3写明：所谓"物理校准宏帧结束事实"，指本阶段内出现过的任一次`o_calibration_frame_complete_event`，不要求晚于本阶段最后一笔样本。
  3. RTL注释：`ppg_amb_recheck_scheduler.v`在基线中第148、215、269行的三处注释说"每阶段对应各自物理帧"，按上面的语义改写，只改注释。
- **顺带订正两处合同措辞**：
  - C17第503行（§8.4末句）"AMB码未实际改变时不得产生`o_dcs_revalidate_request`"，与C16 §9.6/§18及RTL相反。RTL跟C16，按C16改C17。
  - C25 SID-04（约第552行）写"Every evaluated candidate uses eight physical SAR9 subframes"，而RTL是每个候选只取一笔样本、相邻候选相隔一个子帧。核对RTL和TB的SID-04 PASS行后订正措辞。

### 3.10 RTL标签约定（双锚点）
这一约定原本只记录在统筹机器上，别名表表头引用的那份memory文件不在本仓库，所以抄录如下：
- **RTL端**：`@satisfies: <ID1>, <ID2>`不单独成行，追加在该处已有的实质性中文注释末尾，用`;`隔开。例如：
  `// 唯一物理ADC idle同源扇出…; @satisfies: TOP-17`
  - 如果该处原本没有实质性注释，先补一条解释设计意图的中文注释，再追加标签。
  - 单独成行会被deliverable gate判为VG055（空洞注释）或VG066（模板化重复），所以禁止。
  - 改完对该文件跑gate，确认零新增VG055、VG066。
- **TB端**：新建或修改的检查，PASS消息里包含被满足的验收ID或TB本地名。已有TB的历史PASS文本不追溯改写，除非属于§3.3的改名。
- **别名表字段**：验收ID｜对应TB场景名或PASS标记｜对应RTL锚点（本批次起改为符号锚点）｜该映射的出处。没有真实映射时如实填"无映射"，不得留空或编造。

### 3.11 命名治理（矩阵§13.3目前只有一句"见memory…"，规则原文以本节为准，本批次请抄入§13.3）
- 新增验收ID或TB场景之前，先查矩阵§13交叉表，确认这个行为是否已有别的ID在描述。
- 新增CLOSED或PARTIAL断言时，写成"状态见§13交叉表，ID=…"这样的简短指针，不在正文手写整段论证。
- 改动后刷新`tools/cross_reference_tools/reconcile_acceptance_ids.py`的报告。注意：
  - 该脚本的路径仍指向原开发树的`ppg_system_integration/`，需要先改到本仓库路径；
  - 它的ID正则只覆盖22个族，FSC、AMI、SUP等29个族不在其中，只能作辅助；
  - 路径改正后约有22个伪ID，来自TB文件头修订记录中叙述`@satisfies`的文字。把它们作为已知误报排除，并在报告中列出。

### 3.12 已知的覆盖点：本文件与报告措辞不同之处，以本文件为准
1. 生命周期报告§8.4第6条（C18/C16）提到"每个重检阶段在新的校准宏帧sf0开始；只有阶段内需要多个样本时才…"。按§3.9的F-9裁定改写：允许下一阶段在延长或重试之后，于同一物理校准帧的后续子帧开始。
2. 生命周期报告§8.4第1条与第10条中，L-5写作"改为已修复"。按§3.6的L-5条补上"系统级不可观测、属纵深防御"。
3. F-009报告§4与附录A中"间隔2个空拍"已由报告自身订正为"至少2个，由owner释放时刻决定"。按订正后的写法。
4. 生命周期报告§8.4第1条写"`o_wrapper_fault_blocking`随之在排空后为0"，与RTL不符。AMI中该输出还包含`flag_integration_blocking`，后者只在复位、START或abort时清零；排空后落下的是各lane和`o_ami_fault_active`。按RTL写，并在报告中列出这处差异。

### 3.13 冷启动试读提出的问题与统筹答复（推送前用零上下文会话试读本文件得到）
- **Q1 锚点转换方法与范围**
  - 抽查发现多数旧锚点写于更早版本，到基线已漂移：别名表中写明符号的80个锚点只有27个仍指向该符号；矩阵中409个端口锚点只有76个仍指向声明行。
  - 做法：
    - 单元格里已写明符号或声明原文的，以原文为准，到基线按名字定位；
    - 只有裸行号的，用`git log -L`或blame追到该锚点写入时的提交，在那个版本读出符号，再到基线按名字定位；
    - 追不出来的标为"失效锚点（无法追溯）"，在报告中列出，不要猜。
  - 范围：矩阵§12.5 G-FP-01端口台账中带删除线或带日期的条目属于历史叙述，保留原样；只转换当前有效的证据锚点。同一单元格两者都有时，只转换当前部分。
- **Q2 节号重名**：11份文件存在重复节号，例如C01的§4.1出现两次。遇到重名时写"节号+节标题"，检查脚本按"节号+标题"校验。本批次不给合同重新编节号，重新编号登记进二级清单。
- **Q3 无法只改字符串的标签**
  - 原则：任何情况下都不改激励、不改判定。
  - 调度器TB的`check_fsc(N, …)`：不改实参N，只把打印格式串里的前缀改为TB本地名（按§3.3规则选名，先grep避免撞号）。TB FSC-32 ≡ 合同FSC-30的对应关系只登记在别名表，不改实参，因为TB里已有另一个含义不同的`check_fsc(30, …)`。
  - DCR TB的`drive_and_check(test_id, …)`：test_id参与生成激励，不动。若标签由test_id拼出，只改格式串前缀；做不到就只在别名表登记。
  - 这类只改格式串的改动，仍满足"去掉注释和字符串字面量后逐字节相同"。
  - 允许同步修改`tools/run_unit_tb_regression.sh`以及回归脚本中依赖横幅文字（如`ALL FSC-01 THROUGH FSC-62 PASSED`）的判据正则，改后用回归证明判定数和`$finish`不变。
- **Q4 §3.7与§3.8是否矛盾**：不矛盾。§7.1(d)的合同说明按§3.7写入C08；§3.8排除的只是它的后续验证和是否改RTL。
- **Q5 C10 §15.2**：基线中没有"需主机ABORT"这段文字，ABCD §12.8要求补写但一直没落地。按最终RTL直接写，不写"由X改为Y"的过程。`o_wrapper_fault_blocking`的写法见§3.12第4条。
- **Q6 ID治理报告中本文件没有点名的项**：例如S5 PWI-01~05在C18和C23重复定义、S6、S9、S10、OVL/OPTC/JNT登记、RAW↔RGC等对照行、MGR-12 0x05不可达、C17 IDC2-17（第670行，与第503行同一问题）、PRC-05/08、AMI-24可能空真。
  - 凡涉及合同措辞的，纳入本批次：属一级的改，拿不准分级的列"待裁定"。
  - 要改TB判定或会改变PASS行数的（如把PRC-05/08改成INFO），只登记不做，交收尾计划。
- **Q7 指向记忆文件的引用**：矩阵和别名表中约40处`[[project-ppg-...]]`之类的记忆引用。检查脚本把它们单列为"仓库外引用"豁免，并在报告中列出清单；不删除这些引用，它们是历史出处。矩阵§13.3的规则正文从本文件§3.11抄入。

## 4. 工作顺序（按这个顺序做，前后依赖已排好）

| 阶段 | 内容 | 为什么排在这里 |
|---|---|---|
| 0 环境与基线回归 | 克隆仓库，切出`b-merge-batch`。对基线`7a8eabf`完整跑一遍回归（§6.8），可放在后台，同时做阶段1 | 后面每次回归都要和它比 |
| 1 总表（**检查点**） | 把三份交B清单（ABCD §12.8、生命周期§8、F-009 §9）与本文件§3合成一张总表，每项一行：来源、目标合同与节、分级（一级改/二级登记/不做）、处理要点、状态。提交到分支（`verification_reports/B_MERGE_BATCH_ITEMS.md`），告诉用户，等统筹审核。如果用户告知统筹暂时无法审核（例如额度用完），就由用户直接确认后继续，并在报告中注明总表未经统筹审核 | 先确认范围理解一致，避免整批返工。等待期间可做阶段0，以及阶段4的检查脚本开发 |
| 2 一级合同改写 | 按合同逐个改，每份合同一个提交，更新该合同的版本号和修订记录（格式参照以往CONTRACT_SYNC报告）。二级问题随手登记进清单 | 合同内容先定，节号才稳定 |
| 3 编号治理 | 在基线上重跑ID治理扫描器（§6.3）→ TB标签改名（§3.3）→ 别名表映射 | 标签名确定后才能转换锚点 |
| 4 符号锚点 | 检查脚本加负对照 → 一次性转换矩阵和别名表的锚点 → RTL注释与`@satisfies`标签（§0.3）→ 脚本在分支HEAD上0报错 | **必须在阶段2、3之后**：合同节号和标签一变，锚点就要重做 |
| 5 摘要与§13 | 摘要生成脚本重算矩阵§12.4a；修正reconcile脚本路径并刷新§13 | 任何合同改动都会改变摘要，所以放在最后 |
| 6 回归与门禁 | 分支最终提交跑全套回归；与阶段0比对；证据入库；检查脚本接入门禁并演示通过和负对照失败 | 证明RTL/TB行为不变 |
| 7 报告 | `verification_reports/B_MERGE_BATCH_REPORT_20261009.md`（日期按实际），告诉用户分支名、最后提交号、报告路径 | |

## 5. 工作项骨架（阶段1据此展开成总表）

| 合同 | 主要来源 |
|---|---|
| C08 调度器 | L-1、L-3、L-4、F-010、作废释放（FSC-54）、F-7、F-009/F-011、例外C、诊断sticky（RUN外清）、F-9（§12.3）、FSC编号治理 |
| C09 SSW | S1/SSW-18、SSW-16/17/42作废释放、SSW-34/38 owner与帧绑定、L-6、端口`i_adc_transaction_lost_event` |
| C10 AMI | 方案甲：AMI-39/40、端口与参数（F-6）、§6.10 discard 11、§6.11（F-4、七路）、§15.1、§15.2（L-5）、捕获窗口前提（F-3）、已知限制（F-1、F-2）、N-1、冗余校正器部分 |
| C13 / C01 / 矩阵§1.1 | F-002/F-008收窄 |
| C16 / C18 重检、PWI | F-020撤销合并（新输入）、F-9（§9.4） |
| C17 IDAC | F-032改名、C17 §8.4（第503行） |
| C23 精度窗口控制器 | F-1例外 |
| C24 supervisor | §3 cause 06/07、§5下降条件、§6看门狗（"超时作废不属于伪造"）、F-1/F-2恢复流程、F-014/F-024 |
| C25 测试合同 | LFA-04超时作废例外、SID-04措辞、FSC/SUP/RRC相关编号治理 |
| 芯片顶层合同 | F-030四点论证、SPI 0x0108 bit6与诊断地图逐位清除方式、F-014/F-024 |
| C01 | `o_ami_owner_lost_sticky`、F-002/F-008、F-030相关、状态声明订正（ID治理续报告） |
| 矩阵 / 别名表 | 符号锚点、F-003、编号治理、F-032、新检查标签映射、§12.4a摘要、§13刷新 |

## 6. 方法与纪律

1. **合同措辞按RTL原文写**：不照抄报告摘要。每条改写都回到RTL核对，并引用符号锚点。
2. **全仓搜同类表述**：改一条规则时，在`contracts/`和矩阵中搜出所有同义表述，一并改掉或登记为二级。
3. **编号治理先重跑扫描器**：
   - 扫描器和`rescan_diff.py`的完整代码在ID_GOVERNANCE_AUDIT_20261005.md的"附录A"（约第1256行起），仓库里没有现成的脚本文件，需要你从报告中提取。
   - 原快照基线`tb_sites.json`也不在仓库中：先对该报告的快照`2a90a69`导出运行扫描器，重新生成基线；再对`7a8eabf`运行；然后用`python rescan_diff.py <基线tb_sites.json> <新tb_sites.json> contract_ids.json`比对。
   - 报出的项逐条人工复读。之后ABCD的TB轮改过多份TB，当时试跑报出过31处"B?"，要逐条核实。
4. **TB标签改名**：只改`$display`中的标签字符串。
   - 改名后，去掉注释和字符串字面量，必须与基线逐字节相同，用脚本证明。
   - 回归中PASS行只允许出现标签字符串的差异，并逐条列出新旧标签对应。
5. **一次性锚点转换的已知陷阱**（来自以往批次的实际踩坑）：
   - 扫描要覆盖这些写法：
     - 裸`:NNN`（文件名在同一单元格前面）；
     - `Cxx:a, Cxx:b-Cxx:c`形式的列表（防止前一个引用吞并后一个）；
     - 整数节号（如`C10:2;`、`C10:7, 10`）；
     - `Cxx :N`、`contract `:N``、`§x`:N``、`合同`:N``。
   - 文件名匹配要有左边界，否则`tb_xxx.v`会被误认成`xxx.v`。曾因此误归属47条。
   - 裸引用前面插着模块简称时（如`AMI :304`、`Top :410`），要逐条人工复核。
   - 改之前先快照，最后读磁盘上的新旧文件独立复核：引用逐条配对后文字相等。
6. **负对照**：检查脚本、转换复核脚本都要先证明自己能报错，再采信"全部通过"。工具第一次就报"几乎没有问题"时，先怀疑工具本身。
7. **历史叙述不改**：带日期的修订记录和历史段落保持原样。
8. **回归**（在你的机器上跑）：
   - 入口脚本：
     - 系统TB：`rtl/ppg_control_top/run_xsim_regression.sh`，20份；
     - 芯片：`rtl/ppg_chip_digital_top/run_xsim_regression.sh`；
     - 模块级：`tools/run_unit_tb_regression.sh -g all`，28份。
   - 环境：脚本按Windows + Git Bash编写，调用`xvlog.bat`等。Vivado路径用环境变量`VIVADO_BIN`指定，默认`/c/Xilinx/Vivado/2022.2/bin`。基线用的是Vivado 2022.2，版本不同请在报告中注明。如果是Linux机器，需要把`.bat`改成本地可执行文件，只改本地运行副本，不提交。
   - 导出：一律用`git -c core.autocrlf=false archive <提交> | tar -x`导出到仓库外的独立目录再跑。不要在工作区直接跑：autocrlf会改写文件字节，`.sh`带CRLF在bash下会出错。
   - 基线与分支：先在你的机器上对基线`7a8eabf`完整跑一遍，再对分支最终提交跑一遍，两次在同一台机器、同一Vivado版本上跑。20份系统TB可分3~4组并行，每组用独立的导出目录。参考耗时：分组并行约1小时。
   - 比对方法：逐TB把PASS行排序后做diff，再比`$finish`时刻。不要用summary.tsv代替逐行比对。预期只有标签字符串不同，`$finish`完全相同。
   - 证据入库：统筹看不到你机器上的运行目录。把两次回归的逐TB排序PASS行和`$finish`行（纯文本）提交到`verification_reports/b_merge_batch_evidence/`，并在报告中给出比对结论。
   - 基线参考值：统筹机器上对`545abfd`的回归结果为：系统TB 20/20全部通过、0 FAIL；按`grep -E '\bPASS\b'`并排除含`pass=`的汇总行计，共1250行；芯片20/0；模块级28/28。
     - `545abfd`与`7a8eabf`的差别只有L-6改名：注释、PASS标签`N2-START`→`L6-START`、`N2SCAN`→`L6SCAN`，以及adc_anomaly TB局部变量`n2_*`→`l6_*`。PASS行数和`$finish`应相同。
     - 你的基线结果与此不一致时，先查环境。
9. **文本与编码**：仓库文件是UTF-8中文。含正则的Python脚本用文件写，不要用Bash heredoc（会吃掉`\\`）。`git diff --word-diff-regex`处理中文时容易失效，宜逐行比较。

## 7. 交付与验收

- **交付物**（都在`b-merge-batch`分支上）：
  - 合同、矩阵、别名表的修改，按合同分组提交；
  - `tools/`下的符号锚点检查脚本和摘要生成脚本，附用法说明；
  - `verification_reports/B_MERGE_BATCH_ITEMS.md`（总表，最终版注明每项的状态）；
  - `verification_reports/POST_TAPEOUT_DOC_CLEANUP_LIST.md`（二级清单）；
  - `verification_reports/b_merge_batch_evidence/`（回归比对证据）；
  - `verification_reports/B_MERGE_BATCH_REPORT_<日期>.md`。报告内容包括：
    - 总表中每项的处置；
    - 锚点转换对照表（附录）；
    - 脚本负对照证据；
    - 回归比对结论；
    - RTL注释改动的去注释比对证明；
    - RTL疑点；
    - 不做或延后的项及原因；
    - 待用户裁定项。
- **验收标准**（统筹核对）：
  - 三份交B清单与§3的每一项，在总表中都有处置记录；
  - 检查脚本在分支HEAD上0报错，负对照恰好命中，已接入门禁；
  - RTL去掉注释后与基线相同；TB去掉注释和字符串后与基线相同；
  - 回归证据已入库：两次回归逐TB的PASS行只有标签字符串差异，`$finish`完全相同；
  - 合同中每条新写或改写的规则，都能在RTL中找到对应符号；统筹会抽查一级改动与RTL的一致性；
  - 矩阵§12.4a摘要由脚本生成，并与分支HEAD的文件一致。

## 8. 不在本批次范围

- 任何RTL逻辑修改。
- 补测试：FSC-19/23/24/27/44、SSW-18 sticky置1检查。按计划在本批次之后做。
- 流片前验证收尾计划：同拍冲突矩阵、时序扫描、故障注入、覆盖率、变异测试、独立TB、形式验证等。
- 外部审阅的证据文件（C组`id_review_matrix.csv`等）不在本仓库，本批次不依赖它们。
