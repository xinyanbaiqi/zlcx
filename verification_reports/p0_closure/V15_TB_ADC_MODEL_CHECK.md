# V15：TB中的ADC行为模型核对

- 分支：`p0-closure`（已合并 origin/main `bb3c1ab`），RTL/TB与main `c56296d`/`7a8eabf`相同。
- 方法：只读静态核对，无仿真器。按根目录`CLAUDE.md`加载`erie-verilog-generator` skill，按其existing-RTL分析流程逐模块阅读RTL与TB；本报告不修改任何RTL/TB。
- 合同语义以`git show origin/b-merge-batch:contracts/<文件>`为准；与RTL冲突时以RTL为准。
- 模拟侧事实（任务书§1，编号沿用）：F1 两个SAR ADC；F2 DONE上升沿=转换结束，**电平保持到下一次转换开始**；F3 完成后DOUT稳定；F4 物理空闲后无旧DONE；F5 DONE几乎不丢；F6 Q3→DONE上升沿 2~20拍。

---

## 0. 结论摘要

| 号 | 级别 | 结论 |
|---|---|---|
| **V15-N1** | **需修改（高，阻塞流片判断，须模拟侧先回答一个问题）** | 芯片顶层的物理空闲由`!CLK_STAGEx_DOUT_LOW`合成。若DONE按F2保持到"下一次转换开始"，而下一次转换在数字侧owner提交之后才开始，则形成循环依赖：idle=0 → owner不能提交 → Q1/Q2/Q3被抑制 → 没有下一次转换 → DONE不回落 → idle一直为0。RUN中会在第一笔完成后静默停采；STOP后STOPPING永远不能完成，约5000拍后supervisor报看门狗0x31，START也被挡住。所有TB用5拍宽的DONE短脉冲，DONE很快回到0，**这条路径在任何TB中都没有被触发**。见§2.1。 |
| V15-N2 | 需修改（中） | Q3→DONE时延在全部系统级TB中固定约2~3拍，2~20拍中的其余相位从未出现：DONE晚于SAR15 RED/IR波形末拍（d>8）、晚于SAR9或CAL波形末拍（d>17~18）、S2明显晚于S1。RTL结构上看没有发现依赖"完成早于波形末拍"的逻辑，但这些相位关系没有仿真证据。见§2.2。 |
| V15-N3 | 需修改（低） | 帧调度器单元TB的自动完成在owner提交后3拍给出，早于Q3（真实为Q3后2~20拍），所以单元层从未出现"RED owner跨越IR接管点160仍在途"的情形。系统TB已覆盖，所以只建议补充，不阻塞。见§3 M9。 |
| — | 保守差异，可保留 | control_top层19个TB共用的`drive_real_adc_done`（M1）在"短脉冲"和"转换期间idle=1"两点与真实不同，但在control_top层这两点不会掩盖问题（DONE被短脉冲化只会让捕获更难，idle由TB独立驱动，转换期间有`flag_adc_transaction_inflight`等在途标志挡住）。问题只在芯片层出现，即N1。 |
| — | 符合 | 捕获器单元TB（M7）、冗余校正器单元TB（M8）采用保持电平模型，并在下一事务前模拟ADC_RST拉低DONE，与F2/F3一致。 |

**需要用户（模拟设计者）回答的一个问题**（决定N1是真问题还是只是TB问题）：
> 在下一次转换中，`CLK_STAGEx_DOUT_LOW`被哪一个数字输出引脚的哪一个边沿拉低？它相对NORMAL RED/IR owner截止（宏帧tick 283/443）和CAL owner截止（local tick 248）早还是晚？STOP以后SSW进入安全态、不再产生任何波形，这时DONE会不会自行回落（例如在`EN_SAR9_IREF`、`EN_15SAR_LOW`等使能撤销时）？

---

## 1. RTL如何使用这些信号

### 1.1 完成信号：按电平采样，两级同步，每个事务只接纳一次
RTL：`rtl/ppg_adc_async_stage_capture/ppg_adc_async_stage_capture.v`；合同：C10 §6.4、§7.1（b-merge-batch），以及`contracts/PPG_ADC_IDAC_INTEGRATION_SPEC.md` §3.1、§5.2、§5.3（不在C01~C25内，作背景）。

- `flag_stage1_done_meta → flag_stage1_done_sync`、`flag_stage2_done_meta → flag_stage2_done_sync`：每路两级同步，**按电平采样**，没有边沿检测。
- `i_adc_transaction_start`（=AMI `o_transaction_start_fire`）同拍把四个同步寄存器清0，把`flag_capture_pending`置1，并锁存`reg_capture_mode`（9位等S1，15位等S2）。
- 接纳条件为`flag_capture_accept = flag_selected_done_sync && flag_capture_pending && flag_buffer_available && !i_adc_transaction_start`。接纳后`flag_capture_pending`清0，此后DONE即使一直为高也不会重复捕获。**捕获的"重新武装"只发生在下一次`i_adc_transaction_start`。**
- 锁存时机：在`flag_capture_accept`拍直接采样`i_dout_stage1_low/i_dout_stage2_low`（不同步），依赖F3"DONE有效期间DOUT稳定"。
- 反压：`flag_buffer_available=0`时`flag_capture_pending`保持，等DONE电平和缓冲同时就绪再接纳。**因此保持型DONE可以在长时间反压后被正确接纳；短脉冲DONE若在反压期间结束，这一笔就会被漏掉。**

### 1.2 物理空闲`i_adc_physical_idle`
- control_top层：外部输入，`flag_adc_physical_idle = i_adc_physical_idle`（`ppg_control_top.v:419`）原样扇出给五个消费者（C01 §6.2.1/扇出表）：
  - AMI `i_adc_idle`：`transaction_start_ready_o`要求`i_adc_idle`（`ppg_adc_measurement_idac_integration.v:986`）；作废判定`flag_owner_lost_fire`要求`i_adc_idle && !flag_capture_valid && !flag_adc_completion_pending`（`:954`）；`flag_precision_takeover_safe`（`:1010`）。
  - 调度器 `i_adc_idle`：`startup_idac_safe_boundary_o`、`flag_idle_idac_safe_boundary`、`o_scheduler_idle`（`ppg_400hz_frame_calibration_scheduler.v:479/482/580`）。
  - SSW `i_adc_idle`：`flag_start_restore`、`o_wrapper_idle`（`ppg_sar9_sar15_safe_selection_wrapper.v:449/494`）。
  - manager（经ACTIVE wrapper）：`flag_start_ready`和`flag_stopping_complete = i_adc_idle && i_datapath_empty && i_idac_idle && i_analog_safe`（`ppg_system_config_manager.v:453/466`）。
  - supervisor：看门狗`flag_watchdog_window_active = i_stop_episode_active && !i_adc_physical_idle && ...`，连续`C_ADC_DRAIN_WATCHDOG_CYCLES=5000`拍非idle时报cause 0x31（`ppg_system_fault_abort_supervisor.v:56/193/194`）。
- 合同语义：C10 §6.4 `i_adc_idle`为"模拟ADC当前无转换且DONE已回到可启动状态"；C09 `i_adc_idle`为"物理ADC转换与Stage1/Stage2 DONE/CLK_DOUT返回均非活动"；manager端口注释为"当前无ADC转换且两个DONE均已回低"。也就是说，**合同要求DONE先回低，才算空闲、才能开始下一事务**。
- 芯片层（`rtl/ppg_chip_digital_top/ppg_chip_digital_top.v:290/348-359/521`）：`w_idle_mux_async = o_active_precision_mode ? !CLK_STAGE2_DOUT_LOW : !CLK_STAGE1_DOUT_LOW`，经`reg_idle_sync_meta → reg_idle_sync_stable`两级同步后接`i_adc_physical_idle`。按芯片合同§3③和C01 V1.11冻结公式实现。芯片合同§11.3和TB注释（`tb_ppg_chip_digital_top.v:1120-1125`）明确写着：该公式按"DOUT**选通脉冲**的取反，不在选通期间就恒为1"来理解。**这与F2矛盾。**

### 1.3 owner生命周期（C10 §7.1a，AMI V1.17/V1.18）
- 作废：`cnt_owner_age >= 4500`，且同拍物理空闲、捕获缓存空、无待发布完成。同槽连续作废达到k=2次时为cause 06；owner年龄达到9000且一直不空闲时为cause 07。
- 作废时`.i_transaction_abandon(flag_owner_lost_fire)`让冗余校正器丢弃迟到RAW（AMI V1.18）。
- 作废前1~2拍的同步链窗口：作废判定看的是`flag_capture_valid`（捕获后一拍才为1），不看捕获器内部的`flag_selected_done_sync`。芯片层中，idle同步器和捕获同步器是两个独立的两级同步器，采同一个DONE引脚；两者分辨结果可能差1拍。如果idle同步器慢1拍，同一拍会同时发生"作废"和"接纳"，迟到结果由冗余校正器的作废丢弃路径吃掉。control_top层TB用`sys_done_keep_idle`/`olr_done_keep_idle`（idle保持为1、只拉DONE）覆盖了"idle完全不随DONE变化"这个极端，可以认为覆盖了该窗口。

### 1.4 时序锚点（C09 §4.2~§4.5）
- owner截止：RED为宏帧tick 283，IR为443，CAL为local tick 248（"最早SAR15 Q1窗口开始前一拍"或"AMB后段控制窗口开始前一拍"）。
- 截止前未提交owner时，**Q1/Q2/Q3、LED有效采样和结果接纳都被抑制**，预建立安全收尾；owner截止超时只记为非阻断诊断，不报故障（C09 §4.5、SSW-38）。
- 波形末拍（`ppg_sar9_sar15_safe_selection_wrapper.v:414-416`）：RED为307（SAR15）或317（SAR9），IR为467或477，CAL为283。波形末拍只释放波形上下文，不释放owner（`:1299`、`:436`）。
- 可能是"转换开始"的控制边沿全部在owner截止之后：CAL的`o_clk_aferst_low`在[249,261)，`o_clk_9q1_low`在[259,268)；NORMAL的SAR15 Q1从tick 284起。在截止之前出现的只有预建立类输出，例如CAL的`o_clk_iref_idac_sar9_low`[10,284)、`o_en_sar9_iref`[202,274)，以及NORMAL的SAR9包络（RED从tick 44起）。

---

## 2. 专项判断

### 2.1 短脉冲代替保持电平：芯片层空闲判定从未被真实触发（V15-N1）

**推导**（静态推导，未仿真）。假设F2成立，并假设DONE回落是由某个在owner提交之后才出现的控制边沿（Q1、AFERST或Q3）引起的：
1. 第1笔事务正常：上电时DONE=0，idle=1，owner提交，转换完成，DONE=1。
2. DONE保持为1，芯片层`reg_idle_sync_stable=0`。
3. 下一笔事务：AMI `transaction_start_ready_o`要求`i_adc_idle=1`，不成立，owner截止前一直无法提交。
4. 到截止时SSW抑制Q1/Q2/Q3，不会开始下一次转换，DONE一直不回落，回到第2步。每一帧都只记一次非阻断的owner截止超时，系统不报故障，**静默停采**。这与`tb_ppg_control_top_owner_identity_backpressure.v:1163/1355`、`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v:1138`中"idle持续为0跨过owner截止"的行为一致；这些control_top场景已经证明此时只有非阻断诊断。
5. STOP：`flag_stopping_complete`要求`i_adc_idle`，而STOP后没有新波形，DONE不会回落，所以STOPPING永远不能完成。supervisor看门狗在第5000个非idle拍报cause 0x31，经abort升级；之后idle仍为0，`flag_start_ready`也要求`i_adc_idle`，**START同样被挡住**。数字复位不能复位模拟侧的DONE。
6. 即使DONE回落发生在owner截止之前（例如由预建立使能引起），第5条仍然成立，除非STOP后DONE也会自行回落。

**为什么TB没有发现**：芯片TB `drive_real_adc_done`（`tb_ppg_chip_digital_top.v:400-414`）让DONE为高5拍后拉低。拉低后芯片层idle 2拍内就回到1，第3~5步都不可能出现。TC6已经观察到"STOPPING一旦被接受，`i_adc_idle`这一路几乎立即满足"，芯片合同V1.12按"选通脉冲"解释把它结案。按F2，这个结论的前提不成立。

**涉及的RTL路径**（TB中从未在"保持型DONE"下被真实触发）：芯片层空闲合成器（`reg_idle_sync_stable`）、AMI `transaction_start_ready_o`的`i_adc_idle`项、manager `flag_stopping_complete`/`flag_start_ready`的`i_adc_idle`项、supervisor看门狗、调度器`startup_idac_safe_boundary_o`/`o_scheduler_idle`的`i_adc_idle`项。

**捕获器重新武装**不受影响：武装只看`i_adc_transaction_start`。保持型DONE在start拍被清掉同步历史，按C10要求"start前DONE已回低"，不会重复接纳。

**建议**（只给建议，不改TB/RTL）：
- 先由模拟侧回答§0中的问题。
- TB：芯片TB新增保持型DONE模型。DONE在Q3后d拍上升，一直保持到模拟侧确认的那个回落边沿（由TB监视对应的芯片输出引脚来驱动），DOUT在此期间稳定。新增两个场景：
  - (a) 连续RUN两帧以上，检查每笔都有结果、无owner截止超时；
  - (b) 完成后STOP，检查在合理时间内回到CONFIG、不报0x31，然后能重新START。

  按当前RTL，预计(a)(b)至少有一项失败，具体取决于模拟侧的回答。
- RTL（交统筹/用户决定，本会话不修）：如果模拟侧确认DONE只在下一次转换开始时回落，那么`!CLK_STAGE_DOUT_LOW`不能作为"物理空闲"。可选方向：
  - ① 改合成公式，例如"DONE上升并被接纳之后即视为空闲"，不再要求DONE回低，同时保留C10"start前同步历史清零"的保护；
  - ② 让模拟侧在owner截止前、以及STOP安全态时提供ADC_RST；
  - ③ 增加独立的ADC_RST/BUSY引脚（芯片合同V1.12曾否决新增引脚）。

  无论选哪一种，C10 §6.4、C09 `i_adc_idle`语义和芯片合同§3③都要一并修订。

### 2.2 固定约1拍时延：2~20拍中的其余相位从未出现（V15-N2）
- 实际时延：各TB的bg_responder在Q3为高时等待Q3回到0（`wait_q3_release`或`bg_adc_responder`），再进入`drive_real_adc_done`，等下一个下降沿后拉高DONE。以CAL为例，Q3窗口为[265,267)、中心为266，DONE约在267.5~268.5拍上升，**即约Q3+2~3拍**。在F6区间中只覆盖了下限附近。
- 只在故障场景中出现过的大时延：`rsp_red_delay_tick=400`（RED迟到到tick 400）、`rsp_cal_delay_*`（CAL推迟到local tick 400或600）、busy变体（不发DONE）。这些都属于迟到或丢失故障，远大于20拍。
- 从未出现的相位：

| 相位关系 | 需要的d | 可能影响 | RTL静态判断 |
|---|---|---|---|
| SAR15 RED/IR的DONE晚于波形末拍307/467 | d>7~8 | 波形上下文先释放，owner仍在途 | 上下文与owner独立（`:1299`、`:436`），未见依赖 |
| SAR9 RED/IR的DONE晚于317/477 | d>17 | 同上 | 同上 |
| CAL的DONE晚于CAL_WAVE_END 283/284 | d>17 | `flag_cal_q3_end_passed`之后owner仍在途；与IDAC提交tick 385之间的余量从约115拍减为约98拍 | 未见依赖；余量仍足够 |
| 15位S2比S1晚许多拍 | — | S1保持为高、S2尚为低时的捕获与idle | 捕获只等S2；芯片层SAR15的idle只看S2；捕获器单元TB已覆盖（S1领先4拍） |
| RED的DONE在d=20时到达，IR owner提交被推迟 | d≈20 | IR截止为443，余量约120拍 | 足够 |

- 判定：没有发现会因此出错的RTL结构，但这些相位都没有仿真证据，列为"需修改（中）"。
- 建议：bg_responder的时延改为可配置，在{2, 8, 9, 18, 19, 20}拍上各跑一轮主回归，至少覆盖SAR15与SAR9双光、以及校准启动搜索；15位事务让S2比S1晚若干拍。与N1的保持型模型一起实现最省。

### 2.3 短脉冲对捕获反压路径的影响（保守差异）
- 5拍短脉冲在反压超过约3拍时会被漏掉，真实保持电平则不会。所以短脉冲比真实情况**更严**，只可能多报丢失，不会掩盖错误。保持电平下"反压后接纳"的路径由捕获器单元TB（M7第61~77行、137~147行）覆盖。可保留。

---

## 3. 模型逐项核对

列表列出了所有驱动`i_clk_stage[12]_dout_low_async`、`i_dout_stage[12]_low`、`i_adc_physical_idle`、`CLK_STAGE*_DOUT_LOW`、`DOUT_STAGE*_LOW`的TB代码和`.vh`（`legacy/`除外）。扫描脚本见附录A。

第3步各检查点的含义：
- ①DONE形态；
- ②DOUT稳定；
- ③空闲后有无旧DONE；
- ④Q3→DONE时延；
- ⑤idle与DONE、DOUT的关系。

### M1 control_top通用`drive_real_adc_done`（19个TB逐字相同，task体md5前缀`dc6a0770`）
- 位置：每个TB各自有一份，例如`tb_ppg_control_top.v:749`、`tb_ppg_control_top_adc_anomaly.v:597`。
- 使用它的TB：`tb_ppg_control_top`、`_adc_anomaly`、`_adc_numeric_scoreboard`、`_baseline_cross`、`_fir_tail_isolation`、`_idac_bus_isolation`、`_injection`、`_input_light_static_matrix`、`_lifecycle_fault_adc_anomaly`、`_long_10_cycles`、`_longrun`、`_no_recheck_control`、`_normal_slow_tracking`、`_owner_identity_backpressure`、`_peak_valley_return`、`_periodic_recheck_recovery`、`_robustness_corner_waveforms`、`_startup_idac_calibration`、`tb_diag_algo_probe`。一般由各TB的bg_responder在`wait_q3_release`后调用。`tb_ppg_jnt_baseline_prefix.vh`、`tb_ppg_real_raw_generator.vh`不驱动DONE。
- 行为：在下降沿后+2ns拉低idle，+4ns给DOUT，+6~7ns拉高S1 DONE；`precision_mode`为1时S2 DONE同时拉高。保持5个下降沿后拉低S1/S2 DONE，最后把idle拉回1。
- ①5拍短脉冲（**不符合F2**）。②DOUT在DONE期间不变，下一次调用前也不变（符合F3）。③正常路径不产生旧DONE（符合F4）。④约Q3+2~3拍（落在F6下限，见N2）。⑤idle只在DONE脉冲期间为0，转换期间（Q3→DONE）为1；与C09/C10"无转换且DONE已回低"的语义不同，但与芯片公式`!DONE`在短脉冲下的结果一致。
- 判定：**control_top层属于保守差异，可保留**。理由：
  - control_top层的idle由TB独立驱动，与DONE形态无关；
  - 转换期间idle=1会被`flag_adc_transaction_inflight`、`B_INFLIGHT`、`adc_owner_inflight_o`挡住，AMI start、调度器边界、manager STOPPING（经`i_datapath_empty`包含`o_adc_chain_idle`）都不会误放行；
  - 短脉冲只会让捕获更严。

  但它是N1、N2的根源：芯片TB照抄了同一形态。
- 建议：保留现有模型作为"短脉冲压力"变体，另外增加保持型变体（见N1、N2），idle改为由TB按芯片公式从DONE推出。

### M2 芯片层`drive_real_adc_done`（`tb_ppg_chip_digital_top.v:400`，只用于芯片TB）
- 行为与M1相同（5拍短脉冲），只驱动引脚；idle由DUT内部合成。
- ①短脉冲（**不符合F2**）。②符合F3。③TC4a/TC4b（`:938-955`、`:1056-1072`）在没有owner时直接翻动`CLK_STAGE1/2_DOUT_LOW`来测试idle二选一，这是**刻意构造的无owner DONE**；TB注释承认它会被AMI当作身份不匹配的DONE吞掉，随后用STOP加重建现场来清理。④约Q3+2~3拍。⑤idle=!DONE，短脉冲下idle只为0约5拍。
- 判定：**需修改（高）**，即V15-N1，会掩盖芯片层"保持型DONE使idle长期为0"的全部后果。
- 建议：见§2.1。TC4a/TC4b可保留，但最好放在独立复位的子序列中，避免污染后续场景。

### M3 `tb_ppg_control_top_adc_anomaly.v`中的`bg_adc_responder`故障变体（`:1115-1210`，在M1基础上）
- skip/drop/dead（不发DONE）、`rsp_red_delay_tick`/`rsp_cal_delay_*`（DONE迟到数百拍）、busy变体（idle=0持续跨帧且始终不发DONE，`:1143-1160`）。
- ①短脉冲。②符合F3。③不产生旧DONE。④迟到变体属于"迟到故障"，刻意超出F6。⑤busy变体是"ADC忙而无DONE"，用于cause 07；在芯片层这种情况无法构造（OLR §7.1(e)，已知）。
- 判定：保守差异（故障注入），可保留，并标注为刻意构造。

### M4 `sys_done_keep_idle`（`tb_ppg_control_top_adc_anomaly.v:1346`）与`olr_done_keep_idle`（`tb_ppg_adc_measurement_idac_integration.v:723`）
- idle保持为1，只拉DONE 5拍，模拟作废窗口附近才到的迟到DONE。
- ③属于刻意构造（F4、F5下几乎不会发生）。⑤与芯片公式`idle=!DONE`矛盾。但这正好覆盖了§1.3中"idle同步器比捕获同步器慢"的极端情况。
- 判定：保守差异（故障注入），可保留。

### M5 只扰动idle的场景（不动DONE）
- `tb_ppg_control_top_owner_identity_backpressure.v:1163/1236/1355`：idle=0跨过或不跨过RED/IR owner截止。
- `tb_ppg_control_top_lifecycle_fault_adc_anomaly.v:1138/1577-1656`：同上，以及竞态窗口保持。
- `tb_ppg_control_top_startup_idac_calibration.v:796-805`：截止抑制。
- `tb_ppg_jnt_baseline_prefix.vh:772-800`（JNT-09）：ADC不可用。
- `tb_ppg_control_top.v:1737-1743`（SMOKE-10）：idle抖动。
- `tb_ppg_control_top_adc_anomaly.v:1667-1678/1847`。

判定：都是"物理忙而无DONE"的刻意场景，在芯片层（idle=!DONE）中无法构造，可保留。另外，它们正好给出了N1第4步"idle持续为0跨过owner截止时只产生非阻断诊断"的行为证据。

### M6 AMI单元TB `drive_adc_done`（`tb_ppg_adc_measurement_idac_integration.v:879`）
- 与M1同形，驱动`i_adc_idle`，在下降沿后立即动作，无ns偏移；单元层不建模Q3。
- 判定：保守差异，可保留（单元层不建模Q3→DONE时延）。建议在其中加一个"DONE保持到下一笔start前若干拍才回低"的用例，覆盖"长保持DONE加反压后接纳"在AMI集成层的路径。

### M7 捕获器单元TB（`tb_ppg_adc_async_stage_capture.v:86-318`）
- 保持电平模型：DONE保持到"模拟ADC_RST"（TB在下一次`i_adc_transaction_start`前把DONE和DOUT清0）。覆盖以下内容：
  - 无事务时的伪DONE；
  - 9位模式下的非选中S2；
  - DONE持续为高时反压不重复捕获；
  - 15位模式S1领先S2 4拍；
  - 缓冲满时到达的新DONE；
  - 异步相位扫描（`cnt_phase_delay`）；
  - 复位。
- ②第61行在DONE为高期间改动DOUT，用于验证缓存已与模拟端隔离，属于**刻意违反F3的隔离检查**。
- 判定：**符合**。

### M8 冗余校正器单元TB（`tb_ppg_adc_s1_redundancy_corrector.v:133-600`，内部例化真实捕获器）
- 保持电平模型：每笔事务前"模拟ADC_RST"拉低DONE，S1先于S2，包含"旧结果阻塞时启动下一事务"。
- 判定：**符合**。

### M9 帧调度器单元TB自动完成（`tb_ppg_400hz_frame_calibration_scheduler.v:338-364`）
- 抽象完成事件：`o_adc_owner_commit_event`后3拍给出`i_adc_transaction_complete_event`；此期间`i_adc_idle=0`、`i_sar_timing_idle=0`。
- ④完成在owner提交后3拍，**早于Q3**（RED提交不晚于283，Q3为300）。真实情况下RED owner在tick 160（IR波形接管）到约320之间一直在途。
- 判定：**需修改（低）**，即V15-N3。单元层从未出现"RED在途跨越IR接管"和OLR F-3附（调度器tick≥160放行IR与SSW 283后认IR的不一致）。系统TB已覆盖，所以不阻塞。建议把自动完成的时延改为"Q3坐标+d"。

### M10 其它只驱动抽象idle电平、不含DONE的模块TB
`tb_ppg_system_fault_abort_supervisor.v`（`i_adc_physical_idle`）、`tb_ppg_system_config_manager.v`、`tb_ppg_sar9_sar15_safe_selection_wrapper.v`、`tb_ppg_precision_window_integration.v`、`tb_ppg_active_v4_control_plane_integration.v`、`tb_ppg_amb_recheck_scheduler.v`（`i_adc_idle`）。这些TB把idle当作静态或场景电平，不建模ADC，不在F1~F6的核对范围内。它们本身没有问题；N1的后果由芯片层场景暴露，不在这里。

---

## 4. "需修改"汇总

| 号 | 模型/文件 | 掩盖的场景 | 建议（不改TB，仅建议） |
|---|---|---|---|
| **V15-N1（高）** | M2 `tb_ppg_chip_digital_top.v` `drive_real_adc_done`；根源是M1的形态 | 芯片层保持型DONE使`reg_idle_sync_stable`长期为0：RUN中owner无法提交、静默停采；STOP后STOPPING不能完成、0x31、START被挡。属于RTL与合同层面的循环依赖（芯片合同§3③、C01 V1.11公式、C10 §6.4 `i_adc_idle`语义），不只是TB问题 | 先由模拟侧回答§0的问题；芯片TB增加保持型DONE模型和"连续RUN""完成后STOP→重新START"两个场景；RTL修改方向见§2.1，交统筹和用户决定 |
| V15-N2（中） | M1、M2的bg_responder时延 | Q3→DONE时延3~20拍的相位：DONE晚于波形末拍、CAL晚于283、S2晚于S1 | 时延参数化，在{2,8,9,18,19,20}拍上回归；15位时让S2晚于S1 |
| V15-N3（低） | M9调度器单元TB | 单元层RED在途跨越IR接管点 | 自动完成时延改为相对Q3坐标 |

保守差异、可保留：M1（control_top层）、M3、M4、M5、M6。符合：M7、M8。

---

## 附录A：模型扫描方法
- 用一个只读Python脚本（放在会话scratchpad，不入库）逐文件匹配对上述信号的过程赋值（`=`/`<=`），按所在的`task`/`always`/`initial`分组，并逐TB计算`drive_real_adc_done`去除注释和空白后的md5，以确认19个control_top TB的task体逐字相同、芯片TB的task体不同（md5前缀`32b82103`）。
- 已排除`legacy/`。`tb_ppg_real_raw_generator_selfcheck.v`不驱动这些信号。
