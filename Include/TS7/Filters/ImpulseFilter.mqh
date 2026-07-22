//+------------------------------------------------------------------+
//|                                  TS7/Filters/ImpulseFilter.mqh  |
//|                Original-entry adverse impulse confirmation      |
//+------------------------------------------------------------------+
#ifndef TS7_FILTERS_IMPULSE_FILTER_MQH
#define TS7_FILTERS_IMPULSE_FILTER_MQH

//+------------------------------------------------------------------+
bool ValidateImpulseGuardInputs()
  {
   if(!InpEnableImpulseGuard)
      return true;

   if(InpImpulseLookbackBars <= 0)
     {
      Print("ERROR: InpImpulseLookbackBars must be > 0.");
      return false;
     }

   if(InpImpulseAtrPeriod <= 0)
     {
      Print("ERROR: InpImpulseAtrPeriod must be > 0.");
      return false;
     }

   if(InpMaxAdverseImpulseAtr <= 0.0)
     {
      Print("ERROR: InpMaxAdverseImpulseAtr must be > 0.");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
void ResetImpulseGuardTelemetry()
  {
   g_impulseGuardChecks = 0;
   g_impulseGuardBlockedBuy = 0;
   g_impulseGuardBlockedSell = 0;
   g_impulseGuardDataErrors = 0;
  }

//+------------------------------------------------------------------+
void PrintImpulseGuardTelemetry()
  {
   if(!InpEnableImpulseGuard)
      return;

   Print("INFO: Impulse guard summary. Checks=", g_impulseGuardChecks,
         " BlockedBuy=", g_impulseGuardBlockedBuy,
         " BlockedSell=", g_impulseGuardBlockedSell,
         " DataErrors=", g_impulseGuardDataErrors);
  }

//+------------------------------------------------------------------+
bool IsOriginalEntryAllowedByImpulse(const int side,
                                     const datetime signalTime,
                                     bool &consumeSignal)
  {
   consumeSignal = false;
   if(!InpEnableImpulseGuard)
      return true;

   g_impulseGuardChecks++;

   if(side != 1 && side != -1)
     {
      g_impulseGuardDataErrors++;
      Print("ERROR: Invalid impulse guard side=", side);
      return false;
     }

   if(g_handles.impulseATR == INVALID_HANDLE)
     {
      g_impulseGuardDataErrors++;
      Print("WARNING: Original entry temporarily blocked: impulse ATR handle unavailable.");
      return false;
     }

   double atrBuf[1];
   ResetLastError();
   int copiedAtr = CopyBuffer(g_handles.impulseATR, 0, 1, 1, atrBuf);
   double latestClose = iClose(_Symbol, _Period, 1);
   double olderClose = iClose(_Symbol, _Period, InpImpulseLookbackBars + 1);

   if(copiedAtr != 1 || atrBuf[0] == EMPTY_VALUE || atrBuf[0] <= 0.0 ||
      !MathIsValidNumber(atrBuf[0]) || latestClose <= 0.0 || olderClose <= 0.0 ||
      !MathIsValidNumber(latestClose) || !MathIsValidNumber(olderClose))
     {
      g_impulseGuardDataErrors++;
      Print("WARNING: Original entry temporarily blocked: impulse data unavailable. Error=", GetLastError());
      return false;
     }

   double adverseMove = (side > 0)
                        ? MathMax(0.0, olderClose - latestClose)
                        : MathMax(0.0, latestClose - olderClose);
   double impulseRatio = adverseMove / atrBuf[0];
   if(impulseRatio <= InpMaxAdverseImpulseAtr)
      return true;

   consumeSignal = true;
   if(side > 0)
      g_impulseGuardBlockedBuy++;
   else
      g_impulseGuardBlockedSell++;

   Print("INFO: ", (side > 0 ? "BUY" : "SELL"),
         " signal rejected by adverse impulse guard. SignalTime=",
         TimeToString(signalTime, TIME_DATE|TIME_MINUTES),
         " Lookback=", InpImpulseLookbackBars,
         " LatestClose=", DoubleToString(latestClose, _Digits),
         " OlderClose=", DoubleToString(olderClose, _Digits),
         " AdverseMove=", DoubleToString(adverseMove, _Digits),
         " ATR=", DoubleToString(atrBuf[0], _Digits),
         " Ratio=", DoubleToString(impulseRatio, 2),
         " Limit=", DoubleToString(InpMaxAdverseImpulseAtr, 2));
   return false;
  }

#endif // TS7_FILTERS_IMPULSE_FILTER_MQH
