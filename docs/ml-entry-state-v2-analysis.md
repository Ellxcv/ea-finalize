# Entry-State Schema v2 Analysis

## Keputusan

`REJECTED_NOT_FROZEN`

Dataset schema v2 valid dan seluruh feature baru berhasil direkam, tetapi Logistic Regression dan
shallow Random Forest masih tidak menemukan ranking signal walk-forward yang cukup. Tidak ada
model, threshold, atau feature subset yang dibekukan. Final OOS `2026.05.03–2026.07.18` tetap
belum dibuka.

## Dataset

Folder 43–44 mengulang dua development window validity 3 yang sama dengan dataset v1:

| Folder | Periode | Candidate | History quality | Net profit | Max equity DD |
| ---: | --- | ---: | ---: | ---: | ---: |
| 43 | 2025.09.01–2026.01.03 | 504 | 100% real ticks | 2.843,47 | 2.220,30 (38,93%) |
| 44 | 2026.01.04–2026.05.02 | 576 | 100% real ticks | 4.171,15 | 2.661,96 (44,40%) |

Audit menerima 2/2 run, mempertahankan 1.080/1.080 candidate, dan menghasilkan nol error. Dua
warning berasal dari `SYMBOL_MIGRATION_UNVERIFIED`. Distribusi label sama dengan dataset v1:

- 482 `FAVORABLE_FIRST` dan 598 `ADVERSE_FIRST`;
- 526 `NO_RECOVERY`;
- 453 `RECOVERY_L1_L3`;
- 101 `RECOVERY_L4_PLUS`.

Kesamaan sample dan label membuat perbandingan v1/v2 langsung: yang berubah hanya kontrak feature.

## Diagnosis feature baru

Dari 15 entry-state feature baru, hanya dua yang stabil pada kedua run dengan batas univariate
separation minimal 0,03:

| Target | Feature | Pooled AUC | Minimum run separation | Interpretasi |
| --- | --- | ---: | ---: | --- |
| Barrier favorable | `AdxValue` | 0,4628 | 0,0371 | ADX lebih rendah sedikit terkait favorable |
| L4+ | `HiLoLineSlopeATR` | 0,5559 | 0,0460 | slope HiLo lebih tinggi sedikit terkait L4+ |

Tiga belas feature baru lain tidak stabil antar-run. Nilai AUC sekitar 0,46–0,56 menunjukkan
separation yang lemah, bukan guard entry siap pakai. Seluruh kontrak v2 menghasilkan sembilan
sinyal stabil bila feature v1 juga dihitung.

## Walk-forward model

Evaluation selalu berada setelah train/validation dan memakai purge/embargo 50 menit.

| Contract / model | ROC-AUC | Brier | Winner rejected | L4+ rejected | Original WR delta | Recovery reduction |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| v1 full Logistic | 0,4890 | 0,2549 | 7,43% | 6,45% | +0,11 pp | 0,26% |
| v1 full RF | 0,4884 | 0,2512 | 6,00% | 6,45% | -0,41 pp | -1,25% |
| v1 compact RF | 0,4819 | 0,2519 | 11,14% | 12,90% | -0,91 pp | -1,97% |
| v2 full Logistic | 0,4975 | 0,2565 | 8,00% | 8,06% | +0,69 pp | 1,56% |
| v2 full RF | 0,4898 | 0,2518 | 9,71% | 11,29% | -0,05 pp | -0,08% |

Random Forest v2 menangkap L4+ lebih banyak daripada full v1, tetapi:

- masih jauh dari gate minimal 20%;
- original win rate tidak meningkat;
- recovery rate sedikit memburuk;
- fold pertama menolak 13,59% winner, sehingga batas winner 10% tidak stabil per-fold;
- ROC-AUC tetap sekitar random.

Logistic Regression memberi original win-rate delta terbaik, tetapi hanya `+0,69 pp` versus target
`+3 pp`, recovery reduction hanya `1,56%` versus target `10%`, dan L4+ rejection hanya `8,06%`.

## Makna

Masalah berikutnya bukan kekurangan indikator serupa. ADX/DI, CCI velocity, ATR expansion, dan
geometri HiLo/PSAR/SuperTrend sudah tersedia tetapi mayoritas tidak stabil. Menambah indikator
lagi tanpa hipotesis baru berisiko menambah noise.

Label barrier tetap berguna untuk kualitas gerak harga, tetapi hubungannya dengan L4+ lebih lemah
daripada dengan no-recovery. Langkah development berikutnya yang direkomendasikan adalah
challenger dua-target:

1. `NO_RECOVERY` versus recovery untuk memodelkan kemenangan original secara langsung;
2. `RECOVERY_L4_PLUS` versus selain L4+ sebagai risk model sekunder dengan penanganan class
   imbalance.

Pemilihan threshold harus tetap hanya pada validation fold dan gate wajib dinilai per-fold, bukan
hanya aggregate. Ini masih eksperimen development; final OOS tetap tersegel.
