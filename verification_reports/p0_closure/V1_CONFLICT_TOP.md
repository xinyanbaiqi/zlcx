# V1 同拍冲突矩阵：control_top（`ppg_control_top.v`，对照C01）

- 任务：P0-V1 续，模块12/12；基线main `a1ba482`；只读；纯静态（没有仿真器）
- 合同：C01 = `contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`（191–193行的合并表、364–405行）
- 范围：Top自身的6个always块和生命周期胶合assign（413–419、734）；子模块各有独立文件

## 0. 胶合逻辑一览（行号为基线）

| 信号 | 行号 | 定义 | 去向 |
|---|---|---|---|
| `flag_diag_clear_event` | 328 | reg(`i_diag_clear_event`) | AMI、调度器、SSW、supervisor、CDC |
| `flag_status_clear_event` | 337 | reg(`i_diag_clear_event`)，与上一行同源、同延迟的另一个寄存器 | wrapper→manager `i_status_clear_event` |
| `flag_owner_abort_event` | 356 | reg(外部abort \|\| supervisor abort) | AMI、调度器、SSW |
| `flag_abort_drain_stop_request` | 365 | reg(外部abort) | 进入下一行 |
| `flag_stop_request_event` | 374 | reg(外部STOP \|\| supervisor STOP \|\| abort_drain) | wrapper→manager `i_stop_event` |
| `flag_test_inject_mode_latched` | 390 | abort或stop_ack清0 > `!run_enable`时装载 | AMI测试注入（生产构建`C_ENABLE_TEST_INJECTION=0`） |
| `i_start_event` | 747（端口直连） | **不寄存**，直接进wrapper/manager | manager |
| `measurement_run_enable`、`measurement_allow_new_transaction`、`flag_measurement_start_ack_event` | 414–417 | 与`!flag_static_characterization_enable`相与（三者门控一致） | 调度器、AMI |
| `analog_run_enable`、`flag_analog_start_ack_event` | 413、416 | 不受STATIC_BIAS门控 | SSW |
| `flag_idac_boundary_request` | 734 | 三个IDAC pending的“或” | 调度器L-3 |

由此得到的到达时序（设T为外部事件到达Top端口的那一拍）：
- START：manager在T接受，各模块在T+1看到start_ack；
- STOP：manager在T+1接受，各模块在T+2看到stop_ack；
- DIAG_CLEAR：manager与各模块都在T+1；
- 外部ABORT：owner在T+1，manager在T+2收到STOP形式，各模块在T+3看到stop_ack；
- supervisor：abort与STOP都在T+1；discard事件在T（直连AMI，见V1-AMI A4）。

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `flag_owner_abort_event`（356） | 两路abort相“或”后寄存 | 外部abort × supervisor abort同拍 | (b) | 合成一个脉冲；C01 192行“the sole owner-abort fanout”。discard原因由AMI按`sys_pending`区分（V1-AMI 1.3） | 否 |
| `flag_stop_request_event`（374） | 三路STOP相“或”后寄存 | 任两路同拍 | (b) | 合成一个STOP；C01 191行 | 否 |
| `flag_abort_drain_stop_request`（365） | 外部abort寄存 | — | (b) | 只取外部abort；supervisor STOP另有一路（C01 403–405） | 否 |
| START（直连）× STOP（寄存一拍） | 747 vs 374 | **同一拍到达Top的START与STOP** | **(c) V1-TOP-C1（低，即V1-MGR-C2的根因）** | C01 191行与395–398行：“STOP wins over same-cycle START/COMMIT/clear”。Top让STOP比START晚一拍到manager，同拍的START先被执行，再接STOP，manager的冲突检测失效。SPI同字节0x03可达，而且四路CDC之间可能相差±1拍，所以结果不确定。0x09（START+DIAG_CLEAR）同理 | 同V1-MGR-C2 |
| `flag_status_clear_event`（337）× `flag_diag_clear_event`（328） | 两个寄存器同源、同延迟，分发到不同对象 | **与STOP同拍的诊断清除** | **(c) V1-TOP-C2（低，即V1-MGR-C3的根因）** | C01 365–367行：“Manager status clear remains local”。manager在与STOP同拍时拒绝自己的清除（记0x01），而其它模块同拍照常清除。C01没有规定这种不一致是否可以接受 | 同V1-MGR-C3 |
| START（T+1到各模块）× 外部abort（T+1到各owner） | 416–417 vs 356 | **同一拍到达Top的START与ABORT（SPI 0x11）** | (c) 引用V1-SCH-C3 | 两者经不同的寄存级数，恰好在各模块同拍。调度器、AMI、IDAC上下文按START处理；SSW、IDAC状态机按abort处理。drain-STOP在T+3到达 | 同V1-SCH-C3 |
| `flag_test_inject_mode_latched`（390） | abort/stop_ack清0 > `!run_enable`装载 | — | (b) | 仅验证构建有效；C01 360–362行 | 否 |
| `measurement_*`与`analog_*`门控 | 413–417 | STATIC_BIAS下测量链与模拟链的START看到的不一致 | (b) | 设计意图（TOP-12/TOP-18）：STATIC_BIAS下SSW建立静态向量，测量链保持空闲。三个测量信号使用同一个门控，所以调度器与AMI内部的U1（START拍lifecycle=0）关系保持成立 | 否 |
| `flag_idac_boundary_request`（734） | 组合“或” | — | — | 纯组合，无冲突 | — |

## 2. 汇总与清单

- 本模块(c)：V1-TOP-C1（低）、V1-TOP-C2（低），分别是V1-MGR-C2、V1-MGR-C3的Top侧根因，**不重复计数**；V1-SCH-C3在Top侧的成因也记在这里。
- always块（6个，全部覆盖）：328 `flag_diag_clear_event`；337 `flag_status_clear_event`；356 `flag_owner_abort_event`；365 `flag_abort_drain_stop_request`；374 `flag_stop_request_event`；390 `flag_test_inject_mode_latched`。（`grep always`另有两处命中，在第31、66行的修订记录文字中。）
