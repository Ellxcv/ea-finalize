# Phase 3B Deep-Recovery Failure Diagnostic

## Decision

`EARLY_PATH_SCHEMA_V4_RECOMMENDED`

## Inputs

- Dataset: schema v3 folder 47-48, 1,080 rows
- Dataset SHA-256:
  `4A869B605EDFF2709B8F7124F031E64EFAEE73C1B51FD2BF27A412749DED5C2E`
- Prediction artifacts: five staged v3 families, three model pairings each
- Evaluation matrix: 644 candidates and 9,660 prediction rows
- Final OOS: not opened

## Result

- 62 L4+ cases occur in the evaluation folds.
- 20/62 remain allowed by at least 12 of 15 challenger decisions.
- 12/62 entry features pass the weak univariate stability screen.
- None of 1,596 additive rank pairs reaches AUC 0.60 in both chronological runs.
- Best pair: `SpreadATR + SupportAgeBars`, discovery AUC 0.6226 and confirmation AUC 0.5957.
- No model, feature pair, or threshold is frozen.

The repeated misses occur on both BUY and SELL, in all three evaluation folds, and all have
complete schema-v3 context. The evidence therefore favors an early post-entry warning schema over
another candidate-time indicator.

## Local artifacts

`C:\Users\ACER\Documents\TS7_ML\artifacts\phase3b-folder32-cci3-entry-v3-deep-recovery-diagnostic-v002`

| Artifact | SHA-256 |
| --- | --- |
| `diagnostic_manifest.json` | `A5433D0F0416E19932F86C7F72FA1C902EEA5B07FC229EE5DDA45C705A40D729` |
| `diagnostic_report.json` | `7F3057B8ECF5AE08DE6536959DD84DFD4CEA31606DA5647716C60F49A4FCFFEA` |
| `consensus_candidates.csv` | `F2E06C2F5DD30FC5C272503C7DBB39C16AB14C2B7983865631F60FD907072F5E` |
| `feature_depth_separation.csv` | `E8185289196818B3CD5A380831DB317AB54700DB241C42109455DE22D3C8E84D` |
| `pair_interactions.csv` | `9D001B0D590F53B382DD21007624E7423818BA8E6D04AAF8EB3F2A0CDB7F8FAC` |

Raw dataset, predictions, and diagnostic tables remain local.
