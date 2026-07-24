# ML Entry-Candidate Schema v3

Status: **implemented, compiled, and Strategy Tester parity passed**

## Purpose

Schema v3 adds compact candidate-time context for the zero-L4 challenger without changing entry,
exit, lot, stop, trailing, or recovery decisions. The logger remains observation-only.

Schema identifier: `ts7_entry_candidate_v3`.

All values use closed candles available before the candidate order. Outcome, future price,
trade result, recovery start, and maximum recovery level remain forbidden as features.

## Contract

Schema v3 preserves all 97 columns from v2 and adds `FeatureReadyV3` plus 30 fields. Candidate
rows therefore contain 128 unique columns.

### Volatility regime

| Feature | Definition |
| --- | --- |
| `AtrRatioMean50` | current closed ATR14 / mean ATR14 over 50 closed M1 bars |
| `AtrRatioMean200` | current closed ATR14 / mean ATR14 over 200 closed M1 bars |
| `AtrPercentile200` | empirical percentile of current ATR14 within 200 closed values |
| `AtrTrend5` | mean ATR14 bars 1-5 / bars 6-10 minus one |
| `AtrTrend20` | mean ATR14 bars 1-20 / bars 21-40 minus one |
| `AtrShockRatio` | latest closed true range / mean true range of previous 20 bars |

### Trend durability

| Feature | Definition |
| --- | --- |
| `TrendAgeBars` | consecutive closed price changes aligned with candidate direction, capped at 100 |
| `DirectionalPersistence10/20` | fraction of aligned close-to-close changes |
| `TrendEfficiency10/20` | signed net displacement / total absolute price path |
| `PullbackCount20` | number of opposing close-to-close changes |
| `MaxOpposingRun20` | longest consecutive opposing run |

### Pre-entry momentum

| Feature | Definition |
| --- | --- |
| `DirectionalVelocity1/3/5` | direction-normalized displacement per bar divided by ATR |
| `VelocityAcceleration1v3` | velocity 1 minus velocity 3 |
| `VelocityAcceleration3v5` | velocity 3 minus velocity 5 |
| `DirectionalPressure10` | sum of aligned close changes / ATR |
| `OpposingPressure10` | absolute sum of opposing close changes / ATR |

### Dynamic structure

Confirmed pivots use the existing structure left/right/history inputs. The forming candle is never
used. A pivot is available only after every configured right-side confirmation candle is closed.

| Feature | Definition |
| --- | --- |
| `NearestSupportDistanceATR` | distance to nearest confirmed pivot low below price |
| `NearestResistanceDistanceATR` | distance to nearest confirmed pivot high above price |
| `DirectionalLevelRoomATR` | room to the level in trade direction |
| `OpposingLevelDistanceATR` | distance to the protective level behind the trade |
| `SupportAgeBars` / `ResistanceAgeBars` | native-timeframe age of selected pivots |
| `SupportTouchCount` / `ResistanceTouchCount` | confirmed pivots clustered within 0.15 ATR |
| `StructureWidthATR` | resistance minus support divided by ATR |
| `TrappedBetweenLevels` | structure width is at most 2 ATR |

The manifest records structure timeframe, pivot parameters, history size, touch tolerance, and
trapped-width threshold.

## Readiness

`FeatureReadyV3=true` requires:

- all v2 features ready;
- 200 valid closed ATR values;
- 202 closed M1 price bars;
- both a confirmed support below price and resistance above price.

Candidates with false readiness or `NA` required fields are excluded by the audit instead of
being imputed silently.

## Staged experiment configs

The same processed v3 dataset will be evaluated with a fixed 28-feature core and one feature
family at a time:

- `ml-phase3-zero-l4-feature-v3-core.json`
- `ml-phase3-zero-l4-feature-v3-volatility.json`
- `ml-phase3-zero-l4-feature-v3-durability.json`
- `ml-phase3-zero-l4-feature-v3-momentum.json`
- `ml-phase3-zero-l4-feature-v3-structure.json`

Only families stable across chronological folds may enter a later combined challenger.

## Required Strategy Tester validation

1. Short logger-OFF versus logger-ON parity on the same preset and period: passed.
2. Trades, deals, net profit, and drawdown: identical.
3. Candidate header: 128 columns; 37 of 38 smoke-test candidates retained as v3-ready.
4. Repeat the two existing high-quality development periods with logger ON.
5. Audit both runs together; do not open final OOS.

The one excluded smoke-test candidate had no bounded pair of confirmed support and resistance in
the configured historical scan. This is represented by `FeatureReadyV3=false` and `NA` structure
fields, then excluded rather than imputed. Full-period collection must report this exclusion rate
before model training.
