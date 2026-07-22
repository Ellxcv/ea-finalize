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
| 5, existing | `CCI_SIGNAL_MODE_BOTH` equivalent | Historical control sebelum tag telemetry |
| 10 | `CCI_SIGNAL_MODE_NORMAL_ONLY` | Mengisolasi normal Buy/Sell |
| 11 | `CCI_SIGNAL_MODE_STRONG_ONLY` | Mengisolasi StrongBuy/StrongSell |

Untuk folder 10 dan 11, load preset folder 5 lalu ubah hanya `InpCciSignalMode`. Simpan preset
masing-masing sebagai `backtest-10.set` dan `backtest-11.set`. Repeat BOTH dilewati untuk menghemat
waktu karena mode default mempertahankan seleksi sinyal folder 5.

## Telemetry contract

- Original normal: comment `orderBuy [CCI:N]` atau `orderSell [CCI:N]`.
- Original strong: comment `orderBuy [CCI:S]` atau `orderSell [CCI:S]`.
- Recovery tetap menggunakan tag `[REC]` dan tidak berubah.
- Journal mencatat mode saat init serta tipe dan timestamp saat original order dieksekusi.

## Acceptance criteria

Kandidat harus dibandingkan dengan folder 5, bukan hanya berdasarkan net profit:

| Metric | Initial target |
| --- | ---: |
| Original win rate | > 42% |
| Recovery entry rate | < 57% |
| Recovery level 4+ | < 13% |
| Active weekday coverage | >= 80% |
| Stop-out / forced liquidation | 0 |
| Relative equity DD | Lebih rendah dari control |

Jika tidak ada single mode yang memenuhi target, bandingkan folder 10 dan 11 untuk menentukan tipe
yang lebih berisiko. Run BOTH dengan telemetry baru hanya diperlukan kemudian jika interaksi kedua
tipe dalam satu run perlu direkonstruksi.

## Results

Pending Strategy Tester folders 10–11. MetaEditor build 5833 compiled the implementation with
0 errors and 0 warnings before the batch.
