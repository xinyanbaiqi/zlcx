# Track B 功能完整性核对结论（2026-08-23）

> 本文档记录 Track B（算法功能完整性核对）的完整结论，是
> `PPG_SESSION_HANDOFF_20260822.md` 第3节第6条工作的产出。核对方法：对每一个
> 算法行为项，通读对应合同的算法行为章节全文（不只是端口表）与对应RTL全文，
> 逐条核实合同描述的行为是否在RTL里真正、正确地实现，而不是只看端口/信号名
> 是否存在。全部核对均为只读，未修改任何RTL/合同文件。

## 0. 总体结论

用户要求核对的11项算法行为中：

- **10项已确认正确实现**：多光源输入、上电AMB/DC校准、慢漂移检测、周期性重检、
  波峰波谷检测、每周期基线生成、周期性重检后基线相交、非重检基线相交、滤波处理、
  9-bit准确码值（其中"慢漂移检测"按合同定义确认后无缺陷）。
- **1项（基线比较切精度、波谷后切精度共用同一处提交门控缺陷）FSM/时序结构
  本身正确，但提交门控曾使用错误的信号语义**——见1.3节，**已修复**。
- 另发现2处独立于上述11项、但同属"算法/接口协调"层面的CONFIRMED缺陷（峰谷
  检测器sticky被START清除、动态基线的config_valid门控不完整）——见1.1/1.2节，
  **均已修复**。
- 审计过程中还发现2处PWI层面的疑似不一致（`o_detection_datapath_empty`疑似漏项、
  `recheck_busy`疑似接线不统一），经结合系统架构和逐拍时序推导**核实为假阳性**，
  RTL本身正确，是合同表述容易被字面误读——见1.4/1.5节，**不修改RTL**，只记录
  合同措辞澄清建议。
- 本次审计发现的3处真实CONFIRMED缺陷全部已修复并通过三件套验证，Track B
  当前**没有遗留的算法行为正确性问题**。
- 2026-08-23对1.6节和第2节剩余4项做了结合系统架构、全部合同、全部代码的
  复核判断，并逐项完成修复：1.6节（DC恢复缺诊断透传端口）**已修复**；2.1节
  （CHARACTERIZATION模式ACTIVE配置合法性豁免范围）**已修复，合同已同步**；
  2.2节（reacquire峰峰间隔豁免范围）**已修复，合同已同步**；2.3节（FIR的
  `i_sample_valid`字面缺失）复核确认零功能影响，是可选的低优先级清理项，
  未修改。
- **Track B 至此全部完成**：11项算法行为核对完毕，6处CONFIRMED缺陷
  （1.1/1.2/1.3/1.6/2.1/2.2）全部修复并通过三件套验证，2处疑似问题
  （1.4/1.5）核实为假阳性未改RTL，其中2.1/2.2两处同时完成了对应的合同文字
  同步，仅剩2.3一项低优先级、无需修改的清理建议。

## 1. CONFIRMED 缺陷清单（按建议修复优先级排序）

### 1.1 `ppg_peak_valley_window_detector.v`：新START会清除历史诊断sticky——**已修复**

**修复状态（2026-08-23）**：三处清除条件已删除`i_start_ack_event==1'b1 ||`，只保留
`i_diag_clear_event`（V1.1→V1.2）。修复过程中Erie严格门禁第一次触发VG066
（`reacquire_timeout_sticky_o`的两处新注释和`fine_window_timeout_sticky_o`的
注释近似重复），已改写为entity-specific措辞后复核通过。iverilog编译通过、
Erie严格门禁`delivery_ready=True`（0/0）、独立lint（0/0），PWI+5个真实子模块
和AMI+14个真实子模块两级elaborate均0 error。

- **原位置**：第597-598、610-611、623-624行，三个sticky
  （`fine_window_timeout_sticky_o`/`reacquire_timeout_sticky_o`/`protocol_error_sticky_o`）
  的清除条件都写成 `i_start_ack_event==1'b1 || i_diag_clear_event==1'b1`。
- **合同依据**：`PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md` §12.4
  （约608行）"历史sticky只能由全局`i_diag_clear_event`或复位清除"；验收项PVW-37
  （约815行）"STOP和新START均不得清除历史sticky"。
- **后果**：任意sticky置位后只要发生下一次`i_start_ack_event`，无需
  `i_diag_clear_event`即可被静默清零，软件无法在下次读状态寄存器时看到上一次
  RUN的故障原因。
- **建议修复**：删除三处清除条件里的`i_start_ack_event==1'b1 ||`部分，只保留
  `i_diag_clear_event`（及复位，需确认复位路径已在别处正确处理）。

### 1.2 `ppg_dynamic_baseline_cross_detector.v`：`i_peak_valley_config_valid`门控不完整——**已修复**

**修复状态（2026-08-23）**：`flag_candidate_start`和`flag_candidate_continue`
（V1.2→V1.3）已加入`i_peak_valley_config_valid`门控——`flag_candidate_complete`
派生自`flag_candidate_continue`因而自动同步获得门控，`reg_candidate_context`
锁存只由`flag_candidate_start`驱动因而同样自动受保护，未改动`flag_candidate_break`
（取消候选不在合同§14.4禁止之列，保持原样）。iverilog编译通过（仅剩两处既有、
与本次改动无关的hex常量警告）、Erie严格门禁一次性`delivery_ready=True`（0/0）、
独立lint（0/0），PWI+5个真实子模块和AMI+14个真实子模块两级elaborate均0 error。

- **原位置**：第476-478行`flag_candidate_start/continue/complete`、
  第1537-1547行`reg_candidate_context`锁存，均未接`i_peak_valley_config_valid`门控。
- **合同依据**：`PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md` §14.4
  "config_valid为0时不得推进cross-confirmation、不得更新formal cross-related
  state"；BSL-40。
- **后果**：`i_peak_valley_config_valid`跌为0期间，候选确认计数（`cnt_cross_confirm`）
  和候选身份（`reg_candidate_context`）仍会继续推进/锁存；一旦config_valid恢复为1
  且候选仍在延续，会立即用"非法期间"积累的证据发布一次`o_cross_valid`，其
  `cross_frame_id`是config_valid=0期间锁存的帧号，不是恢复后的新证据。
- **建议修复**：在`flag_candidate_start/continue`、`reg_candidate_context`锁存
  条件里加入`i_peak_valley_config_valid`门控，或在gate跌为0时主动清空
  `flag_candidate_active/cnt_cross_confirm/flag_below_seen`（参考模块内
  `i_recheck_accept_event`已有的清空模式）。

### 1.3 精度切换安全门控链条：数值正确，**纯命名违反合同**——**已修复**

**修复状态（2026-08-23）**：已完成`i_adc_idle`→`i_precision_takeover_safe`改名，
范围覆盖精度控制器、PWI、AMB重检调度器三个端口，以及AMI内部wire
`flag_precision_takeover_adc_idle`→`flag_precision_takeover_safe`，纯改名不改
任何逻辑/时序。四个文件逐个通过iverilog编译、Erie严格门禁
（`delivery_ready=True`，0 error/0 strict warning）、独立lint（0/0），最后
AMI+全部14个真实子模块一起elaborate，0 error（仅剩动态基线文件里两个既有、
与本次改动无关的hex常量警告）。AMB调度器是否一并改名已征得用户明确同意
（选择"一起改"）。

**原始Track B四个并行agent的结论过于严重，是审计范围局限造成的假阳性——
各agent只核对了单个文件自己的端口名，没有向上追一层去看AMI在例化时真正喂给
这个端口的是什么值。2026-08-23后续设计讨论阶段重新核实后确认：AMI已经正确
计算出合同要求的复合信号，并且这个正确的值确实被送进了PWI/精度控制器/AMB
调度器，只是三处端口的字面名字仍然叫`i_adc_idle`，不是合同要求的
`i_precision_takeover_safe`。**

- **AMI已有的正确实现**：
  ```verilog
  // ppg_adc_measurement_idac_integration.v 第506/863行
  wire flag_precision_takeover_adc_idle;
  assign flag_precision_takeover_adc_idle =
      i_adc_idle && o_adc_chain_idle && o_normal_fork_idle && o_measurement_output_idle;
  ```
  其中`o_adc_chain_idle`（第1014行）、`o_normal_fork_idle`（第1015行）、
  `o_measurement_output_idle`（第1016行，已经内含overlap/重构器/DC恢复/DC恢复
  双消费者fork四项空闲判据）三个子项的定义与合同§14.1-14.3逐句一致，整条
  `flag_precision_takeover_adc_idle`公式与合同§14.5给出的
  `precision_takeover_safe`公式逐项对应，无遗漏无多余。第2217行这个信号被
  正确接进PWI实例的`i_adc_idle`端口（**不是**AMI自己的物理层
  `i_adc_idle`输入）。PWI内部把这个转发值原样喂给精度控制器（第936行）和
  AMB重检调度器（第982行）——两个消费者拿到的都是同一个正确的复合值。
- **真正的问题（CONFIRMED，但性质是命名合规，不是数据通路缺陷）**：
  - `ppg_precision_window_integration.v` 第157行端口声明`i_adc_idle`；
  - `ppg_precision_window_controller.v` 第123行端口声明`i_adc_idle`；
  - `ppg_amb_recheck_scheduler.v` 第73行端口声明`i_adc_idle`。
  三处字面名字都与合同§16第16条"不得将复合`precision_takeover_safe`伪装为
  物理idle"、精度控制器合同§18.5/§19、PWI合同§5.4/§7的逐字端口名要求
  （`i_precision_takeover_safe`）不符。
- **实际风险定性**：不是当前会导致错误行为的功能缺陷，而是一处**审计/维护期
  风险**——端口名字面意义具有误导性，未来任何人（包括自动化端口对齐检查）
  看到`i_adc_idle`都可能合理地认为可以安全地接一个真实物理ADC空闲信号，从而
  在后续维护中真的引入合同原本要防的提交延迟/死锁问题。
- **已产出设计方案**：见独立设计讨论（下方新增4.x节/或另附设计纪要），核心是
  纯改名（3个端口+相关内部wire注释同步），不改变任何逻辑/时序行为，风险低。
  AMB重检调度器是否也一并改名（它没有独立署名合同，改名不是合同逐字要求，
  但保持链路命名一致、消除同样的"伪装成idle"风险）需要用户裁决范围。

### 1.4 `ppg_precision_window_integration.v`：`o_detection_datapath_empty`——**已核实为假阳性，不修改RTL**

**核实结论（2026-08-23）**：不是缺陷。当前5项寄存器AND（第508-513行
`detection_fork_idle_o && fir_local_empty_o && baseline_local_empty_o &&
peak_valley_local_empty_o && precision_local_empty_o`）本身就是合同§5.10所说
"discard-broadcast state...empty"这个性质的实现，不需要额外的第6个信号。

- **合同原文（§5.10，377-380行）**："`o_detection_datapath_empty` is registered
  high only after PWI's fork, FIR, baseline/cross, peak/valley, precision
  controller **and discard-broadcast state** are empty. PWI samples each
  `o_local_empty` on the next 2 MHz edge after the broadcast; **it cannot
  report empty in the discard edge**."——第二句话是在解释第一句"discard-broadcast
  state...empty"具体指什么：不是一个独立硬件项，而是"寄存器化AND必须在discard
  那一拍之后才能报告empty"这个时序性质本身。
- **逐拍时序推导证据**：
  1. `flag_detection_discard_apply`（第435行，代际匹配的discard事件）在拍T命中时，
     PWI自己的`flag_fork_clear`（第436行含`flag_detection_discard_apply`）会在拍T
     把`flag_baseline_pending`/`flag_peak_valley_pending`两个寄存器清零（第534-535、
     547-548行）；FIR/baseline/peak_valley/精度控制器四个真实子模块内部各自的
     discard响应（Track A 1.6节已验证）同样在拍T的同一沿清空各自pending寄存器。
  2. 因此拍T到拍T+1期间，`detection_fork_idle_o`（组合逻辑，第430行）和四个子
     模块的`o_local_empty`（组合逻辑或直接registered输出）都已经变为"空"。
  3. `detection_datapath_empty_o`（第510-515行）是一个纯寄存器AND，在**下一拍**
     （拍T+1）才采样这5个此时已经变"空"的值——即`detection_datapath_empty_o`
     最早在拍T+1才可能变高，拍T（discard那一拍本身）绝不可能报告empty。
  4. 这与合同两句话逐字对应：discard边沿不能报empty（拍T仍为0，因为拍T更新时
     采样的是discard**之前**的组合值）、下一拍才可能为高（拍T+1）。
- **结论**：5项寄存器AND是"discard-broadcast state"这个时序要求的正确实现，
  不是漏了一项要凑的第6个信号。**不修改RTL**。
- **建议的合同措辞澄清方向**（供合同维护方参考，未主动去改合同文件）：在
  §5.10当前两句之间/之后加一句明确说明，例如："The phrase 'discard-broadcast
  state' above is not a seventh distinct empty term to be ANDed separately; it
  describes the timing property that emerges when the five listed local-empty
  signals are combined in a single registered AND, given each of them is
  itself cleared on the same discard edge. No additional signal is required
  as long as this registration-induced one-cycle lag is preserved." 中文对照：
  "上文'discard-broadcast state'不是需要单独AND进去的第七个信号，而是描述把
  上面五项本地排空信号放进同一个寄存器化AND后自然产生的时序性质（前提是这五项
  各自都在同一个discard边沿被清零）。只要保留这个由寄存器化本身带来的一拍延迟，
  不需要额外信号。"

### 1.5 `ppg_precision_window_integration.v`：`recheck_busy`分两路——**已核实为假阳性，不修改RTL**

**核实结论（2026-08-23）**：不是接线不统一的缺陷，是刻意的防死锁设计。

- **合同原文（§8，第535、541行）**："`recheck_busy = scheduler.o_amb_recheck_busy`"；
  "上述四个信号并联到FIR、动态基线和峰谷检测器的对应端口；FIR只使用accept和busy。"
  字面上要求三个消费者拿到完全相同的原始信号。
- **RTL现状**：FIR（第618行）拿到原始`amb_recheck_busy_o`；baseline（第706行）、
  peak_valley（第820行）拿到PWI内部派生的`flag_recheck_detector_busy`（第556-565行
  定义，注释原文"Scheduler等待排空时仅阻止FIR接收新输入；真实accept后才冻结检测器
  状态"，仅在`amb_recheck_accept_o`置位后才变1，比scheduler进入`ST_WAIT_DRAIN`
  （此时`o_amb_recheck_busy`已经为1）晚）。
- **子模块内部对`i_recheck_busy`的真实用法**（决定了原始信号能不能直接喂）：
  - `ppg_dynamic_baseline_cross_detector.v:421`：busy=1时**主动取消**在途相交运算
    （`flag_arithmetic_cancel`）；
  - `ppg_peak_valley_window_detector.v:434`：busy=1时`o_result_ready`直接拉零，
    拒绝任何新样本。
  两者都是"busy=1即刻冻结/取消"的强语义，不是"busy=1只是提示、允许排空在途工作"。
- **死锁推导**：合同§9（AMB安全接管条件，第547-558行）要求scheduler在拉高accept
  之前必须先看到`peak_valley_o_detector_idle=1`（峰谷检测器已经排空）。若把
  scheduler从`ST_WAIT_DRAIN`就拉高的原始`o_amb_recheck_busy`直接并联给baseline和
  peak_valley，这两个模块会在scheduler还在**等待它们排空**的阶段就被强制冻结/
  取消在途工作，永远无法到达`o_detector_idle=1`，scheduler也就永远等不到接管条件
  成立——形成死锁。PWI用`flag_recheck_detector_busy`把这两个消费者的冻结时刻推迟
  到真正`accept`之后（此时按§9的条件它们本就应该已经排空了），恰好打破了这个
  死锁，逻辑上是必要的。
- **结论**：三个消费者接线"不统一"是有意为之、且可证明必要的分级防死锁设计，
  不是遗漏。**不修改RTL**。
- **建议的合同措辞澄清方向**（供合同维护方参考，未主动去改合同文件）：在§8
  "并联"这句后面补一句区分FIR与另外两个消费者的措辞，例如："FIR receives the
  raw `scheduler.o_amb_recheck_busy` directly, since it only needs to stop
  admitting new samples. The dynamic-baseline and peak/valley children instead
  receive a PWI-derived busy signal that only asserts after the scheduler's
  real `amb_recheck_accept_o`, so they remain free to finish draining their
  own in-flight state during `ST_WAIT_DRAIN` — feeding them the raw busy value
  would deadlock against the section 9 takeover-idle condition, since it
  requires exactly the idle state this staged freeze protects." 中文对照：
  "FIR直接拿原始`scheduler.o_amb_recheck_busy`，因为它只需要停止接纳新样本。
  动态基线和峰谷检测器则拿PWI派生的busy信号，只在scheduler真正的
  `amb_recheck_accept_o`之后才置位，使它们在`ST_WAIT_DRAIN`期间仍能自由排空
  在途状态——直接喂原始busy会和第9节的接管idle条件死锁，因为该条件恰好要求
  这个分级冻结所保护的idle状态。"

### 1.6 `ppg_adc_dc_recovery.v`：合同要求的诊断透传端口缺失——**已修复**

**修复状态（2026-08-23）**：`ppg_adc_dc_recovery.v`（V1.0→V1.1）新增8组
`i_detect_code[8:0]/o_detect_code`、`i_stage1_raw[9:0]/o_stage1_raw`、
`i_stage1_code_ext signed[10:0]/o_stage1_code_ext`、
`i_stage2_raw[9:0]/o_stage2_raw`、`i_stage2_code_ext signed[10:0]/o_stage2_code_ext`、
`i_nominal_15_code signed[14:0]/o_nominal_15_code`、
`i_nominal_15_valid/o_nominal_15_valid`、`i_nominal_saturated/o_nominal_saturated`，
并入模块既有的单缓存原子`payload_o`（新增8个payload LSB localparam、扩展
`dec_payload_input`打包表达式、新增8条输出桥接assign），与其余事务字段同一拍
锁存/保持/替换，不是另建一条不同步的旁路。`ppg_adc_measurement_idac_integration.v`
（V1.7→V1.8）把可编程重构器原来留空的8个诊断输出（第1893-1900行附近）接进了
DC恢复实例新增的8个输入；DC恢复自己的8个新输出暂时留空（`.o_xxx()`），因为
目前系统里还没有真实消费方，等以后supervisor/调试通道真正需要时再接，这个
处理方式和路由器现有约19个悬空诊断输出是同一个已确认可接受的模式。

修复过程中Erie严格门禁第一次触发4处VG066（Stage1/Stage2字段的输入端口、
输出端口、localparam、输出assign四处注释太像），已改写为区分"Stage1"和
"第二级冗余"措辞后复核通过。两个文件各自过完iverilog编译、Erie严格门禁
（`delivery_ready=True`，0/0）、独立lint（0/0），AMI+全部14个真实子模块
elaborate 0 error（仅剩动态基线文件里两个既有、与本次改动无关的hex常量
警告）。

- **合同依据**：`PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md` §11.3（423-459行）
  给出的是逐字段位宽/语义表，8组`i_detect_code`/`i_stage1_raw`/
  `i_stage1_code_ext`/`i_stage2_raw`/`i_stage2_code_ext`/`i_nominal_15_code`/
  `i_nominal_15_valid`/`i_nominal_saturated`都要求"必须产生同名o_前缀输出，
  位宽和bit pattern保持不变"——这不是像cause`8'h02`/`8'h03`那样"合同没给判据、
  只能留白"的情况，是一张写死的透传表，没有解释空间。
- **实际追踪结果（逐级排查这条诊断链路走到哪里断的）**：
  1. S1可编程校准器/S1冗余校正器→router→overlap corrector：链路完整，
     `ppg_adc_pipeline_overlap_corrector.v`第1792-1795行正确接收
     `i_detect_code`等输入，第1815-1822行正确输出到`dec_overlap_*`一组wire。
  2. overlap corrector→可编程重构器：链路完整，
     `ppg_adc_programmable_reconstructor.v`第1861-1868行正确接收这组
     `dec_overlap_*`输入。
  3. **链路在这里断掉**：可编程重构器自己的8个诊断输出端口
     （`o_detect_code`/`o_stage1_raw`/`o_stage1_code_ext`/`o_stage2_raw`/
     `o_stage2_code_ext`/`o_nominal_15_code`/`o_nominal_15_valid`/
     `o_nominal_saturated`）在AMI例化调用里全部是`.o_xxx()`空连接（第
     1893-1900行"留空"），重构器模块本身确实有这些输出端口（合同
     `PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md`§5.3要求"同时
     逐位透传...S1_RAW/S2_RAW、D1_EXT/D2_EXT、nominal_15_code"），只是AMI没接。
  4. 即使AMI把重构器这8个输出接上，DC恢复模块自己完全没有对应的8个输入端口
     可以接收——`ppg_adc_dc_recovery.v`端口列表里这组字段整体空白，这是
     §11.3要求的直接实现缺口。
- **和"9-bit准确码值"功能正确性的关系（不影响，但也不构成"可以不修"的理由）**：
  这组信号被合同独立定性为"仅供对照和诊断的固定黄金码"，真实测量数据通路走的
  是S1校准器的`calibrated_s1_value`（1.7节已验证），链路断在这里不会污染
  测量结果——但"不影响功能正确性"只说明这不是紧急缺陷，不代表这组合同明确
  要求的诊断透传能力可以无限期不做。ASIC流片后的调试/表征通常正是靠这类
  诊断透传链路对照黄金模型定位问题，长期空着会在真正需要调试的时候才发现缺口。
- **建议**：在`ppg_adc_dc_recovery.v`新增这8组input+对应o_前缀output（纯
  `assign o_x = i_x;`透传，位宽和现有overlap corrector/重构器同名字段完全
  一致，模式上是这个模块族已经反复用过的标准写法，没有新发明的余地），然后在
  AMI里把重构器现在留空的8个输出接进新增的DC恢复输入。风险低、范围明确，
  可以按标准三件套流程直接做，不需要额外的架构讨论。

## 2. PLAUSIBLE 待澄清项（复核后仍需要用户/合同裁决，不能单方面动手改）

### 2.1 `ppg_peak_valley_window_detector.v`：CHARACTERIZATION模式下的ACTIVE配置合法性豁免——**已修复**

**修复状态（2026-08-23）**：不需要新增"非正式标记"字段——AMI合同§8.5"CHARACTERIZATION
运行档案隔离"一节给出了系统级设计意图："CHARACTERIZATION的测量分支仍可完成
Stage1/Stage2、FIR、动态基线、峰谷和精度相关数据处理，但这些算法输出不得反向
开启tracking或校准请求"（第869行）——"非正式"这个属性是靠AMI在fork边界把
CHARACTERIZATION结果隔离出tracking/校准闭环之外实现的，不是靠给每笔峰谷事件
单独打标记；下游（AMI/supervisor）本来就知道整个RUN的`i_run_profile`。

结合`PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`§7/§7.1对CHARACTERIZATION
各子场景的具体定义（外部固定电流表征、STATIC_BIAS、固定精度纯RED运行）逐一核实：
§7.1固定精度纯RED运行是CHARACTERIZATION里唯一会真实驱动峰谷检测算法的子场景
（真实光电二极管输入，只是精度锁定不做9↔15自动切换），这个子场景恰恰需要
`peak_confirm_count`/`min_peak_to_peak_frames`等6个数值门限保持真实生效才有
表征意义，不该被放宽；STATIC_BIAS"不允许启动ADC事务"使`flag_red_time_transfer`
永远不触发，`flag_formal_sample`因此永远为0，这6个门限是否为0对STATIC_BIAS
子场景毫无影响。且这6个字段在合同§3.2表格里本来就都标注了"冻结默认值"
（3/3/20/100/600/1000），不属于"表征期间还没测出来只能先填0"的那一类参数——
只有`peak_valley_config_valid`自身（"配置commit"这个动作）才是合同§3.2"允许
0或临时值"字面上最贴切的对象。

**已实施的精确机制**：`flag_active_config_legal`（V1.2→V1.3）只把
`i_peak_valley_config_valid`这一项改成`(i_peak_valley_config_valid ||
i_characterization_mode)`，其余6个`!= 0`数值门限原样保留、两种运行档案下都
强制非零，不是笼统给整个信号加`|| i_characterization_mode`。iverilog编译通过、
Erie严格门禁`delivery_ready=True`（0/0）、独立lint（0/0），PWI+5个真实子模块、
AMI+全部14个真实子模块两级elaborate均0 error。

**合同同步——已完成（2026-08-23）**：`PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md`
§3.2/§3.3已补充澄清文字，明确"CHARACTERIZATION允许0或临时值"只指
`peak_valley_config_valid`一项，其余6个数值门限两种运行档案下均强制非零，
并给出了两点理由（6个字段已有冻结默认值、`PPG_DIGITAL_TOP_INTERFACE_
CONNECTION_CONTRACT.md`§7.1固定精度RED表征场景依赖这些门限保持真实生效）。
**只改了正文内容，没有改顶部"Current normative version"版本号**——核实发现
这份合同的V2.6版本号被C18/C19/C23/C25共4份合同的依赖声明和
`PPG_CONTRACT_CLOSURE_MATRIX.md`的内容哈希记录同时引用，贸然bump版本号会让
这5处引用瞬间变成不一致，超出"补一句澄清"的范围，所以保持版本号不变，只更新
正文措辞。

### 2.2 `ppg_peak_valley_window_detector.v`：reacquire期间峰峰间隔豁免范围——**已修复，合同已同步**

**修复状态（2026-08-23）**：和用户逐场景核对了`reacquire_search_active_o`
置位的全部6种触发条件后确认，"没有可靠前一波峰参照"的场景（START、周期重检
成功）本来就已经被`flag_previous_peak_valid==0`独立覆盖，`|| reacquire_search_
active_o`这条额外豁免对这两种场景是冗余的；而其余场景（9-bit不完整周期超时、
外部no-cross-limit/重检失败/精度异常回退触发、跨epoch波谷故障）里那个"上一个
波峰"始终是真实、已完整确认的正式波峰，不应该被豁免峰峰最小间隔检查。删除
这条豁免不引入死锁风险——`max_reacquire_frames`默认2.5秒的独立超时兜底比
`min_peak_to_peak_frames`默认0.25秒宽裕十倍，且真实心率（60-100 BPM，间隔
0.6-1秒）几乎不会触及这条检查，删除后不会带来有感知的恢复延迟。

`ppg_peak_valley_window_detector.v`（V1.3→V1.4）：`flag_peak_interval_legal`
删除`|| reacquire_search_active_o`一项，只保留`(flag_previous_peak_valid ==
1'b0)`和峰峰间隔达标两个条件。iverilog编译通过、Erie严格门禁
`delivery_ready=True`（0/0）、独立lint（0/0），PWI+5个真实子模块、AMI+全部
14个真实子模块两级elaborate均0 error。

**合同同步**：核实发现`PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md`
§7.1（真正的峰峰间隔检查规范定义处，不是§9.1/§9.2）原文"除9-bit启动或重新
获取的第一个波峰外"字面上确实容易读成"任意reacquire轮次的第一个候选一律
豁免"，但紧接着的下一句"第一个可靠波峰没有前一波峰，因此免除峰峰最小时间
检查"给出的理由是"没有前一波峰"——和RTL的`flag_previous_peak_valid`语义完全
对应。已把§7.1这段改写为明确说明豁免只取决于"是否存在可靠前一波峰参照"这一
个条件，并且明确指出reacquire若由不完整周期超时/no-cross-limit/跨epoch故障
触发、且参照仍然有效未被清空时，峰峰最小时间检查必须继续对其生效，不得因
处于重新获取状态就整体放行。只改了正文措辞，同1.6/2.1节的做法一样没有改
顶部"Current normative version"（仍为V2.6），避免破坏C18/C19/C23/C25及
闭合矩阵对这份合同版本号的依赖引用。

### 2.3 `ppg_coarse_detection_fir.v`：`flag_sample_qualified`缺`i_sample_valid`项——**复核确认无功能影响，可选的低优先级清理项**

**复核结论（2026-08-23）**：追踪了`flag_sample_qualified`（第299行）在全文件
唯一的下游消费路径——它只在第335行被打包进`dec_window_qualification`，而
这个组合值只有在`flag_history_transfer`（第296行，本身已经包含
`&& i_sample_valid`）为真时才会被移入持久化的窗口历史寄存器（第631/648/665/678
行四处写使能条件均以`flag_history_transfer`为前提）。也就是说
`flag_sample_qualified`在`i_sample_valid=0`时算出的值永远不会被锁存进任何
持久状态，纯组合、不可观测，**没有发现任何场景会因为这处字面缺失产生错误
行为**，属于确认过的无害问题。**建议**：不是必须修，如果以后要顺便清理，
可以在`flag_sample_qualified`公式前面补一个`i_sample_valid &&`让字面表达和
合同7.3节公式完全对齐，纯风格/未来重构健壮性收益，没有正确性收益，优先级
最低，可以留到下次动这个文件时顺手做。

## 3. 术语澄清（核实后确认不是缺陷，仅记录以免重复排查）

- **"慢漂移检测"**：`PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`
  §9对AMB周期检查的定义就是纯定时器触发（4096帧），不含独立漂移量判据——合同
  §9.7原文明确"该周期只表示检查时间，不表示每10.24秒必然调整AMB码"。RTL的
  `ppg_amb_recheck_scheduler.v`据此实现，符合合同定义，不是缺陷。DC_R/DC_IR
  倒是有真正的连续漂移判据（合同§7.3"连续确认"机制），但实现在
  `ppg_idac_code_controller.v`内部，本次核对已确认其二分搜索/确认计数算法整体
  正确，但未逐句比对合同2§7.3的措辞，留作后续如有需要可以补查的低优先级项。
- **`ppg_amb_recheck_scheduler.v`没有独立署名的书面合同**：
  `PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`第7行"目标
  RTL"列表并未点名这个文件（只写"后续测量帧调度逻辑"），但该模块头部注释、
  信号命名、与其它合同（AMI §11.4、400Hz调度器C16依赖表）的交叉引用都表明这份
  合同事实上是它的算法权威依据，只是没有正式署名。这是文档治理缺口，不是RTL
  行为缺陷。

## 4. 已确认正确、无需再查的项（10项，含核查依据摘要）

| 算法行为 | 核对范围 | 结论 |
| --- | --- | --- |
| 滤波处理 | `ppg_coarse_detection_fir.v` vs C19 | 21抽头/系数/Q16定点/舍入/饱和/帧边界清空/RED-IR双通道隔离/输出时序对中，逐项核实正确 |
| 多光源输入 | IDAC控制器、S1校准器、AMI vs C10/IDAC_V2/S1合同 | RED/IR全链路packed字段完全隔离，无交叉污染 |
| 上电AMB/DC校准 | IDAC控制器 vs IDAC_V2合同§8/§9 | 严格AMB→DC_R→DC_IR三阶段顺序，二分搜索算法（中点/收缩/耗尽处理）与合同逐项一致 |
| 周期性重检 | AMB重检调度器+400Hz调度器+AMI vs NORMAL_FORK合同§9 | 4096帧定时、三阶段FSM、真实驱动IDAC控制器重新收敛、结果确认真正回传生效 |
| 波峰波谷检测 | `ppg_peak_valley_window_detector.v` vs C22 | 波峰/波谷两条路径对称完整实现，窗口时序（含跨代际边界）正确 |
| 每周期基线生成 | `ppg_dynamic_baseline_cross_detector.v` vs C20/C21 | 逐帧连续组合求值，独立乘法器，位宽/公式匹配 |
| 非重检基线相交 | 同上 | 迟滞/3点确认/身份锁存逐项匹配 |
| 周期性重检后基线相交 | 同上 | 确认是独立于非重检路径的专用分支（`flag_resume_pending`/`flag_unknown_cross_emit`），符合合同§10.1/10.3两分支描述 |
| 基线比较切精度 / 波谷后切精度 | `ppg_precision_window_controller.v` vs C23 | 两条触发路径（cross触发 vs 波谷后触发）确认为真正独立实现，FSM方向/窗口定义正确；**唯一问题是提交门控信号语义，见1.3节** |
| 9-bit准确码值 | `ppg_adc_s1_programmable_calibrator.v`→router→overlap→reconstructor→`ppg_adc_dc_recovery.v` vs 对应各合同 | 数据源确认为S1校准器的`calibrated_s1_value`（非诊断用`detect_code`），定点数学（中心化/Q17累加/对称舍入/24-bit饱和）逐公式匹配，精度切换原子性（单一寄存器同拍锁存）正确 |

## 5. 建议的下一步

按缺陷影响面排序：

1. **1.3节（`i_precision_takeover_safe`命名不合规）——已修复**，见1.3节修复
   状态记录。
2. **1.1节（sticky被START清除）和1.2节（config_valid门控不完整）——均已修复**，
   见各自节内修复状态记录。
3. **1.4/1.5节——已核实为假阳性，不修改RTL**，见各自节内的逐拍时序推导证据
   和建议的合同措辞澄清方向（尚未实际去改合同文件，只是记录建议供以后合同
   维护方参考）。
4. **1.6节（DC恢复缺诊断透传端口）——已修复**，见1.6节修复状态记录。
5. **第2.1节（CHARACTERIZATION模式ACTIVE配置合法性豁免）——已修复，合同已同步**，
   见2.1节修复状态记录。
6. **第2.2节（reacquire峰峰间隔豁免范围）——已修复，合同已同步**，见2.2节
   修复状态记录。
7. **第2.3节（FIR的`i_sample_valid`字面缺失）——2026-08-23复核确认零功能
   影响**，可选的低优先级清理项，可以留到下次动这个文件时顺手做。

**Track B 收尾**：以上7项全部处理完毕，本轮功能完整性核对结束。
