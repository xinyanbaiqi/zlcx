# P01-P17 + N01-N08 工作线D独立复核（2026-09-28）

> 延续`K_D01_GFP_WORKLINE_D_INDEPENDENT_RECHECK_20260928.md`同一对话框、同一天的后续工作。
> 范围：`HANDOFF_20260928.md`点名的"工作线D剩余约41个ID"中最后一批P(17)+N(8)=25项。
> 至此工作线D原方案11个家族全部至少过了一遍独立复核：259(此前)+16(NRE/ADCN)+16(K/D01/
> G-FP)+25(本批次)=316。

## 方法论说明——与K/D01/G-FP不同

这25项在`PPG_CONTRACT_CLOSURE_MATRIX.md`§11里全部有真实TB场景引用，且已经过Phase 3
穷尽核对(2026-09-06)+开放项批次1-4(2026-09-06~09-08)的多轮真实debug——不是K/D01/G-FP
那种"无TB场景、只能读静态声明"的证据形态。因此本轮复核方式换回NRE/ADCN那套"读TB断言
代码本身是否真完整覆盖合同要求"，而不是读静态声明。**这批底子明显比NRE/ADCN更扎实**：
matrix原文自带大量诚实的"残留缺口"批注（如N04"scheduler/SSW两条腿未单独隔离，只是从
共享net推断"、N06"'幂等性'不是靠专门的连续两次episode测试，是从K02的开合设计架构推断"、
P10"不逐条穷尽每个hex码，只证明blocking/non-blocking两个类"），这些自曝的边界经本轮
逐条核对后确认仍然准确——不是脚本误报，也没有被静默"修复"掉。

## 结论汇总：25项全部CONFIRMED，1处真实TB覆盖缺口已发现并修复

### 逐项复核记录

| ID | 复核方式 | 结果 |
| --- | --- | --- |
| P01 | 实读`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v`两个facet的完整断言代码（Facet1身份逐字段比对、Facet2真实同拍ready/abort race） | **CONFIRMED**，构造质量极高（正确同拍竞争、discard reason+identity+cnt_result_capture三重核对） |
| P02 | grep确认`@satisfies: P02, N01`标签仍在`ppg_adc_measurement_idac_integration.v:970`，语义（无条件广播+下一拍empty）与标签描述一致 | **CONFIRMED** |
| P03 | 实读supervisor unit TB SUP01A/SUP06B(`o_system_stop_request_event`断言)+Top侧`ppg_control_top.v:375`三路STOP合并(`i_stop_event \|\| supervisor_system_stop_request_event_o \|\| flag_abort_drain_stop_request`) | **CONFIRMED**，两个citation都实读到真实代码，行号未漂移 |
| P04 | 实读supervisor unit TB SUP01A（8字段原子快照同时核对） | **CONFIRMED** |
| P05 | 实读supervisor unit TB SUP06B/C（缩短阈值8拍的看门狗超时+恢复） | **CONFIRMED**，缩短阈值是合法的参数化验证技巧，未改变逻辑本身 |
| P06 | 实读`tb_ppg_control_top_injection.v:785-789`——**发现该文件自己的V1.1 changelog写"20 cycles"，与同一文件的真实断言代码"2 cycles"自相矛盾**；已修正changelog措辞，不动断言/RTL | **CONFIRMED**（含1处changelog文字修复，见下） |
| P07 | =LFA-08=TOP-22，TOP-22已在工作线D批次1(TOP-01~24,20260916)的18个CONFIRMED之列 | **CONFIRMED（传递）** |
| P08 | grep确认`@satisfies: P08, LFA-04, OIB-08`标签仍在`ppg_adc_measurement_idac_integration.v:1496`，语义（owner身份绑定,三终止路径）与标签描述一致 | **CONFIRMED** |
| P09 | 实读supervisor unit TB SUP02A(首故障快照不被覆盖)/SUP03A(诊断清除在episode内无效)/SUP04A/B(discard与blocking诊断分离) | **CONFIRMED** |
| P10 | 实读supervisor unit TB SUP02A(cause 8'h01)+SUP06B(cause 8'h31看门狗)+SUP04A/B(discard非blocking类) | **CONFIRMED**，narrative自陈"不逐hex码穷尽,只证明两大类"的范围界定本身准确 |
| P11 | =TOP-21~24改写，四者均在批次1的18个CONFIRMED之列 | **CONFIRMED（传递）** |
| P12 | 静态/合同定义完整性证据，同TOP-10证据类别；底层G-FP-05参数传播台账本对话框当天早些时候(K/D01/G-FP批次)已亲自重新核实过`ppg_control_top.v:1099-1106`8参数透传+`ppg_adc_measurement_idac_integration.v:2446-2461`15参数透传 | **CONFIRMED** |
| P13 | 实读`ppg_normal_transaction_fork`自己的unit TB FFK-02(双分支独立存储)/FFK-03/04(对称单分支反压+独立释放,两种顺序都测)/FFK-06(5拍持续反压) | **CONFIRMED**，四条用例组合对称、覆盖两种消费顺序，构造质量高 |
| P14 | grep确认`@satisfies: P14, LFA-04, OIB-08`标签仍在`ppg_adc_measurement_idac_integration.v:1226`，语义（原identity exactly-once success=0释放）与标签描述一致 | **CONFIRMED** |
| P15 | grep确认`@satisfies: P15`标签仍在`ppg_control_top.v:1394`（supervisor端口台账代表行） | **CONFIRMED** |
| P16 | 合同文字定义完整性证据（C25§7.1/9.3-9.5），同TOP-10证据类别，未重新展开（低风险纯文本项） | **CONFIRMED（沿用既有论证）** |
| P17 | =TOP-17改写，TOP-17在批次1的18个CONFIRMED之列 | **CONFIRMED（传递）** |
| N01 | 实读`tb_ppg_control_top_baseline_cross.v:1498-1558`——真实轮询下游检测代际非空(非vacuous)+STOP+discard reason核对+**PWI四个子消费者(FIR/baseline/peak-valley/precision)逐一断言settle到local-empty**(1551-1558) | **CONFIRMED**，四消费者逐一核对是真正扎实的构造 |
| N02 | 与K04共享完全相同的RTL机制（`ppg_system_config_manager.v:533`唯一generation producer）；本对话框当天K/D01/G-FP批次已对这条机制做过完整独立结构核实 | **CONFIRMED（复用同日K04复核证据）** |
| N03 | 实读supervisor unit TB SUP02B——AMI/Scheduler/SSW三路同一negedge真实同时到达，确认cause/source/frame_id均来自AMI(优先级最高)且三路summary bit(1/3/5)全部置位 | **CONFIRMED**，真实同拍三方竞争构造扎实 |
| N04 | 实读`tb_ppg_control_top_injection.v`+`tb_ppg_control_top.v`的`i_diag_clear_event`真实用例（SMOKE-20→21/22→23之间的W1C sticky清除，下游场景的PASS本身即证明该fanout工作，否则下游会FAIL）；**narrative自陈"scheduler/SSW两条腿未被单独隔离断言"这条残留缺口，本轮核实后仍准确，未发现新的专属断言** | **CONFIRMED（含仍然准确的已知残留缺口，不算新发现）** |
| N05 | Top半（`flag_test_inject_mode_latched`）与AMI半的机制在本轮阅读`tb_ppg_control_top_injection.v`changelog时得到间接印证（该文件多处场景本身依赖这个锁存正确工作才能成立），未独立重新展开SID-10/11 | **CONFIRMED（间接印证，未重新精读SID-10/11）** |
| N06 | 实读supervisor unit TB全部12个既有case——**发现真实TB覆盖缺口：SUP02B虽验证了第二个episode的快照仲裁，但check时机（pulse后2拍才check）结构性错过trio脉冲窗口，K02/N06"后续episode依然完整发一次trio"这条声明此前从未被任何仿真动态验证过，只有本对话框当天早些时候对K02做的RTL结构性阅读支持** | **发现真实缺口，已修复（见下）** |
| N07 | 与P16同证据类别（C25§7.1complementary obligation定义），未重新展开 | **CONFIRMED（沿用既有论证）** |
| N08 | 实读`ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v:1575-1620`N08-01完整断言——**发现一处测试健壮性观察**：`flag_n08_fir_busy_observed`（FIR真实忙碌）只做`$display`诊断打印，未编入`check_case`的硬性PASS/FAIL条件，真正硬性门控的是`flag_n08_window_hit`；构造本身确实是为命中FIR忙碌态设计的，当前不是vacuous pass，但如果未来pipeline时序改变导致命中窗口消失，这条测试不会FAIL、只会静默打印一行未被检查的DIAG | **CONFIRMED，含1处已记录未修复的观察项（见下）** |

## 已执行的修复

### 1. 真实TB覆盖缺口修复：N06/K02"后续episode独立于首故障历史"

[`tb_ppg_system_fault_abort_supervisor.v`](../ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v)
新增`SUP10A`：在既有12个case全部跑完、episode已彻底关闭+诊断清除之后，再触发一个全新
episode（不同cause/frame_id/sample_index，与之前所有快照区分），直接检查abort/STOP/
丢弃三事件与新快照，证明"episode开合独立于首故障快照历史"这条声明的"后续episode"那一半
不再只靠RTL结构性阅读支持，而是有真实仿真动态证据。

验证：
- iverilog编译+运行：`SUP-01 through SUP-10 PASS: 14 real comparisons`，0 FAIL，清洁`$finish`
- 真实Vivado 2022.2 xsim（xvlog+xelab+xsim）独立重跑：结果逐行一致，14/14 PASS
- deliverable gate对整个模块目录扫描发现16处`COMMENT_COMMENT_PLACEMENT`，逐条核对确认
  全部落在本次新增代码块之外（都是文件原有task端口声明等2026-08-23就存在的历史内容），
  与本次改动无关，不在本次范围内处理
- 单文件TB修复（不碰RTL、不碰共享TB文件），按既定标准不触发全套19-TB重跑

### 2. 文字性修复：P06 changelog数字纠错

[`tb_ppg_control_top_injection.v`](../ppg_control_top/tb_ppg_control_top_injection.v)第22行
自己的V1.1 changelog原写"deassert ... for 20 cycles"，与同一文件真实断言代码（785-789行，
真实核对的是2拍窗口）以及矩阵原文本身的"2-cycle window"描述相矛盾——是changelog自己的
数字错误，不是断言或RTL问题。已订正为"2-cycle window"并追加订正说明。纯注释改动，未
触碰任何断言逻辑或RTL，不影响仿真结果。

## 观察到但未处理的次要项（如实记录，非本轮范围）

- **N08-01的FIR忙碌诊断未硬性门控**（见上表N08行）——不建议现在顺手加严：这条诊断本身
  依赖精确的pipeline时序窗口，草率改成硬性FAIL条件有把测试变脆弱（未来良性时序调整就
  意外FAIL）的风险，是否值得为这条边缘情况加固，留给用户判断，不在本轮擅自决定。
- N04的"scheduler/SSW两条腿未单独隔离"、N05的"未独立重新精读SID-10/11"——均为本轮核实
  范围内的既有诚实披露事项，未发现使其失真的新证据，也未新增独立断言去补强，如实沿用。

## 与"工作线D剩余41个ID"的关系

本批次完成后，`HANDOFF_20260928.md`点名的工作线D剩余41个ID（D01(4)+G-FP(7)+K(5)+N(8)+
P(17)）**全部完成独立复核**：D01/G-FP/K共16项见`K_D01_GFP_WORKLINE_D_INDEPENDENT_
RECHECK_20260928.md`，N/P共25项见本文档。工作线D原方案11个家族累计316项均至少过了
一遍独立复核方法论，真实发现并修复的缺口：NRE/ADCN批次2处、K/D01/G-FP批次2处（含1处
真实标签缺口）、本批次2处（1处真实TB覆盖缺口+1处文字纠错）。
