//+------------------------------------------------------------------+
//|                                                    TS7/Utils.mqh |
//|                         Shared helper functions for TS7          |
//+------------------------------------------------------------------+
#ifndef TS7_UTILS_MQH
#define TS7_UTILS_MQH

//+------------------------------------------------------------------+
//| Detect New Bar (candle close)                                    |
//+------------------------------------------------------------------+
bool IsNewBar()
  {
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == 0)
      return false;

   if(currentBarTime != g_lastBarTime)
     {
      g_lastBarTime = currentBarTime;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Debug Print (only prints to journal for monitoring)              |
//+------------------------------------------------------------------+
void PrintDebug(const string msg)
  {
#ifdef _DEBUG
   Print("DEBUG: ", msg);
#endif
   // Untuk release mode, uncomment baris di bawah jika butuh log tambahan:
   // Print("DEBUG: ", msg);
  }

//+------------------------------------------------------------------+
//| Round lot to nearest valid volume step (standard rounding)       |
//+------------------------------------------------------------------+
double RoundLotToStep(const double rawLot)
  {
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double volumeMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double volumeMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(volumeStep <= 0.0)
      volumeStep = 0.01;

   double lot = MathRound(rawLot / volumeStep) * volumeStep;
   // Clamp to valid range
   if(lot < volumeMin) lot = volumeMin;
   if(lot > volumeMax) lot = volumeMax;

   // Fix floating point precision
   int digits = (int)MathCeil(-MathLog10(volumeStep));
   return NormalizeDouble(lot, digits);
  }

#endif // TS7_UTILS_MQH
