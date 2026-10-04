# PPG NORMAL事务Fork、IDAC跟踪与AMB周期重检接口合同

> V2.1修订日期：2026-10-01。合同补记批次3：amb_recheck RTL V1.1（2026-08-23）把重检调度器的输入`i_adc_idle`改名为`i_precision_takeover_safe`（纯改名，不改逻辑，`ppg_amb_recheck_scheduler.v:75`）。本合同此前两个名字都没有出现，只在第9.2节笼统写作“ADC……排空”。本次在第9.3节表中补`i_precision_takeover_safe`，以及同样缺失的`i_peak_valley_idle`两行，并在第9.2节补写RTL接管条件的准确六项形式（`:179`）。不改变AMR自检验收条款。合同同步记录见`verification_reports/CONTRACT_SYNC_BATCH3_20261001.md`。
> Current normative version: V2, 2026-08-20. Status: `ACTIVE_NORMATIVE`; the NORMAL fork, IDAC tracking and AMB recheck lifecycle rules are normative. System closure is `NOT_CLOSED`; implementation evidence is `EVIDENCE_PENDING`.
> Historical V2 freeze date: 2026-08-08.
> 适用时钟域：2 MHz数字处理域  
> ACTIVE联合配置固定1024 bit；本模块仅消费V4 `[639:0]` 的运行/IDAC字段，V5 `[1023:640]` 由AMI->PWI检测链唯一消费。
> 目标RTL：`ppg_normal_transaction_fork.v`、重构后的`ppg_idac_code_controller.v`及后续测量帧调度逻辑

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C02 | `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` | V4.9 | RUN lifecycle and committed ACTIVE ownership. |
| C05 | `ppg_system_active_config_unpack/ppg_system_active_config_unpack_semantic_contract.md` | V5 | Sole decoded V4 IDAC-field interpretation. |
| C08 | `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` | V1.12 | Frame scheduling and AMB-recheck transaction insertion. |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.4 | AMI parent, transaction fork and generation/discard ownership. |
| C17 | `ppg_system_integration/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` | V2.3 | Sole IDAC pending/code/epoch and local fault owner. |

## 1. 合同目的

本文冻结以下三部分之间的职责、接口和事务行为：

1. NORMAL事务无丢失地分发给正常PPG测量链和IDAC慢速跟踪链；
2. IDAC控制器使用校准后的Stage1残差执行DC_R/DC_IR慢速跟踪；
3. 帧调度逻辑按可编程间隔插入LED关闭的AMB检查事务，IDAC控制器根据检查结果决定是否重新搜索AMB码。

本文不改变Stage1校准、Stage2重构、DC恢复和后续PPG算法的数学合同。IDAC控制仍只观察
DC恢复前的`signed 12-bit calibrated_s1_value`，不得使用15-bit重构结果或DC恢复后的PPG值。

## 2. 已冻结的系统决策

### 2.1 IDAC数字状态

系统保留三组逻辑码：

```text
AMB_CODE
DC_CODE_R
DC_CODE_IR
```

SAR9和SAR15的对应物理IDAC使用同一组逻辑配置码和committed码。数字域不为SAR9和SAR15复制
manual/min/max、连续确认计数器、pending码或code_epoch状态。

9-bit与15-bit事务均使用同一标度的`calibrated_s1_value`。精度切换本身：

- 不清除连续越界计数；
- 不取消已经形成的pending码；
- 不改变committed码；
- 不重新启动AUTO_SEARCH；
- 不递增任何code_epoch。

### 2.2 IDAC模式

| `idac_mode` | 行为 |
| --- | --- |
| `2'b00` MANUAL | 使用ACTIVE manual码；不执行自动搜索、NORMAL慢速跟踪或周期AMB检查 |
| `2'b01` SEARCH_HOLD | 每次合法START执行一次启动搜索；成功后保持，不执行NORMAL慢速跟踪或周期AMB重搜索 |
| `2'b10` SEARCH_TRACK | 每次合法START执行一次启动搜索；NORMAL期间跟踪DC_R/DC_IR，并允许周期AMB检查和必要重搜索 |
| `2'b11` | RESERVED，COMMIT必须拒绝 |

### 2.3 调码目标

IDAC控制只要求把Stage1残差保持在ACTIVE LOW/HIGH窗口内，避免前端超量程。它不负责把残差精确锁定到
窗口中心，也不执行LAS、NLAS或片内系数辨识。

### 2.4 模拟建立

不使用`settle_sample_count`。数字域committed码只在`frame_safe_boundary`更新；帧内模拟时序必须保证
从码值生效到下一次积分之间满足IDAC、参考和PVT建立裕量。

## 3. 系统连接位置

本模块的正式参数至少包括`C_FRAME_ID_WIDTH=16`、`C_SAMPLE_INDEX_WIDTH=16`、
`C_CONFIG_EPOCH_WIDTH=8`、`C_COEF_EPOCH_WIDTH=8`、`C_CODE_EPOCH_WIDTH=4`和
`C_RUN_GENERATION_WIDTH=8`；AMI逐层传入Top参数并在elaboration检查相等。

冻结连接如下：

```text
ppg_adc_s1_programmable_calibrator
                |
                v
ppg_adc_result_router
    | AMB_CAL -------------------------------> IDAC校准样本入口
    | DCS_CAL -------------------------------> IDAC校准样本入口
    |
    ` NORMAL
        |
        v
ppg_normal_transaction_fork
        | measurement分支 -------------------> ppg_adc_pipeline_overlap_corrector
        |
        ` tracking分支 ----------------------> IDAC NORMAL跟踪样本入口
```

`ppg_adc_result_router`继续保持现有AMB_CAL、DCS_CAL、NORMAL互斥路由职责。NORMAL双消费者保持、独立
反压和逐分支单次消费由独立的`ppg_normal_transaction_fork`负责，不把现有纯组合router静默改造成有状态模块。

## 4. 固定字段宽度和编码

| 字段 | 位宽 | 语义 |
| --- | ---: | --- |
| `calibrated_s1_value` | signed 12 | Stage1逐物理位可编程校准残差 |
| `config_epoch` | 8 | 完整ACTIVE配置版本 |
| `coef_epoch` | 8 | Stage1系数组版本 |
| `frame_id` | 16 | 同一PPG采样帧的R/IR配对标识 |
| `sample_index` | 16 | 全局ADC事务顺序号 |
| `precision_mode` | 1 | 0为9-bit，1为15-bit |
| `color_ir` | 1 | 0为红光，1为红外 |
| `frame_type` | 2 | 00 AMB_CAL；01 DCS_CAL；10 NORMAL；11保留 |
| `amb_code_snapshot` | 8 | 本次积分使用的AMB码 |
| `dc_code_snapshot` | 8 | 本次颜色积分使用的DC码 |
| `amb_code_epoch` | 4 | AMB committed码版本 |
| `dc_code_epoch` | 4 | 当前颜色DC committed码版本 |

code_epoch按模16回绕。只有committed码实际改变时才递增；形成pending、精度切换、检查完成但码值不变
均不得递增。

## 5. NORMAL事务Fork合同

### 5.1 代际与终止生命周期

`ppg_normal_transaction_fork`接收并在measurement与tracking两个pending中逐位
保持`i_run_generation[C_RUN_GENERATION_WIDTH-1:0]`。本模块正式参数表声明
`C_RUN_GENERATION_WIDTH=8`，AMI在实例化时逐层传入Top的同名参数，并在elaboration
时拒绝宽度不等。该值只来自manager经ACTIVE wrapper、Top、AMI的层级扇出；fork、
IDAC或重检逻辑不得生成、递增或截断它。AMI的注册
`i_datapath_discard_event/reason/ID`是NORMAL fork尚未送入DC恢复或IDAC的
pending的唯一终止释放路径：无ready、无ack，匹配ID在采样沿恰好一次清除，最早
下一周期才能报告fork empty。它不产生measurement result discard，因为后者只在
DC结果正式measurement fork已建立且未transfer时产生。

STOP、abort和system fault不得以第二个直接清valid端口绕过上述事件。已交给
IDAC的tracking样本按IDAC合同取消；已交给measurement链的样本按AMI私有
datapath discard或正式fork discard完成。陈旧generation不得输出、更新IDAC
pending、推进重检或绑定新owner。

### 5.2 强制端口扩展

`ppg_normal_transaction_fork`正式声明
`i_run_generation[C_RUN_GENERATION_WIDTH-1:0]`、
`i_datapath_discard_event`、`i_datapath_discard_reason[1:0]`、
`i_datapath_discard_identity_valid`、完整`i_datapath_discard_<TXN_ID>`、
`o_measurement_run_generation[C_RUN_GENERATION_WIDTH-1:0]`、
`o_tracking_run_generation[C_RUN_GENERATION_WIDTH-1:0]`及`o_local_empty`。AMI是
generation和discard组的唯一生产者；measurement链和IDAC tracking链各自消费其
对应保持型generation输出；AMI是`o_local_empty`唯一聚合消费者。所有这些端口均为
2 MHz注册信号，复位为0；discard无ready/ack且其完整载荷在采样沿稳定。

### 5.1 模块职责

`ppg_normal_transaction_fork`必须：

1. 只接收router已经判定为NORMAL的保持型事务；
2. 为measurement分支保存完整NORMAL载荷；
3. 为tracking分支保存IDAC判断所需的校准值和事务身份；
4. 允许两个分支在不同周期完成握手；
5. 保证同一输入事务在每个分支恰好消费一次；
6. 任一分支反压时保持该分支valid和全部载荷稳定；
7. 复位时清除全部valid、占用状态和分支消费状态。

它不得解释LOW/HIGH、修改码值、判断搜索模式或产生AMB重检请求。

### 5.2 输入事务

输入握手定义为：

```text
normal_input_transfer = i_normal_valid && o_normal_ready
```

输入必须包含当前router NORMAL分支的完整载荷：

| 输入字段 | 位宽 |
| --- | ---: |
| `i_calibrated_s1_value` | signed 12 |
| `i_calibration_applied` | 1 |
| `i_saturation_low`、`i_saturation_high` | 各1 |
| `i_config_epoch`、`i_coef_epoch` | 各8 |
| `i_detect_code` | 9 |
| `i_stage1_raw` | 10 |
| `i_stage1_code_ext` | signed 11 |
| `i_stage2_raw` | 10 |
| `i_precision_mode` | 1 |
| `i_frame_id`、`i_sample_index` | 各16 |
| `i_color_ir` | 1 |
| `i_frame_type` | 2，必须为`2'b10` |
| `i_amb_code_snapshot`、`i_dc_code_snapshot` | 各8 |
| `i_amb_code_epoch`、`i_dc_code_epoch` | 各4 |

### 5.3 measurement分支

measurement分支必须完整、逐位不变地输出全部输入载荷，直接连接
`ppg_adc_pipeline_overlap_corrector`的现有NORMAL输入接口。

```text
measurement_transfer = o_measurement_valid && i_measurement_ready
```

该分支不得因为IDAC模式为MANUAL、SEARCH_HOLD、SEARCH_TRACK或IDAC正在等待安全提交而丢弃事务。

### 5.4 tracking分支

tracking分支输出：

| 输出字段 | 位宽 | IDAC用途 |
| --- | ---: | --- |
| `o_track_calibrated_s1_value` | signed 12 | 唯一主比较量 |
| `o_track_calibration_applied` | 1 | 正式NORMAL跟踪资格 |
| `o_track_saturation_low/high` | 各1 | 明确越界方向 |
| `o_track_config_epoch` | 8 | ACTIVE版本一致性检查 |
| `o_track_coef_epoch` | 8 | 校准版本诊断 |
| `o_track_precision_mode` | 1 | 事务追踪；不分裂控制状态 |
| `o_track_frame_id` | 16 | 事务追踪 |
| `o_track_sample_index` | 16 | 单次消费和顺序检查 |
| `o_track_color_ir` | 1 | 选择DC_R或DC_IR状态 |
| `o_track_frame_type` | 2 | 必须保持NORMAL编码10 |
| `o_track_amb_code_snapshot` | 8 | 诊断和一致性追踪 |
| `o_track_dc_code_snapshot` | 8 | 与当前颜色committed码比较 |
| `o_track_amb_code_epoch` | 4 | AMB版本诊断 |
| `o_track_dc_code_epoch` | 4 | 拒绝旧DC码样本 |

tracking分支不输出Stage2结果、15-bit重构结果或DC恢复后的PPG值。

```text
tracking_transfer = o_track_valid && i_track_ready
```

### 5.5 保持和消费规则

Fork采用单元素寄存保持结构，输入到两个输出增加一个寄存周期。每个缓存事务至少维护：

```text
occupied
measurement_pending
tracking_pending
payload
```

冻结行为：

- 接收新输入时，两个pending同时置位；
- 某分支握手后只清除该分支pending；
- 另一分支尚未握手时继续保持自己的valid和payload；
- 两个pending均清除后，该事务才从fork释放；
- 允许在旧事务两个分支均于当前沿完成时，同沿接收下一笔事务；
- 不允许把输入valid直接复制到两个输出valid；
- 不允许使用`i_measurement_ready && i_track_ready`作为无状态组合ready而丢失异步分支握手历史。

### 5.6 IDAC分支反压边界

IDAC等待pending码的安全提交、处于MANUAL/SEARCH_HOLD模式或当前样本不具备跟踪资格时，仍必须消费tracking分支事务，
随后在控制器内部明确忽略，不得用长期拉低`i_track_ready`阻塞PPG测量链。

允许IDAC输入流水因内部P0/P1寄存边界产生有限反压，但在无复位和无故障条件下，单笔反压不得超过
三个2 MHz时钟周期。等待下一帧安全边界不属于允许反压原因。

## 6. IDAC样本入口合同

重构后的`ppg_idac_code_controller`具有两个逻辑入口：

1. 校准入口：接收router的AMB_CAL或DCS_CAL事务；
2. NORMAL跟踪入口：接收fork的tracking事务。

两者均采用保持型ready/valid。系统帧调度保证不会在同一时刻要求控制器同时处理校准序列和NORMAL跟踪序列；
若两个入口同时valid，属于上层调度协议错误，控制器不得隐式混合两笔样本。

所有入口都必须在唯一的`valid && ready`上升沿接收一次，不得按valid保持周期重复计数。

## 7. NORMAL DC慢速跟踪合同

### 7.1 跟踪资格

一笔已经由tracking分支握手的事务只有同时满足以下条件时才可进入比较和连续确认：

```text
run_enable == 1
idac_mode == SEARCH_TRACK
dcs_enable == 1
frame_type == NORMAL
calibration_applied == 1
config_epoch == active_config_epoch
dc_code_snapshot == selected_committed_dc_code
dc_code_epoch == selected_dc_code_epoch
selected_dc_pending_valid == 0
controller_fault_blocking == 0
```

`selected`由`color_ir`选择DC_R或DC_IR。任何不合格事务仍被消费，但不得改变比较流水、连续确认计数、
pending码、committed码或code_epoch。

### 7.2 比较定义

正常非饱和样本：

```text
calibrated_s1_value > DCS_THRESHOLD_HIGH  -> ABOVE_HIGH
calibrated_s1_value < DCS_THRESHOLD_LOW   -> BELOW_LOW
LOW <= calibrated_s1_value <= HIGH        -> IN_WINDOW
```

等于LOW或HIGH属于窗口内。

饱和样本优先定义方向：

```text
saturation_high == 1 -> ABOVE_HIGH
saturation_low  == 1 -> BELOW_LOW
```

两个饱和标志不得同时为1；若同时为1，属于事务错误，该样本不参与跟踪并置诊断状态。

### 7.3 连续确认

DC_R和DC_IR分别保存高侧、低侧连续确认计数。两种精度共用对应颜色计数器。

- 同方向越界：对应计数加1，最大保持在`DCS_CONFIRM_COUNT`；
- 窗口内：该颜色高侧和低侧计数同时清零；
- 反方向越界：旧方向计数清零，新方向从1开始；
- 另一颜色事务：不得修改当前颜色之外的计数器；
- 9/15-bit切换：不清零；
- `DCS_CONFIRM_COUNT=1`：第一笔合格越界样本即可形成1 LSB pending；
- 达到确认次数后只形成一次pending，直到该pending提交或取消前不再累计新证据。

### 7.4 调码方向

`dcs_polarity`冻结为：

| `dcs_polarity` | ABOVE_HIGH | BELOW_LOW |
| --- | --- | --- |
| 1 | 码值增加1 LSB | 码值减少1 LSB |
| 0 | 码值减少1 LSB | 码值增加1 LSB |

当前PPG模拟架构预期使用`dcs_polarity=1`，即DC IDAC码增加时抵消电流增大、ADC残差减小。保留极性字段
用于流片表征和测试连接方向变化，不在RTL中写死。

### 7.5 min/max和pending

- pending码必须限制在当前颜色ACTIVE `code_min/code_max`内；
- 已在边界且继续请求越界方向时保持边界码，不允许回绕；
- 边界保持不得产生虚假的`code_update`或code_epoch递增；
- pending形成后只保存相邻1 LSB候选，不立即改变输出码；
- pending等待期间继续接收并忽略NORMAL跟踪样本；
- 配置错误、STOP、restart或阻断故障取消尚未提交的pending。

### 7.6 安全提交和epoch

```text
dc_code_apply = pending_valid && frame_safe_boundary && !config_apply_conflict
```

安全提交沿必须：

1. 更新对应颜色committed码；
2. 仅在码值实际变化时使对应4-bit code_epoch加1；
3. 产生单周期`code_update`和`track_adjust`事件；
4. 清除对应颜色pending和连续确认计数；
5. 后续新ADC事务绑定新的码快照和epoch；
6. 旧epoch事务即使随后到达，也必须被消费但拒绝进入确认计数。

## 8. 启动搜索和模式行为

### 8.1 MANUAL

合法START后，在首个允许的帧安全边界装入ACTIVE manual码。随后保持，不执行搜索、慢速跟踪或AMB周期检查。

### 8.2 SEARCH_HOLD和SEARCH_TRACK

每次合法START按以下顺序初始化：

```text
AMB_SEARCH
    -> DCS_R_SEARCH
    -> DCS_IR_SEARCH
    -> NORMAL
```

未启用的颜色或抵消功能按ACTIVE使能位跳过。任一必要搜索失败时，正式NORMAL_PPG不得提前放行。

### 8.3 8-bit受限二分搜索

搜索区间初始化为对应ACTIVE `code_min/code_max`，候选码为区间中点。候选码必须先形成pending，并在
`frame_safe_boundary`成为committed码；随后产生的AMB_CAL或DCS_CAL事务才允许评价该候选。每笔合格样本：

- 落入窗口：搜索成功，保持已经提交并被本样本观察的当前候选；
- 高于窗口：按对应polarity保留能减小残差的一半区间；
- 低于窗口：按对应polarity保留能增大残差的一半区间；
- 区间仍可缩小：形成下一候选并等待安全边界提交；
- 区间耗尽仍未进入窗口：把最接近目标的边界候选在安全边界提交后置`search_exhausted`。

每次候选码实际提交都更新对应code_epoch。搜索不通过`settle_sample_count`丢弃完整400-Hz样本，模拟建立
由候选码提交后的帧内安全时序保证。

## 9. AMB周期重检合同

### 9.1 启用条件

周期AMB检查只有同时满足以下条件时启用：

```text
run_enable == 1
idac_mode == SEARCH_TRACK
amb_enable == 1
amb_recheck_interval_frames != 0
startup_search_complete == 1
normal_measurement_active == 1
```

MANUAL和SEARCH_HOLD忽略该间隔字段，不发起周期检查。

### 9.2 帧计数

测量帧调度逻辑拥有周期计数器。计数单位是完成的完整400-Hz NORMAL采样帧，不是2 MHz时钟，也不是
单独的红光或红外ADC事务。

```text
normal_frame_complete_event -> counter + 1
counter达到amb_recheck_interval_frames -> 锁存amb_recheck_pending
```

计数器在以下事件清零：

- 合法START后首次进入NORMAL；
- STOP、复位或离开RUN；
- 固定AMB、DC_R和DC_IR三阶段全部完成并重新进入NORMAL。

请求达到周期后必须保持。无论到期时处于9-bit还是15-bit，都等待下一次15-bit到9-bit切换事件，随后才可
在安全边界启动固定三阶段校准；不能只产生可能丢失的单拍脉冲。接管条件还必须满足ADC、NORMAL fork、IDAC、FIR和帧边界全部排空，其中`i_fir_idle=1`表示FIR无待消费输出且当前沿未接收输入。若切换事件发生时FIR未空闲，必须保持等待状态，不能丢弃已经锁存的重检资格。

V2.1补记：上述接管条件在RTL中的准确形式是`flag_takeover_safe = i_precision_takeover_safe && i_normal_fork_idle && i_idac_idle && i_fir_idle && i_peak_valley_idle && i_frame_safe_boundary`（`ppg_amb_recheck_scheduler.v:179`），共六项。上文的“ADC”一项对应`i_precision_takeover_safe`（原名`i_adc_idle`，见第9.3节表）；上文未列出的第六项是峰谷检测空闲`i_peak_valley_idle`。`i_fir_idle`在PWI内接的是FIR与检测fork都排空后锁存的`flag_fir_idle_to_scheduler`（`ppg_precision_window_integration.v:999`）。

### 9.3 调度与控制器握手

系统级语义信号冻结为：

| 信号 | 方向 | 语义 |
| --- | --- | --- |
| `amb_recheck_pending` | 帧计数/调度内部保持 | 周期已到，保持至固定三阶段全部完成 |
| `precision_15_to_9_event` | 精度控制 -> 序列控制 | 允许pending请求在下降段开始处启动 |
| `amb_recheck_accept` | 序列控制 -> 帧计数/调度 | 已在15-bit到9-bit安全边界接管三阶段流程 |
| `i_fir_idle` | FIR -> 序列控制 | FIR无待消费输出且当前沿未接收输入时为1，作为安全接管条件 |
| `i_precision_takeover_safe` | AMI -> PWI -> 序列控制 | AMI复合切换安全资格（V2.1补记），原名`i_adc_idle`，amb_recheck RTL V1.1改名，纯改名不改逻辑。AMI侧为`i_adc_idle && o_adc_chain_idle && o_normal_fork_idle && o_measurement_output_idle`（`ppg_adc_measurement_idac_integration.v:962`），经PWI原样转发（`ppg_precision_window_integration.v:996`），不只是物理ADC空闲；是安全接管条件之一 |
| `i_peak_valley_idle` | 峰谷检测 -> 序列控制 | 峰谷检测器没有待提交事件、允许重检接管时为1（PWI内接`detector_idle_o`，`:1000`）；是安全接管条件之一（V2.1补记） |
| `amb_sequence_start` | 序列控制 -> IDAC控制器 | 启动一次周期AMB检查上下文 |
| `amb_sample_request` | IDAC控制器 -> 序列控制 | 当前检查/搜索需要下一笔LED关闭AMB_CAL样本 |
| `amb_sequence_done` | IDAC控制器 -> 序列控制 | 检查完成或重搜索成功 |
| `amb_sequence_failed` | IDAC控制器 -> 序列控制 | 搜索耗尽，无法恢复到窗口 |
| `dcs_revalidate_request` | IDAC控制器 -> 序列控制 | AMB阶段成功后固定要求重新检查DC_R/DC_IR |

这些信号均位于2 MHz域。事件型信号为单周期；request型信号必须保持到明确accept。
本合同表列出的端口名称、方向和分组是唯一规范，不允许以未来模块的不同端口分组、隐式别名或层次化引用替代。

### 9.4 周期检查序列

```text
NORMAL
    -> 间隔到期并锁存amb_recheck_pending
    -> 等待下一次15-bit到9-bit切换
    -> 等待当前ADC事务和NORMAL fork排空
    -> 第1个9-bit校准帧执行AMB检查或搜索
    -> 第2个9-bit校准帧执行DC_R检查或搜索
    -> 第3个9-bit校准帧执行DC_IR检查或搜索
    -> 三路全部成功后清除pending并恢复正式9-bit NORMAL
```

AMB_CAL继续使用现有`frame_type=2'b00`。周期检查身份由序列控制器和IDAC控制器的
`amb_sequence_start`上下文保存，不增加第四种frame_type编码。

### 9.5 检查结果

当前AMB码下第一笔合格AMB_CAL样本位于窗口内：

- AMB码、AMB code_epoch保持不变；
- 产生`amb_sequence_done`；
- 不清除DC_R/DC_IR committed码；
- 产生`dcs_revalidate_request`并继续固定DC_R、DC_IR阶段。

样本越界时，控制器使用ACTIVE `amb_confirm_count`进行同方向确认。需要更多样本时保持
`amb_sample_request`。达到确认次数后进入AMB受限二分重搜索。

若越界方向反转或样本回到窗口，确认计数按与DC相同的规则清除或切换。

### 9.6 固定DC_R和DC_IR重新确认

周期AMB阶段成功后，只要DCS使能，无论AMB committed码是否实际改变，都必须执行：

1. 产生`dcs_revalidate_request`；
2. 清除DC_R和DC_IR连续确认计数；
3. 保留当前DC_R/DC_IR committed码作为重新检查的初始码；
4. 序列控制器依次执行DCS_R检查和DCS_IR检查；
5. 在窗口内时保持原码和epoch，越界确认后才进入受限搜索；
6. 两个启用颜色均恢复到窗口后才能返回正式NORMAL。

如果AMB码实际改变，仍按既有规则递增AMB code_epoch，并取消两路尚未提交的旧DC pending。固定重新确认
不等于强制重跑搜索；当前DC码在窗口内时直接保留。

### 9.7 默认间隔

ACTIVE默认值：

```text
amb_recheck_interval_frames = 16'd4096
```

在400 Hz完整采样帧率下约为10.24秒。该周期只表示检查时间，不表示每10.24秒必然调整AMB码。

## 10. ACTIVE V4配置扩展

ACTIVE V4保持V3的640-bit总宽度和全部既有字段位置，仅使用V3保留扩展区的一部分：

| ACTIVE位 | 字段 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| `[7:0]` | `schema_version` | 8 | V4固定为`8'h04` |
| `[575:0]` | V3既有功能字段 | 576 | 位置和数值格式全部保持不变 |
| `[591:576]` | `amb_recheck_interval_frames` | 16 | 完整NORMAL帧计数；0关闭周期检查 |
| `[639:592]` | `reserved_extension_v4` | 48 | 必须为0 |

默认完整配置使用`16'h1000`。间隔字段在CONFIG阶段写入SHADOW，经合法COMMIT进入ACTIVE，在整个RUN期间
冻结。RUN期间SPI不得直接改变周期。

配置管理器必须新增检查：

- `schema_version==8'h04`；
- `[639:592]`全部为0；
- 640-bit快照原子提交，不得退回512-bit截断；
- 非法COMMIT不得改变ACTIVE、config_epoch或任何系数epoch。

`amb_recheck_interval_frames`的全部16-bit编码均合法。MANUAL/SEARCH_HOLD模式下非零值允许保留但被功能逻辑忽略。

`ppg_system_config_manager`和`ppg_system_active_config_unpack`已于2026-08-07按本合同升级为原生640-bit V4，
没有在顶层对旧512-bit总线拼接常量。后续集成必须直接使用其V4端口和新增具名字段。

## 11. 搜索失败和结果资格

`search_exhausted`表示在ACTIVE min/max允许区间内不存在已观察到的窗口内码。典型情况包括输入电流过大、
IDAC量程不足、极性配置错误或模拟故障。

失败行为：

- 保持最接近目标的边界committed码；
- 置对应AMB、DC_R或DC_IR的`search_exhausted`和阻断级fault；
- 不产生虚假`search_done`；
- NORMAL_PPG运行配置不得把后续数据标记为正式有效；
- CHARACTERIZATION允许继续导出ADC结果、码快照和故障标志，但必须标记为诊断数据；
- 清除故障只能通过显式restart、STOP后重新COMMIT/START或系统定义的状态清除流程，不能被下一笔普通样本静默覆盖。

## 12. 复位、STOP和流水清理

### 12.1 复位

复位必须清除：

- fork占用和两个分支pending；
- 所有样本流水valid和compare_valid；
- 高低侧连续确认计数；
- pending码和搜索临时边界；
- 周期计数、保持请求和活动序列状态；
- 单周期状态事件。

输出码回到系统定义的安全复位值，所有epoch回到0。

### 12.2 STOP

STOP进入STOPPING后：

1. 停止发起新的NORMAL、AMB_CAL和DCS_CAL事务；
2. 已被fork接受的NORMAL事务必须完成两个分支消费或按统一复位/停止合同明确丢弃；
3. 取消尚未安全提交的搜索或跟踪pending；
4. 不因取消pending改变committed码或code_epoch；
5. 清除AMB周期请求和活动序列；
6. `i_idac_idle`只有在样本流水、比较、pending和搜索序列全部为空时才能为1。

## 13. 顶层连接合同

| 源 | 目的 | 连接 |
| --- | --- | --- |
| router NORMAL valid/载荷 | normal fork输入 | 完整NORMAL事务 |
| normal fork ready | router `i_normal_ready` | router反压返回 |
| fork measurement valid/载荷 | overlap corrector | 现有NORMAL接口逐字段连接 |
| overlap `o_normal_ready` | fork measurement ready | 测量分支反压 |
| fork tracking valid/载荷 | IDAC NORMAL跟踪入口 | Stage1校准残差和元数据 |
| IDAC tracking ready | fork tracking ready | 必须保持有界反压 |
| router AMB_CAL | IDAC校准入口 | LED关闭环境光样本 |
| router DCS_CAL | IDAC校准入口 | 当前颜色DC搜索/检查样本 |
| ACTIVE V4解包 | IDAC控制器 | mode、enable、polarity、manual/min/max、threshold、confirm_count |
| ACTIVE V4解包 | 帧调度逻辑 | `amb_recheck_interval_frames` |
| 帧调度逻辑 | IDAC/序列控制 | AMB重检请求、启动和样本调度握手 |
| IDAC控制器 | 模拟时序输出选择 | AMB、DC_R、DC_IR committed码及对应epoch |

## 14. 禁止事项

以下实现违反本合同：

1. 把router的NORMAL valid直接复制给PPG和IDAC两个消费者；
2. IDAC未ready时仍让上游覆盖事务载荷；
3. IDAC等待安全边界期间长期拉低tracking ready；
4. 使用`detect_code`、Stage2、15-bit重构值或DC恢复值代替`calibrated_s1_value`控制IDAC；
5. 因9/15-bit切换清除DC确认计数、重启搜索或复制两套码状态；
6. 用NORMAL事务直接修改AMB码；
7. 由IDAC控制器直接关闭LED或自行产生ADC启动脉冲；
8. 把AMB周期检查事务送入正常PPG算法链；
9. pending尚未在安全边界提交时提前改变码快照或code_epoch；
10. 码值达到min/max后利用自然溢出回绕；
11. RUN期间SPI直接修改`amb_recheck_interval_frames`；
12. 在V3中解释原保留位而不升级schema；
13. 重新引入`settle_sample_count`丢弃完整400-Hz样本；
14. 搜索失败后仍把结果标记为正式NORMAL有效数据。

## 15. 自检验收矩阵

### 15.1 NORMAL fork

| 编号 | 场景 | 预期 |
| --- | --- | --- |
| FFK-01 | 复位 | 两个输出valid和占用状态为0 |
| FFK-02 | 输入握手 | 下一周期两个分支各出现一次同载荷事务 |
| FFK-03 | measurement先消费 | tracking保持valid和载荷，measurement不重复 |
| FFK-04 | tracking先消费 | measurement保持valid和载荷，tracking不重复 |
| FFK-05 | 两分支同时消费 | 事务释放，可同沿接收下一笔 |
| FFK-06 | 任一分支反压5拍 | 该分支载荷逐位稳定 |
| FFK-07 | 连续两笔事务 | 顺序一致，无丢失、无复制、无交叉元数据 |
| FFK-08 | MANUAL/SEARCH_HOLD模式 | tracking仍被消费，measurement不被阻塞 |
| FFK-09 | STOP/复位打断 | valid和pending按合同清除，不产生伪传输 |

### 15.2 DC慢速跟踪

| 编号 | 场景 | 预期 |
| --- | --- | --- |
| IDT-01 | valid为0且总线变化 | 状态不变 |
| IDT-02 | 合格窗口内样本 | 对应颜色高低计数清零 |
| IDT-03 | `N_CONFIRM=1` | 第一笔同向越界形成1 LSB pending |
| IDT-04 | `N_CONFIRM=3` | 第三笔而不是第二笔形成pending |
| IDT-05 | 越界方向反转 | 旧计数清零，新方向从1开始 |
| IDT-06 | R/IR交错 | 两颜色计数和pending互不污染 |
| IDT-07 | 9/15-bit交错 | 同颜色、同epoch证据连续累计 |
| IDT-08 | calibration_applied为0 | 消费但不比较、不计数 |
| IDT-09 | snapshot或epoch不匹配 | 消费但拒绝旧码证据 |
| IDT-10 | saturation_high/low | 分别作为明确高/低越界证据 |
| IDT-11 | pending等待安全边界 | 继续接收样本但不累计，PPG链不被长期阻塞 |
| IDT-12 | 安全边界提交 | 码实际变化、epoch加1、事件单拍、计数清零 |
| IDT-13 | min/max边界继续越界 | 保持边界，不回绕、不产生虚假更新 |
| IDT-14 | 精度切换 | committed、pending、计数和epoch均保持 |
| IDT-15 | STOP/restart/error | 流水、证据和未提交pending按合同清除 |

### 15.3 AMB周期重检

| 编号 | 场景 | 预期 |
| --- | --- | --- |
| AMR-01 | interval为0 | RUN期间永不产生周期请求 |
| AMR-02 | MANUAL/SEARCH_HOLD且interval非0 | 周期字段被忽略 |
| AMR-03 | TRACK下完成4095帧 | 默认配置尚不请求 |
| AMR-04 | TRACK下完成第4096帧 | pending置位并保持至三阶段完成 |
| AMR-05 | pending等待15-bit到9-bit事件 | 不提前启动、不改变任一码值 |
| AMR-06 | 切换事件到达但NORMAL/Fork未排空 | 不启动AMB序列 |
| AMR-07 | 第一笔AMB_CHECK在窗口内 | AMB码和epoch不变，继续请求DCS重验证 |
| AMR-08 | AMB同向越界达到确认数 | 进入受限二分重搜索 |
| AMR-09 | AMB重搜索改变码 | AMB epoch递增并继续DCS_R、DC_IR阶段 |
| AMR-10 | AMB码未改变 | 仍依次请求DC_R和DC_IR校准样本 |
| AMR-11 | 三路均在窗口 | 固定顺序完成且所有code_epoch保持不变 |
| AMR-12 | 搜索耗尽 | 保持边界码、failed/fault置位、正式NORMAL资格撤销 |
| AMR-13 | AMB_CHECK事务到PPG链 | 必须被测试判定为失败 |
| AMR-14 | STOP打断周期请求 | pending和活动序列清除，不产生码更新 |

### 15.4 ACTIVE V4

| 编号 | 场景 | 预期 |
| --- | --- | --- |
| CF4-01 | schema为04且保留位为0 | 允许继续其他字段检查 |
| CF4-02 | schema仍为03但重检字段非0 | COMMIT拒绝 |
| CF4-03 | `[639:592]`任一位为1 | COMMIT拒绝，ACTIVE和epoch不变 |
| CF4-04 | interval为0、1、4096、65535 | 均为合法16-bit编码 |
| CF4-05 | RUN期间尝试修改interval | 请求拒绝，ACTIVE计数周期保持 |

## 16. 实施顺序

本合同冻结后的实施顺序为：

1. 已完成：将系统配置管理器和ACTIVE解包接口升级到640-bit V4；
2. 实现`ppg_normal_transaction_fork.v`及自检TB；
3. 按本合同重构`ppg_idac_code_controller.v`及自检TB；
4. 后续实现拥有完整400-Hz帧计数和AMB序列控制权的测量帧调度逻辑；
5. 集成AMB_CAL、DCS_CAL、NORMAL fork、帧安全提交和STOPPING排空；
6. 运行formatter-AST严格门禁、xsim自检仿真和Vivado综合回归。

## 17. 冻结结论

本合同冻结：

- NORMAL事务采用独立单元素保持型双输出fork；
- measurement分支无条件保留完整PPG事务；
- tracking分支只向IDAC提供Stage1校准残差和必要元数据；
- SAR9/SAR15共用AMB、DC_R、DC_IR逻辑码和跟踪状态；
- 9/15-bit切换不清除确认计数；
- NORMAL只慢速跟踪DC_R/DC_IR，不直接调整AMB；
- AMB周期检查由帧调度逻辑发起，IDAC控制器判断和调码；
- 周期字段为ACTIVE V4的16-bit帧计数，默认4096，0关闭；
- 周期重检固定执行AMB、DC_R、DC_IR三个校准阶段，AMB码未变化时也重新确认两路DC；
- 所有码仅在帧安全边界提交，实际变化时才递增4-bit code_epoch；
- 搜索失败阻断正式NORMAL资格，但CHARACTERIZATION保留诊断输出。

## 18. V2固定三帧周期重检修订

周期重检正常路径固定使用三个连续校准阶段：

```text
AMB -> DC_R -> DC_IR
```

AMB当前码即使仍在窗口内，只要`i_dcs_enable==1`，控制器也必须继续执行DC_R和DC_IR
重新确认。在窗口内时保持原committed码和code_epoch；只有实际调码时才递增对应epoch。
该修订不改变NORMAL期间由tracking入口执行的DC慢速`+/-1 LSB`跟踪。

后续RTL和顶层连接不得静默改变上述行为；如需增加提前AMB检查、运行期热更新或独立SAR9/SAR15码库，
必须发布新的合同版本。
