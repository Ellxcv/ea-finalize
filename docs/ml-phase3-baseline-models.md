# Fase 3 — Offline Baseline Models

## Status

Pipeline Phase 3 sudah diimplementasikan dan diuji pada retained dataset folder 35. Output selalu
berstatus `EXPLORATORY_NOT_FROZEN`: ia tidak boleh dipasang ke EA, dianggap model final, atau
dipakai untuk membuka final OOS.

Implementasi memakai Python standard library agar dapat dijalankan pada environment project tanpa
NumPy/scikit-learn. Baseline yang dibandingkan:

- Logistic Regression dengan standardization train-only dan L2 regularization;
- deterministic shallow Random Forest;
- Platt calibration yang di-fit pada validation fold;
- threshold veto yang dipilih pada validation fold dengan batas winner rejection.

XGBoost/ONNX tidak masuk eksperimen ini. Keduanya baru relevan setelah jumlah data dan sinyal
walk-forward cukup.

## Kontrak data dan feature

Input wajib memakai `merged_candidates.csv` hasil audit Phase 2 yang sudah lolos. Feature hanya
diambil dari allowlist eksplisit di `config/ml-phase3-baseline.json`.

Pipeline menolak:

- field label/outcome, ID, waktu mentah, ticket, harga absolut, dan P/L sebagai feature;
- duplicate `SetupId`;
- label selain `FAVORABLE_FIRST`/`ADVERSE_FIRST`;
- missing/non-finite feature;
- output experiment di dalam repository.

Numeric standardization dan categorical level hanya di-fit pada train fold. Category baru pada
validation/evaluation dipetakan ke all-zero one-hot, bukan digunakan untuk memperbarui encoder.

## Chronological walk-forward

Dataset awal memakai tiga expanding folds:

| Fold | Train | Validation | Evaluation |
| ---: | ---: | ---: | ---: |
| 1 | 314 | 77 | 195 |
| 2 | 470 | 116 | 196 |
| 3 | 629 | 155 | 194 |

Setiap boundary memakai purge 50 menit pada sisi kiri dan embargo 50 menit pada sisi kanan.
Candidate dengan `SignalTime + Direction` yang sama tidak boleh terpisah antar-partition.

Alur setiap fold:

~~~text
train
  -> fit preprocessor
  -> fit Logistic Regression / Random Forest
validation
  -> fit Platt calibrator
  -> pilih threshold dengan winner rejection <= 10%
future evaluation
  -> ukur ML metrics dan business proxy tanpa refit
~~~

Evaluation fold ini masih development walk-forward, bukan final OOS Phase 4.

## Menjalankan experiment

~~~powershell
python tools/ml/train_baseline_models.py `
  --dataset "C:\local-ml-data\processed\folder32-v1-dataset-v001\merged_candidates.csv" `
  --output-dir "C:\local-ml-data\artifacts\phase3-folder32-v1-exp001"
~~~

Gunakan `--replace-output` hanya untuk mengganti exact experiment directory yang sudah ditinjau.
Raw/processed/model artifact tetap lokal dan tidak di-commit.

Output:

~~~text
phase3-folder32-v1-exp001/
  config.snapshot.json
  experiment_manifest.json
  experiment_report.json
  experiment_report.md
  fold_metrics.csv
  threshold_selection.csv
  calibration_curve.csv
  subgroup_metrics.csv
  predictions.csv
  models/
    fold-<n>_logistic_regression.json
    fold-<n>_shallow_random_forest.json
~~~

Manifest menyimpan hash dataset, config, script, dan setiap artifact. Model JSON menyimpan
preprocessor, model, calibrator, threshold, serta date range fold.

## Hasil experiment awal

Dataset: 982 candidate folder 35; aggregate evaluation berisi 585 future-fold prediction.

| Model | ROC-AUC | PR-AUC | Log loss | Brier | Retained | Winner rejected | L4+ rejected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | 0,4977 | 0,4533 | 0,6922 | 0,2495 | 93,33% | 5,95% | 7,14% |
| Shallow Random Forest | 0,4854 | 0,4355 | 0,6974 | 0,2520 | 86,15% | 15,18% | 12,50% |

Logistic Regression menjadi exploratory champion karena Brier/log loss lebih baik, tetapi
performanya pada dasarnya setara tebakan acak:

- original win rate proxy hanya naik dari 57,44% menjadi 57,88%;
- recovery rate proxy hanya turun sekitar 1,10% relatif;
- L4+ yang ditolak hanya 7,14%, jauh di bawah target 20%;
- Random Forest menolak 15,18% legacy winner dan melampaui batas 10%;
- threshold Logistic Regression tidak stabil: fold pertama memilih allow-all.

Karena itu tidak ada model atau threshold yang dibekukan. Hasil ini bukan alasan mengaktifkan
`ML_SHADOW`/`ML_FILTER`.

## Hasil challenger CCI validity 3

Dataset folder 39–40 yang lolos audit (1.080 candidate) sudah dijalankan melalui pipeline yang
sama. Folder 38 tidak disertakan karena history quality 16% dan margin-call termination.

| Model | ROC-AUC | PR-AUC | Log loss | Brier | Winner rejected | L4+ rejected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | 0,4890 | 0,4316 | 0,7045 | 0,2549 | 7,43% | 6,45% |
| Shallow Random Forest | 0,4884 | 0,4424 | 0,6956 | 0,2512 | 6,00% | 6,45% |

Random Forest menjadi exploratory champion berdasarkan Brier/log loss, tetapi kedua model tetap
setara atau lebih buruk dari ranking acak. Kenaikan original win rate terbaik hanya `+0,11 pp`
dan pengurangan recovery rate relatif hanya `0,26%`; keduanya jauh di bawah gate. Model dan
threshold tidak dibekukan, dan final OOS `2026.05.03–2026.07.18` tetap belum dibuka.

Catatan eksperimen lengkap:
[CCI validity 3 Phase 3 record](../tuning/runs/2026-07-24_GOLD-i_M1_cci-validity3-ml-phase3/RECORD.md).

Diagnosis lanjutan membuktikan label barrier-50 tetap selaras dengan outcome bisnis pada kedua
development run, tetapi feature individual lemah dan memiliki 14 pasangan korelasi absolut
minimal 0,90. Kontrak, command, dan hasil tersedia di
[ml-phase3-feature-diagnostics.md](ml-phase3-feature-diagnostics.md).

Compact challenger kemudian mengurangi raw feature dari 60 menjadi 37. L4+ rejection Random
Forest naik menjadi 12,90%, tetapi winner rejection memburuk menjadi 11,14%, melewati gate 10%,
dan metrik klasifikasi/recovery ikut memburuk. Compact contract tidak dipromosikan. Detailnya ada
di [ml-phase3-compact-features.md](ml-phase3-compact-features.md).

Schema v2 entry-state sudah diimplementasikan untuk menguji informasi ADX/DI, CCI velocity,
volatility expansion, serta indicator distance/slope yang belum tersedia di v1. Short logger parity
folder 41/42 dan training development v2 folder 43–44 sudah selesai.

## Hasil entry-state schema v2

Folder 43–44 menghasilkan 1.080 candidate schema v2 dan audit lulus tanpa error. Karena sample dan
label sama dengan dataset validity 3 v1, perubahan hasil berasal dari 15 feature entry-state baru.

| Model | ROC-AUC | Brier | Winner rejected | L4+ rejected | Original WR delta | Recovery reduction |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | 0,4975 | 0,2565 | 8,00% | 8,06% | +0,69 pp | 1,56% |
| Shallow Random Forest | 0,4898 | 0,2518 | 9,71% | 11,29% | -0,05 pp | -0,08% |

Random Forest menangkap L4+ lebih banyak daripada full v1, tetapi masih jauh di bawah gate 20%,
tidak memperbaiki original win/recovery, dan winner rejection melampaui 10% pada salah satu fold.
Model v2 tidak dibekukan. Analisis lengkap:
[ml-entry-state-v2-analysis.md](ml-entry-state-v2-analysis.md).

Challenger dua target bisnis kemudian diuji pada dataset yang sama. Ranking target
`NO_RECOVERY` membaik menjadi AUC 0,6075-0,6220, tetapi L4-risk tetap setara atau lebih buruk
dari random dan tidak ada fold yang lolos seluruh gate. Challenger berstatus
`REJECTED_NOT_FROZEN`; final OOS tidak dibuka. Lihat
[ml-dual-business-targets.md](ml-dual-business-targets.md).

## Interpretasi dan langkah berikutnya

Hasil lemah belum membuktikan ML tidak berguna. Dataset 982 candidate berada pada batas eksplorasi
dan hanya mencakup satu continuous development window. Langkah aman:

1. kumpulkan development window non-overlap dengan kontrak baseline identik;
2. capai sekitar 2.000–5.000 candidate independen;
3. audit dan merge tanpa menghitung ulang duplicate run;
4. rerun pipeline yang sama tanpa mengubah final OOS;
5. hanya pertimbangkan feature reduction/tree boosting bila walk-forward menunjukkan sinyal yang
   konsisten.

Jangan memilih threshold baru dari evaluation fold experiment ini. Evaluation hanya boleh
digunakan untuk memutuskan bahwa kandidat saat ini belum siap.
