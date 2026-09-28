#!/usr/bin/env python3
"""PPG cross-reference reconciliation script (Phase 2, workflow doc 2026-09-05/06).

Reads three real sources and cross-checks them against each other:
  1. ppg_system_integration/PPG_ALIAS_MAPPING_TABLE.md (the alias mapping table)
  2. every `@satisfies: <ID>[, <ID>...]` RTL comment tag under the project
  3. every acceptance-ID mention in PPG_CONTRACT_CLOSURE_MATRIX.md and the 25 active
     contract .md files, together with any CLOSED/PARTIAL/EVIDENCE_PENDING/NOT_CLOSED
     status keyword found on the same line

For each known ID it reports one of:
  A_CONSISTENT        - alias table has a real mapping AND an RTL @satisfies tag exists
  B_TAG_MISSING       - alias table has a real mapping but no RTL @satisfies tag was found
                        (a tagging gap, not an evidence gap)
  C_UNVERIFIED_CLOSED - matrix/contract text asserts CLOSED or PARTIAL for this ID but the
                        alias table has no real mapping row for it (the assertion was never
                        actually cross-checked against real evidence)
  D_PENDING_KNOWN     - matrix text says EVIDENCE_PENDING/NOT_CLOSED and there is no alias
                        mapping either; this is an honest, already-known open item, not a
                        new problem
  E_STALE_MATRIX_TEXT - alias table HAS a real mapping (real evidence exists) but the matrix
                        text for this ID still says EVIDENCE_PENDING/NOT_CLOSED; the matrix
                        prose itself is stale and should be updated to point at the alias
                        table / Section 13 rather than re-asserting a pending state

This intentionally does not force everything into a 3-box scheme; D and E are real,
previously-observed patterns in this project (TOP-06, K01-K05, D01 chain) and collapsing
them into A/B/C would hide exactly the kind of finding this project has repeatedly needed
to catch.

Usage (from repo root D:\\PPG\\verilog\\jxa):
    python ppg_system_integration/cross_reference_tools/reconcile_acceptance_ids.py \
        --json ppg_system_integration/cross_reference_tools/reconciliation_report.json \
        --markdown ppg_system_integration/cross_reference_tools/reconciliation_report.md
"""

import argparse
import datetime
import json
import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
INTEGRATION_DIR = REPO_ROOT / "ppg_system_integration"
ALIAS_TABLE_PATH = INTEGRATION_DIR / "PPG_ALIAS_MAPPING_TABLE.md"
MATRIX_PATH = INTEGRATION_DIR / "PPG_CONTRACT_CLOSURE_MATRIX.md"

# Directories that must never be scanned as "current" evidence: archives, baselines,
# history and legacy copies are explicitly non-normative per the matrix's own Section 2.
EXCLUDED_DIR_MARKERS = (
    "_archive_",
    "baselines",
    "history",
    "legacy",
    ".git",
)

# The 25 active contracts (C01-C25) live directly under ppg_system_integration/ as the
# *_CONTRACT.md / *_INTERFACE_CONTRACT.md files; this glob intentionally also enumerates
# module-local *_semantic_contract.md files (C02, C05) which live in their own module dirs.
CONTRACT_GLOBS = [
    "ppg_system_integration/*CONTRACT*.md",
    "*/*_semantic_contract.md",
]

ID_PATTERN = re.compile(
    r"""
    G-FP-0[1-7](?:-D01-0[1-9])?          # G-FP-01 .. G-FP-07, optionally -D01-01 style
  | Acceptance-D01-0[1-9]
  | \bD0[1-9]\b
  | \bL0[1-9]\b
  | \bK0[1-5]\b
  | \bTOP-\d{2}\b
  | \bP\d{2}\b
  | \bN0[1-8]\b
  | \bJNT-\d{2}[A-Z]?\b
  | \bSID-\d{2}\b
  | \bLFA-\d{2}\b
  | \bOIB-\d{2}\b
  | \bPRC-\d{2}\b
  | \bRRC-\d{2}\b
  | \bTRK-\d{2}\b
  | \bNRE-\d{2}\b
  | \bILM-\d{2}\b
  | \bADCN-\d{2}\b
  | \bISE-\d{2}\b
  | \bPVW-\d{2}\b
  | \bPWC-\d{2}\b
  | \bFIR-\d{2}\b
    """,
    re.VERBOSE,
)

STATUS_PATTERN = re.compile(
    r"`?(CONTRACT_CLOSED|CLOSED|PARTIAL|EVIDENCE_PENDING|NOT_CLOSED)`?"
)

SATISFIES_PATTERN = re.compile(r"@satisfies:\s*([^*/\n]+)")


def is_excluded(path: Path) -> bool:
    parts = {p.lower() for p in path.parts}
    for marker in EXCLUDED_DIR_MARKERS:
        if any(marker in p for p in parts):
            return True
    return False


def expand_range_token(token):
    """Expand a single '<PREFIX>-<NN>~<MM>' style token into individual IDs.

    Only handles the simple numeric-range shorthand actually used in this project's
    own prose (e.g. 'TOP-01~05'); anything else is returned unexpanded.
    """
    m = re.match(r"^([A-Za-z\-]+)(\d{2})~(\d{2})$", token)
    if not m:
        return [token]
    prefix, lo, hi = m.group(1), int(m.group(2)), int(m.group(3))
    return [f"{prefix}{n:02d}" for n in range(lo, hi + 1)]


def parse_alias_table(path: Path):
    """Return {id: [{"tb": str, "rtl": str, "source": str, "no_mapping": bool}, ...]}."""
    mapping = {}
    if not path.exists():
        return mapping
    text = path.read_text(encoding="utf-8")
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("|") or line.startswith("| ---"):
            continue
        cols = [c.strip() for c in line.strip("|").split("|")]
        if len(cols) < 4:
            continue
        id_cell, tb_cell, rtl_cell, source_cell = cols[0], cols[1], cols[2], cols[3]
        if id_cell in ("验收ID", "字段"):
            continue
        raw_ids_found = ID_PATTERN.findall(id_cell)
        if not raw_ids_found:
            continue
        ids_found = []
        for raw in raw_ids_found:
            ids_found.extend(expand_range_token(raw))
        no_mapping = "无映射" in rtl_cell or "无映射" in tb_cell
        for raw_id in ids_found:
            mapping.setdefault(raw_id, []).append(
                {
                    "tb": tb_cell,
                    "rtl": rtl_cell,
                    "source": source_cell,
                    "no_mapping": no_mapping,
                    "row": id_cell,
                }
            )
    return mapping


def scan_rtl_tags(root: Path):
    """Return {id: [{"file": str, "line": int}, ...]} for every @satisfies tag."""
    tags = {}
    for v_file in root.rglob("*.v"):
        if is_excluded(v_file.relative_to(root)):
            continue
        try:
            text = v_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            m = SATISFIES_PATTERN.search(line)
            if not m:
                continue
            id_list = [tok.strip() for tok in m.group(1).split(",") if tok.strip()]
            rel = v_file.relative_to(root).as_posix()
            for raw_id in id_list:
                expanded = expand_range_token(raw_id)
                for one_id in expanded:
                    tags.setdefault(one_id, []).append({"file": rel, "line": lineno})
    return tags


def scan_matrix_and_contracts(root: Path):
    """Return {id: [{"file": str, "line": int, "status": str|None, "text": str}, ...]}."""
    mentions = {}
    candidate_files = set()
    if MATRIX_PATH.exists():
        candidate_files.add(MATRIX_PATH)
    for pattern in CONTRACT_GLOBS:
        for f in root.glob(pattern):
            if is_excluded(f.relative_to(root)):
                continue
            candidate_files.add(f)

    for md_file in sorted(candidate_files):
        try:
            text = md_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        rel = md_file.relative_to(root).as_posix()
        for lineno, line in enumerate(text.splitlines(), start=1):
            ids_here = set(ID_PATTERN.findall(line))
            if not ids_here:
                continue
            status_m = STATUS_PATTERN.search(line)
            status = status_m.group(1) if status_m else None
            for one_id in ids_here:
                mentions.setdefault(one_id, []).append(
                    {"file": rel, "line": lineno, "status": status, "text": line.strip()[:200]}
                )
    return mentions


def classify(all_ids, alias_map, rtl_tags, matrix_mentions):
    results = {}
    for one_id in sorted(all_ids):
        alias_rows = alias_map.get(one_id, [])
        has_real_alias = any(not r["no_mapping"] for r in alias_rows)
        has_rtl_tag = one_id in rtl_tags

        mentions = matrix_mentions.get(one_id, [])
        statuses = [m["status"] for m in mentions if m["status"]]
        asserts_closed = any(s in ("CLOSED", "CONTRACT_CLOSED", "PARTIAL") for s in statuses)
        asserts_pending = any(s in ("EVIDENCE_PENDING", "NOT_CLOSED") for s in statuses)

        if has_real_alias and asserts_pending and not asserts_closed:
            category = "E_STALE_MATRIX_TEXT"
        elif has_real_alias and has_rtl_tag:
            category = "A_CONSISTENT"
        elif has_real_alias and not has_rtl_tag:
            category = "B_TAG_MISSING"
        elif has_rtl_tag and not has_real_alias:
            # Symmetric to B: RTL is tagged but the alias table has no row for it at
            # all (not even a "no mapping" row). Same severity as B - a bookkeeping
            # gap in the alias table, not a missing-evidence problem.
            category = "B2_ALIAS_ROW_MISSING"
        elif asserts_closed and not has_real_alias:
            category = "C_UNVERIFIED_CLOSED"
        elif not has_real_alias and not has_rtl_tag:
            # Nothing in the alias table, no RTL tag, and no CLOSED/PARTIAL assertion
            # was found anywhere this script looked. Split further by whether an
            # explicit EVIDENCE_PENDING/NOT_CLOSED status was found on the same line
            # as the ID (a self-declared open item) versus no status keyword at all
            # (most acceptance-ID definition lines in the 25 contracts read this way -
            # status is usually asserted at the family/table level, not per line).
            if asserts_pending:
                category = "D_PENDING_KNOWN"
            else:
                category = "D2_NO_STATUS_FOUND"
        else:
            category = "F_UNCLASSIFIED"

        results[one_id] = {
            "category": category,
            "has_real_alias": has_real_alias,
            "has_rtl_tag": has_rtl_tag,
            "asserts_closed_or_partial": asserts_closed,
            "asserts_pending": asserts_pending,
            "alias_rows": alias_rows,
            "rtl_tag_locations": rtl_tags.get(one_id, []),
            "matrix_mentions": mentions[:5],
        }
    return results


def render_markdown(results, generated_at):
    lines = []
    lines.append("# PPG 交叉引用核对表 (自动生成,脚本产物)")
    lines.append("")
    lines.append(f"生成时间: {generated_at}")
    lines.append("")
    lines.append(
        "由 `ppg_system_integration/cross_reference_tools/reconcile_acceptance_ids.py` 生成。"
        "任何人工修改前必须重新运行该脚本,不要手工编辑本表格内容。"
    )
    lines.append("")

    counts = {}
    for r in results.values():
        counts[r["category"]] = counts.get(r["category"], 0) + 1
    lines.append("## 汇总计数")
    lines.append("")
    lines.append("| 分类 | 数量 | 含义 |")
    lines.append("| --- | ---: | --- |")
    legend = {
        "A_CONSISTENT": "别名表有真实映射 + RTL有标签,真正一致,无需动作",
        "B_TAG_MISSING": "别名表有真实映射但RTL标签缺失,只是打标签遗漏,非证据问题",
        "B2_ALIAS_ROW_MISSING": "RTL已有@satisfies标签但别名表里连一行都没有,是别名表记录遗漏(与B同级,非证据问题)",
        "C_UNVERIFIED_CLOSED": "矩阵/合同断言CLOSED或PARTIAL但别名表无真实映射记录,断言从未被核实过,需要回去核实证据",
        "D_PENDING_KNOWN": "矩阵断言EVIDENCE_PENDING/NOT_CLOSED且别名表也无映射,已知的诚实开放项,非新问题",
        "D2_NO_STATUS_FOUND": "别名表无映射、RTL无标签,且本脚本没在同一行找到任何CLOSED/PARTIAL/PENDING状态词(该ID的状态通常在family/表格层面陈述,非逐行陈述);多数是Stage5未点名family(TRK/NRE/ILM/ADCN/ISE)或本工作顺序范围外的项,不代表脚本判断有误",
        "E_STALE_MATRIX_TEXT": "别名表已有真实映射(证据存在)但矩阵文字仍写EVIDENCE_PENDING/NOT_CLOSED,矩阵文字本身过期",
        "F_UNCLASSIFIED": "不落入上述任何一类,需要人工判断",
    }
    for cat in ["A_CONSISTENT", "B_TAG_MISSING", "B2_ALIAS_ROW_MISSING", "C_UNVERIFIED_CLOSED", "D_PENDING_KNOWN", "D2_NO_STATUS_FOUND", "E_STALE_MATRIX_TEXT", "F_UNCLASSIFIED"]:
        lines.append(f"| {cat} | {counts.get(cat, 0)} | {legend[cat]} |")
    lines.append("")

    for cat in ["C_UNVERIFIED_CLOSED", "E_STALE_MATRIX_TEXT", "B_TAG_MISSING", "B2_ALIAS_ROW_MISSING", "F_UNCLASSIFIED", "A_CONSISTENT", "D_PENDING_KNOWN", "D2_NO_STATUS_FOUND"]:
        ids_in_cat = sorted([i for i, r in results.items() if r["category"] == cat])
        if not ids_in_cat:
            continue
        lines.append(f"## {cat} ({len(ids_in_cat)}项)")
        lines.append("")
        lines.append("| ID | 别名表映射 | RTL标签位置 | 矩阵/合同断言 |")
        lines.append("| --- | --- | --- | --- |")
        for one_id in ids_in_cat:
            r = results[one_id]
            alias_txt = "; ".join(f"{a['rtl']}" for a in r["alias_rows"][:2]) or "(无)"
            rtl_txt = "; ".join(f"{t['file']}:{t['line']}" for t in r["rtl_tag_locations"][:3]) or "(无)"
            mtx_txt = "; ".join(
                f"{m['file']}:{m['line']}[{m['status'] or '?'}]" for m in r["matrix_mentions"][:2]
            ) or "(无)"
            lines.append(f"| {one_id} | {alias_txt} | {rtl_txt} | {mtx_txt} |")
        lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", default=None, help="Path to write the JSON report")
    parser.add_argument("--markdown", default=None, help="Path to write the Markdown report")
    args = parser.parse_args()

    alias_map = parse_alias_table(ALIAS_TABLE_PATH)
    rtl_tags = scan_rtl_tags(REPO_ROOT)
    matrix_mentions = scan_matrix_and_contracts(REPO_ROOT)

    all_ids = set(alias_map) | set(rtl_tags) | set(matrix_mentions)
    results = classify(all_ids, alias_map, rtl_tags, matrix_mentions)

    generated_at = datetime.datetime.now().isoformat(timespec="seconds")
    report = {
        "generated_at": generated_at,
        "counts": {},
        "results": results,
    }
    for r in results.values():
        report["counts"][r["category"]] = report["counts"].get(r["category"], 0) + 1

    if args.json:
        Path(args.json).write_text(
            json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8"
        )
    if args.markdown:
        Path(args.markdown).write_text(
            render_markdown(results, generated_at), encoding="utf-8"
        )

    print(f"INFO: reconciliation complete; {len(results)} IDs classified.")
    print(f"INFO: counts = {report['counts']}")


if __name__ == "__main__":
    main()
