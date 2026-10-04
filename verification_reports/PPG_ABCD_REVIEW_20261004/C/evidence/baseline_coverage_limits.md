# 基线TB两项验收声明的裁定
固定d18c6954621e53e5a6505dd3a6c688c266d23839。

C21合同C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/contracts/PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md:589..592要求OPT23连续两个完整周期、OPT24随机所有合法事务正式结果逐位一致并覆盖正负平滑/无相交/lead三区间/回绕/饱和。C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd16-9489-7e50-a7b6-a1178fd92bf1/ppg_audit/snapshot/rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v:403..430任务每次410 reset、413新START，426只比42轮内部商。1279/1281的两次调用不共享周期状态；1286..1303随机32组调用同一任务，不能证明最终平滑斜率或连续pending隔离。

C独立12公开算术向量及舍入变异真实运行，只补其中数学边界；phase_a_equivalence20005组没有DUT实例，是公式宽窄等价辅助。系统baseline连续生成真实波形，但B[f]比较使用RTL报告斜率，不是独立最终斜率golden。此前正确的除法比较、共享乘法局部路由和原65 PASS仍有效，不把该缺口升级为RTL错误。建议新增不复位双完整周期、独立输入驱动的软件最终结果参考和错误最终提交负对照。静态证据确认，未运行新的全TB变异。
