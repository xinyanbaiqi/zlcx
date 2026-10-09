# V1 独立同拍冲突审查：SSW

固定基线 `a1ba482d35f5d5d211ba86a5b73c91c99740eaca`；RTL：`rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v`。以下行号全部属于该基线。使用仓库 erie-verilog-generator analyze/formatter AST；只读静态复核，无仿真/综合声明，未访问被隔离的审查分支/目录。依据C09，B交接§3、生命周期/F009明确用户裁定。2 MHz、5000/625拍及模拟侧9/15位SAR、DONE保持、2–20拍延迟为本审查前提。

## 1. 上游追踪与事件定义

Top L1006–1011扇入manager START/STOP、独立注册abort/diag和scheduler tick；L1050–1054接AMI唯一完成/作废/序号/物理idle。scheduler固定NORMAL RED/IR接管点0/160、CAL local0（FSC L453–455），owner候选CAL>RED>IR（L463–465），唯一期望提交来自FSC的`valid && AMI ready`（L473）。SSW ready独立产生，owner身份逐字段比对（SSW L428–431），commit/error在L434–435分为成功/失败互补；release需已有owner且同序号、同代际（L436）。

R=owner release；O=owner commit fire；A=abort；S=`flag_start_restore`（START && !owner && ADC idle，L449）；Wc=某槽context fire；Lc=某槽wave_last；F=首次blocking故障；D=diag && wrapper idle。所有寄存器异步reset优先，依据C09复位规则；输入电平reset和事件可同时高，属于(b)，不是(a)。

START/STOP由manager状态与命令冲突排除同拍（manager L451–464）；START/abort及diag/新错误**没有该排除**，Top L328–360的寄存网相互独立。O/R在构造上(a)：O要求!owner，R要求owner。O/A(a)：L434含!abort。R/A可同拍(b)，匹配释放应优先，不能仅因abort保留一个已完成owner。

## 2. 全部对象的条件顺序和同拍处置

| 对象及always起点 | 全部顺序（reset省写但最高） | 条件对与结论 |
|---|---|---|
| adc_owner_inflight_o L521 | R清 > A保持 > O置1 > 保持 | R/A(b)，SSW-22/C09释放旧owner；O/R、O/A(a)，上述直接谓词；STOP不清owner(b)，等待真实DONE/作废 |
| reg_owner_q3_closed_o L534 | R清 > O清 > OR当前Q3已过组合资格 | R/Q3到期可同拍(b)，释放后清；O/R(a)；Q3累计不受tick回0影响(b)，保留跨帧释放资格 |
| calibration_timeout_sticky_o L547 | S清 > 内部 D清；随后CAL local385且has_owner置1 | D/置位(a)，has_owner使wrapper idle=0；S/置位(a)，S要求!owner；R/local385可同拍时旧has_owner仍1，见T-SSW-01 |
| owner_deadline_timeout_sticky_o L563 | S清 > 内部D清；随后red/ir/cal timeout置1 | D/timeout(a)，timeout需context_valid而idle需三个context0；S/timeout可在未提交残留context且旧tick=deadline+1成立，S清(b)，新RUN丢弃旧诊断，F009 L-6/C09 START规则；多timeout同拍均置1(b) |
| switch_protocol_error_sticky_o L579、transaction_mismatch_sticky_o L595 | S清 > 内部D清；随后新switch_error/done_mismatch置1 | D/新错配可同拍(b)，新置位胜出；S/新错配可同拍，S覆盖新故障，且fault_valid却仍由F产生，见T-SSW-02；合法生产输入不存在无owner完成，但边界防御仍须测试 |
| reg_control_vector L612 | A清 > reg_control_next装载 | abort与static/任意波形可同拍(b)，寄存清零优先；组合static分支虽在abort前选择，但注册输出被A清，不形成输出脉冲；reset同理 |
| reg_run_active L783 | S置1 > (!RUN或stop_pending)&&idle 清 > 保持 | S/idle清可同拍(b)，新RUN优先；S/A可能同拍而A不直接影响该寄存器，见T-SSW-02；STOP时已有wave/owner继续安全收尾(b) |
| flag_stop_pending L796 | A置1 > STOP置1 > (!run_active&&idle)清 > S清 | A/STOP(b)，同值；STOP/idle清(b)，取消优先；S/idle清(b)，同值；S/A可同拍，stop=1、run_active=1组合如何恢复见T-SSW-02 |
| flag_cal_context_valid L956、flag_ir_context_valid L1104、flag_red_context_valid L1291 | A清 > S清 > 内部Lc清；随后Wc置1 | A/Wc(a)，Wc在L410含!A；S/Wc生产(a)：START前FSC旧STARTED=0，正常无wavevalid；Lc/Wc(a)，RED接管0与last307/317、IR160与467/477、CAL0与283直接相反；A/S(b)，都清context；STOP不立即清context(b)，F009既定预建立排空语义 |
| 各CAL/IR/RED载荷寄存器（详见覆盖附录） | A保持 > Wc装载；reset各初值 | A/Wc(a)，fire门控；RED/IR/CAL W两两(a)，NORMAL/CAL由同一FSC frame_mode解码互斥，RED/IR同时需tick0/160矛盾；S不清载荷但清valid(b)，F009 L-6允许下次整体覆盖；STOP/Wc生产(a)，FSC的wavevalid含同拍STOP/!RUN门控 |
| reg_owner_abort_seen L1309 | R清 > A且owner置1 > O清 | R/A(b)，旧owner完成胜出；O/A、O/R(a)；STOP不设置abort_seen(b)，已提交owner安全波形继续，结果由AMI discard控制 |
| owner sample_index/generation/frame_id/color/type/precision/slot L1324等 | A保持 > R保持 > O装载 | R/A(b)，均保持原身份；O/A、O/R(a)；同一O选择RED>IR>CAL，CAL/NORMAL互斥，IR候选明文!red_window（L425–427），不能跳过RED |
| reg_owner_cal_subframe L1363 | O装载；其余保持 | A/O、R/O(a)，构造门控同上；STOP不改子帧身份(b)，匹配late CAL owner须保持 |
| flag_ssw_fault_valid L1431 | F置1 > 默认0 | F与S/D可能同拍；valid无恢复门控，见T-SSW-02；同一阻断episode F由!blocking限定，连续level错误在置sticky后不再新发(b) |
| flag_ssw_fault_identity_valid L1442 | S清 > 内部D清；随后F按commit_error > done_mismatch&&owner > 无身份装载 | D/F可同拍(b)，新故障胜出；S/F可同拍则idvalid清而valid1，见T-SSW-02；两错误同拍时commit_error身份优先，C09未给同源身份仲裁，T-SSW-03 |
| reg_ssw_fault_frame_id/sample_index/color/type/precision/generation L1464–1529 | F：commit_error取候选身份 > done_mismatch且owner取原身份；reset清，其余保持 | 所有字段同谓词、同顺序(b)，没有部分字段混装；新fault与owner释放，done_mismatch与合法release(a)，L435/436；无身份时公共输出归零（L511–516），内部旧字段保持(b) |

## 3. 组合控制字逐字段冲突矩阵（always L624）

全部控制字段：EN_TIA、LED_CODE/LED_DATA、LED_R/IR、EN_TEST、CLK_BUF、IREF_IDAC、Q1_9/15、AFERST、IREF_9/15、Q2/Q3、TIAEN、EN_15、EN_9_AMB/DC/IREF、EN_15_AMB/DC/IREF、AMB9/DC9/AMB15/DC15、S_IN。默认全0 → STATIC_BIAS或动态分支 → 动态中RED段 → IR段 → CAL段。CTRL编号按L252–283定义，无重叠切片。

| 组合条件对/字段 | 可同拍证明、覆盖方式和处置 |
|---|---|
| static/动态 | (a) if/else；static与任何wave即使残留并存，也只执行static。abort注册优先清输出 (b) |
| RED/IR包络 | **可同拍**：正常双光各在0/160成功锁存，context有效至307/317与467/477，SAR9共同活动[204,318)，SAR15[187,308)。不依赖owner释放。C09 §4.5明确IR接管不等RED owner。不能以一ADC owner断言两个包络互斥 |
| IREF_IDAC（RED/IR） | L642及L690均OR前值；两独立IDAC窗口[263,303)/[423,463)或[246,306)/[406,466)，并集(b)，无额外重叠 |
| IREF_9/15 | 同精度双方只写1；SAR9得到[44,478)并集，SAR15相应并集(b)，符合C09 §4.6白名单 |
| EN_15_IREF/AMB/DC | RED先写，IR L695–700 OR前值；包络重叠可同拍，白名单允许并集(b)，C09 §4.6；DC在NORMAL资格下开启 |
| EN_9_IREF/AMB/DC | IR L707–710 **直接赋值**，覆盖RED L657–660，(c)，V1-SSW-01 |
| AMB/DC码总线（各精度、两色） | 每段逐bit OR旧值（L651–664、L701–714）。精度一致由FSC每帧冻结、SSW接管比对当前committed保证；9位RED码窗[258,310)/[266,310)，IR[418,470)/[426,470)，15位RED[203,308)/[151,308)，IR[363,468)/[311,468)，**有效码窗两两不重叠**(a)，因此OR不会合成两个不同码。另精度的片段默认0。不能把“包络可重叠”误当码窗可重叠 |
| EN_TIA/AFERST/TIAEN/Q2/Q3（两色owner段） | RED先写，IR多数OR；TIAEN回读EN_TIA。单一owner slot导致has_owner_RED/IR两两(a)，即使两个wave包络同时高，也只有一个owner段执行；双方在固定采样区间相距160拍，不出现额外脉冲(b) |
| Q1_9/15、EN_15（两色owner段） | IR直接覆盖但两has_owner不能同拍(a)，同一reg_owner_slot编码；release/O也不能同拍。提前DONE会截断原owner资格，应做T-SSW-04；不能由“else最后覆盖”独自报缺陷 |
| LED_R/IR、LED_CODE/DATA | 两has_owner(a)；固定两色LED窗也不交集(a)。PD模式输出锁存LEDDAC，固定电流!input_source=0使LED关闭(b)。CAL仅DCS且owner时写二选一颜色；AMB无LED(b) |
| CAL/RED、CAL/IR | 在生产连接(a)：FSC两模式同一状态片段互斥；normal context最迟477清，比宏帧4999早4522拍；CAL最迟local283清，比624边界早342拍；下一帧没有旧活动context。abort清三个valid，新START按L-6清。对异常跳tick或非法双模式输入不作互斥声明，作为T-SSW-05。若异常三段同时执行，CAL直接覆盖共享字段及码总线，必须由协议保护阻断 |
| EN_TEST、CLK_BUF、S_IN | static/动态(a)；EN_TEST动态固定current标志一次写，CLK_BUF/S_IN动态默认0。static的四组码总线从未置位(b)，C09 §8.5 |

## 4. (c) 发现

### V1-SSW-01：双光SAR9的IR包络清掉RED三个建立使能（高）

在正常双光SAR9帧，RED上下文tick0、IR上下文tick160接管。L411/412给RED/IR活动包络[44,318)和[204,478)，同时高的区间为[204,318)。L657设RED EN_9_IREF窗[236,308)，L658/659设RED EN_9_AMB/DC窗[256,310)。后执行的IR段L689、L707–710分别赋IR窗[396,468)、[416,470)；在整个RED有效使能窗这些谓词全为0，覆盖RED的1。

因此实际公共输出丢失RED IREF使能72拍（36 µs）及RED AMB/DC使能54拍（27 µs）。reg_control_vector在L618注册，所以以上是**组合输入tick窗口**；输出对采样沿注册，波形比较应使用与RTL寄存延迟一致的坐标，不把下一拍显示误报成新的off-by-one。受影响输出在L478–480映射到控制片段；码总线仍按RED窗输出，不能以码总线正常推断模拟使能正常。

C09 §4.6仅允许IREF_9跨色连续保持，其他SAR9使能须保留各自独立颜色窗口；“不许重叠”不意味着后色包络可以删掉前色窗口。模拟设计者确认这些窗口即需求，不能把它降格成内部注释不一致。该反例无需任何异常DONE、反压、非法参数或测试注入，影响每个成功接管IR的双光SAR9帧。SAR15的相同三字段L695–700采用OR而保留RED。这里只报告缺陷，不提供或应用RTL补丁。

## 5. 待定项

| ID | 场景、需要的仿真 |
|---|---|
| T-SSW-01 | CAL匹配release恰在local385：旧has_owner仍1，L556置迟到sticky，虽然同拍完成释放。扫描384/385/386，明确合同“tick385仍未完成”是否包含该采样沿已完成；B §3.5只规定诊断不终止burst，没有给该同拍判据 |
| T-SSW-02 | START与外部注册abort、START与异常DONE/非法波形同拍。S不含!abort，新run_active置1而stop_pending置1，valid故障可能1、cause/sticky/idvalid0。生产正常START/旧owner互斥已追manager empty，但独立abort未互斥。全链扫描±2拍，验证取消优先及记录原子性，不能强制manager同时发START/STOP |
| T-SSW-03 | 非法commit与错配DONE同拍，六fault字段统一取commit候选。证明协议错误输出稳定并评估C24首故障身份需要；生产正确连接不产生非法commit，属于防御性测试 |
| T-SSW-04 | 按设计者2–20拍转换延迟，DONE/CLK_DOUT出现在Q3结束前、同拍、之后，owner release会移除has_owner并截断尾部Q1/AFE/TIA资格。C09完整网表窗和真实模拟完成前提是否一致，应联测ADC两精度并逐tick比对；不将Q3门控当成物理owner不得释放的理由 |
| T-SSW-05 | 跳tick、非法双frame_active、CAL旧context与NORMAL新context。明确协议检测后下一拍输出安全与abort时延。生产自然递增下的互斥证据不能外推到故障输入 |

## 6. 覆盖清单

formatter AST识别64个always：63个时序块及1个组合块。全部已逐行覆盖：L521、534、547、563、579、595、612、624、783、796；CAL载荷L813、826、839、852、865、878、891、904、917、930、943和valid L956；IR载荷L974、987、1000、1013、1026、1039、1052、1065、1078、1091和valid L1104；RED载荷L1122、1135、1148、1161、1174、1187、1226、1239、1252、1265、1278和valid L1291；IR/CAL generation L1200/1213；owner L1309、1324、1337、1350、1363、1372、1385、1398、1411；fault L1431、1442、1464、1477、1490、1503、1516、1529。

载荷寄存器完整名单：每色 `reg_{red,ir,cal}_{amb_code,amb_epoch,dc_code,dc_epoch,frame_id,frame_type,input_source,leddac_code,optical_mode,precision,generation}`，CAL另有`reg_cal_color_ir`；三valid；owner `adc_owner_inflight_o, reg_owner_{q3_closed_o,abort_seen,sample_index,generation,frame_id,cal_subframe,color_ir,frame_type,precision_mode,slot}`；四sticky；run/stop；control_next/vector；fault valid/identity_valid和六字段。组合所有CTRL字段见§3，无只检查寄存器而跳过组合覆盖。

接受的旧合同差异：L-6 START清未提交残留context、作废新增release、local385超时只诊断不撤销burst，按B §3.5–3.7处理；不当成新增缺陷。

## 7. 文末汇总

(c)：V1-SSW-01（高，正常双光SAR9共享使能被覆盖）。待定：T-SSW-01～05。主发现有静态逐tick反例；尚无本次运行的模拟或系统仿真证据。
