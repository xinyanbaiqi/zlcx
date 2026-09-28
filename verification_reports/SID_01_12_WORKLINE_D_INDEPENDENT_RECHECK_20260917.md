# SID-01~12启动IDAC校准验收ID独立复核——工作线D新批次3（家族：SID）

> 方法声明：本文档不信任`tb_ppg_control_top_startup_idac_calibration.v`自己的changelog
> （含"SID-11双向饱和数学不可达，改用专属注入端口"这类已经很有说服力的真实分析）或
> `PPG_ALIAS_MAPPING_TABLE.md`SID相关行的既有映射，全部当作"待验证的声称"。复核方法：
> (1)从`PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.1（545-560行，SID-01~12
> 逐条verbatim英文acceptance requirement）取每条原文，(2)逐段读本文件真实的
> `if(...)...$display("FAIL ...")...cnt_error=cnt_error+1`断言代码块，(3)特别注意
> 合同原文里"每个/each/every"这类量词覆盖的范围，与TB实际检查覆盖的范围逐一核对是否
> 匹配。
>
> **状态：SID-01~12全部12项完成断言级复核**。结论：**4个真实缺口（SID-03/04/05/06）
> +4个次要观察（SID-08/09/10/11，不计入缺口数但供参考）+4项CONFIRMED（SID-01/02/07/
> 12，SID-02另有一个次要观察）**。四个真实缺口里前三个（SID-03/04/05）共享同一个根因，
> 作为一组呈现。

## 真实缺口1（根因，覆盖SID-03/04/05）：AMB子阶段的三项协议时序检查从未延伸到DC_R/DC_IR子阶段

启动IDAC搜索分三个子阶段顺序执行：AMB→DC_R→DC_IR（`sid_amb_stage`/`sid_dcs_r_stage`/
`sid_dcs_ir_stage`三个独立`begin...end`块，1049/1161/1213行）。SID-03/04/05三条合同
要求分别是：

- **SID-03**（合同545-560行原文）："AMB_CAL, DCS_CAL RED, and DCS_CAL IR **each** use
  local Q3=266..."——三个子阶段各自都要测。
- **SID-04**："**Every evaluated candidate** uses eight physical SAR9 subframes whose
  adjacent Q3 centers are exactly 625 ticks apart..."——每个被评估的候选（不分子阶段）
  都要测625拍间隔。
- **SID-05**："**Each** calibration ADC owner commits no later than local tick
  248..."——每一个校准owner（不分子阶段）都要测248拍截止时限。

**TB实际实现**：
- SID-03的tick窗口检查（`reg_sampled_tick != 10'd265 && != 10'd266`）**只出现在AMB子
  阶段**（1115-1118行）。DC_R子阶段（1161-1210行）和DC_IR子阶段（1213-1254行）都通过
  `wait_q3_release_and_sample`真实采样了`reg_sampled_tick`，但两处的`if`判断链
  （1183-1190/1231-1236行）都只检查LED极性和AMB码保持，从未比较过tick值。
- SID-04的625拍间隔检查（`time_this_q3 - time_prev_q3 != 625*500`，1131-1136行）用的
  `time_prev_q3`/`time_this_q3`是`sid_amb_stage`这个`begin...end`块内部的局部变量
  （1050/1055行声明），DC_R/DC_IR两个阶段块里根本没有声明同名变量，**结构上不可能做
  这项检查**，不是"忘了写if"，是变量作用域从设计上就没有覆盖到后两个阶段。
- SID-05的248拍截止时限抑制检查（`flag_sid05_injected`门控，1052/1065-1107行）只在AMB
  候选循环的**第一次迭代**触发一次，DC_R/DC_IR阶段的候选循环（1166-1199/1217-1243行）
  没有对应的注入点或检查。

三条要求的合同原文都明确不局限于某一个子阶段（"each"/"every"），但TB把这三项协议级
时序检查全部只实现在AMB子阶段，DC_R/DC_IR子阶段只验证了"最终收敛到正确目标码"这个
结果性质，没有重复验证过程性质的协议时序。这是同一处代码结构决策（三个子阶段各用
独立作用域的`begin...end`块，时序检查变量只在第一个块里声明）连带产生的三条缺口，
不是三处独立疏漏。

## 真实缺口2：SID-06——挂靠在SID-04的检查上，自己的合同条款从未被测试

**合同原文**："Candidate, confirmed AMB code, color, type, and epochs are captured
before preparation; an update after tick 385 affects only the next subframe."——这条
测的是候选/已确认AMB码/颜色/类型/epoch这些快照必须在"准备"阶段之前就已锁定，且
tick 385之后如果有新的更新提交，只能影响下一个子帧、不能扰动当前正在进行的子帧。

**TB实际实现**：本文件唯一提到"SID-06"字样的地方是1156行的PASS消息
`"PASS SID-04/06 AMB stage converged to target code 64 with real physical candidates
625 ticks apart"`——它的真实判定条件（1149-1155行）是`!flag_amb_converged`→FAIL
"未收敛"、`reg_confirmed_amb_code != 64`→FAIL"收敛到错误码"，两者都只测"AMB搜索最终
有没有收敛到正确目标码"，跟"快照何时锁定"/"tick 385之后的更新只影响下一子帧"完全是
两件事。全文件没有任何场景在搜索进行中途改变候选/AMB码/颜色/类型/epoch并观察生效
时机，SID-06自己的合同条款事实上零覆盖，只是被贴上了SID-04检查的标签。

## 次要观察（不计入缺口，置信度较低或严重度较小，供参考）

- **SID-02**（1039-1046行）：只显式检查"入口先进AMB"这一句。后续AMB→DC_R→DC_IR的
  顺序推进虽然结构上由三个阶段循环各自等待"进入下一阶段专属状态"来隐式保证（如果RTL
  把某阶段跳过，循环会一直等不到目标状态，最终以`C_CANDIDATE_GUARD_MAX`耗尽的通用
  FAIL收场，不会打"SID-02"标签但确实会FAIL），但合同原文"不能跳过或重复"里"重复"
  （比如AMB→DC_R→又回到AMB）这一半没有对应的防护——候选循环只关心"有没有到达目标
  状态"，不关心"有没有先倒退回上一个阶段"。是否构成真实风险取决于`ppg_idac_code_
  controller.v`真实FSM是否存在能倒退的路径，本次未反查RTL确认，如实记录。
- **SID-08/SID-09**（1174-1193/1225-1238行）：验证了LED窗口极性+AMB总线保持已确认码，
  但没有验证DC总线在采样窗口内是否真的携带"当前正在被评估的候选值"本身（只在阶段收敛
  后验证了最终码是否正确，80/96）。
- **SID-10**（864-944行）：合同"exactly eight matching successful results contribute
  to each candidate evaluation"这个正向计数子句未见对应检查；"wrong type、color、
  sample index、code snapshot、epoch"五个维度用一个统一的"身份注入"机制笼统覆盖，
  未逐字段单独构造。
- **SID-11**（961-1017行）：确认了"未升级为硬故障"+"AMB码未推进"，但合同"must produce
  the specified protocol diagnostic"这半句——是否有一个具体的软诊断位/事件被正向确认
  置位（而不只是确认硬故障没有发生）——从读到的代码看不够清楚，需要进一步反查
  `ppg_idac_code_controller.v`的饱和拒绝路径才能下定论，本次未做，如实记录。
- **SID-12**（1306-1322行）：耗尽场景的"fault/exhausted asserted"+"startup_search_
  complete保持低"+"NORMAL持续阻塞3000拍"三项验证扎实，但合同"search exhaustion keeps
  the boundary code"（耗尽后边界码本身应保持不变）这一小句未见对应检查。

## CONFIRMED项说明

- **SID-01**（825-860行）：exactly one boundary pulse + 零波形/owner/frame/result推进，
  与合同逐字对应。
- **SID-07**（1119-1129行）：AMB_CAL期间双LED关闭+DC总线不活动，真实极性约定（LED_low
  后缀实际1=点亮）与SMOKE-18已确立的项目惯例一致，本文件自己的changelog记录过第一版
  猜反极性的真实调试过程。
- **SID-12正向半句**（1256-1282行）：`startup_search_complete`在任何NORMAL owner之前
  正确置位+NORMAL确认真实解除阻塞，独立于上面提到的"边界码保持"这个次要观察。

## 完整复核表（12/12全部完成）

| ID | 场景（文件行号） | 结论 |
| --- | --- | --- |
| SID-01 | 825-860 | CONFIRMED |
| SID-02 | 1039-1046（+隐式顺序保证） | CONFIRMED（"重复"半句为次要观察，见上） |
| SID-03 | 1115-1118（AMB）/1174-1193（DC_R,缺失）/1225-1238（DC_IR,缺失） | **真实缺口**（缺口1） |
| SID-04 | 1131-1136（AMB）/DC_R/DC_IR均无对应 | **真实缺口**（缺口1） |
| SID-05 | 1065-1107（仅AMB第一候选） | **真实缺口**（缺口1） |
| SID-06 | 1149-1157（挂靠SID-04，自身条款零覆盖） | **真实缺口**（缺口2） |
| SID-07 | 1119-1129 | CONFIRMED |
| SID-08 | 1174-1193 | CONFIRMED（DC总线候选值未核对为次要观察） |
| SID-09 | 1225-1238 | CONFIRMED（同SID-08次要观察） |
| SID-10 | 864-944 | CONFIRMED（"恰好8笔"+五维度逐字段为次要观察） |
| SID-11 | 961-1017 | CONFIRMED（"专属诊断"半句为次要观察） |
| SID-12 | 1256-1332 | CONFIRMED（"边界码保持"半句为次要观察） |

## 与今日工作线B回归的交叉核对

`tb_ppg_control_top_startup_idac_calibration.v`今日回归报告
`STARTUP_IDAC_CALIBRATION_TB_PASS`，与本次独立复核读到的断言代码一致——现有检查全部
真实通过，本报告的缺口指的是"合同要求的检查范围比TB实际实现的范围更宽"，不影响现有
PASS结论。
