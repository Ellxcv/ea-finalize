//+------------------------------------------------------------------+
//|                                                   TS7/PSAR.mqh   |
//+------------------------------------------------------------------+
#ifndef TS7_PSAR_MQH
#define TS7_PSAR_MQH

//+------------------------------------------------------------------+
int GetPSARStateByHandle(const int handle,
                         const string symbol,
                         const ENUM_TIMEFRAMES timeframe)
  {
   if(handle == INVALID_HANDLE)
      return 0;

   ENUM_TIMEFRAMES resolvedTimeframe = (timeframe == PERIOD_CURRENT)
                                      ? (ENUM_TIMEFRAMES)_Period
                                      : timeframe;

   double psarBuffer[];
   double closeBuffer[];
   ArraySetAsSeries(psarBuffer, true);
   ArraySetAsSeries(closeBuffer, true);

   ResetLastError();
   int copiedPsar = CopyBuffer(handle, 0, 1, 1, psarBuffer);
   int copiedClose = CopyClose(symbol, resolvedTimeframe, 1, 1, closeBuffer);
   if(copiedPsar != 1 || copiedClose != 1)
     {
      Print("WARNING: Gagal membaca nilai PSAR/close. Symbol=", symbol,
            " TF=", EnumToString(resolvedTimeframe), " Err=", GetLastError());
      return 0;
     }

   double psarValue = psarBuffer[0];
   double closeValue = closeBuffer[0];
   if(psarValue == EMPTY_VALUE ||
      !MathIsValidNumber(psarValue) ||
      !MathIsValidNumber(closeValue))
      return 0;

   if(closeValue > psarValue)
      return 1;
   if(closeValue < psarValue)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
// Compatibility wrapper untuk PSAR pada symbol/timeframe chart.
int GetPSARStateByHandle(const int handle)
  {
   return GetPSARStateByHandle(handle, _Symbol, (ENUM_TIMEFRAMES)_Period);
  }

//+------------------------------------------------------------------+
int GetPSARState()
  {
   return GetPSARStateByHandle(g_handles.psar);
  }

//+------------------------------------------------------------------+
int GetMainPSARState()
  {
   if(g_handles.mainPSAR != INVALID_HANDLE)
      return GetPSARStateByHandle(g_handles.mainPSAR);
   return GetPSARState();
  }

//+------------------------------------------------------------------+
int GetMainPSARState(const string symbol, const ENUM_TIMEFRAMES timeframe)
  {
   if(g_handles.mainPSAR != INVALID_HANDLE)
      return GetPSARStateByHandle(g_handles.mainPSAR, symbol, timeframe);
   return GetPSARStateByHandle(g_handles.psar, symbol, timeframe);
  }

#endif // TS7_PSAR_MQH
