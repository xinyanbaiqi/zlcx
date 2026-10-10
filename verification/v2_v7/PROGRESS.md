# V2/V7框架进度

任务书：`verification_reports/V2_V7_FRAMEWORK_BRIEF_20261010.md`。分支：`v2-sweep-framework`。
报告：`verification_reports/V2_V7_FRAMEWORK_TRIAL_20261010.md`。

## 已完成（P0阶段全部里程碑）
- M1：ADC行为模型（兼容；保持型按10-10模拟侧确认的Q1回落语义；提交时回落对照；外部ADC_RST；idle两种公式加0~3拍同步延迟；5类故障，落点为绝对拍），自测46/46；6个监视器核心（gate 0/0），自测43/43；扫描TB。
- M2：网格生成器与`grids/*.tsv`，`v2_batch.sh`（并行、可续跑），`v2_summarize.py`，各事件提前量实测校准，落点按绝对拍核对。
- M3：V7断言19条（`bind ppg_control_top`），自测13/13；RTL变异负对照4/4被杀死。
- M4：缩小网格469点试跑（PASS 444、EXC-C 15、EXC-F1 1、KNOWN-FIX-7 4、NEW 5，NEW均已分析，无新RTL缺陷，两项交统筹裁定）；必须覆盖场景9项全部有冒烟点；报告已写。

## 当前
- 2026-10-10统筹核实`32cbec8`：P0阶段四个里程碑验收通过，本阶段结束。
- 裁定：
  - §6.2（迟到完成越过T-lost与作废竞争）：在ADC完成信号轮处理。新物理空闲带64拍转换超时，使竞争回到约2拍偶发窗口；同拍规定"捕获优先于作废"并逐拍检查；作废后才到的DONE维持升级为cause 02；cause 07保留作纵深防御，写明芯片层不可达。
  - §6.3（活性界限）：不采用(b)(c)。界限改为按设计常量推导的最长合法无进展时间，ADC完成信号轮合入后由统筹重新推导，写进正式扫描任务书。
  - 报告§7第3、4条（例外C第4项措辞、START后首帧界限）已列入修复轮。

## 下一步（RC1打出后，按统筹另发的正式扫描任务书执行）
- 分支变基到RC1。
- 默认改用保持型ADC模型（模式1），TB例化新的空闲合成模块。
- 按新的owner截止265/425更新关键拍网格（`scripts/v2_gen_grids.py`的KEY_TICKS，以及引用283/443的注释与必须覆盖场景）。
- 活性界限按统筹推导的新值修改（`v2_mon_liveness`的C_LIMIT、V7 P7的C_LIMIT）。
- 启动搜索加多候选RAW档，覆盖校准帧全部8个子帧。
- 登记进回归前，把TB和断言文件的deliverable gate问题清零（`scripts/align_inline_comments.py`处理VG060，再补begin/end等）。

## 已知阻塞
- 无。KNOWN-ADC-HELD-DONE由ADC完成信号轮处理。
