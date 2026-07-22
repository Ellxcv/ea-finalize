//+------------------------------------------------------------------+
//|                              TS7/Recovery/RecoveryStartReverse.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_RECOVERY_RECOVERYSTARTREVERSE_MQH
#define TS7_RECOVERY_RECOVERYSTARTREVERSE_MQH

//+------------------------------------------------------------------+
void HandleStartReverseRecoveryMode(const double bid, const double ask)
  {
   // Step pertama: paksa arah lawan dari posisi loss terakhir
   if(g_recoveryStepCount == 0)
     {
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

      if(g_recoveryInitialDirection > 0)
        {
         string recComment = InpBuyComment + " " + RECOVERY_TAG;
         if(g_trade.Buy(nextLot, _Symbol, ask, 0.0, 0.0, recComment))
           {
            g_recoveryLastDirection = 1;
            g_recoveryBuyDone      = true;
            g_recoverySellDone     = false;
            g_recoveryStepCount++;
            g_recoveryNextLot      = g_recoveryNextLot * MathMax(1.0, InpRecoveryLotMultiplier);
            Print("INFO: [START_REVERSE_FIRST_ENTRY] Recovery BUY opened. Lot=", nextLot,
                  " Step=", g_recoveryStepCount, "/", InpMaxRecoverySteps,
                  " NextRaw=", g_recoveryNextLot);
           }
        }
      else if(g_recoveryInitialDirection < 0)
        {
         string recComment = InpSellComment + " " + RECOVERY_TAG;
         if(g_trade.Sell(nextLot, _Symbol, bid, 0.0, 0.0, recComment))
           {
            g_recoveryLastDirection = -1;
            g_recoverySellDone     = true;
            g_recoveryBuyDone      = false;
            g_recoveryStepCount++;
            g_recoveryNextLot      = g_recoveryNextLot * MathMax(1.0, InpRecoveryLotMultiplier);
            Print("INFO: [START_REVERSE_FIRST_ENTRY] Recovery SELL opened. Lot=", nextLot,
                  " Step=", g_recoveryStepCount, "/", InpMaxRecoverySteps,
                  " NextRaw=", g_recoveryNextLot);
           }
        }

      return;
     }

   // Setelah first entry, lanjut logic classic
   HandleClassicRecoveryMode(bid, ask);
  }

#endif // TS7_RECOVERY_RECOVERYSTARTREVERSE_MQH
