`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/01
// Design Name:        PPG ADC Result Router
// Module Name:        ppg_adc_result_router
// Description:        Description/ppg_adc_result_router_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_adc_result_router
//
// Referrences:        PPG_ADC_IDAC_INTEGRATION_SPEC.md,
//                     PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md,
//                     ppg_adc_s1_programmable_calibrator.v
//
// Dependencies:       ppg_adc_s1_programmable_calibrator
//
// Version:            V1.1
// Revision Date:      2026/08/22
// History:
//    Time               Version       Revised by            Contents
// 2026/08/01            V1.0          Erie                  Create file.
// 2026/08/05            V1.0          Erie                  Forward S1 raw physical decisions.
// 2026/08/06            V1.0          Erie                  Add calibrated payload and version tags.
// 2026/08/22            V1.1          Erie                  Add i_run_generation/o_run_generation pass-through per PPG_ADC_ROUTER_TO_PIPELINE_OVERLAP_INTERFACE_CONTRACT.md section 4.1.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月01日
// 设计名称:           PPG ADC结果路由器
// 模块名称:           ppg_adc_result_router
// 模块说明:           Description/ppg_adc_result_router_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_adc_result_router
//
// 参考资料:           PPG_ADC_IDAC_INTEGRATION_SPEC.md、
//                     PPG_ADC_S1_CALIBRATOR_TO_ROUTER_INTERFACE_CONTRACT.md、
//                     ppg_adc_s1_programmable_calibrator.v
//
// 依赖文件:           ppg_adc_s1_programmable_calibrator
//
// 当前版本:           V1.1
// 修订日期:           2026年08月22日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月01日        V1.0          Erie                  创建文件
// 2026年08月05日        V1.0          Erie                  透传S1物理决策位供可编程校准和测试导出
// 2026年08月06日        V1.0          Erie                  扩展Stage1校准结果、状态和配置版本公共载荷
// 2026年08月22日        V1.1          Erie                  按合同4.1节新增i_run_generation/o_run_generation原样透传

// 按帧类别把一笔Stage1校准事务互斥分发到AMB校准、DC校准或正常PPG处理链
module ppg_adc_result_router
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16,                         // R/IR共享PPG周期标识的字段位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16,                     // 全局ADC结果顺序编号的字段位宽
	parameter integer C_IDAC_CODE_WIDTH = 32'd8,                         // AMB与DC实际施加码快照的位宽
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4,                        // IDAC安全提交版本标识的位宽
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8,                      // 完整ACTIVE配置版本标签的位宽
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8,                        // Stage1校准系数组版本标签的位宽
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8                    // manager唯一产生、AMI逐层传入的RUN代际字段位宽
)
(
	//---------------全局信号---------------//
	input i_rstn,                           // 低有效数字复位，复位期间关闭全部事务握手

	//----------Stage1校准结果输入接口----------//
	input i_result_valid,                       // 校准器保持完整事务有效直到本模块返回ready
	input signed [11:0]i_calibrated_s1_value,   // Stage1逐物理位乘加后的signed 12-bit残差
	input i_calibration_applied,                // 本笔结果使用合法片外拟合系数的资格标签
	input i_saturation_low,                     // 校准舍入结果低于signed 12-bit范围的标志
	input i_saturation_high,                    // 校准舍入结果高于signed 12-bit范围的标志
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 本笔计算绑定的完整ACTIVE配置版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 本笔计算绑定的Stage1系数组版本
	input [8:0]i_detect_code,                   // S1冗余重构后钳位到0至511的检测码
	input [9:0]i_stage1_raw,                    // 与固定结果对齐的完整S1物理决策位
	input signed [10:0]i_stage1_code_ext,       // 未钳位D1_EXT供量程诊断和精细链使用
	input [9:0]i_stage2_raw,                    // 15-bit事务中与S1绑定的第二级物理码
	input i_precision_mode,                     // 低为9-bit事务，高为15-bit事务
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id,   // 同一PPG周期R/IR事务共享的帧标识
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 当前ADC结果在全局数据流中的顺序号
	input i_color_ir,                           // 低表示红光通道，高表示红外通道
	input [1:0]i_frame_type,                    // 00为AMB_CAL、01为DCS_CAL、10为NORMAL
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // 本次模拟积分实际使用的AMB抵消码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 本次颜色积分实际使用的共享DC IDAC码
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // 当前AMB快照对应的安全提交版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // 当前R或IR DC快照对应的提交版本
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // AMI经本笔事务实时广播的当前RUN代际

	//----------下游分支握手输入接口----------//
	input i_amb_cal_ready,                    // AMB控制逻辑允许接收当前校准残差
	input i_dc_cal_ready,                     // 共享DC控制逻辑允许接收当前颜色残差
	input i_normal_ready,                     // 正常PPG数据链允许接收完整测量事务

	//----------上游握手输出接口----------//
	output o_result_ready,                // 当前选中分支可接收或输入为空时允许上游推进

	//----------分支选择输出接口----------//
	output o_amb_cal_valid,               // 仅AMB_CAL事务向环境光控制分支声明有效
	output o_dc_cal_valid,                // 仅DCS_CAL事务向共享DC控制分支声明有效
	output o_normal_valid,                // 仅NORMAL事务向PPG测量分支声明有效
	output o_frame_type_error,            // 有效事务使用保留编码11时给出协议错误电平

	//----------共享事务载荷输出接口----------//
	output signed [11:0]o_calibrated_s1_value, // 各分支消费的正式Stage1校准残差
	output o_calibration_applied,             // 透传本笔事务的校准系数合法资格
	output o_saturation_low,                  // 输出未饱和结果跌破-2048的负向诊断
	output o_saturation_high,                 // 输出未饱和结果超过+2047的正向诊断
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_config_epoch, // 传递本笔事务实际使用的ACTIVE版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_coef_epoch, // 传递本笔事务实际使用的系数组版本
	output [8:0]o_detect_code,                // 各分支按自身valid解释的固定S1黄金残差
	output [9:0]o_stage1_raw,                 // 逐物理位校准和测试导出使用的S1原始码
	output signed [10:0]o_stage1_code_ext,    // 正常精细链使用的未饱和第一级重构结果
	output [9:0]o_stage2_raw,                 // NORMAL高精度事务携带的第二级物理结果
	output o_precision_mode,                  // 保存当前共享载荷所属的9/15-bit精度
	output [C_FRAME_ID_WIDTH - 1:0]o_frame_id, // 透传用于配对R/IR测量的PPG周期编号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_sample_index, // 透传用于检查结果顺序的样本编号
	output o_color_ir,                        // DCS与NORMAL分支用来选择R或IR状态库
	output [1:0]o_frame_type,                 // 保留原始事务类别供波形和故障追踪
	output [C_IDAC_CODE_WIDTH - 1:0]o_amb_code_snapshot, // 传递产生该ADC残差时的AMB实际码
	output [C_IDAC_CODE_WIDTH - 1:0]o_dc_code_snapshot, // 传递产生该ADC残差时的当前颜色DC码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_amb_code_epoch, // 传递AMB调码前后样本区分标识
	output [C_CODE_EPOCH_WIDTH - 1:0]o_dc_code_epoch, // 传递当前颜色DC调码版本标识
	output [C_RUN_GENERATION_WIDTH - 1:0]o_run_generation // 原样透传本笔事务绑定的RUN代际
);

	//-------------配置参数区域-------------//
	// 帧类别编码与S1重构测试平台已经使用的事务合同保持一致
	localparam [1:0] FRAME_TYPE_AMB_CAL = 2'b00; // LED关闭时执行环境光抵消码校准
	localparam [1:0] FRAME_TYPE_DCS_CAL = 2'b01; // 按color_ir更新共享DC控制器的颜色状态
	localparam [1:0] FRAME_TYPE_NORMAL = 2'b10; // 将结果送入正常PPG测量数据链

	//---------------标志信号---------------//
	// 输入valid限定帧类别译码，保证空闲或复位期间没有伪分支事务
	wire flag_frame_amb_cal;                // 当前有效载荷属于AMB校准类别
	wire flag_frame_dcs_cal;                // 当前事务需送往对应颜色直流抵消闭环
	wire flag_frame_normal;                 // 当前有效载荷属于正常PPG类别
	wire flag_frame_type_legal;             // 当前两位类别属于三个已定义编码之一
	wire flag_selected_ready;               // 当前帧类别对应目的分支的接收能力

	//---------------其他信号---------------//

	//---------------输出信号---------------//

	//-------------其他信号连线-------------//
	// 三个类别标志互斥，保留编码11只触发错误而不激活任何功能分支
	assign flag_frame_amb_cal = (i_frame_type == FRAME_TYPE_AMB_CAL); // 识别环境光校准事务编码00
	assign flag_frame_dcs_cal = (i_frame_type == FRAME_TYPE_DCS_CAL); // 识别共享DC校准事务编码01
	assign flag_frame_normal = (i_frame_type == FRAME_TYPE_NORMAL); // 识别正常PPG测量事务编码10
	assign flag_frame_type_legal = flag_frame_amb_cal || flag_frame_dcs_cal || flag_frame_normal; // 汇总三个受支持类别
	assign flag_selected_ready = flag_frame_amb_cal ? i_amb_cal_ready :
		flag_frame_dcs_cal ? i_dc_cal_ready :
		flag_frame_normal ? i_normal_ready : 1'b1; // 非法类别由错误出口直接消费避免死锁

	//-------------输出信号连线-------------//
	// 输入为空时ready保持开放；有效事务只接受被选中分支的反压反馈
	assign o_result_ready = i_rstn && ((i_result_valid == 1'b0) || flag_selected_ready); // 返回唯一目的分支的握手许可
	assign o_amb_cal_valid = i_rstn && i_result_valid && flag_frame_amb_cal; // 将00事务限定到AMB搜索或跟踪逻辑
	assign o_dc_cal_valid = i_rstn && i_result_valid && flag_frame_dcs_cal; // 将01事务交给共享R/IR DC状态控制器
	assign o_normal_valid = i_rstn && i_result_valid && flag_frame_normal; // 将10事务交给后续完整PPG数据链
	assign o_frame_type_error = i_rstn && i_result_valid && (flag_frame_type_legal == 1'b0); // 标记被丢弃的保留类别

	// 校准字段保持上游逐位语义，不在路由器内重新推导资格、饱和或版本关系
	assign o_calibrated_s1_value = i_calibrated_s1_value; // 保持signed 12-bit校准残差的符号和位宽
	assign o_calibration_applied = i_calibration_applied; // 传递本笔系数是否具备正式校准资格
	assign o_saturation_low = i_saturation_low; // 保留校准器给出的负向饱和诊断
	assign o_saturation_high = i_saturation_high; // 保留校准器给出的正向饱和诊断
	assign o_config_epoch = i_config_epoch; // 绑定本笔结果对应的完整配置提交版本
	assign o_coef_epoch = i_coef_epoch;     // 绑定本笔结果对应的Stage1系数组版本

	// 原始观察载荷不增加寄存级，稳定性由上游保持型valid和当前分支ready共同保证
	assign o_detect_code = i_detect_code;   // 向选中分支传递固定钳位残差
	assign o_stage1_raw = i_stage1_raw;     // 保持S1物理位与同一事务valid直接对应
	assign o_stage1_code_ext = i_stage1_code_ext; // 保留D1_EXT符号与过量程边界信息
	assign o_stage2_raw = i_stage2_raw;     // 保持S2码与同一帧元数据的组合对应关系
	assign o_precision_mode = i_precision_mode; // 透传本次转换实际采用的精度模式
	assign o_frame_id = i_frame_id;         // 保持同一心动周期的R/IR配对标识
	assign o_sample_index = i_sample_index; // 保留跨类别ADC事务的严格先后顺序
	assign o_color_ir = i_color_ir;         // 指示共享DC状态或正常数据属于哪种颜色
	assign o_frame_type = i_frame_type;     // 允许下游诊断原始帧类型而不重新推断
	assign o_amb_code_snapshot = i_amb_code_snapshot; // 绑定本次残差所使用的环境光抵消码
	assign o_dc_code_snapshot = i_dc_code_snapshot; // 绑定本次残差所使用的R或IR直流码
	assign o_amb_code_epoch = i_amb_code_epoch; // 传播AMB码安全更新后的版本标签
	assign o_dc_code_epoch = i_dc_code_epoch; // 传播当前颜色DC码的提交代号
	assign o_run_generation = i_run_generation; // 原样透传AMI广播的RUN代际，不做代际比较或丢弃判断

endmodule
