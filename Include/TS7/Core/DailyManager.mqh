//+------------------------------------------------------------------+
//|                                      TS7/Core/DailyManager.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_CORE_DAILYMANAGER_MQH
#define TS7_CORE_DAILYMANAGER_MQH

//+------------------------------------------------------------------+
void RecordStartOfDayEquity()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

   if(today != g_lastEquityResetDay)
     {
      g_startOfDayEquity   = g_accountInfo.Equity();
      g_lastEquityResetDay = today;
      g_dailyTargetReached = false;
      g_dailyDrawdownReached = false;
      Print("INFO: New day detected. Start equity=", g_startOfDayEquity);
     }
  }

//+------------------------------------------------------------------+
bool IsDailyTargetReached()
  {
   if(g_startOfDayEquity <= 0.0)
      return false;

   double currentEquity = g_accountInfo.Equity();

   if(InpDailyTargetMode == DAILY_TARGET_EQUITY)
     {
      // Target berdasarkan nominal
      return (currentEquity >= g_startOfDayEquity + InpDailyTargetValue);
     }
   else
     {
      // Target berdasarkan persentase
      double targetEquity = g_startOfDayEquity * (1.0 + InpDailyTargetValue / 100.0);
      return (currentEquity >= targetEquity);
     }
  }

//+------------------------------------------------------------------+
bool IsDailyDrawdownReached(double &dailyPL, double &ddLimitMoney)
  {
   dailyPL = 0.0;
   ddLimitMoney = 0.0;

   if(g_startOfDayEquity <= 0.0 || InpDailyDrawdownValue <= 0.0)
      return false;

   double currentEquity = g_accountInfo.Equity();
   dailyPL = currentEquity - g_startOfDayEquity;

   if(InpDailyDrawdownMode == DAILY_DD_PERCENTAGE)
      ddLimitMoney = g_startOfDayEquity * (InpDailyDrawdownValue / 100.0);
   else
      ddLimitMoney = InpDailyDrawdownValue;

   if(ddLimitMoney <= 0.0)
      return false;

   return ((-dailyPL) >= ddLimitMoney);
  }

#endif // TS7_CORE_DAILYMANAGER_MQH
