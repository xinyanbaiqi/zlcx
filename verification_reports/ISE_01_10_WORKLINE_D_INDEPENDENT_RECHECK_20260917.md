# ISE-01~10 IDAC快照/Epoch/总线隔离验收ID独立复核——工作线D新批次5（家族：ISE）

> 方法声明：不信任`tb_ppg_control_top_idac_bus_isolation.v`自己的changelog或
> `PPG_ALIAS_MAPPING_TABLE.md`既有映射，全部当作"待验证的声称"。复核方法：(1)从
> `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.7（640-653行，ISE-01~10
> 逐条verbatim英文acceptance requirement）取原文，(2)逐段读真实断言代码块（含
> `flag_check_ise_snapshot_bus`门控的连续监视进程本身，不是只看主序列调用点），
> (3)特别核对合同原文枚举的多维度清单（如ISE-01的"code, color, type, precision,
> epoch"五项）是否每一项都有对应检查，不是只测其中最显眼的一项。
>
> **状态：ISE-01~10全部10项完成断言级复核**。结论：**1个真实缺口（ISE-01）+2个次要
> 观察（ISE-02/10，不计入缺口数）+9项CONFIRMED**。这份文件同样质量很高——ISE-10自己
> 的changelog记录了一次真实xsim confirmed的构造bug（第一版照抄校准搜索的等待信号模式，
> 但NORMAL跟踪阶段根本不经过那个信号，导致零次真实commit，之后改用已验证手法修复）；
> `flag_check_ise_snapshot_bus`门控的连续监视进程设计也说明了为什么不用逐拍相等断言
> （避免总线间隙产生误报），是经过真实推敲的方案。ISE-01的缺口与批次3 SID-06是同一个
> 模式的第二次出现，两份独立文件、同一类"合同枚举多维度、TB只测其中数值码"的疏漏，
> 说明这可能是跨越这个RTL集群共同的一种系统性遗漏，值得后续批次继续留意。

## 真实缺口：ISE-01——合同要求"code、color、type、precision、epoch"五项均需捕获时点证据，TB只验证了code

**合同原文**（§9.4.7，644行）："AMB/DC code, color, type, precision, and epochs are
captured before the first preparation window of each waveform."

**TB实际实现**（1053-1260行区间，AMB/DC_R/DC_IR三个阶段共用同一套机制）：在每个候选
的准备窗口开启前（`o_amb_sample_request`/`o_dcs_sample_request`刚出现时）锁存
`reg_ise_snapshot_expect_ambn`/`reg_ise_snapshot_expect_dcn`两个8-bit码值
（1075/1079-1080/1144-1146/1213行附近），随后由`flag_check_ise_snapshot_bus`门控的
连续监视进程（801-817行）latch窗口期间总线上出现过的非零值，窗口关闭后一次性核对
latch到的值是否等于准备窗口前的快照——这个机制扎实地验证了**AMB/DC码**这两项"准备
窗口之前已捕获"，但合同原文明确列出的另外三项——**color、type、precision**——在这套
快照机制里完全没有对应的捕获时点验证；**epoch**虽然在其它检查里（如ISE-10）被读取过，
但读取的是"当前epoch数值是否正确递增"，不是"epoch是否在准备窗口之前就已经锁定、不会
被窗口内的后续事件扰动"这个capture-timing性质的问题。

**与批次3 SID-06的模式关联**：这是这次工作线D复核第二次遇到同一种缺口形态——合同
条款枚举了"候选/码/颜色/类型/epoch"这一组身份字段要求"准备前锁定"，TB只针对其中的
数值码做了真实验证，颜色/类型/精度/epoch这几个身份维度的捕获时点从未被独立测试过。
两份文件（SID的
`tb_ppg_control_top_startup_idac_calibration.v`、ISE的
`tb_ppg_control_top_idac_bus_isolation.v`）彼此独立编写，出现同一种遗漏模式，值得
后续批次（尤其是同一RTL集群下的其它家族）留意是否也有同样的遗漏。

## 次要观察（不计入缺口，置信度较低或严重度较小，供参考）

- **ISE-02**（同ISE-01共用机制）：合同"Changing any live code after capture cannot
  change a current IDAC bus bit, **enable, LED window, or result snapshot**"——本文件
  的快照机制验证了"总线本身在窗口内保持快照值"（间接说明码没有被live-change），但没有
  主动构造一个"窗口内真的尝试改一次码"的场景，并核对EN_TEST/LED窗口/结果快照是否受到
  扰动——测的是"码没变"这个前提是否成立，不是"如果码被人为改了，enable/LED/result这些
  下游信号是否被隔离"这个更直接的应急场景。
- **ISE-10**（1394-1427行）：合同"remains correctly bound to all later waveform and
  result snapshots"这半句——TB只确认了回绕事件本身真实发生（epoch从4'hF变为4'h0），
  没有继续验证回绕之后紧接着的下一次waveform/result快照是否正确携带了新epoch（0），
  而不是某种残留的旧值。

## CONFIRMED项说明（9/10，含ISE-01/02/10自身的核心半句）

- **ISE-03**（1076-1117行）：用真实safe-boundary-change检测（`flag_ise03_seen_real_
  change`）确认下一候选窗口只在真实码变化发生之后才采用新码，非猜测/非时间巧合。
- **ISE-04/05**（775-963行）：SAR9/SAR15两条总线在对方阶段保持零 + 非对称8-bit模式
  （A5/3C与5A/C3）在真实Q3窗口内逐位核对，两个精度方向各自独立验证。
- **ISE-06**（1002-1006/1118/1185/1252行）：STATIC_BIAS四总线归零、AMB_CAL只驱动AMB
  候选总线（DC归零）、DCS_CAL总线携带已确认AMB+当前DC候选，三个子句各自独立验证，
  不是笼统一句带过。
- **ISE-07**（877/934行注释明示）：与ISE-04/05共用同一组非对称模式（A5/3C为第一个、
  5A/C3为第二个），满足"至少两个非对称模式证明逐位门控"的合同要求，是合法的共享覆盖，
  非缺口。
- **ISE-08**（1133-1186/1213-1253行）：DC_R搜索期间DC_IR码/epoch冻结（前半）+DC_IR
  搜索期间DC_R码/epoch冻结（后半），两个方向都有独立场景，不是只测单向。
- **ISE-09**（1355-1381行）：连续6次窗口内中性值驱动确认无数值变化的安全边界不产生
  update/track-adjust/epoch递增。
- **ISE-01/02核心（码值本身）**：如上所述，AMB/DC码"准备前锁定+窗口内保持"这个核心
  性质本身验证扎实，缺口只在于合同枚举的另外三个身份维度未覆盖。
- **ISE-10核心（回绕事件本身）**：宽范围单方向持续驱动真实凑够跨越4'hF->4'h0的回绕，
  避免了第一版窄范围振荡在边界卡死的真实构造陷阱（changelog记录）。

## 完整复核表（10/10全部完成）

| ID | 场景（文件行号） | 结论 |
| --- | --- | --- |
| ISE-01 | 1053-1260（三阶段共用快照机制） | **真实缺口**——仅覆盖code，color/type/precision未测 |
| ISE-02 | 同上 | CONFIRMED（enable/LED/result隔离为次要观察） |
| ISE-03 | 1076-1117 | CONFIRMED |
| ISE-04 | 775-909 | CONFIRMED |
| ISE-05 | 784-963 | CONFIRMED |
| ISE-06 | 1002-1006/1118/1185/1252 | CONFIRMED |
| ISE-07 | 877/934（共享ISE-04/05证据） | CONFIRMED |
| ISE-08 | 1133-1186/1213-1253 | CONFIRMED |
| ISE-09 | 1355-1381 | CONFIRMED |
| ISE-10 | 1394-1427 | CONFIRMED（回绕后绑定持续性为次要观察） |

## 与今日工作线B回归的交叉核对

`tb_ppg_control_top_idac_bus_isolation.v`今日回归通过，与本次独立复核读到的断言代码
一致；本报告的1个缺口指合同枚举范围比TB实际验证范围更宽，不影响现有PASS结论。

## 批次5小结：SID+TRK+ISE集群（共32项）全部完成

至此，共享`ppg_idac_code_controller.v`/`ppg_400hz_frame_calibration_scheduler.v`两个
RTL锚点文件的SID(12)+TRK(10)+ISE(10)三个家族全部完成工作线D独立复核，共9个真实缺口
（SID 4+TRK 1+ISE 1，另加SID/ISE各自的多个次要观察）。三份TB文件工程质量普遍较高
（均有真实自捕获构造期bug的changelog记录），缺口集中在"合同枚举多维度、TB只测最显眼
的一项"（SID-06/ISE-01同型）和"合同要求主动故障注入、TB做了被动/结果性检查"（TRK-01、
SID-03/04/05的部分表现）这两类模式，供后续批次参考排查同类问题。
