# PPG动态基线斜率与向上相交接口合同

> V2.6 fail-closed V5-gate revision, 2026-08-20: detection-discard remains the sole STOP/abort/system-fault lifecycle clear path; `i_peak_valley_config_valid` is a registered PWI input that gates formal cross state. System closure is `NOT_CLOSED` until the matrix audit records zero defects. Implementation evidence is `EVIDENCE_PENDING`.

> 历史版本记录（非规范）：V1/V2/V2.1/V2.2的冻结日期分别为2026-08-10/2026-08-12/2026-08-12/2026-08-12；当前唯一规范版本为页眉声明的V2.6。  
> 目标RTL：`ppg_dynamic_baseline_cross_detector.v`  
> 时钟域：2 MHz数字处理域  
> 上游：`ppg_coarse_detection_fir`经无丢失检测事务fork  
> 事件协作者：`ppg_peak_valley_window_detector`  
> 配置基线：联合ACTIVE固定1024 bit；V4保持640 bit子载荷不变，本文逻辑字段来自V5 `[1023:640]`并仅经AMI->PWI具名输入到达本模块。

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C18 | `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.1 | Sole PWI parent, V5 forwarding and discard broadcast boundary. |
| C19 | `ppg_system_integration/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md` | V2.5 | Sole qualified FIR transaction source. |
| C21 | `ppg_system_integration/PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md` | V1.2 | Normative arithmetic sub-rule for this module only. |

V2.1相对V2属于不增加端口的小版本修订，新增冻结内容为：

- `i_precision_mode`从中心样本身份字段升级为向上相交资格字段；
- 只有中心精度为9-bit的正式RED NORMAL FIR样本可以武装、建立、延续或完成相交候选；
- 15-bit返回9-bit后的旧15-bit中心尾部可以被正常消费，但不得产生新的9-bit到15-bit请求；
- 任一旧15-bit中心样本必须切断相交连续证据，禁止与后续新9-bit中心样本跨精度拼接；
- 重检恢复的未知时刻相交请求同样只允许由中心精度为9-bit的恢复样本建立。

V2.2相对V2.1属于增加一个控制端口的小版本修订，新增冻结内容为：

- 增加`i_reacquire_request_event`，唯一连接精度窗口控制器的异常返回重新获取事件；
- `FINE_WINDOW_TIMEOUT`、`PROTOCOL_FALLBACK`或保留原因归一化回退在真实返回9-bit后，通过本事件废止旧基线；
- 事件清除旧锚点、旧峰谷周期、相交候选、已保持cross和lead统计，撤销在途斜率算术；
- 事件保留`slope_current_q16`数值作为新锚点的启动参考，但清除自适应资格和旧基础斜率诊断；
- 普通`VALLEY_CONFIRMED`返回和成功AMB/DC重检不得伪造本事件。

## 1. 合同目的

本文冻结原始PPG码值方向下的动态基线数学模型、逐周期自适应负斜率、向上相交确认、
FIR群延时对齐、15-bit提前窗口、异常返回重新获取、AMB/DC重检恢复、ready/valid所有权、定点格式、
诊断状态和验证用例。

后续RTL、自检TB、精度窗口控制器和ACTIVE配置扩展必须以本文为直接接口真源。任何改变斜率符号、
周期索引、相交方向、中心`frame_id`解释、异常重新获取、重检时间连续性或配置原子性的实现，都必须先
发布本文新版本。

## 2. 系统极性与功能边界

### 2.1 冻结的原始PPG码值方向

本系统的统一PPG码值与光电二极管接收光强正相关，因此正常窗口控制顺序固定为：

```text
9-bit粗链等待负斜率动态基线的向上相交
-> 下一400 Hz安全帧进入15-bit
-> Stage1粗链确认码值波峰
-> 跟踪下降段和运行最小值
-> 从最小值连续上升后确认码值波谷已经经过
-> 下一安全帧返回9-bit
```

本文中的“波峰”始终表示原始码值波峰，不表示生理血容量PPG正峰。本文中的“波谷”始终表示原始码值
运行最小值附近的码值波谷。

### 2.2 本模块必须负责

`ppg_dynamic_baseline_cross_detector`必须：

1. 接收RED/IR粗FIR事务，消费但忽略IR事务，只有RED事务拥有精度窗口控制权；
2. 保存最近一个可靠RED码值波峰锚点、锚点中心帧号和当前活动负斜率；
3. 按中心`frame_id`计算与FIR输出时间对齐的动态基线；
4. 仅使用中心精度为9-bit的正式检测样本执行“先到基线下方、再连续3点向上越过”的相交确认；
5. 保持相交事件及其首次越过中心元数据，直到精度控制器完成ready/valid消费；
6. 根据一个完整周期的峰谷幅度、峰峰帧距和相交提前量计算下一周期斜率；
7. 在AMB/DC重检期间暂停相交和自适应统计，但让基线数学时间按全局`frame_id`连续推进；
8. 对无相交、跨重检相交未知、配置错误、帧序异常和恢复失败提供可见诊断；
9. 接收精度控制器在异常返回9-bit后产生的明确重新获取事件，废止旧基线并等待新波峰；
10. 在任何普通9/15-bit切换、IR事务或下游反压情况下保持已冻结状态语义。

### 2.3 本模块不得负责

本模块不得：

- 使用15-bit可编程重构结果替换Stage1粗检测FIR输入；
- 自行解释生理收缩期峰或输出片内精细峰值；
- 生成或调整AMB/DC IDAC码；
- 自行清空或预热FIR历史；
- 用2 MHz时钟周期数或FIR输出笔数替代400 Hz中心`frame_id`时间；
- 在当前周期中途把下一周期斜率切换为活动斜率；
- 在RUN期间直接接受SPI异步覆盖ACTIVE配置；
- 在重检/FIR预热空窗内伪造精确相交帧号；
- 把IR样本计入RED连续确认、周期长度或相交状态。
- 让中心精度为15-bit的FIR历史尾部武装、建立、延续或完成新的向上相交请求。
- 使用START、STOP、abort、sticky边沿或AMB重检事件冒充异常返回重新获取事件。

## 3. 检测事务分发前提

粗FIR输出同时被动态基线模块和后续峰谷窗口检测器观察。顶层必须使用无丢失双输出保持型fork：

```text
ppg_coarse_detection_fir
    -> detection_transaction_fork
        -> dynamic_baseline_cross_detector
        -> peak_valley_window_detector
```

同一FIR事务在每个分支只能消费一次。不得把`valid`无状态复制到两个独立`ready`消费者，也不得让任一
分支因当前模式不使用该事务而长期反压；不使用的IR或非活动精度事务必须被接收并按合同忽略。

## 4. 固定宽度、编码和默认值

### 4.1 参数

| 参数 | 默认值 | 语义 |
| --- | ---: | --- |
| `C_FRAME_ID_WIDTH` | 16 | 全局400 Hz帧号宽度 |
| `C_SAMPLE_INDEX_WIDTH` | 16 | 全局ADC事务序号宽度 |
| `C_CONFIG_EPOCH_WIDTH` | 8 | ACTIVE配置版本宽度 |
| `C_COEF_EPOCH_WIDTH` | 8 | Stage1系数组版本宽度 |
| `C_DC_RECOVERY_EPOCH_WIDTH` | 8 | DC恢复系数组版本宽度 |
| `C_RUN_GENERATION_WIDTH` | 8 | manager唯一生产并由PWI透传的RUN代际位宽 |
| `C_SLOPE_WIDTH` | 32 | signed Q16斜率字段宽度 |
| `C_BASELINE_WIDTH` | 48 | signed Q16内部基线工作宽度 |
| `C_RATIO_WIDTH` | 16 | unsigned Q1.15比例字段宽度 |
| `C_CROSS_CONFIRM_DEFAULT` | 3 | 包含首次越过样本的连续确认点数 |
| `C_LEAD_MIN_DEFAULT` | 17 | 合格提前窗口下界，42.5 ms |
| `C_LEAD_MAX_DEFAULT` | 19 | 合格提前窗口上界，47.5 ms |
| `C_NO_CROSS_LIMIT_DEFAULT` | 2 | 连续无相交后重新获取的周期数 |

决定运行行为的数值不得作为无法由ACTIVE观察的隐藏参数。表中默认值用于复位诊断和配置模板，
NORMAL_PPG启动仍必须使用配置管理器已校验的ACTIVE字段。

### 4.2 斜率模式

```text
1'b0 = FIXED_SPI
1'b1 = ADAPTIVE
```

`FIXED_SPI`使用ACTIVE提供的固定负斜率。`ADAPTIVE`在第一个完整合格周期之前也使用该固定负斜率作为
启动种子；获得完整周期后才允许逐周期更新。

### 4.3 冻结默认比例

| 字段 | 默认实数 | unsigned Q1.15编码 | 语义 |
| --- | ---: | ---: | --- |
| `alpha` | 0.20 | `16'h199A` | 上一周期峰谷幅度用于基础斜率的比例 |
| `beta` | 0.25 | `16'h2000` | 当前斜率向新基础斜率移动的平滑比例 |
| `timing_adjust_ratio` | 0.0625 | `16'h0800` | 相交过早/过晚的单周期相对修正比例 |

论文中的20%只支持“信号幅度用于初始斜率尺度”的思路；本文把它中心化为峰谷有效幅度并除以实际
上一周期帧数。`beta`和`timing_adjust_ratio`属于本项目的硬件闭环参数，不得宣称为论文原值。

## 5. 周期索引和冻结数学定义

### 5.1 周期事件

对RED粗滤波链定义：

```text
P[n]      = 第n个可靠码值波峰值
V[n]      = 第n个可靠码值波谷值
C[n]      = 从P[n]开始的周期内首次正式向上相交值
F_P[n]    = P[n]对应的中心frame_id
F_V[n]    = V[n]对应的中心frame_id
F_C[n]    = C[n]首次越过对应的中心frame_id
S[n]      = 从P[n]到P[n+1]期间使用的活动负斜率
```

第`n`周期内所有基线比较只使用`S[n]`。`S[n+1]`只能在`P[n+1]`确认、周期`n`数据完整后计算，
并从以`P[n+1]`为锚点的新周期开始生效。

### 5.2 帧差

16-bit帧差采用无符号模减：

```text
frame_delta(a, b) = (a - b) mod 2^16
```

所有正式周期、提前量和超时必须严格小于`2^15`帧。若差值最高位表示跨度达到或超过半个回绕周期，
该周期无资格且置位帧序诊断，禁止用于自适应更新。

### 5.3 动态基线

对中心帧`f`：

```text
B[f] = P[n] + DELTA + S[n] * frame_delta(f, F_P[n])
```

冻结符号为：

```text
S[n] < 0
DELTA为signed Q16起点偏置
DELTA默认0，表示基线严格经过码值波峰
```

不得同时采用“signed负斜率”与`-S*frame_delta`，否则会形成双重负号并使基线向上。

### 5.4 FIR时间对齐

粗FIR群延时固定为10个同色有效样本。模块必须使用FIR事务携带的中心`frame_id=f`计算`B[f]`，并执行：

```text
filtered_ppg_value[f] 与 B[f] 比较
```

不得使用FIR结果实际到达2 MHz逻辑的墙钟帧号计算基线。FIR群延时只延迟事件可见时间，不能改变事件
对应的数学帧位置。FIR内部最多16个2 MHz处理周期属于同一400 Hz帧内的微周期计算，不得再折算成
额外400 Hz帧延时。

## 6. 自适应斜率计算

### 6.1 完整周期观测量

在`P[n+1]`确认后计算：

```text
A[n] = P[n] - V[n]
T[n] = frame_delta(F_P[n+1], F_P[n])
L[n] = frame_delta(F_P[n+1], F_C[n])
```

合法极性要求`A[n] > 0`。`T[n]`必须非零且小于半回绕周期。`L[n]`只有在本周期存在已确认、时间已知
的向上相交时才有效。

### 6.2 基础斜率

```text
S_BASE_Q16[n+1] =
    -round((A[n] * ALPHA_Q15 * 2^16) / (T[n] * 2^15))

等价化简：
S_BASE_Q16[n+1] =
    -round((A[n] * ALPHA_Q15 * 2) / T[n])
```

`A[n]`是整数码，`ALPHA_Q15`含15个小数位，输出`S_BASE_Q16`必须含16个小数位，因此必须显式补足
一个二进制小数位。不得遗漏该缩放后把Q15结果误标成Q16。变量除法只在每个可靠波峰事件后执行一次；
允许使用顺序除法器或经验证的倒数乘法，不允许在每个400 Hz样本上推导通用大组合除法器。

### 6.3 平滑候选

```text
S_SMOOTH[n+1] =
    S[n]
  + round(BETA_Q15 * (S_BASE[n+1] - S[n]) / 2^15)
```

这里`S[n]`是当前周期活动斜率，不是`S_BASE`。`S_SMOOTH[n+1]`只是下一周期候选，不得在当前周期
中途覆盖活动寄存器。

### 6.4 相交时间修正步长

```text
ADJUST_STEP[n+1] =
    max(1 Q16 LSB,
        round(abs(S_BASE[n+1]) * TIMING_ADJUST_RATIO_Q15 / 2^15))
```

若`S_BASE[n+1]`因周期不完整而无效，使用`abs(S[n])`作为比例基数。默认比例为1/16，即6.25%。

### 6.5 17至19帧合格窗口

```text
L[n] < LEAD_MIN:
    TIMING_TERM[n+1] = -ADJUST_STEP[n+1]

LEAD_MIN <= L[n] <= LEAD_MAX:
    TIMING_TERM[n+1] = 0

L[n] > LEAD_MAX:
    TIMING_TERM[n+1] = +ADJUST_STEP[n+1]
```

默认`LEAD_MIN=17`、`LEAD_MAX=19`。17帧下界由以下时序预算组成：

```text
10帧FIR群延时
+ (3点确认 - 1) = 2帧附加确认延时
+ 1帧下一安全边界模式切换
+ 4帧波峰前15-bit保护样本
= 17帧
```

17帧是安全下界，不得通过对称负向死区把合格范围扩展到17以下。这里的10帧FIR群延时只描述事件
可见延迟；比较和相交事件仍绑定FIR中心样本的实际`frame_id`，不得再额外减去或补加10帧。

### 6.6 最终斜率和提交

```text
S_CANDIDATE[n+1] = S_SMOOTH[n+1] + TIMING_TERM[n+1]

S[n+1] = clamp(S_CANDIDATE[n+1], SLOPE_MIN, SLOPE_MAX)
```

冻结边界关系：

```text
SLOPE_MIN < SLOPE_MAX < 0
```

若候选触及边界，仍允许作为下一周期斜率使用，但必须输出对应低/高限幅诊断。本模块只在新可靠波峰
建立下一周期锚点时把`slope_next`提交为新的活动`S[n+1]`。

## 7. 向上相交确认

### 7.1 正式状态更新条件

以下输入传输定义为正式RED NORMAL结果，可用于维持中心时间、基线计算和非相交诊断：

```text
input_transfer
&& i_detection_qualified
&& i_color_ir == 0
&& i_frame_type == NORMAL
&& i_window_saturation_low == 0
&& i_window_saturation_high == 0
&& i_fir_saturation_low == 0
&& i_fir_saturation_high == 0
```

其中只有进一步满足以下条件的结果才具有新相交资格：

```text
cross_eligible_red_result =
    formal_red_normal_result
 && i_fine_window_active == 0
 && i_precision_mode == 0
 && i_peak_valley_config_valid == 1
```

`i_fine_window_active`描述当前真实模拟采集窗口，`i_precision_mode`描述该笔FIR输出中心样本的历史采集精度。
两者不能互相替代。真实模拟精度已经返回9-bit时，FIR仍可能输出最多10笔中心精度为15-bit的历史尾部；
这些事务可以被消费并用于维持全局中心时间和非相交诊断，但不得成为新的9-bit相交证据。

IR事务必须被消费但不得改变任何RED基线、连续计数或周期统计。未正式资格的RED事务不得形成事件证据；
若其发生在候选连续确认期间，必须取消该候选并重新等待基线下方资格。

中心精度为15-bit的正式RED事务必须执行以下相交状态处理：

```text
below_seen            = 0
cross_candidate       = 0
cross_confirm_count   = 0
previous_9bit_valid   = 0
```

该处理只切断新相交证据，不清除波峰锚点、活动斜率、基线资格、峰谷周期统计或已保持的`o_cross_valid`。
下一笔中心精度为9-bit的正式RED事务只能重新建立9-bit相邻样本上下文，并可按其相对基线位置重新武装；
不得与退出尾部中的最后一笔15-bit中心样本拼接成一次跨精度穿越。

### 7.2 重新武装

新锚点建立或重检恢复后，先清除`below_seen`。只有观察到：

```text
Y[f] <= B[f] - CROSS_HYSTERESIS
```

才置位`below_seen=1`。置位动作还必须满足`cross_eligible_red_result=1`。这保证波峰附近建立基线时不会
立即把相等、微小噪声或旧15-bit中心尾部解释为新的9-bit向上相交。

### 7.3 候选和连续3点确认

在`below_seen=1`且当前结果满足`cross_eligible_red_result=1`时，首次满足：

```text
Y[f-1] <= B[f-1] - CROSS_HYSTERESIS
Y[f]   >= B[f]   + CROSS_HYSTERESIS
```

时建立候选并保存`F_C_candidate=f`及其完整中心元数据。前一相邻样本和当前样本都必须是中心精度为9-bit
的正式RED NORMAL结果。随后要求总计3个连续、正式、同色且中心精度为9-bit的RED样本位于正迟滞边界
上方；首次越过样本计为第1点，因此附加确认延时为2帧。

候选期间若消费任一中心精度为15-bit的RED事务，必须立即取消候选、清零确认计数并使9-bit相邻上下文
失效。后续新9-bit样本不得继承旧候选或旧15-bit样本的方向关系。

确认完成后输出的`cross_frame_id`必须是`F_C_candidate`，不得替换为第3点确认帧号。相交输出在一个
锚点周期内最多产生一次，直到下一个可靠波峰建立新周期才重新允许。

### 7.4 精度窗口请求

相交事件使用保持型ready/valid接口。事件完成握手后，精度控制器只允许在下一400 Hz安全帧进入15-bit，
不得修改已经开始或已经完成的当前ADC转换。

`i_fine_window_active=1`时本模块继续接收FIR事务和峰/谷事件，但不得产生新的相交请求。15-bit期间确认的
Stage1粗码值波峰仍可建立下一周期锚点并提交下一周期斜率。

15-bit返回9-bit后，`i_fine_window_active`会按真实模拟精度提交立即清零，而`i_precision_mode`仍可能因
21抽头FIR固定群延时在最多10笔同色RED NORMAL中心事务中保持为1。该退出尾部只能维持粗链连续性，
不得武装`below_seen`、建立或确认候选、产生已知/未知时刻相交事件，亦不得消耗当前锚点周期的一次请求
配额。只有中心精度重新成为9-bit后，才能从新的9-bit相邻样本上下文开始下一次相交判断。

## 8. 无相交和周期恢复

若在`P[n+1]`确认时周期`n`没有正式相交：

```text
TIMING_TERM[n+1] = -ADJUST_STEP[n+1]
```

即下一周期斜率比平滑候选更负一个修正步长，以降低基线并促使相交提前。每个无相交周期使
`no_cross_count`加1；有正式相交时清零。

默认连续两个完整周期无相交时：

```text
baseline_valid = 0
adaptive_slope_valid = 0
进入波峰锚点重新获取
```

旧基线不得无限延伸。重新获取阶段保持9-bit，不产生正式fine请求；获得可靠波峰后使用ACTIVE固定斜率
重新建立基线，完成一个新的完整周期后恢复自适应更新。

## 9. 启动、STOP和故障

### 9.1 新RUN启动

新`START_ACK`后：

```text
baseline_valid = 0
adaptive_slope_valid = 0
slope_current = fixed_slope
清除峰、谷、相交和周期计数
```

Stage1粗链在9-bit下重新获取第一个可靠码值波峰。获得锚点后使用固定斜率建立第一条基线；第一个完整
合格周期结束后才允许置位`adaptive_slope_valid`。

### 9.2 检测生命周期discard

AMI对STOP、abort或system fault形成带触发身份的generation-scoped detection discard，并由PWI原样广播。事件的
`run_generation`与本模块当前状态相同则在接收沿丢弃该代际全部未消费相交事件、全部运行状态和算术暂存，返回无有效基线；它不是直接STOP/abort清除端口。`identity_valid=0`的scope-only flush同样必须清理当前代际。普通下游反压、普通9/15-bit
切换和IR事务不得触发该清理。

### 9.3 固定斜率回退

以下任一情况使自适应结果失效并退回ACTIVE固定斜率：

- AMB/DC重检失败；
- FIR恢复后正式结果饱和或DC恢复资格无效；
- 波峰重新获取失败；
- 帧差达到或超过半回绕周期；
- 合法性检查发现`A<=0`、`T==0`或斜率配置非法；
- 当前generation的`DISCARD_ABORT`或`DISCARD_SYSTEM_FAULT`生命周期discard。

退回固定斜率不等于立即产生有效基线；仍须重新获得可靠波峰锚点。

### 9.4 精度窗口异常返回重新获取

精度窗口控制器是唯一同时知道返回原因和真实9-bit提交时刻的模块。以下返回原因完成真实15-bit到9-bit
提交后，控制器必须在下一2 MHz周期产生一次：

```text
i_reacquire_request_event = 1
```

适用原因固定为：

```text
FINE_WINDOW_TIMEOUT
PROTOCOL_FALLBACK
RESERVED归一化后的PROTOCOL_FALLBACK
```

正常`VALLEY_CONFIRMED`返回不得产生该事件。该事件也不得由仅有AMB重检pending、普通精度切换、START、
STOP、abort或sticky诊断变化产生。

事件到达时应已经满足：

```text
i_run_enable == 1
i_fine_window_active == 0
活动committed精度已经为9-bit
```

若集成错误使事件在正式fine窗口仍活动时到达，本模块仍执行安全重新获取清理并置
`o_protocol_error_sticky`，不得继续使用旧基线产生请求。

`i_reacquire_request_event`到达沿必须原子完成：

```text
baseline_valid            = 0
adaptive_slope_valid      = 0
reacquire_active          = 1
no_cross_count            = 0
last_lead_frames          = 0
slope_base_q16            = 0

清除旧peak_anchor及全部epoch
清除旧valley上下文和周期峰谷资格
清除已知/未知相交候选、连续确认和相邻样本上下文
清除cross_time_unknown恢复等待和当前周期相交资格
撤销尚未完成的多周期斜率计算及波峰快照
撤销尚未被精度控制器消费的旧o_cross_valid及其载荷资格
```

同时必须：

```text
slope_current_q16保持原数值
```

该保留值只作为新可靠波峰到达时的启动参考，不再具有旧锚点上的数学基线资格，也不得宣称
`adaptive_slope_valid=1`。新波峰完成握手后，用保留的活动斜率建立新基线；若保留值因协议错误超出当前
合法边界，则按既有固定斜率回退规则装载`i_fixed_slope_q16`。

从事件到新可靠波峰建立期间：

- 保持9-bit工作；
- 消费但不使用IR和无资格FIR事务；
- 不产生新cross；
- 峰谷检测器通过`o_reacquire_active`进入9-bit波峰搜索；
- 新波峰的真实`frame_id/sample_index/epoch`成为下一条基线唯一锚点。

该路径与第10节AMB/DC重检严格区分：异常返回重新获取总是废止旧锚点；成功AMB/DC重检仍保留可靠锚点
和活动斜率。

## 10. AMB/DC重检和FIR恢复

### 10.1 成功重检必须保留的状态

周期重检被安排在上一15-bit窗口结束并返回9-bit之后。成功重检不强制牺牲下一个完整心搏周期，因此
接管时保留：

```text
peak_anchor_value
peak_anchor_frame_id
slope_current
baseline_valid
```

同时清除：

```text
cross_candidate
cross_confirm_count
below_seen
本周期自适应更新资格
```

跨重检周期仍可继续使用保留基线完成后续相交和15-bit请求，但该周期不得用于更新`S_BASE`、`beta`平滑
或`lead_actual`闭环。

### 10.2 基线时间不得暂停

全局400 Hz `frame_id`在9-bit、15-bit、三帧AMB/DC重检和FIR重新预热期间都必须持续递增。重检期间没有
正式FIR输出不表示基线时间停止。

FIR恢复后第一个正式中心样本`f_resume`必须使用：

```text
B[f_resume] =
    peak_anchor
  + DELTA
  + slope_current * frame_delta(f_resume, peak_anchor_frame_id)
```

该`frame_delta`必须包含重检帧和FIR预热经过的全部真实400 Hz帧。

### 10.3 恢复后重新锁定

若第一个或后续中心精度为9-bit的正式恢复样本重新满足：

```text
Y[f] <= B[f] - CROSS_HYSTERESIS
```

则重新置位`below_seen`并按正常规则等待向上相交。

若第一个中心精度为9-bit的正式恢复样本已经位于正迟滞边界上方，说明相交可能发生在无正式FIR输出的
空窗内。此时：

```text
产生保持型fine请求
cross_time_unknown = 1
不得伪造cross_frame_id
本周期不得计算lead_actual或更新自适应斜率
```

事件可携带恢复后第一个正式中心`frame_id`作为“发现时刻”，但必须同时置位`cross_time_unknown`，下游和
片外不得把该字段解释为真实穿越时刻。

若恢复后首先到达的是中心精度为15-bit的历史样本，则只能消费并等待，不得据此产生
`cross_time_unknown=1`事件。未知时刻请求必须等待第一笔中心精度为9-bit且满足正迟滞条件的正式恢复样本。

## 11. 配置合同

### 11.1 逻辑配置字段

| 字段 | 位宽/格式 | 冻结语义 |
| --- | --- | --- |
| `slope_mode` | 1 | FIXED_SPI或ADAPTIVE |
| `fixed_slope_q16` | signed 32 Q16 | 启动、恢复和固定模式负斜率 |
| `alpha_q15` | unsigned 16 Q1.15 | 默认0.20 |
| `beta_q15` | unsigned 16 Q1.15 | 默认0.25 |
| `timing_adjust_ratio_q15` | unsigned 16 Q1.15 | 默认1/16 |
| `slope_min_q16` | signed 32 Q16 | 最负允许斜率 |
| `slope_max_q16` | signed 32 Q16 | 最接近零允许斜率 |
| `baseline_delta_q16` | signed 32 Q16 | 起点偏置，默认0 |
| `cross_hysteresis_q16` | unsigned 32 Q16 | 正负对称相交迟滞 |
| `lead_min_frames` | unsigned 16 | 默认17 |
| `lead_max_frames` | unsigned 16 | 默认19 |
| `cross_confirm_count` | unsigned 4 | 默认3，首次越过计第1点 |
| `no_cross_limit` | unsigned 4 | 默认2 |

### 11.2 NORMAL合法性

NORMAL_PPG配置至少要求：

```text
fixed_slope_q16 < 0
slope_min_q16 < slope_max_q16 < 0
slope_min_q16 <= fixed_slope_q16 <= slope_max_q16
alpha_q15 != 0
beta_q15 != 0
timing_adjust_ratio_q15 != 0
lead_min_frames <= lead_max_frames
lead_min_frames >= cross_confirm_count + 14
cross_confirm_count >= 2
no_cross_limit >= 1
```

`cross_confirm_count + 14`来自冻结安全预算：10帧FIR群延时、`N-1`帧确认附加延时、1帧模式切换和
4帧波峰前保护，即`10 + (N-1) + 1 + 4 = N + 14`。默认`N=3`时下界恰好为17帧。

CHARACTERIZATION可在显式诊断资格下扫描更宽参数，但任何非法符号、反转限幅关系或零确认次数仍必须拒绝。

### 11.3 ACTIVE版本

ACTIVE V4总宽度为640 bit，`[639:592]`仍是必须为0的48-bit保留区。本文全部配置字段不得静默解释
V4保留位。现行配置管理器、ACTIVE解包器和1024-bit联合位图已通过独立V5 `[1023:640]`统一扩展；本模块只能消费PWI具名端口，不得读取原始payload。
本文逻辑字段。

RUN期间上述字段全部冻结。片外参数扫描必须采用：

```text
STOP -> CONFIG写SHADOW -> COMMIT -> START -> 记录 -> STOP
```

不得在同一NORMAL RUN中直接覆盖ACTIVE参数。

## 12. 定点运算合同

### 12.1 数值格式

| 数值 | 格式 | 说明 |
| --- | --- | --- |
| FIR输入`Y` | signed 24整数 | 统一PPG码 |
| `P/V/A`工作量 | signed 25整数 | 覆盖24-bit端点差值 |
| `S/S_BASE/S_SMOOTH` | signed 32 Q16 | 码/400 Hz帧 |
| `DELTA/HYSTERESIS` | Q16 | 与统一PPG码对齐 |
| 比例字段 | unsigned 16 Q1.15 | `alpha/beta/adjust_ratio` |
| 基线和乘积 | signed 48 Q16 | 覆盖32-bit斜率乘16-bit帧差 |

### 12.2 舍入

比例乘法和变量除法必须使用正负对称、恰好半LSB远离零舍入。不得依赖Verilog隐式signed转换、自然截断
或对负数无条件加半LSB后算术右移。

### 12.3 比较

FIR整数值比较前显式转换为Q16：

```text
Y_Q16 = sign_extend(Y) <<< 16
```

基线、迟滞和FIR值全部在扩展Q16工作宽度中比较，不得先把基线截断为24-bit整数后再判断相交。

### 12.4 饱和

斜率按配置上下限显式饱和。用于诊断输出的基线值若超出signed 24-bit统一PPG范围，应输出端点值并置位
`baseline_saturation_low/high`；内部48-bit基线工作量不得自然回绕。

## 13. ready/valid接口合同

### 13.1 FIR事务输入

```text
input_transfer = i_result_valid && o_result_ready
```

本模块应能在2 MHz域持续接收400 Hz事务。除复位、当前generation的detection-discard清理和显式重检禁止窗口外，不得因当前
颜色、精度模式或未使用事务而长期撤销`o_result_ready`。

### 13.2 峰谷事件输入

峰值和波谷事件必须使用独立保持型ready/valid接口，至少携带：

```text
event_value
event_frame_id
event_sample_index
config_epoch
coef_epoch
dc_recovery_coef_epoch
```

事件源必须保持valid和全部载荷直到握手。动态基线模块不得组合采样未握手脉冲。峰值事件建立新锚点；
波谷事件只为当前周期幅度统计提供资格，不直接产生fine请求。

### 13.3 相交事件输出

相交事件输出至少携带：

```text
cross_frame_id
cross_sample_index
cross_time_unknown
config_epoch
coef_epoch
dc_recovery_coef_epoch
slope_current_q16
baseline_at_cross_q16
```

`o_cross_valid=1 && i_cross_ready=0`时，valid和全部载荷逐拍保持。已经保持的事件不得因fine模式开始、
重检pending或新FIR事务而撤销。

## 14. 逐端口逻辑合同

### 14.1 生命周期和控制输入

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_clk` | 1 | 2 MHz数字处理时钟 |
| `i_rstn` | 1 | 低有效异步复位 |
| `i_run_enable` | 1 | RUN允许检测 |
| `i_start_ack_event` | 1 | 新RUN状态清理和固定斜率装载 |
| `i_fine_window_active` | 1 | 当前精度窗口已经进入15-bit |
| `i_reacquire_request_event` | 1 | 精度控制器在异常返回9-bit后要求废止旧基线并重新获取的单拍 |
| `i_recheck_accept_event` | 1 | 重检实际安全接管 |
| `i_recheck_busy` | 1 | 重检和测量禁止窗口 |
| `i_recheck_done_event` | 1 | 重检序列结束 |
| `i_recheck_success` | 1 | 与done同拍的成功资格 |
| `i_peak_valley_config_valid` | 1 | AMI经PWI注册转发的V5正式检测资格；为0时仅允许安全消费/排空，不得推进或发布正式cross状态 |

### 14.2 FIR事务输入

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_result_valid` | 1 | fork分支保持的FIR事务valid |
| `o_result_ready` | 1 | 本模块允许消费事务 |
| `i_filtered_ppg_value` | signed 24 | 粗FIR统一PPG码 |
| `i_detection_qualified` | 1 | FIR完整窗口正式资格 |
| `i_window_saturation_low/high` | 各1 | 输入窗口端点诊断 |
| `i_fir_saturation_low/high` | 各1 | FIR输出端点诊断 |
| `i_config_epoch` | 8 | 中心ACTIVE版本 |
| `i_coef_epoch` | 8 | 中心Stage1系数版本 |
| `i_dc_recovery_coef_epoch` | 8 | 中心DC恢复版本 |
| `i_precision_mode` | 1 | FIR中心样本历史采集精度；0才具有新相交资格，1只允许维持非相交粗链状态 |
| `i_frame_id` | 16 | 中心400 Hz帧号 |
| `i_sample_index` | 16 | 中心事务序号 |
| `i_color_ir` | 1 | 0 RED、1 IR |
| `i_frame_type` | 2 | 固定NORMAL编码`2'b10` |

### 14.3 峰谷事件输入

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_peak_valid` / `o_peak_ready` | 各1 | 可靠码值波峰事件握手 |
| `i_peak_value` | signed 24 | Stage1粗FIR码值波峰 |
| `i_peak_frame_id` | 16 | 波峰实际中心帧 |
| `i_peak_sample_index` | 16 | 波峰中心事务号 |
| `i_peak_config_epoch` | 8 | 波峰ACTIVE版本 |
| `i_peak_coef_epoch` | 8 | 波峰Stage1系数版本 |
| `i_peak_dc_recovery_coef_epoch` | 8 | 波峰DC恢复版本 |
| `i_valley_valid` / `o_valley_ready` | 各1 | 可靠码值波谷事件握手 |
| `i_valley_value` | signed 24 | Stage1粗FIR码值波谷 |
| `i_valley_frame_id` | 16 | 波谷实际中心帧 |
| `i_valley_sample_index` | 16 | 波谷中心事务号 |

谷事件的三个epoch必须与峰事件同样透传，RTL端口不得为节省接口而省略。

### 14.4 ACTIVE逻辑配置输入

| 端口 | 位宽/格式 |
| --- | --- |
| `i_slope_mode` | 1 |
| `i_fixed_slope_q16` | signed 32 Q16 |
| `i_alpha_q15` | unsigned 16 Q1.15 |
| `i_beta_q15` | unsigned 16 Q1.15 |
| `i_timing_adjust_ratio_q15` | unsigned 16 Q1.15 |
| `i_slope_min_q16` | signed 32 Q16 |
| `i_slope_max_q16` | signed 32 Q16 |
| `i_baseline_delta_q16` | signed 32 Q16 |
| `i_cross_hysteresis_q16` | unsigned 32 Q16 |
| `i_lead_min_frames` | 16 |
| `i_lead_max_frames` | 16 |
| `i_cross_confirm_count` | 4 |
| `i_no_cross_limit` | 4 |

`i_peak_valley_config_valid` is a registered 2 MHz input from PWI. It is not
derived locally and is stable with the committed `i_config_epoch`. When it is
zero, this detector must still consume and drain held transactions, but it
must not arm `below_seen`, advance cross-confirmation, publish `o_cross_valid`,
or update formal cross-related state. Held inputs remain subject to the normal
ready/valid transfer rule.

### 14.5 相交和状态输出

| 端口 | 位宽/格式 | 语义 |
| --- | --- | --- |
| `o_cross_valid` / `i_cross_ready` | 各1 | 保持型相交事件握手 |
| `o_cross_frame_id` | 16 | 首次越过中心帧或未知事件发现帧 |
| `o_cross_sample_index` | 16 | 对应中心事务号 |
| `o_cross_time_unknown` | 1 | 重检空窗可能已相交 |
| `o_cross_config_epoch` | 8 | 事件ACTIVE版本 |
| `o_cross_coef_epoch` | 8 | 事件Stage1系数版本 |
| `o_cross_dc_recovery_coef_epoch` | 8 | 事件DC恢复版本 |
| `o_cross_slope_q16` | signed 32 Q16 | 本次相交使用的活动斜率 |
| `o_cross_baseline_q16` | signed 48 Q16 | 本次比较基线 |
| `o_baseline_valid` | 1 | 当前锚点和斜率可用于比较 |
| `o_adaptive_slope_valid` | 1 | 已获得完整周期并启用自适应 |
| `o_slope_current_q16` | signed 32 Q16 | 当前周期活动斜率 |
| `o_slope_base_q16` | signed 32 Q16 | 最近基础斜率 |
| `o_last_lead_frames` | 16 | 最近时间已知相交提前量 |
| `o_no_cross_count` | 4 | 连续无相交周期计数 |
| `o_reacquire_active` | 1 | 正在重新获取波峰锚点 |
| `o_slope_saturation_min/max` | 各1 | 最近更新触及斜率边界 |
| `o_baseline_saturation_low/high` | 各1 | 诊断基线超出24-bit端点 |
| `o_protocol_error_sticky` | 1 | 帧序、事件顺序或配置协议错误 |

`i_reacquire_request_event`固定连接：

```text
ppg_precision_window_controller.o_reacquire_request_event
-> ppg_dynamic_baseline_cross_detector.i_reacquire_request_event
```

该输入不是ready/valid事务，不允许反压或延迟；控制器必须仅在真实9-bit提交后的冻结单拍产生它。

### 14.1 V2.3 detection lifecycle ports

The detector receives PWI's registered 2 MHz
`i_detection_discard_event/reason/identity_valid/sample_valid/TXN_ID` and `i_run_generation`. It has no discard
ready. On the event edge it clears arithmetic staging, cycle counters, pending
cross candidate and output-valid state for the event generation, without changing unrelated
committed configuration. A legal scope-only flush has `identity_valid=0` and
must perform the same current-generation clear. `o_local_empty` can assert only from the next cycle.
It emits no cross for the discarded or stale generation. A following qualified
sample begins normal post-discard history; it is not compared against a
synthetic zero. `i_sample_valid=0` is not a numeric sample and cannot advance
cycle evidence or slope state.

## 15. Epoch和周期资格

用于同一次自适应更新的`P[n]`、`V[n]`、`C[n]`和`P[n+1]`必须具有一致的：

```text
config_epoch
coef_epoch
dc_recovery_coef_epoch
```

NORMAL慢速DC调码允许`dc_code_epoch`变化，因为DC恢复已经把每笔事务恢复到统一PPG标度；该字段不作为
本文周期一致性拒绝条件。若调码仍造成饱和或资格丢失，FIR会使相关事务无正式检测资格，从而阻止该周期
进入自适应更新。

跨AMB/DC重检周期无论epoch是否相同，都必须标记为自适应统计不完整；它可在成功重检后继续使用保留
锚点完成fine请求，但不得更新下一周期斜率。

## 16. 片外表征和只读诊断

`alpha`、`beta`、`timing_adjust_ratio`、迟滞、斜率边界和固定斜率由片外通过多次
`CONFIG/COMMIT/RUN`扫描。片内不自动遍历参数。

片外至少应能读取：

```text
slope_current
slope_base
last_peak/valley/cross frame_id
last_period_frames
last_lead_frames
baseline_valid
adaptive_slope_valid
cross_time_unknown
no_cross_count
slope/baseline饱和和协议错误
config_epoch
```

上述状态读回位图属于后续SPI状态合同，不授权在RUN中反向写入内部活动状态。

## 17. 自检TB冻结矩阵

| 编号 | 场景 | 必须结果 |
| --- | --- | --- |
| BSL-01 | 复位和新START | 固定斜率装载，基线无效，状态清零 |
| BSL-02 | 第一个可靠波峰 | 建立锚点和固定斜率基线，不提前宣称自适应有效 |
| BSL-03 | signed负斜率 | frame增加时基线单调不升，不出现双重负号 |
| BSL-04 | FIR中心帧对齐 | 使用中心frame_id而非结果到达帧计算基线 |
| BSL-05 | 三点确认 | 首次越过计第1点，第3点确认，输出首次越过frame_id |
| BSL-06 | 候选中资格丢失 | 取消候选，重新等待基线下方 |
| BSL-07 | 相交事件反压 | valid和全部载荷保持，事件不重复消费 |
| BSL-08 | `lead<17` | timing term为负，下一周期斜率更负 |
| BSL-09 | `17<=lead<=19` | timing term为0 |
| BSL-10 | `lead>19` | timing term为正，下一周期斜率不那么负 |
| BSL-11 | `alpha=0.20` | 基础斜率计算和对称舍入正确 |
| BSL-12 | `beta=0.25` | 当前斜率向基础斜率移动25% |
| BSL-13 | 调整比例1/16 | adjust step等于基础斜率绝对值的6.25% |
| BSL-14 | 斜率限幅 | 候选被显式夹紧并输出边界诊断 |
| BSL-15 | 单周期无相交 | 下一周期增加一个负向修正步长 |
| BSL-16 | 连续两周期无相交 | 基线失效并进入重新获取 |
| BSL-17 | 普通9/15-bit切换 | 不清除锚点、斜率或周期状态 |
| BSL-18 | IR事务 | 被消费且完全不改变RED状态 |
| BSL-19 | 重检成功 | 保留锚点/斜率，清除临时候选，暂停自适应周期资格 |
| BSL-20 | 重检和预热时间 | 恢复基线frame_delta包含全部真实帧 |
| BSL-21 | 恢复后位于基线下方 | 重新武装并正常等待相交 |
| BSL-22 | 恢复首样本已在基线上方 | fine请求、time_unknown置位、不伪造精确相交 |
| BSL-23 | 重检失败 | 锚点失效、退回固定斜率和重新获取 |
| BSL-24 | FIR/DC恢复无资格或饱和 | 不形成正式事件，不更新自适应斜率 |
| BSL-25 | frame_id回绕 | 合法短跨度模减正确，半回绕异常被拒绝 |
| BSL-26 | epoch不一致 | 周期更新无资格，旧活动斜率保持 |
| BSL-27 | ACTIVE配置非法 | NORMAL启动被配置管理器拒绝 |
| BSL-28 | detection discard | STOP/abort/system-fault通过当前generation的带身份或scope-only discard清理在途事件和运行状态 |
| BSL-29 | 退出15-bit历史尾部 | `i_fine_window_active=0`但`i_precision_mode=1`时正常消费样本，不武装、不建立或输出新cross |
| BSL-30 | 跨精度候选切断 | 9-bit候选期间到达15-bit中心样本时取消候选、清零确认并使9-bit相邻上下文失效 |
| BSL-31 | 返回9-bit重新建链 | 尾部结束后的第一笔9-bit样本只重新建立相邻上下文，后续全9-bit序列才能正常形成cross |
| BSL-32 | 恢复未知相交精度资格 | 15-bit恢复尾部不得产生time_unknown请求，第一笔合格9-bit恢复样本才允许产生 |
| BSL-33 | 异常返回重新获取 | 事件废止旧锚点和基线，置reacquire，保留当前斜率数值但清除自适应资格 |
| BSL-34 | 正常波谷返回 | 不产生reacquire事件时保持旧锚点、斜率和正常周期连续性 |
| BSL-35 | 重新获取时旧cross反压 | 事件原子撤销尚未消费的旧cross，之后不得迟到握手或复活 |
| BSL-36 | 重新获取时算术busy | 任一乘法、除法、平滑或等待波峰提交阶段均立即撤销，不提交旧锚点或部分斜率 |
| BSL-37 | 重新获取后新波峰 | 新波峰使用真实中心元数据重建基线，并以保留活动斜率作为启动参考 |
| BSL-38 | 重新获取与重检相邻 | 先执行异常重获清理；后续recheck accept不得恢复已废止旧锚点，成功结束后仍等待新波峰 |
| BSL-39 | 非法fine期间重获事件 | 安全废止旧基线并置协议sticky，不允许旧fine上下文继续产生cross |
| BSL-40 | V5正式检测门控 | `i_peak_valley_config_valid=0`时仍握手并排空输入，但不武装、确认或发布正式cross；合法COMMIT后的高电平才允许新的9-bit正式cross证据。 |

## 18. 综合和实现约束

- RTL必须为可综合Verilog-2001；
- 不得使用real、短实数或仿真专用延时实现定点算法；
- 不得生成门控时钟，所有状态使用2 MHz时钟使能；
- 变量除法只在逐周期更新路径执行，允许多周期FSM，但必须在下一笔需要新斜率的可靠RED事务前完成；
- 输入和事件ready/valid不得形成跨模块组合环；
- 所有输出保持寄存器必须在低有效复位、STOP和abort路径完整初始化；
- 每个顺序过程的状态所有权必须唯一，避免同一寄存器被多个`always`块驱动；
- 斜率、帧差、绝对值和乘法必须显式扩展位宽，禁止依赖隐式signed/unsigned提升。

## 19. 冻结结论

V2.6当前冻结结论（纳入已保留的V2.2规则）：

1. 动态基线使用`B=P+DELTA+S*frame_delta`，其中`S<0`、`DELTA`默认0；
2. 当前周期使用`S[n]`，下一周期斜率只能由完整周期`n`的数据生成；
3. `alpha=0.20`、`beta=0.25`、相对调整比例1/16是可配置默认值；
4. 相交提前量17至19帧合格，低于17使下一斜率更负，高于19使其不那么负；
5. 连续3点确认包含首次越过点，输出首次越过中心`frame_id`；
6. FIR群延时、重检和预热不改变数学时间，基线始终按全局中心`frame_id`计算；
7. 成功重检保留锚点和斜率，失败或恢复异常才退回固定斜率和重新获取；
8. 跨重检空窗相交时间未知时立即请求fine但不伪造相交帧，也不更新自适应斜率；
9. ACTIVE V4保持不变，新增逻辑配置必须通过现行V5 `[1023:640]`合同映射；
10. 只有中心精度为9-bit的正式RED NORMAL FIR样本具有新相交资格；真实窗口状态与中心历史精度必须同时合格；
11. 退出尾部中的旧15-bit中心样本必须切断候选和相邻证据，不得与新9-bit样本拼接或产生已知/未知相交请求；
12. 新增单拍`i_reacquire_request_event`，唯一连接精度控制器异常返回重新获取输出；
13. 事件废止旧锚点、周期证据、相交输出和在途算术，置重新获取并保留当前活动斜率数值作为启动参考；
14. 正常波谷返回和成功AMB/DC重检不产生该事件，二者继续保持已冻结的周期连续性；
15. ACTIVE配置位图保持不变，RTL及TB必须覆盖第17节BSL-01至BSL-40全部冻结用例。
