# ATR Initial Stop Loss — Implementation and Test Plan

## Tujuan

Menguji apakah initial SL original strategy yang mengikuti volatilitas dapat meningkatkan original
win rate dan mengurangi entry ke recovery tanpa memperbesar deep recovery, loss amount, atau
drawdown.

Perubahan ini hanya mengubah initial SL original order. Entry stack, trailing, dan aturan recovery
tidak diubah.

## Implemented behavior

Input baru:

~~~text
InpMainStopLossMode
InpMainStopAtrTimeframe
InpMainStopAtrPeriod
InpMainStopAtrMultiplier
~~~

Mode:

~~~text
MAIN_SL_FIXED_POINTS
MAIN_SL_ATR_CANDLE
~~~

Formula `MAIN_SL_ATR_CANDLE` mengikuti ATR stop finder `decisionDashboard`:

~~~text
BUY SL  = low candle tertutup sebelumnya  - ATR RMA(14) × 1.4
SELL SL = high candle tertutup sebelumnya + ATR RMA(14) × 1.4
~~~

ATR dan anchor candle dibaca hanya dari candle tertutup pada timeframe yang dipilih. Implementasi
meminta minimal 300 candle untuk menjaga seed RMA konsisten dengan dashboard.

Mode default tetap `MAIN_SL_FIXED_POINTS`, sehingga preset lama mempertahankan SL 500 points.

## Safety contract

- ATR history atau hasil perhitungan yang belum siap memblokir entry.
- SL ATR yang berada pada sisi market yang salah memblokir entry.
- SL ATR yang melanggar `SYMBOL_TRADE_STOPS_LEVEL` memblokir entry.
- Tidak ada fallback otomatis dari ATR ke fixed SL.
- Dynamic lot memakai jarak entry-ke-SL aktual; fixed lot tidak berubah.
- Take profit, trailing start/distance/step, break-even offset, dan recovery tidak diubah.

## Journal contract

Setiap original order yang berhasil menghasilkan:

~~~text
TS7_MAIN_SL|Side=...|SignalTime=...|Mode=...|Timeframe=...
|EntryPrice=...|StopPrice=...|StopDistancePoints=...
|ATRPrice=...|ATRPoints=...|ATRMultiplier=...
|AnchorTime=...|AnchorPrice=...|Lot=...|EstimatedRiskMoney=...
|Order=...|Deal=...
~~~

Entry yang diblokir:

~~~text
TS7_MAIN_SL_BLOCK|Side=...|SignalTime=...|Mode=...|Reason=...
~~~

Summary:

~~~text
TS7_MAIN_SL_SUMMARY|Mode=...|Opened=...|CalculationBlocks=...|BrokerBlocks=...
~~~

Acceptance integrity:

- `CalculationBlocks=0`;
- `BrokerBlocks=0`;
- jumlah `TS7_MAIN_SL` sama dengan original entry yang berhasil;
- fixed control mereproduksi folder 25 sebelum ATR dibandingkan.

## Required backtests

Gunakan symbol, timeframe, periode, model tick, deposit, spread, dan seluruh setting folder 25.
Late-confirmation mask-5 guard harus aktif dan seluruh CCI/HiLo/PSAR/SuperTrend setting tetap sama.

### Folder 32 — fixed regression control

~~~text
InpMainStopLossMode=MAIN_SL_FIXED_POINTS
InpStopLossPoints=500
InpMainStopAtrTimeframe=PERIOD_CURRENT
InpMainStopAtrPeriod=14
InpMainStopAtrMultiplier=1.4
~~~

Expected exact control:

| Metric | Folder 25 |
| --- | ---: |
| Original closed | 529 |
| Winner / loser | 257 / 272 |
| Original WR | 48.58% |
| Recovery entry rate | 51.42% |
| L4+ | 41 |
| Total trades / deals | 1,170 / 2,340 |
| Net profit | $3,163.68 |
| Profit factor | 1.62 |
| Relative equity DD | 22.81% |

Jika folder 32 tidak identik, hentikan comparison dan audit fixed-mode regression.

### Folder 33 — ATR candle experiment

Ubah hanya:

~~~text
InpMainStopLossMode=MAIN_SL_ATR_CANDLE
~~~

Tetap gunakan:

~~~text
InpMainStopAtrTimeframe=PERIOD_CURRENT
InpMainStopAtrPeriod=14
InpMainStopAtrMultiplier=1.4
~~~

Jangan mengubah trailing, recovery, lot, atau indikator entry pada run ini.

## Analysis metrics

Bandingkan folder 33 terhadap fixed control untuk:

1. original WR dan recovery entry rate;
2. recovery L1, L2, L3, dan L4+;
3. maximum recovery depth;
4. distribusi `StopDistancePoints` winner, L1–L3, dan L4+;
5. original loss amount dan recovery target awal;
6. PF, net profit, equity DD, dan stop-out;
7. active/positive weekdays dan recovery carried overnight;
8. jumlah calculation/broker blocks.

ATR diteruskan hanya jika recovery rate serta L4+ membaik tanpa memperbesar loss amount, DD, atau
stop-out risk secara material. Kenaikan WR yang hanya berasal dari SL lebih longgar tidak cukup
untuk diterima.

## Verification

- MetaEditor compile: 0 errors, 0 warnings.
- Fixed Strategy Tester regression: tidak dijalankan pada folder 32.
- ATR Strategy Tester comparison: tidak dapat dianggap one-variable comparison.

## Status

Implementasi ATR siap, tetapi rencana test awal tidak diikuti sebagai controlled experiment.
Audit preset aktual folder 32 menemukan:

- `InpMainStopLossMode=MAIN_SL_ATR_CANDLE`, bukan fixed control;
- late-confirmation guard OFF;
- CCI validity 5;
- SuperTrend M1 70/2.0 dan PSAR 0.01/0.01/0.1;
- session, recovery, dan beberapa parameter lain berbeda dari folder 25.

Karena lebih dari satu kelompok setting berubah, folder 32 tidak membuktikan efek kausal ATR SL
terhadap folder 25. Run tersebut sekarang dibekukan sebagai baseline ML mandiri
`folder32_v1`; manifest lengkap tersedia di
[../../../docs/ml-folder32-v1-baseline.md](../../../docs/ml-folder32-v1-baseline.md).

Raw report, preset, screenshot, journal, dan binary tidak di-commit.
