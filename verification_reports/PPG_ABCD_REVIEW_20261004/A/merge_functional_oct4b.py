from pathlib import Path
import json,re,hashlib
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence'
GB=B.parent.parent/'01a0fd78-55cb-7173-9e41-1e0b27c41d49/ppg_review_B'
GD=B.parent.parent/'01a0fd78-edf3-7221-9fc4-3dd2391369a9/ppg_review_D'
refs={
 'F-018':[('rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v',438,'assign o_result_ready'),('rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v',555,'flag_valley_accept_event'),('rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v',556,'return_payload_o')],
 'F-019':[('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',1296,'measurement_result_discard_frame_id_o'),('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',1307,'measurement_result_discard_sample_index_o'),('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',1318,'measurement_result_discard_color_ir_o')],
 'F-020':[('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',1798,'flag_calibration_request_inflight'),('rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v',368,'flag_sample_inflight')],
 'F-021':[('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',1238,'flag_measurement_transfer'),('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',1239,'result_sample_valid_o'),('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',2518,'i_sample_valid')],
 'F-022':[('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',1186,'i_start_ack_event'),('rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v',1187,'integration_protocol_error_sticky_o')],
 'F-023':[('rtl/ppg_system_config_manager/ppg_system_config_manager.v',313,'i_stop_event'),('rtl/ppg_system_config_manager/ppg_system_config_manager.v',461,'i_stop_event'),('rtl/ppg_system_config_manager/ppg_system_config_manager.v',462,'ST_RUN')],
 'F-024':[('contracts/ppg_system_config_manager_semantic_contract.md',37,'shall declare'),('contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md',63,'C_CONFIG_WIDTH'),('contracts/ppg_system_active_config_unpack_semantic_contract.md',26,'C_CONFIG_WIDTH')]
}
evidence={};quotes={}
for fid,items in refs.items():
    quotes[fid]=[]
    for rel,n,key in items:
        raw=(S/rel).read_bytes();line=raw.decode('utf-8-sig').splitlines()[n-1]
        assert key in line,(fid,rel,n,key,line)
        quotes[fid].append(line.split('//',1)[0].strip())
        evidence.setdefault(fid,[]).append({'file':rel,'line':n,'text':line,'sha256':hashlib.sha256(raw).hexdigest()})
cases=[(GB,'discard_identity_one'),(GB,'discard_identity_two'),(GB,'recheck_control'),(GB,'recheck_deadline_v4'),(GB,'recheck_deadline_gate_counterfactual'),(GB,'branch_qualification_v2'),(GB,'branch_qualification_counterfactual_v2'),(GB,'ami_sticky_start')]
records=[]
for root,name in cases:
    d=root/'evidence'/name;m=json.loads((d/'result.json').read_text(encoding='utf-8'))
    assert m['compile_rc']==0,(name,m)
    log=(d/'run.log').read_bytes();text=log.decode('utf-8',errors='replace').replace('\x00','')
    records.append({'case':name,'directory':str(d),'metadata':m,'run_log_sha256':hashlib.sha256(log).hexdigest(),'key_output':[l for l in text.splitlines() if re.search(r'^(PASS B|FAIL B|B_(?:PRE|POST|BRANCH|STICKY)|FATAL|PASS AMI)',l)]})
for name in ['stop_only','stop_start','stop_commit','stop_clear']:
    d=GD/'evidence/tb_ppg_system_config_manager';m=json.loads((d/(name+'.result.json')).read_text(encoding='utf-8'));assert m.get('compile_rc',m.get('compileCode'))==0,m
    log=(d/(name+'.run.log')).read_bytes();records.append({'case':name,'directory':str(d),'metadata':m,'run_log_sha256':hashlib.sha256(log).hexdigest(),'key_output':log.decode('utf-8',errors='replace').replace('\x00','')})
for name in ['chip_stop_only','chip_stop_commit']:
    d=GD/'evidence/tb_ppg_chip_digital_top';m=json.loads((d/(name+'.result.json')).read_text(encoding='utf-8'));assert m.get('compile_rc',m.get('compileCode'))==0,m
    log=(d/(name+'.run.log')).read_bytes();records.append({'case':name,'directory':str(d),'metadata':m,'run_log_sha256':hashlib.sha256(log).hexdigest(),'key_output':log.decode('utf-8',errors='replace').replace('\x00','')})
(E/'merged_findings_oct4b_refs.json').write_text(json.dumps({'refs':evidence,'actual_simulations':records},ensure_ascii=False,indent=2),encoding='utf-8')
details={
'F-018':'''### F-018：PVW 返回请求反压期间被第二次合法谷值覆盖 frame_id

- 严重度/层：S1 / RTL。置信度：仿真确认叶子接口错误；未声称常规Top路径必现。关联C-004；原专项把RTL握手错误归S2，按本任务S1定义统一。
- 位置：`rtl/ppg_peak_valley_window_detector/ppg_peak_valley_window_detector.v:438,555,556`，原文3行：
{quote}
- 描述/依据：C22合同§11.3:520-521允许valley与return独立握手，§11.4:538要求return原因/frame在反压期间保持。消费valley但保持return ready=0后，输入ready重新开放；同epoch、连续合法15-bit峰谷可再次确认，555-556无pending保护，覆盖仍valid的旧返回frame。
- A/B证据：A独立执行C组公开输入准备件并核对所有激励、精度/epoch、真实握手及无协议故障前提。`evidence/peak_hold_actual/native.run.log`：`held return changed: expected frame=10 actual=21`，编译0运行1；先真实消费旧return再送相同第二峰谷的`peak_hold_consumed_control`打印`C_RETURN_HOLD_PASS`，编译0运行0；错误初始期望11的负对照在第一请求建立时fatal，运行1。全部依赖只有实际PVW和仓库外TB，输入hash/命令保存在对应native.result.json。
- 反驳：PWI实际绑定PWC的ready（PWC:280在正常ST_FINE立即为1）限制常规系统触发，不能解除叶子合同的独立反压义务。原PVW-30:851-859未消费valley、未继续送输入，不能推翻反例。非TRK-01原子不可测试、discard豁免、已知PWC修复或PRC-04。
- 建议方向：在旧返回请求消费前保护其载荷/所有权，并加入valley先消费、return反压的公开输入对照。
''',
'F-019':'''### F-019：AMI 正式结果 discard 报告了已推进上游的另一笔身份

- 严重度/层：S1 / RTL。置信度：真实链仿真确认；关联B-006。
- 位置：`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1296,1307,1318`，原文3行：
{quote}
- 描述/依据：C10:616-620、661-673要求measurement discard携带该分支保留事务。正式待消费输出来自1742-1749的`reg_result_fork_payload`，但discard六字段取自NORMAL fork的上游`dec_measurement_*`（2022-2041），该上游可先到下一笔。
- 证据：B组仓库外`discard_identity_one`单笔真实ADC/S1/DC链3 PASS；相同启动与链路的`discard_identity_two`保持正式RED 90/900，再接收IR 91/901。原始日志：`B_PRE_DISCARD resultframe=90 resultsample=900 upstreamframe=91 upstreamsample=901`；abort后`B_POST_DISCARD event=1 frame=91 sample=901 color=1`，`FAIL BIDISC`，编译0运行1。A已读实际公开刺激、完整身份来源和原始日志/命令。Top:1190-1192/1576-1578直通错误身份。
- 反驳：没有force，注入参数默认关闭；正常正式结果仍90/900，排除只是期望把trigger当保留事务的误解。合同明确每分支身份，不允许任意上游trigger。本条为真实可见错身份，区别F-002/F-008五epoch文档缺口；C11/C14/C15条件豁免不能覆盖公开measurement-discard。没有据此声称永久排空失败。
- 建议方向：discard取当前正式measurement保留载荷的身份，增加两笔背压后取消的比较。
''',
'F-020':'''### F-020：周期 AMB 截止只清 AMI 外层 inflight，内层锁住后续 RUN 重试

- 严重度/层：S1 / RTL·跨层。置信度：AMI及全部实际子模块仿真确认；全Top拒绝owner的专项尚待补。关联B-007。
- 位置：AMI `rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1798` 与 `rtl/ppg_amb_recheck_scheduler/ppg_amb_recheck_scheduler.v:368`，原文2行：
{quote}
- 描述/依据：C10:486/996规定未取得owner的截止不会有结果返回，应重新发同一候选。AMI:929把中间缓存ready经PWI:1015送给AMB；AMB:195/360-369在缓存握手时先置本地inflight，208据此禁止valid。截止1797-1798仅清外层；没有deadline送到AMB，内层只在实际结果accepted、阶段结束或生命周期取消时清，未建立owner则没有结果可解锁。
- 证据：B `recheck_deadline_v4`经真实启动、FIR/cross/精度返回到periodic reason01，公开请求握手后outer=1/inner=1/adc=0；合法deadline及100次安全边界后，`B_POST_DEADLINE outer=0 inner=1 adc=0 req=0 busy=1 physidle=1 chainidle=1 fault=0 ownerdelta=0`，`FAIL BRETRY`、`PASS BCLEAR`，编译0运行1。正常真实三阶段结果链`recheck_control`30 PASS；只删除内层valid的inflight门控之仓库外因果对照31 PASS，req恢复；不是候选修复。A已核对实际代码、公开刺激、两层握手、原始日志和命令。
- 反驳：RUN撤销后确实恢复，故不称复位后永久死锁；物理/数据链idle且ownerdelta=0排除等待合法ADC返回。Top把Scheduler deadline直送AMI，没有内层补偿；外层SID-05修复只能帮助startup单层源，不能替periodic内层清理。与已知tick248同拍commit不同，此复现完全无owner commit。全Top在SSW拒绝或候选来晚时的实际截止触发仍待补，不能称已端到端复现。
- 建议方向：未建立owner的截止释放要贯穿周期重检所有权，并保留重复请求保护。
''',
'F-021':'''### F-021：measurement 先消费清共享 sample-valid，仍 pending 的 detection 资格变零

- 严重度/层：S1 / RTL。置信度：真实链仿真及因果对照确认；关联B-008。
- 位置：`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1238,1239,2518`，原文3行：
{quote}
- 描述/依据：C10:691-694、941-946明确两分支分别保存资格，任一消费不能修改另一pending分支。现有唯一资格寄存器同时驱动measurement:1028与PWI detection:2518；measurement完成时清零，detection仍pending也看见0，稍后会作为invalid样本被消耗。
- 证据：B `branch_qualification_v2`保留原AMI TB至N08的真实链及FIR忙窗口，原47比较通过后：`B_BRANCH_DIAG window=1 firbusy=1 detpending=1 measpending=0 samplequal=0 frame=1131 expected=1131`；`PASS BWINDO`、`FAIL BQUALI`，编译0运行1。同激励仅在仓库外让measurement清零还要求detection不pending，samplequal=1且49比较/0失败。A读实际变异单行、公开激励、原日志及代码来源；第一版观察早一拍的失败属于setup，未采用。
- 反驳：没有force、注入关闭、payload仍保持，排除F-001悬空注入及P2S三个遥测错拍已知项。消费measurement期间detection ready低为原N08已有合法背压；不能用一条branch的原子数值载荷代替另一条独立资格。常规400 Hz每帧是否一定命中该窗口未证明，不扩大为所有默认帧丢失。
- 建议方向：分支独立保存资格，并比较measurement先消费及detection先消费两种次序。
''',
'F-022':'''### F-022：AMI 新合法 START 清除了软件尚未清除的历史 protocol sticky

- 严重度/层：S1 / RTL。置信度：仿真确认；关联B-009。
- 位置：`rtl/ppg_adc_measurement_idac_integration/ppg_adc_measurement_idac_integration.v:1186-1187`，原文2行：
{quote}
- 描述/依据：C10 §15.1:1153只允许reset，或本地无活动blocking cause时的diag_clear清历史；START/STOP明确不得清。实际把START与diag_clear并列清零。
- 证据：B `ami_sticky_start`通过MANUAL真实启动建立上下文，非法保留frame11置sticky；`PASS BSTICK`证明sticky=1、blocking=0、无ADC inflight，STOP/撤RUN/drain后`PASS BDRAIN`证明empty及历史仍1。新generation2合法START后`B_STICKY_AFTER_START sticky=0 blocking=0 inflight=0`，`FAIL BKEEPH`；显式diag_clear的`PASS BDIAGC`对照通过。编译0运行1，3 PASS/1 FAIL。A核对实际刺激、合同、清零代码和原始日志。
- 反驳：新START前已排空，没有保留旧owner或故障blocking阻止START；Top允许从正常排空后的新RUN清上下文，未自动发diag_clear。用户已知09-17 PWC保留sticky修复是另一个模块，不能豁免AMI同名历史状态。
- 建议方向：START仅重建RUN上下文，历史sticky保留至其明文清除条件；加跨RUN比较。
''',
'F-023':'''### F-023：STOP 与竞争命令同拍被 manager 吞掉，真实 SPI 仍保持 RUN

- 严重度/层：S1 / RTL。置信度：叶子及真实SPI pad仿真确认；关联D-003。
- 位置：`rtl/ppg_system_config_manager/ppg_system_config_manager.v:313,461,462`，原文3行：
{quote}
- 描述/依据：C02当前V4.9:65、228-236及MGR-11要求Top-merged STOP抢占START/COMMIT/status-clear，保留冲突诊断。实际任意冲突把stop_accept也清零，RUN许可继续为1，没有排空episode。
- 证据：D仓库外manager真实COMMIT/START进入RUN。单STOP日志`state=11 run=0 allow=0 ack=1 episode=1`、PASS；分别同START/COMMIT/clear则`state=10 run=1 allow=1 ack=0 episode=0 error=1 code=01`，各fatal、编译0运行1。真实chip SPI写0x0090命令：0x02对照`state=00 stop_hits=1 collisions=0 code=00` PASS；0x06(STOP+COMMIT)出现`D_CHIP_STOP_COMMIT_COLLISION`后`state=10 stop_hits=0 collisions=1 code=01`、`D_CHIP_STOP_FAIL`，编译0运行1。A已读公开pad刺激、actual commands/日志、RTL优先条件。
- 反驳：wrapper:397-399直通，Top:375/737-739只注册合并STOP、不屏蔽竞争命令；SPI命令位允许同时设置，真实pad对照消除了仅叶子非可达假设。没有其他机制补发丢STOP；fault blocking只拒START不自动退出RUN。原MGR TB在READY测试旧全拒绝不能反驳RUN丢终止请求。无已知事项豁免，当前规范明确STOP优先；不采用旧互斥说明盖过当前规范。
- 建议方向：保持冲突诊断同时落实STOP优先，补RUN/STOPPING的同拍命令矩阵。
''',
'F-024':'''### F-024：manager、ACTIVE wrapper、unpack 缺当前合同要求的正式参数及透传

- 严重度/层：S3 / 合同·跨层。置信度：静态确认；关联D-002，不指控默认产品宽度错误。
- 位置：`contracts/ppg_system_config_manager_semantic_contract.md:37`、`contracts/PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md:63`、`contracts/ppg_system_active_config_unpack_semantic_contract.md:26`，原文3行：
{quote}
- 描述/依据：C02:43-50要求8正式参数，实际manager:54-58只有CONFIG_WIDTH与RUN_GENERATION_WIDTH，余6项不声明、epoch端口固定8bit；C03:63-65要求3参数，wrapper:49-50无参数表，generation固定8bit，379只显式传常数1024给bridge，392/429调用manager/unpack无参数传递；C05:26要求CONFIG_WIDTH，unpack:47-50无参数表、输入固定1024bit。C02:52-55所述Top一路透传每个参数及拒绝不匹配路径不存在。
- 证据/反驳：完整实际模块参数声明与实例、仓库skill canonical AST均核对；AST的parameter_count可包含localparam，未把计数当正式接口。默认1024/8产品连接一致，未把非法/非默认宽度问题升级为默认功能S1；当前V4.9/V1.6正式页眉没有缺参数豁免，旧历史冻结不能替代。不是已接受VG风格问题或chip层没有验收ID的问题。无需行为仿真，事实是正式接口缺失。
- 建议方向：设计owner统一实际允许的参数、透传及拒绝检查，或明确冻结产品固定值。
'''
}
r=B/'PPG_FULL_REVIEW_20261002.md';txt=r.read_text(encoding='utf-8')
for fid,detail in details.items():
    if '### '+fid in txt:continue
    q='```text\n'+'\n'.join(quotes[fid])+'\n```'
    body=detail.replace('{quote}',q)
    target='### F-001' if fid!='F-024' else '## 4. 已知事项'
    pos=txt.index(target);txt=txt[:pos]+body+'\n'+txt[pos:]
txt+='\n## 功能专项检查点：2026-10-04b\n\n新增F-018～024均已由A重新定位实际源行并跨文件反驳。F-018补跑公开端口A/B及错误期望；B/D六项复用其真实短仿真，A读取公开刺激、实际RTL/合同/生产者消费者与原始日志，不凭专项摘要计数。证据索引evidence/merged_findings_oct4b_refs.json。相关完整系统场景、default频率触发和全Top截止仍按各条限定，不把叶子反例自动升级为所有芯片运行必现。共24条待刷新总表；所有源文件仍只读。\n'
r.write_bytes(txt.replace('\n','\r\n').encode('utf-8'))
print('MERGED',list(details),'refchecks',sum(map(len,evidence.values())),'raw_simulations',len(records))
