# 实际短测试与负对照

工具复用A现有Icarus11 /tmp/ppg_audit_iverilog_20261004，Windows bundled Python仅负责tar标准输入传输与收集日志。输入副本、SHA256、命令、退出码与时间均见results*.json。Linux脚本尝试因缺Python3退出127，随后改为已有tar，成功；初始失败日志保留。

- baseline_original：12固定独立合同向量PASS，退出0。baseline_round_mutant：16384→16383，case10失败退出1。
- reconstructor_original：四个可达Q17半值门限邻点PASS，退出0。reconstructor_round_mutant：65536→65534，+65537点预期1实得0，退出1。reconstructor_legacy_mutant：同一变异通过原PR-01..14/1024 sweep，退出0，验证C-003测试缺口。
- peak_return_hold：原RTL返回frame10→21失败退出1。peak_return_hold_with_protocol_check：协议sticky==0仍在同一保持比较失败退出1。peak_return_guard_countercontrol：只在自有副本阻止pending载荷覆盖，对照PASS退出0，非交付修复。
- idac_midpoints_original：独立固定127/191/223/207/199/203/201/200候选序列PASS，退出0。sum8变异同序列第二点期望191实得63退出1；idac_legacy_sum8_mutant仍148 PASS退出0。

这些仅是专项短测试，不是A的48份实际回归，也不是ASIC/FPGA或模拟硅签核。

追加run_jnt.py三份原文收尾短探针、run_dc.py两份公开端点/错误期望对照；对应plan/results及compile/run.log齐全，未修改共享源码。
