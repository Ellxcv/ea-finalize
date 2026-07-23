# CCI Stale Breakout Confirmation Study — Planned Run

## Objective

Meningkatkan original entry win rate dan menurunkan kemungkinan recovery dimulai, tanpa membatasi
semua entry pada CCI age 1 yang terlalu jarang.

## Diagnostic basis

Telemetry folder 15 memetakan seluruh 594 original cycle pada validity 3:

| CCI signal age | Original cycles | Original WR | Recovery rate | Recovery L4+ |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 34 | 52.94% | 47.06% | 6.25% |
| 2 | 284 | 37.68% | 61.62% | 16.57% |
| 3 | 276 | 40.94% | 58.33% | 14.29% |

Age 1 paling menjanjikan tetapi sample kecil dan tidak cukup aktif jika digunakan sendirian. Age
2–3 tetap dipertahankan sebagai setup, tetapi memerlukan bukti follow-through dari closed price.

## Scenario map

| External folder | Variant | Changed input |
| ---: | --- | --- |
| 5, existing | Validity-3 control | `InpEnableCciStaleBreakoutConfirm=false` equivalent |
| 16 | Stale signal breakout | `InpEnableCciStaleBreakoutConfirm=true` |

## Fixed configuration

Load `%USERPROFILE%\Downloads\Backtest-1\5\backtest-5.set`, lalu pastikan:

```text
InpCciSignalValidityBars             = 3
InpCciSignalMode                     = CCI_SIGNAL_MODE_BOTH
InpEnableCciStaleBreakoutConfirm     = true
InpEnableAdxFilter                   = false
InpRecoveryGridMaxLevels             = 10
```

Ubah hanya stale breakout confirmation. Pertahankan GOLD.i# M1, 2026-01-04 sampai 2026-05-02,
deposit $4,000, leverage 1:500, dan real ticks yang sama. Simpan sebagai `backtest-16.set`.

## Rule contract

```text
CCI age 1 BUY/SELL = unchanged

CCI age 2–3 BUY  = Close[1] > High[signal candle]
CCI age 2–3 SELL = Close[1] < Low[signal candle]
```

- hanya candidate yang sudah lolos existing trend filters dan memiliki slot posisi yang diperiksa;
- stale signal yang belum confirmed tetap menunggu selama masih berada dalam validity 3;
- signal yang tidak confirmed sampai validity habis tidak dieksekusi;
- data candle yang unavailable memblokir entry sementara;
- recovery tidak menggunakan filter ini;
- journal merangkum fresh allowed, stale confirmed BUY/SELL, waiting BUY/SELL, dan data errors.

## Acceptance criteria

| Metric | Target |
| --- | ---: |
| Original win rate | > 42% |
| Recovery entry rate | < 57% |
| Recovery level 4+ | < 13% |
| Active weekday coverage | >= 80% |
| Maximum recovery depth | < 10 |
| Relative equity DD | < 25% |
| Stop-out / forced liquidation | 0 |

## Decision gate

Jika kualitas naik tetapi daily coverage jatuh di bawah 80%, jangan melonggarkan breakout secara
acak. Analisis breakdown fresh versus stale-confirmed lebih dahulu. Jika original WR dan recovery
rate tidak membaik, hentikan CCI timing filters dan lanjutkan diagnosis original exit/MFE/MAE.

## Results

Pending Strategy Tester folder 16.
