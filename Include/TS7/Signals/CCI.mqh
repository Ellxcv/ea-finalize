//+------------------------------------------------------------------+
//|                                                   TS7/CCI.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_CCI_MQH
#define TS7_CCI_MQH

//+------------------------------------------------------------------+
bool IsCCISignalTypeAllowed(const int signalType)
  {
   int absoluteType = (int)MathAbs(signalType);
   if(InpCciSignalMode == CCI_SIGNAL_MODE_NORMAL_ONLY)
      return (absoluteType == 1);
   if(InpCciSignalMode == CCI_SIGNAL_MODE_STRONG_ONLY)
      return (absoluteType == 2);
   return (absoluteType == 1 || absoluteType == 2);
  }

//+------------------------------------------------------------------+
string CCISignalTypeToString(const int signalType)
  {
   switch(signalType)
     {
      case CCI_SIGNAL_STRONG_BUY:  return "STRONG_BUY";
      case CCI_SIGNAL_BUY:         return "BUY";
      case CCI_SIGNAL_SELL:        return "SELL";
      case CCI_SIGNAL_STRONG_SELL: return "STRONG_SELL";
      default:                     return "NONE";
     }
  }

//+------------------------------------------------------------------+
string BuildCCIMainOrderComment(const string baseComment, const int signalType)
  {
   int absoluteType = (int)MathAbs(signalType);
   if(absoluteType == 2)
      return baseComment + " [CCI:S]";
   if(absoluteType == 1)
      return baseComment + " [CCI:N]";
   return baseComment;
  }

//+------------------------------------------------------------------+
bool GetCCISignal(const int side, int &signalType, datetime &signalTime)
  {
   signalType = 0;
   signalTime = 0;

   // ccicustomv3 menggunakan AsSeries=true, jadi:
   // index 0 = bar terbaru (running), index 1 = bar terakhir yang closed
   // Kita scan dari bar 1 sampai InpCciSignalValidityBars

   if(side == 1)  // Cari Buy signals
     {
      double strongBuyBuf[];
      double buyBuf[];
      ArraySetAsSeries(strongBuyBuf, true);
      ArraySetAsSeries(buyBuf, true);

      int copied1 = CopyBuffer(g_handles.cci, 4, 1, InpCciSignalValidityBars, strongBuyBuf);
      int copied2 = CopyBuffer(g_handles.cci, 5, 1, InpCciSignalValidityBars, buyBuf);
      if(copied1 <= 0 || copied2 <= 0)
        {
         Print("WARNING: Gagal copy buffer CCI Buy. Err=", GetLastError());
         return false;
        }

      int count = MathMin(copied1, copied2);
      for(int i = 0; i < count; i++)
        {
         if(strongBuyBuf[i] != EMPTY_VALUE && IsCCISignalTypeAllowed(CCI_SIGNAL_STRONG_BUY))
           {
            signalType = CCI_SIGNAL_STRONG_BUY;
            signalTime = iTime(_Symbol, _Period, i + 1);
            return true;
           }
         if(buyBuf[i] != EMPTY_VALUE && IsCCISignalTypeAllowed(CCI_SIGNAL_BUY))
           {
            signalType = CCI_SIGNAL_BUY;
            signalTime = iTime(_Symbol, _Period, i + 1);
            return true;
           }
        }
     }
   else if(side == -1)  // Cari Sell signals
     {
      double strongSellBuf[];
      double sellBuf[];
      ArraySetAsSeries(strongSellBuf, true);
      ArraySetAsSeries(sellBuf, true);

      int copied1 = CopyBuffer(g_handles.cci, 6, 1, InpCciSignalValidityBars, strongSellBuf);
      int copied2 = CopyBuffer(g_handles.cci, 7, 1, InpCciSignalValidityBars, sellBuf);
      if(copied1 <= 0 || copied2 <= 0)
        {
         Print("WARNING: Gagal copy buffer CCI Sell. Err=", GetLastError());
         return false;
        }

      int count = MathMin(copied1, copied2);
      for(int i = 0; i < count; i++)
        {
         if(strongSellBuf[i] != EMPTY_VALUE && IsCCISignalTypeAllowed(CCI_SIGNAL_STRONG_SELL))
           {
            signalType = CCI_SIGNAL_STRONG_SELL;
            signalTime = iTime(_Symbol, _Period, i + 1);
            return true;
           }
         if(sellBuf[i] != EMPTY_VALUE && IsCCISignalTypeAllowed(CCI_SIGNAL_SELL))
           {
            signalType = CCI_SIGNAL_SELL;
            signalTime = iTime(_Symbol, _Period, i + 1);
            return true;
           }
        }
     }

   return false;
  }

#endif // TS7_CCI_MQH
