# PPG ADC DC恢复接口与数学合同

> Current normative version: V1, 2026-08-20. Status: `ACTIVE_NORMATIVE`; the DC-recovery interface, scaling, fixed-point arithmetic and transaction behavior are normative. System closure is `NOT_CLOSED`; implementation evidence is `EVIDENCE_PENDING`.
> Historical V1 freeze date: 2026-08-07.
> 目标RTL：ppg_adc_dc_recovery.v
> 上游：ppg_adc_programmable_reconstructor.v
> 下游：PPG检测、滤波、动态基线、相交和精细数据输出链

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.2 | AMI parent, generation/discard and recovery integration ownership. |
| C14 | `ppg_system_integration/PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md` | V1.2 | Sole upstream reconstructed NORMAL transaction boundary. |
| C18 | `ppg_system_integration/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.0 | Sole downstream detection-chain integration boundary. |

## 1. 模块目的

本模块把当前DC IDAC抵消作用后的ADC残差恢复为统一的输入等效PPG码。模块同时产生粗精度结果和精细结果，使9-bit检测链与15-bit精细数据链在同一signed 24-bit输出标度下工作。

本模块不重新执行ADC捕获、Stage1校准、Stage2重构、IDAC搜索或模拟时序控制。

## 2. 系统边界

正常数据链固定为：

~~~text
S1_RAW/S2_RAW
    -> Stage1逐物理位校准
    -> result router
    -> pipeline overlap corrector
    -> 15-bit可编程重构
    -> DC恢复
    -> coarse_ppg_value / fine_ppg_value
    -> PPG滤波、baseline、相交、峰谷和数据输出
~~~

DC恢复只处理NORMAL事务。AMB_CAL和DCS_CAL事务属于IDAC控制链，不能被解释为正常生物医学PPG波形。

DC恢复只加回本事务的DC抵消量：

~~~text
正常PPG恢复量 = 本事务dc_code_snapshot的输入等效量
~~~

AMB抵消量不进入正常PPG波形加回路径。amb_code_snapshot和amb_code_epoch仍作为诊断和事务追踪字段透传。

恢复后的PPG结果不得反馈给IDAC范围判断。IDAC控制继续使用未恢复的signed 12-bit Stage1残差。

## 3. 输入结果语义

### 3.1 粗结果输入

粗路径使用：

~~~text
signed [11:0] calibrated_s1_value
~~~

该值已经包含Stage1十个物理位权重、Stage1 offset、Q16对称舍入和signed 12-bit饱和。DC恢复不得再次加入Stage1 offset。

9-bit描述的是Stage1标称分辨率和检测路径角色；calibrated_s1_value仍是signed 12-bit正式输入。

### 3.2 精细结果输入

精细路径使用：

~~~text
signed [14:0] programmable_15_code
~~~

该值已经由ppg_adc_programmable_reconstructor完成Stage1/Stage2可编程重构、Stage2 offset、Q17对称舍入和signed 15-bit饱和。DC恢复不得再次缩放或再次加入Stage2 offset。

programmable_15_code只在15-bit事务有效。9-bit事务的精细结果固定为0，精细资格固定为0。

### 3.3 IDAC码快照

~~~text
dc_code_snapshot[7:0]
~~~

该字段是本次ADC积分实际使用的当前颜色DC抵消码，不是下一次待提交码，也不是控制器的shadow码。它必须与ADC残差属于同一事务。

dc_code_snapshot按unsigned 8-bit幅度码解释。V1冻结：

~~~text
dc_code_snapshot = 0 -> DC恢复加回量 = 0
~~~

V1不实现dc_recovery_offset或非零截距。若流片表征证明零码存在显著且稳定的等效电流截距，必须在后续合同版本中新增该字段。

## 4. 统一输出标度

统一输出标度定义为：

~~~text
1个输出整数LSB = 1个15-bit可编程重构结果LSB
~~~

该标度不是物理电流单位。nA/LSB、uA/LSB等模拟物理参数由片外表征数据库维护；本模块使用的是已经包含模拟前端转换关系的“输入等效PPG码/IDAC LSB”系数。

## 5. DC恢复系数

片内正式保存两组DC输入等效系数：

~~~text
K_DC9  = SAR9 DC IDAC每增加1 LSB对应的统一PPG码
K_DC15 = SAR15 DC IDAC每增加1 LSB对应的统一PPG码
~~~

两者均为：

~~~text
signed 32-bit Q16
~~~

正常已确认的极性下，恢复系数为正值；signed格式用于明确二进制补码算术并保留后续表征扩展能力。配置管理器在NORMAL_PPG合法提交时应拒绝不符合系统极性的系数。

同一精度下红光和红外共用同一个物理DC IDAC，因此共用对应的K_DC9或K_DC15。红光和红外仍分别保存和选择自己的dc_code_snapshot。

AMB IDAC单位电流等效系数不进入V1正常PPG恢复运算。AMB码控制使用ADC残差和LOW/HIGH窗口，不依赖nA/LSB换算。AMB物理系数如需保存，属于后续表征或诊断配置，不得接入本模块算术路径。

## 6. 定点数学合同

### 6.1 9-bit粗路径中心化

Stage1到统一15-bit标度使用已有固定Q16比例：

~~~text
A1_FIXED_Q16 = 23'sd3533837
~~~

先以Stage1标称中心256进行中心化，并以当前粗量化区间的中心作为9-bit估计：

~~~text
S1_CENTER    = signed(calibrated_s1_value) - 256
S1_CENTER_X2 = 2 * S1_CENTER + 1
~~~

等价实数公式：

~~~text
coarse_base = (S1_CENTER + 0.5) * A1_FIXED
~~~

9-bit DC恢复项：

~~~text
dc9_term = unsigned(dc_code_snapshot) * K_DC9_Q16
~~~

为了避免在加法前丢弃半LSB，统一使用Q17累加：

~~~text
COARSE_ACC_Q17 =
      S1_CENTER_X2 * A1_FIXED_Q16
    + 2 * unsigned(dc_code_snapshot) * K_DC9_Q16
~~~

### 6.2 15-bit精细路径

15-bit重构器输出已经是signed整数统一标度，转换到Q17：

~~~text
FINE_BASE_Q17 = signed(programmable_15_code) * 2^17
~~~

15-bit DC恢复项：

~~~text
dc15_term = unsigned(dc_code_snapshot) * K_DC15_Q16
~~~

统一Q17累加：

~~~text
FINE_ACC_Q17 =
      signed(programmable_15_code) * 2^17
    + 2 * unsigned(dc_code_snapshot) * K_DC15_Q16
~~~

STAGE2_OFFSET_Q16作为signed加性截距，已经在15-bit可编程重构器内部加入，不得在DC恢复模块重复加入。

### 6.3 粗精度与精细精度拟合约束

Stage1和Stage2必须使用同一个片外参考标度分层拟合：

~~~text
第一步：用Stage1物理位权重和Stage1 offset拟合粗区间中心估计Y9
第二步：计算FINE_ERROR = reference_common - Y9
第三步：按FINE_ERROR = D2_CENTER * STAGE2_GAIN + STAGE2_OFFSET拟合剩余误差
~~~

因此STAGE2_OFFSET是Stage1粗估计之后剩余误差模型的signed加性截距，不是任意的模式切换偏移。片外拟合应直接输出标准形式`y = kx + b`中的`b`并写入该字段；正值提高15-bit结果，负值降低15-bit结果。9-bit模式不使用STAGE2_OFFSET，也不增加独立coarse offset。

两种精度的系统性零点和单位标度必须对齐；单笔9-bit结果仍只代表粗区间中心，允许与同一模拟输入的15-bit结果存在真实低位量化修正。该修正不属于模式切换错误。

### 6.4 内部位宽

V1使用显式signed中间量：

| 中间量 | 位宽 | 说明 |
| --- | ---: | --- |
| S1_CENTER_X2 | signed 14 | 覆盖signed 12-bit Stage1完整范围和中心补偿 |
| stage1_product_q17 | signed 37 | 14-bit乘23-bit Q16比例 |
| dc9_product_q16 | signed 41 | signed 32-bit系数乘signed 9-bit正码 |
| dc15_product_q16 | signed 41 | signed 32-bit系数乘signed 9-bit正码 |
| coarse_acc_q17 | signed 42 | DC项和Stage1项累加不自然回绕 |
| fine_acc_q17 | signed 42 | DC项和signed 15-bit残差累加不自然回绕 |
| round_work | signed 43 | 绝对值、加半LSB和最小负数保护 |

所有乘法、符号扩展、左移、加法和舍入常量必须显式位宽。禁止依赖Verilog表达式的隐式signed/unsigned扩展。

### 6.5 舍入和输出饱和

Q17到signed整数执行正负对称舍入，恰好半LSB时远离零：

~~~text
if ACC_Q17 >= 0:
    rounded = (ACC_Q17 + 65536) >>> 17
else:
    rounded = -(((-ACC_Q17) + 65536) >>> 17)
~~~

最终输出为signed 24-bit：

~~~text
PPG_CODE_MIN = -8388608
PPG_CODE_MAX = +8388607
~~~

不得依赖24-bit自然截断实现饱和。输出端点标志必须互斥：

~~~text
saturation_low  = rounded < PPG_CODE_MIN
saturation_high = rounded > PPG_CODE_MAX
~~~

粗路径和精细路径分别产生饱和标志。

## 7. 有效性和资格

本模块区分“产生了数值”和“该数值已完成正式校准”两个概念。

### 7.1 粗路径

只要本笔是被接受的NORMAL事务，粗结果就有数值：

~~~text
o_coarse_valid = o_result_valid
~~~

正式校准资格为：

~~~text
o_coarse_recovery_calibrated =
    i_calibration_applied && i_dc9_recovery_valid
~~~

### 7.2 精细路径

~~~text
o_fine_valid =
    o_result_valid && i_precision_mode && i_programmable_15_valid
~~~

正式校准资格为：

~~~text
o_fine_recovery_calibrated =
    i_programmable_15_calibration_applied
    && i_dc15_recovery_valid
~~~

CHARACTERIZATION允许使用标称或临时系数进行计算并导出结果，但相应recovery_calibrated必须为0。NORMAL_PPG启动资格由系统配置管理器检查；在系统允许自动进入15-bit时，dc9_recovery_valid和dc15_recovery_valid均必须为1。

Stage1/Stage2饱和不丢弃事务。输入饱和标志、15-bit可编程重构饱和标志和本模块新增的恢复饱和标志分别保留，后续算法可以据此屏蔽或诊断异常样本。

## 8. 事务接口

### 8.1 单原子ready/valid

本模块使用一个输入和一个输出保持型ready/valid接口：

~~~text
input_transfer  = i_result_valid && o_result_ready
output_transfer = o_result_valid && i_result_ready
~~~

模块包含一个元素的输出缓存和一个寄存器延迟。下游反压时，粗结果、精细结果、资格标志、饱和标志和全部元数据逐拍保持不变。

### 8.2 同一事务内的双精度结果

本模块输出一个原子载荷，同时包含：

~~~text
o_coarse_ppg_value
o_coarse_valid
o_coarse_recovery_calibrated
o_coarse_saturation_low/high

o_fine_ppg_value
o_fine_valid
o_fine_recovery_calibrated
o_fine_saturation_low/high
~~~

9-bit事务中o_fine_ppg_value固定为0且o_fine_valid=0；15-bit事务中粗结果和精细结果都保持有效。后续若需要两个独立下游消费者，必须使用显式事务fork/缓存，不得把同一输入事务无界复制给多个消费者。

## 9. 元数据透传

以下字段必须和两个结果原子对齐并在反压期间保持稳定：

~~~text
config_epoch
coef_epoch
stage2_coef_epoch
dc_recovery_coef_epoch
precision_mode
frame_id
sample_index
color_ir
frame_type
dc_code_snapshot
dc_code_epoch
amb_code_snapshot
amb_code_epoch
Stage1/Stage2 calibration and saturation flags
~~~

AMB字段不参与正常PPG算术，但必须保留用于诊断和流片数据关联。

## 10. ACTIVE V3配置扩展

ACTIVE V3将现有512-bit V2快照扩展为640-bit。V2已定义字段保持原位：

| ACTIVE位 | 字段 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| [7:0] | schema_version | 8 | V3固定为8'h03 |
| [19] | stage1_calibration_valid | 1 | Stage1系数合法资格 |
| [20] | stage2_calibration_valid | 1 | Stage2系数合法资格 |
| [21] | dc9_recovery_valid | 1 | SAR9 DC恢复系数合法资格 |
| [22] | dc15_recovery_valid | 1 | SAR15 DC恢复系数合法资格 |
| [31:23] | reserved_header_v3 | 9 | 必须为0 |
| [479:460] | stage2_gain_q16 | signed 20 | Stage2统一Q16增益 |
| [511:480] | stage2_offset_q16 | signed 32 | 15-bit剩余误差拟合的加性截距 |
| [543:512] | dc9_recovery_gain_q16 | signed 32 | SAR9 DC输入等效系数 |
| [575:544] | dc15_recovery_gain_q16 | signed 32 | SAR15 DC输入等效系数 |
| [639:576] | reserved_extension_v3 | 64 | V3必须为0，供后续版本扩展 |

dc_recovery_coef_epoch[7:0]不是快照数值字段，由配置管理器独立维护。每次合法提交DC恢复字段组时递增一次，字段组包括两个gain和两个valid位；按模256回绕。一次COMMIT同时改变多个DC恢复字段时只递增一次。

配置管理器必须检查：

- schema为V3；
- [639:576]全部为0；
- [31:23]全部为0；
- dc9_recovery_valid为1时，dc9_recovery_gain_q16满足系统极性和范围要求；
- dc15_recovery_valid为1时，dc15_recovery_gain_q16满足系统极性和范围要求；
- 非法或不完整COMMIT不得改变ACTIVE快照或任何epoch。

V1不实现dc_recovery_offset。如果后续表征确认存在稳定零码截距，应版本化扩展reserved_extension_v3或发布V4，不得在V1中解释保留位。

## 11. 模块端口合同

目标RTL沿用现有参数默认值：

~~~verilog
parameter integer C_FRAME_ID_WIDTH = 16
parameter integer C_SAMPLE_INDEX_WIDTH = 16
parameter integer C_IDAC_CODE_WIDTH = 8
parameter integer C_CODE_EPOCH_WIDTH = 4
parameter integer C_CONFIG_EPOCH_WIDTH = 8
parameter integer C_COEF_EPOCH_WIDTH = 8
parameter integer C_RUN_GENERATION_WIDTH = 8
~~~

并新增：

~~~verilog
parameter integer C_DC_RECOVERY_EPOCH_WIDTH = 8
~~~

### 11.1 全局和配置输入

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | i_clk | 1 | 2 MHz数字处理域工作时钟 |
| input | i_rstn | 1 | 低有效异步复位，释放由系统顶层同步 |
| input | i_active_valid | 1 | 当前ACTIVE V3快照具备事务接收资格 |
| input | i_dc9_recovery_valid | 1 | SAR9 DC恢复系数合法资格 |
| input | i_dc15_recovery_valid | 1 | SAR15 DC恢复系数合法资格 |
| input | i_dc9_recovery_gain_q16 | signed 32 | SAR9 DC输入等效系数 |
| input | i_dc15_recovery_gain_q16 | signed 32 | SAR15 DC输入等效系数 |
| input | i_dc_recovery_coef_epoch | 8 | 当前DC恢复系数组版本 |
| input | i_run_generation | `C_RUN_GENERATION_WIDTH` | AMI逐层传入；仅在输入事务接受沿与完整身份原子锁存。 |
| input | i_datapath_discard_event / reason / identity_valid / `<TXN_ID>` | `1/2/1/each field` | AMI私有注册释放组；无ready/ack，完整ID在事件采样沿稳定。 |
| output | o_local_empty | 1 | 已注册本地排空状态；唯一消费者AMI，匹配discard后最早下一周期为1。 |

### 11.2 上游事务输入

至少包含：

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | i_result_valid | 1 | 重构器保持的NORMAL事务有效 |
| output | o_result_ready | 1 | DC恢复模块可以接收新事务 |
| input | i_calibrated_s1_value | signed 12 | Stage1正式校准残差 |
| input | i_calibration_applied | 1 | Stage1系数合法资格 |
| input | i_stage1_saturation_low | 1 | Stage1输入负向饱和诊断 |
| input | i_stage1_saturation_high | 1 | Stage1输入正向饱和诊断 |
| input | i_programmable_15_code | signed 15 | 15-bit正式重构残差 |
| input | i_programmable_15_valid | 1 | 当前事务具有正式15-bit结果 |
| input | i_programmable_15_calibration_applied | 1 | Stage1和Stage2校准资格 |
| input | i_programmable_saturation_low | 1 | 15-bit重构负向饱和诊断 |
| input | i_programmable_saturation_high | 1 | 15-bit重构正向饱和诊断 |
| input | i_config_epoch | 8 | 本笔ACTIVE配置版本 |
| input | i_coef_epoch | 8 | 本笔Stage1系数组版本 |
| input | i_stage2_coef_epoch | 8 | 本笔Stage2系数组版本 |
| input | i_precision_mode | 1 | 0为9-bit，1为15-bit |
| input | i_dc_code_snapshot | 8 | 本笔当前颜色DC实际码 |

### 11.3 事务元数据和诊断透传

下列每个输入必须产生同名o_前缀输出，位宽和bit pattern保持不变：

| 输入端口 | 对应输出 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| i_calibrated_s1_value | o_calibrated_s1_value | signed 12 | Stage1正式校准残差诊断值 |
| i_calibration_applied | o_calibration_applied | 1 | Stage1校准资格 |
| i_stage1_saturation_low | o_stage1_saturation_low | 1 | Stage1负向饱和诊断 |
| i_stage1_saturation_high | o_stage1_saturation_high | 1 | Stage1正向饱和诊断 |
| i_programmable_15_code | o_programmable_15_code | signed 15 | 15-bit正式重构残差诊断值 |
| i_programmable_15_valid | o_programmable_15_valid | 1 | 15-bit数值资格 |
| i_programmable_15_calibration_applied | o_programmable_15_calibration_applied | 1 | Stage1和Stage2联合校准资格 |
| i_programmable_saturation_low | o_programmable_saturation_low | 1 | 15-bit负向饱和诊断 |
| i_programmable_saturation_high | o_programmable_saturation_high | 1 | 15-bit正向饱和诊断 |
| i_config_epoch | o_config_epoch | 8 | ACTIVE配置版本 |
| i_coef_epoch | o_coef_epoch | 8 | Stage1系数组版本 |
| i_stage2_coef_epoch | o_stage2_coef_epoch | 8 | Stage2系数组版本 |
| i_detect_code | o_detect_code | 9 | 固定Stage1黄金码 |
| i_stage1_raw | o_stage1_raw | 10 | Stage1物理判决位 |
| i_stage1_code_ext | o_stage1_code_ext | signed 11 | 固定D1_EXT诊断值 |
| i_stage2_raw | o_stage2_raw | 10 | Stage2物理判决位 |
| i_stage2_code_ext | o_stage2_code_ext | signed 11 | 固定D2_EXT诊断值 |
| i_nominal_15_code | o_nominal_15_code | signed 15 | 固定标称15-bit黄金结果 |
| i_nominal_15_valid | o_nominal_15_valid | 1 | 标称15-bit结果资格 |
| i_nominal_saturated | o_nominal_saturated | 1 | 标称15-bit饱和诊断 |
| i_precision_mode | o_precision_mode | 1 | 9/15-bit事务模式 |
| i_frame_id | o_frame_id | 16 | R/IR共享帧号 |
| i_sample_index | o_sample_index | 16 | 当前结果样本序号 |
| i_color_ir | o_color_ir | 1 | 0红光，1红外 |
| i_frame_type | o_frame_type | 2 | NORMAL固定为2'b10 |
| i_amb_code_snapshot | o_amb_code_snapshot | 8 | 本笔AMB实际码，仅透传 |
| i_dc_code_snapshot | o_dc_code_snapshot | 8 | 本笔当前颜色DC实际码 |
| i_amb_code_epoch | o_amb_code_epoch | 4 | 本笔AMB码版本 |
| i_dc_code_epoch | o_dc_code_epoch | 4 | 本笔当前颜色DC码版本 |

参数化字段必须使用对应C_*_WIDTH，表中数字为V1默认值。上游不得在i_result_valid为1时提交非NORMAL事务；i_frame_type不等于2'b10属于集成协议错误，不能被解释为有效PPG结果。

### 11.4 下游数据输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | i_result_ready | 1 | 下游允许消费当前原子事务 |
| output | o_result_valid | 1 | 输出原子载荷保持有效 |
| output | o_coarse_ppg_value | signed 24 | 统一标度的粗PPG值 |
| output | o_coarse_valid | 1 | 当前事务具有粗结果 |
| output | o_coarse_recovery_calibrated | 1 | 粗结果使用合法Stage1和DC9系数 |
| output | o_coarse_saturation_low | 1 | 粗恢复结果的24-bit负向饱和诊断 |
| output | o_coarse_saturation_high | 1 | 粗恢复结果的24-bit正向饱和诊断 |
| output | o_fine_ppg_value | signed 24 | 统一标度的精细PPG值 |
| output | o_fine_valid | 1 | 当前事务具有精细结果 |
| output | o_fine_recovery_calibrated | 1 | 精细结果使用合法15-bit和DC15系数 |
| output | o_fine_saturation_low | 1 | 精细恢复结果的24-bit负向饱和诊断 |
| output | o_fine_saturation_high | 1 | 精细恢复结果的24-bit正向饱和诊断 |
| output | o_dc_recovery_coef_epoch | 8 | 本笔实际使用的DC恢复系数组版本 |
| output | o_run_generation | `C_RUN_GENERATION_WIDTH` | 与coarse/fine结果同一原子事务输出到AMI双fork。 |

所有版本、诊断和事务元数据输出均需与上述两个结果原子对齐。

### 11.5 代际、私有discard与local empty

DC恢复必须接收并逐位保持
`i_run_generation[C_RUN_GENERATION_WIDTH-1:0]`，并把它作为完整事务身份的一
部分输出给AMI双fork。若本模块保留AMI唯一产生的私有注册组：

```text
i_datapath_discard_event
i_datapath_discard_reason[1:0]
i_datapath_discard_ID
```

该组无ready或ack；事件、reason和完整ID在采样沿稳定。ID匹配的事件在该沿
恰好一次清除DC恢复输出缓存和本地pending，不得产生正式结果、completion、
fault、owner release或physical idle。`o_local_empty`只表示DC恢复本地无缓存
和无pending，最早在discard采样沿的下一周期报告为1；AMI是其唯一聚合消费者。
陈旧generation不产生输出或算法状态变化。STOP、abort和system fault不得存在
绕过该事件的第二个直接清除端口。

> **2026-09-07合同文字修订（取代下方2026-09-05待定注记，选项3执行）**：本节
> 此前无条件要求这组discard-broadcast端口+`o_local_empty`输出。按P1
> investigation的五点证据链（完整证据见
> `PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md`§6.1，同一结论逐字适用于
> 本模块），合法START已经要求AMI自己的`o_datapath_empty`，其公式包含本模块
> 自己的held-output valid信号——所以`i_run_generation`推进前本模块必然已被
> 结构性保证排空，这组端口原本要防护的场景在当前RTL下没有路径可以发生。
> **本模块当前不要求实现discard-broadcast端口组+`o_local_empty`输出。这是
> 有条件的免除，不是无条件删除**：完全依赖`flag_start_accept`公式包含
> `i_datapath_empty`、以及AMI的`o_datapath_empty`公式包含本模块held-output
> valid信号这两处当前写法，任一改变都必须重新核实这条链条是否依然成立，一旦
> 不成立必须把这组端口补齐为真实实现，不能只靠文档记录了事。完整证据链详见
> memory `project-ppg-p1-discard-broadcast-investigation-20260905`。

## 12. ready/valid和时序合同

V1采用一个寄存输出缓冲，无额外内部流水级：

~~~text
buffer_available = !o_result_valid || i_result_ready
o_result_ready = i_rstn && i_active_valid && buffer_available
~~~

行为冻结为：

1. 只在input_transfer上升沿读取结果、配置和元数据；
2. 输入传输沿完成两条算术路径并锁存完整输出载荷；
3. 从该沿之后输出有效，形成一个寄存周期延迟；
4. o_result_valid为1且i_result_ready为0期间，所有输出位逐拍稳定；
5. 旧输出被消费且同拍有新输入时，直接替换载荷并保持valid为1；
6. 只有旧输出被消费且没有新输入时，下一拍valid清零；
7. i_result_valid为0时，输入数据、配置或元数据变化不得改变事务状态；
8. ACTIVE配置不得在RUN或任何在途事务期间改变。

如果后续ASIC STA证明单周期乘加不能满足2 MHz，必须通过新合同版本增加流水级；V1 RTL不得自行改变延迟。

## 13. 复位合同

i_rstn为0时：

- o_result_valid和o_result_ready为0；
- coarse/fine值、valid、校准资格和饱和标志为0；
- 所有epoch和透传元数据清零；
- 不得产生伪事务。

异步复位释放由系统顶层同步。复位打断反压中的输出时，旧事务不得在复位后复活。

## 14. 配置与生命周期要求

NORMAL_PPG启动必须同时满足：

~~~text
active_valid = 1
stage1_calibration_valid = 1
stage2_calibration_valid = 1
dc9_recovery_valid = 1
dc15_recovery_valid = 1
~~~

CHARACTERIZATION允许使用标称或临时DC恢复系数，但正式校准资格保持为0。临时系数仍必须在CONFIG阶段写入SHADOW并通过合法COMMIT进入ACTIVE，不能在RUN中直接覆盖。

ACTIVE V3、DC系数和各epoch在RUN期间保持稳定。STOPPING必须等待DC恢复输出缓存和后续算法链排空。

## 15. 验收矩阵

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| DCR-01 | 复位 | valid、结果、资格、饱和标志、epoch和载荷为规定复位值 |
| DCR-02 | 9-bit中心值 | calibrated_s1_value为256时按+0.5区间中心规则计算 |
| DCR-03 | 9-bit正负边界 | Stage1中心化、A1固定比例和对称舍入正确 |
| DCR-04 | 9-bit DC码为0 | DC恢复项严格为0 |
| DCR-05 | K_DC9正值 | DC码每增加1，恢复结果按K_DC9增加 |
| DCR-06 | 15-bit DC码为0 | 输出等于programmable_15_code的统一标度值 |
| DCR-07 | K_DC15正值 | DC码每增加1，恢复结果按K_DC15增加 |
| DCR-08 | Q16半LSB边界 | 正负对称舍入且tie远离零 |
| DCR-09 | signed 24-bit上下溢出 | 分别饱和到-8388608和+8388607，标志互斥 |
| DCR-10 | 9/15连续切换 | coarse/fine资格与事务模式不错拍 |
| DCR-11 | 15-bit事务双结果 | coarse和fine同一事务、同一metadata、同一ready/valid |
| DCR-12 | 系数无效CHARACTERIZATION | 允许计算，正式校准资格为0 |
| DCR-13 | NORMAL无效系数 | 系统不允许正式启动；模块不伪造校准资格 |
| DCR-14 | 上游Stage1/Stage2饱和 | 事务不丢弃，各级饱和状态分别保持 |
| DCR-15 | 输出反压 | 两个结果、资格、标志和全部metadata完全保持 |
| DCR-16 | 同拍消费替换 | 无空拍、无覆盖、事务顺序正确 |
| DCR-17 | 配置输入变化 | 已接受事务仍使用锁存的系数和epoch |
| DCR-18 | epoch回绕 | 版本按模256传递，资格不由epoch数值推导 |
| DCR-19 | AMB字段变化 | AMB码和epoch只透传，不进入恢复算术 |
| DCR-20 | 多颜色事务 | R/IR选择各自DC码快照，但同精度使用同一DC系数 |
| DCR-21 | 粗精度与精细精度联合拟合 | 两种模式无与输入无关的固定台阶，只保留真实低位量化修正 |
| DCR-22 | 非NORMAL输入协议检查 | testbench识别并报告上游集成协议错误，不生成正常PPG期望值 |

自检TB必须使用独立宽位整数定点黄金模型，覆盖正负输入、半LSB、全部DC码端点、模式切换、反压、同拍替换、饱和、无效资格和epoch回绕。PASS只能在全部用例执行且错误计数为0后产生。

## 16. RTL交付门禁

实现时必须满足：

- 可综合Verilog-2001；
- Erie strict命名、双语文件头、中文实体注释和区域结构；
- 所有signed扩展、乘法、左移、累加器、舍入和饱和比较显式位宽；
- 时序逻辑使用非阻塞赋值，组合逻辑完整赋值，无latch和多驱动；
- 不使用RTL function或task隐藏定点算术；
- 不使用原始门控时钟、延时、initial或仿真专用系统任务；
- formatter-AST严格门禁、独立lint、Vivado xsim自检和OOC综合全部通过；
- 综合报告确认无锁存器、黑盒、组合环和不可解释的位宽截断。

## 17. V1冻结结论

V1 DC恢复模块冻结为：

- Stage1中心化加+0.5的粗区间中心估计；
- 与15-bit重构器一致的A1_FIXED_Q16统一比例；
- 独立的signed 32-bit Q16 K_DC9和K_DC15；
- 零码为零恢复量的线性DC模型；
- signed 42-bit Q17内部累加器；
- 正负对称、半LSB远离零的舍入；
- signed 24-bit显式饱和输出；
- 单原子保持型ready/valid事务，同时携带coarse和fine结果；
- 独立DC系数valid标志和8-bit dc_recovery_coef_epoch；
- 正常PPG不恢复AMB抵消量；
- V3 联合ACTIVE兼容说明：V4 `[639:0]` 保持原位图和保留位约束；V5 `[1023:640]` 不进入DC recovery，由AMI/PWI检测链唯一消费。
- V1不实现dc_recovery_offset，后续截距需求必须版本化。

任何改变上述标度、公式、系数归属、事务延迟、有效性语义、配置版本或保留位解释的实现，都必须先修订本合同，再修改RTL。
