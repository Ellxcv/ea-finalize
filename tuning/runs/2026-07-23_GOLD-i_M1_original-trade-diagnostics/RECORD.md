# Original Trade Diagnostics — Folder 17

## Tujuan

Mengumpulkan MFE/MAE dan konteks entry setiap posisi strategy original tanpa mengubah perilaku
trading. Data ini dipakai untuk menentukan apakah eksperimen berikutnya sebaiknya berupa impulse
guard, volatility guard, spread guard, atau pengelolaan exit original.

## Kontrol

Gunakan setting dan periode yang sama persis dengan control folder 5:

- symbol: `GOLD.i#`;
- timeframe: `M1`;
- CCI signal validity: `3`;
- CCI signal mode: `BOTH`;
- ADX filter: `false`;
- parameter entry, exit, lot, session, dan recovery: sama dengan folder 5;
- model tick, spread, commission, deposit, leverage, dan rentang tanggal: sama dengan folder 5.

Perubahan satu-satunya:

~~~text
InpEnableOriginalTradeDiagnostics=true
InpOriginalDiagAtrPeriod=14
~~~

Simpan hasil sebagai folder `17`.

## Acceptance check

Karena fitur ini observation-only, hasil trading folder 17 harus sama dengan folder 5:

- jumlah original trade dan seluruh deal sama;
- waktu, arah, volume, dan harga entry/close sama dalam toleransi tester;
- original win rate, recovery rate, recovery depth, net profit, dan drawdown sama;
- journal berakhir dengan `TS7_ORIGINAL_SUMMARY`;
- `DataErrors=0`;
- `ActiveRemaining=0` jika semua posisi sudah selesai ketika test berakhir.

Jika history trade berbeda, jangan gunakan telemetry untuk mengambil keputusan. Catat perbedaan
pertama dan periksa konfigurasi tester.

## Journal yang diperlukan

Jangan commit raw journal karena dapat memuat data akun/broker. Setelah backtest selesai, simpan
folder hasil tester seperti biasa. Baris berikut akan dibaca langsung dari Strategy Tester journal:

~~~text
TS7_ORIGINAL_OPEN|...
TS7_ORIGINAL_CLOSE|...
TS7_ORIGINAL_SUMMARY|...
~~~

Data close menyediakan:

- `MFEPoints`: excursion terbaik yang sempat dicapai;
- `MAEPoints`: excursion terburuk yang sempat dialami;
- `MaxProfitMoney` dan `MaxLossMoney`: floating result ekstrem;
- `FinalProfit`, `BarsHeld`, `Reason`, `SignalAge`, dan `CCIType`.

## Hasil

Status: **pending backtest folder 17**

| Metric | Result |
| --- | ---: |
| Original closed | Pending |
| Winners / losers | Pending |
| Data errors | Pending |
| Active records remaining | Pending |
| Loser MFE < 100 points | Pending |
| Loser MFE >= 250 points | Pending |
| Loser MFE >= 500 points | Pending |
| Winner average MFE / MAE | Pending |
| Loser average MFE / MAE | Pending |

## Keputusan setelah analisis

- Banyak loser punya MFE tinggi lalu kembali rugi: prioritaskan eksperimen exit/breakeven original.
- Loser dominan MFE rendah dan entry saat candle terlalu ekstrem: prioritaskan impulse/ATR guard.
- Loser terkonsentrasi pada spread tinggi: prioritaskan maximum-spread guard.
- Tidak ada pemisah stabil: jangan menambah filter; cari fitur konteks lain dan validasi
  out-of-sample sebelum implementasi.
