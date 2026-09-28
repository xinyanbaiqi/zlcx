# PPG IDAC码控制器V2逐端口接口合同

> Current normative version: V2.3, 2026-08-30. Bucket-1 RTL session (dedicated SID-11+LFA-06+OIB-01+LFA-10(b) session): adds module parameter `C_ENABLE_TEST_INJECTION`（默认0，生产网表必须为0）and a verification-only injection pair `i_test_saturation_inject_valid`/`o_test_saturation_inject_ready`，与AMI已有的`i_test_identity_inject_*`同一约定：只在`C_ENABLE_TEST_INJECTION!=0`且`i_test_inject_enable=1`时可用，`o_test_saturation_inject_ready`只在真实AMB/DCS样本本拍参与`flag_amb_sample_qualified`/`flag_dcs_sample_qualified`判定时可以接纳，直接覆盖判据里的双向饱和判据项，不touch共享的`i_search_saturation_low`/`i_search_saturation_high`输入线（第一版曾尝试force这两根共享网线导致污染其它真实消费者，见SID-11原始调查记录）。用于真实构造SID-11（此前记录为结构性不可达的双向饱和拒绝路径，因为真实RAW值无法让两个饱和标志同时为真）。真实证据：`tb_ppg_control_top_startup_idac_calibration.v` SID-11（V1.1，iverilog+Vivado 2022.2 xsim双工具confirmed）。不改变本合同任何既有IDC2-XX编号条款的行为，不touch任何既有生产信号路径。
> Current normative version: V2.2, 2026-08-20. Status: `ACTIVE_NORMATIVE`; the V2 interface remains normative, but the system closure verdict is `NOT_CLOSED` until the current matrix audit records zero defects. RTL/TB evidence is `EVIDENCE_PENDING`.
> V2.2 change record: adds the previously omitted formal `C_RUN_GENERATION_WIDTH` parameter to the parameter table and requires the AMI equality check. No IDAC search, tracking, fault or code-epoch semantic changes.  
> Historical V2.2 freeze date: 2026-08-07.
> 目标RTL：`ppg_idac_code_controller.v`  
> 时钟域：2 MHz数字处理域  
> 配置格式：联合ACTIVE固定1024 bit；本模块仅消费V4 `[639:0]` 中的IDAC字段。V5检测 `[1023:640]` 不进入IDAC，统一由AMI->PWI检测链消费。

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C02 | `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` | V4.9 | RUN lifecycle and committed ACTIVE ownership. |
| C05 | `ppg_system_active_config_unpack/ppg_system_active_config_unpack_semantic_contract.md` | V5 | Sole decoded V4 IDAC-field interpretation. |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.1 | AMI parent, transaction context and AMI-only blocking-fault record promotion. |
| C16 | `ppg_system_integration/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md` | V2 | Sole NORMAL tracking and AMB-recheck transaction source. |
| C24 | `ppg_system_integration/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` | V1.5 | System blocking-fault consumption after the required AMI record-promotion boundary. |

## 1. 合同目的

本文冻结新版`ppg_idac_code_controller`的模块职责、逐端口名称、方向、位宽、握手、搜索、慢速跟踪、
安全提交、版本标签和故障行为。后续RTL和自检TB必须以本文为直接接口真源。

本文中的“搜索/检查样本入口”替代容易误解的“校准入口”称呼。该入口接收的不是未校准ADC码，而是
`ppg_adc_s1_programmable_calibrator`已经产生的`signed 12-bit calibrated_s1_value`；AMB_CAL和DCS_CAL
只是该样本所属的模拟采样序列类别。

## 2. 模块职责与边界

### 2.1 必须负责

控制器统一拥有三组逻辑IDAC状态：

```text
AMB_CODE
DC_CODE_R
DC_CODE_IR
```

控制器必须：

1. 在MANUAL模式装入三路ACTIVE手动码；
2. 在自动模式按AMB、DC_R、DC_IR顺序执行8-bit受限二分搜索；
3. 在SEARCH_TRACK的NORMAL阶段用合格NORMAL事务慢速跟踪DC_R/DC_IR；
4. 接受周期AMB重检上下文，必要时重搜AMB；
5. AMB码实际变化后请求DC_R/DC_IR重新验证；
6. 将所有候选先保存为pending，只在`i_frame_safe_boundary`提交；
7. 输出三组committed码、独立4-bit code epoch、更新事件和诊断状态；
8. 消费但忽略不具备资格的NORMAL跟踪事务，避免阻塞PPG测量链。

SAR9和SAR15共用上述三组逻辑码、pending、确认计数、搜索状态和code epoch；精度切换不复制或重置状态。

### 2.2 不得负责

控制器不得：

- 拥有SPI shadow/live/commit寄存器；
- 使用旧版`i_detect_code[8:0]`作为闭环主输入；
- 使用Stage2、15-bit重构结果或DC恢复后的PPG值调节IDAC；
- 直接控制LED、ADC启动、模拟开关或帧计数；
- 自行产生AMB_CAL/DCS_CAL事务；
- 使用`settle_sample_count`丢弃完整400-Hz样本；
- 在非帧安全边界修改committed码；
- 在NORMAL事务中直接调整AMB码。

## 3. 固定参数、编码和比较数值

### 3.1 参数

| 参数 | 冻结默认值 | 语义 |
| --- | ---: | --- |
| `C_FRAME_ID_WIDTH` | 16 | R/IR共享采样帧编号宽度 |
| `C_SAMPLE_INDEX_WIDTH` | 16 | 全局ADC事务编号宽度 |
| `C_IDAC_CODE_WIDTH` | 8 | 三路IDAC逻辑码宽度 |
| `C_CODE_EPOCH_WIDTH` | 4 | 每路码安全提交版本宽度 |
| `C_CONFIG_EPOCH_WIDTH` | 8 | ACTIVE配置版本宽度 |
| `C_COEF_EPOCH_WIDTH` | 8 | Stage1系数组版本宽度 |
| `C_RUN_GENERATION_WIDTH` | 8 | manager唯一产生、AMI逐层传入的RUN代际宽度；必须等于AMI `C_RUN_GENERATION_WIDTH`，不允许截断或硬编码。 |
| `C_RESET_CODE` | 0 | 复位及禁用路径的安全数字码 |

本控制器不得增加决定架构行为的隐藏参数。阈值、确认次数、极性和码范围全部来自ACTIVE V4端口。

> **命名澄清（2026-09-02，解决2026-08-31全系统复审发现的命名歧义）**：`C_IDAC_CODE_WIDTH=8`
> 在SAR9与SAR15两种精度模式下统一使用、无截断无差异，`i_track_precision_mode`只选择R/IR
> 计数器来源，不参与码宽选择（见第409/596行）。"SAR9"/"SAR15"这两个名字指的是ADC**转换
> 精度模式**（9位/15位采样精度），不是IDAC补偿码本身的位宽——不存在、也不需要一个9-bit宽
> 的码字段。若需求文字里出现"9位码"，指的是SAR9这个模式名，不是对`C_IDAC_CODE_WIDTH`的
> 位宽要求。详见memory `project-ppg-full-system-audit-20260831`。

### 3.2 模式编码

| `i_idac_mode` | 名称 | 行为 |
| --- | --- | --- |
| `2'b00` | MANUAL | 启动时装入手动码，随后保持 |
| `2'b01` | SEARCH_HOLD | 启动搜索完成后保持，不慢速跟踪、不周期重检 |
| `2'b10` | SEARCH_TRACK | 启动搜索后允许DC慢速跟踪和AMB周期重检 |
| `2'b11` | RESERVED | ACTIVE COMMIT必须拒绝，控制器不定义运行行为 |

### 3.3 帧类别编码

```text
2'b00 = AMB_CAL
2'b01 = DCS_CAL
2'b10 = NORMAL
2'b11 = RESERVED/ERROR
```

### 3.4 唯一闭环比较值

所有搜索、检查和跟踪只比较：

```text
signed [11:0] calibrated_s1_value
```

正常非饱和样本采用包含边界的窗口：

```text
value > threshold_high -> ABOVE_HIGH
value < threshold_low  -> BELOW_LOW
low <= value <= high   -> IN_WINDOW
```

`saturation_high`优先表示ABOVE_HIGH，`saturation_low`优先表示BELOW_LOW。两者同时为1时样本被消费但拒绝
参与判断，并置`o_protocol_error_sticky`。

### 3.4a `i_amb_threshold_low/high`标定口径说明（2026-09-10）

本模块自身`i_amb_threshold_low/high`和`i_dcs_threshold_low/high`四个独立可配置窗口端口（见第4节端口原型、第112-124行判据文字）本次未新增、未改名、未改动比较逻辑。这条说明只提醒标定这两组阈值具体数值的人一件真实变化：`ppg_sar9_sar15_safe_selection_wrapper.v`V1.5起（详见`PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md`第6.4节）AMB_CAL期间不再驱动Q2、只保留Q3，使流入本模块`i_search_calibrated_s1_value`的AMB样本原始数值物理意义从"Q2/Q3两相chopping抵消后的净值"变成"Q3单相原始摆幅"；`i_dcs_threshold_low/high`守护的DCS样本物理意义不变，仍是两相净值形式的LED残余。

`i_amb_threshold_low/high`和`i_dcs_threshold_low/high`自此不再是同一量级、同一物理意义的两组数字，不能假设它们天然可比，也不能把旧的AMB阈值数值直接沿用到新时序下——旧数值是按"两相净值通常趋近于0、只需卡住硬饱和"标定的，新时序下同一套数值大概率既不贴近实际单相摆幅范围，也可能过窄或过宽。这两组阈值的具体数值本身需要真实硅片特性数据才能重新标定，不在本次RTL/合同改造范围内，留给用户后续在实验室里测。

## 4. 冻结的模块端口原型

后续RTL端口名称、方向和位宽必须与下列原型一致。参数表达式可按Erie formatter要求换行，但不得改变语义。

```verilog
module ppg_idac_code_controller
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16,
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16,
	parameter integer C_IDAC_CODE_WIDTH = 32'd8,
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4,
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8,
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8,
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8,
	parameter [C_IDAC_CODE_WIDTH - 1:0]C_RESET_CODE = {C_IDAC_CODE_WIDTH{1'b0}}
)
(
	input i_clk,
	input i_rstn,
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation,

	input i_run_enable,
	input i_start_ack_event,
	input i_stop_ack_event,
	input i_diag_clear_event,
	input i_control_abort_event,
	input i_frame_safe_boundary,
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_active_config_epoch,

	input [1:0]i_idac_mode,
	input i_amb_enable,
	input i_dcs_enable,
	input i_amb_polarity,
	input i_dcs_polarity,
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_manual_code,
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_min,
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_max,
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_manual_code,
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code_min,
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_r_code_max,
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_manual_code,
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code_min,
	input [C_IDAC_CODE_WIDTH - 1:0]i_dcs_ir_code_max,
	input signed [11:0]i_amb_threshold_low,
	input signed [11:0]i_amb_threshold_high,
	input signed [11:0]i_dcs_threshold_low,
	input signed [11:0]i_dcs_threshold_high,
	input [7:0]i_amb_confirm_count,
	input [7:0]i_dcs_confirm_count,

	input i_search_amb_valid,
	output o_search_amb_ready,
	input i_search_dcs_valid,
	output o_search_dcs_ready,
	input signed [11:0]i_search_calibrated_s1_value,
	input i_search_calibration_applied,
	input i_search_saturation_low,
	input i_search_saturation_high,
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_search_config_epoch,
	input [C_COEF_EPOCH_WIDTH - 1:0]i_search_coef_epoch,
	input i_search_precision_mode,
	input [C_FRAME_ID_WIDTH - 1:0]i_search_frame_id,
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_search_sample_index,
	input i_search_color_ir,
	input [1:0]i_search_frame_type,
	input [C_IDAC_CODE_WIDTH - 1:0]i_search_amb_code_snapshot,
	input [C_IDAC_CODE_WIDTH - 1:0]i_search_dc_code_snapshot,
	input [C_CODE_EPOCH_WIDTH - 1:0]i_search_amb_code_epoch,
	input [C_CODE_EPOCH_WIDTH - 1:0]i_search_dc_code_epoch,

	input i_track_valid,
	output o_track_ready,
	input signed [11:0]i_track_calibrated_s1_value,
	input i_track_calibration_applied,
	input i_track_saturation_low,
	input i_track_saturation_high,
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_track_config_epoch,
	input [C_COEF_EPOCH_WIDTH - 1:0]i_track_coef_epoch,
	input i_track_precision_mode,
	input [C_FRAME_ID_WIDTH - 1:0]i_track_frame_id,
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_track_sample_index,
	input i_track_color_ir,
	input [1:0]i_track_frame_type,
	input [C_IDAC_CODE_WIDTH - 1:0]i_track_amb_code_snapshot,
	input [C_IDAC_CODE_WIDTH - 1:0]i_track_dc_code_snapshot,
	input [C_CODE_EPOCH_WIDTH - 1:0]i_track_amb_code_epoch,
	input [C_CODE_EPOCH_WIDTH - 1:0]i_track_dc_code_epoch,

	input i_amb_sequence_start,
	output o_amb_sample_request,
	output o_amb_sequence_busy,
	output o_amb_sequence_done,
	output o_amb_sequence_failed,
	output o_dcs_sample_request,
	output o_dcs_sample_color_ir,
	output o_dcs_revalidate_request,
	input i_dcs_revalidate_accept,
	output o_dcs_revalidate_busy,
	output o_dcs_revalidate_done,
	output o_dcs_revalidate_failed,

	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code,
	output [C_IDAC_CODE_WIDTH - 1:0]o_dcs_r_code,
	output [C_IDAC_CODE_WIDTH - 1:0]o_dcs_ir_code,
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch,
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dcs_r_code_epoch,
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dcs_ir_code_epoch,
	output o_amb_code_update,
	output o_dcs_r_code_update,
	output o_dcs_ir_code_update,
	output o_dcs_r_track_adjust,
	output o_dcs_ir_track_adjust,

	output o_amb_search_done,
	output o_dcs_r_search_done,
	output o_dcs_ir_search_done,
	output o_amb_search_exhausted,
	output o_dcs_r_search_exhausted,
	output o_dcs_ir_search_exhausted,
	output o_amb_pending_valid,
	output o_dcs_r_pending_valid,
	output o_dcs_ir_pending_valid,
	output o_amb_code_at_min,
	output o_amb_code_at_max,
	output o_dcs_r_code_at_min,
	output o_dcs_r_code_at_max,
	output o_dcs_ir_code_at_min,
	output o_dcs_ir_code_at_max,
	output o_amb_fault,
	output o_dcs_r_fault,
	output o_dcs_ir_fault,
	output o_controller_fault_blocking,
	output o_controller_fault_event,
	output o_controller_fault_identity_valid,
	output [C_FRAME_ID_WIDTH - 1:0]o_controller_fault_frame_id,
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_controller_fault_sample_index,
	output o_controller_fault_color_ir,
	output [1:0]o_controller_fault_frame_type,
	output o_controller_fault_precision,
	output [C_RUN_GENERATION_WIDTH - 1:0]o_controller_fault_run_generation,
	output o_protocol_error_sticky,
	output o_startup_search_complete,
	output o_idac_idle
);
```

## 5. 全局、生命周期和配置端口

### 5.1 run generation与终止隔离

IDAC控制器接收`i_run_generation[C_RUN_GENERATION_WIDTH-1:0]`，由AMI在每个accepted tracking、搜索和
重检事务上逐位携带。所有pending样本、确认计数、序列证据和候选码必须记录其
generation；manager是唯一生成者。陈旧generation输入不建立pending、不改变
committed码或code epoch，也不产生搜索、跟踪或重检输出。

`i_stop_ack_event`和`i_control_abort_event`只取消尚未安全提交的本地IDAC
请求/候选/序列，并在下一个2 MHz周期按`o_idac_idle`证明本地排空。它们不得
清除AMI measurement/detection fork、伪造结果discard、完成、物理idle或owner
release。已接受的IDAC sample不因`i_test_inject_enable`变化而被撤销；测试
enable从不直接进入本模块。

### 5.1 全局与生命周期

| 端口 | 位宽 | 来源 | 冻结语义 |
| --- | ---: | --- | --- |
| `i_clk` | 1 | 系统时钟 | 2 MHz控制与数据处理时钟 |
| `i_rstn` | 1 | 顶层复位 | 低有效异步复位；释放由上层同步 |
| `i_run_enable` | 1 | config manager | 仅RUN为1；为0时禁止接纳新的有效控制证据 |
| `i_start_ack_event` | 1 | config manager | 已被manager合法接受的START单周期事件；不是原始SPI命令 |
| `i_stop_ack_event` | 1 | Top registered lifecycle fanout after manager acceptance | STOP已被manager接受的单周期事件；取消在途样本、确认和pending |
| `i_diag_clear_event` | 1 | AMI从Top唯一系统诊断清除事件层级转发 | 只在本地无活动阻断故障后清除非阻断诊断sticky；不得单独解除搜索耗尽阻断故障 |
| `i_control_abort_event` | 1 | AMI内部对Top注册owner-abort事件的逐级转发 | 取消本地未安全提交的临时证据、活动序列和pending；IDAC不接收Top直接端口。 |
| `i_frame_safe_boundary` | 1 | 帧/模拟调度 | 当前沿允许提交一个或多个pending码 |
| `i_active_config_epoch` | 8 | config manager | 当前稳定ACTIVE V4快照版本，用于拒绝旧事务 |

本模块不设置独立`restart`端口。系统级显式重启固定为：STOP排空，必要时重新COMMIT和诊断清除，然后新的
`i_start_ack_event`。新START只建立下一RUN的搜索结果和临时状态；它不得清除活动或历史阻断故障，也不在非安全边界强改输出码。

### 5.2 ACTIVE V4配置

第4节所列全部`i_idac_*`、enable、polarity、manual/min/max、threshold和confirm端口直接来自
`ppg_system_active_config_unpack`。这些字段在整个RUN期间稳定，本模块只读，不保存第二套shadow/live配置。

配置管理器在COMMIT前保证：

```text
idac_mode != 2'b11
amb_code_min <= amb_manual_code <= amb_code_max
dcs_r_code_min <= dcs_r_manual_code <= dcs_r_code_max
dcs_ir_code_min <= dcs_ir_manual_code <= dcs_ir_code_max
amb_threshold_low < amb_threshold_high
dcs_threshold_low < dcs_threshold_high
amb_confirm_count != 0
dcs_confirm_count != 0
```

控制器仍应对不可能出现的运行期非法组合置阻断故障，禁止依赖无符号回绕继续运行。

## 6. 搜索/检查样本入口

### 6.1 与router的连接

| 控制器端口 | 连接 |
| --- | --- |
| `i_search_amb_valid` | router `o_amb_cal_valid` |
| `o_search_amb_ready` | router `i_amb_cal_ready` |
| `i_search_dcs_valid` | router `o_dc_cal_valid` |
| `o_search_dcs_ready` | router `i_dc_cal_ready` |
| 全部`i_search_*`载荷 | router对应共享输出载荷 |

唯一接纳事件为：

```text
search_amb_transfer = i_search_amb_valid && o_search_amb_ready
search_dcs_transfer = i_search_dcs_valid && o_search_dcs_ready
```

一个valid保持多个周期只能接纳一次。若AMB、DCS和tracking入口在同一拍同时valid，属于上层调度错误；
控制器置`o_protocol_error_sticky`，且单拍最多接纳一个入口，优先级固定为当前活动序列所期待的
AMB或DCS入口，高于tracking入口。不得把两笔载荷或计数合并。

### 6.2 搜索/检查样本资格

AMB样本参与判断必须同时满足：

```text
i_run_enable == 1
当前确实等待AMB_CAL
i_search_frame_type == 2'b00
i_search_calibration_applied == 1
i_search_config_epoch == i_active_config_epoch
i_search_amb_code_snapshot == o_amb_code
i_search_amb_code_epoch == o_amb_code_epoch
饱和标志不是非法双高
```

DCS样本还必须满足：

```text
当前确实等待DCS_CAL
i_search_frame_type == 2'b01
i_search_color_ir == 当前请求颜色
i_search_amb_code_snapshot == o_amb_code
i_search_amb_code_epoch == o_amb_code_epoch
i_search_dc_code_snapshot == 当前颜色committed DC码
i_search_dc_code_epoch == 当前颜色DC code epoch
```

不合格样本应被消费以排空router，但不得更新搜索区间、确认计数、pending、committed码或epoch。
`i_search_coef_epoch`、precision、frame_id和sample_index作为诊断元数据保存/检查，不用于分裂控制状态。

## 7. NORMAL tracking入口

### 7.1 与fork的逐项连接

控制器全部`i_track_*`端口与`ppg_normal_transaction_fork`同名`o_track_*`端口逐项连接，
`o_track_ready`连接fork的`i_track_ready`。唯一消费事件为：

```text
track_transfer = i_track_valid && o_track_ready
```

控制器使用单元素保持/比较流水时，反压必须有界。等待pending安全提交、MANUAL/SEARCH_HOLD模式、阻断故障或样本
不合格都不是长期拉低`o_track_ready`的理由；这些事务必须被接收并忽略。

### 7.2 跟踪资格

一笔已握手NORMAL事务只有同时满足以下条件才进入比较和连续确认：

```text
i_run_enable == 1
i_idac_mode == SEARCH_TRACK
i_dcs_enable == 1
o_startup_search_complete == 1
i_track_frame_type == 2'b10
i_track_calibration_applied == 1
i_track_config_epoch == i_active_config_epoch
i_track_amb_code_snapshot == o_amb_code
i_track_amb_code_epoch == o_amb_code_epoch
i_track_dc_code_snapshot == selected_committed_dc_code
i_track_dc_code_epoch == selected_dc_code_epoch
selected_dc_pending_valid == 0
没有活动AMB/DCS检查序列
o_controller_fault_blocking == 0
饱和标志不是非法双高
```

`selected`只由`i_track_color_ir`选择R或IR。`i_track_precision_mode`不参与计数器选择；9-bit和15-bit样本可在
同一颜色、同一有效码epoch下连续积累证据，精度切换不清除计数、不取消pending、不修改码或epoch。

### 7.3 连续确认和1 LSB pending

DC_R和DC_IR分别拥有高侧和低侧确认计数：

- 同方向越界：对应计数加1并饱和保持在`i_dcs_confirm_count`；
- 窗口内：该颜色两侧计数清零；
- 方向反转：旧方向清零，新方向从1开始；
- 另一颜色事务：不得修改本颜色以外的计数；
- `i_dcs_confirm_count==1`：第一笔合格越界样本形成1 LSB pending；
- pending存在时继续消费后续tracking事务，但不再累计或覆盖该pending。

`i_dcs_polarity`方向冻结为：

| polarity | ABOVE_HIGH | BELOW_LOW |
| --- | --- | --- |
| 1 | 码增加1 LSB | 码减少1 LSB |
| 0 | 码减少1 LSB | 码增加1 LSB |

pending必须钳制在对应ACTIVE min/max范围。已到边界时保持边界，不形成虚假更新，不允许8-bit回绕。

## 8. 序列调度端口

### 8.1 样本请求

`o_amb_sample_request`是保持型请求，表示控制器当前需要下一笔LED关闭的AMB_CAL事务；它保持到匹配的
`search_amb_transfer`被接纳、序列取消或STOP。

`o_dcs_sample_request`是保持型请求，`o_dcs_sample_color_ir`在请求期间稳定，0请求红光DCS_CAL，1请求红外
DCS_CAL。请求保持到匹配颜色的`search_dcs_transfer`被接纳、序列取消或STOP。

调度器拥有LED、模拟时序和ADC启动；控制器只能发出上述语义请求。

### 8.2 启动序列

合法`i_start_ack_event`启动一个新RUN上下文：

- MANUAL：形成三路启动pending，并在首个帧安全边界把启用路径装入manual码、禁用路径装入
  `C_RESET_CODE`；全部处理后置`o_startup_search_complete`；
- AUTO模式：按`AMB -> DC_R -> DC_IR`顺序搜索，未启用路径跳过并保持/装入`C_RESET_CODE`；
- 任一路必要搜索耗尽时，不置`o_startup_search_complete`，并置对应阻断故障。

`o_startup_search_complete`是RUN范围内保持型电平，不是单拍脉冲；STOP、新START或复位清除。

### 8.3 周期AMB重检

`i_amb_sequence_start`是序列控制器在NORMAL流水已排空且安全接管后产生的单周期事件，只允许在：

```text
i_run_enable == 1
i_idac_mode == SEARCH_TRACK
i_amb_enable == 1
o_startup_search_complete == 1
无其他活动序列或阻断故障
```

时接受。接受后置`o_amb_sequence_busy`并请求当前AMB码下的AMB_CAL样本：

- 第一笔合格样本在窗口内：码和epoch不变，busy清零，`o_amb_sequence_done`单拍；
- 越界：按`i_amb_confirm_count`进行同方向确认；未达到次数时继续请求样本；
- 达到确认次数：从ACTIVE AMB min/max启动受限二分重搜索；
- 重搜索成功：`o_amb_sequence_done`单拍；
- 搜索耗尽：`o_amb_sequence_failed`单拍并置AMB阻断故障。

`o_amb_sequence_done`与`o_amb_sequence_failed`互斥，均为单周期事件。

### 8.4 AMB变化后的DCS重验证

周期检查/重搜索期间，只要AMB committed码至少实际改变一次，控制器必须：

1. 清除DC_R/DC_IR确认计数；
2. 取消未提交的DC tracking pending；
3. 保留DC_R/DC_IR committed码；
4. 在AMB序列成功结束后置`o_dcs_revalidate_request`并保持到`i_dcs_revalidate_accept`；
5. accept后置`o_dcs_revalidate_busy`，依次检查启用的DC_R和DC_IR；
6. 当前DC码在窗口内则直接完成该颜色；越界经`i_dcs_confirm_count`确认后进入该颜色全范围受限搜索；
7. 两个启用颜色均恢复窗口后产生单拍`o_dcs_revalidate_done`；任一路耗尽产生单拍
   `o_dcs_revalidate_failed`并置对应阻断故障。

AMB码未实际改变时不得产生`o_dcs_revalidate_request`。该request为电平握手，不得实现为可能丢失的单拍。

## 9. 搜索算法冻结

每一路自动搜索使用对应ACTIVE `[code_min, code_max]`闭区间：

1. 初始候选为`floor((low_bound + high_bound) / 2)`；中间求和至少9 bit；
2. 候选先形成pending，安全提交后才请求观察样本；
3. IN_WINDOW时搜索成功并保持当前committed候选；
4. 需要提高码值时令`low_bound = candidate + 1`；
5. 需要降低码值时令`high_bound = candidate - 1`；
6. 新区间非空则按同一中点规则形成下一候选；
7. 新区间为空时保持最近一次已经提交、最接近目标方向的边界码，并置search exhausted/fault。

提高或降低码值的方向由对应polarity决定：polarity为1时ABOVE_HIGH要求增码、BELOW_LOW要求减码；
polarity为0时相反。所有加减必须显式扩位并比较边界，不得依赖自然溢出。

## 10. pending、安全提交和epoch

三路pending独立保存候选值和来源类型。提交条件为：

```text
pending_valid && i_frame_safe_boundary && i_run_enable && !blocking_abort
```

同一安全边界允许同时提交启动MANUAL形成的多路pending；搜索和NORMAL慢速跟踪通常只提交当前活动一路。

每一路提交沿必须：

1. 若pending值不同于committed码，更新对应`o_*_code`；
2. 仅在实际改变时使对应4-bit`o_*_code_epoch`模16加1；epoch允许自然回绕，事务比较只判断相等；
3. 仅在实际改变时产生对应单拍`o_*_code_update`；
4. 只有NORMAL慢速1 LSB提交产生`o_dcs_*_track_adjust`；启动搜索、重搜索和MANUAL装码不产生track_adjust；
5. 清除已提交pending及与该码相关的旧确认计数；
6. 后续事务必须绑定新码快照和新epoch。

pending形成不改变committed码和epoch。STOP、新START、`i_control_abort_event`、运行配置异常、阻断故障或活动序列取消必须取消尚未
提交的pending，但不得因取消而改变committed码或epoch。

## 11. 输出状态定义

### 11.1 码值与事件

`o_amb_code`、`o_dcs_r_code`和`o_dcs_ir_code`是唯一可送往模拟时序选择与事务快照逻辑的committed码。
三组update与两组track_adjust均为单周期事件，默认每拍拉低。

### 11.2 搜索、边界和pending

- `o_*_search_done`：当前RUN中该启用路径最近一次必要自动搜索/重搜索已经由窗口内样本确认；MANUAL和
  禁用路径不伪装为search done；
- `o_*_search_exhausted`：当前RUN发生搜索区间耗尽的sticky状态；
- `o_*_pending_valid`：该路径存在尚未安全提交的候选；
- `o_*_code_at_min/max`：committed码等于当前ACTIVE边界的组合状态；
- STOP或新START清除run-scoped search done/exhausted；异步复位也清除。

### 11.3 故障

- `o_amb_fault`、`o_dcs_r_fault`、`o_dcs_ir_fault`为路径级活动阻断故障；搜索耗尽或对应内部非法状态置位；它们只在STOP/abort终止动作使本地`o_idac_idle=1`且相应活动根因不再存在后撤销，或由异步复位撤销；
- `o_controller_fault_event`在任一路活动阻断故障从0到1的采样沿产生一个注册单拍；它与`o_controller_fault_identity_valid`、完整`o_controller_fault_<FAULT_ID>`和`o_controller_fault_run_generation[C_RUN_GENERATION_WIDTH-1:0]`原子稳定。没有可证明事务身份时identity-valid为0且全部身份字段为0；
- `o_controller_fault_blocking`是三路活动阻断故障的或，用于撤销正式NORMAL_PPG资格；它不能由START或诊断清除直接撤销。AMI是这些输出的唯一系统消费者，形成cause=`8'h05`的AMI fault record；IDAC不得直连supervisor、Top或manager；
- `o_protocol_error_sticky`记录双入口冲突、保留frame type、非法双饱和、错误颜色或错误序列事件；普通协议
  错误样本被消费并忽略，不自动改变committed码；
- `i_diag_clear_event`只在三路活动故障均已解除后清除`o_protocol_error_sticky`等非阻断历史诊断；阻断故障的系统历史由supervisor first-fault快照保留，不能由START或本地clear覆盖。

NORMAL_PPG不得把`o_controller_fault_blocking==1`后的数据标记为正式结果；CHARACTERIZATION可以继续导出
码快照、ADC结果和故障信息，但必须标为诊断数据。

### 11.4 idle

`o_idac_idle==1`必须同时满足：

```text
无已接纳但未处理的search/tracking样本
无比较结果等待消费
无AMB或DCS活动序列
无amb/dcs sample request
无dcs_revalidate_request/busy
三路pending均为0
当前拍无提交动作
```

连续确认计数本身不是在途动作；STOP时会被清除。阻断故障保持不妨碍idle变高，否则STOPPING无法排空。

## 12. 复位、STOP和精度切换

### 12.1 异步复位

复位必须把三路committed码置`C_RESET_CODE`，三个epoch置0，并清除valid、确认计数、pending、搜索边界、
请求、busy、done、exhausted、fault和所有单拍事件。

### 12.2 STOP

`i_stop_ack_event`或`i_run_enable`撤销后：

- 不再把新样本作为有效证据；
- 已出现的入口事务仍可被消费并忽略以帮助系统排空；
- 清除样本流水、确认计数、活动序列和保持型请求；
- 取消所有未提交pending；
- committed码和code epoch保持到下一次START安全装载或异步复位。

`i_control_abort_event`执行与STOP相同的临时状态取消，但不伪造STOP应答，也不自行改变生命周期；其唯一来源是AMI对Top注册owner-abort事件的内部转发，是否离开RUN
由配置管理器和顶层故障策略决定。该事件不得改变committed码或code epoch。

### 12.3 9/15-bit切换

精度切换不清除连续确认计数，不取消pending，不重启搜索，不改变committed码或epoch。只要事务的配置版本、
码快照和epoch仍匹配，同一颜色的9-bit与15-bit Stage1校准残差可形成连续证据。

## 13. 顶层所有权和连接

| 源 | 目的 | 信号 |
| --- | --- | --- |
| config manager/顶层故障汇总 | IDAC控制器 | run、START/STOP ack、status clear、control abort、active config epoch |
| ACTIVE V4 unpack | IDAC控制器 | mode、enable、polarity、manual/min/max、threshold、confirm count |
| router AMB_CAL/DCS_CAL | 搜索/检查入口 | 两个valid、共享校准载荷及快照元数据 |
| NORMAL fork tracking | tracking入口 | ready/valid、Stage1校准残差及快照元数据 |
| 帧/模拟调度 | IDAC控制器 | frame safe boundary、AMB sequence start、DCS revalidate accept |
| IDAC控制器 | 帧/模拟调度 | AMB/DCS sample request、颜色、序列done/failed、三路committed码 |
| IDAC控制器 | 事务快照逻辑 | 三路code与code epoch；按color选择R或IR DC字段 |
| IDAC控制器 | config manager | `o_idac_idle`连接manager `i_idac_idle` |
| IDAC控制器 | 资格/状态汇总 | blocking fault、search exhausted、protocol error及更新事件 |

`amb_recheck_interval_frames`仍由帧调度器拥有和计数，不进入本控制器端口。帧调度器达到周期并完成流水接管后，
才向本模块产生`i_amb_sequence_start`。

## 14. 禁止事项

以下实现违反本合同：

1. 保留旧版内部SPI shadow/write/commit端口；
2. 只输出一组`o_idac_code`并由外部猜测当前通道；
3. 使用`detect_code`代替`signed calibrated_s1_value`；
4. 把NORMAL valid直接复制给测量链和控制器而没有fork所有权；
5. pending等待安全边界期间长期反压tracking分支；
6. 用精度模式选择两套独立AMB/DC状态；
7. 精度切换清除确认次数或pending；
8. NORMAL事务直接调整AMB；
9. controller直接切LED或启动ADC；
10. 码在min/max处自然溢出回绕；
11. pending尚未提交就改变输出码、快照或epoch；
12. pending形成时递增epoch；
13. 码未实际变化却产生update或递增epoch；
14. 搜索候选提交产生track_adjust；
15. 使用`settle_sample_count`丢弃完整采样事务；
16. 搜索耗尽后仍声明正式NORMAL资格；
17. 用`status_clear_event`在RUN中静默解除搜索耗尽而不重新搜索。

## 15. 自检TB最低验收矩阵

| 编号 | 场景 | 预期 |
| --- | --- | --- |
| IDC2-01 | 异步复位 | 三码为reset code，epoch/valid/request/fault为0，idle为1 |
| IDC2-02 | MANUAL启动 | 首个安全边界原子装入启用路径手动码，禁用路径为reset code |
| IDC2-03 | 自动启动顺序 | 请求严格为AMB、R、IR，禁用路径被跳过 |
| IDC2-04 | 二分搜索成功 | 仅提交后样本可评价，窗口内置对应search done |
| IDC2-05 | 二分搜索耗尽 | 保持边界码，置exhausted/fault，不置startup complete |
| IDC2-06 | 反压保持 | valid保持多拍只消费一次，载荷不重复计数 |
| IDC2-07 | 错epoch/快照 | 样本被消费但搜索和计数状态不变 |
| IDC2-08 | 双饱和 | 样本忽略并置protocol error |
| IDC2-09 | NORMAL窗口内 | 对应颜色高低计数清零，无pending |
| IDC2-10 | N_CONFIRM=1 | 第一笔合格越界形成1 LSB pending |
| IDC2-11 | N_CONFIRM=3 | 第三笔同向越界才形成pending |
| IDC2-12 | R/IR交错 | 两色计数、pending和epoch互不污染 |
| IDC2-13 | 9/15-bit交错 | 同色同epoch证据连续累计，精度切换不清状态 |
| IDC2-14 | pending等待 | tracking继续被消费但不覆盖pending |
| IDC2-15 | 安全提交 | 实际改码、epoch加1、update单拍；track来源另有track_adjust |
| IDC2-16 | min/max继续越界 | 不回绕、不虚假update、不递增epoch |
| IDC2-17 | 周期AMB在窗口 | done单拍，AMB码/epoch不变，不请求DCS重验 |
| IDC2-18 | 周期AMB重搜改码 | AMB epoch更新，成功后保持DCS revalidate request至accept |
| IDC2-19 | DCS重验证 | 依次检查R/IR，全部成功才产生done |
| IDC2-20 | 双入口冲突 | 最多接纳一笔并置protocol error，不混合载荷 |
| IDC2-21 | STOP取消pending | committed码/epoch保持，序列/request/pending清空后idle为1 |
| IDC2-22 | status clear | 清protocol error但不清阻断search fault |
| IDC2-23 | 安全恢复后的新START | STOP/abort后真实IDAC idle、活动故障解除且系统诊断按合同清除后，从ACTIVE配置重新执行启动流程；START本身不清故障 |
| IDC2-24 | epoch回绕 | 4'hF实际改码后回到0，快照相等比较仍正确 |

## 16. 与旧版V1接口的迁移结论

旧版以下接口删除：

```text
i_enable
i_analog_ready
i_sample_valid
i_detect_code
i_cfg_shadow_write
i_cfg_shadow_addr
i_cfg_shadow_wdata
i_cfg_commit
o_idac_code
o_commit_pending
o_commit_ack
o_commit_error
o_threshold_error
```

旧版`C_USE_DCS_THRESHOLD`、`C_DEFAULT_*`、`C_DEFAULT_TRACK_ENABLE`和`C_SETTLE_SAMPLE_COUNT`删除。其单上下文
状态机替换为三路逻辑码所有权、双样本入口、系统生命周期事件和外部ACTIVE V4只读配置。

## 17. 冻结结论

本文正式冻结：

- IDAC控制器使用三组共享于SAR9/SAR15的逻辑码；
- 搜索/检查和NORMAL tracking采用两个保持型ready/valid入口；
- 闭环唯一数值为`signed 12-bit calibrated_s1_value`；
- 启动搜索、AMB周期重检和AMB变化后的DCS重验证使用同一套码状态与明确调度握手；
- 三路pending只在frame safe boundary提交，实际改码才递增独立4-bit epoch；
- NORMAL只慢速跟踪DC_R/DC_IR，AMB只在受控AMB序列中检查或重搜；
- 精度切换不清除证据，不复制码状态；
- 搜索耗尽是阻断正式NORMAL资格的sticky故障；
- 旧版内部配置、单码输出、detect code输入和settle sample机制不得进入V2。

任何改变端口名称/宽度、模式编码、握手所有权、搜索顺序、码提交边界或故障资格的修改，都必须发布新的合同版本，
不得在RTL实现中静默改变。
