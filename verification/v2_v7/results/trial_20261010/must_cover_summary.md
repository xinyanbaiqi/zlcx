# 必须覆盖场景（提交acc88f8）

points: 25; verdicts: EXC-C 1, EXC-F1 1, NEW 5, PASS 18
landing: MISMATCH 1, OK 24
per-point wall time: mean 35.5 s, max 356 s

| mode | event | EXC-C | EXC-F1 | NEW | PASS |
|---|---|---:|---:|---:|---:|
| DUAL9 | FOREVER | 0 | 0 | 0 | 1 |
| DUAL9 | LATE | 0 | 0 | 4 | 1 |
| DUAL9 | START_DELAY | 0 | 0 | 0 | 9 |
| GEN_DUAL | PREC_IR_LOST | 0 | 1 | 0 | 0 |
| RECHECK | RECHECK_CAL_BUSY | 0 | 0 | 1 | 0 |
| RED15 | LOST | 0 | 0 | 0 | 1 |
| SEARCH | LATE | 1 | 0 | 0 | 0 |
| SEARCH | POSTBUSY | 0 | 0 | 0 | 2 |
| SEARCH | START_DELAY | 0 | 0 | 0 | 4 |

## Points not PASS

| point | target | landed | landing | verdict | why | causes | sigs |
|---|---|---|---|---|---|---|---|
| MC1_F1_GEN_DUAL_IR_LOST | f423/t330 | f423/t460/sf0lt460 | OK | EXC-F1 | cause04 + void at tick>=4760 | 04/04 | - |
| MC2_RECHECK_CAL_LOST_BUSY | f616/t2000 | f618/t2000/sf3lt125 | OK | NEW | LIVENESS,V7:P7_BOUNDED_LIVENESS | -/- | - |
| MC4_EXCC_SEARCH_LATE_CAL | f0/t100 | f1/t0/sf0lt0 | MISMATCH | EXC-C | conditioned exception C gap | -/- | - |
| MC9_LATE_AT_VOID_t4499 | f3/t4499 | f3/t4499/sf7lt124 | OK | NEW | system causes 02 | 02/02 | - |
| MC9_LATE_AT_VOID_t4500 | f3/t4500 | f3/t4500/sf7lt125 | OK | NEW | system causes 02 | 02/02 | - |
| MC9_LATE_AT_VOID_t4501 | f3/t4501 | f3/t4501/sf7lt126 | OK | NEW | system causes 02 | 02/02 | - |
| MC9_LATE_AT_VOID_t4502 | f3/t4502 | f3/t4502/sf7lt127 | OK | NEW | system causes 02 | 02/02 | - |

## Landing mismatches

| point | target | landed | rule |
|---|---|---|---|
| MC4_EXCC_SEARCH_LATE_CAL | f0/t100 | f1/t0/sf0lt0 | exact |
