# Recovery Hard Abort Before Level

## Status

`IMPLEMENTED - DEFAULT OFF - STRATEGY TESTER PENDING`

## Hypothesis

When a GRID recovery cycle reaches the trigger for a configured failure level, do not open that
level. Close only the active `[REC]` basket, record a failed completion reason, and use the
existing recovery cooldown before normal entries resume.

Example:

```text
InpRecoveryAbortBeforeLevel = 4
```

L1-L3 may open. When the L4 entry condition becomes true, L4 is not opened and the existing
recovery basket is closed.

## Scope and safety

- Applies only to `RECOVERY_MODE_GRID`.
- Default is `0` (disabled), preserving prior trading behavior.
- Requires a value of `0` or at least `2`.
- `InpRecoveryGridMaxLevels` must reach the abort level; nonzero
  `InpMaxRecoverySteps` and `InpMaxRecoveryPositions` must not be lower than it.
- Does not close unrelated original strategy positions.
- Deletes recovery pending orders and closes positions identified by the `[REC]` tag.
- Cleanup is fail-closed: if any recovery exposure remains, the EA retries and cannot open the
  blocked level.
- Cycle telemetry uses completion reason `HARD_ABORT_BEFORE_LEVEL`.
- Existing `InpRecoveryCooldownBars` applies after a successful abort cleanup.

`BusinessOutcome` remains the observed maximum opened depth. For an abort before L4 it is normally
`RECOVERY_L1_L3`; the completion reason is the explicit failure label.

## Historical counterfactual

The estimate reconstructed all 101 L4+ cycles from folders 47-48 and closed L1-L3 at the observed
L4 trigger. It is not a replacement for Strategy Tester because later path changes, spread, and
slippage require a new run.

| Result | Actual | Abort before L4, no spread | Abort with 0.20 price spread |
| --- | ---: | ---: | ---: |
| Folder 47 net | 2,843.47 | 36.02 | -17.98 |
| Folder 48 net | 4,171.15 | -147.51 | -214.71 |
| Combined net | 7,014.62 | -111.49 | -232.69 |

This feature is an experimental capital-protection control, not an expected profit improvement.

## Required test

First run a short behavior test on `GOLD.i#`, M1, real ticks, 2026.01.04-2026.01.10:

```text
InpRecoveryAbortBeforeLevel = 4
InpRecoveryCooldownBars      = 0
```

Confirm:

- journal contains `RECOVERY_HARD_ABORT_TRIGGER` and `RECOVERY_HARD_ABORT_COMPLETE`;
- no recovery order tagged `[REC]` opens at L4;
- completion reason is `HARD_ABORT_BEFORE_LEVEL`;
- no orphan recovery positions or pending orders remain.

Only after the short behavior test passes should folders 47-48 be repeated with the abort enabled.

## Reproducible artifacts

- Source revision: `bff7a8ccbc90845aabd2bb65f38b9473fca1df89`
- Exact-commit compile: `0 errors, 0 warnings`
- Strategy preset:
  `presets/folder32-cci3-recovery-abort-l4-strategy.set`
- Observation logger preset:
  `presets/folder32-cci3-recovery-abort-l4-observation-on.set`
- Strategy preset SHA-256:
  `D5DC9DAAAEABE0242169811A560D237D9A4E4514F4B55BE7B656B76BB6133214`

The observation preset keeps the folder32 CCI-validity-3 baseline and enables the ML dataset
logger. Its only intentional strategy change is `InpRecoveryAbortBeforeLevel=4`.
