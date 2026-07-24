# CCI Validity 3 Entry-State v2 — Audit and Phase 3

## Decision

`REJECTED_NOT_FROZEN`

Folder 43–44 berhasil menghasilkan retained dataset schema v2, tetapi model walk-forward tidak
mencapai gate original win rate, recovery reduction, atau L4+ rejection. Tidak ada model atau
threshold yang dipromosikan.

## Collection

| Item | Folder 43 | Folder 44 |
| --- | --- | --- |
| Periode | 2025.09.01–2026.01.03 | 2026.01.04–2026.05.02 |
| Candidate | 504 | 576 |
| History quality | 100% real ticks | 100% real ticks |
| Final balance | 6.843,47 | 8.171,15 |
| Net profit | 2.843,47 | 4.171,15 |
| Balance DD maximal | 520,38 (9,10%) | 513,27 (9,09%) |
| Equity DD maximal | 2.220,30 (38,93%) | 2.661,96 (44,40%) |
| Trades / deals | 1.194 / 2.388 | 1.274 / 2.548 |

Kedua run memakai:

~~~text
SchemaVersion   = ts7_entry_candidate_v2
StrategyVersion = folder32_cci3_v1
SourceRevision  = eaa396be6ad526bb17ac8e150e69b5718cffbb0e
PresetHash      = 7CA8B8F6C99073EC78147B42EFD347E7B0A1972EA834CD18897E0F5EAFBAB635
EA EX5 SHA-256  = 66DC93D78182EE9534B3C4FFD0051F9DE1ECB5718525B99D24050ADA5EDBA42A
~~~

## Audit

~~~powershell
python tools/ml/audit_dataset.py `
  --raw-root "C:\Users\ACER\Documents\TS7_ML\collections\folder32-cci3-entry-v2-valid" `
  --output-dir "C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v2-dataset-v001" `
  --config "config/ml-dataset-audit-folder32-cci3-v2.json"
~~~

Hasil:

- 2/2 run diterima;
- 1.080/1.080 candidate retained;
- nol excluded dan nol error;
- dua warning `SYMBOL_MIGRATION_UNVERIFIED`;
- financial, pairing, barrier, readiness v1/v2, artifact, dependency, dan exact-source gate lulus.

Dataset SHA-256:

`D1EE04A22A877F133CAD28B41F2EB4672C9D780B8E58B9C307F609532383D58F`

## Feature diagnostics

Tool diagnostics diperbaiki agar `extends` pada model config diselesaikan dengan perilaku yang sama
seperti trainer. Regression test inheritance dan cycle detection ditambahkan.

~~~powershell
python tools/ml/analyze_feature_diagnostics.py `
  --dataset "C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v2-dataset-v001\merged_candidates.csv" `
  --output-dir "C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-entry-v2-feature-diagnostic-v001" `
  --diagnostic-config "config/ml-phase3-feature-diagnostics-v2.json" `
  --model-config "config/ml-phase3-baseline-v2.json"
~~~

Hanya `AdxValue` untuk barrier dan `HiLoLineSlopeATR` untuk L4+ yang stabil dari 15 feature baru.
Keduanya tetap lemah, dengan pooled AUC 0,4628 dan 0,5559.

## Baseline models

~~~powershell
python tools/ml/train_baseline_models.py `
  --dataset "C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v2-dataset-v001\merged_candidates.csv" `
  --output-dir "C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-entry-v2-exp001" `
  --config "config/ml-phase3-baseline-v2.json"
~~~

| Model | ROC-AUC | PR-AUC | Log loss | Brier | Winner rejected | L4+ rejected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | 0,4975 | 0,4359 | 0,7078 | 0,2565 | 8,00% | 8,06% |
| Shallow Random Forest | 0,4898 | 0,4546 | 0,6970 | 0,2518 | 9,71% | 11,29% |

Business result:

| Model | Original WR delta | Relative recovery reduction | Status |
| --- | ---: | ---: | --- |
| Logistic Regression | +0,69 pp | 1,56% | gagal gate |
| Shallow Random Forest | -0,05 pp | -0,08% | gagal gate |

## Artifact hashes

| Artifact | SHA-256 |
| --- | --- |
| `audit_report.json` | `6DDA237F08926AE1D33238BE780AFE06F2CC56F72A37E195CE6AD624B6AA6783` |
| `experiment_manifest.json` | `FADEDC2C797152531E28933705350556A7D7343D4E931417D54007AB4D04B8A2` |
| `experiment_report.json` | `F495199AF71FACDB9130C966BCBE9A650021A827B0D4DF8B83BB18CC8BBEFB28` |
| `diagnostic_manifest.json` | `BFE5DD4F9EA7FEC5D23E2C7BC8508A7E42EB859AC000EF7D53671671827D87AB` |
| `diagnostic_report.json` | `C7B3DC125CD3CD401B0EB7AD6BA73BCA8C25B3829FBBBD0C5C117DA1C58A9491` |

Raw CSV, tester report, model, prediction, dan processed dataset tetap berada di luar repository.

## Next action

Jangan membuka final OOS. Review challenger label langsung `NO_RECOVERY` dan
`RECOVERY_L4_PLUS` sebelum implementasi berikutnya. Jangan menambah indikator baru tanpa hipotesis
yang berbeda.
