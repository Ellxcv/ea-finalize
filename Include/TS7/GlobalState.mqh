//+------------------------------------------------------------------+
//|                                              TS7/GlobalState.mqh |
//|                         Shared state containers for TS7          |
//+------------------------------------------------------------------+
#ifndef TS7_GLOBAL_STATE_MQH
#define TS7_GLOBAL_STATE_MQH

struct SHandles
  {
   int cci;
   int hilo;
   int psar;
   int superTrend;
   int mainPSAR;
   int mainSuperTrend;
   int recoveryClassicPSAR;
   int recoveryClassicST;
   int recoveryDistancePSAR;
   int recoveryDistanceST;
   int recoveryATR;
   int recoveryGridATR;
   int adx;
   int stFilter;
   int accountStatus;
   int algoZone;
   int distEmaFast;
   int distEmaSlow;
   int originalDiagATR;
   int originalDiagEMA;
   int mlBarrierATR;
   int mlATR_M5;
   int mlEMA;
   int mlADX;

   SHandles()
     {
      cci = INVALID_HANDLE;
      hilo = INVALID_HANDLE;
      psar = INVALID_HANDLE;
      superTrend = INVALID_HANDLE;
      mainPSAR = INVALID_HANDLE;
      mainSuperTrend = INVALID_HANDLE;
      recoveryClassicPSAR = INVALID_HANDLE;
      recoveryClassicST = INVALID_HANDLE;
      recoveryDistancePSAR = INVALID_HANDLE;
      recoveryDistanceST = INVALID_HANDLE;
      recoveryATR = INVALID_HANDLE;
      recoveryGridATR = INVALID_HANDLE;
      adx = INVALID_HANDLE;
      stFilter = INVALID_HANDLE;
      accountStatus = INVALID_HANDLE;
      algoZone = INVALID_HANDLE;
      distEmaFast = INVALID_HANDLE;
      distEmaSlow = INVALID_HANDLE;
      originalDiagATR = INVALID_HANDLE;
      originalDiagEMA = INVALID_HANDLE;
      mlBarrierATR = INVALID_HANDLE;
      mlATR_M5 = INVALID_HANDLE;
      mlEMA = INVALID_HANDLE;
      mlADX = INVALID_HANDLE;
     }
  };

SHandles g_handles;

#endif // TS7_GLOBAL_STATE_MQH
