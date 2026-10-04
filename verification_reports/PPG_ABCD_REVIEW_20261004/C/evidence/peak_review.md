# 峰谷检测审阅（固定快照，只读）

全文实读：C22合同1..901、RTL1..1004、TB1..1205。当前计30/44，ID总映射和独立RTL复现尚未闭环。

## 数值与状态

24位有符号PPG用25位差值，±16777215在范围内；deadband/minAmp按25位无符号零扩展，方向严格大于门限，幅度严格正且>=门限。16位帧差使用模减，MSB排除半回绕；正式峰峰参照只在真正无前峰时豁免，不因reacquire自动豁免。PVW-09-WRAP连续真实回绕到20帧，PVW-39-WRAP连续32768平坦帧排除了“不连续分支替代半回绕分支”的假证明。

运行极值在相同平台值更新到最后一帧；5位next确认数容纳4位1..15阈值且有界。上下方向清零，flat/IR/无资格保持；正式样本帧不连续清计数并sticky。上下文原子打包值、实际中心frame/sample和3epoch，不再扣FIR10帧群延迟。所有输出reset低有效异步清零，context clear最高优先，消费释放valid，输出pending阻止新FIR输入。sticky优先新故障再diag-clear，不随普通START/STOP清除。

fine资格绑定实际极值的precision/frame而不是确认时刻；入口旧9-bit10笔允许负帧龄，正式15-bit出现后不得倒退；退出被动旧15-bit10笔不阻挡idle。timeout>=门限以RED真实帧更新，谷值同拍成功优先。reacquire timer重启且不伪造锚点。单bit FSM不存在第三个二进制编码，不将无default恢复误判为缺陷。

## TB实效与限制

54个显式布尔判据、独立watchdog50ms；失败仍finish退出0，外层必须解析FAIL与总数。PVW-40是随机步长的单调上/下波形，参考来自生成波形极值和最后平台帧，独立于DUT信号，能证明该波形峰谷值/时间；它不是任意噪声状态机全随机golden，也未覆盖全部epoch/饱和/方向边界。PVW-19仅驱动window_saturation_high，另外3饱和输入一直0，不能自动标为所有饱和位定向覆盖。PVW-01仅查valid/state/sticky不逐项检查清零payload；PVW-28/29/30无新输入，held字段比较不是整包每拍变化攻击。PVW-31改变epoch在谷搜索很早的位置，未构造第N确认沿漂移。PVW-32/46层级观察用于局部历史清空，不能代替公开输出行为的独立算法参考。

## 返回阻塞静态反例（C-004）

ready仅受peak/valley pending限制，return pending不限制输入。公开端口序列：RUN + fine start0；峰120@frame1，谷50@frame7于frame10确认；return ready始终0，消费valley；再送100/120/110/100/90@11..15并消费peak，再送80/60/50/60/70/80@16..21。第二峰frame12距离前峰11>=minPP4，第二谷frame18距离峰6>=minPV2，幅度70>=minAmp20，均同epoch/fine，age21<maxFine40。第二谷确认会再次触发RTL555写return frame21，旧frame10从未握手。该结论来自逐项公开输入与同步方程，非仿真日志。准备件peak_public_vectors/tb_C_peak_return_hold.v复制原有完整驱动/绑定，以固定期望frame10检验；未执行，WSL检查未恢复，不写PASS。

反驳：生产PWC RTL280在正常ST_FINE立即ready，通常下一沿接受，故不据此宣称Top常规流程必现或模拟硅故障。叶子C22§11.3/11.4明确允许独立分支反压，无最大阻塞时长；PVW-30持有valley使ready0，掩蔽该边界。需要保持旧请求或阻止能重复建立请求的输入/事件，报告建议不改源码。

## 跨层资格与待验证候选

C22后附sample-valid条款没有对应leaf端口；PWI630真实将上游i_sample_valid送FIR，FIR资格0只释放不进入历史，PWI656接FIR完整窗资格，经fork原子保存并849接peak i_detection_qualified。因此生产资格路径已有实现，不直接编号缺sample-valid的S1。该合同接口文字是否应描述层级范围，留最终ID/版本核对。

epoch第N确认沿漂移可能同时触发tracking restart与accept（RTL391/404没有排除426）；端点epoch配对仍旧值，运行候选会清除，需公开向量和冻结ACTIVE前提核验，暂未作为发现。runtime clear !run_enable与生命周期事件优先级留跨层最后核验。o_local_empty与o_detector_idle当前同值，注释“更严格”只是冗余解释，不单列功能缺陷。

## 实际仿真补充（覆盖上述未运行状态）

A已恢复现有Icarus11至Linux /tmp，C用tar标准输入传输自有副本，未重启或改工具。原RTL公开反例退出1，frame10→21；追加协议sticky必须0仍在载荷比较失败。仅在自有副本555建立载荷时加入return pending==0的反驳对照退出0，C_RETURN_HOLD_PASS。证据targeted_runtime_20261004/results_peak_control.json及两个run.log。C-004按任务严重度定义归为S1真实RTL错误，限定叶子合法反压，不扩大为Top必现。
