# V1 独立同拍冲突审查：SSW

固定基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`；RTL：`rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v`。以下行号全部属于该基线。使用仓库 erie-verilog-generator analyze/formatter AST；只读静态复核，无仿真/综合声明，未访问被隔离的审查分支/目录。依据C09，B交接§3、生命周期/F009明确用户裁定。2 MHz、5000/625拍及模拟侧9/15位SAR、DONE保持、2–20拍延迟为本审查前提。

## 1. 上游追踪与事件定义

Top L1006–1011扇入manager START/STOP、独立注册abort/diag和scheduler tick；L1050–1054接AMI唯一完成/作废/序号/物理idle。scheduler固定NORMAL RED/IR接管点0/160、CAL local0（FSC L453–455），owner候选CAL>RED>IR（L463–465），唯一期望提交来自FSC的`valid && AMI ready`（L473）。SSW ready独立产生，owner身份逐字段比对（SSW L428–431），commit/error在L434–435分为成功/失败互补；release需已有owner且同序号、同代际（L436）。

R=owner release；O=owner commit fire；A=abort；S=`flag_start_restore`（START && !owner && ADC idle，L449）；Wc=某槽context fire；Lc=某槽wave_last；F=首次blocking故障；D=diag && wrapper idle。所有寄存器异步reset优先，依据C09复位规则；输入电平reset和事件可同时高，属于(b)，不是(a)。

START/STOP由manager状态与命令冲突排除同拍（manager L451–464）；START/abort及diag/新错误**没有该排除**，Top L328–360的寄存网相互独立。O/R在构造上(a)：O要求!owner，R要求owner。O/A(a)：L434含!abort。R/A可同拍(b)，匹配释放应优先，不能仅因abort保留一个已完成owner。

## 2. 全部对象的条件顺序和同拍处置

| 对象及always起点 | 全部顺序（reset省写但最高） | 条件对与结论 |
|---|---|---|
| adc_owner_inflight_o L521 | R清 > A保持 > O置1 > 保持 | R/A(b)，SSW-22/C09释放旧owner；O/R、O/A(a)，上述直接谓词；STOP不清owner(b)，等待真实DONE/作废 |
| reg_owner_q3_closed_o L534 | R清 > O清 > OR当前Q3已过组合资格 | R/Q3到期可同拍(b)，释放后清；O/R(a)；Q3累计不受tick回0影响(b)，保留跨帧释放资格 |
| calibration_timeout_sticky_o L547 | S清 > 内部 D清；随后CAL local385且has_owner置1 | D/置位(a)，has_owner使wrapper idle=0；S/置位(a)，S要求!owner；R/local385可同拍时旧has_owner仍1，见T-SSW-01 |
| owner_deadline_timeout_sticky_o L563 | S清 > 内部D清；随后red/ir/cal timeout置1 | D/timeout(a)，timeout需context_valid而idle需三个context0；S/timeout可在未提交残留context且旧tick=deadline+1成立，S清(b)，新RUN丢弃旧诊断，F009 L-6/C09 START规则；多timeout同拍均置1(b) |
| switch_protocol_error_sticky_o L579、transaction_mismatch_sticky_o L595 | S清 > 内部D清；随后新switch_error/done_mismatch置1 | D/新错配可同拍(b)，新置位胜出；S/新错配可同拍，S覆盖新故障，且fault_valid却仍由F产生，见T-SSW-02；合法生产输入不存在无owner完成，但边界防御仍须测试 |
| reg_control_vector L612 | A清 > reg_control_next装载 | abort与static/任意波形可同拍(b)，寄存清零优先；组合static分支虽在abort前选择，但注册输出被A清，不形成输出脉冲；reset同理 |
| reg_run_active L783 | S置1 > (!RUN或stop_pending)&&idle 清 > 保持 | S/idle清可同拍(b)，新RUN优先；S/A可能同拍而A不直接影响该寄存器，见T-SSW-02；STOP时已有wave/owner继续安全收尾(b) |
| flag_stop_pending L796 | A置1 > STOP置1 > (!run_active&&idle)清 > S清 | A/STOP(b)，同值；STOP/idle清(b)，取消优先；S/idle清(b)，同值；S/A可同拍，stop=1、run_active=1组合如何恢复见T-SSW-02 |
| flag_cal_context_valid L956、flag_ir_context_valid L1104、flag_red_context_valid L1291 | A清 > S清 > 内部Lc清；随后Wc置1 | A/Wc(a)，Wc在L410含!A；S/Wc生产(a)：START前FSC旧STARTED=0，正常无wavevalid；Lc/Wc(a)，RED接管0与last307/317、IR160与467/477、CAL0与283直接相反；A/S(b)，都清context；STOP不立即清context(b)，F009既定预建立排空语义 |
| 各CAL/IR/RED载荷寄存器（详见覆盖附录） | A保持 > Wc装载；reset各初值 | A/Wc(a)，fire门控；RED/IR/CAL W两两(a)，NORMAL/CAL由同一FSC frame_mode解码互斥，RED/IR同时需tick0/160矛盾；S不清载荷但清valid(b)，F009 L-6允许下次整体覆盖；STOP/Wc生产(a)，FSC的wavevalid含同拍STOP/!RUN门控 |
| reg_owner_abort_seen L1309 | R清 > A且owner置1 > O清 | R/A(b)，旧owner完成胜出；O/A、O/R(a)；STOP不设置abort_seen(b)，已提交owner安全波形继续，结果由AMI discard控制 |
| owner sample_index/generation/frame_id/color/type/precision/slot L1324等 | A保持 > R保持 > O装载 | R/A(b)，均保持原身份；O/A、O/R(a)；同一O选择RED>IR>CAL，CAL/NORMAL互斥，IR候选明文!red_window（L425–427），不能跳过RED |
| reg_owner_cal_subframe L1363 | O装载；其余保持 | A/O、R/O(a)，构造门控同上；STOP不改子帧身份(b)，匹配late CAL owner须保持 |
| flag_ssw_fault_valid L1431 | F置1 > 默认0 | F与S/D可能同拍；valid无恢复门控，见T-SSW-02；同一阻断episode F由!blocking限定，连续level错误在置sticky后不再新发(b) |
| flag_ssw_fault_identity_valid L1442 | S清 > 内部D清；随后F按commit_error > done_mismatch&&owner > 无身份装载 | D/F可同拍(b)，新故障胜出；S/F可同拍则idvalid清而valid1，见T-SSW-02；两错误同拍时commit_error身份优先，C09未给同源身份仲裁，T-SSW-03 |
| reg_ssw_fault_frame_id/sample_index/color/type/precision/generation L1464–1529 | F：commit_error取候选身份 > done_mismatch且owner取原身份；reset清，其余保持 | 所有字段同谓词、同顺序(b)，没有部分字段混装；新fault与owner释放，done_mismatch与合法release(a)，L435/436；无身份时公共输出归零（L511–516），内部旧字段保持(b) |

## 3. 组合控制字逐字段冲突矩阵（always L624）

全部控制字段：EN_TIA、LED_CODE/LED_DATA、LED_R/IR、EN_TEST、CLK_BUF、IREF_IDAC、Q1_9/15、AFERST、IREF_9/15、Q2/Q3、TIAEN、EN_15、EN_9_AMB/DC/IREF、EN_15_AMB/DC/IREF、AMB9/DC9/AMB15/DC15、S_IN。默认全0 → STATIC_BIAS或动态分支 → 动态中RED段 → IR段 → CAL段。CTRL编号按L252–283定义，无重叠切片。

| 组合条件对/字段 | 可同拍证明、覆盖方式和处置 |
|---|---|
| static/动态 | (a) if/else；static与任何wave即使残留并存，也只执行static。abort注册优先清输出 (b) |
| RED/IR包络 | **可同拍**：正常双光各在0/160成功锁存，context有效至307/317与467/477，SAR9共同活动[204,318)，SAR15[187,308)。不依赖owner释放。C09 §4.5明确IR接管不等RED owner。不能以一ADC owner断言两个包络互斥 |
| IREF_IDAC（RED/IR） | L642及L690均OR前值；两独立IDAC窗口[263,303)/[423,463)或[246,306)/[406,466)，并集(b)，无额外重叠 |
| IREF_9/15 | 同精度双方只写1；SAR9得到[44,478)并集，SAR15相应并集(b)，符合C09 §4.6白名单 |
| EN_15_IREF/AMB/DC | RED先写，IR L695–700 OR前值；包络重叠可同拍，白名单允许并集(b)，C09 §4.6；DC在NORMAL资格下开启 |
| EN_9_IREF/AMB/DC | IR L707–710 **直接赋值**，覆盖RED L657–660，(c)，V1-SSW-01 |
| AMB/DC码总线（各精度、两色） | 每段逐bit OR旧值（L651–664、L701–714）。精度一致由FSC每帧冻结、SSW接管比对当前committed保证；9位RED码窗[258,310)/[266,310)，IR[418,470)/[426,470)，15位RED[203,308)/[151,308)，IR[363,468)/[311,468)，**有效码窗两两不重叠**(a)，因此OR不会合成两个不同码。另精度的片段默认0。不能把“包络可重叠”误当码窗可重叠 |
| EN_TIA/AFERST/TIAEN/Q2/Q3（两色owner段） | RED先写，IR多数OR；TIAEN回读EN_TIA。单一owner slot导致has_owner_RED/IR两两(a)，即使两个wave包络同时高，也只有一个owner段执行；双方在固定采样区间相距160拍，不出现额外脉冲(b) |
| Q1_9/15、EN_15（两色owner段） | IR直接覆盖但两has_owner不能同拍(a)，同一reg_owner_slot编码；release/O也不能同拍。提前DONE会截断原owner资格，应做T-SSW-04；不能由“else最后覆盖”独自报缺陷 |
| LED_R/IR、LED_CODE/DATA | 两has_owner(a)；固定两色LED窗也不交集(a)。PD模式输出锁存LEDDAC，固定电流!input_source=0使LED关闭(b)。CAL仅DCS且owner时写二选一颜色；AMB无LED(b) |
| CAL/RED、CAL/IR | 在生产连接(a)：FSC两模式同一状态片段互斥；normal context最迟477清，比宏帧4999早4522拍；CAL最迟local283清，比624边界早342拍；下一帧没有旧活动context。abort清三个valid，新START按L-6清。对异常跳tick或非法双模式输入不作互斥声明，作为T-SSW-05。若异常三段同时执行，CAL直接覆盖共享字段及码总线，必须由协议保护阻断 |
| EN_TEST、CLK_BUF、S_IN | static/动态(a)；EN_TEST动态固定current标志一次写，CLK_BUF/S_IN动态默认0。static的四组码总线从未置位(b)，C09 §8.5 |

## 4. (c) 发现

### V1-SSW-01：双光SAR9的IR包络清掉RED三个建立使能（高）

在正常双光SAR9帧，RED上下文tick0、IR上下文tick160接管。L411/412给RED/IR活动包络[44,318)和[204,478)，同时高的区间为[204,318)。L657设RED EN_9_IREF窗[236,308)，L658/659设RED EN_9_AMB/DC窗[256,310)。后执行的IR段L689、L707–710分别赋IR窗[396,468)、[416,470)；在整个RED有效使能窗这些谓词全为0，覆盖RED的1。

因此实际公共输出丢失RED IREF使能72拍（36 µs）及RED AMB/DC使能54拍（27 µs）。reg_control_vector在L618注册，所以以上是**组合输入tick窗口**；输出对采样沿注册，波形比较应使用与RTL寄存延迟一致的坐标，不把下一拍显示误报成新的off-by-one。受影响输出在L478–480映射到控制片段；码总线仍按RED窗输出，不能以码总线正常推断模拟使能正常。

C09 §4.6仅允许IREF_9跨色连续保持，其他SAR9使能须保留各自独立颜色窗口；“不许重叠”不意味着后色包络可以删掉前色窗口。模拟设计者确认这些窗口即需求，不能把它降格成内部注释不一致。该反例无需任何异常DONE、反压、非法参数或测试注入，影响每个成功接管IR的双光SAR9帧。SAR15的相同三字段L695–700采用OR而保留RED。这里只报告缺陷，不提供或应用RTL补丁。

## 5. 待定项

| ID | 场景、需要的仿真 |
|---|---|
| T-SSW-01 | CAL匹配release恰在local385：旧has_owner仍1，L556置迟到sticky，虽然同拍完成释放。扫描384/385/386，明确合同“tick385仍未完成”是否包含该采样沿已完成；B §3.5只规定诊断不终止burst，没有给该同拍判据 |
| T-SSW-02 | START与外部注册abort、START与异常DONE/非法波形同拍。S不含!abort，新run_active置1而stop_pending置1，valid故障可能1、cause/sticky/idvalid0。生产正常START/旧owner互斥已追manager empty，但独立abort未互斥。全链扫描±2拍，验证取消优先及记录原子性，不能强制manager同时发START/STOP |
| T-SSW-03 | 非法commit与错配DONE同拍，六fault字段统一取commit候选。证明协议错误输出稳定并评估C24首故障身份需要；生产正确连接不产生非法commit，属于防御性测试 |
| T-SSW-04 | 按设计者2–20拍转换延迟，DONE/CLK_DOUT出现在Q3结束前、同拍、之后，owner release会移除has_owner并截断尾部Q1/AFE/TIA资格。C09完整网表窗和真实模拟完成前提是否一致，应联测ADC两精度并逐tick比对；不将Q3门控当成物理owner不得释放的理由 |
| T-SSW-05 | 跳tick、非法双frame_active、CAL旧context与NORMAL新context。明确协议检测后下一拍输出安全与abort时延。生产自然递增下的互斥证据不能外推到故障输入 |

## 6. 覆盖清单

formatter AST识别64个always：63个时序块及1个组合块。全部已逐行覆盖：L521、534、547、563、579、595、612、624、783、796；CAL载荷L813、826、839、852、865、878、891、904、917、930、943和valid L956；IR载荷L974、987、1000、1013、1026、1039、1052、1065、1078、1091和valid L1104；RED载荷L1122、1135、1148、1161、1174、1187、1226、1239、1252、1265、1278和valid L1291；IR/CAL generation L1200/1213；owner L1309、1324、1337、1350、1363、1372、1385、1398、1411；fault L1431、1442、1464、1477、1490、1503、1516、1529。

载荷寄存器完整名单：每色 `reg_{red,ir,cal}_{amb_code,amb_epoch,dc_code,dc_epoch,frame_id,frame_type,input_source,leddac_code,optical_mode,precision,generation}`，CAL另有`reg_cal_color_ir`；三valid；owner `adc_owner_inflight_o, reg_owner_{q3_closed_o,abort_seen,sample_index,generation,frame_id,cal_subframe,color_ir,frame_type,precision_mode,slot}`；四sticky；run/stop；control_next/vector；fault valid/identity_valid和六字段。组合所有CTRL字段见§3，无只检查寄存器而跳过组合覆盖。

接受的旧合同差异：L-6 START清未提交残留context、作废新增release、local385超时只诊断不撤销burst，按B §3.5–3.7处理；不当成新增缺陷。

## 7. 文末汇总

(c)：V1-SSW-01（高，正常双光SAR9共享使能被覆盖）。待定：T-SSW-01～05。主发现有静态逐tick反例；尚无本次运行的模拟或系统仿真证据。

## 补充覆盖证据：技能AST与全部always原始顺序

技能静态门禁的compile/AST均passed；compile在这里仅指formatter AST+静态lint，testbench/toolchain未请求，没有外部编译、仿真或综合。
基线严格风格门禁：10 error(s)，0 strict warning(s)。现有源文件不修复，门禁成功也不能证明同拍功能正确。

### L521：adc_owner_inflight_o

```text
521: 	always@(posedge i_clk or negedge i_rstn)begin
522: 		if(i_rstn == 1'b0)begin
523: 			adc_owner_inflight_o <= 1'b0;
524: 		end else if(flag_owner_release == 1'b1)begin
525: 			adc_owner_inflight_o <= 1'b0;
526: 		end else if(i_control_abort_event == 1'b1)begin
527: 			adc_owner_inflight_o <= adc_owner_inflight_o;
528: 		end else if(flag_owner_commit_fire == 1'b1)begin
529: 			adc_owner_inflight_o <= 1'b1;
530: 		end
531: 	end
```

### L534：reg_owner_q3_closed_o

```text
534: 	always@(posedge i_clk or negedge i_rstn)begin
535: 		if(i_rstn == 1'b0)begin
536: 			reg_owner_q3_closed_o <= 1'b0;
537: 		end else if(flag_owner_release == 1'b1)begin
538: 			reg_owner_q3_closed_o <= 1'b0;
539: 		end else if(flag_owner_commit_fire == 1'b1)begin
540: 			reg_owner_q3_closed_o <= 1'b0;
541: 		end else begin
542: 			reg_owner_q3_closed_o <= reg_owner_q3_closed_o || flag_owner_q3_closed_combo;
543: 		end
544: 	end
```

### L547：calibration_timeout_sticky_o

```text
547: 	always@(posedge i_clk or negedge i_rstn)begin
548: 		if(i_rstn == 1'b0)begin
549: 			calibration_timeout_sticky_o <= 1'b0;
550: 		end else if(flag_start_restore == 1'b1)begin
551: 			calibration_timeout_sticky_o <= 1'b0;
552: 		end else begin
553: 			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
554: 				calibration_timeout_sticky_o <= 1'b0;
555: 			end
556: 			if(i_calibration_frame_active == 1'b1 && (i_calibration_local_tick == CAL_COMMIT_TICK) && flag_cal_has_owner == 1'b1)begin
557: 				calibration_timeout_sticky_o <= 1'b1;
558: 			end
559: 		end
560: 	end
```

### L563：owner_deadline_timeout_sticky_o

```text
563: 	always@(posedge i_clk or negedge i_rstn)begin
564: 		if(i_rstn == 1'b0)begin
565: 			owner_deadline_timeout_sticky_o <= 1'b0;
566: 		end else if(flag_start_restore == 1'b1)begin
567: 			owner_deadline_timeout_sticky_o <= 1'b0;
568: 		end else begin
569: 			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
570: 				owner_deadline_timeout_sticky_o <= 1'b0;
571: 			end
572: 			if(flag_red_timeout == 1'b1 || flag_ir_timeout == 1'b1 || flag_cal_timeout == 1'b1)begin
573: 				owner_deadline_timeout_sticky_o <= 1'b1;
574: 			end
575: 		end
576: 	end
```

### L579：switch_protocol_error_sticky_o

```text
579: 	always@(posedge i_clk or negedge i_rstn)begin
580: 		if(i_rstn == 1'b0)begin
581: 			switch_protocol_error_sticky_o <= 1'b0;
582: 		end else if(flag_start_restore == 1'b1)begin
583: 			switch_protocol_error_sticky_o <= 1'b0;
584: 		end else begin
585: 			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
586: 				switch_protocol_error_sticky_o <= 1'b0;
587: 			end
588: 			if(flag_switch_protocol_error_condition == 1'b1)begin
589: 				switch_protocol_error_sticky_o <= 1'b1;
590: 			end
591: 		end
592: 	end
```

### L595：transaction_mismatch_sticky_o

```text
595: 	always@(posedge i_clk or negedge i_rstn)begin
596: 		if(i_rstn == 1'b0)begin
597: 			transaction_mismatch_sticky_o <= 1'b0;
598: 		end else if(flag_start_restore == 1'b1)begin
599: 			transaction_mismatch_sticky_o <= 1'b0;
600: 		end else begin
601: 			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
602: 				transaction_mismatch_sticky_o <= 1'b0;
603: 			end
604: 			if(flag_done_mismatch == 1'b1)begin
605: 				transaction_mismatch_sticky_o <= 1'b1;
606: 			end
607: 		end
608: 	end
```

### L612：reg_control_vector

```text
612: 	always@(posedge i_clk or negedge i_rstn)begin
613: 		if(i_rstn == 1'b0)begin
614: 			reg_control_vector <= {CONTROL_WIDTH{1'b0}};
615: 		end else if(i_control_abort_event == 1'b1)begin
616: 			reg_control_vector <= {CONTROL_WIDTH{1'b0}};
617: 		end else begin
618: 			reg_control_vector <= reg_control_next;
619: 		end
620: 	end
```

### L624：reg_control_next

```text
624: 	always@(*)begin
625: 		reg_control_next = {CONTROL_WIDTH{1'b0}};
626: 		if(flag_static_active == 1'b1)begin
627: 			reg_control_next[CTRL_EN_TEST] = 1'b1;
628: 			reg_control_next[CTRL_CLK_BUF] = 1'b1;
629: 			reg_control_next[CTRL_IREF_IDAC] = 1'b1;
630: 			reg_control_next[CTRL_AFERST] = 1'b1;
631: 			reg_control_next[CTRL_IREF_9] = 1'b1;
632: 			reg_control_next[CTRL_IREF_15] = 1'b1;
633: 			reg_control_next[CTRL_TIAEN] = 1'b1;
634: 			reg_control_next[CTRL_EN_9_AMB] = 1'b1;
635: 			reg_control_next[CTRL_EN_9_DC] = 1'b1;
636: 			reg_control_next[CTRL_EN_15_AMB] = 1'b1;
637: 			reg_control_next[CTRL_EN_15_DC] = 1'b1;
638: 			reg_control_next[CTRL_S_IN_H:CTRL_S_IN_L] = i_test_mux_ctrl;
639: 		end else if(reg_run_active == 1'b1 && i_control_abort_event == 1'b0)begin
640: 			reg_control_next[CTRL_EN_TEST] = flag_fixed_current_active;
641: 			if(flag_red_wave_active == 1'b1)begin
642: 				reg_control_next[CTRL_IREF_IDAC] = reg_control_next[CTRL_IREF_IDAC] ||
643: 				(reg_red_precision ? ((i_macro_tick >= 13'd246) && (i_macro_tick < 13'd306)):
644: 				((i_macro_tick >= 13'd263) && (i_macro_tick < 13'd303)));
645: 				if(reg_red_precision == 1'b1)begin
646: 					reg_control_next[CTRL_IREF_15] = 1'b1;
647: 					reg_control_next[CTRL_EN_15_IREF] = (i_macro_tick >= 13'd27) && (i_macro_tick < 13'd306);
648: 					reg_control_next[CTRL_EN_15_AMB] = (i_macro_tick >= 13'd47) && (i_macro_tick < 13'd308);
649: 					reg_control_next[CTRL_EN_15_DC] = (i_macro_tick >= 13'd47) && (i_macro_tick < 13'd308) &&
650: 					(reg_red_frame_type != FRAME_TYPE_AMB);
651: 					reg_control_next[CTRL_AMB15_H:CTRL_AMB15_L] = reg_control_next[CTRL_AMB15_H:CTRL_AMB15_L] | (((i_macro_tick >= 13'd203) && (i_macro_tick < 13'd308) &&
652: 					(reg_red_frame_type == FRAME_TYPE_NORMAL)) ? reg_red_amb_code : 8'h00);
653: 					reg_control_next[CTRL_DC15_H:CTRL_DC15_L] = reg_control_next[CTRL_DC15_H:CTRL_DC15_L] | (((i_macro_tick >= 13'd151) && (i_macro_tick < 13'd308) &&
654: 					(reg_red_frame_type == FRAME_TYPE_NORMAL)) ? reg_red_dc_code : 8'h00);
655: 				end else begin
656: 					reg_control_next[CTRL_IREF_9] = 1'b1;
657: 					reg_control_next[CTRL_EN_9_IREF] = (i_macro_tick >= 13'd236) && (i_macro_tick < 13'd308);
658: 					reg_control_next[CTRL_EN_9_AMB] = (i_macro_tick >= 13'd256) && (i_macro_tick < 13'd310);
659: 					reg_control_next[CTRL_EN_9_DC] = (i_macro_tick >= 13'd256) && (i_macro_tick < 13'd310) &&
660: 					(reg_red_frame_type != FRAME_TYPE_AMB);
661: 					reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] = reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] | (((i_macro_tick >= 13'd258) && (i_macro_tick < 13'd310)) ?
662: 					reg_red_amb_code : 8'h00);
663: 					reg_control_next[CTRL_DC9_H:CTRL_DC9_L] = reg_control_next[CTRL_DC9_H:CTRL_DC9_L] | (((i_macro_tick >= 13'd266) && (i_macro_tick < 13'd310) &&
664: 					(reg_red_frame_type != FRAME_TYPE_AMB)) ? reg_red_dc_code : 8'h00);
665: 				end
666: 				if(flag_red_has_owner == 1'b1)begin
667: 					reg_control_next[CTRL_EN_TIA] = (i_macro_tick >= (reg_red_precision ? 13'd266 : 13'd283)) &&
668: 					(i_macro_tick < (reg_red_precision ? 13'd305 : 13'd303));
669: 					reg_control_next[CTRL_AFERST] = (i_macro_tick >= (reg_red_precision ? 13'd266 : 13'd283)) &&
670: 					(i_macro_tick < (reg_red_precision ? 13'd286 : 13'd295));
671: 					reg_control_next[CTRL_TIAEN] = reg_control_next[CTRL_EN_TIA];
672: 					reg_control_next[CTRL_Q2] = (i_macro_tick >= (reg_red_precision ? 13'd287 : 13'd296)) &&
673: 					(i_macro_tick < (reg_red_precision ? 13'd295 : 13'd298));
674: 					reg_control_next[CTRL_Q3] = (i_macro_tick >= (reg_red_precision ? 13'd296 : 13'd299)) &&
675: 					(i_macro_tick < (reg_red_precision ? 13'd304 : 13'd301));
676: 					if(reg_red_precision == 1'b1)begin
677: 						reg_control_next[CTRL_Q1_15] = (i_macro_tick >= 13'd284) && (i_macro_tick < 13'd305);
678: 						reg_control_next[CTRL_EN_15] = reg_control_next[CTRL_Q1_15];
679: 					end else begin
680: 						reg_control_next[CTRL_Q1_9] = (i_macro_tick >= 13'd293) && (i_macro_tick < 13'd302);
681: 					end
682: 					if((reg_red_frame_type != FRAME_TYPE_AMB) && (i_macro_tick >= (reg_red_precision ? 13'd295 : 13'd298)) && (i_macro_tick < (reg_red_precision ? 13'd304 : 13'd301)))begin
683: 						reg_control_next[CTRL_LED_R] = !reg_red_input_source;
684: 						reg_control_next[CTRL_LED_CODE] = !reg_red_input_source;
685: 						reg_control_next[CTRL_LED_DATA_H:CTRL_LED_DATA_L] = reg_red_leddac_code;
686: 					end
687: 				end
688: 			end
689: 			if(flag_ir_wave_active == 1'b1)begin
690: 				reg_control_next[CTRL_IREF_IDAC] = reg_control_next[CTRL_IREF_IDAC] ||
691: 				(reg_ir_precision ? ((i_macro_tick >= 13'd406) && (i_macro_tick < 13'd466)):
692: 				((i_macro_tick >= 13'd423) && (i_macro_tick < 13'd463)));
693: 				if(reg_ir_precision == 1'b1)begin
694: 					reg_control_next[CTRL_IREF_15] = 1'b1;
695: 					reg_control_next[CTRL_EN_15_IREF] = reg_control_next[CTRL_EN_15_IREF] ||
696: 					((i_macro_tick >= 13'd187) && (i_macro_tick < 13'd466));
697: 					reg_control_next[CTRL_EN_15_AMB] = reg_control_next[CTRL_EN_15_AMB] ||
698: 					((i_macro_tick >= 13'd207) && (i_macro_tick < 13'd468));
699: 					reg_control_next[CTRL_EN_15_DC] = reg_control_next[CTRL_EN_15_DC] ||
700: 					(((i_macro_tick >= 13'd207) && (i_macro_tick < 13'd468)) && (reg_ir_frame_type == FRAME_TYPE_NORMAL));
701: 					reg_control_next[CTRL_AMB15_H:CTRL_AMB15_L] = reg_control_next[CTRL_AMB15_H:CTRL_AMB15_L] | (((i_macro_tick >= 13'd363) && (i_macro_tick < 13'd468) &&
702: 					(reg_ir_frame_type == FRAME_TYPE_NORMAL)) ? reg_ir_amb_code : 8'h00);
703: 					reg_control_next[CTRL_DC15_H:CTRL_DC15_L] = reg_control_next[CTRL_DC15_H:CTRL_DC15_L] | (((i_macro_tick >= 13'd311) && (i_macro_tick < 13'd468) &&
704: 					(reg_ir_frame_type == FRAME_TYPE_NORMAL)) ? reg_ir_dc_code : 8'h00);
705: 				end else begin
706: 					reg_control_next[CTRL_IREF_9] = 1'b1;
707: 					reg_control_next[CTRL_EN_9_IREF] = (i_macro_tick >= 13'd396) && (i_macro_tick < 13'd468);
708: 					reg_control_next[CTRL_EN_9_AMB] = (i_macro_tick >= 13'd416) && (i_macro_tick < 13'd470);
709: 					reg_control_next[CTRL_EN_9_DC] = (i_macro_tick >= 13'd416) && (i_macro_tick < 13'd470) &&
710: 					(reg_ir_frame_type == FRAME_TYPE_NORMAL);
711: 					reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] = reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] | (((i_macro_tick >= 13'd418) && (i_macro_tick < 13'd470)) ?
712: 					reg_ir_amb_code : 8'h00);
713: 					reg_control_next[CTRL_DC9_H:CTRL_DC9_L] = reg_control_next[CTRL_DC9_H:CTRL_DC9_L] | (((i_macro_tick >= 13'd426) && (i_macro_tick < 13'd470) &&
714: 					(reg_ir_frame_type == FRAME_TYPE_NORMAL)) ? reg_ir_dc_code : 8'h00);
715: 				end
716: 				if(flag_ir_has_owner == 1'b1)begin
717: 					reg_control_next[CTRL_EN_TIA] = reg_control_next[CTRL_EN_TIA] ||
718: 					((i_macro_tick >= (reg_ir_precision ? 13'd426 : 13'd443)) &&
719: 					(i_macro_tick < (reg_ir_precision ? 13'd465 : 13'd463)));
720: 					reg_control_next[CTRL_AFERST] = reg_control_next[CTRL_AFERST] ||
721: 					((i_macro_tick >= (reg_ir_precision ? 13'd426 : 13'd443)) &&
722: 					(i_macro_tick < (reg_ir_precision ? 13'd446 : 13'd455)));
723: 					reg_control_next[CTRL_TIAEN] = reg_control_next[CTRL_EN_TIA];
724: 					reg_control_next[CTRL_Q2] = reg_control_next[CTRL_Q2] ||
725: 					((i_macro_tick >= (reg_ir_precision ? 13'd447 : 13'd456)) &&
726: 					(i_macro_tick < (reg_ir_precision ? 13'd455 : 13'd458)));
727: 					reg_control_next[CTRL_Q3] = reg_control_next[CTRL_Q3] ||
728: 					((i_macro_tick >= (reg_ir_precision ? 13'd456 : 13'd459)) &&
729: 					(i_macro_tick < (reg_ir_precision ? 13'd464 : 13'd461)));
730: 					if(reg_ir_precision == 1'b1)begin
731: 						reg_control_next[CTRL_Q1_15] = (i_macro_tick >= 13'd444) && (i_macro_tick < 13'd465);
732: 						reg_control_next[CTRL_EN_15] = reg_control_next[CTRL_Q1_15];
733: 					end else begin
734: 						reg_control_next[CTRL_Q1_9] = (i_macro_tick >= 13'd453) && (i_macro_tick < 13'd462);
735: 					end
736: 					if((reg_ir_frame_type != FRAME_TYPE_AMB) && (i_macro_tick >= (reg_ir_precision ? 13'd455 : 13'd458)) && (i_macro_tick < (reg_ir_precision ? 13'd464 : 13'd461)))begin
737: 						reg_control_next[CTRL_LED_IR] = !reg_ir_input_source;
738: 						reg_control_next[CTRL_LED_CODE] = !reg_ir_input_source;
739: 						reg_control_next[CTRL_LED_DATA_H:CTRL_LED_DATA_L] = reg_ir_leddac_code;
740: 					end
741: 				end
742: 			end
743: 			if(calibration_wave_active_o == 1'b1)begin
744: 				reg_control_next[CTRL_IREF_9] = 1'b1;
745: 				reg_control_next[CTRL_IREF_IDAC] = (i_calibration_local_tick >= 10'd229) &&
746: 				(i_calibration_local_tick < 10'd269);
747: 				reg_control_next[CTRL_EN_9_IREF] = (i_calibration_local_tick >= 10'd202) &&
748: 				(i_calibration_local_tick < 10'd274);
749: 				reg_control_next[CTRL_EN_9_AMB] = (i_calibration_local_tick >= 10'd222) &&
750: 				(i_calibration_local_tick < 10'd276);
751: 				reg_control_next[CTRL_AMB9_H:CTRL_AMB9_L] = ((i_calibration_local_tick >= 10'd224) &&
752: 				(i_calibration_local_tick < 10'd276)) ? reg_cal_amb_code : 8'h00;
753: 				if(reg_cal_frame_type == FRAME_TYPE_DCS)begin
754: 					reg_control_next[CTRL_EN_9_DC] = (i_calibration_local_tick >= 10'd222) &&
755: 					(i_calibration_local_tick < 10'd276);
756: 					reg_control_next[CTRL_DC9_H:CTRL_DC9_L] = ((i_calibration_local_tick >= 10'd232) &&
757: 					(i_calibration_local_tick < 10'd276)) ? reg_cal_dc_code : 8'h00;
758: 				end
759: 				if(flag_cal_has_owner == 1'b1)begin
760: 					reg_control_next[CTRL_AFERST] = (i_calibration_local_tick >= 10'd249) &&
761: 					(i_calibration_local_tick < 10'd261);
762: 					reg_control_next[CTRL_TIAEN] = (i_calibration_local_tick >= 10'd249) &&
763: 					(i_calibration_local_tick < 10'd269);
764: 					reg_control_next[CTRL_Q1_9] = (i_calibration_local_tick >= 10'd259) &&
765: 					(i_calibration_local_tick < 10'd268);
766: 					reg_control_next[CTRL_Q2] = (reg_cal_frame_type == FRAME_TYPE_DCS) &&
767: 					(i_calibration_local_tick >= 10'd262) &&
768: 					(i_calibration_local_tick < 10'd264);
769: 					reg_control_next[CTRL_Q3] = (i_calibration_local_tick >= 10'd265) &&
770: 					(i_calibration_local_tick < 10'd267);
771: 					if(reg_cal_frame_type == FRAME_TYPE_DCS && reg_cal_input_source == 1'b0 && (i_calibration_local_tick >= 10'd265) && (i_calibration_local_tick < 10'd267))begin
772: 						reg_control_next[CTRL_LED_R] = !reg_cal_color_ir;
773: 						reg_control_next[CTRL_LED_IR] = reg_cal_color_ir;
774: 						reg_control_next[CTRL_LED_CODE] = 1'b1;
775: 						reg_control_next[CTRL_LED_DATA_H:CTRL_LED_DATA_L] = reg_cal_leddac_code;
776: 					end
777: 				end
778: 			end
779: 		end
780: 	end
```

### L783：reg_run_active

```text
783: 	always@(posedge i_clk or negedge i_rstn)begin
784: 		if(i_rstn == 1'b0)begin
785: 			reg_run_active <= 1'b0;
786: 		end else begin
787: 			if(flag_start_restore == 1'b1)begin
788: 				reg_run_active <= 1'b1;
789: 			end else if((i_run_enable == 1'b0 || flag_stop_pending == 1'b1) && o_wrapper_idle == 1'b1)begin
790: 				reg_run_active <= 1'b0;
791: 			end
792: 		end
793: 	end
```

### L796：flag_stop_pending

```text
796: 	always@(posedge i_clk or negedge i_rstn)begin
797: 		if(i_rstn == 1'b0)begin
798: 			flag_stop_pending <= 1'b0;
799: 		end else begin
800: 			if(i_control_abort_event == 1'b1)begin
801: 				flag_stop_pending <= 1'b1;
802: 			end else if(i_stop_ack_event == 1'b1)begin
803: 				flag_stop_pending <= 1'b1;
804: 			end else if(reg_run_active == 1'b0 && o_wrapper_idle == 1'b1)begin
805: 				flag_stop_pending <= 1'b0;
806: 			end else if(flag_start_restore == 1'b1)begin
807: 				flag_stop_pending <= 1'b0;
808: 			end
809: 		end
810: 	end
```

### L813：reg_cal_amb_code

```text
813: 	always@(posedge i_clk or negedge i_rstn)begin
814: 		if(i_rstn == 1'b0)begin
815: 	reg_cal_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}};
816: 		end else if(i_control_abort_event == 1'b1)begin
817: 			reg_cal_amb_code <= reg_cal_amb_code;
818: 		end else begin
819: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
820: 				reg_cal_amb_code <= i_waveform_amb_code_snapshot;
821: 			end
822: 		end
823: 	end
```

### L826：reg_cal_amb_epoch

```text
826: 	always@(posedge i_clk or negedge i_rstn)begin
827: 		if(i_rstn == 1'b0)begin
828: 	reg_cal_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
829: 		end else if(i_control_abort_event == 1'b1)begin
830: 			reg_cal_amb_epoch <= reg_cal_amb_epoch;
831: 		end else begin
832: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
833: 				reg_cal_amb_epoch <= i_waveform_amb_code_epoch;
834: 			end
835: 		end
836: 	end
```

### L839：reg_cal_color_ir

```text
839: 	always@(posedge i_clk or negedge i_rstn)begin
840: 		if(i_rstn == 1'b0)begin
841: 			reg_cal_color_ir <= 1'b0;
842: 		end else if(i_control_abort_event == 1'b1)begin
843: 			reg_cal_color_ir <= reg_cal_color_ir;
844: 		end else begin
845: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
846: 				reg_cal_color_ir <= i_waveform_color_ir;
847: 			end
848: 		end
849: 	end
```

### L852：reg_cal_dc_code

```text
852: 	always@(posedge i_clk or negedge i_rstn)begin
853: 		if(i_rstn == 1'b0)begin
854: 	reg_cal_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}};
855: 		end else if(i_control_abort_event == 1'b1)begin
856: 			reg_cal_dc_code <= reg_cal_dc_code;
857: 		end else begin
858: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
859: 				reg_cal_dc_code <= i_waveform_dc_code_snapshot;
860: 			end
861: 		end
862: 	end
```

### L865：reg_cal_dc_epoch

```text
865: 	always@(posedge i_clk or negedge i_rstn)begin
866: 		if(i_rstn == 1'b0)begin
867: 	reg_cal_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
868: 		end else if(i_control_abort_event == 1'b1)begin
869: 			reg_cal_dc_epoch <= reg_cal_dc_epoch;
870: 		end else begin
871: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
872: 				reg_cal_dc_epoch <= i_waveform_dc_code_epoch;
873: 			end
874: 		end
875: 	end
```

### L878：reg_cal_frame_id

```text
878: 	always@(posedge i_clk or negedge i_rstn)begin
879: 		if(i_rstn == 1'b0)begin
880: 	reg_cal_frame_id <= {C_FRAME_ID_WIDTH{1'b0}};
881: 		end else if(i_control_abort_event == 1'b1)begin
882: 			reg_cal_frame_id <= reg_cal_frame_id;
883: 		end else begin
884: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
885: 				reg_cal_frame_id <= i_waveform_frame_id;
886: 			end
887: 		end
888: 	end
```

### L891：reg_cal_frame_type

```text
891: 	always@(posedge i_clk or negedge i_rstn)begin
892: 		if(i_rstn == 1'b0)begin
893: 			reg_cal_frame_type <= FRAME_TYPE_AMB;
894: 		end else if(i_control_abort_event == 1'b1)begin
895: 			reg_cal_frame_type <= reg_cal_frame_type;
896: 		end else begin
897: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
898: 				reg_cal_frame_type <= i_waveform_frame_type;
899: 			end
900: 		end
901: 	end
```

### L904：reg_cal_input_source

```text
904: 	always@(posedge i_clk or negedge i_rstn)begin
905: 		if(i_rstn == 1'b0)begin
906: 			reg_cal_input_source <= 1'b0;
907: 		end else if(i_control_abort_event == 1'b1)begin
908: 			reg_cal_input_source <= reg_cal_input_source;
909: 		end else begin
910: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
911: 				reg_cal_input_source <= i_waveform_input_source;
912: 			end
913: 		end
914: 	end
```

### L917：reg_cal_leddac_code

```text
917: 	always@(posedge i_clk or negedge i_rstn)begin
918: 		if(i_rstn == 1'b0)begin
919: 	reg_cal_leddac_code <= 8'h00;
920: 		end else if(i_control_abort_event == 1'b1)begin
921: 			reg_cal_leddac_code <= reg_cal_leddac_code;
922: 		end else begin
923: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
924: 				reg_cal_leddac_code <= i_waveform_leddac_code_snapshot;
925: 			end
926: 		end
927: 	end
```

### L930：reg_cal_optical_mode

```text
930: 	always@(posedge i_clk or negedge i_rstn)begin
931: 		if(i_rstn == 1'b0)begin
932: 			reg_cal_optical_mode <= OPTICAL_MODE_BOTH;
933: 		end else if(i_control_abort_event == 1'b1)begin
934: 			reg_cal_optical_mode <= reg_cal_optical_mode;
935: 		end else begin
936: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
937: 				reg_cal_optical_mode <= i_waveform_optical_mode;
938: 			end
939: 		end
940: 	end
```

### L943：reg_cal_precision

```text
943: 	always@(posedge i_clk or negedge i_rstn)begin
944: 		if(i_rstn == 1'b0)begin
945: 			reg_cal_precision <= 1'b0;
946: 		end else if(i_control_abort_event == 1'b1)begin
947: 			reg_cal_precision <= reg_cal_precision;
948: 		end else begin
949: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
950: 				reg_cal_precision <= 1'b0;
951: 			end
952: 		end
953: 	end
```

### L956：flag_cal_context_valid

```text
956: 	always@(posedge i_clk or negedge i_rstn)begin
957: 		if(i_rstn == 1'b0)begin
958: 			flag_cal_context_valid <= 1'b0;
959: 		end else if(i_control_abort_event == 1'b1)begin
960: 			flag_cal_context_valid <= 1'b0;
961: 		end else if(flag_start_restore == 1'b1)begin
962: 			flag_cal_context_valid <= 1'b0;
963: 		end else begin
964: 			if(flag_cal_wave_last == 1'b1)begin
965: 				flag_cal_context_valid <= 1'b0;
966: 			end
967: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
968: 				flag_cal_context_valid <= 1'b1;
969: 			end
970: 		end
971: 	end
```

### L974：reg_ir_amb_code

```text
974: 	always@(posedge i_clk or negedge i_rstn)begin
975: 		if(i_rstn == 1'b0)begin
976: 	reg_ir_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}};
977: 		end else if(i_control_abort_event == 1'b1)begin
978: 			reg_ir_amb_code <= reg_ir_amb_code;
979: 		end else begin
980: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
981: 				reg_ir_amb_code <= i_waveform_amb_code_snapshot;
982: 			end
983: 		end
984: 	end
```

### L987：reg_ir_amb_epoch

```text
987: 	always@(posedge i_clk or negedge i_rstn)begin
988: 		if(i_rstn == 1'b0)begin
989: 	reg_ir_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
990: 		end else if(i_control_abort_event == 1'b1)begin
991: 			reg_ir_amb_epoch <= reg_ir_amb_epoch;
992: 		end else begin
993: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
994: 				reg_ir_amb_epoch <= i_waveform_amb_code_epoch;
995: 			end
996: 		end
997: 	end
```

### L1000：reg_ir_dc_code

```text
1000: 	always@(posedge i_clk or negedge i_rstn)begin
1001: 		if(i_rstn == 1'b0)begin
1002: 	reg_ir_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}};
1003: 		end else if(i_control_abort_event == 1'b1)begin
1004: 			reg_ir_dc_code <= reg_ir_dc_code;
1005: 		end else begin
1006: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1007: 				reg_ir_dc_code <= i_waveform_dc_code_snapshot;
1008: 			end
1009: 		end
1010: 	end
```

### L1013：reg_ir_dc_epoch

```text
1013: 	always@(posedge i_clk or negedge i_rstn)begin
1014: 		if(i_rstn == 1'b0)begin
1015: 	reg_ir_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
1016: 		end else if(i_control_abort_event == 1'b1)begin
1017: 			reg_ir_dc_epoch <= reg_ir_dc_epoch;
1018: 		end else begin
1019: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1020: 				reg_ir_dc_epoch <= i_waveform_dc_code_epoch;
1021: 			end
1022: 		end
1023: 	end
```

### L1026：reg_ir_frame_id

```text
1026: 	always@(posedge i_clk or negedge i_rstn)begin
1027: 		if(i_rstn == 1'b0)begin
1028: 	reg_ir_frame_id <= {C_FRAME_ID_WIDTH{1'b0}};
1029: 		end else if(i_control_abort_event == 1'b1)begin
1030: 			reg_ir_frame_id <= reg_ir_frame_id;
1031: 		end else begin
1032: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1033: 				reg_ir_frame_id <= i_waveform_frame_id;
1034: 			end
1035: 		end
1036: 	end
```

### L1039：reg_ir_frame_type

```text
1039: 	always@(posedge i_clk or negedge i_rstn)begin
1040: 		if(i_rstn == 1'b0)begin
1041: 			reg_ir_frame_type <= FRAME_TYPE_NORMAL;
1042: 		end else if(i_control_abort_event == 1'b1)begin
1043: 			reg_ir_frame_type <= reg_ir_frame_type;
1044: 		end else begin
1045: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1046: 				reg_ir_frame_type <= i_waveform_frame_type;
1047: 			end
1048: 		end
1049: 	end
```

### L1052：reg_ir_input_source

```text
1052: 	always@(posedge i_clk or negedge i_rstn)begin
1053: 		if(i_rstn == 1'b0)begin
1054: 			reg_ir_input_source <= 1'b0;
1055: 		end else if(i_control_abort_event == 1'b1)begin
1056: 			reg_ir_input_source <= reg_ir_input_source;
1057: 		end else begin
1058: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1059: 				reg_ir_input_source <= i_waveform_input_source;
1060: 			end
1061: 		end
1062: 	end
```

### L1065：reg_ir_leddac_code

```text
1065: 	always@(posedge i_clk or negedge i_rstn)begin
1066: 		if(i_rstn == 1'b0)begin
1067: 	reg_ir_leddac_code <= 8'h00;
1068: 		end else if(i_control_abort_event == 1'b1)begin
1069: 			reg_ir_leddac_code <= reg_ir_leddac_code;
1070: 		end else begin
1071: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1072: 				reg_ir_leddac_code <= i_waveform_leddac_code_snapshot;
1073: 			end
1074: 		end
1075: 	end
```

### L1078：reg_ir_optical_mode

```text
1078: 	always@(posedge i_clk or negedge i_rstn)begin
1079: 		if(i_rstn == 1'b0)begin
1080: 			reg_ir_optical_mode <= OPTICAL_MODE_BOTH;
1081: 		end else if(i_control_abort_event == 1'b1)begin
1082: 			reg_ir_optical_mode <= reg_ir_optical_mode;
1083: 		end else begin
1084: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1085: 				reg_ir_optical_mode <= i_waveform_optical_mode;
1086: 			end
1087: 		end
1088: 	end
```

### L1091：reg_ir_precision

```text
1091: 	always@(posedge i_clk or negedge i_rstn)begin
1092: 		if(i_rstn == 1'b0)begin
1093: 			reg_ir_precision <= 1'b0;
1094: 		end else if(i_control_abort_event == 1'b1)begin
1095: 			reg_ir_precision <= reg_ir_precision;
1096: 		end else begin
1097: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1098: 				reg_ir_precision <= i_waveform_precision_mode;
1099: 			end
1100: 		end
1101: 	end
```

### L1104：flag_ir_context_valid

```text
1104: 	always@(posedge i_clk or negedge i_rstn)begin
1105: 		if(i_rstn == 1'b0)begin
1106: 			flag_ir_context_valid <= 1'b0;
1107: 		end else if(i_control_abort_event == 1'b1)begin
1108: 			flag_ir_context_valid <= 1'b0;
1109: 		end else if(flag_start_restore == 1'b1)begin
1110: 			flag_ir_context_valid <= 1'b0;
1111: 		end else begin
1112: 			if(flag_ir_wave_last == 1'b1)begin
1113: 				flag_ir_context_valid <= 1'b0;
1114: 			end
1115: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1116: 				flag_ir_context_valid <= 1'b1;
1117: 			end
1118: 		end
1119: 	end
```

### L1122：reg_red_amb_code

```text
1122: 	always@(posedge i_clk or negedge i_rstn)begin
1123: 		if(i_rstn == 1'b0)begin
1124: 	reg_red_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}};
1125: 		end else if(i_control_abort_event == 1'b1)begin
1126: 			reg_red_amb_code <= reg_red_amb_code;
1127: 		end else begin
1128: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1129: 				reg_red_amb_code <= i_waveform_amb_code_snapshot;
1130: 			end
1131: 		end
1132: 	end
```

### L1135：reg_red_amb_epoch

```text
1135: 	always@(posedge i_clk or negedge i_rstn)begin
1136: 		if(i_rstn == 1'b0)begin
1137: 	reg_red_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
1138: 		end else if(i_control_abort_event == 1'b1)begin
1139: 			reg_red_amb_epoch <= reg_red_amb_epoch;
1140: 		end else begin
1141: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1142: 				reg_red_amb_epoch <= i_waveform_amb_code_epoch;
1143: 			end
1144: 		end
1145: 	end
```

### L1148：reg_red_dc_code

```text
1148: 	always@(posedge i_clk or negedge i_rstn)begin
1149: 		if(i_rstn == 1'b0)begin
1150: 	reg_red_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}};
1151: 		end else if(i_control_abort_event == 1'b1)begin
1152: 			reg_red_dc_code <= reg_red_dc_code;
1153: 		end else begin
1154: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1155: 				reg_red_dc_code <= i_waveform_dc_code_snapshot;
1156: 			end
1157: 		end
1158: 	end
```

### L1161：reg_red_dc_epoch

```text
1161: 	always@(posedge i_clk or negedge i_rstn)begin
1162: 		if(i_rstn == 1'b0)begin
1163: 	reg_red_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
1164: 		end else if(i_control_abort_event == 1'b1)begin
1165: 			reg_red_dc_epoch <= reg_red_dc_epoch;
1166: 		end else begin
1167: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1168: 				reg_red_dc_epoch <= i_waveform_dc_code_epoch;
1169: 			end
1170: 		end
1171: 	end
```

### L1174：reg_red_frame_id

```text
1174: 	always@(posedge i_clk or negedge i_rstn)begin
1175: 		if(i_rstn == 1'b0)begin
1176: 	reg_red_frame_id <= {C_FRAME_ID_WIDTH{1'b0}};
1177: 		end else if(i_control_abort_event == 1'b1)begin
1178: 			reg_red_frame_id <= reg_red_frame_id;
1179: 		end else begin
1180: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1181: 				reg_red_frame_id <= i_waveform_frame_id;
1182: 			end
1183: 		end
1184: 	end
```

### L1187：reg_red_generation

```text
1187: 	always@(posedge i_clk or negedge i_rstn)begin
1188: 		if(i_rstn == 1'b0)begin
1189: 			reg_red_generation <= {C_RUN_GENERATION_WIDTH{1'b0}};
1190: 		end else if(i_control_abort_event == 1'b1)begin
1191: 			reg_red_generation <= reg_red_generation;
1192: 		end else begin
1193: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1194: 				reg_red_generation <= i_run_generation;
1195: 			end
1196: 		end
1197: 	end
```

### L1200：reg_ir_generation

```text
1200: 	always@(posedge i_clk or negedge i_rstn)begin
1201: 		if(i_rstn == 1'b0)begin
1202: 			reg_ir_generation <= {C_RUN_GENERATION_WIDTH{1'b0}};
1203: 		end else if(i_control_abort_event == 1'b1)begin
1204: 			reg_ir_generation <= reg_ir_generation;
1205: 		end else begin
1206: 			if(flag_context_fire == 1'b1 && flag_context_is_ir == 1'b1)begin
1207: 				reg_ir_generation <= i_run_generation;
1208: 			end
1209: 		end
1210: 	end
```

### L1213：reg_cal_generation

```text
1213: 	always@(posedge i_clk or negedge i_rstn)begin
1214: 		if(i_rstn == 1'b0)begin
1215: 			reg_cal_generation <= {C_RUN_GENERATION_WIDTH{1'b0}};
1216: 		end else if(i_control_abort_event == 1'b1)begin
1217: 			reg_cal_generation <= reg_cal_generation;
1218: 		end else begin
1219: 			if(flag_context_fire == 1'b1 && flag_context_is_cal == 1'b1)begin
1220: 				reg_cal_generation <= i_run_generation;
1221: 			end
1222: 		end
1223: 	end
```

### L1226：reg_red_frame_type

```text
1226: 	always@(posedge i_clk or negedge i_rstn)begin
1227: 		if(i_rstn == 1'b0)begin
1228: 			reg_red_frame_type <= FRAME_TYPE_NORMAL;
1229: 		end else if(i_control_abort_event == 1'b1)begin
1230: 			reg_red_frame_type <= reg_red_frame_type;
1231: 		end else begin
1232: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1233: 				reg_red_frame_type <= i_waveform_frame_type;
1234: 			end
1235: 		end
1236: 	end
```

### L1239：reg_red_input_source

```text
1239: 	always@(posedge i_clk or negedge i_rstn)begin
1240: 		if(i_rstn == 1'b0)begin
1241: 			reg_red_input_source <= 1'b0;
1242: 		end else if(i_control_abort_event == 1'b1)begin
1243: 			reg_red_input_source <= reg_red_input_source;
1244: 		end else begin
1245: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1246: 				reg_red_input_source <= i_waveform_input_source;
1247: 			end
1248: 		end
1249: 	end
```

### L1252：reg_red_leddac_code

```text
1252: 	always@(posedge i_clk or negedge i_rstn)begin
1253: 		if(i_rstn == 1'b0)begin
1254: 	reg_red_leddac_code <= 8'h00;
1255: 		end else if(i_control_abort_event == 1'b1)begin
1256: 			reg_red_leddac_code <= reg_red_leddac_code;
1257: 		end else begin
1258: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1259: 				reg_red_leddac_code <= i_waveform_leddac_code_snapshot;
1260: 			end
1261: 		end
1262: 	end
```

### L1265：reg_red_optical_mode

```text
1265: 	always@(posedge i_clk or negedge i_rstn)begin
1266: 		if(i_rstn == 1'b0)begin
1267: 			reg_red_optical_mode <= OPTICAL_MODE_BOTH;
1268: 		end else if(i_control_abort_event == 1'b1)begin
1269: 			reg_red_optical_mode <= reg_red_optical_mode;
1270: 		end else begin
1271: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1272: 				reg_red_optical_mode <= i_waveform_optical_mode;
1273: 			end
1274: 		end
1275: 	end
```

### L1278：reg_red_precision

```text
1278: 	always@(posedge i_clk or negedge i_rstn)begin
1279: 		if(i_rstn == 1'b0)begin
1280: 			reg_red_precision <= 1'b0;
1281: 		end else if(i_control_abort_event == 1'b1)begin
1282: 			reg_red_precision <= reg_red_precision;
1283: 		end else begin
1284: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1285: 				reg_red_precision <= i_waveform_precision_mode;
1286: 			end
1287: 		end
1288: 	end
```

### L1291：flag_red_context_valid

```text
1291: 	always@(posedge i_clk or negedge i_rstn)begin
1292: 		if(i_rstn == 1'b0)begin
1293: 			flag_red_context_valid <= 1'b0;
1294: 		end else if(i_control_abort_event == 1'b1)begin
1295: 			flag_red_context_valid <= 1'b0;
1296: 		end else if(flag_start_restore == 1'b1)begin
1297: 			flag_red_context_valid <= 1'b0;
1298: 		end else begin
1299: 			if(flag_red_wave_last == 1'b1)begin
1300: 				flag_red_context_valid <= 1'b0;
1301: 			end
1302: 			if(flag_context_fire == 1'b1 && flag_context_is_red == 1'b1)begin
1303: 				flag_red_context_valid <= 1'b1;
1304: 			end
1305: 		end
1306: 	end
```

### L1309：reg_owner_abort_seen

```text
1309: 	always@(posedge i_clk or negedge i_rstn)begin
1310: 		if(i_rstn == 1'b0)begin
1311: 			reg_owner_abort_seen <= 1'b0;
1312: 		end else if(flag_owner_release == 1'b1)begin
1313: 			reg_owner_abort_seen <= 1'b0;
1314: 		end else if(i_control_abort_event == 1'b1)begin
1315: 			if(adc_owner_inflight_o == 1'b1)begin
1316: 				reg_owner_abort_seen <= 1'b1;
1317: 			end
1318: 		end else if(flag_owner_commit_fire == 1'b1)begin
1319: 			reg_owner_abort_seen <= 1'b0;
1320: 		end
1321: 	end
```

### L1324：reg_owner_sample_index

```text
1324: 	always@(posedge i_clk or negedge i_rstn)begin
1325: 		if(i_rstn == 1'b0)begin
1326: 	reg_owner_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
1327: 		end else if(i_control_abort_event == 1'b1)begin
1328: 			reg_owner_sample_index <= reg_owner_sample_index;
1329: 		end else if(flag_owner_release == 1'b1)begin
1330: 			reg_owner_sample_index <= reg_owner_sample_index;
1331: 		end else if(flag_owner_commit_fire == 1'b1)begin
1332: 			reg_owner_sample_index <= i_adc_owner_sample_index;
1333: 		end
1334: 	end
```

### L1337：reg_owner_generation

```text
1337: 	always@(posedge i_clk or negedge i_rstn)begin
1338: 		if(i_rstn == 1'b0)begin
1339: 			reg_owner_generation <= {C_RUN_GENERATION_WIDTH{1'b0}};
1340: 		end else if(i_control_abort_event == 1'b1)begin
1341: 			reg_owner_generation <= reg_owner_generation;
1342: 		end else if(flag_owner_release == 1'b1)begin
1343: 			reg_owner_generation <= reg_owner_generation;
1344: 		end else if(flag_owner_commit_fire == 1'b1)begin
1345: 			reg_owner_generation <= i_run_generation;
1346: 		end
1347: 	end
```

### L1350：reg_owner_frame_id

```text
1350: 	always@(posedge i_clk or negedge i_rstn)begin
1351: 		if(i_rstn == 1'b0)begin
1352: 			reg_owner_frame_id <= {C_FRAME_ID_WIDTH{1'b0}};
1353: 		end else if(i_control_abort_event == 1'b1)begin
1354: 			reg_owner_frame_id <= reg_owner_frame_id;
1355: 		end else if(flag_owner_release == 1'b1)begin
1356: 			reg_owner_frame_id <= reg_owner_frame_id;
1357: 		end else if(flag_owner_commit_fire == 1'b1)begin
1358: 			reg_owner_frame_id <= i_adc_owner_frame_id;
1359: 		end
1360: 	end
```

### L1363：reg_owner_cal_subframe

```text
1363: 	always@(posedge i_clk or negedge i_rstn)begin
1364: 		if(i_rstn == 1'b0)begin
1365: 			reg_owner_cal_subframe <= 3'd0;
1366: 		end else if(flag_owner_commit_fire == 1'b1)begin
1367: 			reg_owner_cal_subframe <= i_calibration_subframe_index;
1368: 		end
1369: 	end
```

### L1372：reg_owner_color_ir

```text
1372: 	always@(posedge i_clk or negedge i_rstn)begin
1373: 		if(i_rstn == 1'b0)begin
1374: 			reg_owner_color_ir <= 1'b0;
1375: 		end else if(i_control_abort_event == 1'b1)begin
1376: 			reg_owner_color_ir <= reg_owner_color_ir;
1377: 		end else if(flag_owner_release == 1'b1)begin
1378: 			reg_owner_color_ir <= reg_owner_color_ir;
1379: 		end else if(flag_owner_commit_fire == 1'b1)begin
1380: 			reg_owner_color_ir <= i_adc_owner_color_ir;
1381: 		end
1382: 	end
```

### L1385：reg_owner_frame_type

```text
1385: 	always@(posedge i_clk or negedge i_rstn)begin
1386: 		if(i_rstn == 1'b0)begin
1387: 			reg_owner_frame_type <= 2'b00;
1388: 		end else if(i_control_abort_event == 1'b1)begin
1389: 			reg_owner_frame_type <= reg_owner_frame_type;
1390: 		end else if(flag_owner_release == 1'b1)begin
1391: 			reg_owner_frame_type <= reg_owner_frame_type;
1392: 		end else if(flag_owner_commit_fire == 1'b1)begin
1393: 			reg_owner_frame_type <= i_adc_owner_frame_type;
1394: 		end
1395: 	end
```

### L1398：reg_owner_precision_mode

```text
1398: 	always@(posedge i_clk or negedge i_rstn)begin
1399: 		if(i_rstn == 1'b0)begin
1400: 			reg_owner_precision_mode <= 1'b0;
1401: 		end else if(i_control_abort_event == 1'b1)begin
1402: 			reg_owner_precision_mode <= reg_owner_precision_mode;
1403: 		end else if(flag_owner_release == 1'b1)begin
1404: 			reg_owner_precision_mode <= reg_owner_precision_mode;
1405: 		end else if(flag_owner_commit_fire == 1'b1)begin
1406: 			reg_owner_precision_mode <= i_adc_owner_precision_mode;
1407: 		end
1408: 	end
```

### L1411：reg_owner_slot

```text
1411: 	always@(posedge i_clk or negedge i_rstn)begin
1412: 		if(i_rstn == 1'b0)begin
1413: 			reg_owner_slot <= SLOT_RED;
1414: 		end else if(i_control_abort_event == 1'b1)begin
1415: 			reg_owner_slot <= reg_owner_slot;
1416: 		end else if(flag_owner_release == 1'b1)begin
1417: 			reg_owner_slot <= reg_owner_slot;
1418: 		end else if(flag_owner_commit_fire == 1'b1)begin
1419: 			if(flag_red_owner_candidate == 1'b1)begin
1420: 				reg_owner_slot <= SLOT_RED;
1421: 			end else if(flag_ir_owner_candidate == 1'b1)begin
1422: 				reg_owner_slot <= SLOT_IR;
1423: 			end else begin
1424: 				reg_owner_slot <= SLOT_CAL;
1425: 			end
1426: 		end
1427: 	end
```

### L1431：flag_ssw_fault_valid

```text
1431: 	always@(posedge i_clk or negedge i_rstn)begin
1432: 		if(i_rstn == 1'b0)begin
1433: 			flag_ssw_fault_valid <= 1'b0;
1434: 		end else if(flag_ssw_fault_rising == 1'b1)begin
1435: 			flag_ssw_fault_valid <= 1'b1;
1436: 		end else begin
1437: 			flag_ssw_fault_valid <= 1'b0;
1438: 		end
1439: 	end
```

### L1442：flag_ssw_fault_identity_valid

```text
1442: 	always@(posedge i_clk or negedge i_rstn)begin
1443: 		if(i_rstn == 1'b0)begin
1444: 			flag_ssw_fault_identity_valid <= 1'b0;
1445: 		end else if(flag_start_restore == 1'b1)begin
1446: 			flag_ssw_fault_identity_valid <= 1'b0;
1447: 		end else begin
1448: 			if(i_diag_clear_event == 1'b1 && o_wrapper_idle == 1'b1)begin
1449: 				flag_ssw_fault_identity_valid <= 1'b0;
1450: 			end
1451: 			if(flag_ssw_fault_rising == 1'b1)begin
1452: 				if(flag_owner_commit_error == 1'b1)begin
1453: 					flag_ssw_fault_identity_valid <= 1'b1;
1454: 				end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
1455: 					flag_ssw_fault_identity_valid <= 1'b1;
1456: 				end else begin
1457: 					flag_ssw_fault_identity_valid <= 1'b0;
1458: 				end
1459: 			end
1460: 		end
1461: 	end
```

### L1464：reg_ssw_fault_frame_id

```text
1464: 	always@(posedge i_clk or negedge i_rstn)begin
1465: 		if(i_rstn == 1'b0)begin
1466: 			reg_ssw_fault_frame_id <= {C_FRAME_ID_WIDTH{1'b0}};
1467: 		end else if(flag_ssw_fault_rising == 1'b1)begin
1468: 			if(flag_owner_commit_error == 1'b1)begin
1469: 				reg_ssw_fault_frame_id <= i_adc_owner_frame_id;
1470: 			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
1471: 				reg_ssw_fault_frame_id <= reg_owner_frame_id;
1472: 			end
1473: 		end
1474: 	end
```

### L1477：reg_ssw_fault_sample_index

```text
1477: 	always@(posedge i_clk or negedge i_rstn)begin
1478: 		if(i_rstn == 1'b0)begin
1479: 			reg_ssw_fault_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
1480: 		end else if(flag_ssw_fault_rising == 1'b1)begin
1481: 			if(flag_owner_commit_error == 1'b1)begin
1482: 				reg_ssw_fault_sample_index <= i_adc_owner_sample_index;
1483: 			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
1484: 				reg_ssw_fault_sample_index <= reg_owner_sample_index;
1485: 			end
1486: 		end
1487: 	end
```

### L1490：reg_ssw_fault_color_ir

```text
1490: 	always@(posedge i_clk or negedge i_rstn)begin
1491: 		if(i_rstn == 1'b0)begin
1492: 			reg_ssw_fault_color_ir <= 1'b0;
1493: 		end else if(flag_ssw_fault_rising == 1'b1)begin
1494: 			if(flag_owner_commit_error == 1'b1)begin
1495: 				reg_ssw_fault_color_ir <= i_adc_owner_color_ir;
1496: 			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
1497: 				reg_ssw_fault_color_ir <= reg_owner_color_ir;
1498: 			end
1499: 		end
1500: 	end
```

### L1503：reg_ssw_fault_frame_type

```text
1503: 	always@(posedge i_clk or negedge i_rstn)begin
1504: 		if(i_rstn == 1'b0)begin
1505: 			reg_ssw_fault_frame_type <= 2'b00;
1506: 		end else if(flag_ssw_fault_rising == 1'b1)begin
1507: 			if(flag_owner_commit_error == 1'b1)begin
1508: 				reg_ssw_fault_frame_type <= i_adc_owner_frame_type;
1509: 			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
1510: 				reg_ssw_fault_frame_type <= reg_owner_frame_type;
1511: 			end
1512: 		end
1513: 	end
```

### L1516：reg_ssw_fault_precision_mode

```text
1516: 	always@(posedge i_clk or negedge i_rstn)begin
1517: 		if(i_rstn == 1'b0)begin
1518: 			reg_ssw_fault_precision_mode <= 1'b0;
1519: 		end else if(flag_ssw_fault_rising == 1'b1)begin
1520: 			if(flag_owner_commit_error == 1'b1)begin
1521: 				reg_ssw_fault_precision_mode <= i_adc_owner_precision_mode;
1522: 			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
1523: 				reg_ssw_fault_precision_mode <= reg_owner_precision_mode;
1524: 			end
1525: 		end
1526: 	end
```

### L1529：reg_ssw_fault_generation

```text
1529: 	always@(posedge i_clk or negedge i_rstn)begin
1530: 		if(i_rstn == 1'b0)begin
1531: 			reg_ssw_fault_generation <= {C_RUN_GENERATION_WIDTH{1'b0}};
1532: 		end else if(flag_ssw_fault_rising == 1'b1)begin
1533: 			if(flag_owner_commit_error == 1'b1)begin
1534: 				reg_ssw_fault_generation <= i_run_generation;
1535: 			end else if(flag_done_mismatch == 1'b1 && adc_owner_inflight_o == 1'b1)begin
1536: 				reg_ssw_fault_generation <= reg_owner_generation;
1537: 			end
1538: 		end
1539: 	end
```

## 最终文末汇总

(c)：V1-SSW-01（高）；待定：T-SSW-01～05。
