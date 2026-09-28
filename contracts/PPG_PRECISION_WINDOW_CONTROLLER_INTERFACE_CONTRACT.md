# PPG精度窗口模式控制器接口合同

> Current normative version: V2.6, 2026-08-20. Status: `ACTIVE_NORMATIVE`; system closure is `NOT_CLOSED` until the current matrix audit records zero defects. `i_precision_takeover_safe` is an AMI/PWI forwarded composite switch predicate, not physical idle; `i_peak_valley_config_valid` is the registered V5 formal-detection gate. RTL/TB evidence is `EVIDENCE_PENDING`.
> V2.6 change record: adds the explicit PWI-forwarded `i_peak_valley_config_valid` input and requires it for formal cross consumption, 9-to-15 requests and fine-window control. Safe drain and discard semantics are unchanged.  
> 冻结日期：2026-08-20  
> 目标RTL：`ppg_precision_window_controller.v`  
> 时钟域：2 MHz数字处理域  
> 请求上游：`ppg_dynamic_baseline_cross_detector`、`ppg_peak_valley_window_detector`  
> 提交下游：经PWI和AMI到400 Hz帧/模拟时序选择层、AMI拥有的ADC事务上下文和AMB重检调度器  
> 配置基线：联合ACTIVE固定1024 bit；本控制器消费V4的`run_profile/initial_precision`和由PWI注册转发的V5资格/窗口字段。V4 `[639:0]` 不重排，V5 `[1023:640]` 不由本模块直接读取。

## 1. 合同目的

本文冻结PPG自动9-bit/15-bit精度窗口的唯一所有权、进入和返回请求握手、下一400 Hz安全帧提交、
正式fine窗口事件、异常重新获取、AMB周期重检协作、生命周期优先级、两帧切换保护、sticky诊断、
20阶FIR精度历史尾部责任边界、逐端口接口以及自检验收矩阵。

后续RTL、自检TB、最终SAR9/SAR15受控wrapper、数字功能顶层和状态寄存器必须以本文为直接接口真源。
任何改变“相交后下一帧进入15-bit”“波谷经过后下一帧返回9-bit”、R/IR同帧精度一致性、异常重新获取
或安全边界提交语义的实现，都必须先发布本文新版本。

V2相对V1新增以下冻结内容：

- 精度控制器只提交真实模拟采集精度，不统计20阶FIR的10笔同色中心样本历史尾部；
- `o_fine_window_active`与真实模拟精度提交同步，不因FIR尾部而延迟置位或清零；
- 进入和退出尾部均由峰谷检测器依据中心样本元数据识别、计数和诊断；
- AMB重检安全接管可以直接废止仅等待自然排空的15-bit退出尾部状态，但不得绕过真实未消费事务；
- 精度切换超时只覆盖模拟安全提交等待，FIR历史尾部不计入两帧超时。

## 2. 规范来源和优先级

本文与以下当前活动合同共同组成精度窗口控制闭环：

1. C18 — `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.0；
2. C10 — `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.1；
3. C20 — `ppg_system_integration/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md` V2.6；
4. C22 — `ppg_system_integration/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md` V2.6；
5. C16 — `ppg_system_integration/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md` V2。

若旧版`ppg_dual_precision_top.v`、旧时序顶层、旧handoff文字或SPI静态精度控制与本文冲突，以本文和
上述活动合同为准。旧版`i_spi_precision_mode`只能作为历史参考，不得与本控制器共同拥有NORMAL运行期
精度状态。

## 3. 冻结的系统行为

### 3.1 原始PPG码值方向

本系统统一PPG码值与光电二极管接收光强正相关，自动精度顺序固定为：

```text
NORMAL从9-bit启动
-> Stage1粗FIR码值向上穿越负斜率动态基线
-> 相交请求完成ready/valid握手
-> 下一400 Hz安全帧进入15-bit
-> Stage1粗FIR链确认码值波峰
-> 跟踪下降段并保存运行最小值
-> 从运行最小值连续上升后确认码值波谷已经经过
-> 返回请求完成ready/valid握手
-> 下一400 Hz安全帧返回9-bit
```

15-bit可编程重构结果只用于高精度数据记录，不参与进入或退出窗口的判断。9-bit和15-bit期间检测均使用
连续的Stage1粗FIR结果。

### 3.2 精度唯一所有权

`ppg_precision_window_controller`是NORMAL_PPG运行期唯一的committed精度所有者。它必须输出唯一的：

```text
o_active_precision_mode
```

该信号同时驱动：

- SAR9/SAR15受控时序选择层；
- ADC事务开始沿的`precision_mode_committed`快照；
- 峰谷检测器的当前已提交精度输入；
- 结果事务的精度元数据源。

不得让SPI寄存器、动态基线模块、峰谷检测器、AMB重检调度器或红外通道另行驱动第二套活动精度状态。

### 3.3 R/IR精度一致性

红光粗检测链拥有自动窗口请求权。一次400 Hz采样帧内的红光和红外事务必须使用同一个
`o_active_precision_mode`快照。红外事务不得独立提出进入或返回请求，也不得维护独立精度FSM。

## 4. 固定参数和编码

### 4.1 RTL固定参数

| 参数 | 默认值 | 语义 |
| --- | ---: | --- |
| `C_FRAME_ID_WIDTH` | 16 | 400 Hz帧号宽度 |
| `C_SAMPLE_INDEX_WIDTH` | 16 | 相交事务号宽度 |
| `C_CONFIG_EPOCH_WIDTH` | 8 | ACTIVE版本宽度 |
| `C_COEF_EPOCH_WIDTH` | 8 | Stage1系数组版本宽度 |
| `C_DC_RECOVERY_EPOCH_WIDTH` | 8 | DC恢复系数版本宽度 |
| `C_RUN_GENERATION_WIDTH` | 8 | manager唯一生产并由PWI透传的RUN代际位宽 |
| `C_SWITCH_TIMEOUT_CYCLES` | 10000 | 2 MHz下两个400 Hz周期的最大提交等待时间 |
| `C_SWITCH_TIMEOUT_COUNTER_WIDTH` | 14 | 表达0至10000的等待计数宽度 |

`C_SWITCH_TIMEOUT_CYCLES`是实现保护参数，不进入ACTIVE寄存器。首版不得通过RUN期SPI写入改变该值。

### 4.2 精度编码

```text
1'b0 = PRECISION_9BIT
1'b1 = PRECISION_15BIT
```

### 4.3 运行配置编码

```text
run_profile = 1'b0：NORMAL_PPG
run_profile = 1'b1：CHARACTERIZATION
```

### 4.4 返回原因编码

与峰谷检测合同保持一致：

```text
2'b00 = VALLEY_CONFIRMED
2'b01 = FINE_WINDOW_TIMEOUT
2'b10 = PROTOCOL_FALLBACK
2'b11 = RESERVED
```

收到`RESERVED`必须置协议诊断，并按`PROTOCOL_FALLBACK`安全返回9-bit，不得继续保持正式15-bit窗口。

## 5. ACTIVE V4和模式语义

### 5.1 既有字段

ACTIVE V4继续使用：

| ACTIVE字段 | V4位置 | 本控制器语义 |
| --- | ---: | --- |
| `run_profile` | `[8]` | 选择NORMAL自动控制或CHARACTERIZATION固定精度 |
| `initial_precision` | `[14]` | CHARACTERIZATION固定精度；NORMAL规范值固定为0 |

本文不改变V4 640-bit子载荷或schema；V5检测字段属于联合ACTIVE的独立`[1023:640]`检测子载荷，schema绑定为`8'h05`，由PWI完成端口化转发。不得形成第二个配置producer。

### 5.2 NORMAL_PPG

NORMAL_PPG固定行为为：

```text
run_profile == 0
initial_precision == 0
START后committed精度为9-bit
后续只接受正式cross和return请求自动切换
```

配置管理器的合法性检查应拒绝`run_profile==0 && initial_precision==1`。若异常集成使该组合仍到达本模块，
本模块必须强制安全9-bit、置协议诊断并报告控制故障，不得从15-bit开始正式NORMAL。

### 5.3 CHARACTERIZATION

CHARACTERIZATION固定行为为：

```text
run_profile == 1
START时采用initial_precision
整个RUN保持该精度
不建立正式PPG fine窗口
不产生fine_window_start_event
不产生precision_15_to_9_event
不根据cross或return自动切换
```

CHARACTERIZATION中的固定15-bit只表示测试采集精度为15-bit，不表示已经建立正式PPG高精度窗口。
动态基线和峰谷模块不应在该profile下产生正式模式请求；若错误请求到达，控制器必须安全消费并置协议诊断，
防止保持型输出永久占用。

### 5.4 RUN期间配置冻结

`run_profile`和`initial_precision`只从已提交ACTIVE读取。READY、RUN和STOPPING期间不得由SPI异步覆盖，
不得把新的SHADOW值直接接入本控制器。

## 6. 生命周期行为

### 6.1 异步复位

`i_rstn=0`时必须：

```text
o_active_precision_mode = 0
o_fine_window_active = 0
o_switch_pending = 0
o_switch_hold_new_transaction = 0
全部commit/reacquire/fault事件 = 0
全部sticky = 0
全部pending上下文和等待计数 = 0
```

### 6.2 START

合法`i_start_ack_event`到达时：

- 清除上一RUN的进入、返回、重新获取和故障保持上下文；
- NORMAL固定装载9-bit并等待启动AMB/DC搜索完成；
- CHARACTERIZATION装载`i_initial_precision`但不产生正式fine窗口事件；
- 不把START本身伪造成`precision_15_to_9_event`；
- 历史sticky只能在本地活动故障已解除后由Top唯一`i_diag_clear_event`清除；新RUN不清除历史诊断。

START后只有`i_normal_measurement_active=1`才允许NORMAL相交请求被正式接受。启动AMB_CAL、DCS_CAL和FIR
准备阶段不得建立fine窗口。

### 6.3 STOP

PWI广播的`i_detection_discard_event`且reason为`DISCARD_STOP`优先取消当前`run_generation`
的全部尚未提交进入或返回请求、延迟重新获取动作和切换超时计数；`identity_valid=0`的scope-only flush同样生效。STOP不得在ADC转换中途改变
`o_active_precision_mode`。模拟时序排空后，活动精度电平可以保持到下一次START重新装载；它不再具有正式PPG窗口资格。

STOP不得产生AMB重检使用的`precision_15_to_9_event`，也不得产生虚假fine start事件。

### 6.4 abort

PWI广播的`i_detection_discard_event`且reason为`DISCARD_ABORT`或
`DISCARD_SYSTEM_FAULT`具有高于本地正常请求的安全优先级：

- 立即阻止新事务；
- 撤销尚未提交的模式请求；
- 清除正式fine窗口资格；
- 不在当前ADC转换中途改变物理精度；
- 不产生正常窗口commit事件；
- 等待系统模拟安全排空或STOP处理。

## 7. 相交请求接口

### 7.1 保持型握手

动态基线模块提供：

```text
cross_transfer = i_cross_valid && o_cross_ready
```

`i_cross_valid=1 && o_cross_ready=0`期间，动态基线模块必须保持全部相交载荷。本控制器只能在
`cross_transfer`沿锁存一次请求，不得组合采样未握手载荷。

### 7.2 NORMAL接受条件

正式`o_cross_ready=1`至少要求：

```text
i_run_enable == 1
i_active_config_valid == 1
i_peak_valley_config_valid == 1
i_run_profile == NORMAL_PPG
i_normal_measurement_active == 1
o_active_precision_mode == 0
o_fine_window_active == 0
o_switch_pending == 0
i_recheck_busy == 0
无故障保持
```

`amb_recheck_pending`不得阻止接受相交请求。周期重检正是等待下一次实际15-bit到9-bit事件；若pending直接
禁止进入15-bit，系统可能永远无法产生其等待的切换事件。

### 7.3 原子请求上下文

相交请求至少携带：

```text
cross_frame_id
cross_sample_index
cross_time_unknown
cross_config_epoch
cross_coef_epoch
cross_dc_recovery_coef_epoch
```

这些字段在请求握手时原子锁存。`cross_frame_id`是FIR时间对齐后的实际相交中心帧或未知事件发现帧，
不是15-bit提交帧。

### 7.4 `cross_time_unknown`

`cross_time_unknown=1`仍允许进入15-bit。该属性表示相交可能发生在AMB重检或FIR恢复空窗内，控制器必须：

- 正常请求下一安全帧进入15-bit；
- 保存未知时间诊断；
- 不把请求帧改写成伪造的真实相交帧；
- 不要求动态基线用该事件计算`lead_actual`或自适应时间修正。

## 8. 进入15-bit提交

### 8.1 请求接受不等于物理提交

`cross_transfer`只表示控制器取得进入请求所有权。它不表示精度已经改变，也不得立即改变正在进行的ADC
转换或已经开始的400 Hz帧。

### 8.2 安全提交条件

进入请求锁存后，提交条件固定为：

```text
enter_commit = o_switch_pending
            && pending_target == PRECISION_15BIT
            && i_frame_safe_boundary
            && i_precision_takeover_safe
            && i_analog_safe
            && !i_recheck_busy
```

`i_frame_safe_boundary`必须是下一400 Hz帧任何模拟相位和ADC事务开始前的单周期安全事件，
`i_safe_frame_id`在同拍给出即将采用新精度的帧号。

普通精度切换不要求`i_fir_idle`、`i_peak_valley_idle`、`i_normal_fork_idle`或`i_idac_idle`。Stage1粗链必须
跨精度切换连续，且峰谷检测器正等待实际精度反馈；把这些idle加入提交条件可能造成不必要延迟或死锁。

若同一边界还要提交NORMAL慢速IDAC码，顶层必须保证新精度、新IDAC码和全部事务元数据在下一事务前
原子可见。无法保证原子快照时，精度切换优先，IDAC码提交延后一帧。

### 8.3 提交输出

`enter_commit`沿必须原子完成：

```text
o_active_precision_mode <= 1
o_fine_window_active <= 1
o_fine_window_start_event <= 1个2 MHz周期
o_fine_window_start_frame_id <= i_safe_frame_id
清除进入pending和等待计数
```

`o_fine_window_start_frame_id`是第一笔真正采用15-bit采集的400 Hz帧，不是`cross_frame_id`，也不是请求
握手时所在的处理时刻。

在正常间歇工作条件下，数字判断远短于2.5 ms，因此该帧就是`cross_transfer`之后的下一物理400 Hz帧。
由于FIR群延时和连续相交确认，`o_fine_window_start_frame_id`不要求等于`cross_frame_id+1`。

### 8.4 事务启动顺序

模式提交沿仍必须保持`o_switch_hold_new_transaction=1`。PWC只发布已提交
精度和hold；PWI、AMI、Top和Scheduler/SSW按第19节唯一层次路径消费这些
端口。该路径不得在提交沿发起新的`transaction_start_fire`；最早在下一
2 MHz上升沿，AMI才可向已接管的Scheduler/SSW事务链提供更新后的精度快照，
从而使capture、S1重构器和模拟时序观察同一`o_active_precision_mode=1`。

### 8.5 进入15-bit后的FIR历史尾部

20阶、21抽头线性相位FIR的中心元数据绑定`x[n-10]`。因此`enter_commit`已经使当前模拟采集精度变为
15-bit后，FIR仍可能继续输出最多10笔同色有效NORMAL中心样本，其历史精度为9-bit。

该过渡冻结为：

```text
o_active_precision_mode = 1
o_fine_window_active = 1
FIR中心样本i_precision_mode仍可在最多10笔RED NORMAL事务中为0
```

本控制器不得等待这10笔尾部自然排空后再提交15-bit，也不得在内部重复实现尾部计数器。FIR负责输出
中心样本采集时绑定的历史精度和真实`frame_id/sample_index`；峰谷检测器负责检查旧9-bit尾部不超过10笔、
首笔15-bit中心样本后的精度不得再次倒退，以及第11笔旧精度样本的协议异常。

`o_fine_window_start_event`表示真实模拟15-bit采集已经提交，不表示同拍即可看到历史精度为15-bit的FIR
中心样本。FIR可见新精度所需的最多10笔同色有效样本延迟不是重复start条件，也不是本控制器的切换超时。

## 9. 正式15-bit窗口行为

`o_fine_window_active=1`表示由正式相交请求建立的PPG高精度窗口。窗口期间：

- `o_active_precision_mode`保持15-bit；
- 不接受新的相交请求；
- Stage1粗FIR、动态基线时间和峰谷检测连续运行；
- 15-bit精细结果可以进入数据记录链，但不得驱动本控制器；
- 只有峰谷检测器的保持型返回请求可以正常结束窗口；
- `amb_recheck_pending`不得强制提前结束窗口。

`o_fine_window_active`只描述真实模拟精度窗口，不描述FIR中心流水是否已经完全更新为15-bit。正式fine极值
资格由峰谷检测器同时检查窗口有效、中心样本历史精度和`fine_window_start_frame_id`，本控制器不得用FIR
尾部状态延迟或重新生成窗口事件。

CHARACTERIZATION固定15-bit时`o_fine_window_active`必须保持0。

## 10. 返回9-bit请求接口

### 10.1 保持型握手

峰谷检测器提供：

```text
return_transfer = i_return_9bit_valid && o_return_9bit_ready
```

`i_return_9bit_valid=1 && o_return_9bit_ready=0`期间，返回原因和请求帧号必须保持。本控制器只在
`return_transfer`沿锁存一次请求。

### 10.2 接受条件

正式`o_return_9bit_ready=1`至少要求：

```text
i_run_enable == 1
i_run_profile == NORMAL_PPG
o_active_precision_mode == 1
o_fine_window_active == 1
o_switch_pending == 0
无故障保持
```

返回请求已经由当前fine窗口产生，不得因为`i_recheck_busy`或重检pending拒绝正常返回。按冻结调度，
`i_recheck_busy`不应在正式15-bit窗口中出现；若出现必须置协议诊断，但返回9-bit仍具有安全优先级。

`o_return_9bit_ready`的接受条件不包含`i_peak_valley_config_valid`——这是刻意设计，不是遗漏。

> **文档修订记录（2026-09-02，解决2026-08-31全系统复审的待决项）**：本节此前误写入了
> `i_peak_valley_config_valid == 1`要求，与`ppg_precision_window_controller.v`现网表
> （`assign o_return_9bit_ready = ...`，约280行）不一致，现已删除该条并确认现网表为正确
> 实现。判断依据：(1) 该信号确认正确gate了本节10.1的*进入*路径（`o_cross_ready`），本控制
> 器的安全模型是"进入15-bit严格准入、返回9-bit不受阻拦"的非对称设计，与`active_precision_mode_o`
> 复位固定为`PRECISION_9BIT`（安全默认态）的整体语义一致；(2) 上级wrapper合同
> `PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` PWI-08验收条款明文
> 要求"`i_peak_valley_config_valid=0`时precision controller等三者**继续安全消费/排空**"，
> 与本节此前的文本要求直接矛盾，PWI-08才是正确的系统级设计意图；(3) 追踪
> `ppg_peak_valley_window_detector.v`（返回请求的真正发起方）确认其`flag_active_config_legal`
> 已经在生成新检测结果处门控了`i_peak_valley_config_valid`，且按§10.1保持型握手语义，一旦
> 请求发出必须持续保持到握手完成——若`o_return_9bit_ready`也被同一信号门住，config_valid在
> fine窗口中途跌落会导致已持有的合法返回请求永久无法被消费（ST_FINE状态本身没有超时保护，
> `flag_switch_timeout_event`只覆盖`ST_WAIT_ENTER`/`ST_WAIT_RETURN`），构成真实协议死锁。
> `i_peak_valley_config_valid`在RTL全文件中仅在10.1入口路径被引用一次，没有其他补偿机制，
> 已实测确认。**结论：RTL不改，本节文本是唯一需要修订的一方，已修订完成。**
>
> 本决定未被专项动态仿真覆盖——PWI-08本身在代码库中没有找到对应的专项testbench证据，
> 属于纯静态代码追踪+跨合同交叉印证的结论。如需更彻底的把握，"config_valid在fine窗口
> 中途跌落、验证返回请求仍被正常排空"可作为独立的低优先级补测项，不阻塞本次文档修订。
> 详见memory `project-ppg-full-system-audit-20260831`。

### 10.3 原子返回上下文

返回请求至少锁存：

```text
return_reason
return_frame_id
```

`return_frame_id`是峰谷确认、窗口超时或协议回退绑定的真实检测帧，不是实际9-bit提交帧。

## 11. 返回9-bit提交

### 11.1 安全提交条件

```text
return_commit = o_switch_pending
             && pending_target == PRECISION_9BIT
             && i_frame_safe_boundary
             && i_precision_takeover_safe
             && i_analog_safe
```

返回9-bit的安全提交优先于异常出现的`i_recheck_busy`。控制器不得因为重检状态错误而继续让系统停留在
15-bit；同时必须置协议诊断并向系统管理器报告故障。

### 11.2 提交输出

`return_commit`沿必须原子完成：

```text
o_active_precision_mode <= 0
o_fine_window_active <= 0
o_precision_15_to_9_event <= 1个2 MHz周期
o_precision_15_to_9_frame_id <= i_safe_frame_id
清除返回pending和等待计数
```

`o_precision_15_to_9_frame_id`是第一笔真正恢复9-bit采集的400 Hz帧。正常情况下，该帧就是
`return_transfer`之后的下一物理400 Hz帧。

`o_precision_15_to_9_event`只在NORMAL正式窗口实际15-bit到9-bit提交时产生。CHARACTERIZATION、START、
STOP、abort或复位导致的状态装载不得伪造该事件。

### 11.3 返回9-bit后的FIR历史尾部

`return_commit`已经使当前模拟采集精度恢复9-bit后，FIR仍可能继续输出最多10笔同色有效NORMAL中心样本，
其历史精度为15-bit：

```text
o_active_precision_mode = 0
o_fine_window_active = 0
FIR中心样本i_precision_mode仍可在最多10笔RED NORMAL事务中为1
```

这些样本只用于保持Stage1粗趋势连续，不得延长正式fine窗口、重新建立fine资格或产生新的9-bit向上相交
请求。本控制器不统计退出尾部，也不等待尾部自然排空后才清除`o_fine_window_active`。峰谷检测器负责检查
旧15-bit中心样本不超过10笔，并在首笔9-bit中心样本到达时结束退出尾部。

动态基线检测器只能使用历史精度为9-bit的正式RED NORMAL中心样本建立新的向上相交请求。退出尾部中的
旧15-bit中心样本可以更新时间和粗趋势，但不得建立下一次9-bit到15-bit切换请求。

### 11.4 正常返回

`return_reason==VALLEY_CONFIRMED`时：

- 正常返回9-bit；
- 不产生重新获取请求；
- 不清除动态基线、FIR历史、峰谷历史或当前活动斜率；
- 若AMB重检pending已经锁存，scheduler可以使用本次实际15-bit到9-bit事件进入安全接管等待。

### 11.5 异常返回

以下原因要求异常返回：

```text
FINE_WINDOW_TIMEOUT
PROTOCOL_FALLBACK
RESERVED归一化后的PROTOCOL_FALLBACK
```

实际9-bit提交后，控制器必须在同一控制序列中产生一次：

```text
o_reacquire_request_event
```

该事件推荐在`return_commit`后的下一个2 MHz周期产生，使下游观察事件时
`o_active_precision_mode`已经稳定为9-bit。重新获取事件交付前继续阻止新NORMAL事务；事件产生沿之后
才允许调度器恢复9-bit正式测量。

## 12. 动态基线重新获取接口扩展

### 12.1 缺口定义

当前`ppg_dynamic_baseline_cross_detector.v`能够因新START、重检失败或连续无相交进入重新获取，但它无法
直接知道峰谷检测器为什么请求返回9-bit。模式控制器是唯一同时知道`return_reason`和实际9-bit提交时刻的
模块，因此必须负责产生独立重新获取事件。

### 12.2 后续端口冻结

动态基线模块后续必须增加：

```verilog
input i_reacquire_request_event;
```

连接固定为：

```text
ppg_precision_window_controller.o_reacquire_request_event
-> ppg_dynamic_baseline_cross_detector.i_reacquire_request_event
```

动态基线模块接收该事件后必须：

- 使旧波峰基线锚点失效；
- 清除旧波谷、相交候选、周期完整性和lead统计；
- 保留当前斜率数值作为重新启动参考；
- 置`o_reacquire_active=1`；
- 等待新的可靠Stage1粗FIR码值波峰重新建立基线。

动态基线的`o_reacquire_active`继续连接峰谷检测器`i_reacquire_active`。不得使用
`i_start_ack_event`、lifecycle discard或sticky诊断边沿替代本事件。

### 12.3 与AMB重检并发

若异常返回时AMB重检pending已经锁存：

1. 实际15-bit到9-bit事件仍送给scheduler；
2. 重新获取事件先使峰谷恢复等待状态解除并废止旧基线；
3. scheduler继续等待FIR和峰谷检测器idle后接管三帧重检；
4. 重检成功后按既有合同从空历史重新获取可靠波峰；
5. 重检失败保持9-bit并报告故障。

## 13. AMB周期重检协作

### 13.1 pending不抢占fine窗口

`amb_recheck_pending`只表示周期已到。它不得：

- 中断当前15-bit窗口；
- 直接修改活动精度；
- 撤销已经握手的cross或return；
- 在没有实际15-bit到9-bit提交时启动三帧重检。

### 13.2 实际切换事件

`o_precision_15_to_9_event`连接：

```text
ppg_amb_recheck_scheduler.i_precision_15_to_9_event
```

scheduler收到事件后仍必须等待其已冻结的安全接管条件，包括ADC、NORMAL fork、IDAC、FIR、峰谷检测器
和帧安全边界全部排空。本控制器不重复实现三帧AMB、DC_R、DC_IR调度。

这里的“峰谷检测器排空”只要求真实事务所有权已经释放，包括：

```text
无待消费peak事件
无待消费valley事件
无待消费return请求
无待提交内部控制事件
无生命周期清理动作
```

15-bit返回9-bit后，仅表示“若继续接收NORMAL样本则允许最多10笔旧15-bit中心样本”的被动退出尾部状态，
不单独阻止AMB重检接管。原因是scheduler已经抑制新NORMAL事务时，该尾部无法依靠新9-bit中心样本自然
排空；若仍把它计入`o_detector_idle=0`，将形成scheduler等待detector idle、detector又等待新NORMAL样本的
循环等待。

因此，当真实输出和在途事务已经排空时，即使峰谷检测器仍保留退出尾部标志，也允许其
`o_detector_idle=1`。随后真正的`i_recheck_accept_event`必须原子完成：

```text
FIR清空两色21点历史，使旧精度中心尾部不再具备后续输出资格
峰谷检测器清除退出尾部、旧极值、方向确认和窗口状态
动态基线废止旧锚点和旧周期统计
进入AMB、DC_R、DC_IR三帧重检
重检结束后重新预热21点
```

该放宽只适用于被重检明确清除的15-bit退出尾部，不适用于真实未消费输出、返回请求、在途运算或生命周期
清理。上述真实事务仍必须严格阻止安全接管。

### 13.3 重检busy

`i_recheck_busy=1`期间：

- 活动精度应保持9-bit；
- 不接受新的正式相交请求；
- 不产生fine start事件；
- 不把校准帧解释为NORMAL精度窗口；
- 普通精度切换历史不被重检pending单独清除。

## 14. 新事务阻断和提交原子性

### 14.1 阻断输出

以下任一状态要求`o_switch_hold_new_transaction=1`：

- 已接受进入15-bit请求但尚未提交；
- 已接受返回9-bit请求但尚未提交；
- 模式提交沿本身；
- 异常返回提交后等待重新获取事件；
- 切换超时故障保持；
- STOP/abort要求阻止新事务。

该输出经`PWC -> PWI -> AMI -> Top -> Scheduler.i_switch_hold_new_transaction`
与配置管理器`o_allow_new_transaction`及Scheduler资格共同形成最终事务启动
门限。PWC没有直接Scheduler、manager、capture或S1端口。

### 14.2 同拍原子快照

模式提交后的第一笔ADC事务必须在同一个`transaction_start_fire`沿由AMI向
模拟时序、capture和S1重构器提供：

```text
新committed精度
frame_id
sample_index
frame_type
color_ir
AMB/DC committed码及code_epoch
config/coef/DC recovery epoch
```

不得出现模拟时序使用新精度而数字事务仍记录旧精度，或R/IR使用不同精度的情况。

## 15. 两帧切换超时保护

### 15.1 正常延迟

本系统一个400 Hz帧为5000个2 MHz周期。Stage1结果、粗FIR、相交/峰谷确认和模式请求处理均发生在
间歇空闲时间内，正常请求应在握手后的下一400 Hz安全帧提交。

### 15.2 保护计数

从`cross_transfer`或`return_transfer`后的下一周期开始，控制器按2 MHz周期计数。若在
`C_SWITCH_TIMEOUT_CYCLES=10000`周期内始终没有满足安全提交条件，则判定切换超时。

安全提交条件与超时阈值在同一周期同时成立时，安全提交优先，不得误报超时。

两帧保护只计算从请求握手到真实模拟精度安全提交的等待时间。进入或退出精度提交后的10笔同色FIR历史
尾部不计入`C_SWITCH_TIMEOUT_CYCLES`，也不得触发`o_switch_timeout_sticky`。尾部超过10笔、首笔新精度中心
样本后再次倒退等异常由峰谷检测器的协议诊断负责，本控制器不得重复报告为模拟精度切换超时。

### 15.3 超时行为

切换超时后必须：

```text
保持当前o_active_precision_mode
不产生虚假fine start或15-to-9 commit事件
置o_switch_timeout_sticky
产生单拍o_mode_fault_event
进入故障保持并继续阻止新事务
等待当前`run_generation`的`i_detection_discard_event`（包括scope-only flush）或复位清除故障保持
```

不得因超时在ADC转换中途强制切换。两帧保护只用于发现
`i_precision_takeover_safe`、`i_analog_safe`、帧安全边界或
模拟时序状态机异常，正常系统不会使用完整两帧等待时间。

## 16. 请求和生命周期优先级

控制优先级冻结为：

```text
异步复位
> 当前generation的detection discard
> 已接受请求的安全提交
> 已接受请求的切换超时
> FINE_WINDOW_TIMEOUT / PROTOCOL_FALLBACK返回请求
> VALLEY_CONFIRMED返回请求
> 向上相交进入15-bit请求
```

补充规则：

- 同周期安全提交和超时达到阈值时，安全提交优先；
- 当前为9-bit时只允许cross建立进入请求；
- 当前为正式15-bit窗口时只允许return建立返回请求；
- cross和return同时有效属于协议异常，按当前活动精度选择唯一合法方向并置诊断；
- 未完成的pending不得被同方向第二个请求覆盖；
- return安全优先于错误出现的recheck busy状态。

## 17. sticky诊断和状态

### 17.1 sticky输出

| 输出 | 语义 |
| --- | --- |
| `o_switch_timeout_sticky` | 自上次清除后至少一次模式请求等待超过10000个2 MHz周期 |
| `o_protocol_error_sticky` | 非法profile、非法模式请求、非法返回原因、重复请求或状态关系异常 |

sticky发生后保持到异步复位，或在本地活动故障已经解除后由Top唯一注册式
`i_diag_clear_event`清除。新合法START和STOP本身不清sticky，确保片外软件可以在停止后读取故障原因。`i_diag_clear_event`只清历史标志，不得
解除正在进行的故障保持；故障保持只由当前generation的detection discard（包括scope-only flush）或复位结束。

### 17.2 状态输出

| 输出 | 语义 |
| --- | --- |
| `o_active_precision_mode` | 当前唯一committed精度 |
| `o_fine_window_active` | 正式相交建立且尚未返回的PPG 15-bit窗口 |
| `o_switch_pending` | 已接受进入或返回请求，等待安全提交 |
| `o_switch_target_precision` | pending目标精度；无pending时仅作诊断 |
| `o_switch_hold_new_transaction` | 必须阻止新ADC事务 |
| `o_controller_idle` | 无pending、无延迟重新获取、无故障保持和无当拍控制事件 |
| `o_last_cross_time_unknown` | 最近接受相交请求的未知时间属性 |
| `o_last_return_reason` | 最近接受返回请求的原因 |

`o_controller_idle`描述控制事务排空，不表示当前一定为9-bit，也不表示不存在正式fine窗口。

## 18. 逐端口接口合同

### 18.1 全局和生命周期

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_clk` | 1 | 2 MHz数字处理时钟 |
| input | `i_rstn` | 1 | 低有效异步复位，释放由顶层同步 |
| input | `i_run_enable` | 1 | 生命周期当前处于RUN |
| input | `i_start_ack_event` | 1 | 新RUN正式开始 |
| input | `i_diag_clear_event` | 1 | 软件请求清除历史sticky |

### 18.1a 检测discard、代际与本地排空

精度控制器不接收`i_stop_ack_event`或`i_control_abort_event`作为直接清除状态
的输入。PWI是本模块唯一的检测生命周期事件生产者；STOP、abort和system
fault必须先由AMI形成带触发身份的generation-scoped discard，再由PWI原样广播。逐端口合同如下：

| 方向 | 端口 | 位宽 | 生产者/消费者与保持规则 |
| --- | --- | ---: | --- |
| input | `i_detection_discard_event` | 1 | PWI注册单拍；无ready、无ack，reset为0。 |
| input | `i_detection_discard_reason` | 2 | PWI；事件采样沿与ID稳定，编码按闭合矩阵。 |
| input | `i_detection_discard_identity_valid` | 1 | PWI；为0时discard是合法scope-only flush，除目标`run_generation`外的全部触发身份与sample-valid必须为0。 |
| input | `i_detection_discard_sample_valid` | 1 | PWI；触发事务的qualification快照；identity无效时为0。 |
| input | `i_detection_discard_frame_id/sample_index/color_ir/frame_type/precision` | `16/16/1/2/1` | PWI；完整事务身份的一部分。 |
| input | `i_detection_discard_config_epoch/coef_epoch/dc_recovery_epoch/amb_code_epoch/dc_code_epoch/run_generation` | `C_CONFIG_EPOCH_WIDTH/C_COEF_EPOCH_WIDTH/C_DC_RECOVERY_EPOCH_WIDTH/C_CODE_EPOCH_WIDTH/C_CODE_EPOCH_WIDTH/C_RUN_GENERATION_WIDTH` | PWI；完整事务身份的其余字段。 |
| input | `i_run_generation` | `C_RUN_GENERATION_WIDTH` | PWI层级扇出；当前RUN的唯一manager生成值。 |
| output | `o_local_empty` | 1 | PWI；本模块无pending、无输出和无discard在途。事件采样沿之后最早下一周期为1。 |

当`i_detection_discard_event=1`且其`run_generation`等于本模块当前generation时，控制器在该采样沿
恰好一次清除该代际的全部相交请求、返回请求、切换pending、窗口计数和任何待发布控制事件。
它不得用STOP/abort旁路替代此规则、不得产生精度切换、重获取请求或诊断完成
事件。`identity_valid=0`的scope-only flush同样清除该代际；generation陈旧时不产生输出、不推进算法状态且不影响新一代
事务；没有本地pending时事件为无条件接收的幂等空操作。`i_diag_clear_event`
仅可在本地无活动故障时清历史sticky，不能释放pending或改变generation。

### 18.2 ACTIVE和运行资格

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_active_config_valid` | 1 | ACTIVE配置通过合法性检查 |
| input | `i_run_profile` | 1 | 0 NORMAL_PPG，1 CHARACTERIZATION |
| input | `i_initial_precision` | 1 | CHARACTERIZATION固定精度，NORMAL规范值为0 |
| input | `i_normal_measurement_active` | 1 | 启动搜索完成且当前允许正式NORMAL事务 |
| input | `i_peak_valley_config_valid` | 1 | PWI经AMI注册转发的V5正式检测资格；为0时禁止正式cross消费、9-to-15请求和fine-window控制，但不阻止安全排空 |

### 18.3 相交请求

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_cross_valid` | 1 | 动态基线保持的相交请求valid |
| output | `o_cross_ready` | 1 | 控制器允许消费当前相交请求 |
| input | `i_cross_frame_id` | 16 | 实际相交中心帧或未知事件发现帧 |
| input | `i_cross_sample_index` | 16 | 相交中心ADC事务号 |
| input | `i_cross_time_unknown` | 1 | 相交可能发生在无正式FIR输出空窗 |
| input | `i_cross_config_epoch` | 8 | 相交事件ACTIVE版本 |
| input | `i_cross_coef_epoch` | 8 | 相交事件Stage1系数版本 |
| input | `i_cross_dc_recovery_coef_epoch` | 8 | 相交事件DC恢复版本 |

### 18.4 返回请求

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_return_9bit_valid` | 1 | 峰谷检测器保持的返回请求valid |
| output | `o_return_9bit_ready` | 1 | 控制器允许消费当前返回请求 |
| input | `i_return_reason` | 2 | 波谷成功、窗口超时或协议回退 |
| input | `i_return_frame_id` | 16 | 返回结论绑定的实际检测帧 |

### 18.5 帧和模拟安全输入

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_frame_safe_boundary` | 1 | 下一400 Hz帧模拟相位开始前的单拍安全事件 |
| input | `i_safe_frame_id` | 16 | 当前安全边界即将启动的400 Hz帧号 |
| input | `i_precision_takeover_safe` | 1 | PWI原样转发AMI复合资格：物理ADC/DONE已空闲，且ADC事务、异步capture和结果所有权已排空；不是物理idle事实。 |
| input | `i_analog_safe` | 1 | LED、积分、参考、ADC复位和模拟控制允许切换 |
| input | `i_recheck_busy` | 1 | AMB/DC三帧重检及FIR恢复正在占用测量调度 |

### 18.6 committed精度和事件输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| output | `o_active_precision_mode` | 1 | 唯一已提交精度，0为9-bit、1为15-bit |
| output | `o_fine_window_active` | 1 | 正式PPG 15-bit窗口状态 |
| output | `o_fine_window_start_event` | 1 | 实际进入正式15-bit窗口的单拍提交事件 |
| output | `o_fine_window_start_frame_id` | 16 | 第一笔正式15-bit帧号 |
| output | `o_precision_15_to_9_event` | 1 | NORMAL正式窗口实际返回9-bit事件 |
| output | `o_precision_15_to_9_frame_id` | 16 | 第一笔恢复9-bit帧号 |
| output | `o_reacquire_request_event` | 1 | 异常返回后要求动态基线重新获取的单拍事件 |
| output | `o_mode_fault_event` | 1 | 切换超时或阻断协议故障单拍 |
| output | `o_mode_fault_active` | 1 | 当前RUN代际的精度阻断故障保持电平；仅discard/reset后解除 |
| output | `o_mode_fault_identity_valid` | 1 | 故障身份有效位；无事务身份时为0 |
| output | `o_mode_fault_<FAULT_ID>` | 各字段宽度 | 故障发生沿原子锁存的frame/sample/color/type/precision/run_generation；无效时全0 |

### 18.7 状态和诊断输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| output | `o_switch_pending` | 1 | 已接受请求且等待安全提交 |
| output | `o_switch_target_precision` | 1 | 当前pending目标精度 |
| output | `o_switch_hold_new_transaction` | 1 | PWI内部上送AMI；AMI是唯一启动资格消费者，Top不得直接连接本子模块输出。 |
| output | `o_controller_idle` | 1 | 模式控制事务已经排空 |
| output | `o_last_cross_time_unknown` | 1 | 最近相交请求的未知时间诊断 |
| output | `o_last_return_reason` | 2 | 最近返回请求原因 |
| output | `o_switch_timeout_sticky` | 1 | 模式提交超时历史 |
| output | `o_protocol_error_sticky` | 1 | 精度控制协议异常历史 |

## 19. 顶层连接合同

| 源 | 目的 | 连接 |
| --- | --- | --- |
| ACTIVE V4 unpack -> AMI -> PWI | precision controller | `run_profile`、`initial_precision`、ACTIVE valid；PWC没有直接ACTIVE-unpack端口。 |
| AMI/PWI生命周期路径 | precision controller | RUN、START、diagnostic clear，以及唯一带ID的detection-discard；无直接STOP/abort清除端口 |
| AMI -> PWI | precision controller | `normal_measurement_active`; PWC has no direct Scheduler input. |
| dynamic baseline cross输出 | precision controller cross输入 | valid、完整相交元数据 |
| precision controller `o_cross_ready` | dynamic baseline `i_cross_ready` | 相交反压返回 |
| peak/valley return输出 | precision controller return输入 | valid、reason、frame_id |
| precision controller `o_return_9bit_ready` | peak/valley `i_return_9bit_ready` | 返回请求反压 |
| Scheduler -> Top -> AMI -> PWI | precision controller | `frame_safe_boundary`、`safe_frame_id`、`analog_safe`；PWC only receives PWI ports. |
| AMI -> PWI | precision controller | unchanged `i_precision_takeover_safe`; it is the AMI composite switch predicate, never an ADC-idle input. |
| AMI -> PWI | precision controller | `peak_valley_config_valid`; one registered V5 safety gate shared with baseline/cross and peak/valley. A low gate forces `o_cross_ready=0`, rejects formal fine-window entry/9-to-15 control, and leaves held inputs available for later safe consumption. |
| precision controller active mode | PWI -> AMI -> Top -> SSW | 下一事务唯一精度选择；AMI alone snapshots it into ADC transactions. |
| precision controller fine start | PWI内部peak/valley detector | start event和第一笔15-bit frame_id |
| precision controller fine active | PWI内部dynamic baseline | 禁止同一周期重复相交请求 |
| precision controller 15-to-9事件 | PWI内部AMB recheck scheduler | 周期pending的切换触发事件 |
| precision controller reacquire事件 | PWI内部dynamic baseline输入 | 异常返回后废止旧基线并重新获取 |
| precision controller hold | PWI -> AMI private gate -> AMI `o_switch_hold_new_transaction` -> Top -> Scheduler `i_switch_hold_new_transaction` | 只阻止新事务；PWC没有直连Scheduler端口。 |
| precision controller fault | PWI -> AMI fault-record forming -> supervisor -> Top -> ACTIVE wrapper -> manager | 仅经唯一注册fault-record路径请求系统阻断、abort和STOP；precision controller不直连manager。 |

最终SAR9/SAR15 wrapper不得再接收独立的运行期SPI精度位。旧版`ppg_dual_precision_top.v`不得直接作为
本文目标控制器或最终精度选择层集成。

## 20. 禁止事项

以下实现违反本合同：

1. NORMAL期间让SPI和本控制器同时驱动活动精度；
2. 在`cross_transfer`同拍立即改变正在进行的ADC精度；
3. 使用`cross_frame_id+1`硬算15-bit提交帧而不观察真实安全边界；
4. 把请求握手时刻写入`fine_window_start_frame_id`；
5. 因普通9/15-bit切换清空FIR、动态基线、运行极值或方向计数；
6. 使用15-bit可编程重构结果决定返回9-bit；
7. 仅因AMB重检pending提前退出15-bit；
8. 将`i_fir_idle`或`i_peak_valley_idle`加入普通返回提交条件并形成握手死锁；
9. 在CHARACTERIZATION固定15-bit时伪造正式fine start事件；
10. 用sticky边沿代替明确的异常重新获取控制事件；
11. 使用START、abort或STOP事件冒充`i_reacquire_request_event`；
12. 超时后在ADC转换中途强制改变精度；
13. 模式提交沿让新事务仍快照旧精度；
14. R和IR在同一400 Hz帧使用不同精度；
15. STOP或CHARACTERIZATION切换产生AMB scheduler使用的假15-to-9事件；
16. 未完成pending时接受第二请求并覆盖原子上下文；
17. 将2 MHz处理周期号代替真实400 Hz `frame_id`；
18. 等待10笔FIR历史尾部排空后才更新`o_active_precision_mode`或`o_fine_window_active`；
19. 在精度控制器中重复实现进入或退出尾部计数并与峰谷检测器争夺责任；
20. 把FIR历史尾部延迟计入两帧模拟精度切换超时；
21. 让15-bit退出尾部中的旧中心样本产生新的9-bit向上相交请求；
22. 仅因被动退出尾部标志仍有效而永久阻止AMB重检安全接管；
23. 在真实peak、valley、return或内部事务尚未排空时以尾部可废止为由强行接管重检。

## 21. 自检验收矩阵

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| PWC-01 | 异步复位 | 精度9-bit、窗口/pending/事件/sticky确定性清零 |
| PWC-02 | NORMAL合法START | 固定9-bit启动且不产生commit事件 |
| PWC-03 | NORMAL非法初始15-bit | 强制9-bit、置协议诊断并报告故障 |
| PWC-04 | CHARACTERIZATION 9-bit | 整个RUN固定9-bit且无正式窗口 |
| PWC-05 | CHARACTERIZATION 15-bit | 整个RUN固定15-bit但无fine start事件 |
| PWC-06 | 启动校准期间cross | 不建立正式进入请求 |
| PWC-07 | cross反压 | valid未握手时控制器不采样载荷 |
| PWC-08 | cross握手 | 原子锁存frame/sample/time_unknown和epoch |
| PWC-09 | 下一安全帧进入 | 握手后首个合格边界提交15-bit |
| PWC-10 | 进入frame_id | start frame_id等于真实safe frame_id而非cross frame_id |
| PWC-11 | 模式提交原子性 | commit沿后下一时钟才允许事务启动并快照新精度 |
| PWC-12 | unknown相交 | 仍进入15-bit且保留未知时间诊断 |
| PWC-13 | fine期间第二cross | 不重复建立进入请求，不覆盖上下文 |
| PWC-14 | return反压 | 原因和帧号在握手前保持 |
| PWC-15 | VALLEY正常返回 | 下一安全帧返回9-bit且不产生reacquire |
| PWC-16 | FINE timeout返回 | 安全返回9-bit并在下一控制周期产生reacquire |
| PWC-17 | protocol fallback返回 | 安全返回9-bit并产生reacquire和协议诊断 |
| PWC-18 | RESERVED返回原因 | 归一化为协议回退，不继续保持fine窗口 |
| PWC-19 | 返回frame_id | 15-to-9 frame_id等于真实safe frame_id |
| PWC-20 | AMB pending | 不提前退出fine，实际返回事件仍可触发scheduler |
| PWC-21 | recheck busy | 保持9-bit且拒绝新的正式cross |
| PWC-22 | 普通切换连续性 | 不要求FIR、fork、IDAC或峰谷idle |
| PWC-23 | 等待安全边界 | pending和目标精度保持，新事务被阻止 |
| PWC-24 | 10000周期前提交 | 不置超时sticky |
| PWC-25 | 安全与阈值同拍 | 安全提交优先，不误报超时 |
| PWC-26 | 切换超时 | 保持原精度、无假事件、置sticky并报告fault |
| PWC-27 | pending期间STOP | 等待AMI/PWI generation-scoped `DISCARD_STOP`；不经直接STOP端口清理，无模式commit事件 |
| PWC-28 | pending期间abort | 等待AMI/PWI generation-scoped `DISCARD_ABORT`或`DISCARD_SYSTEM_FAULT`；不经直接abort端口清理并持续阻止不安全事务 |
| PWC-29 | pending期间复位 | 全部上下文确定性清零 |
| PWC-30 | cross和return同拍 | 按活动精度选择唯一合法方向并置协议诊断 |
| PWC-31 | 重复同向请求 | 不覆盖第一笔pending上下文 |
| PWC-32 | 异常返回加重检pending | 先恢复重新获取语义，再允许scheduler安全接管 |
| PWC-33 | STOP不清sticky | 软件仍可读取历史故障 |
| PWC-34 | diagnostic clear | 只清sticky，不解除活动故障保持 |
| PWC-35 | controller idle | 仅在无pending、无延迟动作和无故障保持时为1 |
| PWC-36 | R/IR同帧 | 两色事务逐位使用同一committed精度 |
| PWC-37 | 进入15-bit历史尾部 | commit立即更新活动精度和窗口，不等待最多10笔旧9-bit中心样本 |
| PWC-38 | 返回9-bit历史尾部 | commit立即清除fine窗口，不等待最多10笔旧15-bit中心样本 |
| PWC-39 | 尾部不计切换超时 | 模拟精度提交并清除pending后，不因下游FIR历史尾部置switch timeout sticky |
| PWC-40 | V5正式检测门控 | `i_peak_valley_config_valid=0`时不接受formal cross、不产生9-to-15请求或fine-window控制；已有安全排空和generation-scoped discard规则不变。 |
| PWC-41 | START不清sticky（2026-09-17新增） | 新合法START本身不清`switch_timeout_sticky`/`protocol_error_sticky`，只有`i_diag_clear_event`或复位可以清（PWC-33的START对应半句；§6.2`:205`/§17.1`:731`早已如此规定，本条补齐验收覆盖，同时修复了RTL此前把`i_start_ack_event`当清除条件这一处真实违反合同的实现缺陷） |

所有PASS必须来自真实信号、状态和载荷比较，不得使用无条件打印、仅时间等待或未连接的占位检查。任何PASS均为后续实现证据，不能改变本合同或系统的`NOT_CLOSED`状态。

以下新增语义跨越控制器、动态基线、峰谷检测器、FIR和AMB scheduler，必须进入后续顶层集成TB，不能以
控制器单模块TB中的常量占位代替：

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| PWI-01 | 进入尾部责任分离 | 控制器不统计尾部，峰谷检测器独立检查最多10笔旧9-bit中心样本 |
| PWI-02 | 退出尾部禁止新cross | 旧15-bit中心样本可以维护粗趋势，但不得建立新的9-bit进入请求 |
| PWI-03 | AMB接管被动尾部 | 真实事务排空后，被动退出尾部不阻止detector idle和重检accept |
| PWI-04 | AMB接管真实事务 | peak、valley、return或内部事件未排空时仍必须等待，不得借尾部规则强行接管 |
| PWI-05 | 重检原子清理 | accept后FIR历史、峰谷退出尾部和旧动态基线状态全部废止并重新预热 |

## 22. RTL实现和验证门禁

后续`ppg_precision_window_controller.v`必须：

- 使用可综合Verilog-2001；
- 使用单一2 MHz时钟和低有效异步复位；
- 使用三段式FSM和明确`ST_*`状态；
- 所有保持型请求只在ready/valid传输沿消费；
- 所有commit和重新获取事件固定为单周期；
- 不生成门控时钟；
- 不推断锁存器；
- 不依赖`initial`、`force`、延时语句或SystemVerilog结构；
- 对计数、优先级、默认分支和异常输入显式处理；
- 保证模式寄存器只在复位、合法START初始化或安全commit路径改变。

正式交付门禁为：

```text
formatter-AST：0 error / 0 strict warning
独立lint：0 error / 0 warning
历史实现证据记录（非规范，当前均为`EVIDENCE_PENDING`）：

- 历史 Vivado xvlog/xelab/xsim/综合结果；
- 历史 PWC-01 至 PWC-39 与 PWI-01 至 PWI-05 的执行记录。

这些记录不能证明当前合同闭合，不能替代现行接口、连接、CDC 或验收要求。
Latch = 0
Blackbox = 0
2 MHz时序满足
记录LUT、寄存器、DSP、WNS/TNS和非阻断警告
```

## 23. Historical V2 Freeze Record (Non-Normative)

The V2 record below is retained for change traceability. The current V2.5
port, fault, discard, generation, hierarchy and evidence rules are defined by
the active sections above and its current dependency table; this record cannot
assert an implementation or system-closure result.

V2正式冻结以下结论：

- NORMAL_PPG由寄存器选择，但进入RUN后精度由本控制器唯一拥有；
- NORMAL固定9-bit启动，CHARACTERIZATION按SPI提交的`initial_precision`固定工作；
- 相交和返回握手只锁存请求，实际精度在下一400 Hz安全帧提交；
- 正常间歇工作下，第一笔15-bit或恢复9-bit帧就是请求握手后的下一物理帧；
- `fine_window_start_frame_id`和`precision_15_to_9_frame_id`均来自真实安全提交帧；
- 普通精度切换不清Stage1粗FIR、动态基线或峰谷历史；
- 控制器在安全边界立即提交真实模拟精度和窗口状态，不等待FIR的10笔同色历史尾部；
- FIR负责携带中心样本历史精度，峰谷检测器独立负责进入/退出尾部计数、倒退检查和超限诊断；
- 退出尾部中的旧15-bit中心样本不得建立新的9-bit向上相交请求；
- AMB重检可以在真实事务排空后直接废止被动退出尾部，避免等待新NORMAL样本形成循环等待；
- 波谷成功正常返回不重新获取，窗口超时和协议回退返回后显式重新获取；
- 动态基线模块后续增加`i_reacquire_request_event`，不得滥用START或abort；
- AMB重检pending不抢占fine窗口，只使用实际15-bit到9-bit事件；
- 请求正常在下一帧提交，10000个2 MHz周期只作为两帧异常保护；
- FIR精度历史尾部不计入两帧模拟切换超时；
- 超时保持原精度并阻止新事务，绝不在ADC转换中途强制切换；
- ACTIVE V4保持640 bit不变；V5检测字段由联合ACTIVE/PWI输入链提供，不得从V4保留位或SPI shadow直连。

任何改变以上模式所有权、安全提交、frame_id、重新获取、重检协作或异常保护语义的实现，都必须先修订
本文，再修改RTL、自检TB和顶层连接。
