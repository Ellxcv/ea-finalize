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
| Data / context / trend-context errors | 0 / 0 / 0 | 0 / 0 / 0 |
| Active records remaining | 0 | 0 |

Report history folder 21 dan 22 harus identik. Jika berubah, feature tidak boleh dipakai untuk
memilih filter.

Folder 22 diterima sebagai reproduction yang bersih. Preset folder 21 dan 22 identik, seluruh
5,381 baris report history sama, terdapat 594 pasangan original OPEN/CLOSE, dan seluruh record
memiliki `TrendContextReady=true`.

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

## Results

Recovery loser tetap terbagi menjadi 259 cycle L1-L3 dan 53 cycle L4+. Distribusi feature berikut
menunjukkan median dan interquartile range.

| Feature | Winner, n=282 | Recovery L1-L3, n=259 | Recovery L4+, n=53 |
| --- | ---: | ---: | ---: |
| `HiLoAgeBars` | 1 (1-1) | 1 (1-1) | 1 (1-1) |
| `PsarAgeBars` | 1 (1-2) | 2 (1-2) | 2 (1-2) |
| `SuperTrendAgeBars` | 2 (1-23) | 1 (1-21) | 1 (1-18) |
| `STMTFAgeBars` | 9 (5-17) | 9 (4-18) | 9 (5-19) |
| `EMASlope5ATR` | 0.128 (-0.014-0.294) | 0.147 (-0.026-0.284) | 0.174 (-0.002-0.312) |
| `EMASlope10ATR` | 0.363 (0.008-0.687) | 0.365 (0.031-0.683) | 0.483 (0.017-0.731) |

Seluruh trend age bernilai positif. Ini mengonfirmasi bahwa empat filter memang searah posisi saat
entry. Namun, freshness-nya hampir sama pada semua outcome. HiLo paling sering baru berubah satu
bar, PSAR satu sampai dua bar, dan SuperTrend MTF memiliki median sembilan bar pada ketiga grup.
EMA slope kelompok L4+ justru sedikit lebih positif, bukan lebih lemah.

Kemampuan pemisahan L4+ versus winner tetap dekat tebakan acak:

| Feature | AUC tanpa arah |
| --- | ---: |
| `HiLoAgeBars` | 0.535 |
| `PsarAgeBars` | 0.565 |
| `SuperTrendAgeBars` | 0.547 |
| `STMTFAgeBars` | 0.537 |
| `EMASlope5ATR` | 0.525 |
| `EMASlope10ATR` | 0.535 |

Tidak ada threshold yang mencapai target menolak minimal 20% L4+ dengan maksimal 10% winner.
Berikut hasil terbaik ketika winner yang ditolak dibatasi maksimal 10%.

| Rule observasi | L4+ ditolak | Winner ditolak | L1-L3 ditolak |
| --- | ---: | ---: | ---: |
| `HiLoAgeBars >= 17` | 1/53 (1.9%) | 6/282 (2.1%) | 7/259 (2.7%) |
| `PsarAgeBars >= 4` | 5/53 (9.4%) | 20/282 (7.1%) | 24/259 (9.3%) |
| `SuperTrendAgeBars >= 43` | 6/53 (11.3%) | 26/282 (9.2%) | 20/259 (7.7%) |
| `STMTFAgeBars >= 38` | 3/53 (5.7%) | 17/282 (6.0%) | 21/259 (8.1%) |
| `EMASlope5ATR >= 0.448` | 6/53 (11.3%) | 24/282 (8.5%) | 25/259 (9.7%) |
| `EMASlope10ATR >= 0.985` | 7/53 (13.2%) | 28/282 (9.9%) | 31/259 (12.0%) |

Pemeriksaan Januari-Februari versus Maret-Mei tidak menghasilkan threshold yang lolos pada kedua
bagian waktu. Screening kombinasi dua kondisi dengan operator AND maupun OR juga tidak menemukan
kandidat stabil.

## Verdict

Jangan implementasikan entry guard berbasis trend age atau EMA slope dari run ini. Deep recovery
tidak didominasi alignment yang stale ataupun trend mean yang melemah. Memilih threshold dari
feature ini akan mengurangi winner tanpa menangkap bagian material dari 53 L4+.

Diagnosis berikutnya kembali ke sumber signal paling sensitif: ukur perubahan state CCI dari
candle signal sampai entry. Telemetry berikutnya harus menangkap nilai CCI saat signal, nilai saat
entry, perubahan direction-normalized, dan apakah momentum signal masih bertahan. Recent-range
position dan volatility regime disimpan sebagai hipotesis setelah CCI progression.

## Status

Completed and accepted. Raw report dan journal tidak di-commit.
