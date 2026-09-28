# PPG动态基线算术优化合同

> Current normative version: V1.2, 2026-08-20. Status: `ACTIVE_NORMATIVE` arithmetic sub-rule; system closure is `NOT_CLOSED` until the current matrix audit records zero defects. RTL/TB evidence is `EVIDENCE_PENDING`.
> 目标RTL：`ppg_dynamic_baseline_cross_detector.v`  
> 目标TB：`tb_ppg_dynamic_baseline_cross_detector.v`  
> 上位合同：`PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md`  
> 优化范围：精确位宽收缩、顺序除法器、周期级乘法器复用  
> 时钟域：2 MHz数字处理域  
> 外部接口版本：保持现有动态基线模块端口不变；STOP/abort只经父模块的带ID detection-discard进入内部算术取消路径。

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C20 | `ppg_system_integration/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md` | V2.6 | Parent interface, lifecycle and external arithmetic semantics. |

## 1. 合同目的

本文冻结`ppg_dynamic_baseline_cross_detector`逐周期自适应斜率路径的算术优化方法，使优化后的RTL在降低
组合除法面积、宽乘法器数量和无效翻转功耗的同时，保持原合同的数学公式、舍入、饱和、周期索引、
ready/valid所有权、波峰锚点语义和异常恢复行为。

本文是上位动态基线合同的规范性补充。若两份合同发生冲突：

- 动态基线数学、PPG极性、相交方向、中心`frame_id`和系统生命周期以上位合同为准；
- 本文冻结的中间位宽、多周期算术时序、有界反压、原子提交和异常撤销行为为优化实现真源；
- 任何改变外部端口、ACTIVE字段、数学公式或400 Hz事务语义的后续方案，必须先发布新合同版本。

## 2. 优化目标与非目标

### 2.1 必须实现的优化

正式优化RTL必须依次实现：

1. 把明显超出数学范围的64-bit和80-bit周期更新中间量收缩到已证明的安全宽度；
2. 把`A * alpha / T`中的变量组合除法替换为精确多周期顺序除法器；
3. 复用一个周期级乘法器，依次计算`A * alpha`、`difference * beta`和`abs(S_BASE) * adjust_ratio`；
4. 保留当前逐样本动态基线乘法`S * frame_delta`的独立实现；
5. 让周期算术引擎只在完整自适应周期闭合时活动，其余时间保持空闲。

### 2.2 不得改变的功能

优化不得改变：

- `B = P + DELTA + S * frame_delta`动态基线公式；
- `S_BASE`、`S_SMOOTH`、`ADJUST_STEP`和`S_CANDIDATE`数学定义；
- signed负斜率方向和12至14帧lead闭环方向；
- FIR中心`frame_id`作为数学时间的解释；
- BSL-01至BSL-28的系统级期望结果；
- 相交输出保持型ready/valid行为；
- 普通9/15-bit切换、IR隔离和AMB/DC重检语义；
- ACTIVE配置字段、Q格式和默认参数；
- `i_precision_mode`与`i_fine_window_active`的既有身份和控制职责。

### 2.3 本轮不优化的路径

本轮不得把以下逐样本路径接入共享乘法器：

```text
slope_current_q16 * frame_delta
```

该乘法属于400 Hz正式FIR事务的实时基线计算路径。把它与周期更新引擎复用会引入样本调度、重检恢复、
帧跳跃和相交比较延迟的新耦合，必须由独立合同评估后才能实施。

## 3. 优化前后的功能等价边界

### 3.1 事务级等价

对任一合法完整周期，优化前后必须产生逐位相同的：

```text
o_slope_base_q16
o_slope_current_q16
o_last_lead_frames
o_slope_saturation_min
o_slope_saturation_max
o_adaptive_slope_valid
o_no_cross_count
o_baseline_valid
```

优化允许改变2 MHz内部计算周期数和输入ready的短暂拉低时刻，但不得改变正式握手后对外可见的数学结果、
中心`frame_id`、周期归属或状态所有权。

### 3.2 原子提交

新周期的以下状态必须在同一个2 MHz时钟沿提交：

```text
新波峰锚点及其全部epoch
新活动斜率S[n+1]
最近基础斜率S_BASE[n+1]
最近有效lead
斜率上下限诊断
无相交计数更新
周期候选和旧波谷清理
自适应斜率有效资格
```

不得出现：

```text
新波峰锚点 + 旧活动斜率
旧波峰锚点 + 新活动斜率
新斜率 + 旧限幅诊断
新锚点已经提交但旧周期波谷仍有效
```

### 3.3 数学时间不随运算延迟移动

多周期算术延迟使用2 MHz墙钟周期计数，只决定结果何时可提交，不改变波峰真实中心时间：

```text
peak_anchor_frame_id = 待处理波峰事件携带的i_peak_frame_id
```

算术完成后，后续样本仍使用：

```text
frame_delta = current_center_frame_id - peak_anchor_frame_id
```

不得把算术完成时刻或`cnt_arithmetic_cycle`加入400 Hz基线时间。

## 4. 冻结数学公式

### 4.1 周期观测量

```text
A[n] = P[n] - V[n]
T[n] = frame_delta(F_P[n+1], F_P[n])
L[n] = frame_delta(F_P[n+1], F_C[n])
```

合法周期要求：

```text
A[n] > 0
0 < T[n] < 2^(C_FRAME_ID_WIDTH-1)
P/V/C/P_NEXT的config_epoch一致
P/V/C/P_NEXT的coef_epoch一致
P/V/C/P_NEXT的dc_recovery_coef_epoch一致
周期未跨AMB/DC重检禁止窗口
```

### 4.2 基础斜率

```text
BASE_NUMERATOR = A[n] * ALPHA_Q15 * 2
BASE_ROUNDED_NUMERATOR = BASE_NUMERATOR + floor(T[n] / 2)
BASE_MAGNITUDE = BASE_ROUNDED_NUMERATOR / T[n]
S_BASE_WIDE = -BASE_MAGNITUDE
S_BASE = saturate_to_supported_signed_32_q16(S_BASE_WIDE)
```

该实现必须与上位合同的：

```text
S_BASE_Q16[n+1] = -round((A[n] * ALPHA_Q15 * 2) / T[n])
```

逐位一致。分子为正、分母为正，因此先加`floor(T/2)`再执行无符号整数除法是冻结的最近舍入实现。

### 4.3 beta平滑

```text
SMOOTH_DIFFERENCE = S_BASE - S_CURRENT
SMOOTH_PRODUCT = SMOOTH_DIFFERENCE * BETA_Q15
SMOOTH_DELTA = symmetric_round(SMOOTH_PRODUCT / 2^15)
S_SMOOTH = S_CURRENT + SMOOTH_DELTA
```

负乘积必须先取绝对值、加`2^14`、右移15位，再恢复符号。不得直接对负数无条件加`2^14`后算术右移。

### 4.4 相交时刻修正

```text
ADJUST_PRODUCT = abs(S_BASE) * TIMING_ADJUST_RATIO_Q15
ADJUST_ROUNDED = round(ADJUST_PRODUCT / 2^15)
ADJUST_STEP = max(1, ADJUST_ROUNDED)
```

```text
没有时间已知正式相交： TIMING_TERM = -ADJUST_STEP
L < LEAD_MIN：          TIMING_TERM = -ADJUST_STEP
LEAD_MIN <= L <= LEAD_MAX：TIMING_TERM = 0
L > LEAD_MAX：          TIMING_TERM = +ADJUST_STEP
```

### 4.5 最终候选和饱和

```text
S_CANDIDATE = S_CURRENT + SMOOTH_DELTA + TIMING_TERM
S_NEXT = clamp(S_CANDIDATE, SLOPE_MIN, SLOPE_MAX)
```

必须先在扩展宽度中完成全部加法和比较，再截取或写入signed 32-bit Q16寄存器。禁止先截断再判断限幅。

## 5. 精确位宽合同

### 5.1 输入和正式输出宽度保持不变

| 数值 | 冻结格式 | 说明 |
| --- | --- | --- |
| `P/V` | signed 24-bit整数 | Stage1粗FIR统一PPG码 |
| `S_CURRENT/S_BASE/S_NEXT` | signed 32-bit Q16 | 正式斜率字段 |
| `alpha/beta/adjust_ratio` | unsigned 16-bit Q1.15 | ACTIVE比例字段 |
| `T/L/frame_delta` | unsigned 16-bit | 400 Hz中心帧差 |
| 内部动态基线 | signed 48-bit Q16 | 保留原逐样本基线工作宽度 |

### 5.2 周期更新中间宽度

| 中间量 | 冻结宽度 | signed属性 | 设计依据 |
| --- | ---: | --- | --- |
| `cycle_amplitude` | 25 | signed | 覆盖两个signed 24-bit端点差 |
| `base_numerator` | 42 | unsigned | 24-bit正幅度乘16-bit比例并左移1位，含保护位 |
| `base_rounded_numerator` | 42 | unsigned | 分子加16-bit半分母后不溢出 |
| `base_quotient` | 42 | unsigned | 在`T=1`时保留完整商，饱和前不得截断 |
| `slope_base_wide` | 43 | signed | 覆盖42-bit正商取负 |
| `smooth_difference` | 33 | signed | 两个signed 32-bit斜率相减 |
| `shared_product` | 50 | signed | 最大操作为33-bit signed乘17-bit正signed扩展 |
| `smooth_product_abs` | 50 | unsigned | 覆盖signed乘积绝对值 |
| `smooth_delta` | 34 | signed | 50-bit乘积舍入并右移15位后的安全结果 |
| `base_abs` | 32 | unsigned | 覆盖正式signed 32-bit负斜率绝对值 |
| `adjust_product` | 48 | unsigned | 32-bit正幅值乘16-bit比例并保留保护位 |
| `adjust_step` | 33 | signed | 覆盖右移后的正调整量及符号应用 |
| `timing_term` | 33 | signed | 覆盖正负调整步长 |
| `slope_candidate` | 35 | signed | 覆盖活动斜率、平滑量和时刻修正之和 |

表中宽度是正式实现宽度下限与保护位组合。实现不得通过更窄的自然截断获得相同端口宽度。若参数化实现
需要更宽的局部工作量，可以保留额外保护位，但不得恢复无依据的通用64/80-bit宽度并宣称已完成优化。

### 5.3 signed转换规则

共享乘法器统一按signed `33 x 17`实现，各操作的输入扩展固定为：

```text
MUL_ALPHA:
    operand_a = zero_extend(cycle_amplitude_positive, 33)
    operand_b = zero_extend(alpha_q15, 17)

MUL_BETA:
    operand_a = sign_extend(smooth_difference, 33)
    operand_b = zero_extend(beta_q15, 17)

MUL_ADJUST:
    operand_a = zero_extend(base_abs, 33)
    operand_b = zero_extend(timing_adjust_ratio_q15, 17)
```

所有补零、符号扩展和乘法输入signed解释必须在RTL中显式写出，不得依赖表达式上下文自动推断。

### 5.4 绝对值边界

正式`slope_base`不得采用`-2^31`作为有效自适应值。基础斜率宽结果超过可表示范围时，先夹紧到：

```text
-2^31 + 1
```

再执行绝对值。这样：

```text
abs(slope_base) <= 2^31 - 1
```

不得对signed最小值直接使用二进制取负后截断。

## 6. 周期级共享算术引擎

### 6.1 状态机

正式实现采用三段式FSM，状态至少包括：

```text
ST_IDLE
ST_CAPTURE
ST_MUL_ALPHA
ST_PREPARE_DIVIDE
ST_DIVIDE
ST_BUILD_SLOPE_BASE
ST_MUL_BETA
ST_ROUND_BETA
ST_MUL_ADJUST
ST_ROUND_ADJUST
ST_CLAMP
ST_WAIT_PEAK_COMMIT
ST_TIMEOUT_FALLBACK
```

允许把相邻的单周期准备状态安全合并，但必须保持：

- 捕获、除法迭代、乘法结果保存、舍入、限幅和正式提交之间的状态所有权清晰；
- `state_current/state_next`和`ST_*`命名符合Erie三段式FSM规范；
- 每个寄存器只有一个时序驱动源；
- 所有组合next-state逻辑具有默认值和`default`分支。

### 6.2 启动条件

只有满足以下条件的新波峰候选才启动多周期算术：

```text
i_peak_valid == 1
i_run_enable == 1
i_recheck_busy == 0
i_slope_mode == ADAPTIVE
当前已经具有有效旧波峰锚点
当前周期波谷有效
当前周期允许自适应更新
A > 0
T合法且非零
epoch一致
```

第一个波峰、固定斜率模式、无效周期、重新获取和明确固定斜率回退不启动顺序除法，应沿原合同的即时路径
建立锚点或提交固定斜率。

### 6.3 待处理上下文

进入`ST_CAPTURE`时必须保存：

```text
旧波峰值、frame_id、sample_index和全部epoch
旧周期波谷值、frame_id、sample_index和全部epoch
待处理新波峰值、frame_id、sample_index和全部epoch
当前活动斜率
当前周期相交有效性、frame_id和全部epoch
当前no_cross_count
alpha_q15
beta_q15
timing_adjust_ratio_q15
slope_min_q16
slope_max_q16
no_cross_limit
```

运算开始后不得继续从外部端口或可被后续事件清理的活动上下文读取本次计算操作数。

### 6.4 共享乘法器操作

共享乘法器每次只执行一个操作：

```text
ST_MUL_ALPHA：
    shared_product = cycle_amplitude * alpha_q15

ST_MUL_BETA：
    shared_product = smooth_difference * beta_q15

ST_MUL_ADJUST：
    shared_product = base_abs * timing_adjust_ratio_q15
```

每个状态必须把乘法结果保存到对应专用寄存器后才能切换乘法器操作码。不得让后续状态覆盖仍被前一计算
引用的`shared_product`。

### 6.5 时钟使能

共享算术寄存器只在对应状态使能时更新。禁止通过组合逻辑生成门控时钟；所有状态、乘法器输入寄存器、
除法器和结果寄存器继续使用2 MHz `i_clk`及低有效异步复位。

## 7. 顺序除法器合同

### 7.1 算法

顺序除法器采用精确无符号逐位恢复除法或与其逐位等价的非恢复除法。冻结操作数为：

```text
dividend = base_rounded_numerator[41:0]
divisor  = period_frames[15:0]
quotient = base_quotient[41:0]
```

不得使用：

- 实数运算；
- 未验证的近似倒数；
- 丢弃低位的提前截断；
- 依赖综合器重新推导的通用组合`/`操作；
- 与输入数据相关且无固定上限的循环。

### 7.2 除零防御

合法周期在启动算术前必须保证`divisor != 0`。除法器内部仍必须防御性检查零分母：

```text
divisor == 0
→ 不进入迭代
→ 本次自适应结果无效
→ 进入固定斜率回退提交
→ 置位o_protocol_error_sticky
```

不得把零分母静默替换为1并宣称自适应结果有效。

### 7.3 固定周期上限

42-bit被除数的正式逐位实现应在42个迭代周期内产生完整商。考虑捕获、三个乘法、舍入、限幅、状态转换
和提交，冻结：

```text
C_SLOPE_UPDATE_MAX_CYCLES = 128
```

从周期算术启动到进入可提交状态的2 MHz周期数必须小于或等于128。实现使用7-bit计数器覆盖0至127；
不得自然回绕后继续占用接口。

### 7.4 超时回退

若算术引擎超过128周期仍未进入提交状态：

```text
取消本次自适应结果
待处理波峰仍可作为新锚点
新周期使用i_fixed_slope_q16
o_adaptive_slope_valid = 0
清除旧周期相交、波谷和候选统计
置位o_protocol_error_sticky
退出busy，禁止永久反压
```

超时回退不得提交部分商、旧共享乘法结果或未完成的限幅标志。

## 8. ready/valid和有界反压合同

### 8.1 波峰事件所有权

当一个合法自适应完整周期的新波峰以`i_peak_valid=1`出现时：

1. 算术引擎可以在未完成正式握手前观察并暂存稳定载荷，用于准备结果；
2. `o_peak_ready`保持0，事件源必须按ready/valid合同保持valid和全部载荷；
3. 暂存内容在正式握手前不得改变任何对外可见的锚点、斜率、计数或诊断；
4. 算术结果全部完成后进入`ST_WAIT_PEAK_COMMIT`并置`o_peak_ready=1`；
5. 只有`i_peak_valid && o_peak_ready`为1的时钟沿才正式提交新锚点和全部周期结果。

若发送方在`ready=0`期间违反合同撤销valid或改变载荷，属于上游协议错误；本模块必须丢弃暂存结果并
置位`o_protocol_error_sticky`，不得提交不再拥有的事件。

### 8.2 算术忙期间的其他输入

在周期算术忙期间：

```text
o_peak_ready   = 0，直到ST_WAIT_PEAK_COMMIT
o_result_ready = 0
o_valley_ready = 0
```

上游FIR fork和峰谷事件源必须保持各自valid及载荷，直到ready恢复。最大反压不超过128个2 MHz周期：

```text
128 / 2 MHz = 64 us
```

64 us远小于一个400 Hz帧的2.5 ms，不构成长期反压。任何实现都不得因算术busy超过冻结上限阻塞测量链。

### 8.3 即时路径

以下波峰不需要等待周期算术，可以按原接口立即握手：

```text
当前没有旧锚点的第一个可靠波峰
FIXED_SPI模式波峰
重新获取阶段波峰
不具备完整周期资格的波峰
重检失败或算术错误后的固定斜率波峰
```

即时路径仍必须保持原子提交，不得与正在运行的旧算术事务并存。

### 8.4 不形成跨模块组合环

`o_peak_ready/o_result_ready/o_valley_ready`可以依赖本模块已寄存的FSM状态、生命周期输入和重检busy，
不得组合依赖上游ready或下游相交ready而形成跨模块环。启动判定可以观察`i_peak_valid`和稳定峰值载荷，
但正式ready必须由已寄存的算术状态决定。

## 9. 生命周期、重检和异常撤销

### 9.1 复位

`i_rstn=0`必须清除：

```text
算术FSM
busy和timeout计数
待处理波峰及旧周期快照
乘法器操作码和结果寄存器
除法余数、商、被除数移位寄存器
待提交斜率和限幅诊断
```

复位释放后不得出现伪造ready脉冲或旧结果提交。

### 9.2 检测生命周期discard

本优化算术单元不是独立生命周期端口owner。父动态基线模块接收PWI的匹配
`i_detection_discard_event/reason/ID`后，必须在同一采样沿对本单元执行以下内部取消：

```text
立即撤销在途计算
清除待提交有效标志
返回ST_IDLE
禁止旧商或旧乘法结果后续写回
按上位合同清除RUN动态基线状态
```

当前`run_generation`的`DISCARD_STOP`、`DISCARD_ABORT`或`DISCARD_SYSTEM_FAULT`优先于算术完成和波峰提交；`identity_valid=0`的scope-only flush同样取消全部当前代际内部算术。不得保留`i_stop_ack_event`或`i_control_abort_event`直达本算术单元的端口或清除路径。

### 9.3 AMB/DC重检

`i_recheck_accept_event`在任何算术状态出现时，本周期自适应资格已经因重检失效，因此必须：

```text
取消在途算术
丢弃待处理波峰快照
清除周期自适应提交资格
保持上位合同要求保留的旧波峰锚点和旧活动斜率
进入重检禁止状态
```

重检成功后不得恢复被取消的旧算术；必须等待新的完整合格周期重新启动更新。重检失败按上位合同退回
固定斜率和锚点重新获取。

### 9.4 epoch和配置变化

RUN期间ACTIVE字段冻结，但算术引擎仍必须使用捕获时的配置和epoch快照。提交前若发现正式输入epoch与
待处理快照不一致，必须取消自适应提交并按固定斜率回退，不得混用不同版本的系数或配置。

## 10. 功耗和综合结构约束

- 不得使用门控时钟，使用FSM状态和时钟使能降低翻转；
- 共享乘法器只能存在一个周期更新实例，逐样本基线乘法器不计入该限制；
- 正式RTL不得保留周期更新路径的通用组合变量除法；
- 除法迭代器、共享乘法器和待处理上下文必须为可综合Verilog-2001；
- 不得使用`initial`、`real`、延时、系统任务、force/release或仿真专用结构；
- 组合逻辑必须完整赋值并避免锁存器；
- 每个寄存器只能有一个时序驱动源；
- 算术busy、timeout和commit控制不得形成未约束的高扇出组合反馈；
- 异步低有效复位保持项目既有接口语义，不得仅为FPGA DSP映射擅自改成同步复位。

## 11. 实施顺序

### 11.1 阶段A：精确位宽收缩

只修改周期更新中间信号宽度、扩展、舍入和饱和表达式，不增加FSM，不改变ready/valid和提交周期。
阶段A必须先通过逐位等价验证，才能开始多周期化。

### 11.2 阶段B：顺序除法器

引入待处理波峰快照、算术FSM、42周期精确除法和128周期超时保护。阶段B可以暂时保留三个独立乘法
表达式，但不得恢复组合变量除法。

### 11.3 阶段C：周期级乘法器复用

把三个低频乘法映射到同一个`33 x 17`共享乘法器，通过状态和专用结果寄存器隔离操作。完成阶段C后形成
正式优化RTL候选。

每个阶段都必须独立运行formatter-AST、lint、xsim和综合。不得一次修改三阶段后只执行一次最终回归。

## 12. 优化专用自检矩阵

原BSL-01至BSL-28全部保留，新增：

| 编号 | 场景 | 必须结果 |
| --- | --- | --- |
| OPT-01 | signed 24-bit最大合法峰谷幅度 | 42-bit分子不溢出，饱和前不截断 |
| OPT-02 | `T=1` | 完整42-bit商保留并正确执行32-bit斜率饱和 |
| OPT-03 | 最大合法短周期`T=16'h7fff` | 除法迭代和最近舍入正确 |
| OPT-04 | 除法半LSB边界 | 与组合黄金公式逐位一致 |
| OPT-05 | 最大正平滑差值 | 33/50/34-bit路径不溢出 |
| OPT-06 | 最大负平滑差值 | 对称舍入恢复负号正确 |
| OPT-07 | 最大合法调整比例 | 48-bit乘积和33-bit步长正确 |
| OPT-08 | 候选低于最负边界 | 提交`slope_min`并置低限幅诊断 |
| OPT-09 | 候选高于近零边界 | 提交`slope_max`并置高限幅诊断 |
| OPT-10 | 波峰valid在busy期间保持 | ready为0，载荷不被提前提交 |
| OPT-11 | 算术完成后的波峰握手 | 锚点、斜率和诊断同拍原子提交 |
| OPT-12 | busy期间FIR事务到达 | result ready为0，上游保持后无丢失消费 |
| OPT-13 | busy期间波谷事件到达 | valley ready为0，恢复后只消费一次 |
| OPT-14 | 每个FSM阶段触发STOP | 在途结果全部撤销，无迟到写回 |
| OPT-15 | 每个FSM阶段触发abort | 立即返回清理状态并禁止提交 |
| OPT-16 | 每个FSM阶段触发重检接管 | 旧斜率保留，跨重检自适应结果无效 |
| OPT-17 | busy期间异步复位 | 所有算术状态和pending上下文清零 |
| OPT-18 | 分母异常为0 | 不迭代、不死锁，固定斜率回退并置错误 |
| OPT-19 | 人工制造超过128周期 | timeout回退，不永久反压 |
| OPT-20 | pending epoch变化 | 取消自适应提交，不混合版本 |
| OPT-21 | 第一个波峰即时路径 | 不启动算术，固定斜率建立首锚点 |
| OPT-22 | FIXED_SPI即时路径 | 不启动除法和共享乘法器 |
| OPT-23 | 连续两个完整周期 | 每个周期结果独立，不复用旧pending数据 |
| OPT-24 | 优化前后随机差分 | 所有合法事务的正式结果逐位一致 |

`OPT-24`必须同时覆盖合法配置边界、正负平滑差值、无相交、lead三个区间、frame回绕短跨度和各类饱和。

## 13. 验证和交付门禁

### 13.1 静态门禁

正式优化RTL必须满足：

```text
formatter-AST：0 error，0 strict warning
独立RTL lint：0 error，0 warning
无组合变量除法
无多驱动
无锁存器
无门控时钟
无仿真专用结构
```

### 13.2 仿真门禁

```text
BSL-01至BSL-28全部通过
OPT-01至OPT-24全部通过
优化前后算术随机差分全部通过
ready/valid反压载荷保持检查通过
带身份detection discard/重检/复位逐状态撤销检查通过
```

### 13.3 综合门禁

Vivado综合至少要求：

```text
0 error
0 critical warning
latch count = 0
blackbox count = 0
2 MHz约束满足
```

优化完成后必须同时报告优化前后的LUT、寄存器、DSP、WNS/TNS和方法学警告。资源下降是优化评估依据，
但不得用资源改善替代功能和协议门禁。

### 13.4 当前黄金基线

优化前正式版本的已知综合基线为：

```text
Slice LUTs      = 2508
Slice Registers = 602
DSP48E1         = 9
Latch           = 0
Blackbox        = 0
2 MHz WNS       = +378.540 ns
TNS             = 0 ns
```

该数据仅用于前后对比，不是后续ASIC面积的绝对承诺。

## 14. 冻结结论

V1正式冻结：

1. 三项优化全部允许实施，但必须按照位宽收缩、顺序除法、乘法器复用的顺序独立回归；
2. 周期更新中间量采用第5节冻结宽度，任何更窄实现必须先提供新的完整范围证明；
3. 基础斜率采用42-bit正分子、42-bit精确商和43-bit负宽结果，32-bit饱和前不得截断；
4. 顺序除法器执行精确42周期逐位除法，不允许近似倒数或通用组合`/`；
5. 周期更新三个乘法复用一个signed `33 x 17`乘法器，逐样本基线乘法保持独立；
6. 算术更新最大允许128个2 MHz周期，即64 us，超过上限必须固定斜率回退并解除反压；
7. 算术忙期间峰、FIR和波谷输入允许有界反压，上游必须保持valid和载荷；
8. 新波峰锚点、新活动斜率、基础斜率和全部周期诊断必须在波峰正式握手沿原子提交；
9. 复位、当前generation的detection discard（包括scope-only flush）和AMB/DC重检可以在任一算术状态取消在途结果，旧结果不得迟到写回；
10. 优化不得改变动态基线数学时间、PPG相交方向、BSL-01至BSL-28结果或外部模块端口；
11. 正式交付必须通过BSL-01至BSL-28、OPT-01至OPT-24、随机差分、formatter-AST、lint、xsim和综合；
12. 当前合同只授权算术微架构优化，不授权ACTIVE版本、顶层连接或检测算法变化。
