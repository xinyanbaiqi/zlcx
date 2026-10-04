from pathlib import Path
import csv,json,re,collections,datetime
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';O=E/'global_closure_20261004'
f=O/'C03_C04_source_rows_129.json';d=json.loads(f.read_text(encoding='utf-8'))
cl=(S/'contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md').read_text(encoding='utf-8').splitlines()
manager=(S/'contracts/ppg_system_config_manager_semantic_contract.md').read_text(encoding='utf-8').splitlines()
assert cl[219]=='## 7. ACTIVE与epoch输出'
assert 'o_lifecycle_state' in manager[108] and 'start_ready = active_valid' in manager[310]
for r in d['records']:
 if r['matrix_line'] not in (1639,1640):continue
 assert r['port'] in ('o_lifecycle_state','o_start_ready') and r['contract_line']==220
 r['state']='confirmed_wrong_source_line'
 r['reason']='Source220 section7 freezes only ACTIVE/config/coef/DC epochs (226-231), not lifecycle state or start eligibility. C03 diagram52 lifecycle/status + manager dependency29 and reset-forward rule286 establish inheritance; C02 explicitly defines state109/start-ready311. Real wrapper declarations86/87, passthrough296/297 and manager instance413/414 verified. Thus a wrong Source category, not absent hardware or unspecified semantics.'
 r['related_current_definition']=dict(path='contracts/ppg_system_config_manager_semantic_contract.md',line=(109 if r['port']=='o_lifecycle_state' else 311),text=manager[108 if r['port']=='o_lifecycle_state' else 310])
d['counts']=dict(collections.Counter(r['state'] for r in d['records']));d['scope_ambiguities_resolved_at']=datetime.datetime.now().isoformat(timespec='seconds')
f.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
af=E/'anchor_failures.csv';rows=list(csv.DictReader(af.read_text(encoding='utf-8-sig').splitlines()));fields=list(rows[0]);keys={(r['source'],int(r['line']),r['reference'],r['expected']) for r in rows}
for r in d['records']:
 if r['matrix_line'] not in (1639,1640):continue
 row=dict(source='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md',line=r['matrix_line'],reference=r['reference'],kind='contract_source_category',expected=r['port'],status='text_mismatch',target=r['target'])
 key=(row['source'],int(row['line']),row['reference'],row['expected'])
 if key not in keys:rows.append(row);keys.add(key)
with af.open('w',encoding='utf-8',newline='') as fh:
 w=csv.DictWriter(fh,fieldnames=fields);w.writeheader();w.writerows(rows)
counts=collections.Counter(r['status'] for r in rows)
assert counts['text_mismatch']==640 and counts['out_of_bounds']==14,counts
report=B/'PPG_FULL_REVIEW_20261002.md';t=report.read_text(encoding='utf-8');a=t.index('### F-003');z=t.index('\n### F-',a+1)
block=t[a:z]
start=block.index('- **描述/依据**');end=block.index('- **证据/反驳**')
description=f'''- **描述/依据**：当前累计确认{counts['text_mismatch']}处文字/当前章节不符、14处越界，按引用出现位置而非独立缺陷计数。包括165个Top声明、64个Scheduler/AMI子模块声明、12个K出处、6个C09依赖、3个AMI标签、以及390个合同Source索引。最后一批864条Source逐项裁定新增84处：空行、围栏、ASCII图、错误输入/输出握手边界及把正式测量/检测discard指向物理ADC owner或成功completion章节；另把C03的生命周期/START-ready两处歧义裁定为章节索引错位。所有真实端口与正确现行定义已另核实，不把失效引用推导成硬件未实现。全1860条Source现均有独立记录，合法分组/完整身份展开/当前覆盖及矩阵自述缺口保留，不凑成失配。逐项原Source、目标文字、正确当前定义和实际Erie端口声明见`anchor_failures.csv`及各`*_source_rows_*.json`；不能当成640个独立功能错误。
'''
block=block[:start]+description+block[end:]
# Remove chronological intermediate counts; the evidence still preserves every batch.
trail=block.index('\n\n本批继续人工裁定') if '\n\n本批继续人工裁定' in block else len(block)
block=block[:trail].rstrip()+'\n\n'
t=t[:a]+block+t[z:]
h='## A Source人工裁定闭合：2026-10-04'
if h not in t:
 t+='\n'+h+'\n\n此前996已审/864待审是历史检查点；本批已实际完成剩余864条逐项裁定，并解决C03两处范围歧义。当前1860/1860 Source工作项有单条记录，待审0、未裁定歧义0。最后一批341条当前字面/章节支持、435条明确分组及跨合同支持、84条失效Source、4条已有明确缺口/历史覆盖说明。两处C03新增索引失效并入F003；最后批次负对照曾真实捕获空行错误地继承后续表格的问题，检查器已在仓库外修正，再通过当前覆盖、跨章节、空行、反向握手四类负对照；没有以失败检查器的无报错结果作依据。\n\n这只关闭Source索引与分组来源人工待办，不把结果扩展成ASIC CDC签核或未经执行的长期回归结论。关键证据：global_closure_20261004/C01_C10_C13_C14_C15_C16_source_rows_864.json和更新后的C03_C04_source_rows_129.json。\n'
report.write_bytes(t.replace('\n','\r\n').encode('utf-8'))
print('ALL_SOURCE_RULINGS_COMPLETE; F003',dict(counts))
