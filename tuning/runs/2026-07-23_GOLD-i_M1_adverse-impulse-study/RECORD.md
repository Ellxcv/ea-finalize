# Adverse Impulse Guard Study — Planned Run

## Objective

Menolak original BUY setelah penurunan harga ekstrem dan original SELL setelah kenaikan ekstrem,
tanpa mengubah recovery atau menghilangkan kebutuhan daily trading activity.

## Hypothesis

Deep recovery lebih mungkin dimulai ketika original entry melawan impulse harga yang besar.
Normalisasi dengan ATR memberi ukuran yang dapat dibandingkan pada volatility regime berbeda dan
menambahkan informasi yang tidak sama dengan trend-state HiLo, PSAR, atau SuperTrend.

## Scenario map

| External folder | Variant | Changed input |
| ---: | --- | --- |
| 5, existing | Validity-3 control | `InpEnableImpulseGuard=false` equivalent |
| 14 | Adverse impulse guard | Guard ON, lookback 5, ATR 14, maximum 2.0 ATR |

## Fixed configuration

Load `%USERPROFILE%\Downloads\Backtest-1\5\backtest-5.set`, lalu pastikan:

```text
InpCciSignalValidityBars     = 3
InpCciSignalMode             = CCI_SIGNAL_MODE_BOTH
InpEnableImpulseGuard        = true
InpImpulseLookbackBars       = 5
InpImpulseAtrPeriod          = 14
InpMaxAdverseImpulseAtr      = 2.0
InpEnableAdxFilter           = false
InpRecoveryGridMaxLevels     = 10
```

Ubah hanya empat input impulse guard. Pertahankan GOLD.i# M1, 2026-01-04 sampai 2026-05-02,
deposit $4,000, leverage 1:500, dan real ticks yang sama. Simpan sebagai `backtest-14.set`.

## Rule contract

```text
LatestClose = Close[1]
OlderClose  = Close[InpImpulseLookbackBars + 1]

BUY adverse move  = max(OlderClose - LatestClose, 0)
SELL adverse move = max(LatestClose - OlderClose, 0)
Impulse ratio     = adverse move / ATR(14)[1]
BLOCK             = impulse ratio > 2.0
```

- hanya candidate yang sudah lolos konfirmasi entry lain dan memiliki slot posisi yang diperiksa;
- signal yang ditolak dianggap sudah digunakan dan memerlukan CCI signal baru untuk entry;
- kegagalan membaca ATR/close memblokir entry sementara tetapi tidak mengonsumsi signal;
- recovery tidak menggunakan impulse guard;
- journal mencatat setiap rejection serta summary checks, blocked BUY/SELL, dan data errors.

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

Jika guard hampir tidak mengubah exposure, satu retest dengan batas 1.5 ATR boleh dipertimbangkan.
Jika kualitas atau daily coverage memburuk, jangan melakukan threshold sweep; lanjutkan ke recovery
exposure guard. Spread guard baru diuji terpisah setelah adverse impulse menunjukkan manfaat.

## Results

Pending Strategy Tester folder 14.
