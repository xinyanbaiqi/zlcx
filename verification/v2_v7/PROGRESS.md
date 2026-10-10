# V2/V7框架进度

任务书：`verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md`。分支：`v2-sweep-framework`（从main `c56296d`切出）。

## 已完成
- ADC行为模型`adc_model/v2_adc_behavior_model.v`：兼容脉冲加3种电平模式，2种idle公式，按槽位和序号注入丢失、迟到、忙后恢复、永久忙。deliverable gate 0/0。
- 模型自测`tb/tb_v2_adc_behavior_model.v`：xsim 41/41 PASS（`ADCM_SELFTEST_PASS checks=41`）。
- 6个常驻监视器核心`monitors/`（活性、身份记分板、恢复、帧间隔、Q3绑定、作废/完成互斥）：均为可综合检查核心，deliverable gate 0/0。打印层放在TB里。
- 扫描TB`tb/tb_v2_sweep.v`：编译通过，基线单点跑通（DUAL9/NONE，6个监视器全部PASS，约9秒/8帧）。
- 脚本：`scripts/v2_compile.sh`（只编译一次）、`scripts/v2_run_point.sh`（单点，每点私有快照副本，可并行）、`scripts/align_inline_comments.py`与`scripts/gate.sh`（复用skill的VG060列宽规则）。
- xsim 2022.2 SVA探针：并发断言、`bind`、跨层次引用、`##[1:n]`、`$past`可用；`cover property`不支持（会被忽略）。

## 当前（2026-10-10，暂停等待答复）
- **阻塞**：完成信号电平语义与RTL不兼容，其中一种组合出现静默停滞。见`verification_reports/V2_V7_BLOCKER_ADC_DONE_LEVEL_20261010.md`，等待统筹或用户答复DONE下降沿的时刻。

## 下一步
- M1收尾：监视器自测TB（人造违反与合规序列）。
- M2：网格TSV、批量脚本（可续跑、并行、记录起止时间）、汇总`summary.tsv`与Markdown表、落点精度核对。
- M3：V7断言（`assertions/`）、自测TB、3条性质的RTL变异负对照。
- M4：缩小网格试跑、必须覆盖场景冒烟、报告`verification_reports/V2_V7_FRAMEWORK_TRIAL_<日期>.md`。

## 已知阻塞
- 见上（ADC完成信号电平语义）。在得到答复前，扫描默认用兼容模式（mode 0），mode 2做对照。
