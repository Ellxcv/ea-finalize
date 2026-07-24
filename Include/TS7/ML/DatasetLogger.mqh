//+------------------------------------------------------------------+
//|                               TS7/ML/DatasetLogger.mqh           |
//|       Observation-only entry candidate and outcome dataset      |
//+------------------------------------------------------------------+
#ifndef TS7_ML_DATASET_LOGGER_MQH
#define TS7_ML_DATASET_LOGGER_MQH

const string TS7_ML_SCHEMA_VERSION = "ts7_entry_candidate_v2";
const int    TS7_ML_BARRIER_ATR_PERIOD = 14;
const int    TS7_ML_PRIMARY_HORIZON = 50;
const int    TS7_ML_SENSITIVITY_HORIZON = 40;

struct SMlBarrierRecord
  {
   bool     active;
   string   setupId;
   int      direction;
   datetime candidateTime;
   datetime candidateBarTime;
   double   referencePrice;
   double   atrPrice;
   double   favorablePrice;
   double   adversePrice;
   bool     horizon40Done;
   bool     horizon50Done;
  };

struct SMlTradeLink
  {
   bool     activeCycle;
   string   setupId;
   string   cycleId;
   long     positionId;
   int      direction;
   datetime entryTime;
   double   entryPrice;
   double   volume;
   double   mfePoints;
   double   maePoints;
   datetime originalCloseTime;
   double   originalNetProfit;
   bool     originalClosed;
   bool     recoveryStarted;
   int      recoveryEntries;
   int      maxRecoveryLevel;
   double   recoveryNetProfit;
  };

struct SMlRecoveryPositionLink
  {
   long positionId;
   int  tradeIndex;
  };

struct SMlCandidateState
  {
   string setupId;
   int    orderAttempts;
  };

int g_mlCandidateFile = INVALID_HANDLE;
int g_mlTradeEntryFile = INVALID_HANDLE;
int g_mlTradeOutcomeFile = INVALID_HANDLE;
int g_mlCycleOutcomeFile = INVALID_HANDLE;
int g_mlBarrierOutcomeFile = INVALID_HANDLE;
int g_mlManifestFile = INVALID_HANDLE;

string g_mlRunId = "";
string g_mlRunDirectory = "";
bool   g_mlLoggerReady = false;
int    g_mlRecordsSinceFlush = 0;
int    g_mlCandidateCount = 0;
int    g_mlOrderAttemptCount = 0;
int    g_mlTradeOutcomeCount = 0;
int    g_mlCycleOutcomeCount = 0;
int    g_mlBarrierOutcomeCount = 0;
int    g_mlDataErrors = 0;
int    g_mlCurrentRecoveryTradeIndex = -1;

string g_mlPendingSetupId = "";
int    g_mlPendingDirection = 0;
ulong  g_mlObservedOriginalEntryDeal = 0;
long   g_mlObservedOriginalPositionId = 0;

SMlBarrierRecord g_mlBarrierRecords[];
SMlTradeLink     g_mlTradeLinks[];
SMlRecoveryPositionLink g_mlRecoveryPositionLinks[];
SMlCandidateState g_mlCandidateStates[];

//+------------------------------------------------------------------+
string MlBoolText(const bool value)
  {
   return value ? "true" : "false";
  }

//+------------------------------------------------------------------+
string MlTimeText(const datetime value)
  {
   if(value <= 0)
      return "NA";
   return TimeToString(value, TIME_DATE | TIME_MINUTES | TIME_SECONDS);
  }

//+------------------------------------------------------------------+
string MlDoubleText(const double value, const int digits, const bool ready = true)
  {
   if(!ready || !MathIsValidNumber(value))
      return "NA";
   return DoubleToString(value, digits);
  }

//+------------------------------------------------------------------+
string MlLongText(const long value)
  {
   return StringFormat("%I64d", value);
  }

//+------------------------------------------------------------------+
bool MlActiveSessionDistances(const int currentMinutes,
                              const int startMinutes,
                              const int endMinutes,
                              int &minutesFromOpen,
                              int &minutesToClose)
  {
   minutesFromOpen = -1;
   minutesToClose = -1;
   if(!IsInSession(currentMinutes, startMinutes, endMinutes))
      return false;

   int duration = (endMinutes - startMinutes + 1440) % 1440;
   if(duration == 0)
      duration = 1440;
   minutesFromOpen = (currentMinutes - startMinutes + 1440) % 1440;
   minutesToClose = MathMax(0, duration - minutesFromOpen);
   return true;
  }

//+------------------------------------------------------------------+
string MlCsvEscape(const string value)
  {
   string output = value;
   bool quote = (StringFind(output, ",") >= 0 ||
                 StringFind(output, "\"") >= 0 ||
                 StringFind(output, "\r") >= 0 ||
                 StringFind(output, "\n") >= 0);
   StringReplace(output, "\"", "\"\"");
   return quote ? "\"" + output + "\"" : output;
  }

//+------------------------------------------------------------------+
string MlJsonEscape(const string value)
  {
   string output = value;
   StringReplace(output, "\\", "\\\\");
   StringReplace(output, "\"", "\\\"");
   StringReplace(output, "\r", "\\r");
   StringReplace(output, "\n", "\\n");
   StringReplace(output, "\t", "\\t");
   return output;
  }

//+------------------------------------------------------------------+
string MlSanitizePathPart(const string value)
  {
   string output = "";
   for(int i = 0; i < StringLen(value); i++)
     {
      ushort ch = (ushort)StringGetCharacter(value, i);
      bool allowed = ((ch >= '0' && ch <= '9') ||
                      (ch >= 'A' && ch <= 'Z') ||
                      (ch >= 'a' && ch <= 'z') ||
                      ch == '_' || ch == '-');
      output += allowed ? StringSubstr(value, i, 1) : "-";
     }
   while(StringFind(output, "--") >= 0)
      StringReplace(output, "--", "-");
   return output;
  }

//+------------------------------------------------------------------+
string MlAutoRunId()
  {
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   string timestamp = StringFormat("%04d%02d%02dT%02d%02d%02d",
                                   dt.year, dt.mon, dt.day,
                                   dt.hour, dt.min, dt.sec);
   return MlSanitizePathPart(InpMlStrategyVersion) + "_" +
          MlSanitizePathPart(_Symbol) + "_M1_" + timestamp + "_" +
          MlLongText((long)GetMicrosecondCount());
  }

//+------------------------------------------------------------------+
bool MlValidateLoggerInputs()
  {
   if(!InpEnableMlDatasetLogger)
      return true;
   if(_Period != PERIOD_M1)
     {
      Print("ERROR: [ML_DATASET] Logger schema v2 requires chart timeframe M1.");
      return false;
     }
   if(StringLen(InpMlStrategyVersion) == 0)
     {
      Print("ERROR: [ML_DATASET] InpMlStrategyVersion cannot be empty.");
      return false;
     }
   if(StringLen(InpMlDatasetDirectory) == 0)
     {
      Print("ERROR: [ML_DATASET] InpMlDatasetDirectory cannot be empty.");
      return false;
     }
   if(InpMlFlushEveryRecords <= 0)
     {
      Print("ERROR: [ML_DATASET] InpMlFlushEveryRecords must be > 0.");
      return false;
     }
   if(StringLen(InpMlSourceRevision) == 0)
      Print("WARNING: [ML_DATASET] InpMlSourceRevision is empty. ",
            "Set the Git commit/tag before producing a retained dataset.");
   return true;
  }

//+------------------------------------------------------------------+
bool MlOpenOutputFile(const string fileName, int &handle)
  {
   string path = g_mlRunDirectory + "\\" + fileName;
   ResetLastError();
   handle = FileOpen(path,
                     FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON,
                     0,
                     CP_UTF8);
   if(handle == INVALID_HANDLE)
     {
      Print("ERROR: [ML_DATASET] Cannot open ", path,
            " in Terminal Common Files. Error=", GetLastError());
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
void MlFlushAllFiles()
  {
   if(g_mlCandidateFile != INVALID_HANDLE) FileFlush(g_mlCandidateFile);
   if(g_mlTradeEntryFile != INVALID_HANDLE) FileFlush(g_mlTradeEntryFile);
   if(g_mlTradeOutcomeFile != INVALID_HANDLE) FileFlush(g_mlTradeOutcomeFile);
   if(g_mlCycleOutcomeFile != INVALID_HANDLE) FileFlush(g_mlCycleOutcomeFile);
   if(g_mlBarrierOutcomeFile != INVALID_HANDLE) FileFlush(g_mlBarrierOutcomeFile);
   if(g_mlManifestFile != INVALID_HANDLE) FileFlush(g_mlManifestFile);
   g_mlRecordsSinceFlush = 0;
  }

//+------------------------------------------------------------------+
void MlCloseFile(int &handle)
  {
   if(handle == INVALID_HANDLE)
      return;
   FileFlush(handle);
   FileClose(handle);
   handle = INVALID_HANDLE;
  }

//+------------------------------------------------------------------+
void MlCloseAllOutputFiles()
  {
   MlCloseFile(g_mlCandidateFile);
   MlCloseFile(g_mlTradeEntryFile);
   MlCloseFile(g_mlTradeOutcomeFile);
   MlCloseFile(g_mlCycleOutcomeFile);
   MlCloseFile(g_mlBarrierOutcomeFile);
   MlCloseFile(g_mlManifestFile);
  }

//+------------------------------------------------------------------+
bool MlWriteRow(const int handle, const string row)
  {
   if(handle == INVALID_HANDLE)
      return false;
   ResetLastError();
   uint written = FileWriteString(handle, row + "\r\n");
   if(written == 0)
     {
      g_mlDataErrors++;
      Print("WARNING: [ML_DATASET] FileWriteString failed. Error=", GetLastError());
      return false;
     }
   g_mlRecordsSinceFlush++;
   if(g_mlRecordsSinceFlush >= InpMlFlushEveryRecords)
      MlFlushAllFiles();
   return true;
  }

//+------------------------------------------------------------------+
string MlCandidateHeader()
  {
   return
      "SchemaVersion,RunId,SetupId,StrategyVersion,SourceRevision,PresetHash,"
      "Symbol,Timeframe,CandidateTime,CandidateBarTime,SignalTime,Direction,"
      "CciSignalType,SignalAgeBars,CandidatePrice,Bid,Ask,SpreadPoints,"
      "SpreadATR,BarrierATR,ATR_M5,ATRRatioM1M5,InitialSL,InitialSLPoints,"
      "InitialSLATR,FeatureReady,CciSignal,CiSignal,CciCandidate,CiCandidate,"
      "CciDeltaDir,CciGapSignalDir,CciGapCandidateDir,HiLoSignalAlign,"
      "PsarSignalAlign,STSignalAlign,STMTFSignalAlign,ConfirmationsAtSignal,"
      "LateConfirmMask,HiLoLatencyBars,PsarLatencyBars,STLatencyBars,"
      "STMTFLatencyNativeBars,STMTFLatencySeconds,HiLoAgeBars,PsarAgeBars,"
      "STAgeBars,STMTFAgeBars,Return1ATR,Return3ATR,Return5ATR,Return10ATR,"
      "Return20ATR,BodyATR,RangeATR,UpperWickATR,LowerWickATR,"
      "DisplacementATR,PreEntryMFEATR,PreEntryMAEATR,DistanceEMAATR,"
      "EMASlope5ATR,EMASlope10ATR,RecentRangePositionDir,TickVolume,Hour,"
      "Minute,DayOfWeek,TimeOfDaySin,TimeOfDayCos,DayOfWeekSin,"
      "DayOfWeekCos,AsiaSession,LondonSession,NewYorkSession,"
      "SessionDistanceReady,MinutesFromSessionOpen,MinutesToSessionClose,"
      "StructureReady,DirectionalRoomATR,FeatureReadyV2,AdxValue,"
      "AdxSlope1,DiGapDir,DiGapSlopeDir,CciSlope1Dir,CciSlope3Dir,"
      "ATRChange1,HiLoDistanceATR,HiLoLineSlopeATR,PsarDistanceATR,"
      "PsarLineSlopeATR,STDistanceATR,STLineSlopeATR,STMTFDistanceATR,"
      "STMTFLineSlopeATR,DataIntegrityFlag";
  }

//+------------------------------------------------------------------+
bool MlInitializeDatasetLogger()
  {
   if(!InpEnableMlDatasetLogger)
      return true;

   g_mlRunId = (StringLen(InpMlRunId) > 0
                ? MlSanitizePathPart(InpMlRunId)
                : MlAutoRunId());
   if(StringLen(g_mlRunId) == 0)
     {
      Print("ERROR: [ML_DATASET] Resolved RunId is empty.");
      return false;
     }
   g_mlRunDirectory =
      MlSanitizePathPart(InpMlDatasetDirectory) + "\\" + g_mlRunId;
   if(FileIsExist(g_mlRunDirectory + "\\run_manifest.json", FILE_COMMON))
     {
      Print("ERROR: [ML_DATASET] RunId already exists in Terminal Common Files: ",
            g_mlRunDirectory, ". Use a unique InpMlRunId.");
      return false;
     }

   if(!MlOpenOutputFile("candidate_setups.csv", g_mlCandidateFile) ||
      !MlOpenOutputFile("trade_entries.csv", g_mlTradeEntryFile) ||
      !MlOpenOutputFile("trade_outcomes.csv", g_mlTradeOutcomeFile) ||
      !MlOpenOutputFile("cycle_outcomes.csv", g_mlCycleOutcomeFile) ||
      !MlOpenOutputFile("barrier_outcomes.csv", g_mlBarrierOutcomeFile) ||
      !MlOpenOutputFile("run_manifest.json", g_mlManifestFile))
     {
      MlCloseAllOutputFiles();
      return false;
     }

   MlWriteRow(g_mlCandidateFile, MlCandidateHeader());
   MlWriteRow(g_mlTradeEntryFile,
      "SchemaVersion,RunId,SetupId,AttemptNumber,CycleId,OrderTicket,DealTicket,PositionId,"
      "RequestTime,ActualTime,Direction,RequestedPrice,ActualPrice,Volume,"
      "InitialSL,InitialSLPoints,TakeProfit,SpreadPoints,Retcode,"
      "RetcodeDescription,OrderSucceeded");
   MlWriteRow(g_mlTradeOutcomeFile,
      "SchemaVersion,RunId,SetupId,CycleId,PositionId,ExitDeal,ExitTime,"
      "Direction,ExitPrice,ExitReason,GrossProfit,Commission,Swap,NetProfit,"
      "BarsHeld,MFEPoints,MAEPoints,RecoveryEligible");
   MlWriteRow(g_mlCycleOutcomeFile,
      "SchemaVersion,RunId,SetupId,CycleId,OutcomeTime,BusinessOutcome,"
      "OriginalNetProfit,RecoveryNetProfit,CycleNetProfit,RecoveryStarted,"
      "RecoveryEntries,MaxRecoveryLevel,CompletionReason");
   MlWriteRow(g_mlBarrierOutcomeFile,
      "SchemaVersion,RunId,SetupId,HorizonBars,OutcomeTime,BarrierOutcome,"
      "Direction,ReferencePrice,ATRPrice,FavorablePrice,AdversePrice,"
      "ElapsedBars");

   string manifest =
      "{\r\n"
      "  \"schema_version\": \"" + MlJsonEscape(TS7_ML_SCHEMA_VERSION) + "\",\r\n"
      "  \"run_id\": \"" + MlJsonEscape(g_mlRunId) + "\",\r\n"
      "  \"strategy_version\": \"" + MlJsonEscape(InpMlStrategyVersion) + "\",\r\n"
      "  \"source_revision\": \"" + MlJsonEscape(InpMlSourceRevision) + "\",\r\n"
      "  \"preset_sha256\": \"" + MlJsonEscape(InpMlPresetHash) + "\",\r\n"
      "  \"symbol\": \"" + MlJsonEscape(_Symbol) + "\",\r\n"
      "  \"timeframe\": \"M1\",\r\n"
      "  \"barrier_atr\": \"RMA_14_M1_CLOSED\",\r\n"
      "  \"primary_horizon_bars\": 50,\r\n"
      "  \"sensitivity_horizon_bars\": 40,\r\n"
      "  \"feature_contract\": \"entry_state_strength_distance_v2\",\r\n"
      "  \"feature_snapshot\": \"CLOSED_BARS_ONLY_AT_CANDIDATE\",\r\n"
      "  \"adx_timeframe\": \"" +
         MlJsonEscape(EnumToString((InpAdxTimeframe == PERIOD_CURRENT)
                                    ? (ENUM_TIMEFRAMES)_Period
                                    : InpAdxTimeframe)) + "\",\r\n"
      "  \"adx_dmi_period\": " + IntegerToString(InpAdxDmiPeriod) + ",\r\n"
      "  \"adx_smoothing_enabled\": " +
         MlBoolText(InpAdxEnableSmoothing) + ",\r\n"
      "  \"adx_smoothing_period\": " +
         IntegerToString(InpAdxSmoothing) + ",\r\n"
      "  \"data_integrity_flag\": \"" + MlJsonEscape(InpMlDataIntegrityFlag) + "\",\r\n"
      "  \"build_time\": \"" + MlJsonEscape(MlTimeText(__DATETIME__)) + "\",\r\n"
      "  \"tester\": " + MlBoolText((bool)MQLInfoInteger(MQL_TESTER)) + ",\r\n"
      "  \"optimization\": " + MlBoolText((bool)MQLInfoInteger(MQL_OPTIMIZATION)) + "\r\n"
      "}\r\n";
   FileWriteString(g_mlManifestFile, manifest);

   ArrayResize(g_mlBarrierRecords, 0);
   ArrayResize(g_mlTradeLinks, 0);
   ArrayResize(g_mlRecoveryPositionLinks, 0);
   ArrayResize(g_mlCandidateStates, 0);
   g_mlLoggerReady = true;
   MlFlushAllFiles();

   Print("TS7_ML_DATASET_INIT|Schema=", TS7_ML_SCHEMA_VERSION,
         "|RunId=", g_mlRunId,
         "|StrategyVersion=", InpMlStrategyVersion,
         "|CommonFilesPath=", g_mlRunDirectory,
         "|PrimaryHorizon=50|SensitivityHorizon=40");
   return true;
  }

//+------------------------------------------------------------------+
bool MlReadIndicatorValue(const int handle,
                          const int buffer,
                          const int shift,
                          double &value)
  {
   value = 0.0;
   if(handle == INVALID_HANDLE || shift < 0)
      return false;
   double values[1];
   if(CopyBuffer(handle, buffer, shift, 1, values) != 1)
      return false;
   if(values[0] == EMPTY_VALUE || !MathIsValidNumber(values[0]))
      return false;
   value = values[0];
   return true;
  }

//+------------------------------------------------------------------+
bool MlReadAtr(const int handle, double &atrPrice)
  {
   return MlReadIndicatorValue(handle, 0, 1, atrPrice) && atrPrice > 0.0;
  }

//+------------------------------------------------------------------+
bool MlReadAdxSnapshot(const int direction,
                       double &adxValue,
                       double &adxSlope1,
                       double &diGapDir,
                       double &diGapSlopeDir)
  {
   adxValue = 0.0;
   adxSlope1 = 0.0;
   diGapDir = 0.0;
   diGapSlopeDir = 0.0;
   if(g_handles.mlADX == INVALID_HANDLE || (direction != 1 && direction != -1))
      return false;

   int smoothCount = (InpAdxEnableSmoothing
                      ? MathMax(1, InpAdxSmoothing) : 1);
   int requiredAdx = smoothCount + 1;
   double adxValues[];
   double plusDiValues[];
   double minusDiValues[];
   ArrayResize(adxValues, requiredAdx);
   ArrayResize(plusDiValues, 2);
   ArrayResize(minusDiValues, 2);
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(plusDiValues, true);
   ArraySetAsSeries(minusDiValues, true);

   if(CopyBuffer(g_handles.mlADX, 0, 1, requiredAdx, adxValues) != requiredAdx ||
      CopyBuffer(g_handles.mlADX, 1, 1, 2, plusDiValues) != 2 ||
      CopyBuffer(g_handles.mlADX, 2, 1, 2, minusDiValues) != 2)
      return false;

   double previousAdx = 0.0;
   for(int i = 0; i < smoothCount; i++)
     {
      if(!MathIsValidNumber(adxValues[i]) ||
         !MathIsValidNumber(adxValues[i + 1]) ||
         adxValues[i] == EMPTY_VALUE ||
         adxValues[i + 1] == EMPTY_VALUE)
         return false;
      adxValue += adxValues[i];
      previousAdx += adxValues[i + 1];
     }
   adxValue /= smoothCount;
   previousAdx /= smoothCount;
   adxSlope1 = adxValue - previousAdx;

   for(int i = 0; i < 2; i++)
      if(!MathIsValidNumber(plusDiValues[i]) ||
         !MathIsValidNumber(minusDiValues[i]) ||
         plusDiValues[i] == EMPTY_VALUE ||
         minusDiValues[i] == EMPTY_VALUE)
         return false;

   double currentGap = plusDiValues[0] - minusDiValues[0];
   double previousGap = plusDiValues[1] - minusDiValues[1];
   diGapDir = direction * currentGap;
   diGapSlopeDir = direction * (currentGap - previousGap);
   return true;
  }

//+------------------------------------------------------------------+
bool MlReadDirectionalLineSnapshot(const int handle,
                                   const int lineBuffer,
                                   const int currentShift,
                                   const int direction,
                                   const double referencePrice,
                                   const double atrPrice,
                                   double &distanceAtr,
                                   double &lineSlopeAtr)
  {
   distanceAtr = 0.0;
   lineSlopeAtr = 0.0;
   if(currentShift < 1 || atrPrice <= 0.0)
      return false;

   double lineCurrent = 0.0;
   double linePrevious = 0.0;
   if(!MlReadIndicatorValue(handle, lineBuffer, currentShift, lineCurrent) ||
      !MlReadIndicatorValue(handle, lineBuffer, currentShift + 1, linePrevious))
      return false;

   distanceAtr = direction * (referencePrice - lineCurrent) / atrPrice;
   lineSlopeAtr = direction * (lineCurrent - linePrevious) / atrPrice;
   return true;
  }

//+------------------------------------------------------------------+
bool MlReadTrendLineAtShift(const int handle,
                            const int shift,
                            double &lineValue)
  {
   lineValue = 0.0;
   int state = 0;
   if(!MlReadBufferStateAtShift(handle, 4, shift, state))
      return false;
   int lineBuffer = (state > 0 ? 0 : 1);
   return MlReadIndicatorValue(handle, lineBuffer, shift, lineValue);
  }

//+------------------------------------------------------------------+
bool MlReadTrendLineSnapshot(const int handle,
                             const ENUM_TIMEFRAMES timeframe,
                             const datetime observationTime,
                             const int direction,
                             const double referencePrice,
                             const double atrPrice,
                             double &distanceAtr,
                             double &lineSlopeAtr)
  {
   distanceAtr = 0.0;
   lineSlopeAtr = 0.0;
   int shift =
      FindOriginalDiagnosticLastClosedShift(timeframe, observationTime);
   if(shift < 1 || atrPrice <= 0.0)
      return false;

   double lineCurrent = 0.0;
   double linePrevious = 0.0;
   if(!MlReadTrendLineAtShift(handle, shift, lineCurrent) ||
      !MlReadTrendLineAtShift(handle, shift + 1, linePrevious))
      return false;

   distanceAtr = direction * (referencePrice - lineCurrent) / atrPrice;
   lineSlopeAtr = direction * (lineCurrent - linePrevious) / atrPrice;
   return true;
  }

//+------------------------------------------------------------------+
int MlSignalAgeBars(const datetime signalTime)
  {
   if(signalTime <= 0)
      return -1;
   return iBarShift(_Symbol, PERIOD_M1, signalTime, false);
  }

//+------------------------------------------------------------------+
bool MlReadBufferStateAtShift(const int handle,
                              const int buffer,
                              const int shift,
                              int &state)
  {
   return ReadOriginalDiagnosticBufferTrendState(handle, buffer, shift, state);
  }

//+------------------------------------------------------------------+
bool MlReadPsarStateAtShift(const int handle,
                            const ENUM_TIMEFRAMES timeframe,
                            const int shift,
                            int &state)
  {
   return ReadOriginalDiagnosticPsarTrendState(handle, timeframe, shift, state);
  }

//+------------------------------------------------------------------+
bool MlBufferConfirmationLatency(const int handle,
                                 const int buffer,
                                 const ENUM_TIMEFRAMES timeframe,
                                 const datetime signalCloseTime,
                                 const int direction,
                                 int &nativeBars,
                                 int &elapsedSeconds)
  {
   nativeBars = -1;
   elapsedSeconds = -1;
   ENUM_TIMEFRAMES resolved = (timeframe == PERIOD_CURRENT
                               ? (ENUM_TIMEFRAMES)_Period : timeframe);
   int signalShift =
      FindOriginalDiagnosticLastClosedShift(resolved, signalCloseTime);
   if(signalShift < 1)
      return false;

   for(int shift = signalShift; shift >= 1; shift--)
     {
      int state = 0;
      if(!MlReadBufferStateAtShift(handle, buffer, shift, state))
         return false;
      if(direction * state == 1)
        {
         nativeBars = signalShift - shift;
         datetime alignedClose =
            iTime(_Symbol, resolved, shift) + PeriodSeconds(resolved);
         elapsedSeconds =
            (int)MathMax(0, (long)(alignedClose - signalCloseTime));
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
bool MlPsarConfirmationLatency(const int handle,
                               const ENUM_TIMEFRAMES timeframe,
                               const datetime signalCloseTime,
                               const int direction,
                               int &nativeBars,
                               int &elapsedSeconds)
  {
   nativeBars = -1;
   elapsedSeconds = -1;
   ENUM_TIMEFRAMES resolved = (timeframe == PERIOD_CURRENT
                               ? (ENUM_TIMEFRAMES)_Period : timeframe);
   int signalShift =
      FindOriginalDiagnosticLastClosedShift(resolved, signalCloseTime);
   if(signalShift < 1)
      return false;

   for(int shift = signalShift; shift >= 1; shift--)
     {
      int state = 0;
      if(!MlReadPsarStateAtShift(handle, resolved, shift, state))
         return false;
      if(direction * state == 1)
        {
         nativeBars = signalShift - shift;
         datetime alignedClose =
            iTime(_Symbol, resolved, shift) + PeriodSeconds(resolved);
         elapsedSeconds =
            (int)MathMax(0, (long)(alignedClose - signalCloseTime));
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
bool MlPreEntryExcursion(const int direction,
                         const int signalAge,
                         const double triggerPrice,
                         const double candidatePrice,
                         double &mfePrice,
                         double &maePrice)
  {
   mfePrice = 0.0;
   maePrice = 0.0;
   if(signalAge < 1 || triggerPrice <= 0.0 || candidatePrice <= 0.0)
      return false;

   double maxObserved = MathMax(triggerPrice, candidatePrice);
   double minObserved = MathMin(triggerPrice, candidatePrice);
   for(int shift = signalAge - 1; shift >= 1; shift--)
     {
      double high = iHigh(_Symbol, PERIOD_M1, shift);
      double low = iLow(_Symbol, PERIOD_M1, shift);
      if(high <= 0.0 || low <= 0.0)
         return false;
      maxObserved = MathMax(maxObserved, high);
      minObserved = MathMin(minObserved, low);
     }

   if(direction > 0)
     {
      mfePrice = MathMax(0.0, maxObserved - triggerPrice);
      maePrice = MathMax(0.0, triggerPrice - minObserved);
     }
   else
     {
      mfePrice = MathMax(0.0, triggerPrice - minObserved);
      maePrice = MathMax(0.0, maxObserved - triggerPrice);
     }
   return true;
  }

//+------------------------------------------------------------------+
string MlBuildSetupId(const int direction,
                      const datetime signalTime,
                      const datetime candidateBarTime)
  {
   return MlSanitizePathPart(InpMlStrategyVersion) + "_" +
          MlSanitizePathPart(_Symbol) + "_M1_" +
          (direction > 0 ? "BUY_" : "SELL_") +
          MlLongText((long)signalTime) + "_" +
          MlLongText((long)candidateBarTime);
  }

//+------------------------------------------------------------------+
int MlFindCandidateState(const string setupId)
  {
   for(int i = 0; i < ArraySize(g_mlCandidateStates); i++)
      if(g_mlCandidateStates[i].setupId == setupId)
         return i;
   return -1;
  }

//+------------------------------------------------------------------+
void MlAppendBarrierRecord(const string setupId,
                           const int direction,
                           const datetime candidateTime,
                           const datetime candidateBarTime,
                           const double referencePrice,
                           const double atrPrice)
  {
   int index = ArraySize(g_mlBarrierRecords);
   if(ArrayResize(g_mlBarrierRecords, index + 1) != index + 1)
     {
      g_mlDataErrors++;
      return;
     }
   g_mlBarrierRecords[index].active = true;
   g_mlBarrierRecords[index].setupId = setupId;
   g_mlBarrierRecords[index].direction = direction;
   g_mlBarrierRecords[index].candidateTime = candidateTime;
   g_mlBarrierRecords[index].candidateBarTime = candidateBarTime;
   g_mlBarrierRecords[index].referencePrice = referencePrice;
   g_mlBarrierRecords[index].atrPrice = atrPrice;
   g_mlBarrierRecords[index].favorablePrice =
      NormalizeDouble(referencePrice + direction * atrPrice, _Digits);
   g_mlBarrierRecords[index].adversePrice =
      NormalizeDouble(referencePrice - direction * atrPrice, _Digits);
   g_mlBarrierRecords[index].horizon40Done = false;
   g_mlBarrierRecords[index].horizon50Done = false;
  }

//+------------------------------------------------------------------+
string MlRegisterEntryCandidate(const int direction,
                                const int cciSignalType,
                                const datetime signalTime,
                                const double referencePrice,
                                const double bid,
                                const double ask,
                                const SMainStopLossContext &stopContext)
  {
   if(!g_mlLoggerReady)
      return "";

   datetime candidateTime = TimeCurrent();
   datetime candidateBarTime = iTime(_Symbol, PERIOD_M1, 0);
   string setupId =
      MlBuildSetupId(direction, signalTime, candidateBarTime);
   int existingCandidate = MlFindCandidateState(setupId);
   if(existingCandidate >= 0)
     {
      g_mlPendingSetupId = setupId;
      g_mlPendingDirection = direction;
      g_mlObservedOriginalEntryDeal = 0;
      g_mlObservedOriginalPositionId = 0;
      return setupId;
     }
   int signalAge = MlSignalAgeBars(signalTime);
   datetime signalCloseTime =
      signalTime + PeriodSeconds(PERIOD_M1);

   double atrM1 = 0.0;
   double atrM1Previous = 0.0;
   double atrM5 = 0.0;
   double ema1 = 0.0;
   double ema6 = 0.0;
   double ema11 = 0.0;
   bool atrM1Ready = MlReadAtr(g_handles.mlBarrierATR, atrM1);
   bool atrM1PreviousReady =
      MlReadIndicatorValue(g_handles.mlBarrierATR, 0, 2, atrM1Previous) &&
      atrM1Previous > 0.0;
   bool atrM5Ready = MlReadAtr(g_handles.mlATR_M5, atrM5);
   bool emaReady =
      MlReadIndicatorValue(g_handles.mlEMA, 0, 1, ema1) &&
      MlReadIndicatorValue(g_handles.mlEMA, 0, 6, ema6) &&
      MlReadIndicatorValue(g_handles.mlEMA, 0, 11, ema11);

   double cciSignal = 0.0;
   double ciSignal = 0.0;
   double cciCandidate = 0.0;
   double ciCandidate = 0.0;
   double cciPrevious1 = 0.0;
   double cciPrevious3 = 0.0;
   bool cciReady =
      ReadOriginalDiagnosticCciPairAtShift(signalAge, cciSignal, ciSignal) &&
      ReadOriginalDiagnosticCciPairAtShift(1, cciCandidate, ciCandidate);
   bool cciVelocityReady =
      MlReadIndicatorValue(g_handles.cci, 0, 2, cciPrevious1) &&
      MlReadIndicatorValue(g_handles.cci, 0, 4, cciPrevious3);

   int mainPsarHandle = (g_handles.mainPSAR != INVALID_HANDLE
                         ? g_handles.mainPSAR : g_handles.psar);
   int mainStHandle = (g_handles.mainSuperTrend != INVALID_HANDLE
                       ? g_handles.mainSuperTrend : g_handles.superTrend);
   ENUM_TIMEFRAMES mainPsarTf = (g_handles.mainPSAR != INVALID_HANDLE
                                  ? InpMainPsarTimeframe
                                  : (ENUM_TIMEFRAMES)_Period);
   ENUM_TIMEFRAMES mainStTf = (g_handles.mainSuperTrend != INVALID_HANDLE
                                ? InpMainSuperTrendTimeframe
                                : (ENUM_TIMEFRAMES)_Period);

   double adxValue = 0.0;
   double adxSlope1 = 0.0;
   double diGapDir = 0.0;
   double diGapSlopeDir = 0.0;
   bool adxSnapshotReady =
      MlReadAdxSnapshot(direction, adxValue, adxSlope1,
                        diGapDir, diGapSlopeDir);

   double hiloDistanceAtr = 0.0;
   double hiloLineSlopeAtr = 0.0;
   int hiloLineBuffer = (direction > 0 ? 7 : 6);
   bool hiloSnapshotReady =
      MlReadDirectionalLineSnapshot(g_handles.hilo, hiloLineBuffer, 1,
                                    direction, referencePrice, atrM1,
                                    hiloDistanceAtr, hiloLineSlopeAtr);

   double psarDistanceAtr = 0.0;
   double psarLineSlopeAtr = 0.0;
   int psarCandidateShift =
      FindOriginalDiagnosticLastClosedShift(mainPsarTf, candidateTime);
   bool psarSnapshotReady =
      MlReadDirectionalLineSnapshot(mainPsarHandle, 0, psarCandidateShift,
                                    direction, referencePrice, atrM1,
                                    psarDistanceAtr, psarLineSlopeAtr);

   double stDistanceAtr = 0.0;
   double stLineSlopeAtr = 0.0;
   bool stSnapshotReady =
      MlReadTrendLineSnapshot(mainStHandle, mainStTf, candidateTime,
                              direction, referencePrice, atrM1,
                              stDistanceAtr, stLineSlopeAtr);

   double stMtfDistanceAtr = 0.0;
   double stMtfLineSlopeAtr = 0.0;
   bool stMtfSnapshotReady = true;
   if(InpEnableSTMTF && InpSTFilterTF != PERIOD_CURRENT)
      stMtfSnapshotReady =
         MlReadTrendLineSnapshot(g_handles.stFilter, InpSTFilterTF,
                                 candidateTime, direction, referencePrice,
                                 atrM1, stMtfDistanceAtr,
                                 stMtfLineSlopeAtr);

   int hiloSignalAlign = 0;
   int psarSignalAlign = 0;
   int stSignalAlign = 0;
   int stMtfSignalAlign = 0;
   bool confirmationReady = (signalAge >= 1);
   int state = 0;
   if(InpUseMainHiLoFilter)
     {
      bool ready = MlReadBufferStateAtShift(g_handles.hilo, 8,
                                            signalAge, state);
      confirmationReady = confirmationReady && ready;
      if(ready) hiloSignalAlign = direction * state;
     }
   if(InpUseMainPsarFilter)
     {
      int shift = FindOriginalDiagnosticLastClosedShift(mainPsarTf,
                                                        signalCloseTime);
      bool ready = MlReadPsarStateAtShift(mainPsarHandle, mainPsarTf,
                                          shift, state);
      confirmationReady = confirmationReady && ready;
      if(ready) psarSignalAlign = direction * state;
     }
   if(InpUseMainSuperTrendFilter)
     {
      int shift = FindOriginalDiagnosticLastClosedShift(mainStTf,
                                                        signalCloseTime);
      bool ready = MlReadBufferStateAtShift(mainStHandle, 4, shift, state);
      confirmationReady = confirmationReady && ready;
      if(ready) stSignalAlign = direction * state;
     }
   if(InpEnableSTMTF)
     {
      int shift = FindOriginalDiagnosticLastClosedShift(InpSTFilterTF,
                                                        signalCloseTime);
      bool ready =
         MlReadBufferStateAtShift(g_handles.stFilter, 4, shift, state);
      confirmationReady = confirmationReady && ready;
      if(ready) stMtfSignalAlign = direction * state;
     }

   int confirmationsAtSignal = 0;
   int lateConfirmMask = 0;
   if(!InpUseMainHiLoFilter || hiloSignalAlign == 1) confirmationsAtSignal++;
   else lateConfirmMask |= 1;
   if(!InpUseMainPsarFilter || psarSignalAlign == 1) confirmationsAtSignal++;
   else lateConfirmMask |= 2;
   if(!InpUseMainSuperTrendFilter || stSignalAlign == 1) confirmationsAtSignal++;
   else lateConfirmMask |= 4;
   if(!InpEnableSTMTF || stMtfSignalAlign == 1) confirmationsAtSignal++;
   else lateConfirmMask |= 8;

   int hiloLatency = -1;
   int hiloLatencySeconds = -1;
   int psarLatency = -1;
   int psarLatencySeconds = -1;
   int stLatency = -1;
   int stLatencySeconds = -1;
   int stMtfLatency = -1;
   int stMtfLatencySeconds = -1;
   bool latencyReady = true;
   if(InpUseMainHiLoFilter)
      latencyReady =
         MlBufferConfirmationLatency(g_handles.hilo, 8, PERIOD_M1,
                                     signalCloseTime, direction,
                                     hiloLatency, hiloLatencySeconds) &&
         latencyReady;
   else hiloLatency = 0;
   if(InpUseMainPsarFilter)
      latencyReady =
         MlPsarConfirmationLatency(mainPsarHandle, mainPsarTf,
                                   signalCloseTime, direction,
                                   psarLatency, psarLatencySeconds) &&
         latencyReady;
   else psarLatency = 0;
   if(InpUseMainSuperTrendFilter)
      latencyReady =
         MlBufferConfirmationLatency(mainStHandle, 4, mainStTf,
                                     signalCloseTime, direction,
                                     stLatency, stLatencySeconds) &&
         latencyReady;
   else stLatency = 0;
   if(InpEnableSTMTF)
      latencyReady =
         MlBufferConfirmationLatency(g_handles.stFilter, 4, InpSTFilterTF,
                                     signalCloseTime, direction,
                                     stMtfLatency, stMtfLatencySeconds) &&
         latencyReady;
   else
     {
      stMtfLatency = 0;
      stMtfLatencySeconds = 0;
     }

   int hiloAge = (!InpUseMainHiLoFilter ? 0 :
                  ReadOriginalDiagnosticBufferTrendAge(
                     g_handles.hilo, 8, direction));
   int psarAge = (!InpUseMainPsarFilter ? 0 :
                  ReadOriginalDiagnosticPsarTrendAge(
                     mainPsarHandle, mainPsarTf, direction));
   int stAge = (!InpUseMainSuperTrendFilter ? 0 :
                ReadOriginalDiagnosticBufferTrendAge(
                   mainStHandle, 4, direction));
   int stMtfAge = (!InpEnableSTMTF ? 0 :
                   ReadOriginalDiagnosticBufferTrendAge(
                      g_handles.stFilter, 4, direction));

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M1, 0, 22, rates);
   bool ratesReady = (copied >= 22);
   double close1 = ratesReady ? rates[1].close : 0.0;
   double returns[5];
   for(int i = 0; i < 5; i++) returns[i] = 0.0;
   int returnShifts[5] = {2, 4, 6, 11, 21};
   if(ratesReady && atrM1Ready)
      for(int i = 0; i < 5; i++)
         returns[i] =
            direction * (close1 - rates[returnShifts[i]].close) / atrM1;

   double bodyAtr = 0.0;
   double rangeAtr = 0.0;
   double upperWickAtr = 0.0;
   double lowerWickAtr = 0.0;
   if(ratesReady && atrM1Ready)
     {
      bodyAtr = MathAbs(rates[1].close - rates[1].open) / atrM1;
      rangeAtr = (rates[1].high - rates[1].low) / atrM1;
      upperWickAtr =
         (rates[1].high - MathMax(rates[1].open, rates[1].close)) / atrM1;
      lowerWickAtr =
         (MathMin(rates[1].open, rates[1].close) - rates[1].low) / atrM1;
     }

   double signalClose = (signalAge >= 1
                         ? iClose(_Symbol, PERIOD_M1, signalAge) : 0.0);
   double displacementAtr = 0.0;
   double preEntryMfePrice = 0.0;
   double preEntryMaePrice = 0.0;
   bool preEntryReady =
      MlPreEntryExcursion(direction, signalAge, signalClose,
                          referencePrice, preEntryMfePrice,
                          preEntryMaePrice);
   if(atrM1Ready && signalClose > 0.0)
      displacementAtr =
         direction * (referencePrice - signalClose) / atrM1;

   double recentHigh = 0.0;
   double recentLow = 0.0;
   bool recentRangeReady = false;
   if(ratesReady)
     {
      recentHigh = rates[1].high;
      recentLow = rates[1].low;
      for(int shift = 2; shift <= 20; shift++)
        {
         recentHigh = MathMax(recentHigh, rates[shift].high);
         recentLow = MathMin(recentLow, rates[shift].low);
        }
      recentRangeReady = (recentHigh > recentLow);
     }
   double recentPosition = 0.0;
   if(recentRangeReady)
     {
      double rawPosition = (close1 - recentLow) / (recentHigh - recentLow);
      recentPosition = (direction > 0 ? rawPosition : 1.0 - rawPosition);
     }

   double distanceEmaAtr = 0.0;
   double emaSlope5Atr = 0.0;
   double emaSlope10Atr = 0.0;
   if(emaReady && atrM1Ready)
     {
      distanceEmaAtr = direction * (referencePrice - ema1) / atrM1;
      emaSlope5Atr = direction * (ema1 - ema6) / atrM1;
      emaSlope10Atr = direction * (ema1 - ema11) / atrM1;
     }

   STS7MarketStructureSnapshot structure;
   bool structureReady =
      (InpEnableOriginalStructureDiagnostics &&
       CalculateOriginalMarketStructure(structure));
   bool directionalRoomReady = false;
   double directionalRoomAtr = 0.0;
   if(structureReady && atrM1Ready)
     {
      if(direction > 0 && structure.hasResistance)
        {
         directionalRoomAtr =
            (structure.resistance - referencePrice) / atrM1;
         directionalRoomReady = true;
        }
      else if(direction < 0 && structure.hasSupport)
        {
         directionalRoomAtr =
            (referencePrice - structure.support) / atrM1;
         directionalRoomReady = true;
        }
     }

   double spreadPoints =
      (_Point > 0.0 ? (ask - bid) / _Point : 0.0);
   double spreadAtr =
      (atrM1Ready ? (ask - bid) / atrM1 : 0.0);
   double atrRatio =
      (atrM1Ready && atrM5Ready ? atrM1 / atrM5 : 0.0);
   double initialSlAtr =
      (atrM1Ready ? stopContext.distancePoints * _Point / atrM1 : 0.0);

   MqlDateTime dt;
   TimeToStruct(candidateTime, dt);
   int currentMinutes = dt.hour * 60 + dt.min;
   bool asia = InpEnableAsiaSession &&
               IsInSession(currentMinutes,
                           InpAsiaStartHour * 60 + InpAsiaStartMinute,
                           InpAsiaEndHour * 60 + InpAsiaEndMinute);
   bool london = InpEnableLondonSession &&
                 IsInSession(currentMinutes,
                             InpLondonStartHour * 60 + InpLondonStartMinute,
                             InpLondonEndHour * 60 + InpLondonEndMinute);
   bool newYork = InpEnableNewYorkSession &&
                  IsInSession(currentMinutes,
                              InpNewYorkStartHour * 60 + InpNewYorkStartMinute,
                              InpNewYorkEndHour * 60 + InpNewYorkEndMinute);
   double timeOfDayAngle =
      2.0 * M_PI * (double)currentMinutes / 1440.0;
   double dayOfWeekAngle =
      2.0 * M_PI * (double)dt.day_of_week / 7.0;
   int minutesFromSessionOpen = -1;
   int minutesToSessionClose = -1;
   bool sessionDistanceReady = false;
   if(asia)
      sessionDistanceReady =
         MlActiveSessionDistances(
            currentMinutes,
            InpAsiaStartHour * 60 + InpAsiaStartMinute,
            InpAsiaEndHour * 60 + InpAsiaEndMinute,
            minutesFromSessionOpen, minutesToSessionClose);
   else if(london)
      sessionDistanceReady =
         MlActiveSessionDistances(
            currentMinutes,
            InpLondonStartHour * 60 + InpLondonStartMinute,
            InpLondonEndHour * 60 + InpLondonEndMinute,
            minutesFromSessionOpen, minutesToSessionClose);
   else if(newYork)
      sessionDistanceReady =
         MlActiveSessionDistances(
            currentMinutes,
            InpNewYorkStartHour * 60 + InpNewYorkStartMinute,
            InpNewYorkEndHour * 60 + InpNewYorkEndMinute,
            minutesFromSessionOpen, minutesToSessionClose);

   bool featureReady =
      atrM1Ready && atrM5Ready && emaReady && cciReady &&
      confirmationReady && latencyReady && ratesReady &&
      preEntryReady && recentRangeReady;
   double cciSlope1Dir =
      direction * (cciCandidate - cciPrevious1);
   double cciSlope3Dir =
      direction * (cciCandidate - cciPrevious3) / 3.0;
   double atrChange1 =
      (atrM1PreviousReady ? atrM1 / atrM1Previous - 1.0 : 0.0);
   bool featureReadyV2 =
      featureReady && atrM1PreviousReady && cciVelocityReady &&
      adxSnapshotReady && hiloSnapshotReady && psarSnapshotReady &&
      stSnapshotReady && stMtfSnapshotReady;

   string row =
      TS7_ML_SCHEMA_VERSION + "," +
      MlCsvEscape(g_mlRunId) + "," +
      MlCsvEscape(setupId) + "," +
      MlCsvEscape(InpMlStrategyVersion) + "," +
      MlCsvEscape(InpMlSourceRevision) + "," +
      MlCsvEscape(InpMlPresetHash) + "," +
      MlCsvEscape(_Symbol) + ",M1," +
      MlCsvEscape(MlTimeText(candidateTime)) + "," +
      MlCsvEscape(MlTimeText(candidateBarTime)) + "," +
      MlCsvEscape(MlTimeText(signalTime)) + "," +
      IntegerToString(direction) + "," +
      MlCsvEscape(CCISignalTypeToString(cciSignalType)) + "," +
      IntegerToString(signalAge) + "," +
      MlDoubleText(referencePrice, _Digits) + "," +
      MlDoubleText(bid, _Digits) + "," +
      MlDoubleText(ask, _Digits) + "," +
      MlDoubleText(spreadPoints, 1) + "," +
      MlDoubleText(spreadAtr, 6, atrM1Ready) + "," +
      MlDoubleText(atrM1, _Digits, atrM1Ready) + "," +
      MlDoubleText(atrM5, _Digits, atrM5Ready) + "," +
      MlDoubleText(atrRatio, 6, atrM1Ready && atrM5Ready) + "," +
      MlDoubleText(stopContext.stopPrice, _Digits) + "," +
      MlDoubleText(stopContext.distancePoints, 1) + "," +
      MlDoubleText(initialSlAtr, 6, atrM1Ready) + "," +
      MlBoolText(featureReady) + "," +
      MlDoubleText(cciSignal, 6, cciReady) + "," +
      MlDoubleText(ciSignal, 6, cciReady) + "," +
      MlDoubleText(cciCandidate, 6, cciReady) + "," +
      MlDoubleText(ciCandidate, 6, cciReady) + "," +
      MlDoubleText(direction * (cciCandidate - cciSignal), 6, cciReady) + "," +
      MlDoubleText(direction * (cciSignal - ciSignal), 6, cciReady) + "," +
      MlDoubleText(direction * (cciCandidate - ciCandidate), 6, cciReady) + "," +
      IntegerToString(hiloSignalAlign) + "," +
      IntegerToString(psarSignalAlign) + "," +
      IntegerToString(stSignalAlign) + "," +
      IntegerToString(stMtfSignalAlign) + "," +
      IntegerToString(confirmationsAtSignal) + "," +
      IntegerToString(lateConfirmMask) + "," +
      IntegerToString(hiloLatency) + "," +
      IntegerToString(psarLatency) + "," +
      IntegerToString(stLatency) + "," +
      IntegerToString(stMtfLatency) + "," +
      IntegerToString(stMtfLatencySeconds) + "," +
      IntegerToString(hiloAge) + "," +
      IntegerToString(psarAge) + "," +
      IntegerToString(stAge) + "," +
      IntegerToString(stMtfAge) + "," +
      MlDoubleText(returns[0], 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(returns[1], 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(returns[2], 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(returns[3], 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(returns[4], 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(bodyAtr, 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(rangeAtr, 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(upperWickAtr, 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(lowerWickAtr, 6, ratesReady && atrM1Ready) + "," +
      MlDoubleText(displacementAtr, 6, atrM1Ready && signalClose > 0.0) + "," +
      MlDoubleText(preEntryMfePrice / atrM1, 6, preEntryReady && atrM1Ready) + "," +
      MlDoubleText(preEntryMaePrice / atrM1, 6, preEntryReady && atrM1Ready) + "," +
      MlDoubleText(distanceEmaAtr, 6, emaReady && atrM1Ready) + "," +
      MlDoubleText(emaSlope5Atr, 6, emaReady && atrM1Ready) + "," +
      MlDoubleText(emaSlope10Atr, 6, emaReady && atrM1Ready) + "," +
      MlDoubleText(recentPosition, 6, recentRangeReady) + "," +
      MlLongText((long)(ratesReady ? rates[1].tick_volume : 0)) + "," +
      IntegerToString(dt.hour) + "," +
      IntegerToString(dt.min) + "," +
      IntegerToString(dt.day_of_week) + "," +
      MlDoubleText(MathSin(timeOfDayAngle), 8) + "," +
      MlDoubleText(MathCos(timeOfDayAngle), 8) + "," +
      MlDoubleText(MathSin(dayOfWeekAngle), 8) + "," +
      MlDoubleText(MathCos(dayOfWeekAngle), 8) + "," +
      MlBoolText(asia) + "," +
      MlBoolText(london) + "," +
      MlBoolText(newYork) + "," +
      MlBoolText(sessionDistanceReady) + "," +
      (sessionDistanceReady ? IntegerToString(minutesFromSessionOpen) : "NA") + "," +
      (sessionDistanceReady ? IntegerToString(minutesToSessionClose) : "NA") + "," +
      MlBoolText(structureReady) + "," +
      MlDoubleText(directionalRoomAtr, 6, directionalRoomReady) + "," +
      MlBoolText(featureReadyV2) + "," +
      MlDoubleText(adxValue, 6, adxSnapshotReady) + "," +
      MlDoubleText(adxSlope1, 6, adxSnapshotReady) + "," +
      MlDoubleText(diGapDir, 6, adxSnapshotReady) + "," +
      MlDoubleText(diGapSlopeDir, 6, adxSnapshotReady) + "," +
      MlDoubleText(cciSlope1Dir, 6, cciVelocityReady) + "," +
      MlDoubleText(cciSlope3Dir, 6, cciVelocityReady) + "," +
      MlDoubleText(atrChange1, 8, atrM1PreviousReady) + "," +
      MlDoubleText(hiloDistanceAtr, 6, hiloSnapshotReady) + "," +
      MlDoubleText(hiloLineSlopeAtr, 6, hiloSnapshotReady) + "," +
      MlDoubleText(psarDistanceAtr, 6, psarSnapshotReady) + "," +
      MlDoubleText(psarLineSlopeAtr, 6, psarSnapshotReady) + "," +
      MlDoubleText(stDistanceAtr, 6, stSnapshotReady) + "," +
      MlDoubleText(stLineSlopeAtr, 6, stSnapshotReady) + "," +
      MlDoubleText(stMtfDistanceAtr, 6, stMtfSnapshotReady) + "," +
      MlDoubleText(stMtfLineSlopeAtr, 6, stMtfSnapshotReady) + "," +
      MlCsvEscape(InpMlDataIntegrityFlag);

   MlWriteRow(g_mlCandidateFile, row);
   g_mlCandidateCount++;
   int candidateStateIndex = ArraySize(g_mlCandidateStates);
   if(ArrayResize(g_mlCandidateStates, candidateStateIndex + 1) ==
      candidateStateIndex + 1)
     {
      g_mlCandidateStates[candidateStateIndex].setupId = setupId;
      g_mlCandidateStates[candidateStateIndex].orderAttempts = 0;
     }
   else
      g_mlDataErrors++;
   if(atrM1Ready)
      MlAppendBarrierRecord(setupId, direction, candidateTime,
                            candidateBarTime, referencePrice, atrM1);
   else
     {
      g_mlDataErrors++;
      for(int horizonIndex = 0; horizonIndex < 2; horizonIndex++)
        {
         int horizon = (horizonIndex == 0
                        ? TS7_ML_SENSITIVITY_HORIZON
                        : TS7_ML_PRIMARY_HORIZON);
         string errorRow =
            TS7_ML_SCHEMA_VERSION + "," + MlCsvEscape(g_mlRunId) + "," +
            MlCsvEscape(setupId) + "," + IntegerToString(horizon) + "," +
            MlCsvEscape(MlTimeText(candidateTime)) +
            ",LABEL_DATA_ERROR," + IntegerToString(direction) + "," +
            MlDoubleText(referencePrice, _Digits) +
            ",NA,NA,NA,0";
         MlWriteRow(g_mlBarrierOutcomeFile, errorRow);
         g_mlBarrierOutcomeCount++;
        }
     }

   g_mlPendingSetupId = setupId;
   g_mlPendingDirection = direction;
   g_mlObservedOriginalEntryDeal = 0;
   g_mlObservedOriginalPositionId = 0;
   return setupId;
  }

//+------------------------------------------------------------------+
void MlWriteBarrierOutcome(const SMlBarrierRecord &record,
                           const int horizon,
                           const string outcome,
                           const datetime outcomeTime,
                           const int elapsedBars)
  {
   string row =
      TS7_ML_SCHEMA_VERSION + "," + MlCsvEscape(g_mlRunId) + "," +
      MlCsvEscape(record.setupId) + "," + IntegerToString(horizon) + "," +
      MlCsvEscape(MlTimeText(outcomeTime)) + "," + outcome + "," +
      IntegerToString(record.direction) + "," +
      MlDoubleText(record.referencePrice, _Digits) + "," +
      MlDoubleText(record.atrPrice, _Digits) + "," +
      MlDoubleText(record.favorablePrice, _Digits) + "," +
      MlDoubleText(record.adversePrice, _Digits) + "," +
      IntegerToString(elapsedBars);
   MlWriteRow(g_mlBarrierOutcomeFile, row);
   g_mlBarrierOutcomeCount++;
  }

//+------------------------------------------------------------------+
void MlUpdateBarrierRecords(const MqlTick &tick)
  {
   if(!g_mlLoggerReady)
      return;
   datetime currentBar = iTime(_Symbol, PERIOD_M1, 0);
   if(currentBar <= 0)
      return;

   for(int i = 0; i < ArraySize(g_mlBarrierRecords); i++)
     {
      if(!g_mlBarrierRecords[i].active)
         continue;
      int elapsedBars =
         (int)((currentBar - g_mlBarrierRecords[i].candidateBarTime) / 60);

      if(!g_mlBarrierRecords[i].horizon40Done &&
         elapsedBars >= TS7_ML_SENSITIVITY_HORIZON)
        {
         MlWriteBarrierOutcome(g_mlBarrierRecords[i],
                               TS7_ML_SENSITIVITY_HORIZON,
                               "UNRESOLVED", TimeCurrent(),
                               TS7_ML_SENSITIVITY_HORIZON);
         g_mlBarrierRecords[i].horizon40Done = true;
        }
      if(!g_mlBarrierRecords[i].horizon50Done &&
         elapsedBars >= TS7_ML_PRIMARY_HORIZON)
        {
         MlWriteBarrierOutcome(g_mlBarrierRecords[i],
                               TS7_ML_PRIMARY_HORIZON,
                               "UNRESOLVED", TimeCurrent(),
                               TS7_ML_PRIMARY_HORIZON);
         g_mlBarrierRecords[i].horizon50Done = true;
        }

      double closeablePrice =
         (g_mlBarrierRecords[i].direction > 0 ? tick.bid : tick.ask);
      bool favorable =
         (g_mlBarrierRecords[i].direction > 0
          ? closeablePrice >= g_mlBarrierRecords[i].favorablePrice
          : closeablePrice <= g_mlBarrierRecords[i].favorablePrice);
      bool adverse =
         (g_mlBarrierRecords[i].direction > 0
          ? closeablePrice <= g_mlBarrierRecords[i].adversePrice
          : closeablePrice >= g_mlBarrierRecords[i].adversePrice);
      string outcome = "";
      if(favorable) outcome = "FAVORABLE_FIRST";
      else if(adverse) outcome = "ADVERSE_FIRST";

      if(StringLen(outcome) > 0)
        {
         if(!g_mlBarrierRecords[i].horizon40Done &&
            elapsedBars < TS7_ML_SENSITIVITY_HORIZON)
           {
            MlWriteBarrierOutcome(g_mlBarrierRecords[i],
                                  TS7_ML_SENSITIVITY_HORIZON,
                                  outcome, TimeCurrent(), elapsedBars);
            g_mlBarrierRecords[i].horizon40Done = true;
           }
         if(!g_mlBarrierRecords[i].horizon50Done &&
            elapsedBars < TS7_ML_PRIMARY_HORIZON)
           {
            MlWriteBarrierOutcome(g_mlBarrierRecords[i],
                                  TS7_ML_PRIMARY_HORIZON,
                                  outcome, TimeCurrent(), elapsedBars);
            g_mlBarrierRecords[i].horizon50Done = true;
           }
        }

      if(g_mlBarrierRecords[i].horizon40Done &&
         g_mlBarrierRecords[i].horizon50Done)
         g_mlBarrierRecords[i].active = false;
     }
  }

//+------------------------------------------------------------------+
int MlFindTradeLinkByPositionId(const long positionId)
  {
   for(int i = 0; i < ArraySize(g_mlTradeLinks); i++)
      if(g_mlTradeLinks[i].positionId == positionId)
         return i;
   return -1;
  }

//+------------------------------------------------------------------+
int MlFindTradeLinkBySetupId(const string setupId)
  {
   for(int i = 0; i < ArraySize(g_mlTradeLinks); i++)
      if(g_mlTradeLinks[i].setupId == setupId)
         return i;
   return -1;
  }

//+------------------------------------------------------------------+
void MlObserveEntryDealTransaction(const ulong dealTicket,
                                   const string dealComment)
  {
   if(!g_mlLoggerReady)
      return;
   if(IsRecoveryComment(dealComment))
     {
      if(g_mlCurrentRecoveryTradeIndex >= 0 &&
         g_mlCurrentRecoveryTradeIndex < ArraySize(g_mlTradeLinks))
        {
         long recoveryPositionId =
            (long)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         SMlTradeLink link = g_mlTradeLinks[g_mlCurrentRecoveryTradeIndex];
         link.recoveryEntries++;
         link.maxRecoveryLevel =
            MathMax(link.maxRecoveryLevel, link.recoveryEntries);
         g_mlTradeLinks[g_mlCurrentRecoveryTradeIndex] = link;

         bool positionRegistered = false;
         for(int i = 0; i < ArraySize(g_mlRecoveryPositionLinks); i++)
            if(g_mlRecoveryPositionLinks[i].positionId == recoveryPositionId)
              {
               positionRegistered = true;
               break;
              }
         if(!positionRegistered && recoveryPositionId > 0)
           {
            int positionIndex = ArraySize(g_mlRecoveryPositionLinks);
            if(ArrayResize(g_mlRecoveryPositionLinks, positionIndex + 1) ==
               positionIndex + 1)
              {
               g_mlRecoveryPositionLinks[positionIndex].positionId =
                  recoveryPositionId;
               g_mlRecoveryPositionLinks[positionIndex].tradeIndex =
                  g_mlCurrentRecoveryTradeIndex;
              }
            else
               g_mlDataErrors++;
           }
        }
      return;
     }

   if(StringLen(g_mlPendingSetupId) == 0)
      return;
   long dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   int direction = (dealType == DEAL_TYPE_BUY ? 1 :
                    (dealType == DEAL_TYPE_SELL ? -1 : 0));
   if(direction != g_mlPendingDirection)
      return;
   g_mlObservedOriginalEntryDeal = dealTicket;
   g_mlObservedOriginalPositionId =
      (long)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
  }

//+------------------------------------------------------------------+
void MlRegisterOrderResult(const string setupId,
                           const int direction,
                           const double requestedPrice,
                           const double volume,
                           const double initialSl,
                           const double initialSlPoints,
                           const double takeProfit,
                           const double spreadPoints,
                           const bool succeeded)
  {
   if(!g_mlLoggerReady || StringLen(setupId) == 0)
      return;

   int candidateStateIndex = MlFindCandidateState(setupId);
   int attemptNumber = 0;
   if(candidateStateIndex >= 0)
     {
      g_mlCandidateStates[candidateStateIndex].orderAttempts++;
      attemptNumber =
         g_mlCandidateStates[candidateStateIndex].orderAttempts;
     }
   else
     {
      g_mlDataErrors++;
      Print("WARNING: [ML_DATASET] Missing candidate state for order result. SetupId=",
            setupId);
     }

   ulong orderTicket = g_trade.ResultOrder();
   ulong dealTicket = g_trade.ResultDeal();
   if(dealTicket == 0)
      dealTicket = g_mlObservedOriginalEntryDeal;
   long positionId = g_mlObservedOriginalPositionId;
   double actualPrice = g_trade.ResultPrice();
   datetime actualTime = TimeCurrent();
   if(dealTicket > 0 && HistoryDealSelect(dealTicket))
     {
      positionId = (long)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      actualPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      actualTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
     }

   string cycleId = setupId + "_CYCLE";
   string row =
      TS7_ML_SCHEMA_VERSION + "," + MlCsvEscape(g_mlRunId) + "," +
      MlCsvEscape(setupId) + "," + IntegerToString(attemptNumber) + "," +
      MlCsvEscape(cycleId) + "," +
      MlLongText((long)orderTicket) + "," +
      MlLongText((long)dealTicket) + "," +
      MlLongText(positionId) + "," +
      MlCsvEscape(MlTimeText(TimeCurrent())) + "," +
      MlCsvEscape(MlTimeText(actualTime)) + "," +
      IntegerToString(direction) + "," +
      MlDoubleText(requestedPrice, _Digits) + "," +
      MlDoubleText(actualPrice, _Digits, succeeded && actualPrice > 0.0) + "," +
      MlDoubleText(volume, 2) + "," +
      MlDoubleText(initialSl, _Digits) + "," +
      MlDoubleText(initialSlPoints, 1) + "," +
      MlDoubleText(takeProfit, _Digits) + "," +
      MlDoubleText(spreadPoints, 1) + "," +
      MlLongText((long)g_trade.ResultRetcode()) + "," +
      MlCsvEscape(g_trade.ResultRetcodeDescription()) + "," +
      MlBoolText(succeeded);
   MlWriteRow(g_mlTradeEntryFile, row);
   g_mlOrderAttemptCount++;

   if(succeeded)
     {
      int index = MlFindTradeLinkBySetupId(setupId);
      if(index < 0)
        {
         index = ArraySize(g_mlTradeLinks);
         if(ArrayResize(g_mlTradeLinks, index + 1) != index + 1)
           {
            g_mlDataErrors++;
            index = -1;
           }
        }
      if(index >= 0)
        {
         g_mlTradeLinks[index].activeCycle = true;
         g_mlTradeLinks[index].setupId = setupId;
         g_mlTradeLinks[index].cycleId = cycleId;
         g_mlTradeLinks[index].positionId = positionId;
         g_mlTradeLinks[index].direction = direction;
         g_mlTradeLinks[index].entryTime = actualTime;
         g_mlTradeLinks[index].entryPrice =
            (actualPrice > 0.0 ? actualPrice : requestedPrice);
         g_mlTradeLinks[index].volume = volume;
         g_mlTradeLinks[index].mfePoints = 0.0;
         g_mlTradeLinks[index].maePoints = 0.0;
         g_mlTradeLinks[index].originalCloseTime = 0;
         g_mlTradeLinks[index].originalNetProfit = 0.0;
         g_mlTradeLinks[index].originalClosed = false;
         g_mlTradeLinks[index].recoveryStarted = false;
         g_mlTradeLinks[index].recoveryEntries = 0;
         g_mlTradeLinks[index].maxRecoveryLevel = 0;
         g_mlTradeLinks[index].recoveryNetProfit = 0.0;
        }
     }

   g_mlPendingSetupId = "";
   g_mlPendingDirection = 0;
   g_mlObservedOriginalEntryDeal = 0;
   g_mlObservedOriginalPositionId = 0;
  }

//+------------------------------------------------------------------+
void MlUpdateTradeExcursions(const MqlTick &tick)
  {
   if(!g_mlLoggerReady || _Point <= 0.0)
      return;
   for(int i = 0; i < ArraySize(g_mlTradeLinks); i++)
     {
      if(!g_mlTradeLinks[i].activeCycle ||
         g_mlTradeLinks[i].originalClosed ||
         g_mlTradeLinks[i].entryPrice <= 0.0)
         continue;
      double closeable =
         (g_mlTradeLinks[i].direction > 0 ? tick.bid : tick.ask);
      double signedMove =
         g_mlTradeLinks[i].direction *
         (closeable - g_mlTradeLinks[i].entryPrice) / _Point;
      g_mlTradeLinks[i].mfePoints =
         MathMax(g_mlTradeLinks[i].mfePoints, MathMax(0.0, signedMove));
      g_mlTradeLinks[i].maePoints =
         MathMax(g_mlTradeLinks[i].maePoints, MathMax(0.0, -signedMove));
     }
  }

//+------------------------------------------------------------------+
bool MlAggregatePositionFinancials(const long positionId,
                                   double &grossProfit,
                                   double &commission,
                                   double &swap,
                                   double &netProfit)
  {
   grossProfit = 0.0;
   commission = 0.0;
   swap = 0.0;
   netProfit = 0.0;
   if(positionId <= 0 || !HistorySelectByPosition(positionId))
      return false;
   int total = HistoryDealsTotal();
   if(total <= 0)
      return false;
   for(int i = 0; i < total; i++)
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      grossProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      commission += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      swap += HistoryDealGetDouble(ticket, DEAL_SWAP);
     }
   netProfit = grossProfit + commission + swap;
   return true;
  }

//+------------------------------------------------------------------+
void MlRefreshRecoveryFinancials(const int tradeIndex)
  {
   if(tradeIndex < 0 || tradeIndex >= ArraySize(g_mlTradeLinks))
      return;

   double recoveryNetProfit = 0.0;
   for(int i = 0; i < ArraySize(g_mlRecoveryPositionLinks); i++)
     {
      if(g_mlRecoveryPositionLinks[i].tradeIndex != tradeIndex)
         continue;
      double grossProfit = 0.0;
      double commission = 0.0;
      double swap = 0.0;
      double netProfit = 0.0;
      if(MlAggregatePositionFinancials(
            g_mlRecoveryPositionLinks[i].positionId,
            grossProfit, commission, swap, netProfit))
         recoveryNetProfit += netProfit;
      else
        {
         g_mlDataErrors++;
         Print("WARNING: [ML_DATASET] Cannot aggregate recovery position. "
               "PositionId=", g_mlRecoveryPositionLinks[i].positionId,
               " TradeIndex=", tradeIndex);
        }
     }
   g_mlTradeLinks[tradeIndex].recoveryNetProfit = recoveryNetProfit;
  }

//+------------------------------------------------------------------+
int MlRegisterOriginalClose(const ulong dealTicket,
                            const long dealReason)
  {
   if(!g_mlLoggerReady || !HistoryDealSelect(dealTicket))
      return -1;
   long positionId =
      (long)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
   int index = MlFindTradeLinkByPositionId(positionId);
   if(index < 0)
     {
      g_mlDataErrors++;
      Print("WARNING: [ML_DATASET] Missing trade link for original close. PositionId=",
            positionId, " Deal=", dealTicket);
      return -1;
     }

   double exitPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
   datetime exitTime =
      (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   double grossProfit = 0.0;
   double commission = 0.0;
   double swap = 0.0;
   double netProfit = 0.0;
   bool financialsReady =
      MlAggregatePositionFinancials(positionId, grossProfit,
                                    commission, swap, netProfit);
   if(!financialsReady)
     {
      g_mlDataErrors++;
      HistoryDealSelect(dealTicket);
      grossProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      netProfit = grossProfit + commission + swap;
     }

   double signedExitMove =
      g_mlTradeLinks[index].direction *
      (exitPrice - g_mlTradeLinks[index].entryPrice) / _Point;
   g_mlTradeLinks[index].mfePoints =
      MathMax(g_mlTradeLinks[index].mfePoints, MathMax(0.0, signedExitMove));
   g_mlTradeLinks[index].maePoints =
      MathMax(g_mlTradeLinks[index].maePoints, MathMax(0.0, -signedExitMove));
   int barsHeld = (int)((exitTime - g_mlTradeLinks[index].entryTime) /
                        PeriodSeconds(PERIOD_M1));

   string row =
      TS7_ML_SCHEMA_VERSION + "," + MlCsvEscape(g_mlRunId) + "," +
      MlCsvEscape(g_mlTradeLinks[index].setupId) + "," +
      MlCsvEscape(g_mlTradeLinks[index].cycleId) + "," +
      MlLongText(positionId) + "," +
      MlLongText((long)dealTicket) + "," +
      MlCsvEscape(MlTimeText(exitTime)) + "," +
      IntegerToString(g_mlTradeLinks[index].direction) + "," +
      MlDoubleText(exitPrice, _Digits) + "," +
      MlCsvEscape(EnumToString((ENUM_DEAL_REASON)dealReason)) + "," +
      MlDoubleText(grossProfit, 2) + "," +
      MlDoubleText(commission, 2) + "," +
      MlDoubleText(swap, 2) + "," +
      MlDoubleText(netProfit, 2) + "," +
      IntegerToString(barsHeld) + "," +
      MlDoubleText(g_mlTradeLinks[index].mfePoints, 1) + "," +
      MlDoubleText(g_mlTradeLinks[index].maePoints, 1) + "," +
      MlBoolText(InpEnableRecovery && netProfit < 0.0);
   MlWriteRow(g_mlTradeOutcomeFile, row);
   g_mlTradeOutcomeCount++;

   g_mlTradeLinks[index].originalCloseTime = exitTime;
   g_mlTradeLinks[index].originalNetProfit = netProfit;
   g_mlTradeLinks[index].originalClosed = true;
   return index;
  }

//+------------------------------------------------------------------+
void MlWriteCycleOutcome(const int index,
                         const string businessOutcome,
                         const string completionReason,
                         const datetime outcomeTime)
  {
   if(index < 0 || index >= ArraySize(g_mlTradeLinks) ||
      !g_mlTradeLinks[index].activeCycle)
      return;
   double cycleNet = g_mlTradeLinks[index].originalNetProfit +
                     g_mlTradeLinks[index].recoveryNetProfit;
   string row =
      TS7_ML_SCHEMA_VERSION + "," + MlCsvEscape(g_mlRunId) + "," +
      MlCsvEscape(g_mlTradeLinks[index].setupId) + "," +
      MlCsvEscape(g_mlTradeLinks[index].cycleId) + "," +
      MlCsvEscape(MlTimeText(outcomeTime)) + "," +
      businessOutcome + "," +
      MlDoubleText(g_mlTradeLinks[index].originalNetProfit, 2) + "," +
      MlDoubleText(g_mlTradeLinks[index].recoveryNetProfit, 2) + "," +
      MlDoubleText(cycleNet, 2) + "," +
      MlBoolText(g_mlTradeLinks[index].recoveryStarted) + "," +
      IntegerToString(g_mlTradeLinks[index].recoveryEntries) + "," +
      IntegerToString(g_mlTradeLinks[index].maxRecoveryLevel) + "," +
      MlCsvEscape(completionReason);
   MlWriteRow(g_mlCycleOutcomeFile, row);
   g_mlCycleOutcomeCount++;
   g_mlTradeLinks[index].activeCycle = false;
  }

//+------------------------------------------------------------------+
void MlFinalizeNoRecovery(const int tradeIndex,
                          const string completionReason)
  {
   if(!g_mlLoggerReady || tradeIndex < 0)
      return;
   MlWriteCycleOutcome(tradeIndex, "NO_RECOVERY",
                       completionReason, TimeCurrent());
  }

//+------------------------------------------------------------------+
void MlMarkRecoveryStarted(const ulong originalCloseDeal)
  {
   if(!g_mlLoggerReady || !HistoryDealSelect(originalCloseDeal))
      return;
   long positionId =
      (long)HistoryDealGetInteger(originalCloseDeal, DEAL_POSITION_ID);
   int index = MlFindTradeLinkByPositionId(positionId);
   if(index < 0)
     {
      g_mlDataErrors++;
      return;
     }
   g_mlTradeLinks[index].recoveryStarted = true;
   g_mlCurrentRecoveryTradeIndex = index;
  }

//+------------------------------------------------------------------+
void MlFinalizeRecoveryCycleFromReset(const string completionReason)
  {
   if(!g_mlLoggerReady ||
      g_mlCurrentRecoveryTradeIndex < 0 ||
      g_mlCurrentRecoveryTradeIndex >= ArraySize(g_mlTradeLinks))
      return;
   int index = g_mlCurrentRecoveryTradeIndex;
   MlRefreshRecoveryFinancials(index);
   string outcome = "INCOMPLETE";
   if(g_mlTradeLinks[index].maxRecoveryLevel >= 4)
      outcome = "RECOVERY_L4_PLUS";
   else if(g_mlTradeLinks[index].maxRecoveryLevel >= 1)
      outcome = "RECOVERY_L1_L3";
   MlWriteCycleOutcome(index, outcome, completionReason, TimeCurrent());
   g_mlCurrentRecoveryTradeIndex = -1;
  }

//+------------------------------------------------------------------+
void MlUpdateDatasetLoggerOnTick()
  {
   if(!g_mlLoggerReady)
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   MlUpdateBarrierRecords(tick);
   MlUpdateTradeExcursions(tick);
  }

//+------------------------------------------------------------------+
void MlShutdownDatasetLogger(const int deinitReason)
  {
   if(!g_mlLoggerReady)
      return;

   datetime now = TimeCurrent();
   for(int i = 0; i < ArraySize(g_mlBarrierRecords); i++)
     {
      if(!g_mlBarrierRecords[i].active)
         continue;
      datetime currentBar = iTime(_Symbol, PERIOD_M1, 0);
      int elapsedBars =
         (currentBar > 0
          ? (int)((currentBar - g_mlBarrierRecords[i].candidateBarTime) / 60)
          : 0);
      if(!g_mlBarrierRecords[i].horizon40Done)
         MlWriteBarrierOutcome(g_mlBarrierRecords[i], 40,
                               "HORIZON_INCOMPLETE", now, elapsedBars);
      if(!g_mlBarrierRecords[i].horizon50Done)
         MlWriteBarrierOutcome(g_mlBarrierRecords[i], 50,
                               "HORIZON_INCOMPLETE", now, elapsedBars);
      g_mlBarrierRecords[i].active = false;
     }

   for(int i = 0; i < ArraySize(g_mlTradeLinks); i++)
      if(g_mlTradeLinks[i].activeCycle)
        {
         if(g_mlTradeLinks[i].recoveryStarted)
            MlRefreshRecoveryFinancials(i);
         MlWriteCycleOutcome(i, "INCOMPLETE",
                             "DEINIT_" + IntegerToString(deinitReason), now);
        }
   g_mlCurrentRecoveryTradeIndex = -1;

   Print("TS7_ML_DATASET_SUMMARY|RunId=", g_mlRunId,
         "|Candidates=", g_mlCandidateCount,
         "|OrderAttempts=", g_mlOrderAttemptCount,
         "|TradeOutcomes=", g_mlTradeOutcomeCount,
         "|CycleOutcomes=", g_mlCycleOutcomeCount,
         "|BarrierOutcomes=", g_mlBarrierOutcomeCount,
         "|DataErrors=", g_mlDataErrors);

   MlFlushAllFiles();
   MlCloseAllOutputFiles();
   g_mlLoggerReady = false;
  }

#endif // TS7_ML_DATASET_LOGGER_MQH
