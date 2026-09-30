# PPG ADC 15-bit可编程重构器接口合同

> Current normative version: V1.2, 2026-08-20. Status: `ACTIVE_NORMATIVE`; ID/generation pass-through and local-drain ownership remain normative. System closure is `NOT_CLOSED`; implementation evidence is `EVIDENCE_PENDING`.

> Historical V1 interface freeze date: 2026-08-06. The former "ACTIVE configuration V2" label is historical and has no current normative force; the current joint ACTIVE authority is C04 V1.7.
> 上游模块：ppg_adc_pipeline_overlap_corrector.v
> 目标模块：ppg_adc_programmable_reconstructor.v
> 下游模块：15-bit DC等效量恢复和精细PPG数据链

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.3 | AMI parent, generation/discard and data-chain integration ownership. |
| C13 | `ppg_system_integration/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md` | V1.2 | Sole upstream overlap-corrected NORMAL transaction boundary. |
| C15 | `ppg_system_integration/PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md` | V1 | Sole downstream DC-recovery boundary. |

## 1. 模块职责

本模块声明`C_RUN_GENERATION_WIDTH=8`参数；所有`i_run_generation`及输出身份字段
均使用`[C_RUN_GENERATION_WIDTH-1:0]`，由AMI逐层传入并在elaboration检查相等。

本模块把一笔已经经过Stage1可编程校准、并由overlap corrector对齐的NORMAL事务转换为可编程15-bit残差结果。

~~~text
ppg_adc_pipeline_overlap_corrector
    | calibrated_s1_value、D2_EXT、S1/S2 RAW和统一事务元数据
    v
ppg_adc_programmable_reconstructor
    | programmable_15_code、资格、饱和状态和全部元数据
    v
ppg_dc_equivalent_restorer（后续模块）
~~~

本模块负责：

- 使用已校准的signed 12-bit Stage1整数结果作为Stage1输入；
- 使用overlap corrector输出的signed 11-bit D2_EXT作为Stage2首版输入；
- 使用一个可编程signed 20-bit Q16 Stage2统一增益；
- 使用一个可编程signed 32-bit Q16 15-bit输出offset；
- 完成显式定点乘加、正负对称舍入和signed 15-bit饱和；
- 原子保持可编程结果、资格、版本、饱和标志和原事务元数据。

本模块不负责：

- ADC异步DONE同步、RAW捕获或Stage1逐物理位校准；
- 重新计算detect_code、D1_EXT或Stage1饱和标志；
- 使用已经舍入饱和的nominal_15_code进行二次重构；
- IDAC搜索、IDAC码更新、DC恢复、滤波、基线、相交或峰谷算法；
- 在线NLMS或其它片内自适应系数迭代。

## 2. 输入数据选择

### 2.1 正式计算输入

Stage1输入固定为上游事务中的：

~~~text
signed [11:0] calibrated_s1_value
~~~

本模块不得使用detect_code、D1_EXT或重新压缩的RAW替代该输入。

Stage2首版只使用overlap corrector已经解码的：

~~~text
signed [10:0] D2_EXT
~~~

完整S2_RAW[9:0]继续作为透传和测试导出字段保存，以便流片数据证明需要Stage2逐物理位校准时扩展合同。

### 2.2 9-bit事务

precision_mode=0时：

- 本模块仍接收并透传统一NORMAL事务，不能造成上游阻塞；
- 不执行Stage2乘加；
- programmable_15_code固定为0；
- programmable_15_valid=0；
- 15-bit饱和标志和15-bit校准资格固定为0；
- Stage1校准结果、固定黄金字段和全部元数据保持原值。

### 2.3 15-bit事务

precision_mode=1时，每一笔正常事务执行一次15-bit重构。S1_RAW、S2_RAW、Stage1结果、精度模式、颜色、帧号、样本号、IDAC快照和所有epoch必须属于同一事务。

固定nominal_15_code、nominal_15_valid和nominal_saturated只作为黄金参考和诊断旁路，不得进入本模块的正式算术路径。

## 3. 定点数学合同

### 3.1 中心化与公式

先把Stage1和Stage2转换到重构中点标度：

~~~text
S1_CENTER = signed(calibrated_s1_value) - 256
D2_CENTER = signed(D2_EXT) - 256
~~~

正式实数公式按分层拟合关系定义为：

~~~text
Y9_BASE_Q16 = (S1_CENTER + 0.5) * A1_FIXED_Q16

FINE_ERROR_Q16 = D2_CENTER * STAGE2_GAIN_Q16
                 + STAGE2_OFFSET_Q16

Y_Q16 = Y9_BASE_Q16 + FINE_ERROR_Q16
~~~

`STAGE2_OFFSET_Q16`冻结为signed加性截距，对应片外线性拟合标准形式`y = kx + b`中的`b`。正值提高15-bit重构结果，负值降低15-bit重构结果；片外软件必须直接写入拟合得到的有符号截距，不得因offset名称额外取负。若表征工具内部采用`FINE_ERROR = D2_CENTER * gain - O`，提交ACTIVE配置前必须转换为`STAGE2_OFFSET_Q16 = -O`。

固定Stage1到15-bit的标称比例为：

~~~text
A1_FIXED_Q16 = 23'sd3533837
~~~

Stage2统一增益的标称值为：

~~~text
STAGE2_GAIN_Q16 = 20'sd54143
~~~

标称Stage2 offset为：

~~~text
STAGE2_OFFSET_Q16 = 32'sd0
~~~

使用上述标称值时，合法物理输入范围内的结果必须与固定overlap标称公式一致；本模块不得读取或再次缩放nominal_15_code。

### 3.2 Q17整数实现

为精确实现Stage1的+0.5，RTL使用倍增形式：

~~~text
S1_CENTER_X2 = 2 * S1_CENTER + 1
D2_CENTER_X2 = 2 * D2_CENTER

ACC_Q17 = S1_CENTER_X2 * A1_FIXED_Q16
        + D2_CENTER_X2 * STAGE2_GAIN_Q16
        + 2 * STAGE2_OFFSET_Q16
~~~

所有乘积、符号扩展和累加必须显式位宽。V1位宽要求为：

| 中间量 | signed位宽 | 说明 |
| --- | ---: | --- |
| S1_CENTER_X2 | 14 | 覆盖signed 12-bit Stage1输入完整范围 |
| D2_CENTER_X2 | 11 | 覆盖signed 11-bit D2_EXT合法范围 |
| Stage1乘积 | 37 | 14-bit乘23-bit |
| Stage2乘积 | 31 | 11-bit乘20-bit |
| 2*STAGE2_OFFSET_Q16 | 33 | Q17 offset |
| ACC_Q17 | 38 | 累加不自然回绕 |

### 3.3 舍入与饱和

Q17到整数采用最接近整数、正负对称、恰好半LSB时远离零：

~~~text
if ACC_Q17 >= 0:
    rounded = (ACC_Q17 + 65536) >>> 17
else:
    rounded = -(((-ACC_Q17) + 65536) >>> 17)
~~~

舍入前必须先扩展到至少39 bit处理绝对值，避免最小负数取负溢出。

最终输出范围固定为signed 15-bit：

~~~text
PROGRAMMABLE_15_MIN = -16384
PROGRAMMABLE_15_MAX = +16383
~~~

programmable_saturation_low只在未钳位舍入结果小于-16384时置1；programmable_saturation_high只在未钳位舍入结果大于+16383时置1；两者互斥。禁止依赖15-bit自然截断实现饱和。

## 4. ACTIVE配置V2

当前ACTIVE V1的reserved_extension[511:460]升级为Stage2配置字段，schema_version由8'h01升级为8'h02。

| ACTIVE位 | 字段 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| [20] | stage2_calibration_valid | 1 | Stage2片外拟合系数完整且合法 |
| [31:21] | reserved_header_v2 | 11 | 必须为0 |
| [479:460] | stage2_gain_q16 | signed 20 | Stage2统一增益，Q16 |
| [511:480] | stage2_offset_q16 | signed 32 | 15-bit残差拟合的加性截距，Q16 |

stage2_coef_epoch[7:0]是配置管理器的独立版本标签，不占用512-bit数值快照字段。每次合法Stage2系数提交递增一次，按模256回绕；CHARACTERIZATION装载标称Stage2系数时不递增，并保持stage2_calibration_valid=0。

正式NORMAL_PPG启动资格必须同时满足Stage1和Stage2所需系数已经合法提交。CHARACTERIZATION可以使用标称Stage2系数产生有效15-bit结果，但programmable_15_calibration_applied=0。

## 5. 端口合同

### 5.1 全局和配置输入

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | i_clk | 1 | 2 MHz数字处理时钟 |
| input | i_rstn | 1 | 低有效异步复位 |
| input | i_run_generation | `C_RUN_GENERATION_WIDTH` | AMI逐层传入；只在输入握手沿锁存。 |
| input | i_datapath_discard_event / reason / identity_valid / `<TXN_ID>` | `1/2/1/each field` | AMI私有注册释放组；无ready/ack，事件和完整ID在接收沿稳定。 |
| output | o_local_empty | 1 | 已注册本地排空状态；唯一消费者AMI，匹配discard后最早下一周期为1。 |
| input | i_active_valid | 1 | ACTIVE快照具备接收资格 |
| input | i_stage2_calibration_valid | 1 | 当前Stage2系数是否合法 |
| input | i_stage2_gain_q16 | signed 20 | Stage2统一增益 |
| input | i_stage2_offset_q16 | signed 32 | 直接加入Stage2残差项的有符号Q16截距 |
| input | i_stage2_coef_epoch | 8 | Stage2系数组版本 |

### 5.2 事务输入

事务输入沿用overlap corrector的完整输出载荷：

~~~text
i_result_valid / o_result_ready
i_calibrated_s1_value[11:0]
i_calibration_applied
i_saturation_low / i_saturation_high
i_config_epoch[7:0]
i_coef_epoch[7:0]
i_detect_code[8:0]
i_stage1_raw[9:0]
i_stage1_code_ext[10:0]
i_stage2_raw[9:0]
i_stage2_code_ext[10:0]
i_nominal_15_code[14:0]
i_nominal_15_valid
i_nominal_saturated
i_precision_mode
i_frame_id
i_sample_index
i_color_ir
i_frame_type
i_amb_code_snapshot
i_dc_code_snapshot
i_amb_code_epoch
i_dc_code_epoch
~~~

参数化字段沿用overlap corrector的默认位宽：frame_id=16、sample_index=16、IDAC码=8、IDAC code epoch=4、配置和系数epoch=8。

### 5.3 事务输出

输出使用单一保持型结果接口：

~~~text
o_result_valid / i_result_ready
o_programmable_15_code signed [14:0]
o_programmable_15_valid
o_programmable_15_calibration_applied
o_programmable_saturation_low / o_programmable_saturation_high
o_stage2_coef_epoch[7:0]
~~~

同时逐位透传Stage1校准字段、固定黄金字段、S1_RAW/S2_RAW、D1_EXT/D2_EXT、nominal_15_code及全部原事务元数据。

### 5.1 Generation and local drain

The reconstructor receives and forwards the complete transaction identity,
including `i_run_generation[C_RUN_GENERATION_WIDTH-1:0]`, without extension or
truncation. A stale generation produces no output. `o_local_empty` reports
only its registered arithmetic/output state to AMI; AMI remains the sole
`datapath_empty` owner. Reconstructor does not create injection, fault,
discard, completion or physical-idle semantics.

If this module retains an AMI-private discard-broadcast group (`i_datapath_
discard_event/reason/ID`), that group is the sole terminal clear path for a
retained reconstructor result before the DC-result fork: a registered
one-cycle 2 MHz event with no ready/acknowledgement, reason and full ID
stable at its sampling edge, a matching event clears only the matching local
hold exactly once, causes no result/completion/fault, and permits
`o_local_empty` no earlier than the following cycle; STOP/abort must not be
implemented as a second direct clear port alongside it.

> **2026-09-07 contract revision (supersedes the 2026-09-05 pending note
> below, Option 3 executed)**: this section previously required the
> discard-broadcast port group unconditionally. Per the P1 investigation's
> five-point evidence chain (`PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md`
> §6.1 carries the full chain; same conclusion applies here verbatim), a legal
> START already requires AMI's own `o_datapath_empty`, whose formula includes
> this module's own held-output valid signal -- so `i_run_generation` cannot
> advance while this module still holds prior-generation data, and the
> scenario this port group exists to guard against has no reachable path
> under current RTL. **This module does not currently require the
> discard-broadcast port group + `o_local_empty` output. This is a
> conditional exemption, not an unconditional deletion**: it depends entirely
> on `flag_start_accept`'s formula including `i_datapath_empty` and AMI's
> `o_datapath_empty` formula including this module's held-output valid signal,
> both as currently written -- anyone changing either formula must re-verify
> this chain still holds, and if it no longer holds, the port group must be
> retrofitted as a real implementation, not left as a documentation note.
> Full evidence: memory `project-ppg-p1-discard-broadcast-investigation-20260905`.

## 6. ready/valid和时序

V1采用单元素寄存输出缓存，不增加内部流水级：

~~~text
buffer_available = !o_result_valid || i_result_ready
o_result_ready = i_rstn && i_active_valid && buffer_available
input_transfer = i_result_valid && o_result_ready
output_transfer = o_result_valid && i_result_ready
~~~

输入传输沿锁存全部算术结果和元数据，下一拍形成输出有效。输出有效且下游反压时，所有输出字段逐拍保持不变。旧结果被消费且同拍有新输入时，原子替换且不插入空拍。

## 7. 复位

i_rstn=0时：

- o_result_valid=0、o_result_ready=0；
- 15-bit结果、资格、15-bit饱和标志、Stage2 epoch和所有透传载荷清零；
- 复位期间不得产生伪事务；
- 反压期间复位立即撤销旧valid，复位后旧事务不得复活。

## 8. 边界和下游约束

- 15-bit结果只供DC等效量恢复、精细PPG记录和数据输出，不驱动IDAC判断；
- IDAC仍只消费signed 12-bit calibrated_s1_value；
- 9-bit与15-bit结果最终必须由后续DC恢复模块转换到同一输入等效标度；
- 本模块不改变config_epoch或Stage1 coef_epoch，只绑定并透传；
- nominal_15_code可以进入测试导出，但不得参与正式算术。

## 9. 自检TB验收矩阵

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| PR-01 | 复位 | valid、ready、结果、资格、epoch和载荷为规定复位值 |
| PR-02 | NORMAL 9-bit | 统一事务透传，15-bit valid和结果为0 |
| PR-03 | 标称15-bit | 标称Stage2系数时逐笔等于固定overlap黄金公式 |
| PR-04 | Stage2增益变化 | 只改变Stage2项，不改变Stage1和元数据 |
| PR-05 | 加性offset正负变化 | 正offset提高结果、负offset降低结果，signed Q16符号扩展正确 |
| PR-06 | 正负半LSB边界 | 对称舍入且tie远离零 |
| PR-07 | 15-bit上下饱和 | 分别得到-16384/+16383和唯一programmable饱和标志 |
| PR-08 | 全部1024个S2码 | D2_EXT和可编程结果逐码正确 |
| PR-09 | 输出反压 | valid、数值、资格、epoch和元数据完全保持 |
| PR-10 | 同拍消费替换 | 无空拍、无覆盖、事务顺序正确 |
| PR-11 | 系数资格组合 | Stage1/Stage2资格和最终校准标志正确绑定 |
| PR-12 | epoch回绕 | 版本按模256传递，不由epoch数值推导资格 |
| PR-13 | 有效期间改变配置输入 | 已锁存事务不受新配置总线变化影响 |
| PR-14 | 9/15/9/15连续切换 | 每笔精度资格与载荷不错拍 |

## 10. 冻结结论

本合同冻结以下V1行为：Stage1使用signed 12-bit校准结果，Stage2使用单一signed 20-bit Q16统一增益，offset使用直接加入残差拟合结果的signed 32-bit Q16加性截距，内部累加器使用signed 38-bit Q17，执行正负对称舍入和signed 15-bit饱和，采用单元素保持型ready/valid接口和一个寄存周期延迟。Stage2逐物理位权重属于后续合同版本，不得在V1 RTL中隐式加入。
