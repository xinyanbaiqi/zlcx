# PPG 400 Hz帧与校准事务调度器接口合同

> V1.13修订日期：2026-10-09。B合同合并批次（`verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-001~015，按基线`7a8eabf`调度器RTL V1.12改写，符号锚点格式为“文件 + 符号（§节）”）：① §4.2新增§4.2.1宏帧末拍衔接：F-009末拍直接起帧（`flag_frame_restart`、`flag_next_frame_inputs_eligible`）、F-010校准滚动受生命周期门控（`flag_calibration_rollover`）、起帧快照在末拍采样，以及FSC-03例外C；② §8.2新增§8.2.3启动搜索空闲边界（L-3，`flag_idle_idac_safe_boundary`）；③ §9.6、§10.4写明宏帧末不重挂在途owner（L-1）；④ §10.3写明截止当拍可提交、越过截止只收尾（L-4，`flag_candidate_expired`）；⑤ §10.4新增AMI超时作废释放（R3，`flag_owner_lost_match`），作废置失败的是当前宏帧（F-7）；⑥ §12.3写明“物理校准宏帧结束事实”的含义（F-9）；⑦ §13.3、§13.7端口表新增`i_idac_boundary_request`、`i_adc_transaction_lost_event`；⑧ §16.2写明调度器sticky与AMI历史诊断两套START规则；§16.3写明STOP不等帧结束；§16.5写明诊断清除门控与已知限制（重检期间owner截止sticky）；⑨ §18 FSC-03/17/19/38/46/49/50/54原行补充；§19证据状态声明订正。不改变任何时间点、端口位宽或既有编号含义。
> V1.12修订日期：2026-10-04。合同补记批次3第二阶段：按任务C的结论关闭第10.3节的tick-248开放观察项。scheduler RTL V1.9（2026-10-01）把`o_cal_owner_deadline_event`改为`flag_cal_owner_deadline && !adc_owner_commit_event_o`（`ppg_400hz_frame_calibration_scheduler.v:569`），与内部截止分支`if(adc_owner_commit_event_o == 1'b0)`（`:738`）同一门控：截止事件只在截止点到达而owner仍未提交时发出，local tick 248当拍提交属于按时提交，不回报截止。本次相应修改：第10.3节两段（保留原文于删除线中）、第13.9节`o_cal_owner_deadline_event`行、FSC-50原行补充（不新开ID）。证据：`verification_reports/TASKC_TICK248_P2S_20261001.md`第1节（A/B仿真确认缺陷，tick 247与真正错过截止两组对照逐事件不变）、调度器单元TB V1.7新增检查（TB内编号FSC-60/61/62，本表未登记，见同步记录）、全套19-TB回归19/19 PASS。合同同步记录见`verification_reports/CONTRACT_SYNC_BATCH3_PHASE2_20261004.md`。
> V1.11修订日期：2026-10-01。合同补记批次3：第10.4节的`owner_release`公式补上RTL中已有的RUN代际匹配项`i_run_generation == current_owner_run_generation`（`ppg_400hz_frame_calibration_scheduler.v:461`，`flag_completion_match`）。该规则本身早已由第15.1节规定（陈旧代际不得匹配、释放或重新绑定owner）；本次只让第10.4节公式与第15.1节及RTL一致，并加交叉引用，不新增规则。不涉及`o_cal_owner_deadline_event`的相关描述。合同同步记录见`verification_reports/CONTRACT_SYNC_BATCH3_20261001.md`。
> V1.10修订日期：2026-09-30。合同补记批次2：V1.8修订记录已经描述、但正式端口表一直缺失的输入`i_owner_q3_window_closed`（`ppg_400hz_frame_calibration_scheduler.v:165`声明），本次补进第13.7节端口表；第10.4节补写它对完成成功判定的门控，即`flag_completion_success = flag_completion_match && i_adc_transaction_success && !B_INFLIGHT_DISCARD && i_owner_q3_window_closed`（`:462`）。调度器内部只有NORMAL事务用到这个判据，用来置位`B_RED_DONE`/`B_IR_DONE`（`:716-721`）。以下内容均不改变：owner释放条件`flag_completion_match`（`:461`，不含该门控）、owner截止、FSC-01至FSC-57的任何条款，以及`o_cal_owner_deadline_event`的相关描述。依据：本合同V1.8修订记录，以及该输出的生产者SSW合同C09 V1.9；真实证据为V1.8记录所引的`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v` LFA-06。合同同步记录见`verification_reports/CONTRACT_SYNC_BATCH2_20260930.md`。
> V1.9修订日期：2026-09-30。补记2026-09-18 SID-05修复在调度器RTL V1.8中新增的输出`o_cal_owner_deadline_event`（1 bit；端口声明`ppg_400hz_frame_calibration_scheduler.v:191`，赋值`:569`为`assign o_cal_owner_deadline_event = flag_cal_owner_deadline;`，源信号定义`:469`）。它把既有组合信号`flag_cal_owner_deadline`原样引出：校准宏帧中校准owner-pending到local tick 248仍未提交owner的那一拍为1，唯一消费者是AMI新增输入`i_cal_owner_deadline_event`（经Top内部网`sched_cal_owner_deadline_event_o`，不是Top端口）。**为什么新增**：tick-248截止抑制本身（撤销`B_CAL_WAVE_PENDING`、置`B_OWNER_DEADLINE_TIMEOUT`，`:749-752`）此前就是正确的，但从未回报AMI；AMI的`flag_calibration_request_inflight`只在校准结果被真实消费或STOP/abort/阻断时清零，被截止抑制的请求既无owner也无结果，在途标志永久为1，AMI不再发起请求握手，第9.1节要求的“原请求保留并在下一校准子帧重试”永远不会发生，整个AMB/DCS_CAL搜索永久卡死（真实RTL缺陷）。**本次改动**：第9.1节末段补一句实现说明；第10.3节末尾新增截止回报规则及一条开放观察项；第13.9节端口表新增一行。不改变owner截止数值248、`o_owner_deadline_timeout_sticky`的非阻断历史诊断属性、RED/IR owner截止283/443或FSC-01至FSC-57任何既有条款。**真实证据**：`verification_reports/WORKLINE_D_SID05_SID06_20260918.md`；`rtl/ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v` V1.2的SID-05-DCR/SID-05-DCIR截止抑制后恢复断言，iverilog与Vivado 2022.2 xsim均83 PASS/0 FAIL；2026-09-19全套19个TB的xsim系统级回归19/19 PASS、0 FAIL、合计1208 PASS。模块级`tb_ppg_400hz_frame_calibration_scheduler.v`未连接该端口，合同同步记录见`verification_reports/CONTRACT_SYNC_SID05_20260930.md`。
> V1.8修订日期：2026-08-30。桶1 RTL会话（SID-11+LFA-06+OIB-01+LFA-10(b)专属会话）新增输入`i_owner_q3_window_closed`（来自SSW新状态输出`o_owner_q3_window_closed`），接入`flag_completion_success`（正式成功结果资格判据），额外要求在途owner自身选定的Q3窗口已经关闭，防止早于Q3的CLK_DOUT冒充协议意义上的成功完成（LFA-06缺口的RTL修复）。**门控点特别说明**：`flag_completion_match`（DONE身份逐位匹配、owner是否合法释放）本身**不**引入这项新要求——身份匹配就应该合法释放owner槽位，Q3要求只作用于`flag_completion_success`（是否记为协议意义上的成功、是否置位`B_RED_DONE`/`B_IR_DONE`）。这个门控点的选择是一次真实构造中发现死锁后的修正：门控放在owner释放本身会导致"Q3若因异常提前完成而不再出现"时owner永久卡在in-flight，连带SSW侧`o_wrapper_idle`永远为假、`transaction_mismatch_sticky_o`永远清不掉。AMI自身的独立测量结果流（`o_measurement_result_valid`）不受本次改动影响——AMI-37明文要求AMI自己的完成判定只认真实DONE、不掺Q3，这是刻意的架构边界，不是遗漏，详见`PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` AMI-37。真实证据：`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v` LFA-06（V1.3，iverilog+Vivado 2022.2 xsim双工具confirmed）。不改变本合同FSC-01至FSC-57任何既有编号条款的行为。
> V1.7 fail-closed integration review, 2026-08-20: Scheduler semantics remain normative and unchanged, but the system closure verdict is owned solely by the current matrix audit and is `NOT_CLOSED` until every final defect count is zero. Implementation evidence is `EVIDENCE_PENDING`.
> V1.7 change record: replaces non-normative timing RTL and stale dependency versions with the current active contract set. Scheduler Rule A, fixed handover, owner deadline, Q1/Q2/Q3, RAW path and sample-index allocation do not change.

> Historical V1.3 freeze record (non-normative). The current normative revision is V1.7.  
> 冻结日期：2026-08-15  
> V1.3修订：将模拟波形上下文与ADC结果事务上下文拆为两个独立接口，冻结ADC owner截止点、双光在途规则、SAR9/SAR15跨色白名单、启动IDAC安全边界及AMI/SSW独立故障输入  
> V1.3依赖勘误日期：2026-08-15  
> V1.3依赖勘误：AMI依赖更新为V1.3.3，SSW依赖更新为V1.3.2；不改变RED/IR接管点、owner deadline、Q3位置或FSC-01至FSC-57语义  
> V1.3完成释放措辞勘误日期：2026-08-15  
> V1.3完成释放措辞勘误：匹配完成事件无论`success`取值均释放旧物理owner；`success`只决定结果能否进入正式处理，不改变端口、时序、验收编号或owner deadline  
> V1.3校准责任边界勘误日期：2026-08-16  
> V1.3校准责任边界勘误：仅在RUN期间按实际请求检查NORMAL_PPG、光电二极管输入、合法AMB/DCS类型和SAR9资格；不接收配置管理器校准计划，不移动接管点、Q3或owner deadline  
> 目标RTL：`ppg_400hz_frame_calibration_scheduler.v`  
> 目标TB：`tb_ppg_400hz_frame_calibration_scheduler.v`  
> 工作时钟：2 MHz数字主时钟  
> NORMAL宏帧率：400 Hz，5000个2 MHz时钟周期  
> 快速校准子周期率：3200 Hz，625个2 MHz时钟周期  
> RTL语言：可综合Verilog-2001

## 1. 合同目的

本文冻结400 Hz NORMAL宏帧、SAR9快速校准子周期、模拟波形上下文、ADC结果事务上下文、双光顺序、固定Q3采样中心以及完成事件之间的接口和时序关系。

本调度器负责：

1. 产生唯一400 Hz宏帧时间基准；
2. 按`optical_mode`调度RED、IR或双光NORMAL事务；
3. 接受AMI保持型AMB_CAL/DCS_CAL请求，并在SAR9快速校准子周期内调度；
4. 在固定早期接管点向SSW交付模拟波形上下文，但不在该时刻消费正式`sample_index`；
5. 在ADC owner截止点前向AMI提交独立结果事务，并仅为真实提交的ADC事务产生唯一`sample_index`；
6. 为同一400 Hz宏帧内的事务绑定同一`frame_id`；
7. 产生NORMAL宏帧完成和校准物理宏帧完成事件；
8. 在波形上下文或ADC owner错过各自截止点时抑制无归属采样并报告诊断；
9. 在START后发布一次不推进宏帧或采样序号的IDAC启动安全边界。

本调度器不负责：

- 计算AMB重检间隔；
- 判断AMB、DC_R或DC_IR是否位于目标窗口；
- 执行IDAC二分搜索、慢速跟踪或码值更新；
- 计算Stage1、Stage2、DC恢复、FIR、动态基线或峰谷结果；
- 产生SAR9/SAR15内部Q1/Q2/Q3模拟波形；
- 仅消费由ACTIVE控制平面解包后的V4字段；联合ACTIVE固定1024 bit，V5检测字段不直连Scheduler，必须经AMI/PWI检测链转发。
- 修改AMI内部committed IDAC码或code epoch。

## 2. 依赖追踪和优先级

**当前规范依赖（可决定Scheduler接口或语义）**

1. C01 — `ppg_system_integration/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` V1.10；
2. C04 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` V1.7；
3. C06 — `ppg_system_integration/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` V1.3；
4. C09 — `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.11；
5. C10 — `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.5；
6. C18 — `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.2；
7. C16 — `ppg_system_integration/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md` V2.2；
8. C17 — `ppg_system_integration/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` V2.4；
9. C24 — `ppg_system_integration/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` V1.6。

The fixed Q1/Q2/Q3 windows, handover and owner-deadline rules are defined in
this contract. Timing RTL, regressions, logs and predecessor documents are
non-normative evidence or conflict-discovery material and cannot move a timing
point or create a Scheduler port.

若旧handoff、旧顶层草案或注释与本文冲突，400 Hz物理调度、双光事务数量、Q3中心、`frame_id/sample_index`和快速校准容量以本文为准。

本文对旧文档中“固定三帧重检”的准确解释为：

```text
AMB -> DC_R -> DC_IR三个有序校准阶段
```

正常情况下每阶段占用一个400 Hz物理宏帧。若可配置确认次数、ADC反压或二分搜索需要的合格样本超过单宏帧8个SAR9子周期，当前阶段必须延长到后续400 Hz宏帧，禁止截断搜索、伪造阶段成功或提前进入下一阶段。

## 3. 固定编码

### 3.1 运行模式

```text
run_profile = 1'b0：NORMAL_PPG
run_profile = 1'b1：CHARACTERIZATION
```

### 3.2 光学模式

```text
optical_mode = 2'b00：RED后IR双光
optical_mode = 2'b01：仅RED
optical_mode = 2'b10：仅IR
optical_mode = 2'b11：安全关闭
```

### 3.3 ADC事务类型

```text
frame_type = 2'b00：AMB_CAL
frame_type = 2'b01：DCS_CAL
frame_type = 2'b10：NORMAL
frame_type = 2'b11：非法保留编码
```

### 3.4 精度

```text
precision_mode = 1'b0：SAR9
precision_mode = 1'b1：SAR15
```

### 3.5 颜色

```text
color_ir = 1'b0：RED
color_ir = 1'b1：IR
```

AMB_CAL时`color_ir=0`只作为协议标识。AMB_CAL期间RED和IR LED均必须关闭，不表示启用红光。

## 4. 固定时间层次

### 4.1 2 MHz基础时钟

```text
T_CLK = 0.5 us
```

所有计数边界均以2 MHz时钟上升沿定义，不允许使用组合门控时钟产生新的时钟域。

### 4.2 400 Hz宏帧

```text
C_MACRO_FRAME_TICKS = 5000
T_MACRO_FRAME       = 2.5 ms
F_MACRO_FRAME       = 400 Hz
```

宏帧计数范围为`0..4999`，在`4999 -> 0`时进入下一宏帧。

#### 4.2.1 宏帧末拍衔接（V1.13补记）

宏帧末拍（macro tick 4999）的下一宏帧建立方式冻结如下（`ppg_400hz_frame_calibration_scheduler.v` `flag_calibration_rollover`、`flag_frame_restart`）：

1. **校准滚动**：当前为校准宏帧、校准请求仍活动、无未提交校准owner-pending、无在途owner，且已有保持的请求pending或本拍AMI校准请求valid时，末拍后直接进入下一校准宏帧的子帧0，中间不经空拍；同时照常输出`o_calibration_frame_complete_event`并递增`frame_id`。
2. **直接起帧（F-009）**：不满足校准滚动、但下一帧资格在末拍已经成立时，末拍后直接建立下一宏帧，不经空拍。下一帧资格为：帧末处理后的校准请求pending（含本拍请求握手与未提交请求的跨帧重挂；已成为在途owner的请求不重挂，见§10.4），或无校准请求时的NORMAL/光学关闭起帧输入资格（`flag_next_frame_inputs_eligible`：`i_allow_new_transaction`，且光学关闭或`i_normal_measurement_eligible && !i_switch_hold_new_transaction`）。存在pending时下一帧为校准帧，否则为NORMAL帧。
3. **生命周期门控（F-010）**：以上两条都要求本拍生命周期仍有效（`flag_lifecycle_active`：已START、`i_run_enable`、非STOP排空、本拍无STOP确认、无abort、无本地或外部阻断故障）且ACTIVE配置合法。STOP确认、abort、故障或RUN撤销落在末拍时，不滚动、不直接起帧，按主状态机的帧末处理结束本帧。
4. **起帧快照**：直接起帧时，新宏帧的AMB/DC码及其epoch、精度、光学模式、输入来源和LEDDAC快照在上一宏帧末拍采样。IDAC提交在宏帧安全边界（tick 4760）或校准local tick 385，精度提交在tick 4760，末拍时这些输入早已稳定。
5. 以上条件都不成立时，宏帧在末拍后结束；之后按`flag_frame_start_eligible`从空闲起帧，空闲起帧与直接起帧使用同一输入侧资格。

因此相邻宏帧起点严格相差5000个2 MHz周期（FSC-03），唯一例外是下述例外C。

**例外C（已知既有行为）**：校准宏帧末拍时校准owner仍在途、没有pending请求、NORMAL起帧资格不成立（例如启动搜索期），且AMI以电平保持校准请求。此时末拍不滚动（在途owner）、也不直接起帧（无pending且无NORMAL资格），校准请求要等宏帧结束后的空闲期握手，下一校准宏帧在其后一拍建立。相邻宏帧起点间隔因此大于5000：至少空2拍，具体由在途owner的释放时刻决定。回归实测为5004和5131拍；换回F-009之前的调度器结果相同，属既有行为。全套回归中4份带帧间隔监视器的TB没有出现其它非5000间隔（`verification_reports/F009_ROUND_20261008.md` §4）。

### 4.3 3200 Hz快速SAR9校准子周期

```text
C_CAL_SUBFRAME_TICKS = 625
T_CAL_SUBFRAME       = 312.5 us
F_CAL_SUBFRAME       = 3200 Hz
```

一个400 Hz宏帧具有8个校准子周期容量。该容量是物理上限，不代表每个阶段必然产生8笔ADC事务；只有AMI真实请求且全部启动资格满足时才启动事务。

### 4.4 固定波形上下文接管点和Q3中心

NORMAL宏帧内的Q3中心冻结为：

```text
RED waveform context fire = macro_tick 0
IR  waveform context fire = macro_tick 160

RED Q3 center = macro_tick 300 = 宏帧起点后150 us
IR  Q3 center = macro_tick 460 = 宏帧起点后230 us
IR相对RED偏移 = 160 ticks      = 80 us
```

必须满足：

```text
T_Q3_RED(SAR9)  == T_Q3_RED(SAR15)
T_Q3_IR(SAR9)   == T_Q3_IR(SAR15)
```

调度器在固定接管点只交付模拟波形上下文。该握手允许SAR安全选择wrapper锁存精度、颜色、类型、码值、epoch和模拟来源，并按精度模板开始预建立；它不建立AMI ADC结果事务，不递增正式`sample_index`，也不表示ADC结果已经取得数字归属。SAR9与SAR15允许具有不同的预建立提前量、Q3窗口宽度和结果返回延迟，但不得改变Q3中心。

快速校准子周期内使用相同局部位置：

```text
AMB_CAL waveform context fire       = subframe_tick 0
DCS_CAL RED waveform context fire   = subframe_tick 0
DCS_CAL IR waveform context fire    = subframe_tick 0

AMB_CAL local Q3 center    = subframe_tick 266，LED全关
DCS_CAL RED local Q3 center = subframe_tick 266
DCS_CAL IR local Q3 center  = subframe_tick 266
```

候选IDAC码、颜色模式和输入信号幅度均不得移动上下文接管点或Q3中心。校准颜色只选择模拟通道、LED和DC码，不改变校准物理相位。

### 4.5 ADC结果事务owner截止点

模拟波形上下文接管后，调度器可在对应owner截止点之前提交独立ADC结果事务。截止点冻结为：

```text
NORMAL RED ADC owner deadline = macro_tick 283 = RED Q3 - 17
NORMAL IR  ADC owner deadline = macro_tick 443 = IR  Q3 - 17
CAL ADC owner deadline        = local_tick 248
```

owner可以在波形上下文成功锁存后、截止点到达前的任一2 MHz上升沿真实握手；不得早于波形上下文，也不得迟于表中截止点。`283/443`保证最早SAR15 Q1窗口开始前至少完成一个注册边沿的数字归属；校准`248`保证AMB专用波形从local tick 249开始的后段控制窗口之前已经确定结果归属。

波形上下文成功但owner未在截止点前提交时，SSW只能让已经开始的模拟预建立安全收尾，必须抑制该颜色的Q1/Q2/Q3、LED有效采样和ADC结果归属。调度器不得递增`sample_index`，不得产生该颜色完成，并置owner截止超时诊断。固定Q3坐标本身不得移动。

### 4.6 单光模式不得搬移时隙

```text
RED-only：RED仍在macro tick 0接管，Q3仍位于macro tick 300
IR-only： IR仍在macro tick 160接管，Q3仍位于macro tick 460
```

禁止为了缩短单光帧而把IR搬到RED接管点或RED Q3。这样可保证任一精度、任一合法光学模式下，同一颜色的上下文和采样时刻一致。

## 5. SAR9/SAR15启动差异

当前时序基线改为同一宏帧内完成全部预建立：

```text
NORMAL RED波形上下文在macro tick 0接管
NORMAL IR波形上下文在macro tick 160接管
SAR15最早模拟边沿相对同色Q3为-273 tick
SAR9最早模拟边沿相对同色Q3为-256 tick
```

后续SAR安全选择wrapper必须采用“由固定Q3中心向前反推预建立时刻”的方式处理精度差异：

```text
固定Q3中心
    <- SAR9所需准备时间
    <- SAR15所需准备时间
```

不得采用“先启动，再由转换长度决定Q3何时出现”的实现。

冻结的NORMAL模拟包络为：SAR15 RED最早边沿在macro tick 27，SAR9 RED最早边沿在44；SAR15 IR最早边沿在187，SAR9 IR最早边沿在204。全部边沿均位于当前400 Hz宏帧内，不占用上一宏帧。

## 6. 双光NORMAL宏帧

`optical_mode=2'b00`严格表示：

```text
一个400 Hz宏帧
    -> tick 0锁存RED波形上下文并开始RED预建立
    -> RED ADC owner在deadline 283前提交
    -> tick 160锁存IR波形上下文；此时RED owner允许仍在途
    -> IR预建立与RED尾部仅按冻结白名单允许连续共享
    -> RED Q3中心采样并由真实CLK_DOUT链完成RED结果
    -> RED owner释放
    -> IR ADC owner在deadline 443前提交
    -> IR Q3中心采样
    -> 由真实CLK_DOUT链完成IR结果并释放IR owner
    -> 该宏帧NORMAL完成
```

冻结规则：

- RED与IR不得同时点亮；
- 固定顺序为RED先、IR后；
- 每个双光NORMAL宏帧有两笔独立ADC事务；
- RED有效采样率为400 samples/s；
- IR有效采样率为400 samples/s；
- NORMAL ADC事务总率为800 transactions/s；
- 两笔事务使用相同`frame_id`；
- 两笔事务使用不同且连续的`sample_index`；
- 两笔事务使用同一个宏帧精度快照；
- IR波形上下文接管不得等待RED ADC owner释放；
- 任一时刻最多只有一个ADC结果owner；
- 只有两笔事务均真实完成后才能产生一次NORMAL完成事件。

SAR9 RED与IR包络在物理时间上允许重叠，但跨颜色连续保持白名单严格限定为：

```text
CLK_IREF_IDAC_SAR9_LOW
```

在当前统一Q3坐标下，该信号的RED窗口为`[44,318)`、IR窗口为`[204,478)`，双光并集为连续的`[44,478)`。其余SAR9控制必须保持各自RED/IR独立窗口，不得因两个波形上下文并存产生额外重叠。

SAR15 RED与IR包络同样允许相邻或部分连续，其跨颜色连续保持白名单严格限定为：

```text
CLK_IREF_IDAC_SAR15_LOW
EN_SAR15_IREF
EN_SAR15_AMB_LOW
EN_SAR15_DC_LOW
```

SAR9单项白名单和SAR15四项白名单均来自用户确认的真实模拟工作要求；各信号逻辑值和窗口仍必须逐tick取自相应netlist，不能按信号名称推断。除各自精度白名单外，RED/IR专属控制不得因两个波形上下文并存而产生额外重叠；两种精度下RED与IR LED始终互斥。

## 7. `frame_id`和`sample_index`

### 7.1 `frame_id`

`frame_id`是400 Hz真实时间坐标和双光配对标识，不是ADC事务计数器。

```text
每经过一个400 Hz宏帧边界：frame_id = frame_id + 1 mod 2^16
```

在RUN期间，以下宏帧均推进`frame_id`：

- NORMAL宏帧；
- AMB_CAL物理宏帧；
- DCS_CAL物理宏帧；
- 校准阶段延长所占用的后续宏帧；
- `optical_mode=11`下没有ADC事务的安全关闭宏帧。

因此重检或空帧不会暂停动态基线和峰谷检测所使用的真实时间。

### 7.2 `sample_index`

`sample_index`是实际启动ADC事务的全局唯一顺序号，不是400 Hz采样帧号。

```text
transaction_start_fire：
    当前事务使用当前sample_index
    随后sample_index = sample_index + 1 mod 2^16
```

模拟波形上下文不携带、不预约`sample_index`。只有ADC结果事务真实`transaction_start_fire`才把当前`o_next_sample_index`绑定为本笔正式序号并递增计数。未提交owner、被取消、错过波形接管点、错过owner截止点或被安全关闭抑制的事务不占用`sample_index`，后续有效事务继续使用未被消费的当前值。

### 7.3 双光示例

```text
frame_id=100：
    RED -> sample_index=1000
    IR  -> sample_index=1001

frame_id=101：
    RED -> sample_index=1002
    IR  -> sample_index=1003
```

RED和IR通过相同`frame_id`配对。每笔结果通过`sample_index`唯一追踪。

同色连续性只要求`frame_id`连续加1：双光模式下相邻RED事务的`sample_index`通常相差2，不能用`sample_index+1`判断同色连续采样。

### 7.4 校准示例

同一400 Hz校准宏帧可包含多笔SAR9事务：

```text
frame_id=300：
    AMB_CAL request 0 -> sample_index=4000
    AMB_CAL request 1 -> sample_index=4001
    ...
    AMB_CAL request 7 -> sample_index=4007
```

所有事务共享当前物理宏帧`frame_id`，但每笔具有唯一`sample_index`、IDAC码快照和code epoch。

## 8. 三类安全边界

### 8.1 400 Hz宏帧安全边界

`o_macro_frame_safe_boundary`只在下一400 Hz宏帧最早模拟准备动作开始前产生一次。当前2 MHz基线对应：

```text
macro_tick = 4760
```

该边界用于：

- 精度9/15-bit安全提交；
- `optical_mode`宏帧快照；
- 周期AMB重检安全接管；
- 下一宏帧`frame_id`通知；
- NORMAL宏帧上下文冻结。

精度只能在该边界改变。同一宏帧RED和IR不得使用不同精度。

### 8.2 IDAC候选提交安全边界

`o_idac_code_safe_boundary`是`ppg_idac_code_controller`把pending候选提交为committed码的唯一外部安全脉冲。它在NORMAL和快速校准期间采用不同的重复频率，但始终是2 MHz域单周期事件。V1.13补记：它是四类边界的合并——START启动边界（§8.3）、宏帧安全边界（§8.2.1）、快速校准边界（§8.2.2）和启动搜索空闲边界（§8.2.3）（`ppg_400hz_frame_calibration_scheduler.v` `idac_code_safe_boundary_o`）。

#### 8.2.1 NORMAL、单光和安全关闭RUN宏帧

当当前调度状态不是快速SAR9校准，并且系统仍处于允许受控提交的RUN上下文时：

```text
o_idac_code_safe_boundary = o_macro_frame_safe_boundary
```

因此NORMAL双光、RED-only、IR-only以及RUN中的`optical_mode=2'b11`安全关闭宏帧，均只在每个400 Hz宏帧安全点提供一次IDAC提交机会。该脉冲用于：

- START后提交MANUAL模式形成的AMB、DC_R和DC_IR初始pending码；
- NORMAL慢速跟踪提交DC_R或DC_IR的1 LSB pending调整；
- 在进入快速校准前提交仍合法且未被控制流程取消的pending码；
- 保证同一NORMAL宏帧内RED和IR使用同一组committed IDAC码及code epoch快照。

不得因为双光宏帧含有RED和IR两笔事务而产生两次NORMAL IDAC提交边界。

#### 8.2.2 3200 Hz快速SAR9校准

当调度器已经安全接管并处于AMB_CAL或DCS_CAL快速校准状态时，每个下一SAR9子周期准备窗口前产生一次`o_idac_code_safe_boundary`。其局部位置冻结为：

```text
subframe_tick = 385 = 625 - 240
```

对于一个完整400 Hz校准宏帧，理论脉冲位置为：

```text
macro_tick = 385, 1010, 1635, 2260,
             2885, 3510, 4135, 4760
```

即每个校准宏帧最多提供8次IDAC候选提交机会。脉冲是否存在由“当前宏帧已被快速校准状态占用”决定，不由该子周期是否恰好已有校准请求决定；没有pending码时脉冲可以正常出现，但不得产生虚假code update或epoch递增。

IDAC候选在某个安全脉冲提交后，只允许用于该脉冲之后的下一笔合格SAR9校准波形上下文。已经接管的波形继续使用其waveform fire时锁存的旧码值和旧epoch，不得被新提交污染。

#### 8.2.3 与宏帧安全边界同拍

第8个快速校准提交点满足：

```text
7 * C_CAL_SUBFRAME_TICKS + 385
    = 7 * 625 + 385
    = 4760
```

因此该时刻允许：

```text
o_macro_frame_safe_boundary = 1
o_idac_code_safe_boundary   = 1
```

两路输出虽然同拍为1，但所有权完全分离：

- `o_macro_frame_safe_boundary`只送往精度窗口控制器和AMB重检调度器；
- `o_idac_code_safe_boundary`只送往IDAC码控制器；
- IDAC码控制器在该时钟沿最多执行一次pending提交；
- 不得把两路脉冲再次OR后送入IDAC码控制器；
- 同拍不得被解释为两次IDAC提交，也不得递增两次code epoch；
- 精度提交、重检接管和下一宏帧快照仍只观察宏帧安全边界。

该同拍规则同时覆盖“快速校准继续到下一宏帧”和“当前校准宏帧结束、下一宏帧恢复NORMAL”两种情况。状态转换不得吞掉第8个IDAC提交点，也不得在下一拍补发第二个提交脉冲。

#### 8.2.4 生命周期门控

以下任一条件成立时，不得产生新的IDAC提交脉冲：

```text
!i_run_enable
|| i_stop_ack_event
|| i_control_abort_event
|| i_ami_fault_blocking
|| i_ssw_fault_blocking
|| o_scheduler_local_fault_blocking
```

复位、STOP、abort或阻断故障按生命周期合同取消不再合法的pending和预约；不得为了提交旧候选而延长RUN或产生迟到安全边界。`i_diag_clear_event`只清历史诊断，不抑制本来合法的安全边界。

#### 8.2.5 作用范围

该边界只用于：

- 把IDAC控制器的下一候选pending码提交为committed码；
- 更新对应code epoch；
- 为下一SAR9校准事务建立码值稳定时间。

该边界不得用于：

- 提交9/15-bit精度切换；
- 接受新的AMB周期重检接管；
- 改变400 Hz宏帧`frame_id`；
- 伪造NORMAL帧完成事件。

`o_idac_code_safe_boundary`只提供提交时刻，不判断pending是否合法，也不直接修改IDAC码。pending所有权、提交优先级、码值钳位、实际变化判断和epoch更新仍全部属于`ppg_idac_code_controller`。

#### 8.2.3 启动搜索空闲边界（V1.13补记，L-3）

启动搜索期间，若校准结果在子帧7的local tick 385之后才被消费，IDAC的下一候选码没有校准边界可等；而调度器此时既没有校准请求、又没有NORMAL资格，不会起帧，也就不会产生宏帧边界。为避免这种互相等待的死锁，调度器在以下条件全部成立时补发一拍边界（`ppg_400hz_frame_calibration_scheduler.v` `flag_idle_idac_safe_boundary`）：

```text
i_idac_boundary_request          // AMI三路IDAC候选任一路待提交（Top合并AMB/DC_R/DC_IR pending_valid）
&& 生命周期有效 && i_active_config_valid
&& !i_normal_measurement_eligible // 仅启动搜索期，NORMAL资格不成立
&& 本拍不会起帧                    // !flag_frame_start_eligible
&& 无START启动边界pending、无活动宏帧、无校准请求pending
&& 无RED/IR/校准owner-pending、无在途owner
&& i_adc_idle && i_analog_safe && i_sar_timing_idle
```

该边界只提供提交时刻；IDAC提交后请求自然撤销。它只在无宏帧时出现，不增加NORMAL宏帧内的提交次数（FSC-38），也不得被精度控制器或重检调度器当作宏帧安全边界。

### 8.3 START后的IDAC启动安全边界

为了消除“IDAC等待调度器边界、调度器又等待AMI完成启动搜索”的首帧循环等待，调度器在每次`i_start_ack_event`后建立一次启动边界pending。仅当下列条件同时满足时输出一拍：

```text
i_adc_idle
&& i_analog_safe
&& i_sar_timing_idle
&& !o_waveform_context_valid
&& !o_transaction_start_valid
&& !o_transaction_inflight
```

该拍同时满足：

```text
o_startup_idac_safe_boundary = 1
o_idac_code_safe_boundary    = 1
```

启动边界只允许IDAC控制器把MANUAL、AMB或DCS启动pending码安全提交为committed码；它不启动400 Hz宏帧、不产生ADC或模拟波形上下文、不推进`frame_id/sample_index`，也不得被精度控制器或AMB重检调度器解释为宏帧安全边界。每个START最多产生一次，STOP、abort、复位或阻断故障撤销尚未发布的pending。

### 8.4 AMI V1.3.3安全边界连接

AMI V1.3.3继续保留并冻结V1.2已经实现的公共边界拆分：

```text
i_macro_frame_safe_boundary
    -> precision window controller
    -> AMB recheck scheduler

i_idac_code_safe_boundary
    -> IDAC code controller
```

禁止简单地把3200 Hz子周期安全脉冲接到现有公共`i_frame_safe_boundary`，否则可能在校准子周期中错误提交精度切换或错误接受重检接管。

## 9. 校准事务

### 9.1 来源和所有权

调度器只消费AMI输出的保持型校准请求：

```text
calibration_sample_valid
calibration_frame_type
calibration_color_ir
calibration_precision_mode
calibration_request_reason
```

调度器不得根据`idac_mode`、`amb_recheck_interval_frames`、阈值或IDAC内部状态自行生成第二套搜索请求。

配置管理器只在COMMIT/START前检查静态ACTIVE组合，不向调度器提供校准计划。调度器必须对RUN期间实际到达的每笔请求执行接收端资格检查：

```text
calibration_request_qualified =
    i_run_enable
 && i_run_profile == NORMAL_PPG
 && i_input_source == PHOTODIODE
 && (i_calibration_frame_type == AMB_CAL
  || i_calibration_frame_type == DCS_CAL)
 && i_calibration_precision_mode == SAR9
```

只有`calibration_request_qualified=1`且本地请求缓冲可用时，`o_calibration_sample_ready`才允许为1。若CHARACTERIZATION、外部固定电流、非法frame type或SAR15请求把`i_calibration_sample_valid`拉高，调度器必须保持ready为0、置`o_protocol_error_sticky`并阻断该请求生成波形上下文、ADC owner、IDAC边界、结果事务或`sample_index`变化。该检查不得改变NORMAL RED/IR接管点、Q3、owner deadline或既有校准local tick。

`o_calibration_sample_ready`表示调度器的一项校准请求缓冲可原子接收全部请求载荷，不要求恰好位于local tick 0。请求握手后由调度器拥有并保持，直到某个后续local tick 0完成波形上下文握手。若该次波形上下文未接管，或已经接管但ADC owner未在local tick 248前提交，调度器不得再次消费上游请求；在无STOP、abort、复位或阻断故障时，原请求保留并在下一校准子帧重试。每个真实ADC owner fire只对应一笔请求，禁止一次请求自动扩增为多笔样本。V1.9补记：对“ADC owner未在local tick 248前提交”这一情形，请求载荷在波形上下文握手时已被消费（`B_CAL_REQ_PENDING`在波形fire时清零，`ppg_400hz_frame_calibration_scheduler.v:659-662`），调度器侧不再保留原请求；“原请求保留并在下一校准子帧重试”由调度器输出`o_cal_owner_deadline_event`、AMI释放在途请求并重新握手同一个尚未得到结果的候选来实现（见第10.3节）。这次重新握手不是新的样本请求，不扩增样本数。

### 9.2 固定SAR9

所有AMB_CAL和DCS_CAL固定：

```text
precision_mode = 0
```

若AMI校准请求携带`precision_mode=1`，调度器不得接受，必须置协议诊断。

### 9.3 AMB_CAL

```text
RED LED = OFF
IR LED  = OFF
frame_type = AMB_CAL
color_ir = 0，仅作协议标识
waveform context fire = 当前SAR9子周期local tick 0
Q3 center = 当前SAR9子周期local tick 266
```

正常PPG输出链不得消费AMB_CAL事务。

### 9.4 DCS_CAL RED

```text
仅RED光学时隙有效
frame_type = DCS_CAL
color_ir = 0
waveform context fire = 当前SAR9子周期local tick 0
Q3 center = 当前SAR9子周期local tick 266
```

### 9.5 DCS_CAL IR

```text
仅IR光学时隙有效
frame_type = DCS_CAL
color_ir = 1
waveform context fire = 当前SAR9子周期local tick 0
Q3 center = 当前SAR9子周期local tick 266
```

### 9.6 校准容量和阶段延长

每个400 Hz物理宏帧最多具有8个3200 Hz校准子周期。实际可启动笔数还受以下条件限制：

- AMI请求是否已经valid；
- 上一笔ADC事务是否完成并排空；
- IDAC候选是否已经在安全边界提交；
- SAR时序wrapper是否ready；
- 请求、候选码、颜色、类型和epoch是否在对应子周期local tick 0前稳定就绪。

IDAC确认和搜索需求可能为：

```text
连续越界确认样本
    +
最多8次8-bit二分候选观察
```

因此单阶段不能无条件保证在一个物理宏帧内完成。冻结行为为：

- 当前阶段未完成时继续占用后续校准宏帧；
- 跨宏帧保留的只是尚未提交owner的请求（请求pending或owner-pending）；宏帧末仍为在途owner的请求不重挂，由该owner的迟到完成或AMI超时作废后的重发推进（V1.13补记，L-1，见§10.4）；
- 保持相同AMB/DC_R/DC_IR阶段身份；
- `frame_id`按真实400 Hz边界继续递增；
- 每笔新事务继续分配新`sample_index`；
- 当前阶段成功后才进入下一阶段；
- 阶段失败时终止整体序列，不产生整体成功事件。

### 9.7 三阶段顺序

周期重检固定顺序：

```text
AMB
 -> DC_R
 -> DC_IR
 -> 恢复NORMAL
```

即使AMB committed码未改变，只要DCS功能启用，也必须执行DC_R和DC_IR重验证。

## 10. 两条独立上下文接口

### 10.1 模拟波形上下文：调度器到SSW

模拟波形上下文是保持型、时间限定的ready/valid通道：

```text
o_waveform_context_valid
i_waveform_context_ready
o_waveform_precision_mode
o_waveform_frame_id
o_waveform_color_ir
o_waveform_frame_type
o_waveform_amb_code_snapshot
o_waveform_dc_code_snapshot
o_waveform_amb_code_epoch
o_waveform_dc_code_epoch
o_waveform_input_source
o_waveform_optical_mode
o_waveform_leddac_code_snapshot
```

调度器可在固定接管点之前预装`valid`，并在等待期间逐位保持全部载荷。SSW的`i_waveform_context_ready`只在该类型的固定接管点、对应上下文槽空闲且无阻断故障时为1。唯一接管事件为：

```text
waveform_context_fire =
    o_waveform_context_valid && i_waveform_context_ready
```

该fire只完成以下工作：

- SSW锁存模拟预建立所需的完整快照；
- 为当前颜色或校准子帧预约固定物理Q3；
- 允许对应模拟包络从冻结的最早边沿开始；
- 按波形fire顺序建立owner-pending队列项。

该fire明确不完成以下工作：

- 不向AMI建立ADC结果事务；
- 不递增正式`sample_index`；
- 不表示ADC已经开始或结果一定会产生；
- 不要求上一颜色ADC owner已经释放。

NORMAL RED、NORMAL IR和校准分别使用独立波形上下文槽语义。双光时，IR在macro tick 160必须能够在RED ADC owner仍在途时锁存；SSW不得用“存在旧ADC owner”作为IR波形上下文ready的单独否决条件。

固定接管点错过后，本次时间容量失效，禁止迟到fire或移动Q3。NORMAL丢弃该颜色；已缓存校准请求保留到下一local tick 0重试。两种情况均不得消费`sample_index`。

### 10.2 ADC结果事务上下文：调度器到AMI

ADC结果事务沿用AMI保持型ready/valid通道，但只有匹配波形上下文已经锁存后才允许建立：

```text
o_transaction_start_valid
o_transaction_precision_mode
o_transaction_frame_id
o_transaction_sample_index
o_transaction_color_ir
o_transaction_frame_type
o_transaction_amb_code_snapshot
o_transaction_dc_code_snapshot
o_transaction_amb_code_epoch
o_transaction_dc_code_epoch
```

调度器在波形上下文fire后保持一笔owner-pending事务。只有SSW独立给出`i_adc_owner_ready=1`时，调度器才可向AMI导出`o_transaction_start_valid`；SSW的ready不得依赖AMI valid/ready。AMI反压期间，valid和全部载荷保持，直至真实握手或本事务owner截止点到达。

owner选择严格遵循波形接管顺序：NORMAL固定为RED后IR，校准每次只有一个槽。调度器与SSW必须各自选择最早尚未提交owner的有效波形上下文，不允许跳过RED直接给IR owner。RED在deadline 283失败并被双方同拍失效后，IR才成为最早pending项。

```text
transaction_start_fire_local =
    o_transaction_start_valid && i_transaction_start_ready
```

只有该fire才：

- 使AMI capture/S1取得唯一ADC结果所有权；
- 正式消费当前`sample_index`并将下一序号加1；
- 同拍产生给SSW的`o_adc_owner_commit_event`；
- 同拍交付owner identity sideband和`o_adc_owner_sample_index`，其值必须逐位匹配AMI事务；
- 把后续真实`CLK_DOUT`完成与该sample index绑定。

AMI返回的`i_transaction_start_fire`只作同拍一致性监测，必须逐拍等于`transaction_start_fire_local`，不得参与valid/ready组合生成。若不一致，置`o_protocol_error_sticky`并阻止后续新owner，但不得把未握手事务提升为已启动事务。

### 10.3 ADC owner资格、截止和原子提交

`i_adc_owner_ready`只能由SSW根据已锁存的匹配波形上下文、当前owner空闲、生命周期和截止范围独立生成。正式原子条件为：

```text
adc_owner_commit =
    transaction_start_fire_local
 && i_adc_owner_ready

o_adc_owner_commit_event = adc_owner_commit
```

owner identity sideband包含`precision_mode/frame_id/color_ir/frame_type/AMB code/DC code/AMB epoch/DC epoch/sample_index`。SSW必须把除新分配sample index以外的字段与最早pending波形快照逐位比较；不匹配时拒绝建立owner并置协议sticky。

调度器禁止在`i_adc_owner_ready=0`时对AMI形成可握手valid，因而AMI与SSW不会出现一侧取得owner、另一侧未取得的半提交状态。不得由`i_transaction_start_fire`反向驱动SSW ready，也不得形成调度器、AMI和SSW三方组合环。

owner必须在第4.5节截止点之内提交。截止点当拍仍允许按时提交（与SSW owner窗口`<=`截止一致）；越过截止点的候选不再形成可握手valid，只走下述截止收尾，不会出现截止与提交同拍（V1.13补记，L-4，`ppg_400hz_frame_calibration_scheduler.v` `flag_candidate_expired`、`transaction_start_valid_o`）。截止点到达仍未fire时：

- 撤销该次owner-pending；
- 不递增或跳过`sample_index`；
- SSW依据同一相位和自身owner-pending状态同步抑制尚未开始的转换资格窗口，并安全收尾预建立；
- 置`o_owner_deadline_timeout_sticky`；
- 双光NORMAL缺少任一颜色结果时不产生完整NORMAL完成；
- 校准请求保持为同一笔pending，在下一校准子帧重新建立波形上下文。

**校准owner截止回报（V1.9补记，SID-05）**：调度器通过单周期事件输出`o_cal_owner_deadline_event`把校准owner截止回报给AMI。RTL为~~`assign o_cal_owner_deadline_event = flag_cal_owner_deadline;`（V1.8）~~ `assign o_cal_owner_deadline_event = flag_cal_owner_deadline && !adc_owner_commit_event_o;`（V1.9，V1.12补记，`ppg_400hz_frame_calibration_scheduler.v:569`），源信号`flag_cal_owner_deadline`为`B_FRAME_ACTIVE && 帧模式==CAL && B_CAL_WAVE_PENDING && !B_INFLIGHT && o_calibration_local_tick >= C_CAL_OWNER_DEADLINE`（`:469`，`C_CAL_OWNER_DEADLINE=248`），纯组合，不经额外寄存器，也不以`flag_lifecycle_active`门控。该拍没有owner提交时，次态逻辑在同一拍撤销`B_CAL_WAVE_PENDING`并置`B_OWNER_DEADLINE_TIMEOUT`（`:749-752`），因此事件恰好持续1个2 MHz周期，在`B_CAL_WAVE_PENDING`寄存器清零的同一时钟沿回落；复位时状态向量全零（`:880`），事件为0。该事件不分配或跳过`sample_index`、不建立owner、不产生完成事件，也不汇入`o_scheduler_local_fault_blocking`或`o_scheduler_fault_*`记录。唯一消费者是AMI `i_cal_owner_deadline_event`（经Top内部网`sched_cal_owner_deadline_event_o`，见C01第6.3节），AMI据此释放校准在途请求，并重新发起同一个尚未得到结果的候选（见C10第11.3节）。上一条“校准请求保持为同一笔pending”在owner截止情形下的实现方式是：请求载荷已在波形上下文握手时被消费（`:659-662`），调度器侧不再保留；AMI重新握手时，`o_calibration_sample_ready`在`B_CAL_REQ_ACTIVE`、校准宏帧、`!B_CAL_WAVE_PENDING`、`!B_INFLIGHT`时允许接收（`:431-434`，其余资格见第9.1节），握手置`B_CAL_REQ_PENDING`并重新开放`B_CAL_CONTEXT_SEEN`，由下一校准子帧local tick 0重新建立波形上下文；本宏帧已无剩余子帧时，按第9.6节跨宏帧保留。没有这条回报时，AMI在途标志永不释放，后续子帧不会再有请求握手，`B_CAL_CONTEXT_SEEN`保持封闭，整个AMB/DCS_CAL搜索永久停滞。

~~**开放观察项（未裁定，暂不作规范要求）**：~~ **已裁定并修复（V1.12补记），原观察如下**：内部截止处理位于`if(adc_owner_commit_event_o == 1'b0)`分支内（`:738`），而`o_cal_owner_deadline_event`直接转发`flag_cal_owner_deadline`，没有这项同拍提交屏蔽。SSW的校准owner窗口包含local tick 248（`ppg_sar9_sar15_safe_selection_wrapper.v:413`，`<= C_CAL_OWNER_DEADLINE`），因此校准owner理论上可能恰好在local tick 248提交：调度器按正常提交处理，但同一拍仍向AMI输出截止事件。这一同拍情形尚未经仿真确认，已记录在`verification_reports/CONTRACT_SYNC_SID05_20260930.md`待裁定；裁定前，本合同不把该同拍输出列为规范行为。 **裁定结果（2026-10-01，任务C）**：A/B仿真确认这是RTL缺陷。local tick 248当拍的合法按时提交仍会触发截止事件，AMI随之过早释放在途标志、锁存陈旧请求，导致每个搜索阶段末尾多执行一次上一阶段的校准转换，并置位IDAC协议sticky。scheduler RTL V1.9把端口改为`flag_cal_owner_deadline && !adc_owner_commit_event_o`（`:569`），与内部截止分支同一门控；修复后tick 248提交不再回报截止，tick 247提交和真正错过截止两组对照逐事件不变。因此本段描述的同拍情形已不存在，上一段的规则即为规范行为。证据见`verification_reports/TASKC_TICK248_P2S_20261001.md`第1节。

### 10.4 完成和owner释放

ADC owner fire后，只能由AMI真实数字捕获链返回的下列信息释放：

```text
i_adc_transaction_complete_event
i_adc_transaction_success
i_adc_complete_sample_index
```

物理owner释放条件冻结为：

```text
owner_release =
    i_adc_transaction_complete_event
 && i_adc_complete_sample_index == current_owner_sample_index
 && i_run_generation == current_owner_run_generation   // V1.11补记；代际规则见第15.1节
```

`i_adc_transaction_success`不是物理owner释放条件，只是完成结果的后续处理资格：

- 匹配完成且`success=1`：释放当前物理owner，并允许按事务类型进入NORMAL或校准成功处理；
- 匹配完成且`success=0`：仍必须释放当前旧物理owner，但不得生成颜色成功、NORMAL宏帧完成、校准阶段成功、IDAC结果消费或任何正式测量结果；
- 完成事件的sample index不匹配：不得释放当前owner，置身份错配/阻断诊断；
- 当前无owner却收到完成事件：不得借用下一事务或旧波形身份，置协议诊断。

**成功判定的Q3门控（V1.10补记，对应V1.8新增输入）**：上面“匹配完成且`success=1`”在RTL中的准确判据是`flag_completion_success = flag_completion_match && i_adc_transaction_success && !B_INFLIGHT_DISCARD && i_owner_q3_window_closed`（`ppg_400hz_frame_calibration_scheduler.v:462`）。其中`i_owner_q3_window_closed`来自SSW `o_owner_q3_window_closed`，含义是当前在途owner自身选定的Q3窗口已经关闭（按owner保持，见C09），用来保证早于本owner Q3窗口结束的`CLK_DOUT`不被计为成功。这项门控只影响成功判定，不影响owner释放：`flag_completion_match`（`:461`）不含此项，身份和RUN代际都匹配的完成事件照常释放owner。`flag_completion_success`在调度器内只有一个消费点（`:716-721`）：NORMAL事务据此置位`B_RED_DONE`或`B_IR_DONE`；校准事务的成功处理不经过这个判据。若匹配完成且`success=1`、但Q3窗口尚未关闭，owner照常释放，但不置位颜色完成位；由于`i_adc_transaction_success`为1，`B_FRAME_FAILED`也不会被置位（`:722-723`只在`success==0`时置位），所以这个NORMAL宏帧得不到完整成功的完成事件。

真实完成必须经历`CLK_DOUT`两级同步、RAW锁存及事务身份接纳。Q3结束、模拟包络末沿、固定4拍延时或宏帧tick均不得伪造DONE。错误或迟到DONE不得归入下一事务；只有仍保留原始owner身份且sample index匹配的受控迟到完成，才可按上述`success=0`规则释放旧物理owner。

**AMI超时作废释放（V1.13补记，R3/FSC-54）**：除真实完成外，唯一的另一条owner释放路径是AMI的完成丢失超时作废单拍`i_adc_transaction_lost_event`（AMI为唯一裁决点，判定条件见C10 §7.1）。它与`i_adc_transaction_complete_event`互斥，并复用`i_adc_complete_sample_index`作为作废身份：

```text
owner_lost_release =
    i_adc_transaction_lost_event
 && current_owner_inflight
 && i_adc_complete_sample_index == current_owner_sample_index
 && i_run_generation == current_owner_run_generation
```

（`ppg_400hz_frame_calibration_scheduler.v` `flag_owner_lost_match`）匹配时：释放在途owner；不置`success`、不置RED/IR颜色完成位、不计校准阶段成功；若该owner不是STOP/abort的受控丢弃owner，则把**当前宏帧**置为失败收尾，不产生该帧的NORMAL完成。owner跨宏帧在途时，置失败的是作废发生时的当前宏帧，不是作废事务的起始帧（F-7）。作废事件身份不匹配或当前无owner时，按错配DONE处理：置`o_completion_mismatch_sticky`并发出调度器故障记录。

**校准owner跨宏帧（V1.13补记，L-1）**：校准宏帧末拍，未提交owner的请求（请求pending或owner-pending）跨宏帧重挂；已成为在途owner的请求不重挂。下一宏帧由该owner的迟到完成或作废后的AMI重发推进，避免下一宏帧发出拿不到owner的波形、迟到的`CLK_DOUT`被错绑到旧owner（`ppg_400hz_frame_calibration_scheduler.v`帧末处理中`B_CAL_REQ_PENDING`的重挂条件；`@satisfies: FSC-17`）。

## 11. IDAC码和epoch快照

事务只使用AMI committed输出：

```text
AMB code
DC_R code
DC_IR code
AMB code epoch
DC_R code epoch
DC_IR code epoch
```

按颜色选择：

```text
RED事务 -> DC_R code及epoch
IR事务  -> DC_IR code及epoch
AMB_CAL  -> AMB code及epoch；DC字段按协议带0或当前诊断值，但不得参与AMB判断
```

模拟控制字段在`waveform_context_fire`时原子快照；ADC结果事务在后续`transaction_start_fire`时必须逐位复用同一身份快照，并在该沿首次绑定正式sample index。后续候选提交不得污染已锁存波形上下文或已经启动的ADC事务。

禁止使用ACTIVE manual码或IDAC pending候选码直接替代committed码。

## 12. 完成事件

### 12.1 物理ADC事务完成

后续SAR/capture层必须向调度器返回单周期完成事件及匹配的`sample_index`。调度器只能完成当前已提交ADC owner，不得把波形上下文、Q3末沿或迟到DONE当作完成，也不得把旧DONE归入下一事务。完成沿与SSW观察到的同一AMI旁带必须一致释放双方owner状态。

### 12.2 NORMAL完成

```text
双光：RED和IR两笔匹配事务均真实完成后产生一次
RED-only：RED完成后产生一次
IR-only：IR完成后产生一次
safe-off：不产生
```

`o_normal_frame_complete_event`每个完整NORMAL宏帧最多一拍。双光模式不得每颜色各产生一次，否则AMI内部AMB重检间隔计数会加倍。

### 12.3 校准物理宏帧完成

`o_calibration_frame_complete_event`表示当前400 Hz物理宏帧的校准调度窗口已经结束，不表示当前AMB/DC阶段必然成功。

阶段控制同时等待：

```text
物理校准宏帧结束事实
    &&
IDAC阶段结果成功/失败事实
```

若阶段需要延长，后续校准宏帧继续产生各自的物理完成事件，阶段身份保持不变，直到IDAC结果闭合。

V1.13补记（F-9）：上式中的“物理校准宏帧结束事实”，指本阶段内出现过的任一次`o_calibration_frame_complete_event`，不要求晚于本阶段最后一笔样本。因此阶段跨宏帧延长（§9.6）或跨宏帧重试之后，阶段在后一宏帧中途得到结果时立即推进，下一阶段可以在同一物理校准宏帧的后续子帧开始（重检侧的表述见C16 §9.4）。下一阶段不会使用未生效的码：IDAC样本资格要求样本快照码和epoch等于当前已提交的码和epoch（C17）。

## 13. 冻结端口合同

### 13.1 参数

| 参数 | 默认值 | 语义 |
| --- | ---: | --- |
| `C_FRAME_ID_WIDTH` | 16 | 400 Hz物理帧号宽度 |
| `C_SAMPLE_INDEX_WIDTH` | 16 | ADC事务全局序号宽度 |
| `C_IDAC_CODE_WIDTH` | 8 | committed IDAC码宽度 |
| `C_CODE_EPOCH_WIDTH` | 4 | IDAC码版本宽度 |
| `C_RUN_GENERATION_WIDTH` | 8 | manager唯一生产、经ACTIVE wrapper与Top透明扇出的RUN代际宽度 |
| `C_MACRO_TICK_WIDTH` | 13 | 覆盖0至4999 |
| `C_CAL_TICK_WIDTH` | 10 | 覆盖0至624校准局部相位 |
| `C_MACRO_FRAME_TICKS` | 5000 | 400 Hz宏帧周期 |
| `C_CAL_SUBFRAME_TICKS` | 625 | 3200 Hz校准子周期 |
| `C_NORMAL_RED_OWNER_DEADLINE` | 283 | RED ADC owner最晚提交tick |
| `C_NORMAL_IR_OWNER_DEADLINE` | 443 | IR ADC owner最晚提交tick |
| `C_CAL_OWNER_DEADLINE` | 248 | 校准ADC owner最晚提交local tick |

### 13.2 全局与生命周期输入

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_clk` | 1 | 2 MHz主时钟 |
| `i_rstn` | 1 | 低有效异步复位 |
| `i_active_config_valid` | 1 | ACTIVE整体合法 |
| `i_run_enable` | 1 | 当前处于RUN |
| `i_allow_new_transaction` | 1 | manager允许新ADC事务 |
| `i_start_ack_event` | 1 | 新RUN开始单拍 |
| `i_stop_ack_event` | 1 | STOP进入排空单拍 |
| `i_control_abort_event` | 1 | 阻断撤销单拍 |
| `i_diag_clear_event` | 1 | sticky清除单拍 |
| `i_run_generation` | `C_RUN_GENERATION_WIDTH` | manager经ACTIVE wrapper与Top扇出的当前RUN代际；每个保留owner、波形和完成上下文原子锁存，陈旧代际不得匹配、释放或重绑owner |

### 13.3 配置和AMI状态输入

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_run_profile` | 1 | NORMAL或CHARACTERIZATION |
| `i_input_source` | 1 | 模拟输入来源资格/诊断，不改变frame type |
| `i_optical_mode` | 2 | 双光、单光或安全关闭 |
| `i_active_precision_mode` | 1 | AMI唯一committed精度 |
| `i_normal_measurement_eligible` | 1 | AMI允许正式NORMAL测量 |
| `i_switch_hold_new_transaction` | 1 | 精度切换阻止新事务 |
| `i_ami_fault_blocking` | 1 | AMI捕获、IDAC或测量链阻断故障 |
| `i_ssw_fault_blocking` | 1 | SSW波形、owner或模拟协议阻断故障 |
| `i_amb_code` | 8 | 当前AMB committed码 |
| `i_dcs_r_code` | 8 | 当前RED DC committed码 |
| `i_dcs_ir_code` | 8 | 当前IR DC committed码 |
| `i_amb_code_epoch` | 4 | AMB码版本 |
| `i_dcs_r_code_epoch` | 4 | RED DC码版本 |
| `i_dcs_ir_code_epoch` | 4 | IR DC码版本 |
| `i_leddac_r_code` | 8 | 独立已提交RED LEDDAC码，供波形上下文快照 |
| `i_leddac_ir_code` | 8 | 独立已提交IR LEDDAC码，供波形上下文快照 |
| `i_idac_boundary_request` | 1 | V1.13补记。AMI三路IDAC候选（AMB、DC_R、DC_IR）任一路等待安全边界提交；Top由三路`pending_valid`相或得到。只用于启动搜索空闲边界（§8.2.3） |

### 13.4 AMI校准请求输入

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_calibration_sample_valid` | 1 | 保持型SAR9校准请求 |
| `o_calibration_sample_ready` | 1 | 调度器接受当前请求 |
| `i_calibration_frame_type` | 2 | AMB_CAL或DCS_CAL |
| `i_calibration_color_ir` | 1 | DCS颜色；AMB固定0 |
| `i_calibration_precision_mode` | 1 | 必须为0 |
| `i_calibration_request_reason` | 2 | 启动搜索或周期重检 |

### 13.5 SSW模拟波形上下文输出

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `o_waveform_context_valid` | 1 | 保持型模拟波形上下文有效 |
| `i_waveform_context_ready` | 1 | SSW在固定接管点接受当前波形快照 |
| `o_waveform_precision_mode` | 1 | 本次模拟波形精度快照 |
| `o_waveform_frame_id` | 参数化 | 本次波形所属400 Hz物理帧号 |
| `o_waveform_color_ir` | 1 | 本次波形颜色 |
| `o_waveform_frame_type` | 2 | AMB_CAL、DCS_CAL或NORMAL |
| `o_waveform_amb_code_snapshot` | 8 | 预建立前冻结的AMB committed码 |
| `o_waveform_dc_code_snapshot` | 8 | 预建立前冻结的颜色DC committed码 |
| `o_waveform_amb_code_epoch` | 4 | AMB快照版本 |
| `o_waveform_dc_code_epoch` | 4 | 颜色DC快照版本 |
| `o_waveform_input_source` | 1 | 光电二极管或外部固定电流快照 |
| `o_waveform_optical_mode` | 2 | 波形接管时的宏帧光学模式快照 |
| `o_waveform_leddac_code_snapshot` | 8 | 当前颜色已提交LEDDAC码快照；固定电流/AMB为0 |

必须满足：

```text
waveform_context_fire =
    o_waveform_context_valid && i_waveform_context_ready
```

波形载荷在等待固定接管点期间保持；fire后由SSW独立持有，不得继续依赖调度器端实时配置。

### 13.6 AMI ADC结果事务输出

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `o_transaction_start_valid` | 1 | 波形已锁存且SSW owner ready后、截止点前有效的AMI结果事务 |
| `i_transaction_start_ready` | 1 | AMI可接收事务 |
| `i_transaction_start_fire` | 1 | AMI返回的启动一致性监测单拍；不得参与调度器ready生成 |
| `o_transaction_precision_mode` | 1 | 本笔精度快照 |
| `o_transaction_frame_id` | 参数化 | 本笔400 Hz物理帧号 |
| `o_transaction_sample_index` | 参数化 | 本笔全局ADC序号 |
| `o_transaction_color_ir` | 1 | 本笔颜色 |
| `o_transaction_frame_type` | 2 | AMB_CAL、DCS_CAL或NORMAL |
| `o_transaction_amb_code_snapshot` | 8 | 本笔AMB committed码 |
| `o_transaction_dc_code_snapshot` | 8 | 本笔颜色DC committed码 |
| `o_transaction_amb_code_epoch` | 4 | 本笔AMB版本 |
| `o_transaction_dc_code_epoch` | 4 | 本笔颜色DC版本 |

必须满足：

```text
i_transaction_start_fire
    == o_transaction_start_valid && i_transaction_start_ready
```

该等式是同拍一致性检查，不改变正式握手方向；不一致时置协议sticky并进入阻止新事务的故障保持。

### 13.7 SSW owner资格和物理完成接口

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_adc_owner_ready` | 1 | SSW确认匹配波形上下文存在、当前owner空闲且未过截止点 |
| `o_adc_owner_commit_event` | 1 | 与AMI真实transaction fire同拍的SSW owner提交单拍 |
| `o_adc_owner_precision_mode` | 1 | 与AMI事务相同的精度身份 |
| `o_adc_owner_frame_id` | 参数化 | 与AMI事务相同的物理帧号 |
| `o_adc_owner_color_ir` | 1 | 与AMI事务相同的颜色身份 |
| `o_adc_owner_frame_type` | 2 | 与AMI事务相同的类型身份 |
| `o_adc_owner_amb_code_snapshot` | 8 | 与AMI事务相同的AMB码快照 |
| `o_adc_owner_dc_code_snapshot` | 8 | 与AMI事务相同的颜色DC码快照 |
| `o_adc_owner_amb_code_epoch` | 4 | 与AMI事务相同的AMB版本 |
| `o_adc_owner_dc_code_epoch` | 4 | 与AMI事务相同的DC版本 |
| `o_adc_owner_sample_index` | 参数化 | 与AMI事务相同、仅在本次fire正式分配的sample index |
| `i_adc_transaction_complete_event` | 1 | 当前物理ADC事务完成单拍 |
| `i_adc_transaction_success` | 1 | 完成结果处理资格；0仍释放匹配owner，但禁止计为成功结果 |
| `i_adc_complete_sample_index` | 参数化 | 完成事务身份回传 |
| `i_adc_transaction_lost_event` | 1 | V1.13补记。AMI在途owner完成丢失超时作废单拍，与`i_adc_transaction_complete_event`互斥，身份取`i_adc_complete_sample_index`；匹配时释放owner但不计成功（§10.4） |
| `i_owner_q3_window_closed` | 1 | 来自SSW `o_owner_q3_window_closed`，表示当前在途owner自身选定的Q3窗口已关闭。只进入成功判定`flag_completion_success`（`:460`），不参与owner释放；V1.8新增，V1.10补入本表，语义见第10.4节 |
| `i_adc_idle` | 1 | 物理ADC和DONE已回到可启动状态 |
| `i_analog_safe` | 1 | 模拟输出处于允许停止/切换状态 |
| `i_sar_timing_idle` | 1 | 无在途模拟相位或待完成颜色 |

### 13.8 时间和完成输出

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `o_macro_frame_start_event` | 1 | 400 Hz宏帧起点单拍 |
| `o_macro_frame_safe_boundary` | 1 | 下一宏帧准备前安全边界 |
| `o_idac_code_safe_boundary` | 1 | NORMAL时每宏帧一次、快速校准时每子周期一次的IDAC唯一提交边界；另含START启动边界与启动搜索空闲边界（§8.2，V1.13补记） |
| `o_startup_idac_safe_boundary` | 1 | 每次START后、首个宏帧前最多一次的IDAC启动提交边界 |
| `o_safe_frame_id` | 参数化 | 下一400 Hz宏帧编号 |
| `o_macro_tick` | 13 | 当前0至4999相位，供集成验证 |
| `o_calibration_subframe_index` | 3 | 当前0至7校准子周期 |
| `o_calibration_local_tick` | 10 | 当前0至624校准局部相位，是安全选择wrapper的唯一子帧相位源 |
| `o_normal_frame_complete_event` | 1 | 完整NORMAL宏帧完成单拍 |
| `o_calibration_frame_complete_event` | 1 | 校准物理宏帧结束单拍 |

### 13.9 状态和诊断输出

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `o_scheduler_idle` | 1 | 无保持波形上下文、无owner-pending、无在途ADC、无待完成宏帧和启动边界pending |
| `o_normal_frame_active` | 1 | 当前宏帧正在执行NORMAL |
| `o_calibration_frame_active` | 1 | 当前宏帧用于校准 |
| `o_transaction_inflight` | 1 | 当前有一笔已启动未完成ADC事务 |
| `o_current_frame_id` | 参数化 | 当前400 Hz宏帧号 |
| `o_next_sample_index` | 参数化 | 下一笔成功启动将使用的序号 |
| `o_launch_timeout_sticky` | 1 | 至少一个波形上下文错过固定接管点 |
| `o_owner_deadline_timeout_sticky` | 1 | 波形已接管但ADC owner未在截止点前提交 |
| `o_cal_owner_deadline_event` | 1 | 校准owner截止单周期事件（V1.9补记，SID-05）。输出，复位值0（组合输出，由复位清零的状态向量导出）。生产者：~~`flag_cal_owner_deadline`直接转发~~ `flag_cal_owner_deadline && !adc_owner_commit_event_o`（V1.12补记，RTL V1.9，`:569`）；校准宏帧中校准owner-pending到local tick 248仍无owner、且该拍没有owner提交时为1，持续1个2 MHz周期，在`B_CAL_WAVE_PENDING`清零的同一时钟沿回落。唯一消费者：AMI `i_cal_owner_deadline_event`（Top内部网`sched_cal_owner_deadline_event_o`，非Top端口）。不是故障，不进入阻断汇总；语义见第10.3节 |
| `o_completion_mismatch_sticky` | 1 | DONE sample index与在途事务不匹配 |
| `o_protocol_error_sticky` | 1 | 编码、握手或上下文协议异常 |
| `o_scheduler_local_fault_blocking` | 1 | 仅本地活动根因、协议错误或身份错配的阻断汇总；不重复回送AMI/SSW输入故障 |

`o_launch_timeout_sticky`和`o_owner_deadline_timeout_sticky`是历史诊断，不因单次容量丢失永久阻断后续合法重试；当前失败波形安全收尾期间仍禁止同槽新接管。`o_protocol_error_sticky`、无法确认归属的completion mismatch及尚未排除的活动根因属于阻断项。这样既不掩盖异常，也不会让一次有界反压把400 Hz系统永久锁死。

## 14. NORMAL调度资格

```text
normal_eligible =
    i_active_config_valid
 && i_run_enable
 && i_allow_new_transaction
 && i_normal_measurement_eligible
 && !i_switch_hold_new_transaction
 && !i_ami_fault_blocking
 && !i_ssw_fault_blocking
 && !o_scheduler_local_fault_blocking
 && i_optical_mode != 2'b11
```

双光宏帧一旦开始，RED和IR的精度、光学模式及宏帧身份必须来自同一宏帧快照。RUN中实时输入变化不得污染已开始宏帧。

## 15. 校准与NORMAL优先级

固定优先级：

```text
复位/STOP/abort/阻断故障
    > 已接受且正在执行的校准请求
    > 新的AMI校准请求
    > NORMAL事务
```

校准请求valid只表示AMI需要下一笔样本，不允许调度器一次握手后自动生成8笔重复事务。每笔SAR9校准ADC事务都必须对应一笔真实请求握手和一个匹配结果。

### 15.1 V1.4 generation and supervisor fault ports

Scheduler receives `i_run_generation[C_RUN_GENERATION_WIDTH-1:0]` from the
manager-owned fanout through the ACTIVE wrapper and Top, and retains it atomically with every owner and
completion context. A stale generation cannot match, release or rebind an
owner. The generation tag never changes Rule A, fixed handover, Q1/Q2/Q3, RAW
causality, owner deadline or normal `sample_index` consumption.

Scheduler exposes the registered supervisor record
`o_scheduler_fault_valid`, `o_scheduler_fault_active`,
`o_scheduler_fault_cause[7:0]`,
`o_scheduler_fault_identity_valid` and full ID. `valid` is one 2 MHz cycle;
cause and ID are stable during that cycle; invalid identity fields are zero.
Only an unrecoverable Scheduler protocol condition may emit this record. The
waveform-launch and owner-deadline timeout classes remain non-blocking local
historical diagnostics and never assert this record or system abort/STOP.
`fault_active` falls only after the documented safe cancellation/recovery
predicate or reset. `i_diag_clear_event` clears historical diagnostics only and
cannot release an owner or active fault.

`i_adc_idle` is a retained local port name only. Its unique source is
`Top.flag_adc_physical_idle`; it means that physical conversion and both
asynchronous DONE/CLK_DOUT returns are inactive. It is not an AMI completion,
digital drain or a Scheduler-generated idle indication.

## 16. 生命周期

### 16.1 复位

`i_rstn=0`立即：

- 清除所有valid、在途事务、宏帧活动和完成事件；
- 清除所有波形上下文槽、owner-pending和启动边界pending；
- `frame_id`和`sample_index`清零；
- 模拟启动输出保持安全关闭；
- 清除全部sticky；
- 禁止迟到DONE成为新事务结果。

### 16.2 START

`i_start_ack_event`建立新RUN：

- `frame_id=0`；
- `sample_index=0`；
- 清除上一RUN的宏帧和校准所有权；
- 清除调度器sticky；
- 建立一次START后IDAC启动安全边界pending；
- V1.13补记：调度器的历史sticky在新START清零（START把整个状态向量清零后只置STARTED和启动边界pending），而AMI的历史诊断（含`o_owner_lost_sticky`）在新START不清（C10 §15.1）。两套规则并存，软件需分别读取；
- 等待该启动边界完成、ACTIVE、AMI和模拟资格后开始首个宏帧；
- NORMAL_PPG仍由AMI先完成IDAC启动搜索，调度器不得提前发正式NORMAL。

### 16.3 STOP

`i_stop_ack_event`后：

- 立即停止提出新事务；
- 未接管波形上下文、未提交owner和AMI事务valid撤销；
- 已接管但未提交owner的模拟预建立安全收尾且不得形成Q1/Q2/Q3有效采样；
- 已提交ADC owner在STOP接受时标记为discard-pending，等待真实物理完成；AMI返回的原身份`success=0`旁带是唯一释放路径，不得把该事务计为成功、推进IDAC/校准或产生正式NORMAL完成；
- 不产生新的正式NORMAL完成事件；
- `o_scheduler_idle`只有在事务和模拟时序均排空后置1；
- sticky保留供软件读取。

V1.13补记（STOP语义）：manager的STOPPING不等待当前宏帧结束。纯STOP（无abort）不清除已建立的宏帧：本帧的接管点立即封闭、owner-pending立即撤销，宏帧在CONFIG中以空帧形式自然走到tick 4999后结束。STOP落在新宏帧tick 0时，这段空帧约2.5 ms。这段空帧不触发任何STOPPING计时。

### 16.4 abort

`i_control_abort_event`立即禁止未来启动，撤销未握手波形上下文、已接管但未提交的owner-pending及启动边界pending，并把已提交ADC owner标记为丢弃。scheduler和SSW必须保留该已提交owner的原始`sample_index`作为最小释放身份，直至AMI返回匹配完成旁带；匹配旁带无论`success`取值均只释放旧物理owner，且abort路径期望`success=0`。SSW立即失效旧波形驱动资格，但不得在物理owner释放前把该释放身份重新分配给新事务。迟到DONE不得复活旧波形、递增序号或产生正式完成事件。

### 16.5 诊断清除

`i_diag_clear_event`只清除非活动历史sticky，不得解除当前在途事务、阻断故障根因或改变计数器。

V1.13补记（清除门控，`ppg_400hz_frame_calibration_scheduler.v`诊断清除分支）：只有在无活动宏帧、无在途owner、无RED/IR/校准owner-pending、且无AMI/SSW外部阻断故障时，诊断清除才清掉`o_launch_timeout_sticky`、`o_owner_deadline_timeout_sticky`、`o_completion_mismatch_sticky`和`o_protocol_error_sticky`。RUN中宏帧首尾相接（§4.2.1），活动宏帧始终存在，所以**调度器历史sticky只能在RUN之外清除**。

**已知限制（V1.13补记）**：周期重检期间，夹在两个校准宏帧之间的NORMAL宏帧会出现没有owner的RED/IR波形，RED/IR owner截止（283/443）因此触发并置位`o_owner_deadline_timeout_sticky`。所以周期重检期间该sticky不能作为异常指示。这是既有行为（`verification_reports/OWNER_LIFECYCLE_ROUND_20261007.md` §7.1(d)），其后续验证另行安排。

## 17. 禁止事项

以下实现违反本合同：

1. 双光模式只采RED或只采IR；
2. RED与IR同时点亮；
3. 双光每颜色产生一次`normal_frame_complete_event`；
4. RED和IR使用不同`frame_id`；
5. RED和IR共用同一个`sample_index`；
6. 单光IR被搬到RED的接管点或Q3时隙；
7. SAR9和SAR15同色Q3中心不一致；
8. 用ADC结果返回时刻替代Q3采样时刻定义`frame_id`；
9. 反压时移动已经承诺事务的Q3中心；
10. 波形上下文错过固定接管点后迟到启动；
11. 校准事务使用SAR15；
12. AMB_CAL期间点亮任一LED；
13. 在外部调度器重复维护AMB重检间隔计数；
14. 自动重复AMI的一笔校准请求形成多笔ADC事务；
15. 在8个子周期不足时截断确认/搜索并伪造阶段成功；
16. 使用一个公共3200 Hz安全脉冲同时提交IDAC码和精度切换；
17. 使用ACTIVE manual码或pending候选码替代AMI committed码；
18. 未启动事务仍递增`sample_index`；
19. 校准或安全关闭期间暂停`frame_id`；
20. 把`sample_index`当作双光配对标识或同色400 Hz连续性判断依据；
21. 使用同一个fire同时承担波形预建立接管和AMI ADC结果owner提交；
22. 在波形上下文fire时递增正式`sample_index`；
23. 因RED ADC owner仍在途而拒绝macro tick 160的IR波形上下文；
24. owner未提交仍产生Q1/Q2/Q3、LED有效采样或接纳ADC结果；
25. 用固定4拍、Q3结束或模拟包络末沿伪造ADC完成；
26. 让SAR15白名单四项以外的RED/IR专属控制产生额外重叠；
27. 把AMI故障与SSW故障合并成来源不明的单一输入或把外部故障回送进本地故障组合环；
28. 让`CLK_IREF_IDAC_SAR9_LOW`以外的SAR9控制跨RED/IR连续保持或额外重叠。

## 18. 自检验收矩阵

| 编号 | 场景 | 验收要求 |
| --- | --- | --- |
| FSC-01 | 异步复位 | valid、在途、计数、完成事件和sticky确定清零 |
| FSC-02 | 新START | frame ID从0开始，首笔事务使用sample index 0且真实fire后下一序号变为1 |
| FSC-03 | 400 Hz周期 | 相邻宏帧起点严格相差5000个2 MHz周期。V1.13原行补充：对所有帧末成立，包括宏帧末拍直接起帧与校准滚动（§4.2.1）；唯一例外是§4.2.1例外C |
| FSC-04 | 双光NORMAL | RED后IR，各启动一次，禁止同时点亮 |
| FSC-05 | 双光编号 | 两色frame ID相同，sample index连续且不同 |
| FSC-06 | RED-only | 仅RED事务，接管点仍为macro tick 0 |
| FSC-07 | IR-only | 仅IR事务，接管点仍为macro tick 160 |
| FSC-08 | safe-off | 无NORMAL和CAL事务，frame ID仍推进 |
| FSC-09 | SAR9上下文 | RED/IR分别在macro tick 0/160原子接管，后续Q3合同值为300/460 |
| FSC-10 | SAR15上下文 | 接管点与SAR9逐tick一致，后续预建立包络允许不同 |
| FSC-11 | 同帧精度 | 双光RED/IR使用同一committed精度 |
| FSC-12 | 精度pending | 停止新事务，只有宏帧安全边界允许提交 |
| FSC-13 | AMB_CAL | SAR9、颜色标识0、local tick 0接管，后续Q3为266且两LED关闭 |
| FSC-14 | DCS_CAL RED | SAR9、local tick 0接管，后续Q3为266 |
| FSC-15 | DCS_CAL IR | SAR9、local tick 0接管，后续Q3同样为266 |
| FSC-16 | 3200 Hz容量 | 子周期严格625 tick，每宏帧8个容量 |
| FSC-17 | 校准请求资格与缓冲 | 仅RUN期NORMAL_PPG+PHOTODIODE+AMB/DCS+SAR9请求握手一次；非法请求无波形/owner/序号副作用；合法请求错过接管或owner截止后保留到下一子帧重试。V1.13原行补充：校准宏帧末仍为在途owner的请求不跨帧重挂（§10.4，L-1） |
| FSC-18 | IDAC子周期提交 | 候选提交边界不触发精度或重检提交 |
| FSC-19 | 阶段超过8笔 | 同阶段延长到下一宏帧，不伪造完成。V1.13原行补充：启动搜索期结果晚于子帧7 local tick 385时，由§8.2.3空闲边界提交下一候选，不得死锁 |
| FSC-20 | 三阶段顺序 | AMB成功后固定DC_R、DC_IR，禁止跳序 |
| FSC-21 | AMB码未改变 | 仍执行两色DC重验证 |
| FSC-22 | 双光完成事件 | 两色完成后仅一拍，RED完成时不得提前输出 |
| FSC-23 | 单光完成事件 | 唯一颜色完成后仅一拍 |
| FSC-24 | 校准物理完成 | 宏帧结束事件与阶段成功严格区分 |
| FSC-25 | sample index增长 | 只在真实start fire后加1 |
| FSC-26 | frame ID增长 | 每真实宏帧边界加1，包括校准和空帧 |
| FSC-27 | 16-bit回绕 | 两计数器自然回绕，无额外重复消费 |
| FSC-28 | 两上下文分离 | waveform fire只锁存SSW模拟快照，不启动AMI、不消费sample index |
| FSC-29 | 波形接管超时 | 固定波形接管点SSW未ready时抑制迟到波形、不移动Q3、置launch sticky |
| FSC-30 | DONE身份匹配 | 错误sample index不完成在途事务并置sticky |
| FSC-31 | STOP排空 | 无新启动，迟到结果不产生正式完成 |
| FSC-32 | abort | 撤销未握手事务，已启动事务受控丢弃 |
| FSC-33 | 诊断清除 | 只清历史，不解除活动根因 |
| FSC-34 | 随机ready/valid | 无丢失、无重复、无颜色/epoch交叉 |
| FSC-35 | 长时间回归 | RED/IR各自400 Hz，完成事件和计数无漂移 |
| FSC-36 | AMI fire一致性 | 返回fire必须逐拍等于valid与ready；错配置协议sticky且不得伪造启动 |
| FSC-37 | owner资格反压 | SSW owner未ready时不对AMI形成可握手valid，不消费序号；截止后置owner sticky |
| FSC-38 | NORMAL IDAC边界 | 每个400 Hz宏帧只与宏帧安全边界同拍一次，双光不增加次数。V1.13原行补充：§8.2.3空闲边界只在无宏帧时出现，不计入宏帧内次数 |
| FSC-39 | 快速校准IDAC边界 | 一个完整校准宏帧在指定8个tick各输出一拍 |
| FSC-40 | 边界同拍 | macro tick 4760两路边界可同拍，但IDAC只提交一次且epoch最多递增一次 |
| FSC-41 | 生命周期门控 | 非RUN、STOP、abort和阻断故障期间不产生新的IDAC提交脉冲 |
| FSC-42 | 校准局部tick | `o_calibration_local_tick`严格循环0至624且与子帧编号一致 |
| FSC-43 | 校准接管间隔 | 连续合格校准事务的接管点严格相隔625个2 MHz周期 |
| FSC-44 | 迟到校准valid | local tick 0之后到达的请求不得在本子帧迟到启动，只能等待下一子帧tick 0 |
| FSC-45 | 校准颜色同相位 | AMB、DCS RED和DCS IR均只在local tick 0接管，不因颜色移动 |
| FSC-46 | RED独立owner | RED波形tick 0接管，ADC owner在deadline 283前独立提交。V1.13原行补充：tick 283当拍提交属按时；越过283的候选不再形成valid（§10.3，L-4） |
| FSC-47 | IR并行预建立 | macro tick 160接管IR波形时允许RED owner仍在途，IR最早包络不漂移 |
| FSC-48 | RED完成后IR owner | 仅真实RED DONE释放owner；IR在deadline 443前随后原子提交 |
| FSC-49 | IR owner截止失败 | deadline 443仍无owner时不消费序号、不产生IR有效采样或NORMAL完成。V1.13原行补充：越过443的候选只走截止收尾，不与截止同拍提交（§10.3，L-4） |
| FSC-50 | 校准owner截止 | local tick 248前提交；失败时安全收尾并重试同一校准请求。V1.12原行补充：local tick 248当拍提交仍属按时提交，不回报截止；截止点到达仍未提交时`o_cal_owner_deadline_event`恰好输出1个周期，AMI据此释放在途请求并重新握手同一候选（第10.3节，SID-05）。V1.13原行补充：越过local tick 248的候选不再形成valid（L-4） |
| FSC-51 | owner原子提交 | AMI fire与SSW owner commit同拍且sample index逐位相同，无半提交 |
| FSC-52 | 连续sample index | 仅owner fire递增；双光两个正式结果使用不同且连续序号 |
| FSC-53 | SAR15跨色白名单 | 仅四项批准信号可跨RED/IR连续，其他控制及两路LED无额外重叠 |
| FSC-54 | 真实完成链 | DONE来自CLK_DOUT同步、RAW锁存和身份接纳；匹配`success=1/0`均释放owner但只有1计为成功，错配或固定延时脉冲不得释放owner。V1.13原行补充：AMI超时作废单拍按同一身份匹配释放owner、不计成功，并把当前宏帧置为失败收尾（§10.4，R3、F-7） |
| FSC-55 | START启动边界 | 安全空闲后仅一拍IDAC边界，无宏帧、波形、ADC和计数推进 |
| FSC-56 | 独立故障阻断 | AMI或SSW任一故障独立阻断新接管，本地fault无反馈组合环 |
| FSC-57 | SAR9跨色白名单 | 仅`CLK_IREF_IDAC_SAR9_LOW`按`[44,318)`与`[204,478)`合并为连续`[44,478)`；其余SAR9控制无额外重叠 |

## 19. 实现与验证要求

后续RTL必须：

- 使用可综合Verilog-2001；
- 采用单一2 MHz时钟域；
- 不生成门控时钟；
- 对全部保持型接口实现载荷稳定；
- 对宏帧、子周期、事务和完成所有权使用显式状态；
- 对计数宽度、自然回绕、固定波形接管点和owner截止点比较显式处理；
- 对异常DONE和迟到事务具有确定恢复路径；
- 不推断锁存器；
- 不依赖`initial`形成ASIC功能状态。

自检TB必须真实覆盖FSC-01至FSC-57。V1.13补记：这是要求，不是当前状态。调度器单元TB的检查标签是TB内场景序号，与本表同号条目含义不同（例如TB FSC-14对应本表FSC-03，TB FSC-32对应本表FSC-30），逐条对应关系与当前证据状态见别名表FSC对照行与矩阵§13（ID=FSC-01～FSC-57）。已知FSC-19/23/24/27/44当前无证据，FSC-18/34/35/48/53/57只有部分证据（`verification_reports/ID_GOVERNANCE_AUDIT_FOLLOWUP_20261005.md` §2；FSC-35按`verification_reports/SSW18_TICK385_INVESTIGATION_20261006.md` §5改判为部分）。所有PASS必须来自信号比较，不得使用无条件PASS打印；不得再用“启动后固定4拍产生ADC完成”的桩模型替代真实CLK_DOUT完成路径。

质量闭环包括：

1. formatter-AST严格检查；
2. 独立Verilog lint；
3. Vivado `xvlog`、`xelab`和`xsim`；
4. Vivado综合；
5. Latch=0；
6. Blackbox=0；
7. 2 MHz时序满足；
8. 记录LUT、寄存器、DSP、WNS/TNS和非阻断警告。

## 20. Current V1.7 Frozen Rule Set

V1.7 retains and normatively restates the following frozen Scheduler rules:

- 一个400 Hz宏帧固定为5000个2 MHz周期；
- 双光固定RED先、IR后，每颜色400 Hz，每宏帧两笔ADC事务；
- RED和IR共享`frame_id`，但使用不同且连续的`sample_index`；
- NORMAL RED/IR模拟波形上下文分别在macro tick 0/160接管；
- 波形上下文不建立AMI结果事务，也不消费正式`sample_index`；
- ADC结果owner在匹配波形接管后独立提交，NORMAL RED/IR截止点为283/443，校准截止点为248；
- IR波形接管不等待RED owner释放，但任一时刻最多只有一个ADC结果owner；
- NORMAL同色Q3中心在SAR9/SAR15之间严格一致，RED/IR分别固定为macro tick 300/460；
- 单光模式不得搬移上下文接管点或Q3；
- SAR9/SAR15预建立时长和结果返回延迟允许不同；
- AMB_CAL/DCS_CAL固定使用3200 Hz SAR9子周期；
- AMB_CAL、DCS_CAL RED和DCS_CAL IR统一在local tick 0接管，后续Q3统一为local tick 266；
- `o_calibration_local_tick`是安全选择wrapper唯一的0至624校准相位源；
- 每个400 Hz宏帧最多8个快速校准事务容量；
- 周期重检为AMB、DC_R、DC_IR三个有序阶段，容量不足时阶段延长而不伪造完成；
- 宏帧安全边界和IDAC子周期候选提交边界必须分离；
- NORMAL、单光及安全关闭RUN宏帧中，IDAC提交边界与400 Hz宏帧安全边界同拍且每帧最多一次；
- 快速SAR9校准中，IDAC提交边界在每个625拍子周期的局部tick 385产生，每宏帧最多8次；
- 第8个快速IDAC边界允许与macro tick 4760宏帧边界同拍，但不得形成重复提交或双重epoch递增；
- 非RUN、STOP、abort和阻断故障期间不得产生新的IDAC提交边界；
- 调度器只消费AMI校准请求，不重复拥有AMB间隔、搜索或IDAC算法；
- 调度器不接收配置管理器校准计划，只对RUN期间实际校准请求执行NORMAL/输入源/type/SAR9接收资格检查；
- 校准请求只消费一次；波形或owner失败时保留同一请求到下一子帧重试；
- ADC事务元数据在owner start fire时原子绑定并随真实结果返回；
- SAR9跨RED/IR连续保持仅允许`CLK_IREF_IDAC_SAR9_LOW`，其余SAR9控制不得产生额外重叠；
- SAR15跨RED/IR连续保持仅允许四项已确认信号，其他SAR15颜色控制不得产生额外重叠；
- START后在ADC、模拟与SAR时序均安全空闲时提供一次独立IDAC启动边界；
- AMI与SSW故障分别输入，本地调度器fault不得形成反馈组合环；
- 固定波形接管点或owner截止发生反压时禁止迟到握手，且不得移动固定Q3中心。

历史Scheduler V1.3 RTL、TB与`xsim_v13_tb.log`曾报告FSC-01～FSC-57的PASS；该日志是非规范历史证据，不能作为当前合同闭合或当前实现PASS。它仅说明旧版本曾覆盖Scheduler局部场景，不能扩展到SSW、AMI、最终顶层或后续跨模块要求；当前实现证据仍为`EVIDENCE_PENDING`。
