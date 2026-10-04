from pathlib import Path
import json,csv,re,collections,runpy,contextlib,io
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';out=E/'global_closure_20261004'
matrix='contracts/PPG_CONTRACT_CLOSURE_MATRIX.md';mapping='contracts/PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md';cf4='contracts/PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md';top='rtl/ppg_control_top/ppg_control_top.v';wrapper_tb='rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v';manager='rtl/ppg_system_config_manager/ppg_system_config_manager.v';prefix='rtl/ppg_control_top/tb_ppg_jnt_baseline_prefix.vh';sup='rtl/ppg_system_fault_abort_supervisor/ppg_system_fault_abort_supervisor.v';suptb='rtl/ppg_system_fault_abort_supervisor/tb_ppg_system_fault_abort_supervisor.v';lfa='rtl/ppg_control_top/tb_ppg_control_top_lifecycle_fault_adc_anomaly.v';amitb='rtl/ppg_adc_measurement_idac_integration/tb_ppg_adc_measurement_idac_integration.v'
samples=[
('AV4',[(mapping,606,'AV4-01'),(wrapper_tb,649,'o_active_config'),(mapping,621,'AV4-16'),(wrapper_tb,815,'o_active_config')],'19个C04连接验收条款不是AV4C编号的逐号别名；1024-bit COMMIT直连唯一unpack、具名V5到AMI/PWI、码快照与epoch静态逐跳和AV4C01/21、TOP02、MGR/UNPACK分担验证。F-025的alpha缺比较保留，不能据AV4C22 PASS宣称全部V5字段动态已验证。'),
('CF4',[(cf4,670,'CF4-01'),(cf4,674,'CF4-05'),(manager,314,"8'h04"),(manager,317,'639:592')],'schema4和保留位由唯一manager资格门检查，MGR12真实非法schema/bit639比较及MGR03合法提交补样本；16bit interval不存在额外数值拒绝比较，0/1/4096/65535静态均可表示；RUN只允许CONFIG COMMIT，当前规范字段仍保持。五个CF4未形成独立命名TB，不制造全量动态四端点已PASS结论。'),
('D',[(matrix,3536,'D02'),(matrix,3585,'D03'),(top,123,'i_adc_physical_idle')],'D01/D02/D03是产品接口决策及关联门禁；D02端口已存在，D03模拟收敛不适用已冻结为用户已知，不要求虚造独立TB/RTL标签。'),
('D01',[(matrix,3599,'peak_valley_config_valid'),(wrapper_tb,824,'peak_valley_config_valid')],'V5 safety-valid同一unpack->AMI->PWI->三leaf链及reset valid0/合法commit释放真实比较；F-034同拍discard/safe提交优先级反例仍适用。'),
('G-FP',[(matrix,3599,'G-FP-01-D01-04'),(matrix,3602,'G-FP-05-D01-01'),(top,104,'C_CONFIG_WIDTH')],'G-FP01..07及D01子项是端口、状态、故障、参数、CDC、产品台账门禁，机械ID不等于一个RTL状态机。C01 165边界端口完成独立名称/方向/默认宽度核对；其他cluster按B/C/D端口表实读，用户已知的独立签核不足仍明确保留；参数F014/F024、manifest F045、失效锚点F003不能被旧CLOSED文字覆盖。'),
('JNT',[(prefix,638,'JNT-02-IR-PREESTABLISH'),(prefix,796,'flag_jnt_baseline_pass'),(prefix,800,'status=FAIL')],'9稳定ID由共享prefix54子比较实现，全部14真实include已自包含编译；跨整个Top的验收无需单模块tag（别名表明示N/A）。原19系统已完成者逐log确认JNT54；数量不足终判传递错误F037必须保留；剩余长回归不填PASS。'),
('K',[(sup,198,'flag_episode_open_edge'),(suptb,480,'SUP10A')],'K01五路根故障->AMI->supervisor，K02episode与首故障分离，K03generation参数，K04代际discard，K05层级排他逐跳核对。SUP10A缺保留旧首故障刺激F012；PWC sticky START历史F022、clear归因F046、SSW碰撞F035均可反驳局部CLOSED。'),
('L',[(matrix,996,'L01'),(matrix,167,'active normative')],'L01是版本/规范优先级清理项，别名表明确N/A；全部141依赖及26原Git blob核对，不要求独立硬件tag。F047基础标签与增量版本关系未明示仍保留。'),
('N',[(amitb,1616,'N08-01'),(amitb,1619,'o_detection_discard_frame_id'),(manager,533,'run_generation_o'),(top,329,'flag_diag_clear_event')],'N08真实pre-handoff判据及系统scope-only flush互补，N01四consumer empty真实比较；N02generation唯一producer静态，N03SUP同拍仲裁，N04两腿未单独隔离为用户已知且F048名单冲突，N05Top锁模式，N06SUPwatchdog/episode但旧first-fault保留验证不足F012，N07是TB方法规范无需RTL锚点。'),
('P',[(lfa,1622,'o_measurement_result_valid'),(lfa,1639,'discard identity mismatch'),(lfa,1644,'cnt_result_capture')],'P01真实ready/abort同拍优先与完整identity逐场景核对，P02/N01同源discard，P03注册merge，P04/09/10由SUP模块补证，P05watchdog，P06合法Top RUN去使能不可达而叶子问题F044仅疑似，P07/08/11/14引用INJ/LFA/OIB且有限比较F049保留，P12/15/16/17是静态参数/连线或方法义务，P13 fork原50比较；P10逐hex未测为用户已知。'),
('R',[(matrix,997,'R01'),(matrix,1005,'R09')],'R01..09是历史冲突修复追溯，不是9个新增运行场景。当前端口/层级与141依赖源已实读；C01 discard/诊断清除文字和C09版本关系仍有F008/F048/F047，未因历史Replaced自动判当前一致。')]
records=[]
for name,refs,decision in samples:
    verified=[]
    for file,line,token in refs:
        value=(S/file).read_text(encoding='utf-8').splitlines()[line-1]
        assert token in value,(name,file,line,token,value)
        verified.append(dict(file=file,line=line,text=value,token=token))
    records.append(dict(family=name,refs=verified,decision=decision))
(out/'A_remaining_family_adjudication.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
families=json.loads((out/'family_summary.json').read_text(encoding='utf-8'))
audited={r['family'] for r in families if r['with_semantic_record']}|{r['family'] for r in records}
assert audited=={r['family'] for r in families},sorted({r['family'] for r in families}-audited)
report=B/'PPG_FULL_REVIEW_20261002.md';text=report.read_text(encoding='utf-8');heading='## A 全局四链及标签检查点：2026-10-04'
if heading not in text:
    text+='\n'+heading+'\n\n全量机械四链表all_id_four_links.csv包含838个候选，涵盖当前模块/系统验收、历史引用和G-FP子项；不把它当约319个系统ID的总数。已合并745个候选的A/B/C/D逐ID语义记录，其余93个按下表裁定。46个家族均有实际源码/条款代表样本审阅；各组部分或待动态项保持原限制，不把合并操作算成A逐ID重新仿真。四类缺边负对照分别报出唯一删除的边。\n\n'
    text+='| 剩余家族 | 源码/当前条款样本 | 范围裁定 |\n|---|---|---|\n'
    for r in records:text+='| '+r['family']+' | '+'; '.join(f"{Path(x['file']).name}:{x['line']}" for x in r['refs'])+' | '+r['decision']+' |\n'
    text+='\n已确认的矩阵/别名语义错误为F003、F045、F046及相关合同F047/F048；用户明确已知的§13.1快照滞后、G-FP独立复核不足及工具签核局限不重复编号。缺字面tag/索引只是四链候选，模块级共享比较、静态义务和N/A理由列明；未称所有838候选已达到四边逐ID规范签核。\n'
report.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
print('ALL_FAMILIES_SAMPLED',len(audited),'A_REMAINING',len(records))
