//+------------------------------------------------------------------+
//|                                                   TS7/Inputs.mqh |
//|                         Input parameters for testing_strat_7      |
//+------------------------------------------------------------------+
#ifndef TS7_INPUTS_MQH
#define TS7_INPUTS_MQH

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "Trading Setup"
input double InpLotSize                = 0.01;      // Fixed lot
input ENUM_MAIN_LOT_MODE InpMainLotMode = MAIN_LOT_FIXED; // Main strategy lot mode
input double InpMainRiskPercent        = 1.0;       // Main strategy risk % (dynamic mode)
input bool   InpEnableBuy              = true;       // Allow buy entry
input bool   InpEnableSell             = true;       // Allow sell entry
input int    InpMaxBuyPositions        = 1;          // Max active buy positions
input int    InpMaxSellPositions       = 1;          // Max active sell positions
input int    InpCciSignalValidityBars  = 6;          // Signal candle + 5 next candles
input ENUM_CCI_SIGNAL_MODE InpCciSignalMode = CCI_SIGNAL_MODE_BOTH; // CCI signal type selection
input ENUM_MAIN_POSITION_MODE InpMainPositionMode = MAIN_POSITION_MODE_LEGACY; // Main strategy position mode
input ENUM_MAIN_SIGNAL_REENTRY_MODE InpMainSignalReentryMode = MAIN_SIGNAL_REENTRY_LEGACY; // Main signal re-entry mode

input group "CCI Settings"
input int    InpCciLength              = 11;         // CCI length
input int    InpCiLength               = 5;          // CI smoothing length

input group "Original Trade Diagnostics"
input bool   InpEnableOriginalTradeDiagnostics = false; // Log original-trade MFE/MAE without changing trading
input int    InpOriginalDiagAtrPeriod  = 14;          // ATR period captured at original entry
input int    InpOriginalDiagEmaPeriod  = 50;          // EMA period for entry distance telemetry
input bool   InpEnableOriginalStructureDiagnostics = false; // Log confirmed-pivot S/R at original entry
input ENUM_TIMEFRAMES InpOriginalStructureTimeframe = PERIOD_M1; // Explicit structure telemetry timeframe
input int    InpOriginalStructureLeftBars = 10;       // Older bars required to form a pivot
input int    InpOriginalStructureRightBars = 10;      // Closed newer bars required to confirm a pivot
input int    InpOriginalStructureHistoryBars = 1500;  // Bars scanned for structure state

input group "Late Confirmation Guard"
input bool   InpEnableLateConfirmationGuard = false;  // Block symmetric HiLo+ST M1 late-confirm pattern

input group "SuperTrend Settings"
input bool   InpUseMainSuperTrendFilter = true;      // Main strategy: use SuperTrend confirmation
input int    InpSuperTrendAtrPeriod    = 50;         // SuperTrend ATR period
input double InpSuperTrendMultiplier   = 1.5;        // SuperTrend ATR multiplier
input bool   InpSuperTrendChangeAtrMethod = true;    // SuperTrend ATR method (true=RMA)
input ENUM_TIMEFRAMES InpMainSuperTrendTimeframe = PERIOD_CURRENT; // Main strategy SuperTrend timeframe

input group "Parabolic SAR Settings"
input bool   InpUseMainPsarFilter      = true;       // Main strategy: use PSAR confirmation
input double InpPsarStart              = 0.02;       // PSAR start
input double InpPsarIncrement          = 0.02;       // PSAR increment
input double InpPsarMaximum            = 0.20;       // PSAR maximum
input ENUM_TIMEFRAMES InpMainPsarTimeframe = PERIOD_CURRENT; // Main strategy PSAR timeframe

input group "HiLo Settings"
input bool   InpUseMainHiLoFilter      = true;       // Main strategy: use HiLo confirmation
input int    InpHiLoPeriod             = 20;         // HiLo period
input int    InpHiLoShift              = 0;          // HiLo shift
input ENUM_MA_METHOD InpHiLoMethod     = MODE_LWMA;  // HiLo MA method
input int    InpHiLoAtrPeriod          = 14;         // HiLo ATR period

input group "Trading Time Filter"
input int    InpStartHour              = 2;          // Trading start hour
input int    InpStartMinute            = 0;          // Trading start minute
input int    InpEndHour                = 22;         // Trading end hour
input int    InpEndMinute              = 0;          // Trading end minute
input bool   InpEnableSessionFilter    = true;       // Enable session filter

input group "Session Hours"
input bool   InpEnableAsiaSession      = true;       // Enable Asia session
input int    InpAsiaStartHour          = 4;          // Asia start hour
input int    InpAsiaStartMinute        = 0;          // Asia start minute
input int    InpAsiaEndHour            = 10;          // Asia end hour
input int    InpAsiaEndMinute          = 0;          // Asia end minute
input bool   InpEnableLondonSession    = false;      // Enable London session
input int    InpLondonStartHour        = 13;         // London start hour
input int    InpLondonStartMinute      = 0;          // London start minute
input int    InpLondonEndHour          = 17;         // London end hour
input int    InpLondonEndMinute        = 0;          // London end minute
input bool   InpEnableNewYorkSession   = true;       // Enable New York session
input int    InpNewYorkStartHour       = 17;         // New York start hour
input int    InpNewYorkStartMinute     = 0;          // New York start minute
input int    InpNewYorkEndHour         = 23;         // New York end hour
input int    InpNewYorkEndMinute       = 55;          // New York end minute

input group "Risk Management"
input int    InpStopLossPoints         = 500;        // Stop Loss (points) = 50 pips
input int    InpTakeProfitPoints       = 0;       // Take Profit (points) = 200 pips

input group "Trailing Stop"
input int    InpTrailingStartPoints    = 500;        // Start trailing after (points)
input int    InpTrailingStepPoints     = 500;        // Move every (points)
input int    InpTrailingDistancePoints = 500;        // SL distance when trailing (points)
input int    InpTrailingBreakEvenOffsetPoints = 0;   // Minimum locked profit after trailing starts (0=legacy)

input group "ADX Filter"
input bool   InpEnableAdxFilter        = false;      // Enable ADX filter
input ENUM_TIMEFRAMES InpAdxTimeframe  = PERIOD_CURRENT; // ADX timeframe
input int    InpAdxDmiPeriod           = 14;         // DMI/ADX period
input bool   InpAdxEnableSmoothing     = true;       // Enable ADX smoothing
input int    InpAdxSmoothing           = 14;         // ADX smoothing
input double InpAdxThreshold           = 20.0;       // ADX threshold
input ENUM_ADX_FILTER_MODE InpAdxFilterMode = ADX_FILTER_ADX_WITH_BIAS; // ADX mode (only / with bias)

input group "SuperTrend MTF Filter"
input bool            InpEnableSTMTF         = false;          // Enable SuperTrend MTF filter
input ENUM_TIMEFRAMES InpSTFilterTF          = PERIOD_M5;     // Filter timeframe (M5/M15/etc)
input int             InpSTFilterATRPeriod   = 50;             // MTF ATR period
input double          InpSTFilterATRMult     = 1.5;            // MTF ATR multiplier
input bool            InpSTFilterATRMethod   = true;           // MTF ATR method (true=RMA)

input group "Daily Target"
input bool   InpEnableDailyTarget      = false;       // Enable daily target
input ENUM_DAILY_TARGET_MODE InpDailyTargetMode = DAILY_TARGET_EQUITY; // Target mode
input double InpDailyTargetValue       = 20.0;       // Target value
input bool   InpEnableDailyDrawdown    = false;      // Enable daily drawdown limit
input ENUM_DAILY_DRAWDOWN_MODE InpDailyDrawdownMode = DAILY_DD_PERCENTAGE; // Drawdown mode
input double InpDailyDrawdownValue     = 5.0;        // Drawdown value ($ or %)

input group "Recovery - General"
input bool   InpEnableRecovery          = true;       // Enable recovery mode
input ENUM_RECOVERY_MODE InpRecoveryMode = RECOVERY_MODE_GRID; // Recovery mode (Classic/Trend/Start Reverse/Grid/Distance)
input double InpRecoveryTargetMultiplier= 2.0;        // Recovery target x loss amount
input double InpRecoveryLotMultiplier   = 1.437;      // Recovery lot multiplier per step
input int    InpRecoveryMinZonePoints   = 500;        // Min zone range (points, 0=off)
input int    InpRecoveryMaxZonePoints   = 1300;       // Max zone range (points, 0=off)

input group "Recovery Classic Zone - Signal Filter"
input ENUM_TIMEFRAMES InpRecoveryClassicStTimeframe = PERIOD_CURRENT; // Classic start SuperTrend timeframe
input int    InpRecoveryClassicStAtrPeriod = 50;      // Classic start SuperTrend ATR period
input double InpRecoveryClassicStMultiplier = 1.5;    // Classic start SuperTrend ATR multiplier
input bool   InpRecoveryClassicStAtrMethod = true;    // Classic start SuperTrend ATR method (true=RMA)
input ENUM_TIMEFRAMES InpRecoveryClassicPsarTimeframe = PERIOD_CURRENT; // Classic start PSAR timeframe
input double InpRecoveryClassicPsarStart = 0.02;      // Classic start PSAR start
input double InpRecoveryClassicPsarIncrement = 0.02;  // Classic start PSAR increment
input double InpRecoveryClassicPsarMaximum = 0.20;    // Classic start PSAR maximum

input group "Recovery Classic Zone - Basket Trailing"
input bool   InpBasketTrailing       = true;  // CLASSIC only: enable basket trailing
input double InpBasketTrailThreshold = 0.5;   // CLASSIC only: trailing starts at X * cycle target
input double InpBasketTrailGapPct    = 0.30;  // CLASSIC only: trail gap from peak profit
input bool   InpBasketHardFloor      = true;  // CLASSIC only: lock SL >= target when peak >= target

input group "Recovery Distance - Signal Filter"
input ENUM_TIMEFRAMES InpRecoveryDistanceStTimeframe = PERIOD_CURRENT; // Distance ST+PSAR SuperTrend timeframe
input int    InpRecoveryDistanceStAtrPeriod = 50;      // Distance ST+PSAR SuperTrend ATR period
input double InpRecoveryDistanceStMultiplier = 1.5;    // Distance ST+PSAR SuperTrend ATR multiplier
input bool   InpRecoveryDistanceStAtrMethod = true;    // Distance ST+PSAR SuperTrend ATR method (true=RMA)
input ENUM_TIMEFRAMES InpRecoveryDistancePsarTimeframe = PERIOD_CURRENT; // Distance ST+PSAR PSAR timeframe
input double InpRecoveryDistancePsarStart = 0.02;      // Distance ST+PSAR PSAR start
input double InpRecoveryDistancePsarIncrement = 0.02;  // Distance ST+PSAR PSAR increment
input double InpRecoveryDistancePsarMaximum = 0.20;    // Distance ST+PSAR PSAR maximum

input group "Recovery - Zone"
input ENUM_RECOVERY_ZONE_MODE InpRecoveryZoneMode = RECOVERY_ZONE_FIXED; // Zone range mode
input int    InpRecoveryZoneRangePoints = 500;       // Fixed zone range (points) - mode Fixed
input int    InpRecoveryAtrPeriod       = 14;        // ATR period - mode ATR
input double InpRecoveryAtrMultiplier   = 1.5;       // ATR multiplier - mode ATR
input ENUM_TIMEFRAMES InpRecoveryAtrTimeframe = PERIOD_CURRENT; // ATR timeframe - mode ATR

input group "Recovery - Grid"
input int    InpRecoveryGridStepPoints  = 500;        // GRID: distance between grid levels (points)
input ENUM_RECOVERY_GRID_STEP_MODE InpRecoveryGridStepMode = GRID_STEP_FIXED; // GRID step mode
input int    InpRecoveryGridAtrPeriod   = 14;         // GRID ATR period
input double InpRecoveryGridAtrMultiplier = 1.0;      // GRID ATR multiplier
input ENUM_TIMEFRAMES InpRecoveryGridAtrTimeframe = PERIOD_CURRENT; // GRID ATR timeframe
input int    InpRecoveryGridMaxLevels   = 4;          // GRID: max levels to execute (0=off)
input double InpRecoveryGridLotMultiplier = 0.0;      // GRID: lot multiplier per level (0=use InpRecoveryLotMultiplier)
input ENUM_RECOVERY_GRID_DIRECTION InpRecoveryGridDirectionMode = GRID_DIRECTION_REVERSE; // GRID direction mode (with-loss/reverse/hedge/trend-signal)
input double InpRecoveryGridTakeProfitMoney = 0.0;    // GRID: basket TP in money (0=use target multiplier)
input bool   InpRecoveryGridForceLevel1Market = true; // GRID: force level-1 market entry on first recovery tick

input group "Recovery - Distance"
input int    InpRecoveryDistancePoints  = 500;        // DISTANCE: min points between recovery orders
input ENUM_RECOVERY_DISTANCE_SIGNAL_SOURCE InpRecoveryDistanceSignalSource = DIST_SIGNAL_ST_PSAR; // DISTANCE: signal source
input int    InpRecoveryBasicEmaFast    = 21;         // DISTANCE BASIC EMA fast
input int    InpRecoveryBasicEmaSlow    = 55;         // DISTANCE BASIC EMA slow

input group "Recovery Risk Control"
input int    InpMaxRecoverySteps        = 0;          // Max recovery steps (0=unlimited)
input double InpMaxRecoveryLot          = 0;       // Max recovery lot (0=unlimited)
input double InpRecoveryMaxDrawdown     = 0;       // Max recovery drawdown $ (0=off)
input int    InpMaxRecoveryPositions    = 0;          // Max recovery positions (0=unlimited)
input int    InpRecoveryCooldownBars    = 0;          // Cooldown bars after recovery (0=off)

input group "Order Identity"
input long   InpMagicNumber            = 140402;     // Magic number
input string InpBuyComment             = "orderBuy"; // Buy order comment
input string InpSellComment            = "orderSell";// Sell order comment

input group "Dashboard Integration"
input bool   InpEnableAccountStatusDashboard = true; // Auto attach account status dashboard
input string InpAccountStatusIndicatorPath   = "accountStatus\\accountStatus"; // MQL5\\Indicators\\accountStatus\\accountStatus.mq5

#endif // TS7_INPUTS_MQH
