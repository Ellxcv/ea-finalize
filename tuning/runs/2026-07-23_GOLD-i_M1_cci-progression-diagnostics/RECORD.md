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
| Original closed | 594 | Pending |
| Winner / loser / neutral | 282 / 312 / 0 | Pending |
| Original win rate | 47.47% | Pending |
| Recovery entry rate | 52.53% | Pending |
| Recovery L4+ absolute | 53 | Pending |
| Total trades / deals | 1,343 / 2,686 | Pending |
| Total net profit | $3,427.74 | Pending |
| Profit factor | 1.52 | Pending |
| Relative equity DD | 31.88% | Pending |
| Active weekdays | 84/85 | Pending |
| Data / context / trend / CCI errors | 0 / 0 / 0 / 0 | Pending |
| Active records remaining | 0 | Pending |

Preset dan seluruh report history folder 22 dan 23 harus identik. Jika berubah, feature tidak boleh
dipakai untuk memilih filter.

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

## Status

Pending backtest folder 23. Raw report dan journal tidak boleh di-commit.
