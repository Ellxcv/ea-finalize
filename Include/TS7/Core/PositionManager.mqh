//+------------------------------------------------------------------+
//|                                      TS7/Core/PositionManager.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_CORE_POSITIONMANAGER_MQH
#define TS7_CORE_POSITIONMANAGER_MQH

//+------------------------------------------------------------------+
bool CloseAllEAOpenPositions()
  {
   bool allClosed = true;
   int total = PositionsTotal();

   for(int i = total - 1; i >= 0; i--)
     {
      if(!g_positionInfo.SelectByIndex(i))
         continue;
      if(g_positionInfo.Symbol() != _Symbol || g_positionInfo.Magic() != InpMagicNumber)
         continue;

      ulong ticket = g_positionInfo.Ticket();
      if(!g_trade.PositionClose(ticket))
        {
         Print("WARNING: Failed to close EA position #", ticket,
               " during daily drawdown lock.");
         allClosed = false;
        }
     }

   return allClosed;
  }

//+------------------------------------------------------------------+
int CountPositions(const ENUM_POSITION_TYPE posType)
  {
   int count = 0;
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      if(g_positionInfo.SelectByIndex(i))
        {
         if(g_positionInfo.Symbol() == _Symbol &&
            g_positionInfo.Magic()  == InpMagicNumber &&
            g_positionInfo.PositionType() == posType)
           {
            count++;
           }
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
int CountMainStrategyPositions()
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
         continue;
      count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
int CountMainStrategyPositionsByType(const ENUM_POSITION_TYPE posType)
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
         continue;
      if(g_positionInfo.PositionType() == posType)
         count++;
     }
   return count;
  }

#endif // TS7_CORE_POSITIONMANAGER_MQH
