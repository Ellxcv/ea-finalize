# Deep-Recovery Entry Diagnostics — Folder 21

## Tujuan

Mencari konteks entry yang membedakan original winner, recovery dangkal L1–L3, dan 53 recovery
L4+ pada candidate offset 50. Run ini observation-only dan tidak menambahkan filter entry.

## Control

Gunakan seluruh konfigurasi folder 20:

- symbol `GOLD.i#`, timeframe `M1`;
- periode 2026-01-04 sampai 2026-05-02;
- CCI validity 3 dan CCI signal mode BOTH;
- ADX filter false;
- trailing start/step/distance 500;
- `InpTrailingBreakEvenOffsetPoints=50`;
- diagnostics true;
- seluruh session, indicator, lot, dan recovery setting sama.

Input diagnostics baru:

~~~text
InpOriginalDiagEmaPeriod=50
~~~

Simpan hasil sebagai folder `21`.

## Feature definitions

Seluruh nilai berikut dibagi ATR diagnostics dan disesuaikan terhadap arah posisi. Positif berarti
searah posisi; negatif berarti melawan posisi.

| Field | Definition |
| --- | --- |
| `Impulse3ATR` | BUY: `(Close[1]-Close[4])/ATR`; SELL dibalik |
| `Impulse5ATR` | BUY: `(Close[1]-Close[6])/ATR`; SELL dibalik |
| `DistanceEMAATR` | BUY: `(Entry-EMA50)/ATR`; SELL dibalik |
| `SignalDriftATR` | BUY: `(Entry-SignalClose)/ATR`; SELL dibalik |
| `ContextReady` | Seluruh source feature tersedia dan valid |

## Acceptance check

Karena hanya menambah telemetry, folder 21 harus mereproduksi folder 20:

| Metric | Folder 20 control | Folder 21 |
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
| Data errors / context errors | 0 / 0 | 0 / 0 |
| Active records remaining | 0 | 0 |

Jika trading history berubah, jangan gunakan feature untuk memilih filter.

Folder 21 diterima sebagai reproduction yang bersih. Seluruh 5,381 baris tabel history pada report
folder 20 dan 21 identik. Preset juga identik kecuali penambahan
`InpOriginalDiagEmaPeriod=50`. Journal memiliki 594 `TS7_ORIGINAL_OPEN`, 594
`TS7_ORIGINAL_CLOSE`, dan seluruh record memiliki `ContextReady=true`.

## Analysis groups

Setelah run diterima, bandingkan distribusi setiap feature untuk:

1. 282 original winner;
2. 259 recovery L1–L3;
3. 53 recovery L4+.

Catat median, quartile, sample size, dan overlap. Sebuah threshold hanya menjadi kandidat test bila
menolak bagian material kelompok L4+ dengan false rejection winner yang rendah. Screening awal:
menolak minimal 20% L4+ dengan maksimal 10% winner. Threshold tersebut tetap harus diuji melalui
full Strategy Tester karena penolakan entry mengubah urutan trade.

## Results

Recovery loser terbagi menjadi 259 cycle L1-L3 dan 53 cycle L4+. Distribusi depth sama dengan
folder 20:

| Maximum depth | Cycle |
| ---: | ---: |
| L1 | 110 |
| L2 | 94 |
| L3 | 55 |
| L4 | 25 |
| L5 | 10 |
| L6 | 8 |
| L7 | 3 |
| L8 | 1 |
| L9 | 1 |
| L10 | 5 |

Distribusi feature berikut menunjukkan overlap yang sangat besar. Angka dalam kurung adalah
interquartile range.

| Feature | Winner, n=282 | Recovery L1-L3, n=259 | Recovery L4+, n=53 |
| --- | ---: | ---: | ---: |
| `Impulse3ATR` | 1.815 (1.296-2.308) | 1.825 (1.305-2.338) | 1.853 (1.255-2.295) |
| `Impulse5ATR` | 1.219 (0.806-1.716) | 1.328 (0.808-1.835) | 1.415 (1.070-1.821) |
| `DistanceEMAATR` | 1.782 (1.141-2.451) | 1.806 (1.123-2.466) | 1.962 (1.202-2.649) |
| `SignalDriftATR` | 1.172 (0.762-1.686) | 1.132 (0.710-1.667) | 1.336 (0.779-1.634) |

Kemampuan pemisahan L4+ versus winner berada dekat tebakan acak. AUC tanpa memperhatikan arah
threshold hanya 0.507 untuk `Impulse3ATR`, 0.549 untuk `Impulse5ATR`, 0.536 untuk
`DistanceEMAATR`, dan 0.520 untuk `SignalDriftATR`.

Screening threshold dua arah juga gagal memenuhi syarat awal. Berikut hasil terbaik tiap feature
saat winner yang ditolak dibatasi maksimal 10%.

| Rule observasi | L4+ ditolak | Winner ditolak | L1-L3 ditolak |
| --- | ---: | ---: | ---: |
| `Impulse3ATR >= 2.796` | 6/53 (11.3%) | 22/282 (7.8%) | 27/259 (10.4%) |
| `Impulse5ATR <= 0.306` | 5/53 (9.4%) | 28/282 (9.9%) | 17/259 (6.6%) |
| `DistanceEMAATR >= 3.325` | 5/53 (9.4%) | 21/282 (7.4%) | 21/259 (8.1%) |
| `SignalDriftATR <= 0.361` | 5/53 (9.4%) | 27/282 (9.6%) | 23/259 (8.9%) |

Tidak ada threshold yang mencapai target menolak minimal 20% L4+ dengan maksimal 10% winner,
bahkan sebelum perubahan urutan trade diperhitungkan. Pemeriksaan terpisah Januari-Februari versus
Maret-Mei juga tidak menghasilkan threshold yang lolos pada kedua bagian waktu.

Side tidak menjelaskan deep recovery: BUY memiliki WR 47.4% dan L4+ 9.4% dari seluruh entry,
sedangkan SELL memiliki WR 47.5% dan L4+ 8.2%. Tidak ada konsentrasi bulanan yang cukup kuat:
L4+ berada di 7.0%-10.4% dari entry pada empat bulan penuh.

## Verdict

Jangan implementasikan filter entry berbasis empat feature ini. Magnitude impulse, jarak EMA, dan
drift sejak signal tidak menjelaskan 53 deep recovery dengan cukup baik. Memilih threshold dari
overlap tersebut hanya akan mengurangi aktivitas dan meng-overfit periode ini.

Hipotesis berikutnya harus mengukur keadaan yang belum tertangkap oleh magnitude harga:

1. usia/freshness perubahan arah HiLo, PSAR, SuperTrend M1, dan SuperTrend M5;
2. slope trend yang direction-normalized, bukan hanya jarak harga dari EMA;
3. state CCI pada signal dan entry, termasuk perubahan nilainya;
4. posisi entry dalam recent range serta perubahan regime volatilitas.

Mulai dari telemetry trend-freshness dan slope sebagai satu kelompok observasi. Jangan aktifkan
entry guard sampai feature tersebut mampu memisahkan L4+ dengan kriteria yang sama dan tetap stabil
pada pembagian waktu.

## Status

Completed and accepted. Raw journal tidak di-commit.
