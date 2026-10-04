# PPG ADC Stage1校准器到结果路由器接口冻结合同

> Current normative version: V1.3, 2026-08-20. Status: `ACTIVE_NORMATIVE`; manager-owned generation, AMI-private generation-scoped discard and the single NORMAL-to-tracking source semantics remain normative. System closure is `NOT_CLOSED`; implementation evidence is `EVIDENCE_PENDING`.

> Historical V1 interface, handshake and payload freeze date: 2026-08-06.
> 上游RTL：`ppg_adc_s1_programmable_calibrator.v`  
> 下游RTL：`ppg_adc_result_router.v`  
> 适用范围：AMB_CAL、DCS_CAL和NORMAL三类Stage1校准事务

## 0. Current Normative Dependencies

| Dependent Cxx | Active relative path | Required version | Dependency scope |
| --- | --- | --- | --- |
| C10 | `ppg_system_integration/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | V2.4 | AMI parent, generation/discard and router integration ownership. |
| C11 | `ppg_system_integration/PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md` | V1 | Sole upstream calibrated retained transaction. |
| C13 | `ppg_system_integration/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md` | V1.2 | Sole NORMAL downstream overlap boundary. |

## 1. 连接目的

本连接合同的参数接口固定为`C_FRAME_ID_WIDTH=16`、`C_SAMPLE_INDEX_WIDTH=16`、
`C_CONFIG_EPOCH_WIDTH=8`、`C_COEF_EPOCH_WIDTH=8`、`C_CODE_EPOCH_WIDTH=4`和
`C_RUN_GENERATION_WIDTH=8`。校准器、router及AMI实例化时必须逐层传入同一组参数，
Top/AMI在elaboration拒绝任一宽度不一致；本合同不允许用固定`[7:0]`替代参数端口。

本接口把Stage1可编程校准器产生的一笔完整保持型事务送入结果路由器。路由器依据同一事务中的
`frame_type`选择唯一目的分支，并把所选分支的ready直接反馈给校准器。

冻结数据链为：

```text
ppg_adc_s1_redundancy_corrector
    | S1_RAW + detect_code + D1_EXT + S2_RAW + metadata
    v
ppg_adc_s1_programmable_calibrator
    | calibrated_s1_value + calibration/status/epoch + passthrough payload
    v
ppg_adc_result_router
    +-- AMB_CAL
    +-- DCS_CAL
    `-- NORMAL
```

router不执行校准算术，不重新解释固定`detect_code`，不修改任何版本标签，也不增加事务存储。

## 2. 握手映射

| 校准器端口 | router端口 | 语义 |
| --- | --- | --- |
| `o_calibrated_valid` | `i_result_valid` | 完整校准事务保持有效 |
| `i_calibrated_ready` | `o_result_ready` | 当前唯一目的分支允许接收事务 |

唯一传输事件为：

```text
calibrator_to_router_transfer = o_calibrated_valid && i_calibrated_ready
                              = i_result_valid && o_result_ready
```

规则冻结为：

1. router为纯组合模块，不增加寄存级和周期延迟；
2. 校准器在`o_calibrated_valid=1 && i_calibrated_ready=0`期间保持全部输出载荷稳定；
3. router只把当前选中分支的ready反馈给校准器，未选分支不得形成反压；
4. 一笔合法事务只允许激活一个分支valid，不允许复制或重复消费；
5. router没有独立empty寄存器，STOPPING排空由校准器valid和各分支消费者状态共同汇总。

## 3. 公共载荷映射

### 3.1 代际与排空旁带

校准器到router的完整载荷新增并逐位保持`run_generation[C_RUN_GENERATION_WIDTH-1:0]`。
校准器与router的参数均声明并接收同一`C_RUN_GENERATION_WIDTH`，由Top/AMI
在elaboration时检查相等。它由AMI从
manager唯一generation扇出，不能由校准器或router重建。若载荷停留在任一保持
边界，AMI私有注册`datapath_discard_event/reason/identity_valid/TXN_ID`在当前generation的采样沿恰好一次
清除该代际全部保持状态，无ready或ack；`identity_valid=0`的scope-only flush同样有效；其后最早下一周期对应`o_local_empty=1`。陈旧
generation不产生router输入valid、结果、完成、fault、owner release或物理idle。

### 3.1 校准字段

| 校准器输出 | router输入 | router输出 | 位宽 | 语义 |
| --- | --- | --- | ---: | --- |
| `o_calibrated_s1_value` | `i_calibrated_s1_value` | `o_calibrated_s1_value` | signed 12 | 本笔Stage1校准残差 |
| `o_calibration_applied` | `i_calibration_applied` | `o_calibration_applied` | 1 | 本笔使用合法片外拟合系数 |
| `o_saturation_low` | `i_saturation_low` | `o_saturation_low` | 1 | 未饱和结果低于-2048 |
| `o_saturation_high` | `i_saturation_high` | `o_saturation_high` | 1 | 未饱和结果高于+2047 |
| `o_config_epoch` | `i_config_epoch` | `o_config_epoch` | 8 | 本笔完整ACTIVE配置版本 |
| `o_coef_epoch` | `i_coef_epoch` | `o_coef_epoch` | 8 | 本笔Stage1系数组版本 |

router必须逐位透传上述字段：

- 不得由`coef_epoch`数值推导`calibration_applied`；
- 不得根据校准值重新生成饱和标志；
- 不得把signed 12-bit校准值截断为9 bit或转换为无符号数；
- 不得用固定`detect_code`替换`calibrated_s1_value`。

### 3.2 固定观察字段和物理码

| 校准器输出 | router输入/输出 | 位宽 | 语义 |
| --- | --- | ---: | --- |
| `o_stage1_raw` | `i/o_stage1_raw` | 10 | Stage1完整物理判决位 |
| `o_detect_code` | `i/o_detect_code` | 9 | 固定黄金检测码，仅作对照和诊断 |
| `o_stage1_code_ext` | `i/o_stage1_code_ext` | signed 11 | 未钳位D1_EXT |
| `o_stage2_raw` | `i/o_stage2_raw` | 10 | 15-bit后续链所需S2物理码 |

`S1_RAW`已在校准器内参与计算，但仍必须随结果继续透传，供测试导出、片外拟合核对和后续诊断使用。

### 3.3 事务元数据

下列字段保持同名、同宽、同一事务原子透传：

- `precision_mode`；
- `frame_id`；
- `sample_index`；
- `color_ir`；
- `frame_type`；
- `amb_code_snapshot`和`dc_code_snapshot`；
- `amb_code_epoch`和`dc_code_epoch`。

默认位宽冻结为：

```text
frame_id          = 16 bit
sample_index      = 16 bit
IDAC code         = 8 bit
IDAC code_epoch   = 4 bit
config_epoch      = 8 bit
coef_epoch        = 8 bit
```

## 4. 路由行为

| `frame_type` | 目的分支 | 有效输出 | ready来源 |
| --- | --- | --- | --- |
| `2'b00` | AMB_CAL | `o_amb_cal_valid` | `i_amb_cal_ready` |
| `2'b01` | DCS_CAL | `o_dc_cal_valid` | `i_dc_cal_ready` |
| `2'b10` | NORMAL | `o_normal_valid` | `i_normal_ready` |
| `2'b11` | 非法类别 | 仅`o_frame_type_error` | 固定允许直接消费 |

合法事务的三个分支valid必须one-hot。非法`2'b11`不得进入任何功能分支，并通过
`o_frame_type_error=1`报告后直接消费，避免错误事务永久阻塞校准器输出缓存。

NORMAL事务继续保持单目的路由。当前活跃系统不定义经过router的
`SEARCH_TRACK`输入、输出或独立frame type：tracking只由NORMAL事务在本路由器
完成唯一NORMAL握手后，按`PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`
在NORMAL fork内部取得其保留身份。router不得生成、接受或旁路一条
`SEARCH_TRACK`事务，也不得新增NORMAL到IDAC的无界双消费者扇出。

## 5. 复位和无效周期

`i_rstn=0`时：

- `o_result_ready=0`；
- 三个分支valid均为0；
- `o_frame_type_error=0`；
- 不产生任何传输事件。

公共载荷输出是输入载荷的纯组合镜像，不要求在复位或`i_result_valid=0`时清零。只有对应分支valid为1时，
公共载荷才具有事务语义，下游禁止在valid为0时解释残留总线。

`i_rstn=1 && i_result_valid=0`时，`o_result_ready=1`，允许上游提前观察空闲接收能力。

## 6. 模块边界

router负责：

- 互斥译码AMB_CAL、DCS_CAL和NORMAL；
- 选择唯一ready反馈；
- 逐位透传完整校准载荷和原事务元数据；
- 对保留帧类别产生协议错误电平。

router不负责：

- Stage1权重乘加、舍入或饱和；
- 检查NORMAL是否具备校准启动资格；
- IDAC搜索、跟踪或码值提交；
- 15-bit可编程重构；
- DC等效量恢复、滤波、基线、相交或峰谷处理；
- 配置COMMIT、ACTIVE所有权或epoch递增。

## 7. 验收矩阵

| 编号 | 场景 | 必须满足 |
| --- | --- | --- |
| RTR-01 | 复位 | ready、三个分支valid和错误输出均关闭 |
| RTR-02 | 无输入事务 | `o_result_ready=1`且无分支valid |
| RTR-03 | AMB_CAL | 只激活AMB分支，完整校准载荷逐位一致 |
| RTR-04 | DCS_CAL反压 | 只读取DC ready，未选分支不形成反压，载荷保持对齐 |
| RTR-05 | 红光/红外DCS交错 | `color_ir`、DC码和DC epoch不交叉 |
| RTR-06 | NORMAL 9-bit | 校准Stage1值有效，S2字段按上游事务原样透传 |
| RTR-07 | NORMAL 15-bit | S1校准值、S2_RAW、精度和身份元数据保持同一事务 |
| RTR-08 | signed边界 | -2048与+2047逐位透传，不发生符号或位宽改变 |
| RTR-09 | 校准资格与epoch独立 | `calibration_applied`不由0或非0 epoch重新推导 |
| RTR-10 | 饱和标志 | 正负饱和标志按上游值透传且不被router重算 |
| RTR-11 | 连续类别切换 | AMB、DCS、NORMAL逐拍传输，无空拍、复制或双valid |
| RTR-12 | 非法类别11 | 无功能分支valid，错误置位并直接消费防死锁 |
| RTR-13 | 反压期间复位 | 所有控制输出立即关闭，复位后空闲ready恢复 |

自检TB必须通过真实比较累计错误，只能在全部RTR用例执行且错误数为0后打印PASS。

## 8. V1冻结结论

V1冻结现有router端口`i_result_valid/o_result_ready`以保持兼容，并通过显式映射连接校准器的
`o_calibrated_valid/i_calibrated_ready`。本次只扩展公共事务载荷，不增加时钟、缓存、FSM、延迟或NORMAL扇出。
任何改变握手端口语义、非法类别消费策略、互斥路由或公共载荷位宽的方案，必须先版本化修订本合同。
