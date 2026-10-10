# V9：TB容差、PASS与超时清点（只读）

日期：2026-10-10。源码基线：main `bb3c1aba12474638fcbefd9b1f324ecfc7524544`；任务书所写 `c56296d` 之后的 main 增量为任务文档。合同语义基线：`origin/b-merge-batch`，本次读取时提交见 `PROGRESS.md`。分支：`v9-v16`。

## 高风险项先读

| ID | 位置 / 检查标签 / 符号 | 风险与建议 |
| --- | --- | --- |
| U01 | `rtl/ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v`，PRC-05，引用RGC-06 | 本次没有比较就打印PASS，引用旧日期不能证明当前源码；改为INFO/CITATION，由同基线RGC日志完成证据链接。 |
| U02 | 同文件，PRC-08，引用INJ-03 | 不读取当前INJ-03结果仍打印PASS，且新合同PRC-08包括FIR历史及检测副作用，不能把旧引用扩张为完整闭合；建立当前联合/芯片日志证据链接并逐项复核。 |
| U03 | `rtl/ppg_chip_digital_top/tb_ppg_chip_digital_top.v`，TC6，`mr_latch_after/dd_latch_after` | 翻转位不变和变化两支都PASS，局部判据覆盖全部结果；在明确的场景预期下比较，窄窗口未命中记录观察/未覆盖。 |
| V01 | `rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v`，AMI-24，`o_wrapper_fault_blocking` | `!fault || !ready`允许从未故障直接通过；先确认真实阻断发生，再尝试start并核算无fire及恢复行为。 |
| T18 | robustness TB，PRC-09，`reg_unqualified_after_injection_count` | 只要求大于0，合同要求包含失资格样本的每个窗口都失资格；按同色21笔队列逐窗计算，不能用“出现过一笔”代替全部窗口。 |
| R01 | `rtl/ppg_control_top/run_xsim_regression.sh`，`pass_count/fail_count/finished` | 仅写summary，没有最终验收或失败退出，编译失败/提前finish/零PASS也不会由脚本形成失败状态；加入逐TB终判和聚合退出码。 |
| R02 | `rtl/ppg_chip_digital_top/run_xsim_regression.sh`，同符号 | 与R01同类；芯片TB缺最终横幅也没有拒绝，必须核对退出码、结束及最终成功横幅。 |

以上是验证证据风险，**不是已经证明的RTL错误**。静态发现未用变异或仿真确认；建议均未实施。

## 汇总计数与覆盖口径

按“不同检查机制/标签族”计数，复制到多个TB的同一机制合为一条，逐条列出全部已定位副本；不是PASS文本行数，也不是RTL缺陷数。

| 类别 | 高 | 中 | 低 | 合计 |
| --- | ---: | ---: | ---: | ---: |
| 容差/宽松判据 T01–T18 | 1 | 13 | 4 | 18 |
| 无条件或穷尽分支PASS U01–U03 | 3 | 0 | 0 | 3 |
| 空真/证据范围不足 V01–V03 | 1 | 2 | 0 | 3 |
| 静默超时及其已防护对照 W01–W05 | 0 | 3 | 2 | 5 |
| 回归判定 R01–R03 | 2 | 0 | 1 | 3 |
| 同沿计数更新/读取竞争 Q01–Q02 | 0 | 2 | 0 | 2 |
| 当前清点总数 | **7** | **20** | **7** | **34** |

H01为历史已修项，另计1条，不混入当前未处置项。低风险条目中包括合同本来就规定的区间/最大时延，以及有明确失败兜底的等待；**34条不等于34个需要修复的缺陷**。无条件引用PASS有2处实际 `$display`；U03是2个穷尽分支的实际 `$display`，不能误称整个芯片TB无条件通过。

范围为49份 `rtl/**/tb_*.v`（系统20、芯片1、模块28）和control_top的2份 `.vh`，另读3个指定回归脚本；`legacy/`未扫描。全部文件的SHA256、formatter结构结果与候选数见 `V9_SOURCE_COVERAGE.json`；原文导航见 `V9_SCAN_CANDIDATES.tsv`，7023条候选包含NBA赋值、诊断和正常边界，不自动当成发现。

技能路径：`.claude/skills/erie-verilog-generator/`，使用其 `quality.formatter_ast.build_ast_report_for_path`，未另建Verilog解析器。现有TB的部分clock/named always写法使formatter报 `always header normalization failed`，部分初始块也超出该parser模型；无module的头文件不能作为完整module AST验证。诊断原样保留，人工读取原文检查条件、调用方、存在性与最终终判，**不声称AST全通过**。

交付矩阵：`compile/ast`只提供静态结构尝试及其限制；`readability/comment/naming/profile`对新增RTL不适用（没有新增/修改RTL）；`testbench`为只读证据审阅；`toolchain`原静态清点阶段未运行仿真；后续Q01/Q02以仓库外Icarus 11 / XSIM 2019.2实验确认，实际TB/RTL未修改。原静态阶段的技能依赖预检缺少remote SSH/FPGA开发技能，未使用远端或Vivado流程，也未安装这些依赖；后续定因实验使用本机已有的XSIM 2019.2。

## 合同缩写（全部取自B分支）

| 缩写 | 合同文件 |
| --- | --- |
| RAW | `contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md` |
| FIR | `contracts/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md` |
| PVW | `contracts/PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md` |
| BSL | `contracts/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md` |
| AMI | `contracts/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` |
| FSC | `contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md` |
| IDC | `contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md` |
| PWI | `contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` |
| CHIP | `contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md` |

下文缩写+节号即对应上述具体文件。位置以文件、标签、符号为主，行号只是本基线导航。

## 容差与宽松判据

### T01（中）：理论原始波峰±11帧

- 位置：`rtl/ppg_control_top/tb_ppg_control_top_{baseline_cross,peak_valley_return,fir_tail_isolation,long_10_cycles}.v`，`GROUP1_PVW17_CHECK_B`，`frame_diff/C_GROUP_DELAY_TOLERANCE_FRAMES`（常量11）。花括号表示4个实际文件，非glob文件名。
- 判据原文：`if(frame_diff < 0) frame_diff = -frame_diff;`；失败条件 `if(frame_diff > C_GROUP_DELAY_TOLERANCE_FRAMES)`。理论帧由 `(this_peak_frame_id_signed / C_RAW_PULSE_PERIOD_FRAMES) * C_RAW_PULSE_PERIOD_FRAMES + C_RAW_RISE_END_FRAME_RED`产生。
- 依据：FIR §4/§8/§10.2，PVW §4.2、§16 PVW-17，RAW §9.2。合同固定中心身份，但未规定“原始转折±11”作为精确身份豁免。
- 能否精确：可以对真实同色21笔输入独立滤波、定点舍入并按PVW资格/平台规则求峰；不能简单把原始波形转折当滤波后唯一峰。
- 风险/建议：当前范围可吸收错误减10帧、局部身份漂移；循环编号又来自被检查的峰帧，可能吸收整周期错绑。保留原始波形范围作为健全性检查，另做精确中心身份与独立周期关联。

### T02（中）：事件到达帧只要求至少晚10帧

- 位置：与T01同4文件，`GROUP1_BSL04_CHECK_A/GROUP2_BSL04_CHECK_A`，`this_live_frame_id/this_peak_frame_id_signed/this_cross_frame_id_signed`。
- 判据原文：失败条件 `(this_live_frame_id - this_peak_frame_id_signed) < C_FIR_GROUP_DELAY_SAMPLES`；CROSS分支同式换为 `this_cross_frame_id_signed`。
- 依据：FIR §8/§10.2、PVW §4.2、BSL的中心样本身份条款，RAW §9.2。
- 能否精确：中心身份可以；墙钟到达帧与极值帧之差包括检测确认及握手等待，不能强制等于10。
- 风险/建议：没有上界可放过额外延迟或再减10帧。将“中心元数据精确匹配”和“事件等待合同上界”分开核对，保留>=10仅作辅助。

### T03（中）：SAR15中心身份只落在大区间

- 位置：`rtl/ppg_control_top/tb_ppg_control_top_{peak_valley_return,fir_tail_isolation,long_10_cycles}.v`，`GROUP3_CENTER_SAMPLE_IDENTITY`，`reg_sar15_entry_frame_id/reg_last_real_red_sar15_frame_id`。
- 判据原文（PEAK失败分支）：`o_peak_frame_id < reg_sar15_entry_frame_id` 或 `o_peak_frame_id > reg_last_real_red_sar15_frame_id`；VALLEY对应 `o_valley_frame_id`。另有真实SAR15样本存在性前提。
- 依据：PVW §4.2要求保留真实中心样本的frame/sample/epoch/precision；RAW §9.2第3组要求bound center identity。
- 能否精确：可用输入队列及峰谷模型绑定frame、sample、颜色、epoch。
- 风险/建议：这是合同要求的必要范围检查，不能证明区间内取对了那一笔；将区间检查和逐字段精确比对并存，不宣称区间本身已证明完整身份。

### T04（中）：正常返回元数据只要求不早于谷帧

- 位置：T03同3文件，`GROUP3_RETURN_REQUEST`，`effective_valley_frame_id/valley_confirmed_same_cycle`。
- 判据原文：失败条件 `o_return_frame_id < effective_valley_frame_id`；PASS打印 `frame_id ... >= confirmed_valley_frame_id`，另检查 `reason == 2'b00`及已确认谷值。
- 依据：PVW §10.3/§11.4要求返回握手前保持原因和绑定谷元数据，RAW §9.2第3组。
- 能否精确：可与对应谷事件完整快照精确比；实际精度提交帧仍按安全边界另算。
- 风险/建议：错误绑定稍晚帧也可过；不能混淆“请求绑定谷帧”与“实际返回提交帧”，分别核对。

### T05（中）：启动搜索码只核对min/max

- 位置：`rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v`，AMI-14/15，`o_amb_code/o_dcs_r_code/o_dcs_ir_code`。
- 判据原文：`check_case("AMI-14", o_startup_search_complete && (o_amb_code >= i_amb_code_min) && (o_amb_code <= i_amb_code_max));`；AMI-15对两色DC分别使用 `>= *_code_min`、`<= *_code_max`。
- 依据：AMI §11.3/§17 AMI-14/15，IDC §8.2/§9/§10，要求请求、颜色、快照、epoch、搜索顺序闭合。
- 能否精确：本TB固定样本响应可推导候选提交轨迹、终码和epoch。
- 风险/建议：任意合法区间内错误码或跳阶段不能由这两句拒绝；保留边界安全检查，追加独立候选序列及每阶段握手次数。不能拿该范围检查替代合同AMI-14/15全部语义。

### T06（中）：AMI丢失事件年龄4500–4502

- 位置：AMI TB，`LOST-FIRE`，`cnt_olr_age_at_lost`，约2036行。
- 判据原文：`(cnt_olr_age_at_lost >= 4500) && (cnt_olr_age_at_lost <= 4502)`。
- 依据：AMI §7.1a：`cnt_owner_age >= 4500`条件在裁决拍成立，下一拍公开lost_event；条件还包括idle/capture/pending等。
- 能否精确：在该无DONE、idle=1的定向场景可以；须以start fire、裁决拍、公开脉冲和TB观测沿分开计算。
- 风险/建议：多放宽1–2拍会隐藏计龄或脉冲延迟错误；记录基于采样区的精确偏移，不把4500–4502当合同范围。

### T07（中）：系统丢失年龄4500–4504

- 位置：`rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v`，`SYS-LOST-RED`，`cnt_lost_age`，约1511行。
- 判据原文：`(cnt_lost_age >= 4500) && (cnt_lost_age <= 4504)`；另有 `reg_lost_mtick < 13'd4999`及身份/原因/计数等检查。
- 依据：AMI §7.1a，FSC §10.4，RAW §9.4.9。
- 能否精确：可以依据系统各注册阶段和实际监视沿推导单一预期观测年龄。
- 风险/建议：4拍窗口宽于叶模块判据，可能掩盖Top传播延迟；各层单独列时序表，其他身份检查保留。

### T08（中）：JNT等待器接受超额计数

- 位置：`rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh`，`JNT-OWNER-WAIT/JNT-DONE-WAIT`，`jnt_wait_owner_commit_count/jnt_wait_completion_count`；影响包含该头文件的系统TB。
- 判据原文：`cnt_jnt_owner_commit >= expected_count`、`cnt_jnt_completion >= expected_count`。
- 依据：FSC §10.3/§10.4/§18唯一owner/完成，RAW §9.1及JNT规格。JNT最终子检查条数使用 `C_JNT_REQUIRED_SUBCHECKS=54`，是另一个精确总数门，不等价于owner次数门。
- 能否精确：定向单事务的delta可精确，后台自由运行场景应按身份/时间窗口核算。
- 风险/建议：重复事件可以让等待提前结束，之后只有部分场景另做==比较；等待可继续用>=，正式断言须验证窗口内准确增量及身份，不能一刀切把所有等待改==。

### T09（中）：FSC事件次数“至少一次”

- 位置：`rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v`，FSC-13/47/48/50/53，`cnt_idac_boundary/cnt_startup_boundary/cnt_frame_start/cnt_cal_boundary/cnt_done`。
- 判据原文摘录：FSC-13 `(cnt_idac_boundary >= 1) && (cnt_startup_boundary == 1)`；FSC-47 `(cnt_startup_boundary >= 1) && (cnt_frame_start >= 1)`；FSC-48 `cnt_cal_boundary >= 1`；FSC-50 `cnt_done >= 1`；FSC-53 `(cnt_startup_boundary >= 2) && (cnt_frame_start >= 1)`。
- 依据：FSC §8.2/§8.3/§12/§18。§8.3每START最多一个启动边界，§12完成脉冲单拍。
- 能否精确：每START启动边界应精确；正常多帧边界需依据实际观察窗口计算。
- 风险/建议：跨RUN累积计数/重复脉冲可被“至少”吸收；用每START和每owner的独立差分计数，不把自由运行的所有边界一概限定为1。

### T10（中）：FSC取消到idle的宽窗口

- 位置：同FSC TB，`CAL-ROLLOVER-ABORT/CAL-ROLLOVER-STOP/RESTART-STOP-SCAN/RESTART-ABORT-SCAN`，`cnt_rollover_idle_cycle/cnt_scan_idle_at`。
- 判据原文：`(cnt_rollover_idle_cycle >= 0) && (cnt_rollover_idle_cycle < 4)`；scan终判 `((idx_scan_offset < 2 || idx_scan_kind == 1) ? (cnt_scan_idle_at < 8) : (cnt_scan_idle_at > 4990))`。
- 依据：FSC §4.2.1/§16.3/§16.4；STOP排空与abort立即取消的职责不同。
- 能否精确：在已证明没有owner的定向配置可以按采样沿推导；若只审合同最大延迟，应明确相应上限来源。
- 风险/建议：延迟清状态或提前进入idle几拍不被拒绝；保存注入时的实际macro tick与owner状态再计算预期idle拍。

### T11（中）：PWI返回握手至少1次

- 位置：`rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v`，PWI-02及PWI-03/05前提，`cnt_return_transfer`。
- 判据原文：PWI-02终判 `cnt_return_transfer >= 1`；建立返回前提还使用 `o_return_pending || o_switch_pending || (cnt_return_transfer >= 1)`。
- 依据：PWI §6.3/§7/§13，PVW §11.3/§11.4，PWC保持型请求只消费一次。
- 能否精确：可在本次真实fine-return前后做delta==1，并关联谷身份。
- 风险/建议：重复握手不一定重复产生精度返回事件，`cnt_return_event == 1`不足以检测重复请求消费。

### T12（低）：long_10重复事件只有下限

- 位置：`rtl/ppg_control_top/tb_ppg_control_top_long_10_cycles.v`，`GROUP5_REPEATED_BASELINE/GROUP5_REPEATED_PRECISION_ENTRY_RETURN`，`C_LONGRUN_MIN_REPEAT_COUNT/reg_cross_count/cnt_entry_commits/cnt_return_commits`。
- 判据原文：失败条件 `reg_cross_count < C_LONGRUN_MIN_REPEAT_COUNT`、`cnt_entry_commits < C_LONGRUN_MIN_REPEAT_COUNT`、`cnt_return_commits < C_LONGRUN_MIN_REPEAT_COUNT`。
- 依据：RAW §9.2第5组规定至少10个完整周期，属于必要存在性下限。
- 能否精确：可以独立检测模型按刺激与端部截断推导完整周期数；当前合同不能据此武断要求所有事件恰好10次。
- 风险/建议：保留下限作为合规覆盖，另做逐周期唯一事件核算以排除额外事件；不把>=误报成合同违反。

### T13（低）：RAW长期运行“至少”与诊断短跑

- 位置：`rtl/ppg_control_top/tb_ppg_control_top_longrun.v`，RAW-12；long_10中的 `LONGRUN10_COVERAGE`；`tb_diag_algo_probe.v`中的同名RAW-12。
- 判据原文：longrun等待 `(cnt_red_response >= C_RAW12_TARGET_RED_SAMPLES) && (cnt_ir_response >= C_RAW12_TARGET_IR_SAMPLES) && (($time - reg_measurement_start_time) >= C_PPG_MIN_DURATION_NS)`；long_10用 `C_LONGRUN_TARGET_*`。diag的常量为诊断缩短配置，应另登记。
- 依据：RAW §8.1/§8 RAW-12及§9.2第5组明确at least，不该为了计数相等提前停止到10秒之前。
- 能否精确：物理观察期和逐身份计数可以，覆盖终止条件仍可用>=。
- 风险/建议：诊断probe的PASS标签不能当正式10秒证据；正式跑保留下限，独立核对4000宏帧/2000万拍和测量窗口内响应守恒。diag只作诊断，不能因标签相同并入RAW-12闭合。

### T14（低）：FIR频率响应区间

- 位置：`rtl/ppg_coarse_detection_fir/tb_ppg_coarse_detection_fir.v`，`check_frequency_response`，`model_frequency_magnitude/magnitude_min/magnitude_max`。
- 判据原文：`(model_frequency_magnitude >= magnitude_min) && (model_frequency_magnitude <= magnitude_max)`。
- 依据：FIR §4.3给近似dB特性，区间作为浮点频响健全性检查合理。
- 能否精确：系数、冲激响应和定点输出可以逐bit比；实数三角函数宜保留有推导的数值容差。
- 风险/建议：宽区间会隐藏系数扰动，且此函数算的是模型系数而非直接读取DUT；保留现有冲激/逐事务模型检查作为实际RTL证据，记录区间与dB阈值换算，不能单靠此函数宣称RTL频响通过。

### T15（低）：FIR最多16周期

- 位置：同FIR TB，FIR-03/FIR-23，`cnt_clock_cycle/cnt_last_input_cycle/C_PROCESS_MAX_CYCLES`。
- 判据原文：`(cnt_clock_cycle - cnt_last_input_cycle) <= C_PROCESS_MAX_CYCLES`；FIR-03还要求 `o_result_valid == 1'b1 && o_history_full_r == 1'b1`。
- 依据：FIR §10.2/§16 FIR-03、FIR-23明确最多16周期（8us），内部提交拍可变。
- 能否精确：对固定实现可计算精确延迟，但不得把该实现延迟当外部合同额外要求。
- 风险/建议：无valid的单独时延数值不证明完成；每笔核对输入/首次valid配对，保留<=16合同门。等待器限制见W02。

### T16（中）：RAW自检只检查形状、排序及稀疏范围

- 位置：`rtl/ppg_control_top/tb_ppg_real_raw_generator_selfcheck.v`，RGC-01–05/08–14及non-normal sweep，`pulse_* / drift_* / frame_probe / period_* / cycles_*`；生成器实现位于 `tb_ppg_real_raw_generator.vh`。
- 判据原文摘录：`pulse_start < pulse_rise_mid`、`pulse_cycle_end < pulse_notch_end && pulse_cycle_end >= 0`、`drift_trough < drift_peak`、`amp_low < amp_normal && amp_normal < amp_high`、`cycles_fast > cycles_normal && cycles_normal > cycles_slow`；RGC-08扫描 `frame_probe = frame_probe + 31`，RGC-12步长131；范围用 `target_code_first < C_RAW_TARGET_CODE_MIN || target_code_first > C_RAW_TARGET_CODE_MAX`拒绝越界。
- 依据：RAW §3/§4/§9.4.10，冻结配置、可复现和RAW合法区间。
- 能否精确：可建立独立公式模型并枚举全部周期/参数边界。RGC-06本已有1000次同帧重复调用相等检查，属于真实条件PASS，不能与U01混淆。
- 风险/建议：参数、幅度或分段边界错但仍单调/有界可过；互质步长在不到一整圈的有限扫描中不代表枚举所有相位。保留形态检查，同时补精确数值/边界，不把“相对大小”宣传成完整冻结模型一致。

### T17（中）：PRC合法周期只检查少量事件存在

- 位置：robustness TB，PRC-06a/06b，`reg_peak_count/reg_valley_count`。
- 判据原文：06a失败条件 `(reg_peak_count < 2) || (reg_valley_count < 2)`；06b失败条件 `(reg_peak_count < 1) || (reg_valley_count < 1)`。
- 依据：RAW §9.4.10 PRC-06，PVW §7/§8要求合法间隔资格。
- 能否精确：可记录每对峰峰/峰谷身份并计算实际间隔，完整重复数依刺激窗口确定。
- 风险/建议：额外错误事件或错间隔但次数够仍通过；不把“有两个峰谷”当“所有间隔检查正确”。PRC-06c另有实际timeout计数非零前提，已防空真。

### T18（高）：PRC-09只要求至少一个失资格窗口

- 位置：robustness TB，PRC-09，`reg_unqualified_after_injection_count/flag_qualified_recovered_after_injection`，约1698行。
- 判据原文：恢复已成立后，仅 `reg_unqualified_after_injection_count == 0`时报FAIL，否则打印“produced %0d real unqualified FIR output handshake(s)”PASS。
- 依据：RAW §9.4.10 PRC-09要求每个覆盖失资格样本的检测窗口unqualified，FIR §7.3是21笔窗口资格。
- 能否精确：可以，以同色真实被接纳样本队列确定包含该样本的窗口集合；计数通常与21笔历史有关，不能忽略warmup/丢弃/模式等前提直接硬填21。
- 风险/建议：只有首个窗口失资格、下一窗过早恢复也可满足>0；逐个计算窗口membership及资格，并要求预期集合全部观察到、恢复点正确。

## 无条件与穷尽分支PASS

### U01（高）：PRC-05引用型PASS

- 位置：robustness TB，PRC-05，约1720行。
- 判据原文：`$display("PASS PRC-05 cited: tb_ppg_real_raw_generator_selfcheck.v RGC-06 real evidence (2026/08/29 rerun) -- noise bounded to configured amplitude and bit-identical across 1000 repeated frame evaluations, both colors");`，该处没有运行RGC或检查它的当前结果。
- 依据：RAW §9.4.10 PRC-05、§9.6当前源码/日志/版本链接及真实比较规则。
- 能否精确：可以，将当前RGC-06两色的实际比较结果和生成器哈希关联到组级汇总。
- 风险/建议：旧证据/失败RGC也能产生此PASS；打印INFO而非成功比较，聚合层显式验证来源日志。

### U02（高）：PRC-08引用型PASS

- 位置：robustness TB，PRC-08，约1725行。
- 判据原文：`$display("PASS PRC-08 cited: tb_ppg_control_top_injection.v INJ-03 real confirmed evidence -- invalid-sample-injected transaction reached the formal boundary with sample_valid=0 and identity/value fields intact, later legal sample recovered sample_valid=1");`。
- 依据：RAW §9.4.10 PRC-08、§9.5.1/§9.6要求当前联合或final-top公开注入、身份、副作用和恢复证据。
- 能否精确：可以建立同基线INJ-03证据链接，再核对它是否覆盖新合同全部项目，未覆盖者写PARTIAL。
- 风险/建议：打印引用不执行当前INJ，也不证明FIR历史/检测状态没有推进；当前真实注入TB另有valid/identity比较，但不能用这句话直接关闭PRC-08。

### U03（高）：芯片TC6无论翻转与否都PASS

- 位置：chip TB，TC6，`mr_latch_before/after/dd_latch_before/after`，约1121行。
- 判据原文：`if((mr_latch_after[0] === mr_latch_before[0]) && (dd_latch_after[0] === dd_latch_before[0]))`分支打印“PASS TC6 架构级窄窗口结论确认”；`else`打印“PASS TC6 真实STOP触发discard锁存翻转位变化”。两支都不增加 `cnt_error`。
- 依据：CHIP §9诊断读回、§11.3窄窗口记录；FSC/AMI的实际discard事件与锁存对应。合同接受窄窗口限制不等于任意观测均可当精确比较PASS。
- 能否精确：可以相对真实公开discard事件计数/身份计算翻转位奇偶；事件未发生应标观察或未覆盖，替代场景证据另链接。
- 风险/建议：错误多翻转、漏翻转或X落在else都不由此局部判据拒绝；保留TC6此前真实Q3/DBG存在性检查，单独决定这项是精确compare还是INFO，不宣称整个chip TB永远PASS。

## 空真与证据范围不足

### V01（高）：AMI-24故障前提可为假

- 位置：AMI TB，AMI-24，约1726行。
- 判据原文：`check_case("AMI-24", !o_wrapper_fault_blocking || !o_transaction_start_ready);`，位于正常固定SAR15 characterization检查之后。
- 依据：AMI §15.1/§15.2/§6.11及§17 AMI-24要求真实阻断禁止新事务、诊断和活动故障保持/清理。
- 能否精确：可先证明真实fault active，保持start valid，逐拍要求ready=0/fire delta=0，再检查冻结清理事件。
- 风险/建议：fault=0时条件恒成立，甚至没有测试阻断；后续HIST-BLOCK/K-RED2等有真实故障前提，可作为补充来源但必须逐条映射，不据此掩盖原AMI-24空真。

### V02（中）：长跑正式结果数量只打印

- 位置：`rtl/ppg_control_top/tb_ppg_control_top_longrun.v`及同目录 `tb_diag_algo_probe.v`，`LONGRUN_TB_PASS`，`cnt_measurement_result_valid`。
- 判据原文：`if(cnt_error == 0)`后打印 `measurement_result_valid=%0d`，未在这两份文件里对该数量建立响应/正式结果/合法discard的守恒比较。
- 依据：RAW §6/§9.6，AMI §6.7/§13；RAW-12本身的最低物理运行覆盖与完整数据路径闭合应分开。
- 能否精确：可沿用H01的每组START基线、匹配身份和STOP原因计数方式。
- 风险/建议：正式结果为零或累计漏出不由此横幅的打印字段拒绝；只能把当前长跑PASS用于实际断言过的RAW覆盖，不能把打印数量视为守恒证明。diag缩短跑更不能替代正式长期证据。

### V03（中）：PRC-10只检查sample_index方向

- 位置：robustness TB，PRC-10，`reg_order_violation_count`。
- 判据原文：`if(reg_order_violation_count != 0)`FAIL，否则打印“sample_index strictly advanced ... order_violation_count stayed 0”。PRC-09先检查真实unqualified输出和qualified恢复，故不是“整个场景零事件”的空真。
- 依据：RAW §9.4.10 PRC-10要求frame/sample/color顺序和恢复前history资格。
- 能否精确：可按逐身份队列比对合法结果集合和恢复资格，带颜色及frame的预期递增。
- 风险/建议：丢样本后仍单调、颜色串扰或frame错绑不由该计数检查识别；将PASS措辞限于其真实sample顺序证据，补完整合同项目映射。

## 等待、看门狗和超时

### W01（中）：AMI通用助手到限静默返回

- 位置：AMI TB，`start_transaction/wait_measurement_result/service_calibration_request/complete_wrapper_startup/complete_wrapper_recheck`，`cnt_watchdog/calibration_guard/startup_guard/recheck_guard`。
- 判据原文：start等待 `(o_transaction_start_ready !== 1'b1) && (cnt_watchdog < 200)`后仅ready为1时等待握手，随后撤销valid；result等待valid最多500；service等待请求最多200后仅请求valid时响应；startup循环上限300、recheck上限500，均未在助手出口直接FAIL。
- 依据：AMI §7/§11/§17、IDC §8/§9，真实请求和结果为比较前提。
- 能否精确：可返回成功标志，调用处累计场景前提失败；在预期拒绝场景另用专用helper。
- 风险/建议：局部setup未发生却继续做否定性质比较；AMI-17的精确3请求、AMI-26的更新delta、全局watchdog等会捕获部分异常，所以本条不声称每个timeout都能让整个TB最终PASS。

### W02（中）：FIR助手40/80拍静默超时

- 位置：FIR TB，`wait_result_valid/wait_fir_idle`，`wait_cycles/cnt_wait_cycle`。
- 判据原文：`while(o_result_valid !== 1'b1 && wait_cycles < 40)`、`while(o_fir_idle !== 1'b1 && cnt_wait_cycle < 80)`，循环结束不直接判失败。
- 依据：FIR §10.2最多16拍；§10.3/§13排空。40是TB保护上限，不是合同许可的计算时延。
- 能否精确：可在助手出口证明valid/idle，另按每笔首次valid检查<=16。
- 风险/建议：后续只比payload可读到旧值；FIR-03/23和FIR-24另有检查、末尾要求完整PASS数量，全局超时缺终判横幅会被unit driver拒绝，不能把局部静默返回直接等同整套静默通过。

### W03（中）：FSC末拍扫描未显式证明对齐成功

- 位置：FSC TB，`FRAME-NC-LAST/RESTART-STOP-SCAN/RESTART-ABORT-SCAN`，`cnt_scan_wait/idx_scan_offset`。
- 判据原文：等待macro tick4998/4999最多5100拍后直接驱动STOP/abort；`FRAME-NC-LAST`在等待4999后保存ready，没有保存tick匹配成功标志。
- 依据：FSC §4.2.1/§16/§18 FSC-03及边界扫描设计依据。
- 能否精确：可同时锁存实际注入tick、frame、frame-active和等待成功。
- 风险/建议：取消动作落在错误拍仍可能满足末态计数，不能当指定相位已覆盖；终判结合对齐标志，timeout单独FAIL。scan中tick0延迟/新帧检查可捕获部分未对齐，不能据此省略每格setup确认。

### W04（低）：Q3未出现返回false已有多数调用者防护

- 位置：system/chip TB的复制 `wait_q3_release`，符号 `o_real_release/cnt_wd`；实际副本和while位置见候选表。
- 判据原文：`while((o_clk_q3_low !== 1'b1) && (cnt_wd < 5600))`；未等到返回0；已拉高但不释放超过6600会打印FAIL并增加错误。chip用 `CLK_Q3_LOW`。
- 依据：RAW §5/FSC §4.4及相应事务存在性合同。
- 能否精确：真实应答场景可确认Q3/owner匹配；预期抑制场景不能把无Q3当统一失败。
- 风险/建议：只是看到false本身不足以判timeout缺陷。JNT有 `JNT-Q3-RELEASE`，chip TC6有真实Q3前提，连续样本TB有目标数与全局watchdog；保留返回标志模式，每个新调用者必须明确消极/积极预期。

### W05（低）：无界ready等待有全局失败兜底

- 位置：`rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v`、FIR TB、`rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v`、`rtl/ppg_normal_transaction_fork/tb_ppg_normal_transaction_fork.v`、`rtl/ppg_peak_valley_window_detector/tb_ppg_peak_valley_window_detector.v`等，send/request助手中的ready循环。
- 判据原文代表：`while(o_result_ready !== 1'b1)`、`while(o_source_update_ready !== 1'b1)`、`while(o_normal_ready !== 1'b1)`。
- 依据：各模块ready/valid与自检结束设计，tools unit driver要求最终横幅。
- 能否精确：可补局部有界失败以指明卡住身份，不应以超时静默返回代替真实握手。
- 风险/建议：这些TB已有全局FAIL/`[FAIL]`/`$fatal`或超时横幅、且缺成功横幅被unit driver拒绝；此次不把它们列为已证实的静默超时缺陷。局部timeout有助定位，保留全局兜底。

## 回归入口

### R01（高）：系统脚本仅统计，不形成验收

- 位置：`rtl/ppg_control_top/run_xsim_regression.sh`，for循环及末尾 `cat "$SUMMARY"`。
- 判据原文：记录 `xvlog_rc/xelab_rc/xsim_rc`，`grep -c -E "^PASS "`、`grep -c -E "^FAIL |ERROR:|FATAL_ERROR|UVM_ERROR|status=FAIL"`、`grep -c 'finish called'`；之后只echo summary，没有任何逐TB verdict或聚合 `exit 1`。
- 依据：RAW §9.6/§11当前日志完整真实比较规则；脚本头写回归driver，其他入口tools的显式pass criteria是可参考设计依据。
- 能否精确：可列每TB预期最终横幅、检查标签集合/比较次数及结束记录，聚合退出码。
- 风险/建议：编译失败、TB崩溃、提前finish、没有FAIL但没有PASS都只成为TSV值；shell最后cat成功通常返回0。要消费summary显式验收，不能把shell 0当20-TB全过。固定OUTDIR还有旧产物新鲜度风险，后续改为每次唯一目录。

### R02（高）：芯片脚本同样无终判

- 位置：`rtl/ppg_chip_digital_top/run_xsim_regression.sh`，`pass_count/fail_count/finished`与末尾cat。
- 判据原文：与R01相同的记录流程，FAIL ERE为 `^FAIL |ERROR:|FATAL_ERROR|UVM_ERROR`（未含 `status=FAIL`），不比较PASS数量，不要求chip最终横幅，不检查finished>=1决定退出。
- 依据：CHIP验收/回归证据要求及同R01的回归判定设计。
- 能否精确：可要求chip明确终判、每场景实际比较及全部tool rc为0。
- 风险/建议：同R01，包括打印 `CHIP_DIGITAL_TOP_TB_FAIL`而未匹配前置FAIL时的终判缺失；先建立准确最终横幅门，再补完整失败模式，不能只扩大grep就宣称验收闭合。

### R03（低）：unit driver有实质验收但未冻结所有比较数量

- 位置：`tools/run_unit_tb_regression.sh`，`TB_TABLE/FAIL_ERE/verdict`。
- 判据原文：`rc_xvlog/rc_xelab/rc_xsim == 0 && fin >= 1 && fails == 0 && have_banner == Y`；末尾 `[ $n_run -gt 0 ] && [ $n_fail -eq 0 ]`。部分banner采用 `[0-9]+`。
- 依据：脚本头pass criteria；各模块验收矩阵和真实比较规则。FSC/AMI/PVW/BSL/PWC/PWI/SSW/SUP及FIR在当前TB内另有精确比较总数门。
- 能否精确：可固定比较标签集合或数量清单，但应区分单行总横幅和逐比较行，不直接拿grep PASS数量当检查次数。
- 风险/建议：unit驱动已有0测试拒绝、tool退出、最终横幅和结束门，崩溃/提前finish缺banner会FAIL。对只有 `cnt_error==0`终判的TB，删场景但保留成功横幅仍可能通过；新增expected标签/比较总数作为补强，而非误报unit也与R01相同。

## H01：long_10“JNT前缀残留1笔”已修，保留历史清点

位置：`rtl/ppg_control_top/tb_ppg_control_top_long_10_cycles.v`，`GROUP5_NO_STALE_CONTEXT`，`cnt_l10_base_responses/cnt_l10_stop_completion_discards/cnt_l10_stop_result_discards`。

旧的“最多允许正式结果少一笔”文字仍保留在历史注释里；当前可执行判据为：

```verilog
if((cnt_measurement_result_valid + cnt_l10_stop_completion_discards + cnt_l10_stop_result_discards) !=
    (cnt_red_response + cnt_ir_response - cnt_l10_base_responses)) begin
```

当前START窗口排除前缀响应，并分别统计STOP期间success=0旁带及STOP原因正式结果discard。依据：RAW §9.1独立组干净起步、§9.2第5组/§9.6守恒，AMI §6.10/§13，FSC §10.4/§16.3。此项能精确核算且已实际写成精确核算，**不再存在活跃“允许差1”判据**。旧容差曾吸收错误计数口径与合法STOPdiscard的混合，建议RC1用丢失/重复负对照守住这条等式，另核对STOP计数是否逐身份去重，不能只看三个全局总数抵消。

## 全范围审阅归档

51份源码的逐文件清单及结果见 `V9_FILE_REVIEW.tsv`。该表记录每文件适用条目与防空真/终判；没有列入正文的比较是精确数值、固定窗口波形布尔表达式、参数合法性、循环计数或赋值，不因出现 `<=`就算容差。

补充已核对的防护：AMI-08计数相等还有>0前提；LOST-EXCL有lost>0；NRE-03确认两色历史真实full、NRE-04/05确认真实cross/进入/返回；RRC-09等待满历史失败会加错误；TRK-07要求真正pending提交、码及epoch各加1；PRC-03要求实际饱和非零，PRC-06c要求实际timeout事件，PRC-09要求实际注入和恢复；Group1–4末尾有first-peak/cross/valley/tail存在性。它们不是零事件自动PASS。

仍需RC1动态验证：7个高风险项的针对性负对照、T06/T07采样沿精确偏移、U03真实事件到SPI翻转位的逐次关联、T18逐窗membership，以及所有建议实施后的完整回归。本次仅清点，不将这些待验证项写成已关闭。

## 后续仿真确认的TB同沿竞争（Q01–Q02）

统筹已认可D04/D06定因结论。本节基于 `66bebdfabe9e1cb173c34a0ce44e48ba4230398d` 的仓库外实验，原32项增加两个独立机制，总数为高7、中20、低7、合计34。实验diff仅供证据审阅，没有应用到仓库TB。完整证据见 [定因报告](D04_D06_CAUSE_REPORT.md)、[逐拍TXN](TXN_EVIDENCE.tsv)、[运行汇总](RUN_RESULTS.json)。

### Q01（中）：SMOKE-23 owner统计与等待读取同沿竞争

- 位置：`rtl/ppg_control_top/tb_ppg_control_top.v`，owner计数/身份快照进程（基线1043–1060行）、SMOKE-23两个等待循环（2915/2930行）。
- 机制：posedge监测进程以阻塞赋值更新owner计数和身份；主刺激也在同一Active区读取，影响退出等待和后续STOP排期。
- 已确认影响：同一RUN15/frame1/sample2的RED NORMAL SAR9事务，在Icarus中于126039拍输出，在XSIM中于同拍STOP丢弃；STOP_ACK相差一拍，最终结果分别34/33。不是重复计数，也不是后续复位丢失。
- 最小实验：两个读取点加#1，两边73 PASS、49 ADC/33 results、finish=1655648.5 ns，差异TXN同拍STOP丢弃。完整输出/丢弃身份序列一致，但其他未改场景仍有时序偏移；扩展错开计数/身份更新与读取后，全套运行期观测拍号一致。
- 建议：owner计数/身份作为原子观测快照，在其更新结算后读取并决定STOP，不依赖Active区进程执行先后。SMOKE-17 ready同沿驱动仍是候选风险，单独调整未消除本次D06，不能误标为本次差异根因。
- 证据：[最小diff](tb_ppg_control_top.minimal.diff)、[扩展时序diff](tb_ppg_control_top.full_timing.diff)。

### Q02（中）：芯片lost统计与等待读取同沿竞争

- 位置：`rtl/ppg_chip_digital_top/tb_ppg_chip_digital_top.v`，`cnt_chip_lost`监视进程及`wait_chip_lost`（基线778–791行）。
- 机制：计数进程在posedge阻塞递增，等待循环同沿读取，导致后续SPI/STOP排期差异；原始结束时刻相差1000 ns。
- 最小实验：只在wait_chip_lost的posedge后加#1，保留等待计数增量和上限，两边20 PASS、0 FAIL、finish=11361750 ns，lost/START/STOP及结果事件序列、拍号一致。
- TXN核对：原始两边输出的五笔正式结果身份/时刻/拍号完全相同，三笔completion-lost身份相同；未发现正式结果在一边输出、另一边丢弃的差异。
- 建议：在计数结算后的#1或下降沿读取，并保持TB输入驱动与DUT采样沿错开。
- 证据：[最小diff](tb_ppg_chip_digital_top.minimal.diff)、[扩展时序diff](tb_ppg_chip_digital_top.full_timing.diff)。

两项均是已确认的TB竞争问题，不是RTL竞争或新增RTL缺陷数。实际修复和RC1的Icarus 12复核由统筹后续安排。
