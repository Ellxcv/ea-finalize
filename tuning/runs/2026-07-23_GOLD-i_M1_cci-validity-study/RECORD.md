# CCI Signal Validity Study

## Scope

Empat report dibandingkan pada GOLD.i# M1, 2026-01-04 sampai 2026-05-02, 99% real ticks, deposit
$4,000, leverage 1:500. Semua parameter sama kecuali InpCciSignalValidityBars.

Artefak tetap berada di folder eksternal Backtest-1/2 sampai Backtest-1/5.

## Parameter map

| External folder | Variant | CCI validity |
| ---: | --- | ---: |
| 2 | Control | 5 |
| 3 | Fresh signal only | 1 |
| 4 | Two-bar validity | 2 |
| 5 | Three-bar validity | 3 |

Folder 3 menggunakan nama preset backtest-2.set, tetapi nilai di dalamnya adalah validity 1.

## Overall comparison

| Metric | Validity 5 | Validity 1 | Validity 2 | Validity 3 |
| --- | ---: | ---: | ---: | ---: |
| Net profit | $6,219.06 | $310.24 | -$8,340.05 | $3,472.01 |
| Profit factor | 1.56 | 2.57 | 0.18 | 1.53 |
| Expected payoff | $2.59 | $3.37 | -$29.06 | $2.50 |
| Total MT5 trades | 2,404 | 92 | 287 | 1,391 |
| Maximum equity DD | $4,115.14 | $108.34 | $9,077.44 | $1,608.22 |
| Relative equity DD | 90.45% | 2.70% | 191.61% | 31.85% |
| Sharpe ratio | 1.35 | 28.92 | -5.00 | 3.80 |

Sharpe validity 1 tidak dapat dibandingkan secara naif karena hanya memiliki 92 trades dan sangat
sedikit hari aktif.

## Original and recovery reconstruction

Rekonstruksi memakai comment orderBuy/orderSell sebagai original dan [REC] sebagai recovery.

| Metric | Validity 5 | Validity 1 | Validity 2 | Validity 3 |
| --- | ---: | ---: | ---: | ---: |
| Original cycles | 1,020 | 44 | 117 | 594 |
| Original winners | 398 | 21 | 41 | 238 |
| Original losers | 609 | 22 | 76 | 352 |
| Original win rate | 39.02% | 47.73% | 35.04% | 40.07% |
| Recovery cycles | 609 | 22 | 76 | 352 |
| Recovery entry rate | 59.71% | 50.00% | 64.96% | 59.26% |
| Net-positive recovery cycles | 98.03% | 100.00% | 97.37% | 97.44% |
| Recovery <= level 2 | 68.97% | 54.55% | 75.00% | 68.47% |
| Recovery <= level 3 | 84.07% | 90.91% | 85.53% | 84.94% |
| Recovery level 4+ | 15.93% | 9.09% | 14.47% | 15.06% |
| Maximum depth | 10 | 5 | 10 | 10 |

## Recovery depth distribution

| Depth | Validity 5 | Validity 1 | Validity 2 | Validity 3 |
| ---: | ---: | ---: | ---: | ---: |
| L1 | 249 | 9 | 30 | 145 |
| L2 | 171 | 3 | 27 | 96 |
| L3 | 92 | 8 | 8 | 58 |
| L4 | 48 | 1 | 4 | 25 |
| L5 | 19 | 1 | 4 | 10 |
| L6 | 10 | 0 | 1 | 8 |
| L7 | 7 | 0 | 0 | 3 |
| L8 | 5 | 0 | 0 | 1 |
| L9 | 1 | 0 | 0 | 1 |
| L10 | 7 | 0 | 2 | 5 |

## Daily consistency

Weekday adalah Senin–Jumat pada rentang report. Hari libur broker belum dipisahkan.

| Metric | Validity 5 | Validity 1 | Validity 2 | Validity 3 |
| --- | ---: | ---: | ---: | ---: |
| Weekdays | 85 | 85 | 85 | 85 |
| Days with deals | 84 | 36 | 28 | 84 |
| Positive realized-P/L days | 84 | 35 | 27 | 84 |
| Losing days | 0 | 1 | 1 | 0 |
| No-trade weekdays | 1 | 49 | 57 | 1 |
| Active-day coverage | 98.82% | 42.35% | 32.94% | 98.82% |
| Avg active-day P/L | $74.04 | $8.62 | -$297.86 | $41.33 |
| Median active-day P/L | $68.50 | $6.29 | $26.56 | $36.83 |
| Longest no-trade weekday streak | 1 | 7 | 56 | 1 |
| Top-5 share of positive daily P/L | 14.71% | 39.09% | 32.46% | 16.06% |

Validity 5 dan 3 terlihat sangat konsisten pada realized P/L. Namun smooth daily balance tidak
membuktikan keamanan karena equity DD dan deep recovery tetap besar.

## Validity-2 stop-out

Pada 2026-02-12:

- original BUY 0.01 masuk sekitar 5070 dan ditutup -$7.74;
- recovery BUY bertambah dari level 1 sampai level 10 dalam sekitar 12 menit;
- maximum single lot mencapai 0.38;
- harga terus turun sampai seluruh basket dipaksa tutup/stop-out sekitar 4951;
- cycle loss sekitar -$9,073.23 dan balance berakhir negatif pada report.

Ini adalah kegagalan strategi/risk design pada data test, bukan sekadar hari loss biasa.

## Indicator diagnosis

1. CCI timing sangat sensitif dan menjadi trigger utama variasi hasil.
2. EA tidak membedakan strong vs normal CCI walaupun indicator menyediakan tipe tersebut.
3. Filter trend lain membaca current closed bar, bukan kondisi pada timestamp CCI signal.
4. HiLo, PSAR, SuperTrend M1, dan SuperTrend M5 bersifat correlated trend-state filters.
5. Tidak ada impulse-range, volatility-shock, atau spread guard.
6. ADX directional bias sudah tersedia tetapi belum diuji.

## Verdict

- Validity 5: aktivitas dan profit kuat, tetapi reject sebagai kandidat compound karena 90.45% DD.
- Validity 1: kualitas statistik tampak baik, tetapi reject karena terlalu sedikit trade/hari aktif.
- Validity 2: reject karena stop-out.
- Validity 3: provisional control untuk eksperimen berikutnya; belum layak compound.

## Follow-up execution

Repeatability control dilewati karena folder 5 sudah tersedia. Seluruh parameter non-ADX,
termasuk recovery maksimum 10 level, tetap identik. Batch aktual dijalankan sebagai berikut:

| Folder | CCI validity | ADX enabled | ADX timeframe | Mode | Threshold |
| ---: | ---: | --- | --- | --- | ---: |
| 5, existing control | 3 | false | — | — | — |
| 6 | 3 | true | Current/M1 | WITH_BIAS | 20 |
| 7 | 3 | true | M5 | WITH_BIAS | 20 |
| 8 | 3 | true | M5 | WITH_BIAS | 25 |

Hasil batch ini dicatat pada
[ADX directional-bias study](../2026-07-23_GOLD-i_M1_adx-directional-bias-study/RECORD.md).

Success criteria:

- active trading weekdays >= 80%;
- positive realized-P/L weekdays >= 75%;
- original win rate meningkat material dari 40.07%;
- recovery entry rate turun dari 59.26%;
- recovery L4+ turun dari 15.06%;
- tidak ada stop-out dan equity DD turun;
- jumlah cycle tetap cukup untuk evaluasi.
