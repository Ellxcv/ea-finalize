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
bool ConfirmCCIMomentumExpansion(const int side,
                                 const int candidateSignalType,
                                 const datetime candidateSignalTime)
  {
   if(!InpCciRequireMomentumExpansion)
      return true;

   double cciBuf[];
   double ciBuf[];
   ArraySetAsSeries(cciBuf, true);
   ArraySetAsSeries(ciBuf, true);

   int copiedCci = CopyBuffer(g_handles.cci, 0, 1, 2, cciBuf);
   int copiedCi  = CopyBuffer(g_handles.cci, 3, 1, 2, ciBuf);
   if(copiedCci != 2 || copiedCi != 2)
     {
      Print("WARNING: Gagal copy CCI/CI momentum expansion buffers. Err=", GetLastError());
      return false;
     }

   for(int i = 0; i < 2; i++)
     {
      if(cciBuf[i] == EMPTY_VALUE || ciBuf[i] == EMPTY_VALUE ||
         !MathIsValidNumber(cciBuf[i]) || !MathIsValidNumber(ciBuf[i]))
        {
         PrintDebug("CCI signal blocked: momentum expansion value unavailable");
         return false;
        }
     }

   double currentDelta  = cciBuf[0] - ciBuf[0]; // Latest closed bar (bar 1)
   double previousDelta = cciBuf[1] - ciBuf[1]; // Previous closed bar (bar 2)
   bool expanding = ((side > 0 && currentDelta > 0.0 && currentDelta > previousDelta) ||
                     (side < 0 && currentDelta < 0.0 && currentDelta < previousDelta));

   if(!expanding)
     {
      PrintDebug(StringFormat("CCI signal blocked by momentum expansion: Type=%s SignalTime=%s Delta1=%.2f Delta2=%.2f",
                 CCISignalTypeToString(candidateSignalType),
                 TimeToString(candidateSignalTime, TIME_DATE|TIME_MINUTES),
                 currentDelta,
                 previousDelta));
     }

   return expanding;
  }

//+------------------------------------------------------------------+
bool AcceptCCISignalCandidate(const int side,
                              const int candidateSignalType,
                              const datetime candidateSignalTime,
                              int &signalType,
                              datetime &signalTime)
  {
   if(!ConfirmCCIMomentumExpansion(side, candidateSignalType, candidateSignalTime))
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
