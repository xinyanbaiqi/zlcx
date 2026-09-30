# 合同补记批次2：C08/C10/C01端口补记、C01依赖行号订正、矩阵两处台账订正、合同同步普查（2026-09-30）

> 任务：“B：合同补记（与tick-248无关的部分）”。只改`contracts/`下的`.md`，并新建本报告；未改动`rtl/`、`tools/`、`legacy/`、`README.md`、`.gitignore`，也未改`verification_reports/`里已有的报告。
> 工作树为克隆`D:\PPG\verilog\ppg_github_release`，开工时fetch到的`main`为`ba1c90e`。同一时间“PPG项目全套回归重跑基线”会话在做“A：TB维护”，双方通过SendMessage协调提交顺序。
> 按要求**排除**：`o_cal_owner_deadline_event`/`i_cal_owner_deadline_event`的时序说明、C08中tick-248开放观察项、FSC-50/AMI-14的原行修订。这些文字本次一个字都没动（第6节word-diff核查可证）。
> 上一批记录：`verification_reports/CONTRACT_SYNC_SID05_20260930.md`。

## 1. 结论摘要

| 项 | 结果 |
| --- | --- |
| C08 | V1.9 → **V1.10**：第13.7节端口表补`i_owner_q3_window_closed`；第10.4节补写成功判定的Q3门控 |
| C10 | V2.2 → **V2.3**：第6.5b节补`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready`及其行为说明；第6.7节补`o_s1_calibration_applied`、`o_s1_raw[9:0]`、`o_s2_raw[9:0]`（字段定义交叉引用芯片顶层合同§8.4.5） |
| C01 | **V1.16勘误**（规范标签仍为V1.10）：同样5个Top边界端口分别写进第4.1、4.2、4.3、6.7节，写法与既有identity/invalid注入组（TOP-21~24）一致 |
| 版本联动 | C08被8份合同引用，C10被16份合同引用；这些合同的依赖表以及矩阵§12.4/§12.4a/§12.4b全部在原行更新 |
| 行号重映射（三份合同全部改完后只做一次） | 共改写1160个数字：矩阵1133个、别名表26个、C02合同1个；逐条核对后全部与原引用文字一致或属于计划内情形（第4节） |
| 负对照 | 在临时副本里人为把3处引用各错改1行，校验器报出且只报出这3处，之后才采信它的“全部通过” |
| word-diff核查 | 矩阵、别名表和其它合同中，除行号数字、计划内版本号、第4/5项订正和台账汇总行追加说明外，**0处**其它文字变动 |
| 第4项（C01依赖行号） | 重映射完成后单独订正：§12.4b的9个binding和§12.4的范围改为`C01:93-C01:101`，9/9逐条验证确实指向C01依赖表中声明对应合同的那一行 |
| 第5项 | 矩阵2185行、2196行独立复核后确认原说法有误，已在原行追加订正（`~~旧~~ **新**`） |
| 矩阵行数 | 3920 → **3920** |
| 新发现的RTL问题（未改） | P2S三个遥测端口取自正式结果fork之前的DC恢复载荷，在结果侧反压时可能与`o_result_*`不是同一笔事务（第7.1节） |

## 2. 各合同改动及其依据的RTL事实

所有语义逐句对照RTL写成。行号均为本次独立取得：先按名字grep，AMI的例化区间再用skill的formatter-AST（`build_ast_report_for_path`）核对。

### 2.1 C08 `PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`（1246 → 1250行）

| RTL事实 | 位置 |
| --- | --- |
| `input i_owner_q3_window_closed` | `ppg_400hz_frame_calibration_scheduler.v:163` |
| `assign flag_completion_match = i_adc_transaction_complete_event && B_INFLIGHT && sample_index相等 && i_run_generation相等`（不含Q3项） | `:459` |
| `assign flag_completion_success = flag_completion_match && i_adc_transaction_success && !B_INFLIGHT_DISCARD && i_owner_q3_window_closed` | `:460` |
| `flag_completion_success`唯一消费点：NORMAL事务置`B_RED_DONE`/`B_IR_DONE` | `:714-719` |
| `success==0 && !DISCARD`才置`B_FRAME_FAILED` | `:720-721` |
| 生产者：SSW `assign o_owner_q3_window_closed = reg_owner_q3_closed_o \|\| flag_owner_q3_closed_combo`（按owner保持，owner释放或新owner建立时复位） | `ppg_sar9_sar15_safe_selection_wrapper.v:488-489`、`:526-532` |
| Top连接：内部网`ssw_owner_q3_window_closed_o` | `ppg_control_top.v:602`、`:941`（调度器）、`:1076`（SSW） |

改动：
1. 顶部新增V1.10修订记录（第3行）。
2. **第10.4节**（“完成和owner释放”）末尾新增一段。原文“匹配完成且`success=1`：释放当前物理owner，并允许……进入成功处理”没有提到这项门控，这次补上：
   - `i_owner_q3_window_closed`只影响成功判定，不影响owner释放；
   - `flag_completion_success`在调度器内只有NORMAL事务一个消费点；
   - `success=1`但Q3窗口未关闭时，owner照常释放、不置颜色完成位、也不置`B_FRAME_FAILED`，因此该NORMAL宏帧得不到完整成功的完成事件。
3. **第13.7节端口表**：在`i_adc_complete_sample_index`之后新增一行（与RTL声明顺序一致）。

### 2.2 C10 `PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md`（1329 → 1337行）

| RTL事实 | 位置 |
| --- | --- |
| `input i_test_calibration_loss_inject_valid` / `output o_test_calibration_loss_inject_ready` | `ppg_adc_measurement_idac_integration.v:398-399` |
| 两者在PWI例化处原样直连 | `:2615-2616`（在AST给出的`ppg_precision_window_integration_Inst`区间2446-2617内） |
| AMI送给PWI的`i_test_inject_enable = flag_test_inject_effective = (C_ENABLE_TEST_INJECTION != 0) && i_test_inject_enable` | `:908`、`:2614`；参数透传`:2461` |
| PWI原样直通到FIR | `ppg_precision_window_integration.v:651-652` |
| FIR：ready为`(C_ENABLE_TEST_INJECTION != 0) && i_test_inject_enable && i_rstn && !armed`；fire为ready再加valid；命中下一笔被接纳样本时强制该样本不合格；绑定寄存器在命中、历史清空或复位时撤销 | `ppg_coarse_detection_fir.v:312-315`、`:465-477` |
| `output o_s1_calibration_applied`、`output [9:0] o_s1_raw`、`output [9:0] o_s2_raw` | `ppg_adc_measurement_idac_integration.v:403-405` |
| 赋值：`o_s1_calibration_applied = flag_dc_s1_calibration_applied`；`o_s1_raw = dec_dc_stage1_raw`；`o_s2_raw = dec_dc_stage2_raw` | `:1029-1031` |
| 来源：DC恢复实例的`o_calibration_applied`/`o_stage1_raw`/`o_stage2_raw` | `:2278`、`:2299`、`:2301`（位于`ppg_adc_dc_recovery_Inst`区间2214-2306内） |
| 正式输出`o_result_*`/`o_calibrated_s1_value`取自fork寄存器`reg_result_fork_payload`的解包，不是上面的直通线 | `:961`、`:1744-1748` |

改动：
1. 顶部新增V2.3修订记录。
2. **第6.5b节端口表**新增2行，节末新增一段calibration-loss注入说明：AMI既不解释也不门控，原样直通PWI和FIR；在FIR中的接受条件、绑定和作用；`C_ENABLE_TEST_INJECTION=0`时ready恒为0、valid被忽略；不受本节第3条双请求互斥约束。
3. **第6.7节端口表**新增3行。字段用途交叉引用芯片顶层合同§8.4.5，没有另写一份定义。表格行只写AMI侧可由RTL证实的事实：这三个端口直接转发DC恢复实例的输出，不是本表其余“本笔”字段所用的fork载荷；同拍关系指向本报告第7.1节。

### 2.3 C01 `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`（941 → 950行）

| RTL事实 | 位置 |
| --- | --- |
| `input i_test_calibration_loss_inject_valid` | `ppg_control_top.v:135` |
| `output o_test_calibration_loss_inject_ready` | `:242` |
| `output o_s1_calibration_applied`、`output [9:0] o_s1_raw`、`output [9:0] o_s2_raw` | `:292-294` |
| AMI例化连接：`.i_test_calibration_loss_inject_valid(i_test_calibration_loss_inject_valid)`、`.o_test_calibration_loss_inject_ready(ami_…_o)`、`.o_s1_*(ami_s1_*_o)` | `:1372-1377` |
| 边界赋值 | `:1551`、`:1601-1603` |
| Top的`flag_test_inject_effective = C_ENABLE_TEST_INJECTION && flag_test_inject_mode_latched`送AMI `i_test_inject_enable` | `:398`、`:1364` |

改动（均为V1.16勘误，沿用C01把勘误追加在V1.15之后的惯例）：
- §4.1输入组表中“验证专用异常注入”那一行，原行补记新请求输入。
- §4.2验证专用ready返回代码块新增1行，并新增P2S三个输出一段（逐位直连AMI，字段定义交叉引用芯片顶层合同§8.4.5）。
- §4.3验证组端口表新增2行，并在原句上补充两处：请求输入由三个变为四个、第三个ready同样为0。
- §6.7注入连接表新增2行。

写法与既有TOP-21~24注入组保持一致：同一张表、同样的方向列和语义措辞。RTL核实结果：当`C_ENABLE_TEST_INJECTION=0`、有效使能为0或`i_rstn=0`时，FIR的ready恒为0。

### 2.4 本次没有改的相关项

- C08/C10里SID-05截止事件的全部描述、C08 tick-248开放观察项、FSC-50、AMI-14：按任务要求排除。
- 芯片顶层合同§8.4.5本身：不在本次修改范围内，但它对`s1_calibration_applied`来源的描述与RTL不一致（见第7.1节）。

## 3. 版本号联动清单（全部原行修改）

| 位置 | 改动 |
| --- | --- |
| C01依赖表 | C08 V1.9→V1.10；C10 V2.2→V2.3 |
| C03、C06、C09、C16、C24 | C08→V1.10；C10→V2.3（各2处） |
| C25 | C08→V1.10；C10→V2.3。这两行以句号结尾（`V1.9.`），通用匹配漏掉了它们，已单独处理并复查 |
| C08自身依赖表 | C10→V2.3 |
| C10自身依赖表 | C08→V1.10 |
| C11、C12、C13、C14、C15、C17、C18、C23 | C10→V2.3（各1处） |
| 矩阵§12.4 | C08行“V1.10; Scheduler”、C10行“V2.3; AMI”；C08、C10两行的Metadata source追加移位说明（C01行的说明随第5节订正） |
| 矩阵§12.4a | C01/C08/C10三行的版本与日期单元格 |
| 矩阵§12.4b | 24条binding的声明版本（C08被8份合同引用，C10被16份）；前言末句追加说明 |

C01按其supersession条款只追加勘误V1.16，规范标签仍为V1.10，因此其它合同中“C01 V1.10”的引用都不需要改。

## 4. 行号重映射

### 4.1 映射

改动前把`contracts/`下32份`.md`全部快照。**三份合同和全部版本联动都改完之后，只做了一次重映射。** 用`difflib`的相等块逐行建立映射；原行内修改的行按1:1映射并单独标出。得到的分段位移如下：

| 合同 | 旧行区间 → 位移 | 原行内修改的旧行 |
| --- | --- | --- |
| C08 | 1-2 → +0；3-756 → +1；757-951 → +3；952-1246 → +4 | 58（依赖版本） |
| C10 | 1-2 → +0；3-422 → +1；423-459 → +3；460-523 → +5；524-1329 → +8 | 61（依赖版本） |
| C01 | 1-14 → +0；15-224 → +2；225-229 → +4；230-263 → +5；264-768 → +7；769-941 → +9 | 94、95（依赖版本）、209（§4.1注入行）、284、292（§4.3两句） |

扫描器沿用上一批修正后的版本，覆盖三种写法：`文件.md:NNN`、`Cxx:NNN`（含`Cxx:a-Cxx:b`和逗号列表），以及§12.5 C01台账里裸写的`` `:NNN` ``（按同一单元格前面的文件路径定位）。`C10:2`、`C10:7, 10`、`C10:11.`仍按章节号处理，不改。

### 4.2 统计

| 文件 | 改写的数字 | 其中新旧行文字相等 | 指向本次原行修改行 | 保留`:3`（版本头） | 未变（引用落在插入点之前） |
| --- | ---: | ---: | ---: | ---: | ---: |
| 矩阵（`文件.md:NNN`/`Cxx:NNN`） | 765 | 757 | 8 | 26 | 7 |
| 矩阵（裸`:NNN`，184个删除线旧值+184个“当前”值） | 368 | 368 | 0 | 0 | 0 |
| 别名表 | 26 | 26 | 0 | 1 | 0 |
| C02合同 | 1 | 1 | 0 | 0 | 0 |
| **合计** | **1160** | **1152** | **8** | **27** | **7** |

指向原行修改行的8个数字，都是同一行在行尾追加内容后的原位：

| 矩阵行 | 引用 | 说明 |
| --- | --- | --- |
| 1284 | `C01:94`→`96`、`C01:95`→`97` | 依赖版本行；随后又被第5节订正覆盖 |
| 1291 | `C08:58`→`59` | 依赖版本行 |
| 1293 | `C10:61`→`62` | 依赖版本行 |
| 1512、1513、1544、1545 | `C01:209`→`211` | 即C01 §4.1“验证专用异常注入”行，本次只在行尾追加 |

版本头引用`-> C08:3`、`-> C10:3`以及别名表:105的`C08:3`保持3不变：新的V1.10/V2.3记录正好插在第3行，已核对第3行确为当前版本记录。

### 4.3 保险1：负对照

脚本`negctl`把`contracts/`整体复制到临时目录，在副本矩阵中人为把3个引用各加1（选的都是“下一行文字不同”的位置）：
- 1个`Cxx:NNN`：第1284行`C01:91→92`；
- 1个`文件.md:NNN`：第1322行；
- 1个裸`:NNN`：第1322行。

然后用同一个核对脚本检查这个副本。结果：`text_differs`从真实工作树的8变为**11，恰好多出这3处**，且逐条定位到被改的行；工作树本身未受影响。之后才采信它对真实工作树给出的“全部一致”。

### 4.4 最终独立核对（只基于磁盘上的新旧文件）

| 检查 | 结果 |
| --- | --- |
| 引用逐条配对（行号、合同一一对应，数量相等） | 通过 |
| 新行文字 == 旧行文字 | 1150个（含7个落在插入点之前、数值未变的引用） |
| 版本头保留`:3` | 27个 |
| 章节号保持不变 | 12个数字 |
| 文字不同的引用 | 17个 = 第5节有意订正的11个数字（9个binding + §12.4范围两端） + 6个指向原行修改行（1291、1293、1512、1513、1544、1545） |
| 引用区间之外的数字变化 | 24处，全部是版本号（另有2处落在已有文字改动的行上） |
| 除数字外还有文字改动的矩阵行 | 恰好是计划内的11行：1198、1205、1207、1236、1243、1245、1280、1571、2185、2196、3189 |

## 5. 修正既有过期引用（第4项，与重映射分开）

背景：上一批报告已查明，矩阵§12.4、§12.4b中C01依赖声明的行号自2026-09-05 V1.14勘误起就偏了2行，当时按规则只做了重映射。上一批结束时它们是`C01:89-97`（已偏2）；本次重映射按V1.16插入的+2把它们移到`91-99`，仍然偏2。本次先完成全部编辑和重映射，**然后**单独订正：

- 方法：不套+2，而是逐个binding按其目标合同，在C01中查找声明该合同的那一行（`| Cxx — \``开头），用该行号替换。
- §12.4b的C01行：

  | 目标合同 | 订正前 | 订正后 |
  | --- | --- | --- |
  | C04 | 91 | 93 |
  | C02 | 92 | 94 |
  | C03 | 93 | 95 |
  | C08 | 94 | 96 |
  | C10 | 95 | 97 |
  | C18 | 96 | 98 |
  | C09 | 97 | 99 |
  | C07 | 98 | 100 |
  | C24 | 99 | 101 |

- §12.4的C01行：`C01:91-C01:99` → `C01:93-C01:101`；原说明“pre-existing +2 drift … left uncorrected”改为删除线，并追加订正说明。
- **验证**：从磁盘重新读取，9/9个binding所指的C01行都以`| <目标合同> — \``开头、且含该合同文件名；§12.4范围恰好覆盖9行依赖声明。
- **旁证**：用同一方法检查§12.4b中所有以C01、C08、C10为源的binding，共32条（9+9+14），全部正确；C08范围`55-63`、C10范围`60-73`也恰好覆盖各自的依赖声明行。

## 6. 第5项：矩阵两处台账内容订正（先独立复核，原行追加，不插行）

**矩阵2185行（C16块，`o_calibration_precision_mode`）。** 原文说它经PWI `:1019`“-> same AMI-level arbitration”。复核结果：
- `ppg_amb_recheck_scheduler.v:211`硬连`1'b0`；
- PWI在`:1019`接入，并由`:458`转发到自身输出`o_calibration_precision_mode`；
- AMI例化PWI时该输出**留空**：`ppg_adc_measurement_idac_integration.v:2564` `.o_calibration_precision_mode()`，AST确认位于PWI例化区间2446-2617内；
- AMI自己的`o_calibration_precision_mode`在`:1021`硬连`1'b0`。

结论：这是悬空输出，不进入AMI校准请求仲裁。已把原句划删除线，并追加订正。

**矩阵2196行（C10块，`i_idac_mode`）。** 原文说“This whole 20-port group is exclusively wired to C17”。复核方法：对AMI“IDAC配置接口”横幅下的20个端口（`:202-221`，`i_idac_mode`…`i_dcs_confirm_count`）逐一grep，统计C17例化区间2309-2443之外的使用。结果：
- `i_idac_mode`：C17（`:2331`）+ PWI例化`:2513` + AMI自身资格判定`:918-920`；
- `i_amb_enable`：C17（`:2332`）+ PWI例化`:2514`；
- `i_dcs_enable`：C17（`:2333`）+ PWI例化`:2515`；
- 以上三个在PWI内经`ppg_precision_window_integration.v:988-990`送入AMB重检调度器；
- 其余17个端口在C17例化之外没有任何使用。

结论：该句对3个端口不成立，与附录四会话的发现一致。已划删除线并追加订正。另外说明：同组的`i_amb_recheck_interval_frames`（矩阵2216行）不在该横幅组内（声明于`:271`），其行已正确写明消费者是PWI，无需订正。该行里“raw passthrough at `:2316`”这个行号本身也已过期（实际为`:2331`），不属于本项，只记录，不改。

## 7. RTL与文档观察项（只报告，未改）

### 7.1 【RTL/设计开放观察项】P2S三个遥测端口不在正式结果的原子载荷内

**事实（均来自RTL）：**
- `o_result_frame_id`、`o_calibrated_s1_value`等全部正式输出，都解包自fork寄存器`reg_result_fork_payload`（AMI `:961`）。该寄存器只在`flag_dc_result_transfer`时装入`enc_dc_result_payload`（`:1744-1748`），并一直保持到正式输出被消费。
- `o_s1_calibration_applied`/`o_s1_raw`/`o_s2_raw`则直接取自fork**之前**的DC恢复实例输出（`:1029-1031` ← `:2278/:2299/:2301`）。它们对应DC恢复内部的`payload_o`，而`payload_o`在**每次输入握手**时都会被覆盖（`ppg_adc_dc_recovery.v:355-356`）。
- fork载荷里其实有同一个Stage1资格字段：`:961`解包出的`flag_unused_output_calibration`，它来自`enc_dc_result_payload`中的`flag_dc_s1_calibration_applied`。`stage1_raw`/`stage2_raw`则根本不在fork载荷中。

**后果：** 事务N交给fork后，DC恢复就可以接纳事务N+1。如果此时正式输出还没被消费（例如片外P2S打包器的深度2缓冲已满而反压），这三个端口已经显示N+1，而`o_result_*`仍是N。P2S打包器在N的握手沿采样，就会把N+1的原始码打进N的包里。

**与合同的关系：**
- 芯片顶层合同§8.4.5写`s1_calibration_applied`来自“AMI内部result fork payload第949行解包出的`flag_unused_output_calibration`……同源同拍，不存在错位风险”。这描述的是fork解包的那个字段，而RTL（AMI V1.14）实际导出的是fork之前的`flag_dc_s1_calibration_applied`。
- 对`stage1_raw`/`stage2_raw`，§8.4.5只写到DC恢复的原子载荷，没有说明它与fork之后结果之间的对齐。
- AMI端口注释“与frame_id/sample_index/coarse/fine结果同一原子载荷锁存”，就端口输出的时间关系而言不成立。

**可达性：** 需要在事务N被消费前，DC恢复已接纳N+1。正常节拍下（RED/IR结果相隔约80 us，P2S缓冲1~2拍就能接住）不会发生；但该合同§8.4.3自己也指出单包80.5 us已贴近80 us窗口。这是**静态读码结论，未经仿真确认**。

**可能的修法（供裁定，未实施）：**
- `o_s1_calibration_applied`改取`flag_unused_output_calibration`；
- 把`stage1_raw`/`stage2_raw`加入`enc_dc_result_payload`和fork解包。

C10第6.7节新增的三行已如实写明“取自DC恢复实例，不是fork载荷”，没有替RTL背书同拍关系。

### 7.2 【RTL文档缺口】PWC的09-17修复没有写进RTL头部changelog

`ppg_precision_window_controller.v`在2026-09-17修复了“新START清掉两个历史sticky”，代码处有`@satisfies: PWC-41`（`:494`、`:511`），C23的PWC-41也已在当天加入（C23第953行）。但RTL文件头仍是`V1.3 / 2026/08/23`，changelog里没有09-17这一条；C23加PWC-41时也没有在文件头写修订记录。

### 7.3 其它顺带发现

- C01没有记录Top内部网`ssw_owner_q3_window_closed_o`（SSW `o_owner_q3_window_closed` → 调度器`i_owner_q3_window_closed`，`ppg_control_top.v:602/941/1076`）。任务范围未包含，留下一批处理。
- C08第10.4节`owner_release`公式没有写`run_generation`匹配项（RTL `:459`有）；第15.1节另有代际规则。只记录。
- 矩阵§12.5 C01块1569-1571行的Source列“C01无覆盖”，以及注入端口对各行锚点所指的§4.1行，在C01 V1.16之后已不准确。本次按规则不改行，只在C01块末尾汇总行追加了说明，留待G-FP-01复核时改锚。C10块则在末尾汇总行注明P2S三端口尚未入账（calibration-loss端口对在C10块已有2624/2625两行）。
- TB侧：并行会话已在调度器单元TB把`o_cal_owner_deadline_event`接到观察wire，在AMI单元TB用初值0的reg驱动`i_cal_owner_deadline_event`，未加断言（见其`TB_MAINTENANCE_20260930`报告）。

## 8. 合同与RTL同步普查（C01/C08/C10之外；只报告，不修改）

方法：从本批修改前的快照中，取每份合同文件头（第一个`##`之前）出现的最晚日期作为最后修订日；对照映射到的RTL模块文件头changelog，列出更晚的条目，再逐条判断。RTL changelog明确写“per 合同 section X / 按合同X节”的，属于先有合同后实现，判为“推定已覆盖（未逐句核对）”。

### 8.1 任务点名的三项

| 项 | 结论 |
| --- | --- |
| PWC“新START清sticky”（09-17）→ C23 | **合同已覆盖**：C23第6.2/17.1节本来就要求新START不清sticky，PWC-41已于09-17加入C23验收表；RTL修复带`@satisfies: PWC-41`。遗留的是RTL文件头changelog缺条目，以及C23文件头缺修订记录（第7.2节） |
| SSW V1.5 AMB_CAL单相积分改造（09-10）→ C09 | **合同已覆盖**：C09 V1.10（2026-09-10）顶部修订记录、第6.4节“AMB_CAL单相积分改造”，以及第383、403行都已写明 |
| SPI诊断快照撕裂修复（09-14）→ 芯片顶层合同 | **合同已覆盖**：`ppg_spi_register_file.v` V1.3（2026/09/14）对应芯片顶层合同V1.15勘误（2026-09-14）；第7节CDC表和第8.1节“整体一次性捕获”的约束均在 |

### 8.2 其它合同

| 合同（最后修订） | 更晚的RTL changelog | 判断 |
| --- | --- | --- |
| C02（08-20） | 配置管理器V4.9（08-23）：1024-bit V4+V5 | 自述“bring RTL up to contract V4.9”，推定已覆盖 |
| C03/C04（08-20） | ACTIVE wrapper V1.6（08-23）：1024-bit、透传端口 | 同上，推定已覆盖 |
| C05（08-20） | 解包器V5（08-23） | 按合同，推定已覆盖 |
| C06（08-20） | 无直接对应的新条目（映射到的SSW条目归C09） | — |
| C07（08-20） | 无 | — |
| C09（09-10） | 无更晚条目 | — |
| C11（08-20） | 无 | — |
| C12/C13（08-20） | router V1.1、overlap V1.1（08-22）：`run_generation`、discard组、`o_local_empty` | 自述按C13第4.1节，推定已覆盖 |
| C14（08-20） | 无 | — |
| C15（08-20） | DC恢复V1.1（08-23）：8对诊断透传端口 | C15中能找到`o_stage1_raw`，其余7对**未逐项核对**，建议下一批核 |
| **C16（08-20）** | amb_recheck V1.1（08-23）：`i_adc_idle`改名为`i_precision_takeover_safe` | **可能缺口**：C16全文既没有`i_precision_takeover_safe`，也没有`i_adc_idle`，需要核对C16用什么名字描述该输入 |
| C16 | normal fork V2.0（08-22）：`run_generation`、discard组 | 按合同，推定已覆盖 |
| C17（08-30） | 无更晚条目 | — |
| **C18（08-20）** | PWI V1.4（08-31）：新增`C_ENABLE_TEST_INJECTION`参数和`i_test_inject_enable`/`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready`透传 | **确认缺口**：C18全文没有这三个端口，也没有这个参数 |
| C18 | PWI V1.1~V1.3（08-22/23） | 自述按合同5.x节，其中V1.3改名后的`i_precision_takeover_safe`在C18中可以找到；推定已覆盖 |
| C19（08-31） | 无更晚条目（V2.5已含PRC-09/10注入） | — |
| C20/C21（08-20） | 基线V1.1~V1.3（08-22/23，按第14.4节）、V1.4（08-27，仅字面量修饰） | 推定已覆盖 |
| C22（08-20） | 峰谷V1.1~V1.4（08-22/23） | V1.2“START不清sticky”已在C22第630、660行和PVW-37；V1.3按第3.2节；V1.4的峰间隔豁免**未逐句核对** |
| C23（08-20头部；内容09-17） | PWC V1.1~V1.3（08-22/23，按合同） | 推定已覆盖；09-17修复见8.1 |
| C24（08-20） | supervisor V1.0（08-23）首版实现 | 按合同实现 |
| C25 | 验证合同，没有单一RTL模块 | 未普查 |

**留给下一批文档任务的清单：**
1. C18补PWI的注入参数与端口透传；
2. 核对C16对`i_precision_takeover_safe`的称呼；
3. C15逐项核对8对诊断透传端口；
4. C22 V1.4峰间隔豁免逐句核对；
5. C23和PWC RTL补修订记录；
6. C01补`ssw_owner_q3_window_closed_o`内部连线；
7. 第7.1节P2S对齐问题的裁定（RTL改动或芯片顶层合同勘误）。

## 9. 保险2：word-diff核查结论

用`git diff --word-diff=porcelain`（按“字母数字串 / 非字母数字串”分词）检查`contracts/`下全部20份改动文件（矩阵、别名表、C02、C08、C10、C01及其余14份），并对每一对删除/新增的词分类：

| 文件 | 数字（行号） | 计划内版本号 | 计划内行 | 正文编辑 | 其它 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 矩阵 | 1133 | 28 | 21（落在11个计划内行上） | — | **0** |
| 别名表 | 26 | 0 | — | — | **0** |
| C02合同 | 1 | 0 | — | — | **0** |
| 其余14份合同 | 0 | 每份1~2处 | — | — | **0** |
| C08/C10/C01 | — | 各1~2处 | — | 本次正文编辑 | 另查（见下） |

对C08/C10/C01，另外逐行比对了所有原行修改的行：修改前的文字全部原样保留，只有插入（C01第209、284、292行）或版本号数字替换。第一次运行时正则写错，结果几乎为空；修正正则后重跑，才得到上表结果。

## 10. 协调与提交

- 开工、改动过程中和提交前都用ListAgents/SendMessage与“PPG项目全套回归重跑基线”会话协调。对方期间提交了TB和工具改动（`50a2b88`等），未触碰`contracts/`；对方工作区里未提交的TB改动我没有触碰。
- 只`git add`本批改动的`contracts/*.md`和本报告。
