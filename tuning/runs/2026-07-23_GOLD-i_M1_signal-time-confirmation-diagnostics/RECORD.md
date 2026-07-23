# Signal-Time Confirmation Diagnostics — Folder 24

## Tujuan

Menguji apakah original entry terlambat karena HiLo, PSAR, SuperTrend M1, atau SuperTrend M5 baru
searah beberapa candle setelah signal CCI. Perubahan ini observation-only: tidak ada entry yang
ditolak dan tidak ada parameter trading baru.

## Control

Gunakan seluruh preset dan rentang folder 23 tanpa perubahan:

- symbol `GOLD.i#`, timeframe `M1`;
- periode 2026-01-04 sampai 2026-05-02;
- CCI validity 3 dan CCI signal mode BOTH;
- HiLo, PSAR, SuperTrend M1, dan SuperTrend MTF M5 aktif;
- ADX filter false;
- trailing start/step/distance 500;
- `InpTrailingBreakEvenOffsetPoints=50`;
- original diagnostics true;
- ATR diagnostics 14 dan EMA diagnostics 50;
- seluruh session, lot, serta recovery setting sama.

Gunakan build dari branch `feature/signal-time-confirmation-diagnostics` dan simpan report sebagai
folder `24`. Tidak ada input baru.

## Feature definitions

Setiap field `*Align` dinormalisasi terhadap arah original entry:

- `1`: indikator mendukung arah entry;
- `-1`: indikator berlawanan dengan arah entry;
- `0`: filter tidak aktif atau data tidak berhasil dibaca.

| Field | Definition |
| --- | --- |
| `HiLoSignalAlign` / `HiLoEntryAlign` | Alignment HiLo pada signal-close / entry |
| `PsarSignalAlign` / `PsarEntryAlign` | Alignment PSAR pada signal-close / entry |
| `SuperTrendSignalAlign` / `SuperTrendEntryAlign` | Alignment main SuperTrend pada signal-close / entry |
| `STMTFSignalAlign` / `STMTFEntryAlign` | Alignment SuperTrend MTF pada signal-close / entry |
| `LateConfirmMask` | Bitmask filter yang berubah dari tidak aligned menjadi aligned: HiLo=1, PSAR=2, ST=4, STMTF=8 |
| `LateConfirmCount` | Jumlah bit/filter pada `LateConfirmMask` |
| `ConfirmationContextReady` | Seluruh filter aktif berhasil dibaca pada signal-close dan entry |

Untuk timeframe yang lebih besar daripada M1, signal-time memakai candle terakhir yang sudah
benar-benar selesai ketika candle CCI menutup. Contohnya, signal M1 yang menutup pukul 13:03 tidak
boleh membaca hasil final candle M5 pukul 13:00–13:05. Dalam kasus itu telemetry memakai candle M5
12:55–13:00. Aturan ini mencegah look-ahead bias.

## Acceptance check

Karena perubahan hanya menambah log, folder 24 harus mereproduksi folder 23:

| Metric | Folder 23 control | Folder 24 target |
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
| All diagnostic error counters | 0 | 0 |
| Active records remaining | 0 | 0 |

Jika trade history berubah, run tidak boleh dipakai untuk menyimpulkan kombinasi indikator.

## Analysis plan

Pasangkan `TS7_ORIGINAL_OPEN` dengan hasil original dan maximum recovery depth, lalu bandingkan:

1. 282 original winner;
2. 259 recovery L1-L3;
3. 53 recovery L4+.

Hitung frekuensi setiap signal-time alignment, `LateConfirmMask`, dan `LateConfirmCount` untuk
ketiga grup. Ulangi per BUY/SELL, signal age, serta time split Januari–Februari dan Maret–Mei.

Filter hanya layak masuk ablation test bila keterlambatannya lebih terkonsentrasi pada L4+
daripada winner dan pola tersebut bertahan pada kedua time split. Ablation berikutnya harus
menonaktifkan satu filter per run; jangan menonaktifkan seluruh confirmation stack sekaligus.

## Status

Implementation ready; menunggu Strategy Tester folder 24. Raw report dan journal tidak di-commit.
