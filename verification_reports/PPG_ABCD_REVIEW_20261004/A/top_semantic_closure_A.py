from pathlib import Path
import csv,json,re,collections
B=Path(__file__).resolve().parent;S=B/'snapshot';E=B/'evidence';out=E/'closure_skill_20261004'
cfile='contracts/PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md'; top='rtl/ppg_control_top/ppg_control_top.v'; smoke='rtl/ppg_control_top/tb_ppg_control_top.v'; inj='rtl/ppg_control_top/tb_ppg_control_top_injection.v';sid='rtl/ppg_control_top/tb_ppg_control_top_startup_idac_calibration.v'
definitions={}
for n,line in enumerate((S/cfile).read_text(encoding='utf-8').splitlines(),1):
    m=re.match(r'\| (TOP-\d+) \| (.*?) \| (.*?) \|$',line)
    if m:definitions[m[1]]=dict(line=n,scenario=m[2],requirement=m[3])
assert len(definitions)==24
# Exact current source checks, not inferred line offsets or historical aliases.
checks=[
('TOP-01',[(smoke,1143,'ST_CONFIG'),(smoke,1153,'o_s_in'),(smoke,3018,'B_INFLIGHT'),(smoke,3034,'ST_CONFIG')],'复位初值、安全S、真实在途复位及重新产生新结果；71 PASS smoke 已完成','已审'),
('TOP-02',[(smoke,1189,'o_config_epoch'),(smoke,1308,'o_config_epoch')],'联合合法提交及破坏V5保留位负向拒绝；下游ACK连接逐跳审过；F-023 STOP同拍优先级另列','已审'),
('TOP-03',[(smoke,2921,'pair1_red_frame_id'),(smoke,2924,'pair1_ir_sample'),(smoke,2942,'pair1_red_tick')],'两真实双光宏帧的帧号、连续序号、精度及固定Q3相位比较；F-009 宏帧5001拍另列','已审'),
('TOP-04',[(smoke,2132,'reg_last_cal_local_tick'),(smoke,2135,'reg_last_cal_amb_snapshot')],'CAL响应tick允许捕获延迟，不能把260..272响应范围当Q3本身偏移；SSW/Scheduler单位tick0/266比较补证','已审'),
('TOP-05',[(smoke,2281,'i_measurement_result_ready'),(smoke,2312,'cnt_owner_commit_red'),(smoke,2316,'cnt_drop_without_consume')],'输出反压期间owner继续、held valid不撤销；独立波形/事务握手另在OIB与Scheduler单位场景。OIB顺序判据缺陷F-042保留；原OIB完整运行待终态','已审；长回归待终态'),
('TOP-06',[(smoke,2219,'reg_last_precision_scheduler')],'同笔三模块精度对比；FIR-tail GROUP4 真实旧尾部candidate禁止及重新CROSS，原80 PASS已完成','已审'),
('TOP-07',[(smoke,2405,'SMOKE-18'),(smoke,2422,'SMOKE-18'),(smoke,2429,'SMOKE-18')],'固定电流边界逐拍监视并要求真实RED/IR继续响应，不只有静态输出','已审'),
('TOP-08',[(smoke,2521,'o_en_test'),(smoke,2531,'o_s_in'),(smoke,2601,'o_s_in')],'静态向量逐位比较、CDC提交后S更新、真实owner计数不变；CCC原单位26 PASS补跨域提交原子性','已审'),
('TOP-09',[(smoke,1285,'ST_CONFIG'),(smoke,3133,'o_measurement_result_valid'),(smoke,3160,'cnt_top09_discard_event')],'STOP/abort/drain及held正式结果显式discard均有真实比较；F-019身份/F-021资格/F-035完成abort碰撞反例不得被这些PASS掩盖','已审；发现反例'),
('TOP-10',[(top,730,'ppg_active_v4_control_plane_integration')],'Erie AST六个直接子模块及全层次iverilog elaborate；旧双精度/旧SAR timing无可达实例。静态验收无需TB标签；无ASIC综合工具','已审；静态证据'),
('TOP-11',[(sid,889,'cnt_boundary_pulses'),(sid,892,'cnt_owner_commit_total_sid')],'SID01真实计一次边界及首AMB请求前owner/macro/result不推进；原完整SID回归排队，不能写成已重跑PASS','已审；长回归待终态'),
('TOP-12',[(top,411,'measurement_run_enable'),(smoke,2556,'o_scheduler_idle'),(smoke,2566,'cnt_owner_commit_total')],'许可门控、全4000拍idle及owner不变。宏帧/索引无推进由Scheduler static支路和单位场景另核对','已审'),
('TOP-13',[(smoke,1840,'cnt_ir_delta'),(smoke,1843,'cnt_red_delta'),(smoke,1847,'i_dcs_r_code')],'纯RED SAR9按宏帧计一笔、无IR、固定IDAC快照；逐笔owner精度由后台捕获并按配置路径冻结','已审'),
('TOP-14',[(smoke,1933,'SMOKE-13'),(smoke,1945,'cnt_ir_delta'),(smoke,1948,'cnt_red_delta')],'纯RED SAR15全RUN精度及每帧一笔比较；精度事件直接由fixed模式PWC屏蔽分支补静态证据','已审'),
('TOP-15',[(smoke,1031,'o_adc_owner_commit_event'),(smoke,1033,'B_INFLIGHT'),(smoke,3175,'cnt_top15_commit_checked')],'同拍owner不重入且终判要求监视非空；四SAR15控制共享包络在SSW逐拍及smoke后台监视补证','已审'),
('TOP-16',[(smoke,1656,'SMOKE-09'),(smoke,1675,'SMOKE-09')],'真实Q3后悬置DONE3000拍，owner不释放；释放真实CLK_DOUT后必须完成。错误identity在INJ02/AMI单位真实拒绝','已审'),
('TOP-17',[(top,416,'flag_adc_physical_idle'),(smoke,1720,'B_INFLIGHT'),(smoke,1723,'cnt_measurement_result_valid')],'单一网五路同源；扰动物理idle不造completion。芯片只同步一次，CDC signoff不属于现有工具能力','已审；静态及仿真切片'),
('TOP-18',[(top,410,'analog_run_enable'),(top,411,'measurement_run_enable'),(smoke,2559,'measurement_run_enable'),(smoke,2562,'analog_run_enable')],'高有效许可分开扇出；STATIC测量0模拟1；真实错误期望变异触发smoke FAIL','已审'),
('TOP-19',[(top,851,'flag_static_characterization_enable'),(smoke,2656,'o_last_error_code')],'CDC已提交单一源到manager/SSW/许可；非法PHOTODIODE组合提交真实拒绝','已审'),
('TOP-20',[(smoke,2757,'cnt_owner_commit_red'),(smoke,2761,'flag_calibration_leaked'),(smoke,2764,'flag_scheduler_ready_leaked'),(smoke,2825,'o_last_error_code')],'真实固定电流RUN要求有两色事务且源/接收校准门持续禁用；NORMAL SAR15配置先拒绝，不制造不可达非法RUN；F-046 FSC标签语义错位保留','已审'),
('TOP-21',[(inj,687,'INJ-01'),(inj,699,'o_result_sample_valid'),(top,393,'flag_test_inject_mode_latched')],'参数默认0 smoke与编译使能1运行enable0 INJ双切片；未持有历史V1.3.4全波形逐位比较源，不能以一个sample_valid替代逐位等价签核','已审；历史逐位证据未重建'),
('TOP-22',[(inj,797,'INJ-02'),(inj,811,'INJ-02'),(inj,835,'B_INFLIGHT'),(inj,900,'o_result_sample_valid')],'真实错identity保持owner、supervisor阻断、STOP清理和下一合法样本恢复；INJ02“恰好一次/原identity”横幅没有独立完整completion计数，AMI单位cache/单脉冲结构补有限证据，非所有collision覆盖','已审；证据范围有限'),
('TOP-23',[(inj,954,'reg_captured_sample_valid'),(inj,957,'reg_captured_frame_id'),(inj,978,'o_result_sample_valid')],'invalid握手、正式sample_valid0和后续1真实比较；全X判断不能证明身份正确，完整frame变异逃逸F-049；robust直接引用不能补此比较','已审；发现F-049'),
('TOP-24',[(inj,997,'i_test_invalid_sample_valid'),(inj,1000,'INJ-04')],'双请求ready0场景没有命中实际采样eligible窗口，变异已证实F-040；其他安全负向由模块/结构补有限切片，F-044叶子去使能Top RUN不可达仍疑似','已审；发现F-040')]
records=[]
for ident,refs,assessment,status in checks:
    actual=[]
    for file,line,token in refs:
        value=(S/file).read_text(encoding='utf-8').splitlines()[line-1]
        assert token in value,(ident,file,line,token,value)
        actual.append(dict(file=file,line=line,token=token,text=value))
    records.append(dict(id=ident,contract_file=cfile,contract_line=definitions[ident]['line'],requirement=definitions[ident]['requirement'],references=actual,assessment=assessment,status=status))
(out/'top_24_semantic.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
with (out/'top_24_semantic.csv').open('w',encoding='utf-8-sig',newline='') as f:
    writer=csv.DictWriter(f,fieldnames=['id','contract_line','requirement','references','assessment','status']);writer.writeheader()
    for r in records:writer.writerow({k:(';'.join(f"{x['file']}:{x['line']}" for x in r['references']) if k=='references' else r[k]) for k in writer.fieldnames})
report=B/'PPG_FULL_REVIEW_20261002.md';text=report.read_text(encoding='utf-8')
heading='## A 全局追溯检查点：2026-10-04 Top / 参考说明'
if heading not in text:
    text+='\n'+heading+'\n\n'
    text+='使用仓库 erie-verilog-generator 的 analyze-existing 与八门 deliverable gate 只读入口。新的Top AST/分析与JSON均在 evidence/closure_skill_20261004；真实工具链编译/仿真独立记录，不将门禁的 compile 静态解析或 toolchain=not_requested 说成 xsim/ASIC验证。Top 165个端口名称、方向、默认位宽与C01边界台账165行一致（4个signed输出逐声明核对，矩阵未独立声明signed）；先做错误方向/宽度、缺行和重复行负对照。AST六个直接实例与合同一致；旧行号问题仍为F-003，参数化缺陷F-014/F-024和formal discard缺五epochs F-008不被此结论覆盖。门禁只有已接受VG031=1。\n\n'
    text+='TOP01-24逐条源代码语义复核完成；“已审”表示审阅完成而非验收CLOSED。有限切片、真实反例及未结束的SID/OIB长回归如下，各引用文字已逐行校验。完整证据在top_24_semantic.csv/json。\n\n| ID | 当前C01行 | 真正比较/结构证据 | 审阅结论和限制 |\n|---|---:|---|---|\n'
    for r in records:text+=f"| {r['id']} | {r['contract_line']} | "+'; '.join(f"{Path(x['file']).name}:{x['line']}" for x in r['references'])+' | '+r['assessment']+' |\n'
    text+='\n非规范参考裁定：TAPEOUT_FINAL_REVIEW_GUIDE.md全部71行已核对。其本机路径不存在、SMOKE56与现71、CDC/锁存审计日期早于修复，属于用户明确已知；不新增发现、不采用“唯一开放线索/功能正确”作为当前结论。没有Cxx当前版本声明或独立验收定义，版本绑定/验收闭环项属于不适用；矩阵§2:167-171规定其非规范地位，真实流片/STA/AMS限制仍明确保留。\n\n'
    text+='候选联合TB说明全部382行已核对：§2只连接Scheduler/SSW/AMI，明确排除manager/SPI/fault supervisor，不能拿其scope否定Top路径；STATIC许可与当前Top拆分一致，10秒/≥4000帧/每色≥4000真实结果按现行C25和原long_10_cycles判据核对。§11的历史52子检查先于当前C25及JNT54，按候选状态与矩阵§2非规范分类处理，当前回归不用52作门槛；真实门槛失效F-037独立保留。PRC-04零脉搏冲突是已接受事项，候选闭环次序不覆盖C20/C23现行规范。不存在独立Cxx版本绑定，未因非规范候选中尚未实现的场景自动报RTL错误。原10秒回归仍未结束，不宣布候选算法长运行PASS。\n'
report.write_bytes(text.replace('\n','\r\n').encode('utf-8'))
print('TOP24 semantics',len(records),dict(collections.Counter(x['status'] for x in records)))
