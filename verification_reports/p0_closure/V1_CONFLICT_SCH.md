# V1 同拍冲突矩阵：调度器（`ppg_400hz_frame_calibration_scheduler.v`，对照C08）

- 任务：流片前验证收尾 P0-V1（同拍冲突矩阵），模块1/3
- 基线：main `a1ba482`；RTL版本 V1.12（2026-10-08）；只读分析，未改任何已有文件
- 方法：按CLAUDE.md加载 `erie-verilog-generator` skill，做existing-RTL只读分析。环境里没有仿真器（iverilog/xsim/verilator都不可用），所以全部结论都来自静态逐路追踪；需要仿真才能定的，列为“待定”，或在“建议扫描/断言”列写明构造方法。
- 设计意图依据：C08（`contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`）、B_MERGE_BATCH_BRIEF §3（下称“brief”）、OWNER_LIFECYCLE_ROUND（下称“OLR”）、F009_ROUND（下称“F009”，其附录A的“末拍同拍事件表”已经统筹审核）。合同与RTL有差异时以RTL为准，差异记在§6。

## 0. 记号

调度器的全部状态都在一个寄存器向量 `state_current` 里（字段由`B_*` localparam定义，共95个位置常量，合为65个逻辑字段）。共有3个always块：

| 块 | 行号 | 作用 |
|---|---|---|
| A1 组合 `always@(*)` | 607–875 | 主FSM，生成`state_next` |
| A2 组合 `always @*` | 880–937 | 覆盖层，在`state_next`上叠加滚动（R1）和末拍直接起帧（R2），生成`state_rollover_next` |
| A3 时序 `always@(posedge i_clk or negedge i_rstn)` | 941–947 | 复位清零；否则`state_current <= state_rollover_next` |

A1按程序顺序执行，**同一字段后写者胜**。A2在A1之后，R1/R2写入的字段覆盖A1的结果。下文用以下代号表示A1、A2的写入段（行号为基线行号）：

| 代号 | 行号 | 条件 | 写入要点 |
|---|---|---|---|
| D | 608–612 | 无条件 | `state_next=state_current`；`MACRO_START/NORMAL_COMPLETE/CAL_COMPLETE/SCHED_FAULT_VALID`默认0 |
| P0 | 613–616 | `i_start_ack_event` | 整个向量清零，`STARTED=1`、`STARTUP_PENDING=1`；**其余P1–P12全在else里，不执行** |
| P1 | 618–641 | `stop_ack \|\| abort \|\| !run_enable` | `STARTED=0`、`STOP_DRAIN=1`、`STARTUP_PENDING=0`；仅abort时清`FRAME_ACTIVE/FRAME_MODE`；三个`*_CONTEXT_SEEN=1`，三个`*_WAVE_PENDING=0`，`CAL_REQ_PENDING=0`、`CAL_REQ_ACTIVE=0`；若`INFLIGHT`则`INFLIGHT_DISCARD=1` |
| P2 | 642–644 | `startup_idac_safe_boundary_o` | `STARTUP_PENDING=0` |
| P3 | 645–650 | `diag_clear && !FRAME_ACTIVE && !INFLIGHT && !三个WAVE_PENDING && !flag_external_fault` | 清四个sticky：`LAUNCH_TIMEOUT/OWNER_DEADLINE_TIMEOUT/COMPLETION_MISMATCH/PROTOCOL_ERROR` |
| P4 | 651–657 | `cal_valid && !flag_calibration_request_valid` | `PROTOCOL_ERROR=1`；若当前无本地故障，则`SCHED_FAULT_VALID=1`、`IDENTITY_VALID=0` |
| P5 | 658–670 | `!start && (i_transaction_start_fire != adc_owner_commit_event_o)` | `PROTOCOL_ERROR=1`；若当前无本地故障，则记录故障身份 |
| P6 | 671–677 | `flag_calibration_request_fire` | `CAL_CONTEXT_SEEN=0`、`CAL_REQ_PENDING=1`、锁存`CAL_REQ_TYPE/COLOR/REASON` |
| P7f | 678–696 | `flag_waveform_fire` | 校准：`CAL_REQ_PENDING=0`、`CAL_CONTEXT_SEEN=1`、`CAL_WAVE_PENDING=1`、锁存校准码快照；IR：`IR_CONTEXT_SEEN=1`、`IR_WAVE_PENDING=1`；RED：`RED_CONTEXT_SEEN=1`、`RED_WAVE_PENDING=1` |
| P7t | 697–711 | 无fire且`*_context_due` | RED/IR：`*_CONTEXT_SEEN=1`、`LAUNCH_TIMEOUT=1`、`FRAME_FAILED=1`；CAL：`CAL_CONTEXT_SEEN=1`、`LAUNCH_TIMEOUT=1` |
| P8 | 713–731 | `adc_owner_commit_event_o` | `INFLIGHT=1`、`DISCARD=0`、身份字段、`NEXT_SAMPLE+1`；消费对应的`*_WAVE_PENDING`；校准时`CAL_REQ_ACTIVE`写回当前值（725） |
| P9m | 732–743 | `flag_completion_match` | `INFLIGHT=0`、`DISCARD=0`；成功且为NORMAL时置`RED_DONE/IR_DONE`；`success=0`且非丢弃时置`FRAME_FAILED` |
| P9l | 744–749 | `flag_owner_lost_match`（与P9m互斥，else-if） | `INFLIGHT=0`、`DISCARD=0`；非丢弃时置`FRAME_FAILED` |
| P9x | 750–761 | 有完成或作废事件但不匹配 | `COMPLETION_MISMATCH=1`；若当前无本地故障，则记录故障身份 |
| P10 | 763–778 | `!adc_owner_commit_event_o`，且出现RED/IR/CAL截止 | 清对应`*_WAVE_PENDING`，置`OWNER_DEADLINE_TIMEOUT`；RED/IR还置`FRAME_FAILED` |
| P11 | 779–818 | `flag_frame_start_eligible`（空拍起帧） | 建帧全套初始化；`CAL_CONTEXT_SEEN=(cur PENDING\|\|fire)?0:1`；若**当前**`CAL_REQ_PENDING`为1，则转为`REQ_ACTIVE`，并按`state_current`复制`CAL_FRAME_*` |
| P12a | 820–838 | `FRAME_ACTIVE && CAL && local==624 && REQ_ACTIVE && !CAL_WAVE_PENDING && !INFLIGHT` | `CAL_CONTEXT_SEEN=0`（无当前pending也无fire时改回1）；若**当前**`CAL_REQ_PENDING`为1，则按`state_current`把`REQ_*`复制进`CAL_FRAME_*`，pending保持为1 |
| P12b | 839–863 | `FRAME_ACTIVE && macro_tick==4999` | NORMAL完成判定（读`state_current`）；CAL帧置`CAL_COMPLETE`，若`REQ_ACTIVE`且（当前pending或`CAL_WAVE_PENDING`）则重挂`REQ_PENDING=1`，再清`REQ_ACTIVE`；帧结束：`FRAME_ACTIVE=0`、`MODE=IDLE`、`frame_id+1`、tick/sub/local清零、`CONTEXT_SEEN=1`、`WAVE_PENDING=0` |
| P12c | 864–872 | `FRAME_ACTIVE`且非4999 | tick+1；local回绕或+1；sub+1 |
| R1 | 882–897 | `flag_calibration_rollover`（487–492） | `CAL_COMPLETE=1`、`FRAME_ACTIVE=1`、`MODE=CAL`、`frame_id=cur+1`、tick/sub/local清零、`CAL_CONTEXT_SEEN=0`、`REQ_ACTIVE=1`；若**当前**`CAL_REQ_PENDING`为1，则消费并按`state_current`复制`CAL_FRAME_*` |
| R2 | 898–936 | `flag_frame_restart`（493–494） | 与P11相同的建帧初始化；模式、类型、颜色、原因都取**`state_next`** |

## 1. 上游公共引理（供(a)类判定使用，均逐路追到源头）

| 编号 | 结论 | 追踪 |
|---|---|---|
| U1 | **`i_start_ack_event=1`那一拍`flag_lifecycle_active=0`** | `i_start_ack_event`=Top `flag_measurement_start_ack_event`=`wrapper_start_ack_event_o && !static`（control_top 417），wrapper直通manager `start_ack_event_o`，即`flag_start_accept`打一拍（manager 631）。`flag_start_accept`要求`flag_start_ready`，后者要求`state_current==ST_READY`（manager 451–452）。因此START那一拍manager的`state_current`已经是RUN，而前一拍是READY，`o_run_enable=(state==ST_RUN)`（manager 506）为0。调度器前一拍走P1（`!run_enable`）把`B_STARTED`清0。`flag_lifecycle_active`要求`state_current[B_STARTED]`（440），所以START拍为0。另外`measurement_run_enable`与`measurement_start_ack`共用同一个`!static`门控（control_top 414/417），STATIC_BIAS下两者同为0 |
| U2 | **stop_ack拍`i_run_enable=0`同拍成立；START与stop_ack互斥** | `stop_ack_event_o`是`flag_stop_accept`打一拍，后者要求前一拍状态为RUN或STOPPING（manager 462–464、640）。RUN→STOPPING与寄存的stop_ack同一个沿生效，所以stop_ack那一拍`state_current=STOPPING`，`run_enable=0`。START要求前一拍为READY，二者不可能同时是前一拍的状态 |
| U3 | **在RUN内`B_STARTED`一旦为0，只有START能把它重新置1，而START会原子清零整个向量** | `B_STARTED`只由P0置1（615），只由P1清0（619）。所以`B_STARTED=0`之后，任何`flag_lifecycle_active`门控的置位路径（ready、波形valid、owner valid、起帧、R1、R2、IDAC边界）都关闭，直到下一次START |
| U4 | **abort可以与任何事件同拍，包括START** | `i_control_abort_event`=Top `flag_owner_abort_event`=reg(`i_control_abort_event \|\| supervisor_system_abort_event_o`)（control_top 360）。外部abort来自SPI命令字节0x0090第4位（`ppg_spi_register_file.v` 298）。同一命令字节的第0位是START（294），RTL注释写明“允许同拍多位同时命中”。两路都经同构的`ppg_pulse_cdc_sync`进入系统域。START在manager内是组合接受加一拍寄存，abort在control_top内一拍寄存，**一次写0x11就使START确认与abort在调度器同拍到达**（假定两路CDC延迟相同，同构实例） |
| U5 | **`i_active_config_valid`、`i_input_source`、`i_optical_mode`、`i_allow_new_transaction`在RUN内是静态的** | manager只在CONFIG接受COMMIT（manager 459），ACTIVE快照在RUN内不变；`allow_new_transaction=(state==ST_RUN)`。F009 §1.5已列表核实，本次复核一致 |
| U6 | **AMI `calibration_sample_valid_o=1`蕴含AMI `flag_calibration_request_inflight=0`** | AMI 1456：只在`valid==0 && inflight==0`时置valid；1455：fire当拍valid清0；2023：同一拍inflight置1。inflight只在`accepted \|\| withdraw`（2020）或STOP/abort/阻断（2018）时清0。withdraw=`i_cal_owner_deadline_event \|\| (lost && 校准槽)`（961） |
| U7 | **`dec_frame_mode!=IDLE`蕴含`B_FRAME_ACTIVE=1`** | 凡是写`FRAME_ACTIVE=0`的地方（P1-abort 623–624、P12b 852–853）都同时写`MODE=IDLE`；START清零整个向量；凡是写`MODE=CAL/NORMAL`的地方（P11、R1、R2）都同时写`FRAME_ACTIVE=1` |
| U8 | **owner提交与完成/作废匹配不能同拍** | 提交需要`transaction_start_valid_o`→`flag_transaction_candidate`，三个候选都含`!state_current[B_INFLIGHT]`（463–465）；`flag_completion_match`、`flag_owner_lost_match`都要求`state_current[B_INFLIGHT]`（476–477） |
| U9 | **越过截止的候选不能提交（L-4）** | `transaction_start_valid_o`含`!flag_candidate_expired`（469–470）：RED在tick>283、IR在tick>443、CAL在local>248时被屏蔽。所以宏帧末拍4999（=CAL sub7 local 624）不可能有提交 |

## 2. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)可同拍，不一致或没有依据（发现）｜待定。“扫描/断言”列中的“是”表示建议放进后续逐拍扫描或断言验证。

### 2.1 生命周期字段

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `B_STARTED` | P0置1(615) > [else] P1清0(619) | START × stop_ack | (a) | U2 | 否 |
| 〃 | 〃 | START × `!run_enable` | (a) | U1：START拍`run_enable=1`；STATIC_BIAS下两者同为0 | 否 |
| 〃 | 〃 | **START × abort** | **(c) V1-SCH-C3** | U4：可同拍。START分支在else之外，abort整段被跳过，`B_STARTED=1`、`STOP_DRAIN=0`。C08 §16.2/§16.4都没有规定二者的优先级 | 是：单元TB在同拍驱动start_ack与abort；系统TB写SPI 0x0090=0x11，观察T+2拍是否出现`o_startup_idac_safe_boundary`，以及三模块的处理是否一致 |
| `B_STOP_DRAIN` | P0清0（整体清零）> P1置1(620) | START × P1 | 同上 | 同`B_STARTED` | 同上 |
| `B_STARTUP_PENDING` | P0置1(616)；P1清0(621)；P2清0(643) | P1 × P2 | (a) | P2要求`flag_lifecycle_active`（479），P1的三种条件都使其为0（440） | 否 |
| 〃 | 〃 | P0 × P1/P2 | (a)/(c) | 同`B_STARTED`；START×abort时启动pending保留为1（属于C3） | 归入C3 |
| `B_FRAME_ACTIVE`、`B_FRAME_MODE` | P0清；P1-abort清(623–624)；P11置(780–781)；P12b清(852–853)；R1置(884–885)；R2置(899–900) | P1(STOP，非abort) × P12b | (b) | 纯STOP不清帧，帧自然走到4999由P12b结束，符合V1.6修订与C08 §16.3“已接管但未提交owner的模拟预建立安全收尾”；F009附录A #1、#1′ | 否（已有RESTART-STOP-SCAN） |
| 〃 | 〃 | P1(abort) × P12b（abort落在4999） | (b) | 两者都清0，一致；P12b照常使`frame_id+1`，见`B_FRAME_ID`行 | 否 |
| 〃 | 〃 | P1 × P11 | (a) | P11要求`flag_lifecycle_active`（450） | 否 |
| 〃 | 〃 | P1 × R1/R2 | (a) | R1/R2都含`flag_lifecycle_active`（487、493），即F-010门控 | 否（已有FSC-44、CAL-ROLLOVER、RESTART-*-SCAN） |
| 〃 | 〃 | P11 × P12 | (a) | P11要求`!state_current[B_FRAME_ACTIVE]`（450），P12要求它为1（819） | 否 |
| 〃 | 〃 | R1 × R2 | (a) | R2含`!flag_calibration_rollover`（493） | 否 |
| 〃 | 〃 | P0 × R1/R2 | (a) | U1：START拍lifecycle=0 | 否 |
| `B_FRAME_ID` | P0清；P12b +1(854)；R1 = cur+1(886)；R2沿用P12b结果 | P1(abort)在帧中途 × P12c | (b) | abort中途结束帧，`frame_id`不加1；之后要到START才会再起帧（U3），而START会清零`frame_id`，所以不影响C08 FSC-26“每真实宏帧边界加1” | 否 |
| `B_MACRO_TICK`、`B_CAL_SUB`、`B_CAL_LOCAL` | P0清；P11清；P12b清；P12c递增(865–871)；R1清；R2清 | P1(abort) × P12c | (b)，附注 | abort当拍P12c仍按`state_current[B_FRAME_ACTIVE]`推进一拍，下一拍`FRAME_ACTIVE=0`，tick停在一个非零值（例如abort落在4998时停在4999）。下游凡是读tick的地方，都同时用`FRAME_ACTIVE`或`MODE`门控（453–455、480–481、486–493），SSW在abort拍自行清上下文，所以无功能后果。只是`o_macro_tick`/`o_calibration_local_tick`在空闲时显示陈旧值 | 断言：`!o_normal_frame_active && !o_calibration_frame_active`时，SSW不依据tick产生任何包络 |
| `B_FRAME_OPTICAL/PRECISION/INPUT_SOURCE`、`B_RED/IR_REQUIRED`、`B_FRAME_AMB/DCR/DCIR(_EPOCH)`、`B_FRAME_LEDDAC_R/IR` | P0清；P11装载；R2装载（R1不动） | P11 × R2 | (a) | P11要求`!FRAME_ACTIVE`，R2要求`FRAME_ACTIVE` | 否 |
| 〃 | 〃 | R2装载 × 输入在4999后一拍变化 | (b) | F009 §1.5逐输入核实（U5）：这些输入只在COMMIT、4760或local 385边界变化，末拍采样与空拍采样的值相同；brief §3.7 | 否 |

### 2.2 帧结果字段

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `B_RED_DONE`、`B_IR_DONE` | P0清；P9m成功且为NORMAL时置1(735–740)；P11清(790–791)；R2清(909–910) | P9m × P11（上一帧owner的完成落在空拍起帧拍） | (b) | P11在后，清掉P9m的置位。该完成属于已结束的帧，不得计入新帧；C08 §12.2 | 否 |
| 〃 | 〃 | P9m × R2（完成落在4999） | (b) | F009附录A #10，统筹已审核：本帧完成判定读`state_current`，同拍写入的DONE被重启清零 | 是：扫描IR完成落在4997–5001，检查`o_normal_frame_complete_event`与帧号 |
| 〃 | 〃 | **P9m（上一帧owner）落在新帧tick ≥ 1** | **(c) V1-SCH-C8** | 起帧拍以外的完成，P9m不核对owner所属帧，直接写进新帧的DONE。同拍时由P11/R2的清零兜住，晚一拍就归属错误。详见§3 | 是：见§3 |
| `B_FRAME_FAILED` | P0清；P7t(701/706)；P9m `success=0 && !DISCARD`(741–742)；P9l `!DISCARD`(747–748)；P10 RED/IR(767/772)；P11清(792)；R2清(911) | P9m/P9l × P11/R2 | (b) | 失败属于已结束的帧，被清；F009附录A #10。帧中途作废置的是“当前帧”的失败位，F-7用户已裁定（brief §3.6） | 否 |
| 〃 | 〃 | P7t × P1 | 见`B_LAUNCH_TIMEOUT`行（C2） | | |
| `B_NORMAL_COMPLETE` | D清；P12b置(840–841) | **P1（纯STOP、run_enable撤销、故障）之后，帧自然走到4999** | **(c) V1-SCH-C7（低）** | STOP后帧不清，P12b的完成判定不看生命周期。STOP前两色都已成功的帧，会在4999照常发出`o_normal_frame_complete_event`，与C08 §16.3“不产生新的正式NORMAL完成事件”字面不符。消费者`ppg_amb_recheck_scheduler.v` `flag_period_enabled`含`i_run_enable`（180），所以STOP/run_enable撤销时不会计数；外部故障阻断时run_enable仍为1，会在supervisor的abort之前多计一帧 | 是：单元TB在tick≈1000（两色已完成）发STOP，检查4999是否有完成事件；系统TB做故障阻断的同类场景 |
| 〃 | 〃 | P1(abort)落在4999 × P12b | (c) 并入C7 | abort拍P12b仍按`state_current`判定，可发出完成事件 | 同上 |
| `B_CAL_COMPLETE` | D清；P12b置(844)；R1置(883) | P1（纯STOP）后，CAL帧走到4999 | (b) | 消费者`flag_stage_frame_complete`（recheck 354）要求状态处于AMB/DCS阶段；STOP/run_enable撤销时recheck的`flag_control_cancel`（`ppg_amb_recheck_scheduler.v` 177，含`!i_run_enable`）立即清理阶段上下文，所以不会锁存。属于C08 §12.3“物理宏帧结束事实”的本义 | 否 |
| `B_MACRO_START` | D清；P11置(799)；R2置(918)；R1不置 | R1不发起点脉冲 | (b)，附注 | F009附录A #17：`o_macro_frame_start_event`在Top未连接 | 否 |

### 2.3 校准请求与波形字段（重点）

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `B_CAL_REQ_PENDING` | P0清；P1清(636)；P6置(673)；P7f(cal)清(681)；P11清(810，仅当前pending)；P12a净保持(829→836)；P12b重挂(846–848)；R1清(893，仅当前pending)；R2清(928，按state_next) | P1 × P6 | (a) | ready含`flag_lifecycle_active`（444） | 否 |
| 〃 | 〃 | P6 × P7f(cal)，子帧sub≥1 | (a) | sub≥1时`flag_cal_context_due`要求`state_current[B_CAL_REQ_PENDING]`（455），ready要求它为0（444） | 否 |
| 〃 | 〃 | P6 × P7f(cal)，sub0 local0 | (a) | sub0时due不要求pending，ready也可能为1（REQ_ACTIVE、CAL、无WAVE_PENDING、无INFLIGHT）。但sub0的REQ_ACTIVE来自一次握手H（P11/R1/R2把它转成active），H使AMI inflight=1。按U6，AMI valid要回到1，inflight必须先清0，即：结果被接受（H的样本还没fire，不可能）、withdraw（截止事件要求`CAL_WAVE_PENDING=1`，作废要求有在途owner，见下行）或STOP/abort（会使lifecycle=0）。帧刚建立时H的波形尚未fire，所以AMI valid=0 | 断言：`o_calibration_frame_active && sub==0 && local==0 && cal_context_due → !i_calibration_sample_valid` |
| 〃 | 〃 | 同上，例外核查：L-1跨帧在途的校准owner于sub0作废 | (a) | 该owner对应的是更早的请求H0。H0未消费时AMI inflight=1，AMI不可能再握手H，所以本帧不可能带着新的REQ_ACTIVE开始（与U6同理） | 同上 |
| 〃、`B_CAL_FRAME_TYPE/COLOR/REASON`、`B_CAL_CONTEXT_SEEN` | P12a只在**当前**pending时把`REQ_*`复制到`CAL_FRAME_*`（827–833）；R1同样只在**当前**pending时复制（892–897） | **P6握手 × P12a（任一子帧local 624）或 × R1（帧末4999滚动）** | **(c) V1-SCH-C1（中）** | 握手当拍P6写入新的`REQ_*`并置pending，但P12a/R1看的是`state_current`中pending=0，不复制；`CONTEXT_SEEN`保持0。下一拍（下一子帧local 0）`flag_cal_context_due`成立，波形以**旧**`CAL_FRAME_TYPE/COLOR/REASON`发出，P7f清掉新请求的pending。新请求的类型和颜色从未生效。详见§3 | 是：见§3 |
| 〃 | 〃 | P6 × P12b（NORMAL帧4999） | (b) | R2的类型、颜色、原因取`state_next`（930–932），本拍握手生效；F009附录A #5 | 否（TB FRAME-NC-LAST） |
| 〃 | 〃 | P6 × P12b（CAL帧4999、无滚动） | (a) | CAL帧内握手需要`REQ_ACTIVE && !CAL_WAVE_PENDING && !INFLIGHT`（446–447），而R1的条件（487–492）恰好被它满足（valid=1），所以必走R1，即上一行的C1 | 否 |
| 〃 | 〃 | **P6握手 × P11空拍起帧** | **(c) V1-SCH-C4（低）** | P11按`state_current[B_CAL_REQ_PENDING]`（=0）决定帧模式，于是起NORMAL帧；新请求留在pending里，直到该NORMAL帧4999才由R2起CAL帧，推迟5000拍。C08 §15规定“新的AMI校准请求 > NORMAL事务”。请求没有丢失 | 是：单元TB在`flag_frame_start_eligible`那一拍拉高合法校准valid |
| 〃 | 〃 | P12b重挂 × R1 | (b) | R1要求`!CAL_WAVE_PENDING`，所以重挂只可能来自当前pending；R1随后消费它，与P11路径等价；FSC-31/32 | 否 |
| 〃 | 〃 | P12b重挂 × R2 | (b) | R2取`state_next`，含重挂；F009附录A #8；L-1：在途owner不重挂（847注释，OLR §8.4第5条） | 否 |
| 〃 | 〃 | 例外C：CAL帧末owner在途、无pending、NORMAL资格不成立、AMI电平保持请求 | (b) | brief §3.7（用户已定，FSC-03的已知例外） | 否（已有帧间隔监视器） |
| 〃、`B_CAL_CONTEXT_SEEN` | P1清pending、置SEEN=1；之后P12a（829→836）和P12b（846–848）读`state_current`，把pending重新置1，P12a还把SEEN置0 | **P1（STOP/abort/run_enable撤销）× P12a（local 624）或P12b（4999）** | **(c) V1-SCH-C5（无可观测后果）** | 撤销后`B_CAL_REQ_PENDING=1`，可能还有`CAL_CONTEXT_SEEN=0`，残留到下一次START。按U3，所有读这两个位的置位路径都由lifecycle门控（444、455经460、450、482、487、493），而且两者都不进任何输出端口（`o_scheduler_idle`不含`REQ_PENDING`，580），START会原子清零。与C08 §16.3“撤销未接受校准请求”的状态语义不符，但对外不可观测 | 断言：`!B_STARTED → !waveform_valid && !ready && !owner_valid`（已经成立，作为回归护栏） |
| `B_CAL_REQ_ACTIVE` | P0清；P1清(637)；P8(cal)写回当前值(725)；P11置1或0(811/816)；P12b清(849)；R1置(891)；R2置1或0(929/934) | P1 × P8 | (a) | P8需要lifecycle | 否 |
| 〃 | 〃 | P8 × P12b | (a) | U9 | 否 |
| 〃 | 〃 | P8 × P11 | (a) | 空拍时三个WAVE_PENDING都为0（P12b、P1、P0都清），没有候选 | 否 |
| 〃 | 〃 | R2(NORMAL) × L-1跨帧在途校准owner | (b) | F009附录A #9：在途owner跨入NORMAL帧，REQ_ACTIVE=0，完成照常释放owner | 否 |
| `B_CAL_REQ_TYPE/COLOR/REASON` | 只有P6写（P0清） | — | — | 单写者 | — |
| `B_CAL_CONTEXT_SEEN` | P0清；P1置1；P6清0；P7f(cal)置1；P7t(cal)置1；P11按条件；P12a按条件；P12b置1；R1清0；R2按条件 | P6 × P7t(cal) | (a) | sub≥1时due要求pending，ready要求无pending；sub0同U6 | 否 |
| 〃 | 〃 | P1 × R1/R2 | (a) | lifecycle | 否 |
| 〃 | 〃 | P1 × P12a | (c) 并入C5 | | |
| `B_RED_CONTEXT_SEEN`、`B_IR_CONTEXT_SEEN` | P0清；P1置1；P7f置1；P7t置1；P11清；P12b置1；R2清 | P7f/P7t（tick 0/160）× P12b（4999） | (a) | tick不同 | 否 |
| 〃 | 〃 | P1 × P11/R2 | (a) | lifecycle | 否 |
| `B_CAL_WAVE_PENDING` | P0清；P1清(635)；P7f(cal)置(685)；P8(cal)清(722)；P10(cal)清(775)；P11清(798)；P12b清(863)；R2清(917) | P7f × P8 | (a) | P7f在local 0，P8(cal)需要当前pending；上一笔pending在248前已被提交或截止消费 | 否 |
| 〃 | 〃 | P8 × P10 | (b) | P10整段由`!adc_owner_commit_event_o`门控（763）：截止当拍提交属按时提交（L-4；V1.9；C08 FSC-50 V1.12补记） | 否（TB已有248/247/249三组） |
| 〃 | 〃 | P1 × P7f | (a) | 波形valid含lifecycle（460） | 否 |
| 〃 | 〃 | `CAL_WAVE_PENDING && INFLIGHT`同时为1 | (b) | 可达：R2起CAL帧时带着L-1/跨帧的在途owner，sub0波形照常接管。此时截止要等INFLIGHT释放后才触发（486），4999时P12b的`CAL_WAVE_PENDING`项负责重挂。这正是846行该项的用途 | 是：单元TB让CAL帧起始时owner在途，分别在local 248前后和4999之后释放，检查重挂与截止事件各只发生一次 |
| `B_RED_WAVE_PENDING`、`B_IR_WAVE_PENDING` | P0清；P1清；P7f置；P8清；P10清；P11清；P12b清；R2清 | P7f(IR, tick 160) × P8(RED提交) | (b) | 两者写不同的位；C08 §10.1、§17第23条：IR波形接管不等待RED owner | 否 |
| 〃 | 〃 | P8 × P10 | (b) | 同CAL | 否 |
| 〃 | 〃 | RED截止 × IR提交 | (a) | 有RED pending时候选只能是RED（464–465） | 否 |
| 〃 | 〃 | F-3附：RED已释放、tick<283时调度器允许IR提交，SSW要等RED窗口在283后关闭 | 不在本次 | brief §3.8已排除，交收尾计划 | — |

### 2.4 owner在途字段

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `B_INFLIGHT` | P0清；P8置(714)；P9m清(733)；P9l清(745) | P8 × P9m/P9l | (a) | U8 | 否 |
| 〃 | 〃 | P0 × P9m | (a) | manager START要求`i_adc_idle && i_datapath_empty`（452），AMI `o_datapath_empty`含整条ADC链空闲（AMI 1195），没有在途owner就不会发完成 | 否 |
| 〃 | 〃 | P0 × P9l | (a) | AMI作废条件显式含`!i_start_ack_event`（OLR §1.1公式） | 否 |
| `B_INFLIGHT_DISCARD` | P0清；P1置(639)；P8清(715)；P9m清(734)；P9l清(746) | P1 × P8 | (a) | lifecycle | 否 |
| 〃、`B_RED/IR_DONE` | P1在前、P9m在后；`flag_completion_success`读`state_current[B_INFLIGHT_DISCARD]`（478） | **P1（STOP/abort）× P9m `success=1`** | **待定 V1-SCH-P1** | 同拍时完成按成功处理（置DONE），owner照常释放。C08 §16.3写“STOP接受时标记为discard-pending”，同拍完成究竟算STOP前还是STOP后，没有明文。必须与AMI对同一拍的结果处理一致，否则调度器计成功、AMI丢弃（或反之）。纯STOP时帧会走到4999，还可能触发C7 | 是：三模块同拍扫描，STOP/abort相对DONE取−1/0/+1拍，比较调度器DONE位、AMI正式结果、discard原因（AMI节复核） |
| 〃 | 〃 | P1 × P9l | (b) | 作废释放owner，`FRAME_FAILED`读当前DISCARD（747）；OLR §1.1 R3 | 否 |
| `B_INFLIGHT_SAMPLE/TYPE/COLOR/GENERATION` | 只有P8写 | — | — | 单写者 | — |
| `B_NEXT_SAMPLE` | P0清；P8 +1 | — | — | 两写者分属if/else，互斥 | — |

### 2.5 诊断sticky与故障记录

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `B_LAUNCH_TIMEOUT` | P0清；P3清(646)；P7t置(700/705/710) | P3 × P7t | (a) | P3要求`!FRAME_ACTIVE`，due要求`FRAME_ACTIVE` | 否 |
| 〃 | 〃 | **P1（STOP/abort/run_enable撤销）× 固定接管点（RED tick 0、IR tick 160、CAL local 0）** | **(c) V1-SCH-C2（低）** | `*_context_due`（453–455）不含lifecycle，波形valid（460）含。撤销当拍valid=0，走P7t：置`LAUNCH_TIMEOUT`（和`FRAME_FAILED`）。撤销早一拍时，P1已把SEEN置1，due不再成立，sticky不置。所以同一个STOP，早一拍和同拍得到不同的诊断。外部故障导致lifecycle=0时，之后每个接管点都会一致地置位，属(b) | 是：单元TB扫描STOP/abort落在tick 159/160/161、0/1、local 0/1，检查sticky |
| `B_OWNER_DEADLINE_TIMEOUT` | P0清；P3清(647)；P10置(766/771/776) | P3 × P10 | (a) | 截止要求`FRAME_ACTIVE` | 否 |
| 〃、`o_cal_owner_deadline_event` | P10读`state_current`的WAVE_PENDING；截止flag（484–486）不含lifecycle | **P1 × 截止点（RED 283、IR 443、CAL local 248）** | **(c) 并入V1-SCH-C2** | 撤销当拍P1清pending，P10仍按`state_current`触发：置sticky；若是CAL截止，还在撤销当拍向AMI输出一拍`o_cal_owner_deadline_event`。撤销早一拍则都不发生。C08 §10.3写明该事件“不以`flag_lifecycle_active`门控”，所以事件本身符合合同，但sticky不一致；AMI在同一拍同时收到withdraw与STOP，见AMI节 | 是：同上，扫描283/443/local 248 ±1 |
| 〃 | 已知 | 周期重检期间夹在校准帧之间的NORMAL帧，RED/IR没有owner，截止sticky被置位 | (b) | brief §3.7（OLR §7.1(d)，用户已定写入合同） | 否 |
| `B_COMPLETION_MISMATCH` | P0清；P3清(648)；P9x置(751) | P3 × P9x（空闲时的无owner DONE） | (b) | P9x在后，新错配胜出。C08 §16.5：诊断清除只清非活动历史，同拍发生的新错误是活动的 | 是：断言`diag_clear && 同拍新错误 → 下一拍sticky=1` |
| `B_PROTOCOL_ERROR` | P0清；P3清(649)；P4置(652)；P5置(659) | P3 × P4/P5 | (b) | 同上 | 同上 |
| 〃 | 〃 | P0 × P4 | (b) | START拍P4被跳过。U1：START拍ready=0，非法请求不会被接收；下一拍仍保持valid就会被标记 | 否 |
| `B_SCHED_FAULT_VALID` | D清；P4/P5/P9x在“当前无本地故障”时置1 | P3清sticky × 同拍新错误 | (b) | 当前已处于故障时不发新valid，sticky不落，`o_scheduler_fault_active`一直为1，属于同一episode；C08 §15.1“valid is one cycle per new episode” | 否 |
| `B_SCHED_FAULT_IDENTITY_VALID`及身份字段 | P4写(655)，P5写(662–668)，P9x写(754–760)，后写者胜：P9x > P5 > P4 | **P4/P5/P9x任两项同拍** | **(c) V1-SCH-C6（低）** | 两路以上协议条件同拍时，上报的身份按代码顺序取最后一个；cause固定为8'h11。C08 §15.1、C24都没有规定选择规则。只影响诊断取证 | 是：断言或单元TB，同拍注入非法请求与无owner DONE，记录实际上报的身份 |
| 4个sticky被P3清除（含`PROTOCOL_ERROR`/`COMPLETION_MISMATCH`，即本地阻断） | P3 | 诊断清除解除本地阻断 | (b)，附合同差异 | P3要求`!FRAME_ACTIVE && !INFLIGHT && 无pending && !外部故障`。supervisor收到本地故障后会abort（使`B_STARTED=0`，U3），所以清掉本地阻断不会恢复事务。合同C08 §15.1写“`i_diag_clear_event` … cannot release … active fault”，与RTL字面不符，见§6 | 否 |
| 〃 | 〃 | 诊断清除只能在RUN之外生效 | (b) | brief §3.7（审核点D），F009附录A #15 | 否 |

### 2.6 组合事件（不是寄存器，但它们是下游寄存器的置位条件，一并列出）

| 对象 | 条件 | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `o_idac_code_safe_boundary`（483） | 启动边界、宏帧4760、校准local 385、L-3空闲边界四路OR | 4760 × sub7 local 385 | (b) | C08 §8.2.3：允许同拍，IDAC只提交一次 | 否（FSC-40） |
| 〃 | 〃 | 启动边界 × 空闲边界 | (a) | 空闲边界要求`!STARTUP_PENDING`（482） | 否 |
| 〃 | 〃 | 启动/空闲边界 × 宏帧/校准边界 | (a) | 前者要求`!FRAME_ACTIVE`，后者要求`FRAME_ACTIVE` | 否 |
| 〃 | 〃 | 空闲边界 × P6握手 | (b) | 握手下一拍起CAL帧，tick 0再隔一拍接管，波形接管时实时读码（504–507），提交已生效。“提交到接管只隔2~16拍”是否够用，brief §3.8已交模拟侧确认 | 否 |
| `o_cal_owner_deadline_event`（588） | `flag_cal_owner_deadline && !commit` | × commit | (b) | V1.9；TASKC报告 | 否 |
| 〃 | 〃 | × STOP/abort | 并入C2 | | |
| `o_calibration_sample_ready`（444–447） | — | R1使用`i_calibration_sample_valid`而不是fire（492） | (b) | 若valid=1、fire=0且R1成立：U5保证config有效；pending=1时R1本来就成立；lifecycle两边相同。剩下的唯一差别是请求非法，此时P4在同拍置协议错误，下一拍lifecycle=0，新帧没有波形可接管，supervisor随即abort，无错绑 | 否 |

## 3. (c)类发现详述

### V1-SCH-C1（中）子帧边界或宏帧末拍同拍握手：下一子帧沿用旧请求的类型和颜色，新请求被吞

- **场景**：校准宏帧内，`B_CAL_REQ_ACTIVE=1`、`CAL_WAVE_PENDING=0`、`INFLIGHT=0`、`CAL_REQ_PENDING=0`时，ready为1（444–447，与tick无关）。AMI的下一笔请求恰好在某个子帧的**local 624**（含宏帧末拍4999，即sub7 local 624）完成握手。
- **逐拍**：
  - 第t拍（local 624）：P6置`REQ_PENDING=1`、`CAL_CONTEXT_SEEN=0`，锁存新的`REQ_TYPE/COLOR/REASON`（671–677）。
    - 若不是4999：P12a条件成立（820），但827行只在`state_current[B_CAL_REQ_PENDING]`为1时复制`REQ_*→CAL_FRAME_*`，此时为0，不复制；823行因fire=1不回锁SEEN。
    - 若是4999：R1条件成立（492行接受`i_calibration_sample_valid`），892行同样只看`state_current`的pending，不复制；`state_rollover_next`沿用P6的pending=1。
  - 第t+1拍（下一子帧local 0）：`flag_cal_context_due`成立（455：sub≥1时pending=1；sub0时REQ_ACTIVE=1即可）。`o_waveform_frame_type/color`取**旧**的`CAL_FRAME_TYPE/COLOR`（500–501、505、509）。SSW接管时P7f清掉`REQ_PENDING`（681），新请求的类型和颜色再也没有生效的机会。
- **对照**：握手若在local ≤ 623，下一拍P12a会看到当前pending=1并正确复制；NORMAL帧4999的握手由R2从`state_next`取值，也是正确的（F-009设计）。只有“握手拍=local 624”这一拍出错。
- **后果**：
  - 新旧请求类型和颜色相同时（同一阶段内的候选），只有REASON可能不同，基本无害；
  - 阶段切换（AMB→DC_R、DC_R→DC_IR）时，调度器发出旧类型/颜色的波形和owner候选，AMI的`flag_calibration_start_match`比对类型和颜色（AMI 983）失败：`transaction_start_ready_o=0`（986），并在1630/1781/1934各支路记协议错误，形成阻断故障，supervisor随即abort+STOP。正常运行中就可能被误判为系统故障。
- **可达性**：阶段在校准帧中途切换的路径已经实测存在（OLR §4.3(a)，F-9：结果被接受后约4拍就有下一阶段握手，lt274→lt278）。握手时刻随ADC完成延迟（合法迟到可达4355拍）连续变化，所以总能找到某个延迟使握手正好落在local 624。启动搜索阶段切换的时刻锚定在IDAC local 385提交之后的固定延迟，落在624的可能性取决于该延迟，静态无法排除，也无法确认。
- **RTL证据**：`ppg_400hz_frame_calibration_scheduler.v` 444–447（ready不限tick）、455（due）、671–677（P6）、820–838（P12a，827/829–833只看`state_current`）、882–897（R1，892–897只看`state_current`）、492（R1接受valid）、500–509（波形载荷取`CAL_FRAME_*`）、681（P7f消费pending）。
- **建议**：
  - 单元TB（不需要仿真器以外的工具）：
    1. 在某子帧local 624拉高一笔与当前帧不同类型或颜色的合法请求，检查下一拍`o_waveform_frame_type/color`是否等于新请求；
    2. 在CAL帧4999（滚动路径）做同样检查；
    3. 用local 623作对照。
  - 断言：`flag_waveform_fire && flag_waveform_is_calibration`时，波形类型和颜色等于“最后一次被接受的请求”的类型和颜色（TB侧镜像寄存器）。
  - 系统级：periodic_recheck_recovery场景下扫描IDAC结果接受时刻，使下一阶段握手落在local 620–628。

### V1-SCH-C2（低）撤销事件与接管点或截止点同拍时，非阻断诊断sticky被置位

- **场景**：STOP确认、abort或run_enable撤销恰好落在RED tick 0、IR tick 160、CAL local 0（接管点），或RED tick 283、IR tick 443、CAL local 248（owner截止点）。
- **机理**：
  - `flag_*_context_due`（453–455）与`flag_*_owner_deadline`（484–486）都不含`flag_lifecycle_active`。
  - 撤销当拍波形valid和owner valid都被lifecycle屏蔽，于是走P7t或P10：置`B_LAUNCH_TIMEOUT`或`B_OWNER_DEADLINE_TIMEOUT`（以及`FRAME_FAILED`）。
  - CAL截止还会在撤销当拍向AMI输出`o_cal_owner_deadline_event`。
  - 撤销早一拍时，P1已置SEEN=1并清pending，这些条件都不再成立。
- **后果**：同一个STOP，早一拍不置sticky，正好落在接管点或截止点就置，软件读到的诊断取决于1拍的巧合。sticky非阻断，START清零，没有功能影响。AMI在撤销当拍同时收到withdraw与STOP，见AMI文件。
- **依据缺口**：C08 §10.1、§4.5只定义“错过”的语义，没有说撤销同拍算不算错过。外部故障导致lifecycle=0时，之后每个接管点都会一致地置位，这一情形不算发现。
- **建议**：单元TB扫描撤销落在{159,160,161}、{0,1}、{282,283,284}、{442,443,444}、local{0,1,247,248,249}，记录两个sticky与截止事件；系统TB断言“STOP拍的`o_cal_owner_deadline_event`不引起AMI重新请求”。

### V1-SCH-C3（低）START与abort同拍：调度器里START胜出，abort被吞

- **可达性**：U4，一次SPI写0x0090=0x11即可。
- **逐拍**（T=SPI命令在系统域的那一拍）：
  - T+1：START确认与abort同拍到达。P0胜出，`B_STARTED=1`、`STOP_DRAIN=0`、`STARTUP_PENDING=1`，abort没有任何效果。
  - T+2：`flag_lifecycle_active=1`。若此时ADC、模拟、SAR时序都空闲，会发出一拍`o_startup_idac_safe_boundary`，同时发出`o_idac_code_safe_boundary`（IDAC可能提交启动pending码）。
  - T+3：abort派生的drain-STOP（control_top 369→378，manager在T+2接受）到达，`stop_ack`进入排空。
- **后果**：一个只持续约2拍的RUN；run_generation加1；可能多出一次启动IDAC边界。C08 §16.2/§16.4没有规定START与abort的优先级。SSW、AMI各自的优先级是否与调度器一致，决定了IDAC是否真的在这一拍提交、owner和请求是否残留，见SSW/AMI文件。
- **建议**：系统TB写0x11，检查三模块状态与IDAC epoch；合同补一句START与abort同拍的处理。

### V1-SCH-C4（低）空拍起帧与校准握手同拍：校准请求推迟一整帧

- 场景：调度器空闲，`flag_frame_start_eligible`因NORMAL输入资格成立（450），同拍完成了一笔校准握手（ready第一项`!REQ_ACTIVE && !FRAME_ACTIVE`，445）。
- 机理：P11按`state_current[B_CAL_REQ_PENDING]`（=0）选模式（781、783、809），于是起NORMAL帧；P6置的pending保留，直到该帧4999才由R2起CAL帧。
- 后果：校准请求推迟5000拍，没有丢失；与C08 §15“新的AMI校准请求 > NORMAL事务”不符。F-009之后，帧与帧之间由R2无缝衔接（R2取`state_next`，没有这个问题），空拍起帧只出现在START后首帧、精度切换挂起解除、例外C之后，所以可达窗口窄。
- 建议：单元TB在起帧拍同拍握手，检查帧模式。

### V1-SCH-C5（无可观测后果）撤销与子帧末或帧末同拍时，P12a/P12b覆盖P1的撤销

- 见2.3节。撤销后`B_CAL_REQ_PENDING`残留为1、`B_CAL_CONTEXT_SEEN`可能为0，直到START。对外不可观测（U3，且不进任何输出端口）。列出来只是因为它与“STOP撤销未接受校准请求”的状态语义不符，以后若有人去掉lifecycle门控，它会立刻变成真缺陷。
- 建议：保留断言`!B_STARTED → !(o_waveform_context_valid||o_calibration_sample_ready||o_transaction_start_valid)`作为护栏。

### V1-SCH-C6（低）多个协议条件同拍时，故障身份的取舍没有依据

- P4、P5、P9x按代码顺序后写者胜：P9x > P5 > P4。cause固定为8'h11，只影响上报的owner身份。
- 建议：合同C08 §15.1或C24补一句选择规则，或在别名表登记为已知行为。

### V1-SCH-C7（低）STOP、abort、阻断故障之后，帧末仍可发出NORMAL完成

- 见2.2节。STOP与run_enable撤销的情形被消费者的`i_run_enable`门控吸收；故障阻断时run_enable仍为1，在supervisor的abort到达之前，recheck的NORMAL帧计数可能多加1。影响只是AMB重检间隔偏差1帧。与C08 §16.3字面不符。

### V1-SCH-C8（低）跨帧在途NORMAL owner的成功完成计入新帧

- 场景：帧N的IR（或RED）owner越过帧末仍在途（例如ADC长时间忙，OLR SYS-CAL-BUSY-NORMAL同类条件），在帧N+1 tick ≥ 1时完成，且成功。
- 机理：P9m（735–740）按`INFLIGHT_COLOR`置`IR_DONE/RED_DONE`，不核对owner的`frame_id`。只有恰好落在起帧拍时由P11/R2清零兜住。
- 后果：帧N+1的DONE中混入帧N的结果。若帧N+1自身的IR owner在4999时仍在途（同一慢ADC条件，既未完成也未被作废、没有失败），P12b会用这个陈旧的`IR_DONE`判定帧N+1完整，提前发出一次NORMAL完成。影响是重检间隔计数偏差。F-7裁定失败归当前帧，没有涉及成功归属。
- 建议：TB让IR owner在帧N+1 tick 50完成，同时让帧N+1的IR owner在途跨过4999，检查是否出现NORMAL完成；或请统筹裁定“成功也归当前帧”为已知行为。

## 4. 待定项

| 编号 | 内容 | 需要的仿真 |
|---|---|---|
| V1-SCH-P1 | STOP/abort与匹配完成（`success=1`）同拍：调度器按成功计（读当前DISCARD=0），owner释放；纯STOP时帧继续，可能进入C7的NORMAL完成。要看AMI对同一拍是输出正式结果还是丢弃，以及SSW的owner释放是否一致 | 三模块联合（control_top）扫描：STOP/abort相对DONE取−1/0/+1拍，记录调度器`RED/IR_DONE`、AMI `measurement_result_valid`与discard原因、SSW `adc_owner_inflight_o`。AMI节会给出AMI侧的静态结论 |

## 5. 汇总

**(c)类**（8项）：

| 编号 | 级别 | 一句话 |
|---|---|---|
| V1-SCH-C1 | 中 | local 624或4999同拍握手：下一子帧波形用旧类型/颜色，新请求被吞；阶段切换时引发AMI start mismatch，形成阻断故障 |
| V1-SCH-C2 | 低 | 撤销与接管点或截止点同拍：launch/owner-deadline sticky被置，CAL截止事件在撤销拍发出 |
| V1-SCH-C3 | 低 | START与abort同拍（SPI 0x11可达）：START胜出，abort被吞，可多出一拍启动IDAC边界 |
| V1-SCH-C4 | 低 | 空拍起帧与校准握手同拍：校准推迟一帧，违反§15优先级 |
| V1-SCH-C5 | 无可观测 | 撤销与local 624/4999同拍：pending重挂、SEEN重开，残留到START |
| V1-SCH-C6 | 低 | 多个协议条件同拍：故障身份按代码顺序取最后一个，没有规则 |
| V1-SCH-C7 | 低 | STOP、abort、故障之后，帧末仍发NORMAL完成（§16.3字面） |
| V1-SCH-C8 | 低 | 跨帧在途owner的成功完成计入新帧的DONE |

**待定**（1项）：V1-SCH-P1（STOP/abort与成功完成同拍，需跨模块一致性仿真）。

## 6. 合同与RTL差异记录（以RTL为准）

1. C08 §15.1“`i_diag_clear_event` … cannot release … active fault”：RTL的P3（645–650）在空闲时会清`PROTOCOL_ERROR/COMPLETION_MISMATCH`，二者正是`o_scheduler_fault_active`的来源。系统层由supervisor abort兜底（U3），所以没有功能后果。
2. C08 §16.3“不产生新的正式NORMAL完成事件”：见C7。
3. C08 §9.1正文与§10.3中的行号（`:659-662`、`:431-434`等）已经漂移（例如ready现在在444–447，P7f在678–689）。按brief §3.2由B批次转换为符号锚点，这里只是记录。
4. C08 §16.2/§16.4没有写START与abort同拍时的优先级（C3）。
5. C08 §9.1写“请求握手后由调度器拥有并保持，直到某个后续local tick 0完成波形上下文握手”，没有排除local 624握手。RTL在该拍会把新请求交给“旧载荷”的波形（C1），与§9.1的“每个真实ADC owner fire只对应一笔请求”不冲突，但与类型、颜色的绑定意图冲突。

## 7. 已覆盖的always块与寄存器清单

**always块**（共3个，全部覆盖）：

- A1：607–875，组合主FSM（P0–P12c逐段）；
- A2：880–937，组合覆盖层（R1、R2）；
- A3：941–947，时序寄存器（复位清零与原子提交；复位与时钟沿互斥，不产生同拍冲突）。

**寄存器**：

- 物理寄存器只有`state_current`（338）。`state_next`（339）与`state_rollover_next`（340）是组合变量，带初值声明，在A1/A2中被完全赋值。

**`state_current`字段**（65个逻辑字段，95个位置常量全部对应；“单写者”指除P0/复位外只有一个写入点）：

| 组 | 字段 | 覆盖位置 |
|---|---|---|
| 生命周期 | `B_STARTED`、`B_STARTUP_PENDING`、`B_STOP_DRAIN` | §2.1 |
| 帧 | `B_FRAME_ACTIVE`、`B_FRAME_MODE_L/H`、`B_FRAME_OPTICAL_L/H`、`B_FRAME_PRECISION`、`B_FRAME_INPUT_SOURCE`、`B_FRAME_ID_L/H`、`B_MACRO_TICK_L/H`、`B_CAL_SUB_L/H`、`B_CAL_LOCAL_L/H`、`B_RED_REQUIRED`、`B_IR_REQUIRED` | §2.1 |
| 帧码快照 | `B_FRAME_AMB_L/H`、`B_FRAME_DCR_L/H`、`B_FRAME_DCIR_L/H`、`B_FRAME_AMB_EPOCH_L/H`、`B_FRAME_DCR_EPOCH_L/H`、`B_FRAME_DCIR_EPOCH_L/H`、`B_FRAME_LEDDAC_R_L/H`、`B_FRAME_LEDDAC_IR_L/H` | §2.1（P11/R2装载，互斥） |
| 帧结果 | `B_RED_DONE`、`B_IR_DONE`、`B_FRAME_FAILED`、`B_MACRO_START`、`B_NORMAL_COMPLETE`、`B_CAL_COMPLETE` | §2.2 |
| 校准请求 | `B_CAL_REQ_PENDING`、`B_CAL_REQ_ACTIVE`、`B_CAL_REQ_TYPE_L/H`、`B_CAL_REQ_COLOR`、`B_CAL_REQ_REASON_L/H`、`B_CAL_FRAME_TYPE_L/H`、`B_CAL_FRAME_COLOR`、`B_CAL_FRAME_REASON_L/H` | §2.3 |
| 波形 | `B_RED_CONTEXT_SEEN`、`B_IR_CONTEXT_SEEN`、`B_CAL_CONTEXT_SEEN`、`B_RED_WAVE_PENDING`、`B_IR_WAVE_PENDING`、`B_CAL_WAVE_PENDING`、`B_CAL_WAVE_AMB_L/H`、`B_CAL_WAVE_DC_L/H`、`B_CAL_WAVE_AMB_EPOCH_L/H`、`B_CAL_WAVE_DC_EPOCH_L/H` | §2.3（`B_CAL_WAVE_*`码快照只由P7f写，单写者） |
| owner | `B_INFLIGHT`、`B_INFLIGHT_DISCARD`、`B_INFLIGHT_SAMPLE_L/H`、`B_INFLIGHT_TYPE_L/H`、`B_INFLIGHT_COLOR`、`B_INFLIGHT_GENERATION_L/H`、`B_NEXT_SAMPLE_L/H` | §2.4 |
| 诊断与故障记录 | `B_LAUNCH_TIMEOUT`、`B_OWNER_DEADLINE_TIMEOUT`、`B_COMPLETION_MISMATCH`、`B_PROTOCOL_ERROR`、`B_SCHED_FAULT_VALID`、`B_SCHED_FAULT_IDENTITY_VALID`、`B_SCHED_FAULT_FRAME_ID_L/H`、`B_SCHED_FAULT_SAMPLE_INDEX_L/H`、`B_SCHED_FAULT_COLOR`、`B_SCHED_FAULT_FRAME_TYPE_L/H`、`B_SCHED_FAULT_PRECISION`、`B_SCHED_FAULT_GENERATION_L/H` | §2.5 |

组合事件`o_idac_code_safe_boundary`、`o_cal_owner_deadline_event`、`o_calibration_sample_ready`的置位条件见§2.6。
