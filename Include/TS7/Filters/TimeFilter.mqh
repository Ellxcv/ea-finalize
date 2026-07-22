//+------------------------------------------------------------------+
//|                                                   TS7/TimeFilter.mqh |
//+------------------------------------------------------------------+
#ifndef TS7_TIMEFILTER_MQH
#define TS7_TIMEFILTER_MQH

//+------------------------------------------------------------------+
bool IsWithinTimeWindow()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes   = InpStartHour * 60 + InpStartMinute;
   int endMinutes     = InpEndHour * 60 + InpEndMinute;

   // Handle overnight wrap (misalnya start=22:00, end=06:00)
   if(startMinutes <= endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   else
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
  }

#endif // TS7_TIMEFILTER_MQH
