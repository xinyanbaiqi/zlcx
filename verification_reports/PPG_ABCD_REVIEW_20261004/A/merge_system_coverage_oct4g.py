from pathlib import Path
import json,hashlib
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';GB=B.parent.parent/'01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B'
refs={
'F-040':[('rtl/ppg_control_top/tb_ppg_control_top_injection.v',1006,'i_test_identity_inject_valid'),('rtl/ppg_control_top/tb_ppg_control_top_injection.v',1007,'i_test_invalid_sample_valid'),('rtl/ppg_control_top/tb_ppg_control_top_injection.v',1008,'drive_real_adc_done')],
'F-041':[('rtl/ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v',1056,'cnt_frame_before_pending'),('rtl/ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v',1067,'flag_pending_before_fine_window'),('rtl/ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v',1071,'configured interval=30')],
'F-042':[('rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v',951,'o_result_frame_id == reg_last_result_frame_id'),('rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v',956,'cnt_duplicate_or_relabel_violation'),('rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v',1875,'no loss/duplication/recoloring')],
'F-043':[('contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md',201,'precision controller'),('rtl/ppg_precision_window_integration/ppg_precision_window_integration.v',842,'i_max_fine_window_frames'),('rtl/ppg_precision_window_integration/ppg_precision_window_integration.v',843,'i_max_reacquire_frames')],
'F-044':[('rtl/ppg_control_top/tb_ppg_control_top_injection.v',783,'i_test_inject_enable'),('rtl/ppg_control_top/ppg_control_top.v',392,'wrapper_run_enable_o'),('contracts/PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md',714,'locked on accepted START')]
}
saved={};quotes={}
for fid,items in refs.items():
 saved[fid]=[];quotes[fid]=[]
 for rel,n,key in items:
  raw=(S/rel).read_bytes();line=raw.decode('utf-8-sig').splitlines()[n-1];assert key in line,(fid,n,line)
  saved[fid].append({'file':rel,'line':n,'text':line,'sha256':hashlib.sha256(raw).hexdigest()});quotes[fid].append(line.split('//',1)[0].strip())
sim=[]
for n in ['inj_mutex_original','inj_mutex_original_mutant','inj_mutex_eligible_v2','inj_mutex_eligible_v2_mutant','p06_target_enable','p06_target_enable_mutant']:
 d=GB/'evidence'/n;m=json.loads((d/'result.json').read_text(encoding='utf-8'));assert m['compile_rc']==0
 raw=(d/'run.log').read_bytes();sim.append({'case':n,'metadata':m,'raw_log':str(d/'run.log'),'log_sha256':hashlib.sha256(raw).hexdigest()})
for n in ['A_oib06_checker','A_rrc01_checker']:
 d=E/n;m=json.loads((d/'native.result.json').read_text(encoding='utf-8'));assert (m['compile_rc'],m['run_rc'])==(0,0)
 raw=(d/'native.run.log').read_bytes();sim.append({'case':n,'metadata':m,'raw_log':str(d/'native.run.log'),'log_sha256':hashlib.sha256(raw).hexdigest()})
(E/'merged_findings_oct4g_refs.json').write_text(json.dumps({'source_refs':saved,'simulations':sim},ensure_ascii=False,indent=2),encoding='utf-8')
details={
'F-040':'''### F-040：INJ-04 在两类注入均未就绪的窗口检查互斥，删门控仍 PASS

- 严重度/层：S2 / TB；置信度：真实Top原场景短片段变异确认。关联B-013。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_injection.v:1006-1008`，原文3行：
{quote}
- 描述/依据：995-1004只在DONE到达前重叠请求4拍，再撤销valid才投递DONE。AMI:1012 identity-ready需completion_pending/S1valid；:1013 invalid-ready需真实NORMAL DC transfer，重叠窗口两者都未出现。C01 TOP-24:936及:946把该项作为双请求互斥闭合，不能以未就绪时ready0证明处理窗口互斥。
- 证据：B复用真实合法COMMIT/START/Q3和原INJ04，双方将F-001相关cal-loss valid绑0隔离已知X；原RTL与仅删1012/1013两互斥项的外部变异，均4条PASS、运行0，`window_cycles=4 eligible_cycles=0 ready_cycles=0`。保持双请求穿过真实DONE的补充窗口，原`eligible2 ready0`、变异`eligible4 ready1`且独立ready错误检查fatal运行1。A已读刺激、差异和原始日志；v2补充后续还重复驱动一次DONE，不据该补充序列宣称全协议无错误，其首次真实eligible/ready旁证足以分辨门控。
- 反驳：INJ02/03分别验证单请求，不能覆盖双valid同拍门控；原互斥RTL正确，本项是TB窗口错误。Top锁存enable不是两个请求资格，不能补这一交叠。非F-001悬空输入原因，变异对照已一致隔离；未声称完整15 PASS变异逃逸。
- 建议方向：在真实两类处理资格窗口持续检查ready/fire、副作用及owner身份，使用单笔合法DONE。
''',
'F-041':'''### F-041：RRC-01 只打印首次 pending 帧数，没有比较配置间隔

- 严重度/层：S2 / TB；置信度：静态确认及原终判短Verilog确认。关联B-014。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_periodic_recheck_recovery.v:1056,1067,1071`，原文3行：
{quote}
- 描述/依据：497-498设间隔30、865-869数真实宏帧，1056保存首次pending计数；终判只要求pending曾出现，未比较应于30帧到期，也未比较双光owner和整帧比率。C16:415-420规定单位为完整NORMAL帧而非单个颜色事务。
- 证据：A提取1067-1072原分支实际编译0运行0，计数30和错误计数1均打印PASS，分别`after 30 ... configured interval=30`、`after 1 ... configured interval=30`；pending从未出现负对照真实FAIL。日志evidence/A_rrc01_checker。不使用该短检查器宣称改RTL间隔后完整RRC会通过。
- 反驳：AMR单位TB有正确周期证据，不能让这份集成检查验证传入的真实事件来源/间隔；后续RRC12有部分码保持比较，也无该到期等式。只报此系统验收声明，未声称周期计数RTL错误或全项目无覆盖；不重复F-009物理宏帧多拍。
- 建议方向：在完整宏帧完成沿逐次核验pending到期边界，并核对同窗双色owner增量。
''',
'F-042':'''### F-042：OIB-06 的排序和重复判据不能证明无丢失及三类元数据错标

- 严重度/层：S2 / TB；置信度：原监视器/终判短Verilog及跨场景静态确认。关联B-015。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_owner_identity_backpressure.v:951,956,1875`，原文3行：
{quote}
- 描述/依据：946-960只检测(frame,sample)递减或相等；颜色/type/precision仅锁存/打印，未与每笔owner期望队列比较，也无数量守恒。C25:684规定无loss/duplication/recoloring/retyping/precision relabeling；别名174/176声称全部已覆盖。
- 证据：A直接复制942-967监视器与1868-1876终判，输入合法16位二值结果流。基准四笔及分别漏第2笔、翻color、改type、改precision四反例均`errors=0`并原OIB06 PASS；重复/倒序两个已知错误负对照各`errors=1`且FAIL，编译0运行0。evidence/A_oib06_checker及stream_interval_checker_evidence_A.json。只证明原判据盲点，不冒称完整1887行TB的RTL变异通过。
- 反驳：OIB07:1670-1671确有一笔frame/sample/color/precision比较，OIB09:1567/1621有两笔前后epoch核对；不能将这些有限真检查扩大为全stream、type及丢失检测。与F-017不同TB/验收义务，与F-003旧行号不同；原元数据RTL未证明错误，已知事项不豁免此项。
- 建议方向：从真实owner与合法discard维护期望队列，逐transfer比较身份/元数据并核对守恒。
''',
'F-043':'''### F-043：C18 窗口长度配置的直接消费者写成了 PWC

- 严重度/层：S3 / 合同；置信度：静态确认。关联B-017。
- 位置：`contracts/PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:201`、PWI RTL:842/843，原文3行：
{quote}
- 描述/依据：表196明文为直接子模块消费者；实际两输入只送803开始的PVW实例，PWC声明60-156没有这两端口。窗口计数/超时由PVW拥有，PWC依据返回请求做安全精度提交。
- 反驳/证据：全PWI例化和PWC/PVW公开端口已查；配置未丢失，不报RTL功能错误。“间接影响精度”不能使直接消费者表成立。C23未要求PWC另收两字段，C18其他职责段落也指PVW。非F-003引用偏移，行201本身语义错。
- 建议方向：统一直接消费者与真实窗口/返回/精度提交所有权。
''',
'F-044':'''### F-044：疑似——P06 动态闭合是否需要叶子去使能，范围尚待裁定

- 严重度/层：S2 / TB·跨层（疑似）；置信度：疑似，刺激到达事实已仿真确认，但合同允许的覆盖范围尚不能判为新错误。关联B-016，**不计已确认发现**。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_injection.v:783`、Top RTL:392、C10:714，原文3行：
{quote}
- 描述：TB拉低Top源enable后仍见AMI hold1；Top RUN锁存使叶子enable实际仍1。若P06闭合要求AMI端实际去使能，该动态证据未构造它；若接受合法系统源去使能加Top锁存结构证明，则该场景确实证明了系统性质，不能报成验证错误。
- 证据：原场景短链与在外部AMI副本加!enable清hold的错误分支，均3 PASS、运行0，`outer_enable=0 leaf_enable=1 hold=1 abort=0`及`leaf_disable_cycles=0`。双方隔离F-001。A已核对原实际接口、公开激励、变异及日志，evidence/merged_findings_oct4g_refs.json。
- 反驳：C10:712-714明文控制只能由Top注册源进入、START后锁定并忽略RUN源改变；这使所提叶子去使能在合法RUN结构上不可达。C10:715及矩阵P06:928的AMI request-slot保持义务仍可由当前寄存器静态规则支持。不能仅凭不触发的叶子变异将已被另一机制覆盖的性质判失效。TRK01的既有结构豁免针对其他ID，是否采用类似静态闭合需接口owner明确。
- 缺失证据/建议方向：明确P06要求的入口层与可接受静态闭合证据；若要独立叶子动态证明，再用合法叶子场景实降输入。这里不请求修改RTL，也不升级为芯片功能错。
'''
}
p=B/'PPG_FULL_REVIEW_20261002.md';t=p.read_text(encoding='utf-8')
for fid,body in details.items():
 if '### '+fid in t:continue
 body=body.replace('{quote}','```text\n'+'\n'.join(quotes[fid])+'\n```');pos=t.index('### F-002' if fid!='F-043' else '## 4. 已知事项');t=t[:pos]+body+'\n'+t[pos:]
if '## 系统覆盖检查点：2026-10-04g' not in t:t+='\n## 系统覆盖检查点：2026-10-04g\n\nF-040～043四项已独立复核确认；F-044保留疑似范围裁定，不直接采信B-016的S2确认，因为Top锁存为合同明文的合法系统机制。新增A原OIB/RRC检查器短Verilog及正负对照，复核B真实INJ/P06六运行原始证据。共43已确认、1疑似，等待刷新总表。\n'
p.write_bytes(t.replace('\n','\r\n').encode('utf-8'));print('MERGED',list(details),'confirmed_new4','suspected1')
