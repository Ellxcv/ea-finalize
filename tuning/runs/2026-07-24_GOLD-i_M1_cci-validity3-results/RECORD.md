# CCI Validity 3 Challenger Results — Folders 38–40

## Decision

`PARTIAL PASS — NOT PROMOTED`

Folder 39 dan 40 valid secara provenance/data. Folder 38 tidak valid untuk kesimpulan strategi
karena history quality hanya 16% dan tester berhenti pada incomplete L10 recovery. Validity 3
menunjukkan robustness lebih baik pada window Sep–Jan, tetapi tidak mencapai tujuan meningkatkan
original entry quality pada window Jan–Mei.

## Audit

Audit seluruh run:

| Run | Candidate | Retained | Error | Keputusan |
| --- | ---: | ---: | ---: | --- |
| Folder 38, 2025.05.01–2025.08.31 | 353 | 0 | 2 | Rejected |
| Folder 39, 2025.09.01–2026.01.03 | 504 | 504 | 0 | Accepted |
| Folder 40, 2026.01.04–2026.05.02 | 576 | 576 | 0 | Accepted |

Folder 38 errors:

~~~text
HISTORY_QUALITY_BELOW_MINIMUM: required >=99%, found 16%
TERMINATION_STATUS_REJECTED: MARGIN_CALL
~~~

Valid processed dataset:

| Item | Nilai |
| --- | --- |
| Dataset version | `folder32-cci3-v1-dataset-v001` |
| Retained candidate | 1.080 |
| `merged_candidates.csv` SHA-256 | `BCC8B49ACB13DF1075BC776E4D9B36D0AE59DA172F2760E4D627BC5D75255404` |
| `rule_analysis.csv` SHA-256 | `D555FA8C024BFC7A1233076EF99D051CB0E2A8414A30226BBFB8D27064F19649` |
| Audit errors / warnings | 0 / 2 |

Kedua warning adalah `SYMBOL_MIGRATION_UNVERIFIED`.

## Folder 38 — rejected

| Metric | Nilai |
| --- | ---: |
| History quality | 16% real ticks |
| Candidate coverage | 2025.05.01–2025.08.01 |
| Tester termination | sekitar 2025.08.04 |
| Net profit | -3.849,27 |
| Equity DD maximal | 5.492,22 (98,42%) |
| Candidate | 353 |
| Last cycle | incomplete, L10, -5.428,97 |

Hasil ini tidak membuktikan validity 3 gagal pada market history yang benar. Ia juga tidak boleh
digabungkan dengan folder 39–40.

## Folder 39 — accepted

| Metric | Nilai |
| --- | ---: |
| History quality | 100% real ticks |
| Net profit | 2.843,47 |
| Profit factor | 1,52 |
| Equity DD maximal | 2.220,30 (38,93%) |
| Candidate | 504 |
| `NO_RECOVERY` | 203 (40,28%) |
| `RECOVERY_L1_L3` | 256 (50,79%) |
| `RECOVERY_L4_PLUS` | 45 (8,93%) |
| Original net / win rate | -90,08 / 40,28% |

Validity 5 margin call pada awal window yang sama, sedangkan validity 3 menyelesaikan seluruh
window. Ini adalah bukti robustness yang relevan, tetapi profit masih sepenuhnya bergantung pada
recovery karena original net negatif.

## Folder 40 — accepted and directly comparable

| Metric | Validity 5 folder 35 | Validity 3 folder 40 |
| --- | ---: | ---: |
| Candidate | 982 | 576 |
| Total trades | 2.092 | 1.274 |
| Net profit | 7.020,93 | 4.171,15 |
| Profit factor | 1,63 | 1,57 |
| Original win rate | 57,54% | 55,90% |
| `NO_RECOVERY` rate | 57,94% | 56,08% |
| `RECOVERY_L4_PLUS` rate | 9,16% | 9,72% |
| Equity DD maximal | 2.949,11 (30,98%) | 2.661,96 (44,40%) |

Validity 3 mengurangi candidate sekitar 41%, tetapi:

- original win rate turun 1,64 percentage points;
- no-recovery rate turun 1,86 percentage points;
- L4+ rate naik 0,56 percentage points;
- net profit turun sekitar 40,6%;
- absolute equity DD turun sekitar 9,7%, tetapi relative DD memburuk.

Dari 982 candidate validity 5, hanya 497 candidate yang muncul dengan key waktu/arah sama di
validity 3. Candidate validity 5 yang tidak muncul memiliki original win rate 56,49% dan L4+ rate
8,87%; jadi validity 3 tidak secara khusus membuang kelompok entry yang paling buruk.

## Combined valid validity-3 dataset

| Outcome | Jumlah | Rate |
| --- | ---: | ---: |
| `NO_RECOVERY` | 526 | 48,70% |
| `RECOVERY_L1_L3` | 453 | 41,94% |
| `RECOVERY_L4_PLUS` | 101 | 9,35% |
| Barrier favorable first | 482 | 44,63% |

Original net gabungan folder 39–40 hanya +9,71, sedangkan cycle net mencapai 7.014,62. Recovery
masih menjadi sumber hampir seluruh profit.

## Next action

1. Jangan melatih ulang model atau mempromosikan validity 3 sekarang.
2. Jangan mengulang folder 38 dengan history lokal yang sama; quality akan tetap rendah.
3. Cari/download real-tick `GOLD.i#` yang lengkap untuk 2025.05.01–2025.08.31.
4. Jika data tersebut memang tidak tersedia akibat migrasi simbol, pilih development window
   pengganti dan bekukan ulang calon final OOS sebelum membukanya.
5. Setelah window ketiga valid, audit ulang lalu putuskan apakah robustness Sep–Jan cukup untuk
   menerima trade-off kualitas entry validity 3.
