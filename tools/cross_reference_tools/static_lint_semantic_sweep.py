#!/usr/bin/env python3
"""对项目当前真实 RTL/TB 源码运行 Erie 静态 lint 的语义类检查子集。

背景：`erie-verilog-generator` skill 自带的 `verilog_lint.py` 命令行入口只支持
单文件；真正支持目录扫描的 `quality_gate.py`/`verilog_generated_deliverable_gate.py`
会把格式化/文件头/命名等大量本项目已知、已接受的历史债务规则也打包进来。这个脚本
100% 复用 skill 自带的 `scripts.python.quality.static_lint.lint_generated_rtl`
检查逻辑（不重新实现任何一条检查），只是换一个更窄的调用入口：把 `lint_generated_rtl`
指向一份临时镜像目录（只包含本项目当前真实的顶层模块源文件，排除 `_archive_*`
历史快照、`legacy_ppg_reference` 参考设计，以及每个模块目录内部的
`validation/`、`history/`、`xsim_*/`、`baselines/` 等快照子目录），然后把结果
过滤到 Stage 3 Item 1 关心的语义类规则码，忽略其余格式类 VG0xx 噪音。

范围说明：只扫描每个 `ppg_*` 顶层目录的直接子文件（`module_dir/*.v`），不递归
进入模块自己的快照子目录——这是按目录层级做的结构性排除，不是关键字猜测。
"""

# future annotations 保持与 skill 自身模块一致的写法风格。
from __future__ import annotations

# 标准库依赖：参数解析、JSON 输出、临时目录、路径操作。
import argparse
import json
import shutil
import sys
import tempfile
from pathlib import Path

# 项目根目录固定为本脚本上溯两级（cross_reference_tools -> ppg_system_integration -> 项目根）。
PATH_PROJECT_ROOT = Path(__file__).resolve().parents[2]  # PPG 项目根目录

# skill 根目录用于导入其 runtime 包。
PATH_SKILL_ROOT = Path(r"C:\Users\d\.claude\skills\erie-verilog-generator")  # erie-verilog-generator skill 根目录

# Stage 3 Item 1 关心的语义类规则码：既有的组合完整性/驱动/风格检查，加上新增的锁存推断检查。
SET_SEMANTIC_CODES = {
    "CASE_DEFAULT",
    "CASE_DEFAULT_XZ",
    "MULTIPLE_DRIVERS",
    "ALWAYS_STAR",
    "MIXED_ASSIGN",
    "COMB_NONBLOCKING_ASSIGN",
    "SEQ_BLOCKING_ASSIGN",
    "IF_ELSE_LATCH",
}


def collect_real_source_files(path_root: Path) -> list[Path]:
    """收集项目当前真实的顶层模块源文件列表。

    参数:
        path_root: PPG 项目根目录。

    返回:
        按稳定顺序排列的 `.v` 文件路径列表；只包含每个 `ppg_*` 顶层目录的
        直接子文件，排除 `_archive_*`/`legacy_ppg_reference` 以及模块目录
        内部的快照子目录。
    """

    # 汇总最终纳入扫描范围的真实源文件。
    list_files: list[Path] = []

    # 只遍历以 `ppg_` 开头的顶层目录，天然排除 `_archive_*` 和 `legacy_ppg_reference`。
    for path_module_dir in sorted(path_root.glob("ppg_*")):

        # 非目录条目（理论上不存在，但保持防御性判断）直接跳过。
        if not path_module_dir.is_dir():
            continue

        # 只取该模块目录的直接子文件，不递归进入 validation/history/xsim_*/baselines 等快照子目录。
        for path_source in sorted(path_module_dir.glob("*.v")):
            list_files.append(path_source)

    # 返回收集到的真实源文件列表。
    return list_files


def stage_files_into_mirror(list_files: list[Path], path_project_root: Path, path_mirror_root: Path) -> None:
    """把选中的源文件复制进临时镜像目录，保持原有相对目录结构。

    参数:
        list_files: 需要镜像的真实源文件列表。
        path_project_root: 项目根目录，用于计算相对路径。
        path_mirror_root: 镜像目标根目录。

    返回:
        无；文件被复制到镜像目录对应的相对路径下。
    """

    # 逐个复制文件，保持 `module_dir/file.v` 的相对结构。
    for path_source in list_files:
        path_rel = path_source.relative_to(path_project_root)
        path_dest = path_mirror_root / path_rel
        path_dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path_source, path_dest)


def run_semantic_sweep(path_project_root: Path) -> tuple[list[dict], list[Path]]:
    """运行语义类静态 lint 扫描并返回过滤后的结果。

    参数:
        path_project_root: PPG 项目根目录。

    返回:
        `(过滤后的问题字典列表, 参与扫描的真实源文件列表)`。
    """

    # 确保能够导入 skill 自带的 runtime 包。
    str_skill_root = str(PATH_SKILL_ROOT)
    if str_skill_root not in sys.path:
        sys.path.insert(0, str_skill_root)

    # 延迟导入，避免脚本在 sys.path 设置前就触发导入失败。
    from scripts.python.quality.static_lint import lint_generated_rtl

    # 先收集本项目当前真实的顶层模块源文件。
    list_files = collect_real_source_files(path_project_root)

    # 在临时目录中镜像这些文件，再把 `lint_generated_rtl` 指向镜像根目录。
    with tempfile.TemporaryDirectory(prefix="erie-semantic-sweep-") as str_temp_dir:
        path_mirror_root = Path(str_temp_dir)
        stage_files_into_mirror(list_files, path_project_root, path_mirror_root)

        # dict_spec 只需要满足 lint_generated_rtl 的最小接口形状。
        dict_spec = {"interfaces": {"ports": []}}

        # 运行 skill 自带的完整静态 lint（内部已跳过 testbench 文件）。
        list_issues = lint_generated_rtl(dict_spec, path_mirror_root)

    # 只保留 Stage 3 Item 1 关心的语义类规则码，过滤掉其余格式类噪音。
    list_filtered = [
        issue.to_dict()
        for issue in list_issues
        if issue.code in SET_SEMANTIC_CODES
    ]

    # 按文件路径、行号排序，便于报告阅读。
    list_filtered.sort(key=lambda d: (d["path"], d["line"], d["code"]))

    # 返回过滤后的问题列表和参与扫描的文件列表。
    return list_filtered, list_files


def main(argv: list[str] | None = None) -> int:
    """脚本入口：运行扫描并打印/导出结果。"""

    # Windows 终端默认代码页不是 UTF-8，这里显式重配置避免中文输出乱码。
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, default=None, help="可选：把过滤后的结果写成 JSON 文件。")
    namespace_args = parser.parse_args(argv)

    list_issues, list_files = run_semantic_sweep(PATH_PROJECT_ROOT)

    print(f"扫描的真实源文件数（含 TB，lint 内部会跳过 TB）：{len(list_files)}")
    print(f"命中的语义类问题总数：{len(list_issues)}")

    dict_count_by_code: dict[str, int] = {}
    for issue in list_issues:
        dict_count_by_code[issue["code"]] = dict_count_by_code.get(issue["code"], 0) + 1
    for str_code in sorted(dict_count_by_code):
        print(f"  {str_code}: {dict_count_by_code[str_code]}")

    print()
    for issue in list_issues:
        print(f"[{issue['severity'].upper()}] [{issue['code']}] {issue['path']}:{issue['line']} {issue['message']}")

    if namespace_args.json is not None:
        namespace_args.json.write_text(
            json.dumps({"files_scanned": len(list_files), "issues": list_issues}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"\n已写入 JSON：{namespace_args.json}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
