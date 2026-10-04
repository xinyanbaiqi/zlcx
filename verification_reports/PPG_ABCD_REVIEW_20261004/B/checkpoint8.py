from review import *
p=OUT/'PPG_REVIEW_B.md'
text='''
## 批次8：身份断言反驳、使能到达与消费者核对

### B-015 — OIB-06只有排序/重复比较，未验证无丢失与元数据错标

- S2 / TB；静态确认并有精确二值谓词反例。位置：`rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v:946-960,1868-1875`；直接需求 `contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:684`；别名表`:174,176`宣称所有五类均已检测。OIB-06以frame/sample递减或等于上一结果作唯二错误条件，color/type/precision仅锁存、打印，没有期望owner队列、数量守恒或对应字段比较。
- 原文（2行）：`end else if((o_result_frame_id == reg_last_result_frame_id) && (o_result_sample_index == reg_last_result_sample_index)) begin` / `$display("PASS OIB-06 result stream preserved order with no loss/duplication/recoloring/retyping/precision-relabeling across %0d real transfers", cnt_result_capture);`。
- `predicate_counterexamples.py`及`evidence/oib06_predicate_counterexamples.json`：核对当前源码两条实际谓词后，对连续唯一身份的四笔结果分别丢一笔、翻color、改type、改precision；四种反例均产生0错误，最终OIB-06 gate仍PASS。重复和递减两个阳性对照各产生1错误。这里只是二值静态谓词重放，未冒称全系统RTL仿真或元数据RTL已错。
- 反驳：OIB-07在`:1670-1671`确实对一笔事务比较frame/sample/color/precision；OIB-09在`:1567,1621`对两笔真实调码前后RED结果比较该帧epoch。因此不是全项目没有字段检查。它们不覆盖OIB-06连续stream的全部事务、type或丢失，不足以支持本项的全程PASS描述。已知F-003是失效行锚点；这里是有效代码里缺少语义判据，相关但不重复。
- 建议：从真实owner提交/受控discard维护期望队列，在每次formal transfer逐字段核对且核算剩余队列。置信度：静态确认/谓词负对照。

### B-016 — P06去使能刺激被Top RUN锁存屏蔽，叶子错误负对照仍PASS

- S2 / TB与闭合证据。位置：`rtl/ppg_control_top/tb_ppg_control_top_injection.v:783-789`；`rtl/ppg_control_top/ppg_control_top.v:387-398,1364`；`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1573-1580`；矩阵P06 `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:928`和别名表`:467`。测试在RUN内将source配置请求i_test_inject_enable置0；Top只在!run_enable时跟随该请求，RUN内AMI收到的effective enable保持1。故该检查未验证AMI request-slot在实际去使能后的保持规则。
- 原文（2行）：`end else if(!wrapper_run_enable_o) begin` / `flag_test_inject_mode_latched <= i_test_inject_enable;`。
- `short_p06.py`及`evidence/p06_target_enable*`：复用真实合法COMMIT/START、Q3和RAW/DONE，再原样复用INJ-02到P06检查；双方隔离F-001，将复制TB的calibration_loss valid绑0。原RTL与仅在AMI hold寄存器新增!i_test_inject_enable清零的错误副本，均3个PASS、0FAIL；trace为outer_enable=0 leaf_enable=1 hold=1 abort=0，outer_disable_cycles=1/leaf_disable_cycles=0。双posedge等待里下降沿可见一次外部低电平，该统计只是可观测采样数，不把它误写为外部仅保持一拍。初次脚本定位假定源码always有空格，匹配失败未执行仿真；已改用实读位置+内容断言。
- 反驳：Top锁存本身正是C01/AMI约定的合法行为，不是RTL错；AMI真正的hold逻辑也确实没有enable清零，P06性质由静态源码支持。问题是矩阵把没有到达目标输入的刺激写成动态闭合证据。自动abort另外会合法清hold，并不能让刺激到达AMI。建议增加AMI叶子场景，在真实fire之后直接拉低其输入、连续比较原身份与hold，或将系统证据改为Top RUN模式锁存范围。置信度：真实短仿真与错误负对照。

### B-017 — C18窗口长度字段的直接消费者标错

- S3 / 合同；静态确认。位置：`contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:196-201`，实际PWI `rtl/ppg_precision_window_integration/ppg_precision_window_integration.v:803-843`与PWC`:60-156`端口全文。
- 原文（1行）：`| i_max_fine_window_frames, i_max_reacquire_frames | precision controller |`（原Markdown含代码反引号）。表头明确“直接子模块消费者”，但两个字段仅连接peak/valley detector例化的同名输入，PWC完全没有这两个端口。PWC按真实peak/valley返回请求执行安全切换，窗口计数/超时归PVW；配置没有丢失，此项不能升级为功能缺陷。
- 反驳：C23没有要求PWC另设这两个输入，C18其它段落也描述PVW窗口/重新获取职责，无法用“间接影响precision”解释直接消费者表。与F-003锚点老化不同，这行本身明确错误。建议把直接消费者更正为peak/valley detector，并保留PWC的请求/提交职责。置信度：静态确认。

### OIB其余检查与版本口径

OIB1887行执行代码已全部审阅，main884-1887原文完成。OIB-03反压分支只在阻塞驱动任务返回时检查valid保持，没有全周期payload稳定比较；STOP/reset支具备真实held-result前提，STOP支比较恰好一次discard但不比其identity（B-006专项已给双事务反例）。OIB-05与LFA-07同样只在完全STOP排空、未武装状态呈交重复DONE。OIB-07的commit snapshot确实逐字段实比。OIB-09真正观察码改变和后来frame-latched epoch改变，比before/after formal epoch；before/after轮询有上界但未先显式拒绝valid未到的情况，不过后续字段case-inequality通常捕获不匹配，不用疑似问题凑新条。

LFA-10b明确SKIP是真实限度，不能算PASS；声称由OIB-01承接，只限非阻断launch-timeout与SSW blocking=0区分（OIB:1738-1752），并不动态验证SSW真正blocking fault=1形成记录。C24单元SUP源仲裁有独立输入为1覆盖，Top连接可静态核对，不能偷换成SSW真实源的整机正向构造。OIB-01恢复分支实际STOP+drain+diag_clear+recommit+START；未证明同一RUN的下一宏帧自动恢复（:1756-1762已明示），保留为测试范围限制。

C08/C09/C10/C18存在“更新修订记录较新、sole/current normative正文仍指定旧版”的并置：例如C09:3 V1.10、:7 sole V1.9、:9 sole V1.8；C18:3 V2.1而:4 current V2.0。当前依赖表和新增条目确实保留新能力，不把较早版本的历史标签单独解读为禁止新端口；这种版本权威措辞仍需统一，供A合并文档一致性项。旧checklist/ADC-IDAC SPEC已按当前矩阵non-normative边界处理，不据其旧实现状态报功能错。

当前新发现B-001..017。剩余：长文件内联注释全面收尾、ID机械关联与各family语义抽查、覆盖/交接最终一致性复核。共享源码未修改，未新跑长回归。
'''
p.write_text(p.read_text(encoding='utf-8')+text,encoding='utf-8')
rows=list(csv.DictReader((OUT/'coverage.csv').open(encoding='utf-8-sig')))
for r in rows:
 if 'owner_identity_backpressure' in r['path']:
  r.update(status='部分',evidence='执行代码全文；main884-1887原文；B-015谓词反例；共用任务SHA关联',remaining='文件头/共享任务注释、全family ID及最终证据一致性收尾')
with (OUT/'coverage.csv').open('w',encoding='utf-8-sig',newline='') as fp:
 w=csv.DictWriter(fp,fieldnames=rows[0].keys());w.writeheader();w.writerows(rows)
(OUT/'protocol_table.md').write_text((OUT/'protocol_table.md').read_text(encoding='utf-8')+'''
| OIB-06 stream identity | decreasing/equal frame+sample alone rejected; unique wrong metadata or missing result accepted by this gate | B-015; OIB-07 is a separate one-transaction field comparison |
| P06 enable deassert | RUN freezes Top latched injection mode, so source enable=0 still AMI enable=1 | B-016 original and leaf-clear-on-disable mutant pass; target condition never occurs |
| fine/reacquire configured lengths | PWI sends both directly to PVW; PWC receives derived return requests | B-017 C18 direct-consumer table says PWC incorrectly |
''',encoding='utf-8')
(OUT/'handoff.md').write_text((OUT/'handoff.md').read_text(encoding='utf-8')+'''
批次8：B-015 S2 OIB-06无丢失/换色/换型/精度错标判据，二值谓词反例全逃逸；OIB-07单笔真实比较仍有效。B-016 S2 P06去使能被Top锁存屏蔽，AMI leafenable仍1，加入leaf禁用清hold错误分支依然PASS。B-017 S3 C18 maxfine/maxreacquire直接消费者实际PVW不是PWC。当前B-001..017；六份系统TB执行代码/新增场景正文均审完，文件头及内联注释与ID最终闭环仍在推进。无运行中仿真、无长回归、未改共享代码。
''',encoding='utf-8')
print('batch8 saved')
