# F-002/F-008 epoch消费方只读核查（2026-10-06）

起因：ABCD会话转达。用户已裁定F-002/F-008按“合同收窄”处理，但前提是先确认没有任何消费方比较或使用缺少的5个epoch字段，并同意把这项核查交给B会话。

本次只读：基于`origin/main` = `9049adc`读码与grep，没有改任何文件，也没有仿真（静态核查已足以回答“有没有使用方”）。

## 0. 结论

**确认没有消费方。** 全仓RTL与TB中，没有任何一方比较或使用以下两组身份里的5个epoch字段（`config_epoch`、`coef_epoch`、`dc_recovery_epoch`、`amb_code_epoch`、`dc_code_epoch`，即矩阵§1.1 `TXN_ID`展开中的后5项），也没有任何一方依赖这些字段：
1. overlap之后的事务身份：AMI送给overlap校正器与NORMAL fork的私有`i_datapath_discard_<TXN_ID>`组（F-002，C13第4.1节）；
2. AMI/Top公开的正式结果丢弃身份：`o_measurement_result_discard_<TXN_ID>`（F-008，C01/C10）。

两组在RTL中都只有`frame_id`、`sample_index`、`color_ir`、`frame_type`、`precision`、`run_generation`六项，各消费方连这六项也主要只作诊断。按ABCD会话的约定，合并批次可以把C13/C01/C10/矩阵收窄为RTL实际字段组。措辞建议见第3节，其中“唯一确定”需要加回绕窗口限定。

## 1. F-002：`i_datapath_discard_<TXN_ID>`（AMI → overlap / NORMAL fork）

**生产方**：AMI（`ppg_adc_measurement_idac_integration.v`）。全仓只有两个实例接收这组端口，各9根线：`event`、`reason`、`identity_valid`、`frame_id`、`sample_index`、`color_ir`、`frame_type`、`precision`、`run_generation`，没有任何epoch端口。

| 消费方 | 端口声明 | 实际使用 | 结论 |
|---|---|---|---|
| `ppg_adc_pipeline_overlap_corrector.v` | `:69-77`（注释为“仅诊断用途”） | 唯一使用点`:217`：`flag_discard_apply = i_datapath_discard_event && (run_generation_o == i_run_generation)`。只用event和代际比较，身份字段（含`run_generation`本身）都未读 | 不使用epoch |
| `ppg_normal_transaction_fork.v` | 同组 | 唯一使用点`:201`：`flag_discard_apply = i_datapath_discard_event && (run_generation_o == i_run_generation)` | 不使用epoch |
| 其余ADC链模块（router、S1校准、重构、DC恢复、async capture） | 没有这组端口 | — | 不涉及 |
| TB | 只有`tb_ppg_adc_pipeline_overlap_corrector.v:102-107`、`:374-377`声明并驱动这6个字段（ABCD F-026补接），不做比较 | — | 不使用epoch |

全仓grep `(measurement_result_discard|datapath_discard|mr_discard)_[a-z_]*epoch`（`.v`/`.vh`）：0处命中。

**旁注（不影响本结论）**：
- AMI把`i_datapath_discard_run_generation`接到`i_run_generation`（`:1998`、`:2085`），与实时广播值相同。
- 两个消费方实际比较的是各自的`i_run_generation`输入，不是这组里的`run_generation`字段。overlap的`i_run_generation`接的是router透传值`dec_router_run_generation`（`:2106`），而AMI在`:2085`的注释写的是“overlap只比较该字段与自身锁存代际是否一致”，与实现不符。
- C13第4.1节写的是“For a matching retained transaction”，实现的“匹配”是代际匹配。收窄时宜明文写成“按代际匹配（generation-scoped），身份字段仅诊断”。这一点交ABCD会话判断是否需要RTL注释订正。

## 2. F-008：`o_measurement_result_discard_<TXN_ID>`（AMI → Top → 芯片顶层）

**生产方**：AMI `:190-199`。公开字段为`event`、`reason`、`identity_valid`、`sample_valid`、`frame_id`、`sample_index`、`color_ir`、`frame_type`、`precision`、`run_generation`，没有epoch。对照：同一模块的检测丢弃组`o_detection_discard_<TXN_ID>`带全部5个epoch（`:987-991`）。

| 消费方 | 位置 | 实际使用 | 结论 |
|---|---|---|---|
| `ppg_control_top.v` | 原样转出到Top端口 | 纯连线 | 不使用epoch |
| `ppg_chip_digital_top.v` | `:251-260`、`:440-449`、`:637-646` | 原样连到SPI寄存器文件 | 不使用epoch |
| `ppg_spi_register_file.v` | `:201`、`:570-572` | 事件到来时锁存进49位`reg_mr_latch`：{precision, run_generation, sample_index, frame_id, frame_type, color_ir, sample_valid, identity_valid, reason, toggle}。对照：检测丢弃锁存`reg_dd_latch`（`:202`、`:583`）是81位，含5个epoch | 不使用epoch |
| 芯片顶层合同第11.2节读地图 | `0x0114`~`0x011A` | 正式结果discard只映射控制字节、frame_id、sample_index、run_generation、precision，没有epoch字节 | 芯片层合同已与RTL一致 |
| `tb_ppg_adc_measurement_idac_integration.v` | `:1568-1571`（AMI-DISC-1） | 比较reason、identity_valid、frame_id、sample_index | 不使用epoch |
| `tb_ppg_control_top_injection.v` | `:651-652` | 记录reason、sample_index | 不使用epoch |
| `tb_ppg_control_top_lifecycle_fault_adc_anomaly.v` | `:904-907` | 锁存reason、color_ir、frame_type、sample_index | 不使用epoch |
| `tb_ppg_control_top_owner_identity_backpressure.v` | `:914` | 锁存reason | 不使用epoch |
| `tb_ppg_chip_digital_top.v` | `:853`、`:883`、`:898`（TC6） | 读`0x0114`控制字节的翻转位 | 不使用epoch |

其余系统级TB只把这组端口接线（`wire`和例化），不读取。

## 3. 合并批次的收窄措辞建议

- **C13第4.1节、C01/C10公开端口表、矩阵§1.1**：
  - `i_datapath_discard_*`与`o_measurement_result_discard_*`改为RTL实际字段组：`frame_id`、`sample_index`、`color_ir`、`frame_type`、`precision`、`run_generation`（正式结果组另有`sample_valid`）；
  - 矩阵§1.1另立一个缩小的身份组名（例如`TXN_KEY`），避免与完整`TXN_ID`混用；
  - 检测丢弃组与owner/完成组仍用完整`TXN_ID`，它们在RTL中确实带epoch。
- **建议的说明文字**：“epoch是版本元数据，不参与事务身份；事务身份由帧号、样本序号、颜色和RUN代际确定”。需要加上回绕限定：
  - 帧号与样本序号都是16位计数；双光时样本序号约每32768帧（约82 s）回绕一次，帧号约每65536帧（约164 s）回绕一次；
  - 两者组合在约164 s的回绕窗口内唯一；
  - epoch只在配置或码提交时变化，不是序列号，加进来也不能延长唯一窗口。
  
  所以宜写“在16位计数回绕窗口内唯一”，不宜写无条件的“唯一确定”。
- **F-002的匹配语义**：明文写为“丢弃按RUN代际匹配，身份字段仅作诊断，不参与匹配”，与`overlap:217`、`fork:201`一致。

## 4. 方法

1. 从矩阵§1.1取`TXN_ID`的11项展开，确定缺少的5项epoch。
2. 列出全仓声明`input … i_datapath_discard_*`的非TB模块（2个），以及AMI对这组端口的全部例化连接。
3. 读这两个消费方中所有非`input`声明的引用（各只有1处使用）。
4. 全仓grep `measurement_result_discard_*`在非AMI RTL中的全部引用，并沿连线追到芯片顶层与SPI寄存器文件的锁存位拼接。
5. 全仓TB中grep这两组的每个字段：排除`wire`/`reg`声明和端口例化行后，逐条看是比较、锁存还是只接线。
6. 全仓grep任何以这两组为前缀、带`epoch`的标识符：0命中。
