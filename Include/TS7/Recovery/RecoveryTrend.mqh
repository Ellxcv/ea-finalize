//+------------------------------------------------------------------+
//|                              TS7/Recovery/RecoveryTrend.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_RECOVERY_RECOVERYTREND_MQH
#define TS7_RECOVERY_RECOVERYTREND_MQH

//+------------------------------------------------------------------+
void HandleTrendRecoveryMode(const double bid, const double ask)
  {
   if(InpEnableAdxFilter && g_handles.adx != INVALID_HANDLE)
     {
      int adxStatePre = GetAdxFilterState();
      int trendDirPre = GetRecoveryTrendDirection();
      if((trendDirPre == 1 && adxStatePre != 1 && adxStatePre != 2) ||
         (trendDirPre == -1 && adxStatePre != -1 && adxStatePre != 2))
         return;
     }

   //--- Tentukan arah recovery dari SuperTrend + PSAR
   int trendDir = GetRecoveryTrendDirection();
   if(trendDir == 0)
      return;  // Trend belum sinkron → tunggu

   //--- Cek apakah zone sudah pernah ditembus
   if(!g_recoveryZoneBreached)
     {
      if(trendDir == 1 && bid >= g_recoveryZoneHigh)
         g_recoveryZoneBreached = true;
      else if(trendDir == -1 && bid <= g_recoveryZoneLow)
         g_recoveryZoneBreached = true;
      else
         return;  // Zone belum ditembus → tunggu
     }

   //--- Entry hanya saat candle close (new bar)
   //    Cek apakah ini bar baru (tanpa mengubah g_lastBarTime)
   static datetime lastRecoveryBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == 0 || currentBarTime == lastRecoveryBarTime)
      return;  // Belum ada candle close baru
   lastRecoveryBarTime = currentBarTime;

   //--- Validasi trend masih sinkron pada candle close
   trendDir = GetRecoveryTrendDirection();
   if(trendDir == 0)
      return;  // Trend berubah → tunggu

   //--- Risk control: check max steps
   if(InpMaxRecoverySteps > 0 && g_recoveryStepCount >= InpMaxRecoverySteps)
      return;  // Max steps reached, no new entries

   //--- Risk control: check max recovery positions
   if(InpMaxRecoveryPositions > 0 && CountRecoveryPositions() >= InpMaxRecoveryPositions)
      return;  // Max positions reached

   double nextLot = RoundLotToStep(g_recoveryNextLot);
   if(nextLot <= 0.0)
      nextLot = InpLotSize;

   //--- Risk control: clamp lot to max
   if(InpMaxRecoveryLot > 0.0 && nextLot > InpMaxRecoveryLot)
     {
      nextLot = RoundLotToStep(InpMaxRecoveryLot);
      PrintDebug(StringFormat("Recovery lot capped to max: %.2f", nextLot));
     }

   //--- Trend UP → hanya BUY recovery
   if(trendDir == 1)
     {
      if(!g_recoveryBuyDone || g_recoveryLastDirection < 0)
        {
         string recComment = InpBuyComment + " " + RECOVERY_TAG;
         if(g_trade.Buy(nextLot, _Symbol, ask, 0.0, 0.0, recComment))
           {
            g_recoveryLastDirection = 1;
            g_recoveryBuyDone      = true;
            g_recoverySellDone     = false;
            g_recoveryStepCount++;
            g_recoveryZoneBreached = false; // Reset: harus break zone lagi untuk step berikutnya
            g_recoveryNextLot      = g_recoveryNextLot * MathMax(1.0, InpRecoveryLotMultiplier);
            Print("INFO: [TREND] Recovery BUY opened. Lot=", nextLot,
                  " Step=", g_recoveryStepCount, "/", InpMaxRecoverySteps,
                  " NextRaw=", g_recoveryNextLot);
           }
        }
     }
   //--- Trend DOWN → hanya SELL recovery
   else if(trendDir == -1)
     {
      if(!g_recoverySellDone || g_recoveryLastDirection > 0)
        {
         string recComment = InpSellComment + " " + RECOVERY_TAG;
         if(g_trade.Sell(nextLot, _Symbol, bid, 0.0, 0.0, recComment))
           {
            g_recoveryLastDirection = -1;
            g_recoverySellDone     = true;
            g_recoveryBuyDone      = false;
            g_recoveryStepCount++;
            g_recoveryZoneBreached = false; // Reset
            g_recoveryNextLot      = g_recoveryNextLot * MathMax(1.0, InpRecoveryLotMultiplier);
            Print("INFO: [TREND] Recovery SELL opened. Lot=", nextLot,
                  " Step=", g_recoveryStepCount, "/", InpMaxRecoverySteps,
                  " NextRaw=", g_recoveryNextLot);
           }
        }
     }
  }

#endif // TS7_RECOVERY_RECOVERYTREND_MQH
