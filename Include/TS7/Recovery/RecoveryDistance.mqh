//+------------------------------------------------------------------+
//|                              TS7/Recovery/RecoveryDistance.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_RECOVERY_RECOVERYDISTANCE_MQH
#define TS7_RECOVERY_RECOVERYDISTANCE_MQH

//+------------------------------------------------------------------+
int GetDistanceTrendDirection()
  {
   int st = GetSuperTrendDirection();
   if(g_handles.recoveryDistanceST != INVALID_HANDLE)
      st = GetSuperTrendDirectionByHandle(g_handles.recoveryDistanceST);

   int psar = GetPSARState();
   if(g_handles.recoveryDistancePSAR != INVALID_HANDLE)
      psar = GetPSARStateByHandle(g_handles.recoveryDistancePSAR);

   if(st == 1 && psar == 1)
      return 1;
   if(st == -1 && psar == -1)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
int GetDistanceSignalDirection()
  {
   if(InpRecoveryDistanceSignalSource == DIST_SIGNAL_ST_PSAR)
      return GetDistanceTrendDirection();

   if(InpRecoveryDistanceSignalSource == DIST_SIGNAL_ALGOZONE)
     {
      if(g_handles.algoZone == INVALID_HANDLE)
         return GetDistanceTrendDirection(); // fallback

      double signalDirBuf[];
      ArraySetAsSeries(signalDirBuf, true);
      // AlgoZone (latest): buffer 2 = signal direction (1=blue, -1=purple, 0=neutral)
      if(CopyBuffer(g_handles.algoZone, 2, 1, 1, signalDirBuf) <= 0)
        {
         Print("WARNING: Gagal copy buffer AlgoZone signal dir. Err=", GetLastError());
         return 0;
        }

      if(signalDirBuf[0] > 0.0)
         return 1;   // Blue = bullish
      if(signalDirBuf[0] < 0.0)
         return -1;  // Purple = bearish

      return 0;      // Neutral/unknown
     }

   if(InpRecoveryDistanceSignalSource == DIST_SIGNAL_BASIC_EMA)
     {
      if(g_handles.distEmaFast == INVALID_HANDLE || g_handles.distEmaSlow == INVALID_HANDLE)
         return GetDistanceTrendDirection(); // fallback

      double emaFastBuf[];
      double emaSlowBuf[];
      ArraySetAsSeries(emaFastBuf, true);
      ArraySetAsSeries(emaSlowBuf, true);

      if(CopyBuffer(g_handles.distEmaFast, 0, 1, 1, emaFastBuf) <= 0 ||
         CopyBuffer(g_handles.distEmaSlow, 0, 1, 1, emaSlowBuf) <= 0)
        {
         Print("WARNING: Gagal copy buffer Basic EMA. Err=", GetLastError());
         return 0;
        }

      if(emaFastBuf[0] > emaSlowBuf[0])
         return 1;   // Fast > Slow = buy only
      if(emaFastBuf[0] < emaSlowBuf[0])
         return -1;  // Fast < Slow = sell only

      return 0;
     }

   return 0;
  }

//+------------------------------------------------------------------+
void ExecuteDistanceRecoveryOrder(const int direction, const double lot, const double bid, const double ask)
  {
   double lotMultiplier = MathMax(1.0, InpRecoveryLotMultiplier);

   if(direction > 0)
     {
      string recComment = InpBuyComment + " " + RECOVERY_TAG;
      if(g_trade.Buy(lot, _Symbol, ask, 0.0, 0.0, recComment))
        {
         g_recoveryLastDirection = 1;
         g_recoveryLastOpenPrice = ask;
         g_recoveryLastOpenDirection = 1;
         g_recoveryBuyDone      = true;
         g_recoverySellDone     = false;
         g_recoveryStepCount++;
         g_recoveryNextLot      = g_recoveryNextLot * lotMultiplier;
         Print("INFO: [DISTANCE] Recovery BUY opened. Price=",
               DoubleToString(ask, _Digits),
               " Lot=", lot, " Step=", g_recoveryStepCount);
        }
     }
   else if(direction < 0)
     {
      string recComment = InpSellComment + " " + RECOVERY_TAG;
      if(g_trade.Sell(lot, _Symbol, bid, 0.0, 0.0, recComment))
        {
         g_recoveryLastDirection = -1;
         g_recoveryLastOpenPrice = bid;
         g_recoveryLastOpenDirection = -1;
         g_recoverySellDone     = true;
         g_recoveryBuyDone      = false;
         g_recoveryStepCount++;
         g_recoveryNextLot      = g_recoveryNextLot * lotMultiplier;
         Print("INFO: [DISTANCE] Recovery SELL opened. Price=",
               DoubleToString(bid, _Digits),
               " Lot=", lot, " Step=", g_recoveryStepCount);
        }
     }
  }

//+------------------------------------------------------------------+
void HandleDistanceRecoveryMode(const double bid, const double ask)
  {
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == 0 || currentBarTime == g_recoveryDistLastBarTime)
      return;
   g_recoveryDistLastBarTime = currentBarTime;

   int trendDir = GetDistanceSignalDirection();
   if(trendDir == 0)
      return;

   if(InpMaxRecoverySteps > 0 && g_recoveryStepCount >= InpMaxRecoverySteps)
      return;
   if(InpMaxRecoveryPositions > 0 && CountRecoveryPositions() >= InpMaxRecoveryPositions)
      return;

   double nextLot = RoundLotToStep(g_recoveryNextLot);
   if(nextLot <= 0.0)
      nextLot = InpLotSize;
   if(InpMaxRecoveryLot > 0.0 && nextLot > InpMaxRecoveryLot)
      nextLot = RoundLotToStep(InpMaxRecoveryLot);

   double distancePrice = MathMax(1, InpRecoveryDistancePoints) * _Point;

   // First entry: execute directly in current synced trend direction.
   if(g_recoveryStepCount == 0)
     {
      ExecuteDistanceRecoveryOrder(trendDir, nextLot, bid, ask);
      return;
     }

   double lastPrice = g_recoveryLastOpenPrice;
   if(lastPrice <= 0.0)
      return;
   if(g_recoveryLastOpenDirection == 0)
      return;

   if(trendDir > 0)
     {
      if(ask < (lastPrice + distancePrice))
         return;
      ExecuteDistanceRecoveryOrder(1, nextLot, bid, ask);
     }
   else if(trendDir < 0)
     {
      if(bid > (lastPrice - distancePrice))
         return;
      ExecuteDistanceRecoveryOrder(-1, nextLot, bid, ask);
     }
  }

#endif // TS7_RECOVERY_RECOVERYDISTANCE_MQH
