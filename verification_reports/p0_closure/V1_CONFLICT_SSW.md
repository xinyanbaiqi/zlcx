# V1 同拍冲突矩阵：SSW（`ppg_sar9_sar15_safe_selection_wrapper.v`，对照C09）

- 任务：流片前验证收尾 P0-V1，模块2/3
- 基线：main `a1ba482`；RTL V1.8（L-6修复后，`1b9e971`/`fc03d95`）；只读
- 方法：与调度器文件相同（skill只读分析，纯静态，没有仿真器）。合同：C09（`contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md`）。调度器侧的引理U1–U9见`V1_CONFLICT_SCH.md` §1，本文直接引用。

## 0. 结构与记号

SSW共64个always块：63个时序块，1个组合块（624–780，生成`reg_control_next`）。时序块都是`if/else if`链，前面的分支优先；只有4个sticky块与`flag_cal/ir/red_context_valid`三个块在最后的else里用两个并列的`if`，**后写者胜**。

常用组合量（行号为基线）：

| 量 | 行号 | 定义要点 |
|---|---|---|
| `flag_context_fire` | 410 | `valid && o_waveform_context_ready && !i_control_abort_event` |
| `flag_owner_commit_fire` | 434 | `commit_event && o_adc_owner_ready && identity_match && !abort` |
| `flag_owner_commit_error` | 435 | `commit_event && !flag_owner_commit_fire` |
| `flag_owner_release` | 436 | （完成或作废）且在途且序号和代际匹配 |
| `flag_done_mismatch` | 437 | （完成或作废）且不能释放 |
| `flag_start_restore` | 449 | `start_ack && !adc_owner_inflight_o && i_adc_idle`（L-6） |
| `flag_*_owner_window` | 420–422 | 上下文有效且tick ≤ 截止 |
| `flag_*_owner_candidate` | 425–427 | 窗口内、无在途owner、`!stop_pending`、`!static`；IR要求`!red_owner_window`；CAL要求RED/IR上下文都无效 |
| `flag_*_has_owner` | 440–442 | 在途、`!abort_seen`、槽位与帧号匹配；CAL还要求子帧匹配 |
| `flag_*_timeout` | 443–445 | 上下文有效且tick=截止+1且无本色owner |
| `o_wrapper_idle` | 494 | 三个上下文都无效、无在途owner、`i_adc_idle` |

额外引理：

- **S1**：`o_waveform_context_ready`（456）与`o_adc_owner_ready`（459）在STOP拍、abort拍不被立即屏蔽：`stop_pending`是寄存的，abort只门控fire。但调度器的波形valid与owner valid在这两拍都由`flag_lifecycle_active`屏蔽（调度器440、460、470），所以这两拍SSW两侧的fire都不会成立。
- **S2**：`i_normal_frame_active`与`i_calibration_frame_active`不能同时为1（调度器581–582，U7），所以`flag_switch_protocol_error_condition`（450）中的“双模式”项不可达。
- **S3**：任意时刻最多只有一个RED/IR/CAL owner候选：IR候选要求`!red_owner_window`；CAL候选要求`!red_context_valid && !ir_context_valid`。

## 1. 冲突矩阵

处置：(a)构造上互斥｜(b)可同拍，RTL优先级与意图一致｜(c)发现｜待定。

### 1.1 模拟控制向量（重点）

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `reg_control_next`（组合，624–780） | ① `flag_static_active` > ② `reg_run_active && !abort` > ③ 全0；②中依次执行RED段（641–688）、IR段（689–742）、CAL段（743–778），**同一位后写者胜** | **RED段 × IR段，SAR9，`CTRL_EN_9_IREF/EN_9_AMB/EN_9_DC`** | **(c) V1-SSW-C1（高）** | RED段对这三位赋值为RED窗口（657–660）；IR段的SAR9分支对同三位直接赋值为IR窗口（707–710），没有与RED结果OR。双光SAR9时IR上下文在tick 160接管，`flag_ir_wave_active`从tick 204起为1（412），完全覆盖RED窗口[236,308)/[256,310)，于是RED的三个SAR9使能在整个窗口内被清0。C09 §4.6明文要求`o_en_sar9_iref`、`o_en_sar9_amb_low`、`o_en_sar9_dc_low`“仍使用各自独立颜色窗口”。详见§2 | 是：见§2 |
| 〃 | 〃 | RED × IR，SAR15，`EN_15_IREF/AMB/DC` | (b) | IR段用OR（695–700），形成并集；属C09 §4.6的SAR15四项白名单 | 否（SSW-41） |
| 〃 | 〃 | RED × IR，`CTRL_IREF_9`/`CTRL_IREF_15` | (b) | 两段都写1；`CTRL_IREF_9`即`o_clk_iref_idac_sar9_low`，属SAR9单项白名单 | 否（SSW-44） |
| 〃 | 〃 | RED × IR，`CTRL_IREF_IDAC`、`AMB9/DC9/AMB15/DC15`总线 | (b) | 都用OR；RED与IR的窗口不重叠 | 否 |
| 〃 | 〃 | RED owner段 × IR owner段（`EN_TIA/AFERST/TIAEN/Q2/Q3/Q1_*/EN_15/LED_*`） | (a) | `flag_red_has_owner`与`flag_ir_has_owner`要求不同的`reg_owner_slot`（440–441），同一时刻只有一个owner | 否 |
| 〃 | 〃 | IR owner段的`Q1_15`/`Q1_9`赋值（731、734）× RED wave段 | (a) | RED wave段不写Q1；RED owner段写Q1时IR没有owner | 否 |
| 〃 | 〃 | CAL段 × RED/IR段 | (a) | CAL上下文只在CAL帧接管（396），RED/IR只在NORMAL帧（395）。RED/IR上下文在同帧tick 317/477前释放（414–415），CAL帧最早在下一帧tick 0开始；abort与`flag_start_restore`会同时清掉三个上下文 | 否 |
| 〃 | 〃 | ① static × ② run | (b) | STATIC_BIAS优先，C09 §8.5 | 否 |
| `reg_control_vector`（612） | 复位 > abort清0 > `reg_control_next` | abort × 任何波形 | (b) | C09 §8.3“下一个可见控制更新将所有可撤销模拟控制置为安全向量”；RTL在abort当拍的沿就清0，比合同更早 | 否 |

### 1.2 运行生命周期

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `reg_run_active`（783） | `flag_start_restore`置1 > `(!run_enable \|\| stop_pending) && wrapper_idle`清0 | START × 清0条件 | (b) | U1：START拍`run_enable=1`；L-6情形下`stop_pending=1`，START优先恢复运行，F009 §6.3 | 否（L6-START） |
| 〃 | 〃 | START时有在途owner或ADC不空闲（`flag_start_restore=0`） | (a) | manager `flag_start_ready`要求`i_adc_idle && i_datapath_empty`（manager 452）；在CONFIG/READY期间没有新owner，所以START拍不可能有在途owner；F009 §6.3写明的前提 | 断言：`i_start_ack_event → flag_start_restore`（任何一拍不成立即说明前提被破坏，SSW整轮RUN都不会运行） |
| `flag_stop_pending`（796） | abort置1 > stop_ack置1 > `!run_active && wrapper_idle`清0 > `flag_start_restore`清0 | **abort × START** | **(c) 并入V1-SCH-C3** | SPI 0x11可使二者同拍（调度器U4）。SSW中abort优先，`stop_pending=1`；`reg_run_active`被START置1，三个上下文被abort清掉，sticky被start_restore清掉。SSW的净效果是“已abort”，下一拍起`mode_legal=0`（395–396，含`!stop_pending`），不接管，随后清`run_active`。调度器在同一拍却是START胜出（T+2拍lifecycle有效），两模块处理不一致。T+2拍SSW两侧都空闲，所以调度器可以发出一拍启动IDAC边界；没有波形或owner可以建立 | 是：同调度器C3 |
| 〃 | 〃 | stop_ack × START | (a) | U2 | 否 |
| 〃 | 〃 | 清0条件 × start_restore | (b) | 两者都清0 | 否 |

### 1.3 波形上下文与快照

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `flag_red_context_valid`（1291）、`flag_ir_context_valid`（1104）、`flag_cal_context_valid`（956） | abort清0 > `flag_start_restore`清0 > [`*_wave_last`清0；fire置1，fire在后胜出] | fire × wave_last | (a) | RED在tick 0接管，末拍为307/317；IR在160接管，末拍为467/477；CAL在local 0接管，末拍为local 283（397–399、414–416） | 否 |
| 〃 | 〃 | abort × fire | (a) | fire含`!abort`（410） | 否 |
| 〃 | 〃 | start_restore × fire | (a) | START拍调度器lifecycle=0，波形valid=0（U1） | 否 |
| 〃 | 〃 | STOP × 已有上下文 | (b) | STOP不清上下文，包络走到末拍自行释放；C09 §8.2；调度器V1.6修订 | 否 |
| 〃 | 〃 | 新RUN的START × 上一RUN残留的上下文 | (b) | L-6：start_restore作废残留上下文，brief §3.7 | 否（L6-START、L6SCAN） |
| 34个快照寄存器：`reg_{red,ir,cal}_{amb_code,amb_epoch,dc_code,dc_epoch,frame_id,frame_type,input_source,leddac_code,optical_mode,precision,generation}`、`reg_cal_color_ir`（813–953、974–1101、1122–1288） | abort保持 > `fire && is_X`装载 | abort × 装载 | (a) | fire含`!abort`；每个寄存器只有一个装载者。START/STOP不清，作废后不再被读，下一次接管整体覆盖（F009 §6.3已核实） | 否 |

### 1.4 owner

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `adc_owner_inflight_o`（521） | release清0 > abort保持 > commit_fire置1 | release × commit | (a) | 候选含`!adc_owner_inflight_o`（425–427），release要求它为1（436） | 否 |
| 〃 | 〃 | release × abort | (b) | 匹配完成在abort拍照常释放；C09 §8.3“匹配完成旁带释放旧物理owner”；与调度器P9m在P1之后的处理一致 | 否 |
| 〃 | 〃 | abort × commit | (a) | commit_fire含`!abort`（434）；调度器owner valid含lifecycle | 否 |
| 〃 | 〃 | 作废（lost）× commit | (a) | 同release | 否 |
| `reg_owner_abort_seen`（1309） | release清0 > abort（在途时）置1 > commit清0 | release × abort | (b) | 释放后无需保留abort标记 | 否 |
| `reg_owner_q3_closed_o`（534） | release清0 > commit清0 > 累加 | — | (a) | release与commit互斥；累加项`flag_owner_q3_closed_combo`含`!abort_seen` | 否 |
| `reg_owner_sample_index/generation/frame_id/color_ir/frame_type/precision_mode/slot`（1324–1427） | abort保持 > release保持 > commit装载 | — | (a) | 单装载者；commit含`!abort`；`reg_owner_slot`的RED>IR>CAL选择由S3保证唯一 | 否 |
| `reg_owner_cal_subframe`（1363） | commit装载 | — | (a) | 同上 | 否 |
| `o_adc_owner_ready` × 调度器候选颜色 | RED已在283前释放后，SSW仍只给RED候选（`!red_owner_window`），调度器已改给IR候选 | F-3附 | 不在本次 | brief §3.8排除。供收尾计划参考：此时调度器IR valid遇到SSW ready（RED候选），commit_event的身份按RED比对必然不匹配，触发`flag_owner_commit_error`，进而`switch_protocol_error_sticky`形成阻断。只有RED在283前完成（早于Q3=300，属异常早到DONE）时可达 | — |

### 1.5 sticky与故障记录

| 对象 | 条件与优先级（RTL行号） | 条件对 | 处置 | 理由或依据 | 建议扫描或断言 |
|---|---|---|---|---|---|
| `switch_protocol_error_sticky_o`（579） | `flag_start_restore`清0 > [`diag && wrapper_idle`清0；条件置1，置1胜出] | diag × 条件（空闲时的接管点ready错配） | (b) | 新错误胜出；C09 §7.8“非法…必须保持阻断” | 断言：同拍新错误时下一拍sticky=1 |
| 〃 | 〃 | start_restore × 条件 | (a) | 条件各项：commit_error在START拍不可能（调度器lifecycle=0）；双模式不可达（S2）；ready错配要求valid=1，而START拍valid=0；static_bias非法在COMMIT即被拒（manager ILM-15） | 否 |
| `transaction_mismatch_sticky_o`（595） | 同上，置位条件为`flag_done_mismatch` | diag × 无owner的DONE | (b) | 同上 | 同上 |
| 〃 | 〃 | start_restore × DONE | (a) | 调度器§2.4：START前提下没有完成 | 否 |
| `owner_deadline_timeout_sticky_o`（563） | start_restore清0 > [diag清0；`flag_*_timeout`置1] | diag × timeout | (a) | diag要求`wrapper_idle`即三个上下文都无效，timeout要求上下文有效 | 否 |
| 〃 | 〃 | **STOP（`stop_pending`）落在接管与owner提交之间** | **(c) V1-SSW-C2（低）** | STOP后`stop_pending=1`使候选为0（425–427），上下文仍有效，到截止+1拍（284/444/local 249）时`flag_*_timeout`置sticky。调度器在STOP拍就清掉`*_WAVE_PENDING`，不会置自己的owner截止sticky。同一事件在两模块的诊断不一致；与调度器V1-SCH-C2同类（调度器只有正好同拍才置）。abort落在截止+1拍时上下文仍有效（abort在本拍清），同样会置位；早一拍abort则不置 | 是：STOP落在RED tick 1..283，检查两模块sticky；abort落在284±1 |
| `calibration_timeout_sticky_o`（547） | start_restore清0 > [diag清0；`CAL帧 && local==385 && cal_has_owner`置1] | diag/start_restore × 置位 | (a) | 置位要求在途owner；diag要求`wrapper_idle`（无owner）；start_restore要求`!inflight` | 否 |
| 〃 | 〃 | **abort × local 385** | **(c) 并入V1-SSW-C2** | abort当拍`abort_seen`尚为0，`cal_has_owner`仍为1，置sticky；早一拍abort则`abort_seen=1`，不置。STOP不影响`cal_has_owner`，owner仍在途时照常置位，属(b)（S1修复语义：只诊断读出迟到，brief §3.5） | 同上 |
| `flag_ssw_fault_valid`（1431） | `flag_ssw_fault_rising`置1，否则0 | — | — | 单拍脉冲；`rising`含`!flag_blocking_fault`，已阻断时不发新valid，与调度器的同一episode语义一致 | 否 |
| `flag_ssw_fault_identity_valid`（1442）及6个身份寄存器（1464–1539） | start_restore清0 > [diag清0；rising时：commit_error ? 用i_adc_owner_*身份 : (done_mismatch && 在途 ? 用owner身份 : identity=0)] | commit_error × done_mismatch同拍 | (c) V1-SSW-C3（低） | commit_error优先作为身份来源，C09 §7.9没有规定选择规则；与调度器V1-SCH-C6同类。另外，rising由ready错配等无身份条件触发、同拍又有在途owner的done_mismatch时，取owner身份 | 断言或单元TB记录 |

## 2. (c)类发现详述

### V1-SSW-C1（高）双光SAR9：IR段覆盖RED段的三个SAR9使能，RED采样期间`o_en_sar9_iref/o_en_sar9_amb_low/o_en_sar9_dc_low`缺失

- **RTL证据**（`ppg_sar9_sar15_safe_selection_wrapper.v`）：
  - RED段，SAR9分支（655–664）：
    - `reg_control_next[CTRL_EN_9_IREF] = (tick>=236)&&(tick<308);`
    - `reg_control_next[CTRL_EN_9_AMB] = (tick>=256)&&(tick<310);`
    - `reg_control_next[CTRL_EN_9_DC] = (tick>=256)&&(tick<310)&&(type!=AMB);`
  - IR段，SAR9分支（705–714），在RED段之后执行：
    - `reg_control_next[CTRL_EN_9_IREF] = (tick>=396)&&(tick<468);`
    - `reg_control_next[CTRL_EN_9_AMB] = (tick>=416)&&(tick<470);`
    - `reg_control_next[CTRL_EN_9_DC] = (tick>=416)&&(tick<470)&&(type==NORMAL);`
  - 这三位都是**直接赋值，不是OR**。对照：同一块里IR的SAR15分支（695–700）和总线（711–714）都写成`reg_control_next[x] || …`或`| …`。
  - `flag_ir_wave_active`（412）在SAR9时为`ir_context_valid && tick∈[204,478)`；IR上下文在tick 160接管（398）。
- **逐拍**：双光（`OPTICAL_MODE_BOTH`），帧精度SAR9。tick 236–309期间RED与IR两个wave都有效：
  - RED段先写出RED窗口值1；
  - IR段再把同三位写成IR窗口的值，在这些tick上为0；
  - 最终`reg_control_vector`中这三位为0，`o_en_sar9_iref`、`o_en_sar9_amb_low`、`o_en_sar9_dc_low`在RED的整个窗口内都不出现。
  - IR窗口本身不受影响，RED-only模式也不受影响（没有IR上下文）。
- **与意图不符**：C09 §4.6：“`o_en_sar9_iref`、`o_en_sar9_amb_low`、`o_en_sar9_dc_low`以及其他SAR9控制仍使用各自独立颜色窗口”。SSW-44只检查`o_clk_iref_idac_sar9_low`与Q3（TB 974–983），单元TB和系统TB都没有在双光SAR9下检查这三个使能在RED窗口的值（grep：只有静态向量检查引用它们），所以回归不会发现。
- **后果**：NORMAL双光SAR9（精度窗口控制器可以把NORMAL切到SAR9）下，RED转换期间SAR9的IREF使能与AMB/DC IDAC使能缺失。实际后果取决于模拟侧：最坏情况是RED结果缺少环境光/直流抵消，或参考电流未建立，导致RED数据整体错误。数字链路无法检测。
- **IR上下文没能接管时**（launch超时），RED窗口恢复正常，所以单元TB若没有发IR波形就看不出问题。
- **建议**：
  - 单元TB：SAR9双光，RED在tick 0、IR在tick 160接管，逐tick在236–309检查三个使能等于RED窗口值，并用RED-only作对照；
  - 断言：`flag_red_wave_active && !reg_red_precision && tick∈RED窗口 → reg_control_vector[EN_9_*]==1`；
  - 芯片级：在双光SAR9下用netlist黄金向量逐tick比对全部72位控制字（C09 §4.6要求“逐tick来自已确认netlist”）。
- **修法参考（不修）**：IR的SAR9分支三行改为与RED结果OR，与SAR15分支一致。改后需要确认RED与IR窗口在这三位上不重叠：[236,310)与[396,470)不重叠，符合“无额外跨色重叠”的要求。

### V1-SSW-C2（低）STOP、abort与owner截止或local 385的诊断不一致

- **STOP**：落在接管之后、owner提交之前时，SSW仍在截止+1拍置`owner_deadline_timeout_sticky`，调度器则不置自己的sticky（调度器P1清pending）。软件同时读两路诊断时，会看到矛盾的结论。
- **abort**：
  - 正好落在截止+1拍（284/444/local 249）时，SSW置owner截止sticky；早一拍则不置（上下文已清）。
  - 正好落在local 385时，SSW置校准超时sticky；早一拍则不置（`abort_seen`已为1）。
- 这些sticky都是非阻断诊断（C09 §7.8），START清零，没有功能后果。C09 §8.2/§8.3没有说STOP或abort之后截止诊断是否应置位。
- 建议：合同写明“STOP或abort之后的截止诊断不作为异常指示”，或统一两模块的规则；单元TB扫描相应拍点。

### V1-SSW-C3（低）故障身份的选择规则没有依据

- 见1.5节。与调度器V1-SCH-C6同类，建议在C24或C09 §7.9统一写明多源同拍时的身份选择规则。

## 3. 待定项

| 编号 | 内容 | 需要的仿真 |
|---|---|---|
| V1-SSW-P1 | V1-SSW-C1对模拟前端的实际影响（缺失的是使能还是“低有效”的禁止电平，影响多大）只能由模拟侧确认。数字侧的波形偏差是确定的，不需要仿真即可确认 | 模拟/混合仿真：双光SAR9，比较RED样本在使能缺失与正确两种情况下的码值 |

## 4. 汇总

| 编号 | 级别 | 一句话 |
|---|---|---|
| V1-SSW-C1 | 高 | 双光SAR9中IR段覆盖RED段的`EN_9_IREF/EN_9_AMB/EN_9_DC`，RED窗口内三个使能缺失，违反C09 §4.6 |
| V1-SSW-C2 | 低 | STOP或abort落在截止或local 385附近时，SSW的owner截止sticky与校准超时sticky不一致，与调度器的结论也不同 |
| V1-SSW-C3 | 低 | commit_error与done_mismatch同拍时，故障身份按代码顺序选取，没有规则 |
| （并入V1-SCH-C3） | 低 | START与abort同拍：SSW按abort处理（`stop_pending=1`），调度器按START处理，两模块不一致 |

待定：V1-SSW-P1（C1的模拟后果）。

## 5. 合同与RTL差异记录（以RTL为准）

1. C09 §7.8：“非法commit、identity mismatch、无法归属的DONE…必须保持阻断，直到STOP/abort/reset或合同允许的空闲诊断清除”。RTL的`switch_protocol_error_sticky_o`、`transaction_mismatch_sticky_o`只由复位、`flag_start_restore`或空闲诊断清除清0，STOP/abort不清。合同的“直到STOP/abort”若理解为“STOP/abort即解除”，则与RTL不符；若理解为“至少保持到”，则一致。建议B批次澄清。
2. C09 §8.3：“如果异常收到匹配`success=1`（abort后），也必须释放物理owner，但该结果仍按丢弃处理并置协议诊断”。RTL中，abort后的匹配完成按`flag_owner_release`释放owner，但`flag_switch_protocol_error_condition`（450）不含“abort后success=1”这一项，SSW不置协议诊断。调度器与AMI是否置位见AMI文件。
3. C09 §8.2：“`i_stop_ack_event`到达后禁止新的`o_waveform_context_ready`和`o_adc_owner_ready`”。RTL在STOP当拍两个ready仍可能为1（`stop_pending`是寄存的），从下一拍起才禁止。由于调度器在STOP当拍已经屏蔽valid（S1），不会产生fire，属措辞差异。
4. C09 §4.6与RTL的差异即V1-SSW-C1。

## 6. 已覆盖的always块与寄存器清单（64个always块，全部覆盖）

| always起始行 | 目标 | 覆盖位置 |
|---|---|---|
| 521 | `adc_owner_inflight_o` | §1.4 |
| 534 | `reg_owner_q3_closed_o` | §1.4 |
| 547 | `calibration_timeout_sticky_o` | §1.5 |
| 563 | `owner_deadline_timeout_sticky_o` | §1.5 |
| 579 | `switch_protocol_error_sticky_o` | §1.5 |
| 595 | `transaction_mismatch_sticky_o` | §1.5 |
| 612 | `reg_control_vector` | §1.1 |
| 624（组合） | `reg_control_next` | §1.1 |
| 783 | `reg_run_active` | §1.2 |
| 796 | `flag_stop_pending` | §1.2 |
| 813、826、839、852、865、878、891、904、917、930、943、1213 | `reg_cal_amb_code`、`reg_cal_amb_epoch`、`reg_cal_color_ir`、`reg_cal_dc_code`、`reg_cal_dc_epoch`、`reg_cal_frame_id`、`reg_cal_frame_type`、`reg_cal_input_source`、`reg_cal_leddac_code`、`reg_cal_optical_mode`、`reg_cal_precision`、`reg_cal_generation` | §1.3 |
| 956 | `flag_cal_context_valid` | §1.3 |
| 974、987、1000、1013、1026、1039、1052、1065、1078、1091、1200 | `reg_ir_amb_code`、`reg_ir_amb_epoch`、`reg_ir_dc_code`、`reg_ir_dc_epoch`、`reg_ir_frame_id`、`reg_ir_frame_type`、`reg_ir_input_source`、`reg_ir_leddac_code`、`reg_ir_optical_mode`、`reg_ir_precision`、`reg_ir_generation` | §1.3 |
| 1104 | `flag_ir_context_valid` | §1.3 |
| 1122、1135、1148、1161、1174、1187、1226、1239、1252、1265、1278 | `reg_red_amb_code`、`reg_red_amb_epoch`、`reg_red_dc_code`、`reg_red_dc_epoch`、`reg_red_frame_id`、`reg_red_generation`、`reg_red_frame_type`、`reg_red_input_source`、`reg_red_leddac_code`、`reg_red_optical_mode`、`reg_red_precision` | §1.3 |
| 1291 | `flag_red_context_valid` | §1.3 |
| 1309 | `reg_owner_abort_seen` | §1.4 |
| 1324、1337、1350、1363、1372、1385、1398、1411 | `reg_owner_sample_index`、`reg_owner_generation`、`reg_owner_frame_id`、`reg_owner_cal_subframe`、`reg_owner_color_ir`、`reg_owner_frame_type`、`reg_owner_precision_mode`、`reg_owner_slot` | §1.4 |
| 1431 | `flag_ssw_fault_valid` | §1.5 |
| 1442 | `flag_ssw_fault_identity_valid` | §1.5 |
| 1464、1477、1490、1503、1516、1529 | `reg_ssw_fault_frame_id`、`reg_ssw_fault_sample_index`、`reg_ssw_fault_color_ir`、`reg_ssw_fault_frame_type`、`reg_ssw_fault_precision_mode`、`reg_ssw_fault_generation` | §1.5 |

合计：时序块63个（7+2+12+1+11+1+11+1+1+8+2+6），加上组合块624，共64个，与RTL中`always`关键字数（64）一致。
