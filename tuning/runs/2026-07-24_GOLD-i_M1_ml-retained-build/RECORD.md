# ML Retained Dataset Clean Build

## Tujuan

Menyiapkan binary dan preset untuk historical dataset Fase 2 tanpa memakai perubahan source lokal
yang belum di-commit.

## Source dan compile

| Item | Nilai |
| --- | --- |
| Source commit | `3dd654c62607b2333fde9473900d97f997bea48e` |
| Source worktree | detached dan clean |
| Compiler | XM Global MT5 MetaEditor64 build 5833 |
| Compile | `0 errors, 0 warnings` |
| EX5 SHA-256 | `D4EBF165D5B66BEDD397353C7B0352661F41057FC37491013E7EBC39171ABC8C` |

Binary hasil clean build dipasang ke lokasi live `testing_strat_7.ex5`. Hash binary live dan salinan
artefak lokal telah dibandingkan dan identik.

## Preset

| Item | SHA-256 |
| --- | --- |
| Frozen `backtest-32.set` | `737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651` |
| Prepared retained-run preset | `4D4653621C0BB93FE5246C978A4D58D92A388397EA5B33463AB821EB2FE78022` |

Preset yang disiapkan:

~~~text
folder32-v1-ml-retained-20260104-20260502.set
~~~

Pemeriksaan map input membuktikan:

- seluruh 140 input preset original tetap memiliki nilai yang sama;
- tidak ada input original yang hilang atau berubah;
- tepat delapan input logger ML ditambahkan;
- file preset original tidak ditimpa.

Input logger:

~~~text
InpEnableMlDatasetLogger=true
InpMlStrategyVersion=folder32_v1
InpMlSourceRevision=3dd654c62607b2333fde9473900d97f997bea48e
InpMlPresetHash=737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651
InpMlRunId=folder32_v1_GOLD-i_M1_20260104_20260502_r01
InpMlDatasetDirectory=TS7_ML
InpMlDataIntegrityFlag=SYMBOL_MIGRATION_UNVERIFIED
InpMlFlushEveryRecords=50
~~~

## Intended Strategy Tester run

| Item | Nilai |
| --- | --- |
| Symbol / timeframe | `GOLD.i#` / M1 |
| Period | 2026-01-04 sampai 2026-05-02 |
| Model | Every tick based on real ticks |
| Optimization / forward | OFF / OFF |
| Deposit / leverage | USD 4,000 / 1:500 |
| Visual mode | OFF |

RunId retained dipastikan belum pernah digunakan. Smoke test otomatis tidak dijalankan karena
terminal aktif sudah memiliki instance; terminal tersebut sengaja tidak ditutup atau diganggu.
Compile, binary hash, manifest, dan preset contract seluruhnya lulus.

## Artefak

Binary, compile log, preset, serta `build_manifest.json` disimpan lokal di luar Git pada bundle:

~~~text
Documents/TS7_ML/retained-builds/
3dd654c62607b2333fde9473900d97f997bea48e/
~~~

Binary, raw dataset, report tester, dan preset tidak di-commit. Record ini hanya menyimpan
provenance dan hash.
