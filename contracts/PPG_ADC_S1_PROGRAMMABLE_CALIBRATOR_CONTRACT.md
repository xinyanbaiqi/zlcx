# PPG ADC Stage1逐物理位可编程校准器冻结合同

> Current normative version: V1, 2026-08-20. Status: `ACTIVE_NORMATIVE`; this module contract is active while system closure remains `NOT_CLOSED` and implementation evidence remains `EVIDENCE_PENDING`.
> Historical V1 freeze date: 2026-08-06.
> 目标RTL：`ppg_adc_s1_programmable_calibrator.v`  
> 上游：`ppg_adc_s1_redundancy_corrector`  
> 下游：`ppg_adc_result_router`  
> 配置源：`ppg_system_config_manager`和`ppg_system_active_config_unpack`

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C02 | `ppg_system_config_manager/ppg_system_config_manager_semantic_contract.md` | V4.9 | Committed ACTIVE, config/epoch ownership and RUN lifecycle. |
| C05 | `ppg_system_active_config_unpack/ppg_system_active_config_unpack_semantic_contract.md` | V5 | Sole decoded Stage1 calibration-field interpretation. |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.1 | AMI parent, generation/discard and data-chain integration ownership. |
| C12 | `ppg_system_integration/PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md` | V1.3 | Formal retained-output router boundary. |

## 1. 模块职责和边界

本模块负责：

- 在唯一输入ready/valid传输沿接收完整的`S1_RAW[9:0]`事务；
- 使用十个ACTIVE signed 26-bit Q16绝对权重和一个signed 32-bit Q16 offset完成固定系数乘加；
- 按冻结规则执行Q16到整数的正负对称舍入；
- 把舍入结果显式饱和到signed 12-bit范围；
- 将校准值、饱和状态、配置版本、校准资格和全部原事务元数据原子锁存；
- 使用单元素保持型ready/valid输出缓存，支持反压和同拍消费/替换。

本模块不负责：

- ADC异步DONE同步或RAW稳定捕获；
- 重新实现固定冗余解码或从`D1_EXT`再次计算物理位权重；
- 片内LMS/NLMS、误差计算、步长、除法、系数迭代或收敛状态机；
- SPI shadow、COMMIT合法性检查或ACTIVE配置所有权；
- 15-bit S1/S2重构；
- IDAC搜索、跟踪、码值提交或模拟建立控制；
- DC IDAC等效量恢复、PPG滤波、基线、相交或峰谷算法。

## 2. 插入位置

数据链固定为：

```text
ppg_adc_s1_redundancy_corrector
    | S1_RAW + fixed detect code + D1_EXT + S2_RAW + metadata
    | holding ready/valid
    v
ppg_adc_s1_programmable_calibrator
    | calibrated_s1_value + calibration/config tags + passthrough payload
    | holding ready/valid
    v
ppg_adc_result_router
```

`S1_RAW[9:0]`是校准乘加的唯一数据输入。固定`detect_code`和`D1_EXT`只作为黄金对照、量程诊断和测试导出字段透传，禁止作为可编程校准主输入。

## 3. 物理位与权重映射

S1物理位序沿用当前冻结接口：

```text
S1_RAW[9:0] = {vd8, vd7, vd6, vd5, vd4, vd3, vdred, vd2, vd1, vd0}
```

权重不得重新排序：

| RAW位 | 物理含义 | 权重输入 | 标称Q16值 |
| --- | --- | --- | ---: |
| `S1_RAW[0]` | `vd0`，标称1.0 | `stage1_weight_q16_0` | 65,536 |
| `S1_RAW[1]` | `vd1`，标称2.0 | `stage1_weight_q16_1` | 131,072 |
| `S1_RAW[2]` | `vd2`，标称4.0 | `stage1_weight_q16_2` | 262,144 |
| `S1_RAW[3]` | `vdred`，冗余8.0支路 | `stage1_weight_q16_3` | 524,288 |
| `S1_RAW[4]` | `vd3`，主8.0支路 | `stage1_weight_q16_4` | 524,288 |
| `S1_RAW[5]` | `vd4`，标称16.0 | `stage1_weight_q16_5` | 1,048,576 |
| `S1_RAW[6]` | `vd5`，标称32.0 | `stage1_weight_q16_6` | 2,097,152 |
| `S1_RAW[7]` | `vd6`，标称64.0 | `stage1_weight_q16_7` | 4,194,304 |
| `S1_RAW[8]` | `vd7`，标称128.0 | `stage1_weight_q16_8` | 8,388,608 |
| `S1_RAW[9]` | `vd8`，标称256.0 | `stage1_weight_q16_9` | 16,777,216 |

标称offset固定为：

```text
stage1_offset_q16 = -4 * 65536 = -262144
```

标称配置必须满足：

```text
S1_RAW = 10'b0000000000 -> calibrated_s1_value = -4
S1_RAW = 10'b1111111111 -> calibrated_s1_value = 515
```

标称配置下全部1024个物理码必须逐码等于当前固定`D1_EXT`黄金模型。

## 4. 定点计算合同

### 4.1 数学公式

```text
S1_CAL_Q16 = W1_OFFSET_Q16
           + sum(W1_Q16[i] * S1_RAW[i]), i=0..9
```

`S1_RAW[i]`只允许解释为无符号0或1。权重和offset均为二进制补码signed Q16，乘以物理位后仍保持Q16标度。

### 4.2 位宽

- 每个权重：signed 26-bit Q16；
- offset：signed 32-bit Q16；
- 每个物理位贡献：物理位为0时取33-bit signed零，为1时把对应26-bit权重符号扩展到33 bit；
- 累加器`S1_CAL_Q16`：至少signed 33 bit，即Verilog对象`[32:0]`；
- 舍入中间值必须先扩展到至少signed 34 bit再进行取绝对值和加半LSB，禁止在最小负数处发生取负溢出；
- 舍入结果在饱和比较前保持完整signed宽度，禁止先截成12 bit。

signed 33-bit累加器覆盖V1全部合法输入极值：十个signed 26-bit权重同时取同号极值并叠加signed 32-bit offset时不得自然回绕。

### 4.3 舍入

Q16到整数的舍入规则冻结为：最接近整数，正负对称，恰好半LSB时远离零。

数学定义：

```text
if S1_CAL_Q16 >= 0:
    rounded = (S1_CAL_Q16 + 32768) >>> 16
else:
    rounded = -(((-S1_CAL_Q16) + 32768) >>> 16)
```

必须满足：

```text
+0.499984... ->  0
+0.500000... -> +1
+1.500000... -> +2
-0.499984... ->  0
-0.500000... -> -1
-1.500000... -> -2
```

禁止直接使用`(x + 32768) >>> 16`处理负数，因为该写法会产生负数方向偏置。

### 4.4 饱和

`calibrated_s1_value`固定为signed 12-bit整数，不是无符号9-bit码。9-bit描述的是Stage1标称分辨率和数据路径角色；signed 12-bit输出用于保留片外校准后的负残差、正端余量和IDAC阈值统一标度。

饱和规则：

```text
rounded < -2048 -> calibrated_s1_value = -2048
rounded > +2047 -> calibrated_s1_value = +2047
otherwise       -> calibrated_s1_value = rounded[11:0]
```

同一事务必须输出：

- `saturation_low=1`：舍入结果小于-2048；
- `saturation_high=1`：舍入结果大于+2047；
- 两者互斥；
- 范围内结果两者均为0。

禁止依赖12-bit自然截断实现饱和。

## 5. ACTIVE配置合同

校准器直接接收ACTIVE解包层的十个权重和一个offset，并接收配置管理器提供的资格和版本：

- `i_active_valid`；
- `i_stage1_calibration_valid`；
- `i_config_epoch[7:0]`；
- `i_coef_epoch[7:0]`。

规则冻结为：

1. ACTIVE权重、offset、资格和epoch在整个RUN期间保持不变；
2. `i_active_valid=0`时，校准器不得接收新S1事务；
3. `i_stage1_calibration_valid=1`表示本轮使用已合法提交的片外拟合系数；
4. `i_stage1_calibration_valid=0`只允许配置管理器已经批准的CHARACTERIZATION标称系数路径；
5. 校准器不根据权重数值自行猜测系数是否已校准；
6. `calibration_applied`必须等于该笔输入传输沿锁存的`i_stage1_calibration_valid`；
7. `config_epoch`和`coef_epoch`必须在同一输入传输沿锁存并随结果保持；
8. `calibration_applied`不能由`coef_epoch!=0`推导，因为8-bit epoch允许模256回绕；
9. 配置改变只允许发生在无在途事务的CONFIG安全阶段，禁止用配置变化冲刷已接收事务。

NORMAL_PPG的START资格由配置管理器保证`stage1_calibration_valid=1`。校准器不重复实现生命周期策略，但也不能把`calibration_applied=0`静默改成1。

## 6. 冻结端口合同

### 6.1 事务代际与AMI私有排空

校准器接收并在输出缓存中逐位保持
`i_run_generation[C_RUN_GENERATION_WIDTH-1:0]`，并与frame、sample、颜色、类型、精度和全部epoch一起
传给router。该值只来自AMI的manager-generation层级扇出；陈旧generation的
输入不得产生有效输出。若校准器具有保持输出，AMI私有注册
`i_datapath_discard_event/reason/ID`是其唯一STOP/abort/system-fault释放路径：
无ready、无ack，匹配ID在采样沿清除本地hold，最早下一周期`o_local_empty=1`。
本事件不产生正式result discard、completion、fault或physical idle。若实现不
保留输出，`o_local_empty`恒按本合同定义的空状态报告。

> **2026-09-07合同文字修订（取代下方2026-09-05待定注记，选项3执行）**：本节
> 此前要求discard-broadcast端口组（`i_datapath_discard_event/reason/
> identity_valid/<TXN_ID>`）+`o_local_empty`输出必须无条件存在。经P1
> investigation（2026-09-05）五点独立证据核实：合法START（`flag_start_accept`）
> 本身要求`i_datapath_empty==1`（`ppg_system_config_manager.v:458-464`），该
> 信号经三跳具名端口直连AMI自己的`o_datapath_empty`（`ppg_control_top.v:
> 1323`→`ppg_control_top.v:729`→`ppg_active_v4_control_plane_integration.v:
> 402`→`ppg_system_config_manager.v:74`，无中间锁存或旁路），其公式
> （`ppg_adc_measurement_idac_integration.v:1125,1127,1128`）真实包含本模块
> 自己的held-output valid信号`flag_calibrated_valid`。也就是说`i_run_
> generation`推进之前，本模块（以及C14/C15）已被结构性保证处于排空状态——
> "代际已切换、本模块仍held旧代际数据"这条discard-broadcast原本要防护的场景，
> 在当前RTL下没有路径可以发生，五点完整证据链见memory
> `project-ppg-p1-discard-broadcast-investigation-20260905`。
>
> **本模块（及C14/C15）当前不要求实现discard-broadcast端口组+`o_local_empty`
> 输出。这是有条件的免除，不是无条件删除**：上述结论完全依赖
> `ppg_system_config_manager.v`的`flag_start_accept`公式包含`i_datapath_empty`、
> 以及`ppg_adc_measurement_idac_integration.v`的`o_datapath_empty`公式包含
> 本模块（及C14/C15）的held-output valid信号，这两处**当前写法**。以后任何人
> 修改这两处任一公式，都必须重新核实这条链条是否依然成立；一旦不成立，本模块
> （及C14/C15）出现真实未受保护路径，届时必须把discard-broadcast端口组+
> `o_local_empty`补齐为真实实现，不能只靠这份文档记录了事。是否现在就为了跟
> C18 PWI→检测器那套`i_run_generation`/`i_detection_discard_event`实现风格
> 保持字面一致而提前补上这组端口（本身没有功能收益，纯粹是风格对齐），是独立
> 于本次修订的架构决策，本记录不做这个决定。
>
> C14/C15的同一结论见各自对应位置的交叉引用。

目标RTL使用下列参数默认值：

```verilog
parameter integer C_FRAME_ID_WIDTH = 16
parameter integer C_SAMPLE_INDEX_WIDTH = 16
parameter integer C_IDAC_CODE_WIDTH = 8
parameter integer C_CODE_EPOCH_WIDTH = 4
parameter integer C_CONFIG_EPOCH_WIDTH = 8
parameter integer C_COEF_EPOCH_WIDTH = 8
parameter integer C_RUN_GENERATION_WIDTH = 8
```

### 6.1 全局和配置输入

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_clk` | 1 | 2 MHz数字处理时钟 |
| input | `i_rstn` | 1 | 低有效异步复位，释放由上层同步 |
| input | `i_active_valid` | 1 | 当前ACTIVE快照具备运行资格 |
| input | `i_stage1_calibration_valid` | 1 | 当前系数为合法片外拟合系数 |
| input | `i_config_epoch` | 8 | 当前完整ACTIVE配置版本 |
| input | `i_coef_epoch` | 8 | 当前Stage1系数组版本 |
| input | `i_run_generation` | `C_RUN_GENERATION_WIDTH` | AMI逐层传入的当前RUN代际；仅在事务握手沿与输入载荷原子锁存。 |
| input | `i_datapath_discard_event` / `reason` / `identity_valid` / `<TXN_ID>` | `1/2/1/each field` | AMI私有注册释放组；无ready/ack，事件、原因和完整ID在采样沿稳定。 |
| output | `o_local_empty` | 1 | 已注册本地排空状态；discard匹配清除后最早下一周期为1；唯一消费者AMI。 |
| input | `i_stage1_weight_q16_0..9` | 每个signed 26 | 按RAW索引对应的绝对权重 |
| input | `i_stage1_offset_q16` | signed 32 | Stage1整体Q16偏置 |

### 6.2 上游事务输入

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| input | `i_result_valid` | 1 | 上游保持型有效 |
| output | `o_result_ready` | 1 | 校准器允许接收当前完整事务 |
| input | `i_stage1_raw` | 10 | 唯一校准算术输入 |
| input | `i_detect_code` | 9 | 固定黄金检测码，仅透传 |
| input | `i_stage1_code_ext` | signed 11 | 固定D1_EXT，仅透传 |
| input | `i_stage2_raw` | 10 | 后续15-bit链物理码，仅透传 |
| input | `i_precision_mode` | 1 | 该笔事务的9/15-bit模式快照 |
| input | `i_frame_id` | 16 | R/IR共享帧号 |
| input | `i_sample_index` | 16 | 颜色内样本序号 |
| input | `i_color_ir` | 1 | 0红光，1红外 |
| input | `i_frame_type` | 2 | 00 AMB_CAL，01 DCS_CAL，10 NORMAL |
| input | `i_amb_code_snapshot` | 8 | 本次积分实际使用的AMB码 |
| input | `i_dc_code_snapshot` | 8 | 本次积分实际使用的颜色DC码 |
| input | `i_amb_code_epoch` | 4 | 本次AMB码版本 |
| input | `i_dc_code_epoch` | 4 | 本次颜色DC码版本 |

参数化字段必须使用对应`C_*_WIDTH`，表中数值为V1默认值。

### 6.3 下游事务输出

| 方向 | 端口 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| output | `o_calibrated_valid` | 1 | 输出完整载荷保持有效 |
| input | `i_calibrated_ready` | 1 | 下游接受当前载荷 |
| output | `o_calibrated_s1_value` | signed 12 | 对称舍入并饱和后的Stage1值 |
| output | `o_calibration_applied` | 1 | 该笔结果使用合法片外拟合系数 |
| output | `o_saturation_low` | 1 | 未饱和结果低于signed 12-bit范围 |
| output | `o_saturation_high` | 1 | 未饱和结果高于signed 12-bit范围 |
| output | `o_config_epoch` | 8 | 该笔事务实际使用的完整配置版本 |
| output | `o_coef_epoch` | 8 | 该笔事务实际使用的系数组版本 |
| output | `o_stage1_raw` | 10 | 原子透传物理S1码 |
| output | `o_detect_code` | 9 | 原子透传固定检测码 |
| output | `o_stage1_code_ext` | signed 11 | 原子透传D1_EXT |
| output | `o_stage2_raw` | 10 | 原子透传物理S2码 |
| output | `o_run_generation` | `C_RUN_GENERATION_WIDTH` | 与`o_calibrated_valid`同一保持型事务原子输出，逐位传给router。 |
| output | 其余同名元数据 | 与输入相同 | 精度、帧号、样本号、颜色、类型、IDAC码及epoch |

输出侧不得另建无ready的校准脉冲。所有输出字段只在`o_calibrated_valid=1`时具有事务语义。

## 7. ready/valid和时序合同

V1采用一个寄存输出缓冲，无额外内部流水级：

```text
buffer_available = !o_calibrated_valid || i_calibrated_ready
o_result_ready = i_rstn && i_active_valid && buffer_available
input_transfer = i_result_valid && o_result_ready
output_transfer = o_calibrated_valid && i_calibrated_ready
```

行为冻结为：

1. 只在`input_transfer`上升沿读取RAW、配置和元数据；
2. 输入传输沿完成乘加、舍入、饱和并锁存全部输出载荷；
3. 从该沿之后，`o_calibrated_valid`和结果载荷有效，形成一个寄存周期延迟；
4. `o_calibrated_valid=1 && i_calibrated_ready=0`期间，所有输出位逐拍稳定；
5. 旧输出被消费且同拍有新输入传输时，直接替换载荷并保持valid为1，不插入空拍；
6. 只有旧输出被消费且没有新输入传输时，下一拍valid清零；
7. `i_result_valid=0`时，RAW、配置或元数据总线变化不得改变模块事务状态；
8. 上游必须在`i_result_valid=1 && o_result_ready=0`期间保持全部输入事务载荷稳定；
9. ACTIVE配置不得在RUN或任何在途事务期间改变。

如果目标ASIC综合/STA证明单周期乘加不能满足2 MHz，必须通过新合同版本增加流水级，并同步修改ready/valid延迟和全部回归用例；V1 RTL不得自行改变延迟。

## 8. 复位合同

`i_rstn=0`时：

- `o_calibrated_valid=0`；
- `o_result_ready=0`；
- `o_calibrated_s1_value=0`；
- `o_calibration_applied=0`；
- 两个饱和标志为0；
- 所有输出epoch和透传载荷清零；
- 复位期间不得产生伪事务。

异步复位释放由系统顶层同步。复位在反压期间到来时必须立即撤销valid，旧事务在复位后不得复活。

## 9. 与配置管理器和解包器的连接

| 来源 | 校准器输入 |
| --- | --- |
| manager `o_active_valid` | `i_active_valid` |
| unpack `o_stage1_calibration_valid` | `i_stage1_calibration_valid` |
| manager `o_config_epoch[7:0]` | `i_config_epoch[7:0]` |
| manager `o_coef_epoch[7:0]` | `i_coef_epoch[7:0]` |
| unpack `o_stage1_weight_q16_0..9` | 同名校准器权重输入 |
| unpack `o_stage1_offset_q16` | `i_stage1_offset_q16` |

校准器不得再次解析512-bit ACTIVE快照，也不得在本地复制COMMIT、shadow或live配置状态机。

## 10. 下游集成要求

router必须把下列字段作为公共事务载荷透传到AMB_CAL、DCS_CAL和NORMAL分支：

- `calibrated_s1_value`；
- `calibration_applied`；
- `saturation_low`和`saturation_high`；
- `config_epoch`和`coef_epoch`；
- 固定`detect_code`、`D1_EXT`、`S1_RAW`和`S2_RAW`；
- 全部原始事务元数据。

后续IDAC控制器只使用signed 12-bit `calibrated_s1_value`和同标度signed 12-bit LOW/HIGH阈值作闭环比较。固定9-bit `detect_code`不得重新成为NORMAL IDAC主输入。15-bit结果不驱动IDAC。

## 11. 验收矩阵

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| CAL-01 | 复位 | valid、结果、资格、饱和标志、epoch和透传载荷全部为规定复位值 |
| CAL-02 | 标称权重遍历全部1024个RAW码 | 每码结果逐笔等于当前固定`D1_EXT`，范围为-4至515 |
| CAL-03 | 十个one-hot RAW码 | 每个物理位只选择同索引权重，冗余8.0和主8.0不混位 |
| CAL-04 | 仅offset和signed负权重 | 符号扩展、负累加和正负混合求和正确 |
| CAL-05 | 正负半LSB边界 | 对称舍入且tie远离零，不产生负数偏置 |
| CAL-06 | signed 12-bit范围内边界 | -2048和+2047不误报饱和 |
| CAL-07 | 上下越界 | 分别饱和到-2048和+2047，对应标志唯一置位 |
| CAL-08 | `active_valid=0` | ready为0，不接受新事务，不伪造输出 |
| CAL-09 | CHARACTERIZATION标称系数 | 输出有效且`calibration_applied=0` |
| CAL-10 | 合法校准系数 | 输出有效且`calibration_applied=1`，coef/config epoch与该笔计算绑定 |
| CAL-11 | 输出反压 | valid和每一位payload逐拍保持不变 |
| CAL-12 | 同拍消费和新输入 | 无空拍，全部载荷原子替换 |
| CAL-13 | valid为0时改变输入 | 内部状态和输出事务不改变 |
| CAL-14 | 接收后改变ACTIVE输入并保持反压 | 已缓存结果、资格和epoch完全不变 |
| CAL-15 | 复位打断待消费输出 | valid立即清零，旧事务不复活 |
| CAL-16 | 全部元数据组合变化 | frame、sample、color、type、精度、IDAC码和各epoch均不错拍 |
| CAL-17 | epoch从255回绕到0 | `calibration_applied`不由epoch数值推导，事务标签仍正确 |

testbench必须使用独立整数/定点黄金模型自动比较，不允许只观察波形或只打印数值。PASS必须在全部用例执行且错误计数为0后产生。

## 12. RTL交付门禁

实现时必须满足：

- 可综合Verilog-2001 `.v`；
- Erie strict命名、双语文件头、中文实体注释和区域结构；
- 所有signed扩展、累加器、舍入常量、比较常量和截断点显式位宽；
- 时序逻辑使用非阻塞赋值，组合逻辑完整赋值，无latch和多驱动；
- 不使用RTL `function`/`task`隐藏定点算术；
- 不使用原始门控时钟、延时、`initial`或仿真专用系统任务；
- formatter-AST严格门禁、独立lint、Vivado xsim自检和OOC综合全部通过；
- 综合报告确认无锁存器、黑盒、组合环和不可解释的位宽截断。

## 13. V1冻结结论

V1 Stage1校准主模型、位宽、舍入、饱和、ready/valid、配置资格和版本绑定已经冻结。后续RTL必须按本合同实现；任何改变物理位映射、输出标度、signed 12-bit范围、一个寄存周期延迟或配置版本语义的方案，都必须先版本化修订本合同，不能在实现中静默改变。
