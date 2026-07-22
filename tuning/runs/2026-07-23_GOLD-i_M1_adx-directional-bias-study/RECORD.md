# ADX Directional Bias Study

## Scope

Report dibandingkan pada GOLD.i# M1, 2026-01-04 sampai 2026-05-02, 99% real ticks, deposit
$4,000, dan leverage 1:500. Folder 5 adalah control CCI validity 3. Folder 6–9 mengaktifkan ADX
directional bias dan tidak mengubah recovery maksimum 10 level.

Artefak asli tetap berada di `%USERPROFILE%\Downloads\Backtest-1\5` sampai folder `9`.

## Parameter map

| Folder | Variant | ADX TF | Threshold | Smoothing |
| ---: | --- | --- | ---: | --- |
| 5 | CCI validity 3 control | Off | 30, inactive | 14, inactive |
| 6 | ADX directional bias | M1 | 20 | On, 14 bars |
| 7 | ADX directional bias | M5 | 20 | On, 14 bars |
| 8 | ADX directional bias | M5 | 25 | On, 14 bars |
| 9 | ADX directional bias | M5 | 25 | Off |

## Overall comparison

| Metric | Folder 5 | Folder 6 | Folder 7 | Folder 8 | Folder 9 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Net profit | $3,472.01 | $2,906.45 | $1,980.02 | $1,554.60 | -$3,803.64 |
| Profit factor | 1.53 | 1.55 | 1.55 | 1.61 | 0.31 |
| Expected payoff | $2.50 | $2.58 | $2.42 | $2.49 | -$14.80 |
| MT5 trades | 1,391 | 1,126 | 817 | 624 | 257 |
| Sharpe ratio | 3.80 | 4.23 | 3.81 | 6.32 | -5.00 |
| Maximum equity DD | $1,608.22 | $1,500.83 | $1,479.46 | $1,303.24 | $4,391.44 |
| Relative equity DD | 31.85% | 32.12% | 34.10% | 25.24% | 95.72% |

## Original and recovery comparison

| Metric | Folder 5 | Folder 6 | Folder 7 | Folder 8 | Folder 9 |
| --- | ---: | ---: | ---: | ---: | ---: |
| Original cycles | 594 | 475 | 349 | 268 | 100 |
| Original win rate | 40.07% | 39.16% | 40.69% | 39.93% | 36.00% |
| Recovery entry rate | 59.26% | 60.42% | 58.45% | 59.33% | 63.00% |
| Net-positive recovery cycles | 97.44% | 97.56% | 99.02% | 98.74% | 98.41% |
| Recovery <= level 2 | 68.47% | 68.99% | 66.67% | 69.18% | 60.32% |
| Recovery <= level 3 | 84.94% | 84.67% | 84.80% | 84.28% | 82.54% |
| Recovery level 4+ | 15.06% | 15.33% | 15.20% | 15.72% | 17.46% |
| Maximum recovery depth | 10 | 10 | 10 | 10 | 10 |

ADX M1/20 gagal melakukan seleksi entry: original win rate turun 0.91 percentage point dan recovery
rate naik 1.16 point. ADX M5/20 hanya memperbaiki original win rate 0.62 point dan recovery rate
0.81 point, tetapi relative equity DD lebih buruk. Perubahannya belum material.

ADX M5/25 meningkatkan profit factor dan menurunkan drawdown, tetapi tidak meningkatkan original
win rate atau distribusi recovery. Hasil tersebut berasal dari exposure dan jumlah trade yang lebih
rendah, bukan dari original entry yang jauh lebih akurat.

## Daily consistency

| Metric | Folder 5 | Folder 6 | Folder 7 | Folder 8 |
| --- | ---: | ---: | ---: | ---: |
| Active weekdays | 84/85 | 84/85 | 83/85 | 80/85 |
| Positive realized-P/L days | 84 | 84 | 83 | 80 |
| Losing realized-P/L days | 0 | 0 | 0 | 0 |
| No-trade weekdays | 1 | 1 | 2 | 5 |
| Longest no-trade weekday streak | 1 | 1 | 1 | 1 |
| Average active-day P/L | $41.33 | $34.60 | $23.86 | $19.43 |
| Median active-day P/L | $36.83 | $29.90 | $21.80 | $14.20 |

Folder 8 masih memenuhi kebutuhan frekuensi dengan active-day coverage 94.12%. Namun angka positif
harian adalah realized P/L dan tidak menghapus floating risk recovery.

Folder 9 hanya aktif pada 28 dari 85 weekday karena akun hampir habis pada 2026-02-12. Angka
inactivity setelah tanggal tersebut bukan perilaku filter normal dan tidak boleh dipakai sebagai
nilai daily coverage yang valid.

## Recovery carry and tail risk

| Metric | Folder 5 | Folder 6 | Folder 7 | Folder 8 |
| --- | ---: | ---: | ---: | ---: |
| Recovery cycles | 352 | 287 | 204 | 159 |
| Carried overnight | 5 | 4 | 2 | 1 |
| Overnight rate | 1.42% | 1.39% | 0.98% | 0.63% |
| Median recovery duration | 0.25 h | 0.28 h | 0.25 h | 0.24 h |
| L10 cycles | 5 | 3 | 2 | 1 |

Folder 8 mengurangi jumlah recovery overnight dan kejadian L10 secara absolut. Meski demikian,
recovery L10 tanggal 2026-04-06 tetap lolos dan relative equity DD masih 25.24%. Variant ini belum
siap untuk compound.

### Folder 9 catastrophic cycle

Pada 2026-02-12 17:44, original BUY masuk sekitar 5070.25. Recovery bertambah sampai L10 dalam
sekitar 30 menit. Pada 18:14, posisi ditutup melalui stop-out/end-of-test sekitar harga 4990.54.
Cycle kehilangan sekitar $4,387.23 dan balance report tersisa $196.36.

Folder 9 berakhir dengan net loss $3,803.64, profit factor 0.31, original win rate 36.00%, recovery
rate 63.00%, dan relative equity DD 95.72%. Ini mengulang pola kegagalan validity 2 pada timestamp
yang sama.

## Implementation finding

ADX strength yang dipakai EA adalah rata-rata 14 closed bars. Pada M5, strength tersebut mencakup
sekitar 70 menit sehingga berpotensi terlambat terhadap perubahan regime. Bias +DI/-DI sendiri
dipertahankan sampai terjadi cross berikutnya. Tidak ditemukan indikasi bahwa setting report salah;
folder 9 mengisolasi lag tersebut dan membuktikan bahwa smoothing OFF berbahaya pada konfigurasi
ini. ADX tanpa smoothing masih sempat mengizinkan BUY pada fase awal reversal tajam sebelum bias
+DI/-DI berbalik.

## Verdict

- Folder 6: reject sebagai filter win rate.
- Folder 7: improvement terlalu kecil dan drawdown memburuk.
- Folder 8: simpan sebagai kandidat pengurang exposure, bukan kandidat peningkat win rate.
- Folder 9: reject; smoothing OFF menyebabkan account-level failure.
- Control entry tetap folder 5 sampai ada variant yang memperbaiki original/recovery secara material.

## Next action

Hentikan tuning parameter ADX. Mode CCI berikut sudah diimplementasikan pada branch
`feature/cci-signal-modes` untuk diuji secara terpisah:

1. bedakan strong dan normal CCI serta tulis tipe sinyal ke comment/log;
2. test BOTH sebagai control, NORMAL_ONLY, lalu STRONG_ONLY;
3. setelah tipe CCI terukur, tambahkan impulse guard berbasis candle-range/ATR dan maximum spread;
4. gunakan folder 5 sebagai control entry dan folder 8 hanya sebagai pembanding exposure.
