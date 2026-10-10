# V2/V7 阻塞问题：完成信号电平语义与RTL不兼容（含一处静默停滞）

> V2/V7框架会话，2026-10-10。分支`v2-sweep-framework`。按任务书§2.3"静默停滞或死锁：立即停下，告诉用户"上报，附最小复现。
> 基线：main `c56296d`（RTL/TB与`7a8eabf`相同）。只记录，不修。

## 1. 问题

任务书§1.4和§3.1要求ADC模型按以下语义写：完成信号`CLK_STAGEx_DOUT_LOW`在转换结束时上升，**保持高电平到下一次转换开始**。

合同里写的是"完成电平保持到下一次ADC_RST"（C14 §2、§5.2），并要求`i_adc_transaction_start`只能在"ADC_RST已完成、两个DONE都为低之后"发出。但合同**没有把ADC_RST或"下一次转换开始"放到任何数字拍上**，也没说它由哪个SSW输出触发。按任务书§3.1，这属于阻塞问题。

RTL的实际情况（静态阅读，并经下面的仿真确认）：

- owner提交（即AMI `o_transaction_start_fire`，也就是捕获模块的`i_adc_transaction_start`）在波形上下文接管后、只要`i_adc_idle`为1就会发生：RED在宏帧tick 1附近；IR在RED完成之后。都**早于**本笔的Q3（RED 300、IR 460）。
- `ppg_adc_async_stage_capture`在start那一拍清零两级同步链，之后**按电平**捕获所选CLK_DOUT（`flag_capture_accept`）。
- C01 §6.2.1的物理idle公式要求所选DONE"已回到非活动状态"；芯片顶层合成器为`!CLK_STAGEx_DOUT_LOW`经两级同步（`ppg_chip_digital_top.v` `w_idle_mux_async`）。

由此有两种冲突，都已在仿真中出现。

## 2. 仿真证据（control_top级，xsim 2022.2）

| 点 | ADC模型设置 | 现象 |
|---|---|---|
| `base` | 兼容脉冲（等价于现有`bg_adc_responder`） | 6个监视器全部PASS，16笔提交、16笔结果 |
| `lvl2` | DONE电平保持，在**下一次owner提交那一拍**回低 | 全部PASS，与兼容模式一致 |
| `stale_repro` | DONE电平保持到**下一次Q3上升沿**（§1.4字面理解） | 只出现1次Q3，却有4次完成：每次新提交后约2拍，就把上一笔的旧高电平当作本笔完成捕获（早于Q3，success=0）。frame 1 tick 162 SSW报故障`0x21`，系统阻断、STOP |
| （同上） | DONE保持到`CLK_AFERST_LOW`上升沿 | 与上一行逐事件相同：AFERST晚于owner提交 |
| `stall_repro` | DONE在下一次提交时回低，但idle按C01 §6.2.1字面公式（要求所选DONE为低，相当于芯片顶层的`!CLK_DOUT`合成） | **静默停滞**：第1笔转换后DONE保持高，idle恒为0，再无owner提交。RUN中连续39669拍无进展；**无任何阻断故障**，supervisor没有记录。只有非阻断sticky：调度器/SSW owner截止sticky=1，AMI集成协议sticky=1（RED截止后valid切到IR候选，即已知的AMI-C1） |

### 最小复现

```bash
B=<build>; bash verification/v2_v7/scripts/v2_compile.sh <repo_or_archive> $B --no-v7
bash verification/v2_v7/scripts/v2_run_point.sh $B <dir>/stall_repro V2_POINT=stall_repro V2_MODE=DUAL9 V2_EVENT=NONE V2_ADC_DONE_MODE=2 V2_ADC_IDLE_MODE=1
bash verification/v2_v7/scripts/v2_run_point.sh $B <dir>/stale_repro V2_POINT=stale_repro V2_MODE=DUAL9 V2_EVENT=NONE V2_ADC_DONE_MODE=1 V2_TIMEOUT_CYCLES=30000
```

- 模式：NORMAL双光MANUAL SAR9（DUAL9）；事件：无；时延按种子1在[2,20]内取值。
- 停滞起点：frame 0 RED完成之后；监视器在frame 3 tick 331报出（15000拍门限）。
- 日志：`D:\PPG\verilog\ppg_regression_runs\v2_20261010_dev\pts\stall_repro\xsim.log`、`...\pts\stale_repro\xsim.log`。

## 3. 需要统筹或用户回答

1. 完成信号的**下降沿**（ADC_RST，或"下一次转换开始"）相对宏帧tick或Q3在哪一拍？由哪个SSW输出（或模拟内部的什么事件）触发？
2. 它是否保证**早于下一笔owner提交**（RED约在tick 1，IR在RED完成后）？如果不保证：按现有RTL，§1.4字面语义会让每笔事务都错捕旧完成（上表第3行），这不是"F-3约2拍窗口"那类罕见竞争，而是每帧都会发生。
3. 芯片顶层idle按`!CLK_DOUT`合成，在"电平保持"语义下第一笔之后就会静默停滞（上表第5行）。这是否意味着：要么完成信号实际是脉冲或会被自动清低，要么芯片顶层的idle合成公式需要改？

在得到答复前：扫描默认使用兼容模式（mode 0），并用mode 2做对照（两者都与RTL自洽）；电平语义相关的结论暂缓。

## 4. 已登记例外的对照

- 不是F-3：F-3是作废后旧DONE在下一笔start之后约2拍内到达的罕见竞争，合同把"物理空闲后不会出现旧DONE"写成前提。这里是每笔事务都会出现的结构性问题，前提本身就和完成电平语义冲突。
- 第5行中的AMI集成协议sticky，是AMI-C1（KNOWN-FIX-3）在这种停滞下的表现，但停滞本身不是AMI-C1造成的：idle恒为0时没有任何笔能提交。
