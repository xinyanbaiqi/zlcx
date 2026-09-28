# PPG码值峰谷与精度窗口检测接口合同

> Current normative version: V2.6, 2026-08-20. Status: `ACTIVE_NORMATIVE`; generation-scoped detection-discard, generation, local-empty and diagnostic-clear semantics remain normative. System closure is `NOT_CLOSED`; implementation evidence is `EVIDENCE_PENDING`.

> Historical V3 peak/valley freeze date: 2026-08-12. It is non-normative unless explicitly restated by V2.6.
> 目标RTL：`ppg_peak_valley_window_detector.v`  
> 时钟域：2 MHz数字处理域  
> 上游：`ppg_coarse_detection_fir`经无丢失检测事务fork  
> 下游：`ppg_dynamic_baseline_cross_detector`、精度窗口模式控制器和系统状态汇总  
> 配置基线：联合ACTIVE固定1024 bit；V4保持640 bit子载荷不变，本文逻辑字段来自V5 `[1023:640]`并仅经AMI->PWI具名输入到达本模块。

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C18 | `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.0 | Sole PWI parent, V5 forwarding and discard broadcast boundary. |
| C19 | `ppg_system_integration/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md` | V2.5 | Sole qualified FIR transaction source. |
| C20 | `ppg_system_integration/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md` | V2.6 | Cross-event collaborator; no shared owner transfer. |
| C23 | `ppg_system_integration/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md` | V2.6 | Sole precision request/commit consumer. |

## 1. 合同目的

本文冻结原始PPG码值方向下的Stage1粗FIR峰谷检测、9-bit启动和重新获取、15-bit正式窗口资格、
实际极值时间保存、连续方向确认、可编程死区和幅度/时间门限、20阶FIR精度切换流水尾部、窗口超时、
ready/valid所有权、AMB/DC重检、生命周期清理、sticky诊断以及自检验收矩阵。

后续RTL、自检TB、精度模式控制器、状态寄存器和ACTIVE配置扩展必须以本文为直接接口真源。任何改变
极性、极值时间、连续确认定义、普通精度切换连续性、窗口退出条件或超时恢复行为的实现，都必须先发布
本文新版本。

## 2. 系统极性与功能边界

### 2.1 冻结的原始码值方向

统一PPG码值与光电二极管接收光强正相关。片内自动精度控制顺序固定为：

```text
9-bit粗链等待负斜率动态基线向上相交
-> 下一400 Hz安全帧进入15-bit
-> 同一Stage1粗FIR链确认码值波峰
-> 跟踪下降段并保存运行最小值
-> 从运行最小值连续上升后确认码值波谷已经经过
-> 下一400 Hz安全帧返回9-bit
```

本文中的“波峰”表示原始PPG码值最大值，“波谷”表示原始PPG码值最小值，不表示生理血容量PPG的
正峰和负峰。

### 2.2 精度模式不改变检测数据源

9-bit和15-bit模式下，检测数据源始终为：

```text
Stage1可编程校准结果
-> 9-bit粗路径中心化
-> DC恢复
-> signed 24-bit统一PPG码
-> 粗检测FIR
-> 本模块
```

15-bit可编程重构结果只用于高精度数据记录，不得驱动本模块的波峰、波谷、方向或退出判断。普通
9-bit/15-bit切换不得清空FIR历史、运行极值、方向确认计数或中心元数据。

### 2.3 本模块必须负责

`ppg_peak_valley_window_detector`必须：

1. 接收RED/IR粗FIR事务，消费但忽略IR事务，只有RED事务拥有峰谷和精度窗口控制权；
2. 在9-bit启动或重新获取阶段找到第一个可靠码值波峰并输出锚点事件；
3. 在正常连续粗链中跟踪运行最大值、下降段、运行最小值和后续上升段；
4. 保存实际极值样本携带的`frame_id`、`sample_index`和epoch，不使用确认时刻替代极值时刻；
5. 在正式15-bit窗口中确认波谷经过后，以保持型请求通知模式控制器返回9-bit；
6. 对幅度、时间、配置、饱和、帧序和epoch异常提供安全拒绝和可见诊断；
7. 在9-bit重新获取超时后继续保持9-bit并自动开始下一轮搜索；
8. 为AMB/DC重检提供明确的空闲状态，防止撤销尚未消费的峰谷事件。

### 2.4 本模块不得负责

本模块不得：

- 使用15-bit精细重构结果替代Stage1粗FIR结果；
- 计算动态基线或自行决定进入15-bit的相交时刻；
- 直接修改ADC精度寄存器、IDAC码、LED时序或ADC转换时序；
- 对片外输出执行精细峰值搜索或生理参数计算；
- 因普通精度切换、IR事务、反压空拍或仅有重检pending而清理检测历史；
- 在门限或时间资格不足时伪造峰值、谷值或窗口成功事件；
- 使用2 MHz时钟周期数替代400 Hz中心`frame_id`时间。

## 3. 冻结参数、配置字段和默认值

### 3.1 固定参数

| 参数 | 默认值 | 语义 |
| --- | ---: | --- |
| `C_DATA_WIDTH` | 24 | signed统一PPG码和FIR输出宽度 |
| `C_FRAME_ID_WIDTH` | 16 | 400 Hz配对帧号宽度 |
| `C_SAMPLE_INDEX_WIDTH` | 16 | 全局ADC事务序号宽度 |
| `C_CONFIG_EPOCH_WIDTH` | 8 | ACTIVE配置版本宽度 |
| `C_COEF_EPOCH_WIDTH` | 8 | Stage1系数组版本宽度 |
| `C_DC_RECOVERY_EPOCH_WIDTH` | 8 | DC恢复系数组版本宽度 |
| `C_RUN_GENERATION_WIDTH` | 8 | manager唯一生产并由PWI透传的RUN代际位宽 |
| `C_CONFIRM_COUNT_WIDTH` | 4 | 峰谷连续确认计数宽度 |
| `C_INTERVAL_WIDTH` | 16 | 峰谷时间和超时字段宽度 |
| `C_FIR_GROUP_DELAY_SAMPLES` | 10 | 20阶21抽头线性相位FIR的同色有效样本群延时 |

### 3.2 ACTIVE逻辑字段

| 字段 | 位宽 | 冻结默认值 | 语义 |
| --- | ---: | ---: | --- |
| `peak_confirm_count` | unsigned 4 | 3 | 运行最大值后连续有效下降样本数 |
| `valley_confirm_count` | unsigned 4 | 3 | 运行最小值后连续有效上升样本数 |
| `direction_deadband` | unsigned 24 | 表征值 | 相邻FIR值方向分类的对称死区 |
| `min_peak_valley_amplitude` | unsigned 24 | 表征值 | 合格峰谷对的最小正幅度 |
| `min_peak_to_valley_frames` | unsigned 16 | 20 | 波峰到波谷允许的最小时间，50 ms |
| `min_peak_to_peak_frames` | unsigned 16 | 100 | 相邻波峰最小时间，对应最高约240 BPM |
| `max_fine_window_frames` | unsigned 16 | 600 | 正式15-bit窗口最大持续时间，1.5 s |
| `max_reacquire_frames` | unsigned 16 | 1000 | 9-bit重新获取单轮最大时间，2.5 s |
| `peak_valley_config_valid` | 1 | 0 | 全部峰谷正式配置已由片外表征并原子提交 |

`direction_deadband`和`min_peak_valley_amplitude`不得在流片前伪造正式固定物理值。NORMAL_PPG只在
`peak_valley_config_valid=1`时产生正式峰谷和模式控制事件；CHARACTERIZATION允许`peak_valley_config_valid`
使用0（即配置尚未由片外表征正式commit），但结果必须标记为未正式表征。该豁免只适用于
`peak_valley_config_valid`本身——其余6个数值门限字段（见下方非法配置清单）在CHARACTERIZATION下
同样不得为0，理由见3.3节。

### 3.3 非法配置

NORMAL_PPG下，以下任一条件使配置非法：

```text
peak_confirm_count == 0
valley_confirm_count == 0
min_peak_to_valley_frames == 0
min_peak_to_peak_frames == 0
max_fine_window_frames == 0
max_reacquire_frames == 0
peak_valley_config_valid == 0
```

非法配置不得产生正式峰谷或精度返回请求，并必须置位`o_protocol_error_sticky`。若未来需要关闭某一
保护，必须增加独立使能位，不得复用数值0形成双重语义。

上述清单虽然整体限定"NORMAL_PPG下"生效，但只有`peak_valley_config_valid == 0`这一条在CHARACTERIZATION
下被豁免（对应3.2节"允许0或临时值"的描述对象）。其余6个数值门限——`peak_confirm_count`、
`valley_confirm_count`、`min_peak_to_valley_frames`、`min_peak_to_peak_frames`、
`max_fine_window_frames`、`max_reacquire_frames`——在CHARACTERIZATION下同样必须非零，两点理由：
第一，这6个字段在3.2节表格里均已标注冻结默认值（3/3/20/100/600/1000），不属于"表征期间尚未测出、
只能先填0"的一类参数，真正需要片外表征才能确定的只有`direction_deadband`和`min_peak_valley_amplitude`
两个模拟相关参数；第二，`PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`§7.1"固定精度纯RED运行"是
CHARACTERIZATION里唯一会真实驱动本模块峰谷检测
算法的子场景（真实光电二极管输入，仅精度锁定不做9↔15自动切换），该场景的表征目的正是验证峰谷检测
算法在真实条件下的行为，若把去抖（`peak_confirm_count`/`valley_confirm_count`）和生理合理性
（`min_peak_to_valley_frames`/`min_peak_to_peak_frames`）门限也随`peak_valley_config_valid`一并
归零，表征出的将是关闭保护机制的退化行为，而非要表征的算法本身；`max_fine_window_frames`和
`max_reacquire_frames`归零还会使对应超时比较条件恒真，导致15-bit窗口和9-bit重新获取每一拍都立即
判超时，直接令模块无法正常工作，而非单纯放宽。

## 4. 输入事务资格与时间模型

### 4.1 正式状态更新资格

只有完成输入握手且满足以下条件的事务，才允许更新正式方向和极值状态：

```text
input_transfer
&& i_detection_qualified
&& i_color_ir == 0
&& i_frame_type == NORMAL
&& no_saturation
&& active_config_legal
```

IR事务必须被消费但不得改变RED运行最大值、最小值、方向计数、周期时间或窗口状态。未校准、窗口
不完整或饱和的RED事务不得形成正式方向证据。

### 4.2 实际极值时间

FIR输出已经把值和元数据绑定到中心样本`x[n-10]`。本模块必须直接保存该事务携带的：

```text
filtered_ppg_value
frame_id
sample_index
config_epoch
coef_epoch
dc_recovery_coef_epoch
precision_mode
```

不得再次减去10帧群延时。若波峰实际中心为frame 100，经过FIR和3点下降确认后在更晚时刻才可见，
输出仍必须携带`peak_frame_id=100`，不得替换为确认帧号。

### 4.3 中心样本精度与当前精度

`i_precision_mode`表示FIR中心样本`x[n-10]`被ADC采集时绑定的历史精度；`i_active_precision_mode`表示
当前模拟时序已经提交、将用于下一笔ADC事务的精度。二者不是同一个时间平面的状态，不得直接要求逐拍
相等。

普通9-bit到15-bit切换后，最多允许10笔已经握手的RED NORMAL FIR事务继续携带
`i_precision_mode=0`；普通15-bit到9-bit切换后，最多允许10笔已经握手的RED NORMAL FIR事务继续携带
`i_precision_mode=1`。该上限按同色FIR输出事务计数，不按2 MHz周期计数，也不把交错IR事务计入RED尾部。

合法流水尾部必须满足：

```text
存在已识别的正式精度提交事件
&& 历史精度只属于紧邻切换前的旧精度
&& 旧精度RED NORMAL FIR事务数 <= C_FIR_GROUP_DELAY_SAMPLES
&& frame_id连续性仍满足本文规则
```

合法尾部样本继续更新Stage1粗链的相邻值、运行极值和方向趋势；不得丢弃、不得清空FIR历史，也不得仅因
`i_precision_mode != i_active_precision_mode`置协议错误。首笔中心样本精度与当前精度一致的RED事务结束
对应方向的尾部状态；之后再次出现旧精度，或第11笔旧精度RED事务仍未排空，均属于协议异常。

实现可在内部保存中心样本精度或与运行极值绑定的正式fine资格位，不要求为峰值、波谷输出新增精度端口。

### 4.4 16-bit帧差

全部正式时间使用无符号模减：

```text
frame_delta(a, b) = (a - b) mod 2^16
```

合法差值必须小于`2^15`。达到或超过半回绕周期的峰谷、峰峰或窗口时间无资格，并置位协议诊断。

窗口和重新获取超时使用真实`frame_id`差值，不累计2 MHz空闲周期，也不只累计合格样本数。每个被
消费的RED事务即使资格为0，仍可用于观察真实时间已经推进；它不得用于方向或极值更新。

### 4.5 连续样本定义

连续方向确认要求相邻合格RED事务的`frame_id`连续递增1。若出现非预期跳帧：

- 保留已经确认的上一峰值和周期身份；
- 保留当前运行极值用于诊断；
- 清除尚未完成的连续上升或下降计数；
- 不把跳帧前后的方向证据拼成一次连续确认；
- 置位协议诊断。

普通ready/valid反压不会制造逻辑跳帧；上游必须保持同一事务直到握手。

## 5. 方向分类与死区

对相邻合格RED FIR值定义：

```text
delta[n] = Y[n] - Y[n-1]
```

分类冻结为：

```text
delta[n] > +direction_deadband: 有效上升
delta[n] < -direction_deadband: 有效下降
其他情况:                        平坦/方向不确定
```

平坦样本不增加连续确认计数，也不清除已有计数。只有超过死区的反方向变化才清除当前方向计数。
差值运算必须至少使用signed 25-bit工作量，禁止24-bit自然回绕。

## 6. 运行极值与平台处理

### 6.1 运行最大值

处于波峰搜索阶段时：

- `Y > running_max`：更新数值和完整中心元数据，下降计数清零；
- `Y == running_max`：数值不变，但更新为最后一个相同最大值的中心元数据，下降计数清零；
- 有效下降：下降计数加1；
- 平坦但不等于最大值：下降计数保持；
- 有效上升但尚未超过最大值：下降计数清零。

保存最后一个相同最大值，使波峰时间更接近真正开始下降的位置。

### 6.2 运行最小值

处于波谷搜索阶段时：

- `Y < running_min`：更新数值和完整中心元数据，上升计数清零；
- `Y == running_min`：数值不变，但更新为最后一个相同最小值的中心元数据，上升计数清零；
- 有效上升：上升计数加1；
- 平坦但不等于最小值：上升计数保持；
- 有效下降但尚未低于最小值：上升计数清零。

保存最后一个相同最小值，使波谷时间更接近真正开始上升的位置。

## 7. 码值波峰确认

### 7.1 确认条件

运行最大值后观察到连续`peak_confirm_count`个有效下降样本时，形成波峰候选。极值本身不计入下降
确认次数。默认值3表示最大值后的第3个连续下降样本到达时，才确认波峰已经经过。

除没有可靠前一波峰参照的候选外，候选还必须满足：

```text
frame_delta(candidate_peak_frame_id, previous_peak_frame_id)
    >= min_peak_to_peak_frames
```

第一个可靠波峰没有前一波峰，因此免除峰峰最小时间检查。这个豁免只取决于"是否存在可靠的前一
波峰参照"这一个条件，典型出现在9-bit启动后的第一个波峰，或`i_start_ack_event`/周期重检成功
清空历史之后的重新获取；不得把它读成"任意reacquire轮次的第一个候选一律豁免"——reacquire若由
9-bit不完整周期超时、无相交次数超限或跨epoch故障等场景触发，且触发时上一个正式波峰参照仍然
有效未被清空，则该参照依然是真实、已确认的波峰，峰峰最小时间检查必须继续对其生效，不得因为
当前处于重新获取状态就整体放行。

### 7.2 时间不足的局部波峰

若下降确认成立但峰峰时间不足：

- 不输出`o_peak_valid`；
- 不覆盖上一正式波峰；
- 将其视为同一心搏内的局部结构；
- 重新武装运行最大值搜索并继续观察；
- 不触发返回9-bit或自适应周期更新。

### 7.3 波峰事件

合格波峰输出保存的运行最大值及其实际中心元数据。确认延时不得改变事件身份。每个正式周期最多
输出一个波峰事件，直到合格波谷完成后才允许下一周期波峰。

## 8. 码值波谷确认

### 8.1 确认条件

合格波峰建立后，模块跟踪运行最小值。运行最小值后连续`valley_confirm_count`个有效上升样本时，
形成波谷候选。候选必须同时满足：

```text
peak_value - valley_value >= min_peak_valley_amplitude

frame_delta(valley_frame_id, peak_frame_id)
    >= min_peak_to_valley_frames
```

幅度减法必须使用signed 25-bit工作量，并要求结果严格为正。

### 8.2 资格不足

若连续上升成立但幅度或时间不足：

- 不输出`o_valley_valid`；
- 不宣称本周期成功；
- 不请求返回9-bit；
- 继续跟踪后续下降和更低的运行最小值；
- 直到资格满足或正式窗口超时。

该规则用于拒绝噪声、局部平台和重搏切迹，不得在第一次资格不足时直接报故障退出。

### 8.3 波谷事件

合格波谷输出保存的运行最小值及其实际中心元数据。波谷事件只表示码值波谷已经经过；确认时刻比
实际最小值晚`valley_confirm_count`个方向证据样本，但输出身份仍绑定运行最小值。

### 8.4 非正式窗口下的峰后超时

即使当前没有正式15-bit窗口，已确认波峰后的波谷搜索也不得无限持续。若：

```text
frame_delta(current_red_frame_id, peak_frame_id)
    >= max_fine_window_frames
```

仍未得到合格波谷，则该粗周期不完整。本模块保持9-bit，不产生返回请求，清除本周期运行最小值和方向
计数，并重新进入波峰获取。该事件置位`o_reacquire_timeout_sticky`，但不得置位
`o_fine_window_timeout_sticky`，因为没有正式fine窗口。

## 9. 9-bit启动与重新获取

### 9.1 启动

新`START_ACK`后：

```text
无可靠上一波峰
无正式峰谷周期
保持9-bit
等待FIR重新取得正式资格
寻找第一个可靠码值波峰
```

第一个波峰不要求此前发生动态基线相交，也不检查峰峰最小时间。波峰事件被动态基线模块消费后，
由动态基线模块使用ACTIVE固定斜率建立第一条基线。

### 9.2 重新获取

`i_reacquire_active=1`时，本模块在9-bit下重新寻找可靠波峰，不得请求进入15-bit。重新获取单轮时间：

```text
reacquire_age = frame_delta(current_red_frame_id,
                            reacquire_start_frame_id)
```

当`reacquire_age >= max_reacquire_frames`仍未得到可靠波峰时：

- 保持9-bit；
- 不伪造锚点；
- 置位`o_reacquire_timeout_sticky`；
- 清除本轮运行极值和连续方向计数；
- 以当前真实帧号自动开始下一轮重新获取；
- Stage1、DC恢复和粗FIR继续运行。

后续成功获得波峰时，正常输出波峰事件并结束重新获取；历史timeout sticky保持到明确清除。

## 10. 15-bit正式窗口

### 10.1 窗口提交事件

`i_precision_mode`只是FIR中心样本携带的历史精度，不能单独证明当前正式PPG窗口已经开始。模式控制器必须在
动态基线相交请求被接受、下一安全帧的15-bit模式已经提交时产生：

```text
i_fine_window_start_event
i_fine_window_start_frame_id
```

`i_fine_window_start_event`只建立正式窗口资格和超时起点，不重置Stage1粗FIR趋势、运行极值或方向计数。
推荐顶层语义名称为`enter_15bit_commit_event`。

手动15-bit、CHARACTERIZATION或校准流程即使使`i_precision_mode=1`，没有正式start事件也不得建立
PPG精细窗口。

由于FIR中心延迟为10个同色有效样本，start事件发生后的前若干FIR输出允许仍绑定切换前9-bit中心样本。
这些样本保持粗趋势连续，但不具备正式fine峰谷对资格。正式fine中心样本资格冻结为：

```text
fine_center_qualified =
    fine_window_active
    && i_precision_mode == 1
    && frame_delta(i_frame_id, fine_window_start_frame_id) < 2^15
```

只有实际中心`frame_id`位于首个15-bit帧或其后、且中心样本历史精度为15-bit的运行波峰，才可建立正式
fine峰谷对。切换前9-bit中心样本形成的波峰仍可作为粗链趋势或诊断锚点，但不得与后续波谷组成一次
`VALLEY_CONFIRMED`正式返回结论。若窗口未完整覆盖合格波峰，模块继续搜索，最终可由窗口超时安全返回。

### 10.2 窗口持续时间

```text
fine_window_age = frame_delta(current_red_frame_id,
                              fine_window_start_frame_id)
```

当当前FIR中心样本仍早于`fine_window_start_frame_id`时，模减结果最高位为1；这表示正常的9-bit进入尾部，
不是窗口时间回绕、跳帧或精度协议错误。此时不得比较`max_fine_window_frames`，不得触发超时，也不得形成
正式fine峰谷对。首笔`fine_center_qualified`事务到达后，才允许使用非负中心帧龄执行窗口超时判断。

从窗口提交到合格波谷完成期间，Stage1粗链在9-bit/15-bit切换边界保持连续。正常窗口通常远小于
600帧；默认上限600帧用于覆盖较慢心率并防止异常时永久停留15-bit。超时以FIR中心`frame_id`为数学
时间，因此物理可见时刻最多比对应中心时刻晚10个同色有效样本；不得再为该可见延迟修改帧龄或额外
补加10帧。

### 10.3 正常返回9-bit

正式窗口内合格波谷事件建立后，同时提出保持型返回请求：

```text
o_return_9bit_valid
i_return_9bit_ready
```

请求完成握手表示模式控制器已经接受“下一安全帧返回9-bit”。本模块随后进入返回等待状态，直到
`i_active_precision_mode`实际变为0。握手前不得撤销valid或改变返回原因和绑定的谷值元数据。返回提交后
仍可到达的历史15-bit中心样本按第4.3节作为合法退出尾部处理，不得延长正式fine窗口。

### 10.4 窗口超时

当`fine_window_age >= max_fine_window_frames`仍未完成合格波谷时：

- 不生成虚假`o_valley_valid`；
- 不宣称本周期幅度和自适应斜率有效；
- 置位`o_fine_window_timeout_sticky`；
- 以超时原因为模式控制器提出返回9-bit请求；
- 返回9-bit后进入波峰重新获取；
- 保留已经确认的波峰作为诊断，但不得把不完整周期用于自适应更新。

模式控制器接收`FINE_WINDOW_TIMEOUT`或`PROTOCOL_FALLBACK`返回原因后，必须在实际切回9-bit的同一
控制序列中使动态基线进入重新获取，并向本模块反馈`i_reacquire_active=1`。不得使用sticky电平的边沿
代替该正式控制动作。

### 10.5 精度状态异常

- 没有正式start事件却观察到15-bit：允许消费粗FIR数据，但不建立正式窗口；若该状态被解释为
  NORMAL自动模式，置位协议诊断；
- 正式窗口尚未完成返回握手却观察到`i_active_precision_mode=0`：撤销当前窗口资格、置位协议诊断并
  进入重新获取；
- 已完成返回握手并在安全边界实际切回9-bit后，最多10笔中心样本仍为15-bit的RED NORMAL FIR事务属于
  正常退出尾部，不得重新建立fine窗口或置协议错误；
- 普通9-bit到15-bit或15-bit到9-bit切换本身不得清空FIR和粗趋势历史。

## 11. ready/valid和事件原子性

### 11.1 FIR输入

```text
input_transfer = i_result_valid && o_result_ready
```

IR、非正式窗口精度和不参与当前阶段的事务必须被接收并按合同忽略，不能长期反压检测fork。只有峰值
或谷值输出寄存器正被下游反压且继续接收会覆盖唯一事件缓冲时，允许对FIR分支实施有界反压。

### 11.2 峰值事件

```text
peak_transfer = o_peak_valid && i_peak_ready
```

`o_peak_valid=1 && i_peak_ready=0`期间，峰值、实际中心时间、全部epoch和事件资格逐拍保持。不得在
握手前用后续运行最大值覆盖该事件。

### 11.3 波谷事件

```text
valley_transfer = o_valley_valid && i_valley_ready
```

`o_valley_valid=1 && i_valley_ready=0`期间，波谷值和全部元数据逐拍保持。波谷和返回9-bit请求属于
同一检测结论，但分别完成各自握手；任一分支反压不得导致另一分支载荷改变或重复消费。

### 11.4 返回请求

```text
return_transfer = o_return_9bit_valid && i_return_9bit_ready
```

返回请求至少携带原因：

```text
2'b00 = VALLEY_CONFIRMED
2'b01 = FINE_WINDOW_TIMEOUT
2'b10 = PROTOCOL_FALLBACK
2'b11 = RESERVED
```

原因、关联frame_id和窗口身份在反压期间必须保持。模式控制器只在下一400 Hz安全边界修改精度，
不得中途改变当前ADC转换。

`VALLEY_CONFIRMED`只要求正常返回9-bit；`FINE_WINDOW_TIMEOUT`和`PROTOCOL_FALLBACK`还要求模式控制器
在切回9-bit后启动动态基线和峰谷检测器的重新获取控制序列。

### 11.5 空闲定义

`o_detector_idle=1`至少要求：

```text
o_peak_valid == 0
o_valley_valid == 0
o_return_9bit_valid == 0
flag_return_accepted == 0
flag_recovery_return_pending == 0
flag_entry_precision_tail_active == 0
无其他待提交内部事件
无正在进行的生命周期清理
```

运行极值、已确认周期状态以及`flag_exit_precision_tail_active`可以存在而不妨碍idle；idle描述真实事务排空，
不表示检测历史为空。

`flag_exit_precision_tail_active`仅表示：实际15-bit返回9-bit后，若继续接收NORMAL事务，则仍允许最多10笔
旧15-bit中心样本按第4.3节排空。该状态不拥有未消费输出，不要求ADC或FIR继续运行，也会在真正的
`i_recheck_accept_event`到达时被原子清除。因此它属于可由重检废止的被动历史状态，不得单独使
`o_detector_idle=0`。

本放宽不适用于进入15-bit尾部。`flag_entry_precision_tail_active=1`时，检测器仍在确认正式15-bit中心样本
已经到达，并承担入口尾部超限及倒退检查责任，因此必须保持`o_detector_idle=0`。

## 12. AMB/DC重检与生命周期

### 12.1 重检安全接管

周期重检只在间隔到期后等待下一次15-bit返回9-bit。调度器接受重检的条件必须包含：

```text
原调度条件
&& i_fir_idle
&& i_peak_valley_idle
```

其中`i_peak_valley_idle`连接本模块`o_detector_idle`。仅有`recheck_pending`不得改变峰谷状态。

实际15-bit返回9-bit后，scheduler可能已经阻止新的NORMAL事务。如果`o_detector_idle`仍等待被动退出尾部
通过后续9-bit样本自然排空，将形成：

```text
scheduler等待o_detector_idle
-> detector等待新NORMAL样本结束退出尾部
-> scheduler又禁止新NORMAL样本
```

因此，当第11.5节规定的真实事务均已排空时，即使`flag_exit_precision_tail_active=1`，也必须允许
`o_detector_idle=1`，使scheduler能够安全接受重检。

### 12.2 重检清理

真正的`i_recheck_accept_event`到达后，清除：

```text
运行最大值和最小值
方向确认计数
未消费峰谷候选
当前周期幅度和时间资格
正式fine窗口资格
重新获取计时上下文
进入和退出精度流水尾部状态
```

三帧AMB/DC重检和FIR重新预热期间不输入0、不伪造峰谷。重检成功后保持9-bit，从空历史重新获取
可靠波峰。重检失败同样保持9-bit，并报告上层故障。

重检接管被动退出尾部时，FIR必须同时清空两色21点历史，本模块必须清除`flag_exit_precision_tail_active`
及其计数。被废止的旧15-bit中心样本不得在重检后迟到输出，也不得重新建立fine窗口或产生协议错误。

### 12.3 普通精度切换

没有实际重检接管时，以下事件不得清理峰谷历史：

- 9-bit进入15-bit；
- 15-bit返回9-bit；
- 重检间隔到期但仍处于pending；
- NORMAL慢速DC调码；
- IR事务；
- ready/valid空拍或有界反压。

### 12.4 START、STOP、abort和复位

- `i_rstn=0`：全部valid、运行极值、计数、窗口资格和sticky确定性清零；
- `i_start_ack_event`：建立新RUN，清除上一RUN检测历史并进入9-bit重新获取；历史sticky只能由全局`i_diag_clear_event`或复位清除；
- STOP、abort和system fault均不直接进入峰谷检测器清除端口；AMI先形成带触发身份的generation-scoped detection discard，PWI原样广播后在接收沿清除该`run_generation`的全部在途事件和运行状态，并保留sticky供软件读取；`identity_valid=0`的scope-only flush同样必须清理该代际；
- `i_diag_clear_event`：只清除sticky，不改变运行极值、窗口或ready/valid事务。

若新异常事件与`i_diag_clear_event`同拍发生，异常置位优先，禁止丢失诊断。

## 13. sticky诊断

### 13.1 输出定义

| 输出 | 语义 |
| --- | --- |
| `o_fine_window_timeout_sticky` | 自上次清除后至少一次正式15-bit窗口超时 |
| `o_reacquire_timeout_sticky` | 自上次清除后至少一次9-bit重新获取单轮超时 |
| `o_protocol_error_sticky` | 自上次清除后至少一次配置、帧序、epoch或模式协议异常 |

sticky是1-bit电平状态，不是ready/valid事件。恢复成功不会自动清除历史标志。三个标志相互独立，允许
同时为1，并最终映射到SPI只读状态寄存器。

### 13.2 清除优先级

每个sticky使用独立寄存器，优先级冻结为：

```text
异步复位
-> 新异常置位
-> i_diag_clear_event清除（仅当无本地活动故障）
-> 保持
```

START、STOP和lifecycle discard均不清sticky，确保软件可以在停止后读取故障原因。

## 14. 模块端口合同

### 14.1 全局和生命周期

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_clk` | 1 | 2 MHz数字处理时钟 |
| input | `i_rstn` | 1 | 低有效异步复位，释放由顶层同步 |
| input | `i_run_enable` | 1 | 当前生命周期允许NORMAL检测 |
| input | `i_start_ack_event` | 1 | 新RUN正式开始 |
| input | `i_diag_clear_event` | 1 | 软件已读取并请求清除sticky |
| input | `i_recheck_accept_event` | 1 | AMB/DC重检实际安全接管 |
| input | `i_recheck_busy` | 1 | 重检和FIR恢复期间禁止正式检测 |
| input | `i_recheck_done_event` | 1 | 三帧重检结束事件 |
| input | `i_recheck_success` | 1 | 重检结果，失败保持安全9-bit |
| input | `i_reacquire_active` | 1 | 动态基线要求在9-bit重新获取锚点 |

### 14.2 ACTIVE配置输入

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_peak_confirm_count` | 4 | 波峰下降确认数 |
| input | `i_valley_confirm_count` | 4 | 波谷上升确认数 |
| input | `i_direction_deadband` | 24 | unsigned统一PPG码死区 |
| input | `i_min_peak_valley_amplitude` | 24 | unsigned最小峰谷幅度 |
| input | `i_min_peak_to_valley_frames` | 16 | 最小峰谷帧差 |
| input | `i_min_peak_to_peak_frames` | 16 | 最小峰峰帧差 |
| input | `i_max_fine_window_frames` | 16 | 最大正式窗口帧数 |
| input | `i_max_reacquire_frames` | 16 | 单轮重新获取最大帧数 |
| input | `i_peak_valley_config_valid` | 1 | 正式配置有效标志 |
| input | `i_characterization_mode` | 1 | 允许临时门限但不得冒充正式资格 |

### 14.3 FIR输入事务

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_result_valid` | 1 | 粗FIR保持型事务valid |
| output | `o_result_ready` | 1 | 本模块允许接收当前FIR事务 |
| input | `i_filtered_ppg_value` | signed 24 | Stage1粗FIR统一PPG码 |
| input | `i_detection_qualified` | 1 | FIR窗口具备正式检测资格 |
| input | `i_window_saturation_low/high` | 各1 | FIR输入窗口端点饱和诊断 |
| input | `i_fir_saturation_low/high` | 各1 | FIR输出显式饱和诊断 |
| input | `i_config_epoch` | 8 | 中心样本ACTIVE版本 |
| input | `i_coef_epoch` | 8 | 中心样本Stage1系数版本 |
| input | `i_dc_recovery_coef_epoch` | 8 | 中心样本DC恢复版本 |
| input | `i_precision_mode` | 1 | 中心样本采集时历史精度，用于过渡尾部和正式fine资格判定 |
| input | `i_frame_id` | 16 | 中心样本400 Hz帧号 |
| input | `i_sample_index` | 16 | 中心样本事务号 |
| input | `i_color_ir` | 1 | 0为RED，1为IR |
| input | `i_frame_type` | 2 | 正式检测必须为NORMAL编码10 |

### 14.4 正式窗口控制

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_fine_window_start_event` | 1 | PPG 15-bit窗口已经在安全边界正式提交 |
| input | `i_fine_window_start_frame_id` | 16 | 第一笔正式15-bit帧号 |
| input | `i_active_precision_mode` | 1 | 当前模拟时序已提交精度，不要求与延迟中心样本逐拍相等 |
| output | `o_return_9bit_valid` | 1 | 保持型返回9-bit请求 |
| input | `i_return_9bit_ready` | 1 | 模式控制器接受返回请求 |
| output | `o_return_reason` | 2 | 谷值成功、窗口超时或协议回退 |
| output | `o_return_frame_id` | 16 | 请求绑定的确认或超时帧号 |

### 14.5 波峰事件输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| output | `o_peak_valid` | 1 | 可靠码值波峰事件valid |
| input | `i_peak_ready` | 1 | 动态基线模块允许消费 |
| output | `o_peak_value` | signed 24 | 保存的运行最大值 |
| output | `o_peak_frame_id` | 16 | 波峰实际中心帧 |
| output | `o_peak_sample_index` | 16 | 波峰实际中心事务号 |
| output | `o_peak_config_epoch` | 8 | 波峰ACTIVE版本 |
| output | `o_peak_coef_epoch` | 8 | 波峰Stage1系数版本 |
| output | `o_peak_dc_recovery_coef_epoch` | 8 | 波峰DC恢复版本 |

### 14.6 波谷事件输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| output | `o_valley_valid` | 1 | 可靠码值波谷事件valid |
| input | `i_valley_ready` | 1 | 动态基线模块允许消费 |
| output | `o_valley_value` | signed 24 | 保存的运行最小值 |
| output | `o_valley_frame_id` | 16 | 波谷实际中心帧 |
| output | `o_valley_sample_index` | 16 | 波谷实际中心事务号 |
| output | `o_valley_config_epoch` | 8 | 波谷ACTIVE版本 |
| output | `o_valley_coef_epoch` | 8 | 波谷Stage1系数版本 |
| output | `o_valley_dc_recovery_coef_epoch` | 8 | 波谷DC恢复版本 |

### 14.7 状态和诊断输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| output | `o_detector_idle` | 1 | 真实输出、返回/恢复事务、入口尾部和生命周期清理均已排空；被动退出尾部不单独阻挡重检接管 |
| output | `o_fine_window_active` | 1 | 正式PPG 15-bit窗口已提交且未结束 |
| output | `o_reacquire_search_active` | 1 | 当前在9-bit重新获取波峰 |
| output | `o_fine_window_timeout_sticky` | 1 | 窗口超时历史标志 |
| output | `o_reacquire_timeout_sticky` | 1 | 重新获取超时历史标志 |
| output | `o_protocol_error_sticky` | 1 | 协议、配置或帧序异常历史标志 |

端口实现允许把相关载荷内部打包为保持寄存器，但模块边界必须使用上述离散Verilog-2001端口，不得依赖
SystemVerilog结构体。

### 14.1 V2.3 detection lifecycle ports

The detector receives PWI's registered 2 MHz
`i_detection_discard_event/reason/identity_valid/sample_valid/TXN_ID` and `i_run_generation`. It does not
acknowledge this event. At its sampling edge it clears pending peak/valley
candidate, window and output state for the event `run_generation` exactly once,
including legal `identity_valid=0` scope-only flush; local empty can be asserted
no earlier than the following cycle. No peak, valley, window or precision request
is generated for a discarded or stale generation.
`i_sample_valid=0` cannot build extrema or advance detection qualification.

## 15. epoch和周期资格

同一正式峰谷周期必须使用一致的配置语义。至少要求峰值和谷值的：

```text
config_epoch
coef_epoch
dc_recovery_coef_epoch
```

逐字段一致。NORMAL慢速DC码调整不会改变DC恢复系数epoch，因此允许一个周期内`dc_code_epoch`变化；
本模块不使用IDAC码版本替代系数版本。

若峰谷epoch不一致：

- 保留数值用于CHARACTERIZATION诊断；
- 不输出正式波谷成功事件；
- 不允许该周期更新动态基线自适应斜率；
- 正式窗口继续搜索至新合格周期或超时；
- 置位协议诊断。

## 16. 自检验收矩阵

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| PVW-01 | 异步复位 | valid、极值、计数、窗口和sticky确定性清零 |
| PVW-02 | 新START | 保持9-bit并进入首峰重新获取 |
| PVW-03 | 首个可靠波峰 | 免除峰峰时间检查并输出锚点 |
| PVW-04 | 波峰连续3点下降 | 第3个下降样本确认，事件时间仍绑定运行最大值 |
| PVW-05 | 相同最大值平台 | 保存最后一个相同最大值的中心元数据 |
| PVW-06 | 波峰死区平坦 | 计数保持但不增加 |
| PVW-07 | 波峰反方向 | 下降计数清零且无伪事件 |
| PVW-08 | 峰峰时间不足 | 拒绝局部波峰并继续搜索 |
| PVW-09 | 合格峰峰时间 | 模回绕帧差正确接受 |
| PVW-10 | 波谷连续3点上升 | 第3个上升样本确认，事件时间仍绑定运行最小值 |
| PVW-11 | 相同最小值平台 | 保存最后一个相同最小值的中心元数据 |
| PVW-12 | 波谷死区平坦 | 上升计数保持但不增加 |
| PVW-13 | 波谷反方向 | 上升计数清零并允许更新更低最小值 |
| PVW-14 | 峰谷幅度不足 | 不输出谷值、不返回9-bit并继续跟踪 |
| PVW-15 | 峰谷时间不足 | 不输出谷值、不返回9-bit并继续跟踪 |
| PVW-16 | 合格峰谷 | 原子输出谷值和完整实际元数据 |
| PVW-17 | FIR群延时 | 中心绑定`x[n-10]`，不重复减去10帧，不使用确认帧替代极值帧 |
| PVW-18 | IR交错 | 消费IR但RED状态逐位不变 |
| PVW-19 | 无效或饱和RED | 不形成方向证据或正式事件 |
| PVW-20 | 非预期跳帧 | 清方向计数、保留正式周期并置协议诊断 |
| PVW-21 | 9/15-bit普通切换 | FIR趋势、运行极值和计数连续，合法历史精度尾部不报错 |
| PVW-22 | 正式fine start | 只建立窗口资格和起始帧，不清粗链状态 |
| PVW-23 | 手动15-bit无start | 不建立正式PPG窗口 |
| PVW-24 | 谷值返回请求 | 保持valid和原因，握手后等待实际9-bit |
| PVW-25 | fine窗口超时 | 无伪谷值、请求返回9-bit、置sticky并重新获取 |
| PVW-26 | 重新获取超时 | 保持9-bit、置sticky、清候选并自动开始下一轮 |
| PVW-27 | 超时后重新获取成功 | 输出新峰值并恢复固定斜率基线建立资格 |
| PVW-28 | 峰值反压 | valid和全部载荷逐拍稳定，不接受覆盖事件 |
| PVW-29 | 谷值反压 | valid和全部载荷逐拍稳定，不重复消费 |
| PVW-30 | 返回请求反压 | 请求原因和frame_id保持，模式不提前切换 |
| PVW-31 | epoch不一致 | 不提交正式完整周期并置协议诊断 |
| PVW-32 | recheck pending | 不清极值、不清计数、不改变窗口状态 |
| PVW-33 | recheck安全接管 | 仅FIR和检测器均idle时允许accept |
| PVW-34 | recheck accept | 清峰谷上下文，三帧期间无正式事件 |
| PVW-35 | STOP | 清运行事务但保留sticky供软件读取 |
| PVW-36 | abort | 撤销窗口和在途事件，禁止迟到提交 |
| PVW-37 | sticky清除 | 新异常优先于同拍全局`diag_clear`，STOP和新START均不清历史sticky |
| PVW-38 | 非法ACTIVE | 禁止正式事件并置协议诊断 |
| PVW-39 | frame_id半回绕 | 拒绝非法跨度，无自然回绕误判 |
| PVW-40 | 随机宽位回归 | 与独立软件黄金模型逐事务一致 |
| PVW-41 | 9-bit峰后长期无谷 | 保持9-bit、无返回请求、置重新获取timeout并重启峰值搜索 |
| PVW-42 | 进入15-bit流水尾部 | 最多10笔旧9-bit RED中心样本继续更新粗趋势，第11笔仍未排空则报协议错误 |
| PVW-43 | fine起点前中心样本 | 负帧龄不超时、不报回绕、不形成正式fine峰谷对 |
| PVW-44 | fine波峰资格 | 只有起始帧或之后的15-bit中心波峰可与波谷组成正式返回结论 |
| PVW-45 | 返回9-bit流水尾部 | 返回提交后最多10笔旧15-bit RED中心样本合法，第11笔仍未排空则报协议错误 |
| PVW-46 | 被动退出尾部允许重检接管 | 仅`flag_exit_precision_tail_active=1`且真实输出、返回等待、恢复事务、入口尾部和生命周期清理均已排空时，`o_detector_idle=1`；`i_recheck_accept_event`随后原子清除退出尾部及旧峰谷上下文 |
| PVW-47（2026-09-17新增） | 精度提前下降（§10.5第2条） | 正式窗口尚未完成返回握手却观察到`i_active_precision_mode=0`：撤销当前窗口资格、置位协议诊断并进入重新获取 |
| PVW-48（2026-09-17新增） | RETURN_REASON_PROTOCOL回退（§11.4） | 正式fine窗口活跃期间配置失效（`flag_active_config_legal=0`）：产生`RETURN_REASON_PROTOCOL`(2'b10)返回请求 |

自检TB必须覆盖PVW-01至PVW-48，并设置有界watchdog。所有PASS必须来自真实比较，不得使用空检查或
仅打印通过文本。

## 17. RTL实现与验证门禁

后续实现必须满足：

- 可综合Verilog-2001，不使用RTL `function`、`task`、`initial`、延时或系统任务；
- Erie strict双语文件头、ANSI端口、Tab缩进、区域归属、输出桥和中文实体注释；
- 低有效异步复位，释放由顶层同步；
- 状态机采用明确`state_current/state_next`三段式结构和`ST_*`编码；
- 每个时序`always`块只有一个主要寄存目标；
- signed差值、幅度和模帧差显式扩位，无隐式符号转换或自然回绕；
- 保持型事件在反压期间逐位稳定；
- 无门控时钟、锁存器、多驱动、组合环和未约束变量循环；
- formatter-AST严格门禁0 error、0 strict warning；
- 独立静态lint、PVW自检TB、Vivado xvlog/xelab/xsim和综合全部通过；
- 综合报告锁存器0、Blackbox 0，并记录LUT、寄存器、DSP、WNS/TNS和全部非阻断警告。

## 18. ACTIVE和状态寄存器版本策略

本文冻结逻辑字段，不修改现有640-bit ACTIVE V4，也不得静默解释`reserved_extension_v4`。后续实现前
必须检查V4保留空间；现行1024-bit联合ACTIVE的V5 `[1023:640]`已原子映射第3.2节全部配置字段和
`peak_valley_config_valid`，本模块只能由PWI接收具名字段。

三个sticky诊断和必要的当前状态必须映射到SPI只读状态寄存器。读状态不得清除sticky；清除必须由
明确的`diag_clear`写命令或复位完成；新START只建立新的运行代际，不能清历史诊断。

## 19. V3冻结结论

V3正式冻结为：

- 9-bit和15-bit共用连续Stage1粗FIR检测链；
- 波峰后连续3个下降样本确认，波谷后连续3个上升样本确认；
- 方向死区和最小幅度由SPI表征配置；
- 相同极值平台保存最后一个相同极值的实际中心元数据；
- 默认最小峰谷20帧、最小峰峰100帧、最大fine窗口600帧、重新获取1000帧；
- 资格不足继续搜索，不提前退出；
- fine窗口由明确commit事件建立，谷值或超时通过保持型请求返回9-bit；
- 重新获取失败始终保持9-bit并自动重试；
- 普通精度切换不清历史；实际重检和lifecycle discard只清对应代际的运行状态，STOP/abort同样经discard清运行状态；历史sticky只由`diag_clear`或复位清除；
- 20阶FIR输出绑定`x[n-10]`，极值时间不得再次减去10帧；
- 当前committed精度与中心样本历史精度允许存在最多10笔同色有效样本的合法切换尾部；
- 被动15-bit退出尾部不单独阻止`o_detector_idle`和AMB重检安全接管，实际accept时原子废止该尾部；
- 未消费peak、valley、return、返回等待、异常恢复、进入尾部和生命周期清理仍必须严格阻止接管；
- fine起点前的9-bit中心样本继续维护粗趋势，但不计窗口帧龄，也不能建立正式fine峰谷对；
- 峰值、谷值、返回请求和全部元数据原子保持；
- timeout和协议异常使用可由SPI读取的sticky历史诊断；
- ACTIVE V4保持不变，配置字段进入现行版本化V5 `[1023:640]`，V5保留位不参与功能。

任何改变以上极性、时间、门限、事务或清理语义的实现，都必须先修订本文，再修改RTL和自检TB。
