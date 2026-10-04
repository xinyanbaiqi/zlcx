from review import *
from collections import Counter
import re

baseline=json.loads((OUT/'evidence/final_baseline.json').read_text(encoding='utf-8'))
assert baseline['head_matches'] and not baseline['clone_status_porcelain']
assert len(baseline['files'])==29 and all(x['same_as_git'] for x in baseline['files'])
line_counts={x['path']:x['lines'] for x in baseline['files']}
id_data=json.loads((OUT/'evidence/id_four_link_audit.json').read_text(encoding='utf-8'))
assert len(id_data['rows'])==312 and all(id_data['negative_controls'].values())
dep=json.loads((OUT/'evidence/dependency_bindings.json').read_text(encoding='utf-8'))
assert len(dep['bindings'])==54 and sum(not x['version_matches'] for x in dep['bindings'])==3
assert all(x['path_matches'] for x in dep['bindings'])

# file/line anchors are verified against actual source, not offset arithmetic.
def rtl(module,tb=False):return f'rtl/{module}/{"tb_" if tb else ""}{module}.v'
AMI='ppg_adc_measurement_idac_integration';FSC='ppg_400hz_frame_calibration_scheduler';SSW='ppg_sar9_sar15_safe_selection_wrapper';AMR='ppg_amb_recheck_scheduler';PWC='ppg_precision_window_controller';PWI='ppg_precision_window_integration';SUP='ppg_system_fault_abort_supervisor'
def contract(name):return 'contracts/'+name+'.md'
C08=contract('PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT');C09=contract('PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT');C10=contract('PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT');C16=contract('PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT');C18=contract('PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT');C23=contract('PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT');C24=contract('PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT')
def sys_tb(name):return 'rtl/ppg_control_top/tb_ppg_control_top_'+name+'.v'
findings=[
 (1,'S3','watchdog非法参数未拒绝',C24,41,'Elaboration',['supervisor_invalid_width'],[rtl(SUP)]),
 (2,'S2','历史未clear的rearm前提未测',rtl(SUP,True),475,'SUP-10',['supervisor_original_rearm_mutant','supervisor_extended_rearm_mutant'],[C24]),
 (3,'S1','NORMAL宏帧5001拍',rtl(FSC),752,'flag_frame_start_eligible',['scheduler_cadence'],[C08]),
 (4,'S2','周期容差及Q3固定资格掩盖错误',rtl(FSC,True),581,'check_fsc(14',['scheduler_original_q3_gate_mutant','scheduler_early_q3_mutant'],[C08]),
 (5,'S1','CAL末拍rollover覆盖abort',rtl(FSC),855,'flag_calibration_rollover',['scheduler_abort_tick4999','scheduler_abort_tick4998'],[C08]),
 (6,'S1','formal discard身份取错fork',rtl(AMI),1296,'dec_measurement_frame_id',['discard_identity_two','discard_identity_one'],[C10]),
 (7,'S1','periodic deadline只释放外层inflight',rtl(AMR),208,'flag_sample_inflight',['recheck_deadline_v4','recheck_control'],[rtl(AMI),rtl(PWI),C10,C16]),
 (8,'S1','measurement消费清除detection资格',rtl(AMI),1238,'flag_measurement_transfer',['branch_qualification'],[C10]),
 (9,'S1','AMI START清历史sticky',rtl(AMI),1186,'i_start_ack_event',['ami_sticky_start'],[C10]),
 (10,'S1','PWC同拍discard仍commit及发事件',rtl(PWC),264,'flag_enter_commit',['pwc_cancel_commit','pwc_cancel_commit_counterfactual'],[C23,rtl(AMI)]),
 (11,'S2','PWI尾部累计判据未使用',rtl(PWI,True),743,'flag_case_ok',['pwi_tail_sampled_strict','pwi_tail_sampled_strict_early_mutant'],[C18]),
 (12,'S1','SSW abort同拍吞匹配完成',rtl(SSW),514,'i_control_abort_event',['top_abort_done_v3','top_abort_done_v3_counterfactual'],[C09,rtl(AMI),sys_tb('lifecycle_fault_adc_anomaly')]),
 (13,'S2','INJ互斥在ready不可能的窗口检查',sys_tb('injection'),996,'i_test_identity_inject_valid',['inj_mutex_eligible_v2','inj_mutex_eligible_v2_mutant'],[rtl(AMI)]),
 (14,'S2','RRC间隔只打印未比较',sys_tb('periodic_recheck_recovery'),1067,'flag_pending_before_fine_window',[],[C16]),
 (15,'S2','OIB stream缺无丢失及元数据比较',sys_tb('owner_identity_backpressure'),946,'o_result_frame_id',['oib06_predicate_counterexamples.json'],[]),
 (16,'S2','P06禁用未到达AMI输入',sys_tb('injection'),783,'i_test_inject_enable',['p06_target_enable','p06_target_enable_mutant'],[rtl(AMI),'rtl/ppg_control_top/ppg_control_top.v']),
 (17,'S3','C18窗口长度直接消费者标错',C18,201,'precision controller',[],[rtl(PWI),rtl(PWC)]),
 (18,'S3','合同与TB同号场景语义错位',C08,1135,'FSC-03',['id_four_link_audit.json'],[rtl(FSC,True),C24,rtl(SUP,True)]),
 (19,'S3','C09当前版本及依赖台账不一致',C24,17,'V1.9',['dependency_bindings.json'],[C09,C08,C10,'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md'])
]
rows=[]
for num,severity,title,path,line,token,evidence,related in findings:
 lines=(SNAP/path).read_text(encoding='utf-8-sig').splitlines()
 if len(sys.argv)>1 and sys.argv[1]=='locate':
  matches=[(n,s.strip()) for n,s in enumerate(lines,1) if token in s and abs(n-line)<22]
  if not matches:matches=[(n,s.strip()) for n,s in enumerate(lines,1) if token in s][:3]
  print(num,Path(path).name,'expected',line,'actual',matches)
  for e in evidence:
   if not (OUT/'evidence'/e).exists():print('missing evidence',num,e)
  continue
 # Assert the exact cited line contains the expected text. Any disagreement
 # stops finalization so it can be manually relocated before publication.
 assert token in lines[line-1],(num,path,line,lines[line-1],token)
 for e in evidence:assert (OUT/'evidence'/e).exists(),(num,e)
 rows.append({'id':f'B-{num:03d}','severity':severity,'title':title,'path':path,'absolute_source_path':(SNAP/path).as_posix(),'line':line,'verified_source_text':lines[line-1].strip(),'related_paths':'; '.join(related),'evidence':'; '.join('evidence/'+e for e in evidence) or '静态源文件/合同全文；见报告对应项','status':'发现确认；未修复；不等于全系统动态签核'})
if len(sys.argv)>1 and sys.argv[1]=='locate':
 print('Evidence trial directories:',', '.join(p.name for p in sorted((OUT/'evidence').iterdir()) if p.is_dir() and p.name!='skill'))
 sys.exit(0)
def write_csv(name,items):
 with (OUT/name).open('w',encoding='utf-8-sig',newline='') as fp:
  w=csv.DictWriter(fp,fieldnames=list(items[0]));w.writeheader();w.writerows(items)
write_csv('findings_index.csv',rows)

# These are review states. Defect disposition and full-regression evidence
# remain separate from the completed file reading and checking work.
meta={
 'ppg_adc_measurement_idac_integration':('C10 §§6-18 / AMI-01..54 / N08 / P01-P06','B-006/007/008/009；TB关联F-001及B-013/016','端口/位宽/寄存复位；ADC armed/owner identity与generation；completion/discard流水与双fork；独立资格与sticky；取消/故障优先级'),
 'ppg_400hz_frame_calibration_scheduler':('C08 §§4-20 / FSC-01..57 / SID-05 / LFA-06','B-003/004/005/018；已知tick248保持关联','宏帧与子周期边界；waveform/owner分离；握手冻结与真实fire编号；deadline/Q3/success=0释放；START/STOP/abort同拍及位宽'),
 'ppg_amb_recheck_scheduler':('C16 §§9-14 / AMR-01..14 / RRC / NRE','B-007；RRC覆盖限制B-014','完整NORMAL帧计数与饱和/interval0；pending与15到9等待；六项safe条件；内层inflight；三阶段结果/物理帧顺序及取消恢复'),
 'ppg_sar9_sar15_safe_selection_wrapper':('C09 §§4-11 / SSW-01..52 / LFA-04/06 / OIB','B-012/019；D03冻结不另报','双waveform槽；每精度/颜色/类型窗口和逐bit总线；AMB Q2单相；owner/Q3保持/代际身份；错/迟到/失败完成与abort同拍；复位与安全收敛边界'),
 'ppg_precision_window_integration':('C18 §§4-10 / PWI-01..08 / D01 / PRC','B-007/011/017；单元TB只有01..05','FIR/fork/baseline/PVW/PWC逐端口和配置资格扇出；invalid安全消费；detection broadcast generation；empty聚合与重检历史清理；精度尾部'),
 'ppg_precision_window_controller':('C23 §§5-21 / PWC-01..41 / PWI-05 / PRC','B-010；已知09-17 START sticky修复有效','cross及return保持与safe commit；FSM/default/取消优先级；两帧保护/尾部/超时与位宽；sticky仅clear/reset；matching与stale discard generation'),
 'ppg_system_fault_abort_supervisor':('C24 §§1-7 / SUP-01..10 / K02','B-001/002/018/019','注册故障源固定仲裁/快照与summary；episode/trio/history；watchdog计数和真实idle优先；clear与new fault同拍；无ready/伪DONE/owner释放'),
 'startup_idac_calibration':('C25 SID-01..12 / C08/C09/C10/C16','F-001；SID-05/06有效；tick248同拍未覆','COMMIT/START合法配置；三阶段deadline抑制与重试；真实owner/RAW/DONE；快照/epoch；耗尽前提；非空窗口及超时/结束'),
 'periodic_recheck_recovery':('C25 RRC-01..12 / C16/C18/C23','F-001；B-014；B-007专项补充','完整帧计数/首次pending；安全接管及真实阶段；FIR/基线保持与调码/epoch；超时；PASS比较和前提范围'),
 'owner_identity_backpressure':('C25 OIB-01..10 / C08/C09/C10','F-001；B-015；B-006专项补充','公开背压与合法生命周期；held formal/detection；真实snapshot与码epoch；全部PASS判据/元数据/守恒；launch/owner timeout分类'),
 'no_recheck_control':('C25 NRE-01..06 / C16/C18/C23','已知长回归未完成；未新增RTL错误','interval0全RUN活动监视；FIR预热/精度入口与PV返回事件；result计数/身份单调性的有效范围；超时和结束'),
 'lifecycle_fault_adc_anomaly':('C25 LFA-01..12 / C08/C09/C10/C24 / P01','F-001；B-012补充同拍；LFA-10b SKIP保留','真实ack代际；STOP/abort/reset/迟到/重复DONE；物理armed资格；精确discard与首fault；owner drain和新START；所有SKIP/PASS范围'),
 'injection':('C01 TOP-24 / C10 AMI-47..52 / INJ-00..04 / P01-P06','B-013/016；INJ03 partial-X/沿竞争限制','注入双请求真实处理资格；身份绑定和invalid输出；源enable vs叶子锁存；实际fire/hold/取消；X/Z检测范围、输入驱动和超时'),
}
contract_meta={
 C08:meta[FSC],C09:meta[SSW],C10:meta[AMI],C16:meta[AMR],C18:meta[PWI],C23:meta[PWC],C24:meta[SUP],
 contract('PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST'):('non-normative reference / C08/C09/C10 / JNT-01..09','F-003历史锚点关联；不得覆盖当前合同','全文逐端口连线设计快照、waveform/owner/DONE/故障与START边界；更新状态引用按当前源合同判断'),
 contract('PPG_ADC_IDAC_INTEGRATION_SPEC'):('non-normative reference / C10/C16 / NORMAL fork/IDAC/AMB','历史实现状态不转为当前闭合','全文架构职责/注册数据流/握手和NORMAL tracking、校准重检、精度安全及数值接口边界，与当前规范职责对照')
}
def info(f):
 if f['layer']=='合同':return contract_meta[f['path']]
 if f['path'].startswith('rtl/ppg_control_top/'):
  return meta[Path(f['path']).stem.replace('tb_ppg_control_top_','')]
 return meta[Path(f['path']).parent.name]

coverage=list(csv.DictReader((OUT/'coverage.csv').open(encoding='utf-8-sig')))
assert len(coverage)==94 and {r['path'] for r in coverage}=={f['path'] for f in FILES}
for r in coverage:
 f=next(f for f in FILES if f['path']==r['path']);reference,issues,checks=info(f)
 r['contract_or_id']=reference
 r['status']='完成'
 # Keep evidence appropriate to the item; never imply every TB was mutated.
 if f['layer']=='合同':
  ev='全文及RTL/TB对照；报告批次1-9；evidence/dependency_bindings.json；evidence/id_four_link_audit.json；findings_index.csv'
 elif f['layer']=='RTL':
  ev=f'全文逐项；{checks}；evidence/skill/{Path(f["path"]).stem}/；protocol_table.md；findings_index.csv'
 else:
  ev='全文所有驱动/比较/注释/结束与超时；报告对应模块和系统审阅记录；evidence/id_four_link_audit.json；findings_index.csv'
  if r['check_item']=='负对照/运行证据':ev+='；短专项的范围见evidence/final_trial_inventory.json，未逐TB补跑整套或宣称所有case变异通过'
 r['evidence']=ev+'；evidence/final_baseline.json'
 r['remaining']='本项审阅无未完成；发现/限度：'+issues+'；缺陷未修复，全局回归和完整ID/锚点签核由A汇总'
write_csv('coverage.csv',coverage)
perfile=[]
for f in FILES:
 reference,issues,checks=info(f)
 perfile.append({'owner':'B','layer':f['layer'],'path':f['path'],'lines':line_counts[f['path']],'status':'完成','completed_scope':checks+'；全文代码/注释（合同为全文正文）；本组机械ID及family语义抽查','contract_or_id':reference,'findings_and_limits':issues,'global_signoff':'未签核；未修复；全套原TB回归由A负责'})
write_csv('file_coverage.csv',perfile)

ids=[]
for r in id_data['rows']:
 ids.append({'id':r['id'],'definition_anchors':'; '.join(x['path']+':'+str(x['line']) for x in r['definitions']),'rtl_tag_count':len(r['rtl_tags']),'tb_code_reference_count':len(r['tb_code_mentions']),'registry_reference_count':len(r['matrix_or_alias_mentions']),'mechanical_review':'完成；逐来源见evidence/id_four_link_audit.json','semantic_review':'至少family抽查；报告批次9及实际全文；不声称每个ID动态签核','missing_links':'；'.join(label for key,label in [('rtl_tags','无同名@satisfies'),('tb_code_mentions','无同名TB代码引用'),('matrix_or_alias_mentions','无同名matrix/alias引用')] if not r[key]) or '四类文字联系存在，仍需实际语义和当前状态判定','closure_verdict':'不把文字联系或历史PASS判为CLOSED；全局台账由A汇总'})
write_csv('acceptance_coverage.csv',ids)

report=OUT/'PPG_REVIEW_B.md';body=report.read_text(encoding='utf-8')
body=body.replace('C24合同第1节（43行）','C24合同第1节（41行）')
body=body.replace('原RTL及仅删除AMI两个互斥项的负对照，都四比较PASS','原RTL及仅删除AMI两个互斥项的负对照，都有3条PASS比较输出（含INJ-00 setup）及最终通过标记')
body=body.replace('原RTL重叠66拍、eligible2、ready0、四比较PASS','原RTL重叠66拍、eligible2、ready0，3条PASS比较输出（含setup）及最终通过标记')
body=body.replace('均3个PASS、0FAIL；trace','均2条PASS比较输出（含INJ-00 setup）及最终通过标记、0FAIL；trace')
body=body.replace('VG014/VG0611/VG0661/VG0603/VG0666','VG014/VG060/VG061/VG066')
old='状态：进行中。只读、conservative。初始主责文件字节核对见 evidence/baseline.json。'
new='''状态：B组主责审阅完成（2026-10-04）：7 RTL、13 TB、9合同，共29文件、30,592行；逐项94/94完成。缺陷未修复，全局回归与最终签核由A负责。只读、conservative。初始/最终字节核对见 evidence/baseline.json、final_baseline.json。

以下按批次保留调查过程；较早“待审/进行中”仅描述当时进度，以本段及最终 coverage.csv / handoff.md 为准。仍然有效的验证限制保留在各发现里。

19项发现：8 S1 RTL、7 S2 TB、4 S3合同/一致性，无新增风格编号。最需优先复核的内部协议问题是B-007（periodic deadline不能在当前RUN重试）和B-012（abort同拍DONE残留SSW owner，首次CONFIG可达，但新START不能提交新owner）。B-003默认连续NORMAL周期5001拍，B-006正式discard身份错指另一笔，B-008独立分支资格被提前清除，B-009 AMI START清历史，B-010取消同拍仍精度提交，B-005取消沿CAL上下文重建。各项的实际动态范围、反驳及恢复条件见对应条目。

本组文件审阅不等于RTL正确、TB全部通过或芯片签核。没有修改共享RTL/合同/TB，也没有启动全套/长回归。312个ID机械索引和14个family语义抽查完成；完整逐ID语义签核与全局锚点台账保持A主责。

快速索引：findings_index.csv（19项及真实源行）；file_coverage.csv（29文件）；coverage.csv（94检查项）；acceptance_coverage.csv（312明确定义ID）；protocol_table.md（逐拍协议）；evidence/final_trial_inventory.json（52次既有短试验，含无效setup及负对照，不能视作52份原TB）。

| 编号 | 层/分类 | 确认问题 |
|---|---|---|
'''
new+='\n'.join(f'| {r["id"]} | {r["severity"]} | {r["title"]} |' for r in rows)
if old in body:body=body.replace(old,new,1)
else:assert '状态：B组主责审阅完成' in body
if '## 最终复核（2026-10-04）' not in body:
 body+='''

## 最终复核（2026-10-04）

Git 2.54.0.windows.1、Python 3.12.14；既有Icarus11.0（WSL Debian）。最后重新读取HEAD及status：固定提交一致、工作树干净，29/29快照字节等于该提交Git blob。Git safe-directory例外只在本次命令参数中使用、禁optional locks，未写全局配置或共享.git。最终结果保存evidence/final_baseline.json。

7份同版本门禁按规则汇总为VG014=2、VG060=3、VG061=2、VG066=7，共12 error/2 strict warning；其中AMI 2/1、SSW 10/0、PWI 0/1、其他四份0/0。这里只汇总已知积压，不把门禁标为全部通过。formatter AST与真实编译/仿真各有独立证据。原始stdout混有WSL UTF-16代理警告的NUL，最终试验索引去NUL后统计比较行并单列FATAL，原日志未改；`*_PASS`结束标记不计为独立比较。为此复核并订正B-013/016的比较数量，问题和负对照结论不变。

逐文件审阅状态均为完成（7 RTL / 13 TB / 9合同，94检查项）；完成是阅读、实际核对、问题记录和交接完成，不把未修复问题和未完成长回归藏进PASS。A需要复核关键原始日志、合并已有F编号和全局ID/锚点台账，并处理本报告保留的动态范围及签核缺口。本组没有运行中仿真。
'''
report.write_text(body,encoding='utf-8')

handoff=f'''# B组最终交接 — 主责审阅完成

被审提交：`{COMMIT}`。日期2026-10-04。只读/conservative，未修改共享RTL、合同、TB、A报告或登记表，未提交/推送。未向其他聊天发送消息。

状态：7 RTL、13 TB、9合同共29/29全文审阅完成（30,592行），94/94本组检查项完成。剩余未审RTL=0、TB=0、合同=0。语义/协议问题均保持未修复；全套原TB回归、完整逐ID语义/全局锚点和系统最终签核保持A主责。历史批次交接中“待审”已由此最终交接替代。

- [详细报告]({(OUT/'PPG_REVIEW_B.md').as_posix()})
- [94项覆盖台账]({(OUT/'coverage.csv').as_posix()})
- [29文件覆盖]({(OUT/'file_coverage.csv').as_posix()})
- [19项发现索引]({(OUT/'findings_index.csv').as_posix()})
- [312个ID机械联系]({(OUT/'acceptance_coverage.csv').as_posix()})
- [逐拍协议]({(OUT/'protocol_table.md').as_posix()})
- 原始证据：{(OUT/'evidence').as_posix()}

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
'''
(OUT/'handoff.md').write_text(handoff,encoding='utf-8')
print('Finalized: 29 files / 94 checks / 312 ID records / 19 findings; all B review states complete')
