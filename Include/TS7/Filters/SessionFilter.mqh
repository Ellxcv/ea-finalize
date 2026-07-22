//+------------------------------------------------------------------+
//|                                                   TS7/SessionFilter.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_SESSIONFILTER_MQH
#define TS7_SESSIONFILTER_MQH

//+------------------------------------------------------------------+
bool IsWithinAnySession()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int currentMinutes = dt.hour * 60 + dt.min;

   bool anyEnabled = false;

   if(InpEnableAsiaSession)
     {
      anyEnabled = true;
      if(IsInSession(currentMinutes,
                     InpAsiaStartHour * 60 + InpAsiaStartMinute,
                     InpAsiaEndHour * 60 + InpAsiaEndMinute))
         return true;
     }

   if(InpEnableLondonSession)
     {
      anyEnabled = true;
      if(IsInSession(currentMinutes,
                     InpLondonStartHour * 60 + InpLondonStartMinute,
                     InpLondonEndHour * 60 + InpLondonEndMinute))
         return true;
     }

   if(InpEnableNewYorkSession)
     {
      anyEnabled = true;
      if(IsInSession(currentMinutes,
                     InpNewYorkStartHour * 60 + InpNewYorkStartMinute,
                     InpNewYorkEndHour * 60 + InpNewYorkEndMinute))
         return true;
     }

   // Jika tidak ada session yang dienable, return true (pass through)
   if(!anyEnabled)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsInSession(const int currentMinutes, const int startMinutes, const int endMinutes)
  {
   if(startMinutes <= endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   else
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
  }

#endif // TS7_SESSIONFILTER_MQH
