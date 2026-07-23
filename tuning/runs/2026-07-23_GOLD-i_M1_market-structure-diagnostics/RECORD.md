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

Implementation ready; menunggu Strategy Tester folder 26. Raw report dan journal tidak di-commit.
