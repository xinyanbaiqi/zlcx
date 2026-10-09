# V1 同拍冲突矩阵：manager（`ppg_system_config_manager.v`，对照C02）

- 任务：流片前验证收尾 P0-V1 续，模块4/12
- 基线：main `a1ba482`；只读。方法同前三个文件（skill只读分析，纯静态，没有仿真器）
- 合同：C02 = `contracts/ppg_system_config_manager_semantic_contract.md`；Top胶合部分参照C01和`ppg_control_top.v`
- 本模块的重点：START、STOP、ABORT、COMMIT、诊断清除这几条命令同时出现时的处理。V1-SCH-C3已指出，一次写0x11会同时产生START与abort

## 0. 结构与记号

- 17个always块：16个时序块，1个组合块（706–733，`state_next`）。
- 状态机：`ST_CONFIG/READY/RUN/STOPPING`（3 bit，另有非法编码检测），按`case(state_current)`分支，**每个状态只响应一个事件**，所以状态转移本身没有同拍冲突。
- 关键组合量：

| 量 | 行号 | 定义 |
|---|---|---|
| `flag_command_conflict` | 309–315 | COMMIT、START、STOP、status clear四个事件中任意两个同拍 |
| `flag_commit_accept` | 457–459 | COMMIT、无冲突、CONFIG、快照合法 |
| `flag_start_accept` | 460–461 | START、无冲突、`flag_start_ready`（READY、`active_valid`、模拟ready、ADC空闲、datapath空、IDAC空闲、STATIC_BIAS合法、无系统阻断、无`error_sticky`） |
| `flag_stop_accept` | 462–464 | STOP且状态为RUN或STOPPING——**不受冲突门控**（MGR-11：STOP优先） |
| `flag_stopping_complete` | 465–466 | ADC空闲、datapath空、IDAC空闲、模拟安全 |
| `dec_error_code` | 470–494 | 固定优先级：非法状态 > 冲突 > 各COMMIT错误 > 各START错误 > STOP状态错误 |

### 0.1 命令到达manager的时序（上游逐路追踪）

所有命令都来自SPI命令字节0x0090，同一字节允许多位同时为1（`ppg_spi_register_file.v` 294–299）。START、STOP、DIAG_CLEAR、ABORT各经一个独立的`ppg_pulse_cdc_sync`例化（SPI 612–650，四个同构实例）进入2 MHz域；COMMIT留在source域，经配置CDC桥（`ppg_active_v4_control_plane_integration.v` 383/396）进入。设T为CDC输出到达`ppg_control_top`端口的那一拍：

| SPI位 | Top内部路径（`ppg_control_top.v`） | 到manager | 到调度器/SSW/AMI |
|---|---|---|---|
| bit0 START | `i_start_event`直连wrapper（747），manager组合接受，`start_ack`再寄存一拍 | T（接受）；ack在T+1 | start_ack：T+1 |
| bit1 STOP | `flag_stop_request_event`寄存一拍（378） | T+1；ack在T+2 | stop_ack：T+2 |
| bit3 DIAG_CLEAR | `flag_status_clear_event`寄存一拍（341）→manager；`flag_diag_clear_event`寄存一拍（332）→各模块 | T+1 | T+1 |
| bit4 ABORT | `flag_owner_abort_event`寄存一拍（360）→owner；`flag_abort_drain_stop_request`（369）再经`flag_stop_request_event`（378）两拍→manager | T+2（STOP形式）；ack在T+3 | abort：T+1；stop_ack：T+3 |
| bit2 COMMIT | source域事件→配置CDC桥（握手，多拍） | T+L（L为CDC桥时延，多拍，且桥忙时会丢弃） | — |

**硅片注意**：四个命令位各走一个独立的双触发器同步器。源时钟与2 MHz异步时，同一SPI写里的两位在目标域可能因亚稳态分辨不同而**相差±1拍**。所以下表中“同拍”与“相差一拍”两种情形都必须视为可达。

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

### 1.1 状态与生命周期输出

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `state_current/state_next`（697、706） | 按状态分支：CONFIG只看commit，READY只看start，RUN只看stop，STOPPING只看complete，非法编码回CONFIG | 不同事件同拍 | (a) | `case`保证每个状态只有一个转移条件；其余事件只影响错误记录 | 否 |
| 〃 | 〃 | START × STOP（manager同拍） | (b) | START被冲突否决（461），STOP在RUN/STOPPING时被接受（不看冲突），并记0x01；C02 §2、§3.1、MGR-11 | 否 |
| 〃 | 〃 | STOP在CONFIG/READY | (b) | 不接受，记0x0C（`ERROR_STOP_STATE`）；brief §3.6 F-2已知：supervisor或abort派生的STOP落在CONFIG时会使manager记0x0C，需诊断清除后才能START | 否 |
| `stop_episode_active_o`（542） | `flag_stop_accept`置1 > `STOPPING && complete`清0 | **重复STOP × STOPPING完成（同拍）** | **(c) V1-MGR-C1（中）** | 置1在前胜出：状态已转回CONFIG，`stop_episode_active_o`却保持1。清0条件要求`state_current==ST_STOPPING`，而CONFIG、READY、RUN中都没有清0路径（只有复位），所以这个电平会一直卡住，直到下一次RUN的STOP走完STOPPING。详见§2 | 是：manager单元TB在STOPPING完成拍再发一次STOP；系统TB在排空末尾（ADC回空闲那一拍）注入第二次STOP（主机或abort派生） |
| `active_valid_o`（556） | 非法状态清0 > commit置1 > STOPPING完成清0 | commit × 完成 | (a) | commit只在CONFIG，完成只在STOPPING | 否 |
| `run_generation_o`（531） | `flag_start_accept`时+1 | — | — | 单写者；C02 §3.1 | — |
| `active_config_o`及四个epoch（520、572、584、595、606） | commit装载/+1 | — | — | 单写者 | — |
| `commit/start/stop_ack_event_o`（618、627、636） | 对应accept打一拍 | stop_ack × 状态已回CONFIG | (b)，附注 | 与C1同一条件对：完成拍的重复STOP会在CONFIG第一拍发出`stop_ack`。下游调度器、SSW、AMI在CONFIG中收到stop_ack都只是把已为排空态的标志再置一次（调度器P1、SSW `stop_pending`、AMI `stop_result_draining`），无功能后果。C02 §3“STOPPING重复STOP→幂等ACK” | 断言：`stop_ack → 上一拍state为RUN或STOPPING` |

### 1.2 错误与sticky

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `error_sticky_o`（668）、`last_error_code_o`（682）、`error_event_o`（645） | 新错误置位 > （无冲突时）status clear清0 | 新错误 × status clear | (b) | 若二者在manager同拍，status clear与任何命令同拍都属冲突，清除被否决，错误胜出；与C24 §4“新故障胜过同拍清除”一致 | 否 |
| 〃 | `dec_error_code`固定优先级 | 两种错误同拍 | (b) | 只记录最高优先级的一个；C02“固定顺序保证软件得到确定的首个失败原因”（RTL 494注释） | 否 |
| `commit_ack_sticky_o`（654） | commit置1 > （无冲突时）clear清0 | commit × clear | (a) | 同拍即冲突，commit不被接受 | 否 |

### 1.3 SPI同字节多命令（系统级，按§0.1的到达时序）

| SPI写 | manager看到的序列 | 处置 | 结果与依据 | 建议扫描 |
|---|---|---|---|---|
| **0x03 START+STOP** | 名义上START在T、STOP在T+1，**不同拍**；CDC偏斜−1时同拍 | **(c) V1-MGR-C2（低）** | 名义时序：READY下START被接受→RUN，下一拍STOP被接受→STOPPING，形成只有1拍的RUN，`run_generation`被消耗，不记冲突诊断。偏斜时同拍：STOP优先、START被否决、记0x01（READY下STOP本身非法，再记0x0C）。C02 §2/§3.1的意图是“STOP优先于同拍START，START不执行并记冲突”，系统级的名义时序却让START先执行。结果取决于CDC亚稳态分辨 | 是：chip TB写0x03，分别在READY与RUN下观察 |
| **0x09 START+DIAG_CLEAR** | START在T，status clear在T+1 | **(c) 并入V1-MGR-C2** | 若已有`error_sticky=1`：T拍START因`!error_sticky`不满足被拒（记0x0B），T+1的clear又把这条拒绝记录清掉，主机看到“START没生效、也没有错误”。若无错误：正常START。C02 MGR-11的意图是同拍时拒绝并记0x01 | 同上 |
| **0x0A STOP+DIAG_CLEAR** | 二者都在T+1，同拍 | **(c) V1-MGR-C3（低）** | manager：STOP被接受，clear被否决，记0x01，`error_sticky=1`，下一次START需要再单独清一次。但Top的`flag_diag_clear_event`（332）与manager的`flag_status_clear_event`（341）是两个独立寄存器，**各模块的诊断清除在T+1照常执行**（supervisor的`flag_diag_clear_legal`、AMI、调度器、SSW的sticky各按自己的条件清）。同一次写，manager判为冲突拒绝，其它模块却已清除，状态不一致 | 是：chip TB写0x0A，比较manager last_error与supervisor first-fault快照 |
| **0x11 START+ABORT** | START在T（被接受），STOP（abort派生）在T+2 | (b)（manager层），系统级见V1-SCH-C3 | manager没有abort端口（C02 §3.1：abort不是manager端口）。START被接受，T+1进入RUN，T+2 STOP被接受，RUN持续2拍。下游三模块对同拍start_ack与abort的处理不一致（调度器/AMI按START，SSW按abort），见V1-SCH-C3/V1-SSW §1.2/V1-AMI §3 | 已在C3建议 |
| 0x12 STOP+ABORT | STOP在T+1（接受），abort派生的STOP在T+2（STOPPING中重复，幂等） | (b) | C02 §3：重复STOP幂等ACK；下游abort（T+1）先于stop_ack（T+2） | 否 |
| 0x18 DIAG_CLEAR+ABORT | clear在T+1，abort派生的STOP在T+2 | (b) | manager不冲突；若处于CONFIG/READY，派生STOP记0x0C并重新置`error_sticky`，刚做的clear实际无效。这属于F-2的同类已知行为（brief §3.6） | 否 |
| COMMIT与其它任一位 | COMMIT经CDC桥，晚多拍 | (b) | 不会与START/STOP/clear同拍；CONFIG下START先到，记0x0A（`ERROR_START_STATE`），属合同规定的状态错误 | 否 |
| 外部abort单独发生在CONFIG/READY | 派生STOP在CONFIG/READY | (b)，附注 | 记0x0C，`error_sticky=1`，之后START被拒，直到诊断清除。brief §3.6 F-2只写了supervisor发出的STOP；外部abort同理，建议B批次在恢复流程里一并写明 | 否 |

## 2. 发现详述

### V1-MGR-C1（中）重复STOP与STOPPING完成同拍：`o_stop_episode_active`卡在1

- **RTL证据**：
  - `stop_episode_active_o`（542–553）：`if(flag_stop_accept) <=1; else if(state_current==ST_STOPPING && flag_stopping_complete) <=0;`
  - `flag_stop_accept`在STOPPING下成立（462–464）；状态机同拍走STOPPING→CONFIG（724–727）。
- **逐拍**：第t拍，状态为STOPPING，`flag_stopping_complete=1`，同拍又来一次STOP。
  - 第t+1拍：状态CONFIG，`stop_episode_active_o=1`，`stop_ack_event_o=1`。
  - 此后CONFIG、READY、RUN中都不满足清0条件，电平一直保持1，直到下一次RUN的STOP进入STOPPING并完成。
- **可达性**：STOPPING中的重复STOP有三个来源：
  - 主机再次写STOP；
  - abort派生的drain-STOP（control_top 369/378）；
  - supervisor在排空期间开启episode时发出的`o_system_stop_request_event`（例如brief §3.6 F-2：第k次作废落在排空末尾）。
  只要其中之一恰好落在`flag_stopping_complete`首次成立的那一拍即可。这个时刻由ADC空闲、datapath排空的时刻决定，扫描可以命中。
- **后果**：
  - C02 §2.1写“reset low after drain/reset”，与RTL不符。
  - `o_stop_episode_active`是manager唯一提供给supervisor的“物理排空episode存在”证明（C02 §3.1）。卡住之后，supervisor的看门狗窗口`flag_watchdog_window_active = i_stop_episode_active && !i_adc_physical_idle && !latch`（supervisor 193）在**下一次RUN**中也会打开。正常转换的忙时远短于5000拍，计数会被每次空闲清零，所以不触发；但在RUN中ADC长时间忙的情形（OLR SYS-CAL-BUSY-NORMAL类、lane 07前段），看门狗会在连续5000拍非空闲时报0x31。这与C24 §6“Normal RUN ADC busy never starts it”相反，并且会抢在AMI lane 07（9000拍）之前成为首故障。
- **建议**：
  - manager单元TB：STOPPING完成拍同拍注入STOP，检查下一拍`o_stop_episode_active`；
  - 系统TB：在排空末尾注入abort（派生STOP）扫描±2拍，下一RUN中保持ADC忙≥5000拍，检查是否出现0x31；
  - 断言：`state_current==ST_CONFIG || state_current==ST_READY → !o_stop_episode_active`。

### V1-MGR-C2（低）同一SPI写里的START与STOP/DIAG_CLEAR不在manager同拍，冲突诊断被绕过

- 见1.3节0x03、0x09两行。根因在Top胶合：START直连，STOP与status clear各多寄存一拍。所以manager的`flag_command_conflict`只能在两路CDC偏斜时偶然检测到。
- 结果不确定：主机同一操作，可能得到“1拍RUN”，也可能得到“冲突+0x01”。0x09在已有错误时会出现“START被拒且错误记录被同次清除”。
- 建议：合同（C02 §2或C01）写明同字节多命令的语义，或在SPI侧把多位同写定义为非法；chip TB覆盖0x03/0x09。

### V1-MGR-C3（低）0x0A STOP+DIAG_CLEAR：manager拒绝清除，其它模块已清除

- 见1.3节。manager判冲突（0x01）、保留`error_sticky`；同一事件经`flag_diag_clear_event`已到达supervisor、AMI、调度器、SSW，各自按自己的合法条件清除。C02 §3.1的“STOP wins over simultaneous … status-clear”只约束了manager本身。
- 建议：合同写明“与STOP同拍的诊断清除在全系统一律无效”，或接受现状并写明不一致。

## 3. 汇总

| 编号 | 级别 | 一句话 |
|---|---|---|
| V1-MGR-C1 | 中 | 重复STOP与STOPPING完成同拍，`o_stop_episode_active`在CONFIG中卡1到下一次排空，下一RUN中长时间ADC忙会误触发supervisor看门狗0x31 |
| V1-MGR-C2 | 低 | SPI同字节START+STOP/DIAG_CLEAR到达manager相差一拍，冲突诊断被绕过，结果依赖CDC偏斜 |
| V1-MGR-C3 | 低 | 0x0A STOP+DIAG_CLEAR：manager拒绝清除并记0x01，其它模块已经清除 |

待定：无。

合同差异：
- C02 §2.1 `o_stop_episode_active`“reset low after drain/reset”（C1）；
- brief §3.6 F-2只写了supervisor STOP落在CONFIG的情形，外部abort同理。

## 4. 已覆盖的always块与寄存器清单（17个，全部覆盖）

| always起始行 | 目标 | 覆盖位置 |
|---|---|---|
| 520 | `active_config_o` | 1.1 |
| 531 | `run_generation_o` | 1.1 |
| 542 | `stop_episode_active_o` | 1.1、C1 |
| 556 | `active_valid_o` | 1.1 |
| 572、584、595、606 | `stage2_coef_epoch_o`、`dc_recovery_coef_epoch_o`、`config_epoch_o`、`coef_epoch_o` | 1.1 |
| 618、627、636 | `commit_ack_event_o`、`start_ack_event_o`、`stop_ack_event_o` | 1.1 |
| 645、654、668、682 | `error_event_o`、`commit_ack_sticky_o`、`error_sticky_o`、`last_error_code_o` | 1.2 |
| 697 | `state_current` | 1.1 |
| 706（组合） | `state_next` | 1.1 |
