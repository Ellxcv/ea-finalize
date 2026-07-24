//+------------------------------------------------------------------+
//|                              TS7/Recovery/RecoveryUtils.mqh      |
//|                              Shared recovery helper functions    |
//+------------------------------------------------------------------+
#ifndef TS7_RECOVERY_RECOVERY_UTILS_MQH
#define TS7_RECOVERY_RECOVERY_UTILS_MQH

//+------------------------------------------------------------------+
bool IsRecoveryComment(const string comment)
  {
   return (StringFind(comment, RECOVERY_TAG) >= 0);
  }

//+------------------------------------------------------------------+
int CountRecoveryPositions()
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      if(!g_positionInfo.SelectByIndex(i))
         continue;
      if(g_positionInfo.Symbol() != _Symbol || g_positionInfo.Magic() != InpMagicNumber)
         continue;
      if(IsRecoveryComment(g_positionInfo.Comment()))
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
int CountRecoveryPositionsByType(const ENUM_POSITION_TYPE posType)
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      if(!g_positionInfo.SelectByIndex(i))
         continue;
      if(g_positionInfo.Symbol() != _Symbol || g_positionInfo.Magic() != InpMagicNumber)
         continue;
      if(!IsRecoveryComment(g_positionInfo.Comment()))
         continue;
      if(g_positionInfo.PositionType() == posType)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
bool IsRecoveryDealByPosition(const ulong dealTicket)
  {
   if(!HistoryDealSelect(dealTicket))
      return false;

   long positionId = (long)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   if(positionId <= 0)
      return false;

   // Select all deals belonging to this position
   if(!HistorySelectByPosition(positionId))
      return false;

   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
     {
      ulong entryTicket = HistoryDealGetTicket(i);
      if(entryTicket == 0)
         continue;

      long entry = HistoryDealGetInteger(entryTicket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
        {
         string entryComment = HistoryDealGetString(entryTicket, DEAL_COMMENT);
         return IsRecoveryComment(entryComment);
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
void DrawRecoveryLine(const string name, const double price, const color clr)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   else
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);

   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void DeleteRecoveryLines()
  {
   ObjectDelete(0, REC_ZONE_H_LINE);
   ObjectDelete(0, REC_ZONE_L_LINE);
  }

//+------------------------------------------------------------------+
double GetRecoveryFloatingProfit()
  {
   double total = 0.0;
   int count = PositionsTotal();
   for(int i = count - 1; i >= 0; i--)
     {
      if(!g_positionInfo.SelectByIndex(i))
         continue;
      if(g_positionInfo.Symbol() != _Symbol || g_positionInfo.Magic() != InpMagicNumber)
         continue;
      if(!IsRecoveryComment(g_positionInfo.Comment()))
         continue;
      total += g_positionInfo.Profit() + g_positionInfo.Swap() + g_positionInfo.Commission();
     }
   return total;
  }

//+------------------------------------------------------------------+
double GetRecoveryFloatingProfitOnly()
  {
   double total = 0.0;
   int count = PositionsTotal();
   for(int i = count - 1; i >= 0; i--)
     {
      if(!g_positionInfo.SelectByIndex(i))
         continue;
      if(g_positionInfo.Symbol() != _Symbol || g_positionInfo.Magic() != InpMagicNumber)
         continue;
      if(!IsRecoveryComment(g_positionInfo.Comment()))
         continue;
      total += g_positionInfo.Profit();
     }
   return total;
  }

//+------------------------------------------------------------------+
bool CloseAllRecoveryPositions()
  {
   bool allClosed = true;
   int count = PositionsTotal();
   for(int i = count - 1; i >= 0; i--)
     {
      if(!g_positionInfo.SelectByIndex(i))
         continue;
      if(g_positionInfo.Symbol() != _Symbol || g_positionInfo.Magic() != InpMagicNumber)
         continue;
      if(!IsRecoveryComment(g_positionInfo.Comment()))
         continue;

      ulong ticket = g_positionInfo.Ticket();
      if(!g_trade.PositionClose(ticket))
        {
         Print("WARNING: Failed to close recovery position #", ticket);
         allClosed = false;
        }
     }
   return allClosed;
  }

//+------------------------------------------------------------------+
//| Complete a previously triggered GRID hard abort                  |
//+------------------------------------------------------------------+
bool ContinueRecoveryHardAbortCleanup()
  {
   if(!g_recoveryHardAbortPending)
      return false;

   g_closingRecoveryPositions = true;
   bool deleteDone = DeleteRecoveryPendingOrders();
   bool closeDone = CloseAllRecoveryPositions();
   if(deleteDone)
      deleteDone = DeleteRecoveryPendingOrders();

   int remainingPositions = CountRecoveryPositions();
   int remainingPending = CountRecoveryPendingOrders();
   bool exposureCleared =
      (remainingPositions == 0 && remainingPending == 0);

   if(closeDone && deleteDone && exposureCleared)
     {
      g_recoveryHardAbortCount++;
      g_recoveryHardAbortTotalBasketPL += g_recoveryHardAbortBasketPL;
      Print("WARNING: [RECOVERY_HARD_ABORT_COMPLETE] Recovery failed before L",
            g_recoveryHardAbortLevel,
            ". Trigger=", DoubleToString(g_recoveryHardAbortTriggerPrice, _Digits),
            " BasketPLAtTrigger=", DoubleToString(g_recoveryHardAbortBasketPL, 2),
            " ClosedRecoveryPL=", DoubleToString(g_recoveryClosedProfit, 2),
            " AbortCount=", g_recoveryHardAbortCount,
            ". Normal entry resumes after configured recovery cooldown.");
      ResetRecoveryState("HARD_ABORT_BEFORE_LEVEL");
      g_closingRecoveryPositions = false;
      return true;
     }

   Print("WARNING: [RECOVERY_HARD_ABORT_RETRY] Cleanup incomplete before L",
         g_recoveryHardAbortLevel,
         ". CloseDone=", (closeDone ? "true" : "false"),
         " DeleteDone=", (deleteDone ? "true" : "false"),
         " RemainingPos=", remainingPositions,
         " RemainingPending=", remainingPending,
         ". Recovery remains blocked.");
   g_closingRecoveryPositions = false;
   return false;
  }

//+------------------------------------------------------------------+
//| Trigger GRID hard abort instead of opening the configured level  |
//+------------------------------------------------------------------+
bool TryTriggerRecoveryHardAbort(const int level,
                                 const double triggerPrice,
                                 const double bid,
                                 const double ask)
  {
   if(InpRecoveryAbortBeforeLevel <= 0 ||
      InpRecoveryMode != RECOVERY_MODE_GRID ||
      level < InpRecoveryAbortBeforeLevel)
      return false;

   if(!g_recoveryHardAbortPending)
     {
      g_recoveryHardAbortPending = true;
      g_recoveryHardAbortLevel = level;
      g_recoveryHardAbortTriggerPrice = triggerPrice;
      g_recoveryHardAbortBasketPL =
         g_recoveryClosedProfit + GetRecoveryFloatingProfit();
      Print("WARNING: [RECOVERY_HARD_ABORT_TRIGGER] L", level,
            " condition reached. L", level, " will not be opened.",
            " Steps=", g_recoveryStepCount,
            " RecoveryPositions=", CountRecoveryPositions(),
            " Trigger=", DoubleToString(triggerPrice, _Digits),
            " Bid=", DoubleToString(bid, _Digits),
            " Ask=", DoubleToString(ask, _Digits),
            " BasketPL=", DoubleToString(g_recoveryHardAbortBasketPL, 2));
     }

   ContinueRecoveryHardAbortCleanup();
   return true;
  }

//+------------------------------------------------------------------+
void PrintRecoveryHardAbortSummary()
  {
   if(InpRecoveryAbortBeforeLevel <= 0)
      return;
   Print("INFO: [RECOVERY_HARD_ABORT_SUMMARY] BeforeLevel=",
         InpRecoveryAbortBeforeLevel,
         " AbortedCycles=", g_recoveryHardAbortCount,
         " TriggerBasketPLSum=",
         DoubleToString(g_recoveryHardAbortTotalBasketPL, 2));
  }

//+------------------------------------------------------------------+
int CountRecoveryPendingOrders()
  {
   int count = 0;
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;

      string symbol = OrderGetString(ORDER_SYMBOL);
      long   magic  = (long)OrderGetInteger(ORDER_MAGIC);
      string comment= OrderGetString(ORDER_COMMENT);
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      bool isPending = (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT
                        || type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP
                        || type == ORDER_TYPE_BUY_STOP_LIMIT || type == ORDER_TYPE_SELL_STOP_LIMIT);
      if(!isPending)
         continue;
      if(symbol != _Symbol || magic != InpMagicNumber)
         continue;
      if(!IsRecoveryComment(comment))
         continue;
      count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
bool DeleteRecoveryPendingOrders()
  {
   bool allDeleted = true;
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;

      string symbol = OrderGetString(ORDER_SYMBOL);
      long   magic  = (long)OrderGetInteger(ORDER_MAGIC);
      string comment= OrderGetString(ORDER_COMMENT);
      ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);

      bool isPending = (type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT
                        || type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP
                        || type == ORDER_TYPE_BUY_STOP_LIMIT || type == ORDER_TYPE_SELL_STOP_LIMIT);
      if(!isPending)
         continue;
      if(symbol != _Symbol || magic != InpMagicNumber)
         continue;
      if(!IsRecoveryComment(comment))
         continue;

      if(!g_trade.OrderDelete(ticket))
        {
         allDeleted = false;
         Print("WARNING: Failed to delete recovery pending #", ticket,
               " RetCode=", g_trade.ResultRetcode(),
               " Desc=", g_trade.ResultRetcodeDescription());
        }
      else
        {
         Print("INFO: [RECOVERY_PENDING_CLEANUP] Deleted pending #", ticket);
        }
     }
   return allDeleted;
  }

//+------------------------------------------------------------------+
double GetRecoveryZoneRange()
  {
   double zoneRange = 0.0;
   if(InpRecoveryZoneMode == RECOVERY_ZONE_ATR && g_handles.recoveryATR != INVALID_HANDLE)
     {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(g_handles.recoveryATR, 0, 1, 1, atrBuf) > 0 && atrBuf[0] > 0.0)
        {
         zoneRange = atrBuf[0] * InpRecoveryAtrMultiplier;
         Print("INFO: Recovery zone using ATR. ATR=", DoubleToString(atrBuf[0], _Digits),
               " x ", InpRecoveryAtrMultiplier, " = ", DoubleToString(zoneRange, _Digits));
        }
      else
        {
         Print("WARNING: Failed to read ATR for recovery zone. Fallback to Fixed.");
         zoneRange = InpRecoveryZoneRangePoints * _Point;
        }
     }
   else
     {
      zoneRange = InpRecoveryZoneRangePoints * _Point;
     }
   if(zoneRange <= 0.0)
      zoneRange = 1000 * _Point;

   //--- Clamp min/max
   if(InpRecoveryMinZonePoints > 0)
     {
      double minRange = InpRecoveryMinZonePoints * _Point;
      if(zoneRange < minRange)
         zoneRange = minRange;
     }
   if(InpRecoveryMaxZonePoints > 0)
     {
      double maxRange = InpRecoveryMaxZonePoints * _Point;
      if(zoneRange > maxRange)
         zoneRange = maxRange;
     }

   return zoneRange;
  }

//+------------------------------------------------------------------+
double GetRecoveryGridStepPrice()
  {
   double gridStep = MathAbs(InpRecoveryGridStepPoints) * _Point;

   if(InpRecoveryGridStepMode == GRID_STEP_ATR && g_handles.recoveryGridATR != INVALID_HANDLE)
     {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(g_handles.recoveryGridATR, 0, 1, 1, atrBuf) > 0 && atrBuf[0] > 0.0)
        {
         gridStep = atrBuf[0] * MathMax(0.1, InpRecoveryGridAtrMultiplier);
         Print("INFO: GRID step using ATR. ATR=", DoubleToString(atrBuf[0], _Digits),
               " x ", InpRecoveryGridAtrMultiplier, " = ", DoubleToString(gridStep, _Digits));
        }
      else
        {
         Print("WARNING: Failed to read GRID ATR. Fallback to Fixed step points.");
        }
     }

   if(gridStep <= 0.0)
      gridStep = 500 * _Point;

   return MathMax(_Point, gridStep);
  }

//+------------------------------------------------------------------+
void BuildRecoveryZone(const double closePrice, const long dealType, const double zoneRange)
  {
   // dealType pada DEAL_ENTRY_OUT: DEAL_TYPE_SELL = closed BUY, DEAL_TYPE_BUY = closed SELL
   if(dealType == DEAL_TYPE_SELL)  // Closed BUY position
     {
      // Target mapping:
      // loss BUY -> Low = closePrice, High = closePrice + zoneRange
      g_recoveryZoneLow  = NormalizeDouble(closePrice, _Digits);
      g_recoveryZoneHigh = NormalizeDouble(closePrice + zoneRange, _Digits);
     }
   else if(dealType == DEAL_TYPE_BUY)  // Closed SELL position
     {
      // Target mapping:
      // loss SELL -> High = closePrice, Low = closePrice - zoneRange
      g_recoveryZoneHigh = NormalizeDouble(closePrice, _Digits);
      g_recoveryZoneLow  = NormalizeDouble(closePrice - zoneRange, _Digits);
     }
   else
     {
      g_recoveryZoneHigh = NormalizeDouble(closePrice + zoneRange * 0.5, _Digits);
      g_recoveryZoneLow  = NormalizeDouble(closePrice - zoneRange * 0.5, _Digits);
     }

   DrawRecoveryLine(REC_ZONE_H_LINE, g_recoveryZoneHigh, clrGreen);
   DrawRecoveryLine(REC_ZONE_L_LINE, g_recoveryZoneLow, clrRed);
  }

//+------------------------------------------------------------------+
void BuildRecoveryZoneFromSignal(const double signalPrice, const int signalDir, const double zoneRange)
  {
   if(signalDir > 0) // BUY signal
     {
      g_recoveryZoneHigh = NormalizeDouble(signalPrice, _Digits);
      g_recoveryZoneLow  = NormalizeDouble(signalPrice - zoneRange, _Digits);
     }
   else if(signalDir < 0) // SELL signal
     {
      g_recoveryZoneLow  = NormalizeDouble(signalPrice, _Digits);
      g_recoveryZoneHigh = NormalizeDouble(signalPrice + zoneRange, _Digits);
     }
   else
     {
      g_recoveryZoneHigh = NormalizeDouble(signalPrice + zoneRange * 0.5, _Digits);
      g_recoveryZoneLow  = NormalizeDouble(signalPrice - zoneRange * 0.5, _Digits);
     }

   DrawRecoveryLine(REC_ZONE_H_LINE, g_recoveryZoneHigh, clrGreen);
   DrawRecoveryLine(REC_ZONE_L_LINE, g_recoveryZoneLow, clrRed);
  }

#endif // TS7_RECOVERY_RECOVERY_UTILS_MQH
