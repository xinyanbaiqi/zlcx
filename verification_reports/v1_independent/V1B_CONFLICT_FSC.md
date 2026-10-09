# V1 独立同拍冲突审查：FSC

基线：`a1ba482d35f5d5d211ba86a5b73c91c99740eaca`。对象：`rtl/ppg_400hz_frame_calibration_scheduler/ppg_400hz_frame_calibration_scheduler.v`（以下省略路径）。所有 RTL 行号均为该提交的一基行号。2 MHz；宏帧 5000 拍；校准子帧 625 拍。本报告只做静态审查，没有运行仿真。独立性隔离：未打开、读取或搜索其他审查分支及被排除的报告目录。

使用仓库 `.claude/skills/erie-verilog-generator/SKILL.md` 的 analyze 路径和 formatter AST；不格式化、不修复源码。技能依赖预检缺少 SSH/FPGA 开发工具，因此只使用本地静态能力。AST/静态阅读不等于仿真、综合或流片验证。合同依据为 C08；发生差异时使用合同意图，但 B 交接书 §3 和生命周期/F009 报告中的明确用户裁定覆盖旧合同文字。

## 1. 事件来源和优先级读法

主组合块 L607：默认保持及四个脉冲归零 → START 整向量重建，否则依次执行生命周期取消、启动边界消费、诊断清除、请求校验、fire 一致性校验、请求接受、波形接管/错过、owner 提交、完成/作废/错配、owner 截止、空闲起帧、子帧边界、宏帧结束/计数推进。这里多数是独立 `if`，**后写覆盖先写**，不能把段落先后当成前段优先。

覆盖组合块 L880：`state_next` → CAL rollover（优先）→ frame restart。寄存块 L941：异步低有效复位 → `state_rollover_next`。

上游：control_top L885–888 将 manager START/STOP、注册合并 abort、注册诊断清除扇入 FSC；L907 接 AMI 保持型校准请求；L928 接 AMI fire；L949–954 接 AMI 完成、序号及唯一物理 idle。manager 的 START 必须 READY 且 ADC/数据链/IDAC idle（manager L451–461），STOP 只在 RUN/STOPPING 接受（L462–464）；同一 manager 状态不能同时接受 START 和 STOP。Top 的 abort 和 diag 是独立寄存网（Top L328–360），**不与其他事件构造互斥**。FSC 的本地 fire 与 AMI fire 由同一 `valid && ready` 网产生（FSC L473、AMI L1046、Top 连接），在生产一对一连接下 fire 不一致不可能；端口故障测试仍应检查该保护逻辑。

定义：S=START；L=STOP/abort/`!run_enable`；D=满足 L645 全部资格的 diag；R=校准请求 fire；W=波形 fire；O=owner commit；C=匹配完成；V=匹配作废；E=截止且没有 O；I=空闲起帧；T=local 624 的子帧处理；M=macro 4999；K=rollover；J=restart。复位对所有对象最高优先，以下矩阵中的 reset 与任意事件均为 (b)，依据 C08 §16.1；不宣称其输入电平互斥。

## 2. 对象、全部写入条件及条件对矩阵

字段均同时指 `state_next`、`state_rollover_next` 和最终 `state_current` 的对应片段。表中的分号表示后续独立写入，右侧写入胜出；`>` 表示 else-if 优先。没有列出的情况保持。S 对所有字段先全清，并仅设 STARTED/STARTUP_PENDING。

| 对象（完整字段组） | 非 S 的全部写入与最终优先级 | 条件对及处置 |
|---|---|---|
| B_STARTED、B_STOP_DRAIN | L：0/1；其余保持 | S/L：START/STOP (a)，manager 状态及 command-conflict；S/abort 可同拍 (c)，见待定 T-FSC-03；L 内事件同拍 (b)，统一关闭生命周期 |
| B_STARTUP_PENDING | L 清；startup safe 清 | 两种清可同拍 (b)，同值；S/safe (a)，旧 pending=0 且首帧前启动资格；S/abort 同 T-FSC-03 |
| B_FRAME_ACTIVE、B_FRAME_MODE | abort 清；I 装入；M 清；K/J 装入 | L/I、L/K、L/J (a)：L440 生命周期门控直接含 STOP/abort/!RUN；I/M (a)：FRAME_ACTIVE 相反；K/J (a)：L493 明确 !K；abort/M (b)，都清帧；abort/普通 tick (b)，推进数值不恢复活动位 |
| B_FRAME_ID、B_MACRO_TICK、B_CAL_SUB、B_CAL_LOCAL | I 置相位 0；M 帧号+1/相位0，否则活动帧 tick+1、local624回0/sub+1；K/J 相位0，K 帧号+1 | I/活动推进 (a)，FRAME_ACTIVE 相反；M/local624 同拍 (b)，M优先相位归零；M/K或J (b)，覆盖层保持帧号只增1，符合 F009 §1.3/§9.4；S/tick (b)，S整向量重建 |
| B_FRAME_OPTICAL、B_FRAME_PRECISION、B_FRAME_INPUT_SOURCE、B_RED_REQUIRED、B_IR_REQUIRED；B_FRAME_AMB/DCR/DCIR、各 EPOCH、LEDDAC_R/IR 片段 | I 锁存；J 锁存；K保持已有快照；S清 | I/J (a)，活动位相反；M/J (b)，帧末采样下一帧输入，F009 §9.4/B §3.7；K/J (a)；码提交/快照采样：正常固定码提交在4760或local385，与4999 (a)，异常 idle 提交则需另测，见 T-FSC-04 |
| B_RED_DONE、B_IR_DONE | C且success且NORMAL置同色1；I清；J清；S清 | RED/IR置位 (a)，同一 owner color；C/O (a)，current INFLIGHT 与 !INFLIGHT 相反；C/I或J可同拍 (b)，新帧完成位清零，F009 事件表#10；C/L可同拍，AMI输出若已注册则只释放旧owner，应由 discard资格阻止正式完成，见下文 |
| B_FRAME_FAILED | W错过 NORMAL置1；C失败置1；V置1；RED/IR E置1；I/J清；S清 | C/V (a)，AMI pending完成与 !pending作废直接相反；W错过/W (a)，else分支；C或V/E (a)，INFLIGHT相反；W错过/E不同槽可同拍 (b)，都是置1；失败/M或J (b)，M判旧状态、J清新帧，按F009#10的已定语义，不重复报新缺陷 |
| B_RED_CONTEXT_SEEN、B_IR_CONTEXT_SEEN | L置1；W或错过置1；I清；M置1；J清；S清 | L/W (a)，W含生命周期；L/错过可同拍 (b)，同值；W/I/M/J (a)，tick0/160与4999及活动位限定；M/J (b)，结束旧帧并开放新帧 |
| B_CAL_CONTEXT_SEEN | L置1；R清；W或错过置1；I按请求设置；T先条件写再无条件0、无请求再1；M置1；K清；J按处理后pending设置；S清 | R/W可同拍 (c)，见 T-FSC-02；R/T可同拍 (c)，见 T-FSC-01；L/T (c)，见 V1-FSC-02；T三次写 (b)，最终等价于 `(current pending || R)?0:1`，L821为冗余写；M/K/J (b)，合法重开；L/K/J (a)生命周期门控 |
| B_RED_WAVE_PENDING、B_IR_WAVE_PENDING | L清；W置1；O按候选清；E清；I/M/J清；S清 | W/O同槽 (a)，O读旧pending且W需context unseen；RED W/IR O受固定点和最早队列限制，不能仅按不同颜色宣称互斥；即使跨槽同拍不覆盖同一字段；O/E (a)，E明确 !O；L/W/O (a)，同一生命周期门控；L/E、M/清理 (b)，同值 |
| B_CAL_WAVE_PENDING、B_CAL_WAVE_AMB/DC及EPOCH | L清pending；W置pending并锁码；O/E清pending；I/M/J清pending；S全清 | W/O (a)，旧pending/!seen；W/E (a)，local0与>=248；L/W/O (a)；M/W (a)，local624与0；码装载只W，失效后保持载荷但不能形成候选，C08 §10/§11 |
| B_CAL_REQ_PENDING | L清；R置1；CAL W清；I消费旧pending；T先清再恢复旧pending=1；M按旧pending或WAVE_PENDING重挂；K消费旧pending；J消费处理后pending | R/W、R/I、R/T分别见 T-FSC-02、T-FSC-01；L/T/M (c)，V1-FSC-02；M/J (b)，依据B §3.7；R/K且旧pending0 (c)，V1-FSC-03；旧pending/R (a)，ready含 !pending；K/J (a) |
| B_CAL_REQ_TYPE/COLOR/REASON | R装载；S清 | 非复位只有一装载条件；S/R (a)，正常START时旧STARTED=0阻止ready；非法重复START作为边界测试，不能据合法系统结论省略 |
| B_CAL_REQ_ACTIVE、B_CAL_FRAME_TYPE/COLOR/REASON | L清ACTIVE；O保持ACTIVE；I按旧pending建活动/装payload；T按旧pending装payload；M清ACTIVE；K置ACTIVE并仅旧pending时装payload；J按state_next pending建活动/装payload；S清 | L/O/I/K/J (a)；L/T可同拍 (c)，ACTIVE保持0但payload被写；T/M可同拍 (b)，ACTIVE帧末清；R/T、R/K旧pending0导致新旧载荷不一致，见V1-FSC-03/T-FSC-01 |
| B_INFLIGHT、B_INFLIGHT_DISCARD；B_INFLIGHT_SAMPLE/TYPE/COLOR/GENERATION | L且在途置DISCARD；O建立owner/装身份/clear discard；C或V清owner/clear discard；S全清 | O/C/V (a)，INFLIGHT相反且AMI完成/作废相反；L/O (a)，L440/470直接门控；L/C或V (b)，匹配释放胜出且不复活；同拍STOP成功发布的AMI边界缺口见AMI报告；S/旧owner (a)受manager empty，但S/abort独立输入见待定 |
| B_NEXT_SAMPLE | O+1；S清 | 只真实owner fire递增，C/V/E/W/R不写，(b) C08 §7.2；O/S在生产START前empty且STARTED0 (a) |
| B_MACRO_START、B_NORMAL_COMPLETE、B_CAL_COMPLETE | 默认0；I/J设MACRO_START；K设CAL_COMPLETE；M按旧状态设NORMAL/CAL_COMPLETE；S全清 | M/J同时完成和起帧 (b)，不同字段；L/M或L后的M产生NORMAL_COMPLETE (c)，V1-FSC-01；S/M (b)，S清所有脉冲；K/CAL_COMPLETE不重复累加 |
| B_LAUNCH_TIMEOUT | D清；context_due且无W置1；S清 | D/置位 (a)，D要求!FRAME_ACTIVE，due要求FRAME_ACTIVE；L/due可同拍 (b)，历史诊断允许保留，B §3.7说明空帧行为 |
| B_OWNER_DEADLINE_TIMEOUT | D清；E置1；S清 | D/E (a)，FRAME_ACTIVE相反；O/E (a)，提交屏蔽；三截止两NORMAL可同时越限，均置1 (b)，队列最早事务与INFLIGHT详见L484–486 |
| B_PROTOCOL_ERROR、B_COMPLETION_MISMATCH | D清；非法请求/fire不一致/无owner或错配完成各置1；S清 | D/非法请求或无owner完成可同拍 (b)，后置新故障胜出；D/fire不一致生产 (a)，同源fire；新请求错误/完成错误可同拍 (b)，两sticky均置位，身份仲裁见下一行 |
| B_SCHED_FAULT_VALID、IDENTITY_VALID及FRAME_ID/SAMPLE_INDEX/COLOR/TYPE/PRECISION/GENERATION | 默认valid0；非法请求首次写valid1/idvalid0；fire不一致首次写候选身份；完成错配首次写旧owner身份；S清 | 多错误同拍时后面的完成错配覆盖fire身份，fire覆盖无身份请求；生产fire不一致 (a)；非法请求/完成错误在异常边界可并发，均cause11，但合同没有给同源首故障身份顺序，列T-FSC-05；D/新错配 (b)，新置位胜出 |

## 3. (c) 发现

### V1-FSC-01：STOP/abort 的完成禁止可被帧末独立 if 覆盖（中）

C08 §16.3 明确 STOP 后不得产生新的正式 NORMAL 完成，§16.4 禁止 abort/迟到DONE生成正式完成。RTL L618–640 关闭生命周期，abort在L623清活动位；但 L819、L839–842 仍读 `state_current[B_FRAME_ACTIVE]`、旧 DONE/FAILED，未检查生命周期或 `state_next[B_FRAME_ACTIVE]`。

可达生产场景：NORMAL双光本帧两色已经真实成功，`B_RED_DONE=B_IR_DONE=1`、FAILED=0。主机 STOP 可以在任何剩余相位被 manager 接受。STOP在tick4999同拍时，L841仍置NORMAL_COMPLETE=1；STOP较早发生时，按B §3.7已定行为空帧继续计tick，到4999仍发该脉冲。abort恰好在4999也同样被L841覆盖。脉冲在采样沿后保持1拍（0.5 µs）；较早STOP到4999的余量可从1至约4500拍。上游Top的STOP/abort没有末拍排除。后果是停止后的帧成功计数/观察事件错误；不主张它必然产生新的RAW或正式测量结果。F009关于STOP空帧自然走完的裁定并没有授权产生正式NORMAL完成，因此仍按C08意图判缺陷。

### V1-FSC-02：生命周期清除的校准 pending 被旧状态边界处理重新置位（低）

CAL活动帧有已接受的下一请求pending=1，且无CAL wave pending/owner，STOP或abort与local624同拍。L636清请求，L632封闭上下文，随后L820按旧CAL_REQ_ACTIVE判断，L822重开context，L836又置CAL_REQ_PENDING=1。在macro4999，L846–847还可依据旧pending/WAVE_PENDING再次重挂。生命周期 L440只保护新fire和覆盖层，**不保护这些主块写入**。

请求可在前一子帧结果消费后通过AMI L2015–2023重新握手；既有pending保持到下一个local0，所以local624出现pending1是正常保持路径，主机STOP可独立选中该沿。C08 §15/§16、B §3.7要求取消未提交控制。后果是取消沿之后一个周期出现被复活的请求状态；下一拍`!run_enable`一般再次清除，START也整向量清除，因此没有证据将其夸大为新owner、持久死锁或跨RUN错绑。abort若FRAME_ACTIVE已清，下一拍仍由生命周期分支清pending。

### V1-FSC-03：CAL末拍新请求未同步转移活动payload（中；模块边界确定，系统可达性待测）

条件：CAL macro4999、ACTIVE1、WAVE_PENDING0、INFLIGHT0、旧REQ_PENDING0、合法新valid1。L444–448允许R，L671–676装新请求。L487–492让K成立；L890/891开放sf0并保留ACTIVE，但L892只在**旧pending1**时装活动请求和消费pending，本例不执行。因此下一帧sf0的`waveform_*`仍用旧CAL_FRAME_TYPE/COLOR（L500–505），新REQ_PENDING却保持1。下一拍CAL W清该pending，即新请求被旧活动身份消费。与C08 §9.1、§10的请求载荷原子保持和一请求一owner不一致。

新旧payload相同时该错配不显现；不同阶段/颜色时，AMI L983以自己的新inflight身份拒绝旧类型owner，可能产生cause02。这里没有证明一请求实际生成了两个owner。常规2–20拍ADC返回通常在local约270–290完成，请求会早于624握手；本审查**没有证明正常固定延迟会恰落4999**。跨帧重试/异常延迟允许阶段变化（B §3.9/F009），但必须用生产完整链定向延迟证明该边界，而不是强制内部状态冒充系统证据。

## 4. 待定项与最小仿真

| ID | 需要解决的组合 | 所需仿真/判据 |
|---|---|---|
| T-FSC-01 | R/local624（非macro末拍）且旧pending0 | 单元以新旧不同TYPE/COLOR/REASON在local623、624、下一local0分别握手；L830–832只读旧pending，而L822/825允许新R开放，验证下一波形是否错误沿用旧payload。系统用真实AMI/IDAC返回和异常延迟对齐请求，不force内部寄存器。模块逻辑缺口同V1-FSC-03 |
| T-FSC-02 | 校准R与CAL W同local0，或NORMAL I与新R | R清CONTEXT_SEEN后W置1且清pending；W payload读旧活动请求。sf0刚建立后ready仍可能为1（L444–447），不过AMI自己的request_inflight通常阻止再发。追到AMI来源和IDAC样本消费后，仍需构造上游重请求/late retry，确认新请求不被无声消费。I读旧pending0，R本拍装入，可能先建立一NORMAL帧而让校准等5000拍；合同“校准优先”没有给同拍边界例外，需测系统是否到达 |
| T-FSC-03 | 合法START与独立Top abort同拍 | manager在READY接受START；外部abort独立注册，Top没有与START互斥的门。FSC L613使START胜出；SSW context清除却abort胜出。扫描外部abort相对START ±2拍，查是否会有一个STARTED=1周期、启动边界或owner机会；合同 §15意图为abort优先 |
| T-FSC-04 | 异常idle IDAC补发边界与新帧快照/码提交 | 普通固定边界相位排除同拍；异常启动搜索阶段的L482不能只按固定相位推断。用真实IDAC pending、新请求握手及精度commit记录码/epoch快照完整性；检查I采样旧码与AMI current-code资格不会引入混合或无故拒绝 |
| T-FSC-05 | 同源两个协议故障的记录身份覆盖 | 非法校准请求与错配DONE同拍，D同拍/不同拍；检查case11只保留最后身份是否满足C08/ C24首故障诊断意图。生产合法AMI不会发非法请求，作为接收端防御测试；合同未明确同源多身份顺序，不能直接认定高严重度 |

## 5. 覆盖声明和差异

全部三个 always：L607 `state_next`（含所有字段）、L880 `state_rollover_next`、L941 `state_current`，无遗漏；完整字段清单为§2每行。全部关键assign L428–522及输出桥L527–603已核对。零新RTL/TB；报告之外没有提交现有文件变化。

接受的旧合同差异：R3作废新增释放路径、F009 末拍重启/例外C、RUN外diag限制、L-3 idle码边界、F-7当前帧失败语义按明确裁定，均不重复报缺陷。不能从历史TB PASS推导本矩阵已验证。

## 6. 文末汇总

(c)：V1-FSC-01（中，停止后错误NORMAL完成）；V1-FSC-02（低，取消被边界重写）；V1-FSC-03（中，末拍新请求与旧payload错配，系统可达性待测）。待定：T-FSC-01～05。不得将模块边界静态反例标成已运行的系统反例。

## 补充覆盖证据：技能AST与全部always原始顺序

技能静态门禁的compile/AST均passed；compile在这里仅指formatter AST+静态lint，testbench/toolchain未请求，没有外部编译、仿真或综合。
基线严格风格门禁：0 error(s)，0 strict warning(s)。现有源文件不修复，门禁成功也不能证明同拍功能正确。

### L607：state_next

```text
607: 	always@(*)begin
608: 		state_next = state_current;
609: 		state_next[B_MACRO_START] = 1'b0;
610: 		state_next[B_NORMAL_COMPLETE] = 1'b0;
611: 		state_next[B_CAL_COMPLETE] = 1'b0;
612: 		state_next[B_SCHED_FAULT_VALID] = 1'b0;
613: 		if(i_start_ack_event == 1'b1)begin
614: 			state_next = {STATE_WIDTH{1'b0}};
615: 			state_next[B_STARTED] = 1'b1;
616: 			state_next[B_STARTUP_PENDING] = 1'b1;
617: 		end else begin
618: 			if(i_stop_ack_event == 1'b1 || i_control_abort_event == 1'b1 || i_run_enable == 1'b0)begin
619: 				state_next[B_STARTED] = 1'b0;
620: 				state_next[B_STOP_DRAIN] = 1'b1;
621: 				state_next[B_STARTUP_PENDING] = 1'b0;
622: 				if(i_control_abort_event == 1'b1)begin
623: 					state_next[B_FRAME_ACTIVE] = 1'b0;
624: 					state_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = FRAME_MODE_IDLE;
625: 				end
630: 				state_next[B_RED_CONTEXT_SEEN] = 1'b1;
631: 				state_next[B_IR_CONTEXT_SEEN] = 1'b1;
632: 				state_next[B_CAL_CONTEXT_SEEN] = 1'b1;
633: 				state_next[B_RED_WAVE_PENDING] = 1'b0;
634: 				state_next[B_IR_WAVE_PENDING] = 1'b0;
635: 				state_next[B_CAL_WAVE_PENDING] = 1'b0;
636: 				state_next[B_CAL_REQ_PENDING] = 1'b0;
637: 				state_next[B_CAL_REQ_ACTIVE] = 1'b0;
638: 				if(state_current[B_INFLIGHT])begin
639: 					state_next[B_INFLIGHT_DISCARD] = 1'b1;
640: 				end
641: 			end
642: 			if(startup_idac_safe_boundary_o == 1'b1)begin
643: 				state_next[B_STARTUP_PENDING] = 1'b0;
644: 			end
645: 			if(i_diag_clear_event == 1'b1 && !state_current[B_FRAME_ACTIVE] && !state_current[B_INFLIGHT] && !state_current[B_RED_WAVE_PENDING] && !state_current[B_IR_WAVE_PENDING] && !state_current[B_CAL_WAVE_PENDING] && flag_external_fault == 1'b0)begin
646: 				state_next[B_LAUNCH_TIMEOUT] = 1'b0;
647: 				state_next[B_OWNER_DEADLINE_TIMEOUT] = 1'b0;
648: 				state_next[B_COMPLETION_MISMATCH] = 1'b0;
649: 				state_next[B_PROTOCOL_ERROR] = 1'b0;
650: 			end
651: 			if(i_calibration_sample_valid == 1'b1 && flag_calibration_request_valid == 1'b0)begin
652: 				state_next[B_PROTOCOL_ERROR] = 1'b1;
653: 				if(!scheduler_local_fault_blocking_o)begin
654: 					state_next[B_SCHED_FAULT_VALID] = 1'b1;
655: 					state_next[B_SCHED_FAULT_IDENTITY_VALID] = 1'b0;
656: 				end
657: 			end
658: 			if(i_start_ack_event == 1'b0 && (i_transaction_start_fire != adc_owner_commit_event_o))begin
659: 				state_next[B_PROTOCOL_ERROR] = 1'b1;
660: 				if(!scheduler_local_fault_blocking_o)begin
661: 					state_next[B_SCHED_FAULT_VALID] = 1'b1;
662: 					state_next[B_SCHED_FAULT_IDENTITY_VALID] = 1'b1;
663: 					state_next[B_SCHED_FAULT_FRAME_ID_H:B_SCHED_FAULT_FRAME_ID_L] = current_frame_id_o;
664: 					state_next[B_SCHED_FAULT_SAMPLE_INDEX_H:B_SCHED_FAULT_SAMPLE_INDEX_L] = transaction_sample_index_o;
665: 					state_next[B_SCHED_FAULT_COLOR] = transaction_color_ir_o;
666: 					state_next[B_SCHED_FAULT_FRAME_TYPE_H:B_SCHED_FAULT_FRAME_TYPE_L] = transaction_frame_type_o;
667: 					state_next[B_SCHED_FAULT_PRECISION] = transaction_precision_mode_o;
668: 					state_next[B_SCHED_FAULT_GENERATION_H:B_SCHED_FAULT_GENERATION_L] = i_run_generation;
669: 				end
670: 			end
671: 			if(flag_calibration_request_fire == 1'b1)begin
672: 				state_next[B_CAL_CONTEXT_SEEN] = 1'b0;
673: 				state_next[B_CAL_REQ_PENDING] = 1'b1;
674: 				state_next[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L] = i_calibration_frame_type;
675: 				state_next[B_CAL_REQ_COLOR] = i_calibration_color_ir;
676: 				state_next[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L] = i_calibration_request_reason;
677: 			end
678: 			if(flag_waveform_fire == 1'b1)begin
679: 				if(flag_waveform_is_calibration == 1'b1)begin
681: 					state_next[B_CAL_REQ_PENDING] = 1'b0;
682: 				end
683: 				if(flag_waveform_is_calibration == 1'b1)begin
684: 					state_next[B_CAL_CONTEXT_SEEN] = 1'b1;
685: 					state_next[B_CAL_WAVE_PENDING] = 1'b1;
686: 					state_next[B_CAL_WAVE_AMB_H:B_CAL_WAVE_AMB_L] = i_amb_code;
687: 					state_next[B_CAL_WAVE_DC_H:B_CAL_WAVE_DC_L] = (state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] == FRAME_TYPE_AMB) ? {C_IDAC_CODE_WIDTH{1'b0}} : (state_current[B_CAL_FRAME_COLOR] ? i_dcs_ir_code : i_dcs_r_code);
688: 					state_next[B_CAL_WAVE_AMB_EPOCH_H:B_CAL_WAVE_AMB_EPOCH_L] = i_amb_code_epoch;
689: 					state_next[B_CAL_WAVE_DC_EPOCH_H:B_CAL_WAVE_DC_EPOCH_L] = (state_current[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] == FRAME_TYPE_AMB) ? {C_CODE_EPOCH_WIDTH{1'b0}} : (state_current[B_CAL_FRAME_COLOR] ? i_dcs_ir_code_epoch : i_dcs_r_code_epoch);
690: 				end else if(flag_waveform_is_ir == 1'b1)begin
691: 					state_next[B_IR_CONTEXT_SEEN] = 1'b1;
692: 					state_next[B_IR_WAVE_PENDING] = 1'b1;
693: 				end else begin
694: 					state_next[B_RED_CONTEXT_SEEN] = 1'b1;
695: 					state_next[B_RED_WAVE_PENDING] = 1'b1;
696: 				end
697: 			end else begin
698: 				if(flag_red_context_due == 1'b1)begin
699: 					state_next[B_RED_CONTEXT_SEEN] = 1'b1;
700: 					state_next[B_LAUNCH_TIMEOUT] = 1'b1;
701: 					state_next[B_FRAME_FAILED] = 1'b1;
702: 				end
703: 				if(flag_ir_context_due == 1'b1)begin
704: 					state_next[B_IR_CONTEXT_SEEN] = 1'b1;
705: 					state_next[B_LAUNCH_TIMEOUT] = 1'b1;
706: 					state_next[B_FRAME_FAILED] = 1'b1;
707: 				end
708: 				if(flag_cal_context_due == 1'b1)begin
709: 					state_next[B_CAL_CONTEXT_SEEN] = 1'b1;
710: 					state_next[B_LAUNCH_TIMEOUT] = 1'b1;
711: 				end
712: 			end
713: 			if(adc_owner_commit_event_o == 1'b1)begin
714: 				state_next[B_INFLIGHT] = 1'b1;
715: 				state_next[B_INFLIGHT_DISCARD] = 1'b0;
716: 				state_next[B_INFLIGHT_SAMPLE_H:B_INFLIGHT_SAMPLE_L] = transaction_sample_index_o;
717: 				state_next[B_INFLIGHT_TYPE_H:B_INFLIGHT_TYPE_L] = transaction_frame_type_o;
718: 				state_next[B_INFLIGHT_COLOR] = transaction_color_ir_o;
719: 				state_next[B_INFLIGHT_GENERATION_H:B_INFLIGHT_GENERATION_L] = i_run_generation;
720: 				state_next[B_NEXT_SAMPLE_H:B_NEXT_SAMPLE_L] = state_current[B_NEXT_SAMPLE_H:B_NEXT_SAMPLE_L] + {{(C_SAMPLE_INDEX_WIDTH - 1){1'b0}}, 1'b1};
721: 				if(flag_candidate_calibration == 1'b1)begin
722: 					state_next[B_CAL_WAVE_PENDING] = 1'b0;
725: 					state_next[B_CAL_REQ_ACTIVE] = state_current[B_CAL_REQ_ACTIVE];
726: 				end else if(flag_candidate_red == 1'b1)begin
727: 					state_next[B_RED_WAVE_PENDING] = 1'b0;
728: 				end else begin
729: 					state_next[B_IR_WAVE_PENDING] = 1'b0;
730: 				end
731: 			end
732: 			if(flag_completion_match == 1'b1)begin
733: 				state_next[B_INFLIGHT] = 1'b0;
734: 				state_next[B_INFLIGHT_DISCARD] = 1'b0;
735: 				if(flag_completion_success == 1'b1 && (state_current[B_INFLIGHT_TYPE_H:B_INFLIGHT_TYPE_L] == FRAME_TYPE_NORMAL))begin
736: 					if(state_current[B_INFLIGHT_COLOR])begin
737: 						state_next[B_IR_DONE] = 1'b1;
738: 					end else begin
739: 						state_next[B_RED_DONE] = 1'b1;
740: 					end
741: 				end else if(i_adc_transaction_success == 1'b0 && !state_current[B_INFLIGHT_DISCARD])begin
742: 					state_next[B_FRAME_FAILED] = 1'b1;
743: 				end
744: 			end else if(flag_owner_lost_match == 1'b1)begin
745: 				state_next[B_INFLIGHT] = 1'b0;
746: 				state_next[B_INFLIGHT_DISCARD] = 1'b0;
747: 				if(!state_current[B_INFLIGHT_DISCARD])begin
748: 					state_next[B_FRAME_FAILED] = 1'b1;
749: 				end
750: 			end else if(i_adc_transaction_complete_event == 1'b1 || i_adc_transaction_lost_event == 1'b1)begin
751: 				state_next[B_COMPLETION_MISMATCH] = 1'b1;
752: 				if(!scheduler_local_fault_blocking_o)begin
753: 					state_next[B_SCHED_FAULT_VALID] = 1'b1;
754: 					state_next[B_SCHED_FAULT_IDENTITY_VALID] = state_current[B_INFLIGHT];
755: 					state_next[B_SCHED_FAULT_FRAME_ID_H:B_SCHED_FAULT_FRAME_ID_L] = current_frame_id_o;
756: 					state_next[B_SCHED_FAULT_SAMPLE_INDEX_H:B_SCHED_FAULT_SAMPLE_INDEX_L] = state_current[B_INFLIGHT_SAMPLE_H:B_INFLIGHT_SAMPLE_L];
757: 					state_next[B_SCHED_FAULT_COLOR] = state_current[B_INFLIGHT_COLOR];
758: 					state_next[B_SCHED_FAULT_FRAME_TYPE_H:B_SCHED_FAULT_FRAME_TYPE_L] = state_current[B_INFLIGHT_TYPE_H:B_INFLIGHT_TYPE_L];
759: 					state_next[B_SCHED_FAULT_PRECISION] = (state_current[B_INFLIGHT_TYPE_H:B_INFLIGHT_TYPE_L] == FRAME_TYPE_NORMAL) ? state_current[B_FRAME_PRECISION] : 1'b0;
760: 					state_next[B_SCHED_FAULT_GENERATION_H:B_SCHED_FAULT_GENERATION_L] = state_current[B_INFLIGHT_GENERATION_H:B_INFLIGHT_GENERATION_L];
761: 				end
762: 			end
763: 			if(adc_owner_commit_event_o == 1'b0)begin
764: 				if(flag_red_owner_deadline == 1'b1)begin
765: 					state_next[B_RED_WAVE_PENDING] = 1'b0;
766: 					state_next[B_OWNER_DEADLINE_TIMEOUT] = 1'b1;
767: 					state_next[B_FRAME_FAILED] = 1'b1;
768: 				end
769: 				if(flag_ir_owner_deadline == 1'b1)begin
770: 					state_next[B_IR_WAVE_PENDING] = 1'b0;
771: 					state_next[B_OWNER_DEADLINE_TIMEOUT] = 1'b1;
772: 					state_next[B_FRAME_FAILED] = 1'b1;
773: 				end
774: 				if(flag_cal_owner_deadline == 1'b1)begin
775: 					state_next[B_CAL_WAVE_PENDING] = 1'b0;
776: 					state_next[B_OWNER_DEADLINE_TIMEOUT] = 1'b1;
777: 				end
778: 			end
779: 			if(flag_frame_start_eligible == 1'b1)begin
780: 				state_next[B_FRAME_ACTIVE] = 1'b1;
781: 				state_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = state_current[B_CAL_REQ_PENDING] ? FRAME_MODE_CAL : FRAME_MODE_NORMAL;
782: 				state_next[B_FRAME_OPTICAL_H:B_FRAME_OPTICAL_L] = i_optical_mode;
783: 				state_next[B_FRAME_PRECISION] = state_current[B_CAL_REQ_PENDING] ? 1'b0 : i_active_precision_mode;
784: 				state_next[B_FRAME_INPUT_SOURCE] = i_input_source;
785: 				state_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = {C_MACRO_TICK_WIDTH{1'b0}};
786: 				state_next[B_CAL_SUB_H:B_CAL_SUB_L] = 3'd0;
787: 				state_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}};
788: 				state_next[B_RED_REQUIRED] = (i_optical_mode == OPTICAL_BOTH) || (i_optical_mode == OPTICAL_RED);
789: 				state_next[B_IR_REQUIRED] = (i_optical_mode == OPTICAL_BOTH) || (i_optical_mode == OPTICAL_IR);
790: 				state_next[B_RED_DONE] = 1'b0;
791: 				state_next[B_IR_DONE] = 1'b0;
792: 				state_next[B_FRAME_FAILED] = 1'b0;
793: 				state_next[B_RED_CONTEXT_SEEN] = 1'b0;
794: 				state_next[B_IR_CONTEXT_SEEN] = 1'b0;
795: 				state_next[B_CAL_CONTEXT_SEEN] = 1'b0;
796: 				state_next[B_RED_WAVE_PENDING] = 1'b0;
797: 				state_next[B_IR_WAVE_PENDING] = 1'b0;
798: 				state_next[B_CAL_WAVE_PENDING] = 1'b0;
799: 				state_next[B_MACRO_START] = 1'b1;
800: 				state_next[B_FRAME_AMB_H:B_FRAME_AMB_L] = i_amb_code;
801: 				state_next[B_FRAME_DCR_H:B_FRAME_DCR_L] = i_dcs_r_code;
802: 				state_next[B_FRAME_DCIR_H:B_FRAME_DCIR_L] = i_dcs_ir_code;
803: 				state_next[B_FRAME_AMB_EPOCH_H:B_FRAME_AMB_EPOCH_L] = i_amb_code_epoch;
804: 				state_next[B_FRAME_DCR_EPOCH_H:B_FRAME_DCR_EPOCH_L] = i_dcs_r_code_epoch;
805: 				state_next[B_FRAME_DCIR_EPOCH_H:B_FRAME_DCIR_EPOCH_L] = i_dcs_ir_code_epoch;
806: 				state_next[B_FRAME_LEDDAC_R_H:B_FRAME_LEDDAC_R_L] = i_leddac_r_code;
807: 				state_next[B_FRAME_LEDDAC_IR_H:B_FRAME_LEDDAC_IR_L] = i_leddac_ir_code;
808: 				state_next[B_CAL_CONTEXT_SEEN] = (state_current[B_CAL_REQ_PENDING] || flag_calibration_request_fire) ? 1'b0 : 1'b1;
809: 				if(state_current[B_CAL_REQ_PENDING])begin
810: 					state_next[B_CAL_REQ_PENDING] = 1'b0;
811: 					state_next[B_CAL_REQ_ACTIVE] = 1'b1;
812: 					state_next[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] = state_current[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L];
813: 					state_next[B_CAL_FRAME_COLOR] = state_current[B_CAL_REQ_COLOR];
814: 					state_next[B_CAL_FRAME_REASON_H:B_CAL_FRAME_REASON_L] = state_current[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L];
815: 				end else begin
816: 					state_next[B_CAL_REQ_ACTIVE] = 1'b0;
817: 				end
818: 			end
819: 			if(state_current[B_FRAME_ACTIVE])begin
820: 				if(dec_frame_mode == FRAME_MODE_CAL && (calibration_local_tick_o == CAL_LAST_LOCAL_TICK) && state_current[B_CAL_REQ_ACTIVE] && !state_current[B_CAL_WAVE_PENDING] && !state_current[B_INFLIGHT])begin
821: 					state_next[B_CAL_CONTEXT_SEEN] = (state_current[B_CAL_REQ_PENDING] || flag_calibration_request_fire) ? 1'b0 : 1'b1;
822: 					state_next[B_CAL_CONTEXT_SEEN] = 1'b0;
823: 					if(!state_current[B_CAL_REQ_PENDING] && !flag_calibration_request_fire)begin
825: 						state_next[B_CAL_CONTEXT_SEEN] = 1'b1;
826: 					end
827: 					if(state_current[B_CAL_REQ_PENDING])begin
829: 						state_next[B_CAL_REQ_PENDING] = 1'b0;
830: 						state_next[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] = state_current[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L];
831: 						state_next[B_CAL_FRAME_COLOR] = state_current[B_CAL_REQ_COLOR];
832: 						state_next[B_CAL_FRAME_REASON_H:B_CAL_FRAME_REASON_L] = state_current[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L];
833: 					end
835: 					if(state_current[B_CAL_REQ_PENDING])begin
836: 						state_next[B_CAL_REQ_PENDING] = 1'b1;
837: 					end
838: 				end
839: 			if(macro_tick_o == MACRO_LAST_TICK)begin
840: 					if((dec_frame_mode == FRAME_MODE_NORMAL) && (dec_frame_optical_mode != OPTICAL_OFF) && !state_current[B_FRAME_FAILED] && ((!state_current[B_RED_REQUIRED] || state_current[B_RED_DONE]) && (!state_current[B_IR_REQUIRED] || state_current[B_IR_DONE])))begin
841: 						state_next[B_NORMAL_COMPLETE] = 1'b1;
842: 					end
843: 					if(dec_frame_mode == FRAME_MODE_CAL)begin
844: 						state_next[B_CAL_COMPLETE] = 1'b1;
845: 						if(state_current[B_CAL_REQ_ACTIVE])begin
846: 							if(state_current[B_CAL_REQ_PENDING] || state_current[B_CAL_WAVE_PENDING])begin
847: 								state_next[B_CAL_REQ_PENDING] = 1'b1;
848: 							end
849: 							state_next[B_CAL_REQ_ACTIVE] = 1'b0;
850: 						end
851: 					end
852: 					state_next[B_FRAME_ACTIVE] = 1'b0;
853: 					state_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = FRAME_MODE_IDLE;
854: 					state_next[B_FRAME_ID_H:B_FRAME_ID_L] = current_frame_id_o + {{(C_FRAME_ID_WIDTH - 1){1'b0}}, 1'b1};
855: 					state_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = {C_MACRO_TICK_WIDTH{1'b0}};
856: 					state_next[B_CAL_SUB_H:B_CAL_SUB_L] = 3'd0;
857: 					state_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}};
858: 					state_next[B_RED_CONTEXT_SEEN] = 1'b1;
859: 					state_next[B_IR_CONTEXT_SEEN] = 1'b1;
860: 					state_next[B_CAL_CONTEXT_SEEN] = 1'b1;
861: 					state_next[B_RED_WAVE_PENDING] = 1'b0;
862: 					state_next[B_IR_WAVE_PENDING] = 1'b0;
863: 					state_next[B_CAL_WAVE_PENDING] = 1'b0;
864: 				end else begin
865: 					state_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = macro_tick_o + {{(C_MACRO_TICK_WIDTH - 1){1'b0}}, 1'b1};
866: 					if(calibration_local_tick_o == CAL_LAST_LOCAL_TICK)begin
867: 						state_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}};
868: 						state_next[B_CAL_SUB_H:B_CAL_SUB_L] = calibration_subframe_index_o + 3'd1;
869: 					end else begin
870: 						state_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = calibration_local_tick_o + {{(C_CAL_TICK_WIDTH - 1){1'b0}}, 1'b1};
871: 					end
872: 				end
873: 			end
874: 		end
875: 	end
```

### L880：state_rollover_next

```text
880: 	always @* begin
881: 		state_rollover_next = state_next;
882: 		if(flag_calibration_rollover)begin
883: 			state_rollover_next[B_CAL_COMPLETE] = 1'b1;
884: 			state_rollover_next[B_FRAME_ACTIVE] = 1'b1;
885: 			state_rollover_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = FRAME_MODE_CAL;
886: 			state_rollover_next[B_FRAME_ID_H:B_FRAME_ID_L] = current_frame_id_o + {{(C_FRAME_ID_WIDTH - 1){1'b0}}, 1'b1};
887: 			state_rollover_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = {C_MACRO_TICK_WIDTH{1'b0}};
888: 			state_rollover_next[B_CAL_SUB_H:B_CAL_SUB_L] = 3'd0;
889: 			state_rollover_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}};
890: 			state_rollover_next[B_CAL_CONTEXT_SEEN] = 1'b0;
891: 			state_rollover_next[B_CAL_REQ_ACTIVE] = 1'b1;
892: 		if(state_current[B_CAL_REQ_PENDING] == 1'b1)begin
893: 				state_rollover_next[B_CAL_REQ_PENDING] = 1'b0;
894: 				state_rollover_next[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] = state_current[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L];
895: 				state_rollover_next[B_CAL_FRAME_COLOR] = state_current[B_CAL_REQ_COLOR];
896: 				state_rollover_next[B_CAL_FRAME_REASON_H:B_CAL_FRAME_REASON_L] = state_current[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L];
897: 		end
898: 		end else if(flag_frame_restart == 1'b1)begin
899: 			state_rollover_next[B_FRAME_ACTIVE] = 1'b1;
900: 			state_rollover_next[B_FRAME_MODE_H:B_FRAME_MODE_L] = state_next[B_CAL_REQ_PENDING] ? FRAME_MODE_CAL : FRAME_MODE_NORMAL;
901: 			state_rollover_next[B_FRAME_OPTICAL_H:B_FRAME_OPTICAL_L] = i_optical_mode;
902: 			state_rollover_next[B_FRAME_PRECISION] = state_next[B_CAL_REQ_PENDING] ? 1'b0 : i_active_precision_mode;
903: 			state_rollover_next[B_FRAME_INPUT_SOURCE] = i_input_source;
904: 			state_rollover_next[B_MACRO_TICK_H:B_MACRO_TICK_L] = {C_MACRO_TICK_WIDTH{1'b0}};
905: 			state_rollover_next[B_CAL_SUB_H:B_CAL_SUB_L] = 3'd0;
906: 			state_rollover_next[B_CAL_LOCAL_H:B_CAL_LOCAL_L] = {C_CAL_TICK_WIDTH{1'b0}};
907: 			state_rollover_next[B_RED_REQUIRED] = (i_optical_mode == OPTICAL_BOTH) || (i_optical_mode == OPTICAL_RED);
908: 			state_rollover_next[B_IR_REQUIRED] = (i_optical_mode == OPTICAL_BOTH) || (i_optical_mode == OPTICAL_IR);
909: 			state_rollover_next[B_RED_DONE] = 1'b0;
910: 			state_rollover_next[B_IR_DONE] = 1'b0;
911: 			state_rollover_next[B_FRAME_FAILED] = 1'b0;
912: 			state_rollover_next[B_RED_CONTEXT_SEEN] = 1'b0;
913: 			state_rollover_next[B_IR_CONTEXT_SEEN] = 1'b0;
914: 			state_rollover_next[B_CAL_CONTEXT_SEEN] = state_next[B_CAL_REQ_PENDING] ? 1'b0 : 1'b1;
915: 			state_rollover_next[B_RED_WAVE_PENDING] = 1'b0;
916: 			state_rollover_next[B_IR_WAVE_PENDING] = 1'b0;
917: 			state_rollover_next[B_CAL_WAVE_PENDING] = 1'b0;
918: 			state_rollover_next[B_MACRO_START] = 1'b1;
919: 			state_rollover_next[B_FRAME_AMB_H:B_FRAME_AMB_L] = i_amb_code;
920: 			state_rollover_next[B_FRAME_DCR_H:B_FRAME_DCR_L] = i_dcs_r_code;
921: 			state_rollover_next[B_FRAME_DCIR_H:B_FRAME_DCIR_L] = i_dcs_ir_code;
922: 			state_rollover_next[B_FRAME_AMB_EPOCH_H:B_FRAME_AMB_EPOCH_L] = i_amb_code_epoch;
923: 			state_rollover_next[B_FRAME_DCR_EPOCH_H:B_FRAME_DCR_EPOCH_L] = i_dcs_r_code_epoch;
924: 			state_rollover_next[B_FRAME_DCIR_EPOCH_H:B_FRAME_DCIR_EPOCH_L] = i_dcs_ir_code_epoch;
925: 			state_rollover_next[B_FRAME_LEDDAC_R_H:B_FRAME_LEDDAC_R_L] = i_leddac_r_code;
926: 			state_rollover_next[B_FRAME_LEDDAC_IR_H:B_FRAME_LEDDAC_IR_L] = i_leddac_ir_code;
927: 			if(state_next[B_CAL_REQ_PENDING])begin
928: 				state_rollover_next[B_CAL_REQ_PENDING] = 1'b0;
929: 				state_rollover_next[B_CAL_REQ_ACTIVE] = 1'b1;
930: 				state_rollover_next[B_CAL_FRAME_TYPE_H:B_CAL_FRAME_TYPE_L] = state_next[B_CAL_REQ_TYPE_H:B_CAL_REQ_TYPE_L];
931: 				state_rollover_next[B_CAL_FRAME_COLOR] = state_next[B_CAL_REQ_COLOR];
932: 				state_rollover_next[B_CAL_FRAME_REASON_H:B_CAL_FRAME_REASON_L] = state_next[B_CAL_REQ_REASON_H:B_CAL_REQ_REASON_L];
933: 			end else begin
934: 				state_rollover_next[B_CAL_REQ_ACTIVE] = 1'b0;
935: 			end
936: 	end
937: 	end
```

### L941：state_current

```text
941: 	always@(posedge i_clk or negedge i_rstn)begin
942: 		if(i_rstn == 1'b0)begin
943: 			state_current <= {STATE_WIDTH{1'b0}};
944: 		end else begin
945: 			state_current <= state_rollover_next;
946: 		end
947: 	end
```

## 最终文末汇总

(c)：V1-FSC-01（中）、02（低）、03（中，模块边界确定、系统待测）；待定：T-FSC-01～05。
