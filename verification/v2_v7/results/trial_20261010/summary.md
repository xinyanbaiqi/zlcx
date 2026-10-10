# V2试跑（缩小网格，提交627f065，当前RTL）

points: 469; verdicts: EXC-C 15, EXC-F1 1, KNOWN-FIX-7 4, NEW 5, PASS 444
landing: INFO 73, MISMATCH 3, OK 393
per-point wall time: mean 18.1 s, max 793 s

| mode | event | EXC-C | EXC-F1 | KNOWN-FIX-7 | NEW | PASS |
|---|---|---:|---:|---:|---:|---:|
| DUAL9 | ABORT | 0 | 0 | 1 | 0 | 36 |
| DUAL9 | FOREVER | 0 | 0 | 0 | 0 | 1 |
| DUAL9 | LATE | 0 | 0 | 0 | 4 | 75 |
| DUAL9 | LOST | 0 | 0 | 0 | 0 | 37 |
| DUAL9 | START_DELAY | 0 | 0 | 0 | 0 | 9 |
| DUAL9 | STOP | 0 | 0 | 1 | 0 | 36 |
| GEN_DUAL | PREC_IR_LOST | 0 | 1 | 0 | 0 | 0 |
| RECHECK | RECHECK_CAL_BUSY | 0 | 0 | 0 | 1 | 0 |
| RED15 | ABORT | 0 | 0 | 1 | 0 | 36 |
| RED15 | LATE | 0 | 0 | 0 | 0 | 37 |
| RED15 | LOST | 0 | 0 | 0 | 0 | 38 |
| RED15 | STOP | 0 | 0 | 1 | 0 | 36 |
| SEARCH | BUSY | 0 | 0 | 0 | 0 | 1 |
| SEARCH | LATE | 1 | 0 | 0 | 0 | 0 |
| SEARCH | LOST | 14 | 0 | 0 | 0 | 42 |
| SEARCH | START_DELAY | 0 | 0 | 0 | 0 | 4 |
| SEARCH | STOP | 0 | 0 | 0 | 0 | 56 |

## Points not PASS

| point | target | landed | landing | verdict | why | causes | sigs |
|---|---|---|---|---|---|---|---|
| DUAL9_ABORT_ANY_t4999 | f3/t4999 | f3/t4999/sf7lt624 | OK | KNOWN-FIX-7 | normal frame complete after STOP/abort/fault | -/- | KNOWN-FIX-7 |
| DUAL9_STOP_ANY_t4999 | f3/t4999 | f3/t4999/sf7lt624 | OK | KNOWN-FIX-7 | normal frame complete after STOP/abort/fault | -/- | KNOWN-FIX-7 |
| MC1_F1_GEN_DUAL_IR_LOST | f423/t330 | f423/t460/sf0lt460 | OK | EXC-F1 | cause04 + void at tick>=4760 | 04/04 | - |
| MC2_RECHECK_CAL_LOST_BUSY | f616/t2000 | f618/t2000/sf3lt125 | OK | NEW | LIVENESS,V7:P7_BOUNDED_LIVENESS | -/- | - |
| MC4_EXCC_SEARCH_LATE_CAL | f0/t100 | f1/t0/sf0lt0 | MISMATCH | EXC-C | conditioned exception C gap | -/- | - |
| MC9_LATE_AT_VOID_t4499 | f3/t4499 | f3/t4499/sf7lt124 | OK | NEW | system causes 02 | 02/02 | - |
| MC9_LATE_AT_VOID_t4500 | f3/t4500 | f3/t4500/sf7lt125 | OK | NEW | system causes 02 | 02/02 | - |
| MC9_LATE_AT_VOID_t4501 | f3/t4501 | f3/t4501/sf7lt126 | OK | NEW | system causes 02 | 02/02 | - |
| MC9_LATE_AT_VOID_t4502 | f3/t4502 | f3/t4502/sf7lt127 | OK | NEW | system causes 02 | 02/02 | - |
| RED15_ABORT_ANY_t4999 | f3/t4999 | f3/t4999/sf7lt624 | OK | KNOWN-FIX-7 | normal frame complete after STOP/abort/fault | -/- | KNOWN-FIX-7 |
| RED15_STOP_ANY_t4999 | f3/t4999 | f3/t4999/sf7lt624 | OK | KNOWN-FIX-7 | normal frame complete after STOP/abort/fault | -/- | KNOWN-FIX-7 |
| SEARCH_LOST_sf0_lt385 | f0/t385/sf0lt385 | f0/t891/sf1lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf1_lt0 | f0/t625/sf1lt0 | f0/t891/sf1lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf1_lt1 | f0/t626/sf1lt1 | f0/t891/sf1lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf1_lt2 | f0/t627/sf1lt2 | f0/t891/sf1lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf1_lt248 | f0/t873/sf1lt248 | f0/t891/sf1lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf1_lt249 | f0/t874/sf1lt249 | f0/t891/sf1lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf1_lt250 | f0/t875/sf1lt250 | f0/t891/sf1lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf1_lt385 | f0/t1010/sf1lt385 | f0/t1516/sf2lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf2_lt0 | f0/t1250/sf2lt0 | f0/t1516/sf2lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf2_lt1 | f0/t1251/sf2lt1 | f0/t1516/sf2lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf2_lt2 | f0/t1252/sf2lt2 | f0/t1516/sf2lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf2_lt248 | f0/t1498/sf2lt248 | f0/t1516/sf2lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf2_lt249 | f0/t1499/sf2lt249 | f0/t1516/sf2lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |
| SEARCH_LOST_sf2_lt250 | f0/t1500/sf2lt250 | f0/t1516/sf2lt266 | OK | EXC-C | conditioned exception C gap | -/- | - |

## Landing mismatches

| point | target | landed | rule |
|---|---|---|---|
| MC4_EXCC_SEARCH_LATE_CAL | f0/t100 | f1/t0/sf0lt0 | exact |
| SEARCH_STOP_sf0_lt0 | f0/t0/sf0lt0 | f0/t0/sf0lt0 | exact |
| SEARCH_STOP_sf0_lt1 | f0/t1/sf0lt1 | f0/t0/sf0lt0 | exact |
