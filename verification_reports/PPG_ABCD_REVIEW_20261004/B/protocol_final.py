from review import *
(OUT/'protocol_table.md').write_text('''# 请求 → 身份保持 → 提交/截止 → 完成/discard → owner释放

被审提交：`d18c6954621e53e5a6505dd3a6c688c266d23839`。B组协议审阅完成，2026-10-04。表内是当前实现及确认偏差，不是正确性签核；共享源未修复。完整源文件路径/实际行号见findings_index.csv、coverage.csv和报告。

沿t的条件用沿前值，寄存结果在NBA更新后可见；下一消费者按自己的注册边界处理。源请求、缓存握手、物理owner提交、结果消费是不同事件。跨模块延迟以真实短仿真trace为准，不能把所有寄存事件画成同一沿。

| 环节/所有者 | 请求/提交资格 | 身份保持、释放及取消 | 实际证据/偏差 |
|---|---|---|---|
| Top生命周期 | manager注册START/STOP ack，RUN/generation授权新工作 | STOPPING撤销RUN；旧DONE不能绑定新generation | 人为cancel仍保持RUN=1的叶子刺激不能证明Top STOPPING死锁 |
| AMI startup请求 | IDAC真实startup请求先进入AMI保留缓存 | 请求与Scheduler握手后outer inflight；未取得owner的deadline应重试候选 | SID-05三阶段有真实deadline抑制/恢复；已知tick248同拍commit不另编号 |
| AMB periodic请求 | 完整NORMAL帧计数到期，pending等15→9和六项safe资格 | AMR→AMI缓存握手先令inner inflight=1，此时尚无物理owner | B-007 deadline只清outer，inner仍1/valid0，真实idle1也不能RUN内重试；实际accepted或!RUN/START/reset可恢复 |
| Scheduler CAL请求 | 双边RUN/NORMAL_PPG/PHOTODIODE/AMB或DCS/SAR9资格，valid&ready | CAL_REQ_PENDING冻结请求，错过固定点/截止后保持到下一子帧重试 | 非法请求不得波形/owner/序号副作用；TB58/59确有比较，但FSC-17同号语义错误B-018 |
| Scheduler waveform | NORMAL RED tick0、IR160、CAL local0，独立SSW wave-ready | 冻结模拟上下文/码/epoch/精度/颜色；不启动AMI、不消费sample_index | 错过固定点不补迟到波形/移动Q3；launch sticky非阻断，owner截止另分类 |
| Scheduler owner | CAL>RED>IR pending，SSW owner-ready、AMI ready、allow及生命周期有效 | 单个inflight冻结sample/type/color/generation；只有真实fire使sample_index加1 | STOP/abort/block禁止新owner；与wave接管分开，frame-latched码/epoch不混合 |
| Scheduler deadline | CAL248、RED283、IR443，pending且无inflight | 未fire的请求槽撤销留软历史，已提交owner仍等匹配完成 | 本地next同拍commit优先；CAL输出未mask同拍commit是已知基准问题 |
| Scheduler宏帧 | 默认tick0..4999；NORMAL无active才启动新帧 | NORMAL末拍清active，下一沿才新建；CAL后置rollover可不空一拍 | B-003连续NORMAL实际5001拍；B-005CAL末拍abort被rollover重新建立逻辑frame，未见新物理owner/永久死锁 |
| SSW模拟槽/窗口 | 双wave槽、精度/颜色/类型白名单；使用已冻结码 | SAR9/SAR15逐bit窗口独立，当前AMB_CAL Q2全0、Q3窗口不变 | V1.10增量与RTL一致；D03 cause22按已知冻结；模拟safe与完整SSW idle不同 |
| SSW owner/Q3 | owner-ready并满足公开上下文/资格，保持最小sample/generation | per-owner Q3 closed跨宏帧回绕；匹配完成无论success应释放owner | B-012 abort保持优先吞同拍完成；AMI/Scheduler释放、SSW仍1。真实Top首次CONFIG可达，新START仍受阻；reset可失效旧数字身份 |
| AMI真实RAW/DONE | capture需真实start武装，RAW经过S1/Router/重构/DC | completion旁带使用原owner；success=0负责释放而无正式结果 | 未武装旧/重复DONE安全丢弃；错sample/generation不释放新owner；diag_clear不伪造DONE |
| Scheduler DONE | sample/generation一致释放；正式success另需不discard及Q3 closed | 匹配即清inflight，早Q3/failure也释放，但不计正式NORMAL成功 | B-004 Q3恒1/固定DONE模型掩盖错误；Q3=0补充场景原释放而不计成功，负对照错误计成功 |
| AMI双结果分支 | DC真实transfer建立measurement/detection pending | 每支valid等自己的fire/discard；formal缓存A时上游fork可已到B | B-006 discard错取B身份；B-008measurement消费清共享sample-valid，detection仍pending/FIRbusy，独立资格丢失 |
| AMI fault reason | supervisor只一拍fault-discard，AMI在当前generation记内部reason | 后续延迟terminal仍使用fault reason，数字terminal排空后才清 | 后来的STOP/abort不能改reason，不跨generation；一次源事件与每terminal仅一次discard分开检查 |
| PWI入口/empty | same-generation合法NORMAL；invalid只消费上游，不推进算法历史 | FIR/fork/baseline/PVW/PWC各有pending，empty真实聚合 | V5门控由AMI唯一注册producer原样扇出；低门控可安全排空、无正式事件/fault；F-001按实际输入资格解释 |
| PWC精度commit | cross/return保持，等frame-safe/takeover-safe/analog-safe且!recheckbusy | precision、fine状态、start/return事件有不同更新位置 | B-010matching discard清FSM却commit公式仍有效，物理模式及正常事件改变；stale-generation对照不取消；未新模拟完整Top同拍窗口 |
| PWI历史/PV窗口 | recheck accept清两色history与旧证据，真实有效NORMAL每色21笔恢复 | maxfine/maxreacquire由PVW消费，PWC消费派生return请求 | B-017直接消费者表错；B-011原TB未用累计尾部判据，纠正观察点及累计条件可区分早overflow |
| Supervisor | 注册故障源固定优先、watchdog真实idle优先；new fault胜过clear | episode开一次abort/stop/discard trio，close不清first-fault历史；可独立rearm | B-001非法width未拒绝；B-002原rearm已经clear历史，错误副本逃逸；保留历史补充场景可拒绝错误实现 |
| sticky历史 | PWC START保持历史，仅clear/reset清；活动根因限制clear | 已知09-17 PWC两sticky修复有效，有非空前提和比较 | B-009AMI仍把START并入清历史，PWC修复不能补偿AMI |

| 跨层观测/反证 | 范围 |
|---|---|
| INJ互斥 | 原重叠4拍无ready处理资格，删除互斥仍过；穿过真实DONE时原ready0，负对照ready1且正式结果失败，B-013 |
| P06去使能 | RUN时Top锁存模式，source0而AMI leaf1，leaf-clear-on-disable错误副本仍过，B-016；Top锁存本身合法 |
| RRC间隔 | 真实完整帧计数和pending快照只有打印，未与配置30比较，B-014；不据此声称数值RTL错误 |
| OIB stream | 仅拒绝递减/相等frame+sample，唯一身份下丢失或元数据错误反例仍过，B-015；这是静态谓词重放。单笔OIB-07/09真实字段/epoch比较仍有效 |
| 外部响应 | owner等待ADC DONE/physicalidle，或formal valid等待ready，本身不是内部死锁。B-007没有owner，B-012完成已经发生却本地吞掉，分别排除此解释 |
| 追溯 | FSC/SUP同号场景错位B-018；C09第3行V1.10与sole V1.9/三处依赖不一致B-019；文字联系不是当前CLOSED |

证据：详细报告、findings_index.csv、evidence/final_baseline.json、final_trial_inventory.json、id_four_link_audit.json、dependency_bindings.json及各短试验原日志。52次既有试验包含无效setup/负对照，不代表52份原TB通过。全套/长回归、完整全局ID/锚点和系统签核由A汇总；本组没有运行中仿真。
''',encoding='utf-8')
print('Protocol table finalized; all seven B RTL lifecycle paths represented')
