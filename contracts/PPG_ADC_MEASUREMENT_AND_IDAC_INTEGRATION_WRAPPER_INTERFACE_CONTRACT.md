# PPG ADC测量、DC恢复、IDAC与精度窗口集成Wrapper接口合同

> V2.1 fail-closed V5-gate revision, 2026-08-20: AMI remains the sole `o_datapath_empty` aggregate owner and the sole Top-facing parent that forwards V5 named detection configuration and the registered `peak_valley_config_valid` gate into PWI. System closure is `NOT_CLOSED` until the matrix reverse-port audit records zero defects. RTL/TB evidence remains `EVIDENCE_PENDING`.
> Historical V1.9 change record (non-normative): it added the previously prose-only AMI system-feedback ports for committed precision, NORMAL eligibility, IDAC code/epoch and IDAC idle. Current V2.1 rules above are authoritative.

> Historical V1.3.4 predecessor record (non-normative): its verification-interface shape is incorporated only where V2.1 repeats it. It has no independent authority and its RTL/TB evidence is `EVIDENCE_PENDING`.
> Every V1.1-V1.9 date, change or status record below is historical unless V2.1 explicitly repeats the behavior. Such records cannot define a current port, dependency version, lifecycle rule or closure verdict.
> 冻结日期：2026-08-12  
> V1.1修订日期：2026-08-13  
> V1.1修订：将公共帧安全边界拆分为宏帧安全边界和IDAC码安全边界  
> V1.2修订日期：2026-08-14  
> V1.2修订：增加可靠ADC完成旁带，供400 Hz调度器和SAR安全选择wrapper共同消费  
> V1.3修订日期：2026-08-15  
> V1.3修订：冻结AMI仅拥有ADC结果事务、START后IDAC启动安全边界复用、真实DONE归属、生命周期迟到DONE及精度切换期间IDAC状态保持规则  
> V1.3.1勘误日期：2026-08-16  
> V1.3.1勘误：SSW依赖更新为V1.3.2；既有AMI-01至AMI-42回归日志属于历史证据，不把历史日志表述为当前RTL闭合。本勘误不改变ADC结果事务、abort迟到DONE、reset后旧DONE或`success=0`释放语义。  
> V1.3.2勘误日期：2026-08-16  
> V1.3.2勘误：`i_analog_safe`仅约束精度切换和IDAC安全提交，不得阻止已预建立波形在前一笔匹配DONE后取得下一笔ADC结果owner；保持IR波形在tick 160预建立、Q3位置及owner deadline不变。  
> V1.3.3小版本修订日期：2026-08-16  
> V1.3.3小版本修订：冻结CHARACTERIZATION测量的自动搜索、NORMAL慢速tracking fork和自动调码pending隔离；沿用已有`i_run_profile`与`i_idac_mode`输入，不新增AMI端口，不修改Stage1/Stage2、FIR、动态基线、峰谷或精度算法。  
> V1.3.3校准责任边界勘误日期：2026-08-16  
> V1.3.3校准责任边界勘误：AMI只在RUN期NORMAL自动IDAC资格下发布实际SAR9 AMB/DCS请求；不接收或产生配置管理器`calibration_plan`，不修改算法和物理时序
> V1.3.3实现证据状态更新日期：2026-08-16
> 实现证据状态：当前RTL、TB和XSim日志时间顺序匹配；AMI-01至AMI-45已完成45项真实比较且全部PASS。该证据仅覆盖AMI单模块，不等同于三模块联合TB或最终顶层闭合。
> V1.3.4修订日期：2026-08-20  
> V1.3.4修订：冻结默认关闭的验证专用identity/invalid-sample一次性注入接口、独立`o_result_sample_valid`资格、生产模式旁路、异常身份不释放owner及系统fault导出语义；不改变Scheduler固定接管点、owner deadline、Q1/Q2/Q3、RAW数值链或正常`sample_index`分配。  
> V1.4合同状态：AMI-46至AMI-55的接口、释放、CDC和恢复语义已由第6.10节闭合；当前RTL/TB与最终系统证据为`EVIDENCE_PENDING`。V1.3.3的AMI-01至AMI-45日志仅为未受影响功能的历史基线，不得升级为V1.4证据。
> V1.3.4 P1语义补充日期：2026-08-20  
> V1.5 historical integration note: `result_sample_valid` retention, explicit discard, first-fault isolation and controlled original-ID recovery are normative only as reconciled by the current matrix; this note does not claim closure.  
> 目标RTL：`ppg_adc_measurement_idac_integration.v`  
> 目标TB：`tb_ppg_adc_measurement_idac_integration.v`  
> 时钟域：2 MHz数字处理域  
> ACTIVE联合配置：固定1024 bit；V4子载荷为`[639:0]`、`schema_version=8'h04`，V5检测子载荷为`[1023:640]`、合同绑定`schema=8'h05`。AMI是唯一将V5具名字段转发至PWI的父模块。  
> 目标语言：可综合Verilog-2001  
> 验收范围：AMI-01至AMI-54

## 1. 合同目的

本文冻结ADC异步结果捕获、ADC结果事务owner、Stage1重构与校准、事务路由、NORMAL双分支、Stage2可编程重构、DC恢复、IDAC控制以及精度窗口检测子系统之间的可综合集成边界。

本wrapper把已经独立验证的小模块连接为一条完整的ADC数字测量与控制链，但不拥有：

- SPI物理接口和寄存器地址映射；
- 1024-bit联合配置的CDC、配置生命周期管理和ACTIVE解包结果消费；AMI不重建V4/V5，也不产生第二个默认配置源；
- 400 Hz帧、红光/红外和校准事务的物理调度；
- 调度器到SAR安全选择wrapper的模拟波形上下文、固定接管点、预建立槽和owner截止点；
- SAR9/SAR15模拟时序波形产生及模拟输出选择；
- Pad、ESD和最终芯片封装边界。

AMI只在`i_transaction_start_valid && o_transaction_start_ready`真实握手后取得一笔ADC结果事务owner。模拟波形上下文只属于`ppg_400hz_frame_calibration_scheduler -> ppg_sar9_sar15_safe_selection_wrapper`通道，既不进入AMI，也不得由AMI start fire重新生成。

后续wrapper RTL、集成TB、帧调度器、SAR时序选择层和最终数字顶层必须以本文为本子系统的连接真源。

## 2. 依赖追踪与冲突优先级

**当前规范依赖（可决定AMI接口或语义）**

1. C01 — `ppg_system_integration/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` V1.10；
2. C04 — `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` V1.7；
3. C08 — `ppg_system_integration/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` V1.8；
4. C09 — `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.9；
5. C11 — `ppg_system_integration/PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md` V1；
6. C12 — `ppg_system_integration/PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md` V1.3；
7. C13 — `ppg_system_integration/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md` V1.2；
8. C14 — `ppg_system_integration/PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md` V1.2；
9. C15 — `ppg_system_integration/PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md` V1；
10. C16 — `ppg_system_integration/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md` V2；
11. C17 — `ppg_system_integration/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` V2.3；
12. C18 — `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V2.0；
13. C06 — `ppg_system_integration/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` V1.3；
14. C24 — `ppg_system_integration/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` V1.5.

`PPG_ADC_IDAC_INTEGRATION_SPEC.md`, all RTL files, regression logs, handoff
documents and predecessor version records are non-normative design or evidence
references. They cannot define an AMI port, fault route, width or lifecycle.

若旧顶层草案、旧handoff或模块注释与本文冲突：

- 本wrapper的连接、仲裁、fork所有权和跨模块握手以本文为准；
- 各子模块内部数学和局部状态行为以各自最新冻结合同为准；
- 640-bit V4配置字段不得退回旧512-bit版本；
- PPG原始码值方向保持“接收光强越强，码值越高”。

## 3. 集成模块范围

wrapper必须实例化以下十个真实子模块：

1. `ppg_adc_async_stage_capture`；
2. `ppg_adc_s1_redundancy_corrector`；
3. `ppg_adc_s1_programmable_calibrator`；
4. `ppg_adc_result_router`；
5. `ppg_normal_transaction_fork`；
6. `ppg_adc_pipeline_overlap_corrector`；
7. `ppg_adc_programmable_reconstructor`；
8. `ppg_adc_dc_recovery`；
9. `ppg_idac_code_controller`；
10. `ppg_precision_window_integration`。

wrapper内部还必须实现三个小型可综合控制结构：

1. 唯一ADC结果事务启动门控和ADC结果owner在途保护；
2. 启动搜索与周期重检的校准请求仲裁及单事务在途保护；
3. DC恢复结果到片内检测与正式测量输出的双消费者保持型fork。

不得在TB中使用行为模型、常量ready或层次化force替代上述真实子模块。

## 4. 总体数据与控制结构

V1.3的跨模块控制结构冻结为：

```text
ppg_400hz_frame_calibration_scheduler
        |                                    |
        | 模拟波形上下文                     | ADC结果事务上下文
        v                                    v
ppg_sar9_sar15_safe_selection_wrapper    本AMI start valid/ready
        ^                                    |
        | owner commit（调度器同拍产生）     | capture + S1取得结果owner
        |                                    v
        +--------- AMI真实完成旁带 <---- CLK_DOUT同步、RAW锁存和身份接纳

START后调度器IDAC启动边界
        -> AMI.i_idac_code_safe_boundary
        -> ppg_idac_code_controller.i_frame_safe_boundary
```

上图两条上下文通道不得合并；AMI完成旁带是调度器和SSW释放同一ADC结果owner的唯一数字事件。

```text
ADC异步RAW与DONE
        |
        v
ppg_adc_async_stage_capture
        |
        v
ppg_adc_s1_redundancy_corrector
        |
        v
ppg_adc_s1_programmable_calibrator
        |
        v
ppg_adc_result_router
        |------------------------------------|
        | AMB_CAL / DCS_CAL                  | NORMAL
        v                                    v
ppg_idac_code_controller          ppg_normal_transaction_fork
                                             |----------------------|
                                             | tracking             | measurement
                                             v                      v
                                  ppg_idac_code_controller   pipeline_overlap_corrector
                                                                    |
                                                                    v
                                                     programmable_reconstructor
                                                                    |
                                                                    v
                                                           adc_dc_recovery
                                                                    |
                                                                    v
                                                   DC恢复双消费者保持型fork
                                                       |                    |
                                                       v                    v
                                         precision_window_integration   正式PPG结果输出
                                                       |
                                                       +----周期重检请求----+
                                                                    |
                                                                    v
                                                       ppg_idac_code_controller
```

## 5. 固定事务编码和元数据

### 5.1 帧类型

| `frame_type` | 事务类型 | 目的分支 |
| --- | --- | --- |
| `2'b00` | AMB_CAL | IDAC AMB搜索/检查 |
| `2'b01` | DCS_CAL | IDAC当前颜色DC搜索/检查 |
| `2'b10` | NORMAL_PPG | 测量链和IDAC tracking fork；仅`i_run_profile=NORMAL`时允许tracking分支有效 |
| `2'b11` | RESERVED | 不进入任何正式数据链并置协议诊断 |

### 5.2 颜色和精度

- `color_ir=0`表示红光，`color_ir=1`表示红外；
- NORMAL事务的`precision_mode`必须等于事务启动沿观察到的唯一committed精度；
- AMB_CAL和DCS_CAL固定使用SAR9，`precision_mode=0`；
- 同一事务的精度、颜色、帧类型、frame ID、sample index、IDAC快照和全部epoch必须原子绑定。

### 5.3 IDAC快照

- `amb_code_snapshot`必须等于本次模拟积分实际使用的committed AMB码；
- DCS_CAL和NORMAL的`dc_code_snapshot`必须等于当前颜色committed DC码；
- 快照不得使用pending、shadow或下一帧候选码；
- `dc_code_epoch`由`color_ir`选择DC_R或DC_IR的committed epoch；
- AMB_CAL的DC码不参与AMB资格判断，上层可按模拟时序合同使用零码或已冻结固定码。

## 6. 外部端口分组

### 6.1 参数

| 参数 | 默认值 | 语义 |
| --- | ---: | --- |
| `C_FRAME_ID_WIDTH` | 16 | 真实400 Hz物理帧编号宽度 |
| `C_SAMPLE_INDEX_WIDTH` | 16 | ADC事务全局顺序编号宽度 |
| `C_CONFIG_EPOCH_WIDTH` | 8 | ACTIVE配置版本宽度 |
| `C_COEF_EPOCH_WIDTH` | 8 | Stage1/Stage2系数版本宽度 |
| `C_DC_RECOVERY_EPOCH_WIDTH` | 8 | DC恢复系数版本宽度 |
| `C_IDAC_CODE_WIDTH` | 8 | 三组逻辑IDAC码宽度 |
| `C_CODE_EPOCH_WIDTH` | 4 | IDAC committed码版本宽度 |
| `C_RUN_GENERATION_WIDTH` | 8 | manager唯一生产、经ACTIVE wrapper与Top透明扇出的RUN代际宽度 |
| `C_DATA_WIDTH` | 24 | 统一PPG码宽度 |
| `C_ENABLE_TEST_INJECTION` | 0 | 验证专用异常注入结构生成开关；生产构建必须保持0，只有联合/最终顶层验证构建可显式覆盖为1 |

### 6.2 全局与生命周期输入

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_clk` | 1 | 2 MHz数字处理时钟 |
| `i_rstn` | 1 | 低有效异步复位，释放由系统上层同步 |
| `i_active_config_valid` | 1 | 当前ACTIVE配置整体合法 |
| `i_run_enable` | 1 | 生命周期处于RUN |
| `i_allow_new_transaction` | 1 | 配置管理器允许启动新ADC事务 |
| `i_start_ack_event` | 1 | 新RUN被合法接受的单周期事件 |
| `i_stop_ack_event` | 1 | STOP进入排空的单周期事件 |
| `i_control_abort_event` | 1 | 阻断异常撤销控制事务的单周期事件 |
| `i_diag_clear_event` | 1 | 软件清除sticky诊断的单周期事件 |
| `i_config_epoch` | 8 | 当前ACTIVE配置版本 |
| `i_stage1_coef_epoch` | 8 | 当前Stage1系数组版本 |
| `i_stage2_coef_epoch` | 8 | 当前Stage2系数组版本 |
| `i_dc_recovery_coef_epoch` | 8 | 当前DC恢复系数组版本 |
| `i_run_generation` | `C_RUN_GENERATION_WIDTH` | manager经ACTIVE wrapper与Top扇出的当前RUN代际；AMI及全部保留owner、完成、fork、discard和fault上下文原子锁存，陈旧代际不得绑定新owner |
| `i_slope_mode`至`i_peak_valley_config_valid` | C04 V5精确字段宽度 | Top仅将wrapper/unpacker的具名V5输出连接AMI；AMI不切片1024-bit联合ACTIVE、不产生默认值，逐项转发PWI。所有字段同`i_config_epoch`在合法COMMIT后稳定。 |
| `flag_precision_switch_hold` | 1 | PWI `o_switch_hold_new_transaction` to AMI's registered transaction-start gate; reset 0; blocks only a new ADC transaction and never clears an accepted owner. This is an AMI private input net. |
| `flag_normal_output_inhibit` | 1 | PWI `o_normal_output_inhibit` to AMI's registered formal-result qualification gate; reset 0; never clears an accepted owner, fork or calibration request. This is an AMI private input net. |
| `flag_precision_fault_event/active/identity_valid/<FAULT_ID>` | `1/1/1/each field` | PWI `o_mode_fault_event/active/identity_valid/<FAULT_ID>` to AMI's registered fault-record formation logic; reset 0; AMI maps this only to cause `8'h04`. This is an AMI private input net. |
| `flag_idac_fault_event/active/identity_valid/<FAULT_ID>` | `1/1/1/each field` | IDAC `o_controller_fault_event/blocking/identity_valid/<FAULT_ID>` to AMI's registered fault-record formation logic and `flag_idac_fault_active` start gate; reset 0; AMI maps this only to cause `8'h05`. This is an AMI private input net. |

### 6.2a V5到PWI的唯一逐端转发

AMI是V5检测配置连接PWI的唯一父模块。Top不得直连任何PWI、FIR、baseline、
peak/valley或precision端口。每个成员均为2 MHz域配置输入，与`i_config_epoch`在
合法COMMIT后绑定，并在整个RUN保持稳定：

| AMI input | Width | PWI direct consumer and final child |
| --- | ---: | --- |
| `i_slope_mode` | 1 | PWI -> dynamic baseline |
| `i_fixed_slope_q16`, `i_slope_min_q16`, `i_slope_max_q16`, `i_baseline_delta_q16`, `i_cross_hysteresis_q16` | signed/unsigned 32 | PWI -> dynamic baseline |
| `i_alpha_q15`, `i_beta_q15`, `i_timing_adjust_ratio_q15` | 16 | PWI -> dynamic baseline |
| `i_lead_min_frames`, `i_lead_max_frames` | 16 | PWI -> dynamic baseline |
| `i_cross_confirm_count`, `i_no_cross_limit` | 4 | PWI -> dynamic baseline |
| `i_peak_confirm_count`, `i_valley_confirm_count` | 4 | PWI -> peak/valley |
| `i_direction_deadband`, `i_min_peak_valley_amplitude` | 24 | PWI -> peak/valley |
| `i_min_peak_to_valley_frames`, `i_min_peak_to_peak_frames` | 16 | PWI -> peak/valley |
| `i_max_fine_window_frames`, `i_max_reacquire_frames` | 16 | PWI -> precision controller |
| `i_peak_valley_config_valid` | 1 | AMI registered V5 gate -> PWI -> baseline/cross, peak-valley and precision-controller safety gate; reset 0, stable with `i_config_epoch`, no local producer |
| `i_config_epoch[C_CONFIG_EPOCH_WIDTH-1:0]` | `C_CONFIG_EPOCH_WIDTH` | PWI `i_config_epoch`, then atomically tagged on every detection transaction |

`i_peak_valley_config_valid=0`不是AMI本地fault或STOP请求。AMI继续正常数据owner和
PWI排空，但必须将该注册门控沿唯一链路转发给PWI及其三个检测子模块；门控为0时子模块只能安全
消费/排空，禁止正式峰谷、cross、9-to-15请求和fine-window控制，AMI不得
代替PWI伪造这些事件。

### 6.3 ADC结果事务owner输入

外部帧调度器在匹配模拟波形上下文已经由SSW锁存、SSW独立给出owner资格且尚未越过owner截止点后，使用保持型valid/ready向AMI提交一笔ADC结果事务上下文：

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_transaction_start_valid` | 1 | 当前ADC结果事务上下文保持有效 |
| `o_transaction_start_ready` | 1 | AMI允许取得下一笔ADC结果事务owner |
| `o_transaction_start_fire` | 1 | AMI取得ADC结果owner的唯一正式单拍，返回调度器作同拍一致性监测 |
| `i_transaction_precision_mode` | 1 | 本笔事务使用的9/15-bit精度 |
| `i_transaction_frame_id` | 参数化 | 本笔事务真实物理帧号 |
| `i_transaction_sample_index` | 参数化 | 本笔事务全局顺序号 |
| `i_transaction_color_ir` | 1 | 本笔事务颜色 |
| `i_transaction_frame_type` | 2 | AMB_CAL、DCS_CAL或NORMAL |
| `i_transaction_amb_code_snapshot` | 8 | 本次积分实际AMB码 |
| `i_transaction_dc_code_snapshot` | 8 | 本次积分实际颜色DC码 |
| `i_transaction_amb_code_epoch` | 4 | AMB码版本 |
| `i_transaction_dc_code_epoch` | 4 | 当前颜色DC码版本 |

`o_transaction_start_fire`严格定义为：

```text
i_transaction_start_valid && o_transaction_start_ready
```

该fire在AMI内部必须同拍连接到：

- capture的`i_adc_transaction_start`；
- S1重构器的`i_adc_transaction_start`。

调度器以同一握手条件在该拍独立产生SSW的`i_adc_owner_commit_event`和完整owner identity。`o_transaction_start_fire`只返回调度器作以下一致性检查：

```text
o_transaction_start_fire
    == i_transaction_start_valid && o_transaction_start_ready
```

AMI不得直接连接SSW的波形上下文或owner提交端口，不得根据start fire产生模拟预建立，不得分配或递增`sample_index`。`sample_index`由调度器在该fire使用的输入载荷中首次正式绑定并消费。

### 6.3a 两类上下文的所有权边界

两类上下文必须始终独立：

| 上下文 | 提交方向 | AMI职责 |
| --- | --- | --- |
| 模拟波形上下文 | 调度器到SSW | 不接收、不保存、不产生ready或fire |
| ADC结果事务上下文 | 调度器到AMI | 握手后保存完整身份并等待真实ADC结果 |

波形上下文fire不启动AMI capture/S1，不占用AMI结果owner，也不消费`sample_index`。AMI start fire不改写SSW早先锁存的模拟码值、epoch、颜色、精度或Q3位置。调度器和SSW必须在AMI之外完成两类上下文的顺序、deadline和身份原子性检查。

### 6.4 ADC异步物理结果输入

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_dout_stage1_low` | 10 | Stage1物理判决码 |
| `i_clk_stage1_dout_low_async` | 1 | Stage1异步完成保持电平 |
| `i_dout_stage2_low` | 10 | Stage2物理判决码 |
| `i_clk_stage2_dout_low_async` | 1 | Stage2异步完成保持电平 |
| `i_adc_idle` | 1 | 模拟ADC当前无转换且DONE已回到可启动状态 |
| `i_analog_safe` | 1 | 模拟时序允许精度提交和IDAC安全提交；不阻止已预建立波形的ADC结果owner启动 |
| `i_macro_frame_safe_boundary` | 1 | 下一400 Hz宏帧准备前的精度、重检和上下文安全边界 |
| `i_idac_code_safe_boundary` | 1 | START启动、快速校准或NORMAL慢速IDAC pending码成为committed码的唯一安全提交边界 |
| `i_safe_frame_id` | 参数化 | 与宏帧安全边界同拍的下一物理帧真实frame ID |

V1.1删除旧公共输入`i_frame_safe_boundary`。两个新输入均来自`ppg_400hz_frame_calibration_scheduler` V1.3，且只能按以下职责消费：

```text
i_macro_frame_safe_boundary
    -> ppg_precision_window_integration.i_frame_safe_boundary
       -> ppg_precision_window_controller
       -> ppg_amb_recheck_scheduler

i_idac_code_safe_boundary
    -> ppg_idac_code_controller.i_frame_safe_boundary
```

`i_safe_frame_id`只与`i_macro_frame_safe_boundary`绑定。仅有`i_idac_code_safe_boundary=1`时，wrapper及IDAC控制器不得使用或重新解释`i_safe_frame_id`。

NORMAL期间两个输入通常在同一个400 Hz安全沿同时为1；快速SAR9校准期间，`i_idac_code_safe_boundary`可在相邻宏帧安全边界之间多次出现。AMI不得要求两路脉冲始终相等，也不得用任一路重新生成另一脉冲。

V1.3把调度器的START后启动边界冻结为`i_idac_code_safe_boundary`的一种合法来源，不新增AMI或IDAC控制器端口：

```text
每次START后，调度器确认ADC、模拟和SAR时序安全空闲
    -> ppg_400hz_frame_calibration_scheduler.o_startup_idac_safe_boundary = 1
    -> ppg_400hz_frame_calibration_scheduler.o_idac_code_safe_boundary = 1
    -> AMI.i_idac_code_safe_boundary = 1
    -> ppg_idac_code_controller.i_frame_safe_boundary = 1
```

该边界不得被`o_startup_search_complete=0`、`o_normal_measurement_eligible=0`或尚未开始400 Hz宏帧阻挡。它只允许IDAC控制器在`MANUAL_APPLY`、`AMB_APPLY`或`DCS_R_APPLY/DCS_IR_APPLY`状态把当前合法启动pending码提交为committed码；AMI不得用该拍启动ADC、产生校准结果、产生宏帧边界、推进`frame_id/sample_index`、提交精度切换或触发AMB重检。

每个START最多一次、发布前的物理安全资格以及STOP/abort/故障撤销属于调度器V1.3职责。AMI只逐拍透传每个合法`i_idac_code_safe_boundary`给IDAC控制器，不得缓存、补发、合并或根据`startup_search_complete`过滤。

### 6.5 上层帧完成事件

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `i_normal_frame_complete_event` | 1 | 一帧完整NORMAL测量结束 |
| `i_calibration_frame_complete_event` | 1 | 当前AMB或DCS校准帧物理结束 |

### 6.5a ADC可靠完成旁带输出

V1.2新增以下三个输出。V1.3进一步冻结它们只描述“ADC结果已经经过`CLK_DOUT`同步、RAW已经锁存、capture身份与AMI当前结果owner匹配并且已经被接纳或受控丢弃”，不是SAR模拟波形结束事件：

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `o_adc_transaction_complete_event` | 1 | 当前事务完成的单周期脉冲 |
| `o_adc_transaction_success` | 1 | 与完成脉冲同拍的结果有效资格；失败时为0 |
| `o_adc_complete_sample_index` | `C_SAMPLE_INDEX_WIDTH` | 与完成脉冲绑定的事务`sample_index` |

三项输出的原子关系冻结为：

```text
o_adc_transaction_complete_event = 1
    -> o_adc_complete_sample_index == 当前已捕获事务sample_index
    -> o_adc_transaction_success表示该事务是否可继续处理
```

正常成功完成旁带只能在以下条件全部成立后产生：

1. 9-bit事务的Stage1 `CLK_DOUT`或15-bit事务的Stage1/Stage2 `CLK_DOUT`已经按capture合同完成两级同步；
2. 对应全部RAW码已经被ADC捕获链稳定锁存；
3. capture锁存的`precision_mode`与当前AMI结果owner一致，S1上下文及其返回的`frame_id/sample_index/color_ir/frame_type/AMB code/DC code/AMB epoch/DC epoch`与同一owner快照逐位一致；
4. 该结果不是重复DONE、无owner DONE、复位后旧DONE或已被新START失效的旧上下文；
5. 下一级S1上下文能够在同一事务身份下接纳该捕获结果；
6. `o_adc_complete_sample_index`与原始owner快照逐位一致。

满足上述条件时，`o_adc_transaction_success=1`。若已提交owner在abort后等待物理DONE释放，AMI仍可在匹配真实DONE到达时产生一次`o_adc_transaction_complete_event=1`，但必须同时输出`o_adc_transaction_success=0`和原始owner的`sample_index`；该脉冲只允许调度器和SSW释放旧物理owner，不得把RAW送入router、IDAC、NORMAL测量或检测链。

无owner DONE、复位后旧DONE、重复DONE或无法恢复原始owner identity的结果不得产生完成旁带，只置既有协议诊断并保持新事务禁止资格，直到物理ADC/DONE重新安全空闲。若owner identity仍完整但内部元数据错配，必须以原始owner `sample_index`产生一次失败完成用于释放外部owner，同时置阻断协议诊断；错误载荷不得进入正式数据链。

V1.3.4必须严格区分上述“原始owner仍可证明的内部处理失败”和第6.5b节验证专用错误completion identity。前者沿用原始owner产生`success=0`释放；后者故意向production matcher呈交不匹配身份，matcher不得用已保存owner修补输入、不得产生失败完成旁带，也不得释放AMI、Scheduler或SSW中的当前owner。验证注入造成的未解决owner只能走第6.5b节冻结的受控恢复路径。

完成旁带必须只保持一个2 MHz时钟周期。内部接收反压只允许延迟成功旁带产生，不得改变已经锁存的载荷；失败释放旁带也必须保持原始owner身份。旁带必须同时连接到：

```text
ppg_400hz_frame_calibration_scheduler.i_adc_transaction_complete_event
ppg_400hz_frame_calibration_scheduler.i_adc_transaction_success
ppg_400hz_frame_calibration_scheduler.i_adc_complete_sample_index

ppg_sar9_sar15_safe_selection_wrapper.i_adc_transaction_complete_event
ppg_sar9_sar15_safe_selection_wrapper.i_adc_transaction_success
ppg_sar9_sar15_safe_selection_wrapper.i_adc_complete_sample_index
```

顶层不得用Q3结束、SAR波形末沿、固定延迟、`i_adc_idle`或`i_normal_frame_complete_event`伪造这三个输出，也不得将两个消费者分别生成的完成脉冲合并。`i_adc_idle`只表示物理转换和DONE返回启动资格，不能替代已经提交结果owner的身份化完成。

### 6.5b 受保护的验证专用异常注入接口

该控制组只服务LFA-08和PRC-08端到端验证，不是生产数据路径、软件配置字段或普通CHARACTERIZATION模式。端口冻结为：

| 端口 | 位宽 | 方向 | 语义 |
| --- | ---: | --- | --- |
| `i_test_inject_enable` | 1 | input | 当前验证构建允许接受异常注入；还必须同时满足`C_ENABLE_TEST_INJECTION=1` |
| `i_test_identity_inject_valid` | 1 | input | 保持型一次性错误完成身份请求valid |
| `o_test_identity_inject_ready` | 1 | output | AMI可把请求原子绑定到当前唯一ADC结果owner |
| `i_test_identity_inject_sample_index` | `C_SAMPLE_INDEX_WIDTH` | input | 送入生产completion identity matcher的显式错误`sample_index`，必须不同于当前owner |
| `i_test_invalid_sample_valid` | 1 | input | 保持型一次性invalid-sample qualification请求valid |
| `o_test_invalid_sample_ready` | 1 | output | AMI可把invalid请求原子绑定到当前唯一NORMAL owner |

两个唯一接受事件为：

```text
test_identity_inject_fire =
    C_ENABLE_TEST_INJECTION
 && i_test_inject_enable
 && i_test_identity_inject_valid
 && o_test_identity_inject_ready

test_invalid_sample_fire =
    C_ENABLE_TEST_INJECTION
 && i_test_inject_enable
 && i_test_invalid_sample_valid
 && o_test_invalid_sample_ready
```

ready/valid规则冻结如下：

1. identity请求只在当前存在唯一已提交ADC结果owner、真实完成尚未被identity matcher消费、没有其他注入pending，且注入值与当前owner `sample_index`不同时ready；握手后请求绑定当前owner完整快照，不得中途改绑。
2. invalid请求只在当前存在唯一已提交NORMAL owner、结果尚未越过正式sample qualification边界、没有其他注入pending时ready；握手后只绑定该owner。
3. 两类valid不得对同一owner同时提出；同时为1时两个ready均为0，不接受任何请求，也不得改变生产事务。
4. valid受反压时，其请求类型和payload必须逐位保持到握手或验证控制方撤销；AMI不得在ready为0时预先改变owner、结果或诊断。
5. `C_ENABLE_TEST_INJECTION=0`、reset、未锁存测试模式或STOP/abort终止边界时，两个ready固定为0，所有注入选择固定旁路；已被ready/valid握手接受的请求不得因`i_test_inject_enable`随后拉低而撤回，只能由其匹配完成、明确STOP/abort终止动作或reset结束。所有生产端口行为必须与V1.3.3逐位等价。
6. `i_rstn=0`立即清除全部已锁存请求、payload和owner绑定；STOP禁止新注入并清除尚未接受或尚未绑定的请求。若identity错配已经锁存原始真实完成，STOP或abort均不得直接清除该owner、完成缓存或测试hold，而必须进入本节规定的受控失败释放；绑定但尚未越过资格边界的invalid请求可随STOP/abort撤销且不得产生算法副作用。顶层验证控制源本身也必须在reset时输出0。
7. 禁止用注入端口生成或移动Q1/Q2/Q3、修改RAW、改写已保存owner、分配或递增`sample_index`、改变IDAC码/epoch、驱动内部fork ready或形成组合ready环。

identity注入只替换一次真实物理完成首次呈交给既有production identity matcher的`sample_index`比较输入，并保留未被消费的原始真实完成上下文。它不得直接置sticky、直接释放owner、生成成功/失败completion旁带或绕过原fault路径。错误身份被matcher拒绝后：

- 当前AMI owner保持，不产生`o_adc_transaction_complete_event`；
- 不产生正式测量、IDAC、FIR、检测、精度或序号副作用；
- 置既有`o_integration_protocol_error_sticky`并进入`o_wrapper_fault_blocking`；
- 该注入请求消费一次后清除，但原始真实DONE、RAW和owner identity保持在受控恢复缓存中；旧owner只能由该真实上下文在受控STOP/abort下重匹配形成的`success=0`完成或reset解决，单独`i_diag_clear_event`不能释放owner。

因为该注入建立在一笔真实物理DONE已经返回的事务上，AMI必须另行保持“测试错配后owner retained”和原始真实完成上下文。若随后收到STOP ack或全局受控abort，AMI把该已保存真实完成以原始identity重新呈交production matcher；只有原始身份匹配后才输出一次原`sample_index`、`success=0`完成旁带，使Scheduler、SSW和AMI按既有规则释放旧owner。STOP与abort并发或先后到达时该释放必须幂等：同一旧owner最多产生一次失败完成旁带，已释放后到达的另一事件不得产生第二次完成。不得生成第二个物理DONE、不得直接由STOP/abort清owner，也不得把错误注入身份用于释放。reset可立即失效数字owner；`diag_clear`单独无效。

invalid-sample注入发生在真实DONE和完整身份成功匹配、DC恢复结果已经形成、但结果进入正式measurement/detection双消费者边界之前。它只把绑定事务的独立sample资格清为0，不改变事务valid、RAW、Stage1/Stage2值、DC恢复值、身份、码快照或epoch。

### 6.6 校准请求输出

wrapper把启动搜索和周期重检请求仲裁成一个保持型接口：

配置管理器只检查COMMIT/START前静态配置组合。AMI不接收`calibration_plan`、未来frame type或预声明校准队列；其运行时请求源资格冻结为：

```text
calibration_source_qualified =
    i_run_enable
 && i_run_profile == NORMAL_PPG
 && (i_idac_mode == SEARCH_HOLD
  || i_idac_mode == SEARCH_TRACK)
```

只有`calibration_source_qualified=1`时，启动搜索或周期重检仲裁结果才允许形成`o_calibration_sample_valid`。AMI必须把输出`frame_type`限制为AMB_CAL/DCS_CAL并把`o_calibration_precision_mode`固定为SAR9。若CHARACTERIZATION、MANUAL或保留IDAC模式下内部状态异常尝试发布校准，必须在wrapper边界抑制valid、不得建立校准在途状态或自动pending，并置`o_integration_protocol_error_sticky`；不得依赖配置管理器预测该运行时错误。

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `o_calibration_sample_valid` | 1 | 当前存在一笔待调度SAR9校准请求 |
| `i_calibration_sample_ready` | 1 | 帧调度器接受该请求 |
| `o_calibration_frame_type` | 2 | `00`为AMB_CAL，`01`为DCS_CAL |
| `o_calibration_color_ir` | 1 | DCS请求颜色；AMB时固定为0供诊断 |
| `o_calibration_precision_mode` | 1 | 固定为0，即SAR9 |
| `o_calibration_request_reason` | 2 | `00`启动搜索，`01`周期重检，其他保留 |
| `o_calibration_request_fire` | 1 | valid与ready同拍的接受事件 |

请求握手只表示帧调度器取得该校准事务所有权，不等于ADC结果已经返回。wrapper必须保存请求类型、颜色和原因，
直到匹配的AMB_CAL或DCS_CAL结果被IDAC控制器真实消费。

### 6.7 正式PPG测量输出

DC恢复后的完整事务通过第二个无丢失fork送往片内检测和以下正式输出：

| 端口 | 位宽 | 语义 |
| --- | ---: | --- |
| `o_measurement_result_valid` | 1 | 正式测量事务保持有效 |
| `i_measurement_result_ready` | 1 | 片外输出/FIFO接受当前事务 |
| `o_result_sample_valid` | 1 | 独立样本资格；真实身份匹配NORMAL事务通常为1，受控invalid-sample注入的绑定事务为0，不等同于事务valid或calibration-valid |
| `o_coarse_ppg_value` | signed 24 | Stage1粗路径统一PPG码 |
| `o_coarse_valid` | 1 | 粗结果资格 |
| `o_coarse_recovery_calibrated` | 1 | Stage1和DC9恢复正式校准资格 |
| `o_coarse_saturation_low/high` | 各1 | 粗恢复24-bit饱和诊断 |
| `o_fine_ppg_value` | signed 24 | 15-bit精细统一PPG码 |
| `o_fine_valid` | 1 | 仅15-bit事务有效 |
| `o_fine_recovery_calibrated` | 1 | 两级重构和DC15恢复正式资格 |
| `o_fine_saturation_low/high` | 各1 | 精细恢复24-bit饱和诊断 |
| `o_calibrated_s1_value` | signed 12 | 本笔正式Stage1残差 |
| `o_programmable_15_code` | signed 15 | 本笔可编程15-bit残差 |
| `o_programmable_15_valid` | 1 | 可编程精细结果资格 |
| `o_config_epoch` | 8 | 本笔ACTIVE版本 |
| `o_coef_epoch` | 8 | 本笔Stage1版本 |
| `o_stage2_result_coef_epoch` | 8 | 本笔Stage2版本 |
| `o_dc_result_coef_epoch` | 8 | 本笔DC恢复版本 |
| `o_result_precision_mode` | 1 | 本笔事务精度快照 |
| `o_result_frame_id` | 参数化 | 本笔物理帧号 |
| `o_result_sample_index` | 参数化 | 本笔全局样本号 |
| `o_result_color_ir` | 1 | 本笔颜色 |
| `o_result_frame_type` | 2 | 正式路径固定为NORMAL |
| `o_result_amb_code_snapshot` | 8 | 本笔AMB码快照 |
| `o_result_dc_code_snapshot` | 8 | 本笔颜色DC码快照 |
| `o_result_amb_code_epoch` | 4 | 本笔AMB版本 |
| `o_result_dc_code_epoch` | 4 | 本笔颜色DC版本 |

9-bit事务仍产生完整输出事务，但`fine_valid=0`；15-bit事务的粗、精细结果和全部元数据属于同一原子事务。

`result_sample_valid`是正式输出和片内检测路径共同来源、但由第10节fork按分支独立拥有的原子sideband；顶层可见的`o_result_sample_valid`来自measurement分支资格快照。`o_measurement_result_valid=1 && i_measurement_result_ready=0`期间，它必须与全部数值和身份逐拍保持；measurement分支完成不得清除仍pending的detection资格，反向亦然。生产旁路模式下每笔成功NORMAL结果均输出1；它不得由RAW为零、低/高数值、饱和状态或Stage1/Stage2/DC calibration-valid推导。invalid事务仍可在正式measurement接口被观察和记录，但片内检测路径不得把它计入FIR历史。

### 6.8 配置输入

wrapper不重新解包联合ACTIVE。V4字段由上层ACTIVE解包器提供；V5检测字段由同一解包器经AMI具名端口转发到PWI，并在RUN内稳定：

- `i_run_profile`、`i_initial_precision`；
- IDAC mode、enable、polarity、三路manual/min/max码、AMB/DCS阈值和确认次数；
- 十个signed 26-bit Q16 Stage1权重及signed 32-bit Q16 Stage1 offset；
- Stage1校准valid；
- signed 20-bit Q16 Stage2 gain、signed 32-bit Q16 Stage2 offset及Stage2校准valid；
- signed 32-bit Q16 DC9/DC15恢复系数及各自valid；
- AMB周期重检间隔；
- FIR/动态基线/峰谷/精度控制器所需的斜率、比例、迟滞、确认次数、死区、幅度和帧间隔配置。

其中：

- `i_run_profile=0`为`NORMAL_PPG`，允许NORMAL measurement和在资格满足时的tracking fork；
- `i_run_profile=1`为`CHARACTERIZATION`，只允许合同规定的固定精度measurement；
- `i_idac_mode=2'b00`为MANUAL，`2'b01`为SEARCH_HOLD，`2'b10`为SEARCH_TRACK，`2'b11`为RESERVED；
- 配置管理器负责在COMMIT/START前拒绝CHARACTERIZATION与自动IDAC模式；AMI仍必须使用`i_run_profile`做内部防御门控。

V5检测参数不是后续方案，也不是第二配置块；其唯一来源是`Top -> ACTIVE wrapper -> manager/unpacker -> AMI -> PWI`的1024-bit联合配置链。AMI不得读取V4保留位、SPI shadow或未登记输入，也不得向Top暴露PWI内部子模块端口。任何新增字段必须同时修订联合ACTIVE解包、Top逐端连接表、AMI、PWI及本矩阵后才能成为活跃接口。

### 6.9 IDAC、精度和诊断输出

AMI 的每个系统可见 IDAC、precision 和 lifecycle feedback port is formal
only in the following table. The listed child-to-AMI links are internal
registered signals, not implicit Top ports; every Top-visible row has exactly
the stated consumer path.

| AMI output | Width / reset | Sole internal producer | Sole external consumer and hold rule |
| --- | --- | --- | --- |
| `o_active_precision_mode` | 1 / 0 | PWI `o_active_precision_mode`, registered through AMI | Top -> Scheduler `i_active_precision_mode` and SSW `i_precision_mode_committed`; stable from a committed PWI switch until the next committed switch. AMI alone snapshots it into a new ADC transaction. |
| `o_normal_measurement_eligible` | 1 / 0 | AMI `normal_measurement_active` eligibility register | Top -> Scheduler `i_normal_measurement_eligible`; it gates only new NORMAL work and does not release an accepted owner. |
| `o_amb_code`, `o_dcs_r_code`, `o_dcs_ir_code` | each `C_IDAC_CODE_WIDTH` / `C_RESET_CODE` | IDAC controller committed-code registers | Top -> matching Scheduler code inputs; held until the IDAC safe-boundary commit updates the corresponding registered code. |
| `o_amb_code_epoch`, `o_dcs_r_code_epoch`, `o_dcs_ir_code_epoch` | each `C_CODE_EPOCH_WIDTH` / 0 | IDAC controller committed-epoch registers | Top -> matching Scheduler epoch inputs; atomically stable with the corresponding code. |
| `o_idac_idle` | 1 / 1 | IDAC controller `o_idac_idle` | Top -> ACTIVE wrapper `i_idac_idle` -> manager STOPPING predicate; it is not digital `o_datapath_empty`, physical `i_adc_idle` or a completion. |
| `o_amb_code_update`, `o_dcs_r_code_update`, `o_dcs_ir_code_update`, `o_dcs_r_track_adjust`, `o_dcs_ir_track_adjust` | each 1 / 0 | IDAC controller registered events | Explicit AMI diagnostic/observation endpoint only unless a future active contract adds one declared consumer; no event is a manager, Scheduler-ready, abort or STOP input. |
| `o_amb_search_done`, `o_dcs_r_search_done`, `o_dcs_ir_search_done`, `o_amb_search_exhausted`, `o_dcs_r_search_exhausted`, `o_dcs_ir_search_exhausted` | each 1 / 0 | IDAC controller registered status/event outputs | Explicit AMI diagnostic/observation endpoint only; exhaustion contributes only through the declared IDAC fault record, never through an undeclared direct route. |
| PWI fine-window, recheck and detector diagnostics | declared child widths / reset 0 | PWI and its contained children | Explicit AMI diagnostic/observation endpoint only; no Top, manager or supervisor consumer is implicit. |
| `o_integration_protocol_error_sticky`, `o_wrapper_fault_blocking` | each 1 / 0 | AMI protocol/fault state | `o_wrapper_fault_blocking` only -> Top -> Scheduler `i_ami_fault_blocking`; the sticky is an AMI diagnostic observation. Neither bypasses the AMI fault record. |
| `o_adc_chain_idle`, `o_normal_fork_idle`, `o_measurement_output_idle`, `o_datapath_empty` | each 1 / reset as its named retained state requires | AMI retained-state aggregates | `o_datapath_empty` only -> Top -> ACTIVE wrapper `i_datapath_empty` -> manager; the other three are explicit AMI diagnostic/observation endpoints and never replace physical idle. |

### 6.10 V1.5 retained-transaction, injection and fault ports

AMI receives `i_run_generation[C_RUN_GENERATION_WIDTH-1:0]` directly from the
manager-owned fanout through the ACTIVE wrapper and Top. Every accepted ADC owner, captured completion,
recovery cache, measurement result, detection fork and AMI fault record retains
the complete ID group, including this generation. A raw `CLK_DOUT` does not
carry a generation itself: AMI binds it only to the current physical owner;
old-generation DONE, RAW, injection state or recovery context cannot bind a
new owner.

AMI retains the local port name `i_adc_idle`; its sole source is Top
`flag_adc_physical_idle`. It is the physical conversion/DONE-return idle fact,
not a completion, captured RAW indication, owner-release event or substitute
for this section's digital `o_datapath_empty` expression.

The following registered lifecycle inputs and outputs are part of this external
port group. `i_system_fault_discard_event` is produced only by the supervisor;
an external abort never drives it. All three inputs are one-cycle registered 2
MHz events, reset low, and have no ready return path. The fault event sets the
AMI-private, current-generation `system_fault_discard_pending` latch. This is
not a new port and is not a second supervisor: it preserves the event's reason
until every AMI current-generation terminal slot has either transferred or
emitted its one permitted discard, and AMI then reports `o_datapath_empty=1`.
Consequently, a result or detection state that becomes discardable after the
single supervisor pulse still receives `DISCARD_SYSTEM_FAULT`. Reset clears the
latch without an event; a new generation cannot inherit it.

| Input | Width | Producer | Meaning |
| --- | ---: | --- | --- |
| `i_stop_ack_event` | 1 | Top lifecycle fanout | Accepted Top-merged STOP lifecycle event. |
| `i_control_abort_event` | 1 | Top abort-owner fanout | Registered owner-abort event; it does not itself identify a blocking system fault. |
| `i_system_fault_discard_event` | 1 | supervisor | Registered fault-episode discard selector. |

The following registered AMI outputs are part of this external port group:

| Port group | Width | Meaning |
| --- | ---: | --- |
| `o_measurement_result_discard_event` | 1 | Registered one-cycle explicit formal-result lifecycle discard observation. |
| `o_measurement_result_discard_reason` | 2 | `DISCARD_STOP`/`DISCARD_ABORT`/`DISCARD_SYSTEM_FAULT`; stable with the event. |
| `o_measurement_result_discard_identity_valid` | 1 | Always 1 when the measurement discard event is asserted; its retained `TXN_ID` is therefore meaningful. |
| `o_measurement_result_discard_sample_valid` | 1 | Discarded measurement qualification snapshot; stable with the event. |
| `o_measurement_result_discard_<TXN_ID>` | each transaction field width | Complete retained transaction identity; the exact field expansion is defined in the closure matrix and stable with the event. |
| `o_detection_discard_event` | 1 | Registered one-cycle unconditional detection lifecycle-discard broadcast. |
| `o_detection_discard_reason` | 2 | `DISCARD_STOP`/`DISCARD_ABORT`/`DISCARD_SYSTEM_FAULT`; stable with the event. |
| `o_detection_discard_identity_valid` | 1 | Trigger identity valid. It is 1 only when a retained detection-fork transaction initiated the generation-scoped flush; otherwise every trigger transaction field except mandatory target `run_generation`, and sample-valid, are 0. |
| `o_detection_discard_sample_valid` | 1 | Discarded detection qualification snapshot; stable with the event. |
| `o_detection_discard_<TXN_ID>` | each transaction field width | Complete retained transaction identity; the exact field expansion is defined in the closure matrix and stable with the event. |
| `o_ami_fault_valid` / `o_ami_fault_active` | 1 / 1 | Registered AMI blocking-fault record valid and unresolved level. |
| `o_ami_fault_cause` / `o_ami_fault_identity_valid` | 8 / 1 | Fixed cause and validity of the atomically captured fault identity. |
| `o_ami_fault_<FAULT_ID>` | each fault-identity field width | Registered fault identity; exact field expansion is defined in the closure matrix; all fields are zero when invalid. |
| `o_wrapper_fault_blocking` | 1 | Registered AMI local start-gate level. It is 0 on reset and 1 while any unresolved AMI blocking lane or AMI-private precision/IDAC blocking source remains active. Its sole public consumer is Scheduler `i_ami_fault_blocking` through the Top mapping. It is not a supervisor record, does not directly drive manager or STOP, and cannot clear an accepted owner. |
| `o_switch_hold_new_transaction` | 1 | Registered AMI re-export of private `flag_precision_switch_hold`; its only public consumer is Scheduler through Top; reset is 0. |
| `o_datapath_empty` | 1 | AMI's sole full digital-drain aggregation. |

### 6.11 AMI local fault-record arbitration

AMI owns one registered fault-record dispatcher for its five blocking-cause
lanes. The lanes are `8'h01` protected sample-index mismatch, `8'h02`
unrecoverable owner/protocol error, `8'h03` unprovable controlled-recovery
context, `8'h04` registered PWI precision fault and `8'h05` registered IDAC
controller fault. A rising event for a lane captures that lane's `FAULT_ID`
atomically, sets its lane-pending bit and sets its lane-active bit. An invalid
identity captures every `FAULT_ID` field as zero.

`o_ami_fault_active` is the OR of the five lane-active bits. AMI dispatches
exactly one pending lane per 2 MHz cycle as the one-cycle
`o_ami_fault_valid/cause/identity_valid/<FAULT_ID>` record. If two or more
lanes become pending on the same edge, or a new lane arrives while another is
pending, AMI retains each lane independently and dispatches them in this fixed
order: `8'h01 > 8'h02 > 8'h03 > 8'h04 > 8'h05`. A dispatched lane is removed
from the event-pending set but remains active until its source-specific
recovery predicate is true. Consequently a simultaneous PWI and IDAC fault
produces two distinct AMI valid pulses in deterministic order; the supervisor
can set both summary bits without a second child-to-supervisor route.

Reset clears every lane state and emits no fault record. `diag_clear`, STOP,
abort, a result discard, enable deassertion and START neither remove a pending
fault record nor clear an active lane. A stale-generation fault event is
discarded without a record or active-lane mutation. PWI and IDAC child outputs
are the only producers of lanes `8'h04` and `8'h05`; neither may drive the
supervisor or manager directly.

Discard ID fields are per branch, not a shared mux. The appropriate ID,
sample-valid qualification, identity-valid and reason are registered and
stable throughout the event sampling edge. A normal measurement `valid && ready`
transfer wins over same-edge measurement discard. A terminal lifecycle action
has priority over a detection handoff: it emits the generation-scoped detection
flush and prevents that transaction from entering PWI. If no normal measurement
transfer occurs, priority is
`system_fault_discard_pending (including a same-edge
i_system_fault_discard_event) > i_control_abort_event > i_stop_ack_event`.
Reasons are `STOP=2'b00`, `ABORT=2'b01`, `SYSTEM_FAULT=2'b10`; `2'b11` is
reserved and is never emitted. Reset clears state without a discard event.
There is no `discard_ready`, and clearing a held valid without transfer or its
branch's explicit discard event is forbidden.

For retained work before the DC-result fork, AMI is the sole producer of the
private registered `datapath_discard_event/reason/identity_valid/TXN_ID`
fanout to NORMAL fork, Router, overlap, reconstructor and DC recovery. It uses
the same terminal selection, including the retained
`system_fault_discard_pending` reason, and current `run_generation` as this section, has
no ready return and is not a public result-discard observation. It is a
generation-scoped flush: each receiving stage clears every retained pending
context belonging to the event generation on that sampling edge, regardless of
whether its trigger `TXN_ID` is the same transaction. `identity_valid=1` only
when AMI has a concrete retained trigger transaction; otherwise every trigger
transaction field except mandatory target `run_generation`, and sample
qualification, are zero. A stage reports local empty no
earlier than the following cycle. This private event is the unique
STOP/abort/system-fault release path for pre-fork digital pending; it must not
fabricate a result, completion or physical idle.

The measurement and detection fork payloads contain separate registered
`measurement_sample_valid` and `detection_sample_valid` bits. A handshake or
discard of one branch never releases, modifies or observes the other branch's
qualification. For any terminal action while the current-generation detection
chain is nonempty, AMI emits exactly one generation-scoped detection discard
event even if the AMI detection fork is already empty. It carries a concrete
trigger `TXN_ID` only when available; otherwise `identity_valid=0`, its
sample-valid and every trigger transaction field except target `run_generation`
are zero. Detection discard is received
unconditionally by PWI in the same 2 MHz domain; PWI and each downstream owner
clear every local pending and run-scoped algorithm state belonging to that
generation on that edge and report empty no earlier than the next cycle.

AMI determines that downstream detection state remains by the registered PWI
`o_detection_datapath_empty` return, not by the AMI detection-fork state alone.
The scope-discard episode latch is set when the event is emitted and suppresses
all duplicate STOP/abort/fault events for that generation until PWI reports
empty or reset occurs. A later terminal request cannot alter the recorded
reason or emit a second event; it may only continue to block new work. This
exactly-once rule is independent of the measurement-result discard slot.

Injection controls arrive only from the Top's registered 2 MHz verification
source. They use held valid/payload-to-ready. Test mode may be configured only
in CONFIG/READY, is locked on accepted START and ignores source changes in RUN.
An accepted request remains owner-bound after a later enable deassertion.
Identity and invalid requests are mutually exclusive: AMI accepts neither when
the other is valid, armed or accepted on the same edge. It accepts neither with
no unique legal owner, an equal injected index, STOP/abort/system-fault pending,
or a duplicate request. Reset and a terminal lifecycle action outrank a new
request and force both ready outputs low.

Identity injection is limited to a wrong `sample_index`, enters the production
matcher, and may not alter owner state or bypass matching. After a real DONE
has been rejected by that test mismatch, STOP or abort re-presents the proven
original ID once with `success=0`; the matching completion is the only release
path. Invalid injection applies only after real completion, production identity
match and DC recovery. It changes only the independent fork qualifications,
never RAW, numeric payload, ID, epoch or sample index, and never advances FIR,
baseline, cross, peak/valley or precision state.

`o_datapath_empty` is AMI's single registered digital-drain expression:

```text
adc_chain_idle
&& normal_fork_idle
&& overlap_empty
&& reconstructor_empty
&& dc_recovery_empty
&& measurement_fork_empty
&& detection_fork_empty
&& pwi_fir_baseline_peak_valley_precision_empty
&& calibration_request_inflight == 0
```

`adc_chain_idle` includes accepted-owner, capture, S1 and raw-completion or
recovery-cache state. The expression excludes physical ADC idle and IDAC idle:
they are separate STOPPING predicates. Top and manager consume this one output
and may not recreate it. AMI fault-valid is one registered cycle; AMI
fault-active remains high until its documented matching or controlled
`success=0` release proves no AMI blocking cause remains. `diag_clear` cannot
release that owner or active cause.

## 7. 唯一ADC结果owner合同

### 7.1 内部ADC在途所有权

wrapper必须保存`flag_adc_transaction_inflight`及完整结果owner identity：

- `o_transaction_start_fire`时置1；
- 匹配真实DONE形成第6.5a节成功或失败完成旁带时清0；
- 复位清0；
- STOP不强制清除，等待已启动转换返回并排空；
- abort保留仅用于释放物理owner的原始身份并进入受控丢弃，匹配旧DONE只产生`success=0`完成旁带；
- 新START不得在旧物理owner、旧DONE或受控丢弃上下文仍未排空时取得新结果owner。

现有capture没有独立`transaction_ready`输出，因此wrapper不得仅依赖`i_adc_idle`重复启动；必须同时使用上述所有权。

AMI的`flag_adc_transaction_inflight`只表示已握手的ADC结果owner，不表示SSW模拟波形槽、预建立状态、owner-pending或Q3资格。AMI不得因观察到调度器波形接管而提前置位，也不得因模拟包络结束而提前清除。

### 7.2 NORMAL启动资格

```text
normal_measurement_active =
    i_run_enable
 && i_active_config_valid
 && idac_startup_search_complete
 && !flag_idac_fault_active
 && !flag_precision_fault_active
 && !integration_fault_blocking
```

```text
normal_start_eligible =
    normal_measurement_active
 && i_allow_new_transaction
 && !flag_precision_switch_hold
 && !flag_normal_output_inhibit
 && i_adc_idle
 && !adc_transaction_inflight
 && s1_transaction_ready
```

NORMAL事务还必须满足：

- `i_transaction_precision_mode == active_precision_mode`；
- AMB/DC码和epoch与当前committed状态匹配；
- `frame_type == 2'b10`。

`idac_startup_search_complete`只门控NORMAL ADC结果事务资格，不得门控第6.4节START启动IDAC边界。也就是说，`normal_start_eligible=0`可以阻止NORMAL start ready，但不能阻止`i_idac_code_safe_boundary`到达IDAC控制器。

### 7.3 校准启动资格

AMB_CAL或DCS_CAL只能在已经握手取得的校准请求上下文存在时启动。必须满足：

- `precision_mode=0`；
- frame type和颜色与保存的请求一致；
- AMB快照与epoch匹配；
- DCS_CAL的颜色DC快照与epoch匹配；
- `i_allow_new_transaction && i_adc_idle`；
- 无ADC在途事务，且S1上下文可接收。

校准事务不受`flag_normal_output_inhibit`阻止，因为该内部信号只用于给周期重检让出NORMAL测量链。

### 7.4 非法start处理

当`i_transaction_start_valid=1`但资格不满足时，wrapper保持`ready=0`且不得产生fire。若valid保持期间载荷变化，
或校准上下文与已接受请求不匹配，置`o_integration_protocol_error_sticky`；严重错配进入blocking fault保持。

调度器V1.3已经保证只有SSW `o_adc_owner_ready=1`时才向AMI形成可握手valid，并在AMI真实fire同拍向SSW提交同一owner identity。AMI不接收SSW ready，也不得从`o_transaction_start_fire`反向参与调度器或SSW ready组合逻辑。对于IR，SSW可以在RED结果owner尚未释放时保持波形预建立；匹配RED DONE释放物理owner后，AMI必须只以ADC、结果owner、S1和NORMAL资格决定IR结果owner是否可以fire，不能等待`i_analog_safe`。任何顶层把AMI ready/fire直接反馈生成SSW ready的实现均属于组合环和半提交风险。

## 8. Stage1、router和NORMAL fork连接

### 8.1 capture到S1重构器

capture的四个输出逐项连接S1重构器输入，S1的`o_capture_ready`返回capture的`i_capture_ready`。
S1上下文只在唯一start fire沿锁存，禁止直接使用未握手的外部帧控制电平。

### 8.2 S1可编程校准

S1固定重构结果完整送入Stage1可编程校准器。`detect_code`和`stage1_code_ext`只作为黄金、范围和诊断字段；
正式IDAC和粗测量值固定使用`signed [11:0] calibrated_s1_value`。

### 8.3 router互斥路由

- AMB_CAL只连接IDAC `i_search_amb_*`；
- DCS_CAL只连接IDAC `i_search_dcs_*`；
- NORMAL只连接`ppg_normal_transaction_fork`；
- router两个校准valid共享同一完整载荷，但IDAC依靠各自valid解释；
- router非法`2'b11`不得进入NORMAL或校准链。

以下内部事件必须由真实握手产生：

```text
amb_sample_accepted_event = router_amb_valid && idac_amb_ready
dcs_sample_accepted_event = router_dcs_valid && idac_dcs_ready
```

它们同时用于清除校准请求在途所有权，并连接precision wrapper的同名接受事件输入。

### 8.4 NORMAL双分支

每笔NORMAL事务必须由`ppg_normal_transaction_fork`复制为两个独立所有权：

- measurement分支进入overlap、Stage2重构和DC恢复；
- tracking分支进入IDAC控制器；
- 两个分支各消费且只消费一次；
- IDAC等待pending安全提交或样本不合格时仍应有界接收并忽略，不得长期堵塞测量链。

`o_normal_fork_idle`定义为measurement和tracking两个pending均为0；不得只观察其中一路ready。

### 8.5 CHARACTERIZATION运行档案隔离

当`i_run_profile=CHARACTERIZATION`且不是STATIC_BIAS测量许可时，AMI仍可接收合法的固定精度ADC结果事务，
但必须执行以下运行档案门控：

```text
characterization_measurement = 1
tracking_qualified          = 0
calibration_qualified       = 0
auto_idac_pending_qualified  = 0
```

具体冻结规则：

1. 不启动或接受`AMB_CAL`、`DCS_CAL`、周期AMB重检或任何自动搜索请求；
2. 不把CHARACTERIZATION结果送入NORMAL慢速IDAC tracking fork；tracking分支必须保持无效、不得建立pending；
3. 不消费慢速tracking资格；`o_dcs_r_track_adjust`和`o_dcs_ir_track_adjust`必须保持为0，不得由CHARACTERIZATION结果形成AMB/DC自动调码pending、候选码提交或自动epoch更新；
4. 允许的MANUAL启动码只能沿既有IDAC安全边界提交一次，并作为后续波形的committed码；该提交不属于自动搜索或慢速跟踪；
5. CHARACTERIZATION的测量分支仍可完成Stage1/Stage2、FIR、动态基线、峰谷和精度相关数据处理，但这些算法输出不得反向开启tracking或校准请求；
6. `i_run_profile`和`i_idac_mode`必须在相关握手沿绑定并保持，不能由未提交配置或运行中shadow值改变门控；
7. 运行档案门控点固定在NORMAL结果进入双消费者fork之前：CHARACTERIZATION结果只允许进入measurement分支，tracking分支输入valid和内部pending必须保持为0；禁止先复制到tracking分支、再依赖下游IDAC控制器丢弃；
8. 除MANUAL启动码在既有启动IDAC安全边界前允许存在的一次性提交状态外，CHARACTERIZATION测量结果不得使`o_dcs_r_pending_valid`或`o_dcs_ir_pending_valid`从0变为1；启动提交完成后，两路pending在整个固定精度测量期间必须保持为0。

配置管理器负责在COMMIT/START前拒绝CHARACTERIZATION与`SEARCH_HOLD/SEARCH_TRACK`组合；AMI仍必须保留上述防御性门控，不能把配置管理器的拒绝当作内部fork隔离的替代品。

当`i_run_profile=NORMAL_PPG`时，NORMAL测量结果才允许按既有双消费者fork同时进入measurement和tracking；tracking资格仍由既有IDAC模式、样本资格和控制器合同共同决定。

### 8.6 两类安全边界的内部连接

V1.1冻结以下逐位直连关系：

| AMI外部输入 | 内部唯一消费者 | 内部端口 | 允许行为 |
| --- | --- | --- | --- |
| `i_macro_frame_safe_boundary` | `ppg_precision_window_integration` | `i_frame_safe_boundary` | 精度提交、AMB重检接管和下一宏帧上下文冻结 |
| `i_idac_code_safe_boundary` | `ppg_idac_code_controller` | `i_frame_safe_boundary` | START启动pending、校准候选或NORMAL慢速pending码提交、实际变化判断和code epoch更新 |

冻结约束：

- `i_macro_frame_safe_boundary`不得连接到IDAC控制器的提交端口；
- `i_idac_code_safe_boundary`不得连接到precision wrapper、精度控制器或AMB重检调度器；
- wrapper不得对两路输入执行OR、AND、边沿合并、脉冲展宽或重新定时；
- 两路输入同拍为1时，precision和IDAC各自只消费一次本模块职责对应的单周期事件；
- 同拍不得导致IDAC重复提交，也不得导致同一code epoch递增两次；
- 快速校准期间额外出现的IDAC边界不得产生精度切换、AMB重检accept、FIR清空或safe frame ID更新；
- NORMAL期间两路边界同拍不表示二者可以合并，后续接口和验证仍必须分别观察；
- START后的第一次合法`i_idac_code_safe_boundary`允许发生在`startup_search_complete=0`且首个宏帧尚未开始时，AMI必须原样送到IDAC控制器；
- START启动边界不得形成`o_transaction_start_fire`、capture/S1上下文、校准结果或`sample_index`消费；
- STOP、abort或阻断故障发生时，wrapper不自行制造补偿边界；pending和在途控制按各子模块生命周期合同撤销或排空。

该拆分只改变安全事件的路由，不改变`ppg_idac_code_controller`和`ppg_precision_window_integration`当前内部端口名称。两个子模块仍各自使用局部名称`i_frame_safe_boundary`，但连接源不同。

## 9. overlap与正式可编程15-bit路径

`ppg_adc_pipeline_overlap_corrector`仍必须位于正式measurement链中，因为它负责把Stage2 RAW转换为：

```text
stage2_code_ext
```

`ppg_adc_programmable_reconstructor`使用该值以及正式Stage1结果完成Stage2增益和offset重构。

overlap输出的`nominal_15_code`、`nominal_15_valid`和`nominal_saturated`只作为黄金参考载荷透传给可编程重构器，
不得替代`programmable_15_code`，不得进入DC恢复正式精细算术，也不得驱动IDAC、基线、相交或峰谷控制。

综合工具允许在未导出黄金观察端口时优化无消费者的标称参考逻辑；该优化不影响正式功能。若后续需要片上导出黄金链，
必须新增独立诊断接口版本，不能复用正式测量valid。

## 10. DC恢复双消费者fork

### 10.1 所有权

DC恢复的单一完整输出事务必须写入wrapper内部单元素保持缓存，同时建立：

```text
detection_pending = 1
measurement_pending = 1
```

- detection分支连接`ppg_precision_window_integration`；
- measurement分支连接第6.7节正式输出；
- fork建立时必须把该事务的`result_sample_valid`复制到两个分支各自拥有的事务payload；语义上分别形成`detection_sample_valid`和`measurement_sample_valid`，不得让两个分支在pending期间读取一个会被任一消费者提前清除的共享可变资格寄存器；
- detection分支的资格快照只送precision wrapper `i_sample_valid`，measurement分支的资格快照只驱动`o_result_sample_valid`；两者初值必须逐位相同；
- 每个pending只在对应ready/valid握手、或第6.10节定义的同分支显式生命周期discard时清除；reset按复位规则清除且不产生discard事件；
- 任一分支握手只能释放该分支的pending和资格快照，不得改变另一仍pending分支可见的`result_sample_valid`；
- 任一分支反压时，整个载荷逐位保持；
- 两个pending均清除后才允许释放或同拍替换为下一事务。

禁止把DC恢复valid直接并联给两个消费者。

### 10.2 检测分支

- 检测链始终使用`coarse_ppg_value`；
- 检测分支把`result_sample_valid`逐位连接precision wrapper的`i_sample_valid`；该位为0时仍可完成当前检测分支事务握手，但FIR不得移动历史、递增计数或启动MAC；
- 9-bit和15-bit事务都把Stage1粗恢复结果送入检测链；
- `fine_ppg_value`只属于正式精细数据输出，不驱动片内相交和峰谷控制；
- 普通9/15切换不清空FIR历史；
- AMB/DC周期重检由precision wrapper按其V1.2合同清空并重新预热FIR。

### 10.3 正式测量分支

正式输出不得被检测链反压覆盖或重复消费。重检安全接管前必须已经排空所有旧NORMAL事务；若异常情况下
`flag_normal_output_inhibit=1`后仍到达旧NORMAL结果，wrapper必须完成受控排空、置协议诊断，并不得把它标记为新的
正式重检后PPG样本。

## 11. 校准请求仲裁

### 11.1 请求来源

| 来源 | 条件 | 请求语义 |
| --- | --- | --- |
| IDAC启动搜索 | `startup_search_complete=0`且IDAC请求AMB/DCS样本 | RUN初始化 |
| precision wrapper | 周期重检已经安全接管 | 固定AMB、DC_R、DC_IR三阶段 |

### 11.2 优先级

```text
STOP / abort / blocking fault
> 已经开始或已经接受的周期重检请求
> 启动IDAC搜索请求
> NORMAL测量
```

启动搜索和周期重检正常情况下互斥。若两者同时提出，wrapper不得静默合并或同时接受；保持已有在途所有权，
阻止新请求并置integration协议诊断。

### 11.3 单事务在途保护

校准请求握手后必须置`calibration_request_inflight`，在匹配结果被IDAC真实消费前：

- 不得再次对同一保持请求产生第二次外部握手；
- 请求类型、颜色和reason保持在内部快照中；
- 只允许一笔匹配校准ADC事务启动；
- 不匹配结果被消费以避免死锁，但不得更新搜索，并置协议诊断；
- STOP、abort和复位撤销未启动请求；已经启动的ADC事务按第13节排空或丢弃。

### 11.4 周期重检闭环

以下连接必须逐项闭合：

- precision `o_amb_sequence_start`到IDAC `i_amb_sequence_start`；
- IDAC AMB request/done/failed到precision同名输入；
- IDAC `o_dcs_revalidate_request`到precision输入；
- precision `o_dcs_revalidate_accept`到IDAC输入；
- IDAC DCS request/color/done/failed到precision输入；
- router到IDAC的AMB/DCS真实消费事件到precision accepted event。

周期重检固定执行`AMB -> DC_R -> DC_IR`。只要DCS使能，即使AMB码未改变，也不得省略两路DC重新确认。

## 12. 配置和epoch原子性

### 12.1 接受沿快照

各子模块在自身输入ready/valid握手沿锁存其使用的ACTIVE参数和epoch。配置输入之后变化不得重新解释已接受事务。

### 12.2 正式NORMAL资格

NORMAL_PPG正式输出要求：

```text
stage1_calibration_valid = 1
stage2_calibration_valid = 1（仅精细资格）
dc9_recovery_valid = 1
dc15_recovery_valid = 1（仅精细资格）
```

CHARACTERIZATION允许使用标称或临时系数，但对应`calibration_applied`和`recovery_calibrated`必须如实为0。

### 12.3 code epoch

三组逻辑码在SAR9和SAR15之间共用。只有committed码实际变化时相应code epoch才按模16递增；精度切换、检查通过、
形成pending但未提交均不得递增。

### 12.4 普通精度切换期间的NORMAL慢速IDAC状态

普通`SAR9 -> SAR15`或`SAR15 -> SAR9`只改变后续ADC结果事务的committed精度，不得清除或重建同色IDAC慢速跟踪状态。AMI必须保证：

- RED和IR各自的连续越界确认计数保持；
- 已形成但尚未到IDAC安全边界的tracking pending保持；
- committed AMB、DC_R、DC_IR码和各自epoch保持；
- 饱和边界、方向和最后一次有效调码上下文保持；
- 精度切换本身不得产生IDAC提交、code update或epoch递增；
- 新精度事务仍使用同一颜色当时的committed码和epoch；
- 旧在途事务继续使用start fire时锁存的旧精度、码值和epoch。

周期AMB重检、STOP、abort和复位仍按各自合同清理或重建状态，不能借用普通精度切换规则跳过重检清理。

## 13. START、STOP、abort和复位

| 事件 | 新事务 | 已接受ADC/数据事务 | 控制状态 | 输出事务 |
| --- | --- | --- | --- | --- |
| 复位 | 立即禁止 | 数字owner和上下文全部清除；复位后旧DONE不得产生完成旁带 | pending、fork、inflight和sticky复位 | valid清0 |
| START ack | 按RUN资格重新开放；首个ADC start必须等待启动IDAC流程取得资格 | 不应存在旧事务、旧DONE或旧受控丢弃owner | IDAC进入启动装码/搜索；等待调度器一次启动安全边界；检测链进入新RUN | 清旧输出所有权 |
| STOP ack | 立即禁止 | 每个已提交但尚未完成的owner立即标记为discard-pending，等待真实DONE；真实DONE只能以原始identity产生一次`success=0`释放旁带。若测试identity错配后真实DONE已缓存，则立即以原identity产生一次`success=0`受控释放 | 撤销未启动控制请求，不制造补偿边界 | 未传输measurement产生一次`DISCARD_STOP`；检测链按当前generation产生一次scope discard；不得产生STOP后正式结果 |
| abort | 立即禁止 | 已提交owner保留原始身份等待真实DONE，只产生`success=0`释放旁带 | 撤销计算、pending和未来提交 | 未传输measurement/detection分别产生一次`DISCARD_ABORT`，不得产生迟到正式valid |
| AMB重检accept | 禁止NORMAL，允许匹配CAL | 安全条件要求旧NORMAL已排空 | 固定三阶段并清FIR历史 | 不撤销已经握手输出 |

STOPPING完成前`o_datapath_empty`必须真实为1。不得通过清除wrapper输出valid伪造排空。

abort期间，无法直接复位的既有数据子模块只可经各自的显式生命周期discard事件排空；不得伪造内部ready、直接清valid或把丢弃事务重新送入正式输出或检测链。

第6.5b节identity注入错配是STOP/abort表格的受控特例：真实DONE已经到达但首次错误身份呈交被production matcher拒绝，因此不会等待或生成第二个物理DONE。STOP ack或全局abort到达后，AMI只可使用保存的原始真实完成上下文重新执行匹配；匹配成功后产生一次原`sample_index`、`success=0`旁带并释放三方旧owner。两事件并发或先后到达不得重复释放。该特例仅在`C_ENABLE_TEST_INJECTION=1`且存在已记录的测试错配状态时成立，生产模式不可触发。

生命周期中的迟到DONE规则冻结为：

1. STOP前已经取得结果owner的事务继续等待真实DONE，但STOP接受时所有尚未完成owner都已经标记为丢弃；因此真实DONE只能产生一次原身份`success=0`释放旁带，绝不进入正式结果、IDAC、校准或检测链。若真实DONE已因受保护identity错配保存在恢复缓存中，则STOP必须立即启动原identity的单次`success=0`重匹配释放，不等待第二个DONE；
2. abort前已经取得结果owner的事务保留原始`sample_index`到真实DONE，只输出一次失败释放旁带，不更新IDAC、不推进校准阶段、不生成NORMAL结果；
3. 复位立即失效全部数字owner。复位释放后出现的旧DONE没有可恢复身份，不产生完成旁带，只能等待物理`i_adc_idle`重新建立安全启动资格；
4. 无owner、重复或身份无法匹配的DONE不得借用当前输入事务载荷，不得释放新owner或成为新START后的首笔结果；
5. 新START只有在旧ADC/DONE、受控丢弃owner和全部数据fork排空后才可接受，禁止通过清除valid伪造恢复。

## 14. idle与安全汇总

### 14.1 `o_adc_chain_idle`

必须同时满足：

- 无ADC事务在途所有权；
- 无abort后等待真实DONE释放的受控丢弃owner；
- 无测试identity错配后等待原始真实完成经STOP/全局abort重匹配或reset解决的保留owner/完成缓存；
- capture无保持结果；
- S1重构器无上下文或输出事务；
- Stage1校准器无输出事务。

### 14.2 `o_normal_fork_idle`

NORMAL measurement和tracking两个分支均无pending。

### 14.3 `o_measurement_output_idle`

DC恢复双消费者fork的正式测量分支无pending，且DC恢复、可编程重构和overlap无保持输出。

### 14.4 `o_datapath_empty`

必须同时包含：

```text
adc_chain_idle
&& normal_fork_idle
&& overlap_empty
&& reconstructor_empty
&& dc_recovery_empty
&& measurement_fork_empty
&& detection_fork_empty
&& pwi_fir_baseline_peak_valley_precision_empty
&& calibration_request_inflight=0
```

IDAC idle单独导出给配置管理器，但最终STOP条件必须同时检查`o_datapath_empty && o_idac_idle`。

### 14.5 precision wrapper的切换安全资格输入

本wrapper不得把外部物理`i_adc_idle`直接连接到
`ppg_precision_window_integration.i_precision_takeover_safe`。必须先形成：

```text
precision_takeover_safe =
    i_adc_idle
 && adc_chain_idle
 && normal_fork_idle
 && overlap/reconstructor/dc_recovery为空
 && DC恢复双消费者fork为空
```

然后把`precision_takeover_safe`连接到precision wrapper的
`i_precision_takeover_safe`，并由PWI原样转发到precision controller同名端口。
该复合资格不是物理空闲事实，不得命名为`*_adc_idle`，也不得回接为Top
`flag_adc_physical_idle`。precision wrapper仍独立接收`i_normal_fork_idle`和
`i_idac_idle`，这类重复安全检查属于有意的防御性约束，不得因逻辑化简而改变语义。

这样才能保证周期AMB重检不会在模拟ADC已经停止、但旧NORMAL事务仍停留在数字恢复或正式输出分支时提前接管。

## 15. 故障与sticky诊断

### 15.1 integration协议sticky

以下任一事件置`o_integration_protocol_error_sticky`：

- 非法`frame_type=2'b11`；
- 启动搜索和周期重检请求冲突；
- 校准请求valid受反压时载荷变化；
- 校准start与已接受请求的类型、颜色或精度不匹配；
- 校准结果在无在途请求时返回，或结果元数据不匹配；
- NORMAL事务精度、IDAC码或epoch与committed状态不匹配；
- capture精度或S1上下文返回的frame ID、sample index、颜色、类型、码快照、epoch与当前ADC结果owner不匹配；
- 受保护identity注入通过production matcher产生的完成身份错配；
- 无owner、重复、复位后旧DONE或无法恢复原始owner身份的DONE到达；
- AMI `o_transaction_start_fire`与`i_transaction_start_valid && o_transaction_start_ready`不一致；
- 重检禁止期间异常到达旧NORMAL结果；
- 同一事务在任一fork分支重复消费。

AMI历史协议sticky保持到异步复位，或在本地无活动blocking cause后由Top唯一注册式`i_diag_clear_event`清除。新合法START和STOP本身不得清除该历史诊断；START只建立新`run_generation`的运行上下文，不能覆盖未清除的故障历史。

### 15.2 blocking fault

`o_wrapper_fault_blocking`汇总：

- IDAC controller blocking fault；
- precision controller产生mode fault后形成的RUN范围故障保持；
- 会使校准请求和返回事务失去唯一对应关系的严重integration协议错误；
- 生产路径真实completion identity无法与当前owner匹配，或无法证明可用原owner执行合同允许的失败释放；
- 第6.5b节production identity matcher拒绝的受保护错误completion identity。

blocking fault发生后禁止新NORMAL和校准start；等待STOP、abort或复位结束当前RUN上下文。

## 16. 禁止事项

以下实现违反本合同：

1. 直接使用旧`ppg_dual_precision_top.v`作为本wrapper；
2. 省略Stage1可编程校准而让IDAC使用固定`detect_code`；
3. 将AMB_CAL或DCS_CAL送入DC恢复和PPG检测链；
4. 把恢复后的PPG值反馈给IDAC窗口控制；
5. 省略overlap模块而直接把Stage2 RAW解释为`stage2_code_ext`；
6. 使用`nominal_15_code`替代正式可编程15-bit输出；
7. 将NORMAL valid无状态并联给measurement和tracking；
8. 将DC恢复valid无状态并联给检测和正式输出；
9. 校准请求保持期间重复启动多笔ADC转换；
10. capture与S1重构器使用不同事务启动脉冲；
11. 允许SAR9/SAR15为同一事务观察到不同precision快照；
12. 使用当前IDAC码重写已经在途事务的快照或epoch；
13. 普通精度切换清空FIR历史；
14. 周期重检时因AMB码未变化而跳过DC_R或DC_IR；
15. STOP在没有同拍`valid && ready`传输时直接清除valid而不产生一次稳定、可观察的measurement discard事件；
16. 把物理`i_adc_idle`直接连接precision wrapper，或将复合
    `precision_takeover_safe`伪装为物理idle，从而忽略数字测量流水排空；
17. 在本合同中擅自分配尚未进入V4 ACTIVE的检测参数SPI位段；
18. 保留旧公共`i_frame_safe_boundary`并同时驱动IDAC与precision wrapper；
19. 把`i_macro_frame_safe_boundary`接到IDAC控制器；
20. 把`i_idac_code_safe_boundary`接到precision wrapper或AMB重检调度器；
21. 在AMI内部OR、合并或重定时两路安全边界；
22. 快速校准IDAC边界触发精度提交、重检接管、FIR清空或safe frame ID变化；
23. 两路边界同拍时让IDAC提交两次或让code epoch递增两次；
24. 把AMI start fire直接并联为SSW模拟波形上下文fire或用它开始预建立；
25. 让波形上下文fire占用AMI结果owner、启动capture/S1或消费`sample_index`；
26. 在`startup_search_complete=0`时过滤START后的合法IDAC启动安全边界；
27. 让START启动边界产生ADC事务、宏帧动作、精度提交、AMB重检或序号推进；
28. 使用Q3末沿、模拟包络结束、固定拍数、`i_adc_idle`或宏帧tick伪造ADC完成旁带；
29. abort后把迟到DONE送入IDAC、NORMAL数据链、检测链或正式输出；
30. 普通9/15精度切换清除慢速IDAC确认计数、pending、committed码或epoch；
31. 用当前输入事务身份覆盖、修补或重新解释旧owner的迟到DONE；
32. 在旧物理owner、旧DONE或受控丢弃上下文尚未排空时接受新START或新ADC结果owner；
33. 在`C_ENABLE_TEST_INJECTION=0`或`i_test_inject_enable=0`时接受、保存或执行任何注入请求；
34. 用层次化`force`、直接置sticky、替换内部valid/ready或修改fork ready冒充LFA-08/PRC-08；
35. 用特殊RAW值、RAW为零、饱和或Stage1/Stage2/DC calibration-valid冒充invalid sample；
36. 让验证注入改变Q1/Q2/Q3、RAW、正常owner分配、正常`sample_index`推进、IDAC码或epoch。

## 17. AMI集成验收矩阵

| 编号 | 场景 | 真实比较要求 |
| --- | --- | --- |
| AMI-01 | 复位 | 全部valid、pending、inflight、fork所有权和输出状态为冻结初值 |
| AMI-02 | 唯一结果owner fire | capture与S1上下文同拍接受，返回调度器的fire严格等于valid与ready且仅一拍 |
| AMI-03 | start反压 | 任一启动资格缺失时ready为0，载荷保持后恢复且只启动一次 |
| AMI-04 | 9-bit RAW链 | 只等待S1 DONE，Stage2无效，事务元数据逐级不变 |
| AMI-05 | 15-bit RAW链 | 等待S2 DONE，两级RAW和精度原子对齐 |
| AMI-06 | Stage1校准与router | AMB、DCS、NORMAL各只进入唯一合法分支 |
| AMI-07 | 非法frame type | 不产生正式事务并置integration协议sticky |
| AMI-08 | NORMAL fork | measurement和tracking各消费一次，独立反压不丢失不重复 |
| AMI-09 | overlap角色 | `stage2_code_ext`进入可编程重构，标称码不替代正式码 |
| AMI-10 | 9-bit DC恢复 | 粗结果有效、精细结果无效、码值和epoch正确 |
| AMI-11 | 15-bit DC恢复 | 粗细结果同事务有效且元数据完全一致 |
| AMI-12 | DC恢复双fork | 检测和正式输出各消费一次；分别构造measurement先完成、detection反压及detection先完成、measurement反压，两种顺序下仍pending分支的全部payload及其独立sample-valid资格逐拍不变 |
| AMI-13 | 输出同拍替换 | 旧事务两个分支最后消费与新事务装入同拍，无空泡和覆盖 |
| AMI-14 | 启动AMB搜索 | 请求只握手一次，匹配结果消费后才允许下一请求 |
| AMI-15 | 启动DC_R/DC_IR | 颜色、码快照和epoch正确，搜索顺序闭合 |
| AMI-16 | NORMAL慢速跟踪 | IDAC仅使用未恢复calibrated S1，调码不阻塞正式测量 |
| AMI-17 | 周期重检闭环 | 固定AMB、DC_R、DC_IR请求与结果逐阶段匹配 |
| AMI-18 | AMB码未改变 | 仍执行两色DC重验证，epoch不虚增 |
| AMI-19 | 普通精度切换 | 新事务采用新精度，旧事务保持历史精度，FIR及NORMAL慢速IDAC状态均不清空 |
| AMI-20 | 重检安全接管 | 只有ADC、fork、IDAC、FIR和检测状态均安全时开始校准 |
| AMI-21 | STOP排空 | 禁止新start，已接受事务和正式输出全部真实排空 |
| AMI-22 | abort在途 | 不产生迟到正式输出或控制提交，数据链最终回到empty |
| AMI-23 | epoch与配置变化 | 已接受事务使用旧快照，新事务使用新快照，无跨事务混合 |
| AMI-24 | blocking fault | 禁止新事务，sticky和fault保持到冻结清理事件 |
| AMI-25 | NORMAL边界同拍 | 两路输入同拍时precision和IDAC各消费一次，IDAC最多提交一次 |
| AMI-26 | 快速校准IDAC边界 | 仅IDAC码和epoch允许更新，不触发精度、重检、FIR或safe frame ID动作 |
| AMI-27 | 宏帧边界隔离 | 仅宏帧边界可驱动精度提交和AMB重检接管，不额外提交IDAC码 |
| AMI-28 | safe frame ID绑定 | `i_safe_frame_id`只在宏帧边界被precision路径消费，IDAC独立边界不使用该字段 |
| AMI-29 | 生命周期与边界 | STOP、abort和blocking fault期间wrapper不合成、补发或合并安全边界 |
| AMI-30 | 完成旁带原子性 | 完成脉冲、success和sample_index同拍绑定，sample_index与在途事务逐位一致 |
| AMI-31 | 完成旁带双消费者 | 顶层向调度器和SSW连接同一个完成脉冲及同一载荷，无重复、丢失或重新编码 |
| AMI-32 | 迟到/失败完成 | 无owner DONE不产生旁带；可恢复原始owner的失败DONE只产生`success=0`释放旁带且不产生正式结果 |
| AMI-33 | 两类上下文隔离 | SSW波形接管不启动AMI、不占用结果owner、不消费sample index；AMI接口不存在波形上下文兼容别名 |
| AMI-34 | owner原子提交 | start fire沿一次锁存精度、帧号、sample index、颜色、类型、AMB/DC码及epoch，等待期间载荷逐位稳定 |
| AMI-35 | START启动边界透传 | `startup_search_complete=0`且首帧未开始时，合法IDAC边界仍逐拍到达IDAC控制器并可完成MANUAL/启动候选提交 |
| AMI-36 | START启动边界隔离 | 启动边界不产生ADC fire、capture/S1上下文、宏帧/精度/重检动作或sample index变化，同一输入脉冲只消费一次 |
| AMI-37 | 真实DONE资格 | 9-bit等待Stage1、15-bit等待Stage1/Stage2的同步DONE和RAW锁存；Q3、包络末沿、固定延时及ADC idle均不能完成owner |
| AMI-38 | 完成身份逐字段匹配 | capture精度及S1上下文与owner的帧号、sample index、颜色、类型、码值和epoch逐位比较；原始owner仍可证明的内部处理失败使用原owner `success=0`释放，无法匹配或受保护错误identity注入不得释放owner并置阻断诊断 |
| AMI-39 | abort迟到DONE | abort后保留旧owner identity；匹配真实DONE只产生一次原sample index、`success=0`释放旁带，不进入任何数据或IDAC链 |
| AMI-40 | STOP在途排空 | STOP禁止新owner，旧owner等待真实DONE并完成受控排空；若测试错配已缓存真实DONE，则STOP以原identity产生一次`success=0`释放；不得清valid伪造idle、直接清owner或补发安全边界 |
| AMI-41 | reset后旧DONE | 复位清owner；释放复位后的旧DONE不产生完成旁带、不绑定新事务，等待物理ADC/DONE重新idle |
| AMI-42 | 精度切换IDAC保持 | SAR9/SAR15切换不清RED/IR确认计数、tracking pending、committed码、epoch和饱和状态，也不因切换产生码提交 |
| AMI-43 | CHARACTERIZATION档案与校准资格隔离 | 固定精度测量只进入measurement链；tracking分支valid/pending保持0，`o_calibration_sample_valid=0`，`o_dcs_r_track_adjust=0`且`o_dcs_ir_track_adjust=0`；启动MANUAL码提交完成后，测量结果不得使RED/IR pending重新置位；无manager校准计划输入 |
| AMI-44 | CHARACTERIZATION手动码 | MANUAL码可沿启动IDAC安全边界提交一次；之后码、epoch和波形快照稳定，不因测量结果启动搜索或慢速跟踪 |
| AMI-45 | CHARACTERIZATION算法边界 | Stage1/Stage2、FIR、动态基线、峰谷和精度算法保持既有数据处理；其输出不得反向开启tracking、自动调码或校准请求 |
| AMI-46 | 注入默认关闭 | 默认参数、生产enable为0及reset期间两个ready为0；所有生产输出与V1.3.3逐位一致且无注入pending |
| AMI-47 | identity请求绑定 | 合法one-shot请求只绑定当前唯一owner；反压时payload保持，相等sample index、无owner或双请求并发均不接受 |
| AMI-48 | identity matcher拒绝 | 错误sample index只进入production matcher；owner不释放，无completion、正式结果、IDAC、FIR、精度或序号副作用，并置integration sticky和blocking fault |
| AMI-49 | identity恢复 | `diag_clear`、STOP和abort本身不能直接清owner；STOP或受控abort使缓存的原始真实上下文产生一次且仅一次匹配原sample index、`success=0`旁带，两事件并发/先后到达不重复，或由reset失效数字owner；随后下一合法START/事务无旧身份恢复 |
| AMI-50 | invalid请求绑定 | one-shot invalid请求只绑定当前唯一NORMAL owner，真实DONE和完整身份匹配仍按正常链完成，数值和身份不变 |
| AMI-51 | invalid正式sideband | 绑定事务的measurement资格快照及`o_result_sample_valid=0`并在正式输出反压期间稳定；正常、零值、低/高值和饱和事务不会被自动改为invalid |
| AMI-52 | invalid检测隔离 | detection分支独立资格快照把同一invalid语义送入precision wrapper；另一分支先握手不得改变该快照，该事务不推进FIR/基线/峰谷/精度控制，后续合法样本按合同恢复 |
| AMI-53 | 延迟fault discard reason | supervisor单周期`i_system_fault_discard_event`到达时先建立AMI当前generation的内部fault-discard pending；该脉冲后才成为待丢弃的measurement、detection或pre-fork pending仍只产生一次`DISCARD_SYSTEM_FAULT`，不得被后续STOP或abort改标；数字终端排空后该内部标志清除，下一generation不得继承。 |
| AMI-54 | V5有效资格单一路径 | unpacker的`i_peak_valley_config_valid`仅由AMI注册并逐位转发PWI；AMI不产生默认值或第二producer，PWI三个子模块均观察同一稳定门控，低电平不形成AMI fault、STOP或伪检测事件。 |

所有PASS必须来自真实端口、握手计数、数值、元数据和状态比较。禁止仅打印PASS、跳过真实子模块、使用force
制造内部状态，或用固定ready掩盖反压错误。

## 18. RTL与验证门禁

实现完成后必须执行：

- 可综合Verilog-2001审查；
- formatter-AST：0 error / 0 strict warning；
- 独立Verilog lint：0 error / 0 warning；
- Vivado `xvlog`和`xelab`通过；
- xsim中AMI-01至AMI-52全部真实比较PASS；
- wrapper为顶层、包含十个真实子模块的Vivado OOC综合；
- 综合0 error / 0 critical warning；
- Latch = 0，Blackbox = 0，无组合环；
- 2 MHz时序满足；
- 记录LUT、FF、DSP、WNS/TNS、最大内部反压和非阻断警告。

综合不能只例化空壳、fork或部分数据链。若工具因未导出黄金参考而优化标称路径，应记录为预期优化，不能误判为
正式可编程路径缺失。

## 19. Historical V1.3.4 Freeze Record (Non-Normative)

The V1.3.4 record below is retained only for change traceability. The current
normative AMI interface, lifecycle, fault, discard, generation and hierarchy
rules are the V1.9 tables and sections above. Historical implementation
results in this section are not contract-closure evidence and remain separate
from current `EVIDENCE_PENDING` obligations.

1. wrapper模块名冻结为`ppg_adc_measurement_idac_integration`；
2. 十个既有真实子模块按第3节全部实例化；
3. 外部采用ADC结果事务start valid/ready，wrapper内部形成唯一结果owner `transaction_start_fire`；
4. capture和S1上下文固定使用同一fire；
5. router对AMB_CAL、DCS_CAL和NORMAL互斥分发；
6. 仅NORMAL_PPG事务通过双消费者fork分别进入measurement和IDAC tracking；CHARACTERIZATION只进入measurement，tracking分支必须由运行档案门控为无效；
7. overlap继续负责Stage2冗余预解码，但标称15-bit码不得进入正式输出路径；
8. 正式15-bit结果固定来自可编程重构器；
9. DC恢复后新增无丢失双消费者fork，分别服务片内检测和正式PPG输出；
10. 启动搜索和周期重检请求合并为单一SAR9校准请求接口，并具有单事务在途保护；
11. 周期重检固定执行AMB、DC_R和DC_IR；
12. wrapper形成NORMAL测量资格、idle、datapath empty和blocking fault汇总；
13. precision wrapper的ADC安全输入同时包含物理ADC和全部前级数字测量流水排空；
14. STOP排空已接受事务，abort受控丢弃，复位立即清除；
15. 当前未进入V4 ACTIVE的检测参数只作为稳定外部输入，不在本文分配寄存器位段；
16. 删除旧公共`i_frame_safe_boundary`，新增`i_macro_frame_safe_boundary`和`i_idac_code_safe_boundary`；
17. 宏帧安全边界只连接precision wrapper，用于精度提交、重检接管和safe frame ID；
18. IDAC码安全边界只连接IDAC控制器，用于pending提交和code epoch更新；
19. 两路边界允许同拍但不得合并、重复提交或双重递增epoch；
20. 快速校准期间的额外IDAC边界不得影响精度、重检、FIR或宏帧上下文；
21. ADC可靠完成旁带由调度器和SSW共同消费同一份完成载荷；
22. 模拟波形上下文只属于调度器到SSW通道，AMI不接收、不保存，也不以start fire重新生成；
23. AMI start fire只表示ADC结果owner提交，调度器在同拍独立向SSW提交相同owner identity；
24. START后IDAC启动边界复用现有`i_idac_code_safe_boundary`路径，不新增IDAC控制器端口；
25. 启动边界不得被`startup_search_complete=0`阻挡，且不得启动ADC、宏帧、精度、重检或序号动作；
26. 真实DONE必须经过CLK_DOUT同步、RAW锁存和完整事务身份匹配；Q3、固定延时和ADC idle均不能替代；
27. STOP排空旧owner，abort迟到DONE只产生`success=0`释放旁带，复位后无身份旧DONE不产生旁带；
28. 普通精度切换保持NORMAL慢速IDAC确认计数、pending、committed码、epoch及饱和状态；
29. AMI-01至AMI-54作为后续wrapper和系统集成的强制验收基线；
30. CHARACTERIZATION不启动自动搜索、不消费慢速tracking资格、不产生自动调码pending；
31. V1.3.3运行档案门控沿用已有`i_run_profile`和`i_idac_mode`，该项本身不增加配置端口或修改Stage1/Stage2、FIR、动态基线、峰谷和精度算法；
32. 配置管理器不提供校准计划；AMI只在RUN期NORMAL自动IDAC资格下发布实际AMB/DCS SAR9请求，Scheduler再独立执行接收端资格检查；
33. 验证异常注入由默认0的`C_ENABLE_TEST_INJECTION`与`i_test_inject_enable`双重保护，采用两组one-shot valid/ready并绑定当前唯一owner；
34. identity注入位于真实completion identity进入production matcher之前，不修改Scheduler匹配规则，错配不得释放owner或产生完成旁带；
35. invalid sample在身份匹配与DC恢复之后、measurement/detection双消费者边界之前只清独立`result_sample_valid`，不复用数值valid、饱和或calibration-valid；
36. 正式输出新增`o_result_sample_valid`，检测分支原子连接precision wrapper `i_sample_valid`；生产模式每笔成功NORMAL事务该位为1；
37. Scheduler固定接管点、owner deadline、Q1/Q2/Q3、真实RAW链和正常`sample_index`分配保持不变。

任何改变事务编码、ADC结果owner start fire、两个fork所有权、校准请求仲裁、正式15-bit来源、epoch绑定、两类安全边界路由、真实DONE身份、迟到DONE释放、STOP排空或周期重检顺序的实现，必须先修订本文版本，再修改RTL。

当前AMI V1.3.3 RTL/TB已实现并验证CHARACTERIZATION运行档案门控；AMI-01至AMI-45完成45项真实比较且全部PASS。第6.10节定义的V1.4双fork资格保持、STOP错配恢复、supervisor fault record和AMI-46至AMI-55尚无当前运行证据，因此其证据状态为`EVIDENCE_PENDING`。历史45项证据不得被重标为新验收项PASS，也不得据此宣称联合或最终系统闭合。
