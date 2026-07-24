# CCI Validity 3 — Compact Feature ML Experiment

## Decision

`COMPACT_REJECTED_NOT_FROZEN`

Compact feature contract sudah dibandingkan dengan full-feature baseline memakai dataset,
walk-forward folds, purge/embargo, model hyperparameter, calibration, dan threshold gate yang
identik. Final OOS tidak dibuka.

## Contract

| Item | Full | Compact |
| --- | ---: | ---: |
| Numeric | 54 | 32 |
| Boolean | 3 | 3 |
| Categorical | 3 | 2 |
| Total raw feature | 60 | 37 |

Reduksi raw feature: 38,33%.

Contract compact mempertahankan representasi nonredundan dari candidate age, volatility/risk,
CCI directional gap, confirmation latency/state age, price action, EMA/regime, volume, time,
session, dan directional room.

## Dataset dan execution

| Item | Nilai |
| --- | --- |
| Dataset | folder 39–40 validity 3 |
| Candidate | 1.080 |
| Aggregate future-fold predictions | 644 |
| Dataset SHA-256 | `BCC8B49ACB13DF1075BC776E4D9B36D0AE59DA172F2760E4D627BC5D75255404` |
| Folds | 3 chronological expanding walk-forward |
| Purge/embargo | 50 menit per sisi |
| Config | `ts7_ml_phase3_compact_v1` |

~~~powershell
python tools/ml/train_baseline_models.py `
  --config config/ml-phase3-compact-v1.json `
  --dataset "C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-v1-dataset-v001\merged_candidates.csv" `
  --output-dir "C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-v1-compact-exp001"
~~~

## Full versus compact

| Model | Contract | ROC-AUC | PR-AUC | Log loss | Brier | Retained |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | full | 0,4890 | 0,4316 | 0,7045 | 0,2549 | 92,39% |
| Logistic Regression | compact | 0,4871 | 0,4297 | 0,7038 | 0,2548 | 92,39% |
| Random Forest | full | 0,4884 | 0,4424 | 0,6956 | 0,2512 | 94,72% |
| Random Forest | compact | 0,4819 | 0,4285 | 0,6971 | 0,2519 | 90,37% |

| Model | Contract | Winner rejected | L4+ rejected | Allowed original win rate | Recovery reduction |
| --- | --- | ---: | ---: | ---: | ---: |
| Logistic Regression | full | 7,43% | 6,45% | 54,45% | +0,26% |
| Logistic Regression | compact | 7,71% | 8,06% | 54,29% | -0,11% |
| Random Forest | full | 6,00% | 6,45% | 53,93% | -1,25% |
| Random Forest | compact | 11,14% | 12,90% | 53,44% | -1,97% |

Compact Random Forest menaikkan L4+ rejection sebesar 6,45 pp, tetapi:

- winner rejection naik menjadi 11,14% dan gagal batas maksimal 10%;
- L4+ rejection 12,90% masih gagal target minimal 20%;
- ROC-AUC, PR-AUC, Brier, original win rate, dan recovery rate memburuk;
- validation threshold tidak stabil: `0,4641`, `0,3919`, `0,3845`.

Compact Logistic Regression tidak melanggar winner gate, tetapi tidak menghasilkan perbaikan
bisnis dan tetap memiliki AUC di bawah 0,50.

## Interpretation boundary

Feature contract dipilih setelah development diagnostic pada dataset yang sama. Karena itu hasil
ini hanya boleh dipakai untuk menolak atau memperbaiki challenger, bukan sebagai bukti independen
untuk freeze. Hasil aktual juga gagal gate, sehingga final OOS tetap tersegel.

Feature reduction statis tidak cukup. Langkah development berikutnya perlu menambah informasi
entry-state yang belum tersedia, bukan sekadar mencoba model lebih kompleks atau threshold baru.

## Artifact provenance

Lokasi lokal:

`C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-v1-compact-exp001`

| Artifact | SHA-256 |
| --- | --- |
| `experiment_manifest.json` | `46BD00D71830CECEBD156017D083DCFC0747EFCDA1F103D767B919B8F77CFF81` |
| `experiment_report.json` | `9AFBE3A84CC7CEF42A2688375C9E90C6AA3D89425D58F40723E2E359AD7C1810` |
| `predictions.csv` | `12FF05079606EC87EEDE09EFF5CD91D9A94F50754B42B074FB7E28940B008B39` |
| `config.snapshot.json` | `F914D5BEBA68B17E1A4D89DEED7796891045A8D0E47AB77035B118F33F91C9A5` |

Dataset dan model artifact tetap lokal dan tidak di-commit.
