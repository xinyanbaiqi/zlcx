# V1 同拍冲突矩阵：精度窗口控制器（`ppg_precision_window_controller.v`，对照C23）

- 任务：P0-V1 续，模块7/12；基线main `a1ba482`；只读；纯静态（没有仿真器）
- 合同：C23 = `contracts/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md`（§6.2、§17.1 sticky规则；§21 PWC-25/27/28/30/41）

## 0. 结构与记号

48个always块：35个时序块，13个组合块（598 `state_next`，以及653–888的12个单信号组合标志）。

关键组合量（行号为基线）：

| 量 | 行号 | 定义 |
|---|---|---|
| `flag_enter_commit` | 268 | WAIT_ENTER、安全边界、接管安全、模拟安全、`!recheck_busy`、`!lifecycle_cancel` |
| `flag_return_commit` | 269 | WAIT_RETURN、安全边界、接管安全、模拟安全、`!lifecycle_cancel` |
| `flag_lifecycle_cancel` | 271 | 本代际的detection discard事件，或`flag_leave_run_cancel`（`!run_enable && state!=IDLE`，669） |
| `flag_switch_timeout_event` | 272 | 处于pending状态、本拍无commit、计数器到上限——**不含cancel门控** |
| `o_cross_ready` / `o_return_9bit_ready` | 281/284 | 都含`i_run_enable`、`!fault_hold`；cross要求IDLE、9-bit、无精细窗口、`!recheck_busy`；return要求FINE、15-bit、精细窗口有效 |

`state_next`（598–649）：START（按阻断协议故障选FAULT或IDLE）> cancel→IDLE > 按状态`case`（FAULT自锁）。

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `state_current/next` | 见上 | START × cancel | (a) | START拍`run_enable=1`（U1），leave_run不成立；START时PWI检测链为空，AMI不发detection discard（AMI 1020要求`!flag_pwi_detection_datapath_empty`） | 否 |
| 〃 | 〃 | enter/return commit × timeout | (b) | timeout定义中排除了本拍commit（272），PWC-25“安全与阈值同拍，安全提交优先” | 否 |
| `active_precision_mode_o`（320） | START > enter commit（15）> return commit（9） | enter × return | (a) | 两者要求不同状态 | 否 |
| 〃 | 〃 | cancel不改精度 | (b)，附注 | cancel后状态回IDLE，`fine_window_active=0`，但精度保持当前值（可能是15-bit），直到下一次START重置。cancel只由STOP、abort、系统故障引起，三者都会结束当前RUN（abort派生drain-STOP；supervisor同时发STOP），所以15-bit不会被新的NORMAL帧使用 | 断言：`state==IDLE && active_precision==15 → !run_enable或下一拍有STOP` |
| `fine_window_active_o`（341） | START/cancel清0 > enter置1 > return清0 | — | (b) | | 否 |
| `switch_target_precision_o`（531） | cross（15）> return（9） | cross × return同拍 | (a) | 两个ready按状态互斥（IDLE只接cross，FINE只接return），所以transfer不可能同拍；PWC-30的协议诊断由`flag_cross_return_collision`（864）按valid给出 | 否 |
| `switch_timeout_sticky_o`（494）、`protocol_error_sticky_o`（507） | **诊断清除（无条件）> 新事件置1** | **诊断清除 × 同拍超时/协议事件** | **(c) V1-PWC-C1（低）** | 清除在前，新事件丢失；而且清除没有“本地活动故障已解除”这一条件。C23 §17.1（730–733）：“在本地活动故障已经解除后由Top唯一注册式`i_diag_clear_event`清除…不得解除正在进行的故障保持”。`switch_timeout_sticky_o`还是AMI阻断的组成部分：AMI的`flag_precision_fault_blocking = precision_fault_event \|\| switch_timeout_sticky_o`（AMI 978），进入`o_wrapper_fault_blocking`与`o_normal_measurement_eligible`（AMI 1189–1190）。所以RUN中的一次诊断清除会解除AMI这一路阻断，此时`flag_fault_hold`仍为1。OLR F-1“须诊断清除后才能START”的恢复语义依赖这个sticky，同拍丢失会使恢复流程看不到超时记录 | 是：PWC单元TB在超时拍同拍诊断清除；在fault_hold=1期间诊断清除，检查sticky与AMI的`o_wrapper_fault_blocking` |
| `flag_fault_hold`（674） | cancel清0 > START置为阻断协议故障 > 超时置1 | **超时 × cancel同拍** | **(c) V1-PWC-C2（低）** | hold被cancel清0；但`mode_fault_event_o`（411–419）与`switch_timeout_sticky_o`不看cancel，照常置位。AMI据事件置lane 04的pending并分发记录，而`flag_precision_fault_active`（=hold）为0。与V1-AMI-C3同型：supervisor开启一个立即关闭的episode。C23 840行：active“仅discard/reset后解除”，与“同拍新超时”的优先级没有规定 | 是：STOP（或abort）落在第10000拍 |
| `mode_fault_event_o`及身份（411–490） | 超时、或return commit且重检忙 → 有身份；START阻断协议故障 → 无身份 | 超时 × START协议脉冲 | (a) | START拍状态为IDLE（CONFIG中每拍leave_run cancel），没有pending状态 | 否 |
| 〃 | 〃 | `return_commit && i_recheck_busy` | (a)，附注 | 重检调度器只在收到`o_precision_15_to_9_event`后才进入busy（`ppg_amb_recheck_scheduler.v` 190/280–289），该事件由return commit打一拍产生；FINE期间重检转busy会先被`flag_recheck_in_fine`记为协议错误。所以这一支是防御性的，正常不可达 | 否 |
| `flag_pending_cross`（827）/ `flag_pending_return`（840） | **transfer置1 > cancel/commit/timeout清0**；START不清 | **transfer × cancel（detection discard）** | **(c) V1-PWC-C3（无可观测后果）** | 同一模块的快照寄存器（706–811）是cancel优先、清0，而pending位是transfer优先，同拍时pending=1、快照=0、状态=IDLE（state_next是cancel优先）。START不在清除列表里，残留会跨RUN保留。可达：abort或系统故障discard拍`run_enable=1`，cross ready可能为1，检测器的valid（寄存）同拍仍为1。后果：pending位只用于超时故障身份的来源选择（439/454/469），而下一次进入WAIT_*之前，enter commit或新的transfer会覆盖它，所以不可观测 | 断言：`state==IDLE → !flag_pending_cross && !flag_pending_return`（作为护栏） |
| 快照寄存器（`reg_cross_*`、`flag_pending_cross_time_unknown`、`reg_return_frame_snapshot`、`enc_return_reason_snapshot`、`flag_pending_return_reacquire`，706–824） | START/cancel清0 > transfer装载 | — | (b) | 与lifecycle cancel同向；见C3中与pending位的对比 | 否 |
| `cnt_switch_timeout`（689） | START/cancel/commit/超时清0 > pending状态递增 | — | (b) | | 否 |
| `switch_pending_o`、`switch_hold_new_transaction_o`、`controller_idle_o`（520、544、553） | 由`state_next`与当拍commit/cancel组合后寄存 | — | (b) | 单一表达式，无分支冲突；hold含cancel，cancel当拍起继续阻止新事务（PWC-28） | 否 |
| 单拍事件与帧号（`fine_window_start_*`、`precision_15_to_9_*`、`reacquire_request_event_o`，356–408） | 各自单条件 | — | — | 单写者 | — |
| `last_cross_time_unknown_o`、`last_return_reason_o`（562、573） | transfer装载 | — | — | 单写者；不受START清除（历史观察量） | — |
| 13个组合标志（653–888） | 各为单一表达式 | — | — | 进入`flag_protocol_error_event`（273），在sticky行中覆盖 | — |

## 2. 发现详述

### V1-PWC-C1（低）两个sticky：诊断清除无条件且优先于同拍新事件

- RTL 497–503、510–516：`if(i_diag_clear_event) <=0; else if(event) <=1;`。
- 与C23 §17.1的两处不符：（1）清除不检查活动故障；（2）同拍新事件丢失。
- 与AMI的V1-AMI-C2同型；与supervisor、owner_lost_sticky的“新事件优先”相反。
- 额外后果：`switch_timeout_sticky_o`参与AMI阻断，RUN中的诊断清除会提前解除这一路阻断。

### V1-PWC-C2（低）超时与cancel同拍：事件与sticky照常产生，active保持为0

- 同型问题见V1-AMI-C3。建议在C23里写明同拍规则：要么cancel同拍抑制事件，要么hold仍置1。

### V1-PWC-C3（无可观测后果）pending位与快照的cancel优先级相反

- 作为护栏记录。

## 3. 合同与RTL差异

- C23 §17.1 sticky清除条件（C1）。
- C23 840行的`o_mode_fault_active`“仅discard/reset后解除”：RTL中`flag_leave_run_cancel`（`run_enable=0`）也会解除，不需要等discard事件。PWC-27写“等待AMI/PWI generation-scoped DISCARD_STOP；不经直接STOP端口清理”，RTL在STOP拍就因`run_enable=0`走leave_run cancel。由于STOP拍的detection discard同拍到达（AMI terminal action），两者效果相同，属于措辞差异。

## 4. 汇总与清单

- (c)：V1-PWC-C1（低）、V1-PWC-C2（低）、V1-PWC-C3（无可观测）；待定：无。
- always块（48个，全部覆盖）：
  - 时序块：320 `active_precision_mode_o`；341 `fine_window_active_o`；356 `fine_window_start_event_o`；367 `fine_window_start_frame_id_o`；378 `precision_15_to_9_event_o`；389 `precision_15_to_9_frame_id_o`；400 `reacquire_request_event_o`；411 `mode_fault_event_o`；422 `fault_identity_valid_o`；435 `fault_frame_id_o`；450 `fault_sample_index_o`；465 `fault_precision_o`；480 `fault_run_generation_o`；494 `switch_timeout_sticky_o`；507 `protocol_error_sticky_o`；520 `switch_pending_o`；531 `switch_target_precision_o`；544 `switch_hold_new_transaction_o`；553 `controller_idle_o`；562 `last_cross_time_unknown_o`；573 `last_return_reason_o`；589 `state_current`；674 `flag_fault_hold`；689 `cnt_switch_timeout`；706 `reg_cross_frame_snapshot`；719 `reg_cross_sample_snapshot`；732 `reg_cross_config_snapshot`；745 `reg_cross_coef_snapshot`；758 `reg_cross_dc_snapshot`；771 `flag_pending_cross_time_unknown`；784 `reg_return_frame_snapshot`；797 `enc_return_reason_snapshot`；814 `flag_pending_return_reacquire`；827 `flag_pending_cross`；840 `flag_pending_return`。
  - 组合块：598 `state_next`；653 `flag_duplicate_cross`；658 `flag_duplicate_return`；663 `flag_invalid_direction_request`；668 `flag_leave_run_cancel`；853 `flag_active_config_fault`；858 `flag_characterization_request`；863 `flag_cross_return_collision`；868 `flag_normal_start_illegal`；873 `flag_protocol_fault_pulse`；878 `flag_recheck_in_fine`；883 `flag_return_protocol_fallback`；888 `flag_return_reserved`。
