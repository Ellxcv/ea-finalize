# Kontrak Dataset `ts7_entry_candidate_v2`

## Status dan tujuan

Schema v2 memperluas logger observation-only v1 dengan entry-state strength dan distance feature.
Tujuannya memberi model informasi yang belum tersedia ketika baseline v1 menghasilkan ROC-AUC
sekitar 0,49.

Perubahan ini tidak mengubah entry, exit, stop loss, lot, trailing, recovery, atau risk control.
Seluruh feature baru hanya dihitung ketika `InpEnableMlDatasetLogger=true`, memakai data yang sudah
tertutup sebelum candidate order dikirim.

Schema v1 tetap didukung oleh audit tooling untuk dataset historis, tetapi run v1 dan v2 tidak
boleh digabung dalam satu dataset/model.

## Candidate columns

Schema v2 mempertahankan seluruh 81 kolom v1 lalu menambahkan 16 kolom sebelum
`DataIntegrityFlag`:

~~~text
FeatureReadyV2,
AdxValue,AdxSlope1,DiGapDir,DiGapSlopeDir,
CciSlope1Dir,CciSlope3Dir,ATRChange1,
HiLoDistanceATR,HiLoLineSlopeATR,
PsarDistanceATR,PsarLineSlopeATR,
STDistanceATR,STLineSlopeATR,
STMTFDistanceATR,STMTFLineSlopeATR
~~~

Total `candidate_setups.csv`: 97 kolom.

## Timing dan normalisasi

Notasi:

- `d`: `1` untuk BUY dan `-1` untuk SELL;
- `P`: candidate reference price;
- `ATR`: ATR RMA(14) M1 pada candle terakhir yang sudah tertutup;
- subscript `t-1`: closed bar sebelum snapshot saat ini.

| Feature | Definisi |
| --- | --- |
| `AdxValue` | ADX closed-bar, mengikuti timeframe, DMI period, dan smoothing input EA |
| `AdxSlope1` | `ADX(t) - ADX(t-1)` setelah smoothing yang sama |
| `DiGapDir` | `d × (+DI(t) - -DI(t))` |
| `DiGapSlopeDir` | `d × ((+DI(t)- -DI(t)) - (+DI(t-1)- -DI(t-1)))` |
| `CciSlope1Dir` | `d × (CCI(t) - CCI(t-1))` |
| `CciSlope3Dir` | `d × (CCI(t) - CCI(t-3)) / 3` |
| `ATRChange1` | `ATR(t) / ATR(t-1) - 1` |
| `HiLoDistanceATR` | `d × (P - HiLoLine(t)) / ATR` |
| `HiLoLineSlopeATR` | `d × (HiLoLine(t) - HiLoLine(t-1)) / ATR` |
| `PsarDistanceATR` | `d × (P - PSAR(t)) / ATR` |
| `PsarLineSlopeATR` | `d × (PSAR(t) - PSAR(t-1)) / ATR` |
| `STDistanceATR` | `d × (P - active ST line(t)) / ATR` |
| `STLineSlopeATR` | `d × (active ST line(t) - active ST line(t-1)) / ATR` |
| `STMTFDistanceATR` | Formula distance yang sama untuk SuperTrend MTF |
| `STMTFLineSlopeATR` | Formula slope yang sama untuk SuperTrend MTF |

HiLo memakai MA-low sebagai line BUY dan MA-high sebagai line SELL. PSAR/SuperTrend memakai
main-strategy timeframe. SuperTrend MTF memakai `InpSTFilterTF`. Jika filter MTF disabled, kedua
feature MTF bernilai netral `0`; jika enabled tetapi buffer tidak dapat dibaca,
`FeatureReadyV2=false`.

Nilai distance positif berarti harga berada di sisi line yang mendukung arah candidate. Nilai
slope positif berarti line bergerak mengikuti arah candidate.

## Readiness

`FeatureReady` mempertahankan arti v1. `FeatureReadyV2=true` hanya bila:

- seluruh feature wajib v1 siap;
- ATR previous, ADX/DI, dan CCI velocity dapat dibaca;
- snapshot distance/slope HiLo, PSAR, SuperTrend, dan MTF aktif dapat dibaca;
- tidak ada nilai wajib baru yang missing/non-finite.

Audit v2 memerlukan kedua readiness flag `true` dan menolak `NA` pada feature wajib v1/v2.

## Manifest v2

`run_manifest.json` menambah:

~~~text
feature_contract=entry_state_strength_distance_v2
feature_snapshot=CLOSED_BARS_ONLY_AT_CANDIDATE
adx_timeframe
adx_dmi_period
adx_smoothing_enabled
adx_smoothing_period
~~~

Audit memeriksa feature-contract, snapshot boundary, dan parameter ADX minimum. Preset hash serta
source revision tetap menjadi provenance utama.

## Tooling

- `tools/ml/audit_dataset.py` mendukung schema v1 dan v2 secara eksplisit;
- `config/ml-phase3-baseline-v2.json` menambahkan 15 numeric feature baru ke model contract;
- `config/ml-phase3-feature-diagnostics-v2.json` menyediakan kontrak diagnosis v2;
- audit config retained-run tetap harus dibuat setelah strategy version, preset hash, test window,
  dependency hash, dan source revision v2 dibekukan.

Sebelum dataset panjang dikumpulkan, schema v2 harus melewati short Strategy Tester parity:
logger OFF dan ON wajib menghasilkan urutan deal serta balance identik, candidate wajib memiliki
97 kolom, dan `FeatureReadyV2=false` harus nol.
