# ADC完成信号保持型改造轮 任务书（RC1前，排在修复轮之前）

> 统筹会话撰写，2026-10-10。读者：本机新开的Claude会话（Vivado 2022.2）。本文件自包含。
> 基线：main `835643c`（B合同合并批次已合入）。RTL/TB与B批次终版`5d8ceba`相同，只多supervisor一处注释。
> 本轮之后再执行`FIX_ROUND_RC1_BRIEF`（修复与补测试轮）。两轮分开做，是为了让本轮的全套回归差异能单独归因。

---

## 0. 先读这一节

### 0.1 问题
数字侧一直假设ADC的完成信号（`CLK_STAGEx_DOUT_LOW`）是短脉冲，会自己回落。用户（模拟设计者）2026-10-10确认，实际行为是"保持型"，见§1。按真实行为，当前设计在芯片层有三个后果：
1. **首笔转换后静默停采**：
   - 芯片顶层的物理空闲 = `!DONE`（`ppg_chip_digital_top.v` `w_idle_mux_async`）。DONE保持为高，空闲就一直为0。
   - AMI的`transaction_start_ready_o`要求`i_adc_idle`，下一笔owner因此提交不了。
   - SSW只在有owner时才发Q1（`flag_red_has_owner`等）。没有Q1，DONE就不回落，形成死循环。
   - 全程只置不阻断的owner截止sticky，不报故障。
2. **STOP完成不了**：manager的STOPPING完成要求`i_adc_idle`。约5000拍后supervisor看门狗报0x31，之后仍不恢复；START也被挡住，只能重新上电。
3. **若只放开空闲，会采到旧数据**：`ppg_adc_async_stage_capture`在事务开始时置`flag_capture_pending`，并按同步后的DONE**电平**接收。上一笔的DONE要到Q1才回落，而owner在Q1之前提交，所以会立刻把上一笔的DOUT当作本笔结果收进来，静默错数。

**统筹的芯片级演示**（仓库外，`D:\PPG\verilog\ppg_regression_runs\coord_helddone_demo_20261010\`）：双光SAR9运行10帧后发STOP，对比两种DONE模型：

| 项目 | 短脉冲DONE | 保持型DONE |
|---|---|---|
| 转换次数 | 20 | 1 |
| 结果数 | 20 | 1 |
| STOP后 | 2500拍内回到CONFIG | 一直停在STOPPING，约5000拍后报0x31 |

所有现有TB都用5拍短脉冲模拟DONE，所以从未暴露。演示用的TB是`tb_helddone_demo.v`，在上述目录的`src/rtl/ppg_chip_digital_top/`下，可作参考。

**第二份独立证据（V2会话，control_top层）**：分支`v2-sweep-framework`的`verification_reports/V2_V7_BLOCKER_ADC_DONE_LEVEL_20261010.md`。
- 物理空闲按芯片公式（`!DONE`）取值时，第1笔之后静默停滞，与上面的芯片级演示一致；
- 物理空闲单独驱动、DONE保持到下一次Q3或AFERST时，每笔新提交约2拍后就把上一笔的旧高电平当成本笔完成，第2帧报SSW故障`0x21`并阻断。这就是§0.1第3条"采到旧数据"在control_top层的表现。

本轮的负对照可以直接复用它的最小复现。

### 0.2 工作位置与边界
- **工作目录**：本机还有其他会话在工作。V2会话占用`D:\PPG\verilog\ppg_github_release`，统筹占用`D:\PPG\verilog\ppg_coord_wt`。你必须用`git worktree add D:/PPG/verilog/ppg_helddone_wt -b adc-held-done origin/main`建立自己的目录，只在其中做git写操作。
- **CPU**：开始跑全套回归前告诉用户，由用户通知V2会话暂停批量仿真。
- **skill**：按根目录`CLAUDE.md`使用`.claude/skills/erie-verilog-generator/`。改动和新增的RTL都要跑deliverable gate，问题集不得新增。
- **RTL修改先在仓库外的导出副本中进行**（`git -c core.autocrlf=false archive`），验证通过后再提交。
- **标签**：修复点在既有实质性中文注释末尾追加`@satisfies`标签。新检查用TB本地名（本轮前缀`HD-`），并写明服务于本轮。
- **合同**：改写使用符号锚点（文件 + 符号 + 合同节号）。改合同后先跑`tools/b_merge_tools/anchor_check.py`；影响矩阵§12.4a摘要时，用`tools/b_merge_tools/manifest_digest.py --write`重算。
- **负对照**：每个修改先写检查，确认检查**在旧RTL上FAIL、新RTL上PASS**，再提交。
- 下任何"不会卡死、可以恢复"的结论前，把相关lane和状态位的置位、清零条件逐路追完，并实测。
- 遇到本任务书未覆盖、且需要裁定的取舍，停下报告，不要自行决定。
- **本机`python`命令已失效**（会以退出码49失败）。请用`py -3`。运行`tools/b_merge_tools/run_anchor_gate.sh`或`tools/run_unit_tb_regression.sh`时先设`PYTHON=py`，否则门禁会误报失败。
- **可复用的现成材料**：
  - 分支`v2-sweep-framework`中的`verification/v2_v7/adc_model/`（ADC行为模型，含自测）和`verification/v2_v7/monitors/`（活性、身份等监视器）。复用前须核对其"保持型"模式与本任务书§1完全一致。
  - 分支`v18-ssw-golden`中的SSW逐拍黄金比对脚本，可用于确认本轮没有改变SSW的输出。

---

## 1. 模拟侧接口事实（用户2026-10-09、10-10确认）
1. **Stage1完成信号`CLK_STAGE1_DOUT_LOW`**：
   - 在比较器结束时上升。Q3采样到上升沿约1~10 µs，即2~20拍。
   - **保持为高，直到下一次工作的复位，即Q1，才回落**：SAR9模式下是`CLK_9Q1_LOW`，SAR15模式下是`CLK_15Q1_LOW`（用户10-10确认）。
2. **Stage2完成信号`CLK_STAGE2_DOUT_LOW`**（仅15位模式）：
   - 在Stage1完成信号上升**之后**才回落，低电平一般约2.5 µs，最短约2 µs（4拍）；
   - **从Q3采样结束到Stage2完成信号上升，最长15 µs（30拍）**（用户10-10确认）；
   - 之后在Stage2比较器结束时上升，保持为高直到下一次复位；
   - 9位模式下不参与转换，电平不可信。
3. 某一槽没有工作时（没有Q1），DONE不会回落。一次测量最后一笔转换之后，DONE一直为高，直到下一次START后的第一个Q1。
4. 上电时DONE为低。
5. DONE为高期间，DOUT稳定。

---

## 2. 设计（用户2026-10-10已定）

### 2.1 物理空闲的新定义："当前没有转换在进行"
- 新建一个独立的小模块（建议名`ppg_adc_physical_idle_synth`），由`ppg_chip_digital_top`例化，替换现有的`!DONE`二选一与两级同步。
- **语义**：
  - 复位后为空闲（1）。
  - 在本次转换所用精度的Q1引脚上升沿，置为忙（0）：SAR9用`CLK_9Q1_LOW`，SAR15用`CLK_15Q1_LOW`。置忙时同时锁存本次精度。
  - 满足以下任一条件时回到空闲：
    1. 锁存精度所选那一级的DONE（经两级同步）在置忙之后**先被看到为0、再被看到为1**；
    2. 置忙后经过`C_ADC_CONVERSION_TIMEOUT_CYCLES`拍仍未满足第1条（转换超时，用户选方案(i)）。
- **超时值定为80拍（40 µs）**（统筹10-10依据用户给出的Stage2最长15 µs确定），请在设计说明中核算：
  - 下限：Q1到所选DONE上升的最长时间。SAR9 RED：Q1在293，Q3结束在301，再加20拍为321，共28拍。SAR15：Q1在284，Q3结束在304，Stage2最晚在304+30=334上升，共50拍，加两级同步约52拍。80拍留有约28拍余量。CAL：Q1在local 259，加20拍后约28拍。
  - 上限：必须早于下一笔owner截止前约3拍（同步与握手），按修复轮的新IR截止425计：SAR9 RED 293+80=373、SAR15 RED 284+80=364，都小于422；CAL 259+80=339，早于IDAC提交点local 385。
- **不变的部分**：
  - C01 §6.2.1的单点同步原则和五个消费者的扇出关系不变；
  - 消费者端口和`ppg_control_top`的边界不变；
  - 芯片顶层输出`top_active_precision_mode_o`仍作精度依据。

### 2.2 采集只接收"新的"完成信号
- 修改`ppg_adc_async_stage_capture`：事务开始（`i_adc_transaction_start`）后，所选那一级同步后的DONE**必须先被看到为0**，之后看到为1时才接收。上一笔遗留的高电平一律不收。
- 15位模式以Stage2为准。Stage2最短4拍的低电平能被两级同步器看到，这一点请在设计说明中核实。
- 保留现有的防护：事务开始那一拍禁止接收；完成后清除pending；跨代的陈旧DONE丢弃。

### 2.3 完成信号丢失
- 加了转换超时，DONE丢失时，超时后物理空闲回到1。现有的T-lost作废（4500拍，要求`i_adc_idle`）和同槽位连续2次升级cause 06的机制照常工作。
- cause 07（ADC长期忙）在芯片层仍然构造不出来。生命周期轮报告§7.1(e)已登记这一点，请在本轮报告中重申。

### 2.3a 作废与捕获的先后、迟到DONE、cause 07（V2试跑后统筹10-10裁定）
1. **作废与捕获同拍时，捕获优先**，与C09 F-035"abort与匹配完成同拍时完成优先"保持同一原则。
   - 背景：V2试跑（`verification_reports/V2_V7_FRAMEWORK_TRIAL_20261010.md` §6.2）发现，物理空闲与DONE同拍恢复时，忙过T-lost后才完成的转换，必然先被作废（`flag_owner_lost_fire`只看`!flag_capture_valid`，而捕获要等两级同步之后才登记），随后这笔DONE按无owner被拒，报cause 02。
   - 新定义加了64拍转换超时之后，这种情况回到合同所说的"约2拍"偶发窗口。但仍要求：作废条件同时排除"所选DONE已在同步链中出现上升"的那几拍（例如用同步后电平或`flag_capture_accept`），使同拍竞争确定为捕获优先。
   - 加检查与负对照：DONE上升落在owner年龄4498~4502拍各点。
2. **作废之后才到的DONE**：维持C10 §7.1a现行规则，不归属任何owner，按无owner捕获处理并升级（cause 02）。理由：模拟侧确认转换在Q3后2~20拍内完成，T-lost（4500拍）之后才来的DONE说明ADC已经异常。合同中写明这一点，以及T-lost相对模拟侧"最晚合法完成时刻"的余量。
3. **cause 07（ADC长期忙）**：新定义下数字侧看到的"忙"最长只有64拍，cause 07在芯片层构造不出来。
   - 保留为纵深防御，单元级仍可触发，与L-5的处理方式一致；
   - 合同和报告中写明"芯片层不可达及其原因"。

### 2.4 必须逐一核对的消费者
物理空闲的五个消费者，以及每一处使用`i_adc_idle`或`i_adc_physical_idle`的条件，都要在新定义下逐一说明行为：
- AMI：`transaction_start_ready_o`、`flag_owner_lost_fire`、`flag_adc_busy_fault_fire`、`flag_precision_takeover_safe`；
- 调度器：`startup_idac_safe_boundary_o`等；
- SSW：`flag_start_restore`、`o_wrapper_idle`；
- ACTIVE平面与manager：STOPPING完成；
- supervisor：看门狗。

**时序要求（用户2026-10-10强调）**：所有数字侧的判定与提交，都必须在下一次波形最早的控制边沿之前完成。包括精度切换、IDAC码提交、起帧快照。报告中要给出一张判定时刻表，证明新定义下各判定点都满足这一要求：
- NORMAL帧：
  - 最后一次转换（IR）在约第480拍前完成；
  - 第4760拍提交IDAC跟踪码并接管精度切换；`flag_precision_takeover_safe`要求`i_adc_idle`，在新定义下此时必须为1；
  - 第4999拍做起帧快照；
  - 下一帧第0/160拍锁存波形上下文；
  - 下一帧最早的控制边沿在第27拍（SAR15）或第44拍（SAR9）。
- 校准子帧：结果约在local 289采到，local 385提交下一候选码，下一子帧最早边沿在local 10。
- START：启动IDAC安全边界在首帧波形之前放行。

旧定义下还有一个同类后果：第4760拍时DONE仍保持为高，精度切换永远接管不了。本轮的负对照要覆盖这一点。

### 2.5 合同
本轮负责改写以下合同，使用符号锚点：
- **C01 §6.2.1**：物理空闲的定义与合成规则；
- **芯片合同**：ADC引脚语义（§1）、空闲合成器、超时参数；
- **C10**：采集接收规则（先低后高），以及DONE保持型前提；
- **C24**：看门狗所看的"物理空闲"的含义；
- **生命周期相关条文**：C10 §7.1a的T-lost前提；约2拍竞争窗口（F-3）在"先低后高"规则下是否仍然存在，请分析后改写。
- 验收ID：新增或改写的行为要有对应的验收条目，并按命名治理规则先查合同验收表。

---

## 3. TB
1. **可复用的保持型ADC模型**，新建`.vh`或模块：
   - 时延参数（Q3结束到上升沿2~20拍，可外扩）；
   - DONE保持到Q1；
   - 15位时Stage2在Stage1上升后回落，低电平宽度可配（最短4拍）；
   - 故障模式：丢失、迟到、长期忙。
   全部系统TB和芯片TB中的`drive_real_adc_done`及后台响应进程，都改用这个模型。
2. **control_top层TB也要用同一套空闲逻辑**：TB直接例化§2.1的新模块来产生`i_adc_physical_idle`，不再由TB单独驱动空闲电平。
3. **模块级TB**：
   - 采集模块：先低后高规则及其负对照；
   - 新空闲模块：自带单元TB；
   - AMI、调度器等受影响的单元TB相应调整。调度器单元TB中完成早于Q3的写法（V15-N3）一并改正。
4. **新增检查（前缀`HD-`）**，每项都要在旧RTL上FAIL、新RTL上PASS：
   1. 保持型DONE下，双光与单光连续运行至少10帧，结果数等于每帧应得数；
   2. DONE保持为高时发STOP，STOPPING在合同规定时间内完成；
   3. 随后START（含启动IDAC边界）正常；
   4. owner在Q1之前提交、旧DONE仍为高时，不得采到旧数据。每笔用不同的RAW码，按身份核对；
   5. DONE丢失：超时后回到空闲，T-lost作废；同槽位连续2次升级为cause 06；
   6. 15位模式：Stage2低电平取最短4拍时，仍正确完成；
   7. 精度切换前后两笔（9→15、15→9）；
   8. 校准子帧（AMB_CAL、DCS_CAL）连续运行；
   9. 芯片顶层重做统筹演示中的场景，结果应与短脉冲对照一致。

---

## 4. 回归
- 全套回归：系统级20个、芯片级1个、模块级28个。在`git archive`导出的目录中用Vivado 2022.2执行，逐TB比较PASS行和`$finish`。
- **比较基线**：`verification_reports/b_merge_batch_evidence/final_5d8ceba/`（本机Vivado 2022.2，49个TB的排序PASS行与`$finish`）。它的RTL/TB与本轮基线`835643c`相同，可直接作为对照；也可以先在`835643c`上重跑一次基线。
- 本轮会改变所有TB的ADC行为，差异会很大。报告中要逐TB说明每一处变化，并分类：
  - 时序后移；
  - 新增检查；
  - 原检查的期望值依据合同改写；
  - 其它（须单独解释）。

## 5. 交付
- **分支**：`adc-held-done`。推送main之前先通知统筹核对。
- **报告**：`verification_reports/ADC_HELD_DONE_ROUND_<日期>.md`，内容包括：
  - 设计说明：超时值核算、五个消费者的行为表、判定时刻表（§2.4）、Stage2同步可行性；
  - RTL改动（符号锚点）；
  - 合同改动；
  - TB改动；
  - 新检查与负对照；
  - 回归比对与逐项解释；
  - 遗留项。

## 6. 模拟侧前提的确认
- 已确认：SAR15模式下，Stage1的DONE由`CLK_15Q1_LOW`复位（用户10-10）。
- 已确认：15位模式下，从Q3采样结束到Stage2完成信号上升最长15 µs（用户10-10）；转换超时据此定为80拍。
- 设计说明中若发现其它尚未确认的模拟侧前提（例如Stage2最晚上升时刻），停下，通过用户向统筹提问，不要自行假设。
