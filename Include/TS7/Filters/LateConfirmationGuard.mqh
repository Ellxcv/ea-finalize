//+------------------------------------------------------------------+
//|                         TS7/Filters/LateConfirmationGuard.mqh     |
//|  Symmetric original-entry guard for the observed mask-5 pattern |
//+------------------------------------------------------------------+
#ifndef TS7_FILTERS_LATECONFIRMATIONGUARD_MQH
#define TS7_FILTERS_LATECONFIRMATIONGUARD_MQH

const int LATE_CONFIRMATION_GUARD_MASK = 5; // HiLo=1 + main SuperTrend=4

int      g_lateConfirmationGuardBlockedSignals = 0;
int      g_lateConfirmationGuardBlockedBuySignals = 0;
int      g_lateConfirmationGuardBlockedSellSignals = 0;
int      g_lateConfirmationGuardContextErrors = 0;
datetime g_lateConfirmationGuardLastBlockedBuySignal = 0;
datetime g_lateConfirmationGuardLastBlockedSellSignal = 0;
datetime g_lateConfirmationGuardLastErrorBuySignal = 0;
datetime g_lateConfirmationGuardLastErrorSellSignal = 0;

//+------------------------------------------------------------------+
void ResetLateConfirmationGuard()
  {
   g_lateConfirmationGuardBlockedSignals = 0;
   g_lateConfirmationGuardBlockedBuySignals = 0;
   g_lateConfirmationGuardBlockedSellSignals = 0;
   g_lateConfirmationGuardContextErrors = 0;
   g_lateConfirmationGuardLastBlockedBuySignal = 0;
   g_lateConfirmationGuardLastBlockedSellSignal = 0;
   g_lateConfirmationGuardLastErrorBuySignal = 0;
   g_lateConfirmationGuardLastErrorSellSignal = 0;
  }

//+------------------------------------------------------------------+
bool ValidateLateConfirmationGuardInputs()
  {
   if(!InpEnableLateConfirmationGuard)
      return true;

   if(!InpUseMainHiLoFilter ||
      !InpUseMainPsarFilter ||
      !InpUseMainSuperTrendFilter ||
      !InpEnableSTMTF)
     {
      Print("ERROR: Late confirmation guard requires HiLo, PSAR, main SuperTrend, ",
            "and SuperTrend MTF filters enabled.");
      return false;
     }

   if(InpSTFilterTF == PERIOD_CURRENT)
     {
      Print("ERROR: Late confirmation guard requires a dedicated SuperTrend MTF ",
            "timeframe, not PERIOD_CURRENT.");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
bool ValidateLateConfirmationGuardHandles()
  {
   if(!InpEnableLateConfirmationGuard)
      return true;

   if(g_handles.hilo == INVALID_HANDLE ||
      (g_handles.mainPSAR == INVALID_HANDLE && g_handles.psar == INVALID_HANDLE) ||
      (g_handles.mainSuperTrend == INVALID_HANDLE &&
       g_handles.superTrend == INVALID_HANDLE) ||
      g_handles.stFilter == INVALID_HANDLE)
     {
      Print("ERROR: Late confirmation guard cannot read all required indicator handles.");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
int LateConfirmationTrendState(const double value)
  {
   if(value == EMPTY_VALUE || !MathIsValidNumber(value))
      return 0;
   if(value == 1.0)
      return 1;
   if(value == -1.0)
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
int FindLateConfirmationLastClosedShift(const ENUM_TIMEFRAMES timeframe,
                                        const datetime observationTime)
  {
   ENUM_TIMEFRAMES resolvedTimeframe = (timeframe == PERIOD_CURRENT)
                                      ? (ENUM_TIMEFRAMES)_Period
                                      : timeframe;
   int periodSeconds = PeriodSeconds(resolvedTimeframe);
   if(observationTime <= 0 || periodSeconds <= 0)
      return -1;

   int shift = iBarShift(_Symbol, resolvedTimeframe, observationTime - 1, false);
   if(shift < 0)
      return -1;

   datetime barOpenTime = iTime(_Symbol, resolvedTimeframe, shift);
   if(barOpenTime <= 0)
      return -1;
   if(barOpenTime + periodSeconds > observationTime)
      shift++;

   return shift;
  }

//+------------------------------------------------------------------+
bool ReadLateConfirmationBufferState(const int handle,
                                     const int bufferIndex,
                                     const int shift,
                                     int &state)
  {
   state = 0;
   if(handle == INVALID_HANDLE || shift < 1)
      return false;

   double trendBuffer[1];
   if(CopyBuffer(handle, bufferIndex, shift, 1, trendBuffer) != 1)
      return false;

   state = LateConfirmationTrendState(trendBuffer[0]);
   return (state != 0);
  }

//+------------------------------------------------------------------+
bool ReadLateConfirmationPsarState(const int handle,
                                   const ENUM_TIMEFRAMES timeframe,
                                   const int shift,
                                   int &state)
  {
   state = 0;
   if(handle == INVALID_HANDLE || shift < 1)
      return false;

   ENUM_TIMEFRAMES resolvedTimeframe = (timeframe == PERIOD_CURRENT)
                                      ? (ENUM_TIMEFRAMES)_Period
                                      : timeframe;
   double psarBuffer[1];
   double closeBuffer[1];
   if(CopyBuffer(handle, 0, shift, 1, psarBuffer) != 1 ||
      CopyClose(_Symbol, resolvedTimeframe, shift, 1, closeBuffer) != 1)
      return false;
   if(psarBuffer[0] == EMPTY_VALUE ||
      !MathIsValidNumber(psarBuffer[0]) ||
      !MathIsValidNumber(closeBuffer[0]))
      return false;

   if(closeBuffer[0] > psarBuffer[0])
      state = 1;
   else if(closeBuffer[0] < psarBuffer[0])
      state = -1;

   return (state != 0);
  }

//+------------------------------------------------------------------+
bool BuildLateConfirmationSignalMask(const int direction,
                                     const datetime signalTime,
                                     int &mask,
                                     int &hiloAlign,
                                     int &psarAlign,
                                     int &superTrendAlign,
                                     int &stMtfAlign)
  {
   mask = 0;
   hiloAlign = 0;
   psarAlign = 0;
   superTrendAlign = 0;
   stMtfAlign = 0;
   if(direction == 0 || signalTime <= 0)
      return false;

   datetime signalCloseTime =
      signalTime + PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(signalCloseTime <= signalTime)
      return false;

   int mainPsarHandle = (g_handles.mainPSAR != INVALID_HANDLE
                         ? g_handles.mainPSAR : g_handles.psar);
   int mainSuperTrendHandle = (g_handles.mainSuperTrend != INVALID_HANDLE
                               ? g_handles.mainSuperTrend : g_handles.superTrend);
   ENUM_TIMEFRAMES mainPsarTimeframe =
      (g_handles.mainPSAR != INVALID_HANDLE
       ? InpMainPsarTimeframe : (ENUM_TIMEFRAMES)_Period);
   ENUM_TIMEFRAMES mainSuperTrendTimeframe =
      (g_handles.mainSuperTrend != INVALID_HANDLE
       ? InpMainSuperTrendTimeframe : (ENUM_TIMEFRAMES)_Period);

   int state = 0;
   int shift =
      FindLateConfirmationLastClosedShift((ENUM_TIMEFRAMES)_Period,
                                          signalCloseTime);
   if(!ReadLateConfirmationBufferState(g_handles.hilo, 8, shift, state))
      return false;
   hiloAlign = direction * state;

   shift =
      FindLateConfirmationLastClosedShift(mainPsarTimeframe, signalCloseTime);
   if(!ReadLateConfirmationPsarState(mainPsarHandle, mainPsarTimeframe,
                                    shift, state))
      return false;
   psarAlign = direction * state;

   shift =
      FindLateConfirmationLastClosedShift(mainSuperTrendTimeframe,
                                          signalCloseTime);
   if(!ReadLateConfirmationBufferState(mainSuperTrendHandle, 4, shift, state))
      return false;
   superTrendAlign = direction * state;

   shift =
      FindLateConfirmationLastClosedShift(InpSTFilterTF, signalCloseTime);
   if(!ReadLateConfirmationBufferState(g_handles.stFilter, 4, shift, state))
      return false;
   stMtfAlign = direction * state;

   if(hiloAlign != 1)
      mask |= 1;
   if(psarAlign != 1)
      mask |= 2;
   if(superTrendAlign != 1)
      mask |= 4;
   if(stMtfAlign != 1)
      mask |= 8;

   return true;
  }

//+------------------------------------------------------------------+
void RegisterLateConfirmationGuardContextError(const int direction,
                                               const datetime signalTime)
  {
   datetime lastErrorSignal = (direction > 0
                               ? g_lateConfirmationGuardLastErrorBuySignal
                               : g_lateConfirmationGuardLastErrorSellSignal);
   if(lastErrorSignal == signalTime)
      return;

   if(direction > 0)
      g_lateConfirmationGuardLastErrorBuySignal = signalTime;
   else
      g_lateConfirmationGuardLastErrorSellSignal = signalTime;
   g_lateConfirmationGuardContextErrors++;

   Print("WARNING: [LATE_CONFIRM_GUARD] Signal context not ready. Side=",
         (direction > 0 ? "BUY" : "SELL"),
         " SignalTime=", TimeToString(signalTime,
                                      TIME_DATE | TIME_MINUTES | TIME_SECONDS));
  }

//+------------------------------------------------------------------+
bool ShouldBlockLateConfirmationEntry(const int direction,
                                      const int cciSignalType,
                                      const datetime signalTime)
  {
   if(!InpEnableLateConfirmationGuard)
      return false;

   int mask = 0;
   int hiloAlign = 0;
   int psarAlign = 0;
   int superTrendAlign = 0;
   int stMtfAlign = 0;
   if(!BuildLateConfirmationSignalMask(direction, signalTime, mask,
                                       hiloAlign, psarAlign,
                                       superTrendAlign, stMtfAlign))
     {
      RegisterLateConfirmationGuardContextError(direction, signalTime);
      return true;
     }

   if(mask != LATE_CONFIRMATION_GUARD_MASK)
      return false;

   datetime lastBlockedSignal = (direction > 0
                                 ? g_lateConfirmationGuardLastBlockedBuySignal
                                 : g_lateConfirmationGuardLastBlockedSellSignal);
   if(lastBlockedSignal != signalTime)
     {
      if(direction > 0)
        {
         g_lateConfirmationGuardLastBlockedBuySignal = signalTime;
         g_lateConfirmationGuardBlockedBuySignals++;
        }
      else
        {
         g_lateConfirmationGuardLastBlockedSellSignal = signalTime;
         g_lateConfirmationGuardBlockedSellSignals++;
        }
      g_lateConfirmationGuardBlockedSignals++;

      Print("TS7_LATE_CONFIRMATION_GUARD_BLOCK",
            "|Side=", (direction > 0 ? "BUY" : "SELL"),
            "|SignalTime=", TimeToString(signalTime,
                                         TIME_DATE | TIME_MINUTES | TIME_SECONDS),
            "|CCIType=", CCISignalTypeToString(cciSignalType),
            "|Mask=", mask,
            "|HiLoSignalAlign=", hiloAlign,
            "|PsarSignalAlign=", psarAlign,
            "|SuperTrendSignalAlign=", superTrendAlign,
            "|STMTFSignalAlign=", stMtfAlign);
     }

   return true;
  }

//+------------------------------------------------------------------+
void PrintLateConfirmationGuardSummary()
  {
   if(!InpEnableLateConfirmationGuard)
      return;

   Print("TS7_LATE_CONFIRMATION_GUARD_SUMMARY",
         "|BlockedSignals=", g_lateConfirmationGuardBlockedSignals,
         "|BlockedBuySignals=", g_lateConfirmationGuardBlockedBuySignals,
         "|BlockedSellSignals=", g_lateConfirmationGuardBlockedSellSignals,
         "|ContextErrors=", g_lateConfirmationGuardContextErrors);
  }

#endif // TS7_FILTERS_LATECONFIRMATIONGUARD_MQH
