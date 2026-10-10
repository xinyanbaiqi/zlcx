# V2逐拍扫描框架与V7断言：P0阶段交付与试跑报告

> V2/V7框架会话，2026-10-10。任务书：`verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md`；上位文件：`PRE_TAPEOUT_CLOSURE_PLAN_20261009.md` §2 V2、V7。
> 分支`v2-sweep-framework`。RTL与TB与`7a8eabf`相同，本分支只新增文件，未修改任何已有文件。
> 试跑源码：缩小网格两组用`627f065`，必须覆盖场景用`acc88f8`（之间只新增了一个故障模式和一个plusarg，其余两组不受影响）。均为`git -c core.autocrlf=false archive`导出，在仓库外的`D:\PPG\verilog\ppg_regression_runs\v2_20261010_trial2\`和`...\v2_20261010_trial3_mc\`编译运行。
> 判定一律来自TB逐条打印的V2MON/V7SUM/V2POINT等检查行，不以退出码或PASS横幅为准。

---

## 0. 结论

1. 四件交付都已完成并跑通：ADC行为模型、6个常驻监视器、扫描框架（TB＋网格＋批量与汇总脚本）、V7断言（19条）。
2. 负对照：
   - 三个自测TB分别通过44+2、43、13项（合计ADC模型46、监视器43、断言13）；
   - 4个RTL变异全部被目标断言杀死（任务书要求至少3个），未变异设计在相同点上全部PASS。
3. 当前RTL上的缩小网格共469点：PASS 444、EXC-C 15、EXC-F1 1、KNOWN-FIX-7 4、NEW 5。
   - 5个NEW经逐条分析，**没有新的RTL缺陷**，但有两项交统筹裁定（§6.2、§6.3）。
   - 全程0次身份错绑；只有1次活性超界，就是§6.3那一项，系统随后自行恢复。
4. 阻塞问题（ADC完成信号保持语义）已由统筹答复，登记为`KNOWN-ADC-HELD-DONE`。模型已按10-10确认的语义实现保持型模式，留作RC1后使用；本次试跑用兼容模式。
5. 正式全网格7776点，按实测推算约3.3小时（10路并行）；加3个时延种子约10小时（§8）。

---

## 1. 交付文件清单

全部位于`verification/v2_v7/`（另有本报告和`verification_reports/V2_V7_BLOCKER_ADC_DONE_LEVEL_20261010.md`）。

| 文件 | 内容 |
|---|---|
| `adc_model/v2_adc_behavior_model.v` | ADC行为模型（可综合风格，deliverable gate 0/0），见§2 |
| `monitors/v2_mon_liveness.v` | 活性监视核心 |
| `monitors/v2_mon_identity.v` | owner身份记分板核心 |
| `monitors/v2_mon_recovery.v` | 恢复检查核心 |
| `monitors/v2_mon_frame_interval.v` | 帧间隔监视核心（条件化例外C） |
| `monitors/v2_mon_q3_bind.v` | Q3与owner绑定（复制改写自`tb_ppg_control_top_adc_anomaly.v` V1.2） |
| `monitors/v2_mon_void_excl.v` | 作废与完成互斥（同上来源） |
| `assertions/v7_checkers.sv` | 4种通用SVA检查器（同拍蕴含、下一拍蕴含、互斥、有界活性） |
| `assertions/v7_assertions.sv` | `bind ppg_control_top`的19条V7性质，见§4 |
| `tb/tb_v2_sweep.v` | 参数化单点扫描TB。DUT例化、配置与生命周期task、owner快照复制自`tb_ppg_control_top_adc_anomaly.v` V1.2（行号写在文件头） |
| `tb/tb_v2_adc_behavior_model.v` | 模型自测（46项） |
| `tb/tb_v2_monitor_selftest.v` | 监视器正负对照自测（43项） |
| `tb/tb_v7_assertion_selftest.sv` | 断言检查器正负对照自测（13项） |
| `scripts/v2_compile.sh` | 只编译一次。RTL清单读自`xsim_adc_anomaly_filelist.f`并剔除其TB行，不改该文件；断言用`xvlog -sv`单独编译 |
| `scripts/v2_run_point.sh` | 单点运行：每点私有一份快照副本，以便并行。plusargs经`xsim -f`文件传入，因为`xsim.bat`会把`A=B`在`=`处拆开 |
| `scripts/v2_batch.sh` | 批量：并行数可配（默认10），可续跑（已有V2POINT行的点跳过），记录起止时间 |
| `scripts/v2_summarize.py` | 汇总：`summary.tsv`加Markdown表，只按TB打印的检查行判定，分类规则写在文件头 |
| `scripts/v2_gen_grids.py`、`grids/*.tsv` | 网格生成器与网格数据文件（试跑3份，正式2份） |
| `scripts/v2_selftests.sh` | 一次跑完三个自测TB |
| `scripts/v7_mutation_check.sh` | RTL变异负对照：在仓库外导出，单行sed变异，变异副本不入库 |
| `scripts/align_inline_comments.py`、`scripts/gate.sh` | 复用skill的VG060列宽函数做行尾注释对齐，并调用deliverable gate |
| `results/trial_20261010/` | 试跑`summary.tsv`/`summary.md`、必须覆盖场景的汇总（不含完整日志） |
| `results/mutation_20261010/` | 4个变异的diff和结果摘要 |
| `gate_results/` | 全部新Verilog/SV文件的deliverable gate结果（JSON+MD） |
| `PROGRESS.md` | 进度 |

---

## 2. ADC行为模型

### 2.1 语义

- 转换在owner的Q3窗口上升沿开始（模型在上升沿采到Q3为高的那一拍记为第0拍）。所选完成电平在第`i_latency`拍后上升，DOUT在转换开始后第1拍换成本次结果码，因此早于上升沿稳定。
- 时延由TB在每次owner提交时按种子从`[V2_LAT_MIN, V2_LAT_MAX]`取值，默认[2,20]，可外扩，也可固定。
- RAW取固定值150（窗口内），或在GEN_DUAL/RECHECK模式下取生理RAW生成器的值（`tb_ppg_real_raw_generator.vh`，经`-i`原样包含）。
- 四种DONE形态（`+V2_ADC_DONE_MODE`）：

| 模式 | 行为 | 用途 |
|---|---|---|
| 0 兼容 | Q3关闭后一拍起发5拍脉冲，idle只在脉冲期间为低；等价于`bg_adc_responder` | **本次试跑默认**（统筹10-10指定） |
| 1 保持型 | 按10-10模拟侧确认的语义：Stage1 DONE在比较结束时上升，保持到下一笔有owner事务的Q1上升沿（`CLK_9Q1_LOW`或`CLK_15Q1_LOW`）才回落，ADC从Q1起算忙；没有owner的槽不发Q1，DONE就不回落；上电为低。15位时Stage2在Stage1上升后一拍才回落，低5拍（时延不足时最短4拍），比较结束时再上升 | RC1后、ADC完成信号轮合入后切换为默认 |
| 2 提交时回落 | DONE在事务启动fire那一拍回落 | 非物理行为，只作对照 |
| 3 外部ADC_RST | 由TB给出回落脉冲（可选用`CLK_AFERST_LOW`上升沿） | 探索用 |

- idle公式（`+V2_ADC_IDLE_MODE`）：
  - 0 = "无转换进行"；
  - 1 = C01 §6.2.1字面公式，另要求所选DONE为低，相当于芯片顶层的`!CLK_DOUT`合成。
  - 另外可再延迟0~3拍（`+V2_ADC_IDLE_DELAY`），模拟ppg_control_top之外的单点同步器。
- 故障（按RED/IR/CAL槽位和第几笔，`+V2_SLOT`、`+V2_FAULT_SERIAL`）：

| 编码 | 故障 | 行为 |
|---|---|---|
| 1 | 丢失 | 无DONE，idle照常回到1 |
| 2 | 迟到 | 保持忙，到绝对落点才完成 |
| 3 | 忙后恢复 | 忙到落点后回空闲，不发DONE |
| 4 | 永久忙 | 一直忙 |
| 5 | 按时完成后继续忙 | 正常发DONE，但idle保持为低到落点（SID-05场景用） |

- 迟到和忙的落点在转换开始时换算为绝对拍数（帧偏移×5000＋目标相位－当前相位）。所以在途owner让宏帧停下时，落点照样到期。最初按"帧号＋tick"比较，例外C场景里宏帧停住后落点永远到不了，模型就一直忙，试跑中报cause 07。这是模型错误，已改。
- 兼容模式下迟到期间保持忙。最初照搬旧TB让idle为1，迟到超过T-lost时就落在合同前提之外（物理空闲后出现旧DONE），已改。

### 2.2 自测（`tb_v2_adc_behavior_model.v`，46/46 PASS）

逐拍核对了以下各项：
- 兼容脉冲：宽度5、相对Q3关闭的位置、idle窗口、15位时Stage2同拍；
- 保持型：时延2/10/20/1/30各点的上升拍；DONE在下一笔Q1回落，只有Q3时不回落；idle从Q1忙到完成；
- 15位：Stage1领先最终完成6拍，Stage2在Stage1之后回落并低5拍，时延不足时低4拍；
- 模式2、模式3的回落时刻；
- 五种故障；槽位与序号命中；CAL连续失联；兼容模式下的丢失与迟到。

---

## 3. 常驻监视器

全部是可综合检查核心（gate 0/0，不含系统任务），通过只读层次引用接入，不force任何信号。打印层在TB里：每个监视器结束时打印一行`V2MON <名称> PASS|FAIL|EXC <计数> ...`，并按`+V2_DETAIL`（默认8）打印前N条明细。

| 监视器 | 判定规则 | 界限及其依据 |
|---|---|---|
| LIVENESS | RUN/STOPPING中，连续C_LIMIT拍既无进展（完成、作废、正式结果、IDAC提交、生命周期变化）也无故障记录（AMI/SSW/调度器fault valid或系统阻断）即FAIL；每段只计一次 | 15000拍，即3个宏帧（任务书） |
| IDENTITY | 提交打开owner；下一拍SSW与AMI记录的身份（帧号、序号、颜色、类型、精度）必须与提交一致，三方在途都为1；过渡拍之外三方在途必须与记分板一致（连续不一致只计一次）；恰好一次带同序号的完成或作废关闭；成功NORMAL完成进入2项待决表；每个正式结果必须匹配一项；每个身份有效的discard必须匹配待决、当前owner（作废与原因11 discard同拍）或最近2个已关闭owner；待决10000拍未了结即FAIL；表满时报溢出，不静默丢弃；`i_excl_window`（F-3前提窗口）内的违例单独计数 | 10000拍：完成到正式结果的流水线远小于1帧，取2帧 |
| RECOVERY | (a) STOP确认到回CONFIG；(b) START确认到首个宏帧起点；(c) NORMAL模式下首帧到首个正式结果 | (a) 5000拍，即supervisor排空看门狗窗口：T-lost 4500加最长analog_safe等待仍在其内，更长的排空必须由看门狗上报，期间记录过故障即豁免；(b)(c) 合同只给条件、没给数值（C08 §8.3/§16.2），取一个宏帧，并报告实测最大值（试跑中(b)最大4拍，(c)最大329拍） |
| FRAMEGAP | 起点识别沿用F-009（帧在tick 0活动，且上一拍不活动或处于4999）；非5000间隔只允许三类：START后首帧（FIRST）；例外C（EXC-C），须在前一校准帧的tick 4999实际观测到其条件，且间隔至少5002；帧被STOP、abort或阻断故障结束（BREAK，C08 §4.2.1第3条F-010） | 例外C第4项"AMI以电平保持校准请求"在RTL中取`i_calibration_sample_valid || AMI.flag_calibration_request_inflight`，见§7 |
| Q3BIND | 每个Q3上升沿必须发生在调度器有在途owner、与该owner同帧（校准还须同子帧）时 | — |
| VOIDEXCL | AMI作废与完成不得同拍 | — |

**负对照**（`tb_v2_monitor_selftest.v`，43/43 PASS）：每个监视器都分别用合规序列（失败计数必须保持0）和违反序列（失败计数必须恰好增加预期值）驱动；身份记分板还核对失败码，10种失败码逐一构造。帧间隔监视器用真实的5000拍帧：
- 例外C条件成立且空2拍以上 → 放行；
- 只空1拍 → FAIL；
- 条件不成立 → FAIL；
- 条件出现在NORMAL帧末拍 → 不采信。

**试跑中发现并修正的监视器问题**（均为监视器自身问题，不是RTL问题）：
- 作废与原因11 discard同拍时，关闭历史还没更新，导致误报；
- slot=ANY时RED命中后IR序号1又命中；
- 在途不一致按拍计数，一次事件计了4501次；
- KNOWN-FIX-7签名在tick 0上误把上一帧的完成事件当作本帧的。

---

## 4. V7断言

### 4.1 工具能力

xsim 2022.2实测：并发断言能正确报错（一条通过、一条故意失败）；`bind`、跨层次引用、`##[m:n]`、`$past`、final块都可用；`cover property`不支持（会被忽略），不使用。断言文件单独用`xvlog -sv`编译，RTL不动。

### 4.2 性质与试跑结果

全部通过`bind ppg_control_top`挂接，RC1后加进所有系统TB时不必改动这些TB。带点的层次名会向上查找；ppg_control_top作用域里的简单名（例如`sched_adc_owner_commit_event_o`）不会向上查找，所以经bind端口传入。

下表"命中"为469个点的前件命中拍数之和，用来证明不是空真。

| 性质 | 断言 | 469点结果 | 命中 |
|---|---|---|---:|
| 1 owner唯一 | P1a 提交时调度器无在途，或同拍关闭 | 0违反 | 7111 |
| 1 三方一致 | P1b 非过渡拍三方在途一致；P1c SSW与AMI的owner身份一致 | 0违反 | 2.0e7 / 2.9e6 |
| 2 作废与完成互斥 | P2 | 0违反 | 7110 |
| 3 冗余校正器不变量 | P3 `(capture.flag_capture_pending ∨ rc.i_capture_valid) ⇒ (rc.flag_context_valid ∨ rc.flag_capture_drop_armed)`（信号已对照RTL核实） | 0违反 | 3.0e6 |
| 4 START后可恢复 | P4 START确认后下一拍SSW无RED/IR/CAL上下文 | 0违反 | 691 |
| 5 L-5不起作用 | P5 `flag_run_context_drained`且非START/abort时，lane 01/02/03/06/07全为0 | 0违反 | 17855 |
| 6 lane落下 | P6 START或abort后下一拍上述lane全为0 | 0违反 | 772 |
| 7 有界活性 | P7 RUN/STOPPING中15000拍内必有进展或故障 | 1个点违反（MC2，§6.3） | 2.0e7 |
| 8 IDAC IDLE | P8 IDAC控制器IDLE时无pending valid、无样本请求 | 0违反 | 175525 |
| 9 V1建议 | P9a manager stop_ack的上一拍为RUN/STOPPING；P9b CONFIG/READY时stop_episode_active=0（MGR-C1护栏）；P9c AMB重检期间无DCS pending；P9d START拍flag_start_restore成立；P9e 冗余校正器吞掉迟到RAW的拍不配对；P9f 精度控制器IDLE时无pending来源位（V1-PWC-C3护栏）；P9g 未START时调度器静默；P9h 重检请求transfer拍不被IDAC同拍消费；P9i AMI校准请求fire拍不同时撤销或被消费 | 全部0违反 | 224 / 15016 / 10515 / 691 / 6949 / 1.9e7 / 175525 / 7 / 535 |

性质9出自p0-closure的V1_CONFLICT_*.md中"建议扫描或断言"一列有明确RTL信号的条目。v1-independent的V1B报告中只有"不能断言互斥"一类说明，没有可直接写成断言的建议。

缩小网格未能有效覆盖的：P9a（命中224，但未构造"STOPPING完成拍的重复STOP"）、P9h（命中7）、P9c（只在启动搜索中命中）。KNOWN-FIX-4（MGR-C1）的同拍条件在本次网格中没有构造，所以P9b通过不说明问题已消失。

### 4.3 负对照

- **人造序列**（`tb_v7_assertion_selftest.sv`，13/13 PASS）：4种检查器各两份实例。合规组必须0失败且前件命中非0；违反组失败数必须恰好等于注入数。判定直接读检查器自己的计数器，所以被检查的是SVA的action块本身。复位期间的违反不计。
- **RTL变异**（`scripts/v7_mutation_check.sh`，导出到仓库外，每个变异只改一行，diff见`results/mutation_20261010/`）：

| 变异 | 改动 | 扫描点 | 目标断言（变异/原设计） | 连带触发 |
|---|---|---|---|---|
| MUT_P1_SSW_IGNORES_VOID | SSW `flag_owner_release`去掉`i_adc_transaction_lost_event` | DUAL9 LOST t100 | P1b FAIL 53042次 / PASS | — |
| MUT_P3_RC_NO_DROP_ARM | 冗余校正器作废时不布防（`flag_capture_drop_armed <= 1'b0`） | DUAL9 LOST t100 | P3 FAIL 499次 / PASS | — |
| MUT_P4_SSW_START_KEEPS_RED_CTX | SSW `flag_start_restore`分支不清RED上下文（复现L-6） | DUAL9 START_DELAY t1 d0 | P4 FAIL / PASS | P7（新RUN卡死） |
| MUT_P5_LANE06_IGNORES_ABORT | AMI lane 06只由START清零，abort不清 | DUAL9 LOST RED持续失联 t100 | P5 FAIL / PASS | P6 |

4/4被杀死；未变异设计在相同点上全部PASS。

---

## 5. 扫描框架与试跑

### 5.1 单点流程与参数

单点流程：复位（真实异步复位沿）→ 配置 → START → 等到目标帧和目标拍 → 注入 → 若离开RUN，则回CONFIG、等待d拍、诊断清除、COMMIT、START → 再跑至少`V2_POST`（默认3）帧 → 打印V2MON、V7SUM、V2POINT行。

- 模式：DUAL9（双光MANUAL SAR9）、RED15（表征PHOTODIODE+RED_ONLY+固定SAR15，按MGR-17这是唯一合法的固定SAR15组合）、SEARCH（双光SEARCH_TRACK启动搜索）、RECHECK（生成器加30帧周期重检）、GEN_DUAL（双光MANUAL加生理生成器，走真实检测链）。
- 事件：NONE、STOP、START_DELAY、ABORT、LOST、LATE、BUSY、POSTBUSY、FOREVER、DIAG_CLEAR、COMMIT；必须覆盖场景另有PREC_IR_LOST、RECHECK_CAL_BUSY。
- **精度切换请求**不是可按拍注入的独立事件，只能由检测链产生，见§9局限。
- 目标：`V2_FRAME`加`V2_TICK`，或`V2_SF`加`V2_LT`（换算为625×sf+lt）。

### 5.2 落点

每个点打印V2LAND，即DUT实际看到事件的那一拍。提前量全部实测校准：

| 事件 | 提前量 | 说明 |
|---|---|---|
| STOP | 2拍 | 调度器`i_stop_ack_event` |
| ABORT | 1拍 | control_top注册一拍 |
| DIAG_CLEAR | 0拍 | — |
| COMMIT | 3拍 | source域CDC到manager |
| LATE | — | 迟到完成上升的那一拍；兼容模式触发后一拍上升 |
| BUSY/POSTBUSY | — | 释放回空闲的那一拍 |
| LOST/FOREVER | — | 目标拍之后的第一笔转换的Q3上升沿 |

落点按绝对拍（帧×5000+tick）比较，并要求那一拍有帧处于活动状态。469点中：
- 393点精确一致；
- 73点为"INFO"：LOST或FOREVER的目标拍之后没有本帧转换，按定义落在下一笔转换上；
- 3点不符：MC4（宏帧因在途owner停顿，帧号和tick标签失去意义，按绝对拍是一致的）；SEARCH sf0 lt0和lt1的STOP（目标在START后首帧开始前的2拍之内，TB无法提前发出，只能立即发出，实际落在帧开始之前）。

### 5.3 缩小网格结果（469点；缩小网格两组用`627f065`，必须覆盖场景用`acc88f8`）

| 组 | 点数 | PASS | EXC-C | EXC-F1 | KNOWN-FIX-7 | NEW |
|---|---:|---:|---:|---:|---:|---:|
| DUAL9 / RED15 × {STOP, ABORT, LOST, LATE} × 37个关键拍（DUAL9的LATE分RED、IR两槽） | 333 | 329 | 0 | 0 | 4 | 0 |
| SEARCH × {STOP, LOST} × 8子帧 × {0,1,2,248,249,250,385} | 112 | 98 | 14 | 0 | 0 | 0 |
| 必须覆盖场景 | 25 | 18 | 1 | 1 | 0 | 5 |

（第3组在`627f065`上为24点，MC5只有同帧一个变体；在`acc88f8`上为25点，增加了跨帧变体。本表按`acc88f8`；469点的总数和逐点表见`results/trial_20261010/summary.tsv`。）

- **KNOWN-FIX-7**（4点）：DUAL9与RED15的STOP、ABORT落在tick 4999，帧末仍发出`o_normal_frame_complete_event`（V2SIG签名），与修复轮第7项一致。
- **EXC-C**（15点）：
  - SEARCH中LOST命中第1、2子帧的校准转换，owner在校准帧帧末仍在途，作废后下一校准帧晚起，间隔5131（7点）和5756（7点）。5131与合同例外C记载的实测值一致。帧末四项条件都在tick 4999实测成立（V2EXCC行）。
  - 另1点是MC4，间隔5112。
- **EXC-F1**（MC1）：生理生成器驱动真实检测链，第423帧精度控制器接受切换请求后丢掉下一笔IR完成。IR在tick 4812作废（>4760），随后cause 04、系统STOP，重启正常，其余监视器全部PASS。
- **NEW**（5点，逐条见§6）：MC2（1点）、MC9（4点）。
- 全部469点：Q3BIND、VOIDEXCL、IDENTITY都是0违反；LIVENESS只有MC2一处违反（V7的P7同步报出）；RECOVERY 0违反。

### 5.4 必须覆盖场景（任务书§3.3，`acc88f8`）

| # | 场景 | 点 | 结果 |
|---|---|---|---|
| 1 | F-1：真实检测链精度切换＋IR丢失 | MC1 | EXC-F1（见上） |
| 2 | 校准owner纯丢DONE并跨入NORMAL帧 | MC2：重检接管后第一笔重检校准转换不发DONE、ADC忙到下一宏帧tick 2000 | 跨帧后作废、重试、重检完成，0错绑、0故障；但活性超界，见§6.3 |
| 3 | L-6扩展到RED/IR/CAL完整窗口 | MC3：RED t1/44/200/300/318，IR t161/204/460/477，CAL sf1 lt1/10/266/283，均为START延迟0 | 13/13 PASS，P4命中且通过（变异负对照见§4.3） |
| 4 | 例外C | MC4：第0帧第一笔校准转换迟到到下一帧 | EXC-C，间隔5112，帧末四项条件实测成立 |
| 5 | SID-05截止跨帧重试 | MC5两个变体，均用POSTBUSY | 同帧：第1子帧local 248截止（idle=0），local 250重新请求，第2子帧重试提交；跨帧：第2~7子帧均截止，重试在下一帧提交；搜索完成，无故障（V2TRACE证据见`...\v2_20261010_dev\pts7\mc5*`） |
| 6 | 迟到完成跨帧 | MC6：RED完成迟到到下一帧tick 200（ADC保持忙，年龄<9000） | PASS，迟到结果正常出结果 |
| 7 | SAR15下的作废时序 | MC7：RED15 LOST | PASS，作废在age 4500，discard原因11，无升级 |
| 8 | cause 07在芯片层的可观测性 | 控制顶层的MC8（FOREVER）：cause 07加阻断，停在STOPPING，不是静默停滞 | 芯片层见下面的说明 |
| 9 | 冗余校正器作废前1~2拍DONE进入同步链 | MC9：模式2下迟到DONE落在t4499~4502 | 全部cause 02，见§6.2 |

**场景8（芯片层）的说明：**
- 芯片顶层idle=`!CLK_DOUT`。在保持型DONE下，第一笔之后就是`KNOWN-ADC-HELD-DONE`的静默停滞（阻塞报告第2节）。
- 在这种合成方式下，ADC"忙"只能表现为DONE保持高：此时idle=0，任何owner都提交不了，owner年龄也就不会增长；而DONE为低时idle=1，又只会走作废。所以cause 07在现有芯片顶层确实构造不出来，与生命周期报告§7.1(e)的结论一致，原因多了一条：保持型DONE。
- ADC完成信号轮的新idle模块定义为"从Q1起算忙、加64拍转换超时"。超时之后idle回到1，cause 07（9000拍）同样构造不出来。**建议在ADC完成信号轮中明确：cause 07是否保留、靠什么条件触发。**
- 芯片层仿真留到新idle模块合入后再做。

---

## 6. 新发现与需统筹裁定的事项

结论：**本次试跑没有发现新的RTL缺陷。**5个NEW点都可归入下面两项，均交统筹裁定。

### 6.1 已上报：KNOWN-ADC-HELD-DONE

见`V2_V7_BLOCKER_ADC_DONE_LEVEL_20261010.md`，统筹10-10已答复并登记，由单独的ADC完成信号轮处理。

### 6.2 迟到完成越过T-lost时，作废总是抢在捕获之前，结果都是cause 02（MC9等，交统筹）

**现象**：电平型DONE（模式2，DONE上升与idle恢复同拍）下，迟到完成落在age约4499拍以后的任何时刻，都会出现：
1. 先作废（discard 11）；
2. 随后这笔DONE按"无owner捕获"被拒，AMI报cause 02；
3. supervisor阻断、abort、STOP。

idle再延迟2拍（模拟芯片层单点同步）结果相同。兼容脉冲模式下不出现，因为脉冲期间idle为低。

| 迟到DONE的tick（RED提交在tick约3） | 4490~4498 | 4499~4510（所测各点） |
|---|---|---|
| idle延迟0拍 | 正常完成 | 作废，cause 02 |
| idle延迟2拍 | 正常完成 | 作废，cause 02 |

**原因**：作废条件`flag_owner_lost_fire`要求`!flag_capture_valid`。`flag_capture_valid`是登记后下一拍才为1，而idle是与DONE同拍恢复的。DONE要经两级同步才被捕获，所以在年龄已满4500的情况下，idle一回到1，作废条件就先成立。

**与合同的关系**：C10 §7.1a"捕获窗口前提（F-3）"第1点已写明："物理DONE落在约2拍的同步链窗口内时，owner会先被作废，随后这笔DONE按上一条被拒并升级"。所以这**是合同已描述的行为**。

**但要提醒**：在物理语义下，idle与DONE同拍恢复，因此每一笔忙过T-lost、随后完成的转换都必然落入这个窗口，而不是"约2拍"的偶发巧合。结果都是阻断加STOP，而ADC忙本身（不到9000拍）并不报故障。这与ADC完成信号轮的新idle定义直接相关。

**复现**：
```bash
bash verification/v2_v7/scripts/v2_run_point.sh <build> <dir> V2_MODE=DUAL9 V2_EVENT=LATE V2_SLOT=RED V2_TICK=4500 V2_ADC_DONE_MODE=2 [V2_ADC_IDLE_DELAY=2]
```
日志：`...\v2_20261010_trial3_mc\points\MC9_LATE_AT_VOID_t4500\xsim.log`，竞争窗口扫描结果在`...\v2_20261010_dev\race\`。

**请裁定**：这是可接受的已描述行为（例如把T-lost与模拟侧"最晚合法完成"的余量写清楚），还是应在ADC完成信号轮中让"捕获当拍"也能阻止作废（例如改用`flag_capture_accept`）。

### 6.3 活性界限（3帧/15000拍）与设计允许的"静默忙"不一致（MC2，交统筹）

**现象**：周期重检接管后，第一笔重检校准转换不发DONE，ADC忙到下一宏帧tick 2000才回空闲（约6700拍，低于cause 07的9000拍）。之后系统自行恢复：作废、重试、重检完成，0错绑、0故障。但RUN中连续16524拍没有任何进展和故障记录，LIVENESS与P7都报FAIL。

**追踪**（`V2_TRACE_FRAME=612`）：
- 第615帧：NORMAL正常完成；
- 第616帧：夹在重检之前的NORMAL帧，AMI整帧不ready，RED、IR都走owner截止，整帧没有事务。这是重检挂起期间的设计行为；AMI集成协议sticky同时置位，即KNOWN-FIX-3（AMI-C1）的表现；
- 第617帧：校准帧，注入的忙从这里开始；
- 第618帧tick 2002：作废。

不注入时，这段无进展期约9800拍，在界限之内；注入一段合法时长的忙之后就超过了15000拍。

**判断**：不是死锁，也不是新的RTL缺陷。问题在于"3帧无进展即判停滞"这条界限，比设计允许的"ADC静默忙最长9000拍（不报故障）＋重检前可能出现的空帧"更紧。

**请裁定**：
- (a) 活性界限放宽到"9000＋最长合法空帧＋余量"；
- (b) 把"物理ADC忙"本身计为非静默；
- (c) 认定这类组合应当有诊断上报。

**复现**：`V2_MODE=RECHECK V2_EVENT=RECHECK_CAL_BUSY V2_SLOT=CAL V2_TIMEOUT_CYCLES=8000000 V2_POST=6 V2_TRACE_FRAME=612`（约6分钟）。

### 6.4 已登记问题在试跑中的表现

| 已登记问题 | 表现 |
|---|---|
| KNOWN-FIX-7 | 4点，见§5.3 |
| KNOWN-FIX-3（AMI-C1） | MC2中AMI集成协议sticky置位 |
| EXC-F1 | MC1 |
| 例外C | 15点，均满足条件 |
| KNOWN-FIX-1（SSW-C1） | 只在SSW引脚上可见，本框架不比对SSW输出，未检查（属V18范围） |
| 其余KNOWN-FIX（2、4、5、6、8、9） | 缩小网格没有构造其同拍条件，未出现 |

---

## 7. 合同与RTL的差异

1. **C14 §2/§5.2（"DONE保持到下一次ADC_RST"、start须在DONE为低后）与RTL的提交时序**：owner提交早于本笔Q1，而DONE在Q1才回落。已登记为KNOWN-ADC-HELD-DONE。
2. **C01 §6.2.1 idle公式与芯片顶层合成器**：两者在保持型DONE下都会让idle在完成后一直为0。同上，由ADC完成信号轮处理。
3. **C08 §4.2.1例外C第4项"AMI以电平保持校准请求"**：在RTL中对应"AMI校准请求valid，或已被调度器接受、仍在AMI在途（`flag_calibration_request_inflight`）"。实测帧末拍valid=0、在途=1。建议合同改为后一种写法，否则按字面判定，例外C的条件不成立。
4. **恢复界限**：C08 §8.3/§16.2只规定了START后首帧的条件，没有给数值。本框架取1帧，实测最大4拍。建议合同补一个上界，供V2正式判定使用。
5. **C10 §7.1a F-3第1点"约2拍"**：在idle与DONE同拍恢复的物理语义下，触发面是"所有忙过T-lost的转换"，见§6.2。
6. （非差异，覆盖提示）在启动搜索中，值150使每个候选一次收敛，所以校准帧0只有子帧0~2有owner；子帧3~7的LOST落到下一NORMAL帧的RED上。正式扫描如要覆盖全部子帧，需要让搜索多走几个候选，见§10。

---

## 8. 正式扫描机时推算

**实测**（试跑：10路并行，本机12核，V7断言全部挂上）：
- 短点（除MC1、MC2外的467点）平均15.3秒/点，约3.19万拍/点，单进程约2100拍/秒；
- 469点墙钟911秒；
- MC1（210万拍）551秒，MC2（310万拍）793秒。

| 网格 | 点数 | 单点 | 机时（单进程） | 墙钟（10路） |
|---|---:|---:|---:|---:|
| `formal_normal.tsv`（DUAL9/RED15 × 7类事件＋START_DELAY 4档 × 234拍） | 5616 | 约15秒 | 约23.4小时 | 约2.4小时 |
| `formal_cal.tsv`（SEARCH × 5类事件＋START_DELAY 4档 × 8子帧 × 30拍） | 2160 | 约15秒 | 约9小时 | 约0.9小时 |
| 合计 | 7776 | | 约32小时 | **约3.3小时** |
| 时延种子×3 | 23328 | | 约97小时 | **约10小时** |
| 长场景（RECHECK、GEN_DUAL，每个5~13分钟） | 按需 | | | 每10个约15分钟 |

修复轮跑全套回归期间应暂停批量（任务书§0.4）。批量脚本可续跑，暂停后直接重启同一条命令即可。

---

## 9. 框架的已知局限

1. **ADC模型默认用兼容模式**：保持型模式在RC1前与RTL不兼容（KNOWN-ADC-HELD-DONE），本次试跑的结论只对兼容形态成立。
2. **精度切换请求**不能按拍注入，只能由生理生成器经检测链产生，时刻由信号决定。F-1类场景只能"在请求出现后注入另一个事件"（MC1）。正式扫描若要逐拍扫精度切换，需要验证构建中的专用注入口；现有`i_test_*`没有这一项。
3. **第0帧开头几拍的目标**（SEARCH sf0 lt0~1）：TB无法提前发出事件，落点如实标为不符。
4. **启动搜索用固定值150**：只覆盖校准帧0的前3个子帧。周期重检需要生理生成器跑到9→15→9，单点约13分钟。
5. **监视器只看控制面**：
   - 不比对SSW的32路模拟控制输出（SSW-C1只在引脚上可见，属V18）；
   - 不核对数值通路的结果值；
   - 身份记分板只按身份比对结果。
6. **合规与否的判定依赖界限取值**：恢复(b)(c)和活性的界限不是合同数值（§3、§6.3、§7.4）。
7. **断言只能证明"跑到的场景里没有违反"**（收尾计划V7已写明）：P9a、P9h在缩小网格上命中很少；KNOWN-FIX-4的同拍条件未构造。
8. **兼容模式的迟到行为**已改为"迟到期间保持忙"，与原`bg_adc_responder`（迟到期间idle=1）不同。原方式在迟到超过T-lost时会落在F-3前提之外。
9. **TB和SV文件的gate结果**未达0/0（§11）。
10. **执行环境**：本会话后期，shell里的`python`别名（WindowsApps）失效，改用`py -3`运行汇总脚本；`gate.sh`已支持用`PYTHON`环境变量指定解释器。

---

## 10. RC1之后正式扫描的建议做法

1. 变基到RC1；ADC完成信号轮合入后，TB例化新的空闲合成模块，并把ADC模型默认切到保持型（模式1）。先在保持型下重跑三个自测和本报告的缩小网格，与本次的兼容模式结果逐点对照。
2. 跑`formal_normal.tsv`和`formal_cal.tsv`（7776点，约3.3小时），再用3个时延种子各跑一遍（约10小时）。时延加上外扩档：固定1拍，以及21~30拍。
3. 校准子帧覆盖：给SEARCH加一个"候选不收敛"的RAW档（例如先给below_low再给in_window），让启动搜索用满8个子帧；或改用RECHECK模式，每点约13分钟，挑关键子帧和关键拍跑。
4. V7断言随修复轮之后的全套回归一起挂上：把`v7_checkers.sv`和`v7_assertions.sv`加入编译，xelab自动展开bind；TB不需要改。
5. 补构造：KNOWN-FIX-4（STOPPING完成拍的重复STOP）、KNOWN-FIX-2（子帧末拍同拍的校准请求）、KNOWN-FIX-8（abort与episode同拍），用来验证修复轮的效果，并给P9a、P9b找到有效命中。
6. 两份V1报告中标"待定"或"建议扫描"的条件对，尚未逐条列入网格，需要在正式网格中补行并回填V1。
7. §6.2、§6.3的裁定结果要回写监视器界限或合同。

---

## 11. 新文件的deliverable gate结果

用`.claude/skills/erie-verilog-generator`的`verilog_generated_deliverable_gate`（strict）检查。TB和SV文件加`--include-testbench`，因为gate默认把`tb_`开头的文件排除在交付门禁外。结果文件在`verification/v2_v7/gate_results/`。

| 文件 | 结果 | 问题分布 |
|---|---|---|
| `adc_model/v2_adc_behavior_model.v` | **0 error / 0 strict warning** | — |
| `monitors/`下6个文件 | **均为0 / 0** | — |
| `tb/tb_v2_adc_behavior_model.v` | 187 / 0 | VG060行尾注释列 178，VG025控制语句缺begin/end 8，VG000 1 |
| `tb/tb_v2_monitor_selftest.v` | 9 / 0 | VG025 5，VG002 2（文件头路径`monitors/*.v`中的`/*`被当作块注释，误报），VG000 2 |
| `tb/tb_v2_sweep.v` | 178 / 0 | VG060 107，VG025 66，VG002 2（同上误报），VG000 2，VG042注释覆盖率 1 |
| `tb/tb_v7_assertion_selftest.sv` | 4 / 0 | VG025 2，VG000 1，VG042 1 |
| `assertions/v7_checkers.sv` | 7 / 0 | VG025 6，VG000 1 |
| `assertions/v7_assertions.sv` | 95 / 24 | 主要是端口、实例、区域横幅类规则（VG064 22、VG024 19、VG030 16、VG040 15、VG060 15等）；SV的bind/断言结构不在该门禁的RTL规则范围内 |

- 可综合的模型和监视器核心严格通过。
- TB和SV的问题类别与现有TB相同（例如`tb_ppg_control_top_adc_anomaly.v`在同样选项下是231条：VG060 174、VG025 55、VG000 1、VG042 1）。
- 本次未为凑数去改这些TB/SV，以保证试跑源码与提交一致。如需达到0/0，可以在RC1前用`scripts/align_inline_comments.py`对齐VG060，再补begin/end。

---

## 12. 复现

```bash
# 导出与编译（仓库外）
R=D:/PPG/verilog/ppg_regression_runs/v2_<日期>_<标签>; mkdir -p $R/src
git -c core.autocrlf=false archive HEAD | tar -x -C $R/src
bash verification/v2_v7/scripts/v2_compile.sh $R/src $R/build
bash verification/v2_v7/scripts/v2_selftests.sh $R/src $R/selftests
# 缩小网格（可续跑）
G=$R/src/verification/v2_v7/grids
bash verification/v2_v7/scripts/v2_batch.sh $R/build $R 10 $G/trial_must_cover.tsv $G/trial_normal.tsv $G/trial_cal.tsv
py -3 verification/v2_v7/scripts/v2_summarize.py $R "标题"
# 断言变异负对照
bash verification/v2_v7/scripts/v7_mutation_check.sh . D:/PPG/verilog/ppg_regression_runs/v2_<日期>_mut 8
```

运行目录：
- `D:\PPG\verilog\ppg_regression_runs\v2_20261010_trial2\`：缩小网格，`627f065`；
- `...\v2_20261010_trial3_mc\`：必须覆盖场景，`acc88f8`；
- `...\v2_20261010_mut\`：变异；
- `...\v2_20261010_dev\`：开发、追踪和竞争窗口扫描。
