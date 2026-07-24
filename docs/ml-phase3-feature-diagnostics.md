# Fase 3 — Feature and Label Diagnostics

## Tujuan

Tool ini menjawab dua pertanyaan sebelum menambah kompleksitas model:

1. apakah `Barrier50Outcome` selaras dengan tujuan bisnis menghindari recovery dan L4+;
2. apakah feature memiliki sinyal univariate yang konsisten pada lebih dari satu development run.

Diagnosis hanya memakai development data. Hasilnya tidak memilih final model dan tidak membuka
final OOS.

## Menjalankan diagnosis

~~~powershell
python tools/ml/analyze_feature_diagnostics.py `
  --dataset "C:\local-ml-data\processed\folder32-cci3-v1-dataset-v001\merged_candidates.csv" `
  --output-dir "C:\local-ml-data\artifacts\phase3-folder32-cci3-v1-feature-diagnostic-v001"
~~~

Konfigurasi diagnosis berada di `config/ml-phase3-feature-diagnostics.json`, sedangkan feature
allowlist diambil dari `config/ml-phase3-baseline.json`. Output wajib berada di luar repository.
`--replace-output` hanya dapat mengganti direktori yang sudah memiliki manifest diagnosis yang
sesuai.

Output:

~~~text
feature_summary.csv
feature_by_run.csv
subgroup_diagnostics.csv
label_alignment.csv
label_alignment_summary.csv
high_correlations.csv
diagnostic_report.json
diagnostic_report.md
diagnostic_manifest.json
~~~

`StableAcrossRuns=true` memerlukan arah AUC yang sama dan jarak AUC dari 0,50 minimal 0,03 pada
setiap run. Flag ini hanya screening development; bukan bukti causal, belum mengoreksi multiple
testing, dan tidak boleh dipakai sebagai acceptance gate final.

## Hasil folder 39–40

Dataset berisi 1.080 candidate dari dua run 100% history quality.

Hubungan barrier dengan outcome bisnis stabil:

| Scope | Phi favorable vs no recovery | Phi favorable vs L4+ | AUC favorable untuk no recovery | AUC favorable untuk L4+ |
| --- | ---: | ---: | ---: | ---: |
| Pooled | 0,3698 | -0,1284 | 0,6839 | 0,3904 |
| Folder 39 | 0,3389 | -0,1377 | 0,6715 | 0,3802 |
| Folder 40 | 0,4021 | -0,1210 | 0,7016 | 0,3984 |

Pada entry `FAVORABLE_FIRST`, 69,29% selesai tanpa recovery dan 5,19% mencapai L4+. Pada
`ADVERSE_FIRST`, hanya 32,11% selesai tanpa recovery dan 12,71% mencapai L4+. Karena itu label
barrier-50 tetap dipertahankan.

Hanya tujuh sinyal univariate melewati screening kestabilan, semuanya lemah. Pemisahan terbesar
memiliki pooled AUC sekitar 0,55. Selain itu ditemukan 14 pasangan feature dengan korelasi absolut
minimal 0,90, termasuk cluster ATR/SL, latency/alignment, return/body, dan EMA slope.

Kesimpulan:

- kegagalan baseline bukan disebabkan label barrier yang tidak relevan;
- feature saat ini terlalu lemah dan sebagian redundan untuk memprediksi label tersebut;
- target khusus L4+ belum layak dilatih karena hanya memiliki 101 positive sample;
- model tidak dibekukan dan final OOS `2026.05.03–2026.07.18` tetap belum dibuka.

Catatan hasil lengkap:
[feature diagnostic record](../tuning/runs/2026-07-24_GOLD-i_M1_cci-validity3-feature-diagnostic/RECORD.md).
