# Trend-Freshness Diagnostics — Folder 22

## Tujuan

Menguji apakah recovery L4+ berasal dari trend alignment yang sudah terlalu lama atau mulai
melemah saat original entry dibuka. Run ini observation-only dan tidak menambahkan entry filter.

## Control

Gunakan seluruh konfigurasi dan periode folder 21 tanpa perubahan:

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

Tidak ada input baru. Gunakan build dari branch `feature/trend-freshness-diagnostics` dan simpan
hasil sebagai folder `22`.

## Feature definitions

Trend age menghitung jumlah bar closed berturut-turut sejak state indikator terakhir berubah.
Nilai positif berarti state saat entry searah posisi, nilai negatif berarti berlawanan, dan nol
berarti source tidak aktif atau gagal dibaca. Nilai absolut dibatasi maksimum 200; nilai 200
berarti 200 bar atau lebih.

| Field | Definition |
| --- | --- |
| `HiLoAgeBars` | Signed age HiLo pada M1 |
| `PsarAgeBars` | Signed age PSAR pada timeframe main PSAR |
| `SuperTrendAgeBars` | Signed age SuperTrend pada timeframe main SuperTrend |
| `STMTFAgeBars` | Signed age SuperTrend MTF dalam satuan bar timeframe MTF |
| `EMASlope5ATR` | Direction × `(EMA50[1]-EMA50[6])/ATR14[1]` |
| `EMASlope10ATR` | Direction × `(EMA50[1]-EMA50[11])/ATR14[1]` |
| `TrendContextReady` | Semua source aktif tersedia dan valid |

Slope positif berarti EMA bergerak searah posisi; slope negatif berarti EMA bergerak melawan
posisi. Summary journal menambahkan `TrendContextErrors`.

## Acceptance check

Karena hanya menambah telemetry, folder 22 harus mereproduksi folder 21:

| Metric | Folder 21 control | Folder 22 |
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
| Data / context / trend-context errors | 0 / 0 / 0 | Pending |
| Active records remaining | 0 | Pending |

Report history folder 21 dan 22 harus identik. Jika berubah, feature tidak boleh dipakai untuk
memilih filter.

## Analysis plan

Pasangkan setiap `TS7_ORIGINAL_OPEN` dengan hasil original dan maximum recovery depth:

1. 282 original winner;
2. 259 recovery L1-L3;
3. 53 recovery L4+.

Bandingkan median, interquartile range, overlap, dan separation score untuk setiap feature.
Screen threshold rendah dan tinggi. Kandidat hanya diteruskan bila:

- menolak minimal 20% L4+;
- menolak maksimal 10% winner;
- tetap memenuhi dua syarat tersebut pada Januari-Februari dan Maret-Mei secara terpisah.

Threshold yang lolos tetap harus diimplementasikan default-off dan diuji melalui full Strategy
Tester karena penolakan entry akan mengubah urutan trade.

## Status

Pending backtest folder 22. Raw report dan journal tidak boleh di-commit.
