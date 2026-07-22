//+------------------------------------------------------------------+
//|                                                   TS7/Enums.mqh  |
//|                       Enum definitions for testing_strat_7        |
//+------------------------------------------------------------------+
#ifndef TS7_ENUMS_MQH
#define TS7_ENUMS_MQH

//--- Enum Daily Target Mode
enum ENUM_DAILY_TARGET_MODE
  {
   DAILY_TARGET_EQUITY     = 0, // Target by Equity
   DAILY_TARGET_PERCENTAGE = 1  // Target by Percentage
  };

//--- Enum Daily Drawdown Mode
enum ENUM_DAILY_DRAWDOWN_MODE
  {
   DAILY_DD_EQUITY     = 0, // Drawdown by Equity
   DAILY_DD_PERCENTAGE = 1  // Drawdown by Percentage
  };

//--- Enum Recovery Zone Mode
enum ENUM_RECOVERY_ZONE_MODE
  {
   RECOVERY_ZONE_FIXED = 0, // Fixed (points)
   RECOVERY_ZONE_ATR   = 1  // ATR-based
  };

//--- Enum Recovery Mode
enum ENUM_RECOVERY_MODE
  {
   RECOVERY_MODE_CLASSIC_ZONE = 0, // Classic Zone (two-way)
   RECOVERY_MODE_TREND        = 1, // Trend Recovery (one-way)
   RECOVERY_MODE_START_REVERSE= 2, // First entry reverse, then classic zone
   RECOVERY_MODE_GRID         = 3, // Grid-based recovery
   RECOVERY_MODE_DISTANCE     = 4  // Distance-based (selectable signal)
  };

//--- Enum Recovery Trend Signal Mode
enum ENUM_RECOVERY_TREND_SIGNAL_MODE
  {
   TREND_SIGNAL_ST_PSAR = 0 // SuperTrend + PSAR sync signal
  };

//--- Enum Distance Signal Source (RECOVERY_MODE_DISTANCE)
enum ENUM_RECOVERY_DISTANCE_SIGNAL_SOURCE
  {
   DIST_SIGNAL_ST_PSAR  = 0, // SuperTrend + PSAR
   DIST_SIGNAL_ALGOZONE = 1, // AlgoZone signal dir
   DIST_SIGNAL_BASIC_EMA= 2  // Basic EMA cross (fast vs slow)
  };

//--- Enum Recovery Grid Direction Mode
enum ENUM_RECOVERY_GRID_DIRECTION
  {
   GRID_DIRECTION_WITH_LOSS = 0, // Follow direction of losing position
   GRID_DIRECTION_REVERSE   = 1, // Opposite direction of losing position
   GRID_DIRECTION_HEDGE_BOTH= 2, // Execute BUY on upper grid, SELL on lower grid
   GRID_DIRECTION_TREND_SIGNAL = 3 // Follow SuperTrend+PSAR direction (bar close only)
  };

//--- Enum Recovery Grid Step Mode
enum ENUM_RECOVERY_GRID_STEP_MODE
  {
   GRID_STEP_FIXED = 0, // Fixed points
   GRID_STEP_ATR   = 1  // ATR-based
  };

//--- Enum Main Strategy Lot Mode
enum ENUM_MAIN_LOT_MODE
  {
   MAIN_LOT_FIXED   = 0, // Use InpLotSize
   MAIN_LOT_DYNAMIC = 1  // Risk-based lot from equity and StopLossPoints
  };

//--- Enum Main Signal Re-entry Mode
enum ENUM_MAIN_SIGNAL_REENTRY_MODE
  {
   MAIN_SIGNAL_REENTRY_LEGACY = 0, // Legacy: one entry per signal timestamp
   MAIN_SIGNAL_REENTRY_PROFIT_SAME_SIGNAL = 1 // Allow reuse of same signal after positive strategy close
  };

//--- Enum Main Strategy Position Mode
enum ENUM_MAIN_POSITION_MODE
  {
   MAIN_POSITION_MODE_LEGACY = 0,        // Legacy: buy/sell can coexist if signal valid
   MAIN_POSITION_MODE_SINGLE_ACTIVE = 1  // New: only one active original strategy position
  };

//--- Enum CCI Signal Type
enum ENUM_CCI_SIGNAL_TYPE
  {
   CCI_SIGNAL_STRONG_SELL = -2,
   CCI_SIGNAL_SELL        = -1,
   CCI_SIGNAL_NONE        = 0,
   CCI_SIGNAL_BUY         = 1,
   CCI_SIGNAL_STRONG_BUY  = 2
  };

//--- Enum CCI Signal Selection Mode
enum ENUM_CCI_SIGNAL_MODE
  {
   CCI_SIGNAL_MODE_BOTH        = 0, // Accept normal and strong signals (legacy behavior)
   CCI_SIGNAL_MODE_NORMAL_ONLY = 1, // Accept normal Buy/Sell signals only
   CCI_SIGNAL_MODE_STRONG_ONLY = 2  // Accept StrongBuy/StrongSell signals only
  };

//--- Enum ADX Filter Mode
enum ENUM_ADX_FILTER_MODE
  {
   ADX_FILTER_ADX_ONLY = 0,      // ADX strength only (direction-agnostic)
   ADX_FILTER_ADX_WITH_BIAS = 1  // ADX strength + DI cross bias
  };

#endif // TS7_ENUMS_MQH
