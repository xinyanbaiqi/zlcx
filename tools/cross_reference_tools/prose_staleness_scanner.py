#!/usr/bin/env python3
"""扫描合同 `.md` 文字里的"完成度声明"关键词，找出文字滞后于已完成 RTL 的实例。

背景（方案 Stage 3 Item 3，三个真实历史案例，均在
`PPG_CHIP_DIGITAL_TOP_SPI_P2S_INTEGRATION_CONTRACT.md`里发生过）：
  1. V1.8 勘误 -- `CLK_IREF_LED_LOW` 幽灵端口，一度被怀疑是"SSW 未实现"的真实功能缺口，
     后确认是黑盒壳层残留、早已从真实设计删除。
  2. V1.9 勘误 -- `EN_SAR9_IREF_LOW` 命名不一致，与 `ppg_control_top.v` 已冻结的
     `o_en_sar9_iref` 不对称。
  3. V1.13 勘误 -- 第 8.4.2 节字段 12 和第 8.4.5 节的文字仍停留在"glue 顶层 P2S
     打包器接入待做/未做"的措辞，但 V1.11 勘误的 glue 顶层实现早已完成这一步。

这三例的共同点：功能性 TB 检查的是 RTL 对 RTL，不会去检查合同文字本身是否还准确；
只有人工交叉核对才发现。这个脚本把"人工交叉核对"里最机械的一半自动化：找出合同文字里
带"完成度声明"性质的关键词命中，交给人工核实每一处命中背后的 RTL/端口现在是否真的还
符合那句话描述的状态。

误报控制是本脚本的重点，不是次要工作，原因是真实踩过的坑（详见脚本内注释与
`--selftest` 的合成用例）：
  1. 裸词匹配会被大量真实标识符/技术术语淹没 -- 英文 `pending` 在本项目里绝大多数
     场合是硬件状态的技术形容词（`amb_recheck_pending`、"owner-pending 队列"、
     "pending 候选"），不是"这个功能还没做"；反引号包裹的代码片段/标识符更是如此。
  2. 本项目"不删历史"的约定意味着大量勘误记录会永久保留"曾经如何如何"的历史文字
     （例子 1/2/3 的原始案例现在全部以"> Vx.y 勘误：...曾被...一度怀疑/明确保留未做/
     仍停留在...的措辞..."这种历史叙事形式留在文档里）。扫描器必须能区分"现在陈述"
     和"历史引用"，不能把整个版本历史都当成当前状态的滞后声明。
  3. 参考 `reconcile_acceptance_ids.py` 自己在 §13.2 记录的教训（别名表汇总行文字
     里裸写另一个 ID 号会被误当映射证据）-- 这里的等价教训是：合同里"确认某处历史
     文字已经过期"的勘误条目本身会在同一句话里原样引用旧关键词（例如 V1.13 那句话
     字面写着"待做/未做"），如果扫描器不能识别这种自我修正的引用，就会把"已经修好的
     记录"误报成"还没修好"。

这个脚本只负责扫描并打上启发式标签供人工核实，不自动判定"现在真的滞后"还是"只是历史
引用"——后者需要人读 RTL/端口才能确认，这正是本项目一贯的核实纪律（Stage 2 每个批次
都是"先读脚本命中，再读真实 RTL，再下结论"，不是相信脚本第一次输出）。
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

# 项目根目录固定为本脚本上溯两级（cross_reference_tools -> ppg_system_integration -> 项目根）。
PATH_PROJECT_ROOT = Path(__file__).resolve().parents[2]

# 本脚本自己所在目录，用于导入同目录下的既有脚本（不复制其逻辑）。
PATH_SELF_DIR = Path(__file__).resolve().parent
if str(PATH_SELF_DIR) not in sys.path:
    sys.path.insert(0, str(PATH_SELF_DIR))

# 复用既有核对脚本的路径常量和排除逻辑，不重新发明一套合同文件收集规则。
import reconcile_acceptance_ids as mod_reconcile  # noqa: E402

# 复用新鲜度看门狗已经写好的"合同 md 文件收集"逻辑（MATRIX_PATH + CONTRACT_GLOBS，
# 经 is_excluded 过滤），不第三次重复同一套 glob。
import regression_freshness_watchdog as mod_freshness  # noqa: E402

# 这份整合验证方案自己的路径 -- 2026-09-08/09-10 两次被发现内容过期（Notes-on-scope
# 自述），按 Item 3 任务文本自己的要求纳入扫描范围，没有特殊豁免。
PATH_PLAN_FILE = Path(r"C:\Users\d\.claude\plans\sprightly-wobbling-wadler.md")


# ---------------------------------------------------------------------------
# 关键词定义
# ---------------------------------------------------------------------------


@dataclass
class KeywordSpec:
    """一个完成度声明关键词的匹配规格。"""

    label: str
    pattern: re.Pattern
    # 是否是本身就极易与本项目技术术语混淆、需要格外保守的关键词（目前只有英文
    # `pending`）——命中后仍然报告，但标注 low_confidence，不当作强证据。
    low_confidence: bool = False


def _compile_keyword_specs() -> list[KeywordSpec]:
    """构造关键词列表。中文关键词用纯子串匹配（不加 `\\b`），原因见模块说明第 1 条：
    Python `re` 的 `\\w` 在 Unicode 模式下把汉字也算作单词字符，相邻两个汉字之间永远
    没有单词边界，`\\b` 在连续中文语境里几乎总是匹配失败（对着真实语料实测验证过，
    不是猜测）——用 `\\b` 反而会把绝大多数真实命中漏掉。英文关键词保留 `\\b`，因为
    英文词之间有空格/标点分隔，`\\b` 才是有效过滤。
    """

    return [
        KeywordSpec("CN_待做", re.compile(r"待做")),
        KeywordSpec("CN_未做", re.compile(r"未做")),
        KeywordSpec("CN_尚未编写", re.compile(r"尚未编写")),
        KeywordSpec("CN_未实现", re.compile(r"未实现")),
        KeywordSpec("CN_暂缓", re.compile(r"暂缓")),
        KeywordSpec("EN_TODO", re.compile(r"\bTODO\b")),
        KeywordSpec("EN_to_be_done", re.compile(r"\bto be done\b", re.IGNORECASE)),
        KeywordSpec("EN_not_yet", re.compile(r"\bnot yet\b", re.IGNORECASE)),
        # `pending` 收紧到"still/remains/left/is/was pending"这类明确短语，且只在
        # 同一行内匹配（不用 `\s+`，避免跨行换行符把"...is\npending on..."这种纯因为
        # 物理换行而巧合相邻的词组也算命中）。即便如此，实测这个短语在本项目里几乎
        # 全部还是"硬件状态处于 pending"的技术意思（例如"a new lane...is pending"
        # 描述的是一个在途事务，不是"文档没写完"），所以标 low_confidence，人工核实
        # 时优先级最低，需要格外小心不要被英文语感带偏。裸 `pending`（不带这些搭配
        # 词）经实测在本项目里几乎全部是`owner-pending`/`pending候选`/`EVIDENCE_
        # PENDING`这类技术术语或状态令牌，噪音远大于信号，不纳入扫描。
        KeywordSpec(
            "EN_pending_phrase",
            re.compile(r"\b(?:still|remains?|left|is|was)[ \t]+pending\b", re.IGNORECASE),
            low_confidence=True,
        ),
    ]


KEYWORD_SPECS = _compile_keyword_specs()

# 用于识别"引用旧文字"的线索词（本地上下文窗口内出现即视为可能是历史引用，而不是
# 当前陈述）——直接取自 V1.13 真实案例自己的措辞（"...的措辞"）。
CUE_QUOTED_REFERENCE = ("的措辞", "字样", "原文", "写着", "曾写", "引用", "措辞")

# 用于识别"这句话本身就在说明已经修复/已经完成"的线索词——同样取自真实案例
# （V1.13"早已完成"、"纯文本纠正"）。
CUE_SUPERSEDED_LOCAL = (
    "早已完成", "已经完成", "均已实现", "已实现", "已修复", "已解决", "已经实现",
    "纯文本纠正", "纯文本修正", "非本次新增实现", "已经确认",
    "superseded", "already implemented", "already completed", "already fixed",
    "no longer",
)

# 用于识别"整份文件声明自己某一段是非规范历史"的线索词（真实案例：
# `PPG_DIGITAL_TOP_INTERFACE_CONNECTION_CONTRACT.md` 第 14/16-17 行的
# "Normative supersession"/"历史冻结记录（非规范）"声明，覆盖第 32 行的
# "`ppg_control_top.v`仍未实现"这类过期状态文字）——这个检查是整份文件级别的，
# 不要求声明句和关键词命中在同一段落里。
CUE_FILE_LEVEL_DISCLAIMER = (
    "非规范", "仅作历史", "只作历史", "不代表当前", "不定义当前",
    "non-normative", "retained only as historical", "expressly non-normative",
)


@dataclass
class KeywordHit:
    """一次关键词命中及其启发式标签（供人工核实，不是最终判定）。"""

    file: str
    line: int
    keyword: str
    matched_text: str
    line_text: str
    low_confidence: bool
    in_blockquote: bool
    quoted_reference: bool
    superseded_cue_local: bool
    file_has_disclaimer: bool

    @property
    def likely_historical(self) -> bool:
        """启发式猜测：很可能是历史引用而非当前陈述。仍然需要人工读 RTL 核实——
        这只是排优先级用的标签，不是自动判定"没问题"。"""
        if not self.in_blockquote:
            return False
        return self.quoted_reference or self.superseded_cue_local or self.file_has_disclaimer

    def to_dict(self) -> dict:
        return {
            "file": self.file,
            "line": self.line,
            "keyword": self.keyword,
            "matched_text": self.matched_text,
            "line_text": self.line_text,
            "low_confidence": self.low_confidence,
            "in_blockquote": self.in_blockquote,
            "quoted_reference": self.quoted_reference,
            "superseded_cue_local": self.superseded_cue_local,
            "file_has_disclaimer": self.file_has_disclaimer,
            "likely_historical": self.likely_historical,
        }


# ---------------------------------------------------------------------------
# 代码片段排除：反引号内联代码 + 围栏代码块
# ---------------------------------------------------------------------------


def _backtick_spans(line: str) -> list[tuple[int, int]]:
    """返回一行文本里成对反引号包裹的字符区间列表 `[(start, end), ...]`（不含反引号
    本身之外的边界处理，只要落在某个区间内就视为"在代码片段里"）。奇数个反引号时，
    最后一个悬空反引号忽略（没有区间可归属）。
    """
    positions = [i for i, ch in enumerate(line) if ch == "`"]
    spans = []
    for i in range(0, len(positions) - 1, 2):
        spans.append((positions[i], positions[i + 1]))
    return spans


def _is_inside_span(pos: int, spans: list[tuple[int, int]]) -> bool:
    return any(start < pos < end for start, end in spans)


# ---------------------------------------------------------------------------
# 已知局限（2026-09-13 第一次真实扫描 + 人工逐条核实后新发现，记录下来供未来批次
# 复用，不要重新踩坑一遍 —— 与 `reconcile_acceptance_ids.py` 自己的 §13.2 是
# 同一种纪律）：
#
#   (a) 英文叙事引用中文旧关键词时，如果用的是 ASCII 双引号包裹（例如本方案文件
#       自己 taxonomy 一节里 `field-12 "待做" text left stale...`），而不是本文件
#       CUE_QUOTED_REFERENCE 列出的中文线索词（"的措辞"/"字样"等），也不在
#       `>` 勘误块里，就不会被标 `likely_historical`——需要人工确认这是历史引用。
#   (b) 英文里"引用旧措辞做对比"的说法不止"...的措辞"这一种句式，还有
#       "replacing the prior 'X'"、"not a continued 'X' gap"这类通过引号+对比
#       连词表达的写法（真实案例：`PPG_CONTRACT_CLOSURE_MATRIX.md` §12.12a/12.12b
#       D02/D03 FROZEN 段落），当前 CUE 词表不覆盖，同样需要人工确认。
#   (c) 矩阵里存在"冻结的某次审计快照"整节（例如 §12.16 "V4.2 post-edit
#       independent rerun (2026-08-20)"），用表格行而不是 `>` 勘误块承载，矩阵
#       自己在别的章节（§13.1）已经承认这类段落"固有滞后"、不做持续维护——这类
#       整节冻结快照，本工具目前不会自动识别，需要靠人工发现"这一整节本身就是
#       历史快照"这个上下文。
#   (d) 这份整合验证方案自己的 Status 记录用的是 `- **YYYY-MM-DD, 描述**：`
#       项目符号，不是 `>` 勘误块——结构上等价（都是追加式历史日志），但本文件
#       的 `in_blockquote` 检查认不出这种写法，命中会被当成"活体正文"而不是
#       "历史条目"，优先级标注偏保守（不会错误压低成误报，但也不会自动标为
#       历史引用）。
#   (e) 连字符复合词（`not-yet-started`、`not-yet-done`）会让 `\bnot yet\b`
#       完全找不到——真实案例：这份方案文件 2026-09-13 之前的版本里
#       `"D2_NO_STATUS_FOUND` (61 items) is a separate, not-yet-started
#       priority"`一句，用的就是这个连字符写法，本工具第一次真实扫描完全没有
#       报告这处命中，是人工核对附近文字时偶然发现的，不是脚本主动抓到的。
#   (f) 英文 `pending` 即便收紧到"still/remains/left/is/was pending"这类明确
#       短语，在本项目里实测出来的两条真实命中仍然全部是硬件状态术语或蓄意保留
#       的系统级判定文字，不是文档滞后——`low_confidence` 标签是合理的，但不代表
#       这个关键词在本项目里能提供任何真实信号，未来批次可以考虑直接跳过 pending
#       的人工核实，除非上下文明显在谈论"文档/规范/端口连接"本身。
#   (g) `not yet` 也会出现在纯粹描述实时协议/握手顺序的正文里（真实案例：
#       `PPG_REAL_PPG_RAW_GENERATOR_TESTBENCH_CONTRACT.md:293`
#       "the RED ADC owner has not yet been released"，描述的是仿真模型里一个
#       事务尚未释放的时序状态，不是"某功能没写完"）——这是识别符/历史引用之外
#       的第三种误报类别，只能靠读懂整句话的语义来排除，没有便宜的结构性规则。
# ---------------------------------------------------------------------------


def _compute_fence_mask(lines: list[str]) -> list[bool]:
    """返回逐行的"是否在围栏代码块（```...```）内部"布尔列表。"""
    mask = [False] * len(lines)
    in_fence = False
    for idx, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith("```"):
            # 围栏起止行本身不算"内容"，但也不需要单独处理；直接翻转状态。
            in_fence = not in_fence
            mask[idx] = True
            continue
        mask[idx] = in_fence
    return mask


# ---------------------------------------------------------------------------
# 核心扫描逻辑
# ---------------------------------------------------------------------------


def _local_context_window(lines: list[str], idx: int, radius: int = 2) -> str:
    """取命中行前后各 `radius` 行非空行拼接成的局部上下文，用于线索词搜索。

    本项目的勘误段落几乎总是单个物理行里的一整段长文字（已通过真实语料确认），
    所以大多数情况下这个窗口等价于命中行本身；额外前后各 2 行是为了覆盖少数
    真正跨物理行手工换行的段落，属于保守的简化处理，不做完整的段落边界解析。
    """
    lo = max(0, idx - radius)
    hi = min(len(lines), idx + radius + 1)
    return "\n".join(lines[lo:hi])


def scan_text(text: str, file_label: str) -> list[KeywordHit]:
    """对一份文档的全文文本运行关键词扫描，返回命中列表。

    参数:
        text: 文档全文（已按 UTF-8 解码）。
        file_label: 报告里展示用的文件标签（通常是相对路径）。

    返回:
        `KeywordHit` 列表，按行号、关键词顺序排列。
    """
    lines = text.splitlines()
    fence_mask = _compute_fence_mask(lines)

    file_has_disclaimer = any(cue in text for cue in CUE_FILE_LEVEL_DISCLAIMER)

    hits: list[KeywordHit] = []
    for idx, line in enumerate(lines):
        lineno = idx + 1
        if fence_mask[idx]:
            continue

        stripped = line.lstrip()
        in_blockquote = stripped.startswith(">")

        spans = _backtick_spans(line)

        for spec in KEYWORD_SPECS:
            for m in spec.pattern.finditer(line):
                if _is_inside_span(m.start(), spans):
                    continue

                context = _local_context_window(lines, idx)
                quoted_reference = any(cue in context for cue in CUE_QUOTED_REFERENCE)
                superseded_cue_local = any(cue in context for cue in CUE_SUPERSEDED_LOCAL)

                hits.append(
                    KeywordHit(
                        file=file_label,
                        line=lineno,
                        keyword=spec.label,
                        matched_text=m.group(0),
                        line_text=line.strip()[:300],
                        low_confidence=spec.low_confidence,
                        in_blockquote=in_blockquote,
                        quoted_reference=quoted_reference,
                        superseded_cue_local=superseded_cue_local,
                        file_has_disclaimer=file_has_disclaimer,
                    )
                )

    return hits


# ---------------------------------------------------------------------------
# 扫描范围收集
# ---------------------------------------------------------------------------


def collect_scan_targets(path_project_root: Path) -> list[Path]:
    """收集本次扫描的全部目标文件。

    范围（Item 3 任务文本明确要求，逐条落实，不留缺口）：
      1. 直接复用 `regression_freshness_watchdog.collect_contract_md_files`——
         `PPG_CONTRACT_CLOSURE_MATRIX.md` 本身 + `reconcile_acceptance_ids.py`
         自己的 `CONTRACT_GLOBS`（`ppg_system_integration/*CONTRACT*.md` 和
         `*/*_semantic_contract.md`，后者正是任务文本点名的
         `ppg_system_config_manager_semantic_contract.md` 这一类模块级合同），
         经 `is_excluded` 排除 `_archive_*`/`baselines`/`history`/`legacy`/`.git`。
         不重新发明第三套合同文件收集规则。
      2. 这份整合验证方案自身（`PATH_PLAN_FILE`）——按 Item 3 任务文本自己的要求，
         这份文件 2026-09-08/09-10 两次被发现内容过期，理应纳入自己的扫描范围，
         没有特殊豁免。

    范围说明（有意的取舍，不是遗漏）：`ppg_system_integration/` 目录下不含
    "CONTRACT"字样的其他 `.md`（会话交接记录 `PPG_SESSION_HANDOFF_*`、评审记录
    `*_REVIEW_*`/`*_AUDIT_*`、`joint_tb_deliverable_gate.md`等）不在这次范围内——
    这些文件本身就是"某个历史时间点的快照记录"，不是持续维护、需要与当前 RTL
    保持同步的规范性合同文本，混进来只会制造大量"整份文件都是历史叙事"的噪音，
    而不是这个检查要抓的"合同文字忘记更新"问题。这与 `reconcile_acceptance_ids.py`
    自己的 `CONTRACT_GLOBS` 定义完全一致，不是本脚本另开的口子。
    """
    set_files: set[Path] = set(mod_freshness.collect_contract_md_files(path_project_root))

    if PATH_PLAN_FILE.exists():
        set_files.add(PATH_PLAN_FILE)

    return sorted(set_files)


def _label_for(path_file: Path, path_project_root: Path) -> str:
    try:
        return path_file.relative_to(path_project_root).as_posix()
    except ValueError:
        # 项目根目录之外的文件（目前只有 PATH_PLAN_FILE）用绝对路径展示。
        return str(path_file)


def run_scan(path_project_root: Path) -> tuple[list[KeywordHit], list[Path]]:
    """对全部扫描目标运行关键词扫描。

    返回:
        `(全部命中列表, 参与扫描的文件列表)`。
    """
    list_files = collect_scan_targets(path_project_root)
    all_hits: list[KeywordHit] = []
    for path_file in list_files:
        try:
            text = path_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        label = _label_for(path_file, path_project_root)
        all_hits.extend(scan_text(text, label))
    return all_hits, list_files


# ---------------------------------------------------------------------------
# 合成用例自检（先验证判断逻辑，再信任真实扫描结果）
# ---------------------------------------------------------------------------


def _selftest() -> bool:
    """用合成正反例 + 3 个真实历史案例的复原文本验证扫描逻辑，不直接跑真实语料就
    信任第一次输出（与 Stage 3 Item 1 的验证纪律一致）。返回 True 表示全部通过。
    """
    all_ok = True

    def check(name: str, text: str, expect_hits: int, expect_likely_historical: list[bool] | None = None):
        nonlocal all_ok
        hits = scan_text(text, "synthetic")
        ok = len(hits) == expect_hits
        detail = f"expect {expect_hits} hits, got {len(hits)}"
        if ok and expect_likely_historical is not None:
            actual = [h.likely_historical for h in hits]
            ok = actual == expect_likely_historical
            detail += f"; expect likely_historical={expect_likely_historical}, got {actual}"
        status = "PASS" if ok else "FAIL"
        if not ok:
            all_ok = False
            for h in hits:
                detail += f"\n    hit: line={h.line} kw={h.keyword} text={h.line_text!r}"
        print(f"[{status}] {name}: {detail}")

    # --- 正例：真实滞后文字，活体正文（非勘误块），应当被当作当前候选 ---
    check(
        "syn_a_real_current_stale_live_body",
        "本模块的报警输出端口目前仍未实现，等待后续版本补充设计。",
        expect_hits=1,
        expect_likely_historical=[False],
    )

    # --- 反例：勘误块里引用旧文字并说明已经修复（真实 V1.13 案例的结构复现） ---
    check(
        "syn_b_quoted_historical_reference",
        '> V2.0勘误，2026-09-20：修复第5节残留文字"该端口待做"的说法，'
        "V1.8勘误的RTL实现早已完成，此处纯文本纠正，不涉及RTL改动。",
        expect_hits=1,
        expect_likely_historical=[True],
    )

    # --- 反例：真实标识符，反引号包裹，不应命中 ---
    check(
        "syn_c1_identifier_in_backticks",
        "`o_dcs_ir_pending_valid`信号在STOP时清零，不做特殊处理。",
        expect_hits=0,
    )
    check(
        "syn_c2_identifier_underscore_no_backtick",
        "amb_recheck_pending寄存器在复位时清零。",
        expect_hits=0,
    )

    # --- 反例：围栏代码块里的 TODO 注释，不应命中 ---
    check(
        "syn_d_todo_inside_fenced_code",
        "普通说明文字。\n```verilog\n// TODO: add saturation check here\n```\n普通说明文字。",
        expect_hits=0,
    )
    # 正例：同样的 TODO 出现在围栏代码块之外，应当命中
    check(
        "syn_d2_todo_outside_fenced_code",
        "// TODO: add saturation check here 这是遗留在正文里的说明。",
        expect_hits=1,
        expect_likely_historical=[False],
    )

    # --- 反例：英文裸 pending 技术术语，不应命中（不在扫描关键词短语范围内） ---
    check(
        "syn_e_bare_pending_domain_jargon",
        "The scheduler holds a pending candidate until commit.",
        expect_hits=0,
    )

    # --- 命中但低置信度：pending 短语，实测几乎总是硬件状态描述 ---
    hits_f = scan_text("A new lane arrives while another is pending.", "synthetic")
    ok_f = len(hits_f) == 1 and hits_f[0].low_confidence and not hits_f[0].likely_historical
    print(f"[{'PASS' if ok_f else 'FAIL'}] syn_f_pending_phrase_low_confidence: hits={[h.to_dict() for h in hits_f]}")
    if not ok_f:
        all_ok = False

    # --- 真实历史案例复现 1：V1.7 P2S 条目风格 -- 勘误块内，没有本地"已解决"线索词，
    #     应当保留为需要人工核对的候选（不能被"在勘误块里"这一点单独就免检） ---
    check(
        "syn_g_real_v1_7_style_no_local_supersede_cue",
        "> V1.7勘误，2026-09-05：第8.4.5节两步AMI/Top RTL已按已溯源方案实现，"
        "非本合同重新设计。第8.4.5节原列三步中的第①②步（AMI/Top端口）至此完成，"
        "第③步（glue顶层P2S打包器接入这三个端口）明确保留未做——"
        "ppg_chip_digital_top.v本身是另一项独立工作，按用户指示在另一会话进行，"
        "本次不顺带开工，避免两边同时改动冲突。",
        expect_hits=1,
        expect_likely_historical=[False],
    )

    # --- 真实历史案例复现 2：V1.13 条目原文（field-12 文档滞后修复记录本身），
    #     应当被识别为"历史引用 + 已说明修复"，不是新的滞后 ---
    check(
        "syn_h_real_v1_13_verbatim",
        "> V1.13勘误，2026-09-07：修复第8.4.2节字段12和第8.4.5节的文档滞后——"
        '两处文字仍停留在V1.6/V1.7时代"glue顶层P2S打包器接入待做/未做"的措辞，'
        "但V1.11勘误的glue顶层实现早已完成这一步："
        "`ppg_chip_digital_top.v:473-475`将`s1_calibration_applied`/"
        "`stage1_raw`/`stage2_raw`接入P2S打包器，字段12三步全部完成，"
        "非本次新增实现，纯文本纠正，不涉及RTL改动。",
        expect_hits=2,  # "待做" 和 "未做" 各一次
        expect_likely_historical=[True, True],
    )

    # --- 真实历史案例复现 3：DIGITAL_TOP 合同的"整份文件非规范历史声明 + 后文
    #     仍写着过期状态文字"结构 -- 声明句和过期文字不在同一段落/同一次勘误块里，
    #     必须靠文件级 disclaimer 才能标为 likely_historical ---
    check(
        "syn_i_file_level_disclaimer_far_from_hit",
        "> Normative supersession: V1.10 is this file's only current normative "
        "revision. Every V1.3.x/V1.4/V1.9 status statement below is retained only "
        "as historical context and is expressly non-normative where it differs "
        "from V1.10.\n"
        "\n"
        "some unrelated normative section text here to separate the two blocks "
        "so the local context window does not see the disclaimer directly\n"
        "\n"
        "> V1.3.4 status update: Scheduler and AMI have current PASS evidence; "
        "`ppg_control_top.v` 仍未实现",
        expect_hits=1,
        expect_likely_historical=[True],
    )

    return all_ok


# ---------------------------------------------------------------------------
# 命令行入口
# ---------------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    """脚本入口：可选先跑自检，再对真实扫描范围运行一次，打印/导出结果。"""

    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, default=None, help="可选：把全部命中写成 JSON 文件。")
    parser.add_argument("--selftest", action="store_true", help="只运行合成用例自检，不扫描真实文件。")
    parser.add_argument(
        "--skip-selftest",
        action="store_true",
        help="真实扫描前跳过自检（默认每次真实扫描前都会先跑一遍自检，自检失败则拒绝继续）。",
    )
    namespace_args = parser.parse_args(argv)

    if namespace_args.selftest:
        ok = _selftest()
        return 0 if ok else 1

    if not namespace_args.skip_selftest:
        print("=== 真实扫描前自检 ===")
        if not _selftest():
            print("\n自检未通过，拒绝对真实文件运行扫描——先修复扫描逻辑本身。")
            return 1
        print()

    print("=== 真实扫描 ===")
    hits, list_files = run_scan(PATH_PROJECT_ROOT)
    print(f"扫描文件数：{len(list_files)}")
    for f in list_files:
        print(f"  {_label_for(f, PATH_PROJECT_ROOT)}")

    print(f"\n命中总数：{len(hits)}")
    count_likely_historical = sum(1 for h in hits if h.likely_historical)
    count_low_confidence = sum(1 for h in hits if h.low_confidence)
    print(f"  启发式标为「可能是历史引用」：{count_likely_historical}")
    print(f"  低置信度（pending 短语）：{count_low_confidence}")
    print(
        f"  需要优先人工核实（既非历史引用也非低置信度）："
        f"{len(hits) - count_likely_historical - count_low_confidence + sum(1 for h in hits if h.likely_historical and h.low_confidence)}"
    )

    dict_by_keyword: dict[str, int] = {}
    for h in hits:
        dict_by_keyword[h.keyword] = dict_by_keyword.get(h.keyword, 0) + 1
    print("\n按关键词分布：")
    for kw in sorted(dict_by_keyword):
        print(f"  {kw}: {dict_by_keyword[kw]}")

    print("\n逐条命中：")
    for h in sorted(hits, key=lambda h: (h.file, h.line)):
        tag = "历史引用?" if h.likely_historical else ("低置信度" if h.low_confidence else "需核实")
        print(f"  [{tag}] {h.file}:{h.line} [{h.keyword}] {h.line_text}")

    if namespace_args.json is not None:
        namespace_args.json.write_text(
            json.dumps(
                {
                    "files_scanned": [_label_for(f, PATH_PROJECT_ROOT) for f in list_files],
                    "hits": [h.to_dict() for h in hits],
                },
                ensure_ascii=False,
                indent=2,
            ),
            encoding="utf-8",
        )
        print(f"\n已写入 JSON：{namespace_args.json}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
