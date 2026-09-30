# 合同补记批次3（第一阶段）：C18/C16/C23/C01/C08补记、连接核对表状态节、C15/C22核对（2026-10-01）

> 任务：“B下一批”第一阶段。只改`contracts/`下的`.md`，并新建本报告；不碰`rtl/`、`tools/`、`legacy/`，也不改`verification_reports/`里已有的报告。
> 工作树：克隆`D:\PPG\verilog\ppg_github_release`，开工时`main`与`origin/main`同为`95ff349`，工作区干净。
> 并行：“任务C”会话（tick-248 A/B、注入口补接、SID-05单元断言、P2S错拍仿真、PWC注释、全套回归）只改`rtl/`和它自己的报告。双方通过SendMessage协调提交。
> **本批不涉及**：tick-248截止事件相关文字（C08 §10.3开放项、C10 §11.3、FSC-50/AMI-14），P2S对齐（芯片顶层合同§8.4.5、C10 §6.7），矩阵§12.5补行或改锚。这些文字一个字未动（第6节word-diff可证）。
> 前两批：`CONTRACT_SYNC_SID05_20260930.md`、`CONTRACT_SYNC_BATCH2_20260930.md`。

## 1. 结论摘要

| 项 | 结果 |
| --- | --- |
| 1 C18 | V2.0 → **V2.1**：第4节参数表补`C_ENABLE_TEST_INJECTION`；新增第5.12节，补3个calibration-loss注入透传端口，口径与C10第6.5b节一致 |
| 2 C16 | V2 → **V2.1**：第9.3节表补`i_precision_takeover_safe`（原名`i_adc_idle`）和同样缺失的`i_peak_valley_idle`；第9.2节补RTL接管条件的准确六项形式 |
| 3 C15 | **无需修改**：8对诊断透传端口全部已在C15第11.3节表中，位宽和符号与RTL一致。批次2普查“只找到`o_stage1_raw`”是我当时只grep带反引号写法造成的误报 |
| 4 C22 | **无需修改**：第7.1节已逐句写明V1.4的峰间隔豁免只取决于“有无可靠前一波峰参照”，与RTL `:386`一致 |
| 5 C23 | 文件头补一条2026-09-17内容更新记录（PWC-41）；按C23自身“内容更新、标签不变”的惯例，规范标签仍为V2.6，引用它的合同都不需要改版本号 |
| 6 C01 | 新增**V1.17勘误**（规范标签仍为V1.10）：第6.2节补Top内部网`ssw_owner_q3_window_closed_o` |
| 7 C08 | V1.10 → **V1.11**：核实结果是第15.1节已规定代际规则，第10.4节只是公式漏写。因此在`owner_release`公式中补上代际项并交叉引用第15.1节，不新增规则 |
| 8 连接核对表 | 第8行状态单元格原地改写（原文保留在删除线内）；文件末尾追加第15节“后续状态”。原第1-420行编号不变，`TB_MAINTENANCE_20260930.md`对`:420`的引用仍然有效 |
| 版本联动 | C08被8份合同引用、C16被6份、C18被10份；这些依赖表以及矩阵§12.4/§12.4a/§12.4b全部原行更新，替换后grep旧版本号为0 |
| 重映射 | 全部合同改完后只做一次：共改写1109个数字（矩阵1039、别名表69、C02合同1）。其中1095个核对为新旧行文字相等，14个指向只改了版本号的依赖声明行 |
| 负对照 | 在副本中把3处引用各错改1行，校验器的`text_differs`从17变为20，恰好多出这3处 |
| word-diff | 计划外文字变动**0处**（原始工具输出中有6处“其它”，都是word-diff对齐方式造成的范围端点显示问题，逐行核实为纯数字变化，见第6节） |
| 矩阵行数 | 3920 → **3920** |

## 2. 各项改动及其RTL依据

行号均为本次开工时独立取得（grep端口名/线网名，逐一与声明、例化连接对照）。

### 2.1 C18 `PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md`（678 → 690行）

| RTL事实 | 位置 |
| --- | --- |
| 文件头：V1.4（2026-08-31）新增默认关闭的`C_ENABLE_TEST_INJECTION`，以及纯直通的`i_test_inject_enable`/`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready` | `ppg_precision_window_integration.v:27`、`:52` |
| `parameter integer C_ENABLE_TEST_INJECTION = 32'd0` | `:72` |
| 三个端口声明 | `:249-251` |
| 传给FIR例化：参数`:600`；端口`.i_test_inject_enable(i_test_inject_enable)`、`.i_test_calibration_loss_inject_valid(...)`、`.o_test_calibration_loss_inject_ready(...)` | `:600`、`:650-652` |
| 全文件除上述声明和例化连接外，没有其它使用 | grep |
| 接受、绑定、作用都在FIR内 | `ppg_coarse_detection_fir.v:312-315`、`:465-477` |

改动：
- 顶部新增V2.1修订记录；
- 第4节参数表新增一行；
- 新增“5.12 验证专用calibration-loss注入透传端口”：3行端口表，加一段说明（PWI只透传，不参与第6节fork或第9节接管；接受条件以C19和C10第6.5b节为准）。

### 2.2 C16 `PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md`（711 → 716行）

| RTL事实 | 位置 |
| --- | --- |
| amb_recheck V1.1（2026/08/23）：把`i_adc_idle`改名为`i_precision_takeover_safe`（纯改名，不改逻辑） | `ppg_amb_recheck_scheduler.v:26`、`:50` |
| `input i_precision_takeover_safe`（PWI原样转发AMI复合资格） | `:75` |
| 接管资格：`flag_takeover_safe = i_precision_takeover_safe && i_normal_fork_idle && i_idac_idle && i_fir_idle && i_peak_valley_idle && i_frame_safe_boundary` | `:179` |
| AMI复合资格：`flag_precision_takeover_safe = i_adc_idle && o_adc_chain_idle && o_normal_fork_idle && o_measurement_output_idle` | `ppg_adc_measurement_idac_integration.v:962` |
| PWI连接：`.i_precision_takeover_safe(i_precision_takeover_safe)`、`.i_fir_idle(flag_fir_idle_to_scheduler)`、`.i_peak_valley_idle(detector_idle_o)` | `ppg_precision_window_integration.v:996`、`:999`、`:1000` |
| `flag_fir_idle_to_scheduler`是寄存器，在WAIT_DRAIN阻止新输入后锁存“FIR与检测fork稳定排空” | `:299`、`:578-582` |

核对结论：C16全文确实既没有`i_adc_idle`，也没有`i_precision_takeover_safe`。第9.2节只写了“ADC、NORMAL fork、IDAC、FIR和帧边界全部排空”五项，笼统地用“ADC”指代这个输入，并且**漏掉了RTL中的第六项`i_peak_valley_idle`**。

改动：
- 顶部新增V2.1修订记录；
- 第9.3节表新增2行（`i_precision_takeover_safe`、`i_peak_valley_idle`）；
- 第9.2节新增一段，写出RTL的准确六项接管条件，并说明`i_fir_idle`在PWI内接的是锁存的`flag_fir_idle_to_scheduler`。

### 2.3 C15（核对，未修改）

- RTL：`ppg_adc_dc_recovery.v:22`文件头V1.1（2026/08/23）新增8对诊断透传端口。输入在`:93-100`，输出在`:138-145`。
- C15第11.3节表（本批修改前的快照中为第441-448行）逐项列出了`i_detect_code/o_detect_code`（9）、`i_stage1_raw/o_stage1_raw`（10）、`i_stage1_code_ext`（signed 11）、`i_stage2_raw`（10）、`i_stage2_code_ext`（signed 11）、`i_nominal_15_code`（signed 15）、`i_nominal_15_valid`（1）、`i_nominal_saturated`（1），位宽和符号与RTL逐一相符。
- 结论：无缺口。批次2普查只用带反引号的写法grep，而该表不带反引号，导致误报。本条订正批次2报告第8.2节的C15一行（批次2报告不修改，以本报告为准）。

### 2.4 C22（核对，未修改）

- RTL：`ppg_peak_valley_window_detector.v:27`文件头V1.4（2026/08/23）。从`flag_peak_interval_legal`中去掉笼统的`reacquire_search_active_o`豁免，只在`flag_previous_peak_valid==0`时豁免。代码为`:386`：`(flag_previous_peak_valid == 1'b0) || (帧差非负 && 帧差 >= i_min_peak_to_peak_frames)`。
- C22第7.1节（修改前快照第291行起）已写明：“这个豁免只取决于‘是否存在可靠的前一波峰参照’这一个条件……不得把它读成‘任意reacquire轮次的第一个候选一律豁免’……峰峰最小时间检查必须继续对其生效。”
- 结论：已覆盖。附带说明：RTL还要求帧差最高位为0（即帧差非负，`dec_peak_to_peak_frames[C_FRAME_ID_WIDTH-1]==0`），合同用`frame_delta(...)`表述，未单独点明回绕判断，本次不改。

### 2.5 C23 `PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md`（1028 → 1029行）

- 事实：
  - PWC-41位于C23第21节“自检验收矩阵”（修改前第953行），标注为“2026-09-17新增”；
  - 第6.2节、第17.1节早已规定新START不清历史sticky；
  - RTL修复点带`@satisfies: PWC-41`（`ppg_precision_window_controller.v:494`、`:511`）；
  - 依据报告为`verification_reports/PWC_STICKY_CLEAR_RTL_FIX_20260917.md`。
- 惯例：矩阵§12.4a对C23的记载是“V2.6 (normative label unchanged) | 2026-08-20 base; content updated by 2026-09-02”，即内容更新但不改标签。本次沿用这一惯例，规范标签仍为V2.6。
- 改动：在“V2.6 change record”之后插入一条“2026-09-17内容更新记录（2026-10-01补记）”（第3行版本头不动）；§12.4a的日期单元格改为“content updated by 2026-09-17”。
- PWC RTL文件头changelog缺这一条，按任务分工由任务C处理，本批未改。

### 2.6 C01 `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`（950 → 954行）

| RTL事实 | 位置 |
| --- | --- |
| `wire ssw_owner_q3_window_closed_o` | `ppg_control_top.v:602` |
| 调度器例化：`.i_owner_q3_window_closed(ssw_owner_q3_window_closed_o)` | `:941` |
| SSW例化：`.o_owner_q3_window_closed(ssw_owner_q3_window_closed_o)` | `:1076` |
| 该网只在上述3处出现 | grep |
| 生产者：SSW `assign o_owner_q3_window_closed = reg_owner_q3_closed_o \|\| flag_owner_q3_closed_combo` | `ppg_sar9_sar15_safe_selection_wrapper.v:489` |
| 消费者：调度器`flag_completion_success`的第4个与项 | `ppg_400hz_frame_calibration_scheduler.v:460` |

改动：
- 在V1.16之后追加V1.17勘误（2行）；
- 第6.2节“调度器输出→SSW输入”表之后的段落后面，新增一段写明这条反向（SSW→调度器）内部连线：唯一生产者、唯一消费者、只用于成功判定、不参与owner释放。

### 2.7 C08 `PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`（1250 → 1252行）

- RTL：`flag_completion_match = i_adc_transaction_complete_event && B_INFLIGHT && (i_adc_complete_sample_index == owner sample index) && (i_run_generation == owner generation)`（`:459`）。
- C08第15.1节原文：“The generation tag … A stale generation cannot match, release or rebind an owner.” 可见**规则早已规定**，只是第10.4节的`owner_release`公式没有写这一项，也没有指向第15.1节。
- 处理：在第10.4节公式末尾补一行`&& i_run_generation == current_owner_run_generation   // V1.11补记；代际规则见第15.1节`。原公式各行原样保留，未新增规则，也没有改第15.1节。公式里没有写出的`B_INFLIGHT`项，由“current_owner”本身的含义覆盖，本次不展开。
- 顶部新增V1.11修订记录。

### 2.8 `PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md`（420 → 430行，原第1-420行编号不变）

写入第15节之前，逐条自己核实：
- a) `rtl/ppg_control_top/ppg_control_top.v`存在，文件头`:30`为“2026/08/23 V1.0 Create file. First RTL implementation of contract C01 (V1.10)”；
- b) `legacy/rtl/ppg_system_integration/tb_ppg_scheduler_ssw_ami_integration.v`存在，由commit `50a2b88`（2026-09-30）移入。`legacy/README.md`第10行写明的原因是：14个08-17之后新增的输入未连接、JNT-08的`success==1`断言与合同矛盾、`$fopen`写死了原始开发树路径；
- c) `rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh`存在（文件头“JNT-01~09 Shared Baseline Prefix”）。`rtl/ppg_control_top/`下有14份TB `include`了它。

改动：
- 第8行状态单元格：`~~连接合同已完成；……最终顶层RTL尚未编写~~ 本表为control_top实现前的设计快照，后续状态见§15`；
- 文件末尾追加“## 15. 后续状态（2026-10-01补记）”，写入上述三项，并说明本表仍是矩阵§2所定的non-normative design reference，正文其它状态句（第47、345、412-414、420行）保持原样。
- 核对：修改前后第1-420行逐行比较，只有第8行不同。

## 3. 版本号联动清单（全部原行修改）

| 被引用合同 | 升版 | 引用它的合同依赖表（每份1处） | 矩阵 |
| --- | --- | --- | --- |
| C08 | V1.10→V1.11 | C01、C03、C06、C09、C10、C16、C24、C25（共8份） | §12.4的1处 + §12.4b的8处 |
| C18 | V2.0→V2.1 | C01、C08、C10、C15、C19、C20、C22、C23、C24、C25（共10份） | §12.4的1处 + §12.4b的10处 |
| C16 | V2→V2.1 | C08、C10、C17、C18、C23、C25（共6份） | §12.4的1处 + §12.4b的6处 |

- C25的写法以句号结尾（`V1.10.`、`V2.0.`、`V2.`），本次的替换模式已能覆盖。替换后按“文件名 + 旧版本号”grep，结果为0。
- §12.4a：C01、C08、C16、C18、C23五行的版本和日期单元格原行改写；§12.4的C08、C16、C18、C23、C01五行在Metadata source后追加移位说明；§12.4b前言末句追加一句。
- C01（勘误V1.17）和C23（内容更新）都保持原规范标签，引用它们的地方不改。
- 旁证：§12.4b中以C01、C08、C10、C16、C18、C23为源的binding共49条，逐条核对“源行确实声明了目标合同”，**49/49正确**。§12.4六个范围（C01:95-103、C08:56-64、C10:60-73、C16:14-18、C18:40-46、C23:35-39）都恰好覆盖依赖声明行；各合同第3行都是当前版本声明行。

## 4. 行号重映射

### 4.1 映射

改动前把`contracts/`下32份`.md`全部快照。上述7份文件和全部版本联动都改完之后，只做一次重映射（使用`difflib`相等块，原行内修改的行按1:1映射）。

| 合同 | 旧行 → 位移 | 原行内修改的旧行 |
| --- | --- | --- |
| C08 | 1-2 → 0；3-748 → +1；749起 → +2 | 60、61（依赖版本） |
| C10 | 全部 → 0 | 62、69、71（依赖版本） |
| C01 | 1-16 → 0；17-658 → +2；659起 → +4 | 96、98（依赖版本） |
| C16 | 1-2 → 0；3-430 → +1；431-440 → +3；441起 → +5 | 15（依赖版本） |
| C18 | 1-2 → 0；3-131 → +1；132-438 → +2；439起 → +12 | 45（依赖版本） |
| C23 | 1-4 → 0；5起 → +1 | 34、38（依赖版本） |

扫描器沿用批次2版本，覆盖`文件.md:NNN`、`Cxx:NNN`（含`Cxx:a-Cxx:b`和逗号列表）以及§12.5 C01行的裸`:NNN`；本批把`Cxx:`短写的适用范围扩展到C16、C18、C23。

**人工判定为章节号、未改的引用：**
- 沿用前批：`C10:2`、`C10:7, 10`、`C10:11.`；
- 本批新增：`C23:2`（矩阵1001、3268行；C23第2行是空行，对应第2节）、`C23:19`（3265行，对应第19节“顶层连接合同”，同格的`C01:6.2`也是节号）、`C16:8-13`（3217行，与`C17:10-12`并列，对应第8-13节）；
- 正则已识别的节号：`C18:5.7`、`C18:2-2.2`、`C23:8.4, 14.1, 14.2, 19`等。

**版本头保持为3：** `-> C08:3`、`-> C16:3`、`-> C18:3`（C16、C18的新记录恰好插在第3行）；`C23:3`、`C01:3`本身没有移位。

### 4.2 统计

| 文件 | 改写的数字 | 新旧行文字相等 | 指向只改了版本号的行 | 保留`:3` | 未变 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 矩阵（`文件.md:NNN`/`Cxx:NNN`） | 671 | 657 | 14 | 44 | 347 |
| 矩阵（裸`:NNN`） | 368 | 368 | 0 | 0 | 0 |
| 别名表 | 69 | 69 | 0 | 1 | 2 |
| C02合同 | 1 | 1 | 0 | 0 | 0 |
| **合计** | **1109** | **1095** | **14** | **45** | **349** |

按目标合同统计改写数：C01 691（含裸引用368）、C08 132、C16 131、C23 130、C18 25。

“指向只改了版本号的行”的14个数字（另有3个C10的同类引用，因C10不移位而数值未变）全部是§12.4/§12.4b中的依赖声明行：矩阵1005、1215、1220、1284、1291、1299、1301、1306各行。

### 4.3 负对照（保险1）

把`contracts/`复制到临时目录，在副本矩阵中把3个引用各加1（1个`Cxx:NNN`、1个`文件.md:NNN`、1个裸`:NNN`），再用同一核对脚本检查副本。结果：`text_differs`从真实工作树的17变为**20**，恰好多出这3处，并能定位到被改的行；真实工作树未受影响。

### 4.4 最终独立核对（只读磁盘上的新旧文件）

| 检查 | 结果 |
| --- | --- |
| 引用逐条配对 | 通过 |
| 新行文字 == 旧行文字 | 1436（含未移位的引用） |
| 版本头保留`:3` | 50 |
| 章节号保持不变 | 34 |
| 文字不同的引用 | 17，全部是指向“只改了版本号”的依赖声明行（含3个数值未变的C10引用） |
| 引用区间外的数字变化 | 14处，全部是矩阵中的版本号（V1.10→V1.11、V2.0→V2.1） |
| 除数字外还有文字改动的矩阵行 | 1198、1205、1213、1215、1220、1236、1243、1251、1253、1258、1280（计划内11行）以及1291、1293、1300、1301、1306、1308（只因`V2`→`V2.1`多了“.1”） |

## 5. 观察项（只报告，未改）

1. **Top RTL changelog缺条目**：`ssw_owner_q3_window_closed_o`（`ppg_control_top.v:602/941/1076`）是2026-08-30 Bucket-1 RTL会话随调度器V1.8、SSW V1.9一起加入的，但`ppg_control_top.v`文件头changelog没有对应条目（V1.0 08/23之后直接是08/31的V1.2~V1.4）。这是RTL文件，本批不改，建议交给任务C或下一次RTL批次。
2. **C16第9.3节`i_fir_idle`的语义说明**（“FIR无待消费输出且当前沿未接收输入时为1”）描述的是FIR本身，而PWI实际送给重检调度器的是锁存后的`flag_fir_idle_to_scheduler`（FIR与检测fork稳定排空）。本批在第9.2节补充说明里写明了这一点，没有改原表行。
3. **C22 §7.1的回绕判断**：见第2.4节，只记录，不改。
4. **批次2普查的C15误报**：已在第2.3节订正。批次2普查中的其它“推定已覆盖”项，本批未重新核查。
5. 等待任务C的项（本批不动）：tick-248相关文字、P2S对齐、PWC RTL头注释。

## 6. word-diff核查（保险2）

`git diff --word-diff=porcelain --word-diff-regex='[A-Za-z0-9_.]+|[^[:space:]A-Za-z0-9_.]+'`，对`contracts/`下全部20份改动文件（矩阵、别名表、C02合同、6份正文编辑文件、11份只改版本号的合同）的每一对删除/新增词分类：

| 文件 | 数字（行号） | 计划内版本号 | 计划内矩阵行 | 正文编辑 | 其它 |
| --- | ---: | ---: | ---: | ---: | ---: |
| 矩阵 | 1032 | 28 | 18 | — | 6 → 逐行核实为纯数字，实际为**0** |
| 别名表 | 69 | 0 | — | — | 0 |
| C02合同 | 1 | 0 | — | — | 0 |
| 其余只改版本号的11份合同 | 0 | 每份1~3处 | — | — | 0 |
| C08、C01、C16、C18、C23、连接核对表 | — | 各1~2处 | — | 本批正文编辑 | 0 |

- 6处“其它”分别在矩阵997、3202、3599行，形如`858-860`→`860-862`。word-diff把中间的`860`当作共同词对齐，于是报告成“删`858-`、加`-862`”。逐行把数字替换为占位符后比较，这3行修改前后完全一致，只有数字不同；这些数字也都已由第4.4节逐条核对。
- 对6份正文编辑文件逐行比对：没有删除任何行；所有原行内修改只删掉了版本号中被替换的那一位数字（`V1.10`→`V1.11`、`V2.0`→`V2.1`中的“0”），其余全部是插入。连接核对表第8行的原文保留在删除线中。

## 7. 协调与提交

- 开工时用ListAgents确认任务C会话（“PPG项目全套回归重跑基线”），用SendMessage告知本批范围。对方回复只改`rtl/`和自己的报告，并请本批先不写tick-248/P2S相关文字，本批已照办。
- 提交前再次ListAgents/SendMessage，`git pull --rebase`后，只`git add`本批改动的`contracts/*.md`和本报告。
- 第二阶段（tick-248与P2S相关文字、按任务C的行号映射重映射RTL/TB引用）等任务C推送后另行进行，届时在本报告后续节或新报告中记录。
