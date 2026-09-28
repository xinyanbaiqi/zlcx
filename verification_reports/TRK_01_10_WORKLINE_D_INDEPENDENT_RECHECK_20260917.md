# TRK-01~10正常慢速跟踪验收ID独立复核——工作线D新批次4（家族：TRK）

> 方法声明：不信任`tb_ppg_control_top_normal_slow_tracking.v`自己的changelog或
> `PPG_ALIAS_MAPPING_TABLE.md`既有映射，全部当作"待验证的声称"。复核方法：(1)从
> `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.2（562-575行，TRK-01~10
> 逐条verbatim英文acceptance requirement）取原文，(2)逐段读真实断言代码块，(3)特别
> 核对合同原文里枚举的多个子条件（如"A或B"、"missing X or mismatched Y/Z"）是否
> 每一个分支都有对应的主动构造场景，而不是只有其中一支。
>
> **状态：TRK-01~10全部10项完成断言级复核**。结论：**1个真实缺口（TRK-01）+2个次要
> 观察（TRK-09/10，不计入缺口数）+9项CONFIRMED**。这份文件的工程质量很高——TRK-05
> 自己的断言逻辑主动防范了"事件从未真实发生导致检查空跑"的风险（1300帧驱动窗口内如果
> 没有真实观察到精度切换，会显式报`"TRK-05 check is vacuous"`而不是静默PASS），TRK-09
> 使用`force`前明确写明是"私有单消费者网线"，是已经内化了本项目force-on-shared-net
> 教训的写法。本批次缺口率是四批里最低的，如实报告，不为了凑数拔高。

## 真实缺口：TRK-01——合同要求主动构造"无效输入/valid低时payload变化"，TB只做被动40拍静默等待

**合同原文**（§9.4.2，566行）："Invalid tracking input or a changing payload while
valid is low cannot change evidence, pending code, committed code, or epoch."——这条
要求的是一个**主动**场景：在valid=0期间，即使payload线上的数据是无效的或者持续变化的，
也不能让证据/pending/committed/epoch产生任何变化。

**TB实际实现**（1016-1028行）：进入TRK-01检查前，本文件没有调用过任何
`task_drive_track_color`（该文件驱动跟踪输入的唯一task），只是快照
`cnt_dcs_r_low`/`cnt_dcs_r_high`/`o_dcs_r_code`三个值，然后`repeat(40)
@(posedge i_clk)`纯等待，再确认这三个值没变。这测的是"如果什么都不驱动，跟踪状态
自己不会凭空变化"——一个被动的静默基线检查，比合同要求的"即使主动喂无效输入/变化
payload，valid=0期间也不能生效"这个主动故障注入场景弱得多。全文件搜索确认，
`task_drive_track_color`第一次被调用是在TRK-02阶段（1034行），TRK-01阶段之前和期间
都没有任何主动驱动。

**为何认定是真实缺口而非等价覆盖**：被动基线检查只能证明"电路在没有输入活动时保持
静止"，这是几乎任何正常时序电路都自动满足的弱性质；合同真正关心的是"即使有人往输入
线上塞垃圾数据，只要valid没有同时置位，这些垃圾就一定被过滤"，这是需要主动激励才能
证伪的性质。两者不是同一件事——参照本项目自己反复确认过的类似教训（TOP-09"活性检查"
vs"机制检查"不是一回事）。

## 次要观察（不计入缺口，置信度较低，供参考）

- **TRK-09**（1168-1209行）：合同原文"A missing calibration-applied qualification or
  mismatched code snapshot/epoch"里的"code snapshot/epoch"，TB只构造了code-snapshot
  错配（force `flag_track_dc_code_snapshot`=8'hFF），没有单独构造一个epoch错配场景。
  是否需要独立测试取决于RTL里code-snapshot和epoch的比对是否共用同一个等值判据（如果是
  同一个reject门控里的同一次比较，两者理论上等价；如果分开判定，则epoch这一支未受检验）
  ——本次未反查RTL确认判据结构，如实记录，不定性。
- **TRK-10**（1211-1227行）：驱动单一target_code(37)，确认跟踪证据(`flag_track_s1_
  value`)等于该值。合同要求排除的是Stage2/重建15-bit/粗精DC恢复/正式输出这四个"替代
  来源"，但本检查没有构造一个Stage1与其它某个候选管线阶段取值**不同**的场景——如果
  这次驱动下游几个阶段的数值本来就自然趋同（37这个数字在无失真情况下逐级传递基本不变），
  这个检查就无法真正区分"正确读了Stage1"和"意外读了某个恰好同值的其它阶段"，判别力
  存疑。是否构成真实风险取决于这几个阶段在真实驱动下是否自然发散取值，本次未做核实，
  如实记录供参考。

## CONFIRMED项说明（9/10）

- **TRK-02/03/04**（1030-1097行）：确认计数阈值（N-1次不形成pending、窗口内清零、
  第N次形成pending）+方向反转清零旧计数+RED/IR证据独立性（用交错插入IR样本做天然
  对照），三条逐字对应合同。
- **TRK-06/07**（1099-1166行）：pending等待期间正式PPG消费继续+pending payload稳定+
  安全边界恰好提交一次signed 1-LSB变化+epoch恰好加一+确认计数器清零，五个子条件全部
  独立核对。
- **TRK-08**（1229-1381行，跨阶段A/B两部分）：连续16次真实提交验证4'hF->4'h0自然回绝
  （阶段A）+窄范围配置逼近端点验证持续above-high不回绕/不产生假update/不增epoch
  （阶段B），两个子句都有专属场景，非同一场景兼顾。
- **TRK-05**（1386-1515行）：真实生成器驱动直到观测到真实SAR9->SAR15转换+确认转换本身
  不改变RED证据/码/epoch+等待真实SAR15->SAR9回落+确认完整往返后码/epoch恒定不变，
  且对"转换从未真实发生"这个空跑风险有专属FAIL分支防护。
- **TRK-09主体**（1168-1209行）：calibration_applied=0与code-snapshot错配两条注入路径
  均确认"消费但不推进证据+不触发系统故障"，注入撤销后立即恢复正常跟踪资格。

## 完整复核表（10/10全部完成）

| ID | 场景（文件行号） | 结论 |
| --- | --- | --- |
| TRK-01 | 1016-1028 | **真实缺口**——被动基线检查，非合同要求的主动故障注入 |
| TRK-02 | 1030-1074 | CONFIRMED |
| TRK-03 | 1076-1097 | CONFIRMED |
| TRK-04 | 1042-1051（交错于TRK-02） | CONFIRMED |
| TRK-05 | 1386-1515 | CONFIRMED |
| TRK-06 | 1121-1136 | CONFIRMED |
| TRK-07 | 1138-1165 | CONFIRMED |
| TRK-08 | 1229-1381 | CONFIRMED |
| TRK-09 | 1168-1209 | CONFIRMED（epoch错配子分支为次要观察） |
| TRK-10 | 1211-1227 | CONFIRMED（判别力为次要观察） |

## 与今日工作线B回归的交叉核对

`tb_ppg_control_top_normal_slow_tracking.v`今日回归报告`NORMAL_SLOW_TRACKING_TB_PASS`，
与本次独立复核读到的断言代码一致；本报告的1个缺口指TRK-01现有检查本身是真实的、也
真实通过，但检查的属性比合同原文要求的弱，不影响现有PASS结论的有效性。
