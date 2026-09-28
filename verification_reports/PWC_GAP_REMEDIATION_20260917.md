# PWC-04/15/21/26/34/35六个真实缺口补TB证据报告（2026-09-17）

> 执行依据：`TASKBRIEF_TOP01_24_GAP_REMEDIATION_20260916.md`"PWC模块6个缺口"一节。
> PWC那个真实RTL缺陷（新START清sticky，PWC-41）是另一件事，见
> `PWC_STICKY_CLEAR_RTL_FIX_20260917.md`，不在本报告范围。

## 总体结论

6条缺口全部真实补上信号级断言证据，**RTL全程未改动**。`ppg_precision_window_controller.v`
本身未改一行——这批修复全部是TB侧断言设计缺陷（断言恒真、被别的变量顶替、采样点错误），
不是RTL功能缺陷。官方xsim回归（`module_tb_regression/run_module_tb_regression.sh`）：
**48/48 PASS**（40条原有+PWC-41新增2条+本批6处修改净增6条=48）。6条全部做了真实RTL
变异测试确认判别力：每条对应报告里描述的具体缺陷机制都被还原成一个最小mutant，新断言
在mutant上真实FAIL、在正确RTL上真实PASS。

## PWC-15——"不产生reacquire"恒真

原断言在错误的采样拍读`o_reacquire_request_event`（比PWC-16证明的真正交付拍早一拍），
把返回原因换成异常该断言依然PASS（零判别力）。**新增**第二条断言，对齐PWC-16的采样拍
（提交后多等一拍），单独核对`o_reacquire_request_event==0`；原断言其余3个子句（在
正确拍反而会失败，故保留原断言不动，新增而非替换）。变异（探针）：把返回原因换成
`RETURN_FINE_TIMEOUT`，新断言正确FAIL，原断言（检查其余3个真实子句）依然PASS——
证明新旧两条断言各自独立、互不掩盖。

## PWC-21——`o_cross_ready==0`被状态跳转顶替

原断言的`o_cross_ready==0`其实是握手后`ST_WAIT_ENTER`状态跳转导致，对`i_recheck_busy`
门控本身零判别力（对照ID PWC-06结构相同但多了`o_switch_pending==0`一项因此能抓住）。
**改动**：给原断言追加`&& (o_switch_pending == 1'b0)`。变异：移除`o_cross_ready`里的
`i_recheck_busy`项，真实FAIL（同时PWC-07依旧FAIL，交叉确认）。

## PWC-26——"报告fault"和"无假事件"零覆盖

原断言只覆盖"保持原精度/置sticky"，`o_mode_fault_event`单拍脉冲从未被断言过。**新增**
`cnt_fault_pulse`逐拍计数器（在建立超时的循环内统计`o_mode_fault_event===1'b1`的真实
出现次数），断言`==1`且循环结束后已回到0——不依赖假设具体的周期偏移。变异：移除
`mode_fault_event_o`里的切换超时触发源，真实FAIL。

## PWC-34——"不解除活动故障保持"零覆盖

原断言完全被`state_current==ST_FAULT`顶替，已连出的`o_mode_fault_active`此前40条
断言从未用过。**新增**：diag_clear前快照`o_mode_fault_active`（确认是真实活动状态），
diag_clear后新增断言`flag_case_ok && o_mode_fault_active`（确认故障保持未被诊断清除
误解除）。变异：给`flag_fault_hold`加一条`i_diag_clear_event`释放分支，真实FAIL。

## PWC-35——"仅"字排除半句零覆盖

原断言只测过idle=1这一侧，且该取值恰好等于复位默认值，零判别力。**新增**：
`request_cross`建立真实pending后，新增断言`(o_controller_idle==1'b0) && o_switch_pending`。
变异：把`controller_idle_o`硬连高，真实FAIL。

## PWC-04——表征profile下从未施加过cross/return激励

原断言只测复位后的未激励状态，46个变异体实验里PWC-04一次都没抓住任何一个。**新增**：
在CHARACTERIZATION profile下真实驱动一次`i_cross_valid`和一次`i_return_9bit_valid`，
分别断言"安全消费（ready=1）+不建立正式窗口（switch_pending/fine_window_active均0）+
置协议诊断"。变异：分别移除`o_cross_ready`/`o_return_9bit_ready`的CHARACTERIZATION
分支，真实FAIL。

## 回归证据

`ppg_system_integration/module_tb_regression/xsim_module_regression/tb_ppg_precision_window_controller/xsim.log`：
48/48 PASS，0 FAIL。别名表对应6行已追加2026-09-17说明（含具体xsim.log行号）。
