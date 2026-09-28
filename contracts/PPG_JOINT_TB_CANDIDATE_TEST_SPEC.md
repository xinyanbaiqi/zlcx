# Scheduler + SSW + AMI联合TB冻结候选测试说明

> 状态：候选测试说明，尚未作为RTL/TB实现声明
> 修订日期：2026-08-17
> 目的：冻结正式术语、合法启动配置和联合TB验收边界
> 本文不修改模块合同、RTL、TB或既有仿真日志

## 1. 正式术语

以ACTIVE V4配置映射合同为术语源，联合TB只使用以下枚举名称：

| 字段 | 编码/名称 |
| --- | --- |
| `idac_mode` | `MANUAL`、`SEARCH_HOLD`、`SEARCH_TRACK`、`RESERVED` |
| `input_source` | `PHOTODIODE`、`EXTERNAL_TEST_CURRENT` |
| `optical_mode` | `BOTH`、`RED_ONLY`、`IR_ONLY`、`OFF` |
| `run_profile` | `NORMAL_PPG`、`CHARACTERIZATION` |
| 精度 | `SAR9`、`SAR15` |
| 校准事务 | `AMB_CAL`、`DCS_CAL`，颜色由`RED/IR`字段确定 |

`OFF`只表示安全关闭，不表示固定电流测量。`HOLD`、`TRACK`只作为
`SEARCH_HOLD`、`SEARCH_TRACK`的一部分出现。联合TB和报告只使用本节冻结的正式枚举名称。

## 2. 联合TB边界

联合TB连接真实的Scheduler、SSW和AMI实例，验证：

```text
Scheduler waveform context
    -> SSW模拟波形和IDAC总线
Scheduler ADC事务
    -> AMI真实fire和结果链
真实CLK_DOUT/RAW
    -> AMI完成旁带
完成旁带
    -> Scheduler/SSW释放owner
```

配置管理器、SPI CDC和最终fault supervisor不是本联合TB的被测实例。TB必须提供已经提交的
ACTIVE快照、MANUAL码/epoch和独立运行许可，并检查非法配置的防御性隔离。

许可连接固定为：

```text
analog_run_enable                  -> SSW
measurement_run_enable             -> Scheduler + AMI
measurement_allow_new_transaction  -> Scheduler + AMI
```

普通NORMAL或CHARACTERIZATION测量：

```text
analog_run_enable                  = 1
measurement_run_enable             = 1
measurement_allow_new_transaction  = 1
```

STATIC_BIAS：

```text
analog_run_enable                  = 1
measurement_run_enable             = 0
measurement_allow_new_transaction  = 0
```

独立回归仍需保留IDT、AMI、FIR、BSL、PVW、PWI和其他算法模块的既有测试；联合TB只证明真实跨模块事务链。

## 3. 合法启动配置矩阵

| 场景 | `run_profile` | `input_source` | `static_characterization_enable` | `optical_mode` | 精度 | `idac_mode` | 许可/输出 |
| --- | --- | --- | ---: | --- | --- | --- | --- |
| NORMAL双光 | `NORMAL_PPG` | `PHOTODIODE` | 0 | `BOTH` | 初始`SAR9` | `MANUAL`/`SEARCH_HOLD`/`SEARCH_TRACK` | RED后IR，LED按PD合同驱动 |
| NORMAL纯RED | `NORMAL_PPG` | `PHOTODIODE` | 0 | `RED_ONLY` | 初始`SAR9` | `MANUAL`/`SEARCH_HOLD`/`SEARCH_TRACK` | 仅RED |
| NORMAL纯IR | `NORMAL_PPG` | `PHOTODIODE` | 0 | `IR_ONLY` | 初始`SAR9` | `MANUAL`/`SEARCH_HOLD`/`SEARCH_TRACK` | 仅IR |
| SAFE_OFF（非测量） | `NORMAL_PPG` | `PHOTODIODE` | 0 | `OFF` | 不参与 | 不参与 | 无新波形、owner或测量事务 |
| 光电二极管固定RED SAR9 | `CHARACTERIZATION` | `PHOTODIODE` | 0 | `RED_ONLY` | 固定`SAR9` | `MANUAL` | `EN_TEST=0`，IR关闭 |
| 光电二极管固定RED SAR15 | `CHARACTERIZATION` | `PHOTODIODE` | 0 | `RED_ONLY` | 固定`SAR15` | `MANUAL` | `EN_TEST=0`，IR关闭 |
| 外部固定电流SAR9双光 | `CHARACTERIZATION` | `EXTERNAL_TEST_CURRENT` | 0 | `BOTH` | 固定`SAR9` | `MANUAL` | `EN_TEST=1`，LEDEN/LEDDAC关闭 |
| 外部固定电流SAR9纯RED | `CHARACTERIZATION` | `EXTERNAL_TEST_CURRENT` | 0 | `RED_ONLY` | 固定`SAR9` | `MANUAL` | `EN_TEST=1`，LEDEN/LEDDAC关闭 |
| 外部固定电流SAR9纯IR | `CHARACTERIZATION` | `EXTERNAL_TEST_CURRENT` | 0 | `IR_ONLY` | 固定`SAR9` | `MANUAL` | `EN_TEST=1`，LEDEN/LEDDAC关闭 |
| 外部固定电流SAR15双光 | `CHARACTERIZATION` | `EXTERNAL_TEST_CURRENT` | 0 | `BOTH` | 固定`SAR15` | `MANUAL` | `EN_TEST=1`，LEDEN/LEDDAC关闭 |
| 外部固定电流SAR15纯RED | `CHARACTERIZATION` | `EXTERNAL_TEST_CURRENT` | 0 | `RED_ONLY` | 固定`SAR15` | `MANUAL` | `EN_TEST=1`，LEDEN/LEDDAC关闭 |
| 外部固定电流SAR15纯IR | `CHARACTERIZATION` | `EXTERNAL_TEST_CURRENT` | 0 | `IR_ONLY` | 固定`SAR15` | `MANUAL` | `EN_TEST=1`，LEDEN/LEDDAC关闭 |
| STATIC_BIAS | `CHARACTERIZATION` | `EXTERNAL_TEST_CURRENT` | 1 | 不参与测量选择 | 不参与 | 不参与 | 仅SSW模拟许可 |

固定电流的`BOTH`按RED后IR产生两笔400 Hz间歇测量；`RED_ONLY`只产生RED事务；`IR_ONLY`
只产生IR事务。`optical_mode`只选择测量颜色和ADC波形，不重新打开LED。

所有CHARACTERIZATION非STATIC_BIAS测量都使用已提交的MANUAL AMB/DC码，SAR精度在整个RUN内固定，
不执行自动搜索、慢速跟踪、周期AMB重检或精度切换。

STATIC_BIAS的`input_source=EXTERNAL_TEST_CURRENT`是START资格的一部分；它不参与静态向量选择，
但`input_source=PHOTODIODE`必须拒绝。STATIC_BIAS不产生ADC事务、不推进正常frame/sample计数。

## 4. 非法配置和START副作用

以下组合不得成为合法RUN：

```text
NORMAL_PPG + initial_precision=SAR15
NORMAL_PPG + input_source=EXTERNAL_TEST_CURRENT
CHARACTERIZATION + idac_mode=SEARCH_HOLD
CHARACTERIZATION + idac_mode=SEARCH_TRACK
CHARACTERIZATION + PHOTODIODE + optical_mode!=RED_ONLY
CHARACTERIZATION + EXTERNAL_TEST_CURRENT + optical_mode=OFF
CHARACTERIZATION + AMB_CAL/DCS_CAL实际运行请求
SAR15 + AMB_CAL/DCS_CAL实际运行请求
STATIC_BIAS + input_source=PHOTODIODE
idac_mode=RESERVED
保留frame type或非法枚举编码
```

静态配置非法时，配置管理器在COMMIT/START前报告明确错误原因。固定电流`OFF`组合使用配置错误
`8'h16`；实际`AMB_CAL/DCS_CAL`请求由Scheduler/AMI在波形或ADC owner启动前拒绝，不增加
`calibration_plan`字段。

非法START或非法运行时请求必须满足：

```text
无有效START ACK
无IDAC启动边界
无400 Hz宏帧启动
无waveform context
无ADC owner
frame_id/sample_index不变
模拟输出保持安全
报告配置或协议错误
```

STATIC_BIAS是唯一例外：SSW可以接收`analog_start_ack_event`建立静态向量；Scheduler和AMI
不得收到测量START，不得产生测量事务、owner或序号变化。

## 5. 启动IDAC码确定闭环

### 5.1 MANUAL

```text
合法START
 -> Scheduler等待模拟和ADC安全
 -> 一次startup IDAC安全边界
 -> 原子提交ACTIVE中的AMB、DC_R、DC_IR MANUAL码
 -> code/epoch更新
 -> startup_search_complete=1
 -> 开放首个NORMAL宏帧
```

不通过ADC结果搜索码值。

### 5.2 SEARCH_HOLD

```text
START
 -> 安全边界提交AMB初始候选
 -> AMB_CAL二分搜索并确认AMB
 -> DCS_CAL（RED）使用已确认AMB搜索DC_R
 -> DCS_CAL（IR）使用同一已确认AMB搜索DC_IR
 -> 三路成功提交
 -> startup_search_complete=1
 -> 开放NORMAL
 -> 后续码值保持
```

所有候选码先进入pending，只有安全边界才可提交；任一路失败都必须阻断NORMAL。

### 5.3 SEARCH_TRACK

启动搜索与`SEARCH_HOLD`相同。进入NORMAL后才允许RED/IR独立慢速1 LSB调码、周期AMB重检以及
AMB变化后的DC_R/DC_IR重新验证。联合TB场景名称使用：

```text
JNT-PWR-MANUAL
JNT-PWR-SEARCH-HOLD
JNT-PWR-SEARCH-TRACK
JNT-PWR-SNAPSHOT
JNT-PWR-FAIL
JNT-PWR-DISABLE
JNT-PWR-RESTART
JNT-PWR-NO-DEADLOCK
```

自动搜索期间严格按AMB -> DC_R -> DC_IR顺序执行，所有校准使用SAR9；每个625-tick子周期最多
观察一个真实候选，搜索期间不开放NORMAL波形。

## 6. 物理波形时序

TB必须使用冻结合同和netlist的tick常数，不能自行推导或移动时序。至少检查：

- RED waveform context接管点为tick 0；IR接管点为tick 160；
- RED Q3中心为tick 300，IR Q3中心为tick 460；
- 校准Q3中心为local tick 266；
- SAR9/SAR15预热区间严格采用各自netlist；
- IR可以在RED ADC owner未释放时预建立，但不改变RED波形；
- 只有合同规定的跨色白名单信号允许连续保持；
- Q3、包络末沿或`adc_idle`都不能伪造ADC DONE；
- 固定电流三种模式LEDEN/LEDDAC保持关闭，`OFF`不发布波形。

正式物理时间基准为2 MHz，即`C_CLK_PERIOD_NS=500`；tick数值和合同时序不因仿真缩放改变。

## 7. ADC owner和完成链

```text
waveform context
 -> 预建立
 -> Q1/Q2/Q3
 -> 真实CLK_DOUT/RAW
 -> AMI身份匹配
 -> completion sideband
 -> Scheduler/SSW释放owner
```

必须覆盖RED owner、IR预建立、RED释放后IR owner提交、真实sample_index递增和以下错误路径：

- frame、sample、color、precision、transaction type、code、epoch任一字段错配；
- 无owner DONE、重复DONE、reset后旧DONE；
- owner deadline超时；
- `success=1`匹配完成允许正式结果；
- `success=0`匹配完成只释放owner，不产生正式成功结果、IDAC消费或校准成功；
- abort后的迟到DONE以原owner身份匹配并按`success=0`丢弃；
- 错配或无owner完成不得释放当前owner。

禁止使用“fire后固定4拍DONE”模型。ADC模型必须观察实际Q3结束和捕获窗口后，异步产生满足时序的`CLK_DOUT/RAW`。

## 8. 四组IDAC数据总线

逐bit、逐tick检查：

```text
IDAC_BUS[k] = 模式资格
           && 精度资格
           && 事务类型资格
           && netlist时间窗口
           && 帧开始前锁存的code[k]
```

- SAR9事务只允许SAR9 AMB/DC总线；SAR15事务只允许SAR15 AMB/DC总线；
- 未选精度的两组总线全程为零；
- AMB_CAL只允许SAR9 AMB候选总线；
- DCS_CAL使用已确认AMB和当前颜色DC候选；
- STATIC_BIAS四组总线全为零；
- 当前帧中途改变shadow、pending或实时输入码不能改变当前波形；
- 新码只在下一次合法安全边界后生效。

## 9. NORMAL精度、tracking和PPG闭环

NORMAL只能从SAR9启动。合法精度路径为：

```text
NORMAL SAR9
 -> 至少21笔真实SAR9结果预热FIR
 -> 动态基线建立并向上相交
 -> 宏帧安全边界切换SAR15
 -> 峰谷形成
 -> 合法返回请求
 -> 宏帧安全边界返回SAR9
```

PPG算法闭环场景固定为：

```text
run_profile                  = NORMAL_PPG
input_source                 = PHOTODIODE
optical_mode                 = BOTH
initial_precision            = SAR9
heart_rate                   = 60 BPM
完整心搏数                   >= 10
正式物理运行时间             >= 10 s
```

在2 MHz、400 Hz宏帧合同下，10秒对应至少4000个宏帧；`BOTH`模式应产生每个宏帧的RED和IR测量事务，
每个颜色至少接收4000个真实ADC结果。该场景必须使用真实RAW序列和真实`CLK_DOUT`捕获，不得直接改写
baseline、pending、committed precision、峰谷或FIR历史状态。

联合 TB 的确定性 PPG RAW 发生器冻结为每颜色每宏帧一个样本：

```text
快速收缩上升 -> 较慢舒张下降 -> 重搏切迹 -> 缓慢三角基线漂移 -> 固定幅度确定性噪声
```

发生器使用RED/IR独立基线和脉动幅度，60 BPM下每颜色每心搏400个样本；样本索引只由该颜色
已完成的真实owner计数提供。每笔样本必须严格执行：

```text
waveform_context握手
 -> 当前owner提交
 -> 选定精度Q1/Q2/Q3
 -> Q3释放
 -> 异步CLK_DOUT/RAW脉冲
 -> AMI完成旁带
```

`drive_ppg_adc_done`只能在观察到对应颜色的Q1、Q2、Q3并确认Q3释放后调用异步RAW驱动；
不得以固定拍数产生DONE，不得使用`force`或层次引用修改AMI内部状态。SAR9只提供Stage1 RAW，
SAR15同时提供Stage1和Stage2 RAW，RAW编码必须由公开的Stage1物理位定义反推目标检测码。

算法闭环必须按公开状态和事件检查以下顺序：

```text
FIR预热（至少21笔真实SAR9结果）
 -> o_baseline_valid
 -> o_cross_pending
 -> o_fine_window_start_event / SAR9到SAR15安全切换
 -> o_active_precision_mode = SAR15
 -> o_peak_pending与o_valley_pending形成
 -> o_precision_15_to_9_event / SAR15返回SAR9
 -> 旧SAR15 FIR尾部与返回SAR9首笔结果隔离
```

必须同时检查`frame_id`、`sample_index`连续性、400 Hz宏帧无漂移、无重复或跨精度历史拼接，以及
切换前后IDAC code/epoch快照的合法性。若10个完整心搏或10秒物理时间未完成，不能将该算法闭环记为PASS。

必须检查旧SAR15 FIR尾部隔离、跨精度sample/frame连续性和切换时IDAC tracking状态保持。

`SEARCH_TRACK`下还必须覆盖：

```text
连续真实NORMAL结果越界
 -> 确认计数
 -> pending
 -> 安全边界提交±1 LSB
 -> epoch+1
 -> 当前帧不变
 -> 下一帧采用新码
```

RED/IR tracking状态独立，并跨SAR9/SAR15精度保持。CHARACTERIZATION固定精度不得进入该路径。

## 10. CHARACTERIZATION、STATIC_BIAS和safe-off

### CHARACTERIZATION

覆盖纯RED光电二极管固定SAR9/SAR15、外部固定电流`BOTH/RED_ONLY/IR_ONLY`的SAR9/SAR15，
检查`EN_TEST`、LEDEN、LEDDAC、固定精度、MANUAL码快照以及无自动搜索、跟踪、周期重检和精度切换。

### STATIC_BIAS

覆盖SSW模拟许可、Scheduler/AMI测量静默、完整静态0/1向量、`S[4:0]`原子更新以及
`input_source=0`拒绝。不得产生ADC、owner、宏帧测量、IDAC事务或正常序号推进。

### safe-off

`optical_mode=OFF`只作为安全关闭验证，不属于外部固定电流测量矩阵。联合 TB 必须明确断言：

```text
safe-off进入后保持5000个2 MHz tick的宏帧时基；
每到一个5000-tick边界，frame_id按合同推进且每个边界只推进一次；
safe-off期间sample_index保持进入safe-off时的值，不产生任何ADC owner；
safe-off期间不产生waveform context、IDAC启动边界或成功NORMAL测量结果；
safe-off期间不产生AMB_CAL/DCS_CAL或tracking pending；
退出safe-off前不得发布NORMAL成功完成旁带。
```

TB 必须同时检查 `frame_id` 的边界推进和 `sample_index` 的不变性，不能只检查模拟输出为安全电平。

## 11. 固定基线和扩展顺序

JNT-01～09（当前52个子检查）作为每次联合回归的固定基线，既有判据不修改。每个新增测试组都必须
在独立复位后先完整执行JNT-01～09，并确认52个子检查全部PASS，之后才允许启动该测试组的正式激励。
基线PASS不代表新增CHARACTERIZATION、STATIC_BIAS、启动搜索、tracking、PPG算法或最终顶层闭合已经通过。

每个新增测试组的执行门槛固定为：

```text
独立复位
 -> 执行JNT-01～09
 -> 确认52个子检查全部PASS
 -> 清理本组计数器和证据标志
 -> 执行本组场景
```

若任一JNT基线检查失败、超时或出现未预期协议错误，则该测试组必须记录为`NOT_RUN`或`BLOCKED`，不得记录为PASS，
也不得使用该组后续偶然通过的局部检查覆盖基线失败。

在基线通过后，按以下顺序扩展：

1. 重新运行JNT-01～09；
2. 加入合法CHARACTERIZATION和STATIC_BIAS；
3. 加入非法配置和运行时校准拒绝；
4. 加入MANUAL、`SEARCH_HOLD`、`SEARCH_TRACK`启动闭环；
5. 加入tracking、AMB重检和PPG精度闭环；
6. 做多宏帧连续性、fault/abort/reset和长时间回归。

本文只冻结测试语义，不宣称上述新增场景已经有RTL、TB或XSim证据。
