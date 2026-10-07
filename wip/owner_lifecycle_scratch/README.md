# owner生命周期轮 云端第三步用的本机材料（仅供分支 wip/owner-lifecycle 使用，合并main前删除或归档）

来源与用途见 `verification_reports/OWNER_LIFECYCLE_STEP2_HANDOFF.md` 第(e)节。

- `b_temp_tb/`：B会话的临时TB（基于517ab78版TB生成），用作永久系统TB `tb_ppg_control_top_adc_anomaly.v` 的起点。
- `workflow_scripts/`：ABCD会话的工作流脚本，内含Windows绝对路径，云端需改。
- `olr_patch_scripts/`：本轮RTL补丁脚本，仅供审阅改动。
- `baseline_05a31cf/`：05a31cf回归每个TB排序后的PASS行与`$finish`行，用于第三步回归比对。
