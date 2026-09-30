# SID-05新增端口/连线的合同补记（2026-09-30）

> 任务：把2026-09-18 SID-05修复在RTL里新增的端口和连线补记进接口合同。只改`contracts/`下的`.md`并新建本报告；
> 未改动`rtl/`下任何文件（RTL、TB、脚本、filelist），也未改动`verification_reports/`里的已有报告。
> 工作树：`xinyanbaiqi/zlcx`的本地克隆`D:\PPG\verilog\ppg_github_release`，开工时`main`与`origin/main`同为`e769a67`。
> 原始开发树`D:\PPG\verilog\jxa`既未作为依据，也未写入。

## 1. 结论摘要

| 项 | 结果 |
| --- | --- |
| C08 | V1.8 → **V1.9**：第13.9节端口表新增`o_cal_owner_deadline_event`；第10.3节新增截止回报规则和1条开放观察项；第9.1节末段原行补一句实现说明；顶部新增V1.9修订记录 |
| C10 | V2.1 → **V2.2**：第6.6节端口表新增`i_cal_owner_deadline_event`，表后说明原行补全；第11.3节新增在途标志清零条件和“重新发起同一候选”的行为说明；顶部新增V2.2修订记录 |
| C01 | 新增**V1.15勘误**（按本合同惯例，规范标签仍为V1.10）：第6.3节校准请求行原行补记内部连线，并新增一段说明；不新增Top端口 |
| 连接核对表 | **不补**（理由见第2.4节） |
| 版本联动 | 17份合同的依赖表共改24处，矩阵§12.4、§12.4a、§12.4b共改29处；全部为原行内修改 |
| 行号重映射 | 合同行号引用共**1160个数字**被改写（矩阵1135个、别名表24个、C02合同1个）：1154个核对为“新行文字 = 旧行文字”，其余6个指向本次原行修改的行（逐个说明见第4.4节）；另有27个版本头`:3`按人工判断保留；矩阵行数**3920 → 3920** |
| 矩阵§12.5 | 未插行；C08、C10、C01三个端口台账块末尾的原行各追加一句说明 |
| 第6项清点 | 3份合同最后修订日之后，RTL里还有5个端口和2处行为改动没写进合同（第6节）；另有1个RTL开放观察项、3个TB未接新端口，需要用户裁定 |

## 2. 各合同改动及其依据的RTL事实

### 2.1 依据的RTL事实（全部独立重新取得）

取法：先按名字grep，再用skill自带的formatter-AST（`scripts/python/quality/formatter_ast.py`的`build_ast_report_for_path`）交叉核对端口/线网声明行和例化区间。

| RTL事实 | 位置 | 取证方式 |
| --- | --- | --- |
| 调度器输出声明`output o_cal_owner_deadline_event` | `rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v:189` | grep + AST（`direction=output, line 189`） |
| 源信号`wire flag_cal_owner_deadline`声明 | 同文件`:355` | AST（`kind=wire, line 355`） |
| 源信号赋值：`B_FRAME_ACTIVE && 帧模式==CAL && B_CAL_WAVE_PENDING && !B_INFLIGHT && calibration_local_tick_o >= C_CAL_OWNER_DEADLINE` | 同文件`:467`；`C_CAL_OWNER_DEADLINE = 248`在`:74` | grep |
| `assign o_cal_owner_deadline_event = flag_cal_owner_deadline;` | 同文件`:567` | grep |
| 截止处理分支`if(adc_owner_commit_event_o == 1'b0)`中：撤销`B_CAL_WAVE_PENDING`、置`B_OWNER_DEADLINE_TIMEOUT` | 同文件`:736`、`:747-750` | 读代码 |
| 请求载荷在波形fire时被消费（`B_CAL_REQ_PENDING`清零） | 同文件`:657-660` | 读代码 |
| `calibration_sample_ready_o`的校准段资格（`B_CAL_REQ_ACTIVE`、CAL帧、`!B_CAL_WAVE_PENDING`、`!B_INFLIGHT`） | 同文件`:429-432` | 读代码 |
| 状态向量异步复位全零 | 同文件`:878` | 读代码 |
| AMI输入声明`input i_cal_owner_deadline_event` | `rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:153` | grep + AST（`direction=input, line 153`） |
| `flag_calibration_request_inflight`更新块：复位；STOP/abort/阻断；`flag_amb_sample_accepted \|\| flag_dcs_sample_accepted \|\| i_cal_owner_deadline_event`清零；`calibration_request_fire_o`置位 | 同文件`:1791-1802`（新增条件在`:1797-1798`） | 读代码；该输入在AMI内部只有`:1797`这一个消费点（grep） |
| 校准请求仲裁的四个寄存器块（valid/颜色/类型/reason，valid与在途同为0时按重检优先于启动搜索重新锁存） | 同文件`:1357-1410` | 读代码 |
| Top内部网`wire sched_cal_owner_deadline_event_o` | `rtl/ppg_control_top/ppg_control_top.v:553` | grep + AST（`kind=wire, line 553`） |
| 调度器例化端口连接`.o_cal_owner_deadline_event(sched_cal_owner_deadline_event_o)` | 同文件`:963`，位于AST给出的`ppg_400hz_frame_calibration_scheduler_Inst`区间`862-977`内 | grep + AST |
| AMI例化端口连接`.i_cal_owner_deadline_event(sched_cal_owner_deadline_event_o)` | 同文件`:1151`，位于AMI例化区间`1097-1378`内 | grep + AST |
| 该内部网只有上面3处出现，无其它扇出，也不是Top端口 | 全文件grep | grep |
| SSW校准owner窗口`i_calibration_local_tick <= C_CAL_OWNER_DEADLINE`（含248） | `rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v:413` | grep（用于第7.1节开放观察项） |

用任务说明里的“约”行号逐一对照，`:189`、`:567`、`:467`、`:153`、`:1797`、`:553`、`:963`、`:1151`全部与实测一致。

### 2.2 C08 `PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`（1240 → 1246行）

1. **顶部V1.9修订记录**（新第3行，照V1.8那一条的写法）：新增了什么、为什么（截止抑制从未回报AMI，AMI在途标志永久为1，搜索永久卡死）、本次改了哪几节、不改变什么（owner截止数值248、sticky的非阻断属性、RED/IR截止283/443、FSC-01~57）、真实证据（见第2.5节）。
2. **第9.1节末段**（原行追加，不插行）：原文写的是“ADC owner未在tick 248前提交时，调度器不得再次消费上游请求，原请求保留并重试”。这与RTL不一致：请求载荷在波形fire时就已被消费（`:657-660`），调度器侧并不保留原请求。补记的实现说明是：这种情形下由`o_cal_owner_deadline_event`触发AMI重新握手同一候选；这次重新握手不是新的样本请求，不扩增样本数。原文字未删改。
3. **第10.3节末尾**（新增4行）：
   - “校准owner截止回报（V1.9补记，SID-05）”一段：按RTL逐项写清赋值式、源信号的与项、纯组合且不以`flag_lifecycle_active`门控；何时为1；恰好1个2 MHz周期，在`B_CAL_WAVE_PENDING`清零的同一时钟沿回落；复位值0；不分配`sample_index`、不建立owner、不产生完成、不进阻断汇总；唯一消费者；AMI重新握手的路径（`:429-432`）及跨宏帧保留。
   - “开放观察项（未裁定，暂不作规范要求）”一段：见第7.1节。
4. **第13.9节端口表**：`o_owner_deadline_timeout_sticky`之后新增一行（与RTL端口声明顺序一致），写明方向、位宽、复位值、生产者、唯一消费者和时序语义。

### 2.3 C10 `PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md`（1325 → 1329行）

1. **顶部V2.2修订记录**（新第3行）。
2. **第6.6节端口表**：`i_calibration_sample_ready`之后新增`i_cal_owner_deadline_event`一行。
3. **第6.6节表后说明**（原行修改）：原句“wrapper必须保存请求类型、颜色和原因，直到匹配的AMB_CAL或DCS_CAL结果被IDAC控制器真实消费”后补一句：“若调度器以`i_cal_owner_deadline_event`报告该请求已被owner截止抑制，在途所有权同样释放”。
4. **第11.3节末尾**（新增2行）：按RTL写出`flag_calibration_request_inflight`的完整更新优先级；解释新增的第3项清零条件；说明清零后的下一拍按当时有效的请求来源重新拉高`o_calibration_sample_valid`，由于没有结果被消费、IDAC搜索没有推进，重新发起的就是同一个候选；`reg_inflight_*`不随截止事件清除；在途为1期间valid恒为0，不会与本侧握手同拍冲突。

### 2.4 C01 `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`（937 → 941行）

1. **V1.15勘误**：C01把勘误按时间顺序追加在V1.14之后（用`>`空行分隔），这次沿用这一惯例（新增2行）。按文件自带的supersession条款，V1.11~V1.14都是非规范勘误，规范标签一直是V1.10（V1.11/V1.12新增了Top端口，也照此处理）。这次只是一条内部连线，同样只加勘误，**规范标签保持V1.10**，因此其它合同对C01的依赖版本不变。
2. **第6.3节“AMI状态回授”表**：`o_calibration_sample_valid`和全部请求载荷那一行（原行追加）补上“调度器`o_cal_owner_deadline_event`经Top内部网`sched_cal_owner_deadline_event_o`回连AMI `i_cal_owner_deadline_event`（V1.15勘误，非Top端口）”。
3. **第6.3节**：在“顶层只直连AMI与Scheduler的保持型校准请求接口……”那段之后新增一段（2行），写明连线路径、`ppg_control_top.v:553/963/1151`，以及唯一生产者/唯一消费者、不得扇出到SSW/supervisor/配置管理器/Top输出。

**`PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md`：判断为不补。**
- 矩阵§2把它列为non-normative design reference。
- 它停在V1.3（2026-08-17），核对范围是它自己第14节写明的“七条指定主连接”（波形上下文、ADC事务、owner commit、完成旁带、START边界、两路故障）。整条校准请求通道（`o_calibration_sample_valid/ready`等）本来就不在这七条里（全文grep `calibration_sample`为0）。
- 只给这一条新线补一行，会造出一个“核对表覆盖了校准通道”的假象。而且它的“核对结果”列要求真实核对过，我这次没有在它的框架下做核对。
- 该连线的权威描述已写进C01第6.3节以及C08、C10。如果以后要让这份核对表覆盖校准请求通道，应整条通道一起补。该文件没有被任何文件按行号引用，将来补行不会引起行号漂移。

### 2.5 修订记录引用的真实证据

- `verification_reports/WORKLINE_D_SID05_SID06_20260918.md`（根因、A/B trace、修法）。
- `rtl/ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v` V1.2：SID-05-DCR（`task_verify_deadline_suppression`调用在`:1214`）、SID-05-DCIR截止抑制后恢复断言；iverilog与Vivado 2022.2 xsim均为`STARTUP_IDAC_CALIBRATION_TB_PASS result_captures=2`，83 PASS / 0 FAIL。
- 同一报告的“2026-09-19补充”：全套19个TB的xsim系统级回归19/19 PASS、0 FAIL，合计1208 PASS。
- 本次没有重跑任何仿真，以上数字均引自该报告。

## 3. 版本号联动清单

所有改动都在原行内完成，没有新增行。

| 位置 | 改动 |
| --- | --- |
| C03 `PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md` | C10 V2.1→V2.2；C08 V1.8→V1.9 |
| C06 `PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md` | C08 V1.8→V1.9；C10 V2.1→V2.2 |
| C08（自身依赖表） | C10 V2.1→V2.2 |
| C09 `PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` | C08→V1.9；C10→V2.2 |
| C10（自身依赖表） | C08 V1.8→V1.9 |
| C11 / C12 / C13 / C14 / C15 | C10 V2.1→V2.2（各1处） |
| C16 `PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md` | C08→V1.9；C10→V2.2 |
| C17 / C18 / C23 | C10 V2.1→V2.2（各1处） |
| C24 `PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md` | C08→V1.9；C10→V2.2 |
| C25 `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md` | C08→V1.9；C10→V2.2 |
| C01依赖表 | C08→V1.9；C10→V2.2 |
| 矩阵§12.4总表 | C08行“V1.8; Scheduler”→“V1.9; Scheduler”；C10行“V2.1; AMI”→“V2.2; AMI”；三行的Metadata source列各追加一句移位说明 |
| 矩阵§12.4a | C08、C10的版本/日期单元格改为V1.9/V2.2及2026-09-30；C01单元格的“V1.11/V1.12/V1.13 … errata through 2026-09-02”改为“V1.11-V1.15 … errata through 2026-09-30”（顺带补上原先漏写的V1.14） |
| 矩阵§12.4b | 24条binding的声明版本（C08被8份合同引用、C10被16份合同引用），与§12.4b自己记录的citer数一致；前言段末原行追加一句说明（仍为141/141一致） |

- 匹配规则只认`ppg_system_integration/<合同>.md` V…这种当前依赖声明。历史列表不在匹配范围内，例如C01:109-110、连接核对表:28-31（分别引用V1.3/V1.3.4/V1.3.3）。
- 矩阵§2的权威表（第130-155行）只有ID、路径和职责，没有版本号，无需改动。
- **§12.4a的SHA-256摘要没有重算。** 本次修改前实测C01-C25共25个合同摘要，只有C04/C05/C12/C13/C21这5个与当时文件的原始字节一致，其余本来就已过期；§12.4a自己的前言也写明“任何后续修改都会使该基线失效，直到重新生成清单”。

## 4. 行号重映射

### 4.1 旧行号→新行号映射

映射取法：`difflib.SequenceMatcher`对比本次修改前的快照和修改后的文件，按“相等块”逐行建立映射；原行内修改的行按1:1映射，并单独标出。结果是分段的固定位移：

| 合同 | 旧行区间 → 位移 | 原行内修改的旧行 |
| --- | --- | --- |
| C08 | 1-2 → +0；3-725 → +1；726-977 → +5；978-1240 → +6 | 57（依赖版本）、534（第9.1节末段） |
| C10 | 1-2 → +0；3-479 → +1；480-985 → +2；986-1325 → +4 | 60（依赖版本）、487（第6.6节表后说明） |
| C01 | 1-12 → +0；13-672 → +2；673-937 → +4 | 92、93（依赖版本）、654（第6.3节校准请求行） |

### 4.2 受影响的引用统计

| 文件 | 改写的数字 | 其中文字逐条相等 | 指向本次原行修改行 | 保留`:3`（版本头） |
| --- | ---: | ---: | ---: | ---: |
| `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md`（`文件.md:NNN`与`Cxx:NNN`两种写法） | 767 | 763 | 4 | 27 |
| 同上，§12.5 C01台账行里裸写的`` `:NNN` ``（184行，每行1个删除线旧值+1个“当前”值） | 368 | 366 | 2 | 0 |
| `contracts/PPG_ALIAS_MAPPING_TABLE.md` | 24 | 24 | 0 | 0 |
| `contracts/ppg_system_config_manager_semantic_contract.md` | 1 | 1 | 0 | 0 |
| **合计** | **1160** | **1154** | **6** | **27** |

- 矩阵有701行在原行内被修改（`git diff --numstat`：701+/701-），**`wc -l`修改前后都是3920**。别名表和C02合同的行数也没变（570、395）。
- **给用户报数时说的是“782处”，最终是1160个数字，差别有两处来源：**
  1. 报数后才发现§12.5 C01台账行里还有一种写法：`` `…md:NNN`<br>~~`:NNN`~~ **当前`:NNN`** ``，后两个是不带文件名的裸`:NNN`，文件由同一单元格前面的路径决定。这类共368个，全部指向C01，已用同一映射改写并逐条核对。删除线旧值也按规则重映射，保证它与同一格里已重映射的原始引用继续一致、仍指向同一段文字。
  2. 统计口径不同：“782”数的是引用条目，这里数的是数字；一个范围算两个数字。
- **中途发现并纠正的一处扫描器错误（如实记录）。** 第一版扫描器把`C01:3, C01:87-C01:95`里的`, C01:87`吞进了前一个引用，导致：
  - `87`、`53`（C08）、`58`（C10）这3个范围起点没有改写，`95`、`61`、`71`被当成单个引用；
  - `C01:22-30, C08:1240`里的`C08:1240`被漏扫；
  - `C10:7, 10`、`C10:11.`这3个节号被误当行号改写。

  发现后，把矩阵、别名表和C02合同从修改前快照恢复，重新做了§12.4版本联动，用修正后的扫描器整体重跑。第4.3节的最终核对只基于磁盘上的新旧文件，不依赖重映射脚本自己的日志。

### 4.3 逐条验证方法与结果

独立核对脚本从磁盘重新扫描修改前快照和修改后文件，把引用逐条配对（行号和合同必须一一对应，数量必须相等），然后做三项检查。结果：

| 检查 | 结果 |
| --- | --- |
| 新行号上的合同文字 == 旧行号上的合同文字 | 1161个数字相等（含未变化的） |
| 只允许是本次原行修改的行（文字差异仅为版本号或追加的说明） | 6个 |
| 版本头`C08:3`/`C10:3`按人工判断保留为3 | 27个 |
| 节号引用（`C01:6.3-6.4`、`C10:6.9`、`C10:6.3a`、`C10:2`、`C10:7, 10`、`C10:11.`等）保持不变 | 12个数字 |
| 修改前后每一行的所有数字变化都落在已识别的引用区间内 | 例外只有26处，恰好是§12.4/§12.4b的26个版本号改动（V1.8→V1.9、V2.1→V2.2） |
| 除数字外还有文字改动的矩阵行 | 恰好是本次有意修改的10行：1198、1205、1207、1236、1243、1245、1280、1571、1924、3189 |

### 4.4 人工判断项（映射不上，或不宜机械映射）

1. **版本头引用`-> C08:3`、`-> C10:3`（§12.4b，共24处：8+16），以及§12.4的`C08:3`、`C10:3`和别名表:105的`C08:3`（3处），合计27处。** 它们表示“当前版本声明所在行”。新的V1.9/V2.2记录正好插在第3行，所以保留`:3`，与2026-08-30 V1.8插入时的做法一致。`C01:3`本来就不受影响。
2. **指向本次原行修改行的6个数字**，按位置映射：
   - §12.4b的`C01:92/93`→`94/95`、`C08:57`→`58`、`C10:60`→`61`（依赖版本行，文字只差版本号）；
   - 矩阵第1385、1386行（§12.5 C01台账`o_calibration_sample_ready`、`o_calibration_sample_valid`两行）的“当前`:654`”→`:656`（C01第6.3节校准请求行，本次只在行尾追加内容）。
3. **跨过插入点的4个范围**：`C10:198-610`（两处）→`199-612`，`C10:419-570`（两处）→`420-572`。两端各自映射后，范围自然把C10第6.6节新增的端口行包进来，语义正确。
4. **以整数形式写出的节号**：`C10:2`（矩阵1001、3268行，C10第2行是空行，对应“第2节 依赖”）、`C10:7, 10`（3216行，对应第7节owner、第10节DC恢复fork）、`C10:11.`（3397行，对应第11节校准请求仲裁）。均判为节号，不改。

### 4.5 本来就已过期的引用（照规则重映射，未顺手修复）

**A. 能确定过期的（11处）**

- **矩阵§12.4b C01行的9个依赖声明行号**：`C01:87`…`C01:95`（本次→`89`…`97`）。C01依赖表的实际声明行，修改前是89-97（本次后是91-99）。原因是2026-09-05 V1.14勘误又在文件头插了2行，而§12.4b在09-02核对后没再更新。所以每个binding都错指到上一个依赖或表头。例如`[C01:90 -> C08:3]`原本指向的是C02声明行。
- **矩阵§12.4 C01行的`C01:87-C01:95`**：同一原因，本次→`89-97`。我在该行说明里追加了一句“pre-existing +2 drift … left uncorrected”，数字本身没有改正。
- **矩阵§12.4 C08行**（附带说明）：本次→`54-62`，这是正确的。C08的依赖表从`:54`到`:62`，恰好9行。

**B. 台账自己已经用删除线/“当前”标为过期的（370处，仅供知悉）**

§12.5 C01块的184行里，原始引用`…md:NNN`（186个）和删除线`~~:NNN~~`（184个）是09-16重建时刻意保留的旧值，同一格里有“当前”值给出正确位置。本次三者一起重映射，相对关系不变。

**C. 启发式可疑（332处，未逐条人工确认，只列出供后续批次审计参考）**

判据：对§12.5端口台账行，检查该行“Formal port”列的端口名是否出现在所引合同行上；引用的是标题行时，检查整个节。按“旧行→新行”分组如下（后两列为引用数和所在矩阵行范围）。

这里混有三种情况：
- **真实行号漂移**：例如C10`:242`、`:304`、`:309`、`:337`等指向空行或代码围栏行，C10`:368`指向表格分隔行。
- **按设计的组锚点**：例如C01`:215`是“顶层还应输出……”这句概括。
- **合同本身没列出该端口的内容缺口**：例如C10`:527` 6.8节、`:549` 6.9节里查不到的配置/诊断端口，属于G-FP-01已知缺口。

要区分这三种情况需要逐行人工判断，这属于工作线C批次2（C10）/批次4（C08）等审计的范围。本次按规则不修。

| 合同 | 旧→新 | 旧行文字（截断） | 引用数 | 矩阵行 |
| --- | --- | --- | ---: | --- |
| C01 | `:73`→`:75` | > 历史顶层、旧时序核、旧草案和旧handoff | 1 | 1453 |
| C01 | `:202`→`:204` | V4 SPI源域快照与提交事件 … | 1 | 1450 |
| C01 | `:204`→`:206` | 已同步START、STOP、诊断清除和`control_abort` … | 1 | 1452 |
| C01 | `:205`→`:207` | ADC物理接口 … | 4 | 1507-1510 |
| C01 | `:206`→`:208` | 正式结果消费者ready … | 1 | 1511 |
| C01 | `:207`→`:209` | 验证专用异常注入 … | 4 | 1512-1545 |
| C01 | `:213`→`:215` | 模拟顶层输出只能原样来自SSW … | 26 | 1469-1494 |
| C01 | `:215`→`:217` | 顶层还应输出AMI正式测量结果 … | 47 | 1454-1543 |
| C01 | `:279`→`:281` | `o_measurement_result_discard_event` / `reason` / … | 8 | 1547-1554 |
| C01 | `:280`→`:282` | `o_detection_discard_event` / `reason` / … | 13 | 1556-1568 |
| C08 | `:929`→`:934` | ### 13.7 SSW owner资格和物理完成接口（`i_owner_q3_window_closed`，见第6节） | 1 | 1890 |
| C08 | `:1014`→`:1020` | ### 15.1 V1.4 generation and supervisor fault ports | 6 | 1919-1924 |
| C10 | `:97`→`:98` | 10. `ppg_precision_window_integration`。 | 1 | 3120 |
| C10 | `:105`→`:106` | 不得在TB中使用行为模型 … | 1 | 3122 |
| C10 | `:139`→`:140` | ppg_adc_s1_programmable_calibrator | 1 | 3121 |
| C10 | `:140`/`:141`/`:143`→`:141`/`:142`/`:144` | 代码块内的框图字符 | 3 | 2621-2623 |
| C10 | `:242`→`:243` | （空行） | 1 | 2619 |
| C10 | `:243`→`:244` | AMI input / Width / PWI direct consumer … | 1 | 2620 |
| C10 | `:262`→`:263` | ### 6.3 ADC结果事务owner输入 | 13 | 2640-3128 |
| C10 | `:304`/`:309`/`:311`/`:327`/`:337`/`:343`/`:393`→各+1 | （空行） | 7 | 2624-2633 |
| C10 | `:308`→`:309` | ADC结果事务上下文 / 调度器到AMI … | 1 | 2627 |
| C10 | `:312`→`:313` | ### 6.4 ADC异步物理结果输入 | 1 | 2635 |
| C10 | `:336`/`:344`→`:337`/`:345` | 代码围栏行 | 2 | 2631、2634 |
| C10 | `:368`→`:369` | 表格分隔行`--- / ---: / ---` | 15 | 3167-3181 |
| C10 | `:394`→`:395` | V1.3.4必须严格区分上述 … | 1 | 2625 |
| C10 | `:527`→`:529` | ### 6.8 配置输入 | 20 | 2197-2216 |
| C10 | `:549`→`:551` | ### 6.9 IDAC、精度和诊断输出 | 23 | 2243-2266 |
| C10 | `:565`→`:567` | PWI fine-window, recheck and detector diagnostics … | 14 | 2466-2479 |
| C10 | `:569`→`:571` | ### 6.10 V1.5 retained-transaction, injection and fault ports | 2 | 2217-2218 |
| C10 | `:623`→`:625` | ### 6.11 AMI local fault-record arbitration | 1 | 3182 |
| C10 | `:743`→`:745` | ## 7. 唯一ADC结果owner合同 | 39 | 3129-3188 |
| C10 | `:811`→`:813` | ## 8. Stage1、router和NORMAL fork连接 | 9 | 2646-2666 |
| C10 | `:818`→`:820` | ### 8.2 S1可编程校准 | 35 | 2665-2757 |
| C10 | `:823`→`:825` | ### 8.3 router互斥路由 | 24 | 2762-2786 |
| C10 | `:840`→`:842` | ### 8.4 NORMAL双分支 | 2 | 2761-2765 |
| C10 | `:955`→`:957` | ## 11. 校准请求仲裁 | 2 | 2759-2760 |

其余约81个非台账引用（§11、§12.2/12.3、§12.8、§12.10等行文里的引用）无法机械判断是否过期，本次只重映射，未评估。

### 4.6 未改动的引用

- `verification_reports/`里的旧报告：带日期的历史记录，按要求不改。
- `tools/cross_reference_tools/reconciliation_report.json`、`reconciliation_report.md`、`reconciliation_report_verify_pvw_pwc_fir.json`、`prose_staleness_scanner_report.json`：这些是脚本生成的产物（矩阵§13明确写“任何人工修改前必须重新运行脚本”），里面约110个对这三份合同的行号引用本次**没有改**，下次重跑生成脚本时会刷新。
- RTL/TB文件里没有对这三份合同的行号引用（已扫描`rtl/`下全部`.v/.vh/.sh`等文件）。

## 5. 矩阵修改前后行数与§12.5处理

- `wc -l contracts/PPG_CONTRACT_CLOSURE_MATRIX.md`：修改前**3920**，修改后**3920**。CRLF行尾保持不变（全文件`\r\n`计数等于`\n`计数）。
- §12.5未插行。三个台账块末尾的原行各追加一句说明（都写在该行最后一个单元格内）：
  - C08块最后一行（矩阵第1924行，`o_scheduler_fault_run_generation`）：“SID-05新增端口`o_cal_owner_deadline_event` … 尚未入账；为避免插行导致矩阵行号漂移，留待G-FP-01批次4（C08）审计时统一补行。”
  - C10台账末尾汇总行（矩阵第3189行，“Final disposition of AMI's remaining genuinely-unclaimable ports”那条note）：同样写法，留待批次2（C10）。
  - C01块最后一行（矩阵第1571行，`o_s2_raw`）：说明SID-05没有新增Top端口，只新增内部网，本台账按端口入账所以不单独成行；以后若决定为内部网建条目再统一补。
- 别名表里引用矩阵行号的地方没有动：矩阵行数不变，它们不会失效。

## 6. 顺带清点（只报告，未改）

### 6.1 各合同最后修订日之后，RTL changelog里尚未写进合同的改动

| 合同（最后修订） | RTL条目 | 内容 | 合同现状 |
| --- | --- | --- | --- |
| C08（V1.8，2026-08-30） | 调度器RTL | 08-30之后只有V1.8（09-18，SID-05），本次已补 | — |
| C08（同上，附带发现） | C08 V1.8自己新增的输入`i_owner_q3_window_closed` | 只出现在顶部V1.8修订记录里 | **第13.7节端口表没有这一行**；调度器RTL头部changelog也没有对应条目（端口本身已在RTL中）。矩阵第1890行把它锚在`### 13.7`标题上 |
| C10（V2.1，2026-08-20） | AMI V1.13（08-31） | 新增`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready` | C10全文无这两个端口 |
| C10 | AMI V1.14（09-05） | 新增`o_s1_calibration_applied`/`o_s1_raw`/`o_s2_raw`（P2S遥测透传，依据P2S集成合同§8.4.5） | C10全文无这三个端口 |
| C10 | AMI V1.11（08-23）STOP命中在途owner时的排空死锁修复（`flag_stop_result_draining`的置位条件）；V1.12（08-24）LFA-08 abort释放条件修复（`flag_adc_completion_abort_release`不再要求`flag_s1_detect_valid`） | 行为改动 | C10没有出现这两个内部标志名；第13节文字是否已覆盖这两处修复后的行为，本次**没有逐句核对** |
| C10 | AMI V1.4/V1.5/V1.9/V1.10（08-22~08-23） | changelog自述是按第6.10/6.11/6.5b/15.2节实现 | 属于先有合同后实现，视为已覆盖 |
| C10 | AMI V1.6（system-fault discard并入abort discard）、V1.7（内部wire改名）、V1.8（重构器诊断透传接入DC恢复实例） | 内部接线或行为改动；后两项对应C18、C15的端口 | C10未单独描述；属于内部层次，影响有限，列出备查 |
| C01（V1.10，2026-08-20；勘误至V1.14，09-05） | Top V1.2（08-31） | 新增Top端口`i_test_calibration_loss_inject_valid`/`o_test_calibration_loss_inject_ready` | C01全文无这两个端口 |
| C01 | Top V1.5（09-05） | 新增Top输出`o_s1_calibration_applied`/`o_s1_raw`/`o_s2_raw` | C01全文无；矩阵§12.5已有“C01无覆盖；依据`ppg_control_top.v:68`与P2S集成合同§8.4.5”行 |
| C01 | Top V1.3/V1.4（08-31） | `o_active_precision_mode`、`o_source_config_update_ready` | 已由V1.11/V1.12勘误写入第4.2节 |
| C01 | Top V1.0/V1.1（08-23/24） | 首版实现和声明顺序修正 | 无接口影响 |

### 6.2 这个新端口要不要在合同自检表里加一条

先按“新ID前先查矩阵§13”的规则查过，**没有新建任何ID**。

- **C08（FSC表）**：FSC-50“校准owner截止：local tick 248前提交；失败时安全收尾并重试同一校准请求”已经把“重试”写成验收要求。SID-05修复正是让这条要求在系统里真正成立，所以语义上不需要新ID。
  - 需要注意：调度器单元TB并没有接这个端口，FSC-50的“重试”半句在单元层面无法单独检查（重试要靠AMI配合）。系统级证据在C25的SID-05（`tb_ppg_control_top_startup_idac_calibration.v`）。
  - **建议方案（二选一，待定）**：
    - (a) 原行修订FSC-50的验收文字，补上“截止拍输出`o_cal_owner_deadline_event`单周期脉冲”；
    - (b) 新增一条模块级ID。但FSC-58/59已被调度器TB（`tb_ppg_400hz_frame_calibration_scheduler.v` V1.5，08-24）使用，而C08第18节表只列到FSC-57（这本身也是一处合同滞后）。所以新号只能从**FSC-60**起，并且要先把FSC-58/59补进表里。

    我倾向(a)。
- **C10（AMI表）**：**AMI-14“启动AMB搜索：请求只握手一次，匹配结果消费后才允许下一请求”在V2.2下已不完整**：截止事件也会释放在途、允许重新握手。
  - **建议方案**：
    - (a) 原行修订AMI-14，补上“或调度器报告owner截止抑制后，重新握手同一候选”；
    - (b) 新增一条ID。C10表目前到AMI-54，但C10顶部V1.4状态行写着“AMI-46至AMI-55”、验收范围又写“AMI-01至AMI-54”，编号本身有歧义。若新增，应先澄清AMI-55，再从AMI-55或AMI-56起编。

    我倾向(a)。

  两处都属于修改验收条款，未经用户确认不改。

## 7. RTL与TB观察项（不是文档问题，未改，请用户裁定）

### 7.1 【RTL开放观察项】截止事件没有做“同拍owner提交”屏蔽

- 调度器内部的截止处理在`if(adc_owner_commit_event_o == 1'b0)`分支里（`:736`、`:747-750`），而`o_cal_owner_deadline_event = flag_cal_owner_deadline`（`:567`）直接转发、没有这层屏蔽。
- SSW的校准owner窗口是`i_calibration_local_tick <= 248`（`ppg_sar9_sar15_safe_selection_wrapper.v:413`，含248），调度器截止判据是`>= 248`（`:467`）。所以在local tick恰好为248、校准owner恰好在这一拍真实提交时，两者会同拍为1。这时：
  1. 调度器按正常提交处理：消费`B_CAL_WAVE_PENDING`、置`B_INFLIGHT`，不置超时；
  2. 同一拍仍向AMI输出截止事件，AMI清掉`flag_calibration_request_inflight`，而这笔校准事务其实在途；
  3. 下一拍起AMI按仍然有效的请求来源重新拉高`o_calibration_sample_valid`。调度器要等`B_INFLIGHT`释放后才接受（`:429-432`），所以原事务的结果返回时，AMI的`flag_calibration_result_match`（要求在途为1，AMI `:941`）可能落空，按合同第11.3节作为“不匹配结果”处理（消费、不更新搜索、置协议诊断）；也可能与重新握手后的新请求错配。
- 这是**静态读码结论，未经仿真确认**。可达性取决于物理ADC/SSW的owner ready是否可能恰好在local tick 248拍变为1。SID-05本身处理的正是“ADC晚于预期才idle”这类场景，因此不能排除。
- 合同处理：C08第10.3节把这一点写成“开放观察项，裁定前不列为规范行为”，没有替RTL背书。
- 建议下一步（需用户决定）：用一个scratch TB在tick 248拍放开`i_adc_physical_idle`做一次真实A/B仿真确认。若确认，修法大概率是把端口改成`flag_cal_owner_deadline && !adc_owner_commit_event_o`，与内部截止分支同一门控。**未改RTL。**

### 7.2 【TB】三个直接例化调度器/AMI的TB都没有连接新端口

| TB | 情况 |
| --- | --- |
| `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v` | 例化调度器，未连`o_cal_owner_deadline_event` |
| `rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v` | 例化AMI，`i_cal_owner_deadline_event`悬空（并行会话“PPG项目全套回归重跑基线”告知：xelab与iverilog都对此报了警告） |
| `rtl/ppg_system_integration/tb_ppg_scheduler_ssw_ami_integration.v`（JNT联合TB） | 同时例化两者，但两端都没连。联合TB里调度器的截止事件到不了AMI，所以联合层面仍是修复前的行为 |

只有`ppg_control_top.v`真正连了这条线，因此目前只有Top层TB（含SID-05用的`tb_ppg_control_top_startup_idac_calibration.v`）能覆盖修复后的行为。同一并行会话还告知：调度器单元TB也没连08-30新增的`i_owner_q3_window_closed`，导致FSC-15 FAIL。这些都记在对方的回归报告里，本次未改TB。

### 7.3 其它

C01 §12.4a和§12.4b的C01依赖行号漂移（第4.5节A）：本次按要求只重映射、未修正。建议在下一次G-FP-07复核时统一订正为`C01:91-99`（本次之后的实际位置）。
