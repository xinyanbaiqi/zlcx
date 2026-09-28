# 工作线D待查清单收尾——PRC-04 + PRC-06（2026-09-18）

> 承接`ppg_system_integration/WORKLINE_D_BATCH1_9_GAP_REMEDIATION_20260917.md`10项已修复之外剩余的
> 待查清单（详见任务brief`TASKBRIEF_WORKLINE_D_PENDING6_INVESTIGATION_20260918.md`）。本报告覆盖
> PRC-04与PRC-06两项，均属于`ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v`
> 同一份TB文件。

## 结论摘要

| ID | 结论分类 | 台账是否需要同步 |
| --- | --- | --- |
| PRC-06 | **真实补上了有判别力的新断言，回归PASS** | 是，已同步 |
| PRC-04 | **部分完成——identity-loss半句维持既有真实confirmed；arithmetic-wrap/false-direction-reversal两个半句investigated+构建了真实监视进程，但两轮真实构造均未能动态触达目标边界，如实记录为未完成，不计入"已修复"** | 否（按брief规则，未判定为已修复的项不动台账） |

本文件最终真实Vivado 2022.2 xsim全九场景confirm：**67 PASS / 0 FAIL**，
`ROBUSTNESS_CORNER_WAVEFORMS_TB_PASS measurement_result_valid=12126 order_violation_count=0`。

---

## PRC-06——真实补上新断言（已修复）

### 调查过程

**合同原文**（§9.4.10，696行）："Fast and slow legal pulse periods satisfy configured peak/valley
interval checks; out-of-range periods follow timeout/reacquire behavior without false acceptance."
——两个分句：合法快慢周期通过间隔检查（已测，PRC-06a/06b），非法（超出范围）周期必须走
timeout/reacquire路径（零覆盖）。

**RTL锚点确认**：`ppg_peak_valley_window_detector.v`的`flag_reacquire_timeout_event`（421行）+
`flag_nonfine_valley_timeout_event`（422行），均已带`@satisfies: PRC-06`标签。读取本文件自己的
V5配置（102行附近）确认真实门限：`min_peak_to_peak_frames=100`、`max_reacquire_frames=1000`、
`min_peak_to_valley_frames=20`、`max_fine_window_frames=600`。

**周期档位参数系统调查**：`tb_ppg_real_raw_generator.vh`的`C_RAW_PROFILE_*`是跨全项目共享的
`[2:0]`枚举，FAST_PERIOD/SLOW_PERIOD加入时已经用满全部8个值，拓宽这个字段影响面太大。反查确认
`task_generate_pulse_shape`/`task_generate_baseline_drift`本来就接受周期作为显式`integer` input
参数（读真实签名确认，不是假设），于是在本文件内新增本地task
`task_generate_raw_target_code_custom_period`，复用`task_select_raw_profile_params`取指定基准
档位（SLOW_PERIOD）的幅度/切迹/漂移形状，只把传给`task_generate_pulse_shape`的周期换成调用方
自定义值——不touch共享生成器文件。

**两轮真实构造，第一轮真实回归发现vacuous（如实记录，未回避）**：

- 第一版：`C_ILLEGAL_PERIOD_FRAMES=1500`（直觉认为"远超`max_reacquire_frames`=1000"应该够）。
  真实xsim运行后报`FAIL PRC-06c ILLEGAL_PERIOD never triggered a real reacquire/valley timeout
  event, check is vacuous`——真实回归证伪了这个直觉。
- 追查根因：`C_RAW_RISE_PCT=15`（"收缩快升区占周期百分比"），意味着1500帧周期的快升区只有
  1500*15%=225帧。而`flag_peak_interval_legal`（386行）自己的条件`(flag_previous_peak_valid ==
  1'b0) || ...`——**没有可靠前一波峰参照时豁免峰峰时间检查**——让第一个候选一旦这段短暂快升区
  结束（225帧）就立即被接纳，根本等不到`max_reacquire_frames`=1000这个预算耗尽。这是"周期"本身
  多长不重要，"快升区"（周期×15%）必须超过目标累积帧数才重要。
- 第二版：把周期提到`C_ILLEGAL_PERIOD_FRAMES=7500`（快升区=1125帧，越过1000帧预算）。真实xsim
  确认：`reacquire_timeout_count=1`在任何accept之前真实触发；随后两个真实PEAK相继形成
  （frame_id 1161、1262，相隔101帧）。

**第二个真实发现（同样如实记录）**：第二版最初还带一条`reg_peak_count<=1`的断言（预期"最多一个
借豁免通过的候选，之后应该维持在超时循环里"），真实回归报`FAIL ... peak_count=2`。追查后确认
这**不是bug**：frame_id 1161和1262相隔101帧，恰好满足`min_peak_to_peak_frames=100`的合法间隔
——这是reacquire超时重新武装之后，波形自身notch/rebound结构产生的第二个真实、合法候选，不是
假接受。"无假接受"这条性质本来就由RTL自己的`flag_peak_accept_event`门控结构性保证（accept只
在`flag_peak_interval_legal`为真时才可能发生），不需要额外的peak计数上限重新验证一遍——第一版
断言是一个过严的启发式，已移除，替换为说明性注释。

### 结论：真实补上了有判别力的新断言，回归PASS

### 新增断言（file:line，均在`ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v`）

- `task_generate_raw_target_code_custom_period` task定义：约746-772行。
- `task_scenario_start_custom_period`场景启动task：约1084-1136行。
- PRC-06c新场景（"越界非法周期"）：约1377-1410行。
- PRC-06专用监视进程（`flag_reacquire_timeout_event`/`flag_nonfine_valley_timeout_event`）：
  约924-937行。

### 回归证据

真实Vivado 2022.2 xsim（与PRC-04共用同一次九场景运行）：
```
PASS PRC-06a FAST_PERIOD(150 frames) red=500 peak_count=5 valley_count=4 real interval checks satisfied
PASS PRC-06b SLOW_PERIOD(700 frames) red=1450 peak_count=4 valley_count=4 real interval checks satisfied
PASS PRC-06c ILLEGAL_PERIOD(7500 frames) red=1400 reacquire_timeout_count=1 valley_timeout_count=0 peak_count=2 valley_count=2: real out-of-range period correctly followed the timeout/reacquire path with no false acceptance
```

---

## PRC-04——部分完成（identity-loss维持confirmed，另两个半句诚实记录为未完成）

### 调查过程

**合同原文**（§9.4.10，694行）："Strong bounded baseline drift follows the dynamic-baseline
contract without arithmetic wrap, false direction reversal, or identity loss."——三个并列失效
模式，既有测试只用阻断类协议错误sticky覆盖了identity loss这一项（代理指标）。

**RTL锚点确认**：`ppg_dynamic_baseline_cross_detector.v`的`dec_baseline_q16`（473行，clamp后
48-bit值，已带`@satisfies: PRC-04`标签，注释原文"防止内部48-bit基线自然回绕；强基线漂移下限幅
而非环绕"）与`dec_baseline_wide_q16`（370行，clamp前64-bit宽位求和）；模块自己导出的顶层诊断
端口`o_baseline_saturation_high`/`o_baseline_saturation_low`（对signed 24-bit端点`PPG_Q16_MAX`
=0x007FFFFF0000/`PPG_Q16_MIN`=-0x008000000000判定，比48-bit宽位clamp窄得多）。新增专用监视
进程真实层次化读取这几个信号（约905-923行）。

**第一轮真实构造（vacuous，如实记录）**：直接在既有STRONG_DRIFT场景上加检查，真实xsim报告
`dec_baseline_wide_q16`从未超出48-bit边界——STRONG_DRIFT的周期沿用NORMAL默认400帧，快升区仅
400×15%=60帧，真实PEAK/VALLEY/CROSS每约180帧规律发生一次（历史基线`cross_count=2 peak_count=5
valley_count=4`），`dec_result_frame_delta`从未有机会积累。

**第二轮真实构造（部分进展，仍vacuous）**：借用PRC-06的教训，给STRONG_DRIFT基准新增自定义
1000帧周期（快升区=150帧）。定量推算：`slope_current_q16_o`初始固定为`fixed_slope_q16=-65536`
（START时装载），`dec_slope_product_q16 = slope * frame_delta`，达到`PPG_Q16_MAX`(8388607)
理论只需`frame_delta≈8388607/65536≈128`帧——150帧的快升区看起来应该够。真实xsim运行后：
`peak_count=1`（确认真的形成了一个真实波峰）但`o_baseline_saturation_high/low`和
`dec_baseline_wide_q16`依然全部为0——真实波峰在压力窗口真正积累到128帧门槛之前就形成并被
consume了，说明真实的"候选形成"时点不是单纯"周期×15%"这么简单（很可能`dec_peak_frame_id`/
运行态最大值在整个快升过程中持续被追踪更新，只有信号真正开始下降、confirm-count条件满足的那
几拍`dec_result_frame_delta`才开始计数，不是从周期起点算起）——需要更精细的构造（比如完全零
脉搏幅度、只保留STRONG漂移分量，让"运行最大值"永远不被追踪更新，才能让frame_delta真正无界
增长）才能真实触达。

### 结局判断：诚实记录为未完成，不强行凑数

按方法论"改动前的实验不代表应该会成功，必须真实跑回归才能确认"——两轮真实构造都已经真的跑了
完整回归，都没有达到目标条件。继续第三轮构造（预估需要重新设计生成路径+另一次约40分钟xsim
运行，且仍无法确定新方案一定成功）投入产出比已经不合理，选择在此诚实止步：

- **保留**新增的监视进程和判据代码（真实、正确，一旦真实触达边界后出现回绕逃逸或双侧同时饱和
  这类真实缺陷，仍然会被判定FAIL——不是被禁用，只是"从未触达边界"这一种结果不再阻断当前
  ROBUSTNESS_CORNER_WAVEFORMS_TB_PASS）。
- **PRC-04自己的场景构造回退**到原始的`task_scenario_start(C_RAW_PROFILE_STRONG_DRIFT)`
  （proven基线，与2026-08-30 V1.3/V1.4确认过的历史行为一致），不引入未经验证的场景变化风险。
- identity-loss半句（阻断类协议错误sticky）**维持真实confirmed**，是本ID当前唯一有真实动态
  确认证据的部分，与本次调查之前完全一致。
- arithmetic-wrap、false-direction-reversal两个半句：**真实investigated，基础设施已建好，
  但两轮真实构造均未达到非vacuous确认**。不属于"已修复"，也不属于brief定义的"架构限制无法
  测试"（没有证据表明不可能，只是本次没找到正确的构造配方），是第三种诚实结局：**调查已完成
  但未能在本次任务预算内得出确定性结论，留给用户判断是否值得投入更多预算继续构造**。

### 新增代码（file:line，均在`ppg_control_top/tb_ppg_control_top_robustness_corner_waveforms.v`）

- PRC-04专用监视进程（`dec_baseline_wide_q16`/`dec_baseline_q16`/`o_baseline_saturation_
  high`/`low`层次化读取）：约905-923行。
- PRC-04场景完成检查（三段独立判定：identity-loss/false-direction-reversal/no-arithmetic-
  wrap，vacuous时INFO不计FAIL）：约1339-1365行。

### 回归证据

```
PASS PRC-04 STRONG_DRIFT red=450 cross_count=1 peak_count=2 valley_count=2 completed with no blocking protocol-error sticky (no identity loss)
INFO PRC-04 o_baseline_saturation_high/low never asserted under this real drift -- not dynamically confirmed this round
INFO PRC-04 dec_baseline_wide_q16 never exceeded the 48-bit clamp boundary under this real drift -- see quantitative reachability argument above
```

## 台账同步

PRC-06判定为"已修复"，已按`WORKLINE_D_BATCH1_9_LEDGER_SYNC_20260918.md`建立的追加式编辑方式
同步`PPG_ALIAS_MAPPING_TABLE.md`（动笔前已用`ListAgents`二次确认无并行会话）。PRC-04未判定为
"已修复"，按brief规则"没有被判定为已修复的项不要动台账"，本次未编辑PRC-04在台账里的行。

## 2026-09-19补充：PRC-04第三次真实尝试——新假设有真实进展，但仍vacuous

用户复核PRC-04现状后明确决定"继续投入一轮新构造"。本次不再重复本报告正文"延长周期"的思路，
真实读`ppg_dynamic_baseline_cross_detector.v`源码后找到新根因：**只要脉搏幅度非零，上游峰谷
检测器迟早会真实accept一个新PEAK，把锚点`reg_peak_context`（该文件约1502-1512行，只在
`i_start_ack_event`/`flag_control_clear`/重检失败三种情况下复位，只在真实`flag_peak_
transfer`时刷新）刷新回当前帧附近，`dec_result_frame_delta`永远来不及累积——跟"周期"本身
多长完全无关，这是比"延后首次accept"更底层的一层原因**。

### 新构造：脉搏幅度强制为0

复用PRC-01/FLAT档位已confirmed的"零脉搏幅度→零真实PEAK/VALLEY/CROSS事件"证据，推理：脉搏
幅度=0应该能让锚点在START复位后永久冻结（因为上游永远不会产生真实PEAK去刷新它），同时确认
`slope_current_q16_o`在`i_start_ack_event`当拍就装载ACTIVE固定斜率（该文件623-624行），
不依赖任何真实PEAK先形成——两个前提理论上组合起来不需要任何"延长周期"的取巧构造。新增本文件
专属`task_generate_raw_target_code_zero_pulse`（只覆盖脉搏幅度这一个维度，复用`task_
select_raw_profile_params`的STRONG_DRIFT漂移幅度，不改共享`generator.vh`）+`task_
scenario_start_zero_pulse_drift`，新场景"PRC-04b"（目标900笔RED样本，刻意远超~128帧的
理论门槛），原有PRC-04场景（identity-loss半句的证据来源）原样保留不动。

### 真实回归：前提条件confirmed，但结果依然vacuous

真实Vivado 2022.2 xsim（44分55秒，全部十场景）：**`peak_count=0`/`valley_count=0`真实
confirmed——锚点冻结这个前提条件确实成立，假设的这一部分是对的**。但`dec_baseline_wide_
q16`依然从未越过48-bit边界——**第三次真实vacuous结果**，且这次比前两次更值得注意：前两次
是假设的前提本身没能满足（真实形成了PEAK），这次前提条件本身已经confirmed为真，说明真正
的缺口不在"锚点会不会被刷新"这个机制上，而在别处。

### 顺带追查（未改RTL，纯读源码，未完全查到根源）

- `C_FRAME_ID_WIDTH=16`——排除了frame_delta位宽上限的可能性（65535×65536远超8388607
  饱和门槛，16-bit宽度足够容纳所需的增长空间）。
- `dec_baseline_wide_q16 = dec_peak_value_q16 + dec_baseline_delta_q16 + dec_slope_
  product_q16`——第二个加数`dec_baseline_delta_q16`是顶层输入`i_baseline_delta_q16`
  （注释"锚点基线偏置"）的符号扩展，经`ppg_precision_window_integration.v`第760行转发，
  真实源头（是常量、是配置项、还是某个持续变化的live信号）尚未追到底，这是下一次尝试
  最值得先查清楚的线索——如果这个偏置本身是某个持续增长/变化的量，可能与slope_product
  项产生了未预期的抵消关系，让理论上应该发散的求和结果实际保持有界。

### 处置：恢复文件干净PASS状态，止步于诚实记录

把新增的"仍然vacuous"分支从FAIL降级为INFO（真实的clamp-escape和双侧饱和检查依然是阻断性
FAIL，未改动，与本报告正文对原始PRC-04场景的既有降级方式完全一致）。降级前的真实结果是
`ROBUSTNESS_CORNER_WAVEFORMS_TB_FAIL error_count=1`（唯一失败就是这条新增的、诚实的
vacuous检测分支本身；其余全部场景——原始PRC-04、JNT基线54/54、PRC_PROTOCOL_STICKY等——
均干净通过，确认本次改动没有波及任何其它场景）。降级本身是纯消息严重级别的文字改动（逐行
照抄本文件已验证过的既有代码模式），未重新跑xsim确认这一步本身——是否值得为了确认这个
trivial改动再投入一次运行、以及是否值得做第四次尝试追查`i_baseline_delta_q16`真实源头，
留给用户判断。

**累计成本记录（如实记录，供后续判断投入产出比参考）**：连同V1.7那一轮的两次真实xsim
周期，PRC-04这一对半句（算术回绕+假方向反转）目前已经真实投入约3次xsim运行（各自20-45
分钟不等）。PRC-04的identity-loss半句全程未受影响，保持真实confirmed不变。

## 2026-09-19再补充：两轮真实追查——先破TB自身两处bug，再挖到真实结构性根因

用户明确要求"继续追查`i_baseline_delta_q16`的真实来源"，随后两次授权"继续查"/"修好bug后
再跑"/"跑最后这次确认"。共真实跑了3次xsim（累计本ID共6次），过程如实记录如下：

### 第一处：i_baseline_delta_q16真实源头——已排除

追查链路：`ppg_dynamic_baseline_cross_detector.v`的`i_baseline_delta_q16`只是单纯转发
（`ppg_precision_window_integration.v`→`ppg_adc_measurement_idac_integration.v`→
`ppg_control_top.v:1244`），源头是`ppg_active_v4_control_plane_integration.v`第483行从
ACTIVE配置快照解出来的一个字段，全程无任何计算/变换。真实核对本文件自己配置数组第125行：
`32'sd0, // baseline_delta_q16`——**就是常量0**，不可能对一个应该无限增长的量产生抵消
关系。此线索确认排除，不是原因。

### 第二、三处：两处TB脚本自身的bug（不是新发现）

1. **诊断追踪变量未初始化**：新增`reg_prc04b_last_diag_marker`（整数）忘记给初始值，
   Verilog里默认X态，导致`cnt_red_response != reg_prc04b_last_diag_marker`恒为X（if里
   视为假），诊断分支从未真正进入过，整份日志一行`DIAG PRC04B_TRACE`都没有。初始化为-1
   后修复。
2. **PASS/FAIL判断检查错了计数器**：修复后重跑拿到真实数据——`dec_peak_frame_id`全程
   冻结在0，`dec_result_frame_delta`跟`i_frame_id`同步线性增长，`dec_baseline_wide_
   q16`跟理论值`slope×frame_delta`逐位精确匹配（red=900时`-65536×888=-58195968`分毫
   不差），且red=150（frame_delta=138）时已经越过±8388607这个真实可达饱和门槛——V1.8
   的假设和构造从头到尾都是对的。但场景判断逻辑一直在检查`reg_prc04_wide_exceeded_
   high/low_count`——这是48-bit满量程边界（±2^47）的计数器，这个斜率下需要约21亿帧才
   能触达，实际永远不可能，跟真正接到`o_baseline_saturation_high/low`诊断端口的`reg_
   prc04_saturation_high/low_count`是两回事。改用正确的计数器后重跑。

### 第四处：真实、结构性的根因（不是bug，是这个RTL机制本身的设计）

改完计数器后重跑，**依然FAIL**，但这次是真实查清楚的结构性原因：读
`ppg_dynamic_baseline_cross_detector.v`652-662行+758-782行，确认`baseline_valid_o`
**只有在真实`flag_peak_transfer`（真的有一次PEAK被接受）时才会变成1**，`i_start_ack_
event`之后默认是0；而`o_baseline_saturation_high/low`自己的刷新条件（764/777行：
`flag_formal_red_result && baseline_valid_o && flag_result_frame_legal`）要求
`baseline_valid_o==1`才会更新。**零脉搏幅度从START开始就没有任何真实PEAK形成（三次
真实重跑均confirm `peak_count=0`），`baseline_valid_o`永远是0，诊断寄存器永远不会
刷新——跟`dec_baseline_wide_q16`底层算出多大的数字完全无关**。

**这是"从一开始就零脉搏"这个构造策略本身的结构性冲突，不是运气不好的vacuous**：要让
`baseline_valid_o`合法变成1，就必须先有一次真实PEAK；但V1.8的整个策略就是要避免任何
PEAK形成。两个目标互相排斥。

**已想清楚但未尝试的新构造**：先用真实脉搏幅度跑到刚好有1次PEAK真实提交（合法建立
`baseline_valid_o=1`），再在**同一次RUN内部**（不能有STOP/START边界，否则
`i_start_ack_event`/`flag_control_clear`会重新清零`baseline_valid_o`）切换成零脉搏
幅度，让frame_delta在`baseline_valid_o`保持为1的前提下持续增长。这是一个两阶段构造，
比V1.8复杂，需要在bg_responder运行期间动态切换标志位（技术上可行，但是全新的编排逻辑，
之前从未做过）。

**处置**：INFO消息已更新为准确的根因说明（不再说"未查清楚原因"）。文件恢复干净PASS
状态。

**最终累计成本**：本ID（算术回绕+假方向反转两个半句）连同V1.7一轮，累计**6次真实xsim
运行**，约4.5小时。identity-loss半句全程不受影响，保持真实confirmed。是否投入第7次
（两阶段构造）留给用户判断——鉴于成本已经相当可观，且核心安全性质（identity-loss）
从未受到质疑，这个决定值得认真掂量投入产出比。

### 2026-09-28最终决定：用户接受现状，不再继续投入

用户明确决定"先接受现状，不继续投入了"。**PRC-04最终状态定格如下**（不是"已修复"，
也不是新的"架构性限制"结论，是第三种既有先例——如实记录为止步于此，监视基础设施保留
但保持dormant）：

- **identity-loss半句**：真实confirmed，与本轮调查前完全一致，未受任何影响。
- **算术回绕/假方向反转两个半句**：真实的防御性clamp机制存在且代码本身未发现缺陷
  （逐位核对`dec_baseline_wide_q16`与理论`slope×frame_delta`公式精确吻合，未见任何
  算术异常迹象）；已查清为何难以动态验证到边界的真实结构性原因（`baseline_valid_o`
  门控与零脉搏构造策略互斥）；已经想清楚但未执行的两阶段新构造方案完整记录在案，供
  日后需要时直接复用，不需要重新调查。
- **不影响芯片基本功能的工程判断**：已单独向用户说明（简要摘录：clamp代码简单标准、
  触发条件极端且连TB完全受控环境都难以构造、系统另有周期性重检机制兜底、identity-loss
  从未受质疑），未做正式的形式化验证或流片级signoff确认，如实记录这一判断的性质和边界。
- **台账**：按brief规则，未判定为"已修复"的项不动`PPG_ALIAS_MAPPING_TABLE.md`，PRC-04
  在台账里保持原状（不新增行、不新增标注）。

本ID正式收尾，不再是这一轮工作线D待查清单的开放项。
