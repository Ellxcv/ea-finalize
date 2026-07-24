# Entry Feature v3 Full Collection and Phase 3

## Decision

`REJECTED_NOT_FROZEN`

Folders 47-48 produced a valid schema-v3 development dataset. None of the five staged feature
experiments achieves zero allowed L4+ on every future evaluation fold. No model, threshold, or
runtime ML filter is promoted.

## Collection

| Item | Folder 47 | Folder 48 |
| --- | ---: | ---: |
| Period | 2025.09.01-2026.01.03 | 2026.01.04-2026.05.02 |
| History quality | 100% real ticks | 100% real ticks |
| Candidates | 504 | 576 |
| Final balance | 6,843.47 | 8,171.15 |
| Net profit | 2,843.47 | 4,171.15 |
| Balance DD maximal | 520.38 (9.10%) | 513.27 (9.09%) |
| Equity DD maximal | 2,220.30 (38.93%) | 2,661.96 (44.40%) |
| Trades / deals | 1,194 / 2,388 | 1,274 / 2,548 |

Both reports freeze:

```text
SchemaVersion   = ts7_entry_candidate_v3
StrategyVersion = folder32_cci3_v1
SourceRevision  = 0fa72ffd879cfc2f086d2de393bd0fe443654e66
PresetHash      = 7CA8B8F6C99073EC78147B42EFD347E7B0A1972EA834CD18897E0F5EAFBAB635
EA EX5 SHA-256  = CEE53F49522E78575840F5A70696DE330B0AD7477840257D9C6E4C7E44E8E958
```

Report SHA-256:

- folder 47: `7684334314A8FD0EE5F268E700E561E5B16CF2504D551F12E4EAACEBA82614CE`
- folder 48: `6A3D36166015E2F3EB00F85510734DB47F243C6EE7307EDB81C51D773B7A8E15`

## Audit and scarce-L4 retention

Raw collection:

`C:\Users\ACER\Documents\TS7_ML\collections\folder32-cci3-entry-v3-valid`

Retained dataset:

`C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v3-dataset-v002`

```powershell
python tools/ml/audit_dataset.py `
  --raw-root "C:\Users\ACER\Documents\TS7_ML\collections\folder32-cci3-entry-v3-valid" `
  --output-dir "C:\Users\ACER\Documents\TS7_ML\processed\folder32-cci3-entry-v3-dataset-v002" `
  --config "config/ml-dataset-audit-folder32-cci3-v3.json"
```

Audit result:

- 2/2 runs accepted;
- 1,080/1,080 candidates retained;
- zero excluded and zero errors;
- two expected `SYMBOL_MIGRATION_UNVERIFIED` warnings;
- business labels: 526 `NO_RECOVERY`, 453 `RECOVERY_L1_L3`, and
  101 `RECOVERY_L4_PLUS`;
- barrier-50 labels: 482 favorable-first and 598 adverse-first.

The first audit policy excluded 75 structure-incomplete rows. Those rows contained five L4+
cycles, including L8 and L9. The policy was corrected before training:

- all non-structure v3 values remain mandatory;
- incomplete bounded structure remains explicit through `FeatureReadyV3=false` and `NA`;
- the structure experiment uses training-fold-only median imputation for its nine optional
  numeric fields and includes `FeatureReadyV3` as an availability flag.

Dataset SHA-256:

`4A869B605EDFF2709B8F7124F031E64EFAEE73C1B51FD2BF27A412749DED5C2E`

Audit report SHA-256:

`A9EC6F88BA5AD29F9D5600992C7836C2783A0B0664153A66ACDC70B184B1440E`

## Staged evaluation

Each experiment uses the same 1,080 rows, three chronological walk-forward folds, a conditional
L4+ target (`L1-L3` versus `L4+`), and the hard zero-allowed-L4 gate. The user-approved policy does
not impose a low winner-rejection limit; zero L4+ remains mandatory.

| Family | Development leader | No-recovery AUC | L4-risk AUC | Retained | Winner rejected | WR delta | Recovery reduction | Allowed L4+ |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Core | XGBoost | 0.6280 | 0.5301 | 51.71% | 45.43% | +3.01 pp | 6.27% | 35 |
| Volatility | Shallow forest | 0.6089 | 0.4709 | 53.11% | 47.43% | -0.55 pp | -0.90% | 36 |
| Durability | Shallow forest | 0.6115 | 0.5272 | 57.14% | 39.43% | +3.26 pp | 7.42% | 30 |
| Momentum | XGBoost | 0.6280 | 0.5452 | 57.30% | 36.29% | +6.09 pp | 13.03% | 37 |
| Structure | Shallow forest | 0.6273 | 0.5123 | 50.47% | 41.14% | +9.04 pp | 20.20% | 31 |

The lowest aggregate allowed-L4 count is 28 from the core shallow forest, but it retains only
48.29% and still allows 15, 6, and 7 L4+ cycles across the three folds. No family records a
zero-L4 fold.

Structure improves general entry quality most strongly, but its L4-risk AUC remains only 0.5123
for the selected forest. This supports a narrow conclusion: the new context helps distinguish
some weak entries, but does not isolate the mechanism that creates deep recovery.

## Artifact hashes

| Family | Manifest SHA-256 | Report SHA-256 |
| --- | --- | --- |
| Core | `33EE50F5B598F38CF665C959D87CEF38EC9059505856064F3FA795E332AB2A8F` | `12B818C4F3722ABE68BEE3471FDD82E162D06592510E8CB4B144782B6F514D29` |
| Volatility | `7108C14926446166E73719B4F083483CF401AD97B1A1706E600BF613665D23A7` | `B0DC0818D9B54EE6E121B42B1A8A1064DD01A61DDD841D99CDF39ECB326FA85F` |
| Durability | `D932FEA7DD5AF2029EDF98E3A52E905CD4690DC4265299D74D36BC30C366E2EF` | `AA2E58BFA0E30360EB19B7BAE537AAB1132F27C372B7E80411D52CDDE6EEB179` |
| Momentum | `212C3C4D93138773C8FF12283CBE237EB5CA6C0304DFE100B4DDC3CBEFEF9078` | `0D65D00945603E1D0B542B18C4F7240DA411BDC42FCA437ABC5576C0FB7F9D13` |
| Structure | `E07F120C499F89CBF5ECD78B5DB7E2A11FC1930212E1902979DC9BE9AECBF16C` | `002BF83B0B344133D3C5095E06AB923321BA7B0ED38F7752EF08AD91A1D9D65B` |

Raw CSV, tester reports, processed datasets, predictions, and model files remain outside Git.
Final OOS remains sealed.

## Next action

Do not combine all v3 families blindly and do not activate an ML entry filter. First perform
depth-specific diagnostics comparing L1-L3 directly against L4+ to identify which candidate-time
features, interactions, or missing market-state concepts distinguish deep recovery. Any next
feature proposal must explain that depth mechanism rather than only improving `NO_RECOVERY`.
