# V1 同拍冲突矩阵：PWI（`ppg_precision_window_integration.v`，对照C18）

- 任务：P0-V1 续，模块9/12；基线main `a1ba482`；只读；纯静态（没有仿真器）
- 合同：C18 = `contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md`（§5.10 detection discard广播、链路空汇总）
- 本文件只覆盖PWI自身的6个always块。子模块（FIR、基线/穿越检测、峰谷检测、精度控制器、重检调度器）中，精度控制器与重检调度器见`V1_CONFLICT_PWC.md`、`V1_CONFLICT_RCK.md`；FIR只在追踪上游时引用。

## 0. 关键组合量（行号为基线）

| 量 | 行号 | 定义 |
|---|---|---|
| `flag_fir_output_transfer` | 443 | FIR结果valid，且两个检测分支都已释放（或本来为空） |
| `flag_detection_discard_apply` | 446 | detection discard事件且代际匹配 |
| `flag_fork_clear` | 447 | `!run_enable \|\| START \|\| discard_apply \|\| recheck_accept` |

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `reg_fork_payload`（531）、`flag_baseline_pending`（542）、`flag_peak_valley_pending`（555） | fork_clear清0 > FIR输出transfer置位/装载 > 分支transfer清0 | discard事件 × FIR输出transfer | (b) | discard按代际清空，同拍进入的结果一并清掉，不发分支事件。C18 §5.10：generation-scoped flush在“receiving edge”清空本代际全部pending；AMI侧已按terminal action发出一次detection discard（V1-AMI 1.3） | 否 |
| 〃 | 〃 | 重检accept × FIR输出transfer | (a) | accept=`flag_enter_amb`，要求`flag_takeover_safe`，其中`i_fir_idle`=`flag_fir_idle_to_scheduler`（1002），即上一拍FIR为`ST_IDLE && !result_valid && 无输入transfer`（`ppg_coarse_detection_fir.v` 323）。IDLE且无输入的FIR下一拍不可能出结果，所以accept拍没有FIR输出transfer | 否 |
| 〃 | 〃 | START × FIR输出 | (a) | START时检测链已空（manager START要求`i_datapath_empty`，AMI把PWI的检测链空汇入`o_datapath_empty`） | 否 |
| 〃 | 〃 | 新结果进入 × 旧结果离开（同拍） | (b) | 置位在后胜出；`flag_fir_result_ready`要求两个分支都已释放（440–442） | 否 |
| `flag_recheck_detector_busy`（568） | START/discard/重检done或failed/`!run_enable`清0 > accept置1 | accept × done/failed | (a) | 重检调度器中accept与done/failed所在状态不同（RCK 189/196/197） | 否 |
| 〃 | 〃 | accept × 系统故障discard事件（同拍） | (b)，附注 | `flag_enter_amb`的cancel只含STOP、abort、`!run_enable`，不含系统故障discard（RCK 177/189）。V1-AMI A4：supervisor的discard事件比abort早一拍到达AMI，可能恰好落在accept拍。结果是本模块的busy被清、重检调度器却进入AMB，持续1拍，下一拍abort使重检调度器回到MONITOR，没有后果 | 否 |
| `flag_fir_idle_to_scheduler`（579） | START/discard/15→9事件/accept/`!run_enable`清0 > 空闲时置1 > 否则0 | — | (b) | 注册式“上一拍FIR与检测fork都空闲”；15→9事件与accept当拍强制为0，避免同一拍再次接管 | 否 |
| `detection_datapath_empty_o`（521） | 各子模块local empty与fork空闲的“与”，打一拍 | — | (b) | C18 §5.10：子模块最早在flush后一拍报告空 | 否 |

## 2. 汇总与清单

- 本模块(c)：0项；待定：无。
- always块（6个，全部覆盖）：521 `detection_datapath_empty_o`；531 `reg_fork_payload`；542 `flag_baseline_pending`；555 `flag_peak_valley_pending`；568 `flag_recheck_detector_busy`；579 `flag_fir_idle_to_scheduler`。
