# V1 独立同拍冲突审查：control_top

基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`；`rtl/ppg_control_top/ppg_control_top.v`，行号均基线。依据C01/C02/C03/C24与SPI/P2S合同§9条11及B交接§3明确用户裁定。erie-verilog-generator AST只读检查，未访问独立性隔离材料，未改现有文件、未仿真。

## 1. 本地对象及组合/上游冲突矩阵

| 对象/always | 全部顺序 | 同拍条件对及处置 |
|---|---|---|
| flag_diag_clear_event L328 | reset清 > 每拍装i_diag_clear_event | diag与任何外部命令/ADC结果可同拍，独立注册(b)，C01诊断扇出；下游新故障与clear必须自己消歧，AMI/PWC问题见各报告 |
| flag_status_clear_event L337 | reset清 > 每拍装同一个i_diag_clear_event | 两寄存器同源但独立(b)，不把manager status clear反馈为系统diag；两者延迟相同，manager冲突判断不应清其他故障 |
| flag_owner_abort_event L356 | reset清 > 外部abort OR supervisor abort | 两abort同拍可并存(b)，OR不会覆盖；START与外部abort也可同拍，没互斥，V1-TOP-02；不同周期多个输入可产生连续高，单拍请求/episode前提需要T-TOP-02 |
| flag_abort_drain_stop_request L365 | reset清 > 每拍装外部abort | 外部abort同时推动owner-abort与延迟STOP贡献(b)，不伪造完成；贡献比owner-abort到manager多一寄存器阶段，需与START优先级对齐 |
| flag_stop_request_event L374 | reset清 > 外部STOP OR supervisor STOP OR旧abort_drain contribution | 多STOP同拍(b)，OR幂等；STOP相邻周期输入可能连续高，manager重复接受应不影响drain；START直送、STOP多注册一拍(c)，V1-TOP-01 |
| flag_test_inject_mode_latched L390 | owner-abort或STOP ACK清 > !wrapper_RUN时装外部enable > 保持 | 清与配置阶段enable同拍(b)，取消优先；START接受沿读旧RUN0装配置值(b)，新RUN内冻结；外部enable与RUN中结果注入不能仅名称排除，但参数0时effective恒0(a) |

全部对象异步reset最高(b)。组合资格L413–419：analog RUN/START完整转发SSW，measurement RUN/START/allow加!static_enable，互斥static与measurement。static_enable只能经characterization CDC整组提交，RUN中只有同static使能的MUX更新可接受（CDC L109），所以正常静态mode与测量mode不同时生效(a)。physical_idle在L419只透传外部真源，不能以AMI/datapath idle替代。

连接核对：manager wrapper START输入L747直连`i_start_event`；STOP L748连接本地注册`flag_stop_request_event`。FSC/AMI/SSW START来自同一manager ACK（L885/L1006/L1127），owner abort来自同一注册OR网（L887/L1008/L1129）。AMI返回fire接FSC校验，与FSC真实fire同一valid/ready，正常连接构造互斥“fire不一致”保护触发。AMI完成/作废分别同源送FSC/SSW；各模块的匹配/取消顺序可能不同，不能用布线同源代替行为一致性。FSC固定宏帧、local phase直接送SSW；没有第二个相位producer。

source配置/characterization两CDC的提交不是在Top用组合优先级融合；ACTIVE V4/V5由manager原子提交，Top只映射字段，未发现对同一组合输出后写覆盖。参数/实例连接与输出桥均检查，所有六个always已覆盖。这里不声称AMI或检测算法子模块的全部always都包含在Top本文件里。

## 2. (c) 发现

### V1-TOP-01：同拍START+STOP在Top被错开，manager先接受START（中）

初始READY且全部START资格满足。外部同一个2MHz周期令`i_start_event=i_stop_event=1`（合法SPI命令字节两个bit同步请求可提供该输入）。采样沿N，manager经L747直接看到START=1、旧flag_stop_request_event=0，接受START，代际+1、state RUN、START ACK=1；Top L378同沿只将STOP注册为1。N+1 manager才看到STOP，在新RUN接受并进入STOPPING。没有同沿command_conflict，可能既无0x01又出现一次不应执行的START。

C02 §3.1要求同拍Top合并STOP抢占START并保留命令冲突；芯片合同§9条11允许SPI同字节START/STOP且消歧依赖Top原有合并优先级。SPI两个pulse CDC结构相同、源同bit提交，至少存在相位使二者目标脉冲同拍；Top接口本身也允许同拍。不同寄存延迟不是上游互斥证明。

后果是多一个RUN代际/START应答及下游启动初始化；随后STOP一般在FSC启动边界前封闭新owner，所以不声称必然有真实ADC。最小验证：合法READY下SPI命令0x03及Top同拍两个脉冲，比较START ACK、generation、ERROR与STOP状态；±1拍分开输入作为对照。

### V1-TOP-02：START+外部ABORT传播造成取消后启动IDAC码提交（中，完整链静态时间表）

SPI合同允许同字节START+ABORT（0x11）。与上例相同，沿N manager直收START并进入RUN；Top owner_abort/abort_drain均注册为1，STOP注册这沿仍读旧abort_drain0。N+1：三个owner模块看到START ACK和owner_abort同时1；FSC L613让START整向量重建胜出，IDAC FSM L699取消到IDLE却context L1166在取消后重建pending，SSW run_active L787置1、stop_pending L800置1。Top这沿将STOP注册为1，owner_abort回0，但manager还没看到STOP，因此沿后RUN仍1。

N+1到N+2之间：FSC已有STARTED/STARTUP_PENDING，当前abort/STOP ACK为0、RUN1；若初始ADC idle、analog safe、SAR timing idle均1，FSC L479的startup IDAC safe boundary成立。IDAC的START新pending已经1且generation匹配，L584–595提交条件成立。N+2：IDAC提交启动码/epoch/update；同沿manager才接受延迟STOP。这是取消事件之后一个周期（0.5 µs）的真实数字码提交，而不是新RAW；C17 §10要求abort取消未提交pending，C01/C02取消优先意图未得到跨模块一致执行。

使用合法MANUAL或搜索初始候选与旧committed码不同便可观察；如果码相同仍会消费pending但不增epoch。STATIC_BIAS下measurement START被屏蔽，不适用这一IDAC反例；报告限于测量RUN。完整系统仿真尚未运行，若某外部模拟ready额外限制会阻断safe boundary应记录实测，但正常合法START资格与无owner初始空闲满足该时间表。

## 3. 待定和覆盖

T-TOP-01：同拍START/STOP/ABORT/COMMIT/diag全部合法命令组合（源域SPI与2MHz已同步接口分别测），记录每个本地寄存延迟，不能仅在manager端强制同拍替代Top传播。T-TOP-02：多个fault或外部abort相邻周期到来，检查连续高是否在下游被误当多次取消/新episode。T-TOP-03：static控制CDC更新和START临界沿，核验完整mode snapshot与measurement屏蔽，禁止以实时shadow推断已提交值。

全部6个always、三个cancel寄存网、两个diag寄存器、一个test mode寄存器以及组合RUN/START/static/idle资格已覆盖。附录完整列出本文件块和所有赋值顺序。manager repeated-STOP episode滞留归V1-MGR-01，不重复计Top。(c) V1-TOP-01/02；待定T-TOP-01～03。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 328 | `flag_diag_clear_event` | seq |
| 337 | `flag_status_clear_event` | seq |
| 356 | `flag_owner_abort_event` | seq |
| 365 | `flag_abort_drain_stop_request` | seq |
| 374 | `flag_stop_request_event` | seq |
| 390 | `flag_test_inject_mode_latched` | seq |

### L328：flag_diag_clear_event

```text
328: 	always @(posedge i_clk or negedge i_rstn) begin
329: 		if(!i_rstn) begin
330: 			flag_diag_clear_event <= 1'b0;
331: 		end else begin
332: 			flag_diag_clear_event <= i_diag_clear_event;
333: 		end
334: 	end
```

### L337：flag_status_clear_event

```text
337: 	always @(posedge i_clk or negedge i_rstn) begin
338: 		if(!i_rstn) begin
339: 			flag_status_clear_event <= 1'b0;
340: 		end else begin
341: 			flag_status_clear_event <= i_diag_clear_event;
342: 		end
343: 	end
```

### L356：flag_owner_abort_event

```text
356: 	always @(posedge i_clk or negedge i_rstn) begin
357: 		if(!i_rstn) begin
358: 			flag_owner_abort_event <= 1'b0;
359: 		end else begin
360: 			flag_owner_abort_event <= i_control_abort_event || supervisor_system_abort_event_o;
361: 		end
362: 	end
```

### L365：flag_abort_drain_stop_request

```text
365: 	always @(posedge i_clk or negedge i_rstn) begin
366: 		if(!i_rstn) begin
367: 			flag_abort_drain_stop_request <= 1'b0;
368: 		end else begin
369: 			flag_abort_drain_stop_request <= i_control_abort_event;
370: 		end
371: 	end
```

### L374：flag_stop_request_event

```text
374: 	always @(posedge i_clk or negedge i_rstn) begin
375: 		if(!i_rstn) begin
376: 			flag_stop_request_event <= 1'b0;
377: 		end else begin
378: 			flag_stop_request_event <= i_stop_event || supervisor_system_stop_request_event_o || flag_abort_drain_stop_request;
379: 		end
380: 	end
```

### L390：flag_test_inject_mode_latched

```text
390: 	always @(posedge i_clk or negedge i_rstn) begin
391: 		if(!i_rstn) begin
392: 			flag_test_inject_mode_latched <= 1'b0;
393: 		end else if(flag_owner_abort_event || wrapper_stop_ack_event_o) begin
394: 			flag_test_inject_mode_latched <= 1'b0;
395: 		end else if(!wrapper_run_enable_o) begin
396: 			flag_test_inject_mode_latched <= i_test_inject_enable;
397: 		end
398: 	end
```

## 文末汇总

(c)：V1-TOP-01/02（均中，终止命令延迟与START错开）；待定：T-TOP-01～03。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
