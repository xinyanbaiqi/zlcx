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
| 精度窗口控制器（C23） | `V1_CONFLICT_PWC.md` | 已完成：(c) 3项（2低、1无可观测） |
| 重检调度器（C16） | `V1_CONFLICT_RCK.md` | 已完成：(c) 0项 |
| PWI（C18） | `V1_CONFLICT_PWI.md` | 已完成：(c) 0项 |
| SPI寄存器文件（芯片顶层合同） | `V1_CONFLICT_SPI.md` | 已完成：本模块(c) 0项；系统级见MGR-C2/C3、SCH-C3 |
| 冗余校正器（C10/OLR §2.2） | `V1_CONFLICT_RDC.md` | 已完成：(c) 0项 |
| control_top（C01） | `V1_CONFLICT_TOP.md` | 已完成：TOP-C1/C2为MGR-C2/C3的根因，不重复计数 |

## 跨模块遗留：已全部在AMI文件§3结案
- V1-SCH-C3（START×abort）：调度器与AMI按START处理，SSW按abort处理，三模块不一致，维持低级别。
- V1-SCH-C2（STOP拍CAL截止事件）：AMI与重检调度器都是STOP优先，没有额外后果。
- V1-SCH-P1（STOP/abort×成功完成）：静态结案为(b)。

## 状态
三个模块全部完成。(c)类合计16项：高1（V1-SSW-C1）、中2（V1-SCH-C1、V1-AMI-C1）、低12、无可观测1；待定：V1-SSW-P1（模拟后果）。

## 第二批状态（9个模块全部完成）
新增(c)类8项，按编号去重（TOP-C1/C2与MGR-C2/C3同根，不重复计数）：
- 中：V1-MGR-C1（`o_stop_episode_active`在“重复STOP × STOPPING完成”同拍后卡1，下一RUN中长时间ADC忙会误触发看门狗0x31）；
- 低：V1-MGR-C2、V1-MGR-C3、V1-IDAC-C1、V1-IDAC-C2、V1-PWC-C1、V1-PWC-C2；
- 无可观测：V1-PWC-C3。
supervisor、重检调度器、PWI、SPI、冗余校正器自身0项。
两批合计(c)类：高1、中3、低18、无可观测2（共24项）；待定：V1-SSW-P1。

---

# P0-V15 / V10（Python部分）：进度

- 任务书：`verification_reports/P0_CLOUD_BRIEF_V15_V10_20261010.md`；在`p0-closure`上继续，已合并origin/main `bb3c1ab`。
- 环境：云端会话，无仿真器；只新增本目录下文件。

| 任务 | 文件 | 状态 |
|---|---|---|
| V15 TB中ADC行为模型核对 | `V15_TB_ADC_MODEL_CHECK.md` | 已完成：需修改3项（高1 V15-N1、中1 V15-N2、低1 V15-N3）；保守差异5个模型、符合2个模型 |
| V10 Python静态扫描重跑 | `V10_STATIC_RERUN.md` | 未开始 |

## V15要点
- V15-N1（高）：芯片层物理idle=`!CLK_STAGEx_DOUT_LOW`。若DONE按模拟侧事实保持到下一次转换开始，RUN中会静默停采，STOP后无法完成STOPPING（报0x31），START被挡。所有TB用5拍短脉冲，从未触发。**需要模拟侧回答：哪个引脚的哪个边沿使DONE回落，相对owner截止（283/443/CAL 248）早还是晚，STOP后DONE是否会自行回落。**
