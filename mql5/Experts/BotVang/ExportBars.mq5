// Chỉ máy thử: xuất nến M1 (giá Bid) ra CSV để nghiên cứu ngoài MT5.
// MT5 chính giới hạn số nến nên CopyRates theo khoảng dài báo lỗi 4401; máy thử tự nạp lịch sử theo khoảng chạy.
// Chạy: run-tester.ps1 -Expert BotVang\ExportBars.ex5 -Model 1 -Period M1 -From 2025.01.01 -To 2026.01.05
// File ra: Common\Files\BotVang\bars_<ký hiệu>_M1_<ngày đầu>.csv; cột time;open;high;low;close;tick_volume;spread_price.

int      g_file = INVALID_HANDLE;
datetime g_last = 0;
long     g_rows = 0;

int OnInit()
  {
   if(!MQLInfoInteger(MQL_TESTER))
      return INIT_FAILED;
   string day = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(day, ".", "");
   FolderCreate("BotVang", FILE_COMMON);
   g_file = FileOpen("BotVang\\bars_" + _Symbol + "_M1_" + day + ".csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(g_file == INVALID_HANDLE)
     {
      Print("[ExportBars] khong_mo_duoc_file err=", GetLastError());
      return INIT_FAILED;
     }
   FileWriteString(g_file, "time;open;high;low;close;tick_volume;spread_price\r\n");
   return INIT_SUCCEEDED;
  }

void OnTick()
  {
   datetime t = iTime(_Symbol, PERIOD_M1, 0);
   if(t == g_last)
      return;
   g_last = t;
   MqlRates r[];
   if(CopyRates(_Symbol, PERIOD_M1, 1, 1, r) != 1)
      return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   FileWriteString(g_file, TimeToString(r[0].time, TIME_DATE | TIME_SECONDS) + ";" + DoubleToString(r[0].open, digits) + ";" +
                           DoubleToString(r[0].high, digits) + ";" + DoubleToString(r[0].low, digits) + ";" +
                           DoubleToString(r[0].close, digits) + ";" + (string)r[0].tick_volume + ";" +
                           DoubleToString(r[0].spread * SymbolInfoDouble(_Symbol, SYMBOL_POINT), digits) + "\r\n");
   g_rows++;
  }

void OnDeinit(const int reason)
  {
   if(g_file != INVALID_HANDLE)
      FileClose(g_file);
   Print("[ExportBars] da_ghi ", g_rows, " nen M1");
  }
