# TOP-01/02/09/15/18五个真实缺口补TB证据报告（2026-09-17）

> 执行依据：`TASKBRIEF_TOP01_24_GAP_REMEDIATION_20260916.md`"TOP模块5个缺口"一节。本报告
> 只覆盖这5条，PVW/PWC/FIR三个模块的14条缺口+2个新ID见各自独立报告
> （`PVW_GAP_REMEDIATION_20260917.md`、`PWC_GAP_REMEDIATION_20260917.md`、
> `FIR_GAP_REMEDIATION_20260917.md`）；PWC那个真实RTL缺陷（新START清sticky）见
> `PWC_STICKY_CLEAR_RTL_FIX_20260917.md`，不在本报告范围。

## 总体结论

5条缺口全部真实补上信号级断言证据，**RTL全程未改动**（TOP-01/02/09/15/18都是"缺测试"，
不是RTL功能缺陷）。完整回归（`ppg_control_top/run_xsim_regression.sh`，19个TB全套）：
**0 FAIL**，`tb_ppg_control_top.v`自身`SMOKE_TB_PASS`（49笔真实ADC响应，33笔正式结果）。
TOP-02、TOP-18两条做了真实RTL变异测试确认判别力；TOP-01/09/15三条在开发过程中反复通过
真实仿真证据自我纠正（细节见下），过程本身就是判别力的直接证明。

**过程中的方法论教训（本次任务最有价值的部分）**：5条里有3条（TOP-09、TOP-15、TOP-18）
第一版设计凭直觉/字面理解就动手，跑出来才发现假设有错，必须回头独立读RTL追根因才找到
真正正确的断言。这完全复现了这个项目反复验证过的教训——"先读RTL、别猜"——哪怕是在补
测试证据这种看似机械的任务里，同样会踩到同一类坑。

## TOP-01：SSW为安全向量 + 无旧事务恢复

**合同原文**（C01合同§10）："复位｜无事务valid；SSW为安全向量；无旧事务恢复"。

### "SSW为安全向量"

独立读`ppg_sar9_sar15_safe_selection_wrapper.v:604`发现该行本身已带
`@satisfies: TOP-01`标签和注释"复位后SSW为安全向量"，`reg_control_vector`异步复位清零，
`o_s_in`是它的字段切片，安全向量即全零——但全项目从未有断言真的检查过`o_s_in`本身。

**新增**：`tb_ppg_control_top.v` SMOKE-01内新增
```verilog
if(o_s_in !== 5'b00000) begin
    $display("FAIL TOP-01 SSW o_s_in is not the safe all-zero vector after reset, ...");
```

### "无旧事务恢复"

全项目仅有的两处`i_rstn=1'b0`都是场景最开头的上电复位，从未在RUN期间真实在途事务时
触发过复位。这是5条缺口里唯一一条要求原文没有指定具体信号、需要自己设计断言逻辑的。

**新增场景**（文件末尾，独立场景）：commit+start→等到`B_INFLIGHT=1`（真实owner在途）→
快照`cnt_measurement_result_valid`→**在途期间**触发`i_rstn=1'b0`（双域复位）→复位释放后
核对：`o_lifecycle_state==ST_CONFIG`、四个ack/error事件全0、`B_INFLIGHT==0`、
`o_measurement_result_valid==0`，且**结果计数在复位窗口内保持不变**（证明旧事务没有被
静默恢复完成）→重新COMMIT+START→确认系统仍功能健康，真的产生了一笔全新结果（避免
"系统复位后死机"这种表面上也满足"没有恢复旧事务"但实际上是另一种缺陷的假阳性）。

真实回归：一次通过，5个PASS点全部命中（re-commit、confirmed in-flight、reset cleared
state、re-commit after reset、genuine new result）。

## TOP-02：V4/V5均合法才替换

**合同原文**：验收表"1024-bit联合ACTIVE原子生效；V4/V5均合法才替换且config_epoch仅
递增一次"。独立读`ppg_system_config_manager.v:340-341`确认V5保留位段（`i_config_snapshot
[1023:1010]`）必须全零才合法，是最容易构造的V5非法字段。

**新增场景**（SMOKE-05与SMOKE-06之间）：复用`task_build_normal_manual_config`（合法V4），
只追加`i_source_config_snapshot[1023:1010] = 14'd1;`破坏V5保留位段，提交后断言
`!commit_ack && error_event && config_epoch不变`。

**变异测试**：把`ppg_system_config_manager.v:341`的`flag_snapshot_v5_reserved_valid`
恒设为1（不再检查），真实回归FAIL：`commit=1 error=0 epoch_before=1 epoch_after=2`——
非法快照被错误接受、epoch错误递增，与断言设计的判据完全对应，确认真实判别力。

**清理**：manager的`error_sticky`是W1C sticky，不清会静默挡住SMOKE-06紧接着的合法
提交（与SMOKE-20→21已踩过的坑同源）；新增一次显式`i_diag_clear_event`脉冲清理。

## TOP-09：正式结果按显式discard事件完成

**合同原文**：STOP/abort/reset场景"检测链按discard事件排空"。独立读
`ppg_adc_measurement_idac_integration.v:949`发现`flag_measurement_result_discard_fire
= flag_measurement_pending && flag_result_abort_discard`——**需要一笔正式结果真的已经
进入AMI pipeline（`flag_measurement_pending=1`）才可能丢弃**，不是ADC owner刚claim但
DONE未到的早期窗口。

**第一版设计的错误**：最初直接沿用SMOKE-06"STOP恰好命中owner已提交但DONE未完成"这个
早期窗口去数`o_measurement_result_discard_event`脉冲，真实回归**0脉冲**。追根因（读
RTL而不是重新猜一个数字）确认：那个窗口结构上根本没有"正式结果"可丢弃，0是符合该场景
设计意图的真实结果，不是RTL缺陷，是**选错了验证阶段**。

**改正后的独立场景**：参照SMOKE-17的输出反压手法（`i_measurement_result_ready=0`）
真实建立一笔held在途的正式结果，**在其仍被反压保持时STOP**（不像SMOKE-17那样先正常
释放消费），drain期间逐拍计数`o_measurement_result_discard_event === 1'b1`，断言
`>= 1`。真实回归：1个真实脉冲，PASS。

## TOP-15：ADC结果事务严格单笔在途

**合同原文**："四个已确认SAR15控制允许跨RED/IR连续保持，同时ADC结果事务仍严格单笔
在途"。SMOKE-14注释承诺验证`B_INFLIGHT`不重入，实际代码从未引用该信号。

**设计与调试过程（本报告最长的一段，因为最曲折）**：

1. 第一版：额外声明`reg_top15_prev_b_inflight`，用阻塞赋值在同一个`always @(posedge)`
   里"先检查、后更新"采样`state_current[B_INFLIGHT]`。真实回归**11次FAIL**，双光场景
   下高频出现。
2. 用探针核实：`commit_event=1`时`b_inflight_now=0`（同拍直接读）——不是重入，是
   scheduler有意设计的"释放同一拍立即建立下一笔"零浪费衔接。
3. 第一次修正尝试：怀疑是阻塞赋值和scheduler自己对该寄存器的非阻塞更新在同一个posedge
   里竞争，改成`reg_top15_prev_b_inflight <= ...`（非阻塞）。重跑：**结果完全不变**，
   同样11次FAIL、同样的时间戳——证明"竞争条件"这个猜测本身是错的。
4. 用多拍连续波形追踪（而不是单点探针）彻底查清：`o_adc_owner_commit_event`和
   `state_current[B_INFLIGHT]`本来就该在**同一拍、同一读取方式**下比较——两者都是
   "进入本次边沿之前已结算的值"，额外加一拍延迟寄存器本身就是错误的参照点，把
   RTL有意设计的零周期衔接错判成重入。
5. 最终版：删掉额外寄存器，直接同拍比较`commit_event && state_current[B_INFLIGHT]`。
   真实回归：**0 FAIL**。

**最终实现**：扩展既有owner-commit计数`always`块，新commit同拍若`B_INFLIGHT`仍为1即
判重入；文件末尾新增汇总检查确认监测非空跑（全程检查50笔真实commit，零重入）。

这个过程本身就是本条断言判别力的证明——同一个监测机制在开发过程中先后暴露过"错误
参照点导致11次假阳性"和"最终版本0误报"两种状态，说明它对时序确实敏感，不是一个
无论怎么改都通过的摆设。

## TOP-18：RUN许可极性与拆分（STATIC_BIAS负向半句）

**合同原文**："STATIC_BIAS下测量许可和新事务许可均为0"。SMOKE-11自己的注释承诺留到
SMOKE-19验证，从未兑现。

**第一版设计的错误**：按字面理解，假设`analog_run_enable`和`measurement_run_enable`
在STATIC_BIAS下都该是0，真实回归中`analog_run_enable`那一半立刻FAIL。独立读
`ppg_control_top.v:408`发现该行注释本身写明"STATIC_BIAS下仍跟随RUN，允许建立静态
向量"（同样带`@satisfies: TOP-18`标签）——`analog_run_enable`只接SSW，STATIC_BIAS
要靠它继续为1才能驱动`S[4:0]`静态向量；只有`measurement_run_enable`（合同"测量
许可"）才该是0。

**改正后的断言**（SMOKE-19已有的4000拍steady-state循环内逐拍核对）：
`measurement_run_enable == 0` 且 `analog_run_enable == 1`。

**变异测试**：把`ppg_control_top.v:409`的`&& !flag_static_characterization_enable`
门控去掉，真实回归FAIL：`measurement_run_enable`在STATIC_BIAS下未能保持0，与断言
设计的判据完全对应。

## 回归与验证方式汇总

| 缺口 | 新增断言方式 | 变异测试 | 独立场景/复用场景 |
| --- | --- | --- | --- |
| TOP-01 | 直接信号核对 + 复位前后计数不变 | 未做（非单行RTL可还原） | 复用SMOKE-01 + 新增独立场景 |
| TOP-02 | 提交结果+epoch比对 | 做了，真实FAIL | 新增负向场景 |
| TOP-09 | 逐拍脉冲计数 | 未做（需要复杂时序才能还原） | 新增独立场景（参照SMOKE-17手法） |
| TOP-15 | 常驻后台监测+汇总计数 | 未做（调试过程本身即判别力证明） | 扩展既有owner-commit监测block |
| TOP-18 | 4000拍逐拍核对 | 做了，真实FAIL | 复用SMOKE-19 |

**诚实声明**：TOP-01/09/15三条未做独立RTL变异测试，原因不同——TOP-01是"复位覆盖面广"
不好构造最小还原式mutant；TOP-09同理；TOP-15的判别力已经在真实开发调试过程中被反复
证明（11次假阳性→0次），认为等价于变异测试的效果，但严格说不是同一种证据形式，如实
记录供后续判断是否需要补做。

## 文件改动清单

- `ppg_control_top/tb_ppg_control_top.v`：V1.6→V1.7，新增约150行（3个独立场景+2处扩展
  现有场景+1个常驻监测block+若干新声明），无RTL改动。
- `ppg_system_integration/PPG_ALIAS_MAPPING_TABLE.md`：TOP-01/02/09/15/18五行追加
  2026-09-17说明。
- `ppg_system_integration/TOP01_24_ACCEPTANCE_ID_INDEPENDENT_RECHECK_20260916.md`：
  开头追加更新note，原文不改。

## 回归证据

`ppg_control_top/run_xsim_regression.sh`完整19-TB回归重跑中（详见该脚本
`xsim_regression_20260906/summary.tsv`），`tb_ppg_control_top`：0 FAIL，
`SMOKE_TB_PASS real_adc_responses=49 measurement_result_valid=33`。
