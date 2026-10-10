# 第五轮对照：被明示取代的旧锚点（规则1f、历史类history-superseded）

每个负对照在当前文本（第五轮写入后）的独立副本上只改一处；NC1经门禁`run_anchor_gate.sh`。

| 编号 | 文件:行 | 改动 | 原文 | 改后 |
|---|---|---|---|---|
| NC1 | CONTRACT:1595 | 基线1577行恢复成第四轮的转换写法（统筹点名） | corrected from stale `:234` (unrelated | corrected from stale `ppg_system_config_manager.v` `flag_stop_accept` (unrelated |
| NC2 | ALIAS_MA:194 | 别名表基线192行“**不是**”旧锚点恢复成转换后的写法 | ——**不是**`ppg_idac_code_controller.v:285` | ——**不是**`ppg_idac_code_controller.v` `ST_AMB_RECHECK` |

## 结果

- 正对照（当前文本，统筹点名两行已恢复为`:234`、`:245`）：矩阵副本退出码0、报错0；别名表副本退出码0、报错0。恢复后的旧行号不报错，且对照表中归入历史类：
  - CONTRACT:1577 ``:234`` → history-superseded
  - CONTRACT:1585 ``:245`` → history-superseded
  - CONTRACT:1596 ``:247`` → history-superseded
  - ALIAS_MA:192 `ppg_idac_code_controller.v:285` → history-superseded
- NC1：退出码1（门禁）
  - `ANCHOR GATE: Python 3.12.4 D:/ppg_zlcx/zlcx/tools/b_merge_tools/anchor_check.py C:/Users/DAWN/AppData/Local/Temp/claude/D--ppg-zlcx-zlcx/ec50af72-800d-4fa7-8f6b-800e4fb65072/scratchpad\negctl5\nc1\PPG_CONTRACT_CLOSURE_MATRIX.md`
  - `ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:1595 superseded-converted ppg_system_config_manager.v flag_stop_accept: the cell marks this anchor as superseded ("stale"); keep the old text as history`
  - `ANCHOR GATE FAILED (anchor_check.py exit 1)`
- NC2：退出码1，报错2
  - `PPG_ALIAS_MAPPING_TABLE.md:194 superseded-converted ppg_idac_code_controller.v ST_AMB_RECHECK: the cell marks this anchor as superseded ("**不是**"); keep the old text as history`
  - `PPG_ALIAS_MAPPING_TABLE.md:194 symbol-unmentioned ppg_idac_code_controller.v ST_AMB_RECHECK: not stated by the row (unstated: ST_AMB_RECHECK)`

结论：符合预期：正对照0报错且四处同类旧锚点均归history-superseded；两种恢复成转换写法的负对照都报出superseded-converted，NC1门禁失败。
