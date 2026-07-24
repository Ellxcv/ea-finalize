# Dual Business-Target Phase 3 Record

## Identity

- Date: 2026-07-24
- Symbol/timeframe: `GOLD.i#`, M1
- Source runs: Strategy Tester folders 43 and 44
- Dataset:
  `C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v2-dataset-v001\merged_candidates.csv`
- Dataset SHA-256:
  `D1EE04A22A877F133CAD28B41F2EB4672C9D780B8E58B9C307F609532383D58F`
- Candidate count: 1,080
- Outcome counts: 526 no recovery, 453 L1-L3, 101 L4+
- Config: `config/ml-phase3-dual-business-v2.json`

## Command

~~~powershell
python tools/ml/train_dual_business_models.py `
  --dataset C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v2-dataset-v001\merged_candidates.csv `
  --output-dir C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-entry-v2-dual-business-primary-exp002 `
  --config config/ml-phase3-dual-business-v2.json
~~~

## Reproducibility boundaries

- All fitting, oversampling, calibration, and threshold selection stay inside train/validation.
- Evaluation retains its original class distribution.
- Threshold selection never reads evaluation labels.
- Final OOS `2026.05.03-2026.07.18` remains sealed.
- Strategy Tester logs, dataset, predictions, and model binaries remain outside Git.

## Aggregate result

| Pair | NO_RECOVERY AUC | L4-risk AUC | Retained | Winner rejected | WR delta | Recovery reduction | L4+ rejected | Conditional L4+ reduction |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic | 0.6075 | 0.4959 | 86.49% | 12.00% | +0.95 pp | 2.14% | 12.90% | -2.90% |
| Random Forest | 0.6220 | 0.4576 | 88.51% | 11.14% | +0.21 pp | 0.51% | 11.29% | -0.74% |

No evaluation fold passes every acceptance gate. Status:
`REJECTED_NOT_FROZEN`.

## Artifact hashes

| Artifact | SHA-256 |
| --- | --- |
| `experiment_manifest.json` | `E3EE4D9B3FD9E49E4BFDE573B54F1F682B67DC3C598FE593397B801D254BADF8` |
| `experiment_report.json` | `CD0056D5D57A7C8E9F01024D4815D9D8889061904545000D12954E62BA5AF53F` |
| `predictions.csv` | `359E69A559F9351C4E64001EDF09170B372F1DD51936A0F2F9E27DD5C9E63646` |
| `threshold_selection.csv` | `9B019B0A38FA393E43F94F0E07B16194D6F1857E99F953A3A1C760D889A668DE` |
| `config.snapshot.json` | `3728975374D717EFACD2CE5ED1BA81181BA3C410535B595CE61E95EB8F2A96CF` |

## Decision

Do not freeze either model pair, do not add a runtime filter, and do not open final OOS. The
direct no-recovery target is a useful research lead, but the current L4-risk target/features are
not predictive enough to enforce the user's L1-L3 ceiling.
