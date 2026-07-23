# Original Trailing Breakeven Study — Folders 18–19

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
| 18 | Conservative floor | 50 points |
| 19 | Stronger floor | 100 points |

Tidak perlu mengulang folder 17 kecuali konfigurasi tester atau data berubah.

## Metric wajib

| Metric | Folder 17 control | Folder 18 | Folder 19 |
| --- | ---: | ---: | ---: |
| Original win rate | 40.07% | Pending | Pending |
| Recovery entry rate | 59.26% | Pending | Pending |
| Original neutral | 4 | Pending | Pending |
| Original loss after MFE >= 500 | 48 | Pending | Pending |
| Recovery L4+ absolute | 53 | Pending | Pending |
| Recovery <= L3 | 84.94% | Pending | Pending |
| Total net profit | $3,472.01 | Pending | Pending |
| Profit factor | 1.53 | Pending | Pending |
| Relative equity DD | 31.85% | Pending | Pending |
| Active trading weekdays | 84/85 | Pending | Pending |
| Data errors / active records | 0 / 0 | Pending | Pending |

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
