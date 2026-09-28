# TOP-01~24 顶层验收ID独立复核——工作线D批次1（已完成）

> 方法声明：本文档不信任`PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md`第10节下方
> 2026-09-02/2026-09-05 Priority-1b核对表的任何"CLOSED"结论、别名表映射或matrix文字，
> 把它们全部当作"待验证的声称"。复核方法：(1)从C01合同第10节原文取每条ID的验收要求，
> (2)独立定位真实TB场景并完整读断言代码块本身（不是只读`$display`标签或场景注释——
> 这是本次反复踩到的关键教训，好几个真实缺口都是"comment写着有检查，代码里其实没有"
> 这个模式），(3)必要时反查RTL实现，(4)与2026-09-16当天刚重跑（工作线B）的新鲜xsim
> 证据交叉核对。
>
> **状态：24项全部完成断言级复核**。结论：**5个真实开放缺口**（TOP-01/02/09/15/18）+
> **1个历史缺口，确认已在早于09-02核对之前就修复关闭**（TOP-20）+**18项CONFIRMED**（含
> 1项自曝窄覆盖TOP-24、2项字面措辞略强于实测方法但非真实缺陷TOP-05/07/21）。
>
> **2026-09-17更新：本页记录的5个真实开放缺口已全部补上真实TB证据（用户决定要修，非
> 静默处理），详见完整报告`ppg_system_integration/TOP01_24_GAP_REMEDIATION_20260917.md`
> 与`PPG_ALIAS_MAPPING_TABLE.md`对应5行的追加说明。本页原文保留不改，作为独立复核当时
> 真实状态的历史记录；下方逐条缺口描述仍然是准确的"补之前"状态说明，不代表现状。**

## 真实缺口1：TOP-01——"SSW为安全向量""无旧事务恢复"两个子句零TB证据

要求原文三个子句："复位｜无事务valid；SSW为安全向量；无旧事务恢复"。

现有证据（`tb_ppg_control_top.v` SMOKE-01，1115-1123行）只检查`o_lifecycle_state==ST_CONFIG`
且四个ack/error事件全0，只覆盖第一个子句。

- **"SSW为安全向量"**：项目全部`*.v`搜"安全向量"/"safe vector"/"SAFE_VECTOR"零命中；
  SSW唯一对外可观测输出`o_s_in`（`ppg_control_top.v:478`）只在SMOKE-19（STATIC_BIAS场景，
  COMMIT之后）被检查过，复位后、COMMIT前该是什么值，全项目没有断言过。
- **"无旧事务恢复"**：全项目仅两处`i_rstn=1'b0`，都是场景最开头的上电复位（谈不上"旧
  事务"），没有一份TB做过"RUN期间有真实在途事务时触发复位"。

## 真实缺口2：TOP-02——"V4/V5均合法才替换"这个具体claim没有专属负向测试

`ppg_system_config_manager.v:436-448`独立确认：`flag_snapshot_valid`是**多个独立子字段
校验位的AND**（含V5专属的`flag_snapshot_v5_reserved_valid`/`flag_snapshot_v5_range_valid`，
与其余字段并列），任一为0则整份1024-bit快照被原子拒绝（`dec_error_code`按472-474行有
专属`ERROR_V5_SCHEMA_RESERVED`/`ERROR_V5_FIELD_RANGE`区分）——**RTL结构上"一方非法"确实
是可区分、可测试的真实状态，不是伪命题**。但全项目grep"V4/V5其中一方非法"相关措辞
（"V4.*illegal"/"V5.*illegal"/"一方非法"等）零命中：现有SMOKE-02只测了"两方都合法→
成功、epoch恰好递增一次"这一条正向路径，没有测过"一方非法→整体拒绝、epoch不变"。

## 真实缺口3：TOP-09——"正式结果按显式discard事件完成"在自己的证据场景里只是DIAG打印

证据场景SMOKE-05/06/07/08（STOP/abort/校准窗口停止）逐一确认：全部只检查`stop_ack`
超时、drain-to-CONFIG超时、`o_system_fault_blocking`三项。`o_measurement_result_discard_event`
在这四个场景里唯一一次出现是`tb_ppg_control_top.v:1350`的`$display("DIAG...")`调试打印，
不是PASS/FAIL判据。该信号真正被断言的地方在`tb_ppg_control_top_injection.v`的后台计数器
里，但那是TOP-22（LFA-08身份错配）的证据链，不是TOP-09自己的。

"排空到CONFIG且无故障残留"是活性检查，"排空是经由显式discard事件完成的"是机制检查，
两者不是同一件事（同类区分见SPI诊断快照撕裂memory：时序余量解决得了到达时间，解决
不了原子性）。

## 真实缺口4：TOP-15——"ADC结果事务严格单笔在途"子句无任何断言

SMOKE-14自己的注释承诺验证"B_INFLIGHT与B_INFLIGHT不重入"，但实际代码（1960-1981行）
只检查"RED和IR各自≥3次真实事务发生"，完全没有引用`B_INFLIGHT`。全项目grep确认没有
任何专属的"single-in-flight重入"后台监视进程（不同于TOP-17确实有的常驻fanout monitor）。

## 真实缺口5：TOP-18——STATIC_BIAS负向半句承诺但从未真正写出来

SMOKE-11（TOP-18正向部分，1689-1700行）自己的注释明确写"STATIC_BIAS下两者应强制为0
的反向部分，留到Tier 3做STATIC_BIAS场景时一并验证"（Tier 3即SMOKE-19）。全文件
`grep "run_enable"`只有4处命中，全部在SMOKE-11自己的1689-1700行区间，SMOKE-19
（2422-2565行，真正的STATIC_BIAS场景）区间内零命中。承诺过的验证从未落地。

## 历史缺口（确认已关闭，非开放项）：TOP-20

`tb_ppg_control_top.v` V1.2 changelog（08-24，早于09-02核对）记录scheduler接收端资格
检查曾经缺失（`i_run_profile`声明未引用）。独立查当前RTL：
`ppg_400hz_frame_calibration_scheduler.v:423,426`已有`@satisfies: TOP-20`标签+真实
门控逻辑（`flag_calibration_request_valid`直接AND进`calibration_sample_ready_o`），
同日V1.7 changelog记录修复过程，`tb_ppg_400hz_frame_calibration_scheduler.v`
FSC-58/59两条专属负向测试真实存在（非法run_profile/input_source各一条，700拍监视
ready从未置位+owner/波形均为0+protocol_error_sticky置位）。**教训复用**：TB自己的
changelog描述的是撰写时的DUT状态，必须查当前RTL——[[feedback_verify_stale_findings_against_current_rtl]]
同类模式再次出现，这次是"缺口在核对表写CLOSED之前就已经被修复"，方向和以往几次
"记录说已修复其实还没修"相反。

## 完整复核表（24/24全部深度）

| ID | 场景 | 结论 |
| --- | --- | --- |
| TOP-01 | SMOKE-01 | **真实缺口**（见上） |
| TOP-02 | SMOKE-02/03 + `ppg_system_config_manager.v` | **真实缺口**（见上） |
| TOP-03 | SMOKE-23（2761-2866行，全帧内/跨帧一致性+Q3相位固定，四子句全覆盖） | CONFIRMED |
| TOP-04 | SMOKE-15（2022-2083行，Q3 tick 260-272范围+AMB快照8-240合法范围） | CONFIRMED |
| TOP-05 | SMOKE-17（2206-2283行，owner独立推进+held-result零静默丢弃+释放后即时消费） | CONFIRMED（"不共用单一fire"措辞未逐字覆盖，非功能性缺陷） |
| TOP-06 | SMOKE-16协议半句（2124-2165行，scheduler/SSW/AMI精度三方一致）+`tb_ppg_control_top_fir_tail_isolation.v` GROUP4动态触发半句（历史已有详细真实dual-tool数字，本次未重新逐行读代码，仅交叉核对今日workline B新鲜PASS） | CONFIRMED |
| TOP-07 | SMOKE-18（2324-2414行，EN_TEST/LEDEN/LEDDAC边界含运行期间连续监视+RED/IR持续产生） | CONFIRMED（"400Hz间歇"具体频率未专门量测，非功能性缺陷） |
| TOP-08/12 | SMOKE-19（2422-2565行，静态向量匹配+S[4:0]匹配+零owner提交+SSW/AMI/scheduler idle 4000拍+运行期更新跟随） | CONFIRMED |
| TOP-09 | SMOKE-05/06/07/08 | **真实缺口**（见上） |
| TOP-10 | 静态结构检查（非TB） | CONFIRMED（独立grep零实例化+独立iverilog -Wall elaborate 0 error） |
| TOP-11 | `tb_ppg_control_top_startup_idac_calibration.v` SID-01（852/857行） | CONFIRMED |
| TOP-13 | SMOKE-12（1738-1800行，帧计数+零IR+AMB/DC_R码不漂移+owner真实释放） | CONFIRMED |
| TOP-14 | SMOKE-13（1835-1940行，同SMOKE-12结构+运行期间逐拍连续监视精度不跌出SAR15） | CONFIRMED |
| TOP-15 | SMOKE-14 | **真实缺口**（见上） |
| TOP-16 | SMOKE-09（1541-1621行） | CONFIRMED |
| TOP-17 | SMOKE-10 + 常驻fanout monitor（1047-1057行，5路`i_adc_idle`/`i_adc_physical_idle`逐位比较） | CONFIRMED |
| TOP-18 | SMOKE-11 + SMOKE-19（应含负向，实际没有） | **真实缺口**（见上） |
| TOP-19 | SMOKE-20（2565-2579行，commit拒绝+error_event+精确错误码8'h14三重校验） | CONFIRMED |
| TOP-20 | SMOKE-21/22 + `ppg_400hz_frame_calibration_scheduler.v` FSC-58/59 | CONFIRMED（历史缺口已关闭，见上） |
| TOP-21 | INJ-01（677-704行，injection-ready=0+事务正常完成） | CONFIRMED（"逐位一致V1.3.4基线"措辞比实测的功能等价检查更强，非真实缺陷） |
| TOP-22 | INJ-02/LFA-08（727-904行，mismatch保留+sticky+fault传播+STOP触发单次释放+diag清零+后续事务干净） | CONFIRMED（构建期真实发现并修复AMI V1.12一处永久死锁） |
| TOP-23 | INJ-03/PRC-08（909-960行，invalid-ready+正式结果存在+sample_valid=0+identity/value字段非X三重校验） | CONFIRMED |
| TOP-24 | INJ-04（992-1018行，仅覆盖双请求同时到达→两路ready全0+真实事务不受影响） | PARTIAL——自曝窄覆盖：文件V1.0 changelog已写明"remaining rules are a known coverage gap, not silently assumed to pass"，requirement原文"运行中改绑/重复abort完成/组合环/禁止force和fork-ready改写"等子句零断言覆盖，但这是已知已披露的窄覆盖，不是本次新发现的隐藏缺口 |

## 汇总

- **5个真实开放缺口**（TOP-01/02/09/15/18）：全部是"RTL可能没问题，但claim的这一半
  没有真实TB断言证据"模式，不是发现RTL功能性bug。是否补测试留给用户决定——调查本身
  已经做完，剩下的是修不修的产品决定（[[project-ppg-fix-dont-defer]]）。
- **1个历史缺口**（TOP-20）：确认在09-02核对表写CLOSED之前就已经真实修复，不是被
  掩盖的开放项。
- **18项CONFIRMED**：有真实、具体、信号级的断言证据，不是空标签。
