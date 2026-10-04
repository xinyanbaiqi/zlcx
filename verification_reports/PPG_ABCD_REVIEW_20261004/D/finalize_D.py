"""D组交付核验；只读固定源码，输出本组台账，不解析Verilog。"""
import collections,csv,hashlib,json,re,subprocess,sys
import review_driver as d

def diagnostics():
    records=[]
    for item in json.loads((d.EVIDENCE/'tb_gate_summary.json').read_text(encoding='utf-8')):
        report=json.loads(d.Path(item['report']).read_text(encoding='utf-8'))
        errors=[issue for issue in report['issues'] if issue['code']=='VG000']
        print(d.Path(item['tb']).name, 'FORMATTER_ERRORS',errors)
        records.append({'path':item['tb'],'checks':report['checks'],'parser_diagnostics':errors,'delivery_ready':report['delivery_ready'],'rules':report['delivery_issues_by_rule'],'limitation':'TB风格按用户原任务豁免；formatter静态compile/AST与真实Icarus编译分开，not_requested不能记通过'})
    d.save_json(d.EVIDENCE/'tb_gate_review_D.json',records)
    for item in json.loads((d.EVIDENCE/'gate_reuse.json').read_text(encoding='utf-8')):
        print('RTL_GATE',d.Path(item['path']).name,item['prior_rules'])

def final_baseline():
    original={r['path']:r for r in json.loads((d.EVIDENCE/'baseline.json').read_text(encoding='utf-8'))}
    extra=['rtl/ppg_control_top/ppg_control_top.v','rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh','contracts/PPG_CONTRACT_CLOSURE_MATRIX.md','contracts/PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md']
    paths=[r['path'] for r in d.owned()]+extra
    records=[]
    for path in paths:
        raw=(d.SOURCE/path).read_bytes()
        blob=subprocess.run([d.GIT,'-C',str(d.AUDIT/'zlcx'),'show',d.COMMIT+':'+path],capture_output=True,check=True).stdout
        sha=hashlib.sha256(raw).hexdigest()
        copies=[]
        for folder in ('skill_inputs','tb_gate_inputs'):
            copy=d.EVIDENCE/folder/path
            if copy.exists():copies.append({'copy':str(copy),'byte_equal':copy.read_bytes()==raw})
        row={'path':path,'sha256':sha,'git_blob_equal':raw==blob,'initial_sha_equal':sha==original[path]['sha256'] if path in original else None,'unmodified_gate_copies':copies}
        assert row['git_blob_equal'] and row['initial_sha_equal'] is not False and all(c['byte_equal'] for c in copies),row
        records.append(row)
    head=subprocess.run([d.GIT,'-C',str(d.AUDIT/'zlcx'),'rev-parse','HEAD'],capture_output=True,check=True).stdout.decode().strip()
    status=subprocess.run([d.GIT,'-C',str(d.AUDIT/'zlcx'),'status','--porcelain'],capture_output=True,check=True).stdout.decode('utf-8')
    assert head==d.COMMIT
    result={'commit':head,'git_status_porcelain':status,'records':records,'owned_files':24,'extra_dependencies':len(extra),'note':'复核共享快照/克隆只读一致性；本组变异副本另存evidence，不属于这些输入副本'}
    d.save_json(d.EVIDENCE/'final_baseline_D.json',result)
    print('FINAL_BASELINE',len(records),'HEAD',head,'CLEAN',not bool(status),'UNCHANGED',all(r['git_blob_equal'] for r in records))

def coverage():
    # 以下为已经全文实读和完成专项后的人工结论；不从PASS字样推导语义完成。
    detail={
      'ppg_system_config_manager_semantic_contract.md':('C02 V4.9 / MGR-01..24','正式参数、合法配置、命令优先、generation/episode、排空与异常恢复；D-002/003；MGR-21动态联合层边界已记','evidence/id_local_D.json','D-002/003待设计方修正；MGR-21联合层验收由A/B核实，不宣称本TB已测'),
      'ppg_system_active_config_unpack_semantic_contract.md':('C05 V5 / UNPACK-01..04','1024bit联合位表、signed与零周期映射、保留位；仅4个本地ID，旧台账05已更正；D-002','evidence/id_local_D.json; evidence/tb_ppg_system_active_config_unpack/mapping_mutant.run.log','D-002正式宽度参数合同未落实，待设计方处理'),
      'PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md':('chip V1.15 / F-005..07 / D-007','SPI物理采样、38诊断/128shadow、命令/DBG快照、P2S反压前提、复位/CS_N及模拟pad映射','evidence/anchor_reuse_D.json; evidence/tb_ppg_chip_digital_top/chip_stop_commit.run.log','F-005/006/007、D-007及已知P2S前提尚未修复；无物理签核'),
      'PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md':('C06 V1.3 / CIS-01..30','输入源、EN_TEST/LED、STATIC_BIAS完整向量、MANUAL资格、测量/模拟分离、STOP/abort/reset、跨层CIS映射','evidence/id_local_D.json; evidence/tb_ppg_control_top_input_light_static_matrix/fragment_q3_mutant.run.log','CIS-03/29动态覆盖受D-005限制；CIS-11仅前后值检查不等价五bit转变沿均验收；全局CLOSED由A决定'),
      'PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md':('C07 V1.1 / CCC-01..26','6bit合法序列、valid重武装、稳定载荷、RUN冻结、拒绝优先、clear/STOP/reset及START模式例外；D-001/008','evidence/id_local_D.json; evidence/d_cdc_probe','D-001/F-013和D-008待修正；数字CDC验证不代表物理签核'),
      'PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md':('C03 V1.6 / AV4C-01..22','104端口、source邮箱到manager/unpack、具名V4/V5透传、START与ACTIVE绑定、Top实际第二跳及资格fanout；D-002/004','evidence/port_inventory_D.json; evidence/id_local_D.json','D-002/004待处理；AV4C-22仅资格导出不证明下游算法端到端验收'),
      'PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md':('C04 V1.7 / V4[639:0]+V5[1023:640]','全部字段生产/消费连线、signed 12/20/26/32bit、10权重与V5 fanout；当前依赖2项逐一核对','evidence/port_inventory_D.json; evidence/id_local_D.json','全局矩阵仍NOT_CLOSED；仅tag/alias存在不记ID验收通过'),
      'ppg_active_v4_control_plane_integration.v':('C03/C04/C02/C05 / AV4C-01..22','全文500行/104端口；1024bit CDC、ACTIVE、manager命令、全部unpack输出第二跳和实际Top消费者','evidence/port_inventory_D.json; evidence/skill_analysis/ppg_active_v4_control_plane_integration','默认连接一致；D-002正式参数缺失、D-003命令优先缺陷属于相关路径，未应用修复'),
      'ppg_spi_register_file.v':('chip §4-7 / F-005 / D-007','全文681行/84端口；38字节读map、128shadow逐位写、reserved/invalid、副作用、4命令、DBG快照、首末bit与CS_N','evidence/port_inventory_D.json; PPG_REVIEW_D.md（原SPI日志来源）','F-005真实Mode0首字节错误仍在；D-007片选文档矛盾；不得用legacy采样证明物理接口正确'),
      'ppg_config_cdc_bridge.v':('C03 §3/4 / mailbox','全文192行/9端口；忙拒收、稳定总线、toggle请求/ack、同步标记、目标原子更新、复位清除和时钟间隔','evidence/d_cdc_probe; evidence/skill_analysis/ppg_config_cdc_bridge','快目标部分case复位前已完成，不能称全5case均覆盖严格提交前取消；无MTBF/布局签核'),
      'ppg_p2s_packer.v':('chip §5 / 161bit packet','全文218行/27端口；字段顺序、MSB首末bit、valid/ready、串行有效窗口、FIFO满空/队列与复位','evidence/d_p2s_probe; evidence/skill_analysis/ppg_p2s_packer','7完整包、639反压周期验证packer，未证明AMI遥测在反压下原子对齐；已知3路遥测缺陷按原事项保留'),
      'ppg_characterization_control_cdc.v':('C07 / CCC-01..26','全文222行/16端口；6bit打包、valid重武装、busy冻结/拒绝、enable/MUX输出、sticky清除优先与复位','evidence/d_cdc_probe; evidence/skill_analysis/ppg_characterization_control_cdc','叶子控制行为正常；软件clear的TB覆盖缺D-001/F-013；无物理CDC签核'),
      'ppg_reset_sync.v':('chip §3 / V1.11 erratum / F-007','全文85行/3端口；异步断言、两拍同步释放、初值与复位区分、同步属性、chip仅目标域一实例','evidence/d_cdc_probe; evidence/skill_analysis/ppg_reset_sync','VG060=10已接受可读性积压；F-007复位正文未统一；真实ASIC释放/复位树未签核'),
      'ppg_pulse_cdc_sync.v':('chip §7 / 4 SPI command events','全文110行/6端口；源toggle、目标两级同步/历史差分、单拍脉冲、复位、无反馈事件间隔前提','evidence/d_cdc_probe; evidence/skill_analysis/ppg_pulse_cdc_sync','数字时钟比/相位检查完成；固定SPI事务间隔前提外的任意高速事件流未声称支持'),
      'ppg_system_config_manager.v':('C02 / MGR-01..24','全文733行/33端口；全部状态/合法编码、V4/V5资格、COMMIT/START/STOP/CLEAR、错误及非法状态恢复、epoch/generation/episode','evidence/tb_ppg_system_config_manager; evidence/port_inventory_D.json','D-003 STOP碰撞实缺陷、D-002参数合同矛盾仍在；联合calibration_plan门控按跨层边界'),
      'ppg_chip_digital_top.v':('chip §1-9 / F-005..07 / D-003/007','全文667行/46端口；pad方向/宽度、SPI38诊断与shadow、命令CDC、Top全部模拟控制、P2S数据/valid/backpressure、复位','evidence/tb_ppg_chip_digital_top; evidence/port_inventory_D.json','VG010=46为accepted pad例外；S1 D-003已走真实SPI复现；P2S已知错拍与F-005保留'),
      'ppg_system_active_config_unpack.v':('C05/C04 / UNPACK-01..04','全文211行/68端口；1024bit全部具名切片、10权重、符号、reserved、组合零延迟，无时序状态','evidence/tb_ppg_system_active_config_unpack; evidence/port_inventory_D.json','叶子alpha切片变异可FAIL，不能覆盖wrapper第二跳D-004；D-002正式宽度参数未落实'),
      'tb_ppg_active_v4_control_plane_integration.v':('AV4C-01..22 / D-004','全文889行；输入资格、CDC握手、真实ACTIVE/epoch/generation比较、watchdog/结束；alpha变异22PASS与错误期望FAIL对照','evidence/tb_ppg_active_v4_control_plane_integration; evidence/regression_reuse_D.json','D-004未覆盖全部具名字段；完整22PASS不等价V5第二跳已验收'),
      'tb_ppg_characterization_control_cdc.v':('CCC-01..26 / D-001=F-013','全文497行；26真实check_case、busy/拒绝/模式冻结与复位、watchdog；clear变异26PASS、错误期望FAIL对照','evidence/tb_ppg_characterization_control_cdc; evidence/regression_reuse_D.json','D-001纯软件clear漏比较；叶子26check不扩大为SSW/模拟全系统覆盖'),
      'tb_ppg_control_top_input_light_static_matrix.v':('ILM-01..15 / CIS-01..30 / JNT-54 / D-005','全文2216行含中英文场景历史/实际回补；真实COMMIT/START、owner/颜色/精度、DONE、STOP、static 3000拍、资格窗口/X与watchdog；ILM04三对照','evidence/tb_ppg_control_top_input_light_static_matrix; evidence/regression_reuse_D.json; evidence/id_local_D.json','D-005 LED中间窗口漏查；ILM13/14静态向量仅一次完整比较、MUX前后比较；默认production注入0不等于F-001的注入1环境'),
      'tb_ppg_control_top_idac_bus_isolation.v':('ISE-01..10 / JNT-54 / D-006','全文1532行含中英文历史；真实SAR9/15物理事务、未选中总线持续零检查、选中最后非零、搜索/冻结、145笔wrap、watchdog/结束；ISE04三对照','evidence/tb_ppg_control_top_idac_bus_isolation; evidence/regression_reuse_D.json; evidence/id_local_D.json','D-006选中bus中间错误可被覆盖；ISE08/09未逐拍比pending/update，ISE10不证明全部后续结果身份，边界已记'),
      'tb_ppg_system_config_manager.v':('MGR-01..24 / D-003','全文980行；全部输入驱动和真实比较/错误计数/结束；MGR23通过786行OFF比较，MGR21不在本TB；STOP单独与3冲突专项/错误预期','evidence/tb_ppg_system_config_manager; evidence/id_local_D.json; evidence/regression_reuse_D.json','原MGR11只测READY非STOP冲突；MGR21动态联合层需A/B，不能以横幅推定执行'),
      'tb_ppg_chip_digital_top.v':('chip TC1..6 / F-006 / D-003','全文893行；真实SPI帧与边沿、3诊断读值、模拟pad结构、reset、serial窗口/结束；单STOP/冲突完整pad短专项','evidence/tb_ppg_chip_digital_top; evidence/regression_reuse_D.json; PPG_REVIEW_D.md','F-006 pre-NBA SDO采样掩盖F-005；原TC5未动态选dbg3，TC6窄窗口分支按已接受事项不新编号'),
      'tb_ppg_system_active_config_unpack.v':('UNPACK-01..04','全文340行；1024位one-hot独立期望、signed位宽/10权重/保留区、default映射/结束；alpha切片错位18FAIL负对照','evidence/tb_ppg_system_active_config_unpack; evidence/regression_reuse_D.json','纯叶子切片不证明manager的资格或wrapper第二跳；本地仅4ID，无UNPACK-05'),
    }
    rows=[]; files=[]
    gates={r['path']:r for r in json.loads((d.EVIDENCE/'tb_gate_review_D.json').read_text(encoding='utf-8'))}
    for record in d.owned():
        path=record['path']; name=d.Path(path).name
        scope,meaning,evidence,boundary=detail[name]
        categories=['全文语义与端口合同','复位/状态/异常/握手/位宽/注释','门禁/编译与证据'] if record['layer']=='RTL' else (['全文语义比较与输入资格','有效覆盖/负对照/结束条件','技能静态门禁/真实编译'] if record['layer']=='TB' else ['全文内部一致性与RTL映射','版本/ID/矩阵追溯核验'])
        statuses=[]
        for item in categories:
            state='完成'; ev='PPG_REVIEW_D.md; evidence/final_baseline_D.json; '+evidence; note=boundary
            if record['layer']=='RTL' and item=='门禁/编译与证据':
                ev='evidence/gate_reuse.json; evidence/skill_analysis; evidence/regression_reuse_D.json; PPG_REVIEW_D.md'
                note+='；公共testbench/toolchain为not_requested；真实Icarus证据另列，xsim/Verilator/综合未运行'
            if record['layer']=='TB' and item=='技能静态门禁/真实编译':
                gate=gates[path]; state='部分' if gate['parser_diagnostics'] else '完成'
                ev='evidence/tb_gate_review_D.json; evidence/tb_gates/'+d.Path(path).stem+'/gate.json; evidence/regression_reuse_D.json'
                note='真实Icarus编译/运行见A固定版原始证据；TB风格豁免，不计新S4；toolchain未请求；comment scanned_files=0不作全文扫描通过证据'
                if state=='部分':note+='；formatter静态compile/AST失败，未绕过或记通过：'+str([x['message'] for x in gate['parser_diagnostics']])
            rows.append(dict(owner='D',path=path,check_item=item,contract_or_id=scope,status=state,evidence=ev,remaining=note))
            statuses.append(state)
        files.append(dict(path=path,layer=record['layer'],status='部分' if '部分' in statuses else '完成',full_text_review='完成',scope=scope,actual_review=meaning,evidence=evidence,remaining=boundary))
    assert len(files)==24 and len(rows)==65 and len(detail)==24
    with (d.ROOT/'coverage.csv').open('w',encoding='utf-8-sig',newline='') as handle:
        writer=csv.DictWriter(handle,fieldnames=['owner','path','check_item','contract_or_id','status','evidence','remaining']);writer.writeheader();writer.writerows(rows)
    result={'status_meaning':'全文/专项审阅完成不代表bug已修、ID CLOSED或全部门禁通过。5TB formatter AST留项，文件整体部分。','files':files,'rows':rows,'file_status_counts':dict(collections.Counter(x['status'] for x in files)),'row_status_counts':dict(collections.Counter(x['status'] for x in rows))}
    d.save_json(d.EVIDENCE/'review_ledger_D.json',result)
    print('COVERAGE',len(files),len(rows),result['file_status_counts'],result['row_status_counts'])
    table=['| 文件（均为固定快照相对路径） | 层/行数 | 本组实际检查与语义边界 | 状态 |','| --- | --- | --- | --- |']
    baseline={r['path']:r for r in json.loads((d.EVIDENCE/'baseline.json').read_text(encoding='utf-8'))}
    for x in files:table.append('| '+x['path']+' | '+x['layer']+'/'+str(baseline[x['path']]['lines'])+' | '+x['scope']+'；'+x['actual_review']+'；'+x['remaining']+' | '+x['status']+' |')
    (d.EVIDENCE/'file_review_table_D.md').write_text('\n'.join(table)+'\n',encoding='utf-8')

def integrity():
    report_path=d.ROOT/'PPG_REVIEW_D.md'
    report=report_path.read_text(encoding='utf-8')
    heading='## 逐文件实际审阅表（最终台账）'
    if heading not in report:
        report+='\n'+heading+'\n\n'+(d.EVIDENCE/'file_review_table_D.md').read_text(encoding='utf-8')
        report_path.write_text(report,encoding='utf-8')
    findings=re.findall(r'^## (D-\d{3})：',report,re.M)
    assert len(findings)==8 and set(findings)=={f'D-{n:03d}' for n in range(1,9)},findings
    for identity in findings:
        section=report.split('## '+identity+'：',1)[1].split('\n## ',1)[0]
        quotes=re.findall(r'```(?:verilog|text)\n(.*?)\n```',section,re.S)
        assert len(quotes)==1 and len(quotes[0].splitlines())<=3,(identity,quotes)
        assert all(word in section for word in ('置信度','反驳','建议')),identity
    with (d.ROOT/'coverage.csv').open(encoding='utf-8-sig',newline='') as handle:rows=list(csv.DictReader(handle))
    ledger=json.loads((d.EVIDENCE/'review_ledger_D.json').read_text(encoding='utf-8'))
    assert rows==ledger['rows'] and len(rows)==65
    assert collections.Counter(x['status'] for x in rows)=={'完成':60,'部分':5}
    assert len({x['path'] for x in rows})==24
    assert len(json.loads((d.EVIDENCE/'port_inventory_D.json').read_text(encoding='utf-8'))['ports'])==396
    assert len(json.loads((d.EVIDENCE/'id_local_D.json').read_text(encoding='utf-8'))['rows'])==131
    tb_gates=json.loads((d.EVIDENCE/'tb_gate_review_D.json').read_text(encoding='utf-8'))
    assert len(tb_gates)==7 and sum(g['checks']['ast']['status']=='passed' for g in tb_gates)==2
    assert all(g['checks']['testbench']['status']=='passed' and g['checks']['toolchain']['status']=='not_requested' and g['checks']['comment']['metrics']['scanned_files']==0 for g in tb_gates)
    rtl_gates=json.loads((d.EVIDENCE/'gate_reuse.json').read_text(encoding='utf-8'))
    assert len(rtl_gates)==10 and all(g['analysis_rc']==0 and g['prior_checks']['compile']['status']=='passed' and g['prior_checks']['ast']['status']=='passed' and g['prior_checks']['comment']['metrics']['scanned_files']==0 for g in rtl_gates)
    assert dict(sum((collections.Counter(g['prior_rules']) for g in rtl_gates),collections.Counter()))=={'VG060':10,'VG010':46}
    anchor=json.loads((d.EVIDENCE/'anchor_reuse_D.json').read_text(encoding='utf-8'))
    print('ANCHOR_ACTUAL_COUNTS',anchor['counts'])
    expected=[
      ('tb_ppg_characterization_control_cdc/clear_mutant.run.log','ALL CCC-01 TO CCC-26 PASS'),
      ('tb_ppg_characterization_control_cdc/negative.run.log','FAIL CCC-4'),
      ('tb_ppg_active_v4_control_plane_integration/alpha_mutant.run.log','ALL AV4C-01 THROUGH AV4C-22 PASSED'),
      ('tb_ppg_system_config_manager/stop_only.run.log','D_STOP_PASS'),
      ('tb_ppg_system_config_manager/stop_start.run.log','D_STOP_FAIL'),
      ('tb_ppg_system_config_manager/stop_commit.run.log','D_STOP_FAIL'),
      ('tb_ppg_system_config_manager/stop_clear.run.log','D_STOP_FAIL'),
      ('tb_ppg_chip_digital_top/chip_stop_only.run.log','D_CHIP_STOP_PASS'),
      ('tb_ppg_chip_digital_top/chip_stop_commit.run.log','D_CHIP_STOP_FAIL'),
      ('tb_ppg_control_top_input_light_static_matrix/fragment_positive.run.log','errors=0 observed_led_violation=0'),
      ('tb_ppg_control_top_input_light_static_matrix/fragment_q3_mutant.run.log','errors=0 observed_led_violation=12'),
      ('tb_ppg_control_top_input_light_static_matrix/fragment_negative.run.log','errors=1'),
      ('tb_ppg_control_top_idac_bus_isolation/fragment_positive.run.log','errors=0 observed_active_bus_violation=0'),
      ('tb_ppg_control_top_idac_bus_isolation/fragment_onecycle_mutant.run.log','errors=0 observed_active_bus_violation=2'),
      ('tb_ppg_control_top_idac_bus_isolation/fragment_negative.run.log','errors=2'),
      ('d_p2s_probe/positive.run.log','complete_packets=7 backpressure_cycles=639'),
      ('d_p2s_probe/negative.run.log','P2S_BIT_FAIL packet=0 bit=160')]
    verified=[]
    for path,marker in expected:
        file=d.EVIDENCE/path
        text=file.read_text(encoding='utf-8',errors='replace')
        assert marker in text,(path,marker)
        verified.append({'path':str(file),'checked_marker':marker,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
    for item in ledger['files']:
        for ref in item['evidence'].split('; '):
            if ref.startswith('evidence/'):assert (d.ROOT/ref).exists(),ref
    a_report=d.AUDIT/'PPG_FULL_REVIEW_20261002.md'
    a_text=a_report.read_text(encoding='utf-8')
    mapping={'D-001':'F-013','D-002':'F-024','D-003':'F-023','D-004':'F-025','D-005':'F-028','D-006':'F-029','D-007':'F-030'}
    for identity,unified in mapping.items():assert '### '+unified in a_text,(identity,unified)
    d.save_json(d.EVIDENCE/'final_integrity_D.json',{'findings':findings,'file_count':24,'coverage_rows':65,'row_counts':dict(collections.Counter(x['status'] for x in rows)),'ports':396,'local_ids':131,'verified_raw_logs':verified,'merged_mappings':mapping,'A_report_source':str(a_report),'A_report_sha256':hashlib.sha256(a_report.read_bytes()).hexdigest(),'limitations':'日志标记核验仅验证报告取证位置/数值，不替代已完成的源码语义审查；失败门禁保持部分'})
    print('FINAL_INTEGRITY_OK',len(findings),'findings',len(verified),'raw_logs',len(rows),'ledger_rows')

if __name__=='__main__':
    {'diagnostics':diagnostics,'baseline':final_baseline,'coverage':coverage,'integrity':integrity}[sys.argv[1]]()
