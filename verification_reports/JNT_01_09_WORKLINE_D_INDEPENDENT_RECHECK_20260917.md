# JNT-01~09联合基线验收ID独立复核——工作线D新批次1（家族：JNT）

> 方法声明：本文档不信任`tb_ppg_jnt_baseline_prefix.vh`自己详尽的V1.0/V1.1版本changelog
> 或`PPG_ALIAS_MAPPING_TABLE.md`/`MEMORY.md`里"JNT-01~09 baseline complete"这类既有结论，
> 把它们全部当作"待验证的声称"。复核方法：(1)从`PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md`
> 原文（§6物理波形时序、§7 ADC owner和完成链）取每条verbatim的"至少检查"/"必须覆盖"
> 要求，(2)独立读被架构方案A移植前的源TB（`tb_ppg_scheduler_ssw_ami_integration.v`
> `run_jnt_baseline` task，孤立三模块、52子检查、被移植文件自己声明为"语义来源"）逐条
> `check_case`断言的真实布尔表达式，(3)逐条与移植后（`tb_ppg_jnt_baseline_prefix.vh`
> `run_jnt_baseline_01_09` task，53子检查，真实跑在`ppg_control_top`上）对应位置的
> `jnt_check_case`断言做真实布尔表达式级比对，不是只看`case_id`字符串是否眼熟，
> (4)必要时反查RTL确认信号是否仍然真实存在、机制是否仍然适用。
>
> **状态：JNT-01~09全部9项完成断言级复核**。结论：**5个真实开放缺口**（JNT-02/03/05/
> 07/08）+**4项CONFIRMED**（JNT-01/04/06/09）+**1个连带的ID标签漂移问题**（不计入缺口
> 数，但影响可读性，见文末）。今天（工作线B）刚重跑的19-TB回归里，全部5份包含JNT基线
> 的Group文件均报告`JNT_BASELINE checked=53 pass=53 required=53 status=PASS`——这个
> PASS只证明"现有断言都成立"，不证明"该断言的内容覆盖了合同要求"，本次找到的5个缺口
> 全部是后一种类型：现有断言没错，但合同要求检查的某个子句在移植时被静默丢弃了。

## 真实缺口1：JNT-02——"IR可以在RED owner未释放时预建立"整条检查移植后完全消失

**合同原文**（`PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md:192`，§6"物理波形时序"，明文列在
"至少检查"清单第5条）："IR可以在RED ADC owner未释放时预建立，但不改变RED波形"。

**源TB实现**（`tb_ppg_scheduler_ssw_ami_integration.v:6286-6291`）：JNT-02A之后用独立
while循环（watchdog 250拍）等待`flag_ir_context_while_red_inflight`置位，断言该flag为真
且`cnt_red_waveform_context==1 && cnt_ir_waveform_context==1`。该flag的赋值逻辑
（`:4291-4293`）：当IR侧`o_waveform_context_valid && o_waveform_context_ready`握手发生
时，若`o_scheduler_transaction_inflight`为真且当前owner是RED（`reg_last_owner_color_ir
==1'b0`），则置位——真实验证的正是"IR波形上下文在RED ADC owner尚未释放时就已经预建立"
这个合同明文要求的时序关系。

**移植后**（`tb_ppg_jnt_baseline_prefix.vh`）：JNT-02A（570行）之后直接调用
`jnt_wait_conversion_phase`（571行）+`jnt_check_idac_bus("JNT-03-IDAC")`（572行），全程
没有任何等待或断言涉及"IR上下文在RED未释放时接管"这件事——不是重命名、不是合并进别的
检查，是内容完全消失。该文件自己极其详尽的V1.1版本changelog专门用4段文字逐一交代了
JNT-02/03/05/06/07/08/09每一处相对源TB的偏离原因（`:104-156`英文/`:246-294`中文），
唯独对这一条只字未提。

**该机制在ppg_control_top上依然可测**：`o_waveform_context_valid`/`o_waveform_color_ir`
是Scheduler模块的真实端口（`ppg_400hz_frame_calibration_scheduler.v:116,120`），Scheduler
是`ppg_control_top`的直接子模块、原样例化，不存在"新架构下这个信号不存在"的可能——可以
用本文件已有的同款两跳层次引用手法（参照330-338行`w_jnt_owner_ready`等既有别名）补上，
不需要新增RTL端口。

## 真实缺口2：JNT-03/JNT-02/JNT-07——owner身份与预建立波形上下文一致性检查全部消失

**合同依据**（`PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md:213`，§7"ADC owner和完成链"）："必须
覆盖...frame、sample、color、precision、transaction type、code、epoch任一字段错配"作为
error path——这条baseline要先证明"正常情况下这些字段确实一致"，才谈得上后续错配路径
有意义。

**源TB实现**：`flag_owner_context_identity_match`（`:4308`定义）在owner提交时比对
`o_adc_owner_precision_mode`/`amb_code_snapshot`/`dc_code_snapshot`是否与更早的
waveform-context握手快照一致，在JNT-02A（RED，`:6283`）、JNT-03B（IR，`:6303`）、
JNT-07A（RED/SAR15，`:6364`）、JNT-07D（IR/SAR15，`:6375`）四处owner身份断言里全部作为
必要条件之一。

**移植后**：对应四处断言——`tb_ppg_jnt_baseline_prefix.vh`的JNT-02A（570行）、JNT-03A
（583行，因下方"ID标签漂移"实为源规格JNT-03B的内容）、JNT-07A（644行）、JNT-07D（655
行）——全部只保留color+sample_index（07A/07D额外保留precision_mode），未见
`flag_owner_context_identity_match`等价物。四处一致性缺失，不是单点疏漏。

## 真实缺口3：JNT-05/JNT-08——"success=0路径不产生正式测量结果"这一子句丢失

**合同原文**（`PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md:217`，§7列表最后一条）："`success=0`
匹配完成只释放owner，不产生正式成功结果、IDAC消费或校准成功"。

**源TB实现**：JNT-05B（`:6331-6332`）和JNT-08（`:6404-6405`）均含
`(cnt_measurement_result == cnt_result_before)`，验证abort迟到DONE/STOP排空DONE两条
success=0路径都没有偷偷产生一笔正式测量结果。

**移植后**：`tb_ppg_jnt_baseline_prefix.vh`的JNT-05B（611行）只保留
`(!reg_jnt_last_completion_success) && (reg_jnt_last_completion_sample_index==0) &&
!w_jnt_transaction_inflight && !w_jnt_owner_inflight`；JNT-08（685行）同样只保留
对应四个条件——两处都缺"没有产生正式结果"这一验证。**补测在结构上完全可行**：包含方
Group文件（如`tb_ppg_control_top_baseline_cross.v:353`）本身已声明
`cnt_measurement_result_valid`计数器并在正式结果产生时递增，只需在调用点前后各拍一次
快照即可，不需要新信号。

**说明**：JNT-08的`success`期望值本身（源TB断言1，本项目早先按真实合同
`PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md:1070`修正为0，见移植文件
V1.1 changelog第3点）这处修正是正确的，与本条缺口是两件独立的事——本条缺口是"结果计数
子句"缺失，不是success极性问题。

## 真实缺口4：JNT-07——RED/IR身份一致性检查缺失（同缺口2，独立列出因场景不同）

已计入缺口2的四处清单（JNT-07A/07D），此处不重复展开；JNT-07的IDAC bus（07B/07E）、
完成（07C/07F）、fault-blocking清除（07F）三部分内容对照源TB确认完整，只有身份一致性
这一项缺失。

## CONFIRMED项说明

- **JNT-01**：移植版用`cnt_jnt_owner_commit==0`验证"未生成owner"，源TB额外检查
  `reg_startup_boundary_sample_index==16'd0`——但该寄存器只在owner提交时更新，本场景
  从未有owner提交，其值必然停留在复位默认值0，属于源TB场景下的冗余条件，移植版省略不
  构成真实缺口。
- **JNT-04**（源规格）：内容完整对应到移植版的"JNT-03B"（593行，含完成success/
  sample_index/fault-blocking/inflight清除全部条件），另有一条冗余的"JNT-04"标签
  （596行）重复检查其中success/sample_index两个子条件——内容不缺，只是编号漂移+一处
  冗余（见文末）。
- **JNT-06**：源TB的`flag_reset_done_observation`是TB自己确认"复位+旧DONE"这个脚本化
  时序真的按预期发生过的自检标志，不是DUT行为断言；移植版省略该flag，但保留了核心DUT
  断言（完成计数不变+transaction/owner inflight清零），不构成真实缺口。
- **JNT-09**：`JNT-09-STARTUP`与`JNT-09`两条断言的真实布尔表达式与源TB逐项对应（含
  deadline sticky+transaction/owner inflight+ssw/ami fault-blocking四项），仅watchdog
  上界替换为本文件自己的常量，属已在header里说明过的合理适配。

## 次要观察（不计入真实缺口，供参考）

源规格JNT-02A/JNT-03B原本各带一个owner提交时序上界（`reg_last_owner_macro_tick<=13'd283`
/`<=443`），移植版未见对应数值。这两个具体数值本身在`ppg_control_top`真实V4生命周期下
是否还有意义、该测多少，需要重新实测才能判断（同类"旧数字不能直接套用"的问题，本文件
header已对四个watchdog上界常量做过一次这样的说明，但没有覆盖到这两个内嵌在check_case
条件里的具体时序数字）——不确定性较高，本次不计入"真实缺口"，留供后续参考。

## 完整复核表（9/9全部完成）

| ID | 场景 | 结论 |
| --- | --- | --- |
| JNT-01 | `run_jnt_baseline_01_09` JNT-01段（565行） | CONFIRMED |
| JNT-02 | 同上 JNT-02段（568-578行） | **真实缺口**——IR预建立检查完全消失（缺口1）+身份一致性检查消失（缺口2） |
| JNT-03 | 同上 JNT-03段（580-596行，含IDAC bus） | **真实缺口**——身份一致性检查消失（缺口2）；IDAC bus本身内容完整 |
| JNT-04 | 同上（见593/596行） | CONFIRMED（内容完整，但有编号漂移，见下） |
| JNT-05 | 同上 JNT-05段（598-612行） | **真实缺口**——缺"不产生正式结果"子句（缺口3） |
| JNT-06 | 同上 JNT-06段（614-637行） | CONFIRMED |
| JNT-07 | 同上 JNT-07段（639-665行） | **真实缺口**——身份一致性检查消失（缺口2/4） |
| JNT-08 | 同上 JNT-08段（667-686行） | **真实缺口**——缺"不产生正式结果"子句（缺口3） |
| JNT-09 | 同上 JNT-09段（688-724行） | CONFIRMED |

## 附：ID标签漂移问题（结构性发现，不计入缺口数）

因缺口1（源规格JNT-02B整段消失），移植版从"JNT-02B"标签开始，实际检查内容相对源规格
整体下移一格：

| 移植版标签（真实运行、真实计入53子检查） | 实际检查内容对应源规格哪一条 |
| --- | --- |
| `JNT-02B`（578行） | 源规格`JNT-03A`（RED完成success+sample_index=0） |
| `JNT-03A`（583行） | 源规格`JNT-03B`（IR owner身份，缺identity_match，见缺口2） |
| `JNT-03B`（593行） | 源规格`JNT-04`（IR完成+全部fault-blocking/inflight清除） |
| `JNT-04`（596行） | 无对应——冗余重复检查，非新增覆盖 |

这个漂移不影响PASS/FAIL判定本身（每条`jnt_check_case`调用都是独立、真实的布尔比较），
但对任何后续想按"JNT-03A应该测什么"去对照源规格的读者是真实的陷阱。是否连带修正标签、
是否补齐上述4个真实缺口，是产品决定，本报告不擅自处理，等用户确认。

## 与今日工作线B回归的交叉核对

`ppg_control_top/xsim_regression_20260917`（或当天最新回归目录）5份含JNT基线的Group
文件均报告`JNT_BASELINE checked=53 pass=53 required=53 status=PASS`，与本次独立复核
读到的源码断言逻辑一致——即"现有53条检查全部真实通过"这个事实没有问题，本报告的5个
缺口指的是"合同要求检查、但现有53条检查里没有对应条目"的内容，两者不矛盾。
