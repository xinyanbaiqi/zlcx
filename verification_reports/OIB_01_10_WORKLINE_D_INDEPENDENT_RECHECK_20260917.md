# OIB-01~10所有权身份反压验收ID独立复核——工作线D新批次6（家族：OIB）

> 方法声明：不信任`tb_ppg_control_top_owner_identity_backpressure.v`自己极其详尽的
> changelog（V1.0~V1.2三个版本，含OIB-01/OIB-09两次专门的真实RTL追查+一次真实RTL
> 修复即`i_context_handover_stall_request`注入端口）或`PPG_ALIAS_MAPPING_TABLE.md`
> 既有映射，全部当作"待验证的声称"。复核方法：(1)从
> `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.8（655-668行，OIB-01~10
> 逐条verbatim英文acceptance requirement）取原文，(2)读真实断言代码块和背景监视进程
> 本身，(3)特别核对合同原文里并列枚举的多个失效模式（如OIB-06"no loss, duplication,
> recoloring, retyping, or precision relabeling"五种失效模式）是否每一种都有对应的
> 检测逻辑，不是笼统一个监视进程就都算数。
>
> **状态：OIB-01~10全部10项完成断言级复核**。结论：**1个真实缺口（OIB-06）+2个结构性
> 条款按既有证据类别处理（OIB-04/10，非缺口）+7项CONFIRMED**。这份文件的自我记录质量
> 是本轮五个批次里最高的——OIB-01和OIB-09都经过专门的真实RTL/多文件追查才确定"此路
> 不通"或"需要帧身份作用域的构造"，不是简单跳过；OIB-01的追查过程中还真实修复了一处
> RTL（`ppg_sar9_sar15_safe_selection_wrapper.v`新增`i_context_handover_stall_
> request`注入端口+收窄`flag_switch_protocol_error_condition`的OR项）。但即使是这样
> 高质量的文件，独立复核依然揪出了一个真实缺口，说明"文件质量高"不能替代"逐条核对
> 合同原文"这一步。

## 真实缺口：OIB-06——顺序保序监视进程只查"是否递减"，合同要求的另外四种失效模式全部没查

**合同原文**（§9.4.8，664行）："Accepted transactions and results preserve order with
**no loss, duplication, recoloring, retyping, or precision relabeling**."——五种明确
列举的失效模式：丢失、重复、换色、换类型、精度错标。

**TB实际实现**（923-943行，"结果身份顺序与非递减核查进程"）：

```verilog
always @(posedge i_clk) begin
    if(o_measurement_result_valid && i_measurement_result_ready) begin
        if(!flag_order_first_seen) begin
            flag_order_first_seen <= 1'b1;
        end else if((o_result_frame_id < reg_last_result_frame_id) ||
            ((o_result_frame_id == reg_last_result_frame_id) && (o_result_sample_index < reg_last_result_sample_index))) begin
            cnt_order_violation <= cnt_order_violation + 1;
            ...
        end
        reg_last_result_frame_id <= o_result_frame_id;
        reg_last_result_sample_index <= o_result_sample_index;
    end
end
```

这段逻辑唯一判定的是"这次结果的frame_id/sample_index是否比上一次**更早**（递减）"——
只对应合同五种失效模式里的"顺序"这一个隐含维度，对另外四种：

- **重复（duplication）**：如果`o_result_frame_id`和`o_result_sample_index`与上一次
  **完全相同**（真正的重复投递），判定条件是`(frame_id < last)`（假，因为相等不小于）
  `|| (frame_id==last && sample_index < last_sample_index)`（假，因为相等也不小于）——
  两项都为假，**这次重复不会被计入`cnt_order_violation`**，会被监视进程直接放行且
  静默更新`reg_last_result_*`为同一个值。逐位核实：这是布尔代数上的真实漏洞，不是我的
  猜测。
- **丢失（loss）**：如果`frame_id`从1跳到3（跳过2，一次真实丢失），`frame_id`是
  **递增**的，不触发"递减"判据，同样不会被计入。
- **换色/换类型/精度错标（recoloring/retyping/precision relabeling）**：这个监视
  进程只追踪`frame_id`/`sample_index`两个字段，从未读取或比较过`o_result_color_ir`/
  `type`/`precision`这类身份字段本身——即使同一个frame_id+sample_index组合两次出现
  却带着不同的颜色/类型/精度，这个进程完全看不见。

**与OIB-07的关系**：OIB-07（1619-1650行）确实核对了单笔结果的frame/sample/color/
precision是否匹配"这笔事务自己commit时刻的快照"——但那是**单笔事务的自证**（这笔
结果对不对得上它自己），不是**跨越整个结果流的重复/换色检测**（第二次出现的同一个
frame/sample组合，是否被错误地贴上了不同的颜色标签）。两者是合同分别列出的不同性质
要求，不能相互替代。

**修复方向明确、风险低**：把判据从"是否递减"扩展为"frame_id/sample_index组合是否与
上一次相同（重复）"+"跳跃幅度是否超过预期的单调步进（丢失）"，并在监视进程里加入
color/type/precision字段的比对——不涉及RTL，只是这一个`always`块的判据需要重写。

## 结构性条款说明（OIB-04/OIB-10，不计入缺口）

- **OIB-04**："Legal public lifecycle and downstream conditions induce the...branches
  without direct force, hierarchical write, source-`valid` suppression, or replacement
  of any internal ready signal."——这是对本文件其余全部OIB检查**如何构造**的方法论
  约束，不是一个独立可运行的场景。独立核实：全文件搜索`force`/`release`关键字**零
  命中**，与文件自己模块头注释（66-69行）"全部通过合法顶层公开输入诱导，不force/不
  hierarchical写/不替换任何内部ready信号"一致，视为通过检验，不计入缺口。
- **OIB-10**："Static ready/valid analysis and dynamic traces show no combinational
  ready loop; exact independent internal-fork branch stalls remain covered by **FFK/AMI
  unit regression evidence**."——合同原文本身就指向"由FFK/AMI模块级单元回归证据覆盖"，
  不要求本文件自己提供，是与G-FP-05/TOP-10/P12同一证据类别的结构性条款。本次未去
  验证FFK/AMI单元级回归证据是否真实存在，如实记录为本批次范围边界之外，不定性为缺口。

## CONFIRMED项要点说明（7/10）

- **OIB-01**（1712-1769行）：V1.1真实构造完成——持有`i_context_handover_stall_
  request`跨越RED接管点，确认只有Scheduler非阻断launch-timeout置位、SSW阻断sticky
  保持0；恢复支释放stall后确认干净的新owner提交、无残留阻断故障。changelog记录了
  这背后一次跨多文件的真实RTL追查过程，且这次追查本身导致了一处真实RTL改动
  （新注入端口+收窄OR项），不是事后编的理由。
- **OIB-02**（1054-1258行）：RED/IR两个颜色各自的deadline超时支（非阻断诊断、无
  half-commit、无阻断sticky、无supervisor记录）+RED恢复支（deadline前释放，确认
  atomic ownership+恰好消耗一个sample_index+后续流水线持续推进）。
- **OIB-03**（1323-1404/1819-1832行）：输出反压下owner活动独立推进+held结果不静默
  丢弃+释放后及时消费+STOP-during-held-result产生恰好一次DISCARD_STOP记录+
  reset-during-held-result清空但不产生discard事件，五个子场景分别独立验证。
- **OIB-05**（1669-1673行）：完整排空后的重复/无主DONE不产生第二次completion或
  formal result。
- **OIB-07**（1619-1650行）：精确等在`o_measurement_result_valid`拉高的那一拍读取
  身份字段（frame/sample/color/precision），避免了晚几拍读到下一个空槽复位值的构造
  陷阱（changelog bug(8)记录）。
- **OIB-08**（1439-1462行）：abort后原owner身份保留，迟到DONE以success=0释放，无
  formal/algorithm-side transfer产生。
- **OIB-09**（1541-1603行）：V1.2真实构造完成——帧身份作用域的before/after对比
  （而非同循环快照），真实观测到DC_R epoch跨帧推进后before/after两帧分别绑定正确的
  自身锁存epoch。changelog记录了三次真实构造bug的完整调试过程，包括一次对RTL锁存
  时序（`macro_frame_safe_boundary_o`与`flag_frame_start_eligible`同拍读取的一拍
  滞后现象）的真实追查。

## 完整复核表（10/10全部完成）

| ID | 场景（文件行号） | 结论 |
| --- | --- | --- |
| OIB-01 | 1712-1769 | CONFIRMED |
| OIB-02 | 1054-1258 | CONFIRMED |
| OIB-03 | 1323-1404/1819-1832 | CONFIRMED |
| OIB-04 | 全文件方法论层面 | 结构性条款，非缺口 |
| OIB-05 | 1669-1673 | CONFIRMED |
| OIB-06 | 923-943 | **真实缺口**——只查递减，重复/丢失/换色/换型/精度错标均未查 |
| OIB-07 | 1619-1650 | CONFIRMED |
| OIB-08 | 1439-1462 | CONFIRMED |
| OIB-09 | 1541-1603 | CONFIRMED |
| OIB-10 | 指向FFK/AMI单元证据 | 结构性条款，非缺口（未验证外部证据是否存在） |

## 与今日工作线B回归的交叉核对

`tb_ppg_control_top_owner_identity_backpressure.v`今日回归报告
`OWNER_IDENTITY_BACKPRESSURE_TB_PASS`，`order_violation_count=0`——这个0本身是真实的
（现有判据下确实没有检测到"递减"），但本报告揭示的缺口恰恰是"这个计数器的判据范围
比它的名字和合同要求暗示的要窄"，不是这次回归本身有问题。
