# Dual Business-Target Challenger

Status: **implemented, development-tested, rejected, not frozen**

## Tujuan

Challenger ini mengikuti prioritas bisnis EA secara langsung:

1. mencegah entry original masuk recovery;
2. bila recovery tetap terjadi, mengurangi peluang mencapai L4+.

Dua target dilatih terpisah:

- `NO_RECOVERY`: positif bila cycle selesai tanpa recovery;
- `RECOVERY_L4_PLUS`: positif bila cycle mencapai L4+.

Label barrier tidak digunakan sebagai target model ini. Kolom outcome, label, dan informasi masa
depan tetap dilarang masuk feature.

## Kontrak training

- Model: Logistic Regression dan shallow Random Forest.
- Split: expanding walk-forward dengan purge/embargo 50 menit.
- Kalibrasi: Platt calibration hanya memakai validation fold.
- Class balancing: deterministic minority oversampling hanya pada training data target L4+.
- Validation dan evaluation selalu memakai distribusi asli.
- Threshold dipilih hanya dari validation fold.
- Final OOS `2026.05.03-2026.07.18` tidak dibuka.

Entry diizinkan hanya bila kedua syarat terpenuhi:

~~~text
P(NO_RECOVERY) >= threshold_no_recovery
AND
P(L4_PLUS) <= threshold_l4_risk
~~~

Pemilihan threshold bersifat lexicographic sesuai tujuan pengguna: kurangi recovery terlebih
dahulu, lalu tingkatkan original win rate, baru kurangi proporsi L4+ di antara recovery.

## Acceptance gate per fold

- candidate retained minimal 50%;
- winner rejected maksimal 10%;
- active-day coverage minimal 80%;
- original win-rate delta minimal +3 percentage points;
- recovery-rate relative reduction minimal 10%;
- total L4+ rejected minimal 20%;
- L4+ among recovery relative reduction minimal 20%.

Gate harus lolos pada setiap evaluation fold, bukan hanya aggregate.

## Hasil development folder 43-44

Dataset berisi 1.080 candidate: 526 `NO_RECOVERY`, 453 `RECOVERY_L1_L3`, dan 101
`RECOVERY_L4_PLUS`.

| Pair | NO_RECOVERY AUC | L4-risk AUC | Retained | Winner rejected | Original WR delta | Recovery reduction | L4+ rejected | L4+ among recovery reduction |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic | 0.6075 | 0.4959 | 86.49% | 12.00% | +0.95 pp | 2.14% | 12.90% | -2.90% |
| Random Forest | 0.6220 | 0.4576 | 88.51% | 11.14% | +0.21 pp | 0.51% | 11.29% | -0.74% |

`NO_RECOVERY` memiliki ranking signal di atas random pada seluruh fold:

| Fold | Logistic AUC | Random Forest AUC |
| --- | ---: | ---: |
| 1 | 0.6391 | 0.6196 |
| 2 | 0.5857 | 0.5933 |
| 3 | 0.6273 | 0.6834 |

Sebaliknya, target L4+ tidak stabil walaupun class balancing sudah dibatasi dengan benar:

| Fold | Logistic AUC | Random Forest AUC |
| --- | ---: | ---: |
| 1 | 0.5387 | 0.4985 |
| 2 | 0.4115 | 0.4631 |
| 3 | 0.5005 | 0.4003 |

Tidak ada pair yang lolos seluruh gate pada satu pun fold. Model L4-risk saat ini tidak dapat
membedakan recovery L1-L3 dari L4+ secara konsisten, sedangkan signal `NO_RECOVERY` belum dapat
diubah menjadi filter yang memenuhi batas winner dan peningkatan bisnis.

## Keputusan

- Jangan integrasikan model atau threshold ini ke runtime EA.
- Jangan membuka final OOS.
- Jangan melakukan threshold tuning ulang pada evaluation fold yang sama.
- Pertahankan pipeline sebagai reproducible challenger.
- Karena dataset berkualitas sudah maksimal, eksperimen berikutnya harus memakai data yang sama
  secara konservatif dan hanya menambah feature dengan hipotesis baru.

## Revisi zero-L4 dan conditional target

Setelah prioritas bisnis diubah, winner rejection tidak lagi menjadi hard gate. Target sekunder
sekarang hanya dilatih pada 453 recovery L1-L3 versus 101 recovery L4+, sehingga probability-nya
diinterpretasikan sebagai `P(L4+ | recovery)`. Hard gate baru:

- allowed L4+ harus nol;
- candidate retained minimal 50%;
- active-day coverage minimal 80%;
- cycle-net proxy harus tetap non-negatif.

Logistic Regression, shallow Random Forest, dan regularized XGBoost 3.3.0 dibandingkan dengan
threshold validation-only. Hasil pooled future-fold:

| Pair | NO_RECOVERY AUC | Conditional L4 AUC | Retained | Active days | Winner rejected | WR delta | Recovery reduction | Allowed L4+ | L4+ rejected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic | 0.6075 | 0.5041 | 52.02% | 94.79% | 42.29% | +5.95 pp | 13.39% | 35/62 | 43.55% |
| Random Forest | 0.6220 | 0.5264 | 58.07% | 97.92% | 43.14% | -1.14 pp | -2.85% | 37/62 | 40.32% |
| XGBoost | 0.6345 | 0.5529 | 52.64% | 96.88% | 39.71% | +7.89 pp | 17.66% | 28/62 | 54.84% |

XGBoost menjadi development leader dan memperbaiki ranking kedua target, win rate, serta recovery
reduction. Namun tidak satu pun validation fold menemukan threshold feasible dengan nol L4+ pada
batas aktivitas yang ditetapkan. Evaluation XGBoost masih meloloskan 28 dari 62 L4+. Status tetap
`REJECTED_NOT_FROZEN`: runtime EA tidak berubah dan final OOS tidak dibuka.

Schema v3 berikutnya sudah diimplementasikan untuk menguji empat hipotesis baru secara terpisah:
volatility regime, trend durability, pre-entry momentum, dan dynamic structure. Kontrak lengkap:
[ml-entry-candidate-v3-schema.md](ml-entry-candidate-v3-schema.md).
