# V1 独立同拍冲突审查：PWI

基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`；`rtl/ppg_precision_window_integration/ppg_precision_window_integration.v`，行号均基线。C18/C19/C20/C22/C23为依据，erie-verilog-generator AST只读审查；未访问隔离材料；未仿真/修RTL。范围是本文件六个always及child边界，不将未审child算法冒充完整子系统闭合。

## 1. 来源、对象和优先级

AMI L2693–2709原样接generation discard和scope，不依赖触发identity_valid。PWI L446只比较generation，L447把!RUN、START、匹配discard、重检accept合成fork_clear。FIR ready/valid经L438–443将一笔保留载荷叉分为baseline和peak-valley两消费者；两个消费者ready可不同步，两pending不能互相清除。

定义K=fork_clear，F=FIR output transfer，B/V=baseline/peak-valley transfer，R=重检accept，E=done/failed，C=匹配scope-discard，P=15→9 event。reset优先(b)。

| 对象/always | 全部条件顺序 | 条件对及处置 |
|---|---|---|
| detection_datapath_empty_o L521 | reset0 > 每拍装fork idle &&四child local empty | incoming F、AMI新检测样本、C与旧empty组合可同拍；注册聚合有一个周期滞后，T-PWI-01，不能仅因布尔AND正确宣称无假empty |
| reg_fork_payload L531 | K清 > F装 > 保持 | K/F可同拍(b)，取消胜出；C与payload任意载荷同拍(b)，generation flush不要求identity匹配；F与B/V可同拍(b)，旧数据沿前被消费、沿后整体换新payload |
| flag_baseline_pending L542 | K清 > F置1 > B清 > 保持 | F/B可同拍(b)，新装优先，避免旧释放吞新valid；仅B不影响V(b)，C18叉分；K/F/B可同拍(b)，flush最高 |
| flag_peak_valley_pending L555 | K清 > F置1 > V清 > 保持 | 与上行对称，F/V可同拍(b)；F要求所有旧pending均ready或空（L440/442），不能在一侧stall时换payload(a)，保证迟到消费者读旧事务 |
| flag_recheck_detector_busy L568 | S/C/E/!RUN清 > R置1 > 保持 | R/E正常(a)，R需WAIT_DRAIN而E来自各stage；C/R(a)，R在RRC L189含!cancel；S/R生产(a)，manager START前重检idle；!RUN/R(a)同门控；非法child事件重合时清优先(b) |
| flag_fir_idle_to_scheduler L579 | S/C/P/R/!RUN清 > FIR idle且fork idle置1 > 默认0 | 清与empty证明可同拍(b)，撤销旧证据最高；P与safe接管依赖旧idle时刻，下一拍再证明，打断组合环符合C18；C/输入到达仍须测T-PWI-01 |

下游边界：FIR、baseline、peak-valley、precision四路discard全部直接广播；RRC STOP/abort均接匹配generation apply（L989/990），不是第二种独立flush来源。cross/return没有在PWI遮C，而是直接送precision（L939/947），故本地fork取消正确不证明precision pending取消正确，V1-PWC-01独立归属PWC。peak_valley_config_valid统一扇出，低门控可以安全drain而不能推进正式检测，按合同不产生额外故障。

组合enc_fir_payload/解包L435/437顺序一一对应，所有字段同一个reg_fork_payload，不分字段覆盖。FIR/filter/峰谷本地状态不在本文件，不能把接口检查说成child全部always已经审完。

## 2. 待定、覆盖、结果

T-PWI-01：从empty状态同沿接纳新检测或FIR结果，下一周期registered empty仍取旧值；将STOP/abort、AMI最后一个检测transfer、四child local_empty和manager STOPPING完成逐拍对齐，证明聚合不会让manager提前完成。有ADC/AMI额外pending可能提供保守遮挡，未追到绝对排除前不下(a)结论。

T-PWI-02：C或重检accept与F和双branch ready同沿，检查child端没有取消后算法推进/输出新cross/return；本文件K优先已正确，需要合同范围内child实际行为验证。T-PWI-03：stale generation discard与当前载荷正常transfer，证明只忽略旧flush、不影响新generation；无identity的scope-only当前flush必须全部清。

已覆盖6个always全部目标，连续资格/mux和四child连接逐路核对，附录逐块完整列出。没有本文件新增已确认(c)；待定T-PWI-01～03；关联PWC取消反例不重复计数。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 521 | `detection_datapath_empty_o` | seq |
| 531 | `reg_fork_payload` | seq |
| 542 | `flag_baseline_pending` | seq |
| 555 | `flag_peak_valley_pending` | seq |
| 568 | `flag_recheck_detector_busy` | seq |
| 579 | `flag_fir_idle_to_scheduler` | seq |

### L521：detection_datapath_empty_o

```text
521: 	always@(posedge i_clk or negedge i_rstn)begin
522: 		if(i_rstn == 1'b0)begin
523: 			detection_datapath_empty_o <= 1'b0;
524: 		end else begin
525: 			detection_datapath_empty_o <= detection_fork_idle_o && fir_local_empty_o && baseline_local_empty_o && peak_valley_local_empty_o && precision_local_empty_o;
526: 		end
527: 	end
```

### L531：reg_fork_payload

```text
531: 	always@(posedge i_clk or negedge i_rstn)begin
532: 		if(i_rstn == 1'b0)begin
533: 			reg_fork_payload <= {FORK_PAYLOAD_WIDTH{1'b0}};
534: 		end else if(flag_fork_clear == 1'b1)begin
535: 			reg_fork_payload <= {FORK_PAYLOAD_WIDTH{1'b0}};
536: 		end else if(flag_fir_output_transfer == 1'b1)begin
537: 			reg_fork_payload <= enc_fir_payload;
538: 		end
539: 	end
```

### L542：flag_baseline_pending

```text
542: 	always@(posedge i_clk or negedge i_rstn)begin
543: 		if(i_rstn == 1'b0)begin
544: 			flag_baseline_pending <= 1'b0;
545: 		end else if(flag_fork_clear == 1'b1)begin
546: 			flag_baseline_pending <= 1'b0;
547: 		end else if(flag_fir_output_transfer == 1'b1)begin
548: 			flag_baseline_pending <= 1'b1;
549: 		end else if(flag_baseline_transfer == 1'b1)begin
550: 			flag_baseline_pending <= 1'b0;
551: 		end
552: 	end
```

### L555：flag_peak_valley_pending

```text
555: 	always@(posedge i_clk or negedge i_rstn)begin
556: 		if(i_rstn == 1'b0)begin
557: 			flag_peak_valley_pending <= 1'b0;
558: 		end else if(flag_fork_clear == 1'b1)begin
559: 			flag_peak_valley_pending <= 1'b0;
560: 		end else if(flag_fir_output_transfer == 1'b1)begin
561: 			flag_peak_valley_pending <= 1'b1;
562: 		end else if(flag_peak_valley_transfer == 1'b1)begin
563: 			flag_peak_valley_pending <= 1'b0;
564: 		end
565: 	end
```

### L568：flag_recheck_detector_busy

```text
568: 	always@(posedge i_clk or negedge i_rstn)begin
569: 		if(i_rstn == 1'b0)begin
570: 			flag_recheck_detector_busy <= 1'b0;
571: 		end else if(i_start_ack_event == 1'b1 || flag_detection_discard_apply == 1'b1 || flag_recheck_done_event == 1'b1 || (i_run_enable == 1'b0))begin
572: 			flag_recheck_detector_busy <= 1'b0;
573: 		end else if(amb_recheck_accept_o == 1'b1)begin
574: 			flag_recheck_detector_busy <= 1'b1;
575: 		end
576: 	end
```

### L579：flag_fir_idle_to_scheduler

```text
579: 	always@(posedge i_clk or negedge i_rstn)begin
580: 		if(i_rstn == 1'b0)begin
581: 			flag_fir_idle_to_scheduler <= 1'b0;
582: 		end else if(i_start_ack_event == 1'b1 || flag_detection_discard_apply == 1'b1 || precision_15_to_9_event_o == 1'b1 || amb_recheck_accept_o == 1'b1 || (i_run_enable == 1'b0))begin
583: 			flag_fir_idle_to_scheduler <= 1'b0;
584: 		end else if(fir_idle_o == 1'b1 && detection_fork_idle_o == 1'b1)begin
585: 			flag_fir_idle_to_scheduler <= 1'b1;
586: 		end else begin
587: 			flag_fir_idle_to_scheduler <= 1'b0;
588: 		end
589: 	end
```

## 文末汇总

(c)：无本文件新增已确认项；待定：T-PWI-01～03；关联V1-PWC-01。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
