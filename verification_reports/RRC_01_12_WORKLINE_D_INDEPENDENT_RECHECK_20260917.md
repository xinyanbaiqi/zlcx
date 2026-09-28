# RRC-01~12周期重检恢复验收ID独立复核——工作线D新批次9（家族：RRC）

> 方法声明：不信任`tb_ppg_control_top_periodic_recheck_recovery.v`自己的注释或
> `PPG_ALIAS_MAPPING_TABLE.md`既有映射，全部当作"待验证的声称"。复核方法：(1)从
> `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md`§9.4.3（577-592行，RRC-01~12
> 逐条verbatim英文acceptance requirement）取原文，(2)读真实断言代码块，(3)对TB依赖
> 的RTL复合信号（本次是`flag_takeover_safe`），不满足于"TB确认它为真时才accept"，
> 反查该信号在RTL里的真实公式，逐项核对是否覆盖了合同枚举的每一个子条件。

**状态：RRC-01~12全部12项完成断言级复核。结论：0个真实缺口（RRC-03经专门RTL追查
后确认初步怀疑不成立，见下）+2个次要观察（RRC-04/09）+10项CONFIRMED**。这份文件
同样有很高的自查纪律（RRC-01/02/12三处都有"check is vacuous"自我防护）。

## RRC-03——初步怀疑"门控公式缺detection fork一项"，经专门RTL追查后确认不成立

**用户已明确要求就此做一次专门的真实RTL追查，本节记录完整追查过程和最终结论，取代
本报告更早版本里"待查"的表述。**

**初步怀疑**（复核过程中第一次读到`ppg_amb_recheck_scheduler.v:179`）：
`flag_takeover_safe = i_precision_takeover_safe && i_normal_fork_idle && i_idac_idle
&& i_fir_idle && i_peak_valley_idle && i_frame_safe_boundary`只有六项，展开
`i_precision_takeover_safe`（来自`ppg_adc_measurement_idac_integration.v:959`：
`i_adc_idle && o_adc_chain_idle && o_normal_fork_idle && o_measurement_output_idle`）
后也只对应到ADC/NORMAL fork/IDAC/FIR/peak-valley/held-result六类，合同（583行）
明确要求的第七项"detection fork"排空，在这条追查路径上找不到对应项。

**追查过程**：`i_fir_idle`端口名字虽然只提"FIR"，但真正决定它是谁例化时连的是
`ppg_precision_window_integration.v:999`：
`.i_fir_idle(flag_fir_idle_to_scheduler)`，旁边注释明写"同时要求FIR和检测fork
排空"——顺着这个线索找到`flag_fir_idle_to_scheduler`真正的锁存逻辑
（同文件576-586行）：

```verilog
always@(posedge i_clk or negedge i_rstn)begin
    if(i_rstn == 1'b0)begin
        flag_fir_idle_to_scheduler <= 1'b0;
    end else if(i_start_ack_event==1 || flag_detection_discard_apply==1 ||
        precision_15_to_9_event_o==1 || amb_recheck_accept_o==1 || (i_run_enable==0))begin
        flag_fir_idle_to_scheduler <= 1'b0;
    end else if(fir_idle_o == 1'b1 && detection_fork_idle_o == 1'b1)begin
        flag_fir_idle_to_scheduler <= 1'b1; // 两项都真时才锁存"排空已证明"
    end else begin
        flag_fir_idle_to_scheduler <= 1'b0;
    end
end
```

**结论：初步怀疑不成立，不是真实缺口**。`flag_fir_idle_to_scheduler`这个信号——尽管
它接入`ppg_amb_recheck_scheduler`的端口字面名字是`i_fir_idle`——真实的锁存条件是
`fir_idle_o && detection_fork_idle_o`两项相与，`detection_fork_idle_o`本身定义为
`!flag_baseline_pending && !flag_peak_valley_pending`（同文件438行）。也就是说
合同要求的"detection fork"排空这一项，**确实被真实覆盖了，只是被打包进了一个端口
命名容易让人误判范围的信号里**，不是在RRC-03这条链路上缺失。这里还有一层额外的
设计考量（576行注释）："返回粗模式后先锁存稳定排空事实，切断安全接管对FIR ready的
组合反馈"——用寄存器锁存这个复合条件而不是直接组合判断，是为了避免一个真实的组合
反馈环路，属于有意为之的设计细节，不是巧合掩盖了缺口。

**方法论小结**：这是本次独立复核里一次"发现→深挖→证伪"的完整案例，和SID-11/LFA-06
那类"深挖后确认真的是缺口"方向相反，但过程同样重要——第一层追查（只看
`ppg_amb_recheck_scheduler.v`和`i_precision_takeover_safe`的直接展开）会得出错误
结论，必须再深一层追到端口连线的真实驱动信号（`ppg_precision_window_integration.v`
里`i_fir_idle`实际接的是什么）才能看到完整图像。记录在案，供后续同类"门控信号名字
和真实内容不完全对应"的排查参考。

**合同原文**（§9.4.3，583行）："Accept remains low until **ADC, NORMAL fork, IDAC,
FIR, detection fork, peak/valley, and held result ownership** are all drained."——
明确列出七个必须全部排空的前提条件。

**TB的验证方式**（`tb_ppg_control_top_periodic_recheck_recovery.v:1091-1116`）：TB
自己不逐项重新构造这七个条件，而是直接层级引用RTL自己的复合信号
`ppg_amb_recheck_scheduler_Inst.flag_takeover_safe`，确认accept真正触发时这个信号
恰好为真（906/1113行）。这个验证策略本身是合理的（复用RTL已有的复合门控，而不是
在TB里重新发明一遍等价逻辑）——**但它的可靠性完全取决于`flag_takeover_safe`这个
RTL信号自己的公式是否真的覆盖了合同要求的全部七项**，这一步TB没有做，本次独立复核
补上了。

**独立反查RTL得到的真实公式**：

- `ppg_amb_recheck_scheduler.v:179`：
  `flag_takeover_safe = i_precision_takeover_safe && i_normal_fork_idle &&
  i_idac_idle && i_fir_idle && i_peak_valley_idle && i_frame_safe_boundary`
  （RTL自己的注释也写"六项同时成立"，即六项，不是七项）。
- 其中`i_precision_takeover_safe`本身是复合线，来自
  `ppg_adc_measurement_idac_integration.v:959`：
  `flag_precision_takeover_safe = i_adc_idle && o_adc_chain_idle &&
  o_normal_fork_idle && o_measurement_output_idle`。

展开合并后，`flag_takeover_safe`真实依赖的原子条件是：`i_adc_idle`、
`o_adc_chain_idle`、`o_normal_fork_idle`（与顶层再传入的`i_normal_fork_idle`重复
两次）、`o_measurement_output_idle`、`i_idac_idle`、`i_fir_idle`、
`i_peak_valley_idle`、`i_frame_safe_boundary`。

**与合同七项逐一对照**：ADC→`i_adc_idle`/`o_adc_chain_idle`（有）；NORMAL fork→
`o_normal_fork_idle`/`i_normal_fork_idle`（有，且重复）；IDAC→`i_idac_idle`（有）；
FIR→`i_fir_idle`（有）；peak/valley→`i_peak_valley_idle`（有）；held result
ownership→`o_measurement_output_idle`（合理对应，有）；**detection fork→全公式
搜索不到任何对应项**。同一份AMI文件里`o_datapath_empty`（1140行）自己的公式明确把
`detection_fork_idle_o`作为一个独立、与`fir_idle_o`/`detector_idle_o`/
`o_normal_fork_idle`都不同的单独信号列出——证实"detection fork drain"在这个项目的
RTL里是一个真实、独立、可判断的状态，不是我的臆造；但这个独立信号没有出现在
`flag_takeover_safe`的六项（或展开后的八项）里的任何一项中。

**诚实的不确定性声明**：这个发现目前停留在"公式层面比对，合同要求的一项在门控信号
里找不到对应项"这一步，本次**没有**进一步证明这在真实激励下会产生一个可复现的错误
场景（即没有构造出一个真实的"detection fork真的非空但`flag_takeover_safe`依然为真、
recheck真的accept了"的反例）——`o_datapath_empty`是一个更宽泛的、服务于其它用途
（如STOP排空完成判定）的聚合信号，`flag_takeover_safe`是这个recheck scheduler自己
专属的门控，两者范围是否必须完全一致，取决于detection fork的残留状态在RTL设计意图
上是否真的会威胁recheck accept这个具体场景的安全性——这需要更深入的时序/状态机分析
才能确认，不是本次独立复核范围内能穷尽的。**如实报告发现到这一步，不夸大成"已确认
的RTL bug"，但也不淡化成普通的TB�covered/not covered问题**——建议用户优先安排对
这一条做专门的真实RTL追查（参照本项目SID-11/LFA-06一类问题已经证明有效的追查方式），
而不是按常规"要不要补TB"的节奏处理。

## 次要观察（不计入缺口，供参考）

- **RRC-04**（1138-1165行）：合同要求accept原子性地让"both FIR histories, old cross
  candidates and cycle qualification, old extrema/direction state, and passive
  precision-tail context"全部失效——TB实际验证了"FIR RED/IR历史被清"+"peak anchor/
  slope保持不变"两项，"cross候选/周期资格"、"extrema/方向状态"、"精度尾部上下文"
  这三项没有看到对应的显式核对。
- **RRC-09**（1194-1223行）：RED/IR各自独立累积21个新样本这个核心数字+独立性验证
  扎实，但"old samples or inserted zeros cannot count"（旧样本或插入的零值不能计入
  新warm-up计数）这个反向排除性子句，没有看到主动构造"喂一个理应被排除的旧样本/零值"
  并确认它未被计数的场景，可能是由计数器归零时机的结构性质隐式保证，但未主动验证。

## CONFIRMED项说明（10/12）

- **RRC-03**（1091-1116行+RTL公式反查）：初步怀疑门控公式缺"detection fork"一项，
  经专门追查确认该要求经`flag_fir_idle_to_scheduler`真实覆盖，详见上方专门章节。
- **RRC-01**（1068-1071行）：按真实`sched_normal_frame_complete_event_o`帧完成事件
  计数（非ADC/owner事件计数），配置interval=30真实验证，自带vacuous防护。
- **RRC-02**（1080-1088行）：pending在真实SAR9->SAR15->SAR9往返全程保持、无校准活动/
  码变化，只在真实return事件后才accept，自带vacuous防护。
- **RRC-05**（1171-1174行）：AMB→DC_R→DC_IR严格时间顺序，用真实时间戳比对
  （t_enter_amb_family < t_enter_dcsr_family < t_enter_dcsir_family）而非猜测顺序。
- **RRC-06**（1177-1180行）：窗口内未变的AMB码保持code/epoch同时仍触发DC_R/DC_IR
  重验证状态迁移。
- **RRC-07**（1333-1358行）：真实确认越界触发完整重搜索，新码真实提交，epoch仅在
  安全边界处递增。
- **RRC-08**（1185-1188行）：整个recheck busy窗口期间正式NORMAL输出保持抑制。
- **RRC-10**（1244-1247行）：resume后新的upward cross完全来自新的合格历史，真实
  经安全边界路径进入SAR15。
- **RRC-11**（1362-1408行）：DC_R真实耗尽触发failed/fault+旧baseline anchor失效+
  固定slope重载+进入reacquire+3000拍持续验证NORMAL保持阻塞，五个子句分别独立核对。
- **RRC-12**（1459-1501行）：固定驱动下pending真实卡住等待从未发生的return事件
  （自带vacuous防护）+STOP清除pending不产生码更新+已在途owner遵循常规受控释放。

## 完整复核表（12/12全部完成）

| ID | 场景（文件行号） | 结论 |
| --- | --- | --- |
| RRC-01 | 1068-1071 | CONFIRMED |
| RRC-02 | 1061-1088 | CONFIRMED |
| RRC-03 | 1091-1116（+RTL公式反查） | CONFIRMED（初步怀疑经专门追查证伪，见上方专门章节） |
| RRC-04 | 1138-1165 | CONFIRMED（另三项失效子句为次要观察） |
| RRC-05 | 1171-1174 | CONFIRMED |
| RRC-06 | 1177-1180 | CONFIRMED |
| RRC-07 | 1333-1358 | CONFIRMED |
| RRC-08 | 1185-1188 | CONFIRMED |
| RRC-09 | 1194-1223 | CONFIRMED（旧样本排除子句为次要观察） |
| RRC-10 | 1244-1247 | CONFIRMED |
| RRC-11 | 1362-1408 | CONFIRMED |
| RRC-12 | 1459-1501 | CONFIRMED |

## 与今日工作线B回归的交叉核对

`tb_ppg_control_top_periodic_recheck_recovery.v`今日回归PASS，与本次独立复核读到的
断言代码一致；RRC-03经专门RTL追查确认初步怀疑不成立，不影响现有PASS结论。

## 批次9小结：OIB+LFA+PRC+RRC集群（共44项）全部完成

至此，第二个共享RTL锚点集群（OIB 10+LFA 12+PRC 10+RRC 12）全部完成工作线D独立复核，
累计发现1个OIB真实缺口+0个LFA新缺口（3个次要观察）+2个PRC真实缺口+0个RRC真实缺口
（RRC-03初步怀疑经专门追查证伪）。连同批次1-5，累计110/~157个ID完成，17个"真实缺口"
级别发现，全部登记在案，尚未处理。
