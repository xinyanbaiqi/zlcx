# P0-V1 同拍冲突矩阵：进度

- 分支：`p0-closure`（自main `a1ba482`切出），只新增本目录下的文件
- 环境：云端会话，无仿真器（iverilog/xsim/verilator均不可用），全部为静态逐路追踪

| 模块 | 文件 | 状态 |
|---|---|---|
| 调度器（C08） | `V1_CONFLICT_SCH.md` | 已完成：(c) 8项（1中、6低、1无可观测），待定1项 |
| SSW（C09） | `V1_CONFLICT_SSW.md` | 已完成：(c) 3项（1高、2低），待定1项；START×abort并入V1-SCH-C3 |
| AMI（C10、C24） | `V1_CONFLICT_AMI*.md`（按段） | 当前 |

## 跨模块遗留（后续文件中复核）
- V1-SCH-C3：START与abort同拍（SPI 0x0090=0x11）。SSW已核对：abort优先（`stop_pending=1`），与调度器不一致；AMI待核对。
- V1-SCH-C2：调度器在STOP当拍可能发出`o_cal_owner_deadline_event`。需要核对AMI中withdraw与STOP同拍、F-020转送PWI的处理。
- V1-SCH-P1：STOP/abort与成功完成同拍。需要核对AMI正式结果或discard、SSW owner释放的一致性。
