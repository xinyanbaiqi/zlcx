# RC1前修复与补测试轮任务书（FIX_ROUND_RC1_BRIEF）

> 统筹会话撰写，2026-10-09，10-10更新。
> 基线：**ADC完成信号轮（`verification_reports/ADC_HELD_DONE_ROUND_BRIEF_20261010.md`）合入main之后的提交**，统筹届时补写哈希。**在ADC完成信号轮合入main、并经统筹核对通过之前，不要开工。**
> 执行者：本机新开的会话（有Vivado 2022.2）。本文件自包含。
> 来源：流片前验证收尾P0的同拍冲突矩阵（V1）。云端在分支`p0-closure`、另一个AI在分支`v1-independent`各自独立完成，统筹逐条核实，用户于2026-10-09裁定。

---

## 0. 先读这一节

### 0.1 任务
本轮合并了原计划中RC1之前的全部工作，只跑一次全套回归：
- **A. RTL修复11项**（§1.1~§1.9，以及§1.12、§1.13），同步修改相应合同；
- **B. 只写合同20项**（§2）；
- **C. 补测试**（§1.10）：FSC-19/23/24/27/44、SSW-18 sticky置1、SUP-08中cause 01与03的重启；
- **D. 孤立模块整理**（§1.11）。

每项修复和新检查都配负对照。建议顺序为A→B→C→D，最后统一做全套回归，并与基线逐TB比对。完成后由统筹核对，决定是否打候选标签RC1。

### 0.2 必须遵守
- **工作目录**：本机还有其它目录在用：`D:\PPG\verilog\ppg_github_release`（分支`v2-sweep-framework`）、`D:\PPG\verilog\ppg_coord_wt`（统筹）、`D:\PPG\verilog\ppg_helddone_wt`（ADC完成信号轮）。你必须用`git worktree add D:/PPG/verilog/ppg_fixround_wt -b fix-round-rc1 origin/main`建自己的工作目录，只在其中做git写操作。不要在其它目录里checkout、commit或merge。
- **本机`python`命令已失效**（会以退出码49失败）。请用`py -3`；运行`tools/b_merge_tools/run_anchor_gate.sh`或`tools/run_unit_tb_regression.sh`时先设`PYTHON=py`。
- **CPU**：开始跑全套回归前告诉用户，由用户通知V2会话暂停批量仿真。
- 按根目录`CLAUDE.md`使用`.claude/skills/erie-verilog-generator`：改动的RTL文件要跑deliverable gate，问题集不得新增。
- 所有RTL修改先在仓库外的导出副本中进行（`git -c core.autocrlf=false archive`导出），验证通过后再提交。
- 修复点在已有实质性中文注释末尾追加`@satisfies`标签（不单独成行），新检查用TB本地名，并写明服务于哪个发现编号。芯片顶层的新检查同样用本地名：用户10-10已决定建立CHIP-xx验收ID族，由V8统一定义并映射，本轮不要自行编CHIP号。
- 合同改写必须使用符号锚点（文件 + 符号 + 合同节号）。B合并批次后，`tools/run_unit_tb_regression.sh`的开头会先跑`tools/b_merge_tools/run_anchor_gate.sh`，锚点检查不通过整轮报错。改合同后先单独跑`tools/b_merge_tools/anchor_check.py`。若合同改动影响矩阵§12.4a摘要，用`tools/b_merge_tools/manifest_digest.py --write`重算。
- 每个修复先写检查，确认检查在**旧RTL上FAIL、新RTL上PASS**（负对照），再提交。
- 下任何"不会卡死、可以恢复"的结论前，把相关lane和状态位的置位、清零条件逐路追完，并实测。
- 发现本任务书未覆盖、且需要裁定的取舍时，停下报告，不要自行决定。

### 0.3 参考材料
- V1同拍冲突矩阵，用`git show`阅读：分支`p0-closure`的`verification_reports/p0_closure/V1_CONFLICT_*.md`（云端，12个模块），分支`v1-independent`的`verification_reports/v1_independent/V1B_CONFLICT_*.md`（独立复审）。其中的RTL行号以`a1ba482`为准；B批次和ADC完成信号轮之后行号已漂移，请按符号定位。
- V18 SSW逐拍黄金比对：分支`v18-ssw-golden`的`verification_reports/V18_SSW_GOLDEN_TRIAL_20261010.md`、`V18_SSW_EXPECTED_RULES.md`，以及`verification/v18_ssw_golden/`下的脚本（§1.13要用）。
- V2/V7框架：分支`v2-sweep-framework`的`verification_reports/V2_V7_FRAMEWORK_TRIAL_20261010.md`。
- `verification_reports/B_MERGE_BATCH_BRIEF_20261009.md` §3：用户已定事项。
- 合同C编号对照：`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md` §2。

## 1. RTL修复（共11项：§1.1~§1.9、§1.12、§1.13）与补测试、孤立模块整理

### 1.1 SSW-C1（高）双光SAR9下，IR段覆盖了RED段的三个使能
- **问题**：`ppg_sar9_sar15_safe_selection_wrapper.v`的组合控制字块中，IR段的SAR9分支对`CTRL_EN_9_IREF`、`CTRL_EN_9_AMB`、`CTRL_EN_9_DC`直接赋值（`a1ba482`第707~710行），覆盖了RED段的结果。双光SAR9下，RED窗口（IREF [236,308)、AMB/DC [256,310)）内这三个使能恒为0。SAR15分支已经用OR合并，SAR9只是漏了。
- **用户（模拟设计者）确认**：这三个使能在RED窗口内必须为1，与SAR15的基本工作状态相同。
- **修法**：这三行改为与`reg_control_next`中已有的值做OR，写法与SAR15 IR分支一致。RED [236,310)与IR [396,470)不重叠。
- **检查**：
  - SSW单元TB：双光SAR9，RED在tick 0、IR在tick 160接管，逐tick核对236~309和396~469两段内三个使能的值；以单光RED作对照；
  - 系统级或芯片级：在双光SAR9下至少抽查RED窗口内的三个引脚。
- **合同**：C09 §4.6已规定"各自独立颜色窗口"，不改合同；在报告中登记为"RTL修正到合同"。

### 1.2 SCH-C1（中）子帧末拍或帧末同拍握手时，新请求的类型和颜色没有装入
- **问题**：调度器在子帧末拍（local 624，含帧末4999的滚动路径）同拍接受新的校准请求时，P6把新请求写入`state_next`的REQ字段并置`REQ_PENDING`；但子帧末处理（`a1ba482`第820~836行）和滚动覆盖层（第892~897行）只在`state_current[B_CAL_REQ_PENDING]`为1时复制REQ→CAL_FRAME字段。结果是下一子帧沿用旧的类型和颜色出波形，新请求被消费掉，阶段切换时AMI报错配并阻断。滚动资格（第487~492行）却已经计入了同拍请求，前后口径不一致。
- **修法**：子帧末与滚动两条路径都改为按"本拍处理后"的请求状态装载，包括同拍握手的新请求。写法与F-009末拍起帧路径（覆盖层中读`state_next`）一致，并注意不要形成组合环。
- **检查**：单元TB分别在local 623、624、下一子帧local 0，以及帧末4999，用与当前帧不同的类型或颜色握手，检查下一波形的`o_waveform_frame_type/color`等于新请求，且一笔请求只被转换一次。
- **合同**：C08 §9（校准事务）或§15补一句同拍握手的装载规则。

### 1.3 AMI-C1（中）RED截止后换IR候选，valid不间断，被误判为载荷变化
- **问题**：AMI在整个RED窗口都不ready时（周期重检期间夹在校准帧之间的NORMAL帧，或精度切换挂起），调度器的`transaction_start_valid_o`从RED候选（截止283）直接切到IR候选（284），valid中间不落。AMI的`flag_start_payload_changed`判为"反压期间载荷变化"，置`integration_protocol_error_sticky`（非阻断，但对外可见）。正常运行中每个这样的帧误报一次。
- **合同依据**：C08 §10.2"保持到真实握手或本事务owner截止点到达"；C10 §7.4、§15.1"valid保持期间载荷变化置sticky"。两者各自成立，缺的是两笔事务之间的间隙。
- **修法（用户已定在调度器侧）**：当前持有的候选因截止而结束、且下一拍要提出另一候选时，`transaction_start_valid_o`至少落一拍。正常帧中RED在tick 1就握手，不受影响。CAL截止（local 248）后的换候选也按同一规则处理。
- **检查**：
  - 调度器单元TB：AMI不ready跨越整个RED窗口，检查284拍valid=0、285拍起才提出IR；
  - 系统级：`tb_ppg_control_top_periodic_recheck_recovery`在重检期间NORMAL帧的tick 285之后，`o_ami_integration_protocol_error_sticky`保持0。
- **合同**：C08 §10.2补"截止后换候选时valid至少撤销一拍"。

### 1.4 MGR-C1（中）STOPPING排空完成与重复STOP同拍时，`stop_episode_active`卡在1
- **问题**：`ppg_system_config_manager.v`中，`stop_episode_active_o`的置位条件`flag_stop_accept`（STOPPING中的重复STOP也接受）优先于"STOPPING且排空完成"的清零。两者同拍时，状态回到CONFIG，episode位却保持1，直到下一次RUN排空。supervisor的ADC看门狗因此在下一次RUN中处于打开状态；ADC异常连续忙满5000拍时会误报0x31，顶掉首故障07。
- **修法**：状态离开STOPPING的那一拍必须清零episode。重复STOP只在状态仍停留于RUN或STOPPING时保持置位。
- **检查**：manager单元TB在排空完成的那一拍注入重复STOP，检查回到CONFIG后episode=0；再检查下一次RUN中ADC长时间忙不触发0x31（可在control_top层做）。
- **合同**：C02写明episode在离开STOPPING时清零，C24 §6的看门狗前提保持不变。

### 1.5 诊断清除统一规则（AMI-C2、IDAC-C2、PWC-C1）
- **统一规则**：①同拍出现的新事件（置位）优先于诊断清除；②存在活动故障或阻断时，清除不得解除对应的sticky。这与全项目"新故障优先"一致，lost sticky已经这样做了。
- **AMI**：`integration_protocol_error_sticky_o`（`a1ba482`约第1236~1241行）目前诊断清除优先，新错误同拍时不留痕迹。改为新错误优先，门控条件（无阻断或RUN已结束且排空）保持不变。
- **IDAC控制器**：协议sticky被诊断清除无条件清除，C17要求先等故障解除。按统一规则改。
- **精度窗口控制器**：两个sticky都是诊断清除优先，而且清除不看活动故障。其中`switch_timeout_sticky`参与AMI阻断（`flag_precision_fault_blocking`），RUN中一次诊断清除就会提前解除这一路阻断。按统一规则改；要特别验证：故障活动期间清除无效，阻断不被提前解除。
- **检查**：三个模块各自的单元TB中，新事件与清除同拍，以及故障活动时清除，都要有检查和负对照。
- **合同**：C10 §15.1、C17、C23相应节写明统一规则。

### 1.6 命令字节在SPI侧仲裁（用户已定方案一改进版）
- **问题**：芯片合同§9第11项允许0x0090一次写入多个命令位，并规定SPI不加优先级，"消歧完全依赖control_top"。但实际上：
  - 各命令位走各自独立的同步器进入2 MHz域，同一字节的各位可能相差±1拍到达，取决于亚稳态如何收敛，结果不确定；
  - control_top中START直连，STOP和诊断清除晚1拍，abort派生的STOP晚2拍。
  因此C01"STOP优先于同拍START、清除"实际不会发生。牵涉发现：SCH-C3、IDAC-C1、MGR-C2、MGR-C3、TOP-C1、TOP-C2。
- **修法**：在`ppg_spi_register_file.v`中，命令进入跨时钟域同步之前统一判定：
  - 含ABORT或STOP：只放行停机命令，ABORT优先于STOP，其余位丢弃；
  - 不含停机命令、但同时置了多个命令位（START、COMMIT、DIAG_CLEAR之间任意组合）：整条拒绝，一个也不执行；
  - 以上两种情况都置一个"命令冲突"sticky，主机可读。建议用0x0108 bit7（目前保留）。实现时注意它所在的时钟域和清除方式（诊断清除），以及与0x0108现有快照机制的关系；有疑问就停下报告。
  - bit5（表征更新）是否参与互斥，请先核对它与生命周期命令的关系，报告结论后再实现。
  - 合法的单命令写入，行为必须完全不变。
- **检查**：芯片TB覆盖0x03、0x09、0x0A、0x11、0x12、0x05等组合，以及各单命令；原`check_cmd_stop_priority`中0x03、0x0A的期望改为"只执行STOP、置冲突位"；负对照。
- **合同**：芯片顶层合同§9第11项改写、SPI地图0x0108 bit7；C01中"STOP优先于同拍START/clear"一句补充说明来源；在B批次建立的软件编程相关说明处写明"一次写一个命令"。

### 1.7 STOP、abort、故障之后不再发出NORMAL完成（SCH-C7、FSC-01）
- **问题**：C08 §16.3原文"不产生新的正式NORMAL完成事件"。但帧末处理（`a1ba482`第839~842行一带）只看`state_current`中的帧活动位与DONE位，不检查生命周期。STOP后空帧走到4999，以及abort或阻断故障落在末拍时，仍会发出`o_normal_frame_complete_event`。
- **影响**：唯一消费方是重检调度器的帧计数器（经AMI、PWI转发），受`run_enable`门控且新RUN清零，实际影响为零。这一项按合同原文改正RTL。
- **修法**：NORMAL完成的置位加生命周期门控（STOP确认或排空中、abort、阻断故障时不置位）。不要影响F-009的末拍起帧路径和CAL完成事件。
- **检查**：单元TB中，帧内两色已完成后STOP，检查4999不发NORMAL完成；abort与4999同拍时同样不发；负对照。
- **合同**：无需改（RTL改到符合§16.3）。

### 1.8 测量结果丢弃原因的优先级（V1-AMI-03）
- **问题**：AMI的`flag_measurement_result_discard_reason`（`a1ba482`第1001行）只看已锁存的`flag_system_fault_discard_pending`，没有算入本拍的`i_system_fault_discard_event`；检测分支的`flag_terminal_discard_reason`（第1021行）已经算入。主机abort与supervisor打开episode恰好同拍时，测量结果原因标成ABORT，检测分支标SYSTEM_FAULT，违反C10 §6.11"SYSTEM_FAULT（含本拍事件）> ABORT > STOP"。正常故障流程不受影响：supervisor的abort经control_top寄存晚1拍到达。
- **修法**：测量原因的系统故障条件加入`i_system_fault_discard_event`。
- **检查**：AMI单元TB让系统故障discard事件与abort同拍，且有在途测量结果，检查原因=SYSTEM_FAULT；负对照。
- **合同**：无需改。

### 1.9 精度窗口控制器在丢弃那一拍的处理（PWC-01、PWC-02的重获取部分）
- **合同依据**：C23 §18.1a规定，`i_detection_discard_event`命中当前代际时，"在该采样沿恰好一次清除该代际的全部相交请求、返回请求、切换pending、窗口计数和任何待发布控制事件"，并且"不得产生精度切换、重获取请求或诊断完成事件"。
- **问题(a)**：`flag_pending_cross`、`flag_pending_return`（`a1ba482`约第826~846行）是"新请求置位"优先于"取消清零"。丢弃与相交或返回请求传输同拍时，状态机和快照都被清除，这两个标志却置为1，而且没有START清零分支。后果只在诊断层面：`o_local_empty`等于`controller_idle_o`，不看这两个标志；它们只决定之后故障记录取哪一组快照（第439、454、469行）。
- **修法(a)**：两个标志改为取消清零优先于置位，与状态机和快照寄存器的取消优先一致。
- **问题(b)**：`reacquire_request_event_o`（约第400~406行）只要`state_current == ST_REACQUIRE`就置位，不看同拍丢弃。
- **修法(b)**：加门控，丢弃那一拍不发出重获取请求。
- **不修**：切换超时与丢弃同拍时，`mode_fault_event`照常发出。合同禁止项没有列故障事件，超时是真实发生的异常，保留记录（与AMI-C3一致）。在C23写明"丢弃沿上的真实故障仍记录"。
- **检查**：PWC单元TB中，丢弃分别与相交传输、返回传输同拍，检查之后两个pending标志为0；丢弃与REACQUIRE同拍，检查不发出重获取请求；两项都做负对照。
- 本项与1.5中的PWC诊断清除修改在同一文件，一并提交。

### 1.12 owner截止晚于前端控制（KNOWN-OWNER-DEADLINE，用户10-10选方案A）
- **问题**：
  - SSW中受owner控制的采样相关前端控制（`CTRL_EN_TIA`、`CTRL_AFERST`、`CTRL_TIAEN`）在SAR15下从RED第266拍、IR第426拍开始；
  - NORMAL owner截止却是283/443（调度器与SSW的参数`C_NORMAL_RED_OWNER_DEADLINE`、`C_NORMAL_IR_OWNER_DEADLINE`）；
  - owner在266~283（或426~443）之间提交时，这些窗口从提交那一拍才开始，被截短。
- **用户（模拟设计者）10-10确认**：
  - 模拟端**不能接受**被截短的窗口；
  - owner错过截止时，TIA、AFERST、TIAEN与Q1/Q2/Q3、LEDEN、LEDDAC一样，整槽不出现。
- **修法（方案A）**：两种精度统一提前NORMAL owner截止，RED改为第265拍，IR改为第425拍。
  - 调度器和SSW的上述参数默认值同步修改，并核对所有依赖截止点的逻辑，包括RED截止后切换到IR候选（与§1.3 AMI-C1在同一处，两项一起改，一起验证）。
  - SAR9下最早受owner控制的边沿在283/443，校准在local 249（截止为local 248），都不受影响。
  - **截止当拍的语义**：V18（F07）发现SAR9下owner恰在截止拍283握手时，前端三个窗口少了首拍。必须统一写明并实现："截止拍当拍允许握手；受owner控制的边沿最早从截止拍的下一拍开始"。新截止265/425时，SAR15前端在266/426、SAR9在283/443，都满足这一要求。
- **合同**：
  - C08截止表与推导，原文"RED Q3 − 17"等；
  - C09 §4.5：把截止的依据改为"最早受owner控制的采样相关控制边沿之前一拍"；逐端口写明owner错过截止时被抑制的全部输出（Q1/Q2/Q3、LEDEN、LEDDAC、EN_TIA、AFERST、TIAEN）；写明"受owner控制的窗口要么完整出现、要么整槽不出现，不得截短"；
  - C01和矩阵中参数默认值相关的条目。
- **检查**：
  - SSW单元TB：两种精度下owner分别在264、265、266、283拍提交（RED，IR各加160），逐拍核对三个前端控制与Q1/Q2/Q3、LED。265拍及以前提交的窗口完整；266拍及以后提交的应判为错过截止、整槽不出现；
  - 系统级至少抽查一次；
  - 负对照：旧RTL在266拍提交时出现截短窗口；
  - 现有引用283/443的测试同步更新，并在报告中逐项说明期望值变化的依据。
- **断言**（交V7）："每个受owner控制的窗口要么完整、要么不出现"，写入可复用断言文件。

### 1.13 SSW输出与模拟侧已验证时序模块不一致（V18发现，用户10-10定）
- **背景**：
  - V18（分支`v18-ssw-golden`，`verification_reports/V18_SSW_GOLDEN_TRIAL_20261010.md`）只依据C09和时序模块`ppg_timing_sar9.v`、`ppg_timing_sar15.v`（用户已在模拟电路中验证）建立逐拍期望，与SSW比对。
  - 用户10-10要求：**严格按时序模块**。
- **F03（功能性，最高优先）`o_en_15sar_low`没有整帧保持**：
  - 现状：SSW只在SAR15 Q1窗口内为1（`CTRL_EN_15`跟随`CTRL_Q1_15`），Q3之后的15位转换期间已回到0。
  - 用户确认：15位转换在此情况下不能正常完成，必须整帧保持。
  - 规则：跟随已提交精度，在第4760拍精度提交时切换，RUN中整帧保持（含两次波形之间）；DCS_CAL、AMB_CAL为0；回到CONFIG后为0；STATIC_BIAS为0（C09 §8.5）。
- **F02 NORMAL帧LEDEN早开1拍**：时序模块中LEDDAC比LEDEN早1拍。
  - SAR9：LEDDAC [298,301)、LEDEN [299,301)；
  - SAR15：LEDDAC [295,304)、LEDEN [296,304)；
  - IR各加160。
  - SSW现在让LEDEN与LEDDAC同时从298/295开始。改为与时序模块一致。
- **F05 DCS_CAL的LEDDAC晚开1拍**：SAR9单色模板平移到CAL后，LEDDAC为local [264,267)、LEDEN为[265,267)。SSW现在LEDDAC从265开始。改为与时序模块一致。
- **F04 `o_en_tia_low`**：用户10-10定为在所有有波形的工作状态下与`o_clk_tiaen_low`**完全相同**，包括NORMAL、CHARACTERIZATION、AMB_CAL、DCS_CAL，以及owner错过截止时一起抑制。
  - 现状：校准子帧（AMB与DCS）中`o_en_tia_low`全程为0，而`o_clk_tiaen_low`在local [249,269)为1。改为相同。
  - **例外STATIC_BIAS**：保持C09 §8.5的静态向量（`o_clk_tiaen_low=1`、`o_en_tia_low=0`），与时序模块的静态表征一致（统筹按此理解告知用户，用户未提出异议）。
  - 合同C09 §6.1中AMB_CAL `o_en_tia_low`"始终0（原始netlist静态dc=0）"一行改为local [249,269)，并注明依据为用户10-10确认。
- **合同**：
  - C09 §4.x、§7.7写明以上规则；
  - 写明"LEDDAC码窗与LEDEN窗口按时序模块分别定义，不得合并"。
- **检查**：
  - SSW单元TB逐拍核对以上窗口，用V18的黄金发生器或同等独立期望；
  - 负对照：旧RTL在F02/F03/F05各场景FAIL；
  - RC1后由统筹用V18脚本在2022.2上重跑全部148个场景，作为本项的最终证据。

### 1.10 补测试（只加TB检查，不改RTL）
这些合同条目目前缺少真正检查它们的TB（见`verification_reports/ID_GOVERNANCE_AUDIT_FOLLOWUP_20261005.md`及SSW18报告）。每条都要先在合同原文与RTL中确认含义，检查须真正比对，不能只打印PASS；能用合同编号的按编号治理规则（完全同义才用合同号），否则用TB本地名并登记别名表。

| 合同条目（C08，B之后原文） | 要做的检查 | 建议层级 |
|---|---|---|
| FSC-19 阶段超过8笔：同阶段延长到下一宏帧，不伪造完成；启动搜索期结果晚于子帧7 local 385时由空闲边界提交下一候选，不得死锁 | ①一个阶段需要超过8笔样本时延长到下一宏帧，期间不出现伪造的阶段完成；②启动搜索中，结果晚于子帧7 local 385时，经L-3空闲边界提交下一候选，搜索继续推进 | 调度器单元TB，加一个系统TB场景 |
| FSC-23 单光完成事件：唯一颜色完成后仅一拍 | 单光RED、单光IR模式下，该颜色完成后NORMAL完成事件恰好一拍 | 调度器单元TB |
| FSC-24 校准物理完成：宏帧结束事件与阶段成功严格区分 | 校准宏帧结束事件发出时，阶段未成功的情形不得被当作阶段成功；阶段跨帧延长时两者分别出现 | 调度器单元TB，可与F-9的语义一起验证 |
| FSC-27 16-bit回绕：两计数器自然回绕，无额外重复消费 | 在**单元级跑真实的16位回绕**（帧号、样本序号计数到0xFFFF再回到0），回绕前后没有重复消费或漏消费 | 调度器单元TB（不要用force预置计数器，从可控的初值实际计数过去；若必须缩短，写明理由） |
| FSC-44 迟到校准valid：local 0之后到达的请求不得在本子帧迟到启动，只能等下一子帧tick 0 | 在local 1、2、248等时刻拉高校准请求，检查本子帧不接管，下一子帧local 0才接管 | 调度器单元TB |
| SSW-18（按S1修复后的C09） | sticky条件为"本子帧校准owner在tick 385仍未完成"。先查SSW单元TB中生命周期轮加的S1相关检查（如S1-LATE、S1-ONTM）是否已经覆盖"置1"与"不误置"；已覆盖就登记别名表映射，未覆盖就补 | SSW单元TB |
| SUP-08中cause 01、03的重启 | B批次已证明cause 06、07和错配类02在STOPPING后不复位即可合法重启。补两类：①cause 01（测试身份注入，只在`C_ENABLE_TEST_INJECTION=1`的测试构建中存在）；②cause 03（错配完成）。用现有注入机制构造，从故障到STOPPING、排空、诊断清除、COMMIT、START全链检查。不得force共享线网，必须用专属注入端口；无法用现有机制构造时停下报告 | control_top层或AMI+supervisor层 |

### 1.11 孤立模块整理（用户10-09同意）
- **背景**：以下模块不在`ppg_chip_digital_top`的实例树中（矩阵已登记"7 orphaned RTL never instantiated"），是用户早期评估用的实验品，其中`ppg_timing_sar9/15`同时是C09指定的波形相对窗口真源（见下文"同步清理"最后一条）。现行设计中，SAR9/SAR15的时序控制由SSW生成：例如芯片引脚`CLK_9Q1_LOW`经control_top的`o_clk_9q1_low`，来自SSW的`reg_control_vector[CTRL_Q1_9]`。
- **归档**：用`git mv`移到`legacy/`下（直接移动，不留副本），并在`legacy/README.md`写明来历和"已被SSW取代"：
  - `rtl/ppg_dual_precision_top/`（含TB）；
  - `rtl/ppg_timing_sar9/`、`rtl/ppg_timing_sar15/`（含`*_3200hz.v`、TB、DC脚本、SDC）；
  - `rtl/ppg_timing_3200hz_validation/`；
  - `rtl/ppg_digital_shell/`（旧接口黑盒，端口与现行芯片顶层不符）。
- **保留**：`rtl/ppg_digital_esd_shell/`。它是芯片合同规定的对外引脚边界依据，端口名等于芯片顶层的46个端口加6个电源地脚。新增一个检查脚本放在`tools/`：校验esd_shell的端口名集合等于芯片顶层端口加上这6个电源地脚，方向一致；做负对照；接入回归门禁（与锚点门禁同处）。
- **同步清理**：
  - 从所有编译文件列表中删除这些文件：`rtl/ppg_control_top/rtl_filelist.f`、各`xsim_*_filelist.f`、`rtl/ppg_chip_digital_top/xsim_chip_digital_top_filelist.f`；`_tmp_v13_filelist.f`是遗留临时文件，一并归档。
  - 从`tools/run_unit_tb_regression.sh`中删除4个标为orphan的TB条目，模块级回归由28份变为24份，在报告中写明。
  - 更新`README.md`第56~66行一带关于timing DC脚本的说明。
  - 矩阵中约13处、别名表中约3处引用了这些路径：改为`legacy/`下的新路径，或按历史保留并登记进`anchor_history_allowlist.json`。锚点检查必须通过。
  - **C09 §2规定`ppg_timing_sar9.v`、`ppg_timing_sar15.v`的内部`cnt_frame`"仅保留为波形相对窗口真源"**。它们归档后仍是这一真源，V18的SSW黄金比对也以它们为窗口依据。所以：
    - C09 §2的这句话改为指向`legacy/`下的新路径，并注明"仅作波形相对窗口真源，不参与编译"；
    - `legacy/README.md`中写明这一点；
    - 不得删除这两个文件及其`*_3200hz.v`变体。
- **验证**：编译全部系统TB与芯片TB，证明删掉之后编译照常；回归中，除删掉的4个模块级TB外，其余结果不因本项改变。

## 2. 只写合同的20项（不改RTL；SSW-D1~D3若与RTL不符则转为RTL修复）
每项在对应合同节写明规则；有建议断言或扫描的，在报告中列出，交给后续V2/V7执行。细节见对应的V1报告。

| 编号 | 合同 | 要写明的规则 |
|---|---|---|
| SCH-C2 | C08 §10.1/§4.5 | 撤销（STOP、abort、run_enable撤销）与接管点或截止点同拍时，launch/owner截止sticky与CAL截止事件可能出现；STOP或abort之后的这类诊断不作为异常指示 |
| SCH-C4 | C08 §15 | 空拍起帧与校准握手同拍时，本帧按NORMAL起帧，校准顺延一帧（"校准优先"的已知例外） |
| SCH-C5 | C08 | 撤销与子帧末或帧末同拍时，pending可能残留到START；对外不可观测（建议护栏断言） |
| SCH-C6 | C08 §15.1或C24 | 多个协议条件同拍时，故障身份的取舍规则：按RTL实际顺序写明 |
| SCH-C8 | C08 §10.4 | 跨帧在途owner的成功完成计入当前帧的颜色完成位；影响限于重检计数（与F-7"失败归当前帧"并列） |
| SSW-C2 | C09 §7.8/§8.2/§8.3 | STOP或abort落在截止或local 385附近时，SSW的owner截止sticky与校准超时sticky可能置位；STOP/abort之后的这类诊断不作为异常指示 |
| SSW-C3 | C09 §7.9或C24 | 多源同拍时故障身份的选择规则：按RTL写明 |
| AMI-C3 | C10 §6.11 | abort与同拍新故障：hold被清，但故障记录照常分发，supervisor可能开一个立即关闭的episode（B批次已按RTL写了优先级，核对措辞） |
| AMI-C4 | C10 §6.11 | lane 02、03的身份在分发拍从当前在途owner取样；lane 03因错配完成同拍清掉在途标志，按构造不带身份 |
| AMI-C5 | C10 §6.11 | abort当拍测量结果的valid被组合屏蔽，不形成transfer，按ABORT原因丢弃；"transfer优先于同拍discard"只适用于valid为1的情形 |
| AMI-01 / SCH-P1 | C10 §13、C08 §16.3 | 完成与STOP同拍时按"完成先于STOP"计（success=1）；该结果随STOP私有flush清除，不形成正式结果（建议断言：STOP之后无正式结果valid） |
| PWC-C2 | C23 §18.1a | 切换超时与丢弃同拍时，hold被清，但真实的切换超时故障事件照常发出、照常记录（与AMI-C3同型）；重获取请求按1.9不发出 |
| IDAC-01 | C17 §10/§12；C02 | START与取消（abort/STOP）同拍时，IDAC两个always块的优先级相反。由1.6命令仲裁排除：外部abort只来自SPI，同一次写入不会同时放行START与ABORT；supervisor abort只在episode打开时发出，此时manager不接受START。写明"START与取消同拍不会发生"，不改RTL |
| SSW-D1（V18问题3，用户10-10定） | C09 §4.5 | owner未按时提交、本槽采样被抑制时，LEDEN不出现，LEDDAC码总线同样保持8'h00（与AMB_CAL、固定电流、STATIC_BIAS"不点亮LED则LEDDAC为0"的惯例一致）。若RTL不符，改为RTL修复项并报统筹 |
| SSW-D2（V18问题2，用户10-10定） | C09 §7.7 | **已转为RTL修复，见§1.13 F03**（V18已证实RTL不符）；合同按§1.13写明 |
| SSW-D3（V18问题4，10-10订正，用户10-10定） | C09 §8.2、§4.5 | 写明STOP落在波形已接管的槽时：①owner已在STOP之前提交：该槽完整运行，以便真实DONE以success=0释放owner，结果丢弃（V18 F06证实RTL如此）；②owner尚未提交：**按"owner错过截止"处理**——不受owner控制的预建立（IDAC与参考：`o_clk_iref_idac_sar9/15_low`、`o_en_sar9/15_iref`、AMB/DC使能、四组IDAC码总线、`o_clk_iref_idac_low`）照常运行到既定末沿，受owner控制的采样相关输出（Q1/Q2/Q3、LEDEN、LEDDAC、EN_TIA、AFERST、TIAEN）整槽不出现；STOPPING等待模拟安全，最多约0.24 ms。V18补充的7个场景证实RTL如此，不改RTL |
| SSW-D4（V18问题5） | C09 §8.5、§7.3 | 订正措辞：`static_test_commit_event`指上游表征CDC桥的提交事件，SSW没有该端口；`o_s_in[4:0]`在STATIC_BIAS期间跟随已提交的`i_test_mux_ctrl`，五位同拍变化 |
| BMI-913（B批次登记） | 矩阵§12 G-FP-05参数传播台账，Top→AMI一行 | AMI中Top未绑定的参数应为9个（含后来新增的`C_ADC_COMPLETION_LOST_CYCLES`、`C_ADC_COMPLETION_LOST_LIMIT`），台账写成7个；订正计数与说明文字，使用符号锚点，跑锚点门禁和§12.4a摘要重算 |
| V2-C1（V2试跑§7第3条） | C08 §4.2.1例外C第4项 | "AMI以电平保持校准请求"改为与RTL一致："AMI校准请求valid，或已被调度器接受、仍在AMI在途（`flag_calibration_request_inflight`）"。V2实测帧末拍valid=0、在途=1；按原字面，例外C的条件不成立 |
| V2-C2（V2试跑§7第4条） | C08 §8.3/§16.2 | 补写START后首个宏帧开始的数值上界（MANUAL与启动搜索两种情况分别给出），依据RTL推导并写明推导过程。V2实测NORMAL MANUAL下最大4拍 |

另外两项要求：
- **断言**：编写"IDAC状态为IDLE时不得有有效pending码"的断言，放入可复用的断言文件，供后续V7在全部仿真中启用。本轮至少在IDAC单元TB和一个系统TB中启用。
- **核实**：查明芯片合同中SPI SCLK的最高频率，计算两次相邻0x0090写入的命令在2 MHz域中的最小间隔（含各路同步与control_top寄存级数），确认不会出现START与abort同拍。若可能同拍，停下报告。

## 3. 回归与比对
- **基线**：ADC完成信号轮的终版全套回归（统筹届时提供目录）；否则先对基线提交跑一遍。
- **终版**：20份系统TB分组并行，加芯片、模块级，在`git -c core.autocrlf=false archive`导出的独立目录中运行。Vivado 2022.2，`VIVADO_BIN`默认`/c/Xilinx/Vivado/2022.2/bin`。
- **比对**：逐TB比对排序后的PASS行和`$finish`时刻。每处变化都要解释到具体项，例如：
  - 1.3会改变周期重检帧中的IR提交时刻；
  - 1.6会改变芯片TB的期望；
  - 1.7会改变NORMAL完成的计数；
  - 1.10会增加新的PASS行；
  - 1.11会使模块级由28份变为24份。
  无法解释的变化先停下报告。
- **建议**：先在仓库外副本中逐项完成并做单元级验证，全部完成后只跑一次全套回归。中途若有某项卡住，先完成其余各项，不要整轮停摆。
- **新检查**：列出新增检查、负对照的结果与证据位置。
- 1.5和1.9改动的PWC、IDAC、AMI，除各自单元TB外，还要在周期重检、ADC异常两个系统TB的结果中确认没有意外变化。

## 4. 交付
- 每项修复单独提交（RTL+TB+合同），提交说明写明发现编号。
- 报告`verification_reports/FIX_ROUND_RC1_<日期>.md`，内容包括：
  - 每项的修改点（符号锚点）；
  - 检查与负对照结果；
  - 合同改动；
  - 只写合同的20项的落点；
  - gate与-Wall对比；
  - 回归比对与逐项解释；
  - 新发现与待裁定项。
- 推送main之前先通知统筹核对，或按统筹届时的安排在分支上交付。完成后统筹决定是否打RC1。
