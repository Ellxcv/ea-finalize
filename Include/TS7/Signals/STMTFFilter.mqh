//+------------------------------------------------------------------+
//|                                                   TS7/STMTFFilter.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_STMTFFILTER_MQH
#define TS7_STMTFFILTER_MQH

//+------------------------------------------------------------------+
int GetSTFilterDirection()
  {
   if(!InpEnableSTMTF || g_handles.stFilter == INVALID_HANDLE)
      return 0;  // Filter off → does not block any entry

   double trendBuf[];
   ArraySetAsSeries(trendBuf, true);

   // Shift 1 = last closed bar on the filter TF
   if(CopyBuffer(g_handles.stFilter, 4, 1, 1, trendBuf) <= 0)
     {
      Print("WARNING: Gagal copy buffer SuperTrend MTF. Err=", GetLastError());
      return 0;
     }

   if(trendBuf[0] == 1.0)
      return 1;   // Up Trend
   if(trendBuf[0] == -1.0)
      return -1;  // Down Trend

   return 0;
  }

#endif // TS7_STMTFFILTER_MQH
