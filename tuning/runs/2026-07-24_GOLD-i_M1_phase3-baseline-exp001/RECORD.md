# Phase 3 Baseline Experiment `exp001`

## Status

`EXPLORATORY_NOT_FROZEN — NO DEPLOYABLE MODEL`

Pipeline Phase 3 berhasil dijalankan pada retained dataset folder 35. Eksperimen membandingkan
regularized Logistic Regression dengan deterministic shallow Random Forest melalui tiga
chronological walk-forward fold.

## Provenance

| Item | Nilai |
| --- | --- |
| Dataset rows | 982 |
| Dataset SHA-256 | `4B76D4F7D50A7DF0FADBC9922C033B28087ECBA3E1259EC798F9390606353D5D` |
| Script SHA-256 | `57FA4B68C25DDDF4CCD7A9B582898D498D763C8974A2AFEDB58BFA3D05406C9D` |
| Config SHA-256 | `C7CAFE9433CE59CEDBDBB004477A238A571C83C98F6494DCB7791093728F6291` |
| Experiment manifest SHA-256 | `AB3C69DD181B9CAB03B66F9C8513E2EA8B284596B0F2AB40AE233535C9DE98F2` |
| Experiment report SHA-256 | `67242C875E4601A71B0EFEFE1CC07429AD68613048F12A6830308FC1AF30563E` |
| Prediction rows | 1.170, yaitu 585 per model |
| Final OOS | Belum dibuka |

Artefak lengkap disimpan lokal di `TS7_ML/artifacts/phase3-folder32-v1-exp001` dan tidak di-commit.

## Safeguards

- feature allowlist dan leakage denylist eksplisit;
- preprocessing fit pada train saja;
- chronological expanding folds;
- purge/embargo 50 menit pada kedua sisi boundary;
- grouping `SignalTime + Direction`;
- Platt calibration fit pada validation;
- threshold dipilih pada validation;
- evaluation tidak digunakan untuk refit;
- model dan threshold diberi status non-frozen.

## Aggregate future-fold result

| Model | ROC-AUC | PR-AUC | Log loss | Brier | Retained | Winner rejected | L4+ rejected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Logistic Regression | 0,4977 | 0,4533 | 0,6922 | 0,2495 | 93,33% | 5,95% | 7,14% |
| Shallow Random Forest | 0,4854 | 0,4355 | 0,6974 | 0,2520 | 86,15% | 15,18% | 12,50% |

Logistic Regression dipilih sebagai exploratory champion hanya karena Brier/log loss relatif
lebih baik. Nilai ROC-AUC 0,498 tidak menunjukkan separation yang dapat digunakan.

Business proxy Logistic Regression:

- original win rate 57,44% menjadi 57,88%;
- recovery entry rate turun sekitar 1,10% relatif;
- active day retention 100%;
- legacy winner rejected 5,95%;
- L4+ rejected 7,14%.

Proxy tidak mewakili actual portfolio result. Net/cycle result yang berubah akibat veto baru sah
setelah Strategy Tester `ML_FILTER`, dan eksperimen ini belum memberi alasan untuk masuk ke sana.

## Decision

1. Tidak freeze model, feature subset, atau threshold.
2. Tidak implement `ML_SHADOW`, `ML_FILTER`, atau ONNX dari experiment ini.
3. Tambah development data non-overlap hingga sekitar 2.000–5.000 candidate.
4. Audit gabungan dan rerun pipeline yang sama.
5. Final OOS tetap tertutup.
