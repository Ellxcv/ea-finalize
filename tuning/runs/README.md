# Strategy Tester Runs

Buat satu subfolder untuk setiap run dengan format:

~~~text
YYYY-MM-DD_SYMBOL_TIMEFRAME_variant
~~~

Contoh:

~~~text
2026-07-22_XAUUSD_M5_baseline/
    RECORD.md
    report.html
    inputs.set
    deals.csv
    equity.png
~~~

Salin [STRATEGY_TESTER_RECORD_TEMPLATE.md](STRATEGY_TESTER_RECORD_TEMPLATE.md) menjadi RECORD.md
di subfolder tersebut. Nama file artefak boleh berbeda, tetapi seluruh nama harus dicatat di
RECORD.md.

## Artefak yang berguna

- report Strategy Tester dalam HTML/XML;
- input preset .set;
- deal/order history dalam CSV;
- equity dan balance curve;
- screenshot tab Results, Graph, dan Backtest;
- journal yang sudah diperiksa dan tidak memuat data sensitif.

Sebelum commit, hapus nomor akun, nama pribadi, credential, token, path privat yang tidak perlu,
dan data broker yang tidak boleh dipublikasikan.
