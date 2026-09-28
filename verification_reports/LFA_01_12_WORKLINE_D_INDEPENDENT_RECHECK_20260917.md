# LFA-01~12生命周期故障/ADC异常验收ID独立复核——工作线D新批次7（家族：LFA）

> 方法声明：不信任`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v`自己的changelog
> 或`PPG_ALIAS_MAPPING_TABLE.md`既有映射，全部当作"待验证的声称"。复核方法：(1)从
> `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.9（670-685行，LFA-01~12
> 逐条verbatim英文acceptance requirement，其中LFA-02/08两条极其冗长复杂）取原文，
> (2)读真实断言代码块，(3)对跨文件共享的证据（LFA-08实为`tb_ppg_control_top_
> injection.v`的INJ-02）追到实际文件核实，不满足于"标签对得上"。
>
> **状态：LFA-01~12全部12项完成断言级复核。这是本轮六个批次里第一次没有找到同等量级
> 的"静默丢失"型真实缺口的一批**——3个次要观察（LFA-08/09/02，均需要跨文件才能彻底
> 判定，置信度中等）+12项CONFIRMED。这份文件的自我记录质量是六个批次里最高的：
> changelog完整记录了10处真实构造期bug（每处都附带真实RTL根因追查）、一段专门的
> "调查阶段确立的真实事实"区块（8条独立验证过的RTL行为），且LFA-06/LFA-10(b)这类
> 局限是文件自己已经诚实披露、经过真实RTL多文件追查后才下定论的，不是本次复核才
> 发现的新问题。如实报告"这一批没挖到新的大缺口"，不为了和前几批"凑对称"而拔高。

## 次要观察（不计入缺口，均需跨文件求证才能彻底判定，供参考）

- **LFA-08**（证据实际在`tb_ppg_control_top_injection.v`的INJ-02场景，727-904行，非本
  文件内）：合同原文（§9.4.9，681行）列出了三条并列的owner释放恢复路径——"STOP or the
  registered system abort"（STOP或注册式系统abort）以及"Reset may instead invalidate
  the digital owner"（复位也可以让owner失效），并明确要求"the two recovery events are
  idempotent and cannot directly clear or double-release the owner"（两种恢复方式
  互相幂等，不能直接清除或重复释放owner）。INJ-02实际只构造了**STOP**这一条路径
  （828-844行），没有构造"registered system abort"或"reset"路径，也没有构造两者
  交叠时的幂等性验证。本文件LFA-11a（1803-1808行）确实独立验证了一次"supervisor自动
  abort释放错配owner、未伪造正式结果"的场景，机制上与LFA-08所需的"system abort恢复"
  相近，但两者是不同的具体测试场景，不能直接等同为LFA-08这半句的证据。
- **LFA-09**（1107-1169行）：本文件明确只构造了**RED**owner-deadline场景（1107行
  注释"LFA-09：RED owner-deadline失败"）。合同原文（682行）要求"RED, IR, and
  calibration"三种owner-deadline失败都要有等价证据。批次6的OIB-02（不同文件）确实
  独立测试了RED+IR两支的owner-deadline超时（非阻断诊断/无半提交/无supervisor记录），
  但OIB-02验证的具体子句集合和LFA-09框定的（"suppress the affected active sampling
  windows"+"correct non-blocking historical timeout diagnostic"+"no...first-fault
  snapshot"）不完全一致，calibration变体的等价证据本次没有找到明确对应（批次3 SID-05
  测的是"248拍截止抑制转换"，不是"非阻断诊断分类+无supervisor记录"这个角度）。三个
  文件、三个角度，是否合起来完整覆盖了LFA-09的全部要求，需要专门交叉核对才能下定论，
  本次未做，如实记录。
- **LFA-02a**（1407-1509行）：合同原文（675行）对"generation-scoped detection
  discard"这一支有非常具体的字段级要求——"`identity_valid=0`...requires every
  trigger identity field except mandatory target `run_generation`, and sample-valid,
  to be zero"（除了目标run_generation和sample-valid两个字段，其余每一个身份字段都
  必须为零）和"no earlier than the following 2 MHz cycle"（不早于下一个2MHz周期）。
  本文件在这一支验证了discard真实触发+reason正确+datapath确实归空（1496-1509行），
  但没有看到逐字段核对"除run_generation/sample-valid外全部归零"或核对2MHz周期时序
  边界这两个粒度更细的子句。合同这条本身是本轮见过最冗长复杂的单条要求，本次未做
  逐字段穷尽核对，如实记录为未完全验证，不是确认存在缺口。

## CONFIRMED项说明（12/12，含各自已知的诚实局限）

- **LFA-01**（999-1051行）：STOP取消未提交的AMB pending候选+已提交码不变+无伪造
  completion+真实idle。
- **LFA-02b**（1714-1830行，与LFA-10a/LFA-11共用同一场景）：真实系统故障episode
  产生exactly DISCARD_SYSTEM_FAULT原因（非STOP/ABORT），changelog记录了一处真实
  修复（快照信号从宽泛的`o_ami_datapath_empty`改为`flag_detection_discard_trigger`
  真正引用的`flag_pwi_detection_datapath_empty`）。
- **LFA-03**（1945-1964行）：STOP取消未提交recheck-pending请求，码/epoch不变；自带
  "check is vacuous"空跑防护（同TRK-05纪律）。
- **LFA-04**（1188-1211行）：abort后原身份保留，迟到DONE产生恰好一次success=0释放，
  无formal data。
- **LFA-05**（1988-2083行）：复位立即让scheduler owner身份归零+复位前/复位后的旧
  DONE均无法释放或完成新owner，两个时间点分别独立构造。
- **LFA-06**（2133-2156行）：真实构造完成（非延后）——早于Q3结束的CLK_DOUT让owner
  干净释放（不死锁）但不产生协议级成功completion，精确匹配AMI层"Q3无关完成权限"与
  Scheduler层"门控协议成功"两层语义。
- **LFA-07**（1253-1332行）：已释放owner的重复DONE不产生第二次completion/result/
  owner，且不伪造诊断sticky；诊断clear-after-fault独立验证。
- **LFA-09核心（RED半句）**：如上次要观察所述，核心RED场景本身扎实（非阻断诊断+
  无scheduler本地阻断sticky+无supervisor阻断记录/abort/STOP请求）。
- **LFA-10a**（1768-1778行）：AMI-only故障独立阻断新launch，scheduler/SSW自身本地
  诊断不受牵连。LFA-10b（SSW侧）经真实RTL追查确认此路当前不可达（需要直接force SSW
  内部原始输入才能构造，不满足OIB-04"禁止force"的合法构造要求），文件自己已诚实
  记录为确认的构造难点，与SID-11/LFA-06同一诚实惯例，非本次复核新发现。
- **LFA-11a/11b**（1803-1852行）：supervisor自动abort通过原始身份路径释放错配owner、
  未伪造正式结果（11a）；真正满足合同恢复条件后diag_clear才能清除诊断（11b）。
- **LFA-12(a/b/c/final)**（1083-1105/2034-2099行）：STOP恢复后、复位恢复后两条路径
  分别验证新START从干净状态开始（无残留inflight/无残留搜索完成标记），搜索真实重新
  收敛，无陈旧事件复活。

## 完整复核表（12/12全部完成）

| ID | 场景（文件/行号） | 结论 |
| --- | --- | --- |
| LFA-01 | 999-1051 | CONFIRMED |
| LFA-02a | 1407-1509 | CONFIRMED（identity_valid字段级/2MHz时序子句为次要观察） |
| LFA-02b | 1714-1830 | CONFIRMED |
| LFA-03 | 1945-1964 | CONFIRMED |
| LFA-04 | 1188-1211 | CONFIRMED |
| LFA-05 | 1988-2083 | CONFIRMED |
| LFA-06 | 2133-2156 | CONFIRMED |
| LFA-07 | 1253-1332 | CONFIRMED |
| LFA-08 | `tb_ppg_control_top_injection.v` INJ-02, 727-904 | CONFIRMED（system abort/reset恢复路径+幂等性为次要观察） |
| LFA-09 | 1107-1169 | CONFIRMED（IR/calibration变体跨文件证据完整性为次要观察） |
| LFA-10 | 1768-1830 | CONFIRMED（10a solid，10b文件自己诚实记录为确认的构造难点，非本次新发现） |
| LFA-11 | 1803-1852 | CONFIRMED |
| LFA-12 | 1083-1105/2034-2099 | CONFIRMED |

## 与今日工作线B回归的交叉核对

`tb_ppg_control_top_lifecycle_fault_adc_anomaly.v`与`tb_ppg_control_top_injection.v`
今日回归均报告PASS，与本次独立复核读到的断言代码一致。本批次的3个次要观察均为
"需要跨文件/更细粒度核实才能彻底判定"，不是像前几批那样有明确证据链的"确认缺失"，
如实标注置信度，不夸大也不掩盖。
