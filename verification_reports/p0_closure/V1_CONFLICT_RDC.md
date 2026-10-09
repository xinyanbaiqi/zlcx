# V1 同拍冲突矩阵：S1冗余校正器（`ppg_adc_s1_redundancy_corrector.v`，对照C10相关部分与OLR §2.2）

- 任务：P0-V1 续，模块11/12；基线main `a1ba482`；只读；纯静态（没有仿真器）
- 依据：C10（冗余校正器作为AMI子模块的部分）；`verification_reports/OWNER_LIFECYCLE_ROUND_20261007.md` §2.2（作废布防与三种时序）；brief §3.6（约2拍竞争窗口写成合同前提，F-3）

## 0. 结构与记号

11个always块：10个时序块，1个组合块（286，`dec_detect_code`）。

| 量 | 行号 | 定义 |
|---|---|---|
| `flag_capture_transfer` | 162 | capture valid、有上下文、输出缓存可写 |
| `flag_context_ready` / `flag_context_transfer` | 163/164 | 无上下文或本拍被capture消费；start且ready |
| `flag_capture_drop` | 165 | capture valid、已布防、**当前**无上下文 |
| `o_capture_ready` | 188 | （有上下文且缓存可写）或drop |

上游：
- `i_adc_transaction_start` = AMI `o_transaction_start_fire`；
- `i_transaction_abandon` = AMI `flag_owner_lost_fire`；
- `i_capture_valid`来自`ppg_adc_async_stage_capture`。

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `flag_context_valid`（319） | context transfer置1 > capture transfer清0 > abandon清0 | context × capture | (b) | “同拍替换上下文”：旧上下文被本拍RAW消费，新上下文同时装入（163注释），流水线设计 | 否 |
| 〃 | 〃 | context × abandon | (a) | AMI start要求`!flag_adc_transaction_inflight`，lost要求它为1（AMI 986/954） | 否 |
| 〃 | 〃 | capture × abandon | (a) | lost要求`!flag_capture_valid`（AMI 954） | 否 |
| `flag_capture_drop_armed`（308） | （context transfer或drop）清0 > abandon置1 | abandon × context/drop | (a) | 同上：abandon要求无capture valid、无start | 否 |
| 〃 | 〃 | 迟到RAW的capture valid与下一笔start同拍到达本模块 | (b)，附注 | 当拍`flag_context_valid`（寄存）仍为0、已布防，所以`flag_capture_drop=1`：RAW被吞掉，不与新上下文配对，同沿撤防并装入新上下文。AMI同拍看到`capture_transfer && !inflight`（inflight要到下一沿才置1），记`flag_adc_capture_without_owner`，进入lane 02与integration阻断，即OLR §2.2“迟到旧DONE按无owner捕获被拒并升级”的路径。OLR表中的情形B（“与start同一拍”→绑定）是按DONE引脚边沿计时的，经两级同步后在本模块边界已是start之后，对应本行的下一行 | 断言：`flag_capture_drop → !flag_capture_transfer` |
| 〃 | 〃 | 迟到RAW在start之后1–2拍到达本模块 | (b) | 已撤防，上下文有效，RAW与新事务配对，success=1错绑正式输出：brief §3.6“约2拍竞争窗口”写成合同前提，F-3 | 否 |
| `detect_valid_o`（272） | capture置1 > 下游transfer清0 | 同拍 | (b) | 缓存可写的条件含`i_detect_ready`（161），新结果进入的同时旧结果离开 | 否 |
| `detect_code_o`、`stage1_raw_o`、`stage1_code_ext_o`、`stage2_raw_o`、`precision_mode_o`、`metadata_o`（206–269） | capture装载 | — | — | 单装载者 | — |
| `reg_context`（297） | context transfer装载 | — | — | 单装载者 | — |
| `dec_detect_code`（286，组合） | 饱和截断 | — | — | 纯组合 | — |

## 2. 汇总与清单

- 本模块(c)：0项；待定：无。补充说明一点供B批次写合同前提：OLR §2.2的三种时序是按DONE边沿描述的，在本模块边界，“capture valid与start同拍”走吞掉+升级路径，不是错绑。错绑只发生在capture valid晚于start到达时。
- always块（11个，全部覆盖）：206 `detect_code_o`；217 `stage1_raw_o`；228 `stage1_code_ext_o`；239 `stage2_raw_o`；250 `precision_mode_o`；261 `metadata_o`；272 `detect_valid_o`；286 `dec_detect_code`（组合）；297 `reg_context`；308 `flag_capture_drop_armed`；319 `flag_context_valid`。
