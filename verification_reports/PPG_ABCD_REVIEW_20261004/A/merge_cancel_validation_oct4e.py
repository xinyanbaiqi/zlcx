from pathlib import Path
import json,hashlib
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';P=B.parent.parent
GB=P/'01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B';GC=P/'01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C'
refs={
'F-034':[('rtl/ppg_precision_window_controller/ppg_precision_window_controller.v',264,'flag_enter_commit'),('rtl/ppg_precision_window_controller/ppg_precision_window_controller.v',265,'flag_return_commit'),('contracts/PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md',705,'detection discard')],
'F-035':[('rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v',514,'i_control_abort_event'),('rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v',515,'adc_owner_inflight_o <= adc_owner_inflight_o'),('rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v',516,'flag_owner_release')],
'F-036':[('rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v',738,'flag_case_ok'),('rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v',743,'flag_case_ok'),('rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v',746,'check_case("PWI-01"')],
'F-037':[('rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh',796,'flag_jnt_baseline_pass'),('rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh',801,'cnt_error = cnt_error + cnt_run_jnt_fail'),('rtl/ppg_control_top/run_xsim_regression.sh',90,'fail_count=$(grep')],
'F-038':[('rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v',410,'reset_dut'),('rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v',1281,'check_sequential_divider'),('rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v',1303,'check_case("OPT-24"')],
'F-039':[('contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md',210,'不要求预先'),('contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md',249,'不以'),('contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md',295,'才能允许新的START')]
}
records={};quotes={}
for fid,items in refs.items():
 records[fid]=[];quotes[fid]=[]
 for rel,n,key in items:
  raw=(S/rel).read_bytes();l=raw.decode('utf-8-sig').splitlines()[n-1];assert key in l,(fid,n,l)
  records[fid].append({'file':rel,'line':n,'text':l,'sha256':hashlib.sha256(raw).hexdigest()});quotes[fid].append(l.split('//',1)[0].strip())
sims=[]
cases=[(E,n,'native.result.json','native.run.log') for n in ['A_pwc_cancel_commit','A_pwc_cancel_commit_countercontrol','A_ssw_abort_done','A_ssw_abort_done_countercontrol']]
cases.extend((GB/'evidence',n,'result.json','run.log') for n in ['pwi_tail_original_check','pwi_tail_early_overflow_mutant','pwi_tail_sampled_strict','pwi_tail_sampled_strict_early_mutant','top_abort_done_v3','top_abort_done_v3_counterfactual'])
for root,n,meta,log in cases:
 m=json.loads((root/n/meta).read_text(encoding='utf-8'));assert m['compile_rc']==0
 p=root/n/log;raw=p.read_bytes();sims.append({'case':n,'metadata':m,'raw_log':str(p),'log_sha256':hashlib.sha256(raw).hexdigest()})
jntmeta=json.loads((GC/'evidence/targeted_runtime_20261004/results_jnt.json').read_text(encoding='utf-8'))
for m in jntmeta:
 p=GC/'evidence/targeted_runtime_20261004'/m['name']/'run.log';raw=p.read_bytes();sims.append({'case':m['name'],'metadata':m,'raw_log':str(p),'log_sha256':hashlib.sha256(raw).hexdigest()})
(E/'merged_findings_oct4e_refs.json').write_text(json.dumps({'source_refs':records,'simulations':sims},ensure_ascii=False,indent=2),encoding='utf-8')
details={
'F-034':'''### F-034：PWC 当前代际 discard 与安全提交同拍仍改变精度并发事件

- 严重度/层：S1 / RTL；置信度：A独立最小仿真及限定反驳对照确认。关联B-010。
- 位置：`rtl/ppg_precision_window_controller/ppg_precision_window_controller.v:264,265`及C23:705，原文3行：
{quote}
- 描述/依据：两个commit条件未排除flag_lifecycle_cancel；FSM:602优先回IDLE、窗口:340优先清0，但精度:327-330及事件:355-397仍提交，违反C23:703-710 discard高于提交和:779-784的禁止事件规则。
- 证据：A复用已核实公开cross/return激励重跑：STOP/abort/fault三种当前generation discard分别与合法安全边界同拍，enter均`mode=1 window=0 start=1 state=0`，return均`mode=0 window=0 return=1 state=0`；6功能比较FAIL、8setup/旧generation/正常返回PASS，运行1。外部只在两个commit条件加!flag_lifecycle_cancel，同一14比较PASS、运行0，记录evidence/A_pwc_cancel_commit*。
- 反驳：取消FSM不抑制不同always中的commit事件；AMI:962复合safe/970检测discard与:2539/2541传入PWI并未定义二者互斥。真实父链同步同拍仍待完整Top构造，故不称必然新ADC启动或永久死锁。叶子合同明文允许并冻结同拍优先级；已知09-17 PWC修复是START历史sticky，不豁免此项。
- 建议方向：精度、事件和FSM使用一致的取消优先级，并补双向同拍公开输入检查。
''',
'F-035':'''### F-035：SSW abort 同拍吞掉匹配完成，残留 owner 阻断重新 START

- 严重度/层：S1 / RTL；置信度：A独立叶子仿真、已核实真实Top ADC路径及限定对照确认。关联B-012。
- 位置：`rtl/ppg_sar9_sar15_safe_selection_wrapper/ppg_sar9_sar15_safe_selection_wrapper.v:514-516`，原文3行：
{quote}
- 描述/依据：427的flag_owner_release已识别正确sample_index/generation，无ready完成只有一拍，abort保持优先于释放。C09:346-354、678-689冻结匹配完成success0/1都释放owner，取消阻止新模拟/结果处理却不允许丢失释放事实。
- 证据：A叶子独立运行SAR9/SAR15×success0/1，完成前release=1，沿后`recognized=1 inflight=1 idle=0 waveidle=1 physicalidle=1`，20拍后仍占用，8比较FAIL。迟一拍匹配完成、错ID后正确完成两对照PASS；只删除外部副本abort保持两行，同6case全PASS。
- 顶层证据：B top_abort_done_v3使用真实合法MANUAL双光、Q3、CLK_DOUT/RAW，注入参数0、无force。Top:353-357注册abort与AMI:1199-1202注册完成实见同拍`abort=1 completion=1 release=1`。后`SSWowner=1 schedulerowner=0 AMIowner=0`；3拍回CONFIG，physicalidle1/AMIempty1，但SSWidle0；100拍、diag-clear、合法重新COMMIT/START均不清。新RUN7000拍`newowners=0 blocking=1 cause=21`。仅上述两行外部对照，新RUN5拍`newowners=1 lifecycle=2 blocking=0 cause=00`并PASS。A已读公开激励/寄存器实际路径、全部命令与原始日志，索引evidence/merged_findings_oct4e_refs.json。
- 反驳：首次生命周期能够回CONFIG，不误报STOPPING死锁；Top:741-744排空资格确实不含完整SSW idle。owner寄存器仅reset/release/commit改变，START、diag-clear、physicalidle均无清除，generation改变也不能补释放旧owner；正常接口没有补发已消费DONE机制。LFA-04先abort后DONE及旧SSW迟到测试不覆盖同拍。不是冻结D03 cause22或tick-248。
- 建议方向：匹配完成优先释放真实owner，同时取消继续清模拟/结果资格；补完成/abort同拍及跨START恢复检查。
''',
'F-036':'''### F-036：PWI 尾部测试丢弃累计前置判据，第一笔提前报错仍 PASS

- 严重度/层：S2 / TB；置信度：真实PWI链原场景短片段变异确认。关联B-011。
- 位置：`rtl/ppg_precision_window_integration/tb_ppg_precision_window_integration.v:738,743,746`，原文3行：
{quote}
- 描述/依据：前10笔合法、真实fine事件/进入状态累计到flag_case_ok，最终check_case却不使用它，只要求第11笔后已有sticky。PWI-02:758-766的累计变量也未进入769比较。C18:639要求最多10笔合法、第11笔才错误。
- 证据：原PWI-01片段及仅将外部PVW的FIR_GROUP_DELAY_LIMIT从10改0的变异，均1 PASS/0 FAIL，`saved_preconditions=0`，运行0。直接加flag_case_ok连原RTL也FAIL，因为738读取事件计数尚未经过下一计数沿。补一个negedge观察并使用累计值：原链`count=1 B_TAIL10 sticky=0 saved=1`最终PASS，提前报错变异`sticky=1`最终FAIL、运行1。A已核对单行变异、公开激励、原始日志及采样原因。
- 反驳：PVW其他独立尾部测试有效，不能使此PWI集成项真实检验进入期间前10笔行为；不据变异称原RTL尾部错误。已知C18:690说明PWI06..10缺独立TB，不在本项重复上报。没有运行完整5项变异，仅报告原PWI-01片段和PWI-02静态同构遗漏。
- 建议方向：修正观察时点并将累计判据纳入终判，保留提前报错负对照。
''',
'F-037':'''### F-037：JNT 数量不足不增加统一错误数，官方统计也漏 status=FAIL

- 严重度/层：S2 / TB·运行判据；置信度：检查器原分支短仿真、调用方及脚本静态确认。关联C-008。
- 位置：`rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh:796,801`及`rtl/ppg_control_top/run_xsim_regression.sh:90`，原文3行：
{quote}
- 描述/依据：检查数量/通过数不足时flag为0且打印JNT status=FAIL，却只加单项失败数；已执行子检查全成功时错误数仍0。所有flag使用只在该头自身306/796/797，ADCN:1178等调用方不验证flag，继续组场景并最终按cnt_error判定。C25:442-443要求JNT不足时整个组失败，当前头要求54项。
- 证据：C真实原分支提取短仿真54/54正常PASS；51/51单项fail0打印`status=FAIL`又`GROUP_WOULD_PASS error_count=0`，独立断言fatal运行1；外部数量不足至少加1的限定对照errors1运行0。A读取三份短TB、原始日志和实际源分支。官方脚本仅统计`^FAIL |ERROR:|FATAL_ERROR|UVM_ERROR`，此JNT行不匹配；它只输出统计表，并没有独立JNT前提检查。
- 反驳：正常真实54项运行有效，不称当前未改系统TB只执行51项；每项真实比较也没有因此失效。数量缺失场景仅短检查器，不是完整系统变异。日志本身已有FAIL可供外层更严格审计拒绝，本报告审计器补入status=FAIL判据；不能据error_count0或官方fail_count0判通过。旧52/53注释、TRK01等接受项不覆盖统一失败计数。
- 建议方向：数量不足进入统一错误计数，调用方和运行判据明确核验JNT前提。
''',
'F-038':'''### F-038：OPT-23/24 没有构造连续周期和随机正式最终结果差分

- 严重度/层：S2 / TB；置信度：静态确认覆盖义务与实际激励/比较不符；未运行本项新的全TB变异。关联C-009。
- 位置：`rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v:410,1281,1303`，原文3行：
{quote}
- 描述/依据：OPT23的两次check_sequential_divider都reset+START，不能证明无复位的两个完整周期不复用旧pending；OPT24随机32次同样每次reset，独立比较是内部42轮商及周期数426，不比较随机事务的最终平滑/提交结果。C21:589-592要求连续完整周期及所有合法随机正式结果逐位一致，覆盖正负平滑、无相交、lead三区间、短回绕和饱和。
- 反驳/证据：原商golden、42轮计数、其他固定场景及共享乘法局部监视均有效，原65 PASS不否定这些真实检查。phase_a_equivalence的20005向量无DUT，只证明窄宽公式等价；公开独立算术边界向量每组独立运行，也不验证连续pending。系统连续波形B[f]比较使用DUT报告斜率，不能替代最终斜率独立随机参考。只报这两项覆盖声明不足，不宣称原数值RTL错误。
- 建议方向：增加不复位双周期和从合同/公开输入独立计算的最终参考，并做旧pending/最终提交变异抽查。
''',
'F-039':'''### F-039：表征控制合同复位后的 START 前提与自身模式例外矛盾

- 严重度/层：S3 / 合同；置信度：静态确认。关联D-008。
- 位置：`contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md:210,249,295`，原文3行：
{quote}
- 描述/依据：同一现行正文§9/10允许NORMAL和外部固定电流以复位安全默认控制启动，§11不限定模式又要求所有新START先做6-bit提交；版本勘误没有覆盖该冲突。
- 反驳/证据：STATIC_BIAS确有valid1/enable1前提，本项不否认；Top:851/853区分已提交enable/valid，:746给manager的资格不将ccc_valid作为NORMAL/固定电流硬门控。D固定电流未变异短场景无6-bit提交、直接V4/V5 COMMIT/START后真实RED/IR各3笔支持实现选择。共同复位:297解决toggle代际不解决模式矛盾。F-007复位架构及已知N04/P2S事项不同。
- 建议方向：明确§11前提的模式范围；若要求所有模式重提，应由设计方裁定并统一其他条款。
'''
}
p=B/'PPG_FULL_REVIEW_20261002.md';t=p.read_text(encoding='utf-8')
for fid,body in details.items():
 if '### '+fid in t:continue
 q='```text\n'+'\n'.join(quotes[fid])+'\n```';body=body.replace('{quote}',q)
 pos=t.index('### F-001' if fid in ('F-034','F-035') else '### F-002' if fid!='F-039' else '## 4. 已知事项');t=t[:pos]+body+'\n'+t[pos:]
if '## 取消与验证检查点：2026-10-04e' not in t:t+='\n## 取消与验证检查点：2026-10-04e\n\nF-034～039核实18处精确原文、A独立PWC/SSW四次运行、PWI四对照、真实Top恢复两对照及JNT三对照。共39条；完整smoke错误期望变异真实SMOKE_TB_FAIL error_count=1，确认TOP-18判据能生效。其余未完成检查不升级。\n'
p.write_bytes(t.replace('\n','\r\n').encode('utf-8'));print('MERGED',list(details),'SIMS',len(sims))
