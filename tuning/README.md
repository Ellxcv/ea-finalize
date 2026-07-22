# Strategy Tuning Workspace

Folder ini menjadi workspace untuk meningkatkan win rate strategy original, mengurangi frekuensi
recovery, dan membatasi recovery agar umumnya selesai dalam dua sampai tiga level.

## Isi folder

- [ANALYSIS.md](ANALYSIS.md): analisis berkelanjutan, perbandingan run, hipotesis, dan keputusan.
- [runs/README.md](runs/README.md): aturan penyimpanan artefak setiap Strategy Tester.
- [runs/STRATEGY_TESTER_RECORD_TEMPLATE.md](runs/STRATEGY_TESTER_RECORD_TEMPLATE.md): template
  record yang disalin untuk setiap run.

## Alur kerja

1. Tentukan satu hipotesis tuning.
2. Ubah hanya satu kelompok aturan atau parameter.
3. Jalankan Strategy Tester pada konfigurasi data yang konsisten.
4. Buat folder run baru dan salin template record ke dalamnya.
5. Isi seluruh metrik yang tersedia dan sertakan artefak report.
6. Beri tahu Codex nama folder run yang perlu dianalisis.
7. Perbarui ANALYSIS.md sebelum memilih eksperimen berikutnya.

Jangan menilai strategi hanya dari win rate. Profit factor, expectancy, drawdown, jumlah trade,
recovery rate, kedalaman recovery, dan kestabilan out-of-sample harus dibaca bersama.
