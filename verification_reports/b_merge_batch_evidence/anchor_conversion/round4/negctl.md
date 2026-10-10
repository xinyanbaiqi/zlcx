# 第四轮负对照：规则1d（符号须由本行述及）、1e（参数绑定须落在target模块的例化里）、钉住版本形式

每个对照在当前文本（第四轮写入后）的一个独立副本上只改一处；检查程序`tools/b_merge_tools/anchor_check.py`，NC1经门禁`tools/b_merge_tools/run_anchor_gate.sh`。

| 编号 | 行 | 改动 | 原文 | 改后 |
|---|---:|---|---|---|
| NC1 | 3385 | 参数绑定行（基线3367，C01→C08）整行恢复为66bebdf现文 | binding / binding `ppg_control_top.v` `ppg_400hz_frame_calibration_scheduler_Inst`、`C_FRAME_ID_WIDTH`、`C_SAMPL | binding / binding `ppg_control_top.v` `o_static_characterization_enable`、`o_test_mux_ctrl`、`o_control_valid`、` |
| NC2 | 3427 | 锚点换成同文件中存在、本行未提到的符号 | `ppg_adc_measurement_idac_integration.v` `integration_protocol_error_sticky_o`. Cluster | `ppg_adc_measurement_idac_integration.v` `flag_owner_lost_fire`. Cluster |
| NC3 | 3427 | 删掉本行唯一写明该名的文字，只留锚点 | AMI's own `integration_protocol_error_sticky_o` gives | AMI's own sticky gives |
| NC4 | 114 | （别名表）钉住版本形式指向不存在的文件 | `ppg_idac_code_controller.v:170-172,580`（ | `ppg_no_such_controller.v:170-172,580`（ |

## 结果

- 未改副本（矩阵）：退出码0，报错0；未改副本（别名表）：退出码0，报错0，钉住版本形式1处识别为合法
- NC1：退出码1（门禁）
  - `ANCHOR GATE: Python 3.12.4 D:/ppg_zlcx/zlcx/tools/b_merge_tools/anchor_check.py C:/Users/DAWN/AppData/Local/Temp/claude/D--ppg-zlcx-zlcx/ec50af72-800d-4fa7-8f6b-800e4fb65072/scratchpad\negctl4\nc1\PPG_CONTRACT_CLOSURE_MATRIX.md`
  - `ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:3385 binding-instance ppg_control_top.v o_static_characterization_enable/o_test_mux_ctrl/o_control_valid/o_control_update_event: not an instance of ppg_400hz_frame_calibration_scheduler (instances: ppg_400hz_frame_calibration_scheduler_Inst)`
  - `ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:3385 symbol-unmentioned ppg_control_top.v o_static_characterization_enable/o_test_mux_ctrl/o_control_valid/o_control_update_event: not stated by the row (unstated: o_static_characterization_enable/o_test_mux_ctrl/o_control_valid/o_control_update_event)`
  - `ANCHOR GATE FAILED (anchor_check.py exit 1)`
- NC2：退出码1，报错1
  - `PPG_CONTRACT_CLOSURE_MATRIX.md:3427 symbol-unmentioned ppg_adc_measurement_idac_integration.v flag_owner_lost_fire: not stated by the row (unstated: flag_owner_lost_fire)`
  - 同副本`--no-semantic`：退出码0，报错0
- NC3：退出码1，报错3
  - `PPG_CONTRACT_CLOSURE_MATRIX.md:3427 symbol-unmentioned ppg_adc_measurement_idac_integration.v integration_protocol_error_sticky_o: not stated by the row (unstated: integration_protocol_error_sticky_o)`
  - `PPG_CONTRACT_CLOSURE_MATRIX.md:3427 symbol-unmentioned ppg_adc_measurement_idac_integration.v integration_protocol_error_sticky_o/i_start_ack_event: not stated by the row (unstated: integration_protocol_error_sticky_o)`
  - `PPG_CONTRACT_CLOSURE_MATRIX.md:3427 symbol-unmentioned ppg_adc_measurement_idac_integration.v integration_protocol_error_sticky_o: not stated by the row (unstated: integration_protocol_error_sticky_o)`
  - 同副本`--no-semantic`：退出码0，报错0
- NC4：退出码1，报错1
  - `PPG_ALIAS_MAPPING_TABLE.md:114 file-missing ppg_no_such_controller.v`
  - 同副本`--no-semantic`：退出码1，报错1；`PPG_ALIAS_MAPPING_TABLE.md:114 file-missing ppg_no_such_controller.v`

结论：符合预期。NC1门禁失败（1e binding-instance与1d报错）；NC2恰好报出1处symbol-unmentioned；NC3报出的全部是依赖被删写明名的那些锚点（3处，`--no-semantic`为0）；NC4报file-missing；未改副本0报错。
