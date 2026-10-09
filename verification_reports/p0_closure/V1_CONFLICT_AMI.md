# V1 同拍冲突矩阵：AMI（`ppg_adc_measurement_idac_integration.v`，对照C10、C24）

- 任务：流片前验证收尾 P0-V1，模块3/3
- 基线：main `a1ba482`；RTL V1.17（owner生命周期轮）；只读
- 方法：与前两个文件相同（skill只读分析，纯静态，没有仿真器）。合同：C10（`contracts/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md`）、C24（`contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md`）。调度器引理U1–U9见`V1_CONFLICT_SCH.md` §1。
- 范围：AMI文件本身的73个always块（1235–2065行，全部为时序块）。子模块（S1校准器、router、NORMAL fork、overlap、重构器、DC恢复、IDAC控制器、PWI、捕获、冗余校正器）各有独立文件，不在本次范围；只在追踪上游时读到它们的相关信号，并注明出处。

## 0. 常用组合量（行号为基线）

| 量 | 行号 | 定义要点 |
|---|---|---|
| `flag_adc_completion_normal_emit` / `_emit` | 950–952 | 有待发完成，且S1 detect valid（另有测试注入的abort释放支路） |
| `flag_adc_completion_success` | 964 | emit、owner匹配、`!flag_adc_transaction_abort`、`!flag_result_abort_discard` |
| `flag_owner_lost_fire` | 954 | 在途、年龄≥4500、`i_adc_idle`、无capture valid、无待发完成、无measurement discard fire、`!start` |
| `flag_calibration_request_withdraw` | 961 | `i_cal_owner_deadline_event \|\| (lost && 校准槽)` |
| `flag_start_blocked` | 979 | `!run_enable \|\| stop_ack \|\| abort \|\| abort_draining \|\| stop_result_draining \|\| o_wrapper_fault_blocking` |
| `transaction_start_ready_o` | 986 | 含`!flag_adc_transaction_inflight`、`i_adc_idle`、`!flag_start_blocked`；NORMAL要求`!normal_output_inhibit_o`与码/epoch匹配；CAL要求`flag_calibration_start_match` |
| `flag_start_payload_changed` | 988 | `flag_held_start_valid && valid && 任一载荷字段 != 首次被反压时锁存的值` |
| `flag_result_abort_discard` | 999 | `abort_draining \|\| stop_result_draining \|\| i_control_abort_event（实时） \|\| integration_blocking \|\| sys_fault_discard_pending` |
| `o_measurement_result_valid` | 1078 | `measurement_pending && !flag_result_abort_discard` |
| `flag_ami_terminal_action` | 1012 | `stop_ack \|\| abort \|\| sys_pending \|\| sys_event`（实时） |
| `flag_ami_fault_dispatch_0x` | 1013–1019 | 固定顺序01>02>03>04>05>06>07，一拍发一条 |
| `o_ami_fault_identity_valid`及身份字段 | 1206–1212 | **在发记录（dispatch）那一拍**读取`flag_adc_transaction_inflight`/`reg_adc_inflight_*`，不是在事件发生拍锁存 |

额外引理：

- **A1**：`flag_adc_completion_pending ⇒ flag_adc_transaction_inflight`。pending只在`capture_transfer && inflight`时置位（1807）。inflight只由emit清0（同一沿pending也清0，1805/1818），或由lost清0（lost要求`!pending`，954）。START与abort都不清这两个寄存器。
- **A2**：pending期间，冗余校正器的上下文已被本次capture消费（`ppg_adc_s1_redundancy_corrector.v` 325），`o_capture_ready`只剩丢弃支路（188，需要作废布防，而布防在lost之后，lost要求`!pending`）。因此pending期间不会有第二笔正常capture。
- **A3**：`flag_startup_request_source`要求`!flag_precision_calibration_valid`（973），`flag_recheck_request_source`要求它为1（976），所以“两路请求同时成立”这一协议项不可达。
- **A4**：supervisor在同一沿发出`system_abort_event_o`与`system_fault_discard_event_o`（supervisor 270–296）。discard事件直连AMI（control_top 1132），abort经Top寄存（control_top 360），所以AMI**先一拍**看到discard事件，后一拍看到abort。

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

### 1.1 ADC owner与完成旁带

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `flag_adc_transaction_inflight`（1813） | start_fire置1 > emit清0 > lost清0 | start_fire × emit/lost | (a) | ready含`!inflight`；emit按A1要求inflight=1；lost也要求inflight=1 | 否 |
| 〃 | 〃 | emit × lost | (a) | lost要求`!pending`，emit要求pending | 否 |
| 〃 | 〃 | START × 在途owner | (a) | manager START要求`i_adc_idle && i_datapath_empty`（manager 452），`o_datapath_empty`含`!flag_adc_transaction_inflight`（1192/1195）；C10 §13第5条 | 否 |
| `flag_adc_completion_pending`（1802） | emit清0 > capture置1 | emit × 新capture | (a) | A2 | 否 |
| `flag_adc_transaction_abort`（1826） | start_fire/emit/lost清0 > abort置1 | abort × emit | (b) | 同拍完成释放owner；success因`flag_result_abort_discard`含实时abort而为0（964、999），符合C10 §13 abort行“只产生success=0”。调度器P9m与SSW release在同拍同样释放owner，三方一致 | 否 |
| 〃 | 〃 | abort × lost | (b) | 作废释放，owner已不存在 | 否 |
| 〃 | 〃 | abort × start_fire | (a) | `flag_start_blocked`含实时abort | 否 |
| `adc_transaction_complete_event_o`、`adc_transaction_success_o`（1246、1259） | START清0 > emit置位 | START × emit | (a) | 同`inflight` × START | 否 |
| 〃 | — | **STOP × emit（V1-SCH-P1的AMI侧）** | **(b)，结案V1-SCH-P1** | STOP当拍`flag_stop_result_draining`尚为0（寄存，2062），`flag_result_abort_discard`中没有实时STOP项，所以同拍完成success=1。调度器（读当前DISCARD=0）计成功，SSW释放，三方一致：同拍完成按“STOP前已完成”处理。该结果随后进入数据链：STOP沿发出私有datapath flush（1012→2213、2300），STOP后`stop_result_draining=1`使测量/检测分支丢弃。C10 §13“不得产生STOP后正式结果”成立。附注见§2 V1-AMI-N1 | 是：control_top扫描STOP相对DONE取−2…+1拍，检查三方owner释放、success、正式结果与discard事件 |
| `adc_complete_sample_index_o`（1272） | START清0 > （emit或lost）装载`reg_adc_inflight_sample_index` | emit × lost | (a) | 同上 | 否 |
| 〃 | 〃 | emit但身份不匹配 | (b)，附注 | 不匹配的完成仍以**当前owner的序号**发出（1278），并清AMI在途（1818），success=0。调度器与SSW据此匹配并释放owner，同时lane 03置位、形成阻断。这是C10 §13第4条的实现方式：不借用新事务身份，只释放旧owner | 否 |
| `adc_transaction_lost_event_o`（1283） | START清0 > lost | START × lost | (a) | lost含`!i_start_ack_event`（954） | 否 |
| 〃 | 〃 | lost × STOP/abort | (b) | lost不受STOP/abort门控；调度器P9l、SSW release同拍释放；discard原因见1.3 | 否 |
| `cnt_owner_age`（1518） | start_fire清0 > 在途且<9000时递增 | — | (a) | 单一递增路径 | 否 |
| `cnt_lost_red/ir/cal`（1529/1542/1555） | START清0 > 同槽真实完成清0 > 同槽lost递增 | 真实完成 × lost | (a) | A1 | 否 |
| 〃 | 〃 | STOP | (b) | STOP不清，跨STOP保留到START；brief §3.6（k按槽位计，START不清lost sticky；计数在START清） | 否 |

### 1.2 校准请求

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `calibration_sample_valid_o`（1449） | STOP/abort/阻断清0 > fire清0 > （valid=0且inflight=0时）recheck源或startup源置1 | STOP/abort/阻断 × fire | (a) | fire需要调度器ready，ready含lifecycle；阻断经`o_wrapper_fault_blocking`→调度器`i_ami_fault_blocking`使lifecycle=0 | 否 |
| 〃 | 〃 | recheck源 × startup源 | (a) | A3（RTL 1240/1630/1934中的协议项因此不可达） | 否 |
| `calibration_frame_type_o/color_ir_o/request_reason_o`（1466/1479/1492） | valid=0且inflight=0时，recheck源优先装载，否则startup源 | 与valid同一条件、同一优先级 | (b) | 载荷与valid在同一沿成对装载，valid=1期间冻结；C10 §11.2 | 否 |
| `flag_calibration_request_inflight`（2015） | STOP/abort/阻断清0 > （accepted或withdraw）清0 > fire置1 | **withdraw × fire** | (a) | fire要求valid=1，按调度器U6，此时inflight=0。截止withdraw要求调度器`CAL_WAVE_PENDING=1`，而调度器ready要求它为0，所以不同拍；作废withdraw要求有在途校准owner，其请求在被消费前inflight一直为1，所以valid=0 | 断言：`calibration_request_fire_o → !flag_calibration_request_withdraw && !flag_amb/dcs_sample_accepted` |
| 〃 | 〃 | accepted × fire | (a) | accepted要求有校准结果，结果对应的请求在被接受前inflight=1，所以valid=0。STOP/abort之后清了inflight、owner仍在途时，结果会被`!flag_result_abort_discard`挡住（995–996） | 同上 |
| 〃 | 〃 | STOP × 调度器在STOP拍发出`o_cal_owner_deadline_event`（V1-SCH-C2的AMI侧） | (b) | STOP清0优先，结果相同；`flag_recheck_request_withdraw`（962）在同拍转送PWI，重检调度器的`flag_sample_inflight`中`flag_control_cancel`（含STOP）优先于withdraw（`ppg_amb_recheck_scheduler.v` 366–371），结果也相同 | 否 |
| `reg_inflight_color_ir/frame_type/reason`（2028/2037/2046） | fire装载 | — | — | 单装载者 | — |

### 1.3 结果分支与discard

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `flag_measurement_pending`（1989）/ `o_measurement_result_valid`（1078） | abort_discard清0 > dc_transfer置1 > transfer清0；valid被`!flag_result_abort_discard`实时屏蔽 | **abort（实时项）× 测量分支valid&&ready** | **(c) V1-AMI-C5（低）** | abort当拍valid被组合拉低，同拍的ready无法形成transfer，走discard（原因ABORT）。C10 §6.11：“A normal measurement `valid && ready` transfer wins over same-edge measurement discard.” STOP（`stop_result_draining`为寄存量）与系统故障（`sys_pending`为寄存量）同拍时transfer都能胜出，只有abort的实时项不一致 | 是：TB在abort同拍拉高`i_measurement_result_ready`，检查是transfer还是discard |
| 〃 | 〃 | dc_transfer × transfer（新结果进入的同时旧结果离开） | (b) | 置1在后胜出；`flag_dc_result_ready`要求两分支都已释放（1006–1007） | 否 |
| `flag_detection_pending`（1962） | 同上 | STOP × 检测分支向PWI交付 | (a) | STOP拍`run_enable=0`（U2），FIR的`o_result_ready`含`i_run_enable`（`ppg_coarse_detection_fir.v` 406，PWI的`i_run_enable`直连AMI `i_run_enable`），不会交付。C10 §6.11“terminal action has priority over a detection handoff”成立 | 否 |
| 〃 | 〃 | abort × 交付 | (a) | PWI的`i_normal_result_valid`含`!flag_result_abort_discard`（2740） | 否 |
| `flag_detection_branch_sample_valid`、`result_sample_valid_o`（1976、1305） | abort_discard清0 > dc_transfer装载 > transfer清0 | 同上 | (b) | 与pending同节拍 | 否 |
| `measurement_result_discard_*`（10个，1318–1445） | START清0 > measurement discard fire装载 > lost装载 | discard fire × lost | (a) | lost含`!flag_measurement_result_discard_fire`（954），作废顺延一拍 | 否 |
| 〃 | 〃 | START × discard fire | (a) | START时datapath已排空，measurement pending=0 | 否 |
| `measurement_result_discard_reason_o` | `(sys_pending \|\| integration_blocking) ? SYSTEM_FAULT : ((abort_draining \|\| abort) ? ABORT : STOP)`（1001） | 系统故障discard事件 × abort | (b) | A4：discard事件先到一拍，下一拍`sys_pending=1`，与abort同拍时选SYSTEM_FAULT，符合C10 §6.11的“system_fault > abort > stop”。附注：RTL额外把`integration_blocking`映射为SYSTEM_FAULT，合同没有写，见§4 | 否 |
| `flag_system_fault_discard_pending`（1507） | 事件置1 > datapath空时清0 | 事件 × 已空 | (b) | 置位胜出，下一拍清0；C10 §6.10 | 否 |
| `flag_detection_discard_episode_active`（1671） | trigger置1 > PWI检测链空时清0 | — | (b) | 每个episode只发一次，abort在A4的后一拍到达时不会重发 | 否 |
| `reg_result_fork_payload`（1951） | START或（abort且输出空闲）清0 > dc_transfer装载 | abort且非空闲 × dc_transfer | (b) | 装载照常，pending因abort优先而不置位，载荷不会被读出 | 否 |
| `flag_abort_draining`（2002） | START清0 > abort置1 > 链空闲时清0 | **START × abort** | (c) 并入V1-SCH-C3 | AMI中START胜出：`abort_draining=0`、`stop_result_draining=0`、`run_context_ended=0`，`flag_integration_blocking`被两者都清0；同拍的实时abort只在本拍撤销校准请求，屏蔽ready与结果。下一拍AMI按新RUN运行，与调度器一致、与SSW（abort胜出）不一致 | 同调度器C3 |
| `flag_stop_result_draining`（2057） | START清0 > STOP置1 | START × STOP | (a) | U2 | 否 |
| `flag_run_context_ended`（1940） | START清0 > STOP置1 | 同上 | (a) | U2 | 否 |
| 〃 | — | abort不置该位 | (b) | 外部abort由control_top派生drain-STOP（369→378），supervisor abort伴随STOP请求（C24 §4），所以abort之后总有STOP接着置位；L-5的排空清lane依赖于此 | 否 |

### 1.4 故障lane、阻断与sticky

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `flag_owner_protocol_fault_hold`（02，1776）、`flag_recovery_context_fault_hold`（03，1789）、`flag_owner_lost_fault_hold`（06，1568）、`flag_adc_busy_fault_hold`（07，1581）、`flag_test_identity_hold`（01，1763，仅测试构建） | START/abort清0 > 新故障置1 > 排空（`flag_run_context_drained`）清0 | 新故障 × 排空清0 | (b)/(a) | 置1优先，符合OLR §1.2 L-5“同拍新故障置位优先”。实际上这些置位条件都要求ADC链有活动（capture valid、emit、在途owner），而排空要求`o_datapath_empty`，二者不可能同拍 | 否 |
| 〃 | 〃 | START × 新故障 | (a) | 02：capture或cal start需要在途或start valid，START拍都没有；03：需要emit；06：lost含`!start`；07：需要在途 | 否 |
| 〃 | 〃 | **abort × 新故障（02/03/06/07）** | **(c) V1-AMI-C3（低）** | abort清0优先，hold保持0。但对应的`flag_ami_fault_pending_0x`（1594–1668）没有START/abort清除分支，照常置位并分发一条valid记录，此时`o_ami_fault_active`（1202）可能为0。C24 §4：supervisor只要收到valid就开episode（`flag_episode_open_edge = flag_new_any && !blocking`，supervisor 199–200），又会在“所有本地active为低”后的下一沿关闭。结果是一个立即关闭的episode：发出abort/STOP/discard，但不保持阻断。brief §3.6 F-4要写入C10的“新故障置位优先”只对排空清除成立，对START/abort不成立 | 是：AMI单元TB在abort同拍注入capture-without-owner或第k次作废，检查`o_ami_fault_valid/active`；系统TB检查supervisor episode的开闭 |
| `flag_integration_blocking`（1929） | START/abort清0 > 协议错误置1 | abort × 协议错误 | (c) 并入C3 | 同上：阻断被吞，sticky（1240，无abort分支）仍会置位 | 同上 |
| `flag_ami_fault_pending_01…07`（1616/1627/1638/1649/1660/1594/1605） | 事件置1 > 本lane分发清0 | 同lane新事件 × 分发 | (b) | 置位胜出，下一拍再发一条；supervisor在已开episode中不会产生新事件（C24 §4） | 否 |
| `o_ami_fault_identity_valid`及身份（1206–1212，组合，读取寄存器） | 在**分发拍**读取`flag_adc_transaction_inflight`/`reg_adc_inflight_*` | **lane 03置位 × 同沿emit清在途** | **(c) V1-AMI-C4（低）** | lane 03的置位条件是`emit && !match`（1641），同一沿emit把`flag_adc_transaction_inflight`清0（1818）。下一拍分发时`identity_valid = flag_adc_transaction_inflight = 0`（1206），所以lane 03的记录**永远不带身份**，尽管`reg_adc_inflight_*`仍保存着该owner。lane 06的`identity_valid`固定为1、读`reg_adc_inflight_*`：若被更高优先级lane推迟≥2拍，而新owner已经start，就会报出新owner的身份（只在多lane同时置位时可达）。C10 §6.11：“A rising event for a lane captures that lane's FAULT_ID atomically.” | 是：单元TB注入completion mismatch，检查cause 03记录的`identity_valid` |
| `integration_protocol_error_sticky_o`（1235） | **诊断清除（1238）> 新协议错误置1（1240）** | **诊断清除 × 同拍新错误** | **(c) V1-AMI-C2（低）** | 清除在前，新错误被吞。与同文件`owner_lost_sticky_o`（1297，置位在前）、调度器与SSW的sticky、C24 §4“A new fault wins over same-cycle clear”都相反。只进sticky、不进阻断的协议项（`flag_start_payload_changed`、`flag_start_context_mismatch`的NORMAL部分、`flag_router_frame_type_error`、`flag_late_normal_result`、`frame_type==2'b11`）在这种情况下不留任何痕迹 | 是：单元TB在诊断清除同拍注入frame_type=11的start valid |
| 〃 | 〃 | **调度器RED截止→IR候选，transaction valid不间断 × AMI载荷保持检查** | **(c) V1-AMI-C1（中）** | 见§2 | 是：见§2 |
| `owner_lost_sticky_o`（1294） | lost置1 > 诊断清除（hold=0或已排空） | lost × 诊断清除 | (b) | brief §3.6“同拍新作废优先” | 否 |
| `flag_held_start_valid`（1837）及9个`reg_held_start_*`（1848–1926） | valid=0或fire清0 > （valid且ready=0且未held）置1、装载 | — | (b) | 置1与装载同条件、同沿；C10 §7.4 | 否（但见C1） |

## 2. 发现详述

### V1-AMI-C1（中）RED截止到IR候选，transaction valid不间断：AMI判为“反压期间载荷变化”，置integration协议sticky

- **场景**：NORMAL双光帧中，AMI对NORMAL start一直不ready，跨越整个RED窗口。已知的正常路径是：周期重检期间，夹在校准帧之间的NORMAL帧（`normal_output_inhibit_o=1`，AMI 986）。OLR §7.1(d)实测：这些帧“出现RED/IR波形但没有owner，owner截止在283/443触发”。精度切换挂起在帧中途拉起（`switch_hold_new_transaction_o`）也属同类。
- **逐拍**：
  - **tick 1起**：调度器RED候选有效，SSW `o_adc_owner_ready`为RED候选（SSW 420、425），`transaction_start_valid_o=1`（调度器470）。AMI ready=0，第一拍锁存`flag_held_start_valid=1`和RED载荷（AMI 1842、1851…）。
  - **tick 283**：RED仍未过期（调度器469为`>283`），valid保持为1；P10在本拍清`RED_WAVE_PENDING`（调度器764–767）。
  - **tick 284**：调度器候选变为IR（调度器465），未过期（≤443）；SSW的`flag_red_owner_window`在284关闭，`flag_ir_owner_candidate=1`（SSW 421、426），所以valid**仍为1**，载荷换成IR（颜色、DC码、epoch不同）。
  - AMI的`flag_held_start_valid`从未见到valid=0，因此`flag_start_payload_changed=1`（AMI 988），285拍起`integration_protocol_error_sticky_o=1`（1240）。
  - IR在443截止后，444拍valid落下，held清0。
- **意图**：
  - C08 §10.2：“AMI反压期间，valid和全部载荷保持，直至真实握手或**本事务owner截止点到达**”——RED在283到达截止，结束RED事务后接着提出IR，在调度器看来是合法的新事务；
  - C10 §7.4与§15.1：“valid保持期间载荷变化置sticky”。
  - 两份合同各自成立，但RTL没有在两笔事务之间插入valid=0的间隙，结果在正常运行中被误判为协议错误。
- **后果**：周期重检（以及其他让AMI在整个RED窗口内拒绝NORMAL的情形）中，每个这样的NORMAL帧都会置一次`o_integration_protocol_error_sticky`。它不进阻断，但对外可见，需要诊断清除；软件会把它当成真实的协议错误，真错误的痕迹也会因此被淹没。`tb_ppg_control_top_periodic_recheck_recovery.v`只接了该输出、没有检查（grep结果），所以回归不会暴露。
- **RTL证据**：调度器469–470、463–465、763–768；SSW 420–426；AMI 986、988、1240、1837–1845。
- **建议**：
  - 用现有periodic_recheck_recovery TB，在重检期间的NORMAL帧tick 285观察`o_ami_integration_protocol_error_sticky`，静态结论预期为1；
  - 断言：同一个`flag_held_start_valid`期间，载荷变化只允许出现在“调度器上一候选截止的下一拍”；或者在合同里明确由哪一方负责插入间隙。
- **说明**：这一条按“调度器截止撤销 × 下一候选提升 × AMI保持检查”三方同拍关系发现，所以列在AMI文件；它同样属于调度器的条件对（P10 × 候选切换），调度器文件没有单列。

### V1-AMI-C2（低）integration协议sticky：诊断清除优先于同拍新错误

- 见1.4节。只进sticky的五类协议项在诊断清除同拍发生时完全不留痕迹；进阻断的那几类，虽然阻断照常置位、lane照常产生记录，但sticky与阻断的状态互相矛盾。与C24 §4、OLR的lost sticky规则不一致。

### V1-AMI-C3（低）abort优先于同拍新故障：hold被清，但lane记录照常分发

- 见1.4节。可达性：外部abort（SPI）与真实的无owner RAW、completion mismatch或第k次作废落在同一拍。
- 后果：supervisor开启一个立即关闭的episode；`o_ami_fault_active`在记录有效时可能为0。
- 合同：brief §3.6 F-4要写入C10 §6.11的“新故障置位优先”，按RTL只对排空清除成立，需要B批次写准。

### V1-AMI-C4（低）lane身份在分发拍读取：lane 03永远不带身份

- 见1.4节。

### V1-AMI-C5（低）abort当拍测量分支的transfer让位给discard，与C10 §6.11不符

- 见1.3节。

### V1-AMI-N1（附注，不是发现）STOP沿私有flush之后进入数据链的结果

- STOP当拍（或之前几拍）完成的NORMAL结果，可能在STOP沿时还停在没有datapath discard输入的S1可编程校准器里（AMI 2069–2134，端口列表中没有discard）。
- NORMAL fork在同一沿“输入接收优先于清空”（`ppg_normal_transaction_fork.v` 278–291），所以该结果可以在flush之后继续前进；之后没有新的flush，最终在AMI fork边界因`flag_result_abort_discard=1`被接收但不置pending，既没有正式结果，也没有public discard事件。
- C10 §6.11把fork之前的工作定义为私有flush释放，本来就没有public事件，所以效果等同于flush，不算违反。
- 对应的完成旁带success=1（V1-SCH-P1结案）：调度器计入颜色完成，正式结果却不出现。
- 建议在系统TB中用断言覆盖：“STOP之后没有正式结果valid”，且`o_datapath_empty`最终为1。

## 3. 跨模块遗留项结案

| 来源 | 结论 |
|---|---|
| V1-SCH-P1（STOP/abort与成功完成同拍） | 结案为(b)：STOP同拍，三方都按成功处理并释放（AMI success=1，见1.1）；abort同拍，三方都按失败处理并释放（AMI success=0）。结果本身被STOP/abort的丢弃机制挡在正式输出之外（附注N1） |
| V1-SCH-C2（STOP拍发出CAL截止事件） | AMI与重检调度器都是STOP优先，结果相同，无额外后果（1.2） |
| V1-SCH-C3（START与abort同拍） | AMI：START胜出（1.3）；调度器：START胜出；SSW：abort胜出。三模块不一致，但下一拍drain-STOP到达前不会建立任何波形或owner。可观测后果只有调度器可能在T+2发出一拍启动IDAC边界，且AMI已按新RUN启动IDAC启动流程，可能提交一次启动码。维持低级别 |

## 4. 合同与RTL差异记录（以RTL为准）

1. C10 §6.11：“`diag_clear`, STOP, abort, a result discard, enable deassertion and START neither remove a pending fault record nor clear an active lane”——已由brief §3.6 F-4点名。补充：
   - 按RTL，START/abort清的是hold（active），不清pending记录；
   - 新故障只对排空清除优先，对START/abort不优先（V1-AMI-C3）；
   - 分发器为七路（01–07），顺序01>02>03>04>05>06>07。
2. C10 §6.11：“`2'b11` is reserved and is never emitted”——RTL用`2'b11`=COMPLETION_LOST（1339），brief §3.6已定。
3. C10 §6.11：“A normal measurement transfer wins over same-edge measurement discard”——abort的实时项不满足（V1-AMI-C5）。
4. C10 §6.11的discard原因优先级没有提到`flag_integration_blocking`；RTL把它映射为SYSTEM_FAULT（1001）。
5. C10 §6.11：“A rising event for a lane captures that lane's FAULT_ID atomically”——RTL在分发拍读取（V1-AMI-C4）。
6. C10 §15.1与C24 §4的“新故障胜过同拍清除”——integration sticky相反（V1-AMI-C2）。
7. C10 §15.2：“blocking fault发生后…等待STOP、abort或复位结束当前RUN上下文”——RTL的`flag_integration_blocking`只在START/abort/复位时清0，STOP不清（brief §3.12第4条已记）。

## 5. 汇总

**(c)类**：

| 编号 | 级别 | 一句话 |
|---|---|---|
| V1-AMI-C1 | 中 | RED截止(283)→IR候选(284)时valid不间断，AMI判为载荷变化，在周期重检的NORMAL帧中误置integration协议sticky |
| V1-AMI-C2 | 低 | integration协议sticky：诊断清除优先于同拍新错误，与全项目“新故障优先”相反 |
| V1-AMI-C3 | 低 | abort优先于同拍新故障：hold与integration阻断被清，pending记录照常分发，supervisor开启一个立即关闭的episode；“新故障置位优先”的合同措辞需写准 |
| V1-AMI-C4 | 低 | lane身份在分发拍读取：lane 03记录永远`identity_valid=0`；lane 06延迟分发时可能报新owner |
| V1-AMI-C5 | 低 | abort当拍测量transfer让位给discard，违反C10 §6.11 |

**待定**：无（V1-SCH-P1已在本文件结案为(b)；附注N1建议用断言覆盖）。

## 6. 已覆盖的always块与寄存器清单（73个时序块，全部覆盖）

| always起始行 | 目标 | 覆盖位置 |
|---|---|---|
| 1235 | `integration_protocol_error_sticky_o` | 1.4、C1、C2 |
| 1246、1259、1272、1283 | `adc_transaction_complete_event_o`、`adc_transaction_success_o`、`adc_complete_sample_index_o`、`adc_transaction_lost_event_o` | 1.1 |
| 1294 | `owner_lost_sticky_o` | 1.4 |
| 1305 | `result_sample_valid_o` | 1.3 |
| 1318、1331、1344、1357、1370、1383、1396、1409、1422、1435 | `measurement_result_discard_event_o`、`_reason_o`、`_identity_valid_o`、`_sample_valid_o`、`_frame_id_o`、`_sample_index_o`、`_color_ir_o`、`_frame_type_o`、`_precision_o`、`_run_generation_o` | 1.3 |
| 1449、1466、1479、1492 | `calibration_sample_valid_o`、`calibration_color_ir_o`、`calibration_frame_type_o`、`calibration_request_reason_o` | 1.2 |
| 1507 | `flag_system_fault_discard_pending` | 1.3 |
| 1518 | `cnt_owner_age` | 1.1 |
| 1529、1542、1555 | `cnt_lost_red`、`cnt_lost_ir`、`cnt_lost_cal` | 1.1 |
| 1568、1581 | `flag_owner_lost_fault_hold`、`flag_adc_busy_fault_hold` | 1.4 |
| 1594、1605、1616、1627、1638、1649、1660 | `flag_ami_fault_pending_06`、`_07`、`_01`、`_02`、`_03`、`_04`、`_05` | 1.4 |
| 1671 | `flag_detection_discard_episode_active` | 1.3 |
| 1682、1691、1700、1709、1718、1727、1736、1745、1754 | `reg_adc_inflight_sample_index`、`_precision_mode`、`_frame_id`、`_color_ir`、`_frame_type`、`_amb_code`、`_dc_code`、`_amb_epoch`、`_dc_epoch`（start_fire单装载者） | 1.1、C4 |
| 1763、1776、1789 | `flag_test_identity_hold`、`flag_owner_protocol_fault_hold`、`flag_recovery_context_fault_hold` | 1.4 |
| 1802、1813、1826 | `flag_adc_completion_pending`、`flag_adc_transaction_inflight`、`flag_adc_transaction_abort` | 1.1 |
| 1837 | `flag_held_start_valid` | 1.4、C1 |
| 1848、1857、1866、1875、1884、1893、1902、1911、1920 | `reg_held_start_amb_code`、`_amb_epoch`、`_color_ir`、`_dc_code`、`_dc_epoch`、`_frame_id`、`_frame_type`、`_precision`、`_sample_index` | 1.4、C1 |
| 1929 | `flag_integration_blocking` | 1.4 |
| 1940 | `flag_run_context_ended` | 1.3 |
| 1951 | `reg_result_fork_payload` | 1.3 |
| 1962、1976、1989 | `flag_detection_pending`、`flag_detection_branch_sample_valid`、`flag_measurement_pending` | 1.3 |
| 2002 | `flag_abort_draining` | 1.3 |
| 2015 | `flag_calibration_request_inflight` | 1.2 |
| 2028、2037、2046 | `reg_inflight_color_ir`、`reg_inflight_frame_type`、`reg_inflight_reason` | 1.2 |
| 2057 | `flag_stop_result_draining` | 1.3 |

计数：1+4+1+1+10+4+1+1+3+2+7+1+9+3+3+1+9+1+1+1+3+1+1+3+1 = 73，与RTL中`always`关键字数一致。
