# V1 同拍冲突矩阵：supervisor（`ppg_system_fault_abort_supervisor.v`，对照C24）

- 任务：P0-V1 续，模块5/12；基线main `a1ba482`；只读；纯静态（没有仿真器）
- 合同：C24 = `contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md`（§4同拍规则、§5 active语义、§6看门狗）

## 0. 结构与记号

19个always块，全部是时序块。关键组合量：

| 量 | 行号 | 定义 |
|---|---|---|
| `flag_watchdog_window_active` | 193 | `i_stop_episode_active && !i_adc_physical_idle && !timeout_latch` |
| `flag_watchdog_timeout_fire` | 194 | 窗口打开且计数器到4999 |
| `flag_episode_close_condition` | 196–197 | 三路本地`fault_active`都为低，且看门狗已恢复 |
| `flag_new_any` | 199 | AMI、调度器、SSW任一valid，或看门狗超时 |
| `flag_episode_open_edge` | 200 | `flag_new_any && !system_fault_blocking_o` |
| `flag_diag_clear_legal` | 202 | `i_diag_clear_event && !blocking && !flag_new_any` |
| `flag_capture_*` | 204–207 | 首故障快照：看门狗 > AMI > 调度器 > SSW，且`!cause_valid` |

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `system_fault_blocking_o`（257） | 新记录置1 > 关闭条件清0 | 新记录 × 关闭 | (b) | C24 §4：“new fault wins over simultaneous close” | 否 |
| 〃 | 〃 | 新记录到达时，其来源的`fault_active=0` | (b)，跨模块附注 | 只要有valid就开episode（C24 §4“eligible blocking record”在RTL中等价于valid），下一沿若三路active都为低则立即关闭。V1-AMI-C3的情形（abort同拍新故障，hold被清但记录照常分发）在这里形成“开启即关闭”的episode：仍会发出一组abort/STOP/discard事件，但阻断只维持约1拍 | 断言：`o_system_abort_event`之后，若blocking在≤2拍内落下，则必须是三路active都为低（作为观察项记录） |
| `system_abort_event_o`、`system_stop_request_event_o`、`system_fault_discard_event_o`（268、279、290） | `flag_episode_open_edge`时打一拍 | episode关闭拍 × 新记录 | (b) | 关闭拍blocking仍为1，新记录不形成open_edge，被并入继续保持的episode，不产生第二组事件；C24 §4“Repeated local fault … in an open episode cannot create another event”。由于上一组事件已经触发STOP，系统此时处于排空或CONFIG，不需要新的STOP | 否 |
| 〃 | 〃 | 三个事件之间 | (b) | 同一条件同一沿，原子成组；到达各模块的时刻不同（discard直连AMI，abort与stop经Top寄存），见V1-AMI A4 | 否 |
| `system_fault_cause_valid_o`及首故障快照（cause、source、identity_valid、frame_id、sample_index、color_ir、frame_type、precision、run_generation，302–409） | capture（仅当`!cause_valid`）> diag合法清除 | capture × diag合法清除 | (a) | 合法清除要求`!flag_new_any`，capture要求某一路valid（即`flag_new_any=1`） | 否 |
| 〃 | 〃 | 多源同拍 | (b) | 固定优先级：看门狗 > AMI > 调度器 > SSW；C24 §4 | 否 |
| 〃 | 〃 | START | (b) | 没有START清除路径；C24与C02 §3.1：“START never clears system first-fault history” | 否 |
| `system_fault_summary_o`（413） | 新位OR > diag合法清除 | 同上 | (a) | 同上 | 否 |
| `result_discard_summary_sticky_o`（424） | measurement discard事件置1 > diag合法清除 | discard事件 × diag合法清除 | (b) | 两者可以同拍（合法清除不看discard事件），置位胜出；与C24 §4的“新事件胜过清除”同向 | 否 |
| 〃 | — | diag清除落在episode关闭拍 | (b)，跨模块附注 | 关闭拍blocking仍为1，清除不合法、被丢弃且不重试（C24 §4：“clear is legal only after recovery”）。同一个`flag_diag_clear_event`在manager与AMI、调度器、SSW处可能已经生效，所以单次诊断清除在各模块的效果可能不一致；与V1-MGR-C3同类，软件必须在episode关闭后再清一次 | 否 |
| `cnt_adc_drain_watchdog`（437） | （物理空闲或无STOP episode）清0 > 窗口内+1 | — | (a) | 清0与递增条件互斥 | 否 |
| `flag_watchdog_timeout_latch`（448） | （空闲且无episode）清0 > 超时置1 | — | (a) | 超时要求非空闲 | 否 |
| `flag_watchdog_recovery_pending`（459） | 空闲清0 > 超时置1 | — | (a) | 同上 | 否 |
| 看门狗窗口 × `i_stop_episode_active`卡1 | 193 | **V1-MGR-C1传递而来** | (c) 引用V1-MGR-C1 | manager在“重复STOP × STOPPING完成”同拍后，`o_stop_episode_active`卡1，导致本模块的窗口在下一次RUN中也打开；RUN中连续5000拍ADC忙就报0x31，与C24 §6“Normal RUN ADC busy never starts it”相反。本模块的逻辑本身按合同实现，根因在manager | 同V1-MGR-C1 |

## 2. 汇总

- 本模块自身：(c) 0项，待定0项。
- 跨模块：V1-MGR-C1在本模块表现为看门狗误开；V1-AMI-C3在本模块表现为“开启即关闭”的episode。

## 3. 已覆盖的always块与寄存器清单（19个，全部覆盖）

| always起始行 | 目标 |
|---|---|
| 257 | `system_fault_blocking_o` |
| 268、279、290 | `system_abort_event_o`、`system_stop_request_event_o`、`system_fault_discard_event_o` |
| 302、313、324、335、346、357、368、379、390、401 | `system_fault_cause_valid_o`、`_cause_o`、`_source_o`、`_identity_valid_o`、`_frame_id_o`、`_sample_index_o`、`_color_ir_o`、`_frame_type_o`、`_precision_o`、`_run_generation_o` |
| 413 | `system_fault_summary_o` |
| 424 | `result_discard_summary_sticky_o` |
| 437 | `cnt_adc_drain_watchdog` |
| 448 | `flag_watchdog_timeout_latch` |
| 459 | `flag_watchdog_recovery_pending` |
