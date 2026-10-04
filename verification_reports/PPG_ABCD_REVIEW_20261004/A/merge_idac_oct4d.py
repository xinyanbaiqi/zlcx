from pathlib import Path
import json,hashlib
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
C=B.parent.parent/'01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C'
refs={
 'F-031':[('rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v',503,"8'd17"),('rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v',506,"8'd27"),('contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md',509,'至少9 bit')],
 'F-032':[('contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md',159,'input i_diag_clear_event'),('rtl/ppg_idac_code_controller/ppg_idac_code_controller.v',75,'input i_status_clear_event'),('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',2327,'.i_status_clear_event(i_diag_clear_event)')],
 'F-033':[('contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md',503,'不得产生'),('contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md',487,'无论AMB'),('rtl/ppg_idac_code_controller/ppg_idac_code_controller.v',794,'ST_DCS_REVALIDATE_WAIT')]
}
saved={};quotes={}
for fid,items in refs.items():
 saved[fid]=[];quotes[fid]=[]
 for rel,n,key in items:
  raw=(S/rel).read_bytes();line=raw.decode('utf-8-sig').splitlines()[n-1];assert key in line,(fid,n,line)
  saved[fid].append({'file':rel,'line':n,'text':line,'sha256':hashlib.sha256(raw).hexdigest()})
  quotes[fid].append(line.split('//',1)[0].strip())
meta=json.loads((C/'evidence/targeted_runtime_20261004/results_idac.json').read_text(encoding='utf-8'))
logs=[]
for m in meta:
 assert m['compile_rc']==0
 p=C/'evidence/targeted_runtime_20261004'/m['name']/'run.log';raw=p.read_bytes();text=raw.decode('utf-8',errors='replace').replace('\x00','')
 logs.append({'metadata':m,'log':str(p),'log_sha256':hashlib.sha256(raw).hexdigest(),'key_lines':[l for l in text.splitlines() if 'C_IDAC' in l or 'FAIL' in l or 'regression completed' in l],'pass_prefix_count':sum(l.startswith('PASS') for l in text.splitlines())})
assert [(m['compile_rc'],m['run_rc']) for m in meta]==[(0,0),(0,1),(0,0)]
(E/'merged_findings_oct4d_refs.json').write_text(json.dumps({'source_refs':saved,'simulations':logs},ensure_ascii=False,indent=2),encoding='utf-8')
details={
'F-031':'''### F-031：IDAC 单元 TB 的低码搜索未检出九位求和截断

- 严重度/层：S2 / TB；置信度：仿真确认。关联C-005。
- 位置：`rtl/ppg_idac_code_controller/tb_ppg_idac_code_controller.v:503,506`及`contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:509`，原文3行：
{quote}
- 描述/依据：首轮范围AMB0..7/R10..17/IR20..27；restart:464-471及其调用只用max<=30，端点和<=60。规范的8位码域最高和510，当前真实搜索不经过第9位。
- 证据：A已读C公开端口TB固定8候选字面量127/191/223/207/199/203/201/200，范围0..255、目标200，原RTL编译0运行0，`C_IDAC_MIDPOINT_PASS count=8 target=200`。仓库外仅将RTL:530的AMB初始和及:533后继和掩为低8位；公开TB运行1，`C_IDAC midpoint[1] expected=191 got=63`。同一变异运行完整原TB仍148条PASS、最终regression completed，退出0。原始命令、哈希及日志已复核并索引evidence/merged_findings_oct4d_refs.json。
- 反驳：原RTL确实扩成9位，本条不报生产溢出；完整TB每次最终码的比较是真实有效，只无法识别此宽位缺陷。系统SID/ISE等可能覆盖部分高码，不能代替该单元TB已有搜索算法验收，未据此宣称全系统无高码覆盖。generation悬空旧问题已修复，与本条不同；无已知事项豁免。
- 建议方向：加入高码、第9位和0/255端点的公开搜索向量及独立逐候选比较。
''',
'F-032':'''### F-032：IDAC 冻结诊断清除端口名与实际叶子接口不一致

- 严重度/层：S3 / 合同；置信度：静态确认。关联C-006。
- 位置：`contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:159`、IDAC RTL:75、AMI RTL:2327，原文3行：
{quote}
- 描述/依据：C17:137明确名称、方向、位宽必须与原型一致，原型写diag_clear，实际叶子用status_clear；TB:786和生产AMI均绑定实际旧名。按冻结原型具名实例化将无法elaborate。
- 反驳/证据：全局单一diag事件在AMI映射给叶子的status端口，清除路径存在且原TB有真实比较，故不报清除功能失效；来源映射不能使同一合同原型名与叶子声明一致。已核对合同现行版本行3及诊断正文、RTL声明/使用和生产连线；不属于注释style积压，也不同于F-024参数原型与其他discard合同事项。
- 建议方向：由接口owner统一冻结原型名称和AMI来源映射说明。
''',
'F-033':'''### F-033：IDAC 合同禁止不改 AMB 码时重验，与冻结依赖及实际三阶段相反

- 严重度/层：S3 / 合同；置信度：静态确认，原始148 PASS日志及真实比较支持实际行为。关联C-007。
- 位置：`contracts/PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md:503`、`contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md:487`、IDAC RTL:794，原文3行：
{quote}
- 描述/依据：C17当前规范行3为V2.3，其依赖表:18明确依赖C16 V2.1；C17§8.3/8.4及IDC2-17:670仍要求AMB不改码不请求DCS，C16§9.6却要求DCS启用时无论AMB是否改码均执行固定AMB/R/IR三阶段，两条规范不可同时满足。
- 反驳/证据：实际IDAC在ST_AMB_RECHECK合格且DCS启用时直接转重验等待；TB:371送不改码的合格样本，:377真实比较unchanged AMB仍产生请求，:568执行固定周期场景。C16现行修订及RRC-05三阶段义务已交叉核对；故将C17滞后文字报S3，不把实际无条件重验当RTL错误。不是旧33失败、generation悬空或已知tick-248事项。
- 建议方向：同步C17正文与IDC2-17，使依赖、验收表和固定三阶段义务一致。
'''
}
p=B/'PPG_FULL_REVIEW_20261002.md';txt=p.read_text(encoding='utf-8')
for fid,body in details.items():
 if '### '+fid in txt:continue
 body=body.replace('{quote}','```text\n'+'\n'.join(quotes[fid])+'\n```')
 pos=txt.index('### F-002' if fid=='F-031' else '## 4. 已知事项');txt=txt[:pos]+body+'\n'+txt[pos:]
if '## IDAC检查点：2026-10-04d' not in txt:txt+='\n## IDAC检查点：2026-10-04d\n\nF-031～033已核对9处固定原文、三次公开端口/完整原TB实际日志与变异差异；新增S2一条、S3两条。831等ID扫描数字只是候选文本计数，不能直接作为真实缺口数量。\n'
p.write_bytes(txt.replace('\n','\r\n').encode('utf-8'));print('MERGED',list(details))
