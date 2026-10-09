> **入库说明（统筹会话，2026-10-09）**
> - 本报告由统筹会话委派的独立审查子代理完成，统筹已核实关键论据：C08 §12.3原文、`ppg_amb_recheck_scheduler.v`:186/:354、`ppg_idac_code_controller.v`:469-487的样本资格。
> - **用户裁定（2026-10-09）：F-9按B级处理，不改RTL，由B合同合并批次按§5"修法3"改C16 §9.4、C08 §12.3，并改RTL注释:148/:215/:269（只改注释）。**
> - 文中`W/...`和`D:\PPG\verilog\ppg_regression_runs\...`是统筹机器上的路径，不在本仓库。探针`f9_mon.sv`没有入库。
> - 下文正文保持子代理原文。

# F-9 独立审查报告（重检阶段"帧完成"沿用上一宏帧）

> 审查对象：main `7a8eabf`（只读 `git archive` 导出到 `W/src/`，下文行号均为 7a8eabf 行号）。
> 边审边写：每确认一点即追加。W = `C:\Users\d\AppData\Local\Temp\claude\D--PPG-verilog-jxa\c5cd7fbb-935e-4508-95ee-89aff89a572a\scratchpad\f9_review\`。

## 0. 方法

- 静态：通读 `ppg_amb_recheck_scheduler.v`（全文379行）、`ppg_400hz_frame_calibration_scheduler.v`（:340-949 主FSM与覆盖层）、`ppg_idac_code_controller.v`（FSM :686-835、上下文更新 :837-1120、资格 :469-487、提交 :584-602）；追 `i_calibration_frame_complete_event` 在 PWI/AMI/control_top 的全部连接点。
- 合同：C16、C17、C08 全文相关节，测试合同 `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md` §9.3/§9.4.1/§9.4.3（RRC/SID 验收ID的定义处），矩阵 `PPG_CONTRACT_CLOSURE_MATRIX.md` 与别名表的 RRC 行。
- 日志：`D:\PPG\verilog\ppg_regression_runs\545abfd_20261009\g2\...\tb_ppg_control_top_adc_anomaly\xsim.log`（只读）。
- 探针：xsim 被动监视器，见 §3.5；产物清单见 §9。

---

## 1. 机理（RTL 逐行确认）

### 1.1 重检调度器阶段推进条件

`rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v`（V1.2）：

| 符号 | 行 | 内容 |
|---|---|---|
| `flag_stage_frame_available` | :186 | `flag_stage_frame_complete \|\| i_calibration_frame_complete_event` |
| `flag_stage_result_available` | :185 | AMB：`i_amb_sequence_done`；DC_R：`i_dcs_sample_request && i_dcs_sample_color_ir`（IDAC已开始要IR样本）；DC_IR：`i_dcs_revalidate_done`；或已锁存的 `flag_stage_result_done` |
| `flag_enter_ir` | :192 | `ST_DCS_R && result_available && frame_available` |
| `enc_sequence_done_o` | :196 | `ST_AMB && !dcs_enable && result && frame`，或 `ST_DCS_IR && result && frame` |
| 状态转移 ST_AMB/ST_DCS_R/ST_DCS_IR | :297-322 | 同样要求 `result_available && frame_available` |
| `flag_stage_frame_complete` 置位 | :354-355 | 处于 ST_AMB/ST_DCS_R/ST_DCS_IR 时，**任意一次** `i_calibration_frame_complete_event` 即置1，不区分是哪个宏帧、本阶段样本在哪个宏帧 |
| `flag_stage_frame_complete` 清零 | :352-353 | 仅在 START/取消/done/failed/`flag_enter_amb`/`dcs_revalidate_accept_o`/`flag_enter_ir` |
| `flag_sample_inflight` | :363-377 | F-020（:370-371）在撤销事件时清零，保持型请求随即重发；**不清 `flag_stage_frame_complete`** |
| 模块自述意图 | :269 注释 | "下一状态逻辑强制三个校准阶段由各自物理帧边界隔开"；:148 注释"当前校准阶段对应物理帧已经结束" |

结论（静态，确定）：阶段推进只要求"本阶段期间出现过一次校准宏帧完成"和"本阶段结果已出"，二者任意先后。只要某一阶段跨过了一个校准宏帧末拍而结果尚未出，此后结果一到就在**结果所在拍**推进，下一阶段的请求随即在同一物理校准宏帧的下一个子帧被接管。RTL :269 注释自称的"由各自物理帧边界隔开"在这种情况下不成立。

### 1.2 帧调度器允许同一宏帧内各子帧换类型/颜色

`rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v`（V1.12）：

- `calibration_sample_ready_o`（:444-447）：CAL宏帧内只要 `B_CAL_REQ_ACTIVE && !B_CAL_WAVE_PENDING && !B_INFLIGHT` 就可接受新请求，**不检查请求类型/颜色是否与本帧一致**。
- 子帧末拍（`CAL_LAST_LOCAL_TICK`，:820-837）：有 `B_CAL_REQ_PENDING` 时把请求的类型/颜色/原因装入 `B_CAL_FRAME_TYPE/COLOR/REASON`（:830-832），下一子帧按新类型接管。
- `flag_cal_context_due`（:455）：sf≠0 时要求 `B_CAL_REQ_PENDING`。
- 宏帧末拍：`B_CAL_COMPLETE`（:843-844，滚动路径 :883 同样置位）。`o_calibration_frame_complete_event = state_current[B_CAL_COMPLETE]`（:577），即末拍的下一拍出现单拍。

所以"同一物理校准宏帧内 sf k 做AMB、sf k+1 做DCS_R"是帧调度器原生支持的路径——启动搜索的阶段切换常走这条路（见 §3.4、§3.5(c)）。

### 1.3 F-9 的触发链（以实测帧617/618为例）

1. 帧616（NORMAL）mt4760 宏帧边界上重检接管（`flag_enter_amb`，:189，需 `i_frame_safe_boundary`），进入 ST_AMB；AMB请求 mt4762 握手（日志 `SYSMON CALREQ ... frame=616 ... mtick=4762`）。
2. 帧617（CAL）sf0 的 AMB owner 不应答 → mt4503 作废（`SYSMON LOST ... frame=617 mtick=4503 ... age=4502`）→ F-020 撤销 → 重检内层 inflight 清零 → mt4504 重新握手（`CALREQ ... frame=617 ... mtick=4504`）。
3. 帧617末拍：`B_CAL_COMPLETE` → 重检在 ST_AMB 锁存 `flag_stage_frame_complete=1`（:354）。同拍请求 pending 跨帧重挂/F-009 直接起帧 → 帧618为CAL。
4. 帧618 sf0：AMB 结果 lt274 被IDAC消费（`CALACC ... frame=618 ... sf=0 lt=274 ... amb=1`），`i_amb_sequence_done` 在 lt275 单拍 → result_available && frame_available（来自帧617的锁存）→ 当拍推进到 ST_WAIT_DCS_ACCEPT → 次拍 accept → ST_DCS_R → DC_R 请求在 lt278 握手（`CALREQ ... frame=618 ... lt=278`）。
5. 帧618 sf1：DC_R 样本接管（本TB在此处保持ADC忙，`SYSRSP busy start ... frame=618 sf=1 lt=268`）。
6. 同样模式在帧620（DC_R重试）出现：`CALACC frame=620 sf=0 lt=274 dcs=1` → `CALREQ lt=277`（DC_IR请求）→ `CALACC frame=620 sf=1 lt=274 dcs=1`（DC_IR在sf1被消费）。

证据文件：`D:\PPG\verilog\ppg_regression_runs\545abfd_20261009\g2\rtl\ppg_control_top\xsim_regression_20260906\tb_ppg_control_top_adc_anomaly\xsim.log` 第146-163行（帧616~621的 `SYSMON CALREQ/CALACC`、`SYSRSP busy start`、`SYSINFO RECHECK`）。

## 2. 合同对照（问题1）

### 2.1 相关条文（逐字摘录，文件名+节号）

**C16 `contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`**

- §9.4 周期检查序列（流程图）：
  > `-> 第1个9-bit校准帧执行AMB检查或搜索`
  > `-> 第2个9-bit校准帧执行DC_R检查或搜索`
  > `-> 第3个9-bit校准帧执行DC_IR检查或搜索`
- §9.2：请求"随后才可在安全边界启动固定三阶段校准"。§9.3 表：`amb_recheck_pending` "保持至固定三阶段全部完成"。
- §17：「周期重检固定执行AMB、DC_R、DC_IR三个校准阶段」。
- §18 V2修订：「周期重检正常路径固定使用三个连续校准阶段：`AMB -> DC_R -> DC_IR`」。
- §2.4 模拟建立：「数字域committed码只在`frame_safe_boundary`更新；帧内模拟时序必须保证从码值生效到下一次积分之间满足IDAC、参考和PVT建立裕量。」
- §8.3：「候选码必须先形成pending，并在`frame_safe_boundary`成为committed码；随后产生的AMB_CAL或DCS_CAL事务才允许评价该候选。」
- §15.3 AMR-01~14：无一条涉及"阶段与物理宏帧一一对应"或"阶段推进须等本阶段样本所在宏帧结束"。

**C08 `contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`**

- §4.3：「一个400 Hz宏帧具有8个校准子周期容量。该容量是物理上限，不代表每个阶段必然产生8笔ADC事务」。
- §9.6 校准容量和阶段延长：「因此单阶段不能无条件保证在一个物理宏帧内完成。冻结行为为：当前阶段未完成时继续占用后续校准宏帧；保持相同AMB/DC_R/DC_IR阶段身份；……当前阶段成功后才进入下一阶段」。
- §12.3 校准物理宏帧完成：「`o_calibration_frame_complete_event`表示当前400 Hz物理宏帧的校准调度窗口已经结束，不表示当前AMB/DC阶段必然成功。阶段控制同时等待：`物理校准宏帧结束事实 && IDAC阶段结果成功/失败事实`。若阶段需要延长，后续校准宏帧继续产生各自的物理完成事件，阶段身份保持不变，直到IDAC结果闭合。」
- §8.2.2：「`subframe_tick = 385 = 625 - 240`」；「IDAC候选在某个安全脉冲提交后，只允许用于该脉冲之后的下一笔合格SAR9校准波形上下文」。§8.2.5：该边界用于「为下一SAR9校准事务建立码值稳定时间」。
- §9.7 三阶段顺序：「AMB -> DC_R -> DC_IR -> 恢复NORMAL」。
- §15：「校准请求valid只表示AMI需要下一笔样本……每笔SAR9校准ADC事务都必须对应一笔真实请求握手和一个匹配结果。」

**C17 `contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md`**

- §8.3/§8.4/§9/§10：只规定序列握手、二分搜索"候选先形成pending，安全提交后才请求观察样本"、提交条件 `pending_valid && i_frame_safe_boundary && ...`；**全文无"校准帧/宏帧/阶段与帧对应"字样**（`grep 校准帧|物理帧|宏帧|frame_complete` 零命中）。
- 附带发现（与F-9无关，仅记录）：C17 §8.4 末句「AMB码未实际改变时不得产生`o_dcs_revalidate_request`」与 C16 §9.6/§18 及 RTL `ST_AMB_RECHECK` 窗口内→`ST_DCS_REVALIDATE_WAIT`（`ppg_idac_code_controller.v` :792-796）相矛盾。RTL 跟 C16。交B。

**测试合同 `contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`（RRC/SID 验收ID的定义处）**

- §9.3 第8组 PERIODIC-RECHECK-RECOVERY：「…then execute AMB -> DC_R -> DC_IR.」（只规定顺序）
- §9.4.3 RRC-05：「The active sequence is exactly AMB, DC_R, DC_IR. Every accepted periodic-recheck calibration conversion completes only through its dedicated Q3 end, …」
- RRC-07：「An actual AMB, DC_R, or DC_IR change occurs only at its safe boundary, increments only its epoch, and is used by later waveform/result snapshots.」
- RRC-08：「From accept through successful or failed sequence termination, formal NORMAL output remains inhibited…」
- 其余 RRC-01~04、06、09~12 均不涉及阶段/帧对应。
- 矩阵 `PPG_CONTRACT_CLOSURE_MATRIX.md` :2168 只登记 `i_calibration_frame_complete_event` 的连接（Producer/Consumer），:1903 同；别名表 :191-202 的 RRC 锚点无一指向 `flag_stage_frame_complete`。
- 其他提到"三帧"的只是端口注释式描述：C18 PWI 合同 `PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` :284 `o_calibration_frame_start`「三个校准帧各自开始单拍」、:317 `o_amb_recheck_busy`「三帧校准序列占用状态」、PWI-05「三帧结束后……」。

### 2.2 判定

- **没有违反明文**，但**合同内部口径不一致、未写到F-9这种情形**：
  1. C16 §9.4 字面是"第1/2/3个9-bit校准帧"，读作"每阶段一个物理校准帧"；但 C08 §9.6 已明文冻结"单阶段可延长占用后续校准宏帧"，C08 §12.3 把推进条件定为两件**事实**的合取（"物理校准宏帧结束事实 && IDAC阶段结果事实"），没有要求"结束的那个宏帧"必须晚于本阶段最后一笔样本。RTL :186/:354 的"任意先后、锁存任一次"正是 §12.3 的直译。
  2. 因此 F-9 行为 = **合同未写到**（C16 §9.4 的"帧"按 C08 §9.6/§12.3 只能理解为"阶段"，否则 C08 §9.6 的阶段延长本身就与 C16 §9.4 冲突）。不属于"明确允许"，因为没有任何条文写"下一阶段可在上一阶段所在宏帧的后续子帧开始"。
  3. 与 RTL 自身注释不一致：`ppg_amb_recheck_scheduler.v` :269「强制三个校准阶段由各自物理帧边界隔开」、:215「三个物理校准帧分别产生一次开始事件」。这两句注释在 F-9 路径和"阶段跨帧延长"路径下都不成立。
- 关键：C08 §9.6 的"阶段延长"本身就会产生与 F-9 完全相同的形态（见 §4.2），所以 F-9 不是"重试才有"的特殊形态，而是"本阶段跨过任何一个校准宏帧末拍"的通用后果。

## 3. 功能后果（问题2，最重要）

### 3.1 IDAC码只在哪些边界提交（`idac_code_safe_boundary_o` 的组成）

`ppg_400hz_frame_calibration_scheduler.v` :483：
`idac_code_safe_boundary_o = startup_idac_safe_boundary_o || macro_frame_safe_boundary_o || flag_calibration_boundary_o || flag_idle_idac_safe_boundary`

| 分量 | 行 | 何时 |
|---|---|---|
| `startup_idac_safe_boundary_o` | :479 | START后一次，无帧活动、全链空闲 |
| `macro_frame_safe_boundary_o` | :480 | 任何活动宏帧（NORMAL或CAL）`macro_tick == 4760`（`MACRO_SAFE_TICK = 5000-240`，:232） |
| `flag_calibration_boundary_o` | :481 | CAL宏帧内每个子帧 `local_tick == 385`（`CAL_IDAC_LOCAL_TICK`，:237）；sf7 的385即 mt4760，与宏帧边界同拍（C08 §8.2.3） |
| `flag_idle_idac_safe_boundary`（L-3） | :482 | 仅启动搜索未完成、调度器空闲、本拍不开帧（`!i_normal_measurement_eligible && !flag_frame_start_eligible ...`） |

IDAC侧：`flag_amb_commit`/`flag_dcs_r_commit`/`flag_dcs_ir_commit`（`ppg_idac_code_controller.v` :584-595）= `pending_valid && i_frame_safe_boundary && run && !stop && !abort && 代际匹配`。

校准样本用码的快照点：校准波形上下文 fire（子帧 local tick 0）时取 `i_amb_code` 与同色 DC committed 码（帧调度器 :686-689；`flag_cal_context_due` :455 只在 `calibration_local_tick_o == 0`）。因此一个在 385 提交的码，最早被下一子帧 lt0 的波形使用，间隔 625-385 = **240 拍（120 µs）**；Q3 中心在 lt266，提交到 Q3 为 **506 拍**。

### 3.2 合同对建立时间的规定

- C16 §2.4：只给定性要求（"帧内模拟时序必须保证从码值生效到下一次积分之间满足IDAC、参考和PVT建立裕量"）。
- C08 §8.2.2：385 = 625 − 240，§8.2.5"为下一SAR9校准事务建立码值稳定时间"；§8.1 宏帧边界 4760 = 5000 − 240。
- `PPG_ADC_IDAC_INTEGRATION_SPEC.md` :125：「码值只在帧安全边界更新，并由时序控制器在下一次积分前保证IDAC、参考和PVT裕量所需建立时间」。
- 合同体系中唯一的定量建立预算就是"提交点到下一波形接管 240 拍"。仓库内没有模拟侧给出的更长建立时间要求（全仓 `grep settle|建立时间|稳定时间` 只命中上述条文与禁用 `settle_sample_count` 的条文）。

### 3.3 阶段结束时上一阶段的码是否已提交（静态，确定）

IDAC 控制器所有"阶段成功"出口都只能由一笔**合格样本**触发，而合格样本要求样本快照等于当前 committed 码与 epoch：

- `flag_amb_sample_qualified`（:469-475）要求 `i_search_amb_code_snapshot == amb_code_current && i_search_amb_code_epoch == amb_epoch_current`；
- `flag_dcs_sample_qualified`（:476-487）同时要求 AMB 与本色 DC 的快照和 epoch 都等于当前 committed 值。
- AMB阶段成功：`ST_AMB_RECHECK` 窗口内（:792-797，上下文 :994-998 只置 `CTX_AMB_SEQUENCE_DONE_BIT`，不形成 pending），或重搜 `ST_AMB_WAIT` 窗口内（FSM :730-740，上下文 :909-916，"保持已经提交并被本样本观察的当前候选"）。
- DC_R阶段成功：`ST_DCS_REVALIDATE_R` 窗口内（:810-814）或 `ST_DCS_R_WAIT` 窗口内（:756-760 → `ST_DCS_REVALIDATE_IR`）；DC_IR 同理（FSM :776-780、:819-823，上下文 :968-975、:1046-1051）。
- 搜索中每个候选都先 `*_APPLY` 等 `flag_*_commit` 才转 `*_WAIT` 请求样本（:725-729、:751-755、:771-775），即 C16 §8.3/C17 §9 第2条"候选先形成pending，安全提交后才请求观察样本"。
- 重检启动前提 `flag_amb_check_start_allowed`（:456-462）要求三路 pending 全为0；AMB实际改码时清 DC pending（:856-870，`CTX_AMB_CHANGED_BIT` :864）。

推论：**阶段结束的那一拍，本阶段的最终码早已是 committed 码，并且就是本阶段最后一笔合格样本所用的码**；阶段结束不会留下待提交的 pending（下一阶段若需搜索，它的第一个候选要等下一个 385/4760 边界，再在其后的子帧取样）。F-9 改变的只是"下一阶段第一笔样本落在哪个子帧"，不改变"所用的码何时提交"。

- 下一阶段第一笔样本用的是：AMB = AMB 阶段最终 committed 码；DC_R/DC_IR = 重检开始前的 committed 码（检查路径）或本阶段刚在 385/4760 提交的候选（搜索路径，与启动搜索相同的 240 拍预算）。
- F-9 路径下，下一阶段第一笔样本（sf k+1 lt0）距离上一阶段最后一次提交至少 625 + 240 = 865 拍（上一阶段最后一次提交至迟在 sf k−1 的 385，或更早）。实测见 §3.4。

### 3.4 与启动搜索比较：同一宏帧内相邻子帧换阶段是既有常态

- 启动搜索的请求直接来自 IDAC 的 `o_amb_sample_request`/`o_dcs_sample_request`（AMI `flag_startup_request_source` :973-975，`calibration_sample_valid_o` 仲裁 :1449-1463），**没有任何"阶段帧完成"门控**。AMB 窗口内 → `ST_DCS_R_APPLY`（FSM :740，上下文 :917-922 形成 DC_R 首候选 pending）→ 本子帧 385 提交 DC_R 首候选 → 下一子帧取 DC_R 样本。
- 帧调度器在子帧末拍按新请求类型/颜色装载下一子帧（:827-833），无"同帧同类型"约束。
- 所以"sf k 做 AMB、sf k+1 做 DC_R、sf k+2 做 DC_IR"是启动搜索的设计常态；F-9 只是让周期重检在少数情况下也走同样的物理节拍。

### 3.5 探针实测（xsim，Vivado 2022.2）

探针：`W/probe/f9_mon.sv`（被动监视器，作为第二个 elaboration top，只做层次化读取，不驱动任何信号）；`W/probe/run_probe.sh <短名> <TB顶层> <filelist>`，各自在 `W/probe/run_<短名>/` 下编译运行，RTL/TB 全部取自 `W/src`（7a8eabf 导出），不改仓库。监视器输出前缀 `F9MON`：
`RCK`（重检状态转移，含 `LATCHED_ADV`=推进靠的是更早宏帧的锁存帧完成、当拍无帧完成事件）、`CODE`（IDAC 实际改码的提交拍）、`CALFIRE`（校准波形接管拍及码快照、距最近一次相关码提交的拍数 settle）、`FIRST_FIRE_AFTER_LATCHED_ADV`、`XSTAGE_SAME_FRAME`（同一宏帧内相邻校准样本换类型/颜色）、`SHORT_SETTLE`（settle<240）、`SUMMARY`。

**(a) adc_anomaly（`W/probe/run_anomaly/xsim.log`）复现 F-9**：
- 第232行：`F9MON RCK ... AMB->WAIT_DCSACC frame=618 mode=2 mt=275 sf=0 lt=275 fc_now=0 fc_latched=1 res=1 LATCHED_ADV=1 ... pend(a/r/i)=000 codes(a/r/i)=64/80/96`
- 第236行：`F9MON FIRST_FIRE_AFTER_LATCHED_ADV ... (adv_cyc=3287117, +350) frame=618 sf=1 lt=0 type=1 col=0 snap_amb=64 snap_dc=80 ... pend(a/r/i)=000`
- 第249/252行：帧620 `DCS_R->DCS_IR ... lt=275 LATCHED_ADV=1`，随后 `FIRST_FIRE_AFTER_LATCHED_ADV ... frame=620 sf=1 lt=0 type=1 col=1 snap_amb=64 snap_dc=96 ... pend=000`
- 推进时三路 pending 全0；下一阶段首个波形在推进后350拍（sf1 lt0）接管，快照即当前 committed 码。本TB重检全程码不变（`codes=64/80/96`），所以此处 settle 是"自启动以来"，只能证明机理，不能证明改码情形——改码情形见 (b)。
- 对照：同一运行中正常路径的阶段推进都在 CAL 帧末拍之后一拍（`fc_now=1`，`LATCHED_ADV=0`）。

**(b) startup_idac_calibration（`W/probe/run_startup/xsim.log`）**：
- `F9MON SUMMARY cal_fires=33 ... min_settle_nonstartup=240 short_settle_fires=2`：所有由 385/4760 边界提交的候选，到使用它的下一个校准波形接管，间隔恰为 240 拍（设计预算）。
- 两条 `SHORT_SETTLE`（settle=16 与 4，`kind1`=START 启动边界）：见 §7 附带观察，与 F-9 无关。
- 同一TB中各阶段转换恰好落在宏帧边界（搜索正好用满8个子帧），故 `xstage_same_frame=0`；但 adc_anomaly 与 periodic 两个运行里的启动搜索都出现了同帧换阶段（下条）。

**(c) 启动搜索同帧换阶段（`W/probe/run_anomaly/xsim.log` 前段）**：
- `F9MON XSTAGE_SAME_FRAME ... frame=0 sf=2 prev(type/col/...)=0/0/1250 now(type/col)=1/0 reason=0 settle_amb=1254 settle_dc=240`（AMB→DC_R）
- `F9MON XSTAGE_SAME_FRAME ... frame=0 sf=3 prev=1/0/625 now=1/1 reason=0 ... settle_dc=240`（DC_R→DC_IR，相邻子帧）
- 即启动搜索（reason=0）在同一宏帧 sf1→sf2→sf3 依次做 AMB→DC_R→DC_IR，新阶段首个候选在上一子帧 385 提交、240 拍后接管。这与 F-9 下重检在 sf0→sf1 换阶段是同一物理节拍。
- （注：`frame=0 sf=0 prev .../305` 一类条目是 RUN 重启后帧号归零造成的跨 RUN 误报，不计。）

**(d) periodic_recheck_recovery（`W/probe/run_periodic/xsim.log`）——无ADC异常的正常运行也走 F-9 形态，且带改码**：
- 第一轮重检（帧616~622，AMB/DC_R/DC_IR 均首样本窗口内）：每次推进都在 CAL 帧末拍后一拍（第153/158/162行 `fc_now=1 LATCHED_ADV=0`），且推进时下一帧已经按 F-009 直接起为 NORMAL（`mode=1 mt=0`），阶段间夹 NORMAL 帧——与 OLR 报告 §4.3 一致。
- 第二轮重检（RRC-07：AMB 越界确认后重搜 64→180）：
  - 帧1017 sf0~sf7：8笔 AMB 检查样本均越界（第173-188行 `QSAMPLE ... inwin=0`），sf7 后转重搜，首候选在 mt4760 提交（第189行 `CODE ... mt=4760 sf=7 lt=385 AMB 64->124`）。帧1017 末拍 `CALCOMPLETE ... rck=AMB latched_before=0 result_avail=0`（第190行）→ 锁存。
  - 帧1018 sf0~sf6：二分候选逐子帧 385 提交、下一子帧 lt0 接管，settle 恒为 240（第191-209行）；sf6 lt274 样本窗口内（第210行 `inwin=1 snap=180`）。
  - 第211行：`AMB->WAIT_DCSACC frame=1018 mode=2 mt=4025 sf=6 lt=275 fc_now=0 fc_latched=1 res=1 LATCHED_ADV=1 ... pend(a/r/i)=000 codes(a/r/i)=180/80/96`
  - 第213/214行：`XSTAGE_SAME_FRAME frame=1018 sf=7 prev=0/0 now=1/0 reason=1 settle_amb=865` 与 `FIRST_FIRE_AFTER_LATCHED_ADV ... frame=1018 sf=7 lt=0 type=1 col=0 snap_amb=180 snap_dc=80 settle_amb=865 ... pend=000`
  - 即：DC_R 阶段第一笔样本与 AMB 阶段最后几笔同在物理帧1018；它用的 AMB=180 是 sf5 的385（mt3510，第208行）提交、并已被 sf6 的 AMB 样本验证过的码，提交到 DC_R 波形接管 865 拍，无任何 pending。
- `F9MON SUMMARY ... rck_stage_adv=4 rck_adv_latched=1 ... min_settle_after_latched=865 ... min_settle_nonstartup=240`。

**(e) 探针无干扰**：三个运行的 `^PASS/^FAIL/TB_PASS/status=` 判定行与 `D:\PPG\verilog\ppg_regression_runs\545abfd_20261009` 对应 xsim.log 逐行相同（periodic 70/70、adc_anomaly 40/40、startup 83/83，md5 一致；545abfd 与 7a8eabf 的 RTL 差异仅 SSW 注释）。

### 3.6 功能结论（问题2）

1. 下一阶段在重试帧（或延长帧）sf k+1 接管取样时，上一阶段算出的码**早已在安全边界提交**，且正是上一阶段最后一笔合格样本观察过的码；推进时三路 pending 全0（静态 §3.3；实测 4 次 `LATCHED_ADV=1` 全部 `pend=000`）。
2. 下一阶段用的是"新码"（上一阶段最终 committed 码），不是旧码，也不是帧中途刚提交、未经建立的码：实测最短 865 拍（periodic 帧1018），理论下限 625+240=865 拍（上一阶段最终码最晚在其最后一个样本的前一子帧 385 提交）。这比设计对每个搜索步、每个启动阶段切换都在用的 240 拍预算更宽。
3. 下一阶段自己的首个搜索候选（若需搜索）仍按"pending→385/4760 提交→下一子帧取样"走，240 拍，与启动搜索完全相同（periodic 帧1020 第236-251行 `settle_dc=240`）。
4. 下一阶段 DC 检查所用 DC 码不受上一阶段影响：DC_R/DC_IR 颜色槽各用本色 DC 码（帧调度器 :687、:505），DC_IR 采样不使用 DC_R 码。
5. 因此 F-9 不造成"用未生效或刚生效未稳定的码去测"，**功能上无害**；它也不改变 LED/偏置切换节奏——启动搜索本来就在相邻子帧做 AMB(LED全灭)→DC_R(RED亮)→DC_IR(IR亮)（§3.5(c)）。

## 4. 范围（问题3）

### 4.1 启动搜索

- 启动搜索**没有** F-9 这个机制：启动请求由 AMI 直接从 IDAC 保持型请求生成（`flag_startup_request_source`，AMI :973），没有"阶段结果 && 阶段帧完成"门控，重检调度器不参与（启动期间 `ST_MONITOR`）。
- 但启动搜索的**物理形态与 F-9 相同且是设计常态**：阶段在任意子帧结束，下一阶段首候选在本子帧 385 提交、下一子帧接管。实测：adc_anomaly 运行中启动搜索同帧换阶段（`delta=625`/`1250`、`reason=0`）共十余次，新阶段首样本 `settle_dc=240`；periodic 运行启动段2次（`frame=1 sf=7 ... settle_dc=240`）。
- 结论：F-9 只存在于周期重检。

### 4.2 周期重检中触发"借用更早宏帧的帧完成"推进的条件

统一条件：**某阶段期间已经出现过一次校准宏帧完成事件，而阶段结果在其后某个 CAL 帧的中途才出现**。具体路径：

| 路径 | 是否需要ADC异常 | 证据 | 下一阶段是否与本阶段共用物理CAL帧 |
|---|---|---|---|
| (a) T-lost 作废后跨宏帧重试（方案甲4500，F-020 重挂） | 是（DONE丢失） | 实测：adc_anomaly 帧618、帧620（§3.5(a)） | 是（重试帧 sf1） |
| (b) SID-05 截止撤销后跨宏帧重试 | 是（ADC长时间不idle或SSW不ready，需连续错过到sf7） | 静态：截止在 sf k<7 时重握手赶得上 sf k+1，不跨帧，不触发；只有到 sf7 仍错过才跨帧，与(a)同形 | 是 |
| (c) 迟到完成跨宏帧末拍（L-3 合法迟到） | 是（ADC迟到） | 静态：本阶段最后一笔 owner 在帧N在途→帧N末锁存→L-1 不重挂→结果在帧N+1（NORMAL）被消费→当拍推进→下一阶段请求在 NORMAL 帧握手→下一CAL帧 | **否**（结果到达时所在帧已是 NORMAL，下一阶段从新 CAL 帧 sf0 开始；此时借用锁存是正确语义） |
| (d) 同阶段多样本跨宏帧末拍（确认计数+二分重搜，C08 §9.6 "阶段延长"） | **否** | 实测：periodic 帧1017→1018，AMB 重搜在 1018 sf6 结束，DC_R 在 1018 sf7 接管（§3.5(d)） | 是 |
| (e) 首样本窗口内、单样本阶段、无异常 | 否 | 实测：两个运行的第一轮重检均在 CAL 末拍后推进 | 否 |

- 路径(d)的可达性很宽：每阶段从新 CAL 帧 sf0 开始，确认 N 笔后才开始二分；8-bit 二分最多 8 个候选，每候选一个子帧。只要"N + 收敛所需候选数 > 8"，阶段就跨宏帧末拍，结束于后一帧中途。周期重检真正调码（AMR-08/09、RRC-07）的情形基本都会走到这里。
- 所以**正常运行可以到达**，而且现有永久回归 `tb_ppg_control_top_periodic_recheck_recovery`（RRC-07 段）自建立以来每次都在走这条路径并 PASS；这不是 owner 生命周期轮新增的，也不只靠 ADC 异常触发。
- 附带：路径(a)(b)(d) 都会产生 sf≥1 起动的重检校准 owner。即便修掉 F-9，路径(d)中的同阶段多样本也照样产生 sf≥1 owner，所以 OLR 报告 §4.3 第5条/§7.1(b) 所说的"校准owner在途跨入NORMAL帧"在修复后仍可达（经 (d) + 丢DONE），修 F-9 并不能消除这一类情形。

## 5. 候选修法（问题4）

先说约束：重检调度器只看得到"CAL宏帧完成事件"，看不到 CAL 帧开始、波形接管或 owner 提交。下面两种"看似最小"的改法都有死锁：

- ✗ 在样本被消费（`flag_matching_sample_accepted`，:201）时清 `flag_stage_frame_complete`：路径 4.2(c) 中最后一笔结果在帧N+1（NORMAL）才被消费，清掉帧N的锁存后，阶段已无请求、不会再有 CAL 帧，`ST_AMB`/`ST_DCS_IR` 永远等不到帧完成 → 重检永久 busy、正式输出永久被抑制。
- ✗ 在 F-020 撤销（`i_calibration_request_withdraw_event`，:370）时清锁存或"布防到重试样本被消费"：撤销发生在帧末之前（mt4503），清了也没用；布防方案在"重试又因 SID-05 被推到 sf7、结果迟到进 NORMAL 帧"时同样会丢掉唯一的帧完成而死锁。
- ✗ 在请求握手（`flag_calibration_transfer`）时清锁存：F-9 的顺序是"握手(617 mt4504)→帧完成(617末)→接管(618 sf0)→结果"，锁存发生在握手之后，清不到。

### 修法1（精确语义，需加端口）
- 重检调度器新增输入 `i_calibration_frame_active`（帧调度器已有 `o_calibration_frame_active`，:582；目前只接 SSW，control_top :969/:1015），经 control_top→AMI→PWI 透传。
- 改 :186 为：`flag_stage_frame_available = i_calibration_frame_complete_event || (flag_stage_frame_complete && !i_calibration_frame_active)`。
- 语义："结果出来时若 CAL 帧仍在运行，就等这一帧结束；若已不在 CAL 帧（NORMAL/空闲），说明样本所在的帧早已结束，用阶段内锁存即可"。覆盖 4.2(a)(b)(d)，(c)(e) 行为不变，不引入死锁（CAL 帧总会在 5000 拍内结束；abort 会同时取消重检）。
- 与 F-009（V1.12 末拍直接起帧）：推进点回到 CAL 末拍后一拍，此时下一阶段请求尚未握手，F-009 按 `flag_next_frame_inputs_eligible` 直接起 NORMAL 帧，下一阶段在其后的 CAL 帧——即今天首样本路径的节奏（阶段间夹一个 NORMAL 帧），F-009 逻辑本身不需改。
- 与 L-1：不改帧调度器；4.2(d) 的同阶段 sf≥1 owner 仍存在，L-1 仍然必要；"在途 owner 跨入 NORMAL 帧"仍可达。
- 与 F-020：撤销/重发逻辑不变，只是重试样本所在帧结束后才推进。
- 代价：3个模块端口+control_top 连线；合同 C16 §9.3 端口表（"唯一规范"）、C18 PWI 端口、C10 AMI 端口、control_top 连接合同、矩阵 :2168 一带与别名表都要改。每次跨帧延长或重试多耗约一个 CAL 帧剩余子帧 + 一个 NORMAL 帧（≤约 2.5~5 ms），对周期 10.24 s 的重检可忽略。

### 修法2（不加端口，改变正常路径节奏）
- 只用已有输入 `i_frame_safe_boundary`（PWI :1004 原样转接，AMI :2762 接的是 `i_macro_frame_safe_boundary`，即 mt4760）：把"阶段帧事实"改为"**结果出现之后**观察到的第一个 CAL 帧完成或宏帧安全边界"，即锁存只在 `flag_stage_result_available` 为1时置位，结果出现前的帧完成不计。
- 效果：结果在 CAL 帧中途出现 → 在本帧 mt4760 推进 → 下一阶段请求 mt≈4762 握手 → mt4999 由 `flag_calibration_rollover`（帧调度器 :487-492）直接滚入下一 CAL 帧 sf0，**不再夹 NORMAL 帧**；结果在 NORMAL 帧出现 → 在该帧 4760 推进。NORMAL 帧在重检期间持续运行（AMI `o_normal_measurement_eligible` :1190 不含重检项），不会无边界可等。
- 代价：连"首样本路径"的节奏也变了（每次重检少2个 NORMAL 填充帧），所有带重检的系统 TB 都要重新基线；宏帧安全边界多了一个用途，需补 C08 §8.1 用途列表与 C16 §9.4。

### 修法3（推荐：不改 RTL，合同写明）
- C16 §9.4 流程图中的"第1/2/3个9-bit校准帧"改为"第1/2/3个校准阶段"，并写明：每阶段从一个新的物理校准宏帧开始；阶段跨宏帧延长（C08 §9.6）或跨宏帧重试后，阶段在后一帧中途结束时，下一阶段可在同一物理校准宏帧的后续子帧开始；下一阶段首样本所用码均为上一阶段最终 committed 码，满足 §2.4 建立要求。
- C08 §12.3 补一句："物理校准宏帧结束事实"指本阶段期间出现过的任一 `o_calibration_frame_complete_event`，不要求晚于本阶段最后一笔样本。
- RTL 只改注释（`ppg_amb_recheck_scheduler.v` :148、:215、:269 三处"各自物理帧/三个物理校准帧"的说法），不改逻辑。
- `tb_ppg_control_top_adc_anomaly.v` :1741-1746 的注释已正确描述 F-9，可保留。

### 修法对系统TB的影响（如选修法1或2）
- `tb_ppg_control_top_adc_anomaly`：SYS-CAL-LOST-RETRY 的 `done_frame`、重试帧号会变；**SYS-CAL-BUSY-NORMAL 依赖 F-9 制造"重试帧 sf1 的第3笔重检校准"**（TB :1745-1746 注释、日志 `busy start frame=618 sf=1`）。修后第3笔变成新 CAL 帧 sf0 的 DC_R 首样本；由于该用例让 ADC 一直忙到下一帧 tick 2000，owner 仍会在途跨入下一帧（作废需 idle），预计仍可构造出"跨入 NORMAL 帧"，但帧号、年龄（约 6700 拍，仍 <9000）都会变，必须重跑并可能改检查条件与注释。
- `tb_ppg_control_top_periodic_recheck_recovery`：RRC-07 段 DC_R 将从帧1020（而非1018 sf7）开始；RRC-07/11 判据本身不依赖帧号，预计仍过，但需重跑确认等待上限（TB 内 12000 拍一类 guard）。
- `tb_ppg_control_top_startup_idac_calibration`：无重检，不受影响（探针 `rck_stage_adv=0`）。
- 其余带重检的 TB（long_10_cycles、chip 顶层、lifecycle_fault_adc_anomaly 等）需全套回归比对；修法2影响面最大。

## 6. 结论分级（问题5）

**分级：B（合同写明即可；不需在 B 合同批次前改 RTL）。**

理由：
1. **不违反明文**：C08 §12.3 把推进条件写成"物理校准宏帧结束事实 && IDAC阶段结果事实"两件事实的合取，C08 §9.6 冻结了"阶段可延长占用后续校准宏帧"；RTL :186/:354 正是其直译。与之冲突的只有 C16 §9.4 流程图的"第N个9-bit校准帧"措辞和 RTL 自己的注释（:148/:215/:269）。属于"合同未写到 + 措辞不一致"。
2. **功能无害**：阶段只能由"快照=committed码"的合格样本结束，结束时无 pending；下一阶段首样本所用码在其接管前至少 865 拍已提交（实测 865，periodic 帧1018），宽于设计对每个搜索步都在用的 240 拍预算；三路 pending 在全部 4 次借锁存推进时均为0。启动搜索本来就在相邻子帧换阶段。
3. **既有且常态**：正常运行（无 ADC 异常）中只要阶段需要重搜而跨宏帧末拍就会出现（periodic TB RRC-07 段每次回归都走），owner 生命周期轮只是多了 (a) 一条触发路径。
4. **修 RTL 的收益与代价不对称**：精确修法需要新端口贯穿 3 个模块与 4 份以上合同（修法1），或改变所有重检 TB 的节奏（修法2）；且最小改法都有死锁陷阱（§5 开头）。修后 sf≥1 重检 owner 仍经 4.2(d) 存在，不能顺带消除 §7.1(b) 的情形。

不评 A：没有功能错误、没有错绑、没有停滞（adc_anomaly 的 SYS-MON-BIND/LIVE 与 periodic 全 PASS，探针运行判定与基线逐行一致）。
不评 C：F-9 本身从不把建立时间压到 240 拍以下，所以不需要为 F-9 单独做模拟确认；"240 拍是否够"是全系统的既有前提（每个搜索步都依赖它），应在收尾计划里统一请模拟侧签核，不是 F-9 的判据。

**交B（合同批次）**：按修法3改 C16 §9.4（必要时同步 §17/§18 措辞）、C08 §12.3；记录 RTL 注释 :148/:215/:269 待改（只改注释，可随下一轮 RTL 注释修订）。若用户坚持"每阶段独占物理校准帧"的语义，则改走修法1，并按 §5 末清单重跑系统 TB。

## 7. 附带观察（与 F-9 无关，仅记录，建议入收尾计划）

1. **START 启动边界之后第一帧几乎立即接管（疑似建立不足，需模拟侧确认）**：探针 `SHORT_SETTLE` 全部来自 `kind1`（`startup_idac_safe_boundary_o`，帧调度器 :479）。
   - 自动搜索：启动边界提交 AMB 首候选后 4 拍（个别 16 拍）即是首个 CAL 帧 sf0 lt0 波形接管（`W/probe/run_startup/xsim.log`、`run_anomaly/xsim.log` 中 `F9MON SHORT_SETTLE ... settle_amb=4(kind1)`，adc_anomaly 运行共 9 次）；提交到 Q3（lt266）约 270 拍，而其余所有提交到接管都是 ≥240 拍（提交到 Q3 ≥506 拍）。
   - MANUAL：`run_startup/xsim.log` 第18-23行，三路 manual 码在 t=9.25 µs 提交，首个 NORMAL 帧在 t=10.25 µs（2拍后）开始。
   - C08 §8.3 只规定启动边界的出现条件，没有规定其后到首帧的间隔；C16 §2.4 要求"码值生效到下一次积分之间满足建立裕量"。这是否足够取决于模拟侧建立时间，属既有设计问题，建议列入收尾计划请模拟侧确认，或让启动边界后至少等 240 拍再允许起帧。
2. C17 §8.4 末句「AMB码未实际改变时不得产生`o_dcs_revalidate_request`」与 C16 §9.6/§18 及 RTL（`ppg_idac_code_controller.v` :792-796 窗口内也进 `ST_DCS_REVALIDATE_WAIT`）相反；RTL 与 RRC-06 证据跟 C16。交B改 C17。
3. 测试合同 SID-04「Every evaluated candidate uses eight physical SAR9 subframes」与 RTL"每个候选只取一笔样本、相邻候选相隔一个子帧"（探针 CODE/CALFIRE 序列）字面不一致，疑似措辞问题（TB 的 SID-04 PASS 行检查的是"候选相隔625拍"）。交B核对措辞。

## 8. 未覆盖 / 不确定

- 4.2(b) SID-05 截止跨帧重试、4.2(c) 迟到完成跨帧：只做了静态推导，未动态构造。需要的实测：在周期重检阶段内让 ADC 不 idle 覆盖 sf0~sf7 的 lt248（b），或让最后一笔 owner 的 DONE 合法迟到跨过宏帧末拍（c），用本探针看 `LATCHED_ADV` 与下一阶段接管帧。
- 改码情形只覆盖了 AMB 重搜后进入 DC_R（periodic 帧1018）；"DC_R 重搜成功后在同帧进入 DC_IR"未实测（periodic 的 DC_R 段是耗尽失败）。静态上 DC_IR 不使用 DC_R 码，结论不受影响。
- 修法1/2 未实现、未仿真；§5 对 TB 影响是推断。
- 240 拍预算本身是否满足模拟 IDAC/参考/PVT 建立，仓库内无模拟侧数据，未核实（这是全系统前提，非 F-9 专属）。
- 只探了 adc_anomaly、periodic_recheck_recovery、startup_idac_calibration 三个 control_top TB；long_10_cycles、chip 顶层等未探。
- 外部机器上的 ABCD 证据 CSV 未查阅。

## 9. 产物

- 本报告：`W/REVIEW_F9.md`
- 探针：`W/probe/f9_mon.sv`、`W/probe/run_probe.sh`
- 运行：`W/probe/run_startup/`、`W/probe/run_anomaly/`、`W/probe/run_periodic/`（各含 `xsim.log`、`files.f`、`done.txt`）
- 源码导出：`W/src/`（`git -c core.autocrlf=false archive 7a8eabf`）
