# FIR-01~33 `ppg_coarse_detection_fir`验收ID独立复核——工作线D（已完成）

> 方法声明：本文档不信任`PPG_ALIAS_MAPPING_TABLE.md:396-436`"FIR-01~33"小节的任何映射、
> 不信任工作线A（2026-09-16 TB适配+打标签）"断言非空、回归PASS"的整合结论，把它们全部
> 当作"待验证的声称"。复核方法：(1)从`PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md`
> 第16节验收表`:607-639`取每条ID的验收要求**原文**（不是别名表的转述），(2)独立定位TB
> 断言并**完整读断言所在的整个测试段**（不是只读`check_condition`的条件表达式或`[PASS]`
> 标签——本次最大的两个发现正是"条件表达式看着有检查、其实是TB自己跟自己比"和"用例名
> 写着测某个claim、代码里零激励"），(3)对怀疑confound的条目按PVW-38方法追完整调用链
> （`send_sample`→`load_sample_fields`、`apply_reset`的默认值、记分板always块的触发条件），
> (4)反查`ppg_coarse_detection_fir.v`确认RTL行为与断言预期一致、并判定结构可达性。
>
> **边界**：本次只读不改。未编辑别名表、矩阵、RTL或TB任何一个字节。
>
> **合同文件实际位置更正**：任务书给的路径是`ppg_coarse_detection_fir/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md`，
> 该路径**不存在**。真实权威文件在`ppg_system_integration/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md`
> （另有一份2026-08-20基线快照在`ppg_system_integration/baselines/`下，非权威）。别名表引用的
> `:607-639`行号对准的正是`ppg_system_integration/`这一份，行号**准确**。
>
> **状态：33项全部完成断言级复核**。结论：**4个真实缺口**（FIR-01/12/19/21）+
> **8项部分覆盖**（FIR-07/10/14/15/18/23/24/28）+**21项CONFIRMED**。
> 未发现RTL功能性缺陷；4个真实缺口全部是"RTL大概率没问题，但claim的这一部分没有真实
> 信号级断言证据"模式。

## 先行事实核对（这些"声称"经独立验证成立）

在展开缺口之前，先记录几项经独立核对**成立**的事实，避免把本报告读成"别名表整体不可信"：

- **33条RTL锚点行号全部准确**。逐条打开`ppg_coarse_detection_fir.v`核对，别名表第3列
  引用的每一个`文件:行`（`:309/311/315/319/323/324/325/326/329/359/385/386/388/389/406/444/451/494/547/619/696/737`）
  都落在正确的语句上，且该行确实带对应的`@satisfies`标签。**没有出现B_TAG_MISSING那几个
  家族（OIB/RRC/SID/LFA）"共享锚点连错"的系统性错误模式。**
- **33条回归PASS行号全部准确**。`module_tb_regression/xsim_module_regression/tb_ppg_coarse_detection_fir/xsim.log`
  共118行，逐条核对：FIR-01在`:17`、FIR-30在`:111`、FIR-31/32/33在`:112/113/114`，
  别名表引用无偏差。日志尾行`PPG_COARSE_DETECTION_FIR_V2_TB_PASS pass=98`，`$finish`在TB:1071。
- **断言条数可独立闭合**。手工清点TB全部`check_condition`**执行次数**（含循环展开）
  得98次，与`C_EXPECTED_PASS_COUNT = 32'd98`（TB:72）、与xsim日志`pass=98`三方一致。
  TB:1066最终判定同时要求`cnt_error == 0 && cnt_pass == C_EXPECTED_PASS_COUNT`——
  **这意味着任何一条断言被静默跳过都会让整份TB判FAIL**，这是本家族一个真实的强性质，
  值得记录。
- **"只使用一个乘法器"（FIR-22后半句）结构上为真**。全文件grep`*`共19处，其中18处是
  参数/genvar常量索引运算（`SAMPLE_WIDTH * 32'd9`等），真实信号×信号乘法只有
  `ppg_coarse_detection_fir.v:384`一处（`dec_mac_operand * dec_mac_coefficient`）。
- **"不新增sticky端口"（FIR-30后半句）结构上为真**。模块输出端口清单（TB:1117-1167例化处
  逐条核对）无任何`sticky`/`timeout`类输出，超时只经`flag_transaction_clear`内部撤销。
- **首笔样本预填21份拷贝不构成"复制样本"违规（合同`:60`禁止项）**。RTL:665/682首笔
  `{21{dec_sample_input}}`预填物理tap，但计数只加1（RTL:697/710），且窗口只读tap0~19
  （生成块RTL:760上界为20）。第21笔真实样本到达时tap0~19恰好是20笔互异真实样本，
  预填拷贝已被移出窗口。**"窗口只含21笔真实样本"（FIR-03后半句）结构上成立**，
  TB黄金模型（TB:353-360）镜像同一预填约定这件事在输出端不可观测，不构成模型污染。

## 真实缺口1：FIR-01——"撤销MAC"和"载荷/诊断为冻结复位值"零断言，"计数"只验证了`<21`

要求原文（合同`:607`）：「异步复位 | **撤销MAC**，valid、**计数**、历史资格、**诊断**和**载荷**为冻结复位值」——五个子句。

现有证据只有TB:723一条：

```verilog
apply_reset;                          // TB:722
check_condition(o_result_valid == 1'b0 && o_history_full_r == 1'b0 && o_history_full_ir == 1'b0 && o_fir_idle == 1'b1, "FIR-01 asynchronous reset");
```

逐子句核对：

- **"撤销MAC"——零覆盖，且这条断言执行在"无MAC可撤销"的处女状态**。TB:722是仿真中第一次
  `apply_reset`，此前`i_result_valid`一直为0（TB:672初始化），DUT从未收过任何事务。也就是说
  断言执行时**根本没有在途MAC、没有历史、没有输出**，"撤销"这个动作无从发生。追完整调用链
  确认：TB全文22处`apply_reset`调用（:722/733/746/753/761/766/772/821/827/834/871/888/895/902/909/926/944/959/974/983/998/1037），
  **每一处之前DUT都已经`drain_output`或`wait_fir_idle`或刚被别的事件清空**，没有任何一处
  是"MAC在途时拉复位"。对照：FIR-25专门测了START/STOP/abort在MAC第3/5/7拍撤销，`i_rstn`
  这条撤销路径反而从未在途测过。
- **"载荷为冻结复位值"——零覆盖**。断言完全没有检查`o_filtered_ppg_value`、
  `o_frame_id`、`o_sample_index`、`o_config_epoch`等任何载荷/元数据端口的复位值。
- **"诊断为冻结复位值"——零覆盖**。`o_detection_qualified`、`o_window_saturation_low/high`、
  `o_fir_saturation_low/high`四个诊断端口一个都没检查。
- **"计数"——只验证了`<21`，没有验证`==0`**。RTL:414/415是
  `assign o_history_full_r = cnt_red_sample >= 5'd21;`，所以`o_history_full_r == 1'b0`
  只能证明计数小于21，**不能证明计数是0**。TB在FIR-31/32/33里明明已经会用
  `dut.cnt_red_sample`层次化引用做精确计数比较，FIR-01这里没用。
- 唯一真实覆盖的是**"valid"**子句（`o_result_valid == 1'b0`）。另外因为寄存器上电值是X、
  而`check_condition`用`!== 1'b1`判定，这条断言确实证明了复位真的触发过（否则X比较会判FAIL）——
  这是它唯一的额外价值。

RTL侧独立核实：`payload_o`(:436)、`result_valid_o`(:451)、`state_current`(:510)、
`reg_accumulator`(:522)、`cnt_mac_index`(:541)、`cnt_process_cycle`(:558)、
`reg_red_history`(:660)、`reg_ir_history`(:677)、`cnt_red_sample`(:694)、`cnt_ir_sample`(:707)、
`reg_window_data`(:720)、`reg_context_snapshot`(:733)、`reg_window_status`(:746)、
`flag_test_calibration_loss_armed`(:467)——**14个时序块全部有`if(i_rstn == 1'b0)`异步复位分支**，
所以这是证据缺口不是RTL缺陷。

## 真实缺口2：FIR-12——断言执行时零激励，8拍空转只是把FIR-08/11已经建立的状态再看一眼

要求原文（合同`:618`）：「recheck pending等待 | 仅pending不改变任一历史状态」。

现有证据（TB:794-795）：

```verilog
repeat(8)@(posedge i_clk);             // 仅等待模拟recheck pending
check_condition(o_history_full_r == 1'b1 && o_history_full_ir == 1'b1, "FIR-12 pending alone keeps histories");
```

注释自己写的是"仅等待模拟recheck pending"——**这8拍里TB什么都没驱动**：
`i_recheck_busy`当时是0（TB:800才置1）、`i_recheck_accept_event`是0、`i_result_valid`是0。
断言读到的`o_history_full_r/ir == 1`是FIR-08/FIR-11两步早已建立并已断言过的状态，
**这条断言对任何DUT行为都恒真，提供零信号级证据**。

追端口边界确认这不是"随便挑个信号驱动一下"就能补的，必须说清楚：

- **FIR模块没有`pending`输入端口**。全RTL grep`pending`只有3处命中，全部与recheck无关
  （`:312`是注入端口注释里的"没有其它注入pending"）。recheck相关输入只有
  `i_recheck_accept_event`(:73)和`i_recheck_busy`(:74)两个。
- 合同`:485`明确规定：「`i_recheck_busy`连接其`o_amb_recheck_busy`，**不能用仅表示间隔
  到期的`o_amb_recheck_pending`代替**」——也就是说`pending`是调度器内部信号，**故意不
  接到FIR**。从这个角度，"仅pending不改变历史"在端口边界上是**结构性恒成立**的。
- 但是合同`:483`又把`i_recheck_busy`定义为「**接管等待**和三帧重检期间禁止接收新的
  NORMAL输入」——"接管等待"正是pending语义在FIR端口上的唯一投影。**这个投影是可驱动的，
  而TB从来没有在历史非空时驱动过它**：FIR-14（TB:800-805）确实驱动了`i_recheck_busy=1`，
  但那6拍发生在FIR-13刚刚把两色历史清空之后（TB:799断言`o_history_full_r/ir == 1'b0`），
  此时"不改变任一历史状态"根本无从检验。

结论：FIR-12这条ID在TB里是零激励的空断言。RTL侧无风险（无端口即无路径），但这属于
"用一条恒真断言登记了一个本该用结构性理由登记的条目"，与TOP-09"只有DIAG打印不是断言"
同类。

## 真实缺口3：FIR-19——合同明文要求"自检TB必须报告该错误"，TB从未报告

要求原文（合同`:625`）：「非NORMAL输入 | 不移动历史，**TB报告集成协议错误**」。
合同`:95`把这条写得更死：「若非NORMAL事务到达，属于上游集成协议错误；RTL不得把它作为
PPG样本移入历史，**自检TB必须报告该错误**。」

现有证据（TB:836-837）：

```verilog
send_sample(24'sd9999, 1'b0, 1'b0, 1'b1, 1'b0, 1'b0, 2'b00, 4'd0); // 注入AMB_CAL事务
check_condition(o_history_full_r == 1'b0 && o_result_valid == 1'b0, "FIR-19 non-NORMAL input ignored");
```

- **前半句"不移动历史"CONFIRMED**：20笔合法样本之后注入一笔`i_frame_type=2'b00`，
  若被计入则`o_history_full_r`会变1。RTL:309`flag_history_transfer`确实带
  `(i_frame_type == 2'b10)`门控。这一半是真实的、信号级的、无confound的。
- **后半句"TB报告该错误"零实现**：TB全文没有任何针对非NORMAL输入的告警`$display`，
  也没有任何计数器/监视器记录这类协议违规。TB:306/309的两条`[FAIL]`打印只针对记分板
  载荷不匹配，与frame_type无关。这条不是"测量方法弱"，是合同明文点名的TB义务**完全没做**。

与TOP-18"负向半句承诺但从未真正写出来"同型。

## 真实缺口4：FIR-21——"输入载荷保持"是TB拿自己的寄存器跟自己比（恒真），"只消费一次"是近乎恒真的析取式

要求原文（合同`:627`）：「MAC有界反压 | **busy期间ready为0**，**输入载荷保持**，**恢复后只消费一次**」——三个子句。

现有证据是TB:852-869一整段：

```verilog
@(negedge i_clk);
load_sample_fields(24'sd7200, 1'b1, ...);          // TB:853 TB自己驱动 i_coarse_ppg_value = 7200
i_result_valid = 1'b1;
reg_held_payload = {89'd0, i_coarse_ppg_value};    // TB:855 用 i_coarse_ppg_value 给自己快照
repeat(4)begin
    @(posedge i_clk);
    #1;
    check_condition(o_result_ready == 1'b0 && i_coarse_ppg_value == reg_held_payload[23:0], "FIR-21 bounded input backpressure"); // TB:859
end
```

- **"busy期间ready为0"CONFIRMED**：`o_result_ready == 1'b0`是真实DUT输出观察，
  且此刻旧输出确实被反压（`i_result_ready=0`自TB:842起），RTL:406
  `o_result_ready = ... && (state_current == ST_IDLE) && flag_buffer_available`
  与之一致。这一子句无问题。
- **"输入载荷保持"是恒真式**：`i_coarse_ppg_value`是**TB自己的reg**（TB:102声明），
  这4拍里TB没有再调用`load_sample_fields`、没有任何别的语句改它；
  `reg_held_payload[23:0]`又是TB:855从同一个`i_coarse_ppg_value`抄来的。
  **这是TB拿一个常量跟它自己的副本比，无论DUT做什么都不可能FAIL，零DUT信息量。**
  合同这一句本意是"上游（TB扮演）必须遵守保持型协议"，属于TB侧协议义务，
  但用`check_condition`登记成一条"通过的验收断言"是误导性的。
- **"恢复后只消费一次"近乎恒真**（TB:869）：

  ```verilog
  check_condition(o_result_ready == 1'b1 || dut.state_current != 2'b00, "FIR-21 input resumes exactly once");
  ```

  这是一个析取：反压解除后要么DUT重新给ready（=1），要么DUT正在算（state≠IDLE），
  **两者必居其一，构造上几乎不可能为假**，而且它完全没有"计数"——
  "只消费一次"要的是"握手次数恰好+1"。TB里明明有现成的`cnt_input_transfer`
  （TB:250-254，且FIR-31正是用`(cnt_input_transfer - cnt_input_snapshot) == 2`
  精确计数的），这里没用。

  补充确认这条claim在别处也没有被覆盖：**记分板抓不到重复消费**。记分板
  （TB:317）判断输入握手用的是`i_result_valid && o_result_ready`，与DUT自己
  消费事务用的是同一个条件——若DUT真的连消两次，黄金模型也会跟着移两次历史，
  载荷比较仍然一致。所以"只消费一次"在FIR-21场景下**没有任何检测手段**。

## 部分覆盖清单（8项：有真实证据，但字面要求强于实测方法，或命名断言本身被confound）

### FIR-07：`显式饱和合同`这一半在冻结系数下结构性不可达

要求原文（`:613`）：「signed 24-bit端点 | 41-bit乘积和42-bit累加无回绕，**输出符合显式饱和合同**」。

TB:764/769两条断言分别驱动21笔`24'sh7fffff`和21笔`24'sh800000`，检查输出等于端点
**且`o_fir_saturation_high/low == 1'b0`**——即只验证了"不饱和"这个负向面。

独立算过：21个系数`164,231,409,704,1100,1566,2056,2515,2891,3136`对称两份加中心`3224`，
和恰为`32768 = 2^15`（直流单位增益，FIR-04同源）。全部系数为正⇒输出是输入的凸组合⇒
`|y| ≤ max|x| ≤ 2^23`。取两个极端代入RTL:388-392的舍入路径：
最大正`(2^23-1)*32768 + 16384 >>> 15 = 8388607`（恰等于`FIR_CODE_MAX`，不大于）；
最负`-(2^23)*32768`走幅值路径得`-8388608`（恰等于`FIR_CODE_MIN`，不小于）。
**因此RTL:391/392的`flag_fir_saturation_low/high`在冻结系数下永远为0，
RTL:393的钳位三目`dec_filtered_value`的两条饱和支路是结构性不可达的死路径。**
TB无法（也不可能）给出正向饱和证据。这与OIB-04/06"真结构性无锚点"同类：
记录为部分覆盖并点明不可达性，比记一条假CONFIRMED诚实。

### FIR-10：命名断言被confound（中心与最新样本的精度位在检查时刻恰好都是1）

要求原文（`:616`）：「9/15-bit交错 | 历史连续，系数和输出数学不随精度变化」。

别名表引用的断言是TB:787`check_condition(o_precision_mode == 1'b1, "FIR-10 precision metadata follows center")`。
按PVW-38方法追激励链：

- 红光（TB:774）精度 = `cnt_test_index[0]`；红外（TB:779）精度 = `~cnt_test_index[0]`。
- 断言时刻观察的是第21笔红外样本（`cnt_test_index=20`）产生的输出，其中心是
  `x[n-10]`＝红外第11笔（`cnt_test_index=10`），精度 = `~(10 & 1) = 1`。
- 而**最新输入**（`cnt_test_index=20`）精度 = `~(20 & 1) = 1`，
  **检查时刻总线上的`i_precision_mode`也还是1**。

**三个候选来源（中心／最新样本／当前总线）在这一刻全部等于1，断言无法区分任何一个**——
一个直接把最新输入精度接到`o_precision_mode`的错误DUT也会通过。用例名
"precision metadata follows center"所声称的东西，这条断言没有测到。

但**合同FIR-10真正要求的东西是覆盖的**：交错精度的21+21笔全程由记分板逐笔比较完整
113-bit载荷（黄金模型TB:341/381对任何精度都用同一组系数），"系数和输出数学不随精度变化"
由此得证；"历史连续"由同段TB:784的`o_history_full_r/ir == 1'b1`得证。且中心精度这件事
另有FIR-29（TB:963-971，旧样本精度0／新样本精度1，干净可区分）给出无confound的证明。

结论：ID层面判部分覆盖；但**别名表为FIR-10引用的那条断言应当视为无效证据**。

### FIR-14："三帧重检活动"用6个2 MHz时钟拍代替

要求原文（`:620`）：「三帧重检活动 | 不移位、不插0、不产生正式FIR事务」。
TB:800-805驱动`i_recheck_busy=1`并连查6拍`o_result_ready==0 && o_result_valid==0`。
每颜色400 Hz、时钟2 MHz⇒一帧约5000拍，**"三帧"≈15000拍，实测6拍**。机制正确
（RTL:406的`i_recheck_busy`门控是组合的，与持续时长无关），但字面时长未兑现。
"不插0"这一半不是这条断言给的，是FIR-15给的（若busy期间插了0，TB:807那20笔之后
`o_history_full_r`会提前变1，TB:808会FAIL）——交叉引用成立。属TOP-05/07/21同型。

### FIR-15："两色分别"只测了红光一色

要求原文（`:621`）：「重检后恢复 | **两色分别**重新累计21笔真实NORMAL样本」。
TB:807/809/811重新预热的全是红光（`sample_color_ir=1'b0`）；FIR-13把两色历史一起清空后，
**红外在本场景（以及此后到下一次`apply_reset`之前）再也没有收到过任何样本**，
`o_history_full_ir`的恢复过程零断言。别名表给FIR-15的RTL锚点也只有红光那条
（`:696` `cnt_red_sample <= 5'd0`），没有红外对应的`:709`。

RTL侧独立确认两色是严格对称结构（`cnt_red_sample`:692-702 与 `cnt_ir_sample`:705-715
逐行同构，同一个`flag_history_clear`驱动），且红外"从空开始累计到21笔"在FIR-08/FIR-27/FIR-31
里都被真实走过——只是那几处的清空来源是`i_rstn`而不是`flag_history_clear`。
风险很低，但字面上"两色分别"确实只兑现了一半。

### FIR-18：窗口饱和OR的4个上游输入只激励了2个；且饱和样本恰好是最新样本

要求原文（`:624`）：「上游饱和样本 | 数值不丢弃，窗口饱和OR和检测资格正确」。

- RTL:316/317把4个上游端口归并为2个单点诊断：
  `flag_sample_saturation_low = i_stage1_saturation_low || i_coarse_saturation_low`、
  `flag_sample_saturation_high = i_stage1_saturation_high || i_coarse_saturation_high`。
- 但`load_sample_fields`（TB:459-462）**硬编码**了
  `i_stage1_saturation_high = 1'b0`和`i_coarse_saturation_low = 1'b0`，
  只把调用者的`sample_saturation_low`接到`i_stage1_saturation_low`、
  把`sample_saturation_high`接到`i_coarse_saturation_high`。
  全文件grep确认这两个端口**在整份TB里从来没有被驱动成1**（命中仅TB:106/107声明、
  TB:320-322黄金模型、TB:460-461硬置0、TB:677-678初始化、TB:1127-1128例化）。
  **两个OR各有一个输入项零覆盖。**
- FIR-18自身的注入点是第21笔（最新样本），此刻"窗口OR"与"当前样本诊断"不可区分；
  真正把饱和样本放在窗口中部的是FIR-32（TB:1017/1020/1023在index 4/5/6注入，
  第21笔时检查`o_window_saturation_low/high`双双为1），OR归约由它补齐。

"数值不丢弃"由记分板载荷比较覆盖（黄金模型照样把该样本移入历史）。

### FIR-23："每笔正式计算"只做了2次抽样量测，且量测本身有±1竞态

要求原文（`:629`）：「16周期上限 | **每笔**正式计算在输入握手后最多16周期产生valid」。
全TB只有两处做端到端延迟量测：TB:729（FIR-03）与TB:882（FIR-23），
都是`(cnt_clock_cycle - cnt_last_input_cycle) <= C_PROCESS_MAX_CYCLES`。
FIR-27那160笔随机事务、FIR-05那21笔冲激事务等**都没有量测延迟**。

另记一条工具级注意：`cnt_clock_cycle`在TB:245-247的`always@(posedge i_clk)`里用**阻塞
赋值**自增，`cnt_last_input_cycle = cnt_clock_cycle`在TB:317-318**另一个**`always@(posedge i_clk)`
里同样用阻塞赋值——两个always块在同一个posedge的执行顺序由仿真器决定，
**该差值存在±1的实现依赖**。因为实测余量足够（FIR-23路径约13拍 vs 上限16），
不影响当前结论，但记录下来。

### FIR-24：4个idle子条件只有1个被"反向"验证过

要求原文（`:630`）：「`o_fir_idle`定义 | MAC、在途计算、输出和当前输入沿任一未排空时idle必须为0」。
合同`:433-438`把`o_fir_idle`拆成4行：MAC状态空闲／不存在已接受未完成的计算事务／
`o_result_valid == 0`／当前沿没有输入握手。

RTL:323实现为三项与：`(state_current == ST_IDLE) && (result_valid_o == 1'b0) && (flag_input_transfer == 1'b0)`
（前两行合同子句由同一个`state_current`项覆盖）——**RTL与合同一致**。

TB侧：TB:883`check_condition(o_fir_idle == 1'b0, "FIR-24 pending output is not idle")`
执行在`wait_result_valid`之后，此刻`state_current`已回到`ST_IDLE`、
`flag_input_transfer`为0，**idle为0完全归因于`result_valid_o == 1`这一项**；
TB:886是全排空后的`o_fir_idle == 1'b1`。
也就是说"MAC在途时idle必须为0"和"当前输入沿时idle必须为0"两个子条件
**从未被单独激励验证**。（FIR-26在`result_valid`项上有额外的间接证据：
TB:932危险accept被忽略正是因为此刻idle=0。）

### FIR-28：4条断言完全不碰DUT，只对TB自己的常量数组做数学检查

要求原文（`:634`）：「频率响应 | Q15定点模型满足5、10、20和50 Hz冻结幅频门限」。

`check_frequency_response`（TB:623-639）用`$cos/$sin/$sqrt`对
**`model_impulse_expected[]`这个TB自己在TB:700-720写死的数组**做DFT，
再与门限比较。**整个计算过程没有读取任何DUT信号**。

这不等于没有价值，但证据链必须写明是两步的：
(1) FIR-05（TB:735-744，21条断言）独立证明**DUT实际系数逐个等于`model_impulse_expected[]`**；
(2) FIR-28证明该数组满足频响门限。两步合起来才构成对DUT的论断。
别名表把FIR-28的RTL锚点指到`:619`（`dec_mac_coefficient = 16'sd164`）是合理的，
但"条件"列写的`5, 0.9440, 1.0001`其实是`check_frequency_response`的实参而非断言条件
（见下一节"工具漏检风险"）。

另核对门限本身与合同`:180-185`：5 Hz合同"约-0.401 dB，不超过约0.5 dB"，TB用`[0.9440, 1.0001]`
（0.9440≈-0.5 dB）✔；10 Hz合同"约-1.618 dB"（≈0.8302），TB用`[0.8200, 0.8400]`✔；
20 Hz合同"衰减不低于约6.5 dB"（≈0.4732），TB上界用**0.4740**（≈6.485 dB）——
比合同字面略松0.015 dB；50 Hz合同"约-51.8 dB"（≈0.00257），TB上界用**0.0030**（≈-50.5 dB）——
比合同字面松约1.3 dB。合同两处都写了"约"，判定不构成缺口，但门限确实是**放松侧**的。
另外采样率核对：TB:632用`/400.0`，合同`:15`/`:107`"每个颜色400 Hz有效采样率"——**一致，
不是常见的"双色交错误当200 Hz"陷阱**。

## FIR-31/32/33（本日新建）专项复核结论

任务特别要求对这三条新建ID做同等强度的独立复核、并确认写法是否与历史那批一致。逐条结论：

**FIR-31（TB:983-996）——CONFIRMED，且是全家族最强的一条断言。**
合同`:637`要求`i_result_valid=1`且`i_sample_valid=0`的**合法NORMAL**事务只消费一次，
且两色历史/计数/history_full/MAC/输出valid/全部检测状态保持。
断言条件包含11个并列项，逐项核实全部非平凡：

- `(cnt_input_transfer - cnt_input_snapshot) == 2`——真实握手计数（TB:250-254独立always块），
  这是"只消费一次"唯一被真正计数验证的地方。**反向确认**：若DUT在`i_sample_valid=0`时
  不给ready，`send_sample`的`while(o_result_ready !== 1'b1)`会死循环到watchdog超时，
  所以"==2"同时证明了"确实握手了"和"没有多握手"。
- `dut.reg_red_history === reg_red_history_snapshot`（2331-bit全历史逐位）——
  非平凡：此刻红光已有20笔真实样本，不是全0也不是全X。
- `dut.cnt_red_sample == 5'd20 && dut.cnt_ir_sample == 5'd20`——精确计数，
  若invalid事务被计入会变21。
- 隔离性核实（confound排查重点）：`load_sample_fields`（TB:457）对这两笔invalid事务
  照样设`i_coarse_valid=1'b1`、调用者传`sample_calibrated=1'b1`、
  `sample_frame_type=2'b10`、两个饱和注入都是0。**唯一被置0的变量就是`i_sample_valid`**，
  没有任何第二个变量"顺便"也让事务变得不合法。这正是合同`:99`要的那个正交语义。

**FIR-32（TB:998-1035）——CONFIRMED。**
合同`:638`（与`:101`同源）列举的"RAW零/低/高值、钳位、Stage1/DC饱和、`i_coarse_recovery_calibrated=0`"
全部被7个case分支逐一覆盖（index 0=0值、1=`24'sh800000`、2=`24'sh7fffff`、3=未校准、
4=负饱和、5=正饱和、6=未校准+双向饱和），每笔都查
`dut.cnt_red_sample == cnt_red_snapshot + 1`（真实计数推进）
和`dut.reg_red_history[23:0] == i_coarse_ppg_value`（真值真的进了tap0）。
**注意**：`case 0`那一笔值恰为`24'sd0`、且`apply_reset`刚把历史清零，
所以那一次的`reg_red_history[23:0] == 0`是退化比较；但计数项非退化，
且index 1~20全部是非零值，整条ID不受影响。
`cnt_red_sample`在RTL:697饱和于21，index 20时`20→21`仍在有效区间，无边界问题。
末尾的`cnt_error == cnt_error_snapshot`把记分板载荷比较也纳入了本用例的判定。

**FIR-33（TB:1037-1063）——CONFIRMED，设计得很巧，独立复算通过。**
合同`:639`三个子句都有对应的真实检查：
(1)"不占历史位置"：`dut.cnt_red_sample == 5'd10`（3笔invalid插入后仍是10）；
(2)"达到21笔合法历史前不产生新的合格检测事件"：
`(o_history_full_r==0) && (o_result_valid==0) && (cnt_output_transfer == cnt_output_snapshot)`；
(3)"不插0、不复制"+"身份序号保持原始间隙"：`o_filtered_ppg_value == 24'sd1160`
和`(reg_legal_eleventh_index - reg_legal_tenth_index) == 16'd4`。
**独立复算**：合法斜坡`1000 + 16k`（k=0..20），对称单位增益FIR对线性斜坡的输出等于
中心样本值＝第11笔＝`1000 + 10*16 = 1160`✔；若3笔invalid被插0或被复制，
该等式立刻破。身份间隙4＝3笔invalid各消耗1个`cnt_stimulus`加本笔1个✔
（`i_sample_index = cnt_stimulus[15:0] + 16'h1000`，TB:468）。
另确认`reg_legal_tenth_index`（TB:1044）取值时刻在第一批循环结束后、invalid发送前，
`i_sample_index`仍保持第10笔的值，无串扰。

**写法一致性（任务专门问的点）**：FIR-31/32/33 **全部使用`check_condition(<条件>, "FIR-3X …")`，
ID在第二个参数，与历史FIR-01~30完全一致**，不存在因写法不同被漏检的风险。
真正有漏检风险的反而是**历史那批里的FIR-28**，见下节。

## 别名表/复核工具的系统性风险（照实记录）

不是"整体不可信"——锚点和PASS行号都准（见开头）。但"条件"列有两类系统性失真：

1. **FIR-28的4条断言根本不经过`check_condition`**。它们经`check_frequency_response(频率, 下限, 上限, 用例名)`
   （TB:954-957），**ID字符串在第4个参数**，真正的`check_condition`在任务体TB:637里以
   透传变量`case_name`调用。任何"扫`check_condition(…, "FIR-..")`、ID取第二参数"的正则
   **会漏掉全部4个FIR-28调用点**。别名表FIR-28那一行"条件"列实际印出来的是
   `5, 0.9440, 1.0001`——这正是提取脚本在这一行翻车的直接痕迹。
   （与memory里PWC-40"脚本取第一个状态词"的已知局限同类。）
2. **"条件"列对真实证据系统性低估**。本家族大量ID的真实证据在TB:264-442那个
   记分板`always`块里（逐笔构造21抽头黄金期望、在每次输出握手时逐位比较113-bit载荷，
   不符即`cnt_error++`且最终判定要求`cnt_error==0`）。FIR-08/09/10/16/17/18/27/32/33
   这些条目，光看别名表印出来的条件表达式会显著低估覆盖强度；
   而FIR-32/33印出来的`flag_case_ok && (cnt_error == cnt_error_snapshot)`
   更是完全看不出测了什么——真正的比较在TB:1029/1032和TB:1050/1057/1060，
   在`check_condition`调用点之外累积。
3. **反向的一类也存在**：FIR-10/FIR-21印出来的条件"看着很实"，实际一个被confound、
   一个是TB自比恒真。所以"条件列非空"既不能当作覆盖充分的证据，也不能当作覆盖不足的证据，
   必须读整段。

另记一条与FIR-01~33编号无关、但本次顺带查到的负向测试空白：合同`:85-93`规定进入历史
需同时满足5个条件（`i_result_valid`/`i_coarse_valid`/`i_sample_valid`/`i_frame_type==NORMAL`/颜色）。
其中`i_frame_type≠NORMAL`由FIR-19测、`i_sample_valid=0`由FIR-31测，
但**`i_coarse_valid=0`在整份TB里从未被驱动过**（`load_sample_fields` TB:457恒置1）。
验收表没有为它单列ID，所以不计入本次33条的缺口，仅作观察项记录。

## 完整复核表（33/33全部深度）

| ID | 场景（TB行）与实际证据来源 | 结论 |
| --- | --- | --- |
| FIR-01 | :722-723 复位后4项检查 | **真实缺口**（见上） |
| FIR-02 | :725-726 20笔预热后`valid=0 && full_r=0`；"不产生输出"另由记分板TB:303-310兜底（`i_result_ready`恒1，任何伪输出都会撞空队列判FAIL）；"计数递增"由FIR-03反证 | CONFIRMED |
| FIR-03 | :727-729 第21笔`valid=1 && full_r=1 && 延迟<=16`；"窗口只含21笔真实样本"由记分板中心元数据比较+RTL生成块0..19结构确认 | CONFIRMED |
| FIR-04 | :730 `o_filtered_ppg_value == 24'sd12345`；独立复算系数和=32768=2^15 | CONFIRMED |
| FIR-05 | :735-744 21次循环逐个抽头比对冻结系数（21条PASS） | CONFIRMED（"并正确舍入"半句在本场景无余数，实由FIR-06兑现） |
| FIR-06 | :746-759 正负两侧精确构造总和±16384，输出±1 | CONFIRMED（tie远离零双向都测） |
| FIR-07 | :761-770 双端点无回绕+饱和标志为0 | **部分覆盖**（显式饱和路径结构性不可达，见上） |
| FIR-08 | :772-784 两色交错21+21笔；真实证据是记分板对两套独立黄金历史的逐笔113-bit比较，不只是那3个标志位 | CONFIRMED |
| FIR-09 | :785-786 `o_frame_id/o_sample_index`对`model_ir_meta[10]`；独立核对84-bit打包位域`[40:25]=frame_id`、`[56:41]=sample_index`正确，移位后tap10即本笔中心 | CONFIRMED |
| FIR-10 | :787 `o_precision_mode == 1'b1` | **部分覆盖**（命名断言被confound，合同要求由记分板兑现，见上） |
| FIR-11 | :790-792 15→9切换后3笔仍`full_r=1`（若清空则3笔不可能恢复满窗） | CONFIRMED |
| FIR-12 | :794-795 8拍空转 | **真实缺口**（零激励恒真，见上） |
| FIR-13 | :797-799 idle后accept，两色`full`同时归0且`valid=0`（前一拍FIR-12刚断言过两者为1） | CONFIRMED |
| FIR-14 | :800-805 busy期间连查6拍`ready=0 && valid=0` | **部分覆盖**（"三帧"实测6拍，见上） |
| FIR-15 | :807-811 红光重新预热20笔不满窗、第21笔恢复且值=4000 | **部分覆盖**（红外半句零覆盖，见上） |
| FIR-16 | :814-819 4笔DC版本逐笔变化仍`full_r=1`且每笔都有输出；元数据正确性由记分板比较 | CONFIRMED |
| FIR-17 | :821-825 第21笔未校准→`valid=1 && qualified=0`；"数值移位"由记分板载荷比较 | CONFIRMED |
| FIR-18 | :827-831 第21笔注入负饱和→`window_sat_low=1 && qualified=0` | **部分覆盖**（4个饱和输入只驱动2个；窗口OR由FIR-32补，见上） |
| FIR-19 | :834-837 非NORMAL不进历史 | **真实缺口**（"TB报告协议错误"未实现，见上） |
| FIR-20 | :842-850 反压5拍逐拍比较完整113-bit`dec_observed_payload === reg_held_payload` | CONFIRMED |
| FIR-21 | :852-869 | **真实缺口**（载荷保持恒真+只消费一次近乎恒真，见上） |
| FIR-22 | :871-880 11次`state==MAC && cnt_mac_index==k`逐项+第12次进COMMIT；"单乘法器"由RTL:384唯一信号乘法结构确认 | CONFIRMED |
| FIR-23 | :882 端到端延迟`<=16` | **部分覆盖**（仅2处抽样量测且有±1竞态，见上） |
| FIR-24 | :883/:886 输出未排空时`idle=0`、全排空后`idle=1` | **部分覆盖**（4个子条件只反向验了1个，见上） |
| FIR-25 | :888-923 START(3拍)/STOP(5拍)/abort(7拍)三个MAC阶段各查"无迟到输出且历史清空"+陈旧代际反例（:909-923，`8'h3B`≠`8'h3C`，验证MAC未被误撤且输出=8250） | CONFIRMED（含真实负向用例，质量高） |
| FIR-26 | :926-942 危险accept被忽略（载荷逐位保持）+idle后安全accept清两色 | CONFIRMED（两半句都有） |
| FIR-27 | :944-952 160笔双色随机+`cnt_queue_used==0 && cnt_error==0`；64-bit黄金模型逐笔113-bit比较，队列清空证明无漏输出 | CONFIRMED |
| FIR-28 | :954-957（经`check_frequency_response`，:623-639） | **部分覆盖**（断言不碰DUT，靠FIR-05链接；20/50 Hz门限略松，见上） |
| FIR-29 | :959-971 10笔精度切换后中心仍为旧值0、第11笔翻1且历史不清（旧0/新1可区分，无confound） | CONFIRMED |
| FIR-30 | :974-981 `force dut.cnt_mac_index`卡住18拍触发16周期保护；查`valid=0 && state==IDLE && full_r=1`；"不新增sticky端口"由端口清单结构确认 | CONFIRMED |
| FIR-31 | :983-996 11项并列（握手计数==2、两色全历史逐位===、两色计数==20、双`full`=0、state=IDLE、valid=0、idle=1） | CONFIRMED（全家族最强） |
| FIR-32 | :998-1035 7类资格组合逐笔查计数推进+tap0真值，末尾查窗口诊断与记分板零新增错误 | CONFIRMED |
| FIR-33 | :1037-1063 invalid间隙前后计数10/20、无提前输出、中心值1160、身份间隙4 | CONFIRMED |

## 汇总

- **21项CONFIRMED**：FIR-02/03/04/05/06/08/09/11/13/16/17/20/22/25/26/27/29/30/31/32/33。
  全部有真实、具体、信号级的断言证据（含记分板逐笔113-bit载荷比较这一真实证据来源）。
- **4项真实缺口**：FIR-01（"撤销MAC"零激励、载荷/诊断复位值零检查、计数只验`<21`）、
  FIR-12（8拍空转恒真断言，端口边界上无`pending`输入，可驱动的投影`i_recheck_busy`
  从未在历史非空时测过）、FIR-19（合同明文"自检TB必须报告该错误"未实现）、
  FIR-21（"输入载荷保持"是TB自比恒真式，"恢复后只消费一次"是近乎恒真的析取且从不计数，
  记分板结构上也抓不到重复消费）。
- **8项部分覆盖**：FIR-07（饱和路径结构性不可达）、FIR-10（命名断言被confound）、
  FIR-14（三帧→6拍）、FIR-15（两色→只测红光）、FIR-18（4个饱和输入只驱动2个）、
  FIR-23（每笔→2次抽样，且量测有±1竞态）、FIR-24（4个idle子条件反向只验1个）、
  FIR-28（断言不碰DUT）。
- **零RTL功能性缺陷**。本次反查了RTL的全部14个复位分支、`flag_fir_idle`三项与、
  `flag_history_transfer`四项门控、两色计数/历史的对称结构、单乘法器结构、
  21抽头窗口生成块边界、舍入与饱和数值路径——**均与合同一致**，4个真实缺口全部是
  验证证据层面的，不是RTL行为层面的。是否补测试是后续产品决定，本次只调查不修改
  （[[project-ppg-fix-dont-defer]]：调查不留，修不修可以留）。
- **别名表本身**：33条RTL锚点行号、33条回归PASS行号**全部准确**，
  未出现B_TAG_MISSING那几个家族的"共享锚点连错"模式；
  问题集中在"条件"列——对记分板类证据系统性低估（FIR-08/10/16/17/18/27/32/33），
  对FIR-10/21两条系统性高估，且对FIR-28整行提取失败（印出来的是
  `check_frequency_response`的实参而非断言条件）。
- **FIR-31/32/33写法与历史批次完全一致**（`check_condition`、ID在第二参数），
  无漏检风险；真正的写法异类是历史批次里的**FIR-28**（`check_frequency_response`、
  ID在第四参数），任何按第二参数取ID的正则都会漏掉它那4个调用点。
- **一项编号外观察**：合同`:85-93`五项入历史门控中的`i_coarse_valid=0`
  在整份TB里从未被驱动过（`load_sample_fields` TB:457恒置1）；验收表未为其单列ID，
  故不计入本次33条统计，仅记录。

> 证据新鲜度：本次引用的xsim证据来自2026-09-16 10:05的`module_tb_regression`真实重跑
> （`xsim.log`共118行，`pass=98`，`$finish`于TB:1071），与`C_EXPECTED_PASS_COUNT=98`
> 及本次手工清点的98次`check_condition`执行数三方吻合。
