# CCI Freshness Study

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

### Overall comparison

| Metric | Folder 5 control | Folder 12 freshness | Delta |
| --- | ---: | ---: | ---: |
| Net profit | $3,472.01 | $3,471.94 | -$0.07 |
| Profit factor | 1.53 | 1.53 | 0.00 |
| Expected payoff | $2.50 | $2.50 | $0.00 |
| MT5 trades | 1,391 | 1,390 | -1 |
| Sharpe ratio | 3.80 | 3.80 | 0.00 |
| Maximum equity DD | $1,608.22 | $1,608.22 | $0.00 |
| Relative equity DD | 31.85% | 31.85% | 0.00 pp |

### Original and recovery comparison

| Metric | Folder 5 control | Folder 12 freshness |
| --- | ---: | ---: |
| Original cycles | 594 | 594 |
| Original winners | 238 | 238 |
| Original losers | 352 | 351 |
| Original breakeven | 4 | 5 |
| Original win rate | 40.07% | 40.07% |
| Recovery cycles | 352 | 351 |
| Recovery entry rate | 59.26% | 59.09% |
| Recovery <= level 2 | 68.47% | 68.38% |
| Recovery <= level 3 | 84.94% | 84.90% |
| Recovery level 4+ | 15.06% | 15.10% |
| Maximum recovery depth | 10 | 10 |

Recovery depth folder 12 adalah L1=144, L2=96, L3=58, L4=25, L5=10, L6=8, L7=3,
L8=1, L9=1, dan L10=5. Seluruh lima L10 control tetap muncul pada timestamp yang sama.

### Daily consistency

| Metric | Folder 5 control | Folder 12 freshness |
| --- | ---: | ---: |
| Active weekdays | 84/85 | 84/85 |
| Positive realized-P/L days | 84 | 84 |
| No-trade weekdays | 1 | 1 |
| Average active-day P/L | $41.33 | $41.33 |
| Median active-day P/L | $36.83 | $36.83 |
| Recovery carried overnight | 5 | 5 |

### Exact behavior change

Kedua run memiliki 594 original cycle. Satu-satunya perubahan entry adalah:

- control membuka BUY 2026-03-11 16:26, loss -$0.06, lalu recovery L1 menutup cycle sekitar +$0.07;
- freshness menolak entry tersebut dan membuka BUY 16:27, lalu posisi selesai breakeven tanpa recovery.

Tidak ada deep recovery yang ditolak. Perbedaan net profit total hanya -$0.07.

## Verdict

- Reject sebagai improvement: seluruh acceptance criteria kualitas gagal.
- Current alignment hampir redundan karena setelah sebuah crossover BUY, CCI secara definisi tetap
  di atas CI sampai cross berlawanan; hal yang sama berlaku untuk SELL.
- Jangan menjadikan freshness ON sebagai baseline.
- Folder 5 tetap control sementara.

## Next hypothesis

Jika CCI diberi satu eksperimen terakhir, gunakan momentum expansion yang benar-benar membedakan
signal menguat dan melemah:

```text
CCI_DELTA = CCI - CI
BUY  : DELTA bar 1 > 0 dan DELTA bar 1 > DELTA bar 2
SELL : DELTA bar 1 < 0 dan DELTA bar 1 < DELTA bar 2
```

Berbeda dari alignment biasa, rule ini mensyaratkan jarak CCI terhadap CI sedang melebar ke arah
entry. Jika tetap tidak meningkatkan original win rate/recovery tanpa merusak daily coverage,
hentikan tuning CCI dan pindah ke impulse/risk guard.
