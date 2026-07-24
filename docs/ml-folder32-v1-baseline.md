# Baseline Manifest `folder32_v1`

## Status

Dokumen ini membekukan konfigurasi yang benar-benar digunakan pada backtest folder 32 sebagai
baseline pengumpulan dataset ML. Raw preset/report tetap lokal dan tidak di-commit.

`folder32_v1` adalah nama strategi, bukan klaim bahwa hasil folder 32 berasal dari satu perubahan
ATR SL. Preset aktual berbeda dari folder 25 pada beberapa kelompok setting.

## Provenance

| Item | Nilai |
| --- | --- |
| Strategy version | `folder32_v1` |
| Source commit | `c69f2aff1821a7852e5a61623463b45abe53d942` |
| EA EX5 SHA-256 | `25B2FC4E338513C86D7170025F48A4D7A62D2B370F845A7D32C4E1781BAB6DD6` |
| Preset SHA-256 | `737EF0B78C358EE2D98BD54BA82F06E6C67010E09A12B95E2F05F061438C1651` |
| Report SHA-256 | `652238A12F2BFCE287D850E9A5A0366203BE2696732F1EB562A5BA5AF403C1FC` |
| Expert | `testing_strat_7` |
| Symbol | `GOLD.i#` |
| Chart timeframe | M1 |
| Test period | 2026-01-04 sampai 2026-05-02 |
| Model | 99% real ticks |
| Bars / ticks | 115,508 / 32,562,123 |
| Initial deposit | 4,000.00 |
| Leverage | 1:500 |

Hash mengidentifikasi artefak lokal tanpa mempublikasikan raw report, preset, atau binary.

## Observed report summary

| Metric | Folder 32 |
| --- | ---: |
| Total net profit | 7,020.93 |
| Profit factor | 1.63 |
| Equity DD maximal | 2,949.11 (30.98%) |
| Equity DD relative | 40.93% (2,392.40) |
| Total trades | 2,092 |
| Short trades won | 893 (57.78%) |
| Long trades won | 1,199 (59.72%) |

Metrik ini hanya fingerprint kewajaran reproduksi. Original-cycle/recovery metrics harus
direkonstruksi oleh logger Fase 1, bukan disimpulkan dari aggregate win rate report.

## Runtime dependency hashes

| Dependency | SHA-256 |
| --- | --- |
| `cciCustomFix/cciCustomFix.ex5` | `A2A2E46623D8E436E3E9BF51094824EE0FD4753549F1AF06838D557A3EF2E734` |
| `hiloFix/hiloFix.ex5` | `DEE2185DE717E2CE7AE646D52545DF1A473E24D37F47BC715063EF2290FB92A7` |
| `parabolicSarFix/parabolicSarFix.ex5` | `83A3339EBEFC4501DC48579D8ECAACED221D4315F215E8A4A31907DAD485275F` |
| `superTrend/superTrend.ex5` | `711699DBE3E2D50B28BECCAAE8A1E787C9C643E98EDF1D1595C8E86F2F20F78C` |
| `accountStatus/accountStatus.ex5` | `3305D5DD70EA2EE766D7C85F7C5802A72371965ED74CC58F9F5C97A73689525D` |

Dependency dashboard tidak menentukan entry, tetapi hash tetap dicatat karena aktif pada preset.

## Frozen input values

Nilai enum ditulis dengan nama semantik. Semua nilai di bawah berasal dari kolom current value
preset folder 32.

### Trading dan CCI

~~~text
InpLotSize=0.01
InpMainLotMode=MAIN_LOT_FIXED
InpMainRiskPercent=1
InpEnableBuy=true
InpEnableSell=true
InpMaxBuyPositions=1
InpMaxSellPositions=1
InpCciSignalValidityBars=5
InpCciSignalMode=CCI_SIGNAL_MODE_BOTH
InpMainPositionMode=MAIN_POSITION_MODE_LEGACY
InpMainSignalReentryMode=MAIN_SIGNAL_REENTRY_LEGACY
InpCciLength=11
InpCiLength=5
~~~

### Existing diagnostics

~~~text
InpEnableOriginalTradeDiagnostics=true
InpOriginalDiagAtrPeriod=14
InpOriginalDiagEmaPeriod=50
InpEnableOriginalStructureDiagnostics=true
InpOriginalStructureTimeframe=PERIOD_M5
InpOriginalStructureLeftBars=10
InpOriginalStructureRightBars=10
InpOriginalStructureHistoryBars=1500
InpEnableLateConfirmationGuard=false
~~~

### Main confirmation stack

~~~text
InpUseMainSuperTrendFilter=true
InpSuperTrendAtrPeriod=70
InpSuperTrendMultiplier=2.0
InpSuperTrendChangeAtrMethod=true
InpMainSuperTrendTimeframe=PERIOD_CURRENT

InpUseMainPsarFilter=true
InpPsarStart=0.01
InpPsarIncrement=0.01
InpPsarMaximum=0.1
InpMainPsarTimeframe=PERIOD_CURRENT

InpUseMainHiLoFilter=true
InpHiLoPeriod=14
InpHiLoShift=0
InpHiLoMethod=MODE_LWMA
InpHiLoAtrPeriod=14

InpEnableAdxFilter=false
InpAdxTimeframe=PERIOD_CURRENT
InpAdxDmiPeriod=14
InpAdxEnableSmoothing=true
InpAdxSmoothing=14
InpAdxThreshold=30
InpAdxFilterMode=ADX_FILTER_ADX_ONLY

InpEnableSTMTF=true
InpSTFilterTF=PERIOD_M5
InpSTFilterATRPeriod=50
InpSTFilterATRMult=1.5
InpSTFilterATRMethod=true
~~~

### Time dan session

~~~text
InpStartHour=2
InpStartMinute=0
InpEndHour=22
InpEndMinute=0
InpEnableSessionFilter=true

InpEnableAsiaSession=true
InpAsiaStartHour=1
InpAsiaStartMinute=0
InpAsiaEndHour=7
InpAsiaEndMinute=0

InpEnableLondonSession=true
InpLondonStartHour=7
InpLondonStartMinute=0
InpLondonEndHour=16
InpLondonEndMinute=0

InpEnableNewYorkSession=true
InpNewYorkStartHour=16
InpNewYorkStartMinute=0
InpNewYorkEndHour=23
InpNewYorkEndMinute=0
~~~

### Initial SL dan trailing

~~~text
InpMainStopLossMode=MAIN_SL_ATR_CANDLE
InpStopLossPoints=500
InpMainStopAtrTimeframe=PERIOD_CURRENT
InpMainStopAtrPeriod=14
InpMainStopAtrMultiplier=1.4
InpTakeProfitPoints=0

InpTrailingStartPoints=500
InpTrailingStepPoints=500
InpTrailingDistancePoints=500
InpTrailingBreakEvenOffsetPoints=50
~~~

Rumus initial SL aktif:

~~~text
BUY SL  = low candle tertutup sebelumnya  - ATR RMA(14) * 1.4
SELL SL = high candle tertutup sebelumnya + ATR RMA(14) * 1.4
~~~

### Daily protection

~~~text
InpEnableDailyTarget=false
InpDailyTargetMode=DAILY_TARGET_PERCENTAGE
InpDailyTargetValue=5.0
InpEnableDailyDrawdown=false
InpDailyDrawdownMode=DAILY_DD_PERCENTAGE
InpDailyDrawdownValue=5.0
~~~

Nilai target/drawdown tidak aktif, tetapi tetap dibekukan agar preset dapat dibandingkan.

### Recovery general dan grid aktif

~~~text
InpEnableRecovery=true
InpRecoveryMode=RECOVERY_MODE_GRID
InpRecoveryTargetMultiplier=2.0
InpRecoveryLotMultiplier=1.437
InpRecoveryMinZonePoints=500
InpRecoveryMaxZonePoints=3600

InpRecoveryZoneMode=RECOVERY_ZONE_ATR
InpRecoveryZoneRangePoints=500
InpRecoveryAtrPeriod=14
InpRecoveryAtrMultiplier=2.0
InpRecoveryAtrTimeframe=PERIOD_CURRENT

InpRecoveryGridStepPoints=500
InpRecoveryGridStepMode=GRID_STEP_FIXED
InpRecoveryGridAtrPeriod=14
InpRecoveryGridAtrMultiplier=1.2
InpRecoveryGridAtrTimeframe=PERIOD_CURRENT
InpRecoveryGridMaxLevels=10
InpRecoveryGridLotMultiplier=1.437
InpRecoveryGridDirectionMode=GRID_DIRECTION_WITH_LOSS
InpRecoveryGridTakeProfitMoney=0.0
InpRecoveryGridForceLevel1Market=true
~~~

### Recovery setting nonaktif tetapi dibekukan

~~~text
InpRecoveryClassicStTimeframe=PERIOD_M5
InpRecoveryClassicStAtrPeriod=50
InpRecoveryClassicStMultiplier=1.5
InpRecoveryClassicStAtrMethod=true
InpRecoveryClassicPsarTimeframe=PERIOD_M5
InpRecoveryClassicPsarStart=0.01
InpRecoveryClassicPsarIncrement=0.01
InpRecoveryClassicPsarMaximum=0.1
InpBasketTrailing=false
InpBasketTrailThreshold=0.5
InpBasketTrailGapPct=0.2
InpBasketHardFloor=true

InpRecoveryDistanceStTimeframe=PERIOD_M15
InpRecoveryDistanceStAtrPeriod=50
InpRecoveryDistanceStMultiplier=1.5
InpRecoveryDistanceStAtrMethod=true
InpRecoveryDistancePsarTimeframe=PERIOD_M15
InpRecoveryDistancePsarStart=0.04
InpRecoveryDistancePsarIncrement=0.04
InpRecoveryDistancePsarMaximum=0.4
InpRecoveryDistancePoints=500
InpRecoveryDistanceSignalSource=DIST_SIGNAL_BASIC_EMA
InpRecoveryBasicEmaFast=34
InpRecoveryBasicEmaSlow=55
~~~

### Recovery risk control dan identity

~~~text
InpMaxRecoverySteps=0
InpMaxRecoveryLot=0.0
InpRecoveryMaxDrawdown=0.0
InpMaxRecoveryPositions=0
InpRecoveryCooldownBars=0

InpMagicNumber=140402
InpBuyComment=orderBuy
InpSellComment=orderSell
InpEnableAccountStatusDashboard=true
InpAccountStatusIndicatorPath=accountStatus\accountStatus
~~~

## Reproduction contract

Run hanya boleh memakai `strategy_version=folder32_v1` bila:

1. source dan dependency sesuai hash/versi yang dicatat;
2. seluruh input sesuai manifest;
3. symbol, timeframe, model tick, dan broker cost dicatat;
4. preset hash dicatat dalam run manifest;
5. logger tidak mengubah trade history control.

Perubahan entry, SL, trailing, recovery, session, lot, atau dependency menghasilkan strategy
version baru. Perubahan observation-only boleh mempertahankan strategy version hanya setelah
regression membuktikan history transaksi identik.

## Data-integrity note

Periode historis terkait migrasi `GOLD#` ke `GOLD.i#` belum memiliki tanggal discontinuity yang
terbukti di repository. Dataset Fase 1 harus membawa `DataIntegrityFlag` dan laporan sensitivity
dengan/tanpa interval yang dicurigai. Backtest 99% real ticks tidak dengan sendirinya membuktikan
tidak adanya gap, spike, atau perubahan spread.
