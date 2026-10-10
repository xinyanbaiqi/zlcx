# 阶段4锚点旧→新对照表汇总

清单基线 `7a8eabf`，新节号核对版本 `85e8678`；锚点总数 9702。

| 类别 | 来源 | 数量 |
|---|---|---|
| convert | auto | 8288 |
| convert | manual | 966 |
| external | manual | 3 |
| history | manual | 1 |
| history-block | auto | 30 |
| history-strike | auto | 8 |
| history-superseded-struck | auto | 402 |
| not-anchor | manual | 4 |

统筹2026-10-09裁定的历史保留类别（判定规则见`tools/b_merge_tools/anchor_history_rules.py`，数量为0的类别也列出）：

| 裁定类别 | 本表分类 | 数量 | 判定方法 |
|---|---|---:|---|
| ①删除线内 | history-strike | 8 | 在~~删除线~~内，且同一格中删除线之后没有接续条目 |
| ②历史块：“> ”勘误/说明块 | history-block | 30 | 所在行以“> ”开头 |
| ②历史块：修订记录节 | history-revision | 0 | 所在节标题含修订记录/变更记录/change record/history等 |
| ③被后续条目取代的旧条目（带删除线） | history-superseded-struck | 402 | 在~~删除线~~内，且同一格中删除线之后接续了取代它的新条目（“~~旧~~ **新**”） |
| ③被后续条目取代的旧条目（无删除线） | history-superseded | 0 | 不在删除线内，但同一格后文明示前文作废/不成立/已被取代 |
| 其它历史（人工） | history | 1 | 人工判定，理由见note |
| 非锚点 | not-anchor | 4 | 形似行号但不是锚点 |
| 仓库外文档 | external | 3 | 指向未入库文档 |
| 转换 | convert | 9254 | 其余全部；同格后文有带日期勘误/补记但未明示作废前文的，默认转换并在note中标uncertain |

uncertain（默认转换的③类候选）：98

| 文件 | 类别 | 数量 |
|---|---|---|
| PPG_ALIAS_MAPPING_TABLE.md | convert | 869 |
| PPG_ALIAS_MAPPING_TABLE.md | external | 3 |
| PPG_ALIAS_MAPPING_TABLE.md | history | 1 |
| PPG_ALIAS_MAPPING_TABLE.md | history-block | 3 |
| PPG_ALIAS_MAPPING_TABLE.md | history-strike | 8 |
| PPG_ALIAS_MAPPING_TABLE.md | history-superseded-struck | 4 |
| PPG_ALIAS_MAPPING_TABLE.md | not-anchor | 3 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | convert | 8385 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | history-block | 27 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | history-superseded-struck | 398 |
| PPG_CONTRACT_CLOSURE_MATRIX.md | not-anchor | 1 |
