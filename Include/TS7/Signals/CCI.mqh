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
bool ConfirmCurrentCCIAlignment(const int side,
                                const int candidateSignalType,
                                const datetime candidateSignalTime)
  {
   if(!InpCciRequireCurrentAlignment)
      return true;

   double currentCciBuf[];
   double currentCiBuf[];
   ArraySetAsSeries(currentCciBuf, true);
   ArraySetAsSeries(currentCiBuf, true);

   int copiedCci = CopyBuffer(g_handles.cci, 0, 1, 1, currentCciBuf);
   int copiedCi  = CopyBuffer(g_handles.cci, 3, 1, 1, currentCiBuf);
   if(copiedCci != 1 || copiedCi != 1)
     {
      Print("WARNING: Gagal copy current closed CCI/CI alignment. Err=", GetLastError());
      return false;
     }

   double currentCci = currentCciBuf[0];
   double currentCi  = currentCiBuf[0];
   if(currentCci == EMPTY_VALUE || currentCi == EMPTY_VALUE ||
      !MathIsValidNumber(currentCci) || !MathIsValidNumber(currentCi))
     {
      PrintDebug("CCI signal blocked: current closed CCI/CI value unavailable");
      return false;
     }

   bool aligned = ((side > 0 && currentCci > currentCi) ||
                   (side < 0 && currentCci < currentCi));
   if(!aligned)
     {
      PrintDebug(StringFormat("CCI signal blocked by current alignment: Type=%s SignalTime=%s CCI=%.2f CI=%.2f",
                 CCISignalTypeToString(candidateSignalType),
                 TimeToString(candidateSignalTime, TIME_DATE|TIME_MINUTES),
                 currentCci,
                 currentCi));
     }

   return aligned;
  }

//+------------------------------------------------------------------+
bool AcceptCCISignalCandidate(const int side,
                              const int candidateSignalType,
                              const datetime candidateSignalTime,
                              int &signalType,
                              datetime &signalTime)
  {
   if(!ConfirmCurrentCCIAlignment(side, candidateSignalType, candidateSignalTime))
      return false;

   signalType = candidateSignalType;
   signalTime = candidateSignalTime;
   return true;
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
            datetime candidateTime = iTime(_Symbol, _Period, i + 1);
            return AcceptCCISignalCandidate(side,
                                            CCI_SIGNAL_STRONG_BUY,
                                            candidateTime,
                                            signalType,
                                            signalTime);
           }
         if(buyBuf[i] != EMPTY_VALUE && IsCCISignalTypeAllowed(CCI_SIGNAL_BUY))
           {
            datetime candidateTime = iTime(_Symbol, _Period, i + 1);
            return AcceptCCISignalCandidate(side,
                                            CCI_SIGNAL_BUY,
                                            candidateTime,
                                            signalType,
                                            signalTime);
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
            datetime candidateTime = iTime(_Symbol, _Period, i + 1);
            return AcceptCCISignalCandidate(side,
                                            CCI_SIGNAL_STRONG_SELL,
                                            candidateTime,
                                            signalType,
                                            signalTime);
           }
         if(sellBuf[i] != EMPTY_VALUE && IsCCISignalTypeAllowed(CCI_SIGNAL_SELL))
           {
            datetime candidateTime = iTime(_Symbol, _Period, i + 1);
            return AcceptCCISignalCandidate(side,
                                            CCI_SIGNAL_SELL,
                                            candidateTime,
                                            signalType,
                                            signalTime);
           }
        }
     }

   return false;
  }

#endif // TS7_CCI_MQH
