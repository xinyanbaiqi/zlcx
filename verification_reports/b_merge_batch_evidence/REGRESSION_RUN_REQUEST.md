# 回归运行说明：基线与终版都在"回归机"上跑（用户2026-10-09决定）

## 0. 决定与理由

- **用户决定（2026-10-09）**：本批次的基线回归和终版回归，整套都改在另一台性能更好的电脑（下称"回归机"）上跑。
- **原因**：本机（i7-10510U笔记本，Vivado 2019.2）的情况如下。
  - 跑得慢：最长的TB单个约3小时。
  - 关闭Claude时，后台仿真会被一并结束。
  - `tb_ppg_coarse_detection_fir`在2019.2下xelab确定性崩溃。
- **本机已有结果只作参考**，不作为正式证据：`baseline_7a8eabf_vivado2019.2_partial/`。
- **交接书§6.8的要求**：基线和终版必须在同一台机器、同一Vivado版本上跑。所以两次都在回归机上跑，分组方式也保持一致。
- **Vivado版本**：回归机须用**Vivado 2022.2**，与统筹参考值同版本。如果回归机上没有2022.2，先不要跑，告诉用户。

## 1. 基线回归（现在跑）

在Windows + Git Bash下执行。如果回归机是Linux，按交接书§6.8把`.bat`改成本地可执行文件，只改本地运行副本。

### 1.1 导出

对每个运行组，从基线`7a8eabf`导出一个独立目录，都放在仓库外的同一个根目录下：

```bash
git clone https://github.com/xinyanbaiqi/zlcx && cd zlcx
R=../runs_7a8eabf
for d in sys_g1 sys_g2 sys_g3 sys_g4 chip unit; do mkdir -p $R/$d && git -c core.autocrlf=false archive 7a8eabf | tar -x -C $R/$d; done
```

不要在工作区里直接跑：autocrlf会改写文件字节，`.sh`带CRLF在bash下会出错。

### 1.2 分组

在每个`sys_gN/rtl/ppg_control_top/run_xsim_regression.sh`中，只改`ORDER=( ... )`数组，其余内容不动。分组与本机一致：

- g1：`tb_ppg_control_top_longrun`、`tb_diag_algo_probe`、`tb_ppg_real_raw_generator_selfcheck`、`tb_ppg_control_top`、`tb_ppg_control_top_baseline_cross`
- g2：`tb_ppg_control_top_long_10_cycles`、`tb_ppg_control_top_fir_tail_isolation`、`tb_ppg_control_top_adc_numeric_scoreboard`、`tb_ppg_control_top_idac_bus_isolation`、`tb_ppg_control_top_injection`
- g3：`tb_ppg_control_top_lifecycle_fault_adc_anomaly`、`tb_ppg_control_top_input_light_static_matrix`、`tb_ppg_control_top_normal_slow_tracking`、`tb_ppg_control_top_no_recheck_control`、`tb_ppg_control_top_owner_identity_backpressure`
- g4：`tb_ppg_control_top_peak_valley_return`、`tb_ppg_control_top_periodic_recheck_recovery`、`tb_ppg_control_top_robustness_corner_waveforms`、`tb_ppg_control_top_startup_idac_calibration`、`tb_ppg_control_top_adc_anomaly`

改完后核对：4组合起来恰好是脚本`TB_FILELIST`中的20个TB，不重复、不遗漏。

### 1.3 运行

```bash
export VIVADO_BIN=/c/Xilinx/Vivado/2022.2/bin      # 按实际路径改
R=$(cd ../runs_7a8eabf && pwd)
for g in 1 2 3 4; do (bash $R/sys_g$g/rtl/ppg_control_top/run_xsim_regression.sh > $R/sys_g$g.out 2>&1 &); done
(bash $R/chip/rtl/ppg_chip_digital_top/run_xsim_regression.sh > $R/chip.out 2>&1 &)
(bash $R/unit/tools/run_unit_tb_regression.sh -o $R/unit_runs -g all > $R/unit.out 2>&1; echo "UNIT_EXIT=$?" >> $R/unit.out) &
```

- 运行期间不要关闭启动仿真的程序，不要让电脑睡眠。
- 如果是在Claude会话里启动的，关闭Claude会结束这些仿真。
- 回归机核数较少时，可以先跑4组系统TB，再跑芯片和模块级。分组本身不要改。

### 1.4 核对与证据

跑完后在仓库里执行：

```bash
python tools/b_merge_tools/regression_evidence.py export $R verification_reports/b_merge_batch_evidence/baseline_7a8eabf
```

- 合格判据（参考值来自统筹机器，Vivado 2022.2）：
  - 系统TB 20/20，每份xvlog、xelab、xsim返回0，0 FAIL，`$finish`恰好1次；
  - PASS共1250行（`index.tsv`中system各行`pass_lines`之和）；
  - 芯片20/0；
  - 模块级28/28。
- 对不上时**停下报告**，先查环境。不得为迁就版本改RTL/TB。

### 1.5 回传

提交到`b-merge-batch`分支，放在`verification_reports/b_merge_batch_evidence/baseline_7a8eabf/`下：

- `export`的输出：`index.tsv`和`system/`、`chip/`、`unit/`三个目录；
- `raw/`：各`summary.tsv`、`unit_summary.tsv`、每个TB的`xsim.log`（本机全套约0.7 MB），按`raw/<组>/<tb>/xsim.log`放；
- `MACHINE.txt`：CPU、操作系统、Vivado版本（`xelab -version`的第一行）、开始和结束时间、分组。

提交前先`git pull`，只`git add`这个目录。

## 2. 终版回归（批次最后，阶段6）

- 在回归机上，用同一Vivado、同一分组，对`b-merge-batch`的最终提交重复1.1~1.4：把`7a8eabf`换成最终提交号，证据目录名换成`final_<提交号前7位>`。
- 比对命令：
  ```bash
  python tools/b_merge_tools/regression_evidence.py compare verification_reports/b_merge_batch_evidence/baseline_7a8eabf verification_reports/b_merge_batch_evidence/final_<提交号>
  ```
- 预期结果：`$finish`全部相同（退出码0）。PASS行只允许出现TB标签改名造成的差异，脚本会逐行列出。
- **锚点门禁演示（交接书§3.2“接入回归门禁”，BMI-153）**：模块级回归入口`tools/run_unit_tb_regression.sh`开头会先运行`tools/b_merge_tools/run_anchor_gate.sh`。门禁失败时整轮以退出码1结束，不跑任何仿真。终版回归时需要演示两次：
  1. 通过：正常运行模块级回归（即上面1.3的unit一路），`unit.out`开头应出现`ANCHOR GATE PASSED`。
  2. 负对照：在导出目录（不是仓库）里注入一处坏锚点后单跑一个TB，应报`name-missing`和`ANCHOR GATE FAILED`，退出码1，且不生成输出目录：
     ```bash
     cd $R/unit
     sed -i '0,/`ppg_amb_recheck_scheduler.v` `i_amb_enable`/s//`ppg_amb_recheck_scheduler.v` `i_amb_enablX`/' contracts/PPG_CONTRACT_CLOSURE_MATRIX.md
     bash tools/run_unit_tb_regression.sh -o $R/gate_negctl tb_ppg_adc_dc_recovery > $R/gate_negctl.out 2>&1; echo "EXIT=$?" >> $R/gate_negctl.out
     ```
     这一步放在全部回归跑完之后做，做完后该导出目录作废。把`gate_negctl.out`与`unit.out`开头的门禁几行一起放进`final_<提交号>/`。
  - 门禁需要Python 3（>=3.9时用formatter AST；更低版本自动退回文本检索，判据相同）。
