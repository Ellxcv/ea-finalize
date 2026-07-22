# TESTING_STRAT_7 Working Agreement

## Scope

Repository ini berisi source Expert Advisor MetaTrader 5 TESTING_STRAT_7 dan modul internalnya.
Perubahan harus menjaga source tetap dapat dikompilasi, diuji, dan ditinjau tanpa bergantung pada
file internal yang tersembunyi di luar repository.

## Invariants

1. main harus tetap stabil dan dapat dikompilasi.
2. Modul internal project berada di Include/TS7 dan di-include melalui path relatif.
3. Jangan commit credential, nomor akun, data trading privat, screenshot akun, log terminal, atau
   hasil Strategy Tester yang mengandung data sensitif.
4. Jangan commit binary .ex5, backup manual, atau file scratch.
5. Perubahan aturan entry, exit, lot, drawdown, trailing, atau recovery harus disertai catatan
   perilaku dan hasil pengujian.
6. Custom indicator eksternal harus diperlakukan sebagai dependency; source-nya hanya boleh
   dipublikasikan setelah lisensinya ditinjau.
7. Refactor dilakukan per bagian kecil dan tidak boleh diam-diam mengubah perilaku trading.
8. Keputusan arsitektur yang material dicatat di docs/.

## Branches and commits

- Mulai pekerjaan integrasi dari develop; jaga main stabil.
- Gunakan prefix feature/, fix/, refactor/, test/, atau docs/.
- Gunakan subject Conventional Commits dan commit yang terfokus.
- Stage path yang sudah ditinjau secara eksplisit.

## Required verification

~~~powershell
git diff --check
rg -n -i "token|password|secret|api[_ -]?key" -g "*.mq5" -g "*.mqh" .
# Compile melalui MetaEditor, lalu periksa file log hasil compile.
~~~

Untuk perubahan strategi, jalankan Strategy Tester dengan preset dan rentang data yang dicatat
dalam laporan perubahan.
