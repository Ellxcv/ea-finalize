# CCI Validity 3 Challenger Collection Plan

## Strategy identity

~~~text
StrategyVersion = folder32_cci3_v1
PresetHash      = 7CA8B8F6C99073EC78147B42EFD347E7B0A1972EA834CD18897E0F5EAFBAB635
SourceRevision  = 3dd654c62607b2333fde9473900d97f997bea48e
CCI validity    = 3
~~~

Audit config: `config/ml-dataset-audit-folder32-cci3-v1.json`.

## Runs

| Suggested folder | Period | Input preset | RunId |
| --- | --- | --- | --- |
| 38 | 2025.05.01–2025.08.31 | `folder32-cci3-ml-dev-20250501-20250831-r01.set` | `folder32_cci3_v1_GOLD-i_M1_20250501_20250831_r01` |
| 39 | 2025.09.01–2026.01.03 | `folder32-cci3-ml-dev-20250901-20260103-r01.set` | `folder32_cci3_v1_GOLD-i_M1_20250901_20260103_r01` |
| 40 | 2026.01.04–2026.05.02 | `folder32-cci3-ml-dev-20260104-20260502-r01.set` | `folder32_cci3_v1_GOLD-i_M1_20260104_20260502_r01` |

## Tester settings

~~~text
Expert       = testing_strat_7
Symbol       = GOLD.i#
Timeframe    = M1
Model        = Every tick based on real ticks
Optimization = Disabled
Forward      = No
Deposit      = USD 4,000
Leverage     = 1:500
Visual mode  = Off
~~~

Periode dipilih pada tab Settings. Jangan mengubah Inputs setelah Load. Jika tester berhenti dini,
tetap simpan report dan jangan menggunakan kembali RunId yang sudah menghasilkan raw directory.
