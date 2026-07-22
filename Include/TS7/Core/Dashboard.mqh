//+------------------------------------------------------------------+
//|                                           TS7/Core/Dashboard.mqh |
//|                          Account status dashboard attachment     |
//+------------------------------------------------------------------+
#ifndef TS7_CORE_DASHBOARD_MQH
#define TS7_CORE_DASHBOARD_MQH

void AttachAccountStatusDashboard(SHandles &handles)
  {
//--- Account Status dashboard (attach indikator ke chart utama)
   if(InpEnableAccountStatusDashboard)
     {
      string dashboardPathUsed = InpAccountStatusIndicatorPath;
      handles.accountStatus = iCustom(_Symbol, _Period, dashboardPathUsed);
      if(handles.accountStatus == INVALID_HANDLE && dashboardPathUsed != "accountStatus")
        {
         ResetLastError();
         dashboardPathUsed = "accountStatus";
         handles.accountStatus = iCustom(_Symbol, _Period, dashboardPathUsed);
        }
      if(handles.accountStatus == INVALID_HANDLE)
        {
         Print("WARNING: Gagal buat handle accountStatus dashboard. Path=", InpAccountStatusIndicatorPath,
               " Error=", GetLastError());
        }
      else
        {
         // Hindari duplikasi dashboard saat EA re-init di chart yang sama.
         ChartIndicatorDelete(ChartID(), 0, ACCOUNT_STATUS_SHORTNAME);
         if(!ChartIndicatorAdd(ChartID(), 0, handles.accountStatus))
           {
            Print("WARNING: Gagal attach accountStatus dashboard ke chart. Error=", GetLastError());
           }
         else
           {
            Print("INFO: accountStatus dashboard attached. Path=", dashboardPathUsed);
           }
        }
     }
  }

void DetachAccountStatusDashboard()
  {
   ChartIndicatorDelete(ChartID(), 0, ACCOUNT_STATUS_SHORTNAME);
  }

#endif // TS7_CORE_DASHBOARD_MQH
