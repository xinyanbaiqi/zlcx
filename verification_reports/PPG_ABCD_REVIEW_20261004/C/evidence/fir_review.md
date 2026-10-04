# FIR 全文审阅批次

实际读取：RTL 1..768、TB 1..1191、合同1..686。
数学：21非负系数对称且总和32768；25bit和覆盖[-16777216,16777214]，41bit乘积/42bit累加/43bit绝对值和半LSB保护充分。11MAC+1提交12周期，无负数截断偏置。第21笔旧tap9提供中心元信息。两色历史独立、计数饱和21，invalid消费不移位，未校准/输入饱和仍移位并拉低覆盖窗口资格。输出反压稳定，重检busy不撤valid，不安全accept忽略。复位/START/匹配discard优先清空全部状态，超限只清事务。非法FSM回IDLE。
TB真实103 PASS；独立64bit21项模型，互异元信息，冲激21次、正负精确tie、端点、颜色/精度交错、invalid间隙，状态项0..10检查、watchdog、forced MAC-index超时都实读。原运行退出0只代表结束；变异164->165真实触发147 errors/96 pass/FAIL，退出仍0，必须扫描横幅。
门禁复用A同版本：VG052=1 VG061=2（已接受风格积压）；lint 0error0warning；comment gate自身scanned_files=0不能当实体注释充分证据，quality gate和全文人工检查补充。testbench/toolchain not_requested不能记通过。
待补核：FIR retained交易generation没有独立存储；需核实PWI排空/START前提，不先升级S1。
