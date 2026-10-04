`timescale 1ns / 1ps

////////////////////////////////////English///////////////////////////////////////
// Company:            Erie
// Engineer:           Erie
//
// Create Date:        2026/08/07
// Design Name:        PPG NORMAL Transaction Fork
// Module Name:        ppg_normal_transaction_fork
// Description:        Description/ppg_normal_transaction_fork_Design.pdf
// Simulations:        TestBench/Vivado/2022.2/ppg_normal_transaction_fork
//
// Referrences:        PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md,
//                     ppg_adc_result_router.v,
//                     ppg_adc_pipeline_overlap_corrector.v
//
// Dependencies:       None
//
// Version:            V2.0
// Revision Date:      2026/08/22
// History:
//    Time               Version       Revised by            Contents
// 2026/08/07            V1.0          Erie                  Create file.
// 2026/08/22            V2.0          Erie                  Add i_run_generation with atomic latching shared by both branches, add the AMI private i_datapath_discard_* generation-scoped flush group, and add o_measurement_run_generation/o_tracking_run_generation/o_local_empty, per PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md section 5.2.
///////////////////////////////////Chinese////////////////////////////////////////
// 版权归属:           Erie
// 开发人员:           Erie
//
// 创建日期:           2026年08月07日
// 设计名称:           PPG NORMAL事务双分支分发器
// 模块名称:           ppg_normal_transaction_fork
// 模块说明:           Description/ppg_normal_transaction_fork_Design.pdf
// 仿真工程:           TestBench/Vivado/2022.2/ppg_normal_transaction_fork
//
// 参考资料:           PPG_NORMAL_FORK_IDAC_TRACKING_AMB_RECHECK_INTERFACE_CONTRACT.md、
//                     ppg_adc_result_router.v、
//                     ppg_adc_pipeline_overlap_corrector.v
//
// 依赖文件:           无
//
// 当前版本:           V2.0
// 修订日期:           2026年08月22日
// 修订历史:
//    时间                版本          修订人                修订内容
// 2026年08月07日        V1.0          Erie                  创建文件
// 2026年08月22日        V2.0          Erie                  按合同5.2节新增i_run_generation（两分支共用同一份锁存代际）、AMI私有i_datapath_discard_*代际清空组，以及o_measurement_run_generation/o_tracking_run_generation/o_local_empty。

// 将一笔NORMAL事务无丢失地复制给测量链和IDAC慢速跟踪链，并分别记录两个分支的消费状态
module ppg_normal_transaction_fork
#(
	parameter integer C_FRAME_ID_WIDTH = 32'd16,                         // R/IR共享PPG周期标识字段位宽
	parameter integer C_SAMPLE_INDEX_WIDTH = 32'd16,                     // 全局ADC事务顺序编号字段位宽
	parameter integer C_IDAC_CODE_WIDTH = 32'd8,                         // AMB与当前颜色DC码快照字段位宽
	parameter integer C_CODE_EPOCH_WIDTH = 32'd4,                        // IDAC安全提交版本标签字段位宽
	parameter integer C_CONFIG_EPOCH_WIDTH = 32'd8,                      // 完整ACTIVE配置版本标签字段位宽
	parameter integer C_COEF_EPOCH_WIDTH = 32'd8,                        // Stage1系数组版本标签字段位宽
	parameter integer C_RUN_GENERATION_WIDTH = 32'd8                    // manager唯一产生、AMI逐层传入的RUN代际字段位宽
)
(
	//---------------全局信号---------------//
	input i_clk,                            // 2 MHz数字处理域工作时钟
	input i_rstn,                           // 低有效异步复位，清除缓存和两个分支所有权
	input [C_RUN_GENERATION_WIDTH - 1:0]i_run_generation, // manager经AMI逐层传入的当前RUN代际

	//---------AMI私有终止释放接口---------//
	input i_datapath_discard_event,        // AMI注册式代际清空事件，无ready/ack
	input [1:0]i_datapath_discard_reason,  // 清空原因分类，取值含STOP排空、abort撤销、系统故障三类
	input i_datapath_discard_identity_valid, // 触发事务身份是否可信
	input [C_FRAME_ID_WIDTH - 1:0]i_datapath_discard_frame_id, // 触发事务帧号，仅诊断用途
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_datapath_discard_sample_index, // 触发事务序号，仅诊断用途
	input i_datapath_discard_color_ir,     // 触发事务颜色，仅诊断用途
	input [1:0]i_datapath_discard_frame_type, // 触发事务类型，仅诊断用途
	input i_datapath_discard_precision,    // 触发事务精度，仅诊断用途
	input [C_RUN_GENERATION_WIDTH - 1:0]i_datapath_discard_run_generation, // 本次清空目标RUN代际

	//----------NORMAL事务输入接口----------//
	input i_normal_valid,                   // router保持当前NORMAL事务直到本模块接纳
	input signed [11:0]i_calibrated_s1_value, // Stage1逐物理位可编程校准后的有符号残差
	input i_calibration_applied,            // 当前残差使用正式有效Stage1系数的资格
	input i_saturation_low,                 // Stage1校准结果触发负向端点保护的诊断
	input i_saturation_high,                // Stage1校准结果触发正向端点保护的诊断
	input [C_CONFIG_EPOCH_WIDTH - 1:0]i_config_epoch, // 本笔事务绑定的完整ACTIVE配置版本
	input [C_COEF_EPOCH_WIDTH - 1:0]i_coef_epoch, // 本笔计算绑定的Stage1系数组版本
	input [8:0]i_detect_code,               // 固定冗余重构器产生的9-bit黄金检测码
	input [9:0]i_stage1_raw,                // 与校准结果对应的十个Stage1物理判决位
	input signed [10:0]i_stage1_code_ext,   // 固定Stage1公式产生的未钳位D1_EXT
	input [9:0]i_stage2_raw,                // 15-bit事务携带的十个Stage2物理判决位
	input i_precision_mode,                 // 低表示9-bit事务，高表示15-bit事务
	input [C_FRAME_ID_WIDTH - 1:0]i_frame_id, // 同一PPG采样帧中R/IR事务的共享编号
	input [C_SAMPLE_INDEX_WIDTH - 1:0]i_sample_index, // 当前ADC事务的全局顺序编号
	input i_color_ir,                       // 低表示红光事务，高表示红外事务
	input [1:0]i_frame_type,                // router已判定的NORMAL类别，合法值为2'b10
	input [C_IDAC_CODE_WIDTH - 1:0]i_amb_code_snapshot, // 本次积分实际使用的AMB抵消码
	input [C_IDAC_CODE_WIDTH - 1:0]i_dc_code_snapshot, // 本次颜色积分实际使用的DC抵消码
	input [C_CODE_EPOCH_WIDTH - 1:0]i_amb_code_epoch, // 当前AMB码快照对应的提交版本
	input [C_CODE_EPOCH_WIDTH - 1:0]i_dc_code_epoch, // 当前颜色DC码快照对应的提交版本
	output o_normal_ready,                  // 缓存为空或旧事务本拍完全释放时允许接纳

	//----------测量分支握手接口----------//
	input i_measurement_ready,            // overlap corrector允许消费完整NORMAL事务
	output o_measurement_valid,           // 测量分支尚未消费当前缓存事务的保持型valid

	//----------测量分支完整载荷----------//
	output signed [11:0]o_measurement_calibrated_s1_value, // 向测量链提供正式Stage1校准残差
	output o_measurement_calibration_applied, // 向后续重构链传递Stage1校准资格
	output o_measurement_saturation_low,  // 保留当前校准值的负向饱和状态
	output o_measurement_saturation_high, // 保留当前校准值的正向饱和状态
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_measurement_config_epoch, // 测量结果对应的ACTIVE配置版本
	output [C_COEF_EPOCH_WIDTH - 1:0]o_measurement_coef_epoch, // 测量结果对应的Stage1系数版本
	output [8:0]o_measurement_detect_code, // 供黄金比较使用的固定9-bit检测结果
	output [9:0]o_measurement_stage1_raw, // 供重构和测试导出的Stage1物理码
	output signed [10:0]o_measurement_stage1_code_ext, // 供标称重构使用的未钳位D1_EXT
	output [9:0]o_measurement_stage2_raw, // 高精度重构所需的Stage2物理码
	output o_measurement_precision_mode,  // 决定测量事务采用粗精度或精细精度
	output [C_FRAME_ID_WIDTH - 1:0]o_measurement_frame_id, // 保持R/IR配对所需的帧编号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_measurement_sample_index, // 保持测量结果的全局顺序
	output o_measurement_color_ir,        // 指示测量载荷属于红光或红外
	output [1:0]o_measurement_frame_type, // 保留NORMAL编码供下游协议诊断
	output [C_IDAC_CODE_WIDTH - 1:0]o_measurement_amb_code_snapshot, // 绑定结果产生时的AMB实际码
	output [C_IDAC_CODE_WIDTH - 1:0]o_measurement_dc_code_snapshot, // 绑定结果产生时的当前颜色DC码
	output [C_CODE_EPOCH_WIDTH - 1:0]o_measurement_amb_code_epoch, // 传递AMB调码前后的版本标签
	output [C_CODE_EPOCH_WIDTH - 1:0]o_measurement_dc_code_epoch, // 传递当前颜色DC码的版本标签
	output [C_RUN_GENERATION_WIDTH - 1:0]o_measurement_run_generation, // 测量分支pending所属的保持型RUN代际

	//----------IDAC跟踪分支接口----------//
	input i_track_ready,                  // IDAC控制器允许接收当前慢速跟踪观察事务
	output o_track_valid,                 // 跟踪分支尚未消费当前缓存事务的保持型valid
	output signed [11:0]o_track_calibrated_s1_value, // IDAC窗口比较使用的唯一主数值
	output o_track_calibration_applied,   // 指示跟踪残差是否具备正式校准资格
	output o_track_saturation_low,        // 为IDAC比较器给出明确的低侧越界方向
	output o_track_saturation_high,       // 为IDAC比较器给出明确的高侧越界方向
	output [C_CONFIG_EPOCH_WIDTH - 1:0]o_track_config_epoch, // 校验事务是否属于当前ACTIVE配置
	output [C_COEF_EPOCH_WIDTH - 1:0]o_track_coef_epoch, // 记录本笔跟踪样本使用的Stage1系数组
	output o_track_precision_mode,        // 保留9/15-bit身份但不分裂IDAC控制状态
	output [C_FRAME_ID_WIDTH - 1:0]o_track_frame_id, // 跟踪诊断使用的R/IR共享帧编号
	output [C_SAMPLE_INDEX_WIDTH - 1:0]o_track_sample_index, // 检查单次消费和样本顺序的编号
	output o_track_color_ir,              // 选择DC_R或DC_IR慢速跟踪状态
	output [1:0]o_track_frame_type,       // 保留NORMAL编码以执行入口资格检查
	output [C_IDAC_CODE_WIDTH - 1:0]o_track_amb_code_snapshot, // 追踪该样本观察到的AMB committed码
	output [C_IDAC_CODE_WIDTH - 1:0]o_track_dc_code_snapshot, // 比较样本码快照与选中DC状态
	output [C_CODE_EPOCH_WIDTH - 1:0]o_track_amb_code_epoch, // 记录环境光抵消码的提交代号
	output [C_CODE_EPOCH_WIDTH - 1:0]o_track_dc_code_epoch, // 拒绝旧DC码样本所需的版本代号
	output [C_RUN_GENERATION_WIDTH - 1:0]o_tracking_run_generation, // 跟踪分支pending所属的保持型RUN代际

	//-------------本地排空观测接口-------------//
	output o_local_empty                        // 测量与跟踪两个分支均无pending时为高，唯一消费者AMI
);

	//-------------配置参数区域-------------//
	// 完整事务从最低位DC epoch开始按接口字段顺序逐段打包
	localparam integer C_DC_CODE_EPOCH_LSB = 32'd0; // 当前颜色DC版本位于载荷最低端
	localparam integer C_AMB_CODE_EPOCH_LSB = C_DC_CODE_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // AMB版本紧随DC版本字段
	localparam integer C_DC_CODE_SNAPSHOT_LSB = C_AMB_CODE_EPOCH_LSB + C_CODE_EPOCH_WIDTH; // DC实际码位于两个epoch之上
	localparam integer C_AMB_CODE_SNAPSHOT_LSB = C_DC_CODE_SNAPSHOT_LSB + C_IDAC_CODE_WIDTH; // AMB实际码紧邻DC快照
	localparam integer C_FRAME_TYPE_LSB = C_AMB_CODE_SNAPSHOT_LSB + C_IDAC_CODE_WIDTH; // 帧类别保留两位协议编码
	localparam integer C_COLOR_IR_LSB = C_FRAME_TYPE_LSB + 32'd2; // 颜色身份位于帧类别字段之上
	localparam integer C_SAMPLE_INDEX_LSB = C_COLOR_IR_LSB + 32'd1; // 全局样本号跟随颜色身份
	localparam integer C_FRAME_ID_LSB = C_SAMPLE_INDEX_LSB + C_SAMPLE_INDEX_WIDTH; // 共享帧号位于两个序号字段上方
	localparam integer C_PRECISION_MODE_LSB = C_FRAME_ID_LSB + C_FRAME_ID_WIDTH; // 精度模式绑定本笔完整事务
	localparam integer C_STAGE2_RAW_LSB = C_PRECISION_MODE_LSB + 32'd1; // Stage2物理码仅由测量分支解释
	localparam integer C_STAGE1_CODE_EXT_LSB = C_STAGE2_RAW_LSB + 32'd10; // 未钳位D1_EXT保留符号位
	localparam integer C_STAGE1_RAW_LSB = C_STAGE1_CODE_EXT_LSB + 32'd11; // 十个Stage1物理位组成独立字段
	localparam integer C_DETECT_CODE_LSB = C_STAGE1_RAW_LSB + 32'd10; // 固定检测码用于标称黄金比较
	localparam integer C_COEF_EPOCH_LSB = C_DETECT_CODE_LSB + 32'd9; // Stage1系数版本置于原始码上方
	localparam integer C_CONFIG_EPOCH_LSB = C_COEF_EPOCH_LSB + C_COEF_EPOCH_WIDTH; // ACTIVE版本与系数版本相邻保存
	localparam integer C_SATURATION_HIGH_LSB = C_CONFIG_EPOCH_LSB + C_CONFIG_EPOCH_WIDTH; // 正向饱和诊断位于版本字段上方
	localparam integer C_SATURATION_LOW_LSB = C_SATURATION_HIGH_LSB + 32'd1; // 负向诊断紧邻正向诊断
	localparam integer C_CALIBRATION_APPLIED_LSB = C_SATURATION_LOW_LSB + 32'd1; // 正式校准资格与饱和属性绑定
	localparam integer C_CALIBRATED_S1_VALUE_LSB = C_CALIBRATION_APPLIED_LSB + 32'd1; // signed Stage1残差占据最高段
	localparam integer C_PAYLOAD_WIDTH = C_CALIBRATED_S1_VALUE_LSB + 32'd12; // 完整NORMAL事务缓存总位宽

	//---------------标志信号---------------//
	// 握手标志显式区分输入接纳、两个分支消费和旧事务完全释放
	wire flag_buffer_occupied;              // 任一分支仍拥有当前事务时缓存处于占用状态
	wire flag_measurement_transfer;         // overlap corrector在当前沿消费测量副本
	wire flag_track_transfer;               // IDAC控制器在当前沿消费跟踪副本
	wire flag_transaction_releasing;        // 当前沿后两个旧pending都将被清除
	wire flag_input_transfer;               // router在当前沿向fork交付新NORMAL事务
	wire flag_discard_apply;                // AMI代际清空事件命中当前缓存代际

	//---------------其他信号---------------//
	// 输入组合载荷只在唯一输入握手沿写入保持寄存器
	wire [C_PAYLOAD_WIDTH - 1:0]payload_input; // 聚合router提供的完整NORMAL字段

	//---------------输出信号---------------//
	// 两个valid分别记录当前事务在对应分支上的未消费所有权
	reg [C_PAYLOAD_WIDTH - 1:0]payload_o;   // 反压期间逐位保持的完整NORMAL事务缓存
	reg measurement_valid_o;                // 测量分支尚待消费当前缓存事务的标志
	reg track_valid_o;                      // IDAC跟踪分支尚待消费当前缓存事务的标志
	reg [C_RUN_GENERATION_WIDTH - 1:0]run_generation_o; // 当前缓存事务建立时刻锁存的RUN代际

	//-------------其他信号连线-------------//
	// 缓存释放判断同时支持两个分支同拍消费和最后一个剩余分支单独消费
	assign flag_buffer_occupied = measurement_valid_o || track_valid_o; // 汇总两个独立分支所有权
	assign flag_measurement_transfer = measurement_valid_o && i_measurement_ready; // 定义测量分支唯一消费事件
	assign flag_track_transfer = track_valid_o && i_track_ready; // 定义跟踪分支唯一消费事件
	assign flag_transaction_releasing = flag_buffer_occupied &&
		((measurement_valid_o == 1'b0) || flag_measurement_transfer) &&
		((track_valid_o == 1'b0) || flag_track_transfer); // 判断旧事务在当前沿后不再被任何分支持有
	assign flag_input_transfer = i_normal_valid && o_normal_ready; // 定义新事务进入单元素缓存的唯一条件
	assign flag_discard_apply = i_datapath_discard_event && (run_generation_o == i_run_generation); // AMI清空事件命中当前持有代际时无条件清除两个分支

	// 全部字段采用一次拼接写入，禁止数值、物理码和元数据跨事务混合
	assign payload_input = {
		i_calibrated_s1_value,
		i_calibration_applied,
		i_saturation_low,
		i_saturation_high,
		i_config_epoch,
		i_coef_epoch,
		i_detect_code,
		i_stage1_raw,
		i_stage1_code_ext,
		i_stage2_raw,
		i_precision_mode,
		i_frame_id,
		i_sample_index,
		i_color_ir,
		i_frame_type,
		i_amb_code_snapshot,
		i_dc_code_snapshot,
		i_amb_code_epoch,
		i_dc_code_epoch
	};                                      // 形成131-bit默认参数下的原子NORMAL载荷

	//-------------输出信号连线-------------//
	// 输入ready允许空缓存装入，也允许旧事务释放与下一笔事务在同一上升沿替换
	assign o_normal_ready = i_rstn && ((flag_buffer_occupied == 1'b0) || flag_transaction_releasing); // 返回router的弹性反压许可
	assign o_measurement_valid = measurement_valid_o; // 桥接测量分支pending状态
	assign o_track_valid = track_valid_o;   // 桥接IDAC跟踪分支pending状态

	// measurement分支逐位解包全部输入字段，直接匹配overlap corrector现有NORMAL接口
	assign o_measurement_calibrated_s1_value = payload_o[C_CALIBRATED_S1_VALUE_LSB +: 12]; // 解包正式Stage1残差
	assign o_measurement_calibration_applied = payload_o[C_CALIBRATION_APPLIED_LSB]; // 解包测量链校准资格
	assign o_measurement_saturation_low = payload_o[C_SATURATION_LOW_LSB]; // 解包负向端点诊断
	assign o_measurement_saturation_high = payload_o[C_SATURATION_HIGH_LSB]; // 解包正向端点诊断
	assign o_measurement_config_epoch = payload_o[C_CONFIG_EPOCH_LSB +: C_CONFIG_EPOCH_WIDTH]; // 解包ACTIVE版本标签
	assign o_measurement_coef_epoch = payload_o[C_COEF_EPOCH_LSB +: C_COEF_EPOCH_WIDTH]; // 解包Stage1系数版本
	assign o_measurement_detect_code = payload_o[C_DETECT_CODE_LSB +: 9]; // 解包固定9-bit黄金码
	assign o_measurement_stage1_raw = payload_o[C_STAGE1_RAW_LSB +: 10]; // 解包Stage1物理判决位
	assign o_measurement_stage1_code_ext = payload_o[C_STAGE1_CODE_EXT_LSB +: 11]; // 解包带符号D1_EXT
	assign o_measurement_stage2_raw = payload_o[C_STAGE2_RAW_LSB +: 10]; // 解包仅15-bit路径解释的尾级物理判决位
	assign o_measurement_precision_mode = payload_o[C_PRECISION_MODE_LSB]; // 解包事务精度快照
	assign o_measurement_frame_id = payload_o[C_FRAME_ID_LSB +: C_FRAME_ID_WIDTH]; // 解包R/IR共享帧号
	assign o_measurement_sample_index = payload_o[C_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH]; // 解包全局样本号
	assign o_measurement_color_ir = payload_o[C_COLOR_IR_LSB]; // 解包红光或红外身份
	assign o_measurement_frame_type = payload_o[C_FRAME_TYPE_LSB +: 2]; // 解包NORMAL类别编码
	assign o_measurement_amb_code_snapshot = payload_o[C_AMB_CODE_SNAPSHOT_LSB +: C_IDAC_CODE_WIDTH]; // 解包AMB实际码
	assign o_measurement_dc_code_snapshot = payload_o[C_DC_CODE_SNAPSHOT_LSB +: C_IDAC_CODE_WIDTH]; // 解包当前颜色DC码
	assign o_measurement_amb_code_epoch = payload_o[C_AMB_CODE_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解包AMB版本
	assign o_measurement_dc_code_epoch = payload_o[C_DC_CODE_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 解包所选颜色DC控制状态的提交版本
	assign o_measurement_run_generation = measurement_valid_o ? run_generation_o : {C_RUN_GENERATION_WIDTH{1'b0}}; // 无pending时强制归零

	// tracking分支只暴露IDAC慢速跟踪资格、比较值和事务身份，不传递Stage2或重构结果
	assign o_track_calibrated_s1_value = payload_o[C_CALIBRATED_S1_VALUE_LSB +: 12]; // 提供IDAC主比较残差，与measurement分支233行共用同一payload_o切片，结构上不存在Stage2/重建/正式输出替代通路 @satisfies: ADCN-10
	assign o_track_calibration_applied = payload_o[C_CALIBRATION_APPLIED_LSB]; // 提供正式跟踪资格
	assign o_track_saturation_low = payload_o[C_SATURATION_LOW_LSB]; // 提供明确低侧越界证据
	assign o_track_saturation_high = payload_o[C_SATURATION_HIGH_LSB]; // 提供明确高侧越界证据
	assign o_track_config_epoch = payload_o[C_CONFIG_EPOCH_LSB +: C_CONFIG_EPOCH_WIDTH]; // 提供ACTIVE一致性版本
	assign o_track_coef_epoch = payload_o[C_COEF_EPOCH_LSB +: C_COEF_EPOCH_WIDTH]; // 提供Stage1校准诊断版本
	assign o_track_precision_mode = payload_o[C_PRECISION_MODE_LSB]; // 提供精度追踪属性
	assign o_track_frame_id = payload_o[C_FRAME_ID_LSB +: C_FRAME_ID_WIDTH]; // 提供PPG帧身份
	assign o_track_sample_index = payload_o[C_SAMPLE_INDEX_LSB +: C_SAMPLE_INDEX_WIDTH]; // 提供事务顺序身份
	assign o_track_color_ir = payload_o[C_COLOR_IR_LSB]; // 选择红光或红外DC状态
	assign o_track_frame_type = payload_o[C_FRAME_TYPE_LSB +: 2]; // 验证跟踪入口只接收NORMAL
	assign o_track_amb_code_snapshot = payload_o[C_AMB_CODE_SNAPSHOT_LSB +: C_IDAC_CODE_WIDTH]; // 提供AMB码一致性快照
	assign o_track_dc_code_snapshot = payload_o[C_DC_CODE_SNAPSHOT_LSB +: C_IDAC_CODE_WIDTH]; // 提供选中颜色DC快照
	assign o_track_amb_code_epoch = payload_o[C_AMB_CODE_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 提供AMB提交版本
	assign o_track_dc_code_epoch = payload_o[C_DC_CODE_EPOCH_LSB +: C_CODE_EPOCH_WIDTH]; // 提供拒绝旧样本的DC版本
	assign o_tracking_run_generation = track_valid_o ? run_generation_o : {C_RUN_GENERATION_WIDTH{1'b0}}; // 跟踪分支释放后不得继续暴露旧代际
	assign o_local_empty = !measurement_valid_o && !track_valid_o; // 两个分支均已释放时报告本地排空

	//-----------输出信号处理区域-----------//
	// 唯一输入握手沿原子锁存全部字段，两个消费者反压时禁止重新观察上游组合总线
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			payload_o <= {C_PAYLOAD_WIDTH{1'b0}}; // 复位清除可能被旧valid解释的历史载荷
		end else if(flag_input_transfer == 1'b1)begin
			payload_o <= payload_input;     // 装入下一笔完整NORMAL事务
		end else begin
			payload_o <= payload_o;         // 无输入接纳时逐位保持当前缓存
		end
	end

	// 新输入优先建立measurement所有权，否则仅在该分支握手或代际清空时清除pending，不受tracking分支释放与否影响 @satisfies: P13
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			measurement_valid_o <= 1'b0;    // 复位禁止测量分支产生伪事务
		end else if(flag_input_transfer == 1'b1)begin
			measurement_valid_o <= 1'b1;    // 每笔新事务都必须由测量链消费一次
		end else if(flag_measurement_transfer == 1'b1 || flag_discard_apply == 1'b1)begin
			measurement_valid_o <= 1'b0;    // 当前测量副本完成或被AMI代际清空后撤销该分支valid
		end else begin
			measurement_valid_o <= measurement_valid_o; // 反压期间保持测量所有权
		end
	end

	// 新输入同步建立tracking所有权，已消费的旧副本不会因另一分支等待而再次出现，不受measurement分支释放与否影响 @satisfies: P13
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			track_valid_o <= 1'b0;          // 复位禁止IDAC入口观察到虚假样本
		end else if(flag_input_transfer == 1'b1)begin
			track_valid_o <= 1'b1;          // 每笔新事务都向跟踪链提供一次副本
		end else if(flag_track_transfer == 1'b1 || flag_discard_apply == 1'b1)begin
			track_valid_o <= 1'b0;          // IDAC握手完成或被AMI代际清空后清除独立tracking pending
		end else begin
			track_valid_o <= track_valid_o; // IDAC有限反压期间维持valid不变
		end
	end

	// 唯一输入握手沿原子锁存本笔事务所属的RUN代际，供两个分支各自的过期释放判断共用
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			run_generation_o <= {C_RUN_GENERATION_WIDTH{1'b0}}; // 复位清除历史代际快照
		end else if(flag_input_transfer == 1'b1)begin
			run_generation_o <= i_run_generation; // 新事务装入时锁存当前RUN代际
		end else begin
			run_generation_o <= run_generation_o; // 无新事务时保持已锁存代际
		end
	end

endmodule
