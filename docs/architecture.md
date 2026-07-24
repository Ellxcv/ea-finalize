# Arsitektur

~~~text
testing_strat_7.mq5
    |
    +-- Include/TS7/Inputs.mqh dan GlobalState.mqh
    +-- Include/TS7/Core/       lifecycle, handle, order, posisi, risiko
    +-- Include/TS7/Signals/    pembacaan dan konfirmasi sinyal
    +-- Include/TS7/Filters/    filter waktu dan sesi
    +-- Include/TS7/Diagnostics/ telemetry observasi tanpa keputusan trading
    +-- Include/TS7/ML/          dataset candidate, trade/cycle, dan barrier
    +-- Include/TS7/Recovery/   mode dan state machine recovery
    |
    +-- MQL5/Indicators/*       custom indicator runtime eksternal
~~~

Entry point mengatur lifecycle MetaTrader dan menggabungkan modul berdasarkan tanggung jawab.
Modul internal disimpan bersama repository dan memakai include relatif. Custom indicator tetap
berada pada lokasi standar MQL5/Indicators karena iCustom mencarinya saat runtime.

## Batas tanggung jawab

- Core: pembuatan handle, eksekusi order, posisi, risiko harian, dashboard, dan trailing stop.
- Signals: normalisasi buffer indikator menjadi keputusan sinyal.
- Filters: aturan waktu perdagangan dan sesi.
- Diagnostics: pengukuran entry original seperti MFE/MAE, ATR, range candle, dan spread.
- ML: logger observation-only untuk candidate, actual outcome, recovery cycle, dan barrier 40/50.
- Recovery: state serta implementasi Classic, Trend, Start Reverse, Grid, dan Distance.
- Inputs.mqh: konfigurasi pengguna yang tampil pada properti EA.
- GlobalState.mqh: state dan handle bersama yang dibutuhkan lintas modul.

## ML dataset logger

`ML/DatasetLogger.mqh` aktif hanya jika `InpEnableMlDatasetLogger=true`. Candidate dicatat setelah
seluruh legacy guard dan perhitungan initial SL lolos, tepat sebelum lot/order. Modul ini tidak
memberi allow/reject dan tidak menyentuh aturan entry, exit, trailing, lot, ataupun recovery.

File ditulis ke MetaTrader Terminal Common Files, bukan repository. Relasi record memakai
`RunId`, `SetupId`, `CycleId`, dan `PositionId`. Barrier tracker berjalan per tick dengan horizon
40/50 candle M1; financial original dan recovery dijumlahkan dari history deal per posisi. Kontrak
field dan aturan missing value tersedia di
[ml-entry-candidate-v1-schema.md](ml-entry-candidate-v1-schema.md).

## Initial stop loss original strategy

`Core/MainStopLoss.mqh` menghitung initial SL sebelum lot dan order original dibuat.
`InpMainStopLossMode` menyediakan dua mode:

- `MAIN_SL_FIXED_POINTS`: perilaku legacy, memakai `InpStopLossPoints`;
- `MAIN_SL_ATR_CANDLE`: memakai high/low candle tertutup sebelumnya ditambah jarak ATR.

Formula ATR candle:

~~~text
BUY SL  = previous closed candle low  - ATR(RMA) * multiplier
SELL SL = previous closed candle high + ATR(RMA) * multiplier
~~~

ATR dihitung dari candle tertutup pada `InpMainStopAtrTimeframe`; candle berjalan tidak digunakan.
Mode ATR bersifat fail-closed: entry tidak dikirim jika history belum siap, hasil perhitungan tidak
valid, SL berada di sisi market yang salah, atau melanggar minimum stop distance broker. EA tidak
fallback diam-diam ke fixed SL.

`Core/RiskManager.mqh` menerima jarak initial SL aktual. Dengan demikian, mode lot dynamic memakai
risiko ATR yang sebenarnya, sedangkan mode lot fixed tetap memakai `InpLotSize`. Log
`TS7_MAIN_SL`, `TS7_MAIN_SL_BLOCK`, dan `TS7_MAIN_SL_SUMMARY` menyediakan telemetry untuk audit
Strategy Tester. Initial SL hanya berlaku pada original order; trailing dan recovery tetap memakai
aturan masing-masing.

## CCI signal selection

`Signals/CCI.mqh` membaca empat buffer indikator: normal Buy/Sell dan StrongBuy/StrongSell.
`InpCciSignalMode` menentukan apakah entry menerima keduanya, hanya normal, atau hanya strong. Mode
default `CCI_SIGNAL_MODE_BOTH` mempertahankan perilaku legacy.

Original order diberi tag `[CCI:N]` untuk normal atau `[CCI:S]` untuk strong. Tag tersebut hanya
untuk telemetry dan tidak mengubah klasifikasi recovery; recovery tetap dikenali melalui `[REC]`.

## Original-trade diagnostics

`Diagnostics/OriginalTradeDiagnostics.mqh` aktif hanya jika
`InpEnableOriginalTradeDiagnostics=true`. Modul mencatat konteks entry ketika order original
terbentuk, memperbarui MFE/MAE di memory pada setiap tick, lalu menulis journal hanya pada event
open, close, dan deinitialization. Prefix log terstruktur:

- `TS7_ORIGINAL_OPEN`: signal age/type, harga, ATR, range candle, dan spread saat entry;
- `TS7_ORIGINAL_CLOSE`: MFE/MAE points dan money, hasil akhir, durasi, serta alasan close;
- `TS7_ORIGINAL_SUMMARY`: jumlah winner/loser, kelompok MFE loser, error data, dan record tersisa.

Entry context tambahan memakai nilai signed yang sudah dinormalisasi terhadap arah posisi:

- `Impulse3ATR`/`Impulse5ATR`: perubahan close tiga/lima bar terakhir dibagi ATR;
- `DistanceEMAATR`: jarak entry dari EMA diagnostics dibagi ATR;
- `SignalDriftATR`: perpindahan dari close candle sinyal ke harga entry dibagi ATR.

Nilai positif berarti bergerak searah BUY/SELL dan nilai negatif berarti bergerak melawan arah
posisi. `ContextReady=false` dan `ContextErrors>0` menandai data feature yang tidak lengkap agar
nilai fallback nol tidak dipakai dalam analisis.

Telemetry tidak menambah filter, tidak mengubah harga/lot/SL/TP, dan tidak mengubah recovery.
ATR diagnostics bersifat opsional; kegagalan handle hanya menghasilkan nilai ATR nol dan tidak
menghentikan EA.

`Diagnostics/MarketStructureDiagnostics.mqh` menambahkan snapshot S/R observation-only bila
`InpEnableOriginalStructureDiagnostics=true`. Algoritma memakai pivot HH/HL/LH/LL yang memerlukan
candle kiri dan kanan. Loop berhenti pada shift 1, sehingga candle berjalan tidak dipakai untuk
mengonfirmasi pivot. Modul hanya menghitung ketika original trade terbuka dan tidak menggambar
object chart atau membawa dependency dashboard/Telegram.

Jarak S/R dinormalisasi dengan ATR diagnostics:

- BUY memakai jarak entry menuju resistance sebagai `DirectionalRoomATR`;
- SELL memakai jarak entry menuju support sebagai `DirectionalRoomATR`;
- nilai positif berarti level lawan masih berada di depan entry;
- nilai negatif berarti harga entry sudah melewati level tersebut.

Level yang belum tersedia ditulis sebagai `NA`, bukan nol. `StructureEvaluationErrors` menandai
kegagalan membaca history, sedangkan `StructureMissingDirectionalLevel` dapat terjadi secara valid
sebelum struktur lengkap terbentuk.

Perubahan sebaiknya bergerak dari input dan kontrak state menuju satu modul perilaku, lalu
diverifikasi pada entry point. Jangan menduplikasi source modul kembali ke folder global
MQL5/Include/TS7; repository adalah sumber utama untuk project ini.
