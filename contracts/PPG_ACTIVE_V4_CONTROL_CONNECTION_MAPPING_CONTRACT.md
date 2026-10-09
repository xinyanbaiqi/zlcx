# PPG ACTIVE V4控制连接映射合同

> V1.7 fail-closed V5-gate revision, 2026-08-20: V4/V5 joint configuration, 1024-bit CDC/manager boundary, atomic COMMIT/config_epoch binding and the unique `peak_valley_config_valid` fanout to C20/C22/C23 are normative. The system closure verdict remains `NOT_CLOSED` until every matrix ledger and independent audit count is zero; implementation evidence is `EVIDENCE_PENDING`.
> Normative status: V1.7 is the sole current ACTIVE/control connection authority. Earlier V1.2-V1.6 versions are historical unless repeated by V1.7; they cannot create a direct Top-to-manager connection or remove a required wrapper forwarding path.

> 历史冻结记录（非规范）：V1.2-V1.6正式冻结内容保留用于变更追溯；当前唯一规范版本为本页眉声明的V1.7。  
> 冻结日期：2026-08-20  
> ACTIVE V4配置：640 bit，`schema_version=8'h04`；独立ACTIVE V5检测配置：384 bit，`schema=8'h05`（合同绑定，非payload字段）；联合配置载荷：1024 bit  
> 系统时钟域：2 MHz数字处理域  
> 适用RTL：`ppg_system_config_manager.v`、`ppg_system_active_config_unpack.v`、`ppg_adc_measurement_idac_integration.v`  
> V1.2修订：冻结ACTIVE合法组合、保留IDAC编码和校准事务资格边界
> V1.2光学模式勘误日期：2026-08-17
> V1.2光学模式勘误：明确`CHARACTERIZATION + EXTERNAL_TEST_CURRENT`仅允许`BOTH`、`RED_ONLY`或`IR_ONLY`；`OFF`仅属于安全关闭，不属于固定电流测量资格。
> 合同性质：只冻结控制来源、目标端口、稳定性和所有权，不定义400 Hz事务调度算法、SAR模拟波形或SPI地址协议
> 实现证据说明（非规范）：当前RTL/TB/XSim只能作为`EVIDENCE_PENDING`证据输入；本合同不以历史日志宣称配置管理器或最终顶层闭合。

## 1. 合同目的

本文冻结1024-bit联合ACTIVE控制平面（V4[639:0] + V5[383:0]）到现有ADC/IDAC/精度窗口集成链及后续系统集成层的唯一连接关系，避免：

- 在多个模块中重复解释ACTIVE位段；
- 把运行期状态、事务事件或IDAC committed码误当成静态配置；
- 把V4保留位或V5保留位静默解释为动态基线或峰谷检测参数；
- 在后续400 Hz调度器、SAR安全选择wrapper和完整数字顶层中形成配置来源歧义；
- 由未提交的SPI shadow值直接控制RUN期间的数字或模拟功能。

本文不改变V4位图、帧调度、owner deadline、Q1/Q2/Q3、RAW链或模拟时序；V5字段只通过独立联合配置端口进入检测链。

## 2. 依赖追踪与优先级

本合同是1024-bit联合ACTIVE（V4/V5）字段和组合语义的上游来源，不接受下游模块反向改写。依赖分为：

**规范依赖（可决定本合同语义）**

1. 用户确认的640-bit ACTIVE V4位图、384-bit V5位图和字段编码；
2. C03 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V1.7的联合配置快照和manager-wrapper边界；
3. C05 — `ppg_system_active_config_unpack/ppg_system_active_config_unpack_semantic_contract.md` V5的唯一字段解包规则。

**一致性引用（只用于实现对齐，不覆盖本合同）**

本合同是下游Config manager、Characterization、AMI、SSW和Top合同的字段语义来源，不反向依赖这些下游合同；具体实现证据由各下游合同分别记录。

发生冲突时采用以下优先级：

```text
用户最新明确确认
    > 本合同的控制连接和所有权
    > 规范依赖中的字段和快照边界
    > 一致性引用中的模块接口和局部协议
    > 旧数字顶层草案、handoff和历史RTL
```

旧512-bit配置说明、旧`ppg_dual_precision_top.v`和旧SPI静态精度控制不得覆盖本文。

## 3. 冻结范围

本文冻结：

1. 1024-bit联合快照（V4[639:0]、V5[1023:640]）从CDC目标域到配置管理器的连接；
2. 配置管理器ACTIVE输出到唯一解包器的连接；
3. ACTIVE V4具名字段到AMI wrapper及后续控制层的连接；
4. 配置、Stage1、Stage2和DC恢复epoch的连接；
5. START、STOP、状态清除和阻断撤销事件的所有权；
6. AMI排空状态返回配置管理器的连接；
7. `input_source`、`optical_mode`和IDAC committed码的后续归属；
8. V4未覆盖检测参数的V5隔离、合法性和资格策略。

本文不冻结：

- SPI物理帧格式、地址图和寄存器bank RTL；
- 400 Hz NORMAL、AMB_CAL和DCS_CAL事务的具体调度状态机；
- 红光/红外事务在一帧内的精确启动时刻；
- SAR9/SAR15模拟控制波形和安全选择wrapper内部实现；
- SPI物理地址协议；字段地址由独立寄存器合同定义，但不得改变本文联合载荷位图；
- P2S输出包格式、Pad、ESD和芯片顶层引脚。

## 4. 控制平面层次与唯一所有权

冻结层次如下：

```text
SPI寄存器/命令源域
        |
        | 完整1024-bit shadow快照和COMMIT请求
        v
ppg_config_cdc_bridge，C_CONFIG_WIDTH必须显式为1024
        |
        | destination_config[1023:0]
        | destination_update_event
        v
ppg_system_config_manager
        |
        | active_config[1023:0] + active_v4[639:0] + active_v5[383:0] + active_valid + config_epoch
        v
ppg_system_active_config_unpack
        |
        +--> ppg_adc_measurement_idac_integration
        +--> 后续400 Hz帧/校准事务调度器
        +--> 后续SAR9/SAR15安全选择wrapper
        +--> 后续模拟输入MUX控制层
```

所有权规则：

- `ppg_system_config_manager`是ACTIVE快照、生命周期状态和四类epoch的唯一寄存所有者；
- `ppg_system_active_config_unpack`是V4/V5位段的唯一功能解包点，只做组合选择和signed解释；
- V5 schema固定为`8'h05`，是合同/schema绑定，不占用V5 payload保留位；
- AMI wrapper是三路运行期IDAC committed码及其code epoch的唯一数字控制所有者；
- 精度窗口控制器是运行期committed精度的唯一所有者；
- 后续400 Hz调度器只消费具名配置、运行状态和保持型请求，不得重新解释`active_config[639:0]`；
- 后续SAR安全选择wrapper只消费committed精度、committed IDAC码和具名时序配置，不得读取SPI shadow值。

## 5. ACTIVE V4/V5联合位图

### 5.1 ACTIVE V4位段冻结

| 位范围 | 字段 | 格式 | 主要直接消费者 |
| --- | --- | --- | --- |
| `[7:0]` | `schema_version` | V4固定`8'h04` | manager校验、状态只读 |
| `[8]` | `run_profile` | 0 NORMAL，1 CHARACTERIZATION | AMI、后续帧调度器 |
| `[9]` | `input_source` | 0光电二极管，1外部测试电流 | 后续模拟输入MUX控制层 |
| `[11:10]` | `idac_mode` | 00 MANUAL，01 SEARCH_HOLD，10 SEARCH_TRACK，11 RESERVED且必须拒绝 | AMI、配置管理器 |
| `[13:12]` | `optical_mode` | 00双光，01红光，10红外，11安全关闭 | 后续帧调度器、SAR安全选择wrapper |
| `[14]` | `initial_precision` | 0 SAR9，1 SAR15 | AMI内部精度控制器 |
| `[15]` | `amb_enable` | AMB控制资格 | AMI |
| `[16]` | `dcs_enable` | 两色DC控制资格 | AMI |
| `[17]` | `amb_polarity` | AMB残差到码方向 | AMI |
| `[18]` | `dcs_polarity` | DCS残差到码方向 | AMI |
| `[19]` | `stage1_calibration_valid` | Stage1正式校准资格 | AMI |
| `[20]` | `stage2_calibration_valid` | Stage2正式校准资格 | AMI |
| `[21]` | `dc9_recovery_valid` | SAR9 DC恢复资格 | AMI |
| `[22]` | `dc15_recovery_valid` | SAR15 DC恢复资格 | AMI |
| `[31:23]` | `reserved_header_v4` | 必须为0 | manager校验 |
| `[39:32]` | `amb_manual_code` | unsigned 8 bit | AMI |
| `[47:40]` | `amb_code_min` | unsigned 8 bit | AMI |
| `[55:48]` | `amb_code_max` | unsigned 8 bit | AMI |
| `[63:56]` | `dcs_r_manual_code` | unsigned 8 bit | AMI |
| `[71:64]` | `dcs_r_code_min` | unsigned 8 bit | AMI |
| `[79:72]` | `dcs_r_code_max` | unsigned 8 bit | AMI |
| `[87:80]` | `dcs_ir_manual_code` | unsigned 8 bit | AMI |
| `[95:88]` | `dcs_ir_code_min` | unsigned 8 bit | AMI |
| `[103:96]` | `dcs_ir_code_max` | unsigned 8 bit | AMI |
| `[115:104]` | `amb_threshold_low` | signed 12-bit整数 | AMI |
| `[127:116]` | `amb_threshold_high` | signed 12-bit整数 | AMI |
| `[139:128]` | `dcs_threshold_low` | signed 12-bit整数 | AMI |
| `[151:140]` | `dcs_threshold_high` | signed 12-bit整数 | AMI |
| `[159:152]` | `amb_confirm_count` | unsigned 8 bit | AMI |
| `[167:160]` | `dcs_confirm_count` | unsigned 8 bit | AMI |
| `[427:168]` | `stage1_weight_q16_0..9` | 每项signed 26-bit Q16 | AMI |
| `[459:428]` | `stage1_offset_q16` | signed 32-bit Q16 | AMI |
| `[479:460]` | `stage2_gain_q16` | signed 20-bit Q16 | AMI |
| `[511:480]` | `stage2_offset_q16` | signed 32-bit Q16，加法截距 | AMI |
| `[543:512]` | `dc9_recovery_gain_q16` | signed 32-bit Q16 | AMI |
| `[575:544]` | `dc15_recovery_gain_q16` | signed 32-bit Q16 | AMI |
| `[591:576]` | `amb_recheck_interval_frames` | unsigned 16-bit完整NORMAL帧数 | AMI内部重检调度器 |
| `[639:592]` | `reserved_extension_v4` | 必须为0 | manager校验 |

### 5.2 合法运行组合

配置管理器在COMMIT阶段必须整组验证以下资格；任一条件失败时不得改变ACTIVE、`active_valid`或任何epoch：

| 运行组合 | 合法条件 |
| --- | --- |
| NORMAL_PPG | `input_source=PHOTODIODE`、`initial_precision=SAR9`；`idac_mode`可为MANUAL、SEARCH_HOLD或SEARCH_TRACK |
| CHARACTERIZATION纯RED | `input_source=PHOTODIODE`、`optical_mode=RED_ONLY`、`initial_precision=SAR9/SAR15`、`idac_mode=MANUAL` |
| CHARACTERIZATION固定电流 | `input_source=EXTERNAL_TEST_CURRENT`、`optical_mode=BOTH/RED_ONLY/IR_ONLY`、`initial_precision=SAR9/SAR15`、`idac_mode=MANUAL`；`EN_TEST=1`且LEDEN/LEDDAC关闭 |
| STATIC_BIAS | `run_profile=CHARACTERIZATION`、已提交`static_characterization_enable=1`、`input_source=EXTERNAL_TEST_CURRENT`；测量许可必须关闭 |

以下静态配置组合必须由配置管理器在COMMIT/START前拒绝并产生确定错误码：

```text
NORMAL_PPG + initial_precision=SAR15
NORMAL_PPG + input_source=EXTERNAL_TEST_CURRENT
CHARACTERIZATION + idac_mode=SEARCH_HOLD/SEARCH_TRACK
CHARACTERIZATION + PHOTODIODE + optical_mode!=RED_ONLY
CHARACTERIZATION + EXTERNAL_TEST_CURRENT + optical_mode=OFF
STATIC_BIAS + input_source=PHOTODIODE
idac_mode=2'b11
```

`optical_mode=OFF`仍可作为安全关闭状态使用，但不能与非`STATIC_BIAS`的
`CHARACTERIZATION + EXTERNAL_TEST_CURRENT`组合形成固定电流测量；该组合必须在COMMIT/START前拒绝，且不得产生波形、ADC owner或有效IDAC总线。

### 5.2 ACTIVE V5检测位段冻结

`ACTIVE_V5_DETECTION[383:0]`只能映射到联合配置载荷`[1023:640]`：
`joint_config[1023:640] = active_v5_detection[383:0]`，
`joint_config[639:0] = active_v4[639:0]`。不得隐式拼接、截断、符号扩展或
零扩展。所有V5字段在2 MHz域由manager已提交ACTIVE寄存器唯一产生，解包器
仅组合解释；SPI shadow、表征计算结果、默认常量和TB不得成为第二个运行期
producer。

| V5位段 | 字段 | 格式/合法性 | 唯一端口路径与最终功能消费者 |
| --- | --- | --- | --- |
| `[0]` | `slope_mode` | `0=FIXED`, `1=ADAPTIVE` | unpacker -> AMI -> PWI -> dynamic baseline |
| `[32:1]` | `fixed_slope_q16` | signed Q16，必须`<0`且在slope边界内 | unpacker -> AMI -> PWI -> dynamic baseline |
| `[48:33]`, `[64:49]`, `[80:65]` | `alpha_q15`, `beta_q15`, `timing_adjust_ratio_q15` | unsigned Q1.15，`[0,16'h7fff]` | unpacker -> AMI -> PWI -> dynamic baseline |
| `[112:81]`, `[144:113]` | `slope_min_q16`, `slope_max_q16` | signed Q16，必须`slope_min < slope_max < 0` | unpacker -> AMI -> PWI -> dynamic baseline |
| `[176:145]`, `[208:177]` | `baseline_delta_q16`, `cross_hysteresis_q16` | signed Q16 / unsigned Q16；hysteresis必须`>0` | unpacker -> AMI -> PWI -> dynamic baseline |
| `[224:209]`, `[240:225]` | `lead_min_frames`, `lead_max_frames` | unsigned 16，必须`lead_min <= lead_max` | unpacker -> AMI -> PWI -> dynamic baseline |
| `[244:241]`, `[248:245]` | `cross_confirm_count`, `no_cross_limit` | unsigned 4，均必须`>=1` | unpacker -> AMI -> PWI -> dynamic baseline |
| `[252:249]`, `[256:253]` | `peak_confirm_count`, `valley_confirm_count` | unsigned 4，均必须`>=1` | unpacker -> AMI -> PWI -> peak/valley |
| `[280:257]`, `[304:281]` | `direction_deadband`, `min_peak_valley_amplitude` | unsigned 24；amplitude必须`>0` | unpacker -> AMI -> PWI -> peak/valley |
| `[320:305]`, `[336:321]` | `min_peak_to_valley_frames`, `min_peak_to_peak_frames` | unsigned 16；均必须`>=1`且`PV<=PP` | unpacker -> AMI -> PWI -> peak/valley |
| `[352:337]`, `[368:353]` | `max_fine_window_frames`, `max_reacquire_frames` | unsigned 16，均必须`>=1` | unpacker -> AMI -> PWI -> precision controller |
| `[369]` | `peak_valley_config_valid` | 仅合法表征结果装入V5 shadow并经成功联合COMMIT后可为1 | unpacker `o_peak_valley_config_valid` -> AMI `i_peak_valley_config_valid` -> PWI `i_peak_valley_config_valid` -> C20/C22/C23同名正式输入；唯一注册扇出，禁止子模块本地重建 |
| `[383:370]` | `reserved_v5` | 必须全0；任一为1拒绝整次COMMIT | manager validation only; no unpacker/AMI/PWI child output |

V5 reset/default profile固定为：`slope_mode=ADAPTIVE`、
`fixed_slope_q16=-65536`、`slope_min_q16=-262144`、`slope_max_q16=-8192`、
`alpha_q15=16'h199A`、`beta_q15=16'h2000`、`timing_adjust_ratio_q15=16'h0800`、
`baseline_delta_q16=0`、`cross_hysteresis_q16=131072`、`lead_min_frames=17`、
`lead_max_frames=19`、`cross_confirm_count=3`、`no_cross_limit=2`、
`peak_confirm_count=3`、`valley_confirm_count=3`、`direction_deadband=2`、
`min_peak_valley_amplitude=20`、`min_peak_to_valley_frames=20`、
`min_peak_to_peak_frames=100`、`max_fine_window_frames=600`、
`max_reacquire_frames=1000`、`peak_valley_config_valid=0`、`reserved_v5=0`。
这是唯一V5复位值：它不构成第二个ACTIVE producer，也不具备启动正式检测资格。

当`peak_valley_config_valid=0`时，检测链必须继续安全地消费和排空样本，但不得发布
正式peak、valley、cross、9-to-15请求或正式fine-window控制；它可保留非阻断
诊断。只有片外表征已把完整合法V5快照写入同一source shadow、经同一CDC传输，
并由manager接受联合COMMIT，才可置该位为1。V5不定义表征算法、表征结果寄存器或
SPI地址；其唯一正式运行期producer仍是manager的active寄存器。

`AMB_CAL`和`DCS_CAL`是运行时事务类型，不属于640-bit ACTIVE字段。配置管理器不得使用
`amb_enable/dcs_enable`猜测校准请求，也不增加`calibration_plan`字段或计划端口。系统仍必须在任何校准波形、ADC owner或结果事务启动前拒绝以下运行时组合：
`CHARACTERIZATION + AMB_CAL/DCS_CAL`以及`SAR15 + AMB_CAL/DCS_CAL`。
上述四项的可判定拒绝责任固定给Scheduler/AMI事务资格层；不得声称仅凭ACTIVE COMMIT已经完成该检查，也不得复用ACTIVE位、`amb_enable/dcs_enable`或信号名称预测未来请求。

### 5.3 ACTIVE组合校验所有权

配置管理器负责COMMIT/START前可由ACTIVE快照和已提交STATIC_BIAS资格直接判定的profile、source、
precision、IDAC和静态源组合；调度器/AMI负责运行时AMB_CAL/DCS_CAL请求、CHARACTERIZATION隔离
以及SAR15校准禁止。两者不得用同一字段重复解释或形成组合反馈环。

```text
COMMIT/START前：配置管理器检查静态配置组合
RUN期间：Scheduler/AMI检查实际校准事务资格
```

ACTIVE V4不包含校准计划、未来frame type或待执行校准队列；不得为统一责任边界增加`calibration_plan`字段。

### 5.2 禁止重复解包

最终集成层不得再次编写类似以下逻辑：

```verilog
assign cfg_idac_mode = active_config[11:10];
```

所有功能模块必须连接`ppg_system_active_config_unpack`的具名输出。只有配置管理器允许直接读取原始位段执行整组合法性检查。

## 6. 配置管理器到ACTIVE解包器

固定连接：

| 源 | 目的 | 规则 |
| --- | --- | --- |
| manager `o_active_config[1023:0]` | unpack `i_active_config[1023:0]` | 联合载荷逐位直连；V4 `[639:0]`与V5 `[1023:640]`均不得截断、补零或重排 |
| manager `o_active_valid` | AMI `i_active_config_valid` | 直接连接，不能由schema比较替代 |
| unpack `o_schema_version` | 状态只读/集成诊断 | 不作为ADC启动脉冲或RUN使能 |

`o_active_config[1023:0]`只在V4/V5均合法的联合COMMIT时原子替换；`config_epoch`只递增一次。解包器是纯组合逻辑，不保存第二份ACTIVE副本，也不生成新epoch。

## 7. ACTIVE V4到AMI wrapper逐端口连接

### 7.1 运行模式和IDAC控制

| unpack输出 | AMI输入 |
| --- | --- |
| `o_run_profile` | `i_run_profile` |
| `o_initial_precision` | `i_initial_precision` |
| `o_idac_mode` | `i_idac_mode` |
| `o_amb_enable` | `i_amb_enable` |
| `o_dcs_enable` | `i_dcs_enable` |
| `o_amb_polarity` | `i_amb_polarity` |
| `o_dcs_polarity` | `i_dcs_polarity` |
| `o_amb_manual_code` | `i_amb_manual_code` |
| `o_amb_code_min` | `i_amb_code_min` |
| `o_amb_code_max` | `i_amb_code_max` |
| `o_dcs_r_manual_code` | `i_dcs_r_manual_code` |
| `o_dcs_r_code_min` | `i_dcs_r_code_min` |
| `o_dcs_r_code_max` | `i_dcs_r_code_max` |
| `o_dcs_ir_manual_code` | `i_dcs_ir_manual_code` |
| `o_dcs_ir_code_min` | `i_dcs_ir_code_min` |
| `o_dcs_ir_code_max` | `i_dcs_ir_code_max` |
| `o_amb_threshold_low` | `i_amb_threshold_low` |
| `o_amb_threshold_high` | `i_amb_threshold_high` |
| `o_dcs_threshold_low` | `i_dcs_threshold_low` |
| `o_dcs_threshold_high` | `i_dcs_threshold_high` |
| `o_amb_confirm_count` | `i_amb_confirm_count` |
| `o_dcs_confirm_count` | `i_dcs_confirm_count` |

### 7.2 Stage1、Stage2和DC恢复

以下连接全部逐位直连并保持signed语义：

| unpack输出 | AMI输入 |
| --- | --- |
| `o_stage1_calibration_valid` | `i_stage1_calibration_valid` |
| `o_stage1_weight_q16_0..9` | `i_stage1_weight_q16_0..9` |
| `o_stage1_offset_q16` | `i_stage1_offset_q16` |
| `o_stage2_calibration_valid` | `i_stage2_calibration_valid` |
| `o_stage2_gain_q16` | `i_stage2_gain_q16` |
| `o_stage2_offset_q16` | `i_stage2_offset_q16` |
| `o_dc9_recovery_valid` | `i_dc9_recovery_valid` |
| `o_dc15_recovery_valid` | `i_dc15_recovery_valid` |
| `o_dc9_recovery_gain_q16` | `i_dc9_recovery_gain_q16` |
| `o_dc15_recovery_gain_q16` | `i_dc15_recovery_gain_q16` |

禁止在顶层重新舍入、缩位、取绝对值、改变Stage2 offset符号或组合计算DC恢复系数。

### 7.3 AMB周期重检间隔

固定连接：

```text
unpack.o_amb_recheck_interval_frames
    -> AMI.i_amb_recheck_interval_frames
    -> AMI内部ppg_precision_window_integration
    -> AMI内部ppg_amb_recheck_scheduler
```

后续400 Hz物理帧/校准事务调度器不得再次维护AMB重检周期计数，也不得直接使用该字段重新判断是否到期。它只消费AMI输出的保持型校准请求：

```text
o_calibration_sample_valid
o_calibration_frame_type
o_calibration_color_ir
o_calibration_precision_mode
o_calibration_request_reason
```

该规则避免出现两个周期计数器、两个pending所有者或重复启动同一重检序列。

## 8. `input_source`和`optical_mode`归属

### 8.1 `input_source`

`unpack.o_input_source`只连接后续模拟输入MUX控制层。它不连接AMI wrapper，也不改变ADC数字结果路由、frame type或IDAC模式。

冻结语义：

```text
0: PHOTODIODE
1: EXTERNAL_TEST_CURRENT
```

输入MUX必须在后续模拟安全合同定义的边界提交，不得在ADC积分或转换中途改变。

### 8.2 `optical_mode`

`unpack.o_optical_mode`连接：

1. 后续400 Hz帧/校准事务调度器，用于确定允许产生的颜色事务；
2. 后续SAR9/SAR15安全选择wrapper，用于选择相应红光/红外模拟相位。

它不直接连接AMI内部router，也不允许作为运行期精度选择信号。

冻结编码：

```text
2'b00: 红光和红外
2'b01: 仅红光
2'b10: 仅红外
2'b11: 安全关闭，不产生新的NORMAL或校准ADC事务
```

调度器事务颜色与SAR模拟相位必须来自同一ACTIVE快照，禁止一侧使用旧模式而另一侧使用新模式。

## 9. IDAC码所有权与模拟时序连接

V4中的manual/min/max字段只配置IDAC算法，不是运行期模拟输出码。

后续SAR安全选择wrapper和模拟时序层必须使用AMI的committed输出：

| AMI输出 | 用途 |
| --- | --- |
| `o_amb_code` | 当前唯一AMB committed码 |
| `o_dcs_r_code` | 当前红光DC committed码 |
| `o_dcs_ir_code` | 当前红外DC committed码 |
| `o_amb_code_epoch` | AMB码版本 |
| `o_dcs_r_code_epoch` | 红光DC码版本 |
| `o_dcs_ir_code_epoch` | 红外DC码版本 |

每笔ADC事务启动上下文必须快照实际参与积分的committed码和对应epoch。不得把V4 manual码直接连接模拟IDAC，也不得在pending候选尚未安全提交时提前改变模拟输出。

## 10. 生命周期和事件连接

### 10.1 配置管理器到AMI

| manager输出 | AMI输入 | 语义 |
| --- | --- | --- |
| `o_active_valid` | `i_active_config_valid` | 当前ACTIVE整体合法 |
| `o_run_enable` | `i_run_enable` | RUN电平资格 |
| `o_allow_new_transaction` | `i_allow_new_transaction` | 新ADC事务总门控 |
| `o_start_ack_event` | `i_start_ack_event` | 新RUN初始化单拍 |
| `o_stop_ack_event` | `i_stop_ack_event` | 进入STOPPING排空单拍 |

`o_commit_ack_event`只用于控制平面应答和状态回传，不得代替`o_start_ack_event`初始化AMI。

### 10.2 状态清除

`i_status_clear_event`是control-plane wrapper到manager的本地读状态清除，
不属于系统诊断清除，也不得扇出到AMI。唯一系统诊断清除由Top注册的
`flag_diag_clear_event`产生，并按Top合同直接送AMI、Scheduler、SSW和
supervisor，再由AMI/PWI向内部消费者转发。读状态寄存器不得隐式产生任一
清除事件；同拍STOP抢占START、COMMIT和两类clear。

### 10.3 阻断撤销

`AMI.i_control_abort_event`不是ACTIVE字段，也不是普通STOP。它由Top在2 MHz域注册合并supervisor blocking-fault abort与外部`i_control_abort_event`后产生；外部abort本身不生成first-fault snapshot或`SYSTEM_FAULT` discard reason。该owner-abort事件必须满足：

- 在2 MHz域注册为单周期事件；
- 撤销AMI内部在途控制、pending和未提交请求；
- 不修改ACTIVE快照和四类配置epoch；
- 不直接由`AMI.o_wrapper_fault_blocking`组合反馈生成，避免组合环；
- 不冒充配置管理器的`i_stop_event`或`o_stop_ack_event`。

完整数字顶层是唯一自动故障停机和外部abort-drain的合并点：本映射合同不得
新增manager abort端口，也不得把AMl/SSW/Scheduler abort重解释为STOP。

### 10.4 lifecycle, generation and diagnostic routing

The manager is the sole `run_generation` producer. Its
`o_run_generation[C_RUN_GENERATION_WIDTH-1:0]` crosses the Top only as
`flag_run_generation`, then fans unchanged only to Scheduler, AMI and SSW.
AMI and PWI own the hierarchical forwarding to their contained Router,
reconstructor and detection chain. ACTIVE mapping and Top do not create,
increment, cache or reinterpret this field.

Top is the only registered merge point for external STOP, the supervisor
`o_system_stop_request_event` and its separately registered external-abort
drain request; its output alone reaches manager `i_stop_event`. Supervisor or
external owner-abort separately reaches AMI/Scheduler/SSW
`i_control_abort_event` and never becomes a manager port. Manager
`o_stop_episode_active` reaches only supervisor `i_stop_episode_active` for
watchdog eligibility.

One Top `flag_diag_clear_event` fans unchanged to direct diagnostic consumers
AMI, Scheduler, SSW and supervisor; AMI/PWI forward it internally. manager
`i_status_clear_event` is separate and local. A clear cannot release an owner
or active cause. `flag_adc_physical_idle` is one pre-Top synchronized physical
level mapped unchanged to each retained legacy `i_adc_idle` port of AMI,
Scheduler, SSW, manager and ACTIVE wrapper, and to supervisor
`i_adc_physical_idle`. It is not a completion or `datapath_empty` substitute.

AMI's `o_datapath_empty` is the only digital-drain connection to the manager.
All Supervisor fault record groups, reason codes and watchdog parameters follow
the closure matrix without implicit width conversion.

### 10.5 Mandatory manager-wrapper safety paths

The following table replaces any older direct manager-to-Top shorthand. Manager
is nested inside the ACTIVE wrapper; Top can only use the wrapper ports shown.

| Producer | Wrapper port | Top net | Final consumer | Meaning |
| --- | --- | --- | --- | --- |
| supervisor `o_system_fault_blocking` | `i_system_fault_blocking` | `flag_system_fault_blocking` | manager `i_system_fault_blocking` | Registered high level rejects START and prevents generation increment. It is neither abort nor STOP. |
| manager `o_run_generation[C_RUN_GENERATION_WIDTH-1:0]` | `o_run_generation[C_RUN_GENERATION_WIDTH-1:0]` | `flag_run_generation[C_RUN_GENERATION_WIDTH-1:0]` | Scheduler/AMI/SSW `i_run_generation` | Manager-only generation production; wrapper and Top are bit-transparent. |
| manager `o_stop_episode_active` | `o_stop_episode_active` | `flag_stop_episode_active` | supervisor `i_stop_episode_active` | Registered proof that accepted STOP/system-STOP/external-abort drain may arm watchdog counting. |

No active contract may connect `o_stop_episode_active` directly through a
nonexistent Top manager instance, or omit `i_system_fault_blocking` from either
wrapper or manager. The wrapper shall not latch, synthesize or clear any signal
in this table.

## 11. epoch连接和语义

固定连接：

| manager输出 | AMI输入 | 事务语义 |
| --- | --- | --- |
| `o_config_epoch` | `i_config_epoch` | 完整ACTIVE提交版本 |
| `o_coef_epoch` | `i_stage1_coef_epoch` | Stage1正式系数组版本 |
| `o_stage2_coef_epoch` | `i_stage2_coef_epoch` | Stage2正式系数组版本 |
| `o_dc_recovery_coef_epoch` | `i_dc_recovery_coef_epoch` | DC恢复字段组版本 |

规则：

- epoch只能由配置管理器产生；
- 解包器不得重建或修改epoch；
- 调度器不得用`frame_id`、`sample_index`或code epoch代替配置epoch；
- 已接受ADC事务继续使用启动时快照，后续COMMIT不得污染在途事务；
- code epoch由AMI内部IDAC控制器产生，与四类配置epoch独立。

## 12. 排空和启动资格反向连接

固定反向连接：

| AMI输出 | manager输入 |
| --- | --- |
| `o_datapath_empty` | `i_datapath_empty` |
| `o_idac_idle` | `i_idac_idle` |

以下manager输入来自后续模拟/SAR安全层，不得用AMI数字idle冒充：

| manager输入 | 唯一语义来源 |
| --- | --- |
| `i_analog_ready` | 模拟偏置、参考和输入选择已具备RUN资格 |
| `i_adc_idle` | 无物理ADC转换且异步DONE均已回到非活动状态 |
| `i_analog_safe` | STOP或切换边界下模拟控制已进入安全保持状态 |

AMI的`o_adc_chain_idle`只证明数字捕获至Stage1流水排空，不能替代物理`i_adc_idle`。

## 13. 后续400 Hz调度器的V4输入边界

本文只冻结后续调度器可消费的控制来源，不冻结其状态机。

允许直接连接的V4/生命周期输入包括：

```text
run_profile
input_source，仅用于调度资格或诊断，不直接驱动数字router
optical_mode
manager.active_valid
manager.run_enable
manager.allow_new_transaction
AMI.active_precision_mode
AMI.normal_measurement_eligible
AMI.switch_hold_new_transaction
AMI.wrapper_fault_blocking
```

校准事务来源固定为AMI的保持型校准请求接口。调度器不得根据`idac_mode`、重检间隔或IDAC内部状态自行合成第二套启动搜索/周期重检状态机。

具体NORMAL与校准优先级、frame_id/sample_index生成、每帧事务数量、ready/valid和完成事件将在后续`400 Hz帧/校准事务调度器接口合同`中冻结。

## 14. V4未覆盖的检测配置

以下AMI输入不属于ACTIVE V4，且只从V5具名解包输出进入AMI：

```text
i_slope_mode
i_fixed_slope_q16
i_alpha_q15
i_beta_q15
i_timing_adjust_ratio_q15
i_slope_min_q16
i_slope_max_q16
i_baseline_delta_q16
i_cross_hysteresis_q16
i_lead_min_frames
i_lead_max_frames
i_cross_confirm_count
i_no_cross_limit
i_peak_confirm_count
i_valley_confirm_count
i_direction_deadband
i_min_peak_valley_amplitude
i_min_peak_to_valley_frames
i_min_peak_to_peak_frames
i_max_fine_window_frames
i_max_reacquire_frames
i_peak_valley_config_valid
```

冻结规则：

1. 不得解释V4的`[639:592]`或`[31:23]`来驱动这些端口；
2. V5已固定为联合载荷`[1023:640]`、schema绑定`8'h05`、同一manager校验和同一解包器；
3. V5 reset/default profile是manager复位ACTIVE的唯一值，不能由TB或各实例匿名常量覆盖；
4. V5字段必须在整个RUN期间稳定，并与`config_epoch`原子绑定；
5. `peak_valley_config_valid=0`时禁止正式peak/valley/cross/9-to-15/fine-window控制；
6. 不得因为默认值可工作而绕过合法联合COMMIT或重新解释V4保留位。

## 15. RUN期间稳定性

合法COMMIT只允许在配置管理器的CONFIG状态接纳。进入READY或RUN后：

- `o_active_config[1023:0]`保持不变；V4 `[639:0]`和V5 `[1023:640]`均不得热更新；
- 所有解包字段保持不变；
- config、Stage1、Stage2和DC恢复epoch保持不变；
- SPI shadow写入不能越过CDC/COMMIT路径直接影响功能模块；
- 只有运行期committed精度、IDAC committed码、code epoch和事务状态允许按各自功能合同变化。

NORMAL运行要求`initial_precision=0`。配置管理器必须在COMMIT/START前拒绝NORMAL与`initial_precision=1`组合；若异常集成仍使该组合到达AMI，精度控制器仍按其合同强制安全SAR9并置协议诊断。该纵深保护不替代配置管理器拒绝。

## 16. 禁止连接

以下实现违反本合同：

1. 把ACTIVE V4截断成512 bit或在旧512-bit总线高位拼接常量；
2. 在顶层、调度器、SAR wrapper或AMI内部重复硬编码ACTIVE位段；
3. 使用SPI shadow、实时SPI位或未完成COMMIT的值控制RUN；
4. 把`input_source`解释为IDAC模式、frame type或精度模式；
5. 把`optical_mode`直接当作ADC结果router选择；
6. 把V4 manual码直接连接模拟IDAC输出；
7. 把IDAC pending候选码当作committed码；
8. 由外部400 Hz调度器重复维护AMB重检间隔计数；
9. 用`commit_ack_event`代替START初始化事件；
10. 用AMI数字idle替代物理ADC idle或模拟safe；
11. 从AMI阻断输出组合反馈到其`control_abort_event`输入；
12. 把配置epoch、code epoch、frame_id和sample_index互相替代；
13. 占用V4保留位连接动态基线或峰谷参数；
14. 在RUN中直接热更新任何V4或临时检测配置；
15. 由多个模块分别保存和提交第二份ACTIVE配置副本。

## 17. 后续集成验收项

后续控制平面wrapper或数字顶层TB至少覆盖：

| 编号 | 场景 | 验收要求 |
| --- | --- | --- |
| AV4-01 | 1024-bit逐位连接 | manager联合ACTIVE到unpack无截断、补零或重排；V4/V5边界精确为639/640 |
| AV4-02 | 唯一解包 | 功能模块只使用具名输出，不重复切片原始ACTIVE |
| AV4-03 | IDAC字段连接 | mode、enable、polarity、码范围、阈值和确认次数逐项到AMI |
| AV4-04 | Stage1连接 | 十个权重、offset、valid和epoch逐位一致 |
| AV4-05 | Stage2连接 | gain、加法offset、valid和epoch逐位一致 |
| AV4-06 | DC恢复连接 | 两组gain、valid和epoch逐位一致 |
| AV4-07 | 重检周期单所有者 | 只有AMI内部scheduler计数，外部调度器只消费校准请求 |
| AV4-08 | committed IDAC输出 | 模拟层使用AMI committed码，不使用V4 manual或pending码 |
| AV4-09 | 生命周期 | START、STOP、RUN和allow-new连接无替代或组合旁路 |
| AV4-10 | 状态清除 | manager local status clear与Top唯一系统diagnostic clear分离；后者不经wrapper送AMI |
| AV4-11 | 排空返回 | AMI datapath empty和IDAC idle正确返回manager |
| AV4-12 | 模拟资格隔离 | analog ready、ADC idle和analog safe来自物理/时序层 |
| AV4-13 | epoch原子性 | 在途事务保持旧快照，新事务使用新epoch |
| AV4-14 | optical安全关闭 | `optical_mode=11`不产生新NORMAL或校准事务 |
| AV4-15 | V4保留位 | 两个保留区非零时COMMIT拒绝，ACTIVE和epoch不变 |
| AV4-16 | V5参数隔离 | 检测参数只来自V5具名解包输出；V5保留位非零拒绝，默认profile不形成第二producer |
| AV4-17 | abort无组合环 | 阻断撤销为2 MHz注册单拍，不形成AMI自反馈组合路径 |
| AV4-18 | RUN稳定性 | RUN期间ACTIVE、解包字段和配置epoch全部稳定 |
| AV4-19 | 校准责任边界 | manager只检查静态组合且ACTIVE无`calibration_plan`；实际CHARACTERIZATION/SAR15校准请求由Scheduler/AMI在波形与owner启动前拒绝 |

本合同本身不要求新建RTL或单独TB。上述验收项应在后续V4控制平面集成wrapper和最终数字顶层回归中实现。

## 18. 正式冻结结论

V1.2正式冻结为：

- ACTIVE V4固定640 bit，`schema_version=8'h04`；
- 配置管理器是ACTIVE、生命周期和四类配置epoch的唯一所有者；
- ACTIVE解包器是唯一功能字段解释点；
- V4既有IDAC、Stage1、Stage2、DC恢复和AMB重检间隔字段逐项连接AMI；
- AMB重检间隔只由AMI内部scheduler消费，外部400 Hz调度器不重复计数；
- `input_source`归属模拟输入MUX层，`optical_mode`归属帧调度和SAR安全选择层；
- 模拟IDAC只使用AMI committed码及其code epoch；
- 生命周期、状态清除、abort、epoch和反向排空连接按本文固定；
- 动态基线和峰谷检测参数不属于V4，不得占用V4保留位；
- ACTIVE不保存校准计划；配置管理器检查静态组合，Scheduler/AMI检查RUN期间实际校准事务资格；
- 本合同只冻结控制连接，不定义400 Hz调度算法、SAR模拟时序或SPI物理协议。

下一步应基于本文讨论并冻结`400 Hz帧/校准事务调度器接口合同`。
