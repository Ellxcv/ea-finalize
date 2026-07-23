//+------------------------------------------------------------------+
//|                                      TS7/Core/HandleManager.mqh |
//|                      Indicator handle creation and release       |
//+------------------------------------------------------------------+
#ifndef TS7_CORE_HANDLE_MANAGER_MQH
#define TS7_CORE_HANDLE_MANAGER_MQH

bool CreateAllHandles(SHandles &handles)
  {
//--- CCI Custom v3: path "ccicustomv3\\ccicustomv3"
   handles.cci = iCustom(_Symbol, _Period, "cciCustomFix\\cciCustomFix",
                         InpCciLength, InpCiLength);
   if(handles.cci == INVALID_HANDLE)
     {
      Print("ERROR: Gagal buat handle ccicustomv3. Error=", GetLastError());
      return false;
     }

//--- HiLo v2: path "HiLov3\\HiLov2"
   handles.hilo = iCustom(_Symbol, _Period, "hiloFix\\hiloFix",
                          InpHiLoPeriod,
                          InpHiLoShift,
                          InpHiLoMethod,
                          "",
                          true,
                          2,
                          true,
                          "",
                          InpHiLoAtrPeriod
                          );
   if(handles.hilo == INVALID_HANDLE)
     {
      Print("ERROR: Gagal buat handle HiLov2. Error=", GetLastError());
      return false;
     }

//--- Parabolic SAR: path "parabolicSar\\parabolicSar"
   handles.psar = iCustom(_Symbol, _Period, "parabolicSarFix\\parabolicSarFix",
                          InpPsarStart, InpPsarIncrement, InpPsarMaximum);
   if(handles.psar == INVALID_HANDLE)
     {
      Print("ERROR: Gagal buat handle parabolicSarFix. Error=", GetLastError());
      return false;
     }

//--- Recovery Classic Zone dedicated ST+PSAR filter handles
   if(InpEnableRecovery && InpRecoveryMode == RECOVERY_MODE_CLASSIC_ZONE)
     {
      ENUM_TIMEFRAMES classicStTf = (InpRecoveryClassicStTimeframe == PERIOD_CURRENT)
                                    ? (ENUM_TIMEFRAMES)_Period
                                    : InpRecoveryClassicStTimeframe;
      handles.recoveryClassicST = iCustom(_Symbol, classicStTf, "superTrend\\superTrend",
                                          InpRecoveryClassicStAtrPeriod,
                                          InpRecoveryClassicStMultiplier,
                                          PRICE_MEDIAN,
                                          InpRecoveryClassicStAtrMethod);
      if(handles.recoveryClassicST == INVALID_HANDLE)
        {
         Print("WARNING: [CLASSIC_FILTER] Failed creating SuperTrend handle. Error=", GetLastError(),
               ". Fallback to main SuperTrend filter.");
        }
      else
        {
         Print("INFO: [CLASSIC_FILTER] SuperTrend configured. TF=", EnumToString(classicStTf),
               " ATR=", InpRecoveryClassicStAtrPeriod,
               " Mult=", DoubleToString(InpRecoveryClassicStMultiplier, 2),
               " Method=", (InpRecoveryClassicStAtrMethod ? "RMA" : "SMA"));
        }

      ENUM_TIMEFRAMES classicPsarTf = (InpRecoveryClassicPsarTimeframe == PERIOD_CURRENT)
                                      ? (ENUM_TIMEFRAMES)_Period
                                      : InpRecoveryClassicPsarTimeframe;
      handles.recoveryClassicPSAR = iCustom(_Symbol, classicPsarTf, "parabolicSarFix\\parabolicSarFix",
                                            InpRecoveryClassicPsarStart,
                                            InpRecoveryClassicPsarIncrement,
                                            InpRecoveryClassicPsarMaximum);
      if(handles.recoveryClassicPSAR == INVALID_HANDLE)
        {
         Print("WARNING: [CLASSIC_FILTER] Failed creating PSAR handle. Error=", GetLastError(),
               ". Fallback to main PSAR filter.");
        }
      else
        {
         Print("INFO: [CLASSIC_FILTER] PSAR configured. TF=", EnumToString(classicPsarTf),
               " Start=", DoubleToString(InpRecoveryClassicPsarStart, 3),
               " Increment=", DoubleToString(InpRecoveryClassicPsarIncrement, 3),
               " Max=", DoubleToString(InpRecoveryClassicPsarMaximum, 3));
        }
     }

//--- Recovery Distance dedicated ST+PSAR filter handles
   if(InpEnableRecovery && InpRecoveryMode == RECOVERY_MODE_DISTANCE)
     {
      ENUM_TIMEFRAMES distStTf = (InpRecoveryDistanceStTimeframe == PERIOD_CURRENT)
                                 ? (ENUM_TIMEFRAMES)_Period
                                 : InpRecoveryDistanceStTimeframe;
      handles.recoveryDistanceST = iCustom(_Symbol, distStTf, "superTrend\\superTrend",
                                           InpRecoveryDistanceStAtrPeriod,
                                           InpRecoveryDistanceStMultiplier,
                                           PRICE_MEDIAN,
                                           InpRecoveryDistanceStAtrMethod);
      if(handles.recoveryDistanceST == INVALID_HANDLE)
        {
         Print("WARNING: [DIST_FILTER] Failed creating SuperTrend handle. Error=", GetLastError(),
               ". Fallback to main SuperTrend filter.");
        }
      else
        {
         Print("INFO: [DIST_FILTER] SuperTrend configured. TF=", EnumToString(distStTf),
               " ATR=", InpRecoveryDistanceStAtrPeriod,
               " Mult=", DoubleToString(InpRecoveryDistanceStMultiplier, 2),
               " Method=", (InpRecoveryDistanceStAtrMethod ? "RMA" : "SMA"));
        }

      ENUM_TIMEFRAMES distPsarTf = (InpRecoveryDistancePsarTimeframe == PERIOD_CURRENT)
                                   ? (ENUM_TIMEFRAMES)_Period
                                   : InpRecoveryDistancePsarTimeframe;
      handles.recoveryDistancePSAR = iCustom(_Symbol, distPsarTf, "parabolicSarFix\\parabolicSarFix",
                                             InpRecoveryDistancePsarStart,
                                             InpRecoveryDistancePsarIncrement,
                                             InpRecoveryDistancePsarMaximum);
      if(handles.recoveryDistancePSAR == INVALID_HANDLE)
        {
         Print("WARNING: [DIST_FILTER] Failed creating PSAR handle. Error=", GetLastError(),
               ". Fallback to main PSAR filter.");
        }
      else
        {
         Print("INFO: [DIST_FILTER] PSAR configured. TF=", EnumToString(distPsarTf),
               " Start=", DoubleToString(InpRecoveryDistancePsarStart, 3),
               " Increment=", DoubleToString(InpRecoveryDistancePsarIncrement, 3),
               " Max=", DoubleToString(InpRecoveryDistancePsarMaximum, 3));
        }
     }

//--- SuperTrend: path "superTrend\\superTrend"
   handles.superTrend = iCustom(_Symbol, _Period, "superTrend\\superTrend",
                                InpSuperTrendAtrPeriod,
                                InpSuperTrendMultiplier,
                                PRICE_MEDIAN,
                                InpSuperTrendChangeAtrMethod
                                );
   if(handles.superTrend == INVALID_HANDLE)
     {
      Print("ERROR: Gagal buat handle superTrend. Error=", GetLastError());
      return false;
     }

//--- Main strategy dedicated SuperTrend/PSAR handles (custom timeframe)
   ENUM_TIMEFRAMES mainStTf = (InpMainSuperTrendTimeframe == PERIOD_CURRENT)
                              ? (ENUM_TIMEFRAMES)_Period
                              : InpMainSuperTrendTimeframe;
   handles.mainSuperTrend = iCustom(_Symbol, mainStTf, "superTrend\\superTrend",
                                    InpSuperTrendAtrPeriod,
                                    InpSuperTrendMultiplier,
                                    PRICE_MEDIAN,
                                    InpSuperTrendChangeAtrMethod);
   if(handles.mainSuperTrend == INVALID_HANDLE)
     {
      Print("WARNING: Failed creating main SuperTrend handle. Error=", GetLastError(),
            ". Main signal will fallback to default SuperTrend handle.");
     }

   ENUM_TIMEFRAMES mainPsarTf = (InpMainPsarTimeframe == PERIOD_CURRENT)
                                ? (ENUM_TIMEFRAMES)_Period
                                : InpMainPsarTimeframe;
   handles.mainPSAR = iCustom(_Symbol, mainPsarTf, "parabolicSarFix\\parabolicSarFix",
                              InpPsarStart, InpPsarIncrement, InpPsarMaximum);
   if(handles.mainPSAR == INVALID_HANDLE)
     {
      Print("WARNING: Failed creating main PSAR handle. Error=", GetLastError(),
            ". Main signal will fallback to default PSAR handle.");
     }

//--- Recovery ATR handle (hanya buat jika mode ATR)
   if(InpEnableRecovery && InpRecoveryZoneMode == RECOVERY_ZONE_ATR)
     {
      handles.recoveryATR = iATR(_Symbol, InpRecoveryAtrTimeframe, InpRecoveryAtrPeriod);
      if(handles.recoveryATR == INVALID_HANDLE)
        {
         Print("WARNING: Gagal buat handle Recovery ATR. Error=", GetLastError(),
               ". Recovery akan fallback ke mode Fixed.");
        }
     }

//--- Recovery GRID ATR handle (hanya buat jika GRID step mode ATR)
   if(InpEnableRecovery && InpRecoveryMode == RECOVERY_MODE_GRID && InpRecoveryGridStepMode == GRID_STEP_ATR)
     {
      handles.recoveryGridATR = iATR(_Symbol, InpRecoveryGridAtrTimeframe, InpRecoveryGridAtrPeriod);
      if(handles.recoveryGridATR == INVALID_HANDLE)
        {
         Print("WARNING: Gagal buat handle Recovery GRID ATR. Error=", GetLastError(),
               ". Grid step akan fallback ke Fixed.");
        }
     }

//--- Distance signal source: AlgoZone handle
   if(InpEnableRecovery && InpRecoveryMode == RECOVERY_MODE_DISTANCE &&
      InpRecoveryDistanceSignalSource == DIST_SIGNAL_ALGOZONE)
     {
      handles.algoZone = iCustom(_Symbol, _Period, "algoZone\\algoZone");
      if(handles.algoZone == INVALID_HANDLE)
        {
         Print("WARNING: Gagal buat handle AlgoZone. Error=", GetLastError(),
               ". Distance signal akan fallback ke ST+PSAR.");
        }
     }

//--- Distance signal source: Basic EMA handles
   if(InpEnableRecovery && InpRecoveryMode == RECOVERY_MODE_DISTANCE &&
      InpRecoveryDistanceSignalSource == DIST_SIGNAL_BASIC_EMA)
     {
      handles.distEmaFast = iMA(_Symbol, _Period, InpRecoveryBasicEmaFast, 0, MODE_EMA, PRICE_CLOSE);
      handles.distEmaSlow = iMA(_Symbol, _Period, InpRecoveryBasicEmaSlow, 0, MODE_EMA, PRICE_CLOSE);
      if(handles.distEmaFast == INVALID_HANDLE || handles.distEmaSlow == INVALID_HANDLE)
        {
         Print("WARNING: Gagal buat handle Basic EMA. Error=", GetLastError(),
               ". Distance signal akan fallback ke ST+PSAR.");
        }
     }

//--- ADX handle (built-in, only if ADX filter enabled)
   if(InpEnableAdxFilter)
     {
      ENUM_TIMEFRAMES adxTf = (InpAdxTimeframe == PERIOD_CURRENT)
                              ? (ENUM_TIMEFRAMES)_Period
                              : InpAdxTimeframe;
      handles.adx = iADX(_Symbol, adxTf, InpAdxDmiPeriod);
      if(handles.adx == INVALID_HANDLE)
        {
         Print("WARNING: Gagal buat handle ADX built-in. Error=", GetLastError(),
               ". Filter ADX akan dinonaktifkan.");
        }
      else
        {
         g_adxDirectionalBias = 0;
         g_adxBiasLastBarTime = 0;
         Print("INFO: ADX filter active. TF=", EnumToString(adxTf),
               " DMI=", InpAdxDmiPeriod,
               " Smoothing=", (InpAdxEnableSmoothing ? "ON" : "OFF"),
               " SmoothPeriod=", InpAdxSmoothing,
               " Threshold=", DoubleToString(InpAdxThreshold, 2));
        }
      }

//--- SuperTrend MTF Filter handle
   if(InpEnableSTMTF && InpSTFilterTF != PERIOD_CURRENT)
     {
      handles.stFilter = iCustom(_Symbol, InpSTFilterTF, "superTrend\\superTrend",
                                 InpSTFilterATRPeriod,
                                 InpSTFilterATRMult,
                                 PRICE_MEDIAN,
                                 InpSTFilterATRMethod);
      if(handles.stFilter == INVALID_HANDLE)
        {
         Print("WARNING: Gagal buat handle SuperTrend MTF (", EnumToString(InpSTFilterTF),
               "). Error=", GetLastError(), ". Filter MTF dinonaktifkan.");
        }
      else
        {
         Print("INFO: SuperTrend MTF filter active. TF=", EnumToString(InpSTFilterTF),
               " ATR=", InpSTFilterATRPeriod, " Mult=", InpSTFilterATRMult);
        }
     }

//--- Observation-only ATR snapshot for original-trade diagnostics
   if(InpEnableOriginalTradeDiagnostics)
     {
      int diagnosticAtrPeriod = MathMax(1, InpOriginalDiagAtrPeriod);
      handles.originalDiagATR = iATR(_Symbol, _Period, diagnosticAtrPeriod);
      if(handles.originalDiagATR == INVALID_HANDLE)
        {
         Print("WARNING: [ORIGINAL_DIAG] Failed creating ATR handle. Error=", GetLastError(),
               ". MFE/MAE logging remains active with EntryATRPoints=0.");
        }
     }

   return true;
  }

void ReleaseAllHandles(SHandles &handles)
  {
   if(handles.accountStatus != INVALID_HANDLE) { IndicatorRelease(handles.accountStatus); handles.accountStatus = INVALID_HANDLE; }
   if(handles.cci != INVALID_HANDLE)        { IndicatorRelease(handles.cci);        handles.cci = INVALID_HANDLE; }
   if(handles.hilo != INVALID_HANDLE)       { IndicatorRelease(handles.hilo);       handles.hilo = INVALID_HANDLE; }
   if(handles.psar != INVALID_HANDLE)       { IndicatorRelease(handles.psar);       handles.psar = INVALID_HANDLE; }
   if(handles.superTrend != INVALID_HANDLE) { IndicatorRelease(handles.superTrend); handles.superTrend = INVALID_HANDLE; }
   if(handles.mainPSAR != INVALID_HANDLE)   { IndicatorRelease(handles.mainPSAR);   handles.mainPSAR = INVALID_HANDLE; }
   if(handles.mainSuperTrend != INVALID_HANDLE) { IndicatorRelease(handles.mainSuperTrend); handles.mainSuperTrend = INVALID_HANDLE; }
   if(handles.recoveryClassicPSAR != INVALID_HANDLE) { IndicatorRelease(handles.recoveryClassicPSAR); handles.recoveryClassicPSAR = INVALID_HANDLE; }
   if(handles.recoveryClassicST != INVALID_HANDLE)   { IndicatorRelease(handles.recoveryClassicST);   handles.recoveryClassicST = INVALID_HANDLE; }
   if(handles.recoveryDistancePSAR != INVALID_HANDLE) { IndicatorRelease(handles.recoveryDistancePSAR); handles.recoveryDistancePSAR = INVALID_HANDLE; }
   if(handles.recoveryDistanceST != INVALID_HANDLE)   { IndicatorRelease(handles.recoveryDistanceST);   handles.recoveryDistanceST = INVALID_HANDLE; }
   if(handles.recoveryATR != INVALID_HANDLE) { IndicatorRelease(handles.recoveryATR); handles.recoveryATR = INVALID_HANDLE; }
   if(handles.recoveryGridATR != INVALID_HANDLE) { IndicatorRelease(handles.recoveryGridATR); handles.recoveryGridATR = INVALID_HANDLE; }
   if(handles.adx != INVALID_HANDLE)         { IndicatorRelease(handles.adx);         handles.adx = INVALID_HANDLE; }
   if(handles.stFilter != INVALID_HANDLE)    { IndicatorRelease(handles.stFilter);    handles.stFilter = INVALID_HANDLE; }
   if(handles.algoZone != INVALID_HANDLE)    { IndicatorRelease(handles.algoZone);    handles.algoZone = INVALID_HANDLE; }
   if(handles.distEmaFast != INVALID_HANDLE) { IndicatorRelease(handles.distEmaFast); handles.distEmaFast = INVALID_HANDLE; }
   if(handles.distEmaSlow != INVALID_HANDLE) { IndicatorRelease(handles.distEmaSlow); handles.distEmaSlow = INVALID_HANDLE; }
   if(handles.originalDiagATR != INVALID_HANDLE) { IndicatorRelease(handles.originalDiagATR); handles.originalDiagATR = INVALID_HANDLE; }
  }

#endif // TS7_CORE_HANDLE_MANAGER_MQH
