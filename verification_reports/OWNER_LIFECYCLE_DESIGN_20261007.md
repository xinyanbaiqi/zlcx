# "ADC异常下owner生命周期"轮 设计文档（最终版，2026-10-07）

> 状态：用户两轮确认后的最终设计。**第10、11节（用户裁定及附加要求）优先于第0~9节中与之冲突的内容**，例如：k改为按槽位计数；lost sticky放AMI而非调度器；新增cause 8'h07；不改捕获模块；L-5本轮修复。RTL实现在分支`wip/owner-lifecycle`，交接见`verification_reports/OWNER_LIFECYCLE_STEP2_HANDOFF.md`。

基线：origin/main `0ffb439`（RTL同`05a31cf`）。仓库外副本`phase2/rtl2`（`git archive 0ffb439`）。
范围：F-020、S1、L-1、L-2（方案甲）、L-3、L-4、L-5。下文RTL位置一律按"模块+信号名"引用。

## 0. 读码确认的事实（设计依据）

| 事实 | 位置（模块/信号） |
|---|---|
| 唯一ADC owner在三处各存一份：调度器`B_INFLIGHT`、SSW`adc_owner_inflight_o`、AMI`flag_adc_transaction_inflight`；三处都只由真实完成释放（调度器`flag_completion_match`，SSW`flag_owner_release`，AMI`flag_adc_completion_emit`）。abort/STOP只标记丢弃，不释放 | scheduler、SSW、AMI |
| AMI是完成脉冲唯一来源，同一拍广播给调度器和SSW（`o_adc_transaction_complete_event`/`o_adc_complete_sample_index`） | AMI |
| AMI捕获是电平触发：`ppg_adc_async_stage_capture.flag_capture_pending`在start fire置1、捕获后清0；S1身份也在start fire锁存。因此"作废之后、下一笔start之前"到达的旧DONE会走`flag_adc_capture_without_owner`（现有规则：`flag_integration_blocking`+lane 02+集成sticky），不会产生完成脉冲 | capture、AMI |
| 调度器三个owner截止都带`!B_INFLIGHT`；`transaction_start_valid_o`没有截止门控（L-4）；宏帧末`B_INFLIGHT`也会把请求重挂（L-1） | scheduler |
| SSW的Q3/TIA/AFE控制、owner截止sticky都用`flag_*_has_owner`，它只看"有在途owner且槽位相同"，不看属于哪一帧/子帧（L-1的SSW半句、S1的根因之一） | SSW |
| SSW `calibration_timeout_sticky_o`条件含`flag_cal_context_valid`，该标志在local tick 283清零，tick 385恒为0（S1死逻辑） | SSW |
| IDAC只在`i_frame_safe_boundary`(=调度器`o_idac_code_safe_boundary`)提交候选；调度器的三种边界都要求帧活动或START一次性边界；启动搜索中调度器没有请求就不开帧（L-3） | IDAC、scheduler |
| 周期重检内层`ppg_amb_recheck_scheduler.flag_sample_inflight`没有截止/撤销释放路径；AMI外层`flag_calibration_request_inflight`已有SID-05截止释放（F-020） | recheck、AMI |
| AMI lane 01/02/03只在START或abort清零；manager在`i_system_fault_blocking=1`时拒START（L-5） | AMI、supervisor、manager |
| 正式结果discard原因2位：00 STOP、01 abort、10 系统故障，11未用；原样送SPI锁存`reg_mr_latch` | AMI、SPI |
| supervisor原因码表：01~05 AMI、11 调度器、21/22 SSW、31 看门狗；summary bit 9~15保留 | C24 §3、supervisor |
| supervisor看门狗只在STOP episode且物理ADC非idle时计数；"ADC idle、owner在途、DONE不来"在STOP排空中永久卡住（B报告DROPRED实测） | supervisor |
| 回归TB模型：`i_adc_physical_idle`只在DONE响应的5拍内为0，Q3到DONE之间为1。因此"物理idle"区分不了迟到与丢失，只能按时间区分 | tb_ppg_control_top等 |

## 1. 统一的owner释放规则

owner从调度器提交（commit）起，只有下列三种释放，三处（调度器/SSW/AMI）在同一事件上释放：

| 释放 | 触发 | 产出 | 来源 |
|---|---|---|---|
| R1 真实完成（success=1） | AMI捕获+S1身份与owner逐位一致，非丢弃 | 正式RAW/结果；调度器置RED/IR_DONE | 现有 |
| R2 受控失败（success=0） | 真实DONE到达但该owner已被abort/STOP标丢弃、或测试错配受控释放 | 无数据；NORMAL帧`B_FRAME_FAILED`（非丢弃时） | 现有 |
| R3 超时作废（新，T-lost） | AMI在途owner年龄≥`T_LOST`，且物理ADC idle（`i_adc_idle=1`），且AMI捕获流水里没有该事务的完成（`!flag_capture_valid && !flag_adc_completion_pending`），且本拍无正式结果discard、非START | 不产生RAW/结果/success；AMI发`o_adc_transaction_lost_event`（同拍在`o_adc_complete_sample_index`上给出该owner序号）；调度器、SSW按序号+代际匹配释放；AMI发measurement discard（原因码新`2'b11`，身份=该owner，sample_valid=0）；调度器置诊断sticky与`B_FRAME_FAILED`；校准owner同时撤销在途请求并重发同一候选 | 新 |

R3不是"伪造完成"：它是独立的作废事件，不置complete_event、不置success，下游数据链完全不动。

**互斥与同拍优先级**（逐路核对过）：
- R1/R2 与 R3：R3要求流水中无捕获/无待发布完成，R1/R2要求`flag_adc_completion_pending`，构造上不可能同拍；完成在流水中时R3等待（R3是电平条件，不是单点比较）。
- R3 与 abort/STOP 同拍：abort/STOP只标记丢弃不释放，R3照常释放。SSW：沿用F-035的"释放优先于abort保持"；调度器：abort把`B_INFLIGHT_DISCARD`置1，同拍R3匹配分支随后清`B_INFLIGHT`。若同拍还有正式结果discard，R3推迟一拍（避免两条discard抢同一组输出寄存器）。
- R3 与截止事件：三个截止都要求`!B_INFLIGHT`，R3事件在下一拍才被调度器看到，截止只可能在之后发生（例：RED作废后挂着的IR pending在下一拍按截止收尾），不同拍。
- R3 与新提交：调度器在作废事件那拍`B_INFLIGHT`仍为1，不会提交；AMI在发出事件的同一沿已清在途，下一拍起才可能接受新start。
- R3 与START：START清全部状态，R3在START拍被屏蔽。
- 作废后旧DONE：下一笔start之前到达 → 现有`flag_adc_capture_without_owner`：集成阻断+lane 02+集成sticky → supervisor开episode → abort+STOP。不广播完成，所以不会错绑。下一笔start之后到达在物理上与新事务的DONE无法区分（数字侧无法解决，交B写进合同前提）。

**连续丢失（T-dead）**：AMI计"连续作废次数"，任何一次与owner匹配的真实完成（R1或R2）清零，START清零。第k次作废的同一拍置新lane 06（`flag_owner_lost_fault_hold`）并排队故障记录cause `8'h06`；lane 06计入`o_ami_fault_active`与`o_wrapper_fault_blocking`。supervisor开episode→abort+系统STOP；abort清lane 06（与lane 02/03同规则）→episode关闭→排空正常结束→软件COMMIT/START（或先诊断清除再START）即可重启，不需复位。第k次作废本身照常释放owner，所以排空不会卡。

**（建议，需用户定）ADC长期不回idle**：在途年龄≥2×T_LOST仍因物理非idle无法作废时，同样置lane 06报故障（不释放owner）；排空期间由现有看门狗再报0x31，ADC回idle后R3作废、排空结束。否则RUN中"ADC忙、DONE不来"仍是静默停滞。

## 2. owner与帧/子帧绑定（S1与L-1共用）

- 调度器侧不需要新绑定：只有一个owner；L-1修复（宏帧末不重挂在途owner的请求）+R3（同槽位下次接管前作废）保证"新上下文的Q3不会在旧owner名下执行"。
- SSW侧加绑定，作为第二道防线并修S1：
  - 新寄存器`reg_owner_cal_subframe`（3位）：校准owner提交时锁存`i_calibration_subframe_index`。
  - "当前上下文的owner"判据：RED槽`reg_owner_frame_id == reg_red_frame_id`；IR槽`reg_owner_frame_id == reg_ir_frame_id`；CAL槽`reg_owner_frame_id == reg_cal_frame_id && reg_owner_cal_subframe == i_calibration_subframe_index`。新一帧同色上下文接管时`reg_red/ir_frame_id`更新，旧owner自动失去绑定。
  - 用于：Q3/TIA/AFE/LED控制（L-1：旧owner不再驱动新上下文的Q3）、owner截止sticky（旧owner不再掩盖新上下文的截止）、S1 sticky。
  - S1：`calibration_timeout_sticky_o`改为"local tick 385 && 校准帧活动 && 有绑定到本子帧的校准owner仍在途"，去掉`flag_cal_context_valid`项。语义=迟到诊断（非阻断）；丢失由R3报告。

## 3. 阈值

### 3.1 T_LOST = 4500拍（2.25 ms = 0.9个400 Hz宏帧 = 7.2个校准子帧），按owner年龄计（从start fire起数2 MHz拍）

约束（下界取实测合法迟到最大值，上界取同槽位下一次接管）：
- 下界：B实测最晚合法迟到`LATE6SF`：owner在sf1 lt1提交，DONE在sf7 lt606被合格消费，年龄 = 6×625+605 = **4355拍**（`lost_completion_20261006/run_LATE6SF.log`：`MON OWNER sf=1 lt=1` → `MON DONE sf=7 lt=606`）。其余迟到：LATE385 405拍、LATENEXT 730拍、LATE2SF 1355拍。NORMAL正常完成年龄307（RED）/159（IR）。
- 上界（NORMAL，"下一帧同色接管前"）：RED owner最晚在tick 283提交（SSW窗口≤283），下一帧RED接管在下一帧tick 0；IR最晚443提交，下一帧IR接管在tick 160。年龄下限 = 5000−283 = 5160−443 = **4717拍**（F-009修后5000拍帧；现5001拍帧为4718）。
- 上界（校准，"下一宏帧sf0前"）：L-1修复后，校准owner在途时AMI不会发新请求、调度器不重挂，下一次校准接管只可能在作废/完成之后发生，结构上满足；按年龄4500作废时，sf0提交的owner在sf7 lt≈126作废并在本宏帧内重试（滚入下一宏帧）。
- 取4500：比4355多145拍，比4717少217拍；不依赖帧相位，F-009修复（帧长5001→5000）不影响；STOP排空、帧停止、abort后帧被撤销时照样计时（解决情形④）。
- 既有TB余量：SMOKE-09故意挂起owner约3300拍（从提交算）并断言"owner不被提前释放"，4500仍大于它。

### 3.2 k = 2（连续两次作废升级为系统故障）

- 单次丢失（B的DROPRED/DROPIR）：作废后同一帧内恢复，下一帧正常（预期，待仿真确认），k=2不会升级。
- ADC失联（DEAD/DEADADC）：NORMAL每帧RED owner都会作废，第2次作废约在第一次之后一帧（≈5000拍=2.5 ms），即失联后约4.75 ms报故障；校准侧作废→重试→再作废，约9000拍。
- k=1等价于方案乙（任何一次丢失都STOP）；k=3只是多等一帧，没有额外区分能力。计数在任何真实完成后清零，所以偶发、非连续的丢失永远不会累积成故障。

## 4. 新原因码

| 码 | 位置 | 编码 | 冲突检查 |
|---|---|---|---|
| measurement discard原因 | AMI `o_measurement_result_discard_reason`（2位，原样到SPI锁存） | `2'b11` = COMPLETION_LOST（超时作废） | 现用00/01/10，11空闲；位宽不变；`o_detection_discard_reason`与私有datapath discard不用此码 |
| supervisor故障原因 | AMI故障记录→supervisor | cause `8'h06` = "ADC连续完成丢失（或长期不回idle）"，source `4'h1` AMI，summary bit 9（`16'h0200`） | C24 §3：06未用，bit 9保留；supervisor只需在summary映射里加一行 |

discard对校准owner也发（`frame_type`区分AMB/DCS/NORMAL，`sample_valid=0`）。

## 5. 端口与连线方案（推荐：AMI发起作废，复用SID-05撤销链并合并F-020）

为什么由AMI发起：AMI是完成脉冲唯一来源与discard的所有者，知道捕获流水里有没有该事务的完成（可彻底消除"作废与迟到DONE同拍"的竞争），又直接持有owner完整身份与k计数所需的完成事实。若由调度器发起，还需另加AMI→调度器"流水静默"端口，且两边各存一份计时。

| 模块 | 新增/改动 | 说明 |
|---|---|---|
| AMI | 新参数`C_ADC_COMPLETION_LOST_CYCLES=4500`、`C_ADC_COMPLETION_LOST_LIMIT=2`；新输出`o_adc_transaction_lost_event`；`o_adc_complete_sample_index`在作废拍给出被作废owner序号；discard原因加`2'b11`；新lane 06/cause `8'h06`；内部"校准请求撤销"=`i_cal_owner_deadline_event` 或 校准owner作废（SID-05链路合并），既清`flag_calibration_request_inflight`，又（请求来源为周期重检时）送PWI | 年龄计数器、连续作废计数器、lane 06为新寄存器 |
| 调度器 | 新输入`i_adc_transaction_lost_event`、`i_idac_boundary_request`；新输出`o_owner_lost_sticky`；L-1、L-3、L-4修改 | 作废匹配释放、`B_FRAME_FAILED`、新sticky位`B_OWNER_LOST`（诊断清除/START清，与其它调度器sticky同规则）；不匹配的作废事件按DONE错配处理 |
| SSW | 新输入`i_adc_transaction_lost_event`；新寄存器`reg_owner_cal_subframe`；绑定判据；S1 | 释放=（完成或作废）且序号+代际匹配；不匹配的作废与不匹配的DONE一样记事务错配 |
| PWI | 新输入`i_calibration_request_withdraw_event`，透传 | 纯连线 |
| AMB重检调度器 | 新输入`i_calibration_request_withdraw_event`：清`flag_sample_inflight`（F-020） | 只有本模块发出的请求在途时才有效果 |
| supervisor | summary映射加`8'h06→bit 9` | 一行 |
| control_top | 连线：AMI作废事件→调度器/SSW；AMI三个`o_*_pending_valid`（现悬空）或→调度器`i_idac_boundary_request`；新输出`o_scheduler_owner_lost_sticky` | 纯连线 |
| 芯片顶层+SPI | （若选择导出sticky）`o_scheduler_owner_lost_sticky`→SPI 0x0108 bit 6（现保留位）；芯片TB DIAG-MAP38期望模型加该位 | 可选，见待定项 |
| IDAC | 不改 | 作废后IDAC的保持请求仍在，AMI重发同一候选 |

## 6. L-3、L-4、L-5的修法

- **L-4**（调度器）：`transaction_start_valid_o`增加"候选已过期"屏蔽：RED候选且`macro_tick > 283`、IR候选且`> 443`、校准候选且`local_tick > 248`。等号那一拍仍允许按时提交（与SSW窗口≤截止、V1.9 tick 248规则一致），提交优先、截止不报；过期那拍不提交，截止分支照常把pending清掉并记sticky/帧失败——不会出现"截止也不报、提交也不做"的空拍。
- **L-1**（调度器）：宏帧末重挂条件去掉`B_INFLIGHT`项（保留`CAL_REQ_PENDING || CAL_WAVE_PENDING`）。在途owner随后由迟到完成（AMI消费结果后再发下一请求）或R3作废（AMI撤销并重发同一候选）推进。SSW绑定为第二道防线。
- **L-3**（调度器）：新增"空闲IDAC边界"并入`o_idac_code_safe_boundary`：`i_idac_boundary_request && flag_lifecycle_active && i_active_config_valid && !B_STARTUP_PENDING && !B_FRAME_ACTIVE && !flag_frame_start_eligible && !i_normal_measurement_eligible && 无任何pending/在途/校准请求pending && i_adc_idle && i_analog_safe && i_sar_timing_idle`。只在"启动搜索中、调度器空闲、本拍不会开帧、IDAC有候选待提交"时出现；IDAC提交后pending清零，下一拍条件即消失（单拍）。NORMAL资格成立时（含周期重检）不出现，NORMAL帧的码提交时序不变。排除`flag_frame_start_eligible`是为了避免"同沿开帧锁存旧码、IDAC提交新码"造成启动载荷不一致。
- **L-5**（AMI）：lane 01/02/03（及新lane 06）增加清零条件"当前RUN已被STOP结束且AMI全链排空"（`flag_run_context_ended && o_datapath_empty`，N-1已引入的同一判据）。理由：三个lane注释与C10 §15.2都是"保持到本RUN结束"，STOP也结束RUN；`flag_integration_blocking`本身生命周期不变（仍由START/abort清），只是不再撑住supervisor的episode。**本轮的新机制使L-5在生产构建中变得可达**（T-dead episode中abort之后、排空期间到达的迟到旧DONE会置lane 02），所以必须修，不能只列形式验证。AMI单元TB HIST-RERUN的"空闲期fault-active仍为1"期望随之改为0（负对照：去掉新清零项FAIL）。

## 7. 对现有机制的影响（逐路追踪结论，实施时逐项仿真）

| 机制 | 影响 | 核对/实测安排 |
|---|---|---|
| SID-05截止链 | 截止事件仍只在`!B_INFLIGHT`时产生；AMI撤销源由"截止"扩为"截止或校准作废"，清同一个`flag_calibration_request_inflight` | SID-05-AMB/DCR/DCIR系统检查不变；AMI单元新加作废撤销检查 |
| F-020 | 撤销事件经PWI到重检调度器，清内层在途 | AMI/重检单元：截止后请求重发（原探针f020场景） |
| supervisor episode/看门狗 | 看门狗不改；新cause 06走AMI记录路径；lane 06由abort清→episode随即关闭 | 系统TB：k次丢失→STOPPING→CONFIG→START被接受，lifecycle与blocking逐拍追踪 |
| STOP排空 | R3在排空中照样计时，在途owner作废后`o_datapath_empty`/调度器idle可成立 | 系统TB情形④；排空结束后`flag_run_context_ended && o_datapath_empty`成立→N-1与L-5依赖它 |
| START门控链 | manager←supervisor blocking←三路fault_active；AMI五路+lane 06逐路核对：01/02/03/06 = START/abort/RUN结束排空清；04/05 = PWI/IDAC自身（STOP清）；调度器active=PROTOCOL/MISMATCH（诊断清除）；SSW active=两个阻断sticky（诊断清除） | 每个故障场景都实测"STOP后START是否被接受"，不符即停 |
| INJ-02/P06/LFA-08 | 测试身份hold期间`flag_adc_completion_pending=1`，R3被排除；lane清零新增项只在STOP结束+排空后生效，abort路径时序不变 | injection TB全量比对 |
| LFA-04/OIB-08/SMOKE-06/09/10 | 均在4500拍内送达DONE或abort，不触发R3 | 全量回归逐TB比对PASS行与$finish时刻 |
| OIB反压 | 反压只卡在捕获/S1之后，R3要求`!flag_capture_valid && !flag_adc_completion_pending`，不受影响 | OIB全量比对 |
| SID-06/SSW Q3 | 绑定只在"旧owner跨入新同色上下文"时生效，正常时序下判据恒真 | SSW单元+19-TB比对 |
| NORMAL帧完成计数/周期重检间隔 | 作废帧`B_FRAME_FAILED`，不计完成帧，与现有success=0一致 | 系统TB |
| 芯片层 | 若导出sticky，DIAG-MAP38期望更新 | 芯片TB |

## 8. 验证计划

1. 单元级（每项负对照：旧RTL或去掉修复项须FAIL）：
   - 调度器TB：LOST-REL（作废匹配释放+帧失败+sticky）、LOST-MISM（不匹配作废→错配）、L1-NOREPEND、L4-EXPIRE（RED/IR/CAL过期不提交、等号拍仍提交）、L3-IDLEBND（空闲边界单拍、NORMAL资格时不出现、即将开帧时不出现）。
   - SSW TB：LOST-REL、BIND-Q3（旧owner不驱动新帧Q3）、S1-LATE（迟到置sticky、按时不置、上一子帧owner不置）。
   - AMI TB：LOST-FIRE（年龄/idle/流水条件、discard 11与身份）、LOST-RACE（完成在流水中不作废）、LOST-K（第2次→lane 06/cause 06，真实完成清零计数）、WDRAW（截止或校准作废→撤销并重发）、L5-CLR（STOP结束排空后lane落下、START被接受）、HIST-RERUN期望更新。
   - 重检TB：F020-WDRAW；supervisor TB：SUM06。
   - 标签全部TB本地名（不接合同族编号），注明服务的F/L号。
2. 新系统TB `tb_ppg_control_top_adc_anomaly.v`（由B两份临时TB改成永久回归）：①单次丢失RED/IR各一次后作废恢复、下一帧正常；②LATE385/LATE6SF等合法迟到不作废、S1报迟到；③NORMAL与校准各一组连续丢失→cause 06→STOP后不复位重启成功；④STOP排空中丢失不卡；⑤作废后旧DONE→拒绝、不错绑、升级故障且可重启；⑥L-1(NODONE/DROPIR)、L-3(LATE6SF)、L-4(DROPRED)、L-5原场景；⑦NORMAL与校准两路。全程活性监视器：RUN/STOPPING中连续3帧（15000拍）既无完成/作废/结果/码提交/生命周期变化、也无故障记录 → FAIL。
3. gate/-Wall前后逐条对比；全套回归按导出提交分组并行，与05a31cf逐TB比对PASS行与$finish时刻。

## 9. 待用户确认

1. T_LOST=4500拍；2. k=2；3. 原因码`2'b11`与`8'h06`；4. 端口方案（AMI发起；sticky是否经SPI 0x0108 bit 6导出）；5. L-5本轮修复；6. ADC长期不回idle是否顺带报故障。

---

## 10. 用户第一轮确认（2026-10-07）与据此补充的设计

### 10.1 已定
- T_LOST = 4500拍。
- k = 2，**按槽位分开计数**（RED、IR、CAL各一个"连续作废"计数器）：只有同一槽位与owner匹配的真实完成（R1/R2）清零该槽位计数；任一槽位连续作废2次即升级。截止撤销不计数，只统计真正的作废（R3）。
- 编码按AMI发起：discard `2'b11`=COMPLETION_LOST；cause `8'h06`、source `4'h1`、summary bit 9（`16'h0200`）。
- 端口：AMI发起 + 诊断sticky经SPI导出（0x0108 bit 6）。

### 10.2 T_LOST上限只取"NORMAL下一帧同色接管"的理由（逐路追踪）

**(a) 换槽位接管**（例：校准owner在途时下一宏帧是NORMAL；RED owner在途时同帧IR接管；IR owner跨帧时下一帧RED接管）。新上下文拿不到owner，也不会被旧owner的转换冒充：
- 调度器：三个候选`flag_candidate_calibration/red/ir`都要求`!B_INFLIGHT`。`B_INFLIGHT`只由提交置1；由匹配完成、匹配作废（新）、START、复位清0。旧owner在途期间不可能提交新owner。另一槽位的截止被`!B_INFLIGHT`屏蔽；pending在宏帧末拍被清除，该帧拿不到对应颜色的DONE，不计完成帧。
- SSW：RED/IR/CAL的TIA、AFE、Q2/Q3、LED控制分别要求`flag_red/ir/cal_has_owner`。它们都要求`reg_owner_slot`等于本槽位，`reg_owner_slot`只在owner提交时由当时的候选槽位写入。所以旧owner绝不会驱动另一槽位的Q3：另一槽位的波形没有Q3、不启动转换、不产生CLK_DOUT。该槽位的SSW截止sticky（`flag_red/ir/cal_timeout`）照常置位。
- AMI：`transaction_start_ready_o`要求`!flag_adc_transaction_inflight`，旧owner在途期间不会有新的start fire，捕获与S1身份始终属于旧owner。
- 结论：旧owner的迟到DONE只可能来自它自己的转换，绑定正确；作废只是让它在4500拍时让位。

**(b) 校准同槽位再接管**。要接管新的校准上下文，必须先有`B_CAL_REQ_PENDING`：
- `flag_cal_context_due`在sf0要求帧开始时`CAL_REQ_PENDING`已转成`CAL_REQ_ACTIVE`，在其它子帧要求`B_CAL_REQ_PENDING`；滚动`flag_calibration_rollover`要求`!B_INFLIGHT`。
- `B_CAL_REQ_PENDING`的置1来源：①请求握手`flag_calibration_request_fire`；②宏帧末重挂（L-1修复后去掉`B_INFLIGHT`项，只剩`CAL_REQ_PENDING || CAL_WAVE_PENDING`）。
- 请求握手要求AMI`calibration_sample_valid_o=1`，而它只在`!calibration_sample_valid_o && !flag_calibration_request_inflight`时置1。
- `flag_calibration_request_inflight`的清0来源：STOP、abort、集成阻断、结果被IDAC消费、截止事件（要求`!B_INFLIGHT`）、校准作废撤销（新）。
- 结论：校准owner在途且未作废、未完成时，以上来源都不成立，不会有新的校准接管。

**(c) NORMAL同色**：RED下一次接管在下一帧tick 0，IR在tick 160，没有类似的请求门控，只能靠"在接管前作废"。所以上界取4717拍。

### 10.3 ADC一直不回物理空闲（方案甲前提之外）
- 不作废：R3要求`i_adc_idle=1`。
- RUN中：owner年龄≥`2×T_LOST`=9000拍且仍无法作废时，置lane 06、报cause `8'h06`（不释放owner）→ supervisor episode → abort+STOP。
- 进入STOPPING后：现有看门狗在ADC非idle时计数，5000拍后报`8'h31`。ADC回idle后，R3作废，排空随即结束；ADC永不回idle时停在STOPPING，但已报两条故障，不是静默。
- 这条路径不计入按槽位的k计数。
- 与"丢失"的区分：丢失路径在故障之前已有discard 11和lost sticky；长期忙没有。

### 10.4 按槽位k=2时各路报故障时间（T_LOST=4500，理论值，待仿真实测）
- NORMAL RED一路失联（IR正常）：第1次RED作废在帧N tick≈4501，第2次在帧N+1 tick≈4501，**约在第一次作废后5000拍（2.5 ms）报故障**，即首个丢失提交后约9500拍。
  - 同帧IR因RED在途无法提交，在RED作废后的下一拍按截止收尾。这不是作废，IR计数不变。
- NORMAL IR一路失联：IR在tick≈309提交，作废在≈4809；下一帧同理，约5000拍后报故障。
- 校准失联：作废→撤销→重发同一候选→下一个子帧或滚入宏帧再提交→再过4500拍作废。约在第一次作废后4500~5100拍报故障。
- 双路同时失联：由先到第2次的槽位触发，行为同原方案。

### 10.5 已知限制（写进交B清单）
- 同一槽位间歇丢失、从不连续丢两次时不会升级：
  - 每次丢失都有discard（原因11，身份完整）和lost sticky，软件经SPI可见；
  - 该槽位每次丢失都让当帧失败。
- 作废之后、下一笔start之前到达的旧DONE：被拒绝并升级。下一笔start之后到达的旧DONE，在物理上与新事务的DONE无法区分（数字侧不可解，写成合同前提）。
- discard原因`2'b11`是2位字段的最后一个空位，以后再新增原因需加宽字段。

### 10.6 端口方案细化（按用户要求）
1. **AMI是唯一裁决点**：R3除`i_adc_idle`外，还要求捕获通路中没有该事务的完成，即同时满足：
   - 所选精度的DONE同步末级为0（需从`ppg_adc_async_stage_capture`新导出一个已同步电平，见第11节待定项）；
   - `!flag_capture_valid`；
   - `!flag_adc_completion_pending`。

   完成一旦进入同步末级，就优先于作废。

   完成脉冲要求`flag_adc_completion_pending`，而后者只在"捕获交接且在途"时置位，作废同一沿清在途。因此作废事件与完成事件在结构上不可能同拍。AMI单元TB加逐拍断言：两者同拍即FAIL。

   剩余的异步边界：DONE恰好处于同步首级（亚稳态级，按CDC规则不得驱动逻辑）的那一拍。这时作废先发生，该DONE随后按"无owner捕获"被拒绝并升级。这是唯一的不可再缩小的窗口（1拍），作为合同前提写明。
2. **`o_adc_complete_sample_index`的全部接收方**（RTL）：
   - 调度器只在`flag_completion_match`中使用，以`i_adc_transaction_complete_event`限定；
   - SSW只在`flag_owner_release`中使用，以`i_adc_transaction_complete_event`限定；
   - control_top只做转发（`ami_adc_complete_sample_index_o`），不对外导出；
   - TB接收方：OIB TB的owner表以`complete_event && success`限定；调度器、SSW、AMI单元TB在实施时逐个核对。

   本轮把调度器、SSW的使用点改为"以完成或作废事件限定"，并分开判定：作废不会被当成完成，也不会置success或RED/IR_DONE。
3. **撤销合并（F-020）**：
   - AMI内部撤销 = `i_cal_owner_deadline_event` 或 校准作废；
   - 撤销清`flag_calibration_request_inflight`；请求来源为周期重检时，同时经PWI送重检调度器清`flag_sample_inflight`；
   - k计数只在R3作废时加1。
4. **lost sticky清除规则**：
   - 复位清；
   - 诊断清除在"无活跃阻断（lane 06未保持）或当前RUN已由STOP结束且AMI排空"时可清；
   - 新START不清（F-022原则）。
5. **SPI 0x0108 bit 6**：已核实RTL为`{2'b00, …}`常数0，芯片合同地图写明"bits[7:6]保留"。用作lost sticky；芯片TB DIAG-MAP38期望同步更新，并做负对照。

### 10.7 补充测试（系统TB）
- 校准完成丢失、下一宏帧为NORMAL（周期重检路径）：不错绑；NORMAL该帧没有Q3、没有正式结果；校准owner在4500拍作废后，重试并正确完成。
- RED完成丢失：作废时刻 = 提交后4500拍，且早于下一帧RED接管（同一帧tick≈4501），逐拍断言。
- 只有RED一路持续丢失（IR正常）：在第2次RED作废时报cause 06。
- RED丢一次、下一次RED正常完成：RED计数清零，之后再丢一次也不报故障。
- 连续丢失故障之后，STOP→诊断清除→START成功（不复位），并断言supervisor blocking与AMI fault-active在排空完成时为0。
- 芯片顶层TB：经SPI读回0x0108 bit 6（lost sticky）、0x0114中discard原因=11（正式结果discard锁存）、0x010B cause=0x06、0x0113 bit 1（summary bit 9）。

## 11. 用户第二轮确认（2026-10-07）

### 11.1 L-5：本轮修复
- 改法：
  - AMI lane 01/02/03和新lane 06、07增加清零条件`flag_run_context_ended && o_datapath_empty`；
  - `flag_integration_blocking`的生命周期不变。
- 同拍优先级：复位 > START/abort清零 > lane置位（新故障）> RUN结束排空清零。与C24 §4"新故障优先于清除"一致。
  - 实际上lane置位源（无owner捕获、错配完成等）发生的那一拍`flag_capture_valid`或流水非空，`o_datapath_empty=0`，两者不会真正同拍；仍按上述顺序写成if-else链。
- 迟到旧DONE的三种情况（作废不清捕获模块的`flag_capture_pending`，因此旧DONE一定会被捕获并留下记录）：

  | 情况 | 结果 | 留下的记录 | 恢复 |
  |---|---|---|---|
  | ①排空期间到达 | 无owner捕获 → 集成阻断+lane 02+集成sticky；AMI记录cause 02；episode已开则只更新summary，未开则新开episode（abort+STOP幂等） | AMI集成sticky、supervisor summary bit 1 | 捕获流水排空后`o_datapath_empty`回1 → lane按RUN结束规则落下 → STOPPING结束 → 诊断清除 → START |
  | ②排空完成后的空闲期到达 | 同上；supervisor的STOP请求进manager时不在RUN/STOPPING，按现有规则被拒并记错误码 | 同上，另有manager错误码 | lane按RUN结束规则落下 → 诊断清除 → START（START清集成阻断） |
  | ③下一次RUN、首个start fire之前到达 | 无owner捕获 → 集成阻断+lane 02 → episode → abort+STOP | 同① | abort清lane → STOP排空 → 诊断清除 → START |
  | 下一次RUN首个start fire之后到达 | 与新事务的DONE在物理上不可区分（start fire会清同步链和捕获上下文） | — | 合同前提（已知限制） |

- `o_datapath_empty`在作废路径下能成立：
  - 作废同沿清`flag_adc_transaction_inflight`，`o_adc_chain_idle`随之成立；
  - 其余项（fork、输出、FIR、检测、PWI、重检、校准请求有效/在途）都与被作废事务无关：被作废事务从未进入捕获之后的流水；STOP/abort会清校准请求。
  - 实施时逐项展开表达式核对，并在系统TB中实测。
- 合同依据：
  - C10 §15.2："STOP也结束当前RUN"，与lane注释"保持到本RUN结束"一致；
  - C10 §6："无残留阻断原因时fault-active才落下"：RUN已结束且AMI全链排空，即没有任何在途事务、没有待发布完成，阻断原因已不存在。
  - 交B清单列出：三个lane注释的改动、C10 §15.2/§6的补充文字。

### 11.2 lost sticky放AMI
- 端口链：`o_owner_lost_sticky` → control_top `o_ami_owner_lost_sticky` → SPI 0x0108 bit 6。
- 清除规则沿用N-1：
  - 复位清；
  - 诊断清除在"lane 06未保持"或"RUN已由STOP结束且排空"时可清；
  - START不清。
- 交B清单：
  - 调度器sticky按C08 §16.2在新START时清，AMI历史诊断在新START时不清，两套规则并存；
  - 芯片顶层SPI诊断地图要逐位写明清除方式（一级合同内容）。

### 11.3 ADC长期不回物理空闲：新cause `8'h07`
- 编码：
  - source `4'h1`，summary bit 10（`16'h0400`）；
  - 新lane 07（`flag_adc_busy_fault_hold`）。
- 触发：owner年龄恰好到达2×T_LOST=9000拍那一拍，且仍不满足作废条件（物理非idle）。
  - 每个owner只触发一次，计数器饱和后不再重复触发；
  - 不释放owner；
  - 不计入按槽位的k计数。
- 清零：START、abort、RUN结束且排空。
- 随后走abort+STOP。排空中由现有看门狗再报0x31（ADC非idle时计数）。ADC回idle后：
  - 如果该事务的DONE随之到达，按真实完成释放；
  - 如果没有DONE，年龄已超过4500，按R3作废。

  两种情况下排空都会结束，之后诊断清除→START。ADC永不回idle时停在STOPPING，看门狗0x31与07两条故障都已记录，属于等待复位的状态，不是静默卡住。
- 年龄4717~9000拍期间的Q3：SSW只认绑定到当前上下文的owner。旧RED owner卡忙进入下一帧时：
  - 下一帧RED上下文接管，`reg_red_frame_id`更新，旧owner失去绑定，下一帧RED的TIA/AFE/Q3不产生；
  - 下一帧RED的SSW截止sticky照常置位，不被旧owner掩盖；
  - 调度器不提交新RED owner（`!B_INFLIGHT`），AMI不发新start；
  - ADC恢复后，DONE只可能属于旧owner自己的转换，不会错绑。
- 编码核对：
  - C24 §3：07未用，summary bit 10保留；
  - RTL：supervisor summary映射中07、bit 10都未使用（`flag_new_summary_bits`只映射01~05、11、21、22、看门狗）。

### 11.4 不改捕获模块
- 作废条件在AMI同一拍原子判断：`i_adc_idle && !flag_capture_valid && !flag_adc_completion_pending && 年龄≥T_LOST && 在途`（另加：本拍无正式结果discard、非START）。
- 不可消除窗口约2拍（CDC同步链两级），写成一级合同前提：完成恰好落在窗口内时，先作废，随后的完成按"无owner捕获"拒绝并升级，之后可经STOP→诊断清除→START恢复，不需复位。
- 测试（AMI单元TB逐拍控制，DONE上升时物理idle保持为1以模拟窗口）：
  - 窗口前：DONE已进入`flag_capture_valid`或`flag_adc_completion_pending`，正常完成，不作废；
  - 窗口内：DONE上升在作废前1~2拍，作废先发生，随后捕获被拒、置阻断；
  - 窗口后：作废后再来DONE，同上被拒。
  - 系统TB另测窗口内情况下的STOP→诊断清除→START恢复。

### 11.5 原因码最终表
| 字段 | 码 | 含义 |
|---|---|---|
| AMI正式结果discard原因 | `2'b11` | COMPLETION_LOST（超时作废）；2位字段最后一个空位 |
| supervisor cause | `8'h06` / source `4'h1` / summary bit 9 | 同一槽位连续2次完成丢失 |
| supervisor cause | `8'h07` / source `4'h1` / summary bit 10 | ADC在owner在途时长期（≥9000拍）不回物理空闲 |
