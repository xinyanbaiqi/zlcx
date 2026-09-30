# PPG SAR9/SAR15安全选择Wrapper接口合同

> V1.10修订日期：2026-09-10。AMB_CAL单相积分改造：`ppg_sar9_sar15_safe_selection_wrapper.v`V1.5起，AMB_CAL（`reg_cal_frame_type==FRAME_TYPE_AMB`）期间`CTRL_Q2`（`o_clk_q2_low`）不再产生`[262,264)`脉冲，全程保持`0`；`CTRL_Q3`（`o_clk_q3_low`）在`[265,267)`的既有窗口完全不变，DCS_CAL的Q2/Q3行为也完全不变。详见第6.4节。第6.1节数字控制窗口表和第5.5节暗态采样描述已同步更新为该真实行为；不改变本合同SSW-01至SSW-52任何既有编号条款的行为定义本身，只改变AMB_CAL一种帧类型下CTRL_Q2这一项输出的实际取值。真实依据、根因和影响范围见第6.4节。
> V1.9修订日期：2026-08-30。桶1 RTL会话（SID-11+LFA-06+OIB-01+LFA-10(b)专属会话）新增：（1）新状态输出`o_owner_q3_window_closed`——在途owner自身选定的Q3窗口是否已关闭（per-owner sticky，跨宏帧节拍环绕不丢失，owner释放/新owner建立时复位），供`ppg_400hz_frame_calibration_scheduler.v`门控`flag_completion_success`，防止早于Q3的CLK_DOUT冒充协议意义上的成功完成（LFA-06）；门控放在`flag_completion_success`而不是`flag_owner_release`/`flag_completion_match`上，owner身份匹配即合法释放槽位，避免"Q3若因异常提前完成而不再出现"导致owner永久卡在in-flight、连带`o_wrapper_idle`永远为假、`transaction_mismatch_sticky_o`永远清不掉的死锁——这是一次真实构造中发现并纠正的设计。（2）新增模块参数`C_ENABLE_TEST_INJECTION`（默认0，生产网表必须为0）和一对验证专属端口`i_test_inject_enable`/`i_context_handover_stall_request`，与`ppg_adc_measurement_idac_integration.v`已有的同名验证注入基础设施同一约定：只在`C_ENABLE_TEST_INJECTION!=0`且`i_test_inject_enable=1`时生效，允许在波形上下文接管tick合法压低`o_waveform_context_ready`，不构成协议违规。（3）`flag_switch_protocol_error_condition`第4个OR项（接管tick context_valid但ready仍为0）收窄为只在**排除掉上述反压注入这个因素后依然会不ready**时才判定为真协议违规——反压注入导致的接管未命中不再连带触发SSW阻断的`switch_protocol_error_sticky_o`，只留给Scheduler自己非阻断的`o_launch_timeout_sticky`独立表态，兑现本合同和Scheduler合同一贯宣称的"非阻断launch-timeout应可独立于阻断故障分类"。真实证据：`tb_ppg_control_top_owner_identity_backpressure.v`OIB-01（V1.1，iverilog+Vivado 2022.2 xsim双工具confirmed）和`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v`LFA-06（V1.3，同样双工具confirmed）。不改变本合同SSW-01至SSW-52任何既有编号条款的行为；三项改动均为新增能力，不touch任何既有生产信号路径的既有行为。
> V1.8 fail-closed integration review, 2026-08-20: generation tagging, physical-idle source mapping, STOP discard-pending owner release, SSW supervisor fault records and contract-vs-evidence terminology remain normative, but system closure is `NOT_CLOSED` until the matrix audit records zero defects. Implementation evidence is `EVIDENCE_PENDING`.
> V1.8 change record: replaces non-normative RTL/netlist and stale dependency authority with current active contracts. It changes no physical phase, Q1/Q2/Q3, owner, waveform, abort or fault behavior.
> Normative status: V1.9 is the sole current SSW interface and lifecycle authority (V1.9 is additive over V1.8, see the 2026-08-30 change record above). Earlier V1.3.x-V1.7 status and historical regression wording cannot classify missing joint implementation evidence as a contract-interface defect.

> Historical V1.3.2 freeze record (non-normative); V1.8 is the sole current normative revision.  
> 冻结日期：2026-08-15  
> V1.3修订：拆分模拟波形上下文与ADC结果事务owner，冻结双波形上下文槽、owner截止点、SAR9/SAR15独立跨色白名单及异常收尾语义  
> V1.3.1勘误日期：2026-08-15  
> V1.3.1勘误：冻结四组8-bit IDAC数据总线的逐bit码控、精度隔离、事务类型资格、netlist窗口和快照稳定规则  
> V1.3.1完成释放措辞勘误日期：2026-08-15  
> V1.3.1完成释放措辞勘误：匹配完成事件无论`success`取值均释放旧物理owner；abort保留最小释放身份，reset立即失效身份；不改变端口、时序或SSW-01至SSW-48编号  
> V1.3.1实现状态勘误日期：2026-08-16  
> V1.3.1实现状态勘误：删除V1.2单fire的过时实现状态；SSW-01至SSW-48已有历史回归证据，其中SSW-45至SSW-48的历史日志覆盖四组IDAC数据总线精度隔离、逐bit码窗和模式/类型矩阵。本勘误不把历史日志表述为当前RTL闭合，也不改变端口、时序、owner或`success=0`释放语义。  
> V1.3.2小版本修订日期：2026-08-16  
> V1.3.2小版本修订：增加`CHARACTERIZATION + PHOTODIODE + RED_ONLY`固定SAR9/SAR15合法资格，冻结RED接管点、同色Q3中心、精度专属预热和MANUAL码快照；明确STATIC_BIAS必须使用`input_source=1`，非法配置不得产生波形或有效IDAC总线。四组IDAC总线精度隔离规则保持不变。  
> V1.3.2光学模式勘误日期：2026-08-17  
> V1.3.2光学模式勘误：固定电流CHARACTERIZATION明确支持`BOTH`、`RED_ONLY`和`IR_ONLY`三种测量事务模式；`OFF`只用于安全关闭，不获得固定电流波形或owner资格。LEDEN/LEDDAC在三种固定电流模式下均保持关闭。  
> V1.3.2实现证据状态更新日期：2026-08-16
> Historical evidence (non-normative): earlier RTL/TB/XSim logs reported SSW-01
> through SSW-52. They cover only an earlier single-module context and do not
> establish current joint or final-Top evidence; all current implementation
> evidence remains `EVIDENCE_PENDING`.
> 目标RTL：`ppg_sar9_sar15_safe_selection_wrapper.v`  
> 目标TB：`tb_ppg_sar9_sar15_safe_selection_wrapper.v`  
> 工作时钟：2 MHz数字主时钟  
> RTL语言：可综合Verilog-2001  
> 配置基线：联合ACTIVE固定1024 bit；本SSW仅消费V4 `[639:0]` 运行/时序字段，V5 `[1023:640]` 检测字段由AMI->PWI检测链消费，SSW不得解包或产生V5默认值。
> 验收范围：SSW-01至SSW-52（V1.3.2新增SSW-49至SSW-52）

## 1. 合同目的

本文冻结SAR9、SAR15、AMB专用SAR9校准、固定电流表征和`STATIC_BIAS`的统一物理相位、模拟波形上下文、独立ADC结果owner、预建立、模拟控制选择、安全切换、ADC完成归属及诊断边界。

本wrapper负责：

1. 消费唯一外部400 Hz宏帧相位和快速校准子帧相位；
2. 从既有SAR9/SAR15时序核提取波形规则，形成外部相位驱动的译码实现；
3. 在固定Q3中心前按不同精度的既定提前量完成模拟预建立；
4. 在预热开始前通过独立波形通道锁存完整模拟上下文、AMB/DC码及其epoch；
5. 在固定波形接管点开放`o_waveform_context_ready`，并允许IR波形在RED ADC owner仍在途时独立接管；
6. 为NORMAL、AMB_CAL、DCS_CAL RED和DCS_CAL IR产生正确的模拟控制向量；
7. 在SAR9/SAR15、NORMAL/校准及颜色变更时执行先断后通的注册化安全选择；
8. 在冻结截止点前独立返回`o_adc_owner_ready`，并只在AMI真实fire同拍接受ADC结果owner；
9. 向400 Hz调度器返回模拟安全、时序空闲、两类资格和阻断诊断。

本wrapper不负责：

- 产生400 Hz宏帧、3200 Hz子帧、`frame_id`或`sample_index`；
- 产生或捕获模拟ADC的`CLK_DOUT`、RAW和ADC_RST；
- 计算或提交AMB/DC候选码；
- 解释联合ACTIVE位图、SPI shadow或配置CDC；SSW只接收Top/AMI已注册的2 MHz稳定资格与时序端口，不直连shadow或V5 payload；
- 计算IDAC搜索、FIR、动态基线、峰谷或精度窗口决策；
- 改变SAR9/SAR15模拟电路的物理建立时间、Q1/Q2/Q3相对关系。

## 2. 依赖追踪与优先级

**当前规范依赖（可决定SSW接口或语义）**

1. C01 — `ppg_system_integration/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` V1.10；
2. C04 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` V1.7；
3. C06 — `ppg_system_integration/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` V1.3；
4. C08 — `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` V1.9；
5. C10 — `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.2；
6. C24 — `ppg_system_integration/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` V1.5。

The fixed phase, Q1/Q2/Q3, owner and safety-selection rules are defined in
this contract. RTL, capture implementation, Spectre netlists, regressions and
logs are non-normative evidence or conflict-discovery material; they cannot
define a SSW input, output, waveform edge or fault path.

冲突优先级为：

```text
用户最新明确确认
    > 本合同的相位、快照、安全选择和端口规则
    > 当前规范依赖中的AMI及调度器数字事务语义
    > 历史顶层、注释和handoff
```

`ppg_timing_sar9.v`和`ppg_timing_sar15.v`的现有内部`cnt_frame`仅保留为波形相对窗口真源。它们不得继续作为最终系统中的独立物理时间基准。

## 3. 固定编码

```text
precision_mode = 1'b0：SAR9
precision_mode = 1'b1：SAR15

frame_type = 2'b00：AMB_CAL
frame_type = 2'b01：DCS_CAL
frame_type = 2'b10：NORMAL
frame_type = 2'b11：非法

color_ir = 1'b0：RED
color_ir = 1'b1：IR

optical_mode = 2'b00：RED后IR双光
optical_mode = 2'b01：仅RED
optical_mode = 2'b10：仅IR
optical_mode = 2'b11：安全关闭

run_profile = 1'b0：NORMAL_PPG
run_profile = 1'b1：CHARACTERIZATION
```

AMB_CAL的`color_ir=0`仅为协议身份；它不表示红光LED导通。

## 4. 唯一外部物理相位

### 4.1 时间基准

```text
T_CLK = 0.5 us
C_MACRO_FRAME_TICKS = 5000
T_MACRO_FRAME = 2.5 ms
C_CAL_SUBFRAME_TICKS = 625
T_CAL_SUBFRAME = 312.5 us
```

调度器是唯一物理相位所有者。wrapper只消费：

```text
i_macro_tick[12:0]              // 0..4999
i_calibration_subframe_index[2:0] // 0..7
i_calibration_local_tick[9:0]   // 0..624，仅校准宏帧有效
```

wrapper不得另起自由运行的400 Hz或3200 Hz计数器，不得以`waveform_context_fire`或`i_adc_owner_commit_event`反推、重置或移动物理相位。

`i_calibration_local_tick`是调度器的显式输出。由于5000恰为8乘625，调度器内部子帧计数器是该端口的唯一真源。

### 4.2 NORMAL固定Q3中心

NORMAL宏帧Q3中心冻结为：

```text
RED Q3 center = macro_tick 300 = 宏帧起点后150 us
IR  Q3 center = macro_tick 460 = 宏帧起点后230 us
IR - RED = 160 ticks = 80 us
```

必须满足：

```text
T_Q3_RED(SAR9)  == T_Q3_RED(SAR15)
T_Q3_IR(SAR9)   == T_Q3_IR(SAR15)
```

仅SAR9/SAR15的预建立时间、Q1/Q2/Q3窗口宽度、内部末位完成时间允许不同；同色Q3中心不得因精度、输入幅度、IDAC码、颜色模式或反压而移动。

单光模式不得搬移时隙：

```text
RED-only：仍使用macro_tick 300
IR-only：仍使用macro_tick 460
```

### 4.3 NORMAL预建立包络

既有SAR时序相对Q3的最早控制边沿和最后控制边沿如下：

| 时序模板 | 最早边沿相对Q3 | 最后边沿相对Q3 | RED包络 | IR包络 |
| --- | ---: | ---: | --- | --- |
| SAR9 | `-256 tick` | `+18 tick` | `44..318` | `204..478` |
| SAR15 | `-273 tick` | `+8 tick` | `27..308` | `187..468` |

因此SAR15在本宏帧tick 27开始RED预建立，SAR9在tick 44开始RED预建立；两者都不再跨越上一宏帧。

`o_waveform_context_ready`的NORMAL波形上下文接管点冻结为：

```text
RED事务：macro_tick 0
IR事务： macro_tick 160
```

RED接管点到SAR15最早边沿有27 tick保护；IR接管点到SAR15最早边沿也有27 tick保护。

### 4.4 快速校准固定包络

快速校准固定使用SAR9单色时序模板，不复用NORMAL双光的红外80 us相对偏移。

```text
CAL_CONTEXT_LATCH_TICK = 0
CAL_WAVE_START_TICK    = 10
SAR9_PROFILE_Q3_OFFSET = 256
SAR9_PROFILE_END_OFFSET = 274
CAL_Q3_TICK            = 266
CAL_WAVE_END_TICK      = 284
CAL_IDAC_COMMIT_TICK   = 385
```

数学关系为：

```text
CAL_Q3_TICK = CAL_WAVE_START_TICK + SAR9_PROFILE_Q3_OFFSET
CAL_WAVE_END_TICK = CAL_WAVE_START_TICK + SAR9_PROFILE_END_OFFSET
```

因此以下三类校准均使用相同的Q3中心：

```text
AMB_CAL       -> local tick 266
DCS_CAL RED   -> local tick 266
DCS_CAL IR    -> local tick 266
```

相邻子帧同类Q3相差625 tick，严格对应3200 Hz。`color_ir`只选择DCS校准的模拟颜色通道、LED和DC码，不改变校准Q3相位；AMB_CAL的`color_ir=0`仅为协议身份。

从`CAL_WAVE_END_TICK=284`至`CAL_IDAC_COMMIT_TICK=385`保留101 tick，即50.5 us，用于`CLK_DOUT`同步、RAW捕获、IDAC判定和下一候选码准备。

### 4.5 ADC结果owner截止点

模拟波形上下文与ADC结果owner是两套独立状态。波形接管后，wrapper可在对应截止点之前、当前无旧owner时给出`o_adc_owner_ready`：

```text
NORMAL RED owner deadline = macro_tick 283
NORMAL IR  owner deadline = macro_tick 443
CAL owner deadline        = local_tick 248
```

owner允许在匹配波形上下文fire之后、截止点到达前的任一2 MHz上升沿提交。NORMAL截止点位于最早SAR15 Q1窗口开始前一拍；校准截止点位于AMB专用local tick 249后段控制窗口开始前一拍。owner未按时提交时，固定Q3坐标不移动，但本次波形必须抑制Q1/Q2/Q3、LED有效采样和ADC结果接纳，并让已经开始的预建立控制安全收尾。

RED owner仍在途不阻止macro tick 160接管IR波形上下文；它只会暂时阻止IR `o_adc_owner_ready`。若RED真实DONE在IR截止点前释放owner，IR仍可正常提交；否则本帧IR采样无效并置owner超时诊断。

### 4.6 SAR9/SAR15跨颜色连续保持白名单

双光SAR9中，用户已经明确只允许下列一项在RED与IR之间连续保持或发生物理窗口重叠：

```text
o_clk_iref_idac_sar9_low
```

统一Q3坐标下，其RED窗口为`[44,318)`、IR窗口为`[204,478)`，因此双光时输出并集为连续的`[44,478)`。`o_en_sar9_iref`、`o_en_sar9_amb_low`、`o_en_sar9_dc_low`以及其他SAR9控制仍使用各自独立颜色窗口，不允许附加跨色重叠。

双光SAR15中，用户已经明确允许下列四项在RED与IR之间连续保持或发生物理窗口重叠：

```text
o_clk_iref_idac_sar15_low
o_en_sar15_iref
o_en_sar15_amb_low
o_en_sar15_dc_low
```

SAR9单项白名单和SAR15四项白名单的具体0/1值及窗口必须逐tick来自已确认netlist，不得根据信号名称推断。两个精度的白名单彼此独立，不能交叉继承；除各自白名单外，两个波形上下文并存不得令任何RED/IR专属模拟控制产生额外重叠，`o_leden1_low`与`o_leden2_low`始终互斥。

### 4.7 四组IDAC数据总线的精度隔离和逐bit码控

以下四组信号是直接送往对应IDAC阵列的8-bit数字码总线，不是仅供观察的影子字段，也不能只依赖`o_en_sar9_*`或`o_en_sar15_*`使能完成电气隔离：

```text
o_idac_sar9ambn_low[7:0]
o_idac_sar9dcn_low[7:0]
o_idac_sar15ambn_low[7:0]
o_idac_sar15dcn_low[7:0]
```

每一位必须独立满足：

```text
IDAC_BUS[k] =
    mode_qualified
 && precision_qualified
 && frame_type_qualified
 && netlist_code_window_active
 && latched_code[k]
```

其中：

- `mode_qualified`表示存在已在固定接管点锁存、尚未失效且允许执行当前安全波形的NORMAL或校准上下文；`STATIC_BIAS`强制不具备该资格；
- `precision_qualified`只允许当前波形快照选择的SAR精度驱动对应两组码总线；
- `frame_type_qualified`禁止AMB_CAL驱动任一DC总线，并禁止非法SAR15校准事务驱动任一码总线；
- `netlist_code_window_active`只来自对应SAR精度、颜色和码总线在已确认netlist/活动时序基线中的原始窗口，不得以AMB/DC使能窗口、Q3窗口、整个预建立包络或信号名称替代；
- `latched_code[k]`只来自该颜色波形上下文在预热前锁存的AMB或DC码第`k`位。

四组总线的强制矩阵冻结为：

| 当前合法波形 | `SAR9 AMB` | `SAR9 DC` | `SAR15 AMB` | `SAR15 DC` |
| --- | --- | --- | --- | --- |
| SAR9 NORMAL | SAR9 AMB netlist码窗内输出锁存AMB码 | SAR9 DC netlist码窗内输出当前颜色锁存DC码 | 全波形保持`8'h00` | 全波形保持`8'h00` |
| SAR9 DCS_CAL RED/IR | SAR9 AMB netlist码窗内输出已确认AMB码 | SAR9 DC netlist码窗内输出当前颜色候选DC码 | 全子帧保持`8'h00` | 全子帧保持`8'h00` |
| AMB_CAL | 仅第6.1节`[224,276)`输出锁存AMB候选码 | 全子帧保持`8'h00` | 全子帧保持`8'h00` | 全子帧保持`8'h00` |
| SAR15 NORMAL | 全波形保持`8'h00` | 全波形保持`8'h00` | SAR15 AMB netlist码窗内输出锁存AMB码 | SAR15 DC netlist码窗内输出当前颜色锁存DC码 |
| STATIC_BIAS | `8'h00` | `8'h00` | `8'h00` | `8'h00` |
| 非法、无上下文或安全关闭 | `8'h00` | `8'h00` | `8'h00` | `8'h00` |

DCS_CAL固定为SAR9；任何`precision_mode=1 && frame_type!=NORMAL`组合必须拒绝波形接管、保持四组总线为0并置协议诊断。外部固定电流输入仍属于400 Hz NORMAL SAR9或SAR15测量，因此按所选精度使用同一矩阵中的AMB/DC锁存码；固定电流规则只关闭LEDEN和LEDDAC，不得无条件清零所选精度的AMB/DC码总线。

码值只决定某一bit在自己的netlist码窗内是否为1，不决定窗口起止位置。对于锁存码`8'b1010_0101`，只有bit 7、5、2、0能在相应码窗起点上升并在码窗终点下降，其余bit全程为0。若锁存码为`8'h00`，逻辑码窗仍按netlist存在，但该总线不得产生任何bit翻转。

波形上下文fire后，实时committed码、pending码、SPI shadow或下一候选码发生变化均不得污染当前码窗。本帧或本子帧必须继续使用预热前快照，直到对应码窗结束；新码只能由后续合法波形上下文使用。未选精度两组总线必须从上下文接管到安全结束始终为`8'h00`，不得先输出码值再依靠模拟使能关闭，也不得出现组合MUX毛刺、单拍脉冲或跨精度镜像翻转。

## 5. 波形快照、owner与预热规则

### 5.1 快照原子性

wrapper仅在模拟波形通道真实fire时锁存模拟控制上下文：

```text
precision_mode
frame_type
color_ir
frame_id
AMB code and epoch
color-selected DC code and epoch
optical_mode
input_source
color-selected LEDDAC code
```

从成功锁存至对应波形安全结束、STOP、abort或复位之前，所有字段必须保持对模拟输出的一致解释。中途不得因AMI committed码更新、ACTIVE COMMIT或精度请求改变已经预热或正在转换的波形。

NORMAL至少具有RED和IR两个逻辑波形上下文槽，使IR接管不依赖RED ADC owner释放。校准使用单独一槽且不得与NORMAL槽同时活动。波形槽只保存模拟解释，不等价于ADC结果owner。

### 5.2 接管点和预热前锁存

调度器只有在下列固定点、完整波形载荷有效且wrapper无阻断故障时，才允许形成`waveform_context_fire`：

| 事务 | 接管点 | 首个模拟边沿 | Q3中心 |
| --- | ---: | ---: | ---: |
| NORMAL RED | macro tick 0 | 依精度为27或44 | 300 |
| NORMAL IR | macro tick 160 | 依精度为187或204 | 460 |
| AMB_CAL | calibration local tick 0 | 10 | 266 |
| DCS_CAL RED | calibration local tick 0 | 10 | 266 |
| DCS_CAL IR | calibration local tick 0 | 10 | 266 |

任何波形上下文若未在表中接管点真实握手，wrapper不得开始该次模拟波形，也不得以迟到握手移动Q3。AMI是否ready不参与本通道接管资格。

校准子帧只有在候选码、AMB码、颜色、类型和epoch均已在local tick 0锁存时，才取得本轮8个物理容量之一的预建立资格；只有随后在local tick 248截止前真实提交ADC owner，才计为一笔有效SAR9转换样本。

### 5.3 ADC结果owner原子提交

波形接管后，wrapper依据第4.5节截止范围和当前owner状态独立产生`o_adc_owner_ready`。唯一owner提交为：

```text
i_adc_owner_commit_event && o_adc_owner_ready
```

owner-pending选择严格遵循波形fire顺序：NORMAL固定RED后IR，校准只有一个槽。`o_adc_owner_ready`始终只表示最早尚未提交owner的有效波形槽；不得跳过RED直接选择IR。RED在deadline 283失败并失效后，IR才成为最早pending项。

提交沿必须同时锁存`i_adc_owner_sample_index`，并把owner identity中的`precision_mode/frame_id/color_ir/frame_type/AMB code/DC code/AMB epoch/DC epoch`与最早pending波形快照逐位比较。sample index在该沿首次正式绑定，模拟波形上下文不预先携带或预约它。owner identity不匹配时拒绝提交并置协议sticky。owner提交不得重新锁存或改变模拟码值、epoch、颜色、精度和Q3；这些字段只能来自早先的波形快照。

任一时刻最多只有一个ADC结果owner。owner提交后的物理释放条件冻结为：

```text
owner_release =
    i_adc_transaction_complete_event
 && i_adc_complete_sample_index == current_owner_sample_index
```

匹配完成事件无论`i_adc_transaction_success`为1还是0都必须释放当前物理owner。`success=1`允许本笔结果进入对应NORMAL或校准成功处理；`success=0`只执行owner释放和失败收尾，不得开放IDAC结果消费、颜色成功、校准成功或正式测量资格。sample index错配或当前无owner时不得释放任何owner，并置身份错配或阻断协议诊断。Q3结束、模拟包络末沿、固定延时或`i_adc_idle`不得释放owner。

### 5.4 IDAC候选码提交

快速校准中：

```text
当前子帧CAL_IDAC_COMMIT_TICK = 385
    -> AMI/IDAC控制器允许提交下一子帧候选码

下一子帧local tick 0
    -> wrapper锁存已提交码与epoch

下一子帧local tick 10
    -> 开始模拟预热
```

候选码不得在本轮预热、Q3、转换或RAW捕获期间改变。首个校准子帧的候选码必须在校准宏帧进入前已经准备好；否则该子帧不启动且不计入8次容量。

若当前结果未能在local tick 385前支持下一候选码准备，IDAC控制器必须报告阶段失败。wrapper不得复用旧码并将其标记为新的搜索样本。

### 5.5 三种校准模拟组合

| 校准类型 | LED | AMB IDAC | DC IDAC | DC码选择 |
| --- | --- | --- | --- | --- |
| AMB_CAL | RED、IR均关闭 | 当前AMB候选码有效 | 关闭 | 固定中性码`8'h00` |
| DCS_CAL RED | 仅RED按SAR9窗口导通 | 已确认AMB committed码有效 | SAR9 DC有效 | 当前DC_R候选码 |
| DCS_CAL IR | 仅IR按SAR9窗口导通 | 已确认AMB committed码有效 | SAR9 DC有效 | 当前DC_IR候选码 |

AMB_CAL采用暗态环境光采样：LED关闭但TIA、SAR9、必要的Q1/Q3和AMB支路仍按校准SAR9包络工作；Q2自V1.5起在AMB_CAL全程保持`0`，不参与本次积分（第6.4节）。

AMB_CAL的DC使能必须关闭，且DC码输出固定为`8'h00`。DCS_CAL的AMB码必须是已确认并提交的结果；AMB搜索失败时，调度器不得进入DCS_CAL RED或DCS_CAL IR。

## 6. AMB_CAL专用SAR9波形

### 6.1 原始netlist到local tick的换算

AMB专用Spectre netlist中的pulse`delay`和`width`以`CLK_Q3_LOW`中心为参考。数字时钟为2 MHz，即每个tick为0.5 us；`CAL_Q3_TICK=266`。下表是唯一有效的数字控制窗口，均采用左闭右开区间`[start,end)`。

| 输出 | AMB_CAL local tick有效窗口 | 数字载荷规则 |
| --- | --- | --- |
| `o_clk_iref_idac_sar9_low` | `[10,284)` | 固定波形电平 |
| `o_en_sar9_iref` | `[202,274)` | 固定波形电平 |
| `o_en_sar9_amb_low` | `[222,276)` | 固定波形电平 |
| `o_idac_sar9ambn_low[7:0]` | `[224,276)` | 预热前锁存的AMB候选码；各bit分别取该码对应bit |
| `o_clk_iref_idac_low` | `[229,269)` | 固定波形电平 |
| `o_clk_aferst_low` | `[249,261)` | 固定波形电平 |
| `o_clk_tiaen_low` | `[249,269)` | 固定波形电平 |
| `o_clk_9q1_low` | `[259,268)` | 固定波形电平 |
| `o_clk_q2_low` | 全程`0` | V1.5起AMB_CAL不再驱动Q2，见第6.4节；不是本表窗口之外规则的特例，是该输出在AMB_CAL帧类型下的唯一取值 |
| `o_clk_q3_low` | `[265,267)` | 固定波形电平，中心为266，不受第6.4节影响 |
| `o_en_tia_low` | 始终`0` | 原始netlist静态`dc=0` |

窗口之外，表中所有脉冲输出必须为`0`。`o_clk_buf_low`、`o_clk_15q1_low`、`o_clk_iref_idac_sar15_low`、`o_en_15sar_low`、`o_en_sar15_amb_low`、`o_en_sar15_dc_low`和`o_en_sar15_iref`在AMB_CAL全子帧保持`0`。`o_en_sar9_dc_low`、`o_idac_sar9dcn_low[7:0]`、`o_idac_sar15ambn_low[7:0]`和`o_idac_sar15dcn_low[7:0]`在AMB_CAL全子帧保持`0`。

### 6.2 AMB输入、LED与载荷边界

AMB_CAL使用光电二极管输入语义，因此`o_en_test=0`。RED和IR LED始终关闭，`o_leden1_low=0`、`o_leden2_low=0`，且`o_leddac[7:0]=8'h00`。这些规则来自用户确认的工作语义；不得把netlist中的测试MUX仿真激励或信号名称当作相反的电气极性证据。

AMB候选码、AMB码epoch、事务类型和颜色身份必须在local tick 0的真实`waveform_context_fire`时原子锁存。`o_idac_sar9ambn_low[7:0]`仅在第6.1节窗口内呈现该锁存码，窗口外为`8'h00`。候选码不是固定`8'hFF`，也不得在本子帧中途因SPI、CDC或IDAC更新改变。

### 6.3 不可改变的校准边界

AMB专用波形不得改变以下已冻结规则：

```text
625-tick校准子帧长度
CAL_CONTEXT_LATCH_TICK=0
CAL_Q3_TICK=266
CAL_WAVE_START_TICK=10
CAL_WAVE_END_TICK=284
CAL_IDAC_COMMIT_TICK=385
预热前码值快照规则
wrapper外部端口、握手和诊断语义
```

### 6.4 AMB_CAL单相积分改造（2026-09-10）

**真实发现：** AMB码值校准（`ppg_idac_code_controller.v`的`ST_AMB_WAIT`/`ST_AMB_RECHECK`）依据Q2/Q3两相chopping抵消之后的净值判断候选码好不好。但chopping抵消机制本身对"两相里都存在的对称环境光残余"是结构性不敏感的：只要没有真正物理clip到轨，残余无论多大，净值都趋近于`0`。这意味着现有判据看不出AMB候选码实际用掉了积分器多少线性余量，只能抓到已经硬饱和之后的情况。DCS_CAL不受这个问题影响，因为DCS_CAL的LED只在Q3打开、Q2/Q3本就不对称，chopping相减对DCS恰恰是完整保留LED残余信号，不是掩盖它。

**改造内容：** `ppg_sar9_sar15_safe_selection_wrapper.v`V1.5起，在AMB_CAL（`reg_cal_frame_type==FRAME_TYPE_AMB`）期间抑制`CTRL_Q2`（`o_clk_q2_low`），使其在原`[262,264)`窗口也保持`0`，AMB_CAL全程不产生Q2脉冲；`CTRL_Q3`（`o_clk_q3_low`）的`[265,267)`窗口原样不动。DCS_CAL的`CTRL_Q2`/`CTRL_Q3`行为完全不变。改造后，流入`i_amb_threshold_low/high`判据的原始数值物理意义从"两相净值"变成"单相原始摆幅"，能直接反映积分器线性余量；判据逻辑、阈值端口、config传播路径本身均未新增或改动——`ppg_idac_code_controller.v:95-98`早已存在完全独立、各自可配置的`i_amb_threshold_low/high`和`i_dcs_threshold_low/high`四个窗口端口，:425-437行的判据本来就按`flag_expect_amb_sample`分别比较，这次只是让流进这套既有判据的原始数值物理意义改变。

**交叉核对结论（开工前已核实，非事后声明）：** 第6.1节`CTRL_AFERST`/`CTRL_TIAEN`/`CTRL_Q1_9`时序窗口（`[249,261)`/`[249,269)`/`[259,268)`）与`calibration_wave_active_o`（`[10,284)`）、`flag_cal_context_point`、`flag_cal_q3_end_passed`（`local tick>=267`）均按各自独立的tick比较表达，不隐含"Q2必须产生脉冲"这一前提；抑制Q2不改变这些窗口的时长或触发条件。

**影响范围：** 仅AMB_CAL一种帧类型下`CTRL_Q2`/`o_clk_q2_low`一项输出的取值；不影响DCS_CAL、NORMAL、STATIC_BIAS任何波形；不新增端口、不新增判据逻辑、不改变config传播链路；`i_amb_threshold_low/high`的具体标定数值本身不在本次改造范围内，留待有真实硅片特性数据后再定（见`PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md`对应新增说明）。

## 7. Wrapper逐端口接口

### 7.1 参数

| 参数 | 默认值 | 含义 |
| --- | ---: | --- |
| `C_FRAME_ID_WIDTH` | 16 | 物理400 Hz帧号宽度 |
| `C_SAMPLE_INDEX_WIDTH` | 16 | 全局ADC事务序号宽度 |
| `C_IDAC_CODE_WIDTH` | 8 | AMB/DC IDAC码宽度 |
| `C_CODE_EPOCH_WIDTH` | 4 | IDAC committed码版本宽度 |
| `C_RUN_GENERATION_WIDTH` | 8 | manager唯一生产、经ACTIVE wrapper与Top透明扇出的RUN代际宽度 |
| `C_MACRO_TICK_WIDTH` | 13 | `0..4999`宏帧相位宽度 |
| `C_CAL_TICK_WIDTH` | 10 | `0..624`校准局部相位宽度 |
| `C_NORMAL_RED_OWNER_DEADLINE` | 283 | RED ADC owner最晚提交tick |
| `C_NORMAL_IR_OWNER_DEADLINE` | 443 | IR ADC owner最晚提交tick |
| `C_CAL_OWNER_DEADLINE` | 248 | 校准ADC owner最晚提交local tick |

### 7.2 全局、生命周期和相位输入

| 端口 | 宽度 | 来源 | 语义 |
| --- | ---: | --- | --- |
| `i_clk` | 1 | 系统 | 2 MHz唯一数字时钟 |
| `i_rstn` | 1 | 系统 | 低有效异步复位 |
| `i_run_enable` | 1 | 配置管理器 | RUN期间为1 |
| `i_start_ack_event` | 1 | 配置管理器 | 新RUN接受单拍 |
| `i_stop_ack_event` | 1 | 配置管理器 | STOP接受单拍 |
| `i_control_abort_event` | 1 | 系统 | 立即撤销单拍 |
| `i_diag_clear_event` | 1 | 软件 | 安全空闲时清sticky单拍 |
| `i_run_generation` | `C_RUN_GENERATION_WIDTH` | manager经ACTIVE wrapper与Top扇出 | 波形和物理owner上下文锁存的唯一RUN代际；陈旧代际不得释放owner或复活波形 |
| `i_macro_tick` | `C_MACRO_TICK_WIDTH` | 调度器 | 唯一400 Hz相位 |
| `i_calibration_subframe_index` | 3 | 调度器 | 当前0..7子帧编号 |
| `i_calibration_local_tick` | `C_CAL_TICK_WIDTH` | 调度器V1.3 | 当前0..624子帧相位 |
| `i_normal_frame_active` | 1 | 调度器 | 当前宏帧属于NORMAL |
| `i_calibration_frame_active` | 1 | 调度器 | 当前宏帧属于快速校准 |
| `i_macro_frame_safe_boundary` | 1 | 调度器 | 宏帧安全接管边界 |
| `i_idac_code_safe_boundary` | 1 | 调度器 | 下一候选码唯一提交边界 |

`i_normal_frame_active`与`i_calibration_frame_active`不得同时为1；两者同时为0仅允许空闲、安全关闭、STOP排空或STATIC_BIAS。固定电流CHARACTERIZATION仍是400 Hz NORMAL事务，因此必须使用`i_normal_frame_active=1`。

### 7.3 配置、精度和模拟静态控制输入

| 端口 | 宽度 | 来源 | 语义 |
| --- | ---: | --- | --- |
| `i_run_profile` | 1 | ACTIVE V4解包 | NORMAL_PPG或CHARACTERIZATION |
| `i_input_source` | 1 | ACTIVE V4解包 | `0`为光电二极管输入，`1`为外部固定电流输入 |
| `i_optical_mode` | 2 | ACTIVE V4解包 | 双光、单光或安全关闭 |
| `i_precision_mode_committed` | 1 | 精度窗口控制器 | 当前已提交SAR选择 |
| `i_static_characterization_enable` | 1 | 独立已提交控制 | 静态表征覆盖使能 |
| `i_test_mux_ctrl` | 5 | 独立CDC已提交控制 | 仅STATIC_BIAS期间驱动`S[4:0]`的测试MUX码 |

`i_test_mode`以及`i_static_sar9_amb_code`、`i_static_sar9_dc_code`、`i_static_sar15_amb_code`、`i_static_sar15_dc_code`不是V1.3端口：前者不能定义`EN_TEST`，后四者不能覆盖STATIC_BIAS原始零码向量。独立LEDDAC码先由调度器在波形通道中选择并快照，SSW不再直接读取`i_leddac_r_code/i_leddac_ir_code`实时值。

上述独立控制不得读取V4保留位。`i_test_mux_ctrl`必须经独立SPI shadow、CDC提交和2 MHz同沿锁存；后续若纳入ACTIVE配置，必须单独修订配置合同、配置管理器、解包器和本合同。

### 7.4 调度器模拟波形上下文输入

| 端口 | 宽度 | 方向 | 语义 |
| --- | ---: | --- | --- |
| `i_waveform_context_valid` | 1 | 输入 | 调度器保持型模拟波形载荷有效 |
| `o_waveform_context_ready` | 1 | 输出 | 仅固定波形接管点且目标槽可用时接受 |
| `i_waveform_precision_mode` | 1 | 输入 | 本次波形SAR9/SAR15快照 |
| `i_waveform_frame_id` | `C_FRAME_ID_WIDTH` | 输入 | 本次波形物理帧号 |
| `i_waveform_color_ir` | 1 | 输入 | 本次波形颜色身份 |
| `i_waveform_frame_type` | 2 | 输入 | AMB_CAL、DCS_CAL或NORMAL |
| `i_waveform_amb_code_snapshot` | `C_IDAC_CODE_WIDTH` | 输入 | 预热前冻结AMB码 |
| `i_waveform_dc_code_snapshot` | `C_IDAC_CODE_WIDTH` | 输入 | 预热前冻结颜色DC码 |
| `i_waveform_amb_code_epoch` | `C_CODE_EPOCH_WIDTH` | 输入 | AMB码版本 |
| `i_waveform_dc_code_epoch` | `C_CODE_EPOCH_WIDTH` | 输入 | 颜色DC码版本 |
| `i_waveform_input_source` | 1 | 输入 | 光电二极管或外部固定电流快照 |
| `i_waveform_optical_mode` | 2 | 输入 | 本宏帧光学模式快照 |
| `i_waveform_leddac_code_snapshot` | 8 | 输入 | 当前颜色已提交LEDDAC码快照 |

```text
waveform_context_fire =
    i_waveform_context_valid && o_waveform_context_ready
```

该fire必须发生在第5.2节固定接管点。wrapper不得把单独的valid、ready、owner提交或相位到达误认为波形已接管。

### 7.5 ADC结果owner提交接口

| 端口 | 宽度 | 来源 | 语义 |
| --- | ---: | --- | --- |
| `o_adc_owner_ready` | 1 | SSW | 匹配波形存在、owner空闲、未过截止点且生命周期合法 |
| `i_adc_owner_commit_event` | 1 | 调度器 | 与AMI transaction fire同拍的owner提交单拍 |
| `i_adc_owner_precision_mode` | 1 | 调度器 | AMI事务精度，必须匹配波形快照 |
| `i_adc_owner_frame_id` | `C_FRAME_ID_WIDTH` | 调度器 | AMI事务帧号，必须匹配波形快照 |
| `i_adc_owner_color_ir` | 1 | 调度器 | AMI事务颜色，必须匹配波形快照 |
| `i_adc_owner_frame_type` | 2 | 调度器 | AMI事务类型，必须匹配波形快照 |
| `i_adc_owner_amb_code_snapshot` | `C_IDAC_CODE_WIDTH` | 调度器 | AMI事务AMB码，必须匹配波形快照 |
| `i_adc_owner_dc_code_snapshot` | `C_IDAC_CODE_WIDTH` | 调度器 | AMI事务颜色DC码，必须匹配波形快照 |
| `i_adc_owner_amb_code_epoch` | `C_CODE_EPOCH_WIDTH` | 调度器 | AMI事务AMB版本，必须匹配波形快照 |
| `i_adc_owner_dc_code_epoch` | `C_CODE_EPOCH_WIDTH` | 调度器 | AMI事务DC版本，必须匹配波形快照 |
| `i_adc_owner_sample_index` | `C_SAMPLE_INDEX_WIDTH` | 调度器 | 本次fire首次正式绑定的AMI sample index |

`o_adc_owner_ready`不得依赖AMI valid/ready或owner identity实时值，不得通过调度器形成组合环。`i_adc_owner_commit_event`在ready为0或identity不匹配时到达属于阻断协议错误，不得建立owner或开放转换资格。

### 7.6 ADC完成与空闲输入

| 端口 | 宽度 | 来源 | 语义 |
| --- | ---: | --- | --- |
| `i_adc_transaction_complete_event` | 1 | AMI数字捕获链 | 已同步RAW已被事务处理链接纳的完成单拍 |
| `i_adc_transaction_success` | 1 | AMI数字捕获链 | 本笔完成处理资格；0仍释放匹配owner，但禁止进入IDAC或NORMAL处理 |
| `i_adc_complete_sample_index` | `C_SAMPLE_INDEX_WIDTH` | AMI数字捕获链 | 已完成事务身份 |
| `i_adc_idle` | 1 | Top `flag_adc_physical_idle` | 物理ADC转换与Stage1/Stage2 DONE/CLK_DOUT返回均非活动的同步事实；不是AMI completion、数字排空或owner-release事件 |

`i_adc_transaction_complete_event`不得由Q3结束、SAR控制波形末沿或wrapper内部计数伪造。它必须来自`CLK_DOUT`完成后两级同步、RAW锁存和事务归属完成的数字链。

### 7.7 模拟输出

wrapper输出是唯一允许连接至模拟顶层的时序控制源：

```text
o_en_tia_low
o_leddac[7:0]
o_leden1_low
o_leden2_low
o_en_test
o_clk_buf_low
o_clk_2m
o_clk_iref_idac_low
o_clk_9q1_low
o_clk_15q1_low
o_clk_aferst_low
o_clk_iref_idac_sar9_low
o_clk_iref_idac_sar15_low
o_clk_q2_low
o_clk_q3_low
o_clk_tiaen_low
o_en_15sar_low
o_en_sar9_amb_low
o_en_sar9_dc_low
o_en_sar9_iref
o_en_sar15_amb_low
o_en_sar15_dc_low
o_en_sar15_iref
o_idac_sar9ambn_low[7:0]
o_idac_sar9dcn_low[7:0]
o_idac_sar15ambn_low[7:0]
o_idac_sar15dcn_low[7:0]
o_s_in[4:0]
```

`o_clk_2m`保持对`i_clk`的相位转发，不作为wrapper内部门控时钟。已从活动SAR时序接口删除的`o_clk_iref_led_low`不得重新引入本wrapper、顶层或约束。

四组`o_idac_*[7:0]`必须严格执行第4.7节的逐bit公式和精度隔离矩阵。当前精度对应的AMB/DC码总线也只能在各自netlist码窗内输出快照；未选精度两组总线不得因为共用内部控制向量、代码字段复用或对应模拟使能为0而产生任何翻转。

`o_en_test`不是任意测试开关：NORMAL光电二极管和AMB_CAL为`0`；外部固定电流表征和STATIC_BIAS为`1`。`o_s_in[4:0]`仅在STATIC_BIAS输出已提交的`i_test_mux_ctrl`；其余所有运行状态均为`5'b0`。

### 7.8 状态与诊断输出

| 端口 | 语义 |
| --- | --- |
| `o_analog_safe` | 当前所有活动波形槽的模拟控制向量均处于允许停止/切换状态 |
| `o_sar_timing_idle` | 无RED/IR/CAL预建立、无Q1/Q2/Q3窗口、无待完成安全切换；不等待数字链结果 |
| `o_wrapper_idle` | `o_sar_timing_idle && i_adc_idle`且无波形槽、owner-pending或已提交owner |
| `o_precision_active` | 当前实际驱动模拟输出的SAR9/SAR15选择 |
| `o_calibration_wave_active` | 当前处于625-tick校准模拟包络 |
| `o_adc_owner_inflight` | 当前存在一笔已提交、等待真实数字完成的ADC结果owner |
| `o_switch_protocol_error_sticky` | 非法接管点、双模式同时活动或事务载荷非法 |
| `o_transaction_mismatch_sticky` | ADC完成的sample_index与在途事务不一致 |
| `o_owner_deadline_timeout_sticky` | 波形已接管但ADC owner未在冻结截止点前提交 |
| `o_calibration_timeout_sticky` | 校准结果未能在下一候选码准备截止前完成 |
| `o_wrapper_fault_blocking` | 活动根因、协议错误或无法确认归属的错配汇总，阻止调度器启动新owner |
| `o_ssw_fault_valid` | 给supervisor的注册一周期blocking-fault记录有效位；cause和identity在该周期稳定 |
| `o_ssw_fault_active` | 未解决SSW blocking cause的注册状态；只在安全恢复谓词成立或复位后撤销 |
| `o_ssw_fault_cause` | 8-bit固定SSW blocking cause编码 |
| `o_ssw_fault_identity_valid`和完整fault identity | identity有效时原子携带完整事务身份；无效时每个身份字段为0 |

`o_owner_deadline_timeout_sticky`和安全收尾完成后的单次校准超时只作为历史诊断，不单独永久拉高`o_wrapper_fault_blocking`。owner deadline timeout本身绝不产生supervisor fault record、abort、system STOP、first-fault snapshot或cause `8'h22`。只有独立检测到“模拟安全状态不确定或无法收敛到合同定义安全状态”时，SSW才以独立的analog-safe protocol error（固定cause `8'h22`）成为活动阻断根因；该记录不得由timeout sticky推导。非法commit、identity mismatch、无法归属的DONE或该独立模拟安全错误必须保持阻断，直到STOP/abort/reset或合同允许的空闲诊断清除。

### 7.9 generation and supervisor-fault semantics

SSW receives `i_run_generation[C_RUN_GENERATION_WIDTH-1:0]` with each waveform
and physical-owner context and returns it unchanged with owner/completion
identity. A stale generation cannot release an owner, revive a waveform or
become a new transaction. The port-table name `i_adc_idle` is mapped only from
Top `flag_adc_physical_idle`; `i_adc_physical_idle` is not a second SSW port.
This synchronized physical-idle fact never substitutes for AMI completion or a
fixed delay.

SSW exposes `o_ssw_fault_valid`, `o_ssw_fault_active`,
`o_ssw_fault_cause[7:0]`, `o_ssw_fault_identity_valid` and full ID to the
supervisor. Valid is exactly one registered 2 MHz cycle and the associated
cause/ID is stable then; identity-invalid fields are zero. Only blocking
identity/owner or analog-safe protocol errors emit this record. Waveform-launch
and owner-deadline timeout remain non-blocking historical diagnostics.
`o_ssw_fault_active` falls only when the documented waveform/owner-safe
recovery predicate is true or reset occurs. A diagnostic clear cannot directly
release the physical owner.

### 7.9a cause `8'h22`（独立模拟安全收敛检测器）适用性冻结决策（2026-09-05）

本模块V1.4版本自身changelog（见`ppg_sar9_sar15_safe_selection_wrapper.v`第48行）明确记录：cause `8'h22`（独立模拟安全收敛检测器）本次未实现，原文为"合同未给出具体触发条件，本次也未设计新的检测逻辑"。第7.8节末段（"只有独立检测到……才成为活动阻断根因"）描述的正是这条尚未落地的规则。上述原文均予以保留，不删除、不改写；本节新增的是对该开放项的正式冻结决策，性质与`ppg_system_config_manager_semantic_contract.md`的D02冻结决策同类——由确认结论关闭一个product/architecture层面的悬而未决项，而不是先前误判为"定义还没想清楚"。

**决策：确认cause `8'h22`在本芯片当前模拟实现下不适用，不是有待补齐的空白。** 依据如下两条真实代码证据加上芯片设计者确认：

1. `i_analog_ready`是真实的芯片顶层边界输入端口（`ppg_control_top.v:120`，注释"已同步模拟偏置/参考/输入选择RUN启动资格聚合结果，仅送wrapper"），确属芯片外部模拟域信号，不是数字RTL内部生成的判定结果。但该信号本身只是一次性聚合的启动资格电平，不携带任何"收敛过程"的时间维度信息。
2. `o_analog_safe`（本模块自身输出，`ppg_sar9_sar15_safe_selection_wrapper.v:480`：`assign o_analog_safe = !(flag_red_wave_active || flag_ir_wave_active || calibration_wave_active_o);`）根本不是模拟信号：它是SSW内部"当前有没有在驱动RED/IR/校准波形"这一纯数字时序控制状态（`flag_red_wave_active`/`flag_ir_wave_active`/`calibration_wave_active_o`均由`i_macro_tick`/`i_calibration_local_tick`节拍比较得出，见第400-402行）的取反。历史命名带有"analog"字样容易让人误以为它反映模拟电路本身的安全状态，但它与真实模拟电路是否收敛完全无关；跨合同下游消费者（C01/C03/C08/C23等）收到的`i_analog_safe`实际转发的正是这个数字取反结果，而非任何模拟收敛测量。
3. 本项目模拟部分的芯片设计者本人确认：这是一颗实验室测试芯片，不是量产产品芯片；偏置电路是直接硬连接好的，不存在充电泵爬升、带隙基准慢速建立、校准环路收敛这类需要时间稳定的动态物理过程。

综合以上三点：cause `8'h22`原本想要独立验证的"模拟安全状态是否收敛"这一物理现象，在本芯片当前的真实模拟实现里根本不存在可供检测的对象——`i_analog_ready`虽是真实模拟边界信号但只是一次性资格电平，没有真实收敛行为可查；`o_analog_safe`/`i_analog_safe`从一开始就是SSW内部数字波形驱动状态的取反，不是模拟反馈。这是一个经芯片设计者确认、可永久结案的正式决策，不是继续悬着等待外部输入的空白定义。

**本决策的范围：** 仅关闭"cause `8'h22`该不该实现"这一个product/architecture决策缺口（对应`PPG_CONTRACT_CLOSURE_MATRIX.md`第12.12节"Real remaining defects"清单第2条，以及第12.7节G-FP-03对应行）。不改变`o_ssw_fault_cause`当前只映射`8'h21`（`switch_protocol_error`/`transaction_mismatch`两个sticky）的既有编码；不新增RTL检测逻辑；不改变第7.8节、第7.9节任何既有条款的行为或措辞。SSW-01至SSW-52任何既有编号条款不受影响。

## 8. 安全选择、STOP与撤销

### 8.1 先断后通

精度、校准类型或颜色通道变更仅允许在第5.2节接管点发生。wrapper必须：

```text
固定波形接管点锁存新上下文
    -> 对旧时序输出保持或安全关闭
    -> 至少一个2 MHz注册边沿不存在两个时序模板同时驱动
    -> 新模板按其固定WAVE_START进入预建立
```

禁止组合MUX直接在`i_precision_mode_committed`变化的同一拍切换模拟输出。所有模拟控制输出必须来自单一寄存后的完整控制向量。

### 8.2 STOP

`i_stop_ack_event`到达后：

```text
禁止新的o_waveform_context_ready和o_adc_owner_ready
-> 已开始模拟包络允许运行至其既定安全末沿
-> o_analog_safe置1
-> 已接管但未提交owner的波形不得产生新的Q1/Q2/Q3有效采样
-> 已提交owner标记为discard-pending并保留原始identity；真实DONE只能由AMI以原身份`success=0`完成旁带释放
-> 等待i_adc_idle
-> o_wrapper_idle置1
```

STOP不允许强制在Q1/Q2/Q3中间组合切换精度或颜色。

### 8.3 control_abort与复位

`i_control_abort_event`到达时：

```text
撤销全部未提交波形上下文槽和owner-pending
-> 已提交owner标记为受控丢弃
-> 仅保留原始sample index作为最小释放身份
-> 下一个可见控制更新将所有可撤销模拟控制置为活动SAR核i_enable=0的安全向量
-> 匹配完成旁带释放旧物理owner，但不得恢复旧波形或有效结果
-> 所有待启动预约失效
```

abort后的AMI匹配迟到完成应携带`success=0`。wrapper仍按第5.3节公式释放旧物理owner；如果异常收到匹配`success=1`，也必须释放物理owner，但该结果仍按丢弃处理并置协议诊断。释放前不得把旧owner身份重新分配给新事务。

`i_rstn=0`时立即清除波形槽、owner-pending、已提交数字owner及其释放身份，并把可撤销模拟控制置为复位安全向量。复位后旧DONE无法恢复合法身份，不得产生完成旁带或释放任何新owner；系统只能等待物理`i_adc_idle`重新建立后开始新的RUN。

### 8.4 CHARACTERIZATION固定精度测量

CHARACTERIZATION的非STATIC_BIAS测量只允许以下两类输入源和运行资格：

| 输入源 | 合法光学模式 | 合法精度 | `EN_TEST` | IDAC策略 |
| --- | --- | --- | ---: | --- |
| `PHOTODIODE` | `RED_ONLY` | 固定SAR9或固定SAR15 | `0` | `MANUAL` |
| `EXTERNAL_TEST_CURRENT` | `BOTH`、`RED_ONLY`或`IR_ONLY` | 固定SAR9或固定SAR15 | `1` | `MANUAL` |

外部固定电流三种合法模式均冻结为`LEDEN=0`、`LEDDAC=0`；在本wrapper端口上对应
`o_leden1_low=0`、`o_leden2_low=0`和`o_leddac[7:0]=8'h00`，不得因为`BOTH`、`RED_ONLY`
或`IR_ONLY`而重新打开任一路LED。

两类模式在整个RUN期间均不得自动执行AMB/DCS搜索、NORMAL慢速IDAC跟踪或SAR9/SAR15精度切换；AMB/DC码只能来自已提交的MANUAL配置，并在对应波形预热开始前锁存。

#### 8.4.1 光电二极管纯RED固定SAR测量

以下组合是合法的CHARACTERIZATION模式：

```text
i_run_profile       = CHARACTERIZATION
i_static_characterization_enable = 0
i_input_source      = PHOTODIODE
i_optical_mode      = RED_ONLY
i_precision_mode_committed = SAR9 或 SAR15
i_idac_mode         = MANUAL
```

该模式的物理资格冻结为：

1. RED波形上下文仍在`macro_tick=0`接管；
2. IR波形、IR LEDEN、IR ADC owner和IR有效IDAC码窗在整个RUN期间关闭；
3. SAR9和SAR15的RED Q3中心均为`macro_tick=300`；
4. SAR9 RED预热严格使用netlist区间`[44,318)`，SAR15 RED预热严格使用netlist区间`[27,308)`；不得用统一包络替代各自区间；
5. MANUAL AMB码和RED DC码必须在各自预热开始前锁存，当前宏帧中途的实时码、pending码、SPI shadow或epoch变化不得改变本帧输出；
6. `sample_index`和ADC owner仍按真实RED事务提交推进，固定精度模式不得触发精度窗口切换。

因此，纯RED光电二极管固定SAR9和固定SAR15均复用既有RED物理波形，不改变接管点、Q3位置或netlist预热长度；区别只在启动资格和整个RUN的固定精度约束。

#### 8.4.2 固定电流CHARACTERIZATION测量

固定电流表征的进入条件为：

```text
i_run_profile = CHARACTERIZATION
i_static_characterization_enable = 0
i_input_source = 1
i_optical_mode = BOTH / RED_ONLY / IR_ONLY
```

该模式仍是正常400 Hz间歇SAR9或SAR15测量，而不是STATIC_BIAS，也不是3200 Hz快速校准：

1. `BOTH`按RED后IR顺序产生两笔测量事务，RED接管`macro_tick=0`、IR接管`macro_tick=160`；`RED_ONLY`只产生RED事务，`IR_ONLY`只产生IR事务；各自Q3中心仍为RED=300、IR=460；
2. 允许调度器按NORMAL宏帧规则发出波形上下文，并按固定接管点完成预热和独立ADC owner提交；
3. `o_en_test=1`在整个RUN稳定保持；
4. 已提交精度在START快照后固定，禁止自动精度窗口切换；
5. `o_leden1_low=0`、`o_leden2_low=0`和`o_leddac[7:0]=8'h00`，不产生LED驱动窗口；
6. `o_s_in=5'b0`；
7. 本笔SAR所需AMB/DC和LEDDAC数字码只能来自已握手波形快照及其epoch，不得来自未提交SPI shadow或遗留静态码端口；
8. 拒绝AMB_CAL、DCS_CAL、自动IDAC搜索和快速3200 Hz校准事务。

`optical_mode`只选择测量颜色、事务数量和对应SAR/ADC波形时序，不重新打开LED。`optical_mode=OFF`
不属于固定电流测量资格；到达SSW时必须保持安全关闭，不发布波形上下文、ADC owner或有效IDAC总线。

`i_input_source=1`与`i_static_characterization_enable=0`以外的CHARACTERIZATION组合不得伪装为固定电流SAR测量。

实际校准事务的主要资格所有者是RUN期间的AMI请求源门控和Scheduler接收门控。SSW仍必须对异常到达的CHARACTERIZATION校准、外部固定电流校准、非法frame type或SAR15校准上下文执行防御性安全拒绝，但该隔离不能替代Scheduler/AMI资格检查，也不得把请求反馈给配置管理器预测未来校准。

### 8.5 STATIC_BIAS

STATIC_BIAS进入条件为：

```text
i_run_profile = CHARACTERIZATION
i_static_characterization_enable = 1
i_input_source = 1
```

`STATIC_BIAS + input_source=0`是非法配置，必须在进入静态状态前拒绝。非法配置不得发布
`o_waveform_context_ready`、`o_adc_owner_ready`或任何有效IDAC码总线，也不得启动LED、SAR或ADC。

合法STATIC_BIAS不接收NORMAL、AMB_CAL或DCS_CAL波形上下文，不给出ADC owner ready，不运行任何Q1/Q2/Q3、SAR或ADC完成归属，也不推进400 Hz事务状态。wrapper必须直接输出下列Spectre netlist原始静态逻辑向量；`1`对应原始`dc=1.2`，`0`对应原始`dc=0`，不从端口名称推断电气极性。

| 输出 | STATIC_BIAS值 |
| --- | ---: |
| `o_en_test` | `1` |
| `o_clk_buf_low` | `1` |
| `o_clk_iref_idac_low` | `1` |
| `o_clk_iref_idac_sar9_low` | `1` |
| `o_clk_iref_idac_sar15_low` | `1` |
| `o_clk_aferst_low` | `1` |
| `o_clk_tiaen_low` | `1` |
| `o_en_sar9_amb_low` | `1` |
| `o_en_sar9_dc_low` | `1` |
| `o_en_sar15_amb_low` | `1` |
| `o_en_sar15_dc_low` | `1` |
| `o_en_tia_low` | `0` |
| `o_en_sar9_iref` | `0` |
| `o_en_sar15_iref` | `0` |
| `o_clk_9q1_low` | `0` |
| `o_clk_15q1_low` | `0` |
| `o_clk_q2_low` | `0` |
| `o_clk_q3_low` | `0` |
| `o_en_15sar_low` | `0` |
| `o_leddac[7:0]` | `8'h00` |
| `o_leden1_low` | `0` |
| `o_leden2_low` | `0` |
| 四组`o_idac_*[7:0]` | `8'h00` |

`o_s_in[4:0]`是该向量唯一的可变成员，输出经CDC已提交的`i_test_mux_ctrl`。只允许在STATIC_BIAS保持期间通过独立`static_test_commit_event`原子更新；五位必须同一2 MHz时钟沿可见。NORMAL、固定电流和全部校准状态均隔离该更新，并强制`o_s_in=5'b0`。

## 9. V1.3.2实现状态与联合验证范围

调度器V1.3与本合同V1.3.2保持相同的端口名、方向、位宽、接管点和owner截止点。既有SSW-01至SSW-48回归范围在本小版本中增加纯RED光电二极管固定SAR9/SAR15资格、外部固定电流`BOTH/RED_ONLY/IR_ONLY`模式和非法配置安全输出检查；不改变既有owner、Q3或四组IDAC总线隔离语义。旧V1.2单fire端口不得作为兼容别名保留。

其中，SSW-45至SSW-48明确验证四组IDAC数据总线实现结果：SAR9事务中仅SAR9 AMB/DC总线允许按锁存码和netlist码窗逐bit工作；SAR15事务中仅SAR15 AMB/DC总线允许按锁存码和netlist码窗逐bit工作；AMB_CAL仅SAR9 AMB候选码总线工作；STATIC_BIAS四组总线均为`8'h00`。未选精度数据总线逐tick保持`8'h00`，不得以“模拟通路未使能”替代总线精度隔离证明。

SSW的独立回归不能替代调度器、SSW和AMI的真实三模块联合TB。联合TB仍须证明独立波形上下文与ADC结果事务通道、AMI真实fire同拍owner commit、完成旁带同源扇出、abort迟到DONE释放及无组合ready环。上述缺失属于实现与验证证据，状态为`EVIDENCE_PENDING`；只要端口、连接、所有权和生命周期已由活跃合同无冲突地定义，它不得被表述为合同自身未闭合。

## 10. 验收要求

目标自检TB必须至少覆盖：

| 编号 | 场景 | 预期 |
| --- | --- | --- |
| SSW-01 | NORMAL SAR9 RED | 接管tick 0、Q3=300、SAR9包络44..318 |
| SSW-02 | NORMAL SAR15 RED | 接管tick 0、Q3=300、SAR15包络27..308 |
| SSW-03 | NORMAL SAR9 IR | 接管tick 160、Q3=460、SAR9包络204..478 |
| SSW-04 | NORMAL SAR15 IR | 接管tick 160、Q3=460、SAR15包络187..468 |
| SSW-05 | SAR9/SAR15 Q3对齐 | 两精度同色Q3逐tick一致 |
| SSW-06 | 单光RED | 不移动RED Q3，不产生IR LED窗口 |
| SSW-07 | 单光IR | 不移动IR Q3，不产生RED LED窗口 |
| SSW-08 | AMB_CAL | local Q3=266、两LED关闭、DC关闭且DC码0 |
| SSW-09 | DCS_CAL RED | local Q3=266、AMB已确认码与DC_R候选码同时稳定 |
| SSW-10 | DCS_CAL IR | local Q3=266、AMB已确认码与DC_IR候选码同时稳定 |
| SSW-11 | 8个校准子帧 | 相邻Q3精确相差625 tick |
| SSW-12 | 候选码更新 | tick 385后才影响下一子帧，当前波形快照不变 |
| SSW-13 | 预热中改码 | 输出仍使用旧快照且置协议诊断或隔离新码 |
| SSW-14 | 迟到波形接管 | 不启动波形、不移动Q3、置协议诊断 |
| SSW-15 | AMI反压 | 波形预建立可继续，owner保持pending；截止前无fire不占用sample index |
| SSW-16 | ADC完成匹配 | 相同sample index在`success=1/0`时均只释放当前ADC owner；0不得进入IDAC、NORMAL或校准成功处理 |
| SSW-17 | ADC完成错配 | 保持owner保护并置mismatch sticky |
| SSW-18 | 校准完成超时 | tick 385前未准备下一码则终止burst并置sticky |
| SSW-19 | SAR9到SAR15 | 仅接管点改变，先断后通，无双驱动 |
| SSW-20 | SAR15到SAR9 | 同上，Q3仍保持规定位置 |
| SSW-21 | STOP | 不接受新事务，当前包络安全结束后idle |
| SSW-22 | abort | 未提交上下文撤销；已提交owner保留最小释放身份，匹配`success=0`迟到完成只释放owner且不得重新激活时序 |
| SSW-23 | reset | 所有可撤销模拟控制进入安全向量 |
| SSW-24 | 固定电流SAR9表征 | `EN_TEST=1`，`BOTH/RED_ONLY/IR_ONLY`分别产生规定的RED/IR事务，400 Hz SAR9固定，LED和LEDDAC全程为0；`OFF`无波形、owner或有效IDAC总线 |
| SSW-25 | `o_clk_2m` | 始终与`i_clk`相位一致，无门控 |
| SSW-26 | AMB逐窗口 | 第6.1节全部窗口逐tick匹配，任何窗口外脉冲输出为0 |
| SSW-27 | AMB候选码窗口 | 仅`[224,276)`输出tick 0锁存的候选码，窗口外为0且中途更新不污染本子帧 |
| SSW-28 | AMB输入边界 | `EN_TEST=0`、两路LED为0、LEDDAC和DC码为0 |
| SSW-29 | 固定电流SAR15表征 | `EN_TEST=1`，`BOTH/RED_ONLY/IR_ONLY`分别产生规定的RED/IR事务，400 Hz SAR15固定，LED和LEDDAC全程为0；`OFF`无波形、owner或有效IDAC总线 |
| SSW-30 | STATIC_BIAS向量 | 第8.5节每一位精确符合netlist原始0/1向量，无SAR事务 |
| SSW-31 | STATIC_BIAS MUX | 已提交`S[4:0]`同一2 MHz边沿原子更新；其他模式输出0 |
| SSW-32 | 表征CDC隔离 | 未提交shadow、STOP、abort或复位不得形成迟到的`EN_TEST`、S或码值更新 |
| SSW-33 | 两通道分离 | waveform fire锁存模拟快照但不建立ADC owner；owner fire不改写模拟快照 |
| SSW-34 | 双波形上下文 | RED owner在途时macro tick 160仍接管IR波形，两个上下文身份不交叉 |
| SSW-35 | RED owner截止 | 最晚tick 283提交；tick 284前资格确定且Q3仍为300 |
| SSW-36 | IR owner截止 | RED真实完成后最晚tick 443提交；Q3仍为460 |
| SSW-37 | CAL owner截止 | 最晚local tick 248提交，249开始的后段窗口前owner稳定 |
| SSW-38 | owner失败抑制 | 过截止仍无owner时抑制Q1/Q2/Q3、LED和结果接纳，预建立安全收尾 |
| SSW-39 | owner原子性 | commit只能在ready为1且identity匹配时接受，sample index只在该沿首次绑定 |
| SSW-40 | 单owner约束 | RED owner未释放时IR owner ready保持0，但IR波形上下文不丢失 |
| SSW-41 | SAR15跨色白名单 | 仅四项确认信号允许连续，其他输出和两路LED无额外重叠 |
| SSW-42 | 真实DONE | Q3/包络末沿/固定4拍均不释放owner；匹配数字完成在`success=1/0`时均释放，只有1允许成功处理 |
| SSW-43 | 生命周期epoch | STOP安全收尾；abort保留最小释放身份而reset立即清除，任何迟到DONE均不得复活旧波形或结果 |
| SSW-44 | SAR9跨色白名单 | 仅`o_clk_iref_idac_sar9_low`按RED `[44,318)`和IR `[204,478)`合并为连续`[44,478)`；三个SAR9使能及其他控制无额外重叠 |
| SSW-45 | SAR9码总线精度隔离 | NORMAL/DCS使用非零AMB/DC快照时，只有SAR9对应两组总线按各自netlist码窗逐bit工作，SAR15两组逐tick保持`8'h00` |
| SSW-46 | SAR15码总线精度隔离 | NORMAL使用非零AMB/DC快照时，只有SAR15对应两组总线按各自netlist码窗逐bit工作，SAR9两组逐tick保持`8'h00` |
| SSW-47 | 逐bit码窗与快照稳定 | 使用至少两组非对称码逐bit比较码窗内外值；预热后改变实时码不污染当前输出，下一波形才采用新快照 |
| SSW-48 | 类型和模式矩阵 | AMB_CAL仅SAR9 AMB工作；DCS_CAL为SAR9 AMB+DC；STATIC_BIAS四组为0；固定电流NORMAL保留所选精度AMB/DC码；非法SAR15校准四组为0并置诊断 |
| SSW-49 | CHARACTERIZATION光电二极管固定SAR9 RED | `input_source=PHOTODIODE`、`RED_ONLY`、`EN_TEST=0`、接管tick 0、Q3=300、IR全程关闭、MANUAL码预热前锁存 |
| SSW-50 | CHARACTERIZATION光电二极管固定SAR15 RED | 同SSW-49，SAR15预热严格为`[27,308)`，精度全RUN固定且Q3=300 |
| SSW-51 | CHARACTERIZATION固定模式非法组合 | 非法输入源/光学模式、`OFF`固定电流测量或尝试自动搜索/精度切换时，不产生波形、owner或有效IDAC码总线；合法外部固定电流模式仅为`BOTH/RED_ONLY/IR_ONLY` |
| SSW-52 | STATIC_BIAS源资格 | 仅`input_source=1`进入静态状态；`input_source=0`拒绝且不产生波形、owner或有效IDAC码总线 |

正式RTL完成后必须执行：

```text
formatter-AST：0 error / 0 strict warning
独立Verilog lint：0 error / 0 warning
Vivado xvlog：通过
Vivado xelab：通过
 Vivado xsim：SSW-01至SSW-52全部真实PASS
Vivado综合：0 error / 0 critical warning，Latch=0，Blackbox=0，2 MHz时序满足
```

## 11. Current V1.8 Frozen Rule Set

本文正式冻结以下不可变规则：

```text
统一外部相位是唯一物理时间基准；
NORMAL Q3固定为RED=300、IR=460；
校准Q3固定为266，且所有校准类型相同；
SAR9/SAR15按各自提前量预建立，但不改变同色Q3；
本轮码值和epoch必须在预热前锁存；
模拟波形上下文与ADC结果owner是两个独立接口和状态；
NORMAL RED/IR波形分别在tick 0/160接管，IR接管不等待RED owner释放；
ADC owner最晚在NORMAL tick 283/443和CAL local tick 248提交；
只有owner真实提交才正式绑定sample index，只有真实CLK_DOUT数字完成才释放；
owner缺失时预建立安全收尾，但Q1/Q2/Q3、LED有效采样和结果接纳必须抑制；
SAR9跨颜色连续保持严格限制为`o_clk_iref_idac_sar9_low`单项白名单；
SAR15跨颜色连续保持严格限制为四项用户确认白名单；
AMB_CAL为LED全关、AMB有效、DC关闭且DC码0；
DCS_CAL始终使用已确认AMB码加当前颜色DC候选码；
ADC完成只能来自CLK_DOUT数字捕获链；
未在固定点真实握手的波形不得启动或移动Q3；
SAR选择必须注册化先断后通；
AMB专用SAR9窗口严格采用第6.1节；
固定电流表征仍运行400 Hz间歇SAR，EN_TEST为1且LED全关；
STATIC_BIAS严格采用第8.5节原始静态向量，只有S[4:0]可原子更新；
四组IDAC数据总线按第4.7节逐bit输出；码值只决定码窗内哪些bit为1，窗口位置只来自对应netlist；
SAR9事务中SAR15两组码总线全程为0，SAR15事务中SAR9两组码总线全程为0；
AMB_CAL只有SAR9 AMB候选码总线工作，STATIC_BIAS四组总线全部为0；
未选精度总线不得依赖模拟使能隔离，不得出现镜像码值、组合毛刺或无效翻转。
```

V1.8 normatively retains the interface, fixed pure-RED CHARACTERIZATION
qualification, STATIC_BIAS input-source qualification and four IDAC-bus rules
above. The V1.2 single-fire and dual-precision-bus historical implementation
are not applicable. Earlier SSW-01 through SSW-52 results are non-normative
historical evidence only; current joint and final-Top implementation evidence
remains `EVIDENCE_PENDING`.
