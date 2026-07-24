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
- Eksperimen berikutnya memerlukan development data independen dan/atau feature dengan hipotesis
  baru yang khusus menjelaskan kedalaman recovery, bukan indikator trend serupa.
