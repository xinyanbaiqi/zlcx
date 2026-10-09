# V1 独立同拍冲突审查：IDAC

基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`；`rtl/ppg_idac_code_controller/ppg_idac_code_controller.v`，全部行号属基线。依据C17/C16及B §3.9明确阶段裁定。使用erie-verilog-generator formatter AST；只新增报告，未访问隔离审查材料，未仿真。每个CTX字段的完整写入条件/顺序见附录，不能只读state_next而忽略reg_context_next。

## 1. 顺序与上游

四块：state_current L688；state_next L697；reg_context_next L840；reg_context L1260。FSM是STOP/abort > START > !RUN > state case。context是保持/脉冲默认清 → diag → AMB commit → RED commit → IR commit → MANUAL完成 → 搜索/重检/跟踪 → AMB重检接管 → 新协议错误 → cancel → START重建 → pending generation初次标记 → 首次活动fault快照。独立if后写胜出。

来源：AMI L2547–2552扇入RUN、qualified START、STOP/diag/abort、安全边界；L2574/2576/2596将router搜索与NORMAL tracking有效数据接入，Z禁止取消中的结果消费。AMB/DCS入口来自同一router TYPE互斥，tracking虽可有旧NORMAL保持，但ready L609排除search transfer；搜索资格又按state分离。安全边界来自FSC启动、macro4760、CAL local385或已定L-3 idle补发，generation来自manager且RUN内稳定。

## 2. 对象和条件对矩阵

reset对所有字段优先(b)。K=控制取消STOP/abort/!RUN；S=START；Ca/Cr/Ci=各路旧pending安全提交；Qa/Qd=合格搜索样本；Qt=合格tracking；R=AMB重检接管；Dr=DCS重验accept。表每组包含三路或两色的全部CTX字段，精确写入在附录展开。

| 对象 | 全部条件/最终顺序 | 同拍处置 |
|---|---|---|
| state_current/state_next | STOP/abort到IDLE > S按config/manual/enables到FAULT或APPLY > !RUN到IDLE > case的commit/sample/recheck/accept推进 | K/S同拍FSM取消优先(b)，但context相反(c)，V1-IDAC-01；Qa/Qd(a)，期望state相反；commit/sample同一路(a)，APPLY/WAIT相反；R/Qt同拍只NORMAL允许，见计数行 |
| AMB/DCS_R/DCS_IR committed CODE、EPOCH、UPDATE；两色TRACK_ADJUST | 对应C实际改码时装code/epoch+1/update；track来源置adjust；默认各脉冲0；reset code0/epoch0 | Ca/Cr/Ci可同拍(b)，启动MANUAL三路独立；K/C(a)，L584–595含!STOP/!abort/RUN；S/C生产(a)，manager start前IDAC idle使pending0；同值提交只清pending、不增epoch(b)，C17 §10 |
| 三路PENDING_VALID/CODE/GENERATION及两色PENDING_TRACK | C清valid；AMB recheck改码撤销两色pending；搜索/重验/Qt形成候选；K清valid/track；S重新形成启动候选；最后新valid且旧valid0锁generation | K/形成候选(b)，后写K清；K/S(c)，START再置位；同路C/Qt(a)，Qt要求该路oldpending0；同路C/搜索(a)，APPLY与WAIT/state不变量；不同色C/Qt可同拍(b)，独立字段；Ca重检改码与两DCS commit的风险见T-IDAC-01 |
| 三路BOUND_LOW/HIGH | 搜索越界有next时缩界装载；AMB_RECHECK/重验触发装ACTIVE边界；S按enable装初始边界；其余保持/reset0 | 同一路搜索/重验触发(a)，state编码相反；S/旧样本生产(a)，start前empty；取消不清bound但撤销state/pending(b)，无有效候选，不把残留数据误当活动搜索 |
| 三路HIGH_COUNT/LOW_COUNT | 对应C清；搜索成功清；重验窗口内/触发清、否则高低一路+1另路0；Qt同色同规则；R清AMB计数；K/S全清 | 高侧/低侧(a)，正常单饱和/窗口三个分类排他；双饱和资格拒绝，仅协议sticky(b)；search/track transfer(a)，ready排除；Qt与R可同拍但R只清AMB计数、Qt改DCS计数(b)，首笔序列随后重新验证 |
| AMB_RECHECK_ORIGIN、DCS_REVALIDATE_ORIGIN、AMB_CHANGED | 对应确认触发置origin/changed0；AMB改码changed1；序列完成清origin；R清changed；K/S清 | commit/sample同state(a)；K/序列触发(b)，取消后写；S/K同拍清origin但重建pending见V1-IDAC-01；这些历史字段不自主生成新ADC |
| 三路SEARCH_DONE、EXHAUSTED、FAULT | 窗口内置done/clear计数；二分无next clear done/set exhausted/fault；K清fault，STOP/!RUN另清done/exhausted；S清done/exhausted并按非法config置fault | 成功/耗尽(a)，同一in_window正反及has_next；不同色fault(a)正常state单路搜索，S非法config可三路同置(b)，同一fault event；K/新耗尽可同拍时K清fault，但done/failed脉冲未全部清，T-IDAC-02 |
| STARTUP_COMPLETE | MANUAL安全边界置1；startup末搜索完成置1；K/S清0 | K/完成(b)，后写取消优先；MANUAL/自动搜索(a)，state相反；START与旧完成生产(a)，empty |
| 三UPDATE、两TRACK_ADJUST、AMB_SEQUENCE_DONE/FAILED、DCS_REVALIDATE_DONE/FAILED、CTRL_FAULT_EVENT | 默认0；各commit/样本分类置1；最后fault上升沿检测置事件 | K/commit(a)；K/样本在AMI输入Z下通常(a)，但是模块资格不含K，不能将所有单元边界排除，T-IDAC-02；S/旧脉冲生产(a)，但独立abort同START仍见V1-IDAC-01 |
| PROTOCOL_ERROR | diag清；protocol event置1；S清 | diag/新protocol(b)，L1121后写set胜出；diag/active fault可同拍(c)，V1-IDAC-02；S/新protocol同拍：START最后清，正常START旧请求为空，但非法START协议故障防御测试T-IDAC-03 |
| CTRL_FAULT_IDENTITY_VALID及FRAME_ID/SAMPLE_INDEX/COLOR/TYPE/PRECISION/GENERATION | 聚合fault从旧0到next1时装，S时无身份，其余取搜索身份；reset清 | 三路fault同拍只有一个统一记录(b)，来源类型固定AMI cause05；非法configS采用invalid身份(b)，公共输出归零；当前已有fault时其他故障不覆盖首记录(b)；K可能清nextfault而压掉上升，T-IDAC-02 |

## 3. (c) 发现

V1-IDAC-01（中）：START与abort/STOP取消同拍，FSM L699优先IDLE，而context L1125先取消pending、L1166后START再建立pending（MANUAL L1203–1205，搜索L1211/1214/1225），形成**IDLE但pending有效**。C17 §10/§12要求取消尚未提交候选。正常START/STOP由manager互斥，但START与外部abort是Top独立网（L356/365/374），可以对齐；AMI qualified START L968没有排除abort，L2548照常传入。第一拍之后如RUN尚未被较慢STOP路径撤销，FSC START优先路径还可能提供启动safe边界，使取消后的候选继续提交；若RUN已撤销，则下一拍会清pending。因此既确认同沿不一致，也保留完整链传播的T-IDAC-04，不声称必然持久死锁。

V1-IDAC-02（低）：diag清PROTOCOL_ERROR（L853–854）没有三路active fault解除门控，当前fault仍1时也能清历史；C17 §11.3明确只能活动故障全解除后清历史。独立Top diag与已有搜索耗尽fault可同拍；supervisor abort最终取消fault并不使此前的clear沿合法。protocol新set/clear同沿顺序正确，但不能替代active清除资格。

## 4. 待定及覆盖

T-IDAC-01：AMB recheck改码提交与旧DCS pending提交同沿，主组合依次Ca清DCS再Cr/Ci仍读旧pending。正常R进入要求所有pending0且重检期间无Qt，按state不变量预期(a)；需要三路完整轨迹证明异常恢复/START混合状态不会留下旧DCS，不能只看后写顺序报正常缺陷。

T-IDAC-02：STOP/abort与合格窗口样本/耗尽/序列完成同拍，检测done/failed脉冲是否仍发布。AMI即时abort Z会屏蔽有效输入，STOP当前Z缺口见AMI报告；STOP时RUN已经低一般资格排除。单元与完整链分别测，不把单元非法上下游同拍当生产场景。

T-IDAC-03：START与protocol事件/非法config，检查sticky和fault snapshot一致。T-IDAC-04：START/外部abort±2拍加FSC启动边界，记录state、pending、generation、code/epoch，核验是否取消后有真实提交。

全部4个always及CTX字段L214–273（committed码、epoch、pending码/valid/track/generation、边界、六计数、origin/changed、done/exhausted/fault、protocol、startup、全部事件、fault ID）已覆盖，附录保存全部路径。B §3.9允许阶段延长后下一阶段共用同物理CAL帧、同码AMB重验仍请求DCS重验，按裁定不重复报告旧合同差异。(c) V1-IDAC-01/02；待定T-IDAC-01～04。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 688 | `state_current` | seq |
| 697 | `state_next` | comb |
| 840 | `reg_context_next` | comb |
| 1260 | `reg_context` | seq |

### L688：state_current

```text
688: 	always@(posedge i_clk or negedge i_rstn)begin
689: 		if(i_rstn == 1'b0)begin
690: 			state_current <= ST_IDLE;
691: 		end else begin
692: 			state_current <= state_next;
693: 		end
694: 	end
```

### L697：state_next

```text
697: 	always@(*)begin
698: 		state_next = state_current;
699: 		if((i_stop_ack_event == 1'b1) || (i_control_abort_event == 1'b1))begin
700: 			state_next = ST_IDLE;
701: 		end else if(i_start_ack_event == 1'b1)begin
702: 			if((i_run_enable == 1'b0) || (flag_config_valid == 1'b0))begin
703: 				state_next = ST_FAULT;
704: 			end else if(i_idac_mode == 2'b00)begin
705: 				state_next = ST_MANUAL_APPLY;
706: 			end else if(i_amb_enable == 1'b1)begin
707: 				state_next = ST_AMB_APPLY;
708: 			end else if(i_dcs_enable == 1'b1)begin
709: 				state_next = ST_DCS_R_APPLY;
710: 			end else begin
711: 				state_next = ST_MANUAL_APPLY;
712: 			end
713: 		end else if(i_run_enable == 1'b0)begin
714: 			state_next = ST_IDLE;
715: 		end else begin
716: 			case(state_current)
717: 				ST_IDLE:begin
718: 					state_next = ST_IDLE;
719: 				end
720: 				ST_MANUAL_APPLY:begin
721: 					if(i_frame_safe_boundary == 1'b1)begin
722: 						state_next = ST_NORMAL;
723: 					end
724: 				end
725: 				ST_AMB_APPLY:begin
726: 					if(flag_amb_commit == 1'b1)begin
727: 						state_next = ST_AMB_WAIT;
728: 					end
729: 				end
730: 				ST_AMB_WAIT:begin
731: 					if(flag_amb_sample_qualified == 1'b1)begin
732: 						if(flag_search_in_window == 1'b1)begin
733: 							if(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] == 1'b1)begin
734: 								if(i_dcs_enable)begin
735: 									state_next = ST_DCS_REVALIDATE_WAIT;
736: 								end else begin
737: 									state_next = ST_NORMAL;
738: 								end
739: 							end else if(i_dcs_enable == 1'b1)begin
740: 								state_next = ST_DCS_R_APPLY;
741: 							end else begin
742: 								state_next = ST_NORMAL;
743: 							end
744: 						end else if(flag_amb_search_has_next == 1'b1)begin
745: 							state_next = ST_AMB_APPLY;
746: 						end else begin
747: 							state_next = ST_FAULT;
748: 						end
749: 					end
750: 				end
751: 				ST_DCS_R_APPLY:begin
752: 					if(flag_dcs_r_commit == 1'b1)begin
753: 						state_next = ST_DCS_R_WAIT;
754: 					end
755: 				end
756: 				ST_DCS_R_WAIT:begin
757: 					if(flag_dcs_sample_qualified == 1'b1)begin
758: 						if(flag_search_in_window == 1'b1)begin
759: 							if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b1)begin
760: 								state_next = ST_DCS_REVALIDATE_IR;
761: 							end else begin
762: 								state_next = ST_DCS_IR_APPLY;
763: 							end
764: 						end else if(flag_dcs_r_search_has_next == 1'b1)begin
765: 							state_next = ST_DCS_R_APPLY;
766: 						end else begin
767: 							state_next = ST_FAULT;
768: 						end
769: 					end
770: 				end
771: 				ST_DCS_IR_APPLY:begin
772: 					if(flag_dcs_ir_commit == 1'b1)begin
773: 						state_next = ST_DCS_IR_WAIT;
774: 					end
775: 				end
776: 				ST_DCS_IR_WAIT:begin
777: 					if(flag_dcs_sample_qualified == 1'b1)begin
778: 						if(flag_search_in_window == 1'b1)begin
779: 							state_next = ST_NORMAL;
780: 						end else if(flag_dcs_ir_search_has_next == 1'b1)begin
781: 							state_next = ST_DCS_IR_APPLY;
782: 						end else begin
783: 							state_next = ST_FAULT;
784: 						end
785: 					end
786: 				end
787: 				ST_NORMAL:begin
788: 					if(flag_amb_check_start_allowed == 1'b1)begin
789: 						state_next = ST_AMB_RECHECK;
790: 					end
791: 				end
792: 				ST_AMB_RECHECK:begin
793: 					if(flag_amb_sample_qualified == 1'b1)begin
794: 						if(flag_search_in_window == 1'b1)begin
795: 							if(i_dcs_enable == 1'b1)begin
796: 								state_next = ST_DCS_REVALIDATE_WAIT;
797: 							end else begin
798: 								state_next = ST_NORMAL;
799: 							end
800: 						end else if(flag_amb_confirm_trigger == 1'b1)begin
801: 							state_next = ST_AMB_APPLY;
802: 						end
803: 					end
804: 				end
805: 				ST_DCS_REVALIDATE_WAIT:begin
806: 					if(i_dcs_revalidate_accept == 1'b1)begin
807: 						state_next = ST_DCS_REVALIDATE_R;
808: 					end
809: 				end
810: 				ST_DCS_REVALIDATE_R:begin
811: 					if(flag_dcs_sample_qualified == 1'b1)begin
812: 						if(flag_search_in_window == 1'b1)begin
813: 							state_next = ST_DCS_REVALIDATE_IR;
814: 						end else if(flag_dcs_r_confirm_trigger == 1'b1)begin
815: 							state_next = ST_DCS_R_APPLY;
816: 						end
817: 					end
818: 				end
819: 				ST_DCS_REVALIDATE_IR:begin
820: 					if(flag_dcs_sample_qualified == 1'b1)begin
821: 						if(flag_search_in_window == 1'b1)begin
822: 							state_next = ST_NORMAL;
823: 						end else if(flag_dcs_ir_confirm_trigger == 1'b1)begin
824: 							state_next = ST_DCS_IR_APPLY;
825: 						end
826: 					end
827: 				end
828: 				ST_FAULT:begin
829: 					state_next = ST_FAULT;
830: 				end
831: 				default:begin
832: 					state_next = ST_FAULT;
833: 				end
834: 			endcase
835: 		end
836: 	end
```

### L840：reg_context_next

```text
840: 	always@(*)begin
841: 		reg_context_next = reg_context;
842: 		reg_context_next[CTX_AMB_UPDATE_BIT] = 1'b0;
843: 		reg_context_next[CTX_DCS_R_UPDATE_BIT] = 1'b0;
844: 		reg_context_next[CTX_DCS_IR_UPDATE_BIT] = 1'b0;
845: 		reg_context_next[CTX_DCS_R_TRACK_ADJUST_BIT] = 1'b0;
846: 		reg_context_next[CTX_DCS_IR_TRACK_ADJUST_BIT] = 1'b0;
847: 		reg_context_next[CTX_AMB_SEQUENCE_DONE_BIT] = 1'b0;
848: 		reg_context_next[CTX_AMB_SEQUENCE_FAILED_BIT] = 1'b0;
849: 		reg_context_next[CTX_DCS_REVALIDATE_DONE_BIT] = 1'b0;
850: 		reg_context_next[CTX_DCS_REVALIDATE_FAILED_BIT] = 1'b0;
851: 		reg_context_next[CTX_CTRL_FAULT_EVENT_BIT] = 1'b0;
853: 		if(i_diag_clear_event == 1'b1)begin
854: 			reg_context_next[CTX_PROTOCOL_ERROR_BIT] = 1'b0;
855: 		end
857: 		if(flag_amb_commit == 1'b1)begin
858: 			reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b0;
859: 			if(flag_amb_commit_changes_code == 1'b1)begin
860: 				reg_context_next[CTX_AMB_CODE_LSB +: C_IDAC_CODE_WIDTH] = candidate_amb_code;
861: 				reg_context_next[CTX_AMB_EPOCH_LSB +: C_CODE_EPOCH_WIDTH] = amb_epoch_current + {{C_CODE_EPOCH_WIDTH - 1{1'b0}}, 1'b1};
862: 				reg_context_next[CTX_AMB_UPDATE_BIT] = 1'b1;
863: 				if(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] == 1'b1)begin
864: 					reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b1;
865: 					reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b0;
866: 					reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b0;
867: 					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
868: 					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
869: 					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
870: 					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
871: 				end
872: 			end
873: 		end
875: 		if(flag_dcs_r_commit == 1'b1)begin
876: 			reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b0;
877: 			reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
878: 			reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
879: 			if(flag_dcs_r_commit_changes_code == 1'b1)begin
880: 				reg_context_next[CTX_DCS_R_CODE_LSB +: C_IDAC_CODE_WIDTH] = candidate_dcs_r_code;
881: 				reg_context_next[CTX_DCS_R_EPOCH_LSB +: C_CODE_EPOCH_WIDTH] = dcs_r_epoch_current + {{C_CODE_EPOCH_WIDTH - 1{1'b0}}, 1'b1};
882: 				reg_context_next[CTX_DCS_R_UPDATE_BIT] = 1'b1;
883: 				if(reg_context[CTX_DCS_R_PENDING_TRACK_BIT] == 1'b1)begin
884: 					reg_context_next[CTX_DCS_R_TRACK_ADJUST_BIT] = 1'b1;
885: 				end
886: 			end
887: 			reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0;
888: 		end
890: 		if(flag_dcs_ir_commit == 1'b1)begin
891: 			reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b0;
892: 			reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
893: 			reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
894: 			if(flag_dcs_ir_commit_changes_code == 1'b1)begin
895: 				reg_context_next[CTX_DCS_IR_CODE_LSB +: C_IDAC_CODE_WIDTH] = candidate_dcs_ir_code;
896: 				reg_context_next[CTX_DCS_IR_EPOCH_LSB +: C_CODE_EPOCH_WIDTH] = dcs_ir_epoch_current + {{C_CODE_EPOCH_WIDTH - 1{1'b0}}, 1'b1};
897: 				reg_context_next[CTX_DCS_IR_UPDATE_BIT] = 1'b1;
898: 				if(reg_context[CTX_DCS_IR_PENDING_TRACK_BIT] == 1'b1)begin
899: 					reg_context_next[CTX_DCS_IR_TRACK_ADJUST_BIT] = 1'b1;
900: 				end
901: 			end
902: 			reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0;
903: 		end
905: 		if((state_current == ST_MANUAL_APPLY) && (i_frame_safe_boundary == 1'b1))begin
906: 			reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b1;
907: 		end
909: 		if((state_current == ST_AMB_WAIT) && (flag_amb_sample_qualified == 1'b1))begin
910: 			if(flag_search_in_window == 1'b1)begin
911: 				reg_context_next[CTX_AMB_SEARCH_DONE_BIT] = 1'b1;
912: 				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0;
913: 				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0;
914: 				if(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] == 1'b1)begin
915: 					reg_context_next[CTX_AMB_SEQUENCE_DONE_BIT] = 1'b1;
916: 					reg_context_next[CTX_AMB_RECHECK_ORIGIN_BIT] = 1'b0;
917: 				end else if(i_dcs_enable == 1'b1)begin
918: 					reg_context_next[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_min;
919: 					reg_context_next[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_max;
920: 					reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_initial_midpoint;
921: 					reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1;
922: 					reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0;
923: 				end else begin
924: 					reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b1;
925: 				end
926: 			end else if(flag_amb_search_has_next == 1'b1)begin
927: 				reg_context_next[CTX_AMB_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = amb_next_low;
928: 				reg_context_next[CTX_AMB_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = amb_next_high;
929: 				reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = amb_next_midpoint;
930: 				reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1;
931: 			end else begin
932: 				reg_context_next[CTX_AMB_SEARCH_DONE_BIT] = 1'b0;
933: 				reg_context_next[CTX_AMB_EXHAUSTED_BIT] = 1'b1;
934: 				reg_context_next[CTX_AMB_FAULT_BIT] = 1'b1;
935: 				if(reg_context[CTX_AMB_RECHECK_ORIGIN_BIT] == 1'b1)begin
936: 					reg_context_next[CTX_AMB_SEQUENCE_FAILED_BIT] = 1'b1;
937: 				end
938: 			end
939: 		end
941: 		if((state_current == ST_DCS_R_WAIT) && (flag_dcs_sample_qualified == 1'b1))begin
942: 			if(flag_search_in_window == 1'b1)begin
943: 				reg_context_next[CTX_DCS_R_SEARCH_DONE_BIT] = 1'b1;
944: 				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
945: 				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
946: 				if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b0)begin
947: 					reg_context_next[CTX_DCS_IR_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_ir_code_min;
948: 					reg_context_next[CTX_DCS_IR_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_ir_code_max;
949: 					reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_initial_midpoint;
950: 					reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1;
951: 					reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0;
952: 				end
953: 			end else if(flag_dcs_r_search_has_next == 1'b1)begin
954: 				reg_context_next[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_next_low;
955: 				reg_context_next[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_next_high;
956: 				reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_next_midpoint;
957: 				reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1;
958: 			end else begin
959: 				reg_context_next[CTX_DCS_R_SEARCH_DONE_BIT] = 1'b0;
960: 				reg_context_next[CTX_DCS_R_EXHAUSTED_BIT] = 1'b1;
961: 				reg_context_next[CTX_DCS_R_FAULT_BIT] = 1'b1;
962: 				if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b1)begin
963: 					reg_context_next[CTX_DCS_REVALIDATE_FAILED_BIT] = 1'b1;
964: 				end
965: 			end
966: 		end
968: 		if((state_current == ST_DCS_IR_WAIT) && (flag_dcs_sample_qualified == 1'b1))begin
969: 			if(flag_search_in_window == 1'b1)begin
970: 				reg_context_next[CTX_DCS_IR_SEARCH_DONE_BIT] = 1'b1;
971: 				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
972: 				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
973: 				if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b1)begin
974: 					reg_context_next[CTX_DCS_REVALIDATE_DONE_BIT] = 1'b1;
975: 					reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b0;
976: 				end else begin
977: 					reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b1;
978: 				end
979: 			end else if(flag_dcs_ir_search_has_next == 1'b1)begin
980: 				reg_context_next[CTX_DCS_IR_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_next_low;
981: 				reg_context_next[CTX_DCS_IR_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_next_high;
982: 				reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_next_midpoint;
983: 				reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1;
984: 			end else begin
985: 				reg_context_next[CTX_DCS_IR_SEARCH_DONE_BIT] = 1'b0;
986: 				reg_context_next[CTX_DCS_IR_EXHAUSTED_BIT] = 1'b1;
987: 				reg_context_next[CTX_DCS_IR_FAULT_BIT] = 1'b1;
988: 				if(reg_context[CTX_DCS_REVALIDATE_ORIGIN_BIT] == 1'b1)begin
989: 					reg_context_next[CTX_DCS_REVALIDATE_FAILED_BIT] = 1'b1;
990: 				end
991: 			end
992: 		end
994: 		if((state_current == ST_AMB_RECHECK) && (flag_amb_sample_qualified == 1'b1))begin
995: 			if(flag_search_in_window == 1'b1)begin
996: 				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0;
997: 				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0;
998: 				reg_context_next[CTX_AMB_SEQUENCE_DONE_BIT] = 1'b1;
999: 			end else if(flag_amb_confirm_trigger == 1'b1)begin
1000: 				reg_context_next[CTX_AMB_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_amb_code_min;
1001: 				reg_context_next[CTX_AMB_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_amb_code_max;
1002: 				reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = amb_initial_midpoint;
1003: 				reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1;
1004: 				reg_context_next[CTX_AMB_RECHECK_ORIGIN_BIT] = 1'b1;
1005: 				reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b0;
1006: 				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0;
1007: 				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0;
1008: 			end else if(flag_search_above_high == 1'b1)begin
1009: 				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = cnt_amb_high + 8'd1;
1010: 				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0;
1011: 			end else begin
1012: 				reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = cnt_amb_low + 8'd1;
1013: 				reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0;
1014: 			end
1015: 		end
1017: 		if((state_current == ST_DCS_REVALIDATE_WAIT) && (i_dcs_revalidate_accept == 1'b1))begin
1018: 			reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1019: 			reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1020: 			reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1021: 			reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1022: 			reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b1;
1023: 		end
1025: 		if((state_current == ST_DCS_REVALIDATE_R) && (flag_dcs_sample_qualified == 1'b1))begin
1026: 			if(flag_search_in_window == 1'b1)begin
1027: 				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1028: 				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1029: 			end else if(flag_dcs_r_confirm_trigger == 1'b1)begin
1030: 				reg_context_next[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_min;
1031: 				reg_context_next[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_max;
1032: 				reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_initial_midpoint;
1033: 				reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1;
1034: 				reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0;
1035: 				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1036: 				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1037: 			end else if(flag_search_above_high == 1'b1)begin
1038: 				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = cnt_dcs_r_high + 8'd1;
1039: 				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1040: 			end else begin
1041: 				reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = cnt_dcs_r_low + 8'd1;
1042: 				reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1043: 			end
1044: 		end
1046: 		if((state_current == ST_DCS_REVALIDATE_IR) && (flag_dcs_sample_qualified == 1'b1))begin
1047: 			if(flag_search_in_window == 1'b1)begin
1048: 				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1049: 				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1050: 				reg_context_next[CTX_DCS_REVALIDATE_DONE_BIT] = 1'b1;
1051: 				reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b0;
1052: 			end else if(flag_dcs_ir_confirm_trigger == 1'b1)begin
1053: 				reg_context_next[CTX_DCS_IR_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_ir_code_min;
1054: 				reg_context_next[CTX_DCS_IR_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_ir_code_max;
1055: 				reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_ir_initial_midpoint;
1056: 				reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1;
1057: 				reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0;
1058: 				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1059: 				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1060: 			end else if(flag_search_above_high == 1'b1)begin
1061: 				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = cnt_dcs_ir_high + 8'd1;
1062: 				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1063: 			end else begin
1064: 				reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = cnt_dcs_ir_low + 8'd1;
1065: 				reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1066: 			end
1067: 		end
1069: 		if(flag_track_sample_qualified == 1'b1)begin
1070: 			if(i_track_color_ir == 1'b0)begin
1071: 				if(flag_track_in_window == 1'b1)begin
1072: 					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1073: 					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1074: 				end else if(flag_dcs_r_confirm_trigger == 1'b1)begin
1075: 					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1076: 					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1077: 					if(flag_dcs_r_adjust_allowed == 1'b1)begin
1078: 						reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = flag_dcs_code_increase ?
1079: 							(dcs_r_code_current + {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}) :
1080: 							(dcs_r_code_current - {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1});
1081: 						reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1;
1082: 						reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b1;
1083: 					end
1084: 				end else if(flag_track_above_high == 1'b1)begin
1085: 					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = cnt_dcs_r_high + 8'd1;
1086: 					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1087: 				end else begin
1088: 					reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = cnt_dcs_r_low + 8'd1;
1089: 					reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1090: 				end
1091: 			end else begin
1092: 				if(flag_track_in_window == 1'b1)begin
1093: 					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1094: 					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1095: 				end else if(flag_dcs_ir_confirm_trigger == 1'b1)begin
1096: 					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1097: 					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1098: 					if(flag_dcs_ir_adjust_allowed == 1'b1)begin
1099: 						reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = flag_dcs_code_increase ?
1100: 							(dcs_ir_code_current + {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1}) :
1101: 							(dcs_ir_code_current - {{C_IDAC_CODE_WIDTH - 1{1'b0}}, 1'b1});
1102: 						reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1;
1103: 						reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b1;
1104: 					end
1105: 				end else if(flag_track_above_high == 1'b1)begin
1106: 					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = cnt_dcs_ir_high + 8'd1;
1107: 					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1108: 				end else begin
1109: 					reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = cnt_dcs_ir_low + 8'd1;
1110: 					reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1111: 				end
1112: 			end
1113: 		end
1115: 		if(flag_amb_check_start_allowed == 1'b1)begin
1116: 			reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0;
1117: 			reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0;
1118: 			reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b0;
1119: 		end
1121: 		if(flag_protocol_event == 1'b1)begin
1122: 			reg_context_next[CTX_PROTOCOL_ERROR_BIT] = 1'b1;
1123: 		end
1125: 		if(flag_control_cancel == 1'b1)begin
1126: 			reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b0;
1127: 			reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b0;
1128: 			reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b0;
1129: 			reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0;
1130: 			reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0;
1131: 			reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1132: 			reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1133: 			reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1134: 			reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1135: 			reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0;
1136: 			reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0;
1137: 			reg_context_next[CTX_AMB_RECHECK_ORIGIN_BIT] = 1'b0;
1138: 			reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b0;
1139: 			reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b0;
1140: 			reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b0;
1153: 			reg_context_next[CTX_AMB_FAULT_BIT] = 1'b0;
1154: 			reg_context_next[CTX_DCS_R_FAULT_BIT] = 1'b0;
1155: 			reg_context_next[CTX_DCS_IR_FAULT_BIT] = 1'b0;
1156: 			if(i_stop_ack_event || (i_run_enable == 1'b0))begin
1157: 				reg_context_next[CTX_AMB_SEARCH_DONE_BIT] = 1'b0;
1158: 				reg_context_next[CTX_DCS_R_SEARCH_DONE_BIT] = 1'b0;
1159: 				reg_context_next[CTX_DCS_IR_SEARCH_DONE_BIT] = 1'b0;
1160: 				reg_context_next[CTX_AMB_EXHAUSTED_BIT] = 1'b0;
1161: 				reg_context_next[CTX_DCS_R_EXHAUSTED_BIT] = 1'b0;
1162: 				reg_context_next[CTX_DCS_IR_EXHAUSTED_BIT] = 1'b0;
1163: 			end
1164: 		end
1166: 		if(i_start_ack_event == 1'b1)begin
1167: 			reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b0;
1168: 			reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b0;
1169: 			reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b0;
1170: 			reg_context_next[CTX_DCS_R_PENDING_TRACK_BIT] = 1'b0;
1171: 			reg_context_next[CTX_DCS_IR_PENDING_TRACK_BIT] = 1'b0;
1172: 			reg_context_next[CTX_DCS_R_HIGH_COUNT_LSB +: 8] = 8'd0;
1173: 			reg_context_next[CTX_DCS_R_LOW_COUNT_LSB +: 8] = 8'd0;
1174: 			reg_context_next[CTX_DCS_IR_HIGH_COUNT_LSB +: 8] = 8'd0;
1175: 			reg_context_next[CTX_DCS_IR_LOW_COUNT_LSB +: 8] = 8'd0;
1176: 			reg_context_next[CTX_AMB_HIGH_COUNT_LSB +: 8] = 8'd0;
1177: 			reg_context_next[CTX_AMB_LOW_COUNT_LSB +: 8] = 8'd0;
1178: 			reg_context_next[CTX_AMB_RECHECK_ORIGIN_BIT] = 1'b0;
1179: 			reg_context_next[CTX_DCS_REVALIDATE_ORIGIN_BIT] = 1'b0;
1180: 			reg_context_next[CTX_AMB_CHANGED_BIT] = 1'b0;
1181: 			reg_context_next[CTX_AMB_SEARCH_DONE_BIT] = 1'b0;
1182: 			reg_context_next[CTX_DCS_R_SEARCH_DONE_BIT] = 1'b0;
1183: 			reg_context_next[CTX_DCS_IR_SEARCH_DONE_BIT] = 1'b0;
1184: 			reg_context_next[CTX_AMB_EXHAUSTED_BIT] = 1'b0;
1185: 			reg_context_next[CTX_DCS_R_EXHAUSTED_BIT] = 1'b0;
1186: 			reg_context_next[CTX_DCS_IR_EXHAUSTED_BIT] = 1'b0;
1193: 			reg_context_next[CTX_PROTOCOL_ERROR_BIT] = 1'b0;
1194: 			reg_context_next[CTX_STARTUP_COMPLETE_BIT] = 1'b0;
1195: 			if((i_run_enable == 1'b0) || (flag_config_valid == 1'b0))begin
1196: 				reg_context_next[CTX_AMB_FAULT_BIT] = 1'b1;
1197: 				reg_context_next[CTX_DCS_R_FAULT_BIT] = i_dcs_enable;
1198: 				reg_context_next[CTX_DCS_IR_FAULT_BIT] = i_dcs_enable;
1199: 			end else if(i_idac_mode == 2'b00)begin
1200: 				reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = i_amb_enable ? i_amb_manual_code : C_RESET_CODE;
1201: 				reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_enable ? i_dcs_r_manual_code : C_RESET_CODE;
1202: 				reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_enable ? i_dcs_ir_manual_code : C_RESET_CODE;
1203: 				reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1;
1204: 				reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1;
1205: 				reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1;
1206: 			end else begin
1207: 				if(i_amb_enable == 1'b1)begin
1208: 					reg_context_next[CTX_AMB_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_amb_code_min;
1209: 					reg_context_next[CTX_AMB_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_amb_code_max;
1210: 					reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = amb_initial_midpoint;
1211: 					reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1;
1212: 				end else begin
1213: 					reg_context_next[CTX_AMB_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = C_RESET_CODE;
1214: 					reg_context_next[CTX_AMB_PENDING_VALID_BIT] = 1'b1;
1215: 				end
1216: 				if(i_dcs_enable == 1'b0)begin
1217: 					reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = C_RESET_CODE;
1218: 					reg_context_next[CTX_DCS_IR_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = C_RESET_CODE;
1219: 					reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1;
1220: 					reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] = 1'b1;
1221: 				end else if(i_amb_enable == 1'b0)begin
1222: 					reg_context_next[CTX_DCS_R_BOUND_LOW_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_min;
1223: 					reg_context_next[CTX_DCS_R_BOUND_HIGH_LSB +: C_IDAC_CODE_WIDTH] = i_dcs_r_code_max;
1224: 					reg_context_next[CTX_DCS_R_PENDING_CODE_LSB +: C_IDAC_CODE_WIDTH] = dcs_r_initial_midpoint;
1225: 					reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] = 1'b1;
1226: 				end
1227: 			end
1228: 		end
1231: 		if(reg_context_next[CTX_AMB_PENDING_VALID_BIT] == 1'b1 && reg_context[CTX_AMB_PENDING_VALID_BIT] == 1'b0)begin
1232: 			reg_context_next[CTX_AMB_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] = i_run_generation;
1233: 		end
1234: 		if(reg_context_next[CTX_DCS_R_PENDING_VALID_BIT] == 1'b1 && reg_context[CTX_DCS_R_PENDING_VALID_BIT] == 1'b0)begin
1235: 			reg_context_next[CTX_DCS_R_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] = i_run_generation;
1236: 		end
1237: 		if(reg_context_next[CTX_DCS_IR_PENDING_VALID_BIT] == 1'b1 && reg_context[CTX_DCS_IR_PENDING_VALID_BIT] == 1'b0)begin
1238: 			reg_context_next[CTX_DCS_IR_PENDING_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] = i_run_generation;
1239: 		end
1242: 		if((reg_context_next[CTX_AMB_FAULT_BIT] || reg_context_next[CTX_DCS_R_FAULT_BIT] || reg_context_next[CTX_DCS_IR_FAULT_BIT]) && !(reg_context[CTX_AMB_FAULT_BIT] || reg_context[CTX_DCS_R_FAULT_BIT] || reg_context[CTX_DCS_IR_FAULT_BIT]))begin
1243: 			reg_context_next[CTX_CTRL_FAULT_EVENT_BIT] = 1'b1;
1244: 			if(i_start_ack_event == 1'b1)begin
1245: 				reg_context_next[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] = 1'b0;
1246: 			end else begin
1247: 				reg_context_next[CTX_CTRL_FAULT_IDENTITY_VALID_BIT] = 1'b1;
1248: 				reg_context_next[CTX_CTRL_FAULT_FRAME_ID_LSB +: C_FRAME_ID_WIDTH] = i_search_frame_id;
1249: 				reg_context_next[CTX_CTRL_FAULT_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH] = i_search_sample_index;
1250: 				reg_context_next[CTX_CTRL_FAULT_COLOR_BIT] = i_search_color_ir;
1251: 				reg_context_next[CTX_CTRL_FAULT_FRAME_TYPE_LSB +: 2] = i_search_frame_type;
1252: 				reg_context_next[CTX_CTRL_FAULT_PRECISION_BIT] = i_search_precision_mode;
1253: 				reg_context_next[CTX_CTRL_FAULT_GENERATION_LSB +: C_RUN_GENERATION_WIDTH] = i_run_generation;
1254: 			end
1255: 		end
1256: 	end
```

### L1260：reg_context

```text
1260: 	always@(posedge i_clk or negedge i_rstn)begin
1261: 		if(i_rstn == 1'b0)begin
1262: 			reg_context <= {CONTEXT_WIDTH{1'b0}};
1263: 		end else begin
1264: 			reg_context <= reg_context_next;
1265: 		end
1266: 	end
```

## 文末汇总

(c)：V1-IDAC-01（中，START覆盖取消后的pending）、V1-IDAC-02（低，活动故障时诊断清除）；待定：T-IDAC-01～04。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
