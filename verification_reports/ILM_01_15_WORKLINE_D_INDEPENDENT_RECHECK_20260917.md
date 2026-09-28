# ILM-01~15输入光静态矩阵验收ID独立复核——工作线D新批次2（家族：ILM）

> 方法声明：本文档不信任`tb_ppg_control_top_input_light_static_matrix.v`自己详尽的
> changelog（V1.0设计说明+5处自捕获构造期bug修复记录）或`PPG_ALIAS_MAPPING_TABLE.md`
> 里ILM各行的既有映射，全部当作"待验证的声称"。复核方法：(1)从
> `PPG_JOINT_TB_CANDIDATE_TEST_SPEC.md`§3"合法启动配置矩阵"取每个场景行的verbatim
> 配置要求，(2)逐段读本文件`main_sequence`里每个ILM阶段真实的`if(...)...$display("FAIL
> ...")...cnt_error=cnt_error+1`断言代码块本身（不是只读`$display("PASS ...")`的文字
> 描述），(3)必要时反查RTL/层次信号确认断言逻辑真实对应DUT行为。
>
> **状态：ILM-01~15全部15项完成断言级复核**。结论：**2处真实缺口（轻微，ILM-06/
> ILM-07）+13项CONFIRMED+1个未解决的范围疑问（不计入缺口，见文末，需要超出本文件
> 范围的项目级搜索才能回答）**。与JNT家族（5/9真实缺口）相比，本次缺口率低得多——
> 这份文件的内部工程质量明显更高（自己的changelog记录了5处独立自捕获并修复的构造期
> bug，包括一处监视进程作用域冲突和一处fork/join竞争窗口），没有发现JNT那种"整段
> 合同要求静默消失"的模式。诚实报告一个较少缺口的结果，不为了和上一批"对称"而拔高
> 严重度。

## 真实缺口1：ILM-06——外部固定电流纯RED的SAR15子用例缺EN_TEST/LEDEN/LEDDAC边界检查

`tb_ppg_control_top_input_light_static_matrix.v`第1745-1821行，ILM-06分两个子用例（SAR9
在前、SAR15在后）验证"外部固定电流+RED_ONLY"场景。SAR9子用例（1763-1781行）在事务计数
和颜色隔离之外，额外检查了`(!o_en_test) || o_leden1_low || o_leden2_low || (o_leddac !=
8'h00)`这个边界条件（1776行）——这正是合同§3表格"外部固定电流"行"EN_TEST=1，LEDEN/
LEDDAC关闭"这一列要求的内容。但紧接着的SAR15子用例（1786-1818行）只检查了事务计数和
颜色隔离两项（1810/1813行），**完全没有重复这个边界检查**——同一个ID（ILM-06）下两个
理应等价的精度子用例，覆盖深度不对称。

## 真实缺口2：ILM-07——外部固定电流纯IR的SAR15子用例同样缺边界检查

同一份文件第1823-1896行，ILM-07的结构与ILM-06完全对称（SAR9子用例1841-1858行含边界
检查@1854行；SAR15子用例1864-1896行同样只检查事务计数@1888/1891行，不含边界检查）——
与缺口1是同一种遗漏，在另一个ID上重复出现，说明这不是笔误式的单点疏漏，而是这两个
"先SAR9后SAR15"结构的ID都只把边界检查写在了第一个子用例里。

**两处缺口的共同特征**：EN_TEST/LEDEN/LEDDAC边界这个要求本身在同一份文件的ILM-04/
ILM-05（BOTH双色场景，1690/1734行）里是完整覆盖两个精度的；只有RED_ONLY/IR_ONLY这两个
单色ID的SAR15子用例遗漏。修复方式明确、风险低：把SAR9子用例已有的那一行边界条件复制
到SAR15子用例的判断链里即可，不涉及RTL、不涉及新增信号。

## 待核实的范围疑问（不计入缺口，需项目级搜索才能回答）

合同§3"合法启动配置矩阵"共13行，本文件的15个ID里，"NORMAL双光"对应ILM-01，8行
CHARACTERIZATION相关行对应ILM-02~08，STATIC_BIAS对应ILM-13/14（+ILM-15负向），
ILM-09/10/11/12是跨场景的专项检查（MANUAL-only监视/中途重配置拒绝/AMB_CAL/DCS_CAL）
——但表格里的"NORMAL纯RED"、"NORMAL纯IR"、"SAFE_OFF（非测量）"这三行（NORMAL_PPG模式
+ RED_ONLY/IR_ONLY/OFF光学模式的组合）在本文件里**没有看到对应的专属ILM子ID**。

这三行是否有真实测试证据，本次没有确认——可能的原因有两种，无法仅凭本文件内容区分：
(a) 它们是本项目其他远比ILM更常触碰NORMAL_PPG模式的TB文件（比如`tb_ppg_control_top.v`
自己的SMOKE系列）已经覆盖过的日常路径，ILM家族的15个ID从一开始就没打算重复覆盖这三行，
只专注于CHARACTERIZATION相关的新组合；(b) 这确实是一个未被任何ID认领的真实空白。区分
这两种情况需要跨文件搜索"NORMAL_PPG.*RED_ONLY"/"optical_mode.*OFF"之类的组合在项目全部
TB里的出现情况，超出本文件独立复核的范围，如实记录留供后续参考，不擅自归类为"真实缺口"
或"已覆盖"。

## CONFIRMED项要点说明（13/15）

- **ILM-01**（1394-1432行）：NORMAL双光，commit+lifecycle+EN_TEST（START后即时+循环后
  收尾两次检查）+RED/IR各≥2笔真实事务，内容完整对应合同行。
- **ILM-02/03**（1438-1537行）：PHOTODIODE纯RED固定SAR9/SAR15表征，事务计数精确匹配
  （3笔RED、0笔IR）+AMB/DC_R码未漂移（02）+全程精度不掉出SAR15（03，用
  `B_FRAME_PRECISION`直接层级读取，只在见过真实owner提交后才判定，避免复位默认值
  误报）。
- **ILM-04/05**（1657-1740行）：外部固定电流双色SAR9/SAR15，事务计数（各≥2笔）+
  EN_TEST/LEDEN/LEDDAC边界全程latch监视（真正的连续检查，不是单点抽样）。
- **ILM-08**（1901-1916行）：安全关闭光学模式拒绝，`error_code==C_ERROR_FIXED_CURRENT_
  OPTICAL_MODE(8'h16)`+lifecycle停CONFIG+owner计数/LED/EN_TEST零副作用三重确认。
- **ILM-09**（1270-1295行）：全程持续监视进程，直接层级读取idac控制器`state_current`
  只允许IDLE/MANUAL_APPLY/NORMAL三个状态，2026-08-29回补ILM-11/12时真实踩过一次监视
  范围冲突（SEARCH_TRACK阶段真实进入DCS_IR_WAIT触发大量误报）并修复为显式收窄范围
  （`flag_ilm09_monitor_active`），是直接层级证据而非"没观察到AMB_CAL/DCS_CAL事务"
  的反推。
- **ILM-10**（1539-1655行）：中途重配置拒绝，用fork/join内部全程latch监视（而非join后
  单点抽样，文件自己changelog记录过第一版就是单点抽样漏检的教训）确认`error_code==
  C_ERROR_COMMIT_STATE`+波形控制向量零扰动+原事务不受影响+STOP排空后重新COMMIT同一份
  配置确认下一次合法生效。
- **ILM-11/12**（2042-2181行）：AMB_CAL/DCS_CAL真实二分搜索收敛检测（`flag_amb_
  converged`/candidate-guard循环，非首候选即认定），RED/IR窗口极性（`leden1/2_low`
  真实1=点亮/0=关闭惯例，与SID-07/08/09同款）+AMB总线在DC_R/DC_IR阶段保持已确认码。
- **ILM-13/14**（1921-2012行）：STATIC_BIAS合法场景，~20项netlist级静态向量逐一核对
  （所有时钟门控/使能/IDAC总线归零）+`o_s_in`即时匹配提交值+3000拍稳态idle监视
  （`o_scheduler_idle`/`o_ami_datapath_empty`/`o_ssw_wrapper_idle`三方联合）+运行期
  test_mux_ctrl原子更新验证。此阶段还包含一段值得注意的诊断：文件作者用直接层级读取
  确认了"进入本阶段时`macro_tick`停在约500而非0"是更早阶段遗留的空转宏帧尾巴，不是
  本阶段自己引入的活动，为此在检查"全程idle"之前先等这一整帧走完——这是真实调试出的
  时序细节，不是猜测。
- **ILM-15**（1359-1392行）：STATIC_BIAS非法输入源（PHOTODIODE）拒绝，
  `error_code==C_ERROR_STATIC_BIAS_INPUT_SOURCE`+lifecycle停CONFIG+owner计数零副作用。

## 完整复核表（15/15全部完成）

| ID | 场景（文件行号） | 结论 |
| --- | --- | --- |
| ILM-01 | 1394-1432 | CONFIRMED |
| ILM-02 | 1438-1480 | CONFIRMED |
| ILM-03 | 1485-1534 | CONFIRMED |
| ILM-04 | 1657-1696 | CONFIRMED |
| ILM-05 | 1701-1740 | CONFIRMED |
| ILM-06 | 1745-1821 | **真实缺口（轻微）**——SAR15子用例缺EN_TEST/LEDEN/LEDDAC边界检查 |
| ILM-07 | 1823-1896 | **真实缺口（轻微）**——同ILM-06 |
| ILM-08 | 1901-1916 | CONFIRMED |
| ILM-09 | 1270-1295 | CONFIRMED |
| ILM-10 | 1539-1655 | CONFIRMED |
| ILM-11 | 2042-2101 | CONFIRMED |
| ILM-12 | 2101-2181 | CONFIRMED |
| ILM-13 | 1921-1994 | CONFIRMED |
| ILM-14 | 1995-2008 | CONFIRMED |
| ILM-15 | 1359-1392 | CONFIRMED |

## 与今日工作线B回归的交叉核对

本文件是`module_tb_regression`/19-TB体系里含JNT基线调用的文件之一（1357行
`run_jnt_baseline_01_09`），今日重跑同样报告`JNT_BASELINE ... status=PASS`；ILM自身
15个阶段的PASS消息与本次独立复核读到的断言代码逐一对应，"现有检查全部真实通过"这个
事实没有问题，本报告的2个缺口指的是"同一ID内部两个子用例覆盖深度不对称"，不影响现有
PASS结论的有效性。
