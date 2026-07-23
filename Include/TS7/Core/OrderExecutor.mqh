//+------------------------------------------------------------------+
//|                                      TS7/Core/OrderExecutor.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_CORE_ORDEREXECUTOR_MQH
#define TS7_CORE_ORDEREXECUTOR_MQH

//+------------------------------------------------------------------+
bool ExecuteBuy(const int cciSignalType, const datetime signalTime)
  {
   g_symbolInfo.RefreshRates();
   double ask = g_symbolInfo.Ask();
   double bid = g_symbolInfo.Bid();
   double sl  = 0.0;
   double tp  = 0.0;
   SMainStopLossContext stopContext;
   string stopFailureReason = "";
   if(!CalculateMainStopLoss(1, ask, bid, ask, stopContext, stopFailureReason))
     {
      Print("TS7_MAIN_SL_BLOCK|Side=BUY|SignalTime=",
            TimeToString(signalTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
            "|Mode=", MainStopLossModeText(InpMainStopLossMode),
            "|Reason=", stopFailureReason);
      return false;
     }
   sl = stopContext.stopPrice;
   double lot = CalculateMainStrategyLot(stopContext.distancePoints * _Point);
   string orderComment = BuildCCIMainOrderComment(InpBuyComment, cciSignalType);

   if(InpTakeProfitPoints > 0)
      tp = NormalizeDouble(ask + InpTakeProfitPoints * _Point, _Digits);

   PrepareOriginalTradeDiagnostic(1, cciSignalType, signalTime);
   if(!g_trade.Buy(lot, _Symbol, ask, sl, tp, orderComment))
     {
      CancelOriginalTradeDiagnostic();
      Print("ERROR: Buy failed. Error=", g_trade.ResultRetcode(),
            " Desc=", g_trade.ResultRetcodeDescription());
      return false;
     }

   PrintMainStopLossExecution(1, signalTime, ask, lot, stopContext,
                              g_trade.ResultOrder(), g_trade.ResultDeal());
   Print("INFO: BUY opened. Price=", ask, " SL=", sl, " TP=", tp,
         " Lot=", lot,
         " CCIType=", CCISignalTypeToString(cciSignalType),
         " Comment='", orderComment, "'",
         " Mode=", (InpMainLotMode == MAIN_LOT_DYNAMIC ? "DYNAMIC" : "FIXED"));
   return true;
  }

//+------------------------------------------------------------------+
bool ExecuteSell(const int cciSignalType, const datetime signalTime)
  {
   g_symbolInfo.RefreshRates();
   double bid = g_symbolInfo.Bid();
   double ask = g_symbolInfo.Ask();
   double sl  = 0.0;
   double tp  = 0.0;
   SMainStopLossContext stopContext;
   string stopFailureReason = "";
   if(!CalculateMainStopLoss(-1, bid, bid, ask, stopContext, stopFailureReason))
     {
      Print("TS7_MAIN_SL_BLOCK|Side=SELL|SignalTime=",
            TimeToString(signalTime, TIME_DATE | TIME_MINUTES | TIME_SECONDS),
            "|Mode=", MainStopLossModeText(InpMainStopLossMode),
            "|Reason=", stopFailureReason);
      return false;
     }
   sl = stopContext.stopPrice;
   double lot = CalculateMainStrategyLot(stopContext.distancePoints * _Point);
   string orderComment = BuildCCIMainOrderComment(InpSellComment, cciSignalType);

   if(InpTakeProfitPoints > 0)
      tp = NormalizeDouble(bid - InpTakeProfitPoints * _Point, _Digits);

   PrepareOriginalTradeDiagnostic(-1, cciSignalType, signalTime);
   if(!g_trade.Sell(lot, _Symbol, bid, sl, tp, orderComment))
     {
      CancelOriginalTradeDiagnostic();
      Print("ERROR: Sell failed. Error=", g_trade.ResultRetcode(),
            " Desc=", g_trade.ResultRetcodeDescription());
      return false;
     }

   PrintMainStopLossExecution(-1, signalTime, bid, lot, stopContext,
                              g_trade.ResultOrder(), g_trade.ResultDeal());
   Print("INFO: SELL opened. Price=", bid, " SL=", sl, " TP=", tp,
         " Lot=", lot,
         " CCIType=", CCISignalTypeToString(cciSignalType),
         " Comment='", orderComment, "'",
         " Mode=", (InpMainLotMode == MAIN_LOT_DYNAMIC ? "DYNAMIC" : "FIXED"));
   return true;
  }

#endif // TS7_CORE_ORDEREXECUTOR_MQH
