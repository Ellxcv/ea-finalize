//+------------------------------------------------------------------+
//|             TS7/Diagnostics/OriginalTradeDiagnostics.mqh         |
//|     Observation-only telemetry for original strategy trades     |
//+------------------------------------------------------------------+
#ifndef TS7_DIAGNOSTICS_ORIGINALTRADEDIAGNOSTICS_MQH
#define TS7_DIAGNOSTICS_ORIGINALTRADEDIAGNOSTICS_MQH

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
         "|SpreadPoints=", DoubleToString(g_originalDiagnostics[index].entrySpreadPoints, 1));

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
         "|DataErrors=", g_originalDiagDataErrors);
  }

#endif // TS7_DIAGNOSTICS_ORIGINALTRADEDIAGNOSTICS_MQH
