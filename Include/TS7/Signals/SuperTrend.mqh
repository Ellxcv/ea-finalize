//+------------------------------------------------------------------+
//|                                                   TS7/SuperTrend.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_SUPERTREND_MQH
#define TS7_SUPERTREND_MQH

//+------------------------------------------------------------------+
int GetSuperTrendDirectionByHandle(const int handle)
  {
   if(handle == INVALID_HANDLE)
      return 0;

   double trendBuf[];
   ArraySetAsSeries(trendBuf, true);

   // Shift 1 = last closed bar
   if(CopyBuffer(handle, 4, 1, 1, trendBuf) <= 0)
      return 0;

   if(trendBuf[0] == 1.0)
      return 1;
   if(trendBuf[0] == -1.0)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
int GetSuperTrendDirection()
  {
   int dir = GetSuperTrendDirectionByHandle(g_handles.superTrend);
   if(dir == 0)
      Print("WARNING: Gagal copy buffer SuperTrend. Err=", GetLastError());
   return dir;
  }

//+------------------------------------------------------------------+
int GetMainSuperTrendDirection()
  {
   if(g_handles.mainSuperTrend != INVALID_HANDLE)
      return GetSuperTrendDirectionByHandle(g_handles.mainSuperTrend);
   return GetSuperTrendDirection();
  }

#endif // TS7_SUPERTREND_MQH
