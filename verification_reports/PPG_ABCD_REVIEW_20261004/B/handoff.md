# B组最终交接 — 主责审阅完成

被审提交：`d18c6954621e53e5a6505dd3a6c688c266d23839`。日期2026-10-04。只读/conservative，未修改共享RTL、合同、TB、A报告或登记表，未提交/推送。未向其他聊天发送消息。

状态：7 RTL、13 TB、9合同共29/29全文审阅完成（30,592行），94/94本组检查项完成。剩余未审RTL=0、TB=0、合同=0。语义/协议问题均保持未修复；全套原TB回归、完整逐ID语义/全局锚点和系统最终签核保持A主责。历史批次交接中“待审”已由此最终交接替代。

- [详细报告](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/PPG_REVIEW_B.md)
- [94项覆盖台账](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/coverage.csv)
- [29文件覆盖](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/file_coverage.csv)
- [19项发现索引](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/findings_index.csv)
- [312个ID机械联系](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/acceptance_coverage.csv)
- [逐拍协议](C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/protocol_table.md)
- 原始证据：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B/evidence

发现19项：S1=8（B-003/005/006/007/008/009/010/012）、S2=7（B-002/004/011/013/014/015/016）、S3=4（B-001/017/018/019）；未新增S4。每项有实际行号、≤3行原文、证据、反驳、恢复/范围限度和建议。findings_index.csv的源行由最终脚本重新内容核对，不能套偏移。

优先读B-012：evidence/top_abort_done_v3/run.log。真实Top生产注入关闭，匹配completion与abort同拍，AMI/Scheduler释放而SSW owner仍1。首次3拍到CONFIG，物理ADCidle/AMIempty为1；不能说首次STOPPING死锁。经过100拍、diag_clear、重新START仍占用，新RUN7000拍新owner=0/cause21；只在本组副本删除SSW abort保持分支，对照5拍提交新owner。内部残留阻碍重新启动，已排除外部未响应解释；新owner对照后续仍需外部ADC回应，不把对照的等待算死锁。

B-007：evidence/recheck_deadline_v4/run.log。真实AMI子模块链进入periodic reason01、尚无物理owner；deadline清outer却inner=1，新请求0，即使100次safe/物理CAL结束边界且真实idle均1，仍不能重试。正常三阶段结果消费control完成，!RUN可恢复。不声称reset后永久死锁。完整Top产生此拒绝窗口没有新的动态专项，本条已按AMI及真实子模块的确认范围写明。

其余S1：B-003默认连续NORMAL5001拍；B-005CAL末拍abort被rollover覆盖但未见新物理owner/永久卡死；B-006两个held事务formal discard错指后笔；B-008measurement消费清另一分支资格；B-009AMI START清sticky（PWC已知修复不能补偿AMI）；B-010PWC matching discard同safe commit仍改precision/发正常事件，未声称完整Top同拍窗口已动态证实。

S2反证：SUP历史未clear rearm、FSC周期/Q3、PWI尾部、INJ互斥有效窗口、P06叶子enable未真实撤销，均有错误副本/错误期望或纠正观察点的短对照。RRC首次pending计数没有期望比较是静态；OIB无丢失/元数据是精确二值谓词重放，不是完整系统仿真。没有重复启动全套/长回归。52次既有试验（包括无效setup/负对照）保存evidence/final_trial_inventory.json，不能称52份原TB均通过。

S3：非法watchdog参数elaboration不拒绝（默认Top参数合法，不能升级为默认S1）；C18 maxfine/maxreacquire直接消费者实际PVW；FSC/SUP同号定义与TB场景不同；三个规范依赖仍绑定C09V1.9但目标第3行V1.10，旧sole/current措辞同需统一。54条B规范依赖路径全匹配、3版本不匹配，负对照与中文版本解析fixture已验证；新版本不是据旧标签否定新功能。

ID工作：312明确定义ID、14family语义抽查，逐来源evidence/id_four_link_audit.json。机械引用不是comparison/当前CLOSED：同号错误B-018、旧单元标签不足、history registry及缺同号case均保留。FFK/IDT只复核共享C16所需family场景，不替代C叶子全文主责。INJ/P/N/K相关场景按当前源读取，不混入312定义数量。

已知事项：F-001悬空calibration_loss影响4个注入系统TB，短反证双方同样绑0隔离；F-002身份扩展、F-003漂移锚点/已知§13.1滞后、F-004router合同与实现分别关联，不重复编号。F-005/006/007属D相关保持原编号。tick248基准仍V1.8，不含后续修复；P2S前提更新不在基准；D03/PRC-04/五悬空输出/广播generation豁免按已知范围处理。三份3600秒外部截断回归仍未完成，不判PASS/内部死锁。LFA-10b SKIP保留，OIB只能承接独立非阻断timeout范围，不能证明SSW blocking=1的完整Top正向故障。

最后基准复核：HEAD固定、克隆干净、29文件与Git blob逐字节一致，evidence/final_baseline.json。Python3.12.14、Git2.54.0.windows.1、现有Icarus11.0；七RTL技能AST成功，同版本gate/lint复用的积压12 error/2 warning按规则汇总。未重新执行Vivado xsim/Verilator/综合/STA/PVT。WSL /mnt/c I/O故障经独立/tmp staging绕开，没有重启/挂载/停止A环境。没有运行中的本组任务。

A合并时请读取原始日志和实际源代码，统一去重编号并保留上述范围；本组仅提供交接文件，不自动把本报告内容写入A总报告，也不请求扩大为修复权限。
