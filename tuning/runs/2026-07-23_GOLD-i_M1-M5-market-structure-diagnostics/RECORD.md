# M5 Market-Structure S/R Diagnostics — Folder 27

## Tujuan

Menguji apakah confirmed-pivot S/R M5 memberikan konteks struktural yang lebih berguna daripada
M1 untuk membedakan original winner dari recovery L4+. Snapshot M5 juga digabungkan offline
dengan snapshot M1 folder 26.

## Test setting

Seluruh report dan trading setting disalin dari folder 26. Satu-satunya perubahan:

~~~text
InpOriginalStructureTimeframe=PERIOD_M5
~~~

Left/right pivot tetap 10/10 dan history tetap 1,500 bars. EA chart serta Strategy Tester tetap
`GOLD.i#`, M1, periode 2026-01-04 sampai 2026-05-02.

## Control verification

- perbedaan file `.set` hanya timeframe structure M1 menjadi M5;
- seluruh lima grafik report folder 26 dan 27 memiliki hash SHA-256 identik;
- original closed 529: 257 winner dan 272 loser;
- recovery L1–3 tetap 231 dan L4+ tetap 41;
- total trade 1,170, deals 2,340, net $3,163.68, PF 1.62, dan DD 22.81%.

Folder 27 mereproduksi trading path folder 26 secara identik.

## Journal integrity

~~~text
StructureSnapshots=529
StructureEvaluationErrors=0
StructureNotReady=0
StructureMissingDirectionalLevel=0
~~~

Seluruh 529 position ID, entry time, outcome, dan recovery depth cocok satu-per-satu antara
snapshot M1 dan M5. Semua diagnostic error counter bernilai nol.

## M5 result

### Directional room

| Outcome | Q25 | Median | Q75 |
| --- | ---: | ---: | ---: |
| Winner | -0.726 | 3.591 | 8.294 |
| Recovery L1–3 | -0.039 | 3.532 | 7.930 |
| Recovery L4+ | -0.756 | 3.283 | 8.795 |

Nilai dinormalisasi dengan ATR M1 saat entry, sehingga ruang M5 secara wajar lebih besar. Ketiga
outcome tetap sangat tumpang tindih; L4+ tidak memiliki room yang konsisten lebih kecil.

### Structure context

| Context | Count | Winner | L1–3 | L4+ | Deep rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| Opposing level ahead | 381 | 183 | 171 | 27 | 7.1% |
| Opposing level already broken | 148 | 74 | 60 | 14 | 9.5% |
| Structure trend aligned | 291 | 141 | 127 | 23 | 7.9% |
| Structure trend opposed | 238 | 116 | 104 | 18 | 7.6% |
| Latest HH | 142 | 67 | 64 | 11 | 7.7% |
| Latest HL | 148 | 67 | 73 | 8 | 5.4% |
| Latest LH | 109 | 51 | 47 | 11 | 10.1% |
| Latest LL | 130 | 72 | 47 | 11 | 8.5% |

Trend aligned dan opposed hampir sama. Level yang sudah ditembus serta latest LH sedikit lebih
sering L4+, tetapi masing-masing membuang 28.8% dan 19.8% winner jika dijadikan guard.

### Directional level age

| M5 age | Count | Winner | L1–3 | L4+ | Deep rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| `<= 14` bars | 47 | 25 | 20 | 2 | 4.3% |
| 15–24 bars | 124 | 57 | 58 | 9 | 7.3% |
| 25–39 bars | 164 | 81 | 71 | 12 | 7.3% |
| `>= 40` bars | 194 | 94 | 82 | 18 | 9.3% |

Level tua kembali memiliki deep rate sedikit lebih tinggi, tetapi tidak cukup selektif.

## M1 + M5 screen

Korelasi `DirectionalRoomATR` M1 dan M5 hanya 0.191 untuk seluruh entry dan 0.067 pada L4+.
Artinya M5 memang membawa skala informasi berbeda, tetapi informasi baru tersebut tetap tidak
memisahkan outcome.

Screen mencakup:

- threshold room dan age pada masing-masing timeframe;
- trend, latest swing, opposing-level type, dan status level ahead/broken;
- agreement/disagreement M1–M5;
- seluruh pasangan satu kondisi M1 dengan satu kondisi M5.

Hasil:

- tidak ada single M5 rule yang menangkap minimal 9/41 L4+ dengan maksimal 25/257 winner;
- tidak ada cross-timeframe pair yang memenuhi kedua batas tersebut;
- rule terdekat dengan winner-loss masih aman hanya menangkap 8/41 L4+;
- rule termurah yang menangkap 9/41 L4+ membuang 27/257 winner dan tetap belum lolos time-split
  verification.

Contoh agreement rule juga lemah:

| Combined condition | Flagged | Winner | L1–3 | L4+ |
| --- | ---: | ---: | ---: | ---: |
| Both trends opposed | 79 | 35 | 39 | 5 |
| Both latest structures opposed | 93 | 49 | 35 | 9 |
| Both opposing-level types opposed | 112 | 53 | 50 | 9 |
| Both opposing levels already broken | 50 | 26 | 21 | 3 |

## Decision

Hipotesis confirmed-pivot S/R ditutup sebagai entry guard. M1, M5, dan kombinasi M1+M5 tidak
memenuhi screen 20% L4+ / 10% winner. Jangan tuning threshold pivot atau menambah timeframe lain
pada dataset yang sama karena akan meningkatkan risiko overfitting.

Telemetry dapat tetap tersedia default-off untuk observasi, tetapi tidak diteruskan menjadi
filter. Langkah tuning berikutnya harus berpindah ke karakter candle/volatility regime atau
session-transition context dari 41 L4+ yang tersisa, bukan recovery-grid adaptation.

## Status

Completed and rejected as an entry-filter hypothesis. Raw report dan journal tidak di-commit.
