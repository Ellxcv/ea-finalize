# Fase 2 — Historical Dataset and Audit

## Status

Tooling audit dan merge sudah diimplementasikan. Run diagnostik pertama (`r01`, folder 34) ditolak
karena memakai deposit USD 3.000. Pengulangan `r02` (folder 35) memakai USD 4.000 dan lolos gate:
982 candidate retained, nol error, serta satu warning `SYMBOL_MIGRATION_UNVERIFIED`.

Dataset ini cukup untuk diagnosis dan eksplorasi model sederhana Fase 3, tetapi belum mencapai
target awal penelitian 2.000–5.000 candidate. Final OOS tetap belum dibuka.

Fase 2 tidak melatih model. Outputnya adalah dataset candidate yang sudah lolos gate provenance,
schema, pairing, label, financial, duplicate, serta analisis rule deskriptif.

Audit tooling mendukung `ts7_entry_candidate_v1` dan `ts7_entry_candidate_v2`, tetapi kedua schema
tidak boleh digabung dalam satu output audit. V2 juga mewajibkan `FeatureReadyV2=true`, 15 feature
entry-state baru tanpa `NA`, dan manifest `entry_state_strength_distance_v2`.

Collection v2 folder 43–44 sudah selesai: 2/2 run diterima, 1.080/1.080 candidate retained, nol
error, dan dua warning `SYMBOL_MIGRATION_UNVERIFIED`. Processed dataset lokal:
`folder32-cci3-entry-v2-dataset-v001`.

## Struktur data lokal

Raw dan processed data wajib berada di luar repository:

~~~text
<local-ml-data>/
  raw/
    <run-id>/
      candidate_setups.csv
      trade_entries.csv
      trade_outcomes.csv
      cycle_outcomes.csv
      barrier_outcomes.csv
      run_manifest.json
      collection_context.json
  processed/
    <dataset-version>/
      merged_candidates.csv
      excluded_candidates.csv
      audit_issues.csv
      run_inventory.csv
      rule_analysis.csv
      audit_config.snapshot.json
      audit_report.json
      audit_report.md
~~~

`audit_dataset.py` menolak output yang berada di dalam repository dan tidak menimpa output lama
tanpa `--replace-output`.

## 1. Persiapan build retained

1. Checkout commit yang akan dipakai dan pastikan working tree source sudah ditinjau.
2. Compile melalui MetaEditor: harus `0 errors, 0 warnings`.
3. Isi preset logger:

~~~text
InpEnableMlDatasetLogger=true
InpMlStrategyVersion=folder32_v1
InpMlSourceRevision=<full Git commit>
InpMlPresetHash=737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651
InpMlRunId=<unique run id>
InpMlDatasetDirectory=TS7_ML
InpMlDataIntegrityFlag=SYMBOL_MIGRATION_UNVERIFIED
InpMlFlushEveryRecords=50
~~~

Jangan mengubah input entry, SL, trailing, session, recovery, lot, atau dependency baseline.
Gunakan M1, `Every tick based on real ticks`, deposit USD 4,000, dan leverage 1:500.

Format RunId yang disarankan:

~~~text
folder32_v1_GOLD-i_M1_YYYYMMDD_YYYYMMDD_r01
~~~

Periode antar-run tidak boleh overlap. Jalankan satu continuous window bila tersedia; pemotongan
window dapat mereset balance/recovery dan mengubah kesempatan entry di boundary.

Run retained pertama memakai `2026.01.04` sampai `2026.05.02`, yaitu window baseline folder 32.
Window ini sudah pernah dilihat sehingga hanya menjadi development/diagnostic dataset, bukan final
out-of-sample. Jangan membuka periode calon OOS lain sebelum coverage run pertama ditinjau dan
window OOS dibekukan secara eksplisit.

### Collection schema v2 — CCI validity 3

Setelah parity folder 41/42 lulus, collection entry-state v2 memakai:

~~~text
InpEnableMlDatasetLogger=true
InpMlStrategyVersion=folder32_cci3_v1
InpMlSourceRevision=eaa396be6ad526bb17ac8e150e69b5718cffbb0e
InpMlPresetHash=7CA8B8F6C99073EC78147B42EFD347E7B0A1972EA834CD18897E0F5EAFBAB635
InpMlRunId=<unique run id>
InpMlDatasetDirectory=TS7_ML
InpMlDataIntegrityFlag=SYMBOL_MIGRATION_UNVERIFIED
InpMlFlushEveryRecords=50
~~~

Gunakan hanya dua development window yang history quality-nya sudah terbukti:

~~~text
2025.09.01–2026.01.03
2026.01.04–2026.05.02
~~~

Audit dengan `config/ml-dataset-audit-folder32-cci3-v2.json`. Config ini juga mewajibkan source
revision tepat, schema v2, `FeatureReadyV2=true`, real ticks, history quality minimal 99%, dan
termination `COMPLETED`. Periode `2025.05.01–2025.08.31` tidak digunakan karena run sebelumnya
memiliki history quality 16% dan margin call. Final OOS `2026.05.03–2026.07.18` tetap tersegel.

Retained build dan preset lokal berada di:

~~~text
C:\Users\ACER\Documents\TS7_ML\retained-builds\
  eaa396be6ad526bb17ac8e150e69b5718cffbb0e\
    testing_strat_7.ex5
    folder32-cci-validity3-strategy-original.set
    folder32-cci3-entry-v2-dev-20250901-20260103-r01.set
    folder32-cci3-entry-v2-dev-20260104-20260502-r01.set
    build_manifest.json
~~~

Load preset logger yang sesuai periode ke Strategy Tester. Gunakan strategy-only preset saat
membuat `collection_context.json`, karena hash itulah yang dibekukan di `run_manifest.json`.

## 2. Collection context

Logger tidak mengetahui path report, hash binary/dependency, model tick, atau final balance tester.
Setelah setiap run, buat sidecar dengan `create_collection_context.py`.

Contoh PowerShell:

~~~powershell
python tools/ml/create_collection_context.py `
  --run-dir "C:\local-ml-data\raw\<run-id>" `
  --from-date 2026.01.04 `
  --to-date 2026.05.02 `
  --initial-deposit 4000 `
  --final-balance 11020.93 `
  --currency USD `
  --leverage 1:500 `
  --candidate-count <jumlah-candidate> `
  --bars <jumlah-bars> `
  --ticks <jumlah-ticks> `
  --deal-events <jumlah-deal-events> `
  --history-quality-percent 100 `
  --termination-status COMPLETED `
  --preset "C:\path\folder32-v1.set" `
  --ea-ex5 "C:\path\testing_strat_7.ex5" `
  --report "C:\path\report.htm" `
  --dependency "cciCustomFix/cciCustomFix.ex5=C:\path\cciCustomFix.ex5" `
  --dependency "hiloFix/hiloFix.ex5=C:\path\hiloFix.ex5" `
  --dependency "parabolicSarFix/parabolicSarFix.ex5=C:\path\parabolicSarFix.ex5" `
  --dependency "superTrend/superTrend.ex5=C:\path\superTrend.ex5" `
  --dependency "accountStatus/accountStatus.ex5=C:\path\accountStatus.ex5"
~~~

Tool menghitung hash dari file aktual. Ia menolak preset bila hash-nya berbeda dari
`run_manifest.json`. Jangan mengedit hash secara manual.

## 3. Menjalankan audit

~~~powershell
python tools/ml/audit_dataset.py `
  --raw-root "C:\local-ml-data\raw" `
  --output-dir "C:\local-ml-data\processed\folder32-v1-dataset-v001"
~~~

Exit code:

| Code | Makna |
| ---: | --- |
| 0 | audit selesai tanpa error |
| 2 | laporan dibuat, tetapi gate menemukan error |
| 3 | command/input/output tidak valid dan audit tidak dapat dijalankan |

`--allow-audit-errors` hanya untuk inspeksi regression/fixture. Jangan memakainya untuk menyatakan
dataset retained lulus.

## 4. Gate otomatis

Run ditolak seluruhnya bila menemukan error:

- schema/header/column mismatch;
- source revision bukan Git commit;
- strategy, preset, symbol, timeframe, atau barrier contract mismatch;
- context, artifact hash, dependency hash, atau tester metadata hilang;
- window test, initial deposit, currency, atau leverage berbeda dari audit config;
- history quality di bawah minimum atau termination status tidak diterima oleh audit config;
- bukan real-tick model;
- duplicate key dalam run;
- orphan/missing pairing candidate-entry-trade-cycle-barrier;
- feature wajib `NA` ketika `FeatureReady=true`;
- ATR/direction/time/barrier formula invalid;
- attempt number tidak berurutan;
- trade/cycle financial tidak reconcile;
- sum `CycleNetProfit` tidak sama dengan perubahan balance;
- business label tidak konsisten dengan maximum recovery level;
- duplicate SetupId antar-run memiliki isi berbeda.

Candidate valid tetapi tidak layak training dikeluarkan secara individual bila:

- order tidak terisi;
- trade/cycle belum selesai;
- `FeatureReady=false`;
- barrier 40/50 bukan `FAVORABLE_FIRST` atau `ADVERSE_FIRST`;
- cycle `INCOMPLETE`;
- merupakan duplicate identik yang sudah diwakili run lebih awal.

## 5. Analisis rule sebelum ML

`rule_analysis.csv` menghasilkan statistik deskriptif:

- favorable rate barrier 50;
- `NO_RECOVERY` rate;
- `RECOVERY_L4_PLUS` rate;
- sum original dan cycle net profit.

Grouping categorical mencakup arah, tipe CCI, late-confirm mask, session, dan data-integrity flag.
Feature numeric dibagi menjadi empat quantile. `MeetsMinimumCount=false` berarti kelompok terlalu
kecil untuk dijadikan dasar keputusan.

Analisis ini tidak memilih threshold dan tidak boleh diperlakukan sebagai hasil OOS. Rule yang
menarik harus dibekukan dan diuji pada window berikutnya.

## 6. Symbol migration

Selama tanggal transisi `GOLD#` ke `GOLD.i#` belum dibuktikan, gunakan:

~~~text
InpMlDataIntegrityFlag=SYMBOL_MIGRATION_UNVERIFIED
~~~

Pipeline mempertahankan flag dan melaporkan distribusinya, tetapi memberi warning. Setelah bukti
broker/history tersedia, buat run baru atau context baru dengan flag/version yang eksplisit;
jangan mengubah CSV raw yang sudah dibuat. Kesimpulan Fase 2 harus dilaporkan dengan dan tanpa
interval yang dicurigai.

## 7. Definition of done Fase 2

Fase 2 baru selesai secara data bila:

- seluruh run retained memakai source commit/preset/dependency yang cocok;
- audit error berjumlah nol;
- tidak ada duplicate sample independen;
- reconciliation financial lulus;
- coverage waktu/regime serta data-integrity flag dilaporkan;
- candidate valid cukup untuk diagnosis;
- analisis rule sederhana selesai;
- final OOS masih belum dibuka.

Tooling selesai bukan berarti dataset sudah selesai. Training Logistic Regression baru dimulai di
Fase 3 setelah gate ini terpenuhi.
