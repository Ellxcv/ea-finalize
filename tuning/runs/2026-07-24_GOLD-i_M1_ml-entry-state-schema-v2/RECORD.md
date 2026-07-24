# ML Entry-State Schema v2 Implementation

## Status

`IMPLEMENTED — COMPILED — STRATEGY TESTER PARITY PASSED`

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
| Logger OFF/ON Strategy Tester parity | lulus, folder 41/42 |
| Live/runtime model | tidak dibuat |
| Final OOS | belum dibuka |

Compile log lokal:

`C:\Users\ACER\Documents\TS7_ML\builds\schema-v2-dev\compile-xm-current-worktree-final.log`

Raw logs, `.ex5`, dan compile artifact tetap berada di luar version control.

## Retained collection build

Build bersih untuk collection validity 3 dibuat langsung dari source revision
`eaa396be6ad526bb17ac8e150e69b5718cffbb0e`:

~~~text
C:\Users\ACER\Documents\TS7_ML\retained-builds\
  eaa396be6ad526bb17ac8e150e69b5718cffbb0e\
~~~

| Artifact | SHA-256 |
| --- | --- |
| `testing_strat_7.ex5` | `66DC93D78182EE9534B3C4FFD0051F9DE1ECB5718525B99D24050ADA5EDBA42A` |
| strategy-only preset | `7CA8B8F6C99073EC78147B42EFD347E7B0A1972EA834CD18897E0F5EAFBAB635` |
| logger preset Sep–Jan | `F68C7283EF944FA2BA603162CC6ECD640076A93E6E759C8E25D917FBA4B458FF` |
| logger preset Jan–Mei | `7FB46778B34AA5FE2F5A3D479C5BAEA015B2112D6B0D1059F5D85263C6FC96F5` |

Compile retained menghasilkan `0 errors, 0 warnings`. Preset baru berbeda dari preset logger v1
hanya pada `InpMlSourceRevision` dan `InpMlRunId`; seluruh input trading identik.

## Strategy Tester parity — folder 41/42

Control folder 41 memakai logger OFF dan treatment folder 42 memakai logger ON pada
`GOLD.i#`, M1, `2026.01.04–2026.01.10`, real ticks, dan history quality 100%. Seluruh input
trading identik; lima perbedaan `.set` hanya berada pada enable/metadata ML.

| Pemeriksaan | OFF | ON | Hasil |
| --- | ---: | ---: | --- |
| Total net profit | 227,29 | 227,29 | identik |
| Balance DD maximal | 49,52 (1,18%) | 49,52 (1,18%) | identik |
| Equity DD maximal | 118,00 (2,84%) | 118,00 (2,84%) | identik |
| Total trades / deals | 84 / 168 | 84 / 168 | identik |
| Result, order, dan deal rows | — | — | identik |

Run ON menghasilkan 38 candidate/cycle dan 76 barrier outcome. Header berisi 97 kolom,
`FeatureReady=false` dan `FeatureReadyV2=false` sama-sama nol, seluruh 15 field baru finite,
tidak ada order gagal, dan sum `CycleNetProfit=227,29` cocok dengan report.

Manifest folder 42 salah dilabeli `folder32_v1` meskipun input aktual memakai
`InpCciSignalValidityBars=3`. Karena itu run ini hanya dipakai sebagai bukti parity dan tidak
menjadi retained training data.

## Required next validation

Kumpulkan ulang dua development window validity 3 dengan config
`config/ml-dataset-audit-folder32-cci3-v2.json`. Final OOS
`2026.05.03–2026.07.18` tetap belum boleh dibuka.
