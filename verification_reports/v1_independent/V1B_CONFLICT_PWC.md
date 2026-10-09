# V1 独立同拍冲突审查：精度窗口控制器

固定基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`，RTL `rtl/ppg_precision_window_controller/ppg_precision_window_controller.v`，行号均属该提交。C23/B §3.6为意图依据；已定F-1异常精度切换超时不重新报缺陷。使用erie-verilog-generator AST只读分析；未访问隔离材料；没有仿真或RTL修改。附录逐一列出全部48个always及完整条件顺序。

## 1. 来源与全部对象矩阵

PWI L939/L947将baseline的cross_valid和peak-valley的return_valid直接接入；两个生产者输出是注册保持位（baseline L550、peak-valley L443），没有用当拍discard遮valid。PWI L916/L930原样广播AMI的generation discard；AMI terminal包含当拍abort，且只要PWI有未排空状态就发scope-discard（AMI L1012/1020）。RUN与diag分别来自manager/Top；新discard与旧valid可以在真实系统同拍。

定义C/R为cross/return transfer；Ec/Rc为enter/return安全commit；T为switch timeout；D为匹配generation discard或离开RUN取消（L271）；S为START；G为diag。reset最高(b)。普通NORMAL的C/R两两(a)，C ready需ST_IDLE/9bit，R ready需ST_FINE/15bit。CHARACTERIZATION的两个ready均可高，但normal_transfer同时为0，不推进正式模式，仍置协议诊断。

| 对象（全部分组） | 全部非reset顺序 | 同拍条件对及处置 |
|---|---|---|
| active_precision_mode_o L320 | S按profile/initial配置 > Ec置15 > Rc置9 | Ec/Rc(a)，state相反；Ec/Rc与D(a)，commit含!cancel；S与旧commit合法START前empty(a)，非法重复START待测；D不改已提交精度(b)，C23取消只清预约 |
| fine_window_active_o L341 | S或D清 > Ec置1 > Rc清 | D/commit(a)直接门控；S与旧活动窗口正常(a)，empty；cancel最高正确(b) |
| fine_window_start_event/frame_id L356/367、precision_15_to_9_event/frame_id L378/389 | 各自commit置事件/装safe frame；事件默认0、frame保持 | 两commit(a)；D/commit(a)，cancel门；safe提交/T(a)，T明确!commit，C23 §16/PWC-25 |
| reacquire_request_event_o L400 | current ST_REACQUIRE置1 > 默认0 | D/REACQUIRE可同拍(c)，V1-PWC-02；通常该state只有1拍(b)，但不能用“只有1拍”排除独立discard |
| mode_fault_event_o及五fault字段 L411–480 | T或Rc&&recheck_busy、protocol_fault_pulse置事件；身份/字段T > Rc&&busy > protocol；无新事件保持字段、事件默认0 | T/Rc(a)，T排除Rc；非法START protocol与T正常(a)，START前empty；D/T可同拍(c)，V1-PWC-02；同源记录全组顺序一致(b) |
| switch_timeout_sticky_o L494、protocol_error_sticky_o L507 | G清 > 新T/协议错误置1 > 保持 | G/新错误可同拍(c)，G无上游排斥；G/已有fault可同拍(c)，V1-PWC-03；S/L不直接清sticky(b)，C23 §17.1 |
| switch_pending_o L520、switch_hold_new_transaction_o L544 | 每拍从state_next WAIT及commit/cancel组合装 | D覆盖next状态(b)，pending清；hold可在D保持一周期(b)，阻止新owner；不将输出寄存延迟当新请求 |
| switch_target_precision_o L531 | C装15 > R装9 > 保持 | NORMAL C/R(a)，活动state方向；CHARACTERIZATION C/R可同拍(b)，cross优先只影响诊断target、normal transfer0，T-PWC-03 |
| controller_idle_o L553 | next IDLE/FINE且非REACQUIRE、!fault_hold、!commit、旧event0时置1，否则0 | D与pending/event的旧状态组合产生保守晚一拍idle(b)；但不检查flag_pending_cross/return，取消被覆盖后可错误报告empty，V1-PWC-01 |
| last_cross_time_unknown_o L562、last_return_reason_o L573 | C/R装；reserved映射fallback | D/C或R可能同拍，历史last字段可保留但运行pending必须取消；不以历史观测字段保持直接报新算法复活 |
| state_current L589、state_next L598 | S按配置FAULT/IDLE > D回IDLE > unique state C/R/commit/T推进/defaultFAULT | D/新请求可同拍(b)，next取消优先；T/D取消state却未取消mode event(c)，V1-PWC-02 |
| flag_fault_hold L674 | D清 > S按blocking protocol装 > T置1 | D/T可同拍但清优先(b)，取消结束活动故障；因此mode_fault_event在相同沿继续发会造成valid/active不一致，V1-PWC-02 |
| cnt_switch_timeout L689 | S/D/commit/T清 > pending state且未到上限+1 > 其他清0 | 清/加可同拍(b)，clear优先；commit/T(a)；取消沿也到阈值时counter清而T组合仍高，见事件行 |
| cross frame/sample/config/coef/DC snapshot L706–758、pending_cross_time_unknown L771、return frame/reason L784/797 | S或D清 > 对应C/R装 > 保持 | D/C/R可同拍(b)，清身份优先；与pending位的transfer优先不同(c)，V1-PWC-01；全部字段同谓词、没有部分epoch装载 |
| flag_pending_return_reacquire L814 | S/D/Rc清 > R按reason装 > 保持 | Rc/R(a)，WAIT_RETURN/FINE方向相反；D/R可同拍(b)，取消优先；reserved reason按fallback获取资格(b)，C23 §16 |
| flag_pending_cross L827、flag_pending_return L840 | 对应C/R置1 > D/commit/T清 > 保持 | D/C/R可同拍(c)，V1-PWC-01；commit/新transfer NORMAL(a)，state相反；S缺少直接清，正常START前取消已结束，但防御测试T-PWC-02 |
| 12个组合flags L653/658/663/668/853/858/863/868/873/878/883/888 | 单次完整赋值，无多写；定义duplicate/invalid direction/leave RUN/config/profile/collision/start protocol/recheck/fallback/reserved | duplicate+错误方向/碰撞可同拍(b)，汇入protocol OR不会丢位；reserved与fallback同时成立(b)，同一个诊断；leaveRUN和discard可同拍(b)，统一cancel |

## 2. (c) 发现

V1-PWC-01（中）：generation discard与cross/return transfer同沿，L830或L843先置pending，else-if跳过L832/L845的取消清零；同时state_next L606回IDLE、snapshots L709等清0。C23 §16和§18.1a要求该沿清本generation全部请求/pending。完整上游valid未遮discard、ready L281/284未排除cancel，所以正常RUN中旧cross/return发布与外部abort scope-discard对齐可触发。沿后至少一个周期出现pending1、身份0、stateIDLE；这些位没有START清分支且idle计算不检查它们，可能一直保持到下一合法request/commit/timeout/再次discard。严重度中，属于取消和诊断身份一致性错误，不宣称仅此位会自主提交模式或永久卡住链路。

V1-PWC-02（中）：D与T同沿，T L272未排除cancel；state/counter/fault_hold清除，但L414仍发布mode_fault_event。D与current ST_REACQUIRE同沿时L403仍发布reacquire_request_event。C23 §18.1a禁止discard沿产生模式切换、重获取或诊断完成控制事件。外部abort/其他故障scope-discard可独立对齐第10000拍timeout；REACQUIRE恰是1拍也不能排除同沿输入。分别扫描阈值±1拍和return commit后REACQUIRE周期，检查事件必须被cancel压住。

V1-PWC-03（中）：L497/L510无本地fault解除条件，diag优先清sticky。新T/协议错误同沿，mode fault仍发布而sticky0；已有flag_fault_hold1时diag也能清历史，违反C23 §17.1/§18.1a“本地无活动故障时才清”。Top diag独立于cross、timeout和discard，故可同拍。与AMI新错误被clear压住同类，但这里还确认缺少活动故障门控。

## 3. 待定、覆盖、差异

T-PWC-01：discard/timeout/安全边界三路对齐，核验取消优先以及无新事件；安全commit/T自身互斥已证明。T-PWC-02：S/D及S/旧pending，完整manager/Top输入扫描；不force合法START前empty不可能保留的旧owner。T-PWC-03：CHARACTERIZATION cross和return双请求的消费诊断，不得改变committed精度，验证diagnostic target优先是否有软件依据。

48个always全部覆盖，§1包含每个对象、全部组合flags；精确每块起点/目标/语句顺序在附录。两个sticky历史START不清、F-1 IR丢失与切换超时按已定事项，不重复报。(c) V1-PWC-01～03；待定T-PWC-01～03。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 320 | `active_precision_mode_o` | seq |
| 341 | `fine_window_active_o` | seq |
| 356 | `fine_window_start_event_o` | seq |
| 367 | `fine_window_start_frame_id_o` | seq |
| 378 | `precision_15_to_9_event_o` | seq |
| 389 | `precision_15_to_9_frame_id_o` | seq |
| 400 | `reacquire_request_event_o` | seq |
| 411 | `mode_fault_event_o` | seq |
| 422 | `fault_identity_valid_o` | seq |
| 435 | `fault_frame_id_o` | seq |
| 450 | `fault_sample_index_o` | seq |
| 465 | `fault_precision_o` | seq |
| 480 | `fault_run_generation_o` | seq |
| 494 | `switch_timeout_sticky_o` | seq |
| 507 | `protocol_error_sticky_o` | seq |
| 520 | `switch_pending_o` | seq |
| 531 | `switch_target_precision_o` | seq |
| 544 | `switch_hold_new_transaction_o` | seq |
| 553 | `controller_idle_o` | seq |
| 562 | `last_cross_time_unknown_o` | seq |
| 573 | `last_return_reason_o` | seq |
| 589 | `state_current` | seq |
| 598 | `state_next` | comb |
| 653 | `flag_duplicate_cross` | comb |
| 658 | `flag_duplicate_return` | comb |
| 663 | `flag_invalid_direction_request` | comb |
| 668 | `flag_leave_run_cancel` | comb |
| 674 | `flag_fault_hold` | seq |
| 689 | `cnt_switch_timeout` | seq |
| 706 | `reg_cross_frame_snapshot` | seq |
| 719 | `reg_cross_sample_snapshot` | seq |
| 732 | `reg_cross_config_snapshot` | seq |
| 745 | `reg_cross_coef_snapshot` | seq |
| 758 | `reg_cross_dc_snapshot` | seq |
| 771 | `flag_pending_cross_time_unknown` | seq |
| 784 | `reg_return_frame_snapshot` | seq |
| 797 | `enc_return_reason_snapshot` | seq |
| 814 | `flag_pending_return_reacquire` | seq |
| 827 | `flag_pending_cross` | seq |
| 840 | `flag_pending_return` | seq |
| 853 | `flag_active_config_fault` | comb |
| 858 | `flag_characterization_request` | comb |
| 863 | `flag_cross_return_collision` | comb |
| 868 | `flag_normal_start_illegal` | comb |
| 873 | `flag_protocol_fault_pulse` | comb |
| 878 | `flag_recheck_in_fine` | comb |
| 883 | `flag_return_protocol_fallback` | comb |
| 888 | `flag_return_reserved` | comb |

### L320：active_precision_mode_o

```text
320: 	always@(posedge i_clk or negedge i_rstn)begin
321: 		if(i_rstn == 1'b0)begin
322: 			active_precision_mode_o <= PRECISION_9BIT;
323: 		end else if(i_start_ack_event == 1'b1)begin
324: 			if(i_active_config_valid == 1'b0 || ((i_run_profile == RUN_PROFILE_NORMAL) && i_initial_precision == 1'b1))begin
325: 				active_precision_mode_o <= PRECISION_9BIT;
326: 			end else if(i_run_profile == RUN_PROFILE_CHARACTERIZATION)begin
327: 				active_precision_mode_o <= i_initial_precision;
328: 			end else begin
329: 				active_precision_mode_o <= PRECISION_9BIT;
330: 			end
331: 		end else if(flag_enter_commit == 1'b1)begin
332: 			active_precision_mode_o <= PRECISION_15BIT;
333: 		end else if(flag_return_commit == 1'b1)begin
334: 			active_precision_mode_o <= PRECISION_9BIT;
335: 		end else begin
336: 			active_precision_mode_o <= active_precision_mode_o;
337: 		end
338: 	end
```

### L341：fine_window_active_o

```text
341: 	always@(posedge i_clk or negedge i_rstn)begin
342: 		if(i_rstn == 1'b0)begin
343: 			fine_window_active_o <= 1'b0;
344: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
345: 			fine_window_active_o <= 1'b0;
346: 		end else if(flag_enter_commit == 1'b1)begin
347: 			fine_window_active_o <= 1'b1;
348: 		end else if(flag_return_commit == 1'b1)begin
349: 			fine_window_active_o <= 1'b0;
350: 		end else begin
351: 			fine_window_active_o <= fine_window_active_o;
352: 		end
353: 	end
```

### L356：fine_window_start_event_o

```text
356: 	always@(posedge i_clk or negedge i_rstn)begin
357: 		if(i_rstn == 1'b0)begin
358: 			fine_window_start_event_o <= 1'b0;
359: 		end else if(flag_enter_commit == 1'b1)begin
360: 			fine_window_start_event_o <= 1'b1;
361: 		end else begin
362: 			fine_window_start_event_o <= 1'b0;
363: 		end
364: 	end
```

### L367：fine_window_start_frame_id_o

```text
367: 	always@(posedge i_clk or negedge i_rstn)begin
368: 		if(i_rstn == 1'b0)begin
369: 			fine_window_start_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}};
370: 		end else if(flag_enter_commit == 1'b1)begin
371: 			fine_window_start_frame_id_o <= i_safe_frame_id;
372: 		end else begin
373: 			fine_window_start_frame_id_o <= fine_window_start_frame_id_o;
374: 		end
375: 	end
```

### L378：precision_15_to_9_event_o

```text
378: 	always@(posedge i_clk or negedge i_rstn)begin
379: 		if(i_rstn == 1'b0)begin
380: 			precision_15_to_9_event_o <= 1'b0;
381: 		end else if(flag_return_commit == 1'b1)begin
382: 			precision_15_to_9_event_o <= 1'b1;
383: 		end else begin
384: 			precision_15_to_9_event_o <= 1'b0;
385: 		end
386: 	end
```

### L389：precision_15_to_9_frame_id_o

```text
389: 	always@(posedge i_clk or negedge i_rstn)begin
390: 		if(i_rstn == 1'b0)begin
391: 			precision_15_to_9_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}};
392: 		end else if(flag_return_commit == 1'b1)begin
393: 			precision_15_to_9_frame_id_o <= i_safe_frame_id;
394: 		end else begin
395: 			precision_15_to_9_frame_id_o <= precision_15_to_9_frame_id_o;
396: 		end
397: 	end
```

### L400：reacquire_request_event_o

```text
400: 	always@(posedge i_clk or negedge i_rstn)begin
401: 		if(i_rstn == 1'b0)begin
402: 			reacquire_request_event_o <= 1'b0;
403: 		end else if(state_current == ST_REACQUIRE)begin
404: 			reacquire_request_event_o <= 1'b1;
405: 		end else begin
406: 			reacquire_request_event_o <= 1'b0;
407: 		end
408: 	end
```

### L411：mode_fault_event_o

```text
411: 	always@(posedge i_clk or negedge i_rstn)begin
412: 		if(i_rstn == 1'b0)begin
413: 			mode_fault_event_o <= 1'b0;
414: 		end else if(flag_switch_timeout_event == 1'b1 || flag_protocol_fault_pulse == 1'b1 || (flag_return_commit == 1'b1 && i_recheck_busy == 1'b1))begin
415: 			mode_fault_event_o <= 1'b1;
416: 		end else begin
417: 			mode_fault_event_o <= 1'b0;
418: 		end
419: 	end
```

### L422：fault_identity_valid_o

```text
422: 	always@(posedge i_clk or negedge i_rstn)begin
423: 		if(i_rstn == 1'b0)begin
424: 			fault_identity_valid_o <= 1'b0;
425: 		end else if(flag_switch_timeout_event == 1'b1 || (flag_return_commit == 1'b1 && i_recheck_busy == 1'b1))begin
426: 			fault_identity_valid_o <= 1'b1;
427: 		end else if(flag_protocol_fault_pulse == 1'b1)begin
428: 			fault_identity_valid_o <= 1'b0;
429: 		end else begin
430: 			fault_identity_valid_o <= fault_identity_valid_o;
431: 		end
432: 	end
```

### L435：fault_frame_id_o

```text
435: 	always@(posedge i_clk or negedge i_rstn)begin
436: 		if(i_rstn == 1'b0)begin
437: 			fault_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}};
438: 		end else if(flag_switch_timeout_event == 1'b1)begin
439: 			fault_frame_id_o <= flag_pending_cross ? reg_cross_frame_snapshot : reg_return_frame_snapshot;
440: 		end else if(flag_return_commit == 1'b1 && i_recheck_busy == 1'b1)begin
441: 			fault_frame_id_o <= reg_return_frame_snapshot;
442: 		end else if(flag_protocol_fault_pulse == 1'b1)begin
443: 			fault_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}};
444: 		end else begin
445: 			fault_frame_id_o <= fault_frame_id_o;
446: 		end
447: 	end
```

### L450：fault_sample_index_o

```text
450: 	always@(posedge i_clk or negedge i_rstn)begin
451: 		if(i_rstn == 1'b0)begin
452: 			fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
453: 		end else if(flag_switch_timeout_event == 1'b1)begin
454: 			fault_sample_index_o <= flag_pending_cross ? reg_cross_sample_snapshot : {C_SAMPLE_INDEX_WIDTH{1'b0}};
455: 		end else if(flag_return_commit == 1'b1 && i_recheck_busy == 1'b1)begin
456: 			fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
457: 		end else if(flag_protocol_fault_pulse == 1'b1)begin
458: 			fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
459: 		end else begin
460: 			fault_sample_index_o <= fault_sample_index_o;
461: 		end
462: 	end
```

### L465：fault_precision_o

```text
465: 	always@(posedge i_clk or negedge i_rstn)begin
466: 		if(i_rstn == 1'b0)begin
467: 			fault_precision_o <= 1'b0;
468: 		end else if(flag_switch_timeout_event == 1'b1)begin
469: 			fault_precision_o <= flag_pending_cross ? PRECISION_9BIT : PRECISION_15BIT;
470: 		end else if(flag_return_commit == 1'b1 && i_recheck_busy == 1'b1)begin
471: 			fault_precision_o <= PRECISION_15BIT;
472: 		end else if(flag_protocol_fault_pulse == 1'b1)begin
473: 			fault_precision_o <= 1'b0;
474: 		end else begin
475: 			fault_precision_o <= fault_precision_o;
476: 		end
477: 	end
```

### L480：fault_run_generation_o

```text
480: 	always@(posedge i_clk or negedge i_rstn)begin
481: 		if(i_rstn == 1'b0)begin
482: 			fault_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}};
483: 		end else if(flag_switch_timeout_event == 1'b1 || (flag_return_commit == 1'b1 && i_recheck_busy == 1'b1))begin
484: 			fault_run_generation_o <= i_run_generation;
485: 		end else if(flag_protocol_fault_pulse == 1'b1)begin
486: 			fault_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}};
487: 		end else begin
488: 			fault_run_generation_o <= fault_run_generation_o;
489: 		end
490: 	end
```

### L494：switch_timeout_sticky_o

```text
494: 	always@(posedge i_clk or negedge i_rstn)begin
495: 		if(i_rstn == 1'b0)begin
496: 			switch_timeout_sticky_o <= 1'b0;
497: 		end else if(i_diag_clear_event == 1'b1)begin
498: 			switch_timeout_sticky_o <= 1'b0;
499: 		end else if(flag_switch_timeout_event == 1'b1)begin
500: 			switch_timeout_sticky_o <= 1'b1;
501: 		end else begin
502: 			switch_timeout_sticky_o <= switch_timeout_sticky_o;
503: 		end
504: 	end
```

### L507：protocol_error_sticky_o

```text
507: 	always@(posedge i_clk or negedge i_rstn)begin
508: 		if(i_rstn == 1'b0)begin
509: 			protocol_error_sticky_o <= 1'b0;
510: 		end else if(i_diag_clear_event == 1'b1)begin
511: 			protocol_error_sticky_o <= 1'b0;
512: 		end else if(flag_protocol_error_event == 1'b1)begin
513: 			protocol_error_sticky_o <= 1'b1;
514: 		end else begin
515: 			protocol_error_sticky_o <= protocol_error_sticky_o;
516: 		end
517: 	end
```

### L520：switch_pending_o

```text
520: 	always@(posedge i_clk or negedge i_rstn)begin
521: 		if(i_rstn == 1'b0)begin
522: 			switch_pending_o <= 1'b0;
523: 		end else if(state_next == ST_WAIT_ENTER || state_next == ST_WAIT_RETURN)begin
524: 			switch_pending_o <= 1'b1;
525: 		end else begin
526: 			switch_pending_o <= 1'b0;
527: 		end
528: 	end
```

### L531：switch_target_precision_o

```text
531: 	always@(posedge i_clk or negedge i_rstn)begin
532: 		if(i_rstn == 1'b0)begin
533: 			switch_target_precision_o <= PRECISION_9BIT;
534: 		end else if(flag_cross_transfer == 1'b1)begin
535: 			switch_target_precision_o <= PRECISION_15BIT;
536: 		end else if(flag_return_transfer == 1'b1)begin
537: 			switch_target_precision_o <= PRECISION_9BIT;
538: 		end else begin
539: 			switch_target_precision_o <= switch_target_precision_o;
540: 		end
541: 	end
```

### L544：switch_hold_new_transaction_o

```text
544: 	always@(posedge i_clk or negedge i_rstn)begin
545: 		if(i_rstn == 1'b0)begin
546: 			switch_hold_new_transaction_o <= 1'b0;
547: 		end else begin
548: 			switch_hold_new_transaction_o <= (state_next == ST_WAIT_ENTER) || (state_next == ST_WAIT_RETURN) || (state_next == ST_REACQUIRE) || (state_next == ST_FAULT) || flag_enter_commit || flag_return_commit || flag_lifecycle_cancel;
549: 		end
550: 	end
```

### L553：controller_idle_o

```text
553: 	always@(posedge i_clk or negedge i_rstn)begin
554: 		if(i_rstn == 1'b0)begin
555: 			controller_idle_o <= 1'b1;
556: 		end else begin
557: 			controller_idle_o <= (state_next == ST_IDLE || state_next == ST_FINE) && (state_current != ST_REACQUIRE) && (flag_fault_hold == 1'b0) && (flag_enter_commit == 1'b0) && (flag_return_commit == 1'b0) && (reacquire_request_event_o == 1'b0) && (mode_fault_event_o == 1'b0);
558: 		end
559: 	end
```

### L562：last_cross_time_unknown_o

```text
562: 	always@(posedge i_clk or negedge i_rstn)begin
563: 		if(i_rstn == 1'b0)begin
564: 			last_cross_time_unknown_o <= 1'b0;
565: 		end else if(flag_cross_transfer == 1'b1)begin
566: 			last_cross_time_unknown_o <= i_cross_time_unknown;
567: 		end else begin
568: 			last_cross_time_unknown_o <= last_cross_time_unknown_o;
569: 		end
570: 	end
```

### L573：last_return_reason_o

```text
573: 	always@(posedge i_clk or negedge i_rstn)begin
574: 		if(i_rstn == 1'b0)begin
575: 			last_return_reason_o <= RETURN_VALLEY_CONFIRMED;
576: 		end else if(flag_return_transfer == 1'b1)begin
577: 			if(i_return_reason == RETURN_RESERVED)begin
578: 				last_return_reason_o <= RETURN_PROTOCOL_FALLBACK;
579: 			end else begin
580: 				last_return_reason_o <= i_return_reason;
581: 			end
582: 		end else begin
583: 			last_return_reason_o <= last_return_reason_o;
584: 		end
585: 	end
```

### L589：state_current

```text
589: 	always@(posedge i_clk or negedge i_rstn)begin
590: 		if(i_rstn == 1'b0)begin
591: 			state_current <= ST_IDLE;
592: 		end else begin
593: 			state_current <= state_next;
594: 		end
595: 	end
```

### L598：state_next

```text
598: 	always@(*)begin
599: 		state_next = state_current;
600: 		if(i_start_ack_event == 1'b1)begin
601: 			if(flag_blocking_protocol_fault == 1'b1)begin
602: 				state_next = ST_FAULT;
603: 			end else begin
604: 				state_next = ST_IDLE;
605: 			end
606: 		end else if(flag_lifecycle_cancel == 1'b1)begin
607: 			state_next = ST_IDLE;
608: 		end else begin
609: 			case(state_current)
610: 				ST_IDLE:begin
611: 					if(flag_normal_cross_transfer == 1'b1)begin
612: 						state_next = ST_WAIT_ENTER;
613: 					end
614: 				end
615: 				ST_WAIT_ENTER:begin
616: 					if(flag_enter_commit == 1'b1)begin
617: 						state_next = ST_FINE;
618: 					end else if(flag_switch_timeout_event == 1'b1)begin
619: 						state_next = ST_FAULT;
620: 					end
621: 				end
622: 				ST_FINE:begin
623: 					if(flag_normal_return_transfer == 1'b1)begin
624: 						state_next = ST_WAIT_RETURN;
625: 					end
626: 				end
627: 				ST_WAIT_RETURN:begin
628: 					if(flag_return_commit == 1'b1)begin
629: 						if(flag_pending_return_reacquire == 1'b1)begin
630: 							state_next = ST_REACQUIRE;
631: 						end else begin
632: 							state_next = ST_IDLE;
633: 						end
634: 					end else if(flag_switch_timeout_event == 1'b1)begin
635: 						state_next = ST_FAULT;
636: 					end
637: 				end
638: 				ST_REACQUIRE:begin
639: 					state_next = ST_IDLE;
640: 				end
641: 				ST_FAULT:begin
642: 					state_next = ST_FAULT;
643: 				end
644: 				default:begin
645: 					state_next = ST_FAULT;
646: 				end
647: 			endcase
648: 		end
649: 	end
```

### L653：flag_duplicate_cross

```text
653: 	always@(*)begin
654: 		flag_duplicate_cross = (state_current == ST_WAIT_ENTER) && i_cross_valid;
655: 	end
```

### L658：flag_duplicate_return

```text
658: 	always@(*)begin
659: 		flag_duplicate_return = (state_current == ST_WAIT_RETURN) && i_return_9bit_valid;
660: 	end
```

### L663：flag_invalid_direction_request

```text
663: 	always@(*)begin
664: 		flag_invalid_direction_request = i_run_enable && (((state_current == ST_IDLE) && (active_precision_mode_o == PRECISION_9BIT) && i_return_9bit_valid) || ((state_current == ST_FINE) && i_cross_valid));
665: 	end
```

### L668：flag_leave_run_cancel

```text
668: 	always@(*)begin
669: 		flag_leave_run_cancel = (i_run_enable == 1'b0) && (state_current != ST_IDLE);
670: 	end
```

### L674：flag_fault_hold

```text
674: 	always@(posedge i_clk or negedge i_rstn)begin
675: 		if(i_rstn == 1'b0)begin
676: 			flag_fault_hold <= 1'b0;
677: 		end else if(flag_lifecycle_cancel == 1'b1)begin
678: 			flag_fault_hold <= 1'b0;
679: 		end else if(i_start_ack_event == 1'b1)begin
680: 			flag_fault_hold <= flag_blocking_protocol_fault;
681: 		end else if(flag_switch_timeout_event == 1'b1)begin
682: 			flag_fault_hold <= 1'b1;
683: 		end else begin
684: 			flag_fault_hold <= flag_fault_hold;
685: 		end
686: 	end
```

### L689：cnt_switch_timeout

```text
689: 	always@(posedge i_clk or negedge i_rstn)begin
690: 		if(i_rstn == 1'b0)begin
691: 			cnt_switch_timeout <= {C_SWITCH_TIMEOUT_COUNTER_WIDTH{1'b0}};
692: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1 || flag_enter_commit == 1'b1 || flag_return_commit == 1'b1 || flag_switch_timeout_event == 1'b1)begin
693: 			cnt_switch_timeout <= {C_SWITCH_TIMEOUT_COUNTER_WIDTH{1'b0}};
694: 		end else if(flag_pending_state == 1'b1)begin
695: 			if(cnt_switch_timeout < TIMEOUT_LIMIT_MINUS_ONE)begin
696: 				cnt_switch_timeout <= cnt_switch_timeout + {{(C_SWITCH_TIMEOUT_COUNTER_WIDTH - 1){1'b0}}, 1'b1};
697: 			end else begin
698: 				cnt_switch_timeout <= cnt_switch_timeout;
699: 			end
700: 		end else begin
701: 			cnt_switch_timeout <= {C_SWITCH_TIMEOUT_COUNTER_WIDTH{1'b0}};
702: 		end
703: 	end
```

### L706：reg_cross_frame_snapshot

```text
706: 	always@(posedge i_clk or negedge i_rstn)begin
707: 		if(i_rstn == 1'b0)begin
708: 			reg_cross_frame_snapshot <= {C_FRAME_ID_WIDTH{1'b0}};
709: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
710: 			reg_cross_frame_snapshot <= {C_FRAME_ID_WIDTH{1'b0}};
711: 		end else if(flag_cross_transfer == 1'b1)begin
712: 			reg_cross_frame_snapshot <= i_cross_frame_id;
713: 		end else begin
714: 			reg_cross_frame_snapshot <= reg_cross_frame_snapshot;
715: 		end
716: 	end
```

### L719：reg_cross_sample_snapshot

```text
719: 	always@(posedge i_clk or negedge i_rstn)begin
720: 		if(i_rstn == 1'b0)begin
721: 			reg_cross_sample_snapshot <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
722: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
723: 			reg_cross_sample_snapshot <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
724: 		end else if(flag_cross_transfer == 1'b1)begin
725: 			reg_cross_sample_snapshot <= i_cross_sample_index;
726: 		end else begin
727: 			reg_cross_sample_snapshot <= reg_cross_sample_snapshot;
728: 		end
729: 	end
```

### L732：reg_cross_config_snapshot

```text
732: 	always@(posedge i_clk or negedge i_rstn)begin
733: 		if(i_rstn == 1'b0)begin
734: 			reg_cross_config_snapshot <= {C_CONFIG_EPOCH_WIDTH{1'b0}};
735: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
736: 			reg_cross_config_snapshot <= {C_CONFIG_EPOCH_WIDTH{1'b0}};
737: 		end else if(flag_cross_transfer == 1'b1)begin
738: 			reg_cross_config_snapshot <= i_cross_config_epoch;
739: 		end else begin
740: 			reg_cross_config_snapshot <= reg_cross_config_snapshot;
741: 		end
742: 	end
```

### L745：reg_cross_coef_snapshot

```text
745: 	always@(posedge i_clk or negedge i_rstn)begin
746: 		if(i_rstn == 1'b0)begin
747: 			reg_cross_coef_snapshot <= {C_COEF_EPOCH_WIDTH{1'b0}};
748: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
749: 			reg_cross_coef_snapshot <= {C_COEF_EPOCH_WIDTH{1'b0}};
750: 		end else if(flag_cross_transfer == 1'b1)begin
751: 			reg_cross_coef_snapshot <= i_cross_coef_epoch;
752: 		end else begin
753: 			reg_cross_coef_snapshot <= reg_cross_coef_snapshot;
754: 		end
755: 	end
```

### L758：reg_cross_dc_snapshot

```text
758: 	always@(posedge i_clk or negedge i_rstn)begin
759: 		if(i_rstn == 1'b0)begin
760: 			reg_cross_dc_snapshot <= {C_DC_RECOVERY_EPOCH_WIDTH{1'b0}};
761: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
762: 			reg_cross_dc_snapshot <= {C_DC_RECOVERY_EPOCH_WIDTH{1'b0}};
763: 		end else if(flag_cross_transfer == 1'b1)begin
764: 			reg_cross_dc_snapshot <= i_cross_dc_recovery_coef_epoch;
765: 		end else begin
766: 			reg_cross_dc_snapshot <= reg_cross_dc_snapshot;
767: 		end
768: 	end
```

### L771：flag_pending_cross_time_unknown

```text
771: 	always@(posedge i_clk or negedge i_rstn)begin
772: 		if(i_rstn == 1'b0)begin
773: 			flag_pending_cross_time_unknown <= 1'b0;
774: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
775: 			flag_pending_cross_time_unknown <= 1'b0;
776: 		end else if(flag_cross_transfer == 1'b1)begin
777: 			flag_pending_cross_time_unknown <= i_cross_time_unknown;
778: 		end else begin
779: 			flag_pending_cross_time_unknown <= flag_pending_cross_time_unknown;
780: 		end
781: 	end
```

### L784：reg_return_frame_snapshot

```text
784: 	always@(posedge i_clk or negedge i_rstn)begin
785: 		if(i_rstn == 1'b0)begin
786: 			reg_return_frame_snapshot <= {C_FRAME_ID_WIDTH{1'b0}};
787: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
788: 			reg_return_frame_snapshot <= {C_FRAME_ID_WIDTH{1'b0}};
789: 		end else if(flag_return_transfer == 1'b1)begin
790: 			reg_return_frame_snapshot <= i_return_frame_id;
791: 		end else begin
792: 			reg_return_frame_snapshot <= reg_return_frame_snapshot;
793: 		end
794: 	end
```

### L797：enc_return_reason_snapshot

```text
797: 	always@(posedge i_clk or negedge i_rstn)begin
798: 		if(i_rstn == 1'b0)begin
799: 			enc_return_reason_snapshot <= RETURN_VALLEY_CONFIRMED;
800: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1)begin
801: 			enc_return_reason_snapshot <= RETURN_VALLEY_CONFIRMED;
802: 		end else if(flag_return_transfer == 1'b1)begin
803: 			if(i_return_reason == RETURN_RESERVED)begin
804: 				enc_return_reason_snapshot <= RETURN_PROTOCOL_FALLBACK;
805: 			end else begin
806: 				enc_return_reason_snapshot <= i_return_reason;
807: 			end
808: 		end else begin
809: 			enc_return_reason_snapshot <= enc_return_reason_snapshot;
810: 		end
811: 	end
```

### L814：flag_pending_return_reacquire

```text
814: 	always@(posedge i_clk or negedge i_rstn)begin
815: 		if(i_rstn == 1'b0)begin
816: 			flag_pending_return_reacquire <= 1'b0;
817: 		end else if(i_start_ack_event == 1'b1 || flag_lifecycle_cancel == 1'b1 || flag_return_commit == 1'b1)begin
818: 			flag_pending_return_reacquire <= 1'b0;
819: 		end else if(flag_return_transfer == 1'b1)begin
820: 			flag_pending_return_reacquire <= (i_return_reason != RETURN_VALLEY_CONFIRMED);
821: 		end else begin
822: 			flag_pending_return_reacquire <= flag_pending_return_reacquire;
823: 		end
824: 	end
```

### L827：flag_pending_cross

```text
827: 	always@(posedge i_clk or negedge i_rstn)begin
828: 		if(i_rstn == 1'b0)begin
829: 			flag_pending_cross <= 1'b0;
830: 		end else if(flag_cross_transfer == 1'b1)begin
831: 			flag_pending_cross <= 1'b1;
832: 		end else if(flag_lifecycle_cancel == 1'b1 || flag_enter_commit == 1'b1 || flag_switch_timeout_event == 1'b1)begin
833: 			flag_pending_cross <= 1'b0;
834: 		end else begin
835: 			flag_pending_cross <= flag_pending_cross;
836: 		end
837: 	end
```

### L840：flag_pending_return

```text
840: 	always@(posedge i_clk or negedge i_rstn)begin
841: 		if(i_rstn == 1'b0)begin
842: 			flag_pending_return <= 1'b0;
843: 		end else if(flag_return_transfer == 1'b1)begin
844: 			flag_pending_return <= 1'b1;
845: 		end else if(flag_lifecycle_cancel == 1'b1 || flag_return_commit == 1'b1 || flag_switch_timeout_event == 1'b1)begin
846: 			flag_pending_return <= 1'b0;
847: 		end else begin
848: 			flag_pending_return <= flag_pending_return;
849: 		end
850: 	end
```

### L853：flag_active_config_fault

```text
853: 	always@(*)begin
854: 		flag_active_config_fault = i_start_ack_event && (i_active_config_valid == 1'b0);
855: 	end
```

### L858：flag_characterization_request

```text
858: 	always@(*)begin
859: 		flag_characterization_request = i_run_enable && (i_run_profile == RUN_PROFILE_CHARACTERIZATION) && (i_cross_valid || i_return_9bit_valid);
860: 	end
```

### L863：flag_cross_return_collision

```text
863: 	always@(*)begin
864: 		flag_cross_return_collision = i_run_enable && i_cross_valid && i_return_9bit_valid;
865: 	end
```

### L868：flag_normal_start_illegal

```text
868: 	always@(*)begin
869: 		flag_normal_start_illegal = i_start_ack_event && (i_run_profile == RUN_PROFILE_NORMAL) && i_initial_precision;
870: 	end
```

### L873：flag_protocol_fault_pulse

```text
873: 	always@(*)begin
874: 		flag_protocol_fault_pulse = i_start_ack_event && flag_blocking_protocol_fault;
875: 	end
```

### L878：flag_recheck_in_fine

```text
878: 	always@(*)begin
879: 		flag_recheck_in_fine = i_run_enable && fine_window_active_o && i_recheck_busy;
880: 	end
```

### L883：flag_return_protocol_fallback

```text
883: 	always@(*)begin
884: 		flag_return_protocol_fallback = flag_return_transfer && ((i_return_reason == RETURN_PROTOCOL_FALLBACK) || (i_return_reason == RETURN_RESERVED));
885: 	end
```

### L888：flag_return_reserved

```text
888: 	always@(*)begin
889: 		flag_return_reserved = flag_return_transfer && (i_return_reason == RETURN_RESERVED);
890: 	end
```

## 文末汇总

(c)：V1-PWC-01～03（均中，取消/pending、取消/事件、diag/新故障）；待定：T-PWC-01～03。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
