//+------------------------------------------------------------------+
//|         TS7/Diagnostics/MarketStructureDiagnostics.mqh           |
//|   Confirmed-pivot S/R telemetry adapted from decisionDashboard   |
//+------------------------------------------------------------------+
#ifndef TS7_DIAGNOSTICS_MARKETSTRUCTUREDIAGNOSTICS_MQH
#define TS7_DIAGNOSTICS_MARKETSTRUCTUREDIAGNOSTICS_MQH

struct STS7StructurePoint
  {
   int    direction;
   double price;
  };

struct STS7MarketStructureSnapshot
  {
   bool            calculated;
   ENUM_TIMEFRAMES timeframe;
   int             trend;
   int             latestStructure;
   datetime        latestStructureTime;
   double          latestStructurePrice;
   bool            hasSupport;
   double          support;
   datetime        supportTime;
   int             supportType;
   int             supportAgeBars;
   bool            hasResistance;
   double          resistance;
   datetime        resistanceTime;
   int             resistanceType;
   int             resistanceAgeBars;
  };

//+------------------------------------------------------------------+
ENUM_TIMEFRAMES ResolveOriginalStructureTimeframe()
  {
   return (InpOriginalStructureTimeframe == PERIOD_CURRENT)
          ? (ENUM_TIMEFRAMES)_Period
          : InpOriginalStructureTimeframe;
  }

//+------------------------------------------------------------------+
string OriginalStructureCodeText(const int code)
  {
   if(code == 2)  return "HH";
   if(code == 1)  return "HL";
   if(code == -1) return "LH";
   if(code == -2) return "LL";
   return "NONE";
  }

//+------------------------------------------------------------------+
void ResetMarketStructureSnapshot(STS7MarketStructureSnapshot &snapshot)
  {
   snapshot.calculated = false;
   snapshot.timeframe = ResolveOriginalStructureTimeframe();
   snapshot.trend = 0;
   snapshot.latestStructure = 0;
   snapshot.latestStructureTime = 0;
   snapshot.latestStructurePrice = EMPTY_VALUE;
   snapshot.hasSupport = false;
   snapshot.support = EMPTY_VALUE;
   snapshot.supportTime = 0;
   snapshot.supportType = 0;
   snapshot.supportAgeBars = -1;
   snapshot.hasResistance = false;
   snapshot.resistance = EMPTY_VALUE;
   snapshot.resistanceTime = 0;
   snapshot.resistanceType = 0;
   snapshot.resistanceAgeBars = -1;
  }

//+------------------------------------------------------------------+
bool ValidateOriginalStructureDiagnosticInputs()
  {
   if(!InpEnableOriginalStructureDiagnostics)
      return true;

   if(!InpEnableOriginalTradeDiagnostics)
     {
      Print("ERROR: InpEnableOriginalStructureDiagnostics requires ",
            "InpEnableOriginalTradeDiagnostics=true.");
      return false;
     }
   if(InpOriginalStructureLeftBars < 1 ||
      InpOriginalStructureRightBars < 1 ||
      InpOriginalStructureHistoryBars < 100)
     {
      Print("ERROR: Invalid original structure diagnostics settings. ",
            "LeftBars and RightBars must be >= 1; HistoryBars must be >= 100.");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
bool IsOriginalStructurePivotHigh(const int pivotShift,
                                  const int count,
                                  const MqlRates &rates[])
  {
   if(pivotShift - InpOriginalStructureRightBars < 1 ||
      pivotShift + InpOriginalStructureLeftBars >= count)
      return false;

   double candidate = rates[pivotShift].high;
   for(int i = 1; i <= InpOriginalStructureLeftBars; i++)
      if(rates[pivotShift + i].high >= candidate)
         return false;
   for(int i = 1; i <= InpOriginalStructureRightBars; i++)
      if(rates[pivotShift - i].high > candidate)
         return false;
   return true;
  }

//+------------------------------------------------------------------+
bool IsOriginalStructurePivotLow(const int pivotShift,
                                 const int count,
                                 const MqlRates &rates[])
  {
   if(pivotShift - InpOriginalStructureRightBars < 1 ||
      pivotShift + InpOriginalStructureLeftBars >= count)
      return false;

   double candidate = rates[pivotShift].low;
   for(int i = 1; i <= InpOriginalStructureLeftBars; i++)
      if(rates[pivotShift + i].low <= candidate)
         return false;
   for(int i = 1; i <= InpOriginalStructureRightBars; i++)
      if(rates[pivotShift - i].low < candidate)
         return false;
   return true;
  }

//+------------------------------------------------------------------+
bool AcceptOriginalStructurePivot(const int direction,
                                  const double price,
                                  const STS7StructurePoint &points[])
  {
   int count = ArraySize(points);
   if(count == 0)
      return true;

   STS7StructurePoint last = points[count - 1];
   if(direction == -1 && last.direction == -1 && price > last.price)
      return false;
   if(direction == 1 && last.direction == 1 && price < last.price)
      return false;
   if(direction == -1 && last.direction == 1 && price > last.price)
      return false;
   if(direction == 1 && last.direction == -1 && price < last.price)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
bool FindPreviousOriginalStructurePoints(const int currentDirection,
                                         const STS7StructurePoint &points[],
                                         double &b,
                                         double &c,
                                         double &d,
                                         double &e)
  {
   int expected[4];
   expected[0] = -currentDirection;
   expected[1] = currentDirection;
   expected[2] = -currentDirection;
   expected[3] = currentDirection;

   double found[4];
   int wanted = 0;
   for(int i = ArraySize(points) - 1; i >= 0 && wanted < 4; i--)
     {
      if(points[i].direction == expected[wanted])
        {
         found[wanted] = points[i].price;
         wanted++;
        }
     }
   if(wanted < 4)
      return false;

   b = found[0];
   c = found[1];
   d = found[2];
   e = found[3];
   return true;
  }

//+------------------------------------------------------------------+
void PushOriginalStructurePoint(STS7StructurePoint &points[],
                                const int direction,
                                const double price)
  {
   int index = ArraySize(points);
   ArrayResize(points, index + 1);
   points[index].direction = direction;
   points[index].price = price;
  }

//+------------------------------------------------------------------+
bool CalculateOriginalMarketStructure(STS7MarketStructureSnapshot &snapshot)
  {
   ResetMarketStructureSnapshot(snapshot);

   ENUM_TIMEFRAMES timeframe = snapshot.timeframe;
   int requested = InpOriginalStructureHistoryBars +
                   InpOriginalStructureLeftBars +
                   InpOriginalStructureRightBars + 20;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, timeframe, 0, requested, rates);
   int required = InpOriginalStructureLeftBars +
                  InpOriginalStructureRightBars + 10;
   if(copied < required)
      return false;

   STS7StructurePoint points[];
   int oldestShift =
      MathMin(copied - InpOriginalStructureLeftBars -
              InpOriginalStructureRightBars - 1,
              InpOriginalStructureHistoryBars);
   double support = EMPTY_VALUE;
   double resistance = EMPTY_VALUE;
   int trend = 0;
   int latestStructure = 0;
   datetime latestStructureTime = 0;
   double latestStructurePrice = EMPTY_VALUE;
   datetime supportTime = 0;
   int supportType = 0;
   datetime resistanceTime = 0;
   int resistanceType = 0;

   // Stop at shift 1. A pivot at this step is confirmed only by closed bars
   // [1..RightBars], so the forming bar at shift 0 never enters the snapshot.
   for(int shift = oldestShift; shift >= 1; shift--)
     {
      int direction = 0;
      double pivotPrice = 0.0;
      int pivotShift = shift + InpOriginalStructureRightBars;
      bool pivotHigh = IsOriginalStructurePivotHigh(pivotShift, copied, rates);
      bool pivotLow = IsOriginalStructurePivotLow(pivotShift, copied, rates);
      if(pivotHigh)
        {
         direction = 1;
         pivotPrice = rates[pivotShift].high;
        }
      else if(pivotLow)
        {
         direction = -1;
         pivotPrice = rates[pivotShift].low;
        }

      int structureCode = 0;
      if(direction != 0 &&
         AcceptOriginalStructurePivot(direction, pivotPrice, points))
        {
         double b = 0.0;
         double c = 0.0;
         double d = 0.0;
         double e = 0.0;
         if(FindPreviousOriginalStructurePoints(direction, points, b, c, d, e))
           {
            if(pivotPrice > b && pivotPrice > c && c > b && c > d)
               structureCode = 2;
            else if(pivotPrice < b && pivotPrice < c && c < b && c < d)
               structureCode = -2;
            else if((pivotPrice >= c && b > c && b > d && d > c && d > e) ||
                    (pivotPrice < b && pivotPrice > c && b < d))
               structureCode = 1;
            else if((pivotPrice <= c && b < c && b < d && d < c && d < e) ||
                    (pivotPrice > b && pivotPrice < c && b > d))
               structureCode = -1;
           }

         PushOriginalStructurePoint(points, direction, pivotPrice);
         if(structureCode != 0)
           {
            latestStructure = structureCode;
            latestStructureTime = rates[pivotShift].time;
            latestStructurePrice = pivotPrice;
           }
         if(structureCode == -1)
           {
            resistance = pivotPrice;
            resistanceTime = rates[pivotShift].time;
            resistanceType = structureCode;
           }
         if(structureCode == 1)
           {
            support = pivotPrice;
            supportTime = rates[pivotShift].time;
            supportType = structureCode;
           }
        }

      if(resistance != EMPTY_VALUE && rates[shift].close > resistance)
         trend = 1;
      else if(support != EMPTY_VALUE && rates[shift].close < support)
         trend = -1;

      if((trend == 1 && structureCode == 2) ||
         (trend == -1 && structureCode == -1))
        {
         resistance = pivotPrice;
         resistanceTime = rates[pivotShift].time;
         resistanceType = structureCode;
        }
      if((trend == 1 && structureCode == 1) ||
         (trend == -1 && structureCode == -2))
        {
         support = pivotPrice;
         supportTime = rates[pivotShift].time;
         supportType = structureCode;
        }
     }

   snapshot.calculated = true;
   snapshot.trend = trend;
   snapshot.latestStructure = latestStructure;
   snapshot.latestStructureTime = latestStructureTime;
   snapshot.latestStructurePrice = latestStructurePrice;
   snapshot.hasSupport = (support != EMPTY_VALUE && MathIsValidNumber(support));
   snapshot.support = support;
   snapshot.supportTime = supportTime;
   snapshot.supportType = supportType;
   snapshot.hasResistance =
      (resistance != EMPTY_VALUE && MathIsValidNumber(resistance));
   snapshot.resistance = resistance;
   snapshot.resistanceTime = resistanceTime;
   snapshot.resistanceType = resistanceType;

   if(snapshot.hasSupport && supportTime > 0)
      snapshot.supportAgeBars = iBarShift(_Symbol, timeframe, supportTime, false);
   if(snapshot.hasResistance && resistanceTime > 0)
      snapshot.resistanceAgeBars =
         iBarShift(_Symbol, timeframe, resistanceTime, false);

   return true;
  }

#endif // TS7_DIAGNOSTICS_MARKETSTRUCTUREDIAGNOSTICS_MQH
