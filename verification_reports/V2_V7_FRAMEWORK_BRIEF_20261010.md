# V2逐拍扫描框架与V7断言 任务书（P0阶段）

> 统筹会话撰写，2026-10-10。读者：在本机（Vivado 2022.2）新开的Claude会话。本文件自包含：你看不到统筹的记忆、会话记录，只能看到本仓库和本机文件。
> 基线：main `2f0c0d0`（RTL/TB与`7a8eabf`相同）。
> 上位文件：`verification_reports/PRE_TAPEOUT_CLOSURE_PLAN_20261009.md` §2 的V2、V7两节（必读）。

---

## 0. 先读这一节

### 0.1 为什么做
回归只能证明"没有变坏"，不能证明"是对的"。本项目最严重的几个缺陷都是"异常恰好落在某一拍"：
- L-1：ADC完成丢失后错绑到下一笔；
- L-6：STOP落在波形接管与owner提交之间，随后START，静默卡死；
- 冗余校正器作废死锁。

V2把每类异常事件放到一帧中的每个关键拍去试，并全程挂着监视器。V7把关键协议性质写成断言，在所有仿真中持续检查。

### 0.2 本阶段范围
现在只做以下几件事，**正式扫描放在RC1之后，另发任务书**：
- 写ADC行为模型；
- 写常驻监视器；
- 写扫描框架和批量脚本；
- 写V7断言；
- 在当前RTL上用缩小网格试跑一遍，证明整套框架端到端可用，并估算正式扫描的机时。

### 0.3 工作位置与边界
- **仓库**：`D:\PPG\verilog\ppg_github_release`，是GitHub `xinyanbaiqi/zlcx`的克隆，以它为准。
  - `D:\PPG\verilog\jxa`是旧的原始工作树，只读，不要碰。
  - 如果会话是在jxa中打开的，每条命令都用绝对路径，或以`cd /d/PPG/verilog/ppg_github_release && ...`开头。Bash工具每次调用都会把工作目录复位。
- **分支**：从main切出`v2-sweep-framework`，只推这个分支。不推main，不碰`b-merge-batch`。
- **只新增文件，不修改任何已有文件**（RTL、TB、`.vh`、合同、filelist、回归脚本、README、矩阵、别名表）。新文件放在：
  - `verification/v2_v7/`：新建目录，下设`adc_model/`、`monitors/`、`assertions/`、`tb/`、`scripts/`、`grids/`；
  - `verification_reports/V2_V7_*.md`：报告。
- 现有TB中可复用的代码，**复制**到新文件里使用，在文件头写明来源文件与版本，不要改原文件。
- 不登记进任何回归脚本或filelist。登记放在RC1之后。
- **仿真在仓库外运行**：
  - 运行目录：`D:\PPG\verilog\ppg_regression_runs\v2_<日期>_<标签>\`；
  - 源码用`git -c core.autocrlf=false archive`导出后编译；
  - 只提交脚本、源码、汇总表和必要的日志摘录，不提交整份日志。
- **必须使用skill**：按根目录`CLAUDE.md`，加载`.claude/skills/erie-verilog-generator/`。新写的Verilog/SV文件遵循`erie_strict`风格，并对新文件跑skill的deliverable gate，结果写进报告。
- 发现RTL疑点：只记录，不修。

### 0.4 与其它工作的关系
- **B合同合并批次**：另一个账号正在分支`b-merge-batch`上按最终RTL改写合同，只改文档。
  - 合同语义以`git show origin/b-merge-batch:contracts/<文件>`的版本为准（只读）。
  - 合同与RTL不一致时，以当前RTL的行为为基线，但§2.2所列已知问题除外。差异记进报告。
- **修复轮**：B合并后，会有另一个本机会话执行RC1前修复轮（§2.2的9项修复），并在本机跑全套回归。
  - 届时用户会通知你暂停批量仿真，以免抢CPU（本机12核）。
  - 修复轮会改RTL和现有TB，所以你不能改它们，否则会冲突。
- RC1打标签后，你的分支变基到RC1，重新编译，再按另发的任务书正式扫描。

### 0.5 进度保存
- 每完成一个里程碑（§4），立即提交并推送`v2-sweep-framework`。
- 维护`verification/v2_v7/PROGRESS.md`：已完成、当前、下一步、已知阻塞。
- **教训**：Claude进程退出时，它启动的后台仿真会被一并结束（B批次遇到过）。批量脚本必须可续跑：跳过已有结果的点，并记录开始和结束时间。

### 0.6 第一次回复用户时
先用三五句话说明你对任务的理解和计划，然后开工。除非有阻塞问题，不必等确认。

---

## 1. 需要知道的事实

### 1.1 时间基准
- 2 MHz时钟。
- 宏帧5000拍（400 Hz），F-009之后相邻宏帧严格间隔5000拍。
- 校准宏帧分8个子帧，每个625拍（local tick 0~624）。

### 1.2 关键拍（以C08、C09为准，请到合同中核对）

| 项 | 拍 |
|---|---|
| NORMAL RED Q3 | 宏帧tick 300 |
| NORMAL IR Q3 | 宏帧tick 460 |
| NORMAL RED owner截止 | 宏帧tick 283（= RED Q3 − 17） |
| NORMAL IR owner截止 | 宏帧tick 443 |
| CAL Q3 | local tick 266 |
| CAL owner截止 | local tick 248 |
| CAL下一候选准备截止 | local tick 385 |
| 宏帧安全边界`MACRO_SAFE_TICK` | 宏帧tick 4760 |
| 帧末 | 宏帧tick 4999 |

- 波形窗口（`analog_safe` = 没有任何RED/IR/CAL波形处于活动状态）：
  - RED：SAR9 [44,318)，SAR15 [27,308)；
  - IR：在RED基础上整体后移160拍；
  - CAL：local [10,284)。

### 1.3 owner生命周期（方案甲，C10 §7.1a）
- 完成丢失超时T-lost：`C_ADC_COMPLETION_LOST_CYCLES` = 4500拍，到时作废。
- 作废discard原因为`2'b11`，并置`o_owner_lost_sticky`（芯片SPI 0x0108 bit6）。
- 同槽位连续作废k = 2（`C_ADC_COMPLETION_LOST_LIMIT`）时升级为cause 06。
- ADC长期忙升级为cause 07。

### 1.4 模拟侧事实（用户本人是模拟设计者，2026-10-09确认）
- 模拟侧可抽象为9位和15位两个SAR ADC。
- `CLK_STAGEx_DOUT_LOW`（完成信号）：上升沿表示转换结束，电平保持到下一次转换开始（下降沿）。
- 转换完成后DOUT稳定。
- ADC物理空闲后不会出现旧的完成信号。
- 完成信号几乎不会丢。所以"DONE丢失"只作为故障注入场景。
- Q3采样到完成信号上升沿约1~10 µs，即2~20拍，9位与15位相近。
- IDAC建立由波形内的`CLK_IREF_IDAC_LOW`脉冲和IDAC码脉冲保证。

### 1.5 可复用的现有代码（只复制，不修改）
- `rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v`（V1.1，生命周期轮的系统回归TB，最适合作为起点）。其中可复用：
  - DUT例化（control_top + supervisor）；
  - 配置、生命周期task（`task_pulse_start`/`task_pulse_stop`/`task_stop_and_drain`等）和启动搜索task；
  - owner身份快照进程；
  - 按槽位丢弃、推迟、失联、长期忙的后台ADC响应进程`bg_adc_responder`；
  - 被动监视器：Q3与owner绑定、作废与完成互斥、通用活性（15000拍）；
  - 只打印的F-009帧间隔监视器；
  - L-6扫描用的`l6_reset`、`l6_stop_at`。实测从STOP到调度器`i_stop_ack_event`为3拍，所以要让STOP落在目标拍，需提前3拍发出。
- `rtl/ppg_control_top/tb_ppg_real_raw_generator.vh`（生理RAW生成器）、`tb_ppg_jnt_baseline_prefix.vh`。
- 编译清单与命令：
  - filelist：`rtl/ppg_control_top/xsim_adc_anomaly_filelist.f`；
  - xvlog/xelab/xsim调用方式：`rtl/ppg_control_top/run_xsim_regression.sh`；
  - Vivado路径：`VIVADO_BIN=/c/Xilinx/Vivado/2022.2/bin`。
- 最近一次全套回归的日志（对照用）：`D:\PPG\verilog\ppg_regression_runs\545abfd_20261009\`（系统级）、`..._unit\`（模块级）。
- 注意：现有`bg_adc_responder`的完成信号是在Q3结束约1拍后给出的5拍脉冲，与§1.4不符（云端会话正按V15核对各TB的ADC模型）。V2的ADC模型按§1.4写，见§3.1。

---

## 2. 已登记的例外与已知问题（试跑时会遇到，不要当作新发现）

### 2.1 合同或用户已登记的例外
| 名称 | 行为 | 处理 |
|---|---|---|
| 例外C（FSC-03） | CAL帧末owner在途、无pending、NORMAL资格不成立（如启动搜索期）、AMI以电平保持校准请求时，CAL→CAL间隔大于5000，至少2个空拍；空拍数由owner释放时刻决定，实测出现过4和131 | 帧间隔监视器要**按条件**判定，不能按次数放行 |
| START后的第一帧 | 与前一帧的距离不是5000 | 正常 |
| F-1 | 双光模式下IR完成丢失，约在宏帧tick 4810作废，晚于4760；若此时有精度切换挂起，会切换超时，升级cause 04 | 已知例外，标`EXC-F1` |
| F-2 | 同槽位第k次作废落在主机STOP排空的末尾时，lane 06只保持1拍；cause 06在manager回到CONFIG后才开episode；supervisor发出的STOP使manager记错误0x0C；须先诊断清除，才能START | 已知例外，标`EXC-F2` |
| F-3（约2拍前提窗口） | 作废后旧DONE恰在下一笔start之后约2拍内到达时，会错绑并以success=1输出。合同把"物理空闲后不会出现旧DONE"写成前提，模拟侧已确认成立 | 扫描**不向该窗口注入DONE**；若专门测试，结果归入"合同前提外" |
| L-5 | 纵深防御路径，系统级下实测从未起作用 | 由V7性质5检查 |

### 2.2 修复轮将要修的9项（当前RTL上会表现出来）
监视器或断言报错、且根因是下列之一时，标`KNOWN-FIX-<n>`，并给出证据（扫描点、日志摘录），不作为新发现。
1. **SSW-C1**：双光SAR9下，RED窗口内`EN_9_IREF/AMB/DC`被IR段覆盖为0。只在SSW输出引脚上可见。
2. **SCH-C1**：调度器在子帧末拍（local 624，含帧末4999的滚动路径）同拍接受新的校准请求时，新请求的类型和颜色没有装入。
3. **AMI-C1**：AMI在整个RED窗口都不ready时（周期重检期间夹在校准帧之间的NORMAL帧，或精度切换挂起），调度器的start valid在RED截止后从RED候选直接切到IR候选，中间不落，AMI判为"反压期间载荷变化"，置集成协议错误。
4. **MGR-C1**：STOPPING排空完成与重复STOP同拍时，`stop_episode_active`卡在1，下一次RUN中supervisor的ADC看门狗可能误报0x31。
5. **诊断清除统一规则**：AMI的`integration_protocol_error_sticky`、IDAC协议sticky、PWC的两个sticky，在新事件与清除同拍时清除胜出，在故障仍活动时清除也生效。
6. **SPI命令字节多位组合**（只在芯片层）：一次写入同时含多个命令位，如0x03、0x0A。
7. **NORMAL完成门控**：STOP、abort或阻断故障之后，帧末4999仍发出`o_normal_frame_complete_event`。
8. **丢弃原因优先级**：主机abort与supervisor打开episode恰好同拍时，测量结果丢弃原因记为ABORT，而不是SYSTEM_FAULT。
9. **PWC丢弃那一拍**：pending相交或返回标志的置位压过取消；丢弃拍仍发出重获取请求。

### 2.3 新发现的处理
- **静默停滞或死锁**：立即停下，告诉用户。附最小复现：模式、事件、目标拍、实际落点、日志位置。
- **其它新问题**：写进报告，附复现，由统筹判断。修复轮开工前出现的可能并入修复轮，开工后出现的放到P3。
- **下"不可达""不会卡死"一类结论前**：要把相关每一路置位、清零条件逐路追到底。本项目曾因漏查一路而误判。

---

## 3. 任务

### 3.1 ADC行为模型（`adc_model/`，可复用模块）
- **语义按§1.4**：
  - 转换开始时完成信号为低；
  - 转换结束时出现上升沿，DOUT在上升沿前已稳定；
  - 完成信号保持高电平，直到下一次转换开始。
- **先从合同确认端口对应关系**：`i_adc_physical_idle`、`i_clk_stage1/2_dout_low_async`、`i_dout_stage1/2_low`、`o_clk_q3_low`与"转换开始、转换结束、物理空闲"之间的关系。如果合同没有写清"下一次转换开始"相对Q3的时刻，就作为阻塞问题，通过用户问统筹。
- **参数**：
  - Q3到完成信号上升沿的时延：默认按种子在[2,20]拍内取值，也可固定；还要支持两端外扩（如1拍、21~30拍），作为余量。
  - SAR9/SAR15的数值来源：固定值，或用生理RAW生成器。
- **故障模式**（按槽位RED/IR/CAL，可按序号指定第几笔）：
  - 丢失：无DONE，物理空闲照常回到1；
  - 迟到：DONE推迟到指定的绝对拍，可以跨帧；
  - 忙后恢复：忙到指定拍再空闲，不发DONE；
  - 永久忙。
- **兼容模式**：等价于现有`bg_adc_responder`的脉冲行为，用于A/B对照。
- 带自测TB，证明各模式波形符合定义。

### 3.2 常驻监视器（`monitors/`）
用单独模块通过层次引用只读观察DUT，**不force任何信号**。
1. **活性**：RUN或STOPPING中连续3个宏帧（15000拍）既无进展、又无故障记录，判FAIL。进展包括完成、作废、正式结果、IDAC提交、生命周期变化。由现有代码改写为模块。
2. **身份记分板**：
   - 从调度器、SSW、AMI的提交事件记录在途owner（帧号、序号、颜色、类型、精度）；
   - 每个完成、作废、正式结果和丢弃的身份，都要与某个在途owner一致；
   - 每个owner至多一次完成或作废；
   - 调度器、SSW、AMI三方记录的owner一致；
   - 排除§2.1中F-3的约2拍前提窗口。
3. **恢复检查**：STOP回到CONFIG、诊断清除、COMMIT、START之后，宏帧必须在合同规定的界限内重新开始；NORMAL模式下，正式结果必须在N帧内恢复。界限取自合同，写在报告里。
4. **帧间隔**：非5000的间隔只允许出现在START后的第一帧，以及**条件成立的**例外C中。
5. **Q3与owner绑定**：复用现有代码。
6. **作废与完成互斥**：复用现有代码。

**输出格式**：
- 每个监视器在仿真结束时打印一行汇总：`V2MON <名称> PASS|FAIL|KNOWN|EXC <计数> ...`；
- 另打印前N条明细，N可配置；
- 汇总脚本只按这些行判定。

### 3.3 扫描框架（`tb/`、`scripts/`、`grids/`）
- **一个参数化的扫描TB**（以`tb_ppg_control_top_adc_anomaly.v`的复制为起点），用plusargs选择：
  - 工作模式：NORMAL双光、NORMAL单光RED；SAR9、SAR15（固定精度配置，或经真实检测链切换）；启动搜索；周期重检。
  - 事件：STOP、abort、START延迟（回到CONFIG后过d拍再START）、DONE丢失、DONE迟到、忙后恢复、永久忙、精度切换请求、诊断清除、配置COMMIT。
  - 目标落点：宏帧tick，或子帧号加local tick；以及事件参数。
- **每个扫描点的流程**：复位 → 配置 → START → 进入稳态 → 在目标拍注入事件 → 恢复后至少再跑3帧 → 汇总判定。
- **落点精度**：每个点都要记录事件实际落在哪一拍。实际落点与目标不符的，在汇总中标出。
- **只编译一次**：xelab出一个snapshot，之后每个点用不同的`-testplusarg`调用xsim。并行任务数可配置，默认10（本机12核）。
- **网格定义是数据文件**（`grids/*.tsv`），不写死在代码里。按收尾计划V2：
  - 关键窗口逐拍扫：tick 0~2、160~162、248~250、266、283~285、309~311、385、443~445、477~479、4499~4503、4760、4808~4812、4999~5001，以及各子帧的local 0~2、248~250、385；
  - 其余位置步长不大于25拍。
- **汇总脚本**输出`summary.tsv`（扫描点、实际落点、判定、触发的监视器和断言、日志路径），以及Markdown汇总表。
- **必须覆盖的场景**：本阶段各写好一个场景并跑通一次，大规模扫描放在RC1之后。
  1. F-1：用真实检测链触发精度切换，再叠加IR丢失；
  2. 校准owner纯丢DONE，并跨入NORMAL帧；
  3. L-6扫描扩展到RED、IR、CAL完整窗口；
  4. 例外C；
  5. SID-05截止跨帧重试；
  6. 迟到完成跨帧；
  7. SAR15下的作废时序；
  8. cause 07在芯片层的可观测性。生命周期轮报告（`verification_reports/OWNER_LIFECYCLE_ROUND_20261007.md` §7.1(e)）指出：芯片顶层的物理idle由DOUT电平合成，所以cause 07在芯片层构造不出来。用§3.1的ADC模型（完成信号保持到下次转换开始）在芯片层重新确认能否构造；
  9. 冗余校正器作废前1~2拍，DONE进入同步链。

### 3.4 V7断言（`assertions/`）
- **先确认xsim 2022.2对SVA的支持**：写一个最小文件，含一条通过的和一条故意失败的并发断言，看能否正确报错。
  - 所需语法不支持的，改写成Verilog监视逻辑。
  - 断言文件单独用`xvlog -sv`编译；RTL保持Verilog-2001，不改。
- **首批性质**（收尾计划V7）：
  1. owner唯一：任一时刻至多一个ADC事务在途，且调度器、SSW、AMI三方记录一致；
  2. 作废与完成互斥：同一owner不会同拍既作废又完成；
  3. 冗余校正器不变量：`(capture_pending ∨ capture_valid) ⇒ (context_valid ∨ drop_armed)`。对应RTL信号：异步捕获模块的`flag_capture_pending`、冗余校正器的`i_capture_valid`、`flag_context_valid`、`flag_capture_drop_armed`。以RTL为准，请核对；
  4. START后可恢复：START确认时，没有残留的波形上下文（L-6）；
  5. L-5在系统级（control_top含supervisor）不起实际作用。L-5是AMI中lane 01/02/03/06/07在`flag_run_context_ended && o_datapath_empty`时的清零。生命周期轮已实测：系统级下lane每次置位都会引发supervisor episode和abort，abort先把lane清掉，所以L-5清零从未改变过任何lane（`verification_reports/OWNER_LIFECYCLE_ROUND_20261007.md` §7.1(c)）。断言：L-5清零条件成立的那一拍，这几个lane已经全部为0。若触发，说明找到了L-5的可达场景，按新发现上报；
  6. 各故障lane在合同规定的事件之后一定落下；
  7. 有界活性：RUN中，在规定拍数内必有进展或故障记录；
  8. IDAC控制器处于IDLE时，没有挂起的valid；
  9. 两份V1同拍冲突报告中建议做成断言的条件对。报告在分支`p0-closure`的`verification_reports/p0_closure/V1_CONFLICT_*.md`，和分支`v1-independent`的`verification_reports/v1_independent/V1B_CONFLICT_*.md`，用`git show`阅读。
- **负对照**：
  - 每条断言都配一个自测TB，用人造的违反序列和合规序列分别驱动，证明它能报错，也不误报。
  - 至少3条性质（建议1、3、4）还要在仓库外的RTL**变异副本**上跑一次，证明断言能在真实设计上触发。变异的diff写进报告，变异副本不提交。
- 当前RTL上某些断言可能因§2.2的已知问题触发（例如MGR-C1），标`KNOWN-FIX-<n>`。

### 3.5 在当前RTL上试跑（缩小网格）
- **网格**：
  - NORMAL双光SAR9、NORMAL单光RED固定SAR15，各配{STOP、abort、DONE丢失、DONE迟到}，在§3.3的关键窗口拍上扫；
  - CAL帧配{STOP、DONE丢失}，在子帧关键local tick上扫；
  - §3.3所列必须覆盖的场景，各跑一次。
- **报告**每个点的判定，分类为`PASS`、`EXC-*`（§2.1）、`KNOWN-FIX-<n>`（§2.2）、`NEW`。
- **统计**：单点平均耗时、并行吞吐，并推算正式全网格的总机时。

---

## 4. 里程碑与交付

| 里程碑 | 内容 | 提交时机 |
|---|---|---|
| M1 | ADC模型与自测；监视器模块；扫描TB编译通过，单点跑通 | 完成即推 |
| M2 | 网格文件、批量与汇总脚本、可续跑、并行；落点精度校验 | 完成即推 |
| M3 | V7断言、自测TB、变异负对照 | 完成即推 |
| M4 | 缩小网格试跑、必须覆盖场景的冒烟运行、报告 | 完成即推 |

**报告**：`verification_reports/V2_V7_FRAMEWORK_TRIAL_<日期>.md`，内容包括：
- 交付文件清单；
- ADC模型语义与自测结果；
- 各监视器的判定规则与负对照；
- 各断言、自测与变异负对照；
- 试跑结果表及分类统计；
- 新发现（逐条附复现）；
- 合同与RTL的差异；
- 正式扫描的机时推算；
- 框架的已知局限；
- RC1之后正式扫描的建议做法；
- 新文件deliverable gate的结果。

全部完成（或被叫停）时，告诉用户分支名、最后提交号和报告路径。统筹会核实，尤其是`NEW`类发现和各负对照。

**预计量**：约2~3个会话。

## 5. 本项目的教训（必须遵守）
- **不要force共享net**。异常一律通过TB驱动的输入，或验证构建中的专用注入端口（`i_test_*`，受`C_ENABLE_TEST_INJECTION`和`i_test_inject_enable`限制）构造。
- **异步复位要有真实的触发沿**。不能只在time 0置初值。
- **`$display`的`%0s`**：配合定宽标签时会打印出填充，标签要先裁剪。
- **计数口径**：计数窗口的起止要和判据一致，例如STOP边界。不允许没有推导依据的容差。long_10的"允许差1"曾掩盖过TB计数错误。
- **仿真器**：以xsim为准，iverilog只用于探索。
- **结论有证据**：不能拿退出码0或PASS横幅当判定，以逐条检查的结果为准。
