//+------------------------------------------------------------------+
//|                              TS7/Recovery/RecoveryClassic.mqh    |
//|                              Classic Zone recovery handlers      |
//+------------------------------------------------------------------+
#ifndef TS7_RECOVERY_CLASSIC_MQH
#define TS7_RECOVERY_CLASSIC_MQH

//+------------------------------------------------------------------+
void StartClassicRecoveryPending(const double lossAmount, const double dealVolume)
  {
   g_recoveryPendingStart = true;
   g_recoveryPendingLossAmount = lossAmount;
   g_recoveryPendingDealVolume = dealVolume;
   g_recoveryClassicPendingLastBarTime = 0;

   // Reset runtime state without triggering cooldown
   g_recoveryActive       = false;
   g_recoveryZoneHigh     = 0.0;
   g_recoveryZoneLow      = 0.0;
   g_recoveryClosedProfit = 0.0;
   g_recoveryTargetProfit = 0.0;
   g_recoveryStartEquity  = 0.0;
   g_recoveryNextLot      = 0.0;
   g_recoveryLastDirection= 0;
   g_recoveryInitialDirection = 0;
   g_recoveryLossDirection = 0;
   g_recoveryBuyDone      = false;
   g_recoverySellDone     = false;
   g_recoveryStepCount    = 0;
   g_recoveryZoneBreached = false;
   g_recoveryGridAnchorPrice = 0.0;
   g_recoveryGridStepPrice   = 0.0;
   g_recoveryGridMaxLevelsActive = 0;
   g_recoveryGridLastExecPrice = 0.0;
   g_recoveryGridTrendAnchorReady = false;
   g_recoveryGridTrendDirection = 0;
   g_recoveryGridTrendNextLevel = 1;
   g_recoveryGridTrendLastBarTime = 0;
   g_recoveryLastOpenPrice = 0.0;
   g_recoveryLastOpenDirection = 0;
   g_recoveryDistLastBarTime = 0;
   g_basketPeakProfit = 0.0;
   g_basketTrailActive = false;
   g_classicCycleClosePending = false;
   g_classicCyclePendingProfit = 0.0;
   ArrayResize(g_recoveryGridUpperDone, 0);
   ArrayResize(g_recoveryGridLowerDone, 0);
   DeleteRecoveryLines();

   Print("INFO: [CLASSIC] Recovery pending start. Waiting ST+PSAR signal (classic filter). Loss=",
         DoubleToString(lossAmount, 2), " DealVol=", DoubleToString(dealVolume, 2));
  }

//+------------------------------------------------------------------+
bool TryStartClassicRecoveryFromSignal(const double bid, const double ask)
  {
   if(!g_recoveryPendingStart || InpRecoveryMode != RECOVERY_MODE_CLASSIC_ZONE)
      return false;

   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == 0 || currentBarTime == g_recoveryClassicPendingLastBarTime)
      return false;
   g_recoveryClassicPendingLastBarTime = currentBarTime;

   int trendDir = GetClassicRecoveryTrendDirection();
   if(trendDir == 0)
      return false;

   if(InpMaxRecoverySteps > 0 && g_recoveryStepCount >= InpMaxRecoverySteps)
      return false;
   if(InpMaxRecoveryPositions > 0 && CountRecoveryPositions() >= InpMaxRecoveryPositions)
      return false;

   double startLotMultiplier = MathMax(1.0, InpRecoveryLotMultiplier);
   double baseVolume = (g_recoveryClassicBaseDealVolume > 0.0)
                       ? g_recoveryClassicBaseDealVolume
                       : g_recoveryPendingDealVolume;
   double rawNextLot = baseVolume * startLotMultiplier;
   double nextLot = RoundLotToStep(rawNextLot);
   if(nextLot <= 0.0)
      nextLot = InpLotSize;
   if(InpMaxRecoveryLot > 0.0 && nextLot > InpMaxRecoveryLot)
     {
      nextLot = RoundLotToStep(InpMaxRecoveryLot);
      PrintDebug(StringFormat("Recovery lot capped to max: %.2f", nextLot));
     }

   double signalPrice = (trendDir > 0) ? ask : bid;
   string recComment = (trendDir > 0) ? (InpBuyComment + " " + RECOVERY_TAG)
                                      : (InpSellComment + " " + RECOVERY_TAG);
   bool ok = false;
   if(trendDir > 0)
      ok = g_trade.Buy(nextLot, _Symbol, ask, 0.0, 0.0, recComment);
   else if(trendDir < 0)
      ok = g_trade.Sell(nextLot, _Symbol, bid, 0.0, 0.0, recComment);

   if(!ok)
     {
      Print("WARNING: [CLASSIC_PENDING_START] Failed to open first order. Dir=",
            (trendDir > 0 ? "BUY" : "SELL"),
            " RetCode=", g_trade.ResultRetcode(),
            " Desc=", g_trade.ResultRetcodeDescription());
      return false;
     }

   double zoneRange = GetRecoveryZoneRange();
   BuildRecoveryZoneFromSignal(signalPrice, trendDir, zoneRange);

   if(g_recoveryRemainingTarget <= 0.0)
      g_recoveryRemainingTarget = MathMax(0.01, g_recoveryPendingLossAmount * MathMax(1.0, InpRecoveryTargetMultiplier));

   g_recoveryActive       = true;
   g_recoveryPendingStart = false;
   g_recoveryClosedProfit = 0.0;
   g_recoveryTargetProfit = MathMax(0.01, g_recoveryRemainingTarget);
   g_recoveryStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_recoveryNextLot      = rawNextLot * MathMax(1.0, InpRecoveryLotMultiplier);
   g_recoveryLastDirection= (trendDir > 0) ? 1 : -1;
   g_recoveryInitialDirection = trendDir;
   g_recoveryLossDirection = 0;
   g_recoveryBuyDone      = (trendDir > 0);
   g_recoverySellDone     = (trendDir < 0);
   g_recoveryStepCount++;
   g_recoveryZoneBreached = false;
   g_basketPeakProfit     = 0.0;
   g_basketTrailActive    = false;
   g_classicCycleClosePending = false;
   g_classicCyclePendingProfit = 0.0;

   g_recoveryPendingLossAmount = 0.0;
   g_recoveryPendingDealVolume = 0.0;

   Print("INFO: [CLASSIC_START] Recovery started by ST+PSAR. Dir=",
         (trendDir > 0 ? "BUY" : "SELL"),
         " SignalPrice=", DoubleToString(signalPrice, _Digits),
         " ZoneH=", DoubleToString(g_recoveryZoneHigh, _Digits),
         " ZoneL=", DoubleToString(g_recoveryZoneLow, _Digits),
         " StartEquity=", DoubleToString(g_recoveryStartEquity, 2),
         " TargetProfit=", DoubleToString(g_recoveryTargetProfit, 2),
         " TargetEquity=", DoubleToString(g_recoveryStartEquity + g_recoveryTargetProfit, 2),
         " Lot=", DoubleToString(nextLot, 2),
         " Step=", g_recoveryStepCount);

   return true;
  }

//+------------------------------------------------------------------+
void OnClassicRecoveryCycleEnd(const double cycleProfit)
  {
   g_classicCycleClosePending = false;
   g_classicCyclePendingProfit = 0.0;
   g_recoverySecuredProfit += cycleProfit;
   g_recoveryRemainingTarget = g_recoveryTotalTarget - g_recoverySecuredProfit;

   Print("INFO: [CLASSIC_CYCLE_END] CycleProfit=", DoubleToString(cycleProfit, 2),
         " Secured=", DoubleToString(g_recoverySecuredProfit, 2),
         " Remaining=", DoubleToString(g_recoveryRemainingTarget, 2),
         " TotalTarget=", DoubleToString(g_recoveryTotalTarget, 2));

   if(g_recoveryRemainingTarget <= RECOVERY_CLASSIC_DONE_TOLERANCE)
     {
      Print("INFO: [CLASSIC_DONE] Recovery completed. Secured=", DoubleToString(g_recoverySecuredProfit, 2),
            " TotalTarget=", DoubleToString(g_recoveryTotalTarget, 2));
      ResetRecoveryState();
      return;
     }

   double baseVolume = g_recoveryClassicBaseDealVolume;
   if(baseVolume <= 0.0)
      baseVolume = InpLotSize;
   g_recoveryActive = false;
   g_basketPeakProfit = 0.0;
   g_basketTrailActive = false;

   // Between cycles we skip cooldown/guard to allow immediate pending start.
   g_recoveryCooldownUntil = 0;
   g_recoveryRestartGuardUntil = 0;

   StartClassicRecoveryPending(g_recoveryRemainingTarget, baseVolume);
   g_recoveryClassicBaseDealVolume = baseVolume;
   Print("INFO: [CLASSIC_NEXT_CYCLE] Pending next cycle. RemainingTarget=",
         DoubleToString(g_recoveryRemainingTarget, 2),
         " BaseVolume=", DoubleToString(g_recoveryClassicBaseDealVolume, 2));
  }

//+------------------------------------------------------------------+
bool CloseClassicRecoveryExposureAndEndCycle(const double cycleProfit, const string reason)
  {
   if(!g_classicCycleClosePending)
     {
      g_classicCycleClosePending = true;
      g_classicCyclePendingProfit = cycleProfit;
     }

   g_closingRecoveryPositions = true;
   bool deleteDone = DeleteRecoveryPendingOrders();
   bool closeDone = CloseAllRecoveryPositions();
   if(deleteDone)
      deleteDone = DeleteRecoveryPendingOrders();

   int remainingRecPos = CountRecoveryPositions();
   int remainingRecPending = CountRecoveryPendingOrders();
   bool exposureCleared = (remainingRecPos == 0 && remainingRecPending == 0);
   if(closeDone && deleteDone && exposureCleared)
     {
      Print("INFO: [CLASSIC_CYCLE_CLOSE] Reason=", reason,
            " Profit=", DoubleToString(g_classicCyclePendingProfit, 2));
      OnClassicRecoveryCycleEnd(g_classicCyclePendingProfit);
      g_closingRecoveryPositions = false;
      return true;
     }

   Print("WARNING: [CLASSIC_CYCLE_CLOSE] Cleanup pending. Reason=", reason,
         " CloseDone=", (closeDone ? "true" : "false"),
         " DeleteDone=", (deleteDone ? "true" : "false"),
         " RemainingPos=", remainingRecPos,
         " RemainingPending=", remainingRecPending);
   g_closingRecoveryPositions = false;
   return false;
  }

//+------------------------------------------------------------------+
void CheckClassicRecoveryCycleTargetReached()
  {
   if(!g_recoveryActive || InpRecoveryMode != RECOVERY_MODE_CLASSIC_ZONE)
      return;
   if(g_recoveryTargetProfit <= 0.0)
      return;

   double floatingProfit = GetRecoveryFloatingProfitOnly();
   if(floatingProfit >= g_recoveryTargetProfit)
      CloseClassicRecoveryExposureAndEndCycle(floatingProfit, "TARGET_REACHED");
  }

//+------------------------------------------------------------------+
void TrailClassicRecoveryBasket()
  {
   if(!InpBasketTrailing || !g_recoveryActive || InpRecoveryMode != RECOVERY_MODE_CLASSIC_ZONE)
      return;
   if(g_recoveryTargetProfit <= 0.0)
      return;

   double floatingProfit = GetRecoveryFloatingProfitOnly();
   double thresholdRatio = MathMax(0.0, InpBasketTrailThreshold);
   double threshold = g_recoveryTargetProfit * thresholdRatio;

   if(!g_basketTrailActive)
     {
      if(floatingProfit >= threshold)
        {
         g_basketTrailActive = true;
         g_basketPeakProfit = floatingProfit;
         Print("INFO: [CLASSIC_BASKET_TRAIL] Activated. Threshold=", DoubleToString(threshold, 2),
               " Peak=", DoubleToString(g_basketPeakProfit, 2));
        }
      return;
     }

   if(floatingProfit > g_basketPeakProfit)
      g_basketPeakProfit = floatingProfit;

   double gapPct = InpBasketTrailGapPct;
   if(gapPct < 0.0)
      gapPct = 0.0;
   if(gapPct > 0.95)
      gapPct = 0.95;

   double trailSL = g_basketPeakProfit * (1.0 - gapPct);
   if(InpBasketHardFloor && g_basketPeakProfit >= g_recoveryTargetProfit)
      trailSL = MathMax(trailSL, g_recoveryTargetProfit);

   if(floatingProfit <= trailSL)
      CloseClassicRecoveryExposureAndEndCycle(floatingProfit, "TRAIL_HIT");
  }

//+------------------------------------------------------------------+
void HandleClassicRecoveryMode(const double bid, const double ask)
  {
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

   string recComment = InpBuyComment + " " + RECOVERY_TAG;

   // Harga menembus batas atas → BUY recovery
   if(bid >= g_recoveryZoneHigh)
     {
      if(!g_recoveryBuyDone || g_recoveryLastDirection < 0)
        {
         double sl = 0.0;
         double tp = 0.0;
         if(g_trade.Buy(nextLot, _Symbol, ask, sl, tp, recComment))
           {
            g_recoveryLastDirection = 1;
            g_recoveryBuyDone      = true;
            g_recoverySellDone     = false;
            g_recoveryStepCount++;
            g_recoveryNextLot      = g_recoveryNextLot * MathMax(1.0, InpRecoveryLotMultiplier);
            Print("INFO: [CLASSIC] Recovery BUY opened. Lot=", nextLot,
                  " Step=", g_recoveryStepCount, "/", InpMaxRecoverySteps,
                  " NextRaw=", g_recoveryNextLot);
           }
        }
     }
   // Harga menembus batas bawah → SELL recovery
   else if(bid <= g_recoveryZoneLow)
     {
      if(!g_recoverySellDone || g_recoveryLastDirection > 0)
        {
         double sl = 0.0;
         double tp = 0.0;
         recComment = InpSellComment + " " + RECOVERY_TAG;
         if(g_trade.Sell(nextLot, _Symbol, bid, sl, tp, recComment))
           {
            g_recoveryLastDirection = -1;
            g_recoverySellDone     = true;
            g_recoveryBuyDone      = false;
            g_recoveryStepCount++;
            g_recoveryNextLot      = g_recoveryNextLot * MathMax(1.0, InpRecoveryLotMultiplier);
            Print("INFO: [CLASSIC] Recovery SELL opened. Lot=", nextLot,
                  " Step=", g_recoveryStepCount, "/", InpMaxRecoverySteps,
                  " NextRaw=", g_recoveryNextLot);
           }
        }
     }
  }

#endif // TS7_RECOVERY_CLASSIC_MQH
