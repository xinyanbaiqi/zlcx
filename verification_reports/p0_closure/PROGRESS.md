# P0-V1 同拍冲突矩阵：进度

- 分支：`p0-closure`（自main `a1ba482`切出），只新增本目录下的文件
- 环境：云端会话，无仿真器（iverilog/xsim/verilator均不可用），全部为静态逐路追踪

| 模块 | 文件 | 状态 |
|---|---|---|
| 调度器（C08） | `V1_CONFLICT_SCH.md` | 已完成：(c) 8项（1中、6低、1无可观测），待定1项 |
| SSW（C09） | `V1_CONFLICT_SSW.md` | 已完成：(c) 3项（1高、2低），待定1项；START×abort并入V1-SCH-C3 |
| AMI（C10、C24） | `V1_CONFLICT_AMI.md`（单文件，73个always块） | 已完成：(c) 5项（1中、4低），待定0项；附注N1 |
| **第二批（续）** | | |
| manager（C02） | `V1_CONFLICT_MGR.md` | 已完成：(c) 3项（1中、2低） |
| supervisor（C24） | `V1_CONFLICT_SUP.md` | 已完成：本模块(c) 0项；V1-MGR-C1、V1-AMI-C3在此有体现 |
| IDAC控制器（C17） | `V1_CONFLICT_IDAC.md` | 已完成：(c) 2项（低） |
| 精度窗口控制器（C23） | `V1_CONFLICT_PWC.md` | 当前 |
| 重检调度器（C16） | `V1_CONFLICT_RCK.md` | 待做 |
| PWI（C18） | `V1_CONFLICT_PWI.md` | 待做 |
| SPI寄存器文件（芯片顶层合同） | `V1_CONFLICT_SPI.md` | 待做 |
| 冗余校正器（C10/OLR §2.2） | `V1_CONFLICT_RDC.md` | 待做 |
| control_top（C01） | `V1_CONFLICT_TOP.md` | 待做 |

## 跨模块遗留：已全部在AMI文件§3结案
- V1-SCH-C3（START×abort）：调度器与AMI按START处理，SSW按abort处理，三模块不一致，维持低级别。
- V1-SCH-C2（STOP拍CAL截止事件）：AMI与重检调度器都是STOP优先，没有额外后果。
- V1-SCH-P1（STOP/abort×成功完成）：静态结案为(b)。

## 状态
三个模块全部完成。(c)类合计16项：高1（V1-SSW-C1）、中2（V1-SCH-C1、V1-AMI-C1）、低12、无可观测1；待定：V1-SSW-P1（模拟后果）。
