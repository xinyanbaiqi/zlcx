# PPG ADC 异步捕获与 IDAC 单窗口控制集成规格

> 架构修订：2026-08-09。本文是当前活动规格。IDAC正常控制使用ACTIVE逐物理位可编程校准得到的Stage1结果和一组LOW/HIGH迟滞窗口；芯片内不执行在线NLMS/LMS迭代；SPI静态配置只在CONFIG阶段原子提交。NORMAL慢速跟踪和AMB周期重检由`PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`冻结。本次修订按“PPG码值与光电二极管接收光强正相关”的原始码值极性冻结自动精度窗口方向。

## 1. 文档目的

本文冻结ADC捕获、固定冗余重构、可编程校准、结果路由、系统配置管理和IDAC控制的职责边界、接口语义、拍级时序与禁止事项，供后续窗口按同一合同实现和评审。

目标是：

- 不在两个模块中重复实现 RAW 锁存、冗余校正或阈值判断；
- 不把异步 ADC 信号直接送入 IDAC 控制逻辑；
- 每笔 ADC 结果只被接收、校正和判断一次；
- 通过寄存流水线保证数据、阈值、比较结果和有效信号不会错拍；
- 输出严格可综合的 Verilog-2001 RTL，可进入 Synopsys DC、STA 和 ASIC 布局布线流程。

本文中的“必须”是接口硬约束；实现不得自行更改。

本规格把系统架构合同与实现参数合同分开管理。下面冻结的是数据流方向、模块职责、事务边界、
ADC/RAW接口保持关系、IDAC控制原则和校准位置；校准结果位宽/Q格式、SPI寄存器地址、
FRAME_ID/sample_index的生成与回绕以及尚未覆盖的命令编码仍须在对应模块开始前单独冻结。NORMAL期间慢速跟踪样本来源、4-bit IDAC code_epoch和AMB周期重检已经由独立冻结合同定义。
后续窗口不得把这些待冻结细节反推成新的系统架构，也不得用未确定的细节改写已经完成的RTL接口。

## 2. 已冻结的系统事实

- 数字控制主时钟为 2 MHz。
- PPG 帧率为 400 Hz，每帧约 2.5 ms。
- Pipeline-SAR ADC 的 S1、S2 物理输出均为 10 bit，其中包含冗余信息。
- S1_RAW并行进入两条路径：固定冗余重构产生D1_EXT/detect_code供黄金、范围观察和标称表征；目标架构中的active逐物理判决位固定系数乘加直接产生calibrated_s1_value供正常IDAC和粗波形残差使用，后一路仍待实现。这里的“黄金”只表示与冻结Verilog-A冗余公式逐码一致的数字参考，不表示流片后真实模拟输入，也不表示已经完成校准。
- Stage1物理端码诊断直接由 `S1_RAW==10'b0` 和 `S1_RAW==10'b11_1111_1111` 产生；它只报告物理判决余量已用尽，不建立第二个控制窗口，也不替代校准残差的正常LOW/HIGH比较。
- S1、S2 的物理码和完成电平由一个 `ppg_adc_async_stage_capture` 按当前精度模式统一接收。
- 模拟ADC不接收数字ACK；S1、S2末位转换完成后分别拉高对应 `CLK_DOUT`，并把物理码与完成电平保持到下一次 `ADC_RST`。
- 9-bit事务由S1完成电平触发，只保存S1；15-bit事务由S2完成电平触发，同时保存仍保持稳定的S1和S2。
- 在同一个物理抵消通道内，PMOS/NMOS互补支路使用同一个幅度码，由模拟侧完成正/负方向映射；这不表示AMB与DCS共用同一组逻辑码。AMB和DCS仍是独立的抵消功能、独立的数字状态和独立的事务快照。
- 数字域提交给模拟接口的 IDAC 码字只能在系统定义的帧安全边界改变，ADC 转换和前端积分期间必须保持稳定；该码字不能证明模拟 IDAC 电流已经准确达到目标值，实际电流仍由模拟实现和流片表征确认。
- 系统生命周期固定为CONFIG、READY、RUN和STOPPING；外部测试电流源选择和IDAC控制方式是与生命周期正交的配置字段，不存在会自动关闭IDAC的全局TEST状态。
- 红光粗精度PPG链拥有精度窗口控制权：PPG码值与光电二极管接收光强正相关；该链在恢复DC等效量并完成粗检测滤波后，以前一码值波峰为锚点建立负斜率动态基线，并检测当前粗滤波码值向上穿越该基线。向上相交确认后只提出下一400-Hz采样帧（即下一安全ADC事务，不是下一心动周期）进入15-bit的请求。15-bit期间模式判断仍使用连续的Stage1粗滤波结果：先确认码值波峰，随后跟踪下降段并保存运行最小值；当码值从运行最小值连续上升规定数量的有效样本时，确认码值波谷已经经过，并请求下一采样帧在安全边界切回9-bit。完整15-bit重构结果只用于高精度PPG数据记录，不直接驱动峰谷窗口控制。红外事务不单独发起精度切换，而是跟随同一400-Hz采样帧已经提交的精度模式。任何精度切换都不得发生在同一转换中途。
- RUN期间ACTIVE_CONFIG和本次运行使用的系数版本冻结；运行中的IDAC code_epoch只随数字域已提交IDAC码在安全边界实际改变而更新。`config_epoch`/`coef_epoch`的位宽、回绕和“每次完整提交都递增”还是“仅相关字段改变才递增”的细则待对应配置模块冻结。

## 3. 模块责任边界

### 3.1 `ppg_adc_async_stage_capture`

该模块是双精度 Pipeline-SAR ADC 的统一异步结果接收单元。

它必须负责：

1. 将两个异步 `CLK_DOUT` 分别通过两级目的域触发器同步到 `i_clk` 域；
2. 只使用每套同步链的第二级结果参与功能判断；
3. 9-bit模式只在S1完成后锁存S1，并把缓存S2明确清零；
4. 15-bit模式只在S2完成后同时锁存S1和S2；
5. 每个所选 `CLK_DOUT` 高电平最多捕获一次；下一事务只能由上层在ADC_RST已经使两个DONE回低后发出新的 `i_adc_transaction_start`；本模块没有ADC_RST输入，不直接宣称观测其低相位；
6. 通过 `o_capture_valid/i_capture_ready` 保持已捕获事务，直到下游接收；
7. 缓冲区被占用且下游未接收时，不覆盖旧RAW或精度模式快照。

它不得负责：

- 10-bit RAW 的冗余校正；
- 9-bit等效码生成；
- AMB/DCS 通道识别；
- ADC 高低阈值比较；
- IDAC 快速搜索、慢速跟踪或码值更新；
- SPI SHADOW_CONFIG/ACTIVE_CONFIG 的所有权或提交控制；
- 将10根 RAW 数据线分别送入同步器。

集成层必须使用同一个已接受的事务启动事件同时驱动捕获器和S1上下文模块：

```text
transaction_start_fire =
    start_request
    && o_transaction_ready
    && ADC_RST_complete
    && stage1_done_low
    && stage2_done_low
```

`o_transaction_ready`来自S1上下文缓冲器；捕获器本身没有独立的start-ready输出。
因此，上层不能把原始帧起始脉冲直接接到两个模块，必须先形成上述`transaction_start_fire`，
再把同一个脉冲送到`i_adc_transaction_start`。该前置合同保证上下文不会被新事务覆盖，
也保证捕获器清除同步历史时模拟端已经完成ADC_RST。

### 3.2 冗余校正、Stage1校准与结果对齐模块

这是捕获结果与后续控制/数据链之间的独立依赖，逻辑上不能省略。它可以在后续单独文件中实现，但不能偷偷并入异步捕获或 IDAC 控制器。
当前已经实现的是S1固定冗余重构、事务元数据和S1/S2 RAW透传；Stage1可编程校准器以及
`calibrated_s1_value`、`calibration_applied`、`coef_epoch` 的后续事务传递仍属于待实现接口。

最终集成位置固定为：在事务链上位于S1固定冗余重构模块之后、AMB/DCS/NORMAL结果路由之前；
这只是模块连接和事务对齐顺序，校准算术输入仍必须是同一笔原子锁存的完整 `S1_RAW[9:0]`，
不得把 `D1_EXT` 或 `detect_code` 当作Stage1主校准输入。
现有`ppg_adc_result_router`后接`overlap_corrector`的连接只是未校准标称观察链基线；
Stage1可编程校准器不能只放在NORMAL分支，否则AMB_CAL和DCS_CAL的IDAC控制会继续使用未校准残差。

它必须负责：

1. 在 `capture_valid && capture_ready` 的唯一传输沿接收一次稳定 RAW；
2. 将物理10-bit S1结果按黄金公式转换为未钳位 `D1_EXT` 和固定9-bit检测码；
3. 同时把完整S1_RAW作为事务字段送入独立可编程校准级，由active逐位绝对权重直接生成 `calibrated_s1_value`；
4. 产生与固定码、校准码和元数据严格对齐的单笔事务；
5. 如系统需要，对 S1/S2 结果进行事务对齐和上下文标记；
6. 对下游提供明确的保持型ready/valid接口，并把数值、资格和元数据作为不可拆分载荷保持到握手完成。

它不得把 `o_capture_valid` 原样改名为 IDAC 的 `i_sample_valid`，因为前者可能连续保持多个时钟周期。

### 3.3 `ppg_idac_code_controller`

本节定义重构后的目标控制器合同。当前同名RTL仍是过渡参考实现，尚未满足active配置、
校准Stage1保持型ready/valid和单一LOW/HIGH窗口合同，不得按本节文字误报为已经实现。

该模块只工作在 `i_clk` 同步时钟域，只消费由当前active逐位系数完成乘加后的
`calibrated_s1_value`事务。active系数在RUN期间固定，但可在CONFIG阶段由SPI原子替换；
它不读取异步RAW，也不读取15-bit结果。

它必须负责：

1. 在一笔合法 `sample_transfer` 到来时，锁存 `calibrated_s1_value`；
2. 同拍锁存本次样本对应的ACTIVE高低阈值快照；
3. 下一流水级寄存 `above_high/below_low/in_window` 比较结果；
4. 产生与比较结果严格同拍的内部 `flag_compare_valid`；
5. 搜索 FSM 和跟踪计数器只能在 `flag_compare_valid` 有效时消费比较结果；
6. 上电快速搜索产生候选码，候选码只在安全边界成为数字域committed码；
7. 搜索完成后只使用一组LOW/HIGH迟滞窗口执行长期跟踪；
8. 连续 `N_CONFIRM` 个同向越界结果后只移动1 LSB；
9. 窗口内结果或反向越界结果清空当前同向证据；
10. 码值只在帧安全边界更新，并由时序控制器在下一次积分前保证IDAC、参考和PVT裕量所需建立时间，不丢弃完整400 Hz样本；
11. 只读取系统配置管理器在CONFIG阶段提交的active参数，不解析SPI地址，也不拥有独立shadow/live或运行期commit；
12. 进入非RUN状态、restart在START边界生效、禁用、模拟未就绪和数字域committed码更新时清除可能失效的流水valid与越界证据；
13. 码值上下边界必须饱和保护，不允许回绕；
14. 支持手动码、自动搜索后保持、自动搜索后慢速跟踪三种运行模式；
15. 红光和红外共用物理DC IDAC时，数字域分别保存并选择 `DC_CODE_R`、`DC_CODE_IR` 及相应的DC搜索/跟踪状态。

它不得负责：

- 同步异步 `CLK_DOUT`；
- 直接锁存异步 RAW；
- 实现 S1/S2 的物理10-bit冗余校正；
- 使用异步 `CLK_DOUT` 或未捕获的物理RAW；
- 在 `i_sample_valid=0` 时根据总线残留值作出判断；
- 在 ADC 转换或前端积分窗口内直接改变 `o_idac_code`。

### 3.4 系统生命周期与SPI配置管理器

系统级配置管理器负责唯一的静态配置所有权，功能模块只接收已经验证的ACTIVE字段：

```text
RESET → CONFIG → READY → RUN → STOPPING → CONFIG
```

| 状态 | 允许的SPI操作 | 禁止的SPI操作 |
|---|---|---|
| CONFIG | 读回、写SHADOW_CONFIG、COMMIT、读错误状态 | START、启动模拟转换或任何隐式运行期动作 |
| READY | 读状态/active配置、START | 写配置、COMMIT、SPI直接覆盖手动IDAC码、单次转换 |
| RUN | 读状态/诊断、STOP | 写配置、COMMIT、SPI直接覆盖手动IDAC码、单次转换 |
| STOPPING | 读状态、重复STOP | START、写配置、COMMIT及任何手动模拟动作 |

`cfg_input_source`只选择`PHOTODIODE`或`EXTERNAL_TEST_CURRENT`；`cfg_idac_mode`独立选择`MANUAL`、`SEARCH_HOLD`或`SEARCH_TRACK`。例如外部测试电流源可以和自动IDAC组合，用于动态范围测试；它不是全局TEST状态。`CHARACTERIZATION`若启用，只是CONFIG阶段提交的输入/输出资格配置，不是第四个生命周期状态。MANUAL码在CONFIG写入shadow并COMMIT到ACTIVE_CONFIG；进入RUN后只在首个允许的帧安全边界装入数字域committed码并保持。RUN禁止的是SPI修改或直接覆盖manual code，不是禁止MANUAL模式运行。

SPI逐字段写入SHADOW_CONFIG，写完后只发一次COMMIT。稳定总线加request/ack CDC把整组快照送到2 MHz域；`ppg_config_cdc_bridge`的transport busy/ack只说明跨域传输状态，不等同于ACTIVE已经生效。2 MHz配置管理器必须完成整组枚举、范围、系数完整性和LOW<HIGH检查，只有在安全状态下才可原子替换ACTIVE_CONFIG，并以可读的sticky `config_commit_ack`/`config_error`反馈SPI域。首版只支持完整快照COMMIT；拒绝或非法COMMIT不得改变ACTIVE或任何版本标签。版本标签的具体递增策略属于待冻结实现参数；无论采用何种策略，提交后的每笔结果必须携带真正参与计算的`coef_epoch`，且同一提交不能产生半新半旧的系数快照。busy期间第二次COMMIT必须返回明确拒绝，不能静默丢弃或覆盖第一组快照。

START只能在READY且配置完整有效时接受。正式NORMAL_PPG启动还必须确认校准系数已提交；未校准标称结果只允许在明确选择的CHARACTERIZATION运行配置中导出。STOP进入STOPPING后停止发起新帧，等待当前ADC事务完成、捕获/校正ready/valid流水排空，再把模拟控制置安全并返回CONFIG。ACTIVE_CONFIG和本次RUN的`coef_epoch`在RUN期间不变。

## 4. 总体数据链

以下是冻结的目标数据链，不是对当前source set完成度的声明。Stage1可编程校准、校准字段扩展、
IDAC控制器重构、15-bit可编程重构和DC等效量恢复仍须按交付说明逐项实现与验证。

```text
ADC S1/S2 RAW[9:0] + 两个CLK_DOUT + precision_mode
            │
            ▼
ppg_adc_async_stage_capture
            │ capture_stage1_raw[9:0]
            │ capture_stage2_raw[9:0]
            │ capture_precision_mode
            │ capture_valid/capture_ready
            ▼
S1固定冗余校正与结果对齐模块
    │ S1_RAW、D1_EXT、fixed_detect_code、S2_RAW、元数据、事务valid
    ▼
Stage1可编程校准模块
    │ S1_RAW逐物理位绝对权重 → calibrated_s1_value
    │ fixed_detect_code、D1_EXT、S1/S2_RAW、元数据、事务valid继续对齐透传
    ▼
AMB/DCS/NORMAL互斥结果路由
    ├── AMB/DCS：ppg_idac_code_controller
    │               │ 码值+阈值快照寄存
    │               │ 比较结果+compare_valid寄存
    │               │ 搜索/跟踪决策
    │               ▼
    │          pending_idac_code
    │               │ frame_safe_boundary
    │               ▼
    │          o_idac_code[7:0]
    │
    └── NORMAL：DC等效量恢复、滤波、基线和相交链
```

15-bit事务中的S2结果进入精细数据链，但不得直接驱动本 IDAC 判断；15-bit链路的校准也不改变Stage1 IDAC控制输入：

```text
capture_stage1_raw[9:0] + capture_stage2_raw[9:0]
        + capture_precision_mode=1
            ▼
S1/S2校正、级间对齐与15-bit组合链
```

正常数据链的控制边界为：

```text
S1_RAW ├→ 固定D1_EXT/detect_code（黄金、范围观察和标称表征）
       └→ 逐物理位active权重乘加 → calibrated_s1_residual → IDAC单窗口控制
                                                        └→ DC等效量恢复 → coarse_ppg_value → 滤波、基线、相交和9-bit波形输出
S1_RAW逐物理位基项 + D2_EXT可编程项（同时保留S2_RAW）
       → SPI active固定系数重构 → calibrated_15_residual
                                                 └→ DC等效量恢复 → fine_ppg_value → 精确峰谷和数据输出
```

`calibrated_s1_residual` 是ADC在当前IDAC码作用后的剩余量，适合把模拟工作点维持在目标窗口。`coarse_ppg_value`/`fine_ppg_value` 才是恢复本次 `dc_code_snapshot` 等效量后的生物医学PPG值。不得用恢复后的完整PPG值反过来控制IDAC窗口，也不得把未恢复的残差直接送入基线、相交或完整波形输出。

正常生物医学PPG链只恢复本事务对应的DC抵消等效量；AMB抵消的环境光量不作为正常PPG波形的加回项。AMB量仍可保留在事务快照、校准记录和故障诊断中。粗精度与15-bit精细结果在恢复后必须落到同一输入等效标度，才能无台阶地拼接完整PPG波形。

当前 `ppg_adc_result_router` 对每笔事务采用AMB_CAL/DCS_CAL/NORMAL互斥选择，这是已实现的路由基线。SEARCH_TRACK在NORMAL期间固定采用独立单元素保持型fork：measurement分支保留完整PPG事务，tracking分支把同一笔校准Stage1残差和必要元数据交给IDAC。每个分支只能消费一次，IDAC等待安全提交时必须继续接收并忽略暂时无资格的样本，不得长期反压PPG链。不得把router改成无状态valid复制；具体接口见`PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`。

## 5. 异步捕获模块接口合同

端口必须与真实模拟ADC结果接口保持一致：

```verilog
module ppg_adc_async_stage_capture
#(
	parameter integer C_RAW_WIDTH = 10
)
(
	input i_clk,
	input i_rstn,
	input i_adc_transaction_start,
	input i_precision_mode_committed,
	input [C_RAW_WIDTH - 1:0]i_dout_stage1_low,
	input i_clk_stage1_dout_low_async,
	input [C_RAW_WIDTH - 1:0]i_dout_stage2_low,
	input i_clk_stage2_dout_low_async,
	input i_capture_ready,
	output [C_RAW_WIDTH - 1:0]o_capture_stage1_raw,
	output [C_RAW_WIDTH - 1:0]o_capture_stage2_raw,
	output o_capture_precision_mode,
	output o_capture_valid
);
```

### 5.1 信号语义

| 信号 | 语义 |
|---|---|
| `i_adc_transaction_start` | ADC_RST已完成且两个DONE为低后、下一次模拟转换开始前的事务边界脉冲 |
| `i_precision_mode_committed` | 在事务边界提交、并由模拟时序使用的本笔9/15-bit精度快照 |
| `i_clk_stage1_dout_low_async` | S1末位完成后拉高、ADC_RST后拉低的异步结果有效电平 |
| `i_dout_stage1_low` | S1 bundled-data RAW总线，两种精度模式均可能被捕获 |
| `i_clk_stage2_dout_low_async` | S2末位完成后拉高、ADC_RST后拉低的异步结果有效电平 |
| `i_dout_stage2_low` | S2 bundled-data RAW总线，仅15-bit事务有效 |
| `o_capture_stage1_raw` | 目的时钟域中的稳定S1 RAW缓冲值 |
| `o_capture_stage2_raw` | 目的时钟域中的稳定S2 RAW缓冲值，9-bit事务固定为0 |
| `o_capture_precision_mode` | 与两级RAW同拍保存的精度模式快照 |
| `o_capture_valid` | 缓冲区中存在一笔未被下游消费的结果；可保持多拍 |
| `i_capture_ready` | 下游允许在当前上升沿消费RAW |

唯一的下游传输事件定义为：

```verilog
flag_capture_transfer = o_capture_valid && i_capture_ready;
```

只有 `flag_capture_transfer` 在上升沿为1，才表示下游接收了一笔 RAW。

### 5.2 结果有效与ADC_RST约束

```text
空闲：两个CLK_DOUT均为0
  ↓ ADC末位完成并保持对应RAW
9-bit：S1 CLK_DOUT拉高，数字域同步后锁存S1
15-bit：S1先完成，S2 CLK_DOUT随后拉高，数字域同步后同时锁存S1和S2
  ↓ 每个所选高电平只接纳一次
保持：valid和缓存RAW保持到下游ready消费
  ↓ 下一次ADC_RST
复位相位：两个CLK_DOUT和模拟RAW清零
  ↓ 上层确认两个DONE已经为低
上层发出新的i_adc_transaction_start
  ↓ 捕获器清除旧同步历史并武装本次事务
等待下一次所选DONE拉高
```

`ADC_RST` 到来前必须给数字域留下足够时间完成同步和锁存；`o_capture_valid` 必须独立保持到下游传输完成。

### 5.3 CDC约束

- 两个异步 `CLK_DOUT` 分别进入独立的两级同步链；
- 第一级同步寄存器只能驱动第二级，不得参与功能逻辑；
- 两套RAW总线都不进入逐位同步器；
- 捕获RAW必须依赖已同步的所选 `CLK_DOUT`，并利用RAW保持到ADC_RST的模拟合同；
- 建议综合/STA约束把第一级同步触发器标记为异步寄存器，并对异步输入路径按项目 CDC 策略约束；
- `i_rstn` 可以异步置位/清零，但其释放必须由系统上层同步后再分发。

## 6. 捕获模块到 IDAC 模块的接口合同

捕获模块不能直接连接IDAC控制器。捕获结果进入统一事务链后，完整S1_RAW并行派生固定参考结果、
物理端码诊断和逐物理位校准结果；只有校准结果可以再经通道路由送入IDAC控制器：

```text
capture_raw[9:0] + capture_valid/ready
       ├── 固定冗余公式 → D1_EXT + fixed_detect_code
       ├── S1_RAW全0/全1 → terminal_low/terminal_high诊断
       └── S1_RAW逐物理位active权重固定乘加
                         → calibrated_s1_value + sample_valid/ready
                         → AMB_CAL/DCS_CAL互斥路由
                         → 对应IDAC控制器
```

`fixed_detect_code` 必须继续随事务保留，用于黄金模型比较、范围观察和标称表征，但正常闭环比较只读取 `calibrated_s1_value`。物理端码标志必须直接由完整S1_RAW产生，不能通过固定码或校准结果反推。复位后或流片系数尚未提交时，可编程校准级必须装载标称逐位权重并继续产生有效的 `calibrated_s1_value`，同时输出 `calibration_applied=0`；不得因为 `coef_valid=0` 而中断明确选择的CHARACTERIZATION数据链。正式NORMAL_PPG的START资格仍要求所需校准系数已经合法提交。

IDAC侧保留当前输入命名时，必须冻结以下含义：

`C_S1_CAL_WIDTH` 是校准Stage1结果的有符号位宽，必须在生成RTL前由系统确认。它应至少能够表达正常9-bit标度、校准偏置和控制窗口外的诊断值；不得在乘加或比较前静默截成无符号9 bit。

```verilog
input signed [C_S1_CAL_WIDTH - 1:0]i_calibrated_s1_value; // 与当前窗口标度一致的校准Stage1结果
input i_sample_valid;     // 保持型valid，和校准结果严格对齐
output o_sample_ready;    // 当前控制器可以接收一笔新样本
```

`i_sample_valid` 必须满足：

- 每笔校正结果只被接受一次；
- 高电平所在上升沿，校准结果和窗口元数据已满足建立/保持时间；
- 只包含当前 IDAC 控制实例所属的 AMB 或 DCS 通道结果；
- 不包含 S2 结果；
- 不包含被系统明确丢弃的建立期、复位期或错误事务；
- 若上游可能反压，则不能用无缓存单拍接口，必须升级为 ready/valid，或由上游保证 IDAC 永远可接收。

推荐正式使用：

```text
sample_transfer = i_sample_valid && o_sample_ready
```

不得把上游保持型 `valid` 直接接到没有接收握手的确认计数器。

## 7. IDAC内部推荐的寄存流水

### 7.1 流水级定义

```text
P0：接收校正结果
    条件：sample_transfer = i_sample_valid && o_sample_ready
    动作：寄存calibrated_s1_value、active_low_threshold、active_high_threshold
          同拍寄存本样本code_epoch和通道标识
          置位sample_pipe_valid

P1：完成并寄存比较
    条件：sample_pipe_valid
    动作：寄存above_high、below_low、in_window
          置位compare_valid

P2：消费比较结果
    条件：compare_valid
    动作：搜索FSM或跟踪计数器更新
          必要时形成pending code

P3或更晚：安全提交
    条件：pending有效 && i_frame_safe_boundary
    动作：更新数字域committed码及o_idac_code，产生o_code_update
```

比较器本身会被综合为寄存器之间的组合标准单元，这是正常 ASIC 结构。关键是比较输入和输出均有清楚的寄存边界，不能让搜索/计数器直接消费原始组合比较结果。

### 7.2 阈值快照

每笔样本必须和本次使用的ACTIVE阈值一起锁存。ACTIVE_CONFIG在整个RUN期间冻结，SPI COMMIT只允许在CONFIG且模拟停止、流水排空时生效；P1仍只读取P0阈值快照，以保持比较流水的数据与控制严格同拍。

### 7.3 比较定义

```text
calibrated_s1_value > HIGH  → above_high
calibrated_s1_value < LOW   → below_low
LOW ≤ calibrated_s1_value ≤ HIGH → in_window
```

等于高阈值或低阈值均属于窗口内。三种结果必须互斥。

### 7.4 流水清空条件

以下事件必须清除 `sample_pipe_valid`、`compare_valid` 和不再可信的连续越界证据：

- 复位有效；
- `i_enable=0`；
- `i_analog_ready=0`；
- 系统已回到CONFIG、流水排空且合法COMMIT原子更新ACTIVE_CONFIG后，对控制器执行重新初始化；
- `SEARCH_RESTART` 实际生效；
- 数字域committed IDAC码发生变化；
- 搜索结束进入跟踪的模式切换边界；
- 配置非法导致控制器进入错误锁定。

正常跟踪每次只移动1 LSB；启动搜索允许有限次数的计划内试探码，不得用第二个快速安全窗口形成连续反馈跳码。

如果只到达普通帧边界但没有改变码值或配置，不应无条件清空有效数据。

## 8. 防止旧码样本污染新码判断

系统必须保证以下二选一条件至少成立一项：

### 方案A：安全边界同时保证流水已排空

`i_frame_safe_boundary` 只有在以下条件全部成立时才允许更新数字域committed IDAC码：

- 前端积分已结束；
- ADC 转换已结束；
- 对应 RAW 已完成捕获；
- 冗余校正结果已经被 IDAC 控制器接收或明确丢弃；
- 捕获、校正和比较流水中不存在属于旧 IDAC 码的未标识事务。

### 方案B：携带码值代号/epoch（现有事务链推荐保留）

如果系统不能保证安全边界前流水排空，则必须在启动转换时记录 IDAC code epoch，并把该标记随 RAW、校正结果传到 IDAC 控制器。控制器只允许与当前被观察码一致的结果进入连续确认计数。

当前S1重构器和结果路由器已经透传AMB/DC code epoch，但现有 `ppg_idac_code_controller` 端口尚未接收该字段。改造控制器时应补充对应epoch输入；在该端口补齐前，集成只能采用方案A。epoch只用于拒绝旧码样本，不能放宽“数字域committed IDAC码只能在帧安全边界更新”的约束；模拟电流是否按该码稳定建立由模拟接口时序合同和表征验证。

## 9. AMB/DCS与S1/S2路由约束

- S1/S2 表示 ADC 级别；AMB/DCS 表示模拟抵消相位，两者不是同一个维度。
- 双级捕获模块只区分S1/S2和精度模式，不负责区分AMB/DCS。
- RUN初始化与进入正常采样的冻结顺序为：先执行AMB_CAL并使AMB码稳定，再固定AMB码分别完成红光和红外DCS_CAL，使 `DC_CODE_R`、`DC_CODE_IR` 稳定，最后进入NORMAL事务。AMB_CAL时LED关闭，DC码为零或配置规定的固定值；DCS_CAL时保持AMB码不变并只调节当前 `color_ir` 对应的DC状态。
- 上层时序/结果路由必须把AMB_CAL送入AMB控制状态，把DCS_CAL送入共享DC控制分支；DCS分支使用 `color_ir` 选择并回写红光或红外的DC码及DC搜索/跟踪状态，不要求复制两套DC运算硬件。
- `i_sample_valid` 必须已经经过通道资格判断；未选中通道的控制器不得看到该脉冲。
- AMB与DCS是两个独立抵消控制状态；即使复用同一套比较/加减运算资源，也必须按事务类型装载对应状态和阈值，禁止交叉回写。
- AMB和DCS可以保存不同的阈值参数，但每个控制实例运行时只激活一组LOW/HIGH窗口；这不是同一环路的嵌套双窗口。
- 同一PPG高精度周期的R和IR事务都使用已提交的15-bit模式；15-bit结果不参与IDAC范围控制。

## 10. 可综合ASIC RTL硬约束

两个模块及中间校正模块均必须遵守：

- 仅使用可综合 Verilog-2001；
- RTL中禁止 `#delay`、`initial`、`force/release`、`wait`、`real` 和仿真系统任务；
- 时序寄存器使用非阻塞赋值；
- 组合过程完整赋默认值并覆盖全部分支，禁止锁存器；
- 不使用普通逻辑直接生成门控时钟，统一使用 clock enable；
- 不把异步 `CLK_DOUT` 当时钟；
- 所有计数器、加减法、扩展和截断显式确定位宽；
- IDAC加减必须饱和，不得利用自然溢出；
- 复位后所有valid、重新武装状态、pending、计数器、状态和输出码处于确定状态；
- 顶层复杂输出由内部寄存器驱动，并通过连续赋值桥接；
- 同一寄存器只有一个驱动过程；
- 不依赖 FPGA 专用初始化语义；
- 综合警告中的 latch、multiple driver、width truncation、combinational loop、unconstrained CDC 均视为阻断问题。

## 11. 禁止的直接连接与重复实现

以下写法一律禁止：

```verilog
// 禁止：保持型valid会导致同一RAW被重复使用
assign idac_sample_valid = capture_valid;

// 禁止：IDAC控制器直接观察异步CLK_DOUT
if (i_clk_stage1_dout_low_async) begin
	// IDAC decision
end

// 禁止：把10根RAW逐位同步后拼接
raw_sync_bit_n <= i_dout_stage1_low[n];

// 禁止：未寄存比较结果就直接累计
if (i_sample_valid && (i_calibrated_s1_value > threshold_high_active)) begin
	cnt_high <= cnt_high + 1'b1;
end

// 禁止：ADC捕获模块实现阈值或IDAC算法
if (capture_raw > idac_threshold) begin
	// change IDAC
end
```

## 12. 模块完成判据

只有同时满足以下条件，才可以声称相关模块可以集成：

1. 每个所选 `CLK_DOUT` 高电平最多生成一笔RAW传输；
2. 每笔 RAW 传输最多生成一个校正结果有效事件；
3. 每个校正结果有效事件最多生成一个比较有效事件；
4. 搜索/跟踪只消费比较有效事件，不读取无效总线残留值；
5. SPI COMMIT只在CONFIG且流水为空时更新ACTIVE阈值，RUN期间阈值冻结，任何样本都不会跨配置版本；
6. IDAC码只在安全边界改变；
7. 调码后旧码结果不会被当作新码结果；
8. 捕获模块、IDAC模块和集成测试平台均通过自检仿真；
9. 所有参与集成的 RTL 文件均通过严格静态门禁；
10. 综合无 latch、multiple driver、组合环、宽度丢失和不可综合结构。
