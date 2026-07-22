//+------------------------------------------------------------------+
//|                                                   TS7/ADX.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_ADX_MQH
#define TS7_ADX_MQH

//+------------------------------------------------------------------+
int GetAdxFilterState()
  {
   if(g_handles.adx == INVALID_HANDLE)
      return 0;

   double adxBuf[];
   double plusDiBuf[];
   double minusDiBuf[];
   ArraySetAsSeries(adxBuf, true);
   ArraySetAsSeries(plusDiBuf, true);
   ArraySetAsSeries(minusDiBuf, true);

   int adxCount = (InpAdxEnableSmoothing ? MathMax(1, InpAdxSmoothing) : 1);
   if(CopyBuffer(g_handles.adx, 0, 1, adxCount, adxBuf) <= 0 ||
      CopyBuffer(g_handles.adx, 1, 1, 2, plusDiBuf) <= 0 ||
      CopyBuffer(g_handles.adx, 2, 1, 2, minusDiBuf) <= 0)
     {
      Print("WARNING: Gagal copy buffer ADX built-in. Err=", GetLastError());
      return 0;
     }

   double adxSmoothed = 0.0;
   int smoothN = MathMin(adxCount, ArraySize(adxBuf));
   if(smoothN <= 0)
      return 0;
   if(InpAdxEnableSmoothing)
     {
      for(int i = 0; i < smoothN; i++)
         adxSmoothed += adxBuf[i];
      adxSmoothed /= smoothN;
     }
   else
      adxSmoothed = adxBuf[0];
   bool adxStrong = (adxSmoothed > InpAdxThreshold);

   ENUM_TIMEFRAMES adxTf = (InpAdxTimeframe == PERIOD_CURRENT)
                           ? (ENUM_TIMEFRAMES)_Period
                           : InpAdxTimeframe;
   datetime lastClosedTfBarTime = iTime(_Symbol, adxTf, 1);
   if(lastClosedTfBarTime > 0 && lastClosedTfBarTime != g_adxBiasLastBarTime)
     {
      bool crossUp = (plusDiBuf[0] > minusDiBuf[0] && plusDiBuf[1] <= minusDiBuf[1]);
      bool crossDown = (plusDiBuf[0] < minusDiBuf[0] && plusDiBuf[1] >= minusDiBuf[1]);

      if(crossUp)
         g_adxDirectionalBias = 1;
      else if(crossDown)
         g_adxDirectionalBias = -1;
      else if(g_adxDirectionalBias == 0)
        {
         // Bootstrap bias on first run when no cross has been seen yet.
         if(plusDiBuf[0] > minusDiBuf[0])
            g_adxDirectionalBias = 1;
         else if(plusDiBuf[0] < minusDiBuf[0])
            g_adxDirectionalBias = -1;
        }

      g_adxBiasLastBarTime = lastClosedTfBarTime;
     }

   if(!adxStrong)
      return 0;
   if(InpAdxFilterMode == ADX_FILTER_ADX_ONLY)
      return 2;
   if(g_adxDirectionalBias > 0)
      return 1;
   if(g_adxDirectionalBias < 0)
      return -1;

   return 0;
  }

#endif // TS7_ADX_MQH
