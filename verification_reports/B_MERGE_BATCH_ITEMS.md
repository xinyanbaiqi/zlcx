# B合同合并批次总表（B_MERGE_BATCH_ITEMS）

> 依据：`verification_reports/B_MERGE_BATCH_BRIEF_20261009.md`（下称"交接书"）§4阶段1。
> 基线：`7a8eabf`。分支：`b-merge-batch`。
> 状态：**统筹已批准（2026-10-09，经用户转达）**，进入阶段2。审核意见见§20，已落到各条目。
> 权威顺序：RTL > 交接书§3（覆盖点§3.12）> 三份交B清单 > 更早报告（交接书§0.2）。

---

## 0. 说明

### 0.1 来源缩写

| 缩写 | 出处 |
|---|---|
| ABCD | `ABCD_REVIEW_VERIFICATION_20261004.md` §12.8（交B清单）；`§10(b)`指该报告§10的(b)组，`§4`指总表 |
| OLR | `OWNER_LIFECYCLE_ROUND_20261007.md` §8（交B清单）；`§8.4-n`指§8.4第n条；`§7.2 F-n`指统筹预审 |
| F009 | `F009_ROUND_20261008.md` §9（交B清单）；`§9.4-n`指§9.4第n条 |
| BR | 交接书本身；`BR§3.x`指用户裁定，`BR Q-n`指§3.13冷启动问答 |
| IDG | `ID_GOVERNANCE_AUDIT_20261005.md`；`IDG S-n`指§3.2表，`IDG §10`指处置建议 |
| IDF | `ID_GOVERNANCE_AUDIT_FOLLOWUP_20261005.md`；`IDF P-n/G-n/R-n`指§3各表 |
| F28 | `F002_F008_EPOCH_CONSUMER_CHECK_20261006.md` §3 |
| F9R | `F9_RECHECK_STAGE_FRAME_REVIEW_20261009.md` |
| SSW18 | `SSW18_TICK385_INVESTIGATION_20261006.md` |
| LCN | `LOST_COMPLETION_NORMAL_AND_LATENESS_20261006.md` |

### 0.2 分级（交接书§3.1）
- **一级**：本批次改对。对外接口、编码、恢复流程、功能规则、验收ID及其含义。
- **二级**：本批次不改，登记到`POST_TAPEOUT_DOC_CLEANUP_LIST.md`。
- **三级/不做**：历史叙述、行号、手工摘要；或交接书§3.8/§8排除的事项（只在最终报告中引用登记）。
- **工具**：`tools/`下的脚本工作；**TB标签**：只改PASS标签/格式串（交接书§3.3、Q3）；**RTL注释**：交接书§0.3允许的两类注释改动。

### 0.3 目标节号
- 节号是按基线合同目录初定的。阶段2改写时以合同原文为准，节号若有调整会在本表"状态"列注明。
- 有重名节号的文件（BR Q2），按"节号+节标题"写。

### 0.4 状态取值
`待做` / `进行中` / `已完成（提交号）` / `登记（二级清单）` / `不做（原因）` / `待裁定`。

---

## 1. C08 调度器（`PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`，基线V1.12）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-001 | F009 §9.4-1；BR§3.7 | §4.2 400 Hz宏帧 | 一级 | 补"宏帧末拍下一帧资格成立即直接起帧"条款：门控与F-010滚动相同；校准与否取帧末处理后的请求pending（含本拍握手与跨帧重挂；在途owner不重挂）。RTL锚点：`flag_frame_restart`、`flag_next_frame_inputs_eligible` | 已完成（C08 V1.13） |
| BMI-002 | F009 §9.4-1；BR§3.7、§3.12-3 | §4.2；§18 FSC-03 | 一级 | FSC-03（相邻宏帧起点严格相差5000）对所有帧末成立，写明**例外C**：CAL帧末owner在途、无pending、NORMAL资格不成立（如启动搜索期）、AMI以电平保持校准请求时，间隔不是5000，至少空2拍，由在途owner释放时刻决定；回归实测5004、5131，换回旧调度器也相同，属既有行为；4份带帧间隔监视器的TB没有其它非5000间隔 | 已完成（C08 V1.13） |
| BMI-003 | F009 §9.4-2；OLR §7.1(d)；BR§3.7、Q4 | §16.5 诊断清除；§17或已知限制处 | 一级 | ① 调度器诊断sticky清除要求`!B_FRAME_ACTIVE`，RUN中帧首尾相接，只能在RUN之外清除；② 已知限制：周期重检期间夹在校准帧之间的NORMAL帧会出现无owner的RED/IR波形，owner截止sticky因此置位，重检期间该sticky不能作为异常指示。（只写合同；后续验证按BR§3.8不在本批） | 已完成（C08 V1.13） |
| BMI-004 | F009 §9.4-3；BR§3.7 | §16.3 STOP | 一级 | STOP语义：manager的STOPPING不等帧结束；已建立的帧在CONFIG中以空帧走完，不触发任何STOPPING计时（STOP落在新帧tick 0时空帧约2.5 ms） | 已完成（C08 V1.13） |
| BMI-005 | ABCD §12.8 F-010 | §9（校准事务）CAL滚动相关处；§16.3/§16.4 | 一级 | 补"CAL滚动受生命周期撤销屏蔽（STOP/abort/故障/离开RUN）"条文。RTL锚点：`flag_calibration_rollover`（`@satisfies: FSC-31, FSC-32`） | 已完成（C08 V1.13） |
| BMI-006 | OLR §8.4-5 L-1；LCN | §10.4 完成和owner释放；§18 FSC-17 | 一级 | 宏帧末不重挂在途owner的请求（FSC-17）。RTL锚点：宏帧末重挂条件 | 已完成（C08 V1.13） |
| BMI-007 | OLR §8.4-5 L-4；LCN | §10.3；§18 FSC-46/49/50 | 一级 | 截止当拍可提交，越过截止只收尾。RTL锚点：`flag_candidate_expired`、`transaction_start_valid_o` | 已完成（C08 V1.13） |
| BMI-008 | OLR §8.4-5 L-3；LCN | §8.2 IDAC候选提交安全边界；FSC-19/38相关行 | 一级 | 第4种IDAC边界：启动搜索空闲边界。RTL锚点：`flag_idle_idac_safe_boundary`、`idac_code_safe_boundary_o`；FSC-19恢复`@satisfies`见BMI-160 | 已完成（C08 V1.13） |
| BMI-009 | OLR §8.4-5、§7.2 F-7；BR§3.6 | §10.4；§18 FSC-54 | 一级 | 作废释放（R3）：作废置失败的是**当前宏帧**，不是owner所在帧；owner跨帧时与作废事务起始帧不同。RTL锚点：`flag_owner_lost_match` | 已完成（C08 V1.13） |
| BMI-010 | OLR §8.2、§8.4-5 | §13.4/§13.7 端口表 | 一级 | 加输入`i_adc_transaction_lost_event`、`i_idac_boundary_request`（位宽、方向、复位语义按RTL） | 已完成（C08 V1.13） |
| BMI-011 | OLR §8.4-5 | §16.2 START | 一级 | 写明调度器sticky按§16.2在新START清零，而AMI历史诊断（含lost sticky）在新START不清，两套规则并存 | 已完成（C08 V1.13） |
| BMI-012 | F009 §9.4-5；BR§3.3、§3.7 | 别名表（见BMI-133） | 一级 | TB标签FSC-14 ↔ 合同FSC-03 | 并入BMI-133（C08 §19已写指针） |
| BMI-013 | BR§3.9-2；F9R §5修法3 | §12.3 校准物理宏帧完成 | 一级 | 写明"物理校准宏帧结束事实"指本阶段内出现过的任一次`o_calibration_frame_complete_event`，不要求晚于本阶段最后一笔样本 | 已完成（C08 V1.13） |
| BMI-014 | IDG §6.1、§10；IDF P/G；ABCD F-046；BR§3.3 | §18、§19（:1206"必须真实覆盖FSC-01至FSC-57"） | 一级 | 不在C08建对照表；FSC-58~62不登记。订正G1：原文保留（删除线），改为"单元TB按别名表对照覆盖，缺口见…"；FSC-19/23/24/27/44无证据、FSC-35部分（BMI-015）如实写 | 已完成（C08 V1.13） |
| BMI-015 | SSW18 §5-2；BR§3.3 | 证据状态说明处（§18/§19） | 一级 | FSC-35改判"部分"（RAW-12分辨不出5000/5001）；F-009+F-011后完整证据由TB FSC-14（=合同FSC-03）提供的说法按RTL/TB现状核实后写入 | 已完成（C08 V1.13） |

## 2. C09 SSW（`PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md`，基线头部V1.10）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-020 | BR§3.5；OLR §8.4-4；SSW18 S1；IDF §1.4 | §10 SSW-18验收行（约第835行） | 一级 | 按S1改写：迟到诊断只置sticky，不终止burst；条件是"本子帧校准owner在tick 385仍未完成"，owner与子帧绑定。RTL锚点：`calibration_timeout_sticky_o`、`reg_owner_cal_subframe` | 已完成（C09 V1.11） |
| BMI-021 | BR§3.5 | §5.4 IDAC候选码提交（约第373行"若当前结果未能在local tick 385前…"） | 一级 | 改写为：迟到结果由三道防护挡住，不复用旧码；明文写出前提"ADC在Q3（tick 266）已完成采样，迟到的只是读出" | 已完成（C09 V1.11） |
| BMI-022 | BR§3.5 | §7.8 状态与诊断输出（`o_calibration_timeout_sticky`，约第602行） | 一级 | 端口说明按S1改写 | 已完成（C09 V1.11） |
| BMI-023 | OLR §8.4-4 | §10 SSW-16/17/42；§5.3 | 一级 | 加作废释放（R3）；SSW-42作废释放/错配。RTL锚点：`flag_owner_release`、`flag_done_mismatch` | 已完成（C09 V1.11） |
| BMI-024 | OLR §8.4-4；L-1 | §5.3；§10 SSW-34/38 | 一级 | owner与帧/子帧绑定写入正文。RTL锚点：`flag_red_has_owner`/`flag_ir_has_owner`/`flag_cal_has_owner` | 已完成（C09 V1.11） |
| BMI-025 | OLR §8.2、§8.4-4 | §7.6 ADC完成与空闲输入 | 一级 | 端口表加`i_adc_transaction_lost_event` | 已完成（C09 V1.11） |
| BMI-026 | F009 §9.4-4；BR§3.7 | §8.2 STOP / §8.3（START恢复处） | 一级 | L-6规则：新RUN的START确认时，若无在途owner且ADC空闲，作废上一RUN残留的未提交RED/IR/CAL波形上下文和停止挂起，与abort一致；前提：STOPPING完成要求ADC空闲且数据链排空。RTL锚点：`flag_start_restore`。是否给编号见BMI-027 | 已完成（C09 V1.11） |
| BMI-027 | BR§3.7、§3.3；统筹§20-3 | §10 验收表 | 一级 | **给L-6新增C09验收编号**（统筹裁定：流片前逐ID动态闭环按验收表进行，无编号会漏掉这个曾经的静默卡死）。编号按§13.3规则：先查矩阵§13、C09验收表与全仓，确认未占用、无歧义；别名表登记SSW TB本地标签`L6-START`→新编号 | 已完成（C09 V1.11） |
| BMI-028 | ABCD §12.8 F-035 | §10 SSW-22；§8.3 | 一级 | 补"abort与匹配完成同拍时完成优先释放"（abort仍取消波形和结果资格）。RTL锚点：`adc_owner_inflight_o`（`@satisfies: SSW-22`） | 已完成（C09 V1.11） |
| BMI-029 | IDF G2；IDG S7 | §10（:878"SSW-01至SSW-52全部真实PASS"） | 一级 | 订正状态/门禁声明：SSW-18当前无同义检查（置1检查按BR§8不在本批补） | 已完成（C09 V1.11） |
| BMI-030 | ABCD §10(b) F-047 | 文件头（第3行V1.10与第7行sole V1.9）、依赖表 | 一级 | 随本批升版统一版本号与依赖表绑定 | 已完成（C09 V1.11） |

## 3. C10 AMI（`PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md`，基线V2.4）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-040 | OLR §8.4-1 R3；BR§3.6 | §7.1 内部ADC在途所有权；§7（"只有真实DONE释放owner"正文）；§17 AMI-39/AMI-40 | 一级 | 加超时作废规则：T-lost=4500拍从owner start fire起计年龄，ADC物理空闲且无捕获在途才作废；AMI为唯一裁决点；作废拍的序号语义；作废后旧DONE按无owner捕获被拒并升级；k=2按RED/IR/CAL槽位分别计数，同槽位真实完成清零。RTL锚点：`cnt_owner_age`、`flag_owner_lost_fire`、`cnt_lost_red/ir/cal`、`flag_owner_lost_limit_reached` | 已完成（C10 V2.5） |
| BMI-041 | OLR §8.2、§8.4-1；§7.2 F-6；BR§3.6 | §6.1 参数；§6.5a 或§6.9 端口表 | 一级 | 加`o_adc_transaction_lost_event`、`o_owner_lost_sticky`；参数`C_ADC_COMPLETION_LOST_CYCLES`、`C_ADC_COMPLETION_LOST_LIMIT`冻结为固定值4500/2，合法范围LIMIT 1~15、CYCLES<32768 | 已完成（C10 V2.5） |
| BMI-042 | OLR §8.2"端口语义扩展" | §6.5a ADC可靠完成旁带输出 | 一级 | `o_adc_complete_sample_index`在作废拍也有效；全部接收方以事件限定（调度器`flag_completion_match`/`flag_owner_lost_match`、SSW`flag_owner_release`/`flag_done_mismatch`） | 已完成（C10 V2.5） |
| BMI-043 | OLR §8.4-1；BR§3.6 | §6.10 discard原因表 | 一级 | 加`2'b11` COMPLETION_LOST（2位字段最后一个空位，以后新增原因须加宽字段）；作废discard身份取owner启动快照、`sample_valid=0`、对校准owner也发。RTL锚点：`DISCARD_REASON_COMPLETION_LOST` | 已完成（C10 V2.5） |
| BMI-044 | ABCD §12.8 F-019 | §6.10 | 一级 | discard身份取自正式输出当前持有的结果（`result_*_o`） | 已完成（C10 V2.5） |
| BMI-045 | OLR §8.4-1；§7.2 F-4；BR§3.6 | §6.11 AMI local fault-record arbitration（约第657~659行） | 一级 | 分发器扩为七路；改写F-4点名句：lane 01/02/03/06/07在START、abort、"RUN已由STOP结束且AMI排空"时清零，新故障置位优先。RTL锚点：`flag_ami_fault_dispatch_06/07`、`flag_run_context_drained` | 已完成（C10 V2.5） |
| BMI-046 | ABCD §12.8 F-022/N-1；OLR §8.4-1；BR§3.4 | §15.1 integration协议sticky | 一级 | 清除条件："无活跃集成阻断（`!flag_integration_blocking`），或当前RUN已由STOP结束且AMI排空"；START不清；`o_owner_lost_sticky`清除规则同N-1，START不清。RTL锚点：`flag_run_context_ended` | 已完成（C10 V2.5） |
| BMI-047 | ABCD §12.8；OLR §8.4-1、§8.4-10；BR§3.6 L-5、§3.12-2、§3.12-4、Q5 | §15.2 blocking fault；§6（lane生命周期） | 一级 | 按最终RTL直接写（不写过程）：STOP结束且排空后各lane与`o_ami_fault_active`落下；`o_wrapper_fault_blocking`仍含`flag_integration_blocking`，只在复位/START/abort清零（与OLR §8.4-1原文不符，按RTL写并在报告列差异）；历史诊断保留、可诊断清除；L-5修复在当前生产构建的系统级不可观测（supervisor abort先清lane），属纵深防御 | 已完成（C10 V2.5） |
| BMI-048 | OLR §8.4-1；§7.2 F-3；BR§3.6 | §6.4 ADC异步物理结果输入或§7（新增"捕获窗口前提"） | 一级 | 约2拍竞争窗口写成合同前提：窗口内到达的完成先被作废，之后按无owner捕获被拒并升级，可经STOP→诊断清除→COMMIT→START恢复；作废后在下一笔start当拍或之后到达的旧DONE会绑定新事务，错绑结果以success=1正式输出（F-3）；不改`async_stage_capture` | 已完成（C10 V2.5） |
| BMI-049 | OLR §8.4-1；§7.2 F-1、F-2；BR§3.6 | 已知限制（§15.2或§16后） | 一级 | ① 同槽位间歇丢失、从不连续丢两次时不升级（每次有discard 11与lost sticky）；② F-1：双光IR丢失与精度切换挂起同帧时，作废约mt4810晚于提交点mt4760，10000拍后切换超时报cause 04→abort+STOP，诊断清除后可重启（"单次丢失不升级"的例外）；③ F-2：第k次作废落在STOP排空末尾时lane 06只保持1拍，cause 06在回到CONFIG后才开episode，manager记0x0C，START前须先诊断清除 | 已完成（C10 V2.5） |
| BMI-050 | OLR §8.4-8；§2.2；BR§3.6 | §3 集成模块范围（S1冗余校正器部分）或对应小节 | 一级 | 冗余校正器新端口`i_transaction_abandon`、布防丢弃规则（`flag_capture_drop_armed`/`flag_capture_drop`）、`o_capture_ready`在布防期间可接收并丢弃、三种时序（OLR §2.2） | 已完成（C10 V2.5） |
| BMI-051 | ABCD §12.8 F-021 | §8.4 NORMAL双分支 / §10.2 检测分支 | 一级 | 补"检测分支自有样本资格"。RTL锚点：`flag_detection_branch_sample_valid` | 已完成（C10 V2.5） |
| BMI-052 | OLR §8.2 | §11 校准请求仲裁 | 一级 | `flag_calibration_request_inflight`清零源加入撤销合并（`flag_calibration_request_withdraw`、`flag_recheck_request_withdraw`），与F-020一致（见BMI-090） | 已完成（C10 V2.5） |
| BMI-053 | ABCD §12.8 F-002/F-008；F28 §3；BR§3.4 | §6.7 正式PPG测量输出（`o_measurement_result_discard_*`）；§8/§9中`i_datapath_discard_*` | 一级 | 收窄为RTL实际6字段`frame_id`、`sample_index`、`color_ir`、`frame_type`、`precision`、`run_generation`（正式结果组另有`sample_valid`）；改用缩小身份组名（拟`TXN_KEY`，见BMI-120）；措辞"在16位计数回绕窗口内唯一"；"按代际匹配（generation-scoped），身份字段仅作诊断" | 已完成（C10 V2.5） |
| BMI-054 | IDF G4/G5；IDG S1 | 文件头:27/:30；§18 门禁（:1282）；:1340 | 一级 | 范围订正："AMI-46至AMI-55"→表格实际上限AMI-54；"AMI-01至AMI-52全部真实比较PASS"与表格/单元TB不一致；"45项真实比较且全部PASS"加限定（AMI-13同号不同义、27条部分覆盖） | 已完成（C10 V2.5） |
| BMI-055 | IDF §1.1 T1；IDG §8 | §17 AMI-13 | 一级 | 合同AMI-13记为"无动态证据"（只有RTL结构`flag_result_fork_all_released`）；TB标签改名见BMI-142 | 已完成（C10 V2.5） |
| BMI-056 | IDG §8 AMI-24 | — | 登记 | AMI-24可能空真（`!o_wrapper_fault_blocking || !o_transaction_start_ready`在无阻断时恒真），需改TB判定，按BR Q6只登记、交收尾计划 | 不做（改TB判定，BR Q6） |
| BMI-057 | ABCD §12.8"观察项" | AMI约2085行注释"overlap只比较该字段" | RTL疑点 | 注释与实现不符（F28 §1旁注），不在BR§3.9点名范围，不改；写入报告"RTL疑点"一节 | 不做（只登记） |
| BMI-058 | 阶段2改写C10时发现（RTL核对） | C10 §6.11私有datapath discard扇出 | 一级 | 原文写扇出到NORMAL fork、Router、overlap、reconstructor和DC recovery；RTL中只有`ppg_normal_transaction_fork`与`ppg_adc_pipeline_overlap_corrector`有`i_datapath_discard_*`端口。按RTL订正，其余各级的清除方式指向各自合同（C12/C14/C15）；矩阵对应行（约第637行）随矩阵提交订正 | 已完成（C10 V2.5） |

## 4. C13 / C01 / 矩阵§1.1 身份组（F-002/F-008）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-060 | ABCD §12.8；F28 §3；BR§3.4 | C13 §4 保留载荷（§4.1） | 一级 | `i_datapath_discard_*`收窄为6字段；"For a matching retained transaction"改写为按代际匹配，身份字段仅诊断（`overlap`/`fork`只用`i_datapath_discard_event`与`run_generation_o == i_run_generation`） | 已完成（C13 V1.3） |
| BMI-061 | ABCD §12.8；F28 §3 | C01 公开端口表（§4） | 一级 | `o_measurement_result_discard_*`收窄（7字段，含`sample_valid`） | 已完成（`9c6c0dc`，C01 V1.18：公开discard组改为`TXN_KEY`，与RTL 7字段一致） |
| BMI-062 | ABCD §10(b) F-004 | C13（Router `local_empty`描述） | 一级 | Router无always、无该端口，与C12:65矛盾；按RTL订正 | 已完成（C13 V1.3） |
| BMI-063 | IDG §7、§10 OVL；统筹§20-1 | C13 §7 验收用例 | 一级 | 在C13 §7登记OVL-01~17。每条须对应C13已有规则或RTL实际行为；对不上的标"仅TB检查"，不硬登记 | 已完成（C13 V1.3） |
| BMI-064 | 阶段2改写C13时发现（RTL核对） | C13 §4.1 `o_local_empty`消费关系 | 一级 | 原文写AMI是`o_local_empty`的唯一消费者并用于`o_datapath_empty`；RTL中AMI只把fork/overlap的`o_local_empty`接出供观测，`o_datapath_empty`用各级`o_result_valid`（经`o_measurement_output_idle`）汇总，对单元素缓存语义相同。按RTL订正C13；C10 §6.11的汇总式按语义保留 | 已完成（C13 V1.3） |

## 5. C16 / C18 重检、PWI

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-070 | BR§3.9-1；F9R §5修法3；BR§3.12-1；OLR §8.4-6 | C16 §9.4 流程图；必要时§17、§18 | 一级 | "第1/2/3个9-bit校准帧"→"第1/2/3个校准阶段"；每个阶段从新的物理校准宏帧开始；跨宏帧延长（C08 §9.6）或跨宏帧重试之后，下一阶段可在同一物理校准宏帧的后续子帧开始；下一阶段首样本用上一阶段最终已提交的码。OLR §8.4-6"每个重检阶段在新的校准宏帧sf0开始…"按此覆盖 | 已完成（C16 V2.2） |
| BMI-071 | OLR §8.2、§8.4-6 | C16 §9（端口）/§13；C18 §5 端口表 | 一级 | 新输入`i_calibration_request_withdraw_event`（PWI、重检调度器） | 已完成（C16 V2.2/C18 V2.2） |
| BMI-072 | OLR §8.4-6；ABCD F-020 | C16 §9；C18 §8 重检事件连接 | 一级 | F-020撤销规则：AMB重检inflight在未建立owner的截止时由撤销释放。RTL锚点：重检调度器撤销释放（`@satisfies: SID-05`保留） | 已完成（C16 V2.2） |
| BMI-073 | ABCD §10(b) F-043 | C18（窗口长度的直接消费者） | 一级 | 直接消费者写成PWC，但PWC无这两个端口；按RTL订正 | 已完成（C18 V2.2） |
| BMI-074 | IDG S3、S4；IDF G3 | C18 :3、:10、:690（"PWI-01至PWI-10""PWI-06至PWI-10"）；§14 :659 | 一级 | 范围订正为表格实际上限PWI-08；门禁"PWI-01至PWI-07全部真实比较PASS"改为单元TB实际PWI-01~05，PWI-06/07/08状态如实写 | 已完成（C18 V2.2） |
| BMI-075 | IDG S5 | C23 §21 / C18 §13 | 一级 | PWI-01~05在C18与C23重复定义：在C23 §21标注"PWI-01~05以C18为准" | 已完成（C23 V2.7） |

## 6. C17 IDAC（`PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md`，基线V2.3）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-080 | ABCD §12.8 F-032；BR§3.4 | C17端口表；矩阵约第2032行 | 一级 | RTL已改名为`i_diag_clear_event`。C17正文已是此名（基线C17中3处）；矩阵第2032行登记的RTL名`i_status_clear_event`改为`i_diag_clear_event`并换符号锚点 | 已完成（C17 V2.4；矩阵行待矩阵提交） |
| BMI-081 | BR§3.9；ABCD F-033；IDF §1.3 T3；F9R §7-2 | C17 §8.4末句（第503行） | 一级 | "AMB码未实际改变时不得产生`o_dcs_revalidate_request`"与C16 §9.6/§18、RTL相反，按C16改写（`o_dcs_revalidate_request = (state_current == ST_DCS_REVALIDATE_WAIT)`，窗口内也进入该状态） | 已完成（C17 V2.4） |
| BMI-082 | IDF §1.3；BR Q6 | C17 §15 IDC2-17（第670行） | 一级 | 同BMI-081的同一问题，订正为"周期AMB在窗口内仍请求两色DC重验" | 已完成（C17 V2.4） |

## 7. C23 精度窗口控制器（基线V2.6）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-085 | OLR §8.4-9；§7.2 F-1；BR§3.6 | §15 两帧切换超时保护 | 一级 | F-1例外：双光IR丢失与精度切换挂起同帧→作废晚于提交点→切换超时cause 04→abort+STOP→诊断清除后可重启 | 已完成（C23 V2.7） |
| BMI-086 | ABCD §12.8 F-034 | §14 新事务阻断和提交原子性 / §16 优先级 | 一级 | 补"commit与当前代际撤销同拍时撤销优先"（与既有冻结优先级一致）。RTL锚点：两处commit（`@satisfies: PWC-27`） | 已完成（C23 V2.7） |

## 8. C24 supervisor（`PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md`，基线V1.5）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-090 | OLR §8.4-3；BR§3.6 | §3 Fixed Encoding | 一级 | 原因表加`8'h06`（同槽位连续丢失，summary bit 9）、`8'h07`（owner在途≥9000拍、ADC仍不回idle，summary bit 10），source均`4'h1` | 已完成（C24 V1.6） |
| BMI-091 | OLR §8.4-3 | §5 Recovery and Diagnostic Clear（AMI active fault下降条件） | 一级 | 补"abort、START、RUN结束排空" | 已完成（C24 V1.6） |
| BMI-092 | OLR §8.4-3 | §6 ADC Physical-Drain Watchdog | 一级 | 补"超时作废不属于伪造"；写明RUN中/排空中丢失与长期忙的处理及不卡死保证 | 已完成（C24 V1.6） |
| BMI-093 | OLR §8.4-3；BR§3.6 F-1/F-2 | §5 恢复流程 | 一级 | F-1、F-2写入恢复流程（同BMI-049） | 已完成（C24 V1.6） |
| BMI-094 | ABCD §12.8 F-014/F-024；BR§3.4 | §1 Ownership and Parameters | 一级 | 参数冻结为产品固定值（看门狗5000/13），F-014条款改写为"固定值+仿真开始检查合法性"；检查所在TB：supervisor单元TB `WDPARM` | 已完成（C24 V1.6） |
| BMI-095 | ABCD §10(b) F-051 | §2 端口表（`i_rstn_2m`） | 一级 | RTL端口为`i_rstn`，订正 | 已完成（C24 V1.6） |
| BMI-096 | IDG S10、§10 | SUP-10（:161） | 一级 | 内容"AMI本地保留fault-discard原因"归C10 AMI-53：标注"归C10 AMI-53"（不删行，避免改变编号） | 已完成（C24 V1.6） |
| BMI-097 | IDG §6.2、§10；OLR §8.3 P09 | §7 Required Evidence | 一级 | 证据状态订正：SUP-05/08无/部分证据，SUP-03/09/10的TB子标签同号不同义（改名见BMI-141）；P09（summary映射）恢复`@satisfies`见BMI-160 | 已完成（C24 V1.6） |

## 9. C25 测试合同（`PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-100 | OLR §8.4-2 | LFA-04 | 一级 | 同AMI-39，加超时作废例外 | 已完成（C25 V1.8） |
| BMI-101 | BR§3.9；F9R §7-3 | SID-04（约第552行） | 一级 | "Every evaluated candidate uses eight physical SAR9 subframes"与RTL不符：每个候选只取一笔样本、相邻候选相隔一个子帧（625拍）。核对RTL与TB SID-04 PASS行后订正 | 已完成（C25 V1.8） |
| BMI-102 | IDG §4、§8、§10；BR Q6 | PRC-05/08 | 登记 | PASS行是无条件`$display`引用其他TB证据；改为INFO会改变PASS行数，按BR Q6只登记、交收尾计划 | 不做（改PASS行数，BR Q6） |
| BMI-103 | IDG §6.5、§10 | LFA-11 / TB `LFA-11a` | 一级（合同侧）＋TB标签 | 合同LFA-11前半句无断言如实写；TB子标签LFA-11a改本地名（属§9.5.1规则5/P03）。"informational分支不再打印PASS"会改PASS行数，只登记 | 已完成（标签AUTOABT-QUIET，阶段3提交）；PASS行只登记 |
| BMI-104 | IDG §8 E类、§10 | RAW↔RGC | 一级 | 在别名表加RAW-01~11 ↔ RGC-01~15对照行（数据来自TB原文） | 已完成（`fd348d2`） |
| BMI-105 | BR§5（C25：FSC/SUP/RRC编号治理） | RRC等 | 一级 | C25中涉及FSC/SUP/RRC的编号引用，随BMI-140/141核对；RRC族IDG判A，预计只需核对不改 | 已完成（`c15e648`：C25无需改；C24 V1.6证据指针补新标签名） |

## 10. 芯片顶层合同（`PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md`）与C01

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-110 | ABCD §12.5、§12.8 F-030；BR§3.4 | 芯片合同§8 SPI协议参数（CS_N条款）；§7 CDC路径总表 | 一级 | CS_N作协议异步复位/门控，不加同步链；写入四点论证：① 只有7个协议状态寄存器被CS_N异步清零（列名），其余列明不受影响；② 接口时序要求t_su(CS)/recovery、t_h(CS)、t_cs_high；③ 传输中途CS_N毛刺的剩余风险→板级SI要求、写后读回校验；④ 命令与写入在第8个SCLK上升沿`flag_write_commit`产生，不被CS_N截断 | 已完成（芯片顶层V1.17） |
| BMI-111 | OLR §8.4-7；BR§3.6 | 芯片合同§11 SPI地图；C01端口表 | 一级 | 新输出`o_ami_owner_lost_sticky`（C01）；0x0108 bit6 = AMI owner lost sticky，bit7仍保留；SPI `i_ami_owner_lost_sticky` | 已完成（芯片顶层V1.17/C01 V1.18） |
| BMI-112 | OLR §8.4-7 | 芯片合同§11 诊断地图 | 一级 | 逐位写明清除方式：调度器sticky在START清；AMI历史（含0x0108 bit6）只由复位或诊断清除清；supervisor summary/cause只由复位或合法诊断清除清零（cause是首故障快照，新捕获时覆盖），START不清 | 已完成（芯片顶层V1.17） |
| BMI-113 | ABCD §12.8 F-014/F-024；BR§3.4 | 芯片合同参数节；C01参数/§9 | 一级 | 冻结产品固定值：C_CONFIG_WIDTH=1024，config/coef/DC-recovery epoch=8，code epoch=4，generation=8，frame/sample=16，看门狗5000/13；检查所在TB：smoke `tb_ppg_control_top.v`（PARAM-FIXED、PARAM-WDOG）、`tb_ppg_chip_digital_top.v`、supervisor单元TB WDPARM | 已完成（芯片顶层V1.17/C01 V1.18） |
| BMI-114 | ABCD §12.8 F-005/F-006 | 芯片合同§8.1 | 一级 | 规则无需改；读路径实现说明更新为"字节边界后下降沿装载"（`ST_DATA`且cnt==0的下降沿装载，去掉+1补偿） | 已完成（芯片顶层V1.17） |
| BMI-115 | ABCD §10(b) F-007 | 芯片合同正文（V1.16的:55/66-67/82/84/103） | 一级 | 正文仍写两路reset_sync，RTL只有一个实例；按RTL订正 | 已完成（芯片顶层V1.17） |
| BMI-116 | ABCD §10(b) F-048 | C01 §4.1"only四路" | 一级 | Top有5路`.i_diag_clear_event(flag_diag_clear_event)`（含CCC），订正 | 已完成（C01 V1.18） |
| BMI-117 | IDF P1；IDG S7 | C01:38 | 一级 | "Scheduler FSC-01～57、AMI-01～45和SSW-01～52均已有当前单模块PASS证据"订正（原文删除线保留） | 已完成（C01 V1.18（属历史行，写说明不改原文）） |
| BMI-118 | ABCD §12.8 F-044 | 矩阵P06行；C01相关 | 一级 | P06注明系统级合法RUN下不可达（Top RUN锁存），证据范围只到AMI叶子级（LEAF-HOLD） | 已完成（矩阵V4.5） |

## 11. 矩阵（`PPG_CONTRACT_CLOSURE_MATRIX.md`）

| 编号 | 来源 | 目标节 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-120 | BR§3.4；F28 §3 | §1.1 身份组展开 | 一级 | 另立`TXN_KEY`（6字段；正式结果组另加`sample_valid`），与完整`TXN_ID`分开；检测丢弃组与owner/完成组仍用`TXN_ID`。命名前按BR§3.3先查§13与全仓 | 已完成（矩阵V4.5） |
| BMI-121 | IDF R2；IDG §6.2 | P05行（约:927） | 一级 | 去掉"SUP06A"作为看门狗证据 | 已完成（矩阵V4.5） |
| BMI-122 | ABCD §10(b) F-003；BR§3.2、Q1 | 全表证据/锚点列 | 一级 | 并入符号锚点一次性转换（BMI-150~153） | 已完成（并入BMI-151，`1fab116`） |
| BMI-123 | ABCD §10(b) F-045；BR§3.2 | §12.4a 26-file Baseline Manifest | 工具 | 摘要改脚本生成（BMI-171），阶段5执行 | 已完成（经BMI-171，`5d294db`） |
| BMI-124 | BR§3.11；IDG §9 | §13.1/§13.2/§13.3 | 一级 | §13.3规则正文抄自BR§3.11；§13.2补记核对脚本盲区（29族不在ID正则内、TB修订记录伪ID）；§13.1快照数字随刷新更新 | 已完成（矩阵V4.5（§13.2/§13.3；§13.1刷新在阶段5）） |
| BMI-125 | 各合同升版 | §12.4 版本登记表 | 一级 | 本批次升版的合同同步登记新版本与符号锚点（取代"C08:57-C08:65"式行号区间） | 已完成（版本联动提交8b2b259（行号区间锚点在阶段4转换）） |
| BMI-126 | IDF §3.4 H1 | :947、:3724、:3731、:3736（旧"AMI-46/47"） | 三级 | 历史叙述，按用户决定不改 | 不做（历史叙述） |

## 12. 别名表（`PPG_ALIAS_MAPPING_TABLE.md`）

| 编号 | 来源 | 目标 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-130 | IDF R1 | P05行（约:466） | 一级 | 去掉SUP06A作为5000周期看门狗证据 | 已完成（`fd348d2`） |
| BMI-131 | ABCD §10(b) F-050 | SID-11行（约:148） | 一级 | 仍标SKIP、结构不可达；基线日志有`PASS SID-11`，按现状订正 | 已完成（`fd348d2`） |
| BMI-132 | ABCD §4 F-003 | 约第58行出处`MATRIX:872` | 一级 | 失效出处，并入锚点转换（BMI-151） | 已完成（`1fab116`，改为矩阵§9.2） |
| BMI-133 | F009 §9.4-5；BR§3.3 | 新增对照行 | 一级 | TB FSC-14 ↔ 合同FSC-03；TB FSC-32 ↔ 合同FSC-30（实参N不改，BR Q3）；其余调度器TB检查→合同条目对照（数据取IDG §5.2 FSC列，阶段3重扫后复核） | 已完成（阶段3提交，草稿行已写入别名表） |
| BMI-134 | ABCD §12.8；OLR §8.2；F009 §9.3 | 新增对照行 | 一级 | 三轮新增TB本地标签的映射：MGR-11、CAL-ROLLOVER-*、HIST-*、DISC-HELD、DET-QUAL、LEAF-HOLD、ABT-DONE、CANCEL-COMMIT、RETURN-HOLD、WDPARM、PARAM-*、DIAG-MAP38、CMD-STOP-PRIO；LOST-*、L1-*、L4-*、L3-*、BIND-Q3、S1-*、LSTK-*、K-*、WIN-*、BUSY-*、WDRAW-LOST、LOST-EXCL、F020-WDRAW、SUM-06/07、S1-ABANDON、LOST-SPI-*、SYS-*（37项）；FRAME-*、RESTART-*-SCAN、L6-START、SYS-RESTART-SCAN-*。无合同ID的如实填"无映射" | 已完成（`fd348d2`）；依赖TB改名的行在草稿中（`affd3e3`） |
| BMI-135 | IDG §10；统筹§20-4 | IDC2/CIS/AV4/CF4（整族无TB编号） | 一级 | 本批做**族级登记**（"整族无TB编号、证据分散于…"）；逐条对照**不进**POST_TAPEOUT清单，改列"流片前验证收尾计划"（BMI-910） | 已完成族级登记（`fd348d2`）；逐条对照见BMI-910 |
| BMI-136 | IDG §7、§10 JNT；OPTC；统筹§20-1、§20-2 | 别名表；C21 | 一级 | JNT：别名表注明；先查`PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md`，已定义的JNT项映射到该文档章节，未定义的注明"TB定义"。OPTC-01/02：在C21登记，须对应C21规则或RTL实际行为，对不上的标"仅TB检查" | 已完成（别名表`fd348d2`，JNT按联合TB说明§11/§5.3；OPTC在C21已有登记） |

## 13. 编号治理：TB标签改名（只改格式串/字符串，BR§3.3、Q3）

| 编号 | 来源 | 目标TB | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-140 | IDG §6.1、§10；IDF §4；ABCD F-046；BR Q3 | `tb_ppg_400hz_frame_calibration_scheduler.v` | TB标签 | `check_fsc(N,…)`不改实参，只把打印前缀改为TB本地名（命名先grep避撞号）；横幅`ALL FSC-01 THROUGH FSC-62 PASSED`、`FSC-01 through FSC-62: pass=…`同步改；FSC-32≡合同FSC-30只登记别名表 | 已完成（阶段3提交，SCHT-n） |
| BMI-141 | IDG §6.2、§10；统筹§20-5 | `tb_ppg_system_fault_abort_supervisor.v` | TB标签 | SUP03A/06A/09A/10A：**一律改TB本地名**；只有重扫确认含义与某合同条目完全一致时才用该合同编号，不用"合同号+后缀"（如SUP07B、SUP06D）。横幅"SUP-01 through SUP-10 PASS"改为实际覆盖 | 已完成（阶段3提交，CLRBLK/EPICLS/WDIDLE/EPI2ND） |
| BMI-142 | IDF §1.1、§4 | AMI单元TB `AMI-13` | TB标签 | 改TB本地名（实测反压保持） | 已完成（阶段3提交，FORK-HOLD） |
| BMI-143 | IDG §6.3、§10；BR Q3 | `tb_ppg_adc_dc_recovery.v` `drive_and_check`第3~7号 | TB标签 | test_id参与生成激励，不动；若FAIL标签由test_id拼出则只改格式串前缀，做不到就只在别名表登记；横幅"DCR-01..DCR-22"改为实际覆盖 | 已完成（阶段3提交，FAIL格式串前缀DCRT-；test_id未动） |
| BMI-144 | IDF §1.4、§4 | SSW TB的SSW-18场景 | TB标签 | 改本地名（实测校准owner截止，属SSW-37/38） | 已完成（阶段3提交，CAL-ODL） |
| BMI-145 | IDG §4、IDF §3.5 | MGR/PR/RTR/CAL/CCC/OVL/AV4C区间横幅 | TB标签 | 视重扫结论，只对"区间含无同义检查条目"的横幅改为实际覆盖；FSC/CCC/ADCN补零不一致随改名处理 | 已完成（`c15e648`：只有MGR需改；PR/RTR/CAL/CCC/OVL/AV4C不改，理由见提交说明与`tb_rename_bmi145.py`） |
| BMI-146 | BR Q3；IDF §3.5 | `tools/run_unit_tb_regression.sh` | 工具 | 同步依赖横幅文字的判据正则；回归证明判定数与`$finish`不变 | 已完成（阶段3提交，4条横幅正则）；判定数与`$finish`不变待终版回归证明 |
| BMI-147 | BR§6.3 | 扫描器重跑 | 工具 | 从IDG附录A提取扫描器与`rescan_diff.py`；先对`2a90a69`生成基线`tb_sites.json`，再对`7a8eabf`扫描；逐条复读报出项（含当时31处"B?"） | 已完成（`9e932d6`；37处复读，只有FSC-14属新同号不同义） |

## 14. 符号锚点、RTL注释与`@satisfies`

| 编号 | 来源 | 目标 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-150 | BR§3.2 | `tools/`锚点检查脚本 | 工具 | 检查文件存在、名字/`@satisfies` ID按词边界存在（端口/信号尽量用skill formatter AST）、合同节号存在（重名按"节号+标题"）；`[[project-ppg-...]]`记忆引用单列"仓库外引用"豁免；先做负对照（人为改错几处，恰好报出） | 已完成（`anchor_check.py`；负对照`70fb907`、`fd348d2`、`1fab116`；语义模式`c0190c1`：锚点符号须等于格内写明的符号，负对照恰好报出） |
| BMI-151 | BR§3.2、Q1；§6.5 | 矩阵、别名表一次性转换 | 一级 | 已写明符号的以原文为准到基线按名定位；裸行号用`git log -L`/blame追到写入时版本取符号；追不出来标"失效锚点（无法追溯）"；G-FP-01台账的删除线/带日期条目保留；`Cxx:NNN`互引改节号；覆盖§6.5列举的各种写法与陷阱；旧→新对照表入报告附录 | 已完成（第一轮`1fab116`；第二轮`9dd4333`：带日期的现行结论一并转换；第三轮`c0190c1`：按统筹10-10核对意见做语义一致性复查，纠正247处；补正`de06123`：端口台账端口列为行主题，增量改写311处；第五轮`ce888bb`：按统筹对67707b3核对意见，格内明示被取代的旧锚点27处恢复原文归history-superseded，2147/2860两行核实行号改正19处，门禁新增1f；第四轮`4f33535`：按统筹对66bebdf核对意见，低置信56条逐条判定（改正31、恢复原文4、钉住版本2、核对确认18、dual_precision不改1），G-FP-05参数绑定与同类扩查，anchor_check新增规则1d/1e与钉住版本形式） |
| BMI-152 | BR§3.2 | 转换复核 | 工具 | 改前快照；最后读磁盘新旧文件独立复核，引用逐条配对后文字相等；复核脚本同样先做负对照 | 已完成（`anchor_verify.py`独立复核0不符，负对照4/4） |
| BMI-153 | BR§3.2 | 门禁接入 | 工具 | 检查脚本放进回归入口开头或作为独立一步，失败则整轮报错；真实回归中演示一次通过、一次负对照失败 | 已完成（`de814e7`：回归入口开头门禁，本机演示通过与负对照失败；回归机演示见REGRESSION_RUN_REQUEST §2） |
| BMI-155 | BR§3.9-3；F9R §5修法3 | `ppg_amb_recheck_scheduler.v`基线第148、215、269行注释 | RTL注释 | 按F-9语义改写（只改注释）；去注释后与基线逐字节相同；对该文件跑deliverable gate不新增问题 | 已完成（`f8986b3`；gate 0/0，去注释逐字节相同） |
| BMI-160 | OLR §8.3"本轮移除" | RTL/TB相应符号 | RTL注释 | 合同改写后，在已有实质性中文注释末尾补`@satisfies`：AMI-40（`flag_adc_transaction_inflight`作废释放、冗余校正器`flag_capture_drop`）、AMI-39与LFA-04（`adc_transaction_lost_event_o`）、AMI-24（`owner_lost_sticky_o`、L-5三个lane清零）、SUP-08（`flag_owner_lost_fault_hold`）、FSC-54（`flag_owner_lost_match`）、FSC-19（`flag_idle_idac_safe_boundary`）、SSW-42、SSW-18（S1 sticky）、P09、SID-05（只在含义一致处）。每处先核对合同新文字与实现完全一致；每个RTL文件做去注释比对与gate | 已完成（`467a8ad`：16处；SUP-08按统筹10-09裁定在C24 V1.7改写后补标签，`3570ab6`；SID-05含义不符不补） |
| BMI-161 | BR§3.10 | TB侧`@satisfies` | — | 已有TB历史PASS文本不追溯改写；TB注释中的`@satisfies`不在本批新增（TB只允许改PASS标签） | 不做（BR§0.3） |

## 15. 摘要、§13与交付工具

| 编号 | 来源 | 目标 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-170 | BR§3.11；IDG §9 | `tools/cross_reference_tools/reconcile_acceptance_ids.py` | 工具 | 路径改到本仓库`contracts/`；ID正则只覆盖22族，作辅助；约22个TB修订记录伪ID作已知误报排除并在报告列出；刷新§13 | 已完成（`f5f6e3f`） |
| BMI-171 | ABCD F-045；BR§3.2 | `tools/`摘要生成脚本 | 工具 | 按当时文件生成§12.4a的26个SHA256，放在全部合同改动之后 | 已完成（`5d294db`，HEAD上26/26相符） |

## 16. 其它合同的一级订正（ID治理与ABCD §10(b)）

| 编号 | 来源 | 目标 | 分级 | 处理要点 | 状态 |
|---|---|---|---|---|---|
| BMI-180 | IDF §1.2 T2；IDG S8 | C02 MGR-12（:349） | 一级 | 错误码0x05在RTL不可达（`ERROR_ENUM_ENCODING`只声明未使用），注明已改判0x15并由MGR-20覆盖 | 已完成（C02 V4.10） |
| BMI-181 | IDG S9 | C02 MGR-18与MGR-23 | 二级 | 两条都规定OFF→0x16，内容一致只是重叠 | 已登记（POST_TAPEOUT_DOC_CLEANUP_LIST D-01） |
| BMI-182 | ABCD §10(b) F-039 | C07（:249与:295） | 一级 | START前提与模式例外矛盾，按RTL订正 | 已完成（C07 V1.2） |
| BMI-183 | ABCD §10(b) F-015；IDG S2 | C19（FIR合同"sample_valid无定向TB"；:3、:10、:686"FIR-01~36""FIR-31至FIR-36"） | 一级 | FIR-31/32/33已PASS，订正状态；范围改为表格上限FIR-33 | 已完成（C19 V2.6） |
| BMI-184 | IDF G6 | C03 :325"AV4C-01～AV4C-19" | 一级 | 范围改为AV4C-22 | 已完成（C03 V1.7） |
| BMI-185 | IDF G7 | C21 :563、:613、:614、:665"BSL-01至BSL-28" | 一级 | 范围改为C20表格上限（BSL-40） | 已完成（C21 V1.3） |
| BMI-186 | IDG S6 | C22 PVW-47/48（:847-848多一列） | 二级 | 表格格式问题，含义无误 | 已登记（POST_TAPEOUT_DOC_CLEANUP_LIST D-02） |
| BMI-187 | IDF P2~P6 | `PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md` :16、:43、:44、:45、:420 | 一级 | 快照正文不改；在§15追加一条订正说明（IDF §3.1建议） | 已完成（核对表§15第4条） |
| BMI-188 | ABCD §12.8 F-018 | C22 §11.4 | — | 无需改，实现已对齐 | 不做（无需改） |
| BMI-189 | ABCD §12.8 F-023；§12.4 | C02 | — | C02与RTL一致，无需改；可达性订正只在ABCD报告内 | 不做（无需改） |
| BMI-190 | IDF §3.4 H3~H5 | C08:1253、C09:17、C07:13 | 三级 | 历史叙述，不改 | 不做（历史叙述） |

## 17. 排除项（只在报告中引用登记，交接书§3.8、§8）

| 编号 | 事项 | 去向 |
|---|---|---|
| BMI-900 | 生命周期报告§7.1(d)(e)(f)的后续验证与是否改RTL（(d)的合同说明仍按BMI-003写） | 流片前验证收尾计划 |
| BMI-901 | F-3附：调度器与SSW在IR提交窗口上的不一致 | 同上 |
| BMI-902 | TB容差审计（F009 §9.4-6） | 同上 |
| BMI-903 | F009 §9.4-6其余项：例外C、L-6扫描覆盖面、long_10"JNT前缀残留1笔" | 同上 |
| BMI-904 | START后IDAC码提交到第一帧接管只隔2~16拍；240拍建立预算是否足够（F9R §7-1） | 同上（模拟侧确认） |
| BMI-905 | 补测试：FSC-19/23/24/27/44、SSW-18 sticky置1检查 | 本批次之后 |
| BMI-906 | F-1实测（真实检测链触发切换） | 收尾计划 |
| BMI-907 | OLR §7.1(b)纯丢DONE变体；§7.1(c) L-5 | 用户10-09已定：纯丢DONE变体进收尾计划的逐拍扫描；L-5保留为纵深防御，不可达证明进收尾计划的形式验证 |
| BMI-908 | ABCD §11.4观察项：dynamic baseline TB的EQV追踪下降沿采样竞争；芯片层没有验收ID（既有缺口） | 只登记 |
| BMI-909 | MGR的未使用localparam `ERROR_ENUM_ENCODING`清理 | RTL注释/清理轮 |
| BMI-910 | IDC2/CIS/AV4/CF4逐条对照（统筹§20-4） | 流片前验证收尾计划（不进POST_TAPEOUT清单） |
| BMI-911 | reconcile报告E_STALE_MATRIX_TEXT 16项与B_TAG_MISSING 22项的逐ID闭环（统筹10-09裁定） | 流片前验证收尾计划V8逐ID闭环（不进POST_TAPEOUT清单）。E：JNT-01、K02、LFA-04/06/08、OIB-01/08、P16、PRC-09、PWC-40/41、SID-05/10/11、TOP-17/23；B：Acceptance-D01-01、D01、D03、G-FP-01-D01-01~03、G-FP-02-D01-01、G-FP-03-D01-01、G-FP-04、G-FP-05-D01-01、G-FP-06-D01-01/02、G-FP-07、JNT-09、L01、N07、OIB-04、P12、PRC-05、PVW-47/48、TOP-10 |
| BMI-912 | SUP-08：AMI阻断类故障cause 8'h01、8'h03经STOPPING后不复位重启的检查（终版adc_anomaly TB只覆盖8'h02/06/07） | P1补测试，用现有注入机制构造（统筹10-10核对意见），本批不做 |
| BMI-913 | 矩阵G-FP-05参数传播台账基线3369行（Top→AMI）写“bound 8 at lines 75-79,81,88-89; own-default 7 at lines 80,82-87”，基线RTL中AMI未被绑定的参数为9个（后来新增`C_ADC_COMPLETION_LOST_CYCLES`/`C_ADC_COMPLETION_LOST_LIMIT`），台账计数与行号文字未随之更新 | 锚点第四轮扩查发现；本批只改锚点（target锚点列本行写明的8个被绑定参数），计数文字交修复轮订正 |
| BMI-914 | 按名解析（resolved-by-name）锚点中262个所引行号与所取符号不符（118个超出所指文件末行，文件必然错），分布在210行；锚点第五轮核对2860行时发现 | 待统筹决定（建议合并前再做一轮：按行内上下文重定文件、按写入时版本取符号，取不到用钉住版本写法，并把“行号须在符号附近”加进门禁）；清单`anchor_conversion/round5/resolved_by_name_audit.json` |

---

## 18. 待用户/统筹裁定

阶段1提出的Q-1~Q-5已由统筹裁定，见§20。目前无未决项。报告§9所列执行中的6项判断，统筹已于2026-10-09裁定：第1项（带日期即历史）不接受，改为只保留删除线、"> "历史块、修订记录节与被明示取代的旧条目，锚点第二轮已执行；第2、3、6项接受；第4项SUP-08本批改写并补标签；第5项列入流片前验证收尾计划V8（BMI-911）。

## 19. 统计

| 分级 | 条数 | 说明 |
|---|---:|---|
| 一级 | 97 | 含BMI-012（并入BMI-133）；BMI-103另有TB标签部分，单列下行 |
| 一级（合同侧）＋TB标签 | 1 | BMI-103 |
| TB标签 | 6 | BMI-140~145 |
| 工具 | 8 | BMI-123、146、147、150、152、153、170、171 |
| RTL注释 | 2 | BMI-155、160 |
| 二级登记 | 2 | BMI-181、186；改写中发现的随手登记 |
| 三级/历史叙述 | 2 | BMI-126、190 |
| 只登记不做（改TB判定/PASS行数） | 2 | BMI-056、102 |
| RTL疑点 | 1 | BMI-057 |
| 不做（无需改/超出边界） | 3 | BMI-161、188、189 |
| 待裁定 | 1 | BMI-914（锚点第五轮发现，待统筹决定）；BMI-063、136已裁定转一级 |
| 排除项（§17） | 13 | BMI-900~912 |

## 20. 统筹审核意见（2026-10-09，经用户转达）

总表批准，进入阶段2。
1. Q-1/Q-2：同意在C13/C21补登记OVL、OPTC。每条须对应C13/C21已有规则或RTL实际行为；对不上的标"仅TB检查"，不硬登记。→BMI-063、BMI-136
2. Q-3：同意别名表注明。但先查`PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md`，已定义JNT各项的映射到该文档章节。→BMI-136
3. Q-4：给编号。流片前逐ID动态闭环按验收表逐条进行，无编号会漏掉这个曾经的静默卡死。→BMI-027
4. Q-5：本批做族级登记；逐条对照不进POST_TAPEOUT清单，改列"流片前验证收尾计划"（台账层同样重要）。→BMI-135、BMI-910
5. BMI-141：不用"合同号+后缀"写法，除非重扫确认含义与合同条目完全一致；否则一律TB本地名。
6. BMI-907：用户10-09已定，纯丢DONE变体进收尾计划逐拍扫描；L-5保留为纵深防御，不可达证明进收尾计划形式验证。
7. 基线回归若与参考值不符，在阶段3改TB标签之前停下报告；阶段2可先进行。
