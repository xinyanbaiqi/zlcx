"""Manual per-ID verdicts from reading TB check code against contract rows (snapshot 2a90a69).
Keys are (family, number). Value: (class, note). Families not listed fall back to FAMILY_DEFAULT."""

CMAP = {
    'PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md': 'C01',
    'ppg_system_config_manager_semantic_contract.md': 'C02',
    'PPG_ACTIVE_V4_CONTROL_PLANE_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': 'C03',
    'PPG_ACTIVE_V4_CONTROL_CONNECTION_MAPPING_CONTRACT.md': 'C04',
    'ppg_system_active_config_unpack_semantic_contract.md': 'C05',
    'PPG_CHARACTERIZATION_INPUT_SOURCE_AND_STATIC_BIAS_CONTROL_CONTRACT.md': 'C06',
    'PPG_CHARACTERIZATION_CONTROL_CDC_INTERFACE_CONTRACT.md': 'C07',
    'PPG_400HZ_FRAME_CALIBRATION_SCHEDULER_INTERFACE_CONTRACT.md': 'C08',
    'PPG_SAR9_SAR15_SAFE_SELECTION_WRAPPER_INTERFACE_CONTRACT.md': 'C09',
    'PPG_ADC_MEASUREMENT_AND_IDAC_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': 'C10',
    'PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md': 'C11',
    'PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md': 'C12',
    'PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md': 'C13',
    'PPG_ADC_PROGRAMMABLE_RECONSTRUCTOR_INTERFACE_CONTRACT.md': 'C14',
    'PPG_ADC_DC_RECOVERY_INTERFACE_CONTRACT.md': 'C15',
    'PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md': 'C16',
    'PPG_IDAC_CODE_CONTROLLER_V2_INTERFACE_CONTRACT.md': 'C17',
    'PPG_PRECISION_WINDOW_INTEGRATION_WRAPPER_INTERFACE_CONTRACT.md': 'C18',
    'PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md': 'C19',
    'PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md': 'C20',
    'PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md': 'C21',
    'PPG_PEAK_VALLEY_WINDOW_DETECTOR_INTERFACE_CONTRACT.md': 'C22',
    'PPG_PRECISION_WINDOW_CONTROLLER_INTERFACE_CONTRACT.md': 'C23',
    'PPG_SYSTEM_FAULT_ABORT_SUPERVISOR_INTERFACE_CONTRACT.md': 'C24',
    'PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md': 'C25',
    'PPG_SCHEDULER_SSW_AMI_PORT_CONNECTION_CHECKLIST.md': '核对表',
    'PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md': '芯片顶层',
}

# default verdict when a contract row and a same-number TB label both exist
FAMILY_DEFAULT = {
    'AMI': ('A', ''), 'SSW': ('A', ''), 'CCC': ('A', 'TB打印为`CCC-n`不补零'), 'MGR': ('A', '仅FAIL分支带编号，PASS只有总横幅'),
    'DCR': ('A', '仅FAIL分支带编号，PASS只有总横幅'), 'PR': ('A', '仅FAIL分支带编号，PASS只有总横幅'),
    'RTR': ('A', '编号只在代码注释里，日志只有总横幅'), 'CAL': ('A', '仅FAIL分支带编号，PASS只有总横幅'),
    'FFK': ('A', ''), 'IDT': ('A', 'C16的IDT条目由IDAC控制器单元TB承担'), 'AMR': ('A', ''), 'AV4C': ('A', ''),
    'UNPACK': ('A', '仅FAIL分支带编号'), 'PWC': ('A', ''), 'PWI': ('A', ''), 'PVW': ('A', ''), 'FIR': ('A', ''),
    'BSL': ('A', ''), 'OPT': ('A', ''), 'TOP': ('A', ''), 'SID': ('A', ''), 'LFA': ('A', ''), 'OIB': ('A', ''),
    'PRC': ('A', ''), 'ILM': ('A', ''), 'RRC': ('A', ''), 'NRE': ('A', ''), 'TRK': ('A', ''),
    'ADCN': ('A', 'TB打印为`ADCN-n`不补零'), 'ISE': ('A', ''), 'RAW': ('A', ''), 'SUP': ('A', ''),
    'FSC': ('B', ''),
}

# ---------- FSC: TB check n meaning (read from check_fsc(n, cond) and the stimulus before it) ----------
FSC_TB = {
    1: '复位后无在途、frame/sample为0、无协议sticky',
    2: 'START后恰1个启动IDAC边界', 3: 'START后首帧前无帧起点/序号/在途',
    4: '首个宏帧在macro tick 0开始', 5: '首个波形fire在tick 0且为RED', 6: '首个owner在tick 1、RED、sample 0',
    7: 'owner快照类型NORMAL及AMB/DC码', 8: 'owner快照AMB/DC epoch', 9: '第2个波形fire在tick 160且为IR',
    10: 'IR owner在tick 161、sample 1', 11: '两色同frame 0、IR DC码', 12: '波形LEDDAC快照=0x29',
    13: 'tick 4760有IDAC边界且启动边界仍为1', 14: '宏帧周期5000（容许5001）', 15: '双光完成事件1次、下一序号2',
    16: 'RED-only：owner RED、1次波形、LEDDAC 0x17', 17: 'RED-only：tick 200前仅1次owner',
    18: 'IR-only：tick 160波形/161 owner', 19: 'safe-off：tick 300前无owner/波形', 20: 'SAR15：owner与波形精度位为1',
    21: 'SAR15：owner tick 161/波形tick 160', 22: 'switch_hold：无帧起点/owner/波形', 23: 'AMB_CAL：owner类型AMB、SAR9、颜色0',
    24: 'AMB_CAL：波形local tick 0、owner local tick 1、DC码0', 25: 'tick 625处校准local tick 0、子帧1',
    26: 'DCS_CAL RED owner', 27: 'DCS_CAL IR owner', 28: '波形上下文未ready→launch超时sticky、无owner',
    29: 'owner未ready→tick 284 RED截止超时sticky', 30: 'IR-only owner未ready→tick 444超时sticky',
    31: '校准owner未ready→tick 260超时sticky', 32: '错误sample index DONE→mismatch sticky且仍在途',
    33: '匹配success=0 DONE释放在途', 34: 'success=0不计NORMAL完成', 35: 'STOP后DONE释放且无NORMAL完成',
    36: '`!idle || owner==1`（弱断言）', 37: 'start_ready=0时abort→不消费序号、无在途', 38: 'AMI故障阻断START后的边界/帧',
    39: 'SSW故障阻断START后的边界/帧', 40: '帧内改LED码不影响当前波形快照', 41: '第2个owner sample 1、共2次提交',
    42: 'start_fire与owner commit同拍、序号1', 43: '`!inflight || owner==1`（弱断言）', 44: 'run_enable掉底：无新owner、宏帧自然收尾',
    45: '诊断清除清协议/mismatch sticky', 46: '复位清在途/序号/launch sticky', 47: '故障解除后可重新START',
    48: '校准tick 385前产生校准IDAC边界', 49: '校准owner frame 0/sample 0', 50: '双光2波形2 owner且≥1 DONE',
    51: 'owner与波形同frame、sample 1', 52: 'tick 300前启动边界1次、宏帧边界0次', 53: 'abort后可重新START',
    54: 'stop_ack保持时START无边界/帧', 55: 'tick 4999处safe_frame_id=current+1', 56: 'RED owner类型NORMAL、SAR9',
    57: '双光后无本地故障/协议sticky（总体健康检查）',
    58: 'CHARACTERIZATION run_profile的合法payload请求不被接受、置协议sticky',
    59: 'EXTERNAL_TEST_CURRENT input_source的请求不被接受、置协议sticky',
    60: 'owner恰在local tick 248提交=按时、无截止事件', 61: 'owner在tick 247提交、无截止事件',
    62: '过tick 248未提交→截止事件1拍落在248、不与提交同拍',
}
# contract FSC-n -> TB checks that actually test its meaning
FSC_COVER = {
    1: [1, 46], 2: [6], 3: [14], 4: [5, 9, 50], 5: [10, 11, 51], 6: [16, 17], 7: [18], 8: [19], 9: [5, 9, 56],
    10: [20, 21], 11: [20], 12: [22], 13: [23, 24], 14: [26], 15: [27], 16: [25], 17: [49, 58, 59], 22: [15],
    25: [41], 26: [55], 28: [7, 40], 29: [28], 30: [32], 31: [35, 36], 32: [37, 53], 33: [45], 36: [42], 37: [29],
    38: [13, 52], 39: [48], 40: [13], 41: [38, 44, 54], 42: [25], 45: [24], 46: [6, 29], 49: [30],
    50: [31, 60, 61, 62], 51: [42], 52: [10, 41, 49], 54: [33, 34], 55: [2, 3], 56: [38, 39, 47],
}

DEC = {}
for n in range(1, 63):
    tb = FSC_TB[n]
    cov = FSC_COVER.get(n)
    cov_txt = ('合同FSC-%02d的同义检查在TB的%s' % (n, '、'.join('FSC-%d' % c for c in cov))) if cov else \
        ('合同FSC-%02d在调度器单元TB中无同义检查（系统级证据未核，FSC不在别名表与核对脚本范围）' % n)
    if n == 1:
        DEC[('FSC', n)] = ('C', 'TB：%s；缺完成事件与其他sticky清零' % tb)
    elif n <= 57:
        DEC[('FSC', n)] = ('B', 'TB FSC-%d实测：%s；%s' % (n, tb, cov_txt))
    else:
        DEC[('FSC', n)] = ('D', 'TB FSC-%d：%s（语义属合同%s）' % (n, tb, 'FSC-17' if n < 60 else 'FSC-50 V1.12补充'))

DEC.update({
    # ---------- SUP (C24 §7) ----------
    ('SUP', 0): ('F', 'SUPRST：复位安全默认值，TB本地编号'),
    ('SUP', 1): ('A', 'SUP01A/01B：首个AMI故障原子快照+三事件各一拍、下一拍不重发'),
    ('SUP', 2): ('A', 'SUP02A（后到记录只置汇总位）+SUP02B（同拍固定优先级）'),
    ('SUP', 3): ('B', 'SUP03A实测"episode开启期间诊断清除无效"（属合同SUP-07前半）；合同SUP-03"新故障胜过同拍清除"无同义检查'),
    ('SUP', 4): ('A', 'SUP04A/04B：丢弃只改丢弃sticky，清除后归零'),
    ('SUP', 5): ('E', '合同SUP-05（外部/系统STOP合并幂等）在supervisor单元TB无标签；矩阵P03称由LFA-11a覆盖abort合并半句，STOP合并幂等未见专门检查'),
    ('SUP', 6): ('C', 'SUP06B（阈值处超时）/SUP06C（idle后恢复）覆盖看门狗边界；"不伪造完成"未直接断言；SUP06A实测episode关闭后阻断解除，不是看门狗（同号不同义的子标签）'),
    ('SUP', 7): ('C', 'SUP07A只测"合法清除去历史"；"清除不能释放活动原因"在SUP03A名下'),
    ('SUP', 8): ('E', '合同SUP-08要求最终Top证明，supervisor单元TB不覆盖；Top级证据见LFA-02b/10a/11'),
    ('SUP', 9): ('B', 'SUP09A实测"看门狗阈值前idle不超时"（属合同SUP-06）；合同SUP-09"阻断故障发一次fault-discard、外部abort不发"仅前半由SUP01A/01B间接覆盖'),
    ('SUP', 10): ('B', 'SUP10A实测"第二个独立episode完整trio+新快照"（K02/N06）；合同SUP-10"AMI本地保留fault-discard原因"在C10 AMI-53，不在本TB'),
    # ---------- AMI (C10 §17) ----------
    ('AMI', 1): ('C', '只查复位期间无结果/校准valid、无fire；未查pending/inflight/fork所有权'),
    ('AMI', 2): ('C', '只查一次start产生一次fire；未查capture/S1同拍接受'),
    ('AMI', 3): ('C', '查资格缺失时ready=0、无fire；"恢复后只启动一次"未查'),
    ('AMI', 4): ('C', '查9-bit结果coarse有效、fine无效；未逐级查元数据'),
    ('AMI', 5): ('C', '查15-bit结果精度=1、颜色IR'),
    ('AMI', 6): ('C', '只查NORMAL进入正式结果；AMB/DCS分支未在此标签下查'),
    ('AMI', 8): ('C', '查两分支传输计数相等>0；独立反压未构造'),
    ('AMI', 9): ('C', '只查9-bit无programmable valid'),
    ('AMI', 10): ('C', '只查9-bit精度位=0（coarse/fine在AMI-04）'),
    ('AMI', 11): ('C', '查15-bit coarse/fine/programmable有效及Stage2 epoch'),
    ('AMI', 12): ('C', '只查反压下结果保持；双fork两种先后顺序未构造'),
    ('AMI', 13): ('待定', 'TB实测反压5拍后同一结果仍保持（无新事务装入）；合同要求"同拍替换、无空泡和覆盖"。是部分覆盖还是同号不同义，需看是否有别处构造同拍替换'),
    ('AMI', 14): ('C', '只查启动搜索完成且AMB码在范围内；握手次数与SID-05重握手不在此标签（见AMI-SID05-1/2）'),
    ('AMI', 15): ('C', '只查DC码在范围内'),
    ('AMI', 16): ('C', '查有调码且正式结果继续交付'),
    ('AMI', 17): ('C', '查3次重检请求、accept、busy清除；逐阶段匹配未单独查'),
    ('AMI', 19): ('C', '查切到15-bit且FIR历史满；旧事务精度未单独查'),
    ('AMI', 20): ('C', '查安全边界前不accept'),
    ('AMI', 21): ('C', '只查STOP后ready=0；排空在AMI-40'),
    ('AMI', 23): ('C', '查结果epoch等于配置快照；未在事务途中改配置（AMI-34做了输入改写）'),
    ('AMI', 24): ('C', '`!o_wrapper_fault_blocking || !o_transaction_start_ready`，此时无阻断故障时恒真（可能空真）'),
    ('AMI', 29): ('C', '只覆盖STOP期间；abort/阻断故障期间未查'),
    ('AMI', 31): ('C', '模块级只能查完成脉冲不重复；Top双消费者连接不在本TB'),
    ('AMI', 33): ('C', '查宏帧边界不fire/不完成；"无兼容别名"为静态条款'),
    ('AMI', 36): ('C', '查启动边界无fire/无宏帧路由/无完成'),
    ('AMI', 37): ('C', '查8拍内无完成；Q3/包络末沿等替代完成未逐一构造'),
    ('AMI', 38): ('C', '逐字段比较身份；内部失败success=0路径不在此标签'),
    ('AMI', 42): ('C', '查切换后pending与epoch保持'),
    ('AMI', 46): ('E', '单元TB旧AMI-46已改名AMI-DISC-1（2bb6b17）；C10第30行自述AMI-46至AMI-55为EVIDENCE_PENDING；顶层注入默认关闭证据见TOP-21/INJ-01'),
    ('AMI', 47): ('E', '同上；identity请求绑定的顶层证据见INJ-02/TOP-22。矩阵947/3724/3731/3736、别名表545仍以"AMI-47"指旧TB discard检查（历史叙述，用户决定不改）'),
    ('AMI', 48): ('E', '单元TB旧AMI-48已改名AMI-SID05-1；matcher拒绝的顶层证据见LFA-08/INJ-02'),
    ('AMI', 49): ('E', '单元TB旧AMI-49已改名AMI-SID05-2；identity恢复的顶层证据见INJ-02/LFA-04'),
    ('AMI', 50): ('E', 'invalid请求绑定：顶层证据见INJ-03/PRC-08/TOP-23'),
    ('AMI', 51): ('E', 'invalid正式sideband：顶层证据见INJ-03'),
    ('AMI', 52): ('E', 'invalid检测隔离：顶层证据见PRC-09/10'),
    ('AMI', 53): ('E', '延迟fault-discard原因：顶层证据见LFA-02b'),
    ('AMI', 54): ('E', '别名表89行与矩阵3603/3627/3656：随Acceptance-D01-01（D01-01b）一起登记'),
    # ---------- DCR (C15 §15) ----------
    ('DCR', 3): ('B', 'TB drive_and_check(3,…)实测9-bit且DC码0时DC项为0（属合同DCR-04）；合同DCR-03"9-bit正负边界"无同义检查'),
    ('DCR', 4): ('B', 'TB DCR-4实测15-bit双结果+K_DC15通路（DC码3）（属合同DCR-07/11）；合同DCR-04由TB DCR-3覆盖'),
    ('DCR', 5): ('B', 'TB DCR-5实测CHARACTERIZATION下恢复系数无效时资格为0（属合同DCR-12）；合同DCR-05"K_DC9每增1"仅由TB DCR-2的单点（DC码2）间接覆盖'),
    ('DCR', 6): ('B', 'TB DCR-6实测24-bit正端饱和（属合同DCR-09）；合同DCR-06"15-bit DC码0"无同义检查'),
    ('DCR', 7): ('B', 'TB DCR-7实测24-bit负端饱和（属合同DCR-09）；合同DCR-07由TB DCR-4部分覆盖'),
    ('DCR', 9): ('A', 'FAIL标签DCR-09；用force内部舍入网覆盖端点'),
    ('DCR', 11): ('E', '无同名标签；内容由TB DCR-4（15-bit双结果）覆盖'),
    ('DCR', 13): ('E', '无同名标签；"模块不伪造校准资格"由TB DCR-5覆盖，"系统不允许正式启动"属系统级'),
    ('DCR', 15): ('A', 'FAIL标签"DCR-15/17 backpressure hold"'),
    ('DCR', 17): ('E', '只出现在组合标签"DCR-15/17"中：反压期间改增益/epoch后保持'),
    # ---------- SSW (C09 §10) ----------
    ('SSW', 11): ('C', '查每个子帧Q3在local tick 266、AMB_CAL不驱动Q2；local tick由TB直接驱动，625周期间隔未实测'),
    ('SSW', 18): ('B', 'TB SSW-18实测"校准owner缺失在tick 249前超时"（属合同SSW-37/38）；合同SSW-18"tick 385前未准备下一码终止burst"无同义检查'),
    ('SSW', 24): ('C', '只测一种光学模式；RED_ONLY/IR_ONLY/OFF未逐一构造'),
    ('SSW', 29): ('C', '同SSW-24，只测一种模式'),
    # ---------- others ----------
    ('CCC', 12): ('C', '只查一组相位下的结果与计数，"不同相位"未见循环'),
    ('MGR', 12): ('C', 'TB覆盖0x03/0x04/0x06/0x08/0x09/0x0e/0x0f；合同列出的0x05未测（TB注释称原IDAC枚举场景已按V4.9改判0x15，即MGR-20）。0x05是否仍可达待定'),
    ('MGR', 21): ('E', '无标签；合同第385行要求在三模块联合TB验证；总横幅"MGR-01 through MGR-24"含此项'),
    ('MGR', 23): ('E', '无同名标签；OFF返回0x16由TB的"MGR-18 fixed current optical off rejection"检查（合同MGR-18也列0x16，两条目重叠）'),
    ('PR', 13): ('E', '只出现在组合标签"PR-09/13"中'),
    ('AV4C', 1): ('A', '标签文字仍写"640-bit atomic CDC"，比较的是当前1024-bit ACTIVE'),
    ('AV4C', 3): ('C', '与AV4C-02共用同一组比较后打印PASS'),
    ('AV4C', 15): ('C', '与AV4C-02共用同一组比较后打印PASS'),
    ('AV4C', 17): ('C', '与AV4C-02共用同一组比较后打印PASS'),
    ('AMR', 8): ('E', '无同名标签；受限二分重搜索由IDAC控制器TB的PERIODIC描述行覆盖（无编号）'),
    ('AMR', 9): ('E', '同AMR-08'),
    ('AMR', 13): ('E', '无同名标签；"AMB_CHECK事务进PPG链必须判失败"未见专门检查'),
    ('PWI', 6): ('E', 'PWI单元TB只有PWI-01~05；C18第659行却写"xsim中PWI-01至PWI-07全部真实比较PASS"（合同自述超出TB）'),
    ('PWI', 7): ('E', '同PWI-06'),
    ('PWI', 8): ('E', '别名表89行：随Acceptance-D01-01登记'),
    ('BSL', 40): ('E', '别名表89行：随Acceptance-D01-01登记'),
    ('LFA', 8): ('E', '无同名PASS；证据在注入TB的INJ-02名下（别名表TOP-22=LFA-08）'),
    ('LFA', 10): ('C', 'LFA-10a覆盖AMI侧；LFA-10b打印SKIP（SSW侧该构造路径结构性不可达）'),
    ('LFA', 11): ('C', 'LFA-11b覆盖"合法恢复后清除生效"；LFA-11a实测"supervisor自动abort释放owner期间无虚假正式结果"（属合同§9.5.1规则5/P03，同号不同义的子标签，且两个分支都打印PASS）；"活动故障在清除后继续阻断"未断言'),
    ('PRC', 5): ('C', 'PASS行是无条件$display引用RGC-06证据，本TB不做比较'),
    ('PRC', 8): ('C', 'PASS行是无条件$display引用INJ-03证据，本TB不做比较'),
    ('ISE', 6): ('C', 'PASS行自注"只覆盖STATIC_BIAS子句，AMB_CAL/DCS_CAL子句另组"'),
    ('ISE', 2): ('E', '无独立PASS，出现在组合PASS行"ISE-01/02/03"中（别名表282行）'),
    ('ISE', 7): ('E', '无同名标签；别名表277/287行指向ISE-04/05的非对称码型检查'),
    ('ADCN', 4): ('E', '无独立PASS；别名表267/269行：隐含在ADCN-1/2/3行的"SAR9 fine_valid unexpectedly asserted"未触发'),
    ('ADCN', 7): ('E', '无独立PASS；别名表260/270/271行'),
    ('ADCN', 9): ('E', '无独立PASS；别名表272行指向阶段C饱和边界'),
    ('OIB', 4): ('E', '别名表165/172-175行：结构性满足、无独立PASS'),
    ('OIB', 10): ('E', '别名表165/172-173行：静态分析+结构性满足'),
    ('SID', 3): ('A', '仅FAIL分支带编号'), ('SID', 7): ('A', '仅FAIL分支带编号'), ('ILM', 9): ('A', '仅FAIL分支带编号（别名表记为半覆盖）'),
})
for n in (8, 10, 11, 12, 17, 19, 21, 22, 23, 24):
    DEC.setdefault(('TOP', n), ('E', ''))
DEC[('TOP', 8)] = ('E', '别名表35/255行：SMOKE-19(?)，C01第942行映射')
DEC[('TOP', 10)] = ('E', '别名表37行：综合层次静态检查，非仿真')
DEC[('TOP', 11)] = ('E', '别名表38行：SID-01')
DEC[('TOP', 12)] = ('E', '别名表39行：SMOKE-12(?)')
DEC[('TOP', 17)] = ('E', '别名表：tb_ppg_control_top.v扇出监测器（无编号）')
DEC[('TOP', 19)] = ('E', '别名表44行：SMOKE-21/22(?)')
DEC[('TOP', 21)] = ('E', '别名表46行：INJ-01')
DEC[('TOP', 22)] = ('E', '别名表47行：INJ-02（=LFA-08）')
DEC[('TOP', 23)] = ('E', '别名表48行：INJ-03（=PRC-08）')
DEC[('TOP', 24)] = ('E', '别名表49行：INJ-04')
for n in range(1, 12):
    DEC[('RAW', n)] = ('E', '无RAW标签；生成器性质由tb_ppg_real_raw_generator_selfcheck.v的RGC-01~15覆盖（RGC与RAW无登记对照）')

# contract-only families: one shared note each
CONTRACT_ONLY = {
    'AV4': ('E', 'C04联合映射验收项，无TB标签；内容由AV4C/TOP系列间接覆盖'),
    'CIS': ('E', 'C06验收项，无TB标签；内容分散在MGR/SSW/ILM/CCC'),
    'IDC2': ('E', 'C17验收项，无TB编号；IDAC控制器TB用无编号描述行（RESET/STARTUP/PERIODIC）和C16的IDT标签'),
    'CF4': ('E', 'C16第15.4节ACTIVE V4字段检查，无TB标签；内容属MGR/AV4C'),
    'PC': ('N/A', '核对表第13节"RTL编写前最终检查清单"条目编号，不是验收ID'),
}
# TB-only families
TB_ONLY = {
    'AMI-DISC': ('F', 'TB本地：C10第6.10节公开discard端口检查（原AMI-46/47）'),
    'AMI-SID05': ('F', 'TB本地：SID-05截止事件单元断言（原AMI-48/49），带@satisfies: SID-05'),
    'N08': ('F', 'TB本地：矩阵N08交接前半检查'),
    'OVL': ('D', 'C13第7节验收用例是无编号列表；TB的OVL-01~17来自合同外"交付文件"，横幅称OVL-01..OVL-17'),
    'OPTC': ('D', 'C21只定义OPT-01~24；OPTC-01/02（共享乘法器）未登记'),
    'JNT': ('D', '联合TB说明只引用"JNT-01～09（52个子检查）"，无定义表；子编号JNT-02A等与JNT-STARTUP-READY等只在TB'),
    'RGC': ('F', 'TB本地：真实RAW生成器自检，语义对应C25 RAW-01~11但无对照登记'),
    'SMOKE': ('F', 'TB本地：顶层冒烟场景；C01第942行用它作TOP证据'),
    'NPA': ('F', 'TB本地：Priority-1a NPA端口检查'),
    'INJ': ('F', 'TB本地：注入场景；C01第946行与别名表用它作TOP-21~24/LFA-08/PRC-08证据'),
    'D01': ('F', 'TB本地：矩阵Acceptance-D01-01a/b子检查'),
    'TC': ('F', '芯片顶层TB本地；芯片顶层合同无验收ID族，TC6/TC7被合同正文引用'),
}
