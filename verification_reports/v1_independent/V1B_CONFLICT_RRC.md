# V1 独立同拍冲突审查：重检调度器

固定基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`；`rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v`。所有行号为基线。依据C16/C18及B §3.9用户已定F-9语义；erie-verilog-generator AST只读复核，未访问隔离材料，未仿真/改RTL。

## 1. 来源和对象矩阵

PWI L989/990把同一个generation discard apply接成STOP和abort，故这两个输入在生产中同源，不能误认为两种独立取消。RUN来自AMI/manager；样本接受和撤销由AMI实际消费/owner deadline或lost裁决扇入（AMI L2779–2781）；阶段done/request来自IDAC唯一状态机。安全接管来自真实ADC/IDAC/检测排空以及FSC macro boundary。阶段颜色转换不是新CONFIG操作。

reset所有对象最高(b)。K=START或STOP/abort/!RUN取消；E=sequence done/failed；H=interval hit；A=enter AMB；D=DCS accept；I=enter IR；Q=校准request transfer；U=撤销；V=匹配样本accepted。全部条件与语句在附录逐块展开。

| 对象/always | 全部顺序 | 同拍条件对与依据 |
|---|---|---|
| cnt_normal_frame_o L232 | K/E清 > H装interval > MONITOR无pending且period_enabled及NORMAL complete +1 > 保持 | H/普通+1可同拍(b)，阈值装载胜出；K/H可同拍(b)，取消优先；E/H(a)，stage与MONITOR状态相反；START/旧完成生产正常(a)，manager排空，但异常旧完成应做T-RRC-01 |
| amb_recheck_pending_o L247 | K/E清 > H置1 > 保持 | K/H(b)，取消优先；E/H(a)；不会在同一if后再次被H覆盖 |
| state_current L261、state_next L270 | K到MONITOR > E到MONITOR > unique case：pending/H与15→9选择WAIT_DRAIN/WAIT_SWITCH，switch event到WAIT_DRAIN，safe到AMB，阶段result&&frame到下一stage，DCS request到R，defaultMONITOR | K/任意stage条件可同拍(b)，取消优先；E和stage推进可同拍(b)，序列终止优先；H/switch event可同拍(b)，直接WAIT_DRAIN；done/failed同拍缺明确失败优先，结果两者都清状态，组合输出见T-RRC-02 |
| flag_stage_result_done L332 | K/E/A/D/I清 > AMB done置1 > RED出现IR sample request置1 > IR revalidate done置1 > 保持 | stage清/旧stage结果可同拍(b)，旧结果消费后新stage清；三个置位(a)，state编码相反；阶段结果/帧完成同拍(b)，available组合直接推进，无需多等一帧 |
| flag_stage_frame_complete L349 | K/E/A/D/I清 > 当前AMB/R/IR且CAL physical complete置1 > 保持 | 新stage与旧CAL完成同拍(b)，旧stage消费，新stage从0开始；较早帧完成保持到阶段结果(b)，B §3.9明确允许，**不是F-9新缺陷** |
| flag_sample_inflight L363 | K/E/A/D/I清 > V清 > U清 > Q置1 > 保持 | V/Q正常(a)，old inflight1使request_valid0；U/Q生产正常(a)，AMI withdraw必须对应已接受旧请求，AMI/PWI都禁止在途再请求；若单元外部直接无关U/Q同时高则clear优先，待T-RRC-03；K/Q(b)，取消最高，但组合valid仍见下一段 |

组合全部输出同拍检查：o_calibration_sample_valid L211按unique stage及!sample_inflight/!stage_result_available；payload L212–216有enter_IR预选下一颜色；o_sequence_done/failed L196/197、o_dcs_revalidate_accept L191、frame_start L215没有统一cancel门。因此输入cancel与这些“旧state观察输出”可以并存；生产AMI precision_calibration_ready L977受flag_start_blocked封闭，IDAC的FSM/上下文也受取消，所以不能仅看组合valid高就认定真实新owner已发。需要T-RRC-01/02确认合同是否要求这些对外事件本身同拍归零。

## 2. 待定、覆盖、结果

T-RRC-01：scope-discard与stage request/frame_start/DCS accept同拍；记录AMI ready/真实Q、IDAC实际动作，不能把valid替代fire。T-RRC-02：sequence done与failed同时高以及取消与done/failed同拍，确认失败原因和PWI detector释放不被成功标记覆盖；通过IDAC真实成功/耗尽来源构造，普通互斥需要逐状态证明。T-RRC-03：withdraw紧接或同拍新request，把SID-05、lost重发与跨阶段改变逐路对齐，确保清旧inflight不会吞新请求。

全部7个always已覆盖，寄存器/计数器/state及组合阶段输出列于§1/附录。接受B §3.9允许沿用本阶段任一次物理帧完成、不要求最后样本晚于它；不把已裁定规则标成(c)。本模块没有新增已确认(c)项；待定T-RRC-01～03。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 232 | `cnt_normal_frame_o` | seq |
| 247 | `amb_recheck_pending_o` | seq |
| 261 | `state_current` | seq |
| 270 | `state_next` | comb |
| 332 | `flag_stage_result_done` | seq |
| 349 | `flag_stage_frame_complete` | seq |
| 363 | `flag_sample_inflight` | seq |

### L232：cnt_normal_frame_o

```text
232: 	always@(posedge i_clk or negedge i_rstn)begin
233: 		if(i_rstn == 1'b0)begin
234: 			cnt_normal_frame_o <= 16'd0;
235: 		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1)begin
236: 			cnt_normal_frame_o <= 16'd0;
237: 		end else if(flag_interval_hit == 1'b1)begin
238: 			cnt_normal_frame_o <= i_amb_recheck_interval_frames;
239: 		end else if((state_current == ST_MONITOR) && (amb_recheck_pending_o == 1'b0) && flag_period_enabled == 1'b1 && i_normal_frame_complete_event == 1'b1)begin
240: 			cnt_normal_frame_o <= cnt_normal_frame_o + 16'd1;
241: 		end else begin
242: 			cnt_normal_frame_o <= cnt_normal_frame_o;
243: 		end
244: 	end
```

### L247：amb_recheck_pending_o

```text
247: 	always@(posedge i_clk or negedge i_rstn)begin
248: 		if(i_rstn == 1'b0)begin
249: 			amb_recheck_pending_o <= 1'b0;
250: 		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1)begin
251: 			amb_recheck_pending_o <= 1'b0;
252: 		end else if(flag_interval_hit == 1'b1)begin
253: 			amb_recheck_pending_o <= 1'b1;
254: 		end else begin
255: 			amb_recheck_pending_o <= amb_recheck_pending_o;
256: 		end
257: 	end
```

### L261：state_current

```text
261: 	always@(posedge i_clk or negedge i_rstn)begin
262: 		if(i_rstn == 1'b0)begin
263: 			state_current <= ST_MONITOR;
264: 		end else begin
265: 			state_current <= state_next;
266: 		end
267: 	end
```

### L270：state_next

```text
270: 	always@(*)begin
271: 		state_next = state_current;
272: 		if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1)begin
273: 			state_next = ST_MONITOR;
274: 		end else if(enc_sequence_failed_o == 1'b1 || enc_sequence_done_o == 1'b1)begin
275: 			state_next = ST_MONITOR;
276: 		end else begin
277: 			case(state_current)
278: 				ST_MONITOR:begin
279: 					if(amb_recheck_pending_o == 1'b1 || flag_interval_hit == 1'b1)begin
280: 						if(i_precision_15_to_9_event == 1'b1)begin
281: 							state_next = ST_WAIT_DRAIN;
282: 						end else begin
283: 							state_next = ST_WAIT_SWITCH;
284: 						end
285: 					end
286: 				end
287: 				ST_WAIT_SWITCH:begin
288: 					if(i_precision_15_to_9_event == 1'b1)begin
289: 						state_next = ST_WAIT_DRAIN;
290: 					end
291: 				end
292: 				ST_WAIT_DRAIN:begin
293: 					if(flag_takeover_safe == 1'b1)begin
294: 						state_next = ST_AMB;
295: 					end
296: 				end
297: 				ST_AMB:begin
298: 					if(flag_stage_result_available == 1'b1 && flag_stage_frame_available == 1'b1)begin
299: 						if(i_dcs_enable == 1'b1)begin
300: 							state_next = ST_WAIT_DCS_ACCEPT;
301: 						end else begin
302: 							state_next = ST_MONITOR;
303: 						end
304: 					end
305: 				end
306: 				ST_WAIT_DCS_ACCEPT:begin
307: 					if(i_dcs_enable == 1'b0)begin
308: 						state_next = ST_MONITOR;
309: 					end else if(i_dcs_revalidate_request == 1'b1)begin
310: 						state_next = ST_DCS_R;
311: 					end
312: 				end
313: 				ST_DCS_R:begin
314: 					if(flag_stage_result_available == 1'b1 && flag_stage_frame_available == 1'b1)begin
315: 						state_next = ST_DCS_IR;
316: 					end
317: 				end
318: 				ST_DCS_IR:begin
319: 					if(flag_stage_result_available == 1'b1 && flag_stage_frame_available == 1'b1)begin
320: 						state_next = ST_MONITOR;
321: 					end
322: 				end
323: 				default:begin
324: 					state_next = ST_MONITOR;
325: 				end
326: 			endcase
327: 		end
328: 	end
```

### L332：flag_stage_result_done

```text
332: 	always@(posedge i_clk or negedge i_rstn)begin
333: 		if(i_rstn == 1'b0)begin
334: 			flag_stage_result_done <= 1'b0;
335: 		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1 || flag_enter_amb == 1'b1 || dcs_revalidate_accept_o == 1'b1 || flag_enter_ir == 1'b1)begin
336: 			flag_stage_result_done <= 1'b0;
337: 		end else if((state_current == ST_AMB) && i_amb_sequence_done == 1'b1)begin
338: 			flag_stage_result_done <= 1'b1;
339: 		end else if((state_current == ST_DCS_R) && i_dcs_sample_request == 1'b1 && i_dcs_sample_color_ir == 1'b1)begin
340: 			flag_stage_result_done <= 1'b1;
341: 		end else if((state_current == ST_DCS_IR) && i_dcs_revalidate_done == 1'b1)begin
342: 			flag_stage_result_done <= 1'b1;
343: 		end else begin
344: 			flag_stage_result_done <= flag_stage_result_done;
345: 		end
346: 	end
```

### L349：flag_stage_frame_complete

```text
349: 	always@(posedge i_clk or negedge i_rstn)begin
350: 		if(i_rstn == 1'b0)begin
351: 			flag_stage_frame_complete <= 1'b0;
352: 		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1 || flag_enter_amb == 1'b1 || dcs_revalidate_accept_o == 1'b1 || flag_enter_ir == 1'b1)begin
353: 			flag_stage_frame_complete <= 1'b0;
354: 		end else if(((state_current == ST_AMB) || (state_current == ST_DCS_R) || (state_current == ST_DCS_IR)) && i_calibration_frame_complete_event == 1'b1)begin
355: 			flag_stage_frame_complete <= 1'b1;
356: 		end else begin
357: 			flag_stage_frame_complete <= flag_stage_frame_complete;
358: 		end
359: 	end
```

### L363：flag_sample_inflight

```text
363: 	always@(posedge i_clk or negedge i_rstn)begin
364: 		if(i_rstn == 1'b0)begin
365: 			flag_sample_inflight <= 1'b0;
366: 		end else if(i_start_ack_event == 1'b1 || flag_control_cancel == 1'b1 || enc_sequence_done_o == 1'b1 || enc_sequence_failed_o == 1'b1 || flag_enter_amb == 1'b1 || dcs_revalidate_accept_o == 1'b1 || flag_enter_ir == 1'b1)begin
367: 			flag_sample_inflight <= 1'b0;
368: 		end else if(flag_matching_sample_accepted == 1'b1)begin
369: 			flag_sample_inflight <= 1'b0;
370: 		end else if(i_calibration_request_withdraw_event == 1'b1)begin
371: 			flag_sample_inflight <= 1'b0;
372: 		end else if(flag_calibration_transfer == 1'b1)begin
373: 			flag_sample_inflight <= 1'b1;
374: 		end else begin
375: 			flag_sample_inflight <= flag_sample_inflight;
376: 		end
377: 	end
```

## 文末汇总

(c)：无新增已确认项；待定：T-RRC-01～03；F-9按用户裁定保留。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
