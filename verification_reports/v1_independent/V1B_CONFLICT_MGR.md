# V1 独立同拍冲突审查：manager

基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`，RTL `rtl/ppg_system_config_manager/ppg_system_config_manager.v`；下文行号均为基线。依据C02、C24及B交接§3/F009已定事项。使用erie-verilog-generator formatter AST只读检查；没有访问隔离的审查材料，没有修改RTL，没有仿真。完整always原文条件顺序附后。

## 1. 上游到对象

Top L374–378把外部STOP、supervisor注册STOP和外部abort的独立drain贡献合成注册STOP。ACTIVE wrapper直接转送manager输入；status clear来自Top独立寄存器L337，COMMIT来自配置CDC，START为已经同步的事件。上述源**可以同拍**；SPI合同§9条11允许命令字节同时设置多个bit。manager L309–315检测六种命令条件对，不让COMMIT/START/clear在冲突中部分执行，但L462–464刻意仍允许STOP。

定义C=合法COMMIT，S=合法START，L=合法STOP，D=无命令冲突的status clear，E=dec_error_present，H=STOPPING全部idle/safe。所有对象异步reset优先，与任意事件同拍(b)；以下(a)指构造排除，并不只是输入名称不同。

## 2. 冲突矩阵

| 对象/块 | 全部优先级 | 条件对及处置 |
|---|---|---|
| active_config_o L520 | reset装V5复位配置 > C整组装 > 保持 | C与S/L/D(a)，C含!command_conflict；非法V4/V5字段与C(a)，全组valid；合法config与来源事件同拍只在CONFIG接受(b)，C02 §4 |
| run_generation_o L531 | reset0 > S+1 > 保持 | S与L/C/D(a)，READY、CONFIG/RUN状态相反且command-conflict；STOP/COMMIT不改变代际(b)，C02 §3.1 |
| stop_episode_active_o L542 | L置1 > H清0 > 保持 | L/H可同拍(c)，V1-MGR-01；首次L/H(a)，首次在RUN，H在STOPPING；重复L在STOPPING，不能外推首次互斥 |
| active_valid_o L556 | 非法state清 > C置1 > H清 > 保持 | 非法state/C/H(a)，当前编码相反；C/H(a)，CONFIG/STOPPING相反；L/H可同拍(b)，valid清，因为这里没有L置位分支 |
| stage2_coef_epoch_o L572、coef_epoch_o L606 | 各自C且对应qualification bit1递增 > 保持 | qualification1/0(a)；C与任何取消命令(a)，不增epoch；其余epoch同一C原子提交(b)，C02 §6 |
| dc_recovery_coef_epoch_o L584、config_epoch_o L595 | C递增 > 保持 | 两者同拍C(b)，固定合同语义；不把“两个epoch同时更新”当互相覆盖 |
| commit/start/stop ACK L618/627/636 | reset0 > 每拍分别装C/S/L | 同拍输入命令可同拍但C/S不接受，STOP单独接受(b)，错误E也可同拍输出；ACK连续输入事件会连续高，单拍输入前提，T-MGR-02 |
| error_event_o L645 | reset0 > 每拍装E | E和L可同拍(b)，STOP执行并记录冲突；C和E(a)，合法COMMIT全资格；S和E(a)，合法START全资格 |
| commit_ack_sticky_o L654 | C置1 > D清 > 保持 | C/D(a)，command-conflict门控；输入commit+clear同时高(b)，两动作拒绝、ERROR冲突置位，C02 §3.1 |
| error_sticky_o L668、last_error_code_o L682 | E置位/装错误码 > D清 > 保持 | E/D可同拍：非法state和独立clear，E优先(b)；命令冲突/clear时D本身不合法(a)；新错误覆盖历史last码属于“last”定义(b)，不是first-fault记录 |
| state_current L697、state_next L706 | resetCONFIG > next；组合保持→按唯一state：CONFIG/C到READY、READY/S到RUN、RUN/L到STOPPING、STOPPING/H到CONFIG、非法default到CONFIG | C/S/L跨state(a)；STOPPING重复L和H同拍(b)，FSM允许已排空回CONFIG，与episode寄存器优先级不一致即V1-MGR-01；fault-blocking只影响START资格，不伪造STOP或H(b)，C02 §3.1 |

组合`dec_error_code` L470–494：非法state > command conflict > COMMIT状态/schema/reserved/V5/range/enum/profile/input/optical/IDAC/static/code-range/threshold/confirm/coefficient > START状态/static/qualification > STOP状态。多个非法字段可同拍(b)，固定首失败理由；raw命令冲突高优先(b)。C输入有效各字段只是valid组合，不是会被后写覆盖的状态对象。

## 3. (c) 发现

### V1-MGR-01：重复STOP与排空完成同拍留下永久stop episode（中）

当前ST_STOPPING且`i_adc_idle && i_datapath_empty && i_idac_idle && i_analog_safe=1`，此沿又收到一次合法重复STOP。L545把stop_episode置1，L547的清分支被跳过；同时L724–726无STOP优先阻止H，state进入CONFIG，L563–565清active_valid。之后没有当前ST_STOPPING，episode唯一清分支不可达，START也不清，故episode一直1直到复位或下一次完整STOPPING排空。

C02 §2.1/§3.1明确episode排空后落下；§3“重复STOP幂等ACK，不改变排空过程”。上游已逐路追到Top的注册STOP合并，外部STOP可以选择任意系统相位，supervisor STOP也可能与外部重复，故不是构造互斥。触发只需1拍；滞留可持续跨CONFIG/READY及新RUN。

后果：supervisor L193依据这个唯一episode证明对任何后续`!physical_idle`计数；原本只允许STOPPING排空的5000拍watchdog可能在新RUN里启动，早于AMI的9000拍busy升级。正常2–20拍转换一般只产生短暂错误计数、不到超时，不能声称每次新RUN都会abort；忙/完成丢失异常持续5000拍时误开启cause31才可观察。建议重复STOP相对H扫描-1/0/+1，随后合法COMMIT/START并用5000拍忙输入验证cause31不应在RUN开启。

## 4. 待定和覆盖

T-MGR-01：独立START和外部abort经不同Top延迟到达，manager可能接受START但下游同时取消；归属Top/IDAC报告，完整链扫描±2拍。T-MGR-02：输入命令违反“单周期事件”前提时连续ACK是否符合软件可见协议；不要以持续高代替重复单拍STOP。

已覆盖17个always，目标为active_config、run_generation、stop_episode、active_valid、四epoch、四事件、三sticky/last_error以及state_current/state_next；所有对象/起点在§2。附录逐块列出全部if/else及赋值，无抽读。F009明确manager不等宏帧结束，空帧在CONFIG继续计tick，不将该规则重新报为缺陷。

文末结果：(c) V1-MGR-01（中）；待定T-MGR-01/02。附录之后再次给出汇总。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 520 | `active_config_o` | seq |
| 531 | `run_generation_o` | seq |
| 542 | `stop_episode_active_o` | seq |
| 556 | `active_valid_o` | seq |
| 572 | `stage2_coef_epoch_o` | seq |
| 584 | `dc_recovery_coef_epoch_o` | seq |
| 595 | `config_epoch_o` | seq |
| 606 | `coef_epoch_o` | seq |
| 618 | `commit_ack_event_o` | seq |
| 627 | `start_ack_event_o` | seq |
| 636 | `stop_ack_event_o` | seq |
| 645 | `error_event_o` | seq |
| 654 | `commit_ack_sticky_o` | seq |
| 668 | `error_sticky_o` | seq |
| 682 | `last_error_code_o` | seq |
| 697 | `state_current` | seq |
| 706 | `state_next` | comb |

### L520：active_config_o

```text
520: 	always@(posedge i_clk or negedge i_rstn)begin
521: 		if(i_rstn == 1'b0)begin
522: 			active_config_o <= {V5_RESET_PROFILE, 640'd0};
523: 		end else if(flag_commit_accept == 1'b1)begin
524: 			active_config_o <= i_config_snapshot;
525: 		end else begin
526: 			active_config_o <= active_config_o;
527: 		end
528: 	end
```

### L531：run_generation_o

```text
531: 	always@(posedge i_clk or negedge i_rstn)begin
532: 		if(i_rstn == 1'b0)begin
533: 			run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}};
534: 		end else if(flag_start_accept == 1'b1)begin
535: 			run_generation_o <= run_generation_o + 1'b1;
536: 		end else begin
537: 			run_generation_o <= run_generation_o;
538: 		end
539: 	end
```

### L542：stop_episode_active_o

```text
542: 	always@(posedge i_clk or negedge i_rstn)begin
543: 		if(i_rstn == 1'b0)begin
544: 			stop_episode_active_o <= 1'b0;
545: 		end else if(flag_stop_accept == 1'b1)begin
546: 			stop_episode_active_o <= 1'b1;
547: 		end else if((state_current == ST_STOPPING) &&
548: 			(flag_stopping_complete == 1'b1))begin
549: 			stop_episode_active_o <= 1'b0;
550: 		end else begin
551: 			stop_episode_active_o <= stop_episode_active_o;
552: 		end
553: 	end
```

### L556：active_valid_o

```text
556: 	always@(posedge i_clk or negedge i_rstn)begin
557: 		if(i_rstn == 1'b0)begin
558: 			active_valid_o <= 1'b0;
559: 		end else if(flag_state_invalid == 1'b1)begin
560: 			active_valid_o <= 1'b0;
561: 		end else if(flag_commit_accept == 1'b1)begin
562: 			active_valid_o <= 1'b1;
563: 		end else if((state_current == ST_STOPPING) &&
564: 			(flag_stopping_complete == 1'b1))begin
565: 			active_valid_o <= 1'b0;
566: 		end else begin
567: 			active_valid_o <= active_valid_o;
568: 		end
569: 	end
```

### L572：stage2_coef_epoch_o

```text
572: 	always@(posedge i_clk or negedge i_rstn)begin
573: 		if(i_rstn == 1'b0)begin
574: 			stage2_coef_epoch_o <= 8'd0;
575: 		end else if((flag_commit_accept == 1'b1) &&
576: 			(i_config_snapshot[20] == 1'b1))begin
577: 			stage2_coef_epoch_o <= stage2_coef_epoch_o + 8'd1;
578: 		end else begin
579: 			stage2_coef_epoch_o <= stage2_coef_epoch_o;
580: 		end
581: 	end
```

### L584：dc_recovery_coef_epoch_o

```text
584: 	always@(posedge i_clk or negedge i_rstn)begin
585: 		if(i_rstn == 1'b0)begin
586: 			dc_recovery_coef_epoch_o <= 8'd0;
587: 		end else if(flag_commit_accept == 1'b1)begin
588: 			dc_recovery_coef_epoch_o <= dc_recovery_coef_epoch_o + 8'd1;
589: 		end else begin
590: 			dc_recovery_coef_epoch_o <= dc_recovery_coef_epoch_o;
591: 		end
592: 	end
```

### L595：config_epoch_o

```text
595: 	always@(posedge i_clk or negedge i_rstn)begin
596: 		if(i_rstn == 1'b0)begin
597: 			config_epoch_o <= 8'd0;
598: 		end else if(flag_commit_accept == 1'b1)begin
599: 			config_epoch_o <= config_epoch_o + 8'd1;
600: 		end else begin
601: 			config_epoch_o <= config_epoch_o;
602: 		end
603: 	end
```

### L606：coef_epoch_o

```text
606: 	always@(posedge i_clk or negedge i_rstn)begin
607: 		if(i_rstn == 1'b0)begin
608: 			coef_epoch_o <= 8'd0;
609: 		end else if((flag_commit_accept == 1'b1) &&
610: 			(i_config_snapshot[19] == 1'b1))begin
611: 			coef_epoch_o <= coef_epoch_o + 8'd1;
612: 		end else begin
613: 			coef_epoch_o <= coef_epoch_o;
614: 		end
615: 	end
```

### L618：commit_ack_event_o

```text
618: 	always@(posedge i_clk or negedge i_rstn)begin
619: 		if(i_rstn == 1'b0)begin
620: 			commit_ack_event_o <= 1'b0;
621: 		end else begin
622: 			commit_ack_event_o <= flag_commit_accept;
623: 		end
624: 	end
```

### L627：start_ack_event_o

```text
627: 	always@(posedge i_clk or negedge i_rstn)begin
628: 		if(i_rstn == 1'b0)begin
629: 			start_ack_event_o <= 1'b0;
630: 		end else begin
631: 			start_ack_event_o <= flag_start_accept;
632: 		end
633: 	end
```

### L636：stop_ack_event_o

```text
636: 	always@(posedge i_clk or negedge i_rstn)begin
637: 		if(i_rstn == 1'b0)begin
638: 			stop_ack_event_o <= 1'b0;
639: 		end else begin
640: 			stop_ack_event_o <= flag_stop_accept;
641: 		end
642: 	end
```

### L645：error_event_o

```text
645: 	always@(posedge i_clk or negedge i_rstn)begin
646: 		if(i_rstn == 1'b0)begin
647: 			error_event_o <= 1'b0;
648: 		end else begin
649: 		error_event_o <= dec_error_present;
650: 		end
651: 	end
```

### L654：commit_ack_sticky_o

```text
654: 	always@(posedge i_clk or negedge i_rstn)begin
655: 		if(i_rstn == 1'b0)begin
656: 			commit_ack_sticky_o <= 1'b0;
657: 		end else if(flag_commit_accept == 1'b1)begin
658: 			commit_ack_sticky_o <= 1'b1;
659: 		end else if((i_status_clear_event == 1'b1) &&
660: 			(flag_command_conflict == 1'b0))begin
661: 			commit_ack_sticky_o <= 1'b0;
662: 		end else begin
663: 			commit_ack_sticky_o <= commit_ack_sticky_o;
664: 		end
665: 	end
```

### L668：error_sticky_o

```text
668: 	always@(posedge i_clk or negedge i_rstn)begin
669: 		if(i_rstn == 1'b0)begin
670: 			error_sticky_o <= 1'b0;
671: 		end else if(dec_error_present == 1'b1)begin
672: 			error_sticky_o <= 1'b1;
673: 		end else if((i_status_clear_event == 1'b1) &&
674: 			(flag_command_conflict == 1'b0))begin
675: 			error_sticky_o <= 1'b0;
676: 		end else begin
677: 			error_sticky_o <= error_sticky_o;
678: 		end
679: 	end
```

### L682：last_error_code_o

```text
682: 	always@(posedge i_clk or negedge i_rstn)begin
683: 		if(i_rstn == 1'b0)begin
684: 			last_error_code_o <= ERROR_NONE;
685: 		end else if(dec_error_present == 1'b1)begin
686: 			last_error_code_o <= dec_error_code;
687: 		end else if((i_status_clear_event == 1'b1) &&
688: 			(flag_command_conflict == 1'b0))begin
689: 			last_error_code_o <= ERROR_NONE;
690: 		end else begin
691: 			last_error_code_o <= last_error_code_o;
692: 		end
693: 	end
```

### L697：state_current

```text
697: 	always@(posedge i_clk or negedge i_rstn)begin
698: 		if(i_rstn == 1'b0)begin
699: 			state_current <= ST_CONFIG;
700: 		end else begin
701: 			state_current <= state_next;
702: 		end
703: 	end
```

### L706：state_next

```text
706: 	always@(*)begin
707: 		state_next = state_current;
708: 		case(state_current)
709: 			ST_CONFIG:begin
710: 				if(flag_commit_accept == 1'b1)begin
711: 					state_next = ST_READY;
712: 				end
713: 			end
714: 			ST_READY:begin
715: 				if(flag_start_accept == 1'b1)begin
716: 					state_next = ST_RUN;
717: 				end
718: 			end
719: 			ST_RUN:begin
720: 				if(flag_stop_accept == 1'b1)begin
721: 					state_next = ST_STOPPING;
722: 				end
723: 			end
724: 			ST_STOPPING:begin
725: 				if(flag_stopping_complete == 1'b1)begin
726: 					state_next = ST_CONFIG;
727: 				end
728: 			end
729: 			default:begin
730: 				state_next = ST_CONFIG;
731: 			end
732: 		endcase
733: 	end
```

## 文末汇总

(c)：V1-MGR-01（中，重复STOP与排空同拍episode滞留）；待定：T-MGR-01、T-MGR-02。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
