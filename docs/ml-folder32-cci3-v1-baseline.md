# Challenger Baseline `folder32_cci3_v1`

## Status

`CHALLENGER_PARTIALLY_VALIDATED — NOT PROMOTED`

Challenger ini dibuat setelah `folder32_v1` validity 5 mengalami practical margin call pada
development window 2025.09.01–2026.01.03. Ia belum menggantikan baseline ML, belum boleh digabung
dengan dataset `folder32_v1`, dan belum membatalkan hasil Phase 3 sebelumnya.

Folder 39 dan 40 sudah lolos audit dengan total 1.080 candidate. Folder 38 ditolak karena history
quality hanya 16% dan run berhenti dengan incomplete L10 recovery. Pada window Jan–Mei yang dapat
dibandingkan langsung, validity 3 tidak meningkatkan original win rate atau menurunkan L4+ rate.

Eksperimen ML Phase 3 pada folder 39–40 juga tidak lolos gate. ROC-AUC kedua baseline sekitar
0,49, L4+ rejection hanya 6,45%, dan tidak ada model/threshold yang dibekukan. Final OOS
`2026.05.03–2026.07.18` tetap tersegel.

## Satu-satunya perubahan strategi

~~~text
folder32_v1:       InpCciSignalValidityBars=5
folder32_cci3_v1:  InpCciSignalValidityBars=3
~~~

Seluruh input entry, indicator, SL, trailing, session, lot, recovery, dan risk control lainnya
tetap mengikuti frozen baseline folder 32.

## Provenance

| Item | Nilai |
| --- | --- |
| Strategy version | `folder32_cci3_v1` |
| Source revision | `3dd654c62607b2333fde9473900d97f997bea48e` |
| EA EX5 SHA-256 | `D4EBF165D5B66BEDD397353C7B0352661F41057FC37491013E7EBC39171ABC8C` |
| Strategy-only preset SHA-256 | `7CA8B8F6C99073EC78147B42EFD347E7B0A1972EA834CD18897E0F5EAFBAB635` |
| Parent strategy | `folder32_v1` |
| Parent preset SHA-256 | `737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651` |

Strategy-only preset lokal:

~~~text
TS7_ML\retained-builds\3dd654c62607b2333fde9473900d97f997bea48e\
  folder32-cci-validity3-strategy-original.set
~~~

## Required comparison windows

| Window | Logger preset | File SHA-256 |
| --- | --- | --- |
| 2025.05.01–2025.08.31 | `folder32-cci3-ml-dev-20250501-20250831-r01.set` | `C783F6F8005002A6B5D5BEF11FA1D1B76E44605B46284DF3D5FE401087EBF20A` |
| 2025.09.01–2026.01.03 | `folder32-cci3-ml-dev-20250901-20260103-r01.set` | `A3EAABBB5B9EABCB8F53B7E8A36C3300E552A03CB109766667926081BB16D61B` |
| 2026.01.04–2026.05.02 | `folder32-cci3-ml-dev-20260104-20260502-r01.set` | `4CD965C3BA52DB1C9C2F1789CA2D5C685B0953D7AA8DBD0C0F138A611F2A28E3` |

Setiap run memakai `GOLD.i#`, M1, real ticks, deposit USD 4.000, leverage 1:500, fixed lot
baseline, dan `SYMBOL_MIGRATION_UNVERIFIED`.

## Promotion rule

Validity 3 baru boleh menjadi baseline berikutnya bila:

1. ketiga window selesai tanpa stop-out/margin call;
2. provenance, pairing, label, duplicate, dan financial audit lulus;
3. hasil dibandingkan secara konsisten terhadap validity 5 pada window yang tersedia;
4. penurunan jumlah candidate tidak menghilangkan coverage trading secara berlebihan;
5. keputusan promosi dicatat sebelum training ulang.

Jika dipromosikan, model wajib dilatih ulang hanya dari dataset `folder32_cci3_v1`. Dataset/model
`folder32_v1` tidak boleh diteruskan seolah-olah strateginya sama.
