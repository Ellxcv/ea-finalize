# Original Trailing Breakeven Study — Folders 18–20

## Tujuan

Menguji apakah profit floor pada aktivasi trailing original dapat mencegah loss kecil yang tetap
memicu recovery. Perubahan ini hanya berlaku pada posisi original; recovery grid dan pengelolaan
posisi recovery tidak berubah.

## Dasar hipotesis

Folder 17 menemukan 48 original loser yang sudah mencapai MFE minimal 500 points:

- 45 trade akhirnya rugi maksimal $0.50;
- seluruh 48 trade rugi maksimal $1.01;
- recovery depth seluruh kelompok hanya L1–L3;
- 44 dari 48 berhenti pada L1.

Trailing control mulai pada 500 points dengan distance 500 points. Stop pertama berada dekat entry,
sehingga slippage atau selisih eksekusi masih dapat menghasilkan loss kecil.

## Perilaku input

~~~text
InpTrailingBreakEvenOffsetPoints=0
~~~

Nilai `0` mempertahankan perilaku legacy. Saat nilainya positif dan trailing sudah aktif:

~~~text
BUY  minimum SL = entry + offset
SELL maximum SL = entry - offset
~~~

Regular trailing candidate tetap dipakai jika sudah mengunci profit lebih besar daripada floor.
Offset harus lebih kecil daripada `InpTrailingStartPoints`.

## Test matrix

Gunakan seluruh setting, periode, symbol, timeframe, model tick, deposit, dan leverage folder 17.
Diagnostics tetap aktif.

| Folder | Variant | Offset |
| ---: | --- | ---: |
| 17 | Existing control | 0 points |
| 18 | Aggressive floor | 200 points |
| 19 | Stronger floor | 100 points |
| 20 | Conservative floor | 50 points |

Tidak perlu mengulang folder 17 kecuali konfigurasi tester atau data berubah.

## Metric wajib

| Metric | Folder 17: 0 | Folder 18: 200 | Folder 19: 100 | Folder 20: 50 |
| --- | ---: | ---: | ---: | ---: |
| Test completion | 100% | 33%; stop-out | 33%; stop-out | 100% |
| Original closed | 594 | 208* | 207* | 594 |
| Original winner / loser / neutral | 238 / 352 / 4 | 92 / 116 / 0* | 92 / 115 / 0* | 282 / 312 / 0 |
| Original win rate | 40.07% | 44.23%* | 44.44%* | 47.47% |
| Recovery entry rate | 59.26% | 55.77%* | 55.56%* | 52.53% |
| Original loss after MFE >= 500 | 48 | 1* | 0* | 9 |
| Recovery L4+ absolute | 53 | 21* | 20* | 53 |
| Recovery <= L3 | 84.94% | 81.90%* | 82.61%* | 83.01% |
| Total trades / deals | 1,391 / 2,782 | 507 / 1,014* | 502 / 1,004* | 1,343 / 2,686 |
| Total net profit | $3,472.01 | -$7,752.57* | -$7,863.97* | $3,427.74 |
| Profit factor | 1.53 | 0.32* | 0.31* | 1.52 |
| Relative equity DD | 31.85% | 170.47%* | 174.11%* | 31.88% |
| Active trading weekdays | 84/85 | 29/85* | 29/85* | 84/85 |
| Positive / losing weekdays | 84 / 0 | 28 / 1* | 28 / 1* | 84 / 0 |
| Data errors / active records | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 |

`*` Hasil folder 18 dan 19 tidak boleh dibandingkan sebagai full-period performance karena tester
berhenti pada 2026-02-12, sekitar 33% periode.

## Acceptance criteria

Variant hanya diterima jika:

1. recovery entry rate turun tanpa menaikkan jumlah L4+ absolut di atas 53;
2. tiny-loss setelah MFE 500 berkurang secara material;
3. net profit, profit factor, drawdown, dan daily activity tidak memburuk secara material;
4. tidak muncul error modifikasi SL atau diagnostics;
5. hasil tidak bergantung pada perubahan input selain offset.

Jika offset 50 dan 100 menghasilkan manfaat serupa, pilih 50 karena lebih sedikit memotong ruang
retracement winner. Perhitungan 45–48 trade yang dapat diselamatkan adalah upper bound; perubahan
exit dapat mengubah urutan trade berikutnya sehingga full backtest tetap wajib.

## Hasil recovery depth

| Maximum level | Folder 17: offset 0 | Folder 20: offset 50 |
| ---: | ---: | ---: |
| L1 | 145 | 110 |
| L2 | 96 | 94 |
| L3 | 58 | 55 |
| L4 | 25 | 25 |
| L5 | 10 | 10 |
| L6 | 8 | 8 |
| L7 | 3 | 3 |
| L8 | 1 | 1 |
| L9 | 1 | 1 |
| L10 | 5 | 5 |
| **L4+ absolute** | **53** | **53** |

Offset 50 menghapus 40 original loss dan meningkatkan winner sebanyak 44 karena empat neutral
control juga menjadi winner. Recovery turun 6.73 percentage points. Total trade recovery berkurang,
tetapi seluruh 53 deep recovery L4+ tetap ada; relative share L4+ naik karena denominator recovery
lebih kecil.

Sembilan loser folder 20 masih mencapai MFE minimal 500 points. Seluruhnya hanya mencapai recovery
L1 dan final loss berada antara -$0.03 sampai -$0.82. Tidak ada error modifikasi SL.

## Stop-out offset 100 dan 200

Kedua variant agresif masuk ke jalur trade berbeda sebelum shock 2026-02-12. Original BUY ditutup
rugi -$7.74 pada 17:59:21, lalu recovery mencapai L10 dan seluruh basket terkena stop-out pada
18:15. Control dan offset 50 tidak memulai recovery tersebut. Ini menunjukkan path-dependency:
memotong posisi lebih cepat dapat mengizinkan entry berikutnya pada waktu yang berbeda.

Anomali history Februari dapat memperbesar shock, tetapi variant yang menjadi lebih rapuh terhadap
window yang sama tetap tidak boleh diterima.

## Verdict

- Offset 200: **reject; stop-out dan test tidak selesai**.
- Offset 100: **reject; stop-out dan test tidak selesai**.
- Offset 50: **provisional accept** untuk meningkatkan original WR dan mengurangi frekuensi
  recovery. Net profit turun 1.28%, PF turun 0.01, DD praktis sama, dan daily coverage tetap.
- Jangan lanjut tuning offset untuk mengejar sembilan tiny-loss tersisa. Semuanya hanya L1,
  sedangkan prioritas berikutnya adalah 53 recovery L4+ yang tidak berubah.
- Gunakan offset 50 sebagai candidate saat menguji telemetry directional impulse dan
  distance-from-mean untuk kualitas entry.
