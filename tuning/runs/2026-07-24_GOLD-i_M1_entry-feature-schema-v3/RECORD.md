# Entry Feature Schema v3 Implementation

## Status

`IMPLEMENTED - COMPILED - AUTOMATED CONTRACT TESTED - TESTER PARITY PENDING`

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
| Strategy Tester logger OFF/ON parity | pending |
| Final OOS | sealed |

## Next run

Use the exact folder32 CCI-validity-3 trading preset for both parity runs. Only logger metadata may
differ. Do not use the locally modified `Inputs.mqh` defaults as the experiment definition.
