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

Status: **complete; telemetry accepted**

| Metric | Result |
| --- | ---: |
| Original closed | 594 |
| Winners / losers / neutral | 238 / 352 / 4 |
| Original win rate | 40.07% |
| Recovery-eligible original loss | 59.26% |
| Data errors | 0 |
| Active records remaining | 0 |
| Loser MFE < 100 points | 144 / 352 (40.91%) |
| Loser MFE >= 250 points | 134 / 352 (38.07%) |
| Loser MFE >= 500 points | 48 / 352 (13.64%) |
| Winner average / median MFE | 1,327.5 / 1,126.0 points |
| Winner average / median MAE | 197.0 / 171.0 points |
| Loser average / median MFE | 222.2 / 140.5 points |
| Loser average / median MAE | 471.1 / 506.0 points |

## Validasi terhadap control folder 5

- Total net profit, profit factor, drawdown, total trades, dan total deals sama.
- Seluruh 5,565 baris history mempunyai waktu, arah, volume, harga, SL/TP, dan hasil yang sama.
- Perbedaan history hanya komentar `[CCI:N]`/`[CCI:S]`, sesuai telemetry CCI yang ditambahkan.
- Seluruh parameter yang sama pada preset folder 5 dan 17 mempunyai nilai identik. Folder 17
  hanya menambahkan CCI signal mode dan dua input diagnostics.
- Journal mempunyai 594 `OPEN` dan 594 `CLOSE` yang berpasangan; tidak ada orphan record.

Dengan demikian diagnostics tidak mengubah perilaku trading pada run ini.

## Distribusi recovery

| Maximum level | Cycle | Percent of recovery |
| ---: | ---: | ---: |
| 1 | 145 | 41.19% |
| 2 | 96 | 27.27% |
| 3 | 58 | 16.48% |
| 4 | 25 | 7.10% |
| 5 | 10 | 2.84% |
| 6 | 8 | 2.27% |
| 7 | 3 | 0.85% |
| 8 | 1 | 0.28% |
| 9 | 1 | 0.28% |
| 10 | 5 | 1.42% |
| **L4+** | **53** | **15.06%** |

## Temuan MFE/MAE

Loser terbagi menjadi dua masalah berbeda:

1. Sebanyak 144 loser (40.91%) tidak pernah mencapai MFE 100 points. Kelompok ini merupakan
   kandidat masalah kualitas entry.
2. Sebanyak 134 loser (38.07%) sempat mencapai MFE 250 points, lalu kembali rugi. Ini merupakan
   kandidat masalah pengamanan profit.

Kelompok paling jelas adalah 48 loser yang sudah mencapai MFE minimal 500 points. Seluruhnya
kemudian ditutup dengan kerugian sangat kecil:

- 45 dari 48 rugi maksimal $0.50;
- seluruh 48 rugi maksimal $1.01;
- rata-rata absolute loss sekitar $0.21;
- recovery depth: 44 cycle L1, 1 cycle L2, 3 cycle L3, dan tidak ada L4+.

Trailing saat ini mulai pada 500 points dengan distance 500 points. Stop pertama berada sangat
dekat dengan harga entry, sehingga slippage/selisih eksekusi dapat mengubah trade yang sudah
mencapai trigger trailing menjadi loss kecil. Karena recovery dipicu oleh setiap hasil negatif,
loss kecil tersebut tetap membuka recovery.

Entry ATR, range candle, dan spread tidak memisahkan winner dan loser:

| Entry feature median | Winner | Loser |
| --- | ---: | ---: |
| ATR points | 272.4 | 272.0 |
| Candle range points | 375.0 | 373.5 |
| Range / ATR | 1.29 | 1.31 |
| Spread points | 21.0 | 20.0 |

Hubungan range/ATR dan win rate juga tidak monoton. Maximum-spread guard tidak didukung oleh data;
kelompok spread rendah justru memiliki hasil lebih lemah pada sample ini.

Signal age 1 tetap lebih baik (52.94%, n=34) daripada age 2 (37.68%, n=284) dan age 3
(40.94%, n=276), tetapi sample age 1 kecil dan eksperimen freshness sebelumnya mengurangi coverage
terlalu banyak. Temuan ini tidak cukup untuk menghidupkan kembali filter freshness.

## Keputusan setelah analisis

1. Diagnostics diterima; raw journal tetap tidak di-commit.
2. ATR, single-candle range, dan spread tidak layak langsung dijadikan filter entry.
3. Eksperimen risiko terendah berikutnya adalah breakeven floor/offset pada trailing original.
   Kandidat awal 50 dan 100 points, dengan default 0 untuk mempertahankan legacy.
4. Perubahan ini berpotensi menghapus sampai 45–48 recovery dangkal, tetapi tidak menargetkan 53
   cycle L4+. Bandingkan jumlah L4+ absolut, bukan hanya persentasenya.
5. Untuk menargetkan deep recovery dari sisi entry, telemetry berikutnya harus mengukur directional
   impulse beberapa bar dan distance-from-mean yang dinormalisasi ATR. Data sekarang belum
   membuktikan threshold entry yang aman.
