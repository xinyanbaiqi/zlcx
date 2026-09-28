#!/usr/bin/env python3
"""PPG Item 4b Phase 2：跨域读取候选检测。

背景与依据：完整规划见 `C:\\Users\\d\\.claude\\plans\\ppg-item4b-cdc-ledger-plan.md` "Phase 2 ——
跨域读取候选检测"一节。本脚本直接复用 Phase 1（`cdc_domain_reachability_tagger.py`）已经真实验证
过的域解析基础设施（真实可达例化树、`resolve_signal_domain`、452 条寄存器域标注），不重新推导
Phase 1 已经确认过的事实——见 memory
`project-ppg-item4b-phase1-cdc-domain-tagging-20260914.md`。

Phase 2 的任务：对 Phase 1 已标注的每个寄存器，反向查找项目内真实读取点（`assign` 的 RHS、其他
`always` 块的 RHS），domain 不一致即记候选。

## 检测范围的真实边界（不是回避，是 Verilog 语言本身的作用域规则决定的）

一个 `reg` 只能在声明它的模块自己的作用域内被直接按名字引用——要跨模块边界，必须先经过端口连接
变成另一个模块里的另一个局部名字。给定这个语言事实，本脚本把检测范围严格限定在**同一模块内**
（intra-module）：

1. **直接读取**（`direct_always_read`）：寄存器 T 在模块 M 的某个 always 块里被写（域 D_write）；
   同一模块 M 的**其他** always 块（域 D_read）的函数体里，只要出现 T 的按整词读取（不是 T 自己
   作为该行赋值目标），且 D_read != D_write，记为候选。这正是这次真实抓到的 SPI 诊断快照撕裂
   缺陷的真实形状（`ppg_spi_register_file.v` 内，`reg_diag_snapshot`/CLK_2M 被同文件另一个
   SPI_SCLK 域的 always 块直接读取）。
2. **经组合逻辑一跳间接读取**（`indirect_via_assign_read`）：模块 M 内某条 `assign` 的 RHS 引用了
   T，把这条 assign 的 LHS（记作 W，一个组合 wire）视为 T 的"别名"，再在同一模块内查找读取 W 的
   其他 always 块，同样按域不一致记候选——这一跳仍然完全停留在同一模块作用域内，不需要跨模块
   数据流追踪。

**试过、真实跑出来发现没有信号量、已经移除的第三类检测（诚实记录，不是遗漏）**：最初还实现了
"组合直通到输出端口"检测——模块 M 内某条 `assign` 的 RHS 引用 T，且这条 assign 的 LHS 本身就是
模块 M 的一个输出端口，就记为候选，不做域比较（因为不追踪端口连到父模块之后具体被谁读取）。
真实对当前可达项目跑了一遍：产出 **494** 条这类候选，覆盖 450 个不同的 (模块, 输出端口) 组合——
逐条抽查后确认这些几乎全部是`assign o_xxx = reg_yyy;`这种最普通的"寄存器通过 assign 桥接到
输出端口"写法，恰好正是本 skill 自己的严格风格规则要求的"registered/complex outputs 使用输出
桥接风格"这一强制约定本身，不是风险信号——真实项目里几乎每一个曾经写进 always 块的寄存器，
迟早都会通过这种标准写法暴露给外部。不做下游读取域追踪的前提下，这类检测在这个项目里等价于
"把项目里几乎所有输出桥接assign抄一遍"，没有任何区分度，因此从本脚本里整体移除，不保留在
`candidates`/`gated_candidates`任何一个列表里。如果未来需要，恢复这类检测必须先补上真正跨模块
边界的数据流追踪（沿着例化树把端口连到父模块之后，比较父模块侧实际消费它的 always 块的真实
域），否则重新加回来只会重现这次已经验证过的噪音问题，不应该在没有下游域信息的情况下复活。

**仍然没有做的事（诚实记录，不是遗漏）**：真正跨模块边界的数据流追踪（沿着例化树把一个寄存器的
值一路追到它在其他模块里被消费的地方，再比较那个消费点的真实域）不在本阶段范围内。这需要对每个
可能的信号名做完整的组合驱动链追溯，规模和风险都远超"跨域读取候选检测"这一阶段应有的范围；上面
两条检测已经覆盖了 Verilog 语言本身允许"直接按名字读取"的全部真实场景（模块作用域规则决定了，
跨模块的读取必然先经过一次端口/assign 的具名传递，而这一跳正是上面被移除的第三类检测原本想覆盖
但没有域信息、因而没有信号量的起点）。如果后续阶段需要更深的跨模块追踪，应该作为独立的 Phase 2
扩展明确立项，补上下游域比较后再启用，不在这次范围内静默展开或者不加区分地全部上报。

## 白名单 IP 排除（写在这里，不是想当然，是读了三个 IP 真实源码后确认的）

`ppg_pulse_cdc_sync.v`/`ppg_config_cdc_bridge.v`/`ppg_reset_sync.v` 三个文件内部，本来就存在跨域
读取——那正是它们作为同步器的工作原理本身（例如 `ppg_pulse_cdc_sync.v` 的
`flag_dest_sync_meta <= flag_source_toggle;`，目标域 always 块直接读取源域寄存器，这是两级同步
的第一级，不是缺陷）。如果不排除，每次真实扫描都会把这三个文件自己内部的同步机制误报成"候选"，
把 Item 4a 已经人工审计确认零缺陷的三个文件重新变成噪音源。真实核实确认：三个文件各自的域跨越
只发生在自己内部、且只发生一次（各自的两级/多级同步链起点），不存在"每个使用这三个 IP 输出的
地方都被误报"的风险——因为本脚本严格按模块作用域检测（见上），别的模块读取这三个 IP 的输出端口
时，读到的是这些模块自己域内的局部信号名，不会被误判为直接读取了 IP 内部的寄存器。

## 门控 vs 无门控的区分（这是本阶段候选列表能否复现已知真实先例的关键）

`ppg_spi_register_file.v` V1.3 版本头 changelog 完整描述了同一个寄存器（`reg_diag_sync_meta`，
现已改名 `reg_diag_snapshot_gated`）从 V1.2 到 V1.3 的真实变化：V1.2 无门控、每个 `i_source_clk`
周期都直接采样 `reg_diag_snapshot`（`else begin ... end`，跟随复位分支的唯一 fallback 分支，
没有任何独立条件）；V1.3 改为只在专属门控脉冲为真时才采样（`else if(w_diag_snapshot_gate_event)
begin ... end`，一个真实的、有独立条件的分支）。这两种写法在"是否存在跨域读取"这一点上完全一样
（都是 SPI_SCLK 域的 always 块直接读取 CLK_2M 域的 `reg_diag_snapshot`），唯一的真实区别是
**这次读取有没有被一个独立条件门控**。规划 Phase 2 的验证方式要求"合成负例产出候选，真实 V1.3
现状不产出候选"，而 V1.3 现状在"是否存在跨域读取"这个问题上答案仍然是"是"——真正消失的是"无门控
每拍连续采样"这个更危险的子类别。因此本脚本对 `direct_always_read`/`indirect_via_assign_read`
两类候选，额外用 `gated` 字段区分：
  - `gated=False`（或分支结构无法判定时保守按 False 处理）：读取发生在一个没有独立条件的
    fallback 分支（`else begin`，不是 `else if(...)`），即 Phase 3 判据里点名的"无条件连续采样"
    形状，进入**主候选列表** `candidates`（规划验收标准点名的"候选"，本阶段最高优先级发现）。
  - `gated=True`：读取发生在一个有独立条件的分支（`if(...)`/`else if(...)`），即读取本身依赖某个
    门控信号才会发生，单独放进 `gated_candidates`（次级列表，不计入 Phase 2 验收标准的"候选"计数，
    但完整保留下来——门控信号本身是否安全（是否也经过白名单 IP）是 Phase 3 明确要做的判断，
    Phase 2 只负责如实标注"这次读取被门控了"这个结构事实，不代替 Phase 3 下安全结论）。

用法：
    python cdc_cross_domain_read_candidate_detector.py [--json PATH] [--markdown PATH]
    python cdc_cross_domain_read_candidate_detector.py --selftest
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

# Phase 1 工具作为唯一的域解析/可达性入口复用，不重新实现例化树展开逻辑。
import cdc_domain_reachability_tagger as mod_phase1  # noqa: E402
import static_lint_semantic_sweep as mod_lint_sweep  # noqa: E402

from scripts.python.quality.formatter_ast import build_ast_report_for_path  # noqa: E402


# ---------------------------------------------------------------------------
# 常量：三类已验证安全 IP 白名单（读了三个文件真实源码后确认排除理由，见模块 docstring）
# ---------------------------------------------------------------------------

SET_WHITELIST_IP_MODULES: frozenset[str] = frozenset(
    {"ppg_pulse_cdc_sync", "ppg_config_cdc_bridge", "ppg_reset_sync"}
)

# 只在这两个真实域之间做候选比较；MULTI/UNRESOLVED/N/A/CONSTANT/UNCONNECTED 等含糊域不参与比较
# （不是遗漏，是这些域本身已经代表"未消解干净"，混进域比较会产生没有真实依据的噪音）。
SET_COMPARABLE_DOMAINS: frozenset[str] = frozenset({mod_phase1.DOMAIN_CLK2M, mod_phase1.DOMAIN_SPI})

CANDIDATE_KIND_DIRECT = "direct_always_read"
CANDIDATE_KIND_INDIRECT = "indirect_via_assign_read"


# ---------------------------------------------------------------------------
# 分支门控分类：解析 always 块 `lines` 文本，判定每一行所处的 if/else_if/else 分支
# ---------------------------------------------------------------------------

_RE_BRANCH_ELSE_IF = re.compile(r"^\s*end\s+else\s+if\s*\(")
_RE_BRANCH_ELSE = re.compile(r"^\s*end\s+else\s+begin\b")
_RE_BRANCH_IF = re.compile(r"^\s*if\s*\(")
_RE_BARE_END = re.compile(r"^\s*end\s*;?\s*$")

BRANCH_KIND_TOP = "top"
BRANCH_KIND_IF = "if"
BRANCH_KIND_ELSE_IF = "else_if"
BRANCH_KIND_ELSE = "else"


def classify_always_line_branches(list_lines: list[str]) -> list[str]:
    """对 always 块 `lines`（已知不含 always 自己的 `@(...)begin` 首行）逐行标注所处分支种类。

    项目真实代码风格固定为 `if(cond)begin` / `end else if(cond)begin` / `end else begin` /
    `end`，各自独占一行（真实核实见 `ppg_spi_register_file.v:536-556`）——这里按这个真实、
    一致的风格写一个简单的栈式扫描，不处理任意 Verilog 语法的通用分支解析器。

    返回:
        与 list_lines 等长的分支种类列表，取值为 BRANCH_KIND_* 常量；标注对应的是"这一行内容
        所处的最内层分支"，分支头本身那一行（`if(...)`/`else if(...)`/`else begin`）标注的是
        它刚刚压入的新分支种类（即该分支头行自己的条件表达式，也算"处于这个分支条件的求值
        环境里"）。栈异常（`end` 多于 `begin`，理论上不会真实出现）时不崩溃，保持栈底 top 帧。
    """
    list_result: list[str] = []
    list_stack: list[str] = [BRANCH_KIND_TOP]

    for str_line in list_lines:
        if _RE_BRANCH_ELSE_IF.match(str_line):
            if len(list_stack) > 1:
                list_stack.pop()
            list_stack.append(BRANCH_KIND_ELSE_IF)
            list_result.append(list_stack[-1])
        elif _RE_BRANCH_ELSE.match(str_line):
            if len(list_stack) > 1:
                list_stack.pop()
            list_stack.append(BRANCH_KIND_ELSE)
            list_result.append(list_stack[-1])
        elif _RE_BRANCH_IF.match(str_line):
            list_stack.append(BRANCH_KIND_IF)
            list_result.append(list_stack[-1])
        elif _RE_BARE_END.match(str_line):
            list_result.append(list_stack[-1])
            if len(list_stack) > 1:
                list_stack.pop()
        else:
            list_result.append(list_stack[-1])

    return list_result


def is_branch_header_line(str_line: str) -> bool:
    """这一行本身是不是分支头（`if(...)`/`end else if(...)`/`end else begin`）。"""
    return bool(_RE_BRANCH_IF.match(str_line) or _RE_BRANCH_ELSE_IF.match(str_line) or _RE_BRANCH_ELSE.match(str_line))


# ---------------------------------------------------------------------------
# 读/写occurrence 判定：整词匹配 + LHS/RHS 切分
# ---------------------------------------------------------------------------

_RE_NONBLOCKING_ASSIGN = re.compile(r"<=")
_RE_LONE_EQUALS = re.compile(r"(?<![=!<>])=(?!=)")


def _whole_word_positions(str_signal_name: str, str_text: str) -> list[int]:
    return [m.start() for m in re.finditer(r"\b" + re.escape(str_signal_name) + r"\b", str_text)]


def find_read_positions_in_line(str_signal_name: str, str_line: str, bool_is_header: bool) -> list[int]:
    """返回这一行里 `str_signal_name` 作为"读取"出现的字符位置列表（可能为空）。

    分支头行（`if(...)`/`else if(...)`）：条件表达式里的任何出现都算读取（该表达式本身就是在
    求值一个信号，不存在"这是赋值目标"的可能性）。
    内容行：按 `<=`（非阻塞赋值）优先、否则按孤立 `=`（阻塞赋值，排除 `==`/`!=`/`<=`/`>=`）切分
    LHS/RHS；只有出现在 RHS 部分的才算读取，纯粹出现在 LHS（赋值目标）部分的不算（那是这一行
    在给*别的*寄存器赋值时顺带出现在左边，真实项目风格里这种情况本来就极少见，出现也应该保守地
    不算读取，因为赋值目标不是"被读取"）。找不到赋值运算符的内容行（例如裸的 `case(...)`  或者
    延续的表达式行）按"整行都算读取环境"处理，与分支头行同一逻辑。
    """
    if bool_is_header:
        return _whole_word_positions(str_signal_name, str_line)

    match_nonblocking = _RE_NONBLOCKING_ASSIGN.search(str_line)
    match_op = match_nonblocking
    if match_op is None:
        match_op = _RE_LONE_EQUALS.search(str_line)

    if match_op is None:
        return _whole_word_positions(str_signal_name, str_line)

    int_op_end = match_op.end()
    list_positions = _whole_word_positions(str_signal_name, str_line)
    return [p for p in list_positions if p >= int_op_end]


# ---------------------------------------------------------------------------
# 核心检测：单个模块内的跨域读取候选（纯函数，只依赖调用方传入的域信息，便于单元测试）
# ---------------------------------------------------------------------------


def _strip_bit_select(str_expr: str) -> str:
    """从一个可能带位选/范围的表达式文本里取出基础标识符（`o_x[3:0]` -> `o_x`）。"""
    match = re.match(r"^\s*([A-Za-z_][A-Za-z0-9_]*)", str_expr)
    return match.group(1) if match else str_expr.strip()


def find_cross_domain_read_candidates_for_module(
    str_module_name: str,
    dict_module_ast: dict[str, Any],
    dict_write_domain_by_target: dict[str, str],
    dict_read_domain_by_always_line_start: dict[int, str],
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    """对单个模块的 AST 做 Phase 2 三类候选检测，返回 (主候选列表, 门控候选列表)。

    参数:
        str_module_name: 模块名（仅用于结果标注，不参与逻辑判定）。
        dict_module_ast: `formatter_ast` 的模块字典（含 `always`/`assigns`/`ports`）。
        dict_write_domain_by_target: 该模块内每个已标注寄存器名 -> 写入域（只放
            SET_COMPARABLE_DOMAINS 里的两个真实域，调用方负责提前过滤掉 MULTI/UNRESOLVED 等）。
        dict_read_domain_by_always_line_start: 该模块内每个 always 块的 line_start ->
            该块自身的域（同样只含两个真实域；调用方负责过滤）。
    返回:
        (主候选列表, 门控候选列表) —— 字段含义见模块 docstring。纯函数，不依赖全局状态，
        因此既能喂真实项目扫描的数据，也能喂 `--selftest` 里手写的合成负例数据。
    """
    list_candidates: list[dict[str, Any]] = []
    list_gated_candidates: list[dict[str, Any]] = []

    list_always = dict_module_ast.get("always", []) or []
    list_assigns = dict_module_ast.get("assigns", []) or []

    # 预先给每个 always 块算好"逐行分支种类"标注，避免对同一个块反复重算。
    dict_always_line_branches: dict[int, list[str]] = {}
    for dict_always in list_always:
        int_line_start = dict_always.get("line_start")
        if int_line_start is None:
            continue
        dict_always_line_branches[int_line_start] = classify_always_line_branches(dict_always.get("lines", []) or [])

    def _scan_other_always_for_reads(
        str_signal_name: str, int_writer_line_start: int | None
    ) -> list[tuple[dict[str, Any], str, str]]:
        """在除 int_writer_line_start 之外的所有 always 块里查找 str_signal_name 的读取。

        返回 (该 always 块字典, 命中行原文, 门控种类 'gated'/'ungated') 的列表。
        """
        list_hits: list[tuple[dict[str, Any], str, str]] = []
        for dict_always in list_always:
            int_line_start = dict_always.get("line_start")
            if int_line_start is None or int_line_start == int_writer_line_start:
                continue
            if int_line_start not in dict_read_domain_by_always_line_start:
                continue  # 该 always 块自身域不在可比较范围内（组合块/UNRESOLVED 等），跳过

            list_lines = dict_always.get("lines", []) or []
            list_branches = dict_always_line_branches.get(int_line_start, [])
            for int_idx, str_line in enumerate(list_lines):
                str_branch_kind = list_branches[int_idx] if int_idx < len(list_branches) else BRANCH_KIND_TOP
                bool_is_header = is_branch_header_line(str_line)
                list_positions = find_read_positions_in_line(str_signal_name, str_line, bool_is_header)
                if not list_positions:
                    continue
                str_gating = (
                    "gated"
                    if bool_is_header or str_branch_kind in (BRANCH_KIND_IF, BRANCH_KIND_ELSE_IF)
                    else "ungated"
                )
                list_hits.append((dict_always, str_line.strip(), str_gating))
        return list_hits

    for str_target_register, str_write_domain in dict_write_domain_by_target.items():
        # 找到这个寄存器自己的写入 always 块 line_start（用于从"其他 always 块"里排除自己）。
        int_writer_line_start: int | None = None
        for dict_always in list_always:
            if str_target_register in (dict_always.get("targets") or []):
                int_writer_line_start = dict_always.get("line_start")
                break

        # --- 第1类：直接读取 ---
        for dict_reader_always, str_hit_line, str_gating in _scan_other_always_for_reads(
            str_target_register, int_writer_line_start
        ):
            int_reader_line_start = dict_reader_always.get("line_start")
            str_read_domain = dict_read_domain_by_always_line_start.get(int_reader_line_start, "")
            if str_read_domain == str_write_domain:
                continue
            dict_candidate = {
                "kind": CANDIDATE_KIND_DIRECT,
                "module": str_module_name,
                "target_register": str_target_register,
                "write_domain": str_write_domain,
                "reader_always_line_start": int_reader_line_start,
                "reader_always_line_end": dict_reader_always.get("line_end"),
                "reader_domain": str_read_domain,
                "gated": str_gating == "gated",
                "evidence_line": str_hit_line,
            }
            if str_gating == "gated":
                list_gated_candidates.append(dict_candidate)
            else:
                list_candidates.append(dict_candidate)

        # --- 第2类：经组合 assign 一跳间接读取 ---
        for dict_assign in list_assigns:
            str_rhs = dict_assign.get("rhs", "") or ""
            if not _whole_word_positions(str_target_register, str_rhs):
                continue

            str_assign_lhs_base = _strip_bit_select(dict_assign.get("lhs", "") or "")

            for dict_reader_always, str_hit_line, str_gating in _scan_other_always_for_reads(
                str_assign_lhs_base, int_writer_line_start
            ):
                int_reader_line_start = dict_reader_always.get("line_start")
                str_read_domain = dict_read_domain_by_always_line_start.get(int_reader_line_start, "")
                if str_read_domain == str_write_domain:
                    continue
                dict_candidate = {
                    "kind": CANDIDATE_KIND_INDIRECT,
                    "module": str_module_name,
                    "target_register": str_target_register,
                    "write_domain": str_write_domain,
                    "via_assign_wire": str_assign_lhs_base,
                    "reader_always_line_start": int_reader_line_start,
                    "reader_always_line_end": dict_reader_always.get("line_end"),
                    "reader_domain": str_read_domain,
                    "gated": str_gating == "gated",
                    "evidence_line": str_hit_line,
                }
                if str_gating == "gated":
                    list_gated_candidates.append(dict_candidate)
                else:
                    list_candidates.append(dict_candidate)

    return list_candidates, list_gated_candidates


# ---------------------------------------------------------------------------
# 真实项目全扫编排：复用 Phase 1 的例化树 + register_tags，构建本模块需要的域索引
# ---------------------------------------------------------------------------


def build_reachable_module_tree() -> dict[str, list["mod_phase1.InstanceNode"]]:
    """重跑 Phase 1 orchestration 里"构建可达例化树"的那几步，得到 dict_nodes_by_module。

    `mod_phase1.run_phase1()` 只返回汇总结果字典，不暴露例化树本身；这里直接调用 Phase 1
    已经写好、已经验证过的三个子函数（不重新实现任何域解析/例化展开逻辑），只是多做一次同样的
    编排以拿到中间对象。跟 Phase 1 脚本内部 `run_phase1()` 的前三步完全一致。
    """
    list_candidate_files = mod_lint_sweep.collect_real_source_files(PATH_PROJECT_ROOT)
    dict_declarations, _list_parse_errors = mod_phase1.parse_all_candidates(list_candidate_files)
    dict_canonical, _dict_ambiguous, _list_noncanonical = mod_phase1.build_module_registry(dict_declarations)
    _node_top, dict_nodes_by_module, _list_instance_issues = mod_phase1.build_instance_tree(
        dict_canonical, mod_phase1.TOP_MODULE_NAME
    )
    return dict_nodes_by_module


def run_phase2(
    path_project_root: Path = PATH_PROJECT_ROOT,
    dict_nodes_by_module: "dict[str, list[mod_phase1.InstanceNode]] | None" = None,
) -> dict[str, Any]:
    """跑完整的 Phase 2 流程：对每个真实可达、非白名单模块做跨域读取候选检测。

    参数 `dict_nodes_by_module` 为可选的性能优化钩子（Phase 3 引入）：真实全项目例化树构建
    单次耗时约70秒（本机对本项目实测），Phase 3 需要在同一次运行里多次复用同一棵树（真实审计
    + 5个验证用例），不加这个钩子会被迫重复付出这个耗时。默认 `None` 时行为与之前完全一致
    （自己重新调用 `build_reachable_module_tree()`），不影响本脚本自己的 `--selftest`/真实扫描
    结果——纯粹的性能钩子，不改变任何判定逻辑。
    """
    if dict_nodes_by_module is None:
        dict_nodes_by_module = build_reachable_module_tree()
    list_register_tags = mod_phase1.tag_reachable_registers(dict_nodes_by_module)

    # 按模块聚合"寄存器名 -> 域"与"always块line_start -> 域"，只保留两个真实可比较域。
    dict_write_domain_by_module: dict[str, dict[str, str]] = {}
    dict_read_domain_by_module: dict[str, dict[int, str]] = {}
    for dict_entry in list_register_tags:
        str_domain = dict_entry["domain"]
        if str_domain not in SET_COMPARABLE_DOMAINS:
            continue
        str_module = dict_entry["module"]
        dict_write_domain_by_module.setdefault(str_module, {})[dict_entry["target_register"]] = str_domain
        int_line_start = dict_entry.get("line_start")
        if int_line_start is not None:
            dict_read_domain_by_module.setdefault(str_module, {})[int_line_start] = str_domain

    list_all_candidates: list[dict[str, Any]] = []
    list_all_gated_candidates: list[dict[str, Any]] = []
    list_modules_scanned: list[str] = []
    list_modules_skipped_whitelist: list[str] = []

    for str_module_name, list_nodes in dict_nodes_by_module.items():
        if str_module_name in SET_WHITELIST_IP_MODULES:
            list_modules_skipped_whitelist.append(str_module_name)
            continue
        if str_module_name not in dict_write_domain_by_module:
            continue  # 该模块没有任何域可比较的寄存器，没有候选可能

        list_modules_scanned.append(str_module_name)
        dict_module_ast = list_nodes[0].module_ast
        list_candidates, list_gated = find_cross_domain_read_candidates_for_module(
            str_module_name,
            dict_module_ast,
            dict_write_domain_by_module.get(str_module_name, {}),
            dict_read_domain_by_module.get(str_module_name, {}),
        )
        list_all_candidates.extend(list_candidates)
        list_all_gated_candidates.extend(list_gated)

    dict_kind_counts: dict[str, int] = {}
    for dict_c in list_all_candidates:
        dict_kind_counts[dict_c["kind"]] = dict_kind_counts.get(dict_c["kind"], 0) + 1

    return {
        "modules_scanned_total": len(list_modules_scanned),
        "modules_scanned": sorted(list_modules_scanned),
        "modules_skipped_whitelist_ip": sorted(list_modules_skipped_whitelist),
        "candidates_total": len(list_all_candidates),
        "candidates_by_kind": dict_kind_counts,
        "candidates": list_all_candidates,
        "gated_candidates_total": len(list_all_gated_candidates),
        "gated_candidates": list_all_gated_candidates,
    }


def _format_markdown_report(dict_result: dict[str, Any], dict_validation: dict[str, Any]) -> str:
    list_lines: list[str] = []
    list_lines.append("# PPG Item 4b Phase 2 —— 跨域读取候选检测")
    list_lines.append("")
    list_lines.append(
        "检测范围：同一模块内的直接读取、经一跳组合 assign 的间接读取两类"
        "（严格按 Verilog 模块作用域，见脚本 docstring 的范围边界说明；不做跨模块数据流追踪；"
        "曾经尝试过的『组合直通到输出端口』第三类已因真实验证为纯噪音而移除，见脚本 docstring）。"
    )
    list_lines.append("")
    list_lines.append("## 扫描范围统计")
    list_lines.append("")
    list_lines.append(f"- 真实扫描的非白名单模块数：{dict_result['modules_scanned_total']}")
    list_lines.append(
        f"- 白名单 IP 模块（跳过，理由见脚本 docstring）：{', '.join(dict_result['modules_skipped_whitelist_ip'])}"
    )
    list_lines.append(f"- 主候选（未门控/无法判定门控，Phase 2 验收口径的『候选』）总数：{dict_result['candidates_total']}")
    for str_kind, int_count in sorted(dict_result["candidates_by_kind"].items()):
        list_lines.append(f"  - {str_kind}: {int_count}")
    list_lines.append(f"- 门控候选（已被独立条件门控，留给 Phase 3 判断门控信号本身是否安全）总数：{dict_result['gated_candidates_total']}")
    list_lines.append("")

    list_lines.append("## Phase 2 验证用例结果（依据 changelog 重建的合成负例 + 真实 V1.3 现状对照）")
    list_lines.append("")
    for dict_v in dict_validation["cases"]:
        str_status = "PASS" if dict_v["pass"] else "FAIL"
        list_lines.append(f"- [{str_status}] {dict_v['label']}：{dict_v['detail']}")
    list_lines.append("")
    list_lines.append(
        "**声明**：上面『合成负例』这个用例的输入文件是本次依据 `ppg_spi_register_file.v` V1.3 版本头 "
        "changelog 对 V1.2 旧实现的完整文字描述重建的最小片段（"
        f"`{dict_validation['synthetic_negative_file']}`），**不是真实历史文件**——项目本身不是 git "
        "仓库，V1.2 的真实源码不存在于任何快照目录里（同一结论 Phase 1 已经核实过，见规划文档）。"
    )
    list_lines.append("")

    if dict_result["candidates"]:
        list_lines.append("## 主候选列表（未门控/无法判定门控）")
        list_lines.append("")
        for dict_c in dict_result["candidates"]:
            list_lines.append(f"- [{dict_c['kind']}] `{dict_c['module']}`.`{dict_c['target_register']}`（写入域 {dict_c['write_domain']}）")
            str_via = f"（经组合 wire `{dict_c['via_assign_wire']}`）" if dict_c["kind"] == CANDIDATE_KIND_INDIRECT else ""
            list_lines.append(
                f"  - 被同模块 line {dict_c['reader_always_line_start']}-{dict_c['reader_always_line_end']} 的 "
                f"{dict_c['reader_domain']} 域 always 块直接读取{str_via}"
            )
            list_lines.append(f"  - 证据行：`{dict_c['evidence_line']}`")
        list_lines.append("")
    else:
        list_lines.append("## 主候选列表（未门控/无法判定门控）")
        list_lines.append("")
        list_lines.append("（无）")
        list_lines.append("")

    if dict_result["gated_candidates"]:
        list_lines.append("## 门控候选列表（已被独立条件门控，Phase 3 需要判断门控信号本身是否安全）")
        list_lines.append("")
        for dict_c in dict_result["gated_candidates"]:
            list_lines.append(f"- [{dict_c['kind']}] `{dict_c['module']}`.`{dict_c['target_register']}`（写入域 {dict_c['write_domain']}）")
            str_via = f"（经组合 wire `{dict_c['via_assign_wire']}`）" if dict_c["kind"] == CANDIDATE_KIND_INDIRECT else ""
            list_lines.append(
                f"  - 被同模块 line {dict_c['reader_always_line_start']}-{dict_c['reader_always_line_end']} 的 "
                f"{dict_c['reader_domain']} 域 always 块门控读取{str_via}"
            )
            list_lines.append(f"  - 证据行：`{dict_c['evidence_line']}`")
        list_lines.append("")

    return "\n".join(list_lines)


# ---------------------------------------------------------------------------
# 验证：依据 changelog 重建的最小合成负例 + 真实 V1.3 现状对照
# ---------------------------------------------------------------------------

# 依据 ppg_spi_register_file.v V1.3 版本头 changelog 对 V1.2 旧实现的完整文字描述重建
# （"reg_diag_sync_meta 无门控每拍采样 reg_diag_snapshot 的原始写法"）。明确声明：这不是真实
# 历史文件，项目不是 git 仓库、V1.2 真实源码不存在于任何快照目录（Phase 1 已核实同一结论）。
SYNTHETIC_NEGATIVE_V1_2_RECONSTRUCTION = """`timescale 1ns / 1ps

// 依据 ppg_spi_register_file.v V1.3 changelog 对 V1.2 旧实现文字描述重建的最小合成负例，
// 不是真实历史文件——用于验证 Phase 2 工具能否检出"无门控每拍连续采样"这一真实曾经存在过的
// 结构性 CDC 缺陷形状。真实历史缺陷完整描述见 memory
// project-ppg-stage3-item4a-extension-spi-diag-tearing-confirmed-20260914。
module cdc_phase2_synthetic_v1_2_negative
(
	input i_clk,
	input i_rstn,
	input i_source_clk,
	input i_source_rstn,
	input [303:0] i_dummy_next,
	output [303:0] o_dummy
);

	reg [303:0] reg_diag_snapshot;
	reg [303:0] reg_diag_sync_meta;

	// CLK_2M 域：整体捕获快照（对应真实文件里的 reg_diag_snapshot 写入 always 块）
	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_diag_snapshot <= {304{1'b0}};
		end else begin
			reg_diag_snapshot <= i_dummy_next;
		end
	end

	// SPI_SCLK 域：V1.2 真实曾经存在过的无门控写法，每拍连续直接采样 CLK_2M 域总线
	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_diag_sync_meta <= {304{1'b0}};
		end else begin
			reg_diag_sync_meta <= reg_diag_snapshot;
		end
	end

	assign o_dummy = reg_diag_sync_meta;

endmodule
"""


def _run_synthetic_negative_case() -> dict[str, Any]:
    """把重建的 V1.2 合成负例落盘、解析、跑检测，确认产出未门控主候选。"""
    path_tmp = PATH_SELF_DIR / "_phase2_synthetic_v1_2_negative.v"
    path_tmp.write_text(SYNTHETIC_NEGATIVE_V1_2_RECONSTRUCTION, encoding="utf-8")
    try:
        dict_report = build_ast_report_for_path(path_tmp)
        dict_module = dict_report["modules"][0]

        dict_write_domain = {
            "reg_diag_snapshot": mod_phase1.DOMAIN_CLK2M,
            "reg_diag_sync_meta": mod_phase1.DOMAIN_SPI,
        }
        dict_read_domain_by_line: dict[int, str] = {}
        for dict_always in dict_module.get("always", []):
            if "reg_diag_snapshot" in (dict_always.get("targets") or []):
                dict_read_domain_by_line[dict_always["line_start"]] = mod_phase1.DOMAIN_CLK2M
            elif "reg_diag_sync_meta" in (dict_always.get("targets") or []):
                dict_read_domain_by_line[dict_always["line_start"]] = mod_phase1.DOMAIN_SPI

        list_candidates, list_gated = find_cross_domain_read_candidates_for_module(
            "cdc_phase2_synthetic_v1_2_negative", dict_module, dict_write_domain, dict_read_domain_by_line
        )
        # 候选的 target_register 字段记的是"被跨域读取的源寄存器"（reg_diag_snapshot，CLK_2M），
        # 不是读它的那个寄存器（reg_diag_sync_meta，SPI_SCLK）——用 evidence_line 定位到具体是
        # reg_diag_sync_meta 这次读取命中的，而不是凭空假设 target_register 字段的含义。
        bool_found = any(
            c["target_register"] == "reg_diag_snapshot"
            and c["kind"] == CANDIDATE_KIND_DIRECT
            and not c["gated"]
            and "reg_diag_sync_meta" in c["evidence_line"]
            for c in list_candidates
        )
        return {
            "label": "合成负例（依据changelog重建，非真实历史文件）：V1.2无门控写法产出未门控主候选",
            "pass": bool_found,
            "detail": f"主候选={len(list_candidates)}项, 门控候选={len(list_gated)}项, 命中未门控reg_diag_snapshot被reg_diag_sync_meta读取的候选={bool_found}",
        }
    finally:
        path_tmp.unlink(missing_ok=True)


SYNTHETIC_INDIRECT_VIA_ASSIGN_CASE = """`timescale 1ns / 1ps

// 纯合成单元测试片段（不对应任何真实项目文件），验证 indirect_via_assign_read 检测路径：
// reg_source（CLK_2M）经同模块组合 assign w_alias = reg_source 转一手，
// 再被另一个 SPI_SCLK 域 always 块无门控读取 w_alias——本项目真实扫描里这条路径命中数为 0，
// 用这个合成片段单独证明检测逻辑本身是通的，不是死代码。
module cdc_phase2_synthetic_indirect_case
(
	input i_clk,
	input i_rstn,
	input i_source_clk,
	input i_source_rstn,
	input [7:0] i_dummy_next,
	output [7:0] o_dummy
);

	reg [7:0] reg_source;
	reg [7:0] reg_indirect_reader;
	wire [7:0] w_alias;

	assign w_alias = reg_source;

	always@(posedge i_clk or negedge i_rstn)begin
		if(i_rstn == 1'b0)begin
			reg_source <= 8'd0;
		end else begin
			reg_source <= i_dummy_next;
		end
	end

	always@(posedge i_source_clk or negedge i_source_rstn)begin
		if(i_source_rstn == 1'b0)begin
			reg_indirect_reader <= 8'd0;
		end else begin
			reg_indirect_reader <= w_alias;
		end
	end

	assign o_dummy = reg_indirect_reader;

endmodule
"""


def _run_synthetic_indirect_case() -> dict[str, Any]:
    """验证 indirect_via_assign_read 检测路径本身能真实命中（不是从未被跑过的死代码）。"""
    path_tmp = PATH_SELF_DIR / "_phase2_synthetic_indirect_case.v"
    path_tmp.write_text(SYNTHETIC_INDIRECT_VIA_ASSIGN_CASE, encoding="utf-8")
    try:
        dict_report = build_ast_report_for_path(path_tmp)
        dict_module = dict_report["modules"][0]

        dict_write_domain = {
            "reg_source": mod_phase1.DOMAIN_CLK2M,
            "reg_indirect_reader": mod_phase1.DOMAIN_SPI,
        }
        dict_read_domain_by_line: dict[int, str] = {}
        for dict_always in dict_module.get("always", []):
            if "reg_source" in (dict_always.get("targets") or []):
                dict_read_domain_by_line[dict_always["line_start"]] = mod_phase1.DOMAIN_CLK2M
            elif "reg_indirect_reader" in (dict_always.get("targets") or []):
                dict_read_domain_by_line[dict_always["line_start"]] = mod_phase1.DOMAIN_SPI

        list_candidates, list_gated = find_cross_domain_read_candidates_for_module(
            "cdc_phase2_synthetic_indirect_case", dict_module, dict_write_domain, dict_read_domain_by_line
        )
        bool_found = any(
            c["target_register"] == "reg_source"
            and c["kind"] == CANDIDATE_KIND_INDIRECT
            and not c["gated"]
            and c.get("via_assign_wire") == "w_alias"
            for c in list_candidates
        )
        return {
            "label": "纯合成单元测试：indirect_via_assign_read 路径能真实命中（本项目真实扫描里此路径命中数为0，需要独立证明不是死代码）",
            "pass": bool_found,
            "detail": f"主候选={len(list_candidates)}项, 门控候选={len(list_gated)}项, 命中经w_alias间接读取候选={bool_found}",
        }
    finally:
        path_tmp.unlink(missing_ok=True)


def _run_real_v1_3_case(dict_full_result: dict[str, Any]) -> dict[str, Any]:
    """核对真实 V1.3 当前代码里，同一个寄存器谱系的读取已经从『主候选』降级为『门控候选』。

    候选的 `target_register` 字段记的是被跨域读取的源寄存器（`reg_diag_snapshot`，CLK_2M），
    真正标识"是不是这次读取"要靠 `evidence_line` 里出现 `reg_diag_snapshot_gated`
    （V1.3 真实读取它的那个寄存器名）。
    """

    def _matches(dict_c: dict[str, Any]) -> bool:
        return (
            dict_c["module"] == "ppg_spi_register_file"
            and dict_c["target_register"] == "reg_diag_snapshot"
            and dict_c["kind"] == CANDIDATE_KIND_DIRECT
            and "reg_diag_snapshot_gated" in dict_c["evidence_line"]
        )

    bool_in_main_candidates = any(_matches(c) for c in dict_full_result["candidates"])
    bool_in_gated_candidates = any(_matches(c) and c["gated"] for c in dict_full_result["gated_candidates"])
    return {
        "label": "真实V1.3当前代码：reg_diag_snapshot_gated读取reg_diag_snapshot已从主候选消失，改列门控候选",
        "pass": (not bool_in_main_candidates) and bool_in_gated_candidates,
        "detail": f"是否仍在主候选={bool_in_main_candidates}（应为False）, 是否在门控候选={bool_in_gated_candidates}（应为True）",
    }


def run_validation(dict_full_result: dict[str, Any]) -> dict[str, Any]:
    """跑 Phase 2 规划要求的验证方式：合成负例 vs 真实 V1.3 现状对照。"""
    dict_case_negative = _run_synthetic_negative_case()
    dict_case_real = _run_real_v1_3_case(dict_full_result)
    return {
        "synthetic_negative_file": "ppg_system_integration/cross_reference_tools/_phase2_synthetic_v1_2_negative.v（运行期临时生成，运行后自动删除，不是长期留存的项目文件）",
        "cases": [dict_case_negative, dict_case_real],
        "all_pass": dict_case_negative["pass"] and dict_case_real["pass"],
    }


# ---------------------------------------------------------------------------
# --selftest：不跑真实项目扫描，只验证分支分类器 + 读写切分器 + 端到端合成负例
# ---------------------------------------------------------------------------


def selftest() -> int:
    int_failures = 0

    def _check(str_label: str, bool_condition: bool) -> None:
        nonlocal int_failures
        str_status = "PASS" if bool_condition else "FAIL"
        print(f"[{str_status}] {str_label}")
        if not bool_condition:
            int_failures += 1

    print("=== 分支门控分类器单元测试（对照 ppg_spi_register_file.v:549-555 真实结构） ===")
    list_lines_real_shape = [
        "if(i_source_rstn == 1'b0)begin",
        "reg_diag_snapshot_gated <= {304{1'b0}};",
        "end else if(w_diag_snapshot_gate_event)begin",
        "reg_diag_snapshot_gated <= reg_diag_snapshot;",
        "end else begin",
        "reg_diag_snapshot_gated <= reg_diag_snapshot_gated;",
        "end",
    ]
    list_branches = classify_always_line_branches(list_lines_real_shape)
    _check(
        "if/else_if/else 三分支各自标注正确",
        list_branches
        == [
            BRANCH_KIND_IF,
            BRANCH_KIND_IF,
            BRANCH_KIND_ELSE_IF,
            BRANCH_KIND_ELSE_IF,
            BRANCH_KIND_ELSE,
            BRANCH_KIND_ELSE,
            BRANCH_KIND_ELSE,
        ],
    )

    list_lines_v1_2_shape = [
        "if(i_source_rstn == 1'b0)begin",
        "reg_diag_sync_meta <= {304{1'b0}};",
        "end else begin",
        "reg_diag_sync_meta <= reg_diag_snapshot;",
        "end",
    ]
    list_branches_v1_2 = classify_always_line_branches(list_lines_v1_2_shape)
    _check(
        "V1.2无门控形状：读取行落在裸else（无条件fallback）分支",
        list_branches_v1_2[3] == BRANCH_KIND_ELSE,
    )

    print("\n=== 读/写occurrence切分单元测试 ===")
    _check(
        "非阻塞赋值行：目标名只出现在LHS不算读取",
        find_read_positions_in_line("reg_diag_sync_meta", "reg_diag_sync_meta <= 1'b0;", False) == [],
    )
    _check(
        "非阻塞赋值行：源寄存器出现在RHS算读取",
        len(find_read_positions_in_line("reg_diag_snapshot", "reg_diag_sync_meta <= reg_diag_snapshot;", False)) == 1,
    )
    _check(
        "分支头行：条件表达式里的信号名算读取",
        len(find_read_positions_in_line("w_diag_snapshot_gate_event", "end else if(w_diag_snapshot_gate_event)begin", True))
        == 1,
    )
    _check(
        "无赋值运算符的内容行：整行都算读取环境",
        len(find_read_positions_in_line("reg_x", "case(reg_x)", False)) == 1,
    )

    print("\n=== 端到端：合成负例产出未门控主候选（依据changelog重建，非真实历史文件） ===")
    dict_case_negative = _run_synthetic_negative_case()
    _check(dict_case_negative["label"], dict_case_negative["pass"])

    print("\n=== 端到端：indirect_via_assign_read 路径单独验证（纯合成，证明不是死代码） ===")
    dict_case_indirect = _run_synthetic_indirect_case()
    _check(dict_case_indirect["label"], dict_case_indirect["pass"])

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

    dict_result = run_phase2()
    dict_validation = run_validation(dict_result)

    print(f"真实扫描的非白名单模块数：{dict_result['modules_scanned_total']}")
    print(f"白名单 IP 模块（跳过）：{dict_result['modules_skipped_whitelist_ip']}")
    print(f"主候选总数：{dict_result['candidates_total']}  按类型：{dict_result['candidates_by_kind']}")
    print(f"门控候选总数：{dict_result['gated_candidates_total']}")
    print("\n验证用例：")
    for dict_v in dict_validation["cases"]:
        str_status = "PASS" if dict_v["pass"] else "FAIL"
        print(f"  [{str_status}] {dict_v['label']}: {dict_v['detail']}")

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
