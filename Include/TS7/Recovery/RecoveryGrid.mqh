//+------------------------------------------------------------------+
//|                              TS7/Recovery/RecoveryGrid.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_RECOVERY_RECOVERYGRID_MQH
#define TS7_RECOVERY_RECOVERYGRID_MQH

//+------------------------------------------------------------------+
void HandleGridTrendSignalMode(const double bid, const double ask)
  {
   if(g_recoveryGridStepPrice <= 0.0 || g_recoveryGridMaxLevelsActive <= 0)
      return;

   // Process only on candle close (new bar event)
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == 0 || currentBarTime == g_recoveryGridTrendLastBarTime)
      return;
   g_recoveryGridTrendLastBarTime = currentBarTime;

   int trendDir = GetRecoveryTrendDirection();
   if(trendDir == 0)
      return; // wait until ST+PSAR synced

   // Lock anchor + direction on first synced signal
   if(!g_recoveryGridTrendAnchorReady)
     {
      double signalClosePrice = iClose(_Symbol, _Period, 1); // closed signal candle
      if(signalClosePrice <= 0.0)
         signalClosePrice = bid;

      g_recoveryGridAnchorPrice = NormalizeDouble(signalClosePrice, _Digits);
      g_recoveryGridTrendDirection = trendDir;
      g_recoveryGridTrendAnchorReady = true;
      g_recoveryGridTrendNextLevel = 1;

      Print("INFO: [GRID_TREND_SIGNAL] Anchor locked at ",
            DoubleToString(g_recoveryGridAnchorPrice, _Digits),
            " Direction=", (g_recoveryGridTrendDirection > 0 ? "BUY" : "SELL"));
     }

   // Keep direction fixed to first synced signal for this recovery cycle
   int gridDirection = g_recoveryGridTrendDirection;
   if(gridDirection == 0)
      return;

   if(g_recoveryGridTrendNextLevel < 1 || g_recoveryGridTrendNextLevel > g_recoveryGridMaxLevelsActive)
      return;

   // Risk guard
   if(InpMaxRecoverySteps > 0 && g_recoveryStepCount >= InpMaxRecoverySteps)
      return;
   if(InpMaxRecoveryPositions > 0 && CountRecoveryPositions() >= InpMaxRecoveryPositions)
      return;

   double lotMultiplier = (InpRecoveryGridLotMultiplier > 0.0)
                          ? InpRecoveryGridLotMultiplier
                          : InpRecoveryLotMultiplier;
   lotMultiplier = MathMax(1.0, lotMultiplier);

   double nextLot = RoundLotToStep(g_recoveryNextLot);
   if(nextLot <= 0.0)
      nextLot = InpLotSize;
   if(InpMaxRecoveryLot > 0.0 && nextLot > InpMaxRecoveryLot)
      nextLot = RoundLotToStep(InpMaxRecoveryLot);

   int level = g_recoveryGridTrendNextLevel;
   double levelOffset = (level - 1) * g_recoveryGridStepPrice;
   double triggerPrice = g_recoveryGridAnchorPrice;
   if(gridDirection > 0)
       triggerPrice = NormalizeDouble(g_recoveryGridAnchorPrice - levelOffset, _Digits); // BUY ladder down (DCA against rising loss)
    else
       triggerPrice = NormalizeDouble(g_recoveryGridAnchorPrice + levelOffset, _Digits); // SELL ladder up (DCA against falling loss)

   bool levelTriggered = false;
   if(level == 1)
      levelTriggered = true;
   else
     {
      // Evaluate trigger from the fully closed candle to avoid missing intra-bar touches
      double prevHigh = iHigh(_Symbol, _Period, 1);
      double prevLow  = iLow(_Symbol, _Period, 1);
      if(prevHigh <= 0.0 || prevLow <= 0.0)
         return;

      if(gridDirection > 0)
          levelTriggered = (prevLow <= triggerPrice);   // BUY ladder down: trigger if closed bar low touched level
       else
          levelTriggered = (prevHigh >= triggerPrice);  // SELL ladder up: trigger if closed bar high touched level
     }
   if(!levelTriggered)
      return;

   double marketEntryPrice = (gridDirection > 0) ? ask : bid;
   if(g_recoveryGridLastExecPrice > 0.0 && MathAbs(marketEntryPrice - g_recoveryGridLastExecPrice) < g_recoveryGridStepPrice)
      return;

   if(gridDirection > 0)
     {
      string recComment = InpBuyComment + " " + RECOVERY_TAG;
      if(g_trade.Buy(nextLot, _Symbol, ask, 0.0, 0.0, recComment))
        {
         if(level < ArraySize(g_recoveryGridUpperDone))
            g_recoveryGridUpperDone[level] = true;

         g_recoveryLastDirection = 1;
         g_recoveryBuyDone      = true;
         g_recoverySellDone     = false;
         g_recoveryStepCount++;
         g_recoveryNextLot      = g_recoveryNextLot * lotMultiplier;
         g_recoveryGridLastExecPrice = ask;
         g_recoveryGridTrendNextLevel++;
         Print("INFO: [GRID_TREND_SIGNAL] BUY opened. Level=", level,
               " Trigger=", DoubleToString(triggerPrice, _Digits),
               " Anchor=", DoubleToString(g_recoveryGridAnchorPrice, _Digits),
               " Lot=", nextLot, " Step=", g_recoveryStepCount);
        }
     }
   else
     {
      string recComment = InpSellComment + " " + RECOVERY_TAG;
      if(g_trade.Sell(nextLot, _Symbol, bid, 0.0, 0.0, recComment))
        {
         if(level < ArraySize(g_recoveryGridLowerDone))
            g_recoveryGridLowerDone[level] = true;

         g_recoveryLastDirection = -1;
         g_recoverySellDone     = true;
         g_recoveryBuyDone      = false;
         g_recoveryStepCount++;
         g_recoveryNextLot      = g_recoveryNextLot * lotMultiplier;
         g_recoveryGridLastExecPrice = bid;
         g_recoveryGridTrendNextLevel++;
         Print("INFO: [GRID_TREND_SIGNAL] SELL opened. Level=", level,
               " Trigger=", DoubleToString(triggerPrice, _Digits),
               " Anchor=", DoubleToString(g_recoveryGridAnchorPrice, _Digits),
               " Lot=", nextLot, " Step=", g_recoveryStepCount);
        }
     }
  }

//+------------------------------------------------------------------+
void HandleGridRecoveryMode(const double bid, const double ask)
  {
   if(g_recoveryGridStepPrice <= 0.0 || g_recoveryGridMaxLevelsActive <= 0)
      return;
   if(g_recoveryLossDirection == 0)
      return;

   if(InpRecoveryGridDirectionMode == GRID_DIRECTION_TREND_SIGNAL)
     {
      HandleGridTrendSignalMode(bid, ask);
      return;
     }

   double lotMultiplier = (InpRecoveryGridLotMultiplier > 0.0)
                          ? InpRecoveryGridLotMultiplier
                          : InpRecoveryLotMultiplier;
   lotMultiplier = MathMax(1.0, lotMultiplier);

   for(int level = 1; level <= g_recoveryGridMaxLevelsActive; level++)
     {
      // Risk guard (re-check each level)
      if(InpMaxRecoverySteps > 0 && g_recoveryStepCount >= InpMaxRecoverySteps)
         return;
      if(InpMaxRecoveryPositions > 0 && CountRecoveryPositions() >= InpMaxRecoveryPositions)
         return;

      double nextLot = RoundLotToStep(g_recoveryNextLot);
      if(nextLot <= 0.0)
         nextLot = InpLotSize;
      if(InpMaxRecoveryLot > 0.0 && nextLot > InpMaxRecoveryLot)
        {
         nextLot = RoundLotToStep(InpMaxRecoveryLot);
         PrintDebug(StringFormat("Recovery lot capped to max: %.2f", nextLot));
        }

      // L1 starts from anchor price, then expands by grid step
      double levelOffset = (level - 1) * g_recoveryGridStepPrice;
      double upperPrice = NormalizeDouble(g_recoveryGridAnchorPrice + levelOffset, _Digits);
      double lowerPrice = NormalizeDouble(g_recoveryGridAnchorPrice - levelOffset, _Digits);

      // Single-direction grid (with-loss / reverse)
      if(InpRecoveryGridDirectionMode != GRID_DIRECTION_HEDGE_BOTH)
        {
         int gridDirection = 0;
         if(InpRecoveryGridDirectionMode == GRID_DIRECTION_WITH_LOSS)
            gridDirection = g_recoveryLossDirection;
         else
            gridDirection = -g_recoveryLossDirection; // GRID_DIRECTION_REVERSE

         // Ladder side follows current grid order direction:
         // BUY grid -> lower ladder (averaging down)
         // SELL grid -> upper ladder (averaging up)
         bool useUpperLadder = (gridDirection < 0);
         double triggerPrice = useUpperLadder ? upperPrice : lowerPrice;
         bool levelDone = false;
         if(useUpperLadder && level < ArraySize(g_recoveryGridUpperDone))
            levelDone = g_recoveryGridUpperDone[level];
         else if(!useUpperLadder && level < ArraySize(g_recoveryGridLowerDone))
            levelDone = g_recoveryGridLowerDone[level];

         bool naturalTriggered = (useUpperLadder) ? (bid >= triggerPrice) : (bid <= triggerPrice);
         bool forceLevel1 = (level == 1 && InpRecoveryGridForceLevel1Market);
         bool forcedLevel1Only = (forceLevel1 && !naturalTriggered);
         bool levelTriggered = forceLevel1 || naturalTriggered;
         if(levelDone || !levelTriggered || gridDirection == 0)
            continue;

         if(gridDirection > 0)
           {
            string recComment = InpBuyComment + " " + RECOVERY_TAG;
            if(g_trade.Buy(nextLot, _Symbol, ask, 0.0, 0.0, recComment))
              {
               if(useUpperLadder && level < ArraySize(g_recoveryGridUpperDone))
                  g_recoveryGridUpperDone[level] = true;
               else if(!useUpperLadder && level < ArraySize(g_recoveryGridLowerDone))
                  g_recoveryGridLowerDone[level] = true;

               g_recoveryLastDirection = 1;
               g_recoveryBuyDone      = true;
               g_recoverySellDone     = false;
               g_recoveryStepCount++;
               g_recoveryNextLot      = g_recoveryNextLot * lotMultiplier;
               g_recoveryGridLastExecPrice = ask;
               if(forcedLevel1Only)
                 {
                  double filledPrice = g_trade.ResultPrice();
                  if(filledPrice <= 0.0)
                     filledPrice = ask;
                  g_recoveryGridAnchorPrice = NormalizeDouble(filledPrice, _Digits);
                 }
               Print("INFO: [GRID] BUY opened. Level=", level,
                     " Trigger=", DoubleToString(triggerPrice, _Digits),
                     " ForceL1=", (forceLevel1 ? "true" : "false"),
                     " ForcedOnly=", (forcedLevel1Only ? "true" : "false"),
                     " AnchorNow=", DoubleToString(g_recoveryGridAnchorPrice, _Digits),
                     " DirMode=", (int)InpRecoveryGridDirectionMode,
                     " Lot=", nextLot, " Step=", g_recoveryStepCount);
              }
           }
         else if(gridDirection < 0)
           {
            string recComment = InpSellComment + " " + RECOVERY_TAG;
            if(g_trade.Sell(nextLot, _Symbol, bid, 0.0, 0.0, recComment))
              {
               if(useUpperLadder && level < ArraySize(g_recoveryGridUpperDone))
                  g_recoveryGridUpperDone[level] = true;
               else if(!useUpperLadder && level < ArraySize(g_recoveryGridLowerDone))
                  g_recoveryGridLowerDone[level] = true;

               g_recoveryLastDirection = -1;
               g_recoverySellDone     = true;
               g_recoveryBuyDone      = false;
               g_recoveryStepCount++;
               g_recoveryNextLot      = g_recoveryNextLot * lotMultiplier;
               g_recoveryGridLastExecPrice = bid;
               if(forcedLevel1Only)
                 {
                  double filledPrice = g_trade.ResultPrice();
                  if(filledPrice <= 0.0)
                     filledPrice = bid;
                  g_recoveryGridAnchorPrice = NormalizeDouble(filledPrice, _Digits);
                 }
               Print("INFO: [GRID] SELL opened. Level=", level,
                     " Trigger=", DoubleToString(triggerPrice, _Digits),
                     " ForceL1=", (forceLevel1 ? "true" : "false"),
                     " ForcedOnly=", (forcedLevel1Only ? "true" : "false"),
                     " AnchorNow=", DoubleToString(g_recoveryGridAnchorPrice, _Digits),
                     " DirMode=", (int)InpRecoveryGridDirectionMode,
                     " Lot=", nextLot, " Step=", g_recoveryStepCount);
              }
           }

         continue;
        }

      // Hedge-both grid: BUY on upper levels, SELL on lower levels
      if(level < ArraySize(g_recoveryGridUpperDone) && !g_recoveryGridUpperDone[level] && bid >= upperPrice)
        {
         string recComment = InpBuyComment + " " + RECOVERY_TAG;
         if(g_trade.Buy(nextLot, _Symbol, ask, 0.0, 0.0, recComment))
           {
            g_recoveryGridUpperDone[level] = true;
            g_recoveryLastDirection = 1;
            g_recoveryBuyDone      = true;
            g_recoverySellDone     = false;
            g_recoveryStepCount++;
            g_recoveryNextLot      = g_recoveryNextLot * lotMultiplier;
            Print("INFO: [GRID] BUY opened. Level=", level,
                  " Trigger=", DoubleToString(upperPrice, _Digits),
                  " Lot=", nextLot, " Step=", g_recoveryStepCount);
           }
        }

      if(InpMaxRecoverySteps > 0 && g_recoveryStepCount >= InpMaxRecoverySteps)
         return;
      if(InpMaxRecoveryPositions > 0 && CountRecoveryPositions() >= InpMaxRecoveryPositions)
         return;

      nextLot = RoundLotToStep(g_recoveryNextLot);
      if(nextLot <= 0.0)
         nextLot = InpLotSize;
      if(InpMaxRecoveryLot > 0.0 && nextLot > InpMaxRecoveryLot)
         nextLot = RoundLotToStep(InpMaxRecoveryLot);

      if(level < ArraySize(g_recoveryGridLowerDone) && !g_recoveryGridLowerDone[level] && bid <= lowerPrice)
        {
         string recComment = InpSellComment + " " + RECOVERY_TAG;
         if(g_trade.Sell(nextLot, _Symbol, bid, 0.0, 0.0, recComment))
           {
            g_recoveryGridLowerDone[level] = true;
            g_recoveryLastDirection = -1;
            g_recoverySellDone     = true;
            g_recoveryBuyDone      = false;
            g_recoveryStepCount++;
            g_recoveryNextLot      = g_recoveryNextLot * lotMultiplier;
            Print("INFO: [GRID] SELL opened. Level=", level,
                  " Trigger=", DoubleToString(lowerPrice, _Digits),
                  " Lot=", nextLot, " Step=", g_recoveryStepCount);
           }
        }
     }
  }

#endif // TS7_RECOVERY_RECOVERYGRID_MQH
