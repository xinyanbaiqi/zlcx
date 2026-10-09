# V1 独立同拍冲突审查：supervisor

固定基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`，文件 `rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v`，行号均属基线。C24/B §3.6定义七lane、06/07 cause及summary位。使用erie-verilog-generator AST只读分析；未访问被隔离材料；没有仿真或RTL修改。

## 1. 来源和矩阵

Top L1409–1438逐字段输入AMI/FSC/SSW注册fault记录与active；AMI04/05不另开绕行路径。stop_episode来自唯一manager网（Top L1439），physical idle是Top L419直接扇出的外部真实状态（L1440）；diag由Top L328独立注册。源fault可以同时到达，不能以不同模块断言互斥。N=任一新记录/看门狗fire，H=三个active低且watchdog已恢复，D=diag&&!blocking&&!N，C=某来源捕获。异步reset与任何输入同拍(b)，最高优先。

| 对象/always | 全部非reset优先级 | 同拍处置及依据 |
|---|---|---|
| system_fault_blocking_o L257 | N置1 > H清0 > 保持 | N/H可同拍(b)，新故障胜出，C24 §4；D不直接释放episode(b)，§5 |
| system_abort_event_o L268、system_stop_request_event_o L279、system_fault_discard_event_o L290 | episode_open_edge=N&&!旧blocking置1 > 默认0 | N/旧episode高(a)不能再open；N与历史cause_valid1仍可open(b)，episode独立于历史，C24 §4；外部STOP/abort不直接发system_discard(b) |
| system_fault_cause_valid_o L302 | C置1 > D清0 > 保持 | C/D(a)，C要求N，D要求!N；未有snapshot时多来源并发(b)，固定WD>AMI>FSC>SSW；历史valid1时C全部0(b)，后故障只加summary |
| system_fault_cause/source/identity_valid/frame_id/sample_index/color/frame_type/precision/run_generation L313/324/335/346/357/368/379/390/401 | C原子装对应选中字段 > D清 > 保持 | 全组同谓词和mux优先级(b)，无分字段覆盖；非法身份mux归零(b)；WD与有身份源并发(b)，WD胜且无身份，C24 §4；其他来源仍进入summary |
| system_fault_summary_o L413 | new_bits非0按位OR > D清 > 保持 | 多来源/clear(b)，每个独立bit保留；new_bits与D直接(a)，D含!N；未识别cause的fault N=1但bits0，D被禁止，待T-SUP-01 |
| result_discard_summary_sticky_o L424 | measurement discard置1 > D清 > 保持 | discard/D可同拍(b)，新discard胜出；detection discard不置位(b)，C24编码职责 |
| cnt_adc_drain_watchdog L437 | idle或!episode清0 > window_active加1 > 保持 | 清/加(a)，window含episode&&!idle&&!timeout_latch；idle/阈值(a)，fire也含!idle，不产生伪超时；重复STOP不写本counter(b)，C24 §6 |
| flag_watchdog_timeout_latch L448 | idle&&!episode清 > watchdog fire置1 > 保持 | 清/fire(a)，idle正反；episode结束但ADC仍busy不清latch(b)，不能仅终止输入掩盖旧未恢复timeout |
| flag_watchdog_recovery_pending L459 | idle清 > fire置1 > 保持 | idle/fire(a)；恢复idle与sourcefault同拍(b)，watchdog恢复而N仍保留system blocking |

## 2. 上游互斥边界和合同差异

阈值fire=`episode && !idle && !latch && cnt==4999`（L193–194），只在真实第5000个连续忙采样发一次。复位、idle、episode撤销对计数优先正确；看门狗不生成RAW/完成/物理idle。**episode生产者有独立发现V1-MGR-01**：重复STOP与manager排空同拍可让episode跨RUN滞留。本模块没有自身RUN输入可重新判定episode合法性，不能把上游问题重复计为本地同拍缺陷；也不能用本模块门控正确证明整个系统watchdog合法。

C24旧文字将06/07、summary9/10列为reserved，B §3.6的明确裁定覆盖，RTL L226–227正确实现。C24 §4的watchdog恢复规则是“真实idle已采样”；§5表又要求idle且manager关闭drain episode，措辞更严格。RTL L191/L462实现前者，差异登记T-SUP-02，不擅自选一段判高严重度。

## 3. 待定、覆盖、结果

T-SUP-01：fault_valid=1但cause=00/保留码，尤其SSW START同新错配时可发valid而sticky已被清；supervisor会open episode却summary不置位。来源合同要求有效cause，完整链测试源恢复冲突，判定记录一致性。

T-SUP-02：WD timeout后idle=1、manager episode尚1时与三个active低同拍，验证system blocking允许落下的精确规则；需要统一C24 §4/§5的恢复意图。

T-SUP-03：新fault与episode关闭/diag在同沿及前后±1拍，检查每个episode只有一个注册abort/stop/discard，历史snapshot不被新episode覆盖。静态优先级正确，不把建议测试列成已失败。

覆盖19个always，全部目标列于§1，附录给出每块及完整条件/赋值顺序；无组合always，连续mux和summary OR均覆盖。本模块(c)无新增已确认项；待定T-SUP-01～03；上游关联V1-MGR-01。附录后保留文末汇总。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 257 | `system_fault_blocking_o` | seq |
| 268 | `system_abort_event_o` | seq |
| 279 | `system_stop_request_event_o` | seq |
| 290 | `system_fault_discard_event_o` | seq |
| 302 | `system_fault_cause_valid_o` | seq |
| 313 | `system_fault_cause_o` | seq |
| 324 | `system_fault_source_o` | seq |
| 335 | `system_fault_identity_valid_o` | seq |
| 346 | `system_fault_frame_id_o` | seq |
| 357 | `system_fault_sample_index_o` | seq |
| 368 | `system_fault_color_ir_o` | seq |
| 379 | `system_fault_frame_type_o` | seq |
| 390 | `system_fault_precision_o` | seq |
| 401 | `system_fault_run_generation_o` | seq |
| 413 | `system_fault_summary_o` | seq |
| 424 | `result_discard_summary_sticky_o` | seq |
| 437 | `cnt_adc_drain_watchdog` | seq |
| 448 | `flag_watchdog_timeout_latch` | seq |
| 459 | `flag_watchdog_recovery_pending` | seq |

### L257：system_fault_blocking_o

```text
257: 	always@(posedge i_clk or negedge i_rstn)begin
258: 		if(i_rstn == 1'b0)begin
259: 			system_fault_blocking_o <= 1'b0;
260: 		end else if(flag_new_any == 1'b1)begin
261: 			system_fault_blocking_o <= 1'b1;
262: 		end else if(flag_episode_close_condition == 1'b1)begin
263: 			system_fault_blocking_o <= 1'b0;
264: 		end
265: 	end
```

### L268：system_abort_event_o

```text
268: 	always@(posedge i_clk or negedge i_rstn)begin
269: 		if(i_rstn == 1'b0)begin
270: 			system_abort_event_o <= 1'b0;
271: 		end else if(flag_episode_open_edge == 1'b1)begin
272: 			system_abort_event_o <= 1'b1;
273: 		end else begin
274: 			system_abort_event_o <= 1'b0;
275: 		end
276: 	end
```

### L279：system_stop_request_event_o

```text
279: 	always@(posedge i_clk or negedge i_rstn)begin
280: 		if(i_rstn == 1'b0)begin
281: 			system_stop_request_event_o <= 1'b0;
282: 		end else if(flag_episode_open_edge == 1'b1)begin
283: 			system_stop_request_event_o <= 1'b1;
284: 		end else begin
285: 			system_stop_request_event_o <= 1'b0;
286: 		end
287: 	end
```

### L290：system_fault_discard_event_o

```text
290: 	always@(posedge i_clk or negedge i_rstn)begin
291: 		if(i_rstn == 1'b0)begin
292: 			system_fault_discard_event_o <= 1'b0;
293: 		end else if(flag_episode_open_edge == 1'b1)begin
294: 			system_fault_discard_event_o <= 1'b1;
295: 		end else begin
296: 			system_fault_discard_event_o <= 1'b0;
297: 		end
298: 	end
```

### L302：system_fault_cause_valid_o

```text
302: 	always@(posedge i_clk or negedge i_rstn)begin
303: 		if(i_rstn == 1'b0)begin
304: 			system_fault_cause_valid_o <= 1'b0;
305: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
306: 			system_fault_cause_valid_o <= 1'b1;
307: 		end else if(flag_diag_clear_legal == 1'b1)begin
308: 			system_fault_cause_valid_o <= 1'b0;
309: 		end
310: 	end
```

### L313：system_fault_cause_o

```text
313: 	always@(posedge i_clk or negedge i_rstn)begin
314: 		if(i_rstn == 1'b0)begin
315: 			system_fault_cause_o <= {C_FAULT_CAUSE_WIDTH{1'b0}};
316: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
317: 			system_fault_cause_o <= dec_selected_cause;
318: 		end else if(flag_diag_clear_legal == 1'b1)begin
319: 			system_fault_cause_o <= {C_FAULT_CAUSE_WIDTH{1'b0}};
320: 		end
321: 	end
```

### L324：system_fault_source_o

```text
324: 	always@(posedge i_clk or negedge i_rstn)begin
325: 		if(i_rstn == 1'b0)begin
326: 			system_fault_source_o <= {C_FAULT_SOURCE_WIDTH{1'b0}};
327: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
328: 			system_fault_source_o <= dec_selected_source;
329: 		end else if(flag_diag_clear_legal == 1'b1)begin
330: 			system_fault_source_o <= {C_FAULT_SOURCE_WIDTH{1'b0}};
331: 		end
332: 	end
```

### L335：system_fault_identity_valid_o

```text
335: 	always@(posedge i_clk or negedge i_rstn)begin
336: 		if(i_rstn == 1'b0)begin
337: 			system_fault_identity_valid_o <= 1'b0;
338: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
339: 			system_fault_identity_valid_o <= flag_selected_identity_valid;
340: 		end else if(flag_diag_clear_legal == 1'b1)begin
341: 			system_fault_identity_valid_o <= 1'b0;
342: 		end
343: 	end
```

### L346：system_fault_frame_id_o

```text
346: 	always@(posedge i_clk or negedge i_rstn)begin
347: 		if(i_rstn == 1'b0)begin
348: 			system_fault_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}};
349: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
350: 			system_fault_frame_id_o <= dec_selected_frame_id;
351: 		end else if(flag_diag_clear_legal == 1'b1)begin
352: 			system_fault_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}};
353: 		end
354: 	end
```

### L357：system_fault_sample_index_o

```text
357: 	always@(posedge i_clk or negedge i_rstn)begin
358: 		if(i_rstn == 1'b0)begin
359: 			system_fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
360: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
361: 			system_fault_sample_index_o <= dec_selected_sample_index;
362: 		end else if(flag_diag_clear_legal == 1'b1)begin
363: 			system_fault_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
364: 		end
365: 	end
```

### L368：system_fault_color_ir_o

```text
368: 	always@(posedge i_clk or negedge i_rstn)begin
369: 		if(i_rstn == 1'b0)begin
370: 			system_fault_color_ir_o <= 1'b0;
371: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
372: 			system_fault_color_ir_o <= flag_selected_color_ir;
373: 		end else if(flag_diag_clear_legal == 1'b1)begin
374: 			system_fault_color_ir_o <= 1'b0;
375: 		end
376: 	end
```

### L379：system_fault_frame_type_o

```text
379: 	always@(posedge i_clk or negedge i_rstn)begin
380: 		if(i_rstn == 1'b0)begin
381: 			system_fault_frame_type_o <= 2'b00;
382: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
383: 			system_fault_frame_type_o <= dec_selected_frame_type;
384: 		end else if(flag_diag_clear_legal == 1'b1)begin
385: 			system_fault_frame_type_o <= 2'b00;
386: 		end
387: 	end
```

### L390：system_fault_precision_o

```text
390: 	always@(posedge i_clk or negedge i_rstn)begin
391: 		if(i_rstn == 1'b0)begin
392: 			system_fault_precision_o <= 1'b0;
393: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
394: 			system_fault_precision_o <= flag_selected_precision;
395: 		end else if(flag_diag_clear_legal == 1'b1)begin
396: 			system_fault_precision_o <= 1'b0;
397: 		end
398: 	end
```

### L401：system_fault_run_generation_o

```text
401: 	always@(posedge i_clk or negedge i_rstn)begin
402: 		if(i_rstn == 1'b0)begin
403: 			system_fault_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}};
404: 		end else if(flag_capture_watchdog == 1'b1 || flag_capture_ami == 1'b1 || flag_capture_scheduler == 1'b1 || flag_capture_ssw == 1'b1)begin
405: 			system_fault_run_generation_o <= dec_selected_run_generation;
406: 		end else if(flag_diag_clear_legal == 1'b1)begin
407: 			system_fault_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}};
408: 		end
409: 	end
```

### L413：system_fault_summary_o

```text
413: 	always@(posedge i_clk or negedge i_rstn)begin
414: 		if(i_rstn == 1'b0)begin
415: 			system_fault_summary_o <= {C_FAULT_SUMMARY_WIDTH{1'b0}};
416: 		end else if(flag_new_summary_bits != {C_FAULT_SUMMARY_WIDTH{1'b0}})begin
417: 			system_fault_summary_o <= system_fault_summary_o | flag_new_summary_bits;
418: 		end else if(flag_diag_clear_legal == 1'b1)begin
419: 			system_fault_summary_o <= {C_FAULT_SUMMARY_WIDTH{1'b0}};
420: 		end
421: 	end
```

### L424：result_discard_summary_sticky_o

```text
424: 	always@(posedge i_clk or negedge i_rstn)begin
425: 		if(i_rstn == 1'b0)begin
426: 			result_discard_summary_sticky_o <= 1'b0;
427: 		end else if(i_measurement_result_discard_event == 1'b1)begin
428: 			result_discard_summary_sticky_o <= 1'b1;
429: 		end else if(flag_diag_clear_legal == 1'b1)begin
430: 			result_discard_summary_sticky_o <= 1'b0;
431: 		end
432: 	end
```

### L437：cnt_adc_drain_watchdog

```text
437: 	always@(posedge i_clk or negedge i_rstn)begin
438: 		if(i_rstn == 1'b0)begin
439: 			cnt_adc_drain_watchdog <= {C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH{1'b0}};
440: 		end else if(i_adc_physical_idle == 1'b1 || i_stop_episode_active == 1'b0)begin
441: 			cnt_adc_drain_watchdog <= {C_ADC_DRAIN_WATCHDOG_COUNTER_WIDTH{1'b0}};
442: 		end else if(flag_watchdog_window_active == 1'b1)begin
443: 			cnt_adc_drain_watchdog <= cnt_adc_drain_watchdog + 1'b1;
444: 		end
445: 	end
```

### L448：flag_watchdog_timeout_latch

```text
448: 	always@(posedge i_clk or negedge i_rstn)begin
449: 		if(i_rstn == 1'b0)begin
450: 			flag_watchdog_timeout_latch <= 1'b0;
451: 		end else if(i_adc_physical_idle == 1'b1 && i_stop_episode_active == 1'b0)begin
452: 			flag_watchdog_timeout_latch <= 1'b0;
453: 		end else if(flag_watchdog_timeout_fire == 1'b1)begin
454: 			flag_watchdog_timeout_latch <= 1'b1;
455: 		end
456: 	end
```

### L459：flag_watchdog_recovery_pending

```text
459: 	always@(posedge i_clk or negedge i_rstn)begin
460: 		if(i_rstn == 1'b0)begin
461: 			flag_watchdog_recovery_pending <= 1'b0;
462: 		end else if(i_adc_physical_idle == 1'b1)begin
463: 			flag_watchdog_recovery_pending <= 1'b0;
464: 		end else if(flag_watchdog_timeout_fire == 1'b1)begin
465: 			flag_watchdog_recovery_pending <= 1'b1;
466: 		end
467: 	end
```

## 文末汇总

(c)：无新增已确认项；待定：T-SUP-01～03；上游关联V1-MGR-01。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
