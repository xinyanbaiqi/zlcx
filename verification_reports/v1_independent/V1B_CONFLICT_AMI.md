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

### V1-AMI-04：错配完成释放AMI owner与故障pending同沿，次拍fault身份失效（中；防御路径）

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

(c)：V1-AMI-01（中，STOP同拍成功旁带）；V1-AMI-02（中，diag覆盖新错误）；V1-AMI-03（中，同拍system/abort原因覆盖）；V1-AMI-04（中，错配完成与故障身份保留冲突，防御路径系统可达性待测）。待定：T-AMI-01～07。这里的静态反例和历史报告中的仿真证据分开陈述，没有宣称本次运行验证闭合。
