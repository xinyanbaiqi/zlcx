"""只读收集全部非 legacy TB 的 formatter AST、检索候选和源码哈希。

候选只是人工审阅导航，不自动判定无条件 PASS 或空真，也不是 Verilog 解析器。
唯一结构解析来自仓库 erie-verilog-generator 的 formatter AST。
运行：python -B verification_reports/v9_v16/scripts/v9_collect_evidence.py
"""

from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "verification_reports/v9_v16"
SKILL = ROOT / ".claude/skills/erie-verilog-generator"
sys.path.insert(0, str(SKILL))
from scripts.python.quality.formatter_ast import build_ast_report_for_path


def collect() -> None:
    """收集原文候选及 AST 摘要；所有输出仅位于任务报告目录。"""
    sources = sorted(set((ROOT / "rtl").rglob("tb_*.v")) |
                     set((ROOT / "rtl/ppg_control_top").glob("*.vh")))
    coverage = []
    candidates = []
    for path in sources:
        relative = path.relative_to(ROOT).as_posix()
        lines = path.read_text(encoding="utf-8-sig").splitlines()
        # 文本检索不推断语法，所有候选需要人工检查控制流及场景存在性。
        hits = []
        for number, line in enumerate(lines, 1):
            code = line.strip()
            if not code or code.startswith("//"):
                continue
            tags = []
            if "$display" in code:
                tags.append("display")
            if re.search(r"\b(if|while|wait|check_case|check_condition|check_expect|expect)\b", code):
                tags.append("condition")
            if re.search(r"(>=|<=|toleran|TOLERANCE|watchdog|timeout|TIMEOUT)", code):
                tags.append("range_or_timeout")
            if "$finish" in code or "$fatal" in code or "$stop" in code:
                tags.append("termination")
            if tags:
                hits.append(number)
                context = " ".join(item.strip() for item in lines[max(0, number-3):number+2]
                                   if item.strip() and not item.strip().startswith("//"))
                candidates.append([relative, number, ",".join(tags), code, context])
        try:
            ast = build_ast_report_for_path(path)
            structures = [{"name": module["name"], "counts": module.get("counts", {}),
                           "initials": [{key: item.get(key) for key in ("line_start", "line_end")}
                                        for item in module.get("initials", [])],
                           "tasks": [{key: item.get(key) for key in ("name", "line_start", "line_end")}
                                     for item in module.get("tasks", [])]}
                          for module in ast.get("modules", [])]
            diagnostics = ast.get("diagnostics", [])
        except Exception as exc:
            # .vh 无 module 或 TB 特性可能超出 formatter 模型；不能视为已通过 AST。
            structures = []
            diagnostics = [{"severity": "error", "message": str(exc)}]
        coverage.append({"path": relative, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                         "lines": len(lines), "candidate_lines": len(hits),
                         "structures": structures, "ast_diagnostics": diagnostics})
        print(f"{relative}: candidates={len(hits)} modules={len(structures)}", flush=True)
    OUT.mkdir(parents=True, exist_ok=True)
    with (OUT / "V9_SCAN_CANDIDATES.tsv").open("w", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t")
        writer.writerow(["path", "line", "tags", "source", "nearby_source"])
        writer.writerows(candidates)
    (OUT / "V9_SOURCE_COVERAGE.json").write_text(json.dumps({
        "baseline": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "skill": ".claude/skills/erie-verilog-generator",
        "method": "formatter AST + textual navigation + manual review; candidates are not findings",
        "files": coverage}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"TOTAL files={len(sources)} candidates={len(candidates)}")


if __name__ == "__main__":
    collect()
