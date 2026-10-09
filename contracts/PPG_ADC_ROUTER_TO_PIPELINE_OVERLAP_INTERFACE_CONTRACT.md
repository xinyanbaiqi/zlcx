# PPG ADC Router到Pipeline Overlap Corrector接口冻结合同

> V1.3修订日期：2026-10-09。B合同合并批次（`verification_reports/B_MERGE_BATCH_ITEMS.md` BMI-060、062~064，按基线`7a8eabf` router RTL、overlap RTL与AMI RTL改写，符号锚点格式为“文件 + 符号（§节）”）：① §4.1私有datapath discard身份组收窄为矩阵§1.1 `TXN_KEY`（F-002），并写明按代际匹配、身份字段仅诊断；② §4.1按RTL订正router边界（F-004：router是纯组合透传，没有`o_local_empty`和datapath discard端口；这组端口只在overlap上）以及`o_local_empty`的消费关系；③ §7登记OVL-01~OVL-17验收表（单元TB已有同名检查，此前合同无编号）。不改变握手、位宽、缓存深度或延迟。
> Current normative version: ~~V1.2, 2026-08-20~~ V1.3, 2026-10-09（V1.2记录日期2026-08-20）. Status: `ACTIVE_NORMATIVE`; ID/generation pass-through and local-drain ownership remain normative. System closure is `NOT_CLOSED`; implementation evidence is `EVIDENCE_PENDING`.

> Historical V1 interface, width, handshake and payload-hold freeze date: 2026-08-06.
> 上游RTL：`ppg_adc_result_router.v`  
> 下游RTL：`ppg_adc_pipeline_overlap_corrector.v`

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.4 | AMI parent, generation/discard and NORMAL routing ownership. |
| C11 | `ppg_system_integration/PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md` | V1 | Calibrated source payload and metadata semantics. |
| C12 | `ppg_system_integration/PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md` | V1.3 | Router NORMAL branch handshake and payload mapping. |
| C14 | `ppg_system_integration/PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md` | V1.2 | Sole downstream reconstructor boundary. |

## 1. 接口目的

本模块声明`C_RUN_GENERATION_WIDTH=8`参数；AMI实例化时逐层传入Top参数，
router、overlap和reconstructor在elaboration拒绝任何generation宽度不一致。

本接口只承接router的NORMAL分支。Stage1可编程校准结果、原始物理码、固定黄金结果、S2物理码和事务元数据必须作为同一笔不可拆分事务进入overlap corrector。

冻结数据链为：

```text
ppg_adc_s1_programmable_calibrator
    -> ppg_adc_result_router NORMAL分支
    -> ppg_adc_pipeline_overlap_corrector
    -> ppg_adc_programmable_reconstructor（后续模块）
```

overlap corrector不重新执行Stage1校准，不重新生成校准资格、饱和标志或版本标签。

## 2. 握手映射

| Router端口 | Overlap端口 | 语义 |
| --- | --- | --- |
| `o_normal_valid` | `i_normal_valid` | NORMAL完整事务保持有效 |
| `i_normal_ready` | `o_normal_ready` | 单元素输出缓存允许接收新事务 |

唯一输入传输事件为：

```text
normal_transfer = i_normal_valid && o_normal_ready
```

只有发生`normal_transfer`时，overlap corrector才能锁存输入载荷。`i_normal_valid=1 && o_normal_ready=0`期间，上游必须保持全部输入字段稳定。

## 3. Stage1校准字段

| Router输出 | Overlap输入 | Overlap输出 | 位宽 | 语义 |
| --- | --- | --- | ---: | --- |
| `o_calibrated_s1_value` | `i_calibrated_s1_value` | `o_calibrated_s1_value` | signed 12 | 正式Stage1校准结果 |
| `o_calibration_applied` | `i_calibration_applied` | `o_calibration_applied` | 1 | 本笔事务使用合法校准系数 |
| `o_saturation_low` | `i_saturation_low` | `o_saturation_low` | 1 | 校准器负向饱和诊断 |
| `o_saturation_high` | `i_saturation_high` | `o_saturation_high` | 1 | 校准器正向饱和诊断 |
| `o_config_epoch` | `i_config_epoch` | `o_config_epoch` | 8 | 本笔事务绑定的ACTIVE配置版本 |
| `o_coef_epoch` | `i_coef_epoch` | `o_coef_epoch` | 8 | 本笔事务绑定的Stage1系数组版本 |

冻结规则：

1. `calibrated_s1_value`保持signed 12-bit，不允许截断为9 bit或改为无符号数。
2. `calibration_applied`不得由epoch是否为零推导。
3. 两个饱和标志不得由overlap corrector重新计算。
4. `config_epoch`和`coef_epoch`只透传并锁存，不在本模块内递增。
5. 六个字段与全部原事务字段在同一输入握手沿原子更新。

## 4. 保留载荷

以下字段继续保持既有语义：

- `detect_code[8:0]`：固定黄金结果，只用于对照、范围观察和诊断；
- `stage1_raw[9:0]`：完整Stage1物理判决位；
- `stage1_code_ext[10:0]`：固定未钳位D1_EXT；
- `stage2_raw[9:0]`：15-bit事务的Stage2物理判决位；
- `precision_mode`、`frame_id`、`sample_index`、`color_ir`、`frame_type`；
- `amb_code_snapshot`、`dc_code_snapshot`、`amb_code_epoch`、`dc_code_epoch`。

当前固定标称输出`nominal_15_code`、`nominal_15_valid`和`nominal_saturated`继续保留作为黄金对照。它们不等同于后续可编程15-bit重构结果。

### 4.1 Generation and lifecycle pass-through

V1.3 correction (F-002, F-004; RTL `ppg_adc_result_router.v`, `ppg_adc_pipeline_overlap_corrector.v`, `ppg_adc_measurement_idac_integration.v`). The paragraphs below are kept as originally written; where they differ from RTL, the following governs:
- **Router** has `i_run_generation`/`o_run_generation` only. It is purely combinational pass-through (no always block, no retained state), and has neither `o_local_empty` nor any `i_datapath_discard_*` port. "A stale generation is dropped" and "Router `o_local_empty`" below do not apply to the router.
- **Overlap** declares `i_run_generation`, the private `i_datapath_discard_event`, `i_datapath_discard_reason[1:0]`, `i_datapath_discard_identity_valid`, the `i_datapath_discard_<TXN_KEY>` group (six fields `frame_id`, `sample_index`, `color_ir`, `frame_type`, `precision`, `run_generation`; no epoch; closure matrix §1.1), `o_run_generation` and `o_local_empty`.
- **Matching is generation-scoped**: overlap applies the event when `i_datapath_discard_event && (run_generation_o == i_run_generation)` (`flag_discard_apply`); the identity fields are diagnostic only and never take part in matching. "For a matching retained transaction" below means this generation match.
- AMI connects overlap `o_local_empty` for observation only; AMI's `o_datapath_empty` uses overlap `o_result_valid` (through `o_measurement_output_idle`) instead, which for this single-element buffer carries the same fact.

The formal Router/overlap boundary additionally declares the following ports:
`i_run_generation[C_RUN_GENERATION_WIDTH-1:0]`,
`i_datapath_discard_event`, `i_datapath_discard_reason[1:0]`,
`i_datapath_discard_identity_valid`, the complete
`i_datapath_discard_<TXN_ID>` group, `o_run_generation[C_RUN_GENERATION_WIDTH-1:0]`,
and `o_local_empty`. The input generation and `TXN_ID` are accepted only with
the normal transaction handshake; the output generation is held with the normal
payload until downstream transfer or matching discard. AMI is the sole producer
of both added inputs and the sole consumer of `o_local_empty`.

The router receives `i_run_generation[C_RUN_GENERATION_WIDTH-1:0]` with the
accepted AMI transaction and forwards it unchanged with the complete identity,
qualification and numeric payload. It neither creates a fault record, injection
point, discard event nor owner release. A stale generation is dropped without a
normal output. Router `o_local_empty` is a registered local fact consumed only
by AMI's `o_datapath_empty` aggregation; it is not physical idle.

AMI also supplies the private registered
`i_datapath_discard_event/reason/ID` group. It has no ready or acknowledgement;
the event, reason and complete ID are stable at the receiving edge. For a
matching retained transaction, Router/overlap clears its local output hold on
that edge exactly once and may assert `o_local_empty` only in the next cycle.
The event is never converted into a public measurement discard, completion,
fault, owner release or physical-idle indication. STOP and abort have no second
direct destructive-clear port at this boundary.

## 5. 缓存、反压与复位

overlap corrector保持一个单元素弹性输出缓存：

```text
o_normal_ready = i_rstn && (!o_result_valid || i_result_ready)
```

规则如下：

1. 输出有效且下游反压时，全部数值、状态和元数据逐位保持稳定。
2. 旧事务被消费且同拍接收新事务时，新事务原子替换旧事务，`o_result_valid`保持为1。
3. 旧事务被消费且没有新输入时，`o_result_valid`在下一拍清零。
4. `i_rstn=0`时立即关闭ready和valid，并清零全部保持寄存器。
5. 本次接口扩展不增加流水级、FSM或额外事务延迟。

## 6. 模块职责边界

本模块继续负责：

- NORMAL事务的单元素保持与反压；
- 现有S2冗余解码；
- 现有固定Q16标称15-bit重构、舍入和饱和；
- 将校准字段与原事务载荷原子送往后续链路。

本模块不负责：

- Stage1逐物理位校准乘加；
- 15-bit可编程系数重构；
- IDAC搜索、跟踪或码值提交；
- DC等效量恢复；
- PPG滤波、基线、相交、峰谷或输出格式化。

## 7. 验收用例

修改后的RTL和自检TB至少覆盖：

1. signed 12-bit端点`-2048`和`2047`逐位保持；
2. `calibration_applied`与两个饱和标志的独立组合；
3. `config_epoch`与`coef_epoch`连续事务切换无错拍；
4. 下游反压期间全部新增字段稳定；
5. 同拍消费和替换时新增字段原子更新；
6. 9-bit与15-bit NORMAL事务均携带Stage1校准载荷；
7. 原1024个S2物理码扫描和固定标称重构结果不发生回归；
8. 异步复位清除valid和全部新增保持字段。

### 7.1 验收编号表（V1.3登记）

overlap单元TB（`tb_ppg_adc_pipeline_overlap_corrector.v`）的检查标签为OVL-01~OVL-17，此前本合同没有编号表。下表逐条登记，并写明对应的本合同规则；17项都能对应到本合同已有规则或RTL实际行为，没有“仅TB检查”项。TB只在FAIL分支打印编号，PASS时只有总横幅。

| 编号 | 场景 | 验收要求 | 对应本合同规则 |
| --- | --- | --- | --- |
| OVL-01 | 复位确定状态 | 复位期间及释放后valid、全部保持字段为确定值，复位释放后ready恢复 | §5第4条；§7第8条 |
| OVL-02 | 无valid不建事务 | `i_normal_valid=0`时任意改变输入总线不产生或改写输出事务 | §2（只有`normal_transfer`才锁存） |
| OVL-03 | RED 9-bit透传 | 检测码与全部元数据逐位透传，fine/标称字段保持0 | §4；§7第6条 |
| OVL-04 | IR 9-bit同拍替换 | IR事务同拍替换RED事务，保持各自独立的DC快照 | §5第2条；§4 |
| OVL-05 | RED 15-bit | 同时保留检测码并产生固定标称15-bit重构结果 | §4（标称输出）；§6 |
| OVL-06 | IR 15-bit | 复用同一算术硬件，全部IR元数据不串色 | §4；§6 |
| OVL-07 | 1024码扫描 | 遍历全部1024个S2物理码，用变化的D1_EXT交叉核对标称结果 | §7第7条 |
| OVL-08 | D1_EXT边界 | 覆盖冗余边界、中点两侧与正向量程端点 | §6（S2冗余解码与标称重构） |
| OVL-09 | 对称舍入 | 半LSB门限上下的正负样本舍入完全对称 | §6（舍入） |
| OVL-10 | 饱和不回绕 | 接口可表达的异常D1_EXT在上下端饱和，不发生二进制回绕 | §6（饱和） |
| OVL-11 | 反压保持 | 下游持续反压时全部数值、资格和元数据逐拍保持，ready为0 | §5第1条；§7第4条 |
| OVL-12 | 恰好消费一次 | 解除反压后当前事务只被消费一次并释放缓存 | §5第3条 |
| OVL-13 | 同拍消费与接收 | 旧输出消费与新输入接收同拍时valid连续、载荷完整替换 | §5第2条；§7第5条 |
| OVL-14 | 精度快照 | 连续9/15/9/15事务的fine资格只由各自事务的精度快照决定 | §4（`precision_mode`）；§7第6条 |
| OVL-15 | 旧事务不复活 | 输出消费后valid为0，之后输入总线变化不能复活或改写旧事务 | §2；§5第3条 |
| OVL-16 | 异步复位中断 | 有效输出等待期间异步复位立即清除valid和全部结果字段，复位后可恢复 | §5第4条；§7第8条 |
| OVL-17 | 校准载荷端点 | signed 12-bit校准端点、独立状态位与版本标签逐位保持 | §3第1~5条；§7第1~3条 |

任何改变字段位宽、握手条件、缓存深度、固定标称结果语义或新增延迟的方案，必须先修订本合同。
