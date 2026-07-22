//+------------------------------------------------------------------+
//|                              TS7/Recovery/RecoveryManager.mqh    |
//|                              Recovery lifecycle and dispatcher   |
//+------------------------------------------------------------------+
#ifndef TS7_RECOVERY_MANAGER_MQH
#define TS7_RECOVERY_MANAGER_MQH

//+------------------------------------------------------------------+
void ResetRecoveryState()
  {
   g_recoveryActive       = false;
   g_recoveryPendingStart = false;
   g_recoveryPendingLossAmount = 0.0;
   g_recoveryPendingDealVolume = 0.0;
   g_recoveryClassicBaseDealVolume = 0.0;
   g_recoveryClassicPendingLastBarTime = 0;
   g_recoveryZoneHigh     = 0.0;
   g_recoveryZoneLow      = 0.0;
   g_recoveryClosedProfit = 0.0;
   g_recoveryTargetProfit = 0.0;
   g_recoveryTotalTarget = 0.0;
   g_recoverySecuredProfit = 0.0;
   g_recoveryRemainingTarget = 0.0;
   g_basketPeakProfit = 0.0;
   g_basketTrailActive = false;
   g_classicCycleClosePending = false;
   g_classicCyclePendingProfit = 0.0;
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
   DeleteRecoveryPendingOrders();
   ArrayResize(g_recoveryGridUpperDone, 0);
   ArrayResize(g_recoveryGridLowerDone, 0);
   DeleteRecoveryLines();
   g_closingRecoveryPositions = false;

   //--- Set cooldown if configured
   if(InpRecoveryCooldownBars > 0)
     {
      // Calculate the bar time N bars from now
      datetime currentBarTime = iTime(_Symbol, _Period, 0);
      if(currentBarTime > 0)
        {
         g_recoveryCooldownUntil = currentBarTime + InpRecoveryCooldownBars * PeriodSeconds(_Period);
         Print("INFO: Recovery cooldown started. Blocked until ", TimeToString(g_recoveryCooldownUntil));
        }
     }

   //--- Short anti-race guard to avoid instant recovery re-trigger from close transactions
   g_recoveryRestartGuardUntil = TimeCurrent() + 3;
  }

//+------------------------------------------------------------------+
void StartRecoveryFromLossDeal(const ulong dealTicket)
  {
   if(!InpEnableRecovery || g_recoveryActive || g_recoveryPendingStart)
      return;

   if(g_recoveryRestartGuardUntil > 0 && TimeCurrent() < g_recoveryRestartGuardUntil)
     {
      PrintDebug("Recovery start blocked by short restart guard.");
      return;
     }

   if(!HistoryDealSelect(dealTicket))
      return;

   string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   long   dealMagic  = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   long   dealEntry  = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(dealSymbol != _Symbol || dealMagic != InpMagicNumber || dealEntry != DEAL_ENTRY_OUT)
      return;

   // Hanya trigger dari posisi strategi, bukan recovery
   string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   if(IsRecoveryComment(dealComment))
      return;

   double lossAmount = -(HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION));
   if(lossAmount <= 0.0)
      return;  // Bukan loss

   double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   double dealVolume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   long   dealType   = HistoryDealGetInteger(dealTicket, DEAL_TYPE);

   // Classic Zone: wait for ST+PSAR signal before starting recovery
   if(InpRecoveryMode == RECOVERY_MODE_CLASSIC_ZONE)
     {
      g_recoveryTotalTarget = MathMax(0.01, lossAmount * MathMax(1.0, InpRecoveryTargetMultiplier));
      g_recoverySecuredProfit = 0.0;
      g_recoveryRemainingTarget = g_recoveryTotalTarget;
      g_recoveryClassicBaseDealVolume = dealVolume;
      StartClassicRecoveryPending(lossAmount, dealVolume);
      Print("INFO: [CLASSIC_ACCUM_INIT] TotalTarget=", DoubleToString(g_recoveryTotalTarget, 2),
            " Remaining=", DoubleToString(g_recoveryRemainingTarget, 2),
            " BaseVolume=", DoubleToString(g_recoveryClassicBaseDealVolume, 2));
      return;
     }

   //--- Hitung zone range
   double zoneRange = GetRecoveryZoneRange();

   //--- Set recovery state
   g_recoveryActive       = true;
   g_recoveryClosedProfit = 0.0;
   g_recoveryStartEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   g_recoveryTargetProfit = MathMax(0.01, lossAmount * MathMax(1.0, InpRecoveryTargetMultiplier));
   if(InpRecoveryMode == RECOVERY_MODE_GRID && InpRecoveryGridTakeProfitMoney > 0.0)
      g_recoveryTargetProfit = MathMax(0.01, InpRecoveryGridTakeProfitMoney);

   double startLotMultiplier = MathMax(1.0, InpRecoveryLotMultiplier);
   if(InpRecoveryMode == RECOVERY_MODE_GRID && InpRecoveryGridLotMultiplier > 0.0)
      startLotMultiplier = MathMax(1.0, InpRecoveryGridLotMultiplier);

   g_recoveryNextLot = dealVolume * startLotMultiplier; // Raw, not rounded
   g_recoveryLastDirection= 0;
   g_recoveryInitialDirection = 0;
   g_recoveryLossDirection = 0;
   g_recoveryBuyDone      = false;
   g_recoverySellDone     = false;
   g_recoveryStepCount    = 0;
   g_recoveryZoneBreached = false;
   g_recoveryGridTrendAnchorReady = false;
   g_recoveryGridTrendDirection = 0;
   g_recoveryGridTrendNextLevel = 1;
   g_recoveryGridTrendLastBarTime = 0;
   g_recoveryLastOpenPrice = 0.0;
   g_recoveryLastOpenDirection = 0;
   g_recoveryDistLastBarTime = 0;
   g_recoveryGridAnchorPrice = NormalizeDouble(closePrice, _Digits);
   if(InpRecoveryMode == RECOVERY_MODE_GRID && InpRecoveryGridDirectionMode == GRID_DIRECTION_TREND_SIGNAL)
      g_recoveryGridAnchorPrice = 0.0; // Will be set on first synced ST+PSAR signal candle
   g_recoveryGridStepPrice   = GetRecoveryGridStepPrice();
   g_recoveryGridMaxLevelsActive = MathMax(0, InpRecoveryGridMaxLevels);
   g_recoveryGridLastExecPrice = 0.0;
   ArrayResize(g_recoveryGridUpperDone, g_recoveryGridMaxLevelsActive + 1);
   ArrayResize(g_recoveryGridLowerDone, g_recoveryGridMaxLevelsActive + 1);
   for(int i = 0; i < ArraySize(g_recoveryGridUpperDone); i++)
      g_recoveryGridUpperDone[i] = false;
   for(int i = 0; i < ArraySize(g_recoveryGridLowerDone); i++)
      g_recoveryGridLowerDone[i] = false;

   // DEAL_ENTRY_OUT note:
   // DEAL_TYPE_SELL = closed BUY, DEAL_TYPE_BUY = closed SELL
   if(dealType == DEAL_TYPE_SELL)
     {
      g_recoveryLossDirection = 1;     // Loss BUY
      g_recoveryInitialDirection = -1; // Loss BUY -> first recovery SELL
     }
   else if(dealType == DEAL_TYPE_BUY)
     {
      g_recoveryLossDirection = -1;    // Loss SELL
      g_recoveryInitialDirection = 1;  // Loss SELL -> first recovery BUY
     }

   //--- Bentuk zone high & low
   BuildRecoveryZone(closePrice, dealType, zoneRange);

   //--- Log
   string modeText = "CLASSIC";
   if(InpRecoveryMode == RECOVERY_MODE_TREND)
      modeText = "TREND";
   else if(InpRecoveryMode == RECOVERY_MODE_START_REVERSE)
      modeText = "START_REVERSE";
   else if(InpRecoveryMode == RECOVERY_MODE_GRID)
      modeText = "GRID";
   else if(InpRecoveryMode == RECOVERY_MODE_DISTANCE)
      modeText = "DISTANCE";

   string initDirText = "NONE";
   if(g_recoveryInitialDirection > 0)
      initDirText = "BUY";
   else if(g_recoveryInitialDirection < 0)
      initDirText = "SELL";

   Print("INFO: Recovery started [Mode=", modeText, "]. Loss=", DoubleToString(lossAmount, 2),
         " StartEquity=", DoubleToString(g_recoveryStartEquity, 2),
         " Target=", DoubleToString(g_recoveryTargetProfit, 2),
         " TargetEquity=", DoubleToString(g_recoveryStartEquity + g_recoveryTargetProfit, 2),
         " ZoneH=", DoubleToString(g_recoveryZoneHigh, _Digits),
         " ZoneL=", DoubleToString(g_recoveryZoneLow, _Digits),
         " NextLot=", DoubleToString(g_recoveryNextLot, 2),
         " InitDir=", initDirText);

   if(InpRecoveryMode == RECOVERY_MODE_GRID)
     {
      string anchorText = (g_recoveryGridAnchorPrice > 0.0)
                          ? DoubleToString(g_recoveryGridAnchorPrice, _Digits)
                          : "WAIT_SIGNAL";
      Print("INFO: [GRID] Anchor=", anchorText,
            " Step=", DoubleToString(g_recoveryGridStepPrice, _Digits),
            " MaxLevels=", g_recoveryGridMaxLevelsActive,
            " DirMode=", (int)InpRecoveryGridDirectionMode);
     }
  }

//+------------------------------------------------------------------+
int GetRecoveryTrendDirection()
  {
   int st   = GetSuperTrendDirection();
   int psar = GetPSARState();

   if(st == 1 && psar == 1)
      return 1;   // Both UP → BUY recovery only
   if(st == -1 && psar == -1)
      return -1;  // Both DOWN → SELL recovery only

   return 0;      // Not synced → wait
  }

//+------------------------------------------------------------------+
int GetClassicRecoveryTrendDirection()
  {
   int st = GetSuperTrendDirection();
   if(g_handles.recoveryClassicST != INVALID_HANDLE)
      st = GetSuperTrendDirectionByHandle(g_handles.recoveryClassicST);

   int psar = GetPSARState();
   if(g_handles.recoveryClassicPSAR != INVALID_HANDLE)
      psar = GetPSARStateByHandle(g_handles.recoveryClassicPSAR);

   if(st == 1 && psar == 1)
      return 1;
   if(st == -1 && psar == -1)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
void UpdateRecoveryFromClosedDeal(const ulong dealTicket)
  {
   if(!g_recoveryActive || !HistoryDealSelect(dealTicket))
      return;

   string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   long   dealMagic  = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   long   dealEntry  = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
   if(dealSymbol != _Symbol || dealMagic != InpMagicNumber || dealEntry != DEAL_ENTRY_OUT)
      return;

   string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   if(!IsRecoveryComment(dealComment))
      return;

   double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                       + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                       + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
   g_recoveryClosedProfit += dealProfit;
  }

//+------------------------------------------------------------------+
void HandleRecoveryZone()
  {
   if(!g_recoveryActive)
     {
      if(g_recoveryPendingStart && InpRecoveryMode == RECOVERY_MODE_CLASSIC_ZONE)
         TryStartClassicRecoveryFromSignal(g_symbolInfo.Bid(), g_symbolInfo.Ask());
      return;
     }

   double bid = g_symbolInfo.Bid();
   double ask = g_symbolInfo.Ask();
   bool classicBasketMode = (InpRecoveryMode == RECOVERY_MODE_CLASSIC_ZONE && InpBasketTrailing);

   // Cek target recovery default (fallback mode):
   if(!classicBasketMode)
     {
      double floatingProfit = GetRecoveryFloatingProfit();
      double totalProfit = g_recoveryClosedProfit + floatingProfit;
      if(totalProfit >= g_recoveryTargetProfit)
        {
         g_closingRecoveryPositions = true;  // Guard ON: prevent re-trigger
         bool closeDone = false;
         bool deleteDone = true;
         // Delete pending first to reduce race where pending triggers while closing.
         deleteDone = DeleteRecoveryPendingOrders();
         closeDone = CloseAllRecoveryPositions();
         // Run delete again in case pending appears between close operations.
         if(deleteDone)
            deleteDone = DeleteRecoveryPendingOrders();

         int remainingRecPos = CountRecoveryPositions();
         int remainingRecPending = CountRecoveryPendingOrders();
         bool exposureCleared = (remainingRecPos == 0 && remainingRecPending == 0);

         if(closeDone && deleteDone && exposureCleared)
           {
            Print("INFO: Recovery finished! Profit=", DoubleToString(totalProfit, 2),
                  " Target=", DoubleToString(g_recoveryTargetProfit, 2),
                  " Steps=", g_recoveryStepCount);
            ResetRecoveryState();
           }
         else
           {
            Print("WARNING: Recovery target hit but cleanup pending. CloseDone=", (closeDone ? "true" : "false"),
                  " DeleteDone=", (deleteDone ? "true" : "false"),
                  " RemainingPos=", remainingRecPos,
                  " RemainingPending=", remainingRecPending,
                  ". Recovery stays active for next cleanup tick.");
           }
         g_closingRecoveryPositions = false; // Guard OFF
         return;
        }
     }

   //--- Max drawdown check: force close all recovery if floating loss exceeds limit
   if(InpRecoveryMaxDrawdown > 0.0)
     {
      double floatingPL = GetRecoveryFloatingProfit();
      double basketPL   = g_recoveryClosedProfit + floatingPL;
      if(basketPL < 0.0 && MathAbs(basketPL) >= InpRecoveryMaxDrawdown)
        {
         g_closingRecoveryPositions = true;
         Print("WARNING: Recovery max drawdown hit! BasketPL=", DoubleToString(basketPL, 2),
               " Limit=-", DoubleToString(InpRecoveryMaxDrawdown, 2),
               " Steps=", g_recoveryStepCount, ". Force closing all recovery positions.");
         CloseAllRecoveryPositions();
         DeleteRecoveryPendingOrders();
         ResetRecoveryState();
         g_closingRecoveryPositions = false;
         return;
        }
     }

   bool needsZone = (InpRecoveryMode == RECOVERY_MODE_CLASSIC_ZONE
                     || InpRecoveryMode == RECOVERY_MODE_TREND
                     || InpRecoveryMode == RECOVERY_MODE_START_REVERSE);
   if(needsZone && (g_recoveryZoneHigh <= 0.0 || g_recoveryZoneLow <= 0.0))
      return;

   // Dispatch berdasarkan mode
   if(InpRecoveryMode == RECOVERY_MODE_CLASSIC_ZONE)
      HandleClassicRecoveryMode(bid, ask);
   else if(InpRecoveryMode == RECOVERY_MODE_TREND)
      HandleTrendRecoveryMode(bid, ask);
   else if(InpRecoveryMode == RECOVERY_MODE_START_REVERSE)
      HandleStartReverseRecoveryMode(bid, ask);
   else if(InpRecoveryMode == RECOVERY_MODE_GRID)
      HandleGridRecoveryMode(bid, ask);
   else if(InpRecoveryMode == RECOVERY_MODE_DISTANCE)
      HandleDistanceRecoveryMode(bid, ask);
   else
      HandleClassicRecoveryMode(bid, ask);

   if(classicBasketMode)
     {
      TrailClassicRecoveryBasket();
      CheckClassicRecoveryCycleTargetReached();
     }
  }

#endif // TS7_RECOVERY_MANAGER_MQH
