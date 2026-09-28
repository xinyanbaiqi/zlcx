#!/usr/bin/env python3
"""PPG Item 4b Phase 3：白名单IP识别 + 手搓跨域结构性判定。

背景与依据：完整规划见 `C:\\Users\\d\\.claude\\plans\\ppg-item4b-cdc-ledger-plan.md` "Phase 3 ——
白名单IP识别 + 手搓跨域结构性判定"一节。本脚本直接复用 Phase 1
（`cdc_domain_reachability_tagger.py`，域解析/可达例化树/`_async`信号标注）与 Phase 2
（`cdc_cross_domain_read_candidate_detector.py`，真实跨域读取候选、分支门控分类器）已经验证过的
基础设施，不重新实现例化展开或域解析——见 memory
`project-ppg-item4b-phase1-cdc-domain-tagging-20260914.md`、
`project-ppg-item4b-phase2-cdc-cross-domain-read-candidates-20260915.md`。

Phase 3 的任务：把 Phase 2 产出的候选分成"经过已验证安全 IP"和"手搓跨域"两类，对手搓的做结构性
安全判定；三类 CDC 机制（单 bit 事件/复位释放/多 bit 总线）各自独立判据，不混用。

## 三类判据（严格对应规划文字，不混用）

1. **Class 1（单 bit 事件）**：目标域是否至少 2 级同步（1 级只隔离亚稳态不够）。判据实现为
   `build_bare_driver_map` + `compute_sync_depth_forward`/`compute_inbound_depth`——在同一模块内
   扫描全部 `always` 块，抽取形如 `X <= Y;` 的"裸寄存器到寄存器"单跳赋值（排除自持
   `X <= X` 与复位常量赋值，这两类天然不匹配裸赋值正则），构成一张"目标寄存器 -> 唯一驱动源"表；
   沿这张表数经过多少级寄存器才能从跨域/异步源头走到某个信号，深度 >= 2 即认为安全。
2. **Class 2（复位释放）**：两种安全形态都要认——(a) 标准 `ppg_reset_sync` 白名单实例（2FF 释放
   同步）；(b) 借用已同步的常跑域复位、异步喂入间歇域，且该 assign 附带的注释文本包含"借用"+
   "已同步/已稳定/空闲"这类文档化理由关键词（对照 `ppg_chip_digital_top.v` V1.1 真实先例，见脚本
   `check_class2_borrowed_reset`）。只认 (a) 会把本项目自己真实、已文档化的安全设计误判成风险。
3. **Class 3（多 bit 总线）**：目标寄存器位宽（从 `formatter_ast` 的 `"width"` 字段拿，非空字符串
   即多 bit）+ 采样是否被独立条件门控（沿用 Phase 2 已经产出的 `gated` 字段）。无门控 = 高风险；
   有门控则进一步定位门控分支头，抽取门控条件里的信号名，逐个核查：该信号是否本身是白名单 IP
   实例的输出端口连线，或者本身在同一模块内已经过 >= 2 级寄存器同步——避免"门控信号本身也是没
   保护的手搓跨域"这种二次陷阱，也避免"表面有门控就直接放行"这种假阳性。

## 白名单自洽性检查（规划要求 #1，不是走过场）

`ppg_pulse_cdc_sync`/`ppg_config_cdc_bridge`/`ppg_reset_sync` 三个文件本身就是"安全 CDC 机制"的
定义来源；Phase 2 已经把它们整体排除在跨域读取候选扫描之外（见该脚本 docstring）。但排除本身不能
代替证明——如果 Phase 3 这里写的结构性判据是对的，那么把它们自己的内部同步链单独喂给同一套判据
函数（不走"白名单直接放行"这条捷径），应该也能得出"安全"结论，而不是需要靠"这是白名单"这句话
兜底。`run_whitelist_self_consistency_check` 就是做这件事：对 `ppg_pulse_cdc_sync` 自己的
`flag_source_toggle -> flag_dest_sync_meta -> flag_dest_sync_stable` 链跑 Class 1 判据、对
`ppg_config_cdc_bridge` 自己的门控捕获（`destination_config_o <= reg_source_config`，门控条件是
两个内部寄存器的代际比较，不是连到另一个白名单 IP 的连线）跑 Class 3 判据，确认两者都独立得出
"安全"结论。`ppg_reset_sync` 本身就是 Class 2(a) 的定义来源，不需要二次判定，自洽性平凡成立。

用法：
    python cdc_handrolled_class_classifier.py [--json PATH] [--markdown PATH]
    python cdc_handrolled_class_classifier.py --selftest
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

PATH_PROJECT_ROOT = Path(__file__).resolve().parents[2]  # PPG 项目根目录
PATH_SKILL_ROOT = Path(r"C:\Users\d\.claude\skills\erie-verilog-generator")  # skill 根目录
PATH_SELF_DIR = Path(__file__).resolve().parent  # 本脚本所在目录

for _path_to_add in (str(PATH_SELF_DIR), str(PATH_SKILL_ROOT)):
    if _path_to_add not in sys.path:
        sys.path.insert(0, _path_to_add)

# Phase 1/2 工具作为唯一的域解析/候选检测入口复用，不重新实现例化树展开或候选检测逻辑。
import cdc_domain_reachability_tagger as mod_phase1  # noqa: E402
import cdc_cross_domain_read_candidate_detector as mod_phase2  # noqa: E402

from scripts.python.quality.formatter_ast import build_ast_report_for_path  # noqa: E402


# ---------------------------------------------------------------------------
# 常量
# ---------------------------------------------------------------------------

SET_WHITELIST_IP_MODULES: frozenset[str] = mod_phase2.SET_WHITELIST_IP_MODULES

CLASS_1 = "1"
CLASS_2A = "2a"
CLASS_2B = "2b"
CLASS_3A = "3a"
CLASS_3_HIGH_RISK = "3"

VERDICT_SAFE = "SAFE"
VERDICT_SAFE_GATED_CAPTURE = "SAFE_GATED_CAPTURE"
VERDICT_SAFE_IP_VERIFIED = "SAFE_IP_VERIFIED"
VERDICT_SAFE_DOCUMENTED_BORROW = "SAFE_DOCUMENTED_BORROW"
VERDICT_HIGH_RISK = "HIGH_RISK"
VERDICT_HIGH_RISK_UNVERIFIED_GATE = "HIGH_RISK_UNVERIFIED_GATE"
VERDICT_HIGH_RISK_SINGLE_STAGE = "HIGH_RISK_SINGLE_STAGE"
VERDICT_UNVERIFIED_RESET_BORROW = "UNVERIFIED_RESET_BORROW"


# ---------------------------------------------------------------------------
# 基础工具：位宽查询、逐行定位（复用 formatter_ast 已解析出的字段，不新写第二套 parser）
# ---------------------------------------------------------------------------


def get_decl_width(dict_module_ast: dict[str, Any], str_signal_name: str) -> str:
    """从 `decls`/`ports` 里按名字查位宽字段；空字符串代表 1-bit（含未找到的情况）。"""
    for dict_decl in dict_module_ast.get("decls", []) or []:
        if dict_decl.get("name") == str_signal_name:
            return dict_decl.get("width", "") or ""
    for dict_port in dict_module_ast.get("ports", []) or []:
        if dict_port.get("name") == str_signal_name:
            return dict_port.get("width", "") or ""
    return ""


def get_output_port_names(dict_module_ast: dict[str, Any]) -> set[str]:
    return {
        dict_port.get("name")
        for dict_port in dict_module_ast.get("ports", []) or []
        if dict_port.get("direction") == "output" and dict_port.get("name")
    }


def find_always_by_line_start(dict_module_ast: dict[str, Any], int_line_start: int | None) -> dict[str, Any] | None:
    if int_line_start is None:
        return None
    for dict_always in dict_module_ast.get("always", []) or []:
        if dict_always.get("line_start") == int_line_start:
            return dict_always
    return None


def find_line_index(list_lines: list[str], str_needle: str) -> int | None:
    """按包含关系定位证据行在 `lines` 里的下标（同行可能带 Phase2 未记录的行内注释尾巴）。"""
    str_needle_stripped = str_needle.strip()
    for int_idx, str_line in enumerate(list_lines):
        if str_needle_stripped in str_line or str_line.strip() == str_needle_stripped:
            return int_idx
    return None


# ---------------------------------------------------------------------------
# 白名单 IP 输出连线追溯：本模块内例化的白名单 IP，其输出端口连到了哪个本地信号名
# ---------------------------------------------------------------------------


def build_local_wire_to_whitelist_ip_output(
    dict_module_ast: dict[str, Any],
    dict_whitelist_module_asts: dict[str, dict[str, Any]],
) -> dict[str, dict[str, str]]:
    """扫描 `instances`，凡是白名单 IP 的例化，把其输出端口连到的本地信号名登记为"IP 验证过的信号"。

    返回：本地信号名 -> {"ip_module", "instance_name", "ip_output_port"}。
    这是 Class 3 门控信号安全判定、Class 2(b) 判定"借用对象是否真的是白名单复位同步器输出"
    共用的同一张表，不重复实现两遍。
    """
    dict_result: dict[str, dict[str, str]] = {}
    for dict_inst in dict_module_ast.get("instances", []) or []:
        str_module_name = dict_inst.get("module_name") or ""
        if str_module_name not in dict_whitelist_module_asts:
            continue
        dict_conns = mod_phase1.parse_instance_port_connections(dict_inst.get("text") or "")
        if not dict_conns:
            continue
        set_out_ports = get_output_port_names(dict_whitelist_module_asts[str_module_name])
        for str_port_name, str_wire_expr in dict_conns.items():
            if str_port_name in set_out_ports and mod_phase1._is_simple_identifier(str_wire_expr):
                dict_result[str_wire_expr.strip()] = {
                    "ip_module": str_module_name,
                    "instance_name": dict_inst.get("instance_name") or "",
                    "ip_output_port": str_port_name,
                }
    return dict_result


# ---------------------------------------------------------------------------
# Class 1 / Class 3 门控信号共用的基础设施：模块内"裸寄存器到寄存器"单跳同步链
# ---------------------------------------------------------------------------

# 只匹配最简单的"寄存器整体复制"单跳赋值（本项目全部真实两级同步器都是这个形状：
# `flag_dest_sync_meta <= flag_source_toggle;`），不解析位选/拼接/三元等复杂表达式——
# 复杂表达式如实排除在driver_map之外，不做语义化简猜测。
_RE_BARE_REGISTER_HOP = re.compile(r"^\s*([A-Za-z_]\w*)\s*<=\s*([A-Za-z_]\w*)\s*;\s*$")


def _strip_trailing_line_comment(str_line: str) -> str:
    """去掉行内 `//` 尾随注释，供正则做整行结构匹配前的预处理。

    真实核实：本项目 `formatter_ast` 的 `lines` 字段保留了每行原始文本，包含行尾中文注释
    （例如真实候选证据行 `reg_diag_snapshot_gated <= reg_diag_snapshot; // 门控为真的这一拍...`，
    见 `cdc_cross_domain_read_candidate_report.json`）——如果不先去掉尾注释，`_RE_BARE_REGISTER_HOP`
    这种要求"分号后到行尾没有其他内容"的整行匹配正则会在几乎所有真实行上失配，因为本项目风格
    要求几乎每个功能行都带同行中文注释。本项目代码里不出现字符串字面量，`//` 出现位置足以
    安全判定注释起点（与 Phase 1 `_strip_verilog_line_comments` 同一假设）。
    """
    int_idx = str_line.find("//")
    return str_line if int_idx < 0 else str_line[:int_idx]


def build_bare_driver_map(dict_module_ast: dict[str, Any]) -> dict[str, str]:
    """构建"目标寄存器 -> 唯一裸赋值驱动源"表（同一目标出现多个不同非自持驱动源时判定为
    "分支结构复杂，无法用简单单跳规则确定"，不纳入表——保守地不参与链深度计算，而不是猜一个。
    """
    dict_targets_to_sources: dict[str, set[str]] = {}
    for dict_always in dict_module_ast.get("always", []) or []:
        set_targets = set(dict_always.get("targets") or [])
        for str_line in dict_always.get("lines", []) or []:
            match = _RE_BARE_REGISTER_HOP.match(_strip_trailing_line_comment(str_line))
            if not match:
                continue
            str_lhs, str_rhs = match.group(1), match.group(2)
            if str_lhs not in set_targets or str_rhs == str_lhs:
                continue  # 不是这个 always 块自己的目标，或是自持保持（不构成真实驱动跳转）
            dict_targets_to_sources.setdefault(str_lhs, set()).add(str_rhs)

    return {
        str_target: next(iter(set_sources))
        for str_target, set_sources in dict_targets_to_sources.items()
        if len(set_sources) == 1
    }


def compute_sync_depth_forward(
    dict_driver_map: dict[str, str], str_start_signal: str, int_max_depth: int = 8
) -> tuple[int, list[str]]:
    """从起点信号沿驱动关系正向走（起点 -> 第1级寄存器 -> 第2级寄存器 -> ...），返回链深度与链本身。"""
    dict_reverse: dict[str, str] = {}
    for str_target, str_source in dict_driver_map.items():
        dict_reverse.setdefault(str_source, str_target)  # 本项目真实场景每个源只驱动一个下一级

    int_depth = 0
    list_chain = [str_start_signal]
    str_current = str_start_signal
    while int_depth < int_max_depth and str_current in dict_reverse:
        str_current = dict_reverse[str_current]
        int_depth += 1
        list_chain.append(str_current)
    return int_depth, list_chain


def compute_inbound_depth(dict_driver_map: dict[str, str], str_signal_name: str, int_max_depth: int = 8) -> int:
    """反向走：这个信号自己是经过多少级裸寄存器赋值才走到这里的（>=2 视为"已充分同步"）。"""
    int_depth = 0
    str_current = str_signal_name
    while int_depth < int_max_depth and str_current in dict_driver_map:
        str_current = dict_driver_map[str_current]
        int_depth += 1
    return int_depth


# ---------------------------------------------------------------------------
# Class 3：多 bit 总线门控安全判定
# ---------------------------------------------------------------------------

_RE_HEADER_CONDITION = re.compile(r"\((.*)\)\s*begin\s*$")


def find_branch_header_for_line(dict_always: dict[str, Any], int_content_line_idx: int) -> str | None:
    """给定 always 块内某内容行下标，回溯定位它所处分支的分支头行原文。

    复用 Phase 2 的 `classify_always_line_branches`/`is_branch_header_line`（本项目真实代码风格
    固定为扁平 if/else_if/else，不嵌套，见 Phase 2 docstring），不重新实现分支识别。
    """
    list_lines = dict_always.get("lines", []) or []
    list_branches = mod_phase2.classify_always_line_branches(list_lines)
    if int_content_line_idx >= len(list_branches):
        return None
    str_target_kind = list_branches[int_content_line_idx]
    for int_i in range(int_content_line_idx, -1, -1):
        if mod_phase2.is_branch_header_line(list_lines[int_i]) and list_branches[int_i] == str_target_kind:
            return list_lines[int_i]
    return None


def extract_condition_identifiers(str_header_line: str) -> list[str]:
    """从分支头行（`if(...)begin`/`end else if(...)begin`）里提取条件表达式中的标识符。

    数字字面量（`1'b0`/`8'hFF`等）以数字开头，正则要求标识符以字母/下划线开头，天然排除；
    运算符（`!=`/`==`等）不是词字符，`findall` 本身就不会匹配到它们，不需要额外过滤列表。
    """
    match = _RE_HEADER_CONDITION.search(_strip_trailing_line_comment(str_header_line))
    if not match:
        return []
    return re.findall(r"[A-Za-z_]\w*", match.group(1))


def evaluate_gate_signal_safety(
    dict_module_ast: dict[str, Any],
    str_gate_signal: str,
    dict_whitelist_ip_output_map: dict[str, dict[str, str]],
    dict_driver_map: dict[str, str],
) -> dict[str, Any]:
    """判定单个门控信号本身是否安全：经白名单IP输出，或本模块内已 >= 2 级寄存器同步。"""
    if str_gate_signal in dict_whitelist_ip_output_map:
        dict_ip_info = dict_whitelist_ip_output_map[str_gate_signal]
        return {
            "signal": str_gate_signal,
            "safe": True,
            "reason": (
                f"追溯到白名单IP `{dict_ip_info['ip_module']}` 实例 `{dict_ip_info['instance_name']}` "
                f"的输出端口 `{dict_ip_info['ip_output_port']}`，视为已经过安全CDC机制处理的信号"
            ),
        }

    int_depth = compute_inbound_depth(dict_driver_map, str_gate_signal)
    if int_depth >= 2:
        return {
            "signal": str_gate_signal,
            "safe": True,
            "reason": f"本模块内经{int_depth}级裸寄存器同步链，满足Class 1'至少2级同步'的安全规则",
        }

    return {
        "signal": str_gate_signal,
        "safe": False,
        "reason": (
            f"未追溯到任何白名单IP输出端口，本模块内裸寄存器同步链深度仅{int_depth}级（<2）；"
            "门控信号本身可能是未受保护的手搓跨域，'有门控'这个表面结构不能代替对门控信号自身的判定"
        ),
    }


def evaluate_class3_gate_safety(
    dict_module_ast: dict[str, Any],
    dict_reader_always: dict[str, Any],
    int_evidence_line_idx: int,
    dict_whitelist_ip_output_map: dict[str, dict[str, str]],
) -> dict[str, Any]:
    str_header_line = find_branch_header_for_line(dict_reader_always, int_evidence_line_idx)
    if str_header_line is None:
        return {
            "gate_signals": [],
            "all_safe": False,
            "reason": "无法定位证据行所处分支的分支头行，保守判定门控安全性不可确认",
        }

    list_gate_identifiers = extract_condition_identifiers(str_header_line)
    if not list_gate_identifiers:
        return {
            "gate_signals": [],
            "all_safe": False,
            "reason": f"分支头行 `{str_header_line.strip()}` 未能提取出任何门控条件标识符",
        }

    dict_driver_map = build_bare_driver_map(dict_module_ast)
    list_gate_results = [
        evaluate_gate_signal_safety(dict_module_ast, str_signal, dict_whitelist_ip_output_map, dict_driver_map)
        for str_signal in list_gate_identifiers
    ]
    return {
        "gate_header_line": str_header_line.strip(),
        "gate_signals": list_gate_results,
        "all_safe": all(dict_r["safe"] for dict_r in list_gate_results),
    }


def classify_multibit_register_capture(
    dict_module_ast: dict[str, Any],
    str_target_register: str,
    bool_is_gated: bool,
    dict_reader_always: dict[str, Any] | None,
    str_evidence_line: str,
    dict_whitelist_ip_output_map: dict[str, dict[str, str]],
) -> dict[str, Any]:
    """Class 3 核心判定：位宽 -> 门控与否 -> （若有门控）门控信号自身安全性。"""
    str_width = get_decl_width(dict_module_ast, str_target_register)
    if not str_width:
        return {
            "class": CLASS_1,
            "verdict": None,
            "note": f"目标寄存器 `{str_target_register}` 是1-bit（width为空），不适用Class 3规则，应走Class 1判据",
        }

    if not bool_is_gated:
        return {
            "class": CLASS_3_HIGH_RISK,
            "verdict": VERDICT_HIGH_RISK,
            "width": str_width,
            "reason": "多bit总线无门控每拍连续采样（读取发生在无独立条件的else fallback分支），"
            "这正是真实SPI诊断快照撕裂缺陷（V1.2）的结构形状",
        }

    if dict_reader_always is None:
        return {
            "class": CLASS_3_HIGH_RISK,
            "verdict": VERDICT_HIGH_RISK,
            "width": str_width,
            "reason": "候选标注为已门控，但未能定位到读取所在的always块，保守判定不安全",
        }

    int_idx = find_line_index(dict_reader_always.get("lines", []) or [], str_evidence_line)
    if int_idx is None:
        return {
            "class": CLASS_3_HIGH_RISK,
            "verdict": VERDICT_HIGH_RISK,
            "width": str_width,
            "reason": "候选标注为已门控，但未能在always块文本里定位证据行，保守判定不安全",
        }

    dict_gate_eval = evaluate_class3_gate_safety(dict_module_ast, dict_reader_always, int_idx, dict_whitelist_ip_output_map)
    if dict_gate_eval["all_safe"]:
        return {
            "class": CLASS_3A,
            "verdict": VERDICT_SAFE_GATED_CAPTURE,
            "width": str_width,
            "gate_evaluation": dict_gate_eval,
        }
    return {
        "class": CLASS_3_HIGH_RISK,
        "verdict": VERDICT_HIGH_RISK_UNVERIFIED_GATE,
        "width": str_width,
        "gate_evaluation": dict_gate_eval,
    }


def classify_phase2_candidate(
    dict_candidate: dict[str, Any],
    dict_module_ast: dict[str, Any],
    dict_whitelist_ip_output_map: dict[str, dict[str, str]],
) -> dict[str, Any]:
    """把 Phase 2 产出的一条候选字典适配成 `classify_multibit_register_capture` 的调用。"""
    dict_reader_always = find_always_by_line_start(dict_module_ast, dict_candidate.get("reader_always_line_start"))
    dict_verdict = classify_multibit_register_capture(
        dict_module_ast,
        dict_candidate["target_register"],
        bool(dict_candidate.get("gated")),
        dict_reader_always,
        dict_candidate.get("evidence_line", ""),
        dict_whitelist_ip_output_map,
    )
    return {
        "module": dict_candidate.get("module"),
        "target_register": dict_candidate["target_register"],
        "kind": dict_candidate.get("kind"),
        "evidence_line": dict_candidate.get("evidence_line"),
        **dict_verdict,
    }


# ---------------------------------------------------------------------------
# Class 1：外部异步源信号的同步深度审计（真实范围扩大到 _async 后缀信号，不只是"域A到域B"）
# ---------------------------------------------------------------------------


VERDICT_NOT_CONSUMED_IN_THIS_MODULE = "NOT_CONSUMED_IN_THIS_MODULE"


def _signal_referenced_in_any_always(dict_module_ast: dict[str, Any], str_signal_name: str) -> bool:
    """这个信号名有没有在本模块任何 always 块的函数体文本里整词出现过（不区分读写位置）。

    用于区分"这个模块真的用寄存器消费了这个信号"和"这个模块只是端口直通给子实例"——
    后者不该被当成 Class 1 判据的输入，因为直通模块里根本没有任何 always 块在采样它，
    depth 天然算出 0，但 0 在这里的真实含义是"无关"，不是"只经过 0 级同步的高风险"。
    """
    for dict_always in dict_module_ast.get("always", []) or []:
        for str_line in dict_always.get("lines", []) or []:
            if mod_phase2._whole_word_positions(str_signal_name, str_line):
                return True
    return False


def audit_class1_external_async_signals(dict_nodes_by_module: dict[str, list["mod_phase1.InstanceNode"]]) -> list[dict[str, Any]]:
    """对 Phase 1 已标注的全部 `EXTERNAL_ASYNC` 信号，在各自声明的模块内跑同步深度审计。

    范围依据规划 Phase 3 明确要求扩大到"外部异步源"类别——这些信号源头不是另一个真实时钟域而是
    模拟前端/pad直接来的电平，但本质上也是手搓的单bit同步器，同样需要"至少2级"这条结构性检查。

    真实运行中发现的一个真实边界情况（不是假设）：Phase 1 的 `tag_async_signals` 按"哪些模块的
    端口/内部声明带 `_async` 后缀"逐模块登记，同一个物理信号沿例化链原样透传时会在多个模块里各登记
    一条——例如 `i_clk_stage1_dout_low_async` 在 `ppg_control_top`/`ppg_adc_measurement_idac_integration`
    两个纯透传模块里只是端口连到子实例，真正的两级同步只发生在 `ppg_adc_async_stage_capture`（已确认
    depth=2安全）。透传模块内没有任何 always 块读取过这个信号，构建同步链会得到 depth=0——这个 0
    的真实含义是"本模块不消费，判据不适用"，不是"只经过0级同步的高风险"，必须先判断"是否被消费"
    再判断"深度是否够"，否则会把纯透传模块误报成风险。
    """
    list_async_tags = mod_phase1.tag_async_signals(dict_nodes_by_module)
    list_results: list[dict[str, Any]] = []
    for dict_tag in list_async_tags:
        if dict_tag["domain"] != mod_phase1.DOMAIN_EXTERNAL_ASYNC:
            continue
        str_module_name = dict_tag["module"]
        if str_module_name not in dict_nodes_by_module:
            continue
        dict_module_ast = dict_nodes_by_module[str_module_name][0].module_ast

        if not _signal_referenced_in_any_always(dict_module_ast, dict_tag["signal"]):
            list_results.append(
                {
                    "module": str_module_name,
                    "signal": dict_tag["signal"],
                    "kind": dict_tag["kind"],
                    "class": CLASS_1,
                    "chain": None,
                    "depth": None,
                    "verdict": VERDICT_NOT_CONSUMED_IN_THIS_MODULE,
                    "note": "该信号在本模块内只是端口直通给子实例，未被本模块任何always块读取；"
                    "真实同步链在被例化的子模块内，见该子模块自己的独立审计条目",
                }
            )
            continue

        dict_driver_map = build_bare_driver_map(dict_module_ast)
        int_depth, list_chain = compute_sync_depth_forward(dict_driver_map, dict_tag["signal"])
        list_results.append(
            {
                "module": str_module_name,
                "signal": dict_tag["signal"],
                "kind": dict_tag["kind"],
                "class": CLASS_1,
                "chain": list_chain,
                "depth": int_depth,
                "verdict": VERDICT_SAFE if int_depth >= 2 else VERDICT_HIGH_RISK_SINGLE_STAGE,
            }
        )
    return list_results


# ---------------------------------------------------------------------------
# Class 2：复位释放两种安全形态
# ---------------------------------------------------------------------------


def check_class2_standard_reset_sync(dict_module_ast: dict[str, Any]) -> list[dict[str, Any]]:
    """(a) 标准形态：模块内例化了白名单 `ppg_reset_sync`，即为已验证的2FF释放同步。"""
    list_results: list[dict[str, Any]] = []
    for dict_inst in dict_module_ast.get("instances", []) or []:
        if dict_inst.get("module_name") != "ppg_reset_sync":
            continue
        dict_conns = mod_phase1.parse_instance_port_connections(dict_inst.get("text") or "")
        list_results.append(
            {
                "instance_name": dict_inst.get("instance_name") or "",
                "connections": dict_conns,
                "class": CLASS_2A,
                "verdict": VERDICT_SAFE_IP_VERIFIED,
            }
        )
    return list_results


_RE_RESET_LIKE_NAME = re.compile(r"rstn", re.IGNORECASE)
_TUPLE_KEYWORDS_BORROW = ("借用",)
_TUPLE_KEYWORDS_JUSTIFY = ("已同步", "已稳定", "空闲", "稳定")


def check_class2_borrowed_reset(
    dict_module_ast: dict[str, Any], dict_whitelist_ip_output_map: dict[str, dict[str, str]]
) -> list[dict[str, Any]]:
    """(b) 特例形态：借用已同步的常跑域复位、异步喂入间歇域，且注释含文档化理由。

    判据：`assign lhs = rhs;`，lhs/rhs都像复位信号名（含"rstn"）、rhs不等于lhs、且rhs本身
    追溯到白名单`ppg_reset_sync`实例的输出端口（即rhs自己是Class2(a)已验证安全的复位）；
    再核对该assign的注释文本是否同时含"借用"与"已同步/已稳定/空闲/稳定"类关键词——对照
    `ppg_chip_digital_top.v` V1.1 真实先例（`w_source_rstn = w_rstn`）的真实注释文本。
    只满足信号连接条件、不满足关键词条件的，如实标记"UNVERIFIED_RESET_BORROW"，不假定安全。
    """
    list_results: list[dict[str, Any]] = []
    for dict_assign in dict_module_ast.get("assigns", []) or []:
        str_lhs = dict_assign.get("lhs", "") or ""
        str_rhs = dict_assign.get("rhs", "") or ""
        if not (_RE_RESET_LIKE_NAME.search(str_lhs) and mod_phase1._is_simple_identifier(str_rhs) and str_rhs != str_lhs):
            continue

        str_comment_blob = " ".join([dict_assign.get("comment", "") or ""] + list(dict_assign.get("leading_comments") or []))
        bool_rhs_is_whitelist_reset = (
            str_rhs in dict_whitelist_ip_output_map and dict_whitelist_ip_output_map[str_rhs]["ip_module"] == "ppg_reset_sync"
        )
        bool_has_borrow_keyword = any(k in str_comment_blob for k in _TUPLE_KEYWORDS_BORROW)
        bool_has_justify_keyword = any(k in str_comment_blob for k in _TUPLE_KEYWORDS_JUSTIFY)

        if bool_rhs_is_whitelist_reset and bool_has_borrow_keyword and bool_has_justify_keyword:
            list_results.append(
                {
                    "lhs": str_lhs,
                    "rhs": str_rhs,
                    "class": CLASS_2B,
                    "verdict": VERDICT_SAFE_DOCUMENTED_BORROW,
                    "evidence_comment": str_comment_blob,
                }
            )
        else:
            list_results.append(
                {
                    "lhs": str_lhs,
                    "rhs": str_rhs,
                    "class": "2",
                    "verdict": VERDICT_UNVERIFIED_RESET_BORROW,
                    "rhs_is_whitelist_reset_sync_output": bool_rhs_is_whitelist_reset,
                    "has_borrow_keyword": bool_has_borrow_keyword,
                    "has_justify_keyword": bool_has_justify_keyword,
                    "evidence_comment": str_comment_blob,
                }
            )
    return list_results


# ---------------------------------------------------------------------------
# 白名单自洽性检查（规划要求 #1）
# ---------------------------------------------------------------------------


def run_whitelist_self_consistency_check(dict_nodes_by_module: dict[str, list["mod_phase1.InstanceNode"]]) -> dict[str, Any]:
    dict_results: dict[str, Any] = {}

    # --- ppg_pulse_cdc_sync 自身内部单bit两级同步链（Class 1）---
    dict_pulse_ast = dict_nodes_by_module["ppg_pulse_cdc_sync"][0].module_ast
    dict_pulse_driver_map = build_bare_driver_map(dict_pulse_ast)
    int_depth, list_chain = compute_sync_depth_forward(dict_pulse_driver_map, "flag_source_toggle")
    dict_results["ppg_pulse_cdc_sync_internal_chain"] = {
        "start_signal": "flag_source_toggle",
        "chain": list_chain,
        "depth": int_depth,
        "class": CLASS_1,
        "verdict": VERDICT_SAFE if int_depth >= 2 else VERDICT_HIGH_RISK_SINGLE_STAGE,
        "note": "不走'这是白名单'捷径，直接用Class 1结构判据核实IP自己的两级同步链本身是否安全",
    }

    # --- ppg_reset_sync 本身即Class 2(a)定义来源，不需要二次判定 ---
    dict_results["ppg_reset_sync_is_definition_itself"] = {
        "class": CLASS_2A,
        "verdict": VERDICT_SAFE_IP_VERIFIED,
        "note": "该IP本身就是Class 2(a)标准2FF释放同步的定义来源，对它自己跑'是否例化了ppg_reset_sync'"
        "没有意义；自洽性在这里是平凡成立的，如实记录而不是省略",
    }

    # --- ppg_config_cdc_bridge 自身内部门控捕获（Class 3(a)），门控条件是两个内部寄存器的代际比较，
    #     不是连到另一个白名单IP的连线——用这个真实案例证明Class 3判据的"信号自身>=2级同步链"分支
    #     （而不是只有"连到白名单IP输出"这一条路径）也能正确工作。
    dict_bridge_ast = dict_nodes_by_module["ppg_config_cdc_bridge"][0].module_ast
    dict_dest_always = None
    for dict_always in dict_bridge_ast.get("always", []) or []:
        if "destination_config_o" in (dict_always.get("targets") or []):
            dict_dest_always = dict_always
            break
    if dict_dest_always is not None:
        int_idx = find_line_index(dict_dest_always.get("lines", []) or [], "destination_config_o <= reg_source_config;")
        if int_idx is not None:
            dict_gate_eval = evaluate_class3_gate_safety(dict_bridge_ast, dict_dest_always, int_idx, {})
            dict_results["ppg_config_cdc_bridge_internal_gated_capture"] = {
                "target_register": "reg_source_config",
                "width": get_decl_width(dict_bridge_ast, "reg_source_config"),
                "class": CLASS_3A if dict_gate_eval["all_safe"] else CLASS_3_HIGH_RISK,
                "verdict": VERDICT_SAFE_GATED_CAPTURE if dict_gate_eval["all_safe"] else VERDICT_HIGH_RISK_UNVERIFIED_GATE,
                "gate_evaluation": dict_gate_eval,
                "note": "门控条件flag_request_sync!=flag_destination_ack里的两个标识符都是本模块内部寄存器，"
                "不经其他白名单IP连线——专门验证Class 3判据'信号自身同步链深度>=2'这条分支本身可靠",
            }
    return dict_results


# ---------------------------------------------------------------------------
# 真实全流程编排
# ---------------------------------------------------------------------------


def run_phase3(
    path_project_root: Path = PATH_PROJECT_ROOT,
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]] | None" = None,
) -> dict[str, Any]:
    """跑完整的 Phase 3 流程。

    真实全项目例化树构建单次耗时约70秒（本机实测，`build_reachable_module_tree()`需要重新
    收集候选文件全集并对每个文件跑`formatter_ast`），本函数与`run_validation()`在一次真实
    运行里会多次需要同一棵树——`dict_nodes_by_module`允许调用方（`main()`/`selftest()`）只建一次
    树、多处复用，不是逻辑变化，纯粹避免真实运行时长不必要地成倍增加。
    """
    if dict_nodes_by_module is None:
        dict_nodes_by_module = mod_phase2.build_reachable_module_tree()
    dict_phase2_result = mod_phase2.run_phase2(path_project_root, dict_nodes_by_module)

    dict_whitelist_module_asts = {
        str_name: dict_nodes_by_module[str_name][0].module_ast
        for str_name in SET_WHITELIST_IP_MODULES
        if str_name in dict_nodes_by_module
    }

    dict_whitelist_self_consistency = run_whitelist_self_consistency_check(dict_nodes_by_module)
    list_class1_async_audit = audit_class1_external_async_signals(dict_nodes_by_module)

    dict_chip_top_ast = dict_nodes_by_module[mod_phase1.TOP_MODULE_NAME][0].module_ast
    dict_chip_top_wl_map = build_local_wire_to_whitelist_ip_output(dict_chip_top_ast, dict_whitelist_module_asts)
    list_class2_standard = check_class2_standard_reset_sync(dict_chip_top_ast)
    list_class2_borrowed = check_class2_borrowed_reset(dict_chip_top_ast, dict_chip_top_wl_map)

    list_classified_candidates: list[dict[str, Any]] = []
    for dict_candidate in dict_phase2_result["candidates"] + dict_phase2_result["gated_candidates"]:
        str_module_name = dict_candidate["module"]
        if str_module_name not in dict_nodes_by_module:
            continue
        dict_module_ast = dict_nodes_by_module[str_module_name][0].module_ast
        dict_module_wl_map = build_local_wire_to_whitelist_ip_output(dict_module_ast, dict_whitelist_module_asts)
        list_classified_candidates.append(classify_phase2_candidate(dict_candidate, dict_module_ast, dict_module_wl_map))

    return {
        "whitelist_self_consistency_check": dict_whitelist_self_consistency,
        "class1_external_async_audit": list_class1_async_audit,
        "class2_standard_reset_sync": list_class2_standard,
        "class2_borrowed_reset": list_class2_borrowed,
        "classified_candidates": list_classified_candidates,
        "phase2_summary": {
            "candidates_total": dict_phase2_result["candidates_total"],
            "gated_candidates_total": dict_phase2_result["gated_candidates_total"],
        },
    }


# ---------------------------------------------------------------------------
# 验证：5个规划点名的验证用例 + 附加自洽性/审计断言
# ---------------------------------------------------------------------------


def _run_case_config_cdc_bridge_real_gated(
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]]",
) -> dict[str, Any]:
    """验证用例1：`ppg_config_cdc_bridge.v` 真实门控模式=判定安全（复用整体真实扫描已经跑出的结果）。"""
    dict_check = run_whitelist_self_consistency_check(dict_nodes_by_module)
    dict_entry = dict_check.get("ppg_config_cdc_bridge_internal_gated_capture")
    bool_pass = dict_entry is not None and dict_entry["verdict"] == VERDICT_SAFE_GATED_CAPTURE
    return {
        "label": "验证用例1：ppg_config_cdc_bridge.v真实门控模式=判定安全",
        "pass": bool_pass,
        "detail": f"实际结果={dict_entry}",
    }


def _run_case_synthetic_v1_2_negative_high_risk() -> dict[str, Any]:
    """验证用例2：Phase2重建的V1.2无门控合成负例=判定高风险（复用Phase2既有合成文件，不重建）。"""
    path_tmp = PATH_SELF_DIR / "_phase3_reuse_phase2_negative.v"
    path_tmp.write_text(mod_phase2.SYNTHETIC_NEGATIVE_V1_2_RECONSTRUCTION, encoding="utf-8")
    try:
        dict_report = build_ast_report_for_path(path_tmp)
        dict_module_ast = dict_report["modules"][0]

        dict_writer_always = None
        for dict_always in dict_module_ast.get("always", []):
            if "reg_diag_sync_meta" in (dict_always.get("targets") or []):
                dict_writer_always = dict_always
                break

        dict_verdict = classify_multibit_register_capture(
            dict_module_ast,
            "reg_diag_snapshot",
            False,  # V1.2形状：读取落在无独立条件的else fallback分支，即Phase2的gated=False
            dict_writer_always,
            "reg_diag_sync_meta <= reg_diag_snapshot;",
            {},
        )
        bool_pass = dict_verdict["verdict"] == VERDICT_HIGH_RISK
        return {
            "label": "验证用例2：Phase2合成V1.2无门控负例（依据changelog重建，非真实历史文件）=判定高风险",
            "pass": bool_pass,
            "detail": f"实际结果={dict_verdict}",
        }
    finally:
        path_tmp.unlink(missing_ok=True)


def _run_case_pulse_cdc_sync_self_safe(
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]]",
) -> dict[str, Any]:
    """验证用例3：`ppg_pulse_cdc_sync.v` 自身单bit两级同步=判定安全（与白名单自洽性检查共享同一结果）。"""
    dict_check = run_whitelist_self_consistency_check(dict_nodes_by_module)
    dict_entry = dict_check["ppg_pulse_cdc_sync_internal_chain"]
    bool_pass = dict_entry["verdict"] == VERDICT_SAFE and dict_entry["depth"] >= 2
    return {
        "label": "验证用例3：ppg_pulse_cdc_sync.v自身单bit两级同步=判定安全",
        "pass": bool_pass,
        "detail": f"实际结果={dict_entry}",
    }


def _run_case_chip_top_borrowed_reset_safe(
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]]",
) -> dict[str, Any]:
    """验证用例4：`ppg_chip_digital_top.v` 的 w_source_rstn 借用 w_rstn 模式=判定安全（Class 2特例）。"""
    dict_chip_top_ast = dict_nodes_by_module[mod_phase1.TOP_MODULE_NAME][0].module_ast
    dict_whitelist_module_asts = {
        str_name: dict_nodes_by_module[str_name][0].module_ast
        for str_name in SET_WHITELIST_IP_MODULES
        if str_name in dict_nodes_by_module
    }
    dict_wl_map = build_local_wire_to_whitelist_ip_output(dict_chip_top_ast, dict_whitelist_module_asts)
    list_borrowed = check_class2_borrowed_reset(dict_chip_top_ast, dict_wl_map)
    dict_match = next((d for d in list_borrowed if d["lhs"] == "w_source_rstn"), None)
    bool_pass = dict_match is not None and dict_match["verdict"] == VERDICT_SAFE_DOCUMENTED_BORROW
    return {
        "label": "验证用例4：ppg_chip_digital_top.v的w_source_rstn借用w_rstn模式=判定安全（Class 2特例）",
        "pass": bool_pass,
        "detail": f"实际结果={dict_match}",
    }


SYNTHETIC_GATE_TRAP_CASE = """`timescale 1ns / 1ps

// 合成陷阱用例（不对应任何真实项目文件）：门控信号本身也是未经白名单IP、无门控手搓跨域来的
// （"门控形同虚设"场景）——验证Phase 3不会因为表面存在门控结构就直接放行，必须报高风险。
module cdc_phase3_synthetic_gate_trap
(
	input i_clk,
	input i_rstn,
	input i_source_clk,
	input i_source_rstn,
	input [15:0] i_dummy_next,
	input i_raw_gate_signal,
	output [15:0] o_dummy
);

	reg [15:0] reg_source_bus;
	reg [15:0] reg_dest_bus;
	reg reg_fake_gate;

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_source_bus <= 16'd0;
		end else begin
			reg_source_bus <= i_dummy_next;
		end
	end

	// 手搓的"门控"信号本身只经过一级寄存器，不是白名单IP产物，也不满足Class 1的2级同步规则
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_fake_gate <= 1'b0;
		end else begin
			reg_fake_gate <= i_raw_gate_signal;
		end
	end

	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_dest_bus <= 16'd0;
		end else if(reg_fake_gate)begin
			reg_dest_bus <= reg_source_bus;
		end else begin
			reg_dest_bus <= reg_dest_bus;
		end
	end

	assign o_dummy = reg_dest_bus;

endmodule
"""


def _run_case_synthetic_gate_trap_high_risk() -> dict[str, Any]:
    """验证用例5：门控信号本身也是未经白名单IP、无门控手搓跨域的合成陷阱=判定高风险。"""
    path_tmp = PATH_SELF_DIR / "_phase3_synthetic_gate_trap.v"
    path_tmp.write_text(SYNTHETIC_GATE_TRAP_CASE, encoding="utf-8")
    try:
        dict_report = build_ast_report_for_path(path_tmp)
        dict_module_ast = dict_report["modules"][0]

        dict_reader_always = None
        for dict_always in dict_module_ast.get("always", []):
            if "reg_dest_bus" in (dict_always.get("targets") or []):
                dict_reader_always = dict_always
                break

        dict_verdict = classify_multibit_register_capture(
            dict_module_ast,
            "reg_source_bus",
            True,  # 表面上有门控（if(reg_fake_gate)），Phase2会标gated=True
            dict_reader_always,
            "reg_dest_bus <= reg_source_bus;",
            {},  # 无白名单IP连线，reg_fake_gate必须靠自身同步深度判定（结果应为1级，不够）
        )
        bool_pass = dict_verdict["verdict"] == VERDICT_HIGH_RISK_UNVERIFIED_GATE
        return {
            "label": "验证用例5：门控信号本身是未经白名单IP、无门控手搓跨域的合成陷阱=判定高风险（不能因表面有门控就放行）",
            "pass": bool_pass,
            "detail": f"实际结果={dict_verdict}",
        }
    finally:
        path_tmp.unlink(missing_ok=True)


def _run_case_real_v1_3_gated_candidate_class3a(
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]]",
) -> dict[str, Any]:
    """附加真实断言：Phase2唯一真实门控候选（reg_diag_snapshot_gated读取reg_diag_snapshot）
    最终应被Phase3归类为"Class 3(a)门控捕获，安全"，不是"待定"或"高风险"。"""
    dict_result = run_phase3(dict_nodes_by_module=dict_nodes_by_module)
    dict_match = next(
        (
            c
            for c in dict_result["classified_candidates"]
            if c["module"] == "ppg_spi_register_file"
            and c["target_register"] == "reg_diag_snapshot"
            and "reg_diag_snapshot_gated" in (c.get("evidence_line") or "")
        ),
        None,
    )
    bool_pass = dict_match is not None and dict_match["class"] == CLASS_3A and dict_match["verdict"] == VERDICT_SAFE_GATED_CAPTURE
    return {
        "label": "附加真实断言：Phase2唯一真实门控候选最终归类为Class 3(a)门控捕获，安全",
        "pass": bool_pass,
        "detail": f"实际分类结果={dict_match}",
    }


def run_validation(
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]] | None" = None,
) -> dict[str, Any]:
    """跑5个规划点名验证用例 + 1个真实断言。

    `dict_nodes_by_module`同样是纯性能钩子：用例2/5是纯合成文件，不需要真实例化树；用例1/3/4/6
    需要，默认`None`时各自独立建树（行为与之前一致，只是慢），传入时全部复用同一棵树。
    """
    if dict_nodes_by_module is None:
        dict_nodes_by_module = mod_phase2.build_reachable_module_tree()

    list_cases = [
        _run_case_config_cdc_bridge_real_gated(dict_nodes_by_module),
        _run_case_synthetic_v1_2_negative_high_risk(),
        _run_case_pulse_cdc_sync_self_safe(dict_nodes_by_module),
        _run_case_chip_top_borrowed_reset_safe(dict_nodes_by_module),
        _run_case_synthetic_gate_trap_high_risk(),
        _run_case_real_v1_3_gated_candidate_class3a(dict_nodes_by_module),
    ]
    return {"cases": list_cases, "all_pass": all(c["pass"] for c in list_cases)}


# ---------------------------------------------------------------------------
# Markdown 报告
# ---------------------------------------------------------------------------


def _format_markdown_report(dict_result: dict[str, Any], dict_validation: dict[str, Any]) -> str:
    list_lines: list[str] = []
    list_lines.append("# PPG Item 4b Phase 3 —— 白名单IP识别 + 手搓跨域结构性判定")
    list_lines.append("")

    list_lines.append("## 验证用例结果（5个规划点名用例 + 1个真实断言）")
    list_lines.append("")
    for dict_v in dict_validation["cases"]:
        str_status = "PASS" if dict_v["pass"] else "FAIL"
        list_lines.append(f"- [{str_status}] {dict_v['label']}")
    list_lines.append("")

    list_lines.append("## 白名单自洽性检查")
    list_lines.append("")
    for str_key, dict_entry in dict_result["whitelist_self_consistency_check"].items():
        list_lines.append(f"- `{str_key}`: class={dict_entry.get('class')}, verdict={dict_entry.get('verdict')}")
    list_lines.append("")

    list_lines.append("## Class 1 外部异步源信号同步深度审计（真实全部EXTERNAL_ASYNC信号）")
    list_lines.append("")
    for dict_a in dict_result["class1_external_async_audit"]:
        if dict_a["chain"] is None:
            list_lines.append(
                f"- `{dict_a['module']}`.`{dict_a['signal']}`（{dict_a['kind']}）：判定={dict_a['verdict']}"
                f"（{dict_a.get('note', '')}）"
            )
        else:
            list_lines.append(
                f"- `{dict_a['module']}`.`{dict_a['signal']}`（{dict_a['kind']}）：深度={dict_a['depth']}，"
                f"链={' -> '.join(dict_a['chain'])}，判定={dict_a['verdict']}"
            )
    list_lines.append("")

    list_lines.append("## Class 2 复位释放审计（真实顶层ppg_chip_digital_top）")
    list_lines.append("")
    list_lines.append("### (a) 标准ppg_reset_sync白名单实例")
    for dict_s in dict_result["class2_standard_reset_sync"]:
        list_lines.append(f"- 实例`{dict_s['instance_name']}`：class={dict_s['class']}, verdict={dict_s['verdict']}")
    list_lines.append("")
    list_lines.append("### (b) 借用已同步常跑域复位的特例形态")
    for dict_b in dict_result["class2_borrowed_reset"]:
        list_lines.append(f"- `{dict_b['lhs']} = {dict_b['rhs']}`：class={dict_b['class']}, verdict={dict_b['verdict']}")
    list_lines.append("")

    list_lines.append("## Phase 2候选的Class 3最终分类（真实项目：0主候选 + 1门控候选）")
    list_lines.append("")
    list_lines.append(
        f"（Phase2汇总：主候选{dict_result['phase2_summary']['candidates_total']}项，"
        f"门控候选{dict_result['phase2_summary']['gated_candidates_total']}项）"
    )
    list_lines.append("")
    for dict_c in dict_result["classified_candidates"]:
        list_lines.append(
            f"- `{dict_c['module']}`.`{dict_c['target_register']}`（{dict_c['kind']}）："
            f"class={dict_c.get('class')}, verdict={dict_c.get('verdict')}"
        )
        if dict_c.get("gate_evaluation"):
            for dict_g in dict_c["gate_evaluation"].get("gate_signals", []):
                list_lines.append(f"  - 门控信号`{dict_g['signal']}`：safe={dict_g['safe']}，{dict_g['reason']}")
    list_lines.append("")

    return "\n".join(list_lines)


# ---------------------------------------------------------------------------
# --selftest
# ---------------------------------------------------------------------------


def selftest() -> int:
    int_failures = 0

    def _check(str_label: str, bool_condition: bool) -> None:
        nonlocal int_failures
        str_status = "PASS" if bool_condition else "FAIL"
        print(f"[{str_status}] {str_label}")
        if not bool_condition:
            int_failures += 1

    print("=== 基础工具单元测试 ===")
    _check(
        "裸寄存器单跳赋值正则命中简单形状",
        _RE_BARE_REGISTER_HOP.match("flag_dest_sync_meta <= flag_source_toggle;") is not None,
    )
    _check(
        "自持保持（X<=X）不构成真实驱动跳转",
        "flag_x" not in build_bare_driver_map({"always": [{"targets": ["flag_x"], "lines": ["flag_x <= flag_x;"]}]}),
    )
    _check(
        "分支头行条件标识符提取：单标识符",
        extract_condition_identifiers("end else if(w_diag_snapshot_gate_event)begin") == ["w_diag_snapshot_gate_event"],
    )
    _check(
        "分支头行条件标识符提取：比较表达式两个标识符",
        extract_condition_identifiers("end else if(flag_request_sync != flag_destination_ack)begin")
        == ["flag_request_sync", "flag_destination_ack"],
    )

    print("\n=== 5个规划验证用例 + 1个真实断言（建一次真实例化树，全部复用） ===")
    dict_nodes_by_module = mod_phase2.build_reachable_module_tree()
    dict_validation = run_validation(dict_nodes_by_module)
    for dict_v in dict_validation["cases"]:
        _check(dict_v["label"], dict_v["pass"])

    print(f"\n{'全部通过' if int_failures == 0 else f'{int_failures} 项失败'}")
    return 0 if int_failures == 0 else 1


# ---------------------------------------------------------------------------
# CLI 入口
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, default=None)
    parser.add_argument("--markdown", type=Path, default=None)
    parser.add_argument("--selftest", action="store_true")
    namespace_args = parser.parse_args(argv)

    if namespace_args.selftest:
        return selftest()

    dict_nodes_by_module = mod_phase2.build_reachable_module_tree()
    dict_result = run_phase3(dict_nodes_by_module=dict_nodes_by_module)
    dict_validation = run_validation(dict_nodes_by_module)

    print("白名单自洽性检查：")
    for str_key, dict_entry in dict_result["whitelist_self_consistency_check"].items():
        print(f"  {str_key}: {dict_entry.get('verdict')}")
    print(f"Class1外部异步源审计：{len(dict_result['class1_external_async_audit'])}项")
    for dict_a in dict_result["class1_external_async_audit"]:
        str_depth_display = "N/A" if dict_a["depth"] is None else str(dict_a["depth"])
        print(f"  {dict_a['module']}.{dict_a['signal']}: 深度={str_depth_display}, {dict_a['verdict']}")
    print(f"Class2标准复位实例：{len(dict_result['class2_standard_reset_sync'])}项")
    print(f"Class2借用复位模式：{len(dict_result['class2_borrowed_reset'])}项")
    for dict_b in dict_result["class2_borrowed_reset"]:
        print(f"  {dict_b['lhs']} = {dict_b['rhs']}: {dict_b['verdict']}")
    print(f"Phase2候选最终分类：{len(dict_result['classified_candidates'])}项")
    for dict_c in dict_result["classified_candidates"]:
        print(f"  {dict_c['module']}.{dict_c['target_register']}: class={dict_c.get('class')}, verdict={dict_c.get('verdict')}")

    print("\n验证用例：")
    for dict_v in dict_validation["cases"]:
        str_status = "PASS" if dict_v["pass"] else "FAIL"
        print(f"  [{str_status}] {dict_v['label']}")

    dict_result["validation"] = dict_validation

    if namespace_args.json is not None:
        namespace_args.json.write_text(json.dumps(dict_result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"\n已写入 JSON：{namespace_args.json}")

    if namespace_args.markdown is not None:
        namespace_args.markdown.write_text(_format_markdown_report(dict_result, dict_validation), encoding="utf-8")
        print(f"已写入 Markdown：{namespace_args.markdown}")

    return 0 if dict_validation["all_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
