# Development workflow

## Memulai perubahan

~~~powershell
git switch develop
git pull --ff-only origin develop
git switch -c feature/nama-fitur
~~~

Gunakan fix/, refactor/, test/, atau docs/ jika lebih sesuai. Satu branch sebaiknya menangani satu
perubahan perilaku yang dapat diverifikasi.

## Pemeriksaan sebelum commit

~~~powershell
git status --short
git diff --check
git diff -- testing_strat_7.mq5 Include/TS7
rg -n -i "token|password|secret|api[_ -]?key" -g "*.mq5" -g "*.mqh" .
~~~

Compile testing_strat_7.mqproj di MetaEditor dan pastikan hasilnya tidak memiliki error. Untuk
perubahan strategi, jalankan Strategy Tester dan catat minimal:

- symbol dan timeframe;
- rentang tanggal serta model tick;
- deposit, leverage, spread, dan preset input;
- jumlah trade, drawdown, profit factor, serta hasil forward test bila ada.

## Commit dan integrasi

~~~powershell
git add <path-yang-sudah-ditinjau>
git commit -m "feat: jelaskan perubahan"
git switch develop
git merge --no-ff feature/nama-fitur
~~~

Jangan gunakan git add -A saat ada perubahan lain yang belum ditinjau. Jangan force-push main atau
develop. Promosikan develop ke main melalui pull request setelah compile dan pengujian lolos.
