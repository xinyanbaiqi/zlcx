# PPG Scheduler / SSW / AMI 逐端口连接核对表

## 1. 文档状态

| 项目 | 内容 |
| --- | --- |
| 文档版本 | V1.3 |
| 状态 | ~~连接合同已完成；模块、联合TB和Top按下表分层记录证据，最终顶层RTL尚未编写~~ 本表为control_top实现前的设计快照，后续状态见§15 |
| 目标 | 冻结scheduler、SSW和AMI三模块之间的逐端口连接、握手、身份绑定、完成释放及故障方向 |
| 不包含 | 不修改三模块算法、模拟netlist窗口、Q3坐标、owner deadline、RTL或TB |

### 1.2 文档勘误记录（2026-08-17）

本轮勘误仅修正跨合同文档的一致性，不改变任何设计行为：

1. **状态修正**：根据当前模块合同和XSim证据更新状态；Scheduler FSC-01～57、AMI AMI-01～45和SSW SSW-01～52均记录为当前单模块PASS；JNT-01～09已在当前三模块RTL下通过52个子检查，记录为当前联合基线PASS，不覆盖新增联合矩阵或最终顶层闭合。
2. **术语修正**：正式合同统一使用`MANUAL`、`SEARCH_HOLD`、`SEARCH_TRACK`、`RESERVED`以及`PHOTODIODE`、`EXTERNAL_TEST_CURRENT`；DRAFT、handoff和历史材料保留原术语。
3. **依赖追踪修正**：各源合同区分“规范依赖”和“一致性引用”；Top和本检查表只汇总下游状态，不反向覆盖源合同。
4. **联合基线日志更新**：JNT-01～09当前基线使用`C_CLK_PERIOD_NS=500`（2 MHz，500 ns）；xvlog、xelab和xsim日志分别为`joint_tb_500ns_baseline_xvlog.log`、`joint_tb_500ns_baseline_xelab.log`和`joint_tb_500ns_baseline_xsim.log`；XSim报告52个子检查PASS，统计为`waveform=12 owner=7 completion=6`。

本勘误不新增验收编号，不改变既有JNT、FSC、AMI、SSW或其他验收编号，不修改RTL/TB、端口、时序、算法、仿真日志或历史证据归属。

**规范依赖（被核对模块和顶层连接的语义来源）**

1. `PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md` V1.2；
2. `ppg_system_config_manager_semantic_contract.md` V4.3；
3. `PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` V1.2；
4. `PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` V1.3；
5. `PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` V1.3.2；
6. `PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` V1.3.3；
7. `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` V1.3.4。

**一致性引用（只记录连接核对和证据状态，不覆盖源合同）**

1. `PPG_IMPLEMENTATION_EVIDENCE_BASELINE_20260816.md`当前证据基线。

本表是三模块真实联合TB的连接检查基线和验证记录，不替代上述模块合同。若本表与模块合同冲突，必须先修订冲突合同，禁止直接在RTL中自行选择一种解释。

### 1.1 当前证据汇总

| 对象 | 当前状态 |
| --- | --- |
| Scheduler V1.3 | FSC-01～FSC-57当前RTL/TB/XSim匹配，全部PASS，证据完整 |
| AMI V1.3.3 | AMI-01～AMI-45当前PASS；仅属AMI单模块证据 |
| SSW V1.3.2 | SSW-01～SSW-52当前PASS；仅属SSW单模块证据 |
| Scheduler + SSW + AMI联合TB | JNT-01～JNT-09当前基线PASS，共52个子检查；不覆盖新增联合矩阵或最终顶层闭合 |
| Top V1.3.4 | `ppg_control_top.v`尚未实现，待实现、待验证 |

## 2. 模块简称和连接方向

| 简称 | 模块名 | 本表中的职责 |
| --- | --- | --- |
| scheduler | `ppg_400hz_frame_calibration_scheduler` | 生成波形上下文、分配ADC事务身份、原子协调AMI fire与SSW owner commit |
| SSW | `ppg_sar9_sar15_safe_selection_wrapper` | 锁存模拟波形上下文、驱动SAR模拟波形、保存物理ADC owner |
| AMI | `ppg_adc_measurement_idac_integration` | 接受ADC结果事务、同步`CLK_DOUT`、锁存RAW、验证身份并生成可靠完成旁带 |

所有接口均位于同一个2 MHz系统时钟域。本文所述`同拍`均指同一个2 MHz有效上升沿。

## 3. 公共参数和编码一致性

### 3.1 参数宽度

| 语义 | scheduler | SSW | AMI | 必须满足 |
| --- | --- | --- | --- | --- |
| 物理帧号 | `C_FRAME_ID_WIDTH=16` | `C_FRAME_ID_WIDTH=16` | `C_FRAME_ID_WIDTH=16` | 三者参数值相等 |
| ADC事务序号 | `C_SAMPLE_INDEX_WIDTH=16` | `C_SAMPLE_INDEX_WIDTH=16` | `C_SAMPLE_INDEX_WIDTH=16` | 三者参数值相等 |
| AMB/DC码 | `C_IDAC_CODE_WIDTH=8` | `C_IDAC_CODE_WIDTH=8` | 事务端口固定8位 | 三者有效宽度相等 |
| AMB/DC码epoch | `C_CODE_EPOCH_WIDTH=4` | `C_CODE_EPOCH_WIDTH=4` | 事务端口固定4位 | 三者有效宽度相等 |
| 事务类型 | 2位 | 2位 | 2位 | 编码逐位相同 |
| 颜色 | 1位 | 1位 | 1位 | `0=RED`，`1=IR`的解释逐位相同 |
| 精度 | 1位 | 1位 | 1位 | `0=SAR9`，`1=SAR15`的解释逐位相同 |

三模块联合TB必须在仿真开始时检查公共参数相等。禁止通过截断、补零、重新编码或隐式类型转换掩盖宽度不一致。

### 3.2 事务类型编码

| `frame_type` | 语义 |
| ---: | --- |
| `2'b00` | AMB_CAL |
| `2'b01` | DCS_CAL |
| `2'b10` | NORMAL |
| `2'b11` | 保留/非法，不得建立正式owner |

## 4. 主通道一：scheduler模拟波形上下文到SSW

### 4.1 逐端口连接

| scheduler端口 | 方向 | SSW端口 | 宽度 | 核对结果 |
| --- | --- | --- | ---: | --- |
| `o_waveform_context_valid` | `scheduler -> SSW` | `i_waveform_context_valid` | 1 | 一致 |
| `i_waveform_context_ready` | `SSW -> scheduler` | `o_waveform_context_ready` | 1 | 一致 |
| `o_waveform_precision_mode` | `scheduler -> SSW` | `i_waveform_precision_mode` | 1 | 一致 |
| `o_waveform_frame_id` | `scheduler -> SSW` | `i_waveform_frame_id` | `C_FRAME_ID_WIDTH` | 参数必须相等 |
| `o_waveform_color_ir` | `scheduler -> SSW` | `i_waveform_color_ir` | 1 | 一致 |
| `o_waveform_frame_type` | `scheduler -> SSW` | `i_waveform_frame_type` | 2 | 一致 |
| `o_waveform_amb_code_snapshot` | `scheduler -> SSW` | `i_waveform_amb_code_snapshot` | 8 | 一致 |
| `o_waveform_dc_code_snapshot` | `scheduler -> SSW` | `i_waveform_dc_code_snapshot` | 8 | 一致 |
| `o_waveform_amb_code_epoch` | `scheduler -> SSW` | `i_waveform_amb_code_epoch` | 4 | 一致 |
| `o_waveform_dc_code_epoch` | `scheduler -> SSW` | `i_waveform_dc_code_epoch` | 4 | 一致 |
| `o_waveform_input_source` | `scheduler -> SSW` | `i_waveform_input_source` | 1 | 一致 |
| `o_waveform_optical_mode` | `scheduler -> SSW` | `i_waveform_optical_mode` | 2 | 一致 |
| `o_waveform_leddac_code_snapshot` | `scheduler -> SSW` | `i_waveform_leddac_code_snapshot` | 8 | 一致 |

### 4.2 唯一fire定义

```text
waveform_context_fire =
    scheduler.o_waveform_context_valid
 && SSW.o_waveform_context_ready
```

冻结规则：

- `valid`由scheduler保持，等待期间全部载荷逐位稳定；
- `ready`只由SSW根据固定接管点、目标波形槽可用、生命周期和本地阻断故障产生；
- NORMAL RED、NORMAL IR和CAL的接管点分别为macro tick 0、macro tick 160和local tick 0；
- 该fire只锁存模拟波形身份，不建立AMI结果owner；
- 该fire绑定并锁存`frame_id`，但不携带、不预约、不消费`sample_index`；
- IR波形上下文接管不得因RED ADC owner仍在途而被拒绝；
- 错过固定接管点后禁止迟到fire或移动Q3。

## 5. 主通道二：scheduler ADC结果事务到AMI

### 5.1 逐端口连接

| scheduler端口 | 方向 | AMI端口 | 宽度 | 核对结果 |
| --- | --- | --- | ---: | --- |
| `o_transaction_start_valid` | `scheduler -> AMI` | `i_transaction_start_valid` | 1 | 一致 |
| `i_transaction_start_ready` | `AMI -> scheduler` | `o_transaction_start_ready` | 1 | 一致 |
| `i_transaction_start_fire` | `AMI -> scheduler` | `o_transaction_start_fire` | 1 | 仅同拍一致性监测 |
| `o_transaction_precision_mode` | `scheduler -> AMI` | `i_transaction_precision_mode` | 1 | 一致 |
| `o_transaction_frame_id` | `scheduler -> AMI` | `i_transaction_frame_id` | `C_FRAME_ID_WIDTH` | 参数必须相等 |
| `o_transaction_sample_index` | `scheduler -> AMI` | `i_transaction_sample_index` | `C_SAMPLE_INDEX_WIDTH` | 参数必须相等 |
| `o_transaction_color_ir` | `scheduler -> AMI` | `i_transaction_color_ir` | 1 | 一致 |
| `o_transaction_frame_type` | `scheduler -> AMI` | `i_transaction_frame_type` | 2 | 一致 |
| `o_transaction_amb_code_snapshot` | `scheduler -> AMI` | `i_transaction_amb_code_snapshot` | 8 | 一致 |
| `o_transaction_dc_code_snapshot` | `scheduler -> AMI` | `i_transaction_dc_code_snapshot` | 8 | 一致 |
| `o_transaction_amb_code_epoch` | `scheduler -> AMI` | `i_transaction_amb_code_epoch` | 4 | 一致 |
| `o_transaction_dc_code_epoch` | `scheduler -> AMI` | `i_transaction_dc_code_epoch` | 4 | 一致 |

### 5.2 唯一fire定义

```text
transaction_start_fire_local =
    scheduler.o_transaction_start_valid
 && AMI.o_transaction_start_ready

AMI.o_transaction_start_fire == transaction_start_fire_local
```

冻结规则：

- 正式fire只由`valid && ready`定义；
- AMI返回的`o_transaction_start_fire`只能作同拍一致性检查，不得反馈参与scheduler的`valid`或任何`ready`生成；
- scheduler只有在匹配波形上下文已经fire、SSW给出`o_adc_owner_ready=1`且尚未超过owner deadline时，才允许向AMI形成可握手`valid`；
- AMI反压期间，scheduler保持`valid`和全部事务载荷逐位稳定，直到真实fire或owner deadline失效；
- AMI只在该fire取得ADC结果事务owner；AMI不拥有模拟波形上下文；
- 当前`sample_index`只在该fire首次正式绑定并消费，scheduler随后模`2^C_SAMPLE_INDEX_WIDTH`递增；
- 未fire事务不得递增、跳过或预留`sample_index`。

## 6. 主通道三：scheduler原子owner commit到SSW

### 6.1 逐端口连接

| SSW端口 | 方向 | scheduler端口 | 宽度 | 核对结果 |
| --- | --- | --- | ---: | --- |
| `o_adc_owner_ready` | `SSW -> scheduler` | `i_adc_owner_ready` | 1 | 一致 |
| `i_adc_owner_commit_event` | `scheduler -> SSW` | `o_adc_owner_commit_event` | 1 | 一致 |
| `i_adc_owner_precision_mode` | `scheduler -> SSW` | `o_adc_owner_precision_mode` | 1 | 一致 |
| `i_adc_owner_frame_id` | `scheduler -> SSW` | `o_adc_owner_frame_id` | `C_FRAME_ID_WIDTH` | 参数必须相等 |
| `i_adc_owner_color_ir` | `scheduler -> SSW` | `o_adc_owner_color_ir` | 1 | 一致 |
| `i_adc_owner_frame_type` | `scheduler -> SSW` | `o_adc_owner_frame_type` | 2 | 一致 |
| `i_adc_owner_amb_code_snapshot` | `scheduler -> SSW` | `o_adc_owner_amb_code_snapshot` | 8 | 一致 |
| `i_adc_owner_dc_code_snapshot` | `scheduler -> SSW` | `o_adc_owner_dc_code_snapshot` | 8 | 一致 |
| `i_adc_owner_amb_code_epoch` | `scheduler -> SSW` | `o_adc_owner_amb_code_epoch` | 4 | 一致 |
| `i_adc_owner_dc_code_epoch` | `scheduler -> SSW` | `o_adc_owner_dc_code_epoch` | 4 | 一致 |
| `i_adc_owner_sample_index` | `scheduler -> SSW` | `o_adc_owner_sample_index` | `C_SAMPLE_INDEX_WIDTH` | 参数必须相等 |

### 6.2 原子提交关系

```text
adc_owner_commit =
    transaction_start_fire_local
 && SSW.o_adc_owner_ready

scheduler.o_adc_owner_commit_event = adc_owner_commit
```

在`adc_owner_commit=1`的同一拍，以下关系必须全部成立：

```text
scheduler.o_adc_owner_* == scheduler.o_transaction_*
scheduler.o_adc_owner_sample_index == scheduler.o_transaction_sample_index
AMI.o_transaction_start_fire == transaction_start_fire_local
SSW.o_adc_owner_ready == 1
```

冻结规则：

- SSW的`o_adc_owner_ready`只表示最早pending波形上下文可建立owner；
- `o_adc_owner_ready`不得依赖AMI的`valid`、`ready`、返回fire或实时owner载荷；
- scheduler不得在`o_adc_owner_ready=0`时向AMI形成可握手事务；
- SSW只在`commit_event=1`、自身ready为1且身份与最早pending波形快照逐位匹配时建立owner；
- `sample_index`是owner提交沿新增的唯一身份字段，其余字段必须复用早先的波形快照；
- 任一身份字段不匹配时不得建立owner，必须进入阻断协议错误处理；
- 任一时刻最多存在一个已提交ADC结果owner。

## 7. 主通道四：AMI完成旁带同时扇出到scheduler和SSW

### 7.1 逐端口连接

| AMI输出 | scheduler输入 | SSW输入 | 宽度 | 连接要求 |
| --- | --- | --- | ---: | --- |
| `o_adc_transaction_complete_event` | `i_adc_transaction_complete_event` | `i_adc_transaction_complete_event` | 1 | 同一根单拍事件网扇出 |
| `o_adc_transaction_success` | `i_adc_transaction_success` | `i_adc_transaction_success` | 1 | 与完成事件同拍、同源扇出 |
| `o_adc_complete_sample_index` | `i_adc_complete_sample_index` | `i_adc_complete_sample_index` | `C_SAMPLE_INDEX_WIDTH` | 与完成事件同拍、同源扇出 |

该旁带没有`ready`，也不允许两个消费者分别重建、延迟、合并或重新编码。AMI只有在`CLK_DOUT`同步、RAW稳定锁存、事务身份匹配并完成内部接纳后才能产生该原子旁带。

### 7.2 DONE与owner释放真值表

| complete event | sample index | success | scheduler/SSW owner动作 | 正式结果动作 |
| ---: | --- | ---: | --- | --- |
| 0 | 任意 | 任意 | 不释放 | 不产生 |
| 1 | 匹配当前owner | 1 | scheduler与SSW同拍释放同一owner | 允许进入对应NORMAL或校准成功路径 |
| 1 | 匹配当前owner | 0 | scheduler与SSW同拍释放同一旧物理owner | 严禁进入router、IDAC更新、NORMAL结果或阶段成功路径 |
| 1 | 不匹配当前owner | 任意 | 不得释放当前owner，置身份错配/阻断诊断 | 严禁产生 |
| 1 | 当前无owner | 任意 | 不得借用新事务或旧波形身份，置协议诊断 | 严禁产生 |

冻结的释放条件为：

```text
owner_release =
    adc_transaction_complete_event
 && adc_complete_sample_index == current_owner_sample_index
```

`success`不是物理owner释放条件，而是完成结果能否进入后续处理的资格。特别是abort或受控丢弃后的匹配迟到DONE，必须以`success=0`释放旧物理owner，但不得形成正式完成结果。

禁止以Q3末沿、SAR波形结束、固定周期延时、宏帧tick、`i_adc_idle`或NORMAL帧完成事件代替上述DONE旁带。

### 7.3 合同措辞一致性闭环

AMI V1.3.3、scheduler V1.3完成释放措辞勘误和SSW V1.3.2完成释放措辞勘误现已统一冻结：“匹配`success=0`旁带释放旧owner且不进入数据链”。三份合同均使用相同的sample-index匹配释放条件；本项不再是RTL编写前的文档阻断项。

## 8. 主通道五：scheduler START边界到AMI的IDAC安全边界

### 8.1 逐端口连接

| scheduler输出 | AMI输入 | 宽度 | 连接要求 |
| --- | --- | ---: | --- |
| `o_idac_code_safe_boundary` | `i_idac_code_safe_boundary` | 1 | 唯一实际功能连接 |
| `o_startup_idac_safe_boundary` | 无同名AMI端口 | 1 | 启动子类型/诊断旁带，不得擅自新增AMI端口 |

START后的合法启动拍必须满足：

```text
scheduler.o_startup_idac_safe_boundary = 1
scheduler.o_idac_code_safe_boundary    = 1
```

AMI随后仅执行：

```text
AMI.i_idac_code_safe_boundary
    -> ppg_idac_code_controller.i_frame_safe_boundary
```

冻结规则：

- scheduler在ADC空闲、模拟安全、SAR时序空闲、无波形valid、无事务valid且无在途owner后发布；
- 每个START最多发布一次；
- 该边界不得被`startup_search_complete=0`、`normal_measurement_eligible=0`或首个宏帧尚未启动阻挡；
- AMI不得缓存、合并、补发、过滤或重新定时该边界；
- 该边界不启动ADC、不产生波形上下文、不产生宏帧边界、不提交精度、不触发AMB重检，也不推进`frame_id/sample_index`；
- 不得把`o_startup_idac_safe_boundary`和`o_idac_code_safe_boundary`再次OR后送入AMI，否则会造成一次START两次提交风险。

## 9. 主通道六和七：AMI/SSW阻断故障到scheduler

### 9.1 逐端口连接

| 故障源输出 | scheduler输入 | 宽度 | 极性/类型 | 核对结果 |
| --- | --- | ---: | --- | --- |
| `AMI.o_wrapper_fault_blocking` | `i_ami_fault_blocking` | 1 | 高有效保持电平 | 一致 |
| `SSW.o_wrapper_fault_blocking` | `i_ssw_fault_blocking` | 1 | 高有效保持电平 | 一致 |

冻结规则：

- 两路是独立根因输入，不是valid/ready事件，也不是单拍脉冲；
- 任一路为1均阻止scheduler发起新的波形接管或ADC owner提交；
- 顶层不得先把两路OR成来源不明的单一scheduler输入；
- `scheduler.o_scheduler_local_fault_blocking`只汇总scheduler本地活动根因和协议错误；
- 禁止把scheduler本地fault组合反馈到AMI/SSW的fault生成路径；
- 历史timeout sticky与当前blocking fault必须分开，不能因单次有界超时永久锁死系统；
- fault解除和sticky清除必须遵循各模块STOP、abort、reset及安全空闲规则，不能靠组合取反强行清除。

## 10. 支撑安全状态连接

| 来源 | 目标 | 宽度 | 语义 |
| --- | --- | ---: | --- |
| `SSW.o_analog_safe` | `scheduler.i_analog_safe` | 1 | 当前模拟输出允许停止、切换或发布启动IDAC边界 |
| `SSW.o_sar_timing_idle` | `scheduler.i_sar_timing_idle` | 1 | 无模拟预建立、Q1/Q2/Q3窗口或待完成安全切换 |
| `SSW.o_analog_safe` | `AMI.i_analog_safe` | 1 | AMI新事务与精度相关资格使用同一模拟安全事实 |
| 顶层`flag_adc_physical_idle` | `scheduler.i_adc_idle` | 1 | 物理ADC无转换且DONE回到可启动状态 |
| 顶层`flag_adc_physical_idle` | `AMI.i_adc_idle` | 1 | AMI start资格的物理空闲输入 |
| 顶层`flag_adc_physical_idle` | `SSW.i_adc_idle` | 1 | SSW完整idle与物理排空判断 |

三个`i_adc_idle`必须由顶层V1.3.2冻结的唯一`flag_adc_physical_idle`同源扇出。该网不是握手`ready`，也不得误接为AMI内部`o_adc_chain_idle`、`o_datapath_empty`或测量输出FIFO空闲。SSW合同端口表中“来源=AMI”的描述只能解释为AMI所在ADC捕获边界关联的物理状态，不得解释为AMI数据通路排空状态。

## 11. `frame_id`和`sample_index`绑定时刻

| 时刻 | `frame_id` | `sample_index` | 允许的状态变化 |
| --- | --- | --- | --- |
| scheduler建立宏帧 | 确定本宏帧ID | 尚未绑定事务 | RED/IR共享同一宏帧ID |
| `waveform_context_fire` | SSW原子锁存本波形`frame_id` | 不存在、不预留、不递增 | 锁存精度、颜色、类型、码、epoch、输入源、光学模式和LEDDAC快照 |
| 等待owner | 必须保持早先快照 | 当前scheduler next值尚未消费 | AMI反压不得改变载荷 |
| `transaction_start_fire_local` | 必须逐位复用匹配波形`frame_id` | 首次绑定当前next值并在fire后递增 | AMI取得结果owner，scheduler同拍向SSW commit |
| owner在途 | 三方保持同一事务身份 | 固定为已提交值 | 新IDAC提交或ACTIVE变化不得污染旧owner |
| 匹配完成旁带 | 返回原owner `sample_index` | 不再递增 | scheduler和SSW同拍释放；success只决定后续处理资格 |

双光NORMAL必须满足：

```text
RED.frame_id == IR.frame_id
IR.sample_index == RED.sample_index + 1 mod 2^C_SAMPLE_INDEX_WIDTH
```

同色400 Hz连续性按`frame_id`判断，不能用相邻`sample_index+1`判断，因为双光模式下相邻同色sample index通常相差2。

### 11.1 顶层RUN许可拆分与极性

顶层只允许使用以下三根高有效许可网，不重新设计Scheduler或AMI的时序接口：

| 顶层内部网 | 目标 | 高有效语义 | 非STATIC_BIAS | STATIC_BIAS |
| --- | --- | --- | --- | --- |
| `analog_run_enable` | `SSW.i_run_enable` | 允许模拟控制生命周期运行 | `run_enable` | `1`，建立静态向量 |
| `measurement_run_enable` | `Scheduler.i_run_enable`、`AMI.i_run_enable` | 允许测量生命周期运行 | `run_enable` | `0`，测量链保持空闲 |
| `measurement_allow_new_transaction` | `Scheduler.i_allow_new_transaction`、`AMI.i_allow_new_transaction` | 允许发起新ADC事务 | `allow_new_transaction` | `0` |

START事件同样拆分：`analog_start_ack_event`只送SSW；`measurement_start_ack_event`只送Scheduler和AMI，
STATIC_BIAS时必须为0。STOP、abort、reset和诊断清除事件不随该拆分屏蔽，仍同步送达三模块。

极性核对要求：三根许可均为高有效电平，目标端口不得再次反相、脉冲化或与其他RUN信号组合；
`analog_run_enable`不得送Scheduler/AMI，`measurement_run_enable`不得送SSW。该表仅冻结最终顶层连接，
当前尚未由`ppg_control_top.v`实现或仿真验证。

## 12. 组合ready环审查

### 12.1 允许的单向组合依赖

```text
SSW本地波形槽/相位/生命周期
    -> SSW.o_waveform_context_ready

SSW最早pending波形/owner空闲/deadline/生命周期
    -> SSW.o_adc_owner_ready
    -> scheduler允许提出transaction valid

AMI本地结果owner空闲/物理ADC空闲/模拟安全/S1接纳资格
    -> AMI.o_transaction_start_ready

scheduler.transaction valid && AMI.transaction ready
    -> transaction_start_fire_local
    -> scheduler.o_adc_owner_commit_event
```

### 12.2 明确禁止的依赖

| 禁止路径 | 原因 |
| --- | --- |
| `AMI.o_transaction_start_fire -> SSW.o_adc_owner_ready` | 返回fire不能反向决定提交资格，会形成半提交或组合环 |
| `AMI.o_transaction_start_ready -> SSW.o_adc_owner_ready` | SSW owner资格必须独立于AMI ready |
| `scheduler.o_transaction_start_valid -> SSW.o_adc_owner_ready` | ready不得由即将接收自己的valid产生 |
| `SSW.o_adc_owner_ready -> AMI.o_transaction_start_ready` | AMI ready只表示AMI自身可接收，不得伪装成跨模块联合ready |
| `AMI.o_transaction_start_fire -> scheduler.o_transaction_start_valid` | 返回fire只作一致性监测，不得生成或保持valid |
| `scheduler.o_scheduler_local_fault_blocking -> AMI/SSW fault -> scheduler fault` | 会形成故障组合反馈环 |
| 任一完成旁带消费者的状态 -> AMI完成旁带 | 完成旁带无ready，消费者不得反压或重建DONE |

### 12.3 组合环审查结论

按本表连接时不存在组合ready环。关键条件是：

1. SSW两个ready完全由SSW本地已锁存状态、相位和生命周期资格产生；
2. AMI ready完全由AMI本地结果owner与内部接纳资格产生；
3. scheduler用SSW owner ready门控是否提出AMI valid，但不把AMI ready/fire反馈给SSW ready；
4. owner commit由scheduler本地`valid && ready`同拍生成，AMI返回fire只在时序逻辑中比较；
5. 完成旁带为无反压单向扇出。

## 13. RTL编写前最终检查清单

| 编号 | 检查项 | 当前状态 |
| --- | --- | --- |
| PC-01 | waveform通道13个端口逐位对应 | 已闭合 |
| PC-02 | waveform fire只由scheduler valid与SSW ready定义 | 已闭合 |
| PC-03 | waveform fire不消费sample index | 已闭合 |
| PC-04 | ADC transaction通道12个端口逐位对应 | 已闭合 |
| PC-05 | AMI fire严格等于transaction valid与ready | 已闭合 |
| PC-06 | owner commit与AMI真实fire同拍 | 已闭合 |
| PC-07 | owner载荷与AMI事务载荷逐位相同 | 已闭合 |
| PC-08 | sample index只在真实fire绑定并递增 | 已闭合 |
| PC-09 | AMI完成三元组同源、同拍扇出到scheduler和SSW | 已闭合 |
| PC-10 | 匹配`success=0`只释放owner、不形成结果 | 已闭合 |
| PC-11 | START子类型边界和实际IDAC边界不重复连接 | 已闭合 |
| PC-12 | AMI fault与SSW fault独立、高有效接入scheduler | 已闭合 |
| PC-13 | scheduler本地fault不反馈形成组合环 | 已闭合 |
| PC-14 | `o_analog_safe`和`o_sar_timing_idle`来源唯一 | 已闭合 |
| PC-15 | 三模块`i_adc_idle`使用同一物理ADC/DONE空闲事实 | 已由顶层V1.3.2冻结为`flag_adc_physical_idle` |
| PC-16 | 公共参数宽度和编码完全一致 | 合同一致，待RTL elaboration/TB检查 |
| PC-17 | 不存在valid/ready/fire组合反馈环 | 连接规则已闭合，待RTL lint/结构检查 |
| PC-18 | Q3、固定延时和波形末沿不能伪造DONE | 已闭合 |
| PC-19 | 当前V1.2旧单fire RTL不得作为兼容实现保留 | JNT-01至JNT-09联合TB通过52个子检查；当前基线使用`C_CLK_PERIOD_NS=500`，证据为`joint_tb_500ns_baseline_xsim.log`；未使用旧单fire或固定4拍完成模型 |
| PC-20 | `analog_run_enable`仅接SSW且高有效 | 合同已闭合，顶层RTL待编写 |
| PC-21 | `measurement_run_enable`仅接Scheduler/AMI且高有效 | 合同已闭合，顶层RTL待编写 |
| PC-22 | STATIC_BIAS下测量START和新事务许可为0 | 合同已闭合，顶层RTL待编写 |

## 14. 审查结论和实施门槛

七条指定主连接的端口方向、名称和位宽可以完整一一对应；新增的三根RUN许可网及其高有效极性也已完成合同核对。三模块联合RTL不存在需要新增功能端口的阻断缺口。scheduler和SSW的`success=0`释放措辞已经闭合；共享物理ADC idle也已由顶层V1.3.2冻结为`i_adc_physical_idle -> flag_adc_physical_idle`的唯一同源扇出网络。本核对表列出的连接文档前置项现已全部闭合，但这不等于最终顶层V1.4的其他系统前置条件已经完成。

当前证据仅支持上述分层结论：Scheduler的FSC-01～FSC-57、AMI的AMI-01～AMI-45和SSW的SSW-01～SSW-52均为当前单模块PASS；JNT-01～JNT-09已在当前三模块RTL下以`C_CLK_PERIOD_NS=500`通过52个子检查，属于当前联合基线PASS，但不能替代新增联合矩阵或最终顶层回归。当前联合证据对应`joint_tb_500ns_baseline_xvlog.log`、`joint_tb_500ns_baseline_xelab.log`和`joint_tb_500ns_baseline_xsim.log`，统计为`waveform=12 owner=7 completion=6`。`tb_ppg_scheduler_ssw_ami_integration.v`使用真实`CLK_DOUT`同步与RAW锁存路径产生DONE，不使用固定4拍完成模型；新增RUN许可连接及最终系统级连接仍须待`ppg_control_top.v`实现后验证。

## 15. 后续状态（2026-10-01补记）

本表是`ppg_control_top.v`实现之前的设计快照。第1.1节、第11.1节、第13节PC-20~PC-22和第14节中“顶层RTL尚未编写/待编写”“当前联合基线PASS”等状态描述，都停留在2026-08-17，本节之前的正文保持原样不再更新；当前状态以本节为准：

1. **顶层已实现**：`rtl/ppg_control_top/ppg_control_top.v`于2026-08-23首版实现（文件头V1.0：“First RTL implementation of contract C01 (V1.10)”），此后的版本见其文件头；Scheduler、SSW、AMI三模块在其中按C01逐位互连。
2. **三模块联合TB已退役**：第14节作为JNT-01~09证据引用的`tb_ppg_scheduler_ssw_ami_integration.v`，已于2026-09-30（commit `50a2b88`）`git mv`到`legacy/rtl/ppg_system_integration/`。原因见`legacy/README.md`：它落后于RTL（08-17之后新增的14个输入没有连接）；JNT-08仍按与合同矛盾的`success==1`断言；`$fopen`写死了原始开发树的绝对路径。
3. **JNT-01~09证据的现承接方式**：由`rtl/ppg_control_top/`下的19-TB主回归承接，其中14份TB通过`` `include ``共用`rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh`执行JNT-01~09基线。该前缀源自上述联合TB，并已修正JNT-08的断言。最新一次全套回归见`verification_reports/REGRESSION_BASELINE_20260930.md`。

本节只记录状态，不改变上文任何逐端口连接结论。这些连接的现行权威描述是C01、C08、C09和C10；本表仍是矩阵§2所定的non-normative design reference。
