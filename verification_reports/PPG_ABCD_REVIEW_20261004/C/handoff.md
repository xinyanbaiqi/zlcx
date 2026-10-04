# C 数值专项交接

固定基准 d18c6954621e53e5a6505dd3a6c688c266d23839。C主责44/44文件的全文语义审阅已完成，源码只读未修复；最终功能签核仍未完成。

输出目录：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C
报告：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/PPG_REVIEW_C.md
逐项台账：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/coverage.csv
证据目录：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/

## A应合并的结论

C001 S3→F015、C002 S2→F026、C003 S2→F027、C004 S1→F018已在A总报告出现，避免重复。C004公开合法叶子return反压frame10变21，protocol sticky=0；A真实先消费旧return的对照也已通过。

其余待A复核统一编号：C005 S2 IDAC模块TB低码范围漏sum8（C专项8字面中点拒绝该变异、原Unit148 PASS；SID耗尽可补高码系统行为，所以不扩大为全系统盲区）；C006 S3 C17 diag/status-clear原型不一致；C007 S3 C17不变AMB不重验与C16/实际固定trio冲突；C008 S2 JNT计数不足分支保持error_count0（3个独立收尾短探针，不是完整系统变异）；C009 S2 OPT23 reset两次、OPT24仅随机商，不满足连续周期/随机最终正式结果义务（静态确认，无新增全TB变异）。共9项：S1=1、S2=5、S3=3。

## 逐项证据

- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/id_review_matrix.csv：355个合同表列ID，255审阅裁定完成、100动态/跨组部分；不是355全部PASS。C13无编号ID表，§7五验收项随ADC笔记核对。
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/port_review_matrix.csv：当前formatter AST的796端口，12模块；人工全头/字段打包/生产消费者核对与例外见报告。
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/contract_version_matrix.csv：11合同当前页眉/依赖；旧行号重定位，关联F003，保留C001/006/007冲突。
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/final_deliverable_gate.json和.md：真扫12文件，AST12/12/0 parse_error，lint0；原始strict errors92=VG0522+VG0613+VG0661+COMMENT_COMMENT_PLACEMENT86，strict_warnings0，delivery_ready=false。此前逐单文件comment scanned_files0的PASS不能作为有效门禁；C改对字节相同RTL目录运行，无源修改。风格只汇总，不逐条编号。
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/targeted_runtime_20261004/：plan/results及compile/run.log；恢复后16个短case，含预期失败；FIR8向量/系数变异早期日志另存。DC原始公开两端饱和通过、错误期望拒绝；JNT54正常通过、51不足原分支漏计失败、独立计数对照拒绝。
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/system_compare_*.json和system_diff_*.patch：peak/tail/track共同原文精确映射+全部差异实读；baseline全文实读。相同块继承已审baseline语义，不虚称重复展示。
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/adc_reference/omitted_inputs.json：已补fork10项，4TB总29；formatter端口行号与真实编译warning。
- C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/final_readonly_check.json和git_readonly_check.json：44主责Git blob均匹配固定提交、12临时RTL字节相同，clone HEAD固定、status短输出为空；safe.directory仅命令参数，未写Git配置。

## 保留的未完成项

A同版本完整运行抓取：C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/A_regression_C_scope_snapshot.json；C归属15 TB结束0 FAIL，baseline_cross、peak_valley_return、fir_tail_isolation、normal_slow_tracking四份系统TB未完成，未重复长跑、未记PASS或死锁。完整动态验收与其它系统家族100个部分ID、Vivado xsim/综合、ASIC时序/CDC均待相应主责/工具，coverage.csv保持30个部分检查行。完整回归是A管理范围，C只跑必要短专项。

C11/C14/C15 discard/localempty条件豁免已重新定位成立；TRK01结构豁免保留；ADCN07和饱和历史修复存在不重报。ADCN08原子正式measurement数值保持不等于另一detection分支sample-valid独立，关联B/A真实F021；周期超时链关联F020，不重复C编号。阶段性笔记的待执行描述已由末尾补充和最终报告覆盖，历史报告保存在C:/Users/DAWN/.codex/visualizations/2026/10/02/01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C/evidence/PPG_REVIEW_C_batches_1_6.md。

本组审阅交接完成；9项修复和最终签核未完成，不申请修改共享源码，不发送跨对话消息。
