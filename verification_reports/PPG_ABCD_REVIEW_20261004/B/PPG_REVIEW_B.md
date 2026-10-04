被审提交：`d18c6954621e53e5a6505dd3a6c688c266d23839`

# PPG 控制协议与生命周期专项 B

状态：B组主责审阅完成（2026-10-04）：7 RTL、13 TB、9合同，共29文件、30,592行；逐项94/94完成。缺陷未修复，全局回归与最终签核由A负责。只读、conservative。初始/最终字节核对见 evidence/baseline.json、final_baseline.json。

以下按批次保留调查过程；较早“待审/进行中”仅描述当时进度，以本段及最终 coverage.csv / handoff.md 为准。仍然有效的验证限制保留在各发现里。

19项发现：8 S1 RTL、7 S2 TB、4 S3合同/一致性，无新增风格编号。最需优先复核的内部协议问题是B-007（periodic deadline不能在当前RUN重试）和B-012（abort同拍DONE残留SSW owner，首次CONFIG可达，但新START不能提交新owner）。B-003默认连续NORMAL周期5001拍，B-006正式discard身份错指另一笔，B-008独立分支资格被提前清除，B-009 AMI START清历史，B-010取消同拍仍精度提交，B-005取消沿CAL上下文重建。各项的实际动态范围、反驳及恢复条件见对应条目。

本组文件审阅不等于RTL正确、TB全部通过或芯片签核。没有修改共享RTL/合同/TB，也没有启动全套/长回归。312个ID机械索引和14个family语义抽查完成；完整逐ID语义签核与全局锚点台账保持A主责。

快速索引：findings_index.csv（19项及真实源行）；file_coverage.csv（29文件）；coverage.csv（94检查项）；acceptance_coverage.csv（312明确定义ID）；protocol_table.md（逐拍协议）；evidence/final_trial_inventory.json（52次既有短试验，含无效setup及负对照，不能视作52份原TB）。

| 编号 | 层/分类 | 确认问题 |
|---|---|---|
| B-001 | S3 | watchdog非法参数未拒绝 |
| B-002 | S2 | 历史未clear的rearm前提未测 |
| B-003 | S1 | NORMAL宏帧5001拍 |
| B-004 | S2 | 周期容差及Q3固定资格掩盖错误 |
| B-005 | S1 | CAL末拍rollover覆盖abort |
| B-006 | S1 | formal discard身份取错fork |
| B-007 | S1 | periodic deadline只释放外层inflight |
| B-008 | S1 | measurement消费清除detection资格 |
| B-009 | S1 | AMI START清历史sticky |
| B-010 | S1 | PWC同拍discard仍commit及发事件 |
| B-011 | S2 | PWI尾部累计判据未使用 |
| B-012 | S1 | SSW abort同拍吞匹配完成 |
| B-013 | S2 | INJ互斥在ready不可能的窗口检查 |
| B-014 | S2 | RRC间隔只打印未比较 |
| B-015 | S2 | OIB stream缺无丢失及元数据比较 |
| B-016 | S2 | P06禁用未到达AMI输入 |
| B-017 | S3 | C18窗口长度直接消费者标错 |
| B-018 | S3 | 合同与TB同号场景语义错位 |
| B-019 | S3 | C09当前版本及依赖台账不一致 |

## 批次1：环境、scheduler协议骨架及supervisor

任务分类 analyze + validate。实际调用skill `analyze_existing_verilog`、formatter AST；七个RTL均ast_ok=true，产物在evidence/skill。原同版本strict门禁及独立lint逐文件复用，仿真与门禁分别解释。未调用verify/repair、未应用修复。主责29文件均与git show字节相等。

### B-001 — watchdog非法参数未按合同在elaboration拒绝

- S3 / 合同·RTL一致性。位置：C24合同第1节（41行）明确 `Elaboration shall reject ... COUNTER_WIDTH < $clog2(CYCLES + 1)`；RTL参数54-55行与191-192、433-450行无参数检查。
- 关键原文（2行）：`parameter integer C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH = 32'd13`；`flag_watchdog_timeout_fire = flag_watchdog_window_active && (cnt_adc_drain_watchdog == (C_ADC_DRAIN_WATCHDOG_CYCLES - 1))`。
- 实际证据：evidence/supervisor_invalid_width/compile.log与result.json，原模块TB仅把C_WD_WIDTH从4改1，C_WD_CYCLES仍8；Icarus 11.0 -g2012 -Wall编译rc=0，运行SUP06B FAIL（其余13 PASS）。不能达到7的1-bit计数器循环0/1，无超时故障。默认合法参数不受此结论影响。
- 反驳：Top默认5000/13合法、manager没有可变watchdog配置，故不扩大为默认芯片S1；所有共享RTL搜索未找到参数拒绝补偿，源为独立模块并承诺elaboration拒绝；不是已知风格或D03事项。置信度：仿真确认非法值接受，静态确认无guard。建议：由owner决定增加合法参数门禁或修改参数使用前提；不提供/应用修复。

### B-002 — SUP10A不能证明保留历史时episode重新开启，错误实现逃过原TB

- S2 / TB。位置：rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v:475-488。关键原文（3行）：
```text
// SUP-10：验证第二个独立episode（此前episode均已完整关闭+诊断清除，非同一episode延续）依然
// 完整触发abort/STOP/丢弃三事件并锁存全新快照——这是K02"episode开合独立于首故障快照历史，
check_case("SUP10A", (o_system_fault_blocking === 1'b1) &&
```
- 依据：C24第4节规定第二个独立故障在旧first-fault未diag_clear时仍发新trio且不覆盖旧snapshot；该TB在365-368、414-416、459-461清历史，SUP10A反而期待全新cause03。它验证了清历史后的新episode，没有构造历史仍valid的关键前提。
- 证据：evidence/supervisor_original/run.log真实14 PASS。仅把RTL第198行 `flag_new_any && !system_fault_blocking_o` 变成 `flag_new_any && !system_fault_cause_valid_o`（本组副本），evidence/supervisor_original_rearm_mutant仍14 PASS。补充TB保留cause01历史、等blocking关闭再发送cause02，evidence/supervisor_extended原RTL 6比较/0失败；同变异evidence/supervisor_extended_rearm_mutant BREARM FAIL、退出1。错误期望负对照evidence/supervisor_wrong_expected_negative也报SUP01A FAIL；原TB失败虽退出0，必须读取FAIL/计数。
- 反驳：本条不宣称原RTL错误；第198行原实现正确。系统级其他TB/K02证据仍须核对，不能从本条推断全系统完全没覆盖；本文件新增声明本身过强。不是F-001悬空输入问题。建议补保留历史的rearm比较并要求trio和旧snapshot同时成立；不修复。

### supervisor已核对及限制

已全文读取RTL465行、TB511行与合同161行。reset覆盖全部寄存器；三路记录与watchdog快照优先级正确，identity_valid=0时所有身份字段归零；summary仅bit0..8，reserved位保持0；历史不被episode-close清除。无组合反馈、无ready/完成/owner释放输出。真实idle在计数/触发同拍优先，6比较补充场景验证阈值前一拍无故障和阈值同拍idle阻止超时。合法clear只在episode关闭后，new fault胜过同拍clear。外部响应假设：本地active由各owner真实恢复，watchdog永不伪造idle或DONE。参数非法reject缺失已报B-001。SUP05/08/10 AMI延迟discard/Top merge不由这个叶子TB闭合。


## 批次2：scheduler全周期与取消边界

### B-003 — NORMAL宏帧实际周期5001拍，偏离5000拍/400 Hz合同

- S1 / RTL。C08 §4.2:134-142规定2 MHz、5000拍、4999→0进入下一宏帧，§自检FSC-03要求周期。RTL:752-790只在沿前无active时启动；792-846末拍清active、回IDLE，使下一次启动额外占一拍。Top:862-868只传身份位宽，没有覆盖默认5000或补偿周期。
- 原文（2行）：`C_MACRO_FRAME_TICKS = 5000`；`宏帧计数范围为0..4999，在4999 -> 0时进入下一宏帧。`
- 仿真：evidence/scheduler_cadence以原RTL/默认参数、始终eligible且所有ready/idle有效连续测得5001、5001、5001；精确5000比较3次FAIL、退出1。evidence/scheduler_cadence_counterfactual只在本组副本把长度改4999，测得3次5000并PASS，定位多余边界拍。后者不是有效修复方案，未改共享RTL。
- 影响：理想连续NORMAL每色采样约399.920016 Hz，每帧累积一拍相位偏差；不声称任意背压情况下必须保持400 Hz。反驳：输入全就绪排除了外部ADC/消费者等待；CAL rollover有旁路、不能补偿NORMAL。源内恢复预热属于PWI资格，与这个已经eligible的边界空拍不同。置信度：仿真确认默认叶子行为、Top静态直连确认。建议按合同明确连续NORMAL边界进入语义并补严格周期比较；不修复。

### B-004 — scheduler单元TB容许多一拍并跳过真实Q3完成资格

- S2 / TB。TB:581容许`(reg_frame_period == 5000) || (reg_frame_period == 5001)`，不能发现B-003。TB:276把`i_owner_q3_window_closed`恒接1，310-336固定计数DONE模型；C08:1205明确不允许固定4拍DONE替代真实物理完成链。
- 原文（2行）：`.i_owner_q3_window_closed(1'b1)`；`check_fsc(14, (reg_frame_period == 5000) || (reg_frame_period == 5001));`
- 仿真负对照：仅去掉RTL:460的Q3成功门控，evidence/scheduler_original_q3_gate_mutant仍59 PASS；补充早DONE且Q3=0场景，原RTL释放owner但不报NORMAL完成（evidence/scheduler_early_q3，owner=2/done=2/normalcomplete=0，PASS），同变异却normalcomplete=1，evidence/scheduler_early_q3_mutant FAIL并退出1。
- 反驳：本条不指控原RTL Q3逻辑，也不宣称系统LFA/Q3全无覆盖；原TB有真实比较和失败输出，缺陷在资格与允许值。建议精确周期断言和早DONE对照，并将物理链自检交给实际链TB；不修复。置信度：静态+变异实测。

### B-005 — CAL末拍rollover覆盖同拍abort撤销

- S1 / RTL。RTL:468-473的rollover条件没有取消资格；597-619主next虽清STARTED/FRAME_ACTIVE，853-872的后置state_rollover_next再将FRAME_ACTIVE置1并进入CAL、frame_id递增。C08 §16.4要求abort清宏帧，§15事件优先级要求取消阻止新工作。
- 原文（2行）：`state_rollover_next[B_FRAME_ACTIVE] = 1'b1;`；`if(flag_calibration_rollover)begin`。
- 最小证据：evidence/scheduler_abort_tick4999中CAL active=1/inflight=0/pending=1/rollover=1，于negedge拉abort、下一posedge检查，active仍1、tick=0、ownercommit=0、idle=0，FAIL退出1；相同刺激提前一拍（evidence/scheduler_abort_tick4998）active=0/idle=1，PASS。固定输入均已初始化，没有沿上驱动竞态。
- 已证实范围：逻辑CAL上下文在取消沿被重新创建、scheduler不能立即idle；没有观察到新的物理owner，因为STARTED已清且生命周期gate仍阻止commit。不得据此夸大为ADC永远不返回或永久死锁。STOP也共享未门控overlay，额外drain长度仍需专项量化。Top传播静态及系统边界覆盖待核对。置信度：叶子边界仿真确认。建议让rollover服从取消/生命周期优先级并加入相邻拍反证；不修复。

### scheduler其余审阅结果

RTL884行、TB936行与C08合同1252行的功能正文已读。请求资格双边检查、valid载荷冻结、waveform与owner分离、sample_index只在owner提交递增、sample+generation匹配后释放、Q3只门控success、错/重复DONE阻断均核对。deadline同拍commit在next中优先；直接CAL deadline输出tick248与commit同沿冲突属既有事项，保持关联，不重编号。reset清全state，宽度/计数依赖默认合法参数，非法参数完整拒绝范围尚需同类汇总。门禁AST结构成功不等于行为合同成功。

AMB recheck RTL374行/TB655行代码已读，C16周期章节及PWI实际连线已读：其本地sample_inflight只有accepted/stage/lifecycle释放，没有deadline输入。正在追踪AMI中间ready握手与外层deadline释放后的重试可达性，尚未把疑点定性为发现。

## 批次3：AMI完整代码及周期重检闭环

### B-006 — formal measurement discard身份取自已推进的上游fork

- S1 / RTL。AMI:1296、1307、1318、1329、1340、1351分别从`dec_measurement_*`、`flag_measurement_*`及上游fork generation取discard身份，而当前待discard的正式输出在`reg_result_fork_payload`（1742-1749）。前者是NORMAL fork输出（2022-2041），可以先推进到下一笔。C10:616-620、661-673、691-694要求每分支保留身份。
- 关键原文（3行）：
```text
measurement_result_discard_frame_id_o <= dec_measurement_frame_id;
measurement_result_discard_sample_index_o <= dec_measurement_sample_index;
measurement_result_discard_color_ir_o <= flag_measurement_color_ir;
```
- 最小仿真：evidence/discard_identity_one为单笔真实ADC/S1/DC链对照，3 PASS。evidence/discard_identity_two在同样启动搜索完成后保持正式输出90/900/RED背压，再接受并返回91/901/IR；abort前正式结果仍90/900，上游已91/901；abort的event=1、identity_valid=1却frame=91/sample=901/color=1，BIDISC FAIL、退出1。没有force，没有悬空注入参与（默认C_ENABLE_TEST_INJECTION=0）。Top:1190-1192和1576-1578直接转发错误字段，没有补偿。
- 影响：软件/外部观察到被丢弃的另一事务身份，而原90/900正式结果已撤销。不扩大为当前下游永久不排空；本条针对身份化discard的真实可见错误。反驳：不是F-002 TXN_ID文档扩展缺口，也不是generation广播豁免；该端口明确是formal measurement单事务观察，不能使用任意trigger ID。原AMI-46（1549-1560）只构造单笔，48比较基线不能发现此跨缓存覆盖。置信度：真实链仿真与逐端来源确认。建议从正式measurement保留载荷取身份，增加两笔背压取消比较；不修复。

### B-007 — 周期AMB请求deadline后内部inflight未释放，RUN重检无法重试

- S1 / RTL跨模块。AMI:929给PWI的是中间缓存ready；1364-1368锁存重检源，外部Scheduler握手后1799-1800置外层inflight；deadline在1797-1798只清AMI外层。PWI:1015将中间ready直通重检调度器。AMB recheck:195握手置本地inflight（360-369），208以其为0门控后续valid，本地没有deadline输入或对应清零路径。清除只能来自真实accepted、阶段终结、START或取消。
- 原文（2行）：`flag_calibration_request_inflight <= 1'b0;`（AMI:1798，deadline分支）；`flag_sample_inflight <= 1'b1;`（AMB:368，缓存握手分支）。C10:486、996规定截止未建立owner，不会返回结果，应重发同一候选；不仅限启动搜索。
- 正向复现：evidence/recheck_deadline_v4复用原AMI TB真实启动、数据、FIR/cross和精度返回路径达到periodic reason01，不force内部状态。缓存握手后inner=1，Scheduler请求握手后outer=1；没有启动ADC owner。输入一次合法deadline表示此候选未取得owner，然后提供100次安全边界及物理CAL帧完成，观察outer=0/inner=1/req=0/busy=1/physidle=1/chainidle=1/fault=0/ownerdelta=0，BRETRY FAIL退出1。撤销run_enable后BCLEAR PASS。
- 反证：evidence/recheck_control正常实际校准结果消费可完成三阶段（30 PASS、0 FAIL）；evidence/recheck_deadline_gate_counterfactual仅在本组副本去掉208行的本地inflight valid门控，deadline后的req恢复1，BRETRY/BCLEAR PASS（31比较0失败），定位消失的请求来源。此变异会弱化所有权约束，不是可提交修复。
- 活性结论：当前RUN里没有任何未返回ADC owner，外部ADC/消费者等待已排除；没有accepted结果时本地FSM也无终结条件，不能自主恢复。STOP/撤销RUN/reset可以恢复，因此不声称复位后永久死锁。与已知tick248同拍commit冲突分开：本证据ownerdelta=0，完全无commit。SID-05原修复及startup证据只证明直接IDAC startup请求源重试，不能覆盖有第二层inflight的periodic源。全Top在实际SSW拒绝owner时的专项仍待验证，静态线路与输入合同允许该场景。置信度：AMI+全部真实子模块仿真确认，Top拒绝条件可达性待补。建议把未建立owner的截止释放贯穿重检所有权，保留重复请求保护；不修复。

### 取消路径反驳与工具环境

recheck_cancel_abort/stop在AMI直接输入cancel、同时人为保持run_enable=1时，PWI empty=1使detection discard不发，recheck仍busy；run_enable撤销后BDROPR PASS。Top:411使用wrapper RUN许可，manager:504只在RUN为1，进入STOPPING立即撤销；故不能把这个叶子刺激扩大成Top STOPPING永久死锁，当前不另编号S1。这项反驳独立于B-007截止后仍在RUN的场景。

本次WSL的/mnt/c发生Input/output error，普通sandbox还拒绝访问WSL服务；未重启或改变共享环境。经授权升级调用，把既有Icarus 11.0和只读源码副本经stdin复制到独立/tmp/codex-ppg-review-B-d18c6954下运行，日志保留本组Windows证据目录。未安装软件。前两次deadline试验尚未提供进入AMB的安全边界、BSETUP失败，不作为设计缺陷证据；v3补齐后复现，v4加入撤销RUN反证。

AMI77-2681与模块TB60-1642全部执行代码已读；C10全文尚余1109-1337及注释整理。C16全文已读，除重检owner未收到deadline外，本地请求保持、顺序AMB/R/IR、先结果后物理帧和反序、DCS禁用跳过、失败/STOP释放、间隔16bit饱和及pending等待真实15→9均已对照。C16 AMR-03/04默认4095/4096在叶子TB用interval3与65535等值场景覆盖，不能把标签等同实际默认长边界。SSW/PWC/PWI余部与系统TB全文仍待推进。

## 批次4：独立分支资格和AMI历史诊断

### B-008 — measurement先消费会把仍pending的detection样本资格清0

- S1 / RTL。AMI:1231-1241只保存一个`result_sample_valid_o`，1238-1239在measurement transfer时清零；同一寄存器同时驱动measurement资格（1028）和PWI detection `i_sample_valid`（2518）。C10:535、691-694、941-946明确要求两分支独立保留，pending分支资格不能被另一分支消费改写。
- 原文（2行）：`end else if(flag_measurement_transfer == 1'b1)begin`；`result_sample_valid_o <= 1'b0;`。
- 复现：evidence/branch_qualification_v2完整复用原AMI TB现有N08之前的真实子模块路径与FIR背压窗口，47项原比较全PASS，随后measurement实际消费的下一拍，window=1/firbusy=1/detpending=1/measpending=0/samplequal=0，BWINDO PASS、BQUALI FAIL退出1。该NORMAL结果没有invalid注入，生产资格应为1。
- 因果对照：evidence/branch_qualification_counterfactual_v2只在本组副本让1238的measurement清零还要求detection不pending；完全相同窗口samplequal=1，原47比较及两个扩展比较全部PASS（49/0）。这只是定位，不作为正式分支独立存储修复。第一版检查点位于measurement尚未消费的一拍，measpending=1，资格尚为1，两边BWINDO均FAIL，不作为缺陷证据。
- 影响：PWI稍后握手会把一个成功NORMAL样本当invalid消耗，FIR不得把它计入历史/检测；正式measurement虽已成功消费，算法路径丢失其资格。反驳：数值载荷仍保持，问题不是payload覆盖；C_ENABLE_TEST_INJECTION=0，排除F-001/X及受控invalid；所用背压窗口就是原N08合法压力场景，没有force或伪内部ready。未声明所有默认物理400 Hz帧都会命中该窗口。原TB只检查N08 abort身份，AMI-12/13只构造measurement反压，不比较反向pending资格，故基线48 PASS不能证明分支独立。置信度：真实链+限定counterfactual。建议单独保存measurement/detection资格，并比较两种消费顺序；不修复。

### B-009 — AMI新合法START清除历史protocol sticky

- S1 / RTL。C10 §15.1:1153明确历史protocol sticky只有reset或本地无active blocking cause后的diag_clear可清，START/STOP不能清。AMI:1186-1187却把START与diag_clear并列。
- 原文（2行）：`end else if(i_start_ack_event == 1'b1 || i_diag_clear_event == 1'b1)begin`；`integration_protocol_error_sticky_o <= 1'b0;`。
- evidence/ami_sticky_start：真实MANUAL启动完成后提交非法frame11，BSTICK验证sticky=1、blocking=0、ADC无inflight；STOP、撤销RUN及drain后BDRAIN验证empty=1且历史仍1；generation改2、合法新START后sticky=0，BKEEPH FAIL退出1；显式diag_clear BDIAGC PASS。3 PASS/1 FAIL。所有驱动在negedge，未保留旧owner，新START的安全前提已经比较。
- 影响：软件未清历史即被新RUN静默抹去；不同于PWC已经实现PWC-41保留sticky的已知修复，不能用PWC通过替AMI证明。建议新START只重建RUN上下文，保留历史sticky，并加AMI跨RUN测试；不修复。置信度：合同+仿真确认。

### C10全文审阅及待反驳事项

C10 1337行已全文读完。其规范自检表AMI-46..54与现有叶子TB的同名46/47用途不同：现TB46是measurement discard、47是detection discard，实际只有48比较（含N08），不得重标为当前注入/全合同54项。此项与F-003锚点/语义映射问题关联，不简单再创建一条重复“旧锚点”。

还需独立汇总的静态不一致：C10称注册AMI聚合/事件/每lane原子fault快照，而实际多项直接组合来自live子模块；CHARACTERIZATION在normal fork之后才gate tracking valid，内部raw tracking pending仍会建立（违背§8.5第7项），但IDAC消费口被禁止，尚无实际自动调码错误证据。取消期间注入ready与diag_clear本地active门控也需与Top受保护输入前提逐项核对，当前不提升未证实风险为S1。

## 批次5：精度取消优先级与PWI尾部测试

### B-010 — PWC discard与安全边界同拍仍提交精度和正常事件

- S1 / RTL。PWC:264-265的enter/return commit未排除当前generation discard，虽然602-603的FSM优先回IDLE、337-348窗口资格优先清0，316-334精度寄存器及355-397事件仍按commit更新。C23:213-228、475-476、703-710、779-784要求discard高于提交，不改物理精度、不发fine start/15-to-9。
- 原文（2行）：`assign flag_enter_commit = (state_current == ST_WAIT_ENTER) && i_frame_safe_boundary && i_precision_takeover_safe && i_analog_safe && !i_recheck_busy;`；`assign flag_return_commit = (state_current == ST_WAIT_RETURN) && i_frame_safe_boundary && i_precision_takeover_safe && i_analog_safe;`。
- evidence/pwc_cancel_commit：复用叶子TB真实请求与ready/valid，当前generation的STOP/abort/system-fault分别与合格安全边界同拍，enter后三种均mode=1/window=0/start=1/state=IDLE，return后三种均mode=0/window=0/return=1/state=IDLE，6项FAIL；6项setup、旧generation仍允许正常提交与正常返回共8项PASS，退出1。全部刺激在negedge或posedge后#1，未force。evidence/pwc_cancel_commit_counterfactual仅在本组副本对两个commit条件加!flag_lifecycle_cancel，相同14比较全PASS。副本仅定位，不是共享RTL修复。
- 影响：正常提交事件出现在被撤销generation，物理committed值与已清窗口/FSM不一致。父链AMI:962复合安全公式未屏蔽terminal action，:970检测discard可以由pending PWC触发；:2539原样宏帧边界、:2541安全资格进入PWI。完整Top同拍触发尚未模拟，不能夸大成必然新ADC启动或永久死锁；模块直接合同已被可达合法端口组合反证。建议所有提交/事件/计数以同一有效终端优先级门控，补双方向同拍测试；置信度：短仿真+限定counterfactual确认。

### B-011 — PWI-01丢弃累计前置检查，提前尾部错误也PASS

- S2 / TB。PWI TB:736/738/743累计pending、真实fine事件数、前10笔旧精度不报错到flag_case_ok，但:746最终判定没有该变量；PWI-02:758-766累计值在:769同样遗漏。C18:639要求前10笔合法、第11笔才错误，不能只比较第11笔已有sticky。
- 原文（1行）：`check_case("PWI-01", o_peak_valley_protocol_error_sticky && (cnt_fine_start_event == 1) && o_active_precision_mode && o_fine_window_active);`。
- evidence/pwi_tail_original_check与pwi_tail_early_overflow_mutant：只跑真实链原TB第一项到:746；本组负对照将C-owned峰谷检测器的FIR_GROUP_DELAY_LIMIT从参数10改0，使第一笔旧9-bit中心样本就报overflow，原比较两边仍各1 PASS/0 FAIL，退出0。不是请求修复C源码，也不证明原峰谷RTL错。
- 进一步核验：原累计flag_case_ok在两边均0；只把它加入最终比较会连原RTL也FAIL，原因是:738在fine pulse的下一个posedge计数器尚未计数时读count（pulse_safe_boundary在commit后的negedge就返回）。evidence/pwi_tail_sampled_strict在该观察点补一个negedge、将累计值用于最终比较：原RTL B_FINE_COUNTER=1、B_TAIL10 sticky=0/saved=1，PASS；evidence/pwi_tail_sampled_strict_early_mutant在同样观察点sticky=1/saved=1，最终FAIL退出1。首轮strict失败只定位TB采样问题，不当RTL缺陷。
- 建议同时修复事件计数采样窗口与累计前置条件使用；退出尾部项亦使用已累计比较；补每个真实owner条件独立阻止recheck接管。置信度：真实链负对照。PWI TB仅5条历史项，sample_valid绑1/discard绑0，C18:690已承认06..10缺独立TB；不重复为“新遗漏”。

### 本批语义审阅

PWC RTL全部执行代码、文件头以及TB全部执行代码，C23全文1029行已读；PWI RTL全部执行代码/文件头、TB全部执行代码和C18全文690行已读。C18:201把fine/reacquire限制的消费者写成PWC，但实际两项接PVW（PWC无这两个输入）；C18新V2.1补记仍同时把V2.0称唯一current，C23/C16依赖称C18 V2.1。此类合同内部消费者/版本冲突待在全合同对照中聚合，与F-003旧锚点区分。

SSW RTL1519行全部执行代码、C09全文918行已读，TB目前1-470；新待反驳：SSW:514-517 abort优先保持owner会吞同拍匹配完成，而AMI完成是单周期注册旁带。尚未做short reproducer，不记为确认发现。cause22按D03冻结不适用，未重复列缺陷。

## 批次6：完成与abort同拍、SSW恢复链

### B-012 — SSW abort优先保持吞掉匹配完成，重启仍不能建立新owner

- S1 / RTL，置信度：叶子四组合、顶层真实ADC路径及限定counterfactual确认。SSW:427已识别匹配sample_index和generation；:514-515的abort保持分支优先于:516-517释放，吞掉无ready单周期完成。C09:346-354、678-689与连接检查表:225-238要求匹配完成success=0/1均释放物理owner；取消只应阻止后续数据/模拟行为，不得遗失已经到达的释放事实。
- 原文（3行）：`end else if(i_control_abort_event == 1'b1)begin` / `adc_owner_inflight_o <= adc_owner_inflight_o;` / `end else if(flag_owner_release == 1'b1)begin`。该寄存器:511-520仅reset、release、commit改变；diag_clear、START、物理idle均不清owner。
- evidence/ssw_abort_done：真实waveform/owner握手，SAR9/SAR15×success0/1共四组合，同拍前flag_owner_release=1，沿后owner=1/idle=0，撤销完成脉冲后20拍仍占用，共8比较FAIL。迟一拍匹配失败完成与同拍错ID后迟到正确完成两个对照PASS；abort时模拟输出关闭。evidence/ssw_abort_done_counterfactual只删除独立副本的abort保持分支，两条原行，释放获得优先级，六项case全PASS。
- evidence/top_abort_done_v3：复用lifecycle TB合法MANUAL双光配置、真实Q3和CLK_DOUT/RAW任务，生产注入参数0，未force。AMI:912/1199-1202正常完成为注册单周期；Top:353-357原始abort同样注册。因此在AMI emit前一个negedge拉原始abort，下一消费沿真实pair=abort1/completion1/release1。沿后Scheduler owner=0、AMI owner=0、SSW owner=1；ADC最终physicalidle=1、waveidle=1、AMIempty=1，SSWidle=0。
- 必须限定：首次生命周期在3拍进入CONFIG，并未卡在STOPPING；Top:741-744的排空资格使用physicalidle/AMIempty/IDACidle/analog-safe，未用SSW完整idle。之后100拍、diag_clear、合法重新COMMIT/START仍留SSW owner。新RUN 7000拍newowners=0，自动故障cause=21并再次回CONFIG；这是已完成旧owner的内部残留阻断恢复，不是ADC不响应。generation已改变，即使新completion也不能按旧generation释放该owner。叶子寄存器缺复位外恢复路径，正常外部接口无法补发已消费DONE。
- evidence/top_abort_done_v3_counterfactual：相同全链短序列，旧owner按匹配完成释放；重启5拍newowners=1、lifecycle=RUN、blocking=0/cause00，PASS。新owner之后等待外部ADC属于正常外部等待，未把该在途事务误当内部死锁。原v1已证失释放；v2尝试START清理被真实反证，v3完整记录恢复失败因果。全部独立复制，未改共享源，未重复A全回归。
- 建议：匹配完成事实优先释放物理owner，同时取消仍优先清波形/结果资格；统一owner相关sticky在相同生命周期清理。补四precision/success组合及顶层注册abort与完成同拍、重启恢复验证。现有SSW迟到/错ID测试和LFA-04先abort后DONE未覆盖此竞争。

### 合同全文新增核对

连接检查表430行和ADC_IDAC集成SPEC494行已全文读。检查表§15明确前文是2026-08-17设计快照、老联合TB退役、C01/C08/C09/C10权威且自身non-normative，因此不把前文旧版本/未实现状态另列当前缺陷。SPEC虽然文件头仍称“当前活动”，C10/矩阵把其定为non-normative设计参考；旧“待实现”校准/IDAC段不能推翻当前实现合同，保留为历史状态提醒，不报RTL缺功能。公共位宽/编码、握手单向依赖、物理idle/DONE区别与真实父链相符；当前generation字段以各模块新合同为准。

SSW TB全部执行代码1116行已审，文件头注释仍需收尾。其同拍优先级问题已经闭合证据；C09 cause22仍按D03冻结不适用。六系统TB、跨合同矩阵ID/消费者/版本核对尚未完成，主任务继续。

## 批次7：系统TB前置条件与实际比较

### B-013 — INJ-04在两类注入均未就绪的窗口验证互斥，门控删除仍PASS

- S2 / TB。injection TB:995-1007同时提出两个请求、等4拍检查ready，随后先撤销两个valid，:1008才送真实DONE。AMI:1012身份ready还需要completion_pending/S1valid，:1013 invalid-ready还需要真实NORMAL DC transfer；测试重叠窗口没有这些事实。C01 TOP-24:936要求双请求无半提交/副作用，:946把INJ-04作为CLOSED证据；此证据无法验证真实处理窗口里的互斥。
- 原文（3行）：`i_test_identity_inject_valid = 1'b0;` / `i_test_invalid_sample_valid = 1'b0;` / `drive_real_adc_done(1'b0, reg_fixed_stage1_raw, reg_fixed_stage2_raw);`。
- evidence/inj_mutex_original*：只复用该TB合法MANUAL单光配置与INJ-04，START前打开注入，独立副本把F-001相关calibration_loss输入绑0以隔离X（两边同样处理）。原RTL及仅删除AMI两个互斥项的负对照，都有3条PASS比较输出（含INJ-00 setup）及最终通过标记，重叠4拍、eligible_cycles=0、ready_cycles=0。负对照并不是共享RTL修改，也不说明原RTL互斥错误。
- evidence/inj_mutex_eligible_v2*：把两个请求保持穿过真实DONE与流水，measurement ready=0保存结果到比较；原RTL重叠66拍、eligible2、ready0，3条PASS比较输出（含setup）及最终通过标记。负对照eligible4、ready1、正式结果被身份错误链阻断，FAIL退出1。第一版eligible未保存formal结果，晚60拍轮询错过已消费结果导致原RTL也FAIL；只作为无效观察点证据，不当RTL缺陷，v2已修正。
- 建议在两种真实注入处理窗口连续检查互斥及正常结果，绑定精确owner并监视有无实际fire；不能把DONE到达前的ready0等同互斥成立。置信度：短真实链负对照。

### B-014 — RRC-01只打印到期帧数，没有核对配置间隔

- S2 / TB，静态高置信度，未做整套RRC回归或宣称实际计数RTL错。periodic TB:497-498配置间隔30；:865-869统计真实完整宏帧，:1052-1057快照pending首次到期的cnt_frame_before_pending；:1067-1072仅要求pending曾出现，就打印“configured interval=30 ... not ADC/owner-commit”。没有cnt_frame_before_pending==30（或定义好的同步延迟修正）比较，也没有双光owner事件与完整帧的比率比较。C16:415-418明确以完整400-Hz NORMAL帧计数，:517冻结16bit interval/0关闭。
- 原文（1行）：`if(!flag_pending_before_fine_window) begin`。else分支无数量比较；从首次pending观察到最终PASS的完整控制流已读，因此任意1..上限到期值均不会由RRC-01拒绝。AMR单模块周期测试仍有独立证据，此处仅否定该系统项“已验证正确间隔/计数来源”的结论，不重复B-003物理周期偏差。
- 建议在每个宏帧完成沿观察pending边界，拒绝提前/延后到期，并与同窗双色owner增量对照。RRC-02目前也只连续检查busy没有提前置位，未比较其注释承诺的pending期间所有码/epoch不变；后续RRC-12固定驱动确实另有码比较，不把局部缺比较写成全项目无覆盖。

### 系统语义审阅记录与限度

- lifecycle TB执行代码及1238-2172正文/场景注释已全部审阅：LFA-04先abort后真实DONE，LFA-07先STOP确保未武装才送重复DONE，LFA-05重置后未武装时送旧RAW/DONE，因此后两项不能替代在新owner存在时的generation错配验证；物理ADC线上本身无sample_index/generation。P01同拍ready/abort采用正确注册延迟并检查capture数，但branch identity关联B-006。LFA-11a owner仍在途/已释放两边都打印PASS，未直接比较success和original identity；之后有排空验证。LFA-10b明确SKIP，声称由OIB-01承接需在OIB实际条件复核，当前未把SKIP算PASS。
- startup TB执行代码全文及主序列842-1503/新增任务正文已读：三阶段SID-05保持physicalidle0穿过248后才释放，覆盖deadline miss与重试，未挑战248沿正好合格提交的已知缺口；SID-06 DC_R比较真正当前/下一子帧snapshot，代码有有效非空前提。SID-12耗尽调用make_fixed_raw(0)实际钳成8，与注释“503/反转阈值”不一致，但合法低侧耗尽同样可用，未报RTL功能错。正常启动之前无NORMAL owner的全程性质主要依赖结构，最终startup完成单点不等价完整监视。
- injection TB执行代码全审；INJ-03在posedge活动区撤销valid有TB竞争风险，未知检测仅匹配全向量X，不能排除partial-X；新owneridentity/数学值没有全字段期望值比较。P06顶层enable在RUN内被锁存，外部deassert不等于AMI端enable真实deassert；需与矩阵P06语义及叶子证据对照，不把其PASS当叶子去使能已测。F-001悬空输入继续关联。该TB系统时钟13ns、其他五份500ns；这里只支持加速的逻辑场景，不能宣称该文件动态证明2MHz模拟绝对时序。
- periodic TB1513行执行代码已审：公共任务逐行代码对照lifecycle（已审）后复用，声明/DUT/时钟差异全部读；新增monitors/main全文读。RRC-03在accept沿锁存安全公式，能证明accept时合格但不能替代各安全分量独立负对照；RRC-04从轮询发现accept后才快照baseline，窗口开始的瞬间扰动未被该比对覆盖；success后FIR历史只等待最终full，未逐样本数到21；RRC-12等待400次双色驱动的“cycles”实际是驱动对数，不是i_clk周期。已知长回归超时不转记PASS或内部死锁。
- no_recheck TB1111行执行代码已审：interval=0、直接消费点持续sticky监视、FIR预热降深与fine入口真实非空前提具备；返回事件监视来自PV return请求握手，未直接证明PWC已经物理提交SAR9。NRE-06仅非递减frame_id和总capture>0，不能证明逐帧无丢失、重复/精确400Hz；无frame_id回绕构造。它从仿真开始统计，JNT前缀结果也在总数内。

公共任务一致性证据evidence/system_task_inventory.json与system_delta.py，只作逐行代码关联，不是AST/仿真PASS。两个新系统项B-013/014已保存，OIB全文、文件头/其他内联注释、跨合同ID版本消费者仍待收尾。

## 批次8：身份断言反驳、使能到达与消费者核对

### B-015 — OIB-06只有排序/重复比较，未验证无丢失与元数据错标

- S2 / TB；静态确认并有精确二值谓词反例。位置：`rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v:946-960,1868-1875`；直接需求 `contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:684`；别名表`:174,176`宣称所有五类均已检测。OIB-06以frame/sample递减或等于上一结果作唯二错误条件，color/type/precision仅锁存、打印，没有期望owner队列、数量守恒或对应字段比较。
- 原文（2行）：`end else if((o_result_frame_id == reg_last_result_frame_id) && (o_result_sample_index == reg_last_result_sample_index)) begin` / `$display("PASS OIB-06 result stream preserved order with no loss/duplication/recoloring/retyping/precision-relabeling across %0d real transfers", cnt_result_capture);`。
- `predicate_counterexamples.py`及`evidence/oib06_predicate_counterexamples.json`：核对当前源码两条实际谓词后，对连续唯一身份的四笔结果分别丢一笔、翻color、改type、改precision；四种反例均产生0错误，最终OIB-06 gate仍PASS。重复和递减两个阳性对照各产生1错误。这里只是二值静态谓词重放，未冒称全系统RTL仿真或元数据RTL已错。
- 反驳：OIB-07在`:1670-1671`确实对一笔事务比较frame/sample/color/precision；OIB-09在`:1567,1621`对两笔真实调码前后RED结果比较该帧epoch。因此不是全项目没有字段检查。它们不覆盖OIB-06连续stream的全部事务、type或丢失，不足以支持本项的全程PASS描述。已知F-003是失效行锚点；这里是有效代码里缺少语义判据，相关但不重复。
- 建议：从真实owner提交/受控discard维护期望队列，在每次formal transfer逐字段核对且核算剩余队列。置信度：静态确认/谓词负对照。

### B-016 — P06去使能刺激被Top RUN锁存屏蔽，叶子错误负对照仍PASS

- S2 / TB与闭合证据。位置：`rtl/ppg_control_top/tb_ppg_control_top_injection.v:783-789`；`rtl/ppg_control_top/ppg_control_top.v:387-398,1364`；`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1573-1580`；矩阵P06 `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:928`和别名表`:467`。测试在RUN内将source配置请求i_test_inject_enable置0；Top只在!run_enable时跟随该请求，RUN内AMI收到的effective enable保持1。故该检查未验证AMI request-slot在实际去使能后的保持规则。
- 原文（2行）：`end else if(!wrapper_run_enable_o) begin` / `flag_test_inject_mode_latched <= i_test_inject_enable;`。
- `short_p06.py`及`evidence/p06_target_enable*`：复用真实合法COMMIT/START、Q3和RAW/DONE，再原样复用INJ-02到P06检查；双方隔离F-001，将复制TB的calibration_loss valid绑0。原RTL与仅在AMI hold寄存器新增!i_test_inject_enable清零的错误副本，均2条PASS比较输出（含INJ-00 setup）及最终通过标记、0FAIL；trace为outer_enable=0 leaf_enable=1 hold=1 abort=0，outer_disable_cycles=1/leaf_disable_cycles=0。双posedge等待里下降沿可见一次外部低电平，该统计只是可观测采样数，不把它误写为外部仅保持一拍。初次脚本定位假定源码always有空格，匹配失败未执行仿真；已改用实读位置+内容断言。
- 反驳：Top锁存本身正是C01/AMI约定的合法行为，不是RTL错；AMI真正的hold逻辑也确实没有enable清零，P06性质由静态源码支持。问题是矩阵把没有到达目标输入的刺激写成动态闭合证据。自动abort另外会合法清hold，并不能让刺激到达AMI。建议增加AMI叶子场景，在真实fire之后直接拉低其输入、连续比较原身份与hold，或将系统证据改为Top RUN模式锁存范围。置信度：真实短仿真与错误负对照。

### B-017 — C18窗口长度字段的直接消费者标错

- S3 / 合同；静态确认。位置：`contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:196-201`，实际PWI `rtl/ppg_precision_window_integration/ppg_precision_window_integration.v:803-843`与PWC`:60-156`端口全文。
- 原文（1行）：
```text
| `i_max_fine_window_frames`, `i_max_reacquire_frames` | precision controller | The limits are stable configuration values; the separate valid gate prohibits formal fine-window control and 9-to-15 requests when low. |
```
表头明确“直接子模块消费者”，但两个字段仅连接peak/valley detector例化的同名输入，PWC完全没有这两个端口。PWC按真实peak/valley返回请求执行安全切换，窗口计数/超时归PVW；配置没有丢失，此项不能升级为功能缺陷。
- 反驳：C23没有要求PWC另设这两个输入，C18其它段落也描述PVW窗口/重新获取职责，无法用“间接影响precision”解释直接消费者表。与F-003锚点老化不同，这行本身明确错误。建议把直接消费者更正为peak/valley detector，并保留PWC的请求/提交职责。置信度：静态确认。

### OIB其余检查与版本口径

OIB1887行执行代码已全部审阅，main884-1887原文完成。OIB-03反压分支只在阻塞驱动任务返回时检查valid保持，没有全周期payload稳定比较；STOP/reset支具备真实held-result前提，STOP支比较恰好一次discard但不比其identity（B-006专项已给双事务反例）。OIB-05与LFA-07同样只在完全STOP排空、未武装状态呈交重复DONE。OIB-07的commit snapshot确实逐字段实比。OIB-09真正观察码改变和后来frame-latched epoch改变，比before/after formal epoch；before/after轮询有上界但未先显式拒绝valid未到的情况，不过后续字段case-inequality通常捕获不匹配，不用疑似问题凑新条。

LFA-10b明确SKIP是真实限度，不能算PASS；声称由OIB-01承接，只限非阻断launch-timeout与SSW blocking=0区分（OIB:1738-1752），并不动态验证SSW真正blocking fault=1形成记录。C24单元SUP源仲裁有独立输入为1覆盖，Top连接可静态核对，不能偷换成SSW真实源的整机正向构造。OIB-01恢复分支实际STOP+drain+diag_clear+recommit+START；未证明同一RUN的下一宏帧自动恢复（:1756-1762已明示），保留为测试范围限制。

C08/C09/C10/C18存在“更新修订记录较新、sole/current normative正文仍指定旧版”的并置：例如C09:3 V1.10、:7 sole V1.9、:9 sole V1.8；C18:3 V2.1而:4 current V2.0。当前依赖表和新增条目确实保留新能力，不把较早版本的历史标签单独解读为禁止新端口；这种版本权威措辞仍需统一，供A合并文档一致性项。旧checklist/ADC-IDAC SPEC已按当前矩阵non-normative边界处理，不据其旧实现状态报功能错。

当前新发现B-001..017。剩余：长文件内联注释全面收尾、ID机械关联与各family语义抽查、覆盖/交接最终一致性复核。共享源码未修改，未新跑长回归。


## 批次9：全文注释、ID语义及依赖收尾

### B-018 — 相同验收编号在合同与TB中指向不同场景

- S3 / 合同与测试映射；静态确认。C08 `contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md:1135,1149,1166-1167` 对应 `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:564,592,708,724`；C24 `contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md:160-161` 对应 `rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v:470,480-488`。机械索引可找到同号TB调用，却不能据此判定需求闭合。
- 原文（3行）：
```text
| FSC-03 | 400 Hz周期 | 相邻宏帧起点严格相差5000个2 MHz周期 |
check_fsc(3, (cnt_frame_start == 0) && (o_next_sample_index == 0) && !o_transaction_inflight);
check_fsc(17, cnt_owner_commit == 1);
```
- FSC-03实际检查START后尚未出现宏帧/owner；周期比较在FSC-14（:581），而合同FSC-14是DCS_CAL RED。FSC-17合同要求校准资格与请求保持，TB却处于RED-only正常帧，只检查owner数为1。FSC-34合同是随机反压，TB检查一次失败完成后NORMAL完成数为0；FSC-35合同是长期400Hz无漂移，TB检查STOP后的释放。SUP-09合同是fault-discard/external-abort区分，TB检查watchdog在阈值前真实idle；SUP-10合同是AMI延迟fault reason保持，TB检查清历史后的第二次episode。不是同一场景的不同文字。
- 证据：全文原表/调用控制流，`evidence/id_four_link_audit.json` 的numeric dispatch和SUP子case索引；重新按实际行号读取，未运行新长仿真。反驳：scheduler :909/:927（FSC-58/59）确有非法run-profile/input-source的有效资格比较；SUP-06以及前面的fault-discard检查仍有独立价值。它们不能让原FSC-17或SUP-10同号证据变成合同所述场景；不声称这些需求在全项目完全未验证。
- 与B-004区分：B-004是周期允许值与Q3资格过弱；本条是验收编号语义错位。与F-003区分：这里的行号可找到实际有效调用，问题不是锚点漂移。建议按冻结需求重建编号映射，保留已有有效检查并显式关联替代场景。置信度：静态确认。

### B-019 — C09当前版本声明与三个规范依赖绑定不一致

- S3 / 合同与版本台账；静态确认。`contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md:3` 已是V1.10（AMB单相Q2修订），`:7`仍称sole current V1.9。C08依赖表`:59`、C10`:63`、C24`:17`及 `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:1206,1244` 仍绑定C09 V1.9，与约定按 `C09:3` 读取当前版本的台账不一致。
- 原文（2行）：
```text
> Normative status: V1.9 is the sole current SSW interface and lifecycle authority (V1.9 is additive over V1.8, see the 2026-08-30 change record above). Earlier V1.3.x-V1.7 status and historical regression wording cannot classify missing joint implementation evidence as a contract-interface defect.
| C09 | `ppg_system_integration/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md` | V1.9 | SSW registered fault-record source and stop-drain consumer. |
```
- `dependency_audit.py` / `evidence/dependency_bindings.json` 核对B七份规范合同的54条当前依赖，按当前matrix §12.4a canonical path解析，54条路径全匹配，只有上述3条版本与实际目标第3行不匹配。故意错版本、错路径两个负对照均拒绝。首版版本正则在中文紧跟数字时错误退回V1/V2，输出21条假差异；已撤销该结果，加入中文V1.10、英文逗号、英文句号三个解析fixture，修正后才采信3条差异。未修改共享合同。
- 反驳：V1.10是明确增量修订，V1.9仍含owner/Q3/注入等主要规范，不能把旧sole标签解释成禁止新增端口或推导所有功能错误。C08/C10/C18也各有新修订记录与旧current标签并置，记录为同类版本权威措辞待统一。此项只否定版本/依赖台账完全一致；不重复F-003行锚点问题，也不重报已知§13.1数量滞后。建议明确最新增量与基础规范的关系并同步三处依赖和当前台账；历史版本记录保留为历史。置信度：静态确认与机械负对照。

### 完整读取与抽查口径

7 RTL、13 TB和9份合同的全文（含文件头、中英文修订记录及有语义的内联注释）均已读取。相同系统公共任务使用逐行内容对照后复用阅读，所有差异和新增主序列独立读取。`evidence/comment_inventory.json` / `unique_comments.json`仅为定位/去重索引，不是Verilog语义解析器。语法依据技能formatter AST和真实Icarus编译；注释/PASS/历史回归声明不是规范或当前动态证据。

312个不同合同ID来自B合同明确定义表以及C25中属于B六系统TB的五组需求；14个family均作语义抽查。`evidence/id_four_link_audit.json`保留每个ID的四类原始来源；范围和子case归一化经过fixture，numeric FSC调用、移除TB联系与移除registry联系有负对照。索引里的“有TB代码提及”可能只是横幅或display，不等于真实比较；registry提及可能是历史行，不等于当前CLOSED。完整逐ID语义签核和全局锚点台账仍归A，B完成了本组机械核对及family抽查。

| family | 明确定义数 | 已抽查的实际证据与结果 |
|---|---:|---|
| AMI | 54 | AMI-47合同:1259，叶子TB:1579/1628，实际one-shot绑定/拒绝；INJ互斥处理窗口受B-013限制。AMI-48~53在本组单元TB没有同号case，不能按横幅补齐；对应系统身份/invalid/discard场景按实际条件审，AMI-54跨层门控由D01及静态连接承接，不宣称本组单元覆盖54项。 |
| AMR | 14 | AMR-05合同:655、TB:384-391，pending前/后与未启动可比较；码/epoch不由此调度叶子观测，系统RRC-02限制已记。AMR-08/09涉及IDAC重搜索，AMR-13涉及隔离数值链，叶子无同号case，不自动判为RTL缺失；B-007给真实跨模块反例。 |
| FFK | 9 | FFK-02合同:618，C主责TB:334-340实比两分支payload且初始ready均0；只复核共享合同所需场景，不代替C全文审阅。 |
| FSC | 57 | FSC-03/17/34/35检查调用确有，但语义错位B-018；另有58/59资格对照，不能混作57项需求均已闭合。 |
| IDT | 15 | IDT-03合同:633、C主责TB:588-592，N_CONFIRM=1第一笔有效越界建立pending；数值叶子全文由C负责。 |
| LFA | 12 | LFA-04合同C25:697、TB:1188-1232，先abort后迟到DONE具有真实在途身份并检查failure/no formal；同拍释放缺口另见B-012。LFA-10b SKIP保留，不能转PASS。 |
| NRE | 6 | NRE-01合同C25:618，TB连续RUN监视五个重检活动信号、:1048-1052比较计数；NRE-06只做frame非递减和capture>0，不能替代精确节拍/无丢失。 |
| OIB | 10 | OIB-06合同C25:684、TB:946-960/1868-1875，缺少守恒和元数据期望，B-015；OIB-04是构造方法约束，OIB-10明确静态ready分析/单位fork证据，不要求同名dynamic case。 |
| PWC | 41 | PWC-41合同:954、RTL:494/511、TB:746/758，有真实sticky非空前提和两个比较；已有修复有效。PWC同拍discard/commit仍有B-010。 |
| PWI | 8 | PWI-05合同:643、TB:830-837，在20/21笔边界验证重预热。06/07为invalid、08门控，原TB仅01~05，相关系统场景的范围按实际比较记录，不能宣称单元8项全覆盖。 |
| RRC | 12 | RRC-01合同C25:601、TB:1067-1072只有首次pending帧数打印，B-014。RRC-12有独立真实调码比较，不据前者否定所有调码覆盖。 |
| SID | 12 | SID-05合同C25:553、三阶段deadline抑制/恢复场景均有非空请求，:1117及后续阶段；已知248同拍commit项仍未覆盖，不另报。 |
| SSW | 52 | SSW-46合同:863、TB:986-994，非零SAR15事务逐tick检查SAR9两总线为0；本case只支持其明确比较的精度隔离部分，其他码窗由45/47/48交叉核验。同拍abort/completion另见B-012。 |
| SUP | 10 | SUP-06合同:157、TB:441/458及补充边界对照，真实idle优先、无伪完成成立；非法参数拒绝缺口B-001。09/10同号语义错位B-018，历史未clear rearm覆盖缺口B-002。 |

旧FSC/SSW/AMR/IDT等家族大量没有同名`@satisfies`或在matrix/alias逐项枚举，机械索引按实际缺失记录，不创造豁免、不把无标签等同无实现，也不补写虚构CLOSED。旧§13.1和G-FP独立复核范围不足属已知事项；A可从逐ID索引合并全局账。额外INJ/P/N/K标签在矩阵而非B合同定义表中，已按本组相关场景逐条读取，B-013/016等保存语义反证，不能混入312个定义数重复计数。

### 工具与尚不具备的签核证据

使用bundled Python、D:/Git/cmd/git.exe、现有WSL Debian中的Icarus11.0。7份RTL formatter AST结构成功，同版本deliverable gate/lint已按来源复核复用；AMI 2 error/1 warning、SSW 10 error、PWI 1 warning，其余4份零。错误规则是既有VG014/VG060/VG061/VG066积压，详各模块evidence/skill，不重复列为功能发现；门禁结构结果不等于协议正确。专项的compile.log/run.log/result.json保留真实编译、FAIL和退出码；带FAIL而rc=0的原TB依日志判失败，负对照预期FAIL不算原RTL回归失败。

全套原TB/长回归由A统一执行，本组只做必要短对照及同版本日志复核。三份外部3600秒截断仍是未完成，不能写PASS或内部死锁。未重新运行Vivado xsim、Verilator、FPGA/ASIC综合、STA或PVT；本组结果不构成芯片或工具签核。B-007完整Top拒绝-owner输入窗口的专项以及B-010完整Top同拍取消到达窗口尚没有新的动态证据，这些限制保留在各条结论，不扩大已验证范围。

截止本批，B-001~019共19项：8 S1 RTL、7 S2 TB、4 S3合同/一致性；无新增S4风格条目。发现保持未修复，本组共享源始终只读。正在做最终文件台账与基准字节复核。


## 最终复核（2026-10-04）

Git 2.54.0.windows.1、Python 3.12.14；既有Icarus11.0（WSL Debian）。最后重新读取HEAD及status：固定提交一致、工作树干净，29/29快照字节等于该提交Git blob。Git safe-directory例外只在本次命令参数中使用、禁optional locks，未写全局配置或共享.git。最终结果保存evidence/final_baseline.json。

7份同版本门禁按规则汇总为VG014=2、VG060=3、VG061=2、VG066=7，共12 error/2 strict warning；其中AMI 2/1、SSW 10/0、PWI 0/1、其他四份0/0。这里只汇总已知积压，不把门禁标为全部通过。formatter AST与真实编译/仿真各有独立证据。原始stdout混有WSL UTF-16代理警告的NUL，最终试验索引去NUL后统计比较行并单列FATAL，原日志未改；`*_PASS`结束标记不计为独立比较。为此复核并订正B-013/016的比较数量，问题和负对照结论不变。

逐文件审阅状态均为完成（7 RTL / 13 TB / 9合同，94检查项）；完成是阅读、实际核对、问题记录和交接完成，不把未修复问题和未完成长回归藏进PASS。A需要复核关键原始日志、合并已有F编号和全局ID/锚点台账，并处理本报告保留的动态范围及签核缺口。本组没有运行中仿真。
