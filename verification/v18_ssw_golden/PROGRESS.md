# V18 Progress

2026-10-10；分支 `v18-ssw-golden`；main 基线 `4863ec6e8f1298a7a9d543b3cd1a82e7a3d08fcb`。

- M1：规则表初稿完成，覆盖C09 §7.7全部28组输出；Q01/Q02已通过用户转问统筹，未根据SSW输出猜测规则。
- M2：完成。黄金只从允许的SAR9/SAR15模板提取相对窗口；合同端口TB在Vivado 2019.2上编译、展开、运行，5008行采集、波形2次和owner2次全部接纳、时钟与边沿间稳定检查0失败。双光SAR9有5组输出不符，详见`scenarios/trial_m2.json`；这是发现而非黄金拟合。新TB严格技能门禁0错误/0严格警告。
- M3：完成。148场景、781184行真实采集；最终规则下32 PASS、116 MISMATCH，待确认输出拍数0。所有波形/owner握手次数符合计划，协议/身份错配sticky为0；两相时钟及边沿间稳定检查0失败。7组V18差异记录（F01独立复现已登记SSW-C1）以及KNOWN-SAR15-DEADLINE单列。Q01～Q06全部答复已纳入。逐场景×信号证据见`scenarios/evidence/`。
- M4：未完成。

新克隆目录位于本会话授权可写的 visualizations 目录，因为原 Documents 工作区不能创建目录/写 FETCH_HEAD。未读取SSW实现或禁读报告。只新增本任务文件，不登记回归、不修改RTL。

驱动修正与证据重用：STOP/abort后不再发IDAC提交边界；等待包络、真实owner完成和两拍排空后回CONFIG；只有实际owner提交消耗sample index。受影响场景已重跑。Q06是纯期望规则更新，最终汇总对每项采集证明stimulus.hex与最新生成器输出SHA256完全相同，再重比更新后的黄金；未拟合实际值或移动输出坐标。
