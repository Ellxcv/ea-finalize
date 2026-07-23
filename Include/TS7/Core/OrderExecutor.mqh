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
   double sl  = 0.0;
   double tp  = 0.0;
   double lot = CalculateMainStrategyLot();
   string orderComment = BuildCCIMainOrderComment(InpBuyComment, cciSignalType);

   if(InpStopLossPoints > 0)
      sl = NormalizeDouble(ask - InpStopLossPoints * _Point, _Digits);
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
   double sl  = 0.0;
   double tp  = 0.0;
   double lot = CalculateMainStrategyLot();
   string orderComment = BuildCCIMainOrderComment(InpSellComment, cciSignalType);

   if(InpStopLossPoints > 0)
      sl = NormalizeDouble(bid + InpStopLossPoints * _Point, _Digits);
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

   Print("INFO: SELL opened. Price=", bid, " SL=", sl, " TP=", tp,
         " Lot=", lot,
         " CCIType=", CCISignalTypeToString(cciSignalType),
         " Comment='", orderComment, "'",
         " Mode=", (InpMainLotMode == MAIN_LOT_DYNAMIC ? "DYNAMIC" : "FIXED"));
   return true;
  }

#endif // TS7_CORE_ORDEREXECUTOR_MQH
