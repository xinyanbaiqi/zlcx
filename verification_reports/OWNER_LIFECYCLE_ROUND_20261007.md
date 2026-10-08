# owner生命周期轮报告（OWNER_LIFECYCLE_ROUND_20261007）

> 范围：F-020、S1、L-1、L-2（方案甲：T-lost作废 + T-dead按槽位k升级）、L-3、L-4、L-5。
> 基线：main `0ffb439`（RTL与`05a31cf`相同）。分支`wip/owner-lifecycle`：`bddf70e`（第二步RTL）、`b31b413`（设计与交接）、`7c2b089`（第三步验证）、报告与记录提交见合并记录（第三步验证）。
> 设计文档：`verification_reports/OWNER_LIFECYCLE_DESIGN_20261007.md`（第10、11节为用户裁定，优先于第0~9节）。第二步交接：`verification_reports/OWNER_LIFECYCLE_STEP2_HANDOFF.md`。
> 第三步原计划在云端做，用户2026-10-08撤销云端交接，第三、四步都在本机完成（Vivado 2022.2 xsim）。

## 1. 最终设计与用户裁定

### 1.1 owner释放规则
owner只有三种释放，调度器`B_INFLIGHT`、SSW`adc_owner_inflight_o`、AMI`flag_adc_transaction_inflight`在同一事件上释放：
- R1 真实完成（success=1）；
- R2 受控失败（success=0，abort/STOP标丢弃后的真实DONE）；
- R3 超时作废（新）：由AMI发起，是唯一裁决点。判定条件在同一拍原子成立：
  - `flag_owner_lost_fire = flag_adc_transaction_inflight && cnt_owner_age >= C_ADC_COMPLETION_LOST_CYCLES && i_adc_idle && !flag_capture_valid && !flag_adc_completion_pending && !flag_measurement_result_discard_fire && !i_start_ack_event`；
  - 作废拍输出`o_adc_transaction_lost_event`，同拍在`o_adc_complete_sample_index`给出owner序号；
  - 调度器、SSW按序号和代际匹配后释放；
  - AMI发measurement discard，原因`2'b11`；
  - 不产生RAW、结果或success。

### 1.2 用户裁定（两轮AskUserQuestion，2026-10-07；第三步补充裁定2026-10-08）

**参数与按槽位升级**
| 项 | 裁定 |
|---|---|
| T-lost | 4500拍（owner自start fire起的年龄）。须大于实测最晚合法迟到4355拍（LATE6SF），小于NORMAL下一帧同色接管4717拍 |
| k | 2，按RED/IR/CAL槽位分别计连续作废；只有同槽位与owner匹配的真实完成（R1/R2）清零该槽位；截止撤销不计数 |
| 已知限制 | 同槽位间歇丢失、从不连续丢两次时不升级（交B写入合同） |

**编码**
| 项 | 裁定 |
|---|---|
| discard原因 | `2'b11` COMPLETION_LOST。这是2位字段的最后一个空位 |
| cause 8'h06 | 同槽位连续k次作废。source 4'h1，summary bit 9（`16'h0200`） |
| cause 8'h07 | owner在途年龄达到2×T=9000拍时ADC仍不回空闲。source 4'h1，summary bit 10（`16'h0400`）；不释放owner。排空中由看门狗0x31兜底 |

**诊断sticky与L-5**
| 项 | 裁定 |
|---|---|
| lost sticky位置 | 放在AMI：`o_owner_lost_sticky` → control_top `o_ami_owner_lost_sticky` → SPI 0x0108 bit6 |
| lost sticky清除规则 | 同N-1：复位清；诊断清除在"lane 06未保持，或RUN已由STOP结束且AMI排空"时可清；START不清；同拍新作废优先 |
| L-5 | 本轮修复。lane 01/02/03/06/07在`flag_run_context_ended && o_datapath_empty`时清零；同拍新故障置位优先 |

**实现边界**
| 项 | 裁定 |
|---|---|
| 捕获模块 | 不改`ppg_adc_async_stage_capture`。作废条件在AMI内同拍原子判断；同步链约2拍的窗口写成合同前提 |
| 系统TB校准场景（2026-10-08） | 设计§10.7"校准丢失后下一宏帧为NORMAL"按原设想不可达（§4.3）。改为两项：<br>- TB本地检查SYS-CAL-LOST-RETRY：作废后下一帧是校准重试；<br>- 可达变体SYS-CAL-BUSY-NORMAL：校准owner丢DONE且ADC忙，越过帧尾 |

### 1.3 订正设计文档中的表述
- **§3.2"单次丢失不升级"**：须加例外F-1（统筹预审，用户定为已知例外，本轮不改RTL，见§7.2）。双光模式下，IR约在mt309提交、丢失后约在mt4810作废，晚于`MACRO_SAFE_TICK`=4760。
  - 4760那一拍`i_precision_takeover_safe`=0，切换无法提交。
  - 若这一帧正好有精度切换挂起，`switch_hold_new_transaction_o`会挡住NORMAL起帧，此后不再出现宏帧安全边界。
  - 10000拍后切换超时：报cause 04，abort+STOP；`switch_timeout_sticky`须诊断清除后才能START。
  - 也就是说，单次IR丢失在这种情况下会升级为系统故障。RED丢失约在mt4502作废，不受影响。
- **§10.2(a)与§10.7"校准owner在途时下一宏帧是NORMAL"**：在"每个重检阶段只需一个样本"的配置下不可达，结构原因见§4.3。§3.1"sf0提交的owner在sf7作废并在本宏帧内重试"的表述本来就是对的。
- **§11.4三窗口**：窗口内完成被拒后升级为故障，可经STOP→诊断清除→START恢复。补充统筹F-3（§7.2）：窗口落在下一笔start之后时，错绑结果会以success=1正式输出。

## 2. RTL改动（10个文件）

### 2.1 第二步实现（`bddf70e`，9个文件）
| 文件 | 版本 | 改动 |
|---|---|---|
| AMI `ppg_adc_measurement_idac_integration.v` | V1.16→V1.17 | 作废判定、owner年龄、按槽位k、lane 06/07、discard 11、lost sticky、撤销合并（F-020）、L-5 |
| 调度器 `ppg_400hz_frame_calibration_scheduler.v` | V1.10→V1.11 | 作废匹配释放、L-4过期候选、L-1不重挂、L-3空闲IDAC边界 |
| SSW `ppg_sar9_sar15_safe_selection_wrapper.v` | V1.6→V1.7 | 作废释放；owner与帧/子帧绑定；S1 |
| PWI `ppg_precision_window_integration.v` | V1.4→V1.5 | 撤销事件透传 |
| 重检调度器 `ppg_amb_recheck_scheduler.v` | V1.1→V1.2 | 撤销清`flag_sample_inflight` |
| supervisor | V1.0→V1.1 | summary 06→bit9、07→bit10 |
| control_top | V1.6→V1.7 | 连线，新输出`o_ami_owner_lost_sticky` |
| 芯片顶层 | V1.2→V1.3 | 连线 |
| SPI寄存器文件 | V1.4→V1.5 | 0x0108 bit6 |

### 2.2 第三步验证中发现并修复的RTL缺陷（单列）：冗余校正器

**缺陷与修复**
| 项 | 内容 |
|---|---|
| 文件 | `ppg_adc_s1_redundancy_corrector.v` V1.0→V1.1，本轮第10个RTL文件。AMI随之V1.17→V1.18，只改连线 |
| 现象 | AMI单元检查发现：一次超时作废之后`flag_s1_transaction_ready`一直为0，下一笔事务无法启动（死锁）。TB的start超时后，迟到的DONE按无owner捕获报cause 02 |
| 根因 | 冗余校正器的待配对上下文`flag_context_valid`只能由真实RAW捕获释放；作废没有RAW，上下文永远不释放 |

**修复内容**
- 新端口`i_transaction_abandon`，AMI接`flag_owner_lost_fire`。作废拍撤销`flag_context_valid`，并置位新寄存器`flag_capture_drop_armed`。
- 布防期间且没有上下文时，到达的迟到RAW被接收并丢弃（新组合信号`flag_capture_drop`），`o_capture_ready`据此放行，所以捕获缓存不会滞留。迟到RAW绝不与后续上下文配对。
- 下一次上下文接管（start），或吞掉一笔RAW之后，撤防。
- AMI侧照旧：迟到旧DONE走既有`flag_adc_capture_without_owner`，即拒绝、记lane 02并升级。

**单元检查与时序情况**
- 新单元检查S1-ABANDON。负对照两种：去掉上下文释放、去掉丢弃，都FAIL。
- 三种时序情况（统筹要求），实测结果如下：

| 迟到RAW到达时刻（相对下一笔start） | 实际行为 | 证据 |
|---|---|---|
| A 在start之前 | 被吞掉，不产生输出，捕获缓存不滞留，下一笔事务绑定自己的RAW | S1-ABANDON PASS |
| B 与start同一拍 | 绑定到下一笔上下文（out_frame=9d9d，raw=2aa） | INFO S1-ABANDON-TIMING case=B |
| C start之后约2拍 | 绑定到下一笔上下文（同上） | INFO S1-ABANDON-TIMING case=C |

- B、C两种情况是物理上不可区分的窗口：start沿清零捕获同步链之后，旧DONE电平与新转换的DONE无法区分。
- 这属于合同前提，交B（§8.4）。
- 统筹F-3补充：此时错绑结果会以success=1正式输出。
- 系统TB⑤（SYS-LATE-DRAIN/IDLE/NEXTRUN）证明窗口A的旧DONE被拒绝、不错绑、升级为故障，并且可以不复位重启。

### 2.3 仅注释的修改（第三步，未改逻辑）
- 统筹预审F-5：AMI七路分发器、discard四类原因，以及supervisor输入相关的过时注释已改正。
- 统筹预审F-6：AMI参数注释写明合法范围：
  - `C_ADC_COMPLETION_LOST_LIMIT`取1~15，因为`cnt_lost_*`只有4位；
  - `C_ADC_COMPLETION_LOST_CYCLES`须小于32768，否则2×T超出16位`cnt_owner_age`。
- 统筹预审F-7：调度器作废分支注释改为"置失败的是当前宏帧"。
- `@satisfies`标签清理：凡合同条目原文会被方案甲改写的，先移除合同号，由B改写合同后再补（§8.3）。
- 判定方法：gate问题集与改前逐项相同；`-Wall`不变。

## 3. 单元检查与负对照

所有新增检查都用TB本地名，注明服务的F/L号；没有在TB最后一个编号上加1。每个负对照都是逐项去掉对应修复（在副本里改RTL），然后只看目标检查是否FAIL。

**调度器、SSW、AMI**
| TB | 判据 | 新增检查 | 负对照（去掉修复项 → FAIL的检查） |
|---|---|---|---|
| 调度器 V1.9 | 64→71 | LOST-REL、LOST-MISM、L1-NOREPEND、L4-EXPIRE、L4-ONTIME、L3-IDLEBND、L3-NOEXTRA | 去作废匹配→LOST-REL；作废不计错配→LOST-MISM；恢复B_INFLIGHT重挂→L1-NOREPEND；去过期屏蔽→L4-EXPIRE；去空闲边界→L3-IDLEBND；去资格门控→L3-NOEXTRA |
| SSW V1.7 | 53→58 | LOST-RLS、LOST-MSM、BIND-Q3、S1-LATE、S1-ONTM | 作废不释放→LOST-RLS；不计错配→LOST-MSM；去帧号绑定→BIND-Q3；恢复旧S1条件→S1-LATE；去S1 owner项→S1-ONTM |
| AMI V1.14 | 58→78 | LOST-FIRE、LOST-RECOV、LSTK-START、LOST-IDLE、WIN-BEFORE、WIN-IN、WIN-RECOV、WIN-AFTER、K-RED2、LSTK-BLOCK、K-ABORT、LSTK-CLR、K-CLEAR、K-SLOT、LSTK-PRIO、K-IR2、BUSY-07、BUSY-VOID、WDRAW-LOST、LOST-EXCL；HIST-RERUN按L-5改写 | 关闭作废→16项；去idle→LOST-IDLE/BUSY-07/BUSY-VOID；去流水静默→WIN-BEFORE；S1去丢弃→WIN-IN/WIN-AFTER；去k→K-RED2/LSTK-BLOCK/K-IR2；真实完成不清计数→LOST-RECOV/WIN-BEFORE/K-CLEAR；槽位合并→K-SLOT；去长期忙→BUSY-07/BUSY-VOID；撤销不含作废→WDRAW-LOST；lane 02去RUN结束清零→HIST-RERUN；START清sticky→LSTK-START；诊断清除无门控→LSTK-BLOCK；abort不清lane 06→K-ABORT/LSTK-CLR |

**其余单元TB**
| TB | 判据 | 新增检查 | 负对照（去掉修复项 → FAIL的检查） |
|---|---|---|---|
| 重检调度器 V1.2 | +2 | F020-WDRAW×2 | 去撤销分支→两项 |
| supervisor V1.4 | 16→18 | SUM-06、SUM-07 | 去映射→两项 |
| 冗余校正器 V1.1 | +1 | S1-ABANDON（另有信息行S1-ABANDON-TIMING B/C） | 去上下文释放、去丢弃→均FAIL |
| PWI | — | 只接地新输入（第二步） | — |

**补充说明**
- AMI的WIN三窗口检查：
  - WIN-BEFORE：完成在年龄4497到达，即窗口前，完成胜出；
  - WIN-IN：完成在年龄4499到达，即窗口内，作废先发生，迟到完成被拒并升级；
  - WIN-RECOV：窗口内情况之后可以恢复；
  - WIN-AFTER：窗口后，完成按无owner拒绝。
- AMI的LOST-EXCL是逐拍断言：作废与完成永不同拍。
- 证据目录：`phase2/olr/evidence.md`，单元运行目录在`phase2/probes/mut/olr_*`。

## 4. 新永久系统TB `rtl/ppg_control_top/tb_ppg_control_top_adc_anomaly.v`

### 4.1 结构
- 由`phase2/olr/make_adc_anomaly_tb.py`生成。DUT与激励前缀沿用`tb_ppg_control_top_periodic_recheck_recovery.v`，即control_top，含supervisor；filelist为`xsim_adc_anomaly_filelist.f`。已登记为`run_xsim_regression.sh`第20个TB，判定行`ADC_ANOMALY_TB_PASS checks=37`。
- 后台ADC响应进程：只在真实Q3释放后应答，可按槽位丢弃、推迟、持续失联，或保持ADC忙。NORMAL事务可以改用真实生理生成器取值。
- 全程监视器：
  - BIND：每个Q3必须属于同帧owner，校准还要求同子帧；
  - EXCL：作废与完成不同拍；
  - LIVENESS：RUN或STOPPING中连续15000拍（3帧），既无完成、作废、正式结果、IDAC码提交、生命周期变化，也无故障记录，判FAIL；
  - 故障episode锁存：abort清lane后episode很快关闭，所以必须锁存。

### 4.2 场景与结果（olr_anom4，见§6.3）
所有检查都在提交`7c2b089`的全套回归中通过：37/37，`ADC_ANOMALY_TB_PASS checks=37`，`$finish` 1678493250 ns。

**NORMAL路径（21项）**
| 检查 | 内容（实测要点） |
|---|---|
| SYS-N-BASELINE | 无异常基线 |
| SYS-LOST-RED / SYS-LOST-IR | RED、IR各丢一次。RED提交后年龄4502作废（mtick 4503，早于下一帧RED接管）；IR在mtick 4811作废。下一帧RED/IR照常出结果，lost sticky置位 |
| SYS-K-CLEAR | RED丢一次、下一次RED正常完成，RED计数清零；之后再丢一次也不报故障 |
| SYS-LATE-RED | 合法迟到不作废 |
| SYS-K-RED2 / SYS-K-STOP / SYS-RESTART-K | 只有RED一路持续丢失：第2次RED作废报cause 06（color 0、NORMAL、summary bit9）。IR计数为0，按槽位计数。之后STOP→诊断清除→START，不复位恢复出结果 |
| SYS-DRAIN-LOST / SYS-RESTART-DRAIN | STOP排空中丢失：作废后排空结束，不卡死，可重启 |
| SYS-LATE-DRAIN / SYS-L5-RESTART | 迟到旧DONE情况①（排空期间）：被拒，记cause 02，无完成事件；诊断清除后START被接受 |
| SYS-LATE-IDLE / SYS-RESTART-IDLE | 迟到旧DONE情况②（排空后空闲期） |
| SYS-LATE-NEXTRUN / SYS-RESTART-NEXTRUN | 迟到旧DONE情况③（下一RUN第一笔start之前） |
| SYS-WIN-BEFORE / SYS-WIN-IN / SYS-RESTART-WIN / SYS-WIN-AFTER / SYS-RESTART-WIN2 | 三窗口：窗口前完成胜出；窗口内作废先发生，迟到完成被拒并升级（cause 02）；窗口后被拒。每种之后都能不复位重启 |

**ADC忙路径（5项）**
| 检查 | 内容（实测要点） |
|---|---|
| SYS-BUSY-Q3 | RED owner卡忙，年龄超过4717：下一帧RED的Q3被压掉，零错绑 |
| SYS-BUSY-07 / SYS-BUSY-WDOG / SYS-BUSY-RECOVER / SYS-RESTART-BUSY | 年龄9000报cause 07 → abort+STOP → 排空中看门狗0x31 → ADC回空闲后作废 → 排空结束 → 诊断清除 → START |

**校准路径（5项）**
| 检查 | 内容（实测要点） |
|---|---|
| SYS-CAL-LATE385 | S1：本子帧owner在tick 385仍在途，置迟到sticky，不作废 |
| SYS-CAL-LATE6SF | L-3：最晚合法迟到（年龄4355）不作废，启动搜索完成 |
| SYS-CAL-LOST | 启动搜索中校准丢失：sf1起动的owner在下一帧mtick 0作废（年龄4502），重试后完成 |
| SYS-CAL-K2 / SYS-RESTART-CAL | 校准槽位连续2次作废报cause 06，不复位重启 |

**周期重检R阶段（2项，真实生成器约620帧）**
| 检查 | 内容（实测要点） |
|---|---|
| SYS-CAL-LOST-RETRY | 帧617第1笔重检校准（AMB，sf0）不应答，在sf7 lt128作废（年龄4502）。下一帧618是校准重试，重检在帧621完成，帧622的RED/IR有正式结果，零错绑 |
| SYS-CAL-BUSY-NORMAL | 第3笔重检校准不应答且ADC保持忙。实测它是帧618 sf1起动的owner（F-9路径，见§4.3）。帧尾不重挂；帧619按NORMAL起帧，`sched_inflight=1`；帧619内无owner提交，无RED结果。回空闲（tick 2000）后在mt2001作废，年龄6376<9000，无cause 07。RED/IR截止事件在mt2002才出现：调度器截止判定要求`!B_INFLIGHT`，作废前被屏蔽；L-4的过期屏蔽保证其间不会补提交。F-020重挂（mt2002）后，帧620为校准重试，重检在帧621完成，零错绑，活性监视不报 |

**其余检查（4项）**
| 检查 | 内容（实测要点） |
|---|---|
| SYS-BUSY-FOREVER | ADC永不回空闲：停在STOPPING，已报cause 07和0x31，blocking保持，不静默 |
| SYS-MON-BIND / SYS-MON-EXCL / SYS-MON-LIVE | 全程零错绑、作废与完成永不同拍、无静默停滞 |

**系统级负对照**（`+OLR_SKIP_R`跳过约25分钟的R阶段；正向时35/35）
| 去掉的修复 | 结果 |
|---|---|
| 冗余校正器abandon接0 | 33项FAIL，SYS-LIVENESS多次报"silent stall"：活性监视器能抓住作废后的死锁 |
| SSW帧/子帧绑定 | SYS-BUSY-Q3、SYS-CAL-LOST、SYS-MON-BIND FAIL |
| 作废条件中的`!flag_capture_valid && !flag_adc_completion_pending` | 17项FAIL（cause 11错配） |
| L-5（`flag_run_context_drained`恒0） | **全部PASS，日志与正向逐行相同**，见§7.1(c) |

### 4.3 校准丢失后下一宏帧的结构分析（订正设计§10.2(a)/§10.7）
**实测**
- olr_anom2/olr_anomR5：重检三个阶段（AMB、DC_R、DC_IR）的校准Q3分别在帧617、619、621，都在sf0 lt266。
- 第1笔不应答时，在帧617的sf7 lt128作废（mtick 4503，年龄4502）。随后的帧618是校准重试，重检随后完成，零错绑。

**结构原因（RTL逐路追踪）**
1. **（没有跨帧重试时）每个重检阶段在新的校准宏帧开始**：
   - 重检调度器只在"阶段结果可用 && 阶段帧完成"时换阶段（`flag_enter_ir`、`enc_sequence_done_o`都要求`flag_stage_result_available && flag_stage_frame_available`）。后者要求`i_calibration_frame_complete_event`，即校准宏帧末拍。
   - 下一阶段的请求因此只能在本校准帧结束后握手，并进入下一校准帧。
   - 调度器在新帧开头把`B_CAL_REQ_PENDING`转成`B_CAL_REQ_ACTIVE`，由`flag_cal_context_due`的sf0分支在local tick 0接管。
2. **同一校准帧内要在sf≥1接管，必须先在帧内重新握手**：
   - `flag_cal_context_due`在sf≠0时要求`B_CAL_REQ_PENDING`；
   - `calibration_sample_ready_o`在活动校准帧内要求`!B_CAL_WAVE_PENDING && !B_INFLIGHT`；
   - AMI的`calibration_sample_valid_o`要求`!flag_calibration_request_inflight`，该标志只在IDAC实际消费结果（`flag_amb/dcs_sample_accepted`）、截止或作废撤销、STOP/abort/阻断时清零；
   - 重检调度器的`o_calibration_sample_valid`还要求`flag_sample_inflight==0`，并且IDAC重新拉高`i_amb_sample_request`/`i_dcs_sample_request`。
   - 所以只有IDAC在同一阶段内需要再取样本时，例如AMB越窗后的确认或重搜，才会出现sf≥1的校准owner。
3. **校准owner最晚在local tick 248提交**：`flag_candidate_expired`（L-4，`calibration_local_tick_o > C_CAL_OWNER_DEADLINE`）与`flag_cal_owner_deadline`共同保证。
4. **结论**：每阶段只取一个样本且没有跨帧重试时，校准owner在sf0、tick≤248起动；作废年龄4500使作废落在mtick≤4748，早于5000拍校准宏帧结束。
   - 随后F-020撤销（`flag_calibration_request_withdraw`）在帧尾之前重新挂上请求，下一帧是校准重试，不是NORMAL帧。
   - 所以"校准owner在途时下一宏帧是NORMAL"在该配置下不可达。
5. **结论只覆盖各阶段的第一次取样，以下两种情况会出现sf≥1起动的校准owner**：
   - **(a) 跨帧重试之后（实测，olr_anom4/7c2b089）**：
     - 帧617的AMB owner作废，帧618重试，sf0 lt274被IDAC接收；lt278随即又握手了一次，下一阶段在帧618的sf1接管。
     - 原因是统筹F-9：重检调度器的`flag_stage_frame_complete`沿用帧617的帧完成锁存，重试样本一到，"阶段结果可用 && 阶段帧完成"同时成立，阶段在重试帧内推进。
     - 帧620（DC重试）里同样出现sf0、sf1两次DCS接收。
     - 后果：重试帧内sf1起动的owner如果丢DONE，作废会落在mtick≥625+4500>5000，即下一宏帧内。L-1之后帧尾不重挂，下一帧可按NORMAL起帧。这就是§10.7原本设想的情形，可经F-9路径到达。
     - SYS-CAL-BUSY-NORMAL的忙owner正好是这个sf1 owner。
   - **(b) 同一阶段需要多个样本时**（如AMB越窗后的确认或重搜，读码推断，本轮未实测）：IDAC在阶段内再请求样本，sf≥1接管。
   - 两种情况下，"校准owner在途跨入NORMAL帧"都可达。现有系统TB以SYS-CAL-BUSY-NORMAL覆盖其中带ADC忙的一种。不带ADC忙的纯丢DONE版本（作废发生在下一帧tick约125~373，早于或晚于RED截止283）是否补入，由用户决定（§7.1）。
6. **用户裁定的可达变体SYS-CAL-BUSY-NORMAL**：DONE丢失且ADC保持忙，越过帧尾，在下一帧tick 2000回空闲，没有DONE。按RTL预期：
   - 帧尾因L-1不重挂；
   - 下一帧按NORMAL起帧，该帧RED/IR拿不到ADC，截止失败；
   - 回空闲后作废，年龄<9000，无cause 07；
   - F-020撤销后重新请求，之后是校准重试帧，重检完成；
   - 全程零错绑，活性监视不报。
   - 实测见§4.2。

## 5. 芯片TB（`tb_ppg_chip_digital_top.v` V1.4）
- DIAG-MAP38的期望按0x0108 = {1'b0, `top_ami_owner_lost_sticky_o`, …}组装，bit7仍为保留0。
- 新芯片级场景：IR单光NORMAL，ADC一律不应答，全部检查经SPI读回。

| 检查 | 读回 |
|---|---|
| LOST-SPI-VOID | 第1次作废：0x0108=0x42（bit6=1）；0x0114从0x00变为0xaf（原因2'b11、identity_valid=1、IR、NORMAL、翻转位变化）；不阻断 |
| LOST-SPI-K2 | 第2次连续作废，STOP后读：cause(0x010B)=0x06，source(0x010C)=0x01，0x010A=0xae（cause_valid=1），summary 0x0113:0x0112=0x0200 |
| DIAG-MAP38 after-owner-lost | 38字节全部与模型一致 |
| LOST-SPI-CLR | DIAG_CLEAR后0x0108 bit6=0，summary=0，cause_valid=0 |
| LOST-SPI-RESTART | STOP→DIAG_CLEAR→COMMIT→START，不复位进入RUN。STOP后生命周期回到CONFIG，所以需要COMMIT；系统TB的`sys_restart`序列相同 |
| LOST-SPI-STKSTART | 单次作废→STOP→COMMIT→START之后，0x0108 bit6仍为1（START不清） |
| DIAG-MAP38 after-lost-clear | 一致 |

- 负对照：
  - SPI `byte_0108` bit6接0：LOST-SPI-VOID、LOST-SPI-K2、DIAG-MAP38 after-owner-lost、LOST-SPI-STKSTART共4项FAIL；
  - TB期望退回`{2'b00,…}`：只有DIAG-MAP38 after-owner-lost FAIL。
- 未覆盖：cause 07及summary bit10没有在芯片层实测。
  - 芯片顶层的物理idle由空闲合成器取自`CLK_STAGE_DOUT_LOW`电平，"ADC忙而无DONE"无法从芯片引脚构造。
  - 07的产生在control_top层验证（SYS-BUSY-07/WDOG/FOREVER），映射在supervisor单元验证（SUM-07）。
  - 0x0113是summary[15:8]的整字节直通，由DIAG-MAP38做结构比对。

## 6. 门禁、-Wall与全套回归

### 6.1 gate（Erie deliverable gate，0ffb439与当前比较，问题集去行号逐项比对）
- 18个改动文件（10个RTL、8个TB）逐文件SAME。脚本`olr/gate3.sh`、`olr/gate3_cmp.py`。
- 各RTL文件的问题数（均为既有项）：
  - 调度器、校正器、重检、SPI、supervisor：0/0；
  - AMI：错误2、strict 1；
  - PWI：strict 1；
  - SSW：错误10；
  - control_top：错误1；
  - 芯片：VG010×46。
- TB只有TB通用的file.discovery一项，新系统TB相同。

### 6.2 iverilog -Wall（`olr/wall3.sh`）
- 7个改动的单元TB按`run_unit_tb_regression.sh`的编译闭包编译，含冗余校正器单元TB；芯片TB用全层次filelist。old与new逐行相同：SSW TB两条既有悬空告警，其余为0。
- 新系统TB有3条悬空输入告警，与其前缀来源periodic TB完全相同。

### 6.3 全套回归
- **运行**：提交`7c2b089`，用`git -c core.autocrlf=false archive`导出到`D:/PPG/verilog/ppg_regression_runs/7c2b089_20261008/`，共五份互相独立的导出副本：
  - g1~g4：20个control_top TB分4组并行。每组用同一个`run_xsim_regression.sh`，只把ORDER改成本组子集；脚本先断言四组恰好覆盖登记的20个TB。
  - chip：芯片TB，之后跑模块级（输出`7c2b089_20261008_unit`）。
  - 驱动脚本`phase2/olr/run_full_regression.sh`。开始15:29，最后一组结束16:30。
- **比对方法**：与`05a31cf_20261006`（19-TB、芯片）和`05a31cf_20261006_unit`逐TB比较，看排序后的PASS行与`$finish`时刻，不用summary.tsv（`compare_runs.py`）。
- **结果**：

| 组 | TB | PASS/FAIL | 与05a31cf比较 |
|---|---|---|---|
| g1 | robustness_corner_waveforms | 67/0 | PASS行、$finish相同 |
| g2 | **adc_anomaly（新）** | 37/0 | 新增 |
| g2 | idac_bus_isolation、owner_identity_backpressure、lifecycle_fault_adc_anomaly、input_light_static_matrix、smoke、adc_numeric_scoreboard、startup_idac_calibration、injection、raw_generator_selfcheck | 70、68、80、73、73、69、83、15、40 /0 | 9个均相同 |
| g3 | long_10_cycles、periodic_recheck_recovery、peak_valley_return、fir_tail_isolation | 129、70、75、80 /0 | 均相同 |
| g4 | longrun、diag_algo_probe、baseline_cross、no_recheck_control | 5、5、75、61 /0 | 均相同 |
| g4 | **normal_slow_tracking** | 72/0 | PASS行相同。结束行`result_captures` 1406→1389（owner_commit_total同为1477），$finish 1828110500 ns→1785602 µs。解释见下 |
| chip | tb_ppg_chip_digital_top | 20/0 | 原13行相同，新增7行。到after-conflict为止的日志前缀逐行相同（含TC7 valid_cycles=5）。$finish 3425250→11363250 ns，因为新场景追加在末尾 |
| unit | 28个模块级TB | 28/28 | 22个PASS行、$finish相同。6个改动的TB只增不减（调度器+7、AMI+20、冗余校正器+1、重检+2、SSW+5、supervisor+2）；新增检查追加在末尾，$finish后移。全日志中被删改的行只有计数行，以及AMI `HIST_STOP_ONLY ... ami_fault_active=1→0`（L-5有意改变） |

- **合计**：control_top 20/20（1247 PASS行 = 05a31cf的1210行原样保留 + 新TB 37行，0 FAIL）；芯片20/0；模块级28/28。
- **normal_slow_tracking变化的根因**（两侧RTL用同一TB加事件探针实测，`phase2/runs/trk_old`、`trk_new`）：
  - TB在TRK-02~TRK-07之间被动等待（`repeat(200)`，然后轮询安全边界提交），期间不应答Q3，所以帧11的IR owner（序号39）丢了DONE。这是TB自身的应答空档。
  - **0ffb439**：owner 39一直在途，帧12没有任何owner提交。帧12的IR Q3在旧owner名下执行（旧SSW没有帧绑定），TB对它的应答在年龄5160时把owner 39完成。也就是说，帧12的IR转换被当作帧11序号39的结果正式输出。**这正是L-1错绑，它一直静默存在于05a31cf的基线回归中**，因为该TB不在这里核对身份。
  - **新RTL**：owner 39在年龄4502时作废（discard 11），帧12正常提交RED/IR（序号40/41），同一笔TB应答完成序号41。之后序号整体后移2，生成器驱动的轨迹随之不同，末尾"驱动到SAR15→9回落为止"的循环提前结束。
  - 所以这一变化是L-1/L-2修复的预期结果，不是破坏。其余18个既有control_top TB的PASS行与$finish完全不变。

## 7. 新发现与待用户决定

### 7.1 本会话发现
(a) **冗余校正器作废死锁**（RTL缺陷，已修，§2.2）。

(b) **设计§10.7的可达性**（用户已裁定改为SYS-CAL-LOST-RETRY + SYS-CAL-BUSY-NORMAL，§4.3）。
- 订正我之前给用户的说法："校准owner在途跨入NORMAL帧"并非不可达。
  - 它在"首次取样、单样本阶段"下不可达；
  - 在跨帧重试之后（统筹F-9路径，已实测）和阶段内多样本时（读码推断）都可达。
- 不带ADC忙的纯丢DONE版本是否补入系统TB，**请用户决定**。

(c) **L-5在control_top层不可观测**。
- 系统级负对照N3（L-5清零恒0）与正向逐行相同，包括迟到旧DONE确实在STOPPING中到达的SYS-LATE-DRAIN。
- 机理同第一轮§12.3：
  - 每次lane置位都会产生故障记录，supervisor开episode并abort，abort清lane；
  - 若在STOPPING中，episode在manager回到CONFIG后才开（F-2）。
- 因此设计§6"本轮新机制使L-5在生产构建中变得可达"没有得到实测支持。L-5清零目前只在AMI单元级起作用（HIST-RERUN）。
- 是保留为纵深防御，还是另行构造可达场景，**请用户决定**。本轮未改。

(d) **既有行为**：周期重检期间，夹在校准帧之间的NORMAL帧（实测帧616/618/620）会出现RED/IR波形但没有owner，RED/IR owner截止在283/443触发，并置位非阻断的调度器owner截止sticky。
- 0ffb439与新RTL逐事件相同（periodic TB加探针，`phase2/runs/probe_dl`、`probe_dl_old`），与本轮无关。
- 后果：重检期间该sticky不能作为异常指示。交收尾计划。

(e) **cause 07在芯片层不可构造**：芯片顶层的物理idle由DOUT电平合成（§5）。交收尾计划。

(f) **既有TB应答空档**：normal_slow_tracking在TRK-02~07之间不应答Q3。
- 在旧RTL上它触发了静默的L-1错绑，在新RTL上触发作废（§6.3）。
- TB没有改，PASS不受影响。可交TB维护：等待期间改为后台应答。

### 7.2 统筹预审（2026-10-08，独立审查；用户已对F-1裁定）
| 号 | 内容 | 处理 |
|---|---|---|
| F-1 | 见§1.3。双光IR丢失约在mt4810作废，晚于4760宏帧安全边界；若有精度切换挂起，会切换超时报cause 04 | 用户定为已知例外，本轮不改RTL、不加TB。订正§3.2；交B（§8.4）；实测列入流片前验证收尾计划：用真实检测链触发切换，xsim跑 |
| F-2 | 同槽位第k次作废落在主机STOP后的排空末尾时，lane 06只保持1拍（被`flag_run_context_drained`清掉）；cause 06在manager回到CONFIG后才开新episode；supervisor发出的STOP使manager记错误0x0C；须先诊断清除才能START。机制与设计§11.1情况②相同，但那里没写这种情形 | 交B（§8.4） |
| F-3 | 作废后旧DONE恰在下一笔start之后约2拍内到达时，错绑结果会以success=1正式输出；RED错绑只因碰上SSW cause 21被间接发现，IR和CAL完全静默 | 合同前提写明"错绑结果会被正式输出"（§8.4） |
| F-3附 | 既有潜在不一致：调度器在tick≥160、RED已释放后就允许IR提交，而SSW要等RED窗口在283之后关闭才认IR；只有RED在283之前完成时才可达 | 交收尾计划 |
| F-4 | C10 §6.11（约第658行）"diag_clear, STOP, abort, a result discard, enable deassertion and START neither remove a pending fault record nor clear an active lane"与RTL不符：lane 01/02/03/06/07在START或abort时清零，本轮k升级后的恢复正是靠abort清lane 06 | 交B点名这一句（§8.4） |
| F-5 | 过时注释 | 已改（§2.3） |
| F-6 | 两个参数的合法范围 | 已写进注释（§2.3）；交B冻结为固定值（§8.4）。可选的AMI单元参数检查未做 |
| F-7 | 调度器作废匹配处注释写"作废事务所在帧"，实际置失败的是当前帧 | 已改注释；交B（§8.4） |
| F-8 | 冗余校正器`o_capture_ready`组合依赖`i_capture_valid`：无组合环，惯例允许 | 不处理 |
| F-9 | 跨宏帧重试后，重检阶段沿用上一宏帧的"帧完成"锁存，疑似既有问题 | 统筹列入收尾计划 |

审查报告（只读）：统筹会话scratchpad `olr_review/review/REVIEW.md`。

## 8. 交给B的合同/矩阵/别名表交接清单（符号锚点）

### 8.1 本轮改动文件
- RTL 10个：AMI、调度器、SSW、PWI、重检调度器、supervisor、control_top、芯片顶层、SPI、冗余校正器。
- TB 9个：调度器、SSW、AMI、重检调度器、supervisor、冗余校正器、PWI（仅接地）、芯片TB，以及新的`tb_ppg_control_top_adc_anomaly.v`。
- 另有：`xsim_adc_anomaly_filelist.f`、`run_xsim_regression.sh`（第20个TB）。

### 8.2 新增/改名的符号
**新增端口**
- AMI：`o_adc_transaction_lost_event`、`o_owner_lost_sticky`；参数`C_ADC_COMPLETION_LOST_CYCLES`=4500、`C_ADC_COMPLETION_LOST_LIMIT`=2。
- 调度器：`i_adc_transaction_lost_event`、`i_idac_boundary_request`。
- SSW：`i_adc_transaction_lost_event`。
- PWI、重检调度器：`i_calibration_request_withdraw_event`。
- control_top：`o_ami_owner_lost_sticky`。
- SPI：`i_ami_owner_lost_sticky`。
- 冗余校正器：`i_transaction_abandon`。

**端口语义扩展**
- AMI `o_adc_complete_sample_index`在作废拍也有效。全部接收方都以事件限定：调度器`flag_completion_match`/`flag_owner_lost_match`、SSW`flag_owner_release`/`flag_done_mismatch`。

**新增内部信号**
- AMI：
  - 计数：`cnt_owner_age`、`cnt_lost_red/ir/cal`；
  - lane与分发：`flag_owner_lost_fault_hold`(lane 06)、`flag_adc_busy_fault_hold`(lane 07)、`flag_ami_fault_pending_06/07`、`flag_ami_fault_dispatch_06/07`；
  - 作废判定：`flag_owner_lost_fire`、`flag_adc_busy_fault_fire`、`flag_owner_slot_red/ir/cal`、`flag_owner_alive_completion`、`flag_owner_lost_limit_reached`；
  - 撤销与排空：`flag_calibration_request_withdraw`、`flag_recheck_request_withdraw`、`flag_run_context_drained`；
  - localparam：`DISCARD_REASON_COMPLETION_LOST`、`ADC_BUSY_FAULT_CYCLES`。
- 调度器：`flag_owner_lost_match`、`flag_candidate_expired`、`flag_idle_idac_safe_boundary`。
- SSW：`reg_owner_cal_subframe`。
- 冗余校正器：`flag_capture_drop_armed`、`flag_capture_drop`。
- control_top：`flag_idac_boundary_request`、`ami_owner_lost_sticky_o`等连线。

**语义改变的既有信号**
- SSW：`flag_red/ir/cal_has_owner`加入帧/子帧绑定；`calibration_timeout_sticky_o`按S1改写。
- AMI：
  - `o_wrapper_fault_blocking`、`o_ami_fault_active`加入lane 06/07；
  - lane 01/02/03增加"RUN结束且排空"清零；
  - `flag_calibration_request_inflight`的清零源加入撤销合并；
  - `o_measurement_result_discard_reason`加入2'b11。
- 调度器：`transaction_start_valid_o`（L-4）、`idac_code_safe_boundary_o`（L-3）、宏帧末重挂条件（L-1）。
- 冗余校正器：`o_capture_ready`在布防期间可接收并丢弃。

**新增TB本地检查标签**
- 调度器：LOST-REL、LOST-MISM、L1-NOREPEND、L4-EXPIRE、L4-ONTIME、L3-IDLEBND、L3-NOEXTRA。
- SSW：LOST-RLS、LOST-MSM、BIND-Q3、S1-LATE、S1-ONTM。
- AMI：LOST-FIRE、LOST-RECOV、LSTK-START、LOST-IDLE、WIN-BEFORE/IN/RECOV/AFTER、K-RED2、LSTK-BLOCK、K-ABORT、LSTK-CLR、K-CLEAR、K-SLOT、LSTK-PRIO、K-IR2、BUSY-07、BUSY-VOID、WDRAW-LOST、LOST-EXCL；HIST-RERUN改写。
- 重检调度器：F020-WDRAW。
- supervisor：SUM-06、SUM-07。
- 冗余校正器：S1-ABANDON（信息行S1-ABANDON-TIMING）。
- 芯片TB：LOST-SPI-VOID/K2/CLR/RESTART/STKSTART，DIAG-MAP38 after-owner-lost/after-lost-clear。
- 系统TB：SYS-*共37项（§4.2）。

### 8.3 `@satisfies`锚点
**保留**：合同原文与实现完全一致的
- 调度器：L-4 `flag_candidate_expired`→FSC-46/49/50；L-1宏帧末重挂→FSC-17；LFA-01/02门控行仅移动。
- SSW：`flag_red/ir/cal_has_owner`→SSW-38、SSW-34。
- AMI撤销合并`flag_calibration_request_withdraw`→SID-05（截止半句与FSC-50一致）。
- 重检调度器撤销释放→SID-05。
- TB：L1-NOREPEND→FSC-17；L4-EXPIRE/ONTIME→FSC-46/49；L3-NOEXTRA→FSC-38；系统TB L-1两处→SSW-38、FSC-17。

**本轮移除**：合同原文会被方案甲改写的，B改写对应条目后在括号里的符号处补标签
- AMI-40（作废释放`flag_adc_transaction_inflight`、冗余校正器`flag_capture_drop`、AMI TB WIN-IN）；
- AMI-39、LFA-04（`adc_transaction_lost_event_o`、AMI TB LOST-FIRE、系统TB SYS-LOST-RED）；
- AMI-24（`owner_lost_sticky_o`、L-5三个lane清零、AMI TB HIST-RERUN）；
- SUP-08（`flag_owner_lost_fault_hold`、AMI TB K-RED2、系统TB SYS-K-CLEAR）；
- FSC-54（调度器`flag_owner_lost_match`分支、调度器TB LOST-REL、系统TB SYS-LOST-RED）；
- FSC-19（调度器`flag_idle_idac_safe_boundary`、调度器TB L3-IDLEBND、系统TB SYS-CAL-LATE6SF）；
- SSW-42（SSW作废释放/错配）；SSW-18（S1 sticky，原文还要求"终止burst"，实现只置sticky）；
- P09（supervisor summary映射）；
- SID-05（AMI TB WDRAW-LOST、系统TB SYS-CAL-*，它们验证的是作废撤销，不是截止撤销）。

### 8.4 需要的合同改动
1. **C10（AMI）**
   - **R3作废规则**：AMI-39/AMI-40及"只有真实DONE释放owner"的正文，加入超时作废规则。内容包括：
     - 判定条件（§1.1公式），AMI为唯一裁决点；
     - 作废拍的序号语义；
     - 作废后旧DONE按无owner捕获被拒并升级。
   - **端口表**：加`o_adc_transaction_lost_event`、`o_owner_lost_sticky`、两个参数。参数按F-014/F-024先例冻结为固定值4500/2，并写明合法范围（F-6）：
     - `C_ADC_COMPLETION_LOST_LIMIT` 1~15；
     - `C_ADC_COMPLETION_LOST_CYCLES` < 32768。
   - **§6.10 discard原因表**：
     - 加`2'b11` COMPLETION_LOST，注明这是2位字段的最后一个空位，以后新增原因须加宽字段；
     - 作废discard的身份取owner启动快照，`sample_valid=0`，对校准owner也发。
   - **§6.11**：
     - 分发器扩为七路；
     - 改写F-4点名的那一句，与实现一致：lane 01/02/03/06/07在START、abort、"RUN已由STOP结束且AMI排空"时清零，新故障置位优先。
   - **§15.1**：`o_owner_lost_sticky`清除规则（同N-1），START不清。
   - **§15.2与§6（L-5依据）**：
     - 第一轮交接写的当前限制"lane 02/03保持，需主机ABORT"改为已修复：STOP结束且排空后lane落下；
     - `o_wrapper_fault_blocking`随之在排空后为0；历史诊断仍保留，可诊断清除。
     - §15.2（诊断清除条件）与§6（lane生命周期）现在一致：两处都以"RUN已由STOP结束且AMI排空"为界。
   - **捕获窗口前提**：
     - 同步链约2拍窗口内到达的完成会先被作废，之后按无owner捕获被拒并升级，可经STOP→诊断清除→COMMIT→START恢复；
     - 作废后在下一笔start当拍或之后到达的旧DONE，与新事务的DONE物理上不可区分，会绑定到新事务，错绑结果以success=1正式输出（F-3）；
     - 冗余校正器的三种时序见§2.2。
   - **已知限制**：
     - 同槽位间歇丢失、从不连续丢两次时不升级（每次都有discard 11和lost sticky可见）；
     - F-1：双光IR丢失与精度切换挂起叠加时会切换超时，升级cause 04；
     - F-2：k次作废落在STOP排空末尾时lane 06只保持1拍，cause 06在CONFIG后开episode，supervisor发出的STOP使manager记0x0C，须诊断清除后才能START。
2. **C25 LFA-04**：同AMI-39，加超时作废例外。
3. **C24（supervisor）**
   - §3原因表加8'h06、8'h07（source 4'h1，summary bit 9/10）；
   - §5 AMI active fault的下降条件补"abort、START、RUN结束排空"；
   - §6看门狗：补"超时作废不属于伪造"，并写明RUN中/排空中丢失与长期忙的处理及不卡死保证；
   - F-1、F-2写入恢复流程。
4. **C09（SSW）**
   - SSW-18按S1改写：迟到诊断只置sticky，不终止burst；写明"ADC在tick 266已采样、迟到的只是读出"的前提；
   - SSW-16/17/42加作废释放；
   - owner与帧/子帧绑定写入SSW-34/38正文；
   - 端口表加`i_adc_transaction_lost_event`。
5. **C08（调度器）**
   - L-1：宏帧末不重挂在途owner的请求（FSC-17）；
   - L-4：截止当拍可提交，越过截止只收尾（FSC-46/49/50）；
   - L-3：第4种IDAC边界，即启动搜索空闲边界（FSC-19/38相关）；
   - 作废释放（FSC-54）：作废置失败的是当前宏帧（F-7），owner跨帧时与作废事务的起始帧不同；
   - 端口表加两个输入；
   - 写明调度器sticky按§16.2在新START清零，而AMI历史诊断（含lost sticky）在新START不清，两套规则并存。
6. **C18/C16（PWI/重检）**：新输入与F-020撤销规则。另需写明"每个重检阶段在新的校准宏帧sf0开始；只有阶段内需要多个样本时才有sf≥1的owner"（§4.3）。
7. **C01与芯片顶层合同SPI地图**
   - 新输出`o_ami_owner_lost_sticky`；
   - 0x0108 bit6 = AMI owner lost sticky，bit7仍保留；
   - SPI诊断地图逐位写明清除方式：调度器sticky在START清；AMI历史（含0x0108 bit6）只由复位或诊断清除清；supervisor summary/cause只由复位或合法诊断清除清零（cause是首故障快照，新捕获时覆盖），START不清。
8. **冗余校正器合同（C10中S1子模块部分）**：新端口`i_transaction_abandon`、布防丢弃规则、三种时序（§2.2）。
9. **精度窗口控制器合同与软件恢复流程**：F-1。
10. **既有条目订正**：C10 §15.2关于L-5"需主机ABORT"的限制说明改为已修复。

### 8.5 交收尾计划（不改合同）
- F-1实测：用真实检测链触发切换，xsim跑。
- F-3附：调度器与SSW对IR提交时机的潜在不一致。
- F-9：跨宏帧重试后重检沿用上一帧"帧完成"锁存。
- cause 07在芯片层的可观测性（§5）。

## 9. 运行目录与证据索引
`phase2` = `D:/PPG/verilog/ppg_regression_runs/abcd_20261004/phase2`。

| 位置 | 内容 |
|---|---|
| `D:/PPG/verilog/ppg_regression_runs/7c2b089_20261008/g1~g4` | 20个control_top TB（`rtl/ppg_control_top/xsim_regression_20260906/<tb>/xsim.log`），驱动日志`g*_driver.log` |
| `D:/PPG/verilog/ppg_regression_runs/7c2b089_20261008/chip` | 芯片TB（`rtl/ppg_chip_digital_top/xsim_regression_20261008/`） |
| `D:/PPG/verilog/ppg_regression_runs/7c2b089_20261008_unit` | 28个模块级TB与`unit_summary.tsv` |
| `D:/PPG/verilog/ppg_regression_runs/05a31cf_20261006`、`05a31cf_20261006_unit` | 比对基线 |
| `phase2/olr/evidence.md` | 第三步证据记录（单元正向与负对照、芯片、gate/-Wall、系统TB各次运行） |
| `phase2/olr/`下的`make_adc_anomaly_tb.py`、`run_anom.sh`、`run_chip.sh`、`run_full_regression.sh`、`gate3.sh`、`gate3_cmp.py`、`wall3.sh`、`strip_cmp.py`、`untag.py` | 生成与运行脚本 |
| `phase2/runs/olr_anom*`、`neg_sysN1~4`、`pos_skipR` | 系统TB开发运行与系统级负对照 |
| `phase2/runs/olr_chip3`、`neg_chipA`、`neg_chipB` | 芯片TB正向与负对照 |
| `phase2/runs/trk_old`、`trk_new` | normal_slow_tracking差异根因探针 |
| `phase2/runs/probe_dl`、`probe_dl_old` | 重检期间owner截止sticky探针 |
| `phase2/probes/mut/olr_*` | 单元级正向与负对照运行 |
| `phase2/mut/` | 负对照变异副本 |

**RTL注释修改的无回归证明**：10个RTL文件去掉注释后，与第一次系统TB运行（`runs/olr_anom1`，09:59，与统筹快照同一时刻）的版本逐行相同（`olr/strip_cmp.py`）。此后的RTL改动全部是注释与版本记录，全套回归跑的是最终版本。
