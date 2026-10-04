from pathlib import Path
import json,re,hashlib
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
GD=B.parent.parent/'01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D';GC=B.parent.parent/'01a0fd78-b9b8-78f2-8e39-c02cd0049c19/ppg_review_C'
refs={
 'F-025':[('rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v',192,'o_alpha_q15'),('rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v',674,'AV4C-02'),('rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v',679,'PASS AV4C-02')],
 'F-026':[('rtl/ppg_adc_result_router/ppg_adc_result_router.v',88,'i_run_generation'),('rtl/ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v',69,'i_datapath_discard_event'),('rtl/ppg_adc_dc_recovery/ppg_adc_dc_recovery.v',93,'i_detect_code')],
 'F-027':[('rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v',338,'PR-06'),('rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v',339,"32'sd32768"),('rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v',340,"-32'sd32768")],
 'F-028':[('rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v',1677,'o_leddac'),('rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v',1680,'wait_q3_release'),('rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v',1694,'PASS ILM-04')],
 'F-029':[('rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v',780,'reg_seen_sar9_ambn'),('rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v',815,'reg_ise_seen_ambn'),('rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v',954,'reg_seen_sar9_ambn')],
 'F-030':[('contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md',128,'`CS_N`仍需过标准两级同步器'),('rtl/ppg_chip_digital_top/ppg_chip_digital_top.v',385,'SPI_CS_N'),('rtl/ppg_spi_register_file/ppg_spi_register_file.v',432,'posedge i_spi_cs_n')]
}
out={};quotes={}
for fid,items in refs.items():
    quotes[fid]=[];out[fid]=[]
    for rel,n,key in items:
        raw=(S/rel).read_bytes();line=raw.decode('utf-8-sig').splitlines()[n-1];assert key in line,(fid,rel,n,line)
        out[fid].append({'file':rel,'line':n,'text':line,'sha256':hashlib.sha256(raw).hexdigest()})
        q=line.strip() if n in (338,674) else line.split('//',1)[0].strip()
        if fid=='F-030' and rel.endswith('.md'):q='`CS_N`仍需过标准两级同步器，但只用于门控/复位比特计数器，不用于推导任何离散事件的触发时刻';assert q in line
        quotes[fid].append(q)
simrecords=[]
for folder,labels in [
('tb_ppg_active_v4_control_plane_integration',['alpha_mutant','negative']),
('tb_ppg_control_top_input_light_static_matrix',['fragment_positive','fragment_q3_mutant','fragment_negative']),
('tb_ppg_control_top_idac_bus_isolation',['fragment_positive','fragment_onecycle_mutant','fragment_negative'])]:
    for label in labels:
        d=GD/'evidence'/folder;m=json.loads((d/(label+'.result.json')).read_text(encoding='utf-8'));assert m.get('compile_rc',m.get('compileCode'))==0,m
        raw=(d/(label+'.run.log')).read_bytes();t=raw.decode('utf-8',errors='replace').replace('\x00','')
        simrecords.append({'case':folder+'/'+label,'metadata':m,'log':str(d/(label+'.run.log')),'sha256':hashlib.sha256(raw).hexdigest(),'design_lines':[l for l in t.splitlines() if re.match(r'^(PASS|FAIL|D_|ALL AV4C|DIAG)',l)]})
omitted={}
for name,count in [('ppg_adc_result_router',1),('ppg_adc_pipeline_overlap_corrector',10),('ppg_adc_dc_recovery',8),('ppg_normal_transaction_fork',10)]:
    raw=(E/'compile'/('tb_'+name)/'compile.log').read_bytes();matches=re.findall(r'\((i_\w+)\) floating',raw.decode('utf-8',errors='replace'));assert len(matches)==count,(name,matches)
    omitted[name]={'dangling_input_ports':matches,'raw_compile_log':str(E/'compile'/('tb_'+name)/'compile.log')}
(E/'merged_findings_oct4c_refs.json').write_text(json.dumps({'refs':out,'simulations':simrecords,'real_compiler_omissions':omitted},ensure_ascii=False,indent=2),encoding='utf-8')
details={
'F-025':'''### F-025：ACTIVE wrapper 的字段透传检查漏 alpha，固定错误输出仍 22 PASS

- 严重度/层：S2 / TB；置信度：仿真确认。关联D-004。
- 位置：`rtl/ppg_active_v4_control_plane_integration/tb_ppg_active_v4_control_plane_integration.v:192,674,679`，原文3行（注释行保留）：
{quote}
- 描述/依据：C03:246-251要求V5具名字段原样输出，AV4C-02:296要求具名字段正确。TB声明/连接alpha，但675的长比较没有它；全文件搜索alpha只有声明/连接与配置字段，没有输出比较。默认合法值TB:79为199A，错误全零应被识别。
- 证据：D外部wrapper副本只将356的alpha输出置0000，完整原TB仍22个PASS及`ALL AV4C-01 THROUGH AV4C-22 PASSED`，编译0运行0。错误AV4C-01期望负对照报`FAIL AV4 control plane self-check errors=1`；A已核对实际单行变异、完整原日志/命令及合同。其他未逐一变异字段不按本项宣称全量证明。
- 反驳：unpack叶子1024-bit one-hot比较确实有效，切片变异有18个FAIL，但没有经过wrapper第二跳，不能覆盖本次输出变异；本条不推断系统层完全没覆盖。实际生产alpha透传正确，无RTL错误指控，无已知事项豁免。
- 建议方向：对wrapper具名输出用完整合法非对称配置逐项独立比较。
''',
'F-026':'''### F-026：四份 ADC/fork 模块 TB 漏接 29 个现有输入

- 严重度/层：S2 / TB；置信度：静态确认及真实编译诊断。关联C-002，统一四文件一条，未证明生产数值算法故障。
- 位置：三个代表性实际端口分别为 `rtl/ppg_adc_result_router/ppg_adc_result_router.v:88`、`rtl/ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v:69`、`rtl/ppg_adc_dc_recovery/ppg_adc_dc_recovery.v:93`，原文3行：
{quote}
- 描述/依据：Router TB:465-514缺run_generation；overlap TB:753-802缺run_generation及9个discard输入；DC TB:444-474缺detect_code、两级raw/code_ext及nominal15三诊断输入；NORMAL fork TB:525以后完整绑定缺10个generation/discard输入。合计1+10+8+10=29。实际Icarus -Wall分别精确报1/10/8/10个dangling input，名称清单在evidence/merged_findings_oct4c_refs.json；C组skill AST及完整绑定人工核对一致。
- 证据：原始编译例 `warning: Instantiating module ppg_adc_result_router with dangling input port 22 (i_run_generation) floating.`；这些未绑定输入为Z，TB没有对应有效窗口比较。四份原正常数值/FFK PASS仅支持已有真实比较，不能证明新代际、cancel及DC诊断payload接口；无新增全字段变异完成声明。
- 反驳：AMI实际生产实例有连接，不使这四份模块TB缺失激励变成存在；系统覆盖仍须逐项追溯，不声称全系统都漏。C11/C14/C15条件豁免是不同模块/不可达discard前提，不豁免这些已有接口的输入驱动及DC诊断透传。与F-001四份注入系统TB、五组悬空输出及TRK-01原子耦合不可测试不同。
- 建议方向：补齐公开输入驱动，并以错generation/诊断透传等变异核实实际比较。
''',
'F-027':'''### F-027：PR-06 正负半值标签未构造门限，舍入门限变异逃过完整原 TB

- 严重度/层：S2 / TB；置信度：静态公式、短Verilog及真实变异确认。关联C-003，按本任务验证缺口统一为S2。
- 位置：`rtl/ppg_adc_programmable_reconstructor/tb_ppg_adc_programmable_reconstructor.v:338-340`，原文3行：
{quote}
- 描述/依据：C14:141-143/162-165及PR-06:334要求正负对称门限。S1=256给S1_CENTER_X2=1，Stage1贡献3533837；D2=256/gain0，offset±32768只增加±65536，实际总ACC为3599373/3468301，均正，输出27/26。offset是半值不等于总累加值在门限。
- 证据：A `pr06_formula_actual`六个独立整数期望的短Verilog编译0运行0，输出`PR06_POS_OFFSET acc=3599373 rounded=27`、`PR06_NEG_OFFSET acc=3468301 rounded=26`；错27→28的负对照fatal。C已完成真实DUT公开邻点四向量输出0/1/0/-1；仅将ROUND_HALF_Q17从65536变65534的外部RTL，完整原TB仍`PASS ... PR-01..PR-14 and 1024-code sweep`，新增邻点第二比较却fatal `case 1 got=0`。原始日志在C evidence/targeted_runtime_20261004/reconstructor_{original,round_mutant,legacy_mutant}，A读实际TB/变异及日志。
- 反驳：1024码sweep包含正负，最近距门限25 Q17单位，故不称整个TB没有负舍入覆盖。合法总ACC恒奇数、精确半值不可达，应测门限两侧可达邻点；不能通过强制中间量造非法tie。overlap另有有效邻点不是本DUT，PRC-04已知项也不相关。原RTL舍入正确，仅验证证据不足。
- 建议方向：用公开输入构造正负门限两侧可达邻点，并同步PR-06覆盖文字。
''',
'F-028':'''### F-028：ILM-04/05 LED 禁止驱动检查跳过真实转换窗口

- 严重度/层：S2 / TB；置信度：ILM-04原场景短片段变异确认，ILM-05同结构静态确认。关联D-005。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_input_light_static_matrix.v:1677,1680,1694`，原文3行：
{quote}
- 描述/依据：C25:632-633要求固定电流转换EN_TEST高、LEDEN低且无LEDDAC窗口。原循环每笔在wait_q3_release前只采一次，整个等待Q3窗口没有继续检查。
- 证据：D按固定原文件行复制初始化/task/monitor与ILM-04六笔真实RED/IR、实际Top链，外部Top仅在EXTERNAL_TEST_CURRENT且Q3时映射LEDDAC=01；独立negedge监视实见12个非法周期，原比较却`PASS ILM-04 ... RED=3 IR=3`、`D_ILM_FRAGMENT errors=0 observed_led_violation=12`。未变异违规0；错期望00→01负对照errors1且FAIL。三次编译0运行0，判据从实际错误计数/日志取，不使用rc0判通过。A已读复制脚本、变异、合同及原始日志/命令。
- 反驳：完整TB/共享前缀无在该六笔事务持续运行的固定电流逐拍监视；ILM-10另一个40拍场景不能覆盖本窗口。SSW叶子检查不经过Top映射，未替代覆盖。与后续回补ILM-11/12、冻结D03或P2S不同；不是生产RTL错误。未重跑完整长回归的变异，不称全73 PASS逃逸。
- 建议方向：对合法固定电流RUN的有效窗口持续检查三个输出并计数。
''',
'F-029':'''### F-029：ISE 选中总线的最后非零值比较漏掉中间一拍错误

- 严重度/层：S2 / TB；置信度：原ISE-04短片段变异确认，其他同构selected监视为静态确认。关联D-006。
- 位置：`rtl/ppg_control_top/tb_ppg_control_top_idac_bus_isolation.v:780,815,954`，原文3行：
{quote}
- 描述/依据：C25:665/667-670要求当前波形逐位冻结/门控。监视器只记最后非零值，不积累中途不匹配；下一正确值能覆盖此前错误，零值也被忽略，不能证明958所称整个Q3 bit-for-bit保持。
- 证据：D复制ISE-04 Phase A两笔真实SAR9事务及完整Top，外部Top仅每次Q3首周期将A5翻为A4、下一周期恢复。独立negedge检查2个错误周期，原两比较仍PASS，`D_ISE_FRAGMENT errors=0 observed_active_bus_violation=2 zero_checks=5305`；原对照违规0，错误期望A4产生2 FAIL/errors2。编译均0运行均0，使用真实FAIL/计数。A核对实际脉冲条件确实命中、原始日志和命令，初次条件不命中的nontrigger_setup未采用。
- 反驳：未选中精度总线持续零比较776/785是真实有效的5305/5308计数，不扩大为四总线全未查。JNT前置事务不持续覆盖这两笔，叶子SSW局部正确不检查Top映射。实际生产映射正常，不报RTL错；无已知事项豁免。未声称完整长TB变异仍70 PASS。
- 建议方向：按具体AMB/DC有效窗口逐拍比较并锁存错误，窗口外核对合法idle值。
''',
'F-030':'''### F-030：SPI CS_N 两级同步规范与实际原始片选异步复位不一致

- 严重度/层：S3 / 合同·跨层；置信度：静态确认规范/实现矛盾，不据此声称物理CDC故障。关联D-007。
- 位置：`contracts/PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md:128`（句片段）、chip RTL:385与SPI RTL:432，原文3行：
{quote}
- 描述/依据：chip直接连接pad；SPI全部CS_N使用在372/413/432/447/458/472/481等异步清零及电平门控，没有标准两级CS_N同步链。事件仍由完整字节生成，不能使同步要求成立。
- 反驳/证据：已读chip/SPI全文件、全部CS_N使用和合同勘误。reset_sync处理RSTN、ADC idle同步处理ADC idle，均不处理CS。V1.11仅豁免SPI独立复位同步，V1.15只改诊断快照，未修订CS条款；F-007为RSTN文档冲突，F-005为读位功能，不重复。不是user接受的ASIC CDC签核限制。本项无需仿真来证明没有声明/连线，不要求机械添加两拍改变SPI协议。
- 建议方向：由接口owner明确CS_N异步协议约束或同步方案，同步冻结合同。
'''
}
r=B/'PPG_FULL_REVIEW_20261002.md';txt=r.read_text(encoding='utf-8')
for fid,body in details.items():
    if '### '+fid in txt:continue
    q='```text\n'+'\n'.join(quotes[fid])+'\n```';body=body.replace('{quote}',q)
    pos=txt.index('### F-002' if fid!='F-030' else '## 4. 已知事项');txt=txt[:pos]+body+'\n'+txt[pos:]
txt+='\n## 验证覆盖检查点：2026-10-04c\n\nF-025～030已核对实际合同、代码、变异/公开刺激和原始日志。F-026四模块共29输入悬空，由真实Icarus+skill AST确认；F-027补A短Verilog语义对照，并读取C新增真实DUT门限变异。F-028/029为原场景短片段，明确不宣称完整系统TB变异PASS计数。共30条，等待刷新汇总表。证据索引evidence/merged_findings_oct4c_refs.json。\n'
r.write_bytes(txt.replace('\n','\r\n').encode('utf-8'))
print('MERGED',list(details),'source_refs',sum(map(len,out.values())),'raw_simulations',len(simrecords),'dangling',sum(len(v['dangling_input_ports']) for v in omitted.values()))
