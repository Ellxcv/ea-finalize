# TESTING_STRAT_7

TESTING_STRAT_7 adalah Expert Advisor MetaTrader 5 dengan konfirmasi beberapa indikator,
pengelolaan risiko harian, trailing stop, dan beberapa mode recovery.

Repository ini menyimpan source EA dan modul internal yang diperlukan untuk pengembangan.
Binary hasil kompilasi, backup manual, material eksperimen, credential, dan data runtime tidak
disimpan di Git.

## Struktur repository

~~~text
testing_strat_7.mq5       Entry point EA
testing_strat_7.mqproj    Project MetaEditor
Include/TS7/              Modul internal EA
docs/                     Arsitektur, keamanan, workflow, dan arsip pengembangan
~~~

## Prasyarat

- MetaTrader 5 dan MetaEditor.
- Custom indicator berikut sudah terpasang dan berhasil dikompilasi di MQL5/Indicators:
  - cciCustomFix/cciCustomFix
  - hiloFix/hiloFix
  - parabolicSarFix/parabolicSarFix
  - superTrend/superTrend
  - algoZone/algoZone
  - accountStatus/accountStatus untuk dashboard opsional

Detail kontrak dependency tersedia di [docs/dependencies.md](docs/dependencies.md).

## Compile

Buka testing_strat_7.mqproj atau testing_strat_7.mq5 melalui MetaEditor, lalu compile.
Source utama memakai include relatif sehingga modul Include/TS7 ikut terbawa saat repository
di-clone.

Sebelum menjalankan EA pada akun riil, lakukan compile, Strategy Tester, forward test pada akun
demo, dan review parameter risiko. Software ini tidak menjamin profit.

## Workflow

- main dijaga dalam kondisi stabil.
- Pengembangan dilakukan melalui branch develop dan branch kecil feature/*, fix/*, refactor/*,
  test/*, atau docs/*.
- Commit menggunakan Conventional Commits dan hanya memuat perubahan yang sudah ditinjau.
- Jangan push sebelum pemeriksaan credential, diff, compile, dan test selesai.

Lihat [docs/development.md](docs/development.md) untuk langkah lengkap.

## Strategy tuning

Hasil Strategy Tester dan analisis tuning disimpan di folder [tuning](tuning/README.md).
Gunakan template yang tersedia agar setiap eksperimen dapat dibandingkan berdasarkan kualitas
strategy original, frekuensi recovery, kedalaman recovery, drawdown, dan kesiapan compound.

## Machine learning

Rencana meta-filter entry original tersedia di
[docs/machine-learning-plan.md](docs/machine-learning-plan.md). Konfigurasi dataset awal dibekukan
sebagai `folder32_v1` di
[docs/ml-folder32-v1-baseline.md](docs/ml-folder32-v1-baseline.md). Implementasi ML harus dimulai
dari logger observation-only dan tidak boleh mengubah keputusan trading baseline.

## Status publikasi

Source indikator eksternal pada folder lokal requirement/ sengaja tidak dimasukkan. Lisensi dan
hak redistribusi setiap indikator harus ditinjau sebelum source tersebut dipublikasikan. Repository
ini juga belum diberi lisensi open-source; tentukan lisensi sebelum publikasi jika penggunaan ulang
oleh pihak lain ingin diizinkan.
