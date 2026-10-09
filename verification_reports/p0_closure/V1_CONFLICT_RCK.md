# V1 同拍冲突矩阵：AMB重检调度器（`ppg_amb_recheck_scheduler.v`，对照C16）

- 任务：P0-V1 续，模块8/12；基线main `a1ba482`；只读；纯静态（没有仿真器）
- 合同：C16 = `contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`；用户裁定见brief §3.9（F-9）

## 0. 结构与记号

7个always块：6个时序块，1个组合块（270，`state_next`）。

状态：MONITOR → WAIT_SWITCH →（收到`i_precision_15_to_9_event`）WAIT_DRAIN →（`flag_takeover_safe`）AMB → WAIT_DCS_ACCEPT → DCS_R → DCS_IR → MONITOR。

关键组合量（行号为基线）：

| 量 | 行号 | 定义 |
|---|---|---|
| `flag_control_cancel` | 177 | STOP、abort或`!run_enable` |
| `flag_period_enabled` | 180 | `run_enable`、TRACK模式、AMB使能、间隔非0、启动搜索完成、NORMAL测量活动 |
| `flag_takeover_safe` | 182 | 精度接管安全、fork空闲、IDAC空闲、FIR空闲、峰谷空闲、宏帧安全边界 |
| `flag_enter_amb` | 189 | WAIT_DRAIN、接管安全、`!cancel`；同时作为`o_amb_sequence_start`送IDAC |
| `flag_stage_result_available` / `flag_stage_frame_available` | 185/186 | 锁存位或当拍事件 |
| `enc_sequence_done_o` / `enc_sequence_failed_o` | 196/197 | 阶段闭合/失败 |

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `state_next`（270） | START/cancel→MONITOR > done/failed→MONITOR > 按状态`case` | done × failed | (a) | ST_AMB：done要求`i_amb_sequence_done`或其锁存，failed要求`i_amb_sequence_failed`；IDAC在同一个样本上只置其中一个（IDAC K4，909–938）。DCS阶段同理（IDAC K6/K10）。即使同拍，两者都回MONITOR并清全部状态，结果一致 | 否 |
| 〃 | 〃 | START × 任何推进 | (a) | U1；START时`flag_period_enabled=0`：IDAC在CONFIG中已被cancel清掉`STARTUP_COMPLETE` | 否 |
| `amb_recheck_pending_o`（247） | START/cancel/done/failed清0 > interval hit置1 | interval hit × done/failed | (a) | hit要求MONITOR，done/failed要求非MONITOR状态 | 否 |
| `cnt_normal_frame_o`（232） | 清0条件 > hit装载 > 递增 | NORMAL完成事件在STOP之后到达（V1-SCH-C7） | (b) | `flag_period_enabled`含`i_run_enable`，STOP拍及之后不计数；外部故障阻断时run_enable仍为1，计数可能多加1，见V1-SCH-C7 | 否（已在SCH-C7） |
| `flag_enter_amb` → IDAC `i_amb_sequence_start` | 189 | enter × IDAC同拍提交或跟踪样本 | (a) | `flag_takeover_safe`含`i_idac_idle`；IDAC的`o_idac_idle`含三个pending为0与无transfer（IDAC 673–684）。commit需要pending，跟踪样本需要transfer，二者在enter拍都不可能。见V1-IDAC §1 | 否 |
| `flag_stage_result_done`（332） | 清0（START、cancel、done/failed、enter_amb、dcs accept、enter_ir）> 各阶段结果置1 | enter_ir × DCS_R结果置位 | (b) | enter_ir本身就是用该结果推进的，清0优先，避免把R阶段的结果带进IR阶段 | 否 |
| `flag_stage_frame_complete`（349） | 同样的清0 > 校准帧完成置1 | 阶段切换拍 × `i_calibration_frame_complete_event` | (b) | 切换拍的帧完成事件经组合项`flag_stage_frame_available`（186）用于旧阶段的推进判定，之后被清0，不带入新阶段 | 否 |
| 〃 | 〃 | 阶段延长或跨帧重试后，锁存位沿用较早的帧完成 | (b) | brief §3.9 F-9：用户已裁定不改RTL、由合同写明 | 否（F-9已在收尾计划） |
| `flag_sample_inflight`（363） | 清0条件 > IDAC实际接受样本 > withdraw > 请求transfer置1 | accepted × transfer | (a) | `o_calibration_sample_valid`要求`flag_sample_inflight==0`（211）；accepted对应一笔已transfer的请求，此时inflight=1；inflight被withdraw清掉的请求（截止或作废）不会再有结果 | 断言：`flag_calibration_transfer → !flag_matching_sample_accepted` |
| 〃 | 〃 | withdraw × transfer | (a) | AMI只在自身请求在途时转发withdraw（AMI 962），此时AMI的`flag_precision_calibration_ready=0`（AMI 977），本模块的transfer不成立 | 否 |
| 〃 | 〃 | STOP × withdraw（V1-SCH-C2经AMI转发） | (b) | cancel优先，结果相同（V1-AMI 1.2） | 否 |
| 〃 | 〃 | 阶段切换拍 × transfer | (a) | valid（211）要求`!flag_stage_result_available`，切换拍结果可用，所以valid=0；enter_amb、dcs accept两拍所在状态（WAIT_DRAIN、WAIT_DCS_ACCEPT）不产生valid | 否 |

## 2. 汇总与清单

- 本模块(c)：0项；待定：无。已知事项F-9（brief §3.9）不重复计入。
- always块（7个，全部覆盖）：232 `cnt_normal_frame_o`；247 `amb_recheck_pending_o`；261 `state_current`；270 `state_next`（组合）；332 `flag_stage_result_done`；349 `flag_stage_frame_complete`；363 `flag_sample_inflight`。
