# GFP01 端口台账独立审计 —— 批次2（C10）

> 审计日期：2026-09-29
> 审计对象：`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md` §12.5 "G-FP-01 Port and reverse-consumer ledger" 中属于 **C10**（`ppg_adc_measurement_idac_integration.v`，即AMI，自身顶层端口及其内部专属信号链）的全部行，独立审计前共 **292** 行，散落在 §12.5 全文 5 段不连续区间（2196-2266、2444-2479、2619-2681、2736-2786、3119-3189，中间穿插 C11/C16/C17 等其他合同的行）。
>
> 本审计是"工作线C：G-FP-01 端口台账批次2-9独立审计"的**批次2**（批次1=C01，2026-09-16独立审计完成；批次3=C16+C17，2026-09-28独立审计完成）。方法论完全对齐前两次审计：不信任任何既有结论，先独立建证据库，再逐行比对；不抽样，292行全做；每个"0问题"结论都有负对照支撑。

---

## 1. 方法论

### 1.1 取证原则

与批次1、批次3完全一致：任何矩阵里"已有的结论"，包括C10自己"265 ports now fully accounted for"这类看似完整的收尾句，在被独立核实前都只是"待验证的声称"。本审计的独立事实库完全来自：
- 直接读取 RTL 源码得到的端口声明、例化连接、内部wire驱动/读取关系（不使用矩阵文本中的任何行号作为起点）；
- 独立数出的端口方向/数量；
- 全文件出现次数统计（用于悬空wire判定、覆盖范围核查）；
- 独立重跑的 `iverilog` 结构化elaboration。

只有在独立事实库建完之后，才回头逐行对照矩阵原文。

### 1.2 与erie-verilog-generator skill的关系（本仓库强制要求）

本仓库 CLAUDE.md 强制要求一切Verilog相关工作先经过 `erie-verilog-generator` skill。本次审计是**纯文档审计**，不生成、不修改、不"repair"任何RTL，因此skill里面向RTL生成/修复的部分（`improve_existing_verilog`、`agentic_repair`/`verify_existing_verilog`等）未使用。实际使用的是skill内部支撑其quality gate的**formatter/AST后端**（`scripts/python/quality/formatter_ast.py::build_ast_report_for_path()`）：这是一个纯只读解析器，不写RTL文件，给定一个 `.v` 文件返回结构化端口（含方向/位宽/**signed**/行号）、内部声明、assign、always块、例化连接（含原始例化文本）。

该组件在被正式采信前先做了负对照式验证：
- 用它解析 `ppg_idac_code_controller.v` 得到 **67 input + 55 output = 122** 端口，与批次3报告 §1.2 独立手工核对的结果（67+55=122）**逐位数字完全一致**，且10个子模块全部解析 `ok=True`、0诊断。
- 相比之下，skill文档里作为"既有RTL分析"标准入口的 `analyze_existing_verilog()` facade，其底层正则 `PORT_DECL_RE` 完全不处理 `signed` 关键字（对 `input signed [11:0]i_foo` 这类声明会提取出错误的位宽/名称）；AMI恰好有28个signed端口，若采信该facade会系统性引入新的signed类错误（与C01审计发现的"signed关键字丢失"问题同类）。因此本审计**未使用**该facade，改为直接调用底层formatter/AST后端，仅用作只读结构提取，不涉及任何生成/修改路径。

### 1.3 独立事实库的建立

| 事实库 | 取法 | 规模 |
| --- | --- | --- |
| AMI 顶层端口清单 | 两种独立方法交叉验证：(a) 对 `ppg_adc_measurement_idac_integration.v:95-406` 直接grep统计 `^\s*(input\|output\|inout)` 声明行；(b) `erie-verilog-generator` skill的formatter/AST后端解析同一文件 | **两法完全一致**：269端口（109 input + 160 output + 0 inout），28个signed端口，0重名，0解析错误 |
| AMI 的10个直接子模块端口清单 | 对每个子模块文件跑同一AST后端 | 53+50+74+60+63+81+122+152+13+32 = 700 个子模块端口声明（10个模块，0诊断） |
| AMI 例化连接表 | AST后端提取每个例化的原始文本，正则解析 `.port(expr)` 连接对 | 767 条例化端口连接（10个例化，覆盖AMI全部子模块） |
| AMI 内部网驱动/读取图 | 451个内部wire/reg声明 + 234条assign语句 + 61个always块，结合例化连接按子模块自身端口方向分类"驱动"/"读取" | 720个可查询标识符（451内部声明 + 269顶层端口）的完整驱动者/读取者索引 |

**方法论修正记录（诚实披露，属于本次审计自我纠错的一部分）**：驱动/读取图初版实现有两处真实bug，均已发现并修复，且修复前后的对比本身也是负对照的一种：
1. 初版把一条形如 `assign {a, b, c, ...} = payload;` 的**拼接式LHS**（AMI文件里唯一一处这样的赋值，行961，展开28个字段）当作单一字符串整体匹配，导致这28个字段全部被误判为"从未被驱动"。修复为正确拆分拼接LHS后，"从未被驱动"候选从29降为0。
2. 初版对always块的"读取者"判定只检查了`clock`/`reset`字段，未扫描块体正文，导致任何只在时序逻辑`if`/`case`条件里被读取（而非在assign右侧或例化输入连接里）的信号被漏判为"从未被读取"。修复后（改为扫描AST提供的块体`lines`文本）"从未被读取"候选从31降为7，且这7个候选里有4个与批次3报告 §3.5 独立发现的真实悬空wire（`flag_idac_amb_seq_busy`、`flag_idac_dcs_revalidate_busy`、`flag_fork_tracking_run_generation`、`flag_fork_local_empty`）**完全对应**——用完全不同的工具链（本次是AST解析+驱动图，批次3是纯人工Read+Grep）独立复现了同一组悬空wire，是本次事实库可信度的有力交叉验证。

### 1.4 交叉验证方式

机械核验与人工深读并重：
- 机械：对292行矩阵原文中的每一处 `file:line` 引用、每一个Formal-port名、每一个Direction标注，与独立事实库逐条比对；每类检查均先用负对照证明检测器不是空跑，再采信其"0问题"结论。
- 人工深读：全部4条"note"型行（无单一端口对应，风险最高）逐字通读；另在5个C10行块（2196-2266/2444-2479/2619-2681/2736-2786/3119-3189）中均抽样人工核对，并对机械检查触发的每一条候选异常做溯源式人工复核，不接受"机械检查说有问题"就直接采信。
- 与真实工具的交叉：`iverilog` 全层次elaboration独立重跑，2个负对照。

### 1.5 环境

- `erie-verilog-generator` skill：本仓库 `.claude/skills/erie-verilog-generator/`，仅使用只读formatter/AST后端（见§1.2），未触发任何生成/修复/验证-修复流程。
- `iverilog`：本环境未预装，本次通过 `apt-get install -y iverilog` 安装（12.0-2build2，与批次1/批次3使用的版本一致）。
- 全部脚本以只读方式运行在会话scratchpad目录，从未直接写入仓库文件；对矩阵文件的唯一写入路径是：先在scratchpad临时副本上空跑验证（见§3.3、§3.7），确认0异常后才应用到 `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md` 正式文件。RTL文件全程只读，唯一的"修改"（负对照2的位宽注入）只存在于scratchpad临时副本，从未写入仓库。

---

## 2. 结论速览

| 检查项 | 结果 |
| --- | --- |
| C10行定位（重新Grep，不信旧行号引用） | 292行，5段不连续区间（与任务描述给出的粗略位置有出入，已用Grep重新核实，见§3.1） |
| AMI顶层端口计数（265 vs 268 vs 269 discrepancy） | 269为当前真实值（两种独立方法完全一致）；"265"系cluster⑥自己在扫描时的独立计数（矩阵note行自陈"Read AMI's full 265-line port declaration"），在其扫描完成后AMI又新增4个端口，"265"已过期，非计数错误（见§3.2） |
| 292行C10 Formal-port名解析 | 292/292 全部解析为真实信号（AMI自身端口/AMI内部声明/10个子模块之一的端口），0个虚构名，含负对照 |
| Direction列核对 | 292/292 与其所属实体的真实声明方向一致，含负对照 |
| file:line 引用范围核验（文件存在+行号未越界） | 292行内全部file:line引用均有效，含负对照 |
| file:line 引用内容语义核验（深度检查） | 初筛103条疑似不匹配，逐条人工溯源后**0条为真实内容错误**——全部可归因于(a)已知的系统性行号漂移，或(b)本审计自建检测脚本对多实体行的识别精度问题（见§3.4），不是矩阵本身的错误 |
| 行号系统性漂移范围（补充/修正批次3发现） | 批次3报告称"AMI文件在C17/fork例化区前某处插入了15行"是简化描述；本次证实实际是**随文件深度平滑增长的累积偏移**（+2→+5→+9→+10→+15→+24），不存在单一插入点，已在矩阵中订正说明（见§3.5） |
| "Verbatim declaration anchor"列（第5列） | ~~292行全部为空~~ **已用脚本从RTL源码直接提取补全**，288个真实端口行 100% 命中（209条AMI自身声明 + 79条子模块声明），0个NO_MATCH/DUPLICATE/歧义未解，先在scratch空跑验证后应用（见§3.6） |
| 覆盖范围核查（AMI 269个端口是否都有台账记录，含全矩阵范围） | 269个端口中，**3个（`i_cal_owner_deadline_event`、`o_fir_history_full_r`、`o_fir_history_full_ir`）在整个矩阵零覆盖**，已补充为3条新行（见§3.2、§4问题1） |
| 悬空wire与"仅供诊断"信号扫描 | 发现3个真实悬空/仅诊断wire，其中2个（`flag_overlap_local_empty`、`dec_overlap_run_generation`）确认为**C13合同范围**（`ppg_adc_pipeline_overlap_corrector`），不属本批次；1个（`flag_unused_output_calibration`）确认为AMI内部payload寄存器的未使用占位字段，非端口，不需要台账行，记录为观察项（见§3.8） |
| note行"18个留空端口"计数 | **实际19个**，已订正（见§4问题2） |
| 独立iverilog全层次elaboration | `-s ppg_control_top`，30个非TB源文件，**0 warning 0 error**，含2个负对照 |

**总体结论**：C10这292行（订正后295行）台账的实质内容（端口是否存在、方向、连线拓扑、跨cluster归属声明）高度可信，未发现任何"端口凭空捏造"或"方向搞反"类致命问题。真实问题集中在两类：(1) 3个端口此前在整个矩阵零覆盖，属于纯文档缺口（RTL新增端口后台账未跟进），已补行；(2) 1处note行计数笔误（18→19）。行号引用存在与批次1/批次3同类、但范围更广的系统性漂移（累积偏移模式，非单点插入），已记录规律、未逐行重写。全部已在矩阵中原地订正（append方式，历史文字保留）。

---

## 3. 各项检查详述

### 3.1 结构性检查：292行C10的真实分布（不信任务描述给出的粗略位置）

任务描述给出的粗略位置是"2196-2266、2444-2479、2619-2636、2637-2786、3119-3189附近"。重新用 `Grep`（`^\| C10 \|` 锚定行首，避免匹配C10x或误命中）核实后，真实分布是5段**连续**区间：

| 区间 | 行数 |
| --- | --- |
| 2196-2266 | 71 |
| 2444-2479 | 36 |
| 2619-2681 | 63 |
| 2736-2786 | 51 |
| 3119-3189 | 71 |
| **合计** | **292** |

与任务描述的出入：第3、4段的真实边界是2619-2681与2736-2786，中间2682-2735共54行是**C11**（S1可编程校准器合同）的行，不是任务描述猜测的"2619-2636"/"2637-2786"切法。这印证了"不要直接信行号引用，需要重新Grep核实"的必要性——即使是任务描述本身给出的粗略范围也有出入。

Direction列分布：109 input + 179 output + 4 note = 292。

### 3.2 AMI真实端口数：269，"265"的真实来源与过期原因

独立数出AMI当前端口数为**269**（109 input + 160 output，28 signed），用两种完全独立的方法交叉验证一致（见§1.3表格第一行）。

矩阵原文note行（当前矩阵行3189）自称"C10's 265 ports are now fully accounted for"，且**该note行自己明确写出了取数方法**："Read AMI's full 265-line port declaration (`:93-395`)"——即cluster⑥在做该sweep时，独立通读了AMI的端口声明区，当时数出265个端口，这是一个（在当时）真实的原始计数，不是凭空编造或算术错误。

本次审计独立复核发现：cluster⑥完成该sweep之后，AMI又经历了V1.14（2026-09-05，新增 `o_s1_calibration_applied`/`o_s1_raw`/`o_s2_raw` 3个输出端口）与V1.15（2026-09-18，新增 `i_cal_owner_deadline_event` 1个输入端口）两次版本迭代，纯粹因为RTL在该note写成之后又新增了4个端口，265才变成了当前的269——这与C01审计发现"185行因Top版本演进而过期"是完全同类的现象（RTL持续演进、台账未同步跟进），不是"265"本身计算错误。

进一步核实这4个新端口的台账覆盖情况（**全矩阵范围**搜索，不限于C10——因为AMI自身端口经常被记录在其消费者子模块自己的合同行下，而非C10名下，见§3.4起首的说明）：
- `o_s1_calibration_applied`/`o_s1_raw`/`o_s2_raw`：矩阵已有记录，但记在 **Contract=C01**（矩阵约第1569行，C01第250行块的最后3行），不是C10——这些是2026-09-05 Top V1.5同步新增的芯片边界输出端口，C01在2026-09-16重建时已正确纳入。**不构成覆盖缺口**。
- `i_cal_owner_deadline_event`：整个3920行矩阵**零处**引用（不限于backtick精确匹配，宽松子串搜索同样为零）。**真实缺口**，已补充为新行（见§4问题1）。

### 3.3 292行C10 Formal-port名与Direction列核验（含负对照）

对292行逐行核验：Formal-port名是否能解析为AMI自身端口、AMI内部声明、或10个子模块之一的端口；若能解析，Direction列是否与该实体的真实声明方向一致。

**负对照**（证明检测器不是空跑）：在真实292行数据集中人工注入3条伪造记录后重跑同一脚本：
- 虚构端口名 `i_totally_fake_port_zzz_negative_control` → 正确报告"无法解析"
- 把 `i_clk`（真实方向input）伪造标注为output → 正确报告"方向不匹配"
- 引用一个超出文件总行数的行号（999999，文件仅2681行）→ 正确报告"行号越界"

三条负对照全部被正确捕获后，再对真实292行数据跑同一检测：**0个无法解析的Formal-port名，0个方向不匹配，0个越界或不存在的file:line引用**。

### 3.4 file:line引用的深度内容核验（含false positive溯源分析）

在§3.3"引用是否有效"基础上，进一步检查"引用的那一行是否真的包含该行自称的内容"。初筛用简单启发式（行内出现该行提及的某个backtick标识符）扫描292行，得到103条疑似不匹配。

**逐条溯源后，103条全部不是真实的矩阵内容错误**，可归为两类：

**(a) 已知的系统性行号漂移**（约80条）：矩阵引用的行号N，当前RTL实际行号是N加上一个随深度增长的偏移量（见§3.5），不是引用的内容错了，只是行号漂移导致"精确按矩阵给的行号去看"会看错位置。这类误报的鉴别方法是：以该行的Formal-port名或内部wire名为关键字，在同一文件内查找其真实出现位置，若能找到且与矩阵行号只差一个符合梯度规律的固定offset，判定为"漂移"而非"内容错误"。

**(b) 本审计自建检测脚本的识别精度问题**（约23条）：C10行经常在一句话里同时描述"Producer: 文件A:行X. Consumer: 文件B:行Y"这种多实体结构，本审计的初筛脚本用"整行文字里任意一个标识符命中任意一处引用"这种粗粒度判定，未能正确配对"这个标识符对应这一处引用、那个标识符对应那一处引用"。人工逐条重新配对后（例如把Producer子句里的标识符只与Producer子句的引用配对），确认这23条描述的Producer/Consumer链路本身均可在RTL中找到对应证据，只是脚本配对错了。典型例子：矩阵行"Producer: `ppg_adc_s1_redundancy_corrector.v:88`（对应`o_detect_code`）. Consumer: `ppg_adc_s1_programmable_calibrator.v:81`（`i_detect_code`）"——脚本把Formal-port列的`o_detect_code`错误地拿去核对Consumer侧的引用，自然找不到（因为calibrator侧的真实端口名是`i_detect_code`，不是`o_detect_code`），这不是矩阵的错，是脚本的识别粒度问题。

这一过程本身也是"机械核验+人工深读双轨"方法论的一次实证：纯机械初筛产生了103条看似可疑的记录，但只有回到RTL原文逐条人工复核，才能正确区分"真实错误"与"检测方法本身的局限"。最终：**0条真实的矩阵内容错误**。

### 3.5 行号系统性漂移：修正批次3"单点插入15行"的假设

批次3报告（`GFP01_C16_C17_INDEPENDENT_AUDIT_20260928.md` §4问题1）记录："AMI文件在此例化区之前的某处，被插入了15行内容...具体插入点未定位（需要审计本批次范围外的C10等合同）"，并把这个问题列为该批次"未覆盖范围"的一项，建议C10批次顺便定位。

本次审计独立核实后，结论是：**"单点插入15行"这个前提本身不完全成立**。用§3.4发现的溯源方法，对散布在文件不同深度的多个引用点分别计算"矩阵行号"与"RTL真实行号"的差值，得到一个随深度平滑增长的梯度，而不是一个固定常数：

| 矩阵引用大致深度 | 观测到的偏移 | 来源文件 |
| --- | --- | --- |
| ~行99（`i_active_config_valid`声明） | +2 | `ppg_adc_measurement_idac_integration.v` |
| ~行197（`i_idac_mode`声明） | +5 | 同上 |
| ~行1173（`flag_router_frame_type_error`使用处） | +9~+10 | 同上 |
| ~行1987（fork例化，批次3自己的发现） | +15 | 同上 |
| `ppg_adc_s1_programmable_calibrator.v`内部引用 | +24（独立聚类） | 子模块自身文件 |
| `ppg_control_top.v`内部引用 | +14 | Top自身文件 |

这与AMI自身V1.0-V1.15共15次版本迭代的变更历史完全吻合——变更日志显示多次修订在文件的不同位置新增了端口或逻辑（例如V1.10新增约20个discard端口组、V1.13/V1.14/V1.15各自新增1-3个端口），而不是一次性在某个单点插入15行。同一现象也独立出现在`ppg_control_top.v`与至少一个子模块（`ppg_adc_s1_programmable_calibrator.v`）自己的文件内部，说明这是本项目RTL持续迭代、台账引用未同步更新的**普遍模式**，不是AMI这一个文件的孤立事件。

因此，批次3"未能定位插入点"这一遗留项的**根本原因是前提本身不成立**——不存在一个可以被"定位"的单点，偏移量是引用被写入的时间点与被引用内容在文件中的相对深度共同决定的连续函数。已在矩阵中记录该规律（矩阵当前note行3189的独立审计附注），但鉴于受影响引用数量大（约90+处，遍布全部5个C10行块），未逐行重写，与批次3处理自己发现的+15问题时的原则一致：记录规律、不做无谓的逐行体力劳动。

**重要限定**：该漂移只影响"按矩阵给的行号去RTL翻页会翻到哪里"这件事的准确性，不影响连接关系本身是否正确——§3.4已确认本次追溯到的全部目标内容均与矩阵行文声称的producer/consumer/信号名一致。

### 3.6 "Verbatim declaration anchor"列（第5列）补全

292行C10全部为空（与C16/C17审计前的状态相同）。参照批次3附录二的经验（不手工逐行抄写，改用脚本从RTL源码正则提取），本次流程：

1. 对每行的Formal-port名，判定其"所有权"：若在AMI自身269端口列表中，引用AMI自身声明；若不在但在10个子模块之一的端口列表中，引用该子模块自身声明；若同一端口名被多个子模块各自独立声明（例如`o_frame_id`、`o_color_ir`这类多个模块共用的payload字段名），用行文中"Producer:"（output行）或"Consumer:"（input行）子句里明确提到的模块名做消歧——**不是简单地看整行是否提到某模块名**，因为很多行同时提到Producer和Consumer两个不同模块，早期版本脚本曾因此把窗口切得太宽导致27个本该消歧的案例被误判为"歧义"；改为只在"Producer:"到下一个"Consumer:"（或反之）之间的子句窗口内查找模块名后，292行中仅剩1个真正的歧义案例（`i_adc_transaction_start`，行文本身明确写"Shared with X -- both cluster⑥'s own modules, unambiguous despite the fan-out"，即真实的一端口多消费者场景，两个候选声明本身完全等价，确定性地取行文中先提到的一个）。
2. 从RTL源码对应行直接正则提取verbatim声明文本（方向+可选signed+可选位宽+端口名，逐字保留源码原始写法，不重新格式化）。
3. **先在scratch临时副本上空跑验证**：288个真实端口行（4个note行不适用）全部成功提取，0个NO_MATCH，0个提取失败，且用提取出的声明文本反查其方向关键字与矩阵Direction列做交叉核验，**0处不一致**。
4. 空跑通过后应用到正式文件。应用后核对：正式文件行数仍为3923行（此步骤本身只填空列，不增删行）；292行C10全部保持标准6列7个`|`（含对markdown转义竖线`\|`的正确处理，排除了一条含`assign ... = a \|\| b \|\| c;`表达式的行造成的误报）；`git diff --stat`显示288行变更，与预期完全一致。

### 3.7 独立重跑elaboration（含2个负对照）

```
$ iverilog -o <scratch>/iverilog_elab.out -Wall -g2005 -s ppg_control_top \
           -f ppg_control_top/rtl_filelist.f ppg_control_top/ppg_control_top.v
退出码：0
输出：（空，0 warning 0 error）
```

**负对照1**（证明"找不到模块"这类错误会被正确捕获）：
```
iverilog ... -s ppg_control_top_NONEXISTENT_NEGATIVE_CONTROL ...
error: Unable to find the root module "ppg_control_top_NONEXISTENT_NEGATIVE_CONTROL" in the Verilog source.
退出码：1
```

**负对照2**（证明端口位宽不匹配会被正确捕获）：在scratchpad中复制一份AMI RTL（不改动仓库内真实RTL），把 `i_amb_threshold_low` 声明宽度从 `signed [11:0]` 故意改成 `signed [15:0]`，替换进文件列表重新elaborate：
```
.../ppg_adc_measurement_idac_integration.v:2320: warning: Port 25 (i_amb_threshold_low)
  of ppg_idac_code_controller expects 12 bits, got 16.
ppg_control_top.v:1108: warning: Port 102 (i_amb_threshold_low)
  of ppg_adc_measurement_idac_integration expects 16 bits, got 12.
```
两处警告分别在两个方向（子模块例化与Top例化）都正确捕获了位宽不匹配，且报出的例化行号`:2320`与批次3报告 §3.8 负对照2独立得到的行号**完全一致**（尽管两次审计用的是不同的临时副本、不同批次的会话），进一步印证了该行号是真实、稳定的例化位置，也再次印证了§3.5发现的梯度偏移规律（`:2320`与矩阵可能引用的更早行号之间的差值符合该深度应有的偏移量级）。仓库内真实RTL全程未被改动（`git diff --stat -- rtl/` 为空）。

### 3.8 悬空wire与"仅供诊断"信号扫描（含负对照）

用§1.3的驱动/读取图对AMI全部451个内部声明做悬空扫描，"从未被驱动"候选为0（bug修复后），"从未被读取"候选为7个，其中4个与批次3独立发现的悬空wire完全对应（见§1.3方法论修正记录）。

**负对照**：用虚构wire名`flag_totally_fake_nonexistent_wire_zzz_negative_control`做同样查询，返回0次匹配；用已知高频使用的真实wire `flag_test_inject_effective`（RTL版本历史中被多次提及）验证其确实**不**出现在"从未被读取"候选中（该wire在全文件出现8次），确认检测器区分度正常。

7个候选中，扣除已被批次3记录的4个后，剩余3个新候选，逐一人工核实：

- `flag_idac_dcs_revalidate_busy`、`flag_idac_amb_seq_busy`：与批次3已发现的完全同名，本次审计独立复现，非新发现。
- `flag_overlap_local_empty`（AMI:642）与 `dec_overlap_run_generation`（AMI:763）：均是`ppg_adc_pipeline_overlap_corrector`（overlap corrector）自身输出端口`o_local_empty`/`o_run_generation`接入AMI后的内部wire，源码注释本身已明确标注"仅供诊断观测"。核查矩阵§2权威表（当前矩阵约第158-160行）确认：**`ppg_adc_pipeline_overlap_corrector`由独立合同C13（`PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md`，"Router/overlap pass-through and local empty"）管辖，不属于C10的3个专属子模块（`ppg_adc_async_stage_capture`/`ppg_adc_s1_redundancy_corrector`/`ppg_adc_result_router`）之一**。这两个wire的端口台账责任属于C13批次（工作线C批次列表中列为后续批次），不是本批次（C10）的覆盖缺口，本审计不越界处理，仅记录供C13批次参考。
- `flag_unused_output_calibration`（AMI:589）：不是任何端口连接产生的wire，而是行961那条拼接式assign（`assign {..., flag_unused_output_calibration, ...} = reg_result_fork_payload;`）里的一个字段，源码自己的注释是"正式输出未单独导出的Stage1资格"——即AMI内部结果payload寄存器里一个**声明了但未对外单独导出的占位字段**，不对应任何顶层端口或子模块端口，不是G-FP-01"端口台账"这个ledger的记录对象（该ledger的记录单元是"端口"，不是任意内部信号）。记录为观察项，不新增台账行。

---

## 4. 真实问题清单

### 问题1（3个端口，整个矩阵范围零覆盖）：`i_cal_owner_deadline_event`、`o_fir_history_full_r`、`o_fir_history_full_ir`

**范围**：AMI当前269个顶层端口中的3个，在整个3920行矩阵（不限于C10）中此前均为零引用。

**根因**：
- `i_cal_owner_deadline_event`：AMI V1.15（2026-09-18）新增，配合Top V1.6（同日）与Scheduler V1.8修复一个真实的SID-05校准搜索死锁bug；Top自己的V1.6变更日志明确记录了这是"纯内部接线改动...不新增顶层端口"，但AMI侧新增的这个输入端口从未被写入G-FP-01台账。
- `o_fir_history_full_r`/`o_fir_history_full_ir`：非新增端口（声明由来已久），但从未有过台账行；且发现一条**C19**（`ppg_coarse_detection_fir`合同）的行（矩阵行约2604-2605，`PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md:512`）明确声称"Consumer: ... PWI-internal diagnostic only -- **no matching AMI top-level port exists**"——该声称经独立核实为**假**：AMI:327-328明确声明了这两个输出端口，AMI:1111-1112用`assign`将其从内部wire导出到这两个顶层端口，`ppg_control_top.v:1309-1310`的例化连接也明确写着"接AMI.o_fir_history_full_r"（只是当前留空未接）。C19这条行不在本批次编辑范围（Contract列是C19不是C10），本审计**不修改该行**，仅在此记录、并在新增的C10行内交叉引用，留给未来审计C19的批次处理。

**处理**：已在C10区块末尾（当前矩阵行3189的note之后）新增3行，完整描述各自的producer/consumer链路与cluster归属（`i_cal_owner_deadline_event`归cluster⑥，`o_fir_history_full_r`/`_ir`归cluster⑤），并在note行3189追加独立审计附注说明"265"过期的真实原因。这是文档缺口（台账未跟进RTL演进/历史遗漏），不是RTL缺陷，未涉及任何RTL改动。

### 问题2（1处笔误）：note行"18个留空端口"实际是19个

**范围**：矩阵当前行2736（cluster⑥关于`ppg_adc_result_router`例化留空输出的发现性note）。

**表现**：该note称"all 18 of router's shared-payload output ports are left empty (`.o_calibrated_s1_value()` through `.o_dc_code_epoch()`)"。独立重新核对`ppg_adc_measurement_idac_integration.v:1938-1959`的例化连接，该"through"描述的首尾范围内实际留空端口共**19**个，多出的一个是`o_calibration_applied`（位于`o_calibrated_s1_value`之后、`o_saturation_low`之前，同样是空括号+"留空"注释）。用两种独立方法交叉核对：(a) 本次审计自建的例化连接解析器；(b) 直接Read源码逐行确认每个"留空"注释，两者结果一致。

**性质**：单纯计数笔误（"through"描述的范围本身已完整覆盖19个，只是求和时算错），不影响该note的核心技术判断——这19个端口确为真实存在、被驱动、但下游消费者绕过了router直接吃pre-router wire，属于有意的"跳过直通缓冲"优化，本审计独立核实该判断本身准确（`ppg_normal_transaction_fork`例化`:1985`、IDAC controller的AMB/DCS分支均按此接线）。

**处理**：已在原note后追加订正（`~~旧文字~~ **新结论**`格式，历史文字保留）。

### 观察项（非本批次处理范围，供后续批次参考）

- `ppg_adc_pipeline_overlap_corrector`的端口台账责任属于**C13**合同（`PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md`），该模块目前在§12.5里几乎没有专属端口行（仅1行以"Consumer"身份被C10行提及），C13批次审计时可能需要从零建立该模块约60个端口（33 input + 27 output）的台账，工作量与C11/C16/C17相当。本次未做处理（越界）。
- `flag_unused_output_calibration`：AMI内部结果payload寄存器一个声明但未导出的占位字段，非端口，不在G-FP-01台账的记录范围内，仅记录供参考。

---

## 5. 各项声称的逐条裁定

| 矩阵原有声称 | 裁定 |
| --- | --- |
| C10共265个端口，clusters③④⑤⑥分头认领，"now fully accounted for" | **总数已过期**：当前真实269个（+4，均为RTL后续版本新增）；229个claimed端口本身的producer/consumer链路经抽样与机械核验**未发现内容错误**；3个端口（新增4个里的1个 + 长期存在但被C19错误宣称"无对应端口"的2个）在整个矩阵零覆盖，已补行 |
| 292行Formal-port名、Direction列 | 292/292 与独立事实库完全一致，0处方向搞反，0处虚构端口名 |
| 292行file:line引用有效性（文件存在+行号范围） | 292/292 全部指向真实存在的文件，行号在范围内 |
| 292行file:line引用内容准确性（深度语义核验） | 103条初筛疑似不匹配，逐条溯源后0条为真实内容错误，全部可归因于系统性行号漂移或本审计自建脚本的识别精度局限 |
| AMI文件行号系统性偏移（批次3遗留问题："定位插入点"） | 批次3"单点插入15行"的前提不完全成立；本次证实实际是随深度平滑增长的累积偏移（+2→+24区间），与AMI 15次版本迭代分散在文件各处新增内容的历史完全吻合；同一现象也见于`ppg_control_top.v`与至少一个子模块文件 |
| "Verbatim declaration anchor"列全空 | ~~全空~~ 已用脚本补全288行（209 AMI自身 + 79子模块），先scratch空跑验证0异常后应用 |
| `ppg_adc_result_router`留空输出"18个" | ~~18个~~ **实际19个**，已订正，核心技术判断（功能性无害、有意跳过缓冲）本身准确 |
| 悬空/仅诊断wire扫描 | 3个候选中，2个属C13合同范围（非本批次），1个是非端口内部占位字段（非台账记录对象），均非C10范围内的真实台账问题 |
| 独立iverilog全层次elaboration | `-s ppg_control_top`，0 warning 0 error，2个负对照均被正确捕获，仓库RTL全程未改动 |

---

## 6. 总体结论

### 6.1 可信性判定

C10这292行（订正/新增后295行）台账的**内容实质**（端口是否存在、方向是否正确、producer/consumer链路、cluster归属声明）是可信的：292/292 Formal-port名与Direction列与独立事实库完全一致，103条初筛疑似内容不匹配经逐条溯源后0条为真实错误，独立iverilog elaboration 0 warning。

存在但已订正/记录的问题集中在：
1. **文档覆盖缺口**（3个端口零覆盖，已补行）——性质与C01审计的"65个新增行"、C16/C17审计的"C10范围外关联发现"同类：RTL持续演进，台账未及时跟进，是文档滞后而非内容错误。
2. **单处计数笔误**（18→19，已订正）。
3. **系统性行号漂移**（已记录规律，未逐行重写）——与批次3发现的+15问题同性质，本次证实其真实成因是累积效应而非单点插入，范围比此前认识的更广（不仅C16/C17的跨文件引用受影响，C10自身约1/3的行也受影响），但**不影响连接关系本身的正确性**，只影响"按矩阵行号翻代码"的精确性。

规模和性质与C01、C16/C17两次审计的结论高度一致：真实问题集中在文档层面（覆盖缺口、行号漂移、计数笔误），**未发现任何需要修改RTL的问题**，也未发现任何"端口凭空捏造"或大范围"方向标错"类致命缺陷。

### 6.2 已修的具体内容

矩阵原地订正/新增共5处改动（除新增3行外，均为append方式，`~~旧文字~~ **新结论**`，历史文字保留）：
- 288行第5列"Verbatim declaration anchor"从空白补全为verbatim声明文本+行号（脚本提取，非手工）
- 矩阵行3189（note）追加两段独立审计附注：(a) "265"过期原因与269的独立复核结果；(b) 行号系统性漂移的梯度规律说明
- 矩阵行2736（note）追加"18→19"计数订正
- 新增3行：`i_cal_owner_deadline_event`、`o_fir_history_full_r`、`o_fir_history_full_ir`

§12.1、§12.12及其他已关闭的G-FP账目（§12.6/12.7/12.9/12.10）未触碰，符合任务边界。全程未修改任何RTL/TB文件（`git diff --stat -- rtl/` 为空）。

### 6.3 本次审计未覆盖的范围（诚实声明）

- **系统性行号漂移未逐行订正**：约90+处受影响的file:line引用（遍布全部5个C10行块）仅记录了梯度规律，未像C01那样逐行重写为"当前"值。理由与批次3处理C17/C16的112行漂移引用时一致：数量过大，逐行重写会让已经很密的表格进一步膨胀，且不影响连接关系本身正确性的结论。读者需要按§3.5给出的梯度估算，或等待未来的统一订正批次。
- **C19行的错误声称未直接修正**：矩阵行约2604-2605（"no matching AMI top-level port exists"，经核实为假）不在Contract=C10范围内，按任务边界要求未修改，仅在新增的C10行内交叉记录、在本报告§4问题1详细说明，留给未来审计C19的批次处理。
- **C13（`ppg_adc_pipeline_overlap_corrector`）的端口台账缺口未处理**：该模块几乎没有独立的C10或C13行，可能需要后续C13批次从零建立约60个端口的台账。本次审计过程中意外发现（见§3.8），记录但未处理，因为Contract归属不是C10。
- **本仓库为GitHub发布快照**：本次矩阵修改**不会**自动同步回原始开发环境（另一台Windows机器`D:\PPG\verilog\jxa`）。经用户确认本仓库即最终权威版本，故未做额外同步处理。
- **批次1（C01）、批次3（C16/C17）已完成部分未重新复核**：本次只审计C10范围内的行，未重新验证C01/C16/C17已经结的账。
- 批次4-9（C08/C09、C15/C22/C07、C20/C23/C06、C03/C04/C02、C19/C24/C11、C13/C14/C05）均不在本批次范围内，未涉及。

---

## 附录：本次审计使用的核验方法与可复现脚本

全部脚本位于本次会话scratchpad目录，只读运行，从未直接写入仓库（唯一写入路径是"scratch空跑验证通过后，用独立的apply脚本对正式矩阵文件做最小化、经过结构完整性校验的写入"，见§3.6/§3.3）：

| 脚本 | 作用 |
| --- | --- |
| `ast_smoke_test.py` | 冒烟测试erie-verilog-generator skill的formatter/AST后端能否正确解析AMI，输出269端口清单 |
| `extract_instances.py` | 从AST后端的原始例化文本正则解析767条`.port(expr)`连接 |
| `extract_children_ports.py` | 对AMI的10个子模块分别跑AST后端，得到700个子模块端口声明 |
| `extract_internal_graph.py` | 提取AMI的451个内部声明、234条assign、61个always块 |
| `build_driver_reader_index.py` | 综合以上数据构建720个标识符的驱动者/读取者索引（含拼接LHS与always块体扫描两处bug修复） |
| `check_c10_rows.py` | 292行的Formal-port解析、Direction核对、file:line范围核验（含3条负对照） |
| `check_c10_content_match.py` / `refine_content_mismatch.py` | file:line引用的深度内容核验与偏移量梯度分析 |
| `build_anchor_column.py` / `apply_anchor_column.py` | 第5列verbatim声明锚点的提取、scratch空跑验证、正式应用 |

本报告及其分析过程中收集的完整端口清单、例化连接表、驱动/读取图，保留在本次会话记录中，如后续C13等批次需要类似的子模块端口台账重建，可复用本次的方法与部分数据（尤其是`children_ports.json`已含`ppg_adc_pipeline_overlap_corrector`的完整60端口声明）。
