# V18 SSW模拟控制输出逐拍黄金比对 任务书（RC1前阶段）

> 统筹会话撰写，2026-10-10。读者：用户另一个账号上**新开的**Claude会话。你只能看到本仓库。本文件自包含。
> 基线：main（RTL/TB与`7a8eabf`相同）。
> 上位文件：`verification_reports/PRE_TAPEOUT_CLOSURE_PLAN_20261009.md` §2 V18一节。

---

## 0. 先读这一节

### 0.1 目的
- SSW（`ppg_sar9_sar15_safe_selection_wrapper`）是芯片中唯一驱动模拟顶层时序控制引脚的模块，见C09 §7.7。用户（模拟设计者）确认过"SSW符合合同，即符合模拟需求"，所以SSW这些输出逐拍正确，是芯片功能正确的直接依据。
- 但迄今没有任何测试**只依据合同和网表时序**、逐拍检查过这些输出。
- 本任务要独立建立期望波形（黄金），在各种工作组合下，与SSW的实际输出逐拍比对。

### 0.2 独立性要求（最重要）
本任务的价值在于"期望值不是从SSW的实现推出来的"。
- **禁止阅读**：
  - `rtl/ppg_sar9_sar15_safe_selection_wrapper/`下的全部文件（RTL和它的单元TB）；
  - `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md`、`contracts/PPG_ALIAS_MAPPING_TABLE.md`（其中有大量SSW实现细节）；
  - `verification_reports/`下除本任务书和收尾计划以外的全部文件；
  - 分支`p0-closure`、`v1-independent`、`b-merge-batch`上的报告与证据。
- **只能编译、不能阅读SSW的RTL**。编译或仿真遇到看不懂的错误，需要看RTL才能定位时，停下来，通过用户问统筹。
- **工作目录**：在一个新目录里重新克隆本仓库（例如`git clone https://github.com/xinyanbaiqi/zlcx.git <新目录>`），并在那里打开会话。不要使用这台机器上已有的仓库目录，以免加载到其他会话留下的记忆。
- 报告中写一节"独立性声明"：列出你实际读过的文件。

### 0.3 边界
- **分支**：从main切出`v18-ssw-golden`，只推这个分支。
- **只新增文件，不修改任何已有文件**：
  - 代码放在`verification/v18_ssw_golden/`下（`golden/`、`tb/`、`scripts/`、`scenarios/`）；
  - 报告放在`verification_reports/V18_*.md`。
- 不登记进回归。
- 若环境支持skill：按根目录`CLAUDE.md`，Verilog相关工作使用`.claude/skills/erie-verilog-generator/`，新写的TB遵循`erie_strict`风格。
- **仿真器**：用本机可用的Vivado xsim（2019.2可以）或iverilog，报告中写明版本。RC1之后，统筹会在另一台机器上用Vivado 2022.2重跑你的脚本，所以脚本要可复用：路径、仿真器都做成参数。
- 发现SSW输出与期望不符：只记录，不修。
- **进度保存**：每完成一个里程碑（§4）立即提交并推送，维护`verification/v18_ssw_golden/PROGRESS.md`。
- **第一次回复用户时**：先用三五句话说明对任务的理解和计划，然后开工。

---

## 1. 期望值的依据（黄金来源）

### 1.1 合同C09
读取命令：`git show origin/b-merge-batch:contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md`。`b-merge-batch`分支上的合同版本较新，只读这一个文件，不要读该分支上的其它报告。

使用以下各节：
- §3 固定编码；
- §4：
  - 时间基准；
  - NORMAL Q3中心（RED宏帧tick 300，IR 460）；
  - SAR9/SAR15包络：SAR9相对Q3为−256/+18，SAR15为−273/+8；
  - 校准固定包络（local 10~284，Q3=266）；
  - owner截止点，以及owner未按时提交时"抑制Q1/Q2/Q3、LED有效采样，已开始的预建立安全收尾"；
  - 跨颜色重叠白名单：SAR9只有`o_clk_iref_idac_sar9_low`，SAR15有四项；
  - 四组IDAC码总线的逐bit公式与精度隔离矩阵；
- §5 快照、接管点、owner提交、IDAC候选码提交；
- §6 AMB_CAL专用窗口表（§6.1是唯一有效的数字窗口表）；
- §7 逐端口接口：§7.4上下文输入、§7.5 owner、§7.6完成与空闲、§7.7全部模拟输出、§7.8诊断；
- §8：
  - 先断后通；
  - STOP、abort与复位；
  - START恢复；
  - CHARACTERIZATION固定精度测量；
  - STATIC_BIAS的原始静态向量；
- §10 验收表中与输出波形有关的SSW-xx条目。

**注意**：C09中标为"V1.11补记"或"V1.11改写"的段落，是按RTL行为补写的。如果某条期望规则只能依据这类段落，在规则表中标"RTL派生条文"。

### 1.2 逐信号相对窗口
C09 §2原文："`ppg_timing_sar9.v`和`ppg_timing_sar15.v`的现有内部`cnt_frame`仅保留为波形相对窗口真源。"
- 文件：`rtl/ppg_timing_sar9/ppg_timing_sar9.v`、`rtl/ppg_timing_sar15/ppg_timing_sar15.v`，以及同目录的`*_3200hz.v`变体。
- 这些是早期按网表整理的时序模块，**不是SSW**，也不在芯片层级中，允许阅读。
- **用户确认（2026-10-10）**：这些时序模块的时序是正确的，用户已在模拟电路中验证过。所以它们就是本任务的窗口依据，与它们一致即视为符合模拟需求。
  - 统筹已核对：仓库中这4个文件与用户原始工作树中验证所用的版本（文件名带`_new`）内容相同，只差模块名和例化名。
  - 原始工作树中另有`*_v1.v`、`*_6667hz_v1.v`等其它实验版本，不在仓库中，与本任务无关。
- 做法：
  1. 取出每个输出相对于该模板自身Q3中心的起止拍；
  2. 平移到SSW坐标：RED Q3 = 宏帧tick 300，IR Q3 = 460，CAL Q3 = local tick 266；
  3. 用§1.1中的包络数字（SAR9 −256/+18、SAR15 −273/+8，CAL 10~284）做合理性核对，两者对不上就列为问题。
- 这两个模块计划在RC1前的修复轮中移到`legacy/`目录，所以脚本中它们的路径要做成参数。
- 校准（DCS_CAL）应使用哪个模板，或某个输出在合同与时序模块之间有出入时：**不要猜**，列为问题，通过用户问统筹。

### 1.3 可选：与网表原始参数核对
用户正在找Spectre网表文件，找到后统筹会把它放进仓库，并通知你路径。届时把§1.2的窗口与网表中各控制信号的pulse参数（delay、width）逐项核对，作为对"网表 → 时序模块"这一环的补充确认。在那之前不要等它，按§1.2推进；报告中写明此项是否已做。

---

## 2. 任务

### 2.1 期望规则表（先做，单独交付）
对C09 §7.7列出的**每一个**模拟输出（总线逐组），写出：
- 在各种工作组合下的取值规则：窗口、码值、互斥、白名单、抑制、安全收尾；
- 依据：合同节号，或时序模块中的窗口名；
- 是否为"RTL派生条文"；
- 不能确定的点，列入问题清单。

输出：`verification_reports/V18_SSW_EXPECTED_RULES.md`。

### 2.2 黄金发生器（`golden/`）
- 推荐用Python。输入是场景描述，输出是逐拍期望值文件（每拍一行，列为各输出）。
- 场景描述包括：
  - 光学模式（RED-only、IR-only、双光）；
  - 精度（SAR9、SAR15）；
  - 帧类型（NORMAL、AMB_CAL、DCS_CAL RED、DCS_CAL IR）；
  - AMB/DC码、LEDDAC码；
  - owner提交时刻，或错过截止；
  - 精度切换发生在哪一帧；
  - STOP、abort发生在哪一拍；
  - CHARACTERIZATION（固定精度RED、固定电流）和STATIC_BIAS配置。

### 2.3 SSW单元级比对TB（`tb/`）与脚本（`scripts/`）
- 只按C09 §7的端口表例化SSW，**不读SSW的RTL**。
- TB按C09与调度器合同C08的协议驱动全部输入：
  - 用一个简单的相位发生器产生`i_macro_tick`、子帧号、local tick；
  - 波形上下文fire；
  - owner提交；
  - ADC完成与空闲。
- 每拍把全部模拟输出写入文件。脚本与黄金逐拍比对，按"场景 × 信号"给出第一处不符的拍、期望值、实际值，以及不符拍数。

### 2.4 场景矩阵（`scenarios/`，数据文件）
至少覆盖：
- {RED-only、IR-only、双光} × {SAR9、SAR15} 的NORMAL帧；
- AMB_CAL、DCS_CAL RED、DCS_CAL IR（固定SAR9）；
- 码值：至少两个非对称的8位图样（如0xA5、0x5A），加上0x00、0xFF；
- 精度切换的前一帧和后一帧；
- owner错过截止（RED、IR、CAL各一）；
- STOP与abort落在波形中途：预建立开始前后、Q1前、Q3期间、Q3之后波形结束之前；
- CHARACTERIZATION：光电二极管固定SAR9/SAR15 RED；固定电流BOTH/RED/IR；
- STATIC_BIAS；
- 双光时RED与IR波形窗口的交界附近（宏帧tick 200~320）。

### 2.5 在当前RTL上运行
跑完§2.4的全部场景。每一处不符归入以下一类：
- **SSW与合同不符**：作为发现，附场景、信号、拍、期望值与实际值；
- **期望规则不确定**：作为问题；
- **TB驱动方式问题**：自行修正后重跑。

---

## 3. 交付
- 规则表：`verification_reports/V18_SSW_EXPECTED_RULES.md`。
- 报告：`verification_reports/V18_SSW_GOLDEN_TRIAL_<日期>.md`，包括：
  - 独立性声明；
  - 环境与仿真器版本；
  - 场景矩阵；
  - 逐场景比对结果；
  - 发现清单；
  - 问题清单；
  - 脚本的复用方法：如何换仿真器、换时序模块路径。
- 全部完成（或被叫停）时，告诉用户分支名、最后提交号和报告路径。统筹会核实发现与规则表。

## 4. 里程碑
| 里程碑 | 内容 |
|---|---|
| M1 | 规则表初稿与问题清单（先推送，问题可能需要统筹或用户回答） |
| M2 | 黄金发生器，与一个NORMAL双光SAR9场景跑通比对 |
| M3 | 全部场景矩阵在当前RTL上跑完 |
| M4 | 报告 |

**预计量**：约1~2个会话。
