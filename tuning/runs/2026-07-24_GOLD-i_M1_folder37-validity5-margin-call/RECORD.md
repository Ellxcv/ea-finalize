# Folder 37 — Validity 5 Historical Failure

## Status

`FAIL — PRACTICAL MARGIN CALL / TRUNCATED RUN`

Run meminta periode 2025.09.01–2026.01.03, tetapi tester berhenti pada 2025.09.09. Data hanya
mencakup candidate 2025.09.01–2025.09.08 dan tidak boleh diperlakukan sebagai retained full-window
training data.

## Provenance dan report

| Item | Nilai |
| --- | --- |
| Strategy | `folder32_v1`, CCI validity 5 |
| RunId | `folder32_v1_GOLD-i_M1_20250901_20260103_r01` |
| Requested window | 2025.09.01–2026.01.03 |
| History observed | 8.371 bars / 1.593.024 real ticks |
| History quality | 100% real ticks |
| Initial / final balance | USD 4.000 / USD 28,33 |
| Report SHA-256 | `A4CEA210A7A477C83C21E228DABAA43B4B114CFD08FE2208DF8980DDBD79EAAA` |
| Report-saved preset SHA-256 | `1137116B60D3B6437B8646AC0283F75747FF388BAE3B40F2422EDCFC13C9EFF3` |

## Strategy Tester result

| Metric | Nilai |
| --- | ---: |
| Total net profit | -3.971,67 |
| Profit factor | 0,10 |
| Equity DD maximal | 4.176,30 (99,33%) |
| Margin level akhir | 3,26% |
| Trades / deals | 106 / 212 |
| Candidate / cycle | 42 / 42 |

Cycle outcome:

| Outcome | Jumlah |
| --- | ---: |
| `NO_RECOVERY` | 13 |
| `RECOVERY_L1_L3` | 25 |
| `RECOVERY_L4_PLUS` | 3 |
| `INCOMPLETE` | 1 |

Original trade net untuk 42 candidate hanya +3,62. Hampir seluruh kerugian berasal dari cycle
terakhir:

~~~text
CandidateTime     = 2025.09.08 07:56:00
Direction         = SELL
SignalAgeBars     = 5
OriginalNetProfit = -1.70
RecoveryEntries   = 10
MaxRecoveryLevel  = 10
RecoveryNetProfit = -4174.23
CycleNetProfit    = -4175.93
CompletionReason  = DEINIT_1
~~~

Signal age 5 berarti validity 3 kemungkinan tidak akan menerima candidate yang sama pada state
yang identik. Namun perubahan candidate sebelumnya dapat mengubah seluruh state EA, sehingga ini
hanya hipotesis dan wajib diuji ulang tiga window.

## Decision

- raw validity 5 dipertahankan tanpa edit sebagai diagnostic failure;
- run tidak digabungkan ke retained training dataset;
- `folder32_cci3_v1` dibuat sebagai challenger terpisah;
- ML training tambahan ditunda sampai stability challenger diketahui.
