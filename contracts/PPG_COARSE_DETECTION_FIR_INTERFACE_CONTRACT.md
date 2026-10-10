# PPG粗检测FIR接口与数学合同

> V2.6修订日期：2026-10-09。B合同合并批次（`verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-183，F-015与ID治理S2）：文末当前证据状态段订正——`tb_ppg_coarse_detection_fir.v`（2026-09-16 V2.1起）已驱动`i_sample_valid`并有FIR-31/32/33定向检查；验收表只到FIR-33，“FIR-31至FIR-36”的说法按表格订正为FIR-31至FIR-33。文件头V2.2/V2.5历史行中的范围说法属带日期历史叙述，保持原样。
> V2.5 verification-only injection addendum, 2026-08-31: adds an additive, default-off `C_ENABLE_TEST_INJECTION` capability (mirrors the AMI/SSW/IDAC-controller injection family already frozen in the Stage 5 bucket-1 RTL session). One-shot `i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready` (gated by `i_test_inject_enable`) binds to the very next real `flag_input_transfer` and forces that single sample's own calibration term of `flag_sample_qualified` to 0, without touching the shared `i_coarse_recovery_calibrated` port or any static config bit. This exercises FIR-17's already-documented "an uncalibrated sample still enters history but its covering windows lose formal qualification, then recovers" behavior under real top-level construction, closing the Stage 5 PRC-09/PRC-10 gap. No FIR-01~36 acceptance text is changed; production behavior is bit-identical when `C_ENABLE_TEST_INJECTION=0`. Port threading through `ppg_precision_window_integration.v`/`ppg_adc_measurement_idac_integration.v`/`ppg_control_top.v` and real dual-tool construction evidence are tracked as separate, not-yet-closed follow-up steps -- this addendum records the RTL-level contract only.

> V2.4 fail-closed integration review, 2026-08-20: independent qualification, generation-scoped detection discard, generation and local-empty semantics remain normative, but system closure is `NOT_CLOSED` until the matrix audit records zero defects. Implementation evidence is `EVIDENCE_PENDING`.

> Historical V2.1 interface record (non-normative): the independent sample-valid behavior has authority only as incorporated by V2.4; it is not a separate current contract version and its RTL/TB evidence is `EVIDENCE_PENDING`.
> Historical V1/V2/V2.1 dates: 2026-08-08 / 2026-08-11 / 2026-08-20. They do not define a current version.
> Historical V2.1 revision: `i_sample_valid` behavior is incorporated by V2.4; invalid transactions are atomically consumed without moving history, incrementing counters, starting MAC work or advancing downstream detection/precision state. This record cannot create a separate V2.1 authority.
> V2.2 historical status note: FIR-01至FIR-30 are V2 history. The current FIR-31至FIR-36 interface is normative, but its system closure verdict is owned only by the current fail-closed matrix audit. RTL/TB evidence remains `EVIDENCE_PENDING`.  
> 目标RTL：`ppg_coarse_detection_fir.v`  
> 上游：`ppg_adc_dc_recovery.v`  
> 下游：负斜率动态基线、码值向上相交、码值波峰、运行最小值、码值波谷经过确认及精度窗口控制模块  
> 适用时钟域：2 MHz数字处理域  
> 有效样本率：每个颜色400 Hz

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C15 | `ppg_system_integration/PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md` | V1 | Sole recovered-NORMAL coarse-sample source. |
| C18 | `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.2 | Sole detection parent, V5 forwarding and discard broadcast owner. |
| C20 | `ppg_system_integration/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md` | V2.6 | One direct detection-fork consumer of FIR output. |
| C22 | `ppg_system_integration/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md` | V2.6 | One direct detection-fork consumer of FIR output. |
| C23 | `ppg_system_integration/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md` | V2.7 | Consumes FIR local-empty/qualification and cannot redefine FIR ownership. |

## 1. 合同目的

本文冻结片内粗检测FIR的信号来源、滤波数学、定点运算、颜色状态、事务协议、元数据延迟、历史重建和生命周期行为。

本FIR只服务实时事件检测，不负责产生片外正式高精度PPG波形。系统固定分为：

```text
Stage1粗结果 -> DC恢复 -> 粗检测FIR -> 负斜率动态基线/向上相交/码值波峰/运行最小值/码值波谷经过确认

15-bit精细结果 -> DC恢复 -> 连续窗口记录 -> 片外精细滤波和精确峰值搜索
```

15-bit模式下仍持续产生Stage1粗结果，因此粗检测FIR在9-bit和15-bit模式中都连续工作。精细15-bit结果不得替换本模块输入。

## 2. 模块职责边界

`ppg_coarse_detection_fir`必须：

1. 接收DC恢复后的`signed 24-bit coarse_ppg_value`；
2. 对红光和红外分别维护21个同色有效样本；
3. 执行固定20阶、21抽头、名义10 Hz Hamming窗线性相位低通FIR；
4. 使用一个共享乘法器完成11次对称周期MAC，并在16个2 MHz周期内形成结果；
5. 输出与中心样本`x[n-10]`绑定的滤波值和事务元数据；
6. 在反压期间保持完整输出载荷；
7. 在实际AMB/DC周期重检接管时同时重建两色历史；
8. 给下游提供历史已满、窗口校准资格和窗口饱和诊断；
9. 独立消费明确invalid的NORMAL事务而不推进任一颜色历史、计数、MAC或检测控制。

本模块不得：

- 使用原始9-bit `detect_code`、`calibrated_s1_value`或15-bit精细结果替代粗DC恢复值；
- 解释心率、负斜率动态基线、向上相交、码值波峰、运行最小值或码值波谷经过事件；
- 修改IDAC码、控制LED、请求ADC转换或决定精度切换；
- 根据2 MHz空闲周期向历史插入0或复制样本；
- 因普通9/15-bit精度切换或NORMAL慢速DC调码清空历史。

## 3. 输入数据资格

### 3.1 数值输入

唯一滤波数值输入为：

```text
signed [23:0] i_coarse_ppg_value
```

该值已经由`ppg_adc_dc_recovery`完成：

- Stage1逐物理位校准；
- Stage1粗区间中心化；
- 9-bit统一标度换算；
- 当前颜色DC IDAC抵消量加回；
- Q17对称舍入和signed 24-bit显式饱和。

本模块不得再次执行Stage1 offset、中心补偿、DC恢复或物理单位换算。

### 3.2 允许进入历史的事务

只有完成输入握手且满足以下协议身份的事务才移动历史：

```text
i_result_valid == 1
i_coarse_valid == 1
i_sample_valid == 1
i_frame_type == NORMAL (2'b10)
i_color_ir == RED或IR
```

`AMB_CAL`和`DCS_CAL`不得连接到本模块输入。若非NORMAL事务到达，属于上游集成协议错误；RTL不得把它作为PPG样本移入历史，自检TB必须报告该错误。

`i_coarse_recovery_calibrated=0`或输入饱和不丢弃数值事务，仍按正常采样顺序移入历史，但会使覆盖它的21点窗口失去正式检测资格。这样既保留诊断连续性，也不会把未正式校准或饱和数据误认为可靠事件证据。

`i_sample_valid=0`具有不同语义：该位明确表示当前真实、身份匹配NORMAL事务不具备进入算法历史的样本资格。FIR仍须在`i_result_valid && o_result_ready`时原子消费该事务，使上游所有权可以释放，但不得移动RED/IR数值、资格、饱和或元数据历史，不得递增有效样本计数，不得启动MAC，也不得产生对应FIR输出。invalid事务造成的`sample_index`间隙是合法身份记录，不得用复制、插0或改写后续序号填补。

RAW为零、低/高数值、钳位、Stage1/DC饱和或`i_coarse_recovery_calibrated=0`均不自动令`i_sample_valid=0`。该位必须来自上游正式sample qualification边界，不能由FIR重新推导。

## 4. FIR数学合同

### 4.1 阶数、采样率和设计类型

FIR固定为20阶，即21抽头。每个颜色独立以400 Hz有效采样率工作，采用名义10 Hz Hamming窗低通设计。对每个颜色`c`定义：

```text
y_c[n] = round_away_from_zero(ACC_c[n] / 32768)

ACC_c[n] = sum(k=0..20, C[k] * x_c[n-k])
```

系数为固定signed 16-bit Q15整数：

```text
C[0:20] = [
     164,  231,  409,  704, 1100,
    1566, 2056, 2515, 2891, 3136,
    3224,
    3136, 2891, 2515, 2056, 1566,
    1100,  704,  409,  231,  164
]
```

系数严格满足：

```text
C[k] = C[20-k]
sum(C[0:20]) = 32768 = 2^15
```

因此定点直流增益严格为1。V2系数不可编程，不占用ACTIVE V4配置位，也不新增系数epoch。

### 4.2 对称周期MAC实现

RTL必须先形成10组signed 25-bit对称样本和一个中心样本：

```text
PAIR[0] = x[n]   + x[n-20]
PAIR[1] = x[n-1] + x[n-19]
PAIR[2] = x[n-2] + x[n-18]
PAIR[3] = x[n-3] + x[n-17]
PAIR[4] = x[n-4] + x[n-16]
PAIR[5] = x[n-5] + x[n-15]
PAIR[6] = x[n-6] + x[n-14]
PAIR[7] = x[n-7] + x[n-13]
PAIR[8] = x[n-8] + x[n-12]
PAIR[9] = x[n-9] + x[n-11]
CENTER  = x[n-10]
```

冻结累加数学为：

```text
ACC =
      PAIR[0] * 164
    + PAIR[1] * 231
    + PAIR[2] * 409
    + PAIR[3] * 704
    + PAIR[4] * 1100
    + PAIR[5] * 1566
    + PAIR[6] * 2056
    + PAIR[7] * 2515
    + PAIR[8] * 2891
    + PAIR[9] * 3136
    + CENTER  * 3224
```

实现必须使用一个共享乘法器，按11个MAC计算周期依次完成上述10个对称项和一个中心项。不得实例化11个并行通用乘法器，不得因周期复用改变数学求和、舍入、饱和或中心元数据语义。

### 4.3 频率特性

在每个颜色400 Hz有效采样率下，冻结系数具有：

| 项目 | 数值 |
| --- | ---: |
| 直流增益 | 1.0 |
| 5 Hz幅度 | 约-0.401 dB，不超过约0.5 dB |
| 10 Hz幅度 | 约-1.618 dB |
| -3 dB频率 | 约13.554 Hz |
| -6 dB频率 | 约18.976 Hz |
| 20 Hz幅度 | 约-6.697 dB，衰减不低于约6.5 dB |
| 50 Hz幅度 | 约-51.8 dB |
| 群延迟 | 10个同色有效样本，即25 ms |

该滤波器用于稳定下游对负斜率动态基线的码值向上相交、码值波峰、下降段、运行最小值以及“码值波谷已经经过”的实时判断。FIR自身不解释这些事件，不承诺片内精确峰谷幅值，也不取代片外对15-bit窗口的精细数字滤波。

## 5. 定点运算合同

### 5.1 内部位宽

| 中间量 | 位宽 | 说明 |
| --- | ---: | --- |
| 单个输入 | signed 24 | DC恢复后的统一PPG码 |
| 对称抽头和 | signed 25 | 两个signed 24-bit值相加 |
| Q15系数 | signed 16 | 固定非负整数系数，最大3224 |
| 单周期乘积 | signed 41 | signed 25-bit对称和乘signed 16-bit系数 |
| FIR累加器 | signed 42 | 精确覆盖全部11项周期累加和保护位 |
| 舍入工作量 | signed 43 | 覆盖最负累加值绝对值和16384半LSB加法 |
| 输出 | signed 24 | 与输入保持相同统一PPG标度 |

所有符号扩展、移位、加法、绝对值和常量位宽必须显式定义，不依赖Verilog表达式的隐式signed/unsigned提升。

### 5.2 舍入

42-bit Q15加权累加器除以32768时执行正负对称、恰好半LSB远离零舍入：

```text
if ACC >= 0:
    ROUNDED = (ACC + 16384) >>> 15
else:
    ROUNDED = -(((-ACC) + 16384) >>> 15)
```

不得对负数直接无条件加16384后算术右移，因为该写法不满足冻结的正负对称规则。

### 5.3 饱和

输出范围固定为：

```text
FIR_MIN = -8388608
FIR_MAX = +8388607
```

虽然全正、和为1的冻结系数在合法24-bit输入上理论上不会超出端点，RTL仍必须在舍入后执行显式24-bit饱和，不得依赖自然截断。输出提供互斥的`o_fir_saturation_low`和`o_fir_saturation_high`。

## 6. 红光与红外双历史

模块必须保存两套完全独立的状态：

```text
RED:  21点数值、21点资格、21点饱和诊断、21点中心元数据、有效样本计数
IR:   21点数值、21点资格、21点饱和诊断、21点中心元数据、有效样本计数
```

红光输入只移动红光历史，红外输入只移动红外历史。颜色交错、下游反压和精度模式变化不得使两色样本互相覆盖。

历史深度按“完成握手的同色NORMAL事务”计数，不按2 MHz时钟周期计数。两个同色样本之间存在任意数量空闲时钟时，历史和输出状态保持不变。

## 7. 历史预热和正式资格

### 7.1 有效样本计数

每个颜色维护0至21的5-bit饱和计数：

- 接收该颜色第一笔NORMAL样本后为1；
- 每接收一笔同色NORMAL样本加1；
- 到21后保持21；
- 另一颜色事务不改变本颜色计数；
- 只有第9节规定的历史重建事件把计数清零。

`o_history_full_r`和`o_history_full_ir`分别表示对应计数已经达到21。

### 7.2 第一笔样本初始化

历史重建后的第一笔同色NORMAL样本可以写入该颜色全部21个物理数据寄存器，以避免未初始化值扩散；但逻辑有效计数只能置1，不能把复制值解释为21笔真实样本。

随后每笔同色事务正常移位。只有累计21笔真实、按顺序接受的同色NORMAL事务后，才允许产生该颜色第一笔FIR输出。此时窗口严格为这21笔真实样本，初始复制值已经全部移出有效窗口。

### 7.3 窗口资格

每个输入样本的单点资格定义为：

```text
sample_qualified =
    i_sample_valid
    && i_coarse_recovery_calibrated
    && !i_stage1_saturation_low
    && !i_stage1_saturation_high
    && !i_coarse_saturation_low
    && !i_coarse_saturation_high
```

正式输出资格定义为：

```text
o_detection_qualified =
    selected_history_full
    && AND(all 21 sample_qualified bits)
```

窗口中任一未正式校准或饱和样本都会使`o_detection_qualified=0`，但模块仍可输出滤波数值和窗口诊断。该资格必须在生成输出时与完整载荷一起锁存，不得组合依赖后续变化的生命周期或重检输入。下游向上相交、码值波峰、运行最小值、码值波谷经过确认和精度切换事件模块必须只消费`o_detection_qualified=1`的事务。

窗口饱和诊断为21点对应标志的按位OR：

```text
o_window_saturation_low  = OR(all 21 low flags)
o_window_saturation_high = OR(all 21 high flags)
```

## 8. 中心样本和元数据

对当前接受的新样本`x[n]`产生的滤波结果，所有输出身份元数据必须绑定窗口中心样本`x[n-10]`，而不是最新样本`x[n]`或MAC完成时刻。

至少透传：

| 字段 | 默认位宽 | 输出语义 |
| --- | ---: | --- |
| `config_epoch` | 8 | 中心样本ACTIVE配置版本 |
| `coef_epoch` | 8 | 中心样本Stage1系数组版本 |
| `dc_recovery_coef_epoch` | 8 | 中心样本DC恢复系数组版本 |
| `precision_mode` | 1 | 中心样本采集时的9/15-bit模式 |
| `frame_id` | 16 | 中心样本帧号 |
| `sample_index` | 16 | 中心样本全局事务号 |
| `color_ir` | 1 | 当前独立历史所属颜色 |
| `frame_type` | 2 | 固定透传NORMAL编码`2'b10` |
| `amb_code_snapshot` | 8 | 中心样本AMB码快照 |
| `dc_code_snapshot` | 8 | 中心样本颜色DC码快照 |
| `amb_code_epoch` | 4 | 中心样本AMB码版本 |
| `dc_code_epoch` | 4 | 中心样本颜色DC码版本 |

9/15-bit精度模式允许在同一21点窗口内变化，因为两种模式都使用同一Stage1粗结果和同一粗DC恢复标度。输出`precision_mode`只描述中心样本，不改变滤波数学。

NORMAL慢速DC调码也允许使窗口包含不同`dc_code_epoch`。DC恢复模块必须先把各事务恢复到统一PPG标度；FIR不得因此清空历史或把不同epoch误认为重复样本。

## 9. 历史重建合同

### 9.1 必须重建的事件

以下任一事件必须同时使RED和IR历史、资格移位寄存器、元数据移位寄存器、有效计数和未输出结果失效：

1. `i_rstn=0`；
2. 新的合法`i_start_ack_event`；
3. `ppg_amb_recheck_scheduler.o_amb_recheck_accept`产生的`i_recheck_accept_event`；
4. PWI原样广播的带身份阻断终止事件`i_detection_discard_event`；
5. STOP使当前RUN结束。

周期重检成功和失败之后都从空历史恢复。失败数据可以进入CHARACTERIZATION诊断链，但在新的正式资格建立前不得产生正式检测事件。

### 9.2 禁止重建的事件

同一次正常RUN内，以下情况明确不得清空、重装或改变历史计数：

1. 9-bit切换到15-bit；
2. 15-bit切换到9-bit但没有周期重检实际接管；
3. AMB重检间隔仅到期并锁存pending，但尚未接管；
4. NORMAL期间DC_R或DC_IR慢速`+/-1 LSB`调码；
5. 红光和红外正常交错；
6. 输入valid空拍或下游ready反压；
7. 15-bit窗口开始或结束。

因此，只有“实际发生重检”才会在普通RUN过程中重建滤波器；不发生重检时，粗检测采样必须跨越所有普通精度切换连续运行。

### 9.3 重检期间

从`i_recheck_accept_event`到重检成功或失败结束：

- 不向FIR输入0；
- 不移动RED或IR历史；
- 不伪造NORMAL样本；
- 不产生正式滤波输出；
- 动态基线模块不因周期重检自动清零，但必须暂停使用FIR结果。

重检结束后，RED和IR分别从各自第一笔新NORMAL样本开始累计；每个颜色重新取得21笔真实样本后，才恢复该颜色正式检测资格。

## 10. ready/valid事务协议

### 10.1 输入和输出握手

```text
input_transfer  = i_result_valid && o_result_ready
output_transfer = o_result_valid && i_result_ready
```

V2使用单在途事务、单共享乘法器和单元素输出保持寄存器。输入ready冻结为：

```text
buffer_available = !o_result_valid || i_result_ready
o_result_ready =
    i_rstn
    && i_run_enable
    && !i_recheck_busy
    && !mac_busy
    && buffer_available
```

预热完成后，输入握手必须原子锁存当前21点计算窗口、中心元数据和全部窗口诊断；随后拉低`o_result_ready`并开始周期MAC。不得在计算过程中继续读取可能被后续事务改变的历史寄存器。

历史预热阶段不启动MAC。前20笔同色真实样本只更新状态，不产生`o_result_valid`；第21笔及其后的每笔同色输入各启动一次计算并最终产生一笔输出。

### 10.2 周期MAC时序

单笔正式计算至少包含：

```text
输入握手和计算上下文快照
-> 10个对称项乘累加周期
-> 1个中心项乘累加周期
-> 对称舍入、24-bit饱和和输出载荷提交
```

冻结外部时序约束为：

```text
C_FIR_PROCESS_MAX_CYCLES = 16
```

从一笔会产生输出的输入事务完成握手开始，到对应`o_result_valid`首次置1，不得超过16个2 MHz周期，即不得超过8 us。RTL内部状态数和提交拍位置可以在不改变握手语义的前提下实现，但不得超过该上限。

必须严格区分：

```text
FIR信号群延迟：10个同色有效样本 = 25 ms
周期MAC处理延迟：最多16个2 MHz周期 = 8 us
```

周期MAC延迟只推迟结果在数字逻辑中的可见时刻，不改变输出绑定的中心`frame_id/sample_index`，也不得被重复计入10样本群延迟。

### 10.3 反压

当`o_result_valid=1`且`i_result_ready=0`时：

- `o_filtered_ppg_value`、资格、窗口诊断和全部中心元数据逐拍保持；
- 不允许接受会覆盖该输出的新输入事务；
- RED和IR历史均不得移动；
- valid保持到唯一一次输出握手。

MAC忙期间`o_result_ready=0`，对红光和红外全部输入实施有界反压。上游若提出`i_result_valid=1`，必须保持该事务及全部载荷，直至FIR重新置`o_result_ready=1`并完成唯一一次握手。

允许在旧输出被消费的同一上升沿接受下一笔输入，但只有在MAC空闲且输出缓冲同拍可用时才允许该握手。V2不要求每时钟一笔的持续吞吐率。

正常PPG调度下，相邻ADC结果间隔远大于8 us，周期MAC通常在下一笔红光或红外结果到达前完成。ready/valid反压仍是强制协议保护，必须覆盖异常背靠背事务和上游缓冲集中释放场景。

### 10.4 重检接管与排空

`i_recheck_busy`只阻止新输入，不得组合撤销已经保持的`o_result_valid`或改变其资格和载荷。重检接管前必须先让旧输出按正常ready/valid完成消费。

`i_recheck_accept_event`只允许在本模块`o_fir_idle=1`时产生。`o_fir_idle`至少表示：

```text
MAC状态为空闲
不存在已经接受但尚未完成的计算事务
o_result_valid == 0
当前沿没有输入握手
```

历史寄存器非空不影响`o_fir_idle`；idle描述事务和计算排空，不表示21点历史为空。

顶层必须把`o_fir_idle`纳入AMB调度器的安全接管条件。不得在一个尚未完成握手的输出上撤销valid来强行开始重检。

`i_recheck_busy=1`期间`o_result_ready=0`，且上游调度必须保证DC恢复及其之前的测量流水已经排空，不再保持一笔等待FIR接收的NORMAL事务。重检结束本身不恢复历史资格，只解除输入禁止并进入第7节定义的21点预热。

### 10.5 固定计算上限与诊断边界

V2暂不新增`o_fir_protocol_error_sticky`端口。固定FSM必须通过RTL结构和自检证明所有正常计算均在16周期内完成。若实现保留内部保护计数，则超限时必须：

- 撤销当前MAC事务；
- 不提交部分累加结果；
- 清除内部busy并返回空闲；
- 不产生迟到`o_result_valid`。

内部保护行为不得改变本合同的外部端口集合；超限场景只作为TB故障注入和设计门禁，不作为NORMAL可恢复工作模式。

## 11. 模块端口合同

### 11.1 参数

```verilog
parameter integer C_FRAME_ID_WIDTH = 16
parameter integer C_SAMPLE_INDEX_WIDTH = 16
parameter integer C_IDAC_CODE_WIDTH = 8
parameter integer C_CODE_EPOCH_WIDTH = 4
parameter integer C_CONFIG_EPOCH_WIDTH = 8
parameter integer C_COEF_EPOCH_WIDTH = 8
parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 8
parameter integer C_RUN_GENERATION_WIDTH = 8
```

FIR数据位宽、抽头数量、系数、Q格式、右移位数和16周期处理上限在V2中固定，不作为外部可覆盖参数，避免产生未经合同验证的滤波器变体。

### 11.2 全局和生命周期输入

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_clk` | 1 | 2 MHz数字处理时钟 |
| input | `i_rstn` | 1 | 低有效异步复位，释放由顶层同步 |
| input | `i_run_enable` | 1 | 当前生命周期允许NORMAL算法事务 |
| input | `i_start_ack_event` | 1 | 新RUN开始，清空两色历史 |
| input | `i_recheck_accept_event` | 1 | AMB/DC周期重检实际安全接管事件 |
| input | `i_recheck_busy` | 1 | 接管等待和三帧重检期间禁止接收新的NORMAL输入；接管后不会产生新输出 |

`i_recheck_accept_event`连接`ppg_amb_recheck_scheduler.o_amb_recheck_accept`；`i_recheck_busy`连接其`o_amb_recheck_busy`，不能用仅表示间隔到期的`o_amb_recheck_pending`代替。

### 11.3 上游输入事务

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_result_valid` | 1 | DC恢复输出的保持型事务valid |
| output | `o_result_ready` | 1 | FIR允许接收新粗结果 |
| input | `i_coarse_ppg_value` | signed 24 | 唯一滤波数据输入 |
| input | `i_coarse_valid` | 1 | 当前事务具有粗数值 |
| input | `i_sample_valid` | 1 | 独立样本资格；0表示事务可被消费和记录，但禁止进入FIR历史及全部检测控制 |
| input | `i_coarse_recovery_calibrated` | 1 | Stage1和DC9恢复均具备正式资格 |
| input | `i_stage1_saturation_low/high` | 各1 | Stage1校准端点诊断 |
| input | `i_coarse_saturation_low/high` | 各1 | DC恢复24-bit端点诊断 |
| input | `i_config_epoch` | 8 | ACTIVE版本 |
| input | `i_coef_epoch` | 8 | Stage1系数组版本 |
| input | `i_dc_recovery_coef_epoch` | 8 | DC恢复系数组版本 |
| input | `i_precision_mode` | 1 | 本笔粗结果采集时的精度模式 |
| input | `i_frame_id` | 16 | R/IR配对帧号 |
| input | `i_sample_index` | 16 | 全局事务号 |
| input | `i_color_ir` | 1 | 0红光，1红外 |
| input | `i_frame_type` | 2 | 必须为NORMAL编码10 |
| input | `i_amb_code_snapshot` | 8 | 本笔AMB committed码 |
| input | `i_dc_code_snapshot` | 8 | 本笔当前颜色DC committed码 |
| input | `i_amb_code_epoch` | 4 | AMB码版本 |
| input | `i_dc_code_epoch` | 4 | 当前颜色DC码版本 |

### 11.4 下游输出事务

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_result_ready` | 1 | 下游允许消费当前FIR事务 |
| output | `o_result_valid` | 1 | 完整输出载荷保持有效 |
| output | `o_filtered_ppg_value` | signed 24 | 21抽头名义10 Hz低通结果 |
| output | `o_detection_qualified` | 1 | 全窗口可用于正式检测 |
| output | `o_window_saturation_low/high` | 各1 | 21点窗口饱和诊断OR |
| output | `o_fir_saturation_low/high` | 各1 | FIR输出显式端点诊断 |
| output | `o_history_full_r` | 1 | 红光已经积累至少21笔真实样本 |
| output | `o_history_full_ir` | 1 | 红外已经积累至少21笔真实样本 |
| output | `o_fir_idle` | 1 | MAC、在途事务、输出缓冲和当前输入沿均已排空 |

每笔输出还必须提供第8节全部中心样本元数据，端口使用对应`o_`前缀和参数化位宽。

### 11.1 V2.2 lifecycle and generation ports

FIR receives `i_detection_discard_event`,
`i_detection_discard_reason[1:0]`, `i_detection_discard_identity_valid`,
`i_detection_discard_sample_valid`, the trigger `TXN_ID` and
`i_run_generation[C_RUN_GENERATION_WIDTH-1:0]` from the PWI broadcast. The
event has no ready/acknowledgement. It is generation-scoped: FIR samples and
clears every input fork, MAC, output latch and pending detector handoff of the
event `run_generation` on that edge, including a legal scope-only event with
`identity_valid=0`. Its `o_local_empty` may be high only in the following cycle
after all local state is clear. No result, history advance or downstream event
may be produced for the discarded generation.

Every retained FIR transaction includes full ID and generation. A generation
mismatch is discarded without zero insertion, output, history/count/full/MAC
advance or algorithmic event. `i_sample_valid=0` has the same no-history
property but remains a real upstream accepted transaction with observable ID.

## 12. 精度模式连续性

粗检测链的数学输入始终是Stage1粗结果经9-bit粗DC恢复后的统一标度值，与当前事务是否同时具有15-bit精细结果无关。

因此：

- 进入15-bit模式时FIR继续接收每个颜色400 Hz粗结果；
- 15-bit模式期间历史不暂停、不清空；
- 粗链继续为下游提供连续数据，用于判断向上相交、码值波峰、下降段、运行最小值以及从最小值连续上升后的码值波谷经过；
- 从15-bit返回9-bit且没有实际AMB/DC重检时，FIR保持完全连续；
- 只有调度器真正接受周期重检时，才按第9节重建。

该行为是系统能够用粗链可靠决定15-bit退出时刻的必要条件。

## 13. 复位和STOP

### 13.1 异步复位

`i_rstn=0`时必须：

- 清除输出valid、资格、饱和标志和输出载荷；
- 立即撤销在途MAC、部分累加值、计算索引和冻结上下文；
- 清除两色21点历史、资格、诊断和元数据寄存器；
- 两色有效计数和history_full清零；
- `o_result_ready=0`；
- 不产生伪输出事务。

### 13.2 START和STOP

新的合法START只在前一generation已排空后重建历史，防止前一RUN的数据进入当前RUN。STOP、abort或system fault不直接进入FIR清除端口；它们由AMI形成带触发身份的generation-scoped discard并经PWI广播。FIR在接收该事件的采样沿停止接受新输入、撤销属于该`run_generation`的全部在途MAC和未消费输出并清除其局部历史；`identity_valid=0`的scope-only事件同样必须完成该清理。

若STOP必须打断下游长期反压，允许按系统生命周期合同丢弃尚未消费事务，但该行为必须由显式STOP事件触发，不能由普通模式变化或重检pending触发。

阻断终止同样只能通过PWI的`i_detection_discard_event`到达FIR；无论MAC正在处理第几个项，都在该事件采样沿撤销属于该`run_generation`的部分计算、输出valid和两色历史，撤销后不得产生属于旧代际的迟到输出。

## 14. 动态基线接口约束

动态基线及事件检测模块必须遵守：

1. 只在`o_result_valid && i_result_ready && o_detection_qualified`时更新正式状态；
2. 使用FIR输出携带的中心`frame_id/sample_index`标记事件位置；
3. 把10个同色样本群延迟纳入向上相交、码值波峰、运行最小值、码值波谷经过和精度窗口时序解释；
4. 重检和重新预热期间暂停使用FIR结果；
5. 周期重检本身不强制清除动态基线数值，但恢复后如何重新锁定由后续动态基线合同定义；
6. 不使用15-bit片段化数据替换本粗链连续状态。

## 15. ACTIVE配置和版本

V2 FIR无可编程系数、截止频率或抽头数量，因此：

- ACTIVE联合配置固定1024 bit；FIR不解包V4/V5，仅消费PWI具名的稳定数据和`config_epoch`端口。
- 不解释`reserved_extension_v4`；
- 不新增`fir_coef_epoch`；
- `config_epoch`、`coef_epoch`和`dc_recovery_coef_epoch`只作为中心样本元数据透传。

未来若需要可编程滤波器，必须发布新的ACTIVE schema和本合同新版本，完整冻结系数格式、稳定性、原子提交、epoch以及运行期历史处理，不得在V2保留位上静默扩展。

## 16. 自检验收矩阵

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| FIR-01 | 异步复位 | 撤销MAC，valid、计数、历史资格、诊断和载荷为冻结复位值 |
| FIR-02 | 单色前20笔 | 计数递增但不启动正式MAC、不产生输出 |
| FIR-03 | 单色第21笔 | 启动首次MAC并在16周期内产生输出，窗口只含21笔真实样本 |
| FIR-04 | 常量输入 | 预热后输出严格等于输入，证明直流增益为1 |
| FIR-05 | 单位冲激 | 依次得到冻结的21个Q15系数响应并正确舍入 |
| FIR-06 | 正负半LSB | 对称舍入且tie远离零 |
| FIR-07 | signed 24-bit端点 | 41-bit乘积和42-bit累加无回绕，输出符合显式饱和合同 |
| FIR-08 | R/IR交错 | 两套历史、计数、值和中心元数据互不污染 |
| FIR-09 | 中心元数据 | 输出身份严格来自`x[n-10]`，不是最新输入或MAC提交时刻 |
| FIR-10 | 9/15-bit交错 | 历史连续，系数和输出数学不随精度变化 |
| FIR-11 | 15到9无重检 | 不清空历史，不重新预热 |
| FIR-12 | recheck pending等待 | 仅pending不改变任一历史状态 |
| FIR-13 | recheck accept | 两色历史同时失效，停止正式输出 |
| FIR-14 | 三帧重检活动 | 不移位、不插0、不产生正式FIR事务 |
| FIR-15 | 重检后恢复 | 两色分别重新累计21笔真实NORMAL样本 |
| FIR-16 | NORMAL慢速DC调码 | dc_code_epoch可变化，但历史和计数保持连续 |
| FIR-17 | 未校准样本 | 数值移位，覆盖该样本的窗口资格为0 |
| FIR-18 | 上游饱和样本 | 数值不丢弃，窗口饱和OR和检测资格正确 |
| FIR-19 | 非NORMAL输入 | 不移动历史，TB报告集成协议错误 |
| FIR-20 | 下游反压 | 输出值、资格、诊断和全部元数据逐拍稳定 |
| FIR-21 | MAC有界反压 | busy期间ready为0，输入载荷保持，恢复后只消费一次 |
| FIR-22 | 11次周期MAC | 10个对称项和中心项按冻结系数逐项累加且只使用一个乘法器 |
| FIR-23 | 16周期上限 | 每笔正式计算在输入握手后最多16周期产生valid |
| FIR-24 | `o_fir_idle`定义 | MAC、在途计算、输出和当前输入沿任一未排空时idle必须为0 |
| FIR-25 | START/STOP/abort | 任一MAC阶段被撤销后均不产生迟到输出 |
| FIR-26 | recheck接管排空 | 只有`o_fir_idle=1`时允许accept，不撤销受阻输出valid |
| FIR-27 | 两色极值随机回归 | 宽位黄金模型逐笔一致，无隐式符号截断 |
| FIR-28 | 频率响应 | Q15定点模型满足5、10、20和50 Hz冻结幅频门限 |
| FIR-29 | 中心精度历史 | 精度切换后的10样本固定群延时只改变中心元数据可见时刻，不清历史 |
| FIR-30 | 计算保护注入 | 超限故障注入撤销部分结果并返回空闲，不新增sticky端口 |
| FIR-31 | 独立invalid事务 | `i_result_valid=1`且`i_sample_valid=0`的合法NORMAL事务只消费一次；两色历史、计数、history_full、MAC、输出valid和全部检测状态保持 |
| FIR-32 | 资格正交性 | RAW零/低/高值、未校准和饱和样本在`i_sample_valid=1`时仍按V2规则移入历史；任何calibration-valid或饱和组合不得冒充invalid |
| FIR-33 | invalid后恢复 | invalid事务不插0、不复制、不占历史位置；后续合法同色样本按真实握手继续累计，达到21笔合法历史前不产生新的合格检测事件，身份序号保持原始间隙 |

自检TB必须使用独立宽位整数黄金模型，至少覆盖常量、21点冲激、正负斜坡、随机极值、颜色交错、精度交错、资格窗口、元数据中心延迟、周期MAC状态、反压、16周期上限、频率响应和生命周期打断。所有PASS必须来自真实结果比较，不得只检查仿真是否结束。

## 17. RTL实现门禁

后续实现必须满足：

- 可综合Verilog-2001；
- Erie strict双语文件头、ANSI端口、命名、Tab缩进、区域和中文实体注释；
- 低有效异步复位，复位释放由顶层同步；
- 时序逻辑使用非阻塞赋值，组合逻辑完整赋值；
- 输出使用内部`*_o`桥接；
- 每个`always`块只有一个主要目标；
- 不使用RTL `function`、`task`、`initial`、延时或系统任务；
- 不使用原始门控时钟或锁存器；
- formatter-AST严格门禁零错误、零strict warning；
- 独立静态lint、自检TB、Vivado xvlog/xelab/xsim和综合全部通过；
- xsim中FIR-01至FIR-33全部来自真实端口和状态比较；
- 综合报告无锁存器、组合环、多驱动、黑盒和不可解释位宽截断。

## 18. V2.1冻结结论

V2.1正式冻结为：

- 每个颜色400 Hz、20阶21抽头、名义10 Hz Hamming窗线性相位低通FIR；
- 固定signed 16-bit Q15对称系数，整数和严格为32768；
- 约13.554 Hz的-3 dB频率、10 Hz约-1.618 dB、20 Hz约-6.697 dB和10样本群延迟；
- DC恢复后的signed 24-bit粗结果作为唯一数据输入；
- 9-bit和15-bit模式共用连续Stage1粗检测链；
- 红光和红外各自保存21点历史；
- signed 41-bit乘积、signed 42-bit累加、signed 43-bit舍入工作量、半LSB远离零和24-bit显式饱和；
- 输出元数据绑定中心样本`x[n-10]`；
- 单乘法器完成11次周期MAC，单笔正式计算最大16个2 MHz周期；
- MAC busy期间对全部输入实施有界ready/valid反压；
- `o_fir_idle`同时检查MAC、在途事务、输出缓冲和当前输入沿；
- 未校准或饱和样本保留数值但使覆盖窗口失去正式检测资格；
- 独立`i_sample_valid=0`事务只完成上游握手，不进入历史、不递增计数、不启动MAC或下游检测；
- invalid资格不由RAW数值、饱和或calibration-valid推导，正常生产事务由上游明确提供`i_sample_valid=1`；
- 实际AMB/DC重检接管时同时重建两色历史，重检期间不插0、不移位；
- 重检后每个颜色重新收集21笔真实NORMAL样本；
- 普通精度切换、recheck pending等待和NORMAL慢速DC调码均不得清空历史；
- 暂不增加FIR协议错误sticky端口；
- ACTIVE V4保持640 bit不变；V5检测字段由联合ACTIVE经AMI->PWI提供，FIR不得读取原始payload、V4保留位或产生默认配置。

任何改变抽头、系数、输入标度、舍入、饱和、中心元数据、历史重建条件、ready/valid延迟、sample-valid或检测资格语义的实现，都必须先修订本合同，再修改RTL和自检TB。

当前RTL/TB只具备V2的FIR-01至FIR-30历史证据。~~新增`i_sample_valid`端口及FIR-31至FIR-33尚未实现和运行~~ **2026-09-13勘误（Stage 3 Item 3 合同文字滞后扫描发现）：`i_sample_valid`端口本身早已实现（`ppg_coarse_detection_fir.v` V2.1新增端口、V2.2补齐`flag_sample_qualified`显式引用，2026-08-22/23），并非"尚未实现"；真正仍然缺失的是FIR-31至FIR-36专属验收TB证据——直接检查`tb_ppg_coarse_detection_fir.v`（970行）确认其中不含任何`i_sample_valid`引用，未见针对该端口的定向回归**，因此实现证据为`EVIDENCE_PENDING`，不得宣称PASS，也不得用层次化force、特殊RAW、`i_coarse_valid`或`i_coarse_recovery_calibrated`替代该公开资格接口。

V2.6订正（F-015）：上段2026-09-13勘误所述“TB不含`i_sample_valid`引用”已过时。`tb_ppg_coarse_detection_fir.v`自2026-09-16 V2.1起经公开端口驱动`i_sample_valid`，并有FIR-31、FIR-32、FIR-33定向检查（PASS判据103行含这三项）。验收表只定义到FIR-33，所谓FIR-34~36不存在。当前证据状态见别名表与矩阵§13（ID=FIR-01～FIR-33）。
