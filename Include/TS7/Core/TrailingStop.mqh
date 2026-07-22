//+------------------------------------------------------------------+
//|                                      TS7/Core/TrailingStop.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_CORE_TRAILINGSTOP_MQH
#define TS7_CORE_TRAILINGSTOP_MQH

//+------------------------------------------------------------------+
void ManageTrailingStop()
  {
   if(InpTrailingStartPoints <= 0 || InpTrailingDistancePoints <= 0)
      return;

   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      if(!g_positionInfo.SelectByIndex(i))
         continue;

      if(g_positionInfo.Symbol() != _Symbol ||
         g_positionInfo.Magic()  != InpMagicNumber)
         continue;

      // Skip recovery positions — managed by recovery logic, not trailing
      if(IsRecoveryComment(g_positionInfo.Comment()))
         continue;

      double openPrice   = g_positionInfo.PriceOpen();
      double currentSL   = g_positionInfo.StopLoss();
      double currentTP   = g_positionInfo.TakeProfit();
      ulong  ticket      = g_positionInfo.Ticket();

      g_symbolInfo.RefreshRates();

      if(g_positionInfo.PositionType() == POSITION_TYPE_BUY)
        {
         double bid = g_symbolInfo.Bid();
         double profitPoints = (bid - openPrice) / _Point;

         // Trailing mulai aktif setelah profit >= TrailingStart
         if(profitPoints >= InpTrailingStartPoints)
           {
            double newSL = NormalizeDouble(bid - InpTrailingDistancePoints * _Point, _Digits);

            // Hanya geser SL jika lebih tinggi dari current SL (atau belum ada SL)
            // Dan perubahan minimal TrailingStep
            if(newSL > currentSL || currentSL == 0.0)
              {
               double stepGap = (newSL - currentSL) / _Point;
               if(currentSL == 0.0 || stepGap >= InpTrailingStepPoints)
                 {
                  if(g_trade.PositionModify(ticket, newSL, currentTP))
                     PrintDebug(StringFormat("Trailing BUY #%d: SL moved to %.2f", ticket, newSL));
                 }
              }
           }
        }
      else if(g_positionInfo.PositionType() == POSITION_TYPE_SELL)
        {
         double ask = g_symbolInfo.Ask();
         double profitPoints = (openPrice - ask) / _Point;

         if(profitPoints >= InpTrailingStartPoints)
           {
            double newSL = NormalizeDouble(ask + InpTrailingDistancePoints * _Point, _Digits);

            // Untuk sell, SL baru harus lebih rendah dari current SL
            if(newSL < currentSL || currentSL == 0.0)
              {
               double stepGap = (currentSL - newSL) / _Point;
               if(currentSL == 0.0 || stepGap >= InpTrailingStepPoints)
                 {
                  if(g_trade.PositionModify(ticket, newSL, currentTP))
                     PrintDebug(StringFormat("Trailing SELL #%d: SL moved to %.2f", ticket, newSL));
                 }
              }
           }
        }
     }
  }

#endif // TS7_CORE_TRAILINGSTOP_MQH
