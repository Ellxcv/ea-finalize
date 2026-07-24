# Phase 3B Deep-Recovery Failure Analysis

## Status

`EARLY_PATH_SCHEMA_V4_RECOMMENDED`

Phase 3B is a development-only diagnostic. It does not change EA decisions, freeze a model, or
open final OOS `2026.05.03-2026.07.18`.

## Question

The five schema-v3 experiments produced 15 out-of-fold decisions for every evaluation candidate:
five feature families multiplied by Logistic Regression, shallow Random Forest, and regularized
XGBoost. This analysis asks:

1. which L4+ cases repeatedly escape those models;
2. whether an individual feature separates L1-L3 from L4+ in both development runs;
3. whether a simple two-feature interaction discovered in the earlier run confirms in the later
   run.

An L4+ case is a persistent escape when at least 80% of the 15 decisions allow it. Pair
orientation is learned only from the earlier run. A pair must then reach AUC 0.60 in both runs;
the threshold is not relaxed after seeing the confirmation result.

## Reproduction

```powershell
python tools/ml/analyze_deep_recovery_failures.py `
  --dataset "C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v3-dataset-v002\merged_candidates.csv" `
  --artifact-root "C:\Users\ACER\Documents\TS7_ML\artifacts" `
  --output-dir "C:\Users\ACER\Documents\TS7_ML\artifacts\phase3b-folder32-cci3-entry-v3-deep-recovery-diagnostic-v002" `
  --config config/ml-phase3-deep-recovery-diagnostics-v1.json
```

The analyzer writes:

- a 15-model consensus row for every evaluation candidate;
- an allowed-L4 and L4-risk-veto matrix per family/model;
- L1-L3 versus L4+ feature separation per run;
- all additive rank interactions with discovery and confirmation AUC;
- subgroup depth rates;
- an auditable JSON report, summary, and artifact manifest.

## Results

| Item | Result |
| --- | ---: |
| Development candidates | 1,080 |
| Recovery L1-L3 / L4+ | 453 / 101 |
| Evaluation candidates | 644 |
| Evaluation L4+ | 62 |
| Persistent L4+ escapes | 20/62 (32.26%) |
| Features tested | 62 |
| Stable individual features | 12 |
| Two-feature pairs tested | 1,596 |
| Pairs reaching AUC 0.60 in both runs | 0 |

The lowest allowed-L4 count from a single challenger is still 28/62 from the core shallow forest.
The 20 persistent escapes are not isolated to one side or one fold:

- 11 BUY and 9 SELL;
- 9, 7, and 4 across evaluation folds 1, 2, and 3;
- 17 `ADVERSE_FIRST` and 3 `FAVORABLE_FIRST`;
- all 20 have complete schema-v3 structure context.

The strongest stable individual feature remains weak: `ATR_M5` has pooled AUC 0.5872. The best
two-feature result is `SpreadATR + SupportAgeBars`, with discovery AUC 0.6226 but confirmation AUC
0.5957. Relaxing the fixed 0.60 gate after observing 0.5957 would be evaluation-set tuning, so the
pair is not promoted.

## Interpretation

Schema v3 contains useful general entry-quality information, but it does not isolate the mechanism
that turns a recovery into L4+. A material subset of deep recoveries looks safe to almost every
entry-time model. Adding another similar indicator or combining all v3 families would mainly add
overfit risk.

The next schema should observe the price path after entry but before the original position reaches
SL/recovery. Candidate checkpoints such as 5, 10, and 20 closed M1 bars can record MFE/MAE,
directional velocity, distance remaining to SL, volatility change, and structural reaction using
only information available at that checkpoint. That changes the decision from an impossible
entry-time guess into an early-exit warning while there is still time to prevent recovery.

Final OOS remains sealed and runtime stays `ML_OFF`.
