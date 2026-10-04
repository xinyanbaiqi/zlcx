# 2026-10-04 数值链检查点

固定提交 d18c6954621e53e5a6505dd3a6c688c266d23839；全文读取与专项闭环分开记录。共享源码未修改。

## 已实读范围

- contracts/PPG_DYNAMIC_BASELINE_SLOPE_AND_UPWARD_CROSSING_INTERFACE_CONTRACT.md
- contracts/PPG_DYNAMIC_BASELINE_ARITHMETIC_OPTIMIZATION_CONTRACT.md
- contracts/PPG_COARSE_DETECTION_FIR_INTERFACE_CONTRACT.md
- contracts/PPG_ADC_S1_PROGRAMMABLE_CALIBRATOR_CONTRACT.md
- contracts/PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md
- contracts/PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md
- rtl/ppg_adc_pipeline_overlap_corrector/ppg_adc_pipeline_overlap_corrector.v
- rtl/ppg_adc_async_stage_capture/tb_ppg_adc_async_stage_capture.v
- rtl/ppg_adc_async_stage_capture/ppg_adc_async_stage_capture.v
- rtl/ppg_adc_s1_programmable_calibrator/tb_ppg_adc_s1_programmable_calibrator.v
- rtl/ppg_adc_s1_programmable_calibrator/ppg_adc_s1_programmable_calibrator.v
- rtl/ppg_adc_result_router/tb_ppg_adc_result_router.v
- rtl/ppg_adc_result_router/ppg_adc_result_router.v
- rtl/ppg_adc_s1_redundancy_corrector/tb_ppg_adc_s1_redundancy_corrector.v
- rtl/ppg_adc_s1_redundancy_corrector/ppg_adc_s1_redundancy_corrector.v
- rtl/ppg_coarse_detection_fir/tb_ppg_coarse_detection_fir.v
- rtl/ppg_coarse_detection_fir/ppg_coarse_detection_fir.v
- rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_phase_a_arithmetic_equivalence.v
- rtl/ppg_dynamic_baseline_cross_detector/tb_ppg_dynamic_baseline_cross_detector.v
- rtl/ppg_dynamic_baseline_cross_detector/ppg_dynamic_baseline_cross_detector.v

## 基线

主RTL、两个TB、两个合同全部实读。基线分子42位、除法42轮、负基线48位、beta乘积50位、候选35位的边界与符号扩展按合同核对；正负Q15半值采用远离零舍入。最大合法运算约52周期，低于128周期回退门限。公开输出保持、峰事件pending匹配、配置快照、超时/非法配置回退及复位/重启/discard/recheck分支已逐支阅读。

独立BigInt合同参考只读取输入参数，未读取DUT中间值。10组公开端口向量实际PASS，含lead16/17/19/20、极值、正负beta变化和上下限饱和。vectors.json与当前tb扩展为12组，其中新增正负精确半值尚未执行；run_10vectors.log对应10组，不能冒充12组。WSL DrvFS出现I/O错误后编译失败，编译日志已保存，不终止或重启共享WSL。round-half 16384→16383变异副本已准备，尚未运行。

原65 PASS日志与每个比较已核对。OPT-23任务调用两次reset，不能证明连续双周期pending隔离；OPT-24随机32组只独立核对alpha除法，不独立检查最终斜率随机结果。OPTC乘积监视部分依据DUT快照，证明局部共享乘法路由；phase_a_equivalence无DUT实例，为公式宽窄等价辅助检查。OPT-05/06只看平滑符号和最终限幅，精确半值数值覆盖待负对照裁定。BSL-40资格非法场景未见主TB定向实现；跨层PWI与系统TB覆盖未读完，暂不签核。

资格失效是否撤销周期adaptive状态、invalid-cross配置是否只禁止正式事件而允许部分历史更新，需追溯PWI/生命周期合法输入；当前仅待查，不报功能错误。

## ADC捕获/冗余/校准/路由

async_stage_capture：两级同步DONE、transaction_start锁存精度、pending one-shot、旧输出与新pending并存、单寄存器输出保持及异步复位逐支检查。原TB对4个DONE相位、非选中DONE、重复DONE、反压及换档检查有效；没有据数字模型宣称模拟CDC总线正确，RAW稳定条件和start清DONE依赖上游协议。

redundancy：D1_EXT=8*high6+low3+(B_RED?4:-4)，物理范围-4..515；11位带符号扩展后夹9位输出。TB1024组物理RAW通过capture逐笔比较独立整数参考、RAW/精度/元信息；并发旧capture与新start依靠NBA旧上下文，保持/同周期替换/复位检查有效。

programmable_calibrator：十个26位有符号权重+32位offset用33位累加，34位扩展，35位绝对值+半值舍入，20位恢复符号后夹12位；最大合法和2.483e9在33位范围内。TB1024组、十个独立onehot权重、混合符号、6组半值边界、上下饱和及131位保持/复位/epoch回绕确有比较。C11 discard/local-empty条件豁免需查实际AMI stop-drain前提，不能仅因叶子缺端口报错。

result_router：纯组合三路由与非法frame11、reset控制抑制、非选中ready不干扰、valid0 ready1逐支核对；generation输出是输入透传。原TB完整实读但遗漏i_run_generation绑定，A编译有dangling input22 warning；gen有效事务为Z且未断言。属于候选测试覆盖问题，需独立公开端口探针/变异和跨层确认后编号。

## 流水线overlap RTL

全文实读，尚未读本模块TB。15bit公式按合同A1=3533837、A2=54143，中心x2、36位乘积、37位求和/38位绝对值舍入、22位恢复符号后限幅15位；9bit路径只S1 nominal有效，不产生S2/15bit有效，寄存 payload保持。

i_datapath_discard_run_generation未用于匹配；flag_discard_apply比较retained generation与当前输入generation，输入transfer优先于discard清valid。需追溯AMI事件生产与合法并发，相关既有F-002/F-004不重复编号；不能据叶子端口缺失自动升级S1。

## 工具与证据限制

12个RTL复制件与快照blob一致；已实际调用erie analyze-existing --no-state，静态AST均无parse_error，复用A同版本门禁。Toolchain/testbench not_requested不是通过；comment gate scanned_files=0不是注释语义证据。222已接受风格积压只按适用规则豁免。Icarus11先前10组baseline与8组FIR已执行，后续WSL失败须保留未执行状态。FIR系数164→165原TB真实147错误；原103 PASS、8组独立合同向量PASS已复核。

## 最终状态覆盖前述待执行记录
12基线公开向量及正负半值负对照实际完成；C009确认OPT23/24验收覆盖范围不足。BSL40系统D01+PWI正式门控补静态；C11/C14/C15 START/empty豁免成立。全部44全文语义审阅已完成，12RTL真正注释目录扫描及ID/端口矩阵已保存；动态/工具剩余以最终报告为准。
