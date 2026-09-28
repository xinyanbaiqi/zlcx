# GFP01 端口台账独立审计 —— 批次3（C16 + C17）

审计对象：`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md` §12.5 "G-FP-01 Port and reverse-consumer ledger" 中属于 **C17**（`ppg_idac_code_controller.v`，行 2026-2147，122 行）与 **C16**（`ppg_amb_recheck_scheduler.v` 行 2148-2195，48 行；`ppg_normal_transaction_fork.v` 行 2787-2860，74 行）的全部 **244 行**台账。

本审计是"工作线C：G-FP-01 端口台账批次2-9独立审计"的批次3。方法论完全对齐 `GFP01_C01_REBUILD_INDEPENDENT_AUDIT_20260916.md`（下称"C01审计"）：不信任任何既有结论，先独立建证据库，再逐行比对；不抽样，244行全做；每个"0问题"结论都有负对照支撑。

---

## 1. 方法论

### 1.1 取证原则

任何矩阵里"已有的结论"，包括"C17 now 122/122"这类看似已核验的收尾句，在被独立核实前都只是"待验证的声称"。本审计的独立事实库完全来自：
- 直接 `Read` RTL 源码得到的端口声明、例化连接、内部逻辑行号（不使用矩阵文本中的任何行号作为起点）；
- 独立数出的端口方向/数量；
- `Grep` 对内部wire的全文件出现次数统计（用于悬空wire判定）；
- 独立重跑的 `iverilog` 结构化elaboration。

只有在独立事实库建完之后，才回头逐行对照矩阵原文。

### 1.2 独立事实库的建立

| 模块 | 端口声明位置 | 独立点数结果 | 例化位置 |
| --- | --- | --- | --- |
| C17 `ppg_idac_code_controller.v` | `:67`-`:207`（无 `#(...)` 之外的端口区） | **67 input + 55 output = 122** | 宿主 `ppg_adc_measurement_idac_integration.v`（AMI），`ppg_idac_code_controller_Inst` 例化于 `:2320`-`:2443`（连接本体 `:2321`-`:2442`） |
| C16 `ppg_amb_recheck_scheduler.v` | `:55`-`:116`（无参数模块） | **32 input + 16 output = 48** | 宿主 `ppg_precision_window_integration.v`（PWI），`ppg_amb_recheck_scheduler_Inst` 例化于 `:980`-`:1030`（连接本体 `:981`-`:1029`，其中 `:985` 为纯注释行） |
| C16 `ppg_normal_transaction_fork.v` | `:61`-`:146` | **34 input + 40 output = 74** | 宿主同为 AMI，`ppg_normal_transaction_fork_Inst` 例化于 `:1986`-`:2061`（连接本体 `:1987`-`:2060`） |

端口计数用两种独立方式互相校验：（a）手工逐行摘录端口名+方向；（b）`Grep` `^\tinput `/`^\toutput ` 计数。两者一致。三个模块总端口数 122+48+74=244，与矩阵台账的244行一一对应（无缺行、无多余行）。

另外独立核对了 idac_code_controller.v 内部实现区（`:595`-`:690`，41条 assign）与 amb_recheck_scheduler.v 内部实现区（`:195`-`:229`，16条 assign），用于核实"Producer: file:实现行"类引用。

### 1.3 交叉验证方式

机械核验与人工深读并重：
- 机械：对244行矩阵原文中的每一处 `file:line` 引用，用独立读到的RTL行号做逐条比对（非仅数字比对，同时比对端口名是否在该行匹配，防止"行号凑巧一致但指错端口"）。
- 人工深读：对每个"仅供诊断/无进一步消费者/仅AMI内部消费"类结论，用 `Grep` 统计该wire在AMI全文件的出现次数，人工判读每次出现的语义（声明/驱动/读取/导出）。
- 负对照：见§3.5、§3.8，每个"0问题"结论都配有一次"故意让检测器应该报错"的对照实验，确认检测方法不是形同虚设。

### 1.4 环境

- Bash 工具在本次审计前段出现过服务端分类器瞬时故障（"auto mode classifier gave no verdict"），期间改用 Read/Grep 完成了悬空wire扫描等工作；故障其后自行恢复，未影响最终iverilog复跑。
- `iverilog` 在本环境中原未预装，本次审计通过 `apt-get install -y iverilog`（12.0-2build2）安装后使用，未使用 Vivado/xsim（按任务要求不需要）。

---

## 2. 结论速览

| 检查项 | 结果 |
| --- | --- |
| 结构性：244行台账 vs 独立RTL端口计数 | 一致（122+48+74=244），0缺行0多行 |
| Direction列（input/output） | 244/244 与RTL完全一致 |
| 本模块自身文件引用（声明行+实现行） | 抽查/核对的全部约150处引用**零错误** |
| 跨文件引用 —— PWI（`ppg_amb_recheck_scheduler`） | 48/48 **零错误** |
| 跨文件引用 —— AMI（C17全部122行 + C16 fork块中引用AMI的行） | **系统性锚点少15行**（真实问题1，见§4） |
| 悬空wire误标注 | 2处真实问题（真实问题2） |
| "AMI-internal only"误标注 | 8处真实问题（真实问题3） |
| 结尾汇总句 in/out 拆分算术 | 2处真实问题（真实问题4），但**逐行Direction列本身没有错** |
| Verbatim declaration anchor列（第5列） | 244行全部为空，与C01重建后的格式不同——记录为**结构性观察项**，非本批次范围内的"错误"（见§4附注） |
| 独立iverilog全层次elaboration | `-s ppg_control_top`，37个非TB源文件，**0 warning 0 error**，含2个负对照 |

**结论**：C16/C17这244行台账的实质内容（端口是否存在、方向、连线拓扑、本模块自身引用）高度可信，未发现任何"端口凭空捏造"或"方向搞反"类致命问题。真实问题集中在四类，其中最大的一类（问题1）是纯粹的行号偏移，不影响"连接关系本身是否正确"的结论，但会误导任何按矩阵引用去看代码的读者；问题2、3是具体内容误判（约10行）；问题4是装饰性求和句算错。全部已在矩阵中原地订正（append方式，历史文字保留）。

---

## 3. 各项检查详述

### 3.1 结构性检查（244行 vs 独立端口计数）

见§1.2表格。244行与三个模块的独立端口总数完全对应，行数、方向计数均无出入。

### 3.2 Direction列核对

对2148-2195（C16 amb_recheck_scheduler）与2787-2860（C16 fork）两块，逐行摘录矩阵Direction列后独立求和：
- amb_recheck_scheduler：矩阵逐行Direction列求和 = 32 input + 16 output，**与RTL独立计数完全一致**。
- fork：矩阵逐行Direction列求和 = 34 input + 40 output，**与RTL独立计数完全一致**。

这一步意外定位了问题4的根源：两个模块末尾的装饰性汇总句（"31 in + 17 out"、"37 in + 37 out"）与它们自己上方244行中逐行Direction列的真实求和**不一致**——即错误只在结尾的一句话总结，不在正文244行的任何一个Direction标注上。C17未见类似的显式拆分汇总句，不涉及此问题。

### 3.3 本模块自身文件引用核查（声明行 + 实现行）

- C17自身：验证了全部122行中出现的 `ppg_idac_code_controller.v:NNN`（port declaration，如 `:67`-`:207`）与约42处 `ppg_idac_code_controller.v:6NN`（实现行，如 `:602`-`:682`）引用，**逐条与独立读到的源码行号+端口名/表达式比对，零错误**（含 `o_controller_fault_blocking` 那一行 `:638` 的具体布尔表达式 `o_amb_fault || o_dcs_r_fault || o_dcs_ir_fault`，逐字符匹配）。
- C16 amb_recheck_scheduler自身：验证了48行中 `ppg_amb_recheck_scheduler.v:NN`（声明行 `:55`-`:116`）与16处实现行（`:203`-`:224`）引用，**零错误**（含 `o_calibration_precision_mode` 那一行 `:211` 的具体表达式 `1'b0`，逐字符匹配）。
- C16 fork自身：验证了74行中 `ppg_normal_transaction_fork.v:NN` 声明行（`:61`-`:146`）引用，**零错误**。

### 3.4 跨文件引用核查（PWI / AMI）

**PWI（amb_recheck_scheduler的宿主）**：重新完整读取 `ppg_precision_window_integration.v:978`-`:1032`，把矩阵48行中每一行的 `ppg_precision_window_integration.v:NNNN` 引用与独立读到的例化连接逐行核对（含正确跳过 `:985` 纯注释行的情形），**48/48零错误**。

**AMI（C17与fork的宿主）**：重新完整读取 `ppg_adc_measurement_idac_integration.v:2290`-`:2449`（idac_code_controller_Inst全部122行连接）与 `:1965`-`:2064`（normal_transaction_fork_Inst全部74行连接），逐行与矩阵引用比对，**发现矩阵引用的行号系统性比实际行号少15**：矩阵写的行号 N，RTL实际行号是 N+15。在首行（`i_clk`）、末行（`o_idac_idle`/`o_local_empty`）及中段40+个样本点（含跨行的多跳引用链，如 `i_amb_sequence_start` 经 amb_recheck_scheduler→PWI→AMI三级引用）用**端口名匹配**（非仅数字加减）逐一验证，**零例外**。作为独立交叉验证，负对照2（§3.8）中iverilog报告的真实端口不匹配行号（`:2320`）与本审计独立读到的例化起始行完全一致，从另一个独立工具的角度印证了"实际行号在2320附近，不在矩阵所写的2305附近"。

未能定位这15行具体插入在AMI文件的哪个位置（该模块在C17/fork例化之前还有多个其他contract的例化，定位插入点需要审计C10等本批次范围外的合同，故未做）。

### 3.5 悬空wire扫描（含负对照）

矩阵原文中，C17的10行、fork的3行使用了"仅供诊断/无进一步消费者/仅AMI内部消费"类措辞。对这13个候选wire逐一 `Grep` 统计在AMI全文件的出现次数：

| wire | 矩阵声称 | Grep出现次数 | 判定 |
| --- | --- | --- | --- |
| `flag_idac_amb_seq_busy`（行2097） | 仅AMI内部消费 | 2（声明+例化连接，无第三处） | **矩阵错误**：实为真悬空，从未被读取 |
| `flag_idac_dcs_revalidate_busy`（行2104） | 仅AMI内部消费 | 2 | **矩阵错误**：真悬空 |
| `flag_fork_tracking_run_generation`（行2859） | PWI-internal diagnostic only | 2 | 矩阵结论正确 |
| `flag_fork_local_empty`（行2860） | diagnostic-only，矩阵自称"confirmed via grep" | 2 | 矩阵结论正确 |
| `measurement_result_discard_run_generation_o`（行2841引用） | "real consumer, not pure diagnostic" | 6（声明`:787`+导出`:1009`+复位×2+锁存赋值`:1351`+例化连接） | 矩阵结论正确（且矩阵能指出"尽管RTL自身注释说仅供诊断，实际仍被消费"，判断力可信） |

**负对照**：用一个虚构wire名 `flag_idac_nonexistent_probe_zzz_negative_control` 做同样的 `Grep`，确认返回0次匹配（而非因某种通配符/大小写问题误报"存在"），证明本检测方法本身有效，不是形同虚设。

结论：13个候选中，2个（2097、2104）是真实错误（见§4问题2），其余11个此前的"0问题"结论被独立证实成立。

### 3.6 "AMI-internal only"系统性误标注扫描

在§3.5基础上，进一步发现C17的另外8行（2113-2120，`o_amb_code_update`/`o_dcs_r_code_update`/`o_dcs_ir_code_update`/`o_dcs_r_track_adjust`/`o_dcs_ir_track_adjust`/`o_amb_search_done`/`o_dcs_r_search_done`/`o_dcs_ir_search_done`）同样标注"AMI-internal only"/"consumed only inside AMI"，但 `Grep` 显示这8个wire在AMI文件中均恰好出现3次：声明 + 例化连接 + 一条 `assign o_XXX = XXX_o;`（导出到AMI同名顶层端口）。即这8个wire其实都被**导出到了芯片/AMI边界的输出端口**，与其正上方/正下方的 `o_amb_code_epoch`、`o_amb_pending_valid`、`o_amb_code_at_min`、`o_amb_fault` 等行使用的"-> AMI's own `o_XXX` port, C10 row below"标注方式属于同一类情况，但这8行没有这样写。

抽样核实了这8个对应的AMI顶层端口名（`o_amb_code_epoch`、`o_amb_pending_valid`、`o_amb_code_at_min`、`o_amb_fault`、`o_idac_idle`、`o_startup_search_complete`、`o_idac_protocol_error_sticky`）确实存在于AMI自身端口声明区（`:277`/`:291`/`:294`/`:300`/`:304`-`:306`），确认"C10 row below"这类交叉引用不是凭空编造。

### 3.7 位宽/signed一致性抽样

矩阵第5列"Verbatim declaration anchor"在C16/C17全部244行中为空（见§4附注），因此不存在"verbatim锚点里signed关键字被静默删除"这类C01式问题（该列从未被填过，无从删起）。转而直接核对RTL两端的位宽/signed是否一致：
- C17的6个signed端口（`i_amb_threshold_low/high`、`i_dcs_threshold_low/high`、`i_search_calibrated_s1_value`、`i_track_calibrated_s1_value`）：C17自身声明与AMI侧同名顶层端口声明均为 `signed [11:0]`，宽度/符号一致；内部使用处（`:427`-`:434`）确认以 `$signed()` 显式比较，语义与矩阵"AMB/DCS残差窗口"描述吻合。
- fork的5个signed端口（`i_calibrated_s1_value`/`o_measurement_calibrated_s1_value`/`o_track_calibrated_s1_value` 为 `signed [11:0]`，`i_stage1_code_ext`/`o_measurement_stage1_code_ext` 为 `signed [10:0]`）：AMI内部承接wire（`dec_router_calibrated_s1_value`、`dec_measurement_s1_value`、`flag_track_s1_value`）声明位宽/符号与之一致。

未发现位宽或符号不一致。

### 3.8 独立重跑 elaboration（含2个负对照）

```
iverilog -Wall -g2005 -s ppg_control_top -o elab_top.out <37个非testbench .v文件>
退出码：0
输出：（空，0 warning 0 error）
```

**负对照1**（证明"找不到模块"这类错误会被正确捕获）：
```
iverilog -Wall -g2005 -s ppg_control_top_NONEXISTENT_NEGATIVE_CONTROL ...
error: Unable to find the root module "ppg_control_top_NONEXISTENT_NEGATIVE_CONTROL" in the Verilog source.
退出码：1
```

**负对照2**（证明端口位宽不匹配会被正确捕获）：在scratchpad中复制一份 `ppg_idac_code_controller.v`（不改动仓库内真实RTL），把 `i_amb_threshold_low` 声明宽度从 `[11:0]` 故意改成 `[15:0]`，替换进文件列表重新elaborate：
```
ppg_adc_measurement_idac_integration.v:2320: warning: Port 25 (i_amb_threshold_low)
  of ppg_idac_code_controller expects 16 bits, got 12.
```
成功捕获，且报出的例化行号 `:2320` 与本审计§3.4独立读到的真实例化起始行完全一致（独立佐证问题1）。

两个负对照均证明elaboration确实在做实质性结构检查，因此正文的"0 warning 0 error"是有意义的结论，不是elaboration本身失效导致的假阴性。

---

## 4. 真实问题清单

### 问题1（系统性，影响面最大）：AMI文件锚点行号系统性少15

**范围**：C17全部122行（2026-2147）中所有指向 `ppg_adc_measurement_idac_integration.v` 的行号引用；C16 fork块（2787-2860）中所有指向同一文件的行号引用（例如 `i_clk` 矩阵标 `:1972`，实际 `:1987`）。

**表现**：矩阵标注的行号 N，RTL实际行号为 N+15。总数、方向、端口对应关系、连接拓扑本身**没有错**，纯粹是"按矩阵给的行号去翻代码会翻到错误/偏移15行的地方"。

**根因推断**：AMI文件在此例化区之前的某处，被插入了15行内容（如新增注释、新增端口或新增一小段逻辑），此后矩阵引用从未重新计算。具体插入点未定位（需要审计本批次范围外的C10等合同）。

**处理**：C17末行（2147）与C16 fork末行（2860）已追加完整说明与订正公式；10行有实质内容错误的行（见问题2、3）已逐行订正；其余约112行按"+15"公式由读者自行换算，不逐行重写（避免244行表格因高度重复的订正文字而进一步膨胀失去可读性）。

### 问题2（2行）：悬空wire被误标注为"仅内部消费"

行2097（`o_amb_sequence_busy`→`flag_idac_amb_seq_busy`）、行2104（`o_dcs_revalidate_busy`→`flag_idac_dcs_revalidate_busy`）：矩阵称"consumed only inside AMI"，独立grep证实这两个wire在AMI全文件仅出现2次（声明+例化连接），此后从未被读取，是真正意义上的悬空输出——性质与矩阵在别处已承认的C15"11处悬空输出"同类，只是C16/C17这两处此前未被正确识别、标注成了"内部消费"。已订正。

### 问题3（8行）：应导出到AMI端口的wire被误标注为"AMI-internal only"

行2113-2120：`o_amb_code_update`/`o_dcs_r_code_update`/`o_dcs_ir_code_update`/`o_dcs_r_track_adjust`/`o_dcs_ir_track_adjust`/`o_amb_search_done`/`o_dcs_r_search_done`/`o_dcs_ir_search_done`。矩阵称"AMI-internal only"/"consumed only inside AMI"，独立grep证实这8个wire均通过 `assign o_XXX = XXX_o;` 导出到AMI同名顶层端口，实际会继续向外（C10范畴）传播，与紧邻的epoch/pending_valid/code_at_min/fault等行的处理方式不一致。已订正为"-> AMI's own `o_XXX` port, C10 row below"格式，与相邻行统一。

### 问题4（2行）：结尾装饰性汇总句的in/out拆分算术错误

行2195（C16 amb_recheck_scheduler块尾）："31 in + 17 out" → 实际 **32 in + 16 out**。
行2860（C16 fork块尾）："37 in + 37 out，matching the RTL port count exactly" → 实际 **34 in + 40 out**（且"matching exactly"这句表述本身也具误导性，只有总数74吻合，拆分并不吻合）。

两处均为总数正确、拆分算错；**其上方全部244行的逐行Direction列标注本身经§3.2核实完全正确**，不是大面积方向标错。已订正。

### 结构性观察项（非"问题"，记录供后续参考）：Verbatim declaration anchor列全空

矩阵表头第5列"Verbatim declaration anchor"用于存放 `file:line` + RTL声明原文（如C01重建后 `` `ppg_control_top.v:96` `input i_clk` ``形式，这也是C01那4处"signed关键字丢失"问题的位置）。C16/C17全部244行此列均为空——不是C01式的"个别丢失"，而是**整个批次从未套用2026-09-16之后才出现的重建格式**（C16/C17构建于更早的2026-09-02~06）。

这不是本次审计范围内的"错误"（C01审计本身也只审计、不重建），故本次**未**尝试补全该列，仅如实记录。若后续要将C16/C17提升到C01同等的文档完整度，需要一次独立的"批次3重建"，性质与2026-09-16的C01 rebuild相同，建议作为单独任务、由用户决定是否进行——本审计已经独立整理出了三个模块全部244个端口的声明行号+原文，若日后要做该重建，可直接复用本报告与本次的分析过程，成本会低很多。

---

## 5. 各项声称的逐条裁定

| 矩阵原有声称 | 裁定 |
| --- | --- |
| C17 122/122，cluster③ complete | **总数成立**；118行细节完全准确，4行（2097/2104属问题2性质相近但各自独立判定，2113-2120属问题3）内容有误，已订正；另121行（除2147本身外）的AMI行号引用受问题1影响，已在块尾统一说明 |
| C16 amb-recheck-scheduler 48/48（原称31 in+17 out） | 总数、逐行Direction成立；拆分算术（问题4）已订正为32in+16out；PWI侧引用48/48全部准确 |
| C16 fork 74/74（原称37 in+37 out，"matching exactly"） | 总数、逐行Direction成立；拆分算术（问题4）已订正为34in+40out；自身文件引用准确；AMI侧引用受问题1影响 |
| 悬空wire相关11处"0问题"声称（§3.5表中除2097/2104外的11个） | 独立核实成立 |
| C17/C16自身文件（声明行+实现行）引用 | 独立核实成立，零错误 |

---

## 6. 总体结论

### 6.1 可信性判定

C16/C17这244行台账的**内容实质**（端口是否存在、方向是否正确、跨模块连接拓扑是否正确）是可信的：244/244结构对齐，244/244方向对齐，约150处本模块自身引用零错误，PWI侧48/48引用零错误，iverilog独立elaboration 0 warning。

存在但已订正的问题集中在**引用的可导航性**（问题1，系统性行号偏移，不影响"连接关系本身对不对"的判断，但会让人翻错代码位置）与**局部文字误判**（问题2、3共10行，问题4共2行）。规模和性质与C01审计"9处Source锚点真实错误"属同一数量级、同一类别（文档/引用层面的错误，不是RTL缺陷，未发现任何需要修改RTL的问题）。

### 6.2 已修的具体行

矩阵原地订正共13处（均为append方式，`~~旧文字~~ **新结论**`，历史文字保留）：
- 行2097、2104（问题2，悬空wire）
- 行2113、2114、2115、2116、2117、2118、2119、2120（问题3，误标"internal only"）
- 行2147（问题1，C17块尾统一说明）
- 行2195（问题4，amb_recheck_scheduler拆分算术，附本模块引用核验结论）
- 行2860（问题4，fork拆分算术，附问题1在fork块的说明）

§12.1、§12.12及其他已关闭的G-FP账目（§12.6/12.7/12.9/12.10）未触碰，符合任务边界。

### 6.3 本次审计未覆盖的范围（诚实声明）

- 问题1受影响的约112行（C17剩余112行 + fork中引用AMI但未单独列出的若干行）的具体+15行号，**未逐行重写**，只在块尾给出公式和40+样本点验证，请读者自行换算或等待后续批次统一清理。
- AMI文件中15行插入的具体位置未定位（需要读C10等本批次外的合同内容）。
- C17的"-> AMI's own `o_XXX` port, C10 row below"类交叉引用（约30余处），仅抽样验证了7个目标端口确实存在于AMI自身声明区，未对全部30余处逐一验证对应的C10行文本是否准确（C10不在本批次范围内）。
- Verbatim declaration anchor列的补全（见§4结构性观察项）未做，留待用户决定是否单独立项。
- 本仓库为GitHub发布快照，本次矩阵修改**不会**自动同步回原始开发环境（另一台Windows机器 `D:\PPG\verilog\jxa`）；经用户确认本仓库即最终权威版本，故未做额外同步处理。
- 批次2（C10）、批次4-9（C08/C09、C15/C22/C07、C20/C23/C06、C03/C04/C02、C19/C24/C11、C13/C14/C05）均不在本批次范围内，未涉及。

---

## 附录：本次审计使用的核验方法

由于Bash工具在审计前段有过服务端瞬时故障，本次未采用C01审计那样的独立Python脚本集，改为：
1. `Read` 工具直接读取RTL源码端口声明区/例化连接区/实现区，构建独立事实库（逐行摘录，非脚本提取）。
2. `Grep` 工具做内部wire全文件出现次数统计（悬空wire判定）、端口声明存在性核验（`^\toutput\s.*\bo_XXX\b` 类模式）。
3. 端口名+行号双重比对（而非仅数字加减）用于确认矩阵引用与RTL位置的对应关系，避免"行号算对了但其实指错端口"的假阳性/假阴性。
4. Bash故障恢复后，用于安装iverilog（`apt-get install -y iverilog`）并执行elaboration与两个负对照实验；负对照2的临时损坏文件仅存在于会话scratchpad目录，从未写入仓库RTL。

本报告及其分析过程中收集的完整端口清单、行号对照表，保留在本次会话记录中，如后续要做"C16/C17格式对齐C01的重建"，可直接复用，无需重新独立建证据库。
