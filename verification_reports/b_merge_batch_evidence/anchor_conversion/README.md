# 阶段4锚点人工判定与旧→新对照表（2026-10-09）

**状态：对照表已完成，尚未写入矩阵和别名表。** 按用户10-09指示，阶段3（TB标签改名＋别名表映射行）
完成并经回归机基线核对之后，才把本表写入 `contracts/PPG_CONTRACT_CLOSURE_MATRIX.md` 和
`contracts/PPG_ALIAS_MAPPING_TABLE.md`。

## 文件

| 文件 | 内容 |
|---|---|
| `anchor_mapping_table.tsv` | 全部9702个旧锚点逐条对照：文件、基线行号、该行SHA-1前12位、列位置、旧文本、类别、写入时提交、分类、新文本、来源（auto/manual）、判定理由 |
| `anchor_mapping_summary.md` | 分类计数 |
| `../../../tools/b_merge_tools/anchor_manual_decisions.tsv` | 207条人工判定（解析器给不出唯一答案的锚点），每条写明理由 |

## 复现

```bash
python tools/b_merge_tools/anchor_inventory.py --rev 7a8eabf --out inv.json
python tools/b_merge_tools/anchor_resolve.py --inventory inv.json --base 7a8eabf --out res.json
python tools/b_merge_tools/anchor_manual_seed.py --resolved res.json --out tools/b_merge_tools/anchor_manual_decisions.tsv
python tools/b_merge_tools/anchor_mapping.py --resolved res.json --decisions tools/b_merge_tools/anchor_manual_decisions.tsv --out-dir verification_reports/b_merge_batch_evidence/anchor_conversion
```

清单基线为 `7a8eabf`（批次起点）。新节号核对用的是 `affd3e3`，已包含C08 §8.2.6重编号。
写入矩阵时，按“行SHA-1＋旧文本”定位，不按行号。

## 分类结果

| 分类 | 数量 | 处理 |
|---|---|---|
| convert（auto） | 7612 | 解析器按写入时文件读出的符号/小节/TB标签替换 |
| convert（manual） | 199 | 人工判定后替换（其中3条是人工复核后接受的弱解析） |
| history-dated | 1473 | 同一格内锚点之前有日期的叙述，按历史保留原文；写入时加入 `anchor_history_allowlist.json` |
| history-strike | 410 | 删除线内，按历史保留 |
| history（manual） | 1 | alias P302行“`:312`”是当时deliverable gate报告的错误行号，保留为gate输出原文 |
| not-anchor | 4 | 形似行号但不是锚点：alias 86“`:1024`-bit”、296“`:2026-09`”、486“`:4`个”、562“`:6`段”，保持不动；写入时这4行也须进allowlist |
| external | 3 | alias 172/175/176引用 `PPG_SESSION_HANDOFF_20260826_2.md`，交接文档未随本仓库快照入库，无法读取；保留并在报告中列出 |
| lost（失效锚点（无法追溯）） | 0 | — |

## 人工判定（207条）的依据

本次请求时约有390条待人工判定。解析器改进后（同格日期叙述归为历史、裸 `:N` 按同一子句内的模块词定位、
按格内符号全局查归属、合同小节裸引用）降到207条，逐条判定，动作分布如下：

| 动作 | 数量 | 规则 |
|---|---|---|
| sym | 88 | 格内与锚点同括号的符号为准（brief §3.13 Q1）。符号在HEAD该文件中须存在。典型情形：①“same packed payload unpack (`x_o`, `:949,…`)”→AMI内同名解包线；②“also bypassed to fork (`:19xx`)”→AMI内 `flag_router_*`/`dec_router_*`；③行号写在一个文件名之后，但实际属于另一个文件（如矩阵3189行的 `ppg_idac_code_controller.v:2314`：写入时C17不足2314行，实为AMI的例化连线）→ 按符号归属文件 |
| tag | 43 | 别名表行：被引RTL文件已有本行ID（或格内点名共用的ID）的 `@satisfies` 标签 → `` `file.v` `@satisfies: ID` `` |
| label | 43 | 别名表PVW-01~46行：写入时TB行号已漂移，行ID即 `check_case("PVW-xx", …)` 用例名 → TB标签锚点；alias 305行 `:1099` → TB总判定PASS打印 |
| csec | 11 | 格内写“§x.y (`:N`)”或“合同`:N`”的裸合同行号 → 写入时该合同行所在小节 |
| text | 2 | 矩阵2636行 `:84`：格内写明“§3 (:84, integration module scope)”，但写入时84行已漂进§2，按格内节号和标题取C10 §3；alias 303行 `:3532`：写入时该行是续行，按格内描述（PWC-40映射所在行）取§12.13 Acceptance-D01-01行 |
| file | 9 | 整段端口表/整段实现范围（如 `:58-116`、`:93-395`、`:70-190`）或文件头修订记录行 → 文件级锚点 |
| history / not-anchor / external | 8 | 见上表 |
| keep-auto | 3 | 弱解析（resolved-weak），人工核对后接受 |

## 校验

把全部7811条convert的新文本逐条写成一个临时markdown，用 `tools/b_merge_tools/anchor_check.py` 检查
（Python 3.12，formatter AST开启）：符号锚点5216、`@satisfies` 56、TB标签144、合同小节2582，**0 error**。
另有210条新文本是“Cxx 文件头”（原锚点指向合同第一个编号标题之前的行，绝大多数是 `Cxx:3` 版本行），
这类不经anchor_check校验，人工抽查确认无误。随机抽查14条自动解析结果，均为格内所写符号在写入时
被引行上的真实出现位置。
