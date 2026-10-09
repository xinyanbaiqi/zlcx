# V1 独立同拍冲突审查：S1冗余校正器

固定基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`，文件 `rtl/ppg_adc_s1_redundancy_corrector/ppg_adc_s1_redundancy_corrector.v`；所有行号为基线。C10为内部边界唯一权威，生命周期报告§2.2/B §3.6为作废前提。erie-verilog-generator AST只读检查，未访问隔离材料，未修RTL/仿真。

## 1. 上游与对象冲突矩阵

AMI L2873输入真实transaction_start_fire，L2874输入唯一owner_lost_fire，L2886输入capture_valid，L2887接S1校准器ready。lost fire要求AMI已有owner、!capture_valid、!completion_pending；new start要求AMI!owner，所以生产ABANDON与new start(a)，ABANDON与正常RAW transfer(a)，不能将模块任意输入之间的优先级误报为生产可达冲突。

X=有context的capture transfer L162；N=context transfer L164；Y=detect transfer L160；V=transaction abandon；D=armed且无context的late capture drop L165。reset所有对象优先(b)。

| 对象/always | 全部顺序 | 条件对与处置 |
|---|---|---|
| detect_code_o L206、stage1_raw_o L217、stage1_code_ext_o L228、stage2_raw_o L239、precision_mode_o L250 | X装 > 保持 | X/Y可同拍(b)，旧输出被ready消费后装新数据；X/N可同拍(b)，数据从当前RAW来；V/X生产(a)，AMI!capture_valid；reset/X(b) |
| metadata_o L261 | X装reg_context旧值 > 保持 | X/N可同拍(b)，非阻塞metadata取旧context，而N同时reg_context装新metadata，旧RAW不绑定新owner，C10接受沿身份原则 |
| detect_valid_o L272 | X置1 > Y清 > 保持 | X/Y可同拍(b)，X需output available即旧valid0或ready1，所以只在旧输出真正被消费时替换，置1保留新事务；V不直接清已保留输出(b)，AMI V条件排除completion pending |
| dec_detect_code L286 | signed ext<0置0 > ext>511置511 >取低9bit | 两饱和条件(a)，有序数值范围；三个分支完整，组合无第二次覆盖，无latch |
| reg_context L297 | N装metadata_input > 保持 | N/X同拍(b)，旧身份给旧RAW、新身份供下次；N/V生产(a)，如上；V不擦payload但清valid(b)，下次完整覆盖 |
| flag_capture_drop_armed L308 | N或D清 > V置1 > 保持 | N/D可同拍(b)，无旧context而late RAW已armed时本沿drop旧RAW、同时接新context；N/V与D/V生产(a)，V需capture_valid0，而D需1；模块边界若违反该前提则清优先，T-S1RC-02 |
| flag_context_valid L319 | N置1 > X清 > V清 > 保持 | N/X可同拍(b)，ready允许同沿替换context；N/V和X/V生产(a)；D无context，与X(a)，context正反；N/D可同拍(b)，新context保留而old RAW丢弃 |

组合C_METADATA拼接/输出切片完整按frame/sample/color/type/AMB/DC/code epoch对应；NBA取旧reg_context保证X/N同拍原子身份。数值扩位/钳位不是本轮多条件生命周期状态，但组合块也已完整覆盖。

## 2. 待定、覆盖、结果

T-S1RC-01：作废后迟到DONE在新start之前、同拍、之后约2拍，验证capture同步链和drop_armed共同作用。N清drop armed后，在新context出现后到达的旧RAW物理上不可分辨；这是B §3.6明确F-3前提，不作为新(c)复报，仍需真实9/15位DONE保持/2–20拍时延验证。

T-S1RC-02：单元边界V/N/X/D任意冲突与生产AMI门控对照，证明只由AMI唯一lost裁决驱动abandon，不能在其他hierarchy另发V。T-S1RC-03：下游ready反压时X/Y/N三路替换，比较每笔元数据与RAW，不能只测detect_code数值。

全部11个always：L206、217、228、239、250、261、272、286、297、308、319；目标一一见矩阵和完整附录。无新增已确认(c)；待定T-S1RC-01～03；已定同步窗口风险如实保留。

## 附录：全部 always 的对象和原始赋值顺序

由仓库技能 formatter AST 定位，只去掉注释和空行，保留基线行号、完整条件、else-if和全部赋值；这是阅读证据，不是替换RTL。

| 基线起点 | 目标 | 类型 |
|---:|---|---|
| 206 | `detect_code_o` | seq |
| 217 | `stage1_raw_o` | seq |
| 228 | `stage1_code_ext_o` | seq |
| 239 | `stage2_raw_o` | seq |
| 250 | `precision_mode_o` | seq |
| 261 | `metadata_o` | seq |
| 272 | `detect_valid_o` | seq |
| 286 | `dec_detect_code` | comb |
| 297 | `reg_context` | seq |
| 308 | `flag_capture_drop_armed` | seq |
| 319 | `flag_context_valid` | seq |

### L206：detect_code_o

```text
206: 	always@(posedge i_clk or negedge i_rstn)begin
207: 		if(i_rstn == 1'b0)begin
208: 			detect_code_o <= {C_DETECT_CODE_WIDTH{1'b0}};
209: 		end else if(flag_capture_transfer == 1'b1)begin
210: 			detect_code_o <= dec_detect_code;
211: 		end else begin
212: 			detect_code_o <= detect_code_o;
213: 		end
214: 	end
```

### L217：stage1_raw_o

```text
217: 	always@(posedge i_clk or negedge i_rstn)begin
218: 		if(i_rstn == 1'b0)begin
219: 			stage1_raw_o <= 10'b0000000000;
220: 		end else if(flag_capture_transfer == 1'b1)begin
221: 			stage1_raw_o <= i_capture_stage1_raw;
222: 		end else begin
223: 			stage1_raw_o <= stage1_raw_o;
224: 		end
225: 	end
```

### L228：stage1_code_ext_o

```text
228: 	always@(posedge i_clk or negedge i_rstn)begin
229: 		if(i_rstn == 1'b0)begin
230: 			stage1_code_ext_o <= 11'sd0;
231: 		end else if(flag_capture_transfer == 1'b1)begin
232: 			stage1_code_ext_o <= dec_stage1_code_ext;
233: 		end else begin
234: 			stage1_code_ext_o <= stage1_code_ext_o;
235: 		end
236: 	end
```

### L239：stage2_raw_o

```text
239: 	always@(posedge i_clk or negedge i_rstn)begin
240: 		if(i_rstn == 1'b0)begin
241: 			stage2_raw_o <= 10'b0000000000;
242: 		end else if(flag_capture_transfer == 1'b1)begin
243: 			stage2_raw_o <= i_capture_stage2_raw;
244: 		end else begin
245: 			stage2_raw_o <= stage2_raw_o;
246: 		end
247: 	end
```

### L250：precision_mode_o

```text
250: 	always@(posedge i_clk or negedge i_rstn)begin
251: 		if(i_rstn == 1'b0)begin
252: 			precision_mode_o <= 1'b0;
253: 		end else if(flag_capture_transfer == 1'b1)begin
254: 			precision_mode_o <= i_capture_precision_mode;
255: 		end else begin
256: 			precision_mode_o <= precision_mode_o;
257: 		end
258: 	end
```

### L261：metadata_o

```text
261: 	always@(posedge i_clk or negedge i_rstn)begin
262: 		if(i_rstn == 1'b0)begin
263: 			metadata_o <= {C_METADATA_WIDTH{1'b0}};
264: 		end else if(flag_capture_transfer == 1'b1)begin
265: 			metadata_o <= reg_context;
266: 		end else begin
267: 			metadata_o <= metadata_o;
268: 		end
269: 	end
```

### L272：detect_valid_o

```text
272: 	always@(posedge i_clk or negedge i_rstn)begin
273: 		if(i_rstn == 1'b0)begin
274: 			detect_valid_o <= 1'b0;
275: 		end else if(flag_capture_transfer == 1'b1)begin
276: 			detect_valid_o <= 1'b1;
277: 		end else if(flag_detect_transfer == 1'b1)begin
278: 			detect_valid_o <= 1'b0;
279: 		end else begin
280: 			detect_valid_o <= detect_valid_o;
281: 		end
282: 	end
```

### L286：dec_detect_code

```text
286: 	always@(*)begin
287: 		if(dec_stage1_code_ext < 11'sd0)begin
288: 			dec_detect_code = {C_DETECT_CODE_WIDTH{1'b0}};
289: 		end else if(dec_stage1_code_ext > 11'sd511)begin
290: 			dec_detect_code = DETECT_CODE_MAX;
291: 		end else begin
292: 			dec_detect_code = dec_stage1_code_ext[C_DETECT_CODE_WIDTH - 1:0];
293: 		end
294: 	end
```

### L297：reg_context

```text
297: 	always@(posedge i_clk or negedge i_rstn)begin
298: 		if(i_rstn == 1'b0)begin
299: 			reg_context <= {C_METADATA_WIDTH{1'b0}};
300: 		end else if(flag_context_transfer == 1'b1)begin
301: 			reg_context <= metadata_input;
302: 		end else begin
303: 			reg_context <= reg_context;
304: 		end
305: 	end
```

### L308：flag_capture_drop_armed

```text
308: 	always@(posedge i_clk or negedge i_rstn)begin
309: 		if(i_rstn == 1'b0)begin
310: 			flag_capture_drop_armed <= 1'b0;
311: 		end else if(flag_context_transfer == 1'b1 || flag_capture_drop == 1'b1)begin
312: 			flag_capture_drop_armed <= 1'b0;
313: 		end else if(i_transaction_abandon == 1'b1)begin
314: 			flag_capture_drop_armed <= 1'b1;
315: 		end
316: 	end
```

### L319：flag_context_valid

```text
319: 	always@(posedge i_clk or negedge i_rstn)begin
320: 		if(i_rstn == 1'b0)begin
321: 			flag_context_valid <= 1'b0;
322: 		end else if(flag_context_transfer == 1'b1)begin
323: 			flag_context_valid <= 1'b1;
324: 		end else if(flag_capture_transfer == 1'b1)begin
325: 			flag_context_valid <= 1'b0;
326: 		end else if(i_transaction_abandon == 1'b1)begin
327: 			flag_context_valid <= 1'b0;
328: 		end else begin
329: 			flag_context_valid <= flag_context_valid;
330: 		end
331: 	end
```

## 文末汇总

(c)：无新增已确认项；待定：T-S1RC-01～03；同步窗口F-3为已定前提。

全部always、对象及完整条件顺序如上。本次没有运行仿真；有系统可达性限制的项目必须按正文待定测试核验。
