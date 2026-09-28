# PRC-01~10鲁棒性边角波形验收ID独立复核——工作线D新批次8（家族：PRC）

> 方法声明：不信任`tb_ppg_control_top_robustness_corner_waveforms.v`自己的注释或
> `PPG_ALIAS_MAPPING_TABLE.md`既有映射，全部当作"待验证的声称"。复核方法：(1)从
> `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.10（687-700行，PRC-01~10
> 逐条verbatim英文acceptance requirement）取原文，(2)读真实断言代码块，(3)特别注意
> 合同原文里"A或B"双分支结构（如"either...or..."、"...or the contracted timeout/
> reacquire behavior"）是否两支都有对应场景，还是只测了看似更直接的那一支，(4)对跨
> 文件引用的证据（PRC-05→RGC-06、PRC-08→INJ-03）追到实际文件核实。
>
> **状态：PRC-01~10全部10项完成断言级复核**。结论：**2个真实缺口（PRC-04/06）+3个
> 次要观察（PRC-02/07/08，均是"合同双分支只测了一支"的同类模式）+5项CONFIRMED**。
> PRC-09/10这次意外读到一处真实的项目级发现：构造这两项时确认现有RTL不存在合法路径
> 单独触发一笔样本的calibration-loss资格丢失，与SID-11/LFA-06/OIB-01/LFA-10(b)同类，
> 已经通过新增一个默认关闭的验证专用注入端口（`ppg_coarse_detection_fir.v` V2.3新增
> `i_test_calibration_loss_inject_valid`）解决，是诚实记录、真实修复的又一个案例。

## 真实缺口1：PRC-04——用"无阻断sticky"当"无算术回绕/无假方向反转"的代理，两者不是一回事

**合同原文**（§9.4.10，694行）："Strong bounded baseline drift follows the
dynamic-baseline contract **without arithmetic wrap, false direction reversal, or
identity loss**."——三个并列的失效模式：算术回绕、假方向反转、身份丢失。

**TB实际实现**（1111-1124行）：唯一判据是
`o_error_sticky || o_scheduler_protocol_error_sticky || o_ami_integration_protocol_
error_sticky`——检查的是"有没有阻断类协议错误sticky置位"，把这当成"identity loss
symptom"（识别为身份丢失症状）的代理指标。但"算术回绕"（基线数值本身在动态基线追踪
算法内部越界折返）和"假方向反转"（漂移方向被误判翻转）都是纯数值/算法层面的性质，
不必然会触发任何协议错误sticky——一次真实的回绕bug完全可能悄悄产生一个数值错误的
基线，而不触发任何fault标志。TB测的是"故障标志有没有响"，合同要求的是"这三种具体的
数值/逻辑错误有没有发生"，两者不是同一件事（同类区分参照TOP-09"活性检查非机制检查"
的既有教训）。

## 真实缺口2：PRC-06——只测了合法边界的快/慢周期，合同后半句"非法周期的timeout/reacquire行为"完全没测

**合同原文**（696行）："Fast and slow legal pulse periods satisfy configured
peak/valley interval checks; **out-of-range periods follow timeout/reacquire
behavior without false acceptance**."——两个分句：合法快慢周期通过间隔检查（已测，
见下CONFIRMED），非法（超出范围）周期必须走timeout/reacquire路径、不能被错误接受
（未测）。

**TB实际实现**：全文件只有PRC-06a（FAST_PERIOD，1126-1139行）和PRC-06b
（SLOW_PERIOD，1141-1154行）两个场景，分别验证快、慢两个**合法**边界周期各自产生
真实重复的peak/valley序列。全文件搜索确认没有任何场景驱动一个真正**超出合法范围**
的周期（比如比合法快周期更快、或比合法慢周期更慢），也没有验证这种非法周期是否
correctly被timeout/reacquire路径拒绝、而不是被静默接受成一次假阳性peak/valley。

## 次要观察（不计入缺口，均为"合同双分支只测一支"同类模式，置信度中等，供参考）

- **PRC-02**（1075-1088行）：合同"remains in SAR9 **or** follows the contracted
  no-cross/reacquire policy without a fabricated fine window"——TB判据是
  `flag_precision_mode_ever_high && (reg_cross_count==0)`才FAIL，这只是"如果进了
  SAR15，必须真的记录过至少一次cross"这个**必要条件**，不是"进入SAR15这条路径本身
  是否严格遵循了合同规定的no-cross/reacquire具体策略"的**充分验证**。是否需要更
  精细的核对取决于"contracted no-cross/reacquire policy"在FIR/PWC合同里具体如何
  定义，本次未展开查证。
- **PRC-07**（1156-1169行）：合同"either产生fully qualified valley，or走timeout/
  reacquire路径，never是unqualified SAR9 return"——TB只驱动了一种profile
  （WEAK_NOTCH），验证它落在"produced qualified valley"这一支。"missing"切迹
  （比WEAK更极端、理应触发timeout/reacquire那一支的场景）没有对应测试，这一支
  合同允许的替代结果路径完全没有场景覆盖。
- **PRC-08**（证据实际在`tb_ppg_control_top_injection.v`的INJ-03，909-985行）：合同
  原文列出了一份很长的"不得推进"清单——"cannot advance **FIR history/count/full
  qualification, dynamic-baseline cycle evidence, peak/valley confirmation, or
  precision control**"。INJ-03验证了`sample_valid=0`到达正式边界+身份/数值字段完整+
  后续合法样本恢复`sample_valid=1`，但没有见到对FIR历史/计数/动态基线周期证据/峰谷
  确认/精度控制这几项具体下游状态的直接核对——测的是"这笔注入样本本身被正确标记为
  无效"，不是"这笔无效样本没有偷偷推进下游算法状态"，是两个相关但不同的问题（与
  批次6 OIB-06"单笔自证不等于跨流的重复/换色检测"是同一种区分）。

## CONFIRMED项说明（5/10）

- **PRC-01**（1052-1072行）：FLAT profile零false cross/peak/valley/精度切换，四项
  独立核对。
- **PRC-03**（1090-1109行）：饱和诊断真实置位（非vacuous，`check is vacuous`分支
  证明作者主动防范空跑）+饱和窗口零qualified违规计数。
- **PRC-06合法半句**：快/慢两个合法边界周期各自产生真实重复peak/valley序列，判据
  扎实（详见上方"真实缺口2"对非法半句的说明，合法半句本身没有问题）。
- **PRC-09/10**（1194-1257行）：新增专属注入端口（真实RTL新增，非TB取巧）真实构造
  calibration-loss资格丢失，验证真实污染了若干拍覆盖窗口后资格genuinely恢复
  （PRC-09）+样本序/身份序全程零违规（PRC-10）；构造前有明确的两条独立证据链确认
  "现有RTL无合法路径可测"，新端口是必要的，不是抄近路。
- **PRC-05引用**：`tb_ppg_real_raw_generator_selfcheck.v`RGC-06真实证据（2026-08-29
  重跑），噪声有界+1000次重复帧逐位一致，两色均覆盖，引用准确。

## 完整复核表（10/10全部完成）

| ID | 场景（文件/行号） | 结论 |
| --- | --- | --- |
| PRC-01 | 1052-1072 | CONFIRMED |
| PRC-02 | 1075-1088 | CONFIRMED（"契约策略"精细核对为次要观察） |
| PRC-03 | 1090-1109 | CONFIRMED |
| PRC-04 | 1111-1124 | **真实缺口**——用sticky缺失代理算术回绕/方向反转 |
| PRC-05 | `tb_ppg_real_raw_generator_selfcheck.v` RGC-06 | CONFIRMED（引用准确） |
| PRC-06 | 1126-1154 | **真实缺口**——非法周期timeout/reacquire半句零覆盖 |
| PRC-07 | 1156-1169 | CONFIRMED（timeout/reacquire替代支为次要观察） |
| PRC-08 | `tb_ppg_control_top_injection.v` INJ-03, 909-985 | CONFIRMED（下游状态不推进清单为次要观察） |
| PRC-09 | 1194-1246 | CONFIRMED |
| PRC-10 | 1247-1252 | CONFIRMED |

## 与今日工作线B回归的交叉核对

`tb_ppg_control_top_robustness_corner_waveforms.v`与`tb_ppg_control_top_injection.v`
今日回归均PASS，与本次独立复核读到的断言代码一致；本报告的2个缺口指合同要求的检查
范围比TB实际实现的范围更宽（PRC-04用错误代理指标、PRC-06遗漏非法分支），不影响
现有PASS结论。
