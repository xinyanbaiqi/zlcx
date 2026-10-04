# D 组交接

基准：d18c6954621e53e5a6505dd3a6c688c266d23839。

输出根：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D

报告：同目录 PPG_REVIEW_D.md；台账：coverage.csv；证据：evidence/。

## 当前交付状态（2026-10-04最终更新）

24主责文件全文语义/场景注释、10 RTL的396端口、131个本地验收条目与27条版本依赖均已核对。65项台账为60完成、5部分；文件整体19完成、5部分。5份TB的技能formatter静态compile/AST未通过：CCC、chip、manager、ILM、ISE。全文人工审查已完成，真实Icarus编译/完整运行证据已核对，但未用其替代formatter AST通过。ILM块注释误报来自:2033行注释中的ST_AMB_*/ST_DCS_*，control-parser失败仍保留。

本组共8项确认发现，S1=1、S2=4、S3=3；7项已并入A统一报告，不能重复计数：

| 本组编号 | 统一编号 | 结论 |
| --- | --- | --- |
| D-001 S2 | F-013 | CCC纯软件sticky清零漏比较；清零自保持变异仍26PASS |
| D-002 S3 | F-024 | manager/wrapper/unpack正式参数合同缺实现 |
| D-003 S1 | F-023 | STOP与START/COMMIT/CLEAR同拍被吞；单STOP通过，真实SPI 0x06仍RUN |
| D-004 S2 | F-025 | wrapper第二跳alpha错误输出仍22PASS |
| D-005 S2 | F-028 | ILM04真实转换LED错误12周期仍原场景PASS |
| D-006 S2 | F-029 | ISE04选中bus中间错误2周期仍原场景PASS |
| D-007 S3 | F-030 | CS_N两级同步条款与原始片选异步复位实现冲突 |
| D-008 S3 | 待A复核 | C07:249允许NORMAL/固定电流无control-valid START，:295却无模式限定地要求复位后先6bit提交；STATIC_BIAS仍需合法提交 |

D-008原句、实际Top/manager选择、未变异ILM04的真实默认启动路径及反驳见报告；不声称新RTL缺陷。D-003、D-005/006均有真实刺激、未变异对照、错误期望或适当变异日志；首次无效设置/未触发变异记录明确不计证据。A已收录发现仍保留D编号定位原始素材。

最终核验HEAD固定、工作树为空，24文件+4依赖git blob一致，所有未变异门禁副本字节一致，见evidence/final_baseline_D.json。共享RTL/TB/合同和A报告始终只读；无修复、无安装、无WSL重启或停止A任务，无重复全套长回归。

留项：5个formatter AST失败需要技能维护方修复解析边界后重跑原字节检查；D-008待A复核/统一编号；功能缺陷/TB缺口按conservative未修；全局CIS/MGR联合层动态ID、矩阵CLOSED及其它长回归由A/B/C汇总。未运行xsim/Verilator/综合/ASIC物理签核，不记通过。已接受本组风格VG060=10、VG010=46单列，不升级功能问题。

输出绝对路径：

- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D/PPG_REVIEW_D.md
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D/coverage.csv
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D/handoff.md
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D/evidence/

以下为批次历史，当前状态以上述最终更新和65项台账为准。

2026-10-03：已读取共同约定、原任务、唯一主责清单、登记表和技能入口。正在复核固定版本、原 F 发现和已有门禁/探针。24 项均未完成，不代表功能签核。共享资产只读；conservative，不应用修复。完整回归归 A 管理。

批次一：24主责文件逐字节等于固定git blob；原F-005/F-006完整SPI探针日志已核实，保留原编号。reset_sync、pulse_cdc_sync、config_cdc_bridge、characterization CDC与497行CCC TB全文实读。技能分析使用本组字节相同输入副本；共享目录没有写入。

新发现 D-001 / S2 已仿真确认：CCC-22取消软件sticky清零仍26 PASS；错误期望值负对照能FAIL。完整结论/反驳见 PPG_REVIEW_D.md，证据 evidence/tb_ppg_characterization_control_cdc/。

下一批：完成SPI地图/快照与芯片连接、CDC比例/相位/复位专项；随后config/unpack/wrapper、两系统TB和全部合同。未列完成项保持部分，尚未结束D组审阅。

2026-10-04 批次二：上述SPI/chip/P2S与manager/wrapper/unpack全文已实读；manager980行、wrapper889行、unpack340行TB全文已实读。CDC五组每组590比较通过，错误payload负对照FAIL。D-002 S3正式参数合同缺实现；D-003 S1 STOP同拍被吞、RUN继续（单独STOP通过，三冲突均FAIL）；D-004 S2 wrapper alpha输出变异仍22PASS。报告含完整反驳、真实位置与日志。

WSL drvfs失效已用独立原生/tmp副本完成短验证，无重启或安装。下一批：chip893行TB、2份系统TB（2216/1532行）、2份尚未全文读完合同、矩阵/ID与实际Top连接闭环；P2S短队列probe，STOP芯片路径复现。现阶段不可宣称D全量完成。

批次三进展：chip893行TB已全文实读。D-003已在真实SPI pad确认：命令0x06(STOP+COMMIT)产生真实目标域碰撞，state=RUN、stop_hits=0、code=01；0x02单STOP对照通过。原始日志evidence/tb_ppg_chip_digital_top/chip_stop_*，报告已补芯片证据。
批次三：两系统TB全部可执行语句完成实读。D-005 S2 ILM-04转换期间LEDDAC错误12周期仍原PASS；D-006 S2 ISE-04选中AMB总线错误2周期仍原PASS；两者未变异及错误期望负对照齐备。D-007 S3 CS_N两级同步正文与原始片选异步复位结构冲突（不作物理故障结论）。报告已保存，证据fragment_*。继续ID/版本/矩阵、场景注释及24项台账收束。
