# CCI Freshness Study — Planned Run

## Objective

Mempertahankan peluang CCI validity 3 sambil menolak signal lama yang sudah kehilangan alignment
pada closed bar terbaru.

## Hypothesis

Validity 1 menghasilkan sinyal lebih berkualitas tetapi terlalu jarang, sedangkan validity 3 aktif
hampir setiap weekday namun membawa banyak recovery. Current CCI/CI alignment diperkirakan dapat
menjadi jembatan: signal berumur 1–3 bar tetap boleh masuk hanya selama arah cross masih bertahan.

## Scenario map

| External folder | Variant | Changed input |
| ---: | --- | --- |
| 5, existing | Control validity 3 | `InpCciRequireCurrentAlignment=false` equivalent |
| 12 | Current-alignment confirmation | `InpCciRequireCurrentAlignment=true` |

## Fixed configuration

Load `%USERPROFILE%\Downloads\Backtest-1\5\backtest-5.set`, lalu pastikan:

```text
InpCciSignalValidityBars         = 3
InpCciSignalMode                 = CCI_SIGNAL_MODE_BOTH
InpCciRequireCurrentAlignment    = true
InpEnableAdxFilter               = false
InpRecoveryGridMaxLevels         = 10
```

Ubah hanya input freshness. Pertahankan GOLD.i# M1, 2026-01-04 sampai 2026-05-02, deposit $4,000,
leverage 1:500, dan real ticks yang sama. Simpan preset sebagai `backtest-12.set`.

## Rule contract

- kandidat BUY dari bar 1–3 diterima hanya bila CCI bar 1 > CI bar 1;
- kandidat SELL dari bar 1–3 diterima hanya bila CCI bar 1 < CI bar 1;
- nilai diambil dari buffer CCI 0 dan CI 3 pada custom indicator;
- kegagalan membaca buffer memblokir entry secara aman;
- mode default OFF tidak mengubah perilaku existing preset.

## Acceptance criteria

| Metric | Target |
| --- | ---: |
| Original win rate | > 42% |
| Recovery entry rate | < 57% |
| Recovery level 4+ | < 13% |
| Active weekday coverage | >= 80% |
| Maximum recovery depth | < 10 preferred |
| Relative equity DD | < 25% |
| Stop-out / forced liquidation | 0 |

## Results

Pending Strategy Tester folder 12.
