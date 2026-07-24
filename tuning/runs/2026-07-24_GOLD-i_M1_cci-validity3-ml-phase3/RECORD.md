# Phase 3 ML Experiment — CCI Validity 3

## Decision

`REJECTED_NOT_FROZEN`

Folder 39–40 cukup untuk menjalankan eksperimen baseline ML yang sah, tetapi hasil walk-forward
tidak menunjukkan sinyal prediktif atau perbaikan outcome bisnis yang cukup. Tidak ada model,
feature set, atau threshold yang dibekukan. Periode final OOS `2026.05.03–2026.07.18` tetap belum
dibuka.

## Dataset

| Item | Nilai |
| --- | --- |
| Strategy version | `folder32_cci3_v1` |
| Development runs | folder 39 dan folder 40 |
| Candidate | 1.080 |
| Candidate range | `2025.09.01 11:12:00`–`2026.05.01 18:55:00` |
| History quality | 100% pada kedua run |
| Dataset SHA-256 | `BCC8B49ACB13DF1075BC776E4D9B36D0AE59DA172F2760E4D627BC5D75255404` |
| Label | `Barrier50Outcome` |
| Positive / negative | 482 `FAVORABLE_FIRST` / 598 `ADVERSE_FIRST` |
| Purge/embargo | 50 menit per sisi |
| Walk-forward folds | 3 |

Folder 38 tidak masuk dataset karena history quality 16% dan margin-call termination.

## Command

~~~powershell
python tools/ml/train_baseline_models.py `
  --dataset "C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-v1-dataset-v001\merged_candidates.csv" `
  --output-dir "C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-v1-exp001"
~~~

Folder 39–40 diperlakukan sebagai development data chronological. Pipeline memakai expanding
walk-forward di dalam rentang tersebut agar pemilihan model tidak bergantung pada satu boundary
folder saja. Preprocessor hanya di-fit pada train, calibration dan threshold dipilih pada
validation, kemudian metrik berikut dihitung pada future evaluation folds.

## Aggregate future-fold result

Evaluation prediction: 644 candidate.

| Model | ROC-AUC | PR-AUC | Log loss | Brier | Retained | Winner rejected | L4+ rejected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | 0,4890 | 0,4316 | 0,7045 | 0,2549 | 92,39% | 7,43% | 6,45% |
| Shallow Random Forest | 0,4884 | 0,4424 | 0,6956 | 0,2512 | 94,72% | 6,00% | 6,45% |

Random Forest menjadi exploratory champion secara Brier/log loss, tetapi nilai ROC-AUC kedua
model berada di bawah 0,50 dan tidak menunjukkan ranking signal yang dapat dipercaya.

## Business gate diagnosis

| Gate development proxy | Target | Logistic Regression | Random Forest | Status |
| --- | ---: | ---: | ---: | --- |
| Winner legacy ditolak | maksimal 10% | 7,43% | 6,00% | lulus |
| Recovery L4+ ditolak | minimal 20% | 6,45% | 6,45% | gagal |
| Original win rate | naik minimal 3 pp | +0,11 pp | -0,41 pp | gagal |
| Recovery entry rate | turun minimal 10% relatif | 0,26% | -1,25% | gagal |
| Active trading days | minimal 80% | 100% | 100% | lulus |

Profit factor, actual net profit, dan maximum equity drawdown tidak dinilai dari proxy offline.
Metrik tersebut baru sah bila model sudah dibekukan dan dijalankan pada Strategy Tester OOS.
Karena gate inti entry/recovery sudah gagal, membuka OOS sekarang tidak dibenarkan.

Threshold validation juga tidak stabil:

- Logistic Regression: `0,3534`, `0,4110`, `0,4033`;
- Random Forest: `0,3655`, `0,3967`, `0,4218`.

## Artifact provenance

Artefak lokal:

`C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-v1-exp001`

| Artifact | SHA-256 |
| --- | --- |
| `experiment_manifest.json` | `AD075D4E2B36DDD47395F8B44E1E90F9FE0D1C21A5C03FAC9C0F2B321DE2BACD` |
| `experiment_report.json` | `B8A8FFBEF0B1D309158FBE54FB36E7B229621A3BF23B65A04CF937800159C4F5` |
| `predictions.csv` | `B896BE356A975B5400F8F22615A30DE792B9E95E62B969AA3F1A524202528715` |
| `config.snapshot.json` | `C7CAFE9433CE59CEDBDBB004477A238A571C83C98F6494DCB7791093728F6291` |

Artefak model dan prediction tetap lokal karena berisi data turunan Strategy Tester.

## Next action

Jangan menjalankan final OOS `2026.05.03–2026.07.18` untuk kandidat ini. Perbaikan berikutnya harus
dilakukan di development stage, misalnya:

1. analisis feature/subgroup untuk mengetahui apakah signal hanya muncul pada regime tertentu;
2. tambah development candidate independen menuju target awal 2.000–5.000;
3. uji feature reduction atau label khusus deep-recovery tanpa mengubah final OOS;
4. rerun walk-forward dan hanya freeze kandidat yang stabil serta mendekati seluruh gate.
