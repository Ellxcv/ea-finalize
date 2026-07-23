//+------------------------------------------------------------------+
//|                                  TS7/Core/MainStopLoss.mqh       |
//|             Initial stop calculation for original strategy      |
//+------------------------------------------------------------------+
#ifndef TS7_CORE_MAIN_STOP_LOSS_MQH
#define TS7_CORE_MAIN_STOP_LOSS_MQH

struct SMainStopLossContext
  {
   ENUM_MAIN_STOP_LOSS_MODE mode;
   ENUM_TIMEFRAMES          timeframe;
   double                   stopPrice;
   double                   distancePoints;
   double                   atrPrice;
   double                   atrDistancePrice;
   datetime                 anchorTime;
   double                   anchorPrice;
  };

int g_mainStopLossOpened = 0;
int g_mainStopLossCalculationBlocks = 0;
int g_mainStopLossBrokerBlocks = 0;

//+------------------------------------------------------------------+
void ResetMainStopLossContext(SMainStopLossContext &context)
  {
   context.mode = InpMainStopLossMode;
   context.timeframe = (InpMainStopAtrTimeframe == PERIOD_CURRENT
                        ? (ENUM_TIMEFRAMES)_Period
                        : InpMainStopAtrTimeframe);
   context.stopPrice = 0.0;
   context.distancePoints = 0.0;
   context.atrPrice = 0.0;
   context.atrDistancePrice = 0.0;
   context.anchorTime = 0;
   context.anchorPrice = 0.0;
  }

//+------------------------------------------------------------------+
string MainStopLossModeText(const ENUM_MAIN_STOP_LOSS_MODE mode)
  {
   if(mode == MAIN_SL_ATR_CANDLE)
      return "ATR_CANDLE";
   return "FIXED_POINTS";
  }

//+------------------------------------------------------------------+
void ResetMainStopLossDiagnostics()
  {
   g_mainStopLossOpened = 0;
   g_mainStopLossCalculationBlocks = 0;
   g_mainStopLossBrokerBlocks = 0;
  }

//+------------------------------------------------------------------+
bool ValidateMainStopLossInputs()
  {
   if(InpMainStopLossMode == MAIN_SL_FIXED_POINTS)
     {
      if(InpStopLossPoints < 0)
        {
         Print("ERROR: InpStopLossPoints must be >= 0.");
         return false;
        }
      return true;
     }

   if(InpMainStopLossMode != MAIN_SL_ATR_CANDLE)
     {
      Print("ERROR: Unsupported InpMainStopLossMode.");
      return false;
     }
   if(InpMainStopAtrPeriod <= 0)
     {
      Print("ERROR: InpMainStopAtrPeriod must be > 0.");
      return false;
     }
   if(InpMainStopAtrMultiplier <= 0.0)
     {
      Print("ERROR: InpMainStopAtrMultiplier must be > 0.");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
double MainStopLossTrueRange(const MqlRates &current,
                             const MqlRates &previous)
  {
   return MathMax(current.high - current.low,
                  MathMax(MathAbs(current.high - previous.close),
                          MathAbs(current.low - previous.close)));
  }

//+------------------------------------------------------------------+
bool ReadMainStopLossAtrRma(const ENUM_TIMEFRAMES timeframe,
                            double &atrPrice,
                            MqlRates &anchorCandle,
                            string &failureReason)
  {
   atrPrice = 0.0;
   failureReason = "";

   int requested = MathMax(300, InpMainStopAtrPeriod * 20 + 10);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   ResetLastError();
   int copied = CopyRates(_Symbol, timeframe, 0, requested, rates);
   if(copied < InpMainStopAtrPeriod + 2)
     {
      failureReason = StringFormat("ATR_HISTORY_NOT_READY copied=%d required=%d error=%d",
                                   copied, InpMainStopAtrPeriod + 2, GetLastError());
      return false;
     }

   int oldestShift = copied - 2;
   int trueRangeCount = oldestShift;
   if(trueRangeCount < InpMainStopAtrPeriod)
     {
      failureReason = "ATR_TRUE_RANGE_NOT_READY";
      return false;
     }

   double smoothed = 0.0;
   int chronologicalIndex = 0;
   for(int shift = oldestShift; shift >= 1; --shift)
     {
      double trueRange = MainStopLossTrueRange(rates[shift], rates[shift + 1]);
      if(!MathIsValidNumber(trueRange) || trueRange < 0.0)
        {
         failureReason = "ATR_TRUE_RANGE_INVALID";
         return false;
        }

      if(chronologicalIndex < InpMainStopAtrPeriod)
        {
         smoothed += trueRange;
         if(chronologicalIndex == InpMainStopAtrPeriod - 1)
            smoothed /= InpMainStopAtrPeriod;
        }
      else
        {
         double alpha = 1.0 / InpMainStopAtrPeriod;
         smoothed = alpha * trueRange + (1.0 - alpha) * smoothed;
        }
      chronologicalIndex++;
     }

   if(!MathIsValidNumber(smoothed) || smoothed <= 0.0)
     {
      failureReason = "ATR_RMA_INVALID";
      return false;
     }

   atrPrice = smoothed;
   anchorCandle = rates[1];
   return true;
  }

//+------------------------------------------------------------------+
bool ValidateAtrStopAgainstMarket(const int direction,
                                  const double bid,
                                  const double ask,
                                  const double stopPrice,
                                  string &failureReason)
  {
   failureReason = "";
   if(_Point <= 0.0 || bid <= 0.0 || ask <= 0.0 || stopPrice <= 0.0)
     {
      failureReason = "INVALID_MARKET_PRICE";
      return false;
     }

   long stopsLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minimumDistance = MathMax(0.0, (double)stopsLevelPoints * _Point);
   double availableDistance = (direction > 0 ? bid - stopPrice : stopPrice - ask);

   if(availableDistance <= 0.0)
     {
      failureReason = "STOP_WRONG_SIDE_OF_MARKET";
      return false;
     }
   if(availableDistance + (_Point * 0.1) < minimumDistance)
     {
      failureReason = StringFormat("BROKER_STOPS_LEVEL distance=%.1f minimum=%d",
                                   availableDistance / _Point, (int)stopsLevelPoints);
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
bool CalculateMainStopLoss(const int direction,
                           const double entryPrice,
                           const double bid,
                           const double ask,
                           SMainStopLossContext &context,
                           string &failureReason)
  {
   ResetMainStopLossContext(context);
   failureReason = "";

   if(InpMainStopLossMode == MAIN_SL_FIXED_POINTS)
     {
      if(InpStopLossPoints <= 0)
         return true;

      context.stopPrice = NormalizeDouble(
         entryPrice - direction * InpStopLossPoints * _Point, _Digits);
      context.distancePoints =
         (_Point > 0.0 ? MathAbs(entryPrice - context.stopPrice) / _Point : 0.0);
      return true;
     }

   MqlRates anchorCandle;
   if(!ReadMainStopLossAtrRma(context.timeframe, context.atrPrice,
                              anchorCandle, failureReason))
     {
      g_mainStopLossCalculationBlocks++;
      return false;
     }

   context.atrDistancePrice = context.atrPrice * InpMainStopAtrMultiplier;
   context.anchorTime = anchorCandle.time;
   context.anchorPrice = (direction > 0 ? anchorCandle.low : anchorCandle.high);
   context.stopPrice = NormalizeDouble(
      context.anchorPrice - direction * context.atrDistancePrice, _Digits);
   context.distancePoints =
      (_Point > 0.0 ? MathAbs(entryPrice - context.stopPrice) / _Point : 0.0);

   if(!MathIsValidNumber(context.stopPrice) ||
      !MathIsValidNumber(context.distancePoints) ||
      context.distancePoints <= 0.0)
     {
      failureReason = "CALCULATED_STOP_INVALID";
      g_mainStopLossCalculationBlocks++;
      return false;
     }

   if(!ValidateAtrStopAgainstMarket(direction, bid, ask,
                                    context.stopPrice, failureReason))
     {
      g_mainStopLossBrokerBlocks++;
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
void PrintMainStopLossExecution(const int direction,
                                const datetime signalTime,
                                const double entryPrice,
                                const double lot,
                                const SMainStopLossContext &context,
                                const ulong orderTicket,
                                const ulong dealTicket)
  {
   g_mainStopLossOpened++;
   double estimatedRiskMoney = 0.0;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double distancePrice = context.distancePoints * _Point;
   if(tickSize > 0.0 && tickValue > 0.0 && distancePrice > 0.0)
      estimatedRiskMoney = (distancePrice / tickSize) * tickValue * lot;

   string anchorTimeText =
      (context.anchorTime > 0
       ? TimeToString(context.anchorTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS)
       : "NA");

   Print("TS7_MAIN_SL",
         "|Side=", (direction > 0 ? "BUY" : "SELL"),
         "|SignalTime=", TimeToString(signalTime,
                                      TIME_DATE | TIME_MINUTES | TIME_SECONDS),
         "|Mode=", MainStopLossModeText(context.mode),
         "|Timeframe=", EnumToString(context.timeframe),
         "|EntryPrice=", DoubleToString(entryPrice, _Digits),
         "|StopPrice=", DoubleToString(context.stopPrice, _Digits),
         "|StopDistancePoints=", DoubleToString(context.distancePoints, 1),
         "|ATRPrice=", DoubleToString(context.atrPrice, _Digits),
         "|ATRPoints=", DoubleToString(
            (_Point > 0.0 ? context.atrPrice / _Point : 0.0), 1),
         "|ATRMultiplier=", DoubleToString(
            (context.mode == MAIN_SL_ATR_CANDLE ? InpMainStopAtrMultiplier : 0.0), 3),
         "|AnchorTime=", anchorTimeText,
         "|AnchorPrice=", DoubleToString(context.anchorPrice, _Digits),
         "|Lot=", DoubleToString(lot, 2),
         "|EstimatedRiskMoney=", DoubleToString(estimatedRiskMoney, 2),
         "|Order=", orderTicket,
         "|Deal=", dealTicket);
  }

//+------------------------------------------------------------------+
void PrintMainStopLossSummary()
  {
   Print("TS7_MAIN_SL_SUMMARY",
         "|Mode=", MainStopLossModeText(InpMainStopLossMode),
         "|Opened=", g_mainStopLossOpened,
         "|CalculationBlocks=", g_mainStopLossCalculationBlocks,
         "|BrokerBlocks=", g_mainStopLossBrokerBlocks);
  }

#endif // TS7_CORE_MAIN_STOP_LOSS_MQH
