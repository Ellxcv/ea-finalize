# ML Development Dataset Collection Plan

## Tujuan

Menambah candidate independen untuk mengulang Phase 3 tanpa membuka window setelah 2026.05.02
yang dicadangkan sebagai calon final OOS.

Seluruh run wajib memakai clean retained build `3dd654c62607b2333fde9473900d97f997bea48e`,
strategy preset hash `737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651`,
dan setting baseline folder 35.

## Run A

| Item | Nilai |
| --- | --- |
| Suggested report folder | `36` |
| Period | 2025.09.01–2026.01.03 |
| Input preset | `folder32-v1-ml-dev-20250901-20260103-r01.set` |
| Preset file SHA-256 | `8A6B072A37E5DB67C162728A3DD243D86236967AFFC2AA8FFFE44239624B575C` |
| RunId | `folder32_v1_GOLD-i_M1_20250901_20260103_r01` |

## Run B

| Item | Nilai |
| --- | --- |
| Suggested report folder | `37` |
| Period | 2025.05.01–2025.08.31 |
| Input preset | `folder32-v1-ml-dev-20250501-20250831-r01.set` |
| Preset file SHA-256 | `D1248CE39513F61E52CD35708E8CFE1E8DF198D007F3FBAE26790CAD6D7180FE` |
| RunId | `folder32_v1_GOLD-i_M1_20250501_20250831_r01` |

## Strategy Tester contract

~~~text
Expert       = testing_strat_7
Symbol       = GOLD.i#
Timeframe    = M1
Model        = Every tick based on real ticks
Optimization = Disabled
Forward      = No
Deposit      = USD 4,000
Leverage     = 1:500
Visual mode  = Off
~~~

Jangan mengubah Inputs setelah memuat preset. Periode diatur terpisah pada tab Settings karena
file `.set` hanya menyimpan Inputs.

## Integrity rule

Kedua run memakai `SYMBOL_MIGRATION_UNVERIFIED`. Jika Strategy Tester tidak menyediakan real ticks,
menampilkan history quality yang buruk, tidak menghasilkan history pada sebagian window, atau
menunjukkan lonjakan yang tidak wajar:

1. jangan mengganti symbol ke `GOLD#`;
2. jangan mengedit raw CSV;
3. tetap simpan report dan beri tahu hasilnya;
4. run hanya digabungkan setelah provenance, coverage, pairing, dan financial audit lulus.

Window mulai 2026.05.03 tidak digunakan pada collection ini dan tetap belum dibuka.
