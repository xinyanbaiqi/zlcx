# anchor_check 端口台账检查（1c）与W10 负对照（第三轮补正）

在当前矩阵（第三轮补正写入后）的副本上各改1处锚点，其它不动；检查程序`tools/b_merge_tools/anchor_check.py`（语义模式默认开启）。

| 编号 | 矩阵行 | 改动 | 原锚点 | 改后 |
|---|---:|---|---|---|
| NC1 | 1366 | 多模块锚点行，仅把第5列AMI锚点换成AMI中相邻的已存在端口（声明下一行） | `ppg_adc_measurement_idac_integration.v` `i_run_generation`（子模块声明） | `ppg_adc_measurement_idac_integration.v` `i_system_fault_discard_event`（子模块声明） |
| NC2 | 1885 | 非第5列（Consumer）Top锚点换成相邻的例化连接端口 | Consumer: `ppg_control_top.v` `o_transaction_precision_mode` | Consumer: `ppg_control_top.v` `o_transaction_frame_id` |
| NC3 | 1912 | W10：锚点后写明`.o_macro_frame_start_event()`，锚点换成相邻连接 | `ppg_control_top.v` `o_macro_frame_start_event` is | `ppg_control_top.v` `o_macro_frame_safe_boundary` is |

结果：

- 未改副本：退出码0，报错0
- 改动副本（语义模式）：退出码1，报错3，其中语义类3：
  - `PPG_CONTRACT_CLOSURE_MATRIX.md:1366` port-mismatch ppg_adc_measurement_idac_integration.v i_system_fault_discard_event but the row port `i_run_generation` is carried by that file (RTL column)
  - `PPG_CONTRACT_CLOSURE_MATRIX.md:1885` port-mismatch ppg_control_top.v o_transaction_frame_id but the row port `o_transaction_precision_mode` is carried by that file (unrelated symbol)
  - `PPG_CONTRACT_CLOSURE_MATRIX.md:1912` symbol-mismatch ppg_control_top.v o_macro_frame_safe_boundary but the cell writes `o_macro_frame_start_event` (W10)
- 改动副本（`--no-semantic`）：退出码0，报错0（三处改后的符号在各自文件中都存在，只有语义模式能报出）

结论：3处改动恰好各报出1处，未改副本与`--no-semantic`均为0报错。
