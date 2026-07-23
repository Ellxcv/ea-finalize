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

Completed and accepted. Preset folder 24 identik dengan folder 23 selain timestamp, sedangkan
report HTML dan grafik utama identik byte-for-byte. Journal berisi 594 record dengan
`ConfirmationContextReady=true`; seluruh entry alignment valid, mask/count konsisten, dan semua
error counter nol.

## Results

Outcome tetap 282 winner, 259 recovery L1-L3, dan 53 recovery L4+. Frekuensi filter yang belum
aligned pada signal-close:

| Filter terlambat | Winner | L1-L3 | L4+ |
| --- | ---: | ---: | ---: |
| HiLo | 248/282 (87.9%) | 231/259 (89.2%) | 51/53 (96.2%) |
| PSAR | 191/282 (67.7%) | 166/259 (64.1%) | 29/53 (54.7%) |
| SuperTrend M1 | 141/282 (50.0%) | 137/259 (52.9%) | 32/53 (60.4%) |
| SuperTrend M5 | 8/282 (2.8%) | 4/259 (1.5%) | 0/53 (0.0%) |

Tidak ada satu filter atau mask yang memenuhi screen ketat `>=20% L4+` dan `<=10% winner` pada
full period serta kedua time split. Kandidat terdekat adalah exact `LateConfirmMask=5`: HiLo dan
SuperTrend M1 berlawanan pada signal-close, sedangkan PSAR dan SuperTrend M5 sudah aligned.

| Split | Winner ditandai | L1-L3 ditandai | L4+ ditandai |
| --- | ---: | ---: | ---: |
| Jan-Feb | 13/124 (10.5%) | 16/126 (12.7%) | 7/28 (25.0%) |
| Mar-May | 16/158 (10.1%) | 18/133 (13.5%) | 7/25 (28.0%) |
| Full | 29/282 (10.3%) | 34/259 (13.1%) | 14/53 (26.4%) |

Pada 13 dari 14 L4+ yang bertanda mask 5, HiLo dan SuperTrend M1 sama-sama berubah pada candle
closed terakhir sebelum entry. Entry mask 5 memiliki original win rate 37.7%, recovery rate 62.3%,
dan L4+ share 18.2%; entry lain memiliki win rate 48.9%, recovery rate 51.1%, dan L4+ share 7.5%.
Menghapus mask 5 secara offline masih menyisakan original entry pada seluruh 84 active days,
tetapi hanya full Strategy Tester yang dapat mengukur perubahan urutan trade.

PSAR dan SuperTrend M5 tidak dipilih untuk ablation: PSAR lebih sering terlambat pada winner,
sedangkan SuperTrend M5 tidak terlambat pada satu pun L4+. Single-filter ablation HiLo/ST M1 juga
ditunda karena keduanya berubah bersamaan pada hampir seluruh mask-5 L4+. Kandidat berikutnya
adalah guard simetris exact mask 5, default-off. Raw report dan journal tidak di-commit.
