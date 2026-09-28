# FIR-01/12/19/21四个真实缺口补TB证据报告（2026-09-17）

> 执行依据：`TASKBRIEF_TOP01_24_GAP_REMEDIATION_20260916.md`"FIR模块4个缺口"一节。

## 总体结论

4条缺口全部真实补上信号级断言证据，**RTL全程未改动**（14个时序块复位分支本身早已
正确，这批全是证据缺口不是RTL缺陷）。官方xsim回归（`module_tb_regression/`）：
**103/103 PASS**（98条原有+本批新增5条=103）。其中FIR-01/FIR-12两条做了真实RTL变异
测试确认判别力（含1次真实级联失败交叉确认）。

## FIR-01——"撤销MAC"、载荷/诊断冻结值、精确计数三处零覆盖

原断言只在仿真"处女态"（从未收过事务）时复位，"撤销"这个动作根本无从发生；载荷/
诊断端口复位值零检查；计数只验证了`<21`不是`==0`。**新增**三处：(a) 复位后逐项核对
`o_filtered_ppg_value`等12个载荷/诊断端口的冻结复位值；(b) 层次化引用
`dut.cnt_red_sample`/`dut.cnt_ir_sample`精确核对`==0`；(c) 真实建立在途MAC（送样后
等4拍进入乘加阶段，确认`dut.state_current==2'b01`证明真的在途）后复位，核对撤销真的
发生（`o_result_valid==0 && 计数==0 && state_current==2'b00`）。变异：让复位不再清
`state_current`，真实FAIL。

## FIR-12——8拍空转恒真断言

原断言8拍空转期间`i_recheck_busy`恒为0，读到的只是FIR-08/11早已建立的状态，零判别力。
**改动**：在同一断言前真实驱动`i_recheck_busy=1'b1`（历史仍非空时），8拍观察窗口结束
后撤销busy，避免影响后续FIR-13场景。变异：给`flag_history_clear`加`|| i_recheck_busy`，
真实FAIL（同时FIR-27下游级联失败，交叉确认）。

## FIR-19——合同明文"自检TB必须报告该错误"未实现

原断言只覆盖"不移动历史"（CONFIRMED），"TB报告该错误"这半句从未实现。**新增**：
`cnt_protocol_violation_report`计数器，依据真实驱动的`i_frame_type`（不是硬编码判断）
在注入非NORMAL样本后检测，真实产生`[PROTOCOL_ERROR]`告警并计数，新增断言
`cnt_protocol_violation_report==1`。未做RTL变异（这条本质是TB自身指令是否落地的检查，
不是DUT行为判别）。

## FIR-21——"输入载荷保持"TB自比恒真、"只消费一次"近乎恒真

原断言用TB自己的`reg_held_payload`副本跟同一个`i_coarse_ppg_value`比（零DUT信息量，
独立核实`o_result_ready`纯组合、DUT在ready=0时本就不锁存输入，不存在可比对的DUT侧
寄存器）；"只消费一次"是`o_result_ready==1 || state!=IDLE`这个近乎恒真的析取式，从不
计数。**改动**：反压前后各取一次`dut.cnt_ir_sample`快照，busy期间核对计数不变（层次化
证明未提前消费），解除后核对精确`+1`（层次化证明恰好消费一次）。未做独立RTL变异
（DUT侧无直接单行可还原的mutant点，`o_result_ready`已确认纯组合无寄存器可动）。

## 回归证据

`ppg_system_integration/module_tb_regression/xsim_module_regression/tb_ppg_coarse_detection_fir/xsim.log`：
103/103 PASS，0 FAIL。别名表对应4行已追加2026-09-17说明（含具体xsim.log行号）。
