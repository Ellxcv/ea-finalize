//+------------------------------------------------------------------+
//|                              TS7/Filters/CciStaleBreakout.mqh  |
//|                Price confirmation for stale CCI signals         |
//+------------------------------------------------------------------+
#ifndef TS7_FILTERS_CCI_STALE_BREAKOUT_MQH
#define TS7_FILTERS_CCI_STALE_BREAKOUT_MQH

//+------------------------------------------------------------------+
void ResetCciStaleBreakoutTelemetry()
  {
   g_cciStaleBreakoutChecks = 0;
   g_cciStaleBreakoutFreshAllowed = 0;
   g_cciStaleBreakoutConfirmedBuy = 0;
   g_cciStaleBreakoutConfirmedSell = 0;
   g_cciStaleBreakoutWaitingBuy = 0;
   g_cciStaleBreakoutWaitingSell = 0;
   g_cciStaleBreakoutDataErrors = 0;
  }

//+------------------------------------------------------------------+
void PrintCciStaleBreakoutTelemetry()
  {
   if(!InpEnableCciStaleBreakoutConfirm)
      return;

   Print("INFO: CCI stale breakout summary. Checks=", g_cciStaleBreakoutChecks,
         " FreshAllowed=", g_cciStaleBreakoutFreshAllowed,
         " ConfirmedBuy=", g_cciStaleBreakoutConfirmedBuy,
         " ConfirmedSell=", g_cciStaleBreakoutConfirmedSell,
         " WaitingBuy=", g_cciStaleBreakoutWaitingBuy,
         " WaitingSell=", g_cciStaleBreakoutWaitingSell,
         " DataErrors=", g_cciStaleBreakoutDataErrors);
  }

//+------------------------------------------------------------------+
bool IsCCIEntryAllowedByStaleBreakout(const int side,
                                      const datetime signalTime)
  {
   if(!InpEnableCciStaleBreakoutConfirm)
      return true;

   g_cciStaleBreakoutChecks++;

   if(side != 1 && side != -1)
     {
      g_cciStaleBreakoutDataErrors++;
      Print("ERROR: Invalid CCI stale breakout side=", side);
      return false;
     }

   ResetLastError();
   int signalShift = iBarShift(_Symbol, _Period, signalTime, true);
   if(signalShift < 1)
     {
      g_cciStaleBreakoutDataErrors++;
      Print("WARNING: CCI entry temporarily blocked: signal candle unavailable. SignalTime=",
            TimeToString(signalTime, TIME_DATE|TIME_MINUTES),
            " Error=", GetLastError());
      return false;
     }

   if(signalShift == 1)
     {
      g_cciStaleBreakoutFreshAllowed++;
      return true;
     }

   double latestClose = iClose(_Symbol, _Period, 1);
   double signalExtreme = (side > 0)
                          ? iHigh(_Symbol, _Period, signalShift)
                          : iLow(_Symbol, _Period, signalShift);
   if(latestClose <= 0.0 || signalExtreme <= 0.0 ||
      !MathIsValidNumber(latestClose) || !MathIsValidNumber(signalExtreme))
     {
      g_cciStaleBreakoutDataErrors++;
      Print("WARNING: CCI entry temporarily blocked: breakout price unavailable. SignalTime=",
            TimeToString(signalTime, TIME_DATE|TIME_MINUTES),
            " Age=", signalShift,
            " Error=", GetLastError());
      return false;
     }

   bool confirmed = ((side > 0 && latestClose > signalExtreme) ||
                     (side < 0 && latestClose < signalExtreme));
   if(confirmed)
     {
      if(side > 0)
         g_cciStaleBreakoutConfirmedBuy++;
      else
         g_cciStaleBreakoutConfirmedSell++;

      Print("INFO: ", (side > 0 ? "BUY" : "SELL"),
            " stale CCI signal confirmed by price breakout. SignalTime=",
            TimeToString(signalTime, TIME_DATE|TIME_MINUTES),
            " Age=", signalShift,
            " LatestClose=", DoubleToString(latestClose, _Digits),
            " SignalExtreme=", DoubleToString(signalExtreme, _Digits));
      return true;
     }

   if(side > 0)
      g_cciStaleBreakoutWaitingBuy++;
   else
      g_cciStaleBreakoutWaitingSell++;

   Print("INFO: ", (side > 0 ? "BUY" : "SELL"),
         " stale CCI signal waiting for price breakout. SignalTime=",
         TimeToString(signalTime, TIME_DATE|TIME_MINUTES),
         " Age=", signalShift,
         " LatestClose=", DoubleToString(latestClose, _Digits),
         " Required=", (side > 0 ? "> " : "< "),
         DoubleToString(signalExtreme, _Digits));
   return false;
  }

#endif // TS7_FILTERS_CCI_STALE_BREAKOUT_MQH
