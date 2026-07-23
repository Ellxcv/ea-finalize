//+------------------------------------------------------------------+
//|                                              testing_strat_7.mq5 |
//|                   4-Indicator Confirmation EA (CCI+HiLo+PSAR+ST) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- Library Wajib
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Trade/AccountInfo.mqh>

#include "Include/TS7/Enums.mqh"
#include "Include/TS7/Inputs.mqh"
#include "Include/TS7/GlobalState.mqh"

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
const string ACCOUNT_STATUS_SHORTNAME = "Account Status Dashboard";
const double RECOVERY_CLASSIC_DONE_TOLERANCE = 0.01;

//--- Trade objects
CTrade         g_trade;
CSymbolInfo    g_symbolInfo;
CAccountInfo   g_accountInfo;
CPositionInfo  g_positionInfo;

//--- State tracking
datetime g_lastBarTime        = 0;
double   g_startOfDayEquity   = 0.0;
datetime g_lastEquityResetDay = 0;
bool     g_dailyTargetReached = false;
bool     g_dailyDrawdownReached = false;
int      g_adxDirectionalBias = 0;          // ADX bias state: 1 bullish, -1 bearish, 0 unknown
datetime g_adxBiasLastBarTime = 0;          // Last processed closed bar time on ADX TF

//--- Main signal tracking (legacy no re-entry + optional profit re-entry mode)
datetime g_lastBuySignalUsed  = 0;
datetime g_lastSellSignalUsed = 0;
bool     g_mainAllowBuySignalReuse = false;
bool     g_mainAllowSellSignalReuse = false;

//--- Recovery zone state
bool     g_recoveryActive       = false;
bool     g_recoveryPendingStart = false; // Classic Zone: waiting for ST+PSAR start signal
double   g_recoveryPendingLossAmount = 0.0;
double   g_recoveryPendingDealVolume = 0.0;
double   g_recoveryClassicBaseDealVolume = 0.0; // CLASSIC: fixed base volume from original loss deal
datetime g_recoveryClassicPendingLastBarTime = 0;
double   g_recoveryZoneHigh     = 0.0;
double   g_recoveryZoneLow      = 0.0;
double   g_recoveryClosedProfit = 0.0;
double   g_recoveryTargetProfit = 0.0;
double   g_recoveryTotalTarget  = 0.0; // CLASSIC basket trailing: initial target (constant until done)
double   g_recoverySecuredProfit = 0.0; // CLASSIC basket trailing: accumulated closed cycle profit
double   g_recoveryRemainingTarget = 0.0; // CLASSIC basket trailing: total - secured
double   g_basketPeakProfit     = 0.0; // CLASSIC basket trailing: cycle peak floating profit
bool     g_basketTrailActive    = false; // CLASSIC basket trailing: cycle trailing state
bool     g_classicCycleClosePending = false; // CLASSIC basket trailing: waiting cleanup after close request
double   g_classicCyclePendingProfit = 0.0; // CLASSIC basket trailing: locked cycle profit snapshot
double   g_recoveryStartEquity  = 0.0;     // Equity when recovery cycle starts
double   g_recoveryNextLot      = 0.0;
int      g_recoveryLastDirection= 0;     // -1 sell, +1 buy
int      g_recoveryInitialDirection = 0; // START_REVERSE first entry: -1 sell, +1 buy
int      g_recoveryLossDirection = 0;    // +1 loss BUY, -1 loss SELL
bool     g_recoveryBuyDone      = false;
bool     g_recoverySellDone     = false;
bool     g_closingRecoveryPositions = false; // Guard: prevent re-trigger during close
int      g_recoveryStepCount    = 0;         // Recovery entry counter
bool     g_recoveryZoneBreached = false;     // Zone sudah pernah ditembus (trend mode)
double   g_recoveryGridAnchorPrice = 0.0;    // GRID anchor (loss close or trend signal close)
double   g_recoveryGridStepPrice   = 0.0;    // GRID step in price
int      g_recoveryGridMaxLevelsActive = 0;  // GRID active levels
double   g_recoveryGridLastExecPrice = 0.0;  // GRID last executed market price
bool     g_recoveryGridTrendAnchorReady = false; // GRID trend-signal anchor locked
int      g_recoveryGridTrendDirection = 0;       // GRID trend-signal locked direction (1 buy / -1 sell)
int      g_recoveryGridTrendNextLevel = 1;       // GRID trend-signal next level to execute
datetime g_recoveryGridTrendLastBarTime = 0;     // GRID trend-signal last processed bar
double   g_recoveryLastOpenPrice = 0.0;          // DISTANCE: last opened recovery order price
int      g_recoveryLastOpenDirection = 0;        // DISTANCE: direction of last opened order (1/-1)
datetime g_recoveryDistLastBarTime = 0;          // DISTANCE: last processed bar
bool     g_recoveryGridUpperDone[];          // GRID executed flags above anchor
bool     g_recoveryGridLowerDone[];          // GRID executed flags below anchor

//--- Recovery cooldown
datetime g_recoveryCooldownUntil = 0;         // Cooldown: block entry until this bar time
datetime g_recoveryRestartGuardUntil = 0;     // Short guard after recovery reset (anti race restart)

//--- Recovery chart lines
const string RECOVERY_TAG         = "[REC]";
const string REC_ZONE_H_LINE      = "TS7_REC_ZH";
const string REC_ZONE_L_LINE      = "TS7_REC_ZL";

bool IsRecoveryComment(const string comment);
bool DeleteRecoveryPendingOrders();
void DeleteRecoveryLines();
void ResetRecoveryState();
int GetRecoveryTrendDirection();
int GetClassicRecoveryTrendDirection();

#include "Include/TS7/Utils.mqh"
#include "Include/TS7/Core/HandleManager.mqh"
#include "Include/TS7/Core/Dashboard.mqh"
#include "Include/TS7/Signals/ADX.mqh"
#include "Include/TS7/Signals/STMTFFilter.mqh"
#include "Include/TS7/Signals/CCI.mqh"
#include "Include/TS7/Signals/HiLo.mqh"
#include "Include/TS7/Signals/PSAR.mqh"
#include "Include/TS7/Signals/SuperTrend.mqh"
#include "Include/TS7/Filters/TimeFilter.mqh"
#include "Include/TS7/Filters/SessionFilter.mqh"
#include "Include/TS7/Core/DailyManager.mqh"
#include "Include/TS7/Core/PositionManager.mqh"
#include "Include/TS7/Core/RiskManager.mqh"
#include "Include/TS7/Diagnostics/OriginalTradeDiagnostics.mqh"
#include "Include/TS7/Core/OrderExecutor.mqh"
#include "Include/TS7/Core/TrailingStop.mqh"
#include "Include/TS7/Recovery/RecoveryUtils.mqh"
#include "Include/TS7/Recovery/RecoveryClassic.mqh"
#include "Include/TS7/Recovery/RecoveryTrend.mqh"
#include "Include/TS7/Recovery/RecoveryStartReverse.mqh"
#include "Include/TS7/Recovery/RecoveryGrid.mqh"
#include "Include/TS7/Recovery/RecoveryDistance.mqh"
#include "Include/TS7/Recovery/RecoveryManager.mqh"

//+------------------------------------------------------------------+
//| Validate Classic Zone signal filter inputs                        |
//+------------------------------------------------------------------+
bool ValidateRecoveryClassicSignalInputs()
  {
   if(!InpEnableRecovery || InpRecoveryMode != RECOVERY_MODE_CLASSIC_ZONE)
      return true;

   if(InpRecoveryClassicStAtrPeriod <= 0)
     {
      Print("ERROR: InpRecoveryClassicStAtrPeriod must be > 0.");
      return false;
     }

   if(InpRecoveryClassicStMultiplier <= 0.0)
     {
      Print("ERROR: InpRecoveryClassicStMultiplier must be > 0.");
      return false;
     }

   if(InpRecoveryClassicPsarStart <= 0.0 || InpRecoveryClassicPsarIncrement <= 0.0 ||
      InpRecoveryClassicPsarMaximum < InpRecoveryClassicPsarIncrement)
     {
      Print("ERROR: Invalid Classic Zone PSAR settings. Ensure start>0, increment>0, and maximum>=increment.");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Validate Distance mode ST+PSAR filter inputs                      |
//+------------------------------------------------------------------+
bool ValidateRecoveryDistanceSignalInputs()
  {
   if(!InpEnableRecovery || InpRecoveryMode != RECOVERY_MODE_DISTANCE)
      return true;

   if(InpRecoveryDistanceStAtrPeriod <= 0)
     {
      Print("ERROR: InpRecoveryDistanceStAtrPeriod must be > 0.");
      return false;
     }

   if(InpRecoveryDistanceStMultiplier <= 0.0)
     {
      Print("ERROR: InpRecoveryDistanceStMultiplier must be > 0.");
      return false;
     }

   if(InpRecoveryDistancePsarStart <= 0.0 || InpRecoveryDistancePsarIncrement <= 0.0 ||
      InpRecoveryDistancePsarMaximum < InpRecoveryDistancePsarIncrement)
     {
      Print("ERROR: Invalid Distance PSAR settings. Ensure start>0, increment>0, and maximum>=increment.");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpCciSignalValidityBars <= 0)
     {
      Print("ERROR: InpCciSignalValidityBars must be > 0.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpMainLotMode == MAIN_LOT_DYNAMIC && InpMainRiskPercent <= 0.0)
     {
      Print("ERROR: InpMainRiskPercent must be > 0 when InpMainLotMode=MAIN_LOT_DYNAMIC.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpTrailingBreakEvenOffsetPoints < 0)
     {
      Print("ERROR: InpTrailingBreakEvenOffsetPoints must be >= 0.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpTrailingBreakEvenOffsetPoints > 0 &&
      (InpTrailingStartPoints <= 0 ||
       InpTrailingBreakEvenOffsetPoints >= InpTrailingStartPoints))
     {
      Print("ERROR: Positive trailing breakeven offset requires trailing enabled and offset < start points.");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(!ValidateRecoveryClassicSignalInputs())
      return(INIT_PARAMETERS_INCORRECT);
   if(!ValidateRecoveryDistanceSignalInputs())
      return(INIT_PARAMETERS_INCORRECT);

//--- Init symbol info
   if(!g_symbolInfo.Name(_Symbol))
     {
      Print("ERROR: Gagal init CSymbolInfo untuk ", _Symbol);
      return(INIT_FAILED);
     }
   g_symbolInfo.RefreshRates();

//--- Init trade
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(ORDER_FILLING_FOK);

//--- Buat indicator handles
   if(!CreateAllHandles(g_handles))
      return(INIT_FAILED);

//--- Record start of day equity
   RecordStartOfDayEquity();
   ResetOriginalTradeDiagnostics();

   Print("INFO: testing_strat_7 initialized OK. Magic=", InpMagicNumber,
         " CCISignalMode=", EnumToString(InpCciSignalMode));

//--- Account Status dashboard (attach indikator ke chart utama)
   AttachAccountStatusDashboard(g_handles);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   PrintOriginalTradeDiagnosticsSummary();
   DetachAccountStatusDashboard();
   ReleaseAllHandles(g_handles);
   DeleteRecoveryLines();
   Print("INFO: testing_strat_7 deinitialized. Reason=", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//--- Observation-only original-trade excursion tracking
   UpdateOriginalTradeDiagnostics();

//--- Cek daily reset
   RecordStartOfDayEquity();

//--- Daily drawdown lock: close all EA positions and stop trading until new day
   if(InpEnableDailyDrawdown)
     {
      double dailyPL = 0.0;
      double ddLimitMoney = 0.0;
      if(!g_dailyDrawdownReached && IsDailyDrawdownReached(dailyPL, ddLimitMoney))
        {
         g_dailyDrawdownReached = true;
         if(InpDailyDrawdownMode == DAILY_DD_PERCENTAGE)
           {
            Print("WARNING: Daily drawdown hit. P/L=", DoubleToString(dailyPL, 2),
                  " Limit=", DoubleToString(InpDailyDrawdownValue, 2), "% ($",
                  DoubleToString(ddLimitMoney, 2),
                  "). Trading stopped until next day.");
           }
         else
           {
            Print("WARNING: Daily drawdown hit. P/L=", DoubleToString(dailyPL, 2),
                  " Limit=$", DoubleToString(ddLimitMoney, 2),
                  ". Trading stopped until next day.");
           }
        }

      if(g_dailyDrawdownReached)
        {
         CloseAllEAOpenPositions();
         if(g_recoveryActive)
            ResetRecoveryState();
         return;
        }
     }

//--- Manage trailing stop untuk posisi yang sudah ada
   ManageTrailingStop();

//--- Recovery mode: execute recovery logic and block normal entries
   g_symbolInfo.RefreshRates();
   HandleRecoveryZone();
   if(g_recoveryActive || g_recoveryPendingStart)
      return;

//--- Safety guard: never continue normal entry if orphan recovery exposure still exists
   int orphanRecoveryPos = CountRecoveryPositions();
   int orphanRecoveryPending = CountRecoveryPendingOrders();
   if(orphanRecoveryPos > 0 || orphanRecoveryPending > 0)
     {
      Print("WARNING: Orphan recovery exposure detected while recovery inactive. Pos=",
            orphanRecoveryPos, " Pending=", orphanRecoveryPending,
            ". Cleaning up before normal entry.");
      DeleteRecoveryPendingOrders();
      CloseAllRecoveryPositions();
      return;
     }

//--- Recovery cooldown: block normal entries for N bars after recovery ends
   if(InpRecoveryCooldownBars > 0 && g_recoveryCooldownUntil > 0)
     {
      datetime currentBarTime = iTime(_Symbol, _Period, 0);
      if(currentBarTime < g_recoveryCooldownUntil)
        {
         PrintDebug("Entry blocked: Recovery cooldown active");
         return;
        }
      else
        {
         g_recoveryCooldownUntil = 0;  // Cooldown selesai
         Print("INFO: Recovery cooldown ended. Normal entry resumed.");
        }
     }

//--- Hanya evaluate entry saat candle close (new bar)
   if(!IsNewBar())
      return;

//--- Refresh symbol info
   g_symbolInfo.RefreshRates();

//--- Cek daily target
   if(InpEnableDailyTarget && IsDailyTargetReached())
     {
      if(!g_dailyTargetReached)
        {
         Print("INFO: Daily target tercapai. Equity=", g_accountInfo.Equity(),
               " Start=", g_startOfDayEquity, " Target=", InpDailyTargetValue);
         g_dailyTargetReached = true;
        }
      return;
     }

//--- Cek time window
   if(!IsWithinTimeWindow())
     {
      PrintDebug("Time window filter: BLOCKED");
      return;
     }

//--- Cek session filter (jika aktif)
   if(InpEnableSessionFilter && !IsWithinAnySession())
     {
      PrintDebug("Session filter: BLOCKED");
      return;
     }

//--- Baca semua indikator
   int      cciBuySignal      = CCI_SIGNAL_NONE;
   int      cciSellSignal     = CCI_SIGNAL_NONE;
   datetime cciBuySignalTime  = 0;
   datetime cciSellSignalTime = 0;
   bool     cciBuy             = GetCCISignal(1, cciBuySignal, cciBuySignalTime);
   bool     cciSell            = GetCCISignal(-1, cciSellSignal, cciSellSignalTime);

   int    hiloTrend     = GetHiLoTrend();
   int    psarState     = GetMainPSARState();
   int    stTrend       = GetMainSuperTrendDirection();
   int    adxState      = 0;
   bool   adxAllowBuy   = true;
   bool   adxAllowSell  = true;
   int    stFilterDir   = 0;
   bool   stFilterAllowBuy  = true;
   bool   stFilterAllowSell = true;
   int    mainStrategyOpenCount = CountMainStrategyPositions();

   bool mainHiLoPassBuy  = (!InpUseMainHiLoFilter || hiloTrend == 1);
   bool mainPsarPassBuy  = (!InpUseMainPsarFilter || psarState == 1);
   bool mainStPassBuy    = (!InpUseMainSuperTrendFilter || stTrend == 1);
   bool mainHiLoPassSell = (!InpUseMainHiLoFilter || hiloTrend == -1);
   bool mainPsarPassSell = (!InpUseMainPsarFilter || psarState == -1);
   bool mainStPassSell   = (!InpUseMainSuperTrendFilter || stTrend == -1);

   PrintDebug(StringFormat("Signals: CCI_Buy=%s(%s) CCI_Sell=%s(%s) HiLo=%d(%s) PSAR=%d(%s) ST=%d(%s)",
              cciBuy?"Y":"N", CCISignalTypeToString(cciBuySignal),
              cciSell?"Y":"N", CCISignalTypeToString(cciSellSignal),
              hiloTrend, (InpUseMainHiLoFilter ? "ON" : "OFF"),
              psarState, (InpUseMainPsarFilter ? "ON" : "OFF"),
              stTrend, (InpUseMainSuperTrendFilter ? "ON" : "OFF")));

//--- ADX Filter built-in: ADX strength (optional DI cross bias)
   if(InpEnableAdxFilter && g_handles.adx != INVALID_HANDLE)
     {
      adxState = GetAdxFilterState();
      adxAllowBuy  = (adxState == 1 || adxState == 2);
      adxAllowSell = (adxState == -1 || adxState == 2);
      PrintDebug(StringFormat("ADX filter state=%d (2=adx-only strong,1=bullish,-1=bearish,0=blocked)", adxState));
     }

//--- SuperTrend MTF Filter
   if(InpEnableSTMTF && g_handles.stFilter != INVALID_HANDLE)
     {
      stFilterDir = GetSTFilterDirection();
      stFilterAllowBuy  = (stFilterDir == 1);
      stFilterAllowSell = (stFilterDir == -1);
      PrintDebug(StringFormat("ST MTF filter dir=%d TF=%s (1=up,-1=down,0=unknown)",
                 stFilterDir, EnumToString(InpSTFilterTF)));
     }

//--- Evaluasi entry BUY
   if(InpEnableBuy && cciBuy)
     {
      // Cek re-entry: pastikan sinyal ini belum pernah dipakai
      datetime buySignalTime = cciBuySignalTime;

      bool isNewBuySignal = (buySignalTime != g_lastBuySignalUsed);
      bool allowBuyReuse = (InpMainSignalReentryMode == MAIN_SIGNAL_REENTRY_PROFIT_SAME_SIGNAL
                            && !isNewBuySignal
                            && g_mainAllowBuySignalReuse);
      if(isNewBuySignal || allowBuyReuse)  // Sinyal baru, atau reuse same signal setelah close profit
        {
         if(mainHiLoPassBuy && mainPsarPassBuy && mainStPassBuy)
           {
            if(InpEnableAdxFilter && g_handles.adx != INVALID_HANDLE && !adxAllowBuy)
              {
               PrintDebug("BUY blocked: adxTrendFilter not bullish");
              }
            else if(InpEnableSTMTF && g_handles.stFilter != INVALID_HANDLE && !stFilterAllowBuy)
              {
               PrintDebug(StringFormat("BUY blocked: SuperTrend MTF (%s) not UP (dir=%d)",
                          EnumToString(InpSTFilterTF), stFilterDir));
              }
            else if(InpMainPositionMode == MAIN_POSITION_MODE_SINGLE_ACTIVE && mainStrategyOpenCount > 0)
              {
               PrintDebug("BUY blocked: Main position mode SINGLE_ACTIVE and an original strategy position is still open");
              }
            else if(CountMainStrategyPositionsByType(POSITION_TYPE_BUY) < InpMaxBuyPositions)
              {
               if(ExecuteBuy(cciBuySignal, buySignalTime))
                 {
                  g_lastBuySignalUsed = buySignalTime;
                  g_mainAllowBuySignalReuse = false;
                  mainStrategyOpenCount = CountMainStrategyPositions();
                  Print("INFO: BUY executed. SignalTime=", buySignalTime,
                        " CCIType=", CCISignalTypeToString(cciBuySignal));
                 }
              }
            else
               PrintDebug("BUY blocked: Max buy positions reached");
           }
         else
            PrintDebug(StringFormat("BUY blocked: Confirma incomplete. HiLo=%d(use=%s) PSAR=%d(use=%s) ST=%d(use=%s)",
                       hiloTrend, (InpUseMainHiLoFilter ? "Y" : "N"),
                       psarState, (InpUseMainPsarFilter ? "Y" : "N"),
                       stTrend, (InpUseMainSuperTrendFilter ? "Y" : "N")));
        }
      else
         PrintDebug("BUY blocked: Signal already used at " + TimeToString(buySignalTime));
     }

//--- Evaluasi entry SELL
   if(InpEnableSell && cciSell)
     {
      datetime sellSignalTime = cciSellSignalTime;

      bool isNewSellSignal = (sellSignalTime != g_lastSellSignalUsed);
      bool allowSellReuse = (InpMainSignalReentryMode == MAIN_SIGNAL_REENTRY_PROFIT_SAME_SIGNAL
                             && !isNewSellSignal
                             && g_mainAllowSellSignalReuse);
      if(isNewSellSignal || allowSellReuse)
        {
         if(mainHiLoPassSell && mainPsarPassSell && mainStPassSell)
           {
            if(InpEnableAdxFilter && g_handles.adx != INVALID_HANDLE && !adxAllowSell)
              {
               PrintDebug("SELL blocked: adxTrendFilter not bearish");
              }
            else if(InpEnableSTMTF && g_handles.stFilter != INVALID_HANDLE && !stFilterAllowSell)
              {
               PrintDebug(StringFormat("SELL blocked: SuperTrend MTF (%s) not DOWN (dir=%d)",
                          EnumToString(InpSTFilterTF), stFilterDir));
              }
            else if(InpMainPositionMode == MAIN_POSITION_MODE_SINGLE_ACTIVE && mainStrategyOpenCount > 0)
              {
               PrintDebug("SELL blocked: Main position mode SINGLE_ACTIVE and an original strategy position is still open");
              }
            else if(CountMainStrategyPositionsByType(POSITION_TYPE_SELL) < InpMaxSellPositions)
              {
               if(ExecuteSell(cciSellSignal, sellSignalTime))
                 {
                  g_lastSellSignalUsed = sellSignalTime;
                  g_mainAllowSellSignalReuse = false;
                  mainStrategyOpenCount = CountMainStrategyPositions();
                  Print("INFO: SELL executed. SignalTime=", sellSignalTime,
                        " CCIType=", CCISignalTypeToString(cciSellSignal));
                 }
              }
            else
               PrintDebug("SELL blocked: Max sell positions reached");
           }
         else
            PrintDebug(StringFormat("SELL blocked: Confirma incomplete. HiLo=%d(use=%s) PSAR=%d(use=%s) ST=%d(use=%s)",
                       hiloTrend, (InpUseMainHiLoFilter ? "Y" : "N"),
                       psarState, (InpUseMainPsarFilter ? "Y" : "N"),
                       stTrend, (InpUseMainSuperTrendFilter ? "Y" : "N")));
        }
      else
         PrintDebug("SELL blocked: Signal already used at " + TimeToString(sellSignalTime));
     }
  }

//+------------------------------------------------------------------+
//| CCI Signal Reader                                                |
//| side: 1 = cari Buy/StrongBuy, -1 = cari Sell/StrongSell         |
//| Scan bar 1..InpCciSignalValidityBars (bar 0 masih running)       |
//| Returns true jika sinyal valid ditemukan                         |
//+------------------------------------------------------------------+
//| HiLo Trend Reader                                                |
//| Buffer 8 = TrendBuffer, AsSeries=false                           |
//| Return: 1 = UP, -1 = DOWN, 0 = unknown                          |
//+------------------------------------------------------------------+
//| Read PSAR direction from a specific indicator handle             |
//| RECOVERY MODE FUNCTIONS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if a position comment contains recovery tag                |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Count currently open recovery positions                          |
//+------------------------------------------------------------------+
//| Count recovery positions by type                                |
//+------------------------------------------------------------------+
//| Classify a closing deal by looking up original ENTRY deal        |
//| Returns true if the position was a recovery position             |
//| Uses DEAL_POSITION_ID to find the entry deal's comment           |
//+------------------------------------------------------------------+
//| Draw recovery zone line on chart                                 |
//+------------------------------------------------------------------+
//| Delete recovery zone lines from chart                            |
//+------------------------------------------------------------------+
//| Reset recovery state                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get total floating profit of all recovery positions              |
//+------------------------------------------------------------------+
//| Close all recovery positions                                     |
//+------------------------------------------------------------------+
//| Get recovery floating profit (profit only, no swap/commission)   |
//+------------------------------------------------------------------+
//| Prepare next classic cycle or finish accumulated recovery        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Close CLASSIC recovery exposure and end cycle on success         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Classic cycle target check (profit-only)                         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Classic basket trailing per cycle (profit-only)                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Main strategy lot calculator (fixed or dynamic)                 |
//+------------------------------------------------------------------+
//| Classic Zone: set pending start (wait ST+PSAR)                   |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Start recovery after a strategy position closes at a loss        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Calculate recovery zone range based on mode (fixed or ATR)       |
//+------------------------------------------------------------------+
//| Calculate GRID step price based on mode (fixed or ATR)          |
//+------------------------------------------------------------------+
//| Build recovery zone high & low from close price                  |
//+------------------------------------------------------------------+
//| Build recovery zone from ST+PSAR signal price (Classic pending)  |
//+------------------------------------------------------------------+
//| Get recovery trend direction from SuperTrend + PSAR              |
//| Returns: 1 = BUY only, -1 = SELL only, 0 = not synced           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Classic Zone pending-start trend filter direction                 |
//| Returns: 1 = BUY, -1 = SELL, 0 = not synced                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Distance mode ST+PSAR trend filter direction                     |
//| Returns: 1 = BUY, -1 = SELL, 0 = not synced                      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Get distance recovery signal direction (selectable source)      |
//| Returns: 1 = BUY only, -1 = SELL only, 0 = no signal            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Classic Zone: start recovery after ST+PSAR signal (pending)      |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Update recovery closed profit from a closed recovery deal        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Count pending recovery orders (symbol + magic + recovery tag)    |
//+------------------------------------------------------------------+
//| Delete all pending recovery orders                               |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Start-Reverse Recovery (first entry forced reverse, then classic)|
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Execute one distance recovery order                              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Distance Recovery (selectable signal + fixed min distance)     |
//| Entry only on candle close                                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Grid Trend-Signal Recovery                                       |
//| Anchor locked on first synced ST+PSAR candle close              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Grid Recovery                                                     |
//| Execute recovery positions at grid levels from anchor price       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Classic Zone Recovery (two-way: buy atas, sell bawah)             |
//| Entry setiap tick, bergantian buy/sell                            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trend Recovery (one-way: searah SuperTrend+PSAR)                 |
//| Entry hanya saat candle close, zone = permission level            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trade Transaction Handler                                        |
//| Detects position close → triggers recovery if loss               |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(!HistoryDealSelect(trans.deal))
      return;

   string dealSymbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
   long   dealMagic  = (long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   long   dealEntry  = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(dealSymbol != _Symbol || dealMagic != InpMagicNumber)
      return;

   long dealReason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
   long dealType   = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
   string dealComment = HistoryDealGetString(trans.deal, DEAL_COMMENT);

   if(dealEntry == DEAL_ENTRY_IN)
     {
      RegisterOriginalTradeDiagnosticFromEntryDeal(trans.deal, dealComment);
      return;
     }
   if(dealEntry != DEAL_ENTRY_OUT)
      return;

   // Save deal P/L before HistorySelectByPosition changes context
   double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                   + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                   + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);

   // Classify by looking up the ENTRY deal of this position (reliable)
   bool isRecovery = IsRecoveryDealByPosition(trans.deal);
   // Fallback: some brokers/deal flows may carry recovery tag directly on close deal comment.
   if(!isRecovery && IsRecoveryComment(dealComment))
      isRecovery = true;
   bool isStrategy = !isRecovery;
   if(isStrategy)
     {
      FinalizeOriginalTradeDiagnostic(trans.deal, profit, dealReason);

      // DEAL_TYPE_SELL on OUT = closing BUY, DEAL_TYPE_BUY on OUT = closing SELL
      if(dealType == DEAL_TYPE_SELL)
        {
         g_mainAllowBuySignalReuse = (InpMainSignalReentryMode == MAIN_SIGNAL_REENTRY_PROFIT_SAME_SIGNAL && profit > 0.0);
         if(g_mainAllowBuySignalReuse)
            Print("INFO: [MAIN_REENTRY] BUY signal reuse armed after positive close. Profit=", DoubleToString(profit, 2));
        }
      else if(dealType == DEAL_TYPE_BUY)
        {
         g_mainAllowSellSignalReuse = (InpMainSignalReentryMode == MAIN_SIGNAL_REENTRY_PROFIT_SAME_SIGNAL && profit > 0.0);
         if(g_mainAllowSellSignalReuse)
            Print("INFO: [MAIN_REENTRY] SELL signal reuse armed after positive close. Profit=", DoubleToString(profit, 2));
        }
     }

   if(g_recoveryActive)
      Print("DEBUG: [RECOVERY_TX] Deal=", trans.deal,
            " Entry=", dealEntry,
            " Type=", dealType,
            " Reason=", dealReason,
            " Profit=", DoubleToString(profit, 2),
            " Comment='", dealComment, "'",
            " IsRecovery=", (isRecovery ? "true" : "false"),
            " RecoveryActive=", (g_recoveryActive ? "true" : "false"),
            " ClosingGuard=", (g_closingRecoveryPositions ? "true" : "false"));

   // Update recovery closed P/L if this is a recovery position closing
   if(g_recoveryActive && isRecovery)
     {
      g_recoveryClosedProfit += profit;
      Print("INFO: [RECOVERY_PNL] ClosedProfitUpdated=",
            DoubleToString(g_recoveryClosedProfit, 2),
            " LastDealProfit=", DoubleToString(profit, 2));
     }

   // Start recovery if: enabled, not active, not in cooldown, strategy position closed at loss
   if(InpEnableRecovery && !g_recoveryActive && profit < 0.0 && isStrategy)
     {
      if(g_recoveryRestartGuardUntil > 0 && TimeCurrent() < g_recoveryRestartGuardUntil)
        {
         Print("INFO: Recovery start blocked by short restart guard. Guard until ",
               TimeToString(g_recoveryRestartGuardUntil));
         return;
        }

      // Block new recovery during cooldown
      if(InpRecoveryCooldownBars > 0 && g_recoveryCooldownUntil > 0)
        {
         datetime currentBarTime = iTime(_Symbol, _Period, 0);
         if(currentBarTime < g_recoveryCooldownUntil)
           {
            Print("INFO: Recovery start blocked by cooldown. Loss ignored. Cooldown until ",
                  TimeToString(g_recoveryCooldownUntil));
            return;
           }
        }
      StartRecoveryFromLossDeal(trans.deal);
     }
  }

//+------------------------------------------------------------------+
