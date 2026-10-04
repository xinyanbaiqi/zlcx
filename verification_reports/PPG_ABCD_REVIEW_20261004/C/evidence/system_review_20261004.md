# C 系统级增量审阅（2026-10-04）

固定基准 d18c6954621e53e5a6505dd3a6c688c266d23839，共享源只读。

## RAW / JNT / ADCN
- C25合同976行、RAW支持头364行、RAW自检532行、JNT支持头807行、ADC数值记分板1463行均全文实读。当前累计40/44份全文读过，不等于功能签核。
- RAW八档选择与整数分段/噪声hash/漂移/clamp：合法参数均避免零除，显式clamp到8..503，noise hash按无符号32-bit回绕后mod，不能据hash回绕称RAW溢出。自检RGC13测参数周期比，RGC14测参数切迹幅度；不单独当端到端精细峰谷证明。RGC08步长31在0..3999只访问130点，注释“所有相位”过强，尚未独立编号。
- JNT真实54子检查：52原语义+JNT06独立START+补IR预建立。相对owner/completion增量、Q1Q2Q3、总线、abort/STOP success0、复位stale DONE、owner deadline均有真实动态条件；头注旧52/53属于历史，当前常量54和最终计数相符。待检查调用方对JNT门禁failclosed。
- ADCN逐物理bit的Stage1模型使用encoded raw，S1半LSB正负及offset正负饱和是真激励；SAR15实际从CHARACTERIZATION合法配置获得，D2参考target解码和物理冗余校正吻合。64-bit DC/reconstruct模型宽度足够本场景且与C合同算式相符。
- ADCN07对owner snapshot八字段及当前冻结coef/config版本真实比较；Stage1饱和诊断层次读取已存在，不能重报2026-09-28历史缺口。ADCN10同fork上游Stage1结构证明符合已接受TRK01方法；同源fork比较不是独立数值oracle。
- ADCN08只稳定检查S1/coarse数值及valid；其它资格/诊断/身份比特和SAR15细值需跨OIB03及leaf证据查证。ADCN06抓了DC saturated/calibration标志但drive_and_check_transaction未比较，需DC unit跨文件反证，暂未新增发现。
- ADCN公共ready在第200个posedge active区释放，结果捕获末尾未严格要求16；跨工具旧PASS不是排除竞争的证明，尚待裁定。

## 剩余全文
四份系统TB：baseline_cross、peak_valley_return、fir_tail_isolation、normal_slow_tracking；baseline只读到285行，其中长头30..112工具输出截断须补读。

## 系统四份完成语义核查
- baseline_cross全文1907个物理行已实读（工具显示尾空行计1908）；其余三份用标准difflib逐段核对共用原文，并实读全部不同原文。逐段映射及输入SHA256保存在system_compare_*.json和system_diff_*.patch；没有自造Verilog解析器。peak共1322相同行+259不同，tail1323+389，track601+957；全部行属于已审原文或本次实读原文，不能将此方法表述为逐行重复展示。累计44/44份完成全文语义覆盖，ID/跨文件/八门禁还待闭环。
- 基线系统群延时 A检查>=10、B对闭式转角±11，candidate真实RED身份精确比，B[f]独立算式但斜率取RTL诊断字段；安全切换门控使用上一拍；N01四消费者empty、N08只有scope-only；D01 STOP清状态+合法CONFIG改valid0再恢复，不能将不可达RUN直接改配置当缺陷。
- Group3峰谷先后/中心帧上下界/return原因及谷同拍fallback/返回安全门控、存在性检查有真实条件，未用精确事件帧标签替代golden。中心身份范围检查弱于精确绑定，需PVW leaf跨文件反证。
- Group4逐RED尾部最长10、每次尾样本下一拍previous_valid/below_seen清零、首合格重建参考、真实二次cross；混精度FIR合法，隔离点为cross eligibility，不误报FIR历史不清。
- Track主场景含确认3、方向切换、R/IR一次交错、pending+1和epoch+1、真实16次epoch回绕、上限82、校准资格0与DC快照255拒绝、Stage1=37、真实SAR15往返；accepted TRK01结构证明不重报。待查TRK06读committed值未读pending且静等不送后来证据；TRK07不计update/track-adjust事件；TRK08只上限未下限；TRK09无逐epoch拒绝；TRK05判定入口counter与出口code/epoch，未退出counter与pending，全局协议sticky未检查。必须跨Unit/ISE/其它证据裁定，暂不称RTL错。

## 最终裁定
TRK/ADCN交叉证据已核：Unit IDT12单拍/IDT13双端，IDAC453/486..498 pending及全部资格AND，precision无状态作用；不追加这些重复覆盖发现。OIB03+AMI1748支撑正式measurement原子保持，不支撑另分支sample-valid，关联A F021。JNT新增C008计数不足不累计错误，有隔离原文短探针3次；基线OPT23/24新增C009静态验收缺口。DC公开饱和2向量及错误期望负对照实际完成。最终状态以PPG_REVIEW_C.md及id_review_matrix.csv为准。
