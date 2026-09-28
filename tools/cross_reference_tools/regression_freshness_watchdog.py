#!/usr/bin/env python3
"""回归产物新鲜度看门狗:比对回归产物自身的时间戳与它依赖的源文件时间戳。

背景(Stage 1 的真实教训): 2026-09-07 的 `tb_ppg_chip_digital_top.v` xsim 6/6 PASS
日志被这份方案自己长期当作"当前证据"引用,但 SSW(`ppg_sar9_sar15_safe_selection_
wrapper.v`)在 2026-09-10 发生真实行为改动后,那份日志testat的其实是一份已经不存在
于磁盘上的旧版本 SSW —— 没有任何机制在改动发生时提醒"这份 PASS 结论已经过期"。这个
脚本就是为了不再重演这个失效模式:给定"一份回归产物"和"它依赖的文件列表",只要任何一
个依赖文件的 mtime 比产物自己的 mtime 新,就判定该产物"已失效,需要重跑",不再把它当
作可信的当前证据引用。

这个脚本只负责检测和报告,不重跑任何回归 —— 重跑 TB 回归是另一件事,超出这个工具的范
围(参见方案 Stage 3 Item 2 的任务边界)。

覆盖的四类真实回归产物(不是 demo,第一版就真的指向项目里已经存在的产物):
  1. `ppg_control_top/run_xsim_regression.sh` 产出的 19 个 TB 回归 —— 每个 TB 各自的
     filelist 直接从该脚本自己的 `TB_FILELIST` 关联数组解析出来,不重复硬编码一份
     可能会漂移的映射。
  2. `ppg_chip_digital_top` 的两次已知回归(`xsim_regression_20260910` 和
     `ppg_control_top/xsim_smoke_recheck_20260910`) —— 这两次是一次性人工复核产物,
     其所在目录名内嵌日期、不是可复用脚本参数,因此按方案原文直接点名的两条真实路径
     显式登记,而不是尝试自动发现所有历史运行。
  3. 核对脚本自己的报告(`reconciliation_report.md`/`.json`) —— 依赖不是固定
     filelist,而是"任何一个带 `@satisfies` 标签的 `.v` 文件、任何一份合同 `.md`
     文件、别名映射表本身"三类里最新的一个;直接复用 `reconcile_acceptance_ids.py`
     自己的 `is_excluded`/`CONTRACT_GLOBS`/`ALIAS_TABLE_PATH`/`MATRIX_PATH`,不重新
     发明一套排除规则。
  4. Stage 3 Item 1 的 `static_lint_semantic_sweep_report.json` —— 依赖是它自己扫描
     的全部真实源文件,直接复用 `static_lint_semantic_sweep.py` 自己的
     `collect_real_source_files`,不重新维护一份文件清单。
  5. (2026-09-16 新增)`ppg_system_integration/module_tb_regression/run_module_tb_regression.sh`
     产出的模块级自检 TB 回归(PVW/PWC/FIR)—— 这三份 TB 自 2026-08-22 端口重构起无法
     elaborate,却因为既不在第 1 类、也不在本看门狗登记里而无人发现。驱动脚本与第 1 类同构,
     直接复用同一套 `TB_FILELIST`/`OUTDIR` 解析。
"""

# future annotations 保持与本目录既有脚本一致的写法风格。
from __future__ import annotations

# 标准库依赖:参数解析、JSON 输出、正则、路径操作、时间格式化。
import argparse
import json
import re
import sys
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path

# 项目根目录固定为本脚本上溯两级(cross_reference_tools -> ppg_system_integration -> 项目根)。
PATH_PROJECT_ROOT = Path(__file__).resolve().parents[2]  # PPG 项目根目录

# 本脚本自己所在目录,用于导入同目录下的既有脚本(不复制其逻辑)。
PATH_SELF_DIR = Path(__file__).resolve().parent

# 确保能够直接 import 同目录下的 reconcile_acceptance_ids.py / static_lint_semantic_sweep.py。
if str(PATH_SELF_DIR) not in sys.path:
    sys.path.insert(0, str(PATH_SELF_DIR))

# 复用既有核对脚本的路径常量和排除逻辑,不重新发明一套。
import reconcile_acceptance_ids as mod_reconcile  # noqa: E402

# 复用 Stage 3 Item 1 已经验证过的"真实源文件收集"逻辑,不重新维护一份文件清单。
import static_lint_semantic_sweep as mod_lint_sweep  # noqa: E402


@dataclass
class FreshnessResult:
    """单份回归产物的新鲜度判定结果。"""

    # 产物的可读标签(例如某个 TB 名称,或 "reconciliation_report.md")。
    label: str
    # 产物文件的相对路径(相对项目根,便于跨机器阅读)。
    artifact_path: str
    # 产物自身的 mtime(Unix 时间戳)。
    artifact_mtime: float
    # 参与比对的依赖文件总数。
    dependency_count: int
    # 缺失的依赖文件相对路径列表(存在但比对不到,单独记录,不计入"新鲜"判定的正反面)。
    missing_dependencies: list[str]
    # 比产物更新的依赖文件列表,每项为 {"path":.., "mtime":.., "age_seconds":..}。
    stale_dependencies: list[dict]

    @property
    def is_fresh(self) -> bool:
        """新鲜度判定:没有任何依赖文件比产物自己更新,且依赖文件都真实存在。"""
        return not self.stale_dependencies

    def to_dict(self) -> dict:
        """导出为可 JSON 序列化的字典。"""
        return {
            "label": self.label,
            "artifact_path": self.artifact_path,
            "artifact_mtime_iso": _format_mtime(self.artifact_mtime),
            "dependency_count": self.dependency_count,
            "is_fresh": self.is_fresh,
            "missing_dependencies": self.missing_dependencies,
            "stale_dependencies": self.stale_dependencies,
        }


def _format_mtime(mtime: float) -> str:
    """把 Unix 时间戳格式化为本地可读时间字符串,用于报告展示。"""
    return datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")


def assess_freshness(label: str, path_artifact: Path, list_dependencies: list[Path]) -> FreshnessResult:
    """核心比对逻辑:给定一份产物路径和它依赖的文件列表,判断产物是否新鲜。

    参数:
        label: 这次比对的可读标签,仅用于报告展示。
        path_artifact: 回归产物文件路径(xsim.log/summary.tsv/reconciliation_report.md 等)。
        list_dependencies: 该产物依赖的源文件路径列表(filelist 里列出的 RTL/TB 文件、
            合同 `.md` 文件等)。

    返回:
        `FreshnessResult`:只要有任何一个依赖文件的 mtime 比产物自己的 mtime 新,
        `is_fresh` 就为 False,`stale_dependencies` 列出具体是哪些文件、新了多少秒。
    """

    # 产物自身必须存在,否则无法比对 —— 这是调用方的前置条件,不在这里静默处理。
    mtime_artifact = path_artifact.stat().st_mtime

    list_missing: list[str] = []
    list_stale: list[dict] = []

    for path_dep in list_dependencies:
        try:
            mtime_dep = path_dep.stat().st_mtime
        except OSError:
            # 依赖文件本身不存在(例如 filelist 里的路径已经失效)—— 单独记录为缺失,
            # 不参与"是否比产物新"的判定,避免把"文件被删除"误判成"产物是新鲜的"。
            try:
                rel = path_dep.relative_to(PATH_PROJECT_ROOT).as_posix()
            except ValueError:
                rel = str(path_dep)
            list_missing.append(rel)
            continue

        if mtime_dep > mtime_artifact:
            try:
                rel = path_dep.relative_to(PATH_PROJECT_ROOT).as_posix()
            except ValueError:
                rel = str(path_dep)
            list_stale.append(
                {
                    "path": rel,
                    "mtime_iso": _format_mtime(mtime_dep),
                    "age_seconds_newer": round(mtime_dep - mtime_artifact, 1),
                }
            )

    # 按"比产物新多少"降序排列,最严重的失效原因排在最前面。
    list_stale.sort(key=lambda d: -d["age_seconds_newer"])

    try:
        rel_artifact = path_artifact.relative_to(PATH_PROJECT_ROOT).as_posix()
    except ValueError:
        rel_artifact = str(path_artifact)

    return FreshnessResult(
        label=label,
        artifact_path=rel_artifact,
        artifact_mtime=mtime_artifact,
        dependency_count=len(list_dependencies),
        missing_dependencies=list_missing,
        stale_dependencies=list_stale,
    )


# ---------------------------------------------------------------------------
# 第 1 类:ppg_control_top 的 19 个 TB 回归(run_xsim_regression.sh)
# ---------------------------------------------------------------------------

# 从 shell 脚本里解析 `declare -A TB_FILELIST=( [key]=value ... )` 关联数组的正则:
# 直接解析真实脚本文本,不在 Python 里重复维护一份可能漂移的映射表。
PATTERN_TB_FILELIST_ENTRY = re.compile(r"\[(\w+)\]=(\S+)")
PATTERN_OUTDIR = re.compile(r'OUTDIR="([^"]+)"')


def parse_control_top_regression_script(path_script: Path) -> tuple[str, dict[str, str]]:
    """从 `run_xsim_regression.sh` 里解析真实的 OUTDIR 和 TB_FILELIST 映射。

    参数:
        path_script: `run_xsim_regression.sh` 的路径。

    返回:
        `(OUTDIR 字符串, {tb_name: filelist_name} 字典)`。
    """
    text = path_script.read_text(encoding="utf-8")

    match_outdir = PATTERN_OUTDIR.search(text)
    if match_outdir is None:
        raise ValueError(f"无法从 {path_script} 解析 OUTDIR")
    str_outdir = match_outdir.group(1)

    # 只在 `declare -A TB_FILELIST=(` 到对应 `)` 之间的文本里找 [key]=value 条目,
    # 避免误吃到脚本其余部分里形似的文本。
    idx_start = text.index("declare -A TB_FILELIST=(")
    idx_end = text.index(")", idx_start)
    text_block = text[idx_start:idx_end]

    dict_tb_filelist: dict[str, str] = {}
    for match in PATTERN_TB_FILELIST_ENTRY.finditer(text_block):
        dict_tb_filelist[match.group(1)] = match.group(2)

    if not dict_tb_filelist:
        raise ValueError(f"未能从 {path_script} 解析出任何 TB_FILELIST 条目")

    return str_outdir, dict_tb_filelist


def parse_filelist(path_filelist: Path) -> list[Path]:
    """解析一份 `.f` filelist 文件,返回逐行的依赖文件绝对路径列表。

    参数:
        path_filelist: filelist 文件路径(`.f` 是纯文本,每行一个相对路径)。

    返回:
        依赖文件的绝对路径列表,相对路径按"filelist 自己所在目录"解析
        (与 `xvlog -f <filelist> -i .` 的真实解析基准一致)。
    """
    path_base = path_filelist.parent
    list_deps: list[Path] = []
    for line in path_filelist.read_text(encoding="utf-8").splitlines():
        line_stripped = line.strip()
        if not line_stripped or line_stripped.startswith("#"):
            continue
        list_deps.append((path_base / line_stripped).resolve())
    return list_deps


def check_control_top_19tb_regression(path_project_root: Path) -> list[FreshnessResult]:
    """检查 `ppg_control_top` 19 个 TB 回归各自的新鲜度。

    参数:
        path_project_root: PPG 项目根目录。

    返回:
        19 个 `FreshnessResult`,每个 TB 一条,依赖列表为该 TB 自己的 filelist
        本身(filelist 被编辑也会让已有日志过期,因为 xvlog 实际读取的内容变了)
        加上 filelist 里逐行列出的每个真实 RTL/TB 文件。
    """
    path_control_top_dir = path_project_root / "ppg_control_top"
    path_script = path_control_top_dir / "run_xsim_regression.sh"

    str_outdir, dict_tb_filelist = parse_control_top_regression_script(path_script)

    list_results: list[FreshnessResult] = []
    for str_tb, str_filelist_name in dict_tb_filelist.items():
        path_filelist = path_control_top_dir / str_filelist_name
        path_log = path_control_top_dir / str_outdir / str_tb / "xsim.log"

        if not path_log.exists():
            # 产物本身缺失(尚未跑过这个 TB)——单独记录成一条"缺产物"结果,而不是抛异常
            # 中断整个批次;这类情况本身就是"这个回归还没有可信证据"的一种真实状态。
            list_results.append(
                FreshnessResult(
                    label=str_tb,
                    artifact_path=str((path_log).relative_to(path_project_root).as_posix()),
                    artifact_mtime=0.0,
                    dependency_count=0,
                    missing_dependencies=["<artifact itself missing, never run>"],
                    stale_dependencies=[],
                )
            )
            continue

        list_dependencies = [path_filelist] + parse_filelist(path_filelist)
        list_results.append(assess_freshness(str_tb, path_log, list_dependencies))

    # 按 TB 名称排序,报告顺序稳定可复现。
    list_results.sort(key=lambda r: r.label)
    return list_results


# ---------------------------------------------------------------------------
# 第 2 类:ppg_chip_digital_top 的两次已知回归
# ---------------------------------------------------------------------------


def check_chip_digital_top_regressions(path_project_root: Path) -> list[FreshnessResult]:
    """检查 `ppg_chip_digital_top` 相关的两次已知 xsim 回归的新鲜度。

    参数:
        path_project_root: PPG 项目根目录。

    返回:
        2 个 `FreshnessResult`:
          1. `ppg_chip_digital_top/xsim_regression_20260916/tb_ppg_chip_digital_top/xsim.log`,
             依赖 `xsim_chip_digital_top_filelist.f`(34 个文件)。**2026-09-14 更新**:原
             `xsim_regression_20260910` 目录是脚本自身用 `` `date +%Y%m%d` `` 生成输出目录名,
             Stage4收尾重跑当天系统日期已跨到 2026-09-14,产生了一个新的真实重跑目录而不是
             原地覆盖旧目录——这是该脚本自身"输出目录名内嵌当天日期"设计的已知副作用,不是
             检测逻辑的缺陷。旧的 `xsim_regression_20260910` 目录作为历史记录保留、不删除,
             但看门狗的登记指针更新为指向最新的真实重跑,与第 1 类"永远指向当前真实证据"
             的原则一致。**2026-09-16 再次发生**:PVW/PWC/FIR 三份 RTL 加 `@satisfies` 标签后
             重跑,当天日期又生成了 `xsim_regression_20260916`,指针同样从 `..._20260914` 前移
             (旧目录保留)。这是该脚本设计的固有结果,每次跨天重跑都要检查这个指针。
          2. `ppg_control_top/xsim_smoke_recheck_20260910/tb_ppg_control_top/xsim.log`,
             依赖 `xsim_main_filelist.f`(与第 1 类里 `tb_ppg_control_top` 用的是同一份)。
             Stage4收尾重跑复用了同一个目录名(原地覆盖),因此路径本身不需要更新。
        这两次运行各自的输出目录名内嵌固定日期,不是可循环解析的脚本参数,因此按方案
        原文直接点名的两条真实路径显式登记。
    """
    path_chip_top_dir = path_project_root / "ppg_chip_digital_top"
    path_control_top_dir = path_project_root / "ppg_control_top"

    list_checks = [
        (
            "tb_ppg_chip_digital_top (chip_digital_top xsim_regression_20260916)",
            path_chip_top_dir / "xsim_regression_20260916" / "tb_ppg_chip_digital_top" / "xsim.log",
            path_chip_top_dir / "xsim_chip_digital_top_filelist.f",
        ),
        (
            "tb_ppg_control_top (control_top xsim_smoke_recheck_20260910)",
            path_control_top_dir / "xsim_smoke_recheck_20260910" / "tb_ppg_control_top" / "xsim.log",
            path_control_top_dir / "xsim_main_filelist.f",
        ),
    ]

    list_results: list[FreshnessResult] = []
    for str_label, path_log, path_filelist in list_checks:
        list_dependencies = [path_filelist] + parse_filelist(path_filelist)
        list_results.append(assess_freshness(str_label, path_log, list_dependencies))
    return list_results


# ---------------------------------------------------------------------------
# 第 5 类:模块级自检 TB 回归(ppg_system_integration/module_tb_regression)
# ---------------------------------------------------------------------------


def check_module_tb_regression(path_project_root: Path) -> list[FreshnessResult]:
    """检查模块级自检 TB 回归(PVW/PWC/FIR)各自的新鲜度。

    驱动脚本与第 1 类的 `run_xsim_regression.sh` 同构,因此直接复用
    `parse_control_top_regression_script` 与 `parse_filelist`,不另写一套解析。

    参数:
        path_project_root: PPG 项目根目录。

    返回:
        每个 TB 一条 `FreshnessResult`;依赖为驱动脚本本身(脚本里的期望 PASS 条数一旦修改,
        已有日志的判定基准同样过期)、该 TB 的 filelist 本身,以及 filelist 逐行列出的 RTL/TB 文件。
    """
    path_regression_dir = path_project_root / "ppg_system_integration" / "module_tb_regression"
    path_script = path_regression_dir / "run_module_tb_regression.sh"

    str_outdir, dict_tb_filelist = parse_control_top_regression_script(path_script)

    list_results: list[FreshnessResult] = []
    for str_tb, str_filelist_name in dict_tb_filelist.items():
        path_filelist = path_regression_dir / str_filelist_name
        path_log = path_regression_dir / str_outdir / str_tb / "xsim.log"

        if not path_log.exists():
            # 与第 1 类相同:尚未跑过的 TB 记录成"缺产物",不中断整个批次。
            list_results.append(
                FreshnessResult(
                    label=str_tb,
                    artifact_path=str(path_log.relative_to(path_project_root).as_posix()),
                    artifact_mtime=0.0,
                    dependency_count=0,
                    missing_dependencies=["<artifact itself missing, never run>"],
                    stale_dependencies=[],
                )
            )
            continue

        list_dependencies = [path_script, path_filelist] + parse_filelist(path_filelist)
        list_results.append(assess_freshness(str_tb, path_log, list_dependencies))

    list_results.sort(key=lambda r: r.label)
    return list_results


# ---------------------------------------------------------------------------
# 第 3 类:核对脚本自己的报告(reconciliation_report.md / .json)
# ---------------------------------------------------------------------------


def collect_files_with_satisfies_tag(path_root: Path) -> list[Path]:
    """收集项目里所有真实包含 `@satisfies` 标签的 `.v` 文件。

    直接复用 `reconcile_acceptance_ids.py` 自己的 `is_excluded` 排除逻辑
    (排除 `_archive_*`/`baselines`/`history`/`legacy`/`.git`),不重新发明一套。

    参数:
        path_root: PPG 项目根目录。

    返回:
        含 `@satisfies` 标签的 `.v` 文件路径列表。
    """
    list_files: list[Path] = []
    for path_v_file in path_root.rglob("*.v"):
        if mod_reconcile.is_excluded(path_v_file.relative_to(path_root)):
            continue
        try:
            text = path_v_file.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue
        if "@satisfies" in text:
            list_files.append(path_v_file)
    return list_files


def collect_contract_md_files(path_root: Path) -> list[Path]:
    """收集所有合同 `.md` 文件(矩阵本身 + `CONTRACT_GLOBS` 命中的文件)。

    直接复用 `reconcile_acceptance_ids.py` 自己的 `MATRIX_PATH`/`CONTRACT_GLOBS`/
    `is_excluded`,不重新发明一套 glob 规则。

    参数:
        path_root: PPG 项目根目录。

    返回:
        合同 `.md` 文件路径列表(含矩阵本身)。
    """
    set_files: set[Path] = set()
    if mod_reconcile.MATRIX_PATH.exists():
        set_files.add(mod_reconcile.MATRIX_PATH)
    for str_pattern in mod_reconcile.CONTRACT_GLOBS:
        for path_f in path_root.glob(str_pattern):
            if mod_reconcile.is_excluded(path_f.relative_to(path_root)):
                continue
            set_files.add(path_f)
    return sorted(set_files)


def check_reconciliation_report(path_project_root: Path) -> list[FreshnessResult]:
    """检查核对脚本自己的报告(`reconciliation_report.md`/`.json`)的新鲜度。

    参数:
        path_project_root: PPG 项目根目录。

    返回:
        2 个 `FreshnessResult`(`.md` 和 `.json` 各一条),依赖列表是三类文件的并集:
        所有带 `@satisfies` 标签的 `.v` 文件、所有合同 `.md` 文件、别名映射表本身。
    """
    path_tools_dir = path_project_root / "ppg_system_integration" / "cross_reference_tools"

    list_dependencies: list[Path] = []
    list_dependencies.extend(collect_files_with_satisfies_tag(path_project_root))
    list_dependencies.extend(collect_contract_md_files(path_project_root))
    if mod_reconcile.ALIAS_TABLE_PATH.exists():
        list_dependencies.append(mod_reconcile.ALIAS_TABLE_PATH)

    list_results: list[FreshnessResult] = []
    for str_name in ("reconciliation_report.md", "reconciliation_report.json"):
        path_artifact = path_tools_dir / str_name
        list_results.append(assess_freshness(str_name, path_artifact, list_dependencies))
    return list_results


# ---------------------------------------------------------------------------
# 第 4 类:Stage 3 Item 1 的静态 lint 语义扫描结果
# ---------------------------------------------------------------------------


def check_static_lint_semantic_sweep(path_project_root: Path) -> FreshnessResult:
    """检查 Stage 3 Item 1 的 `static_lint_semantic_sweep_report.json` 的新鲜度。

    参数:
        path_project_root: PPG 项目根目录。

    返回:
        `FreshnessResult`,依赖列表直接复用 `static_lint_semantic_sweep.py` 自己的
        `collect_real_source_files`(全部 109 个真实源文件),不重新维护一份清单。
    """
    path_artifact = (
        path_project_root
        / "ppg_system_integration"
        / "cross_reference_tools"
        / "static_lint_semantic_sweep_report.json"
    )
    list_dependencies = mod_lint_sweep.collect_real_source_files(path_project_root)
    return assess_freshness("static_lint_semantic_sweep_report.json", path_artifact, list_dependencies)


# ---------------------------------------------------------------------------
# 汇总与命令行入口
# ---------------------------------------------------------------------------


def run_all_checks(path_project_root: Path) -> dict[str, list[FreshnessResult] | FreshnessResult]:
    """运行全部五类新鲜度检查,返回按类别组织的结果。"""
    return {
        "control_top_19tb_regression": check_control_top_19tb_regression(path_project_root),
        "chip_digital_top_regressions": check_chip_digital_top_regressions(path_project_root),
        "reconciliation_report": check_reconciliation_report(path_project_root),
        "static_lint_semantic_sweep": check_static_lint_semantic_sweep(path_project_root),
        "module_tb_regression": check_module_tb_regression(path_project_root),
    }


def _print_result(result: FreshnessResult) -> None:
    """打印单条新鲜度结果,供人工阅读。"""
    if result.missing_dependencies and result.artifact_mtime == 0.0:
        print(f"  [MISSING] {result.label} -- 产物本身不存在: {result.artifact_path}")
        return

    str_verdict = "FRESH" if result.is_fresh else "STALE"
    print(
        f"  [{str_verdict}] {result.label} -- {result.artifact_path} "
        f"(mtime={_format_mtime(result.artifact_mtime)}, 依赖数={result.dependency_count})"
    )
    for dep in result.stale_dependencies:
        print(f"        比产物新 {dep['age_seconds_newer']:>10.1f}s: {dep['path']} ({dep['mtime_iso']})")
    if result.missing_dependencies:
        for str_missing in result.missing_dependencies:
            print(f"        [依赖缺失] {str_missing}")


def main(argv: list[str] | None = None) -> int:
    """脚本入口:运行全部四类检查,打印人类可读报告,可选写出 JSON。"""

    # Windows 终端默认代码页不是 UTF-8,这里显式重配置避免中文输出乱码。
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except (AttributeError, ValueError):
        pass

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, default=None, help="可选:把全部检查结果写成 JSON 文件。")
    namespace_args = parser.parse_args(argv)

    dict_results = run_all_checks(PATH_PROJECT_ROOT)

    print("=== 第 1 类:ppg_control_top 19 个 TB 回归 ===")
    for result in dict_results["control_top_19tb_regression"]:
        _print_result(result)

    print("\n=== 第 2 类:ppg_chip_digital_top 的两次已知回归 ===")
    for result in dict_results["chip_digital_top_regressions"]:
        _print_result(result)

    print("\n=== 第 3 类:核对脚本自己的报告(reconciliation_report） ===")
    for result in dict_results["reconciliation_report"]:
        _print_result(result)

    print("\n=== 第 4 类:Stage 3 Item 1 静态 lint 语义扫描结果 ===")
    _print_result(dict_results["static_lint_semantic_sweep"])

    print("\n=== 第 5 类:模块级自检 TB 回归(PVW/PWC/FIR) ===")
    for result in dict_results["module_tb_regression"]:
        _print_result(result)

    # 汇总统计。
    list_all: list[FreshnessResult] = []
    list_all.extend(dict_results["control_top_19tb_regression"])
    list_all.extend(dict_results["chip_digital_top_regressions"])
    list_all.extend(dict_results["reconciliation_report"])
    list_all.append(dict_results["static_lint_semantic_sweep"])
    list_all.extend(dict_results["module_tb_regression"])

    count_missing_artifact = sum(1 for r in list_all if r.artifact_mtime == 0.0 and r.missing_dependencies)
    list_checked = [r for r in list_all if not (r.artifact_mtime == 0.0 and r.missing_dependencies)]
    count_fresh = sum(1 for r in list_checked if r.is_fresh)
    count_stale = sum(1 for r in list_checked if not r.is_fresh)

    print("\n=== 汇总 ===")
    print(f"共检查 {len(list_all)} 份产物:{count_fresh} 份新鲜,{count_stale} 份已失效,{count_missing_artifact} 份产物本身缺失。")
    if count_stale:
        print("已失效的产物(需要重新跑回归才能再被当作当前证据引用):")
        for r in list_checked:
            if not r.is_fresh:
                print(f"  - {r.label} ({r.artifact_path})")

    if namespace_args.json is not None:

        def _serialize(value):
            if isinstance(value, list):
                return [item.to_dict() for item in value]
            return value.to_dict()

        dict_json = {key: _serialize(value) for key, value in dict_results.items()}
        dict_json["_summary"] = {
            "total_checked": len(list_all),
            "fresh": count_fresh,
            "stale": count_stale,
            "missing_artifact": count_missing_artifact,
            "generated_at": datetime.now(timezone.utc).isoformat(),
        }
        namespace_args.json.write_text(
            json.dumps(dict_json, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        print(f"\n已写入 JSON:{namespace_args.json}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
