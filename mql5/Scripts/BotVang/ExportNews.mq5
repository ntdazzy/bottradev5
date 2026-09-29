// Xuất lịch tin mạnh USD từ lịch kinh tế của MT5 ra file CSV, để Strategy Tester (không có lịch tin) đọc lại.
// Chạy trên terminal thật đang kết nối sàn. File ra: Common\Files\BotVang\news_usd.csv (giờ sàn).

input datetime InpFrom = D'2025.12.01';
input datetime InpTo = D'2026.10.31';
input bool InpCloseTerminal = false;   // đóng MT5 khi xong (dùng khi chạy tự động bằng dòng lệnh)

void OnStart()
  {
   MqlCalendarValue v[];
   int n = 0;
   // Lịch kinh tế có thể chưa tải xong ngay khi terminal vừa mở: thử lại tối đa 60 giây.
   for(int i = 0; i < 60 && !IsStopped(); i++)
     {
      n = CalendarValueHistory(v, InpFrom, InpTo, NULL, "USD");
      if(n > 0)
         break;
      Sleep(1000);
     }
   if(n <= 0)
     {
      Print("[ExportNews] khong_lay_duoc_lich_tin err=", GetLastError());
      if(InpCloseTerminal)
         TerminalClose(1);
      return;
     }
   FolderCreate("BotVang", FILE_COMMON);
   int h = FileOpen("BotVang\\news_usd.csv", FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      Print("[ExportNews] khong_mo_duoc_file err=", GetLastError());
      if(InpCloseTerminal)
         TerminalClose(1);
      return;
     }
   FileWriteString(h, "time_server;event_id;event_code;name\r\n");
   int written = 0;
   for(int i = 0; i < n; i++)
     {
      MqlCalendarEvent e;
      if(!CalendarEventById(v[i].event_id, e) || e.importance != CALENDAR_IMPORTANCE_HIGH)
         continue;
      string name = e.name;
      StringReplace(name, ";", ",");
      FileWriteString(h, TimeToString(v[i].time, TIME_DATE | TIME_MINUTES) + ";" + (string)e.id + ";" + e.event_code + ";" + name + "\r\n");
      written++;
     }
   FileClose(h);
   Print("[ExportNews] da_ghi ", written, " tin manh USD tu ", TimeToString(InpFrom, TIME_DATE), " toi ", TimeToString(InpTo, TIME_DATE));
   if(InpCloseTerminal)
      TerminalClose(0);
  }
