# ADC后半链审阅（2026-10-04）

被审提交 d18c6954621e53e5a6505dd3a6c688c266d23839。overlap TB、C14/RTL/TB、C15/RTL/TB共7份全文实读；各端口、复位、握手、异常/配置资格、payload分段及数值位宽已核对，跨层最终验收仍部分。

## overlap

OVL-01..17主流程实际有1024组S2 RAW和变化D1_EXT的独立64位黄金比较（306行），粗精度屏蔽、正负中心与饱和、4拍完整保持、空闲状态、同拍替换、非边沿复位均有实测判据。OVL-09四组半值附近真实距离门限1/3 Q17整数单位，包含正负，无虚假半值标签。保持快照取自DUT仅证明稳定，首次反压载荷未另作全字段黄金比较；其它逐码有独立内容比较。

10个新输入未绑定，包括整个discard组和i_run_generation，原A编译10个dangling input警告，generation保存Z、discard逻辑无法被本TB定向触发。C-002说明测试缺口，不根据PASS签核接口。

AMI2077/2085事件和target取当前代际，1924→1972→2106的router current-generation透传等于target。AMI2086在terminal discard时遮蔽NORMAL输入，故overlap同时输入transfer优先clear以及忽略event-target的问题，在当前AMI合法事件路径有组合防护，未发现可达S1反例。独立叶子接口的陈旧target语义仍需必要最小仿真（WSL失败未执行）；F-002/F-004保留关联不重复。

## programmable reconstructor

Stage1完整12位值中心x2用14位，D2_EXT物理-4..515中心x2在-520..518内，窄到11位无损；接口可编码异常全范围的D2不是合法生产者值，不能以其被截断报功能错误。37位/31位乘积，33位offset*2，38位和/39位绝对值舍入足够合法范围；正负offset符号、stage2校准资格、9bit输出零/epoch清零和各payload分段已核对。ready只由ACTIVE资格/空槽/下游消费控制，ACTIVE变化不撤销已保存输出。

PR TB独立64位模型只用外部驱动输入，不用DUT中间值，1024码逐笔比较是真实算术检查。PR-04非零D2中心输入、两增益比较有效；PR-05 offset正负，PR-07全参数端点，PR-11四组合资格，PR-12 255→0，PR-13完整186位保持和PR-14精度切换有效。check_transaction遗漏Stage1两饱和旁路的内容比较；完整保持/复位只对DUT快照/零，不能证明非零透传，仍待负对照。

PR-06两offset ±32768时实际ACC为3599373/3468301，均正，四舍五入27/26，不是正负半值边界（C-003）。1024 sweep另有正负舍入，距门限最近25 Q17单位，不能称全TB不检查负数。A1奇数乘奇数Stage1中心项，Stage2与offset为偶数，ACC总为奇数；因此精确Q17半值（模131072=65536）在合法输入本来不可达，独立探针采用±65535/±65537四个可达门限邻点。参考、自校验（故意错期望被拒）、TB以及65536→65534变异均已保存；探针/变异未执行，不能称DUT PASS或称原TB漏检变异已实证。

## DC recovery

完整12位Stage1中心、37位A1、unsigned8位DC按正码扩展，signed32 gain乘41位，Q17左移后42位和/43位绝对值、24位饱和正确覆盖合法default范围；粗恢复只DC9，精细整数Q17仅DC15，AMB不入算术，offset不重复加入。全部payload/reset/输入与输出替换分支已逐支实读，无FSM/隐式锁存。可参数化IDAC位宽增大时固定41位乘法的支持范围需统一参数合同裁定，不能推定任意宽参数已验证。

原TB两个PASS有实际独立64位比较，fine ±0.5准确触发远离零舍入；9/15、资格0、metadata/epoch、AMB不入算术、颜色DC选择及同沿替换确有比较。它8个诊断输入及输出未接（C-002）；reset只检查valid/ready/coarse值，反压只检查部分payload；完整诊断/全部保持位未独立覆盖。无独立watchdog（每步有限posedge，但时钟本身固定），最终$finish退出0须读FAIL日志。DCR-22人为驱动非NORMAL，仅检查字段透传，PASS表示识别非法激励的观察，不证明RTL拒绝非法NORMAL（合同459将其定义为上游协议错误，不要求该叶子拒绝）。

DCR-09原物理大gain两组仍不饱和：coarse8355867/-8355813，fine8372223/-8372224；随后force只验证coarse正端与fine负端端点保护。default fine最大8372223、最小-8372224，本来达不到24位溢出；coarse用Stage1最大/最小和DC255可以真实达到8452441/-8480049后饱和。独立向量推导已保存，仍待公开端口DUT探针。

o_coarse_valid/fine_valid是payload资格位，消费后result_valid清零但payload保留，所以不恒满足C15:250和:264字面等式；AMI960以flag_dc_result_valid限定输入fork，2517也以pending限定PWI。需要确认合同是有条件的有效窗口等式还是要求独立valid门控；仅记录规范歧义，未报集成功能错误。

## 已知豁免与原始证据

C11:201..228、C14:276..293、C15:501..513明文免除discard广播/local_empty的条件链已对当前源码重定位：manager449..459 START要求i_datapath_empty；Top1338→742，control_plane402无锁存直达；AMI1140/1142/1143真实包含calibrated/reconstructor/DC输出valid。generation仅在manager532..533合法START变化，当前旧held与新generation不可并存。STOP/abort系统故障AMI951屏蔽各级valid并让下游空槽ready自排空，未把缺叶子clear端口当新错误。C11/C14/C15仍写generation输入/输出声明但实际叶子无该组，可能是合同字面欠同步，需与已接受P1范围裁定后再编号，不升级S1。

所有引用A日志只读复制到adc_reference/，skill AST对应固定blob；新临时TB没有运行结果。

## 最终补充
重构4门限邻点与舍入变异已实际执行；DC公开正负粗饱和向量也已执行，通过，错误期望对照拒绝（results_dc.json）。fine冻结域可达极值±837222x未越24bit端点，force只证明钳位分支。消费后残留coarse/fine资格按无有效result时的payload读取语义解释，AMI/PWI均有result/pending门控；未将字面有效性公式歧义报为S1。接口/默认域/全部异常已审；工具与跨系统剩余见最终台账。
