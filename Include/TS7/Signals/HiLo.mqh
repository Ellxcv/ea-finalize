//+------------------------------------------------------------------+
//|                                                   TS7/HiLo.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_HILO_MQH
#define TS7_HILO_MQH

//+------------------------------------------------------------------+
int GetHiLoTrend()
  {
   double trendBuf[];
   ArraySetAsSeries(trendBuf, true);

   // Copy 1 bar dari shift 1 (bar terakhir yang closed)
   if(CopyBuffer(g_handles.hilo, 8, 1, 1, trendBuf) <= 0)
     {
      Print("WARNING: Gagal copy buffer HiLo trend. Err=", GetLastError());
      return 0;
     }

   if(trendBuf[0] == 1.0)
      return 1;   // HiLo Up
   if(trendBuf[0] == -1.0)
      return -1;  // HiLo Down

   return 0;
  }

#endif // TS7_HILO_MQH
