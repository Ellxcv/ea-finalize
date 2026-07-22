# Strategy Tester Record

Salin file ini menjadi RECORD.md di folder run baru. Jangan mengubah template asli untuk mencatat
satu run.

## Run identity

| Field | Value |
| --- | --- |
| Run ID | YYYY-MM-DD_SYMBOL_TIMEFRAME_variant |
| Test date | YYYY-MM-DD |
| Analyst | |
| EA commit | Output git rev-parse --short HEAD |
| EA version | |
| Variant | Baseline / experiment name |
| Hypothesis | |
| Changed parameters/rules | |

## Tester environment

| Field | Value |
| --- | --- |
| MetaTrader/MetaEditor build | |
| Broker/server | Anonymize if needed |
| Symbol | |
| Timeframe | |
| Test period | |
| Tick model | Every tick / real ticks / other |
| History quality | |
| Initial deposit | |
| Account currency | |
| Leverage | |
| Spread mode/value | |
| Commission | |
| Slippage/delay | |
| Optimization used | No / Yes, explain |
| Forward mode | |

## Dataset role

- [ ] In-sample
- [ ] Out-of-sample
- [ ] Forward/demo
- [ ] Live observation

Alasan pemilihan periode:

> Isi di sini.

## Input configuration

File preset:

> inputs.set atau N/A

Catat hanya parameter yang berbeda dari baseline:

| Parameter | Baseline | This run | Reason |
| --- | ---: | ---: | --- |
| | | | |

## Overall result

| Metric | Value |
| --- | ---: |
| Total net profit | |
| Gross profit | |
| Gross loss | |
| Profit factor | |
| Expected payoff | |
| Recovery factor | |
| Sharpe ratio | |
| Total trades | |
| Win rate | |
| Maximum balance drawdown | |
| Maximum equity drawdown | |
| Relative drawdown | |
| Longest stagnation | |
| Average holding time | |

## Original strategy result

| Metric | Value |
| --- | ---: |
| Original trades | |
| Original winners | |
| Original losers | |
| Original win rate | |
| Original net profit | |
| Original profit factor | |
| Original expectancy/trade | |
| Original average winner | |
| Original average loser | |
| Original payoff ratio | |

CCI signal breakdown bila tag tersedia:

| Signal type | Original trades | Win rate | Recovery rate | L4+ rate | Net result |
| --- | ---: | ---: | ---: | ---: | ---: |
| Normal `[CCI:N]` | | | | | |
| Strong `[CCI:S]` | | | | | |

## Recovery result

| Metric | Value |
| --- | ---: |
| Completed cycle | |
| Cycle entering recovery | |
| Recovery entry rate | |
| Recovery success rate | |
| Finished at level 1 | |
| Finished at level 2 | |
| Finished at level 3 | |
| Reached level 4+ | |
| Finished <= level 2 rate | |
| Finished <= level 3 rate | |
| Maximum recovery depth | |
| Average recovery depth | |
| Recovery net profit/loss | |
| Worst recovery-cycle drawdown | |
| Longest recovery duration | |

Recovery depth distribution:

| Depth | Cycle count | Percent | Net result |
| ---: | ---: | ---: | ---: |
| No recovery | | | |
| Level 1 | | | |
| Level 2 | | | |
| Level 3 | | | |
| Level 4+ | | | |

## Stability breakdown

| Segment | Trades | Original WR | Recovery rate | PF | Net profit | Max DD |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Period/session 1 | | | | | | |
| Period/session 2 | | | | | | |

Tambahkan breakdown bulanan, tahunan, session, arah BUY/SELL, atau regime bila tersedia.

## Compound readiness

- [ ] Original expectancy positif.
- [ ] Recovery entry rate memenuhi target.
- [ ] Mayoritas recovery selesai maksimal level 2–3.
- [ ] Drawdown memenuhi batas risiko.
- [ ] Hasil tidak bergantung pada satu periode pendek.
- [ ] Out-of-sample sudah diuji.
- [ ] Forward/demo sudah diuji.

Kesimpulan compound:

> Not ready / Candidate / Ready for limited forward test, beserta alasannya.

## Artifacts

| Artifact | File | Notes |
| --- | --- | --- |
| Tester report | | |
| Input preset | | |
| Deal history | | |
| Equity curve | | |
| Journal | | |

## Observations

Kondisi yang paling sering menyebabkan original loss:

> Isi di sini.

Kondisi yang paling sering menyebabkan recovery level 3+:

> Isi di sini.

Perubahan positif dan trade-off:

> Isi di sini.

## Verdict

- [ ] Reject
- [ ] Retest
- [ ] Candidate
- [ ] Accept as new baseline

Alasan:

> Isi di sini.

Eksperimen berikutnya:

> Ubah satu kelompok faktor dan tentukan success criterion sebelum menjalankan test.
