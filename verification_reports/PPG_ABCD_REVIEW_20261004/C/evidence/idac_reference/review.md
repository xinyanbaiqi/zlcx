# IDAC完整审阅

全文：C17合同718、RTL1267、TB894行；累计33/44。原单元TB i_run_generation在09-30已经接常量0，A真实148 PASS；旧33失败仅是RTL08-29历史变更记录，不能当作当前失败或重新编号。

## 数值/状态/接口

signed12比较窗口包含low/high，双饱和消费拒绝+sticky；高/低饱和优先比较。三组8位code，独立4位epoch，R/IR只由color选择，precision仅身份，不建第二套状态。9位端点和0..510，中点floor/2 0..255。candidate±1本身8位，但has_next和adjust_allowed严格检查边界，耗尽分支不使用会回绕的组合next值，故默认参数下无非法提交溢出。8位确认计数在threshold-1触发形成候选/清除，不会在合法N=1..255下溢出；N0只非法配置。

码实际改变才epoch+1模16/update；NORMAL来源独立track_adjust，搜索/手动不发track。三路pending只有frame-safe且RUN且非STOP/abort且代际相等才提交。pending不能阻塞track，消费不合格证据保持，无复制precision状态。packed上下文单时序原子写；reset默认code0/epoch0/allflags0。STOP/abort/nonRUN清pending/计数/序列并撤销活动故障，保留committed/epoch；新START不清故障（仅可能非法START新设故障），08-29死锁修复已在快照。

仲裁当前期待AMB/DCS优先于tracking，ready依赖valid使单拍最多一入口；没有样本流水，直接在握手沿组合评价。初始搜索AMB/R/IR、跳禁用、周期检查→受限重搜→固定R/IR重验证均逐分支阅读。invalid FSM编码转FAULT态，但当前没有同步设置fault位；runtime config检查仅在START应用，防御性异常规范存在缺口，暂不据此宣称正常冻结ACTIVE流程功能错误。非默认参数fixed packed offsets、C_RESET_CODE复位0的泛化限制留接口总审，不在默认冻结8位域误判数值溢出。

## 实际TB覆盖

原TB是真布尔条件、watchdog200us、有界服务80/40循环、失败需解析日志（finish退出0）。闭环数字plant根据DUTcommitted码和固定目标决定±20/0，最终目标固定5/15/24且期望独立；能测目标收敛，不能证明每次中点严格floor或模拟真实传递函数。所有搜索范围最大码30、和最大60，未触发第9位；实际8位和截断变异仍148 PASS。独立公开TB给固定范围0..255/目标200，期望候选127,191,223,207,199,203,201,200；原RTL8点通过，截断变异第二点得到63而非191，退出1，C-005。

原IDT09同时改变config_epoch/DCepoch，不能逐项证明AMB/DC快照和epoch的独立资格位；IDT11 pending期间只同方向载荷，没有反向覆盖攻击；IDT13 min=max15只数值/事件局部比较，不自动覆盖0/255或epochF→0；没有MANUAL、SEARCH_HOLD、双饱和、搜索耗尽及故障记录接口的定向比较，不能把148条显示行映射成IDC2-01..24完整闭环。两verification-only输入悬空由C_ENABLE_TEST_INJECTION=0确定屏蔽，是有注释和真实参数限定的允许情形，不并入C-002。fault event/identity完整输出未绑定，旧命名版本字符串V2.1仅历史日志标签，不改变实际代际连接。跨系统SID/TRK/ISE/RRC是否补足待后续系统TB全文核验。

## 合同差异

C17逐端口冻结i_diag_clear_event(159/305)，RTL75与TB786仍i_status_clear_event；AMI实绑这个旧leaf名。这是合同接口不一致，不是请求新增第二套clear源，C-006。
C17§8.3/8.4(482/503/671)要求AMB不变不发DCS重验，与其依赖C16§9.5/9.6(478/487)、实际RTL794及TB377/568无条件固定三帧冲突。C16现行专节明确无论AMB变化与否重验，因此RTL正确，C17文字滞后，C-007。i_track_precision_mode“只选择R/IR计数器来源”(86..87)亦与同文422和RTL137/140相反，属同次同步清理建议，不另计发现。

## 最终交叉裁定
SID耗尽阶段配置8..240、一路增码至上界，具备第9位系统覆盖机会；完整运行待A，C005仅指Unit盲点。MANUAL由JNT真实启动总线快照、SEARCH_HOLD由模式资格结构、双饱和由SID专属注入/原生sticky分支静态阅读、耗尽由SID12真实驱动源码补证；未把原148条显示映射成24项全面动态PASS。其它TRK弱代表性场景由IDT及独立资格结构补；完整回归未完成项仍部分。
