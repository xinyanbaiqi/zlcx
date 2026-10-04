# PPG表征输入源与STATIC_BIAS控制合同

> Current normative version: V1.3. Substantive interface-freeze date: 2026-08-16; metadata baseline date: 2026-08-20. Status: `ACTIVE_NORMATIVE`; system closure is `NOT_CLOSED` until the current matrix audit records zero defects. RTL/TB evidence is `EVIDENCE_PENDING`.
> V1.3 change record: replaces non-contract netlist and stale dependency authority with current active contracts. Existing netlists and RTL/TB can only reveal a conflict and remain `EVIDENCE_PENDING`; no input-source, LED or STATIC_BIAS behavior changes.  
> Historical display of the substantive interface-freeze date: 2026-08-16.
> Historical V1.2 input-source optical-mode clarification date: 2026-08-17. Its stated qualifications are incorporated by V1.3 and do not create a second current authority.
> Historical V1.2 clarification: `BOTH`, `RED_ONLY` and `IR_ONLY` fixed-current measurement eligibility, and `OFF` rejection, are retained only to explain the rule incorporated into V1.3; this line does not define a separate active contract version.
> 合同性质：独立表征、模拟输入源和静态偏置控制边界  
> 工作时钟域：2 MHz数字控制域  
> 适用RTL：后续SAR安全选择wrapper、模拟输入MUX控制层和表征控制连接层  
> 语言目标：可综合Verilog-2001
> Historical evidence (non-normative): an earlier Characterization CDC XSim log
> reported 26 CCC checks. It does not cover this contract's complete input-source,
> characterization qualification, STATIC_BIAS permission or cross-module isolation.
> All current RTL/TB evidence for those rules remains `EVIDENCE_PENDING`.

## 1. 合同目的

本文冻结三类运行边界之间的控制区别：

1. 光电二极管输入下的正常PPG采样；
2. 光电二极管纯RED固定SAR9/SAR15表征；
3. 外部已知固定电流输入下的SAR9/SAR15性能表征；
4. 纯静态`STATIC_BIAS`节点观测。

本文不把固定电流性能表征误写为高频连续转换，也不把`STATIC_BIAS`误写为SAR测量。`EN_TEST`的含义由输入源选择定义，不由信号名称或测试MUX名称推断。

## 2. 依赖追踪与冲突优先级

**当前规范依赖（可决定本合同语义）**

1. C04 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` V1.7；
2. C02 — `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` V4.9；
3. C03 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V1.6；
4. C07 — `ppg_system_integration/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md` V1.1；
5. C08 — `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` V1.12；
6. C09 — `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.9；
7. C10 — `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.4。

The frozen STATIC_BIAS electrical levels and NORMAL waveform windows are
defined by this contract's explicit tables and timing rules. Spectre netlists,
RTL, TB, logs and predecessor documents are non-normative evidence or
conflict-discovery material; they cannot add an interface or override a rule.

发生冲突时采用：

```text
用户最新明确确认
    > 本合同的输入源、表征和STATIC_BIAS边界
    > 当前规范依赖中的配置字段、输入源、静态向量、事务和CDC语义
    > 历史RTL、旧顶层和旧注释
```

netlist中的`dc=0`、`dc=1.2`、pulse`delay`和pulse`width`只作为该工作模式的原始电平和时序证据。不得依据`EN_`、`CLK_`或`_LOW`名称推断电气极性。

## 3. 冻结范围

本文冻结：

1. `input_source`到`EN_TEST`的工作模式映射；
2. 光电二极管纯RED固定精度表征资格；
3. 光电二极管与外部固定电流输入的安全切换；
4. 所有非STATIC_BIAS表征测量固定使用MANUAL IDAC；
5. 固定电流性能表征的400 Hz间歇SAR9/SAR15行为；
6. `STATIC_BIAS`的静态原始0/1向量；
7. `S[4:0]`的SPI提交、CDC和STATIC_BIAS期间原子更新；
8. 表征模式下LEDDAC、LEDEN1和LEDEN2的所有权；
9. START、STOP、abort、复位和配置更新期间的安全边界；
10. AMB_CAL与本文的接口依赖。

本文不冻结：

- SPI物理帧格式、具体地址和寄存器bank实现；
- AMB_CAL各个内部波形的完整tick表；
- ADC模拟电路、CLK_DOUT和RAW捕获电路的内部实现；
- 动态基线、峰谷、FIR或精度窗口算法；
- Pad、ESD和芯片封装引脚。

## 4. 固定编码与控制来源

### 4.1 ACTIVE V4字段

```text
run_profile = 1'b0：NORMAL_PPG
run_profile = 1'b1：CHARACTERIZATION

input_source = 1'b0：光电二极管输入
input_source = 1'b1：外部固定电流输入

initial_precision = 1'b0：SAR9
initial_precision = 1'b1：SAR15
```

`run_profile`和`input_source`来自已提交的ACTIVE V4快照。运行期间不得直接读取SPI shadow值。

### 4.2 表征模式合法组合与IDAC策略

`CHARACTERIZATION`下的测量分支必须同时满足以下规则：

```text
run_profile == CHARACTERIZATION
&& static_characterization_enable == 1'b0
    -> idac_mode == MANUAL
    -> 禁止SEARCH_HOLD
    -> 禁止SEARCH_TRACK
    -> 禁止自动AMB/DCS搜索、周期AMB重检和NORMAL慢速IDAC跟踪
    -> AMB/DC码只能来自已提交的MANUAL码快照
```

以下两类表征测量是合法的：

```text
CHARACTERIZATION + PHOTODIODE + RED_ONLY + SAR9 + MANUAL
CHARACTERIZATION + PHOTODIODE + RED_ONLY + SAR15 + MANUAL
CHARACTERIZATION + EXTERNAL_TEST_CURRENT + BOTH + SAR9/SAR15 + MANUAL
CHARACTERIZATION + EXTERNAL_TEST_CURRENT + RED_ONLY + SAR9/SAR15 + MANUAL
CHARACTERIZATION + EXTERNAL_TEST_CURRENT + IR_ONLY + SAR9/SAR15 + MANUAL
```

上述固定精度表征在整个RUN期间保持启动时的SAR精度，不触发SAR9到SAR15或SAR15到SAR9自动切换。`STATIC_BIAS`不属于测量分支，不产生IDAC搜索或跟踪事务。`EXTERNAL_TEST_CURRENT + OFF`不属于固定电流测量，必须在COMMIT/START资格层拒绝。

### 4.3 独立表征控制

以下控制不占用ACTIVE V4保留位，由独立SPI表征控制路径提交，并在2 MHz域形成稳定控制值：

| 控制 | 语义 |
| --- | --- |
| `static_characterization_enable` | 进入纯静态`STATIC_BIAS`向量 |
| `test_mux_ctrl[4:0]` | STATIC_BIAS期间选择观测节点 |
| `static_test_commit_event` | 将SPI shadow测试控制原子提交到2 MHz域 |

`test_mux_ctrl`的具体SPI地址不属于本文；但未经CDC提交的shadow值不得直接连接模拟MUX。

## 5. 输入源与`EN_TEST`映射

### 5.1 光电二极管输入

```text
run_profile = NORMAL_PPG
input_source = 1'b0
    -> EN_TEST = 1'b0
    -> 使用普通光电二极管模拟输入路径

run_profile = CHARACTERIZATION
static_characterization_enable = 1'b0
input_source = 1'b0
optical_mode = RED_ONLY
    -> EN_TEST = 1'b0
    -> 使用光电二极管输入执行固定SAR9或固定SAR15纯RED表征
    -> idac_mode必须为MANUAL
    -> AMB/DC_R码来自已提交的MANUAL码快照
    -> SAR精度在整个RUN期间保持不变
```

`EN_TEST=0`在NORMAL和纯RED光电二极管表征运行期间保持，不得在Q1、Q2、Q3或ADC捕获期间改变。

### 5.2 外部固定电流输入

```text
run_profile = CHARACTERIZATION
static_characterization_enable = 1'b0
input_source = 1'b1
    -> EN_TEST = 1'b1
    -> 外部精密电流源接入模拟输入路径
```

外部固定电流测量允许的`optical_mode`集合固定为：

```text
BOTH      -> 执行RED后IR两笔NORMAL间歇测量事务，LED仍全程关闭
RED_ONLY  -> 只执行RED测量事务，IR波形、IR owner和IR ADC事务关闭
IR_ONLY   -> 只执行IR测量事务，RED波形、RED owner和RED ADC事务关闭
OFF       -> 不属于固定电流测量，作为非法测量组合拒绝
```

`optical_mode`只选择测量颜色、事务数量和SAR/ADC物理时序，不重新打开LED。外部固定电流模式始终保持`EN_TEST=1`、`LEDEN1_LOW=0`、`LEDEN2_LOW=0`和`LEDDAC[7:0]=8'h00`；AMB/DC码仍来自已提交的MANUAL码快照，SAR精度仍固定为START时的SAR9或SAR15。

外部固定电流的绝对数值由片外仪器提供，不由RTL产生或推断。数字控制只选择输入源，并保持该选择稳定。

固定电流模式的行为为正常间歇采样：

1. 仍使用400 Hz、5000个2 MHz周期的NORMAL宏帧；
2. SAR9/SAR15精度由已提交精度配置固定；
3. 使用NORMAL红光/红外事务的原有Q3和预建立时序；
4. `LEDEN1_LOW=0`、`LEDEN2_LOW=0`；
5. `LEDDAC[7:0]`不产生有效LED驱动窗口；
6. `idac_mode`必须为MANUAL，禁止AMB/DCS自动校准、自动IDAC搜索、周期AMB重检和NORMAL慢速IDAC跟踪；
7. `frame_id`、`sample_index`和ADC结果元数据仍按NORMAL事务规则产生。

固定电流模式不是3200 Hz快速校准，也不是连续高频脉冲模式。

### 5.3 输入源切换

`input_source`只能在新的RUN安全接管前锁存。发生以下任一事件时，当前事务必须保持原输入源解释：

- 已接收事务的预建立；
- Q1、Q2或Q3工作；
- ADC转换在途；
- `CLK_DOUT`同步和RAW捕获；
- 事务结果等待下游消费。

新的输入源配置必须等待STOP排空或合同规定的宏帧安全边界，不得在模拟波形中途切换。

## 6. `STATIC_BIAS`纯静态模式

### 6.1 进入条件

```text
run_profile = CHARACTERIZATION
static_characterization_enable = 1'b1
input_source = 1'b1
```

`input_source=1`是STATIC_BIAS的合法START资格。它不参与第6.2节静态向量的具体选择，但`input_source=0`必须拒绝START。

STATIC_BIAS采用模拟运行许可与测量运行许可分离：

```text
analog_run_enable                 = run_enable
measurement_run_enable            = 1'b0
measurement_allow_new_transaction = 1'b0
```

因此STATIC_BIAS只允许SSW建立静态向量；Scheduler和AMI不得接收测量START，不产生ADC事务，也不推进正常测量计数。

进入后禁止：

- NORMAL ADC事务；
- AMB_CAL和DCS_CAL事务；
- SAR9/SAR15 Q1/Q2/Q3波形；
- `CLK_DOUT`结果归属；
- 400 Hz `frame_id`和`sample_index`推进；
- 自动IDAC搜索和精度窗口切换。

### 6.2 netlist原始静态向量

以下是STATIC_BIAS的逻辑值合同。数值直接对应用户提供的netlist原始`dc`值，不解释信号名称的模拟极性：

| 信号 | STATIC_BIAS逻辑值 |
| --- | ---: |
| `EN_TEST` | `1` |
| `CLK_BUF_LOW` | `1` |
| `CLK_IREF_IDAC_LOW` | `1` |
| `CLK_IREF_IDAC_SAR9_LOW` | `1` |
| `CLK_IREF_IDAC_SAR15_LOW` | `1` |
| `CLK_AFERST_LOW` | `1` |
| `CLK_TIAEN_LOW` | `1` |
| `EN_SAR9_AMB_LOW` | `1` |
| `EN_SAR9_DC_LOW` | `1` |
| `EN_SAR15_AMB_LOW` | `1` |
| `EN_SAR15_DC_LOW` | `1` |
| `EN_TIA_LOW` | `0` |
| `EN_SAR9_IREF` | `0` |
| `EN_SAR15_IREF` | `0` |
| `CLK_9Q1_LOW` | `0` |
| `CLK_15Q1_LOW` | `0` |
| `CLK_Q2_LOW` | `0` |
| `CLK_Q3_LOW` | `0` |
| `EN_15SAR_LOW` | `0` |
| `LEDDAC[7:0]` | `8'h00` |
| `LEDEN1_LOW` | `0` |
| `LEDEN2_LOW` | `0` |
| `IDAC_SAR9AMBN_LOW[7:0]` | `8'h00` |
| `IDAC_SAR9DCN_LOW[7:0]` | `8'h00` |
| `IDAC_SAR15AMBN_LOW[7:0]` | `8'h00` |
| `IDAC_SAR15DCN_LOW[7:0]` | `8'h00` |

`S[4:0]`不采用netlist中某次仿真的固定值，而由已提交SPI测试MUX配置驱动。

### 6.3 `S[4:0]`原子更新

SPI写入先进入source域shadow寄存器。`static_test_commit_event`经过CDC后，在2 MHz域同一安全更新沿原子锁存：

```text
test_mux_shadow[4:0]
    -> CDC提交事件
    -> test_mux_committed[4:0]
    -> STATIC_BIAS输出S[4:0]
```

STATIC_BIAS保持期间允许更新`test_mux_committed`。五个bit必须在同一2 MHz更新沿对外可见，不能逐bit异步变化。测试人员在每次更新后等待模拟节点稳定，再读取观测值。

NORMAL、固定电流NORMAL、AMB_CAL和DCS_CAL期间，`S[4:0]`必须输出安全值`5'b0`，不接受测试MUX更新对模拟工作路径的影响。

## 7. LEDDAC与LEDEN表征规则

### 7.1 固定电流模式

外部固定电流已替代光电二极管/光学激励，因此：

```text
LEDEN1_LOW = 0
LEDEN2_LOW = 0
LEDDAC[7:0]不产生有效驱动窗口
```

这不改变NORMAL光电二极管模式中由SAR9/SAR15 netlist定义的LEDDAC上升时间和保持宽度。

### 7.2 STATIC_BIAS

STATIC_BIAS严格采用第6.2节静态向量：

```text
LEDDAC[7:0] = 8'h00
LEDEN1_LOW = 0
LEDEN2_LOW = 0
```

### 7.3 光电二极管模式边界

NORMAL红光/红外LEDDAC数据码、上升时刻、保持宽度和LEDEN颜色互斥关系不在本文重新定义，继续由SAR安全选择合同及其对应NORMAL netlist章节冻结。

纯RED光电二极管CHARACTERIZATION复用RED_ONLY对应的SAR9或SAR15 netlist窗口：只产生RED事务，不产生IR波形或IR ADC事务；SAR精度和已锁存MANUAL码在整个RUN期间保持。

## 8. START、STOP、abort与复位

### 8.1 START

START只能接收一组完整且稳定的配置快照：

- `run_profile`；
- `input_source`；
- `initial_precision`；
- `optical_mode`；
- `idac_mode`；
- 已提交的MANUAL AMB/DC码；
- `static_characterization_enable`；
- 已提交的测试MUX控制值。

非法组合不得开始模拟动作：

```text
NORMAL_PPG && input_source == 1'b1
CHARACTERIZATION && static_characterization_enable == 1'b0 && input_source == 1'b1 && idac_mode != MANUAL
CHARACTERIZATION && static_characterization_enable == 1'b0 && input_source == 1'b0 && optical_mode != RED_ONLY
CHARACTERIZATION && static_characterization_enable == 1'b0 && input_source == 1'b1 && optical_mode == OFF
CHARACTERIZATION && static_characterization_enable == 1'b1 && input_source != 1'b1
CHARACTERIZATION && static_characterization_enable == 1'b1 && measurement_run_enable != 1'b0
CHARACTERIZATION && static_characterization_enable == 1'b1 && measurement_allow_new_transaction != 1'b0
```

非法组合不得产生START ACK、IDAC启动边界、400 Hz宏帧、波形上下文或ADC owner，且不得改变`frame_id`或`sample_index`；模拟输出保持安全并报告配置/协议错误。

固定电流和纯RED光电二极管表征START后，精度、输入源、MANUAL码和测试规则保持到STOP；STATIC_BIAS START后直接建立第6.2节静态向量。

### 8.2 STOP

STOP后：

1. 禁止新的NORMAL或校准事务；
2. 已开始的固定电流SAR事务运行到合同规定的安全末沿；
3. 等待ADC和数据链排空；
4. 清除在途输入源和测试事务快照；
5. 最终进入安全静态向量或复位默认向量。

STATIC_BIAS没有ADC在途事务，STOP可以在确认控制域安全后撤销静态向量。

### 8.3 abort与复位

`control_abort_event`或复位发生时：

- 立即撤销固定电流事务和静态配置提交；
- 禁止迟到的ADC完成事件形成有效结果；
- 清除未消费的输入源/测试MUX更新；
- 所有模拟输出转入已冻结的安全向量；
- 重新START前不得恢复任何旧测试上下文。

## 9. CDC和控制所有权

```text
SPI source shadow
    -> 配置CDC/提交握手
    -> 2 MHz committed control
    -> SAR安全选择wrapper和模拟输入MUX控制层
```

规则如下：

1. `input_source`和`run_profile`使用ACTIVE V4 committed快照；
2. `test_mux_ctrl`使用独立测试控制提交路径；
3. 未提交的SPI shadow不得直接驱动`EN_TEST`、`S[4:0]`、LEDDAC或IDAC控制；
4. 已接收事务必须使用接收沿锁存的输入源和数字码；
5. CDC忙、STOP、abort或复位期间不得产生迟到的模拟控制更新；
6. V4保留位不被本文重新解释。

## 10. AMB_CAL边界依赖

AMB_CAL不是CHARACTERIZATION，也不是STATIC_BIAS。它使用正常光电二极管输入语义：

```text
input_source = 1'b0
EN_TEST = 1'b0
RED、IR LED关闭
LEDDAC和DC码为0
```

AMB_CAL的完整SAR9专用波形、`CAL_Q3_TICK`、局部tick窗口和候选AMB码有效窗口由
当前 `PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.8 独立冻结。本文不重复该波形表，也不允许STATIC_BIAS向量覆盖AMB_CAL波形。

校准责任边界固定为：配置管理器在COMMIT/START前只检查CHARACTERIZATION的MANUAL、输入源、精度和STATIC_BIAS等静态组合，不增加`calibration_plan`字段，也不预测未来AMB_CAL/DCS_CAL；RUN期间若异常出现CHARACTERIZATION校准请求，由AMI在请求源阻断并由Scheduler在接收端复核，波形、ADC owner、IDAC自动pending和正式结果均不得启动。

## 11. 验收矩阵

| 编号 | 场景 | 验收要求 |
| --- | --- | --- |
| CIS-01 | 光电二极管输入 | `input_source=0`时`EN_TEST=0`并保持 |
| CIS-02 | 固定电流输入 | `input_source=1`时`EN_TEST=1`并保持 |
| CIS-03 | 固定电流LED关闭 | 两路LEDEN为0，LEDDAC无有效窗口 |
| CIS-04 | 固定电流400 Hz | SAR9固定精度按正常宏帧工作 |
| CIS-05 | 固定电流SAR15 | SAR15固定精度按正常宏帧工作 |
| CIS-06 | 禁止自动校准 | 固定电流模式不接受AMB/DCS自动搜索 |
| CIS-07 | 输入源反压 | 事务在途时拒绝输入源切换 |
| CIS-08 | STATIC_BIAS进入 | 建立完整netlist静态向量 |
| CIS-09 | STATIC_BIAS无SAR | Q1/Q2/Q3和ADC事务均不产生 |
| CIS-10 | STATIC_BIAS测试MUX | `S[4:0]`来自已提交SPI值 |
| CIS-11 | STATIC_BIAS原子更新 | 五个S bit同一更新沿改变 |
| CIS-12 | STATIC_BIAS LED状态 | LEDDAC为0，两路LEDEN为0 |
| CIS-13 | NORMAL隔离MUX | NORMAL期间S输出0，测试MUX更新不影响模拟路径 |
| CIS-14 | START快照 | 输入源、精度和模式在START时原子锁存 |
| CIS-15 | STOP排空 | 禁止新事务并等待在途链路安全结束 |
| CIS-16 | abort | 取消在途测试上下文，不产生迟到结果 |
| CIS-17 | 复位 | 清除shadow提交、事务和静态状态 |
| CIS-18 | CDC提交 | 未提交shadow不改变2 MHz输出 |
| CIS-19 | AMB边界 | AMB使用PD输入、EN_TEST=0，采用SAR合同专用波形 |
| CIS-20 | 非法组合 | 非法配置不产生模拟启动 |
| CIS-21 | 纯RED光电二极管SAR9 | CHARACTERIZATION、RED_ONLY、SAR9、MANUAL，EN_TEST=0，精度全RUN保持 |
| CIS-22 | 纯RED光电二极管SAR15 | CHARACTERIZATION、RED_ONLY、SAR15、MANUAL，EN_TEST=0，精度全RUN保持 |
| CIS-23 | 表征IDAC策略 | 非STATIC_BIAS表征拒绝SEARCH_HOLD和SEARCH_TRACK |
| CIS-24 | 表征固定码 | 表征AMB/DC码来自已提交MANUAL快照，不产生搜索、跟踪或周期重检 |
| CIS-25 | 非法表征START副作用 | 非MANUAL或非法光学组合无START ACK、波形、owner和序号推进，模拟保持安全 |
| CIS-26 | STATIC_BIAS输入源资格 | `static_characterization_enable=1`且`input_source=0`时拒绝START |
| CIS-27 | STATIC_BIAS测量隔离 | `measurement_run_enable=0`且`measurement_allow_new_transaction=0`，Scheduler/AMI无START、ADC事务或正常计数推进 |
| CIS-28 | STATIC_BIAS模拟许可 | `analog_run_enable=run_enable`，SSW可建立静态向量，测量许可不得反向屏蔽模拟许可 |
| CIS-29 | 固定电流光学模式 | `BOTH/RED_ONLY/IR_ONLY`分别产生规定的RED/IR测量事务，且两路LED全程关闭 |
| CIS-30 | 固定电流OFF拒绝 | `CHARACTERIZATION + EXTERNAL_TEST_CURRENT + OFF`在COMMIT/START前拒绝，不产生测量事务 |

所有验收必须比较真实端口电平、事务握手、400 Hz相位、静态向量、S[4:0]原子更新和输入源锁存结果，不得用固定ready或内部force代替。

## 12. 后续实现边界

本文冻结后，必须按以下顺序实施：

1. 在SSW合同中登记纯RED光电二极管固定SAR9/SAR15资格及本合同依赖版本；
2. 在配置管理器合同和RTL中实现MANUAL、输入源和STATIC_BIAS合法性检查；
3. 修改SSW RTL及其单模块TB，保持既有netlist波形和IDAC逐bit规则；
4. 追踪AMI是否存在表征搜索/跟踪旁路，只有发现冲突时才增加防御门控；
5. 回归固定表征、STATIC_BIAS、AMB_CAL、NORMAL红光/红外和CDC安全场景；
6. 再进入Scheduler+SSW+AMI联合TB和最终数字顶层集成。

## 13. 冻结结论

本合同V1.2正式冻结以下不可混淆的语义：

```text
input_source=0 -> 光电二极管 -> EN_TEST=0
input_source=1 -> 外部固定电流 -> EN_TEST=1

固定电流表征 -> 正常400 Hz间歇SAR9/SAR15
纯RED光电二极管表征 -> CHARACTERIZATION、RED_ONLY、固定SAR9/SAR15、MANUAL、EN_TEST=0
所有非STATIC_BIAS CHARACTERIZATION测量 -> 仅允许MANUAL，不允许自动搜索或慢速跟踪
STATIC_BIAS -> 纯静态netlist 0/1向量和SPI原子S[4:0]
STATIC_BIAS -> input_source=1、analog_run_enable=run_enable、measurement_run_enable=0
AMB_CAL -> 独立光电二极管校准路径，由SAR合同提供完整专用波形
```

任何后续端口、配置或波形修改必须先版本化本合同或其明确依赖合同。
