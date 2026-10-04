"""汇总固定版既有证据；不解析Verilog，presence仅作机械候选。"""
import sys,json,re,hashlib,csv,collections,subprocess,os
import review_driver as d

def evidence():
    prior=json.loads((d.AUDIT/'evidence/id_presence.json').read_text(encoding='utf-8'))
    assert prior['negative_controls']==[[],['contract_table'],['rtl_tag'],['tb_tag_or_text']]
    prefixes=('MGR-','AV4C-','UNPACK-','CCC-','CIS-','ILM-','ISE-')
    rows=[r for r in prior['rows'] if r['id'].startswith(prefixes)]
    d.save_json(d.EVIDENCE/'id_reuse_D.json',{'source':str(d.AUDIT/'evidence/id_presence.json'),'sha256':hashlib.sha256((d.AUDIT/'evidence/id_presence.json').read_bytes()).hexdigest(),'negative_controls':prior['negative_controls'],'rows':rows,'limitation':'TB文字/标签出现不证明执行或真实比较；逐家族语义结论见报告'})
    for prefix in prefixes:
        group=[r for r in rows if r['id'].startswith(prefix)]
        print('ID',prefix,len(group),'MISSING',[(r['id'],r['missing_candidate']) for r in group if r['missing_candidate']])
    prior=json.loads((d.AUDIT/'evidence/anchor_scan.json').read_text(encoding='utf-8'))
    assert prior['negative_controls']==['in_bounds','text_mismatch','missing_file','out_of_bounds']
    assert json.loads((d.AUDIT/'evidence/anchor_negative/results.json').read_text(encoding='utf-8'))==prior['negative_controls']
    own_names={d.Path(r['path']).name for r in d.owned()}
    own_contract={'C02','C03','C04','C05','C06','C07'}
    subset=[r for r in prior['references'] if r['reference'].split(':')[0].split('/')[-1] in own_names or r['reference'].split(':')[0] in own_contract]
    failures=[r for r in subset if r['status'] in ('missing_file','out_of_bounds','text_mismatch')]
    d.save_json(d.EVIDENCE/'anchor_reuse_D.json',{'source':str(d.AUDIT/'evidence/anchor_scan.json'),'negative_controls':prior['negative_controls'],'counts':dict(collections.Counter(r['status'] for r in subset)),'failures':failures,'limitation':'in_bounds不证明语义；复用F-003，不新编号'})
    print('ANCHOR_D',dict(collections.Counter(r['status'] for r in subset)))
    for row in failures[:10]:print('ANCHOR_FAILURE',row['source'],row['line'],row['reference'],row['expected'],row['status'])
    ledger=(d.SOURCE/'contracts/PPG_CONTRACT_CLOSURE_MATRIX.md').read_text(encoding='utf-8').splitlines()
    for n,line in enumerate(ledger,1):
        if 1263<=n<=1309 and re.match(r'\| C0[2-7] \|',line):print('BINDING',n,line)

def logs():
    records=[]
    for row in d.owned():
        if row['layer']!='TB':continue
        name=d.Path(row['path']).stem
        root=d.AUDIT/'evidence/compile'/name
        log=root/'run.log'
        text=log.read_text(encoding='utf-8',errors='replace')
        record={'tb':row['path'],'source_log':str(log),'sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'pass_lines':len(re.findall(r'^PASS\b',text,re.M)),'fail_lines':len(re.findall(r'^FAIL\b',text,re.M)),'run_rc':(root/'run.rc').read_text().strip() if (root/'run.rc').exists() else 'missing','end_record':(root/'run.end').read_text().strip() if (root/'run.end').exists() else 'missing','conclusion_lines':[l for l in text.splitlines() if ('TB_PASS' in l or 'REGRESSION' in l or 'ALL ' in l or 'JNT_BASELINE checked=' in l)]}
        records.append(record)
        print('LOG',name,'PASS_LINES',record['pass_lines'],'FAIL_LINES',record['fail_lines'],'RC',record['run_rc'],'END',record['end_record'])
        if 'control_top_' not in name:
            print(text)
        else:
            print('\n'.join(record['conclusion_lines']))
    d.save_json(d.EVIDENCE/'regression_reuse_D.json',records)

def id_local():
    # 合同文本ID定位，不是Verilog解析；原TB全文比较语义已人工读完。
    pat=re.compile(r'^\s*\|\s*((?:MGR|AV4C|UNPACK|CCC|CIS|ILM|ISE)-\d{2})')
    fixture=[pat.match(s).group(1) if pat.match(s) else None for s in ['| MGR-01复位 | 内容 |','| CCC-04 | 内容 |','| CCC-XX | 内容 |','| WRONG-01 | 内容 |']]
    assert fixture==['MGR-01','CCC-04',None,None],fixture
    families={
        'MGR':('contracts/ppg_system_config_manager_semantic_contract.md',24,'rtl/ppg_system_config_manager/tb_ppg_system_config_manager.v'),
        'AV4C':('contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md',22,'rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v'),
        'UNPACK':('contracts/ppg_system_active_config_unpack_semantic_contract.md',4,'rtl/ppg_system_active_config_unpack/tb_ppg_system_active_config_unpack.v'),
        'CCC':('contracts/PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md',26,'rtl/ppg_characterization_control_cdc/tb_ppg_characterization_control_cdc.v'),
        'CIS':('contracts/PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md',30,None),
        'ILM':('contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md',15,'rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v'),
        'ISE':('contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md',10,'rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v')}
    prior={r['id']:r for r in json.loads((d.EVIDENCE/'id_reuse_D.json').read_text(encoding='utf-8'))['rows']}
    rows=[]
    for family,(contract,count,tb) in families.items():
        identities={}
        for n,line in enumerate((d.SOURCE/contract).read_text(encoding='utf-8').splitlines(),1):
            match=pat.match(line)
            if match and match.group(1).startswith(family+'-'):identities[match.group(1)]=(n,line)
        assert set(identities)=={f'{family}-{n:02d}' for n in range(1,count+1)},(family,identities)
        tb_lines=(d.SOURCE/tb).read_text(encoding='utf-8-sig').splitlines() if tb else []
        for identity,(line,text) in identities.items():
            hits=[n for n,s in enumerate(tb_lines,1) if identity in s] if tb else []
            if family=='CCC':hits=[n for n,s in enumerate(tb_lines,1) if f"check_case(8'd{int(identity[-2:])}," in s]
            notes='模块本地比较已人工核对；缺全局tag/alias只作追溯边界，不等价功能FAIL'
            if identity=='MGR-21':notes='manager无calibration_plan属静态核对；动态请求拒绝属联合Scheduler/AMI/SSW证据，未在manager TB实现，不能借横幅称已测'
            if identity=='MGR-23':hits=[786];notes='固定电流OFF在MGR-18标签下的786行真实比较；合法三光学模式见MGR-17与ILM-04..07，非未测试'
            if identity=='MGR-11':notes='原TB仅非STOP冲突；D-003专项确认STOP同拍违反合同'
            if identity in ('AV4C-02','AV4C-15'):notes='D-004：V5第二跳及若干字段未逐项比较，不能宣称全部具名字段已验收'
            if identity=='AV4C-22':notes='本TB比较导出的资格bit，实际算法门控属于AMI/PWI/叶子验证，不是此wrapper TB的端到端证据'
            if identity=='CCC-22':notes='D-001/F-013纯软件清除比较缺失'
            if family=='CIS':notes='跨层策略编号，无独立RTL模块；C02静态合法性、C07 CDC、C09波形与C25 ILM/JNT分层承接，报告有具体映射；全局CIS字面alias缺失不等价没有行为检查'
            if identity in ('ILM-04','ILM-05','ILM-06','ILM-07'):notes='D-005：LED/EN_TEST边界的点采样不能证明整个RUN；owner数量与颜色比较真实存在'
            if identity in ('ILM-13','ILM-14'):notes='完整静态向量比较一次；持续3000拍检查idle/owner；MUX只前后值比较，不能扩大为所有静态位逐拍/五位转变沿均测'
            if identity in ('ISE-01','ISE-02','ISE-04','ISE-05','ISE-07'):notes='D-006：选中bus最后非零值比较无法证明全波形逐位正确；未选中精度bus有持续逐拍零值断言'
            if identity=='ISE-08':notes='两个颜色独立真实搜索阶段前后码/epoch比较；pending/update未逐拍比较，不把该片段扩大为全部端口验收'
            if identity=='ISE-09':notes='检查最终code/epoch未变；Top实际update/track-adjust未连入本TB，不能称已直接观察全部脉冲'
            if identity=='ISE-10':notes='真实145事务观察F->0回绕；未逐个后续结果比身份快照，只能证明本观察范围'
            pr=prior.get(identity,{})
            rows.append(dict(id=identity,contract=contract,contract_line=line,requirement=text,tb=tb or 'cross-layer policy',tb_text_or_call_lines=hits,rtl_tags=pr.get('rtl_tag',[]),alias_rows=pr.get('alias_row',[]),review_status='完成',semantic_boundary=notes))
    d.save_json(d.EVIDENCE/'id_local_D.json',{'negative_controls':fixture,'rows':rows,'counts':{f:n for f,(_,n,_) in families.items()},'limitation':'review_status是审阅完成，绝不是该ID已验收CLOSED；global closure由A汇总'})
    print('LOCAL_ID_COUNTS',{f:n for f,(_,n,_) in families.items()},'TOTAL',len(rows))
    print('SPECIAL',[(r['id'],r['tb_text_or_call_lines']) for r in rows if r['id'] in ('MGR-23','CCC-04','UNPACK-04')])

def ports():
    rows=[]; gates=[]
    for row in d.owned():
        if row['layer']!='RTL':continue
        name=d.Path(row['path']).stem
        info=json.loads((d.EVIDENCE/'skill_analysis'/name/'rtl_analysis.json').read_text(encoding='utf-8'))
        for p in info['ports']:rows.append(dict(path=row['path'],**p))
        gates.append(dict(path=row['path'],ports=info['module_info']['port_count'],formal_parameter_note='AST的parameter_count包含部分localparam，D-002以源码formal parameter声明为准'))
    d.save_json(d.EVIDENCE/'port_inventory_D.json',{'source':'本组技能formatter-AST产物；signed和复位语义由实际声明/合同人工核对','modules':gates,'ports':rows})
    print('PORT_INVENTORY',len(gates),len(rows))

def tb_gate():
    records=[]
    for row in d.owned():
        if row['layer']!='TB':continue
        name=d.Path(row['path']).stem
        copy=d.EVIDENCE/'tb_gate_inputs'/row['path']
        copy.parent.mkdir(parents=True,exist_ok=True)
        copy.write_bytes((d.SOURCE/row['path']).read_bytes())
        output=d.EVIDENCE/'tb_gates'/name; output.mkdir(parents=True,exist_ok=True)
        args=[sys.executable,'-X','utf8','-B',str(d.SKILL/'scripts/python/validation/verilog_generated_deliverable_gate.py'),str(copy),'--include-testbench','--json',str(output/'gate.json')]
        result=subprocess.run(args,cwd=d.ROOT,capture_output=True,env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',PYTHONUTF8='1'))
        (output/'gate.log').write_bytes(result.stdout+result.stderr)
        record={'tb':row['path'],'rc':result.returncode,'command':args,'report':str(output/'gate.json')}
        if (output/'gate.json').exists():
            report=json.loads((output/'gate.json').read_text(encoding='utf-8')); record['checks']=report.get('checks'); record['rules']=report.get('delivery_issues_by_rule')
        records.append(record)
        print('TB_GATE',name,result.returncode,[(k,v.get('status'),v.get('errors')) for k,v in (record.get('checks') or {}).items()],flush=True)
    d.save_json(d.EVIDENCE/'tb_gate_summary.json',records)

if __name__=='__main__':
    if sys.argv[1]=='evidence':evidence()
    elif sys.argv[1]=='logs':logs()
    elif sys.argv[1]=='id_local':id_local()
    elif sys.argv[1]=='ports':ports()
    elif sys.argv[1]=='tb_gate':tb_gate()
