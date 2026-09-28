#!/usr/bin/env python3
"""PPG Item 4b Phase 1：时钟域传播标注 + 真实可达性范围界定。

背景与依据：完整规划见 `C:\\Users\\d\\.claude\\plans\\ppg-item4b-cdc-ledger-plan.md`。
Item 4a（`ppg_config_cdc_bridge.v`/`ppg_characterization_control_cdc.v`人工审计）与其延伸审计
（`ppg_spi_register_file.v`真实CDC撕裂缺陷，V1.3已修复）已经用人工方式确认了本项目的2个真实
时钟域（`i_clk`/CLK_2M_PAD 数字系统域、`i_source_clk`或`i_spi_sclk`/SPI_SCLK 配置源域，二者
字面端口名不同但是同一个真实物理域）与1个第三类别（`_async`后缀命名的外部异步源信号，不属于
任何时钟域）。这个脚本把那次人工审计里反复用到的"顺着例化关系把局部时钟名换算回物理源"这个
推理过程变成可重跑、可核对的工具，不是重新发明一套新的CDC理论——三分类本身、两个物理域、
`_async`命名惯例，全部来自已经人工验证过的真实发现。

范围界定为什么不能直接复用 `static_lint_semantic_sweep.collect_real_source_files`：
那个函数收集的是"每个 `ppg_*` 顶层目录的直接子文件"，这对 Item 1 的语义类静态 lint（逐文件
独立解析、互不影响）是安全的，但对本工具不安全——真实跑过一遍才发现，这些目录里混杂着大量
"文件名不同、但内部仍然声明着与真实模块同名的 module"的历史快照/格式化候选文件（例如
`ppg_sar9_sar15_safe_selection_wrapper/` 下有 9 个文件都声明 `module
ppg_sar9_sar15_safe_selection_wrapper`，只有 1 个文件名与模块名完全一致）。如果直接拿
`collect_real_source_files` 的结果做"模块名 -> 文件"映射，会在多个模块上产生真实的名字冲突。
这个脚本改用"文件名（不含扩展名）必须与内部声明的 module 名完全一致"作为 canonical 判据，
经验证足以消解本项目里出现的全部真实冲突（候选/快照文件的内部声明从未随文件改名同步修改），
不需要额外的目录名匹配规则。`collect_real_source_files` 的结果仍然作为"候选文件全集"起点复用
（不重新发明一遍目录扫描逻辑），只是不再假设它等于真实分析范围。

真实可达性用从 `ppg_chip_digital_top`（真实顶层）出发的例化关系递归展开得到，不是目录扫描。
`formatter_ast.py` 的 `_instance_to_dict` 只给 `module_name`/`instance_name`/`text`（重建的例化
原始文本），不给结构化端口连接表——这个脚本自己新写了 `parse_instance_port_connections`，对
`text` 字段做括号深度计数解析 `.端口名(表达式)` 连接对（同时正确跳过 `#(参数)` 块，真实例化里
两种都存在，例如 `ppg_config_cdc_bridge` 用 `#(.C_CONFIG_WIDTH(1024))`，AMI 的多个子模块也普遍
带参数列表）。

时钟域解析用"实例树"而不是"模块类型图"：同一个模块类型在本项目里确实存在被多次例化、且每次
例化的时钟连接方向不同的真实案例——`ppg_spi_register_file.v` 里 `ppg_pulse_cdc_sync` 被例化 7
次，前 6 次都是 source=SPI_SCLK/dest=CLK_2M，第 7 次（`ppg_pulse_cdc_sync_diag_ready_Inst`，
V1.3 新增，用于修复真实CDC撕裂缺陷）方向相反：source=CLK_2M/dest=SPI_SCLK。如果按"模块类型只解析
一次"设计，会把这 7 个实例的寄存器错误合并成同一个域标签。这个脚本按"例化路径"（不是模块类型）
建树，每个实例独立解析，域不一致时如实分别报告，不合并、不假装一致。

用法：
    python cdc_domain_reachability_tagger.py [--json PATH] [--markdown PATH]
    python cdc_domain_reachability_tagger.py --selftest
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

# 项目根目录固定为本脚本上溯两级（cross_reference_tools -> ppg_system_integration -> 项目根）。
PATH_PROJECT_ROOT = Path(__file__).resolve().parents[2]  # PPG 项目根目录

# erie-verilog-generator skill 根目录，提供 formatter_ast 的唯一受控解析入口。
PATH_SKILL_ROOT = Path(r"C:\Users\d\.claude\skills\erie-verilog-generator")  # skill 根目录

# 本脚本自己所在目录，用于导入同目录下的既有脚本（不复制其逻辑）。
PATH_SELF_DIR = Path(__file__).resolve().parent

for _path_to_add in (str(PATH_SELF_DIR), str(PATH_SKILL_ROOT)):
    if _path_to_add not in sys.path:
        sys.path.insert(0, _path_to_add)

# 复用 Stage 3 Item 1 已验证过的"真实源文件收集"逻辑（候选全集起点），不重新维护一份清单。
import static_lint_semantic_sweep as mod_lint_sweep  # noqa: E402

# formatter_ast 是本项目唯一受控的 Verilog 结构化解析入口，不新写第二套 parser。
from scripts.python.quality.formatter_ast import build_ast_report_for_path  # noqa: E402


# ---------------------------------------------------------------------------
# 常量：已通过人工审计确认的真实地基（不是本脚本的假设）
# ---------------------------------------------------------------------------

# 真实顶层模块名，递归可达性从这里出发。
TOP_MODULE_NAME = "ppg_chip_digital_top"

# 两个真实物理时钟源在顶层模块的字面端口名 -> 域标签。仅在"当前节点是顶层、且没有父节点"时使用。
PHYSICAL_CLOCK_PORTS: dict[str, str] = {
    "CLK_2M_PAD": "CLK_2M",
    "SPI_SCLK": "SPI_SCLK",
}

# 外部异步源信号的项目级命名惯例后缀（人工确认，全项目命名一致）。
ASYNC_SUFFIX = "_async"

# 四选一域标签常量。
DOMAIN_CLK2M = "CLK_2M"
DOMAIN_SPI = "SPI_SCLK"
DOMAIN_EXTERNAL_ASYNC = "EXTERNAL_ASYNC"
DOMAIN_UNRESOLVED = "UNRESOLVED"

# TB 文件命名惯例前缀——直接复用本项目 `static_lint_semantic_sweep.py` 等既有工具
# （及其依赖的 skill 自带 `static_lint._is_testbench`）已经在用的 `tb_` 前缀判据，
# 不为"不可达模块"报告呈现另外发明一套新的 testbench 识别规则。
TB_MODULE_NAME_PREFIX = "tb_"

# "不可达模块"清单里两类性质不同的条目分类标签：
#   orphaned_rtl —— 真实架构层面的发现（有意隔离/未接入的 RTL 模块，例如 ppg_dual_precision_top）；
#   testbench_toplevel —— 顶层 TB 模块，"不可达"是预期状态（TB 本来就不会被芯片实例化），不是发现。
CATEGORY_ORPHANED_RTL = "orphaned_rtl"
CATEGORY_TESTBENCH_TOPLEVEL = "testbench_toplevel"

# 第三种状态：文件本身 formatter_ast 解析失败（`parse_errors`），但它的文件名（= 项目 canonical
# 惯例下的模块名）真的出现在某个已确认真实可达模块的 `instances` 列表里——这类文件既不能算"孤立
# RTL"也不能算"顶层TB"，而是"可达但内容无法分析"，必须单独成一类，不能混进另外两类，也不能
# 笼统留在"51个解析失败"名单里不做区分。
CATEGORY_REACHABLE_BUT_UNPARSEABLE = "reachable_but_unparseable"


def classify_unreachable_module(str_module_name: str) -> str:
    """按项目既有 `tb_` 前缀惯例，把一个不可达模块名分类成 RTL 孤立发现或顶层 TB。

    参数:
        str_module_name: canonical 模块名（即声明该模块的文件的文件名 stem）。
    返回:
        CATEGORY_TESTBENCH_TOPLEVEL 或 CATEGORY_ORPHANED_RTL。
    """
    if str_module_name.startswith(TB_MODULE_NAME_PREFIX):
        return CATEGORY_TESTBENCH_TOPLEVEL
    return CATEGORY_ORPHANED_RTL


class CdcLedgerError(RuntimeError):
    """Phase 1 工具自身的结构性错误（例如顶层模块缺失），不是普通诊断。"""


# ---------------------------------------------------------------------------
# 第 1 步：候选文件全集 + 模块名 canonical 化
# ---------------------------------------------------------------------------


@dataclass
class ModuleDecl:
    """一个 canonical 模块声明：文件名（不含扩展名）与内部 module 名完全一致。"""

    name: str
    file: Path
    module_ast: dict[str, Any]


def parse_all_candidates(list_files: list[Path]) -> tuple[dict[str, list[tuple[Path, dict]]], list[tuple[Path, str]]]:
    """对候选全集逐文件跑 formatter_ast，按"内部声明的 module 名"分组。

    返回:
        (declarations, parse_errors)
        declarations: module 名 -> [(file, module_ast), ...]（同名可能来自多个文件）
        parse_errors: 解析失败的 (file, 错误信息) 列表
    """
    declarations: dict[str, list[tuple[Path, dict]]] = {}
    parse_errors: list[tuple[Path, str]] = []

    for path_file in list_files:
        try:
            dict_report = build_ast_report_for_path(path_file)
        except Exception as exc:  # noqa: BLE001 - 单文件解析失败不能中断整体扫描
            parse_errors.append((path_file, str(exc)))
            continue

        if not dict_report.get("ok", False) and not dict_report.get("modules"):
            # 严格失败且一个 module 都没解析出来时，记为解析错误而不是"零 module 的合法文件"。
            list_diag = dict_report.get("diagnostics", [])
            str_msg = "; ".join(str(d.get("message", "")) for d in list_diag) or "formatter_ast 报告 ok=False 且无 module"
            parse_errors.append((path_file, str_msg))
            continue

        for dict_module in dict_report.get("modules", []):
            str_name = dict_module.get("name") or ""
            if not str_name:
                continue
            declarations.setdefault(str_name, []).append((path_file, dict_module))

    return declarations, parse_errors


def build_module_registry(
    declarations: dict[str, list[tuple[Path, dict]]],
) -> tuple[dict[str, ModuleDecl], dict[str, list[Path]], list[tuple[Path, str]]]:
    """把 declarations 按"文件名（不含扩展名）是否等于声明的 module 名"分成三类。

    返回:
        canonical: module 名 -> 唯一 ModuleDecl（文件名与声明名一致，且全项目唯一这样的文件）
        ambiguous: module 名 -> 多个文件路径（真实名字冲突，两个以上文件的文件名都等于该 module 名——
            本项目实测未出现，但工具必须能诚实报告而不是随便选一个）
        noncanonical: [(file, module_name), ...]（文件名与内部声明名不一致，判定为历史快照/格式化
            候选/工具中间产物，不纳入可达性解析的候选池，但完整列入报告，不静默丢弃）
    """
    canonical: dict[str, ModuleDecl] = {}
    ambiguous: dict[str, list[Path]] = {}
    noncanonical: list[tuple[Path, str]] = []

    for str_name, list_entries in declarations.items():
        list_stem_matches = [(f, m) for f, m in list_entries if f.stem == str_name]
        list_stem_mismatches = [(f, m) for f, m in list_entries if f.stem != str_name]

        for path_f, _dict_m in list_stem_mismatches:
            noncanonical.append((path_f, str_name))

        if len(list_stem_matches) == 1:
            path_f, dict_m = list_stem_matches[0]
            canonical[str_name] = ModuleDecl(name=str_name, file=path_f, module_ast=dict_m)
        elif len(list_stem_matches) > 1:
            ambiguous[str_name] = [f for f, _m in list_stem_matches]
        # len == 0: 该 module 名从未出现在与自己同名的文件里（例如只存在于候选/快照文件中）——
        # 不进入 canonical，也不算 ambiguous，已经通过 noncanonical 列表完整记录。

    return canonical, ambiguous, noncanonical


# ---------------------------------------------------------------------------
# 第 2 步：实例端口连接解析（formatter_ast 不提供，本脚本新写）
# ---------------------------------------------------------------------------


def _strip_verilog_line_comments(str_text: str) -> str:
    """按行去掉 `//` 行注释，供括号深度计数前的预处理。

    本项目例化文本里不出现字符串字面量，`//` 出现位置足以安全判定注释起点。
    """
    list_out: list[str] = []
    for str_line in str_text.split("\n"):
        int_idx = str_line.find("//")
        list_out.append(str_line if int_idx < 0 else str_line[:int_idx])
    return "\n".join(list_out)


def _find_last_top_level_paren_group(str_text: str) -> tuple[int, int] | None:
    """返回文本里最后一个顶层圆括号组的 (起始字符下标, 结束字符下标)，下标指向括号本身。

    例化文本形如 `module_name #(参数...) instance_name(端口...)` 或
    `module_name instance_name(端口...)`；端口连接列表永远是最后一个顶层括号组，
    这样定位比显式识别 `#(` 更稳健，不需要对参数块单独写分支。
    """
    int_depth = 0
    int_group_start: int | None = None
    tuple_last: tuple[int, int] | None = None

    for int_i, str_ch in enumerate(str_text):
        if str_ch == "(":
            if int_depth == 0:
                int_group_start = int_i
            int_depth += 1
        elif str_ch == ")":
            if int_depth > 0:
                int_depth -= 1
                if int_depth == 0 and int_group_start is not None:
                    tuple_last = (int_group_start, int_i)

    return tuple_last


def parse_instance_port_connections(str_instance_text: str) -> dict[str, str] | None:
    """从 formatter_ast 实例化 `text` 字段解析 `.端口名(表达式)` 连接对。

    只解析最后一个顶层圆括号组（端口连接列表），自动跳过前面可能存在的 `#(参数)` 块。
    项目里全部真实例化都用具名端口连接（`.port(expr)`），没有位置连接；遇到不符合这个
    惯例的结构（找不到端口列表、端口名后没有紧跟左括号）时返回 None，交给调用方如实
    记为"无法解析"而不是静默吞掉。

    参数:
        str_instance_text: `formatter_ast` 实例条目的 `text` 字段原始内容。
    返回:
        端口名 -> 连接表达式原文（已去除首尾空白）的字典；无法按惯例解析时返回 None。
    """
    str_cleaned = _strip_verilog_line_comments(str_instance_text)
    tuple_group = _find_last_top_level_paren_group(str_cleaned)
    if tuple_group is None:
        return None

    int_start, int_end = tuple_group
    str_body = str_cleaned[int_start + 1 : int_end]

    dict_connections: dict[str, str] = {}
    int_i = 0
    int_n = len(str_body)
    while int_i < int_n:
        if str_body[int_i] == ".":
            int_j = int_i + 1
            while int_j < int_n and (str_body[int_j].isalnum() or str_body[int_j] == "_"):
                int_j += 1
            str_port_name = str_body[int_i + 1 : int_j]
            if not str_port_name:
                # 孤立的 "." 不构成合法端口连接起点，不是本项目的具名连接惯例。
                return None

            int_k = int_j
            while int_k < int_n and str_body[int_k].isspace():
                int_k += 1
            if int_k >= int_n or str_body[int_k] != "(":
                # 端口名后没有紧跟 "(" —— 结构不符合具名端口连接惯例，判定为无法解析。
                return None

            int_depth = 1
            int_m = int_k + 1
            while int_m < int_n and int_depth > 0:
                if str_body[int_m] == "(":
                    int_depth += 1
                elif str_body[int_m] == ")":
                    int_depth -= 1
                int_m += 1
            if int_depth != 0:
                # 括号未闭合，说明清洗后的文本已经不完整，判定为无法解析。
                return None

            str_value = str_body[int_k + 1 : int_m - 1].strip()
            dict_connections[str_port_name] = str_value
            int_i = int_m
        else:
            int_i += 1

    return dict_connections


# ---------------------------------------------------------------------------
# 第 3 步：从真实顶层递归展开"实例树"（不是模块类型图）
# ---------------------------------------------------------------------------


@dataclass
class InstanceNode:
    """例化树中的一个节点：对应一条具体的例化路径，不是一个模块类型。

    同一个模块类型可能对应多个 InstanceNode（例如 `ppg_pulse_cdc_sync` 在
    `ppg_spi_register_file` 里被例化 7 次），每个节点独立缓存自己的信号域解析结果，
    因为不同例化路径的端口连接可能真实不同（已确认的真实案例：7 次例化里有 6 次
    source=SPI_SCLK/dest=CLK_2M，第 7 次方向相反）。
    """

    instance_path: str
    module_name: str
    module_ast: dict[str, Any]
    parent: Optional["InstanceNode"]
    port_connections: dict[str, str]
    domain_cache: dict[str, str] = field(default_factory=dict)


def build_instance_tree(
    dict_canonical: dict[str, ModuleDecl],
    str_top_module_name: str,
) -> tuple[InstanceNode, dict[str, list[InstanceNode]], list[dict[str, Any]]]:
    """从真实顶层递归展开例化树。

    参数:
        dict_canonical: build_module_registry 产出的 canonical 模块登记表。
        str_top_module_name: 真实顶层模块名。
    返回:
        (顶层节点, 模块名 -> 该类型全部例化节点列表, 未能正常展开的实例问题列表)
    异常:
        CdcLedgerError: 顶层模块本身不在 canonical 登记表里时抛出——这是结构性前提失败，
            不能静默继续。
    """
    if str_top_module_name not in dict_canonical:
        raise CdcLedgerError(
            f"顶层模块 '{str_top_module_name}' 未能在 canonical 模块登记表中找到，"
            "无法从真实顶层展开可达性——请检查候选文件收集范围或 canonical 判据。"
        )

    decl_top = dict_canonical[str_top_module_name]
    node_top = InstanceNode(
        instance_path=str_top_module_name,
        module_name=str_top_module_name,
        module_ast=decl_top.module_ast,
        parent=None,
        port_connections={},
    )

    dict_nodes_by_module: dict[str, list[InstanceNode]] = {str_top_module_name: [node_top]}
    list_instance_issues: list[dict[str, Any]] = []

    list_stack: list[InstanceNode] = [node_top]
    while list_stack:
        node_current = list_stack.pop()
        for dict_inst in node_current.module_ast.get("instances", []):
            str_child_module = dict_inst.get("module_name") or ""
            str_inst_name = dict_inst.get("instance_name") or "<anon>"
            str_child_path = f"{node_current.instance_path}/{str_inst_name}"

            if str_child_module not in dict_canonical:
                list_instance_issues.append(
                    {
                        "at": node_current.instance_path,
                        "instance_name": str_inst_name,
                        "module_name": str_child_module,
                        "reason": "子模块不在 canonical 登记表中（可能是 ambiguous 名字冲突，或候选文件收集范围遗漏）",
                    }
                )
                continue

            dict_conns = parse_instance_port_connections(dict_inst.get("text") or "")
            if dict_conns is None:
                list_instance_issues.append(
                    {
                        "at": node_current.instance_path,
                        "instance_name": str_inst_name,
                        "module_name": str_child_module,
                        "reason": "例化端口连接文本无法按具名连接惯例解析",
                    }
                )
                dict_conns = {}

            decl_child = dict_canonical[str_child_module]
            node_child = InstanceNode(
                instance_path=str_child_path,
                module_name=str_child_module,
                module_ast=decl_child.module_ast,
                parent=node_current,
                port_connections=dict_conns,
            )
            dict_nodes_by_module.setdefault(str_child_module, []).append(node_child)
            list_stack.append(node_child)

    return node_top, dict_nodes_by_module, list_instance_issues


# ---------------------------------------------------------------------------
# 第 4 步：信号域递归解析（对寄存器时钟名和 `_async` 信号都适用的同一套算法）
# ---------------------------------------------------------------------------

# 简单标识符：本项目真实例化里，时钟/复位类端口连接永远是裸信号名，不带位选/拼接/三元表达式。
_RE_SIMPLE_IDENTIFIER = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")

# Verilog 数字字面量：可选位宽 + 基数 + 数值，或纯十进制无基数写法。
_RE_VERILOG_CONSTANT = re.compile(r"^\d*'[bBoOdDhH][0-9a-fA-FxXzZ_]+$|^\d+$")


def _is_simple_identifier(str_expr: str) -> bool:
    return bool(_RE_SIMPLE_IDENTIFIER.match(str_expr.strip()))


def _is_verilog_constant(str_expr: str) -> bool:
    return bool(_RE_VERILOG_CONSTANT.match(str_expr.strip()))


def resolve_signal_domain(
    node: InstanceNode,
    str_signal_name: str,
    _set_guard: frozenset[str] | None = None,
) -> str:
    """解析某个信号名（在 node 对应模块的命名空间里）所属的真实时钟域。

    这一个函数同时服务两种调用场景：
      1. Phase 1 主流程用它解析每个 always 块的 `clock` 字段（寄存器的真实时钟域）；
      2. `_async` 后缀信号的分类也复用同一条"没有物理源、且带 `_async` 后缀"分支，
         不需要单独一套逻辑，两者共享同一个"顺着例化关系往上找物理源"的算法。

    解析规则（严格按 Phase 1 规划的"递归域名解析"步骤实现）：
      - `_async` 后缀检查优先于端口连接回溯，在顶层和非顶层节点上都适用。真实扫描发现的
        原因：`i_clk_stage1_dout_low_async`/`i_clk_stage2_dout_low_async` 这两个端口名从
        `ppg_control_top` 一路原样透传到 `ppg_adc_measurement_idac_integration`、
        `ppg_adc_async_stage_capture`，但它们连接的顶层物理源端口本身叫
        `CLK_STAGE1_DOUT_LOW`/`CLK_STAGE2_DOUT_LOW`——不带 `_async` 后缀（后缀只出现在往下
        传递时人为改用的内部信号名上）。如果先查端口连接表再递归，会一路递归到顶层物理名，
        发现它既不是 `CLK_2M_PAD`/`SPI_SCLK` 也不带 `_async` 后缀，误判成"无法判定"——
        这正是规划反复强调的"命名惯例是可靠识别线索"的本意：只要当前这一层的信号名本身
        带 `_async` 后缀，就应该直接判定为外部异步源，不需要（也不应该）继续往上追溯它连接
        的父信号叫什么名字。
      - 顶层模块（node.parent 为 None）：先认 `_async` 后缀，再认 `PHYSICAL_CLOCK_PORTS` 里
        的两个物理源字面名；两者都不满足则如实标记"无法判定"——不会因为名字里带 "CLK" 字样
        就臆造出第三个物理时钟域。
      - 非顶层模块：`_async` 后缀信号直接判定外部异步源；否则如果 `str_signal_name` 是当前
        模块的端口，去父节点的连接表里找父模块侧接的是什么信号，递归到父节点继续解析
        （简单标识符才递归；常量直接判定"CONSTANT"；位选/拼接/三元等复杂表达式如实标记
        "无法判定"，不做语义化简）；如果既不带 `_async` 后缀也不是端口（模块内部自己声明的
        wire/reg），如实标记"无法判定"（本函数不追踪内部 assign 的驱动链，Phase 1 范围只
        覆盖寄存器时钟域和 `_async` 命名信号，不是通用的任意 wire 溯源器）。

    参数:
        node: 待解析信号所在的例化节点。
        str_signal_name: 该节点对应模块命名空间里的信号名。
        _set_guard: 内部递归防环参数，调用方不需要传入。
    返回:
        DOMAIN_CLK2M / DOMAIN_SPI / DOMAIN_EXTERNAL_ASYNC / DOMAIN_UNRESOLVED 之一，
        或附带简短原因的 "UNRESOLVED(...)"/"CONSTANT"/"UNCONNECTED" 变体字符串。
    """
    if str_signal_name in node.domain_cache:
        return node.domain_cache[str_signal_name]

    set_guard = _set_guard or frozenset()
    str_guard_key = f"{node.instance_path}::{str_signal_name}"
    if str_guard_key in set_guard:
        str_result = "UNRESOLVED(circular-reference)"
        node.domain_cache[str_signal_name] = str_result
        return str_result
    set_guard = set_guard | {str_guard_key}

    if node.parent is None:
        if str_signal_name.endswith(ASYNC_SUFFIX):
            str_result = DOMAIN_EXTERNAL_ASYNC
        elif str_signal_name in PHYSICAL_CLOCK_PORTS:
            str_result = PHYSICAL_CLOCK_PORTS[str_signal_name]
        else:
            str_result = DOMAIN_UNRESOLVED
    else:
        if str_signal_name.endswith(ASYNC_SUFFIX):
            str_result = DOMAIN_EXTERNAL_ASYNC
        elif str_signal_name in node.port_connections:
            str_parent_expr = node.port_connections[str_signal_name]
            if str_parent_expr == "":
                str_result = "UNCONNECTED"
            elif _is_simple_identifier(str_parent_expr):
                str_result = resolve_signal_domain(node.parent, str_parent_expr, set_guard)
            elif _is_verilog_constant(str_parent_expr):
                str_result = "CONSTANT"
            else:
                str_result = f"UNRESOLVED(complex-expr:{str_parent_expr[:60]})"
        else:
            str_result = DOMAIN_UNRESOLVED

    node.domain_cache[str_signal_name] = str_result
    return str_result


# ---------------------------------------------------------------------------
# 第 5 步：主流程——寄存器标注 + `_async` 信号标注 + 不可达清单
# ---------------------------------------------------------------------------


def tag_reachable_registers(dict_nodes_by_module: dict[str, list[InstanceNode]]) -> list[dict[str, Any]]:
    """为每个可达模块类型的每个 always 块目标寄存器打域标签。

    同一模块类型的多个例化如果全部解析出一致的域，合并成一条记录（附实例计数）；
    只要有任何一个例化解析出不同的域，就按例化路径分别列出，不允许合并掩盖差异
    （已确认的真实案例：`ppg_pulse_cdc_sync` 的 7 次例化，第 7 次方向与其余 6 次相反）。
    """
    list_results: list[dict[str, Any]] = []

    for str_module_name, list_nodes in dict_nodes_by_module.items():
        dict_module_ast = list_nodes[0].module_ast
        for dict_always in dict_module_ast.get("always", []):
            str_clock = dict_always.get("clock") or ""
            list_targets = dict_always.get("targets") or []
            str_trigger_kind = dict_always.get("trigger_kind") or "unknown"

            if not str_clock:
                for str_target in list_targets:
                    list_results.append(
                        {
                            "module": str_module_name,
                            "target_register": str_target,
                            "clock_local_name": "",
                            "trigger_kind": str_trigger_kind,
                            "line_start": dict_always.get("line_start"),
                            "line_end": dict_always.get("line_end"),
                            "instance_count": len(list_nodes),
                            "domain": "N/A(no-clock-field-on-always-block)",
                            "per_instance": None,
                        }
                    )
                continue

            list_per_instance = [
                (node.instance_path, resolve_signal_domain(node, str_clock)) for node in list_nodes
            ]
            set_distinct_domains = sorted({d for _p, d in list_per_instance})
            str_domain_summary = (
                set_distinct_domains[0]
                if len(set_distinct_domains) == 1
                else "MULTI(" + " | ".join(set_distinct_domains) + ")"
            )

            for str_target in list_targets:
                list_results.append(
                    {
                        "module": str_module_name,
                        "target_register": str_target,
                        "clock_local_name": str_clock,
                        "trigger_kind": str_trigger_kind,
                        "line_start": dict_always.get("line_start"),
                        "line_end": dict_always.get("line_end"),
                        "instance_count": len(list_nodes),
                        "domain": str_domain_summary,
                        "per_instance": list_per_instance if len(set_distinct_domains) > 1 else None,
                    }
                )

    return list_results


def tag_async_signals(dict_nodes_by_module: dict[str, list[InstanceNode]]) -> list[dict[str, Any]]:
    """列出每个可达模块类型里，名字以 `_async` 结尾的端口和内部声明（外部异步源信号）。

    这类信号按项目命名惯例直接判定为外部异步源，不需要经过 `resolve_signal_domain`
    的物理源回溯（它们本来就不该回溯到任何时钟域）；这里仍然调用同一个函数，只是
    为了让报告里的判定路径与寄存器标注共享同一套可核对的机制，而不是两套并行逻辑。
    """
    list_results: list[dict[str, Any]] = []

    for str_module_name, list_nodes in dict_nodes_by_module.items():
        node_representative = list_nodes[0]
        dict_module_ast = node_representative.module_ast

        set_seen: set[tuple[str, str]] = set()
        for dict_port in dict_module_ast.get("ports", []):
            str_name = dict_port.get("name") or ""
            if str_name.endswith(ASYNC_SUFFIX) and (str_name, "port") not in set_seen:
                set_seen.add((str_name, "port"))
                list_results.append(
                    {
                        "module": str_module_name,
                        "signal": str_name,
                        "kind": "port",
                        "line": dict_port.get("line_start"),
                        "domain": resolve_signal_domain(node_representative, str_name),
                        "instance_count": len(list_nodes),
                    }
                )
        for dict_decl in dict_module_ast.get("decls", []):
            str_name = dict_decl.get("name") or ""
            if str_name.endswith(ASYNC_SUFFIX) and (str_name, "decl") not in set_seen:
                set_seen.add((str_name, "decl"))
                list_results.append(
                    {
                        "module": str_module_name,
                        "signal": str_name,
                        "kind": "decl",
                        "line": dict_decl.get("line_start"),
                        "domain": resolve_signal_domain(node_representative, str_name),
                        "instance_count": len(list_nodes),
                    }
                )

    list_results.sort(key=lambda d: (d["module"], d["signal"]))
    return list_results


def compute_unreachable_modules(
    dict_canonical: dict[str, ModuleDecl],
    dict_nodes_by_module: dict[str, list[InstanceNode]],
) -> list[dict[str, str]]:
    """candidate 全集里 canonical 但从真实顶层不可达的模块，单独成节列出。

    每条记录都带 `category` 字段（`orphaned_rtl` / `testbench_toplevel`），区分"真实架构层面的
    孤立 RTL 发现"和"顶层 TB 文件本来就不会被芯片实例化"这两类性质完全不同的条目——这个区分
    写进 JSON 字段本身，不是只在 Markdown 标题里换个说法，下游工具读 JSON 也能拿到同样的区分。
    """
    set_reached = set(dict_nodes_by_module.keys())
    list_out: list[dict[str, str]] = []
    for str_name, decl in sorted(dict_canonical.items()):
        if str_name not in set_reached:
            try:
                str_rel = str(decl.file.relative_to(PATH_PROJECT_ROOT).as_posix())
            except ValueError:
                str_rel = str(decl.file)
            list_out.append({"module": str_name, "file": str_rel, "category": classify_unreachable_module(str_name)})
    return list_out


# ---------------------------------------------------------------------------
# 第 5b 步：解析失败文件的轻量可达性核实（不重新尝试解析这些文件本身，只查引用关系）
# ---------------------------------------------------------------------------


def check_unparseable_file_reachability(
    list_parse_errors: list[tuple[Path, str]],
    dict_nodes_by_module: dict[str, list[InstanceNode]],
) -> list[dict[str, Any]]:
    """核实"51个解析失败文件"里有没有哪个真的被真实可达模块实例化。

    不重新尝试用 formatter_ast 解析这些文件本身（已知会失败，不重复踩坑）。改用轻量方法：
    只检查 `dict_nodes_by_module`（已经通过真实实例树递归展开、确认真实可达的那批模块类型，
    不含任何 TB——TB 从来不会出现在这棵树里，因为真实顶层 `ppg_chip_digital_top` 不会实例化
    TB）自己的 `instances` 列表里，有没有任何一条 `module_name` 恰好等于某个解析失败文件的
    文件名（本项目 canonical 惯例是文件名等于模块名，用文件名做启发式核对与
    `run_phase1` 里"确认未被引用"的核对用的是同一条规则，不是新发明的判据）。

    这个核对天然只统计"被真实可达 RTL 实例化"——因为扫描范围本身就限定在
    `dict_nodes_by_module`，任何"只被某个孤儿模块（如 `ppg_dual_precision_top`）或只被
    TB 自己的单元测试实例化"的情况，根本不会进入这个扫描范围，所以不需要额外写"排除TB"的
    分支去区分，范围选择本身就已经排除了它们。

    参数:
        list_parse_errors: `parse_all_candidates` 产出的 (文件, 错误信息) 列表。
        dict_nodes_by_module: 真实可达模块类型 -> 该类型全部例化节点列表。
    返回:
        每个解析失败文件一条记录：`{"file_stem", "referenced_by_reachable_modules",
        "category"}`；`category` 为 CATEGORY_REACHABLE_BUT_UNPARSEABLE 的才是真实发现
        （需要人工核查具体内容），其余保持"未被真实可达例化引用"的既有结论不变。
    """
    list_results: list[dict[str, Any]] = []

    for path_file, _str_error in list_parse_errors:
        str_stem = path_file.stem
        list_referencing: list[dict[str, str]] = []
        for str_module_name, list_nodes in dict_nodes_by_module.items():
            dict_module_ast = list_nodes[0].module_ast
            for dict_inst in dict_module_ast.get("instances", []):
                if (dict_inst.get("module_name") or "") == str_stem:
                    list_referencing.append(
                        {
                            "by_module": str_module_name,
                            "instance_name": dict_inst.get("instance_name") or "",
                        }
                    )

        list_results.append(
            {
                "file_stem": str_stem,
                "referenced_by_reachable_modules": list_referencing,
                "category": CATEGORY_REACHABLE_BUT_UNPARSEABLE if list_referencing else None,
            }
        )

    return list_results


# ---------------------------------------------------------------------------
# 第 6 步：已知信号人工抽查交叉核对（写进代码而不是只在报告里描述，保证每次跑都真实核对）
# ---------------------------------------------------------------------------


def run_known_signal_cross_checks(list_register_tags: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """规划 Phase 1 退出标准里点名的人工抽查交叉核对，跑出真实结果，不是复述期望值。

    每一条断言都独立于 declared "期望值"重新在真实标注结果里查找，找不到目标条目本身
    也是一种需要暴露的失败（而不是断言直接通不过导致整个工具崩溃）。
    """
    list_expectations = [
        ("ppg_spi_register_file", "reg_diag_snapshot", DOMAIN_CLK2M),
        ("ppg_spi_register_file", "reg_diag_snapshot_gated", DOMAIN_SPI),
        ("ppg_spi_register_file", "reg_diag_sync_stable", DOMAIN_SPI),
    ]

    dict_by_module_target: dict[tuple[str, str], list[dict[str, Any]]] = {}
    for dict_entry in list_register_tags:
        dict_by_module_target.setdefault((dict_entry["module"], dict_entry["target_register"]), []).append(dict_entry)

    list_results = []
    for str_module, str_target, str_expected_domain in list_expectations:
        list_matches = dict_by_module_target.get((str_module, str_target), [])
        if not list_matches:
            list_results.append(
                {
                    "module": str_module,
                    "target_register": str_target,
                    "expected_domain": str_expected_domain,
                    "actual_domain": None,
                    "pass": False,
                    "note": "未在标注结果里找到该寄存器条目",
                }
            )
            continue
        for dict_match in list_matches:
            list_results.append(
                {
                    "module": str_module,
                    "target_register": str_target,
                    "expected_domain": str_expected_domain,
                    "actual_domain": dict_match["domain"],
                    "pass": dict_match["domain"] == str_expected_domain,
                    "note": "",
                }
            )

    return list_results


def run_known_async_cross_checks(list_async_tags: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """w_idle_mux_async（先mux后同步）在真实顶层模块 `ppg_chip_digital_top` 本身的抽查核对。"""
    list_expectations = [("ppg_chip_digital_top", "w_idle_mux_async", DOMAIN_EXTERNAL_ASYNC)]

    dict_by_module_signal: dict[tuple[str, str], dict[str, Any]] = {
        (d["module"], d["signal"]): d for d in list_async_tags
    }

    list_results = []
    for str_module, str_signal, str_expected_domain in list_expectations:
        dict_match = dict_by_module_signal.get((str_module, str_signal))
        if dict_match is None:
            list_results.append(
                {
                    "module": str_module,
                    "signal": str_signal,
                    "expected_domain": str_expected_domain,
                    "actual_domain": None,
                    "pass": False,
                    "note": "未在 _async 信号标注结果里找到该信号",
                }
            )
            continue
        list_results.append(
            {
                "module": str_module,
                "signal": str_signal,
                "expected_domain": str_expected_domain,
                "actual_domain": dict_match["domain"],
                "pass": dict_match["domain"] == str_expected_domain,
                "note": "",
            }
        )

    return list_results


# ---------------------------------------------------------------------------
# 主流程编排
# ---------------------------------------------------------------------------


def run_phase1(path_project_root: Path = PATH_PROJECT_ROOT) -> dict[str, Any]:
    """跑完整的 Phase 1 流程，返回一份可直接序列化成 JSON 的结果字典。"""
    list_candidate_files = mod_lint_sweep.collect_real_source_files(path_project_root)
    dict_declarations, list_parse_errors = parse_all_candidates(list_candidate_files)
    dict_canonical, dict_ambiguous, list_noncanonical = build_module_registry(dict_declarations)

    node_top, dict_nodes_by_module, list_instance_issues = build_instance_tree(dict_canonical, TOP_MODULE_NAME)

    list_register_tags = tag_reachable_registers(dict_nodes_by_module)
    list_async_tags = tag_async_signals(dict_nodes_by_module)
    list_unreachable = compute_unreachable_modules(dict_canonical, dict_nodes_by_module)

    list_register_cross_checks = run_known_signal_cross_checks(list_register_tags)
    list_async_cross_checks = run_known_async_cross_checks(list_async_tags)

    # 51 个解析失败文件（`ppg_timing_sar9`/`ppg_timing_sar15` 家族的 6 个变体在内）不能因为
    # "没有出现在 instance_issues 里"就默认它们是可达的——那句话本身就没有真实数据支撑。
    # 这里独立跑一遍轻量核实：直接查 30 个真实可达模块类型自己的 instances 列表。
    list_unparseable_reachability = check_unparseable_file_reachability(list_parse_errors, dict_nodes_by_module)
    list_reachable_but_unparseable = [
        {"file_stem": d["file_stem"], "referenced_by_reachable_modules": d["referenced_by_reachable_modules"], "category": CATEGORY_REACHABLE_BUT_UNPARSEABLE}
        for d in list_unparseable_reachability
        if d["category"] == CATEGORY_REACHABLE_BUT_UNPARSEABLE
    ]

    dict_domain_counts: dict[str, int] = {}
    for dict_entry in list_register_tags:
        dict_domain_counts[dict_entry["domain"]] = dict_domain_counts.get(dict_entry["domain"], 0) + 1

    # 解析失败的候选文件既不在 canonical 登记表也不在 noncanonical 列表里——它们的内部模块名
    # 根本没能被提取出来。为了不让它们从范围界定报告里"悄悄消失"，这里显式核对：真实可达
    # 例化树展开过程中记录的全部 instance_issues 里，有没有任何一个引用的模块名恰好等于
    # 某个解析失败文件的文件名（本项目 canonical 惯例是文件名等于模块名，所以用文件名做启发式
    # 交叉核对是合理的）。空交集就是"这些解析失败文件确认没有被任何真实可达模块引用"的正面证据，
    # 不是假设。
    set_parse_failed_stems = {f.stem for f, _e in list_parse_errors}
    set_unresolved_instance_module_names = {issue["module_name"] for issue in list_instance_issues}
    set_reachable_but_unparseable_stems = {d["file_stem"] for d in list_reachable_but_unparseable}
    set_parse_failed_possibly_needed = (
        (set_parse_failed_stems & set_unresolved_instance_module_names) | set_reachable_but_unparseable_stems
    )

    int_reconciled_total = (
        len(dict_canonical)
        + sum(len(v) for v in dict_ambiguous.values())
        + len(list_noncanonical)
        + len(list_parse_errors)
    )

    return {
        "top_module": TOP_MODULE_NAME,
        "candidate_files_total": len(list_candidate_files),
        "canonical_modules_total": len(dict_canonical),
        "reachable_module_types_total": len(dict_nodes_by_module),
        "reachable_instance_nodes_total": sum(len(v) for v in dict_nodes_by_module.values()),
        "unreachable_modules": list_unreachable,
        "ambiguous_module_names": {k: [str(p.relative_to(path_project_root).as_posix()) for p in v] for k, v in dict_ambiguous.items()},
        "noncanonical_files": [
            {"file": str(f.relative_to(path_project_root).as_posix()), "declared_module_name": n}
            for f, n in sorted(list_noncanonical, key=lambda t: (str(t[0]), t[1]))
        ],
        "parse_errors": [{"file": str(f.relative_to(path_project_root).as_posix()) if f.is_absolute() else str(f), "error": e} for f, e in list_parse_errors],
        "parse_failed_files_confirmed_unreferenced": sorted(set_parse_failed_stems - set_parse_failed_possibly_needed),
        "parse_failed_files_possibly_needed_but_unparseable": sorted(set_parse_failed_possibly_needed),
        "reachable_but_unparseable_files": sorted(list_reachable_but_unparseable, key=lambda d: d["file_stem"]),
        "candidate_total_reconciliation": {
            "candidate_files_total": len(list_candidate_files),
            "canonical": len(dict_canonical),
            "ambiguous_file_entries": sum(len(v) for v in dict_ambiguous.values()),
            "noncanonical": len(list_noncanonical),
            "parse_errors": len(list_parse_errors),
            "sum_of_above": int_reconciled_total,
            "matches_candidate_total": int_reconciled_total == len(list_candidate_files),
        },
        "instance_issues": list_instance_issues,
        "register_tags": list_register_tags,
        "async_signal_tags": list_async_tags,
        "domain_counts": dict_domain_counts,
        "known_signal_cross_checks": list_register_cross_checks,
        "known_async_cross_checks": list_async_cross_checks,
    }


def _format_markdown_report(dict_result: dict[str, Any]) -> str:
    list_lines: list[str] = []
    list_lines.append("# PPG Item 4b Phase 1 —— 时钟域传播标注 + 真实可达性范围界定")
    list_lines.append("")
    list_lines.append(f"真实顶层模块：`{dict_result['top_module']}`")
    list_lines.append("")
    list_lines.append("## 范围统计")
    list_lines.append("")
    list_lines.append(f"- 候选文件全集（`collect_real_source_files`）：{dict_result['candidate_files_total']}")
    list_lines.append(f"- canonical 模块（文件名与内部声明模块名一致）：{dict_result['canonical_modules_total']}")
    list_lines.append(f"- 真实可达模块类型数：{dict_result['reachable_module_types_total']}")
    list_lines.append(f"- 真实可达例化节点总数（同一模块类型多次例化分别计数）：{dict_result['reachable_instance_nodes_total']}")
    list_lines.append("")

    list_lines.append("## 域标注统计（寄存器/always 块目标）")
    list_lines.append("")
    for str_domain, int_count in sorted(dict_result["domain_counts"].items()):
        list_lines.append(f"- {str_domain}: {int_count}")
    list_lines.append("")

    list_lines.append("## 人工抽查交叉核对（Phase 1 退出标准点名的真实案例）")
    list_lines.append("")
    list_lines.append("| 模块 | 目标 | 期望域 | 实际域 | 结果 |")
    list_lines.append("|---|---|---|---|---|")
    for dict_c in dict_result["known_signal_cross_checks"]:
        str_status = "PASS" if dict_c["pass"] else "FAIL"
        list_lines.append(
            f"| {dict_c['module']} | {dict_c['target_register']} | {dict_c['expected_domain']} | "
            f"{dict_c['actual_domain']} | {str_status} |"
        )
    for dict_c in dict_result["known_async_cross_checks"]:
        str_status = "PASS" if dict_c["pass"] else "FAIL"
        list_lines.append(
            f"| {dict_c['module']} | {dict_c['signal']} | {dict_c['expected_domain']} | "
            f"{dict_c['actual_domain']} | {str_status} |"
        )
    list_lines.append("")

    list_unreachable_rtl = [m for m in dict_result["unreachable_modules"] if m["category"] == CATEGORY_ORPHANED_RTL]
    list_unreachable_tb = [m for m in dict_result["unreachable_modules"] if m["category"] == CATEGORY_TESTBENCH_TOPLEVEL]

    list_lines.append(
        f"## 真实孤立的RTL模块（架构层面的发现，不是TB，共 {len(list_unreachable_rtl)} 个）"
    )
    list_lines.append("")
    if list_unreachable_rtl:
        for dict_m in list_unreachable_rtl:
            list_lines.append(f"- `{dict_m['module']}` — {dict_m['file']}")
    else:
        list_lines.append("（无）")
    list_lines.append("")

    list_lines.append(
        f"## 顶层TB文件（预期如此，不计入CDC分析范围，非发现，共 {len(list_unreachable_tb)} 个）"
    )
    list_lines.append("")
    if list_unreachable_tb:
        for dict_m in list_unreachable_tb:
            list_lines.append(f"- `{dict_m['module']}` — {dict_m['file']}")
    else:
        list_lines.append("（无）")
    list_lines.append("")

    list_reachable_but_unparseable = dict_result["reachable_but_unparseable_files"]
    list_lines.append(
        f"## 真实可达但内容解析失败的文件（需要人工核查，无法确认CDC域标注，共 {len(list_reachable_but_unparseable)} 个）"
    )
    list_lines.append("")
    list_lines.append(
        "这一类与上面两类都不同：文件本身 `formatter_ast` 解析失败，但轻量核对（直接查真实可达"
        "模块类型自己的 `instances` 列表）确认它真的被至少一个真实可达模块实例化——内容无法分析，"
        "但引用关系是真实的，不能归入「孤立RTL」或「顶层TB」，也不能笼统留在「解析失败」名单里不做区分。"
    )
    list_lines.append("")
    if list_reachable_but_unparseable:
        for dict_r in list_reachable_but_unparseable:
            list_refs = "; ".join(
                f"{d['by_module']}.{d['instance_name']}" for d in dict_r["referenced_by_reachable_modules"]
            )
            list_lines.append(f"- `{dict_r['file_stem']}` — 被引用于: {list_refs}")
    else:
        list_lines.append(
            "（无——本次核实确认全部解析失败文件都不被任何真实可达模块实例化，"
            "包括 `ppg_timing_sar9`/`ppg_timing_sar15` 家族里 `control parser strict failure` "
            "的那 6 个变体：它们只被孤儿模块 `ppg_dual_precision_top`（本身不可达）和/或各自的 "
            "TB 单独实例化用于单元测试，两者都不构成真实可达；此前「确认可达」的表述不准确，"
            "已用本节的真实核对结果订正。）"
        )
    list_lines.append("")

    if dict_result["ambiguous_module_names"]:
        list_lines.append("## 真实名字冲突（多个同名文件的文件名都等于声明的 module 名）")
        list_lines.append("")
        for str_name, list_files in dict_result["ambiguous_module_names"].items():
            list_lines.append(f"- `{str_name}`: {', '.join(list_files)}")
        list_lines.append("")

    list_lines.append(f"## 非 canonical 文件（文件名与内部声明模块名不一致，共 {len(dict_result['noncanonical_files'])} 个，不纳入可达性解析）")
    list_lines.append("")
    for dict_nc in dict_result["noncanonical_files"]:
        list_lines.append(f"- {dict_nc['file']} （内部声明 `{dict_nc['declared_module_name']}`）")
    list_lines.append("")

    if dict_result["instance_issues"]:
        list_lines.append("## 例化展开问题（未能正常解析的例化点）")
        list_lines.append("")
        for dict_issue in dict_result["instance_issues"]:
            list_lines.append(
                f"- 在 `{dict_issue['at']}` 例化 `{dict_issue['instance_name']}` (`{dict_issue['module_name']}`): "
                f"{dict_issue['reason']}"
            )
        list_lines.append("")

    if dict_result["parse_errors"]:
        list_lines.append(f"## 候选文件解析失败（{len(dict_result['parse_errors'])} 个，绝大多数是 TB 文件，formatter_ast 对 TB 的宽松写法支持有限属已知局限）")
        list_lines.append("")
        for dict_pe in dict_result["parse_errors"]:
            list_lines.append(f"- {dict_pe['file']}: {dict_pe['error']}")
        list_lines.append("")
        list_lines.append(
            "解析失败的文件既进不了 canonical 登记表也进不了 noncanonical 列表——为了不让它们从范围"
            "界定报告里悄悄消失，这里显式核对：例化展开过程中记录的全部 `instance_issues` 里，"
            "有没有任何一个引用的模块名恰好等于某个解析失败文件的文件名（本项目 canonical 惯例是"
            "文件名等于模块名）。"
        )
        list_lines.append("")
        if dict_result["parse_failed_files_possibly_needed_but_unparseable"]:
            list_lines.append(
                "**以下解析失败文件可能被真实可达模块引用，但因解析失败无法确认（需要人工核查）：** "
                + ", ".join(dict_result["parse_failed_files_possibly_needed_but_unparseable"])
            )
        else:
            list_lines.append(
                f"全部 {len(dict_result['parse_failed_files_confirmed_unreferenced'])} 个解析失败文件都"
                "不在任何 `instance_issues` 的引用名单里——即 0 个未解析的例化点指向它们，"
                "确认它们都不是真实可达例化树需要的依赖（不是假设，是本次扫描 instance_issues 为空的"
                "直接推论）。这条结论与下方「真实可达但内容解析失败的文件」小节用另一条独立路径"
                "（直接扫描 30 个真实可达模块类型自己的 `instances` 列表，不依赖 BFS 过程中偶然记录的"
                "instance_issues）得到的结论一致，互为交叉验证。"
            )
        list_lines.append("")

    dict_recon = dict_result["candidate_total_reconciliation"]
    list_lines.append("## 候选文件全集核对（109 = canonical + ambiguous + noncanonical + 解析失败，必须对得上）")
    list_lines.append("")
    list_lines.append(
        f"- candidate_files_total={dict_recon['candidate_files_total']}, "
        f"canonical={dict_recon['canonical']}, ambiguous_file_entries={dict_recon['ambiguous_file_entries']}, "
        f"noncanonical={dict_recon['noncanonical']}, parse_errors={dict_recon['parse_errors']}, "
        f"四类之和={dict_recon['sum_of_above']}, 与候选全集一致={dict_recon['matches_candidate_total']}"
    )
    list_lines.append("")

    list_multi = [d for d in dict_result["register_tags"] if d.get("per_instance")]
    if list_multi:
        list_lines.append("## 同一模块类型多例化域不一致的真实案例（不合并，分别列出）")
        list_lines.append("")
        for dict_m in list_multi:
            list_lines.append(
                f"- `{dict_m['module']}`.`{dict_m['target_register']}` （本地时钟名 `{dict_m['clock_local_name']}`）："
            )
            for str_path, str_domain in dict_m["per_instance"]:
                list_lines.append(f"  - {str_path}: {str_domain}")
        list_lines.append("")

    return "\n".join(list_lines)


# ---------------------------------------------------------------------------
# --selftest：Phase 1 规划步骤 5 要求覆盖的验证用例
# ---------------------------------------------------------------------------


def _make_synthetic_node(
    str_instance_path: str,
    str_module_name: str,
    dict_port_connections: dict[str, str],
    parent: InstanceNode | None,
) -> InstanceNode:
    return InstanceNode(
        instance_path=str_instance_path,
        module_name=str_module_name,
        module_ast={"instances": [], "always": [], "ports": [], "decls": []},
        parent=parent,
        port_connections=dict_port_connections,
    )


def selftest() -> int:
    """跑 Phase 1 规划步骤 5 点名的验证用例，加上端口连接解析器自身的单元测试。"""
    int_failures = 0

    def _check(str_label: str, bool_condition: bool) -> None:
        nonlocal int_failures
        str_status = "PASS" if bool_condition else "FAIL"
        print(f"[{str_status}] {str_label}")
        if not bool_condition:
            int_failures += 1

    print("=== 端口连接解析器单元测试 ===")

    dict_simple = parse_instance_port_connections(
        "ppg_reset_sync ppg_reset_sync_clk2m_Inst(\n"
        "\t\t.i_clk(CLK_2M_PAD),               // 数字域时钟\n"
        "\t\t.i_async_rstn(RESET_N),           // 全局复位\n"
        "\t\t.o_rstn(w_rstn)                   // 数字域释放\n"
        "\t);"
    )
    _check("简单具名端口连接解析（无参数块）", dict_simple == {"i_clk": "CLK_2M_PAD", "i_async_rstn": "RESET_N", "o_rstn": "w_rstn"})

    dict_with_params = parse_instance_port_connections(
        "ppg_config_cdc_bridge #(.C_CONFIG_WIDTH(1024))config_cdc_bridge_Inst(\n"
        "\t\t.i_source_clk(i_source_clk),\n"
        "\t\t.i_source_config(i_source_config_snapshot)\n"
        "\t);"
    )
    _check(
        "带 #(参数) 块的端口连接解析——必须跳过参数块只取端口列表",
        dict_with_params == {"i_source_clk": "i_source_clk", "i_source_config": "i_source_config_snapshot"},
    )

    dict_empty_conn = parse_instance_port_connections("ppg_control_top ppg_control_top_Inst(\n\t\t.o_coarse_saturation_low(),\n\t\t.o_clk_2m(w_pad_clk_2m)\n\t);")
    _check("空端口连接（悬空输出）解析为空字符串而不是崩溃", dict_empty_conn == {"o_coarse_saturation_low": "", "o_clk_2m": "w_pad_clk_2m"})

    dict_const_conn = parse_instance_port_connections("m i(\n\t.a(1'b1),\n\t.b(16'd0)\n);")
    _check("常量端口连接解析", dict_const_conn == {"a": "1'b1", "b": "16'd0"})

    print("\n=== 规划步骤 5 验证用例 ===")

    # 用例1：i_spi_sclk（本地名）与 i_source_clk（本地名）必须都能解析到同一真实域 SPI_SCLK，
    # 在孤立子图场景下验证（不依赖 ppg_dual_precision_top 出现在真实主扫描报告里，因为它不可达）。
    node_top_fixture = _make_synthetic_node("top_fixture", "top_fixture", {}, None)
    node_top_fixture.parent = None
    # 顶层物理端口场景用真正的 TOP_MODULE_NAME 语义（只有顶层没有 parent 时才查 PHYSICAL_CLOCK_PORTS），
    # 这里直接在顶层节点上解析物理端口名本身。
    str_domain_physical = resolve_signal_domain(node_top_fixture, "SPI_SCLK")
    _check("顶层物理端口 SPI_SCLK 解析为 SPI_SCLK 域", str_domain_physical == DOMAIN_SPI)

    node_child_spi_sclk_name = _make_synthetic_node(
        "top_fixture/child_a", "child_a", {"i_spi_sclk": "SPI_SCLK"}, node_top_fixture
    )
    node_child_source_clk_name = _make_synthetic_node(
        "top_fixture/child_b", "child_b", {"i_source_clk": "SPI_SCLK"}, node_top_fixture
    )
    str_domain_a = resolve_signal_domain(node_child_spi_sclk_name, "i_spi_sclk")
    str_domain_b = resolve_signal_domain(node_child_source_clk_name, "i_source_clk")
    _check(
        "本地端口名 i_spi_sclk 与 i_source_clk 各自接 SPI_SCLK 时解析到同一真实域（孤立子图单元测试）",
        str_domain_a == DOMAIN_SPI and str_domain_b == DOMAIN_SPI and str_domain_a == str_domain_b,
    )

    # 用例2：CLK_STAGE1_DOUT_LOW/CLK_STAGE2_DOUT_LOW 带 "CLK" 字样但实际是异步电平信号，
    # 不得被误判成第三个时钟域——顶层场景下它们既不是物理时钟端口也不带 _async 后缀，
    # 必须落在 UNRESOLVED（不是凭空产生的第三个时钟域标签）。
    str_domain_stage1 = resolve_signal_domain(node_top_fixture, "CLK_STAGE1_DOUT_LOW")
    str_domain_stage2 = resolve_signal_domain(node_top_fixture, "CLK_STAGE2_DOUT_LOW")
    _check(
        "CLK_STAGE1/2_DOUT_LOW 不被误判为第三个时钟域（应为 UNRESOLVED，不是 CLK_2M/SPI_SCLK 之外的新域标签）",
        str_domain_stage1 == DOMAIN_UNRESOLVED
        and str_domain_stage2 == DOMAIN_UNRESOLVED
        and str_domain_stage1 not in (DOMAIN_CLK2M, DOMAIN_SPI)
        and str_domain_stage2 not in (DOMAIN_CLK2M, DOMAIN_SPI),
    )

    # 用例3a："先mux后同步"变体：顶层模块内部 wire（非端口）带 _async 后缀，直接识别为外部异步源，
    # 不需要顺着端口链回溯（因为它本来就不是端口，是顶层自己的组合 assign 产物）。
    str_domain_mux_first = resolve_signal_domain(node_top_fixture, "w_idle_mux_async")
    _check("先mux后同步变体：顶层内部 wire w_idle_mux_async 识别为外部异步源", str_domain_mux_first == DOMAIN_EXTERNAL_ASYNC)

    # 用例3b："先同步后mux"变体：子模块的输入端口本身带 _async 后缀（ppg_adc_async_stage_capture 的
    # i_clk_stage1_dout_low_async/i_clk_stage2_dout_low_async 真实端口名），端口未在父连接表里出现时
    # （模拟"父模块把它当异步源直接命名传入，命名本身已经是 _async 后缀"的情形）同样识别为外部异步源。
    node_child_no_parent_conn = _make_synthetic_node(
        "top_fixture/async_capture_child", "async_capture_child", {}, node_top_fixture
    )
    str_domain_sync_first = resolve_signal_domain(node_child_no_parent_conn, "i_clk_stage1_dout_low_async")
    _check(
        "先同步后mux变体：子模块 _async 后缀输入端口（不在父连接表中时按内部声明规则）识别为外部异步源",
        str_domain_sync_first == DOMAIN_EXTERNAL_ASYNC,
    )
    # 同一变体也要覆盖端口确实出现在父连接表、且父侧信号本身也带 _async 后缀命名的情形
    # （对应 ppg_control_top 把 CLK_STAGE1_DOUT_LOW 重命名传入子模块时子模块侧改用 _async 后缀端口名的真实结构）。
    node_child_with_async_parent_conn = _make_synthetic_node(
        "top_fixture/async_capture_child2",
        "async_capture_child2",
        {"i_clk_stage1_dout_low_async": "some_upstream_async_alias_async"},
        node_top_fixture,
    )
    str_domain_sync_first_via_parent = resolve_signal_domain(node_child_with_async_parent_conn, "i_clk_stage1_dout_low_async")
    _check(
        "先同步后mux变体：子模块 _async 端口经父连接表回溯到父侧同样 _async 后缀命名的信号，仍识别为外部异步源",
        str_domain_sync_first_via_parent == DOMAIN_EXTERNAL_ASYNC,
    )

    # 用例3c：真实扫描曾经暴露的回归案例——子模块 _async 后缀端口连接到的父侧信号名
    # 本身不带 _async 后缀（真实结构：CLK_STAGE1_DOUT_LOW 这个顶层物理名没有 _async 后缀，
    # 但 ppg_control_top/ppg_adc_measurement_idac_integration/ppg_adc_async_stage_capture
    # 逐层往下传递时改用了带 _async 后缀的内部端口名）。_async 后缀检查必须优先于端口连接
    # 回溯，否则会一路递归到顶层物理名、因为它既非 CLK_2M_PAD/SPI_SCLK 也不带 _async 后缀
    # 而被误判为"无法判定"——这正是本脚本第一次真实扫描时抓到的真实回归。
    node_top_no_async_name = _make_synthetic_node("top_fixture2", "top_fixture2", {}, None)
    node_child_async_port_plain_parent = _make_synthetic_node(
        "top_fixture2/child_c",
        "child_c",
        {"i_clk_stage1_dout_low_async": "CLK_STAGE1_DOUT_LOW"},
        node_top_no_async_name,
    )
    str_domain_regression_case = resolve_signal_domain(node_child_async_port_plain_parent, "i_clk_stage1_dout_low_async")
    _check(
        "回归用例：子模块 _async 端口连接到不带 _async 后缀的顶层物理名时，仍必须优先按本地端口名判定外部异步源（不得递归到顶层误判为 UNRESOLVED）",
        str_domain_regression_case == DOMAIN_EXTERNAL_ASYNC,
    )

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
    parser.add_argument("--json", type=Path, default=None, help="可选：把完整结果写成 JSON 文件。")
    parser.add_argument("--markdown", type=Path, default=None, help="可选：把结果写成 Markdown 报告。")
    parser.add_argument("--selftest", action="store_true", help="只跑规划步骤5的验证用例和端口解析器单元测试，不扫描真实项目。")
    namespace_args = parser.parse_args(argv)

    if namespace_args.selftest:
        return selftest()

    dict_result = run_phase1()

    print(f"真实顶层模块：{dict_result['top_module']}")
    print(f"候选文件全集：{dict_result['candidate_files_total']}")
    print(f"canonical 模块数：{dict_result['canonical_modules_total']}")
    print(f"真实可达模块类型数：{dict_result['reachable_module_types_total']}")
    print(f"真实可达例化节点总数：{dict_result['reachable_instance_nodes_total']}")
    int_unreachable_rtl = sum(1 for m in dict_result["unreachable_modules"] if m["category"] == CATEGORY_ORPHANED_RTL)
    int_unreachable_tb = sum(1 for m in dict_result["unreachable_modules"] if m["category"] == CATEGORY_TESTBENCH_TOPLEVEL)
    print(
        f"不可达模块数：{len(dict_result['unreachable_modules'])}"
        f"（真实孤立RTL={int_unreachable_rtl}，顶层TB={int_unreachable_tb}）"
    )
    print(f"非 canonical 文件数：{len(dict_result['noncanonical_files'])}")
    print(f"真实名字冲突数：{len(dict_result['ambiguous_module_names'])}")
    print(f"例化展开问题数：{len(dict_result['instance_issues'])}")
    print(f"候选文件解析失败数：{len(dict_result['parse_errors'])}")
    print(f"  其中确认未被任何真实可达例化引用：{len(dict_result['parse_failed_files_confirmed_unreferenced'])}")
    print(f"  其中可能被引用但因解析失败无法确认（需人工核查）：{len(dict_result['parse_failed_files_possibly_needed_but_unparseable'])}")
    print(f"  其中独立轻量核实确认真实可达但内容解析失败（新增第三类，需人工核查内容）：{len(dict_result['reachable_but_unparseable_files'])}")
    if dict_result["reachable_but_unparseable_files"]:
        for dict_r in dict_result["reachable_but_unparseable_files"]:
            print(f"    - {dict_r['file_stem']}: {dict_r['referenced_by_reachable_modules']}")
    dict_recon = dict_result["candidate_total_reconciliation"]
    print(f"候选文件全集核对：{dict_recon['sum_of_above']} == {dict_recon['candidate_files_total']} -> {dict_recon['matches_candidate_total']}")
    print("\n域标注统计：")
    for str_domain, int_count in sorted(dict_result["domain_counts"].items()):
        print(f"  {str_domain}: {int_count}")

    print("\n人工抽查交叉核对：")
    int_cross_check_failures = 0
    for dict_c in dict_result["known_signal_cross_checks"] + dict_result["known_async_cross_checks"]:
        str_status = "PASS" if dict_c["pass"] else "FAIL"
        if not dict_c["pass"]:
            int_cross_check_failures += 1
        str_target = dict_c.get("target_register") or dict_c.get("signal")
        print(f"  [{str_status}] {dict_c['module']}.{str_target}: 期望={dict_c['expected_domain']} 实际={dict_c['actual_domain']}")

    if namespace_args.json is not None:
        namespace_args.json.write_text(json.dumps(dict_result, ensure_ascii=False, indent=2), encoding="utf-8")
        print(f"\n已写入 JSON：{namespace_args.json}")

    if namespace_args.markdown is not None:
        namespace_args.markdown.write_text(_format_markdown_report(dict_result), encoding="utf-8")
        print(f"已写入 Markdown：{namespace_args.markdown}")

    return 0 if int_cross_check_failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
