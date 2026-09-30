// Bộ lọc: giờ chạy theo phút VN, giờ nghỉ của sàn, chênh lệch, tin mạnh USD, biến động thấp.
#ifndef BOTVANG_FILTERS_MQH
#define BOTVANG_FILTERS_MQH

// Phút trong ngày VN (0–1439) và thứ trong tuần VN (0 = Chủ nhật)
void VnClock(datetime server, int vnOffsetHours, int &minute, int &dow)
  {
   MqlDateTime t;
   TimeToStruct(server + vnOffsetHours * 3600, t);
   minute = t.hour * 60 + t.min;
   dow = t.day_of_week;
  }

// Khung giờ chạy [startMin, endMin) theo phút VN, thứ 2–thứ 6 VN. endMin = 1440 nghĩa là tới 00:00 hôm sau.
bool InTimeWindow(datetime server, int vnOffsetHours, int startMin, int endMin)
  {
   int m, dow;
   VnClock(server, vnOffsetHours, m, dow);
   if(dow == 0 || dow == 6)
      return false;
   if(startMin <= endMin)
      return m >= startMin && m < endMin;
   return m >= startMin || m < endMin;   // khung giờ qua nửa đêm
  }

// Giờ hè Mỹ: từ Chủ nhật thứ hai của tháng 3 tới trước Chủ nhật đầu tiên của tháng 11 (theo ngày giờ sàn)
bool UsDst(datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   if(d.mon < 3 || d.mon > 11)
      return false;
   if(d.mon > 3 && d.mon < 11)
      return true;
   MqlDateTime f = d;
   f.day = 1;
   f.hour = 0;
   f.min = 0;
   f.sec = 0;
   MqlDateTime fd;
   TimeToStruct(StructToTime(f), fd);
   int firstSunday = 1 + (7 - fd.day_of_week) % 7;
   return d.mon == 3 ? d.day >= firstSunday + 7 : d.day < firstSunday;
  }

// Số phút còn tới khi phiên giao dịch hiện tại đóng, và số phút đã trôi từ lúc phiên mở (đọc từ sàn).
// Phiên kết thúc 24:00 nối tiếp phiên 00:00 ngày sau được coi là liền. Trả về false nếu đang ngoài phiên.
bool SessionInfo(const string sym, datetime server, int &minsToEnd, int &minsFromStart)
  {
   minsToEnd = 100000;
   minsFromStart = 100000;
   MqlDateTime t;
   TimeToStruct(server, t);
   int sec = t.hour * 3600 + t.min * 60 + t.sec;
   datetime from, to;
   for(uint i = 0; SymbolInfoSessionTrade(sym, (ENUM_DAY_OF_WEEK)t.day_of_week, i, from, to); i++)
     {
      int f = (int)from, e = (int)to;
      if(e == 0)
         e = 86400;
      if(sec < f || sec >= e)
         continue;
      minsFromStart = (sec - f) / 60;
      minsToEnd = (e - sec) / 60;
      if(f == 0)
        {
         ENUM_DAY_OF_WEEK prev = (ENUM_DAY_OF_WEEK)((t.day_of_week + 6) % 7);
         datetime pf, pt;
         for(uint j = 0; SymbolInfoSessionTrade(sym, prev, j, pf, pt); j++)
            if((int)pt == 0 || (int)pt >= 86400 - 60)
               minsFromStart += (86400 - (int)pf) / 60;
        }
      if(e >= 86400 - 60)
        {
         ENUM_DAY_OF_WEEK next = (ENUM_DAY_OF_WEEK)((t.day_of_week + 1) % 7);
         datetime nf, nt;
         if(SymbolInfoSessionTrade(sym, next, 0, nf, nt) && (int)nf == 0)
            minsToEnd += ((int)nt == 0 ? 86400 : (int)nt) / 60;
        }
      return true;
     }
   return false;
  }

// Lịch tin mạnh USD. Chạy thật: lịch kinh tế của MT5. Strategy Tester: file CSV do script ExportNews tạo
// (Common\Files\BotVang\news_usd.csv, giờ sàn). Không có dữ liệu thì available = false.
class CNews
  {
private:
   datetime          m_time[];
   bool              m_fomc[];
   int               m_count;
   datetime          m_lastLive;
   int               m_cursor;
   datetime          m_lastQuery;

   // Sắp lịch theo giờ (chèn trực tiếp; vài trăm tin)
   void              Sort(void)
     {
      for(int i = 1; i < m_count; i++)
        {
         datetime t = m_time[i];
         bool f = m_fomc[i];
         int j = i - 1;
         for(; j >= 0 && m_time[j] > t; j--)
           {
            m_time[j + 1] = m_time[j];
            m_fomc[j + 1] = m_fomc[j];
           }
         m_time[j + 1] = t;
         m_fomc[j + 1] = f;
        }
      m_cursor = 0;
     }

   void              Push(datetime t, bool fomc)
     {
      ArrayResize(m_time, m_count + 1, 256);
      ArrayResize(m_fomc, m_count + 1, 256);
      m_time[m_count] = t;
      m_fomc[m_count] = fomc;
      m_count++;
     }
   static bool       IsFomc(const string code) { return code == "fed-interest-rate-decision" || code == "fomc-press-conference"; }

   bool              LoadCsv(void)
     {
      int h = FileOpen("BotVang\\news_usd.csv", FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ);
      if(h == INVALID_HANDLE)
         return false;
      FileReadString(h);   // dòng tiêu đề
      while(!FileIsEnding(h))
        {
         string line = FileReadString(h);
         string f[];
         if(StringSplit(line, ';', f) < 3)
            continue;
         datetime t = StringToTime(f[0]);
         if(t > 0)
            Push(t, IsFomc(f[2]));
        }
      FileClose(h);
      Sort();
      return m_count > 0;
     }

   // Trả về true nếu lấy lịch được (kể cả khi trong khoảng đó không có tin mạnh nào); false nếu lịch báo lỗi
   bool              LoadLive(datetime now)
     {
      m_count = 0;
      MqlCalendarValue v[];
      ResetLastError();
      int n = CalendarValueHistory(v, now - 86400, now + 2 * 86400, NULL, "USD");
      if(n <= 0)
         return GetLastError() == 0;
      for(int i = 0; i < ArraySize(v); i++)
        {
         MqlCalendarEvent e;
         if(CalendarEventById(v[i].event_id, e) && e.importance == CALENDAR_IMPORTANCE_HIGH)
            Push(v[i].time, IsFomc(e.event_code));
        }
      Sort();
      return true;
     }

public:
   bool              available;
   bool              tester;

   void              Init(void)
     {
      m_count = 0;
      m_lastLive = 0;
      m_cursor = 0;
      m_lastQuery = 0;
      tester = MQLInfoInteger(MQL_TESTER) != 0;
      available = tester ? LoadCsv() : true;
     }

   // Chạy thật: nạp lại lịch mỗi 10 phút; chỉ báo "không có dữ liệu tin" khi lịch kinh tế báo lỗi
   void              Refresh(datetime now)
     {
      if(tester || now - m_lastLive < 600)
         return;
      m_lastLive = now;
      available = LoadLive(now);
     }

   // Có đang trong cửa sổ tin không: [giờ tin − beforeMin, giờ tin + afterMin]; FOMC/họp báo Fed: + fomcAfterMin.
   // Gọi mỗi tick nên dùng con trỏ chạy theo thời gian (lịch đã sắp theo giờ); thời gian lùi thì quét lại từ đầu.
   bool              InWindow(datetime now, int beforeMin, int afterMin, int fomcAfterMin)
     {
      if(now < m_lastQuery)
         m_cursor = 0;
      m_lastQuery = now;
      int maxAfter = MathMax(afterMin, fomcAfterMin) * 60;
      while(m_cursor < m_count && m_time[m_cursor] + maxAfter < now)
         m_cursor++;
      for(int i = m_cursor; i < m_count && m_time[i] - beforeMin * 60 <= now; i++)
        {
         int after = m_fomc[i] ? fomcAfterMin : afterMin;
         if(now <= m_time[i] + after * 60)
            return true;
        }
      return false;
     }

   // Giờ tin mạnh sắp tới gần nhất sau now (0 = không có)
   datetime          Next(datetime now)
     {
      datetime best = 0;
      for(int i = 0; i < m_count; i++)
         if(m_time[i] > now && (best == 0 || m_time[i] < best))
            best = m_time[i];
      return best;
     }

   int               Count(void) const { return m_count; }
  };

#endif
