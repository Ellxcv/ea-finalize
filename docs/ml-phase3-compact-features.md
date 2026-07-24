# Fase 3 — Compact Feature Challenger

## Tujuan dan status

`ts7_ml_phase3_compact_v1` menguji apakah baseline gagal karena 60 raw feature terlalu redundan
untuk 1.080 candidate. Contract compact memakai 37 raw feature:

- 32 numeric;
- 3 boolean session;
- 2 categorical.

Experiment berstatus `EXPLORATORY_NOT_FROZEN`. Feature dipilih setelah development diagnostic,
sehingga hasil ini adalah development-tuned comparison dan bukan final OOS independen.

## Config inheritance

`config/ml-phase3-compact-v1.json` hanya menyimpan override feature contract dan mewarisi seluruh
label, split, model, calibration, threshold, reporting, serta forbidden-field list dari
`config/ml-phase3-baseline.json`.

Loader menolak inheritance cycle. `--replace-output` juga menolak menghapus direktori yang tidak
memiliki manifest experiment yang sesuai.

## Prinsip reduksi

- raw CCI/CI dan delta yang tumpang tindih diringkas menjadi directional gap;
- alignment/latency yang berkorelasi dipangkas menjadi confirmation summary, latency terpilih,
  dan state age MTF;
- cluster ATR/absolute SL diringkas menjadi `BarrierATR`, `ATRRatioM1M5`, dan `InitialSLATR`;
- return dipertahankan pada horizon 1/5/20;
- `BodyATR` dihapus karena hampir identik dengan `Return1ATR`;
- `PreEntryMFEATR` dihapus karena sangat berkorelasi dengan displacement;
- hanya EMA slope horizon 10 yang dipertahankan;
- `DataIntegrityFlag` dihapus sebagai feature karena konstan pada seluruh dataset.

Feature stabil dari diagnosis seperti `SignalAgeBars`, `STMTFAgeBars`, `BarrierATR`,
`TimeOfDayCos`, dan `TickVolume` tetap dipertahankan.

## Menjalankan experiment

~~~powershell
python tools/ml/train_baseline_models.py `
  --config config/ml-phase3-compact-v1.json `
  --dataset "C:\local-ml-data\processed\folder32-cci3-v1-dataset-v001\merged_candidates.csv" `
  --output-dir "C:\local-ml-data\artifacts\phase3-folder32-cci3-v1-compact-exp001"
~~~

## Hasil

| Model | Contract | ROC-AUC | Brier | Winner rejected | L4+ rejected | Recovery reduction |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | full | 0,4890 | 0,2549 | 7,43% | 6,45% | +0,26% |
| Logistic Regression | compact | 0,4871 | 0,2548 | 7,71% | 8,06% | -0,11% |
| Random Forest | full | 0,4884 | 0,2512 | 6,00% | 6,45% | -1,25% |
| Random Forest | compact | 0,4819 | 0,2519 | 11,14% | 12,90% | -1,97% |

Compact Random Forest menolak lebih banyak L4+, tetapi melanggar batas winner rejection 10%,
tetap jauh dari target L4+ rejection 20%, dan memperburuk AUC, Brier, original win rate, serta
recovery rate. Threshold validation-nya juga berubah dari `0,4641` ke `0,3919` lalu `0,3845`.

## Keputusan

Feature reduction statis saja bukan solusi. Compact contract tidak dipromosikan, model/threshold
tidak dibekukan, dan final OOS `2026.05.03–2026.07.18` tetap belum dibuka.

Catatan lengkap:
[compact experiment record](../tuning/runs/2026-07-24_GOLD-i_M1_cci-validity3-compact-ml/RECORD.md).
