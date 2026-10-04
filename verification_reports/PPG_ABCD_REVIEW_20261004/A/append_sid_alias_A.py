from pathlib import Path
import csv,re,json,collections
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';report=B/'PPG_FULL_REVIEW_20261002.md';text=report.read_text(encoding='utf-8')
alias='contracts/PPG_ALIAS_MAPPING_TABLE.md';tb='rtl/ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v';contract='contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md';ami='rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v'
def quote(file,line,token):
    value=(S/file).read_text(encoding='utf-8').splitlines()[line-1];assert token in value,(file,line,token)
    return f'`{file}:{line}`\n> {value.strip()}\n'
if '### F-050' not in text:
    current=[(n,l) for n,l in enumerate((S/contract).read_text(encoding='utf-8').splitlines(),1) if re.match(r'\| SID-11 \|',l)]
    assert len(current)==1
    section='''### F-050：别名表仍把现有 SID-11 注入场景列为结构不可达的 SKIP

- 严重度：S3；层：矩阵·台账；置信度：静态确认（文档及代码存在事实）。
- 位置与原文：
'''+quote(alias,148,'延期,结构性不可达')+quote(contract,current[0][0],'SID-11')+quote(tb,1033,'i_test_saturation_inject_valid')+'''
- 描述：当前别名行将SID-11写成“SKIP非PASS”，引用数值校准器两方向饱和互斥作为永远无法构造的理由；当前TB阶段B2却已在一笔真实Q3/RAW事务上通过公开专用饱和注入口构造双饱和，1044-1055真正检查fire出现、AMB码不推进和无硬故障，再条件打印PASS SID-11。该行没有标历史或删除线，当前表内状态及锚点都未跟随新的测试边界。
- 反驳：(a) 数值校准器本身确实互斥，但AMI的专用注入口在身份匹配后的搜索评价支路注入，并不要求数值校准器天然同时产生两位；Top TB覆盖参数打开并驱动公开输入，不使用Verilog force。(b) 用户第4节未将SID-11旧延期登记列为已知项，和已知SID-05/tick248截止错误不同。(c) C10/C01/C25允许专用受保护注入；C25仍定义SID-11义务，别名:481也引用SID-10/SID-11作为N05证据，与:148长期SKIP自身矛盾。已检查本表全570行，没有后文把:148标成历史或明确改为现行公开注入场景。
- 证据限度：本条只确认“被审版本已有实际激励和真实比較分支，旧结构不可达理由失效”；当前完整SID原回归尚在队列/执行中，未据TB自己的PASS文本、changelog或旧报告声称本次已通过。动态终态将归入§6。
- 建议方向：将SID-11别名改为当前公开注入场景及对应AMI入口，明确其本次回归实际结果。

'''
    text=text.replace('## 4. 已知事项',section+'## 4. 已知事项',1)
csv_path=E/'anchor_failures.csv';rows=list(csv.DictReader(csv_path.read_text(encoding='utf-8-sig').splitlines()));keys={(r['source'],str(r['line']),r['reference'],r['expected']) for r in rows}
source=(S/alias).read_text(encoding='utf-8').splitlines();target=(S/ami).read_text(encoding='utf-8').splitlines()
for line in (47,147,455):
    assert 'ppg_adc_measurement_idac_integration.v:908' in source[line-1]
    assert 'dec_completion_sample_index' not in target[907] and 'flag_test_inject_effective' in target[907]
    assert 'dec_completion_sample_index' in target[910]
    row=dict(source=alias,line=line,reference='ppg_adc_measurement_idac_integration.v:908',kind='explicit_file_line',expected='dec_completion_sample_index',status='text_mismatch',target=target[907])
    key=(alias,str(line),row['reference'],row['expected'])
    if key not in keys:rows.append(row);keys.add(key)
with csv_path.open('w',encoding='utf-8-sig',newline='') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
counts=collections.Counter(r['status'] for r in rows)
assert counts['text_mismatch']==186 and len(rows)==200,counts
text=text.replace('累计183个文字不匹配记录。','累计183个文字不匹配记录；本轮全量标签核对又逐条确认别名:47/147/455三处仍将dec_completion_sample_index指到AMI:908（实际为flag_test_inject_effective，当前目标为:911），累计186处。')
text=text.replace('不能当成183个独立功能错误。','不能当成186个独立功能错误。')
report.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
print('SID_ALIAS F050 saved; F003 confirmed anchor records',len(rows),dict(counts))
