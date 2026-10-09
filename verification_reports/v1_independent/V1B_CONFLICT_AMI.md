# V1 独立同拍冲突审查：AMI

固定提交 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`；对象 `rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v`，以下行号全部为该提交。使用仓库 erie-verilog-generator 的 analyze/formatter AST，只做静态审查，未仿真、未修改源文件，未访问独立性隔离的审查分支/目录。设计依据C10/C24以及B交接§3、OWNER_LIFECYCLE_ROUND/F009的明确裁定。模拟9/15位SAR、DONE保持到下次开始、2–20拍转换时延；5000/625拍不能替代真实DONE。

## 1. 上游和共同事件

Top L1127–1130输入manager START/STOP、独立注册的owner-abort/diag；L1139–1142给scheduler/SSW同源fire和注册完成；L1157接唯一物理idle。Top L328–360证明diag、外部abort与采样返回并无互斥门；manager L451–464证明正常START前ADC/数字/IDAC排空，START/STOP接受状态互斥。模拟返回经async capture两级同步、RAW缓存、S1重构输出；AMI L2848/L2873同一真实fire启动capture/S1，L2874将超时作废扇到S1。

F=transaction_start_fire（L986/L1046）；X=capture transfer（L944）；C=completion emit（L950–952）；V=owner lost fire（L954）；B=ADC busy fault（L955）；P=DC结果fork装载（L1008）；Mt/Dt=测量/检测分支释放（L1002/1005）；Q=calibration request fire（L980）；U=calibration withdraw（L961）。S/A/L分别为START/abort/STOP；Z=flag_result_abort_discard（L999）；G=RUN ended且datapath empty（L963）。reset最高优先，reset与任意输入可同拍(b)，不是输入互斥。

直接可证明的互斥：(a) F/V：F需!ADC_INFLIGHT，V需已有owner；F/为现有owner建立completion_pending的X分支同样要求相反在途位。F/C需加上S1缓存/metadata的一笔事务保持不变量，不能仅看C的表达式就声称互斥；无owner迟到RAW的X则不因该谓词与F互斥，应保留T-AMI-01窗口检查。V/C因为V需!completion_pending而C需pending；V/X因为V需!capture_valid而X需valid；V/measurement discard由L954直接排除；B/V因ADC idle取值相反；startup/recheck请求源因L973含!precision_calibration_valid而L976含该valid；两个测试注入ready在L1063/1064逐路排除另一valid。测试注入被参数与enable双门控，生产关闭，不将注入行为冒充生产普通场景。

**非互斥**：STOP/C、abort/C、diag/新错误、terminal/P、P/Mt/Dt、高低两lane待分发、A/V/B。manager或模拟ADC没有与这些数字处理相位互斥的规则。输出不是同一always，必须检查采样沿前的旧资格和沿后注册结果的组合。

## 2. 对象与全部优先级/同拍处置

顺序写成`>`表示else-if；“后置”只用于独立if。相同条件/结构的寄存器成组列出，但每个对象名及always起点在文末逐一列出。

| 对象/always | 全部非reset条件顺序 | 同拍条件对及结论 |
|---|---|---|
| integration_protocol_error_sticky_o L1235 | 合格diag清 > router非法类型、held payload变化、start错配、cal结果错配、late NORMAL、无owner RAW、identity注入、completion错配、来源冲突、非法type11置1 | diag/新错误可同拍(c)，V1-AMI-02；START/STOP无直接清(b)，C10 §15.1；错误组合均同值1(b) |
| adc_transaction_complete_event_o L1246、adc_transaction_success_o L1259 | S清 > C发布event及success > 默认清 | S/C生产(a)，manager empty排除缓存完成；A/C可同拍(b)，success含A即时Z；STOP/C可同拍(c)，V1-AMI-01；V/C(a)；注册event默认归零(b) |
| adc_complete_sample_index_o L1272 | S清 > C或V装原owner index > 保持 | C/V(a)；A/C/V可同拍(b)，原index必须发布；S/旧owner生产(a)；非法跨代际START另列T-AMI-04 |
| adc_transaction_lost_event_o L1283 | S清 > 每拍装V | V/S(a)，V本身含!S；V/C(a)；V/L或A可同拍(b)，R3允许排空作废，按方案甲不等待第二个DONE |
| owner_lost_sticky_o L1294 | V置1 > 合格diag清 > 保持 | diag/V可同拍(b)，新作废优先，生命周期报告§1.2；S不清(b)，B §3.6 |
| result_sample_valid_o L1305 | Z清 > P装(!invalid注入) > Mt清 | P/Mt可同拍(b)，新载荷资格胜出，避免清掉新事务；Z/P/Mt可同拍(b)，取消胜出；STOP沿Z尚未形成时的P见V1-AMI-01边界；独立检测资格不随Mt清 |
| measurement_result_discard_event_o L1318 | S清 > 测量discard或V置1 > 默认0 | 两种discard(a)，L954排除测量discard；S/V(a)；S/测量discard生产(a)，empty；事件无ready，必须和下面载荷对齐 |
| discard reason/identity_valid/sample_valid/五身份字段 L1331–1422、generation L1435 | S清 > 测量discard取结果身份/原因 > V取owner身份/LOST原因/sample_valid0 > 保持 | 两discard(a)；A/系统fault/测量discard可同拍(c)，V1-AMI-03；同一测量discard各字段同优先级(b)，不过generation仍取上游fork见T-AMI-03；Mt与Z时输出valid被Z抑制，无实际ready/valid传输，合同的“传输优先”边界见T-AMI-02 |
| calibration_sample_valid_o L1449 | L/A/integration_blocking清 > Q清 > oldvalid0且request_inflight0时 recheck源置1 > startup源置1 | Q/L/A生产(a)，scheduler ready含其生命周期，AMI ready来源也封闭；两源(a)，precisionvalid正反；blocking/装载同拍(b)，清优先；run_enable撤销不直接清，来源受RUN门控，已有valid生命周期见T-AMI-04 |
| calibration_{color_ir,frame_type,request_reason}_o L1466/1479/1492 | oldvalid0且request_inflight0时 recheck源装 > startup源装 | 来源(a)，完整三字段同谓词(b)；L/A同拍可能装字段但valid被取消(b)，无可消费事务；持valid时payload保持(b)，C10 §11 |
| flag_system_fault_discard_pending L1507 | 系统discard事件置1 > datapath empty清 | event/empty可同拍(b)，event优先；事件当拍Z/reason缺少即时项(c)，V1-AMI-03；START不直接清，manager empty与episode恢复前提见T-AMI-04 |
| cnt_owner_age L1518 | F归0 > owner在途且age<9000递增 > 保持 | F/递增(a)，INFLIGHT相反；C/V/递增可同拍(b)，终止拍仍加1但后续无owner不读age，下一F清；A/L不清(b)，需要继续监视旧owner |
| cnt_lost_red/ir/cal L1529/1542/1555 | S清 > 同槽真实匹配C清 > 同槽V且未饱和+1 | C/V(a)，pending相反；槽位两两(a)，TYPE/COLOR互斥；S/V(a)；STOP/abort与匹配C可同拍(b)，R2也清连续计数，生命周期§1.2；deadline U不递增(b) |
| lane06/07 active hold L1568/1581 | S或A清 > 新lost-limit/busy fault置1 > G清 | 新故障/G生产(a)或同拍set优先(b)，G含无owner而fault需owner；A/新故障可能同拍，active清而pending仍置1，T-AMI-05；S/new生产(a)，empty或V含!S；L不直接清，G释放按B §3.6 |
| lane01/02/03 active holds L1763/1776/1789 | S或A清 > 各新来源置1 > G清 | source/G除故障输入外受owner/数据链空条件排除；新置位胜过G(b)；A/new可能同拍T-AMI-05；S/new合法START前empty，但source有效非法输入不由empty全排除，不作无条件(a) |
| 七pending lane L1594/1605/1616/1627/1638/1649/1660 | 对应新来源置1 > 本lane dispatch清 > 保持 | 同一lane source/dispatch可同拍(b)，新事件保持，不能丢；多lane同拍独立保留，dispatch明确优先01>02>03>04>05>06>07(b)，C10 §6.11及B §3.6；terminal/diag不清pending(b)；身份只读实时owner/子模块记录，见T-AMI-06和V1-AMI-04 |
| flag_detection_discard_episode_active L1671 | trigger置1 > PWI empty清 | trigger/empty(a)，trigger含!empty；terminal重复期间已active则不再trigger(b)，C10 scope-discard；START不清，PWI空确认恢复(b) |
| reg_adc_inflight_{sample_index,precision_mode,frame_id,color_ir,frame_type,amb_code,dc_code,amb_epoch,dc_epoch} L1682–1754 | F装；其余保持 | A/L/F(a)，start_ready含!start_blocked；C/V/F(a)；身份保留到下一owner(b)，但故障输出identity_valid读活owner，见V1-AMI-04 |
| flag_adc_completion_pending L1802 | C清 > X且有owner置1 > 保持 | C/X在单一S1缓冲、无第二owner的合法链(a)，S1在读取其detect缓存期间不接新交易；V/X及V/C(a)；A/C可同拍(b)，不能直接清而伪造排空；STOP不直接清(b)，等待真实完成/受保护重放 |
| flag_adc_transaction_inflight L1813 | F置1 > C清 > V清 | 三事件两两(a)，上述谓词；A/L保持直到C/V(b)，C10 §7.1；错配C也清AMI owner，而外部scheduler/SSW可能不同，见V1-AMI-04/T-AMI-06 |
| flag_adc_transaction_abort L1826 | F/C/V清 > A且owner或completion pending置1 | F/A(a)；C/V与A可同拍(b)，本拍success仍由即时A封闭，下一拍已无owner所以不留abort标志；L靠stop_result_draining(b) |
| flag_held_start_valid L1837 | !start_valid或F清 > !ready且oldheld0置1 | 清/装载(a)，装条件虽未写valid，但外层!valid优先；held payload九字段L1848–1920在valid&&!ready&&!held装；F/装载(a)，ready相反；L使scheduler valid撤销，下一拍释放held(b) |
| flag_integration_blocking L1929 | S或A清 > 六类严重协议错误置1 | diag不释放blocking(b)，C10 §15；A/new同T-AMI-05；来源冲突(a)，startup/recheck正反；其余错误可同时发生(b)，统一阻断 |
| flag_run_context_ended L1940 | S清 > L置1 | S/L(a)，manager状态；A本身不置ended(b)，Top独立合并STOP请求最终结束RUN；reset置1保证初始历史可清 |
| reg_result_fork_payload L1951 | S或(A且输出idle)清 > P装 > 保持 | S/P生产(a)，empty；A/输出idle/P(a)，idle需!dc_result_valid而P需valid；A且不idle/P可同拍(b)，payload可写但两个pending和sample资格被Z清，不可输出 |
| flag_detection_pending L1962、flag_measurement_pending L1989 | Z清 > P且!normal_output_inhibit置1 > 各自transfer清 | 新装/旧释放可同拍(b)，装载优先、payload原子更新；Z/任何P/transfer(b)，取消优先；P且inhibit1会消耗上游但不留正式valid，应受C10重检隔离解释，T-AMI-07 |
| flag_detection_branch_sample_valid L1976 | Z清 > P装(!invalid注入) > Dt清 | P/Dt(b)，新资格优先；Mt不影响检测资格(b)，已修F-021不重复报；Z/P(b)，取消优先 |
| flag_abort_draining L2002 | S清 > A置1 > ADC/normal fork/measurement output三idle清 | A/三idle可同拍(b)，保留至少一周期取消；S/A可能同拍T-AMI-04；与P/C同拍(b)，即时Z及后续drain保证取消 |
| flag_calibration_request_inflight L2015 | L/A/integration_blocking清 > accepted AMB/DCS或U清 > Q置1 | Q/accepted正常(a)，Q需旧request_inflight0且旧valid1，结果消费旧请求期间source不新建valid；Q/U正常(a)，deadline需已握手波形且AMI已有request_inflight，重发必须下一拍之后；CAL V/U与STOP同拍(b)，同清；两accepted(a)，router互斥TYPE；Q/取消生产(a)，scheduler生命周期门控 |
| reg_inflight_color_ir/frame_type/reason L2028/2037/2046 | Q装；其余保持 | 载荷同一Q(b)，取消后保持不构成有效事务；Q/L/A(a)，上游ready门控 |
| flag_stop_result_draining L2057 | S清 > L置1 > 保持 | S/L(a)，manager；L/C可同拍(c)，本拍success/Z仍见旧draining0，V1-AMI-01；L/A同拍(b)，Z即时A+后续STOP保持取消 |

## 3. (c) 发现

### V1-AMI-01：STOP与真实完成发布同拍，success仍为1（中）

`flag_result_abort_discard` L999包含abort即时项、abort/STOP已注册draining、integration blocking和system fault pending，**不含当前 i_stop_ack_event 或 !run_enable**。L964因此在STOP沿仍允许completion_success=1；L1264–1265注册发布成功，L2062–2063同沿才把stop-draining置1。C10 §13明确STOP时尚未发布的owner只能原身份success=0释放；没有DONE同拍例外。

生产可达：正常owner尚在途，真实RAW已经经同步/S1输出，C=1；主机STOP独立经过manager注册，选择与C的采样沿重合。Top没有C与STOP互斥逻辑。采样沿之前stop-draining0，之后完整event/success1维持一拍0.5 µs。FSC同STOP先标DISCARD，下一沿通常不会记颜色成功，故**不把此点夸大为必然新增正式NORMAL样本**；S1 calibrator L2096也可能在STOP沿接纳结果，后续Z升高才抑制继续路由。要验证跨链是否全部排空及子模块是否提前消耗，但输出旁带违反合同本身已确定。

### V1-AMI-02：诊断清除优先于当拍新协议错误，历史证据丢失（中）

L1238的clear门读旧integration_blocking；旧blocking0时diag被允许。L1240任何新错误同沿存在，因else-if被clear压住；L1934–1935或lane pending/hold却可在该沿置位。错误和诊断清除不是互斥：Top diag在L328–332独立注册，capture/结果/start错配源不检查diag。比如非owner迟到RAW使X且!owner=1，与diag同沿，新blocking1但history sticky0。

C10 §15.1只允许无活动原因后清历史；本沿新原因仍活动。新清/置同时成立时应保存诊断，不应出现已阻断但没有该次sticky的状态。OWNER报告对lost sticky明确采用新置位优先（本模块L1297正确），这里行为相反。严重度中：主要影响故障观察/软件恢复证据，不声明失去故障阻断或RAW错绑。正常模拟返回不会无owner；该例属于生命周期已认可的late-RAW异常场景，不依赖测试注入。

### V1-AMI-03：同拍系统fault discard与abort丢弃，measurement原因误标ABORT（中）

C10 §6.11要求SYSTEM_FAULT（**含本拍事件**）>ABORT>STOP，B §3.6并未覆盖此原因顺序。L1012/1021用于detection的终端原因包含即时系统事件，正确；但L1001 measurement原因只检查旧pending/integration_blocking。已有未发送measurement、ready0、旧fault_pending0，`i_system_fault_discard_event=1`与`i_control_abort_event=1`同沿：Z因A立即成立，L1336/1337锁原因ABORT，而L1510–1511同沿才置系统pending。measurement已被L1992清除，下一拍无法修正原因；事件原因01维持供外部采样。

系统discard来自supervisor，外部abort经Top独立寄存，可以人为对齐；没有排斥门。若仅系统fault事件到达而无即时A，measurement通常延后一拍丢弃且原因正确，故不把所有system-fault discard都报错。后果是同一终端动作的measurement/detection原因不一致，诊断误分类。复核需双路终端组合扫描。

### 待定 V1-AMI-04：错配完成释放AMI owner与故障pending同沿，次拍fault身份失效（候选严重度中；防御路径可达性未证）

当C=1且`flag_adc_completion_owner_match=0`，L1638–1642登记lane03；L1818–1819却无匹配检查而释放AMI owner。下一拍dispatch03，L1206按**当前**`flag_adc_transaction_inflight`给identity_valid，L1207–1211也按当前在途位输出身份。本例已为0，故障的原owner身份被全部遮为0，虽L1682–1758仍持有原metadata。C10 §6.11要求发生故障时原子捕获FAULT_ID并在待分发期间保持，而这里只保存pending，没有lane03身份快照。

普通一对一S1链有完整metadata保持，正常DONE不应错配；必须以异常metadata/保护路径的单元定向激励证明系统可观测性，不宣称每次正常完成都会触发。但这是实现必须检测并报告的错配条件，不能因为正常不出错而省掉防御逻辑。外部scheduler/SSW按AMI重放的原sample index释放，不一定保留或上报这个被隐藏的身份。建议同时检查错配后原owner三方一致、故障记录稳定；不修RTL。

## 4. 待定项

| ID | 所需仿真与判据 |
|---|---|
| T-AMI-01 | RAW在age4499/4500/4501、ADC idle与capture valid变化的四路对齐。V/X、V/C直接互斥已证明，但同步链约2拍窗口无法静态证明RAW属于哪owner。依照B §3.6已定前提测窗口；已知F-3错绑例外不重复当新发现 |
| T-AMI-02 | measurement ready与abort/STOP/system event同沿、前后±1拍。C10“真实ready/valid传输优先”与L1078即时Z遮valid、L1000立即discard的边界需要明确采样口径；记录沿前有效信号与沿后discard，不能仅用consumer_ready=1代替实际transfer |
| T-AMI-03 | measurement discard的五字段已取本地payload，generation L1441仍读上游NORMAL fork。manager保证一次RUN内generation固定，正常单RUN不混代；跨RUN前empty的证据须结合所有pipe缓存实测，不能把不同来源立即等同错绑 |
| T-AMI-04 | START与Top独立abort/系统discard同沿。FSC整状态START胜出、AMI abort-drain START胜出，而系统pending事件胜出；START前的empty排除旧owner但不能排除新的外部abort。扫描完整manager/Top时序，核验新RUN取消优先，无旧valid复活 |
| T-AMI-05 | A与lost-limit/busy-fault/无ownerRAW/completion错配同沿；active hold在L1571/1584/1766/1779/1792清，而对应pending仍置。B §3.6“新故障置位优先”的范围应与此组合核验；G与新故障时set优先已正确，不能将恢复优先一概判错误。全链验证supervisor是否看到valid但active低、是否仍保存新原因 |
| T-AMI-06 | 多lane同拍或连续到达，特别是06与04/05、03与恢复同拍。pending只保存原因，不保存lane01/02/03/06/07独立完整身份；04/05转发child当前快照。延迟分发时release、abort、新owner或子模块新记录是否改写FAULT_ID。必须比较源沿身份与dispatch沿身份；不能用cause顺序正确证明身份正确 |
| T-AMI-07 | normal_output_inhibit升高与最后一笔DC P及旧Mt/Dt释放同沿，确认上游消费被抑制时是否需要measurement discard、谁持有该transaction；检测flush与fork装载优先同时核验，覆盖重检阶段入口/出口 |

## 5. always覆盖和寄存器清单

AST共73个always，全为posedge i_clk/negedge i_rstn；没有组合always可跳读。已覆盖所有连续资格L944–1041、输出L1045–1230，及所有子模块端口连接L2069–2904；payload拼接与解拼L998/1009顺序对应。以下逐块清单与§2矩阵成组对象一一对应。

```text
1235 integration_protocol_error_sticky_o
1246 adc_transaction_complete_event_o; 1259 adc_transaction_success_o
1272 adc_complete_sample_index_o; 1283 adc_transaction_lost_event_o
1294 owner_lost_sticky_o; 1305 result_sample_valid_o
1318 measurement_result_discard_event_o; 1331 measurement_result_discard_reason_o
1344 measurement_result_discard_identity_valid_o; 1357 measurement_result_discard_sample_valid_o
1370 measurement_result_discard_frame_id_o; 1383 measurement_result_discard_sample_index_o
1396 measurement_result_discard_color_ir_o; 1409 measurement_result_discard_frame_type_o
1422 measurement_result_discard_precision_o; 1435 measurement_result_discard_run_generation_o
1449 calibration_sample_valid_o; 1466 calibration_color_ir_o
1479 calibration_frame_type_o; 1492 calibration_request_reason_o
1507 flag_system_fault_discard_pending; 1518 cnt_owner_age
1529 cnt_lost_red; 1542 cnt_lost_ir; 1555 cnt_lost_cal
1568 flag_owner_lost_fault_hold; 1581 flag_adc_busy_fault_hold
1594 flag_ami_fault_pending_06; 1605 flag_ami_fault_pending_07
1616 flag_ami_fault_pending_01; 1627 flag_ami_fault_pending_02
1638 flag_ami_fault_pending_03; 1649 flag_ami_fault_pending_04; 1660 flag_ami_fault_pending_05
1671 flag_detection_discard_episode_active
1682 reg_adc_inflight_sample_index; 1691 reg_adc_inflight_precision_mode
1700 reg_adc_inflight_frame_id; 1709 reg_adc_inflight_color_ir
1718 reg_adc_inflight_frame_type; 1727 reg_adc_inflight_amb_code
1736 reg_adc_inflight_dc_code; 1745 reg_adc_inflight_amb_epoch; 1754 reg_adc_inflight_dc_epoch
1763 flag_test_identity_hold; 1776 flag_owner_protocol_fault_hold
1789 flag_recovery_context_fault_hold; 1802 flag_adc_completion_pending
1813 flag_adc_transaction_inflight; 1826 flag_adc_transaction_abort
1837 flag_held_start_valid; 1848 reg_held_start_amb_code; 1857 reg_held_start_amb_epoch
1866 reg_held_start_color_ir; 1875 reg_held_start_dc_code; 1884 reg_held_start_dc_epoch
1893 reg_held_start_frame_id; 1902 reg_held_start_frame_type
1911 reg_held_start_precision; 1920 reg_held_start_sample_index
1929 flag_integration_blocking; 1940 flag_run_context_ended
1951 reg_result_fork_payload; 1962 flag_detection_pending
1976 flag_detection_branch_sample_valid; 1989 flag_measurement_pending
2002 flag_abort_draining; 2015 flag_calibration_request_inflight
2028 reg_inflight_color_ir; 2037 reg_inflight_frame_type; 2046 reg_inflight_reason
2057 flag_stop_result_draining
```

合同滞后按已定裁定处理：五lane→七lane、LOST原因11、4500/2/9000参数、START/abort/排空后的active释放、START不清history、F-1/F-2/F-3/F-7、L-5纵深防御和L-3边界，均不重复报为新缺陷。B §3.12指出wrapper_fault_blocking还含integration_blocking，因此只看到lane落下不能声称wrapper已无阻断。

## 6. 文末汇总

(c)：V1-AMI-01（中，STOP同拍成功旁带）；V1-AMI-02（中，diag覆盖新错误）；V1-AMI-03（中，同拍system/abort原因覆盖）。待定：T-AMI-01～08，含V1-AMI-04条件性身份保留缺口。这里的静态反例和历史报告中的仿真证据分开陈述，没有宣称本次运行验证闭合。

## 补充覆盖证据：技能AST与全部always原始顺序

技能静态门禁的compile/AST均passed；compile在这里仅指formatter AST+静态lint，testbench/toolchain未请求，没有外部编译、仿真或综合。
基线严格风格门禁：2 error(s)，1 strict warning(s)。现有源文件不修复，门禁成功也不能证明同拍功能正确。

### L1235：integration_protocol_error_sticky_o

```text
1235: 	always@(posedge i_clk or negedge i_rstn)begin
1236: 		if(i_rstn == 1'b0)begin
1237: 			integration_protocol_error_sticky_o <= 1'b0;
1238: 		end else if(i_diag_clear_event == 1'b1 && (flag_integration_blocking == 1'b0 || (flag_run_context_ended == 1'b1 && o_datapath_empty == 1'b1)))begin
1239: 			integration_protocol_error_sticky_o <= 1'b0;
1240: 		end else if(flag_router_frame_type_error == 1'b1 || flag_start_payload_changed == 1'b1 || flag_start_context_mismatch == 1'b1 || flag_calibration_result_mismatch == 1'b1 || flag_late_normal_result == 1'b1 || flag_adc_capture_without_owner == 1'b1 || flag_test_identity_inject_fire == 1'b1 || (flag_adc_completion_emit == 1'b1 && flag_adc_completion_owner_match == 1'b0) || (flag_startup_request_source == 1'b1 && flag_recheck_request_source == 1'b1) || (i_transaction_start_valid == 1'b1 && (i_transaction_frame_type == 2'b11)))begin
1241: 			integration_protocol_error_sticky_o <= 1'b1;
1242: 		end
1243: 	end
```

### L1246：adc_transaction_complete_event_o

```text
1246: 	always@(posedge i_clk or negedge i_rstn)begin
1247: 		if(i_rstn == 1'b0)begin
1248: 			adc_transaction_complete_event_o <= 1'b0;
1249: 		end else if(i_start_ack_event == 1'b1)begin
1250: 			adc_transaction_complete_event_o <= 1'b0;
1251: 		end else if(flag_adc_completion_emit == 1'b1)begin
1252: 			adc_transaction_complete_event_o <= 1'b1;
1253: 		end else begin
1254: 			adc_transaction_complete_event_o <= 1'b0;
1255: 		end
1256: 	end
```

### L1259：adc_transaction_success_o

```text
1259: 	always@(posedge i_clk or negedge i_rstn)begin
1260: 		if(i_rstn == 1'b0)begin
1261: 			adc_transaction_success_o <= 1'b0;
1262: 		end else if(i_start_ack_event == 1'b1)begin
1263: 			adc_transaction_success_o <= 1'b0;
1264: 		end else if(flag_adc_completion_emit == 1'b1)begin
1265: 			adc_transaction_success_o <= flag_adc_completion_success;
1266: 		end else begin
1267: 			adc_transaction_success_o <= 1'b0;
1268: 		end
1269: 	end
```

### L1272：adc_complete_sample_index_o

```text
1272: 	always@(posedge i_clk or negedge i_rstn)begin
1273: 		if(i_rstn == 1'b0)begin
1274: 			adc_complete_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
1275: 		end else if(i_start_ack_event == 1'b1)begin
1276: 			adc_complete_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
1277: 		end else if(flag_adc_completion_emit == 1'b1 || flag_owner_lost_fire == 1'b1)begin
1278: 			adc_complete_sample_index_o <= reg_adc_inflight_sample_index;
1279: 		end
1280: 	end
```

### L1283：adc_transaction_lost_event_o

```text
1283: 	always@(posedge i_clk or negedge i_rstn)begin
1284: 		if(i_rstn == 1'b0)begin
1285: 			adc_transaction_lost_event_o <= 1'b0;
1286: 		end else if(i_start_ack_event == 1'b1)begin
1287: 			adc_transaction_lost_event_o <= 1'b0;
1288: 		end else begin
1289: 			adc_transaction_lost_event_o <= flag_owner_lost_fire;
1290: 		end
1291: 	end
```

### L1294：owner_lost_sticky_o

```text
1294: 	always@(posedge i_clk or negedge i_rstn)begin
1295: 		if(i_rstn == 1'b0)begin
1296: 			owner_lost_sticky_o <= 1'b0;
1297: 		end else if(flag_owner_lost_fire == 1'b1)begin
1298: 			owner_lost_sticky_o <= 1'b1;
1299: 		end else if(i_diag_clear_event == 1'b1 && (flag_owner_lost_fault_hold == 1'b0 || flag_run_context_drained == 1'b1))begin
1300: 			owner_lost_sticky_o <= 1'b0;
1301: 		end
1302: 	end
```

### L1305：result_sample_valid_o

```text
1305: 	always@(posedge i_clk or negedge i_rstn)begin
1306: 		if(i_rstn == 1'b0)begin
1307: 			result_sample_valid_o <= 1'b0;
1308: 		end else if(flag_result_abort_discard == 1'b1)begin
1309: 			result_sample_valid_o <= 1'b0;
1310: 		end else if(flag_dc_result_transfer == 1'b1)begin
1311: 			result_sample_valid_o <= !flag_test_invalid_sample_fire;
1312: 		end else if(flag_measurement_transfer == 1'b1)begin
1313: 			result_sample_valid_o <= 1'b0;
1314: 		end
1315: 	end
```

### L1318：measurement_result_discard_event_o

```text
1318: 	always@(posedge i_clk or negedge i_rstn)begin
1319: 		if(i_rstn == 1'b0)begin
1320: 			measurement_result_discard_event_o <= 1'b0;
1321: 		end else if(i_start_ack_event == 1'b1)begin
1322: 			measurement_result_discard_event_o <= 1'b0;
1323: 		end else if(flag_measurement_result_discard_fire == 1'b1 || flag_owner_lost_fire == 1'b1)begin
1324: 			measurement_result_discard_event_o <= 1'b1;
1325: 		end else begin
1326: 			measurement_result_discard_event_o <= 1'b0;
1327: 		end
1328: 	end
```

### L1331：measurement_result_discard_reason_o

```text
1331: 	always@(posedge i_clk or negedge i_rstn)begin
1332: 		if(i_rstn == 1'b0)begin
1333: 			measurement_result_discard_reason_o <= 2'b00;
1334: 		end else if(i_start_ack_event == 1'b1)begin
1335: 			measurement_result_discard_reason_o <= 2'b00;
1336: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1337: 			measurement_result_discard_reason_o <= flag_measurement_result_discard_reason;
1338: 		end else if(flag_owner_lost_fire == 1'b1)begin
1339: 			measurement_result_discard_reason_o <= DISCARD_REASON_COMPLETION_LOST;
1340: 		end
1341: 	end
```

### L1344：measurement_result_discard_identity_valid_o

```text
1344: 	always@(posedge i_clk or negedge i_rstn)begin
1345: 		if(i_rstn == 1'b0)begin
1346: 			measurement_result_discard_identity_valid_o <= 1'b0;
1347: 		end else if(i_start_ack_event == 1'b1)begin
1348: 			measurement_result_discard_identity_valid_o <= 1'b0;
1349: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1350: 			measurement_result_discard_identity_valid_o <= 1'b1;
1351: 		end else if(flag_owner_lost_fire == 1'b1)begin
1352: 			measurement_result_discard_identity_valid_o <= 1'b1;
1353: 		end
1354: 	end
```

### L1357：measurement_result_discard_sample_valid_o

```text
1357: 	always@(posedge i_clk or negedge i_rstn)begin
1358: 		if(i_rstn == 1'b0)begin
1359: 			measurement_result_discard_sample_valid_o <= 1'b0;
1360: 		end else if(i_start_ack_event == 1'b1)begin
1361: 			measurement_result_discard_sample_valid_o <= 1'b0;
1362: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1363: 			measurement_result_discard_sample_valid_o <= result_sample_valid_o;
1364: 		end else if(flag_owner_lost_fire == 1'b1)begin
1365: 			measurement_result_discard_sample_valid_o <= 1'b0;
1366: 		end
1367: 	end
```

### L1370：measurement_result_discard_frame_id_o

```text
1370: 	always@(posedge i_clk or negedge i_rstn)begin
1371: 		if(i_rstn == 1'b0)begin
1372: 			measurement_result_discard_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}};
1373: 		end else if(i_start_ack_event == 1'b1)begin
1374: 			measurement_result_discard_frame_id_o <= {C_FRAME_ID_WIDTH{1'b0}};
1375: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1376: 			measurement_result_discard_frame_id_o <= result_frame_id_o;
1377: 		end else if(flag_owner_lost_fire == 1'b1)begin
1378: 			measurement_result_discard_frame_id_o <= reg_adc_inflight_frame_id;
1379: 		end
1380: 	end
```

### L1383：measurement_result_discard_sample_index_o

```text
1383: 	always@(posedge i_clk or negedge i_rstn)begin
1384: 		if(i_rstn == 1'b0)begin
1385: 			measurement_result_discard_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
1386: 		end else if(i_start_ack_event == 1'b1)begin
1387: 			measurement_result_discard_sample_index_o <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
1388: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1389: 			measurement_result_discard_sample_index_o <= result_sample_index_o;
1390: 		end else if(flag_owner_lost_fire == 1'b1)begin
1391: 			measurement_result_discard_sample_index_o <= reg_adc_inflight_sample_index;
1392: 		end
1393: 	end
```

### L1396：measurement_result_discard_color_ir_o

```text
1396: 	always@(posedge i_clk or negedge i_rstn)begin
1397: 		if(i_rstn == 1'b0)begin
1398: 			measurement_result_discard_color_ir_o <= 1'b0;
1399: 		end else if(i_start_ack_event == 1'b1)begin
1400: 			measurement_result_discard_color_ir_o <= 1'b0;
1401: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1402: 			measurement_result_discard_color_ir_o <= result_color_ir_o;
1403: 		end else if(flag_owner_lost_fire == 1'b1)begin
1404: 			measurement_result_discard_color_ir_o <= reg_adc_inflight_color_ir;
1405: 		end
1406: 	end
```

### L1409：measurement_result_discard_frame_type_o

```text
1409: 	always@(posedge i_clk or negedge i_rstn)begin
1410: 		if(i_rstn == 1'b0)begin
1411: 			measurement_result_discard_frame_type_o <= 2'b00;
1412: 		end else if(i_start_ack_event == 1'b1)begin
1413: 			measurement_result_discard_frame_type_o <= 2'b00;
1414: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1415: 			measurement_result_discard_frame_type_o <= result_frame_type_o;
1416: 		end else if(flag_owner_lost_fire == 1'b1)begin
1417: 			measurement_result_discard_frame_type_o <= reg_adc_inflight_frame_type;
1418: 		end
1419: 	end
```

### L1422：measurement_result_discard_precision_o

```text
1422: 	always@(posedge i_clk or negedge i_rstn)begin
1423: 		if(i_rstn == 1'b0)begin
1424: 			measurement_result_discard_precision_o <= 1'b0;
1425: 		end else if(i_start_ack_event == 1'b1)begin
1426: 			measurement_result_discard_precision_o <= 1'b0;
1427: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1428: 			measurement_result_discard_precision_o <= result_precision_mode_o;
1429: 		end else if(flag_owner_lost_fire == 1'b1)begin
1430: 			measurement_result_discard_precision_o <= reg_adc_inflight_precision_mode;
1431: 		end
1432: 	end
```

### L1435：measurement_result_discard_run_generation_o

```text
1435: 	always@(posedge i_clk or negedge i_rstn)begin
1436: 		if(i_rstn == 1'b0)begin
1437: 			measurement_result_discard_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}};
1438: 		end else if(i_start_ack_event == 1'b1)begin
1439: 			measurement_result_discard_run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}};
1440: 		end else if(flag_measurement_result_discard_fire == 1'b1)begin
1441: 			measurement_result_discard_run_generation_o <= dec_fork_measurement_run_generation;
1442: 		end else if(flag_owner_lost_fire == 1'b1)begin
1443: 			measurement_result_discard_run_generation_o <= i_run_generation;
1444: 		end
1445: 	end
```

### L1449：calibration_sample_valid_o

```text
1449: 	always@(posedge i_clk or negedge i_rstn)begin
1450: 		if(i_rstn == 1'b0)begin
1451: 			calibration_sample_valid_o <= 1'b0;
1452: 		end else if(i_stop_ack_event == 1'b1 || i_control_abort_event == 1'b1 || flag_integration_blocking == 1'b1)begin
1453: 			calibration_sample_valid_o <= 1'b0;
1454: 		end else if(calibration_request_fire_o == 1'b1)begin
1455: 			calibration_sample_valid_o <= 1'b0;
1456: 		end else if(calibration_sample_valid_o == 1'b0 && flag_calibration_request_inflight == 1'b0)begin
1457: 			if(flag_recheck_request_source == 1'b1)begin
1458: 				calibration_sample_valid_o <= 1'b1;
1459: 			end else if(flag_startup_request_source == 1'b1)begin
1460: 				calibration_sample_valid_o <= 1'b1;
1461: 			end
1462: 		end
1463: 	end
```

### L1466：calibration_color_ir_o

```text
1466: 	always@(posedge i_clk or negedge i_rstn)begin
1467: 		if(i_rstn == 1'b0)begin
1468: 			calibration_color_ir_o <= 1'b0;
1469: 		end else if(calibration_sample_valid_o == 1'b0 && flag_calibration_request_inflight == 1'b0)begin
1470: 			if(flag_recheck_request_source == 1'b1)begin
1471: 				calibration_color_ir_o <= flag_precision_calibration_color_ir;
1472: 			end else if(flag_startup_request_source == 1'b1)begin
1473: 				calibration_color_ir_o <= flag_startup_request_color_ir;
1474: 			end
1475: 		end
1476: 	end
```

### L1479：calibration_frame_type_o

```text
1479: 	always@(posedge i_clk or negedge i_rstn)begin
1480: 		if(i_rstn == 1'b0)begin
1481: 			calibration_frame_type_o <= FRAME_TYPE_AMB;
1482: 		end else if(calibration_sample_valid_o == 1'b0 && flag_calibration_request_inflight == 1'b0)begin
1483: 			if(flag_recheck_request_source == 1'b1)begin
1484: 				calibration_frame_type_o <= dec_precision_calibration_frame_type;
1485: 			end else if(flag_startup_request_source == 1'b1)begin
1486: 				calibration_frame_type_o <= flag_startup_request_frame_type;
1487: 			end
1488: 		end
1489: 	end
```

### L1492：calibration_request_reason_o

```text
1492: 	always@(posedge i_clk or negedge i_rstn)begin
1493: 		if(i_rstn == 1'b0)begin
1494: 			calibration_request_reason_o <= REASON_STARTUP;
1495: 		end else if(calibration_sample_valid_o == 1'b0 && flag_calibration_request_inflight == 1'b0)begin
1496: 			if(flag_recheck_request_source == 1'b1)begin
1497: 				calibration_request_reason_o <= REASON_RECHECK;
1498: 			end else if(flag_startup_request_source == 1'b1)begin
1499: 				calibration_request_reason_o <= REASON_STARTUP;
1500: 			end
1501: 		end
1502: 	end
```

### L1507：flag_system_fault_discard_pending

```text
1507: 	always@(posedge i_clk or negedge i_rstn)begin
1508: 		if(i_rstn == 1'b0)begin
1509: 			flag_system_fault_discard_pending <= 1'b0;
1510: 		end else if(i_system_fault_discard_event == 1'b1)begin
1511: 			flag_system_fault_discard_pending <= 1'b1;
1512: 		end else if(o_datapath_empty == 1'b1)begin
1513: 			flag_system_fault_discard_pending <= 1'b0;
1514: 		end
1515: 	end
```

### L1518：cnt_owner_age

```text
1518: 	always@(posedge i_clk or negedge i_rstn)begin
1519: 		if(i_rstn == 1'b0)begin
1520: 			cnt_owner_age <= 16'd0;
1521: 		end else if(o_transaction_start_fire == 1'b1)begin
1522: 			cnt_owner_age <= 16'd0;
1523: 		end else if(flag_adc_transaction_inflight == 1'b1 && cnt_owner_age < ADC_BUSY_FAULT_CYCLES)begin
1524: 			cnt_owner_age <= cnt_owner_age + 16'd1;
1525: 		end
1526: 	end
```

### L1529：cnt_lost_red

```text
1529: 	always@(posedge i_clk or negedge i_rstn)begin
1530: 		if(i_rstn == 1'b0)begin
1531: 			cnt_lost_red <= 4'd0;
1532: 		end else if(i_start_ack_event == 1'b1)begin
1533: 			cnt_lost_red <= 4'd0;
1534: 		end else if(flag_owner_alive_completion == 1'b1 && flag_owner_slot_red == 1'b1)begin
1535: 			cnt_lost_red <= 4'd0;
1536: 		end else if(flag_owner_lost_fire == 1'b1 && flag_owner_slot_red == 1'b1 && cnt_lost_red < C_ADC_COMPLETION_LOST_LIMIT)begin
1537: 			cnt_lost_red <= cnt_lost_red + 4'd1;
1538: 		end
1539: 	end
```

### L1542：cnt_lost_ir

```text
1542: 	always@(posedge i_clk or negedge i_rstn)begin
1543: 		if(i_rstn == 1'b0)begin
1544: 			cnt_lost_ir <= 4'd0;
1545: 		end else if(i_start_ack_event == 1'b1)begin
1546: 			cnt_lost_ir <= 4'd0;
1547: 		end else if(flag_owner_alive_completion == 1'b1 && flag_owner_slot_ir == 1'b1)begin
1548: 			cnt_lost_ir <= 4'd0;
1549: 		end else if(flag_owner_lost_fire == 1'b1 && flag_owner_slot_ir == 1'b1 && cnt_lost_ir < C_ADC_COMPLETION_LOST_LIMIT)begin
1550: 			cnt_lost_ir <= cnt_lost_ir + 4'd1;
1551: 		end
1552: 	end
```

### L1555：cnt_lost_cal

```text
1555: 	always@(posedge i_clk or negedge i_rstn)begin
1556: 		if(i_rstn == 1'b0)begin
1557: 			cnt_lost_cal <= 4'd0;
1558: 		end else if(i_start_ack_event == 1'b1)begin
1559: 			cnt_lost_cal <= 4'd0;
1560: 		end else if(flag_owner_alive_completion == 1'b1 && flag_owner_slot_cal == 1'b1)begin
1561: 			cnt_lost_cal <= 4'd0;
1562: 		end else if(flag_owner_lost_fire == 1'b1 && flag_owner_slot_cal == 1'b1 && cnt_lost_cal < C_ADC_COMPLETION_LOST_LIMIT)begin
1563: 			cnt_lost_cal <= cnt_lost_cal + 4'd1;
1564: 		end
1565: 	end
```

### L1568：flag_owner_lost_fault_hold

```text
1568: 	always@(posedge i_clk or negedge i_rstn)begin
1569: 		if(i_rstn == 1'b0)begin
1570: 			flag_owner_lost_fault_hold <= 1'b0;
1571: 		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
1572: 			flag_owner_lost_fault_hold <= 1'b0;
1573: 		end else if(flag_owner_lost_limit_reached == 1'b1)begin
1574: 			flag_owner_lost_fault_hold <= 1'b1;
1575: 		end else if(flag_run_context_drained == 1'b1)begin
1576: 			flag_owner_lost_fault_hold <= 1'b0;
1577: 		end
1578: 	end
```

### L1581：flag_adc_busy_fault_hold

```text
1581: 	always@(posedge i_clk or negedge i_rstn)begin
1582: 		if(i_rstn == 1'b0)begin
1583: 			flag_adc_busy_fault_hold <= 1'b0;
1584: 		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
1585: 			flag_adc_busy_fault_hold <= 1'b0;
1586: 		end else if(flag_adc_busy_fault_fire == 1'b1)begin
1587: 			flag_adc_busy_fault_hold <= 1'b1;
1588: 		end else if(flag_run_context_drained == 1'b1)begin
1589: 			flag_adc_busy_fault_hold <= 1'b0;
1590: 		end
1591: 	end
```

### L1594：flag_ami_fault_pending_06

```text
1594: 	always@(posedge i_clk or negedge i_rstn)begin
1595: 		if(i_rstn == 1'b0)begin
1596: 			flag_ami_fault_pending_06 <= 1'b0;
1597: 		end else if(flag_owner_lost_limit_reached == 1'b1)begin
1598: 			flag_ami_fault_pending_06 <= 1'b1;
1599: 		end else if(flag_ami_fault_dispatch_06 == 1'b1)begin
1600: 			flag_ami_fault_pending_06 <= 1'b0;
1601: 		end
1602: 	end
```

### L1605：flag_ami_fault_pending_07

```text
1605: 	always@(posedge i_clk or negedge i_rstn)begin
1606: 		if(i_rstn == 1'b0)begin
1607: 			flag_ami_fault_pending_07 <= 1'b0;
1608: 		end else if(flag_adc_busy_fault_fire == 1'b1)begin
1609: 			flag_ami_fault_pending_07 <= 1'b1;
1610: 		end else if(flag_ami_fault_dispatch_07 == 1'b1)begin
1611: 			flag_ami_fault_pending_07 <= 1'b0;
1612: 		end
1613: 	end
```

### L1616：flag_ami_fault_pending_01

```text
1616: 	always@(posedge i_clk or negedge i_rstn)begin
1617: 		if(i_rstn == 1'b0)begin
1618: 			flag_ami_fault_pending_01 <= 1'b0;
1619: 		end else if(flag_test_identity_inject_fire == 1'b1)begin
1620: 			flag_ami_fault_pending_01 <= 1'b1;
1621: 		end else if(flag_ami_fault_dispatch_01 == 1'b1)begin
1622: 			flag_ami_fault_pending_01 <= 1'b0;
1623: 		end
1624: 	end
```

### L1627：flag_ami_fault_pending_02

```text
1627: 	always@(posedge i_clk or negedge i_rstn)begin
1628: 		if(i_rstn == 1'b0)begin
1629: 			flag_ami_fault_pending_02 <= 1'b0;
1630: 		end else if(flag_calibration_result_mismatch == 1'b1 || flag_adc_capture_without_owner == 1'b1 || (i_transaction_start_valid == 1'b1 && ((i_transaction_frame_type == FRAME_TYPE_AMB) || (i_transaction_frame_type == FRAME_TYPE_DCS)) && flag_calibration_start_match == 1'b0) || (flag_startup_request_source == 1'b1 && flag_recheck_request_source == 1'b1))begin
1631: 			flag_ami_fault_pending_02 <= 1'b1;
1632: 		end else if(flag_ami_fault_dispatch_02 == 1'b1)begin
1633: 			flag_ami_fault_pending_02 <= 1'b0;
1634: 		end
1635: 	end
```

### L1638：flag_ami_fault_pending_03

```text
1638: 	always@(posedge i_clk or negedge i_rstn)begin
1639: 		if(i_rstn == 1'b0)begin
1640: 			flag_ami_fault_pending_03 <= 1'b0;
1641: 		end else if(flag_adc_completion_emit == 1'b1 && flag_adc_completion_owner_match == 1'b0)begin
1642: 			flag_ami_fault_pending_03 <= 1'b1;
1643: 		end else if(flag_ami_fault_dispatch_03 == 1'b1)begin
1644: 			flag_ami_fault_pending_03 <= 1'b0;
1645: 		end
1646: 	end
```

### L1649：flag_ami_fault_pending_04

```text
1649: 	always@(posedge i_clk or negedge i_rstn)begin
1650: 		if(i_rstn == 1'b0)begin
1651: 			flag_ami_fault_pending_04 <= 1'b0;
1652: 		end else if(flag_precision_fault_event == 1'b1)begin
1653: 			flag_ami_fault_pending_04 <= 1'b1;
1654: 		end else if(flag_ami_fault_dispatch_04 == 1'b1)begin
1655: 			flag_ami_fault_pending_04 <= 1'b0;
1656: 		end
1657: 	end
```

### L1660：flag_ami_fault_pending_05

```text
1660: 	always@(posedge i_clk or negedge i_rstn)begin
1661: 		if(i_rstn == 1'b0)begin
1662: 			flag_ami_fault_pending_05 <= 1'b0;
1663: 		end else if(flag_idac_fault_event == 1'b1)begin
1664: 			flag_ami_fault_pending_05 <= 1'b1;
1665: 		end else if(flag_ami_fault_dispatch_05 == 1'b1)begin
1666: 			flag_ami_fault_pending_05 <= 1'b0;
1667: 		end
1668: 	end
```

### L1671：flag_detection_discard_episode_active

```text
1671: 	always@(posedge i_clk or negedge i_rstn)begin
1672: 		if(i_rstn == 1'b0)begin
1673: 			flag_detection_discard_episode_active <= 1'b0;
1674: 		end else if(flag_detection_discard_trigger == 1'b1)begin
1675: 			flag_detection_discard_episode_active <= 1'b1;
1676: 		end else if(flag_pwi_detection_datapath_empty == 1'b1)begin
1677: 			flag_detection_discard_episode_active <= 1'b0;
1678: 		end
1679: 	end
```

### L1682：reg_adc_inflight_sample_index

```text
1682: 	always@(posedge i_clk or negedge i_rstn)begin
1683: 		if(i_rstn == 1'b0)begin
1684: 			reg_adc_inflight_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
1685: 		end else if(o_transaction_start_fire == 1'b1)begin
1686: 			reg_adc_inflight_sample_index <= i_transaction_sample_index;
1687: 		end
1688: 	end
```

### L1691：reg_adc_inflight_precision_mode

```text
1691: 	always@(posedge i_clk or negedge i_rstn)begin
1692: 		if(i_rstn == 1'b0)begin
1693: 			reg_adc_inflight_precision_mode <= 1'b0;
1694: 		end else if(o_transaction_start_fire == 1'b1)begin
1695: 			reg_adc_inflight_precision_mode <= i_transaction_precision_mode;
1696: 		end
1697: 	end
```

### L1700：reg_adc_inflight_frame_id

```text
1700: 	always@(posedge i_clk or negedge i_rstn)begin
1701: 		if(i_rstn == 1'b0)begin
1702: 			reg_adc_inflight_frame_id <= {C_FRAME_ID_WIDTH{1'b0}};
1703: 		end else if(o_transaction_start_fire == 1'b1)begin
1704: 			reg_adc_inflight_frame_id <= i_transaction_frame_id;
1705: 		end
1706: 	end
```

### L1709：reg_adc_inflight_color_ir

```text
1709: 	always@(posedge i_clk or negedge i_rstn)begin
1710: 		if(i_rstn == 1'b0)begin
1711: 			reg_adc_inflight_color_ir <= 1'b0;
1712: 		end else if(o_transaction_start_fire == 1'b1)begin
1713: 			reg_adc_inflight_color_ir <= i_transaction_color_ir;
1714: 		end
1715: 	end
```

### L1718：reg_adc_inflight_frame_type

```text
1718: 	always@(posedge i_clk or negedge i_rstn)begin
1719: 		if(i_rstn == 1'b0)begin
1720: 			reg_adc_inflight_frame_type <= FRAME_TYPE_AMB;
1721: 		end else if(o_transaction_start_fire == 1'b1)begin
1722: 			reg_adc_inflight_frame_type <= i_transaction_frame_type;
1723: 		end
1724: 	end
```

### L1727：reg_adc_inflight_amb_code

```text
1727: 	always@(posedge i_clk or negedge i_rstn)begin
1728: 		if(i_rstn == 1'b0)begin
1729: 			reg_adc_inflight_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}};
1730: 		end else if(o_transaction_start_fire == 1'b1)begin
1731: 			reg_adc_inflight_amb_code <= i_transaction_amb_code_snapshot;
1732: 		end
1733: 	end
```

### L1736：reg_adc_inflight_dc_code

```text
1736: 	always@(posedge i_clk or negedge i_rstn)begin
1737: 		if(i_rstn == 1'b0)begin
1738: 			reg_adc_inflight_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}};
1739: 		end else if(o_transaction_start_fire == 1'b1)begin
1740: 			reg_adc_inflight_dc_code <= i_transaction_dc_code_snapshot;
1741: 		end
1742: 	end
```

### L1745：reg_adc_inflight_amb_epoch

```text
1745: 	always@(posedge i_clk or negedge i_rstn)begin
1746: 		if(i_rstn == 1'b0)begin
1747: 			reg_adc_inflight_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
1748: 		end else if(o_transaction_start_fire == 1'b1)begin
1749: 			reg_adc_inflight_amb_epoch <= i_transaction_amb_code_epoch;
1750: 		end
1751: 	end
```

### L1754：reg_adc_inflight_dc_epoch

```text
1754: 	always@(posedge i_clk or negedge i_rstn)begin
1755: 		if(i_rstn == 1'b0)begin
1756: 			reg_adc_inflight_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
1757: 		end else if(o_transaction_start_fire == 1'b1)begin
1758: 			reg_adc_inflight_dc_epoch <= i_transaction_dc_code_epoch;
1759: 		end
1760: 	end
```

### L1763：flag_test_identity_hold

```text
1763: 	always@(posedge i_clk or negedge i_rstn)begin
1764: 		if(i_rstn == 1'b0)begin
1765: 			flag_test_identity_hold <= 1'b0;
1766: 		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
1767: 			flag_test_identity_hold <= 1'b0;
1768: 		end else if(flag_test_identity_inject_fire == 1'b1)begin
1769: 			flag_test_identity_hold <= 1'b1;
1770: 		end else if(flag_run_context_drained == 1'b1)begin
1771: 			flag_test_identity_hold <= 1'b0;
1772: 		end
1773: 	end
```

### L1776：flag_owner_protocol_fault_hold

```text
1776: 	always@(posedge i_clk or negedge i_rstn)begin
1777: 		if(i_rstn == 1'b0)begin
1778: 			flag_owner_protocol_fault_hold <= 1'b0;
1779: 		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
1780: 			flag_owner_protocol_fault_hold <= 1'b0;
1781: 		end else if(flag_calibration_result_mismatch == 1'b1 || flag_adc_capture_without_owner == 1'b1 || (i_transaction_start_valid == 1'b1 && ((i_transaction_frame_type == FRAME_TYPE_AMB) || (i_transaction_frame_type == FRAME_TYPE_DCS)) && flag_calibration_start_match == 1'b0) || (flag_startup_request_source == 1'b1 && flag_recheck_request_source == 1'b1))begin
1782: 			flag_owner_protocol_fault_hold <= 1'b1;
1783: 		end else if(flag_run_context_drained == 1'b1)begin
1784: 			flag_owner_protocol_fault_hold <= 1'b0;
1785: 		end
1786: 	end
```

### L1789：flag_recovery_context_fault_hold

```text
1789: 	always@(posedge i_clk or negedge i_rstn)begin
1790: 		if(i_rstn == 1'b0)begin
1791: 			flag_recovery_context_fault_hold <= 1'b0;
1792: 		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
1793: 			flag_recovery_context_fault_hold <= 1'b0;
1794: 		end else if(flag_adc_completion_emit == 1'b1 && flag_adc_completion_owner_match == 1'b0)begin
1795: 			flag_recovery_context_fault_hold <= 1'b1;
1796: 		end else if(flag_run_context_drained == 1'b1)begin
1797: 			flag_recovery_context_fault_hold <= 1'b0;
1798: 		end
1799: 	end
```

### L1802：flag_adc_completion_pending

```text
1802: 	always@(posedge i_clk or negedge i_rstn)begin
1803: 		if(i_rstn == 1'b0)begin
1804: 			flag_adc_completion_pending <= 1'b0;
1805: 		end else if(flag_adc_completion_emit == 1'b1)begin
1806: 			flag_adc_completion_pending <= 1'b0;
1807: 		end else if(flag_adc_capture_transfer == 1'b1 && flag_adc_transaction_inflight == 1'b1)begin
1808: 			flag_adc_completion_pending <= 1'b1;
1809: 		end
1810: 	end
```

### L1813：flag_adc_transaction_inflight

```text
1813: 	always@(posedge i_clk or negedge i_rstn)begin
1814: 		if(i_rstn == 1'b0)begin
1815: 			flag_adc_transaction_inflight <= 1'b0;
1816: 		end else if(o_transaction_start_fire == 1'b1)begin
1817: 			flag_adc_transaction_inflight <= 1'b1;
1818: 		end else if(flag_adc_completion_emit == 1'b1)begin
1819: 			flag_adc_transaction_inflight <= 1'b0;
1820: 		end else if(flag_owner_lost_fire == 1'b1)begin
1821: 			flag_adc_transaction_inflight <= 1'b0;
1822: 		end
1823: 	end
```

### L1826：flag_adc_transaction_abort

```text
1826: 	always@(posedge i_clk or negedge i_rstn)begin
1827: 		if(i_rstn == 1'b0)begin
1828: 			flag_adc_transaction_abort <= 1'b0;
1829: 		end else if(o_transaction_start_fire == 1'b1 || flag_adc_completion_emit == 1'b1 || flag_owner_lost_fire == 1'b1)begin
1830: 			flag_adc_transaction_abort <= 1'b0;
1831: 		end else if(i_control_abort_event == 1'b1 && (flag_adc_transaction_inflight == 1'b1 || flag_adc_completion_pending == 1'b1))begin
1832: 			flag_adc_transaction_abort <= 1'b1;
1833: 		end
1834: 	end
```

### L1837：flag_held_start_valid

```text
1837: 	always@(posedge i_clk or negedge i_rstn)begin
1838: 		if(i_rstn == 1'b0)begin
1839: 			flag_held_start_valid <= 1'b0;
1840: 		end else if(i_transaction_start_valid == 1'b0 || o_transaction_start_fire == 1'b1)begin
1841: 			flag_held_start_valid <= 1'b0;
1842: 		end else if(o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1843: 			flag_held_start_valid <= 1'b1;
1844: 		end
1845: 	end
```

### L1848：reg_held_start_amb_code

```text
1848: 	always@(posedge i_clk or negedge i_rstn)begin
1849: 		if(i_rstn == 1'b0)begin
1850: 			reg_held_start_amb_code <= {C_IDAC_CODE_WIDTH{1'b0}};
1851: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1852: 			reg_held_start_amb_code <= i_transaction_amb_code_snapshot;
1853: 		end
1854: 	end
```

### L1857：reg_held_start_amb_epoch

```text
1857: 	always@(posedge i_clk or negedge i_rstn)begin
1858: 		if(i_rstn == 1'b0)begin
1859: 			reg_held_start_amb_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
1860: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1861: 			reg_held_start_amb_epoch <= i_transaction_amb_code_epoch;
1862: 		end
1863: 	end
```

### L1866：reg_held_start_color_ir

```text
1866: 	always@(posedge i_clk or negedge i_rstn)begin
1867: 		if(i_rstn == 1'b0)begin
1868: 			reg_held_start_color_ir <= 1'b0;
1869: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1870: 			reg_held_start_color_ir <= i_transaction_color_ir;
1871: 		end
1872: 	end
```

### L1875：reg_held_start_dc_code

```text
1875: 	always@(posedge i_clk or negedge i_rstn)begin
1876: 		if(i_rstn == 1'b0)begin
1877: 			reg_held_start_dc_code <= {C_IDAC_CODE_WIDTH{1'b0}};
1878: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1879: 			reg_held_start_dc_code <= i_transaction_dc_code_snapshot;
1880: 		end
1881: 	end
```

### L1884：reg_held_start_dc_epoch

```text
1884: 	always@(posedge i_clk or negedge i_rstn)begin
1885: 		if(i_rstn == 1'b0)begin
1886: 			reg_held_start_dc_epoch <= {C_CODE_EPOCH_WIDTH{1'b0}};
1887: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1888: 			reg_held_start_dc_epoch <= i_transaction_dc_code_epoch;
1889: 		end
1890: 	end
```

### L1893：reg_held_start_frame_id

```text
1893: 	always@(posedge i_clk or negedge i_rstn)begin
1894: 		if(i_rstn == 1'b0)begin
1895: 			reg_held_start_frame_id <= {C_FRAME_ID_WIDTH{1'b0}};
1896: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1897: 			reg_held_start_frame_id <= i_transaction_frame_id;
1898: 		end
1899: 	end
```

### L1902：reg_held_start_frame_type

```text
1902: 	always@(posedge i_clk or negedge i_rstn)begin
1903: 		if(i_rstn == 1'b0)begin
1904: 			reg_held_start_frame_type <= 2'b00;
1905: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1906: 			reg_held_start_frame_type <= i_transaction_frame_type;
1907: 		end
1908: 	end
```

### L1911：reg_held_start_precision

```text
1911: 	always@(posedge i_clk or negedge i_rstn)begin
1912: 		if(i_rstn == 1'b0)begin
1913: 			reg_held_start_precision <= 1'b0;
1914: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1915: 			reg_held_start_precision <= i_transaction_precision_mode;
1916: 		end
1917: 	end
```

### L1920：reg_held_start_sample_index

```text
1920: 	always@(posedge i_clk or negedge i_rstn)begin
1921: 		if(i_rstn == 1'b0)begin
1922: 			reg_held_start_sample_index <= {C_SAMPLE_INDEX_WIDTH{1'b0}};
1923: 		end else if(i_transaction_start_valid == 1'b1 && o_transaction_start_ready == 1'b0 && flag_held_start_valid == 1'b0)begin
1924: 			reg_held_start_sample_index <= i_transaction_sample_index;
1925: 		end
1926: 	end
```

### L1929：flag_integration_blocking

```text
1929: 	always@(posedge i_clk or negedge i_rstn)begin
1930: 		if(i_rstn == 1'b0)begin
1931: 			flag_integration_blocking <= 1'b0;
1932: 		end else if(i_start_ack_event == 1'b1 || i_control_abort_event == 1'b1)begin
1933: 			flag_integration_blocking <= 1'b0;
1934: 		end else if(flag_test_identity_inject_fire == 1'b1 || flag_calibration_result_mismatch == 1'b1 || flag_adc_capture_without_owner == 1'b1 || (flag_adc_completion_emit == 1'b1 && flag_adc_completion_owner_match == 1'b0) || (i_transaction_start_valid == 1'b1 && ((i_transaction_frame_type == FRAME_TYPE_AMB) || (i_transaction_frame_type == FRAME_TYPE_DCS)) && flag_calibration_start_match == 1'b0) || (flag_startup_request_source == 1'b1 && flag_recheck_request_source == 1'b1))begin
1935: 			flag_integration_blocking <= 1'b1;
1936: 		end
1937: 	end
```

### L1940：flag_run_context_ended

```text
1940: 	always@(posedge i_clk or negedge i_rstn)begin
1941: 		if(i_rstn == 1'b0)begin
1942: 			flag_run_context_ended <= 1'b1;
1943: 		end else if(i_start_ack_event == 1'b1)begin
1944: 			flag_run_context_ended <= 1'b0;
1945: 		end else if(i_stop_ack_event == 1'b1)begin
1946: 			flag_run_context_ended <= 1'b1;
1947: 		end
1948: 	end
```

### L1951：reg_result_fork_payload

```text
1951: 	always@(posedge i_clk or negedge i_rstn)begin
1952: 		if(i_rstn == 1'b0)begin
1953: 			reg_result_fork_payload <= {FORK_PAYLOAD_WIDTH{1'b0}};
1954: 		end else if(i_start_ack_event == 1'b1 || (i_control_abort_event == 1'b1 && o_measurement_output_idle == 1'b1))begin
1955: 			reg_result_fork_payload <= {FORK_PAYLOAD_WIDTH{1'b0}};
1956: 		end else if(flag_dc_result_transfer == 1'b1)begin
1957: 			reg_result_fork_payload <= enc_dc_result_payload;
1958: 		end
1959: 	end
```

### L1962：flag_detection_pending

```text
1962: 	always@(posedge i_clk or negedge i_rstn)begin
1963: 		if(i_rstn == 1'b0)begin
1964: 			flag_detection_pending <= 1'b0;
1965: 		end else if(flag_result_abort_discard == 1'b1)begin
1966: 			flag_detection_pending <= 1'b0;
1967: 		end else if(flag_dc_result_transfer == 1'b1 && normal_output_inhibit_o == 1'b0)begin
1968: 			flag_detection_pending <= 1'b1;
1969: 		end else if(flag_detection_transfer == 1'b1)begin
1970: 			flag_detection_pending <= 1'b0;
1971: 		end
1972: 	end
```

### L1976：flag_detection_branch_sample_valid

```text
1976: 	always@(posedge i_clk or negedge i_rstn)begin
1977: 		if(i_rstn == 1'b0)begin
1978: 			flag_detection_branch_sample_valid <= 1'b0;
1979: 		end else if(flag_result_abort_discard == 1'b1)begin
1980: 			flag_detection_branch_sample_valid <= 1'b0;
1981: 		end else if(flag_dc_result_transfer == 1'b1)begin
1982: 			flag_detection_branch_sample_valid <= !flag_test_invalid_sample_fire;
1983: 		end else if(flag_detection_transfer == 1'b1)begin
1984: 			flag_detection_branch_sample_valid <= 1'b0;
1985: 		end
1986: 	end
```

### L1989：flag_measurement_pending

```text
1989: 	always@(posedge i_clk or negedge i_rstn)begin
1990: 		if(i_rstn == 1'b0)begin
1991: 			flag_measurement_pending <= 1'b0;
1992: 		end else if(flag_result_abort_discard == 1'b1)begin
1993: 			flag_measurement_pending <= 1'b0;
1994: 		end else if(flag_dc_result_transfer == 1'b1 && normal_output_inhibit_o == 1'b0)begin
1995: 			flag_measurement_pending <= 1'b1;
1996: 		end else if(flag_measurement_transfer == 1'b1)begin
1997: 			flag_measurement_pending <= 1'b0;
1998: 		end
1999: 	end
```

### L2002：flag_abort_draining

```text
2002: 	always@(posedge i_clk or negedge i_rstn)begin
2003: 		if(i_rstn == 1'b0)begin
2004: 			flag_abort_draining <= 1'b0;
2005: 		end else if(i_start_ack_event == 1'b1)begin
2006: 			flag_abort_draining <= 1'b0;
2007: 		end else if(i_control_abort_event == 1'b1)begin
2008: 			flag_abort_draining <= 1'b1;
2009: 		end else if(o_adc_chain_idle == 1'b1 && o_normal_fork_idle == 1'b1 && o_measurement_output_idle == 1'b1)begin
2010: 			flag_abort_draining <= 1'b0;
2011: 		end
2012: 	end
```

### L2015：flag_calibration_request_inflight

```text
2015: 	always@(posedge i_clk or negedge i_rstn)begin
2016: 		if(i_rstn == 1'b0)begin
2017: 			flag_calibration_request_inflight <= 1'b0;
2018: 		end else if(i_stop_ack_event == 1'b1 || i_control_abort_event == 1'b1 || flag_integration_blocking == 1'b1)begin
2019: 			flag_calibration_request_inflight <= 1'b0;
2020: 		end else if(flag_amb_sample_accepted == 1'b1 || flag_dcs_sample_accepted == 1'b1 || flag_calibration_request_withdraw == 1'b1)begin
2021: 			flag_calibration_request_inflight <= 1'b0;
2022: 		end else if(calibration_request_fire_o == 1'b1)begin
2023: 			flag_calibration_request_inflight <= 1'b1;
2024: 		end
2025: 	end
```

### L2028：reg_inflight_color_ir

```text
2028: 	always@(posedge i_clk or negedge i_rstn)begin
2029: 		if(i_rstn == 1'b0)begin
2030: 			reg_inflight_color_ir <= 1'b0;
2031: 		end else if(calibration_request_fire_o == 1'b1)begin
2032: 			reg_inflight_color_ir <= calibration_color_ir_o;
2033: 		end
2034: 	end
```

### L2037：reg_inflight_frame_type

```text
2037: 	always@(posedge i_clk or negedge i_rstn)begin
2038: 		if(i_rstn == 1'b0)begin
2039: 			reg_inflight_frame_type <= FRAME_TYPE_AMB;
2040: 		end else if(calibration_request_fire_o == 1'b1)begin
2041: 			reg_inflight_frame_type <= calibration_frame_type_o;
2042: 		end
2043: 	end
```

### L2046：reg_inflight_reason

```text
2046: 	always@(posedge i_clk or negedge i_rstn)begin
2047: 		if(i_rstn == 1'b0)begin
2048: 			reg_inflight_reason <= REASON_STARTUP;
2049: 		end else if(calibration_request_fire_o == 1'b1)begin
2050: 			reg_inflight_reason <= calibration_request_reason_o;
2051: 		end
2052: 	end
```

### L2057：flag_stop_result_draining

```text
2057: 	always@(posedge i_clk or negedge i_rstn)begin
2058: 		if(i_rstn == 1'b0)begin
2059: 			flag_stop_result_draining <= 1'b0;
2060: 		end else if(i_start_ack_event == 1'b1)begin
2061: 			flag_stop_result_draining <= 1'b0;
2062: 		end else if(i_stop_ack_event == 1'b1)begin
2063: 			flag_stop_result_draining <= 1'b1;
2064: 		end
2065: 	end
```

### T-AMI-08：lane03错配完成的上游可达性收窄

后续逐路核对：正常S1由同一个fire锁存metadata，保护identity注入在flag_adc_completion_normal_emit中被显式屏蔽，随后受控abort又重放原身份。因此不能用注入错配证明V1-AMI-04的C且!owner_match。该条件下next-cycle身份失效的RTL推导成立，但需要真实可达的metadata/precision错配来源，或明确将内部状态故障列入验证范围；本次未证明生产可达，最终列待定，不计新增已确认系统缺陷。

## 最终文末汇总

(c)：V1-AMI-01～03（中）；V1-AMI-04是防御条件下的身份保留缺口，正常metadata链和保护注入尚未证明可达，按T-AMI-08保留待定。待定：T-AMI-01～08。
