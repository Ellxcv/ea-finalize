# ML Dataset Logger Fase 1 — Real-Tick Regression

## Tujuan

Membuktikan bahwa logger `ts7_entry_candidate_v1`:

- tidak mengubah history trading `folder32_v1`;
- menghasilkan relasi candidate, entry, trade, cycle, dan barrier yang lengkap;
- merekonsiliasi financial cycle dengan perubahan balance Strategy Tester.

## Konfigurasi

| Item | Nilai |
| --- | --- |
| Symbol / timeframe | `GOLD.i#` / M1 |
| Periode | 2026-01-04 sampai 2026-01-10 |
| Tick model | Every tick based on real ticks |
| Deposit / leverage | USD 4,000 / 1:500 |
| Baseline preset | `folder32_v1` |
| Preset SHA-256 | `737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651` |
| Control | `InpEnableMlDatasetLogger=false` |
| Treatment | input sama, hanya logger `true` |
| Schema | `ts7_entry_candidate_v1` |
| Treatment RunId | `phase1-regression-on-v4` |

Run ini adalah short integrity regression, bukan sampel training dan bukan evaluasi performa
strategi.

## Hasil parity trading

| Pemeriksaan | Logger OFF | Logger ON | Hasil |
| --- | ---: | ---: | --- |
| Final balance | 4,286.22 | 4,286.22 | identik |
| Original closed | 45 | 45 | identik |
| Winner / loser | 19 / 26 | 19 / 26 | identik |
| Deal event | 210 | 210 | identik |
| Perbedaan urutan deal | — | 0 | lulus |
| Main SL calculation/broker blocks | 0 / 0 | 0 / 0 | identik |

Net change balance adalah `286.22`.

## Hasil integritas dataset

| Pemeriksaan | Hasil |
| --- | ---: |
| Candidate / unique candidate | 45 / 45 |
| Candidate columns | 81 |
| FeatureReady=false | 0 |
| SessionDistanceReady=false | 0 |
| Entry / failed order | 45 / 0 |
| Invalid `AttemptNumber` | 0 |
| Trade outcome | 45 |
| Cycle outcome | 45 |
| Barrier outcome / expected | 90 / 90 |
| Duplicate `(SetupId,HorizonBars)` | 0 |
| Incomplete/ambiguous/data-error barrier | 0 |
| Dataset `DataErrors` journal | 0 |
| Recovery cycle / zero recovery financial | 26 / 0 |
| Sum `CycleNetProfit` | 286.22 |

Business outcome:

| Label | Jumlah |
| --- | ---: |
| `NO_RECOVERY` | 19 |
| `RECOVERY_L1_L3` | 23 |
| `RECOVERY_L4_PLUS` | 3 |

Barrier:

| Horizon | Favorable first | Adverse first |
| --- | ---: | ---: |
| 40 | 25 | 20 |
| 50 | 25 | 20 |

`Sum(CycleNetProfit)=286.22` tepat sama dengan perubahan balance
`4,286.22 - 4,000.00`. Ini juga membuktikan entry/exit commission, swap, dan seluruh posisi
recovery teragregasi ke cycle yang benar pada sample regression.

## Compile dan status

- MetaEditor: `0 errors, 0 warnings`.
- Real-tick regression: lulus.
- Fase 1 observation-only logger: lulus.
- Historical dataset panjang dan audit symbol discontinuity: belum dilakukan; masuk Fase 2.

Raw CSV, manifest, tester report, journal, preset aktual, dan `.ex5` tidak di-commit.
