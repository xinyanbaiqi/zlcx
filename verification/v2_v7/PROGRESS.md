# V2/V7框架进度

任务书：`verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md`。分支：`v2-sweep-framework`。

## 已完成
- M1：ADC行为模型（兼容脉冲；保持型DONE按10-10模拟侧确认的Q1回落语义；提交时回落对照；外部ADC_RST；idle两种公式加0~3拍同步延迟；四类故障），自测44/44；6个监视器核心（gate 0/0），自测43/43；扫描TB单点跑通。
- M2：网格生成器与`grids/*.tsv`；`v2_batch.sh`（并行、可续跑、记录起止）；`v2_summarize.py`（summary.tsv与Markdown表，按V2MON/V2POINT/V2SIG等行判定）；落点核对（各事件提前量已实测校准）。
- M3（进行中）：V7断言`assertions/v7_checkers.sv`与`v7_assertions.sv`（bind到ppg_control_top，19条），自测13/13；样例点上全部通过。
- 阻塞已答复：完成信号保持语义记为`KNOWN-ADC-HELD-DONE`，扫描默认兼容模式。

## 当前
- M3：RTL变异负对照（性质1、3、4）。

## 下一步
- M4：缩小网格试跑、必须覆盖场景、报告。

## 已知阻塞
- 无（ADC保持型DONE问题由单独的ADC完成信号轮处理）。
