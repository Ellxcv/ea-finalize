//+------------------------------------------------------------------+
//|             TS7/Diagnostics/OriginalTradeDiagnostics.mqh         |
//|     Observation-only telemetry for original strategy trades     |
//+------------------------------------------------------------------+
#ifndef TS7_DIAGNOSTICS_ORIGINALTRADEDIAGNOSTICS_MQH
#define TS7_DIAGNOSTICS_ORIGINALTRADEDIAGNOSTICS_MQH

const int ORIGINAL_DIAG_TREND_AGE_LOOKBACK = 200;

struct SOriginalTradeDiagnostic
  {
   bool               active;
   long               positionId;
   ulong              positionTicket;
   ENUM_POSITION_TYPE positionType;
   datetime           signalTime;
   int                signalAgeBars;
   int                cciSignalType;
   datetime           entryTime;
   double             entryPrice;
   double             entryVolume;
   double             entryAtrPoints;
   double             entryRangePoints;
   double             entrySpreadPoints;
   double             entryEmaPrice;
   double             impulse3Atr;
   double             impulse5Atr;
   double             distanceEmaAtr;
   double             signalDriftAtr;
   bool               contextReady;
   int                hiloAgeBars;
   int                psarAgeBars;
   int                superTrendAgeBars;
   int                stMtfAgeBars;
   double             emaSlope5Atr;
   double             emaSlope10Atr;
   bool               trendContextReady;
   double             mfePoints;
   double             maePoints;
   double             maxProfitMoney;
   double             maxLossMoney;
  };

SOriginalTradeDiagnostic g_originalDiagnostics[];

bool     g_originalDiagPending = false;
int      g_originalDiagPendingDirection = 0;
int      g_originalDiagPendingCciType = CCI_SIGNAL_NONE;
datetime g_originalDiagPendingSignalTime = 0;

int    g_originalDiagClosed = 0;
int    g_originalDiagWinners = 0;
int    g_originalDiagLosers = 0;
int    g_originalDiagNeutral = 0;
int    g_originalDiagLoserMfeLt100 = 0;
int    g_originalDiagLoserMfeGe250 = 0;
int    g_originalDiagLoserMfeGe500 = 0;
int    g_originalDiagDataErrors = 0;
int    g_originalDiagContextErrors = 0;
int    g_originalDiagTrendContextErrors = 0;
double g_originalDiagWinnerMfeTotal = 0.0;
double g_originalDiagWinnerMaeTotal = 0.0;
double g_originalDiagLoserMfeTotal = 0.0;
double g_originalDiagLoserMaeTotal = 0.0;

//+------------------------------------------------------------------+
void ResetOriginalTradeDiagnostics()
  {
   ArrayResize(g_originalDiagnostics, 0);
   g_originalDiagPending = false;
   g_originalDiagPendingDirection = 0;
   g_originalDiagPendingCciType = CCI_SIGNAL_NONE;
   g_originalDiagPendingSignalTime = 0;
   g_originalDiagClosed = 0;
   g_originalDiagWinners = 0;
   g_originalDiagLosers = 0;
   g_originalDiagNeutral = 0;
   g_originalDiagLoserMfeLt100 = 0;
   g_originalDiagLoserMfeGe250 = 0;
   g_originalDiagLoserMfeGe500 = 0;
   g_originalDiagDataErrors = 0;
   g_originalDiagContextErrors = 0;
   g_originalDiagTrendContextErrors = 0;
   g_originalDiagWinnerMfeTotal = 0.0;
   g_originalDiagWinnerMaeTotal = 0.0;
   g_originalDiagLoserMfeTotal = 0.0;
   g_originalDiagLoserMaeTotal = 0.0;
  }

//+------------------------------------------------------------------+
void PrepareOriginalTradeDiagnostic(const int direction,
                                    const int cciSignalType,
                                    const datetime signalTime)
  {
   if(!InpEnableOriginalTradeDiagnostics)
      return;

   g_originalDiagPending = true;
   g_originalDiagPendingDirection = direction;
   g_originalDiagPendingCciType = cciSignalType;
   g_originalDiagPendingSignalTime = signalTime;
  }

//+------------------------------------------------------------------+
void CancelOriginalTradeDiagnostic()
  {
   g_originalDiagPending = false;
   g_originalDiagPendingDirection = 0;
   g_originalDiagPendingCciType = CCI_SIGNAL_NONE;
   g_originalDiagPendingSignalTime = 0;
  }

//+------------------------------------------------------------------+
int FindOriginalDiagnosticByPositionId(const long positionId)
  {
   for(int i = 0; i < ArraySize(g_originalDiagnostics); i++)
     {
      if(g_originalDiagnostics[i].active &&
         g_originalDiagnostics[i].positionId == positionId)
         return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
ulong FindOriginalPositionTicketByIdentifier(const long positionId)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if((long)PositionGetInteger(POSITION_IDENTIFIER) == positionId)
         return ticket;
     }
   return 0;
  }

//+------------------------------------------------------------------+
double ReadOriginalDiagnosticAtrPoints()
  {
   if(g_handles.originalDiagATR == INVALID_HANDLE)
      return 0.0;

   double atrBuffer[1];
   if(CopyBuffer(g_handles.originalDiagATR, 0, 1, 1, atrBuffer) != 1)
      return 0.0;
   if(_Point <= 0.0)
      return 0.0;
   return atrBuffer[0] / _Point;
  }

//+------------------------------------------------------------------+
double ReadOriginalDiagnosticEmaPrice()
  {
   if(g_handles.originalDiagEMA == INVALID_HANDLE)
      return 0.0;

   double emaBuffer[1];
   if(CopyBuffer(g_handles.originalDiagEMA, 0, 1, 1, emaBuffer) != 1)
      return 0.0;
   return emaBuffer[0];
  }

//+------------------------------------------------------------------+
double ReadOriginalDiagnosticEmaPriceAtShift(const int shift)
  {
   if(g_handles.originalDiagEMA == INVALID_HANDLE || shift < 0)
      return 0.0;

   double emaBuffer[1];
   if(CopyBuffer(g_handles.originalDiagEMA, 0, shift, 1, emaBuffer) != 1)
      return 0.0;
   if(emaBuffer[0] == EMPTY_VALUE || !MathIsValidNumber(emaBuffer[0]))
      return 0.0;
   return emaBuffer[0];
  }

//+------------------------------------------------------------------+
int OriginalDiagnosticTrendState(const double value)
  {
   if(value == EMPTY_VALUE || !MathIsValidNumber(value))
      return 0;
   if(value == 1.0)
      return 1;
   if(value == -1.0)
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
int ReadOriginalDiagnosticBufferTrendAge(const int handle,
                                         const int bufferIndex,
                                         const int entryDirection)
  {
   if(handle == INVALID_HANDLE || entryDirection == 0)
      return 0;

   double trendBuffer[];
   ArraySetAsSeries(trendBuffer, true);
   int copied = CopyBuffer(handle, bufferIndex, 1,
                           ORIGINAL_DIAG_TREND_AGE_LOOKBACK, trendBuffer);
   if(copied <= 0)
      return 0;

   int currentState = OriginalDiagnosticTrendState(trendBuffer[0]);
   if(currentState == 0)
      return 0;

   int ageBars = 0;
   for(int i = 0; i < copied; i++)
     {
      int state = OriginalDiagnosticTrendState(trendBuffer[i]);
      if(state != currentState)
         break;
      ageBars++;
     }

   return entryDirection * currentState * ageBars;
  }

//+------------------------------------------------------------------+
int ReadOriginalDiagnosticPsarTrendAge(const int handle,
                                       const ENUM_TIMEFRAMES timeframe,
                                       const int entryDirection)
  {
   if(handle == INVALID_HANDLE || entryDirection == 0)
      return 0;

   ENUM_TIMEFRAMES resolvedTimeframe = (timeframe == PERIOD_CURRENT)
                                      ? (ENUM_TIMEFRAMES)_Period
                                      : timeframe;
   double psarBuffer[];
   double closeBuffer[];
   ArraySetAsSeries(psarBuffer, true);
   ArraySetAsSeries(closeBuffer, true);

   int copiedPsar = CopyBuffer(handle, 0, 1,
                               ORIGINAL_DIAG_TREND_AGE_LOOKBACK, psarBuffer);
   int copiedClose = CopyClose(_Symbol, resolvedTimeframe, 1,
                               ORIGINAL_DIAG_TREND_AGE_LOOKBACK, closeBuffer);
   int copied = MathMin(copiedPsar, copiedClose);
   if(copied <= 0)
      return 0;

   int currentState = 0;
   int ageBars = 0;
   for(int i = 0; i < copied; i++)
     {
      if(psarBuffer[i] == EMPTY_VALUE ||
         !MathIsValidNumber(psarBuffer[i]) ||
         !MathIsValidNumber(closeBuffer[i]))
         break;

      int state = 0;
      if(closeBuffer[i] > psarBuffer[i])
         state = 1;
      else if(closeBuffer[i] < psarBuffer[i])
         state = -1;

      if(i == 0)
        {
         currentState = state;
         if(currentState == 0)
            return 0;
        }
      if(state != currentState)
         break;
      ageBars++;
     }

   return entryDirection * currentState * ageBars;
  }

//+------------------------------------------------------------------+
void UpdateOriginalDiagnosticExcursion(const int index,
                                       const double closeablePrice,
                                       const double currentMoney)
  {
   if(index < 0 || index >= ArraySize(g_originalDiagnostics) || _Point <= 0.0)
      return;

   double favorablePoints = 0.0;
   double adversePoints = 0.0;
   if(g_originalDiagnostics[index].positionType == POSITION_TYPE_BUY)
     {
      favorablePoints = (closeablePrice - g_originalDiagnostics[index].entryPrice) / _Point;
      adversePoints = (g_originalDiagnostics[index].entryPrice - closeablePrice) / _Point;
     }
   else
     {
      favorablePoints = (g_originalDiagnostics[index].entryPrice - closeablePrice) / _Point;
      adversePoints = (closeablePrice - g_originalDiagnostics[index].entryPrice) / _Point;
     }

   g_originalDiagnostics[index].mfePoints =
      MathMax(g_originalDiagnostics[index].mfePoints, MathMax(0.0, favorablePoints));
   g_originalDiagnostics[index].maePoints =
      MathMax(g_originalDiagnostics[index].maePoints, MathMax(0.0, adversePoints));
   g_originalDiagnostics[index].maxProfitMoney =
      MathMax(g_originalDiagnostics[index].maxProfitMoney, currentMoney);
   g_originalDiagnostics[index].maxLossMoney =
      MathMin(g_originalDiagnostics[index].maxLossMoney, currentMoney);
  }

//+------------------------------------------------------------------+
void RegisterOriginalTradeDiagnosticFromEntryDeal(const ulong dealTicket,
                                                  const string dealComment)
  {
   if(!InpEnableOriginalTradeDiagnostics)
      return;
   if(StringFind(dealComment, "[REC]") >= 0)
      return;

   long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL)
      return;

   long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   if(positionId <= 0 || FindOriginalDiagnosticByPositionId(positionId) >= 0)
      return;

   int direction = (dealType == DEAL_TYPE_BUY ? 1 : -1);
   bool pendingMatches = (g_originalDiagPending &&
                          g_originalDiagPendingDirection == direction);
   if(!pendingMatches)
      return;

   int index = ArraySize(g_originalDiagnostics);
   if(ArrayResize(g_originalDiagnostics, index + 1) != index + 1)
     {
      g_originalDiagDataErrors++;
      Print("WARNING: [ORIGINAL_DIAG] Cannot allocate record for PositionId=", positionId);
      return;
     }

   g_originalDiagnostics[index].active = true;
   g_originalDiagnostics[index].positionId = positionId;
   g_originalDiagnostics[index].positionTicket =
      FindOriginalPositionTicketByIdentifier(positionId);
   g_originalDiagnostics[index].positionType =
      (dealType == DEAL_TYPE_BUY ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
   g_originalDiagnostics[index].signalTime =
      (pendingMatches ? g_originalDiagPendingSignalTime : 0);
   g_originalDiagnostics[index].signalAgeBars =
      (pendingMatches && g_originalDiagPendingSignalTime > 0
       ? iBarShift(_Symbol, _Period, g_originalDiagPendingSignalTime, false)
       : -1);
   g_originalDiagnostics[index].cciSignalType =
      (pendingMatches ? g_originalDiagPendingCciType : CCI_SIGNAL_NONE);
   g_originalDiagnostics[index].entryTime =
      (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   g_originalDiagnostics[index].entryPrice =
      HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   g_originalDiagnostics[index].entryVolume =
      HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   g_originalDiagnostics[index].entryAtrPoints = ReadOriginalDiagnosticAtrPoints();
   g_originalDiagnostics[index].entryRangePoints =
      (_Point > 0.0 ? (iHigh(_Symbol, _Period, 1) - iLow(_Symbol, _Period, 1)) / _Point : 0.0);
   g_originalDiagnostics[index].entryEmaPrice = ReadOriginalDiagnosticEmaPrice();

   double atrPrice = g_originalDiagnostics[index].entryAtrPoints * _Point;
   double close1 = iClose(_Symbol, _Period, 1);
   double close4 = iClose(_Symbol, _Period, 4);
   double close6 = iClose(_Symbol, _Period, 6);
   double signalClose =
      (g_originalDiagnostics[index].signalAgeBars >= 0
       ? iClose(_Symbol, _Period, g_originalDiagnostics[index].signalAgeBars)
       : 0.0);
   g_originalDiagnostics[index].contextReady =
      (atrPrice > 0.0 &&
       g_originalDiagnostics[index].entryEmaPrice > 0.0 &&
       close1 > 0.0 && close4 > 0.0 && close6 > 0.0 && signalClose > 0.0);
   g_originalDiagnostics[index].impulse3Atr = 0.0;
   g_originalDiagnostics[index].impulse5Atr = 0.0;
   g_originalDiagnostics[index].distanceEmaAtr = 0.0;
   g_originalDiagnostics[index].signalDriftAtr = 0.0;
   if(g_originalDiagnostics[index].contextReady)
     {
      g_originalDiagnostics[index].impulse3Atr =
         direction * (close1 - close4) / atrPrice;
      g_originalDiagnostics[index].impulse5Atr =
         direction * (close1 - close6) / atrPrice;
      g_originalDiagnostics[index].distanceEmaAtr =
         direction * (g_originalDiagnostics[index].entryPrice
                      - g_originalDiagnostics[index].entryEmaPrice) / atrPrice;
      g_originalDiagnostics[index].signalDriftAtr =
         direction * (g_originalDiagnostics[index].entryPrice - signalClose) / atrPrice;
     }
   else
     {
      g_originalDiagContextErrors++;
      Print("WARNING: [ORIGINAL_DIAG] Entry context not ready. PositionId=", positionId,
            " SignalAge=", g_originalDiagnostics[index].signalAgeBars);
     }

   int mainPsarHandle = (g_handles.mainPSAR != INVALID_HANDLE
                         ? g_handles.mainPSAR : g_handles.psar);
   int mainSuperTrendHandle = (g_handles.mainSuperTrend != INVALID_HANDLE
                               ? g_handles.mainSuperTrend : g_handles.superTrend);
   double emaShift6 = ReadOriginalDiagnosticEmaPriceAtShift(6);
   double emaShift11 = ReadOriginalDiagnosticEmaPriceAtShift(11);

   g_originalDiagnostics[index].hiloAgeBars = 0;
   g_originalDiagnostics[index].psarAgeBars = 0;
   g_originalDiagnostics[index].superTrendAgeBars = 0;
   g_originalDiagnostics[index].stMtfAgeBars = 0;
   g_originalDiagnostics[index].emaSlope5Atr = 0.0;
   g_originalDiagnostics[index].emaSlope10Atr = 0.0;

   if(InpUseMainHiLoFilter)
      g_originalDiagnostics[index].hiloAgeBars =
         ReadOriginalDiagnosticBufferTrendAge(g_handles.hilo, 8, direction);
   if(InpUseMainPsarFilter)
      g_originalDiagnostics[index].psarAgeBars =
         ReadOriginalDiagnosticPsarTrendAge(mainPsarHandle,
                                            InpMainPsarTimeframe, direction);
   if(InpUseMainSuperTrendFilter)
      g_originalDiagnostics[index].superTrendAgeBars =
         ReadOriginalDiagnosticBufferTrendAge(mainSuperTrendHandle, 4, direction);
   if(InpEnableSTMTF)
      g_originalDiagnostics[index].stMtfAgeBars =
         ReadOriginalDiagnosticBufferTrendAge(g_handles.stFilter, 4, direction);

   g_originalDiagnostics[index].trendContextReady =
      (atrPrice > 0.0 &&
       emaShift6 > 0.0 &&
       emaShift11 > 0.0 &&
       (!InpUseMainHiLoFilter || g_originalDiagnostics[index].hiloAgeBars != 0) &&
       (!InpUseMainPsarFilter || g_originalDiagnostics[index].psarAgeBars != 0) &&
       (!InpUseMainSuperTrendFilter ||
        g_originalDiagnostics[index].superTrendAgeBars != 0) &&
       (!InpEnableSTMTF || g_originalDiagnostics[index].stMtfAgeBars != 0));
   if(g_originalDiagnostics[index].trendContextReady)
     {
      g_originalDiagnostics[index].emaSlope5Atr =
         direction * (g_originalDiagnostics[index].entryEmaPrice - emaShift6) / atrPrice;
      g_originalDiagnostics[index].emaSlope10Atr =
         direction * (g_originalDiagnostics[index].entryEmaPrice - emaShift11) / atrPrice;
     }
   else
     {
      g_originalDiagTrendContextErrors++;
      Print("WARNING: [ORIGINAL_DIAG] Trend context not ready. PositionId=", positionId,
            " HiLoAge=", g_originalDiagnostics[index].hiloAgeBars,
            " PsarAge=", g_originalDiagnostics[index].psarAgeBars,
            " SuperTrendAge=", g_originalDiagnostics[index].superTrendAgeBars,
            " STMTFAge=", g_originalDiagnostics[index].stMtfAgeBars);
     }

   MqlTick tick;
   g_originalDiagnostics[index].entrySpreadPoints = 0.0;
   if(SymbolInfoTick(_Symbol, tick) && _Point > 0.0)
      g_originalDiagnostics[index].entrySpreadPoints = (tick.ask - tick.bid) / _Point;

   g_originalDiagnostics[index].mfePoints = 0.0;
   g_originalDiagnostics[index].maePoints = 0.0;
   g_originalDiagnostics[index].maxProfitMoney = 0.0;
   g_originalDiagnostics[index].maxLossMoney = 0.0;

   Print("TS7_ORIGINAL_OPEN",
         "|PositionId=", positionId,
         "|Ticket=", g_originalDiagnostics[index].positionTicket,
         "|Side=", (dealType == DEAL_TYPE_BUY ? "BUY" : "SELL"),
         "|SignalTime=", TimeToString(g_originalDiagnostics[index].signalTime,
                                      TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         "|SignalAge=", g_originalDiagnostics[index].signalAgeBars,
         "|CCIType=", CCISignalTypeToString(g_originalDiagnostics[index].cciSignalType),
         "|EntryTime=", TimeToString(g_originalDiagnostics[index].entryTime,
                                     TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         "|EntryPrice=", DoubleToString(g_originalDiagnostics[index].entryPrice, _Digits),
         "|Volume=", DoubleToString(g_originalDiagnostics[index].entryVolume, 2),
         "|EntryATRPoints=", DoubleToString(g_originalDiagnostics[index].entryAtrPoints, 1),
         "|EntryRangePoints=", DoubleToString(g_originalDiagnostics[index].entryRangePoints, 1),
         "|SpreadPoints=", DoubleToString(g_originalDiagnostics[index].entrySpreadPoints, 1),
         "|EntryEMA=", DoubleToString(g_originalDiagnostics[index].entryEmaPrice, _Digits),
         "|Impulse3ATR=", DoubleToString(g_originalDiagnostics[index].impulse3Atr, 3),
         "|Impulse5ATR=", DoubleToString(g_originalDiagnostics[index].impulse5Atr, 3),
         "|DistanceEMAATR=", DoubleToString(g_originalDiagnostics[index].distanceEmaAtr, 3),
         "|SignalDriftATR=", DoubleToString(g_originalDiagnostics[index].signalDriftAtr, 3),
         "|ContextReady=", (g_originalDiagnostics[index].contextReady ? "true" : "false"),
         "|HiLoAgeBars=", g_originalDiagnostics[index].hiloAgeBars,
         "|PsarAgeBars=", g_originalDiagnostics[index].psarAgeBars,
         "|SuperTrendAgeBars=", g_originalDiagnostics[index].superTrendAgeBars,
         "|STMTFAgeBars=", g_originalDiagnostics[index].stMtfAgeBars,
         "|EMASlope5ATR=", DoubleToString(g_originalDiagnostics[index].emaSlope5Atr, 3),
         "|EMASlope10ATR=", DoubleToString(g_originalDiagnostics[index].emaSlope10Atr, 3),
         "|TrendContextReady=",
         (g_originalDiagnostics[index].trendContextReady ? "true" : "false"));

   if(pendingMatches)
      CancelOriginalTradeDiagnostic();
  }

//+------------------------------------------------------------------+
void UpdateOriginalTradeDiagnostics()
  {
   if(!InpEnableOriginalTradeDiagnostics || ArraySize(g_originalDiagnostics) == 0)
      return;

   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;

   for(int i = 0; i < ArraySize(g_originalDiagnostics); i++)
     {
      if(!g_originalDiagnostics[i].active)
         continue;

      ulong ticket = FindOriginalPositionTicketByIdentifier(
                        g_originalDiagnostics[i].positionId);
      if(ticket == 0)
         continue;

      g_originalDiagnostics[i].positionTicket = ticket;
      double currentMoney = PositionGetDouble(POSITION_PROFIT)
                            + PositionGetDouble(POSITION_SWAP);
      double closeablePrice =
         (g_originalDiagnostics[i].positionType == POSITION_TYPE_BUY ? tick.bid : tick.ask);
      UpdateOriginalDiagnosticExcursion(i, closeablePrice, currentMoney);
     }
  }

//+------------------------------------------------------------------+
void FinalizeOriginalTradeDiagnostic(const ulong dealTicket,
                                     const double finalProfit,
                                     const long dealReason)
  {
   if(!InpEnableOriginalTradeDiagnostics)
      return;

   // IsRecoveryDealByPosition() changes the selected history context.
   // Re-select the closing deal before reading its position, price, and time.
   if(!HistoryDealSelect(dealTicket))
     {
      g_originalDiagDataErrors++;
      Print("WARNING: [ORIGINAL_DIAG] Cannot re-select close deal. Deal=", dealTicket);
      return;
     }

   long positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   int index = FindOriginalDiagnosticByPositionId(positionId);
   if(index < 0)
     {
      g_originalDiagDataErrors++;
      Print("WARNING: [ORIGINAL_DIAG] Close record missing. PositionId=", positionId,
            " Deal=", dealTicket);
      return;
     }

   double exitPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   UpdateOriginalDiagnosticExcursion(index, exitPrice, finalProfit);
   datetime exitTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   int periodSeconds = PeriodSeconds(_Period);
   int barsHeld = (periodSeconds > 0
                   ? (int)((exitTime - g_originalDiagnostics[index].entryTime) / periodSeconds)
                   : 0);
   bool recoveryEligible = (InpEnableRecovery && finalProfit < 0.0);

   g_originalDiagClosed++;
   if(finalProfit > 0.0)
     {
      g_originalDiagWinners++;
      g_originalDiagWinnerMfeTotal += g_originalDiagnostics[index].mfePoints;
      g_originalDiagWinnerMaeTotal += g_originalDiagnostics[index].maePoints;
     }
   else if(finalProfit < 0.0)
     {
      g_originalDiagLosers++;
      g_originalDiagLoserMfeTotal += g_originalDiagnostics[index].mfePoints;
      g_originalDiagLoserMaeTotal += g_originalDiagnostics[index].maePoints;
      if(g_originalDiagnostics[index].mfePoints < 100.0)
         g_originalDiagLoserMfeLt100++;
      if(g_originalDiagnostics[index].mfePoints >= 250.0)
         g_originalDiagLoserMfeGe250++;
      if(g_originalDiagnostics[index].mfePoints >= 500.0)
         g_originalDiagLoserMfeGe500++;
     }
   else
      g_originalDiagNeutral++;

   Print("TS7_ORIGINAL_CLOSE",
         "|PositionId=", positionId,
         "|Ticket=", g_originalDiagnostics[index].positionTicket,
         "|Side=", (g_originalDiagnostics[index].positionType == POSITION_TYPE_BUY ? "BUY" : "SELL"),
         "|SignalAge=", g_originalDiagnostics[index].signalAgeBars,
         "|CCIType=", CCISignalTypeToString(g_originalDiagnostics[index].cciSignalType),
         "|ExitTime=", TimeToString(exitTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         "|ExitPrice=", DoubleToString(exitPrice, _Digits),
         "|BarsHeld=", barsHeld,
         "|MFEPoints=", DoubleToString(g_originalDiagnostics[index].mfePoints, 1),
         "|MAEPoints=", DoubleToString(g_originalDiagnostics[index].maePoints, 1),
         "|MaxProfitMoney=", DoubleToString(g_originalDiagnostics[index].maxProfitMoney, 2),
         "|MaxLossMoney=", DoubleToString(g_originalDiagnostics[index].maxLossMoney, 2),
         "|FinalProfit=", DoubleToString(finalProfit, 2),
         "|Reason=", EnumToString((ENUM_DEAL_REASON)dealReason),
         "|RecoveryEligible=", (recoveryEligible ? "true" : "false"));

   g_originalDiagnostics[index].active = false;
  }

//+------------------------------------------------------------------+
int CountActiveOriginalDiagnostics()
  {
   int count = 0;
   for(int i = 0; i < ArraySize(g_originalDiagnostics); i++)
     {
      if(g_originalDiagnostics[i].active)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
void PrintOriginalTradeDiagnosticsSummary()
  {
   if(!InpEnableOriginalTradeDiagnostics)
      return;

   double winnerAvgMfe = (g_originalDiagWinners > 0
                          ? g_originalDiagWinnerMfeTotal / g_originalDiagWinners : 0.0);
   double winnerAvgMae = (g_originalDiagWinners > 0
                          ? g_originalDiagWinnerMaeTotal / g_originalDiagWinners : 0.0);
   double loserAvgMfe = (g_originalDiagLosers > 0
                         ? g_originalDiagLoserMfeTotal / g_originalDiagLosers : 0.0);
   double loserAvgMae = (g_originalDiagLosers > 0
                         ? g_originalDiagLoserMaeTotal / g_originalDiagLosers : 0.0);

   Print("TS7_ORIGINAL_SUMMARY",
         "|Closed=", g_originalDiagClosed,
         "|Winners=", g_originalDiagWinners,
         "|Losers=", g_originalDiagLosers,
         "|Neutral=", g_originalDiagNeutral,
         "|LoserMFE_LT100=", g_originalDiagLoserMfeLt100,
         "|LoserMFE_GE250=", g_originalDiagLoserMfeGe250,
         "|LoserMFE_GE500=", g_originalDiagLoserMfeGe500,
         "|WinnerAvgMFE=", DoubleToString(winnerAvgMfe, 1),
         "|WinnerAvgMAE=", DoubleToString(winnerAvgMae, 1),
         "|LoserAvgMFE=", DoubleToString(loserAvgMfe, 1),
         "|LoserAvgMAE=", DoubleToString(loserAvgMae, 1),
         "|ActiveRemaining=", CountActiveOriginalDiagnostics(),
         "|DataErrors=", g_originalDiagDataErrors,
         "|ContextErrors=", g_originalDiagContextErrors,
         "|TrendContextErrors=", g_originalDiagTrendContextErrors);
  }

#endif // TS7_DIAGNOSTICS_ORIGINALTRADEDIAGNOSTICS_MQH
