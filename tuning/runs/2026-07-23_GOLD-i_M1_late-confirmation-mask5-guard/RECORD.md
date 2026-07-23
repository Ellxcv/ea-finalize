# Symmetric Late-Confirmation Mask-5 Guard — Folder 25

## Tujuan

Menguji apakah menolak original entry setelah HiLo dan main SuperTrend terlambat berbalik bersama
dapat menaikkan original win rate dan mengurangi recovery, khususnya L4+. Rule berlaku sama untuk
BUY dan SELL; tidak ada mode direction-only.

## Rule

Aktifkan:

~~~text
InpEnableLateConfirmationGuard=true
~~~

Guard dijalankan hanya setelah seluruh confirmation entry saat ini sudah lolos. Entry diblokir
bila kondisi indikator pada saat candle CCI signal selesai menghasilkan exact mask 5:

~~~text
HiLoSignalAlign        = -1
PsarSignalAlign        =  1
SuperTrendSignalAlign  = -1
STMTFSignalAlign       =  1
LateConfirmMask        =  5
~~~

Semua alignment dinormalisasi terhadap arah entry, sehingga rule identik untuk BUY dan SELL.
Guard hanya memengaruhi original entry. Recovery, trailing, lot, session, dan exit tidak berubah.

Untuk mencegah konfigurasi ambigu, EA menolak initialization bila guard aktif tetapi HiLo, PSAR,
main SuperTrend, atau SuperTrend MTF dimatikan. `InpSTFilterTF` juga harus berupa timeframe MTF
khusus, bukan `PERIOD_CURRENT`.

## Control

Salin seluruh preset dan rentang folder 24:

- symbol `GOLD.i#`, timeframe `M1`;
- periode 2026-01-04 sampai 2026-05-02;
- CCI validity 3 dan CCI signal mode BOTH;
- HiLo, PSAR, SuperTrend M1, dan SuperTrend MTF M5 aktif;
- ADX filter false;
- trailing start/step/distance 500;
- `InpTrailingBreakEvenOffsetPoints=50`;
- original diagnostics true;
- ATR diagnostics 14 dan EMA diagnostics 50;
- seluruh session, lot, serta recovery setting sama.

Satu-satunya perubahan untuk folder 25 adalah
`InpEnableLateConfirmationGuard=true`.

## Logging

Setiap signal unik yang pertama kali diblokir menghasilkan:

~~~text
TS7_LATE_CONFIRMATION_GUARD_BLOCK|Side=...|SignalTime=...|CCIType=...|Mask=5|...
~~~

Summary akhir:

~~~text
TS7_LATE_CONFIRMATION_GUARD_SUMMARY|BlockedSignals=...|BlockedBuySignals=...|BlockedSellSignals=...|ContextErrors=...
~~~

Signal yang sama dapat tetap diperiksa sampai validity-nya habis, tetapi hanya dihitung dan dicatat
sekali. `ContextErrors` wajib nol. Jumlah blocked signal tidak harus tepat 77 karena penolakan
entry mengubah urutan trade dan waktu recovery berikutnya. Jika context signal tidak dapat dibaca,
guard fail-closed dan memblokir entry; run dengan `ContextErrors>0` wajib ditolak.

## Control metrics

| Metric | Folder 24 |
| --- | ---: |
| Original closed | 594 |
| Winner / loser / neutral | 282 / 312 / 0 |
| Original win rate | 47.47% |
| Recovery entry rate | 52.53% |
| Recovery L4+ absolute | 53 |
| Total trades / deals | 1,343 / 2,686 |
| Total net profit | $3,427.74 |
| Profit factor | 1.52 |
| Relative equity DD | 31.88% |
| Active weekdays | 84/85 |

## Acceptance

Kandidat hanya diteruskan bila:

- original win rate naik dari 47.47%;
- recovery entry rate turun dari 52.53%;
- jumlah L4+ turun dari 53 dan maximum recovery depth tidak memburuk;
- active weekdays tetap minimal 80% dari hari tersedia dan daily coverage tidak turun tajam;
- net profit, profit factor, dan equity drawdown tidak memburuk material;
- `ContextErrors=0` dan seluruh diagnostic error counter tetap nol.

Jangan aktifkan guard CCI overshoot pada run ini. Jika mask-5 guard gagal, rule ditolak secara
simetris; jangan mengubahnya menjadi BUY-only atau SELL-only.

## Status

Implementation ready; menunggu Strategy Tester folder 25. Raw report dan journal tidak di-commit.
