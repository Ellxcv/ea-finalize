# Dependencies

## Standard library

EA memakai standard library MetaTrader 5:

- Trade/Trade.mqh
- Trade/PositionInfo.mqh
- Trade/SymbolInfo.mqh
- Trade/AccountInfo.mqh

## Custom indicators

Path berikut dipanggil melalui iCustom dan harus tersedia relatif terhadap MQL5/Indicators:

| Path | Peran |
| --- | --- |
| cciCustomFix/cciCustomFix | Sinyal CCI |
| hiloFix/hiloFix | Sinyal HiLo |
| parabolicSarFix/parabolicSarFix | Sinyal PSAR |
| superTrend/superTrend | Konfirmasi SuperTrend dan recovery |
| algoZone/algoZone | Filter zona opsional |
| accountStatus/accountStatus | Dashboard opsional |

Binary indikator tidak disimpan dalam repository. Sebelum publikasi, tentukan sumber resmi,
versi, checksum, dan lisensi setiap dependency. Folder lokal requirement/ berisi material lama
yang belum lolos review tersebut sehingga diabaikan oleh Git.
