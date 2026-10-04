from pathlib import Path
import csv,json,hashlib,re,collections
B=Path(__file__).resolve().parent; E=B/'evidence'; S=B/'snapshot'
cov=list(csv.DictReader((B/'coverage_A.csv').open(encoding='utf-8-sig')))
runtime={x['tb']:x for x in json.loads((E/'regression_results.json').read_text(encoding='utf-8'))}
closure=E/'closure_skill_20261004'
semantic_complete=(closure/'top_24_semantic.json').exists() and (E/'global_closure_20261004/A_remaining_family_adjudication.json').exists()
systems={'tb_ppg_control_top','tb_diag_algo_probe','tb_ppg_control_top_longrun','tb_ppg_control_top_long_10_cycles','tb_ppg_control_top_robustness_corner_waveforms'}
for row in cov:
    n=Path(row['path']).stem
    if n in systems:
        item=row['check_item']; state='完成'
        if item=='验收ID激励/执行计数/覆盖语义': state='完成' if semantic_complete else '部分'
        if item=='变异抽查':state='完成'
        if item=='运行日志/入口脚本判据': state='完成' if runtime.get(n,{}).get('state')=='finished' else '部分'
        remaining='所列静态比较/驱动/时限/终判/路径及各ID语义已审；原最小监视器A/B不冒充完整DUT变异。'
        if runtime.get(n,{}).get('state')!='finished': remaining+='完整原长回归仍运行或排队，终态未核对。'
        row.update(status=state,file_status='部分',evidence=str(B/'PPG_FULL_REVIEW_20261002.md')+';'+str(E/'long_monitor_negatives_A.json')+';'+str(closure/'top_24_semantic.json')+';'+str(E/'global_closure_20261004/A_remaining_family_adjudication.json'),remaining=remaining)
    elif n=='PPG_JOINT_TB_CANDIDATE_TEST_SPEC':
        row.update(status='完成' if semantic_complete else '部分',evidence=str(closure/'top_24_semantic.json')+';'+str(B/'PPG_FULL_REVIEW_20261002.md'),remaining='非规范候选全部382行及范围/规范优先级/JNT54与历史52差异已裁定；实际10秒回归终态仍待§6，不将审阅完成当场景PASS。')
    elif n=='TAPEOUT_FINAL_REVIEW_GUIDE':
        row.update(status='完成' if semantic_complete else '部分',remaining='71行全文及现行规范/工具能力已核对；非规范指南无独立Cxx绑定/验收ID，两个检查项不适用；用户已知路径/回归/旧审计不重复报。')
    elif n=='PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT' and semantic_complete:
        row.update(status='完成',evidence=str(closure/'top_24_semantic.json')+';'+str(closure/'top_port_comparison.json')+';'+str(E/'dependency_audit_A.json'),remaining='C01全文、11公开参数、165边界端口、六子模块连接及TOP01-24已审；F008/F024/F048及F049/F040限制保留；历史逐位证据未重建、SID/OIB原回归未全结束，不宣布CLOSED。')
    elif n=='ppg_control_top' and semantic_complete:
        if row['check_item'] in ('端口与合同名称/方向/宽度/符号/语义','CDC条件与消费者','注释与代码一致'): row['status']='完成'
        if row['status']=='完成':row.update(evidence=str(closure/'top_24_semantic.json')+';'+str(closure/'top_ports_165.csv'),remaining='Top六always复位/注册merge、两source CDC边界、物理idle已同步前提及五同源消费者逐跳核对；有限工具不等于ASIC CDC签核。')
for row in cov:
    rows_for_file=[x for x in cov if x['path']==row['path']]
    row['file_status']='完成' if all(x['status']=='完成' for x in rows_for_file) else '部分'
with (B/'coverage_A.csv').open('w',encoding='utf-8-sig',newline='') as fp:
    w=csv.DictWriter(fp,fieldnames=cov[0]);w.writeheader();w.writerows(cov)

parents=B.parent.parent
groupdirs={
 'B':parents/'01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B',
 'C':parents/'01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C',
 'D':parents/'01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D'}
perfile=collections.defaultdict(list)
for x in cov:perfile[x['path']].append(x)
snap=E/'coverage_snapshot_20261004b';snap.mkdir(exist_ok=True)
for g,d in groupdirs.items():
    raw=(d/'coverage.csv').read_bytes();(snap/(g+'_coverage.csv')).write_bytes(raw)
    for x in csv.DictReader(raw.decode('utf-8-sig').splitlines()):
        x['source_coverage']=str(d/'coverage.csv')
        name=Path(x['path']).stem
        if x['check_item']=='同版本实际完整TB运行（由A管理）':
            result=runtime.get(name,{})
            if result.get('state')=='finished' and result.get('rc')==0 and not result.get('fail_lines') and result.get('banner'):
                x.update(status='完成',evidence=str(E/'compile'/name/'run.log'),remaining='A已核对固定版本完整原TB最终横幅、全部FAIL标记及系统基线PASS数；运行通过不抵消发现表的验证缺口。')
            else:
                x.update(status='部分',evidence=str(E/'compile'/name/'run.log'),remaining='A当前实测状态：'+result.get('state','未运行')+'；原最终横幅仍未取得，不把C交稿时的排队状态当现状。')
        perfile[x['path']].append(x)
ledger=json.loads((E/'ledger.json').read_text(encoding='utf-8'))
for x in ledger:
    assert hashlib.sha256((S/x['file']).read_bytes()).hexdigest()==x['sha256'],x['file']
    rows=perfile.get(x['file'],[])
    if not rows:continue
    state=collections.Counter(r['status'] for r in rows)
    owner=rows[0]['owner']; x['owner']=owner
    if all(r['status']=='完成' for r in rows):x['status']='完成'
    elif any(r['status'] in ('完成','部分') for r in rows):x['status']='部分'
    note=f"{owner}组逐项台账（2026-10-04b读取）："+'，'.join(f'{k}{v}项' for k,v in state.items())
    x['checks']=[c for c in x['checks'] if not re.match(r'[ABCD]组逐项台账',c) and not c.startswith('Icarus回归') and not c.startswith('Icarus入库TB运行') and not c.startswith('Icarus原TB当前状态：') and not c.startswith('当前逐项已审：')]+[note]
    if any(r['status']=='完成' and r['check_item'].startswith('全文语义/') for r in rows):
        x['checks']=[c for c in x['checks'] if not any(term in c for term in ('仍待核对','少量payload段与全部合同比对未完成'))]
        x['checks'].append('当前逐项已审：全文语义、全部端口、复位、状态异常、握手、位宽、注释及TB有效性；具体证据见分组逐项台账')
    run=runtime.get(Path(x['file']).stem)
    if x['layer']=='TB' and run:
        x['checks'].append('Icarus原TB当前状态：'+run['state']+(('; rc='+str(run['rc'])+'；最终横幅='+(';'.join(run.get('banner',[])) or '未取得')) if 'rc' in run else '；未作通过结论'))
    if Path(x['file']).stem in systems:
        x['checks'].append('A：全部有效代码实读，真实比较/输入驱动/注入参数/watchdog/结束/容差/硬编码核对；robust监视器最小A/B揭示F-016/017；smoke原71 PASS。其他长TB仍等待完整回归。') if not any('A：全部有效代码实读' in c for c in x['checks']) else None
    x['remaining']='；'.join(dict.fromkeys(r['check_item']+'：'+r['remaining'] for r in rows if r['status']!='完成')) or '所列要求已审；不等于穷尽输入状态空间或ASIC签核'
    x['coverage_source']=str(B/'coverage_A.csv') if owner=='A' else str(groupdirs[owner]/'coverage.csv')
(E/'ledger.json').write_text(json.dumps(ledger,ensure_ascii=False,indent=2),encoding='utf-8')
report=B/'PPG_FULL_REVIEW_20261002.md'; txt=report.read_text(encoding='utf-8')
start=txt.index('\n\n',txt.index('## 2. 结论摘要'))+2;end=txt.index('## 3. 新发现',start)
findings=[];suspected=[]
for m in re.finditer(r'^### (F-\d+)(?:：| — )([^\n]+)\n(.*?)(?=^### F-|^## 4\.)',txt,flags=re.M|re.S):
    body=m[3]; match=re.search(r'S[1-4]',body)
    if match:
        layer='RTL' if match[0]=='S1' else 'TB' if match[0]=='S2' else '矩阵·台账' if m[1] in ('F-003','F-045','F-050') else '跨层' if m[1]=='F-046' else '合同'
        (suspected if '置信度：疑似' in body else findings).append((m[1],match[0],layer,m[2]))
assert len(findings)>=17,(len(findings),findings)
counts=collections.Counter(f[1] for f in findings); layers=collections.Counter(f[2] for f in findings)
all_runs_ok=len(runtime)==48 and all(r.get('state')=='finished' and r.get('rc')==0 and not r.get('fail_lines') and r.get('banner') and (r.get('baseline') is None or r.get('baseline')==r.get('pass_lines')) for r in runtime.values())
lead='本轮文件审阅及完整原回归日志核对已结束；§5/§7明确列出的未验证范围保留，不记为通过。' if all_runs_ok else '所列人工审阅与交叉核对已补充完成，完整原回归终态尚未齐；未能独立验证的范围明确列于§5/§7。'
intro=f"{lead}已确认{len(findings)}条：**S1={counts['S1']}、S2={counts['S2']}、S3={counts['S3']}、S4={counts['S4']}**；按主层：RTL={layers['RTL']}、TB={layers['TB']}、合同={layers['合同']}、矩阵·台账={layers['矩阵·台账']}、跨层={layers['跨层']}；另有{len(suspected)}条疑似，不计确认数。优先关注F-035完成/abort同拍导致重新START受阻、F-023真实SPI STOP被吞、F-005真实Mode0读流错位、F-020周期重检重试锁住及F-019错误discard身份。S2中F-006/F-011掩盖已有真实S1，其他变异逃逸范围见各条；叶子反压/同拍组合与完整芯片触发严格区分。未审、工具未完成和仅编译通过均不能理解为功能通过。"
head='\n\n| 编号 | 严重度 | 主层 | 结论 |\n|---|---|---|---|\n'
for fid,sev,layer,title in sorted(findings,key=lambda r:(r[1],r[0])):head+=f'| {fid} | {sev} | {layer} | {title} |\n'
for fid,sev,layer,title in suspected:head+=f'| {fid} | {sev}（疑似） | {layer} | {title} |\n'
txt=txt[:start]+intro+head+'\n统计每条发现一次；跨层证据不重复计数。其他组新候选在A独立复核前不计入。\n\n'+txt[end:]
start=txt.index('| 文件 | 层 | 行数 | 状态 | 已做检查 / 剩余 |');end=txt.index('## 6. 回归对比',start)
table='| 文件 | 层 | 行数 | 状态 | 已做检查 / 剩余 |\n|---|---|---:|---|---|\n'
for x in ledger:
    text='；'.join(x['checks'])+'；剩余：'+x['remaining']
    table+='| '+x['file']+' | '+x['layer']+' | '+str(x['lines'])+' | '+x['status']+' | '+text.replace('|',' / ').replace('\n',' ')+' |\n'
txt=txt[:start]+table+'\n完整逐项证据及未完成项分别在各组coverage.csv，总表不将“已读全文”升级为所有检查完成。\n\n'+txt[end:]
if '## 覆盖检查点：2026-10-04b' not in txt:
    txt+='\n## 覆盖检查点：2026-10-04b\n\nA五份系统TB有效代码全文已读，比较、输入驱动、时限、终判、路径静态核对已保存。除smoke原71 PASS外，四份长场景尚未完成实际回归；只对robust PRC09/10完成最小判据变异，未声称完整robust变异仍通过。119文件覆盖表刷新为本次逐项台账：A组自审，B/C/D组状态按其台账保守汇总；跨组新发现仍需独立核实。其余所列未审保持未审。三组台账读取快照保存evidence/coverage_snapshot_20261004b。\n'
report.write_bytes(txt.replace('\n','\r\n').encode('utf-8'))
print('COVERAGE_CHECKPOINT',len(ledger),dict(collections.Counter(x['status'] for x in ledger)),dict(collections.Counter(r['status'] for r in cov)),len(findings))
