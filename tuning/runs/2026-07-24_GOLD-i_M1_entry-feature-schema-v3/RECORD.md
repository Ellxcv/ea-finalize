# Entry Feature Schema v3 Implementation

## Status

`IMPLEMENTED - COMPILED - AUTOMATED CONTRACT TESTED - TESTER PARITY PASSED`

## Scope

- Upgrade observation-only logger from `ts7_entry_candidate_v2` to v3.
- Preserve the 97-column v2 prefix.
- Add 30 compact volatility, durability, momentum, and structure fields.
- Add `FeatureReadyV3`; total candidate header is 128 columns.
- Extend dataset audit with backward-compatible v1/v2/v3 support.
- Add core and four staged zero-L4 model configs.
- Do not change any trading decision.

## Leakage boundary

- Every market value comes from closed bars.
- ATR history ends at shift 1.
- Trend and momentum paths end at shift 1.
- Structure pivots require closed right-side confirmation bars.
- Cycle outcomes remain labels only.

## Verification

| Check | Result |
| --- | --- |
| MQL v3 header versus Python audit | 128 columns, pass |
| v1/v2 audit backward compatibility | pass |
| v3 readiness and merge fixtures | pass |
| staged model config validation | pass |
| MetaEditor compile | 0 errors, 0 warnings |
| Strategy Tester logger OFF/ON parity | pass |
| Final OOS | sealed |

## Strategy Tester parity result

Date completed: `2026-07-24`

| Item | Folder 45: logger OFF | Folder 46: logger ON |
| --- | ---: | ---: |
| Period | 2026.01.04-2026.01.10 | 2026.01.04-2026.01.10 |
| History quality | 100% real ticks | 100% real ticks |
| Bars / ticks | 6,894 / 1,789,942 | 6,894 / 1,789,942 |
| Total net profit | 227.29 | 227.29 |
| Profit factor | 2.09 | 2.09 |
| Total trades / deals | 84 / 168 | 84 / 168 |
| Balance DD maximal | 49.52 (1.18%) | 49.52 (1.18%) |
| Equity DD maximal | 118.00 (2.84%) | 118.00 (2.84%) |

The 168 order rows and all 168 trading deal rows are exactly equal. The deal table also contains
one identical initial-balance row. The only setting differences are the intended logger enable
flag and run ID. Both saved tester presets match the issued presets value-for-value.

Report evidence remains outside Git:

- folder 45 report SHA-256:
  `A9011900682FF43CCA09B9C887D1C881CC5634F3CA5BF74474C30D051C1EE292`
- folder 46 report SHA-256:
  `DF3668969A27D93BA208AED56C6919BED9B6BCC0339B65BDB9D4FEB587CB979C`

## Schema v3 smoke audit

Run ID:
`folder32_cci3_v1_entry_v3_parity_on_20260104_20260110_r01`

| File | Rows | Columns where applicable |
| --- | ---: | ---: |
| `candidate_setups.csv` | 38 | 128 |
| `trade_entries.csv` | 38 | 21 |
| `trade_outcomes.csv` | 38 | 18 |
| `cycle_outcomes.csv` | 38 | 13 |
| `barrier_outcomes.csv` | 76 | 12 |

- Journal summary reports `DataErrors=0`.
- No malformed rows, duplicate candidate IDs, orphan relations, or missing candidate-to-outcome
  relations were found.
- Every candidate has one entry, one trade outcome, one cycle outcome, and both barrier horizons.
- All 38 legacy candidate rows match the earlier schema-v2 collection over all 94 comparable
  non-run-metadata columns.
- `FeatureReady`, `FeatureReadyV2`, `StructureReady`, and `SessionDistanceReady` are true for all
  38 candidates.
- `FeatureReadyV3` is true for 37 of 38 candidates (97.37%).
- The excluded candidate at `2026.01.09 18:24:00` is a SELL for which the bounded dynamic
  structure scan cannot find both a confirmed support below price and resistance above price.
  Its structure fields are `NA` and the audit excludes it by contract; no silent imputation is
  used.
- Every populated v3 numeric value is finite. No v3 feature is wholly missing or constant across
  the retained smoke-test rows.

Business labels in this short parity window are 17 `NO_RECOVERY`, 19 `RECOVERY_L1_L3`, and
2 `RECOVERY_L4_PLUS`. These counts validate logging only and are not a model-performance result.

## Decision and next run

Accept schema v3 for full development-data collection. The single structure-boundary exclusion is
expected under the declared readiness contract and will be measured again over the two complete
periods. Use the exact retained build and folder32 CCI-validity-3 preset; do not use locally
modified `Inputs.mqh` defaults as the experiment definition.
