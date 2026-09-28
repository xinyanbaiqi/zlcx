# PWC-01~40 精度窗口模式控制器验收ID独立复核——工作线D

> 方法声明：本文档不信任`PPG_ALIAS_MAPPING_TABLE.md`第347行起PWC小节的任何映射、
> 不信任2026-09-16工作线A"整合核验"给出的"断言非空/回归PASS"结论，把它们全部当作
> **待验证的声称**。复核方法与TOP-01~24、PVW-01~46两个批次一致：(1)从
> `PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md`§21取每条ID的验收要求原文，
> 并回到§3~§18正文取该要求的规范定义（§21只有一行速记，正文才是真理来源）；
> (2)独立定位`tb_ppg_precision_window_controller.v`里的真实断言，**完整读断言所在的
> 整段场景激励**（不是只读条件表达式或场景注释），逐拍推演采样时刻；(3)对每条断言做
> confound排查——断言是不是靠"这个变量恰好是复位默认值/恰好被状态机另一条件同时决定"
> 而非claim要测的变量通过的，判断时按PVW-38那次的教训**追完整task调用链**
> （`reset_dut`→`set_default_inputs`、`start_run`、`enter_fine_window`→`request_cross`
> +`commit_safe_frame`、`commit_safe_frame`同时驱动3个安全输入）；(4)反查
> `ppg_precision_window_controller.v`确认RTL行为与断言预期一致。
>
> **本批次在静态推演之外增加了一层真实动态证据**：工作线A此前的"变异体复核"只覆盖了
> PWC-27/PWC-40两条。本次在scratchpad临时副本上构造并**实跑了46个单点RTL变异体**
> （真实RTL/TB一字未动），逐个回答"如果RTL这一行写错，40条断言里有没有任何一条会FAIL"，
> 另有7组直接探针打印关键时刻的真实信号值。下文每条结论都标注了对应的变异体存活/被杀
> 结果，**"某半句无覆盖"不再是静态判断而是可复现的实验事实**。
>
> 回归证据新鲜度已独立核对：
> `ppg_system_integration/module_tb_regression/xsim_module_regression/tb_ppg_precision_window_controller/xsim.log`
> 为2026-09-16 10:05:11 xsim v2022.2真实运行，40行`[PASS]`+汇总行
> `PWC-01 through PWC-40 ALL PASS pass=40 fail=0`，`$finish`在TB第713行（正常收尾路径，
> 非第724行watchdog），仿真结束于2216 ns。本次用iverilog 12.0独立重跑同一TB+RTL，
> 同样得到40/40 PASS、同样在第713行`$finish`、同样2216 ns——**跨工具复现成功**。
> **但PASS本身只证明断言没有报错，不证明断言测到了claim——这正是本次复核的对象。**
>
> **状态：40项全部完成断言级复核**。结论：**6个真实开放缺口**（PWC-04/15/21/26/34/35）
> +**13项部分覆盖**（PWC-01/02/05/11/12/20/28/29/30/31/32/36/40）+**21项CONFIRMED**。
> 另有**1个真实RTL/合同不一致**（新START清历史sticky，违反合同`:205`/`:731`，且同项目
> 兄弟模块已在2026-08-23为同一条要求改过RTL——见下文"RTL发现"一节，这是本次最重要的发现）。
> 别名表本身**没有**系统性错映射问题：40行的TB行号、用例名、RTL驱动点、合同锚点逐条抽验
> 全部对得上，问题全部在"断言强度/采样时刻/激励构造"层面。
> 本次未修改任何RTL、TB、别名表或矩阵文件。

---

## 0. 变异体实验总表（本次复核的主要新证据）

在`C:\Users\d\AppData\Local\Temp\...\scratchpad\pwc_recheck\`下复制RTL并做单点修改，
用**未经修改的真实TB**跑完整40条。"存活"= 40/40仍然ALL PASS = 该缺陷被现有断言集完全漏掉。

| 变异体 | 被破坏的合同要求 | 结果 |
| --- | --- | --- |
| `flag_pending_return_reacquire <= 1'b1`（VALLEY也要求重获） | §11.4 正常返回不产生reacquire | **存活** → PWC-15 |
| 去掉`o_cross_ready`里的`i_recheck_busy`项 | §13.3 重检busy期间不接受新cross | **存活**（只有PWC-07失败，PWC-21自己没抓到） → PWC-21 |
| `mode_fault_event_o`去掉超时与recheck-busy-return触发源 | §15.3 超时产生单拍fault、§11.1 报告故障 | **存活** → PWC-26 / PWC-32 |
| `i_diag_clear_event`同时解除`flag_fault_hold` | §17.1 诊断清除不得解除活动故障保持 | **存活** → PWC-34 |
| `controller_idle_o <= 1'b1`硬连高 | §17.2 idle仅在四条件全无时为1 | **存活** → PWC-35 |
| `flag_normal_cross_transfer`去掉NORMAL限定（表征模式也建窗口） | §5.3 表征RUN不建立正式fine窗口 | **存活** → PWC-04 / PWC-05 |
| 表征模式`o_cross_ready`恒0（不再安全消费） | §5.3 表征模式必须安全消费并置诊断 | **存活** → PWC-04 |
| `fine_window_active_o`去掉`flag_lifecycle_cancel`清除 | §6.3/§6.4 STOP/abort清除正式fine窗口资格 | **存活** → PWC-27 / PWC-28 |
| `last_cross_time_unknown_o <= 1'b1`硬连高 | §7.3 time_unknown原子锁存（含0方向） | **存活** → PWC-12 |
| `flag_cross_return_collision = 1'b0` | §16 cross/return同拍属协议异常并置诊断 | **存活** → PWC-30 |
| `flag_duplicate_cross = 1'b0` | §17.1 重复请求置protocol sticky | **存活** → PWC-31 |
| `reg_cross_config_snapshot`复位值改`8'hFF` | §6.1 全部pending上下文复位清零 | **存活** → PWC-29 |
| `switch_hold_new_transaction_o`复位值改`1'b1` | §6.1 `o_switch_hold_new_transaction=0` | **存活** → PWC-01 |
| `fine_window_start_event_o`改为锁存不自清 | §22 全部commit事件固定单周期 | **存活** → 次要观察3 |
| `precision_15_to_9_event_o`改为锁存不自清 | §22 全部commit事件固定单周期 | **存活** → 次要观察3 |
| `o_return_9bit_ready`加上`i_peak_valley_config_valid`门控 | §10.2/PWI-08 V5无效不得阻塞排空 | **存活** → PWC-40 |
| `o_local_empty = 1'b1`硬连高 | §18.1a `:776` | **存活** → 次要观察4 |
| **两个sticky去掉`i_start_ack_event`清除条件（改成合同要求的样子）** | — | **存活**（回归对该行为双向失明，见RTL发现） |
| 去掉`o_cross_ready`的`i_normal_measurement_active`项 | §6.2 启动校准期间不接受cross | 被PWC-06杀 |
| 去掉`o_cross_ready`的`i_peak_valley_config_valid`项 | §21`:952` V5正式检测门控 | 被PWC-40杀 |
| `flag_cross_transfer = i_cross_valid`（忽略ready） | §7.1 只在握手沿锁存 | 被PWC-06/07/31/40杀 |
| 去掉`flag_enter_commit`的`i_precision_takeover_safe` | §8.2 安全提交条件 | 被PWC-23/24/25杀 |
| `flag_switch_timeout_event`去掉`flag_enter_commit==0` | §15.2 同拍安全提交优先 | 被PWC-25杀 |
| `flag_lifecycle_cancel`去掉代际比较 | §6.3 只清当前generation | 被PWC-27杀 |
| `fine_window_start_frame_id_o <= reg_cross_frame_snapshot` | §8.3 用safe_frame_id不用cross_frame_id | 被PWC-10杀 |
| `precision_15_to_9_frame_id_o <= reg_return_frame_snapshot` | §11.2 同上 | 被PWC-19/20杀 |
| RESERVED不再归一化为PROTOCOL_FALLBACK | §4.4 保留编码归一化 | 被PWC-18杀 |
| `flag_return_transfer = i_return_9bit_valid`（忽略ready） | §10.1 只在握手沿锁存一次 | 被PWC-14杀 |
| `flag_return_commit`加上`!i_recheck_busy` | §11.1 返回安全优先于recheck busy | 被PWC-32杀 |
| `o_cross_ready`在ST_FINE也开放 | §9 窗口期间不接受新相交请求 | 被PWC-13杀 |
| 表征模式不再装载`i_initial_precision` | §5.3 START采用initial_precision | 被PWC-05杀 |
| NORMAL合法START装载15-bit | §5.2 固定9-bit启动 | 被PWC-02杀 |
| `flag_pending_state`扩大到非FAULT全状态 | §15.2 只计握手到提交的等待 | 被PWC-24/25/37/38/39杀 |
| `flag_pending_return_reacquire <= 1'b0`（异常也不重获） | §11.5 异常返回必须重获 | 被PWC-16/17/18/32杀 |
| 代际discard顺带清`protocol_error_sticky` | §17.1 STOP不清sticky | 被PWC-33杀 |
| `flag_enter_commit`不再置`fine_window_active_o` | §8.3 提交沿原子输出 | 被PWC-09等杀 |
| `flag_enter_commit`不再改`active_precision_mode_o` | §8.3 提交沿原子输出 | 被PWC-09等杀 |
| `switch_target_precision_o`握手沿不更新 | §17.2 pending目标精度 | 被PWC-08/23/27/30/40杀 |
| `flag_normal_start_illegal = 1'b0` | §5.2 非法NORMAL 15-bit启动 | 被PWC-03杀 |
| `active_precision_mode_o`复位值改15-bit | §6.1 复位固定9-bit | 被PWC-01杀 |
| `protocol_error_sticky_o`复位值改1 | §6.1 全部sticky复位清零 | 被PWC-01杀 |
| `reg_cross_frame_snapshot`复位值改`16'hFFFF` | §6.1 pending上下文复位清零 | 被PWC-29杀 |
| `flag_invalid_direction_request = 1'b0` | §16 方向不合法请求置诊断 | 被PWC-13/33杀（**PWC-30没抓到**） |
| `switch_hold_new_transaction_o`去掉两个commit项 | §8.4 提交沿本身保持hold | 被PWC-11杀 |
| `reacquire_request_event_o`在ST_IDLE也置位 | §11.5 单拍重获事件 | 被PWC-35杀 |

---

## RTL发现（本次最重要的一条）：新START清除了两个历史sticky，违反合同`:205`/`:731`

**这不是测试覆盖问题，是RTL行为与合同正文直接冲突。**

**要求原文**（两处独立表述，互相印证）：

- §6.2 `:205`："历史sticky只能在本地活动故障已解除后由Top唯一`i_diag_clear_event`清除；
  **新RUN不清除历史诊断**。"
- §17.1 `:731`："sticky发生后保持到异步复位，或在本地活动故障已经解除后由Top唯一注册式
  `i_diag_clear_event`清除。**新合法START和STOP本身不清sticky**，确保片外软件可以在停止后
  读取故障原因。"

**RTL实际行为**（`ppg_precision_window_controller.v`）：

```verilog
// :493-494  切换超时sticky
end else if(i_start_ack_event == 1'b1 || i_diag_clear_event == 1'b1)begin
    switch_timeout_sticky_o <= 1'b0;    // 新RUN或软件明确清除历史

// :506-507  协议异常sticky
end else if(i_start_ack_event == 1'b1)begin
    protocol_error_sticky_o <= flag_protocol_error_event; // 新RUN先清旧历史再记录当前配置错误
```

两个sticky都把`i_start_ack_event`当作清除条件，且RTL注释明写"新RUN先清旧历史"——
即实现方当时的意图就是清除，与合同正好相反。

**实测证据**（scratchpad探针，真实RTL未改）：

```
PROBE-A1 protocol_sticky_before_START = 1 (expect 1)
PROBE-A2 protocol_sticky_after_START  = 0 (contract requires 1)
PROBE-B1 timeout_sticky_before_START = 1 (expect 1)
PROBE-B2 timeout_sticky_after_START  = 0 (contract requires 1)
```
（A系列：ST_IDLE下拉高`i_return_9bit_valid`制造真实协议异常→sticky=1→发一次合法
START→sticky=0。B系列：制造真实切换超时→sticky=1→发一次合法START→sticky=0。）

**为什么40/40回归抓不到**：TB里`start_run`共出现24次，**每一次的前一行都是`reset_dut`**
（TB`:410/414/423/427/431/439/452/465/477/492/500/508/517/524/537/558/567/581/601/610/627/637/652/664/690`）。
异步复位本来就会清sticky，所以"START之后sticky=0"永远看不出是复位清的还是START清的；
TB从未构造过"sticky已置位 + 不复位 + 发START"这个唯一能判别的序列。
把RTL改成合同要求的样子（两处都去掉`i_start_ack_event`）后重跑真实TB，**仍然40/40 ALL PASS**
——回归对这个行为**双向失明**，既不保护正确行为，也不报告错误行为。

**同项目兄弟模块已经为同一条要求改过RTL**（这使本条从"合同文字可能过期"变成"PWC漏改"）：
`ppg_peak_valley_window_detector.v`的V1.2修订记录（该文件`:25`/`:50`）写着：

> "Remove `i_start_ack_event` from the fine_window_timeout/reacquire_timeout/protocol_error
> sticky clear conditions; only `i_diag_clear_event` or reset may clear these histories per
> ...section 12.4 and acceptance item PVW-37."

其RTL`:632`现在是`protocol_error_sticky_o <= protocol_error_sticky_o; // 新START与无清除授权时均保留协议违例证据; @satisfies: PVW-35, PVW-37`，
对应验收行PVW-37"**STOP和新START均不清历史sticky**"，且`PPG_ALIAS_MAPPING_TABLE.md:292`
记录了变异体反证"让新START清protocol sticky→PVW-37失败"。
即：**同一条系统级约定，PVW侧2026-08-23已落实并有断言保护，PWC侧（同为V1.3、同一天改的文件）
从未落实，也没有任何验收ID去测它**——PWC验收表40行里根本没有"START不清sticky"这一行，
PWC-33只覆盖了STOP那一半。

**缺什么**：(a) RTL两处清除条件；(b) 一条"sticky已置位→不复位→发合法START→sticky仍为1"的
断言（PVW-37的PWC对应物）。是否修复由后续产品决定，本次只调查记录，未动RTL/TB。

---

## 真实缺口1：PWC-15——"不产生reacquire"这一项是**恒真**的，与返回原因无关

**要求原文**：§21`:927`"VALLEY正常返回 | 下一安全帧返回9-bit**且不产生reacquire**"。
规范定义在§11.4`:497-502`（`return_reason==VALLEY_CONFIRMED`时"正常返回9-bit；不产生重新
获取请求"）与§11.5`:514-521`（异常原因才"必须在同一控制序列中产生一次`o_reacquire_request_event`"，
"推荐在`return_commit`后的下一个2 MHz周期产生"）。

**现有证据**（TB`:477-490`）：

```verilog
enter_fine_window(16'h4000, 16'h4001);
request_return(RETURN_VALLEY_CONFIRMED, 16'h4002);
...
commit_safe_frame(16'h4003);        // ← 提交沿，记为 T
check_case("PWC-15 valley normal return",
    (o_active_precision_mode == 1'b0) && (o_fine_window_active == 1'b0)
    && o_precision_15_to_9_event && (o_reacquire_request_event == 1'b0));
```

**缺什么**：RTL`:396-404`里`reacquire_request_event_o <= 1'b1`的条件是
`state_current == ST_REACQUIRE`。而`ST_REACQUIRE`是提交沿T的**下一拍**才成为
`state_current`（`:626-631`：T拍`state_current==ST_WAIT_RETURN`、`state_next=ST_REACQUIRE`）。
因此**在T+1ns这个采样点上，无论返回原因是什么，`o_reacquire_request_event`都必然是0**。
PWC-16正是因为知道这一点才在`commit_safe_frame`后多写了一句`step_clock`（TB`:497`）——
PWC-15没有，于是这一项退化成恒真。

实测（把PWC-15的场景原样重放、只把返回原因换成`RETURN_FINE_TIMEOUT`）：

```
PROBE-C1 abnormal_return @PWC-15_sample_point: reacquire=0 15to9=1 active=0 fine=0
PROBE-C2 would PWC-15's literal condition PASS on an ABNORMAL return? 1   ← 恒真
PROBE-C3 one cycle later (PWC-16's sample point): reacquire=1
```

变异体反证：把`flag_pending_return_reacquire <= (i_return_reason != RETURN_VALLEY_CONFIRMED)`
（RTL`:818`）改成恒`1'b1`——即**VALLEY_CONFIRMED也强行要求重新获取，直接违反§11.4**——
真实TB仍然**40/40 ALL PASS**。

全TB搜索`o_reacquire_request_event`只有4个断言点：`:490`（PWC-15，恒真）、`:498`（PWC-16，==1）、
`:506`（PWC-17，==1）、`:634`（PWC-32，==1）。另外两处VALLEY_CONFIRMED返回场景
（PWC-20`:517-522`、PWC-38`:680-683`）连reacquire项都没有，且同样没有多走一拍。
**结论：整个TB没有任何一处真实验证过"正常返回不产生reacquire"**。PWC-15的前半句
（安全返回9-bit）是真实、可判别的（`m5_enter_no_precision`等变异体被PWC-15杀），
缺口只在后半句。修法很小：在`commit_safe_frame`后补一句`step_clock`再断言。

---

## 真实缺口2：PWC-21——`o_cross_ready==0`被状态跳转顶替，没有隔离到`i_recheck_busy`

**要求原文**：§21`:933`"recheck busy | 保持9-bit且**拒绝新的正式cross**"。规范定义在
§13.3`:621-627`（"`i_recheck_busy=1`期间：活动精度应保持9-bit；不接受新的正式相交请求；
不产生fine start事件…"）。

**现有证据**（TB`:524-531`）：

```verilog
reset_dut; start_run(1'b0, 1'b0, 1'b1);
i_recheck_busy = 1'b1;
i_cross_valid  = 1'b1;
step_clock;                                   // ← 记为 E
check_case("PWC-21 recheck busy keeps 9bit",
    (o_cross_ready == 1'b0) && (o_active_precision_mode == 1'b0) && (o_fine_window_active == 1'b0));
```

**缺什么**：断言在E沿**之后**采样`o_cross_ready`。假如RTL丢掉了`i_recheck_busy`门控，
E沿上`o_cross_ready=1`、`i_cross_valid=1`就会真实握手，`state_current`随即变成
`ST_WAIT_ENTER`；而`o_cross_ready`（RTL`:277`）的NORMAL分支本身要求
`state_current == ST_IDLE`——**握手成功这件事自己把ready拉回了0**。于是采样点上
`o_cross_ready`仍然是0，断言照过。另外两项`o_active_precision_mode==0`、
`o_fine_window_active==0`在这个场景里也不会变（没有安全边界，不可能提交），同样恒真。

变异体反证：从`o_cross_ready`（RTL`:277`）删掉`&& (i_recheck_busy == 1'b0)`后跑真实TB，
FAIL列表是`PWC-07`——**PWC-21自己没有失败**（两次独立构造同一变异体，结果一致）。
也就是说这条缺陷是被另一条ID顺带抓到的，PWC-21本身零判别力。

**同一份TB里已有正确写法可对照**：PWC-06（TB`:436`）场景结构完全相同（也是拉一个ready门控项
为0、拉高`i_cross_valid`、走一拍、断言），但它多了一项`(o_switch_pending == 1'b0)`——
`switch_pending_o`在握手沿会被置1且不会被状态回读掩盖，所以对应变异体被PWC-06当场杀掉。
PWC-21缺的就是这一项。

（附带：§13.3还有"不产生fine start事件"和"普通精度切换历史不被重检pending单独清除"
两句，PWC-21断言里也没有对应项；前者在该场景里因无安全边界而恒真，后者零覆盖。）

---

## 真实缺口3：PWC-26——"报告fault"和"无假事件"两句被采样点差一拍全部错过

**要求原文**：§21`:938`"切换超时 | **保持原精度、无假事件、置sticky并报告fault**"（四项）。
规范定义在§15.3`:683-692`：

```text
保持当前o_active_precision_mode
不产生虚假fine start或15-to-9 commit事件
置o_switch_timeout_sticky
产生单拍o_mode_fault_event
进入故障保持并继续阻止新事务
```

**现有证据**（TB`:558-565`）：

```verilog
request_cross(16'h7300, ...);                         // 握手沿记为 H
i_precision_takeover_safe = 1'b0;
for(cnt_loop = 0; cnt_loop < C_TEST_TIMEOUT_CYCLES + 1; cnt_loop = cnt_loop + 1)begin
    step_clock;                                        // 9次 → H+1 … H+9
end
check_case("PWC-26 switch timeout fault", o_switch_timeout_sticky && (o_active_precision_mode == 1'b0)
    && (o_switch_pending == 1'b0) && o_switch_hold_new_transaction);
```

**缺什么**：`C_TEST_TIMEOUT_CYCLES=8`、`TIMEOUT_LIMIT_MINUS_ONE=7`，逐拍推演
`cnt_switch_timeout`（RTL`:687-701`）在H+7达到7，**超时事件发生在H+8**；
`mode_fault_event_o`（RTL`:407-415`）是单拍，只在H+8之后那段区间为高，H+9就自动清零。
循环跑了9次，采样点落在H+9——**刚好错过一拍**。断言里也没有
`o_fine_window_start_event`/`o_precision_15_to_9_event`两项，所以"无假事件"同样零覆盖。

实测两个采样点：

```
PROBE-D1 at loop=8 (H+8): mode_fault_event=1 sticky=1 pending=0 hold=1 active=0 fine_start=0 15to9=0
PROBE-D2 at loop=9 (H+9, PWC-26's real sample point): mode_fault_event=0 sticky=1 pending=0 hold=1
```

注意PROBE-D1：**在H+8这一拍，PWC-26现有的四项断言全部已经成立，同时缺失的三项
（`mode_fault_event=1`、`fine_start=0`、`15to9=0`）也全部可观测**。也就是说把循环次数从
`C_TEST_TIMEOUT_CYCLES+1`改成`C_TEST_TIMEOUT_CYCLES`并补三项，四句要求就能一次全覆盖。

变异体反证：把`mode_fault_event_o`（RTL`:410`）的触发源砍成只剩`flag_protocol_fault_pulse`
（即**切换超时不再报告故障**，直接违反§15.3），真实TB仍然**40/40 ALL PASS**。

全TB搜索`o_mode_fault_event`只有两个断言点：`:420`（PWC-03，非法START路径的正向断言）
和`:555`（PWC-25，负向断言==0）。**"超时→故障单拍"这条路径从未被正向断言过**。
这条输出是本模块向AMI cause 8'h04故障分发链的唯一出口（RTL`:138`、合同§18.6），
漏测的分量不轻。

---

## 真实缺口4：PWC-34——"不解除活动故障保持"整条被`ST_FAULT`顶替，零判别力

**要求原文**：§21`:946`"diagnostic clear | 只清sticky，**不解除活动故障保持**"。
规范定义在§17.1`:731-732`："`i_diag_clear_event`只清历史标志，不得解除正在进行的故障保持；
故障保持只由当前generation的detection discard（包括scope-only flush）或复位结束。"

**现有证据**（TB`:652-662`）：先制造一次真实切换超时（进入`ST_FAULT`、`flag_fault_hold=1`），
再拉一拍`i_diag_clear_event`，断言
`(o_switch_timeout_sticky == 1'b0) && o_switch_hold_new_transaction && (o_cross_ready == 1'b0)`。

**缺什么**：后两项都被状态机独立决定，与`flag_fault_hold`无关：

- `o_switch_hold_new_transaction`（RTL`:546`）= `(state_next == ST_FAULT) || …`——
  `ST_FAULT`只由生命周期取消或新START解除（RTL`:639-641`），诊断清除碰不到它，所以恒为1；
- `o_cross_ready`（RTL`:277`）的NORMAL分支要求`state_current == ST_IDLE`，此刻是`ST_FAULT`，
  **即使`flag_fault_hold`被错误清零，ready也照样是0**。

于是"活动故障保持仍在"这件事**没有任何一项真实观测**。

实测：

```
PROBE-E1 PWC-34 sample point: timeout_sticky=0 hold=1 cross_ready=0 | fault_hold(o_mode_fault_active)=1 state_current=5
```
（`state_current=5`即`ST_FAULT`，证实两项都由状态决定。）

变异体反证：给`flag_fault_hold`（RTL`:672-684`）加一条
`else if(i_diag_clear_event == 1'b1) flag_fault_hold <= 1'b0;`——**这正是PWC-34明文禁止的行为**——
真实TB仍然**40/40 ALL PASS**。

**最干净的观测点已经存在但从未被使用**：RTL`:292`有`assign o_mode_fault_active = flag_fault_hold;`，
是`flag_fault_hold`的直接导出；TB`:388`也已经把它连了出来（`wire o_mode_fault_active`在`:144`声明）。
但全TB搜索`o_mode_fault_active`只有声明`:144`和端口连接`:388`两处，**40条check_case里一次都没用过**。
断言里补一项`o_mode_fault_active`即可从零判别力变成完全判别。
前半句"只清sticky"是真实的（`o_switch_timeout_sticky`从1变0，可判别）。

---

## 真实缺口5：PWC-35——"**仅**…时为1"这个排除半句零覆盖，正向项等于复位默认值

**要求原文**：§21`:947`"controller idle | **仅**在无pending、无延迟动作和无故障保持时为1"。
规范定义在§17.2`:743`："`o_controller_idle` | 无pending、无延迟重新获取、无故障保持和无当拍控制事件"。
RTL`:555`把它实现为四个排除条件的与。

**现有证据**（TB`:664-667`）：`reset_dut; start_run; step_clock;`之后断言
`o_controller_idle && (o_switch_pending == 1'b0) && (o_switch_hold_new_transaction == 1'b0)`。

**缺什么**：这是一个**纯正向、零排除条件**的断言，而"仅"字表达的排除半句才是这条要求的全部实质。
三项的取值（idle=1、pending=0、hold=0）**全部等于复位默认值**（`controller_idle_o`复位为1，
见RTL`:553`），场景里也没有任何能让它们改变的激励。全TB搜索`o_controller_idle`只有
声明`:138`、端口连接`:383`和这一处断言`:667`——**没有任何一处断言过`o_controller_idle == 1'b0`**。

变异体反证：把RTL`:555`整条替换成`controller_idle_o <= 1'b1;`（**idle硬连高，四个排除条件
全部失效**），真实TB仍然**40/40 ALL PASS**。

而排除半句是完全可观测、可判别的——实测同一份RTL在有pending时确实会拉低：

```
PROBE-F1 idle in clean ST_IDLE = 1 (PWC-35 asserts this; equals reset default)
PROBE-F2 idle while pending (contract requires 0, never asserted by any PWC ID) = 0
```

只要在`request_cross`之后加一项`(o_controller_idle == 1'b0)`就能覆盖第一个排除条件，
故障保持（`ST_FAULT`）和延迟重获（`ST_REACQUIRE`）两个排除条件同理，
场景在PWC-26/PWC-16里都现成存在。

（附带：`o_local_empty`（RTL`:307`，`assign o_local_empty = controller_idle_o;`，
合同§18.1a`:776`定义的PWI消费端口）在TB里同样只有声明`:143`和端口连接`:348`，零断言；
把它硬连成`1'b1`的变异体同样存活。）

---

## 真实缺口6：PWC-04——表征profile下从未施加过任何cross/return激励，两个半句都恒真

**要求原文**：§21`:916`"CHARACTERIZATION 9-bit | **整个RUN固定9-bit且无正式窗口**"。
规范定义在§5.3`:158-174`：

```text
run_profile == 1
START时采用initial_precision
整个RUN保持该精度
不建立正式PPG fine窗口
不产生fine_window_start_event
不产生precision_15_to_9_event
不根据cross或return自动切换
```
并且`:173-174`明确要求："动态基线和峰谷模块不应在该profile下产生正式模式请求；
**若错误请求到达，控制器必须安全消费并置协议诊断**，防止保持型输出永久占用。"

**现有证据**（TB`:423-425`）：

```verilog
reset_dut;
start_run(1'b1, 1'b0, 1'b1);                  // 表征profile，initial_precision=0
check_case("PWC-04 characterization fixed 9bit",
    (o_active_precision_mode == 1'b0) && (o_fine_window_active == 1'b0) && (o_fine_window_start_event == 1'b0));
```

**缺什么**：三项全部无判别力。

1. `o_active_precision_mode == 1'b0`是**三重简并**的：它同时等于复位默认值（RTL`:318`）、
   NORMAL合法START的装载值（RTL`:325`）、以及本场景表征装载的`i_initial_precision=0`
   （RTL`:323`）。这三条路径产生同一个0，断言无法区分走了哪条，甚至无法区分"有没有走"。
   实证：本次46个变异体中，**PWC-04一次都没有杀掉任何一个**（PWC-01、PWC-36同样，
   全40条里只有这三条从未杀死过任何变异体）。表征装载路径真正被证明存在，
   靠的是PWC-05（`i_initial_precision=1`→输出1，非默认值，对应变异体确实被PWC-05杀掉）。
2. `o_fine_window_active == 0`、`o_fine_window_start_event == 0`：场景里**从头到尾没有
   驱动过`i_cross_valid`或`i_return_9bit_valid`**，也没有安全边界，所以不可能建立窗口，
   两项恒真。
3. "整个RUN"零覆盖：断言只看START之后第2拍这一个瞬间，之后立刻`reset_dut`进入下一用例。

变异体反证（两个，都存活）：

- 把`flag_normal_cross_transfer`（RTL`:262`）的`&& (i_run_profile == RUN_PROFILE_NORMAL)`
  删掉——**表征模式下的cross会真实建立进入请求并打开正式fine窗口**，直接违反§5.3的
  "不建立正式PPG fine窗口"——真实TB仍然**40/40 ALL PASS**；
- 把`o_cross_ready`（RTL`:277`）的`|| (i_run_profile == RUN_PROFILE_CHARACTERIZATION)`
  改成`|| 1'b0`——**表征模式改为直接拒绝而不是"安全消费"，保持型请求将永久占用**，
  违反§5.3`:173-174`——真实TB仍然**40/40 ALL PASS**。

根因是同一个：**TB的24个场景里，只有PWC-04和PWC-05两处用了表征profile，而这两处都不驱动
任何请求**。因此RTL里专门为表征模式写的三段逻辑——`o_cross_ready`的表征分支（`:277`）、
`o_return_9bit_ready`的表征分支（`:280`）、`flag_characterization_request`协议诊断
（`:856-858`）——**整体零覆盖**。

PWC-05的处境略好（"固定15-bit"那半句是真实可判别的），故列为部分覆盖；PWC-04两个半句
都恒真，列为真实缺口。

---

## 部分覆盖13项（要求原文的一部分有真实证据，另一部分证据弱于字面要求）

处理方式参照TOP-05/07/21"CONFIRMED但测量方法比字面弱"的先例。

| ID | 真实、可判别的部分 | 弱于字面要求的部分 |
| --- | --- | --- |
| **PWC-01** | 复位把`o_active_precision_mode`、`o_protocol_error_sticky`等**带条件保持**的寄存器从X驱动到0，确实可判别（改复位值的两个变异体都被PWC-01杀） | (a) §6.1`:191`的`o_switch_hold_new_transaction=0`**不是**在测复位分支：`reset_dut`在释放复位后又走了一拍`step_clock`，而该寄存器（RTL`:542-547`）的else分支每拍无条件重算，复位值当场被覆盖——把它的复位值改成`1'b1`的变异体存活；`o_controller_idle`同理。(b) §6.1`:192`"全部commit/**reacquire**/**fault**事件=0"里的`o_reacquire_request_event`、`o_mode_fault_event`不在断言里。(c) §6.1`:194`"全部pending上下文和等待计数=0"不在断言里（部分由PWC-29覆盖） |
| **PWC-02** | "固定9-bit启动"可判别（把NORMAL合法START改成装载15-bit的变异体被PWC-02杀） | "不产生commit事件"两项采样点在START沿**之后两拍**（`start_run`内含两次`step_clock`），单拍事件早已自清；实测`PROBE-G1/G2`确认START沿那一拍才是唯一可观测窗口。对比PWC-03只走一拍因而能看到`o_mode_fault_event`脉冲 |
| **PWC-05** | "固定15-bit"可判别（输出1非默认值，表征不装载`i_initial_precision`的变异体被PWC-05杀） | "无fine start事件"与"整个RUN"同PWC-04：表征profile下零cross/return激励，`flag_normal_cross_transfer`去NORMAL限定的变异体存活 |
| **PWC-11** | "commit沿本身仍保持hold"可判别（`switch_hold_new_transaction_o`去掉两个commit项的变异体被PWC-11杀，说明提交拍靠的正是`flag_enter_commit`项而非pending残留） | §8.4/`:923`"commit沿后**下一时钟才允许事务启动**"的释放半句无断言：TB`:463`走了一拍就直接`reset_dut`，从未断言过hold在下一拍落回0 |
| **PWC-12** | `i_cross_time_unknown=1`时`o_last_cross_time_unknown`与内部`flag_pending_cross_time_unknown`都为1，非默认值，真实；"仍进入15-bit"由同一连续场景紧接着的PWC-13断言`o_fine_window_active`覆盖 | 只测了unknown=1单方向：把`last_cross_time_unknown_o <= i_cross_time_unknown`改成硬连`1'b1`的变异体存活。PWC-08那笔`request_cross`本来就传了`time_unknown=1'b0`，补一项`(o_last_cross_time_unknown == 1'b0)`即可闭合 |
| **PWC-20** | "实际返回事件仍可触发scheduler"真实：`o_precision_15_to_9_event`+帧号`16'h7003`可判别（帧号取错源的变异体被PWC-19/PWC-20杀） | "AMB pending不提前退出fine"零激励——本模块**根本没有`amb_recheck_pending`输入端口**，§13.1约束的是scheduler侧；模块级结构性满足但非激励证明。合同自己已把该语义归入`:956-964`的PWI-03/04顶层集成TB |
| **PWC-28** | 代际discard撤销pending真实且构造优秀：ABORT与SYSTEM_FAULT两种reason各一次，中间还插了一次"重新建立pending"的正向对照（TB`:591-592`）；`i_run_enable`全程为1，`flag_leave_run_cancel`恒0，取消确实归因于代际discard | §6.4`:225`"清除正式fine窗口资格"零覆盖：全TB三处discard（PWC-27/28/33）**都发生在fine窗口从未建立的状态**，`fine_window_active_o`去掉`flag_lifecycle_cancel`清除条件的变异体存活。§6.3`:214`对STOP的同义要求同样未测 |
| **PWC-29** | 从真实已加载的pending上下文做异步复位，4项全部是非零→零的真实跃变（frame=`16'h7600`、sample=`16'h7601`、unknown=1、pending=1），判别力强（改`reg_cross_frame_snapshot`复位值的变异体被PWC-29杀） | `:941`"**全部**上下文确定性清零"：本场景明明把`config/coef/dc` epoch加载成了`8'hAA/8'hBB/8'hCC`（TB`:603`），断言却只查了4个字段；改`reg_cross_config_snapshot`复位值为`8'hFF`的变异体存活。`cnt_switch_timeout`、`reg_return_frame_snapshot`、`enc_return_reason_snapshot`同样未查 |
| **PWC-30** | "按活动精度选择唯一合法方向"真实：9-bit下cross胜出、`o_switch_pending`/`o_switch_target_precision`置位、`reg_cross_frame_snapshot==16'h7700`锁的是cross而非return载荷，全部可判别 | `o_protocol_error_sticky`这一项**双重confound**：该拍同时有`flag_cross_return_collision`和`flag_invalid_direction_request`（ST_IDLE+9-bit+return_valid）两个独立来源，任意一个单独置0的变异体都存活（`flag_cross_return_collision=1'b0`存活；`flag_invalid_direction_request=1'b0`只被PWC-13/33杀、PWC-30没抓到）。另：只测了9-bit一个方向，15-bit下的镜像碰撞未测 |
| **PWC-31** | "不覆盖第一笔pending上下文"真实且判别力强：已锁存`16'h7700`、新递`16'h77FF`、断言保持不变（`flag_cross_transfer`忽略ready的变异体被PWC-31杀） | 附带的`o_protocol_error_sticky`项被上一条用例confound——PWC-30的场景是**连续的**（中间无`reset_dut`），sticky进入PWC-31时**已经是1**；`flag_duplicate_cross = 1'b0`的变异体存活，说明§17.1"重复请求"这一诊断来源零判别覆盖 |
| **PWC-32** | 核心真实且隔离干净：`flag_return_commit`不含`!i_recheck_busy`（RTL`:265`）→ 返回安全优先于异常出现的recheck busy，对应变异体被PWC-32杀；sticky可归因于`flag_recheck_in_fine`（场景进入时sticky确为0，FINE_TIMEOUT本身不置sticky）；reacquire在提交后下一拍交付 | §11.1`:457`"并向系统管理器**报告故障**"无断言：`flag_return_commit && i_recheck_busy`会在提交沿产生`o_mode_fault_event`单拍（RTL`:410`），但断言点在其后一拍，砍掉该触发源的变异体存活。§12.3`:562`第1项"实际15→9事件仍送给scheduler"在本ID也无断言项 |
| **PWC-36** | —（无可判别项） | "两色事务逐位使用同一committed精度"在本模块**没有落点**：无任何颜色端口，`o_mode_fault_color_ir`硬连0（RTL`:296`），§3.3的R/IR原子性由§14.2交给AMI的`transaction_start_fire`同拍快照。模块级替代物（6拍稳定性观察，TB`:669-674`）取样于**复位默认值0/0**且全程无激励，46个变异体中PWC-36一个都没杀掉。更强的替代物现成可用：在PWC-37提交出15-bit之后再做同样的稳定性观察 |
| **PWC-40** | 阻断半句构造**优于本文件其余全部39条**：先取基线`flag_case_ok = o_cross_ready`（证明其余ready条件全部成立）→ 只改`i_peak_valley_config_valid=0` → `#1`纯组合观察ready立即关闭（不经时钟沿，因此不会被状态跳转顶替，这正是PWC-21栽的地方）→ 4拍交替施加安全边界期间逐拍累积7项 → 最后恢复资格做正向对照，同一笔cross被接纳且`reg_cross_frame_snapshot==16'h7B00`。去掉V5门控项的变异体被PWC-40杀 | `:952`末句"**已有安全排空和generation-scoped discard规则不变**"零覆盖：门控期间从未施加过discard事件，也从未验证过返回/排空路径。给`o_return_9bit_ready`加上`i_peak_valley_config_valid`门控的变异体存活——而这恰好就是合同§10.2`:411-431`那段2026-09-02修订记录自己承认的未覆盖项（"本决定未被专项动态仿真覆盖…'config_valid在fine窗口中途跌落、验证返回请求仍被正常排空'可作为独立的低优先级补测项"）。`o_local_empty`零断言亦属此列 |

---

## 完整40条复核表

| ID | 场景（合同§21要求速记） | 结论 | 判定依据 |
| --- | --- | --- | --- |
| PWC-01 | 异步复位 | **部分覆盖** | 精度/sticky两个复位值变异体被杀=真实；hold项测的不是复位分支（变异体存活）；reacquire/fault事件与pending上下文不在断言 |
| PWC-02 | NORMAL合法START | **部分覆盖** | 装载15-bit变异体被杀=9-bit半句真实；"不产生commit事件"采样晚两拍，单拍事件已自清 |
| PWC-03 | NORMAL非法初始15-bit | CONFIRMED | 三个半句全覆盖且采样点正确（只走一拍，`o_mode_fault_event`脉冲可见）；`flag_normal_start_illegal=0`变异体被PWC-03杀 |
| PWC-04 | CHARACTERIZATION 9-bit | **真实缺口** | 值三重简并（复位=NORMAL=表征），零cross/return激励；两个表征相关变异体均存活；46变异体中PWC-04零杀 |
| PWC-05 | CHARACTERIZATION 15-bit | **部分覆盖** | 不装载`i_initial_precision`变异体被PWC-05杀=15-bit半句真实；"无fine start"同PWC-04恒真 |
| PWC-06 | 启动校准期间cross | CONFIRMED | `i_normal_measurement_active`是ready式子里唯一为0的项（其余项逐项核对全为1），含`o_switch_pending==0`因而不被状态跳转顶替；对应变异体被PWC-06杀 |
| PWC-07 | cross反压 | CONFIRMED | 反压源隔离在`i_recheck_busy`；载荷`16'h1111`→`16'h2222`两次变化而快照保持；`flag_cross_transfer`忽略ready的变异体被PWC-07杀 |
| PWC-08 | cross握手原子上下文 | CONFIRMED | §7.3六字段中五个用互不相同的非零值逐一核对（frame/sample/config/coef/dc），第六个time_unknown由PWC-12覆盖；目标精度变异体被PWC-08杀 |
| PWC-09 | 下一安全帧进入 | CONFIRMED | §8.3四项输出中三项+pending清零，全部为0→1/1→0真实跃变；两个"提交沿不更新输出"变异体均被PWC-09杀 |
| PWC-10 | 进入frame_id | CONFIRMED | `16'h2001`（safe）vs`16'h1234`（cross）两值不同且断言含显式负向项；取错源变异体被PWC-10杀 |
| PWC-11 | 模式提交原子性 | **部分覆盖** | 提交沿hold项真实（去掉commit项的变异体被PWC-11杀）；"下一时钟才允许"释放半句无断言 |
| PWC-12 | unknown相交 | **部分覆盖** | unknown=1方向真实（输出+内部标志双查）；unknown=0方向未测，硬连1的变异体存活 |
| PWC-13 | fine期间第二cross | CONFIRMED | ready=0/pending=0/窗口保持/协议诊断四项；sticky进入本场景时确为0（逐拍核对无其他来源）；ST_FINE放开ready的变异体被PWC-13杀 |
| PWC-14 | return反压 | CONFIRMED | 已锁存(VALLEY,`16'h4002`)对抗新递(FINE_TIMEOUT,`16'h4FFF`)，reason与frame双查；`flag_return_transfer`忽略ready的变异体被PWC-14杀 |
| PWC-15 | VALLEY正常返回 | **真实缺口** | 前半句真实；"不产生reacquire"恒真（采样早一拍，PROBE-C2实测异常原因也PASS），VALLEY强制重获的变异体存活 |
| PWC-16 | FINE timeout返回 | CONFIRMED | 比PWC-15多走一拍，落在`ST_REACQUIRE`交付拍，`o_reacquire_request_event=1`可判别；`flag_pending_return_reacquire=0`变异体被PWC-16杀 |
| PWC-17 | protocol fallback返回 | CONFIRMED | 三个半句全覆盖；sticky可归因（场景进入时为0，逐拍核对`flag_return_protocol_fallback`是唯一来源）；对应变异体被PWC-17杀 |
| PWC-18 | RESERVED返回原因 | CONFIRMED | 归一化判别力满分：复位值`2'b00`、原始值`2'b11`、断言值`2'b10`三者互不相同；不归一化的变异体被PWC-18杀。"不继续保持fine窗口"由同场景PWC-19的15→9事件与PWC-15/38的窗口项覆盖 |
| PWC-19 | 返回frame_id | CONFIRMED | `16'h6103`（safe）vs`16'h6102`（return）+显式负向项；取错源变异体被PWC-19杀 |
| PWC-20 | AMB pending | **部分覆盖** | 返回事件+帧号真实；"pending不提前退出fine"无对应输入端口，属§956-964的PWI-03/04顶层项 |
| PWC-21 | recheck busy | **真实缺口** | `o_cross_ready==0`被握手后的`ST_WAIT_ENTER`顶替，缺PWC-06那样的`o_switch_pending==0`项；去掉recheck门控的变异体两次构造均存活 |
| PWC-22 | 普通切换连续性 | CONFIRMED | 四个idle端口在本模块**不存在**（逐行核对`:122-127`端口段），"不要求"属结构性满足；提交本身用变异体验证为真实 |
| PWC-23 | 等待安全边界 | CONFIRMED | 隔离极干净：安全边界**已施加**、仅`i_precision_takeover_safe=0`，证明边界单独不足以提交；对应变异体被PWC-23杀 |
| PWC-24 | 10000周期前提交 | CONFIRMED | 逐拍推演`cnt_switch_timeout`在采样点恰为7，早一拍的阈值变异体会被抓；pending保持项同时验证；TB用`C_SWITCH_TIMEOUT_CYCLES=8`缩放，属参数化而非弱化 |
| PWC-25 | 安全与阈值同拍 | CONFIRMED | 真正的同拍碰撞：该拍`cnt=7`已达阈值且`flag_enter_commit=1`，只靠`(flag_enter_commit==0)`项抑制误报；去掉该项的变异体被PWC-25杀 |
| PWC-26 | 切换超时 | **真实缺口** | "保持原精度/置sticky"真实；"报告fault"与"无假事件"两句被采样点差一拍全部错过，砍掉超时故障源的变异体存活（PROBE-D1证明早一拍四项全成立且缺失三项均可观测） |
| PWC-27 | pending期间STOP | CONFIRMED | 构造优秀：先施陈旧代际做反例（快照`16'h7400`保持）再施当前代际（快照归零）；`i_run_enable`恒1排除`flag_leave_run_cancel`；"无commit事件"两项采样点正确；去代际比较的变异体被PWC-27杀 |
| PWC-28 | pending期间abort | **部分覆盖** | ABORT+SYSTEM_FAULT两reason+中途正向对照，撤销半句真实；§6.4"清除正式fine窗口资格"零激励，对应变异体存活 |
| PWC-29 | pending期间复位 | **部分覆盖** | 4字段真实跃变、判别力强；"全部上下文"里同场景已加载的`config/coef/dc` epoch等3字段未查，对应变异体存活 |
| PWC-30 | cross和return同拍 | **部分覆盖** | 方向选择与载荷归属真实；`o_protocol_error_sticky`被两个独立flag双重confound（各自单独置0的变异体都存活）；15-bit镜像方向未测 |
| PWC-31 | 重复同向请求 | **部分覆盖** | 上下文保持半句真实且判别力强；附带的sticky项被PWC-30遗留的sticky confound（`flag_duplicate_cross=0`变异体存活） |
| PWC-32 | 异常返回加重检pending | **部分覆盖** | 返回优先于recheck busy+协议诊断+reacquire三项真实且归因干净；§11.1"报告故障"、§12.3第1项无断言 |
| PWC-33 | STOP不清sticky | CONFIRMED | sticky由真实协议异常建立并用`flag_case_ok`前置快照；discard后无其他来源可重置，保持是真的；让discard清sticky的变异体被PWC-33杀。**注**：§17.1同句的"新合法START不清sticky"另属RTL发现一节，不在本ID字面范围 |
| PWC-34 | diagnostic clear | **真实缺口** | "只清sticky"真实；"不解除活动故障保持"两项全部被`ST_FAULT`顶替，对应变异体存活；已连出的`o_mode_fault_active`零使用 |
| PWC-35 | controller idle | **真实缺口** | "仅"字排除半句零覆盖，正向项等于复位默认值；idle硬连高的变异体存活（实测RTL在pending时确实会拉低，可测而未测） |
| PWC-36 | R/IR同帧 | **部分覆盖** | 两色语义在本模块无端口落点（§14.2交给AMI）；模块级替代的稳定性观察取样于复位默认值0/0，零杀伤 |
| PWC-37 | 进入15-bit历史尾部 | CONFIRMED | "commit立即更新"真实（同沿0→1跃变）；"不等待尾部/不重复实现尾部计数器"结构性成立——全模块只有`cnt_switch_timeout`一个计数器，无任何FIR样本端口 |
| PWC-38 | 返回9-bit历史尾部 | CONFIRMED | "commit立即清除fine窗口"真实（1→0同沿跃变+15→9事件）；尾部半句同PWC-37结构性成立 |
| PWC-39 | 尾部不计切换超时 | CONFIRMED | 提交并清pending后等待12拍（>阈值8）仍无sticky，替代物可判别；把`flag_pending_state`放宽到非FAULT全状态的变异体被PWC-39杀 |
| PWC-40 | V5正式检测门控 | **部分覆盖** | 阻断半句是全文件构造最强的一条（基线+组合隔离+4拍带边界+恢复正向对照），去V5门控的变异体被PWC-40杀；"已有安全排空和generation-scoped discard规则不变"零覆盖，给return路径加门控的变异体存活 |

---

## 次要观察（不改变上表判定，供后续参考）

1. **别名表本身没有系统性错误**。PWC-01~40四十行的TB行号、用例名片段、条件片段、RTL驱动点
   行号、合同锚点行号本次逐条抽验，全部对得上真实文件内容；`:351`关于PWC-40此前是唯一缺口、
   以及"D01-01b的CROSS计数取自C20输出因而替代不了C23自身门控"的说明，与TB`:690-709`
   实际写法一致。这与PVW批次结论一致：问题在断言强度层面，不在映射层面。

2. **"采样点差一拍"是本模块反复出现的同一类缺陷**，共命中4条ID：PWC-02/05（START沿后两拍）、
   PWC-15（提交沿后0拍，早一拍）、PWC-26（超时沿后1拍，晚一拍）、PWC-32（提交沿后1拍，晚一拍）。
   TB里已有正确写法作对照——PWC-03只走一拍所以抓得到`o_mode_fault_event`，
   PWC-16比PWC-15多走一拍所以抓得到`o_reacquire_request_event`。全部是几行改动量。

3. **§22`:975`"所有commit和重新获取事件固定为单周期"这一交付门禁无动态覆盖**：把
   `fine_window_start_event_o`和`precision_15_to_9_event_o`的else分支从自清改成保持
   （即事件锁存不落）的两个变异体**都存活**。PWC-27/28虽然断言了`o_fine_window_start_event==0`，
   但那两个场景里从未发生过提交，锁存高电平根本没机会出现。

4. **三个已连出的输出端口零断言**：`o_mode_fault_active`（TB`:388`连接）、
   `o_local_empty`（TB`:348`连接）、`o_return_9bit_ready`的正向(==1)方向（全TB只有`:486`
   一处==0断言）。前两个各自的"硬连"变异体都存活。`o_mode_fault_active`恰好是PWC-34缺口
   最直接的补法。

5. **合同§22`:990`散文仍写"历史 PWC-01 至 PWC-39"**，验收表`:913-952`已是40行。属文字滞后，
   与别名表`:294`(b)记录的FIR同类问题一致，本次未改合同。

6. **一处合同内部表述张力（非RTL缺陷判定，仅记录）**：§17.1`:730-731`与§18.1a`:783`都写
   `i_diag_clear_event`"在本地活动故障已经解除后"/"仅可在本地无活动故障时"清历史sticky，
   而验收行`:946`（PWC-34）与TB`:652-662`的实际构造都是**在故障保持期间**发诊断清除并
   要求sticky被清掉，RTL（`:493`/`:508`）也没有任何`flag_fault_hold`守卫。这两种读法的差别
   在于`:783`约束的是PWC还是Top（事件生产者）。本次不判定为缺陷，但若后续要给PWC-34补
   `o_mode_fault_active`断言，需要先把这处读法定下来。

7. **跨工具复现**：本次用iverilog 12.0跑同一份TB+RTL得到与2026-09-16 xsim完全一致的
   40/40 PASS、同一`$finish`行号(713)、同一结束时刻(2216 ns)。46个变异体全部在iverilog下执行。
   全部实验产物在session scratchpad的`pwc_recheck/`目录，**项目内RTL/TB/别名表/矩阵一字未动**。

---

## 汇总

| 结论 | 条数 | ID |
| --- | ---: | --- |
| CONFIRMED | **21** | PWC-03, 06, 07, 08, 09, 10, 13, 14, 16, 17, 18, 19, 22, 23, 24, 25, 27, 33, 37, 38, 39 |
| 部分覆盖 | **13** | PWC-01, 02, 05, 11, 12, 20, 28, 29, 30, 31, 32, 36, 40 |
| 真实缺口 | **6** | PWC-04, 15, 21, 26, 34, 35 |
| 合计 | **40** | — |

**另有1项模块级RTL/合同不一致**（不属于上述任何一条验收ID的字面范围，因为PWC验收表里
根本没有对应行）：新START清除`o_protocol_error_sticky`与`o_switch_timeout_sticky`，
违反合同§6.2`:205`与§17.1`:731`；兄弟模块`ppg_peak_valley_window_detector.v`已于2026-08-23
的V1.2为同一条要求改过RTL并由PVW-37断言保护，PWC侧漏改且无ID覆盖。

**缺口性质**：6个真实缺口**没有一个是RTL功能性bug**——逐条反查RTL确认实现本身符合合同，
全部是"claim的这一半没有真实断言证据/断言被其他变量顶替"模式，与PVW-01~46批次的结论形态一致。
唯一的真实RTL问题是上面单列的START-sticky一条。是否修复（补断言、改RTL）属后续产品决定，
本次只调查记录，未修改任何项目文件。
