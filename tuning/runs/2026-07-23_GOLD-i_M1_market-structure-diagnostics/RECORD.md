# Market-Structure S/R Diagnostics — Folder 26

## Tujuan

Mengukur apakah original entry yang memiliki ruang sempit menuju structural resistance/support
lebih sering masuk recovery, khususnya level 4+. Run ini observation-only dan tidak menambah entry
filter.

## Control

Gunakan preset, symbol, periode, model tick, deposit, dan seluruh setting trading folder 25 tanpa
perubahan:

- symbol `GOLD.i#`, timeframe `M1`;
- periode 2026-01-04 sampai 2026-05-02;
- late-confirmation mask-5 guard tetap aktif;
- original diagnostics tetap aktif;
- ATR diagnostics 14 dan EMA diagnostics 50;
- seluruh entry, exit, session, lot, trailing, dan recovery setting identik.

Control folder 25:

| Metric | Folder 25 |
| --- | ---: |
| Original closed | 529 |
| Winner / loser | 257 / 272 |
| Original win rate | 48.58% |
| Recovery entry rate | 51.42% |
| Recovery L4+ absolute | 41 |
| Net profit | $3,163.68 |
| Profit factor | 1.62 |
| Relative equity drawdown | 22.81% |
| Active/profit days | 84 / 84 |

## Folder 26 setting

Ubah hanya:

~~~text
InpEnableOriginalStructureDiagnostics=true
InpOriginalStructureTimeframe=PERIOD_M1
InpOriginalStructureLeftBars=10
InpOriginalStructureRightBars=10
InpOriginalStructureHistoryBars=1500
~~~

`InpEnableOriginalTradeDiagnostics` wajib tetap `true`. Jangan mengubah parameter pivot pada run
pertama agar hasil dapat dibandingkan langsung dengan logika `decisionDashboard`.

## Telemetry contract

Field berikut ditambahkan ke setiap `TS7_ORIGINAL_OPEN`:

- `StructureTF`, `StructureTrend`, dan `StructureTrendAlign`;
- `LatestStructure` (`HH`, `HL`, `LH`, `LL`, atau `NONE`);
- `Support`, `SupportType`, dan `SupportAgeBars`;
- `Resistance`, `ResistanceType`, dan `ResistanceAgeBars`;
- `SupportDistanceATR` = `(entry - support) / ATR`;
- `ResistanceDistanceATR` = `(resistance - entry) / ATR`;
- `DirectionalRoomATR`: resistance room untuk BUY, support room untuk SELL;
- `OpposingLevelAhead`, `StructureCalculated`, dan `StructureContextReady`.

Level yang belum tersedia ditulis `NA`. Summary akhir menambahkan:

~~~text
StructureSnapshots=...
StructureEvaluationErrors=...
StructureNotReady=...
StructureMissingDirectionalLevel=...
~~~

`StructureEvaluationErrors` harus nol. `StructureNotReady` atau missing directional level tidak
otomatis membatalkan run karena struktur lengkap mungkin belum tersedia pada awal history.

## Verification

Karena fitur hanya telemetry, folder 26 harus mereproduksi folder 25:

- original closed 529 dan winner/loser 257/272;
- recovery distribution identik, termasuk L4+ sebanyak 41;
- total trade, deals, net profit, PF, dan drawdown identik;
- jumlah `TS7_ORIGINAL_OPEN`, `TS7_ORIGINAL_CLOSE`, dan `StructureSnapshots` konsisten;
- seluruh diagnostic error counter selain kondisi level yang secara eksplisit missing bernilai nol.

Jika hasil trading berbeda, run ditolak sebagai control mismatch sebelum hubungan S/R dianalisis.

## Analisis setelah backtest

Gabungkan open/close dan recovery cycle berdasarkan urutan cycle/position ID, lalu bandingkan
winner, recovery L1–3, dan recovery L4+ untuk:

1. distribusi `DirectionalRoomATR`;
2. entry dengan opposing level di depan versus sudah ditembus;
3. `StructureTrendAlign` searah, netral, dan berlawanan;
4. latest swing serta umur support/resistance;
5. kestabilan hasil pada split Jan–Feb dan Mar–May.

Filter baru hanya dipertimbangkan bila kondisi yang sama menangkap minimal 20% kasus L4+ dengan
mengorbankan maksimal 10% winner dan tetap stabil pada kedua time split.

## Status

Completed and analyzed. Raw report dan journal tidak di-commit.

## Control verification

Folder 26 valid sebagai observation-only comparison:

- file `.set` berbeda dari folder 25 hanya karena lima input structure diagnostics;
- seluruh lima file grafik report folder 25 dan 26 memiliki hash SHA-256 yang identik;
- total trade 1,170 dan total deals 2,340;
- net profit $3,163.68, PF 1.62, expected payoff $2.70, dan Sharpe 5.95;
- relative equity drawdown 22.81% ($1,608.08);
- original closed 529 dengan 257 winner dan 272 loser;
- recovery depth tetap L1=95, L2=86, L3=50, L4=17, L5=8, L6=8, L7=3,
  L8=1, L9=1, dan L10=3.

Trading path identik dengan folder 25. Telemetry tidak mengubah keputusan EA.

## Journal integrity

Summary run terakhir:

~~~text
StructureSnapshots=529
StructureEvaluationErrors=0
StructureNotReady=0
StructureMissingDirectionalLevel=0
~~~

Jumlah open/close snapshot sama dengan 529 original cycle. Seluruh general, trend, CCI,
confirmation, dan structure diagnostic error counter bernilai nol. Journal agent yang memiliki
field lengkap dipakai untuk analisis; journal controller mengagregasi banyak run dan tidak dipakai
tanpa segmentasi.

## Outcome reconstruction

| Outcome | Count |
| --- | ---: |
| Original winner | 257 |
| Recovery L1–3 | 231 |
| Recovery L4+ | 41 |
| BUY: winner / L1–3 / L4+ | 152 / 135 / 27 |
| SELL: winner / L1–3 / L4+ | 105 / 96 / 14 |

### Directional room

`DirectionalRoomATR` adalah ruang menuju resistance untuk BUY dan support untuk SELL.

| Outcome | Q25 | Median | Q75 |
| --- | ---: | ---: | ---: |
| Winner | 0.014 | 0.877 | 1.485 |
| Recovery L1–3 | 0.337 | 0.918 | 1.829 |
| Recovery L4+ | -0.067 | 0.937 | 1.539 |

Distribusi ketiganya sangat tumpang tindih. Median L4+ justru hampir sama dengan winner dan L1–3.
Ruang kecil tidak menunjukkan hubungan monotonic dengan recovery depth.

| Room bin | Count | Winner | L1–3 | L4+ | Deep rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| `< -2 ATR` | 50 | 25 | 20 | 5 | 10.0% |
| `-2 sampai < 0` | 70 | 38 | 26 | 6 | 8.6% |
| `0 sampai < 0.5` | 53 | 27 | 22 | 4 | 7.5% |
| `0.5 sampai < 1` | 114 | 53 | 55 | 6 | 5.3% |
| `1 sampai < 2` | 159 | 80 | 64 | 15 | 9.4% |
| `>= 2 ATR` | 83 | 34 | 44 | 5 | 6.0% |

Level lawan sudah terlewati pada 120 entry: 63 winner, 46 L1–3, dan 11 L4+. Menolak kondisi ini
hanya menangkap 26.8% L4+ tetapi membuang 24.5% winner, sehingga gagal acceptance screen.

### Structure trend and swing

| Context | Count | Winner | L1–3 | L4+ | Deep rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| Structure trend aligned | 397 | 196 | 168 | 33 | 8.3% |
| Structure trend opposed | 132 | 61 | 63 | 8 | 6.1% |
| Latest HH | 165 | 79 | 73 | 13 | 7.9% |
| Latest HL | 112 | 55 | 49 | 8 | 7.1% |
| Latest LH | 136 | 68 | 51 | 17 | 12.5% |
| Latest LL | 116 | 55 | 58 | 3 | 2.6% |

Entry yang melawan structure trend tidak lebih berisiko. `LatestStructure=LH` menangkap 17/41
L4+, tetapi juga membuang 68/257 winner. Rasio tersebut gagal jauh dari batas maksimum 10%
winner.

### Directional level age

| Age | Count | Winner | L1–3 | L4+ | Deep rate |
| --- | ---: | ---: | ---: | ---: | ---: |
| `<= 14` bars | 163 | 72 | 83 | 8 | 4.9% |
| 15–24 bars | 155 | 91 | 51 | 13 | 8.4% |
| 25–39 bars | 115 | 49 | 57 | 9 | 7.8% |
| `>= 40` bars | 96 | 45 | 40 | 11 | 11.5% |

Level tua memiliki deep rate sedikit lebih tinggi, tetapi `age >= 40` tetap membuang 17.5% winner
untuk menangkap 26.8% L4+.

## Candidate screen

Tidak ada single S/R rule yang memenuhi syarat menangkap minimal 20% L4+ dengan kehilangan
maksimal 10% winner.

Satu paired rule lolos secara agregat hanya setelah threshold scan:

~~~text
DirectionalRoomATR <= 0.25 && DirectionalLevelAgeBars >= 40
~~~

Rule tersebut menandai 52 entry: 24 winner, 19 L1–3, dan 9 L4+. Namun hasilnya tidak stabil:

| Split | L4+ caught | Winner rejected |
| --- | ---: | ---: |
| Jan–Feb | 6/22 (27.3%) | 9/113 (8.0%) |
| Mar–May | 3/19 (15.8%) | 15/144 (10.4%) |

Rule gagal minimum deep-catch dan maksimum winner-loss pada Mar–May. Karena ditemukan setelah
scan banyak threshold, rule juga memiliki risiko data-mining tinggi dan ditolak.

## Decision

Jangan menambahkan entry guard berdasarkan S/R M1, directional room, structure-trend alignment,
jenis swing, atau umur level. Semua feature tersedia dengan benar, tetapi tidak memisahkan winner
dari L4+ secara cukup bersih.

Satu test structure yang masih layak adalah mengganti telemetry ke `PERIOD_M5` tanpa perubahan
source atau trading setting. Folder 27 dapat digabungkan offline dengan snapshot M1 folder 26
berdasarkan position ID/waktu entry. Jika M5 dan kombinasi M1+M5 juga gagal, hipotesis structural
S/R dihentikan sebagai entry guard.
