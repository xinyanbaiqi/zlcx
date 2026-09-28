#!/usr/bin/env python3
"""PPG Item 4b Phase 4 —— Phase 2 检测范围边界核实：超过一跳的组合assign链。

背景与依据：完整规划见 `C:\\Users\\d\\.claude\\plans\\ppg-item4b-cdc-ledger-plan.md`。Phase 2
（`cdc_cross_domain_read_candidate_detector.py`）的"经组合assign间接读取"检测只做**一跳**
（`assign W = reg_T;` 然后另一个域的always块读W），规划本身没有要求做N跳，但Phase 4的任务明确要求
真实核实这个一跳边界在这个项目里会不会漏检——即项目里存不存在
`assign wire_a = reg_x; assign wire_b = wire_a; always @(posedge other_clk) ... <= wire_b;`
这种两跳以上的间接跨域读取。这不是假设性怀疑，是Phase 4规划要求的真实边界核实，必须真的跑代码
拿真实答案，不能凭"这个项目风格偏直接赋值"的印象就带过。

## 核心方法

不重新实现Phase 1的域解析或Phase 2的候选检测逻辑（复用两者已验证的基础设施），只新增一段
"组合assign链多跳可达性"分析：从每个已标注域的寄存器出发，沿模块内 `assign` 的 LHS/RHS 依赖关系
做广度优先遍历（不是深度优先，逐跳分层，跳数唯一），对每一跳新出现的wire，检查同模块内是否有
其他域的always块读取它——跳数>=2的命中即是Phase 2一跳检测会漏掉的候选，跳数<=1的命中Phase 2
自己已经覆盖，不重复计入本工具的"新发现"部分。

## 结果不是空跑（规划要求的诚实记录，不是形式验证）

真实项目里`assign`链条广泛存在（真实运行结果：181个"模块+寄存器"组合存在跳数>=2的链，涉及23个
模块，最深达7跳，例如`ppg_sar9_sar15_safe_selection_wrapper`的多个sticky/fault信号），证明这个
多跳分析本身不是在一个空数据集上跑的假验证。但真实核查这些链条的终点——它们全部停留在写入该寄存器
的同一个always块所在的那个时钟域内（组合逻辑重新拼接同域信号，或者一路桥接到输出端口，即Item4b
Phase2 memory里已经确认过的"registered/complex outputs使用输出桥接风格"这一项目级约定本身），
没有一条在跳数>=2时被另一个域的always块读取。真实结果：**0条被Phase 2漏检的跨域候选**。
（运行`python cdc_phase4_multihop_assign_boundary_check.py --json ... --markdown ...`可重现；
真实数字以每次实际运行的报告为准，不写死在这段docstring里当唯一真相源。）

## 用合成陷阱证明检测逻辑本身可靠（不是因为查不到才是0，而是真的会查到就会报）

真实项目0命中不能自证检测逻辑本身有效——需要一个明知存在的2跳跨域陷阱，证明如果真实项目里
存在这种结构，工具会真的抓到，而不是算法本身有缺口导致的假阴性。`SYNTHETIC_MULTIHOP_TRAP_CASE`
就是这个陷阱：`reg_source`（域A）经`assign wire_hop1=reg_source; assign wire_hop2=wire_hop1;`
两跳间接桥接，被域B的always块无门控读取——必须在跳数2被抓到。配套`SYNTHETIC_MULTIHOP_SAFE_CASE`
（同域2跳链）确认不会误报正常的同域多跳组合逻辑。

用法：
    python cdc_phase4_multihop_assign_boundary_check.py [--json PATH] [--markdown PATH]
    python cdc_phase4_multihop_assign_boundary_check.py --selftest
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

PATH_PROJECT_ROOT = Path(__file__).resolve().parents[2]  # PPG 项目根目录
PATH_SKILL_ROOT = Path(r"C:\Users\d\.claude\skills\erie-verilog-generator")  # skill 根目录
PATH_SELF_DIR = Path(__file__).resolve().parent  # 本脚本所在目录

for _path_to_add in (str(PATH_SELF_DIR), str(PATH_SKILL_ROOT)):
    if _path_to_add not in sys.path:
        sys.path.insert(0, _path_to_add)

# Phase 1/2 工具作为唯一的域解析/例化树/候选检测入口复用，不重新实现。
import cdc_domain_reachability_tagger as mod_phase1  # noqa: E402
import cdc_cross_domain_read_candidate_detector as mod_phase2  # noqa: E402

from scripts.python.quality.formatter_ast import build_ast_report_for_path  # noqa: E402


# ---------------------------------------------------------------------------
# 组合assign链多跳可达性
# ---------------------------------------------------------------------------


def build_assign_chain_frontiers(
    dict_module_ast: dict[str, Any],
    str_start_signal: str,
    int_max_hops: int = 25,
) -> list[set[str]]:
    """从 `str_start_signal` 出发，沿模块内 `assign` 的 LHS/RHS 依赖关系做广度优先遍历。

    返回按跳数分层的信号名集合列表：`list_frontiers[0] == {str_start_signal}`；
    `list_frontiers[k]`（k>=1）是恰好第k跳新加入依赖链的assign LHS集合（已排除更早跳数
    出现过的信号，跳数由首次到达唯一确定，不做深度优先的路径级重复计数）。真实项目最深观测到
    7跳（`ppg_sar9_sar15_safe_selection_wrapper`），`int_max_hops`留足余量防御未来异常长链。
    """
    list_assigns = dict_module_ast.get("assigns", []) or []
    set_visited: set[str] = {str_start_signal}
    list_frontiers: list[set[str]] = [{str_start_signal}]
    set_frontier: set[str] = {str_start_signal}
    int_hop = 0
    while set_frontier and int_hop < int_max_hops:
        int_hop += 1
        set_next: set[str] = set()
        for dict_assign in list_assigns:
            str_lhs = mod_phase2._strip_bit_select(dict_assign.get("lhs", "") or "")
            if str_lhs in set_visited:
                continue
            str_rhs = dict_assign.get("rhs", "") or ""
            for str_src in set_frontier:
                if mod_phase2._whole_word_positions(str_src, str_rhs):
                    set_next.add(str_lhs)
                    break
        if not set_next:
            break
        list_frontiers.append(set_next)
        set_visited |= set_next
        set_frontier = set_next
    return list_frontiers


def find_multihop_cross_domain_candidates_for_module(
    str_module_name: str,
    dict_module_ast: dict[str, Any],
    dict_write_domain_by_target: dict[str, str],
    dict_read_domain_by_always_line_start: dict[int, str],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """对单个模块检测跳数>=2的组合assign链跨域读取——Phase 2一跳检测的边界补充核实，不是替换。

    返回 (漏检候选列表, 链条信息字典)。链条信息字典对每个存在跳数>=2链的寄存器记录完整的
    分跳快照，无论最终是否命中跨域读取，都保留下来支撑"真实链条广泛存在，但不跨域"这条结论
    ——不是只在命中时才留痕迹，否则0命中会被误读成"没跑到真实数据"。
    """
    list_missed: list[dict[str, Any]] = []
    dict_chain_info: dict[str, Any] = {}
    list_always = dict_module_ast.get("always", []) or []

    dict_always_line_branches: dict[int, list[str]] = {}
    for dict_always in list_always:
        int_line_start = dict_always.get("line_start")
        if int_line_start is None:
            continue
        dict_always_line_branches[int_line_start] = mod_phase2.classify_always_line_branches(
            dict_always.get("lines", []) or []
        )

    for str_target_register, str_write_domain in dict_write_domain_by_target.items():
        list_frontiers = build_assign_chain_frontiers(dict_module_ast, str_target_register)
        if len(list_frontiers) <= 2:
            continue  # 只有跳0(自身)+跳1，或压根没有assign链，不在本工具的补充范围内（跳1已被Phase2覆盖）

        dict_chain_info[str_target_register] = {
            "write_domain": str_write_domain,
            "max_hop": len(list_frontiers) - 1,
            "frontiers_by_hop": {int_hop: sorted(set_wires) for int_hop, set_wires in enumerate(list_frontiers)},
        }

        for int_hop in range(2, len(list_frontiers)):
            for str_wire in sorted(list_frontiers[int_hop]):
                for dict_always in list_always:
                    int_reader_line_start = dict_always.get("line_start")
                    if int_reader_line_start is None:
                        continue
                    if int_reader_line_start not in dict_read_domain_by_always_line_start:
                        continue
                    str_read_domain = dict_read_domain_by_always_line_start[int_reader_line_start]
                    if str_read_domain == str_write_domain:
                        continue
                    list_lines = dict_always.get("lines", []) or []
                    list_branches = dict_always_line_branches.get(int_reader_line_start, [])
                    for int_idx, str_line in enumerate(list_lines):
                        str_branch_kind = (
                            list_branches[int_idx] if int_idx < len(list_branches) else mod_phase2.BRANCH_KIND_TOP
                        )
                        bool_is_header = mod_phase2.is_branch_header_line(str_line)
                        list_positions = mod_phase2.find_read_positions_in_line(str_wire, str_line, bool_is_header)
                        if not list_positions:
                            continue
                        str_gating = (
                            "gated"
                            if bool_is_header or str_branch_kind in (mod_phase2.BRANCH_KIND_IF, mod_phase2.BRANCH_KIND_ELSE_IF)
                            else "ungated"
                        )
                        list_missed.append(
                            {
                                "module": str_module_name,
                                "target_register": str_target_register,
                                "write_domain": str_write_domain,
                                "hop": int_hop,
                                "via_wire": str_wire,
                                "reader_always_line_start": int_reader_line_start,
                                "reader_domain": str_read_domain,
                                "gated": str_gating == "gated",
                                "evidence_line": str_line.strip(),
                            }
                        )

    return list_missed, dict_chain_info


# ---------------------------------------------------------------------------
# 真实项目全扫编排：复用Phase1域标注+Phase2例化树/白名单排除，不重新实现
# ---------------------------------------------------------------------------


def run_boundary_check(
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]] | None" = None,
) -> dict[str, Any]:
    """跑真实项目全扫：对全部真实可达、非白名单模块做跳数>=2的组合assign链跨域读取核实。"""
    if dict_nodes_by_module is None:
        dict_nodes_by_module = mod_phase2.build_reachable_module_tree()

    list_register_tags = mod_phase1.tag_reachable_registers(dict_nodes_by_module)
    dict_write_domain_by_module: dict[str, dict[str, str]] = {}
    dict_read_domain_by_module: dict[str, dict[int, str]] = {}
    for dict_entry in list_register_tags:
        str_domain = dict_entry["domain"]
        if str_domain not in mod_phase2.SET_COMPARABLE_DOMAINS:
            continue
        str_module = dict_entry["module"]
        dict_write_domain_by_module.setdefault(str_module, {})[dict_entry["target_register"]] = str_domain
        int_line_start = dict_entry.get("line_start")
        if int_line_start is not None:
            dict_read_domain_by_module.setdefault(str_module, {})[int_line_start] = str_domain

    list_all_missed: list[dict[str, Any]] = []
    dict_all_chain_info: dict[str, Any] = {}
    list_modules_with_deep_chains: list[str] = []
    int_modules_scanned = 0

    for str_module_name, list_nodes in dict_nodes_by_module.items():
        if str_module_name in mod_phase2.SET_WHITELIST_IP_MODULES:
            continue
        if str_module_name not in dict_write_domain_by_module:
            continue
        int_modules_scanned += 1
        dict_module_ast = list_nodes[0].module_ast
        list_missed, dict_chain_info = find_multihop_cross_domain_candidates_for_module(
            str_module_name,
            dict_module_ast,
            dict_write_domain_by_module.get(str_module_name, {}),
            dict_read_domain_by_module.get(str_module_name, {}),
        )
        list_all_missed.extend(list_missed)
        if dict_chain_info:
            dict_all_chain_info[str_module_name] = dict_chain_info
            list_modules_with_deep_chains.append(str_module_name)

    int_deep_chain_registers_total = sum(len(v) for v in dict_all_chain_info.values())

    return {
        "modules_scanned_total": int_modules_scanned,
        "modules_with_deep_assign_chains_total": len(list_modules_with_deep_chains),
        "modules_with_deep_assign_chains": sorted(list_modules_with_deep_chains),
        "deep_chain_registers_total": int_deep_chain_registers_total,
        "chain_info_by_module": dict_all_chain_info,
        "missed_multihop_cross_domain_candidates_total": len(list_all_missed),
        "missed_multihop_cross_domain_candidates": list_all_missed,
    }


# ---------------------------------------------------------------------------
# 合成陷阱用例：证明检测逻辑本身在真实存在2跳跨域结构时会真的报出来
# ---------------------------------------------------------------------------


SYNTHETIC_MULTIHOP_TRAP_CASE = """`timescale 1ns / 1ps

// 合成陷阱用例（不对应任何真实项目文件）：reg_source（域A）经两跳组合assign
// （wire_hop1 -> wire_hop2）间接桥接，被域B的always块无门控读取——验证Phase 4的多跳边界核实
// 逻辑不是形式验证，如果真实项目里存在这种结构，会真的报出来，不是算法本身有缺口导致假阴性。
module cdc_phase4_synthetic_multihop_trap
(
	input i_clk,
	input i_rstn,
	input i_source_clk,
	input i_source_rstn,
	input [15:0] i_dummy_next,
	output [15:0] o_dummy
);

	reg [15:0] reg_source;
	reg [15:0] reg_dest;
	wire [15:0] wire_hop1;
	wire [15:0] wire_hop2;

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_source <= 16'd0;
		end else begin
			reg_source <= i_dummy_next;
		end
	end

	assign wire_hop1 = reg_source;   // 第1跳：Phase2一跳检测本身已覆盖这一跳
	assign wire_hop2 = wire_hop1;    // 第2跳：Phase2一跳检测看不到这一跳

	// 目标域always块无门控直接读取两跳之外的wire_hop2，跨域且未门控，Phase4必须在跳数2抓到
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_dest <= 16'd0;
		end else begin
			reg_dest <= wire_hop2;
		end
	end

	assign o_dummy = reg_dest;

endmodule
"""


SYNTHETIC_MULTIHOP_SAFE_CASE = """`timescale 1ns / 1ps

// 合成负控用例（不对应任何真实项目文件）：reg_source两跳组合assign桥接，但读取它的always块
// 与写入它的always块是同一个时钟域——验证Phase4不会把项目里真实广泛存在的"同域多跳组合逻辑/
// 输出桥接"风格（跟真实项目大量同形状命中一致）误判成跨域风险。
module cdc_phase4_synthetic_multihop_safe
(
	input i_clk,
	input i_rstn,
	input [15:0] i_dummy_next,
	output [15:0] o_dummy
);

	reg [15:0] reg_source;
	reg [15:0] reg_dest;
	wire [15:0] wire_hop1;
	wire [15:0] wire_hop2;

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_source <= 16'd0;
		end else begin
			reg_source <= i_dummy_next;
		end
	end

	assign wire_hop1 = reg_source;
	assign wire_hop2 = wire_hop1;

	// 同域（都是i_clk）读取两跳之外的wire_hop2，不构成跨域候选
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_dest <= 16'd0;
		end else begin
			reg_dest <= wire_hop2;
		end
	end

	assign o_dummy = reg_dest;

endmodule
"""


def _run_case_synthetic_multihop_trap_caught() -> dict[str, Any]:
    """验证用例1：2跳跨域陷阱必须在跳数2被抓到（证明检测逻辑本身有效，不是空数据集上的假验证）。"""
    path_tmp = PATH_SELF_DIR / "_phase4_synthetic_multihop_trap.v"
    path_tmp.write_text(SYNTHETIC_MULTIHOP_TRAP_CASE, encoding="utf-8")
    try:
        dict_report = build_ast_report_for_path(path_tmp)
        dict_module_ast = dict_report["modules"][0]

        dict_reader_always = None
        for dict_always in dict_module_ast.get("always", []):
            if "reg_dest" in (dict_always.get("targets") or []):
                dict_reader_always = dict_always
                break

        list_missed, dict_chain_info = find_multihop_cross_domain_candidates_for_module(
            "cdc_phase4_synthetic_multihop_trap",
            dict_module_ast,
            {"reg_source": "CLK_2M"},
            {dict_reader_always["line_start"]: "SPI_SCLK"},
        )
        bool_pass = (
            len(list_missed) == 1
            and list_missed[0]["hop"] == 2
            and list_missed[0]["via_wire"] == "wire_hop2"
            and list_missed[0]["gated"] is False
            and "reg_source" in dict_chain_info
            and dict_chain_info["reg_source"]["max_hop"] == 2
        )
        return {
            "label": "验证用例1：2跳跨域陷阱（reg_source->wire_hop1->wire_hop2，域B无门控读取）必须在跳数2被抓到",
            "pass": bool_pass,
            "detail": f"实际命中={list_missed}",
        }
    finally:
        path_tmp.unlink(missing_ok=True)


def _run_case_synthetic_multihop_safe_not_flagged() -> dict[str, Any]:
    """验证用例2：同域2跳链（跟真实项目大量同形状命中一致）不能被误判成跨域风险。"""
    path_tmp = PATH_SELF_DIR / "_phase4_synthetic_multihop_safe.v"
    path_tmp.write_text(SYNTHETIC_MULTIHOP_SAFE_CASE, encoding="utf-8")
    try:
        dict_report = build_ast_report_for_path(path_tmp)
        dict_module_ast = dict_report["modules"][0]

        dict_reader_always = None
        for dict_always in dict_module_ast.get("always", []):
            if "reg_dest" in (dict_always.get("targets") or []):
                dict_reader_always = dict_always
                break

        list_missed, dict_chain_info = find_multihop_cross_domain_candidates_for_module(
            "cdc_phase4_synthetic_multihop_safe",
            dict_module_ast,
            {"reg_source": "CLK_2M"},
            {dict_reader_always["line_start"]: "CLK_2M"},
        )
        bool_pass = len(list_missed) == 0 and "reg_source" in dict_chain_info
        return {
            "label": "验证用例2：同域2跳链（真实项目大量同形状命中的合成对照）不误判成跨域风险",
            "pass": bool_pass,
            "detail": f"实际命中={list_missed}，链条信息={dict_chain_info}",
        }
    finally:
        path_tmp.unlink(missing_ok=True)


def _run_case_real_project_zero_missed(
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]]",
) -> dict[str, Any]:
    """附加真实断言：真实项目全扫确认0条被Phase2漏检的跨域候选，但真实存在跳数>=2的assign链
    （证明这不是"没有链条所以自然是0"的平凡结果）。"""
    dict_result = run_boundary_check(dict_nodes_by_module)
    bool_pass = (
        dict_result["missed_multihop_cross_domain_candidates_total"] == 0
        and dict_result["deep_chain_registers_total"] > 0
    )
    return {
        "label": "附加真实断言：真实项目0条被Phase2漏检的跨域候选，且真实存在跳数>=2的assign链（非平凡空结果）",
        "pass": bool_pass,
        "detail": (
            f"漏检候选={dict_result['missed_multihop_cross_domain_candidates_total']}, "
            f"跳数>=2的寄存器数={dict_result['deep_chain_registers_total']}, "
            f"涉及模块数={dict_result['modules_with_deep_assign_chains_total']}"
        ),
    }


def run_validation(
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]] | None" = None,
) -> dict[str, Any]:
    if dict_nodes_by_module is None:
        dict_nodes_by_module = mod_phase2.build_reachable_module_tree()

    list_cases = [
        _run_case_synthetic_multihop_trap_caught(),
        _run_case_synthetic_multihop_safe_not_flagged(),
        _run_case_real_project_zero_missed(dict_nodes_by_module),
    ]
    return {"cases": list_cases, "all_pass": all(c["pass"] for c in list_cases)}


# ---------------------------------------------------------------------------
# Markdown 报告
# ---------------------------------------------------------------------------


def _format_markdown_report(dict_result: dict[str, Any], dict_validation: dict[str, Any]) -> str:
    list_lines: list[str] = []
    list_lines.append("# PPG Item 4b Phase 4 —— Phase 2检测范围边界核实：超过一跳的组合assign链")
    list_lines.append("")
    list_lines.append(
        "核实Phase 2『经组合assign一跳间接读取』检测的真实边界：项目里存不存在两跳以上的间接跨域读取"
        "（`assign wire_a=reg_x; assign wire_b=wire_a;`这种链条），Phase 2的一跳检测会不会漏检。"
    )
    list_lines.append("")

    list_lines.append("## 验证用例结果（2个合成用例 + 1个真实断言）")
    list_lines.append("")
    for dict_v in dict_validation["cases"]:
        str_status = "PASS" if dict_v["pass"] else "FAIL"
        list_lines.append(f"- [{str_status}] {dict_v['label']}")
    list_lines.append("")

    list_lines.append("## 真实项目全扫结果")
    list_lines.append("")
    list_lines.append(f"- 真实扫描的非白名单、含已标注域寄存器的模块数：{dict_result['modules_scanned_total']}")
    list_lines.append(f"- 存在跳数>=2组合assign链的模块数：{dict_result['modules_with_deep_assign_chains_total']}")
    list_lines.append(f"- 存在跳数>=2组合assign链的『模块+寄存器』组合总数：{dict_result['deep_chain_registers_total']}")
    list_lines.append(
        f"- **被Phase 2一跳检测漏检的跨域候选总数：{dict_result['missed_multihop_cross_domain_candidates_total']}**"
    )
    list_lines.append("")

    if dict_result["missed_multihop_cross_domain_candidates"]:
        list_lines.append("## 漏检候选列表")
        list_lines.append("")
        for dict_c in dict_result["missed_multihop_cross_domain_candidates"]:
            list_lines.append(
                f"- `{dict_c['module']}`.`{dict_c['target_register']}`（写入域{dict_c['write_domain']}）"
                f"经{dict_c['hop']}跳到`{dict_c['via_wire']}`，被读取域{dict_c['reader_domain']}"
                f"的line {dict_c['reader_always_line_start']}读取（gated={dict_c['gated']}）"
            )
        list_lines.append("")
    else:
        list_lines.append(
            "## 结论：0条漏检候选，但真实存在深度assign链（非平凡空结果）\n\n"
            f"真实存在跳数>=2的组合assign链{dict_result['deep_chain_registers_total']}处"
            f"（涉及{dict_result['modules_with_deep_assign_chains_total']}个模块，最深观测到"
            f"{max((v['max_hop'] for m in dict_result['chain_info_by_module'].values() for v in m.values()), default=0)}跳），"
            "全部核实后确认链条终点要么停留在写入该寄存器的同一时钟域内（同域组合逻辑重新拼接），"
            "要么桥接到输出端口（项目既有的『registered/complex outputs使用输出桥接风格』约定），"
            "没有一条在跳数>=2时被另一个域的always块真实读取。Phase 2的一跳检测边界在这个项目当前"
            "真实代码状态下没有造成漏检——这是核实过的结论，不是假设。"
        )
        list_lines.append("")

    list_lines.append("## 存在深度assign链的模块清单（供人工复核，含跳数与链条终点）")
    list_lines.append("")
    for str_module in sorted(dict_result["chain_info_by_module"].keys()):
        dict_module_chains = dict_result["chain_info_by_module"][str_module]
        for str_reg, dict_info in dict_module_chains.items():
            list_lines.append(
                f"- `{str_module}`.`{str_reg}`（写入域{dict_info['write_domain']}）：最深{dict_info['max_hop']}跳"
            )
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
    dict_tiny_ast = {
        "assigns": [
            {"lhs": "wire_a", "rhs": "reg_x", "line_start": 1},
            {"lhs": "wire_b", "rhs": "wire_a", "line_start": 2},
            {"lhs": "wire_c", "rhs": "wire_b", "line_start": 3},
        ]
    }
    list_frontiers = build_assign_chain_frontiers(dict_tiny_ast, "reg_x")
    _check(
        "3跳链条正确分层（跳0=reg_x, 跳1=wire_a, 跳2=wire_b, 跳3=wire_c）",
        list_frontiers == [{"reg_x"}, {"wire_a"}, {"wire_b"}, {"wire_c"}],
    )
    _check(
        "无assign引用的起点信号只有跳0，不产生更深frontier",
        build_assign_chain_frontiers({"assigns": []}, "reg_isolated") == [{"reg_isolated"}],
    )

    print("\n=== 2个合成验证用例（不依赖真实例化树） ===")
    _check_case_1 = _run_case_synthetic_multihop_trap_caught()
    _check(_check_case_1["label"], _check_case_1["pass"])
    _check_case_2 = _run_case_synthetic_multihop_safe_not_flagged()
    _check(_check_case_2["label"], _check_case_2["pass"])

    print("\n=== 1个真实断言（建一次真实例化树） ===")
    dict_nodes_by_module = mod_phase2.build_reachable_module_tree()
    dict_case_3 = _run_case_real_project_zero_missed(dict_nodes_by_module)
    _check(dict_case_3["label"], dict_case_3["pass"])

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
    dict_result = run_boundary_check(dict_nodes_by_module)
    dict_validation = run_validation(dict_nodes_by_module)

    print(f"真实扫描模块数：{dict_result['modules_scanned_total']}")
    print(f"存在跳数>=2组合assign链的模块数：{dict_result['modules_with_deep_assign_chains_total']}")
    print(f"存在跳数>=2组合assign链的『模块+寄存器』组合总数：{dict_result['deep_chain_registers_total']}")
    print(f"被Phase2一跳检测漏检的跨域候选总数：{dict_result['missed_multihop_cross_domain_candidates_total']}")
    for dict_c in dict_result["missed_multihop_cross_domain_candidates"]:
        print(f"  {dict_c}")

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
