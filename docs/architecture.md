# Arsitektur

~~~text
testing_strat_7.mq5
    |
    +-- Include/TS7/Inputs.mqh dan GlobalState.mqh
    +-- Include/TS7/Core/       lifecycle, handle, order, posisi, risiko
    +-- Include/TS7/Signals/    pembacaan dan konfirmasi sinyal
    +-- Include/TS7/Filters/    filter waktu dan sesi
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
- Recovery: state serta implementasi Classic, Trend, Start Reverse, Grid, dan Distance.
- Inputs.mqh: konfigurasi pengguna yang tampil pada properti EA.
- GlobalState.mqh: state dan handle bersama yang dibutuhkan lintas modul.

## CCI signal selection

`Signals/CCI.mqh` membaca empat buffer indikator: normal Buy/Sell dan StrongBuy/StrongSell.
`InpCciSignalMode` menentukan apakah entry menerima keduanya, hanya normal, atau hanya strong. Mode
default `CCI_SIGNAL_MODE_BOTH` mempertahankan perilaku legacy.

Original order diberi tag `[CCI:N]` untuk normal atau `[CCI:S]` untuk strong. Tag tersebut hanya
untuk telemetry dan tidak mengubah klasifikasi recovery; recovery tetap dikenali melalui `[REC]`.

`InpEnableImpulseGuard` menambahkan veto khusus entry original menggunakan adverse movement dari
closed bar terbaru terhadap close beberapa bar sebelumnya, dinormalisasi dengan ATR. BUY ditolak
setelah penurunan ekstrem dan SELL ditolak setelah kenaikan ekstrem. Sinyal yang ditolak dianggap
sudah digunakan agar tidak berubah menjadi entry tertunda; recovery tidak melewati filter ini.
Default `false` mempertahankan perilaku legacy.

Perubahan sebaiknya bergerak dari input dan kontrak state menuju satu modul perilaku, lalu
diverifikasi pada entry point. Jangan menduplikasi source modul kembali ke folder global
MQL5/Include/TS7; repository adalah sumber utama untuk project ini.
