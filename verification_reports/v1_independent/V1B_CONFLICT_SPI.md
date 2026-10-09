# V1 独立同拍冲突审查：SPI寄存器文件

固定基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`；`rtl/ppg_spi_register_file/ppg_spi_register_file.v`，全部行号属该提交。依据芯片SPI/P2S合同§8/§9/§11、C03/C07及B §3.4的F-030已定CS_N规则。erie-verilog-generator formatter AST只读检查；未访问隔离审查材料，未改RTL/仿真。这里存在SPI source上/下降沿及2 MHz域，不能将跨域信号电平同高等同同一域采样沿。

## 1. 对象、所有条件和同拍对

| 对象/always | 全部优先级 | 条件对与处置 |
|---|---|---|
| state_current L377、state_next L386 | source reset或CS_N高回IDLE > next；组合unique state按byte_boundary/field推进 | reset/CS_N同拍(b)，同一reset分支；CS_N和SCLK同时变化的硬件建立/保持待T-SPI-01，不声称其构造互斥；CMD/ADDR/DUMMY/DATA分支(a)，唯一state |
| cnt_field_byte L418 | reset/CS_N清 > CMD byte末清 > ADDR首字节置1 > ADDR第二字节清 > DUMMY首置1 > DUMMY第二清 > 保持 | 两state(a)，ADDR或DUMMY首/次(a)，同一field位正反；CS_N/任意字段装(b)，帧结束优先 |
| reg_byte_addr L437 | reset/CS_N清 > ADDR首写高8 > ADDR次写低8 > DATA byte末+1 > 保持 | 高/低写(a)，field位相反；装地址/+1(a)，state相反；只一次写一个目标，没有高低片段同时覆盖；DATA读写都自动递增(b)，合同字节协议 |
| flag_cmd_is_read L452 | reset/CS_N清 > CMD byte末装bit7 > 保持 | CS_N/命令装(b)，事务结束优先；读/写命令(a)，同一个锁存位 |
| reg_read_byte L463 | reset/CS_N清 > load_read_byte装 > read DATA移位 > 保持 | load与read-shift可同拍(b)，load优先是byte第一位；shift在negedge，输入采样posedge，不把两沿当寄存多驱动；T-SPI-01覆盖CS边界 |
| cnt_bit_in_byte L477、reg_shift_in L486 | reset/CS_N清 > 每posedge递增/shift | byte末与帧结束(b)，reset优先；shift_in_next含当前SDI末bit，写提交读取同拍新组装值而非旧shift(b) |
| reg_active_shadow L495 | source reset清 > write_commit且地址0..127装一个byte > 保持 | shadow/char/debug/command写(a)，地址区间相反；写/读(a)，write_commit需!cmd_read；CS_N不擦shadow(b)，F-030已定持久配置；CS_N与写资格采样T-SPI-01 |
| reg_characterization L506、reg_dbg_out_select L517 | source reset清 > 地址128/129 write装 > 保持 | 两地址(a)；来源取消/CS_N不清已写影子(b)，C07不是RUN context；char held请求期间再次写shadow的有效载荷保持需要T-SPI-02 |
| flag_char_request_held L528 | source reset清 > char_update trigger置1 > held&&ready清 > 保持 | trigger与ready/旧held可同拍(b)，旧事务被ready接收、新请求继续保持；但characterization CDC需要valid回0重新armed，连续高的情况见T-SPI-02；不自动把重复命令全部判丢失 |
| reg_diag_snapshot L541 | system reset清 > capture trigger整组装 > 保持 | capture与measurement/detection discard同system沿可同拍，读取旧reg_mr/dd的NBA语义；合同snapshot采样边界未明确新事件应纳入，T-SPI-03；diag_clear仅改变上游历史，不直接清snapshot |
| reg_diag_snapshot_gated L553 | source reset清 > returned gate event整组装 > 保持 | source端读命令与系统capture不是同域沿；事件往返与稳定总线以2dummy bytes覆盖，合同4MHz上限/2MHz域前提；不按每bit独立同步论证原子性 |
| reg_diag_sync_stable L564 | source reset清 > 每拍装gated | gate装载/流水装载同source沿(b)，流水取旧gated、下一拍得到完整新值；读取第一数据字节前的时序预算T-SPI-04 |
| reg_mr_latch L573、reg_dd_latch L584 | system reset清 > 各自discard整组装并toggle bit0 > 保持 | measurement/detection同时event可同拍(b)，两独立寄存器；各自事件与snapshot同沿T-SPI-03；不因snapshot把pending事件清掉；双事件都进入38byte快照 |
| dec_read_byte L595 | shadow地址范围 >128 char >129 debug >144 command读0 >256..293诊断快照 >默认0 | 地址范围两两(a)，只一个16bit地址；全部路径有默认赋值，无后段覆盖前段有效诊断字节 |

组合命令L294–299同时允许START/STOP/COMMIT/diag/abort/char update，不自行排序；芯片合同§9条11明确要求多bit原子请求交Top消歧。六个pulse CDC输入分别由同一个flag_write_commit与shift_in_next对应bit产生，其结构相同（L613–672）；START/STOP同时bit高在源域**确实可同拍**，目标同拍并不应靠概率排除。Top再对STOP单独多注册一拍的问题单列V1-TOP-01，不重复计SPI缺陷。

## 2. 待定和覆盖

T-SPI-01：CS_N上升与source上/下降沿、byte末提交同一时刻的门级/RDC检查。异步协议reset优先已定F-030不重复报，纯RTL零延时同沿仿真不能证明电气安全；明确SDI/CS建立保持前提。

T-SPI-02：char trigger与held&&ready同沿，下一周期valid未回0、CDC reg_source_update_armed在L196–203必须先看到valid0才能重新接受，是否会卡住再次请求；同时检查保持型请求等待ready期间新char shadow写的稳定性。正常4MHz SPI一笔新地址命令需多个byte，CDC通常更快，必须追到源busy/armed的最大延迟并仿真合法SPI序列，不以任意force ready0代替生产反例。

T-SPI-03：capture_trigger、discard与diag清同system沿，对照合同快照时间戳定义，确认读取旧latch还是新事件；SPI§11.3已有“两个discard锁存toggle窄窗口”被裁定非bug，不重新推翻。T-SPI-04：4MHz上限及不利两时钟相位、source停钟/恢复，核验16dummy拍后返回门控capture+流水已稳定且整次read冻结。

全部18个always（source协议7个时序+state_next，persistent source4个、snapshot三块、discard两块、read mux一块）已覆盖；所有目标起点见矩阵/附录。无新增已确认(c)；待定T-SPI-01～04；关联Top多命令优先级问题另计。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 377 | `state_current` | seq |
| 386 | `state_next` | comb |
| 418 | `cnt_field_byte` | seq |
| 437 | `reg_byte_addr` | seq |
| 452 | `flag_cmd_is_read` | seq |
| 463 | `reg_read_byte` | seq |
| 477 | `cnt_bit_in_byte` | seq |
| 486 | `reg_shift_in` | seq |
| 495 | `reg_active_shadow` | seq |
| 506 | `reg_characterization` | seq |
| 517 | `reg_dbg_out_select` | seq |
| 528 | `flag_char_request_held` | seq |
| 541 | `reg_diag_snapshot` | seq |
| 553 | `reg_diag_snapshot_gated` | seq |
| 564 | `reg_diag_sync_stable` | seq |
| 573 | `reg_mr_latch` | seq |
| 584 | `reg_dd_latch` | seq |
| 595 | `dec_read_byte` | comb |

### L377：state_current

```text
377: 	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
378: 		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
379: 			state_current <= ST_IDLE;
380: 		end else begin
381: 			state_current <= state_next;
382: 		end
383: 	end
```

### L386：state_next

```text
386: 	always@(*)begin
387: 		state_next = state_current;
388: 		case(state_current)
389: 			ST_IDLE:begin
390: 				state_next = ST_CMD;
391: 			end
392: 			ST_CMD:begin
393: 				if(flag_byte_boundary)begin
394: 					state_next = ST_ADDR;
395: 				end
396: 			end
397: 			ST_ADDR:begin
398: 				if(flag_byte_boundary && (cnt_field_byte == 1'b1))begin
399: 					state_next = flag_cmd_is_read ? ST_DUMMY : ST_DATA;
400: 				end
401: 			end
402: 			ST_DUMMY:begin
403: 				if(flag_byte_boundary && (cnt_field_byte == 1'b1))begin
404: 					state_next = ST_DATA;
405: 				end
406: 			end
407: 			ST_DATA:begin
408: 				state_next = ST_DATA;
409: 			end
410: 			default:begin
411: 				state_next = ST_IDLE;
412: 			end
413: 		endcase
414: 	end
```

### L418：cnt_field_byte

```text
418: 	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
419: 		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
420: 			cnt_field_byte <= 1'b0;
421: 		end else if(flag_byte_boundary && (state_current == ST_CMD))begin
422: 			cnt_field_byte <= 1'b0;
423: 		end else if(flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b0))begin
424: 			cnt_field_byte <= 1'b1;
425: 		end else if(flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b1))begin
426: 			cnt_field_byte <= 1'b0;
427: 		end else if(flag_byte_boundary && (state_current == ST_DUMMY) && (cnt_field_byte == 1'b0))begin
428: 			cnt_field_byte <= 1'b1;
429: 		end else if(flag_byte_boundary && (state_current == ST_DUMMY) && (cnt_field_byte == 1'b1))begin
430: 			cnt_field_byte <= 1'b0;
431: 		end else begin
432: 			cnt_field_byte <= cnt_field_byte;
433: 		end
434: 	end
```

### L437：reg_byte_addr

```text
437: 	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
438: 		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
439: 			reg_byte_addr <= 16'd0;
440: 		end else if(flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b0))begin
441: 			reg_byte_addr[15:8] <= shift_in_next;
442: 		end else if(flag_byte_boundary && (state_current == ST_ADDR) && (cnt_field_byte == 1'b1))begin
443: 			reg_byte_addr[7:0] <= shift_in_next;
444: 		end else if(flag_byte_boundary && (state_current == ST_DATA))begin
445: 			reg_byte_addr <= reg_byte_addr + 16'd1;
446: 		end else begin
447: 			reg_byte_addr <= reg_byte_addr;
448: 		end
449: 	end
```

### L452：flag_cmd_is_read

```text
452: 	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
453: 		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
454: 			flag_cmd_is_read <= 1'b0;
455: 		end else if(flag_byte_boundary && (state_current == ST_CMD))begin
456: 			flag_cmd_is_read <= shift_in_next[7];
457: 		end else begin
458: 			flag_cmd_is_read <= flag_cmd_is_read;
459: 		end
460: 	end
```

### L463：reg_read_byte

```text
463: 	always@(negedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
464: 		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
465: 			reg_read_byte <= 8'h00;
466: 		end else if(flag_load_read_byte)begin
467: 			reg_read_byte <= dec_read_byte;
468: 		end else if(flag_cmd_is_read && (state_current == ST_DATA))begin
469: 			reg_read_byte <= {reg_read_byte[6:0], 1'b0};
470: 		end else begin
471: 			reg_read_byte <= reg_read_byte;
472: 		end
473: 	end
```

### L477：cnt_bit_in_byte

```text
477: 	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
478: 		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
479: 			cnt_bit_in_byte <= 3'd0;
480: 		end else begin
481: 			cnt_bit_in_byte <= cnt_bit_in_byte + 3'd1;
482: 		end
483: 	end
```

### L486：reg_shift_in

```text
486: 	always@(posedge i_source_clk or negedge i_source_rstn or posedge i_spi_cs_n)begin
487: 		if((i_source_rstn == 1'b0) || (i_spi_cs_n == 1'b1))begin
488: 			reg_shift_in <= 8'h00;
489: 		end else begin
490: 			reg_shift_in <= shift_in_next;
491: 		end
492: 	end
```

### L495：reg_active_shadow

```text
495: 	always@(posedge i_source_clk or negedge i_source_rstn)begin
496: 		if(i_source_rstn == 1'b0)begin
497: 			reg_active_shadow <= {1024{1'b0}};
498: 		end else if(flag_write_commit && (reg_byte_addr[15:7] == 9'd0))begin
499: 			reg_active_shadow[({reg_byte_addr[6:0], 3'b000}) +: 8] <= shift_in_next;
500: 		end else begin
501: 			reg_active_shadow <= reg_active_shadow;
502: 		end
503: 	end
```

### L506：reg_characterization

```text
506: 	always@(posedge i_source_clk or negedge i_source_rstn)begin
507: 		if(i_source_rstn == 1'b0)begin
508: 			reg_characterization <= 6'd0;
509: 		end else if(flag_write_commit && (reg_byte_addr == 16'd128))begin
510: 			reg_characterization <= shift_in_next[5:0];
511: 		end else begin
512: 			reg_characterization <= reg_characterization;
513: 		end
514: 	end
```

### L517：reg_dbg_out_select

```text
517: 	always@(posedge i_source_clk or negedge i_source_rstn)begin
518: 		if(i_source_rstn == 1'b0)begin
519: 			reg_dbg_out_select <= 3'd0;
520: 		end else if(flag_write_commit && (reg_byte_addr == 16'd129))begin
521: 			reg_dbg_out_select <= shift_in_next[2:0];
522: 		end else begin
523: 			reg_dbg_out_select <= reg_dbg_out_select;
524: 		end
525: 	end
```

### L528：flag_char_request_held

```text
528: 	always@(posedge i_source_clk or negedge i_source_rstn)begin
529: 		if(i_source_rstn == 1'b0)begin
530: 			flag_char_request_held <= 1'b0;
531: 		end else if(flag_trigger_char_update)begin
532: 			flag_char_request_held <= 1'b1;
533: 		end else if(flag_char_request_held && i_source_characterization_update_ready)begin
534: 			flag_char_request_held <= 1'b0;
535: 		end else begin
536: 			flag_char_request_held <= flag_char_request_held;
537: 		end
538: 	end
```

### L541：reg_diag_snapshot

```text
541: 	always@(posedge i_clk or negedge i_rstn)begin
542: 		if(i_rstn == 1'b0)begin
543: 			reg_diag_snapshot <= {304{1'b0}};
544: 		end else if(w_capture_trigger)begin
545: 			reg_diag_snapshot <= diag_snapshot_next;
546: 		end else begin
547: 			reg_diag_snapshot <= reg_diag_snapshot;
548: 		end
549: 	end
```

### L553：reg_diag_snapshot_gated

```text
553: 	always@(posedge i_source_clk or negedge i_source_rstn)begin
554: 		if(i_source_rstn == 1'b0)begin
555: 			reg_diag_snapshot_gated <= {304{1'b0}};
556: 		end else if(w_diag_snapshot_gate_event)begin
557: 			reg_diag_snapshot_gated <= reg_diag_snapshot;
558: 		end else begin
559: 			reg_diag_snapshot_gated <= reg_diag_snapshot_gated;
560: 		end
561: 	end
```

### L564：reg_diag_sync_stable

```text
564: 	always@(posedge i_source_clk or negedge i_source_rstn)begin
565: 		if(i_source_rstn == 1'b0)begin
566: 			reg_diag_sync_stable <= {304{1'b0}};
567: 		end else begin
568: 			reg_diag_sync_stable <= reg_diag_snapshot_gated;
569: 		end
570: 	end
```

### L573：reg_mr_latch

```text
573: 	always@(posedge i_clk or negedge i_rstn)begin
574: 		if(i_rstn == 1'b0)begin
575: 			reg_mr_latch <= 49'd0;
576: 		end else if(i_measurement_result_discard_event)begin
577: 			reg_mr_latch <= {i_measurement_result_discard_precision, i_measurement_result_discard_run_generation, i_measurement_result_discard_sample_index, i_measurement_result_discard_frame_id, i_measurement_result_discard_frame_type, i_measurement_result_discard_color_ir, i_measurement_result_discard_sample_valid, i_measurement_result_discard_identity_valid, i_measurement_result_discard_reason, ~reg_mr_latch[0]};
578: 		end else begin
579: 			reg_mr_latch <= reg_mr_latch;
580: 		end
581: 	end
```

### L584：reg_dd_latch

```text
584: 	always@(posedge i_clk or negedge i_rstn)begin
585: 		if(i_rstn == 1'b0)begin
586: 			reg_dd_latch <= 81'd0;
587: 		end else if(i_detection_discard_event)begin
588: 			reg_dd_latch <= {i_detection_discard_precision, i_detection_discard_run_generation, i_detection_discard_dc_code_epoch, i_detection_discard_amb_code_epoch, i_detection_discard_dc_recovery_epoch, i_detection_discard_coef_epoch, i_detection_discard_config_epoch, i_detection_discard_sample_index, i_detection_discard_frame_id, i_detection_discard_frame_type, i_detection_discard_color_ir, i_detection_discard_sample_valid, i_detection_discard_identity_valid, i_detection_discard_reason, ~reg_dd_latch[0]};
589: 		end else begin
590: 			reg_dd_latch <= reg_dd_latch;
591: 		end
592: 	end
```

### L595：dec_read_byte

```text
595: 	always@(*)begin
596: 		if(dec_read_load_addr[15:7] == 9'd0)begin
597: 			dec_read_byte = reg_active_shadow[({dec_read_load_addr[6:0], 3'b000}) +: 8];
598: 		end else if(dec_read_load_addr == 16'd128)begin
599: 			dec_read_byte = {2'b00, reg_characterization};
600: 		end else if(dec_read_load_addr == 16'd129)begin
601: 			dec_read_byte = {5'b00000, reg_dbg_out_select};
602: 		end else if(dec_read_load_addr == 16'd144)begin
603: 			dec_read_byte = 8'h00;
604: 		end else if((dec_read_load_addr >= 16'd256) && (dec_read_load_addr < 16'd294))begin
605: 			dec_read_byte = reg_diag_sync_stable[({diag_byte_offset[5:0], 3'b000}) +: 8];
606: 		end else begin
607: 			dec_read_byte = 8'h00;
608: 		end
609: 	end
```

## 文末汇总

(c)：无本文件新增已确认项；待定：T-SPI-01～04；关联V1-TOP-01。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
