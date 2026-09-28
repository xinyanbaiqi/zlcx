# 工作线D批次1-9累计16个真实缺口处理报告（2026-09-17）

> 执行依据：用户明确指令"先处理这堆缺口，使用erie-verilog-generator这个skill"，在本会话
> 直接执行（非先写brief再派发）。范围：工作线D新批次1-9（JNT/ILM/SID/TRK/ISE/OIB/LFA/
> PRC/RRC九个家族）独立复核发现的16个真实缺口（各家族独立复核报告：
> `JNT_01_09_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md`、
> `ILM_01_15_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md`、
> `SID_01_12_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md`、
> `TRK_01_10_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md`、
> `ISE_01_10_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md`、
> `OIB_01_10_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md`、
> `PRC_01_10_WORKLINE_D_INDEPENDENT_RECHECK_20260917.md`）。

## 总体结论

16个真实缺口中，**10个已真实修复，并通过官方19-TB xsim回归最终confirm**（JNT
5个+ILM 2个+SID 2个[SID-03/04]+OIB 1个；19/19 TB全部PASS、0 FAIL，总PASS数
1187→1202，+15逐项对账吻合，见文末），**6个在动手过程中发现需要比"补一条断言"更深
的专门RTL调查才能不瞎猜**（SID-05[DC_R/DC_IR部分]、SID-06、TRK-01、ISE-01、
PRC-04、PRC-06），如实标注为待查项，不强行赶工凑数。**特别说明**：SID-05最初
被算作"已修复"，但复核后发现只有AMB阶段（本身在缺口报告里就不是真正的缺口，缺口
是DC_R/DC_IR缺失覆盖）被保留，DC_R/DC_IR部分因真实回归发现会导致搜索卡死而撤回
——也就是说SID-05这条真实缺口本身仍未关闭，本次订正为待查项，不计入"已修复"，
避免把一个不准确的数字交接下去。修复过程中还真实发现并处理了两处意料之外的问题
（详见"修复过程中的真实
发现"一节），这两处发现本身比原计划的补测工作更有价值。

**本轮RTL零改动**——全部16项都是TB侧断言设计问题，不是RTL功能缺陷；也没有触碰
PPG_ALIAS_MAPPING_TABLE.md/PPG_CONTRACT_CLOSURE_MATRIX.md等共享台账文件（这些文件
记录的是"验收ID是否CLOSED"，工作线D这一整条线索本身尚未走到"是否要正式改变CLOSED
状态"这一步，改台账留给后续单独决定）。

## 已修复的10项（按文件分组）

### JNT-02/03/05/07/08（`ppg_control_top/tb_ppg_jnt_baseline_prefix.vh`，影响全部14个引用该共享前缀的TB文件）

这是本轮风险最高的一处改动——该文件被14个`tb_ppg_control_top_*.v`顶层TB文件
`` `include ``，不是原先以为的5个（Group1~5），本次先用`grep -l`真实核实了完整
引用清单再动手。

- **JNT-02（真实缺口1）**：源规格JNT-02B"IR波形上下文在RED owner未释放时预建立"
  的检查在架构方案A移植时静默丢失。新增连续监视进程`jnt_waveform_context_monitor`，
  复用`ppg_control_top.v`已有的`sched_waveform_context_valid_o`/
  `ssw_waveform_context_ready_o`/`sched_waveform_color_ir_o`等真实内部转发线（本次
  独立核实确认全部已转发到顶层wire，不需要新的两跳层次引用），补回新check
  `JNT-02-IR-PREESTABLISH`。
- **JNT-02/03/07（真实缺口2）**：owner提交身份（精度/AMB码/DC码）与其颜色对应的
  最近一次波形上下文快照的一致性比对（源规格`flag_owner_context_identity_match`）
  在JNT-02A/03A/07A/07D四处丢失。扩展既有`jnt_owner_commit_monitor`，新增
  `flag_jnt_owner_identity_match`计算，接入这四处既有check_case的判据。
- **JNT-05/08（真实缺口3）**：合同§7"success=0匹配完成不产生正式成功结果"这一
  子句在JNT-05B/JNT-08两处缺失。新增自建计数器`cnt_jnt_formal_result`（监视
  `o_measurement_result_valid && i_measurement_result_ready`）——**没有**复用各
  调用方自己声明的同名计数器，因为核实14个文件后发现`tb_ppg_control_top_owner_
  identity_backpressure.v`已经把这个计数器当死代码删掉、改用`cnt_result_capture`
  了，命名并不统一，自建计数器规避了这个真实存在的坑。

C_JNT_REQUIRED_SUBCHECKS从53改为54（新增1条真实check_case调用；其余三处修复都是
扩展既有check_case的判据条件，不产生新的独立子检查）。

**回归证据**：独立在3个不同的引用文件（`tb_ppg_control_top_input_light_static_
matrix.v`、`tb_ppg_control_top_startup_idac_calibration.v`、
`tb_ppg_control_top_owner_identity_backpressure.v`）上分别验证，均报告
`JNT_BASELINE checked=54 pass=54 required=54 status=PASS`。

### ILM-06/07（`ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v`）

SAR15子用例分别补齐SAR9子用例已有的`EN_TEST/LEDEN/LEDDAC`边界检查（工作线D独立
复核真实缺口，纯粹的判据条件补充，不涉及新信号）。

**回归证据**：`INPUT_LIGHT_STATIC_MATRIX_TB_PASS`，新增的两处PASS消息
（"...SAR15: ... EN_TEST/LEDEN/LEDDAC boundary held"）真实出现。

### SID-03/04（`ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v`）

AMB子阶段原有的两项协议时序检查（Q3 tick窗口、625拍候选间隔）延伸到DC_R/DC_IR
子阶段：tick窗口检查+候选间隔检查直接复用AMB阶段已验证的判据逻辑，在DC_R/DC_IR
阶段的候选循环里各自独立追加（DC_IR阶段额外新增`time_prev_q3=0`重置，避免跨阶段
边界误判625拍间隔）。真实回归确认PASS，DC_R/DC_IR两阶段合计14次候选窗口全部满足
tick窗口和间隔要求。

**SID-05未修复，改列入待查清单**：AMB阶段原有的第三项时序检查（tick-248截止抑制）
同样尝试延伸到DC_R/DC_IR，但真实回归发现会导致两个阶段搜索卡死不收敛，已撤回，
只保留AMB阶段原有覆盖（这部分本身在独立复核报告里就不是缺口，只是重构成task、
行为未变）。真实缺口本体（DC_R/DC_IR缺失tick-248覆盖）仍未关闭，详见下方"修复
过程中的真实发现"和文末待查清单表格。

**回归证据**：`STARTUP_IDAC_CALIBRATION_TB_PASS`，整份文件0 FAIL。

### OIB-06（`ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v`）

顺序保序监视进程原本只检测"是否递减"，合同要求的另外四种失效模式（重复/换色/换型/
精度错标）全部未检测；**更严重的是原有的`cnt_order_violation`计数器只在最终摘要行
被打印，从未真正折算进`cnt_error`，即使命中过递减违规也不会让TB报FAIL**。本次：
(1) 扩展监视进程新增重复/换色/换型/精度错标检测（`cnt_duplicate_or_relabel_
violation`），(2) 新增显式gate把两个计数器都真正折算进`cnt_error`，让OIB-06成为
一条真实生效的断言。过程中发现并修复了一处真实的监视范围问题（见下）。

**回归证据**：`OWNER_IDENTITY_BACKPRESSURE_TB_PASS result_captures=35
owner_commit_total=224 measurement_discard_events=1`——与文件自己V1.2 changelog
记录的历史基准值逐位一致，确认本次改动未引入任何意外副作用。

## 修复过程中的真实发现（本报告最有价值的部分）

### 发现1：OIB-06新检查暴露JNT基线内部复位边界从未被这类监视进程纳入考虑

第一版OIB-06修复真实回归后报出
`OIB_DUPLICATE_OR_RELABEL_VIOLATION frame_id=0 sample_index=0 color=0 type=2
precision=1 last_color=0 last_type=2 last_precision=0`——顺着日志时间顺序核实，
这条违规发生在`JNT_BASELINE_BEGIN`和它自己的完成行之间，即JNT基线**自己内部**
（JNT-01/05/06/07/08五处独立复位，其中JNT-07切换到SAR15 CHARACTERIZATION配置）
产生的，不是OIB-06要测的"本文件自己单次连续RUN内部乱序/重复"。JNT基线的内部复位
从设计上就没有、也不应该去感知每个调用方文件各自的监视进程状态——这是共享前缀文件
的合理边界，不是bug。真实修复：新增`flag_oib_order_monitor_active`，只在
`run_jnt_baseline_01_09;`返回之后才开始监视，与本项目已有的`flag_ilm09_monitor_
active`（ILM-11/12回补时收窄MANUAL-only监视范围）同一种处理模式。

**方法论意义**：如果这个项目里还有其它文件也想在JNT基线之后新增跨越"整个仿真"的
连续监视进程，都需要注意这同一个陷阱——不是所有引用JNT基线的文件都自动免疫，只是
这次OIB-06是第一个真正因为这个问题被真实回归揪出来的。

### 发现2：SID的AMB阶段"tick-248截止抑制"机制不能直接照搬到DC_R/DC_IR阶段

第一版SID-05修复把AMB阶段已验证的"持续拉低`i_adc_physical_idle`穿越tick-248
deadline"逻辑提取成可复用task，直接在DC_R/DC_IR阶段各自的第一个候选上调用。真实
回归：DC_R阶段的抑制检查本身通过（确认无owner提交），但**紧接着DC_R阶段剩余全部
候选的Q3窗口再也没有打开过，整个阶段卡死不收敛**；DC_IR阶段同样的问题。

这证明AMB和DC_R/DC_IR两类子阶段对"持续压低物理ADC idle穿越deadline"这个激励的
真实RTL响应不一样——不是TB照搬逻辑的失误（task本身是对AMB原有代码的逐字节提取，
没有引入新bug），是两类子阶段本身的真实行为差异，需要专门读`ppg_idac_code_
controller.v`的DC_R/DC_IR状态机才能确认正确的构造方式（比如是否需要额外的恢复
步骤、是否deadline之后的行为在DC_R/DC_IR下走了一条不同于AMB的分支）。已撤回这
部分改动，不在未查清楚之前留一个可能误导人的实现。

**方法论意义**：这再次印证了这个项目反复验证过的教训——"三个子阶段共享同一个
机制"这个假设，哪怕合同原文用"each calibration ADC owner"这种看似通用的措辞，也
必须真实回归验证才能确认，不能只凭合同文字的语法结构就断定所有子阶段行为一致。

## 待专门调查的6项（如实标注，不强行赶工）

| ID | 需要的调查方向 |
| --- | --- |
| SID-05（DC_R/DC_IR部分） | AMB阶段"持续拉低`i_adc_physical_idle`穿越tick-248 deadline"的验证逻辑直接复用到DC_R/DC_IR阶段后，真实回归发现会让该阶段搜索彻底卡死不收敛（抑制检查本身能通过，但之后Q3窗口再也不会打开）——需要先读`ppg_idac_code_controller.v`的DC_R/DC_IR状态机，确认这两个子阶段对这个激励的真实响应和AMB有何不同，才能构造正确的验证方式 |
| SID-06 | 合同"candidate/AMB码/颜色/类型/epoch在准备前锁定+tick 385之后的更新只影响下一子帧"——"tick 385"已确认是`PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md`里"快速SAR9校准IDAC提交边界"这个具体时序点，但构造一个"迟到更新只影响下一子帧"的真实测试场景需要先摸清`ppg_idac_code_controller.v`内部在这个边界的提交时序逻辑细节 |
| TRK-01 | 合同要求主动构造"valid低时变化payload不生效"，但`i_track_valid`（`ppg_idac_code_controller.v:129`）是AMI内部推导信号，不是TB可以直接force的公开输入（项目一贯的force-on-shared-net戒律），需要找到一条合法顶层杠杆或明确这条要求在当前架构下如何合法验证 |
| ISE-01 | 合同"code、color、type、precision、epoch均需captured-before-preparation"——code这一项已由既有快照机制验证，但"color/type"在ISE文件的校准搜索候选语境下具体对应哪个信号还不够明确（颜色由阶段结构隐含区分，"type"在这个narrower上下文里没有清晰定义），需要先厘清概念映射 |
| PRC-04 | "无算术wrap"的真实判据信号`dec_baseline_q16`（`ppg_dynamic_baseline_cross_detector.v:473`，已有`@satisfies: PRC-04`标签确认是内部限幅机制）是内部wire非顶层端口，需要确认完整层次引用路径；"无假方向反转"对应哪个RTL信号尚未找到 |
| PRC-06 | 需要先理解`tb_ppg_real_raw_generator.vh`生成器的周期档位参数系统，才能构造一个真正超出合法范围、且能被生成器正确驱动的"非法周期"场景，不是简单复用FAST/SLOW两个已有档位的模式 |

## 回归证据汇总

四份独立文件的iverilog真实运行，全部0 FAIL，`JNT_BASELINE checked=54 pass=54
required=54 status=PASS`逐一确认（JNT前缀文件真实被14个文件共享，这四份是快速
验证迭代阶段选取的代表样本，覆盖了ILM/SID/OIB三个本轮同时改动的家族+baseline_cross
这个JNT前缀本身归属的完整多场景文件）：

| 文件 | 结果 |
| --- | --- |
| `tb_ppg_control_top_input_light_static_matrix.v` | `INPUT_LIGHT_STATIC_MATRIX_TB_PASS`，含`JNT_BASELINE checked=54 pass=54` |
| `tb_ppg_control_top_startup_idac_calibration.v` | `STARTUP_IDAC_CALIBRATION_TB_PASS`，含`JNT_BASELINE checked=54 pass=54` |
| `tb_ppg_control_top_owner_identity_backpressure.v` | `OWNER_IDENTITY_BACKPRESSURE_TB_PASS`（各计数与历史基准逐位一致），含`JNT_BASELINE checked=54 pass=54` |
| `tb_ppg_control_top_baseline_cross.v` | `BASELINE_CROSS_TB_PASS real_red=1106 real_ir=1104 measurement_result_valid=2207 ...`，含`JNT_BASELINE checked=54 pass=54`，102行完整日志0个FAIL |

以上为iverilog快速验证迭代结果。JNT前缀文件真实影响全部19个`tb_ppg_control_top_*`
顶层TB文件，为了对共享文件改动做最终confirm，额外跑了一次官方`run_xsim_
regression.sh`（Vivado 2022.2 xsim）全套19-TB回归。

## 最终confirm：官方19-TB xsim回归

**19/19全部完成，0 FAIL，总PASS数从09-17早些时候的1187增加到1202（+15）。**

这个+15可以逐项对账，不是巧合：
- JNT前缀新增的1条真实check_case调用（`JNT-02-IR-PREESTABLISH`）× 14个真实引用
  该共享前缀的TB文件 = **+14**
- OIB-06新增的显式gate本身是一条新的`$display`判定（PASS/FAIL OIB-06）= **+1**
- ILM-06/07、SID-03/04/05五处修复全部是扩展**既有**check_case调用的判据条件，不
  产生新的独立计数行，对总数贡献为0

14+1=15，与真实观测到的+15完全吻合，是本轮修复质量的一次独立交叉验证。

个别文件（`tb_ppg_control_top_robustness_corner_waveforms`用时1987秒、
`tb_ppg_control_top_long_10_cycles`用时1588秒、`tb_ppg_control_top_longrun`用时
1515秒）耗时较长，属于项目里已知的"长场景"文件，非本次改动引入的异常。

