# Strategy Tester Record

## Run identity

| Field | Value |
| --- | --- |
| Run ID | 2026-07-22_GOLD-i_M1_default |
| Test date | 2026-07-22 |
| Analyst | User + Codex |
| EA commit | Not recorded in source report |
| EA version | testing_strat_7 default candidate |
| Variant | Default baseline |
| Hypothesis | Mengukur kualitas original strategy dan beban recovery |
| Changed parameters/rules | Tidak ada; preset backtest-1.set |

## Tester environment

| Field | Value |
| --- | --- |
| MetaTrader/MetaEditor build | Not recorded |
| Broker/server | Not recorded |
| Symbol | GOLD.i# |
| Timeframe | M1 |
| Test period | 2026-01-04 sampai 2026-06-27 |
| Tick model | Real ticks |
| History quality | 99% |
| Bars | 170,262 |
| Ticks | 47,228,485 |
| Initial deposit | $4,000.00 |
| Account currency | Assumed USD; verify |
| Leverage | 1:500 |
| Spread mode/value | Not recorded |
| Commission | $0.00 pada report deals |
| Slippage/delay | Not recorded |
| Optimization used | No indication of optimization |
| Forward mode | No |

## Dataset role

- [x] In-sample baseline
- [ ] Out-of-sample
- [ ] Forward/demo
- [ ] Live observation

Catatan integritas data:

> Broker sebelumnya memakai GOLD# dan kemudian beralih ke GOLD.i#. User mengingat live/backtest
> lama pada periode bermasalah memiliki drawdown sekitar $2,000, sedangkan report baru mencatat
> lebih dari $4,000. Hipotesis missing/discontinuous data belum terverifikasi.

## Input configuration

File preset eksternal:

> backtest-1.set

Parameter recovery yang paling relevan:

| Parameter | Value | Risk implication |
| --- | ---: | --- |
| InpEnableRecovery | true | Recovery aktif |
| InpRecoveryMode | 3 | Mode sesuai enum project; verify label |
| InpRecoveryGridMaxLevels | 10 | Mengizinkan recovery dalam |
| InpRecoveryGridLotMultiplier | 1.437 | Exposure tumbuh per level |
| InpMaxRecoverySteps | 0 | Tidak membatasi steps |
| InpMaxRecoveryLot | 0.0 | Tidak membatasi lot |
| InpRecoveryMaxDrawdown | 0.0 | Tidak membatasi DD recovery |
| InpMaxRecoveryPositions | 0 | Tidak membatasi jumlah posisi |

## Overall result

| Metric | Value |
| --- | ---: |
| Total net profit | $8,818.47 |
| Gross profit | $23,924.94 |
| Gross loss | -$15,106.47 |
| Profit factor | 1.58 |
| Expected payoff | $2.58 |
| Recovery factor | 2.14 |
| Sharpe ratio | 1.33 |
| Total trades | 3,420 |
| Report-level win rate | 54.50% |
| Maximum balance drawdown | $527.22 / 10.40% |
| Maximum equity drawdown | $4,115.14 / 90.45% |
| Equity drawdown absolute | $3,565.28 |
| Minimum reported margin level | 39.58% |

## Original strategy result

Metrik berikut direkonstruksi dari deal comment orderBuy/orderSell dan [REC].

| Metric | Value |
| --- | ---: |
| Original cycles | 1,441 |
| Original winners | 553 |
| Original losers | 871 |
| Original breakeven | 17 |
| Original win rate, seluruh cycle | 38.38% |
| Original BUY win rate | 38.29% |
| Original SELL win rate | 38.49% |

Report MT5 menampilkan win rate 54.50% karena menghitung semua trades, termasuk posisi recovery.
Angka itu bukan win rate strategy original.

## Recovery result

| Metric | Value |
| --- | ---: |
| Completed original cycles | 1,441 |
| Cycles entering recovery | 871 |
| Recovery entry rate | 60.44% |
| Recovery success rate, net-positive cycle | 98.51% |
| Finished at level 1 | 348 |
| Finished at level 2 | 254 |
| Finished at level 3 | 131 |
| Reached level 4+ | 138 |
| Finished <= level 2 rate | 69.12% |
| Finished <= level 3 rate | 84.16% |
| Reached level 4+ rate | 15.84% |
| Maximum recovery depth | 10 |
| Level-10 cycles | 8 |
| Maximum observed single recovery lot | 0.38 |

Recovery depth distribution:

| Depth | Cycle count | Percent of recovery |
| ---: | ---: | ---: |
| Level 1 | 348 | 39.95% |
| Level 2 | 254 | 29.16% |
| Level 3 | 131 | 15.04% |
| Level 4 | 67 | 7.69% |
| Level 5 | 28 | 3.21% |
| Level 6 | 16 | 1.84% |
| Level 7 | 10 | 1.15% |
| Level 8 | 7 | 0.80% |
| Level 9 | 2 | 0.23% |
| Level 10 | 8 | 0.92% |

## Stability breakdown

| Month | Original cycles | Original WR | Recovery rate | L4+ of recovery |
| --- | ---: | ---: | ---: | ---: |
| 2026-01 | 224 | 38.39% | 60.71% | 14.71% |
| 2026-02 | 262 | 38.55% | 59.92% | 16.56% |
| 2026-03 | 288 | 41.32% | 57.64% | 16.87% |
| 2026-04 | 237 | 37.55% | 60.76% | 14.58% |
| 2026-05 | 230 | 38.70% | 60.87% | 16.43% |
| 2026-06 | 200 | 34.50% | 64.00% | 15.63% |

## Extreme drawdown candidate

Cycle 2026-01-16 17:05–18:01 server time:

| Field | Value |
| --- | ---: |
| Original side/lot | BUY 0.01 |
| Original entry | 4616.35 |
| Original result | -$6.29 |
| Recovery depth | 10 |
| Maximum single lot | 0.38 |
| Cycle net result | +$0.76 |
| Balance after cycle | $4,546.86 |

Cycle ini kandidat terkuat penyebab maximum floating drawdown. Konfirmasi final memerlukan tick,
spread, dan equity timeline karena report HTML tidak menyediakan timestamp exact untuk maximum DD.

## Compound readiness

- [x] Overall expectancy positif.
- [ ] Recovery entry rate memenuhi target.
- [ ] Mayoritas recovery aman untuk target compound.
- [ ] Drawdown memenuhi batas risiko.
- [ ] Data symbol sudah diverifikasi.
- [ ] Out-of-sample sudah diuji.
- [ ] Forward/demo pembanding sudah didokumentasikan.

Kesimpulan compound:

> Not ready. Equity DD 90.45%, recovery entry rate 60.44%, dan recovery tanpa cap sampai level 10
> terlalu berisiko untuk compound walaupun balance curve dan net profit terlihat kuat.

## Artifacts

Artefak masih berada pada folder eksternal Backtest-1/1 dan belum disalin ke repository.

| Artifact | File |
| --- | --- |
| Tester report | ReportTester-1301525650.html |
| Input preset | backtest-1.set |
| Balance chart | ReportTester-1301525650.png |
| Equity/balance chart | TesterGraphReport2026.07.22.png |
| Entry/history chart | ReportTester-1301525650-hst.png |
| MFE/MAE chart | ReportTester-1301525650-mfemae.png |
| Holding chart | ReportTester-1301525650-holding.png |

## Observations

- Report-level win rate 54.50% menutupi original win rate 38.38% karena recovery dihitung sebagai
  trade terpisah.
- Sekitar 60% original cycle membutuhkan recovery.
- 84.16% recovery selesai maksimal level 3, tetapi tail risk level 4–10 menghasilkan exposure dan
  floating drawdown yang tidak cocok untuk compound.
- BUY dan SELL memiliki kualitas original yang hampir sama, sehingga tuning awal tidak cukup
  hanya menonaktifkan satu arah.
- Jam server 10, 13, dan 19 adalah kandidat diagnosis, bukan filter final.

## Verdict

- [ ] Reject
- [x] Retest
- [ ] Candidate
- [ ] Accept as new baseline

Alasan:

> Hasil profit kuat, tetapi data-integrity event Januari dan tail risk recovery harus diverifikasi
> sebelum baseline dipakai untuk memilih parameter.

Eksperimen berikutnya:

> Rerun periode 2026-01-12 sampai 2026-01-20 dengan preset identik setelah history GOLD.i#
> dibersihkan/diunduh ulang. Jika tersedia, bandingkan dengan GOLD# pada overlap yang sama.
