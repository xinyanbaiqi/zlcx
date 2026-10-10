# anchor_check语义模式负对照（2026-10-10）

1. 第三轮写入前文本（快照`ad905e8`的矩阵与别名表）上运行语义模式，报出symbol-mismatch 71处，其中包括统筹举例的矩阵1442行（锚点`o_system_fault_discard_event`，格内声明原文写`output [7:0] o_system_fault_cause`）。完整输出见`semantic_on_round2_text.txt`。
2. 在第三轮结果的副本中注入2处“换成同文件中真实存在的另一个端口”的错误：
   - 矩阵1442行：`o_system_fault_cause` 改为 `o_system_fault_discard_event`（W1，格内声明原文在锚点后）；
   - 矩阵1395行：`AMI.i_transaction_sample_index（` 后的Top锚点 `i_transaction_sample_index` 改为 `i_transaction_frame_id`（W2）。
   语义模式恰好报出这2处（退出1）；同一副本用`--no-semantic`运行为0报错（退出0）。这正是本次的错误形态，名字存在性检查查不出来。

```
ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:1395 symbol-mismatch ppg_control_top.v i_transaction_frame_id but the cell writes `i_transaction_sample_index` (W2)
ERROR PPG_CONTRACT_CLOSURE_MATRIX.md:1442 symbol-mismatch ppg_control_top.v o_system_fault_discard_event but the cell writes `o_system_fault_cause` (W1)
stats {"symbol_anchors": 6674, "satisfies_anchors": 188, "label_anchors": 184, "section_refs": 2767, "old_anchor_history": 17, "semantic_checked": 1822}; external refs 27; errors 2; file index git (1036 files)
```

--no-semantic:
```
stats {"symbol_anchors": 6674, "satisfies_anchors": 188, "label_anchors": 184, "section_refs": 2767, "old_anchor_history": 17, "semantic_checked": 0}; external refs 27; errors 0; file index git (1036 files)
```
