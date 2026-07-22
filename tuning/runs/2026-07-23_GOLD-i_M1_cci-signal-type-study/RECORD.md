# CCI Signal Type Study — Planned Batch

## Objective

Mengukur normal dan strong CCI secara terpisah untuk menentukan tipe mana yang menyebabkan original
loss, recovery entry, dan recovery L4+ paling besar. Batch belum dijalankan.

## Fixed test environment

Gunakan environment yang sama dengan folder 5:

| Field | Value |
| --- | --- |
| Symbol/timeframe | GOLD.i# M1 |
| Period | 2026-01-04 sampai 2026-05-02 |
| Tick model | 99% real ticks |
| Deposit/leverage | $4,000 / 1:500 |
| Base preset | `%USERPROFILE%\Downloads\Backtest-1\5\backtest-5.set` |
| CCI validity | 3 |
| ADX | Disabled |
| Recovery max levels | 10 |

Load preset folder 5 sebelum setiap run. Jangan mengandalkan source defaults karena beberapa
default lokal berbeda dari preset penelitian.

## Scenario map

| External folder | `InpCciSignalMode` | Purpose |
| ---: | --- | --- |
| 10 | `CCI_SIGNAL_MODE_BOTH` | Backward-compatibility control dan telemetry kedua tipe |
| 11 | `CCI_SIGNAL_MODE_NORMAL_ONLY` | Mengisolasi normal Buy/Sell |
| 12 | `CCI_SIGNAL_MODE_STRONG_ONLY` | Mengisolasi StrongBuy/StrongSell |

Ubah hanya `InpCciSignalMode`. Simpan preset masing-masing sebagai `backtest-10.set`,
`backtest-11.set`, dan `backtest-12.set`.

## Telemetry contract

- Original normal: comment `orderBuy [CCI:N]` atau `orderSell [CCI:N]`.
- Original strong: comment `orderBuy [CCI:S]` atau `orderSell [CCI:S]`.
- Recovery tetap menggunakan tag `[REC]` dan tidak berubah.
- Journal mencatat mode saat init serta tipe dan timestamp saat original order dieksekusi.

## Acceptance criteria

Kandidat harus dibandingkan dengan folder 10, bukan hanya berdasarkan net profit:

| Metric | Initial target |
| --- | ---: |
| Original win rate | > 42% |
| Recovery entry rate | < 57% |
| Recovery level 4+ | < 13% |
| Active weekday coverage | >= 80% |
| Stop-out / forced liquidation | 0 |
| Relative equity DD | Lebih rendah dari control |

Jika tidak ada single mode yang memenuhi target, gunakan breakdown folder 10 untuk menentukan
apakah masalah berasal dari tipe CCI atau dari freshness/context setelah sinyal muncul.

## Results

Pending Strategy Tester folders 10–12. MetaEditor build 5833 compiled the implementation with
0 errors and 0 warnings before the batch.
