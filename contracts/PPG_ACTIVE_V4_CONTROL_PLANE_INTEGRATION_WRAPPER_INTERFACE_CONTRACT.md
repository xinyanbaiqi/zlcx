# PPG ACTIVE V4控制平面集成Wrapper接口合同

> V1.6 fail-closed D01 revision, 2026-08-20: Top-merged STOP, manager-local status-clear isolation, system-blocking START gating, generation forwarding and stop-episode forwarding remain normative. V4/V5 use one 1024-bit shadow/CDC/atomic COMMIT path; system closure remains `NOT_CLOSED` until the matrix audit records zero defects. Implementation evidence is `EVIDENCE_PENDING`.
> V1.5 change record: replaces stale downstream dependency versions with the active contract set. It changes no wrapper port, CDC, lifecycle or hierarchy behavior.
> Normative status: V1.6 is the sole current wrapper port and hierarchy authority. Earlier V1.0-V1.5 status, dependency-version and scope statements are historical unless repeated by V1.6; they cannot omit a V1.6 wrapper port or bypass the manager-wrapper boundary.

> 历史冻结记录（非规范）：V1.0-V1.5正式冻结内容保留用于变更追溯；当前唯一规范版本为本页眉声明的V1.6。  
> 冻结日期：2026-08-14  
> 目标RTL：`ppg_active_v4_control_plane_integration.v`  
> 目标TB：`tb_ppg_active_v4_control_plane_integration.v`（实现证据仍为`EVIDENCE_PENDING`）  
> 工作域：SPI/source配置域与2 MHz系统域  
> ACTIVE联合配置宽度：1024 bit；V4=`[639:0]`, `schema_version=8'h04`；V5=`[1023:640]`, payload 384 bit, `schema=8'h05`合同绑定  
> RTL语言：可综合Verilog-2001
> V1.0 STATIC_BIAS资格输入一致性勘误日期：2026-08-16  
> V1.0 STATIC_BIAS资格输入一致性勘误：增加2 MHz域已提交`i_static_characterization_enable`到manager的透明连接；不改变ACTIVE位图、CDC传输、生命周期或解包语义

## 1. 合同目的

本文冻结1024-bit ACTIVE V4/V5联合控制平面集成Wrapper的模块边界、CDC责任、生命周期输入、ACTIVE输出、唯一字段解包点和验证要求。

本Wrapper的唯一功能是把稳定的source-domain配置快照传输到2 MHz系统域，交给配置管理器完成COMMIT/START/STOP生命周期管理，再把合法ACTIVE快照交给唯一的字段解包器。它不重新解释配置算法，也不产生模拟波形。

本文与以下当前活动合同共同使用：

1. C04 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` V1.7；
2. C10 — `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.3；
3. C08 — `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` V1.11；
4. C09 — `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.9；
5. C02 — `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` V4.9；
6. C07 — `ppg_system_integration/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md` V1.1；
7. C24 — `ppg_system_integration/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` V1.5。

若字段所有权与本文冲突，以ACTIVE V4控制连接映射合同为准；若Wrapper端口和握手语义与本文冲突，以本文为准。

## 2. 实例层次与职责

Wrapper必须实例化且只允许实例化以下三个控制平面模块：

```text
source-domain snapshot
        |
        v
ppg_config_cdc_bridge (.C_CONFIG_WIDTH(1024))
        |
        | destination_config[1023:0] + destination_update
        v
ppg_system_config_manager
        ^
        | i_static_characterization_enable
        | 2 MHz域已提交表征控制资格
        |
        | active_config[1023:0] + lifecycle/epoch/status
        v
ppg_system_active_config_unpack
        |
         +--> named V4 outputs for AMI, frame scheduler and SAR wrapper
```

### 2.1 V1.6 formal parameter contract

| Parameter | Default | Legal range | Binding/check |
| --- | ---: | --- | --- |
| `C_CONFIG_WIDTH` | 1024 | exactly 1024 | Passed unchanged to `ppg_config_cdc_bridge`, manager and unpacker; any mismatch is an elaboration error. |
| `C_CONFIG_EPOCH_WIDTH` | 8 | >=1 | Passed unchanged to manager/unpacker and checked against Top. |
| `C_RUN_GENERATION_WIDTH` | 8 | >=1 | Passed unchanged to manager and transparent generation outputs; wrapper never produces or increments it. |

The wrapper has one source-domain 1024-bit shadow/CDC path and one 2 MHz
manager/unpacker path. No implicit concatenation, truncation or zero-extension
is legal at an instance boundary.

Wrapper不得在内部实例化：

- SPI slave、SPI地址译码或反向状态CDC；
- AMI、400 Hz调度器、SAR9/SAR15时序模块；
- Stage1/Stage2/DC算法或IDAC搜索算法；
- `control_abort_event`故障汇总器；
- AMB专用模拟波形发生器。

## 3. 时钟、复位与CDC边界

### 3.1 source配置域

以下输入属于source配置时钟域：

| 端口 | 宽度 | 语义 |
| --- | ---: | --- |
| `i_source_clk` | 1 | 配置快照源时钟 |
| `i_source_rstn` | 1 | source域低有效复位 |
| `i_source_config_snapshot` | 1024 | 已完整组装的V4/V5联合shadow快照；`[639:0]=V4`, `[1023:640]=V5` |
| `i_source_config_update_event` | 1 | 请求传输当前1024-bit快照的单周期事件 |

Wrapper必须将`i_source_config_snapshot`和`i_source_config_update_event`连接到CDC bridge的同名source输入。

CDC bridge实例必须显式覆盖：

```verilog
.C_CONFIG_WIDTH(1024)
```

不得依赖bridge当前的历史默认宽度123。

### 3.2 2 MHz系统域

以下输入属于2 MHz域。START、STOP和状态清除必须已经由上层事件CDC重建为单周期事件；`i_static_characterization_enable`是表征控制CDC已经注册提交的保持型电平，不得脉冲化：

| 端口 | 语义 |
| --- | --- |
| `i_clk` | 2 MHz系统控制时钟 |
| `i_rstn` | 2 MHz域低有效复位 |
| `i_start_event` | 已同步START事件 |
| `i_stop_event` | 已同步STOP事件 |
| `i_status_clear_event` | 已同步状态清除事件 |
| `i_system_fault_blocking` | supervisor经Top送达的注册阻断故障电平；只透明送manager并阻断START |
| `i_static_characterization_enable` | 表征控制CDC在2 MHz域已提交的STATIC_BIAS资格电平，直接送manager |

Wrapper不实现SPI命令CDC，也不把source域单拍直接连接到manager。

source域和2 MHz域复位分别由所属上层同步释放；Wrapper不重复实例化复位同步器。

## 4. 配置传输与COMMIT语义

配置传输路径固定为：

```text
i_source_config_update_event
    -> bridge source busy/transport
    -> bridge o_destination_update
    -> manager i_config_update_event
    -> manager校验V4+V5联合快照
    -> V4/V5均合法时原子更新两份ACTIVE并使config_epoch仅递增一次
```

必须严格区分以下三个事件：

1. `o_config_transport_busy`：CDC bridge仍有在途传输；
2. `o_commit_ack_event`：manager确认配置合法并成为ACTIVE；
3. `o_error_event`：manager拒绝当前配置或命令。

CDC传输完成不等于配置COMMIT成功。非法配置时，ACTIVE快照、所有epoch和生命周期状态不得改变。

`o_active_config[1023:0]`只允许来自manager的合法联合ACTIVE寄存器，不得来自source shadow快照。
非法V5字段、非法V5保留位或V4/V5任一失败时，旧V4、旧V5和旧`config_epoch`全部保持。

## 5. manager资格输入

以下输入必须原样连接到manager，不得由Wrapper根据计数器或其他valid信号推断：

| Wrapper输入 | 来源 | manager语义 |
| --- | --- | --- |
| `i_analog_ready` | 模拟偏置/参考/输入MUX安全层 | RUN启动资格 |
| `i_adc_idle` | ADC转换与DONE捕获汇总 | STOPPING排空资格 |
| `i_datapath_empty` | AMI保持型流水汇总 | 数字数据链排空资格 |
| `i_idac_idle` | AMI IDAC搜索和提交状态 | IDAC排空资格 |
| `i_analog_safe` | SAR/模拟时序安全层 | 模拟安全保持资格 |
| `i_system_fault_blocking` | supervisor `o_system_fault_blocking`经Top | 阻断START，不得被Wrapper或manager本地clear清除 |
| `i_static_characterization_enable` | 顶层唯一`flag_static_characterization_enable` | COMMIT/START的STATIC_BIAS配置资格 |

禁止用AMI数字`o_adc_chain_idle`替代物理`i_adc_idle`，也禁止用固定延时替代`i_analog_safe`。

STATIC_BIAS资格连接必须是透明逐位连接：

```verilog
.i_static_characterization_enable(i_static_characterization_enable)
```

Wrapper不得缓存、反相、脉冲化、重新同步或从640-bit ACTIVE、`run_profile`、`input_source`及source域表征字段重建该信号。该输入只参与manager的配置资格检查，不得占用V4保留位，也不得作为Wrapper输出再次生成第二个所有权副本。

## 6. 生命周期、清除和abort边界

以下manager输出必须保持原语义：

| 输出 | 使用者 | 语义 |
| --- | --- | --- |
| `o_active_valid` | AMI/调度器 | ACTIVE合法且可作为本轮运行配置 |
| `o_run_enable` | AMI/调度器 | 当前允许运行功能链 |
| `o_allow_new_transaction` | 调度器 | 当前允许发起新ADC事务 |
| `o_start_ack_event` | AMI/调度器 | START已经被合法接受 |
| `o_stop_ack_event` | AMI/调度器 | STOP已经接受并进入排空 |
| `o_run_generation` | Top | manager唯一产生的`C_RUN_GENERATION_WIDTH`注册generation；Wrapper仅逐位转发 |
| `o_stop_episode_active` | Top -> supervisor | manager唯一产生的注册STOP排空episode电平；Wrapper仅逐位转发 |

`i_status_clear_event`只送manager，且只清manager本地读状态。它不得作为
系统诊断clear送到AMI或任何其他功能模块；完整数字顶层必须独立注册
`flag_diag_clear_event`并按Top合同扇出。读状态不得隐式产生任一清除事件。

`control_abort_event`不属于本Wrapper输入输出协议，不由本Wrapper生成，也不得与STOP合并。它由后续系统故障汇总层在2 MHz域注册产生，直接连接需要撤销在途事务的功能模块。

### 6.1 V1.2 lifecycle routing closure

This wrapper forwards manager lifecycle inputs and outputs without converting
abort into STOP. The final Top alone supplies manager `i_stop_event` from its
registered merge of external STOP, supervisor stop request and external-abort
drain request. This wrapper has no `i_control_abort_event` port; Top sends its
separate owner-abort fanout directly to AMI, Scheduler and SSW. Manager is the
sole producer of `o_run_generation`; the wrapper only forwards the exact width
to Top. It also forwards manager `o_stop_episode_active` unchanged to Top,
which is the sole direct parent able to connect it to supervisor
`i_stop_episode_active`. No watchdog input may be inferred from `i_stop_event`,
abort, STOPPING state, ADC busy or a local wrapper register.

`i_system_fault_blocking` has the only legal wrapper path
`Top.flag_system_fault_blocking -> wrapper.i_system_fault_blocking ->
manager.i_system_fault_blocking`. The wrapper never latches, gates, clears,
combines or recreates this level. A high level blocks START in manager; it does
not itself become a STOP, abort, owner release or diagnostic-clear action.
Top drives this input low during reset. Wrapper `o_run_generation` and
`o_stop_episode_active` reset low because their manager source resets low; the
wrapper neither inserts a cycle nor emits a pulse during reset or reset
release.

The wrapper consumes the one AMI-owned `i_datapath_empty` and the independently
defined physical `i_adc_idle` (mapped only from Top
`flag_adc_physical_idle`), `i_idac_idle` and `i_analog_safe` predicates. None
may be inferred from another. Top's single registered
diagnostic-clear event is distinct from manager status clear and cannot release
an ACTIVE snapshot, owner, injection request or active fault. The wrapper does
not aggregate faults, implement test CDC, generate generation or calculate the
watchdog.

## 7. ACTIVE与epoch输出

Wrapper必须输出以下manager寄存字段：

| 输出 | 宽度 | 语义 |
| --- | ---: | --- |
| `o_active_config` | 1024 | 联合ACTIVE原子快照；V4=`[639:0]`、V5=`[1023:640]` |
| `o_active_valid` | 1 | ACTIVE启动资格 |
| `o_config_epoch` | 8 | 合法V4 COMMIT版本 |
| `o_coef_epoch` | 8 | Stage1系数版本 |
| `o_stage2_coef_epoch` | 8 | Stage2系数版本 |
| `o_dc_recovery_coef_epoch` | 8 | DC恢复系数版本 |

配置epoch不得替代AMI的AMB/DC code epoch，也不得替代调度器的frame_id或sample_index。

## 8. 唯一ACTIVE解包输出

Wrapper必须实例化`ppg_system_active_config_unpack`，并逐项导出其具名输出：

- `schema_version`、`run_profile`、`input_source`、`idac_mode`、`optical_mode`和`initial_precision`；
- AMB/DCS enable、polarity、校准有效标志和AMB重检间隔；
- AMB、RED DC、IR DC的manual/min/max码；
- AMB/DCS signed阈值和确认次数；
- 十个Stage1 Q16权重及offset；
- Stage2 gain/offset；
- SAR9/SAR15 DC恢复gain。
- V5检测字段：`slope_mode`、`fixed_slope_q16`、`alpha_q15`、`beta_q15`、
  `timing_adjust_ratio_q15`、`slope_min_q16`、`slope_max_q16`、
  `baseline_delta_q16`、`cross_hysteresis_q16`、lead窗口、确认计数、
  峰谷幅度/帧距、fine/reacquire窗口和`peak_valley_config_valid`。

所有输出保持unpack模块当前端口名称、位宽和signed属性。Wrapper不得重新切片、重新舍入、改变符号或组合计算这些字段。

功能模块只能使用这些具名输出，禁止重新读取或重新解释`o_active_config`。

## 9. V4未覆盖字段及V5边界

以下信号不属于ACTIVE V4位图，Wrapper不得把它们映射到V4保留位：

- RED/IR LEDDAC码；
- CHARACTERIZATION静态AMB/DC码；
- `static_characterization_enable`；
- `calibration_plan`、未来校准类型或实际AMB_CAL/DCS_CAL请求；
- 测试MUX控制；
- AMB专用模拟控制沿；
- V5字段不得进入V4保留位；V5 `[383:370]`必须为0，schema=`8'h05`不占payload。

这些检测信号由同一联合shadow/CDC/COMMIT路径提供。Wrapper不得增加第二个默认配置producer、校准计划输入或把实际校准请求回送manager预测检查。

## 10. 下游连接边界

Wrapper输出连接规则如下：

1. AMI消费run profile、IDAC模式/资格、IDAC码范围/阈值、Stage1/Stage2/DC恢复字段和配置epoch；
2. 400 Hz调度器消费run profile、input source、optical mode、initial precision以及manager生命周期输出；
3. SAR安全选择层消费已提交精度、调度器事务快照、AMI committed码和code epoch；
4. 任一功能模块不得直接消费source shadow、手动V4码或pending码；
5. Wrapper不负责downstream ready/valid汇合，统一事务fire由后续数字顶层按相应合同产生。

## 11. 输出状态与错误保持

Manager的ACK、error、sticky状态和最近错误码必须逐项透传，不得在Wrapper中重命名为另一种语义或自动清除。

复位期间：

- 不产生配置传输完成、COMMIT、START或STOP伪事件；
- ACTIVE、epoch和生命周期输出遵循manager复位值；
- source busy和destination update遵循CDC bridge复位协议。

## 12. 验收矩阵

Wrapper自检TB至少覆盖：

| 编号 | 场景 | 验收要求 |
| --- | --- | --- |
| AV4C-01 | 1024-bit联合传输 | source快照逐位到达manager，无截断、补零或重排；V4/V5边界固定 |
| AV4C-02 | 唯一解包 | manager ACTIVE逐位连接unpack，具名字段正确 |
| AV4C-03 | 合法COMMIT | ACTIVE和config_epoch原子更新，产生commit ACK |
| AV4C-04 | 非法COMMIT | ACTIVE、epoch和生命周期不改变，产生error |
| AV4C-05 | transport与commit区分 | bridge传输完成不冒充commit ACK |
| AV4C-06 | START资格 | 仅ACTIVE合法且五项系统资格满足时接受START |
| AV4C-07 | STOP排空 | STOP立即禁止新资格，只有ADC/datapath/IDAC/analog全部空闲后完成排空 |
| AV4C-08 | 状态清除 | 清除manager sticky，不隐式触发COMMIT/START/STOP |
| AV4C-09 | epoch独立性 | config、coef、stage2和DC recovery epoch逐项保持独立 |
| AV4C-10 | V4保留位 | 非零保留位拒绝COMMIT |
| AV4C-11 | NORMAL初始精度规则 | NORMAL且initial_precision为SAR15时拒绝COMMIT |
| AV4C-12 | 生命周期稳定 | READY/RUN/STOPPING中ACTIVE和解包字段稳定 |
| AV4C-13 | reset | 两域复位不产生迟到传输或生命周期事件 |
| AV4C-14 | source反压 | source busy期间保持快照和update请求，不丢失或重复 |
| AV4C-15 | signed字段 | 阈值、权重、offset和gain符号逐位保持 |
| AV4C-16 | V4字段隔离 | LEDDAC、静态码、测试MUX和检测参数不来自V4保留位 |
| AV4C-17 | 下游边界 | 输出只提供具名控制源，不产生重复配置解包或算法旁路 |
| AV4C-18 | abort隔离 | Wrapper不生成、不合并、不修改外部control_abort_event |
| AV4C-19 | STATIC_BIAS资格输入 | 顶层2 MHz已提交资格逐位直连manager；STATIC_BIAS+input_source=0在COMMIT/START返回0x14，且无ACTIVE或epoch副作用 |
| AV4C-20 | 系统阻断与episode透传 | `i_system_fault_blocking`逐位送manager并阻断START；manager的`o_run_generation`与`o_stop_episode_active`均无截断、重建或延迟语义变化地送达Top。 |
| AV4C-21 | 联合COMMIT拒绝 | V4或V5任一字段非法、V5保留位非零时，旧V4、旧V5及旧config_epoch同时保持且只产生error。 |
| AV4C-22 | V5资格门控 | reset profile的`peak_valley_config_valid=0`禁止正式peak/valley/cross/9-to-15/fine控制；仅合法联合COMMIT后的值可释放资格。 |

## 13. 工具验证要求

交付前必须完成：

1. formatter-AST严格门：RTL和TB均为0 error、0 strict warning；
2. 独立Verilog lint：0 error、0 warning；
3. Vivado `xvlog`、`xelab`和`xsim`；
4. AV4C-01～AV4C-19全部由真实信号比较通过；
5. Vivado综合：0 error、0 critical warning，Latch=0，Blackbox=0；
6. 记录LUT、寄存器、DSP、WNS/TNS及非阻断警告。

## 14. 正式冻结结论

V1.0正式冻结如下：

- 本Wrapper负责1024-bit V4/V5联合控制平面，不负责SPI物理协议；
- CDC bridge参数必须显式为1024 bit；
- manager是ACTIVE、生命周期和四类配置epoch的唯一寄存所有者；
- unpack是V4/V5字段唯一解释点；
- transport busy、commit ACK和error事件保持独立语义；
- START、STOP、状态清除使用2 MHz域同步事件；
- `i_static_characterization_enable`只从顶层2 MHz已提交表征控制网进入，并透明直连manager资格输入；
- abort由后续系统故障汇总层产生，不由本Wrapper生成；
- V4未覆盖的LED、CHARACTERIZATION静态码、测试MUX、AMB波形和检测参数不得占用保留位；
- AMI、400 Hz调度器和SAR安全选择wrapper由后续数字顶层连接；
- 本合同不改变既有manager、unpack、AMI、调度器或SAR wrapper的功能算法。
