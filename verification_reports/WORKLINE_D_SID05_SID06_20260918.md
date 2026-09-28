# 工作线D待查清单收尾——SID-05（仅DC_R/DC_IR部分）+ SID-06（2026-09-18）

> 承接`ppg_system_integration/WORKLINE_D_BATCH1_9_GAP_REMEDIATION_20260917.md`10项已修复之外剩余的
> 待查清单（详见任务brief`TASKBRIEF_WORKLINE_D_PENDING6_INVESTIGATION_20260918.md`）。本报告覆盖
> SID-05（仅DC_R/DC_IR部分，AMB部分本身不是缺口）与SID-06两项，均属于
> `ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v`同一份TB文件。

## 结论摘要

| ID | 结论分类 | 台账是否需要同步 |
| --- | --- | --- |
| SID-05（DC_R/DC_IR） | **真实RTL功能性bug，已修复+真实补上新断言** | 是，已同步 |
| SID-06 | **真实补上有判别力的新断言** | 是，已同步 |

两项均已通过官方TB模块级双工具（iverilog + 真实Vivado 2022.2 xsim）confirm：
`STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2`，83 PASS / 0 FAIL，两个工具逐项一致。

---

## SID-05（仅DC_R/DC_IR部分）

### 调查过程

**已知背景**：2026-09-17上一轮会话发现，把AMB阶段已验证的tick-248截止抑制verification逻辑
（`task_verify_deadline_suppression`前身）原样搬到DC_R/DC_IR阶段会导致该阶段Q3窗口永久打不开、
搜索卡死不收敛——如实转入待查清单，没有强行凑数。

**第一步：独立复核"AMB部分不是缺口"这个前提**。没有直接采信brief转述，自己重新读了
`ppg_400hz_frame_calibration_scheduler.v`。找到`flag_cal_owner_deadline`（464行，本地tick恰为
`CAL_IDAC_LOCAL_TICK`=385时提交、`C_CAL_OWNER_DEADLINE`=248截止相位）——这条信号本身是**调度器
级别的通用机制**，完全不区分当前是AMB_CAL还是DCS_CAL，只看`B_CAL_WAVE_PENDING`+本地tick位置。
这意味着理论上AMB和DC_R/DC_IR应该共享同一套deadline行为，"AMB通过、DC_R/DC_IR卡死"这个不对称
现象需要一个真实解释，不能只满足于"brief说AMB不是缺口"。

**第二步：真实iverilog实验复现死锁**（遵循方法论"必须真实跑回归"，不满足于读代码）。在scratchpad
里复制TB文件，给DC_R阶段第一个候选加一段和AMB完全同构的`task_verify_deadline_suppression`调用+
详细的逐拍`$display`跟踪（tick/idac_state/cal_valid/cal_ready/inflight/wave_pending/ctx_seen/
cal_owner_deadline/idle/owner_commit），真实跑通后逐行核对trace：

- 抑制检查本身确认通过（"no owner committed"），`flag_cal_owner_deadline`按预期只脉冲一拍（tick=248），
  `B_CAL_WAVE_PENDING`正确清零。
- 但AMI（`ppg_adc_measurement_idac_integration.v`）的`flag_calibration_request_inflight`从此永远
  保持1，`calibration_sample_valid_o`再也不会重新拉高，调度器`B_CAL_CONTEXT_SEEN`因为之后任何一次
  子帧边界都等不到新的`B_CAL_REQ_PENDING`而永久锁闭——**整个校准搜索从此卡死**，真实trace显示后续
  12/12个候选全部"real Q3 window never opened"。

**第三步：确认这不是DC_R/DC_IR专属bug，而是通用死锁，只是AMB恰好没有真实触发它**。追查AMI
`flag_calibration_request_inflight`的清零条件（1788-1799行）：只在`flag_amb_sample_accepted ||
flag_dcs_sample_accepted`（真实消费到搜索结果）或STOP/abort时清零——deadline抑制两者都不会发生。
再用同样的debug trace手法核对AMB自己的候选0：发现AMB候选0的request/accept/context-handoff/
owner-commit**在`task_verify_deadline_suppression`真正开始压idle之前就已经全部完成**（AMB是RUN
里第一个校准请求，恰好在tick 0-2附近就已经competed accept+commit，比TB的"等tick<=5"轮询还快）——
换句话说，**AMB现有的SID-05测试本身可能是vacuous的**（它观察到的"成功恢复"其实是一笔早已在途的
事务，deadline-forcing从未真正命中它）。这是本次调查的一个额外发现，记录在"边界内的额外发现"
一节，不在SID-05（DC_R/DC_IR）本次修复范围内，未改动AMB侧代码。

### 结论：真实RTL功能性bug，已修复

**根因**：AMI的`flag_calibration_request_inflight`没有为"调度器优雅降级式抑制"这条路径设计清零
出口，只认"真实消费到结果"或"STOP/abort"两种关闭方式。这不只是这次合成测试的问题——任何真实
硬件场景下物理ADC合法地晚于tick 248变idle（不是本次测试这种人为强制），都会永久搁浅当次校准搜索，
只有显式STOP才能恢复。属于该顺手修的真实bug（同PWC sticky-clear、AMI永久死锁两个既有先例同一类别）。

**修法**（三份RTL文件，均已bump版本+双语changelog）：

1. `ppg_400hz_frame_calibration_scheduler.v` V1.8：新增单周期事件输出`o_cal_owner_deadline_event`，
   直接转发既有、本来就自清零的`flag_cal_owner_deadline`组合脉冲（`assign o_cal_owner_deadline_event
   = flag_cal_owner_deadline;`）。不新增状态、不新增时序路径。
2. `ppg_adc_measurement_idac_integration.v` V1.15：新增输入`i_cal_owner_deadline_event`，接成
   `flag_calibration_request_inflight`的额外清零条件（与既有两个"结果已消费"条件并列）。
3. `ppg_control_top.v` V1.6：纯接线，新增内部wire`sched_cal_owner_deadline_event_o`把两端连起来。

**验证**：真实iverilog重跑修复后的RTL，DC_R/DC_IR的SID-05抑制测试全部PASS，真实收敛到目标码
（DC_R=80，DC_IR=96），零FAIL——见下方"新增断言"小节的完整回归数字。

### 新增断言（file:line，均在`ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v`）

- SID-05-DCR：`task_verify_deadline_suppression("SID-05-DCR")`调用见1214行起，`wait_q3_release`
  恢复检查见1219-1225行。
- SID-05-DCIR：`task_verify_deadline_suppression("SID-05-DCIR")`调用见1355行起，恢复检查
  1360-1366行。

### 回归证据

- iverilog（本次RTL修复前的对照trace + 修复后的完整回归）：修复前DC_R候选0之后**12/12候选全部
  FAIL**（"real Q3 window never opened"），DC_IR连带失败；修复后**83 PASS / 0 FAIL**，
  `STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2`。
- 真实Vivado 2022.2 xsim：**83 PASS / 0 FAIL**，与iverilog逐项一致。

---

## SID-06

### 调查过程

**合同原文**（`PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.1）：候选/已确认AMB码/颜色/
类型/epoch这些快照必须在"准备"阶段之前就已锁定，且tick 385之后的更新只影响下一子帧。

**RTL锚点确认**：`ppg_400hz_frame_calibration_scheduler.v:460`的`flag_calibration_boundary_o`
（本地tick恰为385）是IDAC控制器候选提交的唯一安全边界（经`idac_code_safe_boundary_o`→AMI
`i_idac_code_safe_boundary`→`i_frame_safe_boundary`）。进一步反查真正驱动物理总线的机制：
`ppg_sar9_sar15_safe_selection_wrapper.v`（SSW）的`reg_cal_amb_code`/`reg_cal_dc_code`寄存器
（800-811/840-851行附近）**只在`flag_context_fire && flag_context_is_cal`（本地tick 0的波形
上下文接管点）那一拍锁存新值**，两次接管之间恒定——808行注释已经明确写着"实时改变
`i_waveform_amb_code_snapshot`不会影响当前已在途波形的AMB总线，下一波形只在自身`flag_context_fire`
再次为真时才采用新码"，且这条注释已带`@satisfies: ISE-01/02/03`标签（说明这是ISE家族已经在用的
同一个真实机制，SID-06是同一个机制的第二次验证需求）。

**既有测试现状核实**：全文件搜索"SID-06"，唯一命中是1156行附近一条PASS消息（挂靠在SID-04的AMB
收敛判定上），其判定条件只测"AMB搜索最终有没有收敛到正确目标码"，跟"快照何时锁定"完全是两件事。
真实确认是零覆盖，不是部分覆盖。

### 结论：真实补上了有判别力的新断言，回归PASS

利用DC_R阶段binary search本身自然产生的真实码变化事件（不需要额外构造场景），在候选转换点
直接层次化读取SSW的`reg_cal_dc_code`内部寄存器（不是TB自己维护的镜像值），构造两段真实检查：

1. **本子帧385拍之后快照保持不受扰动**：捕获tick-385提交前SSW寄存器的值作为基线，驱动下一个
   真实候选（引发一次真实commit），跨过本子帧的385拍之后确认SSW寄存器依然是旧值（还没被这次
   刚提交的新候选扰动）。
2. **下一子帧的真实Q3采样确认新值已生效**：下一次真实Q3窗口采样到的总线值必须等于上一次tick-385
   提交的新码。

**构造过程中一次自我纠错（如实记录，遵循方法论"改动前的实验不代表应该会成功"）**：第一版把"基线"
直接在Q3采样*之前*读`reg_cal_dc_code`，真实回归报出一次FAIL（"perturbed, expected=79 observed=42"）。
没有直接怀疑RTL有缺陷，而是加了一次debug trace逐拍核对，发现问题出在TB自己：这个读取时刻SSW还没
赶上*上一次*提交（SSW只在自己的tick 0接管点刷新，而这个读取点仍处于上一次提交后、SSW尚未追上的
过渡期），读到的是更早一拍尚未生效的陈旧值，基线本身就是错的。改为从本次真实Q3采样得到的
`reg_sampled_dcn`取基线（这个值来自Q3窗口内的真实采样，保证已经过了本子帧自己的tick 0接管点，
一定新鲜）后，问题消失，真实回归PASS，且新旧两个值确实不同（old=0x42, newly committed=0x5d，
非vacuous）。

### 新增断言（file:line）

`ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v`：
- 基线捕获：1226-1230行（源自真实Q3采样`reg_sampled_dcn`）。
- 后半句（下一子帧确认生效）检查：1274-1283行。
- 前半句（本子帧内不受扰动）检查：1284-1301行。
- 顺带修正了旧的误导性"PASS SID-04/06 ..."消息，去掉"/06"标签（该消息只测SID-04的收敛性质，
  从未真正覆盖SID-06自己的条款），见1168-1174行。

### 回归证据

同SID-05（DC_R/DC_IR）共用一次运行：iverilog与真实Vivado 2022.2 xsim均**83 PASS / 0 FAIL**，
`STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2`，两工具逐项一致。真实观测到的PASS消息：

```
PASS SID-06 current-subframe waveform snapshot unperturbed past the tick-385 commit boundary (old=42, newly committed=5d, not yet visible)
PASS SID-06 next-subframe waveform snapshot correctly reflects the code committed at the prior subframe's tick-385 boundary, code=5d
```

---

## 边界内的额外发现（未处理，供用户参考）

调查SID-05时，用相同的debug trace手法独立核实了AMB阶段自己的SID-05测试（"SID-05-AMB"），发现
它可能是**vacuous**的：AMB是RUN里第一个校准请求，其request/accept/context-handoff/owner-commit
在`task_verify_deadline_suppression`真正开始压低`i_adc_physical_idle`之前就已经全部完成（真实
trace显示：从任务开始观察的第一拍起，`wave_pending`已经是0、`ctx_seen`已经是1，说明这笔候选的
owner早已提交，之后观察到的"真实Q3窗口打开"其实是这笔早已在途事务自己的正常测量窗口，不是
deadline-forcing之后的真实恢复）。尝试把idle强制提前到task最开始（在等待tick<=5之前）没能解决
——race发生得比这更早，需要更深入的调查才能确认正确构造方式。

这**不在本次SID-05（仅DC_R/DC_IR）的任务范围内**（brief明确"AMB部分本身不是缺口"），也不影响
本次DC_R/DC_IR修复的正确性（DC_R/DC_IR的deadline-suppression构造已独立验证是真实命中的，不受
AMB侧问题影响）。如实记录，留给用户判断是否值得单独立项调查AMB侧这个测试本身的有效性。

## 台账同步

按brief指示，两项均判定为"已修复"，需要同步`PPG_ALIAS_MAPPING_TABLE.md`。动笔前已用`ListAgents`
确认没有并行会话在改动台账（结果：无其它可达会话）。已按`WORKLINE_D_BATCH1_9_LEDGER_SYNC_20260918.md`
建立的追加式编辑方式同步，见该次编辑记录。

## 2026-09-19补充：全套19-TB官方回归系统级confirm

本报告正文的83 PASS/0 FAIL是`tb_ppg_control_top_startup_idac_calibration.v`**单文件模块级**回归，
没有确认SID-05的RTL改动（`ppg_400hz_frame_calibration_scheduler.v`/`ppg_adc_measurement_idac_
integration.v`/`ppg_control_top.v`三个全项目共享文件）有没有波及其它18个顶层TB场景。用户随后
明确要求补做这一步。

`run_xsim_regression.sh`已完整跑完全部19个TB（后台跑约2小时17分，中途一次Claude Code进程重启
未打断底层Vivado子进程，跑完后从磁盘日志直接核实，未依赖任何自称"已完成"的通知）。**直接grep
19份`xsim.log`原始文件**（不只信脚本自己的`summary.tsv`统计）独立确认：

- 全部19个`finish called`恰好出现1次——19个场景全部真实跑到底，没有卡死/截断。
- 直接对`FAIL |ERROR:|FATAL_ERROR|UVM_ERROR`四类关键字跑一次全量`grep -rn`，**零匹配**。
- 直接对`^PASS `关键字全量计数并求和：**1208**，比本报告发布时引用的09-17基线1202多6
  （SID-06+2、ISE-01+3、PRC-06+1，逐项数字见`WORKLINE_D_TRK01_ISE01_20260918.md`/
  `WORKLINE_D_PRC04_PRC06_20260918.md`各自的回归证据小节；SID-05本身AMB既有+DC_R/DC_IR
  新增，本次直接grep确认当前文件`PASS SID-05-`前缀恰好3条，AMB是09-17之前就有的既有覆盖、
  DC_R/DC_IR两条是本次新增——09-17基线的原始日志已被本次运行覆盖，无法逐行倒推验证增量刚好
  是多少，如实记录这一limitation，不影响"0 FAIL"这个核心结论的可信度，因为0 FAIL是本次
  运行自己独立grep验证的，不依赖新旧对比）。
- `summary.tsv`本身的`fail_count`列有一个无害的脚本cosmetic bug：`grep -c ... || echo 0`
  在真实0匹配时会同时打印grep自己的"0"和echo兜底的"0"（`grep -c`零匹配时返回码非0会触发
  `||`），导致该字段肉眼看是两个"0"、且把每条记录拆成两条物理行——不影响判断（两个"0"结果
  一样），但会让直接`cat summary.tsv`的人误以为文件损坏，特此记录，未修复脚本本身（不在本次
  任务范围内）。

**结论：SID-05这处跨3个共享文件的RTL修复，系统级19/19 PASS、0 FAIL，未观察到对其它任何场景的
负面影响。** 涉及本轮修复的3个TB文件（SID/ISE/PRC）在全套回归里的pass_count（83/70/67）与
各自报告独立汇报的模块级数字逐一一致，进一步交叉确认。
