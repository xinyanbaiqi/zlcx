from pathlib import Path
import json,csv,collections
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';p=B/'PPG_FULL_REVIEW_20261002.md'
t=p.read_text(encoding='utf-8')
def line(f,n,token):
    value=(S/f).read_text(encoding='utf-8').splitlines()[n-1];assert token in value,(f,n,token,value);return value
matrix='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md'
ssw='contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md'
fsc='contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md'
ftb='rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v'
sup='contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md'
stb='rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v'
manifest=json.loads((E/'manifest_audit_A.json').read_text(encoding='utf-8'))['rows']
assert sum(r['status']=='mismatch' for r in manifest)==23
binding=json.loads((E/'dependency_audit_A.json').read_text(encoding='utf-8'))['bindings']
newanchors=[r for r in binding if not r['source_path_text_matches'] or not r['source_version_text_matches']]
assert len(newanchors)==6
old=list(csv.DictReader((E/'anchor_failures.csv').open(encoding='utf-8-sig')))
for r in newanchors:
    record=dict(source=matrix,line=r['matrix_line'],reference=r['source']+':'+str(r['source_line_number']),kind='Cxx_current_binding',expected=Path(r['path']).name,status='text_mismatch',target=r['source_text'])
    if not any(x['reference']==record['reference'] and str(x['line'])==str(record['line']) for x in old):old.append(record)
with (E/'anchor_failures.csv').open('w',encoding='utf-8',newline='') as fp:
    w=csv.DictWriter(fp,fieldnames=['source','line','reference','kind','expected','status','target']);w.writeheader();w.writerows(old)
t=t.replace('12个K出处与上述165个声明引用合计177个文字不匹配记录。','12个K出处与上述165个声明引用合计177个文字不匹配记录；本轮另逐条确认矩阵:1292六条C09现行依赖引用（C09:62至67）未指向所列被依赖合同，累计183个文字不匹配记录。原C09依赖表在:63至68，但此结论来自逐行文字核对，不按偏移推算。')
t=t.replace('不能当成177个独立功能错误','不能当成183个独立功能错误')
blocks=[]
blocks.append('''### F-045：矩阵现行26文件完整性摘要有23项与固定版本字节不符

- 严重度/层：S3 / 矩阵·台账。
- 位置：`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:1226-1232`定义当前完整文件摘要及失效规则；`:1236-1261`现行清单。原文（3行，分别为:1226、:1231、:1232）：
```text
'''+line(matrix,1226,'25 contract digests')+'\n'+line(matrix,1231,'later change')+'\n'+line(matrix,1232,'baseline')+'''
```
- 描述/依据：25合同中仅C04、C05、C21的full-file SHA256匹配；其余22份及按本节规定将自身摘要字段替换为`<SELF_SHA256>`后的M01均不符，共23项。清单明确是active paths现行完整性基线，不能用这些摘要鉴别本次实际文件。
- 证据：`evidence/manifest_audit_A.json`逐项保留登记摘要、实际摘要和源行。C01(:1236)登记`620b671493546aa45b86354d09703f4141c325940b5e7a2cf84b3c832e14f395`，实际`39c747617ff7da2997c1bfc1e14aaf5c41d38056fba2eb662d4ef13d2ddd299e`；C09(:1244)登记`425b896e22b87f84f748829b5d4ac483a50b755668958e12f13610a1c0e973ee`，实际`658fc3c56721a27db369a93057317fd44ebbd4b6bcef6da807dade6a9451451d`。PowerShell Get-FileHash独立核对上述两项相同。26份文件逐个经git cat-file的固定提交原始blob核对，均与导出字节完全一致，排除autocrlf/编码转换。M01登记和实际值见同表。
- 反驳：矩阵:1191-1194明确排除historical lists/baseline copies；:1231-1232明文后续改动使该baseline失效。M01已按其自归一化算法核对，没有拿未经归一化的自摘要制造差异。用户已知§13.1旧ID数量与G-FP独立复核范围没有说明§12.4a现行摘要已接受失效；也非F-003行号引用问题。没有据此认定RTL被篡改或功能错误。
- 置信度：静态确认。脚本先验证正常项、字节改动、错误摘要、缺文件恰好输出三项已知错误；另验证自摘要字段变化被忽略而其他文字变化被检出，详manifest_negative_controls.json。
- 建议方向：重新生成当前完整性清单并独立比对原始Git字节，同时保留旧摘要为历史。

''')
blocks.append('''### F-046：合同与TB的同号验收场景存在语义错位

- 严重度/层：S3 / 跨层。
- 位置：C08 `contracts/PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md:1135,1146,1149,1166-1167`；scheduler TB `rtl/ppg_400hz_frame_calibration_scheduler/tb_ppg_400hz_frame_calibration_scheduler.v:564,581,592,708,724`。C24 `contracts/PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md:160-161`与supervisor TB `rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v:464-488`。原文（3行，分别为C08:1135、scheduler TB:564、C24:161）：
```text
'''+line(fsc,1135,'FSC-03')+'\n'+line(ftb,564,'check_fsc(3')+'\n'+line(sup,161,'SUP-10')+'''
```
- 描述：合同FSC-03是严格5000拍周期，TB同号却比较启动前frame/owner/索引为空；周期检查实际在FSC-14，而合同FSC-14是DCS_CAL RED。FSC-17要求校准资格/请求保持，TB同号比较RED-only owner数；FSC-34/35合同分别随机反压/长期无漂移，TB同号分别失败完成不计正常结果/STOP释放。SUP-09合同区分fault-discard与外部abort，TB同号是阈值前真实idle；SUP-10合同是AMI延迟discard reason保持，TB同号是清历史后第二episode。仅找到相同ID字符串不能证明该冻结需求被验证。
- 证据/反驳：A重新核对原定义、check_fsc数值派发及前后激励，来源B-018，逐ID索引在B evidence/id_four_link_audit.json。FSC-58/59确有真实资格检查，SUP其他case也确有fault-discard比较；不声称这些行为在项目中完全未测。F-011已单列周期容差过弱，F-012已单列历史未清rearm缺口，本条只汇总同号语义错位，不重复算缺失功能，也不是F-003失效行号。未见合同允许重用同一编号表达另一验收义务。
- 置信度：静态确认；本条为编号映射事实，无需新增行为仿真。
- 建议方向：将现有有效检查按冻结需求重新映射，并明列其他case/文件提供的替代证据。

''')
blocks.append('''### F-047：SSW最新修订与唯一规范版本声明的承接关系不明确

- 严重度/层：S3 / 合同。
- 位置：`contracts/PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md:3,7,403,430-438`；矩阵`contracts/PPG_CONTRACT_CLOSURE_MATRIX.md:1206,1244,1267-1280`及八份现行C09依赖表。原文（2行，C09:3、:7）：
```text
'''+line(ssw,3,'V1.10')+'\n'+line(ssw,7,'sole current')+'''
```
- 描述：文件以V1.10记录真实AMB单相Q2取值修订，正文:403/434也采用该行为，但:7仍称V1.9为唯一现行接口/生命周期权威。矩阵版本列仍V1.9，却按C09:3取目标header并称141/141当前header版本匹配。A核对141绑定，八处C09登记V1.9与第3行V1.10不同（C01:101、C03:28、C06:37、C07:40、C08:59、C10:63、C24:17、C25:127）。当前基础标签与增量修订的关系没有像C01:20那样明文澄清。
- 证据：dependency_audit_A.json全141项源声明/目标header，53?没有使用猜测值；真实差异恰好上述八条，其余133条header比对一致。中文紧邻版本、句尾标点正例与错版本/缺路径负例均通过后才采信结果；各源声明的实际文字逐条读取。C09六条依赖声明行引用文字漂移另并入F-003，不重复编号。
- 反驳：C09:7本身明文允许把V1.9视为基础规范，所以本条没有认定八处V1.9绑定非法，也不把SSW AMB改造作为新的功能错误。C01的V1.11~17已被明确解释为保留V1.10标签的errata，不能泛化为所有文件自动具备相同解释。用户已知SSW V1.5单相改造不等于接受此版本元数据矛盾。此条缩窄B-019“只有三处依赖错误”的表达，按全量八处差异记录文档承接问题。
- 置信度：静态确认（元数据和文字事实）；V1.10是否应升级规范标签由合同维护者裁定。
- 建议方向：明确保留V1.9基础标签并声明V1.10为勘误，或将唯一规范升级V1.10后同步八处依赖及矩阵。

'''.replace('53?没有使用猜测值；',''))
for block in blocks:
    fid=block.split('：',1)[0].split()[-1]
    if '### '+fid+'：' not in t:
        i=t.index('## 4. 已知事项');t=t[:i]+block+t[i:]
with (E/'manifest_mismatches_A.csv').open('w',encoding='utf-8-sig',newline='') as fp:
    w=csv.DictWriter(fp,fieldnames=['id','file','manifest_line','declared','actual','status']);w.writeheader();w.writerows(manifest)
cov=list(csv.DictReader((B/'coverage_A.csv').open(encoding='utf-8-sig')))
for r in cov:
    stem=Path(r['path']).stem
    if stem in ['PPG_CONTRACT_CLOSURE_MATRIX','PPG_ALIAS_MAPPING_TABLE']:
        r.update(status='完成' if stem=='PPG_CONTRACT_CLOSURE_MATRIX' and r['check_item']=='版本与依赖' else '部分',evidence=str(E/'anchor_scan_v2.json')+';'+str(E/'id_presence_v2.json')+';'+str(E/'dependency_audit_A.json')+';'+str(E/'manifest_audit_A.json')+';'+str(p),remaining='当前版本/141依赖/26摘要已全量核对，TOP/K及各组家族语义交叉抽查。ID机械全量不是语义闭环，尚需Top逐ID、台账其他cluster和未完成动态结果的最终一致性裁定；不将1696字面候选全部当错误。',file_status='部分')
    elif stem=='PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT' and r['check_item']=='版本与依赖':
        r.update(status='完成',evidence=str(E/'dependency_audit_A.json'),remaining='C01唯一规范V1.10/非规范errata关系、九依赖与当前141绑定逐项核对；SSW元数据问题F-047')
with (B/'coverage_A.csv').open('w',encoding='utf-8-sig',newline='') as fp:
    w=csv.DictWriter(fp,fieldnames=cov[0]);w.writeheader();w.writerows(cov)
p.write_bytes(t.replace('\n','\r\n').encode('utf-8'))
print('TRACEABILITY_FINDINGS_WRITTEN_F045_047','confirmed_anchors',len(old),'status',dict(collections.Counter(r['status'] for r in cov)))
