### 调度器单元TB：合同FSC-nn ↔ TB本地SCHT-n（TB标签改名后生效，BMI-133/140）

> 调度器单元TB原以`check_fsc(n, …)`打印`FSC-n`，n只是TB内场景序号，与C08同号条目含义不同（ID治理§6.1）。改名后打印`SCHT-n`，`check_fsc`实参不变（交接书Q3）。下表按合同条目列出真正检查其含义的TB检查。TB SCHT-14＝合同FSC-03（F-011已收紧为严格5000），TB SCHT-32＝合同FSC-30。TB SCHT-58/59语义属FSC-17，SCHT-60/61/62语义属FSC-50（V1.12补充），按用户决定不在C08登记FSC-58~62。

| 验收ID | 对应TB场景名 | 对应RTL标签位置 | 出处 |
| --- | --- | --- | --- |
| FSC-01 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-1（部分：复位后无在途、frame/sample为0、无协议sticky；缺完成事件与其他sticky清零） | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-01行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-02 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-6 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-02行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-03 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-14；另有TB本地FRAME-NN/FRAME-NC/FRAME-CN/FRAME-NC-LAST | `ppg_400hz_frame_calibration_scheduler.v` `flag_frame_restart`、`@satisfies: FSC-03` | C08 §18 FSC-03行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-04 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-5、SCHT-9、SCHT-50 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-04行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-05 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-10、SCHT-11、SCHT-51 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-05行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-06 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-16、SCHT-17 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-06行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-07 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-18 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-07行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-08 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-19 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-08行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-09 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-5、SCHT-9、SCHT-56 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-09行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-10 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-20、SCHT-21 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-10行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-11 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-20 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-11行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-12 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-22 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-12行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-13 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-23、SCHT-24 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-13行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-14 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-26 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-14行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-15 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-27 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-15行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-16 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-25 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-16行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-17 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-49、SCHT-58、SCHT-59；另有TB本地L1-NOREPEND | `ppg_400hz_frame_calibration_scheduler.v` `@satisfies: FSC-17` | C08 §18 FSC-17行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-18 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：部分 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-18行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-19 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；另有TB本地L3-IDLEBND；系统级证据：无 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-19行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-20 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：已有 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-20行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-21 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：已有 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-21行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-22 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-15 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-22行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-23 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：无 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-23行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-24 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：无 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-24行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-25 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-41 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-25行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-26 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-55 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-26行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-27 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：无 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-27行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-28 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-7、SCHT-40 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-28行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-29 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-28 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-29行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-30 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-32 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-30行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-31 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-35、SCHT-36；另有TB本地CAL-ROLLOVER-STOP | `ppg_400hz_frame_calibration_scheduler.v` `flag_calibration_rollover`、`@satisfies: FSC-31, FSC-32` | C08 §18 FSC-31行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-32 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-37、SCHT-53；另有TB本地CAL-ROLLOVER-ABORT | `ppg_400hz_frame_calibration_scheduler.v` `flag_calibration_rollover`、`@satisfies: FSC-31, FSC-32` | C08 §18 FSC-32行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-33 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-45 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-33行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-34 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：部分 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-34行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-35 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：部分 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-35行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-36 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-42 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-36行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-37 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-29 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-37行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-38 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-13、SCHT-52；另有TB本地L3-NOEXTRA | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-38行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-39 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-48 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-39行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-40 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-13 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-40行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-41 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-38、SCHT-44、SCHT-54 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-41行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-42 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-25 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-42行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-43 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：已有 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-43行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-44 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：无 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-44行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-45 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-24 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-45行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-46 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-6、SCHT-29；另有TB本地L4-EXPIRE/L4-ONTIME | `ppg_400hz_frame_calibration_scheduler.v` `flag_candidate_expired`、`@satisfies: FSC-46, FSC-49, FSC-50` | C08 §18 FSC-46行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-47 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：已有 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-47行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-48 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：部分 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-48行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-49 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-30；另有TB本地L4-EXPIRE | `ppg_400hz_frame_calibration_scheduler.v` `flag_candidate_expired`、`@satisfies: FSC-46, FSC-49, FSC-50` | C08 §18 FSC-49行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-50 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-31、SCHT-60、SCHT-61、SCHT-62 | `ppg_400hz_frame_calibration_scheduler.v` `flag_candidate_expired`、`@satisfies: FSC-46, FSC-49, FSC-50` | C08 §18 FSC-50行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-51 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-42 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-51行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-52 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-10、SCHT-41、SCHT-49 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-52行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-53 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：部分 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-53行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-54 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-33、SCHT-34；另有TB本地LOST-REL/LOST-MISM | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-54行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-55 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-2、SCHT-3 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-55行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-56 | `tb_ppg_400hz_frame_calibration_scheduler.v` SCHT-38、SCHT-39、SCHT-47 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-56行；ID治理§5.2；B合并批次7a8eabf重扫 |
| FSC-57 | `tb_ppg_400hz_frame_calibration_scheduler.v` 无（单元TB无同义检查）；系统级证据：部分 | 无映射（RTL无该ID的`@satisfies`标签） | C08 §18 FSC-57行；ID治理§5.2；B合并批次7a8eabf重扫 |

### 其余随改名生效的映射（BMI-141~144、103）

| 验收ID | 对应TB场景名 | 对应RTL标签位置 | 出处 |
| --- | --- | --- | --- |
| SUP-03 | 无（原子标签SUP03A测的是episode开启期间诊断清除无效，改名为TB本地CLRBLK，属SUP-07前半） | 无映射 | C24 §7；ID治理§6.2 |
| SUP-06 | `tb_ppg_system_fault_abort_supervisor.v` SUP06B、SUP06C（看门狗边界）；WDIDLE（原SUP09A：阈值前idle不超时） | `ppg_system_fault_abort_supervisor.v` `@satisfies: P05` | C24 §6；ID治理§6.2 |
| SUP-07 | `tb_ppg_system_fault_abort_supervisor.v` SUP07A；CLRBLK（原SUP03A）；EPICLS（原SUP06A：episode关闭后阻断解除） | 无映射 | C24 §5、§7 |
| SUP-09 | 无（原SUP09A改名为WDIDLE，属SUP-06） | 无映射 | C24 §7；ID治理§6.2 |
| SUP-10 | 无（该条归C10 AMI-53；原SUP10A测第二个独立episode完整trio，改名为TB本地EPI2ND） | 无映射 | C24 §7（V1.6注明归属）；ID治理§6.2 |
| （TB本地）EPI2ND、RE-ARM | `tb_ppg_system_fault_abort_supervisor.v` 同名 | 无映射 | C24 §4（episode重开） |
| DCR-04 | `tb_ppg_adc_dc_recovery.v` DCRT-3向量（9-bit且DC码0时DC项为0） | 无映射 | C15 DCR-04行；ID治理§6.3 |
| DCR-07、DCR-11 | `tb_ppg_adc_dc_recovery.v` DCRT-4向量（15-bit双结果+K_DC15） | 无映射 | C15；ID治理§6.3 |
| DCR-12 | `tb_ppg_adc_dc_recovery.v` DCRT-5向量与"FAIL DCR-12 qualification"检查 | 无映射 | C15；ID治理§6.3 |
| DCR-09 | `tb_ppg_adc_dc_recovery.v` DCRT-6、DCRT-7向量与"FAIL DCR-09 saturation endpoints"检查 | 无映射 | C15；ID治理§6.3 |
| DCR-03、DCR-06 | 无（证据缺口） | 无映射 | ID治理§10 |
| SSW-18 | `tb_ppg_sar9_sar15_safe_selection_wrapper.v` S1-LATE、S1-ONTM（原SSW-18场景测校准owner截止，已改名为TB本地CAL-ODL） | `ppg_sar9_sar15_safe_selection_wrapper.v` `calibration_timeout_sticky_o`（`@satisfies`在阶段4补） | C09 §5.4、§7.8、SSW-18行（V1.11改写） |
| （TB本地）CAL-ODL | `tb_ppg_sar9_sar15_safe_selection_wrapper.v` CAL-ODL | 无映射 | C09 §4.5、SSW-37/SSW-38 |
| AMI-13 | 无（单元TB原同号检查测的是反压保持，已改名为TB本地FORK-HOLD，属AMI-12） | `ppg_adc_measurement_idac_integration.v` `flag_result_fork_all_released`（RTL结构，无动态证据） | C10 §17 AMI-13行（V2.5注明） |
| （TB本地）FORK-HOLD | `tb_ppg_adc_measurement_idac_integration.v` FORK-HOLD | 无映射 | C10 §17 AMI-12 |
| LFA-11 | `tb_ppg_control_top_lifecycle_fault_adc_anomaly.v` LFA-11b（后半句）；前半句无断言 | 无映射 | C25 LFA-11行；ID治理§6.5 |
| （TB本地）AUTOABT-QUIET | `tb_ppg_control_top_lifecycle_fault_adc_anomaly.v` AUTOABT-QUIET（原LFA-11a；informational分支仍打印PASS，按交接书Q6只登记） | 无映射 | 矩阵P03行；ID治理§6.5 |
