# V2/V7框架进度

任务书：`verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md`。分支：`v2-sweep-framework`。
报告：`verification_reports/V2_V7_FRAMEWORK_TRIAL_20261010.md`。

## 已完成（P0阶段全部里程碑）
- M1：ADC行为模型（兼容；保持型按10-10模拟侧确认的Q1回落语义；提交时回落对照；外部ADC_RST；idle两种公式加0~3拍同步延迟；5类故障，落点为绝对拍），自测46/46；6个监视器核心（gate 0/0），自测43/43；扫描TB。
- M2：网格生成器与`grids/*.tsv`，`v2_batch.sh`（并行、可续跑），`v2_summarize.py`，各事件提前量实测校准，落点按绝对拍核对。
- M3：V7断言19条（`bind ppg_control_top`），自测13/13；RTL变异负对照4/4被杀死。
- M4：缩小网格469点试跑（PASS 444、EXC-C 15、EXC-F1 1、KNOWN-FIX-7 4、NEW 5，NEW均已分析，无新RTL缺陷，两项交统筹裁定）；必须覆盖场景9项全部有冒烟点；报告已写。

## 当前
- 等待统筹核实报告，尤其是§6.2（迟到完成越过T-lost与作废的竞争）和§6.3（活性界限与静默忙）的裁定。

## 下一步（RC1之后，另发任务书）
- 变基到RC1；ADC完成信号轮合入后切换到保持型模型并例化新的空闲模块；跑正式网格（7776点，约3.3小时；3个时延种子约10小时）。

## 已知阻塞
- 无。KNOWN-ADC-HELD-DONE由ADC完成信号轮处理。
