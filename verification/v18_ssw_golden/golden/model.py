"""V18 独立黄金：只读取四个获准模板，绝不读取 SSW 实现或实际波形。"""

from __future__ import annotations

import ast
import csv
import hashlib
import json
import re
from pathlib import Path

# 端口字典来自 C09 §7；顺序同时定义驱动文件的打包布局。
INPUTS = [
    ("i_rstn", 1, "低有效复位使所有数字预约失效"),
    ("i_run_enable", 1, "运行期间允许受控事务"),
    ("i_start_ack_event", 1, "新运行确认清除历史残留"),
    ("i_stop_ack_event", 1, "停止确认阻止后续接管"),
    ("i_control_abort_event", 1, "立即撤销尚未完成的波形"),
    ("i_diag_clear_event", 1, "安全空闲时请求清历史诊断"),
    ("i_run_generation", 8, "唯一运行代际绑定释放身份"),
    ("i_macro_tick", 13, "外部宏帧物理相位从零到四千九百九十九"),
    ("i_calibration_subframe_index", 3, "快速校准当前子帧编号"),
    ("i_calibration_local_tick", 10, "子帧局部相位从零到六百二十四"),
    ("i_normal_frame_active", 1, "声明本宏帧属于正常测量"),
    ("i_calibration_frame_active", 1, "声明当前快速校准宏帧"),
    ("i_macro_frame_safe_boundary", 1, "宏帧末尾安全点接管精度"),
    ("i_idac_code_safe_boundary", 1, "候选码仅在规定边界提交"),
    ("i_run_profile", 1, "选择普通运行或表征运行资格"),
    ("i_input_source", 1, "光电二极管与固定电流的源选择"),
    ("i_optical_mode", 2, "配置红光红外或双光测量数量"),
    ("i_precision_mode_committed", 1, "安全边界已提交的转换精度"),
    ("i_static_characterization_enable", 1, "独立静态偏置覆盖使能"),
    ("i_test_mux_ctrl", 5, "经CDC原子提交的五位测试选择"),
    ("i_waveform_context_valid", 1, "完整模拟上下文载荷有效"),
    ("i_waveform_precision_mode", 1, "接管波形的精度快照"),
    ("i_waveform_frame_id", 16, "波形槽归属的物理帧身份"),
    ("i_waveform_color_ir", 1, "模拟槽使用的颜色身份"),
    ("i_waveform_frame_type", 2, "模拟预约的正常或校准类型"),
    ("i_waveform_amb_code_snapshot", 8, "预热前锁存环境光抵消码"),
    ("i_waveform_dc_code_snapshot", 8, "预热前冻结当前色直流码"),
    ("i_waveform_amb_code_epoch", 4, "环境光快照的码版本"),
    ("i_waveform_dc_code_epoch", 4, "当前颜色直流快照版本"),
    ("i_waveform_input_source", 1, "本次模拟解释的输入源快照"),
    ("i_waveform_optical_mode", 2, "本帧颜色组合的冻结解释"),
    ("i_waveform_leddac_code_snapshot", 8, "本次光路已提交电流码"),
    ("i_adc_owner_commit_event", 1, "与模拟ADC接纳同拍提交结果身份"),
    ("i_adc_owner_precision_mode", 1, "结果事务精度须匹配波形预约"),
    ("i_adc_owner_frame_id", 16, "提交结果所有者的帧号"),
    ("i_adc_owner_color_ir", 1, "结果所有权绑定红或红外"),
    ("i_adc_owner_frame_type", 2, "结果接纳对应的校准类别"),
    ("i_adc_owner_amb_code_snapshot", 8, "所有者携带环境光码副本"),
    ("i_adc_owner_dc_code_snapshot", 8, "结果身份附带直流码副本"),
    ("i_adc_owner_amb_code_epoch", 4, "结果侧环境光码版本核对"),
    ("i_adc_owner_dc_code_epoch", 4, "结果侧颜色码版本核对"),
    ("i_adc_owner_sample_index", 16, "仅真实提交时分配采样序号"),
    ("i_adc_transaction_complete_event", 1, "行为ADC数字链给出完成旁带"),
    ("i_adc_transaction_success", 1, "完成资格为零仍允许释放"),
    ("i_adc_complete_sample_index", 16, "完成链返回原始事务序号"),
    ("i_adc_transaction_lost_event", 1, "超时作废与正常完成互斥"),
    ("i_adc_idle", 1, "物理转换及返回链均已空闲"),
    ("i_test_inject_enable", 1, "生产默认关闭的验证注入开关"),
    ("i_context_handover_stall_request", 1, "不使用上下文反压注入"),
]

OUTPUTS = [
    ("o_en_tia_low", 1, "TIA原始逻辑控制"),
    ("o_leddac", 8, "LED电流数值总线"),
    ("o_leden1_low", 1, "红光发射采样窗口"),
    ("o_leden2_low", 1, "红外发射采样窗口"),
    ("o_en_test", 1, "外部测试电流源资格"),
    ("o_clk_buf_low", 1, "静态偏置缓冲控制"),
    ("o_clk_2m", 1, "原始主时钟同相转发"),
    ("o_clk_iref_idac_low", 1, "局部参考电流预建立"),
    ("o_clk_9q1_low", 1, "九位路径第一采样相"),
    ("o_clk_15q1_low", 1, "十五位路径第一采样相"),
    ("o_clk_aferst_low", 1, "模拟前端复位时序"),
    ("o_clk_iref_idac_sar9_low", 1, "九位参考长包络时钟"),
    ("o_clk_iref_idac_sar15_low", 1, "十五位参考长包络时钟"),
    ("o_clk_q2_low", 1, "环境光扣除第二积分相"),
    ("o_clk_q3_low", 1, "颜色采样固定中心相位"),
    ("o_clk_tiaen_low", 1, "局部跨阻放大器门控"),
    ("o_en_15sar_low", 1, "转换器十五位选择电平"),
    ("o_en_sar9_amb_low", 1, "九位环境光抵消支路开通"),
    ("o_en_sar9_dc_low", 1, "九位直流抵消支路开通"),
    ("o_en_sar9_iref", 1, "九位参考源独立使能"),
    ("o_en_sar15_amb_low", 1, "十五位环境光抵消资格"),
    ("o_en_sar15_dc_low", 1, "十五位直流抵消资格"),
    ("o_en_sar15_iref", 1, "十五位参考源保持许可"),
    ("o_idac_sar9ambn_low", 8, "九位环境光逐位快照码"),
    ("o_idac_sar9dcn_low", 8, "九位颜色逐位直流码"),
    ("o_idac_sar15ambn_low", 8, "十五位环境光数值载荷"),
    ("o_idac_sar15dcn_low", 8, "十五位颜色直流数值载荷"),
    ("o_s_in", 5, "静态测试开关原子向量"),
]

STATUS = [
    ("o_waveform_context_ready", 1, "固定点模拟通道接管资格"),
    ("o_adc_owner_ready", 1, "最早待提交结果预约资格"),
    ("o_adc_owner_inflight", 1, "等待真实完成的所有者存在"),
    ("o_owner_deadline_timeout_sticky", 1, "截止抑制历史诊断"),
    ("o_switch_protocol_error_sticky", 1, "阻断协议错误历史记录"),
    ("o_transaction_mismatch_sticky", 1, "完成身份无法归属记录"),
    ("o_calibration_timeout_sticky", 1, "校准读出迟到非阻断记录"),
    ("o_wrapper_fault_blocking", 1, "当前阻断根因汇总"),
    ("o_analog_safe", 1, "模拟时序向量可停止事实"),
    ("o_sar_timing_idle", 1, "波形及切换已经结束"),
    ("o_wrapper_idle", 1, "时序数字身份物理链均空闲"),
    ("o_precision_active", 1, "实际驱动的转换精度状态"),
    ("o_owner_q3_window_closed", 1, "本所有者的采样窗口已关闭"),
]

AMB_WINDOWS = {
    "o_clk_iref_idac_sar9_low": (10, 284), "o_en_sar9_iref": (202, 274),
    "o_en_sar9_amb_low": (222, 276), "o_idac_sar9ambn_low": (224, 276),
    "o_clk_iref_idac_low": (229, 269), "o_clk_aferst_low": (249, 261),
    "o_clk_tiaen_low": (249, 269), "o_en_tia_low": (249, 269), "o_clk_9q1_low": (259, 268),
    "o_clk_q3_low": (265, 267),
}
STATIC_ONES = {
    "o_en_test", "o_clk_buf_low", "o_clk_iref_idac_low",
    "o_clk_iref_idac_sar9_low", "o_clk_iref_idac_sar15_low",
    "o_clk_aferst_low", "o_clk_tiaen_low", "o_en_sar9_amb_low",
    "o_en_sar9_dc_low", "o_en_sar15_amb_low", "o_en_sar15_dc_low",
}
SAMPLING = {"o_clk_9q1_low", "o_clk_15q1_low", "o_clk_q2_low", "o_clk_q3_low",
            "o_leden1_low", "o_leden2_low", "o_en_tia_low", "o_clk_aferst_low", "o_clk_tiaen_low"}


def _arithmetic(expression: str, values: dict[str, int]) -> int:
    """只求值模板 localparam 中的整数加减，不执行任意 Verilog 或 Python。"""
    converted = re.sub(r"\d+'d(\d+)", r"\1", expression.strip())
    tree = ast.parse(converted, mode="eval").body

    def visit(node: ast.AST) -> int:
        if isinstance(node, ast.Constant) and type(node.value) is int:
            return node.value
        if isinstance(node, ast.Name):
            return values[node.id]
        if isinstance(node, ast.BinOp) and isinstance(node.op, (ast.Add, ast.Sub)):
            left, right = visit(node.left), visit(node.right)
            return left + right if isinstance(node.op, ast.Add) else left - right
        raise ValueError(f"不支持的窗口整数表达式: {expression}")

    return visit(tree)


def load_windows(sar9_path: Path, sar15_path: Path) -> tuple[dict, dict]:
    """提取用户确认的模板窗口，拒绝 SSW 路径与任意目录扫描。"""
    profiles, provenance = {}, {}
    for precision, path in enumerate((sar9_path, sar15_path)):
        if "safe_selection_wrapper" in str(path).lower():
            raise ValueError("黄金来源禁止指向 SSW")
        source = path.read_text(encoding="utf-8-sig")
        params = {"C_FRAME_TICKS": 5000}
        for name, expression in re.findall(r"localparam\s+(?:\[[^]]+\]|integer)\s+(\w+)\s*=\s*([^;]+);", source):
            try:
                params[name] = _arithmetic(expression, params)
            except (KeyError, ValueError, SyntaxError):
                continue  # 控制向量位号不参与窗口翻译。
        center = params["R_Q3_CENTER_TICK"] if precision == 0 else (
            params["R_LED_START"] + params["R_LED_END"]) // 2
        mapping = {
            "o_en_tia_low": ("R_EN_TIA_START" if precision == 0 else None, "R_EN_TIA_END"),
            "o_clk_tiaen_low": ("R_EN_TIA_START" if precision == 0 else None, "R_EN_TIA_END"),
            "o_clk_aferst_low": ("R_AFERST_START" if precision == 0 else None, "R_AFERST_END"),
            "o_clk_9q1_low" if precision == 0 else "o_clk_15q1_low": ("R_Q1_START", "R_Q1_END"),
            "o_clk_q2_low": ("R_Q2_START", "R_Q2_END"),
            "o_clk_q3_low": ("R_LED_START", "R_LED_END"),
            "o_leddac": ("R_LED_CODE_START", "R_LED_CODE_END"),
            "o_leden1_low": ("R_LED_START", "R_LED_END"),
            "o_clk_iref_idac_low": ("R_IDAC_CLOCK_START", "R_IDAC_CLOCK_END"),
        }
        if precision == 0:
            mapping.update({
                "o_clk_iref_idac_sar9_low": ("R_SAR9_IREF_START", "R_SAR9_IREF_END"),
                "o_en_sar9_iref": ("R_ENABLE_IREF_START", "R_ENABLE_IREF_END"),
                "o_en_sar9_amb_low": ("R_ENABLE_CODE_START", "R_ENABLE_CODE_END"),
                "o_en_sar9_dc_low": ("R_ENABLE_CODE_START", "R_ENABLE_CODE_END"),
                "o_idac_sar9ambn_low": ("R_IDAC_AMB_START", "R_IDAC_AMB_END"),
                "o_idac_sar9dcn_low": ("R_IDAC_DC_START", "R_IDAC_DC_END"),
            })
        else:
            mapping.update({
                "o_clk_iref_idac_sar15_low": ("R_SHARED_IREF_START", "R_SHARED_CONTROL_END"),
                "o_en_sar15_iref": ("R_SHARED_IREF_START", "R_SHARED_IREF_END"),
                "o_en_sar15_amb_low": ("R_SHARED_ENABLE_START", "R_SHARED_CONTROL_END"),
                "o_en_sar15_dc_low": ("R_SHARED_ENABLE_START", "R_SHARED_CONTROL_END"),
                "o_idac_sar15ambn_low": ("R_IDAC_AMB_START", "R_IDAC_CODE_END"),
                "o_idac_sar15dcn_low": ("R_IDAC_DC_START", "R_IDAC_CODE_END"),
            })
        windows = {}
        for signal, (start_name, end_name) in mapping.items():
            start = params[start_name] if start_name else 0
            end = params[end_name]
            start = start - 5000 if start > end else start
            windows[signal] = (start - center, end - center)
        envelope = (min(start for start, _ in windows.values()), max(end for _, end in windows.values()))
        assert envelope == ((-256, 18) if precision == 0 else (-273, 8)), envelope
        profiles[precision] = windows
        provenance[str(precision)] = {"path": str(path), "sha256": hashlib.sha256(source.encode()).hexdigest(),
                                     "center": center, "parameters": params, "mapping": mapping,
                                     "windows": windows, "envelope": envelope}
    return profiles, provenance


def pack_input(values: dict[str, int]) -> str:
    """按合同字典将一拍全部输入打包；越界数值直接拒绝。"""
    packed = 0
    for name, width, _ in INPUTS:
        value = values.get(name, 0)
        if not 0 <= value < (1 << width):
            raise ValueError(f"端口越界: {name}={value}")
        packed = (packed << width) | value
    return f"{packed:0{(sum(width for _, width, _ in INPUTS) + 3) // 4}x}"


def contexts_for(scenario: dict) -> list[dict]:
    """场景产生预约、提交和行为ADC完成的明确日程；不观察DUT来拟合日程。"""
    contexts = []
    for frame, precision in enumerate(scenario.get("precisions", [scenario.get("precision", 0)])):
        if scenario.get("static"):
            continue
        kind = scenario.get("frame_type", 2)
        colors = ([0, 1] if scenario.get("optical_mode", 0) == 0 else
                  [0] if scenario.get("optical_mode", 0) == 1 else [1]) if kind == 2 else [scenario.get("color", 0)]
        for sub in range(8 if kind != 2 else 1):
            for color in colors:
                base = frame * 5000 + (sub * 625 if kind != 2 else 0)
                fire = base + (160 if color and kind == 2 else 0)
                deadline = base + (scenario.get("normal_ir_owner_deadline", 443) if color and kind == 2 else
                                   scenario.get("normal_red_owner_deadline", 283) if kind == 2 else 248)
                owner = deadline if scenario.get("owner_at_deadline") else base + (
                    scenario.get("ir_owner_tick", 350) if color and kind == 2 else scenario.get("owner_tick", 1))
                miss = scenario.get("miss_owner") == ("cal" if kind != 2 else "ir" if color else "red")
                pattern = scenario.get("patterns", [165, 90, 0, 255])[(frame + sub) % 4]
                context = dict(frame=frame + 1, sub=sub, precision=precision, color=color, kind=kind,
                               fire=fire, owner=None if miss or owner > deadline else owner,
                               requested_owner=owner, deadline=deadline,
                               done=base + (scenario.get("ir_done_tick", 510) if color and kind == 2 else
                                            scenario.get("done_tick", 335)),
                               center=base + (266 if kind != 2 else 460 if color else 300),
                               amb=pattern, dc=scenario.get("ir_dc_patterns" if color else "dc_patterns",
                                                           [255 ^ pattern] * 4)[(frame + sub) % 4] if kind != 0 else 0,
                               led=scenario.get("ir_led_patterns" if color else "led_patterns",
                                                [90 if color else 165] * 4)[(frame + sub) % 4],
                               epoch=(frame + sub) % 16, sample=0)
                contexts.append(context)
    # C08 §7.2：只有真正提交的owner消耗序号；截止失败不能跳号。
    next_sample = 1
    for context in contexts:
        if context["owner"] is not None and all(scenario.get(action) is None or
                                                context["owner"] < scenario[action]
                                                for action in ("stop_tick", "abort_tick")):
            context["sample"] = next_sample
            next_sample += 1
    return contexts


def _identity(values: dict, prefix: str, context: dict) -> None:
    """波形和结果通道从相同冻结载荷赋值，保持接口身份原子一致。"""
    fields = {"precision_mode": "precision", "frame_id": "frame", "color_ir": "color",
              "frame_type": "kind", "amb_code_snapshot": "amb", "dc_code_snapshot": "dc",
              "amb_code_epoch": "epoch", "dc_code_epoch": "epoch"}
    values.update({prefix + name: context[key] for name, key in fields.items()})


def generate(scenario: dict, profiles: dict, directory: Path) -> dict:
    """同时产生协议刺激与独立期望；不依赖仿真是否成功或任何实际输出。"""
    directory.mkdir(parents=True, exist_ok=True)
    contexts = contexts_for(scenario)
    precisions = scenario.get("precisions", [scenario.get("precision", 0)])
    count = 5000 * len(precisions)
    stop = scenario.get("stop_tick")
    abort = scenario.get("abort_tick")
    names = [name for name, _, _ in OUTPUTS]
    active = []
    physical = None
    scheduled = []
    input_rows, golden_rows = [], []
    uncertainty = {}
    for tick in range(-8, count):
        frame = max(0, tick // 5000)
        macro = tick % 5000 if tick >= 0 else 4760
        local = macro % 625
        kind = scenario.get("frame_type", 2)
        precision = precisions[frame]
        committed = precisions[frame + 1] if macro >= 4760 and frame + 1 < len(precisions) else precision
        values = {name: 0 for name, _, _ in INPUTS}
        values.update(i_rstn=int(tick >= -4), i_run_enable=int(tick >= -4),
                      i_start_ack_event=int(tick == -4), i_run_generation=1,
                      i_macro_tick=macro, i_calibration_local_tick=local,
                      i_calibration_subframe_index=macro // 625,
                      i_macro_frame_safe_boundary=int(macro == 4760 and tick >= -4),
                      i_idac_code_safe_boundary=int((local == 385 if kind != 2 else macro == 4760) and tick >= 0),
                      i_run_profile=int(scenario.get("characterization", False)),
                      i_input_source=scenario.get("input_source", 0),
                      i_optical_mode=scenario.get("optical_mode", 0),
                      i_precision_mode_committed=committed,
                      i_static_characterization_enable=int(scenario.get("static", False)),
                      i_test_mux_ctrl=21 if macro < 100 else 10,
                      i_normal_frame_active=int(tick >= 0 and kind == 2 and not scenario.get("static")),
                      i_calibration_frame_active=int(tick >= 0 and kind != 2))
        if stop is not None and tick == stop:
            values["i_stop_ack_event"] = 1
            # 用户最新确认（10-10）：保留已接管槽的预建立；未提交owner的采样整槽关闭。
            # 不撤销active，且后续禁止新提交；eligible按实际提交资格独立抑制采样输出。
        if abort is not None and tick == abort:
            values["i_control_abort_event"] = 1
            active.clear()
        canceled = (stop is not None and tick >= stop) or (abort is not None and tick >= abort)
        if canceled:
            # C08 §8.2.4：STOP/abort后不再发候选提交安全脉冲。
            values["i_idac_code_safe_boundary"] = 0
        for context in contexts:
            if context["fire"] == tick and not canceled:
                values["i_waveform_context_valid"] = 1
                _identity(values, "i_waveform_", context)
                values.update(i_waveform_input_source=scenario.get("input_source", 0),
                              i_waveform_optical_mode=scenario.get("optical_mode", 0),
                              i_waveform_leddac_code_snapshot=context["led"])
                active.append(context)
            if context["owner"] == tick and not canceled:
                if physical is not None:
                    raise ValueError("场景日程违反单owner约束")
                values["i_adc_owner_commit_event"] = 1
                _identity(values, "i_adc_owner_", context)
                values["i_adc_owner_sample_index"] = context["sample"]
                physical = context
                scheduled.append(context)
        for context in scheduled:
            if context["done"] == tick:
                values.update(i_adc_transaction_complete_event=1,
                              i_adc_transaction_success=int(not canceled),
                              i_adc_complete_sample_index=context["sample"])
                physical = None
        if scenario.get("perturb_payload") and tick >= 50 and not values["i_waveform_context_valid"]:
            # 无valid的实时载荷允许改变，已锁存码值和epoch必须继续独立解释。
            values.update(i_waveform_amb_code_snapshot=255, i_waveform_dc_code_snapshot=0,
                          i_waveform_leddac_code_snapshot=17, i_waveform_amb_code_epoch=15,
                          i_waveform_dc_code_epoch=14)
        values["i_adc_idle"] = int(physical is None)
        if stop is not None and tick > stop and physical is None:
            safe_end = max((context["center"] + (18 if not context["precision"] else 8)
                            for context in active), default=stop)
            if scenario.get("config_after_slot_end"):
                # 保持RUN至预约末沿，避免外部强制回CONFIG掩盖待提交槽的STOP边界行为。
                safe_end = max(safe_end, max((context["center"] + (18 if not context["precision"] else 8)
                                             for context in contexts if context["fire"] < stop), default=stop))
            owner_end = max((context["done"] for context in scheduled), default=stop)
            if tick >= max(safe_end, owner_end, stop) + 2:
                # 行为manager在包络结束且ADC空闲后返回CONFIG，不引入新预约。
                values.update(i_run_enable=0, i_normal_frame_active=0, i_calibration_frame_active=0)
        input_rows.append(pack_input(values))
        expected = {name: 0 for name in names}
        expected["o_clk_2m"] = 1
        if tick >= 0:
            expected["o_en_test"] = scenario.get("input_source", 0)
            # 用户确认（10-10）Q02：选择电平跟随已提交精度，不限于包络。
            # 刺激在低相提交，CSV在随后注册边沿之后采样，已包含输出寄存捕获延迟。
            expected["o_en_15sar_low"] = int(kind == 2 and not scenario.get("static") and
                                             values["i_run_enable"] and committed)
            if scenario.get("static"):
                expected.update({name: 1 for name in STATIC_ONES})
                expected["o_s_in"] = values["i_test_mux_ctrl"]
            elif abort is None or tick < abort:
                for context in active:
                    relative = tick - context["center"]
                    windows = AMB_WINDOWS if kind == 0 else profiles[context["precision"]]
                    for name, (start, end) in windows.items():
                        point = tick - (context["fire"]) if kind == 0 else relative
                        if not start <= point < end:
                            continue
                        dest = "o_leden2_low" if name == "o_leden1_low" and context["color"] else name
                        value = context["amb"] if "ambn" in name else context["dc"] if "dcn" in name else context["led"] if name == "o_leddac" else 1
                        # 用户确认（10-10）Q06：采样相关窗口必须完整或整槽关闭。
                        # 黄金按整槽的按时提交资格定义完整窗口，不能逐拍接owner截短模板。
                        eligible = context["sample"] != 0 and context["owner"] is not None and context["owner"] <= context["deadline"]
                        if dest in SAMPLING and not eligible:
                            value = 0
                        if name == "o_leddac" and not eligible:
                            value = 0  # 用户确认（10-10）Q03：无owner采样抑制也清LEDDAC。
                        if scenario.get("input_source") and dest in {"o_leddac", "o_leden1_low", "o_leden2_low"}:
                            value = 0
                        if expected[dest] is not None:
                            expected[dest] = None if value is None else expected[dest] | value
            if abort is not None and tick >= abort:
                expected["o_en_15sar_low"] = 0  # C09 §8.3活动核disable安全向量。
        for name, value in expected.items():
            if value is None:
                uncertainty[name] = uncertainty.get(name, 0) + 1
        golden_rows.append(dict(row=tick + 8, tick=tick, macro_tick=macro, local_tick=local, **expected))
    (directory / "stimulus.hex").write_text("\n".join(input_rows) + "\n", encoding="ascii")
    with (directory / "expected.csv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(golden_rows[0]))
        writer.writeheader()
        writer.writerows(golden_rows)
    metadata = dict(scenario=scenario, rows=len(golden_rows), contexts=contexts, unknown_by_signal=uncertainty,
                    sources="C09 and allowed timing templates only; no DUT feedback")
    (directory / "metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    return metadata
