# Folder 34 — Phase 2 ML Diagnostic Audit

## Status

`DIAGNOSTIC_ONLY — RETAINED RUN REJECTED`

Raw logger lengkap dan konsisten, tetapi report memakai initial deposit USD 3.000. Kontrak run
retained Fase 2 menetapkan USD 4.000. Dataset ini boleh dipakai untuk diagnosis awal, tetapi tidak
boleh menjadi dataset training retained atau pengganti run yang sesuai kontrak.

## Provenance

| Item | Nilai |
| --- | --- |
| RunId | `folder32_v1_GOLD-i_M1_20260104_20260502_r01` |
| Source revision | `3dd654c62607b2333fde9473900d97f997bea48e` |
| Strategy preset SHA-256 | `737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651` |
| EA EX5 SHA-256 | `D4EBF165D5B66BEDD397353C7B0352661F41057FC37491013E7EBC39171ABC8C` |
| Report SHA-256 | `D3D6287D406A4FBBC46B67FFAA8CE89078BF2E7B46707AE64E156A9C5F19724B` |
| Symbol / timeframe | `GOLD.i#` / M1 |
| Period | 2026.01.04–2026.05.02 |
| Model | 99% real ticks |
| Bars / ticks | 115.508 / 32.562.123 |
| Deposit aktual / kontrak | USD 3.000 / USD 4.000 |
| Leverage | 1:500 |

`collection_context.json` mencatat nilai aktual dari report; metadata tidak dikoreksi secara manual.

## Strategy Tester fingerprint

| Metric | Folder 34 |
| --- | ---: |
| Total net profit | 7.020,93 |
| Profit factor | 1,63 |
| Equity DD maximal | 2.949,11 (34,62%) |
| Equity DD relative | 49,38% (2.392,40) |
| Total trades / deals | 2.092 / 4.184 |
| Short won | 57,78% |
| Long won | 59,72% |

Profit, trade, bars, ticks, dan nilai drawdown absolut sama dengan baseline folder 32. Persentase
drawdown berbeda karena deposit awal berbeda.

## Dataset diagnostic

- 982 candidate, entry, trade outcome, dan cycle outcome;
- 1.964 barrier outcome, tepat dua untuk setiap candidate;
- seluruh `FeatureReady`, `StructureReady`, dan `SessionDistanceReady` bernilai `true`;
- tidak ada schema error, duplicate, orphan, missing pairing, atau financial mismatch;
- sum `CycleNetProfit` = 7.020,93 dan cocok dengan perubahan balance aktual;
- satu warning: seluruh record masih `SYMBOL_MIGRATION_UNVERIFIED`.

Distribusi outcome:

| Outcome | Jumlah | Persentase |
| --- | ---: | ---: |
| `NO_RECOVERY` | 569 | 57,94% |
| `RECOVERY_L1_L3` | 323 | 32,89% |
| `RECOVERY_L4_PLUS` | 90 | 9,16% |
| Barrier 50 favorable first | 462 | 47,05% |
| Barrier 50 adverse first | 520 | 52,95% |

Original trade hanya menghasilkan net 190,10 dengan win rate 57,54% dan profit factor sekitar
1,06. Cycle menghasilkan 7.020,93. Artinya profit baseline sangat bergantung pada recovery, sesuai
masalah bisnis yang ingin diperbaiki.

Barrier 50 memiliki hubungan kuat dengan outcome bisnis: 372 dari 462 `FAVORABLE_FIRST` keluar
tanpa recovery, sedangkan 323 dari 520 `ADVERSE_FIRST` masuk recovery dan 72 di antaranya mencapai
L4+. Ini mendukung penggunaan label price-path sebagai target kualitas entry.

## Sinyal rule awal

Analisis ini deskriptif dan sudah melihat window yang sama dengan baseline; belum boleh menjadi
threshold produksi atau klaim out-of-sample.

- spread/ATR kuartil terendah memiliki `NO_RECOVERY` 74,29%, sedangkan kuartil tertinggi 47,15%;
- `LateConfirmMask=0` memiliki `NO_RECOVERY` 82,14% dari 28 sample, tetapi jumlahnya masih kecil;
- `LateConfirmMask=1` dan `5` menunjukkan barrier favorable serta/atau L4+ yang lebih buruk;
- displacement sekitar 0,95–1,44 ATR memberi L4+ 5,69%, sedangkan beberapa wilayah lain mencapai
  sekitar 13%;
- London session memiliki L4+ 7,24%, lebih rendah dari Asia 12,06%.

Feature saling berinteraksi, sehingga rule satu-dimensi ini belum cukup untuk menghapus indikator
atau menetapkan filter. Fase 3 tetap perlu model sederhana dan validasi temporal.

## Keputusan

1. Pertahankan raw `r01` tanpa edit sebagai bukti diagnostik.
2. Audit config diperketat agar window, deposit, currency, dan leverage mismatch menjadi error.
3. Ulangi run dengan RunId `folder32_v1_GOLD-i_M1_20260104_20260502_r02`, deposit USD 4.000,
   leverage 1:500, dan setting strategi yang sama.
4. Jangan membuka final OOS sebelum `r02` lolos seluruh gate.

Preset pengulangan lokal:

~~~text
MQL5\Profiles\Tester\folder32-v1-ml-retained-20260104-20260502-r02.set
SHA-256: 7C2BF01474A1D304E84116962D12AE923CAAF12EFD3BE4989AF7B387A9735F1E
~~~
