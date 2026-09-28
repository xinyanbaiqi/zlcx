# 工作线D待查清单收尾——TRK-01 + ISE-01（2026-09-18）

> 承接`ppg_system_integration/WORKLINE_D_BATCH1_9_GAP_REMEDIATION_20260917.md`10项已修复之外剩余的
> 待查清单（详见任务brief`TASKBRIEF_WORKLINE_D_PENDING6_INVESTIGATION_20260918.md`）。本报告覆盖
> TRK-01（`tb_ppg_control_top_normal_slow_tracking.v`）与ISE-01
> （`tb_ppg_control_top_idac_bus_isolation.v`）两项，虽然分属不同TB文件，但brief已指出两者是
> "合同枚举多维度、TB只测最显眼一项"同一种缺口形态的两次独立出现，调查方法可以复用，故合并成一
> 份报告。

## 结论摘要

| ID | 结论分类 | 台账是否需要同步 |
| --- | --- | --- |
| TRK-01 | **架构限制——当前RTL下无法在不违反项目戒律的前提下合法验证，仅文档记录，未改断言** | 否 |
| ISE-01 | **真实补上了有判别力的新断言，回归PASS** | 是，已同步 |

---

## TRK-01——架构限制（未修复，仅记录）

### 调查过程

**合同原文**（§9.4.2）："Invalid tracking input or a changing payload while valid is low cannot
change evidence, pending code, committed code, or epoch."——要求的是一个**主动**场景：valid=0期间
即使payload线上的数据无效或持续变化，也不能让下游状态产生任何变化。

**既有测试现状核实**：独立重读了1016-1028行附近的现有TRK-01检查，确认brief的描述准确——进入
检查前从未调用过`task_drive_track_color`，只是快照三个值后`repeat(40)`纯静默等待、再确认没变。
这测的是"没有输入活动时状态自己不会凭空变化"，是一个几乎任何时序电路都自动满足的弱性质。

**反查`i_track_valid`真实推导链**（不能直接force，需要先搞清楚有没有合法顶层杠杆）：

1. `ppg_idac_code_controller.v`的`i_track_valid`端口接的是AMI（`ppg_adc_measurement_idac_
   integration.v:2373`）的`flag_track_branch_valid && !flag_result_abort_discard`。
2. `flag_track_branch_valid`（919/924行）= `flag_normal_track_qualified ? flag_track_branch_valid_raw
   : 1'b0`，其中`flag_normal_track_qualified`只要求`i_run_enable && flag_normal_ppg_profile &&
   (i_idac_mode==SEARCH_TRACK)`——这在TRK TB的整个跟踪场景下恒为真，不是可操作的杠杆。
3. `flag_track_branch_valid_raw`直接来自`ppg_normal_transaction_fork.v`的`o_track_valid`
   （即内部寄存器`track_valid_o`）。

**关键发现**：反查该fork自己两个独立的`always@(posedge i_clk)`块（278-309行）：`payload_o`
（承载`i_track_calibrated_s1_value`等全部payload字段的源头）只在`flag_input_transfer==1'b1`时才
装入新值（279行），否则原样保持（281行）；`track_valid_o`**同一行为、同一个`flag_input_transfer`
条件**（303/307行）。也就是说这颗RTL的结构本身就不存在"payload变化但valid仍为0"这条路径——任何
让payload真实变化的事件（无论上游怎么驱动）必然在**同一拍**把valid同时置1，两者由同一个时钟使能
条件原子驱动，硬件层面不可能独立控制。这不是TB测试手法欠缺，是RTL设计本身的结构性质。

### 结论：架构限制，未修复

- 按项目force-on-shared-net戒律，`payload_o`/`track_valid_o`不是私有单消费者信号，不能force
  （即便force，也只能测出一个真实硬件里不可能出现的组合，没有真实判别力）。
- 静态可证的补充信息：`flag_track_sample_qualified`（`ppg_idac_code_controller.v`约498行，已带
  `@satisfies: TRK-01, TRK-09`标签）是以`flag_track_transfer`打头的纯AND链，transfer=0时整条
  表达式结构上必为0，与payload字段取值无关——这个安全性质本身靠读代码就能证明，只是无法用真实
  仿真动态演示。
- 现有（较弱的）TRK-01检查原样保留：它是对另一条不同、有效性质（静默期间状态不凭空变化）的
  真实且正确通过的测试，不是错误的测试，只是不足以覆盖合同要求的主动场景那一半。
- 是否要新增专属测试注入端口（比如在fork或IDAC控制器上新增一对默认关闭的验证专用端口，类似
  项目里`i_test_calibration_loss_inject_valid`那样的既有模式），让这个主动场景变得合法可构造，
  是产品层面的架构决定，留给用户判断，不擅自新增。

### 改动内容

仅文档性改动，`tb_ppg_control_top_normal_slow_tracking.v` V1.2：在既有TRK-01检查代码块之前新增
一段详细注释（1016行附近），记录反查结论和判断依据；同步更新文件头部changelog。**未修改任何
断言/功能逻辑**。真实iverilog `-t null`语法检查确认零错误（该文件全规模真实仿真按项目已确立的
"这个规模需要xsim不建议iverilog"惯例，本次是纯注释改动不涉及功能，未重新跑全量回归）。

---

## ISE-01——真实补上新断言（已修复）

### 调查过程

**合同原文**（§9.4.7，644行）："AMB/DC code, color, type, precision, and epochs are captured
before the first preparation window of each waveform."

**既有测试现状核实**：独立重读了`flag_check_ise_snapshot_bus`门控的连续监视进程（792-817行）
和三个真实搜索阶段（AMB/DC_R/DC_IR，1053-1260行区间）的既有快照机制，确认brief的描述准确——
这套机制扎实验证了AMB/DC**码**这两项"准备窗口之前已捕获"，但color、type、precision、epoch
在这套机制里完全没有对应的捕获时点验证。

**厘清"color/type"在这个语境下具体对应哪个真实信号**：反查`ppg_sar9_sar15_safe_selection_
wrapper.v`（SSW），确认支撑AMB/DC码快照的`reg_cal_amb_code`/`reg_cal_dc_code`寄存器旁边还有
四个结构完全相同的兄弟寄存器：`reg_cal_color_ir`（颜色）、`reg_cal_frame_type`（类型，AMB_CAL
或DCS_CAL）、`reg_cal_amb_epoch`/`reg_cal_dc_epoch`（版本）。逐个读取它们各自的锁存always块
（808-938行），确认**全部由完全相同的`flag_context_fire && flag_context_is_cal`条件原子锁存**
——这套时序性质本身在`ppg_dynamic_baseline_cross_detector.v`同一份文件里已经被SID-06的调查
独立验证过（见`WORKLINE_D_SID05_SID06_20260918.md`），两次调查互相印证。

**precision的例外**：`reg_cal_precision`寄存器（253/933-938行）对**任何**校准波形都硬编码为0
（`reg_cal_precision <= 1'b0;`，938行），不像另外四项那样来自逐波形的`i_waveform_precision_
mode`快照输入——因为校准固定走SAR9（合同已知事实，ILM-11/12等已确认过）。这意味着precision
对校准语境而言是一个**结构性常量**，不是"捕获"来的值，没有有意义的"捕获时点"可以测试。如实
记录为这一项的调查结论，不强行构造一个vacuous检查凑数。

### 结论：真实补上了有判别力的新断言，回归PASS

新增`check_ise_color_type_epoch_snapshot` task（792-830行附近），在AMB/DC_R/DC_IR三个真实搜索
阶段各自已有的"准备窗口前快照"时点（与既有code快照同一拍），额外锁存期望的frame_type/color_ir/
对应epoch，真实Q3窗口关闭后直接层次化读取SSW内部寄存器核对。每个阶段只核对一次（第一个候选）
——color/type在同一阶段内结构上恒定（不像code每个候选都变），逐候选核对不会增加真实覆盖，
只会制造重复的PASS消息。

### 新增断言（file:line，均在`ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v`）

- `check_ise_color_type_epoch_snapshot` task定义：约807-841行。
- AMB阶段调用（`"ISE-01-AMB"`）：约1084-1097行。
- DC_R阶段调用（`"ISE-01-DCR"`）：约1200-1219行。
- DC_IR阶段调用（`"ISE-01-DCIR"`）：约1276-1298行。

### 回归证据

- 真实iverilog全量跑：**70 PASS / 0 FAIL**，
  `IDAC_BUS_ISOLATION_TB_PASS sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=155`。
- 真实Vivado 2022.2 xsim全量跑：**70 PASS / 0 FAIL**，与iverilog逐项一致（同样的
  `sar15_zero_checks=5305 sar9_zero_checks=5308 result_captures=155`）。
- 三条新增检查的真实PASS输出（非平凡数据，确认真实核对而非vacuous）：

```
PASS ISE-01-AMB color/type/epoch all correctly locked before the preparation window (frame_type=00 color_ir=0)
PASS ISE-01-DCR color/type/epoch all correctly locked before the preparation window (frame_type=01 color_ir=0)
PASS ISE-01-DCIR color/type/epoch all correctly locked before the preparation window (frame_type=01 color_ir=1)
```

frame_type在AMB阶段读到00（AMB_CAL）、DC_R/DC_IR阶段读到01（DCS_CAL），color_ir在DC_R读到0
（RED）、DC_IR读到1（IR）——与真实搜索阶段的身份完全对应，不是巧合数值。

既有ISE-02~10全部不受影响（同一次回归里全部PASS，逐字节复用既有机制未改动）。

## 台账同步

ISE-01判定为"已修复"，需要同步`PPG_ALIAS_MAPPING_TABLE.md`；TRK-01按brief指示"没有被判定为
已修复的项不要动台账"，不做任何台账改动。动笔前已用`ListAgents`确认没有并行会话在改动台账。
ISE-01已按`WORKLINE_D_BATCH1_9_LEDGER_SYNC_20260918.md`建立的追加式编辑方式同步。

## 2026-09-19补充：TRK-01最终收尾——用户决定不新增端口，走合同文字澄清路径

本报告正文把TRK-01的架构限制发现如实记录为"未修复"，新增专属测试注入端口的决定当时明确留给
用户判断，未擅自新增。用户随后被问到"要不要新增专属测试注入端口（类似`i_test_calibration_
loss_inject_valid`模式）"，给出的推荐是**不新增，接受架构性保证**（理由：新端口只能测一个
真实硬件里不可能出现的组合，验证价值存疑，且会给RTL增加只为满足这一条测试而存在的接口面）。
**用户采纳该推荐。**

据此正式收尾，采用本项目`C11/C14/C15`同一先例（[[project-ppg-c11-c14-c15-contract-amendment-20260907]]
"选项3"：合同文字澄清+嵌入脆弱点提醒，零RTL改动）：

1. `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.2表格后新增2026-09-19日期化
   说明——requirement原文本身不改写（这条要求依然100%成立，不是过时或过严），只澄清证据
   类型：从"应该有的动态测试"改为"结构性by-construction证明"，完整给出`flag_input_
   transfer`原子耦合的证据+`flag_track_sample_qualified` AND链的既有静态证明，并嵌入
   脆弱点提醒（未来若两个信号的时钟使能条件被解耦，必须重新核实）。
2. `PPG_ALIAS_MAPPING_TABLE.md`的TRK-01行追加第5单元格，记录这次最终决定和理由。
3. `tb_ppg_control_top_normal_slow_tracking.v`里已有的调查结论注释（V1.2，2026-09-18新增）
   保持不变，不需要因为这次决定而修改代码。

**TRK-01至此正式收尾**：不是"已修复"（没有新断言/新端口），也不是"仍待查"（用户已经拍板），
是第三种、本项目已有先例的收尾形态——**合同文字澄清关闭，零RTL/TB代码改动**。
