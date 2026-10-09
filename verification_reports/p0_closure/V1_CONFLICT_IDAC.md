# V1 同拍冲突矩阵：IDAC码控制器（`ppg_idac_code_controller.v`，对照C17）

- 任务：P0-V1 续，模块6/12；基线main `a1ba482`；只读；纯静态（没有仿真器）
- 合同：C17 = `contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md`

## 0. 结构与记号

4个always块：
- 688：时序，`state_current`；
- 697–836：组合，`state_next`；
- 840–1256：组合，`reg_context_next`；
- 1260：时序，`reg_context`。

全部数据状态在一个向量`reg_context`里（码、epoch、pending、边界、确认计数、各种sticky与故障身份）。

**`state_next`优先级**（697–835）：STOP/abort→IDLE > START（按配置选MANUAL_APPLY/AMB_APPLY/DCS_R_APPLY/FAULT）> `!run_enable`→IDLE > 按状态`case`。

**`reg_context_next`写入段**（后写者胜；行号为基线）：

| 代号 | 行号 | 条件 | 主要写入 |
|---|---|---|---|
| K0 | 841–851 | 默认 | 各单拍脉冲清0 |
| K1 | 853–855 | `i_diag_clear_event`（无其它条件） | `PROTOCOL_ERROR=0` |
| K2 | 857–903 | AMB、DCS_R、DCS_IR各自的commit（pending、边界、run、`!stop`、`!abort`、代际匹配） | 清pending；码变化时写码、epoch+1、update；AMB重检来源且码变化时清DCS pending与计数 |
| K3 | 905–907 | MANUAL_APPLY且遇边界 | `STARTUP_COMPLETE=1` |
| K4/K5/K6 | 909–992 | AMB_WAIT/DCS_R_WAIT/DCS_IR_WAIT收到合格样本 | 完成/下一候选pending/耗尽+FAULT |
| K7 | 994–1015 | AMB_RECHECK收到合格样本 | 确认计数，或触发重搜（pending、RECHECK_ORIGIN） |
| K8 | 1017–1023 | REVALIDATE_WAIT收到accept | 清计数，置REVALIDATE_ORIGIN |
| K9/K10 | 1025–1067 | REVALIDATE_R/IR收到合格样本 | 计数或重搜pending |
| K11 | 1069–1113 | NORMAL跟踪样本合格 | 计数，或±1 LSB跟踪pending |
| K12 | 1115–1119 | `flag_amb_check_start_allowed` | 清AMB计数与CHANGED |
| K13 | 1121–1123 | `flag_protocol_event` | `PROTOCOL_ERROR=1` |
| K14 | 1125–1164 | `flag_control_cancel` = STOP或abort或`!run_enable` | 清全部pending、计数、来源位、`STARTUP_COMPLETE`、三个FAULT；STOP或`!run_enable`时另清done/exhausted |
| K15 | 1166–1228 | `i_start_ack_event` | 清全部临时状态与`PROTOCOL_ERROR`、`STARTUP_COMPLETE`；按配置装载启动pending或置FAULT |
| K16 | 1231–1239 | pending由0变1 | 锁存pending代际 |
| K17 | 1242–1255 | 三个FAULT的“或”出现上升沿 | `FAULT_EVENT=1`；START拍身份无效，否则用`i_search_*`的身份 |

**上游门控**（AMI例化，AMI 2547–2596）：
- `i_run_enable` = AMI `i_run_enable`；
- `i_start_ack_event` = `flag_idac_start_event_qualified`；
- `i_frame_safe_boundary` = `i_idac_code_safe_boundary`；
- 三路样本valid都与`!flag_result_abort_discard`相与（该量含实时abort）。

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `state_next` × `reg_context_next` | 状态机中abort优先于START（699），上下文中START（K15）后写于cancel（K14），START胜 | **START × abort**（SPI 0x11可达，V1-SCH-C3） | **(c) V1-IDAC-C1（低）** | 同一个模块内两个组合块的优先级相反：状态回IDLE，上下文却已装入START的启动pending。T+2拍调度器发出启动IDAC边界（调度器在这一对上是START胜出），`flag_amb_commit`等commit条件不看状态，代际也匹配，于是在IDLE状态下提交一次启动码（码变、epoch+1、update脉冲）。T+3 drain-STOP的cancel再清掉其余部分。随后的START会重新初始化，没有残留 | 是：IDAC单元TB同拍驱动start与abort，再给一拍边界；系统TB写0x11并观察IDAC码与epoch |
| commit（K2）× STOP/abort/`!run_enable` | commit显式含`run_enable && !stop && !abort`（584–595） | — | (a) | C17 §8.2.4（生命周期门控） | 否 |
| commit × START | START拍pending=0：上一RUN的pending在CONFIG期间每拍都被K14清掉（`!run_enable`） | — | (a) | U1 | 否 |
| 搜索/跟踪样本（K4–K11）× abort | 样本valid在AMI侧与`!flag_result_abort_discard`相与，后者含实时abort | — | (a) | AMI 2574/2576/2596、999 | 否 |
| 样本 × STOP | 合格条件含`i_run_enable`（470、477、488），STOP拍`run_enable=0`（U2） | — | (a) | | 否 |
| 跟踪样本（K11）× 同色commit | 跟踪合格要求`flag_track_selected_pending==0`（498），commit要求pending=1 | — | (a) | | 否 |
| AMB重检commit且码变化，清DCS pending（863–871）× 同拍DCS commit（875/890） | DCS commit段在后，若同拍成立会照常提交DCS码 | — | (a) | 重检开始要求三个pending都为0（`flag_amb_check_start_allowed`，456–462）；重检期间状态不是NORMAL，跟踪不合格（491）；所以重检期间不存在DCS pending | 断言：`AMB_RECHECK_ORIGIN → !dcs_r/ir_pending_valid` |
| 重检启动（K12、状态NORMAL→AMB_RECHECK）× 同拍跟踪样本（K11置DCS pending） | 若同拍，会带着刚置位的DCS pending进入重检 | — | (a) | 启动脉冲来自重检调度器`flag_enter_amb`，它要求`flag_takeover_safe`，其中含`i_idac_idle`（`ppg_amb_recheck_scheduler.v` 182/189）；`o_idac_idle`含`flag_track_transfer==0`与三个pending为0（673–684） | 否 |
| `PROTOCOL_ERROR` | K1诊断清除 < K13置位 < K15 START清0 | 诊断清除 × 新协议事件 | (b) | 置位在后胜出 | 否 |
| 〃 | 〃 | START × 新协议事件 | (a) | START拍没有样本（AMI无数据）、没有重检启动（重检调度器在CONFIG期间已因cancel回到MONITOR）、没有revalidate accept | 否 |
| 〃 | K1无条件清除 | **诊断清除 × 活动故障** | **(c) V1-IDAC-C2（低）** | K1没有任何条件，FAULT为1时也会清掉`o_protocol_error_sticky`。C17 §输入表（305行）与565行：“`i_diag_clear_event`只在三路活动故障均已解除后清除`o_protocol_error_sticky`等非阻断历史诊断”。只影响诊断可见性 | 是：单元TB在FAULT=1时发诊断清除 |
| FAULT位（AMB/DCS_R/DCS_IR） | 耗尽置1（K4–K6）< K14 cancel清0 < K15 START按配置置1 | 耗尽 × cancel | (a) | 耗尽需要合格样本，cancel拍没有（见上两行） | 否 |
| 〃 | — | cancel（含`!run_enable`）立即清FAULT | (b)，附合同差异 | brief §3.6 F-4/L-5方向一致（abort清除活动故障）。C17 560行写“只在STOP/abort终止动作使本地`o_idac_idle=1`且相应活动根因不再存在时”清除，RTL不等idle，在cancel当拍就清。见§3 | 否 |
| `FAULT_EVENT`及身份（K17） | 按`reg_context_next`的上升沿判定 | 两路同时耗尽 | (b) | 只发一次事件，身份取当拍样本；AMI lane 05在一次事件后保持active | 否 |
| `STARTUP_COMPLETE` | K3/K4/K6置1 < K14清0 < K15清0 | 置1 × cancel | (a) | 置1需要边界或样本，cancel拍都没有（边界也受生命周期门控，调度器§8.2.4） | 否 |
| pending代际（K16） | pending由0变1时锁存`i_run_generation` | START拍装载 | (b) | manager在接受START的同一沿就递增代际（manager 534–535），START在T+1到达IDAC时代际已是新值 | 否 |

## 2. 发现详述

### V1-IDAC-C1（低）START与abort同拍：状态机按abort回IDLE，上下文按START装入启动pending

- **RTL**：
  - `state_next`（699–712）：先判STOP/abort→IDLE，START在else-if；
  - `reg_context_next`：K14（1125，abort属于`flag_control_cancel`）在前，K15（1166，START）在后，START胜。
- **结果**：状态IDLE、`AMB/DCS pending valid=1`、`STARTUP_COMPLETE=0`。IDLE状态的case分支不再转移，但K2 commit不看状态，T+2拍的启动IDAC边界会把启动pending提交为committed码。
- **与其它模块**：调度器与AMI在这一对上也是START胜（V1-SCH-C3、V1-AMI §3），SSW是abort胜；IDAC内部又是两种优先级各取一半。系统层面只持续到T+3的drain-STOP。
- **建议**：合同（C17 §输入表或C01）写明START与abort同拍时的统一规则；单元TB覆盖该同拍点。

### V1-IDAC-C2（低）诊断清除无条件清协议sticky

- K1（853–855）没有“三路故障已解除”这一条件，与C17第305、565行不符。

## 3. 合同与RTL差异

1. C17 560行：FAULT要等本地`o_idac_idle=1`才清除；RTL在cancel当拍立即清（1153–1155）。
2. C17 305/565行：诊断清除需要故障已解除（V1-IDAC-C2）。
3. C17 311行：“新START…不得清除活动或历史阻断故障”。RTL的START不清FAULT（FAULT在CONFIG中已被`!run_enable`清掉），但START会清`PROTOCOL_ERROR`（1193），合同没有写协议sticky在START时是否清除。

## 4. 汇总与清单

- (c)：V1-IDAC-C1（低）、V1-IDAC-C2（低）；待定：无。
- always块（4个，全部覆盖）：
  - 688 `state_current`（时序）；
  - 697 `state_next`（组合）；
  - 840 `reg_context_next`（组合，K0–K17）；
  - 1260 `reg_context`（时序）。
- `reg_context`字段（按位定义`CTX_*`）全部归入上表各组：码/epoch/pending/pending代际/边界/确认计数（K2–K11、K14–K16）、update/track_adjust/done/failed脉冲（K0、K2、K4–K10）、search_done/exhausted/FAULT/STARTUP_COMPLETE（K3–K6、K14、K15）、来源位RECHECK/REVALIDATE_ORIGIN、AMB_CHANGED（K2、K4、K6–K8、K10、K12、K14、K15）、PROTOCOL_ERROR（K1、K13、K15）、故障事件与身份（K0、K17）。
