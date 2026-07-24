# Folder 35 — Phase 2 Retained Dataset

## Status

`PASS — RETAINED DEVELOPMENT DATASET`

Run `r02` memakai seluruh setting yang dibekukan, termasuk deposit USD 4.000. Audit menerima
982/982 candidate dengan nol error. Satu warning non-blocking tetap ada karena tanggal migrasi
`GOLD#` ke `GOLD.i#` belum dapat dibuktikan.

## Provenance

| Item | Nilai |
| --- | --- |
| RunId | `folder32_v1_GOLD-i_M1_20260104_20260502_r02` |
| Strategy / schema | `folder32_v1` / `ts7_entry_candidate_v1` |
| Source revision | `3dd654c62607b2333fde9473900d97f997bea48e` |
| Strategy preset SHA-256 | `737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651` |
| EA EX5 SHA-256 | `D4EBF165D5B66BEDD397353C7B0352661F41057FC37491013E7EBC39171ABC8C` |
| Report SHA-256 | `5443445E4BAE73C15185BB0EA05D4D916D7A6D22F9516E986CD3DD8E20BE6E6E` |
| Manifest SHA-256 | `F3DDD3333447062D5F50CCAC3CC6BD701BE22C5205AB0CD26D7BF17448FD5D19` |
| Context SHA-256 | `1298847AE2447084C4A7AB887745CCECDD08C2F32E357C7328F73B4ADDFE8B90` |
| Symbol / timeframe | `GOLD.i#` / M1 |
| Period | 2026.01.04–2026.05.02 |
| Candidate coverage | 2026.01.05 02:10–2026.05.01 21:35 |
| Model / history | Every tick based on real ticks / 99% |
| Bars / ticks | 115.508 / 32.562.123 |
| Deposit / final balance | USD 4.000 / USD 11.020,93 |
| Leverage | 1:500 |

Hash dependency runtime cocok dengan baseline manifest. Raw report, CSV, binary, dan processed
dataset tetap lokal dan tidak di-commit.

## Audit gate

| Pemeriksaan | Hasil |
| --- | ---: |
| Raw / retained / excluded candidate | 982 / 982 / 0 |
| Barrier rows | 1.964 |
| Audit errors / warnings | 0 / 1 |
| Feature/structure/session ready | 982 / 982 / 982 |
| Duplicate atau conflicting setup | 0 |
| Orphan atau missing pairing | 0 |
| Financial reconciliation | PASS, 7.020,93 |
| Gate | PASS |

Processed dataset version lokal: `folder32-v1-dataset-v001`.

| Processed artifact | SHA-256 |
| --- | --- |
| `merged_candidates.csv` | `4B76D4F7D50A7DF0FADBC9922C033B28087ECBA3E1259EC798F9390606353D5D` |
| `rule_analysis.csv` | `B80AB8A87CF792B68E5342A69362840EA29F9CE6372214FF8F3D139078CCA3D2` |
| `audit_config.snapshot.json` | `593BC7D147F93B011547193B93914D89CB901C589AAC993F7FC97D931D2F536B` |

## Outcome baseline

| Outcome | Jumlah | Persentase |
| --- | ---: | ---: |
| `NO_RECOVERY` | 569 | 57,94% |
| `RECOVERY_L1_L3` | 323 | 32,89% |
| `RECOVERY_L4_PLUS` | 90 | 9,16% |
| Barrier 50 `FAVORABLE_FIRST` | 462 | 47,05% |
| Barrier 50 `ADVERSE_FIRST` | 520 | 52,95% |

Original trade:

- win/loss/flat: 565/416/1;
- win rate: 57,54%;
- net profit: 190,10;
- profit factor: sekitar 1,06.

Cycle net profit adalah 7.020,93. Dengan demikian recovery masih menyumbang sebagian besar hasil
baseline, sementara target model tetap meningkatkan `NO_RECOVERY` dan menurunkan L4+ tanpa
merusak coverage serta profit portofolio.

## Reproducibility

Kelima file CSV `r02` identik dengan `r01` setelah kolom `RunId` diabaikan. Jumlah record, feature,
entry, trade outcome, cycle outcome, dan barrier outcome semuanya sama. Ini membuktikan pengulangan
folder 35 mereproduksi history folder 34 dan baseline; hanya account deposit serta RunId yang
berubah.

## Coverage dan batas penggunaan

- 982 candidate tersebar pada 84 active trading days;
- Januari/Februari/Maret/April memiliki 218/255/263/233 candidate; dua hari Mei memiliki 13;
- seluruh record masih membawa `SYMBOL_MIGRATION_UNVERIFIED`;
- window ini sudah pernah dilihat dan hanya development data, bukan final OOS;
- 982 candidate cukup untuk diagnosis dan Logistic Regression eksploratif, tetapi belum memenuhi
  target awal 2.000–5.000 candidate untuk pemilihan model yang lebih stabil.

## Keputusan berikutnya

1. Fase 2 retained dataset awal dinyatakan lolos.
2. Fase 3 boleh mulai dari pipeline reproducible, leakage checks, chronological split, serta
   Logistic Regression eksploratif.
3. Jangan membekukan model atau membuka final OOS dari 982 candidate ini.
4. Tambahkan development window non-overlap dengan preset identik sampai mendekati 2.000–5.000
   candidate, lalu rerun audit gabungan sebelum memilih model/threshold.
