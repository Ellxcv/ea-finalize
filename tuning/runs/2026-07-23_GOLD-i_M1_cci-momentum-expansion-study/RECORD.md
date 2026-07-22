# CCI Momentum Expansion Study — Planned Run

## Objective

Mempertahankan peluang CCI validity 3 sambil menolak crossover lama yang masih aligned tetapi
momentumnya sudah melemah.

## Hypothesis

Current alignment biasa hampir tidak mengubah hasil karena CCI tetap berada pada sisi CI yang sama
sampai opposite cross. Delta expansion menambahkan informasi baru: jarak CCI terhadap CI harus
sedang melebar ke arah entry pada closed bar terbaru.

## Scenario map

| External folder | Variant | Changed input |
| ---: | --- | --- |
| 5, existing | Control validity 3 | `InpCciRequireMomentumExpansion=false` equivalent |
| 13 | CCI delta expansion | `InpCciRequireMomentumExpansion=true` |

## Fixed configuration

Load `%USERPROFILE%\Downloads\Backtest-1\5\backtest-5.set`, lalu pastikan:

```text
InpCciSignalValidityBars          = 3
InpCciSignalMode                  = CCI_SIGNAL_MODE_BOTH
InpCciRequireMomentumExpansion    = true
InpEnableAdxFilter                = false
InpRecoveryGridMaxLevels          = 10
```

Ubah hanya input momentum expansion. Pertahankan GOLD.i# M1, 2026-01-04 sampai 2026-05-02,
deposit $4,000, leverage 1:500, dan real ticks yang sama. Simpan sebagai `backtest-13.set`.

## Rule contract

```text
DELTA = CCI - CI
BUY   = DELTA bar 1 > 0 dan DELTA bar 1 > DELTA bar 2
SELL  = DELTA bar 1 < 0 dan DELTA bar 1 < DELTA bar 2
```

- CCI memakai custom indicator buffer 0 dan CI buffer 3;
- bar 1 dan bar 2 adalah dua closed bars terakhir;
- kegagalan membaca buffer memblokir entry secara aman;
- rejected candidate dicatat dengan signal type, timestamp, Delta1, dan Delta2;
- mode default OFF tidak mengubah existing preset.

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

## Decision gate

Ini adalah eksperimen CCI terakhir. Jika target kualitas tidak tercapai atau daily coverage rusak,
hentikan tuning CCI dan pindah ke impulse serta recovery-risk guard.

## Results

Pending Strategy Tester folder 13.
