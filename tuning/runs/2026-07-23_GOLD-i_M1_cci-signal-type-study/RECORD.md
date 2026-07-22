# CCI Signal Type Study

## Objective

Mengukur normal dan strong CCI secara terpisah untuk menentukan tipe mana yang menyebabkan original
loss, recovery entry, dan recovery L4+ paling besar.

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

MetaEditor build 5833 compiled the implementation with 0 errors dan 0 warnings sebelum batch.

### Overall comparison

| Metric | Folder 5 BOTH | Folder 10 NORMAL | Folder 11 STRONG |
| --- | ---: | ---: | ---: |
| Net profit | $3,472.01 | $3,382.09 | $180.72 |
| Profit factor | 1.53 | 1.50 | 1.94 |
| Expected payoff | $2.50 | $2.49 | $2.70 |
| MT5 trades | 1,391 | 1,359 | 67 |
| Sharpe ratio | 3.80 | 3.74 | 18.43 |
| Maximum equity DD | $1,608.22 | $1,608.22 | $229.93 |
| Relative equity DD | 31.85% | 31.94% | 5.50% |

Sharpe folder 11 tidak boleh dibaca sebagai bukti robustness karena hanya memiliki 30 original
cycle dan 22 hari aktif.

### Original and recovery comparison

| Metric | Folder 5 BOTH | Folder 10 NORMAL | Folder 11 STRONG |
| --- | ---: | ---: | ---: |
| Original cycles | 594 | 574 | 30 |
| Original win rate | 40.07% | 39.55% | 43.33% |
| Recovery entry rate | 59.26% | 59.93% | 53.33% |
| Net-positive recovery cycles | 97.44% | 97.38% | 100.00% |
| Recovery <= level 2 | 68.47% | 68.60% | 62.50% |
| Recovery <= level 3 | 84.94% | 84.01% | 93.75% |
| Recovery level 4+ | 15.06% | 15.99% | 6.25% |
| Maximum recovery depth | 10 | 10 | 6 |

Normal-only mengulang kelima cycle L10 control pada 2026-01-23, 2026-01-27, 2026-04-06,
2026-04-24, dan 2026-05-01. Pemisahan tipe tidak mengurangi tail risk pada sumber sinyal yang
memberi aktivitas harian.

### Daily consistency

| Metric | Folder 5 BOTH | Folder 10 NORMAL | Folder 11 STRONG |
| --- | ---: | ---: | ---: |
| Active weekdays | 84/85 | 84/85 | 22/85 |
| Positive realized-P/L days | 84 | 84 | 22 |
| Losing realized-P/L days | 0 | 0 | 0 |
| No-trade weekdays | 1 | 1 | 63 |
| Longest no-trade streak | 1 | 1 | 16 |
| Average active-day P/L | $41.33 | $40.26 | $8.21 |
| Median active-day P/L | $36.83 | $35.72 | $6.25 |

### Direction breakdown

| Variant/direction | Cycle | Original WR | Recovery rate | L4+ rate |
| --- | ---: | ---: | ---: | ---: |
| Normal BUY | 337 | 38.58% | 61.42% | 16.43% |
| Normal SELL | 237 | 40.93% | 57.81% | 15.33% |
| Strong BUY | 20 | 35.00% | 60.00% | 8.33% |
| Strong SELL | 10 | 60.00% | 40.00% | 0.00% |

Strong SELL menarik sebagai hipotesis, tetapi 10 cycle terlalu kecil untuk aturan produksi atau
optimasi per arah.

## Verdict

- Folder 10: reject sebagai improvement; gunakan hanya sebagai bukti bahwa normal CCI mendominasi.
- Folder 11: reject sebagai strategy tunggal karena active-day coverage hanya 25.88%.
- Folder 5 tetap menjadi control sementara dan belum compound-ready.
- Pemisahan signal type selesai; jangan tune parameter mode CCI lebih lanjut.

## Next action

Implementasikan optional CCI freshness confirmation. Untuk signal BUY yang ditemukan pada 1–3 bar
terakhir, closed bar terbaru harus tetap memiliki CCI > CI. Untuk SELL harus tetap CCI < CI. Test
fitur tersebut terhadap folder 5 dengan ADX tetap disabled dan parameter lain tidak berubah.
