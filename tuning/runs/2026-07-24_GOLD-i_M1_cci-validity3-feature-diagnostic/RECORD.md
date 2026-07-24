# CCI Validity 3 — Phase 3 Feature Diagnostic

## Decision

`LABEL_RETAINED — FEATURE_CONTRACT_NEEDS_REVISION`

Diagnosis menggunakan seluruh development data folder 39–40. Final OOS
`2026.05.03–2026.07.18` tidak dibuka.

## Input

| Item | Nilai |
| --- | --- |
| Dataset rows | 1.080 |
| Runs | folder 39 dan folder 40 |
| Dataset SHA-256 | `BCC8B49ACB13DF1075BC776E4D9B36D0AE59DA172F2760E4D627BC5D75255404` |
| Primary label | `Barrier50Outcome` |
| Favorable / adverse | 482 / 598 |
| No recovery / L1–L3 / L4+ | 526 / 453 / 101 |

Folder 38 tidak digunakan karena history quality 16% dan margin-call termination.

## Label alignment

| Scope | Phi favorable vs no recovery | Phi favorable vs L4+ | AUC favorable untuk no recovery | AUC favorable untuk L4+ |
| --- | ---: | ---: | ---: | ---: |
| Pooled | 0,3698 | -0,1284 | 0,6839 | 0,3904 |
| Folder 39 | 0,3389 | -0,1377 | 0,6715 | 0,3802 |
| Folder 40 | 0,4021 | -0,1210 | 0,7016 | 0,3984 |

Contingency pooled:

| Barrier outcome | No recovery | L1–L3 | L4+ |
| --- | ---: | ---: | ---: |
| `FAVORABLE_FIRST` | 334 (69,29%) | 123 (25,52%) | 25 (5,19%) |
| `ADVERSE_FIRST` | 192 (32,11%) | 330 (55,18%) | 76 (12,71%) |

Hubungan memiliki arah yang sama pada kedua run. `Barrier50Outcome` tetap dipakai sebagai primary
quality label; menggantinya bukan tindakan berikutnya.

## Stable univariate screening

Syarat screening: arah sama pada kedua run dan jarak AUC dari 0,50 minimal 0,03 di setiap run.

| Target | Feature | Pooled AUC | Minimum run separation | Arah |
| --- | --- | ---: | ---: | --- |
| Barrier favorable | `STMTFAgeBars` | 0,4509 | 0,0471 | lebih rendah lebih favorable |
| Barrier favorable | `InitialSLPoints` | 0,5374 | 0,0399 | lebih tinggi lebih favorable |
| L4+ | `TimeOfDayCos` | 0,5456 | 0,0378 | lebih tinggi lebih berisiko |
| Barrier favorable | `BarrierATR` | 0,5405 | 0,0343 | lebih tinggi lebih favorable |
| Barrier favorable | `SignalAgeBars` | 0,4643 | 0,0341 | lebih rendah lebih favorable |
| Barrier favorable | `ATR_M5` | 0,5381 | 0,0339 | lebih tinggi lebih favorable |
| L4+ | `TickVolume` | 0,4684 | 0,0308 | lebih rendah lebih berisiko |

Semua efek masih lemah. Tujuh feature ini tidak boleh langsung dijadikan rule trading karena
screening memakai seluruh development data dan belum mengoreksi multiple testing.

## Redundancy

Ada 14 pasangan dengan absolute Spearman correlation minimal 0,90. Contoh utama:

- `STMTFSignalAlign` dengan latency MTF: sekitar `-1,00`;
- `Return1ATR` dengan `BodyATR`: `0,9954`;
- `EMASlope5ATR` dengan `EMASlope10ATR`: `0,9764`;
- `SpreadATR` dengan `BarrierATR`: `-0,9412`;
- `BarrierATR` dengan `InitialSLPoints`: `0,9222`;
- `BarrierATR` dengan `ATR_M5`: `0,9099`.

Ini menjelaskan sebagian risiko overfit dan membuat feature importance model sulit ditafsirkan.

## Interpretation

1. Label barrier memiliki hubungan bisnis yang cukup jelas dan stabil.
2. Baseline gagal karena feature tidak cukup membedakan favorable/adverse entry, bukan karena label
   acak.
3. Menambah model yang lebih kompleks sekarang berisiko hanya mempelajari noise.
4. Model khusus L4+ ditunda karena hanya ada 101 positive sample.
5. Langkah berikutnya harus tetap di Fase 3: revisi feature contract atau fold-local feature
   reduction, kemudian kumpulkan ulang development data bila schema berubah.

## Artifact provenance

Lokasi lokal:

`C:\Users\ACER\Documents\TS7_ML\artifacts\phase3-folder32-cci3-v1-feature-diagnostic-v001`

| Artifact | SHA-256 |
| --- | --- |
| `diagnostic_manifest.json` | `724FBD2707C08B3FC4A90CC730490A8575CDABE815D7133FAFD09705704E5EC8` |
| `diagnostic_report.json` | `192C7E7A19FC2979DA6A7695871D135C130221FA7D018129777DDE58B46B8ECA` |
| `feature_summary.csv` | `5EE782A124E9CBD65CA67AB9C26B40C03741FE7F68EBEEEB40E038079645C8EE` |
| `label_alignment_summary.csv` | `FC31060857C644F4F2E455EED9F892056BA973E44C97EBA745CFF2315A570C0C` |

Raw dataset dan diagnostic artifact tetap lokal dan tidak di-commit.
