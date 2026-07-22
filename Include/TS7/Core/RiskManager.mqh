//+------------------------------------------------------------------+
//|                                      TS7/Core/RiskManager.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_CORE_RISKMANAGER_MQH
#define TS7_CORE_RISKMANAGER_MQH

//+------------------------------------------------------------------+
double CalculateMainStrategyLot()
  {
   double fallbackLot = RoundLotToStep(InpLotSize);
   if(InpMainLotMode == MAIN_LOT_FIXED)
      return fallbackLot;

   // Dynamic mode needs a valid SL distance to convert risk-money to lot.
   if(InpStopLossPoints <= 0)
      return fallbackLot;

   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * InpMainRiskPercent / 100.0;
   double slDistancePrice = InpStopLossPoints * _Point;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(riskMoney <= 0.0 || slDistancePrice <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return fallbackLot;

   double moneyPerLotAtSL = (slDistancePrice / tickSize) * tickValue;
   if(moneyPerLotAtSL <= 0.0)
      return fallbackLot;

   double rawLot = riskMoney / moneyPerLotAtSL;
   double lot = RoundLotToStep(rawLot);
   if(lot <= 0.0)
      return fallbackLot;
   return lot;
  }

#endif // TS7_CORE_RISKMANAGER_MQH
