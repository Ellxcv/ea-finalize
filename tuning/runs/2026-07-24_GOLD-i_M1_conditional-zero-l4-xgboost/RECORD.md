# Conditional Zero-L4 XGBoost Record

## Identity

- Date: 2026-07-24
- Symbol/timeframe: `GOLD.i#`, M1
- Source runs: Strategy Tester folders 43 and 44
- Dataset rows: 1,080
- Outcomes: 526 no recovery, 453 L1-L3, 101 L4+
- Dataset SHA-256:
  `D1EE04A22A877F133CAD28B41F2EB4672C9D780B8E58B9C307F609532383D58F`
- Config: `config/ml-phase3-dual-business-zero-l4-v3.json`
- XGBoost: 3.3.0, pinned by `tools/ml/requirements.txt`

## Contract

- NO_RECOVERY target uses all candidates.
- L4-risk target uses only recovery L1-L3 versus L4+.
- Oversampling is train-only; validation and evaluation retain original distribution.
- XGBoost is shallow, regularized, single-thread deterministic, and early-stopped on validation.
- Threshold selection requires retained candidates >=50%, active days >=80%, non-negative
  cycle-net proxy, and zero allowed L4+.
- Winner rejection is diagnostic, not a hard gate.
- Final OOS remains sealed.

## Command

~~~powershell
python tools/ml/train_dual_business_models.py `
  --dataset C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v2-dataset-v001\merged_candidates.csv `
  --output-dir C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-entry-v2-zero-l4-xgboost-exp004 `
  --config config/ml-phase3-dual-business-zero-l4-v3.json
~~~

## Result

| Pair | NO_RECOVERY AUC | Conditional L4 AUC | Retained | Active days | Winner rejected | WR delta | Recovery reduction | Allowed L4+ | L4+ rejected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic | 0.6075 | 0.5041 | 52.02% | 94.79% | 42.29% | +5.95 pp | 13.39% | 35/62 | 43.55% |
| Random Forest | 0.6220 | 0.5264 | 58.07% | 97.92% | 43.14% | -1.14 pp | -2.85% | 37/62 | 40.32% |
| XGBoost | 0.6345 | 0.5529 | 52.64% | 96.88% | 39.71% | +7.89 pp | 17.66% | 28/62 | 54.84% |

XGBoost is the development leader, but no pairing passes the zero-L4 gate. No validation fold
finds a feasible zero-L4 threshold while retaining the required activity. Status:
`REJECTED_NOT_FROZEN`.

## XGBoost evaluation folds

| Fold | Retained | Active days | Winner rejected | WR delta | Recovery reduction | Allowed L4+ | L4+ rejected |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 62.33% | 100.00% | 33.98% | +2.84 pp | 5.45% | 13/20 | 35.00% |
| 2 | 45.58% | 94.44% | 46.51% | +10.41 pp | 26.02% | 5/20 | 75.00% |
| 3 | 50.00% | 96.55% | 37.29% | +14.02 pp | 32.63% | 10/22 | 54.55% |

## Artifact hashes

| Artifact | SHA-256 |
| --- | --- |
| `experiment_manifest.json` | `97A3C4B81C0C7A059A2DE5835788A5D60CA59C5E3BD4C6E2C829AE42D153BF1C` |
| `experiment_report.json` | `5D29F3D3A0F906EF1340D3664E33F3661D5996CAF3FCC7212F77A8BCF25FF99F` |
| `predictions.csv` | `64C25C3D4B7B0F650D97C08AC26290C4B753C4635ABD15A69A53D70CF5E9A6AE` |
| `threshold_selection.csv` | `01BC8169D5E829059CA0A8C04EB255D019A4B878FB88583993E2B3EAE5224095` |
| `config.snapshot.json` | `9A7FE6B2EA676913437A592576AC7CD3E63F8A7F993FA06B4596DCF31F4DC115` |

## Decision

Do not integrate this model into EA runtime and do not open final OOS. Preserve XGBoost as the
leader for the next compact feature-v3 experiment on the same quality period.
