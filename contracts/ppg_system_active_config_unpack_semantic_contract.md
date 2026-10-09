# ppg_system_active_config_unpack语义合同

> Current normative version: V5, 2026-08-20. Status: `ACTIVE_NORMATIVE`; system closure is owned only by `PPG_CONTRACT_CLOSURE_MATRIX.md` and remains `NOT_CLOSED` until its final audit has zero defects. RTL/TB evidence is `EVIDENCE_PENDING`.
> 输入：配置管理器原子保持的`i_active_config[1023:0]`（V4 `[639:0]`、V5 `[1023:640]`）  
> 实现：纯组合、零新增周期、可综合Verilog-2001

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C02 | `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` | V4.10 | Sole committed `i_active_config[1023:0]` producer, atomic ACTIVE stability and lifecycle owner. |
| C03 | `ppg_system_integration/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V1.7 | Sole manager parent and unchanged wrapper forwarding boundary. |

## 1. 模块职责

该模块是V4/V5 ACTIVE配置的唯一功能字段解包点，只进行固定bit选择和signed解释。它不校验快照，
不保存ACTIVE副本，不改变生命周期，不复制epoch，不执行Stage1/Stage2/DC恢复算术，不进行IDAC判决。

`o_active_valid`、`o_config_epoch`、Stage1 `o_coef_epoch`、`o_stage2_coef_epoch`和
`o_dc_recovery_coef_epoch`继续由`ppg_system_config_manager`直接送往各自使用者，不经过本模块复制或门控。

### 1.1 Formal parameter and module-port contract

| Parameter | Default | Legal range | Elaboration rule |
| --- | ---: | --- | --- |
| `C_CONFIG_WIDTH` | 1024 | exactly 1024 | Must equal Top, ACTIVE wrapper, manager and configuration-CDC width; no implicit pack, truncate or extension is permitted. |

`i_active_config[C_CONFIG_WIDTH-1:0]` is the sole input. Its only producer is
manager `o_active_config[1023:0]`, forwarded unchanged by the ACTIVE wrapper.
The manager holds it atomically stable throughout RUN and STOPPING. This pure
combinational module has no clock, reset, valid, epoch, shadow, default-profile
or lifecycle state; reset/default ownership remains solely with the manager.

| Output group | Exact ports and width | Sole consumer set | Stability and lifecycle |
| --- | --- | --- | --- |
| V4 schema/status | `o_schema_version[7:0]` | Top status observation/integration diagnostics | Combinational image of `[7:0]`; never a START/RUN pulse. |
| V4 mode | `o_run_profile`, `o_input_source`, `o_idac_mode[1:0]`, `o_optical_mode[1:0]`, `o_initial_precision`, `o_amb_enable`, `o_dcs_enable`, `o_amb_polarity`, `o_dcs_polarity` | AMI named configuration inputs | Stable while manager ACTIVE is stable; no local enable or default. |
| V4 IDAC ranges | `o_amb_manual_code`, `o_amb_code_min`, `o_amb_code_max`, `o_dcs_r_manual_code`, `o_dcs_r_code_min`, `o_dcs_r_code_max`, `o_dcs_ir_manual_code`, `o_dcs_ir_code_min`, `o_dcs_ir_code_max` `[7:0]` each | AMI named IDAC configuration inputs | Direct field image; AMI is the only downstream parent of IDAC controller. |
| V4 thresholds | `o_amb_threshold_low`, `o_amb_threshold_high`, `o_dcs_threshold_low`, `o_dcs_threshold_high` signed `[11:0]`; `o_amb_confirm_count`, `o_dcs_confirm_count` `[7:0]` | AMI named IDAC configuration inputs | Direct signed/unsigned field image; no rounding or re-encoding. |
| V4 calibration | `o_stage1_calibration_valid`, `o_stage2_calibration_valid`, `o_dc9_recovery_valid`, `o_dc15_recovery_valid`; `o_stage1_weight_q16_0..9` signed `[25:0]`; `o_stage1_offset_q16[31:0]`, `o_stage2_gain_q16[19:0]`, `o_stage2_offset_q16[31:0]`, `o_dc9_recovery_gain_q16[31:0]`, `o_dc15_recovery_gain_q16[31:0]` signed | AMI named Stage1/Stage2/DC configuration inputs | Direct field image; AMI forwards each field only to its immediate data-chain child. |
| V4 recheck | `o_amb_recheck_interval_frames[15:0]` | AMI -> internal PWI/AMB recheck scheduler | Direct field image; Scheduler never recreates a second recheck counter. |
| V5 detection | `o_slope_mode`; `o_fixed_slope_q16`, `o_slope_min_q16`, `o_slope_max_q16`, `o_baseline_delta_q16`, `o_cross_hysteresis_q16` `[31:0]`; `o_alpha_q15`, `o_beta_q15`, `o_timing_adjust_ratio_q15` `[15:0]`; `o_lead_min_frames`, `o_lead_max_frames`, `o_min_peak_to_valley_frames`, `o_min_peak_to_peak_frames`, `o_max_fine_window_frames`, `o_max_reacquire_frames` `[15:0]`; `o_cross_confirm_count`, `o_no_cross_limit`, `o_peak_confirm_count`, `o_valley_confirm_count` `[3:0]`; `o_direction_deadband`, `o_min_peak_valley_amplitude` `[23:0]`; `o_peak_valley_config_valid` | AMI only, then AMI -> PWI -> detector children | Direct field image; AMI is the only parent permitted to forward these fields. The valid gate is not generated here. |

For the signed V5 fields, the sign follows the bit interpretation in Section 2.
Every output changes only as a combinational consequence of the one held input;
the output has no handshake and cannot acknowledge, consume, clear or modify
the ACTIVE snapshot.

## 2. V4/V5位图

| 输入位段 | 输出端口 | 格式 |
| --- | --- | --- |
| `[7:0]` | `o_schema_version` | unsigned 8-bit |
| `[8]` | `o_run_profile` | 1-bit |
| `[9]` | `o_input_source` | 1-bit |
| `[11:10]` | `o_idac_mode` | 2-bit enum |
| `[13:12]` | `o_optical_mode` | 2-bit enum |
| `[14]` | `o_initial_precision` | 1-bit |
| `[15]` | `o_amb_enable` | 1-bit |
| `[16]` | `o_dcs_enable` | 1-bit |
| `[17]` | `o_amb_polarity` | 1-bit |
| `[18]` | `o_dcs_polarity` | 1-bit |
| `[19]` | `o_stage1_calibration_valid` | 1-bit |
| `[20]` | `o_stage2_calibration_valid` | 1-bit |
| `[21]` | `o_dc9_recovery_valid` | 1-bit |
| `[22]` | `o_dc15_recovery_valid` | 1-bit |
| `[39:32]`、`[47:40]`、`[55:48]` | AMB manual/min/max | unsigned 8-bit |
| `[63:56]`、`[71:64]`、`[79:72]` | 红光DCS manual/min/max | unsigned 8-bit |
| `[87:80]`、`[95:88]`、`[103:96]` | 红外DCS manual/min/max | unsigned 8-bit |
| `[115:104]`、`[127:116]` | AMB LOW/HIGH | signed 12-bit整数 |
| `[139:128]`、`[151:140]` | DCS LOW/HIGH | signed 12-bit整数 |
| `[159:152]`、`[167:160]` | AMB/DCS confirm_count | unsigned 8-bit |
| `[193:168]`至`[427:402]` | `o_stage1_weight_q16_0`至`_9` | 各signed 26-bit Q16 |
| `[459:428]` | `o_stage1_offset_q16` | signed 32-bit Q16 |
| `[479:460]` | `o_stage2_gain_q16` | signed 20-bit Q16 |
| `[511:480]` | `o_stage2_offset_q16` | signed 32-bit Q16加性截距 |
| `[543:512]` | `o_dc9_recovery_gain_q16` | signed 32-bit Q16 |
| `[575:544]` | `o_dc15_recovery_gain_q16` | signed 32-bit Q16 |
| `[591:576]` | `o_amb_recheck_interval_frames` | unsigned 16-bit完整NORMAL帧数 |

`[31:23]`和`[639:592]`为V4保留区；V5 payload位于`i_active_config[1023:640]`，
对应局部`ACTIVE_V5_DETECTION[383:0]`。V5字段固定为：

| 联合输入位段 | 输出端口 | 格式 |
| --- | --- | --- |
| `[640]` | `o_slope_mode` | 1-bit enum |
| `[672:641]` | `o_fixed_slope_q16` | signed 32-bit Q16 |
| `[688:673]`, `[704:689]`, `[720:705]` | `o_alpha_q15`, `o_beta_q15`, `o_timing_adjust_ratio_q15` | unsigned 16-bit Q1.15 |
| `[752:721]`, `[784:753]`, `[816:785]`, `[848:817]` | `o_slope_min_q16`, `o_slope_max_q16`, `o_baseline_delta_q16`, `o_cross_hysteresis_q16` | signed/unsigned 32-bit Q16 |
| `[864:849]`, `[880:865]` | `o_lead_min_frames`, `o_lead_max_frames` | unsigned 16-bit |
| `[884:881]`, `[888:885]`, `[892:889]`, `[896:893]` | `o_cross_confirm_count`, `o_no_cross_limit`, `o_peak_confirm_count`, `o_valley_confirm_count` | unsigned 4-bit |
| `[920:897]`, `[944:921]` | `o_direction_deadband`, `o_min_peak_valley_amplitude` | unsigned 24-bit |
| `[960:945]`, `[976:961]`, `[992:977]`, `[1008:993]` | `o_min_peak_to_valley_frames`, `o_min_peak_to_peak_frames`, `o_max_fine_window_frames`, `o_max_reacquire_frames` | unsigned 16-bit |
| `[1009]` | `o_peak_valley_config_valid` | 1-bit |
| `[1023:1010]` | no output | reserved, manager requires 0 |

V5 schema `8'h05` is a contract binding external to this payload and is not unpacked from
`[1023:640]`. All V5 outputs are a combinational image of the manager-held
ACTIVE state; this module does not create a reset value, hold register or
default producer.

## 3. 组合行为

- 任一已定义输入位变化后，相关输出只经历组合传播延迟，不等待时钟；
- 除对应字段外的其他输出不得变化；
- signed输出必须保持输入二进制补码bit pattern和数值解释；
- 模块不得产生latch、寄存器、FSM、时钟或复位逻辑；
- 输入包含X/Z时按Verilog组合语义传播，不在解包层掩盖上游未知状态。

## 4. 自检用例

| 用例 | 检查目标 |
| --- | --- |
| UNPACK-01 | 全零联合快照产生全部零功能输出 |
| UNPACK-02 | 逐一激励1024个物理位，V4/V5定义字段保持原位，所有保留区不泄漏 |
| UNPACK-03 | signed 12/20/26/32-bit字段保持负数、正数和Q16编码 |
| UNPACK-04 | 多字段同时变化时无状态、无新增周期地完整传播 |
