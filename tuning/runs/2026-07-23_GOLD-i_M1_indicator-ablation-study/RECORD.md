# Indicator Ablation Study — Folders 28–31

## Tujuan

Mengukur kontribusi masing-masing confirmation filter terhadap kualitas original entry dengan
mematikan tepat satu filter per run. CCI tetap menjadi trigger dan seluruh aturan trading lain
dipertahankan.

## Control dan validasi preset

Control yang adil adalah folder 24 karena late-confirmation guard tidak aktif. Folder 25 tidak
dipakai sebagai control ablation karena guard tersebut mensyaratkan HiLo, PSAR, SuperTrend M1, dan
SuperTrend M5 aktif.

| Folder | Variant | Perubahan trading dari folder 24 |
| ---: | --- | --- |
| 28 | HiLo OFF | `InpUseMainHiLoFilter=false` |
| 29 | PSAR OFF | `InpUseMainPsarFilter=false` |
| 30 | SuperTrend M1 OFF | `InpUseMainSuperTrendFilter=false` |
| 31 | SuperTrend M5 OFF | `InpEnableSTMTF=false` |

Keempat preset menggunakan:

- `GOLD.i#`, M1, 2026-01-04 sampai 2026-05-02;
- 99% real ticks dan initial deposit $4,000;
- CCI validity 3, signal mode BOTH, dan trailing break-even offset 50 points;
- `InpEnableLateConfirmationGuard=false`;
- market-structure diagnostics M5 aktif sebagai telemetry saja.

Perbedaan preset lain terhadap folder 24 hanya input market-structure diagnostics yang belum ada
pada source folder 24. Fitur tersebut sudah terbukti observation-only pada folder 26–27.

## Overall result

| Folder | Variant | Test selesai | Original WR | Recovery rate | L4+ | PF | Equity DD | Net profit |
| ---: | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 24 | Semua filter ON, guard OFF | Ya | 47.47% | 52.53% | 53 | 1.52 | 31.88% | $3,427.74 |
| 28 | HiLo OFF | Tidak; stop-out 2026-04-14 | 47.76% | 52.24% | 57* | 0.72 | 97.82% | -$3,823.28 |
| 29 | PSAR OFF | Ya | 48.02% | 51.98% | 55 | 1.56 | 31.53% | $3,712.23 |
| 30 | SuperTrend M1 OFF | Tidak; stop-out 2026-02-23 | 44.64% | 55.36% | 46* | 0.66 | 105.40% | -$4,370.69 |
| 31 | SuperTrend M5 OFF | Tidak; stop-out 2026-01-12 | 37.10% | 62.90% | 7* | 0.14 | 108.88% | -$4,384.10 |

`*` Nilai absolut dari periode parsial dan tidak boleh dibandingkan langsung dengan full-period
control.

Original summary dari journal:

| Folder | Closed | Winner | Loser | Data/diagnostic errors |
| ---: | ---: | ---: | ---: | ---: |
| 28 | 670 | 320 | 350 | 0 |
| 29 | 631 | 303 | 328 | 0 |
| 30 | 401 | 179 | 222 | 0 |
| 31 | 62 | 23 | 39 | 0 |

Folder 29 recovery-depth distribution:

| Depth | Cycle |
| ---: | ---: |
| No recovery | 303 |
| L1 | 114 |
| L2 | 102 |
| L3 | 57 |
| L4 | 26 |
| L5 | 10 |
| L6 | 8 |
| L7 | 4 |
| L8 | 1 |
| L9 | 2 |
| L10 | 4 |

Sebanyak 273/328 recovery (83.23%) selesai pada L1–L3. Control folder 24 mencapai 259/312
(83.01%). Perbaikannya hanya 0.22 percentage point, sementara L4+ absolut naik dari 53 menjadi 55.

## Stop-out evidence

Ketiga variant yang gagal membuka original SELL yang tidak ada pada control folder 24, kemudian
melanjutkan recovery searah loss sampai L10:

| Folder | Original entry | Balance sebelum cycle | Stop-out | Recovery exposure |
| ---: | --- | ---: | --- | --- |
| 28, HiLo OFF | SELL 2026-04-13 02:32 | $8,098.86 | 2026-04-14 01:58 | L10, lot maksimum 0.38 |
| 30, ST M1 OFF | SELL 2026-02-20 21:50 | $6,831.61 | 2026-02-23 04:42 | L10, lot maksimum 0.38 |
| 31, ST M5 OFF | SELL 2026-01-09 21:03 | $4,317.92 | 2026-01-12 02:33 | L10, lot maksimum 0.38 |

Timestamp ketiga original entry tersebut tidak terdapat pada deal history control folder 24.
Karena itu, filter yang dimatikan memang merupakan gate yang mencegah setup berbahaya tersebut
pada control. Stop-out tetap diperbesar oleh recovery grid yang tidak memiliki batas risiko aktif,
tetapi ablation menciptakan jalan masuk menuju cycle tersebut.

## Daily activity

| Folder | Active realized-P/L days | Positive days | Catatan |
| ---: | ---: | ---: | --- |
| 24 | 84 | 84 | Full period |
| 28 | 71 | 69 | Periode berhenti 2026-04-14 |
| 29 | 84 | 84 | Full period |
| 30 | 36 | 35 | Periode berhenti 2026-02-23 |
| 31 | 6 | 5 | Periode berhenti 2026-01-12 |

Hanya folder 29 mempertahankan daily coverage control.

## Interpretation

1. SuperTrend M5 adalah regime gate paling penting. Tanpanya original WR turun 10.37 percentage
   point dari control dan akun stop-out pada 6% interval.
2. SuperTrend M1 juga bukan filter redundan yang aman dihapus. Original WR turun menjadi 44.64%
   dan recovery rate naik menjadi 55.36% sebelum stop-out.
3. HiLo tampak netral pada aggregate WR sebelum stop-out, tetapi mencegah setidaknya satu SELL
   berbahaya yang kemudian mencapai L10. Aggregate WR tidak cukup untuk menyatakan HiLo redundan.
4. PSAR adalah filter dengan kontribusi marginal paling kecil. Mematikannya menyelesaikan periode
   dan memberi kenaikan WR 0.55 point, PF 0.04, serta net profit $284.49 terhadap folder 24.
   Namun recovery L4+ tidak membaik, maximum depth tetap L10, dan perbaikannya terlalu kecil untuk
   membuktikan bahwa PSAR harus dihapus.
5. Folder 25 dengan semua filter serta mask-5 guard masih lebih baik untuk objective utama:
   original WR 48.58%, recovery 51.42%, L4+ 41, PF 1.62, dan equity DD 22.81%.

## Journal integrity

Seluruh run memiliki:

~~~text
DataErrors=0
ContextErrors=0
TrendContextErrors=0
CCIContextErrors=0
ConfirmationContextErrors=0
StructureEvaluationErrors=0
StructureNotReady=0
StructureMissingDirectionalLevel=0
~~~

Folder 28, 30, dan 31 bukan run rusak akibat telemetry. Journal serta report sama-sama mencatat
stop-out dan terminasi periode lebih awal.

## Verdict

- Reject HiLo OFF.
- Reject SuperTrend M1 OFF.
- Reject SuperTrend M5 OFF.
- Do not promote PSAR OFF: hasilnya viable tetapi tidak memberikan perbaikan material pada
  recovery depth dan lebih lemah daripada stack folder 25.
- Pertahankan CCI + HiLo + PSAR + SuperTrend M1 + SuperTrend M5 serta mask-5 guard sebagai
  provisional entry stack.

Eksperimen berikutnya harus mengubah exit original secara terpisah: implementasikan mode initial
SL ATR yang default-off, lalu bandingkan fixed 500 points dengan candle-anchored ATR 14 RMA × 1.4.
Jangan mengubah indikator entry pada eksperimen SL tersebut.

## Artifacts

Raw report, `.set`, screenshot, dan journal tetap berada di lokasi lokal folder 28–31 serta
MetaTrader Tester logs. Artifact tersebut tidak di-commit karena mengandung data trading dan
ukurannya besar.
