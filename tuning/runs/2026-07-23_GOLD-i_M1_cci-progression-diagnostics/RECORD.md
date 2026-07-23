# CCI Progression Diagnostics — Folder 23

## Tujuan

Menguji apakah momentum CCI berubah atau kehilangan cross setelah candle signal tetapi sebelum
original entry dibuka. Run ini observation-only dan tidak menambahkan entry filter.

## Control

Gunakan seluruh konfigurasi dan periode folder 22 tanpa perubahan:

- symbol `GOLD.i#`, timeframe `M1`;
- periode 2026-01-04 sampai 2026-05-02;
- CCI validity 3 dan CCI signal mode BOTH;
- HiLo, PSAR, SuperTrend M1, dan SuperTrend MTF M5 aktif;
- ADX filter false;
- trailing start/step/distance 500;
- `InpTrailingBreakEvenOffsetPoints=50`;
- original diagnostics true;
- ATR diagnostics 14 dan EMA diagnostics 50;
- seluruh session, lot, dan recovery setting sama.

Tidak ada input baru. Gunakan build dari branch `feature/cci-progression-diagnostics` dan simpan
hasil sebagai folder `23`.

## CCI dependency audit

EA membaca custom indicator `cciCustomFix\cciCustomFix`:

| Buffer | Meaning |
| ---: | --- |
| 0 | Raw CCI |
| 3 | Smoothed CI |
| 4-7 | Strong buy, buy, strong sell, dan sell markers |

Dependency yang dipakai pada implementasi ini:

| File | SHA-256 |
| --- | --- |
| `cciCustomFix.mq5` | `E2139B9E14CB209758BBD312EACC5EFE7616D3B37B3D597253839EC679E497EE` |
| `cciCustomFix.ex5` | `A2A2E46623D8E436E3E9BF51094824EE0FD4753549F1AF06838D557A3EF2E734` |

Source eksternal yang terpasang memiliki ekspresi cross yang membandingkan setiap buffer dengan
dirinya sendiri, sedangkan EX5 yang dipakai Strategy Tester menghasilkan signal. Ini menunjukkan
source dan binary kemungkinan tidak sinkron. Jangan compile ulang atau mempublikasikan dependency
tersebut sebelum source, binary, dan lisensinya direkonsiliasi. Telemetry folder 23 membaca handle
EX5 yang sama dengan aturan entry sehingga tetap konsisten dengan run sebelumnya.

## Feature definitions

| Field | Definition |
| --- | --- |
| `CCISignal` | Raw CCI pada candle signal |
| `CISignal` | Smoothed CI pada candle signal |
| `CCIEntry` | Raw CCI pada bar closed terakhir sebelum entry |
| `CIEntry` | Smoothed CI pada bar closed terakhir sebelum entry |
| `CCITriggerMagnitude` | `-Direction × CCISignal`; besar kondisi oversold/overbought signal |
| `CCIDeltaDir` | `Direction × (CCIEntry-CCISignal)` |
| `CCIGapSignalDir` | `Direction × (CCISignal-CISignal)` |
| `CCIGapEntryDir` | `Direction × (CCIEntry-CIEntry)` |
| `CCIMomentumHeld` | `CCIGapEntryDir > 0` |
| `CCIContextReady` | Seluruh buffer signal dan entry tersedia serta valid |

`CCIDeltaDir` positif berarti CCI bergerak searah posisi setelah signal. Gap positif berarti raw
CCI masih berada pada sisi CI yang mendukung arah entry. Untuk `CCITriggerMagnitude`, nilai normal
umumnya 0-100 dan strong umumnya lebih dari 100.

## Acceptance check

Karena hanya menambah telemetry, folder 23 harus mereproduksi folder 22:

| Metric | Folder 22 control | Folder 23 |
| --- | ---: | ---: |
| Original closed | 594 | 594 |
| Winner / loser / neutral | 282 / 312 / 0 | 282 / 312 / 0 |
| Original win rate | 47.47% | 47.47% |
| Recovery entry rate | 52.53% | 52.53% |
| Recovery L4+ absolute | 53 | 53 |
| Total trades / deals | 1,343 / 2,686 | 1,343 / 2,686 |
| Total net profit | $3,427.74 | $3,427.74 |
| Profit factor | 1.52 | 1.52 |
| Relative equity DD | 31.88% | 31.88% |
| Active weekdays | 84/85 | 84/85 |
| Data / context / trend / CCI errors | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |
| Active records remaining | 0 | 0 |

Preset dan seluruh report history folder 22 dan 23 harus identik. Jika berubah, feature tidak boleh
dipakai untuk memilih filter.

Folder 23 diterima sebagai reproduction yang bersih. Preset folder 22 dan 23 identik, seluruh
5,381 report-history rows sama, terdapat 594 pasangan original OPEN/CLOSE, dan seluruh record
memiliki `CCIContextReady=true`.

## Analysis plan

Pasangkan setiap `TS7_ORIGINAL_OPEN` dengan hasil original dan maximum recovery depth:

1. 282 original winner;
2. 259 recovery L1-L3;
3. 53 recovery L4+.

Bandingkan distribusi seluruh feature serta proporsi `CCIMomentumHeld`. Screen threshold rendah dan
tinggi, termasuk pemeriksaan terpisah menurut signal age dan signal type bila sample mencukupi.
Kandidat hanya diteruskan bila:

- menolak minimal 20% L4+;
- menolak maksimal 10% winner;
- tetap memenuhi dua syarat tersebut pada Januari-Februari dan Maret-Mei secara terpisah.

Threshold yang lolos tetap harus diimplementasikan default-off dan diuji melalui full Strategy
Tester karena penolakan entry akan mengubah urutan trade.

## Results

Recovery loser tetap terbagi menjadi 259 cycle L1-L3 dan 53 cycle L4+. `CCIMomentumHeld=true`
pada 593 dari 594 entry. Satu-satunya cross yang tidak bertahan berakhir pada recovery L1-L3.
Hilangnya cross sebelum entry bukan penjelasan deep recovery.

Median dan interquartile range feature direction-normalized:

| Feature | Winner, n=282 | Recovery L1-L3, n=259 | Recovery L4+, n=53 |
| --- | ---: | ---: | ---: |
| `CCITriggerMagnitude` | 37.011 (18.661-69.577) | 36.268 (21.056-66.618) | 43.668 (25.085-72.162) |
| `CCIDeltaDir` | 136.678 (96.405-183.938) | 129.036 (87.921-175.397) | 126.427 (84.156-191.199) |
| `CCIGapSignalDir` | 19.896 (9.723-36.220) | 19.249 (9.309-35.111) | 15.092 (6.607-30.993) |
| `CCIGapEntryDir` | 99.385 (76.085-124.013) | 95.221 (68.663-123.729) | 92.936 (61.279-134.011) |

AUC seluruh raw dan derived feature hanya 0.515-0.562. Satu raw threshold,
`CCISignal <= -76.047`, memenuhi screen pada seluruh periode tetapi gagal pada time split dan
hanya memilih sisi BUY, sehingga tidak diteruskan.

## Overshoot candidate

Screening dua kondisi menemukan pola yang konsisten secara waktu:

~~~text
CITriggerMagnitude = -Direction × CISignal
CCIEntryDirectional = Direction × CCIEntry

Reject jika CITriggerMagnitude >= 80
       dan CCIEntryDirectional >= 110
~~~

Interpretasi: smoothed CI masih berada minimal 80 points di sisi counter-direction ketika signal,
tetapi raw CCI sudah melesat minimal 110 points ke arah posisi ketika entry akhirnya dilakukan.
Ini merupakan late reversal chase atau overshoot, bukan momentum yang hilang.

| Split | L4+ ditolak | Winner ditolak | L1-L3 ditolak |
| --- | ---: | ---: | ---: |
| Jan-Feb | 6/28 (21.4%) | 12/124 (9.7%) | 10/126 (7.9%) |
| Mar-May | 6/25 (24.0%) | 15/158 (9.5%) | 15/133 (11.3%) |
| Full | 12/53 (22.6%) | 27/282 (9.6%) | 25/259 (9.7%) |

Pola ini direction-asymmetric:

| Side | L4+ ditolak | Winner ditolak | L1-L3 ditolak |
| --- | ---: | ---: | ---: |
| BUY | 11/33 (33.3%) | 16/166 (9.6%) | 15/151 (9.9%) |
| SELL | 1/20 (5.0%) | 11/116 (9.5%) | 10/108 (9.3%) |

Komponen SELL tidak memberi separation yang layak. BUY-only memiliki precision lebih baik, tetapi
pada denominator seluruh L4+ bagian Jan-Feb hanya menangkap 5/28 (17.9%). Karena sample L4+ kecil
dan hanya satu kombinasi threshold bulat yang lolos screen symmetric, kandidat ini dianggap
provisional dan berisiko in-sample overfit.

## Verdict

Jangan langsung menetapkan rule sebagai filter final. Implementasikan guard configurable,
default-off, dengan pilihan BUY_ONLY dan BOTH. Gunakan threshold tetap 80/110 tanpa tuning lanjutan
pada periode ini:

1. folder 24: BUY_ONLY;
2. folder 25: BOTH.

Kedua run memakai folder 23 sebagai control. Kandidat hanya diteruskan bila Strategy Tester
menunjukkan original WR/recovery membaik, L4+ absolut turun, active weekdays tetap minimal 80%,
serta net profit, profit factor, dan drawdown tidak memburuk material. Setelah memilih paling
banyak satu variant, lakukan out-of-sample karena threshold ditemukan dari periode ini.

## Status

Completed and accepted. Raw report dan journal tidak di-commit.
