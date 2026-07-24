# ML Entry-State Schema v2 Implementation

## Status

`IMPLEMENTED — COMPILED — STRATEGY TESTER PARITY PENDING`

## Tujuan

Menambah informasi candidate-time yang berpotensi membedakan favorable/adverse entry setelah
full dan compact v1 model sama-sama gagal menemukan sinyal walk-forward.

## Perubahan

- schema logger menjadi `ts7_entry_candidate_v2`;
- seluruh 81 kolom v1 dipertahankan;
- 15 numeric entry-state feature dan `FeatureReadyV2` ditambahkan;
- candidate header menjadi 97 kolom;
- manifest menyimpan kontrak feature dan parameter ADX;
- dedicated observation-only ADX handle hanya dibuat bila logger ON;
- audit dataset mendukung v1/v2 tanpa mengizinkan cross-schema merge;
- config training dan feature diagnostic v2 ditambahkan.

Feature baru:

~~~text
AdxValue,AdxSlope1,DiGapDir,DiGapSlopeDir,
CciSlope1Dir,CciSlope3Dir,ATRChange1,
HiLoDistanceATR,HiLoLineSlopeATR,
PsarDistanceATR,PsarLineSlopeATR,
STDistanceATR,STLineSlopeATR,
STMTFDistanceATR,STMTFLineSlopeATR
~~~

Semua memakai closed bars yang tersedia pada candidate time. Tidak ada outcome, future price,
trade result, atau recovery result yang dipakai sebagai feature.

## Behavior boundary

Saat logger OFF:

- dedicated ML ADX handle tidak dibuat;
- snapshot v2 tidak dieksekusi;
- aturan entry/exit/SL/lot/trailing/recovery tidak berubah.

Saat logger ON, output tetap observation-only dan tidak memberi izin/veto order.

## Verification

| Pemeriksaan | Hasil |
| --- | --- |
| MetaEditor XM Global build | `0 errors, 0 warnings` |
| Python schema/audit/model tests | lulus |
| MQL header vs Python v2 contract | 97 kolom, lulus |
| Audit v1 backward compatibility | 1.080/1.080 candidate retained, 0 error |
| Audit v2 readiness/merge fixture | lulus |
| Logger OFF/ON Strategy Tester parity | pending |
| Live/runtime model | tidak dibuat |
| Final OOS | belum dibuka |

Compile log lokal:

`C:\Users\ACER\Documents\TS7_ML\builds\schema-v2-dev\compile-xm-current-worktree-final.log`

Raw logs, `.ex5`, dan compile artifact tetap berada di luar version control.

## Required next validation

Jalankan short real-tick control/treatment dengan input strategi identik:

- logger OFF versus logger ON;
- periode singkat yang memiliki cukup candidate;
- final balance, deal sequence, dan original/recovery outcome harus identik;
- candidate ON harus 97 kolom;
- `FeatureReady=false` dan `FeatureReadyV2=false` harus nol;
- seluruh field baru harus finite dan memakai closed-bar snapshot.

Dataset development panjang v2 belum boleh dikumpulkan sebelum parity ini lulus.
