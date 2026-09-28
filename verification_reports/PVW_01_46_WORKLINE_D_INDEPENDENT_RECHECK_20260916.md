# PVW-01~46 峰谷窗口检测器验收ID独立复核——工作线D

> 方法声明：本文档不信任`PPG_ALIAS_MAPPING_TABLE.md`第283行起PVW小节的任何映射、
> 不信任2026-09-16工作线A"整合核验"给出的"断言非空/回归PASS"结论，把它们全部当作
> **待验证的声称**。复核方法与TOP-01~24批次1一致：(1)从
> `PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md`§16取每条ID的验收要求原文，
> 并回到§4~§13正文取该要求的规范定义（§16只有一行速记，正文才是真理来源）；
> (2)独立定位`tb_ppg_peak_valley_window_detector.v`里的真实断言，**完整读断言所在的
> 整段场景激励**（不是只读条件表达式或场景注释）；(3)对每条断言做confound排查——
> 断言是不是靠"这个变量恰好是复位默认值"而非claim要测的变量通过的，判断时按PVW-38
> 那次的教训**追完整task调用链**（`reset_dut`→`set_default_inputs`、`push_red`→
> `push_sample`、`start_fine_window`同时改3个变量）；(4)反查
> `ppg_peak_valley_window_detector.v`确认RTL行为与断言预期一致，并对关键断言做
> 静态变异推演（"如果RTL这一行写反，这条断言会不会仍然PASS"）。
>
> 回归证据新鲜度已独立核对：
> `ppg_system_integration/module_tb_regression/xsim_module_regression/tb_ppg_peak_valley_window_detector/xsim.log`
> 为2026-09-16 10:05:00 xsim v2022.2真实运行，46行`[PASS]`+汇总行`ALL PASS: 46 checks`，
> `$finish`在TB第1104行（正常收尾，非第1115行watchdog路径），仿真结束于516500 ns。
> **PASS本身只证明断言没有报错，不证明断言测到了claim——这正是本次复核的对象。**
>
> **状态：46项全部完成断言级复核**。结论：**4个真实开放缺口**（PVW-09/32/33/39，其中
> 09与39同一根因）+**8项部分覆盖**（PVW-01/19/21/25/26/34/35/40）+**34项CONFIRMED**。
> 零RTL功能性bug；全部缺口都是"RTL可能没问题，但claim的这一半没有真实TB断言证据"模式。
> 本次未修改任何RTL、TB、别名表或矩阵文件。

---

## 真实缺口1：PVW-32——"recheck pending"场景里零重检激励

**要求原文**：§16 `:832` "recheck pending | 不清极值、不清计数、不改变窗口状态"。
规范定义在§12.1 `:582`"仅有`recheck_pending`不得改变峰谷状态"与§12.3 `:618-625`
（"没有实际重检接管时，以下事件不得清理峰谷历史：…重检间隔到期但仍处于pending…"）。

**现有证据**（TB `:831-838`）：
```
reset_dut; start_run;
push_red(100, 16'd0);  push_red(90, 16'd1);
repeat(6)@(posedge i_clk);          // ← 这就是全部"recheck pending"
push_red(80, 16'd2);   push_red(70, 16'd3);
check_case("PVW-32", (o_peak_valid === 1'b1) && ($signed(o_peak_value) == 100));
```

**缺什么**：这段激励**没有驱动任何一个重检端口**。全文件grep确认
`i_recheck_busy`只在`:845`/`:851`（PVW-33/34场景）出现，`i_recheck_accept_event`只经
`pulse_control(4)`在`:843`和`:1082`出现，`i_recheck_done_event`只在`:853`出现——
PVW-32区间内一个都没有。`set_default_inputs`（`:288`）把`i_recheck_busy`置0，
`reset_dut`（`:330`）调用它，所以整个场景里重检相关输入恒为0。

实际被验证的是§12.3列表里**另一条**bullet（"ready/valid空拍或有界反压"）：6个2 MHz
空拍之后运行最大值100和下降计数1都还在（若计数被清，之后只剩2个下降样本，
`cnt_direction_confirm_next >= i_peak_confirm_count`不成立，断言会FAIL——这一点是真实
可判别的）。但"recheck pending"这个条件本身、以及"不改变窗口状态"这半句
（断言里没有任何`o_fine_window_active`项，场景里也从未建立过fine窗口）零覆盖。

**最接近claim的可用激励在TB里从未与活跃峰谷链组合过**：`i_recheck_busy=1`期间RTL只靠
`o_result_ready`（`:438`）封锁输入，`flag_runtime_clear`（`:346`）只认
`i_recheck_accept_event`不认`i_recheck_busy`——所以"busy期间极值/计数/窗口全部原样保留"
是可判别、可测试的真实状态。但`:845`那次`i_recheck_busy=1`发生在`start_run`之后、
一笔样本都没推的空上下文里（见缺口2），没有极值和计数可供保留。

---

## 真实缺口2：PVW-33——"仅…时允许accept"的排除半句零覆盖

**要求原文**：§16 `:833` "recheck安全接管 | **仅**FIR和检测器均idle时允许accept"。
§12.1 `:574-582`把它定义为调度器的accept条件必须包含`i_fir_idle && i_peak_valley_idle`，
其中`i_peak_valley_idle`接本模块`o_detector_idle`。

**现有证据**（TB `:840-844`）：`reset_dut; start_run;`之后立刻
`flag_case_ok = (o_detector_idle === 1'b1)`，然后`pulse_control(4)`打accept脉冲，
断言`flag_case_ok && (o_protocol_error_sticky===0) && (o_peak_valid===0) && (o_valley_valid===0)`。

**缺什么**：`仅`字表达的排除半句是这条要求的实质，而它在模块侧有**明确、已实现、
可判别**的落点——`ppg_peak_valley_window_detector.v:432`：
```verilog
assign flag_protocol_error_event = … || (i_recheck_accept_event && (o_detector_idle == 1'b0)) || …
```
即"非idle时到达accept→置协议诊断"。全TB两次accept脉冲（`:843`、`:1082`）**都发生在
完全idle的状态**：`:843`是START之后零事务的空状态，`:1082`是PVW-46里逐项核对过
9个排空条件之后的状态。没有任何一条用例在`o_detector_idle==0`时打accept。
这与TOP-02同型：**RTL结构上"非法accept"是可区分、可测试的真实状态，但没有专属负向测试**。

正向半句本身也偏弱：`:842`的`o_detector_idle===1'b1`是在START之后、一笔事务都没有的
状态下取的，`o_detector_idle`（`:464`）的6个与项此时全部平凡为真。

**已有的间接反向证据（不足以关闭本缺口）**：PVW-36 `:871`断言过
`o_local_empty === 1'b0`（此时有未消费峰值，且`flag_entry_precision_tail_active`已被
首笔15-bit中心样本清除，所以`o_local_empty`此刻等价于`o_detector_idle`）——这证明
"有在途事务时idle会掉0"，但不覆盖"此时来了accept该怎么办"。

---

## 真实缺口3+4：PVW-39与PVW-09——16-bit帧号自然回绕全项目零激励，
## 且PVW-39实际触发的是与PVW-20同一条判据

**要求原文**：
- §16 `:839` PVW-39 "frame_id半回绕 | 拒绝非法跨度，**无自然回绕误判**"；
- §16 `:809` PVW-09 "合格峰峰时间 | **模回绕帧差正确接受**"；
- 规范定义在§4.4 `:219-230`："全部正式时间使用无符号模减`frame_delta(a,b)=(a-b) mod 2^16`；
  合法差值必须小于`2^15`。达到或超过半回绕周期的峰谷、峰峰或窗口时间无资格，并置位协议诊断。"

**现有证据**：
- PVW-39（TB `:917-921`）：`push_red(100, 16'h0001); push_red(90, 16'h8001);`
  断言`(o_protocol_error_sticky === 1'b1) && (o_peak_valid === 1'b0)`。
- PVW-09（TB `:587-595`）：帧17~24，峰值落在帧21，上一正式峰在帧1，差值20，
  `i_min_peak_to_peak_frames=16'd20`，断言峰值140/帧21。

**缺什么（两层）**：

1. **PVW-39的PASS来自与PVW-20相同的判据，不是半回绕判据**。
   `flag_frame_protocol_error_event`（RTL `:427`）是5项OR，其中第1项是
   `flag_formal_sample && flag_previous_valid && (flag_frame_contiguous == 1'b0)`，
   而`flag_frame_contiguous`（`:378`）要求相邻正式帧差**严格等于1**。
   `0x8001 - 0x0001 = 0x8000 ≠ 1`，第1项立即成立。后4项（峰峰、峰谷、fine窗口帧龄、
   重新获取帧龄的最高位检查）在这个场景里连候选事件都不存在，全部为假。
   也就是说PVW-39和PVW-20（`:705-711`，帧0→帧2跳帧）触发的是**同一条OR分支**，
   只是跨度大小不同；把RTL `:427`后4项半回绕检查整体删掉，PVW-39依然PASS。
   要求原文的"拒绝非法跨度"指的正是那4项（跨事件的模减跨度），这部分零覆盖。

2. **全TB没有任何一笔样本把frame_id跨过0xFFFF→0x0000的自然回绕**。
   独立枚举TB里全部16进制帧号字面量：只有`:919`的`16'h0001`和`:920`的`16'h8001`；
   其余全是`16'd0`~`16'd111`的小十进制值（`16'd1000`量级的是`sample_index`不是
   `frame_id`）。因此：
   - PVW-09的"模回绕帧差正确接受"——用的是21-1=20的普通减法，**模回绕从未发生**；
   - PVW-39的"无自然回绕误判"——需要一笔真实跨越0xFFFF的合法序列证明它**不**被误判为
     非法，这个正向反例全项目不存在。

   RTL确实是按模减+最高位判据实现的（`:377`、`:385`、`:397`、`:410-412`，
   `dec_*`全部是无符号模减后查`[C_FRAME_ID_WIDTH-1]`），所以回绕行为是真实存在、
   可被测错的逻辑；一旦这里写错（例如某处误用有符号比较或加了饱和），现有46条用例
   没有一条会FAIL。

**PVW-09非回绕部分是强证据，不受本缺口影响**：同一场景里PVW-08先让帧13的局部峰因
13-1=12<20被拒，PVW-09再让帧21的峰因21-1=20通过——两者共用同一个"上一正式峰=帧1"的
参照，这同时反证了§7.2"不覆盖上一正式波峰"（若被拒的帧13峰覆盖了参照，21-13=8<20，
PVW-09会FAIL）。

---

## 断言层面的系统性观察（不单独计为缺口，但影响对"46/46 PASS"的解读）

### (a) 两条断言把TB自己驱动的输入当判据（恒真项）

全文件枚举`check_case(...)`里出现`i_*`输入的行，恰好2条：

| 位置 | 恒真项 | 为什么恒真 |
| --- | --- | --- |
| `:536` PVW-02 | `(i_active_precision_mode === 1'b0)` | `set_default_inputs`（`:319`）置0，`start_run`不碰它 |
| `:683` PVW-17 | `(i_frame_id == 16'd104)` | `make_basic_peak(16'd100)`最后一笔就是帧104 |

两条都不是DUT观测，永远不可能FAIL。好在两条ID的DUT侧判据本身是真的
（PVW-02的`o_reacquire_search_active===1`+`o_fine_window_active===0`；
PVW-17的`o_peak_frame_id==101`证明事件绑定极值帧而非确认帧104），所以不改变结论，
但"46个检查"里实际有效的比较项比字面看起来少。

### (b) PVW-21对自己的RTL锚点零敏感度

别名表给PVW-21的RTL锚点是`ppg_peak_valley_window_detector.v:417`
`flag_unauthorized_precision_event`。该表达式第2个与项是`(i_characterization_mode == 1'b0)`，
而PVW-21场景第一件事（TB `:715`）就是`i_characterization_mode = 1'b1`——**锚点信号在
它自己的用例里被结构性钉死为0**。加上PVW-21的断言只有
`(o_peak_valid===1) && ($signed(o_peak_value)==100)`、不含任何错误输出项，所以即便
`:417`的门控写反、协议sticky被误置，PVW-21仍然PASS。详见下表PVW-21行。

### (c) 从未被驱动为有效值的输入（RTL对应判据因此无判别力）

| 输入 | TB里的实际取值 | 影响 |
| --- | --- | --- |
| `i_reacquire_active` | 恒0（仅`:291`赋0） | §9.2"`i_reacquire_active=1`时重新获取"的**外部触发入口**从未被走过；`flag_reacquire_start_event`（RTL `:362`）恒假，PVW-26/27走的是START建立的那一轮 |
| `i_window_saturation_low`、`i_fir_saturation_low`、`i_fir_saturation_high` | 恒0 | `flag_no_saturation`（RTL `:350`）是4项与，只有`i_window_saturation_high`经`push_sample`被驱动过1（`:371`），另3项无判别力 |
| `i_frame_type` | 恒`2'b10`=`FRAME_TYPE_NORMAL` | §4.1的`i_frame_type == NORMAL`资格项（RTL `:349`）从未被非NORMAL帧检验过 |
| `i_detection_discard_identity_valid` | 恒0（scope-only） | 符合§12.4对scope-only flush的显式要求，但identity_valid=1分支无对照。RTL事实上根本不读该端口（见(d)） |

### (d) discard载荷端口在RTL里未被读取——PVW-35与PVW-36走的是同一条逻辑

grep确认`i_detection_discard_reason`/`identity_valid`/`sample_valid`/`frame_id`/
`color_ir`/`precision`/`config_epoch`/`amb_code_epoch`等只出现在端口声明
（RTL `:85-96`，注释自述"仅诊断用途"），模块体内只读
`i_detection_discard_event`与`i_detection_discard_run_generation`（RTL `:346`）。
这与合同§12.4一致（非缺陷），但意味着**PVW-35的`DISCARD_REASON_STOP`与PVW-36的
`DISCARD_REASON_ABORT`在DUT看来完全相同**，两条ID验证的是同一条`flag_runtime_clear`
路径，差别只在激励强弱（见PVW-35行）。

### (e) 三条RTL错误路径在46条用例里从未为真

| RTL信号 | 语义/合同出处 | 现状 |
| --- | --- | --- |
| `flag_unauthorized_precision_event` `:417` | §10.5第1条"没有正式start却观察到15-bit且被解释为NORMAL自动模式→置协议诊断" | 唯一可能触发它的两个场景（PVW-21/23）都把`i_characterization_mode`置1关掉了它 |
| `flag_precision_drop_event` `:424` | §10.5第2条"未完成返回握手却观察到`i_active_precision_mode=0`→撤销窗口+协议诊断+重新获取" | PVW-24/45/46三处把`i_active_precision_mode`拉0之前都已完成返回握手（`flag_return_accepted=1`），走的是`flag_fine_exit_complete`正常路径 |
| `flag_fine_protocol_fallback_event` `:423` → `RETURN_REASON_PROTOCOL`(2'b10) | §11.4三种返回原因之一 | 需要"fine窗口活跃 + 配置非法"同时成立；置`i_peak_valley_config_valid=0`的三处（PVW-35/37/38）都没有活跃fine窗口，该原因码从未被产生或断言 |

这三条里只有第1条落在某个PVW ID的名下（PVW-21的锚点）；后两条在§16验收表中没有对应
行，属于合同正文有要求但验收矩阵本身没有立项的空白，已如实记录，不在本次46条计数内。

---

## 完整复核表（46/46全部深度）

结论口径：**CONFIRMED**=核心claim有真实、可判别、无confound的信号级断言；
**部分覆盖**=`必须满足`里某个具名子句在本ID场景内无断言、只能靠邻近场景或结构间接支撑，
但无隐藏功能风险；**真实缺口**=具名子句全项目无真实覆盖，或断言因confound实际测的
不是claim那件事。

| ID | 场景（TB行号）与实际验证到的内容 | 结论 |
| --- | --- | --- |
| PVW-01 | `:533-534` 复位后检查3个valid+2个状态+3个sticky共8项全0 | **部分覆盖**——3个sticky是复位专属证据（RTL `:598/611/624`只认复位和`i_diag_clear_event`）；但另5项同时被`flag_context_clear`满足（此刻`i_run_enable=0`使`flag_runtime_clear`恒1，RTL `:346`），无法与复位路径分离；要求原文的"运行极值""计数"两个子句零观测（TB有层次化读内部信号的能力，见PVW-46，此处未用）。跨场景间接证据真实存在：45个场景都以`reset_dut`开头且依赖干净上下文（例如PVW-10紧跟PVW-09，若`reg_previous_peak_context`不清，21帧的旧参照会让新峰被半回绕判据拒绝，PVW-10会FAIL） |
| PVW-02 | `:535-536` START后`o_reacquire_search_active===1`、`o_fine_window_active===0` | CONFIRMED（含1个恒真项`i_active_precision_mode===1'b0`，见系统性观察(a)；DUT侧两项真实） |
| PVW-03 | `:537-538` 首峰120+`o_reacquire_search_active===1` | CONFIRMED——豁免是承重的：峰在帧1、`i_min_peak_to_peak_frames`默认4，若RTL `:386`的`(flag_previous_peak_valid==0)`豁免项不存在，1-0=1<4会被拒，断言会FAIL |
| PVW-04 | `:539` `o_peak_frame_id==1`、`o_peak_sample_index==1001` | CONFIRMED——事件身份绑定运行最大值帧1而非确认帧4，正是§4.2 `:191-192`的原话；"恰好第3个下降样本确认"的边沿时序由PVW-07/19的中间断言承担 |
| PVW-05 | `:544-550` 100/120/120/110/100/90→峰值120、帧**2**、序号**1002** | CONFIRMED——两个相同最大值取后一个，强判别 |
| PVW-06 | `:552-560` 死区2，100/90/91/80/70→峰值100 | CONFIRMED——"清零"变异体会让下降数只剩2、断言直接FAIL；"增加"变异体会让峰值提前1笔fire、随后`push_red(70,4)`因`o_result_ready=0`永久等待触发watchdog（`:1113`）而FAIL。两种变异都会被抓到，只是后者经由挂死路径而非直接判据 |
| PVW-07 | `:562-571` 反向95清零，含中间态`flag_case_ok=(o_peak_valid===0)` | CONFIRMED（强：先证明没有伪事件，再证明第3个下降才fire） |
| PVW-08 | `:573-586` 峰峰12<20被拒 | CONFIRMED |
| PVW-09 | `:587-595` 峰峰20>=20接受（帧21，值140） | **真实缺口**——"模回绕"限定词零激励，见上文缺口3+4；非回绕部分强且额外反证了§7.2不覆盖上一正式峰 |
| PVW-10 | `:597-602` 谷值50@帧7，确认发生在帧10 | CONFIRMED |
| PVW-11 | `:604-614` 50/50平台→谷值帧**7**（后一个） | CONFIRMED（强判别） |
| PVW-12 | `:616-627` 死区2，59@8为平坦→计数保持→谷值50 | CONFIRMED（变异分析同PVW-06） |
| PVW-13 | `:629-642` 反向清零+更新更低最小值45@帧9，含中间态 | CONFIRMED（强：同时验证两个子句） |
| PVW-14 | `:644-658` 幅度10<20→无谷值无返回 | CONFIRMED——幅度是唯一判别量（峰谷间隔5>=2合格）；"继续跟踪"半句本场景无后续断言，但结构上RTL既不accept也不restart、状态停留`ST_SEARCH_VALLEY`，同类继续跟踪由PVW-15→16连续场景实证 |
| PVW-15 | `:660-671` 峰谷间隔6<10→无谷值无返回 | CONFIRMED——间隔是唯一判别量（幅度70>=20合格）；"继续跟踪"由同一场景不复位直接续跑的PVW-16实证 |
| PVW-16 | `:672-678` 谷值50/帧13/序号1013/三个epoch全核对 | CONFIRMED（"原子输出完整实际元数据"逐字段覆盖） |
| PVW-17 | `:680-683` 峰帧101≠确认帧104 | CONFIRMED（核心判据真实；含1个恒真项`i_frame_id==104`，见观察(a)。"不重复减去10帧"由"输出帧号等于该笔事务自带帧号"证实） |
| PVW-18 | `:685-692` 中间插入IR样本(-7000000@帧500)后峰值100/帧0照常 | CONFIRMED——IR被消费由`push_sample`严格等`o_result_ready`不挂死证明；RED状态不变由"下降计数跨IR样本continue累计到3"证明（若IR清了计数，之后只剩2笔下降，会FAIL）。"逐位不变"字面强于实测（只核对了极值/帧号与计数连续性） |
| PVW-19 | `:694-703` 不合格样本+饱和样本都不形成方向证据，含中间态 | **部分覆盖**——`i_detection_qualified=0`与`i_window_saturation_high=1`两类真实且强判别（若它们形成证据，峰值会提前fire）；但`flag_no_saturation`（RTL `:350`）的另外3个与项（window_low、fir_low、fir_high）全TB恒0，"饱和"半句只覆盖1/4输入 |
| PVW-20 | `:705-711` 帧0→帧2跳帧→协议sticky=1且无峰 | CONFIRMED——"清方向计数"强判别（跳帧后只剩90/80/70三笔中2笔，若计数不清会凑满3笔fire）；"保留正式周期"半句无断言，该场景也不存在正式周期 |
| PVW-21 | `:713-724` characterization下9→15→9切换，峰值100照常 | **部分覆盖**——"FIR趋势、运行极值和计数连续"真实（下降计数跨精度切换累计到3）；但"合法历史精度尾部不报错"半句：断言里**没有任何错误输出项**，且场景中`i_precision_mode`与`i_active_precision_mode`始终同步翻转、**根本没有构造出尾部**（真正的尾部覆盖在PVW-42/45，那里`o_protocol_error_sticky===0`是真实断言）。另：`i_characterization_mode=1`使本ID对自己的RTL锚点`:417`零敏感度，且"普通(NORMAL)切换"被替换成了CHARACTERIZATION分支——NORMAL下同样的激励按§10.5第1条本应报错。NORMAL模式下的9→15历史连续性由PVW-22真实覆盖 |
| PVW-22 | `:726-733` commit前1笔下降+commit后2笔下降凑满3笔→峰值100 | CONFIRMED（强：直接证明start事件不清粗链状态，RTL `:667/717`的清除列表确实不含start事件） |
| PVW-23 | `:735-741` characterization+15-bit但无start→`o_fine_window_active===0` | CONFIRMED——与§10.1 `:423`原句逐字对应；三种列举情形（手动/CHARACTERIZATION/校准）只走了CHARACTERIZATION一种 |
| PVW-24 | `:743-761` 谷值→返回请求(reason 00/帧10)→保持3拍→握手后窗口仍active→实际9-bit后才关窗 | CONFIRMED（四阶段强证据，与§10.3逐条对应。观察：返回载荷绑定的是确认帧10而非谷值帧7，RTL `:556`用`i_frame_id`，§10.3"绑定的谷值元数据"措辞对此有歧义，谷值自身元数据在`o_valley_*`端口上完整输出，非缺陷） |
| PVW-25 | `:763-772` fine窗口超时sticky+返回请求reason 01+帧14+无伪谷值 | **部分覆盖**——前3个子句强判别；"并重新获取"第4子句无断言，且按RTL实现超时只置`flag_recovery_return_pending`（`:996`）、`reacquire_search_active_o`（`:588`）的置位列表里**不含**fine超时事件，真正重新获取要靠上层回灌`i_reacquire_active`——而该输入全TB恒0（观察(c)） |
| PVW-26 | `:774-781` 重新获取超时sticky=1、搜索仍active、无伪峰 | **部分覆盖**——"置sticky""自动开始下一轮"真实；"保持9-bit""清候选"两子句无断言（清候选即RTL `:667`清`reg_running_context`，本场景中后续激励对其是否被清不敏感） |
| PVW-27 | `:782-790` 超时后真实出峰→握手后`o_reacquire_search_active`落0，sticky仍为1 | CONFIRMED——"恢复固定斜率基线建立资格"在模块边界上的唯一可观测表达就是RTL `:590-591`的"峰值被动态基线消费后结束重新获取"，断言正对该点 |
| PVW-28 | `:792-797` 峰值保持+`o_result_ready===0`+4拍后载荷不变 | CONFIRMED——"不接受覆盖事件"由`o_result_ready=0`结构性封锁输入证明（§11.1有界反压）；"逐拍稳定"实测为2个采样点而非逐拍监视，字面强于实测 |
| PVW-29 | `:799-806` 谷值保持+`o_result_ready===0`+4拍后不变 | CONFIRMED（同上note；"不重复消费"由PVW-45中"先消费谷值、再消费返回请求"两分支互不干扰实证） |
| PVW-30 | `:808-816` 返回请求reason/frame_id保持5拍 | CONFIRMED（"模式不提前切换"由PVW-24的窗口关闭时序承担） |
| PVW-31 | `:818-829` 中途改`i_config_epoch`=9→协议sticky=1、无谷值、无返回 | CONFIRMED（强：RTL `:426`的三项epoch比较任一漂移即触发，且`flag_tracking_restart`清活动峰，结构与断言一致） |
| PVW-32 | `:831-838` | **真实缺口**（见上） |
| PVW-33 | `:840-844` | **真实缺口**（见上） |
| PVW-34 | `:845-854` busy期间`o_result_ready===0`且无事件；recheck_done+success后回到重新获取 | **部分覆盖**——"三帧期间无正式事件"以3个2 MHz时钟拍近似（非3帧），机制真实（`i_result_valid`持高但ready被封锁）；"清峰谷上下文"在本场景**空转**——`:843`那次accept打在START后零上下文的状态上，没有上下文可清。该子句的真实证据在PVW-46（`:1082-1095`，10个内部状态逐项核对） |
| PVW-35 | `:856-865` 陈旧代际discard不清理（反例）→当前代际discard后sticky保留、搜索状态清零 | **部分覆盖**——"保留sticky"与"代际作用域"两点真实且强（陈旧代际反例是真正的负向对照）；但"清运行事务"在本场景几乎无物可清：discard发生时`o_peak_valid`/`o_valley_valid`/`o_return_9bit_valid`本来就已是0（该场景唯一的样本因`i_peak_valley_config_valid=0`被判非法、从未进入正式链），真正被清的只有`o_reacquire_search_active`。又因RTL不读`i_detection_discard_reason`（观察(d)），STOP与abort是同一条路径，机制侧由PVW-36的强激励覆盖 |
| PVW-36 | `:867-878` 活跃fine窗口+未消费峰值+`o_local_empty===0`→陈旧代际无效→当前代际abort后全清且`o_local_empty===1`，6拍后载荷仍为0 | CONFIRMED（全组最强的生命周期用例：有真实在途事件可撤销、有负向对照、有`o_peak_value==0`载荷核对。"禁止迟到提交"以abort后6拍无事件出现表达，未再推陈旧样本做更强反例） |
| PVW-37 | `:880-905` 同拍新异常压过`i_diag_clear_event`→单独diag_clear能清→STOP discard不清→新START不清 | CONFIRMED（§13.2优先级与§12.4三个子句逐条真实覆盖，是全组唯一一次显式验证"异常置位优先于同拍清除"） |
| PVW-38 | `:907-915` `i_peak_valley_config_valid=0`下推含真实峰形的5笔样本→协议sticky=1、无峰无谷 | CONFIRMED——本次独立重走了任务卡2的confound排查：`reset_dut`(`:327`)内部`:330`调用`set_default_inputs`(`:266-324`)已把`i_characterization_mode`复位为0(`:301`)、六项阈值复位为合法非零默认(`:292-299`)，`:909`只单独把config_valid改0，因此`flag_active_config_legal`(RTL `:351`)这条与式里**唯一被驱动为非法的变量就是C22**，`flag_config_protocol_error_event`(RTL `:430`)外层要求的`i_characterization_mode==0`也确实成立。原结论成立，无需修正 |
| PVW-39 | `:917-921` | **真实缺口**（见上，且实际触发的是与PVW-20同一条判据） |
| PVW-40 | `:923-969` 宽位随机波形（起点7000000），比对峰/谷的值、帧号、序号 | **部分覆盖**——比对对象是真实存在的（DUT输出 vs TB侧独立累计的`model_*`），平台规则与3点确认也被模型编码；但(1)"独立软件黄金模型"实为同文件内的极值记账，不是独立实现；(2)"逐事务一致"实为23笔事务里2次事件级比对；(3)"宽位"只走了7.0e6附近的正值、单步≤256，从未接近24-bit有符号边界，也从未产生需要25-bit扩位才不回绕的大差值（§5 `:261`那条要求的判别力未被激发） |
| PVW-41 | `:971-978` 峰后帧龄达`i_max_fine_window_frames`→重新获取sticky=1、搜索active、无返回请求、fine超时sticky保持0 | CONFIRMED（§8.4四个子句全覆盖，其中"不得置位`o_fine_window_timeout_sticky`"这条区分性断言真实存在） |
| PVW-42 | `:980-989` 窗口提交后10笔旧9-bit中心样本无错→第11笔置协议错误 | CONFIRMED——边界精确（RTL `:905`计到`FIR_GROUP_DELAY_LIMIT`=10，`:414`在第11笔比较`>=`），且前10笔的`o_protocol_error_sticky===0`是真实断言。"继续更新粗趋势"半句由PVW-44中"起点前9-bit样本仍形成粗峰"实证 |
| PVW-43 | `:991-1002` `i_max_fine_window_frames=1`下，起点前10笔负帧龄样本既不超时也不报回绕 | CONFIRMED（强判别：门限压到1，若负帧龄被当成巨大正帧龄，第一笔就会超时；若被当成回绕，`:427`第4项立即报错。"不形成正式fine峰谷对"半句因波形恒定在本场景不可能形成，真实证据在PVW-44） |
| PVW-44 | `:1004-1036` 起点前9-bit峰(帧91)配谷→无谷值无返回；起点后15-bit峰(帧102)配谷(帧108)→谷值+返回 | CONFIRMED（全组最强的功能用例：同一场景内正负对照，精确打在RTL `:404`的`(fine_window_active_o==0) \|\| flag_active_peak_fine_qualified`与`:405`的restart分支上） |
| PVW-45 | `:1038-1056` 返回完成后10笔旧15-bit中心样本合法→第11笔置协议错误 | CONFIRMED（含`o_fine_window_active===0`核对，确认退出尾部不延长窗口） |
| PVW-46 | `:1058-1096` 退出尾部active时`o_detector_idle===1`（连同6项排空条件逐项核对）→accept后10个内部状态原子清零 | CONFIRMED（全组内部可见度最高的用例，直接对应§11.5 `:562-565`与§12.1 `:593-594`。§12.2清理清单里"重新获取计时上下文"与"正式fine窗口资格"两项未列入断言——前者RTL `:964/979`确实被`flag_context_clear`清、后者在本场景本就为0） |

---

## 汇总

- **4个真实开放缺口**：PVW-09、PVW-32、PVW-33、PVW-39。其中PVW-09与PVW-39同一根因
  （16-bit帧号自然回绕全项目零激励，且PVW-39的PASS来自与PVW-20相同的帧连续性判据，
  不是半回绕跨度判据）；PVW-32（"recheck pending"场景零重检激励）与PVW-33
  （"仅…时允许accept"的排除半句零覆盖，而RTL `:432`明确实现了该排除）各自独立。
  四条全部是"RTL可能没问题，但claim的这一半没有真实TB断言证据"模式，**没有发现
  RTL功能性bug**。是否补测试是后续产品决定，本次只做到调查清楚
  （[[project-ppg-fix-dont-defer]]）。
- **8项部分覆盖**：PVW-01、19、21、25、26、34、35、40。共同形态是"`必须满足`里某个
  具名子句在本ID场景内无断言，靠邻近场景或RTL结构间接支撑"，参照TOP-05/07/21的处理
  口径，不算功能性缺陷。其中PVW-21值得单独留意：它对自己的别名表RTL锚点
  （`:417 flag_unauthorized_precision_event`）零敏感度。
- **34项CONFIRMED**：有真实、具体、信号级且经变异推演可判别的断言证据。PVW-38经独立
  重走确认任务卡2结论无误。PVW-44、PVW-46、PVW-37、PVW-36、PVW-43是全组证据强度最高的
  五条。
- **别名表是否存在系统性错误模式**：**没有**。46行的TB行号、RTL锚点行号逐条核对全部
  对得上（RTL锚点均落在真实驱动该ID行为的`assign`/寄存器分支上），不存在
  B_TAG_MISSING批次2~5里反复出现的"家族共享锚点集体错位"。本次发现的问题全部在
  **断言强度与激励构造**层面，不在映射层面——这与工作线A当时"只核验场景存在+断言非空"
  的边界是自洽的：那道工序不负责判断断言是否测到了claim。
- **两条正文级空白（不计入46条）**：§10.5第2条（`flag_precision_drop_event`）与
  §11.4的`RETURN_REASON_PROTOCOL`(2'b10)回退路径，在§16验收矩阵里本来就没有立项，
  RTL已实现但46条用例无一触发，如实记录供后续决定是否补立ID。
