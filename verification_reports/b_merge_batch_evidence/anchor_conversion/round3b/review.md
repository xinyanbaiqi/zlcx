# 锚点第三轮补正：端口台账以端口列为行主题（统筹10-10核对意见的跟进）

## 起因

已推送的第三轮（`77d281a`）中，矩阵1442、1446行已改对，但1362、1366、1376、1378等端口台账行（当前行号）的第5列仍取了错误符号。例如1366行端口`i_run_generation`，第5列调度器、AMI两个锚点仍为`i_control_abort_event`。原因有二：

1. 第三轮(a)只认格内写明的符号。端口台账第5列只写“（子模块声明）”，不写端口名，该行的主题是第4列端口，(a)没有覆盖到。
2. 第三轮(b)把“写入时点为真实提交”的锚点当作可靠而保留（246个）。但git blame给出的是最后改动该行的提交，不是写入锚点的提交。以矩阵1867~1923行为例，blame为`bb39a0f`，锚点却写于导入之前，`ppg_control_top.v`的例化端口表已漂移15行以上。所以这一类并不可靠。

## 补正规则（`tools/b_merge_tools/anchor_round3.py`、`anchor_semantics.py`）

- **W9**：端口台账行（第3格为input/output/inout）的第5列（RTL锚点列）：锚点文件有本行同名端口（声明，或例化连接`.端口(`）即取同名；该模块确实没有同名时保留，理由写“该模块无同名端口”。
- **W9b**：其它列（Producer/Consumer）的锚点，若无格内符号、原解析与本行无关，而锚点文件有本行端口，则取本行端口。
- **W10**（写明名新规则）：锚点后紧跟`` `.port()` ``（或“is `` `.port()` ``”）即为格内写明名，如“`ppg_control_top.v:932` is `.o_macro_frame_start_event()`”。
- **撤销“写入时点可靠”类**：无格内符号且与本行无关的锚点，一律在写入时版本和导入版本被引行±5行内找本行所述符号；找不到就标低置信并列表，不猜。
- **关联判定**：与本行端口的词干相同或互相包含（如`o_sequence_failed`与`o_recheck_sequence_failed`）。行内写明的`family_*`通配族（前缀至少8个字符）覆盖其成员。行内出现的文件名（如`ppg_adc_dc_recovery.v`）不算写明了例化名`ppg_adc_dc_recovery`。
- **新增人工判定**：矩阵2736（router例化名）、3552和3585（`i_analog_ready`，格内引了该端口的注释原文）。

## 第三轮决定计数（补正后终版）

| 类别 | 数量 |
|---|---:|
| (a) 人工：保留 | 1 |
| (a) 人工：纠正 | 15 |
| (a) 保留：模块端口名不同（W9） | 1 |
| (a) 纠正：同文件 | 31 |
| (a) 纠正：换文件 | 38 |
| (a) 纠正：本行端口（W9） | 94 |
| (b) 低置信 | 56 |
| (b) 纠正：本行端口（W9b） | 294 |
| (b) 纠正：漂移校正 | 4 |
| (b) 纠正：行ID标签 | 78 |

另有2个W6/W7情形，现符号已写在锚点前的同一子句中，保留。
第三轮相对第二轮对照表共改写554处（sym/tag），保留并记录58处（note）。

## 与统筹49/493的对照

用补正后的anchor_check（语义模式，含新增端口台账检查1c与W10）复跑已推送的第三轮文本（`77d281a`的矩阵与别名表）：

- 矩阵中带端口列的台账行共1859行。其中第5列含“文件+符号”锚点的有**493行**，与统筹的493一致。
- 这493行中，第5列锚点文件有本行同名端口、锚点却不是该端口的，共**49个锚点，分布在44行**（5行各有2个模块锚点同时错，如1366、1376、1378）。这与统筹的49对应。
- 第5列以外，Producer/Consumer等列中原解析与本行无关、而锚点文件有本行端口的，另有230个锚点（W9b类）。按W10写明名不一致的有21个。这些不在统筹的49之内，此次一并改正。
- 补正写入后，anchor_check在HEAD上0报错。端口台账检查覆盖1803个有锚点的台账行、5545个锚点。493行第5列中，锚点文件有本行同名端口而锚点不是它的，为0。第5列中按W9保留的只有1处：矩阵基线2032行`ppg_idac_code_controller.v`没有`i_status_clear_event`，该端口在F-032中改名为`i_diag_clear_event`，锚点取改名后的名字。

## 相对已推送第三轮（`anchor_mapping_table_round3a.tsv`）的改写：311处

“基线行”指`7a8eabf`中的行号。当前行号见`round3b/apply_report.tsv`。

| 位置（基线行） | 旧锚点 | 第三轮（已推送） | 补正后 | 类别 |
|---|---|---|---|---|
| 别名表:69 | ppg_precision_window_controller.v:139-147 | `ppg_precision_window_controller.v` `@satisfies: K05` | `ppg_precision_window_controller.v` `o_mode_fault_event`、`o_mode_fault_active`、`o_mode_fault_identity_valid`、`o_mode_fault_frame_id` | 恢复第二轮解析：按补正后的关联判定（行内写明的通配族/文件名不算写明）原解析与本行相关，第三轮的改写撤回 |
| 别名表:89 | ppg_adc_measurement_idac_integration.v:2509 | `ppg_adc_measurement_idac_integration.v` `i_min_peak_to_peak_frames` | `ppg_adc_measurement_idac_integration.v` `i_peak_valley_config_valid` | (b) 纠正：漂移校正 |
| 矩阵:930 | ppg_adc_measurement_idac_integration.v:434-462,1602-1620,913 | `ppg_adc_measurement_idac_integration.v` `flag_adc_transaction_inflight` | `ppg_adc_measurement_idac_integration.v` `reg_held_start_dc_code`、`reg_held_start_amb_epoch`、`reg_held_start_dc_epoch`、`reg_adc_inflight_sample_index` | 恢复第二轮解析：按补正后的关联判定（行内写明的通配族/文件名不算写明）原解析与本行相关，第三轮的改写撤回 |
| 矩阵:1323 | ppg_400hz_frame_calibration_scheduler.v:95 | `ppg_400hz_frame_calibration_scheduler.v` `i_input_source` | `ppg_400hz_frame_calibration_scheduler.v` `i_active_precision_mode` | (a) 纠正：本行端口（W9） |
| 矩阵:1325 | ppg_400hz_frame_calibration_scheduler.v:84 | `ppg_400hz_frame_calibration_scheduler.v` `i_active_config_valid` | `ppg_400hz_frame_calibration_scheduler.v` `i_allow_new_transaction` | (a) 纠正：本行端口（W9） |
| 矩阵:1325 | ppg_adc_measurement_idac_integration.v:101 | `ppg_adc_measurement_idac_integration.v` `i_active_config_valid` | `ppg_adc_measurement_idac_integration.v` `i_allow_new_transaction` | (a) 纠正：本行端口（W9） |
| 矩阵:1326 | ppg_400hz_frame_calibration_scheduler.v:98 | `ppg_400hz_frame_calibration_scheduler.v` `i_normal_measurement_eligible` | `ppg_400hz_frame_calibration_scheduler.v` `i_ami_fault_blocking` | (a) 纠正：本行端口（W9） |
| 矩阵:1327 | ppg_400hz_frame_calibration_scheduler.v:165 | `ppg_400hz_frame_calibration_scheduler.v` `i_owner_q3_window_closed` | `ppg_400hz_frame_calibration_scheduler.v` `i_analog_safe` | (a) 纠正：本行端口（W9） |
| 矩阵:1327 | ppg_adc_measurement_idac_integration.v:142 | `ppg_adc_measurement_idac_integration.v` `i_clk_stage2_dout_low_async` | `ppg_adc_measurement_idac_integration.v` `i_analog_safe` | (a) 纠正：本行端口（W9） |
| 矩阵:1335 | ppg_adc_measurement_idac_integration.v:144 | `ppg_adc_measurement_idac_integration.v` `i_analog_safe` | `ppg_adc_measurement_idac_integration.v` `i_idac_code_safe_boundary` | (a) 纠正：本行端口（W9） |
| 矩阵:1339 | ppg_adc_measurement_idac_integration.v:143 | `ppg_adc_measurement_idac_integration.v` `i_adc_idle` | `ppg_adc_measurement_idac_integration.v` `i_macro_frame_safe_boundary` | (a) 纠正：本行端口（W9） |
| 矩阵:1343 | ppg_400hz_frame_calibration_scheduler.v:96 | `ppg_400hz_frame_calibration_scheduler.v` `i_optical_mode` | `ppg_400hz_frame_calibration_scheduler.v` `i_normal_measurement_eligible` | (a) 纠正：本行端口（W9） |
| 矩阵:1344 | ppg_400hz_frame_calibration_scheduler.v:94 | `ppg_400hz_frame_calibration_scheduler.v` `i_run_profile` | `ppg_400hz_frame_calibration_scheduler.v` `i_optical_mode` | (a) 纠正：本行端口（W9） |
| 矩阵:1348 | ppg_400hz_frame_calibration_scheduler.v:89 | `ppg_400hz_frame_calibration_scheduler.v` `i_control_abort_event` | `ppg_400hz_frame_calibration_scheduler.v` `i_run_generation` | (a) 纠正：本行端口（W9） |
| 矩阵:1348 | ppg_adc_measurement_idac_integration.v:106 | `ppg_adc_measurement_idac_integration.v` `i_control_abort_event` | `ppg_adc_measurement_idac_integration.v` `i_run_generation` | (a) 纠正：本行端口（W9） |
| 矩阵:1349 | ppg_adc_measurement_idac_integration.v:244 | `ppg_adc_measurement_idac_integration.v` `i_dc15_recovery_gain_q16` | `ppg_adc_measurement_idac_integration.v` `i_run_profile` | (a) 纠正：本行端口（W9） |
| 矩阵:1350 | ppg_adc_measurement_idac_integration.v:145 | `ppg_adc_measurement_idac_integration.v` `i_macro_frame_safe_boundary` | `ppg_adc_measurement_idac_integration.v` `i_safe_frame_id` | (a) 纠正：本行端口（W9） |
| 矩阵:1351 | ppg_400hz_frame_calibration_scheduler.v:166 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_idle` | `ppg_400hz_frame_calibration_scheduler.v` `i_sar_timing_idle` | (a) 纠正：本行端口（W9） |
| 矩阵:1357 | ppg_400hz_frame_calibration_scheduler.v:99 | `ppg_400hz_frame_calibration_scheduler.v` `i_switch_hold_new_transaction` | `ppg_400hz_frame_calibration_scheduler.v` `i_ssw_fault_blocking` | (a) 纠正：本行端口（W9） |
| 矩阵:1358 | ppg_400hz_frame_calibration_scheduler.v:85 | `ppg_400hz_frame_calibration_scheduler.v` `i_run_enable` | `ppg_400hz_frame_calibration_scheduler.v` `i_start_ack_event` | (a) 纠正：本行端口（W9） |
| 矩阵:1358 | ppg_adc_measurement_idac_integration.v:102 | `ppg_adc_measurement_idac_integration.v` `i_run_enable` | `ppg_adc_measurement_idac_integration.v` `i_start_ack_event` | (a) 纠正：本行端口（W9） |
| 矩阵:1360 | ppg_400hz_frame_calibration_scheduler.v:86 | `ppg_400hz_frame_calibration_scheduler.v` `i_allow_new_transaction` | `ppg_400hz_frame_calibration_scheduler.v` `i_stop_ack_event` | (a) 纠正：本行端口（W9） |
| 矩阵:1360 | ppg_adc_measurement_idac_integration.v:103 | `ppg_adc_measurement_idac_integration.v` `i_allow_new_transaction` | `ppg_adc_measurement_idac_integration.v` `i_stop_ack_event` | (a) 纠正：本行端口（W9） |
| 矩阵:1363 | ppg_400hz_frame_calibration_scheduler.v:97 | `ppg_400hz_frame_calibration_scheduler.v` `i_active_precision_mode` | `ppg_400hz_frame_calibration_scheduler.v` `i_switch_hold_new_transaction` | (a) 纠正：本行端口（W9） |
| 矩阵:1369 | ppg_adc_measurement_idac_integration.v:133 | `ppg_adc_measurement_idac_integration.v` `i_transaction_amb_code_snapshot` | `ppg_adc_measurement_idac_integration.v` `i_transaction_amb_code_epoch` | (a) 纠正：本行端口（W9） |
| 矩阵:1370 | ppg_adc_measurement_idac_integration.v:131 | `ppg_adc_measurement_idac_integration.v` `i_transaction_color_ir` | `ppg_adc_measurement_idac_integration.v` `i_transaction_amb_code_snapshot` | (a) 纠正：本行端口（W9） |
| 矩阵:1371 | ppg_adc_measurement_idac_integration.v:129 | `ppg_adc_measurement_idac_integration.v` `i_transaction_frame_id` | `ppg_adc_measurement_idac_integration.v` `i_transaction_color_ir` | (a) 纠正：本行端口（W9） |
| 矩阵:1372 | ppg_adc_measurement_idac_integration.v:134 | `ppg_adc_measurement_idac_integration.v` `i_transaction_dc_code_snapshot` | `ppg_adc_measurement_idac_integration.v` `i_transaction_dc_code_epoch` | (a) 纠正：本行端口（W9） |
| 矩阵:1373 | ppg_adc_measurement_idac_integration.v:132 | `ppg_adc_measurement_idac_integration.v` `i_transaction_frame_type` | `ppg_adc_measurement_idac_integration.v` `i_transaction_dc_code_snapshot` | (a) 纠正：本行端口（W9） |
| 矩阵:1374 | ppg_adc_measurement_idac_integration.v:127 | `ppg_adc_measurement_idac_integration.v` `o_adc_complete_sample_index` | `ppg_adc_measurement_idac_integration.v` `i_transaction_frame_id` | (a) 纠正：本行端口（W9） |
| 矩阵:1375 | ppg_adc_measurement_idac_integration.v:130 | `ppg_adc_measurement_idac_integration.v` `i_transaction_sample_index` | `ppg_adc_measurement_idac_integration.v` `i_transaction_frame_type` | (a) 纠正：本行端口（W9） |
| 矩阵:1376 | ppg_adc_measurement_idac_integration.v:126 | `ppg_adc_measurement_idac_integration.v` `o_adc_transaction_success` | `ppg_adc_measurement_idac_integration.v` `i_transaction_precision_mode` | (a) 纠正：本行端口（W9） |
| 矩阵:1377 | ppg_adc_measurement_idac_integration.v:128 | `ppg_adc_measurement_idac_integration.v` `i_transaction_precision_mode` | `ppg_adc_measurement_idac_integration.v` `i_transaction_sample_index` | (a) 纠正：本行端口（W9） |
| 矩阵:1383 | ppg_400hz_frame_calibration_scheduler.v:183 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_idle` | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_frame_active` | (a) 纠正：本行端口（W9） |
| 矩阵:1384 | ppg_400hz_frame_calibration_scheduler.v:176 | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_tick` | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_local_tick` | (a) 纠正：本行端口（W9） |
| 矩阵:1387 | ppg_400hz_frame_calibration_scheduler.v:175 | `ppg_400hz_frame_calibration_scheduler.v` `o_safe_frame_id` | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_subframe_index` | (a) 纠正：本行端口（W9） |
| 矩阵:1395 | ppg_adc_measurement_idac_integration.v:355 | `ppg_adc_measurement_idac_integration.v` `o_adc_chain_idle` | `ppg_adc_measurement_idac_integration.v` `o_datapath_empty` | (a) 纠正：本行端口（W9） |
| 矩阵:1397 | ppg_400hz_frame_calibration_scheduler.v:171 | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_frame_start_event` | `ppg_400hz_frame_calibration_scheduler.v` `o_idac_code_safe_boundary` | (a) 纠正：本行端口（W9） |
| 矩阵:1398 | ppg_adc_measurement_idac_integration.v:303 | `ppg_adc_measurement_idac_integration.v` `o_idac_fault_blocking` | `ppg_adc_measurement_idac_integration.v` `o_idac_idle` | (a) 纠正：本行端口（W9） |
| 矩阵:1402 | ppg_400hz_frame_calibration_scheduler.v:174 | `ppg_400hz_frame_calibration_scheduler.v` `o_startup_idac_safe_boundary` | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_tick` | (a) 纠正：本行端口（W9） |
| 矩阵:1407 | ppg_400hz_frame_calibration_scheduler.v:190 | `ppg_400hz_frame_calibration_scheduler.v` `o_owner_deadline_timeout_sticky` | `ppg_400hz_frame_calibration_scheduler.v` `o_protocol_error_sticky` | (a) 纠正：本行端口（W9） |
| 矩阵:1413 | ppg_400hz_frame_calibration_scheduler.v:173 | `ppg_400hz_frame_calibration_scheduler.v` `o_idac_code_safe_boundary` | `ppg_400hz_frame_calibration_scheduler.v` `o_safe_frame_id` | (a) 纠正：本行端口（W9） |
| 矩阵:1421 | ppg_adc_measurement_idac_integration.v:313 | `ppg_adc_measurement_idac_integration.v` `o_precision_15_to_9_event` | `ppg_adc_measurement_idac_integration.v` `o_switch_hold_new_transaction` | (a) 纠正：本行端口（W9） |
| 矩阵:1439 | ppg_400hz_frame_calibration_scheduler.v:145 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_snapshot` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_epoch` | (a) 纠正：本行端口（W9） |
| 矩阵:1440 | ppg_400hz_frame_calibration_scheduler.v:143 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_color_ir` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_snapshot` | (a) 纠正：本行端口（W9） |
| 矩阵:1441 | ppg_400hz_frame_calibration_scheduler.v:141 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_id` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_color_ir` | (a) 纠正：本行端口（W9） |
| 矩阵:1442 | ppg_400hz_frame_calibration_scheduler.v:146 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_snapshot` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_epoch` | (a) 纠正：本行端口（W9） |
| 矩阵:1443 | ppg_400hz_frame_calibration_scheduler.v:144 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_type` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_snapshot` | (a) 纠正：本行端口（W9） |
| 矩阵:1444 | ppg_400hz_frame_calibration_scheduler.v:139 | `ppg_400hz_frame_calibration_scheduler.v` `i_transaction_start_fire` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_id` | (a) 纠正：本行端口（W9） |
| 矩阵:1445 | ppg_400hz_frame_calibration_scheduler.v:142 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_sample_index` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_type` | (a) 纠正：本行端口（W9） |
| 矩阵:1446 | ppg_400hz_frame_calibration_scheduler.v:138 | `ppg_400hz_frame_calibration_scheduler.v` `i_transaction_start_ready` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_precision_mode` | (a) 纠正：本行端口（W9） |
| 矩阵:1447 | ppg_400hz_frame_calibration_scheduler.v:140 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_precision_mode` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_sample_index` | (a) 纠正：本行端口（W9） |
| 矩阵:1585 | `:245` | `ppg_system_config_manager.v` `dec_amb_threshold_low` | `ppg_system_config_manager.v` `i_static_characterization_enable` | (b) 纠正：本行端口（W9b） |
| 矩阵:1590 | ppg_control_top.v:740 | `ppg_control_top.v` `i_analog_ready` | `ppg_control_top.v` `o_stage2_coef_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1590 | ppg_control_top.v:1502 | `ppg_control_top.v` `o_result_dc_code_snapshot` | `ppg_control_top.v` `o_stage2_coef_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1591 | ppg_control_top.v:741 | `ppg_control_top.v` `i_adc_idle` | `ppg_control_top.v` `o_dc_recovery_coef_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1591 | ppg_control_top.v:1503 | `ppg_control_top.v` `o_result_amb_code_epoch` | `ppg_control_top.v` `o_dc_recovery_coef_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1608 | ppg_control_top.v:722 | `ppg_control_top.v` `sup_system_fault_summary_o` | `ppg_control_top.v` `i_clk` | (b) 纠正：本行端口（W9b） |
| 矩阵:1611 | ppg_control_top.v:723 | `ppg_control_top.v` `sup_result_discard_summary_sticky_o` | `ppg_control_top.v` `i_rstn` | (b) 纠正：本行端口（W9b） |
| 矩阵:1612 | ppg_control_top.v:718 | `ppg_control_top.v` `sup_system_fault_frame_id_o` | `ppg_control_top.v` `i_source_clk` | (b) 纠正：本行端口（W9b） |
| 矩阵:1613 | ppg_control_top.v:720 | `ppg_control_top.v` `sup_system_fault_frame_type_o` | `ppg_control_top.v` `i_source_config_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1614 | ppg_control_top.v:721 | `ppg_control_top.v` `sup_system_fault_run_generation_o` | `ppg_control_top.v` `i_source_config_update_event` | (b) 纠正：本行端口（W9b） |
| 矩阵:1615 | ppg_control_top.v:719 | `ppg_control_top.v` `sup_system_fault_sample_index_o` | `ppg_control_top.v` `i_source_rstn` | (b) 纠正：本行端口（W9b） |
| 矩阵:1617 | ppg_control_top.v:305,733 | `ppg_control_top.v` `i_source_config_snapshot` | `ppg_control_top.v` `i_static_characterization_enable` | (b) 纠正：本行端口（W9b） |
| 矩阵:1643 | ppg_control_top.v:757 | `ppg_control_top.v` `o_run_enable` | `ppg_control_top.v` `o_input_source` | (b) 纠正：本行端口（W9b） |
| 矩阵:1644 | ppg_control_top.v:758 | `ppg_control_top.v` `o_allow_new_transaction` | `ppg_control_top.v` `o_idac_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1645 | ppg_control_top.v:759 | `ppg_control_top.v` `o_run_generation` | `ppg_control_top.v` `o_optical_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1646 | ppg_control_top.v:760 | `ppg_control_top.v` `o_stop_episode_active` | `ppg_control_top.v` `o_initial_precision` | (b) 纠正：本行端口（W9b） |
| 矩阵:1647 | ppg_control_top.v:761 | `ppg_control_top.v` `o_commit_ack_event` | `ppg_control_top.v` `o_amb_enable` | (b) 纠正：本行端口（W9b） |
| 矩阵:1648 | ppg_control_top.v:762 | `ppg_control_top.v` `o_start_ack_event` | `ppg_control_top.v` `o_dcs_enable` | (b) 纠正：本行端口（W9b） |
| 矩阵:1649 | ppg_control_top.v:763 | `ppg_control_top.v` `o_stop_ack_event` | `ppg_control_top.v` `o_amb_polarity` | (b) 纠正：本行端口（W9b） |
| 矩阵:1650 | ppg_control_top.v:764 | `ppg_control_top.v` `o_error_event` | `ppg_control_top.v` `o_dcs_polarity` | (b) 纠正：本行端口（W9b） |
| 矩阵:1651 | ppg_control_top.v:765 | `ppg_control_top.v` `o_commit_ack_sticky` | `ppg_control_top.v` `o_stage1_calibration_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:1652 | ppg_control_top.v:766 | `ppg_control_top.v` `o_error_sticky` | `ppg_control_top.v` `o_stage2_calibration_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:1653 | ppg_control_top.v:767 | `ppg_control_top.v` `o_last_error_code` | `ppg_control_top.v` `o_dc9_recovery_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:1654 | ppg_control_top.v:768 | `ppg_control_top.v` `o_schema_version` | `ppg_control_top.v` `o_dc15_recovery_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:1655 | ppg_control_top.v:769 | `ppg_control_top.v` `o_run_profile` | `ppg_control_top.v` `o_amb_manual_code` | (b) 纠正：本行端口（W9b） |
| 矩阵:1656 | ppg_control_top.v:770 | `ppg_control_top.v` `o_input_source` | `ppg_control_top.v` `o_amb_code_min` | (b) 纠正：本行端口（W9b） |
| 矩阵:1657 | ppg_control_top.v:771 | `ppg_control_top.v` `o_idac_mode` | `ppg_control_top.v` `o_amb_code_max` | (b) 纠正：本行端口（W9b） |
| 矩阵:1658 | ppg_control_top.v:772 | `ppg_control_top.v` `o_optical_mode` | `ppg_control_top.v` `o_dcs_r_manual_code` | (b) 纠正：本行端口（W9b） |
| 矩阵:1659 | ppg_control_top.v:773 | `ppg_control_top.v` `o_initial_precision` | `ppg_control_top.v` `o_dcs_r_code_min` | (b) 纠正：本行端口（W9b） |
| 矩阵:1660 | ppg_control_top.v:774 | `ppg_control_top.v` `o_amb_enable` | `ppg_control_top.v` `o_dcs_r_code_max` | (b) 纠正：本行端口（W9b） |
| 矩阵:1661 | ppg_control_top.v:775 | `ppg_control_top.v` `o_dcs_enable` | `ppg_control_top.v` `o_dcs_ir_manual_code` | (b) 纠正：本行端口（W9b） |
| 矩阵:1662 | ppg_control_top.v:776 | `ppg_control_top.v` `o_amb_polarity` | `ppg_control_top.v` `o_dcs_ir_code_min` | (b) 纠正：本行端口（W9b） |
| 矩阵:1663 | ppg_control_top.v:777 | `ppg_control_top.v` `o_dcs_polarity` | `ppg_control_top.v` `o_dcs_ir_code_max` | (b) 纠正：本行端口（W9b） |
| 矩阵:1664 | ppg_control_top.v:778 | `ppg_control_top.v` `o_stage1_calibration_valid` | `ppg_control_top.v` `o_amb_threshold_low` | (b) 纠正：本行端口（W9b） |
| 矩阵:1665 | ppg_control_top.v:779 | `ppg_control_top.v` `o_stage2_calibration_valid` | `ppg_control_top.v` `o_amb_threshold_high` | (b) 纠正：本行端口（W9b） |
| 矩阵:1666 | ppg_control_top.v:780 | `ppg_control_top.v` `o_dc9_recovery_valid` | `ppg_control_top.v` `o_dcs_threshold_low` | (b) 纠正：本行端口（W9b） |
| 矩阵:1667 | ppg_control_top.v:781 | `ppg_control_top.v` `o_dc15_recovery_valid` | `ppg_control_top.v` `o_dcs_threshold_high` | (b) 纠正：本行端口（W9b） |
| 矩阵:1670 | ppg_control_top.v:784 | `ppg_control_top.v` `o_amb_code_max` | `ppg_control_top.v` `o_stage1_weight_q16_0` | (b) 纠正：本行端口（W9b） |
| 矩阵:1671 | ppg_control_top.v:785 | `ppg_control_top.v` `o_dcs_r_manual_code` | `ppg_control_top.v` `o_stage1_weight_q16_1` | (b) 纠正：本行端口（W9b） |
| 矩阵:1672 | ppg_control_top.v:786 | `ppg_control_top.v` `o_dcs_r_code_min` | `ppg_control_top.v` `o_stage1_weight_q16_2` | (b) 纠正：本行端口（W9b） |
| 矩阵:1673 | ppg_control_top.v:787 | `ppg_control_top.v` `o_dcs_r_code_max` | `ppg_control_top.v` `o_stage1_weight_q16_3` | (b) 纠正：本行端口（W9b） |
| 矩阵:1674 | ppg_control_top.v:788 | `ppg_control_top.v` `o_dcs_ir_manual_code` | `ppg_control_top.v` `o_stage1_weight_q16_4` | (b) 纠正：本行端口（W9b） |
| 矩阵:1675 | ppg_control_top.v:789 | `ppg_control_top.v` `o_dcs_ir_code_min` | `ppg_control_top.v` `o_stage1_weight_q16_5` | (b) 纠正：本行端口（W9b） |
| 矩阵:1676 | ppg_control_top.v:790 | `ppg_control_top.v` `o_dcs_ir_code_max` | `ppg_control_top.v` `o_stage1_weight_q16_6` | (b) 纠正：本行端口（W9b） |
| 矩阵:1677 | ppg_control_top.v:791 | `ppg_control_top.v` `o_amb_threshold_low` | `ppg_control_top.v` `o_stage1_weight_q16_7` | (b) 纠正：本行端口（W9b） |
| 矩阵:1678 | ppg_control_top.v:792 | `ppg_control_top.v` `o_amb_threshold_high` | `ppg_control_top.v` `o_stage1_weight_q16_8` | (b) 纠正：本行端口（W9b） |
| 矩阵:1679 | ppg_control_top.v:793 | `ppg_control_top.v` `o_dcs_threshold_low` | `ppg_control_top.v` `o_stage1_weight_q16_9` | (b) 纠正：本行端口（W9b） |
| 矩阵:1680 | ppg_control_top.v:794 | `ppg_control_top.v` `o_dcs_threshold_high` | `ppg_control_top.v` `o_stage1_offset_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1681 | ppg_control_top.v:795 | `ppg_control_top.v` `o_amb_confirm_count` | `ppg_control_top.v` `o_stage2_gain_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1682 | ppg_control_top.v:796 | `ppg_control_top.v` `o_dcs_confirm_count` | `ppg_control_top.v` `o_stage2_offset_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1683 | ppg_control_top.v:797 | `ppg_control_top.v` `o_stage1_weight_q16_0` | `ppg_control_top.v` `o_dc9_recovery_gain_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1684 | ppg_control_top.v:798 | `ppg_control_top.v` `o_stage1_weight_q16_1` | `ppg_control_top.v` `o_dc15_recovery_gain_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1685 | ppg_control_top.v:799 | `ppg_control_top.v` `o_stage1_weight_q16_2` | `ppg_control_top.v` `o_amb_recheck_interval_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:1686 | ppg_control_top.v:800 | `ppg_control_top.v` `o_stage1_weight_q16_3` | `ppg_control_top.v` `o_slope_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1687 | ppg_control_top.v:801 | `ppg_control_top.v` `o_stage1_weight_q16_4` | `ppg_control_top.v` `o_fixed_slope_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1688 | ppg_control_top.v:802 | `ppg_control_top.v` `o_stage1_weight_q16_5` | `ppg_control_top.v` `o_alpha_q15` | (b) 纠正：本行端口（W9b） |
| 矩阵:1689 | ppg_control_top.v:803 | `ppg_control_top.v` `o_stage1_weight_q16_6` | `ppg_control_top.v` `o_beta_q15` | (b) 纠正：本行端口（W9b） |
| 矩阵:1690 | ppg_control_top.v:804 | `ppg_control_top.v` `o_stage1_weight_q16_7` | `ppg_control_top.v` `o_timing_adjust_ratio_q15` | (b) 纠正：本行端口（W9b） |
| 矩阵:1691 | ppg_control_top.v:805 | `ppg_control_top.v` `o_stage1_weight_q16_8` | `ppg_control_top.v` `o_slope_min_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1692 | ppg_control_top.v:806 | `ppg_control_top.v` `o_stage1_weight_q16_9` | `ppg_control_top.v` `o_slope_max_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1693 | ppg_control_top.v:807 | `ppg_control_top.v` `o_stage1_offset_q16` | `ppg_control_top.v` `o_baseline_delta_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1694 | ppg_control_top.v:808 | `ppg_control_top.v` `o_stage2_gain_q16` | `ppg_control_top.v` `o_cross_hysteresis_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:1695 | ppg_control_top.v:809 | `ppg_control_top.v` `o_stage2_offset_q16` | `ppg_control_top.v` `o_lead_min_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:1696 | ppg_control_top.v:810 | `ppg_control_top.v` `o_dc9_recovery_gain_q16` | `ppg_control_top.v` `o_lead_max_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:1698 | ppg_control_top.v:812 | `ppg_control_top.v` `o_amb_recheck_interval_frames` | `ppg_control_top.v` `o_no_cross_limit` | (b) 纠正：本行端口（W9b） |
| 矩阵:1701 | ppg_control_top.v:815 | `ppg_control_top.v` `o_alpha_q15` | `ppg_control_top.v` `o_direction_deadband` | (b) 纠正：本行端口（W9b） |
| 矩阵:1702 | ppg_control_top.v:816 | `ppg_control_top.v` `o_beta_q15` | `ppg_control_top.v` `o_min_peak_valley_amplitude` | (b) 纠正：本行端口（W9b） |
| 矩阵:1703 | ppg_control_top.v:817 | `ppg_control_top.v` `o_timing_adjust_ratio_q15` | `ppg_control_top.v` `o_min_peak_to_valley_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:1704 | ppg_control_top.v:818 | `ppg_control_top.v` `o_slope_min_q16` | `ppg_control_top.v` `o_min_peak_to_peak_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:1705 | ppg_control_top.v:819 | `ppg_control_top.v` `o_slope_max_q16` | `ppg_control_top.v` `o_max_fine_window_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:1706 | ppg_control_top.v:820 | `ppg_control_top.v` `o_baseline_delta_q16` | `ppg_control_top.v` `o_max_reacquire_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:1803 | ppg_control_top.v:828 | `ppg_control_top.v` `o_direction_deadband` | `ppg_control_top.v` `i_source_clk` | (b) 纠正：本行端口（W9b） |
| 矩阵:1804 | ppg_control_top.v:829 | `ppg_control_top.v` `o_min_peak_valley_amplitude` | `ppg_control_top.v` `i_source_rstn` | (b) 纠正：本行端口（W9b） |
| 矩阵:1805 | ppg_control_top.v:830 | `ppg_control_top.v` `o_min_peak_to_valley_frames` | `ppg_control_top.v` `i_clk` | (b) 纠正：本行端口（W9b） |
| 矩阵:1806 | ppg_control_top.v:831 | `ppg_control_top.v` `o_min_peak_to_peak_frames` | `ppg_control_top.v` `i_rstn` | (b) 纠正：本行端口（W9b） |
| 矩阵:1808 | ppg_control_top.v:833 | `ppg_control_top.v` `o_max_reacquire_frames` | `ppg_control_top.v` `i_source_static_characterization_enable` | (b) 纠正：本行端口（W9b） |
| 矩阵:1809 | ppg_control_top.v:834 | `ppg_control_top.v` `o_peak_valley_config_valid` | `ppg_control_top.v` `i_source_test_mux_ctrl` | (b) 纠正：本行端口（W9b） |
| 矩阵:1823 | ppg_400hz_frame_calibration_scheduler.v:84 | `ppg_400hz_frame_calibration_scheduler.v` `i_active_config_valid` | `ppg_400hz_frame_calibration_scheduler.v` `i_allow_new_transaction` | (b) 纠正：本行端口（W9b） |
| 矩阵:1824 | ppg_400hz_frame_calibration_scheduler.v:85 | `ppg_400hz_frame_calibration_scheduler.v` `i_run_enable` | `ppg_400hz_frame_calibration_scheduler.v` `i_start_ack_event` | (b) 纠正：本行端口（W9b） |
| 矩阵:1825 | ppg_400hz_frame_calibration_scheduler.v:86 | `ppg_400hz_frame_calibration_scheduler.v` `i_allow_new_transaction` | `ppg_400hz_frame_calibration_scheduler.v` `i_stop_ack_event` | (b) 纠正：本行端口（W9b） |
| 矩阵:1826 | ppg_400hz_frame_calibration_scheduler.v:87 | `ppg_400hz_frame_calibration_scheduler.v` `i_start_ack_event` | `ppg_400hz_frame_calibration_scheduler.v` `i_control_abort_event` | (b) 纠正：本行端口（W9b） |
| 矩阵:1827 | ppg_400hz_frame_calibration_scheduler.v:88 | `ppg_400hz_frame_calibration_scheduler.v` `i_stop_ack_event` | `ppg_400hz_frame_calibration_scheduler.v` `i_diag_clear_event` | (b) 纠正：本行端口（W9b） |
| 矩阵:1828 | ppg_400hz_frame_calibration_scheduler.v:89 | `ppg_400hz_frame_calibration_scheduler.v` `i_control_abort_event` | `ppg_400hz_frame_calibration_scheduler.v` `i_run_generation` | (b) 纠正：本行端口（W9b） |
| 矩阵:1831 | ppg_400hz_frame_calibration_scheduler.v:94 | `ppg_400hz_frame_calibration_scheduler.v` `i_run_profile` | `ppg_400hz_frame_calibration_scheduler.v` `i_optical_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1832 | ppg_400hz_frame_calibration_scheduler.v:95 | `ppg_400hz_frame_calibration_scheduler.v` `i_input_source` | `ppg_400hz_frame_calibration_scheduler.v` `i_active_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1833 | ppg_400hz_frame_calibration_scheduler.v:96 | `ppg_400hz_frame_calibration_scheduler.v` `i_optical_mode` | `ppg_400hz_frame_calibration_scheduler.v` `i_normal_measurement_eligible` | (b) 纠正：本行端口（W9b） |
| 矩阵:1834 | ppg_400hz_frame_calibration_scheduler.v:97 | `ppg_400hz_frame_calibration_scheduler.v` `i_active_precision_mode` | `ppg_400hz_frame_calibration_scheduler.v` `i_switch_hold_new_transaction` | (b) 纠正：本行端口（W9b） |
| 矩阵:1835 | ppg_400hz_frame_calibration_scheduler.v:98 | `ppg_400hz_frame_calibration_scheduler.v` `i_normal_measurement_eligible` | `ppg_400hz_frame_calibration_scheduler.v` `i_ami_fault_blocking` | (b) 纠正：本行端口（W9b） |
| 矩阵:1836 | ppg_400hz_frame_calibration_scheduler.v:99 | `ppg_400hz_frame_calibration_scheduler.v` `i_switch_hold_new_transaction` | `ppg_400hz_frame_calibration_scheduler.v` `i_ssw_fault_blocking` | (b) 纠正：本行端口（W9b） |
| 矩阵:1837 | ppg_400hz_frame_calibration_scheduler.v:100 | `ppg_400hz_frame_calibration_scheduler.v` `i_ami_fault_blocking` | `ppg_400hz_frame_calibration_scheduler.v` `i_amb_code` | (b) 纠正：本行端口（W9b） |
| 矩阵:1838 | ppg_400hz_frame_calibration_scheduler.v:101 | `ppg_400hz_frame_calibration_scheduler.v` `i_ssw_fault_blocking` | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_r_code` | (b) 纠正：本行端口（W9b） |
| 矩阵:1839 | ppg_400hz_frame_calibration_scheduler.v:102 | `ppg_400hz_frame_calibration_scheduler.v` `i_amb_code` | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_ir_code` | (b) 纠正：本行端口（W9b） |
| 矩阵:1840 | ppg_400hz_frame_calibration_scheduler.v:103 | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_r_code` | `ppg_400hz_frame_calibration_scheduler.v` `i_amb_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1841 | ppg_400hz_frame_calibration_scheduler.v:104 | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_ir_code` | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_r_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1842 | ppg_400hz_frame_calibration_scheduler.v:105 | `ppg_400hz_frame_calibration_scheduler.v` `i_amb_code_epoch` | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_ir_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1843 | ppg_400hz_frame_calibration_scheduler.v:106 | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_r_code_epoch` | `ppg_400hz_frame_calibration_scheduler.v` `i_leddac_r_code` | (b) 纠正：本行端口（W9b） |
| 矩阵:1844 | ppg_400hz_frame_calibration_scheduler.v:107 | `ppg_400hz_frame_calibration_scheduler.v` `i_dcs_ir_code_epoch` | `ppg_400hz_frame_calibration_scheduler.v` `i_leddac_ir_code` | (b) 纠正：本行端口（W9b） |
| 矩阵:1847 | ppg_400hz_frame_calibration_scheduler.v:112 | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_sample_valid` | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_frame_type` | (b) 纠正：本行端口（W9b） |
| 矩阵:1848 | ppg_400hz_frame_calibration_scheduler.v:113 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_sample_ready` | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_color_ir` | (b) 纠正：本行端口（W9b） |
| 矩阵:1849 | ppg_400hz_frame_calibration_scheduler.v:114 | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_frame_type` | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1850 | ppg_400hz_frame_calibration_scheduler.v:115 | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_color_ir` | `ppg_400hz_frame_calibration_scheduler.v` `i_calibration_request_reason` | (b) 纠正：本行端口（W9b） |
| 矩阵:1853 | ppg_400hz_frame_calibration_scheduler.v:120 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_context_valid` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1854 | ppg_400hz_frame_calibration_scheduler.v:121 | `ppg_400hz_frame_calibration_scheduler.v` `i_waveform_context_ready` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:1855 | ppg_400hz_frame_calibration_scheduler.v:122 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_precision_mode` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_color_ir` | (b) 纠正：本行端口（W9b） |
| 矩阵:1856 | ppg_400hz_frame_calibration_scheduler.v:123 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_frame_id` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_frame_type` | (b) 纠正：本行端口（W9b） |
| 矩阵:1857 | ppg_400hz_frame_calibration_scheduler.v:124 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_color_ir` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_amb_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1858 | ppg_400hz_frame_calibration_scheduler.v:125 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_frame_type` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_dc_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1859 | ppg_400hz_frame_calibration_scheduler.v:126 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_amb_code_snapshot` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_amb_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1860 | ppg_400hz_frame_calibration_scheduler.v:127 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_dc_code_snapshot` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_dc_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1861 | ppg_400hz_frame_calibration_scheduler.v:128 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_amb_code_epoch` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_input_source` | (b) 纠正：本行端口（W9b） |
| 矩阵:1862 | ppg_400hz_frame_calibration_scheduler.v:129 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_dc_code_epoch` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_optical_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1863 | ppg_400hz_frame_calibration_scheduler.v:130 | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_input_source` | `ppg_400hz_frame_calibration_scheduler.v` `o_waveform_leddac_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1866 | ppg_400hz_frame_calibration_scheduler.v:137 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_start_valid` | `ppg_400hz_frame_calibration_scheduler.v` `i_transaction_start_fire` | (b) 纠正：本行端口（W9b） |
| 矩阵:1867 | ppg_400hz_frame_calibration_scheduler.v:138 | `ppg_400hz_frame_calibration_scheduler.v` `i_transaction_start_ready` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1867 | ppg_control_top.v:905 | `ppg_control_top.v` `o_waveform_frame_id` | `ppg_control_top.v` `o_transaction_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1868 | ppg_400hz_frame_calibration_scheduler.v:139 | `ppg_400hz_frame_calibration_scheduler.v` `i_transaction_start_fire` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:1868 | ppg_control_top.v:906 | `ppg_control_top.v` `o_waveform_color_ir` | `ppg_control_top.v` `o_transaction_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:1869 | ppg_400hz_frame_calibration_scheduler.v:140 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_precision_mode` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_sample_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:1869 | ppg_control_top.v:907 | `ppg_control_top.v` `o_waveform_frame_type` | `ppg_control_top.v` `o_transaction_sample_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:1870 | ppg_400hz_frame_calibration_scheduler.v:141 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_id` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_color_ir` | (b) 纠正：本行端口（W9b） |
| 矩阵:1870 | ppg_control_top.v:908 | `ppg_control_top.v` `o_waveform_amb_code_snapshot` | `ppg_control_top.v` `o_transaction_color_ir` | (b) 纠正：本行端口（W9b） |
| 矩阵:1871 | ppg_400hz_frame_calibration_scheduler.v:142 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_sample_index` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_type` | (b) 纠正：本行端口（W9b） |
| 矩阵:1871 | ppg_control_top.v:909 | `ppg_control_top.v` `o_waveform_dc_code_snapshot` | `ppg_control_top.v` `o_transaction_frame_type` | (b) 纠正：本行端口（W9b） |
| 矩阵:1872 | ppg_400hz_frame_calibration_scheduler.v:143 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_color_ir` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1872 | ppg_control_top.v:910 | `ppg_control_top.v` `o_waveform_amb_code_epoch` | `ppg_control_top.v` `o_transaction_amb_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1873 | ppg_400hz_frame_calibration_scheduler.v:144 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_frame_type` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1873 | ppg_control_top.v:911 | `ppg_control_top.v` `o_waveform_dc_code_epoch` | `ppg_control_top.v` `o_transaction_dc_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1874 | ppg_400hz_frame_calibration_scheduler.v:145 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_snapshot` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_amb_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1874 | ppg_control_top.v:912 | `ppg_control_top.v` `o_waveform_input_source` | `ppg_control_top.v` `o_transaction_amb_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1875 | ppg_400hz_frame_calibration_scheduler.v:146 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_snapshot` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_dc_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1875 | ppg_control_top.v:913 | `ppg_control_top.v` `o_waveform_optical_mode` | `ppg_control_top.v` `o_transaction_dc_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1878 | ppg_400hz_frame_calibration_scheduler.v:151 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_owner_ready` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1879 | ppg_400hz_frame_calibration_scheduler.v:152 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_commit_event` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:1880 | ppg_400hz_frame_calibration_scheduler.v:153 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_precision_mode` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_color_ir` | (b) 纠正：本行端口（W9b） |
| 矩阵:1881 | ppg_400hz_frame_calibration_scheduler.v:154 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_frame_id` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_frame_type` | (b) 纠正：本行端口（W9b） |
| 矩阵:1882 | ppg_400hz_frame_calibration_scheduler.v:155 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_color_ir` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_amb_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1883 | ppg_400hz_frame_calibration_scheduler.v:156 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_frame_type` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_dc_code_snapshot` | (b) 纠正：本行端口（W9b） |
| 矩阵:1884 | ppg_400hz_frame_calibration_scheduler.v:157 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_amb_code_snapshot` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_amb_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1885 | ppg_400hz_frame_calibration_scheduler.v:158 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_dc_code_snapshot` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_dc_code_epoch` | (b) 纠正：本行端口（W9b） |
| 矩阵:1886 | ppg_400hz_frame_calibration_scheduler.v:159 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_amb_code_epoch` | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_sample_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:1887 | ppg_400hz_frame_calibration_scheduler.v:160 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_dc_code_epoch` | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_transaction_complete_event` | (b) 纠正：本行端口（W9b） |
| 矩阵:1888 | ppg_400hz_frame_calibration_scheduler.v:161 | `ppg_400hz_frame_calibration_scheduler.v` `o_adc_owner_sample_index` | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_transaction_success` | (b) 纠正：本行端口（W9b） |
| 矩阵:1889 | ppg_400hz_frame_calibration_scheduler.v:162 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_transaction_complete_event` | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_complete_sample_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:1890 | ppg_400hz_frame_calibration_scheduler.v:163 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_transaction_success` | `ppg_400hz_frame_calibration_scheduler.v` `i_owner_q3_window_closed` | (b) 纠正：本行端口（W9b） |
| 矩阵:1891 | ppg_400hz_frame_calibration_scheduler.v:164 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_complete_sample_index` | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_idle` | (b) 纠正：本行端口（W9b） |
| 矩阵:1892 | ppg_400hz_frame_calibration_scheduler.v:165 | `ppg_400hz_frame_calibration_scheduler.v` `i_owner_q3_window_closed` | `ppg_400hz_frame_calibration_scheduler.v` `i_analog_safe` | (b) 纠正：本行端口（W9b） |
| 矩阵:1893 | ppg_400hz_frame_calibration_scheduler.v:166 | `ppg_400hz_frame_calibration_scheduler.v` `i_adc_idle` | `ppg_400hz_frame_calibration_scheduler.v` `i_sar_timing_idle` | (b) 纠正：本行端口（W9b） |
| 矩阵:1894 | ppg_control_top.v:932 | `ppg_control_top.v` `o_adc_owner_frame_type` | `ppg_control_top.v` `o_macro_frame_start_event` | (a) 纠正：同文件 |
| 矩阵:1896 | ppg_400hz_frame_calibration_scheduler.v:171 | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_frame_start_event` | `ppg_400hz_frame_calibration_scheduler.v` `o_idac_code_safe_boundary` | (b) 纠正：本行端口（W9b） |
| 矩阵:1897 | ppg_control_top.v:935 | `ppg_control_top.v` `o_macro_frame_start_event` | `ppg_control_top.v` `o_startup_idac_safe_boundary` | (a) 纠正：同文件 |
| 矩阵:1898 | ppg_400hz_frame_calibration_scheduler.v:173 | `ppg_400hz_frame_calibration_scheduler.v` `o_idac_code_safe_boundary` | `ppg_400hz_frame_calibration_scheduler.v` `o_safe_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:1899 | ppg_400hz_frame_calibration_scheduler.v:174 | `ppg_400hz_frame_calibration_scheduler.v` `o_startup_idac_safe_boundary` | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_tick` | (b) 纠正：本行端口（W9b） |
| 矩阵:1900 | ppg_400hz_frame_calibration_scheduler.v:175 | `ppg_400hz_frame_calibration_scheduler.v` `o_safe_frame_id` | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_subframe_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:1901 | ppg_400hz_frame_calibration_scheduler.v:176 | `ppg_400hz_frame_calibration_scheduler.v` `o_macro_tick` | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_local_tick` | (b) 纠正：本行端口（W9b） |
| 矩阵:1902 | ppg_400hz_frame_calibration_scheduler.v:177 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_subframe_index` | `ppg_400hz_frame_calibration_scheduler.v` `o_normal_frame_complete_event` | (b) 纠正：本行端口（W9b） |
| 矩阵:1903 | ppg_400hz_frame_calibration_scheduler.v:178 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_local_tick` | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_frame_complete_event` | (b) 纠正：本行端口（W9b） |
| 矩阵:1906 | ppg_400hz_frame_calibration_scheduler.v:183 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_idle` | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_frame_active` | (b) 纠正：本行端口（W9b） |
| 矩阵:1907 | ppg_400hz_frame_calibration_scheduler.v:184 | `ppg_400hz_frame_calibration_scheduler.v` `o_normal_frame_active` | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_inflight` | (b) 纠正：本行端口（W9b） |
| 矩阵:1907 | ppg_control_top.v:945 | `ppg_control_top.v` `o_macro_frame_start_event` | `ppg_control_top.v` `o_transaction_inflight` | (a) 纠正：同文件 |
| 矩阵:1908 | ppg_400hz_frame_calibration_scheduler.v:185 | `ppg_400hz_frame_calibration_scheduler.v` `o_calibration_frame_active` | `ppg_400hz_frame_calibration_scheduler.v` `o_current_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:1908 | ppg_control_top.v:946 | `ppg_control_top.v` `o_macro_frame_safe_boundary` | `ppg_control_top.v` `o_current_frame_id` | (a) 纠正：同文件 |
| 矩阵:1909 | ppg_400hz_frame_calibration_scheduler.v:186 | `ppg_400hz_frame_calibration_scheduler.v` `o_transaction_inflight` | `ppg_400hz_frame_calibration_scheduler.v` `o_next_sample_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:1909 | ppg_control_top.v:947 | `ppg_control_top.v` `o_idac_code_safe_boundary` | `ppg_control_top.v` `o_next_sample_index` | (a) 纠正：同文件 |
| 矩阵:1910 | ppg_400hz_frame_calibration_scheduler.v:187 | `ppg_400hz_frame_calibration_scheduler.v` `o_current_frame_id` | `ppg_400hz_frame_calibration_scheduler.v` `o_launch_timeout_sticky` | (b) 纠正：本行端口（W9b） |
| 矩阵:1911 | ppg_400hz_frame_calibration_scheduler.v:188 | `ppg_400hz_frame_calibration_scheduler.v` `o_next_sample_index` | `ppg_400hz_frame_calibration_scheduler.v` `o_owner_deadline_timeout_sticky` | (b) 纠正：本行端口（W9b） |
| 矩阵:1912 | ppg_400hz_frame_calibration_scheduler.v:189 | `ppg_400hz_frame_calibration_scheduler.v` `o_launch_timeout_sticky` | `ppg_400hz_frame_calibration_scheduler.v` `o_completion_mismatch_sticky` | (b) 纠正：本行端口（W9b） |
| 矩阵:1913 | ppg_400hz_frame_calibration_scheduler.v:190 | `ppg_400hz_frame_calibration_scheduler.v` `o_owner_deadline_timeout_sticky` | `ppg_400hz_frame_calibration_scheduler.v` `o_protocol_error_sticky` | (b) 纠正：本行端口（W9b） |
| 矩阵:1914 | ppg_control_top.v:952 | `ppg_control_top.v` `o_scheduler_fault_active` | `ppg_control_top.v` `o_scheduler_local_fault_blocking` | (a) 纠正：同文件 |
| 矩阵:1915 | ppg_400hz_frame_calibration_scheduler.v:194 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_local_fault_blocking` | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:1916 | ppg_control_top.v:954 | `ppg_control_top.v` `o_calibration_frame_complete_event` | `ppg_control_top.v` `o_scheduler_fault_active` | (b) 纠正：本行端口（W9b） |
| 矩阵:1917 | ppg_control_top.v:955 | `ppg_control_top.v` `o_scheduler_idle` | `ppg_control_top.v` `o_scheduler_fault_cause` | (b) 纠正：本行端口（W9b） |
| 矩阵:1918 | ppg_400hz_frame_calibration_scheduler.v:197 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_valid` | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_identity_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:1918 | ppg_control_top.v:956 | `ppg_control_top.v` `o_normal_frame_active` | `ppg_control_top.v` `o_scheduler_fault_identity_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:1919 | ppg_400hz_frame_calibration_scheduler.v:198 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_active` | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:1919 | ppg_control_top.v:957 | `ppg_control_top.v` `o_calibration_frame_active` | `ppg_control_top.v` `o_scheduler_fault_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:1920 | ppg_400hz_frame_calibration_scheduler.v:199 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_cause` | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_sample_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:1920 | ppg_control_top.v:958 | `ppg_control_top.v` `o_transaction_inflight` | `ppg_control_top.v` `o_scheduler_fault_sample_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:1921 | ppg_400hz_frame_calibration_scheduler.v:200 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_identity_valid` | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_color_ir` | (b) 纠正：本行端口（W9b） |
| 矩阵:1921 | ppg_control_top.v:959 | `ppg_control_top.v` `o_current_frame_id` | `ppg_control_top.v` `o_scheduler_fault_color_ir` | (b) 纠正：本行端口（W9b） |
| 矩阵:1922 | ppg_400hz_frame_calibration_scheduler.v:201 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_frame_id` | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_frame_type` | (b) 纠正：本行端口（W9b） |
| 矩阵:1922 | ppg_control_top.v:960 | `ppg_control_top.v` `o_next_sample_index` | `ppg_control_top.v` `o_scheduler_fault_frame_type` | (b) 纠正：本行端口（W9b） |
| 矩阵:1923 | ppg_400hz_frame_calibration_scheduler.v:202 | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_sample_index` | `ppg_400hz_frame_calibration_scheduler.v` `o_scheduler_fault_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:1923 | ppg_control_top.v:961 | `ppg_control_top.v` `o_launch_timeout_sticky` | `ppg_control_top.v` `o_scheduler_fault_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:2016 | ppg_control_top.v:1068 | `ppg_control_top.v` `o_s_in` | `ppg_control_top.v` `o_ssw_fault_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:2017 | ppg_control_top.v:1069 | `ppg_control_top.v` `o_clk_2m` | `ppg_control_top.v` `o_ssw_fault_active` | (b) 纠正：本行端口（W9b） |
| 矩阵:2018 | ppg_control_top.v:1070 | `ppg_control_top.v` `o_analog_safe` | `ppg_control_top.v` `o_ssw_fault_cause` | (b) 纠正：本行端口（W9b） |
| 矩阵:2019 | ppg_control_top.v:1071 | `ppg_control_top.v` `o_sar_timing_idle` | `ppg_control_top.v` `o_ssw_fault_identity_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:2020 | ppg_control_top.v:1072 | `ppg_control_top.v` `o_wrapper_idle` | `ppg_control_top.v` `o_ssw_fault_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:2021 | ppg_control_top.v:1073 | `ppg_control_top.v` `o_precision_active` | `ppg_control_top.v` `o_ssw_fault_sample_index` | (b) 纠正：本行端口（W9b） |
| 矩阵:2022 | ppg_control_top.v:1074 | `ppg_control_top.v` `o_calibration_wave_active` | `ppg_control_top.v` `o_ssw_fault_color_ir` | (b) 纠正：本行端口（W9b） |
| 矩阵:2023 | ppg_control_top.v:1075 | `ppg_control_top.v` `o_adc_owner_inflight` | `ppg_control_top.v` `o_ssw_fault_frame_type` | (b) 纠正：本行端口（W9b） |
| 矩阵:2024 | ppg_control_top.v:1076 | `ppg_control_top.v` `o_owner_q3_window_closed` | `ppg_control_top.v` `o_ssw_fault_precision_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:2195 | `:203-224` | `ppg_amb_recheck_scheduler.v` `o_amb_sequence_start`、`o_dcs_revalidate_accept`、`o_calibration_sample_valid`、`o_calibration_frame_type` | `ppg_amb_recheck_scheduler.v` `o_scheduler_idle` | (b) 纠正：本行端口（W9b） |
| 矩阵:2260 | `:2570,1090` | `ppg_adc_measurement_idac_integration.v` `o_fine_window_start_frame_id`、`o_idac_protocol_error_sticky` | `ppg_adc_measurement_idac_integration.v` `o_amb_recheck_pending` | (b) 纠正：本行端口（W9b） |
| 矩阵:2261 | `:2571,1091` | `ppg_adc_measurement_idac_integration.v` `o_precision_15_to_9_event`、`o_startup_search_complete` | `ppg_adc_measurement_idac_integration.v` `o_amb_recheck_accept` | (b) 纠正：本行端口（W9b） |
| 矩阵:2262 | `:2572,1092` | `ppg_adc_measurement_idac_integration.v` `o_precision_15_to_9_frame_id`、`o_idac_idle` | `ppg_adc_measurement_idac_integration.v` `o_amb_recheck_busy` | (b) 纠正：本行端口（W9b） |
| 矩阵:2263 | `:2573,1093` | `ppg_adc_measurement_idac_integration.v` `o_reacquire_request_event` | `ppg_adc_measurement_idac_integration.v` `o_normal_output_inhibit` | (b) 纠正：本行端口（W9b） |
| 矩阵:2444 | `:244` | `ppg_adc_measurement_idac_integration.v` `i_dc15_recovery_gain_q16` | `ppg_adc_measurement_idac_integration.v` `i_slope_mode` | (b) 纠正：本行端口（W9b） |
| 矩阵:2447 | `:247` | `ppg_adc_measurement_idac_integration.v` `i_run_profile` | `ppg_adc_measurement_idac_integration.v` `i_beta_q15` | (b) 纠正：本行端口（W9b） |
| 矩阵:2448 | `:248` | `ppg_adc_measurement_idac_integration.v` `i_initial_precision` | `ppg_adc_measurement_idac_integration.v` `i_timing_adjust_ratio_q15` | (b) 纠正：本行端口（W9b） |
| 矩阵:2449 | `:249` | `ppg_adc_measurement_idac_integration.v` `i_slope_mode` | `ppg_adc_measurement_idac_integration.v` `i_slope_min_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:2450 | `:250` | `ppg_adc_measurement_idac_integration.v` `i_fixed_slope_q16` | `ppg_adc_measurement_idac_integration.v` `i_slope_max_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:2451 | `:251` | `ppg_adc_measurement_idac_integration.v` `i_alpha_q15` | `ppg_adc_measurement_idac_integration.v` `i_baseline_delta_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:2452 | `:252` | `ppg_adc_measurement_idac_integration.v` `i_beta_q15` | `ppg_adc_measurement_idac_integration.v` `i_cross_hysteresis_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:2453 | `:253` | `ppg_adc_measurement_idac_integration.v` `i_timing_adjust_ratio_q15` | `ppg_adc_measurement_idac_integration.v` `i_lead_min_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:2454 | `:254` | `ppg_adc_measurement_idac_integration.v` `i_slope_min_q16` | `ppg_adc_measurement_idac_integration.v` `i_lead_max_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:2455 | `:255` | `ppg_adc_measurement_idac_integration.v` `i_slope_max_q16` | `ppg_adc_measurement_idac_integration.v` `i_cross_confirm_count` | (b) 纠正：本行端口（W9b） |
| 矩阵:2456 | `:256` | `ppg_adc_measurement_idac_integration.v` `i_baseline_delta_q16` | `ppg_adc_measurement_idac_integration.v` `i_no_cross_limit` | (b) 纠正：本行端口（W9b） |
| 矩阵:2457 | `:257` | `ppg_adc_measurement_idac_integration.v` `i_cross_hysteresis_q16` | `ppg_adc_measurement_idac_integration.v` `i_peak_confirm_count` | (b) 纠正：本行端口（W9b） |
| 矩阵:2458 | `:258` | `ppg_adc_measurement_idac_integration.v` `i_lead_min_frames` | `ppg_adc_measurement_idac_integration.v` `i_valley_confirm_count` | (b) 纠正：本行端口（W9b） |
| 矩阵:2459 | `:259` | `ppg_adc_measurement_idac_integration.v` `i_lead_max_frames` | `ppg_adc_measurement_idac_integration.v` `i_direction_deadband` | (b) 纠正：本行端口（W9b） |
| 矩阵:2460 | `:260` | `ppg_adc_measurement_idac_integration.v` `i_cross_confirm_count` | `ppg_adc_measurement_idac_integration.v` `i_min_peak_valley_amplitude` | (b) 纠正：本行端口（W9b） |
| 矩阵:2461 | `:261` | `ppg_adc_measurement_idac_integration.v` `i_no_cross_limit` | `ppg_adc_measurement_idac_integration.v` `i_min_peak_to_valley_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:2462 | `:262` | `ppg_adc_measurement_idac_integration.v` `i_peak_confirm_count` | `ppg_adc_measurement_idac_integration.v` `i_min_peak_to_peak_frames` | (b) 纠正：本行端口（W9b） |
| 矩阵:2465 | `:265` | `ppg_adc_measurement_idac_integration.v` `i_min_peak_valley_amplitude` | `ppg_adc_measurement_idac_integration.v` `i_peak_valley_config_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:2466 | ppg_control_top.v:1297 | `ppg_control_top.v` `o_precision_15_to_9_event` | `ppg_control_top.v` `o_detection_fork_idle` | (a) 纠正：同文件 |
| 矩阵:2467 | ppg_control_top.v:1298 | `ppg_control_top.v` `o_precision_15_to_9_frame_id` | `ppg_control_top.v` `o_detector_idle` | (a) 纠正：同文件 |
| 矩阵:2468 | ppg_control_top.v:1301 | `ppg_control_top.v` `o_mode_fault_event` | `ppg_control_top.v` `o_cross_pending` | (a) 纠正：同文件 |
| 矩阵:2469 | ppg_control_top.v:1302 | `ppg_control_top.v` `o_normal_frame_count` | `ppg_control_top.v` `o_peak_pending` | (a) 纠正：同文件 |
| 矩阵:2470 | ppg_control_top.v:1303 | `ppg_control_top.v` `o_amb_recheck_pending` | `ppg_control_top.v` `o_valley_pending` | (a) 纠正：同文件 |
| 矩阵:2471 | ppg_control_top.v:1304 | `ppg_control_top.v` `o_amb_recheck_accept` | `ppg_control_top.v` `o_return_pending` | (a) 纠正：同文件 |
| 矩阵:2472 | ppg_control_top.v:1305 | `ppg_control_top.v` `o_amb_recheck_busy` | `ppg_control_top.v` `o_baseline_valid` | (a) 纠正：同文件 |
| 矩阵:2473 | ppg_control_top.v:1306 | `ppg_control_top.v` `o_normal_output_inhibit` | `ppg_control_top.v` `o_reacquire_active` | (a) 纠正：同文件 |
| 矩阵:2474 | ppg_control_top.v:1307 | `ppg_control_top.v` `o_recheck_sequence_done` | `ppg_control_top.v` `o_detector_fine_window_active` | (a) 纠正：同文件 |
| 矩阵:2475 | ppg_control_top.v:1310 | `ppg_control_top.v` `o_fir_history_full_ir` | `ppg_control_top.v` `o_slope_current_q16` | (a) 纠正：同文件 |
| 矩阵:2476 | ppg_control_top.v:1311 | `ppg_control_top.v` `o_fir_idle` | `ppg_control_top.v` `o_baseline_protocol_error_sticky` | (a) 纠正：同文件 |
| 矩阵:2477 | ppg_control_top.v:1312 | `ppg_control_top.v` `o_detection_fork_idle` | `ppg_control_top.v` `o_fine_window_timeout_sticky` | (a) 纠正：同文件 |
| 矩阵:2478 | ppg_control_top.v:1313 | `ppg_control_top.v` `o_detector_idle` | `ppg_control_top.v` `o_reacquire_timeout_sticky` | (a) 纠正：同文件 |
| 矩阵:2479 | ppg_control_top.v:1314 | `ppg_control_top.v` `o_controller_idle` | `ppg_control_top.v` `o_peak_valley_protocol_error_sticky` | (a) 纠正：同文件 |
| 矩阵:2503 | ppg_adc_measurement_idac_integration.v:242 | `ppg_adc_measurement_idac_integration.v` `i_dc15_recovery_valid` | `ppg_adc_measurement_idac_integration.v` `i_run_profile` | (b) 纠正：本行端口（W9b） |
| 矩阵:2504 | `:243` | `ppg_adc_measurement_idac_integration.v` `i_dc9_recovery_gain_q16` | `ppg_adc_measurement_idac_integration.v` `i_initial_precision` | (b) 纠正：本行端口（W9b） |
| 矩阵:2520 | `:2525` | `ppg_adc_measurement_idac_integration.v` `i_coarse_saturation_low` | `ppg_adc_measurement_idac_integration.v` `i_safe_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:2522 | `:2527` | `ppg_adc_measurement_idac_integration.v` `i_config_epoch` | `ppg_adc_measurement_idac_integration.v` `i_analog_safe` | (b) 纠正：本行端口（W9b） |
| 矩阵:2619 | `:242` | `ppg_adc_measurement_idac_integration.v` `i_dc15_recovery_valid` | `ppg_adc_measurement_idac_integration.v` `i_run_profile` | (b) 纠正：本行端口（W9b） |
| 矩阵:2620 | `:243` | `ppg_adc_measurement_idac_integration.v` `i_dc9_recovery_gain_q16` | `ppg_adc_measurement_idac_integration.v` `i_initial_precision` | (b) 纠正：本行端口（W9b） |
| 矩阵:2622 | `:143` | `ppg_adc_measurement_idac_integration.v` `i_adc_idle` | `ppg_adc_measurement_idac_integration.v` `i_safe_frame_id` | (b) 纠正：本行端口（W9b） |
| 矩阵:2623 | `:140` | `ppg_adc_measurement_idac_integration.v` `i_clk_stage1_dout_low_async` | `ppg_adc_measurement_idac_integration.v` `i_analog_safe` | (b) 纠正：本行端口（W9b） |
| 矩阵:2624 | `:393` | `ppg_adc_measurement_idac_integration.v` `i_test_identity_inject_sample_index` | `ppg_adc_measurement_idac_integration.v` `i_test_calibration_loss_inject_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:2625 | `:394,2601` | `ppg_adc_measurement_idac_integration.v` `i_test_invalid_sample_valid`、`o_return_pending` | `ppg_adc_measurement_idac_integration.v` `o_test_calibration_loss_inject_ready` | (b) 纠正：本行端口（W9b） |
| 矩阵:2641 | `:316` | `ppg_adc_measurement_idac_integration.v` `o_switch_hold_new_transaction` | `ppg_adc_measurement_idac_integration.v` `i_dout_stage1_low` | (b) 纠正：本行端口（W9b） |
| 矩阵:2642 | `:317` | `ppg_adc_measurement_idac_integration.v` `o_mode_fault_event` | `ppg_adc_measurement_idac_integration.v` `i_clk_stage1_dout_low_async` | (b) 纠正：本行端口（W9b） |
| 矩阵:2643 | `:318` | `ppg_adc_measurement_idac_integration.v` `o_normal_frame_count` | `ppg_adc_measurement_idac_integration.v` `i_dout_stage2_low` | (b) 纠正：本行端口（W9b） |
| 矩阵:2689 | `:1847` | `ppg_adc_measurement_idac_integration.v` `C_FRAME_ID_WIDTH` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_0` | (b) 纠正：本行端口（W9b） |
| 矩阵:2690 | `:1848` | `ppg_adc_measurement_idac_integration.v` `C_SAMPLE_INDEX_WIDTH` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_1` | (b) 纠正：本行端口（W9b） |
| 矩阵:2691 | `:1849` | `ppg_adc_measurement_idac_integration.v` `C_IDAC_CODE_WIDTH` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_2` | (b) 纠正：本行端口（W9b） |
| 矩阵:2692 | `:1850` | `ppg_adc_measurement_idac_integration.v` `C_CODE_EPOCH_WIDTH` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_3` | (b) 纠正：本行端口（W9b） |
| 矩阵:2693 | `:1851` | `ppg_adc_measurement_idac_integration.v` `C_CONFIG_EPOCH_WIDTH` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_4` | (b) 纠正：本行端口（W9b） |
| 矩阵:2694 | `:1852` | `ppg_adc_measurement_idac_integration.v` `C_COEF_EPOCH_WIDTH` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_5` | (b) 纠正：本行端口（W9b） |
| 矩阵:2697 | `:1855` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_s1_programmable_calibrator_Inst` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_8` | (b) 纠正：本行端口（W9b） |
| 矩阵:2698 | `:1856` | `ppg_adc_measurement_idac_integration.v` `i_clk` | `ppg_adc_measurement_idac_integration.v` `i_stage1_weight_q16_9` | (b) 纠正：本行端口（W9b） |
| 矩阵:2736 | ppg_adc_measurement_idac_integration.v:1938-1956 | `ppg_adc_measurement_idac_integration.v` `i_sample_index`、`i_color_ir`、`i_frame_type`、`i_amb_code_snapshot` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_result_router_Inst` | (a) 人工：纠正 |
| 矩阵:2767 | ppg_adc_measurement_idac_integration.v:1938 | `ppg_adc_measurement_idac_integration.v` `i_sample_index` | `ppg_adc_measurement_idac_integration.v` `o_calibrated_s1_value` | (a) 纠正：同文件 |
| 矩阵:2872 | ppg_normal_transaction_fork.v:101 | `ppg_normal_transaction_fork.v` `o_measurement_valid` | `ppg_normal_transaction_fork.v` `i_normal_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:2927 | `:2138` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_programmable_reconstructor` | `ppg_adc_measurement_idac_integration.v` `i_stage2_offset_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:2990 | `:2214` | `ppg_adc_measurement_idac_integration.v` `ppg_adc_dc_recovery` | `ppg_adc_measurement_idac_integration.v` `i_dc15_recovery_valid` | (b) 纠正：本行端口（W9b） |
| 矩阵:2991 | `:2215` | `ppg_adc_measurement_idac_integration.v` `C_FRAME_ID_WIDTH` | `ppg_adc_measurement_idac_integration.v` `i_dc9_recovery_gain_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:2992 | `:2216` | `ppg_adc_measurement_idac_integration.v` `C_SAMPLE_INDEX_WIDTH` | `ppg_adc_measurement_idac_integration.v` `i_dc15_recovery_gain_q16` | (b) 纠正：本行端口（W9b） |
| 矩阵:3552 | ppg_control_top.v:120 | `ppg_control_top.v` `i_clk_stage1_dout_low_async` | `ppg_control_top.v` `i_analog_ready` | (a) 人工：纠正 |
| 矩阵:3585 | ppg_control_top.v:120 | `ppg_control_top.v` `i_clk_stage1_dout_low_async` | `ppg_control_top.v` `i_analog_ready` | (a) 人工：纠正 |

## (b) 低置信：保留原解析，不猜（56条）

这些锚点多为整段散文对代码块的引用（例如“`supervisor.v:201-230,296-405`”），格内没有写明符号，被引行附近也没有本行所述符号。已保留原解析并列在下面。

| 位置（基线行） | 旧锚点 | 保留的解析 |
|---|---|---|
| 矩阵:837 | ppg_dual_precision_top.v:336-343 | `ppg_dual_precision_top.v` `C_CONFIG_WIDTH`、`i_source_clk`、`i_source_rstn`、`i_source_config` |
| 矩阵:895 | ppg_chip_digital_top.v:284,373 | `ppg_chip_digital_top.v` `w_source_rstn`、`ppg_reset_sync_clk2m_Inst` |
| 矩阵:924 | ppg_adc_measurement_idac_integration.v:967 | `ppg_adc_measurement_idac_integration.v` `flag_ami_fault_dispatch_03` |
| 矩阵:924 | `:522` | `ppg_precision_window_integration.v` `detection_datapath_empty_o` |
| 矩阵:926 | ppg_system_fault_abort_supervisor.v:201-230,296-405 | `ppg_system_fault_abort_supervisor.v` `flag_capture_watchdog`、`flag_capture_ami`、`flag_capture_scheduler`、`flag_capture_ssw` |
| 矩阵:931 | ppg_system_fault_abort_supervisor.v:170,174-183,184,185,419-428 | `ppg_system_fault_abort_supervisor.v` `system_fault_blocking_o`、`system_fault_cause_valid_o`、`system_fault_cause_o`、`system_fault_source_o` |
| 矩阵:932 | ppg_system_fault_abort_supervisor.v:129-133,217-230 | `ppg_system_fault_abort_supervisor.v` `SOURCE_AMI`、`SOURCE_SCHEDULER`、`SOURCE_SSW`、`SOURCE_SUPERVISOR` |
| 矩阵:934 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` |
| 矩阵:936 | ppg_adc_measurement_idac_integration.v:1223,1620,913 | `ppg_adc_measurement_idac_integration.v` `flag_adc_completion_abort_release` |
| 矩阵:937 | ppg_control_top.v:1378-1439 | `ppg_control_top.v` `ppg_system_fault_abort_supervisor_Inst` |
| 矩阵:942 | ppg_system_fault_abort_supervisor.v:201-205,184 | `ppg_system_fault_abort_supervisor.v` `flag_capture_watchdog`、`flag_capture_ami`、`flag_capture_scheduler`、`flag_capture_ssw` |
| 矩阵:945 | ppg_system_fault_abort_supervisor.v:198 | `ppg_system_fault_abort_supervisor.v` `flag_episode_open_edge` |
| 矩阵:1394 | ppg_system_config_manager.v:370-376 | `ppg_system_config_manager.v` `flag_snapshot_static_bias_valid`、`flag_start_static_bias_valid`、`@satisfies: ILM-08, ILM-15` |
| 矩阵:1596 | `:247` | `ppg_sar9_sar15_safe_selection_wrapper.v` `CTRL_EN_TEST` |
| 矩阵:2468 | ppg_dynamic_baseline_cross_detector.v:550 | `ppg_dynamic_baseline_cross_detector.v` `o_cross_valid` |
| 矩阵:2469 | ppg_peak_valley_window_detector.v:446 | `ppg_peak_valley_window_detector.v` `o_peak_valid` |
| 矩阵:2470 | ppg_peak_valley_window_detector.v:455 | `ppg_peak_valley_window_detector.v` `o_valley_valid` |
| 矩阵:2471 | ppg_peak_valley_window_detector.v:441 | `ppg_peak_valley_window_detector.v` `o_return_9bit_valid` |
| 矩阵:2736 | `:1985` | `ppg_adc_measurement_idac_integration.v` `ppg_normal_transaction_fork_Inst` |
| 矩阵:3125 | ppg_adc_async_stage_capture.v:59 | `ppg_adc_async_stage_capture.v` `i_adc_transaction_start` |
| 矩阵:3125 | ppg_adc_s1_redundancy_corrector.v:62 | `ppg_adc_s1_redundancy_corrector.v` `i_adc_transaction_start` |
| 矩阵:3223 | ppg_control_top.v:338,344-350 | `ppg_control_top.v` `flag_status_clear_event`、`flag_owner_abort_event`、`flag_abort_drain_stop_request`、`flag_stop_request_event` |
| 矩阵:3226 | `:384` | `ppg_active_v4_control_plane_integration.v` `o_source_busy` |
| 矩阵:3226 | `:381-382` | `ppg_active_v4_control_plane_integration.v` `i_source_rstn`、`i_source_config` |
| 矩阵:3352 | ppg_control_top.v:288-292 | `ppg_control_top.v` `o_detection_discard_dc_code_epoch`、`o_detection_discard_run_generation`、`o_s1_calibration_applied` |
| 矩阵:3367 | ppg_control_top.v:851-854 | `ppg_control_top.v` `o_static_characterization_enable`、`o_test_mux_ctrl`、`o_control_valid`、`o_control_update_event` |
| 矩阵:3368 | ppg_control_top.v:970-974 | `ppg_control_top.v` `o_scheduler_fault_identity_valid`、`o_scheduler_fault_frame_id`、`o_scheduler_fault_sample_index`、`o_scheduler_fault_color_ir` |
| 矩阵:3369 | ppg_control_top.v:1085-1092 | `ppg_control_top.v` `o_ssw_fault_identity_valid`、`o_ssw_fault_frame_id`、`o_ssw_fault_sample_index`、`o_ssw_fault_color_ir` |
| 矩阵:3370 | ppg_control_top.v:1367-1371 | `ppg_control_top.v` `i_test_identity_inject_sample_index`、`i_test_invalid_sample_valid`、`o_test_invalid_sample_ready`、`i_test_saturation_inject_valid` |
| 矩阵:3374 | ppg_adc_measurement_idac_integration.v:1832-1837 | `ppg_adc_measurement_idac_integration.v` `flag_stop_result_draining` |
| 矩阵:3375 | ppg_adc_measurement_idac_integration.v:1898-1904 | `ppg_adc_measurement_idac_integration.v` `o_stage1_code_ext`、`o_stage2_raw`、`o_precision_mode`、`o_frame_id` |
| 矩阵:3376 | ppg_adc_measurement_idac_integration.v:1962-1968 | `ppg_adc_measurement_idac_integration.v` `o_stage2_raw`、`o_precision_mode`、`o_frame_id`、`o_sample_index` |
| 矩阵:3377 | ppg_adc_measurement_idac_integration.v:2050-2056 | `ppg_adc_measurement_idac_integration.v` `o_track_precision_mode`、`o_track_frame_id`、`o_track_sample_index`、`o_track_color_ir` |
| 矩阵:3378 | ppg_adc_measurement_idac_integration.v:2124-2129 | `ppg_adc_measurement_idac_integration.v` `o_precision_mode`、`o_frame_id`、`o_sample_index`、`o_color_ir` |
| 矩阵:3379 | ppg_adc_measurement_idac_integration.v:2200-2206 | `ppg_adc_measurement_idac_integration.v` `o_nominal_15_valid`、`o_nominal_saturated`、`o_precision_mode`、`o_frame_id` |
| 矩阵:3380 | ppg_adc_measurement_idac_integration.v:2295-2302 | `ppg_adc_measurement_idac_integration.v` `o_dc_code_snapshot`、`o_amb_code_epoch`、`o_dc_code_epoch`、`o_detect_code` |
| 矩阵:3382 | ppg_adc_measurement_idac_integration.v:2625-2628 | `ppg_adc_measurement_idac_integration.v` `i_precision_mode_committed`、`i_dout_stage1_low`、`i_clk_stage1_dout_low_async`、`i_dout_stage2_low` |
| 矩阵:3409 | ppg_adc_measurement_idac_integration.v:1168-1175 | `ppg_adc_measurement_idac_integration.v` `o_detection_discard_frame_id`、`o_detection_discard_sample_index`、`o_detection_discard_color_ir`、`o_detection_discard_frame_type` |
| 矩阵:3456 | wrapper.v:480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` |
| 矩阵:3585 | ppg_sar9_sar15_safe_selection_wrapper.v:25,48,480 | `ppg_sar9_sar15_safe_selection_wrapper.v` `o_analog_safe` |
| 别名表:28 | ppg_system_config_manager.v:556,519-520 | `ppg_system_config_manager.v` `active_valid_o`、`active_config_o` |
| 别名表:38 | ppg_control_top.v:945 | `ppg_control_top.v` `o_macro_frame_start_event` |
| 别名表:45 | ppg_system_config_manager.v:394-448 | `ppg_system_config_manager.v` `flag_snapshot_dc_qualification_valid` |
| 别名表:108 | ppg_adc_measurement_idac_integration.v:1605 | `ppg_adc_measurement_idac_integration.v` `flag_adc_transaction_inflight` |
| 别名表:112 | ppg_idac_code_controller.v:170-172,580 | `ppg_idac_code_controller.v` `o_dcs_ir_code_update`、`o_dcs_r_track_adjust`、`o_dcs_ir_track_adjust`、`flag_control_cancel` |
| 别名表:115 | ppg_adc_measurement_idac_integration.v:2446-2461 | `ppg_adc_measurement_idac_integration.v` `C_DATA_WIDTH`、`C_FRAME_ID_WIDTH`、`C_SAMPLE_INDEX_WIDTH`、`C_IDAC_CODE_WIDTH` |
| 别名表:159 | ppg_control_top.v:355 | `ppg_control_top.v` `flag_owner_abort_event` |
| 别名表:192 | ppg_idac_code_controller.v:285 | `ppg_idac_code_controller.v` `ST_AMB_RECHECK` |
| 别名表:241 | ppg_characterization_control_cdc.v:118 | `ppg_characterization_control_cdc.v` `o_test_mux_ctrl` |
| 别名表:302 | :119 | `ppg_peak_valley_window_detector.v` `i_window_saturation_low` |
| 别名表:302 | `:465` | `ppg_peak_valley_window_detector.v` `o_local_empty` |
| 别名表:458 | ppg_precision_window_integration.v:443 | `ppg_precision_window_integration.v` `flag_detection_discard_apply` |
| 别名表:464 | ppg_control_top.v:350-357,368-375 | `ppg_control_top.v` `supervisor_system_stop_request_event_o`、`flag_owner_abort_event`、`flag_stop_request_event` |
| 别名表:472 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` |
| 别名表:481 | ppg_adc_measurement_idac_integration.v:905,1009-1010,2356,2611 | `ppg_adc_measurement_idac_integration.v` `o_measurement_result_discard_run_generation`、`i_search_calibration_applied`、`o_peak_valley_protocol_error_sticky` |
| 别名表:568 | ppg_control_top.v:295-299 | `ppg_control_top.v` `C_ADC_DRAIN_WATCHDOG_CYCLES` |
